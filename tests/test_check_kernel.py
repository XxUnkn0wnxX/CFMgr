"""Cheap runner safety checks; these never start a privileged namespace."""

from __future__ import annotations

import hashlib
import subprocess
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from tools import check_kernel

pytestmark = [pytest.mark.unit, pytest.mark.matrix("V43", evidence="harness")]


def test_help_never_checks_platform_or_privileges(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(check_kernel, "prove", Mock(side_effect=AssertionError("proof started")))
    with pytest.raises(SystemExit) as exited:
        check_kernel.main(["--help"])
    assert exited.value.code == 0


@pytest.mark.parametrize(
    "platform,uid,message", [("darwin", 0, "requires Linux"), ("linux", 1000, "explicit root")]
)
def test_unsupported_host_fails_before_tools_or_temp_storage(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    platform: str,
    uid: int,
    message: str,
) -> None:
    monkeypatch.setattr(check_kernel.sys, "platform", platform)
    monkeypatch.setattr(check_kernel.os, "geteuid", lambda: uid)
    native = Mock(side_effect=AssertionError("tool resolution started"))
    monkeypatch.setattr(check_kernel, "native", native)
    assert check_kernel.main(["--busybox", "/missing/busybox"]) == 1
    assert message in capsys.readouterr().err
    native.assert_not_called()


def test_namespace_timeout_kills_and_waits_exact_launched_parent(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    child = SimpleNamespace(
        communicate=Mock(side_effect=subprocess.TimeoutExpired("unshare", 15)),
        kill=Mock(),
        wait=Mock(return_value=-9),
    )
    launch = Mock(return_value=child)
    monkeypatch.setattr(check_kernel.subprocess, "Popen", launch)
    with pytest.raises(subprocess.TimeoutExpired):
        check_kernel.namespace(["/trusted/unshare"])
    launch.assert_called_once()
    child.kill.assert_called_once_with()
    child.wait.assert_called_once_with(timeout=5)


def test_cleanup_rejects_changed_root_symlink(tmp_path: Path) -> None:
    retained = tmp_path / "retained"
    retained.mkdir()
    (retained / "sentinel").write_text("retained")
    work = tmp_path / "cfmgr-kernel-replaced"
    work.symlink_to(retained, target_is_directory=True)
    with pytest.raises(ValueError, match="refusing cleanup"):
        check_kernel.owned_cleanup(work, tmp_path, (0, 0))
    assert (retained / "sentinel").read_text() == "retained"


def test_contained_manifest_hashes_exact_fixed_fixture_rows(tmp_path: Path) -> None:
    library = tmp_path / "lib"
    library.mkdir()
    names = ("ld-2.27.so", "libc-2.27.so", "libpthread-2.27.so", "librt-2.27.so")
    entries = []
    for name in names:
        data = name.encode("ascii") + b"\x00\n"
        (library / name).write_bytes(data)
        entries.append((f"lib/{name}", data))
    executable = tmp_path / "controlled-probe"
    data = b"controlled binary\x00\n"
    executable.write_bytes(data)
    entries.extend((f"libexec/{name}", data) for name in ("timeout-coreutils", "gzip-gnu"))
    expected = "".join(
        f"{relative}\t{len(data)}\t{hashlib.sha256(data).hexdigest()}\n"
        for relative, data in entries
    ).encode("ascii")
    assert check_kernel.contained_manifest(tmp_path, executable) == expected
    assert len(expected) <= 4096


@pytest.mark.parametrize("size", [0, 4194305])
def test_contained_manifest_rejects_member_before_reading(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, size: int
) -> None:
    (tmp_path / "lib").mkdir()
    with (tmp_path / "lib/ld-2.27.so").open("wb") as member:
        member.truncate(size)
    read = Mock(side_effect=AssertionError("unbounded fixture read"))
    monkeypatch.setattr(Path, "read_bytes", read)
    with pytest.raises(ValueError, match="member exceeds closure bounds"):
        check_kernel.contained_manifest(tmp_path, tmp_path / "controlled-probe")
    read.assert_not_called()
