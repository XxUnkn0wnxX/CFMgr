"""Fixed worker composition for the bounded native loader probe."""

from __future__ import annotations

import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "modules/lib"
HELPER = ROOT / "modules/helpers/native_probe.sh"
SOURCES = (
    "io.sh",
    "storage.sh",
    "entware.sh",
    "native_config.sh",
    "isolation.sh",
    "entware_root.sh",
    "native_devices.sh",
    "native_config_root.sh",
    "native_shell.sh",
)
UUID = "12345678-1234-1234-1234-123456789abc"
HEX_TARGET = "2f757372"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def _fixture(router: RouterHarness) -> tuple[str, list[str], Path, Path]:
    ramroot = router.path("ram/native-probe")
    ramroot.mkdir(mode=0o700)
    guard = ramroot / "guard"
    guard.mkdir(mode=0o700)
    mount_parser = router.write("work/mount-parser.awk", "# trusted fixture parser\n")
    storage_parser = router.write("work/storage-parser.awk", "# trusted fixture parser\n")
    log = router.path("work/native-probe.log")
    caller_fd = router.write("work/native-probe-caller", "before\nafter\n")
    source_lines = "\n".join(f". {shlex.quote(str(LIB / name))}" for name in SOURCES)
    source_lines += f"\n. {shlex.quote(str(ROOT / 'modules/helpers/worker.sh'))}"
    source_lines += f"\n. {shlex.quote(str(HELPER))}"
    script = f"""{source_lines}
CFMGR_NATIVE_LOG={shlex.quote(str(log))}
CFMGR_NATIVE_ROOT={shlex.quote(str(ramroot))}
CFMGR_NATIVE_GUARD={shlex.quote(str(guard))}
CFMGR_NATIVE_MOUNT={shlex.quote(str(mount_parser))}
CFMGR_NATIVE_STORAGE={shlex.quote(str(storage_parser))}
CFMGR_NATIVE_UUID={UUID}
CFMGR_NATIVE_HEX={HEX_TARGET}
CFMGR_NATIVE_TARGET={HEX_TARGET}
CFMGR_NATIVE_LEDGER=verified-volume-ledger
CFMGR_NATIVE_ROOT_STATUS=${{CFMGR_TEST_ROOT_STATUS-0}}
CFMGR_NATIVE_STORAGE_STATUS=${{CFMGR_TEST_STORAGE_STATUS-0}}
CFMGR_NATIVE_MASK=${{CFMGR_TEST_MASK-0}}
CFMGR_NATIVE_EARLY=${{CFMGR_TEST_EARLY-0}}
CFMGR_NATIVE_EXIT=${{CFMGR_TEST_EXIT_ENTWARE-0}}
export CFMGR_NATIVE_LOG CFMGR_NATIVE_ROOT CFMGR_NATIVE_GUARD
export CFMGR_NATIVE_MOUNT CFMGR_NATIVE_STORAGE CFMGR_NATIVE_UUID
export CFMGR_NATIVE_HEX CFMGR_NATIVE_TARGET CFMGR_NATIVE_LEDGER
export CFMGR_NATIVE_ROOT_STATUS CFMGR_NATIVE_STORAGE_STATUS CFMGR_NATIVE_MASK
export CFMGR_NATIVE_EARLY CFMGR_NATIVE_EXIT

_native_log() {{ printf '%s\\n' "$1" >>"$CFMGR_NATIVE_LOG"; }}

# This seam models the existing deadline owner: arm before invoking the fixed
# runner, and acknowledge only an ordinary callback completion.
cfmgr_worker_deadline_with() {{
    [ "$#" -eq 14 ] && [ "$1" = "$CFMGR_NATIVE_GUARD" ] &&
        [ "$2:$3:$4" = "10:2:_cfmgr_worker_native_probe_run" ] || return 90
    shift 4
    _native_log armed
    /bin/mkdir -m 700 "$CFMGR_NATIVE_GUARD/deadline" || return 91
    /bin/mkdir -m 700 "$CFMGR_NATIVE_GUARD/deadline/armed" || return 92
    _cfmgr_worker_native_probe_run "$@"
    _native_deadline_status=$?
    if [ "$_native_deadline_status" -le 128 ]; then
        /bin/mkdir -m 700 "$CFMGR_NATIVE_GUARD/deadline/done" || return 93
        /bin/mkdir -m 700 "$CFMGR_NATIVE_GUARD/deadline/ack" || return 94
        _native_log deadline-ack
        return "$_native_deadline_status"
    fi
    return 129
}}

# These narrow consumer seams preserve the exact production callbacks and
# argument routing while replacing expensive storage/root operations.
cfmgr_entware_with() {{
    [ "$#" -eq 12 ] && [ "$1" = "$CFMGR_NATIVE_ROOT" ] &&
        [ "$2" = "$CFMGR_NATIVE_MOUNT" ] && [ "$3" = "$CFMGR_NATIVE_STORAGE" ] &&
        [ "$4" = "$CFMGR_NATIVE_UUID" ] && [ "$5" = "$CFMGR_NATIVE_HEX" ] &&
        [ "$6" = _cfmgr_worker_native_probe_storage ] &&
        [ "$7:$8:$9:${{10}}" = "$CFMGR_NATIVE_ROOT:$CFMGR_NATIVE_GUARD:64:128" ] || return 89
    _native_log storage-acquire
    if [ "$CFMGR_NATIVE_EXIT" = 1 ]; then exit 0; fi
    if [ "$CFMGR_NATIVE_EARLY" = 1 ]; then
        _native_log storage-cleanup
        return 0
    fi
    "$6" "$CFMGR_NATIVE_TARGET" "$CFMGR_NATIVE_LEDGER" "$7" "$8" "$9" "${{10}}" "${{11}}" "${{12}}"
    _native_storage_callback_status=$?
    _native_log storage-cleanup
    if [ "$CFMGR_NATIVE_MASK" = 1 ]; then return 1; fi
    if [ "$CFMGR_NATIVE_STORAGE_STATUS" != 0 ]; then return "$CFMGR_NATIVE_STORAGE_STATUS"; fi
    return "$_native_storage_callback_status"
}}

cfmgr_isolation_native_config_root_with() {{
    [ "$#" -eq 10 ] || {{ _native_log root-bad-count; return 88; }}
    [ "$1" = "$CFMGR_NATIVE_TARGET" ] || {{ _native_log root-bad-1; return 88; }}
    [ "$2" = "$CFMGR_NATIVE_LEDGER" ] || {{ _native_log root-bad-2; return 88; }}
    [ "$3" = "$CFMGR_NATIVE_ROOT" ] || {{ _native_log root-bad-3; return 88; }}
    [ "$4" = "$CFMGR_NATIVE_GUARD" ] || {{ _native_log root-bad-4; return 88; }}
    [ "$5:$6" = 64:128 ] || {{ _native_log root-bad-limits; return 88; }}
    [ "$7" = "$CFMGR_NATIVE_MOUNT" ] || {{ _native_log root-bad-mount-parser; return 88; }}
    [ "$8" = "$CFMGR_NATIVE_STORAGE" ] || {{ _native_log root-bad-storage-parser; return 88; }}
    if [ "$9" = _cfmgr_worker_native_probe_root ] && [ "${{10}}" = "$CFMGR_NATIVE_GUARD" ]; then
        :
    else
        _native_log root-bad-callback
        return 88
    fi
    _native_log root-enter
    "$9" "$CFMGR_NATIVE_ROOT/root" root-ledger "$2" "${{10}}"
    _native_root_callback_status=$?
    _native_log root-cleanup
    if [ "$CFMGR_NATIVE_ROOT_STATUS" != 0 ]; then return "$CFMGR_NATIVE_ROOT_STATUS"; fi
    return "$_native_root_callback_status"
}}

cfmgr_native_shell_probe() {{
    [ "$#" -eq 1 ] && [ "$1" = "$CFMGR_NATIVE_ROOT/root" ] || return 87
    _native_log probe
    return "${{CFMGR_TEST_PROBE_STATUS-0}}"
}}

_cfmgr_worker_native_probe_mkdir() {{ printf '%s\\n' /bin/mkdir; }}

# Observe the public result boundary after caller PATH/loader poisoning. The
# predicate still checks the actual marker directory for emptiness.
_cfmgr_isolation_root_empty() (
    [ "$PATH" = /sbin:/bin:/usr/sbin:/usr/bin ] && [ -z "${{LD_LIBRARY_PATH-}}" ] || return 96
    [ -d "$1" ] && [ ! -L "$1" ] || return 1
    set +f
    for _native_empty_entry in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [ -e "$_native_empty_entry" ] || [ -L "$_native_empty_entry" ] || continue
        return 1
    done
)
"""
    args = [
        str(ramroot),
        str(guard),
        "10",
        "2",
        "64",
        "128",
        str(mount_parser),
        str(storage_parser),
        UUID,
        HEX_TARGET,
    ]
    return script, args, log, caller_fd


def _run(
    router: RouterHarness,
    *,
    env: dict[str, str] | None = None,
    setup: str = "",
    call: str | None = None,
    args: list[str] | None = None,
):
    script, default_args, log, caller_fd = _fixture(router)
    script += setup
    if call is None:
        call = 'cfmgr_worker_native_probe "$@"; status=$?\nprintf "RESULT\\t%s\\n" "$status"\n'
    result = router.run(script + call, default_args if args is None else args, env=env, timeout=3)
    return result, log, caller_fd, Path(default_args[1])


def test_clean_probe_outcomes_route_exact_authority_and_ack_after_cleanup(
    router: RouterHarness,
) -> None:
    result, log, caller_fd, guard = _run(
        router,
        env={"CFMGR_TEST_PROBE_STATUS": "0"},
        setup=(
            "IFS=caller-ifs; PATH=/caller/path; LD_LIBRARY_PATH=/caller/loader\n"
            "set -f; umask 027; trap ':' TERM\n"
            "exec 6<" + shlex.quote(str(router.path("work/native-probe-caller"))) + "\n"
            "IFS= read -r _native_fd_before <&6\n"
        ),
        call=(
            'cfmgr_worker_native_probe "$@"; status=$?\n'
            "IFS= read -r _native_fd_after <&6\n"
            "case $- in *f*) : ;; *) exit 71 ;; esac\n"
            '[ "$(umask)" = 0027 ] && [ "$IFS" = caller-ifs ] &&\n'
            '[ "$PATH" = /caller/path ] && [ "$LD_LIBRARY_PATH" = /caller/loader ] &&\n'
            '[ "$_native_fd_before:$_native_fd_after" = before:after ] || exit 72\n'
            'printf "RESULT\\t%s\\n" "$status"\n'
        ),
    )
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\n" and result.stderr == "", (
        result,
        log.read_text(encoding="utf-8") if log.exists() else "no order witness",
    )
    assert log.read_text(encoding="utf-8").splitlines() == [
        "armed",
        "storage-acquire",
        "root-enter",
        "probe",
        "root-cleanup",
        "storage-cleanup",
        "deadline-ack",
    ]
    assert (guard / "probe-success").is_dir() and not (guard / "probe-negative").exists()
    assert (guard / "root-returned").is_dir()
    assert (guard / "deadline/armed").is_dir() and (guard / "deadline/ack").is_dir()


@pytest.mark.parametrize(("probe_status", "expected"), [(1, 1), (2, 129), (129, 129)])
def test_probe_status_requires_exact_ordinary_result_and_checked_cleanup(
    router: RouterHarness, probe_status: int, expected: int
) -> None:
    result, log, _, guard = _run(router, env={"CFMGR_TEST_PROBE_STATUS": str(probe_status)})
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{expected}\n" and result.stderr == ""
    assert (guard / "root-returned").exists() is (probe_status == 1)
    assert (guard / "deadline/ack").exists() is (probe_status == 1)
    if probe_status == 1:
        assert (guard / "probe-negative").is_dir()
        assert log.read_text(encoding="utf-8").splitlines()[-1] == "deadline-ack"
    else:
        assert not (guard / "deadline/ack").exists()


@pytest.mark.parametrize(
    ("env", "expected", "witness"),
    [
        ({"CFMGR_TEST_ROOT_STATUS": "1"}, 129, "root-cleanup"),
        ({"CFMGR_TEST_ROOT_STATUS": "2"}, 129, "root-cleanup"),
        ({"CFMGR_TEST_ROOT_STATUS": "129"}, 129, "root-cleanup"),
        ({"CFMGR_TEST_STORAGE_STATUS": "1"}, 129, "storage-cleanup"),
        ({"CFMGR_TEST_ROOT_STATUS": "129", "CFMGR_TEST_MASK": "1"}, 129, "storage-cleanup"),
        ({"CFMGR_TEST_EARLY": "1"}, 129, "storage-cleanup"),
        ({"CFMGR_TEST_EXIT_ENTWARE": "1"}, 129, "storage-acquire"),
    ],
    ids=[
        "root-one",
        "root-two",
        "root-129",
        "outer-storage-one",
        "masked-uncertainty",
        "premature-zero",
        "early-exit-zero",
    ],
)
def test_enclosing_uncertainty_never_acknowledges(
    router: RouterHarness, env: dict[str, str], expected: int, witness: str
) -> None:
    result, log, _, guard = _run(router, env=env)
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{expected}\n" and result.stderr == ""
    lines = log.read_text(encoding="utf-8").splitlines()
    assert witness in lines and "deadline-ack" not in lines
    assert not (guard / "deadline/ack").exists()
    if env.get("CFMGR_TEST_EARLY") == "1":
        assert len(lines) == 3 and lines[:2] == ["armed", "storage-acquire"]
        assert not (guard / "root-returned").exists()
    if env.get("CFMGR_TEST_EXIT_ENTWARE") == "1":
        assert lines == ["armed", "storage-acquire"]
        assert not (guard / "deadline/done").exists()
        assert not (guard / "root-returned").exists()


@pytest.mark.parametrize(
    "marker", ["deadline", "execution", "probe-success", "probe-negative", "root-returned"]
)
@pytest.mark.parametrize("dangling", [False, True], ids=["existing", "dangling"])
def test_stale_evidence_refuses_before_deadline_or_effects(
    router: RouterHarness, marker: str, dangling: bool
) -> None:
    script, args, log, _ = _fixture(router)
    path = Path(args[1]) / marker
    if dangling:
        path.symlink_to(router.path("work/missing-target"))
    else:
        path.mkdir()
    result = router.run(
        script + 'cfmgr_worker_native_probe "$@"; printf "RESULT\\t%s\\n" "$?"\n',
        args,
        timeout=3,
    )
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t129\n" and result.stderr == ""
    assert not log.exists()
    assert not (Path(args[1]) / "deadline/ack").exists()


@pytest.mark.parametrize(
    "mutation",
    ["argument-count", "guard-owner", "zero-uuid", "traversal-target", "bad-deadline"],
)
def test_malformed_api_returns_two_without_effects(router: RouterHarness, mutation: str) -> None:
    script, args, log, _ = _fixture(router)
    if mutation == "argument-count":
        args = args[:-1]
    elif mutation == "guard-owner":
        args[1] = args[0]
    elif mutation == "zero-uuid":
        args[8] = "00000000-0000-0000-0000-000000000000"
    elif mutation == "traversal-target":
        args[9] = "2f2e2e"
    else:
        args[2] = "3"
    result = router.run(
        script + 'cfmgr_worker_native_probe "$@"; printf "RESULT\\t%s\\n" "$?"\n',
        args,
        timeout=3,
    )
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t2\n" and result.stderr == ""
    assert not log.exists()


@pytest.mark.parametrize(
    ("publish_mode", "expected"),
    [
        ("fail-success", 129),
        ("omit-success", 129),
        ("conflict-success", 129),
        ("fail-root", 129),
        ("omit-root", 129),
        ("nonempty-root", 129),
    ],
)
def test_missing_conflicting_nonempty_or_failed_publication_is_uncertain(
    router: RouterHarness, publish_mode: str, expected: int
) -> None:
    script, args, log, _ = _fixture(router)
    wrapper = router.write(
        "bin/native-probe-mkdir",
        "#!/bin/sh\n"
        '[ "$1" = -m ] && target=$3 || exit 97\n'
        "name=${target##*/}\n"
        "case $CFMGR_TEST_PUBLISH:$name in\n"
        "fail-success:probe-success) exit 1 ;;\n"
        "omit-success:probe-success) exit 0 ;;\n"
        "fail-root:root-returned) exit 1 ;;\n"
        "omit-root:root-returned) exit 0 ;;\n"
        'conflict-success:probe-success) /bin/mkdir -m 700 "$target" || exit; '
        '/bin/mkdir -m 700 "${target%/*}/probe-negative"; exit 0 ;;\n'
        'nonempty-root:root-returned) /bin/mkdir -m 700 "$target" || exit; '
        ': >"$target/unexpected"; exit 0 ;;\n'
        "esac\n"
        'exec /bin/mkdir "$@"\n',
        executable=True,
    )
    script = script.replace(
        "_cfmgr_worker_native_probe_mkdir() { printf '%s\\n' /bin/mkdir; }",
        f"_cfmgr_worker_native_probe_mkdir() {{ printf '%s\\n' {shlex.quote(str(wrapper))}; }}",
    )
    result = router.run(
        script + 'cfmgr_worker_native_probe "$@"; printf "RESULT\\t%s\\n" "$?"\n',
        args,
        env={"CFMGR_TEST_PUBLISH": publish_mode},
        timeout=3,
    )
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{expected}\n" and result.stderr == ""
    assert "deadline-ack" not in log.read_text(encoding="utf-8").splitlines()
    assert not (Path(args[1]) / "deadline/ack").exists()
