"""Byte-framed literal entry-version parser evidence."""

from __future__ import annotations

import shlex
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

PARSER = Path(__file__).resolve().parents[1] / "modules/lib/entry_version.awk"
HOST_AWKS = sorted(
    {
        str(Path(path).resolve())
        for path in ("/usr/bin/awk", "/usr/local/bin/awk", shutil.which("awk"))
        if path and Path(path).is_file() and Path(path).stat().st_mode & 0o111
    }
)
assert HOST_AWKS, "a host awk is required for entry-version parser evidence"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def report(version: bytes) -> bytes:
    body = b"entry-version\t" + version + b"\n"
    return body + b"end\t" + str(len(body)).encode("ascii") + b"\n"


def parse(
    router: RouterHarness,
    source: bytes,
    *,
    size: str | None = None,
    awk: str = HOST_AWKS[0],
    operand: bool = False,
    locale: str = "C",
) -> ShellResult:
    input_path = router.path("work/entry-version-input")
    input_path.write_bytes(source)
    command = [awk]
    if size is not None:
        command.extend(("-v", f"cfmgr_entry_size={size}"))
    command.extend(("-f", str(PARSER)))
    if operand:
        command.append(str(input_path))
    return router.run(
        f"LC_ALL={shlex.quote(locale)}; export LC_ALL\n"
        + " ".join(map(shlex.quote, command))
        + f" < {shlex.quote(str(input_path))}\n"
    )


def assert_rejected(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status
    assert result.stdout == result.stderr == ""


def test_parser_accepts_literal_candidates_and_unrelated_source_bytes(
    router: RouterHarness,
) -> None:
    versions = (
        (b"CFMGR_VERSION=0.0.0", b"0.0.0"),
        (
            b"#!/bin/sh\n# CFMGR_VERSION=9.9.9 is only a comment\nCFMGR_VERSION=1.2.3\n",
            b"1.2.3",
        ),
        (b"CFMGR_VERSION=1.2.3", b"1.2.3"),  # Optional final LF.
        (b"\x80\r\n# unrelated CR and high byte\nCFMGR_VERSION=4.5.6\n", b"4.5.6"),
    )
    for source, version in versions:
        result = parse(router, source, size=str(len(source)))
        assert result.returncode == 0 and result.stderr == ""
        assert result.stdout.encode("ascii") == report(version)

    max_version = b"9" * 41 + b"." + b"8" * 42 + b"." + b"7" * 43
    assert len(max_version) == 128
    source = b"CFMGR_VERSION=" + max_version + b"\n"
    result = parse(router, source, size=str(len(source)))
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == report(max_version)


def test_parser_rejects_ambiguous_and_nonliteral_declarations_as_a_group(
    router: RouterHarness,
) -> None:
    invalid = (
        b"# CFMGR_VERSION=1.2.3 is only a comment\n",
        b"CFMGR_VERSION=1.2.3\nCFMGR_VERSION=1.2.3\n",
        b"export CFMGR_VERSION=1.2.3\n",
        b"readonly CFMGR_VERSION=1.2.3\n",
        b" CFMGR_VERSION=1.2.3\n",
        b"CFMGR_VERSION=01.2.3\n",
        b"CFMGR_VERSION=1.2\n",
        b"CFMGR_VERSION=1.2.3.4\n",
        b"CFMGR_VERSION=-1.2.3\n",
        b"CFMGR_VERSION=\n",
        b"CFMGR_VERSION=1.2.3 trailing\n",
        b"CFMGR_VERSION=1.2.3 \n",
        b"CFMGR_VERSION=1.2.3\r\n",
        b'CFMGR_VERSION="1.2.3"\n',
        b"CFMGR_VERSION=${version}\n",
        b"CFMGR_VERSION=1.2.3\nexport CFMGR_VERSION=1.2.3\n",
    )
    for source in invalid:
        assert_rejected(parse(router, source, size=str(len(source))))

    too_long = b"9" * 43 + b"." + b"8" * 42 + b"." + b"7" * 42
    assert len(too_long) == 129
    source = b"CFMGR_VERSION=" + too_long + b"\n"
    assert_rejected(parse(router, source, size=str(len(source))))


def test_parser_enforces_canonical_size_and_rejects_extra_operands(router: RouterHarness) -> None:
    source = b"CFMGR_VERSION=1.2.3\n"
    for bad_size in (None, "", "0", "01", "1048577", "10000000"):
        assert_rejected(parse(router, source, size=bad_size), status=2)

    assert_rejected(parse(router, source, size=str(len(source) + 1)))
    assert_rejected(parse(router, source, size=str(len(source)), operand=True), status=2)
    assert_rejected(parse(router, source, size=str(len(source)), locale="C.UTF-8"), status=2)


def test_parser_rejects_global_nul_and_record_separator_bytes(router: RouterHarness) -> None:
    valid = b"CFMGR_VERSION=1.2.3\n"
    invalid = (
        b"\x00" + valid,
        valid + b"\x00",
        b"# unrelated \x00 byte\n" + valid,
        b"\x1c" + valid,
        valid + b"\x1c",
        b"# unrelated \x1c byte\n" + valid,
    )
    for source in invalid:
        assert_rejected(parse(router, source, size=str(len(source))))


def test_parser_scans_lf_dense_one_mib_entry(router: RouterHarness) -> None:
    prefix = b"CFMGR_VERSION=7.8.9\n"
    source = prefix + b"\n" * (1_048_576 - len(prefix))
    assert len(source) == 1_048_576
    result = parse(router, source, size="1048576")
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == report(b"7.8.9")


def test_host_awk_implementations_handle_reserved_bytes_and_high_bytes(
    router: RouterHarness,
) -> None:
    valid = b"\x80\r\nCFMGR_VERSION=2.3.4\n"
    for awk in HOST_AWKS:
        result = parse(router, valid, size=str(len(valid)), awk=awk)
        assert result.returncode == 0 and result.stdout.encode("ascii") == report(b"2.3.4")
        for control in (b"\x00", b"\x1c"):
            source = b"# unrelated " + control + b" byte\n" + valid
            assert_rejected(parse(router, source, size=str(len(source)), awk=awk))
