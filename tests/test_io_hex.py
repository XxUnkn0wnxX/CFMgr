"""Byte grammar checks for the private hexadecimal IO validators."""

from __future__ import annotations

import re
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/lib/io.sh"
HOST_SHELLS = [
    pytest.param(None, id="sh"),
    pytest.param(
        "/bin/dash",
        id="dash",
        marks=pytest.mark.skipif(not Path("/bin/dash").is_file(), reason="dash unavailable"),
    ),
]
HEX = re.compile(r"[0-9a-f]+\Z")


def corpus() -> list[str]:
    path_bytes = [
        b"relative/path",
        b"/",
        b"/alpha/beta",
        b"//",
        b"/alpha//beta",
        b"/alpha/",
        b"/.",
        b"/..",
        b"/alpha/./beta",
        b"/alpha/../beta",
        b"/alpha/.",
        b"/alpha/..",
        b"/alpha/.../beta",
        b"/.hidden/file..name",
        b"/alpha/beta.",
        b"/alpha/beta..",
        b"/alpha\x00beta",
        b"/\xa0\x01",
        b'/"\xf2\xf2',
        b'/"\xf2\xe2\xf2',
        b'/"\xf2\xe2\xe2\xf2',
        b"/" + (b"segment-" * 24) + b"end",
    ]
    return [
        "",
        "0",
        "gg",
        "0g",
        "AB",
        "aB",
        "00",
        "610062",
        "a001",
        "2fa001",
        *("" if value == b"" else value.hex() for value in path_bytes),
    ]


def decoded_hex(value: str) -> bytes | None:
    if not value or len(value) % 2 or HEX.fullmatch(value) is None:
        return None
    data = bytes.fromhex(value)
    return None if b"\x00" in data else data


def accepts_hex(value: str) -> bool:
    return decoded_hex(value) is not None


def accepts_path(value: str) -> bool:
    data = decoded_hex(value)
    if data is None:
        return False
    if data == b"/":
        return True
    if not data.startswith(b"/"):
        return False
    return all(component not in (b"", b".", b"..") for component in data[1:].split(b"/"))


def run_corpus(router: RouterHarness, values: list[str], shell: str | None = None) -> list[str]:
    script = (
        f". {shlex.quote(str(SOURCE))}\n"
        "for _hex do\n"
        '    if _cfmgr_io_hex "$_hex"; then _hex_status=1; else _hex_status=0; fi\n'
        '    if _cfmgr_io_hex_path "$_hex"; then _path_status=1; else _path_status=0; fi\n'
        '    printf "%s\\t%s\\t%s\\n" "$_hex" "$_hex_status" "$_path_status"\n'
        "done\n"
    )
    if shell is None:
        result = router.run(script, values)
    else:
        script_path = router.write("work/io-hex.sh", script)
        result = router.run(
            f'exec {shlex.quote(shell)} {shlex.quote(str(script_path))} "$@"\n', values
        )
    assert result.returncode == 0 and result.stderr == "", result
    return result.stdout.splitlines()


def assert_corpus(router: RouterHarness, values: list[str], shell: str | None = None) -> None:
    observed = run_corpus(router, values, shell)
    expected = [
        f"{value}\t{int(accepts_hex(value))}\t{int(accepts_path(value))}" for value in values
    ]
    assert observed == expected


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize("shell", HOST_SHELLS)
def test_hex_validators_match_independent_byte_grammar(
    router: RouterHarness, shell: str | None
) -> None:
    assert_corpus(router, corpus(), shell)


@pytest.mark.busybox
@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="busybox")
def test_hex_validators_match_byte_grammar_under_actual_busybox(
    busybox_router: RouterHarness,
) -> None:
    assert busybox_router.busybox is not None
    assert_corpus(busybox_router, corpus())
