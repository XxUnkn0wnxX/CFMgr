"""Acquisition completion evidence controls the actual preparation cleanup gate."""

from __future__ import annotations

import os
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_archive import native_program
from tests.test_contained import _run_shell
from tests.test_isolation import FOCUSED_BOUNDARIES, IsolationFixture

ROOT = Path(__file__).resolve().parents[1]
MODULES = ROOT / "modules"
pytestmark = pytest.mark.matrix("V74", evidence="host")

# Prerequisite topology, native null and FD admission have integration coverage.
# The same RAM body allows the actual cleanup consumer to reject or remove it.
APPROVED_PREPARATION = r"""
_cfmgr_isolation_umount_admit() { :; }
_cfmgr_isolation_private() { :; }
_cfmgr_isolation_options() { :; }
_cfmgr_isolation_query() {
  _isolation_body=approved-ram
  if [ "${_fixture_changed-0}" = 1 ] && [ "${_fixture_acquired-0}" = 1 ]; then
    _isolation_body=changed-ram
  fi
  _isolation_facts=$_isolation_volume_facts
  _isolation_fs=tmpfs; _isolation_id=11; _isolation_device=0:11
  _isolation_fs_target=2f; _isolation_options=7277; _isolation_super=7277
  case $1 in
    "$_isolation_resolved") _isolation_fs=ext4; _isolation_id=42 ;;
    /dev/null) _isolation_id=12 ;;
  esac
}
"""


@pytest.mark.integration
def test_killed_fetch_supervisor_keeps_guard_and_live_producer_inode(
    router: RouterHarness,
) -> None:
    isolation = IsolationFixture(router, "/bin/sh")
    supervisor = router.path("work/fetch-supervisor")
    record = router.path("work/live-fetch.json")
    verified = router.path("work/live-fetch-verified")
    ready = router.path("work/fetch-ready")
    release = router.path("work/fetch-release")
    os.mkfifo(ready, 0o600)
    os.mkfifo(release, 0o600)
    capture = (
        "import os; from pathlib import Path; "
        f"Path({str(supervisor)!r}).write_text(str(os.getppid()))"
    )
    original = (MODULES / "fetch.sh").read_text()
    header = "_cfmgr_fetch_run() (\n"
    assert original.count(header) == 1
    fetch = router.write(
        "work/instrumented-fetch.sh",
        original.replace(
            header, header + f"{shlex.quote(sys.executable)} -c {shlex.quote(capture)}\n"
        ),
    )
    fault = router.write(
        "work/held-curl.py",
        "import json, os, signal, sys\nfrom pathlib import Path\n"
        "output=Path(sys.argv[sys.argv.index('--output')+1])\n"
        "closed=[]\n"
        "for fd in range(3,10):\n"
        "    try: os.fstat(fd)\n"
        "    except OSError: closed.append(fd)\n"
        "with output.open('wb') as artifact:\n"
        "    artifact.write(b'live acquisition bytes'); artifact.flush()\n"
        f"    Path({str(record)!r}).write_text(json.dumps({{'pid':os.getpid(), "
        "'inode':os.fstat(artifact.fileno()).st_ino,'closed':closed,'cwd':os.getcwd()}))\n"
        f"    os.kill(int(Path({str(supervisor)!r}).read_text()),signal.SIGTERM)\n"
        f"    with open({str(ready)!r},'wb') as stream: stream.write(b'r')\n"
        f"    with open({str(release)!r},'rb') as stream: stream.read(1)\n",
    )
    router.write(
        "bin/curl",
        f'#!/bin/sh\nexec {shlex.quote(sys.executable)} {shlex.quote(str(fault))} "$@"\n',
        executable=True,
    )
    for name in ("env", "wc", "openssl", "hexdump", "printf", "test", "ln"):
        path = router.root / "bin" / name
        if path.exists() or path.is_symlink():
            path.unlink()
        path.symlink_to("/usr/bin/true" if name == "test" else native_program(name))
    verification = (
        "import json, os, time; from pathlib import Path\n"
        f"assert Path({str(record)!r}).is_file(), 'native producer must have started'\n"
        f"with open({str(ready)!r},'rb') as stream: assert stream.read(1)==b'r'\n"
        f"record=json.loads(Path({str(record)!r}).read_text())\n"
        "os.kill(record['pid'],0)\n"
        "assert record['closed']==list(range(3,10)) and record['cwd']=='/'\n"
        f"guard=Path({str(isolation.guard)!r})\n"
        "assert (guard/'active').read_bytes()==b'prepare\\n'\n"
        "artifact=guard/'acquisition/timeout-download/artifact.ipk'\n"
        "assert artifact.read_bytes()==b'live acquisition bytes'\n"
        "assert artifact.stat().st_ino==record['inode']\n"
        f"Path({str(verified)!r}).write_text('live producer and retained inode')\n"
        f"with open({str(release)!r},'wb') as stream: stream.write(b'x')\n"
        "deadline=time.monotonic()+1\n"
        "while True:\n"
        "    try: os.kill(record['pid'],0)\n"
        "    except ProcessLookupError: break\n"
        "    assert time.monotonic()<deadline, 'released fixture producer did not exit'\n"
        "    time.sleep(0.005)\n"
    )
    sources = [
        MODULES / name
        for name in (
            "io.sh",
            "storage.sh",
            "closure.sh",
            "archive.sh",
            "bootstrap.sh",
            "isolation.sh",
        )
    ]
    script = (
        "\n".join(f". {shlex.quote(str(path))}" for path in sources)
        + f"\n. {shlex.quote(str(fetch))}\n"
        + f"_fixture_volume={shlex.quote(isolation.storage.expected())}\n"
        + FOCUSED_BOUNDARIES
        + APPROVED_PREPARATION
        + 'cfmgr_isolation_acquire_test "$@"\n[ "$?" = 1 ] || exit 21\n'
        + f"{shlex.quote(sys.executable)} -c {shlex.quote(verification)}\n"
    )
    volume = isolation.storage.expected().splitlines()[0].split("\t")
    args = [
        str(router.path("ram/tmp")),
        str(router.path("bin")),
        str(isolation.storage.target),
        str(router.path("work/mountinfo")),
        str(router.path("work/fdinfo")),
        str(router.path("work/block")),
        str(MODULES / "mountinfo.awk"),
        str(MODULES / "storageinfo.awk"),
        "armv7sf-k3.2",
        volume[9],
        volume[6],
        "gzip",
    ]
    result = _run_shell(router, script, args)
    isolation.quiet(result, 0)
    assert verified.read_text() == "live producer and retained inode"
    assert not isolation.mutations()
    assert not any(call["tool"] == "chroot" for call in isolation.calls())
    assert not any(
        call["tool"] == "rm" and call["args"] == ["-rf", str(isolation.guard)]
        for call in isolation.calls()
    )


def test_completed_acquisition_failure_retries_only_after_checked_ram_cleanup(
    router: RouterHarness,
) -> None:
    """Real owned/run/cleanup gates; selectors and native admissions are boundaries."""
    sources = [
        MODULES / name
        for name in ("io.sh", "closure.sh", "fetch.sh", "bootstrap.sh", "isolation.sh")
    ]
    script = "\n".join(f". {shlex.quote(str(path))}" for path in sources)
    script += f"\n_isolation_root={shlex.quote(str(router.path('ram/tmp')))}\n"
    script += (
        APPROVED_PREPARATION
        + r"""
_io_lf='
'
_io_tools=''; _io_wc=/usr/bin/wc; _isolation_tools=''; _isolation_mode=acquire
_isolation_test=/usr/bin/true; _isolation_mkdir=/bin/mkdir
_isolation_rm=/bin/rm; _isolation_printf=/usr/bin/printf
_isolation_resolved=$_isolation_root/source; _isolation_volume_facts=approved-volume
_isolation_probe_profile=armv7sf-k3.2
_cfmgr_bootstrap_materialize_run() {
  [ "$#" = 3 ] && [ -z "$1" ] && [ "$_materialize_complete" = 0 ] || return 9
  /bin/mkdir -m 700 "$3" || return 9
  command printf partial >"$3/partial"
  case $_fixture_outcome in completed) return 10 ;; success) return 0 ;; esac
  return 9
}
_cfmgr_isolation_image_stage() { return 1; }
for scenario in retry retry changed later contradictory; do
  _isolation_guard=$_isolation_root/$scenario; _isolation_tree=$_isolation_guard/root
  _isolation_attempted=0; _isolation_null_recorded=0; _isolation_opt_recorded=0
  _isolation_stage_attempted=0; _fixture_changed=0; _fixture_acquired=0
  _fixture_outcome=completed; [ "$scenario" != later ] || _fixture_outcome=success
  if [ "$scenario" = contradictory ]; then
    _cfmgr_bootstrap_materialize_owned() {
      [ "$_materialize_complete" = 0 ] || return 9
      /bin/mkdir -m 700 "$3" || return 9
      command printf partial >"$3/partial"
      _materialize_complete=1
      return 129
    }
  fi
  _materialize_complete=1
  /bin/mkdir -m 700 "$_isolation_guard" || exit 10
  _cfmgr_isolation_run; [ "$?" = 1 ] || exit 11
  [ "$_isolation_stage_attempted" = 1 ] && [ -f "$_isolation_guard/acquisition/partial" ] || exit 12
  if [ "$scenario" = later ] || [ "$scenario" = contradictory ]; then
    [ -f "$_isolation_guard/active" ] || exit 13
  else
    [ ! -e "$_isolation_guard/active" ] && [ "$_materialize_complete" = 1 ] || exit 14
  fi
  [ "$scenario" != changed ] || { _fixture_changed=1; _fixture_acquired=1; }
  _cfmgr_isolation_cleanup; status=$?
  if [ "$scenario" = retry ]; then
    [ "$status" = 0 ] && [ ! -e "$_isolation_guard" ] || exit 15
  else
    [ "$status" = 1 ] && [ -f "$_isolation_guard/acquisition/partial" ] || exit 16
  fi
done
"""
    )
    result = _run_shell(router, script)
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""
    assert not router.path("ram/tmp/retry").exists()
    assert router.path("ram/tmp/changed/acquisition/partial").read_bytes() == b"partial"
    assert router.path("ram/tmp/later/active").read_bytes() == b"prepare\n"
    assert router.path("ram/tmp/contradictory/active").read_bytes() == b"prepare\n"
