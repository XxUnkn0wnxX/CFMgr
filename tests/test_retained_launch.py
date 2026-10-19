"""Retained launch consumer; host adapters do not qualify firmware path admission."""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
from pathlib import Path

import pytest
from test_dependencies import (
    base_tools,
    dependency_process,
    fixture_tools,
    installer_adapter,
    package,
    run_dependency_case,
    selected_shell,
)
from test_install import legacy_fsync, shell, tools

ROOT = Path(__file__).resolve().parents[1]
__all__ = [
    "base_tools",
    "dependency_process",
    "fixture_tools",
    "installer_adapter",
    "legacy_fsync",
    "package",
    "selected_shell",
    "shell",
    "tools",
]


@pytest.fixture(scope="module")
def retained_package(package: Path) -> Path:
    # Share the immutable actual package; launch_host creates fresh mutable state.
    return package


@pytest.fixture(scope="module")
def retained_config(tools: dict[str, str], shell: list[str]) -> bytes:
    # Explicit schema1 original: opaque legacy data is not relabelled schema2.
    value = json.loads((ROOT / "tests/fixtures/config-schema1.json").read_bytes())
    value["manager"]["source"].update(
        repository="https://github.com/example/fixture", branch="fixture"
    )
    value["storage"]["entware"].update(
        uuid="12345678-1234-1234-1234-123456789abc", root="/"
    )
    value["generation"] = 19
    value["manager"]["check_updates"] = False
    value["ddns"]["configured"] = True
    value["ddns"]["credentials"] = "fixture-only-kept-secret"
    value["history"]["ddns"] = {"kept": "unrelated \\ escape"}
    # Deliberate formatting must survive a storage-only patch.
    return (json.dumps(value, indent=2) + "\n").encode()


HOST_LAUNCH = r"""
. "$1/modules/lib/execution.sh"
. "$1/modules/lib/package.sh"
. "$1/modules/lib/package.sh"
# Native lock/supervisor proof is in test_config_store; old host transaction
# fixtures adapt firmware lock admission along with their mount admission.
shift
cfmgr_install_source=$1 cfmgr_install_jffs=$2 cfmgr_install_context=$3
cfmgr_install_private_context=$3 cfmgr_install_source_fd=9 cfmgr_install_context_fd=0
cfmgr_install_owner=$4
shift 4
cfmgr_install_sh=$1 cfmgr_install_env=$2 cfmgr_install_awk=$3 cfmgr_install_readlink=$4
cfmgr_install_sleep=$5 cfmgr_install_wc=$6 cfmgr_install_ls=$7 cfmgr_install_fsync=$8
cfmgr_install_mkdir=$9
shift 9
cfmgr_install_cp=$1 cfmgr_install_chmod=$2 cfmgr_install_mv=$3 cfmgr_install_sha=$4 cfmgr_install_jq=$5 cfmgr_install_df=$6
host_timeout=$7 host_scenario=$8
CFMGR_VERSION=0.1.0
cfmgr_launch_storage_required=0 cfmgr_launch_guard_owned=0 cfmgr_launch_migrating=0
cfmgr_install_interrupted=0 cfmgr_probe_status=reaped
cfmgr_storage_uuid_value=12345678-1234-1234-1234-123456789abc
cfmgr_storage_filesystem=ext4 cfmgr_storage_fsroot=/ cfmgr_storage_relative=entware
exec 0<"$cfmgr_install_context" 8<"$cfmgr_install_jffs" 9<"$cfmgr_install_source"
cfmgr_test_later_config() {
    [ ! -e "$cfmgr_install_context/later-config-mutated" ] || return 1
    "$cfmgr_install_jq" '.ddns.enabled = false | .manager.check_updates = true' \
        "$cfmgr_launch_live" >"$cfmgr_install_context/later-config.json" || return 1
    "$cfmgr_install_chmod" 600 "$cfmgr_install_context/later-config.json" || return 1
    "$cfmgr_install_cp" "$cfmgr_install_context/later-config.json" \
        "$cfmgr_install_context/later-config.expected" || return 1
    "$cfmgr_install_mv" "$cfmgr_install_context/later-config.json" "$cfmgr_launch_live" || return 1
    : >"$cfmgr_install_context/later-config-mutated"
}
cfmgr_config_store_observation_lock() {
    if [ "$host_scenario" = later-off-early ]; then cfmgr_test_later_config || return $?; fi
    return 0
}
# Only unavailable host mount/process admission is adapted. The production
# parser, manifest mapping, hashing, config guard and publication execute.
cfmgr_bootstrap_native_attached() { [ -d "$cfmgr_install_context" ] && [ -d "$cfmgr_install_source" ]; }
cfmgr_storage_attached() { [ "$host_scenario" != lost ]; }
cfmgr_storage_pin() {
    printf 'pin\n' >>"$cfmgr_install_jffs/routes"
    [ "$host_scenario" != absent ]
}
cfmgr_bootstrap_shared_requirements() {
    [ "$1" = retained ] && [ -r "$cfmgr_launch_snapshot" ] || return 99
    printf 'shared\n' >>"$cfmgr_install_jffs/routes"
    case "$host_scenario" in
    replace | publish-fail | postrename-flush | postrename-readback | cleanup-flush | later-off-early | later-off-final | low-space)
        cfmgr_storage_uuid_value=87654321-4321-4321-4321-cba987654321
        ;;
    esac
}
cfmgr_launch_metadata() {
    [ ! -L "$1" ] || return 1
    # Host UID adapter only. Root0 and exact modes are production obligations.
    [ "$("$cfmgr_install_ls" -ldn "$1" | "$cfmgr_install_awk" '{print $3}')" = "$cfmgr_install_owner" ] || return 1
    case $2 in private) [ -d "$1" ] ;; config) [ -f "$1" ] ;; readonly | protected) [ -e "$1" ] ;; *) return 1 ;; esac
}
cfmgr_launch_guard_attachment() {
    [ "$cfmgr_launch_guard_owned" != 1 ] || [ -d "$cfmgr_launch_guard" ] || [ "$cfmgr_launch_retiring" = 1 ]
}
cfmgr_launch_storage_unavailable() {
    printf '[CFMGR] launch: error: Entware attachment unavailable; operation stopped\n' >&2
    # Portable logger sink proves the fixed actual launch-report dispatcher.
    cfmgr_launch_logger=$cfmgr_install_jffs/logger
    cfmgr_launch_action launch-report storage-unavailable || return $?
    return 1
}
cfmgr_prerequisites_run() {
    mode=$1 context=$2 selected_sh=$3 helper=$4 selected_env=$5 selected_tool=$9
    shift 9
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0}+1))
    cfmgr_probe_stdout=$context/$mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$context/$mode.$cfmgr_probe_serial.err
    cfmgr_probe_mode=$mode cfmgr_probe_pid=host-adapter cfmgr_probe_status=reaped
    if [ "$host_scenario:$mode" = publish-fail:install-rename ]; then return 1; fi
    if [ "$host_scenario:$mode" = unresolved:launch-config-check ]; then cfmgr_probe_status=unresolved; return 3; fi
    if [ "$mode" = launch-rmdir ]; then
        # Linux descriptor proof is exercised by the real namespace fixture.
        "$selected_tool" "$1" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
        cfmgr_probe_exit=$?
    else
        cfmgr_test_fsync_fault=clean
        case "$host_scenario:$mode" in
        postrename-flush:install-flush)
            [ ! -e "$cfmgr_install_context/postrename-published" ] || cfmgr_test_fsync_fault=fsync
            ;;
        cleanup-flush:install-flush)
            [ ! -e "$cfmgr_install_context/guard-retired" ] || cfmgr_test_fsync_fault=fsync
            ;;
        esac
        "$host_timeout" --foreground --kill-after=0.1s 2s "$selected_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= CFMGR_FSYNC_FAULT="$cfmgr_test_fsync_fault" \
            "$selected_sh" "$helper" "$mode" "$selected_tool" "$context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
        cfmgr_probe_exit=$?
    fi
    if [ "$host_scenario" = postrename-readback ] && [ "$mode" = install-rename ] && [ "${2-}" = "$cfmgr_install_source/config" ]; then
        printf 'corrupt' >>"$cfmgr_install_source/config"
    fi
    if [ "$host_scenario" = later-off-final ] && [ "$mode" = install-copy ] &&
        [ "${1-}" = "${cfmgr_launch_candidate-}" ] && [ "$cfmgr_probe_exit" -eq 0 ]; then
        cfmgr_test_later_config || return 1
    fi
    if [ "$host_scenario" = postrename-flush ] && [ "$mode" = install-rename ] && [ "${2-}" = "$cfmgr_install_source/config" ]; then
        : >"$cfmgr_install_context/postrename-published"
    fi
    if [ "$host_scenario" = cleanup-flush ] && [ "$mode" = launch-rmdir ] && [ "$cfmgr_probe_exit" -eq 0 ]; then
        : >"$cfmgr_install_context/guard-retired"
    fi
    if [ "$host_scenario:$mode" = snapshot-framing:launch-copy ] &&
        [ "${2-}" = "$cfmgr_install_context/catalog.txt.snapshot" ] && [ "$cfmgr_probe_exit" -eq 0 ]; then
        printf '\000' >>"$2"
    fi
}
cfmgr_bootstrap_native_prepare() { [ "$1:$2" = /jffs/addons/CFMgr.d:launch ]; }
cfmgr_bootstrap_cleanup() { printf 'cleanup\n' >>"$cfmgr_install_jffs/cleanup-route"; }
if cfmgr_launch_native /jffs/addons/CFMgr.d; then status=0; else status=$?; fi
printf 'status=%s recovery=%s\n' "$status" "${cfmgr_launch_recovery:-0}"
exec 0<&- 3<&- 4<&- 5<&- 8<&- 9<&-
"""


def launch_host(
    shell: list[str],
    tools: dict[str, str],
    fsync: Path,
    package: Path,
    config: bytes,
    workspace: Path,
    scenario: str,
    *,
    timeout: float = 20,
) -> tuple[subprocess.CompletedProcess[bytes], Path]:
    jffs = workspace / "jffs"
    support = jffs / "addons/CFMgr.d"
    support.mkdir(parents=True, mode=0o700)
    support.chmod(0o700)
    shutil.copytree(package / "modules", support / "modules")
    for name in ("catalog.txt", "manifest.txt"):
        shutil.copy2(package / name, support / name)
    (jffs / "scripts").mkdir()
    shutil.copy2(package / "cfmgr.sh", jffs / "scripts/cfmgr.sh")
    (support / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (support / "setup-state").chmod(0o600)
    (support / "config").write_bytes(config)
    (support / "config").chmod(0o600)
    if scenario == "guard":
        (support / ".storage-observation").mkdir(mode=0o700)
        (support / ".storage-observation/sentinel").write_text("keep\n")
    if scenario == "setup-complete-guard":
        (support / ".setup.complete").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    if scenario == "incomplete":
        (support / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 installing\n")
    context = workspace / "private RAM"
    context.mkdir(mode=0o700)
    logger = jffs / "logger"
    logger.write_text(
        "#!/bin/sh\nprintf '%s\\n' \"$3\" >"
        + shlex.quote(str(jffs / "system-message"))
        + "\n"
    )
    logger.chmod(0o700)
    selected_df = tools["df"]
    if scenario == "low-space":
        selected_df_path = context / "df-low-space"
        selected_df_path.write_text(
            "#!/bin/sh\nprintf 'called\\n' >"
            + shlex.quote(str(context / "df-called"))
            + "\nprintf 'Filesystem 1024-blocks Used Available Capacity Mounted on\\n'\nprintf '/dev/fixture 1000000 1000000 0 100%% /\\n'\n"
        )
        selected_df_path.chmod(0o700)
        selected_df = str(selected_df_path)
    result = subprocess.run(
        [
            *shell,
            "-c",
            HOST_LAUNCH,
            "retained-launch",
            str(ROOT),
            str(support),
            str(jffs),
            str(context),
            str(os.geteuid()),
            tools["sh"],
            tools["env"],
            tools["awk"],
            tools["readlink"],
            tools["sleep"],
            tools["wc"],
            tools["ls"],
            str(fsync),
            tools["mkdir"],
            tools["cp"],
            tools["chmod"],
            tools["mv"],
            tools["sha256sum"],
            tools["jq"],
            selected_df,
            tools["timeout"],
            scenario,
        ],
        capture_output=True,
        check=False,
        timeout=timeout,
    )
    return result, support


def test_source_inert(shell: list[str], tmp_path: Path) -> None:
    sources = (
        sorted((ROOT / "modules/lib").glob("*.sh"))
        + sorted((ROOT / "modules").glob("*.sh"))
        + [ROOT / "modules/lib/package.sh", ROOT / "modules/lib/package.sh"]
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            'cd "$1" || exit 1; shift; before="$PWD:$-:$(umask)"; for source do . "$source" || exit 1; done; [ "$before" = "$PWD:$-:$(umask)" ]',
            "inert",
            str(tmp_path),
            *map(str, sources),
        ],
        capture_output=True,
        check=False,
        timeout=2,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_invalid_metadata_snapshot_blocks_before_storage_pin_or_repair(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    retained_package: Path,
    retained_config: bytes,
    tmp_path: Path,
) -> None:
    result, support = launch_host(
        shell,
        tools,
        legacy_fsync,
        retained_package,
        retained_config,
        tmp_path,
        "snapshot-framing",
    )
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    assert b"status=1 recovery=0" in result.stdout
    catalog = (support / "catalog.txt").read_bytes()
    assert (tmp_path / "private RAM/catalog.txt.snapshot").read_bytes() == (
        catalog + b"\0"
    )
    assert (support / "config").read_bytes() == retained_config
    assert not (support / ".storage-observation").exists()
    assert not (tmp_path / "jffs/routes").exists()


@pytest.mark.parametrize(
    "scenario",
    [
        "healthy",
        "replace",
        "publish-fail",
        "postrename-flush",
        "postrename-readback",
        "cleanup-flush",
        "later-off-early",
        "later-off-final",
        "low-space",
        "absent",
        "lost",
        "guard",
        "setup-complete-guard",
        "incomplete",
        "corrupt",
        "unresolved",
    ],
)
def test_actual_retained_consumer_and_preserved_config(
    shell: list[str],
    tools: dict[str, str],
    legacy_fsync: Path,
    retained_package: Path,
    retained_config: bytes,
    tmp_path: Path,
    scenario: str,
) -> None:
    original = b"{broken\n" if scenario == "corrupt" else retained_config
    if scenario in {"later-off-early", "later-off-final"}:
        original_value = json.loads(original)
        original_value["ddns"]["enabled"] = True
        original = (json.dumps(original_value, indent=2) + "\n").encode()
        later_value = json.loads(original)
        later_value["ddns"]["enabled"] = False
        later_value["manager"]["check_updates"] = True
    result, support = launch_host(
        shell, tools, legacy_fsync, retained_package, original, tmp_path, scenario
    )
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    success = scenario in {"healthy", "replace"}
    expected_status = 0 if success else 3 if scenario == "unresolved" else 1
    assert f"status={expected_status} ".encode() in result.stdout, (
        result.stdout,
        result.stderr,
    )
    current = (support / "config").read_bytes()
    candidate = original.replace(b'"generation": 19', b'"generation": 20').replace(
        b"12345678-1234-1234-1234-123456789abc",
        b"87654321-4321-4321-4321-cba987654321",
    )
    if scenario == "replace":
        assert current == candidate
        assert not (support / ".storage-observation").exists()
    elif scenario in {"postrename-flush", "postrename-readback", "cleanup-flush"}:
        assert current != original
    elif scenario in {"later-off-early", "later-off-final"}:
        live = json.loads(current)
        assert live == later_value
        assert (support / "config").stat().st_mode & 0o777 == 0o600
        assert (tmp_path / "private RAM/later-config-mutated").is_file()
        assert current == (tmp_path / "private RAM/later-config.expected").read_bytes()
        assert b"verified Entware observation updated" not in result.stdout
        guard = support / ".storage-observation"
        if scenario == "later-off-early":
            assert not guard.exists()
            assert b"recovery=0" in result.stdout
        else:
            assert guard.is_dir()
            assert (guard / "old").read_bytes() == original
            assert (guard / "candidate").read_bytes() == candidate
            assert (guard / "intent").is_file()
            assert b"recovery=1" in result.stdout
    else:
        assert current == original
    routes = support.parents[1] / "routes"
    if scenario in {
        "guard",
        "setup-complete-guard",
        "incomplete",
        "corrupt",
        "unresolved",
    }:
        assert not routes.exists(), (
            "invalid retained state reached storage/dependency work"
        )
    if scenario == "publish-fail":
        # The replacement observation is needed to exercise actual publication.
        assert (support / ".storage-observation").is_dir()
        assert (tmp_path / "private RAM/config.snapshot").read_bytes() == original
        assert not (support.parents[1] / "cleanup-route").exists()
    if scenario in {"postrename-flush", "postrename-readback"}:
        guard = support / ".storage-observation"
        assert guard.is_dir()
        assert (guard / "old").read_bytes() == original
        # The same-filesystem publication rename consumes candidate. Verify
        # its exact bytes at config; intent separately binds target generation
        # and size while retaining the old snapshot digest.
        assert not (guard / "candidate").exists()
        assert (guard / "intent").is_file()
        assert (tmp_path / "private RAM/config.snapshot").read_bytes() == original
        if scenario == "postrename-flush":
            assert (tmp_path / "private RAM/postrename-published").is_file()
            assert any(
                path.read_bytes()
                for path in (tmp_path / "private RAM").glob("install-flush.*.err")
            ), "exit-zero/stderr flush fault was not exercised"
            assert current == candidate
        else:
            assert current == candidate + b"corrupt"
    if scenario == "cleanup-flush":
        assert (tmp_path / "private RAM/guard-retired").is_file()
        assert not (support / ".storage-observation").exists()
        assert json.loads(current)["generation"] == 20
    if scenario == "low-space":
        assert (tmp_path / "private RAM/df-called").is_file()
        assert current == original
        assert not (support / ".storage-observation").exists()
    if scenario == "unresolved":
        assert not (support.parents[1] / "cleanup-route").exists()
        assert not (support.parents[1] / "system-message").exists()
    if scenario in {"absent", "lost"}:
        assert b"Entware attachment unavailable" in result.stderr
        assert (
            (support.parents[1] / "system-message").read_text()
            == "[CFMGR] launch: error: Entware attachment unavailable; operation stopped\n"
        )


@pytest.fixture(scope="module")
def retained_adapter(
    tmp_path_factory: pytest.TempPathFactory, installer_adapter: Path
) -> Path:
    folder = tmp_path_factory.mktemp("retained-native-adapter")
    original = (ROOT / "modules/lib/storage.sh").read_bytes()
    definition = b"cfmgr_storage_pin() {"
    renamed_definition = b"cfmgr_test_real_storage_pin() {"
    assert original.count(definition) == 1
    renamed = original.replace(definition, renamed_definition, 1)
    assert renamed.replace(renamed_definition, definition, 1) == original
    alias = folder / "storage.sh"
    alias.write_bytes(renamed)
    adapter = folder / "adapter.sh"
    adapter.write_text(
        installer_adapter.read_text()
        + "\n"
        + "dependency_retained_fixture="
        + shlex.quote(str(ROOT / "tests/fixtures/retained_launch.sh"))
        + "\n"
        + "retained_storage_alias="
        + shlex.quote(str(alias))
        + "\n"
    )
    return adapter


def test_real_retained_repair_and_later_return(
    fixture_tools: tuple[list[str], str, str, str],
    dependency_process: Path,
    retained_adapter: Path,
    tmp_path: Path,
    capfd: pytest.CaptureFixture[str],
) -> None:
    with capfd.disabled():
        result = run_dependency_case(
            fixture_tools,
            dependency_process,
            tmp_path,
            "dependency_installer",
            retained_adapter,
        )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert (
        b"PASS: actual retained repair, immutable migration, missing-message and returned-volume no-op"
        in result.stdout
    )
    assert b"Entware attachment unavailable" in result.stderr
    assert b"shared dependencies verified; tunnel DNS verified" in result.stdout
    assert b"shared dependencies verified; tunnel DNS deferred" in result.stdout
    assert (
        b"PASS: actual normal native SRV/A and scoped outage with configured-Off settings"
        in result.stdout
    )
    assert (
        b"PASS: actual healthy force, alternate jq-full, settings/history/Off and released guards"
        in result.stdout
    )


@pytest.mark.parametrize("invocation", ["absolute", "relative", "help", "source"])
def test_entry_default_routes_only_the_installed_entry(
    shell: list[str],
    tools: dict[str, str],
    tmp_path: Path,
    invocation: str,
) -> None:
    jffs = tmp_path / "jffs"
    scripts = jffs / "scripts"
    scripts.mkdir(parents=True)
    calls = tmp_path / "isolated-launch-argv"
    env_sink = tmp_path / "native-env-sink"
    env_sink.write_text(
        "#!/bin/sh\nprintf '%s\\n' \"$@\" >" + shlex.quote(str(calls)) + "\n"
    )
    env_sink.chmod(0o700)
    original = (ROOT / "cfmgr.sh").read_text()
    adapted = (
        original.replace("/jffs", shlex.quote(str(jffs.resolve())))
        .replace("/usr/bin/readlink", shlex.quote(tools["readlink"]))
        .replace("/usr/bin/env", shlex.quote(str(env_sink.resolve())))
    )
    assert (
        adapted.replace(shlex.quote(str(env_sink.resolve())), "/usr/bin/env")
        .replace(shlex.quote(tools["readlink"]), "/usr/bin/readlink")
        .replace(shlex.quote(str(jffs.resolve())), "/jffs")
        == original
    )
    entry = scripts / "cfmgr.sh"
    entry.write_text(adapted)
    entry.chmod(0o755)
    source = tmp_path / "source-cfmgr.sh"
    source.write_text(adapted)
    source.chmod(0o755)
    command = (
        "./cfmgr.sh"
        if invocation == "relative"
        else str(source if invocation == "source" else entry)
    )
    result = subprocess.run(
        [*shell, command, *(["--help"] if invocation == "help" else [])],
        cwd=scripts,
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    if invocation in {"absolute", "relative"}:
        assert calls.read_text().splitlines() == [
            "-i",
            "PATH=/bin:/usr/bin:/sbin:/usr/sbin",
            "LC_ALL=C",
            "LANGUAGE=",
            "CFMGR_INTERNAL_LAUNCH=1",
            "/bin/sh",
            str(entry),
            "--internal-launch",
        ]
    else:
        assert not calls.exists()
        assert b"CFMgr: --install" in result.stdout
    assert entry.read_text() == adapted
