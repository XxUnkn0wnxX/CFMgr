"""Backup destination menu journeys through the trusted installed entry."""

from __future__ import annotations

import json
import os
import pty
import shlex
import signal
import subprocess
from pathlib import Path

import pytest
from test_config_observation import commands, config
from test_config_store import ADAPTER, store_fixture
from test_install import legacy_fsync, shell, tools
from test_manager_settings_entry import (
    installed_settings_entry as _installed_settings_entry,
)
from test_manager_settings_entry import (
    run_entry,
    wait_for_output,
)

ROOT = Path(__file__).resolve().parents[1]
__all__ = [
    "_installed_settings_entry",
    "commands",
    "config",
    "legacy_fsync",
    "shell",
    "store_fixture",
    "tools",
]


@pytest.fixture
def installed_backup_entry(_installed_settings_entry):
    entry, support, ram, _ = _installed_settings_entry
    for relative in ("modules/lib/storage.sh", "modules/backup.sh"):
        target = support / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((ROOT / relative).read_bytes())
        target.chmod((ROOT / relative).stat().st_mode & 0o777)

    records = [
        "20\t1\t8:20\t/\t/tmp/mnt/Drive one\tvfat\t/dev/fixture20\trw,noexec\trw",
        "21\t1\t8:21\t/\t/tmp/mnt/nested/Drive two\tvfat\t/dev/fixture21\trw,noexec\trw",
    ]
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    assignments = adapter_path.read_text().split("CFMGR_VERSION=0.1.0", 1)[0]
    adapter = ADAPTER.split('. "$source/modules/lib/config_store.sh"\n', 1)[1]
    adapter = adapter.rsplit('\ncfmgr_config_store "$@"', 1)[0]
    adapter = adapter.replace(
        "case $mode in\n",
        "case $mode in\n"
        '    store-backup-mounts) case $scenario in no-drives) : >"$cfmgr_probe_stdout" ;; single) printf \'%s\\n\' "$backup_record1" >"$cfmgr_probe_stdout" ;; *) printf \'%s\\n\' "$backup_record1" "$backup_record2" >"$cfmgr_probe_stdout" ;; esac; : >"$cfmgr_probe_stderr"; cfmgr_probe_exit=0; return 0 ;;\n',
        1,
    )
    physical1 = ram / "Drive one"
    physical2 = ram / "Drive two"
    physical1.mkdir()
    physical2.mkdir()
    adapter += "\n" + "\n".join(
        (
            f"backup_record1={shlex.quote(records[0])}",
            f"backup_record2={shlex.quote(records[1])}",
            r"""
cfmgr_store_native_tool() { case $1 in /sbin/blkid) return 0 ;; *) [ -x "$1" ] ;; esac; }
cfmgr_backup_attached() { return 0; }
cfmgr_backup_mount_record() {
    case $1 in
        "$backup_record1") cfmgr_backup_id=20 cfmgr_backup_mount='/tmp/mnt/Drive one' cfmgr_backup_snapshot=$1 ;;
        "$backup_record2") cfmgr_backup_id=21 cfmgr_backup_mount='/tmp/mnt/nested/Drive two' cfmgr_backup_snapshot=$1 ;;
        *) return 1 ;;
    esac
    cfmgr_backup_root=/ cfmgr_backup_filesystem=vfat cfmgr_backup_device_path=/dev/fixture
    cfmgr_backup_options=rw,noexec cfmgr_backup_super=rw
}
cfmgr_backup_observe_uuid() { cfmgr_backup_uuid=abcd-1234 cfmgr_backup_label='Duplicate Drive'; }
cfmgr_backup_observe_mount() {
    case $1 in
        '/tmp/mnt/Drive one') cfmgr_backup_mount_record "$backup_record1" ;;
        '/tmp/mnt/nested/Drive two') cfmgr_backup_mount_record "$backup_record2" ;;
        *) return 1 ;;
    esac
}
cfmgr_backup_pin_selected() {
    cfmgr_backup_observe_mount "$cfmgr_backup_want_mount" || return 1
    cfmgr_backup_observe_uuid || return 1
    [ "$cfmgr_backup_snapshot" = "$cfmgr_backup_want_snapshot" ] &&
        [ "$cfmgr_backup_uuid" = "$cfmgr_backup_want_uuid" ] || return 1
    cfmgr_backup_pinned=1 cfmgr_store_backup_gate=1
}
cfmgr_backup_prepare_folder() {
    cfmgr_backup_attached || return 1
    case $cfmgr_backup_mount in
        '/tmp/mnt/Drive one') backup_folder="$ram/Drive one/CFBackup" ;;
        '/tmp/mnt/nested/Drive two') backup_folder="$ram/Drive two/CFBackup" ;;
        *) return 1 ;;
    esac
    [ "$scenario" != folder-failure ] || return 1
    mkdir -p "$backup_folder"
}
cfmgr_backup_folder_admit() { cfmgr_backup_attached; }
""".strip(),
        )
    )
    adapter_path.write_text(assignments + adapter)
    adapter_path.chmod(0o600)
    return entry, support, ram


def test_backup_menu_saves_and_reopens_destination_through_real_store(
    shell, installed_backup_entry
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=single")
    )
    before = (support / "config").read_bytes()
    master, slave = pty.openpty()
    child = subprocess.Popen(
        [*shell, str(entry)],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "LC_ALL": "C"},
    )
    output = bytearray()
    try:
        os.write(master, b"4\n")
        output.extend(wait_for_output(child, b"Backup drives: 1 available\n"))
        assert (support / "config").read_bytes() == before
        assert not (ram / "Drive one/CFBackup").exists()
        os.write(master, b"1\n")
        output.extend(wait_for_output(child, b"Drive number (or e to cancel): "))
        assert b"1) Duplicate Drive | /tmp/mnt/Drive one" in output
        assert b"2) " not in output
        assert not (ram / "Drive one/CFBackup").exists()
        os.write(master, b"1\n")
        output.extend(
            wait_for_output(
                child, b"Staged selection: Duplicate Drive | /tmp/mnt/Drive one\n"
            )
        )
        assert (support / "config").read_bytes() == before
        assert not (ram / "Drive one/CFBackup").exists()
        os.write(master, b"s\n")
        output.extend(wait_for_output(child, b"Prepare /tmp/mnt/Drive one/CFBackup"))
        assert (support / "config").read_bytes() == before
        assert not (ram / "Drive one/CFBackup").exists()
        os.write(master, b"y\n")
        output.extend(
            wait_for_output(child, b"Destination saved: /tmp/mnt/Drive one/CFBackup\n")
        )
        os.write(master, b"e\ne\n")
        remaining, stderr = child.communicate(timeout=25)
        output.extend(remaining)
    finally:
        if child.poll() is None:
            child.kill()
            child.communicate(timeout=3)
        os.close(master)
        os.close(slave)
    assert child.returncode == 0, (bytes(output), stderr)
    assert b"4 Backup / Restore" in output
    assert b"Prepare /tmp/mnt/Drive one/CFBackup" in output
    assert (ram / "Drive one/CFBackup").is_dir()
    saved = json.loads((support / "config").read_text())
    assert saved["backup"]["destination"]["mountpoint"] == "/tmp/mnt/Drive one"

    reopened = run_entry(shell, entry, b"4\ne\ne\n")
    assert reopened.returncode == 0, reopened.stderr
    assert (
        b"Saved destination: /tmp/mnt/Drive one/CFBackup (available)" in reopened.stdout
    )


def test_backup_menu_disambiguates_duplicate_labels_and_invalid_choices_are_read_only(
    shell, installed_backup_entry
):
    entry, support, ram = installed_backup_entry
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n9\ne\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"1) Duplicate Drive | /tmp/mnt/Drive one" in result.stdout
    assert b"2) Duplicate Drive | /tmp/mnt/nested/Drive two" in result.stdout
    assert b"Invalid drive selection." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not list(ram.glob("Drive */CFBackup"))


def test_backup_menu_default_no_does_not_prepare_or_save(shell, installed_backup_entry):
    entry, support, ram = installed_backup_entry
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n1\ns\nn\n1\n\x04\x04")
    assert result.returncode == 0, result.stderr
    assert b"Save cancelled; no changes were written." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not (ram / "Drive one/CFBackup").exists()


def test_backup_menu_interrupt_during_selection_does_not_mutate(
    shell, installed_backup_entry
):
    entry, support, ram = installed_backup_entry
    before = (support / "config").read_bytes()
    master, slave = pty.openpty()
    child = subprocess.Popen(
        [*shell, str(entry)],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "LC_ALL": "C"},
    )
    output = bytearray()
    try:
        os.write(master, b"4\n1\n")
        output.extend(wait_for_output(child, b"Drive number (or e to cancel): "))
        child.send_signal(signal.SIGINT)
        remaining, stderr = child.communicate(timeout=8)
        output.extend(remaining)
    finally:
        if child.poll() is None:
            child.kill()
            child.communicate(timeout=3)
        os.close(master)
        os.close(slave)
    assert child.returncode == -signal.SIGINT, (bytes(output), stderr)
    assert (support / "config").read_bytes() == before
    assert not list(ram.glob("Drive */CFBackup"))


def test_backup_menu_with_no_drives_keeps_destination_unset(
    shell, installed_backup_entry
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=no-drives")
    )
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Backup drives: none available" in result.stdout
    assert b"No backup drives are available." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not list(ram.glob("Drive */CFBackup"))


def test_backup_menu_reports_save_failure_without_claiming_rollback(
    shell, installed_backup_entry
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=folder-failure")
    )
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n1\ns\ny\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert (
        b"Save did not complete; CFBackup may have been prepared and existing contents were preserved."
        in result.stderr
    )
    assert (support / "config").read_bytes() == before
    assert not (ram / "Drive one/CFBackup").exists()


def test_backup_menu_recovers_interrupted_store_save_without_drive(
    shell, installed_backup_entry
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=publish-stop")
    )
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n1\ns\ny\nr\ny\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Pending recovery: yes" in result.stdout
    assert b"Recover previous Save" in result.stdout
    assert b"No backup drive is needed." in result.stdout
    assert b"Previous Save recovered; no settings were replayed." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not list(support.glob(".config-save*"))
    assert (ram / "Drive one/CFBackup").is_dir()


def test_backup_menu_rejects_malformed_backend_frame_before_selection(shell, tmp_path):
    script = f". {shlex.quote(str(ROOT / 'modules/backup.sh'))}\n"
    script += """cfmgr_backup_action() { printf '%s\\n' 'CFMGR-BACKUP 1 list 1 0 none 1 END'; return 0; }
cfmgr_backup_menu
"""
    result = subprocess.run(
        [*shell, "-c", script], input=b"1\n", capture_output=True, check=False
    )
    assert result.returncode == 0
    assert b"invalid backend result" in result.stderr
    assert b"Drive number" not in result.stdout

    unavailable = f". {shlex.quote(str(ROOT / 'modules/backup.sh'))}\n"
    unavailable += """cfmgr_backup_action() { printf '%s\\n' 'CFMGR-BACKUP 1 unavailable 0 0 unavailable 0 END'; return 1; }
cfmgr_backup_menu
"""
    result = subprocess.run(
        [*shell, "-c", unavailable], input=b"e\n", capture_output=True, check=False
    )
    assert result.returncode == 0
    assert b"Saved destination: unknown (backend unavailable)" in result.stdout
    assert b"Backup drives: unavailable" in result.stdout
    assert b"Backup drives: none available" not in result.stdout
