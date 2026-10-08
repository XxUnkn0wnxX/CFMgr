"""Address syntax/canonicalization evidence, without public eligibility policy."""

from __future__ import annotations

import ipaddress
import random
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

SOURCE = Path(__file__).resolve().parents[1] / "src/ip.sh"
NativeShell = tuple[RouterHarness, str]
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V66", evidence="host")]


@pytest.fixture(
    params=[
        pytest.param("/bin/sh", id="sh"),
        pytest.param(
            "/bin/dash",
            id="dash",
            marks=pytest.mark.skipif(not Path("/bin/dash").is_file(), reason="dash unavailable"),
        ),
    ]
)
def native_shell(router: RouterHarness, request: pytest.FixtureRequest) -> NativeShell:
    router.write("work/ip.sh", SOURCE.read_text(encoding="utf-8"))
    return router, request.param


def run_shell(native_shell: NativeShell, script: str, args: list[str]) -> ShellResult:
    router, shell = native_shell
    router.write("work/invoke.sh", script)
    return router.run(f'exec {shlex.quote(shell)} "$CFMGR_TEST_ROOT/work/invoke.sh" "$@"\n', args)


def invoke(native_shell: NativeShell, function: str, *args: str) -> ShellResult:
    return run_shell(native_shell, '. "$CFMGR_TEST_ROOT/work/ip.sh"\n"$@"\n', [function, *args])


def assert_rejected(result: ShellResult) -> None:
    assert result.returncode != 0
    assert result.stdout == result.stderr == ""


def ipv6_expected(value: str) -> str:
    address = ipaddress.IPv6Address(value)
    mapped = address.ipv4_mapped
    if mapped is None:
        return address.compressed
    # Python 3.14 .compressed displays mapped addresses with a dotted tail.
    # Our selected output is pure hex. A mapped address has five leading zero
    # groups then ffff, so its unique longest run always gives this fixed prefix.
    numeric_tail = int(mapped)
    return f"::ffff:{numeric_tail >> 16:x}:{numeric_tail & 65535:x}"


@pytest.mark.parametrize(
    "value",
    [
        "0.0.0.0",
        "255.255.255.255",
        "127.0.0.1",
        "10.0.0.1",
        "192.0.2.1",
        "8.9.80.90",
        "169.254.1.1",
        "224.0.0.1",
        "100.64.0.1",
    ],
)
def test_ipv4_syntax_includes_all_address_classes(native_shell: NativeShell, value: str) -> None:
    result = invoke(native_shell, "cfmgr_ipv4_normalize", value)
    assert result.returncode == 0
    assert result.stdout == str(ipaddress.IPv4Address(value)) + "\n"
    assert result.stderr == ""


@pytest.mark.parametrize(
    "value",
    [
        "",
        "1",
        "1.2.3",
        "1.2.3.4.5",
        ".1.2.3",
        "1.2.3.",
        "1..2.3",
        "01.2.3.4",
        "1.02.3.4",
        "1.2.003.4",
        "1.2.3.00",
        "000.0.0.0",
        "256.0.0.1",
        "1.999.0.1",
        "1234.1.1.1",
        "-1.2.3.4",
        "+1.2.3.4",
        "0x1.2.3.4",
        "1e0.2.3.4",
        "１.2.3.4",
        "1.2.3.4 ",
        " 1.2.3.4",
        "1.2.3.4\n",
        "1.2.3.4\r",
        "1.2.3.4\t",
        "1.2.3.4\x01",
        "1.2.3.4:80",
        "1.2.3.4/32",
        "[1.2.3.4]",
        "$(touch injected)",
        "1.2.3.4;exit 0",
    ],
)
def test_ipv4_malformed_inputs_are_quiet(native_shell: NativeShell, value: str) -> None:
    assert_rejected(invoke(native_shell, "cfmgr_ipv4_normalize", value))
    router, _ = native_shell
    assert not router.path("work/injected").exists()


VALID_IPV6 = [
    "::",
    "::1",
    "1::",
    "0:0:0:0:0:0:0:0",
    "0:0:0:0:0:0:0:1",
    "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff",
    "2001:DB8:0000:0000:0000:0000:0000:0001",
    "2001:db8::1",
    "2001:db8:0:1:2:3:4:5",
    "1:0:0:2:0:0:3:4",
    "1:0:0:0:2:0:0:0",
    "1:2:0:0:0:3:0:0",
    "0:0:1:0:0:2:3:4",
    "1:2:3:4:5:6:0:8",
    "1:2:3:4:5:6::8",
    "FE80::1",
    "ff02::1",
    "fc00::1234",
    "::1:80",
    "::192.0.2.1",
    "::ffff:192.0.2.128",
    "0:0:0:0:0:ffff:192.0.2.1",
    "2001:db8::192.0.2.1",
    "1:2:3:4:5:6:0.0.0.0",
    "ffff:ffff:ffff:ffff:ffff:ffff:255.255.255.255",
    "::0.0.0.0",
    "::255.255.255.255",
    "0001:0002:0003:0004:0005:0006:0007:0008",
]


@pytest.mark.parametrize("value", VALID_IPV6)
def test_ipv6_rfc5952_and_dotted_tail(native_shell: NativeShell, value: str) -> None:
    result = invoke(native_shell, "cfmgr_ipv6_normalize", value)
    assert result.returncode == 0
    assert result.stdout == ipv6_expected(value) + "\n"
    assert result.stderr == ""
    normalized = result.stdout.rstrip("\n")
    assert ipaddress.IPv6Address(normalized) == ipaddress.IPv6Address(value)
    repeated = invoke(native_shell, "cfmgr_ipv6_normalize", normalized)
    assert repeated.returncode == 0
    assert repeated.stdout == result.stdout
    assert repeated.stderr == ""


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("::ffff:192.0.2.128", "::ffff:c000:280"),
        ("0:0:0:0:0:ffff:192.0.2.1", "::ffff:c000:201"),
        ("::ffff:0.0.0.0", "::ffff:0:0"),
        ("::ffff:0.0.1.2", "::ffff:0:102"),
        ("::ffff:255.255.255.255", "::ffff:ffff:ffff"),
    ],
)
def test_mapped_ipv6_fixed_hex_vectors(
    native_shell: NativeShell, value: str, expected: str
) -> None:
    result = invoke(native_shell, "cfmgr_ipv6_normalize", value)
    assert result.returncode == 0
    assert result.stdout == expected + "\n"
    assert result.stderr == ""
    assert ipv6_expected(value) == expected
    assert ipaddress.IPv6Address(expected) == ipaddress.IPv6Address(value)


@pytest.mark.parametrize(
    "value",
    [
        "",
        ":",
        ":::1",
        "1:::2",
        "1::::2",
        ":::",
        "::::",
        "1::2::3",
        "::1::",
        ":1:2:3:4:5:6:7",
        "1:2:3:4:5:6:7:",
        "1:2:3:4:5:6:7",
        "1:2:3:4:5:6:7:8:9",
        "1:2:3:4:5:6:7:8::",
        "::1:2:3:4:5:6:7:8",
        "12345::",
        "1:2:3:4:5:6:7:12345",
        "0x1::",
        "+1::",
        "-1::",
        "GGGG::",
        "1.2.3.4",
        "::192.0.2",
        "::192.0.2.256",
        "::192.00.2.1",
        "::01.2.3.4",
        "::192.0.2.1:80",
        "1.2.3.4::1.2.3.4",
        "1:2:3:4:5:6:7:192.0.2.1",
        "1:2:3:4:5:192.0.2.1",
        "fe80::1%eth0",
        "fe80::1%1",
        "2001:db8::1/64",
        "[::1]",
        "[::1]:80",
        "::1 ",
        " ::1",
        "::1\n",
        "::1\r",
        "::1\t",
        "::1\x01",
        "::１",
        "$(touch injected)",
        "::1;exit 0",
        "ffff:ffff:ffff:ffff:ffff:ffff:0255.255.255.255",
    ],
)
def test_ipv6_malformed_inputs_are_quiet(native_shell: NativeShell, value: str) -> None:
    assert_rejected(invoke(native_shell, "cfmgr_ipv6_normalize", value))
    router, _ = native_shell
    assert not router.path("work/injected").exists()


def test_deterministic_ipv4_and_ipv6_oracle(native_shell: NativeShell) -> None:
    rng = random.Random(42915952)
    addresses = [
        ("cfmgr_ipv4_normalize", str(ipaddress.IPv4Address(rng.getrandbits(32)))) for _ in range(48)
    ]
    for _ in range(48):
        address = ipaddress.IPv6Address(rng.getrandbits(128))
        addresses.extend(
            [
                ("cfmgr_ipv6_normalize", address.exploded.upper()),
                ("cfmgr_ipv6_normalize", address.compressed),
            ]
        )
    # Random zero patterns exercise compression ties, edge runs and isolated zeros.
    for _ in range(32):
        groups = [0 if rng.randrange(3) else rng.randrange(1, 65536) for _ in range(8)]
        value = ":".join(f"{group:04X}" for group in groups)
        addresses.append(("cfmgr_ipv6_normalize", value))
    # Keep subprocess work bounded in small batches, independently compare every result.
    for offset in range(0, len(addresses), 24):
        batch = addresses[offset : offset + 24]
        script = '. "$CFMGR_TEST_ROOT/work/ip.sh"\n' + "\n".join(
            shlex.join([function, value]) + " || exit 20" for function, value in batch
        )
        result = run_shell(native_shell, script, [])
        assert result.returncode == 0
        assert result.stdout.splitlines() == [
            ipv6_expected(value)
            if function == "cfmgr_ipv6_normalize"
            else ipaddress.IPv4Address(value).compressed
            for function, value in batch
        ]
        assert result.stderr == ""


@pytest.mark.parametrize("function", ["cfmgr_ipv4_normalize", "cfmgr_ipv6_normalize"])
def test_exact_argument_count(native_shell: NativeShell, function: str) -> None:
    assert_rejected(invoke(native_shell, function))
    assert_rejected(invoke(native_shell, function, "::1", "extra"))


def test_sourcing_and_calls_preserve_caller_state(native_shell: NativeShell) -> None:
    result = run_shell(
        native_shell,
        """set -efu
set -- original 'two words'
IFS='|'
umask 027
export CFMGR_CALLER_SENTINEL='original value'
_cfmgr_ip4_remaining=caller_four
_cfmgr_ip6_address=caller_six
_cfmgr_ip6_full=caller_full
_cfmgr_ip6_output=caller_output
trap ':' INT TERM
before_options=$-
before_pwd=$PWD
before_umask=$(umask)
before_exports=$(export -p)
child_events=0
trap 'child_events=$((child_events + 1))' CHLD
before_traps=$(trap)
child_events=0
. "$CFMGR_TEST_ROOT/work/ip.sh" > "$RAM_ROOT/source.out" 2> "$RAM_ROOT/source.err"
[ "$child_events" -eq 0 ] || exit 10
[ ! -s "$RAM_ROOT/source.out" ] && [ ! -s "$RAM_ROOT/source.err" ] || exit 11
cfmgr_ipv4_normalize 192.0.2.1 > "$RAM_ROOT/result"
cfmgr_ipv6_normalize ::ffff:192.0.2.1 > "$RAM_ROOT/result"
[ "$#" -eq 2 ] && [ "$1" = original ] && [ "$2" = 'two words' ] || exit 12
[ "$before_options" = "$-" ] && [ "$before_pwd" = "$PWD" ] || exit 13
[ "$before_umask" = "$(umask)" ] && [ "$before_exports" = "$(export -p)" ] || exit 14
[ "$before_traps" = "$(trap)" ] && [ "$IFS" = '|' ] || exit 15
[ "$_cfmgr_ip4_remaining" = caller_four ] && [ "$_cfmgr_ip6_address" = caller_six ] || exit 16
[ "$_cfmgr_ip6_full" = caller_full ] && [ "$_cfmgr_ip6_output" = caller_output ] || exit 17
printf 'preserved\\n'
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "preserved\n"
    assert result.stderr == ""
    router, _ = native_shell
    assert list(router.path("bin").iterdir()) == []


@pytest.mark.busybox
@pytest.mark.matrix("V66", evidence="busybox")
def test_actual_busybox_normalization(busybox_router: RouterHarness) -> None:
    busybox_router.write("work/ip.sh", SOURCE.read_text(encoding="utf-8"))
    values = ["::", "::ffff:192.0.2.1", "1:0:0:2:0:0:3:4", "FFFF::ABCD"]
    result = busybox_router.run(
        '. "$CFMGR_TEST_ROOT/work/ip.sh"\n'
        + "\n".join(shlex.join(["cfmgr_ipv6_normalize", value]) + " || exit 1" for value in values)
        + "\ncfmgr_ipv4_normalize 255.255.255.255\n"
    )
    assert result.returncode == 0
    assert result.stdout.splitlines() == [ipv6_expected(value) for value in values] + [
        "255.255.255.255"
    ]
    assert result.stderr == ""
