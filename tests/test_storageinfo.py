"""Native observation parsing evidence; no live storage authority is established."""

from __future__ import annotations

import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

SOURCE = Path(__file__).resolve().parents[1] / "modules/storageinfo.awk"
HOST_AWKS = sorted(
    {
        str(Path(path).resolve())
        for path in ("/usr/bin/awk", "/usr/local/bin/awk", shutil.which("awk"))
        if path and Path(path).is_file()
    }
)
DEVICE = "/dev/synthetic"
FDINFO = b"pos:\t0\nflags:\t0100000\nmnt_id:\t42\n"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


@pytest.fixture(params=HOST_AWKS, ids=lambda path: path)
def native_awk(router: RouterHarness, request: pytest.FixtureRequest) -> RouterHarness:
    router.path("bin/awk").symlink_to(request.param)
    router.write("work/storageinfo.awk", SOURCE.read_text())
    return router


def invoke(
    router: RouterHarness,
    data: bytes,
    mode: str | None = "fdinfo",
    *,
    size: str | None = None,
    device: str | None = DEVICE,
    locale: str = "C",
    operands: tuple[str, ...] = (),
) -> ShellResult:
    assert len(data) <= router.FILE_LIMIT
    path = router.path("ram/observation")
    path.write_bytes(data)
    path.chmod(0o600)
    args = []
    if mode is not None:
        args.extend(["-v", "cfmgr_storageinfo_mode=" + mode])
    if size != "MISSING":
        args.extend(["-v", "cfmgr_storageinfo_size=" + (str(len(data)) if size is None else size)])
    args.extend(["-f", str(router.path("work/storageinfo.awk")), *operands])
    environment = {"LC_ALL": locale}
    if device is not None:
        environment["CFMGR_BLKID_DEVICE"] = device
    return router.run('awk "$@" < "$RAM_ROOT/observation"\n', args, env=environment)


def quiet(result: ShellResult, status: int) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == ""


def ledger(*fields: str) -> str:
    body = "\t".join(fields) + "\n"
    return body + f"end\t{len(body.encode('ascii'))}\n"


def success(result: ShellResult, expected: str) -> None:
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == expected
    lines = result.stdout.encode("ascii").splitlines(keepends=True)
    assert len(lines) == 2 and all(line.endswith(b"\n") for line in lines)
    assert lines[1] == b"end\t" + str(len(lines[0])).encode() + b"\n"


@pytest.mark.parametrize(
    "identifier", ["1", "42", "9007199254740992", "9007199254740993", "9" * 20]
)
def test_fdinfo_preserves_mount_id_text(native_awk: RouterHarness, identifier: str) -> None:
    data = (
        b"pos:\t99999999999999999999\nflags:\t0000000000000000\nmnt_id:\t"
        + identifier.encode()
        + b"\n"
    )
    success(invoke(native_awk, data), ledger("fdinfo", identifier))


def test_fdinfo_unknown_unique_fields_and_horizontal_spacing(native_awk: RouterHarness) -> None:
    data = b"_future9: \t printable\tvalue \t\nflags: 007\nmnt_id: \t42\npos: 0\n"
    success(invoke(native_awk, data, device="invalid ignored device"), ledger("fdinfo", "42"))


@pytest.mark.parametrize("device", [None, "relative", "/dev/../bad"])
def test_fdinfo_does_not_require_blkid_environment(
    native_awk: RouterHarness, device: str | None
) -> None:
    success(invoke(native_awk, FDINFO, device=device), ledger("fdinfo", "42"))


def test_legacy_fdinfo_without_mount_id_is_distinct(native_awk: RouterHarness) -> None:
    quiet(invoke(native_awk, b"pos:\t0\nflags:\t0100000\n"), 3)


@pytest.mark.parametrize(
    "data",
    [
        b"",
        b"\n",
        FDINFO[:-1],
        FDINFO + b"\n",
        FDINFO + b"trailing",
        b"flags: 01\nmnt_id: 42\n",
        b"pos: 0\nmnt_id: 42\n",
        FDINFO + b"pos: 1\n",
        FDINFO + b"flags: 1\n",
        FDINFO + b"mnt_id: 43\n",
        FDINFO + b"future: value\nfuture: second\n",
        FDINFO.replace(b"pos:\t0", b"pos:0"),
        FDINFO.replace(b"pos:\t0", b"pos: \t"),
        FDINFO.replace(b"pos:\t0", b"pos: 00"),
        FDINFO.replace(b"pos:\t0", b"pos: -1"),
        FDINFO.replace(b"pos:\t0", b"pos: " + b"9" * 21),
        FDINFO.replace(b"flags:\t0100000", b"flags: 08"),
        FDINFO.replace(b"flags:\t0100000", b"flags: " + b"0" * 17),
        FDINFO.replace(b"mnt_id:\t42", b"mnt_id: 0"),
        FDINFO.replace(b"mnt_id:\t42", b"mnt_id: 042"),
        FDINFO.replace(b"mnt_id:\t42", b"mnt_id: " + b"9" * 21),
        FDINFO + b"9invalid: value\n",
        FDINFO + b"bad-key: value\n",
        FDINFO + b"future: \xff\n",
        FDINFO + b"future: \r\n",
        FDINFO + b"future: \x7f\n",
    ],
)
def test_fdinfo_malformed_records_fail_quietly(native_awk: RouterHarness, data: bytes) -> None:
    quiet(invoke(native_awk, data), 1)


def test_fdinfo_record_count_exact_boundary(native_awk: RouterHarness) -> None:
    data = FDINFO + b"".join(f"field{i}: value\n".encode() for i in range(61))
    assert len(data.splitlines()) == 64
    success(invoke(native_awk, data), ledger("fdinfo", "42"))
    quiet(invoke(native_awk, data + b"extra: value\n"), 1)


def test_fdinfo_input_byte_limit_exact_boundary(native_awk: RouterHarness) -> None:
    prefix = FDINFO + b"future: "
    data = prefix + b"x" * (4096 - len(prefix) - 1) + b"\n"
    assert len(data) == 4096
    success(invoke(native_awk, data), ledger("fdinfo", "42"))
    quiet(invoke(native_awk, data + b"x", size="4096"), 1)
    quiet(invoke(native_awk, data + b"x"), 2)


@pytest.mark.parametrize(
    "size", ["MISSING", "", "-1", "+1", "00", "01", "4097", "99999", "1.0", "1e1", " 1", "1 "]
)
def test_invalid_size_assignments_are_usage_errors(native_awk: RouterHarness, size: str) -> None:
    quiet(invoke(native_awk, FDINFO, size=size), 2)


@pytest.mark.parametrize("mode", [None, "", "FDINFO", "unknown", "fdinfo "])
def test_invalid_modes_are_usage_errors(native_awk: RouterHarness, mode: str | None) -> None:
    quiet(invoke(native_awk, FDINFO, mode), 2)


def test_locale_and_filename_operands_are_usage_errors(native_awk: RouterHarness) -> None:
    quiet(invoke(native_awk, FDINFO, locale="POSIX"), 2)
    quiet(invoke(native_awk, FDINFO, operands=("/dev/null",)), 2)


@pytest.mark.parametrize("size", ["0", "1", str(len(FDINFO) - 1), str(len(FDINFO) + 1)])
def test_false_original_size_rejects_without_partial_output(
    native_awk: RouterHarness, size: str
) -> None:
    quiet(invoke(native_awk, FDINFO, size=size), 1)


@pytest.mark.parametrize("control", [b"\x00", b"\x1c", b"\x01", b"\r", b"\x7f"])
def test_raw_control_at_each_framing_position(native_awk: RouterHarness, control: bytes) -> None:
    for data in (control + FDINFO, FDINFO[:5] + control + FDINFO[5:], FDINFO + control):
        quiet(invoke(native_awk, data), 1)


def test_parser_creates_no_files_and_executes_no_helpers(native_awk: RouterHarness) -> None:
    native_awk.fake_tool("touch", 'printf "unexpected process\\n" >&2; exit 99\n')
    success(
        invoke(native_awk, FDINFO + b'future: $(touch forbidden); system("touch forbidden")\n'),
        ledger("fdinfo", "42"),
    )
    assert not native_awk.path("work/forbidden").exists()
    assert list(native_awk.path("ram/tmp").iterdir()) == []


def blkid_record(*attributes: tuple[str, bytes], device: str = DEVICE) -> bytes:
    return (
        device.encode()
        + b": "
        + b" ".join(key.encode() + b'="' + value + b'"' for key, value in attributes)
        + b"\n"
    )


@pytest.mark.parametrize(
    ("uuid", "kind"),
    [
        (b"A12B-00ff", None),
        (b"00000000", b"ext4"),
        (b"-", b"_future.fs+1-2"),
        (b"F" * 128, b"T" * 64),
    ],
)
def test_label_free_blkid_preserves_exact_identity_bytes(
    native_awk: RouterHarness, uuid: bytes, kind: bytes | None
) -> None:
    attributes = [("UUID", uuid)]
    if kind is not None:
        attributes.append(("TYPE", kind))
    success(
        invoke(native_awk, blkid_record(*attributes), "blkid"),
        ledger("blkid", uuid.hex(), "-" if kind is None else kind.hex()),
    )


@pytest.mark.parametrize(
    "data",
    [
        b"",
        blkid_record(("LABEL", b"")),
        blkid_record(("LABEL", b"ordinary label")),
        blkid_record(("TYPE", b"ext4")),
        blkid_record(("LABEL", b"ordinary"), ("UUID", b"a1-b2")),
        blkid_record(("LABEL", b""), ("UUID", b"a1-b2"), ("TYPE", b"ext4")),
        blkid_record(("LABEL", b"backslash\\n and \xff"), ("UUID", b"a1-b2")),
    ],
)
def test_blkid_unavailable_or_label_ambiguous_identity_is_distinct(
    native_awk: RouterHarness, data: bytes
) -> None:
    quiet(invoke(native_awk, data, "blkid"), 3)


def test_raw_native_label_can_impersonate_uuid_and_is_never_accepted(
    native_awk: RouterHarness,
) -> None:
    # BusyBox's raw quoted %s output cannot distinguish these two situations:
    # a normal LABEL+UUID, or a label-only filesystem containing embedded quotes.
    raw_label = b'a" UUID="deadbeef'
    label_only_producer = DEVICE.encode() + b': LABEL="' + raw_label + b'"\n'
    ordinary_producer = blkid_record(("LABEL", b"a"), ("UUID", b"deadbeef"))
    assert label_only_producer == ordinary_producer
    quiet(invoke(native_awk, label_only_producer, "blkid"), 3)
    # A real UUID after the injected one is a duplicate, hence malformed.
    quiet(invoke(native_awk, label_only_producer[:-1] + b' UUID="abcd"\n', "blkid"), 1)


@pytest.mark.parametrize(
    "data",
    [
        blkid_record(("UUID", b"")),
        blkid_record(("UUID", b"a" * 129)),
        blkid_record(("UUID", b"abc_def")),
        blkid_record(("UUID", b"ab cd")),
        blkid_record(("UUID", b"ab\\n")),
        blkid_record(("UUID", b"\xff")),
        blkid_record(("UUID", b"ab"), ("TYPE", b"")),
        blkid_record(("UUID", b"ab"), ("TYPE", b"t" * 65)),
        blkid_record(("UUID", b"ab"), ("TYPE", b".ext4")),
        blkid_record(("UUID", b"ab"), ("TYPE", b"ext/4")),
        blkid_record(("UUID", b"ab"), ("UUID", b"cd")),
        blkid_record(("TYPE", b"ext4"), ("UUID", b"ab")),
        blkid_record(("UUID", b"ab"), ("LABEL", b"label")),
        blkid_record(("LABEL", b"label"), ("LABEL", b"second")),
        blkid_record(("UUID", b"ab"), ("PARTUUID", b"cd")),
        blkid_record(("UUID", b"ab"), device="/dev/wrong"),
        b'/dev/synthetic: UUID="ab" \n',
        b'/dev/synthetic:  UUID="ab"\n',
        b'/dev/synthetic: UUID="ab"  TYPE="ext4"\n',
        b'/dev/synthetic:UUID="ab"\n',
        b'/dev/synthetic: UUID="ab"TYPE="ext4"\n',
        b"/dev/synthetic: UUID=ab\n",
        b'/dev/synthetic: UUID="ab\n',
        b'/dev/synthetic: UUID="ab"',
        b'/dev/synthetic: LABEL="a"b" UUID="ab"\n',
        b'/dev/synthetic: LABEL="a\nb" UUID="ab"\n',
        b'/dev/synthetic: LABEL="a\tb" UUID="ab"\n',
        b'/dev/synthetic: LABEL="a\rb" UUID="ab"\n',
        b"/dev/synthetic: \n",
        b"\n",
        blkid_record(("UUID", b"ab")) + b"\n",
        blkid_record(("UUID", b"ab")) * 2,
        blkid_record(("UUID", b"ab")) + b"junk",
    ],
)
def test_blkid_strict_single_record_attribute_profile(
    native_awk: RouterHarness, data: bytes
) -> None:
    quiet(invoke(native_awk, data, "blkid"), 1)


@pytest.mark.parametrize(
    "device",
    [
        None,
        "",
        "relative",
        "/dev",
        "/dev/",
        "/other/device",
        "/dev//a",
        "/dev/a/",
        "/dev/./a",
        "/dev/a/../b",
        "/dev/a\t",
        "/dev/a\n",
        "/dev/a\x7f",
        "/dev/" + "a" * 252,
    ],
)
def test_blkid_device_environment_must_be_canonical(
    native_awk: RouterHarness, device: str | None
) -> None:
    quiet(invoke(native_awk, b"", "blkid", device=device), 2)


def test_literal_device_environment_bypasses_v_escape_decoding(native_awk: RouterHarness) -> None:
    device = '/dev/weird space/\\040\\n\\x41:="literal"'
    data = blkid_record(("UUID", b"aB-12"), device=device)
    success(invoke(native_awk, data, "blkid", device=device), ledger("blkid", b"aB-12".hex(), "-"))
    device = "/dev/" + "a" * 251
    assert len(device.encode()) == 256
    success(
        invoke(native_awk, blkid_record(("UUID", b"ab"), device=device), "blkid", device=device),
        ledger("blkid", "6162", "-"),
    )


def test_blkid_exact_input_limit_still_withholds_label_identity(native_awk: RouterHarness) -> None:
    base = blkid_record(("LABEL", b""), ("UUID", b"ab"))
    data = blkid_record(("LABEL", b"x" * (4096 - len(base))), ("UUID", b"ab"))
    assert len(data) == 4096
    quiet(invoke(native_awk, data, "blkid"), 3)
    quiet(invoke(native_awk, data + b"x", "blkid", size="4096"), 1)
    quiet(invoke(native_awk, data + b"x", "blkid"), 2)


def test_blkid_raw_nul_and_record_separator_and_false_byte_counts(
    native_awk: RouterHarness,
) -> None:
    data = blkid_record(("UUID", b"ab"))
    for control in (b"\x00", b"\x1c"):
        for corrupted in (control + data, data[:6] + control + data[6:], data + control):
            quiet(invoke(native_awk, corrupted, "blkid"), 1)
    quiet(invoke(native_awk, b"", "blkid", size="1"), 1)
    quiet(invoke(native_awk, data, "blkid", size=str(len(data) - 1)), 1)
    quiet(invoke(native_awk, data, "blkid", size=str(len(data) + 1)), 1)


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_optional_actual_busybox_storage_observations(busybox_router: RouterHarness) -> None:
    busybox_router.busybox_applets("awk")
    busybox_router.write("work/storageinfo.awk", SOURCE.read_text())
    success(invoke(busybox_router, FDINFO), ledger("fdinfo", "42"))
    success(
        invoke(busybox_router, blkid_record(("UUID", b"AB-12")), "blkid"),
        ledger("blkid", b"AB-12".hex(), "-"),
    )
    quiet(
        invoke(busybox_router, blkid_record(("LABEL", b"ordinary"), ("UUID", b"AB-12")), "blkid"), 3
    )
    quiet(invoke(busybox_router, FDINFO + b"\x00"), 1)
