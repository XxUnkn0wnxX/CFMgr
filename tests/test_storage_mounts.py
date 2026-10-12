"""Real Linux ext4 mount and descriptor proof for storage attachment checks."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/fixtures/storage_mounts.sh"
REQUIRE_BUSYBOX = os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1"


@pytest.fixture(scope="module")
def selected_shell() -> list[str]:
    default = "/bin/sh"
    shell = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert shell, "Selected POSIX test shell is empty"
    executable = shutil.which(shell[0])
    assert executable, f"Selected POSIX test shell is missing: {shell[0]}"
    shell[0] = executable
    if REQUIRE_BUSYBOX:
        assert Path(shell[0]).name == "busybox" and shell[1:] == ["ash"], (
            "Required BusyBox coverage must select busybox ash"
        )
    return shell


@pytest.fixture(scope="module")
def fixture_tools(selected_shell: list[str]) -> tuple[list[str], str, str, str]:
    if not REQUIRE_BUSYBOX:
        pytest.skip(
            "real ext4 mount fixtures run only in the explicit required BusyBox validation"
        )
    assert sys.platform == "linux", "Required BusyBox mount proof requires Linux"

    required = (
        "sudo",
        "unshare",
        "timeout",
        "truncate",
        "mkfs.ext4",
        "losetup",
        "mount",
        "umount",
        "mountpoint",
        "blkid",
        "readlink",
        "awk",
        "stat",
        "id",
    )
    paths: dict[str, str] = {}
    for name in required:
        executable = shutil.which(name)
        assert executable, f"Required Linux mount fixture tool is missing: {name}"
        paths[name] = executable

    sudo = paths["sudo"]
    unshare = paths["unshare"]
    # Capability failures are failures on Linux CI, not skips. This verifies
    # that the exact private mount namespace requested by the fixture is usable.
    probe = subprocess.run(
        [sudo, "-n", unshare, "--mount", "--propagation", "private", "/bin/true"],
        check=False,
        capture_output=True,
        timeout=10,
    )
    assert probe.returncode == 0, (
        "Linux storage fixture requires passwordless sudo and private mount namespaces: "
        f"{probe.stderr.decode(errors='replace')}"
    )
    return selected_shell, paths["readlink"], paths["awk"], paths["timeout"]


def run_fixture(
    fixture_tools: tuple[list[str], str, str, str], case: str, workdir: Path
) -> subprocess.CompletedProcess[bytes]:
    shell, readlink, awk, timeout = fixture_tools
    os.chmod(workdir, 0o700)
    parent_namespace = os.readlink("/proc/self/ns/mnt")
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    command = [
        shutil.which("sudo") or "sudo",
        "-n",
        shutil.which("unshare") or "unshare",
        "--mount",
        "--propagation",
        "private",
        timeout,
        "--signal=TERM",
        "--kill-after=2",
        "25",
        *shell,
        str(FIXTURE),
        str(ROOT),
        case,
        str(workdir),
        readlink,
        awk,
        parent_namespace,
        str(os.getuid()),
    ]
    result = subprocess.run(
        command,
        env=environment,
        check=False,
        capture_output=True,
        timeout=30,
    )
    # The fixture owns this exact child path and removes it in its EXIT trap.
    # Preserve its diagnostics if uncertain cleanup deliberately retained data.
    assert list(workdir.iterdir()) == [], (
        "Storage fixture left private files behind:\n"
        f"stdout: {result.stdout.decode(errors='replace')}\n"
        f"stderr: {result.stderr.decode(errors='replace')}"
    )
    return result


def assert_fixture_passed(
    result: subprocess.CompletedProcess[bytes], case: str
) -> None:
    assert result.returncode == 0, (
        f"Linux storage mount fixture failed ({case}):\n"
        f"stdout: {result.stdout.decode(errors='replace')}\n"
        f"stderr: {result.stderr.decode(errors='replace')}"
    )
    assert result.stderr == b"", result.stderr.decode(errors="replace")
    assert result.stdout.startswith(b"PASS: "), result.stdout.decode(errors="replace")


def test_real_ext4_attachment_uuid_and_descriptor_lifetime(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "valid", tmp_path)
    assert_fixture_passed(result, "valid")


def test_alias_substitution_is_denied_without_changing_data(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "alias_substitution", tmp_path)
    assert_fixture_passed(result, "alias_substitution")


def test_lazy_detach_does_not_adopt_different_uuid_replacement(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "lazy_replacement", tmp_path)
    assert_fixture_passed(result, "lazy_replacement")


def test_bind_mount_preserves_filesystem_root_and_volume_relative_identity(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "bind_identity", tmp_path)
    assert_fixture_passed(result, "bind_identity")


def test_read_only_and_noexec_ext4_mounts_are_denied(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "ro_noexec", tmp_path)
    assert_fixture_passed(result, "ro_noexec")


def test_fixture_rejects_wrong_argument_count_before_setup(
    selected_shell: list[str],
) -> None:
    result = subprocess.run(
        [*selected_shell, str(FIXTURE)],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 2
    assert result.stdout == b""
    assert result.stderr.startswith(b"storage mount fixture: expected seven arguments")


def test_fixture_rejects_unknown_case_before_setup(
    selected_shell: list[str], tmp_path: Path
) -> None:
    result = subprocess.run(
        [
            *selected_shell,
            str(FIXTURE),
            str(ROOT),
            "invalid-case",
            str(tmp_path),
            "/bin/readlink",
            "/usr/bin/awk",
            "mnt:[parent]",
            str(os.getuid()),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 2
    assert result.stdout == b""
    assert result.stderr.startswith(b"storage mount fixture: invalid case")
    assert list(tmp_path.iterdir()) == []
