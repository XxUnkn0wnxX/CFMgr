"""Isolated settings-menu journeys against a finite Store adapter."""

from __future__ import annotations

import os
import pty
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
MODULE = ROOT / "modules/manager_settings.sh"


@pytest.fixture(scope="module")
def shell() -> list[str]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    command = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert command and shutil.which(command[0]), "Selected POSIX test shell is missing"
    return command


DRIVER = r"""
. "$1"
state=$2 calls=$3 scenario=$4
cfmgr_config_store() {
    operation=$1 mask=${2-} want_check=${3-} want_auto=${4-}
    printf '%s %s %s %s\n' "$operation" "$mask" "$want_check" "$want_auto" >>"$calls"
    IFS=' ' read -r generation check auto developer pending <"$state"
    case $operation in
    read)
        if [ "$scenario" = read-zero-busy ]; then
            printf 'CFMGR-STORE 1 busy %s %s %s %s %s END\n' "$generation" "$check" "$auto" "$developer" "$pending"
            return 0
        fi
        printf 'CFMGR-STORE 1 read %s %s %s %s %s END\n' "$generation" "$check" "$auto" "$developer" "$pending"
        return 0
        ;;
    save)
        case $scenario in
        malformed-save)
            printf 'CFMGR-STORE 1 saved %s %s %s %s %s END extra\n' "$generation" "$want_check" "$want_auto" "$developer" "$pending"
            return 0
            ;;
        bad-status)
            printf 'CFMGR-STORE 1 saved %s %s %s %s 0 END\n' "$generation" "$want_check" "$want_auto" "$developer"
            return 1
            ;;
        busy | unresolved)
            printf 'CFMGR-STORE 1 %s %s %s %s %s %s END\n' "$scenario" "$generation" "$check" "$auto" "$developer" "$pending"
            return 1
            ;;
        recovery)
            printf '%s %s %s %s 1\n' "$generation" "$check" "$auto" "$developer" >"$state"
            printf 'CFMGR-STORE 1 recovery %s %s %s %s 1 END\n' "$generation" "$check" "$auto" "$developer"
            return 1
            ;;
        status-zero-error)
            printf 'CFMGR-STORE 1 busy %s %s %s %s %s END\n' "$generation" "$check" "$auto" "$developer" "$pending"
            return 0
            ;;
        esac
        target_check=$check target_auto=$auto
        case $mask in check | both) target_check=$want_check ;; esac
        case $mask in auto | both) target_auto=$want_auto ;; esac
        if [ "$mask" = check ] && [ "$target_check" = 0 ]; then target_auto=0; fi
        if [ "$mask" = auto ] && [ "$target_auto" = 1 ]; then target_check=1; fi
        if [ "$target_check:$target_auto" = "$check:$auto" ]; then result=unchanged
        else generation=$((generation + 1)); check=$target_check; auto=$target_auto; pending=0; result=saved
            printf '%s %s %s %s %s\n' "$generation" "$check" "$auto" "$developer" "$pending" >"$state"
        fi
        printf 'CFMGR-STORE 1 %s %s %s %s %s %s END\n' "$result" "$generation" "$check" "$auto" "$developer" "$pending"
        ;;
    recover)
        if [ "$scenario" = recover-unchanged ]; then
            printf '%s %s %s %s 0\n' "$generation" "$check" "$auto" "$developer" >"$state"
            printf 'CFMGR-STORE 1 unchanged %s %s %s %s 0 END\n' "$generation" "$check" "$auto" "$developer"
            return 0
        fi
        printf 'CFMGR-STORE 1 recovered %s %s %s %s 0 END\n' "$generation" "$check" "$auto" "$developer"
        printf '%s %s %s %s 0\n' "$generation" "$check" "$auto" "$developer" >"$state"
        ;;
    *) return 2 ;;
    esac
}
cfmgr_manager_settings
status=$?
printf 'menu-status=%s\n' "$status"
exit "$status"
"""


def run_menu(
    shell: list[str],
    tmp_path: Path,
    data: bytes,
    *,
    initial: str = "1 1 0 0 0\n",
    scenario: str = "normal",
    terminal: bool = True,
) -> tuple[subprocess.CompletedProcess[bytes], list[str], str]:
    state = tmp_path / "store-state"
    calls = tmp_path / "store-calls"
    state.write_text(initial)
    calls.write_text("")
    command = [
        *shell,
        "-c",
        DRIVER,
        "manager-settings-test",
        str(MODULE),
        str(state),
        str(calls),
        scenario,
    ]
    if not terminal:
        result = subprocess.run(
            command,
            input=data,
            capture_output=True,
            check=False,
            timeout=5,
            env={**os.environ, "LC_ALL": "C"},
        )
    else:
        master, slave = pty.openpty()
        try:
            child = subprocess.Popen(
                command,
                stdin=slave,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                env={**os.environ, "LC_ALL": "C"},
            )
            os.write(master, data)
            stdout, stderr = child.communicate(timeout=5)
            result = subprocess.CompletedProcess(
                child.args, child.returncode, stdout, stderr
            )
        finally:
            os.close(master)
            os.close(slave)
    return result, calls.read_text().splitlines(), state.read_text()


@pytest.mark.parametrize(
    ("initial", "inputs", "save_call", "final"),
    [
        ("1 1 1 0 0\n", b"1\ns\ny\ne\n", "save both 0 0", "2 0 0 0 0\n"),
        ("1 0 0 0 0\n", b"1\ns\ny\ne\n", "save check 1 0", "2 1 0 0 0\n"),
        ("1 1 1 0 0\n", b"2\ns\ny\ne\n", "save auto 1 0", "2 1 0 0 0\n"),
        ("1 0 0 0 0\n", b"2\ns\ny\ne\n", "save both 1 1", "2 1 1 0 0\n"),
        ("1 1 0 0 0\n", b"1\n2\ns\ny\ne\n", "save both 1 1", "2 1 1 0 0\n"),
    ],
)
def test_toggle_intents_confirm_save_and_reopen_actual_values(
    shell, tmp_path, initial, inputs, save_call, final
):
    result, calls, state = run_menu(shell, tmp_path, inputs, initial=initial)
    assert result.returncode == 0, result.stderr
    assert calls == ["read   ", save_call, "read   "]
    assert state == final
    assert b"Review Save:" in result.stdout
    assert b"Preferences saved." in result.stdout
    assert b"Saved: Check for updates=" in result.stdout
    assert b"checking/installing updates is unavailable yet" in result.stdout
    assert b"Store" not in result.stdout + result.stderr


@pytest.mark.parametrize(
    "inputs", [b"e\n", b"1\ns\nn\ne\n", b"1\ns\ne\n", b"1\ns\n\x04"]
)
def test_back_decline_confirmation_e_and_eof_never_save(shell, tmp_path, inputs):
    result, calls, state = run_menu(shell, tmp_path, inputs)
    assert result.returncode == 0, result.stderr
    assert calls == ["read   "]
    assert state == "1 1 0 0 0\n"
    assert b"Preferences saved." not in result.stdout


def test_save_without_staged_intent_does_not_call_store(shell, tmp_path):
    result, calls, state = run_menu(shell, tmp_path, b"s\ny\ne\n")
    assert result.returncode == 0
    assert calls == ["read   "]
    assert state == "1 1 0 0 0\n"
    assert b"No preference changes staged" in result.stdout
    assert b"Save these preferences?" not in result.stdout


def test_non_tty_does_not_read_or_mutate_store(shell, tmp_path):
    result, calls, state = run_menu(shell, tmp_path, b"1\ns\ny\n", terminal=False)
    assert result.returncode == 1
    assert calls == []
    assert state == "1 1 0 0 0\n"
    assert b"interactive terminal required" in result.stderr


@pytest.mark.parametrize(
    "scenario", ["malformed-save", "bad-status", "status-zero-error"]
)
def test_invalid_save_receipt_never_claims_success(shell, tmp_path, scenario):
    result, calls, state = run_menu(shell, tmp_path, b"1\ns\ny\n", scenario=scenario)
    assert result.returncode == 1
    assert calls == ["read   ", "save both 0 0"]
    assert state == "1 1 0 0 0\n"
    assert b"Preferences saved." not in result.stdout
    assert b"invalid settings response" in result.stderr


@pytest.mark.parametrize(
    ("initial", "saved", "effective", "note"),
    [
        (
            "1 0 1 0 0\n",
            b"Saved: Check for updates=Off; Auto-update CFMgr=On; Developer=Off",
            b"Effective now: Check for updates=Off; Auto-update CFMgr=Off",
            False,
        ),
        (
            "1 0 1 1 0\n",
            b"Saved: Check for updates=Off; Auto-update CFMgr=On; Developer=On",
            b"Effective now: Check for updates=Off; Auto-update CFMgr=Off",
            True,
        ),
    ],
)
def test_view_keeps_contradictory_saved_values_and_developer_suppression(
    shell, tmp_path, initial, saved, effective, note
):
    result, calls, state = run_menu(shell, tmp_path, b"e\n", initial=initial)
    assert result.returncode == 0
    assert calls == ["read   "]
    assert state == initial
    assert saved in result.stdout and effective in result.stdout
    suppression = (
        b"Developer mode suppresses manager updates; saved preferences are retained."
    )
    assert (suppression in result.stdout) is note


def test_busy_save_reopens_with_fresh_read_but_unresolved_stops(shell, tmp_path):
    busy, busy_calls, busy_state = run_menu(
        shell, tmp_path, b"1\ns\ny\ne\n", scenario="busy"
    )
    assert busy.returncode == 0
    assert busy_calls == ["read   ", "save both 0 0", "read   "]
    assert busy_state == "1 1 0 0 0\n"
    assert b"settings save busy; no changes were saved" in busy.stderr
    assert b"Store" not in busy.stdout + busy.stderr
    assert b"Preferences saved." not in busy.stdout

    unresolved, unresolved_calls, unresolved_state = run_menu(
        shell, tmp_path, b"1\ns\ny\n", scenario="unresolved"
    )
    assert unresolved.returncode == 1
    assert unresolved_calls == ["read   ", "save both 0 0"]
    assert unresolved_state == "1 1 0 0 0\n"
    assert b"settings operation unresolved; leaving settings" in unresolved.stderr

    recovery, recovery_calls, recovery_state = run_menu(
        shell, tmp_path, b"1\ns\ny\ne\n", scenario="recovery"
    )
    assert recovery.returncode == 0
    assert recovery_calls == ["read   ", "save both 0 0", "read   "]
    assert recovery_state == "1 1 0 0 1\n"
    assert b"previous Save needs explicit recovery" in recovery.stderr
    assert b"pending Save/recovery state" in recovery.stdout
    assert b"Preferences saved." not in recovery.stdout


def test_pending_recovery_requires_confirmation_and_only_reopens(shell, tmp_path):
    result, calls, state = run_menu(
        shell, tmp_path, b"r\ny\ne\n", initial="8 1 0 0 1\n"
    )
    assert result.returncode == 0
    assert calls == ["read   ", "recover   ", "read   "]
    assert state == "8 1 0 0 0\n"
    assert b"Recover previous configuration Save?" in result.stdout
    assert b"Previous Save recovered; no settings were replayed." in result.stdout


def test_pending_recovery_cancel_does_not_call_recover(shell, tmp_path):
    result, calls, state = run_menu(
        shell, tmp_path, b"r\nn\ne\n", initial="8 1 0 0 1\n"
    )
    assert result.returncode == 0
    assert calls == ["read   "]
    assert state == "8 1 0 0 1\n"
    assert b"Recovery cancelled; no recovery was attempted." in result.stdout


def test_recover_unchanged_reports_no_pending_then_reopens(shell, tmp_path):
    result, calls, state = run_menu(
        shell,
        tmp_path,
        b"r\ny\ne\n",
        initial="8 1 0 0 1\n",
        scenario="recover-unchanged",
    )
    assert result.returncode == 0, result.stderr
    assert calls == ["read   ", "recover   ", "read   "]
    assert state == "8 1 0 0 0\n"
    assert b"No pending Save to recover." in result.stdout
    assert b"Preferences saved." not in result.stdout
    assert b"Previous Save recovered" not in result.stdout


def test_invalid_read_claiming_busy_uses_fixed_response_error(shell, tmp_path):
    result, calls, state = run_menu(shell, tmp_path, b"e\n", scenario="read-zero-busy")
    assert result.returncode == 1
    assert calls == ["read   "]
    assert state == "1 1 0 0 0\n"
    assert b"invalid settings response" in result.stderr
    assert b"settings save busy" not in result.stderr
    assert b"no changes were saved" not in result.stderr
