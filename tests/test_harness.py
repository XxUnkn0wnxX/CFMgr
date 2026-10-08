"""Harness regressions, without pretending that any CFMgr runtime feature exists."""

from __future__ import annotations

import os
import selectors
import shlex
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

from tests.conftest import ROOT, validate_matrix_marker
from tests.harness import OutputLimitExceeded, RouterHarness, ShellTimeout, matrix_ids
from tools.check import shell_sources

pytestmark = pytest.mark.matrix("V43", evidence="harness")


@pytest.mark.integration
def test_arguments_stdin_status_and_working_directory(router: RouterHarness) -> None:
    router.path("work/with spaces").mkdir()
    result = router.run(
        'IFS= read -r line\nprintf "%s\\n" "$PWD" "$1" "$2" "$line"\n'
        'printf "diagnostic\\n" >&2\nexit 7\n',
        ["literal $(touch unwanted)", "a 'quoted' value"],
        stdin="input with \\ and spaces\n",
        cwd="work/with spaces",
    )
    assert result.returncode == 7
    assert result.stdout.splitlines() == [
        str(router.path("work/with spaces")),
        "literal $(touch unwanted)",
        "a 'quoted' value",
        "input with \\ and spaces",
    ]
    assert result.stderr == "diagnostic\n"
    assert not router.path("work/with spaces/unwanted").exists()


@pytest.mark.integration
def test_environment_drops_inherited_secrets_and_host_path(
    router: RouterHarness,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    for key in ("CLOUDFLARE_API_TOKEN", "HTTPS_PROXY", "PYTHONPATH", "ENV", "BASH_ENV"):
        monkeypatch.setenv(key, "synthetic-poison")
    monkeypatch.setenv("PATH", "/usr/bin:/bin")
    router.fake_tool("curl", 'printf "synthetic-response:%s\\n" "$1"\n')
    result = router.run(
        'printf "%s\\n" "${CLOUDFLARE_API_TOKEN-unset}" "${HTTPS_PROXY-unset}" '
        '"${PYTHONPATH-unset}" "${ENV-unset}" "${BASH_ENV-unset}"\n'
        'printf "%s\\n" "$HOME" "$TMPDIR" "$PATH" "$EXPLICIT"\n'
        "if command -v rm; then exit 99; fi\ncurl example.invalid\n",
        env={"EXPLICIT": "provided"},
    )
    assert result.returncode == 0
    assert result.stdout.splitlines() == [
        *(["unset"] * 5),
        str(router.path("home")),
        str(router.path("ram/tmp")),
        str(router.path("bin")),
        "provided",
        "synthetic-response:example.invalid",
    ]
    assert result.stderr == ""


@pytest.mark.integration
def test_fixture_files_are_private_and_independent(tmp_path: Path) -> None:
    first = RouterHarness(tmp_path / "first router")
    second = RouterHarness(tmp_path / "second router")
    first.write("jffs/settings", "synthetic old value\n")
    second.write("jffs/settings", "synthetic second value\n")
    result = first.run('printf "changed\\n" > "$JFFS_ROOT/settings"\n')
    assert result.returncode == 0
    assert first.read("jffs/settings") == "changed\n"
    assert second.read("jffs/settings") == "synthetic second value\n"
    assert first.path("jffs/settings").stat().st_mode & 0o777 == 0o600
    assert first.root.stat().st_mode & 0o777 == 0o700


@pytest.mark.unit
@pytest.mark.parametrize("relative", ["/jffs/settings", "../settings", "jffs/../../settings"])
def test_paths_reject_escape(router: RouterHarness, relative: str) -> None:
    with pytest.raises(ValueError, match="relative"):
        router.write(relative, "synthetic")


@pytest.mark.unit
def test_paths_reject_symlink_and_bound_files(router: RouterHarness, tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    router.path("jffs/link").symlink_to(outside, target_is_directory=True)
    with pytest.raises(ValueError, match="symlink"):
        router.write("jffs/link/escaped", "synthetic")
    assert not (outside / "escaped").exists()
    with pytest.raises(ValueError, match="size budget"):
        router.write("jffs/large", "x" * (router.FILE_LIMIT + 1))
    router.path("ram/large").write_bytes(b"x" * (router.FILE_LIMIT + 1))
    with pytest.raises(ValueError, match="size budget"):
        router.read("ram/large")


@pytest.mark.unit
@pytest.mark.parametrize("key", ["PATH", "HOME", "TMPDIR", "ENV", "BASH_ENV", "JFFS_ROOT"])
def test_reserved_environment_cannot_override_isolation(router: RouterHarness, key: str) -> None:
    with pytest.raises(ValueError, match="reserved"):
        router.environment({key: "unsafe override"})


def install_blocker(router: RouterHarness) -> None:
    # Explicit trusted fake, allowing no host executable through PATH.
    code = (
        "import os,signal,time; from pathlib import Path; "
        "signal.signal(signal.SIGTERM, signal.SIG_IGN); "
        "Path(os.environ['RAM_ROOT'], 'child.pid').write_text(str(os.getpid())); "
        "time.sleep(30)"
    )
    router.fake_tool("blocker", "exec " + shlex.join([sys.executable, "-c", code]) + "\n")


def assert_child_gone(router: RouterHarness) -> None:
    pid = int(router.read("ram/child.pid"))
    deadline = time.monotonic() + 1
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return
        time.sleep(0.01)
    pytest.fail(f"owned child {pid} survived harness teardown")


@pytest.mark.integration
def test_timeout_kills_owned_group_including_term_ignoring_child(router: RouterHarness) -> None:
    install_blocker(router)
    started = time.monotonic()
    with pytest.raises(ShellTimeout) as failure:
        router.run(
            'trap "" TERM\nblocker &\n'
            'while [ ! -s "$RAM_ROOT/child.pid" ]; do :; done\n'
            'printf "ready\\n"\nwait\n',
            timeout=0.7,
        )
    assert failure.value.result.stdout == "ready\n"
    assert failure.value.result.returncode < 0
    assert time.monotonic() - started < 2
    assert_child_gone(router)


@pytest.mark.integration
def test_normal_exit_cleans_background_child_and_inherited_pipes(router: RouterHarness) -> None:
    install_blocker(router)
    started = time.monotonic()
    result = router.run(
        'blocker &\nwhile [ ! -s "$RAM_ROOT/child.pid" ]; do :; done\n'
        'printf "completed\\n"\nexit 0\n',
        timeout=2,
    )
    assert result.returncode == 0
    assert result.stdout == "completed\n"
    assert time.monotonic() - started < 1
    assert_child_gone(router)


@pytest.mark.integration
def test_output_limit_stops_a_noisy_process(router: RouterHarness) -> None:
    with pytest.raises(OutputLimitExceeded) as failure:
        router.run('while :; do printf "0123456789abcdef"; done\n', output_limit=1024)
    assert len(failure.value.result.stdout.encode()) <= 1024
    assert failure.value.result.returncode < 0


@pytest.mark.integration
def test_finite_output_limit_also_detects_overflow_after_exit(router: RouterHarness) -> None:
    with pytest.raises(OutputLimitExceeded):
        router.run('printf "123456789"\n', output_limit=8)


@pytest.mark.integration
def test_repeated_fast_exit_overflow_keeps_original_error(router: RouterHarness) -> None:
    # Exercise the real kernel transition repeatedly; never accept a cleanup EPERM.
    for _ in range(20):
        with pytest.raises(OutputLimitExceeded) as failure:
            router.run('printf "123456789"\n', output_limit=8)
        assert failure.value.result.stdout == "12345678"


@pytest.mark.integration
@pytest.mark.parametrize("leader_exits", [False, True])
def test_group_denial_is_reported_and_descriptors_close(
    router: RouterHarness,
    monkeypatch: pytest.MonkeyPatch,
    leader_exits: bool,
) -> None:
    # Fault injection targets only our real group. The process stays alive for the
    # first case; the second retains a real child after its leader has exited.
    original_popen = subprocess.Popen
    original_killpg = os.killpg
    processes = []
    input_files = []
    signal_attempts = []

    def capture_process(*args, **kwargs):
        process = original_popen(*args, **kwargs)
        processes.append(process)
        input_files.append(kwargs["stdin"])
        return process

    def deny_group(pgid, sig):
        assert pgid == processes[0].pid
        signal_attempts.append(sig)
        if not leader_exits:
            assert processes[0].poll() is None
        raise PermissionError("synthetic group denial")

    monkeypatch.setattr(subprocess, "Popen", capture_process)
    monkeypatch.setattr(os, "killpg", deny_group)
    if leader_exits:
        install_blocker(router)
        script = (
            'blocker &\nwhile [ ! -s "$RAM_ROOT/child.pid" ]; do :; done\n'
            'printf "ready\\n"\nexit 0\n'
        )
    else:
        script = "while :; do :; done\n"
    started = time.monotonic()
    try:
        with pytest.raises(PermissionError, match="synthetic group denial"):
            router.run(script, timeout=0.3)
        assert time.monotonic() - started < 2
        process = processes[0]
        assert process.stdout.closed and process.stderr.closed and input_files[0].closed
        if leader_exits:
            assert process.returncode == 0
            assert len(signal_attempts) == 2  # Denial survives independently proved leader exit.
        else:
            assert process.returncode < 0  # Best-effort direct-child kill did not hide denial.
            assert len(signal_attempts) == 1
    finally:
        # Test-owned recovery after injecting a denial. Never target another group.
        with monkeypatch.context() as cleanup:
            cleanup.setattr(os, "killpg", original_killpg)
            RouterHarness._stop_group(processes[0])
        if leader_exits:
            assert_child_gone(router)


@pytest.mark.unit
def test_absent_group_is_never_signalled_again(monkeypatch: pytest.MonkeyPatch) -> None:
    process = subprocess.Popen(["/bin/sh", "-c", "exit 0"], start_new_session=True)
    process.wait(timeout=1)
    attempts = []

    def absent_group(pgid, sig):
        assert pgid == process.pid
        attempts.append(sig)
        raise ProcessLookupError("owned group is already absent")

    monkeypatch.setattr(os, "killpg", absent_group)
    RouterHarness._stop_group(process)
    assert attempts == [signal.SIGTERM]


@pytest.mark.unit
def test_stdin_and_time_budgets_are_validated(router: RouterHarness) -> None:
    with pytest.raises(ValueError, match="stdin"):
        router.run("exit 0\n", stdin="x" * (router.INPUT_LIMIT + 1))
    with pytest.raises(ValueError, match="budgets"):
        router.run("exit 0\n", timeout=0)


@pytest.mark.unit
def test_matrix_markers_require_real_ids_and_explicit_evidence() -> None:
    known = matrix_ids(ROOT / "PLAN.md")
    validate_matrix_marker(pytest.mark.matrix("V43", evidence="harness").mark, known)
    with pytest.raises(ValueError, match="known PLAN IDs"):
        validate_matrix_marker(pytest.mark.matrix("V999", evidence="host").mark, known)
    with pytest.raises(ValueError, match="evidence"):
        validate_matrix_marker(pytest.mark.matrix("V43").mark, known)
    with pytest.raises(ValueError, match="evidence"):
        validate_matrix_marker(pytest.mark.matrix("V43", evidence="router").mark, known)


@pytest.mark.unit
def test_shell_source_discovery_excludes_scratch_and_symlinks(tmp_path: Path) -> None:
    router = RouterHarness(tmp_path / "fixture")
    source = router.write("lib/common.sh", "exit 0\n")
    extensionless = router.write("cfmgr", "#!/bin/sh\nexit 0\n")
    env_shell = router.write("tools/fixture", "#!/usr/bin/env sh\nexit 0\n")
    template = router.write("lib/template.sh.in", "exit 0\n")
    router.write("tools/python", "#!/usr/bin/env python3\n")
    router.write("notes", "plain text mentioning /bin/sh\n")
    router.write(".tmp/scratch.sh", "exit 1\n")
    router.write("tmp/scratch.sh", "exit 1\n")
    router.write(".venv/ignored.sh", "exit 1\n")
    router.path("lib/link.sh").symlink_to(source)
    router.path("linked-folder").symlink_to(router.path("lib"), target_is_directory=True)
    assert shell_sources(router.root) == sorted([source, extensionless, env_shell, template])


@pytest.mark.integration
def test_keyboard_interrupt_propagates_after_owned_cleanup(
    router: RouterHarness,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    original_select = selectors.DefaultSelector.select

    def interrupt_on_output(selector, timeout=None):
        events = original_select(selector, timeout)
        if events:
            raise KeyboardInterrupt
        return events

    monkeypatch.setattr(selectors.DefaultSelector, "select", interrupt_on_output)
    with pytest.raises(KeyboardInterrupt):
        router.run(
            'printf "%s" "$$" > "$RAM_ROOT/leader.pid"\nprintf "ready\\n"\nwhile :; do :; done\n'
        )
    pid = int(router.read("ram/leader.pid"))
    with pytest.raises(ProcessLookupError):
        os.kill(pid, 0)


@pytest.mark.busybox
@pytest.mark.matrix("V43", evidence="busybox")
def test_real_busybox_shell_and_explicit_applet(busybox_router: RouterHarness) -> None:
    busybox_router.busybox_applets("cat")
    busybox_router.write("jffs/payload", "synthetic busybox input\n")
    result = busybox_router.run('cat "$JFFS_ROOT/payload"\nprintf "%s\\n" "$1"\n', ["literal"])
    assert result.returncode == 0
    assert result.stdout == "synthetic busybox input\nliteral\n"
    assert result.stderr == ""
