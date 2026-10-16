"""Native settings transaction, recovery and shared-lock consumer proof.

Host adapters replace only firmware roots/admission and unavailable proc
supervision. Real controller, helper, parsers, filesystem and flock semantics
remain. Linux tests keep actual supervisor/FD inheritance and vendor ash.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from test_config_observation import commands, config
from test_install import legacy_fsync, shell, tools
from test_prerequisites import pause_definition

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["commands", "config", "legacy_fsync", "shell", "tools"]


@pytest.fixture
def store_fixture(tmp_path, tools, legacy_fsync, config):
    source = tmp_path / "support"
    (source / "modules/lib").mkdir(parents=True)
    (source / "modules/helpers").mkdir()
    source.chmod(0o700)
    for relative in (
        "modules/lib/config_store.sh",
        "modules/lib/json.awk",
        "modules/lib/mountinfo.awk",
        "modules/lib/config_observation.awk",
        "modules/helpers/probe.sh",
    ):
        original = ROOT / relative
        body = original.read_text()
        if relative.endswith("config_store.sh"):
            body = body.replace(
                ":0 | file:-rw-------:0",
                f":{os.getuid()} | file:-rw-------:{os.getuid()}",
            )
        if relative.endswith("probe.sh"):
            body = body.replace("$4!=0", f"$4!={os.getuid()}")
            if sys.platform == "darwin":
                body = body.replace("/proc/self/fd/8", "/dev/fd/8").replace(
                    '"$1" -ef /dev/fd/8', "-f /dev/fd/8"
                )
        target = source / relative
        target.write_text(body)
        target.chmod(original.stat().st_mode & 0o777)
    (source / "config").write_bytes(config)
    (source / "config").chmod(0o600)
    (source / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (source / "setup-state").chmod(0o600)
    ram = tmp_path / "ram"
    ram.mkdir(mode=0o700)
    flock = shutil.which("flock")
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        vendor_flock = tmp_path / "flock"
        vendor_flock.symlink_to(Path(tools["sh"]).resolve())
        flock = str(vendor_flock)
    if not flock:
        # Host lacks native flock. This direct executable uses the same kernel
        # inherited open-description lock, without a shell/background child.
        shim = tmp_path / "flock"
        shim.write_text(
            f"#!{Path(sys.executable).resolve()}\nimport fcntl,sys\ntry: fcntl.flock(int(sys.argv[2]),fcntl.LOCK_EX|fcntl.LOCK_NB)\nexcept BlockingIOError: sys.exit(1)\n"
        )
        shim.chmod(0o700)
        flock = str(shim)
    return source, ram, flock, str(legacy_fsync)


ADAPTER = r"""
source=$1 ram=$2 flock=$3 fsync=$4 scenario=$5
shift 5
. "$source/modules/lib/config_store.sh"
CFMGR_VERSION=0.1.0
cfmgr_prerequisites_now() { cfmgr_probe_now=100; }
cfmgr_store_prepare() {
    cfmgr_store_source=$source cfmgr_store_ram=$ram cfmgr_store_jffs=$source
    cfmgr_store_live=$source/config cfmgr_store_lock=$ram/config.lock
    cfmgr_store_context=$ram/context
    mkdir -m 700 "$cfmgr_store_context" || return 1
    exec 5<"$cfmgr_store_context" 8<"$source" 9<"$source"
    cfmgr_store_context_fd=5 cfmgr_store_borrowed=0 cfmgr_store_flock_entware=0
    cfmgr_store_sh=$TEST_SH cfmgr_store_env=$TEST_ENV cfmgr_store_awk=$TEST_AWK
    cfmgr_store_readlink=$TEST_READLINK cfmgr_store_wc=$TEST_WC cfmgr_store_ls=$TEST_LS
    cfmgr_store_sleep=$TEST_SLEEP cfmgr_store_flock=$flock cfmgr_store_openssl=$TEST_OPENSSL
    cfmgr_store_dd=$TEST_DD cfmgr_store_cp=$TEST_CP cfmgr_store_mv=$TEST_MV cfmgr_store_fsync=$fsync
    cfmgr_store_deadline=120 cfmgr_probe_pid='' cfmgr_probe_serial=0
}
# Explicit host admission adapter; production metadata/mount/FD checks remain
# unchanged and Linux proof below exercises actual child ownership.
cfmgr_store_attachment_ok() { [ -d "$cfmgr_store_context" ] && [ ! -L "$cfmgr_store_context" ]; }
cfmgr_store_fd_is() { [ -f "$1" ] && [ ! -L "$1" ]; }
cfmgr_store_native_tool() { [ -x "$1" ]; }
cfmgr_test_semantic_edit() {
    case $scenario in
    semantic-remerge)
        [ "${semantic_edited:-0}" = 0 ] || return 0
        (umask 077; "$TEST_JQ" '.manager.check_updates=false | .manager.auto_update=false | .manager.developer=true | .manager.developer_log_directory="/jffs/addons/CFMgr.d/logs" | .cloudflared.configured=true | .cloudflared.enabled=true | .cloudflared.maintenance_enabled=true | .credentials={"cloudflared":{"runtime":"fixture-ref"}} | .ownership={"config_save":{"owner":"fixture","generation":1}}' "$source/config" >"$ram/semantic-new") || return 1
        "$TEST_MV" "$ram/semantic-new" "$source/config" || return 1
        "$TEST_CP" "$source/config" "$ram/semantic-live" || return 1
        semantic_edited=1
        ;;
    semantic-churn)
        (umask 077; "$TEST_JQ" '.manager.developer |= (not)' "$source/config" >"$ram/semantic-new") || return 1
        "$TEST_MV" "$ram/semantic-new" "$source/config" || return 1
        "$TEST_CP" "$source/config" "$ram/semantic-live" || return 1
        ;;
    esac
}
cfmgr_prerequisites_run() {
    mode=$1 context=$2 helper=$4 tool=$9 cfmgr_probe_mode=$1
    shift 9
    cfmgr_probe_serial=$((cfmgr_probe_serial+1))
    cfmgr_probe_stdout=$context/$mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$context/$mode.$cfmgr_probe_serial.err
    cfmgr_probe_status=reaped cfmgr_probe_pid='' cfmgr_probe_reason=''
    printf '%s\n' "$mode" >>"$ram/routes"
    case $mode in
    store-space) tool=$TEST_DF ;;
    store-snapshot)
        if [ "$1" = "$source/config" ]; then
            live_reads=$((${live_reads:-0}+1))
            if [ "$scenario:$live_reads" = post-unresolved:3 ] || [ "$scenario:$live_reads" = noop-unresolved:2 ]; then cfmgr_probe_status=unresolved; cfmgr_probe_pid=fixture; return 3; fi
        fi ;;
    store-mkdir)
        if [ "$scenario" = raw-edit ] && [ "${raw_edited:-0}" = 0 ]; then printf ' ' >>"$source/config"; raw_edited=1; fi ;;

    store-flush)
        if [ "$scenario" = flush-error ] || { [ "$scenario" = post-publish-flush ] && [ "${published:-0}" = 1 ]; }; then
            : >"$cfmgr_probe_stdout"; printf 'fsync: error\n' >"$cfmgr_probe_stderr"; cfmgr_probe_exit=0
            [ "$scenario" != post-publish-flush ] || printf 'exit=0 stderr=fsync error\n' >"$ram/post-publish-flush.injected"
            return 0
        fi ;;
    store-copy)
        case $2 in
        */.config-save.preparing/candidate)
            case $scenario in semantic-remerge | semantic-churn) cfmgr_test_semantic_edit || return 1 ;; esac
            if [ "$scenario" = candidate-copy-error ]; then : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"; cfmgr_probe_exit=1; return 0; fi ;;
        esac ;;
    store-move)
        case $2 in
        */.config-save)
            if [ "$scenario" = stale ]; then printf ' ' >>"$source/config"; fi
            if [ "$scenario" = arm-stop ]; then : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"; cfmgr_probe_exit=1; return 0; fi ;;
        */config)
            if [ "$scenario" = publish-stop ]; then : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"; cfmgr_probe_exit=1; return 0; fi ;;
        */.config-save.retired)
            if [ "$scenario" = retire-stop ]; then : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"; cfmgr_probe_exit=1; return 0; fi ;;
        esac ;;
    store-digest)
        if [ "$scenario" = unresolved ] && [ "$1" != "$context/sha-vector" ]; then cfmgr_probe_status=unresolved; cfmgr_probe_pid=fixture; return 3; fi ;;
    esac
    (umask 077; LC_ALL=C LANGUAGE= "$cfmgr_store_sh" "$helper" "$mode" "$tool" "$context" "$@") >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
    if [ "$mode" = store-move ] && [ "$2" = "$source/config" ] && [ "$cfmgr_probe_exit" = 0 ]; then
        case $scenario in
        post-publish-flush) published=1 ;;
        post-publish-corrupt)
            cat "$source/config" >"$ram/post-publish-corrupt.candidate"
            printf 'corrupt-after-rename\n' >"$source/config"
            ;;
        esac
    fi
    return 0
}
cfmgr_config_store "$@"
"""


def run_store(shell, tools, fixture, *args, scenario="normal", script=ADAPTER):
    source, ram, flock, fsync = fixture
    environment = os.environ.copy()
    environment.update({f"TEST_{key.upper()}": value for key, value in tools.items()})
    environment.update(
        TEST_DD=shutil.which("dd"),
        TEST_OPENSSL=shutil.which("openssl"),
        CFMGR_FSYNC_FAULT="clean",
    )
    return subprocess.run(
        [
            *shell,
            "-c",
            script,
            "store-test",
            str(source),
            str(ram),
            flock,
            fsync,
            scenario,
            *args,
        ],
        env=environment,
        capture_output=True,
        check=False,
        timeout=25,
    )


def test_read_noop_and_save_preserve_unrelated_bytes(shell, tools, store_fixture):
    source, ram, *_ = store_fixture
    before = (source / "config").read_bytes()
    read = run_store(shell, tools, store_fixture, "read")
    assert (read.returncode, read.stdout, read.stderr) == (
        0,
        b"CFMGR-STORE 1 read 1 1 0 0 0 END\n",
        b"",
    )
    assert "store-lock" not in (ram / "routes").read_text()
    noop = run_store(shell, tools, store_fixture, "save", "auto", "0", "0")
    assert noop.returncode == 0, (noop.stdout, noop.stderr[-8000:])
    assert b"unchanged 1 1 0 0 0" in noop.stdout
    assert (source / "config").read_bytes() == before
    saved = run_store(shell, tools, store_fixture, "save", "auto", "0", "1")
    assert saved.returncode == 0, (saved.stdout, saved.stderr)
    assert saved.stdout == b"CFMGR-STORE 1 saved 2 1 1 0 0 END\n"
    expected = before.replace(b'"generation":1', b'"generation":2').replace(
        b'"auto_update":false', b'"auto_update":true'
    )
    assert (source / "config").read_bytes() == expected
    assert (ram / "config.lock").stat().st_size == 0
    assert not (ram / "context").exists()
    assert not list(source.glob(".config-save*"))


@pytest.mark.parametrize(
    "scenario,phase",
    [
        ("arm-stop", ".config-save.preparing"),
        ("publish-stop", ".config-save"),
        ("retire-stop", ".config-save"),
    ],
)
def test_interrupted_phases_recover_old_or_candidate_without_replay(
    shell, tools, store_fixture, scenario, phase
):
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    stopped = run_store(
        shell, tools, store_fixture, "save", "auto", "0", "1", scenario=scenario
    )
    assert stopped.returncode == 1, (stopped.stdout, stopped.stderr)
    assert b"recovery 0 0 0 0 1" in stopped.stdout
    assert (source / phase).is_dir()
    after = (source / "config").read_bytes()
    assert (after != before) == (scenario == "retire-stop")
    recovered = run_store(shell, tools, store_fixture, "recover")
    assert recovered.returncode == 0, (recovered.stdout, recovered.stderr)
    assert b"recovered" in recovered.stdout
    assert (source / "config").read_bytes() == after
    assert not list(source.glob(".config-save*"))


def test_flush_stderr_and_divergent_recovery_preserve_evidence(
    shell, tools, store_fixture
):
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    failed = run_store(
        shell, tools, store_fixture, "save", "check", "0", "0", scenario="flush-error"
    )
    assert failed.returncode == 1
    guard = source / ".config-save.preparing"
    assert guard.exists() and (source / "config").read_bytes() == before
    recovered = run_store(shell, tools, store_fixture, "recover")
    assert recovered.returncode == 1 and guard.exists()


def test_live_rename_flush_error_keeps_candidate_and_guard(shell, tools, store_fixture):
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    failed = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "auto",
        "0",
        "1",
        scenario="post-publish-flush",
    )
    guard = source / ".config-save"
    candidate = before.replace(b'"generation":1', b'"generation":2').replace(
        b'"auto_update":false', b'"auto_update":true'
    )
    assert failed.returncode == 1, (failed.stdout, failed.stderr)
    assert b"recovery 0 0 0 0 1" in failed.stdout
    assert (
        source.parent / "ram/post-publish-flush.injected"
    ).read_bytes() == b"exit=0 stderr=fsync error\n"
    assert (source / "config").read_bytes() == candidate
    assert (guard / "old").read_bytes() == before
    assert not (guard / "candidate").exists()
    assert (guard / "intent").is_file()
    recovered = run_store(shell, tools, store_fixture, "recover")
    assert recovered.returncode == 0, (recovered.stdout, recovered.stderr)
    assert b"recovered" in recovered.stdout
    assert (source / "config").read_bytes() == candidate
    assert not list(source.glob(".config-save*"))


def test_live_rename_verification_corruption_preserves_guard(
    shell, tools, store_fixture
):
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    failed = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "auto",
        "0",
        "1",
        scenario="post-publish-corrupt",
    )
    guard = source / ".config-save"
    assert failed.returncode == 1, (failed.stdout, failed.stderr)
    assert b"recovery 0 0 0 0 1" in failed.stdout
    assert (source / "config").read_bytes() == b"corrupt-after-rename\n"
    assert (guard / "old").read_bytes() == before
    assert (
        source.parent / "ram/post-publish-corrupt.candidate"
    ).read_bytes() == before.replace(b'"generation":1', b'"generation":2').replace(
        b'"auto_update":false', b'"auto_update":true'
    )
    assert (source.parent / "ram/post-publish-corrupt.candidate").read_bytes() != (
        source / "config"
    ).read_bytes()
    assert (guard / "intent").is_file()
    evidence = {item.name: item.read_bytes() for item in guard.iterdir()}
    divergent = (source / "config").read_bytes()
    recovered = run_store(shell, tools, store_fixture, "recover")
    assert recovered.returncode == 1
    assert (source / "config").read_bytes() == divergent
    assert evidence == {item.name: item.read_bytes() for item in guard.iterdir()}


def test_candidate_copy_failure_prevents_live_mutation(shell, tools, store_fixture):
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    failed = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "auto",
        "0",
        "1",
        scenario="candidate-copy-error",
    )
    guard = source / ".config-save.preparing"
    assert failed.returncode == 1, (failed.stdout, failed.stderr)
    assert b"recovery 0 0 0 0 1" in failed.stdout
    assert (source / "config").read_bytes() == before
    assert (guard / "old").read_bytes() == before
    assert not (guard / "candidate").exists()


def test_active_divergent_and_retired_invalid_live_are_preserved(
    shell, tools, store_fixture
):
    source, *_ = store_fixture
    failed = run_store(
        shell, tools, store_fixture, "save", "auto", "0", "1", scenario="publish-stop"
    )
    assert failed.returncode == 1
    guard = source / ".config-save"
    guard.rename(source / ".config-save.retired")
    (source / "config").write_bytes(b"malformed\n")
    snapshot = {
        item.name: item.read_bytes()
        for item in (source / ".config-save.retired").iterdir()
    }
    failed = run_store(shell, tools, store_fixture, "recover")
    assert failed.returncode == 1
    assert snapshot == {
        item.name: item.read_bytes()
        for item in (source / ".config-save.retired").iterdir()
    }


def test_setup_guards_and_nonregular_config_do_not_mutate(shell, tools, store_fixture):
    source, ram, *_ = store_fixture
    before = (source / "config").read_bytes()
    (source / "entry.stage").symlink_to("absent")
    failed = run_store(shell, tools, store_fixture, "save", "auto", "0", "1")
    assert failed.returncode == 1 and b"recovery" in failed.stdout
    assert not (ram / "config.lock").exists()
    assert (source / "config").read_bytes() == before
    (source / "entry.stage").unlink()
    (source / "config").unlink()
    os.mkfifo(source / "config", 0o600)
    failed = run_store(shell, tools, store_fixture, "read")
    assert failed.returncode == 1


def test_unresolved_probe_retains_context_and_failure_receipt(
    shell, tools, store_fixture
):
    source, ram, *_ = store_fixture
    before = (source / "config").read_bytes()
    failed = run_store(
        shell, tools, store_fixture, "save", "auto", "0", "1", scenario="unresolved"
    )
    assert failed.returncode == 3, failed.stderr
    assert failed.stdout == b"CFMGR-STORE 1 unresolved 0 0 0 0 1 END\n"
    assert (ram / "context").exists() and (source / "config").read_bytes() == before


def test_fresh_retry_preserves_raw_edit_and_armed_stale_blocks(
    shell, tools, store_fixture
):
    source, ram, *_ = store_fixture
    before = (source / "config").read_bytes()
    saved = run_store(
        shell, tools, store_fixture, "save", "auto", "0", "1", scenario="raw-edit"
    )
    assert saved.returncode == 0, (saved.stdout, saved.stderr)
    assert (source / "config").read_bytes() == before.replace(
        b'"generation":1', b'"generation":2'
    ).replace(b'"auto_update":false', b'"auto_update":true') + b" "
    assert (ram / "routes").read_text().count("store-mkdir\n") == 2
    stale = run_store(
        shell, tools, store_fixture, "save", "auto", "0", "0", scenario="stale"
    )
    assert stale.returncode == 1 and b"stale 0 0 0 0 1" in stale.stdout
    assert (
        json.loads((source / "config").read_bytes())["manager"]["auto_update"] is True
    )
    assert (source / ".config-save").is_dir()


def test_fresh_retry_remerges_reviewed_intent_and_preserves_other_bytes(
    shell, tools, store_fixture
):
    source, ram, *_ = store_fixture
    saved = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "auto",
        "0",
        "1",
        scenario="semantic-remerge",
    )
    fresh = (ram / "semantic-live").read_bytes()
    expected = (
        fresh.replace(b'"generation": 1', b'"generation": 2', 1)
        .replace(b'"check_updates": false', b'"check_updates": true')
        .replace(b'"auto_update": false', b'"auto_update": true')
    )
    fresh_value = json.loads(fresh)
    assert fresh_value["generation"] == 1
    assert fresh_value["manager"]["check_updates"] is False
    assert fresh_value["manager"]["auto_update"] is False
    assert saved.returncode == 0, (saved.stdout, saved.stderr)
    assert saved.stdout == b"CFMGR-STORE 1 saved 2 1 1 1 0 END\n"
    assert (source / "config").read_bytes() == expected
    saved_value = json.loads(expected)
    assert saved_value["manager"]["developer"] is True
    assert saved_value["ownership"]["config_save"] == {
        "owner": "fixture",
        "generation": 1,
    }
    assert saved_value["cloudflared"]["enabled"] is True
    assert saved_value["credentials"]["cloudflared"]["runtime"] == "fixture-ref"
    assert (ram / "routes").read_text().count("store-mkdir\n") == 2
    assert not list(source.glob(".config-save*"))

    saved_config = (source / "config").read_bytes()
    (source / ".config-save").mkdir(mode=0o700)
    blocked = run_store(shell, tools, store_fixture, "save", "auto", "0", "0")
    assert blocked.returncode == 1
    assert b"recovery 0 0 0 0 1" in blocked.stdout
    assert (source / "config").read_bytes() == saved_config
    assert (source / ".config-save").is_dir()


def test_repeated_semantic_edits_refuse_without_replacing_latest_authority(
    shell, tools, store_fixture
):
    source, ram, *_ = store_fixture
    before = (source / "config").read_bytes()
    refused = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "auto",
        "0",
        "1",
        scenario="semantic-churn",
    )
    latest = (ram / "semantic-live").read_bytes()
    assert refused.returncode == 1
    assert b"CFMGR-STORE 1 stale 0 0 0 0 0 END\n" == refused.stdout
    assert latest != before
    assert (source / "config").read_bytes() == latest
    assert json.loads(latest)["generation"] == 1
    assert (ram / "routes").read_text().count("store-mkdir\n") == 2
    assert not list(source.glob(".config-save*"))
    assert not (ram / "context").exists()
    assert not (ram / "semantic-new").exists()


@pytest.mark.parametrize(
    "scenario,args",
    [
        ("noop-unresolved", ("save", "auto", "0", "0")),
        ("post-unresolved", ("save", "auto", "0", "1")),
    ],
)
def test_live_match_unresolved_is_never_stale(
    shell, tools, store_fixture, scenario, args
):
    source, ram, *_ = store_fixture
    failed = run_store(shell, tools, store_fixture, *args, scenario=scenario)
    assert failed.returncode == 3, (failed.stdout, failed.stderr)
    assert b"unresolved 0 0 0 0 1" in failed.stdout
    assert (ram / "context").exists()
    if scenario == "post-unresolved":
        assert (source / ".config-save").is_dir()


def test_external_lock_busy_prevents_save_and_observation(shell, tools, store_fixture):
    import fcntl

    source, ram, flock, _ = store_fixture
    library = source / "modules/lib/config_store.sh"
    library.write_text(
        library.read_text()
        .replace("/tmp/cfmgr", shlex.quote(str(ram)))
        .replace("/opt/bin/flock", shlex.quote(flock))
    )
    lock = ram / "config.lock"
    lock.touch(mode=0o600)
    before = (source / "config").read_bytes()
    with lock.open("r+b") as owner:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        result = run_store(shell, tools, store_fixture, "save", "auto", "0", "1")
        assert result.returncode == 1 and b"busy" in result.stdout, (
            result.returncode,
            result.stdout,
            result.stderr,
        )
        # Actual launch wrapper/common acquisition; only borrowed firmware path
        # setup is forwarded. A refused lock never enters the publication body.
        script = ADAPTER.replace(
            'cfmgr_config_store "$@"',
            f"""
. {shlex.quote(str(ROOT / "modules/helpers/launch.sh"))}
cfmgr_store_prepare || exit 96
cfmgr_install_source=$source cfmgr_install_jffs=$source cfmgr_install_context=$ram/context cfmgr_install_context_fd=5
cfmgr_install_sh=$TEST_SH cfmgr_install_env=$TEST_ENV cfmgr_install_awk=$TEST_AWK cfmgr_install_sleep=$TEST_SLEEP
cfmgr_install_wc=$TEST_WC cfmgr_install_ls=$TEST_LS cfmgr_install_readlink=$TEST_READLINK
cfmgr_prereq_flock_provider=entware
cfmgr_prerequisites_admit_tool() {{ printf 'already-admitted-entware\\n' >>"$ram/routes"; [ "$1" = "$flock" ] && cfmgr_store_attachment_ok; }}
cfmgr_launch_publish_observation_locked() {{ printf mutated >"$ram/observed"; }}
if cfmgr_launch_publish_observation; then observed_code=0; else observed_code=$?; fi
cfmgr_store_cleanup || exit 98
exit "$observed_code"
""",
        )
        result = run_store(shell, tools, store_fixture, "unused", script=script)
        assert result.returncode == 1 and not (ram / "observed").exists()
    assert "already-admitted-entware" in (ram / "routes").read_text()
    assert (source / "config").read_bytes() == before
    result = run_store(shell, tools, store_fixture, "save", "auto", "0", "1")
    assert result.returncode == 0


def test_fixed_digest_and_intent_frames_reject_ambiguous_receipts(
    shell, tools, tmp_path
):
    record = tmp_path / "frame"
    record.chmod(0o600) if record.exists() else record.touch(mode=0o600)
    digest = "a" * 64
    for mode, payload in (
        ("store-digest-frame", digest + " *stdin\n"),
        ("store-digest-frame", digest + " *stdin\nextra\n"),
        ("store-digest-frame", digest + " file\n"),
        (
            "store-intent",
            f"CFMGR-SETTINGS-INTENT 1 9999999999999999990 9999999999999999992 10 20 {digest} {digest} END\n",
        ),
    ):
        record.write_text(payload)
        operands = [str(record)]
        if mode == "store-intent":
            operands.append(str(len(payload)))
        result = subprocess.run(
            [
                *shell,
                str(ROOT / "modules/helpers/probe.sh"),
                mode,
                tools["awk"],
                str(tmp_path),
                *operands,
            ],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode == 0) == (
            mode == "store-digest-frame" and payload == digest + " *stdin\n"
        )


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="real Linux proc supervision and native inherited FD0 flock",
)
def test_linux_actual_supervisor_save_and_cleanup(shell, tools, store_fixture):
    source, ram, *_ = store_fixture
    # Private fixture alias keeps the exact cleanup body. Capture only bounded
    # synthetic probe output before cleanup deletes it, then emit on failure;
    # successful lock-test contention stays silent and supervision is unchanged.
    library = source / "modules/lib/config_store.sh"
    body = library.read_text()
    assert body.count("cfmgr_store_cleanup() {") == 1
    library.write_text(
        body.replace(
            "cfmgr_store_cleanup() {", "cfmgr_store_diagnostic_cleanup_core() {", 1
        )
    )
    script = ADAPTER[: ADAPTER.index("cfmgr_prerequisites_run() {")]
    script = script.replace(
        "cfmgr_store_deadline=120",
        "cfmgr_prerequisites_now; cfmgr_store_deadline=$((cfmgr_probe_now+20))",
    )
    script = script.replace("cfmgr_prerequisites_now() { cfmgr_probe_now=100; }", "")
    script = script.replace('cfmgr_store_fd_is() { [ -f "$1" ] && [ ! -L "$1" ]; }', "")
    script += (
        f". {shlex.quote(str(ROOT / 'modules/lib/prerequisites.sh'))}\n"
        + pause_definition(shell)
    )
    script += r"""
cfmgr_store_cleanup() {
    diagnostic_mode=${cfmgr_probe_mode:-unset} diagnostic_status=${cfmgr_probe_status:-unset}
    diagnostic_reason=${cfmgr_probe_reason:-unset} diagnostic_exit=${cfmgr_probe_exit:-unset}
    diagnostic_stdout='' diagnostic_stderr=''
    for diagnostic_stream in stdout stderr; do
        case $diagnostic_stream in
        stdout) diagnostic_file=${cfmgr_probe_stdout:-} ;;
        stderr) diagnostic_file=${cfmgr_probe_stderr:-} ;;
        esac
        diagnostic_text='' diagnostic_lines=0
        if [ -f "$diagnostic_file" ] && [ ! -L "$diagnostic_file" ]; then
            while IFS= read -r diagnostic_line || [ -n "$diagnostic_line" ]; do
                diagnostic_lines=$((diagnostic_lines+1))
                # Four lines, 256 bytes each. No context/environment dump.
                diagnostic_text=$diagnostic_text$(printf '%.256s' "$diagnostic_line")'
'
                [ "$diagnostic_lines" -lt 4 ] || break
            done <"$diagnostic_file"
        fi
        case $diagnostic_stream in
        stdout) diagnostic_stdout=$diagnostic_text ;;
        stderr) diagnostic_stderr=$diagnostic_text ;;
        esac
    done
    if cfmgr_store_diagnostic_cleanup_core; then diagnostic_cleanup=0; else diagnostic_cleanup=$?; fi
    if [ "${cfmgr_store_code:-0}" != 0 ] || [ "$diagnostic_cleanup" != 0 ]; then
        printf 'STORE probe diagnostic: mode=%s status=%s reason=%s exit=%s cleanup=%s\n' "$diagnostic_mode" "$diagnostic_status" "$diagnostic_reason" "$diagnostic_exit" "$diagnostic_cleanup" >&2
        printf 'probe stdout: %s\nprobe stderr: %s\n' "$diagnostic_stdout" "$diagnostic_stderr" >&2
    fi
    return "$diagnostic_cleanup"
}
cfmgr_config_store "$@"
"""
    fixture = store_fixture
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        fsync = ram / "fsync"
        fsync.symlink_to(Path(tools["sh"]).resolve())
        fixture = (*store_fixture[:3], str(fsync))
    result = run_store(shell, tools, fixture, "save", "auto", "0", "1", script=script)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout == b"CFMGR-STORE 1 saved 2 1 1 0 0 END\n"
    assert not (ram / "context").exists() and not list(source.glob(".config-save*"))


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="actual Linux unresolved mutator retains inherited lock",
)
@pytest.mark.parametrize("mode", ["store-move", "store-backup-mkdir"])
def test_linux_owned_mutator_keeps_lock_after_controller_closes(
    shell, tools, store_fixture, tmp_path, mode
):
    source, ram, flock, _ = store_fixture
    lock = ram / "config.lock"
    lock.touch(mode=0o600)
    context = ram / "child-context"
    context.mkdir(mode=0o700)
    mutator = tmp_path / "owned-mutator"
    mutator.write_text(
        f"#!{Path(sys.executable).resolve()}\n"
        "import errno,fcntl,os,time\n"
        f"expected=os.stat({str(lock)!r})\n"
        "actual=os.fstat(0)\n"
        "assert (actual.st_dev,actual.st_ino)==(expected.st_dev,expected.st_ino), 'FD0 lost the lock inode'\n"
        "try: fcntl.fcntl(9,fcntl.F_GETFD)\n"
        "except OSError as error: assert error.errno==errno.EBADF\n"
        "else: raise AssertionError('temporary child FD9 alias leaked')\n"
        "time.sleep(0.4)\n"
    )
    mutator.chmod(0o700)
    script = f'''
. {shlex.quote(str(ROOT / "modules/lib/prerequisites.sh"))}
{pause_definition(shell)}
cfmgr_store_attachment_ok() {{ [ "$1" = never ] || [ "$cfmgr_store_lock" -ef /proc/self/fd/0 ]; }}
cfmgr_store_fd_is() {{ [ "$1" -ef "/proc/self/fd/$2" ]; }}
exec 0<>"$1"
"$2" -n 0 || exit 90
cfmgr_config_lock_fd0=1 cfmgr_store_lock=$1
exec 6<"$3"
cfmgr_prerequisites_now; cfmgr_store_deadline=$((cfmgr_probe_now+5))
# Deliberate ownership uncertainty after initial real child identity capture;
# no signal/reap is authorized. The real async exec must still hold FD0.
_cfmgr_prerequisites_observe() {{ cfmgr_probe_status=unresolved; return 3; }}
shift 3
if cfmgr_prerequisites_run "$@"; then exit 91; else [ "$?" = 3 ] || exit 92; fi
owned=$cfmgr_probe_pid
exec 0<&-
exec 7<>"$cfmgr_store_lock"
if "{flock}" -n 7; then exit 93; fi
wait "$owned" || exit 94
"{flock}" -n 7 || exit 95
printf 'retained then released\n'
'''
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "lock-proof",
            str(lock),
            flock,
            str(tmp_path),
            mode,
            str(context),
            tools["sh"],
            str(source / "modules/helpers/probe.sh"),
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            str(mutator),
            *(
                [str(source / "config"), str(tmp_path / "candidate")]
                if mode == "store-move"
                else []
            ),
        ],
        capture_output=True,
        check=False,
        timeout=8,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"retained then released\n",
        b"",
    )


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="actual borrowed FD/mount pins and native/Entware lock compatibility",
)
def test_linux_actual_borrowed_observation_lock_and_crossguard(
    shell, tools, store_fixture
):
    source, ram, flock, _ = store_fixture
    library = source / "modules/lib/config_store.sh"
    library.write_text(
        library.read_text()
        .replace("/tmp/cfmgr", str(ram))
        .replace("/usr/bin/flock", flock)
        .replace("/opt/bin/flock", flock)
    )
    script = ADAPTER[: ADAPTER.index("cfmgr_store_attachment_ok() {")]
    script = script.replace("cfmgr_prerequisites_now() { cfmgr_probe_now=100; }", "")
    script += f"""
. {shlex.quote(str(ROOT / "modules/lib/prerequisites.sh"))}
. {shlex.quote(str(ROOT / "modules/helpers/launch.sh"))}
{pause_definition(shell)}
cfmgr_store_native_tool() {{ [ "$1" = "$flock" ] && [ -x "$flock" ]; }}
cfmgr_launch_attachment_ok() {{ [ "$source" -ef /proc/self/fd/9 ] && [ "$ram/context" -ef /proc/self/fd/5 ] && [ "$source" -ef /proc/self/fd/8 ]; }}
cfmgr_prerequisites_admit_tool() {{ [ "$1" = "$flock" ] && cfmgr_launch_attachment_ok; }}
cfmgr_launch_publish_observation_locked() {{ printf '%s\\n' "$cfmgr_prereq_flock_provider" >>"$ram/observed"; }}
cfmgr_store_prepare || exit 90
cfmgr_install_source=$source cfmgr_install_jffs=$source cfmgr_install_context=$ram/context cfmgr_install_context_fd=5
cfmgr_install_sh=$TEST_SH cfmgr_install_env=$TEST_ENV cfmgr_install_awk=$TEST_AWK cfmgr_install_sleep=$TEST_SLEEP
cfmgr_install_wc=$TEST_WC cfmgr_install_ls=$TEST_LS cfmgr_install_readlink=$TEST_READLINK
cfmgr_install_jffs_snapshot=$("$TEST_AWK" -f "$source/modules/lib/mountinfo.awk" "$source" /proc/self/mountinfo) || exit 91
cfmgr_install_tmp_snapshot=$("$TEST_AWK" -f "$source/modules/lib/mountinfo.awk" /tmp /proc/self/mountinfo) || exit 92
for cfmgr_prereq_flock_provider in native entware; do
    cfmgr_launch_publish_observation || exit 93
    [ "$cfmgr_config_lock_fd0" = 0 ] || exit 94
done
mkdir -m 700 "$source/.config-save"
if cfmgr_launch_publish_observation; then exit 95; fi
[ "$cfmgr_config_lock_fd0" = 0 ] || exit 96
printf 'borrowed locks verified\\n'
"""
    result = run_store(shell, tools, store_fixture, "unused", script=script)
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"borrowed locks verified\n",
        b"",
    )
    assert (ram / "observed").read_text() == "native\nentware\n"
    assert (source / ".config-save").is_dir()
