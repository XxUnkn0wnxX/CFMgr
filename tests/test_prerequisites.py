"""Fixed real-tool probes; Linux ownership is a separate required platform proof."""

from __future__ import annotations

import os
import shlex
import shutil
import signal
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "modules/lib/execution.sh"
PROBE = ROOT / "modules/helpers/worker.sh"
REQUIRE_BUSYBOX = os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1"
DIGEST = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"


@pytest.fixture(scope="module")
def shell() -> list[str]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    command = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert command and shutil.which(command[0]), "Selected POSIX test shell is missing"
    if REQUIRE_BUSYBOX:
        assert Path(command[0]).name == "busybox" and command[1:] == ["ash"]
        assert sys.platform == "linux", "Required ownership proof needs Linux proc"
    return command


@pytest.fixture(scope="module")
def tools() -> dict[str, str]:
    names = {"jq": "jq", "timeout": "timeout", "sha": "sha256sum"}
    result = {}
    for key, name in names.items():
        resolved = shutil.which(name)
        assert resolved, f"Actual {name} prerequisite is missing"
        result[key] = resolved
    for name in ("env", "awk", "sleep", "wc", "flock"):
        result[name] = shutil.which(name) or "-"
    return result


@pytest.fixture
def context(tmp_path: Path) -> Path:
    private = tmp_path / "private probe context"
    private.mkdir(mode=0o700)
    (private / "json.good").write_text('{"answer":[1,2],"ok":true}\n')
    (private / "json.bad").write_text("{broken\n")
    (private / "bytes").write_bytes(b"abc")
    (private / "checksum.good").write_text(f"{DIGEST}  bytes\n")
    (private / "checksum.bad").write_text(f"aa{DIGEST[2:]}  bytes\n")
    return private


def pause_definition(shell: list[str]) -> str:
    """Private host adapter; mandatory CI executes the real selected vendor applet."""
    if REQUIRE_BUSYBOX:
        executable = shutil.which(shell[0])
        assert executable, "Required vendor BusyBox executable is missing"
        command = f"{shlex.quote(executable)} usleep 50000"
    else:
        executable = shutil.which("sleep")
        assert executable, "Actual host sleep adapter is missing"
        command = f"{shlex.quote(executable)} 0.05"
    return f"cfmgr_prerequisites_pause() {{ {command}; }}; "


def invoke(
    shell: list[str], script: str, *arguments: str | Path, pause: bool = False
) -> subprocess.CompletedProcess[bytes]:
    if pause:
        script = script.replace('. "$1";', '. "$1"; ' + pause_definition(shell), 1)
    return subprocess.run(
        [*shell, "-c", script, "prerequisite-test", str(LIBRARY), *map(str, arguments)],
        env={**os.environ, "LC_ALL": "POSIX", "LANGUAGE": "foreign-language"},
        check=False,
        capture_output=True,
        timeout=6,
    )


def probe(
    shell: list[str], mode: str, tool: str, context: Path, *extra: str | Path
) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [*shell, str(PROBE), mode, tool, str(context), *map(str, extra)],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=3,
    )


def test_library_source_is_inert_and_preserves_caller(
    shell: list[str], tmp_path: Path
) -> None:
    result = invoke(
        shell,
        'cd "$2"; before=$PWD; . "$1"; [ "$PWD" = "$before" ] && [ "$LC_ALL" = POSIX ] && [ "$LANGUAGE" = foreign-language ]',
        tmp_path,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_pause_uses_actual_vendor_microseconds_or_labelled_host_adapter(
    shell: list[str],
) -> None:
    result = invoke(
        shell, '. "$1"; ' + pause_definition(shell) + "cfmgr_prerequisites_pause"
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    if REQUIRE_BUSYBOX:
        rejected = subprocess.run(
            [shell[0], "sleep", "0.05"], capture_output=True, check=False, timeout=2
        )
        assert rejected.returncode != 0, (
            "Required firmware fixture must reject float sleep"
        )


def test_jq_parses_values_and_rejects_malformed_input(
    shell: list[str], tools: dict[str, str], context: Path
) -> None:
    good = probe(shell, "jq-good", tools["jq"], context)
    bad = probe(shell, "jq-bad", tools["jq"], context)
    assert (good.returncode, good.stdout, good.stderr) == (0, b"true\n", b"")
    assert bad.returncode != 0 and bad.stdout == b"" and bad.stderr


def test_text_result_rejects_extra_and_unterminated_bytes(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    contents = [
        b"true\n",
        b"true\nextra\n",
        b"true\ntrailing",
        b"true",
        b"true\x00\n",
        b"true\n\x00",
    ]
    files = []
    for index, content in enumerate(contents):
        path = tmp_path / str(index)
        path.write_bytes(content)
        count = subprocess.run(
            [tools["wc"], "-c"],
            input=content,
            capture_output=True,
            check=True,
            timeout=2,
        )
        count_path = tmp_path / f"{index}.count"
        count_path.write_bytes(count.stdout)
        files.extend([path, count_path])
    result = invoke(
        shell,
        'set -e; . "$1"; shift; while [ "$#" -gt 0 ]; do '
        'if cfmgr_prerequisites_text "$1" true "$2"; then printf "yes\\n"; '
        'else printf "no\\n"; fi; shift 2; done',
        *files,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"yes\nno\nno\nno\nno\nno\n",
        b"",
    )


def test_sha_known_bytes_and_corrupt_verification(
    shell: list[str], tools: dict[str, str], context: Path
) -> None:
    digest = probe(shell, "sha-bytes", tools["sha"], context)
    good = probe(shell, "sha-good", tools["sha"], context)
    bad = probe(shell, "sha-bad", tools["sha"], context)
    assert (digest.returncode, digest.stdout, digest.stderr) == (
        0,
        f"{DIGEST}  bytes\n".encode(),
        b"",
    )
    assert (good.returncode, good.stdout, good.stderr) == (0, b"", b"")
    assert (bad.returncode, bad.stdout, bad.stderr) == (1, b"", b"")


def test_timeout_propagates_exit_and_expires_finite_child(
    shell: list[str], tools: dict[str, str], context: Path
) -> None:
    # GNU timeout starts its fixed script using the shell executable; BusyBox ash
    # needs the explicit `ash` argument and is covered through the production API.
    executable = "/bin/sh" if REQUIRE_BUSYBOX else shell[0]
    propagated = probe(
        shell, "timeout-exit", tools["timeout"], context, executable, PROBE
    )
    expired = probe(
        shell,
        "timeout-expiry",
        tools["timeout"],
        context,
        executable,
        PROBE,
        tools["sleep"],
    )
    assert (propagated.returncode, propagated.stdout, propagated.stderr) == (
        7,
        b"",
        b"",
    )
    assert (expired.returncode, expired.stdout, expired.stderr) == (124, b"", b"")


@pytest.mark.parametrize("mode", ["arbitrary", "blkid"])
def test_fixed_probe_rejects_commands_and_non_block_operands(
    shell: list[str], context: Path, mode: str
) -> None:
    result = probe(shell, mode, "/bin/sh", context, context / "bytes")
    assert (result.returncode, result.stdout, result.stderr) == (2, b"", b"")
    assert (context / "bytes").read_bytes() == b"abc"


def test_install_remove_only_accepts_one_regular_completion_guard(
    shell: list[str], context: Path
) -> None:
    unrelated = context / "bytes"
    guard = context / ".setup.complete"
    guard.symlink_to(unrelated)
    for operands in ((unrelated,), (guard,), (guard, unrelated)):
        rejected = probe(shell, "install-remove", "/bin/rm", context, *operands)
        assert rejected.returncode != 0
        assert unrelated.read_bytes() == b"abc"
        assert guard.is_symlink()
    guard.unlink()
    guard.write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    removed = probe(shell, "install-remove", "/bin/rm", context, guard)
    assert (removed.returncode, removed.stdout, removed.stderr) == (0, b"", b"")
    assert not guard.exists()
    assert unrelated.read_bytes() == b"abc"


def test_invalid_scope_and_dns_evidence_fail_before_files(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    arguments = [
        tmp_path,
        shell[0],
        PROBE,
        tools["env"],
        tools["awk"],
        tools["sleep"],
        tools["wc"],
        "-",
        tools["jq"],
        tools["timeout"],
        tools["sha"],
        "-",
        "-",
    ]
    result = invoke(
        shell,
        '. "$1"; shift; cfmgr_prerequisites_check bogus "$@" unknown; first=$?; cfmgr_prerequisites_check shared "$@" guessed; second=$?; [ "$first" = 2 ] && [ "$second" = 2 ]',
        *arguments,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_native_supervisor_is_explicitly_unavailable_without_proc(
    shell: list[str], tools: dict[str, str], context: Path
) -> None:
    if sys.platform == "linux":
        pytest.skip("This boundary specifically proves the workstation without proc")
    result = invoke(
        shell,
        '. "$1"; cfmgr_prerequisites_attachment_ok() { exit 99; }; cfmgr_prerequisites_run jq-good "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"; rc=$?; [ "$rc" = 2 ] && [ "$cfmgr_probe_reason" = native-supervisor ]',
        context,
        shell[0],
        PROBE,
        tools["env"],
        tools["awk"],
        tools["sleep"],
        tools["wc"],
        tools["jq"],
    )
    assert result.returncode == 0
    assert not (context / "jq-good.out").exists()


@pytest.mark.parametrize(
    "native_usable", [True, False], ids=["native-first", "entware-fallback"]
)
def test_linux_supervisor_and_real_flock_capabilities(
    shell: list[str], tools: dict[str, str], tmp_path: Path, native_usable: bool
) -> None:
    if sys.platform != "linux":
        pytest.skip(
            "Linux proc identity, owned descendants and real flock require Linux"
        )
    assert tools["flock"] != "-", "Required real flock is unavailable"
    # /bin/sh is the router-facing executable contract, independently of the
    # test harness shell. Required vendor BusyBox CI must select its /bin/sh.
    executable = "/bin/sh" if REQUIRE_BUSYBOX else shell[0]
    result = invoke(
        shell,
        '. "$1"; shift; cfmgr_prerequisites_attachment_ok() { return 0; }; cfmgr_prerequisites_admit_tool() { [ "$1" != /fixture/unsafe ] || return 2; [ -f "$1" ] && [ -x "$1" ]; }; cfmgr_prerequisites_check shared "$@" /fixture/unsafe unknown || exit $?; printf "%s\\n" "$cfmgr_prereq_flock_provider"; [ "$cfmgr_prereq_result" = capabilities-checked ] && [ -z "$cfmgr_prereq_missing" ] && [ "$cfmgr_prereq_dns" = not-required ] && ! (: <&4) 2>/dev/null && ! (: <&5) 2>/dev/null',
        tmp_path,
        executable,
        PROBE,
        tools["env"],
        tools["awk"],
        tools["sleep"],
        tools["wc"],
        tools["flock"] if native_usable else "/bin/false",
        tools["jq"],
        tools["timeout"],
        tools["sha"],
        "/fixture/unsafe" if native_usable else tools["flock"],
        pause=True,
    )
    provider = b"native\n" if native_usable else b"entware\n"
    assert (result.returncode, result.stdout, result.stderr) == (0, provider, b"")
    assert (tmp_path / "flock-entware-first.out").exists() is (not native_usable)


def test_linux_supervisor_bounds_output_and_denies_detached_launch(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    if sys.platform != "linux":
        pytest.skip("The native file limit and owned-child supervisor require Linux")
    noisy = tmp_path / "admitted unusable jq"
    noisy.write_text(
        "#!/bin/sh\ni=0\nwhile [ \"$i\" -lt 1000 ]; do printf '%080d\\n' 0; i=$((i+1)); done\n"
    )
    noisy.chmod(0o700)
    attached = tmp_path / "attached"
    detached = tmp_path / "detached"
    attached.mkdir(mode=0o700)
    detached.mkdir(mode=0o700)
    executable = "/bin/sh" if REQUIRE_BUSYBOX else shell[0]
    result = invoke(
        shell,
        '. "$1"; cfmgr_prerequisites_attachment_ok() { return 0; }; '
        'cfmgr_prerequisites_run jq-good "$2" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" || exit $?; '
        '[ "$cfmgr_probe_status" = reaped ] && [ "$cfmgr_probe_exit" -ne 0 ] || exit 91; '
        "cfmgr_prerequisites_attachment_ok() { return 1; }; "
        'cfmgr_prerequisites_run jq-good "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"; '
        '[ "$?" = 1 ] && [ -z "$cfmgr_probe_pid" ]',
        attached,
        detached,
        executable,
        PROBE,
        tools["env"],
        tools["awk"],
        tools["sleep"],
        tools["wc"],
        noisy,
        pause=True,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert 0 < (attached / "jq-good.out").stat().st_size <= 8192
    assert (attached / "jq-good.err").stat().st_size <= 8192
    assert list(detached.iterdir()) == []


@pytest.mark.parametrize(
    ("scenario", "expected"),
    [
        (
            "vanished-read",
            "code=0 status=reaped exit=0 signaled=no exists=no",
        ),
        (
            "visible-read-failure",
            "code=3 status=unresolved exit=unset signaled=no exists=yes",
        ),
        (
            "visible-mismatch",
            "code=3 status=unresolved exit=unset signaled=no exists=yes",
        ),
        (
            "vanished-mismatch",
            "code=3 status=unresolved exit=unset signaled=no exists=no",
        ),
        (
            "vanished-invalid-record",
            "code=3 status=unresolved exit=unset signaled=no exists=no",
        ),
    ],
)
def test_linux_supervisor_distinguishes_reaped_child_from_unknown_identity(
    shell: list[str],
    tools: dict[str, str],
    tmp_path: Path,
    scenario: str,
    expected: str,
) -> None:
    if sys.platform != "linux":
        pytest.skip("direct-child proc disappearance and exact wait require Linux")

    source = LIBRARY.read_text()
    identity_definition = "cfmgr_prerequisites_identity() {"
    test_identity_definition = "cfmgr_test_real_identity() {"
    assert source.count(identity_definition) == 1
    instrumented = source.replace(identity_definition, test_identity_definition, 1)
    assert (
        instrumented.replace(test_identity_definition, identity_definition, 1) == source
    )
    library = tmp_path / "prerequisites-identity-hook.sh"
    library.write_text(instrumented)

    context = tmp_path / "identity observation context"
    context.mkdir(mode=0o700)
    (context / "json.good").write_text('{"answer":[1,2],"ok":true}\n')
    os.mkfifo(context / "release")
    tool = tmp_path / "blocking jq adapter"
    tool.write_text(
        "#!/bin/sh\n"
        f"context={shlex.quote(str(context))}\n"
        ': >"$context/child-started"\n'
        "trap ': >\"$context/child-signaled\"' TERM\n"
        'IFS= read -r release <"$context/release" || exit 91\n'
        "printf 'true\\n'\n"
    )
    tool.chmod(0o700)

    script = (
        '. "$1"; '
        + pause_definition(shell)
        + r"""
context=$2 scenario=$3
cfmgr_test_identity_reads=0
cfmgr_prerequisites_attachment_ok() { return 0; }
cfmgr_prerequisites_admit_tool() { [ -f "$1" ] && [ -x "$1" ]; }
cfmgr_test_wait_marker() {
    cfmgr_test_wait_count=0
    while [ ! -e "$context/child-started" ]; do
        [ "$cfmgr_test_wait_count" -lt 40 ] || return 1
        cfmgr_prerequisites_pause || return 1
        cfmgr_test_wait_count=$((cfmgr_test_wait_count + 1))
    done
}
cfmgr_test_release_child() { printf 'release\n' >"$context/release"; }
cfmgr_test_wait_absent() {
    cfmgr_test_wait_count=0
    while [ -e "/proc/$1" ] || [ -L "/proc/$1" ]; do
        [ "$cfmgr_test_wait_count" -lt 40 ] || return 1
        cfmgr_prerequisites_pause || return 1
        cfmgr_test_wait_count=$((cfmgr_test_wait_count + 1))
    done
}
cfmgr_prerequisites_identity() {
    if [ "$1" = "${cfmgr_probe_pid:-}" ]; then
        cfmgr_test_identity_reads=$((cfmgr_test_identity_reads + 1))
        if [ "$cfmgr_test_identity_reads" -eq 2 ]; then
            case $scenario in
                vanished-read)
                    cfmgr_test_wait_marker && cfmgr_test_release_child &&
                        cfmgr_test_wait_absent "$1" || return 1
                    cfmgr_test_real_identity "$@"
                    return $?
                    ;;
                visible-read-failure)
                    cfmgr_test_wait_marker || return 1
                    cfmgr_identity_read=0
                    return 1
                    ;;
                visible-mismatch | vanished-mismatch | vanished-invalid-record)
                    cfmgr_test_real_identity "$@" || return 1
                    cfmgr_test_wait_marker || return 1
                    case $scenario in
                        visible-mismatch | vanished-mismatch)
                            cfmgr_identity_start=$((cfmgr_identity_start + 1))
                            ;;
                        vanished-invalid-record)
                            cfmgr_identity_line=malformed-pid-header
                            cfmgr_identity_read=1
                            ;;
                    esac
                    if [ "$scenario" = vanished-mismatch ] || [ "$scenario" = vanished-invalid-record ]; then
                        cfmgr_test_release_child && cfmgr_test_wait_absent "$1" || return 1
                    fi
                    [ "$scenario" != vanished-invalid-record ] || return 1
                    return 0
                    ;;
            esac
        fi
    fi
    cfmgr_test_real_identity "$@"
}
if cfmgr_prerequisites_run jq-good "$context" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"; then
    cfmgr_test_code=0
else
    cfmgr_test_code=$?
fi
cfmgr_test_probe_pid=${cfmgr_probe_pid:-}
if [ -e "/proc/$cfmgr_test_probe_pid" ]; then exists_at_return=yes; else exists_at_return=no; fi
if [ -n "$cfmgr_test_probe_pid" ] &&
    [ ! -e "$context/child-signaled" ] && [ "$scenario" != vanished-read ] &&
    [ "$scenario" != vanished-mismatch ] && [ "$scenario" != vanished-invalid-record ]; then
    cfmgr_test_release_child || exit 92
fi
if [ -n "$cfmgr_test_probe_pid" ]; then wait "$cfmgr_test_probe_pid" 2>/dev/null || :; fi
if [ -e "$context/child-signaled" ]; then signaled=yes; else signaled=no; fi
printf 'code=%s status=%s exit=%s signaled=%s exists=%s\n' \
    "$cfmgr_test_code" "${cfmgr_probe_status:-unset}" "${cfmgr_probe_exit:-unset}" "$signaled" "$exists_at_return"
"""
    )
    executable = "/bin/sh" if REQUIRE_BUSYBOX else shell[0]
    process = subprocess.Popen(
        [
            *shell,
            "-c",
            script,
            "prerequisite-identity-race",
            str(library),
            str(context),
            scenario,
            executable,
            str(PROBE),
            tools["env"],
            tools["awk"],
            tools["sleep"],
            tools["wc"],
            str(tool),
        ],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        try:
            stdout, stderr = process.communicate(timeout=8)
        except subprocess.TimeoutExpired as error:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                stdout, stderr = process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                stdout = error.stdout or b""
                stderr = error.stderr or b""
            raise AssertionError(
                "identity race fixture exceeded its bound; "
                f"stdout={stdout[-2048:]!r} stderr={stderr[-2048:]!r}"
            ) from error
    finally:
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                process.communicate(timeout=2)
            except subprocess.TimeoutExpired:
                pass
    assert process.returncode == 0, stderr.decode(errors="replace")
    assert stdout.decode().strip() == expected


# This private workstation adapter proves inventory/control flow with actual fixed
# jq/timeout/sha probes. Flock outcomes are finite fixtures; Linux tests above
# retain real lock, process identity, ownership and bounded supervision proof.
HOST_INVENTORY = r"""
. "$1"
shift
cfmgr_test_context=$2
cfmgr_test_admitted=''
cfmgr_test_probed=''
cfmgr_prerequisites_attachment_ok() { [ "$cfmgr_test_fault" != detached ]; }
cfmgr_prerequisites_supervisor() { [ "$cfmgr_test_fault" != no-supervisor ] || return 2; }
cfmgr_prerequisites_admit_tool() {
    cfmgr_test_admitted="${cfmgr_test_admitted:+$cfmgr_test_admitted }$1"
    [ "$1" != /fixture/unsafe ] || return 2
    [ -f "$1" ] && [ -x "$1" ]
}
cfmgr_prerequisites_run() {
    cfmgr_test_probed="${cfmgr_test_probed:+$cfmgr_test_probed }$1"
    cfmgr_probe_reason=''
    cfmgr_probe_status=reaped
    cfmgr_probe_pid=''
    if [ "$cfmgr_test_fault:$1" = ownership-flock:flock-first ]; then
        cfmgr_probe_status=unresolved; cfmgr_probe_pid=123; return 3
    fi
    if [ "$1" = jq-good ]; then
        case "$cfmgr_test_fault" in
            ownership) cfmgr_probe_status=unresolved; cfmgr_probe_pid=123; return 3 ;;
            attachment) cfmgr_probe_reason=attachment; return 1 ;;
            unsupported) cfmgr_probe_reason=native-supervisor; return 2 ;;
        esac
    fi
    cfmgr_probe_stdout=$2/$1.out
    cfmgr_probe_stderr=$2/$1.err
    (umask 077; set -C; : > "$cfmgr_probe_stdout" && : > "$cfmgr_probe_stderr") || return 2
    case "$1" in
        flock-*)
            case "$1:$9" in
                flock-first:*/false) cfmgr_probe_exit=1 ;;
                flock-compete:*|flock-entware-compete:*) cfmgr_probe_exit=1 ;;
                *) cfmgr_probe_exit=0 ;;
            esac
            ;;
        *)
            cfmgr_test_mode=$1 cfmgr_test_context=$2 cfmgr_test_sh=$3
            cfmgr_test_probe=$4 cfmgr_test_env=$5 cfmgr_test_sleep=$7 cfmgr_test_tool=$9
            case "$cfmgr_test_mode" in
                timeout-exit) set -- "$cfmgr_test_sh" "$cfmgr_test_probe" ;;
                timeout-expiry) set -- "$cfmgr_test_sh" "$cfmgr_test_probe" "$cfmgr_test_sleep" ;;
                *) set -- ;;
            esac
            "$cfmgr_test_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
                "$cfmgr_test_sh" "$cfmgr_test_probe" "$cfmgr_test_mode" "$cfmgr_test_tool" "$cfmgr_test_context" "$@" \
                > "$cfmgr_probe_stdout" 2> "$cfmgr_probe_stderr"
            cfmgr_probe_exit=$?
            ;;
    esac
    return 0
}
cfmgr_prerequisites_check "$@"
cfmgr_test_code=$?
printf '%s\n' "$cfmgr_test_code" "$cfmgr_prereq_missing" "$cfmgr_prereq_flock_provider" \
    "$cfmgr_prereq_dns" "$cfmgr_test_admitted" "$cfmgr_test_probed"
[ "$cfmgr_test_code" != 3 ] || [ "$cfmgr_probe_status" = unresolved ] || exit 94
! (: <&4) 2>/dev/null && ! (: <&5) 2>/dev/null || exit 95
"""


def inventory(
    shell: list[str],
    tools: dict[str, str],
    context: Path,
    *,
    scope: str = "shared",
    native: str = "/usr/bin/true",
    fallback: str = "/fixture/unsafe",
    jq: str | None = None,
    timeout: str | None = None,
    sha: str | None = None,
    dig: str = "/fixture/unsafe",
    fault: str = "clean",
    recheck: bool = False,
) -> list[str]:
    # The shell executable is resolved, just as the real installer fixtures do.
    executable = "/bin/sh" if REQUIRE_BUSYBOX else shell[0]
    result = invoke(
        shell,
        f"cfmgr_test_fault={shlex.quote(fault)}; " + HOST_INVENTORY,
        scope,
        context,
        executable,
        PROBE,
        tools["env"],
        tools["awk"],
        tools["sleep"],
        tools["wc"],
        native,
        tools["jq"] if jq is None else jq,
        tools["timeout"] if timeout is None else timeout,
        tools["sha"] if sha is None else sha,
        fallback,
        dig,
        "unknown",
    )
    assert result.returncode == 0
    if recheck:
        # Bash, dash and ash phrase noclobber differently. The result and exact
        # preserved bytes below prove refusal; diagnostics must identify its file.
        assert os.fsencode(context / "json.good") in result.stderr
    else:
        assert result.stderr == b""
    return result.stdout.decode().splitlines()


def test_inventory_healthy_native_ignores_unsafe_optional_flock_and_dns(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    result = inventory(shell, tools, tmp_path)
    assert result[:4] == ["0", "", "native", "not-required"]
    assert result[4].split() == [tools["jq"], tools["timeout"], tools["sha"]]
    assert "flock-entware-first" not in result[5] and "dig-version" not in result[5]


def test_inventory_collects_missing_abi_and_incorrect_behavior_together(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    abi_failure = tmp_path / "unusable ABI jq"
    abi_failure.write_text("#!/missing/loader\n")
    abi_failure.chmod(0o700)
    result = inventory(
        shell,
        tools,
        tmp_path,
        native="-",
        fallback="-",
        jq=str(abi_failure),
        timeout="-",
        sha="/usr/bin/true",
    )
    assert result[:4] == [
        "1",
        "jq coreutils-timeout coreutils-sha256sum flock",
        "none",
        "not-required",
    ]
    assert result[5].split() == ["jq-good", "sha-bytes", "wc-sha"]


def test_inventory_native_failure_admits_fallback_only_when_needed(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    result = inventory(
        shell, tools, tmp_path, native="/usr/bin/false", fallback="/usr/bin/true"
    )
    assert result[:4] == ["0", "", "entware", "not-required"]
    assert result[4].split()[-1] == "/usr/bin/true"
    assert result[5].split()[-5:] == [
        "flock-entware-first",
        "flock-entware-compete",
        "flock-entware-release",
        "flock-entware-after",
        "flock-entware-finish",
    ]


@pytest.mark.parametrize(
    ("fault", "code"),
    [("attachment", "2"), ("ownership", "3"), ("unsupported", "2")],
)
def test_inventory_fatal_probe_stops_before_later_capabilities(
    shell: list[str], tools: dict[str, str], tmp_path: Path, fault: str, code: str
) -> None:
    result = inventory(shell, tools, tmp_path, fault=fault)
    assert result[:4] == [code, "", "none", "not-required"]
    assert result[4].split() == [tools["jq"]]
    assert result[5].split() == ["jq-good"]


def test_inventory_fatal_admission_and_attachment_do_not_become_missing(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    unsafe = tmp_path / "unsafe"
    detached = tmp_path / "detached"
    unsafe.mkdir()
    detached.mkdir()
    result = inventory(shell, tools, unsafe, jq="/fixture/unsafe")
    assert result == ["2", "", "none", "not-required", "/fixture/unsafe", ""]
    result = inventory(shell, tools, detached, fault="detached")
    assert result == ["2", "", "none", "not-required", "", ""]
    assert list(detached.iterdir()) == []


def test_inventory_tunnel_alone_reports_missing_dig_and_preserves_recheck_evidence(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    result = inventory(shell, tools, tmp_path, scope="tunnel", dig="-")
    assert result[:4] == ["1", "bind-dig", "native", "unusable"]
    evidence = {entry.name: entry.read_bytes() for entry in tmp_path.iterdir()}
    # A recheck requires a fresh context. Reusing one fails before replacing any
    # capability evidence and does not delete the first check's private files.
    result = inventory(shell, tools, tmp_path, recheck=True)
    assert result == ["2", "", "none", "not-required", "", ""]
    assert evidence == {entry.name: entry.read_bytes() for entry in tmp_path.iterdir()}


def test_inventory_fatal_flock_closes_descriptors_without_admitting_fallback(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    result = inventory(shell, tools, tmp_path, fault="ownership-flock")
    assert result[:4] == ["3", "", "none", "not-required"]
    assert result[4].split() == [tools["jq"], tools["timeout"], tools["sha"]]
    assert result[5].split()[-1] == "flock-first"


def test_inventory_fatal_required_fallback_and_absent_supervisor(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    fallback = tmp_path / "fallback"
    unsupported = tmp_path / "unsupported"
    fallback.mkdir()
    unsupported.mkdir()
    result = inventory(shell, tools, fallback, native="/usr/bin/false")
    assert result[:4] == ["2", "", "none", "not-required"]
    assert result[4].split()[-1] == "/fixture/unsafe"
    result = inventory(
        shell,
        tools,
        unsupported,
        native="-",
        jq="-",
        timeout="-",
        sha="-",
        fault="no-supervisor",
    )
    assert result == ["2", "", "none", "not-required", "", ""]
    assert list(unsupported.iterdir()) == []
