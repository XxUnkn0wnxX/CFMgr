"""Entware admission checks over retained storage observations."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_dependency_lock import LockFixture
from tests.test_storage import IO, STORAGE, UUID, StorageFixture, quiet
from tests.test_storageinfo import ledger

ROOT = Path(__file__).resolve().parents[1]
ENTWARE = ROOT / "modules/lib/entware.sh"
DEPENDENCY_LOCK = ROOT / "modules/lib/dependency_lock.sh"
MOUNT_PARSER = ROOT / "modules/lib/mountinfo.awk"
STORAGE_PARSER = ROOT / "modules/lib/storageinfo.awk"
TARGET = "/opt"
TARGET_HEX = TARGET.encode().hex()
OTHER_UUID = "11112233-4455-6677-8899-aabbccddeeff"
pytestmark = pytest.mark.matrix("V74", evidence="host")


def volume_ledger(
    *,
    uuid: str = UUID,
    fs_target_hex: str = TARGET_HEX,
    mount_options: bytes = b"rw,relatime",
    super_options: bytes = b"rw",
) -> str:
    return ledger(
        "volume",
        "42",
        "8:1",
        "ext4",
        b"/".hex(),
        TARGET.encode().hex(),
        fs_target_hex,
        mount_options.hex(),
        super_options.hex(),
        uuid,
    )


def consumer_prefix(router: RouterHarness, observation: str) -> str:
    """Stub only the storage acquisition boundary with a complete valid ledger."""
    router.write(
        "work/prefix.sh",
        f""". {shlex.quote(str(IO))}
. {shlex.quote(str(STORAGE))}
. {shlex.quote(str(ENTWARE))}
cfmgr_storage_with() {{
    : >{shlex.quote(str(router.path("work/storage-called")))}
    [ "$#" -ge 4 ] || return 91
    [ "$1" = /trusted/ram ] && [ "$2" = {shlex.quote(str(MOUNT_PARSER))} ] &&
        [ "$3" = {shlex.quote(str(STORAGE_PARSER))} ] || return 92
    _fixture_callback=$4
    shift 4
    "$_fixture_callback" {shlex.quote(TARGET)} {shlex.quote(observation)} "$@"
}}
cfmgr_storage_with_test() {{
    : >{shlex.quote(str(router.path("work/storage-called")))}
    [ "$#" -ge 9 ] || return 93
    _fixture_callback=$9
    shift 9
    "$_fixture_callback" {shlex.quote(TARGET)} {shlex.quote(observation)} "$@"
}}
""",
    )
    return f". {shlex.quote(str(router.path('work/prefix.sh')))}\n"


def invoke_consumer(
    router: RouterHarness,
    *,
    entry: str = "test",
    expected_uuid: str = UUID,
    expected_hex: str = TARGET_HEX,
    callback: str = "fixture_callback",
    callback_body: str = "return 0",
    callback_args: tuple[str, ...] = (),
    observation: str | None = None,
    setup: str = "",
    preserve_state: bool = False,
    invocation_args: tuple[str, ...] | None = None,
) -> ShellResult:
    prefix = consumer_prefix(router, observation or volume_ledger())
    state_check = (
        'result=$?; [ "$IFS" = x ] || exit 99; case $- in *f*) : ;; *) exit 99 ;; esac; '
        '[ "$(umask)" = 0027 ] && [ "$(trap)" = "$before" ] && '
        '[ "$(set +o)" = "$options" ] || exit 99; exit "$result"\n'
        if preserve_state
        else ""
    )
    router.write(
        "work/invoke.sh",
        prefix
        + setup
        + f"fixture_callback() {{ {callback_body}; }}\n"
        + ("cfmgr_entware_with " if entry == "production" else "cfmgr_entware_with_test ")
        + '"$@"\n'
        + state_check,
    )
    if invocation_args is None:
        invocation_args = (
            str(router.path("ram/tmp")),
            str(router.path("bin")),
            str(router.path("work/target")),
            str(router.path("work/mountinfo")),
            str(router.path("work/fdinfo")),
            str(router.path("work/block")),
            str(MOUNT_PARSER),
            str(STORAGE_PARSER),
            expected_uuid,
            expected_hex,
            callback,
            *callback_args,
        )
    script = f". {shlex.quote(str(router.path('work/invoke.sh')))}\n"
    return router.run(script, invocation_args, timeout=5)


def test_fixture_api_admits_exact_identity_and_forwards_consumer_arguments(
    router: RouterHarness,
) -> None:
    expected = volume_ledger()
    marker = router.path("work/callback-called")
    result = invoke_consumer(
        router,
        callback_body=(
            f'[ "$1" = {shlex.quote(TARGET)} ] && '
            f'[ "$2" = {shlex.quote(expected)} ] && [ "$3" = "one two" ] && '
            f'[ "$4" = {shlex.quote("$(touch never)")} ] && '
            '[ "$#" -eq 5 ] && [ -z "$5" ] || return 88; '
            f'printf "called\\n" >>{shlex.quote(str(marker))}; printf "secret out\\n"; '
            'printf "secret err\\n" >&2; return 0'
        ),
        callback_args=("one two", "$(touch never)", ""),
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert marker.read_text() == "called\n"
    assert not router.path("work/never").exists()


def test_production_entry_delegates_authority_to_native_storage(router: RouterHarness) -> None:
    expected = volume_ledger()
    result = invoke_consumer(
        router,
        entry="production",
        callback_body=(
            f'[ "$1" = {shlex.quote(TARGET)} ] && '
            f'[ "$2" = {shlex.quote(expected)} ] && [ "$3" = "production arg" ]'
        ),
        callback_args=("production arg",),
        invocation_args=(
            "/trusted/ram",
            str(MOUNT_PARSER),
            str(STORAGE_PARSER),
            UUID,
            TARGET_HEX,
            "fixture_callback",
            "production arg",
        ),
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""


@pytest.mark.parametrize(
    ("uuid", "fs_hex", "status"),
    [
        (OTHER_UUID, TARGET_HEX, 1),
        (UUID, b"/opt/subtree".hex(), 1),
    ],
    ids=["uuid-mismatch", "filesystem-target-mismatch"],
)
def test_saved_identity_mismatch_does_not_call_consumer(
    router: RouterHarness, uuid: str, fs_hex: str, status: int
) -> None:
    marker = router.path("work/callback-called")
    result = invoke_consumer(
        router,
        observation=volume_ledger(uuid=uuid, fs_target_hex=fs_hex),
        callback_body=f": >{shlex.quote(str(marker))}",
    )
    quiet(result, status)
    assert not marker.exists()


@pytest.mark.parametrize(
    ("mount_options", "super_options"),
    [
        (b"ro,relatime", b"rw"),
        (b"rw,relatime", b"ro"),
        (b"rw,relatime,noexec", b"rw"),
        (b"rw", b"rw,noexec"),
        (b"rwfoo", b"rw"),
        (b"rw", b"xro"),
    ],
    ids=["mount-ro", "super-ro", "mount-noexec", "super-noexec", "rw-substring", "ro-substring"],
)
def test_rw_and_exec_flags_are_complete_tokens_in_both_option_lists(
    router: RouterHarness, mount_options: bytes, super_options: bytes
) -> None:
    marker = router.path("work/callback-called")
    result = invoke_consumer(
        router,
        observation=volume_ledger(mount_options=mount_options, super_options=super_options),
        callback_body=f": >{shlex.quote(str(marker))}",
    )
    quiet(result, 1)
    assert not marker.exists()


def test_option_substrings_are_not_rejected_as_standalone_flags(router: RouterHarness) -> None:
    marker = router.path("work/callback-called")
    result = invoke_consumer(
        router,
        observation=volume_ledger(
            mount_options=b"rw,errors=remount-ro", super_options=b"rw,noexec=off"
        ),
        callback_body=f": >{shlex.quote(str(marker))}",
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert marker.is_file()


@pytest.mark.parametrize(
    ("uuid", "fs_hex", "callback", "extras"),
    [
        ("", TARGET_HEX, "fixture_callback", ()),
        ("A0112233-4455-6677-8899-aabbccddeeff", TARGET_HEX, "fixture_callback", ()),
        ("00000000-0000-0000-0000-000000000000", TARGET_HEX, "fixture_callback", ()),
        (UUID, "", "fixture_callback", ()),
        (UUID, "2f6F7074", "fixture_callback", ()),
        (UUID, "2f6f7", "fixture_callback", ()),
        (UUID, "2e2f6f7074", "fixture_callback", ()),
        (UUID, (b"/" + b"a" * 4096).hex(), "fixture_callback", ()),
        (UUID, TARGET_HEX, "bad-callback", ()),
    ],
    ids=[
        "empty-uuid",
        "uppercase-uuid",
        "zero-uuid",
        "empty-path",
        "uppercase-hex",
        "odd-hex",
        "relative-path",
        "path-too-long",
        "callback-grammar",
    ],
)
def test_malformed_authority_and_callback_are_rejected_before_storage(
    router: RouterHarness, uuid: str, fs_hex: str, callback: str, extras: tuple[str, ...]
) -> None:
    result = invoke_consumer(
        router,
        expected_uuid=uuid,
        expected_hex=fs_hex,
        callback=callback,
        invocation_args=(
            str(router.path("ram/tmp")),
            str(router.path("bin")),
            str(router.path("work/target")),
            str(router.path("work/mountinfo")),
            str(router.path("work/fdinfo")),
            str(router.path("work/block")),
            str(MOUNT_PARSER),
            str(STORAGE_PARSER),
            uuid,
            fs_hex,
            callback,
            *extras,
        ),
    )
    quiet(result, 2)
    assert not router.path("work/storage-called").exists()


def test_missing_api_arguments_are_rejected_before_storage(router: RouterHarness) -> None:
    result = invoke_consumer(
        router,
        invocation_args=(
            str(router.path("ram/tmp")),
            str(router.path("bin")),
            str(router.path("work/target")),
            str(router.path("work/mountinfo")),
        ),
    )
    quiet(result, 2)
    assert not router.path("work/storage-called").exists()


def test_callback_status_is_quiet_and_caller_shell_state_is_preserved(
    router: RouterHarness,
) -> None:
    expected = volume_ledger()
    result = invoke_consumer(
        router,
        callback_body=(
            f'[ "$1" = {shlex.quote(TARGET)} ] && '
            f'[ "$2" = {shlex.quote(expected)} ] || return 88; '
            'printf "secret out\\n"; printf "secret err\\n" >&2; return 7'
        ),
        setup='IFS=x; set -f; umask 027; trap ":" TERM\nbefore=$(trap); options=$(set +o)\n',
        preserve_state=True,
    )
    assert result.returncode == 7 and result.stdout == result.stderr == ""


def test_native_callback_signal_is_quiet_and_preserved(router: RouterHarness) -> None:
    terminate_owner = (
        f"{shlex.quote(sys.executable)} -c "
        f"{shlex.quote('import os,signal; os.kill(os.getppid(), signal.SIGTERM)')}"
        "; return 0"
    )
    quiet(invoke_consumer(router, callback_body=terminate_owner), 143)


def test_storage_unsupported_status_is_preserved_without_consumer_call(
    router: RouterHarness,
) -> None:
    marker = router.path("work/callback-called")
    result = invoke_consumer(
        router,
        callback_body=f": >{shlex.quote(str(marker))}",
        setup="cfmgr_storage_with_test() { return 3; }\n",
    )
    quiet(result, 3)
    assert not marker.exists()


def test_sourcing_modules_defines_functions_without_output_or_shell_changes(
    router: RouterHarness,
) -> None:
    result = router.run(
        f"""IFS=x; set -f; umask 027; trap ':' TERM
before=$(trap); options=$(set +o)
. {shlex.quote(str(IO))}
. {shlex.quote(str(STORAGE))}
. {shlex.quote(str(ENTWARE))}
[ -n "$(command -v cfmgr_entware_with)" ] &&
[ -n "$(command -v cfmgr_entware_with_test)" ] &&
[ "$IFS" = x ] && case $- in *f*) : ;; *) exit 98 ;; esac &&
[ "$(umask)" = 0027 ] && [ "$(trap)" = "$before" ] && [ "$(set +o)" = "$options" ]
""",
        timeout=5,
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""


def run_real_storage(
    fixture: StorageFixture,
    *,
    callback_prefix: str,
    lock_fixture: LockFixture,
    shell: str | None = None,
) -> ShellResult:
    checker = fixture.router.write(
        "work/held-lock-check.py",
        r"""import fcntl
import json
import os
from pathlib import Path
import sys

lock_path, output = map(Path, sys.argv[1:])
held = os.fstat(7)
path = lock_path.stat()
assert (held.st_dev, held.st_ino) == (path.st_dev, path.st_ino)
with lock_path.open("rb") as contender:
    try:
        fcntl.flock(contender.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        contended = True
    else:
        raise AssertionError("FD7 lock was not held at the final storage callback")
output.write_text(json.dumps({"identity": [held.st_dev, held.st_ino], "contended": contended}))
""",
    )
    lock_observation = fixture.router.path("work/held-lock-observation.json")
    dependency_callback = (
        "dependency_storage_callback() {\n"
        f"{shlex.quote(sys.executable)} {shlex.quote(str(checker))} "
        f"{shlex.quote(str(lock_fixture.lock))} {shlex.quote(str(lock_observation))} || return $?\n"
        'fixture_callback "$@"\n}\n'
    )
    storage_args = [
        str(fixture.router.path("ram/tmp")),
        str(fixture.router.path("bin")),
        str(fixture.target),
        str(fixture.router.path("work/mountinfo")),
        str(fixture.settings["fdinfo"]),
        str(fixture.router.path("work/block")),
        str(MOUNT_PARSER),
        str(STORAGE_PARSER),
        UUID,
        fixture.expected().split("\t")[6],
        "dependency_storage_callback",
        "forwarded argument",
    ]
    locked_start = (
        'dependency_start() { cfmgr_entware_with_test "$@"; }\n'
        + lock_fixture.call("dependency_start", *storage_args)
        + "\n"
    )
    fixture.router.write(
        "work/entware-invoke.sh",
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(DEPENDENCY_LOCK))}\n"
        + callback_prefix
        + dependency_callback
        + locked_start,
    )
    script = f'exec {shlex.quote(shell or "/bin/sh")} "$@"\n'
    if fixture.router.busybox:
        script = f'exec {shlex.quote(str(fixture.router.busybox))} sh "$@"\n'
    return fixture.router.run(
        script,
        [str(fixture.router.path("work/entware-invoke.sh"))],
        timeout=45,
        env={
            "_storage_block_fixture": str(fixture.router.path("work/block")),
            "_storage_mode": "with",
            "_storage_callback": "stale_callback",
            "IFS": "x",
        },
    )


def test_real_storage_fixture_calls_consumer_with_retained_descriptors(
    router: RouterHarness,
) -> None:
    fixture = StorageFixture(router)
    lock_fixture = LockFixture(router)
    result = run_real_storage(
        fixture,
        callback_prefix=fixture.callback_prefix(),
        lock_fixture=lock_fixture,
    )
    quiet(result, 0)
    observed = fixture.callback_observation()
    assert observed["args"] == [str(fixture.target), fixture.expected(), "forwarded argument"]
    assert observed["fd8"] and observed["fd9"]
    assert observed["capture_files"] == 48
    lock_check = json.loads(router.path("work/held-lock-observation.json").read_text())
    assert lock_check == {
        "identity": [lock_fixture.lock.stat().st_dev, lock_fixture.lock.stat().st_ino],
        "contended": True,
    }
    assert lock_fixture.records()[0]["identity"] == lock_check["identity"]
    assert lock_fixture.lock.read_bytes() == b""
    fixture.clean()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_entware_admission_runs_under_actual_busybox(busybox_router: RouterHarness) -> None:
    marker = busybox_router.path("work/callback-called")
    result = invoke_consumer(
        busybox_router,
        callback_body=f": >{shlex.quote(str(marker))}",
    )
    quiet(result, 0)
    assert marker.is_file()
