"""Native archive I/O foundation; host adapters do not establish Linux pin proof."""

from __future__ import annotations

import base64
import json
import os
import shlex
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

import pytest
from test_prerequisites import pause_definition
from test_prerequisites import shell as prerequisite_shell

shell = prerequisite_shell
ROOT = Path(__file__).resolve().parents[1]
REQUIRE_BUSYBOX = os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1"


@pytest.fixture
def archive(tmp_path, shell):
    support = tmp_path / "support"
    (support / "modules/lib").mkdir(parents=True)
    (support / "modules/helpers").mkdir()
    ram = tmp_path / "ram"
    ram.mkdir()
    mount = tmp_path / "drive"
    stage = mount / "CFBackup" / "stage"
    stage.mkdir(parents=True)
    for name in ("../backup", "storage", "execution", "config"):
        body = (ROOT / f"modules/lib/{name}.sh").read_text()
        if name == "execution":
            body = body.replace(
                "cfmgr_prerequisites_run() {", "cfmgr_test_real_run() {", 1
            )
        if sys.platform == "darwin":
            # macOS fdescfs cannot traverse retained directory FDs. Only the
            # host data-operation path is adapted; Linux keeps the real pins.
            body = body.replace("/proc/self/fd/5", "${cfmgr_test_ram}").replace(
                "/proc/self/fd/7", "${cfmgr_test_backup}"
            )
        (support / f"modules/lib/{name}.sh").write_text(body)
    body = (ROOT / "modules/helpers/worker.sh").read_text()
    if sys.platform == "darwin":
        body = body.replace(
            '[ "$output" -ef /proc/self/fd/1 ] && [ /proc/self/fd/1 -ef /proc/self/fd/2 ]',
            '[ -f "$output" ]',
        )
        body = body.replace(
            '[ "$3" -ef /proc/self/fd/1 ] && [ /proc/self/fd/1 -ef /proc/self/fd/2 ]',
            '[ -f "$3" ]',
        )
    worker = support / "modules/helpers/worker.sh"
    worker.write_text(body)
    shutil.copymode(ROOT / "modules/helpers/worker.sh", worker)
    tools = {}
    for name in (
        "env",
        "awk",
        "sleep",
        "wc",
        "ls",
        "readlink",
        "openssl",
        "dd",
        "tar",
        "gzip",
        "gunzip",
        "hexdump",
        "date",
        "printf",
    ):
        executable = shutil.which(name)
        assert executable, f"Actual host {name} is required"
        tools[name] = executable
    if REQUIRE_BUSYBOX:
        executable = shutil.which(shell[0])
        assert executable
        applets = tmp_path / "applets"
        applets.mkdir()
        for name in (
            "sh",
            "env",
            "awk",
            "sleep",
            "wc",
            "ls",
            "readlink",
            "dd",
            "tar",
            "gzip",
            "gunzip",
            "hexdump",
            "date",
            "printf",
        ):
            link = applets / name
            link.symlink_to(executable)
            tools[name] = str(link)
    else:
        tools["sh"] = shell[0]
    if sys.platform == "linux":
        tools["flock"] = shutil.which("flock")
        if REQUIRE_BUSYBOX:
            link = tmp_path / "flock"
            link.symlink_to(Path(tools["sh"]).resolve())
            tools["flock"] = str(link)
        assert tools["flock"], "Native flock is required for lock proof"
        # Direct-exec adapters check the real inherited lock, then exec the real
        # host/vendor utility in the same PID. An accidental stdin redirect in
        # any archive mode now fails before performing the requested operation.
        for name in (
            "awk",
            "wc",
            "ls",
            "openssl",
            "dd",
            "tar",
            "gzip",
            "gunzip",
            "hexdump",
            "date",
            "printf",
        ):
            wrapper = tmp_path / f"locked-{name}"
            lock = shlex.quote(str(ram / "lock"))
            lock_check = f"[ /proc/self/fd/0 -ef {lock} ] || exit 91\n"
            if name == "awk":
                # Only JSON modes redirect stdin. Their helper explicitly
                # retains the inherited lock on9; every other tool keeps0.
                lock_check = (
                    "case ${CFMGR_PAYLOAD_MODE:-} in\n"
                    "plan|runtime-json|certificate-json|drafts)\n"
                    f"[ /proc/self/fd/9 -ef {lock} ] || exit 92\n"
                    f"[ ! /proc/self/fd/0 -ef {lock} ] || exit 93\n"
                    f"if [ -f {shlex.quote(str(ram / 'prove-json-lock'))} ]; then\n"
                    f": >{shlex.quote(str(ram / 'json-started'))}\n"
                    "remaining=40\n"
                    f"while [ ! -e {shlex.quote(str(ram / 'json-owner-closed'))} ]; do\n"
                    '[ "$remaining" -gt 0 ] || exit 95\n'
                    "remaining=$((remaining-1)); /bin/sleep 0.05\n"
                    "done\n"
                    f"    (exec 3<>{lock}; {shlex.quote(tools['flock'])} -n 3) && exit 94\n"
                    "fi ;;\n"
                    f"*) {lock_check};;\nesac\n"
                )
            wrapper.write_text(
                "#!/bin/sh\n"
                + lock_check
                + ("case $1 in -*i*) printf '   ' ;; esac\n" if name == "ls" else "")
                + f'exec {shlex.quote(tools[name])} "$@"\n'
            )
            wrapper.chmod(0o700)
            tools[name] = str(wrapper)
    else:
        # Native ls pads small inode numbers. Force that formatting on hosts
        # whose large inode numbers otherwise conceal a parser regression.
        padded_ls = tmp_path / "padded-ls"
        padded_ls.write_text(
            f"#!/bin/sh\ncase $1 in -*i*) printf '   ' ;; esac\nexec {shlex.quote(tools['ls'])} \"$@\"\n"
        )
        padded_ls.chmod(0o700)
        tools["ls"] = str(padded_ls)
    environment = {
        **os.environ,
        **{f"TEST_{key.upper()}": value for key, value in tools.items()},
    }
    environment["TEST_LINUX"] = "1" if sys.platform == "linux" else "0"
    return support, ram, mount, stage, environment


SETUP = r"""
support=$1 ram=$2 mount=$3 stage=$4
cfmgr_test_ram=$ram cfmgr_test_backup=$mount/CFBackup
shift 4
. "$support/modules/lib/config.sh"
. "$support/modules/lib/storage.sh"
. "$support/modules/lib/execution.sh"
. "$support/modules/backup.sh"
cfmgr_store_context=$ram cfmgr_store_source=$support
cfmgr_store_sh=$TEST_SH cfmgr_store_env=$TEST_ENV cfmgr_store_awk=$TEST_AWK
cfmgr_store_sleep=$TEST_SLEEP cfmgr_store_wc=$TEST_WC cfmgr_store_ls=$TEST_LS
cfmgr_store_readlink=$TEST_READLINK cfmgr_store_openssl=$TEST_OPENSSL
cfmgr_backup_mount=$mount cfmgr_backup_folder_pinned=1
cfmgr_archive_stage=$stage cfmgr_archive_stage_leaf=stage
cfmgr_config_lock_fd0=0
if [ "$TEST_LINUX" = 1 ]; then
    : >"$ram/lock"
    exec 0<>"$ram/lock"
    cfmgr_config_lock_fd0=1 cfmgr_store_lock=$ram/lock
fi
cfmgr_archive_stage_inode=$("$TEST_LS" -id "$stage")
IFS=' ' read -r cfmgr_archive_stage_inode inode_rest <<EOF_STAGE_INODE
$cfmgr_archive_stage_inode
EOF_STAGE_INODE
cfmgr_probe_serial=0
if [ "$TEST_LINUX" = 1 ]; then cfmgr_prerequisites_now || exit 80; else cfmgr_probe_now=100; fi
cfmgr_archive_deadline=$((cfmgr_probe_now+10))
exec 5<"$ram" 6<"$mount" 7<"$mount/CFBackup"
cfmgr_store_attachment_ok() { [ ! -e "$ram/cancel" ] && [ -d "$ram" ]; }
cfmgr_backup_attached() { [ -d "$mount/CFBackup" ] && [ ! -L "$mount/CFBackup" ]; }
cfmgr_store_native_tool() { return 0; }
cfmgr_prerequisites_run() {
    mode=$1 context=$2 sh=$3 helper=$4 env=$5 awk=$6 sleep=$7 wc=$8 tool=$9
    shift 9
    case $tool in
    /bin/dd) tool=$TEST_DD ;;
    /bin/gzip) tool=$TEST_GZIP ;;
    /bin/gunzip) tool=$TEST_GUNZIP ;;
    /bin/tar) tool=${TEST_TAR_OVERRIDE:-$TEST_TAR} ;;
    /bin/date) tool=$TEST_DATE ;;
    /usr/bin/hexdump) tool=$TEST_HEXDUMP ;;
    /usr/bin/printf) tool=$TEST_PRINTF ;;
    esac
    if [ "$TEST_LINUX" = 1 ]; then
        cfmgr_test_real_run "$mode" "$context" "$sh" "$helper" "$env" "$awk" "$sleep" "$wc" "$tool" "$@"
        return $?
    fi
    # Explicit host-only supervisor adapter; the same production helper and
    # exec/ulimit profile run real tools, without claiming proc/lock ownership.
    cfmgr_archive_attachment_ok || return 1
    cfmgr_probe_mode=$mode cfmgr_probe_context=$context cfmgr_probe_shell=$sh
    cfmgr_probe_helper=$helper cfmgr_probe_env=$env cfmgr_probe_tool=$tool
    cfmgr_probe_serial=$((cfmgr_probe_serial+1))
    cfmgr_probe_stdout=$context/$mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$context/$mode.$cfmgr_probe_serial.err
    (_cfmgr_prerequisites_exec "$mode" "$context" "$sh" "$helper" "$env" "$awk" "$sleep" "$wc" "$tool" "$@") >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$? cfmgr_probe_status=reaped
    cfmgr_archive_attachment_ok
}
"""


def run(archive, shell, script, *arguments, timeout=15):
    support, ram, mount, stage, environment = archive
    if sys.platform == "darwin":
        script = script.replace("/proc/self/fd/7", str(mount / "CFBackup"))
    return subprocess.run(
        [
            *shell,
            "-c",
            SETUP + pause_definition(shell) + script,
            "archive-io",
            str(support),
            str(ram),
            str(mount),
            str(stage),
            *map(str, arguments),
        ],
        env=environment,
        capture_output=True,
        check=False,
        timeout=timeout,
    )


def passed(result):
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b""), result


def test_staged_worker_preserves_executable_admission_after_fixture_rewrite(
    archive, shell
):
    support, ram, _mount, _stage, _environment = archive
    worker = support / "modules/helpers/worker.sh"
    expected_mode = (ROOT / "modules/helpers/worker.sh").stat().st_mode & 0o777
    assert worker.stat().st_mode & 0o777 == expected_mode
    # Derived archive fixtures edit the existing worker; truncating that file
    # must retain the executable mode required by the real Linux supervisor.
    worker.write_text(worker.read_text())
    assert os.access(worker, os.X_OK)
    assert worker.stat().st_mode & 0o777 == expected_mode
    (ram / "input").write_bytes(b"counted bytes\n")
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_measure "$ram/input" && [ "$cfmgr_archive_bytes" = 14 ]',
        )
    )


def test_source_inert_and_checked_integer_boundaries(shell, tmp_path):
    result = subprocess.run(
        [
            *shell,
            "-c",
            'cd "$2"; . "$1"; cfmgr_archive_uint 0 && cfmgr_archive_uint 9223372036854775296 || exit 1; for bad in "" 01 -1 1e9 9223372036854775297 18446744073709551616; do cfmgr_archive_uint "$bad" && exit 2; done; exit 0',
            "archive-source",
            str(ROOT / "modules/backup.sh"),
            str(tmp_path),
        ],
        check=False,
        capture_output=True,
        timeout=3,
    )
    passed(result)
    assert list(tmp_path.iterdir()) == []


def test_exact_range_and_empty_copy_preserve_binary_and_source(archive, shell):
    ram = archive[1]
    data = bytes(range(256)) * 40
    source = ram / "input"
    source.write_bytes(data)
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_copy "$ram/input" "$stage/range" 13 9001 || exit $?; cfmgr_archive_copy "$ram/input" "$stage/empty" 0 0',
            source,
        )
    )
    assert (archive[3] / "range").read_bytes() == data[13:9014]
    assert (archive[3] / "empty").read_bytes() == b""
    assert source.read_bytes() == data


def test_ram_copy_and_write_use_retained_directory_anchor(archive, shell):
    ram = archive[1]
    (ram / "input").write_bytes(b"pinned-data")
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_output_path "$ram/copy" || exit 80
if [ "$TEST_LINUX" = 1 ]; then
    [ "$cfmgr_archive_anchor" = /proc/self/fd/5/. ] || exit 81
    [ ! -L "$cfmgr_archive_anchor" ] && [ "$cfmgr_archive_anchor" -ef "$ram" ] || exit 82
else [ "$cfmgr_archive_anchor" = "$ram/." ] || exit 83; fi
cfmgr_archive_copy "$ram/input" "$ram/copy" 2 7 || exit 84
cfmgr_archive_write "$ram/written" 4096 new 'written data' || exit 85
""",
        )
    )
    assert (ram / "copy").read_bytes() == b"nned-da"
    assert (ram / "written").read_bytes() == b"written data"
    assert (ram / "input").read_bytes() == b"pinned-data"


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Retained RAM directory FD proof requires Linux proc",
)
def test_ram_worker_refuses_replaced_original_directory_before_copy_or_write(
    archive, shell
):
    _support, ram, mount, stage, _environment = archive
    (stage / "input").write_bytes(b"pinned")
    passed(
        run(
            archive,
            shell,
            r"""
mv "$ram" "$mount/old-ram"
mkdir "$ram"
[ /proc/self/fd/5/. -ef "$mount/old-ram" ] && [ ! /proc/self/fd/5/. -ef "$ram" ] || exit 80
# Invoke the actual child boundary directly: each must reject the changed
# original directory by identity, before reaching its output tool/open.
if "$TEST_SH" "$support/modules/helpers/worker.sh" archive-copy-small "$TEST_DD" "$ram" "$stage/input" /proc/self/fd/5/. "$ram" copy 0 4; then exit 81; else [ "$?" = 1 ] || exit 82; fi
if "$TEST_SH" "$support/modules/helpers/worker.sh" archive-write "$TEST_PRINTF" "$ram" /proc/self/fd/5/. "$ram" written new data; then exit 83; else [ "$?" = 1 ] || exit 84; fi
""",
        )
    )
    for directory in (ram, mount / "old-ram"):
        assert not (directory / "copy").exists()
        assert not (directory / "written").exists()


def test_short_eof_existing_output_and_symlink_refused(archive, shell):
    ram, stage = archive[1], archive[3]
    (ram / "input").write_bytes(b"short")
    (stage / "existing").write_bytes(b"keep")
    (stage / "link").symlink_to(stage / "existing")
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_copy "$ram/input" "$stage/short" 0 4096 && exit 81; cfmgr_archive_copy "$ram/input" "$stage/existing" 0 3 && exit 82; cfmgr_archive_copy "$ram/input" "$stage/link" 0 3 && exit 83; exit 0',
        )
    )
    assert (stage / "existing").read_bytes() == b"keep"
    assert (stage / "link").is_symlink()


def test_real_tar_compress_expand_digest_and_linear_body_stream(archive, shell):
    ram, stage = archive[1], archive[3]
    (stage / "payload").write_bytes(b"body\x00\xff\n")
    (stage / "manifest").write_bytes(b"inert manifest\n")
    (ram / "members").write_text("manifest\npayload\n")
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_io tar-create 65536 "$stage" "$ram/members" "$stage/raw" || exit $?
cfmgr_archive_io gzip 65536 "/proc/self/fd/7/stage/raw" "$stage/compressed" || exit $?
cfmgr_archive_io gunzip-test 4096 "/proc/self/fd/7/stage/compressed" || exit $?
cfmgr_archive_io gunzip 65536 "/proc/self/fd/7/stage/compressed" "$stage/expanded" || exit $?
# Fresh self-created raw bytes; production verifier admission is a separate gate.
cfmgr_archive_io tar-bodies 65536 "/proc/self/fd/7/stage/expanded" "$stage/bodies" || exit $?
cfmgr_archive_io digest 4096 "/proc/self/fd/7/stage/bodies"
""",
        )
    )
    assert (stage / "raw").read_bytes() == (stage / "expanded").read_bytes()
    assert (stage / "bodies").read_bytes() == b"inert manifest\nbody\x00\xff\n"
    with tarfile.open(stage / "compressed", "r:gz") as actual:
        assert actual.getnames() == ["manifest", "payload"]


def test_stream_over_cap_fails_and_no_original_is_clobbered(archive, shell):
    (archive[1] / "input").write_bytes(b"abcd" * 4096)
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_io gzip 65536 "$ram/input" "$stage/zipped" || exit $?; cfmgr_archive_io gunzip 17 "/proc/self/fd/7/stage/zipped" "$stage/over" && exit 81; exit 0',
        )
    )
    assert (archive[1] / "input").read_bytes() == b"abcd" * 4096


def test_literal_timezone_and_bounded_binary_header_hex(archive, shell):
    (archive[1] / "header").write_bytes(b"\0" * 512)
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_io hexdump 4096 "$ram/header" || exit $?
"$TEST_WC" -c "$cfmgr_archive_output" >"$ram/hex-size"
IFS=' ' read -r size rest <"$ram/hex-size"
[ "$size" = 1024 ] || exit 81
cfmgr_archive_io date 4096 'UTC0' || exit $?
IFS='|' read -r epoch day clock zone <"$cfmgr_archive_output"
cfmgr_archive_uint "$epoch" && [ "$zone" = +0000 ]
""",
        )
    )


def test_stage_substitution_refused_before_output(archive, shell):
    (archive[1] / "input").write_bytes(b"data")
    passed(
        run(
            archive,
            shell,
            'mv "$stage" "$mount/old-stage"; mkdir "$stage"; cfmgr_archive_copy "$ram/input" "$stage/copy" 0 4 && exit 81; [ ! -e "$stage/copy" ]',
        )
    )


def test_source_pin_refuses_to_discard_fd3_or_destination_pins(archive, shell):
    passed(
        run(
            archive,
            shell,
            'exec 3<"$ram"; cfmgr_archive_source_pin x ext4 / .; [ "$?" = 2 ] || exit 81; [ -d /proc/self/fd/6 ] && [ -d /proc/self/fd/7 ]'
            if sys.platform == "linux"
            else 'exec 3<"$ram"; cfmgr_archive_source_pin x ext4 / .; [ "$?" = 2 ]',
        )
    )


@pytest.mark.skipif(
    sys.platform != "linux", reason="Real descriptor anchoring requires Linux proc"
)
def test_child_anchor_ignores_replaced_original_mount_path(archive, shell):
    ram, stage = archive[1], archive[3]
    (ram / "input").write_bytes(b"pinned")
    # Detach the name before directly calling the real helper. The original
    # argument is absent/replaced, so the helper fails before any fallback open.
    passed(
        run(
            archive,
            shell,
            r"""
mv "$mount" "$ram/old-drive"
mkdir -p "$mount/CFBackup/stage"
"$TEST_SH" "$support/modules/helpers/worker.sh" archive-copy-blocks "$TEST_DD" "$ram" "$ram/input" /proc/self/fd/7/stage "$stage" copy 0 1 && exit 81
[ ! -e "$stage/copy" ] && [ ! -e "$ram/old-drive/CFBackup/stage/copy" ]
""",
        )
    )
    assert not (stage / "copy").exists()


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="Ownership, deadlines and lock inheritance require Linux proc",
)
@pytest.mark.parametrize("stop", ["deadline", "cancel"])
def test_archive_profile_deadline_cancellation_and_fd0_lock(archive, shell, stop):
    tool = archive[1] / "block-tar"
    tool.write_text(
        "#!/bin/sh\n[ -f /proc/self/fd/0 ] || exit 81\n[ ! -e /proc/self/fd/9 ] || exit 82\n"
        f": >{shlex.quote(str(archive[1] / 'child-started'))}\n"
        "exec /bin/sleep 10\n"
    )
    tool.chmod(0o700)
    archive[4]["TEST_TAR_OVERRIDE"] = str(tool)
    (archive[1] / "input").write_bytes(b"not parsed by blocking adapter")
    archive[4]["TEST_STOP"] = stop
    passed(
        run(
            archive,
            shell,
            r"""
: >"$ram/lock"
exec 0<>"$ram/lock"
cfmgr_config_lock_fd0=1
cfmgr_store_fd_is() { [ "$1" -ef /proc/self/fd/0 ]; }
cfmgr_store_lock=$ram/lock
cfmgr_prerequisites_now || exit 80
cfmgr_archive_deadline=$((cfmgr_probe_now+1))
expected=deadline
if [ "$TEST_STOP" = cancel ]; then
    cfmgr_archive_deadline=$((cfmgr_probe_now+5))
    cfmgr_store_attachment_ok() { [ ! -e "$ram/child-started" ]; }
    expected=attachment
fi
cfmgr_archive_io tar-list 4096 "$ram/input" "$stage/list" && exit 83
[ "$cfmgr_probe_status:$cfmgr_probe_reason" = "reaped:$expected" ] && [ ! -d "/proc/$cfmgr_probe_pid" ]
""",
        )
    )


def test_flattened_long_base64_decodes_exact_valid_json(archive, shell):
    decoded = json.dumps({"AccountTag": "a" * 32, "TunnelSecret": "x" * 1800}).encode()
    encoded = base64.b64encode(decoded)
    assert len(encoded) > 1024 and len(decoded) > 768
    (archive[1] / "base64").write_bytes(encoded)
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_io base64 4096 "$ram/base64" "$stage/decoded"',
        )
    )
    actual = (archive[3] / "decoded").read_bytes()
    assert actual == decoded
    assert json.loads(actual)["TunnelSecret"] == "x" * 1800


@pytest.mark.skipif(
    sys.platform != "linux", reason="Real inherited lock needs Linux proc"
)
def test_json_child_retains_lock9_across_stdin_redirect(archive, shell):
    support = archive[0] / "modules/lib"
    # The production JSON helper redirects stdin and invokes this real AWK
    # script; the direct-exec adapter independently proves lock contention.
    # Override only these parser getters; the consolidated categories also own
    # the production I/O and lock callbacks exercised by this test.
    config = support / "config.sh"
    config.write_text(
        config.read_text()
        + "\ncfmgr_config_awk_json() { cfmgr_awk_program='END { if (NR != 1) exit 1 }'; }\n"
    )
    backup = support / "../backup.sh"
    backup.write_text(
        backup.read_text()
        + "\ncfmgr_backup_awk_backup_payload() { cfmgr_awk_program=''; }\n"
    )
    (archive[1] / "json").write_text('{"ok":true}\n')
    passed(
        run(
            archive,
            shell,
            r"""
"$TEST_FLOCK" -n 0 || exit 80
cfmgr_archive_run archive-payload-json 4096 "$TEST_AWK" "$support/modules/lib" certificate-json "$ram/json" 12 a || exit $?
# Now prove9 alone retains exclusion after the launching parent releases0.
: >"$ram/prove-json-lock"
# Pinned ash resets background0 before redirects: 0<&0 cannot preserve it.
# Use the production supervisor's invocation-scoped9 bridge across that fork.
start_json() {
    (exec "$TEST_SH" "$support/modules/helpers/worker.sh" archive-payload-json "$TEST_AWK" "$ram" "$support/modules/lib" certificate-json "$ram/json" 12 a) 0<&9 9<&- >"$ram/json.out" 2>"$ram/json.err" &
    json_pid=$!
}
start_json 9<&0
remaining=40
while [ ! -e "$ram/json-started" ] && [ "$remaining" -gt 0 ]; do
    remaining=$((remaining-1)); cfmgr_prerequisites_pause
done
if [ ! -e "$ram/json-started" ]; then
    kill "$json_pid" 2>/dev/null
    wait "$json_pid"; json_code=$?
    printf 'JSON child exited before marker: %s\n' "$json_code" >&2
    exit 81
fi
exec 0<&-
: >"$ram/json-owner-closed"
wait "$json_pid" || exit $?
[ ! -s "$ram/json.err" ] || exit 82
# Reaping the only remaining owner makes a fresh open lockable again.
(exec 3<>"$ram/lock"; "$TEST_FLOCK" -n 3)
""",
        )
    )


def test_watch_attachment_never_launches_archive_inode_tool(archive, shell):
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_store_ls() { : >"$ram/unexpected-ls"; return 99; }
cfmgr_store_ls=cfmgr_store_ls
cfmgr_archive_attachment_ok || exit 81
[ ! -e "$ram/unexpected-ls" ]
""",
        )
    )


def test_stage_replacement_during_write_fails_postcheck(archive, shell):
    actual = archive[4]["TEST_PRINTF"]
    replacement = archive[1] / "replace-stage"
    replacement.write_text(
        f"#!/bin/sh\nmv {shlex.quote(str(archive[3]))} {shlex.quote(str(archive[2] / 'old-stage'))} || exit 80\n"
        f"mkdir {shlex.quote(str(archive[3]))} || exit 81\n"
        f'exec {shlex.quote(actual)} "$@"\n'
    )
    replacement.chmod(0o700)
    archive[4]["TEST_PRINTF"] = str(replacement)
    old = archive[2] / "old-stage"
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_write "$stage/generated" 4096 new contents && exit 81; [ ! -e "$stage/generated" ]',
        )
    )
    assert (old / "generated").read_bytes() == b"contents"
    assert not (archive[3] / "generated").exists()


@pytest.mark.skipif(
    sys.platform != "linux", reason="Native child supervision needs Linux proc"
)
def test_stage_inode_probe_is_deadline_bounded(archive, shell):
    blocker = archive[1] / "block-ls"
    blocker.write_text("#!/bin/sh\nexec /bin/sleep 10\n")
    blocker.chmod(0o700)
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_store_ls=$ram/block-ls
cfmgr_prerequisites_now || exit 80
cfmgr_archive_deadline=$((cfmgr_probe_now+1))
cfmgr_archive_write "$stage/generated" 4096 new contents && exit 81
[ "$cfmgr_probe_status:$cfmgr_probe_reason" = reaped:deadline ] && [ ! -e "$stage/generated" ]
""",
        )
    )


def test_append_replacement_during_write_is_not_accepted(archive, shell):
    stage = archive[3]
    target, retained = stage / "append", stage / "retained"
    target.write_bytes(b"old")
    replacement = archive[1] / "replace-append"
    replacement.write_text(
        f"#!/bin/sh\nmv {shlex.quote(str(target))} {shlex.quote(str(retained))} || exit 80\n"
        f"printf foreign >{shlex.quote(str(target))} || exit 81\n"
        f'exec {shlex.quote(archive[4]["TEST_PRINTF"])} "$@"\n'
    )
    replacement.chmod(0o700)
    archive[4]["TEST_PRINTF"] = str(replacement)
    passed(
        run(
            archive,
            shell,
            'cfmgr_archive_write "$stage/append" 4096 append extra && exit 81; exit 0',
        )
    )
    assert target.read_bytes() == b"foreign"
    assert retained.read_bytes() == b"oldextra"
