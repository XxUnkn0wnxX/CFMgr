"""Supplied selected-WAN IPv4 policy reports, independent of collection."""

from __future__ import annotations

import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_ip import NativeShell, native_shell, run_shell

SOURCE = Path(__file__).resolve().parents[1] / "modules/lib/wan.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V44", evidence="host")]


@pytest.fixture
def wan_shell(native_shell: NativeShell) -> NativeShell:
    router, _ = native_shell
    router.write("work/wan.sh", SOURCE.read_text(encoding="utf-8"))
    return native_shell


def expected_report(kind: str, fields: tuple[str, ...]) -> str:
    body = "\t".join((f"wan4-{kind}", "1", *fields)) + "\n"
    return f"{body}end\t{len(body.encode('ascii'))}\n"


def shell_call(function: str, args: tuple[str, ...]) -> str:
    return " ".join(shlex.quote(value) for value in (function, *args))


def run_report_cases(
    native_shell: NativeShell,
    function: str,
    cases: list[tuple[tuple[str, ...], tuple[str, ...]]],
) -> str:
    calls = "\n".join(f"{shell_call(function, args)} || exit 70" for args, _ in cases)
    result = run_shell(
        native_shell,
        '. "$CFMGR_TEST_ROOT/work/ip.sh"\n. "$CFMGR_TEST_ROOT/work/wan.sh"\n' + calls + "\n",
        [],
    )
    assert result.returncode == 0, result
    assert result.stderr == ""
    return result.stdout


@pytest.mark.usefixtures(native_shell.__name__)
def test_selection_decision_table_and_exact_framing(wan_shell: NativeShell) -> None:
    cases = [
        (("off", "1", "0", "-", "-", "-", "-", "-"), ("selected", "0", "primary")),
        (("fo", "0", "1", "-", "-", "-", "-", "-"), ("selected", "1", "primary")),
        (("fb", "1", "0", "-", "-", "-", "-", "-"), ("selected", "0", "primary")),
        (("off", "0", "0", "-", "-", "-", "-", "-"), ("unknown", "-", "primary-ambiguous")),
        (("fo", "1", "1", "-", "-", "-", "-", "-"), ("unknown", "-", "primary-ambiguous")),
        (("fb", "-", "1", "-", "-", "-", "-", "-"), ("unknown", "-", "primary-unavailable")),
        (("off", "0", "-", "-", "-", "-", "-", "-"), ("unknown", "-", "primary-unavailable")),
        (("-", "1", "0", "-", "-", "-", "-", "-"), ("unknown", "-", "mode-unavailable")),
        (("lb", "-", "-", "0", "-", "-", "-", "-"), ("selected", "0", "ddns-unit")),
        (("lb", "-", "-", "1", "0", "0", "-", "-"), ("selected", "1", "ddns-unit")),
        (
            ("lb", "-", "-", "-", "1", "1", "8.8.8.8", "1.1.1.1"),
            ("unknown", "-", "selector-unavailable"),
        ),
        (("lb", "-", "-", "-1", "-", "-", "-", "-"), ("unknown", "-", "connection-unavailable")),
        (
            ("lb", "-", "-", "-1", "1", "-", "8.8.8.8", "-"),
            ("unknown", "-", "connection-unavailable"),
        ),
        (("lb", "-", "-", "-1", "1", "0", "-", "-"), ("unknown", "-", "address-unavailable")),
        (("lb", "-", "-", "-1", "1", "1", "10.0.0.2", "1.1.1.1"), ("selected", "1", "auto-global")),
        (("lb", "-", "-", "-1", "1", "1", "8.8.8.8", "1.1.1.1"), ("selected", "0", "auto-global")),
        (
            ("lb", "-", "-", "-1", "1", "1", "192.0.2.1", "8.8.8.8"),
            ("selected", "1", "auto-global"),
        ),
        (
            ("lb", "-", "-", "-1", "1", "1", "10.0.0.2", "100.64.0.2"),
            ("selected", "0", "auto-connected"),
        ),
        (
            ("lb", "-", "-", "-1", "0", "1", "-", "100.64.0.2"),
            ("selected", "1", "auto-connected"),
        ),
        (("lb", "-", "-", "-1", "0", "1", "-", "-"), ("unknown", "-", "address-unavailable")),
        (("lb", "-", "-", "-1", "0", "0", "-", "-"), ("unknown", "-", "no-connected-wan")),
    ]
    expected = "".join(expected_report("selection", fields) for _, fields in cases)
    assert run_report_cases(wan_shell, "cfmgr_wan4_selection_report", cases) == expected


def test_source_decision_table_and_exact_framing(wan_shell: NativeShell) -> None:
    cases = [
        (("0", "-", "-", "-", "-"), ("inactive", "-", "-", "administratively-disabled")),
        (("-", "dhcp", "eth0", "ppp0", "8.8.8.8"), ("unknown", "-", "-", "enable-unavailable")),
        (("1", "-", "eth0", "ppp0", "8.8.8.8"), ("unknown", "-", "-", "protocol-unavailable")),
        (
            ("1", "disabled", "eth0", "ppp0", "8.8.8.8"),
            ("unknown", "-", "-", "protocol-unavailable"),
        ),
        (
            ("1", "unsupported", "eth0", "ppp0", "8.8.8.8"),
            ("unknown", "-", "-", "protocol-unavailable"),
        ),
        (
            ("1", "pppoe", "eth0", "-", "8.8.8.8"),
            ("unknown", "-", "-", "interface-unavailable"),
        ),
        (("1", "dhcp", "-", "ppp0", "8.8.8.8"), ("unknown", "-", "-", "interface-unavailable")),
        (("1", "static", "eth0", "ppp0", "-"), ("unknown", "-", "-", "address-unavailable")),
        (
            ("1", "pppoe", "eth0", "ppp0", "8.8.8.8"),
            ("candidate", "ppp0", "8.8.8.8", "native-address"),
        ),
        (
            ("1", "pptp", "eth0", "ppp0", "10.0.0.4"),
            ("candidate", "ppp0", "10.0.0.4", "native-address"),
        ),
        (
            ("1", "l2tp", "eth0", "ppp0", "100.64.0.4"),
            ("candidate", "ppp0", "100.64.0.4", "native-address"),
        ),
        (
            ("1", "dhcp", "eth0", "ppp0", "192.168.1.2"),
            ("candidate", "eth0", "192.168.1.2", "native-address"),
        ),
        (
            ("1", "static", "eth0", "ppp0", "100.64.0.2"),
            ("candidate", "eth0", "100.64.0.2", "native-address"),
        ),
        (
            ("1", "static", "abcdefghijklmno", "ppp0", "8.8.8.8"),
            ("candidate", "abcdefghijklmno", "8.8.8.8", "native-address"),
        ),
        (
            ("0", "dhcp", "eth0", "ppp0", "8.8.8.8"),
            ("inactive", "-", "-", "administratively-disabled"),
        ),
        (("1", "dhcp", "eth0", "ppp0", "0.0.0.0"), ("unknown", "-", "-", "address-unavailable")),
        (("1", "dhcp", "eth0", "ppp0", "127.0.0.1"), ("unknown", "-", "-", "address-nonpublic")),
    ]
    expected = "".join(expected_report("source", fields) for _, fields in cases)
    assert run_report_cases(wan_shell, "cfmgr_wan4_source_report", cases) == expected


def test_every_operand_is_validated_even_on_ignored_branches(wan_shell: NativeShell) -> None:
    selection = ("off", "1", "0", "-", "-", "-", "-", "-")
    bad_selection = ["single", "2", "2", "2", "2", "2", "01.2.3.4", "1.2.3.999"]
    source = ("0", "-", "-", "-", "-")
    bad_source = ["2", "unsupported-protocol", "bad iface", "bad/iface", "01.2.3.4"]
    commands = []
    for function, rows, bad_values in (
        ("cfmgr_wan4_selection_report", [selection] * 8, bad_selection),
        ("cfmgr_wan4_source_report", [source] * 5, bad_source),
    ):
        for index, invalid in enumerate(bad_values):
            args = list(rows[index])
            args[index] = invalid
            commands.append(
                f"capture=$({shell_call(function, tuple(args))}); status=$?; "
                '[ "$status" -eq 1 ] && [ -z "$capture" ] || exit 71'
            )
    for function, args in (
        ("cfmgr_wan4_selection_report", ("off", "1", "0", "-", "-", "-", "-")),
        ("cfmgr_wan4_selection_report", ("off", "1", "0", "-", "-", "-", "-", "-", "extra")),
        ("cfmgr_wan4_source_report", ("0", "-", "-", "-")),
        ("cfmgr_wan4_source_report", ("0", "-", "-", "-", "-", "extra")),
    ):
        commands.append(
            f"capture=$({shell_call(function, args)}); status=$?; "
            '[ "$status" -eq 1 ] && [ -z "$capture" ] || exit 72'
        )
    for invalid in ("", ".", "..", "-eth0", "abcdefghijklmnop"):
        command = shell_call("cfmgr_wan4_source_report", ("0", "dhcp", invalid, "-", "-"))
        commands.append(
            f'capture=$({command}); status=$?; [ "$status" -eq 1 ] && [ -z "$capture" ] || exit 73'
        )
    result = run_shell(
        wan_shell,
        '. "$CFMGR_TEST_ROOT/work/ip.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/wan.sh"\n' + "\n".join(commands) + "\n",
        [],
    )
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


def test_formatter_failure_is_reported_and_caller_state_is_preserved(
    wan_shell: NativeShell,
) -> None:
    result = run_shell(
        wan_shell,
        """set -efu
set -- first 'two words'
IFS='|'
umask 027
export CFMGR_WAN_SENTINEL='original value'
_cfmgr_wan4_mode=caller_mode
_cfmgr_wan4_primary=caller_primary
_cfmgr_wan4_body=caller_body
_cfmgr_wan4_report=caller_report
_cfmgr_wan4_source=caller_source
_cfmgr_wan4_state=caller_state
_cfmgr_wan4_unit=caller_unit
_cfmgr_wan4_reason=caller_reason
_cfmgr_wan4_scope0=caller_scope0
_cfmgr_wan4_scope1=caller_scope1
_cfmgr_wan4_row=caller_row
_cfmgr_wan4_body_bytes=caller_body_bytes
_cfmgr_wan4_interface=caller_interface
_cfmgr_wan4_address=caller_address
_cfmgr_wan4_selected_interface=caller_selected_interface
_cfmgr_wan4_ifname=caller_ifname
_cfmgr_wan4_scope=caller_scope
trap ':' INT TERM
before_options=$-
before_umask=$(umask)
before_exports=$(export -p)
before_traps=$(trap)
. "$CFMGR_TEST_ROOT/work/ip.sh"
. "$CFMGR_TEST_ROOT/work/wan.sh"
cfmgr_wan4_selection_report off 1 0 - - - - - >/dev/null || exit 72
cfmgr_wan4_source_report 1 dhcp eth0 ppp0 8.8.8.8 >/dev/null || exit 73
[ "$#" -eq 2 ] && [ "$1" = first ] && [ "$2" = 'two words' ] || exit 74
[ "$before_options" = "$-" ] && [ "$before_umask" = "$(umask)" ] || exit 75
[ "$before_exports" = "$(export -p)" ] && [ "$before_traps" = "$(trap)" ] || exit 76
[ "$IFS" = '|' ] && [ "$CFMGR_WAN_SENTINEL" = 'original value' ] || exit 77
[ "$_cfmgr_wan4_mode" = caller_mode ] && [ "$_cfmgr_wan4_primary" = caller_primary ] || exit 78
[ "$_cfmgr_wan4_body" = caller_body ] && [ "$_cfmgr_wan4_report" = caller_report ] || exit 79
[ "$_cfmgr_wan4_source" = caller_source ] || exit 80
[ "$_cfmgr_wan4_state" = caller_state ] && [ "$_cfmgr_wan4_unit" = caller_unit ] || exit 81
[ "$_cfmgr_wan4_reason" = caller_reason ] && [ "$_cfmgr_wan4_scope0" = caller_scope0 ] || exit 82
[ "$_cfmgr_wan4_scope1" = caller_scope1 ] && \
    [ "$_cfmgr_wan4_body_bytes" = caller_body_bytes ] || exit 83
[ "$_cfmgr_wan4_row" = caller_row ] || exit 84
[ "$_cfmgr_wan4_interface" = caller_interface ] && \
    [ "$_cfmgr_wan4_address" = caller_address ] || exit 85
[ "$_cfmgr_wan4_selected_interface" = caller_selected_interface ] || exit 86
[ "$_cfmgr_wan4_ifname" = caller_ifname ] && [ "$_cfmgr_wan4_scope" = caller_scope ] || exit 87
[ "$before_traps" = "$(trap)" ] || exit 88
printf 'state-preserved\\n'
""",
        [],
    )
    assert result.returncode == 0, result
    assert result.stdout == "state-preserved\n"
    assert result.stderr == ""

    failures = run_shell(
        wan_shell,
        '. "$CFMGR_TEST_ROOT/work/ip.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/wan.sh"\n'
        "printf() {\n"
        "  case $1 in\n"
        '    wan4-selection*) [ "$_printf_fail" != row ] || return 9 ;;\n'
        '    wan4-source*) [ "$_printf_fail" != row ] || return 9 ;;\n'
        "    '%s\\nend\\t%s\\n') [ \"$_printf_fail\" != footer ] || return 9 ;;\n"
        "  esac\n"
        '  command printf "$@"\n'
        "}\n"
        "expect_format_failure() {\n"
        "  _printf_fail=$1; shift\n"
        '  capture=$("$@"); status=$?\n'
        '  [ "$status" -eq 1 ] && [ -z "$capture" ] || exit 89\n'
        "}\n"
        "expect_format_failure row cfmgr_wan4_selection_report off 1 0 - - - - -\n"
        "expect_format_failure footer cfmgr_wan4_selection_report off 1 0 - - - - -\n"
        "expect_format_failure row cfmgr_wan4_source_report 1 dhcp eth0 ppp0 8.8.8.8\n"
        "expect_format_failure footer cfmgr_wan4_source_report 1 dhcp eth0 ppp0 8.8.8.8\n",
        [],
    )
    assert failures.returncode == 0, failures
    assert failures.stdout == failures.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V44", evidence="busybox")
def test_actual_busybox_runs_both_report_functions(busybox_router: RouterHarness) -> None:
    busybox_router.write("work/ip.sh", (SOURCE.parent / "ip.sh").read_text(encoding="utf-8"))
    busybox_router.write("work/wan.sh", SOURCE.read_text(encoding="utf-8"))
    result = busybox_router.run(
        '. "$CFMGR_TEST_ROOT/work/ip.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/wan.sh"\n'
        "cfmgr_wan4_selection_report off 1 0 - - - - - || exit 81\n"
        "cfmgr_wan4_source_report 1 pppoe eth0 ppp0 8.8.8.8 || exit 82\n"
    )
    assert result.returncode == 0, result
    assert result.stdout == (
        expected_report("selection", ("selected", "0", "primary"))
        + expected_report("source", ("candidate", "ppp0", "8.8.8.8", "native-address"))
    )
    assert result.stderr == ""
