"""Trusted process-group admission and native deadline supervision helpers."""

from __future__ import annotations

import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/worker.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def _deadline_api_script() -> str:
    return f". {shlex.quote(str(SOURCE))}\n"


def _deadline_guard(router: RouterHarness) -> Path:
    guard = router.path("ram/deadline-guard")
    guard.mkdir(mode=0o700)
    return guard


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
    poison_marker = router.path("work/poisoned-test-ran")
    router.write(
        "bin/[",
        f"#!/bin/sh\n: >{shlex.quote(str(poison_marker))}\n",
        executable=True,
    )
    router.write(
        "bin/test",
        f"#!/bin/sh\n: >{shlex.quote(str(poison_marker))}\n",
        executable=True,
    )
    stat_tail = "S 1 $_worker_test_pid 77 0 -1 " + " ".join(["0"] * 16)
    result = router.run(
        f"""enable -n '[' test 2>/dev/null || :
IFS=caller-ifs
PATH={shlex.quote(str(router.path("bin")))}
set -f; umask 027; trap ':' TERM
before=$(trap); options=$(set +o); before_path=$PATH
exec 6<{shlex.quote(str(caller_fd))}
IFS= read -r before_fd <&6
. {shlex.quote(str(SOURCE))}
command -v cfmgr_worker_group_check >/dev/null 2>&1 || exit 90
cfmgr_worker_group_check
status=$?
_worker_test_pid=$$
_worker_test_record="$_worker_test_pid (fixture worker) {stat_tail}"
_cfmgr_worker_stat_admitted "$_worker_test_record" "$_worker_test_pid" || exit 97
IFS= read -r after_fd <&6
case $- in *f*) : ;; *) exit 91 ;; esac
case $status in "$1") : ;; *) exit 92 ;; esac
case $before_fd:$after_fd:$IFS:$PATH in
    before:preserved:caller-ifs:"$before_path") : ;;
    *) exit 93 ;;
esac
case "$(umask)" in 0027) : ;; *) exit 94 ;; esac
case "$(trap)" in "$before") : ;; *) exit 95 ;; esac
case "$(set +o)" in "$options") : ;; *) exit 96 ;; esac
""",
        [str(expected)],
        timeout=3,
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert not poison_marker.exists()


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


@pytest.mark.parametrize(
    ("guard", "total", "grace", "callback", "extra"),
    [
        ("relative", "8", "1", "deadline_callback", ()),
        ("double-slash", "8", "1", "deadline_callback", ()),
        ("dot-component", "8", "1", "deadline_callback", ()),
        ("ok", "3", "1", "deadline_callback", ()),
        ("ok", "3601", "1", "deadline_callback", ()),
        ("ok", "08", "1", "deadline_callback", ()),
        ("ok", "8", "0", "deadline_callback", ()),
        ("ok", "8", "31", "deadline_callback", ()),
        ("ok", "8", "8", "deadline_callback", ()),
        ("ok", "8", "1", "bad-callback", ()),
        ("ok", "8", "1", "", ()),
    ],
    ids=[
        "relative-guard",
        "duplicate-slash",
        "dot-component",
        "total-too-small",
        "total-too-large",
        "noncanonical-total",
        "zero-grace",
        "grace-too-large",
        "grace-not-less-than-total",
        "invalid-callback-name",
        "empty-callback-name",
    ],
)
def test_deadline_public_api_rejects_malformed_arguments_without_effects(
    router: RouterHarness,
    guard: str,
    total: str,
    grace: str,
    callback: str,
    extra: tuple[str, ...],
) -> None:
    trusted_guard = _deadline_guard(router)
    selected_guard = {
        "relative": "relative/guard",
        "double-slash": str(trusted_guard).replace("/deadline-guard", "//deadline-guard"),
        "dot-component": str(trusted_guard).replace("/deadline-guard", "/./deadline-guard"),
        "ok": str(trusted_guard),
    }[guard]
    result = router.run(
        _deadline_api_script()
        + 'deadline_callback() { : >"$1"; }\n'
        + 'cfmgr_worker_deadline_with "$@"\n',
        [selected_guard, total, grace, callback, *extra, str(router.path("work/called"))],
        timeout=3,
    )
    assert result.returncode == 2 and result.stdout == result.stderr == ""
    assert not router.path("work/called").exists()
    assert trusted_guard.is_dir() and not (trusted_guard / "deadline").exists()


def test_deadline_refusal_before_watchdog_keeps_guard_and_skips_callback(
    router: RouterHarness,
) -> None:
    guard = _deadline_guard(router)
    result = router.run(
        _deadline_api_script()
        + "cfmgr_worker_group_check() { return 1; }\n"
        + 'deadline_callback() { : >"$1"; }\n'
        + 'cfmgr_worker_deadline_with "$@"\n',
        [str(guard), "8", "1", "deadline_callback", str(router.path("work/called"))],
        timeout=3,
    )
    assert result.returncode == 1 and result.stdout == result.stderr == ""
    assert not router.path("work/called").exists()
    assert guard.is_dir() and not (guard / "deadline").exists()


def test_deadline_public_api_rejects_missing_callback_argument(router: RouterHarness) -> None:
    guard = _deadline_guard(router)
    result = router.run(
        _deadline_api_script() + 'cfmgr_worker_deadline_with "$1" 8 1\n',
        [str(guard)],
        timeout=3,
    )
    assert result.returncode == 2 and result.stdout == result.stderr == ""
    assert guard.is_dir() and not (guard / "deadline").exists()


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("0", 0),
        ("1", 0),
        ("2147483647", 0),
        ("", 1),
        ("00", 1),
        ("01", 1),
        ("+1", 1),
        ("-1", 1),
        ("2147483648", 1),
        ("1x", 1),
    ],
    ids=[
        "zero",
        "one",
        "uint31-max",
        "empty",
        "leading-zeroes",
        "leading-zero",
        "plus",
        "negative",
        "overflow",
        "suffix",
    ],
)
def test_deadline_seconds_parser_accepts_only_canonical_uint31(
    router: RouterHarness, value: str, expected: int
) -> None:
    result = router.run(
        _deadline_api_script() + '_cfmgr_worker_deadline_seconds_valid "$1"\n',
        [value],
        timeout=3,
    )
    assert result.returncode == expected
    assert result.stdout == result.stderr == ""


@pytest.mark.parametrize(
    ("record", "expected_status", "expected_output"),
    [
        ("123.45 456.78\n", 0, "123\n"),
        ("2147483647.99 0.00\n", 0, "2147483647\n"),
        ("0.00 0.00\n", 0, "0\n"),
        ("", 1, ""),
        ("123.45 456.78", 1, ""),
        ("123.45 456.78\nextra\n", 1, ""),
        ("123.45\n", 1, ""),
        ("123.45 456.78 789.01\n", 1, ""),
        ("123.4 456.78\n", 1, ""),
        ("123.456 456.78\n", 1, ""),
        ("0123.45 456.78\n", 1, ""),
        ("2147483648.00 1.00\n", 1, ""),
        ("123.45 00.78\n", 1, ""),
    ],
    ids=[
        "valid-two-fields",
        "uint31-boundary",
        "zero-boundary",
        "empty",
        "missing-linefeed",
        "second-record",
        "missing-field",
        "extra-field",
        "one-fraction-digit",
        "three-fraction-digits",
        "leading-zero-seconds",
        "uint31-overflow",
        "leading-zero-second-whole",
    ],
)
def test_deadline_uptime_reader_requires_one_complete_canonical_record(
    router: RouterHarness, record: str, expected_status: int, expected_output: str
) -> None:
    clock_file = router.write("work/uptime-record", record)
    result = router.run(
        _deadline_api_script() + '_cfmgr_worker_deadline_clock_read 6<"$1"\n',
        [str(clock_file)],
        timeout=3,
    )
    assert result.returncode == expected_status
    assert result.stdout == expected_output and result.stderr == ""


def test_deadline_refresh_rejects_a_backward_clock_sample(router: RouterHarness) -> None:
    result = router.run(
        _deadline_api_script()
        + """_worker_deadline_epoch=100
_worker_deadline_last=101
_cfmgr_worker_deadline_clock_now() { printf '100\\n'; }
_cfmgr_worker_deadline_refresh
status=$?
case $status in 1) : ;; *) exit 90 ;; esac
case $_worker_deadline_last in 101) : ;; *) exit 91 ;; esac
""",
        timeout=3,
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""


def _callback_probe(router: RouterHarness) -> Path:
    return router.write(
        "work/deadline-callback.py",
        """import pathlib, sys
pathlib.Path(sys.argv[1]).write_text("\\n".join(sys.argv[2:]) + "\\n")
""",
        executable=True,
    )


def _successful_deadline_script(guard: Path, log: Path, caller_fd: Path) -> str:
    return f"""IFS=caller-ifs
PATH={shlex.quote(str(guard.parents[1] / "bin"))}
set -f; umask 027; trap ':' TERM
before_traps=$(trap); before_options=$(set +o); before_path=$PATH
exec 6<{shlex.quote(str(caller_fd))}
IFS= read -r before_fd <&6
. {shlex.quote(str(SOURCE))}
deadline_callback() {{
    [ -d {shlex.quote(str(guard / "deadline/armed"))} ] || return 91
    printf '%s\\n' "$#" >{shlex.quote(str(log))}
    printf '<%s>\\n' "$@" >>{shlex.quote(str(log))}
    "$2" "$3" "$4" "$5" "$6" "$7"
    return 7
}}
cfmgr_worker_deadline_with "$@"
status=$?
IFS= read -r after_fd <&6
case $- in *f*) : ;; *) exit 92 ;; esac
case $status in 7) : ;; *) exit 93 ;; esac
case $before_fd:$after_fd:$IFS:$PATH in
    before:preserved:caller-ifs:"$before_path") : ;;
    *) exit 94 ;;
esac
case "$(umask)" in 0027) : ;; *) exit 95 ;; esac
case "$(trap)" in "$before_traps") : ;; *) exit 96 ;; esac
case "$(set +o)" in "$before_options") : ;; *) exit 97 ;; esac
exit "$status"
"""


@pytest.mark.skipif(sys.platform != "linux", reason="requires Linux /proc and process groups")
def test_linux_deadline_callback_waits_for_armed_and_acknowledges_ordinary_status(
    router: RouterHarness,
) -> None:
    guard = _deadline_guard(router)
    probe = _callback_probe(router)
    log = router.path("work/callback.args")
    observed = router.path("work/callback.observed")
    caller_fd = router.write("work/deadline-caller-fd6", "before\npreserved\n")
    result = router.run(
        _successful_deadline_script(guard, log, caller_fd),
        [
            str(guard),
            "8",
            "1",
            "deadline_callback",
            str(log),
            str(sys.executable),
            str(probe),
            str(observed),
            "alpha beta",
            "*",
            "",
        ],
        timeout=12,
    )
    assert result.returncode == 7 and result.stdout == result.stderr == ""
    assert log.read_text(encoding="utf-8").splitlines() == [
        "7",
        f"<{log}>",
        f"<{sys.executable}>",
        f"<{probe}>",
        f"<{observed}>",
        "<alpha beta>",
        "<*>",
        "<>",
    ]
    assert observed.read_text(encoding="utf-8").splitlines() == ["alpha beta", "*", ""]
    deadline = guard / "deadline"
    assert (deadline / "armed").is_dir()
    assert (deadline / "done").is_dir()
    assert (deadline / "ack").is_dir()
    assert not (deadline / "cancel").exists()
    assert not (deadline / "expired").exists()
    assert guard.is_dir()


def _timeout_callback(router: RouterHarness) -> Path:
    return router.write(
        "work/deadline-hang.py",
        """import pathlib, signal, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
pathlib.Path(sys.argv[1]).write_text("started\\n")
while True:
    time.sleep(0.05)
""",
        executable=True,
    )


@pytest.mark.skipif(sys.platform != "linux", reason="requires Linux /proc and process groups")
def test_linux_deadline_cancels_term_ignoring_callback_and_retains_expiry(
    router: RouterHarness,
) -> None:
    guard = _deadline_guard(router)
    callback = _timeout_callback(router)
    started = router.path("work/callback-started")
    result = router.run(
        "trap ':' TERM\nexec 9>&1\n"
        + _deadline_api_script()
        + """deadline_callback() { "$1" "$2" "$3"; }
cfmgr_worker_deadline_with "$@"
""",
        [
            str(guard),
            "4",
            "1",
            "deadline_callback",
            str(sys.executable),
            str(callback),
            str(started),
        ],
        timeout=10,
    )
    deadline = guard / "deadline"
    assert started.read_text(encoding="utf-8") == "started\n"
    assert (deadline / "armed").is_dir()
    assert (deadline / "expired").is_dir()
    assert (deadline / "cancel").is_dir()
    assert not (deadline / "ack").exists()
    assert result.returncode == -9
    assert result.stdout == result.stderr == ""
    assert guard.is_dir()


@pytest.mark.skipif(sys.platform != "linux", reason="requires Linux /proc and process groups")
def test_linux_deadline_late_clock_failure_is_uncertain_and_cancels_group(
    router: RouterHarness,
) -> None:
    guard = _deadline_guard(router)
    clock_file = router.write("work/deadline-clock", "good\n")
    callback_started = router.path("work/clock-failure-callback")
    script = (
        "trap ':' TERM\nexec 9>&1\n"
        + _deadline_api_script()
        + f"""_worker_test_clock_file={shlex.quote(str(clock_file))}
_cfmgr_worker_deadline_clock_now() {{
    IFS= read -r _worker_test_clock <"$_worker_test_clock_file" || return 1
    case $_worker_test_clock in good) printf '100\\n' ;; *) return 1 ;; esac
}}
deadline_callback() {{
    : >{shlex.quote(str(callback_started))}
    printf 'broken\\n' >"$_worker_test_clock_file"
    return 0
}}
cfmgr_worker_deadline_with "$@"
"""
    )
    result = router.run(
        script,
        [str(guard), "8", "1", "deadline_callback"],
        timeout=8,
    )
    deadline = guard / "deadline"
    assert callback_started.is_file()
    assert (deadline / "armed").is_dir()
    assert (deadline / "cancel").is_dir()
    assert not (deadline / "ack").exists()
    assert result.returncode == -9
    assert result.stdout == result.stderr == ""
    assert guard.is_dir()


@pytest.mark.skipif(sys.platform != "linux", reason="requires Linux /proc and process groups")
def test_linux_deadline_ack_producer_failure_cancels_despite_valid_marker(
    router: RouterHarness,
) -> None:
    guard = _deadline_guard(router)
    ack_marker = guard / "deadline/ack"
    mkdir_wrapper = router.write(
        "bin/mkdir-fail-ack",
        f"""#!/bin/sh
_fail_ack=0
for _arg do
    case $_arg in {shlex.quote(str(ack_marker))}) _fail_ack=1 ;; esac
done
/bin/mkdir "$@" || exit $?
case $_fail_ack in 1) exit 1 ;; esac
exit 0
""",
        executable=True,
    )
    callback_started = router.path("work/ack-failure-callback")
    result = router.run(
        "trap ':' TERM\nexec 9>&1\n"
        + _deadline_api_script()
        + f"""_cfmgr_worker_deadline_tools() {{
    _worker_deadline_mkdir={shlex.quote(str(mkdir_wrapper))}
    _worker_deadline_sleep=/bin/sleep
}}
deadline_callback() {{ : >{shlex.quote(str(callback_started))}; return 0; }}
cfmgr_worker_deadline_with "$@"
""",
        [str(guard), "8", "1", "deadline_callback"],
        timeout=10,
    )
    deadline = guard / "deadline"
    assert callback_started.is_file()
    assert all((deadline / name).is_dir() for name in ("armed", "done", "ack", "cancel"))
    assert not (deadline / "expired").exists()
    assert result.returncode == -9
    assert result.stdout == result.stderr == ""
    assert guard.is_dir()


def _hup_callback(router: RouterHarness) -> Path:
    return router.write(
        "work/deadline-hup.py",
        """import os, pathlib, signal, sys, time
signal.signal(signal.SIGHUP, signal.SIG_IGN)
signal.signal(signal.SIGTERM, signal.SIG_IGN)
pathlib.Path(sys.argv[1]).write_text("started\\n")
os.killpg(0, signal.SIGHUP)
while True:
    time.sleep(0.05)
""",
        executable=True,
    )


@pytest.mark.skipif(sys.platform != "linux", reason="requires Linux /proc and process groups")
def test_linux_deadline_group_hup_cancels_and_kills_hung_callback(
    router: RouterHarness,
) -> None:
    guard = _deadline_guard(router)
    callback = _hup_callback(router)
    started = router.path("work/hup-callback-started")
    result = router.run(
        "trap ':' HUP TERM\nexec 9>&1\n"
        + _deadline_api_script()
        + """deadline_callback() { exec "$1" "$2" "$3"; }
cfmgr_worker_deadline_with "$@"
""",
        [
            str(guard),
            "4",
            "1",
            "deadline_callback",
            str(sys.executable),
            str(callback),
            str(started),
        ],
        timeout=10,
    )
    deadline = guard / "deadline"
    assert started.read_text(encoding="utf-8") == "started\n"
    assert (deadline / "armed").is_dir()
    assert (deadline / "cancel").is_dir()
    assert not (deadline / "ack").exists()
    assert result.returncode == -9
    assert result.stdout == result.stderr == ""
    assert guard.is_dir()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_deadline_callback_runs_after_armed_and_acknowledges(
    busybox_router: RouterHarness,
) -> None:
    guard = _deadline_guard(busybox_router)
    observed = busybox_router.path("work/busybox-callback")
    script = (
        _deadline_api_script()
        + f"""deadline_callback() {{
    [ -d {shlex.quote(str(guard / "deadline/armed"))} ] || return 91
    printf '<%s>\\n' "$@" >{shlex.quote(str(observed))}
}}
cfmgr_worker_deadline_with "$@"
"""
    )
    result = busybox_router.run(
        script,
        [str(guard), "8", "1", "deadline_callback", "busybox", "with spaces", "*"],
        timeout=12,
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert observed.read_text(encoding="utf-8").splitlines() == [
        "<busybox>",
        "<with spaces>",
        "<*>",
    ]
    deadline = guard / "deadline"
    assert all((deadline / name).is_dir() for name in ("armed", "done", "ack"))
    assert not (deadline / "cancel").exists()
