"""Confirmed installed action, selected force consumer and bounded DNS adapters.

Portable adapters prove policy/dispatch; retained_launch.sh supplies the real
Linux storage/worker/guard integration without a public-network test dependency.
"""

from __future__ import annotations

import os
import pty
import shlex
import subprocess
import sys
from pathlib import Path

import pytest
from entry_package_fixture import finish_package
from test_config_observation import commands, config
from test_dependency_consumer import LINUX_REPAIR_CONTROLLER
from test_install import shell, tools

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["commands", "config", "shell", "tools"]


@pytest.fixture
def installed_entry(tmp_path: Path, tools: dict[str, str], shell) -> tuple[Path, Path]:
    jffs = tmp_path / "jffs"
    support = jffs / "addons/CFMgr.d"
    scripts = jffs / "scripts"
    scripts.mkdir(parents=True)
    (support / "modules/lib").mkdir(parents=True)
    (support / "modules/helpers").mkdir()
    (support / "modules/manager.sh").write_text("# inert adapter\n")
    (support / "modules/backup.sh").write_text("# inert adapter\n")
    original = (ROOT / "cfmgr.sh").read_text()
    entry = scripts / "cfmgr.sh"
    entry.write_text(original)
    marker = tmp_path / "native-preparation"
    for name in ("storage", "execution", "network", "config"):
        (support / f"modules/lib/{name}.sh").write_text("# inert adapter\n")
    # The retained entry verifies and launches through the same package owner.
    # Apply the host JFFS adapter once, then override only the intended native
    # preparation/cleanup/work callbacks after its real category definitions.
    (support / "modules/manager.sh").write_text(
        (ROOT / "modules/manager.sh").read_text()
    )
    (support / "modules/status.sh").write_text((ROOT / "modules/status.sh").read_text())
    (support / "modules/lib/package.sh").write_text(
        (ROOT / "modules/lib/package.sh").read_text()
        + "\ncfmgr_bootstrap_native_prepare() { printf 'prepare\\n' >"
        + shlex.quote(str(marker))
        + "; }\ncfmgr_bootstrap_cleanup() { return 0; }\n"
        + 'cfmgr_launch_work() { cfmgr_install_interrupted=0; printf "action=%s\\n" "$cfmgr_launch_requested_action"; }\n'
    )
    finish_package(entry, support, tools, shell, adapt=True)
    return entry, marker


def entry_run(
    shell: list[str],
    entry: Path,
    args: list[str],
    data: bytes,
    *,
    terminal: bool,
    timeout: float = 8,
) -> subprocess.CompletedProcess[bytes]:
    environment = {**os.environ, "CFMGR_INTERNAL_LAUNCH": "1", "CFMGR_CONSENT": "yes"}
    if not terminal:
        return subprocess.run(
            [*shell, str(entry), *args],
            input=data,
            env=environment,
            capture_output=True,
            timeout=timeout,
            check=False,
        )
    master, slave = pty.openpty()
    try:
        child = subprocess.Popen(
            [*shell, str(entry), *args],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=environment,
        )
        os.write(master, data)
        try:
            out, err = child.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            child.kill()
            child.communicate()
            raise
        return subprocess.CompletedProcess(child.args, child.returncode, out, err)
    finally:
        os.close(master)
        os.close(slave)


@pytest.mark.parametrize(
    ("args", "data", "terminal", "action"),
    [
        (["--reinstall-dependencies"], b"y\n", True, "reinstall"),
        (["--reinstall-dependencies"], b"n\n", True, None),
        (["--reinstall-dependencies"], b"\n", True, None),
        (["--reinstall-dependencies"], b"\x04", True, None),
        (["--reinstall-dependencies"], b"yes\n", False, None),
        (["--internal-launch", "reinstall"], b"\n", True, None),
        (["--internal-launch", "reinstall", "yes"], b"y\n", True, None),
        ([], b"aox\nao\ne\ne\n", True, None),
        ([], b"uf\nao\n1\ny\n", True, "reinstall"),
        ([], b"", False, "normal"),
    ],
)
def test_actual_entry_confirmation_and_limited_menu(
    shell, installed_entry, args, data, terminal, action
) -> None:
    entry, marker = installed_entry
    result = entry_run(shell, entry, args, data, terminal=terminal)
    if action:
        assert (result.returncode, marker.read_text()) == (0, "prepare\n"), (
            result.stdout,
            result.stderr,
        )
        assert f"action={action}\n".encode() in result.stdout
        assert result.stdout.count(b"[y/N]") == (action == "reinstall")
    else:
        assert not marker.exists(), (result.stdout, result.stderr)
        assert b"action=" not in result.stdout
        if b"reinstall cancelled" in result.stderr:
            assert b"launch: error" not in result.stderr or not terminal


def test_cli_relative_installed_entry_and_source_copy_boundary(
    shell, installed_entry, tmp_path
) -> None:
    entry, marker = installed_entry
    # Relative invocation reaches the same sanitized, canonical installed action.
    relative = Path(os.path.relpath(entry))
    result = entry_run(
        shell, relative, ["--reinstall-dependencies"], b"y\n", terminal=True
    )
    assert result.returncode == 0 and marker.exists(), result.stderr
    marker.unlink()
    copied = tmp_path / "copied-cfmgr.sh"
    copied.write_bytes(entry.read_bytes())
    refused = entry_run(
        shell, copied, ["--reinstall-dependencies"], b"y\n", terminal=True
    )
    assert refused.returncode == 1 and not marker.exists()
    assert b"use the installed entry" in refused.stderr


FORCE_CONSUMER = r"""
. "$1/modules/lib/package.sh"
base=$2 scenario=$3
cfmgr_install_source=$base/source cfmgr_install_context=$base/ram
cfmgr_install_private_context=$cfmgr_install_context
cfmgr_install_source_fd=9 cfmgr_install_context_fd=0 cfmgr_install_interrupted=0
cfmgr_storage_source=/fixture/device
exec 0<"$cfmgr_install_context" 9<"$cfmgr_install_source"
mark() { printf '%s\n' "$1" >>"$base/trace"; }
cfmgr_bootstrap_native_admission() { mark admission; }
cfmgr_bootstrap_action() {
    case $1 in install-nvram) cfmgr_install_output=$base/nvram ;;
    install-mkdir-private) mkdir "$2"; mark post-context ;; *) return 88 ;; esac
}
cfmgr_prerequisites_run() { cfmgr_probe_stdout=$base/blkid; cfmgr_probe_stderr=$base/err; cfmgr_probe_exit=0; }
cfmgr_storage_uuid() { return 0; }
cfmgr_bootstrap_metadata() { return 0; }
cfmgr_launch_reinstall_scope() { cfmgr_install_dependency_scope=shared; case $scenario in *dns*) cfmgr_install_dependency_scope=tunnel ;; esac; }
cfmgr_bootstrap_reinstall_dns() {
    mark "dns-$1"
    cfmgr_install_dns_native=unsupported
    [ "$scenario" != native-dns ] || cfmgr_install_dns_native=srv-a-verified
    [ "$scenario:$1" != unknown-dns:pre ] || return 1
    [ "$scenario:$1" != deferred-dns:post ] || return 1
}
cfmgr_prerequisites_check() {
    mark inventory
    cfmgr_prereq_result=capabilities-checked cfmgr_prereq_missing='' cfmgr_prereq_flock_provider=native
    case $scenario in entware-flock | provider-change) cfmgr_prereq_flock_provider=entware ;; esac
    if [ -n "${cfmgr_install_original_context:-}" ]; then
        mark post
        if [ "$scenario" = provider-change ]; then
            # A now-working native candidate must not replace the selected
            # Entware probe. The fixed ninth argument must force that provider.
            [ "$9" = - ] || return 87
            mark selected-flock-probed
        fi
        [ "$scenario" != post-fail ] || return 1
        [ "$scenario" != post-unknown ] || return 3
    fi
}
cfmgr_dependencies_repair() {
    mark "selected:$1"
    [ "$cfmgr_install_source_fd:$cfmgr_install_context_fd" = 0:9 ] || return 89
    cfmgr_dependencies_result=repaired
    case $scenario in
    coalesced) cfmgr_dependencies_result=coalesced ;;
    repair-fail) return 1 ;;
    repair-unknown) return 3 ;;
    esac
}
cfmgr_launch_migrate_snapshot() { mark migrate; }
cfmgr_bootstrap_cleanup() { mark cleanup-original; exec 3<&-; }
if cfmgr_bootstrap_shared_requirements retained reinstall; then code=0; else code=$?; fi
printf 'status=%s source-fd=%s context-fd=%s\n' "$code" "$cfmgr_install_source_fd" "$cfmgr_install_context_fd"
exec 0<&- 3<&- 9<&-
"""


@pytest.mark.parametrize(
    ("scenario", "selected", "status", "post"),
    [
        ("healthy", "", 0, True),
        ("entware-flock", " flock", 0, True),
        ("provider-change", " flock", 0, True),
        ("unsupported-dns", " bind-dig", 0, True),
        ("native-dns", "", 0, True),
        ("unknown-dns", None, 1, False),
        ("deferred-dns", " bind-dig", 1, True),
        ("coalesced", "", 1, False),
        ("repair-fail", "", 1, False),
        ("repair-unknown", "", 3, False),
        ("post-fail", "", 1, True),
        ("post-unknown", "", 3, True),
    ],
)
def test_real_shared_force_consumer_policy_adapters(
    shell, tmp_path, scenario, selected, status, post
) -> None:
    for name in ("source", "ram"):
        (tmp_path / name).mkdir()
    for name, value in (("nvram", "1\n"), ("blkid", "uuid\n"), ("err", "")):
        (tmp_path / name).write_text(value)
    result = subprocess.run(
        [
            *shell,
            "-c",
            FORCE_CONSUMER,
            "force-consumer",
            str(ROOT),
            str(tmp_path),
            scenario,
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    assert f"status={status} ".encode() in result.stdout
    trace = (tmp_path / "trace").read_text().splitlines()
    selected_lines = [line for line in trace if line.startswith("selected:")]
    assert selected_lines == (
        []
        if selected is None
        else ["selected:jq coreutils-timeout coreutils-sha256sum" + selected]
    )
    assert ("post" in trace) == post
    assert ("migrate" in trace) == (status == 0)
    if scenario == "repair-unknown":
        assert b"source-fd=0 context-fd=9" in result.stdout
    if status == 3:
        assert "cleanup-original" not in trace
    if scenario == "provider-change":
        assert "selected-flock-probed" in trace


@pytest.mark.parametrize("code", [1, 3])
def test_linux_actual_repair_invokes_late_scope_callback_before_worker(
    shell, tmp_path, code
) -> None:
    if sys.platform != "linux":
        pytest.skip("actual repair callback requires Linux proc/descriptor semantics")
    parent = tmp_path / "claims"
    marker = tmp_path / "markers"
    parent.mkdir(mode=0o700)
    marker.mkdir(mode=0o700)
    # Use the existing real repair-controller adapter. Under required CI this
    # runs the pinned stripped ash where `command -v` does not exist.
    anchor = 'if [ "$cfmgr_test_role" = waiter ]; then'
    addition = r"""
cfmgr_install_dependency_action=reinstall
cfmgr_launch_reinstall_recheck() { : >"$cfmgr_test_marker/scope-recheck"; return "$CFMGR_TEST_SCOPE_CODE"; }
cfmgr_execution_tasks_finish() { : >"$cfmgr_test_marker/finish"; cfmgr_tasks_state=quiescent; }
cfmgr_execution_view_release() { : >"$cfmgr_test_marker/release-view"; cfmgr_view_state=released cfmgr_keeper_state=released; }
"""
    assert LINUX_REPAIR_CONTROLLER.count(anchor) == 1
    script = LINUX_REPAIR_CONTROLLER.replace(anchor, addition + anchor)
    script = script.replace(
        'echo "postprobe=$cfmgr_test_postprobe"',
        'echo "postprobe=$cfmgr_test_postprobe"\necho "state=$cfmgr_dependencies_state"\necho "native-unresolved=${cfmgr_dependencies_native_unresolved:-0}"',
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "scope-callback",
            str(parent),
            str(ROOT),
            str(marker),
            "owner",
        ],
        env={
            **os.environ,
            "CFMGR_TEST_ROOT": str(ROOT),
            "CFMGR_TEST_UID": str(os.getuid()),
            "CFMGR_TEST_USLEEP": "/bin/true",
            "CFMGR_TEST_SCOPE_CODE": str(code),
        },
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    assert (marker / "scope-recheck").exists()
    assert f"result={code}\n".encode() in result.stdout, result.stderr.decode()
    assert not (marker / "repair-once").exists()
    assert (marker / "finish").exists() == (code == 1)
    assert (marker / "release-view").exists() == (code == 1)
    assert (parent / "dependencies").exists() == (code == 3)
    if code == 3:
        assert b"state=retained\nnative-unresolved=1\n" in result.stdout


@pytest.mark.parametrize(
    ("scenario", "status", "observed", "released", "loss", "reason"),
    [
        ("lost", 1, True, True, 1, "storage-lost"),
        ("attached-failure", 1, True, True, 0, "admission"),
        ("finish-unresolved", 3, False, False, 0, "cleanup-pending"),
        ("event-unresolved", 3, True, False, 1, "storage-lost"),
        ("native-unresolved", 3, False, False, 0, "admission"),
        ("opkg-update", 1, True, True, 0, "admission"),
        ("opkg-install", 1, True, True, 0, "admission"),
        ("opkg-refused", 1, True, True, 0, "admission"),
        ("opkg-interrupted", 1, True, True, 0, "admission"),
        ("opkg-malformed", 1, True, True, 0, "admission"),
        ("opkg-cleanup", 3, True, True, 0, "admission"),
    ],
)
def test_actual_controller_observes_loss_only_after_resolved_owned_work(
    shell, tmp_path, scenario, status, observed, released, loss, reason
) -> None:
    # Reuse the controller/cleanup adapter; replace only Linux kernel inputs
    # unavailable on macOS. Actual repair and storage-event bodies stay intact.
    boot = tmp_path / "kernel-boot-id"
    boot.write_text("12345678-1234-1234-1234-123456789abc\n")
    source = (ROOT / "modules/lib/execution.sh").read_text()
    adapted = source.replace("/proc/sys/kernel/random/boot_id", str(boot))
    assert adapted.replace(str(boot), "/proc/sys/kernel/random/boot_id") == source
    controller = tmp_path / "controller.sh"
    controller.write_text(adapted)
    parent = tmp_path / "claims"
    marker = tmp_path / "markers"
    parent.mkdir(mode=0o700)
    marker.mkdir(mode=0o700)
    anchor = 'if [ "$cfmgr_test_role" = waiter ]; then'
    addition = r"""
cfmgr_test_observation_scenario=$CFMGR_TEST_OBSERVATION_SCENARIO
cfmgr_test_mark() { printf '%s\n' "$1" >>"$cfmgr_test_marker/trace"; }
_cfmgr_tasks_now() { cfmgr_tasks_now=100; }
cfmgr_prerequisites_identity() { cfmgr_identity_start=1234; }
cfmgr_dependencies_claim_admit() { [ -d "$1" ] && [ ! -L "$1" ]; }
cfmgr_dependencies_attachment_ok() { [ -d "$cfmgr_dependencies_context" ]; }
cfmgr_execution_view_create() {
    cfmgr_view_state=active cfmgr_keeper_state=quiescent
    if [ "$cfmgr_test_observation_scenario" = native-unresolved ]; then
        cfmgr_dependencies_native_unresolved=1
        return 3
    fi
}
cfmgr_execution_tasks_run() {
    cfmgr_test_mark run
    case $cfmgr_test_observation_scenario in opkg-*)
        cfmgr_tasks_state=quiescent cfmgr_tasks_exit=1 cfmgr_tasks_survivors=0
        cfmgr_tasks_action_refused=0 cfmgr_tasks_loss=0
        operation=update
        [ "$cfmgr_test_observation_scenario" != opkg-install ] || operation=install
        printf 'failed %s 7 END\n' "$operation" >>"$cfmgr_dependencies_context/receipt"
        case $cfmgr_test_observation_scenario in
        opkg-refused) cfmgr_tasks_action_refused=1 ;;
        opkg-interrupted) cfmgr_install_interrupted=1 ;;
        opkg-malformed) printf 'unexpected suffix\n' >>"$cfmgr_dependencies_context/receipt" ;;
        esac
        return 1
        ;;
    esac
    if [ "$cfmgr_test_observation_scenario" = attached-failure ]; then cfmgr_tasks_state=quiescent; return 1; fi
    cfmgr_tasks_state=retained
    return 3
}
cfmgr_execution_tasks_finish() {
    cfmgr_test_mark finish
    [ "$cfmgr_test_observation_scenario" != finish-unresolved ] || return 3
    cfmgr_tasks_state=quiescent
}
cfmgr_storage_attached() {
    cfmgr_test_mark observation
    case $cfmgr_test_observation_scenario in attached-failure | opkg-*) return 0 ;; *) return 1 ;; esac
}
cfmgr_dependencies_report() {
    cfmgr_test_mark "report:$1"
    if [ "$cfmgr_test_observation_scenario:$1" = event-unresolved:storage-lost ]; then return 3; fi
    return 0
}
cfmgr_execution_view_release() {
    cfmgr_test_mark release
    [ "$cfmgr_test_observation_scenario" != opkg-cleanup ] || return 3
    cfmgr_view_state=released cfmgr_keeper_state=released
}
"""
    assert LINUX_REPAIR_CONTROLLER.count(anchor) == 1
    script = LINUX_REPAIR_CONTROLLER.replace(anchor, addition + anchor)
    script = script.replace(
        '. "$CFMGR_TEST_ROOT/modules/lib/execution.sh"',
        '. "$CFMGR_TEST_CONTROLLER"',
    )
    script = script.replace(
        'echo "postprobe=$cfmgr_test_postprobe"',
        'echo "postprobe=$cfmgr_test_postprobe"\necho "loss=$cfmgr_dependencies_loss"\necho "reason=$cfmgr_dependencies_reason"\necho "failure=$cfmgr_dependencies_failure"',
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "resolved-loss-observation",
            str(parent),
            str(ROOT),
            str(marker),
            "owner",
        ],
        env={
            **os.environ,
            "CFMGR_TEST_ROOT": str(ROOT),
            "CFMGR_TEST_UID": str(os.getuid()),
            "CFMGR_TEST_USLEEP": "/bin/true",
            "CFMGR_TEST_CONTROLLER": str(controller),
            "CFMGR_TEST_OBSERVATION_SCENARIO": scenario,
        },
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    assert f"result={status}\n".encode() in result.stdout, result.stdout
    assert f"loss={loss}\nreason={reason}\n".encode() in result.stdout
    expected_failure = "opkg" if scenario in {"opkg-update", "opkg-install"} else "none"
    assert f"failure={expected_failure}\n".encode() in result.stdout
    trace_file = marker / "trace"
    trace = trace_file.read_text().splitlines() if trace_file.exists() else []
    assert ("observation" in trace) == observed
    assert ("release" in trace) == released
    assert (parent / "dependencies").exists() == (status == 3)
    if scenario == "lost":
        assert trace == [
            "run",
            "finish",
            "observation",
            "report:storage-lost",
            "release",
            "report:cleanup-complete",
        ]
    elif scenario == "native-unresolved":
        assert trace == []


DNS_CONSUMER = r"""
. "$1/modules/lib/execution.sh"
. "$1/modules/lib/package.sh"
cfmgr_install_source=$1 cfmgr_install_context=$2 cfmgr_install_sh=$3
cfmgr_install_env=$4 cfmgr_install_awk=$5 cfmgr_install_sleep=$6 cfmgr_install_wc=$7
dns_native=$8 dns_dig=$9
shift 9
dns_scenario=$1 dns_phase=$2
[ "$dns_scenario" != selected-dig ] || cfmgr_install_force_dig=1
cfmgr_bootstrap_dns_admit_native() { cfmgr_install_dns_tool=$dns_native; return 0; }
cfmgr_prerequisites_admit_tool() { [ "$1" = /opt/bin/dig ]; }
cfmgr_prerequisites_run() {
    selected_mode=$1 selected_context=$2 selected_sh=$3 selected_probe=$4 selected_env=$5 selected_tool=$9
    shift 9
    [ "$selected_tool" != /opt/bin/dig ] || selected_tool=$dns_dig
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0} + 1))
    cfmgr_probe_stdout=$selected_context/$selected_mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$selected_context/$selected_mode.$cfmgr_probe_serial.err
    printf '%s\n' "$selected_mode" >>"$selected_context/modes"
    [ "$dns_scenario:$selected_mode" != unknown:native-dns-native-srv ] || return 3
    "$selected_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C "$selected_sh" "$selected_probe" "$selected_mode" "$selected_tool" "$selected_context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
    return 0
}
if cfmgr_bootstrap_reinstall_dns "$dns_phase"; then status=0; else status=$?; fi
printf 'status=%s native=%s\n' "$status" "$cfmgr_install_dns_native"
"""


def dns_tools(tmp_path: Path, scenario: str) -> tuple[Path, Path, Path]:
    native_tool = tmp_path / "native-nslookup"
    query_log = tmp_path / "query-argv"
    srv = (
        "Server:\t\t192.0.2.53\nAddress:\t192.0.2.53:53\n\n"
        "_v2-origintunneld._tcp.argotunnel.com\tservice = 0 1 7844 region1.v2.argotunnel.com\n"
        "_v2-origintunneld._tcp.argotunnel.com\tservice = 0 1 7844 region2.v2.argotunnel.com\n"
        "_v2-origintunneld._tcp.argotunnel.com\tservice = 0 1 7844 ignored.v2.argotunnel.com\n"
    )
    a = "Server:\t\t192.0.2.53\nAddress:\t192.0.2.53:53\n\nName:\t%s\nAddress: 192.0.2.1\n"
    header = "#!/bin/sh\nprintf '%s\\n' \"$*\" >>" + shlex.quote(str(query_log)) + "\n"
    if scenario in {"lede", "dig-outage", "unknown"}:
        body = "printf '%s\\n' 'Invalid query type \"SRV\"' >&2\nexit 1\n"
    elif scenario == "ordinary":
        body = "printf '%s\\n' 'BusyBox v1.25.1 (fixture) multi-call binary.' '' 'Usage: nslookup [HOST] [SERVER]' '' 'Query the nameserver for the IP address of the given HOST' 'optionally using a specified DNS server' >&2\nexit 1\n"
    elif scenario == "outage":
        body = "printf '%s\\n' 'nslookup: SERVFAIL' >&2\nexit 1\n"
    elif scenario == "malformed":
        body = "printf '%s\\n' 'service = 0 1 7844 malformed'\n"
    else:
        body = (
            "case $1 in\n-q | --type=SRV) printf '%s\\n' 'nslookup: invalid query type \"\"' >&2; exit 1 ;;\n"
            "-type=SRV) printf '%s' " + shlex.quote(srv) + " ;;\n"
            "-type=A) printf "
            + shlex.quote(
                "Server:\t\t192.0.2.53\nAddress:\t192.0.2.53:53\n\n"
                if scenario == "server-only"
                else a
            )
            + ' "$4" ;;\n*) exit 2 ;;\nesac\n'
        )
    native_tool.write_text(header + body)
    native_tool.chmod(0o700)
    dig = tmp_path / "dig"
    dig.write_text(
        header
        + "case $1 in -v) printf 'DiG fixture\\n'; exit 0 ;; esac\n"
        + (
            "printf '%s\\n' 'dig: network unavailable' >&2; exit 1\n"
            if scenario == "dig-outage"
            else "case $4 in SRV) printf '%s\\n' '0 1 7844 region1.v2.argotunnel.com.' ;; A) printf '%s\\n' '192.0.2.1' ;; *) exit 2 ;; esac\n"
        )
    )
    dig.chmod(0o700)
    return native_tool, dig, query_log


@pytest.mark.parametrize(
    ("scenario", "phase", "status", "native", "dig_used"),
    [
        ("lede", "pre", 0, "unsupported", False),
        ("ordinary", "pre", 0, "unsupported", False),
        ("modern", "pre", 0, "srv-a-verified", False),
        ("server-only", "pre", 1, "unknown", False),
        ("outage", "pre", 1, "unknown", False),
        ("malformed", "pre", 1, "unknown", False),
        ("unknown", "pre", 3, "unknown", False),
        ("lede", "post", 0, "unsupported", True),
        ("dig-outage", "post", 1, "unsupported", True),
        ("selected-dig", "post", 0, "unsupported", True),
    ],
)
def test_actual_dns_syntax_and_response_policy_adapters(
    shell, tools, tmp_path, scenario, phase, status, native, dig_used
) -> None:
    native_tool, dig, query_log = dns_tools(tmp_path, scenario)
    result = subprocess.run(
        [
            *shell,
            "-c",
            DNS_CONSUMER,
            "dns-consumer",
            str(ROOT),
            str(tmp_path),
            tools["sh"],
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            str(native_tool),
            str(dig),
            scenario,
            phase,
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == f"status={status} native={native}\n".encode()
    modes = (tmp_path / "modes").read_text().splitlines()
    assert ("native-dns-dig-srv" in modes) == dig_used
    if scenario == "modern":
        assert modes.count("native-dns-native-srv") == 2
        assert modes.count("native-dns-native-a") == 2
        argv = query_log.read_text().splitlines()
        assert argv[-2:] == [
            "-type=A -retry=1 -timeout=2 region1.v2.argotunnel.com",
            "-type=A -retry=1 -timeout=2 region2.v2.argotunnel.com",
        ]
    if status == 3:
        assert modes == ["native-dns-native-srv"]
    if scenario == "selected-dig":
        assert "native-dns-native-srv" not in modes
    if status == 1:
        assert (
            b"verification deferred" in result.stderr
            or b"capability unverified" in result.stderr
        )


SCOPE_CONSUMER = r"""
. "$1/modules/lib/package.sh"
cfmgr_install_source=$1 cfmgr_install_context=$2 cfmgr_install_sh=$3
cfmgr_install_env=$4 cfmgr_install_awk=$5 cfmgr_install_sleep=$6 cfmgr_install_wc=$7
cfmgr_install_ls=$8
cfmgr_launch_snapshot=$2/snapshot cfmgr_launch_live=$2/live cfmgr_launch_generation=1
cfmgr_launch_metadata() { [ -f "$1" ] && [ ! -L "$1" ]; }
cfmgr_prerequisites_run() {
    selected_mode=$1 selected_context=$2 selected_sh=$3 selected_probe=$4 selected_env=$5 selected_tool=$9
    shift 9
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0} + 1))
    cfmgr_probe_stdout=$selected_context/$selected_mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$selected_context/$selected_mode.$cfmgr_probe_serial.err
    "$selected_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C "$selected_sh" "$selected_probe" "$selected_mode" "$selected_tool" "$selected_context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
}
cfmgr_launch_reinstall_scope || exit 99
if cfmgr_launch_reinstall_recheck; then code=0; else code=$?; fi
printf 'status=%s scope=%s\n' "$code" "$cfmgr_install_dependency_scope"
"""


@pytest.mark.parametrize("change", ["none", "generation", "scope", "invalid"])
def test_actual_native_scope_recheck_preserves_settings_and_refuses_stale_state(
    shell, tools, config, tmp_path, change
) -> None:
    import json

    value = json.loads(config)
    value["cloudflared"].update(configured=True, enabled=False)
    value["history"]["cloudflared"] = {"kept": "private-history"}
    snapshot = json.dumps(value, indent=2).encode()
    (tmp_path / "snapshot").write_bytes(snapshot)
    if change == "generation":
        value["generation"] = 2
    elif change == "scope":
        value["cloudflared"]["configured"] = False
    elif change == "invalid":
        del value["manager"]
    live = json.dumps(value, indent=2).encode()
    (tmp_path / "live").write_bytes(live)
    result = subprocess.run(
        [
            *shell,
            "-c",
            SCOPE_CONSUMER,
            "native-scope",
            str(ROOT),
            str(tmp_path),
            tools["sh"],
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            tools["ls"],
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    assert (
        result.stdout
        == f"status={0 if change == 'none' else 1} scope=tunnel\n".encode()
    )
    assert (tmp_path / "snapshot").read_bytes() == snapshot
    assert (tmp_path / "live").read_bytes() == live
    assert b"private-history" not in result.stdout + result.stderr


@pytest.fixture(scope="module")
def normal_inventory(tmp_path_factory) -> Path:
    """Share only source text; each consumer owns fresh probe and config files."""
    source = (ROOT / "modules/lib/execution.sh").read_text()
    definition = "cfmgr_prerequisites_check() {"
    renamed = "normal_actual_inventory() {"
    assert source.count(definition) == 1
    adapted = source.replace(definition, renamed, 1)
    assert adapted.replace(renamed, definition, 1) == source
    target = tmp_path_factory.mktemp("normal-inventory") / "execution.sh"
    target.write_text(adapted)
    return target


NORMAL_CONSUMER = r"""
. "$1/modules/lib/package.sh"
. "$1/modules/lib/package.sh"
base=$2 scenario=$3
. "$4"
shift 4
cfmgr_install_source=$1 cfmgr_install_context=$base/ram
cfmgr_install_sh=$2 cfmgr_install_env=$3 cfmgr_install_awk=$4
cfmgr_install_sleep=$5 cfmgr_install_wc=$6 cfmgr_install_ls=$7
normal_jq=$8 normal_timeout=$9
shift 9
normal_sha=$1 normal_flock=$2 normal_native=$3 normal_dig=$4
cfmgr_install_private_context=$cfmgr_install_context
cfmgr_install_source_fd=9 cfmgr_install_context_fd=0 cfmgr_install_interrupted=0
cfmgr_storage_source=/fixture/device
cfmgr_launch_snapshot=$base/snapshot cfmgr_launch_live=$base/live cfmgr_launch_generation=1
exec 0<"$cfmgr_install_context" 9<"$cfmgr_install_source"
mark() { printf '%s\n' "$1" >>"$base/trace"; }
cfmgr_bootstrap_native_admission() { return 0; }
cfmgr_bootstrap_action() {
    case $1 in install-nvram) cfmgr_install_output=$base/nvram ;;
    install-mkdir-private) mkdir "$2" ;; *) return 88 ;; esac
}
cfmgr_storage_uuid() { return 0; }
cfmgr_bootstrap_metadata() { return 0; }
cfmgr_launch_metadata() { [ -f "$1" ] && [ ! -L "$1" ]; }
cfmgr_prerequisites_attachment_ok() { return 0; }
cfmgr_prerequisites_supervisor() { return 0; }
cfmgr_bootstrap_dns_admit_native() {
    cfmgr_install_dns_tool=$normal_native
    case $scenario in unsafe-native) return 2 ;; absent-native) return 1 ;;
    post-new-dns) [ ! -e "$base/repaired" ] || return 1 ;;
    post-unsafe-native) [ ! -e "$base/repaired" ] || return 2 ;;
    esac
}
cfmgr_prerequisites_admit_tool() {
    case $1 in
    /opt/bin/dig | "$normal_dig")
        mark admit-dig
        [ "$scenario" != unsafe-dig ] || return 2
        [ "$scenario" != post-new-dns ] || return 1
        case $scenario in missing-dig | repair-outage | repair-failed | repair-unsafe | repair-unresolved | stale | coalesced | post-shared-fail | post-stale | post-unsafe-native | migration-failed | migration-unresolved)
            [ -e "$base/repaired" ] || return 1 ;;
        esac
        [ -f "$normal_dig" ] && [ -x "$normal_dig" ]
        return $?
        ;;
    "$normal_jq")
        case $scenario in shared-missing | outage-shared | post-new-dns)
            [ -e "$base/repaired" ] || return 1 ;;
        post-shared-fail) [ ! -e "$base/repaired" ] || return 1 ;;
        esac ;;
    esac
    [ -f "$1" ] && [ -x "$1" ]
}
cfmgr_prerequisites_run() {
    mode=$1 context=$2 selected_sh=$3 helper=$4 selected_env=$5 selected_tool=$9
    shift 9
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0}+1))
    cfmgr_probe_stdout=$context/$mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$context/$mode.$cfmgr_probe_serial.err
    case $mode in native-dns-* | launch-*) ;; *)
        cfmgr_probe_stdout=$context/$mode.out cfmgr_probe_stderr=$context/$mode.err ;;
    esac
    case $mode in
    timeout-exit) set -- "$selected_sh" "$helper" ;;
    timeout-expiry) set -- "$selected_sh" "$helper" "$cfmgr_install_sleep" ;;
    esac
    cfmgr_probe_reason='' cfmgr_probe_exit=0
    mark "$mode"
    if [ "$selected_tool" = host-flock-adapter ]; then
        : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"
        [ "$mode" != flock-compete ] || cfmgr_probe_exit=1
        return 0
    fi
    if [ "$mode" = blkid ]; then
        cfmgr_probe_stdout=$base/blkid cfmgr_probe_stderr=$base/err
        return 0
    fi
    if [ "$mode" = native-dns-native-srv ]; then
        case $scenario in
        attachment | clock) cfmgr_probe_reason=$scenario; return 1 ;;
        query-timeout) cfmgr_probe_reason=deadline; return 1 ;;
        helper-invalid) return 2 ;;
        unresolved) return 3 ;;
        esac

    fi
    [ "$selected_tool" != /opt/bin/dig ] || selected_tool=$normal_dig
    "$normal_timeout" --foreground --kill-after=0.1s 3s "$selected_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C \
        "$selected_sh" "$helper" "$mode" "$selected_tool" "$context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
    return 0
}
cfmgr_prerequisites_check() {
    mark "inventory:$1:${15}"
    if normal_actual_inventory "$1" "$2" "$cfmgr_install_sh" "$cfmgr_install_source/modules/helpers/worker.sh" \
        "$cfmgr_install_env" "$cfmgr_install_awk" "$cfmgr_install_sleep" "$cfmgr_install_wc" \
        "$normal_flock" "$normal_jq" "$normal_timeout" "$normal_sha" - "$normal_dig" "${15}"; then code=0; else code=$?; fi
    mark "missing:$cfmgr_prereq_missing"
    return "$code"
}
cfmgr_dependencies_repair() {
    mark "repair:$1"
    if [ "$scenario" = stale ]; then cp "$base/stale" "$base/live"; fi
    cfmgr_dependencies_before_repair || return $?
    mark mutation
    case $scenario in
    repair-failed) cfmgr_dependencies_failure=opkg cfmgr_dependencies_state=complete cfmgr_dependencies_loss=0 cfmgr_dependencies_native_unresolved=0; return 1 ;;
    repair-unsafe | shared-missing) return 1 ;;
    repair-unresolved) return 3 ;;
    esac
    : >"$base/repaired"
    [ "$scenario" != post-stale ] || cp "$base/stale" "$base/live"
    cfmgr_dependencies_result=repaired
    [ "$scenario" != coalesced ] || cfmgr_dependencies_result=coalesced
}
cfmgr_launch_migrate_snapshot() {
    mark migrate
    case $scenario in migration-failed) return 1 ;; migration-unresolved) return 3 ;; esac
}
cfmgr_bootstrap_cleanup() { mark cleanup-original; exec 3<&-; }
consumer=retained
[ "$scenario" != fresh ] || consumer=fresh
if cfmgr_bootstrap_shared_requirements "$consumer"; then code=0; else code=$?; fi
printf 'status=%s dns=%s scope=%s source-fd=%s context-fd=%s\n' "$code" "$cfmgr_install_dns_result" \
    "$cfmgr_install_dependency_scope" "$cfmgr_install_source_fd" "$cfmgr_install_context_fd"
exec 0<&- 3<&- 9<&-
"""


@pytest.mark.parametrize(
    ("scenario", "response", "status", "dns", "repair"),
    [
        ("fresh", "modern", 0, "not-required", None),
        ("shared", "modern", 0, "not-required", None),
        ("native", "modern", 0, "verified", None),
        ("missing-dig", "lede", 0, "verified", "bind-dig"),
        ("absent-native", "lede", 0, "verified", None),
        ("healthy-dig", "lede", 0, "verified", None),
        ("outage", "outage", 0, "deferred", None),
        ("malformed", "malformed", 0, "deferred", None),
        ("dig-outage", "dig-outage", 0, "deferred", None),
        ("repair-outage", "dig-outage", 0, "deferred", "bind-dig"),
        ("repair-failed", "lede", 0, "deferred", "bind-dig"),
        ("repair-unsafe", "lede", 1, "not-required", "bind-dig"),
        ("repair-unresolved", "lede", 3, "not-required", "bind-dig"),
        ("stale", "lede", 1, "not-required", "bind-dig"),
        ("coalesced", "lede", 0, "verified", "bind-dig"),
        ("shared-missing", "outage", 1, "deferred", "jq"),
        ("outage-shared", "outage", 0, "deferred", "jq"),
        ("post-shared-fail", "lede", 1, "not-required", "bind-dig"),
        ("post-stale", "lede", 1, "not-required", "bind-dig"),
        ("post-unsafe-native", "lede", 2, "not-required", "bind-dig"),
        ("post-new-dns", "outage", 0, "deferred", "jq"),
        ("migration-failed", "lede", 1, "verified", "bind-dig"),
        ("migration-unresolved", "lede", 3, "verified", "bind-dig"),
        ("unsafe-native", "modern", 2, "not-required", None),
        ("unsafe-dig", "lede", 2, "not-required", None),
        ("attachment", "modern", 2, "not-required", None),
        ("clock", "modern", 2, "not-required", None),
        ("helper-invalid", "modern", 2, "not-required", None),
        ("unresolved", "modern", 3, "not-required", None),
        ("query-timeout", "modern", 0, "deferred", None),
    ],
)
def test_normal_retained_scope_inventory_and_real_dns_queries(
    shell,
    tools,
    config,
    normal_inventory,
    tmp_path,
    scenario,
    response,
    status,
    dns,
    repair,
) -> None:
    import json
    import shutil

    for name in ("source", "ram"):
        (tmp_path / name).mkdir()
    # The production consumer reads a validated retained snapshot. Settings stay
    # configured but Off; native query qualification is never feature activation.
    settings = json.loads(config)
    settings["cloudflared"].update(configured=scenario != "shared", enabled=False)
    original = json.dumps(settings, indent=2).encode()
    for name in ("snapshot", "live"):
        (tmp_path / name).write_bytes(original)
    settings["generation"] = 2
    (tmp_path / "stale").write_text(json.dumps(settings))
    for name, value in (("nvram", "1\n"), ("blkid", "uuid\n"), ("err", "")):
        (tmp_path / name).write_text(value)
    native, dig, query_log = dns_tools(tmp_path, response)
    flock = shutil.which("flock")
    # macOS lacks flock; real native/Entware lock qualification remains in the
    # existing Linux retained integration. Other inventory probes run for real.
    flock = flock or "host-flock-adapter"
    result = subprocess.run(
        [
            *shell,
            "-c",
            NORMAL_CONSUMER,
            "normal-consumer",
            str(ROOT),
            str(tmp_path),
            scenario,
            str(normal_inventory),
            str(ROOT),
            tools["sh"],
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            tools["ls"],
            tools["jq"],
            tools["timeout"],
            tools["sha256sum"],
            flock,
            str(native),
            str(dig),
        ],
        capture_output=True,
        check=False,
        timeout=12,
    )
    assert result.returncode == 0, result.stderr
    scope = "shared" if scenario in {"fresh", "shared"} else "tunnel"
    assert f"status={status} dns={dns} scope={scope} ".encode() in result.stdout, (
        result.stdout,
        result.stderr,
    )
    trace = (tmp_path / "trace").read_text().splitlines()
    assert [line for line in trace if line.startswith("repair:")] == (
        [] if repair is None else [f"repair:{repair}"]
    )
    assert ("mutation" in trace) == (repair is not None and scenario != "stale")
    assert (tmp_path / "snapshot").read_bytes() == original
    expected_live = (
        (tmp_path / "stale").read_bytes()
        if scenario in {"stale", "post-stale"}
        else original
    )
    assert (tmp_path / "live").read_bytes() == expected_live
    assert result.stderr.count(b"tunnel DNS verification deferred") == (
        dns == "deferred"
    )
    if scenario in {"fresh", "shared"}:
        assert not query_log.exists()
        assert "admit-dig" not in trace
    if (response == "outage" and scenario != "post-new-dns") or scenario in {
        "malformed",
        "query-timeout",
    }:
        assert "admit-dig" not in trace
        assert "inventory:shared:unknown" in trace
    if scenario == "native":
        assert "inventory:tunnel:srv-a-verified" in trace
        assert "admit-dig" not in trace
    if repair is not None and status == 0:
        assert trace.count("cleanup-original") == 1 and "migrate" in trace
        assert len([line for line in trace if line.startswith("inventory:")]) == 2
    if status == 3:
        assert "cleanup-original" not in trace
    if scenario in {"post-stale", "post-unsafe-native", "post-shared-fail"}:
        assert trace.count("cleanup-original") == 1
        assert "migrate" not in trace
    if scenario == "migration-failed":
        assert "migrate" in trace and trace.count("cleanup-original") == 1
    if scenario == "migration-unresolved":
        assert "migrate" in trace and "cleanup-original" not in trace
