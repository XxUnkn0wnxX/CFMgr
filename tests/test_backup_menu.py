"""Backup destination menu journeys through the trusted installed entry."""

from __future__ import annotations

import fcntl
import json
import os
import pty
import shlex
import shutil
import signal
import subprocess
import sys
from pathlib import Path

import pytest
from entry_package_fixture import finish_package
from test_archive_config import configured
from test_archive_create import prior_archive
from test_archive_io import SETUP as ARCHIVE_SETUP
from test_config_observation import commands, config, schema2_config
from test_config_store import ADAPTER, store_fixture
from test_install import legacy_fsync, shell, tools
from test_manager_settings_entry import (
    installed_settings_entry as _installed_settings_entry,
)
from test_manager_settings_entry import (
    run_entry,
    wait_for_output,
)
from test_prerequisites import pause_definition

ROOT = Path(__file__).resolve().parents[1]
__all__ = [
    "_installed_settings_entry",
    "commands",
    "config",
    "legacy_fsync",
    "schema2_config",
    "shell",
    "store_fixture",
    "tools",
]


@pytest.fixture
def installed_backup_entry(_installed_settings_entry, tools, shell):
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
    adapter = ADAPTER.split('. "$source/modules/lib/config.sh"\n', 1)[1]
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
        '/tmp/mnt/Drive one') backup_folder="$ram/Drive one/CFMgr/backup" ;;
        '/tmp/mnt/nested/Drive two') backup_folder="$ram/Drive two/CFMgr/backup" ;;
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
    finish_package(entry, support, tools, shell)
    return entry, support, ram


def test_installed_archive_browser_uses_real_backend_without_saved_destination(
    shell, installed_backup_entry, tools, schema2_config
):
    entry, support, ram = installed_backup_entry
    source = ram / "Drive one"
    folder = source / "CFMgr/backup"
    folder.mkdir(parents=True)
    selected = folder / "CFbackup-2023-11-14.tar.gz"
    selected_bytes = prior_archive(configured(schema2_config))
    selected.write_bytes(selected_bytes)
    sibling = folder / "unrelated.txt"
    sibling.write_bytes(b"keep unrelated data\n")
    config_before = (support / "config").read_bytes()
    assert b'"destination":null' in config_before
    assert json.loads(config_before)["backup"].get("set_id") is None

    # Keep Store's existing adapter, but archive probes use the actual production
    # single-exec/ulimit entry and Linux supervisor. Firmware mount admission is
    # explicit fixture data; no real mount policy or Mac proc proof is claimed.
    execution = support / "modules/lib/execution.sh"
    execution.write_text(
        execution.read_text().replace(
            "cfmgr_prerequisites_run() {", "cfmgr_test_real_run() {", 1
        )
    )
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter = (
        adapter_path.read_text()
        .replace("cfmgr_prerequisites_run() {", "cfmgr_browser_test_store_run() {", 1)
        .replace("cfmgr_store_prepare() {", "cfmgr_browser_test_store_prepare() {", 1)
    )
    fixture_tools = dict(tools)
    for name in ("dd", "openssl", "gzip", "gunzip", "tar", "hexdump", "date", "printf"):
        resolved = shutil.which(name)
        assert resolved, f"Actual archive browser tool {name} is required"
        fixture_tools[name] = resolved
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        applets = ram / "browser-applets"
        applets.mkdir()
        for name in (
            "awk",
            "ls",
            "wc",
            "dd",
            "gzip",
            "gunzip",
            "tar",
            "hexdump",
            "date",
            "printf",
        ):
            target = applets / name
            target.symlink_to(Path(tools["sh"]).resolve())
            fixture_tools[name] = str(target)
    adapter += "\n" + "\n".join(
        f"TEST_{name.upper()}={shlex.quote(value)}"
        for name, value in fixture_tools.items()
    )
    adapter += f"\nTEST_LINUX={'1' if sys.platform == 'linux' else '0'}\n"
    adapter += pause_definition(shell)
    adapter += ARCHIVE_SETUP[
        ARCHIVE_SETUP.index("cfmgr_prerequisites_run() {") :
    ].replace("cfmgr_prerequisites_run() {", "cfmgr_browser_test_archive_run() {", 1)
    adapter += r"""
cfmgr_store_prepare() {
    cfmgr_browser_test_store_prepare || return $?
    cfmgr_test_ram=$cfmgr_store_context cfmgr_test_backup="$ram/Drive one/CFMgr/backup"
    cfmgr_prerequisites_now || return 1
    cfmgr_store_deadline=$((cfmgr_probe_now+20))
}
cfmgr_store_native_tool() {
    case $1 in
    /bin/gzip) [ -x "$TEST_GZIP" ] ;;
    /bin/gunzip) [ -x "$TEST_GUNZIP" ] ;;
    /bin/tar) [ -x "$TEST_TAR" ] ;;
    /usr/bin/hexdump) [ -x "$TEST_HEXDUMP" ] ;;
    /usr/bin/printf) [ -x "$TEST_PRINTF" ] ;;
    /sbin/blkid) return 0 ;;
    *) [ -x "$1" ] ;;
    esac
}
cfmgr_prerequisites_run() {
    case $1 in archive-*)
        printf '%s\n' "$1" >>"$ram/routes"
        cfmgr_browser_test_archive_run "$@" ;;
    *) cfmgr_browser_test_store_run "$@" ;;
    esac
}
cfmgr_backup_pin_selected() {
    [ "$cfmgr_backup_want_mount" = '/tmp/mnt/Drive one' ] &&
        [ "$cfmgr_backup_want_uuid" = abcd-1234 ] &&
        [ "$cfmgr_backup_want_snapshot" = "$backup_record1" ] || return 1
    cfmgr_backup_mount="$ram/Drive one" cfmgr_backup_pinned=1 cfmgr_store_backup_gate=1
    exec 6<"$cfmgr_backup_mount"
}
cfmgr_backup_folder_admit() {
    [ -d "$ram/Drive one/CFMgr/backup" ] && [ ! -L "$ram/Drive one/CFMgr/backup" ] || return 1
    exec 7<"$ram/Drive one/CFMgr/backup"
    cfmgr_backup_folder_pinned=1
}
"""
    if sys.platform == "linux":
        adapter += r"""
cfmgr_prerequisites_now() { IFS=' ' read -r cfmgr_probe_uptime cfmgr_probe_idle </proc/uptime || return 1; cfmgr_probe_now=${cfmgr_probe_uptime%%.*}; }
"""
    else:
        adapter += "\ncfmgr_archive_uuid() { cfmgr_archive_uuid=00000000-0000-4000-8000-123456789abc; }\n"
        backup = support / "modules/backup.sh"
        body = (
            backup.read_text()
            .replace("/proc/self/fd/5", "${cfmgr_test_ram}")
            .replace("/proc/self/fd/7", "${cfmgr_test_backup}")
        )
        for variable in ("ram", "backup"):
            body = body.replace(
                f"cd ${{cfmgr_test_{variable}}}", f'cd "${{cfmgr_test_{variable}}}"'
            )
            body = body.replace(
                f" ${{cfmgr_test_{variable}}} ", f' "${{cfmgr_test_{variable}}}" '
            )
        backup.write_text(body)
        memory = ram / "browser-meminfo"
        memory.write_text("MemAvailable: 65536 kB\n")
        worker = support / "modules/helpers/worker.sh"
        worker.write_text(
            worker.read_text().replace("/proc/meminfo", shlex.quote(str(memory)))
        )
    adapter_path.write_text(adapter)
    finish_package(entry, support, tools, shell)
    answers = (
        b"4\n4\n1\n1\n3\nd\nn\ne\ne\ne\n"
        if sys.platform == "linux"
        else b"4\n4\n1\ne\ne\n"
    )
    result = run_entry(shell, entry, answers, timeout=180)
    assert result.returncode == 0, (result.stdout[-3000:], result.stderr[-2000:])
    assert b"4 Browse archives" in result.stdout
    assert b"Saved destination: unset" in result.stdout
    assert (
        b"Archive source drives (saved destination will be preserved)" in result.stdout
    )
    routes = (ram / "routes").read_text().splitlines()
    assert "archive-directory" in routes and "archive-gunzip" in routes
    if sys.platform == "linux":
        assert b"1) 2023-11-14 22-13-20" in result.stdout
        assert b"Full data verification passed" in result.stdout
        assert b"ddns: never configured" in result.stdout
        assert b"Deletion cancelled; archive preserved" in result.stdout
        assert "archive-browser-review" in routes
    else:
        assert b"archive scan is incomplete" in result.stderr
        assert b"No archive list is available from the incomplete scan" in result.stdout
        assert b"Full data verification passed" not in result.stdout
    assert "archive-archive-remove" not in routes
    assert not any(
        route
        in {
            "store-lock",
            "store-backup-mkdir",
            "store-backup-leaf-mkdir",
            "store-backup-chmod",
        }
        for route in routes
    )
    assert selected.read_bytes() == selected_bytes
    assert sibling.read_bytes() == b"keep unrelated data\n"
    assert (support / "config").read_bytes() == config_before
    assert not (ram / "Drive two/CFMgr/backup").exists()
    assert not (ram / "context").exists()
    assert not list(folder.glob(".create.*"))


def test_backup_menu_scoped_save_preserves_edits_during_review_and_reopens(
    shell, installed_backup_entry, tools
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=single")
    )
    finish_package(entry, support, tools, shell)
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
        assert not (ram / "Drive one/CFMgr/backup").exists()
        os.write(master, b"1\n")
        output.extend(wait_for_output(child, b"Drive number (or e to cancel): "))
        assert b"1) Duplicate Drive | /tmp/mnt/Drive one" in output
        assert b"2) " not in output
        assert not (ram / "Drive one/CFMgr/backup").exists()
        os.write(master, b"1\n")
        output.extend(
            wait_for_output(
                child, b"Staged selection: Duplicate Drive | /tmp/mnt/Drive one\n"
            )
        )
        assert (support / "config").read_bytes() == before
        assert not (ram / "Drive one/CFMgr/backup").exists()
        os.write(master, b"s\n")
        output.extend(
            wait_for_output(child, b"Prepare /tmp/mnt/Drive one/CFMgr/backup")
        )
        assert (support / "config").read_bytes() == before
        assert not (ram / "Drive one/CFMgr/backup").exists()
        # Review holds no writer lock. A concurrent editor selects another
        # destination and changes unrelated settings without a generation bump;
        # this reviewed Save may replace only the destination and generation.
        lock = ram / "config.lock"
        lock.touch(mode=0o600)
        other_destination = {
            "schema": 1,
            "mountpoint": "/tmp/mnt/nested/Drive two",
            "uuid": "abcd-1234",
            "filesystem": "vfat",
            "root": "/",
        }
        prior_destination = json.dumps(
            other_destination, separators=(",", ":")
        ).encode()
        fresh = (
            before.replace(b'"destination":null', b'"destination":' + prior_destination)
            .replace(b'"check_updates":true', b'"check_updates":false')
            .replace(
                b'"ownership":{}',
                b'"ownership":{"removal":{"scope":"ip_sync","keep":true}}',
            )
        )
        assert fresh != before and b'"generation":1' in fresh
        assert b'"check_updates":false' in fresh
        assert b'"removal":{"scope":"ip_sync","keep":true}' in fresh
        with lock.open("r+b") as owner:
            fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
            (support / "config").write_bytes(fresh)
            fcntl.flock(owner, fcntl.LOCK_UN)
        os.write(master, b"y\n")
        output.extend(
            wait_for_output(
                child, b"Destination saved: /tmp/mnt/Drive one/CFMgr/backup\n"
            )
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
    assert b"Prepare /tmp/mnt/Drive one/CFMgr/backup" in output
    assert (ram / "Drive one/CFMgr/backup").is_dir()
    selected_destination = dict(other_destination, mountpoint="/tmp/mnt/Drive one")
    expected = fresh.replace(b'"generation":1', b'"generation":2').replace(
        prior_destination,
        json.dumps(selected_destination, separators=(",", ":")).encode(),
    )
    assert (support / "config").read_bytes() == expected
    assert not (ram / "Drive two/CFMgr/backup").exists()

    reopened = run_entry(shell, entry, b"4\ne\ne\n")
    assert reopened.returncode == 0, reopened.stderr
    assert (
        b"Saved destination: /tmp/mnt/Drive one/CFMgr/backup (available)"
        in reopened.stdout
    )


def test_backup_menu_disambiguates_duplicate_labels_and_invalid_choices_are_read_only(
    shell, installed_backup_entry, tools
):
    entry, support, ram = installed_backup_entry
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n9\ne\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"1) Duplicate Drive | /tmp/mnt/Drive one" in result.stdout
    assert b"2) Duplicate Drive | /tmp/mnt/nested/Drive two" in result.stdout
    assert b"Invalid drive selection." in result.stdout
    assert b"2 Create archive" in result.stdout
    assert b"3 Archive preferences" in result.stdout
    assert (support / "config").read_bytes() == before
    assert not list(ram.glob("Drive */CFMgr/backup"))


def test_backup_menu_default_no_does_not_prepare_or_save(shell, installed_backup_entry):
    entry, support, ram = installed_backup_entry
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n1\ns\nn\n1\n\x04\x04")
    assert result.returncode == 0, result.stderr
    assert b"Save cancelled; no changes were written." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not (ram / "Drive one/CFMgr/backup").exists()


def test_backup_menu_interrupt_during_selection_does_not_mutate(
    shell, installed_backup_entry, tools
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
    assert not list(ram.glob("Drive */CFMgr/backup"))


def test_backup_menu_with_no_drives_keeps_destination_unset(
    shell, installed_backup_entry, tools
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=no-drives")
    )
    finish_package(entry, support, tools, shell)
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Backup drives: none available" in result.stdout
    assert b"No backup drives are available." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not list(ram.glob("Drive */CFMgr/backup"))


def test_backup_menu_reports_save_failure_without_claiming_rollback(
    shell, installed_backup_entry, tools
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=folder-failure")
    )
    finish_package(entry, support, tools, shell)
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n1\ns\ny\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert (
        b"Save did not complete; CFMgr/backup may have been prepared and existing contents were preserved."
        in result.stderr
    )
    assert (support / "config").read_bytes() == before
    assert not (ram / "Drive one/CFMgr/backup").exists()


def test_backup_menu_recovers_interrupted_store_save_without_drive(
    shell, installed_backup_entry, tools
):
    entry, support, ram = installed_backup_entry
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text(
        adapter_path.read_text().replace("scenario=normal", "scenario=publish-stop")
    )
    finish_package(entry, support, tools, shell)
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"4\n1\n1\ns\ny\nr\ny\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Pending recovery: yes" in result.stdout
    assert b"Recover previous Save" in result.stdout
    assert b"No backup drive is needed." in result.stdout
    assert b"Previous Save recovered; no settings were replayed." in result.stdout
    assert (support / "config").read_bytes() == before
    assert not list(support.glob(".config-save*"))
    assert (ram / "Drive one/CFMgr/backup").is_dir()


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
