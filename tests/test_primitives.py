"""Pure native parser contracts, distinct from firmware/update transaction proof."""

from __future__ import annotations

import random
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

COMMON = Path(__file__).resolve().parents[1] / "modules/common.sh"
NativeShell = tuple[RouterHarness, str]
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V43", evidence="harness")]


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
    router.write("work/common.sh", COMMON.read_text(encoding="utf-8"))
    return router, request.param


def run_shell(native_shell: NativeShell, script: str, args: list[str]) -> ShellResult:
    router, shell = native_shell
    router.write("work/invoke.sh", script)
    # Explicit host shell; it replaces the harness shell in the same owned session.
    return router.run(
        f'exec {shlex.quote(shell)} "$CFMGR_TEST_ROOT/work/invoke.sh" "$@"\n',
        args,
    )


def invoke(native_shell: NativeShell, function: str, *args: str) -> ShellResult:
    return run_shell(native_shell, '. "$CFMGR_TEST_ROOT/work/common.sh"\n"$@"\n', [function, *args])


def assert_rejected(result: ShellResult) -> None:
    assert result.returncode != 0
    assert result.stdout == ""
    assert result.stderr == ""


def test_sourcing_and_helpers_preserve_caller_state(native_shell: NativeShell) -> None:
    result = run_shell(
        native_shell,
        """set -efu
set -- first 'two words'
IFS='|'
umask 027
export CFMGR_CALLER_SENTINEL='original value'
_cfmgr_decimal=caller_decimal
_cfmgr_left=caller_left
_cfmgr_right=caller_right
_cfmgr_version=caller_version
_cfmgr_digest=caller_digest
trap ':' INT TERM
before_options=$-
before_pwd=$PWD
before_umask=$(umask)
before_exports=$(export -p)
child_events=0
trap 'child_events=$((child_events + 1))' CHLD
before_traps=$(trap)
child_events=0
. "$CFMGR_TEST_ROOT/work/common.sh" > "$RAM_ROOT/source.out" 2> "$RAM_ROOT/source.err"
[ "$child_events" -eq 0 ] || exit 10
[ ! -s "$RAM_ROOT/source.out" ] && [ ! -s "$RAM_ROOT/source.err" ] || exit 11
[ "$#" -eq 2 ] && [ "$1" = first ] && [ "$2" = 'two words' ] || exit 12
cfmgr_decimal_normalize 0009 > "$RAM_ROOT/value"
cfmgr_decimal_compare 99 100 > "$RAM_ROOT/value"
cfmgr_uint31 0002147483647 > "$RAM_ROOT/value"
cfmgr_version_compare 10.0.1 9.99.99 > "$RAM_ROOT/value"
digest=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
cfmgr_sha256_normalize "$digest" > "$RAM_ROOT/value"
[ "$before_options" = "$-" ] && [ "$before_pwd" = "$PWD" ] || exit 13
[ "$before_umask" = "$(umask)" ] && [ "$before_exports" = "$(export -p)" ] || exit 14
[ "$before_traps" = "$(trap)" ] && [ "$IFS" = '|' ] || exit 15
[ "$_cfmgr_decimal" = caller_decimal ] && [ "$_cfmgr_left" = caller_left ] || exit 16
[ "$_cfmgr_right" = caller_right ] && [ "$_cfmgr_version" = caller_version ] || exit 17
[ "$_cfmgr_digest" = caller_digest ] || exit 18
printf 'preserved\\n'
""",
        [],
    )
    assert result.returncode == 0
    assert result.stdout == "preserved\n"
    assert result.stderr == ""
    router, _ = native_shell
    assert list(router.path("bin").iterdir()) == []


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("0", "0"),
        ("00000", "0"),
        ("008", "8"),
        ("00009", "9"),
        ("10", "10"),
        ("0" * 127 + "1", "1"),
        ("9" * 128, "9" * 128),
    ],
)
def test_decimal_normalize(native_shell: NativeShell, value: str, expected: str) -> None:
    result = invoke(native_shell, "cfmgr_decimal_normalize", value)
    assert result.returncode == 0
    assert result.stdout == expected + "\n"
    assert result.stderr == ""


INVALID_DECIMALS = [
    "",
    "9" * 129,
    "+1",
    "-1",
    "0x10",
    "1.0",
    "1e2",
    " 1",
    "1 ",
    "1\t",
    "1\n",
    "1\r",
    "1\x01",
    "1\x7f",
    "１２３",
    "١٢٣",
    "$(touch injected)",
    "1; : > injected",
]


@pytest.mark.parametrize("value", INVALID_DECIMALS)
def test_invalid_decimals_are_quiet_and_inert(native_shell: NativeShell, value: str) -> None:
    for function in ("cfmgr_decimal_normalize", "cfmgr_uint31"):
        assert_rejected(invoke(native_shell, function, value))
    assert_rejected(invoke(native_shell, "cfmgr_decimal_compare", value, "0"))
    assert_rejected(invoke(native_shell, "cfmgr_decimal_compare", "0", value))
    router, _ = native_shell
    assert not router.path("work/injected").exists()


def test_decimal_comparison_against_deterministic_bigint_oracle(native_shell: NativeShell) -> None:
    rng = random.Random(20261008)
    pairs = [
        ("000", "0"),
        ("2147483647", "2147483648"),
        ("4294967295", "4294967296"),
        ("9" * 127, "1" + "0" * 127),
        ("9" * 128, "9" * 128),
        ("1" + "0" * 126 + "1", "1" + "0" * 126 + "2"),
    ]
    for _ in range(24):
        left = str(rng.randrange(10 ** rng.randint(1, 128)))
        right = str(rng.randrange(10 ** rng.randint(1, 128)))
        pairs.append((left, right))
    commands = []
    expected = []
    for left, right in pairs:
        for first, second in ((left, right), (right, left), (left, left)):
            commands.append(shlex.join(["cfmgr_decimal_compare", first, second]) + " || exit 20")
            expected.append(str((int(first) > int(second)) - (int(first) < int(second))))
    result = run_shell(
        native_shell, '. "$CFMGR_TEST_ROOT/work/common.sh"\n' + "\n".join(commands), []
    )
    assert result.returncode == 0
    assert result.stdout.splitlines() == expected
    assert result.stderr == ""


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("0", "0"),
        ("00008", "8"),
        ("2147483646", "2147483646"),
        ("0002147483647", "2147483647"),
        ("0" * 128, "0"),
    ],
)
def test_uint31_boundaries(native_shell: NativeShell, value: str, expected: str) -> None:
    result = invoke(native_shell, "cfmgr_uint31", value)
    assert result.returncode == 0
    assert result.stdout == expected + "\n"
    assert result.stderr == ""


@pytest.mark.parametrize("value", ["2147483648", "4294967295", "4294967296", "9" * 128])
def test_uint31_overflow(native_shell: NativeShell, value: str) -> None:
    assert_rejected(invoke(native_shell, "cfmgr_uint31", value))


@pytest.mark.matrix("V32", evidence="host")
def test_numeric_versions_against_bigint_tuple_oracle(native_shell: NativeShell) -> None:
    rng = random.Random(3108)
    versions = [
        "0.0.0",
        "1.2.3",
        "1.10.0",
        "2.0.0",
        "2026.10.8",
        "4294967296.0.0",
        "1.2147483648.0",
        "1.0." + "9" * 124,
    ]
    for _ in range(16):
        versions.append(".".join(str(rng.randrange(10 ** rng.randint(1, 30))) for _ in range(3)))
    commands = []
    expected = []
    for left, right in zip(versions, versions[1:], strict=False):
        for first, second in ((left, right), (right, left), (left, left)):
            commands.append(shlex.join(["cfmgr_version_compare", first, second]) + " || exit 21")
            first_tuple = tuple(map(int, first.split(".")))
            second_tuple = tuple(map(int, second.split(".")))
            expected.append(str((first_tuple > second_tuple) - (first_tuple < second_tuple)))
    result = run_shell(
        native_shell, '. "$CFMGR_TEST_ROOT/work/common.sh"\n' + "\n".join(commands), []
    )
    assert result.returncode == 0
    assert result.stdout.splitlines() == expected
    assert result.stderr == ""


@pytest.mark.matrix("V32", evidence="host")
@pytest.mark.parametrize(
    "value",
    [
        "",
        "1",
        "1.2",
        "1.2.3.4",
        ".1.2",
        "1..2",
        "1.2.",
        "01.2.3",
        "1.02.3",
        "1.2.00",
        "v1.2.3",
        "1.2.3-rc1",
        "1.2.3+build",
        "+1.2.3",
        "1.-2.3",
        "1.2.3 ",
        " 1.2.3",
        "1.2.3\n",
        "1.2.3\t",
        "1.2.３",
        "1.2.$(touch injected)",
        "1.0." + "9" * 125,
    ],
)
def test_versions_reject_noncanonical_forms(native_shell: NativeShell, value: str) -> None:
    assert_rejected(invoke(native_shell, "cfmgr_version_compare", value, "0.0.0"))
    assert_rejected(invoke(native_shell, "cfmgr_version_compare", "0.0.0", value))


@pytest.mark.matrix("V32", evidence="host")
@pytest.mark.parametrize("value", ["0" * 64, "f" * 64, "A" * 64, "0123456789ABCDEF" * 4])
def test_sha256_text_normalization(native_shell: NativeShell, value: str) -> None:
    result = invoke(native_shell, "cfmgr_sha256_normalize", value)
    assert result.returncode == 0
    assert result.stdout == value.lower() + "\n"
    assert result.stderr == ""


@pytest.mark.matrix("V32", evidence="host")
@pytest.mark.parametrize(
    "value",
    [
        "",
        "a" * 63,
        "a" * 65,
        "g" * 64,
        "a" * 63 + "\n",
        " " + "a" * 63,
        "SHA256=" + "a" * 64,
        "a" * 64 + " " + "b" * 64,
        "a" * 63 + "é",
        "$(touch injected)" + "a" * 47,
    ],
)
def test_sha256_rejects_labels_and_malformed_text(native_shell: NativeShell, value: str) -> None:
    assert_rejected(invoke(native_shell, "cfmgr_sha256_normalize", value))


@pytest.mark.parametrize(
    ("function", "args"),
    [
        ("cfmgr_decimal_normalize", []),
        ("cfmgr_decimal_normalize", ["1", "2"]),
        ("cfmgr_decimal_compare", ["1"]),
        ("cfmgr_decimal_compare", ["1", "2", "3"]),
        ("cfmgr_uint31", []),
        ("cfmgr_uint31", ["1", "2"]),
        ("cfmgr_version_compare", ["1.2.3"]),
        ("cfmgr_version_compare", ["1.2.3"] * 3),
        ("cfmgr_sha256_normalize", []),
        ("cfmgr_sha256_normalize", ["a" * 64] * 2),
    ],
)
def test_argument_counts_are_quiet(
    native_shell: NativeShell, function: str, args: list[str]
) -> None:
    assert_rejected(invoke(native_shell, function, *args))


@pytest.mark.busybox
@pytest.mark.matrix("V43", evidence="busybox")
def test_actual_busybox_primitive_boundaries(busybox_router: RouterHarness) -> None:
    busybox_router.write("work/common.sh", COMMON.read_text(encoding="utf-8"))
    result = busybox_router.run(
        '. "$CFMGR_TEST_ROOT/work/common.sh"\n'
        "cfmgr_decimal_normalize 00008 || exit 1\n"
        "cfmgr_decimal_compare 4294967296 2147483647 || exit 2\n"
        "cfmgr_uint31 0002147483647 || exit 3\n"
        "if cfmgr_uint31 2147483648; then exit 4; fi\n"
        "cfmgr_version_compare 1.4294967296.0 1.2147483647.9 || exit 5\n"
        "cfmgr_sha256_normalize AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n"
    )
    assert result.returncode == 0
    assert result.stdout.splitlines() == ["8", "1", "2147483647", "1", "a" * 64]
    assert result.stderr == ""
