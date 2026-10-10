"""Explicit IPv4/IPv6 scope ranges, separate from route and ownership evidence."""

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

IPV6_PRIVATE_RANGES = (ipaddress.ip_network("fc00::/7"),)
IPV6_TRANSITION_RANGES = tuple(
    ipaddress.ip_network(network)
    for network in (
        "::/96",
        "::ffff:0:0/96",
        "64:ff9b::/96",
        "64:ff9b:1::/48",
        "2001::/32",
        "2002::/16",
    )
)
IPV6_SPECIAL_POINTS = tuple(
    ipaddress.IPv6Address(value) for value in ("2001:1::1", "2001:1::2", "2001:1::3")
)
IPV6_SPECIAL_RANGES = tuple(
    ipaddress.ip_network(network)
    for network in (
        "2001:3::/32",
        "2001:4:112::/48",
        "2001:20::/28",
        "2001:30::/28",
        "2620:4f:8000::/48",
    )
)
IPV6_NONPUBLIC_RANGES = tuple(
    ipaddress.ip_network(network)
    for network in ("2001::/23", "2001:db8::/32", "3fff::/20", "3ffe::/16")
)
IPV6_GLOBAL_RANGE = ipaddress.ip_network("2000::/3")


def expected_ipv6_scope(value: str) -> str:
    address = ipaddress.IPv6Address(value)
    if address in IPV6_PRIVATE_RANGES[0]:
        return "private"
    if any(address in network for network in IPV6_TRANSITION_RANGES) and address not in (
        ipaddress.IPv6Address("::"),
        ipaddress.IPv6Address("::1"),
    ):
        return "transition"
    if address in IPV6_SPECIAL_POINTS or any(address in network for network in IPV6_SPECIAL_RANGES):
        return "special"
    if address in (ipaddress.IPv6Address("::"), ipaddress.IPv6Address("::1")):
        return "nonpublic"
    if any(address in network for network in IPV6_NONPUBLIC_RANGES):
        return "nonpublic"
    if address not in IPV6_GLOBAL_RANGE:
        return "nonpublic"
    return "global"


def ipv6_boundaries(network: ipaddress.IPv6Network) -> tuple[str, ...]:
    start = int(network.network_address)
    end = int(network.broadcast_address)
    values = []
    if start > 0:
        values.append(str(ipaddress.IPv6Address(start - 1)))
    values.extend((str(network.network_address), str(network.broadcast_address)))
    if end < (1 << 128) - 1:
        values.append(str(ipaddress.IPv6Address(end + 1)))
    return tuple(values)


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


@pytest.mark.usefixtures(native_shell.__name__)
def test_ipv6_scope_classifier_matches_explicit_prefix_boundaries_and_exceptions(
    native_shell: NativeShell,
) -> None:
    addresses: dict[str, str] = {}
    networks = (
        *IPV6_PRIVATE_RANGES,
        *IPV6_TRANSITION_RANGES,
        *IPV6_SPECIAL_RANGES,
        *IPV6_NONPUBLIC_RANGES,
        IPV6_GLOBAL_RANGE,
    )
    for network in networks:
        for value in ipv6_boundaries(network):
            addresses[value] = expected_ipv6_scope(value)

    for point in IPV6_SPECIAL_POINTS:
        for value in (int(point) - 1, int(point), int(point) + 1):
            address = str(ipaddress.IPv6Address(value))
            addresses[address] = expected_ipv6_scope(address)
    for value in ("::", "::1", "::2", "::ffff", "fc::", "::ffff:0:0:1", "3fff:1000::"):
        addresses[value] = expected_ipv6_scope(value)

    # These spellings exercise normalization at the classifier boundary, including a dotted tail.
    for value in (
        "FC00:0000:0000:0000:0000:0000:0000:0001",
        "0:0:0:0:0:ffff:192.0.2.1",
        "64:FF9B:0001:0000:0000:0000:0000:0001",
        "2001:0000:0000:0000:0000:0000:0000:0001",
        "2001:0001:0000:0000:0000:0000:0000:0001",
        "2001:0DB8:0000:0000:0000:0000:0000:0001",
    ):
        addresses[value] = expected_ipv6_scope(value)

    items = list(addresses.items())
    for offset in range(0, len(items), 16):
        batch = items[offset : offset + 16]
        script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
            shlex.join(["cfmgr_ipv6_classify", value]) + " || exit 41" for value, _ in batch
        )
        result = run_shell(native_shell, script, [])
        assert result.returncode == 0, f"batch={batch!r}; stderr={result.stderr!r}"
        assert result.stdout == "".join(f"{scope}\n" for _, scope in batch), f"batch={batch!r}"
        assert result.stderr == "", f"batch={batch!r}"


def test_ipv6_scope_classifier_rejects_small_invalid_subset_with_positive_control(
    native_shell: NativeShell,
) -> None:
    result = run_shell(
        native_shell,
        """. "$CFMGR_TEST_ROOT/work/ip.sh"
cfmgr_ipv6_classify 2001:db8::1 || exit 10
check_invalid() {
    if cfmgr_ipv6_classify "$@" > "$RAM_ROOT/invalid.out" 2> "$RAM_ROOT/invalid.err"; then
        code=0
    else
        code=$?
    fi
    [ "$code" -eq 1 ] && [ ! -s "$RAM_ROOT/invalid.out" ] && \
        [ ! -s "$RAM_ROOT/invalid.err" ] || return 1
    printf '%s\\n' "$code"
}
check_invalid
check_invalid 2001:db8::1 extra
check_invalid 2001:db8::1/64
check_invalid fe80::1%eth0
check_invalid :::1
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "nonpublic\n1\n1\n1\n1\n1\n"
    assert result.stderr == ""


def test_ipv6_scope_classifier_preserves_caller_state(native_shell: NativeShell) -> None:
    result = run_shell(
        native_shell,
        """set -efu
set -- original 'two words'
IFS='|'
umask 027
export CFMGR_CALLER_SENTINEL='original value'
_cfmgr_ip6_address=caller_address
_cfmgr_ip6_prefix=caller_prefix
_cfmgr_ip6_classified=caller_classified
_cfmgr_ip6_scope=caller_scope
_cfmgr_ip6_scope_left=caller_scope_left
_cfmgr_ip6_scope_right=caller_scope_right
_cfmgr_ip6_scope_count=caller_scope_count
_cfmgr_ip6_scope_side=caller_scope_side
_cfmgr_ip6_scope_missing=caller_scope_missing
_cfmgr_ip6_scope_full=caller_scope_full
_cfmgr_ip6_scope_first=caller_scope_first
_cfmgr_ip6_scope_second=caller_scope_second
_cfmgr_ip6_full=caller_full
_cfmgr_ip6_output=caller_output
before_options=$-
before_umask=$(umask)
before_exports=$(export -p)
trap ':' INT TERM
before_traps=$(trap)
. "$CFMGR_TEST_ROOT/work/ip.sh"
cfmgr_ipv6_classify 2001:4860::1 > "$RAM_ROOT/classified" || exit 10
IFS= read -r classified < "$RAM_ROOT/classified"
[ "$classified" = global ] || exit 10
[ "$#" -eq 2 ] && [ "$1" = original ] && [ "$2" = 'two words' ] || exit 11
[ "$before_options" = "$-" ] && [ "$before_umask" = "$(umask)" ] || exit 12
[ "$before_exports" = "$(export -p)" ] && [ "$before_traps" = "$(trap)" ] || exit 13
[ "$IFS" = '|' ] || exit 14
[ "$_cfmgr_ip6_address" = caller_address ] && [ "$_cfmgr_ip6_prefix" = caller_prefix ] || exit 15
[ "$_cfmgr_ip6_classified" = caller_classified ] || exit 16
[ "$_cfmgr_ip6_scope" = caller_scope ] || exit 16
[ "$_cfmgr_ip6_scope_left" = caller_scope_left ] || exit 18
[ "$_cfmgr_ip6_scope_right" = caller_scope_right ] || exit 18
[ "$_cfmgr_ip6_scope_count" = caller_scope_count ] || exit 19
[ "$_cfmgr_ip6_scope_side" = caller_scope_side ] || exit 19
[ "$_cfmgr_ip6_scope_missing" = caller_scope_missing ] || exit 20
[ "$_cfmgr_ip6_scope_full" = caller_scope_full ] || exit 20
[ "$_cfmgr_ip6_scope_first" = caller_scope_first ] || exit 21
[ "$_cfmgr_ip6_scope_second" = caller_scope_second ] || exit 21
[ "$_cfmgr_ip6_full" = caller_full ] || exit 17
[ "$_cfmgr_ip6_output" = caller_output ] || exit 17
printf 'preserved\\n'
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "preserved\n"
    assert result.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V66", evidence="busybox")
def test_actual_busybox_classifies_ipv6_scope_candidates(busybox_router: RouterHarness) -> None:
    busybox_router.write("work/ip.sh", SOURCE.read_text(encoding="utf-8"))
    values = ["fc00::1", "::ffff:192.0.2.1", "2001:1::1", "2001:db8::1", "2001:4860::1"]
    script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
        shlex.join(["cfmgr_ipv6_classify", value]) + " || exit 1" for value in values
    )
    result = busybox_router.run(script)
    assert result.returncode == 0
    assert result.stdout == "private\ntransition\nspecial\nnonpublic\nglobal\n"
    assert result.stderr == ""
