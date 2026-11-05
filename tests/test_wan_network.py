"""Invocation-local WAN mapping uses native correlation, never address heuristics."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from runtime_awk import awk_program
from test_install import shell, tools
from test_prerequisites import pause_definition

ROOT = Path(__file__).resolve().parents[1]
NETWORK = ROOT / "modules/lib/network.sh"
WORKER = ROOT / "modules/helpers/worker.sh"
__all__ = ["shell", "tools"]


def frame(kind, key, value, good=1):
    lines = "".join(f"D {line}\n" for line in value.splitlines())
    return f"B {kind} {key} {good}\n{lines}E {good}\n"


def interface(name="eth0", address="192.168.0.30", mask="255.255.255.0", up=True):
    return (
        f"{name} Link encap:Ethernet HWaddr 00:00:00:00:00:01\n"
        f"          inet addr:{address} Bcast:192.168.0.255 Mask:{mask}\n"
        f"          {'UP ' if up else ''}BROADCAST RUNNING MULTICAST MTU:1500\n"
    )


def routes(*names):
    return (
        "Kernel IP routing table\nDestination Gateway Genmask Flags Metric Ref Use Iface\n"
        + "".join(f"0.0.0.0 192.168.0.1 0.0.0.0 UG 0 0 0 {name}\n" for name in names)
    )


def values():
    return {
        "sw_mode": "1",
        "wans_dualwan": "wan none",
        "wans_mode": "fo",
        "wan_primary": "0",
        "lan_ifname": "br0",
        "lan_ipaddr": "192.168.1.1",
        "lan_netmask": "255.255.255.0",
        **unit(0),
    }


def unit(number, name="eth0", protocol="dhcp", primary="1", address="192.168.0.30"):
    return {
        f"wan{number}_{key}": value
        for key, value in {
            "enable": "1",
            "type": "wan",
            "proto": protocol,
            "primary": primary,
            "ifname": name,
            "pppoe_ifname": name,
            "ipaddr": address,
            "state_t": "2",
            "sbstate_t": "0",
            "auxstate_t": "0",
        }.items()
    }


def raw(nv=None, interfaces=None, route=None, *, failed=(), cutoff=0):
    nv = values() if nv is None else nv
    result = "".join(frame("nvram", k, v, int(k not in failed)) for k, v in nv.items())
    result += frame(
        "interfaces",
        "-",
        interface() if interfaces is None else interfaces,
        int("interfaces" not in failed),
    )
    result += frame(
        "routes",
        "-",
        routes("eth0") if route is None else route,
        int("routes" not in failed),
    )
    return result + f"LIMIT {cutoff}\n"


def project(
    text,
    *,
    primary="wan:0",
    selectors="wan:0",
    purpose="inventory",
    origin="inventory",
    state="confirmed",
):
    arguments = {
        "purpose": purpose,
        "generation": "12",
        "origin": origin,
        "state": state,
        "primary": primary,
        "selectors": selectors,
    }
    command = [shutil.which("awk")]
    for key, value in arguments.items():
        command.extend(["-v", f"{key}={value}"])
    return subprocess.run(
        [*command, awk_program("wan")],
        input=text,
        text=True,
        capture_output=True,
        check=False,
    )


def report(result):
    assert result.returncode == 0, result.stderr
    lines = [line.split() for line in result.stdout.splitlines()]
    assert lines[-1] == ["END"] and len(result.stdout.encode()) <= 16384
    assert all(len(line) == 13 for line in lines if line[0] == "SOURCE")
    assert all(len(line) == 7 for line in lines if line[0] == "INTERFACE")
    return lines, {line[1]: line for line in lines if line[0] == "SOURCE"}


def test_single_and_stale_alternative_do_not_infer_unit_from_connector():
    nv = values() | unit(1, "eth8")
    nv["wans_dualwan"] = "wan2 none"
    lines, sources = report(project(raw(nv)))
    assert list(sources) == ["wan:0"]
    assert sources["wan:0"][5:9] == ["yes", "yes", "coherent", "yes"]
    assert sources["wan:0"][-2:] == ["private", "no"]
    assert lines[1] == ["PRIMARY", "wan:0", "wan:0", "coherent", "65746830"]


def test_ppp_refresh_and_coherent_firmware_failover():
    nv = values() | unit(0, "ppp8", "pppoe", "0") | unit(1, "ppp9", "pppoe")
    nv.update(wans_dualwan="wan usb", wan_primary="1")
    nv["wan0_state_t"] = "0"
    lines, sources = report(project(raw(nv, interface("ppp9"), routes("ppp9"))))
    assert lines[1] == ["PRIMARY", "wan:0", "wan:1", "coherent", "70707039"]
    assert sources["wan:0"][3] == "70707038"
    assert sources["wan:0"][7] == "offline"
    assert sources["wan:1"][4] == "pppoe"
    nv["wan1_pppoe_ifname"] = "ppp12"
    lines, _ = report(project(raw(nv, interface("ppp12"), routes("ppp12"))))
    assert lines[1][-1] == "7070703132"


def test_usb_uses_physical_dhcp_and_ppp_name_for_other_protocols():
    nv = values()
    nv.update(
        wans_dualwan="usb none",
        wan0_proto="static",
        wan0_ifname="usb0",
        wan0_pppoe_ifname="ppp7",
    )
    lines, sources = report(project(raw(nv, interface("ppp7"), routes("ppp7"))))
    assert sources["wan:0"][3] == "70707037" and lines[1][3] == "coherent"
    nv.update(wan0_proto="dhcp")
    lines, sources = report(project(raw(nv, interface("usb0"), routes("usb0"))))
    assert sources["wan:0"][3] == "75736230" and lines[1][3] == "coherent"


@pytest.mark.parametrize("purpose", ["inventory", "selected"])
@pytest.mark.parametrize("choice", ["unsupported-unit", "modern", "protocol", "manual"])
def test_unproved_saved_relationship_cannot_adopt_classic_failover(purpose, choice):
    nv = values()
    if choice == "unsupported-unit":
        primary = selectors = "wan:2"
    elif choice == "modern":
        nv.update(unit(50, "missing50", primary="0"))
        primary = selectors = "wan:50"
    elif choice == "protocol":
        nv.update(unit(1, "missing1", protocol="v6plus", primary="0"))
        nv["wans_dualwan"] = "wan wan2"
        primary = selectors = "wan:1"
    else:
        primary = "manual:1"
        selectors = "manual:1=" + b"missing".hex()
    lines, sources = report(
        project(raw(nv), primary=primary, selectors=selectors, purpose=purpose)
    )
    assert sources["wan:0"][7] == "coherent"
    assert lines[1][1:3] == [primary, "-"]
    assert lines[1][3] in {"offline", "unsupported"}


@pytest.mark.parametrize(
    "change", ["flags", "global", "global-no-flags", "lb", "routes", "route-primary"]
)
def test_conflicting_primary_and_load_balancing_remain_unknown(change):
    nv = values() | unit(1, "eth1", primary="0")
    nv["wans_dualwan"] = "wan wan2"
    route = routes("eth0")
    if change == "flags":
        nv["wan1_primary"] = "1"
    elif change == "global":
        nv["wan_primary"] = "1"
    elif change == "global-no-flags":
        nv.update(wan_primary="1", wan0_primary="0", wan1_primary="0")
    elif change == "lb":
        nv["wans_mode"] = "lb"
    elif change == "routes":
        route = routes("eth0", "eth1")
    else:
        nv.update(wan0_primary="0", wan1_primary="1", wan_primary="1")
    lines, _ = report(project(raw(nv, route=route)))
    assert lines[0][-2:] == ["unknown", "ambiguous"]
    assert lines[1][2:4] == ["-", "conflict"]


def test_modern_text_type_gate_missing_enable_and_unsupported_protocol():
    nv = values() | unit(50, "vlan50", primary="0") | unit(51, "stale", primary="0")
    nv["wan51_type"] = "1"
    _, sources = report(
        project(raw(nv, interface() + interface("vlan50"), routes("eth0")))
    )
    assert "wan:50" in sources and "wan:51" not in sources
    nv["wan50_enable"] = ""
    nv["wan50_proto"] = "v6plus"
    _, sources = report(project(raw(nv)))
    assert sources["wan:50"][5:8] == ["unknown", "unknown", "unsupported"]


def test_manual_literal_name_requires_firmware_correlation():
    name = "eth$`x"
    encoded = name.encode().hex()
    nv = values() | unit(0, name)
    lines, sources = report(
        project(
            raw(nv, interface(name), routes(name)),
            primary="manual:1",
            selectors=f"manual:1={encoded}",
        )
    )
    assert sources["manual:1"][3] == encoded
    assert sources["manual:1"][6:8] == ["yes", "coherent"]
    assert lines[1][2] == "manual:1"
    nv = values()
    lines, sources = report(
        project(
            raw(nv, interface(name), routes(name)),
            primary="manual:1",
            selectors=f"manual:1={encoded}",
        )
    )
    assert sources["manual:1"][6] == "unknown"
    assert lines[1][2] == "-"


@pytest.mark.parametrize(
    ("address", "classification", "lan_match"),
    [
        ("10.0.0.1", "private", "no"),
        ("172.20.0.1", "private", "no"),
        ("100.128.0.1", "public", "no"),
        ("192.0.2.1", "nonpublic", "no"),
        ("192.0.3.1", "public", "no"),
        ("198.51.101.1", "public", "no"),
        ("203.0.114.1", "public", "no"),
        ("10.1.2.3", "private", "no"),
        ("172.16.0.1", "private", "no"),
        ("172.31.255.254", "private", "no"),
        ("172.32.0.1", "public", "no"),
        ("100.64.0.1", "shared", "no"),
        ("100.127.255.254", "shared", "no"),
        ("169.254.8.1", "linklocal", "no"),
        ("169.253.8.1", "public", "no"),
        ("192.0.0.9", "public", "no"),
        ("192.0.0.10", "public", "no"),
        ("192.0.0.8", "nonpublic", "no"),
        ("198.18.0.1", "nonpublic", "no"),
        ("192.168.14.2", "private", "yes"),
    ],
)
def test_address_classes_and_actual_lan_mask(address, classification, lan_match):
    nv = values() | unit(0, address=address)
    nv.update(lan_ipaddr="192.168.1.1", lan_netmask="255.255.240.0")
    _, sources = report(project(raw(nv, interface(address=address))))
    assert sources["wan:0"][-2:] == [classification, lan_match]


@pytest.mark.parametrize(
    "failure",
    [
        "interfaces",
        "routes",
        "wan0_enable",
        "wan0_state_t",
        "oversize",
        "empty",
        "mask",
    ],
)
def test_failed_or_malformed_observations_never_establish_connected(failure):
    nv = values()
    interfaces = interface()
    failed = (failure,)
    if failure == "oversize":
        interfaces += "X" * 1100
    elif failure == "empty":
        interfaces = ""
    elif failure == "mask":
        nv["lan_netmask"] = "255.0.255.0"
    result = project(raw(nv, interfaces, failed=failed))
    if failure == "oversize":
        assert result.returncode != 0
    else:
        _, sources = report(result)
        if failure == "mask":
            assert sources["wan:0"][-1] == "unknown"
        else:
            assert sources["wan:0"][6] != "yes"


@pytest.mark.parametrize("mask", ["255.0.255.0", ""])
def test_observed_interface_requires_contiguous_netmask_for_coherent_mapping(mask):
    lines, sources = report(project(raw(interfaces=interface(mask=mask))))
    assert lines[0][-2:] == ["partial", "incomplete"]
    assert sources["wan:0"][6:8] == ["unknown", "unresolved"]


def test_zero_local_address_never_establishes_coherent_mapping():
    _, sources = report(
        project(
            raw(values() | unit(0, address="0.0.0.0"), interface(address="0.0.0.0"))
        )
    )
    assert sources["wan:0"][6:8] == ["unknown", "unresolved"]


def test_selected_only_resolves_primary_and_observed_active_alternative():
    nv = values() | unit(1, "eth1", primary="0") | unit(50, "vlan50", primary="0")
    nv["wans_dualwan"] = "wan wan2"
    _, sources = report(
        project(raw(nv), purpose="selected", selectors="wan:0,wan:1,wan:50")
    )
    assert list(sources) == ["wan:0"]


def test_unresolved_retained_preference_does_not_acquire_effective_authority():
    lines, sources = report(
        project(raw(), primary="-", selectors="-", origin="unresolved", state="unknown")
    )
    assert sources["wan:0"][7] == "coherent"
    assert lines[1] == ["PRIMARY", "-", "-", "unresolved", "-"]
    assert lines[0][-2:] == ["unknown", "incomplete"]
    lines, _ = report(
        project(raw(), primary="-", selectors="-", origin="absent", state="unconfirmed")
    )
    assert lines[1] == ["PRIMARY", "-", "wan:0", "coherent", "65746830"]


def test_truncated_raw_and_oversized_inventory_cannot_pass():
    assert project(raw()[:-5]).returncode != 0
    text = raw(interfaces="".join(interface(f"e{i}") for i in range(65)))
    lines, sources = report(project(text))
    assert lines[0][3] == "partial" and sources["wan:0"][6] != "yes"


def test_worker_operands_are_fixed_and_native_process_is_exec(shell, tmp_path):
    native = tmp_path / "native"
    native.write_text('#!/bin/sh\nprintf \'%s %s %s\\n\' "$$" "$1" "$2"\n')
    native.chmod(0o700)
    command = [*shell, str(WORKER), "status-wan-nvram", str(native), str(tmp_path)]
    for key in [
        "wan256_proto",
        "wan01_proto",
        "wan0_password",
        "wan0_proto;echo",
        "show",
    ]:
        assert (
            subprocess.run([*command, key], capture_output=True, check=False).returncode
            == 2
        )
    child = subprocess.Popen(
        [*command, "wan50_type"], stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    output, error = child.communicate(timeout=5)
    assert child.returncode == 0 and not error
    assert output.decode().split() == [str(child.pid), "get", "wan50_type"]


def collect(shell, tmp_path, *, mode="inventory", selectors="wan:0", fault=""):
    context = tmp_path / "context"
    context.mkdir()
    data = tmp_path / "data"
    data.mkdir()
    selected_shell = tmp_path / "sh"
    selected_shell.symlink_to(shutil.which(shell[0]))
    for key, value in values().items():
        (data / key).write_text(value + "\n")
    if fault == "budget":
        for number in range(50, 65):
            for key, value in unit(number, primary="0").items():
                (data / key).write_text(value + "\n")
    (data / "interfaces").write_text(interface())
    (data / "routes").write_text(routes("eth0"))
    if fault == "large":
        (data / "interfaces").write_text("X" * 70000)
    if fault == "aggregate":
        (data / "interfaces").write_text(
            "".join(
                interface(f"e{i}") + "          RX bytes:" + "1" * 400 + "\n"
                for i in range(64)
            )
        )
    script = r"""
. "$1/modules/lib/network.sh"
root=$1 cfmgr_wan_context=$2 data=$3 awk=$4 test_shell=$5 fault=$6
cfmgr_wan_action() {
    printf '%s %s\n' "$1" "${2-}" >>"$cfmgr_wan_context/calls"
    cfmgr_wan_probe_error=$cfmgr_wan_context/error
    : >"$cfmgr_wan_probe_error"
    cfmgr_wan_probe_exit=0
    if [ "$fault" = owned ] && [ "$1" = interfaces ]; then return 3; fi
    if [ "$1" = project ]; then
        shift
        raw=$1; shift
        cfmgr_wan_probe_output=$cfmgr_wan_context/report
        "$test_shell" "$root/modules/helpers/worker.sh" status-wan-project "$awk" "$cfmgr_wan_context" "$root/modules/lib/network.sh" "$raw" "$@" >"$cfmgr_wan_probe_output" 2>"$cfmgr_wan_probe_error" || cfmgr_wan_probe_exit=$?
        case $fault in
        header-only) printf 'CFMGR-WAN 1 12 complete ok\n' >"$cfmgr_wan_probe_output" ;;
        trailing) printf 'unexpected\n' >>"$cfmgr_wan_probe_output" ;;
        unterminated) printf 'CFMGR-WAN 1 12 complete ok\nPRIMARY wan:0 wan:0 coherent 65746830\nEND' >"$cfmgr_wan_probe_output" ;;
        esac
    else
        case $1 in nvram) file=$2 ;; *) file=$1 ;; esac
        cfmgr_wan_probe_output=$data/$file
        if [ ! -f "$cfmgr_wan_probe_output" ]; then cfmgr_wan_probe_output=$cfmgr_wan_context/empty; : >"$cfmgr_wan_probe_output"; fi
        if [ "$fault" = failed ] && [ "$1" = interfaces ]; then cfmgr_wan_probe_exit=1; fi
    fi
}
shift 6
ulimit -S -f 32 || exit 70
before_limit=$(ulimit -S -f)
if [ "$fault" = deadline ]; then
    cfmgr_wan_deadline=4 counter=0
    cfmgr_prerequisites_now() { counter=$((counter+1)); cfmgr_probe_now=$counter; }
fi
cfmgr_wan_collect "$@"; code=$?
[ "$(ulimit -S -f)" = "$before_limit" ] || exit 71
printf 'result %s %s %s\n' "$code" "$cfmgr_wan_status" "$cfmgr_wan_calls"
[ -z "$cfmgr_wan_output" ] || while IFS= read -r line; do printf '%s\n' "$line"; done <"$cfmgr_wan_output"
"""
    return subprocess.run(
        [
            *shell,
            "-c",
            script,
            "wan-test",
            str(ROOT),
            str(context),
            str(data),
            shutil.which("awk"),
            str(selected_shell),
            fault,
            mode,
            "12",
            "inventory",
            "confirmed",
            "wan:0",
            selectors,
        ],
        text=True,
        capture_output=True,
        check=False,
        timeout=10,
        env={**os.environ, "LC_ALL": "C"},
    ), context


@pytest.mark.parametrize("fault", ["", "large", "failed", "owned"])
def test_collect_callback_budget_partial_and_unresolved_ownership(
    shell, tmp_path, fault
):
    result, context = collect(shell, tmp_path, fault=fault)
    assert result.returncode == 0, result.stderr
    header = result.stdout.splitlines()[0].split()
    calls = (context / "calls").read_text().splitlines()
    assert len(calls) <= 48
    if fault == "owned":
        assert header[1] == "3" and not any(
            line.startswith("project ") for line in calls
        )
    else:
        assert header[1] == "0", result.stdout + result.stderr
        assert header[2] == ("partial" if fault else "complete")
        assert calls[-1].startswith("project ")
        assert not any("wan2_" in line for line in calls)
        if fault:
            assert " yes yes coherent " not in result.stdout


def test_collect_selected_does_not_probe_other_retained_members(shell, tmp_path):
    result, context = collect(
        shell, tmp_path, mode="selected", selectors="wan:0,wan:50,wan:51"
    )
    assert "result 0 complete" in result.stdout, result.stdout + result.stderr
    calls = (context / "calls").read_text()
    assert "wan50_" not in calls and "wan51_" not in calls


def test_collect_budget_reserves_projection_and_reports_partial(shell, tmp_path):
    selectors = ",".join(["wan:0", *(f"wan:{number}" for number in range(50, 65))])
    result, context = collect(shell, tmp_path, selectors=selectors, fault="budget")
    assert "result 0 partial 48" in result.stdout, result.stdout + result.stderr
    calls = (context / "calls").read_text().splitlines()
    assert len(calls) == 48 and calls[-1].startswith("project ")


def test_collect_hard_deadline_does_not_restart_for_projection(shell, tmp_path):
    result, context = collect(shell, tmp_path, fault="deadline")
    assert "result 1 unknown" in result.stdout
    assert "project " not in (context / "calls").read_text()


@pytest.mark.parametrize("fault", ["header-only", "trailing", "unterminated"])
def test_collect_rejects_incomplete_or_appended_project_envelope(
    shell, tmp_path, fault
):
    result, _ = collect(shell, tmp_path, fault=fault)
    assert result.returncode == 0 and "result 1 unknown" in result.stdout, (
        result.stdout + result.stderr
    )
    assert "PRIMARY " not in result.stdout


def test_collect_raw_aggregate_uses_own_quota_and_restores_dashboard_limit(
    shell, tmp_path
):
    result, context = collect(shell, tmp_path, fault="aggregate")
    assert result.returncode == 0 and "result 0 complete" in result.stdout, (
        result.stderr
    )
    assert 16384 < (context / "wan.raw").stat().st_size <= 196608


@pytest.mark.parametrize(
    "selectors",
    [
        "wan:00",
        "wan:256",
        "manual:1=2f",
        "wan:0,",
        "wan:0,wan:0",
        "wan:0,manual:1=20",
        "wan:0,manual:33=61",
    ],
)
def test_collect_invalid_api_stops_before_native_observation(
    shell, tmp_path, selectors
):
    result, context = collect(shell, tmp_path, selectors=selectors)
    assert result.returncode == 0 and "result 2 unknown" in result.stdout
    assert not (context / "calls").exists()


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="native task ownership and timeout require Linux proc",
)
def test_hung_native_observation_is_direct_owned_child_and_reaped(
    shell, tools, tmp_path
):
    context = tmp_path / "context"
    context.mkdir(mode=0o700)
    native = tmp_path / "ifconfig"
    native.write_text(
        f'#!{tools["sh"]}\nprintf "%s\\n" "$$" >"{context}/native.pid"\nexec {tools["sleep"]} 30\n'
    )
    native.chmod(0o700)
    script = (
        r"""
root=$1 context=$2 selected_tool=$3 selected_sh=$4 selected_env=$5 selected_awk=$6 selected_sleep=$7 selected_wc=$8
. "$root/modules/lib/execution.sh"
cfmgr_status_attachment_ok() { [ -d "$context" ]; }
set -f
"""
        + pause_definition(shell)
        + r"""
cfmgr_prerequisites_now || exit 10
cfmgr_status_deadline=$((cfmgr_probe_now+2))
if cfmgr_prerequisites_run status-wan-interfaces "$context" "$selected_sh" "$root/modules/helpers/worker.sh" "$selected_env" "$selected_awk" "$selected_sleep" "$selected_wc" "$selected_tool"; then code=0; else code=$?; fi
IFS= read -r native_pid <"$context/native.pid" || exit 11
[ "$native_pid" = "$cfmgr_probe_pid" ] || exit 12
[ "$cfmgr_probe_status:$cfmgr_probe_reason:$code" = reaped:deadline:1 ] || exit 13
[ ! -e "/proc/$native_pid" ] || exit 14
"""
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "wan-hung",
            str(ROOT),
            str(context),
            str(native),
            *(tools[key] for key in ("sh", "env", "awk", "sleep", "wc")),
        ],
        capture_output=True,
        check=False,
        timeout=6,
    )
    assert result.returncode == 0, result.stderr
