"""Command-line checks for the developer validation runner."""

from __future__ import annotations

import runpy
import shutil
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

from tools import check

pytestmark = [pytest.mark.unit, pytest.mark.matrix("V43", evidence="harness")]


def test_busybox_argument_reaches_pytest_validation(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    original_run = subprocess.run
    pytest_result: subprocess.CompletedProcess[str] | None = None

    def run(
        command: list[str], **kwargs: object
    ) -> SimpleNamespace | subprocess.CompletedProcess[str]:
        nonlocal pytest_result
        if command[1:3] == ["-m", "pytest"]:
            pytest_result = original_run(
                [*command, "--collect-only", "-q"],
                capture_output=True,
                text=True,
                timeout=10,
                cwd=check.ROOT,
            )
            return pytest_result
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(
        sys,
        "argv",
        ["check", "--busybox=/usr/bin/true", "--shellcheck=/usr/bin/true", "--shfmt=/usr/bin/true"],
    )
    monkeypatch.setattr(check, "shell_sources", lambda _root: [])
    monkeypatch.setattr(check.subprocess, "run", run)

    assert check.main() == 4
    assert pytest_result is not None
    assert "not a working BusyBox" in pytest_result.stderr
    assert "unrecognized arguments" not in pytest_result.stderr
    assert "rootdir: /usr/bin" not in pytest_result.stdout
    assert "--busybox=/usr/bin/true" in capsys.readouterr().out


def test_runner_uses_relocated_fork_root(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    fork_root = tmp_path / "renamed fork with spaces"
    tools_dir = fork_root / "tools"
    tools_dir.mkdir(parents=True)
    source_runner = Path(check.__file__)
    relocated_runner = tools_dir / "check.py"
    shutil.copy2(source_runner, relocated_runner)
    shell_source = fork_root / "cfmgr.sh"
    shell_source.write_text("#!/bin/sh\nexit 0\n")
    unrelated = tmp_path / "unrelated working directory"
    unrelated.mkdir()
    monkeypatch.chdir(unrelated)
    monkeypatch.setattr(
        sys,
        "argv",
        ["check", "--shellcheck=/usr/bin/true", "--shfmt=/usr/bin/true"],
    )
    calls: list[tuple[list[str], Path]] = []

    def run(command: list[str], **kwargs: object) -> SimpleNamespace:
        calls.append((command, Path(kwargs["cwd"])))
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(subprocess, "run", run)
    runner = runpy.run_path(str(relocated_runner))

    assert runner["ROOT"] == fork_root
    assert runner["main"]() == 0
    assert calls
    assert all(cwd == fork_root for _, cwd in calls)
    assert any(command == ["/bin/sh", "-n", str(shell_source)] for command, _ in calls)
    tool = str(Path("/usr/bin/true").resolve())
    assert [tool, "--shell=sh", str(shell_source)] in [command for command, _ in calls]
    assert [tool, "-ln", "posix", "-d", str(shell_source)] in [command for command, _ in calls]
    pytest_command = next(command for command, _ in calls if command[1:3] == ["-m", "pytest"])
    assert pytest_command[:3] == [sys.executable, "-m", "pytest"]
    assert not any(command[0] in {"git", "gh"} for command, _ in calls)
