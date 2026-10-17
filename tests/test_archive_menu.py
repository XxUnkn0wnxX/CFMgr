"""Manual archive menu journeys with the production shell consumer."""

from __future__ import annotations

import os
import shlex
import subprocess
from pathlib import Path

import pytest
from test_install import shell

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["shell"]


def run_archive_menu(
    shell_command: list[str],
    tmp_path: Path,
    scenario: str,
    answers: bytes,
    outcome: str = "collision",
) -> subprocess.CompletedProcess:
    log = tmp_path / "archive-actions.log"
    script = f". {shlex.quote(str(ROOT / 'modules/backup.sh'))}\n"
    script += f". {shlex.quote(str(ROOT / 'modules/backup.sh'))}\n"
    script += r"""
cfmgr_backup_action() {
    printf '%s\n' 'CFMGR-BACKUP 1 list 1 0 none 0 END'
    return 0
}
cfmgr_archive_action() {
    printf '%s\n' "$*" >> "$ARCHIVE_ACTION_LOG"
    case $ARCHIVE_SCENARIO:$1 in
        preferences:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 1 0 - 0 0 - none none END'
            return 0
            ;;
        preferences:preferences)
            printf 'CFMGR-ARCHIVE-ACTION 1 saved 2 0 %s %s 1 - none none END\n' "$2" "$3"
            return 0
            ;;
        create-ok:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 8 0 MDY 4 1 - none none END'
            return 0
            ;;
        create-ok:create)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 created 9 0 MDY 4 1 43466261636b75702d32303236313031375f3132303030302e7461722e677a failed saved END'
            return 0
            ;;
        legacy:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 8 0 YMD 4 0 - none none END'
            return 0
            ;;
        legacy:create)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 created 9 0 YMD 4 0 43466261636b75702d32303236313031375f3132303030302e7461722e677a complete saved END'
            return 0
            ;;
        partial:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 8 0 DMY 0 0 - none none END'
            return 0
            ;;
        unresolved:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 8 0 MDY 4 1 - none none END'
            return 0
            ;;
        unresolved:create)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 unresolved 9 1 MDY 4 1 43466261636b75702d32303236313031375f3132303030302e7461722e677a unresolved none END'
            return 3
            ;;
        outcomes:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 8 0 MDY 4 1 - none none END'
            return 0
            ;;
        outcomes:create)
            if [ "$ARCHIVE_OUTCOME" = collision ]; then
                printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 collision 12 0 MDY 4 1 - none none END'
            else
                printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 preferences-needed 12 0 MDY 4 1 - none none END'
            fi
            return 1
            ;;
        malformed:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 1 0 MDY 4 1 - none none END'
            return 0
            ;;
        read-fail:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 unavailable 0 0 - 0 0 - none none END'
            return 1
            ;;
        malformed:create)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 created 9 0 MDY 4 1 7365637265740a2f6576696c complete saved END'
            return 0
            ;;
        generic-name:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 1 0 MDY 4 1 - none none END'
            return 0
            ;;
        generic-name:create)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 created 9 0 MDY 4 1 666f6f2e7461722e677a complete saved END'
            return 0
            ;;
    esac
    return 1
}
cfmgr_backup_menu
"""
    result = subprocess.run(
        [*shell_command, "-c", script],
        input=answers,
        capture_output=True,
        check=False,
        env={
            **os.environ,
            "LC_ALL": "C",
            "ARCHIVE_SCENARIO": scenario,
            "ARCHIVE_ACTION_LOG": str(log),
            "ARCHIVE_OUTCOME": outcome,
        },
    )
    result.action_log = log.read_text().splitlines() if log.exists() else []
    return result


def test_archive_preferences_require_explicit_choices_and_review(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "preferences", b"3\nDMY\n5\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert (
        b"Choose date order: DMY (31/12/2026), MDY (12/31/2026), or YMD (2026-12-31)."
        in result.stdout
    )
    assert b"Choose retention: 3, 4, or 5 archives." in result.stdout
    assert (
        b"Archive preferences saved: DMY date order, retain 5 archives."
        in result.stdout
    )
    assert b"Existing archives were not pruned." in result.stdout
    assert result.action_log == ["read", "read", "preferences DMY 5"]


def test_archive_preference_cancel_and_invalid_menu_choice_are_read_only(
    shell, tmp_path
):
    result = run_archive_menu(shell, tmp_path, "preferences", b"x\n3\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert (
        b"Archive preferences: unset (choose date order and retention)" in result.stdout
    )
    assert b"Date order (DMY/MDY/YMD, or e to cancel): " in result.stdout
    assert result.action_log == ["read", "read"]


def test_archive_read_failure_keeps_destination_menu_available(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "read-fail", b"e\n")
    assert result.returncode == 0, result.stderr
    assert b"archive preferences are unavailable" in result.stderr
    assert b"Backup drives: none available" in result.stdout
    assert b"Archive preferences: unknown" in result.stdout
    assert result.action_log == ["read"]


def test_legacy_preferences_read_without_set_marker_remain_usable(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "legacy", b"2\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Archive preferences: YMD date order, retain 4 archives" in result.stdout
    assert b"Archive created: CFbackup-20261017_120000.tar.gz" in result.stdout
    assert result.action_log == ["read", "create"]


def test_partially_unset_preferences_read_cleanly_and_block_create(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "partial", b"2\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Archive preferences: DMY date order, retain 0 archives" in result.stdout
    assert b"Choose archive date order and retention in option 3" in result.stdout
    assert result.action_log == ["read"]


def test_eof_cancels_archive_preferences_without_writing(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "preferences", b"3\n")
    assert result.returncode == 0, result.stderr
    assert b"Date order (DMY/MDY/YMD, or e to cancel): " in result.stdout
    assert result.action_log == ["read", "read"]


def test_invalid_preference_choice_does_not_write(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "preferences", b"3\nBAD\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Invalid date order." in result.stdout
    assert result.action_log == ["read", "read"]


def test_archive_create_confirms_and_reports_retention_and_history_separately(
    shell, tmp_path
):
    result = run_archive_menu(shell, tmp_path, "create-ok", b"2\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert (
        b"Archive contents are unencrypted and may contain operational credentials."
        in result.stdout
    )
    assert b"filesystem privacy is best-effort." in result.stdout
    assert b"Archive created: CFbackup-20261017_120000.tar.gz" in result.stdout
    assert b"Archive created, but retention did not complete." in result.stderr
    assert b"Archive history saved." in result.stdout
    assert result.action_log == ["read", "create"]


def test_archive_create_default_no_does_not_call_backend(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "create-ok", b"2\nn\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Archive creation cancelled; no changes were made." in result.stdout
    assert result.action_log == ["read"]


@pytest.mark.parametrize(
    ("outcome", "expected"),
    [
        (
            "collision",
            b"An archive with that name already exists; no archive was replaced.",
        ),
        (
            "preferences-needed",
            b"Set archive date order and retention in option 3 before creating an archive.",
        ),
    ],
)
def test_archive_create_reports_backend_outcomes(shell, tmp_path, outcome, expected):
    result = run_archive_menu(shell, tmp_path, "outcomes", b"2\ny\ne\n", outcome)
    assert result.returncode == 0, result.stderr
    assert expected in result.stdout
    assert result.action_log == ["read", "create"]


def test_unresolved_archive_with_published_name_stops_menu(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "unresolved", b"2\ny\n")
    assert result.returncode == 0, result.stderr
    assert b"Published archive name: CFbackup-20261017_120000.tar.gz" in result.stdout
    assert (
        b"[CFMGR] backup: error: archive operation is unresolved; leaving Backup / Restore"
        in result.stderr
    )
    assert result.action_log == ["read", "create"]


def test_malformed_archive_frame_rejects_injected_name(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "malformed", b"2\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"invalid archive backend result" in result.stderr
    assert b"secret" not in result.stdout
    assert b"/evil" not in result.stdout


def test_archive_frame_rejects_generic_tar_basename(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "generic-name", b"2\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"invalid archive backend result" in result.stderr
    assert b"foo.tar.gz" not in result.stdout
