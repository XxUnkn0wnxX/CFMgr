"""Owned real-JSON to minimal config-header report composition."""

from __future__ import annotations

import shlex
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_config_header import SEED, exact_token_cap_document, produce
from tests.test_config_header import SOURCE as HEADER_PARSER
from tests.test_json import SOURCE as JSON_PARSER
from tests.test_package import PackageFixture

LIB = Path(__file__).resolve().parents[1] / "modules/lib"
IO_RUNTIME = LIB / "io.sh"
JSON_RUNTIME = LIB / "json.sh"
CONFIG_RUNTIME = LIB / "config.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V42", evidence="host")]
ConfigFixture = tuple[PackageFixture, Path, Path, Path]
NATIVE_AWK = Path(shutil.which("awk") or "/usr/bin/awk").resolve()
NATIVE_CMP = Path(shutil.which("cmp") or "/usr/bin/cmp").resolve()


def expected_report(generation: int, developer: bool) -> bytes:
    value = "true" if developer else "false"
    body = f"config-header\t1\t{generation}\t{value}\n".encode("ascii")
    return body + f"end\t{len(body)}\n".encode("ascii")


def projection(line: str) -> bytes:
    body = (line + "\n").encode("ascii")
    return body + f"end\t{len(body)}\n".encode("ascii")


def runtime_source() -> str:
    return f'. "{IO_RUNTIME}"\n' + f'. "{JSON_RUNTIME}"\n' + f'. "{CONFIG_RUNTIME}"\n'


def source(package: PackageFixture) -> str:
    return runtime_source() + 'cfmgr_config_header_test "$@"\n'


def lifecycle_source() -> str:
    return runtime_source() + 'cfmgr_config_lifecycle_test "$@"\n'


def configure_header_files(package: PackageFixture) -> tuple[Path, Path, Path]:
    config = package.router.path("work/config.json")
    config.write_bytes(SEED)
    config.chmod(0o600)
    json_parser = package.router.write("work/json.awk", JSON_PARSER.read_text(encoding="utf-8"))
    header_parser = package.router.write(
        "work/config_header.awk", HEADER_PARSER.read_text(encoding="utf-8")
    )
    return config, json_parser, header_parser


@pytest.fixture
def config_fixture(router: RouterHarness, pytestconfig: pytest.Config) -> ConfigFixture:
    return make_config_fixture(router, pytestconfig._cfmgr_busybox)


def make_config_fixture(router: RouterHarness, busybox: Path | None = None) -> ConfigFixture:
    package = PackageFixture(router, busybox=busybox)
    return (package, *configure_header_files(package))


def report(
    package: PackageFixture, config: Path, json_parser: Path, header_parser: Path
) -> ShellResult:
    args = tuple(map(str, (package.root, package.tools, config, json_parser, header_parser)))
    return package.router.run(source(package), args)


def lifecycle_report(
    package: PackageFixture,
    config: Path,
    json_parser: Path,
    header_parser: Path,
) -> ShellResult:
    args = tuple(map(str, (package.root, package.tools, config, json_parser, header_parser)))
    return package.router.run(lifecycle_source(), args)


def quiet(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == "", result


def assert_clean(package: PackageFixture) -> None:
    assert list(package.root.glob("cfmgr-io.*")) == []


def decode_group(
    package: PackageFixture,
    cases: tuple[tuple[int, Path, int], ...],
    *,
    lifecycle: bool = False,
) -> ShellResult:
    decoder = "_cfmgr_config_lifecycle_decode" if lifecycle else "_cfmgr_config_header_decode"
    script = (
        runtime_source()
        + "fixture_header_decode() {\n"
        + "  _decode_stage=$1; shift\n"
        + "  _decode_results=\n"
        + '  while [ "$#" -ge 3 ]; do\n'
        + "    _decode_expected=$1; _decode_file=$2; _decode_bytes=$3; shift 3\n"
        + f'    if {decoder} "$_decode_file" "$_decode_bytes"; then\n'
        + "      _decode_actual=0\n"
        + "    else\n"
        + "      _decode_actual=$?\n"
        + "    fi\n"
        + '    [ "$_decode_actual" = "$_decode_expected" ] || return 1\n'
        + (
            '    if [ "$_decode_actual" != 0 ]; then\n'
            + '      [ -z "$_config_lifecycle_ledger$_config_generation$_config_developer'
            + "$_config_cloudflared_configured$_config_cloudflared_enabled"
            + "$_config_cloudflared_maintenance_enabled$_config_cloudflared_mode"
            + "$_config_ddns_configured$_config_ddns_enabled"
            + '$_config_ip_sync_configured$_config_ip_sync_enabled" ] || return 1\n'
            + "    fi\n"
            if lifecycle
            else ""
        )
        + '    _decode_results="$_decode_results$_decode_actual\n"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_decode_results"\n'
        + "}\n"
        + "decode_root=$1; decode_tools=$2; shift 2\n"
        + 'cfmgr_io_test "$decode_root" "$decode_tools" report fixture_header_decode "$@"\n'
    )
    args = [str(package.root), str(package.tools)]
    for expected_status, file_path, expected_bytes in cases:
        args.extend((str(expected_status), str(file_path), str(expected_bytes)))
    return package.router.run(script, args)


def test_owned_report_is_exact_and_contains_only_header_fields(
    config_fixture: ConfigFixture,
) -> None:
    package, config, json_parser, header_parser = config_fixture
    result = report(package, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_report(7, True)
    assert b"fixture-secret" not in result.stdout.encode("ascii")
    assert_clean(package)


def test_exact_wide_token_capacity_flows_through_owned_report(
    config_fixture: ConfigFixture,
) -> None:
    package, config, json_parser, header_parser = config_fixture
    document = exact_token_cap_document()
    assert len(document) <= 65536
    config.write_bytes(document)
    result = report(package, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_report(0, False)
    assert_clean(package)


def test_header_decode_refuses_nul_footer_eof_and_byte_count_faults_as_a_group(
    config_fixture: ConfigFixture,
) -> None:
    package, _, _, _ = config_fixture
    valid = expected_report(7, True)
    root = package.router.path("work/header-ledgers")
    root.mkdir()
    files: list[tuple[int, Path, int]] = []

    def add(
        name: str, data: bytes, expected_status: int = 1, expected_size: int | None = None
    ) -> None:
        path = root / name
        path.write_bytes(data)
        files.append((expected_status, path, len(data) if expected_size is None else expected_size))

    add("valid", valid, expected_status=0)
    add("generation-max", expected_report(2147483647, False), expected_status=0)
    nul = valid.replace(b"\ttrue\n", b"\tt\x00rue\n")
    add("nul", nul)
    add("bad-footer", valid.replace(b"end\t23\n", b"end\t24\n"))
    add("missing-lf", valid[:-1])
    add("extra-record", valid + b"extra\n")
    add("partial-extra", valid + b"extra")
    add("wrong-size", valid, expected_size=len(valid) + 1)
    add("generation-overflow", projection("config-header\t1\t2147483648\ttrue"))
    add("noncanonical-generation", projection("config-header\t1\t07\ttrue"))
    add("wrong-schema", projection("config-header\t2\t7\ttrue"))
    add("wrong-developer", projection("config-header\t1\t7\tTRUE"))
    add("extra-field", projection("config-header\t1\t7\ttrue\textra"))
    result = decode_group(package, tuple(files))
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "0\n0\n" + "1\n" * 11
    assert_clean(package)


def test_token_capture_checks_producer_and_downstream_framing_with_positive_control(
    config_fixture: ConfigFixture,
) -> None:
    package, config, json_parser, header_parser = config_fixture
    valid_tokens = produce(package.router, SEED)
    token_path = package.router.path("work/token-output")
    token_path.write_bytes(valid_tokens)
    short_path = package.router.path("work/token-output-short")
    short_path.write_bytes(valid_tokens[:-1])
    mode_path = package.router.path("work/token-producer-mode")
    package.replace_tool(
        "awk",
        "mode=$(/bin/cat "
        + shlex.quote(str(mode_path))
        + "); tokens="
        + shlex.quote(str(token_path))
        + "; short="
        + shlex.quote(str(short_path))
        + "\n"
        + 'case "$mode" in\n'
        + '  valid|stderr|failure|parser-error) /bin/cat "$tokens" ;;\n'
        + '  parser-error-stderr) /bin/cat "$tokens" ;;\n'
        + '  short) /bin/cat "$short" ;;\n'
        + "  *) exit 9 ;;\n"
        + "esac\n"
        + '[ "$mode" != stderr ] || printf diagnostic >&2\n'
        + '[ "$mode" != parser-error-stderr ] || { printf diagnostic >&2; exit 2; }\n'
        + '[ "$mode" != failure ] || exit 7\n'
        + '[ "$mode" != parser-error ] || exit 2\n',
    )
    expected_path = package.router.path("work/expected-header")
    expected_path.write_bytes(expected_report(7, True))
    error_path = package.router.path("work/header-parser.stderr")
    output_path = package.router.path("work/header-parser.stdout")
    script = (
        source(package).split('cfmgr_config_header_test "$@"\n')[0]
        + "fixture_token_capture() {\n"
        + "  _capture_stage=$1; shift\n"
        + "  _config=$1; _json_parser=$2; _header_parser=$3\n"
        + "  _expected_projection=$4; _header_error=$5; _header_output=$6; shift 6\n"
        + "  _capture_results=\n"
        + '  while [ "$#" -ge 4 ]; do\n'
        + "    _expected_capture=$1; _expected_decode=$2; _mode=$3; _slot=$4; shift 4\n"
        + "    printf '%s' \"$_mode\" > "
        + shlex.quote(str(mode_path))
        + " || return 1\n"
        + '    if _cfmgr_json_tokens_capture "$_config" "$_json_parser" '
        + '"$_slot" "$((_slot + 1))"; then\n'
        + "      _capture_actual=0\n"
        + "    else\n"
        + "      _capture_actual=$?\n"
        + "    fi\n"
        + '    [ "$_capture_actual" = "$_expected_capture" ] || return 1\n'
        + "    _header_actual=-\n"
        + '    if [ "$_capture_actual" = 0 ]; then\n'
        + "      if "
        + shlex.quote(str(NATIVE_AWK))
        + ' -v "cfmgr_config_header_size=$_json_tokens_bytes" '
        + '-f "$_header_parser" <"$_json_tokens_file" '
        + '>"$_header_output" 2>"$_header_error"; then\n'
        + "        _header_actual=0\n"
        + "      else\n"
        + "        _header_actual=$?\n"
        + "      fi\n"
        + '      [ "$_header_actual" = "$_expected_decode" ] && '
        + '[ ! -s "$_header_error" ] || return 1\n'
        + '      if [ "$_header_actual" = 0 ]; then\n'
        + "        "
        + shlex.quote(str(NATIVE_CMP))
        + ' "$_header_output" "$_expected_projection" || return 1\n'
        + '        _header_bytes=$(_cfmgr_io_size "$_header_output") || return 1\n'
        + '        _cfmgr_config_header_decode "$_header_output" "$_header_bytes" || return 1\n'
        + "      else\n"
        + '        [ ! -s "$_header_output" ] || return 1\n'
        + "      fi\n"
        + "    fi\n"
        + '    _capture_results="$_capture_results$_capture_actual\t$_header_actual\n"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_capture_results"\n'
        + "}\n"
        + "capture_root=$1; capture_tools=$2; shift 2\n"
        + "capture_config=$1; capture_json_parser=$2; capture_header_parser=$3; shift 3\n"
        + "capture_expected=$1; capture_error=$2; capture_output=$3; shift 3\n"
        + 'cfmgr_io_test "$capture_root" "$capture_tools" report fixture_token_capture '
        + '"$capture_config" "$capture_json_parser" "$capture_header_parser" '
        + '"$capture_expected" "$capture_error" "$capture_output" "$@"\n'
    )
    args = [
        str(package.root),
        str(package.tools),
        str(config),
        str(json_parser),
        str(header_parser),
        str(expected_path),
        str(error_path),
        str(output_path),
    ]
    cases = (
        (0, 0, "valid"),
        (0, 1, "short"),
        (1, "-", "stderr"),
        (1, "-", "failure"),
        (2, "-", "parser-error"),
        (1, "-", "parser-error-stderr"),
    )
    for slot, (capture_status, decode_status, mode) in enumerate(cases):
        args.extend((str(capture_status), str(decode_status), mode, str(slot * 2)))
    result = package.router.run(script, args)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "0\t0\n0\t1\n1\t-\n1\t-\n2\t-\n1\t-\n"
    assert_clean(package)


def test_owned_report_refuses_cleanup_failure_after_a_successful_report(
    config_fixture: ConfigFixture,
) -> None:
    package, config, json_parser, header_parser = config_fixture
    valid = report(package, config, json_parser, header_parser)
    assert valid.returncode == 0 and valid.stderr == ""
    assert valid.stdout.encode("ascii") == expected_report(7, True)
    package.replace_tool("rm", "exit 7\n")
    quiet(report(package, config, json_parser, header_parser))


@pytest.mark.busybox
@pytest.mark.matrix("V42", evidence="busybox")
def test_actual_busybox_composes_owned_config_header_report(
    busybox_router: RouterHarness,
) -> None:
    package = PackageFixture(busybox_router, busybox=busybox_router.busybox)
    config, json_parser, header_parser = configure_header_files(package)
    result = report(package, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_report(7, True)
    assert_clean(package)
