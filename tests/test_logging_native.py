"""Native Health-to-capture integration in an owned Linux mount namespace.

The test translates fixed native paths into an owned fixture. Only status data
collection is replaced; reporting, capture, the worker and supervision are real.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
import test_storage_mounts as storage
from test_archive_history import RULE
from test_config_observation import commands, schema2_config
from test_prerequisites import pause_definition
from test_storage_mounts import selected_shell

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["commands", "schema2_config", "selected_shell"]


@pytest.fixture(scope="module")
def native_mount_tools(selected_shell):
    if sys.platform != "linux":
        pytest.skip("Linux mount namespaces and /proc are required")
    tools = {}
    for name in (
        "sudo",
        "unshare",
        "timeout",
        "truncate",
        "mkfs.ext4",
        "losetup",
        "mount",
        "umount",
        "mountpoint",
        "blkid",
        "readlink",
        "awk",
        "openssl",
        "cmp",
        "stat",
        "id",
    ):
        tools[name] = shutil.which(name)
        assert tools[name], f"Required Linux native fixture tool is missing: {name}"
    probe = subprocess.run(
        [
            tools["sudo"],
            "-n",
            tools["unshare"],
            "--mount",
            "--propagation",
            "private",
            "/bin/true",
        ],
        check=False,
        capture_output=True,
        timeout=10,
    )
    assert probe.returncode == 0, probe.stderr.decode(errors="replace")
    return selected_shell, tools["readlink"], tools["awk"], tools["timeout"]


# Longest first and placeholders ensure a fixture path containing /tmp is not
# accidentally translated a second time. The fixed paths remain explicit.
TOOLS = {
    "/usr/sbin/openssl": "openssl",
    "/usr/bin/cmp": "cmp",
    "/usr/bin/readlink": "readlink",
    "/usr/bin/printf": "printf",
    "/usr/bin/flock": "flock",
    "/usr/bin/awk": "awk",
    "/usr/bin/env": "env",
    "/usr/bin/wc": "wc",
    "/bin/mkdir": "mkdir",
    "/bin/rmdir": "rmdir",
    "/bin/sleep": "sleep",
    "/bin/cat": "cat",
    "/bin/date": "date",
    "/bin/dd": "dd",
    "/bin/ls": "ls",
    "/bin/rm": "rm",
    "/bin/sh": "sh",
}


def native_template(path: Path, *, observe_report: bool = False) -> str:
    source = path.read_text()
    if observe_report:
        entry = "cfmgr_log_health() {\n"
        assert source.count(entry) == 1
        source = source.replace(
            entry,
            entry
            + '    /usr/bin/cmp -s "$1" "$cfmgr_test_transcript" || return 1\n'
            + '    /bin/cp "$1" "$cfmgr_test_report_copy" || return 1\n'
            + '    printf "observed\\n" >>"$cfmgr_test_observation"\n',
            1,
        )
        phases = (
            "run",
            "prepare",
            "capture_work",
            "read_config",
            "select_destination",
            "stage_events",
            "stage_report",
            "open_output",
            "write_fd",
            "health_open",
            "lock",
            "attached",
            "observe_mount",
            "walk_destination",
        )
        metric_names = phases
        wrappers = []
        for phase in phases:
            function = f"cfmgr_log_{phase}"
            original = f"{function}() {{"
            assert source.count(original) == 1
            source = source.replace(original, f"cfmgr_test_original_{phase}() {{", 1)
            mode = '"${1:-unknown}"' if phase == "run" else '"-"'
            reset = ""
            if phase == "prepare":
                reset = "\n".join(
                    f"    cfmgr_test_elapsed_{tracked}=0 cfmgr_test_calls_{tracked}=0"
                    for tracked in metric_names
                )
                reset += (
                    '\n    if [ -n "${cfmgr_test_phase_trace:-}" ]; then '
                    "printf 'capture-start\\n' >>\"$cfmgr_test_phase_trace\" || :; fi\n"
                )
            summary = ""
            if phase == "capture_work":
                fields = " ".join(
                    f"{name}=${{cfmgr_test_elapsed_{name}:-0}}/${{cfmgr_test_calls_{name}:-0}}"
                    for name in metric_names
                )
                summary = (
                    '    if [ -n "${cfmgr_test_phase_trace:-}" ]; then\n'
                    f'        printf \'%s\\n\' "capture-timing-inclusive cs/calls {fields}" >>"$cfmgr_test_phase_trace" || :\n'
                    "    fi\n"
                )
            trace = (
                ""
                if phase == "attached"
                else f'    cfmgr_test_trace {phase} {mode} "$cfmgr_test_result_{phase}"\n'
            )
            wrappers.append(
                f"{function}() {{\n"
                + reset
                + "    cfmgr_test_clock || cfmgr_test_clock_value=0\n"
                + f"    cfmgr_test_started_{phase}=$cfmgr_test_clock_value\n"
                + f'    if cfmgr_test_original_{phase} "$@"; then cfmgr_test_result_{phase}=0; '
                + f"else cfmgr_test_result_{phase}=$?; fi\n"
                + "    cfmgr_test_clock || cfmgr_test_clock_value=0\n"
                + f"    cfmgr_test_ended_{phase}=$cfmgr_test_clock_value\n"
                + f"    cfmgr_test_elapsed_{phase}=$((cfmgr_test_elapsed_{phase} + cfmgr_test_ended_{phase} - cfmgr_test_started_{phase}))\n"
                + f"    cfmgr_test_calls_{phase}=$((cfmgr_test_calls_{phase} + 1))\n"
                + trace
                + summary
                + f'    return "$cfmgr_test_result_{phase}"\n}}'
            )
        source += r"""
cfmgr_test_trace() {
    [ "${cfmgr_test_trace_count:-0}" -lt 512 ] || return 0
    cfmgr_test_trace_count=$((${cfmgr_test_trace_count:-0} + 1))
    case $2 in -) cfmgr_test_mode=- ;; diagnostic-*)
        case $2 in *[!a-z0-9._-]*) cfmgr_test_mode=unknown ;; *) cfmgr_test_mode=$2 ;; esac ;;
        *) cfmgr_test_mode=unknown ;;
    esac
    case ${cfmgr_probe_status:-} in invalid|reaped|unresolved) cfmgr_test_status=$cfmgr_probe_status ;; *) cfmgr_test_status=- ;; esac
    case ${cfmgr_probe_reason:-} in arguments|native-supervisor|attachment|lock-inheritance|clock|deadline|child-signal) cfmgr_test_reason=$cfmgr_probe_reason ;; *) cfmgr_test_reason=- ;; esac
    case ${cfmgr_probe_exit:-} in ''|*[!0-9]*) cfmgr_test_exit=- ;; *)
        if [ "${#cfmgr_probe_exit}" -le 3 ]; then cfmgr_test_exit=$cfmgr_probe_exit; else cfmgr_test_exit=-; fi ;;
    esac
    printf '%s mode=%s code=%s probe=%s reason=%s exit=%s\n' "$1" "$cfmgr_test_mode" "$3" "$cfmgr_test_status" "$cfmgr_test_reason" "$cfmgr_test_exit" >>"$cfmgr_test_phase_trace" || :
}
"""
        source += r"""
cfmgr_test_clock() {
    cfmgr_test_clock_seconds= cfmgr_test_clock_fraction= cfmgr_test_clock_idle=
    IFS='. ' read -r cfmgr_test_clock_seconds cfmgr_test_clock_fraction cfmgr_test_clock_idle </proc/uptime || return 1
    case $cfmgr_test_clock_seconds in ''|*[!0-9]*) return 1 ;; esac
    while [ "${#cfmgr_test_clock_seconds}" -gt 1 ] && [ "${cfmgr_test_clock_seconds#0}" != "$cfmgr_test_clock_seconds" ]; do
        cfmgr_test_clock_seconds=${cfmgr_test_clock_seconds#0}
    done
    case $cfmgr_test_clock_fraction in [0-9]) cfmgr_test_clock_fraction=0$cfmgr_test_clock_fraction ;;
        [0-9][0-9]) ;; *) return 1 ;;
    esac
    case $cfmgr_test_clock_fraction in 0[0-9]) cfmgr_test_clock_fraction=${cfmgr_test_clock_fraction#0} ;;
        [1-9][0-9]) ;; *) return 1 ;;
    esac
    cfmgr_test_clock_value=$((cfmgr_test_clock_seconds * 100 + cfmgr_test_clock_fraction))
}
"""
        source += "\n".join(wrappers) + "\n"
    source = source.replace("/tmp/mnt/?* | /mnt/?*", "CFMGR_FIXTURE_MOUNT_MARKER")
    source = source.replace("/tmp", "CFMGR_FIXTURE_RAM_MARKER")
    source = source.replace("/opt", "CFMGR_FIXTURE_OPT_MARKER")
    for path_text, applet in TOOLS.items():
        marker = f"CFMGR_FIXTURE_TOOL_{applet.upper()}_MARKER"
        if path_text == "/bin/sh":
            source = re.sub(r"/bin/sh(?=$|[ \t\r\n\"';):}])", marker, source)
        else:
            source = source.replace(path_text, marker)
    return source


def build_fixture(test_shell, tmp_path):
    host_tools = {}
    for default, name in TOOLS.items():
        path = default if name in ("sh", "printf") else shutil.which(name) or default
        if sys.platform == "linux":
            assert os.path.isfile(path) and os.access(path, os.X_OK), (
                f"Required Linux native fixture tool is missing: {name}"
            )
        host_tools[name] = path
    host_links = "\n".join(
        f'        ln -s {shlex.quote(path)} "$fixture/bin/{name}"'
        for name, path in host_tools.items()
    )
    templates = tmp_path / "templates"
    templates.mkdir()
    source_files = {
        "storage": ROOT / "modules/lib/storage.sh",
        "execution": ROOT / "modules/lib/execution.sh",
        "config": ROOT / "modules/lib/config.sh",
        "logging": ROOT / "modules/lib/logging.sh",
        "status": ROOT / "modules/status.sh",
        "backup": ROOT / "modules/backup.sh",
        "worker": ROOT / "modules/helpers/worker.sh",
    }
    for name, path in source_files.items():
        (templates / name).write_text(
            native_template(path, observe_report=name == "logging")
        )

    fixture_text = storage.FIXTURE.read_text()
    failure_entry = "fail() {\n"
    assert fixture_text.count(failure_entry) == 1
    fixture_text = fixture_text.replace(
        failure_entry,
        failure_entry
        + """\tcase $case_name in diagnostic_health|diagnostic_scribe)
        if [ -n "${cfmgr_test_transcript:-}" ] && [ -f "$cfmgr_test_transcript" ]; then
            printf 'fixture Health transcript (bounded):\\n' >&2
            head -c 16384 "$cfmgr_test_transcript" >&2 || :
        fi
        if [ -n "${cfmgr_test_phase_trace:-}" ] && [ -f "$cfmgr_test_phase_trace" ]; then
            printf 'fixture capture phases (bounded):\\n' >&2
            head -c 65536 "$cfmgr_test_phase_trace" >&2 || :
        fi ;;
    esac
""",
        1,
    )
    original_allowlist = "valid | alias_substitution | lazy_replacement | bind_identity | ro_noexec | backup_folder"
    assert fixture_text.count(original_allowlist) == 1
    fixture_text = fixture_text.replace(
        original_allowlist,
        "valid | alias_substitution | lazy_replacement | bind_identity | ro_noexec | diagnostic_health | backup_folder",
        1,
    )
    unmount = 'if mountpoint -q "$bind_dir"; then'
    assert fixture_text.count(unmount) == 1
    fixture_text = fixture_text.replace(
        unmount,
        'if [ "$case_name" = diagnostic_health ] && mountpoint -q "$fixture/ram"; then\n'
        '        umount "$fixture/ram" || cleanup_issue "could not unmount owned diagnostic RAM"\n'
        "    fi\n\t" + unmount,
        1,
    )
    branch = r"""
diagnostic_health)
    mkdir -m 700 "$fixture/ram" "$fixture/bin" "$fixture/source"
    mkdir -p "$fixture/source/modules/lib" "$fixture/source/modules/helpers"
    mount -t tmpfs -o size=8m,mode=700 tmpfs "$fixture/ram" || fail 'private RAM mount failed'
    cfmgr_test_phase_trace=$fixture/ram/phase-trace
    (umask 077; : >"$cfmgr_test_phase_trace") || fail 'phase trace setup failed'
    mount -o remount,noexec "$mount_dir" || fail 'noexec data remount failed'
    case $view_busybox in
    */busybox)
        for applet in sh awk dd date cmp ls readlink wc env sleep flock mkdir rmdir rm cat printf; do ln -s "$view_busybox" "$fixture/bin/$applet"; done
        ln -s OPENSSL_PATH "$fixture/bin/openssl"
        ;;
    *)
HOST_LINKS
        ;;
    esac
    render_template() {
        sed -e "s@CFMGR_FIXTURE_MOUNT_MARKER@$fixture/?*@g" \
            -e "s@CFMGR_FIXTURE_RAM_MARKER@$fixture/ram@g" \
            -e "s@CFMGR_FIXTURE_OPT_MARKER@$fixture/opt@g" \
            -e "s@CFMGR_FIXTURE_TOOL_OPENSSL_MARKER@$fixture/bin/openssl@g" \
            -e "s@CFMGR_FIXTURE_TOOL_CMP_MARKER@$fixture/bin/cmp@g" \
            -e "s@CFMGR_FIXTURE_TOOL_READLINK_MARKER@$fixture/bin/readlink@g" \
            -e "s@CFMGR_FIXTURE_TOOL_PRINTF_MARKER@$fixture/bin/printf@g" \
            -e "s@CFMGR_FIXTURE_TOOL_FLOCK_MARKER@$fixture/bin/flock@g" \
            -e "s@CFMGR_FIXTURE_TOOL_AWK_MARKER@$fixture/bin/awk@g" \
            -e "s@CFMGR_FIXTURE_TOOL_ENV_MARKER@$fixture/bin/env@g" \
            -e "s@CFMGR_FIXTURE_TOOL_WC_MARKER@$fixture/bin/wc@g" \
            -e "s@CFMGR_FIXTURE_TOOL_MKDIR_MARKER@$fixture/bin/mkdir@g" \
            -e "s@CFMGR_FIXTURE_TOOL_RMDIR_MARKER@$fixture/bin/rmdir@g" \
            -e "s@CFMGR_FIXTURE_TOOL_SLEEP_MARKER@$fixture/bin/sleep@g" \
            -e "s@CFMGR_FIXTURE_TOOL_CAT_MARKER@$fixture/bin/cat@g" \
            -e "s@CFMGR_FIXTURE_TOOL_DATE_MARKER@$fixture/bin/date@g" \
            -e "s@CFMGR_FIXTURE_TOOL_DD_MARKER@$fixture/bin/dd@g" \
            -e "s@CFMGR_FIXTURE_TOOL_LS_MARKER@$fixture/bin/ls@g" \
            -e "s@CFMGR_FIXTURE_TOOL_RM_MARKER@$fixture/bin/rm@g" \
            -e "s@CFMGR_FIXTURE_TOOL_SH_MARKER@$fixture/bin/sh@g" "$1" >"$2"
    }
    render_template "TEMPLATE_DIR/storage" "$fixture/source/modules/lib/storage.sh"
    render_template "TEMPLATE_DIR/execution" "$fixture/source/modules/lib/execution.sh"
    render_template "TEMPLATE_DIR/config" "$fixture/source/modules/lib/config.sh"
    render_template "TEMPLATE_DIR/logging" "$fixture/source/modules/lib/logging.sh"
    render_template "TEMPLATE_DIR/status" "$fixture/source/modules/status.sh"
    render_template "TEMPLATE_DIR/backup" "$fixture/source/modules/backup.sh"
    render_template "TEMPLATE_DIR/worker" "$fixture/source/modules/helpers/worker.sh"
    chmod 755 "$fixture/source/modules/helpers/worker.sh"
    cfmgr_source=$fixture/source CFMGR_VERSION=0.1.0 cfmgr_log_available=1
    . "$cfmgr_source/modules/lib/storage.sh"
    . "$cfmgr_source/modules/lib/execution.sh"
    . "$cfmgr_source/modules/lib/config.sh"
    . "$cfmgr_source/modules/lib/logging.sh"
    . "$cfmgr_source/modules/status.sh"
    PAUSE_DEFINITION
    assert_diagnostic_cleanup() {
        diagnostic_root=$fixture/ram/cfmgr-diagnostics
        [ -e "$diagnostic_root" ] || [ -L "$diagnostic_root" ] || return 0
        [ -d "$diagnostic_root" ] && [ ! -L "$diagnostic_root" ] &&
            [ "$(stat -c '%u:%a' "$diagnostic_root")" = '0:700' ] || fail 'unsafe diagnostic RAM root'
        for retained in "$diagnostic_root"/* "$diagnostic_root"/.[!.]* "$diagnostic_root"/..?*; do
            [ -e "$retained" ] || [ -L "$retained" ] || continue
            [ "$retained" = "$diagnostic_root/capture.lock" ] && [ -f "$retained" ] && [ ! -L "$retained" ] &&
                [ "$(stat -c '%u:%a:%h' "$retained")" = '0:600:1' ] || fail 'unexpected diagnostic RAM artifact'
        done
    }
    cfmgr_status_work() { printf 'fixture-router-ready\nResources: isolated fixture\n'; }
    cfmgr_health_collect() { cfmgr_health_row fixture.capture PASS 'isolated native capture' current None report; }
    mkdir -m 755 "$mount_dir/CFMgr"
    mkdir -m 700 "$mount_dir/CFMgr/backup" "$mount_dir/CFMgr/foreign"
    printf 'backup sentinel\n' >"$mount_dir/CFMgr/backup/keep"
    printf 'foreign sentinel\n' >"$mount_dir/CFMgr/foreign/keep"
    printf '{"schema":2,"generation":1,"manager":{"developer":false,"developer_log_directory":"%s"}}\n' \
        "$mount_dir/CFMgr/diagnostics" >"$cfmgr_source/config"
    chmod 600 "$cfmgr_source/config"
    cp "$cfmgr_source/config" "$fixture/config-before"
    config_metadata=$(stat -c '%i %a %u %g %h %s' "$cfmgr_source/config")
    cfmgr_test_transcript=$fixture/transcript-one cfmgr_test_observation=$fixture/observed-one cfmgr_test_report_copy=$fixture/report-one
    if cfmgr_status_health_native >"$cfmgr_test_transcript"; then :; else fail 'first Health failed'; fi
    grep -Fq 'fixture-router-ready' "$cfmgr_test_transcript" || fail 'first terminal report absent'
    grep -Fq '[CFMGR] capture.saved PASS' "$cfmgr_test_transcript" || fail 'first capture not saved'
    [ -s "$cfmgr_test_observation" ] || fail 'report was not observed before capture'
    set -- "$mount_dir"/CFMgr/diagnostics/health-*.log
    [ "$#" -eq 1 ] && [ -f "$1" ] || fail 'expected one saved health report'
    grep -Fq 'fixture-router-ready' "$1" || fail 'saved report absent'
    grep -Fq 'CFMGR-EVENT 1' "$1" || fail 'saved run event absent'
    grep -Fq 'CFMGR-CAPTURE 1' "$1" || fail 'saved capture header absent'
    tail -c "$(wc -c <"$fixture/report-one")" "$1" | cmp -s - "$fixture/report-one" || fail 'saved report differs from rendered report'
    [ ! -e "$mount_dir/CFMgr/diagnostics/developer.log" ] || fail 'developer-Off wrote developer.log'
    cmp -s "$fixture/config-before" "$cfmgr_source/config" || fail 'first Health changed config'
    [ "$(stat -c '%i %a %u %g %h %s' "$cfmgr_source/config")" = "$config_metadata" ] || fail 'first Health changed config metadata'
    [ "$(cat "$mount_dir/CFMgr/backup/keep")" = 'backup sentinel' ] || fail 'backup sibling changed'
    ln -s "$mount_dir/CFMgr/foreign" "$mount_dir/CFMgr/unsafe"
    printf '{"schema":2,"generation":2,"manager":{"developer":false,"developer_log_directory":"%s"}}\n' \
        "$mount_dir/CFMgr/unsafe/capture" >"$cfmgr_source/config"
    chmod 600 "$cfmgr_source/config"
    cp "$cfmgr_source/config" "$fixture/config-unsafe"
    config_metadata=$(stat -c '%i %a %u %g %h %s' "$cfmgr_source/config")
    cfmgr_test_transcript=$fixture/transcript-two cfmgr_test_observation=$fixture/observed-two cfmgr_test_report_copy=$fixture/report-two
    if cfmgr_status_health_native >"$cfmgr_test_transcript"; then :; else fail 'second Health failed'; fi
    grep -Fq 'fixture-router-ready' "$cfmgr_test_transcript" || fail 'second terminal report absent'
    grep -Fq '[CFMGR] capture.saved SKIP' "$cfmgr_test_transcript" || fail 'unsafe capture not refused'
    [ -s "$cfmgr_test_observation" ] || fail 'second report was not observed before capture'
    set -- "$mount_dir"/CFMgr/diagnostics/health-*.log
    [ "$#" -eq 1 ] && [ -f "$1" ] || fail 'unsafe destination triggered fallback capture'
    [ ! -e "$mount_dir/CFMgr/foreign/capture" ] || fail 'foreign symlink target changed'
    [ "$(cat "$mount_dir/CFMgr/foreign/keep")" = 'foreign sentinel' ] || fail 'foreign sibling changed'
    cmp -s "$fixture/config-unsafe" "$cfmgr_source/config" || fail 'second Health changed config'
    [ "$(stat -c '%i %a %u %g %h %s' "$cfmgr_source/config")" = "$config_metadata" ] || fail 'second Health changed config metadata'
    for retained in "$fixture"/ram/cfmgr-status.*; do
        [ ! -e "$retained" ] && [ ! -L "$retained" ] || fail 'owned RAM context was retained'
    done
    assert_diagnostic_cleanup
    fixture_children=''
    IFS= read -r fixture_children <"/proc/$$/task/$$/children" || :
    [ -z "$fixture_children" ] || fail 'owned child still active after Health'
    printf 'PASS: native Health capture, report ordering, developer-Off and unsafe destination\n'
    ;;
"""
    branch = branch.replace("OPENSSL_PATH", shlex.quote(host_tools["openssl"]))
    branch = branch.replace("HOST_LINKS", host_links)
    branch = branch.replace("TEMPLATE_DIR", str(templates))
    branch = branch.replace("PAUSE_DEFINITION", pause_definition(test_shell))
    marker = "\nbackup_folder | backup_replacement | archive_source)"
    assert fixture_text.count(marker) == 1
    fixture_text = fixture_text.replace(marker, "\n" + branch + marker, 1)
    fixture = tmp_path / "native-fixture.sh"
    fixture.write_text(fixture_text)
    fixture.chmod(0o700)
    return fixture


def test_native_fixture_shell_syntax(selected_shell, tmp_path):
    fixture = build_fixture(selected_shell, tmp_path)
    source = fixture.read_text()
    assert "command -v" not in source
    assert 'ln -s "$view_busybox" "$fixture/bin/$applet"' in source
    for name in TOOLS.values():
        assert f'"$fixture/bin/{name}"' in source
    result = subprocess.run(
        [*selected_shell, "-n", str(fixture)],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_template_does_not_translate_shell_prefix_inside_other_tool(tmp_path):
    source = tmp_path / "source.sh"
    source.write_text('tool=/opt/bin/sha256sum\nexec /bin/sh "$script"\n')
    adapted = native_template(source)
    assert "CFMGR_FIXTURE_OPT_MARKER/bin/sha256sum" in adapted
    assert "exec CFMGR_FIXTURE_TOOL_SH_MARKER" in adapted


@pytest.mark.parametrize("destination", ["auto", "custom"])
def test_linux_health_capture_on_private_noexec_data_mount(
    native_mount_tools, tmp_path, monkeypatch, destination
):
    fixture = build_fixture(native_mount_tools[0], tmp_path)
    # Exercise both boot-UUID alphabets deterministically at the filename
    # boundary; the supervisor still uses the real kernel boot identity.
    name_boot = (
        "01234567-89ab-cdef-0123-456789abcdef"
        if destination == "auto"
        else "abcdef01-2345-6789-abcd-ef0123456789"
    )
    logging_template = tmp_path / "templates/logging"
    template = logging_template.read_text()
    opener = "cfmgr_test_original_health_open() {\n"
    assert template.count(opener) == 1
    logging_template.write_text(
        template.replace(opener, opener + f"    cfmgr_log_boot={name_boot}\n", 1)
    )
    script = fixture.read_text()
    saved_check = (
        '[ "$#" -eq 1 ] && [ -f "$1" ] || fail \'expected one saved health report\''
    )
    assert script.count(saved_check) == 1
    script = script.replace(
        saved_check,
        saved_check
        + f'\n    case "${{1##*/}}" in health-{name_boot}-*) ;; '
        + "*) fail 'saved health UUID prefix changed' ;; esac",
        1,
    )
    if destination == "auto":
        preference = '"developer":false,"developer_log_directory":"%s"'
        assert script.count(preference) == 2
        script = script.replace(
            preference, '"developer":false,"developer_log_directory":null', 1
        )
        script = script.replace(
            '        "$mount_dir/CFMgr/diagnostics" >"$cfmgr_source/config"',
            '        >"$cfmgr_source/config"',
            1,
        )
    fixture.write_text(script)
    workdir = tmp_path / "work"
    workdir.mkdir(mode=0o700)
    monkeypatch.setattr(storage, "FIXTURE", fixture)
    result = storage.run_fixture(native_mount_tools, "diagnostic_health", workdir)
    storage.assert_fixture_passed(result, "diagnostic_health")


def test_linux_developer_scribe_capture_survives_rotation(
    native_mount_tools, schema2_config, tmp_path, monkeypatch
):
    """Real owned source logs remain sanitized and prior snapshots persist."""
    fixture = build_fixture(native_mount_tools[0], tmp_path)
    templates = tmp_path / "templates"
    config = json.loads(schema2_config)
    config["manager"]["developer"] = True
    config["manager"]["developer_log_directory"] = "CFMGR_FIXTURE_DEST_MARKER"
    config["ownership"]["components"] = []
    source_text = {
        "ddns": b"[CFMGR] DDNS: Info: IPv4 updated: 203.0.113.10\n",
        "ip_sync": b"[CFMGR] IP-Sync: Warning: Rate limited; retry in 5m\n",
        "cloudflared": (
            b'{"level":"info","time":"2025-01-02T03:04:05Z",'
            b'"message":"Starting tunnel","token":"SCRIBE-SECRET-CANARY"}\n'
        ),
    }
    for role, content in source_text.items():
        name = "ip-sync" if role == "ip_sync" else role
        rule = RULE.replace("ddns", name)
        if role == "cloudflared":
            rule = (
                rule.replace("size 7M", "daily")
                .replace("maxsize 0", "maxsize 10M")
                .replace("rotate 2", "rotate 4")
                .replace("maxage 0", "maxage 30")
            )
            policy = {
                "schema": 1,
                "mode": "daily",
                "size": {"value": 10, "unit": "MiB"},
                "total_files": 5,
                "max_age_days": 30,
            }
        else:
            policy = {"schema": 1, "version": 1}
        config["logging"][role].update(
            configured=True, enabled=False, opt_out=True, policy=policy
        )
        rule_bytes = rule.encode()
        (templates / f"rule-{name}").write_bytes(rule_bytes)
        (templates / f"log-{name}").write_bytes(content)
        for component, path, data in (
            (f"history.{role}", f"/var/log/{name}.log", content),
            (f"history-rule.{role}", f"/etc/logrotate.d/cfmgr-{name}", rule_bytes),
        ):
            config["ownership"]["components"].append(
                {
                    "schema": 1,
                    "component": component,
                    "path": "CFMGR_FIXTURE_OPT_MARKER" + path,
                    "generation": 1,
                    "sha256": hashlib.sha256(data).hexdigest(),
                }
            )
    (templates / "log-ddns-retained").write_bytes(
        b"[CFMGR] DDNS: Info: IPv4 updated: 203.0.113.11\n"
    )
    (templates / "scribe-config").write_text(json.dumps(config, separators=(",", ":")))
    fixture_text = fixture.read_text()
    allow = "ro_noexec | diagnostic_health | backup_folder"
    assert fixture_text.count(allow) == 1
    fixture_text = fixture_text.replace(
        allow, "ro_noexec | diagnostic_health | diagnostic_scribe | backup_folder", 1
    )
    cleanup = '[ "$case_name" = diagnostic_health ] && mountpoint -q "$fixture/ram"'
    assert fixture_text.count(cleanup) == 1
    fixture_text = fixture_text.replace(
        cleanup,
        '{ [ "$case_name" = diagnostic_health ] || [ "$case_name" = diagnostic_scribe ]; } && mountpoint -q "$fixture/ram"',
        1,
    )
    health_branch = fixture_text.split("\ndiagnostic_health)\n", 1)[1]
    common = health_branch.split("    cfmgr_status_work()", 1)[0]
    branch = r"""
diagnostic_scribe)
COMMON_SETUP
    mkdir -p "$mount_dir/entware/etc/logrotate.d" "$mount_dir/entware/var/log" "$mount_dir/CFMgr/backup"
    chmod 755 "$mount_dir/CFMgr"
    printf 'backup sentinel\n' >"$mount_dir/CFMgr/backup/keep"
    for role in ddns ip-sync cloudflared; do
        cp "TEMPLATE_DIR/rule-$role" "$mount_dir/entware/etc/logrotate.d/cfmgr-$role"
        cp "TEMPLATE_DIR/log-$role" "$mount_dir/entware/var/log/$role.log"
        chmod 600 "$mount_dir/entware/etc/logrotate.d/cfmgr-$role" "$mount_dir/entware/var/log/$role.log"
    done
    cp "TEMPLATE_DIR/log-ddns-retained" "$mount_dir/entware/var/log/ddns.log.1"
    chmod 600 "$mount_dir/entware/var/log/ddns.log.1"
    sed -e "s@CFMGR_FIXTURE_OPT_MARKER@$fixture/opt@g" \
        -e "s@CFMGR_FIXTURE_DEST_MARKER@$mount_dir/CFMgr/diagnostics@g" \
        "TEMPLATE_DIR/scribe-config" >"$cfmgr_source/config"
    chmod 600 "$cfmgr_source/config"
    mkdir -m 700 "$mount_dir/CFMgr/diagnostics"
    printf 'CFMGR-DEVELOPER 1\n' >"$mount_dir/CFMgr/diagnostics/developer.log"
    history_index=0
    while [ "$history_index" -lt 150 ]; do
        printf 'CFMGR-EVENT 1 unknown manager startup success 0\n' >>"$mount_dir/CFMgr/diagnostics/developer.log"
        history_index=$((history_index + 1))
    done
    chmod 600 "$mount_dir/CFMgr/diagnostics/developer.log"
    cp "$mount_dir/CFMgr/diagnostics/developer.log" "$fixture/developer-before"
    history_bytes=$(wc -c <"$fixture/developer-before")
    [ "$history_bytes" -gt 4096 ] || fail 'existing history fixture is too small'
    cp "$cfmgr_source/config" "$fixture/config-before"
    config_metadata=$(stat -c '%i %a %u %g %h %s' "$cfmgr_source/config")
    event='CFMGR-EVENT 1 unknown manager startup success 0'
    if capture_result=$(cfmgr_log_capture developer "$event"); then :; else fail 'first developer capture failed'; fi
    case $capture_result in 'CFMGR-LOG-CAPTURE 1 saved read '*) ;; *) fail "first capture incomplete: $capture_result" ;; esac
    destination=$mount_dir/CFMgr/diagnostics
    [ -f "$destination/developer.log" ] || fail 'developer log missing'
    [ "$(wc -c <"$destination/developer.log")" -gt "$history_bytes" ] || fail 'existing developer log did not grow'
    head -c "$history_bytes" "$destination/developer.log" | cmp -s - "$fixture/developer-before" || fail 'existing developer history changed'
    grep -Fq 'CFMGR-SCRIBE-RESULT 1 4 0 0 0 END' "$destination/developer.log" || fail 'four owned sources were not captured'
    set -- "$destination"/scribe-*.log
    [ "$#" -eq 4 ] && [ -f "$1" ] || fail 'expected four initial Scribe snapshots'
    grep -Fq 'IPv4 updated: 203.0.113.10' "$destination"/scribe-*-ddns-current-*.log || fail 'current DDNS event missing'
    grep -Fq 'IPv4 updated: 203.0.113.11' "$destination"/scribe-*-ddns-1-*.log || fail 'retained DDNS event missing'
    grep -Fq 'Rate limited; retry in 5m' "$destination"/scribe-*-ip_sync-current-*.log || fail 'IP-Sync event missing'
    grep -Fq 'Starting tunnel' "$destination"/scribe-*-cloudflared-current-*.log || fail 'Cloudflared event missing'
    if grep -R -Fq 'SCRIBE-SECRET-CANARY' "$destination"; then fail 'raw secret reached destination'; fi
    mkdir -m 700 "$fixture/previous"
    for saved; do cp "$saved" "$fixture/previous/${saved##*/}"; done
    mv "$mount_dir/entware/var/log/ddns.log.1" "$mount_dir/entware/var/log/ddns.log.2"
    mv "$mount_dir/entware/var/log/ddns.log" "$mount_dir/entware/var/log/ddns.log.1"
    printf '[CFMGR] DDNS: Info: IPv4 updated: 203.0.113.12\n' >"$mount_dir/entware/var/log/ddns.log"
    chmod 600 "$mount_dir/entware/var/log/ddns.log"
    if capture_result=$(cfmgr_log_capture developer "$event"); then :; else fail 'capture after rotation failed'; fi
    case $capture_result in 'CFMGR-LOG-CAPTURE 1 saved read '*) ;; *) fail "rotation capture incomplete: $capture_result" ;; esac
    grep -Fq 'CFMGR-SCRIBE-RESULT 1 5 0 0 0 END' "$destination/developer.log" || fail 'rotated current and retained logs not captured'
    set -- "$destination"/scribe-*.log
    [ "$#" -eq 9 ] || fail 'rotation did not retain prior and new snapshots'
    for saved in "$fixture"/previous/*; do
        cmp -s "$saved" "$destination/${saved##*/}" || fail 'previous sanitized snapshot changed'
    done
    if grep -R -Fq 'SCRIBE-SECRET-CANARY' "$destination"; then fail 'raw secret reached rotated destination'; fi
    cmp -s "$fixture/config-before" "$cfmgr_source/config" || fail 'developer capture changed config'
    [ "$(stat -c '%i %a %u %g %h %s' "$cfmgr_source/config")" = "$config_metadata" ] || fail 'developer capture changed config metadata'
    [ "$(cat "$mount_dir/CFMgr/backup/keep")" = 'backup sentinel' ] || fail 'backup sibling changed'
    assert_diagnostic_cleanup
    fixture_children=''
    IFS= read -r fixture_children <"/proc/$$/task/$$/children" || :
    [ -z "$fixture_children" ] || fail 'owned child still active after Scribe capture'
    printf 'PASS: owned Scribe capture, secret sanitization and rotation preservation\n'
    ;;
"""
    branch = branch.replace("COMMON_SETUP", common)
    branch = branch.replace("TEMPLATE_DIR", str(templates))
    marker = "\nbackup_folder | backup_replacement | archive_source)"
    assert fixture_text.count(marker) == 1
    fixture_text = fixture_text.replace(marker, "\n" + branch + marker, 1)
    fixture.write_text(fixture_text)
    workdir = tmp_path / "work"
    workdir.mkdir(mode=0o700)
    monkeypatch.setattr(storage, "FIXTURE", fixture)
    # Two independent captures retain their 20-second product deadlines.
    # The combined rotation journey needs both budgets plus fixture cleanup.
    result = storage.run_fixture(
        native_mount_tools, "diagnostic_scribe", workdir, timeout_seconds=45
    )
    storage.assert_fixture_passed(result, "diagnostic_scribe")
