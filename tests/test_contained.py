"""Fixed-probe lifecycle consumers over the synthetic mount/chroot doubles."""

from __future__ import annotations

import json
import os
import shlex
from collections.abc import Sequence
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_isolation import IsolationFixture

ROOT = Path(__file__).resolve().parents[1]


def _run_shell(
    router: RouterHarness,
    script: str,
    args: Sequence[str] = (),
    *,
    shell: str = "/bin/sh",
    env=None,
):
    path = router.write("work/consumer.sh", script)
    command = (
        f'exec {shlex.quote(str(router.busybox))} sh "$@"\n'
        if router.busybox is not None
        else f'exec {shlex.quote(shell)} "$@"\n'
    )
    return router.run(command, [str(path), *args], env=env)


@pytest.fixture
def contained(router: RouterHarness, pytestconfig: pytest.Config) -> IsolationFixture:
    return IsolationFixture(router, "/bin/sh", probe_busybox=pytestconfig._cfmgr_busybox)


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_gzip_probe_binds_only_the_checked_image_and_cleans_in_order(
    contained: IsolationFixture,
) -> None:
    result = contained.run_probe(mode="gzip")
    contained.quiet(result, 0)

    tree = str(contained.guard / "root")
    calls = contained.calls()
    chroot = next(call for call in calls if call["tool"] == "chroot")
    assert chroot["args"] == [
        tree,
        "/bootstrap/timeout-coreutils",
        "--foreground",
        "--kill-after=1",
        "3",
        "/bootstrap/gzip-gnu",
        "--version",
    ]
    assert chroot["image_mount"]["optional"] == []
    assert bytes.fromhex(chroot["image_mount"]["options"]) == b"ro,nosuid,nodev,exec"
    assert bytes.fromhex(chroot["image_mount"]["super_options"]) == b"rw"
    mount_calls = [call["args"] for call in contained.mutations() if call["tool"] == "mount"]
    assert mount_calls == [
        ["-n", "-i", "-o", "bind", "/dev/null", tree + "/dev/null"],
        ["-n", "-i", "-o", "make-private", tree + "/dev/null"],
        ["-n", "-i", "-o", "bind,ro", str(contained.guard / "closure/opt"), tree + "/opt"],
        ["-n", "-i", "-o", "make-private", tree + "/opt"],
        [
            "-n",
            "-i",
            "-o",
            "remount,bind,ro,nosuid,nodev,exec",
            str(contained.guard / "closure/opt"),
            tree + "/opt",
        ],
    ]
    assert [call["args"][-1] for call in contained.mutations() if call["tool"] == "umount"] == [
        tree + "/opt",
        tree + "/dev/null",
    ]
    assert not contained.guard.exists()


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_stage_admission_failure_cleans_before_any_mount_or_launch(
    contained: IsolationFixture,
) -> None:
    result = contained.run_probe(bad_manifest=True)
    contained.quiet(result, 1)
    assert not contained.guard.exists()
    assert not contained.mutations()
    assert not any(call["tool"] == "chroot" for call in contained.calls())


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_image_source_descendant_retains_staged_guard_before_launch(
    contained: IsolationFixture,
) -> None:
    result = contained.run_probe(fault="image-descendant")
    contained.quiet(result, 1)
    assert contained.guard.is_dir()
    assert not any(call["tool"] == "chroot" for call in contained.calls())
    assert not contained.mutations()
    state = json.loads(contained.router.path("work/state.json").read_text())
    assert any(
        os.fsdecode(bytes.fromhex(row["point"])) == str(contained.guard / "closure/opt/child")
        for row in state["mounts"]
    )
    contained.restore_probe_fixture_permissions()


IMAGE_CONSUMER = f"""
. {shlex.quote(str(ROOT / "modules/io.sh"))}
. {shlex.quote(str(ROOT / "modules/isolation.sh"))}
_io_tab=$(printf '\\t')
good=726f2c6e6f737569642c6e6f6465762c65786563; ram=72772c65786563
_cfmgr_isolation_image_options "$good" "$ram" || exit 10
_cfmgr_isolation_image_options 726f2c6e6f737569642c6e6f646576 7277 || exit 23
for bad in \\
  72772c6e6f737569642c6e6f6465762c65786563 \\
  726f2c72772c6e6f737569642c6e6f6465762c65786563 \\
  726f2c6e6f737569642c6e6f6465762c6e6f65786563 \\
  726f2c6e6f6465762c65786563 \\
  726f2c6e6f737569642c65786563; do
  _cfmgr_isolation_image_options "$bad" "$ram" && exit 11
done
_cfmgr_isolation_image_options "$good" 726f && exit 12
_cfmgr_isolation_image_options "$good" 72772c6e6f65786563 && exit 13
set_identity() {{
  _isolation_point=2f66697874757265; _isolation_parent=11; _isolation_id=63
  _isolation_ram_id=11; _isolation_source_id=42
  _isolation_device=0:11; _isolation_image_device=0:11
  _isolation_fs=tmpfs; _isolation_image_fs=tmpfs
  _isolation_super=rw; _isolation_image_super=rw
  _isolation_mount_root=2f; _isolation_image_root=2f; _isolation_fs_target=2f
}}
set_identity; _cfmgr_isolation_image_check || exit 14
[ -n "$_isolation_image_identity" ] || exit 15
set_identity; _isolation_parent=12; _cfmgr_isolation_image_check && exit 16
set_identity; _isolation_id=11; _cfmgr_isolation_image_check && exit 24
set_identity; _isolation_id=42; _cfmgr_isolation_image_check && exit 17
set_identity; _isolation_device=0:99; _cfmgr_isolation_image_check && exit 18
set_identity; _isolation_fs=ext4; _cfmgr_isolation_image_check && exit 19
set_identity; _isolation_super=72772c6e6f65786563; _cfmgr_isolation_image_check && exit 20
set_identity; _isolation_mount_root=2f78; _cfmgr_isolation_image_check && exit 21
set_identity; _isolation_fs_target=2f78; _cfmgr_isolation_image_check && exit 22
# Replacing a valid image mount with another valid ID between syscalls must
# fail before publishing its cleanup ledger, even when every other fact matches.
_isolation_guard=/fixture/guard; _isolation_tree=/fixture/root; _isolation_image=/fixture/image
_cfmgr_isolation_absent() {{ :; }}
_cfmgr_isolation_private() {{ :; }}
_cfmgr_isolation_write() {{ case $1 in */mounted-opt) _published=1 ;; esac; }}
_cfmgr_isolation_native_call() {{ _phase=$1; }}
_cfmgr_isolation_query() {{
  set_identity
  [ "$_phase" != "$_changed_phase" ] || _isolation_id=64
}}
for _changed_phase in private-opt remount-opt; do
  _published=0; _isolation_opt_recorded=0
  _cfmgr_isolation_image_bind && exit 25
  [ "$_published:$_isolation_opt_recorded" = 0:0 ] || exit 26
done
exit 0
"""


@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.skipif(not os.path.isfile("/bin/dash"), reason="dash unavailable")
def test_image_flag_and_identity_consumers_reject_drift(router: RouterHarness) -> None:
    result = _run_shell(router, IMAGE_CONSUMER, shell="/bin/dash")
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_image_flag_consumer_runs_under_busybox(busybox_router: RouterHarness) -> None:
    result = _run_shell(busybox_router, IMAGE_CONSUMER)
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_probe_completion_gate_clears_only_after_no_start_or_verified_completion(
    router: RouterHarness,
) -> None:
    source = shlex.quote(str(ROOT / "modules/isolation.sh"))
    script = f"""
. {source}
_cfmgr_isolation_active() {{ printf '%s\\n' "$1" >"$_isolation_guard/active"; }}
_isolation_rm=/bin/rm
check() {{
  _isolation_guard=$1; /bin/mkdir -p "$_isolation_guard"; _isolation_tree=$_isolation_guard/root
  _isolation_probe_mode=gzip; _isolation_tools=/fixture; _isolation_probe_pending=0
  _stub_started=$2; _stub_complete=$3; _stub_status=$4; _stub_return=$5
  cfmgr_supervision_test() {{
    [ "$_supervision_started" = 0 ] && [ "$_supervision_complete" = 0 ] || return 79
    _supervision_started=$_stub_started; _supervision_complete=$_stub_complete
    _supervision_status=$_stub_status; return "$_stub_return"
  }}
  _cfmgr_isolation_probe_run; _observed=$?
  [ "$_observed" = "$6" ] && [ "$_isolation_probe_pending" = "$7" ] || return 1
  if [ "$8" = present ]; then
    [ -f "$_isolation_guard/active" ] || return 1
  else
    [ ! -e "$_isolation_guard/active" ] || return 1
  fi
}}
check "$1/no-start" 0 0 '' 0 1 0 absent || exit 31
check "$1/incomplete-1" 1 0 '' 1 1 1 present || exit 32
check "$1/incomplete-124" 1 0 '' 124 124 1 present || exit 33
check "$1/complete-124" 1 1 124 124 124 0 absent || exit 34
check "$1/complete-capture-failure" 1 1 0 1 1 0 absent || exit 35
"""
    base = router.path("ram/tmp/probe-owner")
    result = _run_shell(
        router, script, [str(base)], env={"_isolation_mode": "native", "_supervision_complete": "1"}
    )
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


@pytest.mark.matrix("V74", evidence="host")
def test_begin_args_preserves_incomplete_124_without_cleanup(router: RouterHarness) -> None:
    base = router.path("ram/tmp/owner-124")
    tools = base / "tools"
    tools.mkdir(parents=True, mode=0o700)
    (base / "root").mkdir(mode=0o700)
    for name, executable in (
        ("mount", "/usr/bin/true"),
        ("umount", "/usr/bin/true"),
        ("mkdir", "/bin/mkdir"),
        ("rm", "/bin/rm"),
        ("printf", "/usr/bin/printf"),
        ("test", "/usr/bin/true"),
        ("ln", "/bin/ln"),
    ):
        (tools / name).symlink_to(executable)
    guard = base / "root/cfmgr-isolation"
    cleanup_record = base / "cleanup-called"
    source = shlex.quote(str(ROOT / "modules/isolation.sh"))
    script = f"""
. {source}
_cfmgr_isolation_exit() {{ :; }}
_cfmgr_isolation_run() {{ _isolation_probe_pending=1; return 124; }}
_cfmgr_isolation_cleanup() {{ printf x >>{shlex.quote(str(cleanup_record))}; return 0; }}
_isolation_mode=probe; _isolation_root={shlex.quote(str(base / "root"))}
_isolation_guard={shlex.quote(str(guard))}; _isolation_tools={shlex.quote(str(tools))}
_isolation_probe_pending=0; _isolation_interrupted=0
_cfmgr_isolation_begin_args
status=$?
[ "$status" = 124 ] || exit 61
[ -d "$_isolation_guard" ] || exit 62
[ ! -e {shlex.quote(str(cleanup_record))} ] || exit 63
exit 0
"""
    result = _run_shell(router, script)
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_probe_entry_validates_profile_mode_and_replaces_inherited_entry_state(
    router: RouterHarness,
) -> None:
    source = "\n".join(
        f". {shlex.quote(str(ROOT / 'modules' / name))}"
        for name in ("io.sh", "storage.sh", "closure.sh", "supervision.sh", "isolation.sh")
    )
    called = router.path("work/storage-called")
    observed = router.path("work/entry-state")
    valid = [
        "/tmp/root",
        "/tmp/tools",
        "/tmp/target",
        "/tmp/mountinfo",
        "/tmp/fdinfo",
        "/tmp/block",
        "/tmp/mountinfo.awk",
        "/tmp/storageinfo.awk",
        "armv7sf-k3.2",
        "/tmp/manifest.tsv",
        "/tmp/timeout",
        "/tmp/gzip",
        "gzip",
    ]
    call = "cfmgr_isolation_probe_test " + " ".join(map(shlex.quote, valid))
    invalid_mode = "cfmgr_isolation_probe_test " + " ".join(
        map(shlex.quote, valid[:-1] + ["invalid"])
    )
    invalid_profile = "cfmgr_isolation_probe_test " + " ".join(
        map(shlex.quote, valid[:8] + ["unknown-profile"] + valid[9:])
    )
    script = f"""
{source}
cfmgr_storage_with_test() {{
  printf x >>{shlex.quote(str(called))}
  printf '%s\\t%s\\t%s\\n' "$_isolation_mode" "$_isolation_probe_pending" \\
    "$_isolation_probe_mode" >{shlex.quote(str(observed))}
}}
{call} || exit 51
cfmgr_isolation_probe_test; [ "$?" = 2 ] || exit 52
{invalid_mode}; [ "$?" = 2 ] || exit 53
{invalid_profile}; [ "$?" = 2 ] || exit 54
"""
    result = _run_shell(
        router,
        script,
        env={
            "_isolation_mode": "native",
            "_isolation_probe_pending": "1",
            "_isolation_probe_mode": "timeout",
            "_supervision_complete": "1",
        },
    )
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""
    assert called.read_text() == "x"
    assert observed.read_bytes() == b"probe\t0\tgzip\n"


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_busy_image_consumer_stops_before_null_and_ram_cleanup(router: RouterHarness) -> None:
    source = shlex.quote(str(ROOT / "modules/isolation.sh"))
    script = f"""
. {source}
_isolation_guard=$1; _isolation_tree=$_isolation_guard/root
_isolation_opt_recorded=1; _isolation_null_recorded=1; _isolation_attempted=1
_cfmgr_isolation_remove() {{ printf '%s\\n' "$1" >>"$_isolation_guard/removals"; return 1; }}
_cfmgr_isolation_query() {{ exit 77; }}
_isolation_rm=/bin/rm
_cfmgr_isolation_cleanup && exit 41
IFS= read -r removal <"$_isolation_guard/removals"
[ "$removal" = opt ] || exit 42
"""
    guard = router.path("ram/tmp/busy-image")
    guard.mkdir(mode=0o700)
    result = _run_shell(router, script, [str(guard)])
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""
