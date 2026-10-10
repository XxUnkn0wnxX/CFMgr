"""Comparison of caller-supplied IPv4 observations without collection or authority."""

from __future__ import annotations

import shlex

import pytest

from tests.harness import RouterHarness
from tests.test_ip import SOURCE, NativeShell, native_shell, run_shell

pytestmark = [pytest.mark.integration, pytest.mark.matrix("V66", evidence="host")]


def expected_report(state: str, address: str, nat: str, reason: str) -> str:
    row = "\t".join(("ipv4-observation", "1", state, address, nat, reason))
    body = f"{row}\n"
    return f"{body}end\t{len(body.encode('ascii'))}\n"


REPORT_CASES = (
    ("-", "-", "unknown", "-", "unknown", "wan-unavailable"),
    ("-", "8.8.8.8", "unknown", "-", "unknown", "wan-unavailable"),
    ("192.0.2.1", "-", "unknown", "-", "unknown", "wan-nonpublic"),
    ("192.0.2.1", "8.8.8.8", "unknown", "-", "unknown", "wan-nonpublic"),
    ("8.8.8.8", "-", "unknown", "-", "unknown", "external-unavailable"),
    ("10.0.0.1", "-", "unknown", "-", "unknown", "external-unavailable"),
    ("100.64.0.1", "-", "unknown", "-", "unknown", "external-unavailable"),
    ("8.8.8.8", "192.0.2.1", "unknown", "-", "unknown", "external-nonpublic"),
    ("10.0.0.1", "10.0.0.1", "unknown", "-", "unknown", "external-nonpublic"),
    ("100.64.0.1", "100.64.0.1", "unknown", "-", "unknown", "external-nonpublic"),
    ("8.8.8.8", "8.8.8.8", "active", "8.8.8.8", "false", "address-match"),
    ("8.8.8.8", "1.1.1.1", "active", "1.1.1.1", "true", "address-mismatch"),
    ("10.0.0.1", "8.8.8.8", "active", "8.8.8.8", "true", "private-wan"),
    ("100.64.0.1", "8.8.8.8", "active", "8.8.8.8", "true", "shared-wan"),
)


@pytest.mark.usefixtures(native_shell.__name__)
def test_ipv4_observation_report_matches_independent_decision_table(
    native_shell: NativeShell,
) -> None:
    for offset in range(0, len(REPORT_CASES), 8):
        batch = REPORT_CASES[offset : offset + 8]
        script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
            shlex.join(["cfmgr_ipv4_observation_report", wan, external]) + " || exit 41"
            for wan, external, *_ in batch
        )
        result = run_shell(native_shell, script, [])
        expected = "".join(expected_report(*case[2:]) for case in batch)
        assert result.returncode == 0, f"batch={batch!r}; stderr={result.stderr!r}"
        assert result.stdout == expected, f"batch={batch!r}"
        assert result.stderr == "", f"batch={batch!r}"


def test_ipv4_observation_report_rejects_both_operands_and_arity_quietly(
    native_shell: NativeShell,
) -> None:
    result = run_shell(
        native_shell,
        """. "$CFMGR_TEST_ROOT/work/ip.sh"
cfmgr_ipv4_observation_report 8.8.8.8 8.8.8.8 > /dev/null || exit 10
check_invalid() {
    if cfmgr_ipv4_observation_report "$@" > "$RAM_ROOT/invalid.out" 2> "$RAM_ROOT/invalid.err"; then
        code=0
    else
        code=$?
    fi
    [ "$code" -eq 1 ] && [ ! -s "$RAM_ROOT/invalid.out" ] && \
        [ ! -s "$RAM_ROOT/invalid.err" ] || return 1
    printf '%s\\n' "$code"
}
check_invalid
check_invalid 8.8.8.8
check_invalid 8.8.8.8 8.8.8.8 extra
check_invalid invalid 8.8.8.8
check_invalid - invalid
check_invalid 192.0.2.1 invalid
check_invalid 8.8.8.8 008.8.8.8
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "1\n1\n1\n1\n1\n1\n1\n"
    assert result.stderr == ""


def test_ipv4_observation_report_refuses_failed_formatter(native_shell: NativeShell) -> None:
    result = run_shell(
        native_shell,
        """. "$CFMGR_TEST_ROOT/work/ip.sh"
printf() {
    case $1 in ipv4-observation*) return 7 ;; esac
    command printf "$@"
}
cfmgr_ipv4_observation_report - -
""",
        [],
    )
    assert result.returncode == 1
    assert result.stdout == result.stderr == ""


def test_ipv4_observation_report_preserves_caller_state(native_shell: NativeShell) -> None:
    result = run_shell(
        native_shell,
        """set -efu
set -- original 'two words'
IFS='|'
umask 027
export CFMGR_CALLER_SENTINEL='original value'
_cfmgr_ip4_obs_wan=caller_wan
_cfmgr_ip4_obs_external=caller_external
_cfmgr_ip4_obs_wan_scope=caller_wan_scope
_cfmgr_ip4_obs_external_scope=caller_external_scope
_cfmgr_ip4_obs_wan_valid=caller_wan_valid
_cfmgr_ip4_obs_external_valid=caller_external_valid
_cfmgr_ip4_obs_state=caller_state
_cfmgr_ip4_obs_address=caller_address
_cfmgr_ip4_obs_nat=caller_nat
_cfmgr_ip4_obs_reason=caller_reason
_cfmgr_ip4_obs_row=caller_row
_cfmgr_ip4_obs_body_bytes=caller_body_bytes
_cfmgr_ip4_classified=caller_classified
_cfmgr_ip4_scope=caller_scope
_cfmgr_ip4_a=caller_a
_cfmgr_ip4_b=caller_b
_cfmgr_ip4_c=caller_c
_cfmgr_ip4_d=caller_d
_cfmgr_ip4_remaining=caller_remaining
_cfmgr_ip4_count=caller_count
_cfmgr_ip4_octet=caller_octet
before_options=$-
before_umask=$(umask)
before_exports=$(export -p)
trap ':' INT TERM
before_traps=$(trap)
. "$CFMGR_TEST_ROOT/work/ip.sh"
cfmgr_ipv4_observation_report 8.8.8.8 1.1.1.1 > "$RAM_ROOT/report" || exit 10
{
    IFS= read -r first || exit 11
    IFS= read -r second || exit 12
    if IFS= read -r extra; then exit 13; fi
} < "$RAM_ROOT/report"
[ "$first" = 'ipv4-observation	1	active	1.1.1.1	true	address-mismatch' ] || exit 14
[ "$second" = 'end	56' ] || exit 15
[ "$#" -eq 2 ] && [ "$1" = original ] && [ "$2" = 'two words' ] || exit 16
[ "$before_options" = "$-" ] && [ "$before_umask" = "$(umask)" ] || exit 17
[ "$before_exports" = "$(export -p)" ] && [ "$before_traps" = "$(trap)" ] || exit 18
[ "$IFS" = '|' ] || exit 19
[ "$_cfmgr_ip4_obs_wan" = caller_wan ] || exit 20
[ "$_cfmgr_ip4_obs_external" = caller_external ] || exit 21
[ "$_cfmgr_ip4_obs_wan_scope" = caller_wan_scope ] || exit 22
[ "$_cfmgr_ip4_obs_external_scope" = caller_external_scope ] || exit 23
[ "$_cfmgr_ip4_obs_wan_valid" = caller_wan_valid ] || exit 24
[ "$_cfmgr_ip4_obs_external_valid" = caller_external_valid ] || exit 25
[ "$_cfmgr_ip4_obs_state" = caller_state ] || exit 26
[ "$_cfmgr_ip4_obs_address" = caller_address ] || exit 27
[ "$_cfmgr_ip4_obs_nat" = caller_nat ] || exit 28
[ "$_cfmgr_ip4_obs_reason" = caller_reason ] || exit 29
[ "$_cfmgr_ip4_obs_row" = caller_row ] || exit 30
[ "$_cfmgr_ip4_obs_body_bytes" = caller_body_bytes ] || exit 31
[ "$_cfmgr_ip4_classified" = caller_classified ] || exit 32
[ "$_cfmgr_ip4_scope" = caller_scope ] || exit 33
[ "$_cfmgr_ip4_a" = caller_a ] || exit 34
[ "$_cfmgr_ip4_b" = caller_b ] || exit 35
[ "$_cfmgr_ip4_c" = caller_c ] || exit 36
[ "$_cfmgr_ip4_d" = caller_d ] || exit 37
[ "$_cfmgr_ip4_remaining" = caller_remaining ] || exit 38
[ "$_cfmgr_ip4_count" = caller_count ] || exit 39
[ "$_cfmgr_ip4_octet" = caller_octet ] || exit 40
printf 'preserved\\n'
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "preserved\n"
    assert result.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V66", evidence="busybox")
def test_actual_busybox_ipv4_observation_report_composition(busybox_router: RouterHarness) -> None:
    busybox_router.write("work/ip.sh", SOURCE.read_text(encoding="utf-8"))
    cases = (
        ("8.8.8.8", "8.8.8.8", "active", "8.8.8.8", "false", "address-match"),
        ("8.8.8.8", "1.1.1.1", "active", "1.1.1.1", "true", "address-mismatch"),
        ("100.64.0.1", "8.8.4.4", "active", "8.8.4.4", "true", "shared-wan"),
        ("192.0.2.1", "8.8.8.8", "unknown", "-", "unknown", "wan-nonpublic"),
    )
    script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
        shlex.join(["cfmgr_ipv4_observation_report", wan, external]) + " || exit 41"
        for wan, external, *_ in cases
    )
    result = busybox_router.run(script)
    expected = "".join(expected_report(*case[2:]) for case in cases)
    assert result.returncode == 0
    assert result.stdout == expected
    assert result.stderr == ""
