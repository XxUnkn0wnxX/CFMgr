"""Command-line checks for the developer validation runner."""

from __future__ import annotations

import subprocess
import sys
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
