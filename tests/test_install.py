"""Trusted local fresh-install consumer with real isolated host filesystem actions."""

from __future__ import annotations

import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest
from test_prerequisites import pause_definition
from test_storage import legacy_fsync as storage_fsync
from test_storage import shell as storage_shell

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / "modules/helpers/bootstrap.sh"
# Share the immutable native fsync fixture and selected shell contract.
shell = storage_shell
legacy_fsync = storage_fsync


@pytest.fixture(scope="module")
def package(tmp_path_factory: pytest.TempPathFactory) -> Path:
    output = tmp_path_factory.mktemp("immutable-install-package") / "complete package"
    subprocess.run(
        [sys.executable, str(ROOT / "tools/package.py"), "--output", str(output)],
        check=True,
        capture_output=True,
        timeout=10,
    )
    return output


@pytest.fixture(scope="module")
def tools(shell: list[str], tmp_path_factory: pytest.TempPathFactory) -> dict[str, str]:
    executable = shutil.which(shell[0])
    assert executable, "Selected shell must resolve to an actual executable"
    if shell[1:] == ["ash"]:
        # A sh-named symlink invokes the actual selected BusyBox ash without a
        # wrapper child or depending on developer PATH inside the isolated probe.
        executable_path = tmp_path_factory.mktemp("install-shell") / "sh"
        executable_path.symlink_to(executable)
        executable = str(executable_path)
    else:
        assert shell[1:] in ([], ["--posix"]), "Unsupported fixed probe shell contract"
    result = {"sh": executable}
    for name in (
        "env",
        "awk",
        "readlink",
        "sleep",
        "wc",
        "ls",
        "mkdir",
        "cp",
        "chmod",
        "mv",
        "sha256sum",
        "jq",
        "df",
        "timeout",
    ):
        resolved = shutil.which(name)
        assert resolved, f"Actual host {name} is required"
        result[name] = resolved
    return result


# This private fixture adapter changes only the unavailable Linux supervision
# layer. It runs the same fixed production probe executable and real utilities,
# including actual fsync(2) through the already-shared legacy errno fixture.
# Production entry/root admission is unchanged and is exercised separately in CI.
HOST_TRANSACTION = r"""
. "$1"
shift
CFMGR_VERSION=0.1.0
CFMGR_REPOSITORY=https://github.com/example/fixture
CFMGR_BRANCH=fixture
cfmgr_test_timeout=${25}
cfmgr_test_fault=${26}
cfmgr_test_detached=0
cfmgr_bootstrap_attached() {
    [ "$cfmgr_test_detached" = 0 ] && [ -d "$cfmgr_install_jffs" ] && [ -d "$cfmgr_install_opt" ]
}
cfmgr_prerequisites_run() {
    cfmgr_test_mode=$1 cfmgr_test_context=$2 cfmgr_test_sh=$3
    cfmgr_test_probe=$4 cfmgr_test_env=$5 cfmgr_test_tool=$9
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0}+1))
    cfmgr_probe_stdout=$cfmgr_test_context/$cfmgr_test_mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$cfmgr_test_context/$cfmgr_test_mode.$cfmgr_probe_serial.err
    shift 9
    case "$cfmgr_test_fault:$cfmgr_test_mode:${2-}" in copy:install-copy:*/modules/*) return 1 ;; esac
    cfmgr_test_fsync_fault=clean
    if [ "$cfmgr_test_fault" = fsync ] && [ -d "$cfmgr_install_support" ]; then cfmgr_test_fsync_fault=fsync; fi
    if [ "$cfmgr_test_fault" = complete-flush ] && [ "$cfmgr_test_mode" = install-flush ] && [ -f "$cfmgr_install_support/setup-state" ]; then
        IFS= read -r cfmgr_test_guard < "$cfmgr_install_support/setup-state"
        case "$cfmgr_test_guard" in *' complete') cfmgr_test_fsync_fault=fsync ;; esac
    fi
    (
        umask 077
        case "$cfmgr_test_mode" in install-copy) ulimit -f 2048 ;; *) ulimit -f 8 ;; esac
        exec "$cfmgr_test_timeout" --foreground --kill-after=0.1s 2s "$cfmgr_test_env" -i \
            PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= CFMGR_FSYNC_FAULT="$cfmgr_test_fsync_fault" \
            "$cfmgr_test_sh" "$cfmgr_test_probe" "$cfmgr_test_mode" "$cfmgr_test_tool" "$cfmgr_test_context" "$@"
    ) > "$cfmgr_probe_stdout" 2> "$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
    cfmgr_probe_status=reaped
    if [ "$cfmgr_test_mode" = install-copy ]; then
        case "${2-}" in
            */setup-state) [ "$cfmgr_test_fault" != interrupt ] || kill -TERM $$ ;;
            */modules/*) [ "$cfmgr_test_fault" != detach ] || cfmgr_test_detached=1 ;;
        esac
    fi
    return 0
}
cfmgr_test_install() {
    cfmgr_bootstrap_transaction "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" \
        "${10}" "${11}" "${12}" "${13}" "${14}" "${15}" "${16}" "${17}" "${18}" \
        "${19}" "${20}" "${21}" "${22}" "${23}" "${24}"
}
cfmgr_test_install "$@"
"""


def install(
    shell: list[str],
    tools: dict[str, str],
    fsync: Path,
    package: Path,
    tmp_path: Path,
    *,
    fault: str = "clean",
    missing: bool = False,
    script: str = HOST_TRANSACTION,
    extra: tuple[Path | str, ...] = (),
) -> subprocess.CompletedProcess[bytes]:
    jffs = tmp_path / "jffs"
    opt = tmp_path / "opt"
    jffs.mkdir(exist_ok=True)
    opt.mkdir(exist_ok=True)
    context = tmp_path / f"ram-{len(list(tmp_path.glob('ram-*')))}"
    context.mkdir(mode=0o700)
    arguments = [
        package,
        jffs,
        opt,
        context,
        str(os.geteuid()),
        tools["sh"],
        tools["env"],
        tools["awk"],
        tools["readlink"],
        tools["sleep"],
        tools["wc"],
        tools["ls"],
        fsync,
        tools["mkdir"],
        tools["cp"],
        tools["chmod"],
        tools["mv"],
        "-" if missing else tools["sha256sum"],
        tools["jq"],
        "12345678-1234-1234-1234-123456789abc",
        "ext4",
        "/",
        "entware",
        tools["df"],
        tools["timeout"],
        fault,
    ]
    # Publication checks and actually fsyncs every payload file and its parent.
    # Keep the per-operation 2s supervisor above; the outer harness budget scales
    # with this immutable package instead of cutting off a growing finite install.
    payload_files = sum(path.is_file() for path in package.rglob("*"))
    whole_install_budget = max(15, 5 + 2 * payload_files)
    return subprocess.run(
        [
            *shell,
            "-c",
            script,
            "install-test",
            str(BOOTSTRAP),
            *map(str, arguments),
            *map(str, extra),
        ],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        capture_output=True,
        check=False,
        timeout=whole_install_budget,
    )


def snapshot(root: Path) -> dict[str, tuple[int, bytes | None]]:
    return {
        item.relative_to(root).as_posix(): (
            item.stat().st_mode & 0o777,
            item.read_bytes() if item.is_file() else None,
        )
        for item in root.rglob("*")
    }


def test_fresh_install_publishes_passive_private_config_and_rejects_repeat(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
) -> None:
    result = install(shell, tools, legacy_fsync, package, tmp_path)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    jffs = tmp_path / "jffs"
    support = jffs / "addons/CFMgr.d"
    config = support / "config"
    data = json.loads(config.read_bytes())
    assert config.stat().st_mode & 0o777 == 0o600
    assert support.stat().st_mode & 0o777 == 0o700
    assert (jffs / "scripts/cfmgr.sh").read_bytes() == (
        package / "cfmgr.sh"
    ).read_bytes()
    assert (jffs / "scripts/cfmgr.sh").stat().st_mode & 0o777 == 0o755
    assert (support / "setup-state").read_bytes() == b"CFMGR-SETUP 1 0.1.0 complete\n"
    assert not (support / "entry.stage").exists()
    assert (
        data["manager"]["source"]["repository"] == "https://github.com/example/fixture"
    )
    assert data["manager"]["source"]["branch"] == "fixture"
    assert data["manager"]["check_updates"] and not data["manager"]["auto_update"]
    for feature in ("ddns", "ip_sync", "cloudflared"):
        assert not data[feature]["configured"] and not data[feature]["enabled"]
    assert (
        not data["cloudflared"]["installed"]
        and not data["cloudflared"]["maintenance_enabled"]
    )
    assert data["backup"]["destination"] is None
    assert list((tmp_path / "opt").iterdir()) == []
    before = snapshot(jffs)
    repeated = install(shell, tools, legacy_fsync, package, tmp_path)
    assert repeated.returncode == 1
    assert snapshot(jffs) == before


def test_retained_config_is_never_evaluated_or_reset(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
) -> None:
    support = tmp_path / "jffs/addons/CFMgr.d"
    support.mkdir(parents=True)
    content = f'$(touch "{tmp_path}/evaluated")\n'.encode()
    (support / "config").write_bytes(content)
    before = snapshot(tmp_path / "jffs")
    result = install(shell, tools, legacy_fsync, package, tmp_path)
    assert result.returncode == 1
    assert snapshot(tmp_path / "jffs") == before
    assert not (tmp_path / "evaluated").exists()


@pytest.mark.parametrize(
    "retained", ["var/lib/cfmgr", "var/tmp/cfmgr", "etc/cloudflared"]
)
def test_retained_entware_state_blocks_without_jffs_mutation(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
    retained: str,
) -> None:
    state = tmp_path / "opt" / retained
    state.mkdir(parents=True)
    (state / "owned-by-other-operation").write_bytes(b"preserved")
    result = install(shell, tools, legacy_fsync, package, tmp_path)
    assert result.returncode == 1
    assert list((tmp_path / "jffs").iterdir()) == []
    assert (state / "owned-by-other-operation").read_bytes() == b"preserved"


def test_corrupt_executable_package_fails_before_generation_or_jffs_claim(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
) -> None:
    altered = tmp_path / "altered package"
    shutil.copytree(package, altered)
    with (altered / "modules/lib/config.sh").open("a") as stream:
        stream.write(f'\nprintf hacked > "{tmp_path}/executed"\n')
    result = install(shell, tools, legacy_fsync, altered, tmp_path)
    assert result.returncode == 1
    assert not (tmp_path / "executed").exists()
    assert list((tmp_path / "jffs").iterdir()) == []
    assert not list(tmp_path.glob("ram-*/install-config.*"))


@pytest.mark.parametrize("damage", ["version", "traversal", "incomplete", "symlink"])
def test_invalid_package_boundary_never_claims_jffs(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
    damage: str,
) -> None:
    altered = tmp_path / "invalid package"
    shutil.copytree(package, altered)
    metadata = altered / "manifest.txt"
    lines = metadata.read_text().splitlines(keepends=True)
    if damage == "version":
        lines[0] = "CFMGR-MANIFEST 1 9.9.9\n"
    elif damage == "traversal":
        lines[1] = lines[1].rsplit("\t", 1)[0] + "\t../outside\n"
    elif damage == "incomplete":
        (altered / "modules/lib/config.sh").unlink()
        lines = [
            line for line in lines if not line.endswith("\tmodules/lib/config.sh\n")
        ]
        catalog = altered / "catalog.txt"
        catalog.write_text(
            "".join(
                line
                for line in catalog.read_text().splitlines(keepends=True)
                if not line.startswith("modules/lib/config.sh\t")
            )
        )
    else:
        (altered / "modules/lib/config.sh").unlink()
        (altered / "modules/lib/config.sh").symlink_to(
            package / "modules/lib/config.sh"
        )
    metadata.write_text("".join(lines))
    result = install(shell, tools, legacy_fsync, altered, tmp_path)
    assert result.returncode == 1
    assert list((tmp_path / "jffs").iterdir()) == []
    assert not list(tmp_path.glob("ram-*/install-config.*"))


def test_missing_required_tool_blocks_before_any_jffs_write(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
) -> None:
    result = install(shell, tools, legacy_fsync, package, tmp_path, missing=True)
    assert result.returncode == 1
    assert list((tmp_path / "jffs").iterdir()) == []


@pytest.mark.parametrize(
    "fault", ["copy", "fsync", "interrupt", "detach", "complete-flush"]
)
def test_failed_or_interrupted_publication_preserves_guard_and_blocks_reset(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    package: Path,
    tmp_path: Path,
    fault: str,
) -> None:
    result = install(shell, tools, legacy_fsync, package, tmp_path, fault=fault)
    assert result.returncode != 0
    jffs = tmp_path / "jffs"
    support = jffs / "addons/CFMgr.d"
    assert support.is_dir()
    if fault == "complete-flush":
        assert (jffs / "scripts/cfmgr.sh").is_file()
        assert (support / "config").is_file()
        assert (
            support / "setup-state"
        ).read_bytes() == b"CFMGR-SETUP 1 0.1.0 installing\n"
    else:
        assert not (jffs / "scripts/cfmgr.sh").exists()
        assert not (support / "config").exists()
    before = snapshot(jffs)
    repeated = install(shell, tools, legacy_fsync, package, tmp_path)
    assert repeated.returncode == 1
    assert snapshot(jffs) == before


def test_package_builder_and_native_read_only_entry_are_fork_neutral(
    shell: list[str], package: Path, tmp_path: Path
) -> None:
    subprocess.run(
        [
            sys.executable,
            str(ROOT / "tools/package.py"),
            "--output",
            str(tmp_path / "built package"),
        ],
        check=True,
        capture_output=True,
        timeout=10,
    )
    for option in ("--help", "--version"):
        result = subprocess.run(
            [*shell, str(package / "cfmgr.sh"), option],
            check=False,
            capture_output=True,
            timeout=2,
        )
        assert result.returncode == 0 and result.stderr == b""
        assert b"CFMgr" in result.stdout
        assert (
            b"ssh router" not in result.stdout and b"/mnt/MERLIN" not in result.stdout
        )


def test_linux_controller_signal_reaps_active_copy_and_stops_publication(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    if sys.platform != "linux":
        pytest.skip(
            "Signalling an identified owned writer and proc FD pinning require Linux"
        )
    context = tmp_path / "owned RAM context"
    context.mkdir(mode=0o700)
    source = tmp_path / "known bytes"
    source.write_bytes(b"known package bytes")
    target = tmp_path / "blocked owned destination"
    os.mkfifo(target, 0o600)
    (context / "records").write_text("one record\n")
    marker = tmp_path / "unexpected publication"
    script = r"""
. "$1/modules/lib/prerequisites.sh"
. "$1/modules/helpers/bootstrap.sh"
cfmgr_install_source=$1 cfmgr_install_context=$2 cfmgr_install_sh=$3
cfmgr_install_env=$4 cfmgr_install_awk=$5 cfmgr_install_sleep=$6 cfmgr_install_wc=$7
cfmgr_install_cp=$8
cfmgr_bootstrap_signals
exec 5<"$cfmgr_install_context"
cfmgr_install_context_fd=5
cfmgr_bootstrap_attached() {
    [ "$cfmgr_install_interrupted" = 0 ] && [ "$cfmgr_install_context" -ef /proc/self/fd/5 ]
}
cfmgr_prerequisites_attachment_ok() { cfmgr_bootstrap_attached; }
while IFS= read -r record; do
    if cfmgr_bootstrap_action install-copy "$9" "${10}"; then
        printf incorrect >"${11}"
        exit 91
    fi
    [ "$cfmgr_install_interrupted" = 1 ] && [ "$cfmgr_probe_status" = reaped ] || exit 92
    [ ! -d "/proc/$cfmgr_probe_pid" ] || exit 93
    printf '%s\n' "$cfmgr_probe_status"
done <"$cfmgr_install_context/records"
"""
    script = script.replace(
        '. "$1/modules/helpers/bootstrap.sh"\n',
        '. "$1/modules/helpers/bootstrap.sh"\n' + pause_definition(shell) + "\n",
        1,
    )
    arguments = [
        ROOT,
        context,
        tools["sh"],
        tools["env"],
        tools["awk"],
        tools["sleep"],
        tools["wc"],
        tools["cp"],
        source,
        target,
        marker,
    ]
    process = subprocess.Popen(
        [*shell, "-c", script, "owned-signal-test", *map(str, arguments)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    child = None
    child_start = None
    try:
        deadline = time.monotonic() + 1.5
        while time.monotonic() < deadline:
            children_file = Path(f"/proc/{process.pid}/task/{process.pid}/children")
            children = (
                children_file.read_text().split() if children_file.exists() else []
            )
            for candidate in children:
                cmdline = Path(f"/proc/{candidate}/cmdline")
                if cmdline.exists() and cmdline.read_bytes().split(b"\0", 1)[
                    0
                ] == os.fsencode(tools["cp"]):
                    identity = (
                        Path(f"/proc/{candidate}/stat")
                        .read_text()
                        .rsplit(") ", 1)[1]
                        .split()
                    )
                    assert int(identity[1]) == process.pid
                    child_start = identity[19]
                    child = int(candidate)
                    break
            if child is not None:
                break
            assert process.poll() is None, (
                "Controller exited before an actual active copy"
            )
            time.sleep(0.01)
        assert child is not None, (
            "Required identified real copy writer was never active"
        )
        os.kill(process.pid, signal.SIGTERM)
        stdout, stderr = process.communicate(timeout=3)
        assert (process.returncode, stdout, stderr) == (0, b"reaped\n", b"")
        assert not Path(f"/proc/{child}").exists()
        assert not marker.exists()
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(timeout=3)
        if child is not None and Path(f"/proc/{child}").exists():
            identity = (
                Path(f"/proc/{child}/stat").read_text().rsplit(") ", 1)[1].split()
            )
            # Preserve uncertainty if a PID was reused; cleanup targets only the
            # original recorded direct child's unchanged process-start identity.
            if identity[19] == child_start:
                os.kill(child, signal.SIGKILL)


def test_native_install_routes_all_tool_admission_through_inventory(
    shell: list[str], tmp_path: Path
) -> None:
    # Trace the actual controller up to prerequisite checking without pretending
    # these fixtures prove native firmware storage/root admission. A fatal fixed
    # admission call before the shared check detects the old first-failure path.
    enabled = tmp_path / "native scripts enabled"
    enabled.write_text("1\n")
    script = r"""
. "$1"
cfmgr_install_context=$2 cfmgr_install_source=$3 cfmgr_storage_opt=$2
cfmgr_storage_source=/fixture/device
cfmgr_bootstrap_retained() { return 0; }
cfmgr_bootstrap_native_admission() { return 0; }
cfmgr_test_enabled=$4; cfmgr_bootstrap_action() { cfmgr_install_output=$cfmgr_test_enabled; }
cfmgr_test_empty=$5; cfmgr_prerequisites_run() { cfmgr_probe_exit=0; cfmgr_probe_stderr=$cfmgr_test_empty; }
cfmgr_storage_uuid() { return 0; }
cfmgr_bootstrap_metadata() { return 0; }
cfmgr_bootstrap_admit_tool() { printf 'premature admission\n'; return 77; }
cfmgr_prerequisites_check() {
    [ "$#" = 15 ] && [ "$1" = shared ] && [ "$2" = "$cfmgr_install_context" ] || return 92
    shift 9
    [ "$1" = /opt/bin/jq ] && [ "$2" = /opt/bin/timeout ] &&
        [ "$3" = /opt/bin/sha256sum ] && [ "$4" = /opt/bin/flock ] &&
        [ "$5" = - ] && [ "$6" = unknown ] || return 93
    printf 'shared inventory\n'
    cfmgr_prereq_result=capabilities-checked cfmgr_prereq_missing='jq coreutils-timeout'
    return 1
}
cfmgr_dependencies_repair() {
    [ "$1" = 'jq coreutils-timeout' ] && [ "$2" = /tmp/cfmgr ] || return 94
    printf 'mapped repair\n'
    cfmgr_dependencies_phase=fixture-admission
    return 1
}
exec 0<"$2" 9<"$3"
cfmgr_bootstrap_native_work
[ "$?" = 1 ]
"""
    empty = tmp_path / "probe stderr"
    empty.write_bytes(b"")
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "native-inventory-test",
            BOOTSTRAP,
            tmp_path,
            ROOT,
            enabled,
            empty,
        ],
        check=False,
        capture_output=True,
        timeout=2,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"shared inventory\nmapped repair\n",
        b"[CFMGR] install: error: dependency repair failed (fixture-admission)\n",
    )
