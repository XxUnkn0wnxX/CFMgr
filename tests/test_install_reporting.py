"""Fresh native wrapper loss reports; host adapters do not qualify Merlin roots."""

from __future__ import annotations

import os
import shlex
import subprocess
import sys
from pathlib import Path

import pytest
from test_install import BOOTSTRAP, HOST_TRANSACTION, ROOT, install
from test_install import legacy_fsync as install_fsync
from test_install import package as install_package
from test_install import shell as install_shell
from test_install import tools as install_tools
from test_prerequisites import pause_definition

ERROR = b"[CFMGR] Manager: Error: Entware storage lost; installation stopped\n"
shell = install_shell
tools = install_tools
legacy_fsync = install_fsync
package = install_package

WRAPPER = r"""
. "$1"
cfmgr_test_fault=$2 cfmgr_install_context=$3
cfmgr_test_detached=0
cfmgr_bootstrap_native_prepare() { cfmgr_install_interrupted=0; }
cfmgr_storage_pin() { [ "$cfmgr_test_fault" != initial ]; }
cfmgr_storage_attached() { printf 'storage-check\n'; [ "$cfmgr_test_detached" = 0 ]; }
cfmgr_bootstrap_cleanup() { printf 'cleanup\n'; }
cfmgr_bootstrap_native_work() {
    cfmgr_test_detached=1
    printf 'CFMGR-SETUP 1 0.1.0 installing\n' > "$cfmgr_install_context/guard"
    case $cfmgr_test_fault in
    healthy) cfmgr_test_detached=0 ;;
    success) return 0 ;;
    repair-loss) cfmgr_dependencies_loss=1 ;;
    code3 | retained | native-unresolved | nonreaped)
        cfmgr_probe_pid=123 cfmgr_probe_start=456 cfmgr_probe_mode=install-copy
        cfmgr_probe_status=unresolved
        case $cfmgr_test_fault in
        code3) return 3 ;;
        retained) cfmgr_dependencies_state=retained; cfmgr_probe_status=reaped ;;
        native-unresolved) cfmgr_dependencies_native_unresolved=1; cfmgr_probe_status=reaped ;;
        esac
        ;;
    esac
    return 1
}
cfmgr_bootstrap_report_action() {
    printf 'report %s %s\n' "$1" "$2"
    case $cfmgr_test_fault in
    logger-failed) return 1 ;;
    logger-unresolved)
        cfmgr_probe_pid=789 cfmgr_probe_start=987 cfmgr_probe_mode=install-report cfmgr_probe_status=unresolved
        return 3 ;;
    esac
}
cfmgr_bootstrap_logger_admit() { [ "$cfmgr_test_fault" != logger-missing ]; }
cfmgr_bootstrap_native fixture
"""


def invoke(
    shell: list[str], script: str, tmp_path: Path, fault: str = "loss"
) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [*shell, "-c", script, "install-report-test", BOOTSTRAP, fault, tmp_path],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=5,
    )


def test_fresh_native_wrapper_reports_lost_storage_and_preserves_guard(
    shell: list[str], tmp_path: Path
) -> None:
    result = invoke(shell, WRAPPER, tmp_path)
    assert result.returncode == 1
    assert result.stderr == ERROR
    assert (
        result.stdout == b"storage-check\nreport install-report storage-lost\ncleanup\n"
    )
    assert (tmp_path / "guard").read_bytes().endswith(b" installing\n")


@pytest.mark.parametrize("fault", ["healthy", "success", "initial", "repair-loss"])
def test_wrapper_reports_only_new_confirmed_loss(
    shell: list[str], tmp_path: Path, fault: str
) -> None:
    result = invoke(shell, WRAPPER, tmp_path, fault)
    assert result.returncode == (0 if fault == "success" else 1)
    assert result.stderr == b""
    assert b"report " not in result.stdout
    assert result.stdout.endswith(b"cleanup\n")


@pytest.mark.parametrize(
    "fault", ["code3", "retained", "native-unresolved", "nonreaped"]
)
def test_wrapper_retains_original_work_before_any_probe_or_cleanup(
    shell: list[str], tmp_path: Path, fault: str
) -> None:
    result = invoke(
        shell,
        WRAPPER
        + r"""
rc=$?
printf '%s %s %s %s\n' "$rc" "$cfmgr_probe_pid" "$cfmgr_probe_start" "$cfmgr_probe_mode"
exit "$rc"
""",
        tmp_path,
        fault,
    )
    assert result.returncode == 3
    assert result.stdout == b"3 123 456 install-copy\n"
    assert result.stderr == b""
    assert (tmp_path / "guard").exists()


@pytest.mark.parametrize(
    ("fault", "status", "warning"),
    [
        ("logger-missing", 1, b"native system log unavailable"),
        ("logger-failed", 1, b"native system log delivery unconfirmed"),
        ("logger-unresolved", 3, b"native system log delivery unconfirmed"),
    ],
)
def test_wrapper_log_failure_is_honest_and_unresolved_logger_retains_context(
    shell: list[str], tmp_path: Path, fault: str, status: int, warning: bytes
) -> None:
    result = invoke(
        shell,
        WRAPPER
        + r"""
rc=$?
[ "$rc" != 3 ] || printf '%s %s %s\n' "$cfmgr_probe_pid" "$cfmgr_probe_start" "$cfmgr_probe_mode"
exit "$rc"
""",
        tmp_path,
        fault,
    )
    assert result.returncode == status
    assert result.stderr == ERROR + b"[CFMGR] Manager: Warning: " + warning + b"\n"
    assert (b"cleanup\n" in result.stdout) == (status != 3)
    assert (tmp_path / "guard").exists()
    if status == 3:
        assert result.stdout.endswith(b"789 987 install-report\n")


# Reuse the actual transaction, tools and fault injection from fresh-install
# tests. Only native root/storage/supervision admission is adapted for the host.
TRANSACTION_WRAPPER = HOST_TRANSACTION.replace(
    'cfmgr_test_install "$@"',
    r"""
cfmgr_test_source=$1 cfmgr_test_jffs=$2 cfmgr_test_opt=$3 cfmgr_test_context=$4
cfmgr_test_owner=$5 cfmgr_test_sh=$6 cfmgr_test_env=$7 cfmgr_test_awk=$8 cfmgr_test_readlink=$9
shift 9
cfmgr_test_sleep=$1 cfmgr_test_wc=$2 cfmgr_test_ls=$3 cfmgr_test_fsync=$4
cfmgr_test_mkdir=$5 cfmgr_test_cp=$6 cfmgr_test_chmod=$7 cfmgr_test_mv=$8 cfmgr_test_sha=$9
shift 9
cfmgr_test_jq=$1 cfmgr_test_uuid=$2 cfmgr_test_fs=$3 cfmgr_test_fsroot=$4 cfmgr_test_relative=$5 cfmgr_test_df=$6
cfmgr_bootstrap_native_prepare() {
    cfmgr_install_context=$cfmgr_test_context cfmgr_install_interrupted=0
}
cfmgr_storage_pin() { return 0; }
cfmgr_storage_attached() { [ "$cfmgr_test_detached" = 0 ]; }
cfmgr_bootstrap_native_work() {
    # This is the no-op/completed-repair route into publication: no active
    # dependency claim or previous loss report can mask the new storage loss.
    cfmgr_dependencies_state=complete cfmgr_dependencies_loss=0
    cfmgr_test_install "$cfmgr_test_source" "$cfmgr_test_jffs" "$cfmgr_test_opt" "$cfmgr_test_context" \
        "$cfmgr_test_owner" "$cfmgr_test_sh" "$cfmgr_test_env" "$cfmgr_test_awk" "$cfmgr_test_readlink" \
        "$cfmgr_test_sleep" "$cfmgr_test_wc" "$cfmgr_test_ls" "$cfmgr_test_fsync" \
        "$cfmgr_test_mkdir" "$cfmgr_test_cp" "$cfmgr_test_chmod" "$cfmgr_test_mv" "$cfmgr_test_sha" \
        "$cfmgr_test_jq" "$cfmgr_test_uuid" "$cfmgr_test_fs" "$cfmgr_test_fsroot" "$cfmgr_test_relative" "$cfmgr_test_df"
}
cfmgr_bootstrap_logger_admit() { return 0; }
cfmgr_bootstrap_report_action() { printf 'report %s %s\n' "$1" "$2"; }
cfmgr_bootstrap_cleanup() { return 0; }
cfmgr_bootstrap_native "$cfmgr_test_source"
""",
)


def test_actual_publication_loss_reaches_native_wrapper_and_stops_writes(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
) -> None:
    result = install(
        shell,
        tools,
        legacy_fsync,
        package,
        tmp_path,
        fault="detach",
        script=TRANSACTION_WRAPPER,
    )
    assert result.returncode == 1
    assert result.stderr == ERROR
    assert result.stdout == b"report install-report storage-lost\n"
    support = tmp_path / "jffs/addons/CFMgr.d"
    assert (support / "setup-state").read_bytes().endswith(b" installing\n")
    assert not (tmp_path / "jffs/scripts/cfmgr.sh").exists()
    assert not (support / "config").exists()


def test_fixed_report_probe_rejects_unapproved_operands_and_has_error_priority(
    shell: list[str], tmp_path: Path
) -> None:
    capture = tmp_path / "logger argv"
    logger = tmp_path / "logger"
    logger.write_text(
        "#!/bin/sh\nprintf '%s\\n' \"$@\" > " + shlex.quote(str(capture)) + "\n"
    )
    logger.chmod(0o700)
    probe = ROOT / "modules/helpers/worker.sh"
    for mode, operand in [
        ("install-report", "other"),
        ("install-report-ls", "/opt/bin/logger"),
    ]:
        result = subprocess.run(
            [*shell, probe, mode, logger, tmp_path, operand],
            check=False,
            capture_output=True,
            timeout=2,
        )
        assert result.returncode == 2
        assert not capture.exists()
    result = subprocess.run(
        [*shell, probe, "install-report", logger, tmp_path, "storage-lost"],
        check=False,
        capture_output=True,
        timeout=2,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert capture.read_bytes() == b"-p\nuser.err\n-t\nCFMGR\n" + ERROR


@pytest.mark.parametrize("fault", ["clean", "failed", "interrupted"])
def test_reporter_uses_fixed_probe_without_entware_and_honors_native_admission(
    shell: list[str], tools: dict[str, str], tmp_path: Path, fault: str
) -> None:
    logger = tmp_path / "logger"
    capture = tmp_path / "logger argv"
    logger.write_text(
        "#!/bin/sh\nprintf '%s\\n' \"$@\" > "
        + shlex.quote(str(capture))
        + "\nexit "
        + ("1" if fault == "failed" else "0")
        + "\n"
    )
    logger.chmod(0o700)
    script = r"""
. "$1"
cfmgr_test_fault=$2 cfmgr_install_context=$3 cfmgr_test_logger=$4
cfmgr_install_source=$5 cfmgr_install_sh=$6 cfmgr_install_env=$7 cfmgr_install_awk=$8 cfmgr_install_sleep=$9
shift 9
cfmgr_install_wc=$1 cfmgr_test_timeout=$2
cfmgr_bootstrap_native_attached() { [ "$cfmgr_test_fault" != interrupted ]; }
cfmgr_prerequisites_attachment_ok() { printf 'unexpected Entware admission\n' >&2; return 99; }
cfmgr_bootstrap_logger_admit() { return 0; }
cfmgr_prerequisites_run() {
    [ "$1" = install-report ] && [ "$9" = /usr/bin/logger ] || return 99
    cfmgr_probe_stdout=$2/report.out cfmgr_probe_stderr=$2/report.err
    cfmgr_test_context=$2 cfmgr_test_sh=$3 cfmgr_test_probe=$4 cfmgr_test_env=$5
    shift 9
    "$cfmgr_test_timeout" --foreground --kill-after=0.1s 2s "$cfmgr_test_env" -i \
        PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
        "$cfmgr_test_sh" "$cfmgr_test_probe" install-report "$cfmgr_test_logger" "$cfmgr_test_context" "$@" \
        > "$cfmgr_probe_stdout" 2> "$cfmgr_probe_stderr"
    cfmgr_probe_exit=$? cfmgr_probe_status=reaped
    return 0
}
cfmgr_bootstrap_storage_lost
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "reporter-test",
            BOOTSTRAP,
            fault,
            tmp_path,
            logger,
            ROOT,
            tools["sh"],
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            tools["timeout"],
        ],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=4,
    )
    assert result.returncode == 1
    assert result.stdout == b""
    assert result.stderr == ERROR + (
        b""
        if fault == "clean"
        else b"[CFMGR] Manager: Warning: native system log delivery unconfirmed\n"
    )
    if fault == "interrupted":
        assert not capture.exists()
    else:
        assert capture.read_bytes() == b"-p\nuser.err\n-t\nCFMGR\n" + ERROR


@pytest.mark.parametrize("fault", ["clean", "writable", "owner", "unresolved"])
def test_logger_admission_requires_protected_root_and_preserves_unknown_probe(
    shell: list[str], tmp_path: Path, fault: str
) -> None:
    script = r"""
. "$1"
cfmgr_test_fault=$2 cfmgr_install_context=$3
cfmgr_install_readlink=cfmgr_test_readlink
cfmgr_test_readlink() { printf '%s\n' "$2"; }
cfmgr_bootstrap_native_attached() { return 0; }
cfmgr_bootstrap_report_action() {
    printf 'metadata\n'
    if [ "$cfmgr_test_fault" = unresolved ]; then
        cfmgr_probe_pid=123 cfmgr_probe_start=456 cfmgr_probe_mode=install-report-ls
        return 3
    fi
    cfmgr_test_mode=drwxr-xr-x cfmgr_test_uid=0
    [ "$cfmgr_test_fault" != writable ] || cfmgr_test_mode=drwxrwxr-x
    [ "$cfmgr_test_fault" != owner ] || cfmgr_test_uid=123
    cfmgr_probe_stdout=$cfmgr_install_context/listing
    printf '%s 1 %s 0 1 Jan 1 00:00 path\n' "$cfmgr_test_mode" "$cfmgr_test_uid" > "$cfmgr_probe_stdout"
}
cfmgr_bootstrap_logger_admit
rc=$?
[ "$rc" != 3 ] || printf '%s %s %s\n' "$cfmgr_probe_pid" "$cfmgr_probe_start" "$cfmgr_probe_mode"
exit "$rc"
"""
    result = invoke(shell, script, tmp_path, fault)
    assert result.returncode == {"clean": 0, "unresolved": 3}.get(fault, 1)
    assert result.stderr == b""
    assert result.stdout.startswith(b"metadata\n")
    if fault == "unresolved":
        assert result.stdout == b"metadata\n123 456 install-report-ls\n"


@pytest.mark.skipif(
    sys.platform != "linux", reason="Native source FD admission requires Linux proc"
)
@pytest.mark.parametrize("fault", ["missing", "substituted"])
def test_source_loss_or_substitution_cannot_launch_helper_or_mount_parser(
    shell: list[str], tmp_path: Path, fault: str
) -> None:
    for name in ("source", "jffs", "context"):
        (tmp_path / name).mkdir()
    script = r"""
. "$1"
cfmgr_test_fault=$2 cfmgr_test_root=$3
cfmgr_bootstrap_native_prepare() {
    cfmgr_install_interrupted=0 cfmgr_install_source=$cfmgr_test_root/source
    cfmgr_install_jffs=$cfmgr_test_root/jffs cfmgr_install_context=$cfmgr_test_root/context
    cfmgr_install_source_fd=9 cfmgr_install_context_fd=0
    cfmgr_install_awk=cfmgr_test_forbidden cfmgr_install_readlink=cfmgr_test_forbidden
    exec 9<"$cfmgr_install_source" 8<"$cfmgr_install_jffs" 0<"$cfmgr_install_context"
}
cfmgr_test_forbidden() { printf 'untrusted parser/helper executed\n' >&2; return 99; }
cfmgr_storage_pin() { return 0; }
cfmgr_storage_attached() { return 1; }
cfmgr_bootstrap_cleanup() { return 0; }
cfmgr_prerequisites_run() { printf 'untrusted probe executed\n' >&2; return 99; }
cfmgr_bootstrap_native_work() {
    mv "$cfmgr_install_source" "$cfmgr_install_source.old" || return 99
    [ "$cfmgr_test_fault" != substituted ] || mkdir "$cfmgr_install_source"
    return 1
}
cfmgr_bootstrap_native fixture
"""
    result = invoke(shell, script, tmp_path, fault)
    assert result.returncode == 1
    assert result.stdout == b""
    assert (
        result.stderr
        == ERROR + b"[CFMGR] Manager: Warning: native system log unavailable\n"
    )
    assert (tmp_path / "source.old").is_dir()


@pytest.mark.skipif(
    sys.platform != "linux", reason="Native ownership supervision requires Linux proc"
)
@pytest.mark.parametrize("fault", ["clean", "failed", "deadline"])
def test_linux_reporting_supervisor_uses_native_attachment_and_reaps_logger(
    shell: list[str], tools: dict[str, str], tmp_path: Path, fault: str
) -> None:
    logger = tmp_path / "logger"
    if fault == "deadline":
        logger.write_text("#!/bin/sh\nexec " + shlex.quote(tools["sleep"]) + " 10\n")
    else:
        logger.write_text(
            "#!/bin/sh\nexit " + ("1" if fault == "failed" else "0") + "\n"
        )
    logger.chmod(0o700)
    script = r"""
. "$1"
cfmgr_bootstrap_native_attached() { return 0; }
cfmgr_prerequisites_attachment_ok() { printf 'unexpected storage admission\n' >&2; return 1; }
cfmgr_prerequisites_run install-report "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" storage-lost
rc=$?
printf '%s %s %s %s\n' "$rc" "$cfmgr_probe_status" "$cfmgr_probe_exit" "$cfmgr_probe_reason"
[ "$cfmgr_probe_status" = reaped ] && [ ! -e "/proc/$cfmgr_probe_pid" ]
"""
    script = script.replace('. "$1"', '. "$1"\n' + pause_definition(shell), 1)
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "report-supervisor",
            ROOT / "modules/lib/execution.sh",
            tmp_path,
            tools["sh"],
            ROOT / "modules/helpers/worker.sh",
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            logger,
        ],
        check=False,
        capture_output=True,
        timeout=6,
    )
    assert result.returncode == 0, result.stderr
    assert result.stderr == b""
    if fault == "deadline":
        assert result.stdout.startswith(b"1 reaped ") and result.stdout.endswith(
            b" deadline\n"
        )
    else:
        assert result.stdout == (
            b"0 reaped 1 \n" if fault == "failed" else b"0 reaped 0 \n"
        )
