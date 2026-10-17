"""Normal installed-opkg repair in storage's isolated real-ext4 fixture.

The opkg CLI is synthetic. Selected vendor shell, mount, flock, keeper, task-root
ownership and cleanup execute for real; this is not live Entware qualification.
"""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from test_install import legacy_fsync, package, shell
from test_install import tools as install_tools
from test_storage_mounts import (
    FIXTURE,
    ROOT,
    fixture_tools,
    ledger_row,
    ledger_tools,
    run_ledger,
    selected_shell,
)

# Reuse existing immutable platform/tool admission, with fresh mutable images.
base_tools = install_tools
__all__ = [
    "base_tools",
    "fixture_tools",
    "ledger_tools",
    "legacy_fsync",
    "package",
    "selected_shell",
    "shell",
]


@pytest.fixture(scope="module")
def dependency_process(tmp_path_factory: pytest.TempPathFactory) -> Path:
    if sys.platform != "linux":
        pytest.skip("static process/thread fixture requires Linux; exact CI pending")
    compiler = shutil.which("gcc")
    assert compiler, "Declared static C process fixture compiler is missing"
    binary = tmp_path_factory.mktemp("dependency-process") / "process"
    result = subprocess.run(
        [
            compiler,
            "-static",
            "-pthread",
            "-O2",
            "-Wall",
            "-Wextra",
            "-Werror",
            str(ROOT / "tests/fixtures/dependency_process.c"),
            "-o",
            str(binary),
        ],
        capture_output=True,
        check=False,
        timeout=20,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    return binary


@pytest.fixture(scope="module")
def installer_adapter(
    tmp_path_factory: pytest.TempPathFactory,
    package: Path,
    base_tools: dict[str, str],
    legacy_fsync: Path,
) -> Path:
    private = tmp_path_factory.mktemp("dependency-installer-adapter")
    aliases = {}
    for name, relative, original, alias in (
        (
            "repair",
            "modules/lib/execution.sh",
            "cfmgr_dependencies_repair",
            "cfmgr_test_real_repair",
        ),
        (
            "probe",
            "modules/lib/execution.sh",
            "cfmgr_prerequisites_check",
            "cfmgr_test_real_shared_check",
        ),
        (
            "bootstrap",
            "modules/lib/package.sh",
            "cfmgr_bootstrap_transaction",
            "cfmgr_test_real_transaction",
        ),
    ):
        source = (ROOT / relative).read_bytes()
        definition = f"{original}() {{".encode()
        renamed_definition = f"{alias}() {{".encode()
        assert source.count(definition) == 1
        renamed = source.replace(definition, renamed_definition, 1)
        assert renamed.replace(renamed_definition, definition, 1) == source
        target = private / f"{name}.sh"
        target.write_bytes(renamed)
        aliases[f"dependency_{name}_alias"] = target
    values: dict[str, Path | str] = {
        "dependency_package": package,
        **aliases,
        "installer_fsync": legacy_fsync,
        "installer_sha": base_tools["sha256sum"],
        **{
            f"installer_{name}": base_tools[name]
            for name in (
                "jq",
                "timeout",
                "env",
                "awk",
                "readlink",
                "sleep",
                "wc",
                "ls",
                "mkdir",
                "cp",
                "chmod",
                "mv",
                "df",
            )
        },
    }
    adapter = private / "tools.sh"
    adapter.write_text(
        "".join(f"{name}={shlex.quote(str(value))}\n" for name, value in values.items())
    )
    return adapter


def test_dependency_fixture_syntax(
    selected_shell: list[str], installer_adapter: Path, tmp_path: Path
) -> None:
    # Syntax proof must collect/run before Linux/tool skips. ash -n -c executes
    # minusc on the pinned build, so inspect actual script files with -n.
    retirement_script = tmp_path / "dependency-retirement.sh"
    retirement_script.write_text(DEPENDENCY_RETIREMENT_PROBE)
    for script in (
        ROOT / "tests/fixtures/dependencies.sh",
        ROOT / "tests/fixtures/dependency_installer.sh",
        ROOT / "modules/helpers/worker.sh",
        installer_adapter,
        retirement_script,
    ):
        result = subprocess.run(
            [*selected_shell, "-n", str(script)],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def run_dependency_case(
    fixture_tools: tuple[list[str], str, str, str],
    dependency_process: Path,
    tmp_path: Path,
    case: str,
    adapter: Path | None = None,
) -> subprocess.CompletedProcess[bytes]:
    shell, readlink, awk, timeout = fixture_tools
    sudo = shutil.which("sudo")
    unshare = shutil.which("unshare")
    assert sudo and unshare, "Already admitted namespace tools disappeared"
    os.chmod(tmp_path, 0o700)
    # The product action, cancellation and normal release retain their own
    # 120/10/60-second budgets. This outer fixture guard must let them report.
    # Retry performs two complete attempts; mixed roots require explicit isolated
    # recovery after the first honest ownership refusal. No inner limit changes.
    attempts = 2 if case == "dependency_retry" else 1
    recovery = 10 + 60 if case == "dependency_mixed" else 0
    watchdog = attempts * (120 + 10 + 60) + recovery + 30
    result = subprocess.run(
        [
            sudo,
            "-n",
            unshare,
            "--mount",
            "--propagation",
            "private",
            "--pid",
            "--fork",
            "--mount-proc",
            timeout,
            "--signal=TERM",
            "--kill-after=2",
            str(watchdog),
            *shell,
            str(FIXTURE),
            str(ROOT),
            case,
            str(tmp_path),
            readlink,
            awk,
            os.readlink("/proc/self/ns/mnt"),
            str(os.getuid()),
            shell[0],
            os.readlink("/proc/self/ns/pid"),
            str(dependency_process),
            *([str(adapter)] if adapter else []),
        ],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=watchdog + 5,
    )
    cost_phases = (
        "installer-repair",
        "installer-check-1",
        "installer-check-2",
        "installer-transaction",
        "retained-repair",
        "retained-absent",
        "retained-return-dns",
        "retained-force",
    )
    timestamps: dict[str, float] = {}
    stderr_lines = []
    for line in result.stderr.splitlines(keepends=True):
        if line.startswith(b"CFMGR-TEST-COST"):
            record = re.fullmatch(
                rb"CFMGR-TEST-COST 1 ([a-z0-9-]+) ([0-9]+(?:\.[0-9]+)?)\n", line
            )
            assert record, f"malformed fixture cost record: {line!r}"
            label = record.group(1).decode("ascii")
            assert label in {
                f"{phase}-{edge}" for phase in cost_phases for edge in ("begin", "end")
            }, f"unknown fixture cost label: {label}"
            assert label not in timestamps, f"duplicate fixture cost label: {label}"
            timestamps[label] = float(record.group(2))
        else:
            stderr_lines.append(line)
    result.stderr = b"".join(stderr_lines)
    if result.returncode:
        # Private fixture evidence contains finite phase labels only. Root-owned
        # setup uses sudo; validate the known object before a bounded host read.
        stat_tool, head_tool = shutil.which("stat"), shutil.which("head")
        assert stat_tool and head_tool, "Declared host fixture diagnostics disappeared"
        diagnostic = subprocess.run(
            [
                sudo,
                "-n",
                *shell,
                "-c",
                r"""
[ -d "$1" ] && [ ! -L "$1" ] || exit 1
[ "$("$2" -c %u:%a "$1")" = 0:700 ] || exit 1
[ -f "$1/dependency.trace" ] && [ ! -L "$1/dependency.trace" ] || exit 1
[ "$("$2" -c %u:%a "$1/dependency.trace")" = 0:600 ] || exit 1
exec "$3" -c 1024 "$1/dependency.trace"
""",
                "dependency-trace",
                str(tmp_path / "cfmgr-storage-mount-fixture"),
                stat_tool,
                head_tool,
            ],
            capture_output=True,
            check=False,
            timeout=3,
        )
        if diagnostic.returncode == 0:
            assert len(diagnostic.stdout) <= 1024
            result.stderr += b"bounded synthetic fixture trace:\n" + diagnostic.stdout
        outcome = subprocess.run(
            [
                sudo,
                "-n",
                *shell,
                "-c",
                r"""
[ -d "$1" ] && [ ! -L "$1" ] || exit 1
[ "$("$2" -c %u:%a "$1")" = 0:700 ] || exit 1
for outcome in "$1/dependency.outcome.1" "$1/dependency.outcome.2"; do
    [ -e "$outcome" ] || [ -L "$outcome" ] || continue
    [ -f "$outcome" ] && [ ! -L "$outcome" ] || exit 1
    [ "$("$2" -c %u:%a "$outcome")" = 0:600 ] || exit 1
    [ "$("$2" -c %s "$outcome")" -le 2048 ] || exit 1
    printf '%s\n' "outcome: $outcome"
    "$3" -c 2048 "$outcome" || exit $?
    printf '\n'
done
""",
                "dependency-outcome",
                str(tmp_path / "cfmgr-storage-mount-fixture"),
                stat_tool,
                head_tool,
            ],
            capture_output=True,
            check=False,
            timeout=3,
        )
        if outcome.returncode == 0:
            assert len(outcome.stdout) <= 2 * 2048 + 256
            result.stderr += b"bounded synthetic fixture outcome:\n" + outcome.stdout
    else:
        expected_phases = (
            (
                "retained-repair",
                "retained-absent",
                "retained-return-dns",
                "retained-force",
            )
            if b"PASS: actual retained repair" in result.stdout
            else (
                "installer-repair",
                "installer-check-1",
                "installer-check-2",
                "installer-transaction",
            )
            if b"PASS: actual installer repair" in result.stdout
            else ()
        )
        durations = []
        for phase in cost_phases:
            begin, end = (
                timestamps.get(f"{phase}-begin"),
                timestamps.get(f"{phase}-end"),
            )
            if phase in expected_phases:
                assert begin is not None and end is not None, (
                    f"missing fixture cost pair: {phase}"
                )
            if begin is not None or end is not None:
                assert begin is not None and end is not None and end >= begin, (
                    f"invalid fixture cost pair: {phase}"
                )
                durations.append(f"{phase}={end - begin:.2f}s")
        if durations:
            sys.__stdout__.write("CFMGR fixture phases: " + ", ".join(durations) + "\n")
            sys.__stdout__.flush()
    return result


DEPENDENCY_RETIREMENT_PROBE = r"""
root=$1 workspace=$2 scenario=$3
claim=$workspace/dependencies preflight=$workspace/preflight
mkdir -m 700 "$workspace" || exit 81
mkdir -m 700 "$claim" "$preflight" || exit 81
cp "$root/modules/lib/storage.sh" "$preflight/repair-storage.sh" || exit 82
cp "$root/modules/helpers/worker.sh" "$preflight/repair-worker.sh" || exit 83
. "$root/modules/lib/package.sh"
. "$root/modules/lib/storage.sh"
cfmgr_dependencies_context=$claim
cfmgr_install_context=$preflight cfmgr_install_context_fd=9
cfmgr_dependencies_claimed=1 cfmgr_dependencies_snapshot_ready=1 cfmgr_dependencies_cleaning=1
cfmgr_dependencies_state=retained cfmgr_dependencies_phase=cleanup cfmgr_dependencies_native_unresolved=0
cfmgr_install_interrupted=0 cfmgr_install_awk=/usr/bin/awk cfmgr_install_ls=/bin/ls
cfmgr_install_tmp_snapshot=$(/usr/bin/awk "$(cfmgr_storage_awk_mountinfo; printf '%s' "$cfmgr_awk_program")" "$preflight" /proc/self/mountinfo) || exit 84
exec 5<"$claim" 9<"$preflight" || exit 85
case $scenario in
    preexisting)
        /bin/mv "$claim" "$claim.moved" && /bin/mkdir -m 700 "$claim" &&
            printf replacement >"$claim/sentinel" || exit 86
        cfmgr_dependencies_retiring=0 cfmgr_probe_mode=none cfmgr_probe_pid=
        ;;
    rename)
        /bin/mv "$claim" "$claim.moved" || exit 87
        cfmgr_dependencies_retiring=1 cfmgr_probe_mode=repair-retire cfmgr_probe_pid=12345
        ;;
    replace)
        /bin/rmdir "$claim" && /bin/mkdir -m 700 "$claim" &&
            printf replacement >"$claim/sentinel" || exit 88
        cfmgr_dependencies_retiring=1 cfmgr_probe_mode=repair-retire cfmgr_probe_pid=12345
        ;;
    exact)
        /bin/rmdir "$claim" || exit 89
        cfmgr_dependencies_retiring=1 cfmgr_probe_mode=repair-retire cfmgr_probe_pid=12345
        ;;
    *) exit 90 ;;
esac
if cfmgr_dependencies_attachment_ok; then attachment=accepted
else attachment=rejected; fi
cfmgr_dependencies_retiring=0 cfmgr_probe_mode=none cfmgr_probe_pid=
if cfmgr_dependencies_attachment_ok; then ordinary=accepted
else ordinary=rejected; fi
if [ -d "$claim" ] && [ ! -L "$claim" ]; then claim_state=present
else claim_state=absent; fi
if [ -d "$claim.moved" ] && [ ! -L "$claim.moved" ]; then moved_state=present
else moved_state=absent; fi
if [ -f "$claim/sentinel" ] && [ ! -L "$claim/sentinel" ]; then sentinel_state=present
else sentinel_state=absent; fi
printf 'attachment=%s ordinary=%s claim=%s moved=%s sentinel=%s\n' \
    "$attachment" "$ordinary" "$claim_state" "$moved_state" "$sentinel_state"
"""


@pytest.mark.parametrize(
    ("scenario", "expected"),
    [
        (
            "exact",
            "attachment=accepted ordinary=rejected claim=absent moved=absent sentinel=absent",
        ),
        (
            "rename",
            "attachment=rejected ordinary=rejected claim=absent moved=present sentinel=absent",
        ),
        (
            "replace",
            "attachment=accepted ordinary=rejected claim=present moved=absent sentinel=present",
        ),
        (
            "preexisting",
            "attachment=rejected ordinary=rejected claim=present moved=present sentinel=present",
        ),
    ],
)
def test_linux_terminal_retirement_requires_the_pinned_claim_inode(
    selected_shell: list[str], tmp_path: Path, scenario: str, expected: str
) -> None:
    if sys.platform != "linux":
        pytest.skip("terminal claim retirement uses Linux proc descriptor identity")
    sudo = shutil.which("sudo")
    assert sudo, "Linux native supervision regression requires sudo"
    workspace = tmp_path / "root-owned-retirement"
    try:
        result = subprocess.run(
            [
                sudo,
                "-n",
                *selected_shell,
                "-c",
                DEPENDENCY_RETIREMENT_PROBE,
                "dependency-retirement",
                str(ROOT),
                str(workspace),
                scenario,
            ],
            env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
            capture_output=True,
            check=False,
            timeout=8,
        )
        assert result.returncode == 0, result.stderr.decode(errors="replace")
        assert result.stdout.decode().strip() == expected
    finally:
        cleanup = subprocess.run(
            [sudo, "-n", "/bin/rm", "-rf", "--", str(workspace)],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert cleanup.returncode == 0, cleanup.stderr.decode(errors="replace")


@pytest.mark.parametrize(
    "case",
    [
        pytest.param("dependency_repair", marks=pytest.mark.diagnostic),
        "dependency_update_failure",
        pytest.param("dependency_retry", marks=pytest.mark.diagnostic),
        "dependency_daemon",
        pytest.param("dependency_threads", marks=pytest.mark.diagnostic),
        pytest.param("dependency_mixed", marks=pytest.mark.diagnostic),
        "dependency_loss",
    ],
)
def test_normal_repair_and_owned_cleanup(
    fixture_tools: tuple[list[str], str, str, str],
    dependency_process: Path,
    tmp_path: Path,
    case: str,
) -> None:
    result = run_dependency_case(fixture_tools, dependency_process, tmp_path, case)
    diagnostic = (
        f"{case}: exit={result.returncode}\n"
        f"stdout={result.stdout.decode(errors='replace')}\n"
        f"stderr={result.stderr.decode(errors='replace')}"
    )
    assert result.returncode == 0, diagnostic
    if case == "dependency_loss":
        assert (
            b"[CFMGR] dependencies: error: Entware attachment lost; cleanup pending"
            in result.stderr
        ), diagnostic
        assert (
            b"[CFMGR] dependencies: error: Entware operation stopped; owned mounts released"
            in result.stderr
        ), diagnostic
    elif case == "dependency_mixed":
        assert (
            b"[CFMGR] dependencies: error: dependency cleanup pending" in result.stderr
        ), diagnostic
    expected = (
        b"PASS: production loss cancellation with readonly fallback\n"
        if case == "dependency_loss"
        else b"PASS: production dependency update failure retires ownership without installation\n"
        if case == "dependency_update_failure"
        else b"PASS: production dependency repair and normal ownership cleanup\n"
    )
    assert expected in result.stdout, diagnostic
    assert list(tmp_path.iterdir()) == [], diagnostic


def test_detached_guard_requires_actual_readonly_cover(
    ledger_tools: tuple[list[str], str], tmp_path: Path
) -> None:
    """Missing nested guards are safe only behind the actual surviving cover."""
    expected = tmp_path / "expected"
    namespace = tmp_path / "namespace"
    current = tmp_path / "current"
    added = tmp_path / "added"
    root = ledger_row(10, 1, "/owned/view", device="0:100", options="ro")
    source = ledger_row(11, 1, "/owned/guard", device="0:101", options="ro")
    writable = ledger_row(12, 10, "/owned/view/tmp", device="0:50")
    guard = ledger_row(13, 12, "/owned/view/tmp/mnt/usb", device="0:101", options="ro")
    volume = ledger_row(14, 13, "/owned/view/tmp/mnt/usb", device="8:1")
    nested = ledger_row(
        15,
        14,
        "/owned/view/tmp/mnt/usb/entware/nested",
        device="0:101",
        options="ro",
    )
    expected.write_text(root + source + writable + guard + volume + nested)
    # Parent device detach removes nested guard aliases, while its independent
    # readonly guard remains the deepest actual mount at the lost branch.
    current.write_text(root + source + writable + guard)
    namespace.write_bytes(current.read_bytes())
    result = run_ledger(
        ledger_tools, "dynamic", "/owned/view", expected, namespace, current, added
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert added.read_bytes() == b""
    # Removing the guard exposes the writable native /tmp bind. A higher readonly
    # scaffold cannot authorize cleanup/classification through this writable cover.
    current.write_text(root + source + writable)
    namespace.write_bytes(current.read_bytes())
    result = run_ledger(
        ledger_tools, "dynamic", "/owned/view", expected, namespace, current, added
    )
    assert result.returncode != 0 and added.read_bytes() == b""
    # A writable device still covering the missing nested guard is equally unsafe.
    current.write_text(root + source + writable + guard + volume)
    namespace.write_bytes(current.read_bytes())
    result = run_ledger(
        ledger_tools, "dynamic", "/owned/view", expected, namespace, current, added
    )
    assert result.returncode != 0 and added.read_bytes() == b""


def test_actual_installer_repair_and_publication(
    fixture_tools: tuple[list[str], str, str, str],
    dependency_process: Path,
    installer_adapter: Path,
    tmp_path: Path,
    capfd: pytest.CaptureFixture[str],
) -> None:
    # Child output remains captured by subprocess; only finite phase costs are
    # printed directly so successful Quick runs retain the timing evidence.
    with capfd.disabled():
        result = run_dependency_case(
            fixture_tools,
            dependency_process,
            tmp_path,
            "dependency_installer",
            installer_adapter,
        )
    diagnostic = (
        f"exit={result.returncode} stdout={result.stdout!r} stderr={result.stderr!r}"
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"PASS: actual installer repair, fresh full probes and unchanged transaction\n",
        b"",
    ), diagnostic
    assert list(tmp_path.iterdir()) == [], diagnostic


TASK_ADMISSION = r"""
. "$1"
cfmgr_tasks_context=$2 cfmgr_tasks_awk=$3
cfmgr_tasks_state=running cfmgr_tasks_loss=0 cfmgr_tasks_action_refused=0
cfmgr_tasks_deadline=20 cfmgr_test_now=10 cfmgr_install_interrupted=0
cfmgr_test_attached=1 cfmgr_test_event=0 cfmgr_test_finished=0
cfmgr_test_case=$4
_cfmgr_tasks_now() { cfmgr_tasks_now=$cfmgr_test_now; }
cfmgr_storage_attached() { [ "$cfmgr_test_attached" = 1 ]; }
cfmgr_execution_tasks_event() { cfmgr_test_event=$((cfmgr_test_event+1)); }
cfmgr_execution_view_recheck() {
    case $cfmgr_test_case in
        gate-interrupt) cfmgr_install_interrupted=1 ;;
        gate-expiry) cfmgr_test_now=20 ;;
        gate-loss) cfmgr_test_attached=0 ;;
    esac
}
_cfmgr_tasks_direct() {
    cfmgr_identity_state=Z
    case $cfmgr_test_case in
        terminal-interrupt) cfmgr_install_interrupted=1 ;;
        terminal-expiry) cfmgr_test_now=20 ;;
    esac
}
cfmgr_execution_tasks_finish() {
    exec 4<&-
    cfmgr_test_finished=1 cfmgr_tasks_state=quiescent cfmgr_tasks_exit=0
    case $cfmgr_test_case in
        cleanup-interrupt) cfmgr_install_interrupted=1 ;;
        cleanup-late) cfmgr_test_now=30 ;;
    esac
}
exec 4>"$cfmgr_tasks_context/gate"
case $cfmgr_test_case in
    receipt-interrupt|receipt-expiry)
        printf 'ready END\n' >"$cfmgr_tasks_context/receipt"
        if [ "$cfmgr_test_case" = receipt-interrupt ]; then cfmgr_install_interrupted=1
        else cfmgr_test_now=20; fi
        if cfmgr_execution_tasks_receipt ready; then code=0; else code=$?; fi
        ;;
    *) if cfmgr_execution_tasks_run 'install flock'; then code=0; else code=$?; fi ;;
esac
exec 4<&-
printf '%s %s %s %s\n' "$code" "$cfmgr_tasks_action_refused" "$cfmgr_test_finished" "$cfmgr_test_event"
"""


@pytest.mark.parametrize(
    ("case", "expected", "gate"),
    [
        ("gate-interrupt", b"1 1 1 0\n", b""),
        ("gate-expiry", b"1 1 1 0\n", b""),
        ("gate-loss", b"1 1 1 1\n", b""),
        ("terminal-interrupt", b"1 1 1 0\n", b"repair install flock END\n"),
        ("terminal-expiry", b"1 1 1 0\n", b"repair install flock END\n"),
        ("cleanup-interrupt", b"1 0 1 0\n", b"repair install flock END\n"),
        ("cleanup-late", b"0 0 1 0\n", b"repair install flock END\n"),
        ("receipt-interrupt", b"1 1 0 0\n", b""),
        ("receipt-expiry", b"1 1 0 0\n", b""),
    ],
)
def test_action_refusal_survives_successful_child_cleanup(
    ledger_tools: tuple[list[str], str],
    tmp_path: Path,
    case: str,
    expected: bytes,
    gate: bytes,
) -> None:
    """Exercise real receipt/gate policy with deterministic phase observations."""
    shell, awk = ledger_tools
    result = subprocess.run(
        [
            *shell,
            "-c",
            TASK_ADMISSION,
            "task-admission",
            str(ROOT / "modules/lib/execution.sh"),
            str(tmp_path),
            awk,
            case,
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")
    assert (tmp_path / "gate").read_bytes() == gate


@pytest.mark.parametrize("phase", ["logger", "opkg"])
def test_admission_unknown_probe_blocks_later_repair_probe(
    selected_shell: list[str], tmp_path: Path, phase: str
) -> None:
    if not Path("/usr/bin/logger").is_file():
        pytest.skip("fixed native logger path is absent; required Linux proof pending")
    # Adapt only the unavailable firmware opkg executable lookup; admission and
    # unresolved supervisor handling otherwise execute byte-identical code.
    opkg = tmp_path / "opkg"
    opkg.write_text("#!/bin/sh\nexit 0\n")
    opkg.chmod(0o700)
    source = (ROOT / "modules/lib/package.sh").read_text()
    original = "[ -x /opt/bin/opkg ] || return 1"
    forwarded = f"[ -x {shlex.quote(str(opkg))} ] || return 1"
    assert source.count(original) == 1
    adapted = source.replace(original, forwarded, 1)
    assert adapted.replace(forwarded, original, 1) == source
    adapter = tmp_path / "package.sh"
    adapter.write_text(adapted)
    script = r"""
. "$1/modules/lib/execution.sh"
. "$2/package.sh"
_cfmgr_tasks_now() { cfmgr_tasks_now=10; }
cfmgr_bootstrap_attached() { return 0; }
cfmgr_test_phase=$3
cfmgr_bootstrap_admit_tool() {
    if [ "$cfmgr_test_phase" = opkg ]; then
        cfmgr_probe_pid=123 cfmgr_probe_start=456 cfmgr_probe_boot=fixture-boot
        return 3
    fi
}
# Protected native applet admission is forwarded; only logger's supervised
# metadata operation is unresolved, with a retained exact child receipt.
cfmgr_test_readlink() { printf '%s\n' /bin/busybox; }
cfmgr_bootstrap_native_protected() {
    if [ "$cfmgr_dependencies_logger_resolved" = /bin/busybox ]; then
        cfmgr_probe_pid=123 cfmgr_probe_start=456 cfmgr_probe_boot=fixture-boot
        return 3
    fi
}
cfmgr_dependencies_native() { : >"$2/overwritten"; return 99; }
cfmgr_install_readlink=cfmgr_test_readlink
cfmgr_dependencies_logger_resolved=''
if cfmgr_dependencies_repair flock "$2" "$1" / /bin/sh /usr/bin/env awk readlink usleep wc mknod chroot; then code=0
else code=$?; fi
printf '%s %s %s %s %s %s\n' "$code" "$cfmgr_dependencies_native_unresolved" "$cfmgr_dependencies_state" \
    "$cfmgr_dependencies_native_pid" "$cfmgr_dependencies_native_start" "$cfmgr_dependencies_native_boot"
"""
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            script,
            "native-admission",
            str(ROOT),
            str(tmp_path),
            phase,
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"3 1 retained 123 456 fixture-boot\n",
        b"",
    )
    assert set(tmp_path.iterdir()) == {opkg, adapter}
