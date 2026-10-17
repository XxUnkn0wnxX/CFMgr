"""Real history callbacks with the shared host adapter and retained RAM receipts."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest
from test_archive_io import archive as source_archive_fixture
from test_archive_io import passed, run
from test_archive_io import shell as shell_fixture

shell = shell_fixture
base_archive = source_archive_fixture


@pytest.fixture
def archive(base_archive):
    if sys.platform == "darwin":
        support, ram, *_ = base_archive
        worker = support / "modules/helpers/worker.sh"
        body = worker.read_text().replace("/proc/self/fd/5", str(ram))
        body = body.replace('[ "$3" -ef /proc/self/fd/2 ]', '[ -f "$3" ]')
        worker.write_text(body)
    else:
        # Extend the shared fixture lock assertion to history JSON stdin modes.
        wrapper = Path(base_archive[-1]["TEST_AWK"])
        body = wrapper.read_text().replace(
            "${CFMGR_PAYLOAD_MODE:-}",
            "${CFMGR_PAYLOAD_MODE:-history-${CFMGR_HISTORY_MODE:-}}",
        )
        body = body.replace(
            "plan|runtime-json|certificate-json|drafts)",
            "plan|runtime-json|certificate-json|drafts|history-policy)",
        )
        wrapper.write_text(body)
    return base_archive


HISTORY = r"""
cfmgr_history_limit=1048576 cfmgr_history_memory_kib=32768
cfmgr_history_deadline=$cfmgr_archive_deadline
cfmgr_hr_phase=native cfmgr_hr_lib=$support/modules/lib
cfmgr_history_context=$ram
cfmgr_backup_history_attached() { cfmgr_store_attachment_ok; }
cfmgr_history_runtime_seed || exit 81
"""


def test_real_callbacks_account_store_plan_append_and_retirement(archive, shell):
    ram = archive[1]
    (ram / "store-archive-plan.1.out").write_bytes(b"p" * 2048)
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
initial_bytes=$cfmgr_hr_live_bytes initial_files=$cfmgr_hr_live_files
[ "$initial_bytes" -ge 2048 ] || exit 82
cfmgr_history_new || exit 83
owned=$cfmgr_history_new_path
cfmgr_history_runtime_write "$owned" alpha || exit 84
cfmgr_history_runtime_write "$owned" beta || exit 85
[ "$cfmgr_hr_live_files" = "$((initial_files+1))" ] || exit 86
[ "$cfmgr_hr_live_bytes" = "$((initial_bytes+${#owned}-${#ram}-1+64+11))" ] || exit 87
cfmgr_hr_run history-count 4096 "$cfmgr_store_wc" "$owned" || exit 88
[ "$cfmgr_hr_live_files" = "$((initial_files+3))" ] || exit 89
cfmgr_hr_line "$cfmgr_hr_result" || exit 90
[ "$cfmgr_hr_live_files" = "$((initial_files+1))" ] || exit 91
[ -f "$ram/store-archive-plan.1.out" ] || exit 92
""",
        )
    )

    assert next(ram.glob("history-[0-9]*")).read_bytes() == b"alpha\nbeta\n"
    assert not list(ram.glob("history-*.*.out"))
    assert not list(ram.glob("history-*.*.err"))


def test_history_seed_preserves_glob_setting_for_later_store_cleanup(archive, shell):
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
for wanted in enabled disabled; do
    case $wanted in enabled) set +f ;; disabled) set -f ;; esac
    cfmgr_history_runtime_seed || exit 82
    # Missing task metadata is an ordinary observation failure, with no stderr.
    if cfmgr_hr_stat 0; then exit 85; fi
    case $wanted:$- in enabled:*f* | disabled:*f*)
        [ "$wanted" = disabled ] || exit 83 ;;
    *) [ "$wanted" = enabled ] || exit 84 ;;
    esac
done
""",
        )
    )


def test_aggregate_limit_includes_preexisting_parent_receipts(archive, shell):
    (archive[1] / "store-archive-plan.1.out").write_bytes(b"p" * 4096)
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_history_limit=$((cfmgr_hr_live_bytes+511))
cfmgr_hr_run history-count 4096 "$cfmgr_store_wc" "$ram/store-archive-plan.1.out" && exit 82
[ "$cfmgr_probe_serial" = 0 ] || exit 83
""",
        )
    )


def test_file_budget_counts_parent_files_and_reserves_supervised_pair(archive, shell):
    for number in range(511):
        (archive[1] / f"store-{number}").touch()
    passed(
        run(
            archive,
            shell,
            # Metadata semantics are covered by the real-tool case above. This
            # boundary case isolates the 512-file count without 511 ls launches.
            "cfmgr_hr_ram_meta() { cfmgr_hr_ram_inode=1 cfmgr_hr_ram_size=0; }\n"
            + HISTORY
            + r"""
cfmgr_history_runtime_reserve 1 && exit 82
[ "$cfmgr_hr_live_files" -ge 511 ] || exit 83
""",
        )
    )


def test_failed_phase_does_not_replace_prior_anchors(archive, shell):
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_phase=native cfmgr_hr_anchor=old cfmgr_hr_root=oldroot cfmgr_hr_snapshot=oldmount
_cfmgr_history_runtime_init() { cfmgr_hr_phase=entware cfmgr_hr_anchor=bad cfmgr_hr_root=bad cfmgr_hr_snapshot=bad; return 3; }
cfmgr_history_runtime_init entware && exit 82
[ "$?" = 3 ] || exit 83
[ "$cfmgr_hr_phase:$cfmgr_hr_anchor:$cfmgr_hr_root:$cfmgr_hr_snapshot" = native:old:oldroot:oldmount ] || exit 84
""",
        )
    )


@pytest.mark.skipif(
    sys.platform != "linux", reason="Retained FD0/FD9 requires Linux proc"
)
def test_history_json_worker_keeps_borrowed_writer_lock(archive, shell):
    # The shared archive fixture checks actual inherited lock identity in its
    # real AWK wrapper. Policy consumes stdin and must retain the lock on FD9.
    # Actual lock contention after parent close is separate shared I/O proof.
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
"$TEST_FLOCK" -n 0 || exit 81
cfmgr_hr_run history-policy-decode 65536 "$cfmgr_store_awk" 7b2276657273696f6e223a317d || exit 82
input=$cfmgr_hr_result
cfmgr_hr_run history-policy-json 4096 "$cfmgr_store_awk" "$support/modules/lib" "$input" 13 ddns "$cfmgr_history_limit" || exit 83
""",
        )
    )


@pytest.mark.parametrize("change", ["stable", "edit", "replace", "unsafe"])
def test_cron_data_boundary_retains_exact_bytes_and_both_receipts(
    archive, shell, change
):
    # Fixed probe outcomes model the router metadata observed by the parent;
    # native descriptor reads have a separate Linux-only test below.
    (archive[1] / "cron-data").write_bytes(b"job one\n")
    script = (
        HISTORY
        + r"""
initial_files=$cfmgr_hr_live_files
cfmgr_hr_native() { :; }
cfmgr_hr_cron_boundary() {
    boundary_count=$((${boundary_count:-0}+1))
    [ "$TEST_CRON_CHANGE" != unsafe ] || return 1
    cfmgr_hr_cron_bytes=8
    cfmgr_hr_cron_observed='var:drwxrwxrwt:cron:-rw-rw-rw-:inode1:8:mount1:0:1'
    if [ "$TEST_CRON_CHANGE:$boundary_count" = replace:2 ]; then cfmgr_hr_cron_observed=replaced; fi
    if [ "$TEST_CRON_CHANGE:$boundary_count" = edit:2 ]; then printf 'job two\n' >"$ram/cron-data"; fi
}
cfmgr_prerequisites_run() {
    shift 9
    cfmgr_probe_serial=$((cfmgr_probe_serial+1))
    cfmgr_probe_stdout=$ram/history-cron.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$ram/history-cron.$cfmgr_probe_serial.err
    : >"$cfmgr_probe_stderr"
    case $cfmgr_hr_run_mode in
        history-account) printf 'admin\n' >"$cfmgr_probe_stdout" ;;
        history-cron-read) cat "$ram/cron-data" >"$cfmgr_probe_stdout" ;;
        history-count) "$cfmgr_store_wc" -c "$1" >"$cfmgr_probe_stdout" ;;
        history-digest) "$TEST_OPENSSL" dgst -sha256 -r "$1" >"$cfmgr_probe_stdout" ;;
        *) return 2 ;;
    esac
    cfmgr_probe_exit=$? cfmgr_probe_status=reaped
}
if cfmgr_hr_cron; then
    [ "$TEST_CRON_CHANGE" = stable ] || exit 82
    [ -f "$cfmgr_probe_stdout" ] && [ -f "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stderr" ] || exit 83
    [ -n "$cfmgr_hr_cron_fingerprint" ] || exit 84
    [ "$cfmgr_hr_live_files" = "$((initial_files+2))" ] || exit 85
else
    code=$?
    [ "$TEST_CRON_CHANGE" != stable ] || exit 86
    if [ "$TEST_CRON_CHANGE" = unsafe ]; then [ "$code" = 1 ]; else [ "$code" = 2 ]; fi
fi
"""
    )
    archive[-1]["TEST_CRON_CHANGE"] = change
    passed(run(archive, shell, script))
    if change == "stable":
        retained = {path.name for path in archive[1].iterdir()}
        receipts = {name for name in retained if name.startswith("history-cron.")}
        assert len(receipts) == 2
        expected = {"cron-data", "lock"} if sys.platform == "linux" else {"cron-data"}
        assert retained - receipts == expected


@pytest.mark.parametrize(
    "mode,uid,links,expected",
    [
        ("-rw-rw-rw-", "0", "1", 0),
        ("prw-------", "0", "1", 1),
        ("-rw-------", "1", "1", 1),
        ("-rw-------", "0", "2", 1),
    ],
)
def test_rotation_lock_admits_only_owned_regular_single_link(
    archive, shell, mode, uid, links, expected
):
    archive[-1].update(TEST_LOCK_MODE=mode, TEST_LOCK_UID=uid, TEST_LOCK_LINKS=links)
    result = run(
        archive,
        shell,
        HISTORY
        + r"""
cfmgr_hr_meta_raw() { cfmgr_hr_mode=$TEST_LOCK_MODE cfmgr_hr_uid=$TEST_LOCK_UID cfmgr_hr_links=$TEST_LOCK_LINKS cfmgr_hr_inode=42; }
cfmgr_hr_mount_identity() { cfmgr_hr_observed_mount=7 cfmgr_hr_observed_device=0:1; }
cfmgr_hr_text_frame() { [ "$2" = 'ROTATION 42 7 0:1 END
' ]; }
cfmgr_hr_rotation
""",
    )
    assert result.returncode == expected, result.stderr
    assert result.stdout == result.stderr == b""


@pytest.mark.parametrize(
    "observations,expected,mode",
    [
        ("absent", 0, "whole"),
        ("writer", 0, "prefix"),
        ("unknown", 4, ""),
        ("unresolved", 3, ""),
        ("gone absent", 0, "whole"),
        ("gone gone", 4, ""),
    ],
)
def test_cloud_capture_callback_preserves_admission_outcomes(
    archive, shell, observations, expected, mode
):
    # Exercise real public callbacks on a private owned source. Only proc
    # observation is supplied; actual Linux proc/FD proof remains its own gate.
    source = archive[1].parent / "source/var/log"
    source.mkdir(parents=True)
    (source / "cloudflared.log").write_bytes(b"line\n")
    support = archive[0]
    backup = support / "modules/backup.sh"
    backup.write_text(
        backup.read_text().replace(
            "/proc/self/fd/3/var/log/cloudflared.log", str(source / "cloudflared.log")
        )
    )
    archive[-1].update(
        TEST_OBSERVATIONS=observations,
        TEST_EXPECTED=str(expected),
        TEST_EXPECTED_MODE=mode,
    )
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_phase=source cfmgr_history_lock_held=1 cfmgr_config_lock_fd0=1
cfmgr_hr_writer_observe() {
    next=${TEST_OBSERVATIONS%% *}
    case $TEST_OBSERVATIONS in *' '*) TEST_OBSERVATIONS=${TEST_OBSERVATIONS#* } ;; esac
    case $next in
        absent) cfmgr_hr_writer_evidence=absent ;;
        writer) cfmgr_hr_writer_evidence='boot:pid:start:exe:sha:gen:argv:fd:append' ;;
        unknown) return 4 ;;
        unresolved) return 3 ;;
        gone) return 5 ;;
    esac
}
if cfmgr_archive_cloud_capture_mode "$ram/../source/var/log/cloudflared.log"; then code=0; else code=$?; fi
[ "$code" = "$TEST_EXPECTED" ] || exit 82
[ "$code" != 0 ] || [ "$cfmgr_archive_capture_mode" = "$TEST_EXPECTED_MODE" ] || exit 83
""",
        )
    )


@pytest.mark.parametrize(
    "after,expected", [("writer", 0), ("absent", 1), ("other", 1), ("unresolved", 3)]
)
def test_cloud_capture_revalidation_rejects_post_admission_changes(
    archive, shell, after, expected
):
    archive[-1].update(TEST_AFTER=after, TEST_EXPECTED=str(expected))
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_writer_source=$ram/source cfmgr_hr_writer_saved=writer
cfmgr_history_lock_held=1 cfmgr_config_lock_fd0=1
cfmgr_hr_writer_observe() { [ "$TEST_AFTER" != unresolved ] || return 3; cfmgr_hr_writer_evidence=$TEST_AFTER; }
if cfmgr_archive_cloud_capture_revalidate "$ram/source"; then code=0; else code=$?; fi
[ "$code" = "$TEST_EXPECTED" ]
""",
        )
    )


@pytest.mark.parametrize(
    "fault", ["none", "var-unsafe", "ancestor-write", "endpoint-link", "endpoint-owner"]
)
def test_production_cron_boundary_has_narrow_data_permissions(archive, shell, fault):
    archive[-1]["TEST_BOUNDARY_FAULT"] = fault
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_cron_path=/var/spool/cron/crontabs/admin
cfmgr_hr_run() { cfmgr_hr_result=unused; }
cfmgr_hr_line() { cfmgr_hr_line=$cfmgr_hr_cron_path; }
cfmgr_hr_mount_identity() { cfmgr_hr_observed_mount_identity='7 1 0:1 / /var tmpfs tmpfs rw rw'; }
cfmgr_hr_meta_raw() {
    cfmgr_hr_inode=42 cfmgr_hr_mode=drwxr-xr-x cfmgr_hr_uid=0 cfmgr_hr_links=1 cfmgr_hr_size=0
    case $1 in
        /var) cfmgr_hr_mode=drwxrwxrwt; [ "$TEST_BOUNDARY_FAULT" != var-unsafe ] || cfmgr_hr_mode=drwxrwxrwx ;;
        /var/spool) [ "$TEST_BOUNDARY_FAULT" != ancestor-write ] || cfmgr_hr_mode=drwxrwxr-x ;;
        */admin)
            cfmgr_hr_mode=-rw-rw-rw- cfmgr_hr_size=100
            [ "$TEST_BOUNDARY_FAULT" != endpoint-link ] || cfmgr_hr_mode=lrwxrwxrwx
            [ "$TEST_BOUNDARY_FAULT" != endpoint-owner ] || cfmgr_hr_uid=1
            ;;
    esac
    return 0
}
if cfmgr_hr_cron_boundary; then [ "$TEST_BOUNDARY_FAULT" = none ]; else [ "$TEST_BOUNDARY_FAULT" != none ]; fi
""",
        )
    )


@pytest.fixture(scope="module")
def logger_binary(tmp_path_factory):
    import shutil
    import subprocess

    directory = tmp_path_factory.mktemp("history-native-logger")
    source = directory / "logger.c"
    source.write_text(r"""
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
int main(void) {
    const char *log = getenv("CFMGR_FIXTURE_LOG");
    const char *ready = getenv("CFMGR_FIXTURE_READY");
    int flags = O_WRONLY | O_CREAT;
    if (!getenv("CFMGR_FIXTURE_NONAPPEND")) flags |= O_APPEND;
    int fd = open(log, flags, 0600);
    if (fd < 0 || write(fd, "line\n", 5) != 5) return 1;
    int marker = open(ready, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (marker < 0 || write(marker, "ready\n", 6) != 6 || close(marker)) return 1;
    for (;;) pause();
}
""")
    compiler = shutil.which("cc")
    assert compiler, "The existing native fixture toolchain is required"
    binary = directory / "cloudflared"
    subprocess.run(
        [compiler, "-O0", "-o", str(binary), str(source)],
        check=True,
        capture_output=True,
        timeout=15,
    )
    return binary


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Actual process executable/argv/append FD proof requires Linux proc",
)
@pytest.mark.parametrize(
    "kind", ["append", "nonappend", "wrong-executable", "ambiguous"]
)
def test_production_writer_observes_actual_relevant_process_and_fd(
    archive, shell, logger_binary, kind
):
    import hashlib
    import os
    import shutil
    import subprocess
    import time

    source = archive[1].parent / "source"
    (source / "bin").mkdir(parents=True)
    (source / "var/log").mkdir(parents=True)
    binary = source / "bin/cloudflared"
    shutil.copy2(logger_binary, binary)
    plan = archive[1] / "store-archive-plan.1.out"
    plan.write_text(
        "CFMGR-PAYLOAD-PLAN 1 2 2\n"
        + f"WRITER cloudflared {b'/opt/bin/cloudflared'.hex()} 1 {hashlib.sha256(binary.read_bytes()).hexdigest()}\n"
        + f"OWNER history.cloudflared {b'/opt/var/log/cloudflared.log'.hex()} 1 -\nEND 3\n"
    )
    library = archive[0] / "modules/backup.sh"
    library.write_text(
        library.read_text()
        .replace("cfmgr_hr_run() {", "cfmgr_test_hr_run() {", 1)
        .replace("cfmgr_hr_meta_raw() {", "cfmgr_test_hr_meta_raw() {", 1)
    )
    archive[-1].update(TEST_SOURCE=str(source), TEST_WRITER_KIND=kind)
    setup = (
        HISTORY
        + r"""
cfmgr_history_deadline=$((cfmgr_probe_now+60)) cfmgr_archive_deadline=$((cfmgr_probe_now+60))
cfmgr_hr_run() {
    if [ "$3" = /usr/sbin/openssl ]; then
        selected_mode=$1 selected_cap=$2; shift 3
        cfmgr_test_hr_run "$selected_mode" "$selected_cap" "$TEST_OPENSSL" "$@"
    else cfmgr_test_hr_run "$@"; fi
}
# Fixture files belong to the CI account. Map that owner to the router root
# contract only at the metadata boundary; actual proc/inode/hash/FDs stay real.
cfmgr_hr_meta_raw() { cfmgr_test_hr_meta_raw "$@" || return $?; cfmgr_hr_uid=0; }
cfmgr_hr_mount_identity() {
    cfmgr_hr_observed_mount=${observed_mount:-123} cfmgr_hr_observed_device=0:1
}
cfmgr_hr_native() { :; }
cfmgr_hr_phase=source cfmgr_hr_root=$TEST_SOURCE cfmgr_hr_anchor=/proc/self/fd/3
cfmgr_history_plan=$ram/store-archive-plan.1.out
cfmgr_history_lock_held=1
exec 3<"$TEST_SOURCE"
: >"$ram/rotation"
exec 4<>"$ram/rotation"
"$TEST_FLOCK" -n 0 && "$TEST_FLOCK" -n 4 || exit 81
"""
    )
    live = source / "var/log/cloudflared.log"
    live.touch(mode=0o600)
    if kind == "append":
        parked_binary = binary.with_suffix(".parked")
        binary.rename(parked_binary)
        # No candidate means the owned log is copied whole. No executable
        # provenance lookup is needed for this complete inactive observation.
        passed(
            run(
                archive,
                shell,
                setup
                + r"""
cfmgr_archive_cloud_capture_mode "$TEST_SOURCE/var/log/cloudflared.log" || exit 82
[ "$cfmgr_archive_capture_mode" = whole ] || exit 83
""",
                timeout=70,
            )
        )
        parked_binary.rename(binary)
    executable = binary if kind != "wrong-executable" else logger_binary
    children = []
    try:
        for index in range(2 if kind == "ambiguous" else 1):
            ready = archive[1].parent / f"logger-ready-{index}"
            env = {
                **os.environ,
                "CFMGR_FIXTURE_LOG": str(live),
                "CFMGR_FIXTURE_READY": str(ready),
            }
            if kind == "nonappend":
                env["CFMGR_FIXTURE_NONAPPEND"] = "1"
            child = subprocess.Popen(
                [
                    "/opt/bin/cloudflared",
                    "--logfile",
                    "/opt/var/log/cloudflared.log",
                    "tunnel",
                    "run",
                ],
                executable=str(executable),
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            children.append(child)
            archive[-1]["TEST_LOGGER_PID"] = str(child.pid)
            deadline = time.monotonic() + 3
            while (
                not ready.exists()
                and time.monotonic() < deadline
                and child.poll() is None
            ):
                time.sleep(0.01)
            assert ready.read_bytes() == b"ready\n"
        passed(
            run(
                archive,
                shell,
                setup
                + r"""
if cfmgr_archive_cloud_capture_mode "$TEST_SOURCE/var/log/cloudflared.log"; then code=0; else code=$?; fi
if [ "$TEST_WRITER_KIND" = append ]; then
    [ "$code:$cfmgr_archive_capture_mode" = 0:prefix ] || exit 82
    cfmgr_archive_cloud_capture_revalidate "$TEST_SOURCE/var/log/cloudflared.log" || exit 83
    kill -TERM "$TEST_LOGGER_PID" || exit 84
    cfmgr_archive_cloud_capture_revalidate "$TEST_SOURCE/var/log/cloudflared.log" && exit 85
    [ "$?" = 1 ] || exit 86
else [ "$code" = 4 ] || exit 84; fi
""",
                timeout=70,
            )
        )
    finally:
        for child in children:
            child.terminate()
        for child in children:
            child.wait(timeout=3)


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Child-only FD3 and inherited FD0/FD4 lock proof needs Linux proc",
)
def test_fixed_cron_reader_uses_child_fd3_and_preserves_parent_pins(archive, shell):
    import shlex

    ram = archive[1]
    cron = ram.parent / "cron"
    cron.mkdir()
    (cron / "admin").write_bytes(b"native schedule\n")
    (ram.parent / "parent-source").mkdir()
    rotation = ram / "rotation"
    rotation.touch()
    worker = archive[0] / "modules/helpers/worker.sh"
    worker.write_text(
        worker.read_text().replace("/var/spool/cron/crontabs/", str(cron) + "/")
    )
    dd = ram.parent / "cron-locked-dd"
    dd.write_text(
        "#!/bin/sh\n"
        + f"[ /proc/self/fd/3 -ef {shlex.quote(str(cron / 'admin'))} ] || exit 91\n"
        + f"[ /proc/self/fd/4 -ef {shlex.quote(str(rotation))} ] || exit 92\n"
        + f'exec {shlex.quote(archive[-1]["TEST_DD"])} "$@"\n'
    )
    dd.chmod(0o700)
    archive[-1]["TEST_CRON_DD"] = str(dd)
    archive[-1]["TEST_CRON_SOURCE"] = str(cron / "admin")
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
exec 3<"$ram/../parent-source" 4<>"$ram/rotation"
"$TEST_FLOCK" -n 0 && "$TEST_FLOCK" -n 4 || exit 82
cfmgr_hr_run history-cron-read 4096 "$TEST_CRON_DD" "$TEST_CRON_SOURCE" 16 || exit 83
[ /proc/self/fd/3 -ef "$ram/../parent-source" ] && [ /proc/self/fd/4 -ef "$ram/rotation" ] || exit 84
[ "$(cat "$cfmgr_hr_result")" = 'native schedule' ] || exit 85
""",
        )
    )


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Actual held rotation inode checks require Linux proc",
)
@pytest.mark.parametrize("change", ["truncate", "replace", "mount"])
def test_rotation_release_rechecks_inode_and_mount_but_ignores_truncation(
    archive, shell, change
):
    rotation = archive[1] / "rotation"
    rotation.write_bytes(b"old lock content\n")
    rotation.chmod(0o666)
    library = archive[0] / "modules/backup.sh"
    library.write_text(
        library.read_text()
        .replace("/tmp/scribeLogRotate.flock", str(rotation))
        .replace("cfmgr_hr_meta_raw() {", "cfmgr_test_hr_meta_raw() {", 1)
    )
    archive[-1]["TEST_ROTATION_CHANGE"] = change
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_phase=source
cfmgr_hr_meta_raw() { cfmgr_test_hr_meta_raw "$@" || return $?; cfmgr_hr_uid=0; }
cfmgr_history_rotation_meta || exit 82
cfmgr_history_rotation_identity=$cfmgr_history_meta_value
exec 4<"$ram/rotation"
"$TEST_FLOCK" -n 4 || exit 83
cfmgr_history_lock_held=1
case $TEST_ROTATION_CHANGE in
    truncate) : >"$ram/rotation" ;;
    replace) mv "$ram/rotation" "$ram/rotation-old"; : >"$ram/rotation" ;;
    mount) observed_mount=124 ;;
esac
if cfmgr_backup_history_release; then
    [ "$TEST_ROTATION_CHANGE" = truncate ] || exit 84
else [ "$TEST_ROTATION_CHANGE" != truncate ] || exit 85; fi
""",
        )
    )


def test_native_entware_source_phase_transitions_keep_validated_identity(
    archive, shell
):
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_store_jffs=/jffs cfmgr_store_source=/jffs/addons/CFMgr.d
cfmgr_hr_native() { :; }
cfmgr_hr_protect() { [ "$cfmgr_hr_expected" = /jffs/addons/CFMgr.d/modules/backup.sh ]; }
cfmgr_storage_attached() { :; }
cfmgr_archive_source_attached() { :; }
cfmgr_backup_attached() { :; }
cfmgr_hr_run() { :; }
cfmgr_hr_line() { cfmgr_hr_line='UUID testuuid END'; }
cfmgr_history_runtime_init native || exit 82
[ "$cfmgr_hr_phase:$cfmgr_hr_anchor" = native: ] || exit 83
cfmgr_storage_pinned=1 cfmgr_storage_opt=/drive/entware
cfmgr_storage_filesystem=ext4 cfmgr_storage_fsroot=/ cfmgr_storage_relative=entware
cfmgr_history_want_uuid=testuuid cfmgr_history_want_filesystem=ext4 cfmgr_history_want_root=/ cfmgr_history_want_relative=entware
cfmgr_storage_snapshot='7	1	8:1	/	/drive	ext4	/dev/fake	rw	rw'
cfmgr_history_runtime_init entware || exit 84
[ "$cfmgr_hr_phase:$cfmgr_hr_anchor:$cfmgr_hr_device" = entware:/proc/self/fd/7:8:1 ] || exit 85
cfmgr_archive_source_pinned=1 cfmgr_archive_source_root=/drive/entware
cfmgr_archive_source_snapshot=$cfmgr_storage_snapshot
cfmgr_archive_source_want_uuid=testuuid cfmgr_archive_source_want_fs=ext4 cfmgr_archive_source_want_root=/ cfmgr_archive_source_want_relative=entware
cfmgr_history_runtime_init source || exit 86
[ "$cfmgr_hr_phase:$cfmgr_hr_anchor" = source:/proc/self/fd/3 ] || exit 87
cfmgr_archive_source_want_uuid=other
cfmgr_history_runtime_init source && exit 88
[ "$cfmgr_hr_phase:$cfmgr_hr_anchor:$cfmgr_hr_root" = source:/proc/self/fd/3:/drive/entware ] || exit 89
""",
        )
    )


@pytest.mark.parametrize(
    "condition,expected", [("normal", 0), ("argv-unresolved", 3), ("exec-changed", 1)]
)
def test_process_callback_preserves_unresolved_and_detects_exec_transition(
    archive, shell, condition, expected
):
    archive[-1].update(TEST_PROCESS_CONDITION=condition, TEST_EXPECTED=str(expected))
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_root=/drive/entware
cfmgr_hr_native() { :; }
cfmgr_hr_tool() { cfmgr_hr_inode=123; }
cfmgr_hr_stat() { cfmgr_hr_stat_comm=syslog-ng cfmgr_hr_stat_start=99; }
cfmgr_hr_run() {
    mode=$1
    sequence=$((${sequence:-0}+1))
    cfmgr_hr_result=$ram/sample-$sequence
    cfmgr_probe_status=reaped cfmgr_probe_exit=0
    case $mode in
        history-proc-list|history-proc-pids) printf '42\n' >"$cfmgr_hr_result" ;;
        history-realpath)
            exe_count=$((${exe_count:-0}+1))
            if [ "$TEST_PROCESS_CONDITION:$exe_count" = exec-changed:2 ]; then printf '/other/executable\n'; else printf '/drive/entware/sbin/syslog-ng\n'; fi >"$cfmgr_hr_result" ;;
        history-proc-meta) printf '   123 -rwx------ 1 0 0 10 fields\n' >"$cfmgr_hr_result" ;;
        history-hexdump) printf '00\n' >"$cfmgr_hr_result" ;;
        history-argv)
            [ "$TEST_PROCESS_CONDITION" != argv-unresolved ] || return 3
            printf 'PROC 42 99 executable 1 argument END\n' >"$cfmgr_hr_result" ;;
        history-frame) : >"$cfmgr_hr_result" ;;
        *) return 2 ;;
    esac
}
if cfmgr_hr_processes; then code=0; else code=$?; fi
[ "$code" = "$TEST_EXPECTED" ]
""",
        )
    )


def test_unresolved_supervision_is_never_downgraded_by_accounting(archive, shell):
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_prerequisites_run() { cfmgr_probe_status=reaped; return 3; }
cfmgr_hr_register_pair() { accounting_touched=1; return 1; }
if cfmgr_hr_run history-count 4096 "$cfmgr_store_wc" "$ram/unused"; then exit 82; else code=$?; fi
[ "$code:${accounting_touched:-0}" = 3:0 ]
""",
        )
    )


def test_admitted_scheduler_failure_cannot_become_optional_unavailability(
    archive, shell
):
    (archive[1] / "requests").write_text(
        "REQUEST ddns request eligible 1 sha policy END\n"
    )
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_history_call() { [ "$1:$2" = parse:plan ] || return 2; cfmgr_history_result=$ram/requests; }
cfmgr_history_base() { return 2; }
if _cfmgr_backup_history_observe "$ram/plan"; then exit 82; else code=$?; fi
[ "$code:$cfmgr_history_ready" = 2:0 ] || exit 83
[ "$(cat "$cfmgr_history_output")" = 'CFMGR-HISTORY 1' ] || exit 84
""",
        )
    )


@pytest.mark.skipif(sys.platform != "linux", reason="Actual proc stat requires Linux")
def test_process_stat_preserves_caller_glob_setting(archive, shell):
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
for wanted in enabled disabled; do
    case $wanted in enabled) set +f ;; disabled) set -f ;; esac
    cfmgr_hr_stat $$ || exit 82
    case $wanted:$- in enabled:*f* | disabled:*f*)
        [ "$wanted" = disabled ] || exit 83 ;;
    *) [ "$wanted" = enabled ] || exit 84 ;;
    esac
done
""",
        )
    )


def test_writer_identity_parses_padded_native_inode_metadata(archive, shell):
    library = archive[0] / "modules/backup.sh"
    boot = archive[1] / "boot"
    boot.write_text("fixture-boot\n")
    library.write_text(
        library.read_text().replace("/proc/sys/kernel/random/boot_id", '"$ram/boot"')
    )
    passed(
        run(
            archive,
            shell,
            HISTORY
            + r"""
cfmgr_hr_root=/drive/entware cfmgr_hr_writer_pid=42 cfmgr_hr_writer_start=99
cfmgr_hr_writer_inode=123 cfmgr_hr_writer_expected_sha=expected cfmgr_hr_writer_boot=fixture-boot
cfmgr_hr_stat() { cfmgr_hr_stat_comm=cloudflared cfmgr_hr_stat_start=99; }
cfmgr_hr_run() {
    cfmgr_hr_result=$ram/writer-result
    cfmgr_probe_status=reaped cfmgr_probe_exit=0
    case $1 in
    history-realpath) printf '/drive/entware/bin/cloudflared\n' >"$cfmgr_hr_result" ;;
    history-proc-meta) printf '   123 -rwx------ 1 0 0 10 fields\n' >"$cfmgr_hr_result" ;;
    *) return 2 ;;
    esac
}
cfmgr_hr_writer_digest() { cfmgr_hr_writer_sha=expected; }
cfmgr_hr_writer_identity
""",
        )
    )
