"""Fixed installed-opkg version admission without package execution."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_native_shell import NativeShellFixture, quiet

pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]

RECIPE_VERSION = "80503d94e356476250adaf1f669ee955ec26de76 (2025-11-05)"
EXPECTED_ENVIRONMENT = {
    "PATH": "/sbin:/bin:/usr/sbin:/usr/bin",
    "LC_ALL": "C",
    "HOME": "/tmp/cfmgr-home",
    "TMPDIR": "/tmp",
}


def install_opkg(
    fixture: NativeShellFixture,
    version: str,
    *,
    status: int = 0,
    stderr: bytes = b"",
) -> Path:
    output = b"opkg version " + version.encode("ascii") + b"\n"
    witness = fixture.router.path("work/native-opkg-witness.json")
    source = f"""import json
import os
import sys
from pathlib import Path

def _fd_open(fd):
    try:
        os.fstat(fd)
        return True
    except OSError:
        return False

record = {{
    "argv": sys.argv[1:],
    "environment": {{key: value for key, value in os.environ.items()
                    if key not in {{"PWD", "SHLVL", "__CF_USER_TEXT_ENCODING"}}}},
    "fds": [fd for fd in range(3, 64) if _fd_open(fd)],
}}
Path({str(witness)!r}).write_text(json.dumps(record), encoding="utf-8")
if sys.argv[1:] != ["--version"]:
    raise SystemExit(91)
sys.stdout.buffer.write({output!r})
sys.stderr.buffer.write({stderr!r})
raise SystemExit({status})
"""
    python_path = fixture.router.write("work/native-opkg.py", source)
    executable = fixture.router.write(
        "work/native-opkg",
        "#!/bin/sh\nexec "
        + shlex.quote(sys.executable)
        + " -S "
        + shlex.quote(str(python_path))
        + ' "$@"\n',
        executable=True,
    )
    target = fixture.native_root / "opt/bin/opkg"
    target.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
    target.symlink_to(executable)
    return witness


def expected_version_status(
    fixture: NativeShellFixture,
    expected: str,
    *,
    probe: str = "opkg",
    suffix: tuple[str, ...] | None = None,
):
    return fixture.run(
        suffix=(expected,) if suffix is None else suffix,
        probe=probe,
    )


def test_recipe_version_and_shell_probe_keep_separate_evidence_and_owner_fds(
    router: RouterHarness,
) -> None:
    fixture = NativeShellFixture(router, "opkg")
    opkg_witness = install_opkg(fixture, RECIPE_VERSION)

    result = expected_version_status(fixture, RECIPE_VERSION, probe="both")

    quiet(result, 0)
    assert result.stdout == "RESULT\t0\n"
    assert (fixture.execution / "native-shell/complete").is_dir()
    assert (fixture.execution / "opkg-version/complete").is_dir()
    output_bytes = f"opkg version {RECIPE_VERSION}\n".encode("ascii")
    assert (fixture.execution / "opkg-version/status").read_bytes() == (
        f"opkg-version 0 {len(output_bytes)} 0\n"
    ).encode("ascii")
    assert fixture.busybox_witnesses == [
        {"argv": ["test", "-d", "/tmp"], "fd6_open": False},
        {"argv": ["test", "-c", "/dev/null"], "fd6_open": False},
        {"argv": ["printf", "CFMGR_NATIVE_SHELL_V1\\n"], "fd6_open": False},
    ]
    launch = fixture.witness
    assert launch["argv"][:3] == [str(fixture.native_root), "/bin/sh", "-c"]
    assert launch["argv"][3].lstrip("\n") == "exec 6<&-\nexec /opt/bin/opkg --version\n"
    assert launch["environment"] == EXPECTED_ENVIRONMENT
    assert launch["fd6_is_directory"] is True
    child = json.loads(opkg_witness.read_text(encoding="utf-8"))
    assert child == {"argv": ["--version"], "environment": EXPECTED_ENVIRONMENT, "fds": []}


def test_printable_metacharacters_are_literal_data_at_128_byte_limit(
    router: RouterHarness,
) -> None:
    fixture = NativeShellFixture(router, "opkg")
    prefix = "$(printf injected);`printf forged`;'\""
    version = prefix + "V" * (128 - len(prefix))
    assert len(version.encode("ascii")) == 128
    assert all(0x20 <= ord(char) <= 0x7E for char in version)
    witness = install_opkg(fixture, version)
    (fixture.native_root / "bin/busybox").unlink()

    result = expected_version_status(fixture, version)

    quiet(result, 0)
    assert result.stdout == "RESULT\t0\n"
    assert (fixture.execution / "opkg-version/complete").is_dir()
    assert (fixture.execution / "opkg-version/stdout").read_bytes() == (
        b"opkg version " + version.encode("ascii") + b"\n"
    )
    assert version not in fixture.witness["argv"][3]
    assert version not in fixture.witness["environment"].values()
    assert json.loads(witness.read_text(encoding="utf-8"))["argv"] == ["--version"]


@pytest.mark.parametrize(
    "version",
    ["", "V" * 129, "control\x01byte", "nonascii-\u00e9"],
    ids=["empty", "over-limit", "control", "non-ascii"],
)
def test_invalid_expected_version_refuses_before_evidence_or_launch(
    router: RouterHarness, version: str
) -> None:
    fixture = NativeShellFixture(router, "opkg")

    result = expected_version_status(fixture, version)

    quiet(result, 0)
    assert result.stdout == "RESULT\t2\n"
    assert not fixture.witness_path.exists()
    assert not (fixture.execution / "opkg-version").exists()


@pytest.mark.parametrize("suffix", [(), ("version", "extra")], ids=["too-few", "too-many"])
def test_opkg_probe_requires_exactly_two_arguments(
    router: RouterHarness, suffix: tuple[str, ...]
) -> None:
    fixture = NativeShellFixture(router, "opkg")

    result = expected_version_status(fixture, "unused", suffix=suffix)

    quiet(result, 0)
    assert result.stdout == "RESULT\t2\n"
    assert not fixture.witness_path.exists()
    assert not (fixture.execution / "opkg-version").exists()


@pytest.mark.parametrize(
    ("response", "status", "stderr"),
    [
        ("another-version", 0, b""),
        (RECIPE_VERSION, 7, b""),
        (RECIPE_VERSION, 0, b"opkg warning\n"),
    ],
    ids=["mismatch", "nonzero", "stderr"],
)
def test_completed_mismatch_or_child_failure_returns_negative_with_evidence(
    router: RouterHarness, response: str, status: int, stderr: bytes
) -> None:
    fixture = NativeShellFixture(router, "opkg")
    install_opkg(fixture, response, status=status, stderr=stderr)

    result = expected_version_status(fixture, RECIPE_VERSION)

    quiet(result, 0)
    assert result.stdout == "RESULT\t1\n"
    evidence = fixture.execution / "opkg-version"
    assert evidence.joinpath("complete").is_dir()
    output_bytes = f"opkg version {response}\n".encode("ascii")
    assert evidence.joinpath("status").read_text(encoding="ascii") == (
        f"opkg-version {status} {len(output_bytes)} {len(stderr)}\n"
    )


@pytest.mark.parametrize("failure", ["missing-opkg", "collision"], ids=["missing", "collision"])
def test_missing_opkg_or_evidence_collision_refuses_before_launch(
    router: RouterHarness, failure: str
) -> None:
    fixture = NativeShellFixture(router, "opkg")
    if failure == "collision":
        install_opkg(fixture, RECIPE_VERSION)
        directory = fixture.execution / "opkg-version"
        directory.mkdir(mode=0o700)
        prior = directory / "retain"
        prior.write_bytes(b"prior evidence\n")

    result = expected_version_status(fixture, RECIPE_VERSION)

    quiet(result, 0)
    assert result.stdout == "RESULT\t1\n"
    assert not fixture.witness_path.exists()
    if failure == "collision":
        assert prior.read_bytes() == b"prior evidence\n"
    else:
        assert not (fixture.execution / "opkg-version").exists()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_validates_version_bounds_and_runs_fixed_opkg(
    busybox_router: RouterHarness,
) -> None:
    assert busybox_router.busybox is not None
    fixture = NativeShellFixture(busybox_router, "opkg", busybox=busybox_router.busybox)
    invalid = ("", "V" * 129, "bad\x7fbyte", "nonascii-\u00e9")
    for version in invalid:
        result = expected_version_status(fixture, version)
        quiet(result, 0)
        assert result.stdout == "RESULT\t2\n"
        assert not (fixture.execution / "opkg-version").exists()
    version = ("printable ; $() `\"'" + "B" * 120)[:128]
    assert len(version) == 128
    witness = install_opkg(fixture, version)

    result = expected_version_status(fixture, version)

    quiet(result, 0)
    assert result.stdout == "RESULT\t0\n"
    assert (fixture.execution / "opkg-version/complete").is_dir()
    assert json.loads(witness.read_text(encoding="utf-8"))["argv"] == ["--version"]
