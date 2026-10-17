"""Fail-closed admission of raw native tar headers before tar sees them."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
from runtime_awk import awk_arguments

ROOT = Path(__file__).resolve().parents[1]
PARSER = "cfmgr-parser:backup_tar"
MAX_I64 = 2**63 - 1


@pytest.fixture(scope="module")
def awk_programs() -> list[tuple[str, list[str]]]:
    found = shutil.which("awk")
    assert found, "Host awk is required for archive header tests"
    programs = [("host awk", [found])]
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        shell = os.environ.get("CFMGR_TEST_SHELL", "").split()
        assert shell[:2] == ["busybox", "ash"], (
            "Required BusyBox shell selection is missing"
        )
        busybox = shutil.which("busybox")
        expected = ROOT / ".tmp/native-busybox/bin/busybox"
        assert busybox and Path(busybox).resolve() == expected.resolve(), (
            "Required archive proof must use staged vendor BusyBox"
        )
        programs.append(("pinned BusyBox awk", [busybox, "awk"]))
    return programs


def _octal(value: int, width: int) -> bytes:
    encoded = f"{value:o}".encode("ascii")
    if len(encoded) > width:
        raise ValueError("value does not fit tar field")
    return encoded.rjust(width, b"0") + b"\0"


def make_header(
    name: str = "manifest", size: int = 0, *, size_mode: str = "octal"
) -> bytes:
    """Build independent old-GNU bytes using Python's integer/byte operations."""
    header = bytearray(512)
    header[: len(name)] = name.encode("ascii")
    header[100:108] = _octal(0o640, 7)
    header[108:116] = _octal(1000, 7)
    header[116:124] = _octal(1000, 7)
    if size_mode == "octal":
        header[124:136] = _octal(size, 11)
    elif size_mode == "full-octal":
        digits = f"{size:o}".encode("ascii")
        assert len(digits) <= 12
        header[124:136] = digits.rjust(12, b"0")
    elif size_mode == "base256":
        assert 0 < size <= MAX_I64
        header[124:136] = b"\x80\0\0\0" + size.to_bytes(8, "big")
    else:
        raise ValueError(size_mode)
    header[136:148] = _octal(1_700_000_000, 11)
    header[156] = ord("0")
    header[257:265] = b"ustar  \0"
    header[265:270] = b"root\0"
    header[297:302] = b"root\0"
    checksum = sum(header[:148]) + 8 * ord(" ") + sum(header[156:])
    header[148:156] = f"{checksum:06o}".encode("ascii") + b"\0 "
    return bytes(header)


def _invoke(
    awk: list[str],
    data: bytes,
    *,
    offset: int | str = 0,
    total: int | str | None = None,
) -> subprocess.CompletedProcess[bytes]:
    environment = {
        **os.environ,
        "LC_ALL": "C",
        "CFMGR_TAR_OFFSET": str(offset),
        "CFMGR_TAR_BYTES": str(total if total is not None else int(offset) + 512),
    }
    return subprocess.run(
        awk_arguments([*awk, "-f", str(PARSER)]),
        input=data,
        capture_output=True,
        check=False,
        env=environment,
        timeout=5,
    )


def _hex(header: bytes, *, newline: bool = True) -> bytes:
    encoded = header.hex().encode("ascii")
    return encoded + (b"\n" if newline else b"")


@pytest.mark.parametrize(
    ("name", "size", "size_mode"),
    [
        ("manifest", 0, "octal"),
        ("inventory", 1, "octal"),
        ("p00000001", 4095, "octal"),
        ("p00000002", 4096, "octal"),
        ("p99999999", 4097, "octal"),
        ("p00000003", 8 * 1024**3, "full-octal"),
        ("p00000004", 64 * 1024**3 - 1, "full-octal"),
        ("p00000005", 64 * 1024**3, "base256"),
        ("p00000006", MAX_I64 - 4095, "base256"),
    ],
)
def test_admits_native_regular_headers(
    awk_programs: list[tuple[str, list[str]]], name: str, size: int, size_mode: str
) -> None:
    end = 512 + ((size + 511) // 512) * 512
    expected = f"CFMGR-TAR-HEADER 1 file {name} {size} 512 {end} END\n".encode()
    for _label, awk in awk_programs:
        result = _invoke(
            awk, _hex(make_header(name, size, size_mode=size_mode)), total=end
        )
        assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")


def test_zero_block_and_unterminated_record(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    for _label, awk in awk_programs:
        result = _invoke(awk, b"00" * 512, offset=512, total=1024)
        assert (result.returncode, result.stdout) == (
            0,
            b"CFMGR-TAR-HEADER 1 zero - 0 1024 1024 END\n",
        )
        result = _invoke(awk, _hex(make_header(), newline=False), total=1024)
        assert result.returncode == 0


def test_preserves_large_aligned_offsets_exactly(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    offset = 9_007_199_254_740_992
    end = offset + 512 + 4096
    expected = (
        f"CFMGR-TAR-HEADER 1 file p00000001 4095 {offset + 512} {end} END\n".encode()
    )
    for _label, awk in awk_programs:
        result = _invoke(
            awk,
            _hex(make_header("p00000001", 4095)),
            offset=offset,
            total=end,
        )
        assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")


def _rechecksum(header: bytearray) -> bytes:
    header[148:156] = b"\0" * 8
    checksum = sum(header[:148]) + 8 * ord(" ") + sum(header[156:])
    header[148:156] = f"{checksum:06o}".encode("ascii") + b"\0 "
    return bytes(header)


def _rejected(
    awk_programs: list[tuple[str, list[str]]], data: bytes, *, total: int = 4096
) -> None:
    for _label, awk in awk_programs:
        result = _invoke(awk, data, total=total)
        assert result.returncode != 0
        assert result.stdout == b""


@pytest.mark.parametrize(
    "mutate",
    [
        lambda h: h.__setitem__(slice(156, 157), b"1"),
        lambda h: h.__setitem__(slice(156, 157), b"2"),
        lambda h: h.__setitem__(slice(156, 157), b"5"),
        lambda h: h.__setitem__(slice(156, 157), b"L"),
        lambda h: h.__setitem__(slice(156, 157), b"K"),
        lambda h: h.__setitem__(slice(156, 157), b"x"),
        lambda h: h.__setitem__(slice(0, 9), b"../escape"),
        lambda h: h.__setitem__(slice(0, 10), b"/absolute/"),
        lambda h: h.__setitem__(slice(345, 346), b"x"),
        lambda h: h.__setitem__(slice(499, 500), b"x"),
        lambda h: h.__setitem__(slice(257, 265), b"ustar\0\00"),
        lambda h: h.__setitem__(slice(100, 108), b"-000640\0"),
        lambda h: h.__setitem__(slice(136, 148), b"-00000000123"),
    ],
)
def test_rejects_unsafe_or_non_native_headers(
    awk_programs: list[tuple[str, list[str]]], mutate
) -> None:
    header = bytearray(make_header("p00000001", 1))
    mutate(header)
    _rejected(awk_programs, _hex(_rechecksum(header)))


def test_rejects_wrong_checksum(awk_programs: list[tuple[str, list[str]]]) -> None:
    header = bytearray(make_header("p00000001", 1))
    header[148] = ord("0") if header[148] != ord("0") else ord("1")
    _rejected(awk_programs, _hex(bytes(header)))


def test_rejects_payload_past_archive_end(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    _rejected(awk_programs, _hex(make_header("p00000001", 1)), total=512)


@pytest.mark.parametrize(
    "bad_input",
    [
        b"",
        b"00" * 511,
        b"00" * 512 + b"\nextra\n",
        b"00" * 511 + b"0g",
        b"00" * 511 + b"FF",
        _hex(make_header()) + b"\n",
    ],
)
def test_rejects_invalid_record_framing(
    awk_programs: list[tuple[str, list[str]]], bad_input: bytes
) -> None:
    _rejected(awk_programs, bad_input)


@pytest.mark.parametrize(
    ("offset", "total"),
    [
        (1, 1024),
        (0, 511),
        ("01", 1024),
        ("+0", 1024),
        (0, "9223372036854775808"),
    ],
)
def test_rejects_invalid_archive_bounds(
    awk_programs: list[tuple[str, list[str]]], offset: int | str, total: int | str
) -> None:
    for _label, awk in awk_programs:
        result = _invoke(awk, _hex(make_header()), offset=offset, total=total)
        assert result.returncode != 0
        assert result.stdout == b""


def test_rejects_base256_overflow_and_noncanonical_small_value(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    for value in (MAX_I64 + 1,):
        header = bytearray(make_header("p00000001", 1))
        header[124:136] = b"\x80\0\0\0" + value.to_bytes(8, "big")
        _rejected(awk_programs, _hex(_rechecksum(header)), total=MAX_I64)
    negative = bytearray(make_header("p00000001", 1))
    negative[124:136] = b"\xc0\0\0\0" + (1).to_bytes(8, "big")
    _rejected(awk_programs, _hex(_rechecksum(negative)))
    small = bytearray(make_header("p00000001", 1))
    small[124:136] = b"\x80\0\0\0" + (4096).to_bytes(8, "big")
    _rejected(awk_programs, _hex(_rechecksum(small)))
