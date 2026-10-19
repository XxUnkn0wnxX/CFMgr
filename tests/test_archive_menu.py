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

SET_ID = "01234567-89ab-cdef-0123-456789abcdef"
ARCHIVE_ID = "abcdefab-1234-4abc-8abc-123456789abc"
BROWSER_NAME = "CFbackup-999.tar.gz"


def browser_item(index=1, name=BROWSER_NAME):
    return (
        f"CFMGR-ARCHIVE-ITEM 1 {index} {name} {SET_ID} {ARCHIVE_ID} "
        "1700000000 2024-02-29 23-59-59 55544330 +0000 DMY 2 7 END\n"
    )


def browser_effects():
    rows = [
        "SCHEMA 2 current",
        "STATE ddns 1 0",
        "STATE ip_sync 0 0",
        "STATE cloudflared 0 0",
        "CLOUD - 0 0 1 1",
        "LOG ddns 1 0 1 1",
        "LOG ip_sync 0 0 0 0",
        "LOG cloudflared 0 0 0 0",
        f"STORAGE source-uuid ext4 {b'/'.hex()} {b'etc/cloudflared'.hex()}",
        f"FILE manager.config jffs {b'addons/CFMgr.d/config'.hex()} 100 whole",
        f"FILE manager.catalog jffs {b'addons/CFMgr.d/catalog.txt'.hex()} 10 whole",
        "DRAFT ip_sync incomplete",
        f"EXTERNAL data.cloudflared.yaml {b'/opt/external-ca.pem'.hex()} input-reference",
        "NOTE history.ddns unavailable - entware-unavailable",
        "CURRENT readiness-unknown auth-unknown",
        "RESTORE current-components fresh-admission path-remapping history-may-defer",
    ]
    return "".join(f"CFMGR-ARCHIVE-EFFECT 1 {row} END\n" for row in rows)


def run_browser_menu(shell, tmp_path, answers, *, scenario="normal", selected=None):
    log = tmp_path / "browser-actions.log"
    frame = (
        "CFMGR-ARCHIVE-BROWSER 1 verified 0 1 END\n"
        + browser_item()
        + f"CFMGR-ARCHIVE-RECEIPT 1 123 456 {'a' * 64} END\n"
        + browser_effects()
    )
    drives = []
    for index, mount in enumerate(("/tmp/mnt/Drive one", "/tmp/mnt/Drive two"), 1):
        fields = [
            value.encode().hex()
            for value in ("Drive", mount, "uuid", "ext4", "/", f"snapshot{index}")
        ]
        drives.append(f"CFMGR-BACKUP-DRIVE 1 {index} {' '.join(fields)} END")
    script = (
        f". {shlex.quote(str(ROOT / 'modules/backup.sh'))}\n"
        + r"""
cfmgr_backup_action() {
    [ "$1" = list ] || { printf 'unexpected-save\n' >>"$BROWSER_LOG"; return 1; }
    if [ "$BROWSER_SCENARIO" = no-drives ]; then
        printf '%s\n' 'CFMGR-BACKUP 1 list 7 0 none 0 END'
    elif [ "$BROWSER_SCENARIO" = saved ]; then
        printf '%s\n' 'CFMGR-BACKUP 1 list 7 0 available 2 END' "$BROWSER_DEST" "$BROWSER_DRIVES"
    else printf '%s\n' 'CFMGR-BACKUP 1 list 7 0 none 2 END' "$BROWSER_DRIVES"; fi
}
cfmgr_archive_action() {
    [ "$1" = read ] || { printf 'unexpected-archive-save\n' >>"$BROWSER_LOG"; return 1; }
    printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 7 0 - 0 0 - none none END'
}
cfmgr_archive_browser_action() {
    printf '%s\n' "$*" >>"$BROWSER_LOG"
    case $1 in
    list)
        case $BROWSER_SCENARIO in
        incomplete) printf '%s\n' 'CFMGR-ARCHIVE-BROWSER 1 incomplete 0 0 END'; return 1 ;;
        *) printf '%s\n' 'CFMGR-ARCHIVE-BROWSER 1 listed 0 1 END'; printf '%s' "$BROWSER_ITEM" ;;
        esac ;;
    inspect|verify) printf '%s' "$BROWSER_SELECTED" ;;
    delete)
        case $BROWSER_SCENARIO in
        changed) printf '%s\n' 'CFMGR-ARCHIVE-BROWSER 1 unavailable 0 0 END'; return 1 ;;
        pending|unresolved)
            printf '%s' "$BROWSER_SELECTED" | sed '1s/verified 0/deleted 1/'
            [ "$BROWSER_SCENARIO" != unresolved ] || return 3
            return 1 ;;
        *) printf '%s' "$BROWSER_SELECTED" | sed '1s/verified/deleted/' ;;
        esac ;;
    esac
}
cfmgr_backup_menu
"""
    )
    destination = (
        "CFMGR-BACKUP-DEST 1 "
        + " ".join(
            value.encode().hex()
            for value in ("/tmp/mnt/Drive two", "uuid", "ext4", "/")
        )
        + " END"
    )
    result = subprocess.run(
        [*shell, "-c", script],
        input=answers,
        env={
            **os.environ,
            "LC_ALL": "C",
            "BROWSER_LOG": str(log),
            "BROWSER_SCENARIO": scenario,
            "BROWSER_DRIVES": "\n".join(drives),
            "BROWSER_DEST": destination,
            "BROWSER_ITEM": browser_item(),
            "BROWSER_SELECTED": frame if selected is None else selected,
        },
        capture_output=True,
        check=False,
        timeout=15,
    )
    result.actions = log.read_text().splitlines() if log.exists() else []
    return result


def test_browser_uses_alternate_source_and_reuses_verified_details_effects(
    shell, tmp_path
):
    result = run_browser_menu(
        shell, tmp_path, b"4\n1\n1\n1\n3\nd\n\ne\ne\n", scenario="saved"
    )
    assert result.returncode == 0, result.stderr
    assert b"4 Browse archives" in result.stdout
    assert b"s) Saved source | /tmp/mnt/Drive two" in result.stdout
    assert b"1) 29-02-2024 23-59-59 | CFbackup-999.tar.gz" in result.stdout
    assert b"ddns: configured Off" in result.stdout
    assert b"Cloudflared: method -; installed yes; maintenance enabled" in result.stdout
    assert b"inert saved draft (incomplete)" in result.stdout
    assert b"External dependency: /opt/external-ca.pem" in result.stdout
    assert b"history.ddns: unavailable" in result.stdout
    assert b"Current readiness and provider authentication are unknown" in result.stdout
    assert b"Executable restore and activation are not available yet" in result.stdout
    assert b"Deletion cancelled; archive preserved" in result.stdout
    assert [line.split()[0] for line in result.actions] == ["list", "inspect"]
    assert all(b"/tmp/mnt/Drive one".hex() in line for line in result.actions)
    assert b"Saved destination: /tmp/mnt/Drive two/CFBackup" in result.stdout


@pytest.mark.parametrize("scenario", ["changed", "pending", "unresolved"])
def test_browser_delete_passes_exact_receipt_and_reports_actual_outcome(
    shell, tmp_path, scenario
):
    result = run_browser_menu(
        shell, tmp_path, b"4\n1\n1\n2\nd\ny\ne\n", scenario=scenario
    )
    assert result.returncode == 0, result.stderr
    assert [line.split()[0] for line in result.actions] == [
        "list",
        "inspect",
        "verify",
        "delete",
    ]
    assert result.actions[-1].endswith(f"{BROWSER_NAME} 123 456 {'a' * 64}")
    if scenario == "changed":
        assert b"deletion was not confirmed; source may have changed" in result.stderr
        assert b"Archive deleted:" not in result.stdout
    else:
        assert b"Archive deleted: CFbackup-999.tar.gz" in result.stdout
        assert b"archive was deleted; temporary cleanup is pending" in result.stderr
    if scenario == "unresolved":
        assert (
            b"archive operation is unresolved; leaving Backup / Restore"
            in result.stderr
        )


@pytest.mark.parametrize("corruption", ["secret", "name", "missing-state", "bad-hex"])
def test_browser_rejects_entire_selected_frame_before_display(
    shell, tmp_path, corruption
):
    frame = (
        "CFMGR-ARCHIVE-BROWSER 1 verified 0 1 END\n"
        + browser_item()
        + f"CFMGR-ARCHIVE-RECEIPT 1 123 456 {'a' * 64} END\n"
        + browser_effects()
    )
    if corruption == "secret":
        frame += "CFMGR-ARCHIVE-EFFECT 1 AUTH secret-sentinel END\n"
    elif corruption == "name":
        frame = frame.replace(BROWSER_NAME, "CFbackup-111.tar.gz")
    elif corruption == "missing-state":
        frame = frame.replace("CFMGR-ARCHIVE-EFFECT 1 STATE ddns 1 0 END\n", "")
    else:
        frame = frame.replace(b"/opt/external-ca.pem".hex(), b"secret-sentinel\n".hex())
    result = run_browser_menu(shell, tmp_path, b"4\n1\n1\n3\ne\n", selected=frame)
    assert b"invalid archive browser result" in result.stderr
    assert b"Archive: CFbackup-" not in result.stdout
    assert b"secret-sentinel" not in result.stdout + result.stderr
    assert [line.split()[0] for line in result.actions] == ["list", "inspect"]


def test_browser_incomplete_scan_and_eof_return_without_mutation(shell, tmp_path):
    incomplete = run_browser_menu(shell, tmp_path, b"4\n1\ne\n", scenario="incomplete")
    assert b"scan is incomplete" in incomplete.stderr
    assert b"No archive list is available from the incomplete scan" in incomplete.stdout
    assert b"No recognized archives are present" not in incomplete.stdout
    assert len(incomplete.actions) == 1
    (tmp_path / "browser-actions.log").unlink()
    eof = run_browser_menu(shell, tmp_path, b"4\n")
    assert eof.returncode == 0 and eof.actions == []


def run_archive_menu(
    shell_command: list[str],
    tmp_path: Path,
    scenario: str,
    answers: bytes,
    outcome: str = "collision",
) -> subprocess.CompletedProcess:
    log = tmp_path / "archive-actions.log"
    script = f". {shlex.quote(str(ROOT / 'modules/backup.sh'))}\n"
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
        bad-unresolved:read)
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 read 8 0 MDY 4 1 - none none END'
            return 0
            ;;
        bad-unresolved:create)
            # A valid-looking private name must not leak from a rejected frame.
            printf '%s\n' 'CFMGR-ARCHIVE-ACTION 1 unresolved 9 1 MDY 4 1 43466261636b75702d313939392e7461722e677a unresolved private END'
            return 3
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
    if scenario not in {"malformed", "generic-name", "bad-unresolved"}:
        assert b"invalid archive backend result" not in result.stderr
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


def test_bad_unresolved_frame_clears_private_name_and_stops_menu(shell, tmp_path):
    result = run_archive_menu(shell, tmp_path, "bad-unresolved", b"2\ny\n2\ny\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"invalid archive backend result" in result.stderr
    assert result.stdout.count(b"Backup / Restore: manual archive") == 1
    assert b"CFbackup-1999" not in result.stdout + result.stderr
    assert b"Published archive name" not in result.stdout
    assert b"Archive created" not in result.stdout
    assert result.action_log == ["read", "create"]
