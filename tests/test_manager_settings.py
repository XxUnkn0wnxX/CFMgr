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
MODULE = ROOT / "modules/manager.sh"
BACKUP = ROOT / "modules/backup.sh"


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


DIAGNOSTIC_DRIVER = r"""
command() { return 127; }
. "$1"
. "$5"
state=$2 calls=$3 scenario=$4
cfmgr_diagnostic_settings() {
    operation=$1 wanted=${2--}
    printf 'settings %s %s\n' "$operation" "$wanted" >>"$calls"
    IFS=' ' read -r generation developer pending saved <"$state"
    case $operation in
    read)
        printf 'CFMGR-DIAGNOSTIC 1 read %s %s %s %s END\n' "$generation" "$developer" "$pending" "$saved"
        ;;
    save)
        if [ "$scenario" = malformed-save ]; then
            printf 'CFMGR-DIAGNOSTIC 1 saved %s %s %s %s END extra\n' "$generation" "$developer" "$pending" "$wanted"
            return 0
        fi
        if [ "$wanted" = "$saved" ]; then result=unchanged
        else generation=$((generation + 1)); saved=$wanted; result=saved
            printf '%s %s %s %s\n' "$generation" "$developer" "$pending" "$saved" >"$state"
        fi
        printf 'CFMGR-DIAGNOSTIC 1 %s %s %s %s %s END\n' "$result" "$generation" "$developer" "$pending" "$saved"
        ;;
    recover)
        pending=0
        printf '%s %s %s %s\n' "$generation" "$developer" "$pending" "$saved" >"$state"
        printf 'CFMGR-DIAGNOSTIC 1 recovered %s %s 0 %s END\n' "$generation" "$developer" "$saved"
        ;;
    *) return 2 ;;
    esac
}
cfmgr_log_destination() {
    [ "$1" = preview ] || return 2
    printf 'preview %s\n' "$2" >>"$calls"
    auto_hex=2f6d6f636b2f6175746f
    case $scenario:$2 in
    bad-preview:*) printf 'CFMGR-LOG-DEST 1 maybe - END\n'; return 0 ;;
    auto-unavailable:-) printf 'CFMGR-LOG-DEST 1 unavailable - END\n'; return 0 ;;
    unavailable-saved:*) printf 'CFMGR-LOG-DEST 1 unavailable - END\n'; return 0 ;;
    unavailable-custom:2f6d6f636b2f756e617661696c61626c65) printf 'CFMGR-LOG-DEST 1 unavailable - END\n'; return 0 ;;
    -:|*:-) printf 'CFMGR-LOG-DEST 1 available %s END\n' "$auto_hex" ;;
    *) printf 'CFMGR-LOG-DEST 1 available %s END\n' "$2" ;;
    esac
}
cfmgr_launch_menu
menu_status=$?
printf 'menu-status=%s\n' "$menu_status"
exit 0
"""


def run_diagnostic_menu(
    shell: list[str],
    tmp_path: Path,
    data: bytes,
    *,
    initial: str = "1 0 0 -\n",
    scenario: str = "normal",
) -> tuple[subprocess.CompletedProcess[bytes], list[str], str]:
    state = tmp_path / "diagnostic-state"
    calls = tmp_path / "diagnostic-calls"
    state.write_text(initial)
    calls.write_text("")
    master, slave = pty.openpty()
    try:
        child = subprocess.Popen(
            [
                *shell,
                "-c",
                DIAGNOSTIC_DRIVER,
                "manager-diagnostic-test",
                str(MODULE),
                str(state),
                str(calls),
                scenario,
                str(BACKUP),
            ],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, "LC_ALL": "C"},
        )
        os.write(master, data)
        stdout, stderr = child.communicate(timeout=8)
        result = subprocess.CompletedProcess(
            child.args, child.returncode, stdout, stderr
        )
    finally:
        os.close(master)
        os.close(slave)
    return result, calls.read_text().splitlines(), state.read_text()


def test_advanced_option_saves_and_reopens_custom_destination_without_developer_toggle(
    shell, tmp_path
):
    custom_path = str(tmp_path / "custom-diagnostics")
    custom_hex = custom_path.encode().hex()
    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        f"ao\n3\n1\n{custom_path}\ny\ne\ne\ne\n".encode(),
        initial="1 1 0 -\n",
    )
    assert result.returncode == 0, result.stderr
    assert state == f"2 1 0 {custom_hex}\n", (
        f"diagnostic destination Save did not persist; calls={calls!r}; "
        f"state={state!r}; stdout={result.stdout[:4096]!r}; "
        f"stderr={result.stderr[:4096]!r}"
    )
    assert f"preview {custom_hex}" in calls
    assert f"settings save {custom_hex}" in calls
    assert b"Advanced options: other actions unavailable" in result.stdout
    assert (
        b"Saved diagnostic preference: Custom " + custom_path.encode() in result.stdout
    )
    assert b"Developer mode remains manual-file-only" in result.stdout
    assert not Path(custom_path).exists()

    reopened, reopened_calls, reopened_state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\ne\ne\ne\n",
        initial=state,
    )
    assert reopened.returncode == 0, reopened.stderr
    assert reopened_state == state
    assert "settings read " in reopened_calls[0]
    assert f"preview {custom_hex}" in reopened_calls
    assert (
        b"Saved diagnostic preference: Custom " + custom_path.encode()
        in reopened.stdout
    )


def test_unavailable_custom_is_rejected_and_auto_can_be_saved_while_unavailable(
    shell, tmp_path
):
    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\n1\n/mock/unavailable\ne\ne\ne\n",
        scenario="unavailable-custom",
    )
    assert result.returncode == 0, result.stderr
    assert state == "1 0 0 -\n"
    assert not any(call.startswith("settings save ") for call in calls)
    assert b"Custom destination is unavailable" in result.stdout
    assert b"Saved diagnostic preference: Auto" in result.stdout

    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\na\ny\ne\ne\ne\n",
        initial=f"4 0 0 {b'/mock/custom'.hex()}\n",
        scenario="auto-unavailable",
    )
    assert result.returncode == 0, result.stderr
    assert state == "5 0 0 -\n"
    assert "settings save -" in calls
    assert (
        b"Review diagnostic destination: Auto; effective preview=unavailable"
        in result.stdout
    )

    saved_custom = b"/mock/custom".hex()
    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\ne\ne\ne\n",
        initial=f"8 0 0 {saved_custom}\n",
        scenario="unavailable-saved",
    )
    assert result.returncode == 0, result.stderr
    assert state == f"8 0 0 {saved_custom}\n"
    assert f"preview {saved_custom}" in calls
    assert "preview -" not in calls
    assert (
        b"Effective diagnostic destination: unavailable; no fallback selected"
        in result.stdout
    )


def test_navigation_and_bad_preview_never_save_or_create_destination(shell, tmp_path):
    result, calls, state = run_diagnostic_menu(shell, tmp_path, b"ao\n3\ne\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert calls == ["settings read -", "preview -"]
    assert state == "1 0 0 -\n"

    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\n1\n/mock/custom\ny\ne\ne\ne\n",
        scenario="bad-preview",
    )
    assert result.returncode == 0
    assert state == "1 0 0 -\n"
    assert not any(call.startswith("settings save ") for call in calls)
    assert b"invalid diagnostic destination preview" in result.stderr


def test_malformed_store_save_receipt_never_claims_success(shell, tmp_path):
    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\n1\n/mock/custom\ny\ne\ne\ne\n",
        scenario="malformed-save",
    )
    assert result.returncode == 0
    assert state == "1 0 0 -\n"
    assert "settings save " in "\n".join(calls)
    assert b"Diagnostic destination preference saved." not in result.stdout
    assert b"invalid diagnostic destination response" in result.stderr


def test_pending_diagnostic_save_recovery_requires_confirmation(shell, tmp_path):
    result, calls, state = run_diagnostic_menu(
        shell,
        tmp_path,
        b"ao\n3\nr\ny\ne\ne\ne\n",
        initial="7 0 1 -\n",
    )
    assert result.returncode == 0, result.stderr
    assert state == "7 0 0 -\n"
    assert "settings recover -" in calls
    assert b"Recover previous diagnostic destination Save?" in result.stdout
    assert b"Previous diagnostic destination Save recovered" in result.stdout
