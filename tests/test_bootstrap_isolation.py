"""Bind reviewed bootstrap bytes to an independently approved storage record."""

from __future__ import annotations

import json
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_isolation import FOCUSED_BOUNDARIES, IsolationFixture

ROOT = Path(__file__).resolve().parents[1]
IO = ROOT / "modules/io.sh"
STORAGE = ROOT / "modules/storage.sh"
CLOSURE = ROOT / "modules/closure.sh"
BOOTSTRAP = ROOT / "modules/bootstrap.sh"
SUPERVISION = ROOT / "modules/supervision.sh"
ISOLATION = ROOT / "modules/isolation.sh"
MOUNT_PARSER = ROOT / "modules/mountinfo.awk"
STORAGE_PARSER = ROOT / "modules/storageinfo.awk"
CATALOG = ROOT / "docs/evidence/bootstrap-catalog.json"
PROFILE = "armv7sf-k3.2"
UUID = "00112233-4455-6677-8899-aabbccddeeff"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def approved_manifest(profile: str) -> bytes:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    return b"".join(
        f"{member['path']}\t{member['size']}\t{member['sha256']}\n".encode("ascii")
        for member in catalog["profiles"][profile]["members"]
    )


def authority(isolation: IsolationFixture) -> tuple[str, str]:
    fields = isolation.storage.expected().splitlines()[0].split("\t")
    return fields[9], fields[6]


def runner_script(isolation: IsolationFixture, owner_marker: Path | None = None) -> str:
    boundaries = FOCUSED_BOUNDARIES
    if owner_marker is not None:
        begin_call = '    "$_fixture_begin" "$_fixture_target" "$_fixture_volume" "$@" \\\n'
        assert boundaries.count(begin_call) == 1
        boundaries = boundaries.replace(
            begin_call,
            f"    : > {shlex.quote(str(owner_marker))}\n" + begin_call,
        )
    return (
        f". {shlex.quote(str(IO))}\n"
        f". {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(SUPERVISION))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f"_fixture_volume={shlex.quote(isolation.storage.expected())}\n"
        + boundaries
        + 'cfmgr_isolation_bootstrap_test "$@"\n'
    )


def run_bootstrap(
    isolation: IsolationFixture,
    expected_uuid: str,
    expected_fs_target: str,
    *,
    env: dict[str, str] | None = None,
    owner_marker: Path | None = None,
) -> ShellResult:
    native_printf = isolation.router.path("bin/printf")
    if native_printf.exists() or native_printf.is_symlink():
        native_printf.unlink()
    native_printf.symlink_to("/usr/bin/printf")
    subject = isolation.router.write(
        "work/invoke-bootstrap.sh", runner_script(isolation, owner_marker)
    )
    args = [
        str(isolation.router.path("ram/tmp")),
        str(isolation.router.path("bin")),
        str(isolation.storage.target),
        str(isolation.router.path("work/mountinfo")),
        str(isolation.router.path("work/fdinfo")),
        str(isolation.router.path("work/block")),
        str(MOUNT_PARSER),
        str(STORAGE_PARSER),
        PROFILE,
        expected_uuid,
        expected_fs_target,
        str(isolation.router.path("work/probe-inputs/timeout-coreutils")),
        str(isolation.router.path("work/probe-inputs/gzip-gnu")),
        "gzip",
    ]
    if isolation.router.busybox:
        invocation = f'exec {shlex.quote(str(isolation.router.busybox))} sh "$@"\n'
    else:
        invocation = f'exec {shlex.quote(isolation.storage.shell)} "$@"\n'
    return isolation.router.run(invocation, [str(subject), *args], timeout=30, env=env)


def test_invalid_expected_authority_is_rejected_before_storage_owner(
    router: RouterHarness,
) -> None:
    marker = router.path("work/storage-owner-called")
    script = (
        f". {shlex.quote(str(IO))}\n"
        f". {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(SUPERVISION))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f"cfmgr_storage_with_test() {{ : >{shlex.quote(str(marker))}; return 0; }}\n"
        "expect_invalid() {\n"
        '  cfmgr_isolation_bootstrap_test "$ROOT" "$TOOLS" "$TARGET" "$MOUNT" '
        '"$FDINFO" "$BLOCK" "$MPARSER" "$SPARSER" armv7sf-k3.2 "$1" "$2" '
        '"$TIMEOUT" "$GZIP" gzip\n'
        "  _invalid_status=$?\n"
        '  [ "$_invalid_status" -eq 2 ] || return 1\n'
        "}\n"
        "expect_invalid F0112233-4455-6677-8899-aabbccddeeff 2f || exit 7\n"
        "expect_invalid 00000000-0000-0000-0000-000000000000 2f || exit 8\n"
        f"expect_invalid {UUID} 2f2e || exit 9\n"
        f"expect_invalid {UUID} {'2f' + '00' * 4096} || exit 10\n"
        f"[ ! -e {shlex.quote(str(marker))} ] || exit 11\n"
        'printf "RESULT\\tvalidations-rejected\\n"\n'
    )
    script = (
        f"ROOT={shlex.quote(str(router.path('ram/tmp')))}\n"
        f"TOOLS={shlex.quote(str(router.path('bin')))}\n"
        f"TARGET={shlex.quote(str(router.path('work/volume')))}\n"
        f"MOUNT={shlex.quote(str(router.path('work/mountinfo')))}\n"
        f"FDINFO={shlex.quote(str(router.path('work/fdinfo')))}\n"
        f"BLOCK={shlex.quote(str(router.path('work/block')))}\n"
        f"MPARSER={shlex.quote(str(MOUNT_PARSER))}\n"
        f"SPARSER={shlex.quote(str(STORAGE_PARSER))}\n"
        f"TIMEOUT={shlex.quote(str(router.path('work/timeout')))}\n"
        f"GZIP={shlex.quote(str(router.path('work/gzip')))}\n" + script
    )
    result = router.run(script)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\tvalidations-rejected\n"
    assert result.stderr == ""
    assert not marker.exists()


def test_production_entry_validates_routes_resets_state_and_preserves_owner_status(
    router: RouterHarness,
) -> None:
    marker = router.path("work/production-owner-called")
    values = {
        "ROOT": str(router.path("ram/tmp")),
        "MPARSER": str(MOUNT_PARSER),
        "SPARSER": str(STORAGE_PARSER),
        "TIMEOUT": str(router.path("work/timeout")),
        "GZIP": str(router.path("work/gzip")),
    }
    assignments = "".join(f"{key}={shlex.quote(value)}\n" for key, value in values.items())
    script = (
        f". {shlex.quote(str(IO))}\n"
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(SUPERVISION))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        f". {shlex.quote(str(ISOLATION))}\n" + assignments + f"cfmgr_storage_with() {{\n"
        '  [ "$#" -eq 5 ] && [ "$1" = "$ROOT" ] && [ "$2" = "$MPARSER" ] && '
        '  [ "$3" = "$SPARSER" ] && [ "$4" = _cfmgr_isolation_bootstrap_begin ] && '
        '  [ "$5" = _cfmgr_isolation_probe_run ] && [ "$_isolation_mode" = bootstrap ] && '
        '  [ "$_isolation_probe_pending" = 0 ] && [ -z "$_isolation_probe_manifest" ] || return 9\n'
        f"  : >{shlex.quote(str(marker))}\n"
        "  return 3\n"
        "}\n"
        "expect_status() {\n"
        "  _expected_status=$1\n"
        "  shift\n"
        '  cfmgr_isolation_bootstrap "$@"\n'
        "  _actual_status=$?\n"
        '  [ "$_actual_status" -eq "$_expected_status" ] || return 1\n'
        "}\n"
        'expect_status 2 "$ROOT" "$MPARSER" "$SPARSER" armv7sf-k3.2 '
        f'"{UUID}" 2f "$TIMEOUT" || exit 4\n'
        'expect_status 2 "$ROOT" "$MPARSER" "$SPARSER" unknown-profile '
        f'"{UUID}" 2f "$TIMEOUT" "$GZIP" gzip || exit 5\n'
        'expect_status 2 "$ROOT" "$MPARSER" "$SPARSER" armv7sf-k3.2 '
        f'"{UUID}" 2f "$TIMEOUT" "$GZIP" invalid-mode || exit 6\n'
        'expect_status 3 "$ROOT" "$MPARSER" "$SPARSER" armv7sf-k3.2 '
        f'"{UUID}" 2f "$TIMEOUT" "$GZIP" gzip || exit 7\n'
        'printf "RESULT\\tproduction-route-and-status-preserved\\n"\n'
    )
    result = router.run(
        script,
        env={
            "_isolation_mode": "probe",
            "_isolation_probe_pending": "1",
            "_isolation_probe_manifest": "/ambient/untrusted.tsv",
        },
    )

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\tproduction-route-and-status-preserved\n"
    assert result.stderr == ""
    assert marker.read_text() == ""


def test_acquire_entries_validate_route_and_check_authority_before_guard(
    router: RouterHarness,
) -> None:
    """Use the real approved-ledger comparison with cheap explicit owner boundaries."""
    isolation = IsolationFixture(router, "/bin/sh")
    expected_uuid, expected_fs_target = authority(isolation)
    values = {
        "ROOT": str(router.path("ram/tmp")),
        "TOOLS": str(router.path("bin")),
        "TARGET": str(isolation.storage.target),
        "MOUNT": str(router.path("work/mountinfo")),
        "FDINFO": str(router.path("work/fdinfo")),
        "BLOCK": str(router.path("work/block")),
        "MPARSER": str(MOUNT_PARSER),
        "SPARSER": str(STORAGE_PARSER),
        "UUID": expected_uuid,
        "FS": expected_fs_target,
        "LEDGER": isolation.storage.expected(),
        "OWNER": str(router.path("work/acquire-owners")),
        "ADMITTED": str(router.path("work/acquire-admitted")),
    }
    script = "\n".join(f". {shlex.quote(str(path))}" for path in (IO, CLOSURE, ISOLATION))
    script += "\n" + "".join(f"{key}={shlex.quote(value)}\n" for key, value in values.items())
    script += r"""
_io_tab=$(command printf '\t'); _io_lf='
'
check_reset() {
  [ "$_isolation_mode" = acquire ] && [ "$_isolation_probe_pending" = 0 ] &&
    [ -z "$_isolation_probe_manifest$_isolation_probe_timeout$_isolation_probe_gzip" ]
}
cfmgr_storage_with() {
  [ "$#" = 5 ] && [ "$1" = "$ROOT" ] && [ "$2" = "$MPARSER" ] &&
    [ "$3" = "$SPARSER" ] && [ "$4" = _cfmgr_isolation_acquire_begin ] &&
    [ "$5" = _cfmgr_isolation_probe_run ] && [ -z "$_isolation_tools" ] &&
    check_reset || return 9
  return 3
}
cfmgr_storage_with_test() {
  [ "$#" = 10 ] && [ "$1" = "$ROOT" ] && [ "$2" = "$TOOLS" ] &&
    [ "$3" = "$TARGET" ] && [ "$4" = "$MOUNT" ] && [ "$5" = "$FDINFO" ] &&
    [ "$6" = "$BLOCK" ] && [ "$7" = "$MPARSER" ] && [ "$8" = "$SPARSER" ] &&
    [ "$9" = _cfmgr_isolation_acquire_begin ] && [ "${10}" = _cfmgr_isolation_probe_run ] &&
    check_reset || return 9
  command printf x >>"$OWNER"
  "$9" "$TARGET" "$LEDGER" "${10}"
}
_cfmgr_isolation_begin_args() {
  check_reset && [ "$_isolation_callback" = _cfmgr_isolation_probe_run ] || return 9
  command printf admitted >"$ADMITTED"
  return 124
}
fixture() {
  cfmgr_isolation_acquire_test "$ROOT" "$TOOLS" "$TARGET" "$MOUNT" "$FDINFO" "$BLOCK" \
    "$MPARSER" "$SPARSER" "$@"
}
cfmgr_isolation_acquire "$ROOT" "$MPARSER" "$SPARSER" armv7sf-k3.2 "$UUID" "$FS" gzip
[ "$?" = 3 ] || exit 10
cfmgr_isolation_acquire "$ROOT" "$MPARSER" "$SPARSER" armv7sf-k3.2 "$UUID" "$FS"
[ "$?" = 2 ] || exit 11
fixture armv7sf-k3.2 "$UUID" "$FS" gzip extra; [ "$?" = 2 ] || exit 12
fixture unknown-profile "$UUID" "$FS" gzip; [ "$?" = 2 ] || exit 13
fixture armv7sf-k3.2 "$UUID" "$FS" unknown-mode; [ "$?" = 2 ] || exit 14
fixture armv7sf-k3.2 00000000-0000-0000-0000-000000000000 "$FS" gzip
[ "$?" = 2 ] && [ ! -e "$OWNER" ] && [ ! -e "$ADMITTED" ] || exit 15
fixture armv7sf-k3.2 ffeeddcc-bbaa-9988-7766-554433221100 "$FS" gzip
[ "$?" = 1 ] && [ "$(/bin/cat "$OWNER")" = x ] && [ ! -e "$ADMITTED" ] || exit 16
fixture armv7sf-k3.2 "$UUID" 2f6f74686572 gzip
[ "$?" = 1 ] && [ "$(/bin/cat "$OWNER")" = xx ] && [ ! -e "$ADMITTED" ] || exit 17
fixture armv7sf-k3.2 "$UUID" "$FS" gzip
[ "$?" = 124 ] && [ "$(/bin/cat "$OWNER")" = xxx ] && [ -f "$ADMITTED" ] || exit 18
"""
    result = router.run(
        script,
        env={
            "_isolation_mode": "native",
            "_isolation_probe_pending": "1",
            "_isolation_probe_manifest": "/ambient/manifest",
            "_isolation_probe_timeout": "/ambient/timeout",
            "_isolation_probe_gzip": "/ambient/gzip",
        },
    )
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""
    assert not isolation.guard.exists()
    assert isolation.calls() == []


@pytest.mark.parametrize(
    ("mismatch", "expected_uuid", "expected_fs_target"),
    [
        pytest.param("UUID", "ffeeddcc-bbaa-9988-7766-554433221100", "2f", id="uuid"),
        pytest.param("subtree", UUID, "2f6f74686572", id="same-volume-wrong-subtree"),
    ],
)
def test_storage_authority_mismatch_stops_before_guard_stage_or_mounts(
    router: RouterHarness,
    mismatch: str,
    expected_uuid: str,
    expected_fs_target: str,
) -> None:
    isolation = IsolationFixture(router, "/bin/sh")
    isolation.prepare_probe("gzip")
    owner_marker = router.path(f"work/owner-entered-{mismatch}")
    result = run_bootstrap(isolation, expected_uuid, expected_fs_target, owner_marker=owner_marker)

    isolation.quiet(result, 1)
    assert owner_marker.is_file(), "mismatch must be checked inside the retained owner"
    assert not isolation.guard.exists()
    calls = isolation.calls()
    assert not any(call["tool"] in {"mount", "umount", "chroot"} for call in calls)
    assert not isolation.router.path("work/callback.observation").exists()


def test_matching_authority_reaches_real_closure_and_retains_failed_stage(
    router: RouterHarness,
) -> None:
    isolation = IsolationFixture(router, "/bin/sh")
    isolation.prepare_probe("gzip")
    expected_uuid, expected_fs_target = authority(isolation)
    owner_marker = router.path("work/bootstrap-begin-entered")

    result = run_bootstrap(
        isolation,
        expected_uuid,
        expected_fs_target,
        env={"_isolation_mode": "probe", "_isolation_probe_pending": "1"},
        owner_marker=owner_marker,
    )

    isolation.quiet(result, 1)
    assert owner_marker.is_file()
    assert (isolation.guard / "active").read_bytes() == b"prepare\n"
    assert (isolation.guard / "bootstrap-manifest.tsv").read_bytes() == approved_manifest(PROFILE)
    first_member = isolation.guard / "closure/opt/lib/ld-2.27.so"
    assert first_member.read_bytes() == b"synthetic probe image member 1\n"
    first_row = approved_manifest(PROFILE).splitlines()[0].split(b"\t")
    assert first_member.stat().st_size != int(first_row[1]), "copied synthetic bytes must reject"
    assert isolation.mutations() == []
    assert not any(call["tool"] == "chroot" for call in isolation.calls())
    calls = isolation.calls()
    guard_removals = [
        call
        for call in calls
        if call["tool"] == "rm" and call["args"] == ["-rf", str(isolation.guard)]
    ]
    assert guard_removals == [], "failed preparation cannot prove producer completion"


def test_manifest_construction_failure_marks_stage_attempted_without_closure_call(
    router: RouterHarness,
) -> None:
    marker = router.path("work/manifest-constructor-called")
    closure_marker = router.path("work/closure-consumer-called")
    script = (
        f". {shlex.quote(str(IO))}\n"
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        f". {shlex.quote(str(SUPERVISION))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        "_isolation_mode=bootstrap\n"
        "_isolation_probe_profile=armv7sf-k3.2\n"
        f"_isolation_guard={shlex.quote(str(router.path('ram/tmp/stage-failure')))}\n"
        "_isolation_stage_attempted=0\n"
        f"cfmgr_bootstrap_manifest() {{ : >{shlex.quote(str(marker))}; return 1; }}\n"
        f"_cfmgr_closure_stage() {{ : >{shlex.quote(str(closure_marker))}; return 0; }}\n"
        "_cfmgr_isolation_image_stage\n"
        "_stage_status=$?\n"
        'printf "STAGE\\t%s\\t%s\\n" "$_stage_status" "$_isolation_stage_attempted"\n'
    )
    result = router.run(script)

    assert result.returncode == 0
    assert result.stdout == "STAGE\t1\t1\n"
    assert result.stderr == ""
    assert marker.is_file()
    assert not closure_marker.exists()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_busybox_bootstrap_authority_gate_rejects_mismatch_in_retained_owner_fixture(
    busybox_router: RouterHarness,
) -> None:
    isolation = IsolationFixture(busybox_router, "/bin/sh")
    isolation.prepare_probe("gzip")
    _, expected_fs_target = authority(isolation)
    owner_marker = busybox_router.path("work/busybox-owner-entered")
    result = run_bootstrap(
        isolation,
        "ffeeddcc-bbaa-9988-7766-554433221100",
        expected_fs_target,
        env={"_isolation_mode": "native", "_isolation_probe_pending": "1"},
        owner_marker=owner_marker,
    )

    isolation.quiet(result, 1)
    assert owner_marker.is_file()
    assert not isolation.guard.exists()
    calls = isolation.calls()
    assert not any(call["tool"] in {"mount", "umount", "chroot"} for call in calls)
