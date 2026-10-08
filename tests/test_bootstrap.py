"""Trusted bootstrap manifest construction from reviewed member identities."""

from __future__ import annotations

import json
import os
import shlex
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / "modules/bootstrap.sh"
CLOSURE = ROOT / "modules/closure.sh"
CATALOG = ROOT / "docs/evidence/bootstrap-catalog.json"
PROFILE_SIZES = {
    "aarch64-k3.10": 546,
    "armv7sf-k3.2": 634,
    "mipselsf-k3.4": 635,
}
pytestmark = pytest.mark.integration


def expected_manifest(profile: str) -> bytes:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    members = catalog["profiles"][profile]["members"]
    return b"".join(
        f"{member['path']}\t{member['size']}\t{member['sha256']}\n".encode("ascii")
        for member in members
    )


def invocation(
    router: RouterHarness, args: tuple[str, ...], *, shell: str | None = None
) -> ShellResult:
    script = (
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        'cfmgr_bootstrap_manifest "$@"\n'
        "_bootstrap_rc=$?\n"
        'printf "RESULT\\t%s\\n" "$_bootstrap_rc"\n'
    )
    subject = router.write("work/bootstrap-invoke.sh", script)
    if shell:
        runner = f'exec {shlex.quote(shell)} "$@"\n'
        return router.run(runner, [str(subject), *args])
    return router.run(
        f'exec {shlex.quote(str(router.busybox))} sh "$@"\n'
        if router.busybox
        else 'exec /bin/sh "$@"\n',
        [str(subject), *args],
    )


def assert_result(result: ShellResult, code: int) -> None:
    assert result.returncode == 0
    assert result.stdout == f"RESULT\t{code}\n"
    assert result.stderr == ""


@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize("profile", PROFILE_SIZES)
def test_manifest_matches_reviewed_catalog_and_real_closure_consumer(
    router: RouterHarness, profile: str
) -> None:
    output = router.path(f"ram/tmp/{profile}.manifest")
    expected = expected_manifest(profile)
    assert len(expected) == PROFILE_SIZES[profile] <= 4096

    result = invocation(router, (profile, str(output)))

    assert_result(result, 0)
    assert output.read_bytes() == expected
    assert output.stat().st_mode & 0o777 == 0o600

    # Exercise the production closure parser against the generated original bytes.
    members = json.loads(CATALOG.read_text(encoding="utf-8"))["profiles"][profile]["members"]
    total_size = sum(member["size"] for member in members)
    wc = shutil.which("wc", path="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin")
    assert wc is not None, "native wc must be preinstalled for closure acceptance"
    consumer = router.write(
        "work/closure-consumer.sh",
        f". {shlex.quote(str(CLOSURE))}\n"
        '_cfmgr_closure_manifest "$1" "$2" "$3"\n'
        "_consumer_rc=$?\n"
        'printf "CONSUMER\\t%s\\t%s\\t%s\\n" "$_consumer_rc" '
        '"${_closure_manifest_bytes:-unset}" "${_closure_manifest_total:-unset}"\n',
    )
    consumed = router.run(
        f'exec {shlex.quote(str(router.busybox))} sh "$@"\n'
        if router.busybox
        else 'exec /bin/sh "$@"\n',
        [str(consumer), profile, str(output), os.path.realpath(wc)],
    )
    assert consumed.returncode == 0
    assert consumed.stderr == ""
    assert consumed.stdout == f"CONSUMER\t0\t{len(expected)}\t{total_size}\n"


@pytest.mark.matrix("V74", evidence="host")
def test_invalid_api_profiles_and_noncanonical_paths_are_rejected(
    router: RouterHarness,
) -> None:
    valid = "armv7sf-k3.2"
    invalid_calls = [
        ((), "missing arguments"),
        ((valid,), "one argument"),
        ((valid, "/tmp/output", "extra"), "extra argument"),
        (("unknown-profile", "/tmp/output"), "unknown profile"),
    ]
    for args, label in invalid_calls:
        result = invocation(router, args)
        try:
            assert_result(result, 2)
        except AssertionError as error:
            raise AssertionError(f"{label}: {error}") from error

    local = router.path("ram/tmp/invalid")
    invalid_paths = [
        ("relative/output", router.path("work/relative/output")),
        ("/", None),
        (f"{local}/output/", local / "output"),
        (f"{local}//output", local / "output"),
        (f"{local}/./output", local / "output"),
        (f"{local}/../output", local.parent / "output"),
        (f"{local}/out\nput", local / "out\nput"),
        ("/" + "x" * 4096, None),
    ]
    for index, (path, candidate) in enumerate(invalid_paths):
        result = invocation(router, (valid, path))
        try:
            assert_result(result, 2)
        except AssertionError as error:
            raise AssertionError(f"invalid path case {index} ({path!r}): {error}") from error
        if candidate is not None:
            assert not candidate.exists(), f"invalid path case {index} created output"


@pytest.mark.matrix("V74", evidence="host")
def test_existing_output_nodes_are_never_opened_or_replaced(router: RouterHarness) -> None:
    base = router.path("ram/tmp/existing")
    base.mkdir(mode=0o700)
    regular = base / "regular"
    regular.write_bytes(b"preserve me")
    directory = base / "directory"
    directory.mkdir(mode=0o700)
    target = base / "target"
    target.write_bytes(b"symlink target")
    symlink = base / "symlink"
    symlink.symlink_to(target)
    dangling = base / "dangling"
    dangling.symlink_to(base / "missing")
    fifo = base / "fifo"
    os.mkfifo(fifo, 0o600)

    for node in (regular, directory, symlink, dangling, fifo):
        result = invocation(router, ("armv7sf-k3.2", str(node)))
        try:
            assert_result(result, 1)
        except AssertionError as error:
            raise AssertionError(f"existing {node.name} node must fail closed: {error}") from error

    assert regular.read_bytes() == b"preserve me"
    assert directory.is_dir()
    assert symlink.is_symlink() and os.readlink(symlink) == str(target)
    assert dangling.is_symlink() and not (base / "missing").exists()
    assert fifo.is_fifo()


@pytest.mark.matrix("V74", evidence="host")
def test_call_preserves_caller_shell_state_and_runs_with_poisoned_closure_tools(
    router: RouterHarness,
) -> None:
    output = router.path("ram/tmp/state.manifest")
    trap_marker = router.path("ram/tmp/exit-trap")
    shell = shutil.which("dash", path="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin") or "/bin/sh"
    script = (
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        "set +f\n"
        "set -- first second\n"
        "IFS=:\n"
        "LC_ALL=POSIX\n"
        "umask 027\n"
        "_closure_tools=/poisoned/tools\n"
        f"_bootstrap_trap_marker={shlex.quote(str(trap_marker))}\n"
        "trap 'printf fired >> \"$_bootstrap_trap_marker\"' 0\n"
        f"cfmgr_bootstrap_manifest armv7sf-k3.2 {shlex.quote(str(output))}\n"
        "_state_rc=$?\n"
        "case $- in *f*) _noglob=yes ;; *) _noglob=no ;; esac\n"
        'printf "STATE\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "$_state_rc" '
        '"$_noglob" "$#" "$1" "$2" "$IFS" "$LC_ALL" "$_closure_tools"\n'
        "umask\n"
    )
    subject = router.write("work/bootstrap-state.sh", script)
    result = router.run(f'exec {shlex.quote(shell)} "$@"\n', [str(subject)])

    assert result.returncode == 0
    assert result.stderr == ""
    assert result.stdout == ("STATE\t0\tno\t2\tfirst\tsecond\t:\tPOSIX\t/poisoned/tools\n0027\n")
    assert trap_marker.read_bytes() == b"fired"
    assert output.read_bytes() == expected_manifest("armv7sf-k3.2")


@pytest.mark.matrix("V74", evidence="host")
def test_bounded_write_failure_returns_io_error_and_retains_partial_file(
    router: RouterHarness,
) -> None:
    output = router.path("ram/tmp/limited.manifest")
    subject = router.write(
        "work/bootstrap-limited.sh",
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        "ulimit -f 0\n"
        "trap ':' XFSZ\n"
        'cfmgr_bootstrap_manifest armv7sf-k3.2 "$1"\n'
        "_write_rc=$?\n"
        'printf "RESULT\\t%s\\n" "$_write_rc"\n',
    )
    result = router.run('exec /bin/sh "$@"\n', [str(subject), str(output)])

    assert_result(result, 1)
    assert output.is_file()
    assert output.stat().st_size == 0
    assert output.read_bytes() != expected_manifest("armv7sf-k3.2")


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_shell_builds_and_consumes_representative_manifest(
    busybox_router: RouterHarness,
) -> None:
    output = busybox_router.path("ram/tmp/busybox.manifest")
    result = invocation(busybox_router, ("mipselsf-k3.4", str(output)))

    assert_result(result, 0)
    assert output.read_bytes() == expected_manifest("mipselsf-k3.4")
    assert output.stat().st_mode & 0o777 == 0o600
