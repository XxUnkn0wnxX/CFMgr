"""Retained launch consumer; host adapters do not qualify firmware path admission."""

from __future__ import annotations

import json
import os
import pty
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from entry_package_fixture import adapt_native, finish_package
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
    driver = folder / "entry.py"
    driver.write_text(
        "import sys\n"
        # sudo's environment and the caller's cwd need not expose the checkout.
        f"sys.path[:0] = [{str(ROOT / 'tests')!r}, {str(ROOT)!r}]\n"
        "from test_retained_launch import retained_entry_journey\n"
        "if __name__ == '__main__':\n"
        "    retained_entry_journey(*sys.argv[1:])\n"
    )
    adapter.write_text(
        installer_adapter.read_text()
        + "\n"
        + "dependency_retained_fixture="
        + shlex.quote(str(ROOT / "tests/fixtures/retained_launch.sh"))
        + "\n"
        + "retained_storage_alias="
        + shlex.quote(str(alias))
        + "\n"
        + "retained_entry_driver="
        + shlex.quote(str(driver))
        + "\nretained_entry_python="
        + shlex.quote(sys.executable)
        + "\n"
    )
    return adapter


def fixture_functions(path: Path, names: tuple[str, ...]) -> str:
    """Copy an explicit callback list, with no fixture setup or scenario code."""
    source = path.read_text()
    definitions = []
    for name in names:
        matches = list(re.finditer(rf"(?m)^{name}\(\) \{{", source))
        assert len(matches) == 1, (path, name)
        start = matches[0].start()
        first_end = source.index("\n", start)
        if source[start:first_end].endswith("}"):
            end = first_end
        else:
            closing = re.search(r"(?m)^}$", source[first_end:])
            assert closing is not None, (path, name)
            end = first_end + closing.end()
        definitions.append(source[start:end] + "\n")
    return "\n".join(definitions)


def retained_entry_bridge(fixture: Path, adapter: Path, storage_alias: Path) -> str:
    """Replay finite existing OS/tool adapters after a real entry's imports.

    Fresh POSIX shells cannot inherit callbacks. Only the private entry gets
    this suffix after its imports; admission, launch work, repair, probes,
    supervisor and cleanup bodies still execute their production implementations.
    """
    fixtures = ROOT / "tests/fixtures"
    callbacks = "".join(
        fixture_functions(fixtures / file, names)
        for file, names in (
            (
                "storage_mounts.sh",
                (
                    "view_action",
                    "view_native",
                    "cfmgr_execution_view_keeper",
                    "cfmgr_execution_view_quiescent",
                ),
            ),
            (
                "dependencies.sh",
                (
                    "dependency_trace",
                    "dependency_outcome_capture",
                    "dependency_native",
                    "dependency_inside_tools",
                    "dependency_native_tool",
                ),
            ),
            (
                "dependency_installer.sh",
                (
                    "cfmgr_test_cost",
                    "cfmgr_dependencies_repair",
                    "cfmgr_dependencies_inside_tools",
                    "cfmgr_dependencies_native_tool",
                    "cfmgr_execution_tasks_native",
                    "cfmgr_mount_keeper_native",
                    "cfmgr_dependencies_admit",
                    "cfmgr_bootstrap_native_admission",
                    "cfmgr_bootstrap_metadata",
                    "cfmgr_prerequisites_admit_tool",
                    "cfmgr_prerequisites_check",
                ),
            ),
            (
                "retained_launch.sh",
                (
                    "cfmgr_bootstrap_native_prepare",
                    "cfmgr_bootstrap_native_attached",
                    "cfmgr_bootstrap_attached",
                    "cfmgr_storage_pin",
                    "cfmgr_execution_view_native",
                    "cfmgr_prerequisites_pause",
                    "cfmgr_bootstrap_dns_admit_native",
                ),
            ),
        )
    )
    # Observation wrappers preserve the complete selected implementations. Their
    # sidecars survive child cleanup and contain only synthetic phase/status data.
    callbacks = callbacks.replace(
        "cfmgr_prerequisites_check() {", "cfmgr_test_entry_check() {", 1
    )
    cleanup = fixture_functions(
        ROOT / "modules/lib/package.sh", ("cfmgr_bootstrap_cleanup",)
    ).replace("cfmgr_bootstrap_cleanup() {", "cfmgr_test_entry_cleanup() {", 1)
    header = (
        f"\n. {shlex.quote(str(adapter))}\n"
        '. "$dependency_repair_alias"\n. "$dependency_probe_alias"\n'
        f". {shlex.quote(str(storage_alias))}\n"
        f"root={shlex.quote(str(ROOT))}\nfixture={shlex.quote(str(fixture))}\n"
    )
    state = r"""
view_native_root=$fixture/native view_ram=$fixture/native/tmp/private-ram
view_busybox=$view_native_root/bin/busybox
retained_support=$fixture/jffs/addons/CFMgr.d installer_package=$fixture/jffs/addons/CFMgr.d
retained_dns_tool=$view_ram/retained-nslookup
cfmgr_storage_alias=$fixture/opt
cfmgr_view_test_quiet=1 cfmgr_view_test_fault=clean
cfmgr_test_cost_installer=0 installer_probe_count=0 retained_attempt=0
dependency_trace_count=0 dependency_trace_started=0
cfmgr_install_sh=$view_ram/ash cfmgr_install_env=$view_ram/env cfmgr_install_awk=$view_ram/awk
cfmgr_install_readlink=$view_ram/readlink cfmgr_install_sleep=/bin/sleep cfmgr_install_wc=$view_ram/wc
cfmgr_install_ls=$view_ram/ls cfmgr_install_mkdir=$view_ram/mkdir cfmgr_install_cp=$view_ram/cp
cfmgr_install_chmod=$view_ram/chmod cfmgr_install_sha=$installer_sha cfmgr_install_jq=$installer_jq
cfmgr_install_df=$installer_df cfmgr_install_mv=$installer_mv cfmgr_install_fsync=$installer_fsync
cfmgr_install_nvram=$view_ram/nvram cfmgr_install_interrupted=0
cfmgr_install_tmp_snapshot=$("$view_ram/awk" "$(cfmgr_storage_awk_mountinfo; printf '%s' "$cfmgr_awk_program")" "$view_ram" /proc/self/mountinfo)
cfmgr_prerequisites_check() {
    if cfmgr_test_entry_check "$@"; then cfmgr_test_entry_status=0; else cfmgr_test_entry_status=$?; fi
    printf 'probe %s %s\n' "$installer_probe_count" "$cfmgr_test_entry_status" >>"$fixture/entry.receipt"
    return "$cfmgr_test_entry_status"
}
cfmgr_bootstrap_cleanup() {
    if cfmgr_test_entry_cleanup "$@"; then cfmgr_test_entry_status=0; else cfmgr_test_entry_status=$?; fi
    printf 'cleanup %s %s %s %s\n' "$cfmgr_test_entry_status" "${cfmgr_dependencies_result:-none}" \
        "${cfmgr_view_state:-none}" "${cfmgr_keeper_state:-none}" >>"$fixture/entry.receipt"
    return "$cfmgr_test_entry_status"
}
"""
    # Translate the one fixed firmware argument, never variable-based paths such
    # as $fixture/jffs. The bridge is inserted after native entry translation.
    firmware_argument = "= /jffs/addons/CFMgr.d:launch"
    assert callbacks.count(firmware_argument) == 1
    callbacks = callbacks.replace(
        firmware_argument,
        "= " + shlex.quote(str(fixture / "jffs/addons/CFMgr.d") + ":launch"),
        1,
    )
    return header + callbacks + cleanup + state


def prepare_retained_entry(fixture: Path, adapter: Path, storage_alias: Path) -> str:
    """Translate firmware paths once, then inject the already rooted callbacks."""
    support = fixture / "jffs/addons/CFMgr.d"
    entry = fixture / "jffs/scripts/cfmgr.sh"
    ram = fixture / "native/tmp/private-ram"
    source = adapt_native(
        entry.read_text(), fixture / "jffs", {"sh": str(ram / "ash")}, []
    )
    anchor = '\n\t. "$cfmgr_source/modules/lib/logging.sh" || exit 1\n'
    assert source.count(anchor) == 1
    bridge = retained_entry_bridge(fixture, adapter, storage_alias)
    entry.write_text(source.replace(anchor, anchor + bridge, 1))
    verifier = support / "modules/lib/package.sh"
    verifier.write_text(verifier.read_text().replace("/jffs", str(fixture / "jffs")))
    finish_package(entry, support, {"sh": str(ram / "ash")}, [])
    return bridge


def retained_entry_journey(
    fixture_arg: str, adapter_arg: str, alias_arg: str, mode: str = "repair"
) -> None:
    """Run inside the already admitted private Linux PID/mount namespace."""
    fixture = Path(fixture_arg)
    support = fixture / "jffs/addons/CFMgr.d"
    entry = fixture / "jffs/scripts/cfmgr.sh"
    ram = fixture / "native/tmp/private-ram"
    assert mode in {"repair", "healthy"}
    if mode == "repair":
        prepare_retained_entry(fixture, Path(adapter_arg), Path(alias_arg))
    receipt = fixture / "entry.receipt"
    receipt.write_text("")
    receipt.chmod(0o600)
    operations = fixture / "opt/operations"
    before_operations = operations.read_bytes() if operations.exists() else b""
    queries = ram / "retained-dns-queries"
    before_queries = queries.read_bytes() if queries.exists() else b""
    master, slave = pty.openpty()
    try:
        child = subprocess.Popen(
            [str(ram / "ash"), str(entry)],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=os.environ.copy(),
        )
        # Enter and leave Advanced options twice, proving terminal input survives
        # native FD0 replacement and redraws do not repeat the admission child.
        os.write(master, b"ao\ne\nao\ne\ne\n")
        try:
            out, err = child.communicate(timeout=190)
        except subprocess.TimeoutExpired:
            child.kill()
            child.communicate()
            raise
    finally:
        os.close(master)
        os.close(slave)
    sys.stdout.buffer.write(out)
    sys.stderr.buffer.write(err)
    assert child.returncode == 0, (out, err)
    assert out.count(b"CFMgr main menu\n") == 3, (out, err)
    assert out.count(b"Advanced options: other actions unavailable\n") == 2
    dns = "verified" if mode == "repair" else "deferred"
    assert out.count(f"shared dependencies verified; tunnel DNS {dns}".encode()) == 1
    assert b"operational admission unavailable" not in err, err
    query_log = queries.read_bytes()
    assert query_log.startswith(before_queries)
    query_types = [
        line.split()[1] for line in query_log[len(before_queries) :].splitlines()
    ]
    assert b"SRV" in query_types, query_log
    if mode == "repair":
        assert b"A" in query_types, query_log
    rows = receipt.read_text().splitlines()
    probes = [row for row in rows if row.startswith("probe ")]
    cleanups = [row for row in rows if row.startswith("cleanup ")]
    if mode == "repair":
        assert probes == ["probe 1 1", "probe 2 0"], rows
        assert cleanups and set(cleanups) == {"cleanup 0 repaired released released"}, (
            rows
        )
        assert operations.read_text() == "update\ninstall flock\n"
    else:
        assert probes == ["probe 1 0"], rows
        assert cleanups == ["cleanup 0 none none none"], rows
        assert operations.read_bytes() == before_operations
    assert (fixture / "retained.original").read_bytes() == (
        support / "config"
    ).read_bytes()
    assert not (ram / "dependencies").exists()
    print(
        "PASS: installed PTY admission, actual repair/post-probes and reusable menu input"
    )


def test_retained_entry_bridge_syntax_and_real_consumer_boundary(
    retained_adapter: Path,
    retained_package: Path,
    selected_shell: list[str],
    tmp_path: Path,
) -> None:
    # Also assemble the final entry on hosts without Linux mount namespaces: an
    # otherwise syntax-valid second /jffs translation used to corrupt callbacks.
    fixture = tmp_path / "fixture with spaces"
    support = fixture / "jffs/addons/CFMgr.d"
    entry = fixture / "jffs/scripts/cfmgr.sh"
    shutil.copytree(retained_package / "modules", support / "modules")
    entry.parent.mkdir(parents=True)
    shutil.copy2(retained_package / "cfmgr.sh", entry)
    bridge = prepare_retained_entry(fixture, retained_adapter, tmp_path / "alias")
    source = entry.read_text()
    assert bridge in source
    assert "cfmgr_install_jffs=$fixture/jffs" in bridge
    assert '[ "$4:$5:$6" = /:/bin/sh:/usr/bin/env ]' in bridge
    assert source.count(str(fixture / "jffs/scripts/cfmgr.sh")) >= 1
    assert str(fixture / "jffs") + str(fixture / "jffs") not in source
    definitions = set(re.findall(r"(?m)^([a-zA-Z_][a-zA-Z_0-9]*)\(\) \{", bridge))
    assert not definitions.intersection(
        {
            "cfmgr_entry_admit",
            "cfmgr_package_verify",
            "cfmgr_launch_native",
            "cfmgr_launch_work",
            "cfmgr_launch_package_structure",
            "cfmgr_launch_package_digests",
            "cfmgr_bootstrap_shared_requirements",
            "cfmgr_prerequisites_run",
            "cfmgr_dependencies_native",
        }
    )
    actual_cleanup = fixture_functions(
        ROOT / "modules/lib/package.sh", ("cfmgr_bootstrap_cleanup",)
    ).replace("cfmgr_bootstrap_cleanup() {", "cfmgr_test_entry_cleanup() {", 1)
    assert actual_cleanup in bridge
    path = tmp_path / "bridge.sh"
    path.write_text(bridge)
    for script in (path, entry, ROOT / "tests/fixtures/retained_launch.sh"):
        result = subprocess.run(
            [*selected_shell, "-n", str(script)],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_retained_entry_carrier_does_not_inherit_directory_stdin(
    shell: list[str], retained_adapter: Path, tmp_path: Path
) -> None:
    # Native setup pins a directory on FD0. Exercise both actual carrier commands
    # without repeating mount/repair setup; the journey assigns its child a PTY.
    source = (ROOT / "tests/fixtures/retained_launch.sh").read_text()
    invocations = re.findall(r'(?m)^if "\$retained_entry_python" .*; then$', source)
    assert len(invocations) == 2
    driver = tmp_path / "carrier.py"
    driver.write_text(
        "import os, runpy, stat, sys\n"
        "assert stat.S_ISCHR(os.fstat(0).st_mode)\n"
        "assert os.fstat(0).st_rdev == os.stat('/dev/null').st_rdev\n"
        "assert sys.stdin.buffer.read() == b''\n"
        # Import the actual generated driver and its complete import closure.
        # Its main guard leaves the Linux-only journey for the native fixture.
        f"driver = runpy.run_path({str(retained_adapter.parent / 'entry.py')!r})\n"
        "assert driver['retained_entry_journey'].__module__ == 'test_retained_launch'\n"
        f"assert sys.modules['tools.package'].__file__ == {str(ROOT / 'tools/package.py')!r}\n"
        "print('carrier stdin is /dev/null')\n"
    )
    commands = "\n".join(
        line.removeprefix("if ").removesuffix("; then") for line in invocations
    )
    script = (
        "set -eu\n"
        "retained_entry_python=$1 retained_entry_driver=$2 fixture=$3\n"
        "dependency_install_adapter=$3 retained_storage_alias=$3\n"
        + commands
        + "\n[ -d /dev/fd/0 ]\n"
    )
    descriptor = os.open(tmp_path, os.O_RDONLY)
    try:
        result = subprocess.run(
            [
                *shell,
                "-c",
                script,
                "carrier-probe",
                sys.executable,
                str(driver),
                "fixture with spaces",
            ],
            stdin=descriptor,
            cwd=tmp_path,
            env={"PATH": os.environ.get("PATH", os.defpath), "LC_ALL": "C"},
            capture_output=True,
            check=False,
            timeout=5,
        )
    finally:
        os.close(descriptor)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout == b"carrier stdin is /dev/null\n" * 2
    assert not result.stderr


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
    assert (
        result.stdout.count(
            b"PASS: installed PTY admission, actual repair/post-probes and reusable menu input"
        )
        == 2
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
