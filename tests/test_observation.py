"""Supplied observation freshness policy; this does not acquire evidence."""

from __future__ import annotations

import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_ip import NativeShell, native_shell, run_shell

COMMON = Path(__file__).resolve().parents[1] / "modules/lib/common.sh"
SOURCE = Path(__file__).resolve().parents[1] / "modules/lib/observation.sh"
pytestmark = [
    pytest.mark.integration,
    pytest.mark.matrix("V44", evidence="host"),
]

BOOT_A = "00000000-0000-0000-0000-000000000001"
BOOT_B = "00000000-0000-0000-0000-000000000002"
ID_A = "a" * 64
ID_B = "b" * 64
FRESH = (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "105", "10", "6")


@pytest.fixture
def observation_shell(native_shell: NativeShell) -> NativeShell:
    router, _ = native_shell
    router.write("work/common.sh", COMMON.read_text(encoding="utf-8"))
    router.write("work/observation.sh", SOURCE.read_text(encoding="utf-8"))
    return native_shell


def expected_report(state: str, age: str, reason: str) -> str:
    body = f"observation-freshness\t1\t{state}\t{age}\t{reason}\n"
    return f"{body}end\t{len(body.encode('ascii'))}\n"


def shell_call(args: tuple[str, ...]) -> str:
    return " ".join(shlex.quote(value) for value in ("cfmgr_observation_freshness_report", *args))


def run_cases(
    observation_shell: NativeShell,
    cases: list[tuple[tuple[str, ...], tuple[str, str, str]]],
) -> str:
    calls = "\n".join(f"{shell_call(args)} || exit 70" for args, _ in cases)
    result = run_shell(
        observation_shell,
        '. "$CFMGR_TEST_ROOT/work/common.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/observation.sh"\n' + calls + "\n",
        [],
    )
    assert result.returncode == 0, result
    assert result.stderr == ""
    return result.stdout


@pytest.mark.usefixtures(native_shell.__name__)
def test_freshness_precedence_boundaries_and_exact_framing(
    observation_shell: NativeShell,
) -> None:
    cases = [
        (FRESH, ("current", "5", "fresh")),
        (
            ("-", "-", "-", "-", "-", "-", "-", "-", "10", "-"),
            ("unknown", "-", "boot-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "-", "7", ID_A, ID_A, "100", "105", "10", "6"),
            ("unknown", "-", "generation-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", "-", ID_A, "100", "105", "10", "6"),
            ("unknown", "-", "source-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "0", "0", ID_A, ID_A, "100", "100", "1", "forever"),
            ("current", "0", "fresh"),
        ),
        (
            (BOOT_A, BOOT_B, "7", "8", ID_A, ID_B, "100", "105", "10", "6"),
            ("stale", "-", "boot-changed"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "8", ID_A, ID_B, "100", "105", "10", "6"),
            ("stale", "-", "generation-changed"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_B, "100", "105", "10", "6"),
            ("stale", "-", "source-changed"),
        ),
        (
            (BOOT_A, BOOT_A, "-", "7", ID_A, ID_B, "100", "105", "10", "6"),
            ("stale", "-", "source-changed"),
        ),
        (
            ("-", BOOT_A, "7", "8", ID_A, ID_B, "100", "105", "10", "6"),
            ("stale", "-", "generation-changed"),
        ),
        (
            (BOOT_A, "-", "-", "-", "-", "-", "-", "-", "10", "6"),
            ("unknown", "-", "boot-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "-", "-", "-", "-", "-", "10", "6"),
            ("unknown", "-", "generation-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, "-", "-", "-", "10", "6"),
            ("unknown", "-", "source-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "-", "105", "10", "6"),
            ("unknown", "-", "clock-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "106", "105", "10", "6"),
            ("unknown", "-", "clock-regressed"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "110", "10", "-"),
            ("stale", "10", "max-age-expired"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "109", "10", "-"),
            ("unknown", "9", "lifetime-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "109", "10", "forever"),
            ("current", "9", "fresh"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "106", "20", "6"),
            ("stale", "6", "lifetime-expired"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "105", "20", "forever"),
            ("current", "5", "fresh"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "0", "2147483647", "86400", "forever"),
            ("stale", "2147483647", "max-age-expired"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "0", "86399", "86400", "forever"),
            ("current", "86399", "fresh"),
        ),
        (
            (
                BOOT_A,
                BOOT_A,
                "2147483647",
                "2147483647",
                ID_A,
                ID_A,
                "2147483646",
                "2147483647",
                "10",
                "2147483647",
            ),
            ("current", "1", "fresh"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "101", "1", "-"),
            ("stale", "1", "max-age-expired"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "100", "10", "0"),
            ("stale", "0", "lifetime-expired"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "100", "1", "-"),
            ("unknown", "0", "lifetime-unavailable"),
        ),
        (
            (BOOT_A, BOOT_A, "7", "7", ID_A, ID_A, "100", "-", "10", "0"),
            ("unknown", "-", "clock-unavailable"),
        ),
    ]
    expected = "".join(expected_report(*fields) for _, fields in cases)
    assert run_cases(observation_shell, cases) == expected


def test_all_inputs_are_validated_before_identity_or_clock_shortcuts(
    observation_shell: NativeShell,
) -> None:
    invalid_values = [
        "ABCDEF00-0000-0000-0000-000000000001",
        "0000000-00000-0000-0000-000000000001",
        "00",
        "2147483648",
        "g" * 64,
        "a" * 63,
        "00",
        "2147483648",
        "01",
        "2147483648",
    ]
    commands = []
    invalid_cases = [(index, invalid) for index, invalid in enumerate(invalid_values)]
    invalid_cases.extend(((8, "0"), (8, "86401"), (9, "00"), (9, "01")))
    for index, invalid in invalid_cases:
        args = list((BOOT_A, BOOT_B, "7", "8", ID_A, ID_B, "100", "105", "10", "6"))
        args[index] = invalid
        commands.append(
            f'{shell_call(tuple(args))} > "$RAM_ROOT/invalid.out"; status=$?; '
            '[ "$status" -eq 1 ] && [ ! -s "$RAM_ROOT/invalid.out" ] || exit 71'
        )
    for wrong_arity in ((), FRESH[:-1], (*FRESH, "extra")):
        commands.append(
            f'{shell_call(tuple(wrong_arity))} > "$RAM_ROOT/invalid.out"; status=$?; '
            '[ "$status" -eq 1 ] && [ ! -s "$RAM_ROOT/invalid.out" ] || exit 72'
        )
    result = run_shell(
        observation_shell,
        '. "$CFMGR_TEST_ROOT/work/common.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/observation.sh"\n' + "\n".join(commands) + "\n",
        [],
    )
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


def test_report_preserves_actual_scratch_caller_state_and_formatter_status(
    observation_shell: NativeShell,
) -> None:
    state = run_shell(
        observation_shell,
        """set -efu
set -- first 'two words'
IFS='|'
umask 027
export CFMGR_OBSERVATION_SENTINEL='original value'
_cfmgr_obs_boot=caller_boot
_cfmgr_obs_boot_remaining=caller_boot_remaining
_cfmgr_obs_group_length=caller_group_length
_cfmgr_obs_group=caller_group
_cfmgr_obs_number=caller_number
_cfmgr_obs_normalized=caller_normalized
_cfmgr_obs_id=caller_id
_cfmgr_obs_max_age=caller_max_age
_cfmgr_obs_valid_for=caller_valid_for
_cfmgr_obs_state=caller_state
_cfmgr_obs_age=caller_age
_cfmgr_obs_reason=caller_reason
_cfmgr_obs_row=caller_row
_cfmgr_obs_body_bytes=caller_body_bytes
trap ':' INT TERM
before_options=$-
before_umask=$(umask)
before_exports=$(export -p)
before_traps=$(trap)
. "$CFMGR_TEST_ROOT/work/common.sh"
. "$CFMGR_TEST_ROOT/work/observation.sh"
if cfmgr_observation_freshness_report "$@" >/dev/null 2>&1; then
    exit 75
else
    status=$?
fi
[ "$status" -eq 1 ] || exit 75
cfmgr_observation_freshness_report \
    00000000-0000-0000-0000-000000000001 00000000-0000-0000-0000-000000000001 \
    7 7 \
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    100 105 10 6 >/dev/null || exit 76
[ "$#" -eq 2 ] && [ "$1" = first ] && [ "$2" = 'two words' ] || exit 77
[ "$before_options" = "$-" ] && [ "$before_umask" = "$(umask)" ] || exit 78
[ "$before_exports" = "$(export -p)" ] && [ "$before_traps" = "$(trap)" ] || exit 79
[ "$IFS" = '|' ] && [ "$CFMGR_OBSERVATION_SENTINEL" = 'original value' ] || exit 80
[ "$_cfmgr_obs_boot" = caller_boot ] && \
    [ "$_cfmgr_obs_boot_remaining" = caller_boot_remaining ] || exit 81
[ "$_cfmgr_obs_group_length" = caller_group_length ] && \
    [ "$_cfmgr_obs_group" = caller_group ] || exit 82
[ "$_cfmgr_obs_number" = caller_number ] && \
    [ "$_cfmgr_obs_normalized" = caller_normalized ] || exit 83
[ "$_cfmgr_obs_id" = caller_id ] && [ "$_cfmgr_obs_max_age" = caller_max_age ] || exit 84
[ "$_cfmgr_obs_valid_for" = caller_valid_for ] && [ "$_cfmgr_obs_state" = caller_state ] || exit 85
[ "$_cfmgr_obs_age" = caller_age ] && [ "$_cfmgr_obs_reason" = caller_reason ] || exit 86
[ "$_cfmgr_obs_row" = caller_row ] && [ "$_cfmgr_obs_body_bytes" = caller_body_bytes ] || exit 87
[ "$before_traps" = "$(trap)" ] || exit 88
printf 'state-preserved\\n'
""",
        [],
    )
    assert state.returncode == 0, state
    assert state.stdout == "state-preserved\n"
    assert state.stderr == ""

    failures = run_shell(
        observation_shell,
        '. "$CFMGR_TEST_ROOT/work/common.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/observation.sh"\n'
        "printf() {\n"
        "  case $1 in\n"
        '    observation-freshness*) [ "$_printf_fail" != row ] || return 9 ;;\n'
        "    '%s\\nend\\t%s\\n') [ \"$_printf_fail\" != footer ] || return 9 ;;\n"
        "  esac\n"
        '  command printf "$@"\n'
        "}\n"
        "expect_format_failure() {\n"
        "  _printf_fail=$1; shift\n"
        '  "$@" > "$RAM_ROOT/format.out"; status=$?\n'
        '  [ "$status" -eq 1 ] && [ ! -s "$RAM_ROOT/format.out" ] || exit 89\n'
        "}\n"
        f"expect_format_failure row {shell_call(FRESH)}\n"
        f"expect_format_failure footer {shell_call(FRESH)}\n",
        [],
    )
    assert failures.returncode == 0, failures
    assert failures.stdout == failures.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V44", evidence="busybox")
def test_actual_busybox_composes_common_and_observation_report(
    busybox_router: RouterHarness,
) -> None:
    busybox_router.write("work/common.sh", COMMON.read_text(encoding="utf-8"))
    busybox_router.write("work/observation.sh", SOURCE.read_text(encoding="utf-8"))
    result = busybox_router.run(
        '. "$CFMGR_TEST_ROOT/work/common.sh"\n'
        '. "$CFMGR_TEST_ROOT/work/observation.sh"\n' + f"{shell_call(FRESH)}\n"
    )
    assert result.returncode == 0, result
    assert result.stdout == expected_report("current", "5", "fresh")
    assert result.stderr == ""
