"""Read-only setup-state policy and its lifecycle projection."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_config_header_report import (
    assert_clean,
    make_config_fixture,
    runtime_source,
)
from tests.test_config_lifecycle import document, feature_config
from tests.test_package import PackageFixture

LIB = Path(__file__).resolve().parents[1] / "modules/lib"
SETUP_STATE = LIB / "setup_state.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V42", evidence="host")]

IDENTITY = "0123456789abcdef0123456789abcdef"


def guard(state: str, generation: int | str, identity: str = IDENTITY) -> bytes:
    return (
        f"setup-state: 1\nstate: {state}\ngeneration: {generation}\nidentity: {identity}\n"
    ).encode("ascii")


def expected_report(state: str, generation: int | str, identity: str, check: str) -> bytes:
    body = (f"setup-state\t1\t{state}\t{generation}\t{identity}\nconfig-check\t{check}\n").encode(
        "ascii"
    )
    return body + f"end\t{len(body)}\n".encode("ascii")


def setup_source() -> str:
    return runtime_source() + f'. "{SETUP_STATE}"\n' + 'cfmgr_setup_state_test "$@"\n'


def make_setup_fixture(
    router: RouterHarness, busybox: Path | None = None
) -> tuple[PackageFixture, Path, Path, Path, Path]:
    package, config, json_parser, header_parser = make_config_fixture(router, busybox)
    guard_path = router.path("work/setup.guard")
    return package, guard_path, config, json_parser, header_parser


def setup_report(
    package: PackageFixture,
    guard_path: Path,
    config: Path,
    json_parser: Path,
    header_parser: Path,
) -> ShellResult:
    args = tuple(
        map(
            str,
            (package.root, package.tools, guard_path, config, json_parser, header_parser),
        )
    )
    return package.router.run(setup_source(), args)


def test_setup_owner_composes_installed_retained_and_reset_passive_states(
    router: RouterHarness, pytestconfig: pytest.Config
) -> None:
    package, guard_path, config, json_parser, header_parser = make_setup_fixture(
        router, pytestconfig._cfmgr_busybox
    )
    installed = feature_config(
        generation=20,
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "token",
        },
        ddns={"configured": True, "enabled": True},
    )
    config.write_bytes(document(installed))
    guard_path.write_bytes(guard("installed", 20))
    result = setup_report(package, guard_path, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.encode("ascii") == expected_report(
        "installed", 20, IDENTITY, "lifecycle-match"
    )
    assert_clean(package)

    retained = guard("retained", 99)
    guard_path.write_bytes(retained)
    missing = router.path("work/unused-missing.json")
    result = setup_report(package, guard_path, missing, missing, missing)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.encode("ascii") == expected_report("retained", 99, IDENTITY, "not-read")
    assert_clean(package)

    for state in ("installing", "removing-keep", "removing-wipe", "resetting"):
        guard_path.write_bytes(guard(state, "unknown"))
        result = setup_report(package, guard_path, missing, missing, missing)
        assert result.returncode == 0 and result.stderr == "", result
        assert result.stdout.encode("ascii") == expected_report(
            state, "unknown", IDENTITY, "not-read"
        )
        assert_clean(package)

    passive = feature_config(generation=21, developer=False)
    config.write_bytes(document(passive))
    guard_path.write_bytes(guard("reset-passive", 21))
    result = setup_report(package, guard_path, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.encode("ascii") == expected_report(
        "reset-passive", 21, IDENTITY, "passive-match"
    )
    assert_clean(package)


def test_setup_owner_refuses_missing_guard_and_generation_mismatch_quietly(
    router: RouterHarness,
) -> None:
    package, guard_path, config, json_parser, header_parser = make_setup_fixture(router)
    active = feature_config(
        generation=8,
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "advanced",
        },
    )
    config.write_bytes(document(active))
    failed = setup_report(package, guard_path, config, json_parser, header_parser)
    assert failed.returncode == 1
    assert failed.stdout == failed.stderr == ""
    assert_clean(package)

    guard_path.write_bytes(guard("installed", 7))
    failed = setup_report(package, guard_path, config, json_parser, header_parser)
    assert failed.returncode == 1
    assert failed.stdout == failed.stderr == ""
    assert_clean(package)


def test_setup_guard_decoder_checks_canonical_rows_and_all_state_dispositions_as_group(
    router: RouterHarness,
) -> None:
    package, _guard_path, _config, _json_parser, _header_parser = make_setup_fixture(router)
    root = router.path("work/setup-guards")
    root.mkdir()
    cases: list[tuple[int, Path, int, str, str, str]] = []

    def add(
        name: str,
        data: bytes,
        status: int = 1,
        state: str = "",
        generation: str = "",
        identity: str = "",
        measured: int | None = None,
    ) -> None:
        path = root / name
        path.write_bytes(data)
        cases.append(
            (status, path, len(data) if measured is None else measured, state, generation, identity)
        )

    states = (
        "installed",
        "retained",
        "installing",
        "removing-keep",
        "removing-wipe",
        "resetting",
        "reset-passive",
    )
    for state in states:
        add(state, guard(state, 0), 0, state, "0", IDENTITY)
    for state in ("installing", "removing-keep", "removing-wipe", "resetting"):
        add(
            f"{state}-unknown-generation",
            guard(state, 0).replace(b"generation: 0", b"generation: unknown"),
            0,
            state,
            "unknown",
            IDENTITY,
        )
    add(
        "generation-maximum", guard("installed", 2147483647), 0, "installed", "2147483647", IDENTITY
    )
    add(
        "unknown-terminal-generation",
        guard("installed", 0).replace(b"generation: 0", b"generation: unknown"),
    )
    add(
        "unknown-passive-generation",
        guard("reset-passive", 0).replace(b"generation: 0", b"generation: unknown"),
    )
    add(
        "unknown-retained-generation",
        guard("retained", 0).replace(b"generation: 0", b"generation: unknown"),
    )
    add("unknown-state", guard("complete", 0))
    add(
        "leading-zero-generation",
        guard("installed", 7).replace(b"generation: 7", b"generation: 07"),
    )
    add("negative-generation", guard("installed", 7).replace(b"generation: 7", b"generation: -1"))
    add(
        "overflow-generation",
        guard("installed", 7).replace(b"generation: 7", b"generation: 2147483648"),
    )
    add("uppercase-identity", guard("installed", 7, IDENTITY.upper()))
    add("short-identity", guard("installed", 7, IDENTITY[:-1]))
    add("wrong-header", guard("installed", 7).replace(b"setup-state: 1", b"setup-state: 2"))
    add(
        "carriage-return",
        guard("installed", 7).replace(b"state: installed\n", b"state: installed\r\n"),
    )
    add("blank-row", guard("installed", 7).replace(b"setup-state: 1\n", b"setup-state: 1\n\n"))
    add(
        "swapped-rows",
        guard("installed", 7).replace(
            b"state: installed\ngeneration: 7\n",
            b"generation: 7\nstate: installed\n",
        ),
    )
    add("extra-spacing", guard("installed", 7).replace(b"state: installed", b"state:  installed"))
    add("missing-final-lf", guard("installed", 7)[:-1])
    add(
        "partial-final-row",
        guard("installed", 7).rsplit(b"identity", 1)[0] + b"identity: " + IDENTITY[:8].encode(),
    )
    add("extra-row", guard("installed", 7) + b"extra: row\n")
    add("partial-trailing-row", guard("installed", 7) + b"extra")
    nul = guard("installed", 7).replace(b"identity: ", b"identity: \0", 1)
    add("nul-byte", nul)
    add("incorrect-original-size", guard("installed", 7), measured=len(guard("installed", 7)) + 1)
    add("over-limit", b"x" * 257)

    script = (
        runtime_source()
        + f'. "{SETUP_STATE}"\n'
        + "fixture_setup_decode() {\n"
        + "  _decode_stage=$1; shift\n"
        + "  _decode_results=\n"
        + '  while [ "$#" -ge 6 ]; do\n'
        + "    _decode_expected=$1; _decode_file=$2; _decode_bytes=$3\n"
        + "    _want_state=$4; _want_generation=$5; _want_identity=$6; shift 6\n"
        + '    if _cfmgr_setup_state_decode "$_decode_file" "$_decode_bytes"; then\n'
        + "      _decode_actual=0\n"
        + "    else\n"
        + "      _decode_actual=$?\n"
        + "    fi\n"
        + '    [ "$_decode_actual" = "$_decode_expected" ] || return 1\n'
        + '    if [ "$_decode_actual" = 0 ]; then\n'
        + '      [ "$_setup_state" = "$_want_state" ] &&\n'
        + '        [ "$_setup_generation" = "$_want_generation" ] &&\n'
        + '        [ "$_setup_identity" = "$_want_identity" ] || return 1\n'
        + "    else\n"
        + '      [ -z "$_setup_state$_setup_generation$_setup_identity" ] || return 1\n'
        + "    fi\n"
        + '    _decode_results="$_decode_results$_decode_actual$_io_lf"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_decode_results"\n'
        + "}\n"
        + "decode_root=$1; decode_tools=$2; shift 2\n"
        + 'cfmgr_io_test "$decode_root" "$decode_tools" report fixture_setup_decode "$@"\n'
    )
    args = [str(package.root), str(package.tools)]
    for expected_status, path, size, state, generation, identity in cases:
        args.extend((str(expected_status), str(path), str(size), state, generation, identity))
    result = router.run(script, args)
    assert result.returncode == 0 and result.stderr == "", result
    successful = len(states) + 4 + 1
    expected = "0\n" * successful + "1\n" * (len(cases) - successful)
    assert result.stdout == expected
    assert_clean(package)


def test_setup_state_policy_checks_generation_and_each_passive_field_as_a_group(
    router: RouterHarness,
) -> None:
    package, _guard_path, _config, _json_parser, _header_parser = make_setup_fixture(router)
    baseline = [
        "reset-passive",
        "21",
        "21",
        "false",
        "false",
        "false",
        "false",
        "none",
        "false",
        "false",
        "false",
        "false",
    ]
    vectors: list[tuple[int, str, list[str]]] = [(0, "passive-match", baseline.copy())]

    def changed(name: str, **updates: str) -> None:
        fields = baseline.copy()
        indices = {
            "state": 0,
            "setup_generation": 1,
            "config_generation": 2,
            "developer": 3,
            "cf_configured": 4,
            "cf_enabled": 5,
            "cf_maintenance": 6,
            "cf_mode": 7,
            "ddns_configured": 8,
            "ddns_enabled": 9,
            "ip_configured": 10,
            "ip_enabled": 11,
        }
        for key, value in updates.items():
            fields[indices[key]] = value
        vectors.append((1, name, fields))

    changed("generation-mismatch", config_generation="20")
    changed("developer-enabled", developer="true")
    changed("cloudflared-configured", cf_configured="true", cf_mode="token")
    changed(
        "cloudflared-enabled",
        cf_configured="true",
        cf_enabled="true",
        cf_maintenance="true",
        cf_mode="advanced",
    )
    changed("cloudflared-maintenance-only", cf_maintenance="true")
    changed("ddns-configured", ddns_configured="true")
    changed("ddns-enabled", ddns_configured="true", ddns_enabled="true")
    changed("ip-sync-configured", ip_configured="true")
    changed("ip-sync-enabled", ip_configured="true", ip_enabled="true")

    script = (
        runtime_source()
        + f'. "{SETUP_STATE}"\n'
        + "fixture_setup_check() {\n"
        + "  _check_stage=$1; shift\n"
        + "  _check_results=\n"
        + '  while [ "$#" -ge 14 ]; do\n'
        + "    _check_expected=$1; _check_want=$2; shift 2\n"
        + "    _setup_state=$1; _setup_generation=$2; _config_generation=$3; _config_developer=$4\n"
        + "    _config_cloudflared_configured=$5; _config_cloudflared_enabled=$6\n"
        + "    _config_cloudflared_maintenance_enabled=$7; _config_cloudflared_mode=$8\n"
        + "    _config_ddns_configured=$9; shift 9\n"
        + "    _config_ddns_enabled=$1; _config_ip_sync_configured=$2\n"
        + "    _config_ip_sync_enabled=$3; shift 3\n"
        + "    if _cfmgr_setup_state_config_check; then\n"
        + "      _check_actual=0\n"
        + "    else\n"
        + "      _check_actual=$?\n"
        + "    fi\n"
        + '    [ "$_check_actual" = "$_check_expected" ] || return 1\n'
        + '    if [ "$_check_actual" = 0 ]; then\n'
        + '      [ "$_setup_config_check" = "$_check_want" ] || return 1\n'
        + "    else\n"
        + '      [ -z "$_setup_config_check" ] || return 1\n'
        + "    fi\n"
        + '    _check_results="$_check_results$_check_actual$_io_lf"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_check_results"\n'
        + "}\n"
        + "check_root=$1; check_tools=$2; shift 2\n"
        + 'cfmgr_io_test "$check_root" "$check_tools" report fixture_setup_check "$@"\n'
    )
    args = [str(package.root), str(package.tools)]
    for expected_status, name, fields in vectors:
        args.extend((str(expected_status), name, *fields))
    result = router.run(script, args)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == "0\n" + "1\n" * (len(vectors) - 1)
    assert_clean(package)


def test_setup_guard_producer_failure_and_cleanup_failure_suppress_report(
    router: RouterHarness,
) -> None:
    package, guard_path, config, json_parser, header_parser = make_setup_fixture(router)
    value = feature_config(generation=31)
    config.write_bytes(document(value))
    guard_path.write_bytes(guard("installed", 31))

    package.replace_tool(
        "cat",
        "printf 'setup-state: 1\\nstate: installed\\ngeneration: 31\\nidentity: "
        + IDENTITY
        + "\\n'\nexit 1\n",
    )
    failed = setup_report(package, guard_path, config, json_parser, header_parser)
    assert failed.returncode == 1
    assert failed.stdout == failed.stderr == ""
    assert_clean(package)

    # Restore native capture so the next invocation reaches cleanup after a
    # valid owner result; a failed cleanup must still suppress publication.
    native_cat = shutil.which("cat")
    assert native_cat is not None
    package.tool_path("cat").unlink()
    package.tool_path("cat").symlink_to(Path(native_cat).resolve())
    positive = setup_report(package, guard_path, config, json_parser, header_parser)
    assert positive.returncode == 0 and positive.stderr == "", positive
    assert positive.stdout.encode("ascii") == expected_report(
        "installed", 31, IDENTITY, "lifecycle-match"
    )
    assert_clean(package)

    package.replace_tool("rm", "exit 1\n")
    suppressed = setup_report(package, guard_path, config, json_parser, header_parser)
    assert suppressed.returncode == 1
    assert suppressed.stdout == suppressed.stderr == ""
    assert list(package.root.glob("cfmgr-io.*"))


@pytest.mark.busybox
@pytest.mark.matrix("V42", evidence="busybox")
def test_actual_busybox_composes_installed_setup_state(
    busybox_router: RouterHarness,
) -> None:
    package, guard_path, config, json_parser, header_parser = make_setup_fixture(
        busybox_router, busybox_router.busybox
    )
    value = feature_config(
        generation=2147483647,
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "advanced",
        },
    )
    config.write_bytes(document(value))
    guard_path.write_bytes(guard("installed", 2147483647))
    result = setup_report(package, guard_path, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.encode("ascii") == expected_report(
        "installed", 2147483647, IDENTITY, "lifecycle-match"
    )
    assert_clean(package)
