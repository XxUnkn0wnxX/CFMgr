"""Fixed real-tool probes; Linux ownership is a separate required platform proof."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "modules/lib/prerequisites.sh"
PROBE = ROOT / "modules/helpers/probe.sh"
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
        '. "$1"; shift; cfmgr_prerequisites_attachment_ok() { return 0; }; cfmgr_prerequisites_check shared "$@" - unknown || exit $?; printf "%s\\n" "$cfmgr_prereq_flock_provider"; [ "$cfmgr_prereq_result" = capabilities-checked ] && [ "$cfmgr_prereq_dns" = not-required ] && ! (: <&4) 2>/dev/null && ! (: <&5) 2>/dev/null',
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
        tools["flock"],
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
