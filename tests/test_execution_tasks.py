"""Behavioral tests for stat identity parsing used by task supervision."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "modules/lib/execution_tasks.sh"


@pytest.fixture(scope="module")
def shell() -> list[str]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    command = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert command and shutil.which(command[0]), "Selected POSIX test shell is missing"
    return command


@pytest.fixture(scope="module")
def awk() -> str:
    executable = shutil.which("awk")
    assert executable, "Actual awk prerequisite is missing"
    return executable


def stat_record(comm: str, *, pid: int = 12345, start: int = 987654) -> bytes:
    """Return a complete stat row with the standard fields through field 52."""
    fields = [
        "S",  # 3 state
        "77",  # 4 parent
        "12345",  # 5 process group
        "77",  # 6 session
        "0",  # 7 tty number
        "-1",  # 8 foreground process group
        "4194304",  # 9 flags
        "10",  # 10 minor faults
        "0",  # 11 child minor faults
        "0",  # 12 major faults
        "0",  # 13 child major faults
        "4",  # 14 user time
        "5",  # 15 system time
        "0",  # 16 child user time
        "0",  # 17 child system time
        "20",  # 18 priority
        "0",  # 19 nice
        "1",  # 20 thread count
        "0",  # 21 interval timer
        str(start),  # 22 start time
        "4096",  # 23 virtual size
        "8",  # 24 resident pages
        "0",  # 25 resident limit
        "0",  # 26 start code
        "0",  # 27 end code
        "0",  # 28 start stack
        "0",  # 29 stack pointer
        "0",  # 30 instruction pointer
        "0",  # 31 pending signals
        "0",  # 32 blocked signals
        "0",  # 33 ignored signals
        "0",  # 34 caught signals
        "0",  # 35 wait channel
        "0",  # 36 swap count
        "0",  # 37 child swap count
        "0",  # 38 exit signal
        "0",  # 39 processor
        "0",  # 40 realtime priority
        "0",  # 41 scheduling policy
        "0",  # 42 block I/O delay
        "0",  # 43 guest time
        "0",  # 44 child guest time
        "0",  # 45 data limit
        "0",  # 46 start data
        "0",  # 47 end data
        "0",  # 48 start brk
        "0",  # 49 argument start
        "0",  # 50 argument end
        "0",  # 51 environment start
        "0",  # 52 environment end
    ]
    return f"{pid} ({comm}) {' '.join(fields)}\n".encode()


def identity_result(
    shell: list[str], awk: str, context: Path, proc_path: Path
) -> subprocess.CompletedProcess[bytes]:
    script = (
        'cfmgr_tasks_context=$2; cfmgr_tasks_awk=$3; . "$1"; '
        'if _cfmgr_tasks_identity "$4"; then '
        'printf "%s %s %s %s %s\\n" "$cfmgr_tasks_tid" '
        '"$cfmgr_tasks_start" "$cfmgr_tasks_identity_state" '
        '"$cfmgr_tasks_parent" "$cfmgr_tasks_flags"; '
        "else exit $?; fi"
    )
    command = [
        *shell,
        "-c",
        script,
        "execution-tasks-test",
        str(LIBRARY),
        str(context),
        awk,
        str(proc_path),
    ]
    return subprocess.run(
        command,
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=5,
    )


def write_stat(tmp_path: Path, data: bytes) -> Path:
    proc_path = tmp_path / "proc task"
    proc_path.mkdir()
    (proc_path / "stat").write_bytes(data)
    return proc_path


def test_sourcing_library_does_not_change_caller_or_write_files(
    shell: list[str], tmp_path: Path
) -> None:
    script = (
        'cd "$2"; before=$PWD; before_path=$PATH; caller_marker=kept; '
        '. "$1"; [ "$PWD" = "$before" ] && [ "$PATH" = "$before_path" ] && '
        '[ "$caller_marker" = kept ] && [ -z "${cfmgr_tasks_tid+x}" ]'
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "execution-tasks-source-test",
            str(LIBRARY),
            str(tmp_path),
        ],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize(
    "comm",
    [
        "worker with ordinary spaces",
        "worker (inside) parentheses) and another close",
        "first line\nsecond ) line $(touch NEVER_RUN)",
    ],
    ids=["spaces", "embedded-parens", "newline-and-shell-syntax"],
)
def test_identity_extracts_kernel_fields_from_realistic_comm_values(
    shell: list[str], awk: str, tmp_path: Path, comm: str
) -> None:
    proc_path = write_stat(tmp_path, stat_record(comm))
    result = identity_result(shell, awk, tmp_path, proc_path)
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"12345 987654 S 77 4194304\n",
        b"",
    )
    assert (tmp_path / "identity").read_bytes() == b"12345 987654 S 77 4194304\n"
    assert not (tmp_path / "NEVER_RUN").exists()


@pytest.mark.parametrize(
    "data",
    [
        b"12345 (missing close S 77 12345 77 0 1 4194304\n",
        b"leading 12345 (comm) S 77 12345 77 0 1 4194304\n",
        stat_record("comm")[:-1] + b" injected\n",
        b"12345 (short record) S 77 12345\n",
        stat_record("bad-number").replace(b" S 77 ", b" S seven ", 1),
        stat_record("bad-flags").replace(b" 4194304 ", b" flags ", 1),
    ],
    ids=[
        "missing-close-paren",
        "leading-content",
        "trailing-content",
        "short-record",
        "malformed-parent-field",
        "malformed-flags-field",
    ],
)
def test_identity_fails_closed_on_malformed_stat_records(
    shell: list[str], awk: str, tmp_path: Path, data: bytes
) -> None:
    proc_path = write_stat(tmp_path, data)
    result = identity_result(shell, awk, tmp_path, proc_path)
    assert result.returncode == 3
    assert result.stdout == b""


@pytest.mark.parametrize(
    "data",
    [
        stat_record("x" * 4100),
        stat_record("line\n" * 17 + "tail"),
        stat_record("comm")[:-1],
    ],
    ids=["over-4096-bytes", "over-17-records", "truncated-final-line"],
)
def test_identity_rejects_oversized_multiline_and_truncated_input(
    shell: list[str], awk: str, tmp_path: Path, data: bytes
) -> None:
    proc_path = write_stat(tmp_path, data)
    result = identity_result(shell, awk, tmp_path, proc_path)
    assert result.returncode == 3
    assert result.stdout == b""


def test_thread_missing_proc_root_returns_without_exiting_caller(
    shell: list[str], awk: str, tmp_path: Path
) -> None:
    context = tmp_path / "thread context"
    context.mkdir()
    proc_path = write_stat(tmp_path, stat_record("worker", pid=12345))
    script = r"""
cfmgr_tasks_context=$2 cfmgr_tasks_awk=$3
cfmgr_tasks_rows=observed cfmgr_tasks_group_start=987654
cfmgr_mount_keeper_check() { return 0; }
. "$1"
if _cfmgr_tasks_thread 12345 "$4"; then rc=0; else rc=$?; fi
IFS= read -r input || exit 90
printf 'rc=%s input=%s\n' "$rc" "$input"
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "execution-tasks-missing-root-test",
            str(LIBRARY),
            str(context),
            awk,
            str(proc_path),
        ],
        input=b"caller stdin remains available\n",
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"rc=3 input=caller stdin remains available\n",
        b"",
    )
    assert not (context / "observed").exists()
