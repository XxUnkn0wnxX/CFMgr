"""Native-only status projection and actual installed choice0 consumer.

No live router/provider input. Host supervision adapters are labelled; one Linux
case retains the actual bounded supervisor and fixed executable probe body.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from entry_package_fixture import finish_package
from test_config_observation import commands, config
from test_dependency_reinstall import entry_run, installed_entry
from test_install import shell, tools
from test_prerequisites import pause_definition

ROOT = Path(__file__).resolve().parents[1]
BOOT = "12345678-1234-1234-1234-123456789abc"
NOW = 1_700_000_000
__all__ = ["commands", "config", "installed_entry", "shell", "tools"]


def project(commands, tmp_path, data, *, clock="1", boot=BOOT, wan="0"):
    payload = json.dumps(data).encode() if isinstance(data, dict) else data
    return subprocess.run(
        [
            *commands[1],
            "-v",
            f"cfmgr_json_size={len(payload)}",
            "-v",
            "cfmgr_json_mode=tree",
            "-f",
            str(ROOT / "modules/lib/json.awk"),
            "-f",
            str(ROOT / "modules/lib/status.awk"),
        ],
        input=payload,
        capture_output=True,
        check=False,
        timeout=3,
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_STATUS_MODE": "render",
            "CFMGR_STATUS_NOW": str(NOW),
            "CFMGR_STATUS_BOOT": boot,
            "CFMGR_STATUS_WAN": wan,
            "CFMGR_STATUS_CLOCK": clock,
            "CFMGR_STATUS_REPOSITORY": "https://github.com/example/CFMgr",
            "CFMGR_STATUS_BRANCH": "develop",
        },
    )


def record():
    return {
        "schema": 1,
        "generation": 1,
        "ipv4": {"result": "verified", "value": "8.8.8.8", "at": NOW - 60},
        "ipv6": {"result": "removed", "value": None, "at": NOW - 90},
        "latest": {"result": "partial", "reason": "auth", "at": NOW - 50},
        "observation": {
            "origin": "runtime",
            "boot_id": BOOT,
            "at": NOW - 30,
            "running": True,
            "connection": "waiting",
            "logging": "unavailable",
            "cleanup": True,
            "installed_version": "2026.1.0",
        },
    }


def test_typed_history_state_separation_and_privacy(commands, config, tmp_path):
    value = json.loads(config)
    value["ddns"].update(configured=True, enabled=False, credentials="TOP_SECRET")
    value["cloudflared"].update(
        configured=True, enabled=False, installed=True, maintenance_enabled=True
    )
    for name in ("ddns", "ip_sync", "cloudflared"):
        value["history"][name] = {"status": record(), "private_token": "TOP_SECRET"}
        value["history"][name]["status"]["events"] = [
            {"at": NOW - i, "result": "pending", "reason": "throttle"} for i in range(8)
        ]
    value["history"]["network"] = {
        "status": {
            "schema": 1,
            "generation": 1,
            "boot_id": BOOT,
            "selected_wan": "0",
            "ipv4": {"value": "9.9.9.9", "at": NOW - 20, "source": "discovery"},
            "ipv6": {
                "value": "2606:4700::1111",
                "at": NOW - 20,
                "source": "interface",
                "eligible": True,
            },
        }
    }
    result = project(commands, tmp_path, value)
    assert result.returncode == 0, result.stderr
    out = result.stdout.decode()
    assert "configured=On; enabled=Off" in out
    assert "installed=On; maintenance=On" in out
    assert "Last verified IPv4 (historical): verified 8.8.8.8" in out
    assert "Last verified IPv6 (historical): removed; at" in out
    assert "Last outcome (historical): partial; auth" in out
    assert "Observed running=On; connection=waiting" in out
    assert "recorded cleanup required" in out
    assert "Recorded public IPv4 (historical): 9.9.9.9" in out
    assert "Recorded eligible IPv6 (historical): 2606:4700::1111" in out
    assert out.count("Recent ") == 5
    assert "TOP_SECRET" not in out and "\x1b" not in out


@pytest.mark.parametrize(
    "change", ["generation", "boot", "restored", "future", "clock"]
)
def test_stale_or_untrusted_current_claims_keep_historical_outcome(
    commands, config, tmp_path, change
):
    value = json.loads(config)
    current = record()
    if change == "generation":
        current["generation"] = 2
    if change == "boot":
        current["observation"]["boot_id"] = "87654321-4321-4321-4321-cba987654321"
    if change == "restored":
        current["observation"]["origin"] = "restored"
    if change == "future":
        current["observation"]["at"] = NOW + 1
    value["history"]["ddns"] = {"status": current}
    result = project(commands, tmp_path, value, clock="0" if change == "clock" else "1")
    assert result.returncode == 0
    assert b"Last verified IPv4 (historical): verified" in result.stdout
    assert b"Observed running=" not in result.stdout
    assert b"stale/restored/untrusted observation" in result.stdout
    assert b"recorded cleanup required" in result.stdout
    if change == "clock":
        assert b"time/age Unknown" in result.stdout


def test_partial_invalid_and_terminal_unsafe_config_sections(
    commands, config, tmp_path
):
    value = json.loads(config)
    value.pop("manager")
    value["ddns"].update(configured=False, enabled=True)
    value["ip_sync"] = {"configured": False, "enabled": False}
    value["history"]["ddns"] = {"status": record()}
    value["history"]["ddns"]["status"]["latest"]["reason"] = "auth\u001b[2JSECRET"
    result = project(commands, tmp_path, value)
    assert result.returncode == 0
    assert b"invalid enabled-without-configured" in result.stdout
    assert b"IP-Sync: configured=Off; enabled=Off" in result.stdout
    assert b"invalid typed record" in result.stdout
    assert b"SECRET" not in result.stdout and b"\x1b" not in result.stdout
    for data in (
        b"{broken",
        b'{"schema":9,"generation":1}',
        b'{"schema":1,' + b" " * 65536 + b"}",
    ):
        failed = project(commands, tmp_path, data)
        assert failed.returncode != 0 and failed.stdout == b""


@pytest.mark.parametrize(
    ("check", "auto", "developer", "expected", "suppression"),
    [
        (
            True,
            False,
            False,
            "Manager updates: saved Check=On; saved Auto=Off; effective Check=On; effective Auto=Off",
            False,
        ),
        (
            False,
            True,
            False,
            "Manager updates: saved Check=Off; saved Auto=On; effective Check=Off; effective Auto=Off",
            False,
        ),
        (
            True,
            True,
            True,
            "Manager updates: saved Check=On; saved Auto=On; effective Check=Off; effective Auto=Off",
            True,
        ),
        (
            "true",
            True,
            False,
            "Manager updates: saved Check=Unknown; saved Auto=On; effective Check=Unknown; effective Auto=Unknown",
            False,
        ),
        (
            True,
            True,
            "false",
            "Manager updates: saved Check=On; saved Auto=On; effective Check=Unknown; effective Auto=Unknown",
            False,
        ),
    ],
)
def test_manager_status_distinguishes_saved_and_effective_updates(
    commands, config, tmp_path, check, auto, developer, expected, suppression
):
    value = json.loads(config)
    value["manager"].update(
        check_updates=check,
        auto_update=auto,
        developer=developer,
    )
    result = project(commands, tmp_path, value)
    assert result.returncode == 0
    output = result.stdout.decode()
    assert expected in output
    note = "developer mode suppresses manager updates; saved preferences are retained"
    assert (note in output) is suppression


@pytest.mark.parametrize(
    ("ip", "classification"),
    [
        ("10.0.0.1", "Private"),
        ("172.20.0.1", "Private"),
        ("100.64.0.1", "Shared-CGNAT"),
        ("100.128.0.1", "Public"),
        ("192.0.2.1", "Non-public"),
        ("192.0.3.1", "Public"),
        ("198.51.101.1", "Public"),
        ("203.0.114.1", "Public"),
    ],
)
def test_native_wan_ipv4_classification(commands, tmp_path, ip, classification):
    raw = tmp_path / "native.out"
    raw.write_text(ip + "\n")
    result = subprocess.run(
        [
            *commands[1],
            "-f",
            str(ROOT / "modules/lib/status_native.awk"),
            "nvram",
            str(raw),
            "wan0_ipaddr",
        ],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.stdout == f"{ip} ({classification})\n".encode()


@pytest.mark.parametrize(
    "ip", ["fd00::1", "fe80::1", "2001:db8::1", "2001:4860::1:", "2606:4700::1111/64"]
)
def test_ineligible_or_malformed_ipv6_is_never_public_evidence(
    commands, config, tmp_path, ip
):
    value = json.loads(config)
    value["history"]["network"] = {
        "status": {
            "schema": 1,
            "generation": 1,
            "ipv6": {"value": ip, "at": NOW, "source": "interface", "eligible": True},
        }
    }
    result = project(commands, tmp_path, value)
    assert b"Recorded eligible IPv6: Unavailable" in result.stdout
    assert ip.encode() not in result.stdout


@pytest.fixture
def status_fixture(tmp_path, tools, shell):
    source = tmp_path / "source"
    (source / "modules/lib").mkdir(parents=True)
    (source / "modules/helpers").mkdir()
    for relative in (
        "modules/status.sh",
        "modules/lib/json.awk",
        "modules/lib/status.awk",
        "modules/lib/status_native.awk",
        "modules/lib/mountinfo.awk",
        "modules/helpers/probe.sh",
    ):
        original = (ROOT / relative).read_text()
        adapted = original
        if relative == "modules/status.sh":
            adapted = adapted.replace("$3!=0", f"$3!={os.getuid()}")
        if relative == "modules/lib/status_native.awk":
            adapted = adapted.replace('a[4]!="0"', f'a[4]!="{os.getuid()}"')
        if relative == "modules/helpers/probe.sh" and sys.platform == "darwin":
            adapted = adapted.replace("/proc/self/fd/8", "/dev/fd/8").replace(
                '"$1" -ef /dev/fd/8', "-f /dev/fd/8"
            )
        (source / relative).write_text(adapted)
        (source / relative).chmod((ROOT / relative).stat().st_mode & 0o777)
    assert os.access(source / "modules/helpers/probe.sh", os.X_OK)
    proc = tmp_path / "proc"
    (proc / "sys/kernel/random").mkdir(parents=True)
    (proc / "self").mkdir()
    (proc / "uptime").write_text("1234.56 999.00\n")
    (proc / "loadavg").write_text("0.10 0.20 0.30 1/10 50\n")
    (proc / "meminfo").write_text("MemTotal: 1024 kB\nMemAvailable: 640 kB\n")
    (proc / "sys/kernel/random/boot_id").write_text(BOOT + "\n")
    (proc / "self/mountinfo").write_text(
        "1 9 0:1 / / rw - tmpfs tmpfs rw\n2 1 0:2 / /jffs rw - jffs2 jffs rw\n3 1 8:1 / /mnt/usb rw - ext4 /dev/sda1 rw\n"
    )
    fake = tmp_path / "native"
    fake.mkdir()
    bodies = {
        "nvram": "case $2 in productid) echo GT-AX11000 ;; firmver) echo 3004 ;; buildno) echo 388 ;; extendno) echo 8_4 ;; ntp_ready | wan0_primary) echo 1 ;; wan1_primary) echo 0 ;; wan0_proto) echo dhcp ;; wan0_ifname) echo eth0 ;; wan0_ipaddr) echo 100.64.1.2 ;; *) exit 1 ;; esac\n",
        "date": f"echo {NOW}\n",
        "df": "printf '%s\\n' 'Filesystem 1K-blocks Used Available Use% Mounted on' '/dev/fixture 1024 100 924 10% /opt'\n",
        "readlink": "case $2 in /jffs) echo /jffs ;; /opt) echo /mnt/usb/entware ;; *) exit 1 ;; esac\n",
    }
    for name, body in bodies.items():
        (fake / name).write_text("#!/bin/sh\n" + body)
        (fake / name).chmod(0o700)
    # Caller-only host path/ownership forwarding, actual status/probe/parser bodies.
    probe = (
        (source / "modules/helpers/probe.sh")
        .read_text()
        .replace("/proc/self/mountinfo", str(proc / "self/mountinfo"))
    )
    (source / "modules/helpers/probe.sh").write_text(probe)
    return source, proc, fake


STATUS_CONSUMER = r"""
. "$1/modules/status.sh"
base=$2 cfmgr_source=$1 scenario=$3
cfmgr_status_sh=$4 cfmgr_status_awk=$5
CFMGR_VERSION=0.1.0 CFMGR_REPOSITORY=https://github.com/example/CFMgr CFMGR_BRANCH=develop
cfmgr_prerequisites_now() { cfmgr_probe_now=${fake_now:-100}; }
cfmgr_status_prepare() {
    cfmgr_status_context=$base/ram
    mkdir -m 700 "$cfmgr_status_context" || return 1
    exec 9<"$cfmgr_status_context"
    cfmgr_status_interrupted=0 cfmgr_status_budget_exhausted=0 cfmgr_probe_pid=''
    cfmgr_status_deadline=110
}
cfmgr_status_attachment_ok() { [ -d "$cfmgr_status_context" ] && [ ! -L "$cfmgr_status_context" ]; }
cfmgr_prerequisites_run() {
    mode=$1 context=$2 helper=$4 selected_tool=$9
    shift 9
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0}+1))
    cfmgr_probe_stdout=$context/$mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$context/$mode.$cfmgr_probe_serial.err
    cfmgr_probe_status=reaped cfmgr_probe_pid='' cfmgr_probe_reason=''
    printf '%s\n' "$mode" >>"$base/routes"
    case $mode in
    status-date) selected_tool=$base/native/date ;;
    status-native) selected_tool=$cfmgr_status_awk; set -- "$1" "$base/proc" ;;
    status-fields | status-config | status-mount) selected_tool=$cfmgr_status_awk ;;
    status-realpath) selected_tool=$base/native/readlink ;;
    status-space) selected_tool=$base/native/df ;;
    status-nvram)
        selected_tool=$base/native/nvram
        if [ "$scenario" = unresolved ]; then cfmgr_probe_status=unresolved cfmgr_probe_pid=fixture; return 3; fi
        [ "$scenario" != budget ] || fake_now=111
        ;;
    esac
    LC_ALL=C "$cfmgr_status_sh" "$helper" "$mode" "$selected_tool" "$context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
    return 0
}
if cfmgr_status_native; then code=0; else code=$?; fi
printf 'status-code=%s\n' "$code"
"""


@pytest.mark.parametrize(
    "scenario",
    [
        "normal",
        "corrupt",
        "symlink",
        "fifo",
        "oversized",
        "budget",
        "unresolved",
        "save-guards",
    ],
)
def test_real_status_consumer_native_resources_and_failure_survival(
    status_fixture, config, tools, shell, tmp_path, scenario
):
    source, _proc, _fake = status_fixture
    candidate = source / "config"
    candidate.write_bytes(config)
    candidate.chmod(0o600)
    (source / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (source / "setup-state").chmod(0o600)
    if scenario == "corrupt":
        candidate.write_bytes(b"{broken\n")
    if scenario == "oversized":
        candidate.write_bytes(b" " * 65537)
    if scenario in {"symlink", "fifo"}:
        candidate.unlink()
        if scenario == "symlink":
            candidate.symlink_to(source / "setup-state")
        else:
            os.mkfifo(candidate, 0o600)
    if scenario == "save-guards":
        (source / ".config-save.preparing").write_text("in progress\n")
        (source / ".config-save").mkdir()
        (source / ".config-save.retired").symlink_to(source / "missing-target")
    before = (source / "setup-state").read_bytes()
    result = subprocess.run(
        [
            *shell,
            "-c",
            STATUS_CONSUMER,
            "status-consumer",
            str(source),
            str(tmp_path),
            scenario,
            tools["sh"],
            tools["awk"],
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    out = result.stdout.decode()
    assert "uptime: 1234s" in out and "384/1024 KiB used" in out
    if scenario == "normal":
        assert (
            "Selected WAN: 0" in out
            and "eth0" in out
            and "100.64.1.2 (Shared-CGNAT)" in out
        )
        assert "/opt mount: ext4 mounted" in out and "924 KiB available" in out
        assert (
            "Last verified IPv4: Never" in out and "configured=Off; enabled=Off" in out
        )
    if scenario in {"corrupt", "symlink", "fifo", "oversized"}:
        assert "Configuration: Unavailable" in out
    if scenario == "budget":
        assert "probe budget exhausted" in out
    if scenario == "save-guards":
        warning = (
            "Issue: pending configuration Save/recovery guard; use explicit recovery"
        )
        assert out.count(warning) == 1
        assert (source / ".config-save.preparing").read_text() == "in progress\n"
        assert (source / ".config-save").is_dir()
        assert (source / ".config-save.retired").is_symlink()
    assert (
        "status-code=3" in out if scenario == "unresolved" else "status-code=0" in out
    )
    assert (tmp_path / "ram").exists() == (scenario == "unresolved")
    assert (source / "setup-state").read_bytes() == before
    modes = (tmp_path / "routes").read_text().splitlines()
    assert all(mode.startswith("status-") for mode in modes)
    assert "TOP_SECRET" not in out


def test_installed_choice_zero_returns_without_operational_preparation(
    installed_entry, status_fixture, config, tools, shell, tmp_path
):
    entry, marker = installed_entry
    support = entry.parent.parent / "addons/CFMgr.d"
    source, _, _ = status_fixture
    for relative in (
        "modules/status.sh",
        "modules/lib/json.awk",
        "modules/lib/status.awk",
        "modules/lib/status_native.awk",
        "modules/lib/mountinfo.awk",
        "modules/helpers/probe.sh",
    ):
        shutil.copyfile(source / relative, support / relative)
    data = support / "config"
    data.write_bytes(config)
    data.chmod(0o600)
    (support / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (support / "setup-state").chmod(0o600)
    functions = STATUS_CONSUMER[
        STATUS_CONSUMER.index("cfmgr_prerequisites_now()") : STATUS_CONSUMER.index(
            "if cfmgr_status_native;"
        )
    ]
    with (support / "modules/status.sh").open("a") as destination:
        destination.write(
            "\nbase="
            + shlex.quote(str(tmp_path))
            + "\nscenario=normal\ncfmgr_status_sh="
            + shlex.quote(tools["sh"])
            + "\ncfmgr_status_awk="
            + shlex.quote(tools["awk"])
            + "\n"
            + functions
        )
    finish_package(entry, support, tools, shell)
    original = data.read_bytes()
    result = entry_run(shell, entry, [], b"0\nao\ne\ne\n", terminal=True, timeout=10)
    assert result.returncode == 0, result.stderr
    assert b"CFMgr 0.1.0 - local status" in result.stdout
    assert result.stdout.count(b"0 Check status") >= 2
    assert b"shared dependencies verified" not in result.stdout
    assert (
        not marker.exists()
        and data.read_bytes() == original
        and not (tmp_path / "ram").exists()
    )
    assert all(
        mode.startswith("status-")
        for mode in (tmp_path / "routes").read_text().splitlines()
    )


@pytest.mark.parametrize("scenario", ["normal", "budget"])
def test_linux_status_real_supervisor_and_aggregate_budget(
    status_fixture, config, tools, shell, tmp_path, scenario
):
    if sys.platform != "linux":
        pytest.skip("real native status ownership requires Linux proc/FD semantics")
    source, _, fake = status_fixture
    (source / "config").write_bytes(config)
    (source / "config").chmod(0o600)
    (source / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (source / "setup-state").chmod(0o600)
    if scenario == "budget":
        (fake / "nvram").write_text(
            "#!/bin/sh\nprintf '%s\\n' \"$$\" >>"
            + shlex.quote(str(tmp_path / "owned-probes"))
            + "\nexec /bin/sleep 3\n"
        )
    # Exact status consumer body, with literal shell/default path forwarders only.
    original = (source / "modules/status.sh").read_text()
    adapted = original.replace("cfmgr_status_run() {", "cfmgr_status_actual_run() {", 1)
    adapted = adapted.replace("/bin/sh \\\n", shlex.quote(tools["sh"]) + " \\\n", 1)
    assert (
        adapted.replace(shlex.quote(tools["sh"]) + " \\\n", "/bin/sh \\\n", 1).replace(
            "cfmgr_status_actual_run() {", "cfmgr_status_run() {", 1
        )
        == original
    )
    alias = source / "status-supervised.sh"
    alias.write_text(adapted)
    driver = r"""
. "$1/modules/lib/prerequisites.sh"
. "$2/status-supervised.sh"
cfmgr_source=$2 base=$3
CFMGR_VERSION=0.1.0 CFMGR_REPOSITORY=https://github.com/example/CFMgr CFMGR_BRANCH=develop
cfmgr_status_prepare() {
    cfmgr_status_context=$base/ram
    mkdir -m 700 "$cfmgr_status_context" || return 1
    exec 9<"$cfmgr_status_context"
    cfmgr_status_interrupted=0 cfmgr_status_budget_exhausted=0 cfmgr_probe_pid=''
    cfmgr_prerequisites_now || return 1
    cfmgr_status_deadline=$((cfmgr_probe_now + 10))
}
cfmgr_status_run() {
    selected_mode=$1 selected_tool=$2; shift 2
    printf '%s\n' "$selected_mode" >>"$base/routes"
    case $selected_mode in
    status-date) selected_tool=$base/native/date ;;
    status-nvram) selected_tool=$base/native/nvram ;;
    status-space) selected_tool=$base/native/df ;;
    status-realpath) selected_tool=$base/native/readlink ;;
    status-native) set -- "$1" "$base/proc" ;;
    esac
    cfmgr_status_actual_run "$selected_mode" "$selected_tool" "$@"
}
cfmgr_status_native
"""
    driver = driver.replace(
        "cfmgr_status_native\n", pause_definition(shell) + "\ncfmgr_status_native\n", 1
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            driver,
            "status-real-supervision",
            str(ROOT),
            str(source),
            str(tmp_path),
        ],
        capture_output=True,
        check=False,
        timeout=18,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"uptime: 1234s" in result.stdout
    assert not (tmp_path / "ram").exists()
    if scenario == "normal":
        assert b"Last verified IPv4: Never" in result.stdout
    else:
        assert b"probe budget exhausted" in result.stdout
        for pid in (tmp_path / "owned-probes").read_text().splitlines():
            assert not Path(f"/proc/{pid}").exists(), "bounded collector was orphaned"
