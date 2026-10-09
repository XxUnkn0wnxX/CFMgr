"""Native cooperative lock ownership; no Entware, mounts or worker launch."""

from __future__ import annotations

import fcntl
import json
import os
import shlex
import stat
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

SOURCE = Path(__file__).resolve().parents[1] / "modules/dependency_lock.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]

FLOCK_TOOL = r"""
import fcntl
import json
import os
import signal
import sys
from pathlib import Path

log, behavior, *args = sys.argv[1:]
assert args == ["-n", "7"], args
held = os.fstat(7)
with Path(log).open("a") as stream:
    stream.write(json.dumps({
        "args": args, "identity": [held.st_dev, held.st_ino],
        "mode": fcntl.fcntl(7, fcntl.F_GETFL) & os.O_ACCMODE,
        "path": os.environ["PATH"], "locale": os.environ["LC_ALL"],
        "loader": os.environ.get("LD_LIBRARY_PATH"),
    }) + "\n")
if behavior == "signal":
    os.kill(os.getpid(), signal.SIGTERM)
if behavior != "lock":
    sys.exit(int(behavior))
try:
    fcntl.flock(7, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    sys.exit(1)
"""

HOLDER = r"""
import os
import signal
import sys

ready, release, done, behavior = sys.argv[1:]
os.fstat(7)
owner = os.getppid()
with open(ready, "w") as stream:
    stream.write("ready\n")
if behavior == "signal-owner":
    os.kill(owner, signal.SIGTERM)
with open(release) as stream:
    assert stream.readline() == "release\n"
os.close(7)
with open(done, "w") as stream:
    stream.write("closed\n")
"""


class LockFixture:
    def __init__(self, router: RouterHarness):
        self.router = router
        self.root = router.path("ram/tmp/dependency root")
        self.root.mkdir(mode=0o700)
        self.lock = self.root / "dependencies.lock"
        self.log = router.path("work/flock.jsonl")
        self.callback = router.path("work/callback.args")
        self.dispatcher = router.write("work/flock.py", FLOCK_TOOL)
        self.tool = self.flock_tool()

    def flock_tool(self, behavior: str = "lock") -> Path:
        invocation = " ".join(
            shlex.quote(str(value))
            for value in (sys.executable, self.dispatcher, self.log, behavior)
        )
        return self.router.write(
            f"work/flock-{behavior}", f'#!/bin/sh\nexec {invocation} "$@"\n', executable=True
        )

    def run(self, script: str, *, env: dict[str, str] | None = None) -> ShellResult:
        return self.router.run(f". {shlex.quote(str(SOURCE))}\n{script}", env=env, timeout=3)

    def call(self, *args: str | Path, root: str | Path | None = None, tool: Path | None = None):
        values = (root if root is not None else self.root, tool or self.tool, *args)
        return "cfmgr_dependency_lock_with_test " + " ".join(
            shlex.quote(str(value)) for value in values
        )

    def records(self) -> list[dict]:
        return [json.loads(line) for line in self.log.read_text().splitlines()]


def assert_quiet(result: ShellResult, status: int = 0) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == "", result


def test_retained_inode_arguments_mode_and_caller_state(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    fixture.lock.write_bytes(b"retained lock bytes\n")
    identity = fixture.lock.stat().st_ino
    caller_fd = router.write("work/caller-seven", "caller fd seven\n")
    trap_file = router.path("work/caller-trap")
    arguments = ("argument with spaces", "", "a\nb", "--*?[argument]")
    script = f"""
exec 7<{shlex.quote(str(caller_fd))}
trap 'printf exit >{shlex.quote(str(trap_file))}' 0
trap ':' TERM
callback() {{
    [ "$IFS" = ' 	
' ] && [ "$LC_ALL" = C ] || return 91
    case $- in *e*|*u*) return 92 ;; esac
    printf '%s\\0' "$@" >{shlex.quote(str(fixture.callback))}
    printf 'quiet stdout'; printf 'quiet stderr' >&2
    return 17
}}
IFS=caller-ifs
_dependency_lock_mode=fixture
_dependency_lock_flock=/untrusted/inherited
_dependency_lock_entered=999
PATH=caller-path
umask 022
set -eu
saved_flags=$-
saved_traps=$(trap)
if {fixture.call("callback", *arguments)}; then exit 93; else status=$?; fi
[ "$status" -eq 17 ] && [ "$IFS" = caller-ifs ] && [ "$PATH" = caller-path ] || exit 94
[ "$saved_flags" = "$-" ] && [ "$saved_traps" = "$(trap)" ] || exit 95
[ "$(umask)" = 0022 ] || exit 96
IFS= read -r held <&7
[ "$held" = 'caller fd seven' ] || exit 97
"""
    assert_quiet(fixture.run(script, env={"LD_LIBRARY_PATH": "/untrusted/loader"}))
    assert (
        fixture.callback.read_bytes() == b"\0".join(value.encode() for value in arguments) + b"\0"
    )
    assert fixture.lock.read_bytes() == b"retained lock bytes\n"
    assert fixture.lock.stat().st_ino == identity
    assert trap_file.read_text() == "exit"
    record = fixture.records()[0]
    assert record["identity"] == [fixture.lock.stat().st_dev, identity]
    assert record["args"] == ["-n", "7"] and record["mode"] == os.O_WRONLY
    assert record["path"] == "/sbin:/bin:/usr/sbin:/usr/bin"
    assert record["locale"] == "C" and record["loader"] is None


def test_new_lock_is_private_and_normal_return_releases(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    assert_quiet(fixture.run(f"callback() {{ return 0; }}\n{fixture.call('callback')}"))
    assert stat.S_IMODE(fixture.lock.stat().st_mode) == 0o600
    assert fixture.lock.read_bytes() == b""
    with fixture.lock.open("ab") as contender:
        fcntl.flock(contender, fcntl.LOCK_EX | fcntl.LOCK_NB)


def test_production_ignores_ambient_and_inherited_tool_selection(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    router.path("bin/flock").symlink_to(fixture.tool)
    native_available = any(
        Path(path).is_file() and os.access(path, os.X_OK)
        for path in ("/usr/bin/flock", "/bin/flock", "/sbin/flock", "/usr/sbin/flock")
    )
    script = f"""
_dependency_lock_flock={shlex.quote(str(fixture.tool))}
_dependency_lock_mode=fixture
callback() {{ printf called >{shlex.quote(str(fixture.callback))}; }}
cfmgr_dependency_lock_with {shlex.quote(str(fixture.root))} callback
"""
    assert_quiet(fixture.run(script), 0 if native_available else 1)
    assert fixture.callback.exists() == native_available
    assert not fixture.log.exists()


def test_api_validation_precedes_files_and_tools(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    invalid = [
        "cfmgr_dependency_lock_with",
        "cfmgr_dependency_lock_with_test",
        fixture.call("callback", root="relative"),
        fixture.call("callback", root="/"),
        fixture.call("callback", root=str(fixture.root) + "/"),
        fixture.call("callback", root=str(fixture.root) + "/../elsewhere"),
        fixture.call("callback", root="/" + "x" * 4096),
        fixture.call("callback", root=str(fixture.root) + "\n"),
        fixture.call("callback", tool=Path("relative-tool")),
        fixture.call("bad;callback"),
        fixture.call("9callback"),
        fixture.call(""),
    ]
    for call in invalid:
        assert_quiet(fixture.run(f"callback() {{ return 90; }}\n{call}"), 2)
    assert not fixture.lock.exists() and not fixture.log.exists()


def test_unusable_paths_never_invoke_tools(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    symlink_root = router.path("ram/tmp/root-link")
    symlink_root.symlink_to(fixture.root)
    absent_root = router.path("ram/tmp/missing")
    regular_root = router.write("ram/tmp/regular-root", "regular\n")
    for root in (symlink_root, absent_root, regular_root):
        assert_quiet(
            fixture.run(f"callback() {{ return 90; }}\n{fixture.call('callback', root=root)}"), 1
        )
    lock_target = router.write("work/lock-target", "unchanged\n")
    fixture.lock.symlink_to(lock_target)
    assert_quiet(fixture.run(f"callback() {{ return 90; }}\n{fixture.call('callback')}"), 1)
    assert lock_target.read_text() == "unchanged\n"
    fixture.lock.unlink()
    fixture.lock.mkdir()
    assert_quiet(fixture.run(f"callback() {{ return 90; }}\n{fixture.call('callback')}"), 1)
    fixture.lock.rmdir()
    os.mkfifo(fixture.lock)
    assert_quiet(fixture.run(f"callback() {{ return 90; }}\n{fixture.call('callback')}"), 1)
    assert not fixture.log.exists()


def test_tool_failure_and_callback_statuses_remain_distinct(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    missing = router.path("work/missing-flock")
    nonexecutable = router.write("work/not-executable", "regular\n")
    for tool in (missing, nonexecutable, fixture.root):
        assert_quiet(
            fixture.run(f"callback() {{ return 90; }}\n{fixture.call('callback', tool=tool)}"), 1
        )
    for behavior, expected in (("7", 1), ("128", 1), ("129", 129), ("255", 129), ("signal", 129)):
        tool = fixture.flock_tool(behavior)
        assert_quiet(
            fixture.run(f"callback() {{ return 90; }}\n{fixture.call('callback', tool=tool)}"),
            expected,
        )
    for status in (0, 17, 143):
        assert_quiet(
            fixture.run(f"callback() {{ return {status}; }}\n{fixture.call('callback')}"), status
        )


def test_real_contention_is_nonblocking_and_does_not_call_callback(router: RouterHarness) -> None:
    fixture = LockFixture(router)
    fixture.lock.write_bytes(b"existing\n")
    identity = fixture.lock.stat().st_ino
    script = (
        f"callback() {{ printf called >{shlex.quote(str(fixture.callback))}; }}\n"
        f"{fixture.call('callback')}"
    )
    with fixture.lock.open("ab") as owner:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert_quiet(fixture.run(script), 1)
        assert not fixture.callback.exists()
    assert_quiet(fixture.run(script))
    assert fixture.callback.read_text() == "called"
    assert fixture.lock.stat().st_ino == identity
    assert fixture.lock.read_bytes() == b"existing\n"


def exercise_inherited_lock(fixture: LockFixture, behavior: str) -> None:
    holder = fixture.router.write("work/holder.py", HOLDER)
    pipes = [fixture.router.path(f"work/{name}.fifo") for name in ("ready", "release", "done")]
    for pipe in pipes:
        os.mkfifo(pipe)
    ready, release, done = map(lambda path: shlex.quote(str(path)), pipes)
    child = " ".join(
        shlex.quote(str(value)) for value in (sys.executable, holder, *pipes, behavior)
    )
    expected = 143 if behavior == "signal-owner" else 0
    # Keep the intended signal owner alive until TERM arrives; ordinary return
    # intentionally leaves the cooperative child holding its inherited copy.
    wait_for_signal = 'wait "$_fixture_holder_pid"' if behavior == "signal-owner" else ":"
    script = f"""
callback() {{
    {child} &
    _fixture_holder_pid=$!
    IFS= read -r message <{ready}
    [ "$message" = ready ] || return 91
    {wait_for_signal}
}}
contender() {{ return 17; }}
{fixture.call("callback")}
status=$?
[ "$status" -eq {expected} ] || exit 92
# Controller remains alive: harness process-group cleanup has not occurred.
{fixture.call("contender")}
[ "$?" -eq 1 ] || exit 93
printf 'release\\n' >{release}
IFS= read -r message <{done}
[ "$message" = closed ] || exit 94
{fixture.call("contender")}
[ "$?" -eq 17 ] || exit 95
"""
    assert_quiet(fixture.run(script))


@pytest.mark.parametrize("behavior", ["ordinary", "signal-owner"])
def test_inherited_descriptor_retains_lock_after_owner_exit(
    router: RouterHarness, behavior: str
) -> None:
    exercise_inherited_lock(LockFixture(router), behavior)


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_flock_and_ash_inherited_ownership(busybox_router: RouterHarness) -> None:
    fixture = LockFixture(busybox_router)
    busybox_router.busybox_applets("flock")
    fixture.tool = busybox_router.path("bin/flock")
    exercise_inherited_lock(fixture, "ordinary")
