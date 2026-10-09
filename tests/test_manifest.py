"""Bounded manager-package manifest parsing and canonical-ledger evidence."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

LIB = Path(__file__).resolve().parents[1] / "modules/lib"
SOURCE = LIB / "manifest.awk"
PATH_HELPERS = LIB / "package_path.awk"
HOST_AWKS = sorted(
    {
        str(Path(path).resolve())
        for path in ("/usr/bin/awk", "/usr/local/bin/awk", shutil.which("awk"))
        if path and Path(path).is_file()
    }
)
HASH = "0123456789abcdef" * 4
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V32", evidence="host")]


Record = tuple[str, str, str, str]


def manifest(
    *,
    version: str = "1.2.3",
    records: tuple[Record, ...] | None = None,
    prefix: tuple[str, ...] = (),
    metadata_order: tuple[str, ...] = ("manifest", "version", "config-schema", "package-api"),
) -> bytes:
    if records is None:
        records = (
            ("cfmgr.sh", "1", HASH, "0755"),
            ("modules/lib/common.sh", "2", "A" * 64, "0644"),
        )
    metadata = {
        "manifest": "1",
        "version": version,
        "config-schema": "1",
        "package-api": "1",
    }
    lines = [*prefix, *(f"{key}: {metadata[key]}" for key in metadata_order)]
    lines.extend(
        f"{destination}: {size} {sha256} {mode}" for destination, size, sha256, mode in records
    )
    return ("\n".join(lines) + "\n").encode("ascii")


def expected_ledger(version: str, records: tuple[Record, ...]) -> str:
    body = "manifest\t1\n"
    body += f"version\t{version}\nconfig-schema\t1\npackage-api\t1\n"
    body += "".join(
        f"file\t{destination}\t{size}\t{sha256.lower()}\t{mode}\n"
        for destination, size, sha256, mode in records
    )
    total = sum(int(size) for _, size, _, _ in records)
    return body + f"end\t{len(records)}\t{total}\t{len(body.encode('ascii'))}\n"


@pytest.fixture(params=HOST_AWKS, ids=lambda path: path)
def native_awk(router: RouterHarness, request: pytest.FixtureRequest) -> RouterHarness:
    router.path("bin/awk").symlink_to(request.param)
    router.write("work/package_path.awk", PATH_HELPERS.read_text(encoding="utf-8"))
    router.write("work/manifest.awk", SOURCE.read_text(encoding="utf-8"))
    return router


def invoke(
    router: RouterHarness,
    document: bytes,
    *,
    size: str | None = None,
    operands: tuple[str, ...] = (),
    locale: str = "C",
) -> ShellResult:
    assert len(document) <= router.FILE_LIMIT
    path = router.path("ram/manifest")
    path.write_bytes(document)
    path.chmod(0o600)
    args = []
    if size != "MISSING":
        args.extend(["-v", "cfmgr_manifest_size=" + (str(len(document)) if size is None else size)])
    args.extend(
        [
            "-f",
            str(router.path("work/package_path.awk")),
            "-f",
            str(router.path("work/manifest.awk")),
            *operands,
        ]
    )
    return router.run('awk "$@" < "$RAM_ROOT/manifest"\n', args, env={"LC_ALL": locale})


def reject(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status
    assert result.stdout == result.stderr == ""


def test_valid_manifest_has_independent_literal_ledger_and_preserves_file_order(
    native_awk: RouterHarness,
) -> None:
    records = (
        ("modules/helpers/update/deep.sh", "29", "b" * 64, "0644"),
        ("cfmgr.sh", "17", "A" * 64, "0755"),
    )
    document = manifest(
        version="12.34.56",
        records=records,
        prefix=("# immutable package inventory", ""),
        metadata_order=("package-api", "version", "manifest", "config-schema"),
    )
    result = invoke(native_awk, document)
    assert result.returncode == 0
    body = (
        "manifest\t1\n"
        "version\t12.34.56\n"
        "config-schema\t1\n"
        "package-api\t1\n"
        f"file\tmodules/helpers/update/deep.sh\t29\t{'b' * 64}\t0644\n"
        f"file\tcfmgr.sh\t17\t{'a' * 64}\t0755\n"
    )
    assert result.stdout == body + f"end\t2\t46\t{len(body.encode('ascii'))}\n"
    assert result.stderr == ""


def test_shared_path_helper_has_no_input_action(native_awk: RouterHarness) -> None:
    document = b"helper input must not be printed\n"
    path = native_awk.path("ram/helper-only")
    path.write_bytes(document)
    result = native_awk.run(
        'awk -f "$HELPER" < "$RAM_ROOT/helper-only"\n',
        env={"HELPER": str(native_awk.path("work/package_path.awk"))},
    )
    assert result.returncode == 0
    assert result.stdout == result.stderr == ""


def test_version_uses_three_canonical_components_and_accepts_128_bytes(
    native_awk: RouterHarness,
) -> None:
    version = f"{'9' * 42}.{'8' * 42}.{'7' * 42}"
    assert len(version) == 128
    document = manifest(version=version)
    result = invoke(native_awk, document)
    assert result.returncode == 0
    records = (("cfmgr.sh", "1", HASH, "0755"), ("modules/lib/common.sh", "2", "A" * 64, "0644"))
    assert result.stdout == expected_ledger(version, records)
    zero_version = manifest(version="0.0.0")
    zero_result = invoke(native_awk, zero_version)
    assert zero_result.returncode == 0
    assert zero_result.stdout == expected_ledger("0.0.0", records)
    invalid_versions = (
        version + "0",
        "01.2.3",
        "+1.2.3",
        "1.2",
        "1.2.3.4",
        ".1.2",
        "1..2",
        "1.2.",
        "1.2.3-rc1",
        "1.2.3+build",
    )
    for invalid in invalid_versions:
        reject(invoke(native_awk, manifest(version=invalid)))


def test_file_size_and_aggregate_byte_boundaries(native_awk: RouterHarness) -> None:
    accepted = (
        ("cfmgr.sh", "1", HASH, "0755"),
        ("modules/max.bin", "1048576", "b" * 64, "0644"),
    )
    result = invoke(native_awk, manifest(records=accepted))
    assert result.returncode == 0
    assert result.stdout == expected_ledger("1.2.3", accepted)

    maximum_total = (("cfmgr.sh", "1048576", HASH, "0755"),) + tuple(
        (f"modules/f{index}", "1048576", f"{index:064x}", "0644") for index in range(1, 8)
    )
    result = invoke(native_awk, manifest(records=maximum_total))
    assert result.returncode == 0
    assert result.stdout == expected_ledger("1.2.3", maximum_total)
    over_total = maximum_total + (("modules/over", "1", "f" * 64, "0644"),)
    reject(invoke(native_awk, manifest(records=over_total)))

    for invalid_size in ("0", "01", "1048577", "+1"):
        bad = (("cfmgr.sh", invalid_size, HASH, "0755"),)
        reject(invoke(native_awk, manifest(records=bad)))


def test_file_count_boundaries_and_late_failure_emit_no_partial_ledger(
    native_awk: RouterHarness,
) -> None:
    maximum = (("cfmgr.sh", "1", HASH, "0755"),) + tuple(
        (f"modules/f{index:03d}", "1", f"{index:064x}", "0644") for index in range(127)
    )
    result = invoke(native_awk, manifest(records=maximum))
    assert result.returncode == 0
    assert result.stdout == expected_ledger("1.2.3", maximum)

    too_many = maximum + (("modules/f128", "1", "f" * 64, "0644"),)
    reject(invoke(native_awk, manifest(records=too_many)))
    malformed_last = manifest(records=maximum).replace(b"modules/f126: 1 ", b"modules/f126:  1 ")
    reject(invoke(native_awk, malformed_last))
    reject(invoke(native_awk, manifest(records=(("modules/only.sh", "1", HASH, "0644"),))))


def test_hash_mode_root_entry_reserved_paths_and_collisions(native_awk: RouterHarness) -> None:
    good = (("cfmgr.sh", "1", "F" * 64, "0755"),)
    accepted = invoke(native_awk, manifest(records=good))
    assert accepted.returncode == 0
    assert accepted.stdout == expected_ledger("1.2.3", good)

    invalid_records = (
        (("cfmgr.sh", "1", HASH, "0644"),),
        (("cfmgr.sh", "1", HASH[:-1], "0755"),),
        (("cfmgr.sh", "1", HASH + "a", "0755"),),
        (("cfmgr.sh", "1", "g" + HASH[1:], "0755"),),
        (("cfmgr.sh", "1", HASH, "755"),),
        (("cfmgr.sh", "1", HASH, "0640"),),
        (("modules/config", "1", HASH, "0644"), ("cfmgr.sh", "1", HASH, "0755")),
        (("modules/config/private", "1", HASH, "0644"), ("cfmgr.sh", "1", HASH, "0755")),
        (("modules/catalog.txt", "1", HASH, "0644"), ("cfmgr.sh", "1", HASH, "0755")),
        (("modules/catalog.txt/old", "1", HASH, "0644"), ("cfmgr.sh", "1", HASH, "0755")),
        (
            ("modules/a", "1", HASH, "0644"),
            ("modules/a/b", "1", HASH, "0644"),
            ("cfmgr.sh", "1", HASH, "0755"),
        ),
        (("cfmgr.sh", "1", HASH, "0755"), ("cfmgr.sh", "1", HASH, "0755")),
    )
    for records in invalid_records:
        reject(invoke(native_awk, manifest(records=records)))


def test_exact_input_bound_invocation_and_record_spacing(native_awk: RouterHarness) -> None:
    document = manifest()
    padding_size = native_awk.FILE_LIMIT - len(document)
    padding = bytearray()
    if padding_size % 2:
        padding.extend(b"#x\n")
        padding_size -= 3
    while padding_size:
        line_size = min(1024, padding_size)
        if line_size % 2:
            line_size -= 1
        assert 2 <= line_size <= 1024
        padding.extend(b"#" + b"x" * (line_size - 2) + b"\n")
        padding_size -= line_size
    exact = document + bytes(padding)
    assert len(exact) == native_awk.FILE_LIMIT
    result = invoke(native_awk, exact)
    assert result.returncode == 0
    records = (("cfmgr.sh", "1", HASH, "0755"), ("modules/lib/common.sh", "2", "A" * 64, "0644"))
    assert result.stdout == expected_ledger("1.2.3", records)
    accepted_line = ("#" + "x" * 1023).encode("ascii")
    assert len(accepted_line) == 1024
    maximum_line = manifest(prefix=(accepted_line.decode("ascii"),))
    assert invoke(native_awk, maximum_line).returncode == 0

    reject(invoke(native_awk, document, size="MISSING"), 2)
    reject(invoke(native_awk, document, size="0"), 2)
    reject(invoke(native_awk, document, size="01"), 2)
    reject(invoke(native_awk, document, size="65537"), 2)
    reject(invoke(native_awk, document, size=str(len(document) - 1)))
    reject(invoke(native_awk, document, operands=("extra",)), 2)
    reject(invoke(native_awk, document, locale="C.UTF-8"), 2)

    oversized_line = b"#" + b"x" * 1024
    assert len(oversized_line) == 1025
    malformed_documents = (
        document.replace(b"modules/lib/common.sh: 2 ", b"modules/lib/common.sh:  2 "),
        document[:-1],
        document + b"extra\n",
        document.replace(b"manifest: 1\n", b"manifest: 1\r\n"),
        document.replace(b"manifest: 1\n", b"manifest:\t1\n"),
        document.replace(b"manifest: 1\n", b"manifest: 1\nmanifest: 1\n"),
        document.replace(b"manifest: 1\n", b"manifest: 2\n"),
        document.replace(b"manifest: 1\n", b"unexpected: value\nmanifest: 1\n"),
        document + b"bad\xff\n",
        document + b"bad\x7fbyte\n",
        document.replace(b"manifest: 1\n", b"manifest: 1\x00\n"),
        document.replace(b"manifest: 1\n", b"manifest: 1\x1c\n"),
        document + oversized_line + b"\n",
    )
    for malformed in malformed_documents:
        reject(invoke(native_awk, malformed))

    metadata_keys = ("manifest", "version", "config-schema", "package-api")
    for key in metadata_keys:
        line = f"{key}: ".encode("ascii")
        current_value = b"1.2.3" if key == "version" else b"1"
        entry = line + current_value + b"\n"
        reject(invoke(native_awk, document.replace(entry, b"", 1)))
        duplicate = entry + entry
        reject(invoke(native_awk, document.replace(entry, duplicate, 1)))

    for key in ("manifest", "config-schema", "package-api"):
        entry = f"{key}: 1\n".encode("ascii")
        for invalid_value in (b"2", b"01", b"1.0"):
            replacement = f"{key}: ".encode("ascii") + invalid_value + b"\n"
            reject(invoke(native_awk, document.replace(entry, replacement, 1)))


@pytest.mark.busybox
@pytest.mark.matrix("V32", evidence="busybox")
def test_actual_busybox_manifest_record_framing_and_canonical_ledger(
    busybox_router: RouterHarness,
) -> None:
    busybox_router.busybox_applets("awk")
    busybox_router.write("work/package_path.awk", PATH_HELPERS.read_text(encoding="utf-8"))
    busybox_router.write("work/manifest.awk", SOURCE.read_text(encoding="utf-8"))
    document = manifest()
    result = invoke(busybox_router, document)
    assert result.returncode == 0
    assert result.stdout == expected_ledger(
        "1.2.3", (("cfmgr.sh", "1", HASH, "0755"), ("modules/lib/common.sh", "2", "A" * 64, "0644"))
    )
    reject(invoke(busybox_router, document.replace(b" 2 ", b"  2 ")))
    reject(invoke(busybox_router, document + b"bad\x00byte\n"))
