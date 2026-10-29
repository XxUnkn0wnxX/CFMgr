"""Mounted diagnostic destination safety checks."""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest
from test_install import shell
from test_storage_mounts import fixture_tools, selected_shell

ROOT = Path(__file__).resolve().parents[1]
DRAFT = ROOT / "modules/lib/logging.sh"
__all__ = ["fixture_tools", "selected_shell", "shell"]


@pytest.mark.parametrize(
    ("path", "valid"),
    [
        ("/tmp/mnt/Drive name/CFMgr/diagnostics", True),
        ("/mnt/device/debug", True),
        ("", False),
        ("/", False),
        ("relative/name", False),
        ("/tmp//dir", False),
        ("/tmp/./dir", False),
        ("/tmp/../dir", False),
        ("/tmp/dir/", False),
        ("/tmp/dir\nother", False),
        ("/tmp/é", False),
        ("/" + "a" * 1024, False),
    ],
)
def test_diagnostic_destination_path_is_strictly_bounded(shell, path, valid):
    result = subprocess.run(
        [*shell, "-c", '. "$1"; cfmgr_log_path_valid "$2"', "test", str(DRAFT), path],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode == 0) is valid
    assert result.stdout == b""
    assert result.stderr == b""


@pytest.mark.parametrize(
    ("path", "mount", "valid"),
    [
        ("/tmp/mnt/disk/CFMgr/diagnostics", "/tmp/mnt/disk", True),
        ("/tmp/mnt/disk", "/tmp/mnt/disk", True),
        ("/tmp/mnt/disk2/CFMgr", "/tmp/mnt/disk", False),
        ("/jffs/CFMgr", "/tmp/mnt/disk", False),
        ("/tmp/mnt/disk/../foreign", "/tmp/mnt/disk", False),
    ],
)
def test_diagnostic_mount_ancestry_has_a_component_boundary(shell, path, mount, valid):
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; cfmgr_log_path_on_mount "$2" "$3"',
            "test",
            str(DRAFT),
            path,
            mount,
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode == 0) is valid
    assert result.stdout == b""
    assert result.stderr == b""


def test_shell_builtin_physical_directory_checks_preserve_paths_and_cwd(
    selected_shell, tmp_path
):
    ordinary = tmp_path / "ordinary"
    unusual = tmp_path / "space and \\ backslash"
    target = tmp_path / "physical-target"
    alias = tmp_path / "ancestor-link"
    for path in (ordinary, unusual, target):
        path.mkdir()
    alias.symlink_to(target, target_is_directory=True)
    missing = tmp_path / "missing"
    script = r"""
start_pwd=$PWD
start_physical=$(pwd -P) || exit 1
physical=$(CDPATH= cd -P "$1" && pwd -P && printf '.') || exit 2
[ "$physical" = "$1
." ] || exit 3
physical=$(CDPATH= cd -P "$2" && pwd -P && printf '.') || exit 4
[ "$physical" = "$2
." ] || exit 5
physical=$(CDPATH= cd -P "$3" && pwd -P && printf '.') || exit 6
[ "$physical" = "$4
." ] && [ "$physical" != "$3
." ] || exit 7
if physical=$(CDPATH= cd -P "$5" 2>/dev/null && pwd -P && printf '.'); then exit 8; fi
[ -z "$physical" ] || exit 9
[ "$PWD" = "$start_pwd" ] && [ "$(pwd -P)" = "$start_physical" ] || exit 10
"""
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            script,
            "physical-path-test",
            str(ordinary),
            str(unusual),
            str(alias),
            str(target),
            str(missing),
        ],
        cwd=tmp_path,
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_linux_owned_child_retains_capture_lock_and_descriptors(shell, tmp_path):
    """Kernel lock and mount pins survive the isolated controller's exit."""
    import fcntl
    import os
    import shutil
    import signal
    import sys
    import time

    if sys.platform != "linux":
        pytest.skip("Linux /proc and flock descriptor semantics are required")
    flock = shutil.which("flock")
    assert flock, "Native flock is required on the Linux test host"
    lock = tmp_path / "capture.lock"
    lock.touch(mode=0o600)
    ram = tmp_path / "ram"
    mount = tmp_path / "mount"
    leaf = mount / "diagnostics"
    ram.mkdir(mode=0o700)
    leaf.mkdir(parents=True, mode=0o700)
    script = r"""
. "$6"
exec 0<"$1" 5<"$2" 6<"$3" 7<"$4"
"$5" -n 0 || exit 1
_cfmgr_prerequisites_exec() { exec /bin/sleep 30; }
cfmgr_probe_stdout=/dev/null cfmgr_probe_stderr=/dev/null
_cfmgr_prerequisites_start_locked 9<&0 || exit 2
printf '%s\n' "$cfmgr_probe_pid"
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "lock-test",
            str(lock),
            str(ram),
            str(mount),
            str(leaf),
            flock,
            str(ROOT / "modules/lib/execution.sh"),
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stderr) == (0, b"")
    pid = int(result.stdout.strip())
    try:
        for fd, expected in ((0, lock), (5, ram), (6, mount), (7, leaf)):
            assert os.path.samefile(f"/proc/{pid}/fd/{fd}", expected)
        with lock.open("rb") as other, pytest.raises(BlockingIOError):
            fcntl.flock(other.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        os.kill(pid, signal.SIGTERM)
        deadline = time.monotonic() + 2
        with lock.open("rb") as other:
            while True:
                try:
                    fcntl.flock(other.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                    break
                except BlockingIOError:
                    assert time.monotonic() < deadline, (
                        "Owned child retained capture lock"
                    )
                    time.sleep(0.02)
    finally:
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


def test_linux_real_data_mount_pins_and_large_append(
    fixture_tools, tmp_path, monkeypatch
):
    """Real noexec ext4, destination pins, append, symlink swap and detach."""
    import test_storage_mounts as storage

    original = storage.FIXTURE.read_text()
    original = original.replace(
        "valid | alias_substitution | lazy_replacement | bind_identity | ro_noexec | backup_folder",
        "valid | alias_substitution | lazy_replacement | bind_identity | ro_noexec | diagnostic_folder | backup_folder",
        1,
    )
    branch = r"""
diagnostic_folder)
    # Adapt only the platform's mount namespace prefix into the owned fixture.
    sed "s@/tmp/mnt/?\* | /mnt/?\*@${fixture}/?*@g" "$root/modules/lib/logging.sh" >"$fixture/logging-fixture.sh"
    . "$fixture/logging-fixture.sh" || fail 'diagnostic controller not loaded'
    mkdir -m 700 "$fixture/log-probes"
    cfmgr_log_context=$fixture/log-probes
    cfmgr_log_lock=$cfmgr_log_context/capture.lock
    : >"$cfmgr_log_lock"
    chmod 600 "$cfmgr_log_lock"
    exec 0<"$cfmgr_log_lock"
    flock -n 0 || fail 'diagnostic callback lock unavailable'
    exec 5<"$cfmgr_log_context"
    cfmgr_log_tmp_mount=$(cfmgr_storage_mountinfo /usr/bin/awk /tmp /proc/self/mountinfo)
    cfmgr_log_interrupt=0 cfmgr_log_mount_pinned=0 cfmgr_log_walk_pinned=0 cfmgr_log_lock_held=1
    cfmgr_config_lock_fd0=0
    cfmgr_log_run() {
        mode=$1; tool=$2; shift 2
        cfmgr_probe_stdout=$fixture/log-probes/probe.out
        cfmgr_probe_stderr=$fixture/log-probes/probe.err
        : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"
        cfmgr_probe_mode=$mode
        _cfmgr_prerequisites_attachment || return $?
        case $mode in
        diagnostic-meta)
            "$tool" -ildn "$1" >"$cfmgr_probe_stdout" || return $?
            cfmgr_probe_exit=0
            if [ "${cfmgr_test_detach_after_metadata:-0}" = 1 ]; then
                cfmgr_test_detach_after_metadata=0
                umount -l "$mount_dir" || fail 'one-shot metadata detach failed'
            fi
            _cfmgr_prerequisites_attachment
            ;;
        diagnostic-mkdir) "$tool" -m 700 "/proc/self/fd/7/$1" ;;
        diagnostic-create) (umask 077; set -C; : >"/proc/self/fd/7/$1") ;;
        diagnostic-copy) "$tool" bs=4096 "count=$1" <&3 >&4 2>/dev/null ;;
        diagnostic-header) "$tool" bs=1 count=18 <&3 >"$cfmgr_probe_stdout" 2>/dev/null ;;
        *) fail "unexpected diagnostic mode $mode" ;;
        esac
    }
    mount -o remount,noexec "$mount_dir" || fail 'noexec remount failed'
    cfmgr_log_mount_snapshot=$(cfmgr_storage_mountinfo /usr/bin/awk "$mount_dir" /proc/self/mountinfo)
    cfmgr_log_data_mount_record "$cfmgr_log_mount_snapshot" || fail 'noexec data mount refused'
    exec 6<"$mount_dir"
    cfmgr_log_mount_pinned=1
    mkdir -m 755 "$mount_dir/CFMgr"
    mkdir -m 700 "$mount_dir/CFMgr/backup"
    printf 'backup intact\n' >"$mount_dir/CFMgr/backup/keep"
    cfmgr_log_walk_destination "$mount_dir/CFMgr/diagnostics" create || fail 'destination walk failed'
    [ -d "$mount_dir/CFMgr/diagnostics" ] || fail 'destination not created'
    [ "$(cat "$mount_dir/CFMgr/backup/keep")" = 'backup intact' ] || fail 'backup sibling changed'
    printf 'CFMGR-DEVELOPER 1\n' >"$mount_dir/CFMgr/diagnostics/developer.log"
    "$awk" 'BEGIN {for (i=0;i<12288;i++) printf "x"}' >>"$mount_dir/CFMgr/diagnostics/developer.log"
    chmod 600 "$mount_dir/CFMgr/diagnostics/developer.log"
    printf 'tail' >"$cfmgr_log_context/input"
    chmod 600 "$cfmgr_log_context/input"
    cfmgr_log_open_output developer.log append || fail 'existing large log rejected'
    cfmgr_log_developer_admit || fail 'owned log header rejected'
    exec 3<"$cfmgr_log_context/input"
    cfmgr_log_write_fd 4 || fail 'bounded append failed'
    [ "$(wc -c <"$mount_dir/CFMgr/diagnostics/developer.log")" -eq 12310 ] || fail 'wrong appended length'
    [ "$(tail -c 4 "$mount_dir/CFMgr/diagnostics/developer.log")" = tail ] || fail 'append bytes changed'
    exec 3<&- 4>&-
    mv "$mount_dir/CFMgr/diagnostics/developer.log" "$mount_dir/CFMgr/diagnostics/owned.log"
    printf '\001foreign-binary' >"$mount_dir/CFMgr/diagnostics/developer.log"
    chmod 600 "$mount_dir/CFMgr/diagnostics/developer.log"
    cfmgr_log_open_output developer.log append || fail 'foreign file failed metadata admission'
    if cfmgr_log_developer_admit; then fail 'foreign binary log accepted'; fi
    exec 3<&- 4>&-
    [ "$(wc -c <"$mount_dir/CFMgr/diagnostics/developer.log")" -eq 15 ] || fail 'foreign log was changed'
    rm "$mount_dir/CFMgr/diagnostics/developer.log"
    mv "$mount_dir/CFMgr/diagnostics/owned.log" "$mount_dir/CFMgr/diagnostics/developer.log"
    mv "$mount_dir/CFMgr/diagnostics" "$mount_dir/CFMgr/diagnostics-owned"
    ln -s "$mount_dir/CFMgr/backup" "$mount_dir/CFMgr/diagnostics"
    if cfmgr_log_attached; then fail 'replacement symlink admitted'; fi
    rm "$mount_dir/CFMgr/diagnostics"
    mv "$mount_dir/CFMgr/diagnostics-owned" "$mount_dir/CFMgr/diagnostics"
    cfmgr_log_attached || fail 'restored attachment rejected'
    cfmgr_log_open_output developer.log append || fail 'reopened held output rejected'
    cfmgr_log_developer_admit || fail 'reopened held output header rejected'
    exec 3<"$cfmgr_log_context/input"
    cfmgr_test_detach_after_metadata=1
    cfmgr_log_metadata /proc/self/fd/7/developer.log file || fail 'read-only metadata failed across detach'
    [ "$cfmgr_test_detach_after_metadata" = 0 ] || fail 'one-shot detach did not run'
    [ "$cfmgr_probe_exit:$cfmgr_log_meta_size" = 0:12310 ] || fail 'detached metadata receipt changed'
    for cfmgr_test_mode in diagnostic-meta diagnostic-count diagnostic-frame diagnostic-sanitize diagnostic-compare; do
        cfmgr_probe_mode=$cfmgr_test_mode
        _cfmgr_prerequisites_attachment || fail "context-only callback rejected $cfmgr_test_mode"
    done
    for cfmgr_test_mode in diagnostic-create diagnostic-mkdir diagnostic-copy diagnostic-source diagnostic-list diagnostic-digest; do
        cfmgr_probe_mode=$cfmgr_test_mode
        if _cfmgr_prerequisites_attachment; then fail "detached callback admitted $cfmgr_test_mode"; fi
    done
    if cfmgr_log_attached; then fail 'destination scope leaked after context callback'; fi
    cfmgr_test_held_output=$cfmgr_log_output
    if cfmgr_log_open_output health-1.log exclusive; then fail 'detached health file creation admitted'; fi
    [ ! -e /proc/self/fd/7/health-1.log ] && [ ! -L /proc/self/fd/7/health-1.log ] || fail 'detached health file appeared on held destination'
    [ ! -e "$mount_dir/CFMgr/diagnostics/health-1.log" ] && [ ! -L "$mount_dir/CFMgr/diagnostics/health-1.log" ] || fail 'detached health file appeared at stale mountpoint'
    cfmgr_log_output=$cfmgr_test_held_output
    if cfmgr_log_write_fd 4; then fail 'detached writable FD appended'; fi
    [ -f /proc/self/fd/3 ] && [ -f /proc/self/fd/4 ] || fail 'append rejection lacked held input or output descriptors'
    [ "$(wc -c </proc/self/fd/7/developer.log)" -eq 12310 ] || fail 'detached held output changed size'
    [ "$(tail -c 4 /proc/self/fd/7/developer.log)" = tail ] || fail 'detached held output tail changed'
    [ "$(cat /proc/self/fd/6/CFMgr/backup/keep)" = 'backup intact' ] || fail 'detached data changed'
    [ -f /proc/self/fd/0 ] || fail 'held capture lock lost after detach'
    exec 3<&- 4>&-
    exec 5<&- 6<&- 7<&-
    exec 0</dev/null
    printf 'PASS: diagnostic noexec mount, large append, context-only detached metadata and writer rejection\n'
    ;;
"""
    marker = "\nbackup_folder | backup_replacement | archive_source)"
    assert original.count(marker) == 1
    original = original.replace(marker, "\n" + branch + marker, 1)
    fixture = tmp_path / "diagnostic-fixture.sh"
    fixture.write_text(original)
    fixture.chmod(0o700)
    workdir = tmp_path / "work"
    workdir.mkdir(mode=0o700)
    monkeypatch.setattr(storage, "FIXTURE", fixture)
    result = storage.run_fixture(fixture_tools, "diagnostic_folder", workdir)
    storage.assert_fixture_passed(result, "diagnostic_folder")


@pytest.mark.parametrize(
    ("selected", "resolved", "mnt_root", "valid"),
    [
        ("/tmp/mnt/disk/real", "/tmp/mnt/disk/real", "/tmp/mnt", True),
        ("/mnt/disk/real", "/tmp/mnt/disk/real", "/tmp/mnt", True),
        ("/mnt/disk/link", "/tmp/mnt/disk/target", "/tmp/mnt", False),
        ("/tmp/mnt/disk/link", "/tmp/mnt/disk/target", "/tmp/mnt", False),
        ("/mnt/disk/real", "/other/disk/real", "/other", False),
    ],
)
def test_only_namespace_alias_may_canonicalize_custom_path(
    shell, selected, resolved, mnt_root, valid
):
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; cfmgr_log_alias_matches "$2" "$3" "$4"',
            "test",
            str(DRAFT),
            selected,
            resolved,
            mnt_root,
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode == 0) is valid
    assert result.stdout == b""
    assert result.stderr == b""


@pytest.mark.parametrize(
    ("event", "valid"),
    [
        ("CFMGR-EVENT 1 123 manager startup success 0\n", True),
        ("CFMGR-EVENT\t1 123 status health failed 1\n", True),
        ("CFMGR-EVENT 1 unknown manager startup ok 0\x1b\n", False),
        ("private-é", False),
    ],
)
def test_event_stage_rejects_control_and_non_ascii_input(shell, tmp_path, event, valid):
    stage = tmp_path / "context"
    stage.mkdir(mode=0o700)
    command = r"""
. "$1"
cfmgr_log_context=$2
cfmgr_log_metadata() { set -- $(wc -c <"$1"); cfmgr_log_meta_size=$1; }
cfmgr_log_stage_events "$3"
"""
    result = subprocess.run(
        [*shell, "-c", command, "stage-test", str(DRAFT), str(stage), event],
        env={"LC_ALL": "C", "PATH": "/usr/bin:/bin"},
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode == 0) is valid
    if valid:
        assert (stage / "events").read_bytes() == event.encode()
    else:
        assert not (stage / "events").exists()


def test_capture_does_not_start_with_unresolved_child(shell):
    command = r"""
. "$1"
cfmgr_probe_status=unresolved
cfmgr_probe_pid=''
cfmgr_log_capture developer 'CFMGR-EVENT 1 1 manager startup unknown 3'
"""
    result = subprocess.run(
        [*shell, "-c", command, "unresolved-test", str(DRAFT)],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        3,
        b"CFMGR-LOG-CAPTURE 1 unresolved unavailable - END\n",
        b"",
    )


def test_health_name_collision_preserves_existing_file(shell, tmp_path):
    boot = "12345678-1234-1234-1234-123456789abc"
    name = f"health-{boot}-5678-4321-1.log"
    (tmp_path / name).write_text("preserve prior capture")
    script = r"""
. "$1"
cfmgr_log_walk=$2 cfmgr_log_boot=$3 cfmgr_log_start=5678 cfmgr_log_pid=4321
cfmgr_log_attached() { return 0; }
cfmgr_log_open_output() {
    (umask 077; set -C; : >"$cfmgr_log_walk/$1") || return 1
    cfmgr_log_output_created=1
}
cfmgr_log_health_open || exit $?
printf '%s\n' "$cfmgr_log_output_name"
"""
    result = subprocess.run(
        [*shell, "-c", script, "collision-test", str(DRAFT), str(tmp_path), boot],
        capture_output=True,
        check=False,
        timeout=5,
    )
    next_name = f"health-{boot}-5678-4321-2.log"
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        (next_name + "\n").encode(),
        b"",
    )
    assert (tmp_path / name).read_text() == "preserve prior capture"
    assert (tmp_path / next_name).read_bytes() == b""


def test_cleanup_refuses_unregistered_same_prefix_object(shell, tmp_path):
    owned = tmp_path / "diagnostic-copy.1.out"
    injected = tmp_path / "diagnostic-copy.999.out"
    owned.write_bytes(b"owned")
    injected.write_bytes(b"must be preserved")
    script = r"""
. "$1"
cfmgr_log_context=$2 cfmgr_log_owned=''
cfmgr_log_register diagnostic-copy.1.out || exit 2
cfmgr_log_cleanup_inventory
"""
    result = subprocess.run(
        [*shell, "-c", script, "ledger-test", str(DRAFT), str(tmp_path)],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode != 0
    assert owned.read_bytes() == b"owned"
    assert injected.read_bytes() == b"must be preserved"


def test_linux_diagnostic_copy_worker_retains_guard_fds_through_supervisor(
    shell, tmp_path
):
    """Real supervisor/worker routing holds capture descriptors in a child."""
    import fcntl
    import os
    import shlex
    import shutil
    import signal
    import sys
    import time

    from test_prerequisites import pause_definition

    if sys.platform != "linux":
        pytest.skip("Linux /proc and native supervisor identity are required")
    lock = tmp_path / "capture.lock"
    lock.touch(mode=0o600)
    context = tmp_path / "context"
    mount = tmp_path / "mount"
    leaf = mount / "diagnostics"
    context.mkdir(mode=0o700)
    leaf.mkdir(parents=True, mode=0o700)
    source = tmp_path / "source"
    source.write_bytes(b"fixed stage")
    output = leaf / "developer.log"
    output.write_bytes(b"CFMGR-DEVELOPER 1\n")
    marker = tmp_path / "child.pid"
    tool = tmp_path / "blocking-native-writer"
    # This test adapter immediately execs one native utility and has no child
    # processes; actual dd bytes are covered by the real data-mount fixture.
    tool.write_text(
        "#!/bin/sh\nprintf '%s\\n' \"$$\" > "
        + shlex.quote(str(marker))
        + "\nexec /bin/sleep 30\n"
    )
    tool.chmod(0o700)
    flock = shutil.which("flock")
    assert flock, "Native flock is required on the Linux test host"
    command = r"""
. "$1/modules/lib/execution.sh"
. "$2"
cfmgr_source=$1 cfmgr_log_context=$3 cfmgr_log_interrupt=0 cfmgr_log_operations=0
cfmgr_probe_serial=0 cfmgr_log_owned='' cfmgr_config_lock_fd0=0 cfmgr_health_active=0
cfmgr_log_attached() { return 0; }
exec 0<"$4" 3<"$5" 4>>"$6" 5<"$3" 6<"$7" 7<"$8"
"$9" -n 0 || exit 91
cfmgr_prerequisites_supervisor || exit 92
cfmgr_log_deadline=$((cfmgr_probe_now + 10))
cfmgr_log_run diagnostic-copy "${10}" 1
"""
    command = command.replace(
        "\ncfmgr_source=$1", "\n" + pause_definition(shell) + "\ncfmgr_source=$1", 1
    )
    parent = subprocess.Popen(
        [
            *shell,
            "-c",
            command,
            "diagnostic-supervisor-test",
            str(ROOT),
            str(DRAFT),
            str(context),
            str(lock),
            str(source),
            str(output),
            str(mount),
            str(leaf),
            flock,
            str(tool),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    pid = None
    try:
        deadline = time.monotonic() + 1.5
        while not marker.exists() and parent.poll() is None:
            assert time.monotonic() < deadline, "Diagnostic worker did not start"
            time.sleep(0.01)
        assert marker.exists(), parent.communicate(timeout=2)
        pid = int(marker.read_text())
        for fd, expected in (
            (0, source),
            (4, output),
            (5, context),
            (6, mount),
            (7, leaf),
            (9, lock),
        ):
            assert os.path.samefile(f"/proc/{pid}/fd/{fd}", expected)
        with lock.open("rb") as other, pytest.raises(BlockingIOError):
            fcntl.flock(other.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        os.kill(pid, signal.SIGTERM)
        parent.communicate(timeout=5)
        assert parent.returncode != 0
        with lock.open("rb") as other:
            fcntl.flock(other.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    finally:
        if pid is not None:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        if parent.poll() is None:
            parent.terminate()
            parent.communicate(timeout=5)


@pytest.mark.parametrize(
    ("payload", "valid"),
    [
        (b"CFMGR-DEVELOPER 1\n", True),
        (b"foreign log\n", False),
        (b"\x00CFMGR-DEVELOPER 1", False),
        (b"CFMGR-DEVELOPER 1", False),
        (b"CFMGR-DEVELOPER 1\nother\n", False),
    ],
)
def test_developer_owner_header_rejects_foreign_and_binary(
    shell, tmp_path, payload, valid
):
    receipt = tmp_path / "bounded-header"
    receipt.write_bytes(payload)
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; cfmgr_log_header_check "$2"',
            "owner-header-test",
            str(DRAFT),
            str(receipt),
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode == 0) is valid
    assert receipt.read_bytes() == payload


@pytest.mark.parametrize(
    ("failure", "code", "receipt", "partial", "cleaned"),
    [
        ("before-write", 1, "unavailable", False, True),
        ("partial-write", 1, "incomplete", True, True),
        ("unresolved-write", 3, "unresolved", True, False),
    ],
)
def test_capture_failure_receipt_preserves_history_and_unresolved_context(
    shell, tmp_path, failure, code, receipt, partial, cleaned
):
    """Public result policy; real writer/mount/lock behavior has native cases."""
    prior = tmp_path / "prior.log"
    prior.write_bytes(b"previous sanitized capture\n")
    script = r"""
. "$1"
cfmgr_test_capture_root=$2 cfmgr_test_capture_failure=$3
cfmgr_log_prepare() {
    cfmgr_log_context=$cfmgr_test_capture_root
    cfmgr_probe_pid='' cfmgr_probe_status=reaped
}
cfmgr_log_capture_work() {
    [ "$cfmgr_test_capture_failure" != before-write ] || return 1
    printf 'partial sanitized batch\n' >>"$cfmgr_test_capture_root/prior.log"
    cfmgr_log_started_output=1
    [ "$cfmgr_test_capture_failure" != unresolved-write ] || return 3
    return 1
}
cfmgr_log_cleanup() { : >"$cfmgr_test_capture_root/cleaned"; }
cfmgr_log_capture developer 'CFMGR-EVENT 1 1 manager save started 0'
"""
    result = subprocess.run(
        [*shell, "-c", script, "capture-failure", str(DRAFT), str(tmp_path), failure],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        code,
        f"CFMGR-LOG-CAPTURE 1 {receipt} unavailable - END\n".encode(),
        b"",
    )
    expected = b"previous sanitized capture\n"
    if partial:
        expected += b"partial sanitized batch\n"
    assert prior.read_bytes() == expected
    assert (tmp_path / "cleaned").exists() is cleaned


@pytest.mark.parametrize(
    "name",
    [
        "developer.log",
        "health-01234567-89ab-cdef-0123-456789abcdef-10-20-1.log",
        "health-abcdef01-2345-6789-abcd-ef0123456789-10-20-1.log",
        "scribe-abcdef01-2345-6789-abcd-ef0123456789-10-20-ddns-0-1.log",
    ],
)
def test_native_fixed_creation_returns_success_and_preserves_collisions(
    shell, tmp_path, name
):
    import sys

    if sys.platform != "linux":
        pytest.skip("Linux directory descriptor paths are required")
    script = r"""
exec 7<"$1" || exit 90
shift
exec "$@"
"""
    command = [
        *shell,
        "-c",
        script,
        "fixed-create",
        str(tmp_path),
        *shell,
        str(ROOT / "modules/helpers/worker.sh"),
        "diagnostic-create",
        "/bin/sh",
        str(tmp_path),
        name,
    ]
    created = subprocess.run(command, capture_output=True, check=False, timeout=5)
    assert (created.returncode, created.stdout, created.stderr) == (0, b"", b"")
    target = tmp_path / name
    assert target.is_file() and not target.is_symlink()
    assert target.stat().st_mode & 0o777 == 0o600
    target.write_bytes(b"retained diagnostic history\n")
    collision = subprocess.run(command, capture_output=True, check=False, timeout=5)
    assert collision.returncode != 0
    assert target.read_bytes() == b"retained diagnostic history\n"
