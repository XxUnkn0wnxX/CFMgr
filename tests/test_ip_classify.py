"""Explicit IPv4 scope ranges, separate from route and ownership evidence."""

from __future__ import annotations

import ipaddress
import shlex

import pytest

from tests.harness import RouterHarness
from tests.test_ip import SOURCE, NativeShell, native_shell, run_shell

pytestmark = [pytest.mark.integration, pytest.mark.matrix("V66", evidence="host")]

PRIVATE_RANGES = tuple(
    ipaddress.ip_network(network) for network in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16")
)
SHARED_RANGES = (ipaddress.ip_network("100.64.0.0/10"),)
NONPUBLIC_RANGES = tuple(
    ipaddress.ip_network(network)
    for network in (
        "0.0.0.0/8",
        "127.0.0.0/8",
        "169.254.0.0/16",
        "192.0.0.0/24",
        "192.0.2.0/24",
        "192.88.99.0/24",
        "198.18.0.0/15",
        "198.51.100.0/24",
        "203.0.113.0/24",
        "224.0.0.0/3",
    )
)
GLOBAL_EXCEPTIONS = {"192.0.0.9", "192.0.0.10"}


def expected_scope(value: str) -> str:
    address = ipaddress.IPv4Address(value)
    if value in GLOBAL_EXCEPTIONS:
        return "global"
    if any(address in network for network in PRIVATE_RANGES):
        return "private"
    if any(address in network for network in SHARED_RANGES):
        return "shared"
    if any(address in network for network in NONPUBLIC_RANGES):
        return "nonpublic"
    return "global"


@pytest.mark.usefixtures(native_shell.__name__)
def test_ipv4_scope_classifier_matches_explicit_prefix_boundaries_and_exceptions(
    native_shell: NativeShell,
) -> None:
    addresses: dict[str, str] = {}
    for network in (*PRIVATE_RANGES, *SHARED_RANGES, *NONPUBLIC_RANGES):
        start = int(network.network_address)
        end = int(network.broadcast_address)
        if start > 0:
            addresses[str(ipaddress.IPv4Address(start - 1))] = expected_scope(
                str(ipaddress.IPv4Address(start - 1))
            )
        addresses[str(network.network_address)] = expected_scope(str(network.network_address))
        addresses[str(network.broadcast_address)] = expected_scope(str(network.broadcast_address))
        if end < (1 << 32) - 1:
            after = str(ipaddress.IPv4Address(end + 1))
            addresses[after] = expected_scope(after)

    addresses.update(
        {
            value: expected_scope(value)
            for value in (
                "192.0.0.8",
                "192.0.0.9",
                "192.0.0.10",
                "192.0.0.11",
                "192.31.196.1",
                "192.52.193.1",
                "192.175.48.1",
                "8.0.0.0",
                "8.0.0.255",
            )
        }
    )
    script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
        shlex.join(["cfmgr_ipv4_classify", value]) + " || exit 41" for value in addresses
    )
    result = run_shell(native_shell, script, [])
    assert result.returncode == 0
    assert result.stdout == "".join(f"{addresses[value]}\n" for value in addresses)
    assert result.stderr == ""


@pytest.mark.usefixtures(native_shell.__name__)
def test_ipv4_scope_classifier_rejects_small_invalid_subset_with_positive_control(
    native_shell: NativeShell,
) -> None:
    result = run_shell(
        native_shell,
        """. "$CFMGR_TEST_ROOT/work/ip.sh"
cfmgr_ipv4_classify 8.8.8.8 || exit 10
check_invalid() {
    if cfmgr_ipv4_classify "$@" > "$RAM_ROOT/invalid.out" 2> "$RAM_ROOT/invalid.err"; then
        code=0
    else
        code=$?
    fi
    [ "$code" -eq 1 ] && [ ! -s "$RAM_ROOT/invalid.out" ] && \
        [ ! -s "$RAM_ROOT/invalid.err" ] || return 1
    printf '%s\\n' "$code"
}
check_invalid
check_invalid 8.8.8.8 extra
check_invalid 008.8.8.8
check_invalid 8.8.256.8
check_invalid 8.8.8
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "global\n1\n1\n1\n1\n1\n"
    assert result.stderr == ""


@pytest.mark.usefixtures(native_shell.__name__)
def test_ipv4_scope_classifier_preserves_caller_state(native_shell: NativeShell) -> None:
    result = run_shell(
        native_shell,
        """set -efu
set -- original 'two words'
IFS='|'
umask 027
export CFMGR_CALLER_SENTINEL='original value'
_cfmgr_ip4_classified=caller_classified
_cfmgr_ip4_a=caller_a
_cfmgr_ip4_b=caller_b
_cfmgr_ip4_c=caller_c
_cfmgr_ip4_d=caller_d
_cfmgr_ip4_scope=caller_scope
before_options=$-
before_umask=$(umask)
before_exports=$(export -p)
trap ':' INT TERM
before_traps=$(trap)
. "$CFMGR_TEST_ROOT/work/ip.sh"
cfmgr_ipv4_classify 192.168.1.1 > "$RAM_ROOT/classified" || exit 10
IFS= read -r classified < "$RAM_ROOT/classified"
[ "$classified" = private ] || exit 10
[ "$#" -eq 2 ] && [ "$1" = original ] && [ "$2" = 'two words' ] || exit 11
[ "$before_options" = "$-" ] && [ "$before_umask" = "$(umask)" ] || exit 12
[ "$before_exports" = "$(export -p)" ] && [ "$before_traps" = "$(trap)" ] || exit 13
[ "$IFS" = '|' ] || exit 14
[ "$_cfmgr_ip4_classified" = caller_classified ] && [ "$_cfmgr_ip4_a" = caller_a ] || exit 15
[ "$_cfmgr_ip4_b" = caller_b ] && [ "$_cfmgr_ip4_c" = caller_c ] || exit 16
[ "$_cfmgr_ip4_d" = caller_d ] && [ "$_cfmgr_ip4_scope" = caller_scope ] || exit 17
printf 'preserved\\n'
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "preserved\n"
    assert result.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V66", evidence="busybox")
def test_actual_busybox_classifies_private_shared_and_global_candidates(
    busybox_router: RouterHarness,
) -> None:
    busybox_router.write("work/ip.sh", SOURCE.read_text(encoding="utf-8"))
    values = ["10.0.0.1", "100.64.0.1", "192.0.0.9", "192.0.2.1", "8.8.8.8"]
    script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
        shlex.join(["cfmgr_ipv4_classify", value]) + " || exit 1" for value in values
    )
    result = busybox_router.run(script)
    assert result.returncode == 0
    assert result.stdout == "private\nshared\nglobal\nnonpublic\nglobal\n"
    assert result.stderr == ""
