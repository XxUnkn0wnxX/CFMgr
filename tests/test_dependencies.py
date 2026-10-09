"""Serialized bounded dependency-worker contract at its consumer boundaries."""

from __future__ import annotations

import os
import shlex
import signal
import subprocess
import sys
import time
from contextlib import suppress
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "modules/lib"
HELPER = ROOT / "modules/helpers/dependencies.sh"
SOURCES = (
    "io.sh",
    "storage.sh",
    "dependency_lock.sh",
    "entware.sh",
    "native_config.sh",
    "isolation.sh",
    "entware_root.sh",
    "native_devices.sh",
    "native_config_root.sh",
    "native_exec.sh",
    "native_dependencies.sh",
)
UUID = "12345678-1234-1234-1234-123456789abc"
HEX_TARGET = "2f757372"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


DETACHED_CHILD = """import os
import sys
import time
from pathlib import Path

pid_record, ready, request, response, lock = map(Path, sys.argv[1:])
held, expected = os.fstat(7), lock.stat()
assert (held.st_dev, held.st_ino) == (expected.st_dev, expected.st_ino)
os.close(7)
deadline = time.monotonic() + 30
pending_pid = pid_record.with_suffix(".starting")
pending_pid.write_text(f"{os.getpid()}\\n")
pending_pid.replace(pid_record)
# Stay in the worker group until the test knows our exact PID. An interrupted
# readiness wait can therefore clean the group without losing a detached actor.
while not request.exists() or request.read_text() != "detach\\n":
    if time.monotonic() >= deadline:
        raise SystemExit(1)
    time.sleep(0.01)
os.setsid()
ready.write_text(f"{os.getpid()} {os.getpgrp()} {os.getsid(0)}\\n")
while time.monotonic() < deadline:
    if request.exists():
        response.write_text(request.read_text())
    time.sleep(0.01)
"""


def _fixture(
    router: RouterHarness,
    *,
    ramroot: Path | None = None,
    guard_name: str = "guard",
) -> tuple[str, list[str], Path, Path, Path]:
    if ramroot is None:
        ramroot = router.path("ram/dependencies")
        ramroot.mkdir(mode=0o700)
    guard = ramroot / guard_name
    guard.mkdir(mode=0o700)
    mount_parser = router.write("work/mount-parser.awk", "# trusted fixture parser\n")
    storage_parser = router.write("work/storage-parser.awk", "# trusted fixture parser\n")
    bootstrap = router.write("work/bootstrap.sh", "# immutable synthetic bundled source\n")
    caller_fd = router.write("work/caller-fd", "before\nafter\n")
    flock_code = (
        "import fcntl, sys; assert sys.argv[1:] == ['-n', '7']; "
        "fcntl.flock(7, fcntl.LOCK_EX | fcntl.LOCK_NB)"
    )
    flock = router.write(
        "bin/flock",
        f'#!/bin/sh\nexec {shlex.quote(sys.executable)} -c {shlex.quote(flock_code)} "$@"\n',
        executable=True,
    )
    log = router.path("work/dependencies.log")
    child_pid = router.path("work/live-child.pid")
    child_ready = router.path("work/live-child.ready")
    child_request = router.path("work/live-child.request")
    child_response = router.path("work/live-child.response")
    child = router.write("work/detached-child.py", DETACHED_CHILD)
    child_command = shlex.join(
        [
            sys.executable,
            str(child),
            str(child_pid),
            str(child_ready),
            str(child_request),
            str(child_response),
            str(ramroot / "dependencies.lock"),
        ]
    )
    rmdir_refusal = router.write(
        "bin/rmdir-refusal",
        "#!/bin/sh\n"
        '[ "$#" -eq 1 ] && '
        '[ "$1" = "$_dependencies_test_ramroot/dependencies.active" ] || exit 90\n'
        '[ ! -e "$1/owner" ] && [ ! -L "$1/owner" ] || exit 91\n'
        'printf "rmdir-refused\\n" >>"$_dependencies_test_log"\n'
        "exit 1\n",
        executable=True,
    )
    sources = "\n".join(f". {shlex.quote(str(LIB / name))}" for name in SOURCES)
    sources += f"\n. {shlex.quote(str(ROOT / 'modules/helpers/worker.sh'))}"
    sources += f"\n. {shlex.quote(str(HELPER))}"
    script = f"""{sources}
if [ ! -r /proc/self/stat ]; then
    # macOS host runs lack the Linux proc snapshot; retain the real admission
    # check on Linux and let the kernel integration own its behavioral proof.
    cfmgr_worker_group_check() {{ return 0; }}
fi
_dependencies_test_log={shlex.quote(str(log))}
_dependencies_test_guard={shlex.quote(str(guard))}
_dependencies_test_ramroot={shlex.quote(str(ramroot))}
_dependencies_test_target={HEX_TARGET}
_dependencies_test_ledger=verified-volume-ledger
_dependencies_test_flock={shlex.quote(str(flock))}
_dependencies_test_backend_status=${{CFMGR_TEST_BACKEND_STATUS-0}}
_dependencies_test_behavior=${{CFMGR_TEST_BEHAVIOR-normal}}
export _dependencies_test_log _dependencies_test_guard _dependencies_test_ramroot
export _dependencies_test_target _dependencies_test_ledger _dependencies_test_flock
export _dependencies_test_backend_status _dependencies_test_behavior
exec 8<{shlex.quote(str(caller_fd))}

_dependencies_test_log_event() {{ printf '%s\\n' "$1" >>"$_dependencies_test_log"; }}

# Keep real lock validation, FD7 acquisition and callback forwarding, while
# allowing a deterministic refusal case without a second process fixture.
cfmgr_dependency_lock_with() {{
    _dependencies_test_log_event lock-call-$#
    [ "$#" -eq 17 ] && [ "$1" = "$_dependencies_test_ramroot" ] &&
        [ "$2" = _cfmgr_worker_dependencies_locked ] || return 90
    if [ "$_dependencies_test_behavior" = lock-refusal ]; then
        _dependencies_test_log_event lock-refused
        return 1
    elif [ "$_dependencies_test_behavior" = lock-early-zero ]; then
        _dependencies_test_log_event lock-early-zero
        return 0
    elif [ "$_dependencies_test_behavior" = owner-exit-0 ]; then
        exit 0
    elif [ "$_dependencies_test_behavior" = owner-exit-16 ]; then
        exit 16
    elif [ "$_dependencies_test_behavior" = owner-exit-17 ]; then
        exit 17
    fi
    shift 2
    cfmgr_dependency_lock_with_test "$_dependencies_test_ramroot" "$_dependencies_test_flock" \
        _dependencies_test_locked_dispatch "$@"
}}

# Model the deadline handshake cheaply, preserving its callback and records.
_cfmgr_worker_deadline_owner() {{
    [ "$#" -eq 19 ] && [ "$2" = "$_dependencies_test_guard" ] &&
        [ "$5" = _cfmgr_worker_dependencies_run ] || return 89
    _dependencies_test_leader=$1 _dependencies_test_total=$3 _dependencies_test_grace=$4
    shift 4
    /bin/mkdir -m 700 "$_dependencies_test_guard/deadline" || return 91
    /bin/mkdir -m 700 "$_dependencies_test_guard/deadline/armed" || return 92
    _dependencies_test_log_event deadline-armed
    if [ "$_dependencies_test_behavior" = deadline-early-zero ]; then
        _dependencies_test_log_event deadline-early-zero
        return 0
    fi
    "$@"
    _dependencies_test_deadline_status=$?
    if [ "$_dependencies_test_behavior" = owner-loss ]; then
        _dependencies_test_log_event owner-lost
        {child_command} &
        while :; do /bin/sleep 1; done
    fi
    if [ "$_dependencies_test_deadline_status" -le 128 ]; then
        /bin/mkdir -m 700 "$_dependencies_test_guard/deadline/done" || return 93
        if [ "$_dependencies_test_behavior" != deadline-no-ack ]; then
            /bin/mkdir -m 700 "$_dependencies_test_guard/deadline/ack" || return 94
            _dependencies_test_log_event deadline-ack
        fi
    fi
    return "$_dependencies_test_deadline_status"
}}

_dependencies_test_locked_dispatch() {{
    _dependencies_test_log_event locked-enter
    if [ "$_dependencies_test_behavior" = release-rmdir-failure ]; then
        _dependencies_rmdir={shlex.quote(str(rmdir_refusal))}
    fi
    _cfmgr_worker_dependencies_locked "$@"
}}

# The original storage/root authorities are represented by narrow, ordered
# seams. Their callbacks and the worker's record framing remain real.
cfmgr_entware_with() {{
    [ "$#" -eq 16 ] && [ "$6" = _cfmgr_worker_dependencies_storage ] || return 88
    _dependencies_test_log_event storage-acquire
    if [ "$_dependencies_test_behavior" = storage-early-zero ]; then
        _dependencies_test_log_event storage-cleanup
        return 0
    fi
    _dependencies_test_storage_callback=$6
    shift 6
    "$_dependencies_test_storage_callback" "$_dependencies_test_target" \\
        "$_dependencies_test_ledger" "$@"
    _dependencies_test_storage_status=$?
    _dependencies_test_log_event storage-cleanup
    if [ "$_dependencies_test_behavior" = storage-cleanup-failure ]; then return 1; fi
    return "$_dependencies_test_storage_status"
}}

cfmgr_isolation_native_config_root_with() {{
    [ "$#" -eq 14 ] && [ "$9" = _cfmgr_worker_dependencies_root ] || return 87
    _dependencies_test_log_event root-enter
    [ "${{10}}" = "$4" ] || return 87
    "$9" "$1" root-ledger "$2" "$4" "${{11}}" "${{12}}" "${{13}}" "${{14}}"
    _dependencies_test_root_status=$?
    _dependencies_test_log_event root-cleanup
    if [ "$_dependencies_test_behavior" = root-cleanup-failure ]; then return 1; fi
    return "$_dependencies_test_root_status"
}}

# Publish only the backend's documented exact evidence, or selected corrupt
# evidence, so the actual worker result reader has a non-vacuous oracle.
cfmgr_native_dependencies() {{
    [ "$#" -eq 5 ] || return 86
    _dependencies_test_log_event backend
    /bin/mkdir -m 700 "$_dependencies_test_guard/execution" || return 85
    /bin/mkdir -m 700 "$_dependencies_test_guard/execution/complete" || return 84
    /bin/mkdir -m 700 "$_dependencies_test_guard/execution/dependencies" || return 84
    _dependencies_test_status=$_dependencies_test_guard/execution/dependencies/status
    case $_dependencies_test_behavior in
    backend-missing) return "$_dependencies_test_backend_status" ;;
    backend-mismatch)
        printf 'dependencies repair shared native 1\\n' >"$_dependencies_test_status"
        /bin/mkdir -m 700 "$_dependencies_test_guard/execution/dependencies/complete" || return 83
        ;;
    backend-partial)
        printf 'dependencies repair shared native 0' >"$_dependencies_test_status"
        /bin/mkdir -m 700 "$_dependencies_test_guard/execution/dependencies/complete" || return 83
        ;;
    *)
        printf 'dependencies %s %s %s %s\\n' "$3" "$4" "$5" \
            "$_dependencies_test_backend_status" >"$_dependencies_test_status"
        /bin/mkdir -m 700 "$_dependencies_test_guard/execution/dependencies/complete" || return 83
        ;;
    esac
    if [ "$_dependencies_test_behavior" = release-foreign-entry ]; then
        printf 'unowned\\n' >"$_dependencies_test_ramroot/dependencies.active/foreign" || return 82
    fi
    return "$_dependencies_test_backend_status"
}}
"""
    args = [
        str(ramroot),
        str(guard),
        "10",
        "2",
        "64",
        "128",
        str(mount_parser),
        str(storage_parser),
        UUID,
        HEX_TARGET,
        str(bootstrap),
        "repair",
        "shared",
        "native",
    ]
    return script, args, log, guard, ramroot


def _run(
    router: RouterHarness,
    *,
    env: dict[str, str] | None = None,
    behavior: str = "normal",
    backend_status: int = 0,
    call: str | None = None,
    args: list[str] | None = None,
) -> tuple[ShellResult, Path, Path, Path]:
    script, default_args, log, guard, ramroot = _fixture(router)
    if call is None:
        call = _call()
    fixture_env = {
        "CFMGR_TEST_BEHAVIOR": behavior,
        "CFMGR_TEST_BACKEND_STATUS": str(backend_status),
        **(env or {}),
    }
    result = router.run(
        script + call,
        default_args if args is None else args,
        env=fixture_env,
        timeout=5,
    )
    return result, log, guard, ramroot


def _call() -> str:
    return (
        "_dependencies_test_cwd=$PWD\n"
        "IFS= read -r _dependencies_test_fd_before <&8\n"
        'cfmgr_worker_dependencies "$@"; status=$?\n'
        "IFS= read -r _dependencies_test_fd_after <&8\n"
        '[ "$PWD" = "$_dependencies_test_cwd" ] &&\n'
        '[ "$_dependencies_test_fd_before:$_dependencies_test_fd_after" = before:after ] '
        "|| exit 71\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )


def _assert_result(result: ShellResult, status: int) -> None:
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{status}\n" and result.stderr == "", result


@pytest.mark.parametrize(
    ("invalid", "expected"),
    [("selector", 2), ("missing-source", 1)],
    ids=["invalid-selector", "unavailable-bundled-source"],
)
def test_api_refuses_invalid_selector_or_unavailable_source_before_effects(
    router: RouterHarness, invalid: str, expected: int
) -> None:
    script, args, log, _, ramroot = _fixture(router)
    if invalid == "selector":
        args[12] = "all"
    else:
        args[10] = str(router.path("work/missing-bootstrap.sh"))

    result = router.run(script + _call(), args, timeout=5)

    _assert_result(result, expected)
    assert not (ramroot / "dependencies.lock").exists()
    assert not (ramroot / "dependencies.active").exists()
    assert not log.exists()


@pytest.mark.parametrize("backend_status", [0, 1], ids=["completed-success", "completed-negative"])
def test_completed_backend_outcomes_release_only_after_cleanup_and_ack(
    router: RouterHarness, backend_status: int
) -> None:
    result, log, guard, ramroot = _run(router, backend_status=backend_status)

    _assert_result(result, backend_status)
    assert log.read_text(encoding="utf-8").splitlines() == [
        "lock-call-17",
        "locked-enter",
        "deadline-armed",
        "storage-acquire",
        "root-enter",
        "backend",
        "root-cleanup",
        "storage-cleanup",
        "deadline-ack",
    ]
    assert (guard / "dependencies-result").read_bytes() == (
        f"CFMGR_WORKER_DEPENDENCIES_V1 {backend_status}\n".encode("ascii")
    )
    assert (guard / "root-returned").is_dir() and list((guard / "root-returned").iterdir()) == []
    assert (guard / "storage-returned").is_dir() and list(
        (guard / "storage-returned").iterdir()
    ) == []
    assert (guard / "deadline/done").is_dir() and (guard / "deadline/ack").is_dir()
    assert not (ramroot / "dependencies.active").exists()
    lock = ramroot / "dependencies.lock"
    assert lock.is_file() and not lock.is_symlink()


@pytest.mark.parametrize(
    ("behavior", "backend_status", "expected"),
    [
        ("lock-refusal", 0, 1),
        ("lock-early-zero", 0, 129),
        ("owner-exit-0", 0, 129),
        ("owner-exit-16", 0, 129),
        ("owner-exit-17", 0, 129),
        ("deadline-early-zero", 0, 129),
        ("deadline-no-ack", 0, 129),
        ("storage-early-zero", 0, 129),
        ("storage-cleanup-failure", 0, 129),
        ("root-cleanup-failure", 0, 129),
        ("backend-missing", 0, 129),
        ("backend-mismatch", 0, 129),
        ("backend-partial", 0, 129),
        ("release-foreign-entry", 0, 129),
        ("release-rmdir-failure", 0, 129),
    ],
)
def test_unproved_completion_and_cleanup_never_release_active_marker(
    router: RouterHarness, behavior: str, backend_status: int, expected: int
) -> None:
    result, log, guard, ramroot = _run(router, behavior=behavior, backend_status=backend_status)

    _assert_result(result, expected)
    active = ramroot / "dependencies.active"
    if behavior in {
        "lock-refusal",
        "lock-early-zero",
        "owner-exit-0",
        "owner-exit-16",
        "owner-exit-17",
    }:
        assert not active.exists()
        assert not (guard / "execution").exists()
    elif behavior == "deadline-early-zero":
        assert not active.exists()
    elif behavior == "release-rmdir-failure":
        assert active.is_dir() and list(active.iterdir()) == []
        assert (guard / "deadline/ack").is_dir()
        assert log.read_text(encoding="utf-8").splitlines()[-1] == "rmdir-refused"
    else:
        assert active.is_dir() and not active.is_symlink()
        assert (active / "owner").read_bytes() == (
            f"CFMGR_DEPENDENCIES_OWNER_V1\n{guard}\n".encode("ascii")
        )
        if behavior == "release-foreign-entry":
            assert (active / "foreign").read_bytes() == b"unowned\n"
        if behavior == "backend-partial":
            assert (guard / "execution/dependencies/status").read_bytes() == (
                b"dependencies repair shared native 0"
            )


@pytest.mark.parametrize("marker_kind", ["regular", "symlink", "partial-directory"])
def test_foreign_active_marker_is_preserved_and_blocks_backend(
    router: RouterHarness, marker_kind: str
) -> None:
    script, args, log, guard, ramroot = _fixture(router)
    active = ramroot / "dependencies.active"
    if marker_kind == "regular":
        active.write_bytes(b"foreign marker bytes\n")
    elif marker_kind == "symlink":
        target = router.write("work/foreign-active-target", "target bytes\n")
        active.symlink_to(target)
    else:
        active.mkdir(mode=0o700)
        (active / "owner").write_bytes(b"partial record")
        (active / "foreign").write_bytes(b"leave this evidence\n")

    result = router.run(
        script + 'cfmgr_worker_dependencies "$@"; status=$?\nprintf "RESULT\\t%s\\n" "$status"\n',
        args,
        timeout=5,
    )

    _assert_result(result, 129)
    if marker_kind == "regular":
        assert active.read_bytes() == b"foreign marker bytes\n"
    elif marker_kind == "symlink":
        assert active.is_symlink() and active.resolve().read_bytes() == b"target bytes\n"
    else:
        assert (active / "owner").read_bytes() == b"partial record"
        assert (active / "foreign").read_bytes() == b"leave this evidence\n"
    assert log.read_text(encoding="utf-8").splitlines() == ["lock-call-17", "locked-enter"]
    assert not (guard / "execution").exists()


def _group_members(group: int) -> list[tuple[int, str]]:
    """Native ps works on macOS/Linux and includes zombies during reap."""
    snapshot = subprocess.run(
        ["/bin/ps", "-A", "-o", "pid=,pgid=,stat="],
        capture_output=True,
        text=True,
        check=True,
        timeout=1,
    )
    members = []
    for row in snapshot.stdout.splitlines():
        pid, pgid, state = row.split()
        if int(pgid) == group:
            members.append((int(pid), state))
    return members


def _assert_group_gone(group: int) -> None:
    deadline = time.monotonic() + 1
    while time.monotonic() < deadline:
        if not _group_members(group):
            return
        time.sleep(0.01)
    pytest.fail(f"owned fixture group {group} survived cleanup: {_group_members(group)}")


def _stop_detached_group(group: int) -> None:
    if not _group_members(group):
        return
    # Darwin can exclude actors in the kernel's exit transition from killpg.
    # Accept only bounded native-ps absence, never kill0 alone.
    with suppress(ProcessLookupError, PermissionError):
        os.killpg(group, signal.SIGKILL)
    _assert_group_gone(group)


def _assert_child_responds(router: RouterHarness, nonce: str) -> None:
    request = router.path("work/live-child.request")
    response = router.path("work/live-child.response")
    expected = nonce + "\n"
    request.write_text(expected, encoding="ascii")
    deadline = time.monotonic() + 1
    while time.monotonic() < deadline:
        if response.exists() and response.read_text(encoding="ascii") == expected:
            return
        time.sleep(0.01)
    pytest.fail("detached child did not answer a fresh request after owner death")


def test_owner_loss_leaves_blocking_marker_even_after_lock_release(router: RouterHarness) -> None:
    script, args, log, guard, ramroot = _fixture(router)
    subject = router.write("work/owner-death.sh", script + _call())
    process = subprocess.Popen(
        ["/bin/sh", str(subject), *args],
        cwd=router.path("work"),
        env=router.environment({"CFMGR_TEST_BEHAVIOR": "owner-loss"}),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    child_pid = 0
    try:
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            child_record = router.path("work/live-child.pid")
            if child_record.is_file():
                record = child_record.read_text(encoding="ascii")
                if record.strip().isdigit():
                    child_pid = int(record)
                    break
            if process.poll() is not None:
                break
            time.sleep(0.01)
        assert child_pid > 0
        assert os.getpgid(child_pid) == process.pid
        # The child cannot detach until its exact PID is known for cleanup.
        router.path("work/live-child.request").write_text("detach\n", encoding="ascii")
        ready = router.path("work/live-child.ready")
        expected_ready = f"{child_pid} {child_pid} {child_pid}\n"
        while time.monotonic() < deadline:
            if ready.exists() and ready.read_text(encoding="ascii") == expected_ready:
                break
            time.sleep(0.01)
        assert ready.read_text(encoding="ascii") == expected_ready
        assert os.getpgid(child_pid) == os.getsid(child_pid) == child_pid

        # Signal the entire actual worker group, not an async waiting wrapper.
        # The detached child has closed FD7 and cannot retain the native lock.
        os.killpg(process.pid, signal.SIGKILL)
        stdout, stderr = process.communicate(timeout=3)
        assert process.returncode == -signal.SIGKILL, (
            process.returncode,
            stdout,
            stderr,
        )
        assert stdout == stderr == b""
        _assert_group_gone(process.pid)
        active = ramroot / "dependencies.active"
        assert (active / "owner").read_bytes() == (
            f"CFMGR_DEPENDENCIES_OWNER_V1\n{guard}\n".encode("ascii")
        )
        _assert_child_responds(router, "after-owner-death")

        second_script, second_args, _, second_guard, _ = _fixture(
            router, ramroot=ramroot, guard_name="guard-after-owner"
        )
        second = router.run(second_script + _call(), second_args, timeout=5)
        _assert_result(second, 129)
        assert router.read("work/dependencies.log").splitlines() == [
            "lock-call-17",
            "locked-enter",
            "deadline-armed",
            "storage-acquire",
            "root-enter",
            "backend",
            "root-cleanup",
            "storage-cleanup",
            "owner-lost",
            "lock-call-17",
            "locked-enter",
        ]
        assert (active / "owner").is_file()
        assert not (second_guard / "deadline").exists()
        _assert_child_responds(router, "after-marker-refusal")
    finally:
        try:
            # Cleanup remains mandatory after the direct leader has exited.
            RouterHarness._stop_group(process)
            _assert_group_gone(process.pid)
        finally:
            try:
                if child_pid > 0:
                    _stop_detached_group(child_pid)
            finally:
                assert process.stdout is not None and process.stderr is not None
                process.stdout.close()
                process.stderr.close()


@pytest.mark.busybox
def test_busybox_shell_accepts_completed_negative_without_losing_cleanup(
    busybox_router: RouterHarness,
) -> None:
    result, log, guard, ramroot = _run(busybox_router, backend_status=1)

    _assert_result(result, 1)
    assert "storage-cleanup" in log.read_text(encoding="utf-8").splitlines()
    assert (guard / "storage-returned").is_dir()
    assert not (ramroot / "dependencies.active").exists()
