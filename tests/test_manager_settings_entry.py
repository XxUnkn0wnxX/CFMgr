"""Installed-entry preference journeys using the real settings Store."""

from __future__ import annotations

import fcntl
import os
import pty
import select
import shlex
import shutil
import subprocess
import time
from pathlib import Path

import pytest
from entry_package_fixture import finish_package
from test_config_observation import commands, config
from test_config_store import ADAPTER, run_store, store_fixture
from test_install import legacy_fsync, shell, tools

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["commands", "config", "legacy_fsync", "shell", "store_fixture", "tools"]


@pytest.fixture
def installed_settings_entry(tmp_path: Path, store_fixture, tools, shell):
    source, ram, flock, fsync = store_fixture
    jffs = tmp_path / "jffs"
    support = jffs / "addons/CFMgr.d"
    support.parent.mkdir(parents=True)
    shutil.copytree(source, support)
    scripts = jffs / "scripts"
    scripts.mkdir()

    for relative in (
        "modules/lib/prerequisites.sh",
        "modules/lib/mountinfo.awk",
        "modules/lib/storage.sh",
        "modules/backup.sh",
        "modules/helpers/launch.sh",
        "modules/manager_settings.sh",
        "modules/status.sh",
    ):
        target = support / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((ROOT / relative).read_bytes())
        target.chmod((ROOT / relative).stat().st_mode & 0o777)

    env = {f"TEST_{key.upper()}": value for key, value in tools.items()}
    env.update(
        TEST_DD=shutil_which("dd"),
        TEST_OPENSSL=shutil_which("openssl"),
        CFMGR_FSYNC_FAULT="clean",
    )
    assignments = [f"{key}={shlex.quote(value)}" for key, value in env.items()]
    assignments.append("export " + " ".join(env))
    assignments.extend(
        f"{name}={shlex.quote(value)}"
        for name, value in (
            ("source", str(support)),
            ("ram", str(ram)),
            ("flock", flock),
            ("fsync", fsync),
            ("scenario", "normal"),
        )
    )
    adapter_functions = ADAPTER.split('. "$source/modules/lib/config_store.sh"\n', 1)[1]
    adapter_functions = adapter_functions.rsplit('\ncfmgr_config_store "$@"', 1)[0]
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    adapter_path.write_text("\n".join(assignments) + "\n" + adapter_functions + "\n")
    adapter_path.chmod(0o600)

    original = (ROOT / "cfmgr.sh").read_text()
    adapted = original
    # Keep the real isolated re-exec under the selected test interpreter too.
    # The BusyBox tools fixture already supplies a sh-named applet symlink.
    reexec = 'CFMGR_INTERNAL_LAUNCH=1 /bin/sh "$cfmgr_default_entry"'
    assert adapted.count(reexec) == 1
    shell_args = [] if shell[1:] == ["ash"] else shell[1:]
    adapted = adapted.replace(
        reexec,
        "CFMGR_INTERNAL_LAUNCH=1 "
        + shlex.join([tools["sh"], *shell_args])
        + ' "$cfmgr_default_entry"',
        1,
    )
    source_line = '. "$cfmgr_source/modules/lib/config_store.sh" || exit 1'
    assert source_line in adapted
    adapted = adapted.replace(
        source_line,
        source_line
        + '\n\t\t. "$cfmgr_source/modules/lib/config_store_test_adapter.sh" || exit 1',
        1,
    )
    entry = scripts / "cfmgr.sh"
    entry.write_text(adapted)
    finish_package(entry, support, tools, shell, adapt=True)
    return entry, support, ram, (support, ram, flock, fsync)


def shutil_which(name: str) -> str:
    import shutil

    path = shutil.which(name)
    assert path, f"Native host {name} is required by the existing Store fixture"
    return path


def run_entry(shell, entry: Path, data: bytes, *, timeout: float = 25):
    master, slave = pty.openpty()
    try:
        child = subprocess.Popen(
            [*shell, str(entry)],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, "LC_ALL": "C"},
        )
        os.write(master, data)
        out, err = child.communicate(timeout=timeout)
        return subprocess.CompletedProcess(child.args, child.returncode, out, err)
    finally:
        os.close(master)
        os.close(slave)


def wait_for_output(
    child: subprocess.Popen, expected: bytes, timeout: float = 8
) -> bytes:
    assert child.stdout is not None
    output = bytearray()
    deadline = time.monotonic() + timeout
    while expected not in output:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise AssertionError(
                f"timed out waiting for {expected!r}: {bytes(output)!r}"
            )
        ready, _, _ = select.select([child.stdout], [], [], remaining)
        if not ready:
            continue
        chunk = os.read(child.stdout.fileno(), 4096)
        if not chunk:
            raise AssertionError(f"entry exited before {expected!r}: {bytes(output)!r}")
        output.extend(chunk)
    return bytes(output)


def test_installed_menu_saves_reviewed_fields_over_fresh_edits_without_prompt_lock(
    shell, installed_settings_entry
):
    entry, support, ram, _ = installed_settings_entry
    lock = ram / "config.lock"
    lock.touch(mode=0o600)
    master, slave = pty.openpty()
    child = subprocess.Popen(
        [*shell, str(entry)],
        stdin=slave,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env={**os.environ, "LC_ALL": "C"},
    )
    output = bytearray()
    try:
        os.write(master, b"ao\n2\n1\ns\n")
        output.extend(wait_for_output(child, b"Save these preferences? [y/N/e] "))
        with lock.open("r+b") as owner:
            fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
            # An earlier editor can commit while review is waiting. Save owns
            # both reviewed preferences, including Check Off's Auto Off closure,
            # but must reread and preserve unrelated authority without relying
            # on an editor bumping the generation.
            live = support / "config"
            current = live.read_bytes()
            fresh = (
                current.replace(b'"auto_update":false', b'"auto_update":true')
                .replace(b'"developer":false', b'"developer":true')
                .replace(
                    b'"ownership":{}',
                    b'"ownership":{"auth_fault":{"scope":"ddns","keep":true}}',
                )
            )
            assert fresh != current and b'"generation":1' in fresh
            assert b'"auto_update":true' in fresh
            assert b'"developer":true' in fresh
            assert b'"auth_fault":{"scope":"ddns","keep":true}' in fresh
            live.write_bytes(fresh)
            fcntl.flock(owner, fcntl.LOCK_UN)
        os.write(master, b"y\ne\ne\ne\n")
        remaining, stderr = child.communicate(timeout=30)
        output.extend(remaining)
    finally:
        if child.poll() is None:
            child.kill()
            child.communicate(timeout=3)
        os.close(master)
        os.close(slave)

    assert child.returncode == 0, (bytes(output), stderr)
    assert b"CFMgr updates: preferences only" in output
    assert b"Preferences saved." in output
    assert b"Saved: Check for updates=Off; Auto-update CFMgr=Off" in output
    saved = (support / "config").read_bytes()
    expected = (
        fresh.replace(b'"generation":1', b'"generation":2')
        .replace(b'"check_updates":true', b'"check_updates":false')
        .replace(b'"auto_update":true', b'"auto_update":false')
    )
    assert saved == expected
    assert b"Developer mode suppresses manager updates" in output
    routes = (ram / "routes").read_text().splitlines()
    assert "store-lock" in routes
    assert not any("opkg" in route or route.startswith("install-") for route in routes)
    assert b"[CFMGR]" not in stderr
    reopened = run_entry(shell, entry, b"ao\n2\ne\ne\ne\n")
    assert reopened.returncode == 0, reopened.stderr
    assert b"Saved: Check for updates=Off; Auto-update CFMgr=Off" in reopened.stdout


def test_installed_menu_cancel_preserves_config_without_network_or_repair(
    shell, installed_settings_entry
):
    entry, support, ram, _ = installed_settings_entry
    before = (support / "config").read_bytes()
    result = run_entry(shell, entry, b"ao\n2\n1\ns\nn\ne\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert (support / "config").read_bytes() == before
    routes = (ram / "routes").read_text().splitlines()
    assert "store-settings" in routes
    assert "store-lock" not in routes
    assert not any("opkg" in route or route.startswith("install-") for route in routes)
    assert b"Save cancelled; no changes were written." in result.stdout
    assert b"Preferences saved." not in result.stdout
    assert b"opkg" not in result.stdout + result.stderr


def test_installed_menu_recovers_actual_pending_save_only_after_confirmation(
    shell, tools, installed_settings_entry
):
    entry, source, _, store_paths = installed_settings_entry
    interrupted = run_store_for_recovery(shell, tools, store_paths)
    assert interrupted.returncode == 1, (interrupted.stdout, interrupted.stderr)
    assert (source / ".config-save").is_dir()
    result = run_entry(
        shell,
        entry,
        b"ao\n2\nr\ny\ne\ne\ne\n",
    )
    assert result.returncode == 0, result.stderr
    assert b"pending Save/recovery state" in result.stdout
    assert b"Previous Save recovered; no settings were replayed." in result.stdout
    assert not list(source.glob(".config-save*"))
    assert b'"generation":1' in (source / "config").read_bytes()


def run_store_for_recovery(shell, tools, fixture):
    return run_store(
        shell,
        tools,
        fixture,
        "save",
        "auto",
        "0",
        "1",
        scenario="publish-stop",
    )
