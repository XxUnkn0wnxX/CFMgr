"""Catalog-to-manifest joins into pinned, non-installing source plans."""

from __future__ import annotations

import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_catalog import catalog as make_catalog
from tests.test_catalog import expected as expected_catalog
from tests.test_package import PackageFixture, expected_ledger, manifest

LIB = Path(__file__).resolve().parents[1] / "modules/lib"
CATALOG_RUNTIME = LIB / "catalog.sh"
CATALOG_PARSER = LIB / "catalog.awk"
COMMIT = "0123456789abcdef0123456789abcdef01234567"
RAW_PREFIX = "https://raw.githubusercontent.com/Example-Org/CFMgr/{commit}/"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def expected_plan_report(catalog_data: bytes, manifest_data: bytes, commit: str) -> bytes:
    """Join independent parser oracles, pin URLs, and recompute the report footer."""
    catalog_rows = [line.split("\t") for line in expected_catalog(catalog_data).splitlines()]
    catalog_meta = {fields[0]: fields[1:] for fields in catalog_rows if fields[0] != "file"}
    catalog_files = {fields[1]: fields[2] for fields in catalog_rows if fields[0] == "file"}
    manifest_rows = [
        line.split("\t") for line in expected_ledger(manifest_data).decode("ascii").splitlines()
    ]
    manifest_meta = {
        fields[0]: fields[1:]
        for fields in manifest_rows
        if fields[0] != "file" and fields[0] != "end"
    }
    records = [fields for fields in manifest_rows if fields[0] == "file"]
    pinned_manifest = catalog_meta["manifest"][0].replace("{commit}", commit)
    body = (
        "source-plan\t1\n"
        + f"repository\t{catalog_meta['repository'][0]}\t{catalog_meta['repository'][1]}\n"
        + f"selector\t{catalog_meta['branch'][0]}\n"
        + f"commit\t{commit}\n"
        + f"manifest\t{pinned_manifest}\n"
        + f"version\t{manifest_meta['version'][0]}\n"
        + f"config-schema\t{manifest_meta['config-schema'][0]}\n"
        + f"package-api\t{manifest_meta['package-api'][0]}\n"
    )
    total = 0
    for fields in records:
        destination, size, digest, mode = fields[1:]
        total += int(size)
        pinned_url = catalog_files[destination].replace("{commit}", commit)
        body += f"file\t{destination}\t{size}\t{digest}\t{mode}\t{pinned_url}\n"
    body_bytes = body.encode("ascii")
    return body_bytes + f"end\t{len(records)}\t{total}\t{len(body_bytes)}\n".encode("ascii")


@pytest.fixture
def package_fixture(router: RouterHarness, pytestconfig: pytest.Config) -> PackageFixture:
    return PackageFixture(router, busybox=pytestconfig._cfmgr_busybox)


def install_catalog_inputs(package: PackageFixture, catalog_data: bytes) -> tuple[Path, Path]:
    catalog_file = package.router.path("work/catalog.txt")
    catalog_file.write_bytes(catalog_data)
    catalog_file.chmod(0o600)
    parser_file = package.router.write(
        "work/catalog.awk", CATALOG_PARSER.read_text(encoding="utf-8")
    )
    return catalog_file, parser_file


def catalog_source(package: PackageFixture) -> str:
    return package.verifier_source() + f'. "{CATALOG_RUNTIME}"\n'


def plan_source(package: PackageFixture) -> str:
    return catalog_source(package) + 'cfmgr_catalog_plan_test "$@"\n'


def plan_args(
    package: PackageFixture, catalog_file: Path, catalog_parser: Path, commit: str
) -> tuple[str, ...]:
    return tuple(
        map(
            str,
            (
                package.root,
                package.tools,
                catalog_file,
                package.input,
                package.helper,
                catalog_parser,
                package.parser,
                commit,
            ),
        )
    )


def plan_result(
    package: PackageFixture,
    catalog_data: bytes,
    *,
    commit: str = COMMIT,
) -> ShellResult:
    catalog_file, catalog_parser = install_catalog_inputs(package, catalog_data)
    return package.router.run(
        plan_source(package), plan_args(package, catalog_file, catalog_parser, commit)
    )


def assert_no_io_scratch(package: PackageFixture) -> None:
    assert list(package.root.glob("cfmgr-io.*")) == []


def reject(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status
    assert result.stdout == result.stderr == ""


def catalog_decode_group(
    package: PackageFixture, cases: tuple[tuple[int, Path, int], ...]
) -> ShellResult:
    script = (
        catalog_source(package)
        + "fixture_catalog_decode() {\n"
        + "  shift\n"
        + "  _decode_results=\n"
        + '  while [ "$#" -ge 3 ]; do\n'
        + "    _decode_expected=$1; _decode_file=$2; _decode_bytes=$3; shift 3\n"
        + '    if _cfmgr_catalog_decode "$_decode_file" "$_decode_bytes"; then\n'
        + "      _decode_actual=0\n"
        + "    else\n"
        + "      _decode_actual=$?\n"
        + "    fi\n"
        + '    [ "$_decode_actual" = "$_decode_expected" ] || return 1\n'
        + '    _decode_results="$_decode_results$_decode_actual\n"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_decode_results"\n'
        + "}\n"
        + "decode_root=$1; decode_tools=$2; shift 2\n"
        + 'cfmgr_io_test "$decode_root" "$decode_tools" report fixture_catalog_decode "$@"\n'
    )
    args = [str(package.root), str(package.tools)]
    for expected_status, file_path, expected_bytes in cases:
        args.extend((str(expected_status), str(file_path), str(expected_bytes)))
    return package.router.run(script, args)


def test_catalog_ledger_decode_checks_original_bytes_and_exact_eof_as_a_group(
    package_fixture: PackageFixture,
) -> None:
    package = package_fixture
    catalog_data = make_catalog(
        files=(
            ("cfmgr.sh", RAW_PREFIX + "entry.sh"),
            ("modules/z.sh", RAW_PREFIX + "worker.sh"),
        )
    )
    ledger = expected_catalog(catalog_data).encode("ascii")
    root = package.router.path("work/catalog-ledgers")
    root.mkdir()
    exact = root / "exact"
    exact.write_bytes(ledger)
    nul = root / "nul"
    nul.write_bytes(ledger.replace(b"branch\tdevelop\n", b"branch\tdev\x00elop\n"))
    partial = root / "partial"
    partial.write_bytes(ledger[:-1])
    wrong_footer = root / "footer"
    wrong_footer.write_bytes(ledger.replace(b"end\t2\t", b"end\t3\t"))
    trailing = root / "trailing"
    trailing.write_bytes(ledger + b"extra\n")
    partial_trailing = root / "partial-trailing"
    partial_trailing.write_bytes(ledger + b"extra")
    result = catalog_decode_group(
        package,
        (
            (0, exact, len(ledger)),
            (1, nul, len(nul.read_bytes())),
            (1, partial, len(ledger) - 1),
            (1, wrong_footer, len(ledger)),
            (1, exact, len(ledger) + 1),
            (1, trailing, len(trailing.read_bytes())),
            (1, partial_trailing, len(partial_trailing.read_bytes())),
        ),
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "0\n" + "1\n" * 6
    assert_no_io_scratch(package)


def test_catalog_capture_checks_producer_status_and_stderr_with_valid_control(
    package_fixture: PackageFixture,
) -> None:
    package = package_fixture
    catalog_data = make_catalog(
        files=(("cfmgr.sh", RAW_PREFIX + "entry.sh"), ("modules/z.sh", RAW_PREFIX + "worker.sh"))
    )
    catalog_file, parser_file = install_catalog_inputs(package, catalog_data)
    ledger_path = package.router.path("work/catalog-ledger.out")
    ledger_path.write_text(expected_catalog(catalog_data), encoding="ascii")
    mode_path = package.router.path("work/catalog-producer-mode")
    package.replace_tool(
        "awk",
        "mode=$(/bin/cat "
        + shlex.quote(str(mode_path))
        + "); ledger="
        + shlex.quote(str(ledger_path))
        + "\n"
        + "case $mode in\n"
        + '  valid) /bin/cat "$ledger" ;;\n'
        + '  stderr) /bin/cat "$ledger"; printf diagnostic >&2 ;;\n'
        + '  failure) /bin/cat "$ledger"; exit 7 ;;\n'
        + '  parser-error) /bin/cat "$ledger"; exit 2 ;;\n'
        + "  *) exit 9 ;;\n"
        + "esac\n",
    )
    script = (
        catalog_source(package)
        + "fixture_catalog_capture() {\n"
        + "  _capture_stage=$1; shift\n"
        + "  _capture_results=\n"
        + '  while [ "$#" -ge 6 ]; do\n'
        + "    _capture_expected=$1; _capture_mode=$2; _capture_slot=$3\n"
        + "    _capture_input=$4; _capture_helper=$5; _capture_parser=$6; shift 6\n"
        + "    printf '%s' \"$_capture_mode\" > "
        + shlex.quote(str(mode_path))
        + " || return 1\n"
        + '    if _cfmgr_catalog_capture "$_capture_input" '
        + '"$_capture_helper" "$_capture_parser" "$_capture_slot" '
        + '"$((_capture_slot + 1))"; then\n'
        + "      _capture_actual=0\n"
        + "    else\n"
        + "      _capture_actual=$?\n"
        + "    fi\n"
        + '    [ "$_capture_actual" = "$_capture_expected" ] || return 1\n'
        + '    _capture_results="$_capture_results$_capture_actual\n"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_capture_results"\n'
        + "}\n"
        + "capture_root=$1; capture_tools=$2; shift 2\n"
        + 'cfmgr_io_test "$capture_root" "$capture_tools" report fixture_catalog_capture "$@"\n'
    )
    args = [str(package.root), str(package.tools)]
    for slot, (expected_status, mode) in enumerate(
        ((0, "valid"), (1, "stderr"), (1, "failure"), (2, "parser-error"))
    ):
        args.extend(
            (
                str(expected_status),
                mode,
                str(slot * 2),
                str(catalog_file),
                str(package.helper),
                str(parser_file),
            )
        )
    result = package.router.run(script, args)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "0\n1\n1\n2\n"
    assert_no_io_scratch(package)


def catalog_join_group(
    package: PackageFixture,
    cases: tuple[tuple[int, Path, int, Path, int, int], ...],
) -> ShellResult:
    script = (
        catalog_source(package)
        + "fixture_catalog_join() {\n"
        + "  _join_stage=$1; shift\n"
        + "  _catalog_owner=Example-Org; _catalog_repository=CFMgr\n"
        + f"  _catalog_selector={COMMIT}; _catalog_commit={COMMIT}\n"
        + f"  _catalog_pinned_manifest={RAW_PREFIX.replace('{commit}', COMMIT)}"
        + "catalog/manifest.txt\n"
        + "  _join_results=\n"
        + '  while [ "$#" -ge 6 ]; do\n'
        + "    _join_expected=$1; _selected_path=$2; _catalog_count=$3\n"
        + "    _manifest_path=$4; _package_manifest_count=$5\n"
        + "    _package_manifest_total=$6; _package_manifest_version=12.34.56; shift 6\n"
        + '    _catalog_selected_files=$(/bin/cat "$_selected_path")$_io_lf || return 1\n'
        + '    _package_manifest_body=$(/bin/cat "$_manifest_path")$_io_lf || return 1\n'
        + "    if _cfmgr_catalog_join; then _join_actual=0; else _join_actual=$?; fi\n"
        + '    [ "$_join_actual" = "$_join_expected" ] || return 1\n'
        + '    _join_results="$_join_results$_join_actual\n"\n'
        + "  done\n"
        + '  cfmgr_io_stage_report "$_join_results"\n'
        + "}\n"
        + "join_root=$1; join_tools=$2; shift 2\n"
        + 'cfmgr_io_test "$join_root" "$join_tools" report fixture_catalog_join "$@"\n'
    )
    args = [str(package.root), str(package.tools)]
    for expected_status, selected, selected_count, body, manifest_count, total in cases:
        args.extend(
            (
                str(expected_status),
                str(selected),
                str(selected_count),
                str(body),
                str(manifest_count),
                str(total),
            )
        )
    return package.router.run(script, args)


def test_catalog_plan_joins_by_manifest_key_order_and_pins_all_urls(
    package_fixture: PackageFixture,
) -> None:
    package = package_fixture
    payloads = {
        "cfmgr.sh": b"entry bytes",
        "modules/z.sh": b"worker z",
        "modules/a.sh": b"worker a",
    }
    package.configure(payloads)
    catalog_data = make_catalog(
        branch=COMMIT.upper(),
        files=(
            ("modules/a.sh", RAW_PREFIX + "sources/second/worker-a.sh"),
            ("modules/z.sh", RAW_PREFIX + "sources/first/worker-z.sh"),
            ("cfmgr.sh", RAW_PREFIX + "entry/manager/main.sh"),
        ),
        manifest_path="catalog/metadata/package-v1.txt",
    )
    result = plan_result(package, catalog_data)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_plan_report(
        catalog_data, package.input.read_bytes(), COMMIT
    )
    assert result.stdout.encode("ascii").count(COMMIT.encode("ascii")) == 6
    assert_no_io_scratch(package)


def test_maximum_catalog_capture_joins_large_report_with_independent_oracle(
    package_fixture: PackageFixture,
) -> None:
    package = package_fixture
    manifest_rows = [("cfmgr.sh", b"entry", 0o755)]
    file_rows = [
        ("cfmgr.sh", RAW_PREFIX + "source/" + "s" * 80 + "/entry.sh"),
    ]
    for index in range(127):
        destination = f"modules/nested/worker-{index:03}.sh"
        contents = f"worker {index}".encode("ascii")
        manifest_rows.append((destination, contents, 0o644))
        source_path = f"source/{index:03}/" + "s" * 80 + ".sh"
        file_rows.append((destination, RAW_PREFIX + source_path))
    package.input.write_bytes(manifest(tuple(manifest_rows), version="12.34.56"))
    catalog_data = make_catalog(branch="main", files=tuple(file_rows))
    remaining = 32768 - len(catalog_data)
    padding = bytearray()
    line_count = (remaining + 1023) // 1024
    line_size, extra = divmod(remaining, line_count)
    for index in range(line_count):
        current_size = line_size + (index < extra)
        assert 2 <= current_size <= 1024
        padding.extend(b"#" + b"x" * (current_size - 2) + b"\n")
    catalog_data += bytes(padding)
    assert len(catalog_data) == 32768
    expected = expected_plan_report(catalog_data, package.input.read_bytes(), COMMIT)
    assert all(len(line) <= 1024 for line in catalog_data.splitlines(keepends=True))
    assert 32768 < len(expected) <= 65536
    result = plan_result(package, catalog_data)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected
    assert_no_io_scratch(package)


def test_catalog_plan_refuses_selector_mismatch_and_malformed_commit(
    package_fixture: PackageFixture,
) -> None:
    package = package_fixture
    package.configure({"cfmgr.sh": b"entry bytes", "modules/z.sh": b"worker"})
    catalog_data = make_catalog(
        branch="f" * 40,
        files=(("cfmgr.sh", RAW_PREFIX + "entry.sh"), ("modules/z.sh", RAW_PREFIX + "worker.sh")),
    )
    reject(plan_result(package, catalog_data))
    reject(plan_result(package, catalog_data, commit=COMMIT.upper()), 2)
    reject(plan_result(package, catalog_data, commit="bad-commit"), 2)
    assert_no_io_scratch(package)


def test_catalog_join_refuses_count_and_equal_count_key_mismatches_as_a_group(
    package_fixture: PackageFixture,
) -> None:
    package = package_fixture
    package.configure({"cfmgr.sh": b"entry bytes", "modules/z.sh": b"worker"})
    base_manifest = package.input.read_bytes()

    def state(slug: str, rows: tuple[tuple[str, str], ...], source_manifest: bytes) -> tuple:
        selected = package.router.path(f"work/join-selected-{slug}")
        selected.write_text(
            "".join(f"file\t{destination}\t{url}\n" for destination, url in rows),
            encoding="ascii",
        )
        body = package.router.path(f"work/join-manifest-{slug}")
        report = expected_ledger(source_manifest)
        report_body, footer = report.rsplit(b"end\t", 1)
        count, total, _ = footer[:-1].decode("ascii").split("\t")
        body.write_bytes(report_body)
        return selected, int(len(rows)), body, int(count), int(total)

    selected_rows = (
        ("cfmgr.sh", RAW_PREFIX.replace("{commit}", COMMIT) + "entry.sh"),
        ("modules/z.sh", RAW_PREFIX.replace("{commit}", COMMIT) + "source/worker.sh"),
    )
    extra_manifest = manifest(
        (
            ("cfmgr.sh", b"entry bytes", 0o755),
            ("modules/z.sh", b"worker", 0o644),
            ("modules/extra.sh", b"extra", 0o644),
        ),
        version="12.34.56",
    )
    cases = []
    for slug, selected_rows_for_case, manifest_for_case, expected_status in (
        ("valid", selected_rows, base_manifest, 0),
        ("catalog-missing", selected_rows[:1], base_manifest, 1),
        (
            "catalog-extra",
            selected_rows
            + (("modules/extra.sh", RAW_PREFIX.replace("{commit}", COMMIT) + "extra.sh"),),
            base_manifest,
            1,
        ),
        ("manifest-extra", selected_rows, extra_manifest, 1),
        (
            "substituted-key",
            (
                selected_rows[0],
                ("modules/other.sh", RAW_PREFIX.replace("{commit}", COMMIT) + "other.sh"),
            ),
            base_manifest,
            1,
        ),
    ):
        selected_path, selected_count, body_path, manifest_count, total = state(
            slug, selected_rows_for_case, manifest_for_case
        )
        cases.append(
            (expected_status, selected_path, selected_count, body_path, manifest_count, total)
        )
    result = catalog_join_group(package, tuple(cases))
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "0\n" + "1\n" * (len(cases) - 1)
    assert_no_io_scratch(package)


def test_catalog_plan_cleanup_refusal_suppresses_report(package_fixture: PackageFixture) -> None:
    package = package_fixture
    package.configure({"cfmgr.sh": b"entry bytes", "modules/z.sh": b"worker"})
    catalog_data = make_catalog(
        branch=COMMIT,
        files=(("cfmgr.sh", RAW_PREFIX + "entry.sh"), ("modules/z.sh", RAW_PREFIX + "worker.sh")),
    )
    valid = plan_result(package, catalog_data)
    assert valid.returncode == 0 and valid.stderr == ""
    assert valid.stdout.encode("ascii") == expected_plan_report(
        catalog_data, package.input.read_bytes(), COMMIT
    )
    package.replace_tool("rm", "exit 7\n")
    reject(plan_result(package, catalog_data))


def test_actual_busybox_composes_catalog_plan_and_manifest_join(
    busybox_router: RouterHarness,
) -> None:
    package = PackageFixture(busybox_router, busybox=busybox_router.busybox)
    package.configure({"cfmgr.sh": b"entry bytes", "modules/z.sh": b"worker"})
    catalog_data = make_catalog(
        branch=COMMIT.upper(),
        files=(
            ("modules/z.sh", RAW_PREFIX + "different/source/z.sh"),
            ("cfmgr.sh", RAW_PREFIX + "entry.sh"),
        ),
    )
    result = plan_result(package, catalog_data)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_plan_report(
        catalog_data, package.input.read_bytes(), COMMIT
    )
    assert_no_io_scratch(package)
