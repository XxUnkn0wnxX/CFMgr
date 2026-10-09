"""Read-only top-level process-group admission for trusted shell callers."""

from __future__ import annotations

import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/worker.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def stat_record(
    pid: str = "123",
    comm: str = "cfmgr worker",
    *,
    pgrp: str = "123",
    session: str = "987",
    state: str = "S",
) -> str:
    tail = [state, "1", pgrp, session, "0", "-1", *(["0"] * 16)]
    assert len(tail) == 22
    return f"{pid} ({comm}) " + " ".join(tail)


def admit(router: RouterHarness, record: str, expected_pid: str = "123") -> int:
    result = router.run(
        f'. {shlex.quote(str(SOURCE))}\n_cfmgr_worker_stat_admitted "$1" "$2"\n',
        [record, expected_pid],
        timeout=3,
    )
    return result.returncode


@pytest.mark.parametrize(
    "record",
    [
        "",
        "0123 (leading zero) " + " ".join(["S", "1", "123", "1", *(["0"] * 18)]),
        stat_record(pid="0", pgrp="0"),
        stat_record(pid="2147483648", pgrp="2147483648"),
        stat_record(pgrp="0"),
        stat_record(pgrp="0123"),
        stat_record(pgrp="2147483648"),
        stat_record(state="?"),
        "123 command " + " ".join(["S", "1", "123", "1", *(["0"] * 18)]),
        "123 (missing close " + " ".join(["S", "1", "123", "1", *(["0"] * 18)]),
        stat_record() + "\n" + stat_record(),
        "123 (truncated) S 1 123 1",
        "x" * 4097,
    ],
    ids=[
        "empty",
        "noncanonical-pid",
        "zero-pid",
        "pid-overflow",
        "zero-group",
        "noncanonical-group",
        "group-overflow",
        "invalid-state",
        "missing-open-delimiter",
        "missing-close-delimiter",
        "multiline",
        "truncated-suffix",
        "oversized",
    ],
)
def test_internal_stat_parser_rejects_malformed_records(router: RouterHarness, record: str) -> None:
    assert admit(router, record) == 1


def test_internal_stat_parser_uses_last_delimiter_and_ignores_session_id(
    router: RouterHarness,
) -> None:
    record = stat_record(comm="worker with (inner) ) text", session="77")
    assert admit(router, record) == 0
    assert admit(router, stat_record(pgrp="124")) == 1
    assert admit(router, stat_record(), expected_pid="124") == 1


def test_internal_stat_parser_accepts_maximum_pid_boundary(router: RouterHarness) -> None:
    pid = "2147483647"
    assert admit(router, stat_record(pid=pid, pgrp=pid), expected_pid=pid) == 0


def test_internal_reader_requires_one_terminated_record_and_restores_fd6(
    router: RouterHarness,
) -> None:
    tail = "S 1 $_worker_test_pid 77 0 -1 " + " ".join(["0"] * 16)
    valid_path = shlex.quote(str(router.path("work/valid-stat")))
    multiple_path = shlex.quote(str(router.path("work/multiple-stat")))
    unterminated_path = shlex.quote(str(router.path("work/unterminated-stat")))
    empty_path = shlex.quote(str(router.path("work/empty-stat")))
    caller_path = shlex.quote(str(router.path("work/caller-fd6")))
    result = router.run(
        f""". {shlex.quote(str(SOURCE))}
_worker_test_pid=$$
_worker_test_record="$_worker_test_pid (fixture worker (inner)) {tail}"
printf '%s\\n' "$_worker_test_record" >{valid_path}
printf '%s\\n%s\\n' "$_worker_test_record" "$_worker_test_record" >{multiple_path}
printf '%s' "$_worker_test_record" >{unterminated_path}
: >{empty_path}
printf 'before\\npreserved\\n' >{caller_path}
exec 6<{caller_path}
IFS= read -r _worker_before <&6
_cfmgr_worker_read_current 6<{valid_path}
_worker_valid=$?
_cfmgr_worker_read_current 6<{multiple_path}
_worker_multiple=$?
_cfmgr_worker_read_current 6<{unterminated_path}
_worker_unterminated=$?
_cfmgr_worker_read_current 6<{empty_path}
_worker_empty=$?
IFS= read -r _worker_after <&6
[ "$_worker_before" = before ] && [ "$_worker_after" = preserved ] &&
[ "$_worker_valid" = 0 ] && [ "$_worker_multiple" = 1 ] &&
[ "$_worker_unterminated" = 1 ] && [ "$_worker_empty" = 1 ]
""",
        timeout=3,
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""


def test_source_only_api_and_public_caller_state_are_preserved(router: RouterHarness) -> None:
    expected = 0 if sys.platform == "linux" else 1
    caller_fd = router.write("work/public-caller-fd", "before\npreserved\n")
    result = router.run(
        f"""IFS=caller-ifs; set -f; umask 027; trap ':' TERM
before=$(trap); options=$(set +o)
exec 6<{shlex.quote(str(caller_fd))}
IFS= read -r before_fd <&6
. {shlex.quote(str(SOURCE))}
command -v cfmgr_worker_group_check >/dev/null 2>&1 || exit 90
cfmgr_worker_group_check
status=$?
IFS= read -r after_fd <&6
case $- in *f*) : ;; *) exit 91 ;; esac
[ "$status" = "$1" ] && [ "$before_fd" = before ] && [ "$after_fd" = preserved ] &&
[ "$IFS" = caller-ifs ] &&
[ "$(umask)" = 0027 ] && [ "$(trap)" = "$before" ] && [ "$(set +o)" = "$options" ]
""",
        [str(expected)],
        timeout=3,
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""


def test_public_api_rejects_arguments(router: RouterHarness) -> None:
    result = router.run(
        f". {shlex.quote(str(SOURCE))}\n"
        'cfmgr_worker_group_check unexpected; status=$?; printf "%s\\n" "$status"\n',
        timeout=3,
    )
    assert result.returncode == 0 and result.stdout == "2\n" and result.stderr == ""


@pytest.mark.skipif(sys.platform != "linux", reason="requires Linux /proc and process groups")
def test_actual_linux_leader_passes_but_nested_shell_is_rejected(router: RouterHarness) -> None:
    result = router.run(
        f""". {shlex.quote(str(SOURCE))}
cfmgr_worker_group_check
leader=$?
(
    cfmgr_worker_group_check
    nested=$?
    printf 'NESTED\\t%s\\n' "$nested"
)
printf 'LEADER\\t%s\\n' "$leader"
""",
        timeout=3,
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "NESTED\t1\nLEADER\t0\n"


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_top_level_shell_is_admitted(busybox_router: RouterHarness) -> None:
    assert busybox_router.busybox is not None
    script = f""". {shlex.quote(str(SOURCE))}
cfmgr_worker_group_check || exit 90
(
    cfmgr_worker_group_check
    nested=$?
    [ "$nested" = 1 ] || exit 91
)
"""
    result = busybox_router.run(script, timeout=3)
    assert result.returncode == 0 and result.stdout == result.stderr == ""
