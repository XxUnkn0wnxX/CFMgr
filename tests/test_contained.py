"""Fixed-probe lifecycle consumers over the synthetic mount/chroot doubles."""

from __future__ import annotations

import hashlib
import json
import os
import shlex
import sys
from collections.abc import Sequence
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_isolation import FOCUSED_BOUNDARIES, IsolationFixture

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
def test_stage_admission_failure_retains_before_any_mount_or_launch(
    contained: IsolationFixture,
) -> None:
    result = contained.run_probe(bad_manifest=True)
    contained.quiet(result, 1)
    assert (contained.guard / "active").read_bytes() == b"prepare\n"
    first_member = contained.guard / "closure/opt/lib/ld-2.27.so"
    source = contained.storage.target / "lib/ld-2.27.so"
    assert first_member.read_bytes() == source.read_bytes()
    supplied_digest = contained.probe_manifest.read_bytes().splitlines()[0].split(b"\t")[2]
    assert hashlib.sha256(first_member.read_bytes()).hexdigest().encode() != supplied_digest
    assert not any(
        call["tool"] == "rm" and call["args"] == ["-rf", str(contained.guard)]
        for call in contained.calls()
    )
    assert not contained.mutations()
    assert not any(call["tool"] == "chroot" for call in contained.calls())


def preparation_consumer(router: RouterHarness) -> str:
    """Exercise actual preparation flow; admission and the next bind are boundaries."""
    link = router.write(
        "work/preparation-ln",
        "#!/bin/sh\n"
        "guard=${3%/root/bootstrap/*}\n"
        'IFS= read -r active <"$guard/active"\n'
        '[ "$active" = prepare ] || exit 7\n'
        'if [ "$_fixture_failure" = links ] && [ "${3##*/}" = gzip-gnu ]; then exit 1; fi\n'
        'exec /bin/ln "$@"\n',
        executable=True,
    )
    return f"""
. {shlex.quote(str(ROOT / "modules/isolation.sh"))}
_io_lf='
'
_isolation_test=/usr/bin/true; _isolation_mkdir=/bin/mkdir; _isolation_rm=/bin/rm
_isolation_ln={shlex.quote(str(link))}; _isolation_tools=''; _isolation_probe_profile=armv7sf-k3.2
_isolation_root=$1; _isolation_resolved=$1/source; _isolation_volume_facts=facts
shift
_cfmgr_isolation_umount_admit() {{ :; }}
_cfmgr_isolation_private() {{ :; }}
_cfmgr_isolation_options() {{ :; }}
_cfmgr_isolation_query() {{
  _isolation_fs=tmpfs; [ "$1" != "$_isolation_resolved" ] || _isolation_fs=ext4
  _isolation_id=11; _isolation_device=0:11; _isolation_fs_target=2f
  _isolation_options=7277; _isolation_super=7277; _isolation_facts=facts; _isolation_body=ram
}}
_cfmgr_isolation_active() {{
  [ "$1" = prepare ] || return 7
  command printf '%s\\n' "$1" >"$_isolation_guard/active"
}}
_cfmgr_isolation_write() {{
  [ "$1" = "$_isolation_tree/dev/null" ] || return 7
  [ -f "$_isolation_guard/active" ] || return 7
  [ "$_fixture_failure" != null ] || return 1
  command printf '%s' "$2" >"$1"
}}
cfmgr_bootstrap_materialize() {{
  [ "$#" = 2 ] && [ "$1" = armv7sf-k3.2 ] &&
    [ "$2" = "$_isolation_guard/acquisition" ] && [ -f "$_isolation_guard/active" ] || return 7
  /bin/mkdir -m 700 "$2" || return 1
  command printf partial >"$2/partial"
  [ "$_fixture_failure" != acquire ] || return 1
  /bin/mkdir -m 700 "$2/timeout" "$2/gzip" || return 1
  command printf timeout >"$2/timeout/program"
  command printf gzip >"$2/gzip/program"
}}
_cfmgr_bootstrap_materialize_owned() {{
  [ "$#" = 3 ] && [ "$_materialize_complete" = 0 ] || return 7
  [ -z "$1" ] || [ "$1" = {shlex.quote(str(router.path("bin")))} ] || return 7
  cfmgr_bootstrap_materialize "$2" "$3" || return 129
  _materialize_complete=1
}}
_cfmgr_isolation_image_stage() {{
  [ -f "$_isolation_guard/active" ] || return 7
  if [ "$_isolation_mode" = acquire ]; then
    [ "$_isolation_probe_timeout" = "$_isolation_guard/acquisition/timeout/program" ] &&
      [ "$_isolation_probe_gzip" = "$_isolation_guard/acquisition/gzip/program" ] || return 7
    [ -f "$_isolation_probe_timeout" ] && [ -f "$_isolation_probe_gzip" ] || return 7
  fi
  [ "$_fixture_failure" != stage ] || return 1
}}
_cfmgr_isolation_bind() {{
  [ "$1" = null ] && [ ! -e "$_isolation_guard/active" ] || return 7
  [ -f "$_isolation_tree/dev/null" ] || return 7
  for directory in opt dev bootstrap tmp offline; do
    [ -d "$_isolation_tree/$directory" ] || return 7
  done
  if [ "$_isolation_mode" != native ]; then
    [ -L "$_isolation_tree/bootstrap/timeout-coreutils" ] &&
      [ -L "$_isolation_tree/bootstrap/gzip-gnu" ] || return 7
  fi
  command printf bound >"$_isolation_guard/bind-entered"
  [ "$_isolation_mode" != acquire ] || return 0
  return 1
}}
_cfmgr_isolation_image_bind() {{
  [ "$_isolation_mode" = acquire ] && [ -f "$_isolation_guard/bind-entered" ] &&
    [ ! -e "$_isolation_guard/active" ]
}}
_cfmgr_isolation_probe_run() {{
  [ "$_isolation_mode" = acquire ] || return 7
  command printf probe >"$_isolation_guard/probe-entered"
  return 1
}}
for scenario do
  _isolation_mode=${{scenario%%:*}}; _fixture_failure=${{scenario#*:}}
  _isolation_tools=''
  [ "$_fixture_failure" != fixture ] || _isolation_tools={shlex.quote(str(router.path("bin")))}
  export _fixture_failure
  _isolation_guard=$_isolation_root/$scenario; _isolation_tree=$_isolation_guard/root
  _isolation_attempted=0; _isolation_null_recorded=0; _isolation_opt_recorded=0
  _isolation_stage_attempted=0
  /bin/mkdir -m 700 "$_isolation_guard" || exit 10
  _cfmgr_isolation_run; status=$?
  [ "$status" = 1 ] || exit 11
  if [ "$_fixture_failure" = ok ] || [ "$_fixture_failure" = fixture ]; then
    [ -f "$_isolation_guard/bind-entered" ] && [ ! -e "$_isolation_guard/active" ] || exit 12
    [ "$_isolation_mode" != acquire ] || [ -f "$_isolation_guard/probe-entered" ] || exit 21
  else
    [ ! -e "$_isolation_guard/bind-entered" ] || exit 13
    IFS= read -r active <"$_isolation_guard/active"
    [ "$active" = prepare ] || exit 14
    _cfmgr_isolation_cleanup; [ "$?" = 1 ] || exit 15
    [ -d "$_isolation_guard" ] || exit 16
    case $_fixture_failure in
      null) [ -d "$_isolation_tree/dev" ] && [ ! -e "$_isolation_tree/dev/null" ] || exit 17 ;;
      links) [ -L "$_isolation_tree/bootstrap/timeout-coreutils" ] &&
        [ ! -e "$_isolation_tree/bootstrap/gzip-gnu" ] &&
        [ ! -L "$_isolation_tree/bootstrap/gzip-gnu" ] || exit 18 ;;
      acquire) [ -f "$_isolation_guard/acquisition/partial" ] || exit 19 ;;
      stage) [ ! -e "$_isolation_tree" ] || exit 20 ;;
    esac
  fi
done
"""


@pytest.mark.matrix("V74", evidence="host")
def test_preparation_is_protected_for_all_modes_until_the_first_bind(router: RouterHarness) -> None:
    cases = [
        "native:ok",
        "probe:ok",
        "bootstrap:ok",
        "acquire:ok",
        "acquire:fixture",
        "native:null",
        "probe:stage",
        "bootstrap:links",
        "acquire:acquire",
    ]
    result = _run_shell(router, preparation_consumer(router), [str(router.path("ram/tmp")), *cases])
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_busybox_preparation_retains_metadata_failure_and_reaches_acquired_bind(
    busybox_router: RouterHarness,
) -> None:
    result = _run_shell(
        busybox_router,
        preparation_consumer(busybox_router),
        [str(busybox_router.path("ram/tmp")), "native:null", "acquire:ok"],
    )
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_interrupted_closure_intermediate_retains_guard_with_live_producer(
    contained: IsolationFixture,
) -> None:
    """Kill the build shell while its dd fault double still holds the copied inode."""
    contained.prepare_probe()
    router = contained.router
    build_pid = router.path("work/build-pid")
    producer = router.path("work/producer.json")
    verified = router.path("work/live-producer-verified")
    release = router.path("work/release-producer")
    os.mkfifo(release, 0o600)
    probe_code = (
        "import os; from pathlib import Path; "
        f"Path({str(build_pid)!r}).write_text(str(os.getppid()))"
    )
    original = (ROOT / "modules/closure.sh").read_text()
    header = "_cfmgr_closure_build() (\n"
    assert original.count(header) == 1
    instrumented = router.write(
        "work/instrumented-closure.sh",
        original.replace(
            header, header + f"{shlex.quote(sys.executable)} -c {shlex.quote(probe_code)}\n"
        ),
    )
    producer_code = router.write(
        "work/held-producer.py",
        "import json, os, signal, sys\nfrom pathlib import Path\n"
        f"Path({str(producer)!r}).write_text(json.dumps({{'pid': os.getpid(), "
        "'output_inode': os.fstat(1).st_ino, 'source_inode': os.fstat(9).st_ino}))\n"
        "sys.stdout.buffer.write(sys.stdin.buffer.read(8)); sys.stdout.buffer.flush()\n"
        f"os.kill(int(Path({str(build_pid)!r}).read_text()), signal.SIGTERM)\n"
        f"with open({str(release)!r}, 'rb') as stream: stream.read(1)\n",
    )
    dd = router.root / "bin/dd"
    dd.unlink()
    router.write(
        "bin/dd",
        f"#!/bin/sh\nexec {shlex.quote(sys.executable)} {shlex.quote(str(producer_code))}\n",
        executable=True,
    )
    printf = router.root / "bin/printf"
    if printf.exists() or printf.is_symlink():
        printf.unlink()
    printf.symlink_to("/usr/bin/printf")
    # Topology and native null/FD admission have complete integration coverage.
    # This case keeps the owner and real copy, isolating interrupted preparation.
    predicate = router.root / "bin/test"
    predicate.unlink()
    predicate.symlink_to("/usr/bin/true")
    verification = (
        "import json, os, time; from pathlib import Path\n"
        f"record=json.loads(Path({str(producer)!r}).read_text())\n"
        "os.kill(record['pid'], 0)\n"
        f"guard=Path({str(contained.guard)!r})\n"
        "assert (guard/'active').read_bytes()==b'prepare\\n'\n"
        "copy=guard/'closure/opt/lib/ld-2.27.so'\n"
        "assert copy.read_bytes()==b'syntheti' and copy.stat().st_ino==record['output_inode']\n"
        f"assert record['source_inode']==os.stat({str(contained.storage.target)!r}).st_ino\n"
        f"Path({str(verified)!r}).write_text('live producer, retained inode and storage FD')\n"
        f"with open({str(release)!r}, 'wb') as stream: stream.write(b'x')\n"
        "deadline=time.monotonic()+1\n"
        "while True:\n"
        "    try: os.kill(record['pid'], 0)\n"
        "    except ProcessLookupError: break\n"
        "    assert time.monotonic()<deadline, 'released fixture producer did not exit'\n"
        "    time.sleep(0.005)\n"
    )
    sources = [
        ROOT / "modules" / name
        for name in ("io.sh", "storage.sh", "supervision.sh", "isolation.sh")
    ]
    script = (
        "\n".join(f". {shlex.quote(str(source))}" for source in sources)
        + f"\n. {shlex.quote(str(instrumented))}\n"
        + f"_fixture_volume={shlex.quote(contained.storage.expected())}\n"
        + FOCUSED_BOUNDARIES
        + r"""
_cfmgr_isolation_umount_admit() { :; }
_cfmgr_isolation_private() { :; }
_cfmgr_isolation_options() { :; }
_cfmgr_isolation_query() {
  _isolation_body=approved-ram
  _isolation_facts=$_isolation_volume_facts
  _isolation_fs=tmpfs; _isolation_id=11; _isolation_device=0:11
  _isolation_fs_target=2f; _isolation_options=7277; _isolation_super=7277
  case $1 in
    "$_isolation_resolved") _isolation_fs=ext4; _isolation_id=42 ;;
    /dev/null) _isolation_id=12 ;;
  esac
}
"""
        + 'cfmgr_isolation_probe_test "$@"\n[ "$?" = 1 ] || exit 21\n'
        + f"{shlex.quote(sys.executable)} -c {shlex.quote(verification)}\n"
    )
    args = [
        str(router.path("ram/tmp")),
        str(router.path("bin")),
        str(contained.storage.target),
        str(router.path("work/mountinfo")),
        str(router.path("work/fdinfo")),
        str(router.path("work/block")),
        str(ROOT / "modules/mountinfo.awk"),
        str(ROOT / "modules/storageinfo.awk"),
        "armv7sf-k3.2",
        str(contained.probe_manifest),
        str(contained.probe_timeout),
        str(contained.probe_gzip),
        "gzip",
    ]
    result = _run_shell(router, script, args)
    contained.quiet(result, 0)
    assert verified.read_text() == "live producer, retained inode and storage FD"
    assert contained.mutations() == []
    assert not any(call["tool"] == "chroot" for call in contained.calls())
    assert not any(
        call["tool"] == "rm" and call["args"] == ["-rf", str(contained.guard)]
        for call in contained.calls()
    )


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
