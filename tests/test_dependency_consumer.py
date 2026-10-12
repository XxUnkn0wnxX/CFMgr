"""Host-consumer routing tests for the native bootstrap dependency workflow."""

from __future__ import annotations

import os
import shlex
import stat
import subprocess
import sys
import time
from pathlib import Path

import pytest
from test_storage import shell as storage_shell

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / "modules/helpers/bootstrap.sh"
shell = storage_shell


@pytest.fixture(scope="module", autouse=True)
def fixed_dependency_claim_is_absent() -> None:
    # Production currently checks this fixed root path. Never touch a preexisting
    # claim created by another local process while running host-only adapters.
    claim = Path("/tmp/cfmgr/dependencies")
    if claim.exists() or claim.is_symlink():
        pytest.skip("fixed native dependency claim already exists on this host")


NATIVE_WORK = r"""
. "$1"
cfmgr_test_tmp=$2 cfmgr_test_case=$3
cfmgr_test_repair_count=0 cfmgr_test_transaction_count=0 cfmgr_test_check_count=0
cfmgr_test_post_fd0_verified=0 cfmgr_test_original_fd3_verified=0
cfmgr_test_trace=''
cfmgr_test_mark() {
    if [ -z "$cfmgr_test_trace" ]; then cfmgr_test_trace=$1
    else cfmgr_test_trace=$cfmgr_test_trace,$1; fi
}
cfmgr_test_fd_is() {
    CFMGR_TEST_EXPECTED_PATH=$1 "$CFMGR_TEST_PYTHON" -c \
        'import os; expected = os.stat(os.environ["CFMGR_TEST_EXPECTED_PATH"]); actual = os.fstat(3); raise SystemExit(0 if (expected.st_dev, expected.st_ino) == (actual.st_dev, actual.st_ino) else 1)' \
        3<&"$2" </dev/null 2>/dev/null
}

cfmgr_install_source=$cfmgr_test_tmp/source
cfmgr_install_context=$cfmgr_test_tmp/ram
cfmgr_install_private_context=$cfmgr_install_context
cfmgr_install_context_fd=0 cfmgr_install_source_fd=9
cfmgr_storage_source=/fixture/device
exec 0<"$cfmgr_install_context" 9<"$cfmgr_install_source" || exit 81

cfmgr_bootstrap_retained() { cfmgr_test_mark retained; return 0; }
cfmgr_bootstrap_native_admission() { cfmgr_test_mark admission; return 0; }
cfmgr_bootstrap_action() {
    case $1 in
        install-nvram)
            cfmgr_install_output=$cfmgr_test_tmp/nvram
            cfmgr_test_mark nvram
            ;;
        install-mkdir-private)
            [ "$#" -eq 2 ] || return 82
            mkdir "$2" || return 83
            cfmgr_test_post_path=$2
            cfmgr_test_mark mkdir-post
            ;;
        *) return 84 ;;
    esac
}
cfmgr_prerequisites_run() {
    [ "$1" = blkid ] || return 85
    cfmgr_probe_stdout=$cfmgr_test_tmp/blkid.out
    cfmgr_probe_stderr=$cfmgr_test_tmp/blkid.err
    cfmgr_probe_exit=0
    cfmgr_test_mark blkid
    return 0
}
cfmgr_storage_uuid() {
    cfmgr_storage_uuid_value=fixture-uuid
    cfmgr_storage_filesystem=ext4 cfmgr_storage_fsroot=/ cfmgr_storage_relative=opt
    cfmgr_test_mark uuid
}
cfmgr_bootstrap_metadata() { return 0; }
cfmgr_prerequisites_check() {
    [ "$1" = shared ] || return 86
    cfmgr_test_check_count=$((cfmgr_test_check_count + 1))
    if [ "$cfmgr_install_context" = "$cfmgr_test_post_path" ]; then
        cfmgr_test_mark post-check
        cfmgr_test_fd_is "$cfmgr_install_context" 0 || return 87
        cfmgr_test_fd_is "$cfmgr_install_original_context" 3 || return 88
        cfmgr_test_post_fd0_verified=1 cfmgr_test_original_fd3_verified=1
        cfmgr_test_fd_is "$cfmgr_install_source" 9 || return 89
        # The post inventory may use these descriptors, but FD3 must continue
        # to name the original RAM context across both temporary opens.
        exec 4<"$cfmgr_install_source" 5<"$cfmgr_install_original_context" || return 90
        cfmgr_test_fd_is "$cfmgr_install_source" 4 || return 91
        cfmgr_test_fd_is "$cfmgr_install_original_context" 5 || return 92
        exec 4<&- 5<&- || return 93
        cfmgr_test_fd_is "$cfmgr_install_original_context" 3 || return 94
        cfmgr_test_mark post-pins-ok
        cfmgr_prereq_missing=''
        return "${CFMGR_TEST_POST_CODE:-0}"
    fi
    cfmgr_test_mark inventory
    cfmgr_prereq_result=capabilities-checked
    case $cfmgr_test_case in
        healthy) cfmgr_prereq_missing=''; return 0 ;;
        fatal) cfmgr_prereq_missing='jq'; return 2 ;;
        *) cfmgr_prereq_missing='jq coreutils-timeout'; return 1 ;;
    esac
}
cfmgr_dependencies_repair() {
    cfmgr_test_repair_count=$((cfmgr_test_repair_count + 1))
    [ "$1" = 'jq coreutils-timeout' ] && [ "$2" = /tmp/cfmgr ] || return 95
    [ "$cfmgr_install_source_fd" = 0 ] && [ "$cfmgr_install_context_fd" = 9 ] || return 96
    cfmgr_test_fd_is "$cfmgr_install_source" 0 || return 97
    cfmgr_test_fd_is "$cfmgr_install_context" 9 || return 98
    cfmgr_test_mark "repair-$cfmgr_test_repair_count"
    if [ "$cfmgr_test_case" = retry ] && [ "$cfmgr_test_repair_count" -gt 1 ]; then
        return 0
    fi
    return "${CFMGR_TEST_REPAIR_CODE:-0}"
}

# Native cleanup checks /proc/self/fd in production. The host adapter retains
# the same directory identity and descriptor-close behavior through /dev/fd.
cfmgr_bootstrap_cleanup() {
    [ "$cfmgr_install_context_fd" = 3 ] || return 99
    cfmgr_test_fd_is "$cfmgr_install_context" 3 || return 100
    cfmgr_test_fd_is "$cfmgr_test_post_path" 0 || return 101
    rmdir "$cfmgr_install_context" || return 102
    exec 3<&- || return 103
    cfmgr_test_fd_is "$cfmgr_test_post_path" 0 || return 104
    cfmgr_test_mark cleanup-post-fd0-ok
}
cfmgr_bootstrap_flush() {
    cfmgr_test_mark flush
    return 0
}
cfmgr_bootstrap_transaction() {
    [ "$#" -eq 24 ] || return 105
    [ "$cfmgr_install_context_fd" = 5 ] || return 106
    cfmgr_test_fd_is "$cfmgr_install_context" 5 || return 107
    cfmgr_test_fd_is "$cfmgr_install_source" 9 || return 108
    cfmgr_test_transaction_count=$((cfmgr_test_transaction_count + 1))
    cfmgr_test_mark transaction
    return 0
}

run_work() {
    cfmgr_bootstrap_native_work
    cfmgr_test_result=$?
    if [ "$cfmgr_test_case" = missing ] && [ "${CFMGR_TEST_REPAIR_CODE:-0}" = 3 ]; then
        if cfmgr_test_fd_is "$cfmgr_install_source" 0 &&
            cfmgr_test_fd_is "$cfmgr_install_context" 9; then
            cfmgr_test_unresolved_repair_fds_verified=1
        fi
    fi
    if [ "${CFMGR_TEST_POST_CODE:-0}" = 3 ] &&
        cfmgr_test_fd_is "$cfmgr_install_context" 0 &&
        cfmgr_test_fd_is "$cfmgr_install_original_context" 3; then
        cfmgr_test_unresolved_post_fds_verified=1
    fi
    printf 'result=%s\n' "$cfmgr_test_result"
    printf 'trace=%s\n' "$cfmgr_test_trace"
    printf 'transactions=%s\n' "$cfmgr_test_transaction_count"
    printf 'source-fd=%s context-fd=%s\n' \
        "${cfmgr_install_source_fd:-unset}" "${cfmgr_install_context_fd:-unset}"
    printf 'context-path=%s\n' "$cfmgr_install_context"
    printf 'original-exists=%s post-exists=%s\n' \
    "$([ -d "$cfmgr_test_tmp/ram" ] && echo yes || echo no)" \
    "$([ -d "$cfmgr_test_post_path" ] && echo yes || echo no)"
}

if [ "$cfmgr_test_case" = retry ]; then
    run_work
    cfmgr_test_first_result=$cfmgr_test_result
    exec 0<&- 0<"$cfmgr_test_tmp/ram-second" || exit 109
    cfmgr_install_context=$cfmgr_test_tmp/ram-second
    cfmgr_install_private_context=$cfmgr_install_context
    cfmgr_install_context_fd=0 cfmgr_test_check_count=0
    run_work
    printf 'first-result=%s\n' "$cfmgr_test_first_result"
else
    run_work
fi
printf 'post-fd0-verified=%s\n' "$cfmgr_test_post_fd0_verified"
printf 'original-fd3-verified=%s\n' "$cfmgr_test_original_fd3_verified"
printf 'unresolved-repair-fds-verified=%s\n' "${cfmgr_test_unresolved_repair_fds_verified:-0}"
printf 'unresolved-post-fds-verified=%s\n' "${cfmgr_test_unresolved_post_fds_verified:-0}"
exit 0
"""


def prepare_context(tmp_path: Path, *, second: bool = False) -> None:
    (tmp_path / "source").mkdir()
    (tmp_path / "source" / "marker").write_text("source\n")
    (tmp_path / "ram").mkdir(mode=0o700)
    (tmp_path / "nvram").write_text("1\n")
    (tmp_path / "blkid.out").write_text("fixture-uuid\n")
    (tmp_path / "blkid.err").write_bytes(b"")
    if second:
        (tmp_path / "ram-second").mkdir(mode=0o700)


def run_native_work(
    shell: list[str],
    tmp_path: Path,
    case: str,
    *,
    repair_code: int = 0,
    post_code: int = 0,
    second: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    prepare_context(tmp_path, second=second)
    return subprocess.run(
        [
            *shell,
            "-c",
            NATIVE_WORK,
            "native-dependency-consumer",
            str(BOOTSTRAP),
            str(tmp_path),
            case,
        ],
        env={
            **os.environ,
            "LC_ALL": "C",
            "LANGUAGE": "",
            "CFMGR_TEST_REPAIR_CODE": str(repair_code),
            "CFMGR_TEST_POST_CODE": str(post_code),
            "CFMGR_TEST_PYTHON": sys.executable,
        },
        check=False,
        capture_output=True,
        timeout=5,
    )


def report(result: subprocess.CompletedProcess[bytes]) -> dict[str, str]:
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    return dict(line.decode().split("=", 1) for line in result.stdout.splitlines())


def test_native_work_healthy_inventory_runs_transaction_without_repair(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(run_native_work(shell, tmp_path, "healthy"))
    assert result["result"] == "0"
    assert result["transactions"] == "1"
    assert (
        result["trace"]
        == "retained,admission,nvram,blkid,uuid,inventory,flush,transaction"
    )
    assert result["source-fd"] == "9 context-fd=5"
    assert result["post-fd0-verified"] == "0"


def test_bootstrap_source_only_defines_helpers(
    shell: list[str], tmp_path: Path
) -> None:
    marker = tmp_path / "source-marker"
    result = subprocess.run(
        [
            *shell,
            "-c",
            (
                'before=$PWD; old_path=$PATH; sentinel=preserved; . "$1"; '
                '[ "$PWD" = "$before" ] && [ "$PATH" = "$old_path" ] && '
                '[ "$sentinel" = preserved ] && '
                "type cfmgr_bootstrap_native_work >/dev/null 2>&1 && "
                '[ ! -e "$2" ]'
            ),
            "bootstrap-source-inert",
            str(BOOTSTRAP),
            str(marker),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr.decode(errors="replace")


LINUX_CLEANUP = r"""
. "$1"
cfmgr_test_context=$2 cfmgr_test_state=$3
cfmgr_install_context=$cfmgr_test_context
cfmgr_install_private_context=$cfmgr_test_context
cfmgr_install_context_fd=9 cfmgr_install_interrupted=0
cfmgr_probe_pid=12345 cfmgr_probe_status=reaped
cfmgr_dependencies_state=$cfmgr_test_state
cfmgr_dependencies_native_unresolved=0
exec 9<"$cfmgr_test_context" || exit 81
[ "$cfmgr_install_context" -ef /proc/self/fd/9 ] || exit 82
if cfmgr_bootstrap_cleanup; then cfmgr_test_cleanup_result=0
else cfmgr_test_cleanup_result=$?; fi
if [ -d "$cfmgr_test_context" ]; then cfmgr_test_context_exists=yes
else cfmgr_test_context_exists=no; fi
if [ -f "$cfmgr_test_context/helper" ]; then cfmgr_test_helper_exists=yes
else cfmgr_test_helper_exists=no; fi
if [ -e /proc/self/fd/9 ]; then cfmgr_test_fd9_exists=yes
else cfmgr_test_fd9_exists=no; fi
printf 'cleanup=%s\n' "$cfmgr_test_cleanup_result"
printf 'context=%s\n' "$cfmgr_test_context_exists"
printf 'helper=%s\n' "$cfmgr_test_helper_exists"
printf 'fd9=%s\n' "$cfmgr_test_fd9_exists"
exit 0
"""


DEPENDENCY_BATCH_CLEANUP = r"""
. "$CFMGR_TEST_ROOT/modules/helpers/bootstrap.sh"
cfmgr_dependencies_context=$1 cfmgr_install_context=$2 cfmgr_test_log=$3
cfmgr_dependencies_phase=cleanup cfmgr_view_state=released cfmgr_keeper_state=released cfmgr_tasks_state=quiescent
cfmgr_dependencies_state=retained cfmgr_install_private_context=$cfmgr_dependencies_context
cfmgr_dependencies_cleanup_count=0 cfmgr_test_batches=0 cfmgr_test_max_batch=0 cfmgr_test_rmdirs=0
cfmgr_test_fail_batch=$4 cfmgr_test_symlink=$5
cfmgr_dependencies_attachment_ok() { return 0; }
cfmgr_dependencies_native() {
    cfmgr_test_operation=$1
    shift
    case $cfmgr_test_operation in
        inventory) : >"$2" ;;
        remove)
            [ "$#" -ge 1 ] && [ "$#" -le 8 ] || return 91
            cfmgr_test_batches=$((cfmgr_test_batches + 1))
            [ "$#" -le "$cfmgr_test_max_batch" ] || cfmgr_test_max_batch=$#
            printf 'batch=%s count=%s\n' "$cfmgr_test_batches" "$#" >>"$cfmgr_test_log"
            for cfmgr_test_path do
                case $cfmgr_test_path in "$cfmgr_dependencies_context"/*) ;; *) return 93 ;; esac
                if [ "$cfmgr_test_path" = "$cfmgr_dependencies_context/owner" ]; then
                    for cfmgr_test_left in "$cfmgr_dependencies_context"/* \
                        "$cfmgr_dependencies_context"/.[!.]* "$cfmgr_dependencies_context"/..?*; do
                        [ -e "$cfmgr_test_left" ] || [ -L "$cfmgr_test_left" ] || continue
                        [ "$cfmgr_test_left" = "$cfmgr_dependencies_context/owner" ] || return 94
                    done
                    echo owner-last >>"$cfmgr_test_log"
                fi
            done
            if [ "$cfmgr_test_fail_batch" -eq "$cfmgr_test_batches" ]; then
                "$CFMGR_TEST_PROBE_RUNNER" repair-remove /bin/rm \
                    "$cfmgr_dependencies_context" "$1" || return 95
                echo partial-failure >>"$cfmgr_test_log"
                return 92
            fi
            "$CFMGR_TEST_PROBE_RUNNER" repair-remove /bin/rm \
                "$cfmgr_dependencies_context" "$@" || return 95
            ;;
        rmdir)
            [ "$#" -eq 1 ] || return 96
            cfmgr_test_rmdirs=$((cfmgr_test_rmdirs + 1))
            /bin/rmdir "$1"
            ;;
        retire)
            [ "$#" -eq 1 ] && [ "$1" = "$cfmgr_dependencies_context" ] || return 98
            cfmgr_test_rmdirs=$((cfmgr_test_rmdirs + 1))
            echo retire-root >>"$cfmgr_test_log"
            /bin/rmdir "$1"
            ;;
        *) return 97 ;;
    esac
}
if cfmgr_dependencies_cleanup; then cfmgr_test_result=0
else cfmgr_test_result=$?; fi
if [ -d "$cfmgr_dependencies_context" ]; then cfmgr_test_context=present
else cfmgr_test_context=absent; fi
if [ -e "$cfmgr_dependencies_context/owner" ]; then cfmgr_test_owner=present
else cfmgr_test_owner=absent; fi
if [ -L "$cfmgr_test_symlink" ]; then cfmgr_test_symlink=present
else cfmgr_test_symlink=absent; fi
printf 'result=%s\ncontext=%s\nowner=%s\nsymlink=%s\n' \
    "$cfmgr_test_result" "$cfmgr_test_context" "$cfmgr_test_owner" "$cfmgr_test_symlink"
printf 'batches=%s\nmax-batch=%s\nrmdirs=%s\n' \
    "$cfmgr_test_batches" "$cfmgr_test_max_batch" "$cfmgr_test_rmdirs"
exit 0
"""


LINUX_REPAIR_CONTROLLER = r"""
. "$CFMGR_TEST_ROOT/modules/lib/execution_tasks.sh"
. "$CFMGR_TEST_ROOT/modules/lib/prerequisites.sh"
. "$CFMGR_TEST_ROOT/modules/lib/dependencies.sh"
. "$CFMGR_TEST_ROOT/modules/helpers/bootstrap.sh"
cfmgr_test_parent=$1 cfmgr_test_source=$2 cfmgr_test_marker=$3 cfmgr_test_role=$4
cfmgr_install_source=$cfmgr_test_source
cfmgr_install_context=$cfmgr_test_parent/ram-$cfmgr_test_role
cfmgr_install_private_context=$cfmgr_install_context
mkdir -m 700 "$cfmgr_install_context" || exit 81
exec 0<"$cfmgr_install_source" 9<"$cfmgr_install_context" || exit 82
cfmgr_install_source_fd=0 cfmgr_install_context_fd=9 cfmgr_install_interrupted=0
cfmgr_install_awk=/usr/bin/awk cfmgr_install_ls=/bin/ls
cfmgr_install_readlink=/usr/bin/readlink cfmgr_install_wc=/usr/bin/wc
cfmgr_install_mkdir=/bin/mkdir cfmgr_install_cp=/bin/cp cfmgr_install_chmod=/bin/chmod
cfmgr_dependencies_usleep=$CFMGR_TEST_USLEEP
cfmgr_dependencies_wc=/usr/bin/wc
cfmgr_dependencies_state=complete
case $CFMGR_TEST_UID in '' | *[!0-9]*) exit 83 ;; esac
cfmgr_test_uid=$CFMGR_TEST_UID
cfmgr_dependencies_admit() { return 0; }
cfmgr_dependencies_claim_admit() {
    [ -d "$1" ] && [ ! -L "$1" ] || return 2
    [ "$(/usr/bin/stat -c '%a:%u' "$1")" = "700:$cfmgr_test_uid" ] || return 2
    if [ -e "$1/owner" ] || [ -L "$1/owner" ]; then
        [ -f "$1/owner" ] && [ ! -L "$1/owner" ] || return 2
        [ "$(/usr/bin/stat -c '%a:%u' "$1/owner")" = "600:$cfmgr_test_uid" ] || return 2
    fi
}
cfmgr_dependencies_attachment_ok() {
    [ "$cfmgr_dependencies_context" -ef /proc/self/fd/5 ] &&
        [ "$cfmgr_install_context" -ef /proc/self/fd/9 ] &&
        [ "$cfmgr_install_source" -ef /proc/self/fd/0 ]
}
cfmgr_dependencies_native() {
    cfmgr_test_native_mode=$1
    shift
    case $cfmgr_test_native_mode in
        copy) /bin/cp "$1" "$2" ;;
        chmod) /bin/chmod "$2" "$1" ;;
        mkdir) /bin/mkdir -m "$2" "$1" ;;
        inventory) : >"$2" ;;
        remove) /bin/rm -f "$@" ;;
        rmdir | retire) /bin/rmdir "$1" ;;
        *) return 2 ;;
    esac
}
cfmgr_dependencies_inside_tools() {
    cfmgr_dependencies_inside_shell=/bin/sh cfmgr_dependencies_inside_awk=/usr/bin/awk
    cfmgr_dependencies_inside_readlink=/usr/bin/readlink cfmgr_dependencies_inside_usleep=$CFMGR_TEST_USLEEP
}
cfmgr_execution_view_create() { cfmgr_view_state=active cfmgr_keeper_state=quiescent; return 0; }
cfmgr_execution_view_release() { cfmgr_view_state=released cfmgr_keeper_state=released; return 0; }
cfmgr_execution_tasks_start() {
    {
        printf 'ready END\n'
        for cfmgr_test_package in jq jq-full coreutils-timeout coreutils-sha256sum flock bind-dig; do
            printf 'status %s BEGIN\n' "$cfmgr_test_package"
            printf 'Package: %s\n' "$cfmgr_test_package"
            printf 'Status: unknown ok not-installed\n'
            printf 'Version: fixture-1\n'
            printf 'status %s 0 END\n' "$cfmgr_test_package"
        done
        printf 'queried 0 END\n'
    } >"$cfmgr_dependencies_context/receipt" || return 3
    cfmgr_tasks_state=running
    return 0
}
cfmgr_execution_tasks_run() {
    [ "$1" = i-jq ] || return 2
    /bin/mkdir "$cfmgr_test_marker/repair-once" || return 3
    echo "$$" >"$cfmgr_test_marker/repair-owner" || return 3
    cfmgr_test_wait_count=0
    while [ ! -e "$cfmgr_test_marker/release" ]; do
        cfmgr_test_wait_count=$((cfmgr_test_wait_count + 1))
        [ "$cfmgr_test_wait_count" -le 500 ] || return 1
        /bin/sleep 0.02
    done
    return 0
}
cfmgr_execution_tasks_finish() { cfmgr_tasks_state=quiescent; return 0; }
cfmgr_prerequisites_check() {
    [ "$1" = shared ] || return 2
    : >"$cfmgr_test_marker/postprobe"
    return 0
}
if [ "$cfmgr_test_role" = waiter ]; then : >"$cfmgr_test_marker/waiter-started"; fi
if cfmgr_dependencies_repair jq "$cfmgr_test_parent" "$cfmgr_test_source" / /bin/sh /usr/bin/env \
    /usr/bin/awk /usr/bin/readlink "$CFMGR_TEST_USLEEP" /usr/bin/wc /bin/mknod /usr/sbin/chroot; then
    cfmgr_test_result=0
else cfmgr_test_result=$?; fi
cfmgr_test_postprobe=none
if [ "$cfmgr_test_role" = waiter ] && [ "$cfmgr_test_result" = 0 ] &&
    [ "$cfmgr_dependencies_result" = coalesced ]; then
    if cfmgr_prerequisites_check shared "$cfmgr_install_context"; then cfmgr_test_postprobe=passed; fi
fi
echo "result=$cfmgr_test_result"
echo "controller-result=${cfmgr_dependencies_result:-unset}"
echo "postprobe=$cfmgr_test_postprobe"
exit 0
"""


LINUX_WAIT_STALE = r"""
. "$CFMGR_TEST_ROOT/modules/lib/execution_tasks.sh"
. "$CFMGR_TEST_ROOT/modules/lib/prerequisites.sh"
. "$CFMGR_TEST_ROOT/modules/lib/dependencies.sh"
. "$CFMGR_TEST_ROOT/modules/helpers/bootstrap.sh"
cfmgr_dependencies_context=$1 cfmgr_dependencies_usleep=/bin/sleep
cfmgr_dependencies_wc=/usr/bin/wc
case $CFMGR_TEST_UID in '' | *[!0-9]*) exit 81 ;; esac
cfmgr_test_uid=$CFMGR_TEST_UID
cfmgr_dependencies_claim_admit() {
    [ -d "$1" ] && [ ! -L "$1" ] || return 2
    [ "$(/usr/bin/stat -c '%a:%u' "$1")" = "700:$cfmgr_test_uid" ] || return 2
    [ -f "$1/owner" ] && [ ! -L "$1/owner" ] &&
        [ "$(/usr/bin/stat -c '%a:%u' "$1/owner")" = "600:$cfmgr_test_uid" ]
}
if _cfmgr_dependencies_wait; then cfmgr_test_result=0
else cfmgr_test_result=$?; fi
echo "result=$cfmgr_test_result"
echo "result-kind=${cfmgr_dependencies_result:-unset}"
if [ -d "$cfmgr_dependencies_context" ]; then echo claim=present
else echo claim=absent; fi
echo "owner-bytes=$(/usr/bin/wc -c <"$cfmgr_dependencies_context/owner")"
exit 0
"""


PORTABLE_WAIT_DISAPPEARANCE = r"""
. "$CFMGR_TEST_ROOT/modules/lib/dependencies.sh"
cfmgr_dependencies_context=$1 cfmgr_dependencies_usleep=cfmgr_test_usleep cfmgr_dependencies_wc=$2
cfmgr_test_mode=$3
cfmgr_test_now=100
_cfmgr_tasks_now() { cfmgr_tasks_now=$cfmgr_test_now; cfmgr_test_now=$((cfmgr_test_now + 1)); }
cfmgr_test_usleep() { return 97; }
cfmgr_dependencies_claim_admit() {
    [ -d "$1" ] || return 2
    if [ "$cfmgr_test_mode" = claim-admit ]; then
        rm -f "$1/owner" || return 3
        rmdir "$1" || return 3
        return 2
    fi
    return 0
}
if _cfmgr_dependencies_wait; then cfmgr_test_result=0
else cfmgr_test_result=$?; fi
printf 'result=%s\n' "$cfmgr_test_result"
printf 'controller-result=%s\n' "${cfmgr_dependencies_result:-unset}"
if [ -e "$cfmgr_dependencies_context" ] || [ -L "$cfmgr_dependencies_context" ]; then
    echo claim=present
else
    echo claim=absent
fi
exit 0
"""


@pytest.mark.parametrize(
    (
        "state",
        "expected_cleanup",
        "expected_context",
        "expected_helper",
        "expected_fd9",
    ),
    [
        ("retained", "3", "yes", "yes", "yes"),
        ("resolved", "0", "no", "no", "no"),
        ("none", "0", "no", "no", "no"),
    ],
)
def test_linux_cleanup_retains_unresolved_repair_context_only(
    shell: list[str],
    tmp_path: Path,
    state: str,
    expected_cleanup: str,
    expected_context: str,
    expected_helper: str,
    expected_fd9: str,
) -> None:
    if sys.platform != "linux" or not Path("/proc/self/fd").is_dir():
        pytest.skip("requires Linux /proc/self/fd descriptor semantics")

    context = tmp_path / "private-context"
    context.mkdir(mode=0o700)
    (context / "helper").write_text("owned recovery helper\n")
    result = subprocess.run(
        [
            *shell,
            "-c",
            LINUX_CLEANUP,
            "bootstrap-cleanup-retention",
            str(BOOTSTRAP),
            str(context),
            state,
        ],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=5,
    )
    observed = report(result)
    assert observed == {
        "cleanup": expected_cleanup,
        "context": expected_context,
        "helper": expected_helper,
        "fd9": expected_fd9,
    }


@pytest.mark.parametrize("case", ["complete", "batch-failure", "symlink"])
def test_dependency_cleanup_batches_only_prechecked_owned_tree(
    shell: list[str], tmp_path: Path, case: str
) -> None:
    context = tmp_path / "private dependency claim"
    context.mkdir(mode=0o700)
    (context / "owner").write_text("fixture owner\n")
    (context / "owner").chmod(0o600)
    for index in range(24):
        (context / f"item {index:02d}").write_text(f"data {index}\n")
    nested = context / "nested" / "inner"
    nested.mkdir(parents=True)
    for index in range(6):
        (nested / f"nested {index:02d}").write_text(f"nested {index}\n")
    fifo_dir = context / "keeper"
    fifo_dir.mkdir()
    os.mkfifo(fifo_dir / "control")

    marker = tmp_path / "external evidence"
    marker.write_text("outside the claim\n")
    symlink = context / "untrusted-link"
    if case == "symlink":
        symlink.symlink_to(marker)

    install_context = tmp_path / "install-private"
    install_context.mkdir(mode=0o700)
    log = tmp_path / "native-operations"
    fail_batch = "2" if case == "batch-failure" else "0"
    probe_runner = tmp_path / "selected-shell-probe"
    probe_runner.write_text(
        f'#!/bin/sh\nexec {shlex.join(shell)} "$CFMGR_TEST_PROBE" "$@"\n'
    )
    probe_runner.chmod(0o700)
    result = subprocess.run(
        [
            *shell,
            "-c",
            DEPENDENCY_BATCH_CLEANUP,
            "dependency-batched-cleanup",
            str(context),
            str(install_context),
            str(log),
            fail_batch,
            str(symlink),
        ],
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_TEST_ROOT": str(ROOT),
            "CFMGR_TEST_PROBE": str(ROOT / "modules/helpers/probe.sh"),
            "CFMGR_TEST_PROBE_RUNNER": str(probe_runner),
        },
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    observed = report(result)

    if case == "complete":
        assert observed["result"] == "0"
        assert observed["context"] == observed["owner"] == "absent"
        assert 5 <= int(observed["batches"]) <= 6
        assert 2 <= int(observed["max-batch"]) <= 8
        assert int(observed["rmdirs"]) == 4
        assert log.read_text().splitlines()[-2:] == ["owner-last", "retire-root"]
        assert marker.read_text() == "outside the claim\n"
    elif case == "batch-failure":
        assert observed["result"] == "3"
        assert observed["context"] == observed["owner"] == "present"
        assert observed["batches"] == "2"
        assert observed["max-batch"] == "8"
        assert int(observed["rmdirs"]) == 0
        assert (context / "owner").read_text() == "fixture owner\n"
        assert len(list(context.glob("item *"))) < 24
        assert len(list(context.glob("item *"))) > 0
        assert log.read_text().splitlines()[-1] == "partial-failure"
    else:
        assert observed["result"] == "3"
        assert observed["context"] == observed["owner"] == "present"
        assert observed["symlink"] == "present"
        assert observed["batches"] == observed["max-batch"] == "0"
        assert not log.exists()
        assert marker.read_text() == "outside the claim\n"


def process_output_snapshot(process: subprocess.Popen[bytes], limit: int = 2048) -> str:
    sections: list[str] = []
    for label, stream in (("stdout", process.stdout), ("stderr", process.stderr)):
        if stream is None:
            continue
        descriptor = stream.fileno()
        was_blocking = os.get_blocking(descriptor)
        try:
            os.set_blocking(descriptor, False)
            content = os.read(descriptor, limit)
        except BlockingIOError:
            content = b""
        finally:
            os.set_blocking(descriptor, was_blocking)
        if content:
            sections.append(f"{label}={content.decode(errors='replace')[-limit:]}")
    return "\n".join(sections) or "no buffered output"


def wait_for_path(
    path: Path, processes: list[subprocess.Popen[bytes]], timeout: float = 4.0
) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            return
        exited = [process for process in processes if process.poll() is not None]
        if exited:
            details = "; ".join(
                f"pid={process.pid} rc={process.returncode} {process_output_snapshot(process)}"
                for process in exited
            )
            raise AssertionError(f"process exited before marker {path}: {details}")
        time.sleep(0.01)
    details = "; ".join(
        f"pid={process.pid} rc={process.poll()} {process_output_snapshot(process)}"
        for process in processes
    )
    raise AssertionError(
        f"timed out waiting for owned-process marker {path}: {details}"
    )


def linux_process_start(pid: int) -> str:
    stat_record = Path(f"/proc/{pid}/stat").read_text()
    fields_after_comm = stat_record.rsplit(") ", 1)[1].split()
    return fields_after_comm[19]


def test_linux_dependency_repair_coalesces_two_live_controller_processes(
    shell: list[str], tmp_path: Path
) -> None:
    if sys.platform != "linux" or not Path("/proc/self/fd").is_dir():
        pytest.skip("requires Linux /proc identity and descriptor semantics")

    parent = tmp_path / "claim-parent"
    parent.mkdir(mode=0o700)
    marker = tmp_path / "barriers"
    marker.mkdir(mode=0o700)
    usleep = tmp_path / "usleep"
    usleep.write_text(
        "#!/bin/sh\n"
        'if [ "$CFMGR_TEST_ROLE" = waiter ]; then : >'
        '"$CFMGR_TEST_MARKER/waiter-ready"; fi\n'
        "/bin/sleep 0.1\n"
    )
    usleep.chmod(0o700)
    env = {
        **os.environ,
        "LC_ALL": "C",
        "CFMGR_TEST_ROOT": str(ROOT),
        "CFMGR_TEST_PARENT": str(parent),
        "CFMGR_TEST_MARKER": str(marker),
        "CFMGR_TEST_USLEEP": str(usleep),
        "CFMGR_TEST_UID": str(os.getuid()),
    }

    def launch(role: str) -> subprocess.Popen[bytes]:
        process_env = {**env, "CFMGR_TEST_ROLE": role}
        return subprocess.Popen(
            [
                *shell,
                "-c",
                LINUX_REPAIR_CONTROLLER,
                "dependency-controller",
                str(parent),
                str(ROOT),
                str(marker),
                role,
            ],
            env=process_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    leader = launch("leader")
    processes = [leader]
    waiter: subprocess.Popen[bytes] | None = None
    try:
        wait_for_path(marker / "repair-owner", processes)
        owner_record = (parent / "dependencies" / "owner").read_bytes()
        owner_fields = owner_record.decode().split()
        assert len(owner_fields) == 3
        owner_pid = int(owner_fields[0])
        assert owner_pid == leader.pid
        assert (
            owner_record
            == (
                f"{owner_pid} {linux_process_start(owner_pid)} "
                f"{Path('/proc/sys/kernel/random/boot_id').read_text().strip()}\n"
            ).encode()
        )
        claim_stat = (parent / "dependencies").stat()
        owner_stat = (parent / "dependencies" / "owner").stat()
        assert stat.S_IMODE(claim_stat.st_mode) == 0o700
        assert stat.S_IMODE(owner_stat.st_mode) == 0o600

        waiter = launch("waiter")
        processes.append(waiter)
        # The helper emits this only after _wait validates the owner receipt
        # and calls its bounded sleep callback; it never reopens the claim.
        wait_for_path(marker / "waiter-ready", processes)
        assert waiter.pid != leader.pid
        (marker / "release").write_text("release\n")

        leader_stdout, leader_stderr = leader.communicate(timeout=8)
        waiter_stdout, waiter_stderr = waiter.communicate(timeout=8)
        assert leader.returncode == 0, leader_stderr.decode(errors="replace")
        assert waiter.returncode == 0, waiter_stderr.decode(errors="replace")
        leader_result = dict(
            line.split("=", 1) for line in leader_stdout.decode().splitlines()
        )
        waiter_result = dict(
            line.split("=", 1) for line in waiter_stdout.decode().splitlines()
        )
        assert leader_result == {
            "result": "0",
            "controller-result": "repaired",
            "postprobe": "none",
        }
        assert waiter_result == {
            "result": "0",
            "controller-result": "coalesced",
            "postprobe": "passed",
        }
        assert (marker / "repair-once").is_dir()
        assert (marker / "repair-owner").read_text().strip() == str(leader.pid)
        assert (marker / "postprobe").is_file()
        assert not (parent / "dependencies").exists()
    finally:
        (marker / "release").touch(exist_ok=True)
        for process in processes:
            if process.poll() is None:
                process.kill()
            try:
                process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate(timeout=2)


@pytest.mark.parametrize("claim_kind", ["malformed", "dead-owner", "old-boot"])
def test_linux_dependency_wait_preserves_untrusted_or_stale_claims(
    shell: list[str], tmp_path: Path, claim_kind: str
) -> None:
    if sys.platform != "linux" or not Path("/proc/self/fd").is_dir():
        pytest.skip("requires Linux /proc owner identity semantics")

    parent = tmp_path / "claim-parent"
    claim = parent / "dependencies"
    claim.mkdir(parents=True, mode=0o700)
    if claim_kind == "malformed":
        owner_record = b"malformed owner receipt\n"
    elif claim_kind == "dead-owner":
        pid_limit = int(Path("/proc/sys/kernel/pid_max").read_text().strip())
        owner_record = f"{pid_limit + 1} 1 {Path('/proc/sys/kernel/random/boot_id').read_text().strip()}\n".encode()
    else:
        owner_record = f"{os.getpid()} {linux_process_start(os.getpid())} 00000000-0000-0000-0000-000000000000\n".encode()
    owner_path = claim / "owner"
    owner_path.write_bytes(owner_record)
    owner_path.chmod(0o600)
    keep = claim / "keep"
    keep.write_text("must remain\n")
    keep.chmod(0o600)

    result = subprocess.run(
        [
            *shell,
            "-c",
            LINUX_WAIT_STALE,
            "dependency-stale-claim",
            str(claim),
        ],
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_TEST_ROOT": str(ROOT),
            "CFMGR_TEST_UID": str(os.getuid()),
        },
        check=False,
        capture_output=True,
        timeout=5,
    )
    observed = report(result)
    assert observed == {
        "result": "3",
        "result-kind": "unset",
        "claim": "present",
        "owner-bytes": str(len(owner_record)),
    }
    assert owner_path.read_bytes() == owner_record
    assert keep.read_text() == "must remain\n"


@pytest.mark.parametrize(
    (
        "observation",
        "owner_record",
        "expected_result",
        "expected_controller",
        "expected_claim",
    ),
    [
        ("claim-admit", b"12 34 boot\n", "0", "coalesced", "absent"),
        ("owner-wc", b"12 34 boot\n", "0", "coalesced", "absent"),
        ("malformed", b"malformed owner receipt\n", "3", "unset", "present"),
    ],
)
def test_dependency_wait_coalesces_only_after_complete_claim_disappears(
    shell: list[str],
    tmp_path: Path,
    observation: str,
    owner_record: bytes,
    expected_result: str,
    expected_controller: str,
    expected_claim: str,
) -> None:
    """Owner-observation races coalesce only when the whole claim is gone."""
    claim = tmp_path / "dependencies"
    claim.mkdir(mode=0o700)
    owner = claim / "owner"
    owner.write_bytes(owner_record)
    owner.chmod(0o600)

    wc_adapter = tmp_path / "wc-adapter"
    adapter_env = {**os.environ, "LC_ALL": "C", "CFMGR_TEST_ROOT": str(ROOT)}
    if observation == "owner-wc":
        wc_script = tmp_path / "wc-adapter-script"
        wc_script.write_text(
            '[ "$#" -eq 1 ] && [ "$1" = -c ] || exit 91\n'
            "bytes=$(wc -c) || exit 92\n"
            'rm -f "$CFMGR_TEST_CLAIM/owner" || exit 93\n'
            'rmdir "$CFMGR_TEST_CLAIM" || exit 94\n'
            "printf '%s\\n' \"$bytes\"\n"
        )
        wc_adapter.write_text(
            f'#!/bin/sh\nexec {shlex.join(shell)} "$CFMGR_TEST_WC_SCRIPT" "$@"\n'
        )
        wc_adapter.chmod(0o700)
        adapter_env["CFMGR_TEST_WC_SCRIPT"] = str(wc_script)
    else:
        wc_adapter = Path("/usr/bin/wc")

    result = subprocess.run(
        [
            *shell,
            "-c",
            PORTABLE_WAIT_DISAPPEARANCE,
            "dependency-owner-race",
            str(claim),
            str(wc_adapter),
            observation,
        ],
        env={**adapter_env, "CFMGR_TEST_CLAIM": str(claim)},
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    observed = report(result)
    assert observed == {
        "result": expected_result,
        "controller-result": expected_controller,
        "claim": expected_claim,
    }
    if expected_claim == "present":
        assert owner.read_bytes() == owner_record


def test_native_work_repairs_then_uses_fresh_post_inventory_before_transaction(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(run_native_work(shell, tmp_path, "missing"))
    assert result["result"] == "0"
    assert result["transactions"] == "1"
    assert result["trace"] == (
        "retained,admission,nvram,blkid,uuid,inventory,repair-1,mkdir-post,"
        "post-check,post-pins-ok,cleanup-post-fd0-ok,flush,transaction"
    )
    assert result["source-fd"] == "9 context-fd=5"
    assert result["original-exists"] == "no post-exists=yes"
    assert result["post-fd0-verified"] == "1"
    assert result["original-fd3-verified"] == "1"


def test_native_work_fatal_inventory_never_repairs_or_transacts(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(run_native_work(shell, tmp_path, "fatal"))
    assert result["result"] == "2"
    assert result["transactions"] == "0"
    assert result["trace"] == "retained,admission,nvram,blkid,uuid,inventory"
    assert result["context-path"] == str(tmp_path / "ram")


def test_native_work_ordinary_repair_failure_restores_mapping_and_allows_retry(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(
        run_native_work(shell, tmp_path, "retry", repair_code=1, second=True)
    )
    assert result["first-result"] == "1"
    assert result["result"] == "0"
    assert result["transactions"] == "1"
    assert "repair-1" in result["trace"] and "repair-2" in result["trace"]
    assert result["source-fd"] == "9 context-fd=5"
    assert result["original-exists"] == "yes post-exists=yes"


def test_native_work_unresolved_repair_preserves_swapped_source_and_context_fds(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(run_native_work(shell, tmp_path, "missing", repair_code=3))
    assert result["result"] == "3"
    assert result["transactions"] == "0"
    assert result["source-fd"] == "0 context-fd=9"
    assert result["context-path"] == str(tmp_path / "ram")
    assert result["post-fd0-verified"] == "0"
    assert result["unresolved-repair-fds-verified"] == "1"


def test_native_work_failed_post_probe_cleans_only_original_and_blocks_transaction(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(run_native_work(shell, tmp_path, "missing", post_code=1))
    assert result["result"] == "1"
    assert result["transactions"] == "0"
    assert "post-pins-ok,cleanup-post-fd0-ok" in result["trace"]
    assert result["original-exists"] == "no post-exists=yes"
    assert result["source-fd"] == "9 context-fd=0"


def test_native_work_unresolved_post_probe_preserves_both_context_descriptors(
    shell: list[str], tmp_path: Path
) -> None:
    result = report(run_native_work(shell, tmp_path, "missing", post_code=3))
    assert result["result"] == "3"
    assert result["transactions"] == "0"
    assert result["trace"].endswith("post-check,post-pins-ok")
    assert result["original-exists"] == "yes post-exists=yes"
    assert result["post-fd0-verified"] == "1"
    assert result["original-fd3-verified"] == "1"
    assert result["unresolved-post-fds-verified"] == "1"
