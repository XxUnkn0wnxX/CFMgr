"""Installed-entry preference journeys using the real settings Store."""

from __future__ import annotations

import fcntl
import json
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
    # Existing preference journeys opt out of first-use setup explicitly; the
    # dedicated WAN journey removes this retained deferral before launch.
    saved_config = json.loads((support / "config").read_text())
    saved_config["network"]["selected_wan"] = None
    saved_config["network"]["wan_inventory"] = {
        "schema": 1,
        "state": "deferred",
        "primary": None,
        "sources": [],
    }
    (support / "config").write_text(json.dumps(saved_config, separators=(",", ":")))
    scripts = jffs / "scripts"
    scripts.mkdir()

    for relative in (
        "modules/lib/execution.sh",
        "modules/lib/storage.sh",
        "modules/backup.sh",
        "modules/lib/package.sh",
        "modules/manager.sh",
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
    assignments.append("TEST_WAN_REPORT=1")
    assignments.append("export " + " ".join(env))
    assignments.append("export TEST_WAN_REPORT")
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
    adapter_functions = ADAPTER.split('. "$source/modules/lib/config.sh"\n', 1)[1]
    adapter_functions = adapter_functions.rsplit('\ncfmgr_config_store "$@"', 1)[0]
    adapter_path = support / "modules/lib/config_store_test_adapter.sh"
    diagnostic_preview = r"""
cfmgr_log_destination() {
    [ "$1" = preview ] || return 2
    printf 'log-destination-preview %s\n' "$2" >>"$ram/routes"
    case $2 in
    -) printf 'CFMGR-LOG-DEST 1 available 2f746d702f6d6f636b END\n' ;;
    *) printf 'CFMGR-LOG-DEST 1 available %s END\n' "$2" ;;
    esac
}
"""
    wan_fixture = r"""
cfmgr_status_wan_inventory() {
    [ "${TEST_WAN_REPORT:-0}" = 1 ] || return 1
    cat <<EOF_WAN_FIXTURE
CFMGR-WAN 1 $1 complete ok
PRIMARY - - unresolved -
SOURCE wan:0 0 65746830 dhcp yes yes coherent yes 192.168.2.2 255.255.255.0 private no
SOURCE wan:1 1 65746831 static yes no offline no - - unknown no
INTERFACE 65746830 up 192.168.2.2 255.255.255.0 private no
INTERFACE 65746831 down - - unknown no
END
EOF_WAN_FIXTURE
    return 0
}
"""
    adapter_path.write_text(
        "\n".join(assignments)
        + "\n"
        + adapter_functions
        + "\n"
        + diagnostic_preview
        + "\n"
        + wan_fixture
    )
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
    source_line = '. "$cfmgr_source/modules/manager.sh" || exit 1'
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


def run_entry(
    shell,
    entry: Path,
    data: bytes,
    *,
    timeout: float = 25,
    extra_env: dict[str, str] | None = None,
):
    master, slave = pty.openpty()
    try:
        child = subprocess.Popen(
            [*shell, str(entry)],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, "LC_ALL": "C", **(extra_env or {})},
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
    # This fixture has no admitted mounted diagnostic volume. Enabling developer
    # mode preserves the successful Store operation and reports capture absence.
    assert all(
        line
        == b"[CFMGR] diagnostics: warning: developer capture unavailable or incomplete; operation result is unchanged"
        for line in stderr.splitlines()
    )
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


def test_installed_advanced_menu_saves_diagnostic_destination_and_reopens(
    shell, installed_settings_entry
):
    entry, support, ram, _ = installed_settings_entry
    before = json.loads((support / "config").read_text())
    custom_path = str(ram / "diagnostic-copy")
    encoded = custom_path.encode().hex()
    result = run_entry(
        shell,
        entry,
        f"ao\n3\n1\n{custom_path}\ny\ne\ne\ne\n".encode(),
    )
    assert result.returncode == 0, result.stderr
    after = json.loads((support / "config").read_text())
    assert after["generation"] == before["generation"] + 1
    assert after["manager"]["developer_log_directory"] == custom_path
    assert after["manager"]["developer"] == before["manager"]["developer"]
    for key in before:
        if key == "generation":
            continue
        if key == "manager":
            for manager_key in before[key]:
                if manager_key == "developer_log_directory":
                    continue
                assert after[key][manager_key] == before[key][manager_key]
        else:
            assert after[key] == before[key]
    routes = (ram / "routes").read_text().splitlines()
    assert "log-destination-preview -" in routes
    assert f"log-destination-preview {encoded}" in routes
    assert "store-lock" in routes
    assert not Path(custom_path).exists()
    assert b"Diagnostic destination preference saved." in result.stdout

    route_count = len(routes)
    reopened = run_entry(shell, entry, b"ao\n3\ne\ne\ne\n")
    assert reopened.returncode == 0, reopened.stderr
    assert (
        b"Saved diagnostic preference: Custom " + custom_path.encode()
        in reopened.stdout
    )
    assert json.loads((support / "config").read_text()) == after
    assert len((ram / "routes").read_text().splitlines()) > route_count


def _clear_wan_intent(config_path: Path) -> None:
    value = json.loads(config_path.read_text())
    value["network"].pop("wan_inventory", None)
    value["network"]["selected_wan"] = None
    config_path.write_text(json.dumps(value, separators=(",", ":")))


def test_installed_first_use_confirms_primary_saves_and_reopens_real_store(
    shell, installed_settings_entry
):
    entry, support, ram, _ = installed_settings_entry
    _clear_wan_intent(support / "config")
    result = run_entry(
        shell,
        entry,
        b"y\nwan:0\ny\ne\n",
    )
    assert result.returncode == 0, result.stderr
    assert b"First-use WAN confirmation" in result.stdout, result.stdout
    saved = json.loads((support / "config").read_text())
    assert saved["network"]["wan_inventory"]["state"] == "confirmed", result.stdout
    assert saved["network"]["wan_inventory"]["primary"] == "wan:0"
    assert {
        source["id"] for source in saved["network"]["wan_inventory"]["sources"]
    } == {
        "wan:0",
        "wan:1",
    }
    assert b"wan:1: interface=eth1" in result.stdout
    assert b"mapping=offline" in result.stdout
    assert saved["network"]["selected_wan"] == 0
    assert b"protocol=dhcp" in result.stdout
    assert b"local IPv4=192.168.2.2 (private)" in result.stdout
    assert b"Internet access is unverified" in result.stdout
    assert b"WAN preference saved." in result.stdout
    routes = (ram / "routes").read_text().splitlines()
    assert "store-lock" in routes
    reopened = run_entry(shell, entry, b"ao\n4\n1\nwan:1\ny\ne\ne\ne\n")
    assert reopened.returncode == 0, reopened.stderr
    assert b"First-use WAN confirmation" not in reopened.stdout
    assert b"WAN preference saved." in reopened.stdout
    saved = json.loads((support / "config").read_text())
    assert saved["network"]["wan_inventory"]["primary"] == "wan:1"
    assert json.loads((support / "config").read_text()) == saved


def test_installed_no_corrects_interface_and_preserves_detected_source(
    shell, installed_settings_entry
):
    entry, support, _, _ = installed_settings_entry
    _clear_wan_intent(support / "config")
    result = run_entry(
        shell,
        entry,
        b"n\n2\neth0\ny\ne\ne\n",
    )
    assert result.returncode == 0, result.stderr
    value = json.loads((support / "config").read_text())
    inventory = value["network"]["wan_inventory"]
    assert inventory["state"] == "confirmed"
    assert inventory["primary"] == "manual:1"
    assert {source["id"] for source in inventory["sources"]} == {
        "wan:0",
        "wan:1",
        "manual:1",
    }
    manual = next(
        source for source in inventory["sources"] if source["id"] == "manual:1"
    )
    assert manual["interface"] == "eth0"
    assert b"WAN preference saved." in result.stdout


def test_installed_unobserved_manual_choice_can_be_explicitly_deferred(
    shell, installed_settings_entry
):
    entry, support, _, _ = installed_settings_entry
    _clear_wan_intent(support / "config")
    result = run_entry(
        shell,
        entry,
        b"n\n2\neth9\ny\ny\ne\ne\n",
    )
    assert result.returncode == 0, result.stderr
    inventory = json.loads((support / "config").read_text())["network"]["wan_inventory"]
    assert inventory["state"] == "deferred"
    assert inventory["primary"] is None
    assert inventory["sources"] == []
    assert b"WAN preference saved." in result.stdout


def test_installed_invalid_literal_and_cancel_do_not_save_wan_intent(
    shell, installed_settings_entry
):
    entry, support, _, _ = installed_settings_entry
    _clear_wan_intent(support / "config")
    before = (support / "config").read_bytes()
    result = run_entry(
        shell,
        entry,
        b"n\n2\neth:bad\ne\ne\n",
    )
    assert result.returncode == 0, result.stderr
    assert (support / "config").read_bytes() == before
    assert b"Invalid literal interface" in result.stdout
    assert b"WAN preference saved." not in result.stdout


def test_installed_stale_wan_save_reloads_without_overwriting_fresh_config(
    shell, tools, installed_settings_entry
):
    entry, support, _, store_paths = installed_settings_entry
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
        os.write(master, b"ao\n4\n1\n")
        output.extend(wait_for_output(child, b"DDNS primary: "))
        os.write(master, b"wan:0\n")
        output.extend(wait_for_output(child, b"Save this WAN preference? [y/N/e] "))
        fresh = run_store(shell, tools, store_paths, "save", "auto", "0", "1")
        assert fresh.returncode == 0, (fresh.stdout, fresh.stderr)
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
    assert b"changed during review; reloading current saved intent" in output
    assert b"WAN preference saved." not in output
    saved = json.loads((support / "config").read_text())
    assert saved["manager"]["auto_update"] is True
    assert saved["network"].get("wan_inventory", {}).get("state") == "deferred"


def test_installed_removal_is_explicit_and_reselects_primary(
    shell, installed_settings_entry
):
    entry, support, _, _ = installed_settings_entry
    _clear_wan_intent(support / "config")
    confirmed = run_entry(shell, entry, b"y\nwan:0\ny\ne\n")
    assert confirmed.returncode == 0, confirmed.stderr
    result = run_entry(shell, entry, b"ao\n4\n3\nwan:0\nwan:1\ny\ny\ne\ne\ne\n")
    assert result.returncode == 0, result.stderr
    inventory = json.loads((support / "config").read_text())["network"]["wan_inventory"]
    assert inventory["state"] == "confirmed"
    assert inventory["primary"] == "wan:1"
    assert [source["id"] for source in inventory["sources"]] == ["wan:1"]
    assert json.loads((support / "config").read_text())["network"]["selected_wan"] == 1
    assert b"Remove wan:0 and save the reviewed source set?" in result.stdout
    assert b"Review WAN Save" in result.stdout


def test_installed_pending_wan_store_requires_confirmed_recovery(
    shell, tools, installed_settings_entry
):
    entry, support, _, store_paths = installed_settings_entry
    interrupted = run_store_for_recovery(shell, tools, store_paths)
    assert interrupted.returncode == 1, (interrupted.stdout, interrupted.stderr)
    assert list(support.glob(".config-save*"))
    cancelled = run_entry(shell, entry, b"ao\n4\nr\nn\ne\ne\ne\n")
    assert cancelled.returncode == 0, cancelled.stderr
    assert b"no new changes are allowed" in cancelled.stdout
    assert (
        b"Recovery" not in cancelled.stdout
        or b"Recover previous WAN Save?" in cancelled.stdout
    )
    assert list(support.glob(".config-save*"))
    recovered = run_entry(shell, entry, b"ao\n4\nr\ny\ne\ne\n")
    assert recovered.returncode == 0, recovered.stderr
    assert b"Previous WAN Save recovered" in recovered.stdout
    assert not list(support.glob(".config-save*"))


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


WAN_EDITOR_DRIVER = r"""
. "$1"
. "$2"
calls=$3 scenario=$4
cfmgr_config_wan_store() {
    printf 'store %s\n' "$*" >>"$calls"
    case $1 in
    read)
        case $scenario in
        unresolved-read) printf 'CFMGR-WAN-STORE 1 unresolved 1 0 unresolved unknown - - END\n'; return 3 ;;
        legacy-unknown|unknown-defer) printf 'CFMGR-WAN-STORE 1 read 1 0 unresolved unknown - - END\n' ;;
        legacy) printf 'CFMGR-WAN-STORE 1 read 1 0 legacy retained wan:0 wan:0 END\n' ;;
        deferred) printf 'CFMGR-WAN-STORE 1 read 1 0 inventory deferred - - END\n' ;;
        offline) printf 'CFMGR-WAN-STORE 1 read 1 0 inventory confirmed wan:0 wan:0 END\n' ;;
        reuse) printf 'CFMGR-WAN-STORE 1 read 1 0 inventory confirmed manual:2 manual:2=65746830 END\n' ;;
        last) printf 'CFMGR-WAN-STORE 1 read 1 0 inventory confirmed wan:0 wan:0 END\n' ;;
        *) printf 'CFMGR-WAN-STORE 1 read 1 0 absent unconfirmed - - END\n' ;;
        esac ;;
    save)
        case $scenario in
        unresolved|launch-unresolved) printf 'CFMGR-WAN-STORE 1 unresolved 1 0 unresolved unknown - - END\n'; return 3 ;;
        pending) printf 'CFMGR-WAN-STORE 1 recovery 1 1 inventory unknown - - END\n'; return 1 ;;
        *) printf 'CFMGR-WAN-STORE 1 saved 2 0 inventory %s %s %s END\n' "$3" "$4" "$5" ;;
        esac ;;
    recover) printf 'CFMGR-WAN-STORE 1 recovered 1 0 inventory deferred - - END\n' ;;
    esac
}
cfmgr_status_wan_inventory() {
    printf 'observe\n' >>"$calls"
    cat <<EOF_REPORT
CFMGR-WAN 1 $1 complete ok
PRIMARY - - unresolved -
SOURCE wan:0 0 65746830 dhcp yes yes coherent yes 192.168.2.2 255.255.255.0 private no
INTERFACE 65746830 up 192.168.2.2 255.255.255.0 private no
END
EOF_REPORT
}
case $scenario in
legacy|legacy-unknown|deferred|offline|unresolved-read) cfmgr_manager_wan_first_use ;;
launch-unresolved) cfmgr_launch_menu ;;
*) cfmgr_manager_wan_settings ;;
esac
printf 'menu-status=%s\n' "$?"
"""


def run_wan_editor(shell, tmp_path, scenario, inputs):
    calls = tmp_path / "wan-calls"
    calls.write_text("")
    master, slave = pty.openpty()
    child = None
    try:
        child = subprocess.Popen(
            [
                *shell,
                "-c",
                WAN_EDITOR_DRIVER,
                "wan-test",
                str(ROOT / "modules/manager.sh"),
                str(ROOT / "modules/backup.sh"),
                str(calls),
                scenario,
            ],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env={**os.environ, "LC_ALL": "C"},
        )
        os.write(master, inputs)
        stdout, stderr = child.communicate(timeout=8)
    finally:
        if child is not None and child.poll() is None:
            child.kill()
            child.communicate(timeout=3)
        os.close(master)
        os.close(slave)
    assert child.returncode == 0, stderr
    return stdout, calls.read_text().splitlines()


def test_wan_unresolved_save_exits_without_another_operation(shell, tmp_path):
    output, calls = run_wan_editor(shell, tmp_path, "unresolved", b"1\nwan:0\ny\n1\n")
    assert calls == ["store read", "observe", "store save 1 confirmed wan:0 wan:0"]
    assert b"menu-status=3" in output
    assert b"no changes were saved" not in output


def test_wan_new_pending_save_only_offers_explicit_recovery(shell, tmp_path):
    output, calls = run_wan_editor(
        shell, tmp_path, "pending", b"1\nwan:0\ny\n1\nr\nn\nr\ny\n"
    )
    assert calls == [
        "store read",
        "observe",
        "store save 1 confirmed wan:0 wan:0",
        "store recover",
        "store read",
    ]
    assert b"no new changes are allowed" in output
    assert b"publication state is uncertain" in output


def test_wan_overlength_manual_name_never_defers_or_writes(shell, tmp_path):
    output, calls = run_wan_editor(
        shell, tmp_path, "normal", b"2\nabcdefghijklmnop\ny\ne\n"
    )
    assert calls == ["store read", "observe"]
    assert b"Invalid literal interface" in output
    assert b"explicit deferral" not in output


def test_wan_reuses_existing_manual_id_after_gap(shell, tmp_path):
    output, calls = run_wan_editor(shell, tmp_path, "reuse", b"2\neth0\nn\ny\ne\n")
    assert "store save 1 confirmed manual:2 manual:2=65746830,wan:0" in calls
    assert b"manual:2 interface eth0" in output
    assert b"sources=manual:2=65746830" not in output


def test_wan_removing_last_source_saves_empty_deferred(shell, tmp_path):
    _, calls = run_wan_editor(shell, tmp_path, "last", b"3\nwan:0\ny\ne\n")
    assert "store save 1 deferred - -" in calls


@pytest.mark.parametrize(
    "scenario", ["legacy", "legacy-unknown", "deferred", "offline", "unresolved-read"]
)
def test_wan_retained_and_unresolved_first_use_never_observe(shell, tmp_path, scenario):
    output, calls = run_wan_editor(shell, tmp_path, scenario, b"e\n")
    assert calls == ["store read"]
    assert b"First-use WAN confirmation" not in output
    if scenario == "unresolved-read":
        assert b"menu-status=3" in output


def test_wan_editor_eof_does_not_save(shell, tmp_path):
    _, calls = run_wan_editor(shell, tmp_path, "normal", b"\x04")
    assert calls == ["store read"]


def test_wan_deferral_preserves_unresolved_legacy_choice(shell, tmp_path):
    output, calls = run_wan_editor(shell, tmp_path, "unknown-defer", b"4\ny\ne\n")
    assert calls == ["store read"]
    assert b"unresolved retained WAN choice is preserved" in output


def test_wan_unresolved_first_use_exits_real_menu_without_further_actions(
    shell, tmp_path
):
    output, calls = run_wan_editor(
        shell, tmp_path, "launch-unresolved", b"y\nwan:0\ny\nao\n4\n1\n"
    )
    assert calls == ["store read", "observe", "store save 1 confirmed wan:0 wan:0"]
    assert b"CFMgr main menu" not in output
    assert b"menu-status=1" in output
