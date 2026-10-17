"""Archive scopes use the real Store transaction; native borrowing stays distinct."""

from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

import pytest
from test_archive_config import ARCHIVE_ID, SET_ID, configured
from test_config_observation import schema2_config as schema2_fixture
from test_config_store import ADAPTER, ROOT, run_store
from test_config_store import commands as store_commands
from test_config_store import config as store_config
from test_config_store import legacy_fsync as store_fsync
from test_config_store import shell as store_shell
from test_config_store import store_fixture as config_store_fixture
from test_config_store import tools as store_tools
from test_prerequisites import pause_definition

commands = store_commands
config = store_config
legacy_fsync = store_fsync
shell = store_shell
tools = store_tools
store_fixture = config_store_fixture
schema2_config = schema2_fixture

DRIVER = r"""
operation=$1
shift
cfmgr_store_scope=settings cfmgr_store_backup_gate=0 cfmgr_store_archive_lock_held=0
cfmgr_store_result=unavailable cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0
cfmgr_store_pending=0 cfmgr_config_lock_fd0=0 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0 cfmgr_store_flock_entware=0
cfmgr_store_prepare || exit $?
cfmgr_archive_want_format=YMD cfmgr_archive_want_keep=4 cfmgr_archive_want_set_id=01234567-89ab-cdef-0123-456789abcdef
cfmgr_archive_want_id=abcdef01-2345-6789-abcd-ef0123456789 cfmgr_archive_want_at=1792100000
cfmgr_archive_want_date=2026-10-16 cfmgr_archive_want_time=12-34-56 cfmgr_archive_want_zone='AEST-10AEDT,M10.1.0,M4.1.0/3'
cfmgr_archive_want_generation=3
case $operation in
read)
    cfmgr_store_archive_read || exit $?
    printf 'ARCHIVE %s %s %s %s %s\n' "$cfmgr_archive_saved_schema" "$cfmgr_archive_saved_generation" "$cfmgr_archive_saved_format" "$cfmgr_archive_saved_keep" "$cfmgr_archive_saved_set_id"
    code=0
    ;;
preferences | history)
    if cfmgr_store_archive_save "$operation"; then code=0; else code=$?; fi
    ;;
preferences-then-history)
    cfmgr_store_archive_save preferences || exit $?
    [ "$cfmgr_store_generation:$cfmgr_config_lock_fd0" = 2:1 ] || exit 96
    cfmgr_archive_want_generation=$cfmgr_store_generation
    cfmgr_store_archive_lock_held=1
    cfmgr_store_lock_acquire() { return 91; }
    cfmgr_store_archive_save history || exit $?
    [ "$cfmgr_store_generation:$cfmgr_config_lock_fd0" = 3:1 ] || exit 97
    cfmgr_store_archive_save history || exit $?
    [ "$cfmgr_store_result:$cfmgr_store_generation" = unchanged:3 ] || exit 98
    code=0
    ;;
borrow-history)
    cfmgr_store_lock_acquire || exit $?
    cfmgr_store_archive_lock_held=1
    # Any attempt to reopen/acquire this same description is a failure.
    cfmgr_store_lock_acquire() { return 91; }
    if cfmgr_store_archive_save history; then code=0; else code=$?; fi
    [ "$cfmgr_config_lock_fd0:$cfmgr_store_archive_lock_held" = 1:1 ] || exit 92
    cfmgr_store_lock_excludes_fresh_open || exit 93
    ;;
borrow-unlocked)
    : >"$cfmgr_store_lock"
    chmod 600 "$cfmgr_store_lock"
    exec 0<>"$cfmgr_store_lock"
    cfmgr_config_lock_fd0=1 cfmgr_store_archive_lock_held=1
    if cfmgr_store_archive_save preferences; then code=0; else code=$?; fi
    [ "$cfmgr_config_lock_fd0:$cfmgr_store_archive_lock_held" = 1:1 ] || exit 92
    ;;
source-open | rotation-open | owned-guard | mismatched-borrow)
    case $operation in
    source-open) exec 3<"$ram" ;;
    rotation-open) exec 4<"$ram" ;;
    owned-guard) cfmgr_store_guard_owned=1 ;;
    mismatched-borrow) cfmgr_store_archive_lock_held=1 ;;
    esac
    if cfmgr_store_archive_save preferences; then code=0; else code=$?; fi
    case $operation in
    source-open) (: <&3) || exit 94; exec 3<&- ;;
    rotation-open) (: <&4) || exit 94; exec 4<&- ;;
    owned-guard) [ "$cfmgr_store_guard_owned" = 1 ] || exit 94; cfmgr_store_guard_owned=0 ;;
    esac
    ;;
*) exit 90 ;;
esac
printf 'STORE %s %s %s %s\n' "$code" "$cfmgr_store_result" "$cfmgr_store_generation" "$cfmgr_store_pending"
if [ "$code" != 3 ]; then
    exec 0<&-
    cfmgr_config_lock_fd0=0
    cfmgr_store_cleanup || exit 95
fi
exit "$code"
"""
ARCHIVE_ADAPTER = ADAPTER.replace('cfmgr_config_store "$@"', DRIVER)


@pytest.mark.parametrize("schema", [1, 2])
def test_archive_read_preserves_legacy_and_typed_config_without_id_creation(
    shell, tools, store_fixture, schema2_config, schema
):
    source, ram, *_ = store_fixture
    if schema == 2:
        (source / "config").write_bytes(schema2_config)
    before = (source / "config").read_bytes()
    result = run_store(shell, tools, store_fixture, "read", script=ARCHIVE_ADAPTER)
    assert (result.returncode, result.stderr) == (0, b""), result
    assert result.stdout.startswith(f"ARCHIVE {schema} 1 - 0 -\n".encode())
    assert (source / "config").read_bytes() == before
    assert not (ram / "config.lock").exists()
    assert "store-lock" not in (ram / "routes").read_text()


def test_preferences_save_is_lossless_and_second_save_is_noop(
    shell, tools, store_fixture
):
    source, *_ = store_fixture
    original = (
        (source / "config")
        .read_bytes()
        .replace(
            b'"schema":1,', b'"future" : {"precise":900719925474099312345},"schema":1,'
        )
    )
    (source / "config").write_bytes(original)
    saved = run_store(
        shell, tools, store_fixture, "preferences", script=ARCHIVE_ADAPTER
    )
    assert (saved.returncode, saved.stdout, saved.stderr) == (
        0,
        b"STORE 0 saved 2 0\n",
        b"",
    ), saved
    expected = (
        original.replace(b'"generation":1,', b'"generation":2,')
        .replace(b'"retention":null', b'"retention":4')
        .replace(
            b'"last_backup":null}',
            f'"last_backup":null,"date_format":"YMD","set_id":"{SET_ID}"}}'.encode(),
        )
    )
    assert (source / "config").read_bytes() == expected
    repeated = run_store(
        shell, tools, store_fixture, "preferences", script=ARCHIVE_ADAPTER
    )
    assert (repeated.returncode, repeated.stdout, repeated.stderr) == (
        0,
        b"STORE 0 unchanged 2 0\n",
        b"",
    ), repeated
    assert (source / "config").read_bytes() == expected


def history_config(store_fixture):
    source = store_fixture[0]
    original = configured(
        (source / "config").read_bytes(),
        last_backup={
            "schema": 1,
            "generation": 1,
            "at": 1,
            "date_format": "DMY",
            "local_date": "2000-01-01",
            "local_time": "00-00-00",
            "timezone": "UTC0",
            "set_id": SET_ID,
            "archive_id": ARCHIVE_ID,
            "future": {"precise": 900719925474099312345},
        },
    ).replace(b'"generation": 1,', b'"generation": 5,', 1)
    (source / "config").write_bytes(original)
    return original


def test_history_borrows_same_lock_keeps_archive_generation_and_is_idempotent(
    shell, tools, store_fixture
):
    source, ram, *_ = store_fixture
    original = history_config(store_fixture)
    saved = run_store(
        shell, tools, store_fixture, "borrow-history", script=ARCHIVE_ADAPTER
    )
    assert (saved.returncode, saved.stdout, saved.stderr) == (
        0,
        b"STORE 0 saved 6 0\n",
        b"",
    ), saved
    current = (source / "config").read_bytes()
    parsed = json.loads(current)
    assert (
        parsed["generation"] == 6 and parsed["backup"]["last_backup"]["generation"] == 3
    )
    assert (
        parsed["backup"]["last_backup"]["future"]
        == json.loads(original)["backup"]["last_backup"]["future"]
    )
    assert b'"precise": 900719925474099312345' in current
    assert (ram / "routes").read_text().splitlines().count("store-lock") == 1
    repeated = run_store(
        shell, tools, store_fixture, "borrow-history", script=ARCHIVE_ADAPTER
    )
    assert (repeated.returncode, repeated.stdout, repeated.stderr) == (
        0,
        b"STORE 0 unchanged 6 0\n",
        b"",
    ), repeated
    assert (source / "config").read_bytes() == current


def test_preferences_then_history_reuse_one_context_and_writer_lock(
    shell, tools, store_fixture
):
    result = run_store(
        shell, tools, store_fixture, "preferences-then-history", script=ARCHIVE_ADAPTER
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"STORE 0 unchanged 3 0\n",
        b"",
    ), result
    source, ram, *_ = store_fixture
    saved = json.loads((source / "config").read_bytes())
    assert saved["generation"] == 3
    assert saved["backup"]["last_backup"]["generation"] == 2
    assert saved["backup"]["set_id"] == SET_ID
    assert (ram / "routes").read_text().splitlines().count("store-lock") == 1


@pytest.mark.parametrize(
    "operation",
    [
        "source-open",
        "rotation-open",
        "owned-guard",
        "mismatched-borrow",
        "borrow-unlocked",
    ],
)
def test_archive_save_refuses_unreleased_ownership_or_unproved_lock(
    shell, tools, store_fixture, operation
):
    source = store_fixture[0]
    original = (source / "config").read_bytes()
    result = run_store(shell, tools, store_fixture, operation, script=ARCHIVE_ADAPTER)
    assert result.returncode == (1 if operation == "borrow-unlocked" else 2), result
    assert result.stderr == b""
    assert (source / "config").read_bytes() == original
    assert not list(source.glob(".config-save*"))


@pytest.mark.parametrize("scenario", ["publish-stop", "retire-stop"])
def test_archive_guard_recovers_through_ordinary_store_without_candidate_replay(
    shell, tools, store_fixture, scenario
):
    source = store_fixture[0]
    before = (source / "config").read_bytes()
    stopped = run_store(
        shell,
        tools,
        store_fixture,
        "preferences",
        scenario=scenario,
        script=ARCHIVE_ADAPTER,
    )
    assert stopped.returncode == 1 and b"recovery" in stopped.stdout, stopped
    committed = (source / "config").read_bytes()
    assert (committed == before) is (scenario == "publish-stop")
    recovered = run_store(shell, tools, store_fixture, "recover")
    assert recovered.returncode == 0, recovered
    assert (source / "config").read_bytes() == committed
    assert not list(source.glob(".config-save*"))


def test_archive_fresh_retry_preserves_unrelated_raw_edit(shell, tools, store_fixture):
    source = store_fixture[0]
    before = (source / "config").read_bytes()
    saved = run_store(
        shell,
        tools,
        store_fixture,
        "preferences",
        scenario="raw-edit",
        script=ARCHIVE_ADAPTER,
    )
    assert (saved.returncode, saved.stdout, saved.stderr) == (
        0,
        b"STORE 0 saved 2 0\n",
        b"",
    ), saved
    after = (source / "config").read_bytes()
    assert after.endswith(b"\n ") and not before.endswith(b" ")
    assert json.loads(after)["backup"]["set_id"] == SET_ID


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Native proc/FD0 identity and inherited flock borrowing require Linux",
)
@pytest.mark.parametrize("fault", ["clean", "wrong-fd"])
def test_linux_archive_history_borrow_uses_actual_supervisor_and_one_lock(
    shell, tools, store_fixture, fault
):
    original = history_config(store_fixture)
    prefix = ADAPTER[: ADAPTER.index("cfmgr_prerequisites_run() {")]
    prefix = prefix.replace("cfmgr_prerequisites_now() { cfmgr_probe_now=100; }", "")
    prefix = prefix.replace('cfmgr_store_fd_is() { [ -f "$1" ] && [ ! -L "$1" ]; }', "")
    prefix = prefix.replace(
        "cfmgr_store_deadline=120",
        "cfmgr_prerequisites_now; cfmgr_store_deadline=$((cfmgr_probe_now+20))",
    )
    driver = DRIVER
    if fault == "wrong-fd":
        driver = driver.replace(
            "    cfmgr_store_archive_lock_held=1\n    # Any attempt",
            '    cfmgr_store_archive_lock_held=1\n    : >"$ram/other-lock"\n    exec 0<>"$ram/other-lock"\n    # Any attempt',
        ).replace(
            "    cfmgr_store_lock_excludes_fresh_open || exit 93",
            '    [ "$code" != 0 ] || exit 93',
        )
    script = (
        prefix
        + f". {shlex.quote(str(ROOT / 'modules/lib/execution.sh'))}\n"
        + pause_definition(shell)
        + driver
    )
    fixture = store_fixture
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        native_fsync = store_fixture[1] / "fsync"
        native_fsync.symlink_to(Path(tools["sh"]).resolve())
        fixture = (*store_fixture[:3], str(native_fsync))
    result = run_store(shell, tools, fixture, "borrow-history", script=script)
    if fault == "clean":
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            b"STORE 0 saved 6 0\n",
            b"",
        ), result
    else:
        assert result.returncode != 0 and result.stderr == b"", result
        assert (store_fixture[0] / "config").read_bytes() == original


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Real unknown-child lock retention across JSON stdin requires Linux proc",
)
def test_linux_unknown_archive_parser_keeps_lock_on_fd9_after_parent_close(
    shell, tools, store_fixture, tmp_path
):
    source, ram, flock, _ = store_fixture
    lock = ram / "config.lock"
    lock.touch(mode=0o600)
    context = ram / "parser-context"
    context.mkdir(mode=0o700)
    standin = ram / "parser-standin"
    standin.write_text(
        "#!/bin/sh\n"
        f"[ {shlex.quote(str(source / 'config'))} -ef /proc/self/fd/0 ] || exit 81\n"
        f"[ {shlex.quote(str(lock))} -ef /proc/self/fd/9 ] || exit 82\n"
        "exec /bin/sleep 1\n"
    )
    standin.chmod(0o700)
    script = f"""
. {shlex.quote(str(ROOT / "modules/lib/execution.sh"))}
{pause_definition(shell)}
cfmgr_store_lock=$1
exec 0<>"$1"
"$2" -n 0 || exit 90
cfmgr_config_lock_fd0=1
cfmgr_store_fd_is() {{ [ "$1" -ef "/proc/self/fd/$2" ]; }}
cfmgr_store_attachment_ok() {{ cfmgr_store_fd_is "$cfmgr_store_lock" 0; }}
cfmgr_prerequisites_now || exit 91
cfmgr_store_deadline=$((cfmgr_probe_now+5))
_cfmgr_prerequisites_observe() {{ cfmgr_probe_status=unresolved; return 3; }}
shift 2
if cfmgr_prerequisites_run "$@"; then exit 92; else [ "$?" = 3 ] || exit 93; fi
owned=$cfmgr_probe_pid
exec 0<&-
exec 7<>"$cfmgr_store_lock"
if {shlex.quote(flock)} -n 7; then exit 94; fi
# Deliberately forced uncertainty belongs only to this test; exact own child
# is finite and must finish with both real descriptor assertions satisfied.
wait "$owned" || exit 95
{shlex.quote(flock)} -n 7 || exit 96
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "archive-parser-lock",
            str(lock),
            flock,
            "store-archive-config",
            str(context),
            tools["sh"],
            str(source / "modules/helpers/worker.sh"),
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            str(standin),
            str(source / "modules/lib/config.sh"),
            str(source / "modules/lib/config.sh"),
            "archive-read",
            str(source / "config"),
            str((source / "config").stat().st_size),
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
            "",
        ],
        check=False,
        capture_output=True,
        timeout=8,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b""), result
