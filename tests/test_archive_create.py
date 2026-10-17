"""Manual create consumer: real Store, capture, archive verification and publish.

Host root/mount admission is explicit fixture data. Linux keeps the actual
supervisor and inherited lock; macOS adapts unavailable directory-FD traversal.
"""

from __future__ import annotations

import gzip
import hashlib
import io
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
from pathlib import Path

import pytest
from test_archive_config import SET_ID, configured
from test_archive_format import make_header
from test_archive_io import SETUP, passed, run
from test_archive_io import archive as io_archive
from test_config_observation import commands, schema2_config
from test_config_store import legacy_fsync
from test_prerequisites import pause_definition, shell

__all__ = ["commands", "legacy_fsync", "schema2_config", "shell"]
base_archive = io_archive
ROOT = Path(__file__).resolve().parents[1]
PRIOR_ID = "abcdefab-1234-4abc-8abc-123456789abc"


def prior_archive(config: bytes) -> bytes:
    """Independent valid supported raw tar; no production ledger shortcut."""
    bodies = [config, b"prior catalog\n"]
    rows = [
        f"FILE p{n:08d} manager.{role} jffs {path.encode().hex()} 1 0600 "
        f"{len(body)} {hashlib.sha256(body).hexdigest()} whole"
        for n, (role, path, body) in enumerate(
            zip(
                ("config", "catalog"),
                ("addons/CFMgr.d/config", "addons/CFMgr.d/catalog.txt"),
                bodies,
            ),
            1,
        )
    ]
    rows += [
        f"NOTE {role} not_applicable - no-owned-data END"
        for role in (
            "data.cloudflared.yaml",
            "data.cloudflared.yaml-backup",
            "data.cloudflared.json",
            "data.cloudflared.certificate",
            "data.cloudflared.certificate-recovery",
            "data.setup-drafts",
            "history.ddns",
            "history.ip_sync",
            "history.cloudflared",
        )
    ]
    inventory = (
        "CFMGR-INVENTORY 1\n"
        + "\n".join(rows)
        + f"\nEND 2 {len(rows) - 2} {sum(map(len, bodies))}\n"
    ).encode()
    manifest = (
        f"CFMGR-ARCHIVE 1\nSET {SET_ID}\nARCHIVE {PRIOR_ID}\n"
        "CREATED 1700000000 2023-11-14 22-13-20 55544330 +0000 YMD\n"
        f"CONFIG 2 1\nINVENTORY {len(rows)} {len(inventory)} {hashlib.sha256(inventory).hexdigest()} 2 {sum(map(len, bodies))}\nEND\n"
    ).encode()
    result = bytearray()
    for name, body in zip(
        ("manifest", "inventory", "p00000001", "p00000002"),
        (manifest, inventory, *bodies),
    ):
        result.extend(make_header(name, len(body)))
        result.extend(body)
        result.extend(b"\0" * (-len(body) % 512))
    result.extend(b"\0" * 1024)
    return gzip.compress(bytes(result), mtime=0)


@pytest.fixture
def creation(base_archive, legacy_fsync, schema2_config):
    old_support, ram, mount, _stage, environment = base_archive
    jffs = ram.parent / "jffs"
    support = jffs / "addons/CFMgr.d"
    support.parent.mkdir(parents=True)
    shutil.copytree(old_support, support)
    config = configured(schema2_config)
    (support / "config").write_bytes(config)
    (support / "config").chmod(0o600)
    (support / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (support / "setup-state").chmod(0o600)
    (support / "catalog.txt").write_text("informational fixture catalog\n")
    # Retained compressed archives are inert containers, including FAT's
    # executable mode emulation. The archived source files stay data-only.
    prior = mount / "CFBackup/CFbackup-2023-11-14.tar.gz"
    prior.write_bytes(prior_archive(config))
    prior.chmod(0o777)
    for name in ("backup.sh", "lib/config.sh"):
        path = support / "modules" / name
        text = path.read_text().replace(
            '[ "$cfmgr_capture_uid" = 0 ]', f'[ "$cfmgr_capture_uid" = {os.geteuid()} ]'
        )
        text = text.replace(
            ":0 | file:-rw-------:0",
            f":{os.geteuid()} | file:-rw-------:{os.geteuid()}",
        )
        if sys.platform == "darwin":
            text = text.replace("/proc/self/fd/8", "${cfmgr_test_jffs}")
            for variable in ("ram", "backup", "jffs"):
                text = text.replace(
                    f"cd ${{cfmgr_test_{variable}}}", f'cd "${{cfmgr_test_{variable}}}"'
                )
                text = text.replace(
                    f" ${{cfmgr_test_{variable}}} ", f' "${{cfmgr_test_{variable}}}" '
                )
        path.write_text(text)
    worker = support / "modules/helpers/worker.sh"
    text = worker.read_text().replace("$4!=0", f"$4!={os.geteuid()}")
    if sys.platform == "darwin":
        text = (
            text.replace("/proc/self/fd/8", "/dev/fd/8")
            .replace('"$1" -ef /dev/fd/8', "-f /dev/fd/8")
            .replace('ulimit -v "$3" || exit 2', ":")
        )
    if sys.platform == "darwin":
        memory = ram / "meminfo"
        memory.write_text("MemAvailable: 65536 kB\n")
        text = text.replace("/proc/meminfo", shlex.quote(str(memory))).replace(
            '[ "$3" -ef /proc/self/fd/2 ]', '[ -f "$3" ]'
        )
    worker.write_text(text)
    # Store and history JSON modes use stdin and retain the same borrowed0 on9.
    if sys.platform == "linux":
        wrapper = Path(environment["TEST_AWK"])
        text = (
            wrapper.read_text()
            .replace(
                "${CFMGR_PAYLOAD_MODE:-}",
                "${CFMGR_PAYLOAD_MODE:-${CFMGR_HISTORY_MODE:+history-}${CFMGR_HISTORY_MODE:-${2%%=*}}}",
            )
            .replace(
                "plan|runtime-json|certificate-json|drafts)",
                "plan|runtime-json|certificate-json|drafts|history-policy|cfmgr_config_mode|cfmgr_json_mode)",
            )
        )
        wrapper.write_text(text)
    for tool in ("cp", "mv", "df", "flock", "mkdir", "chmod"):
        actual = (
            environment.get("TEST_FLOCK") if tool == "flock" else shutil.which(tool)
        )
        if tool == "flock" and not actual:
            shim = ram.parent / "flock"
            shim.write_text(
                f"#!{Path(sys.executable).resolve()}\nimport fcntl,sys\ntry: fcntl.flock(int(sys.argv[2]),fcntl.LOCK_EX|fcntl.LOCK_NB)\nexcept BlockingIOError: sys.exit(1)\n"
            )
            shim.chmod(0o700)
            actual = str(shim)
        assert actual
        environment[f"TEST_{tool.upper()}"] = actual
    for tool in ("wc", "dd", "openssl"):
        environment[f"TEST_RAW_{tool.upper()}"] = shutil.which(tool)
    nvram = ram.parent / "nvram"
    nvram.write_text("#!/bin/sh\nprintf 'UTC0\\n'\n")
    nvram.chmod(0o700)
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") != "1":
        native_tar = shutil.which("gtar") or shutil.which("tar")
        assert native_tar
        tar = ram.parent / "supported-tar"
        tar.write_text(
            "#!/bin/sh\n"
            + f'case $1 in -cf) exec {shlex.quote(native_tar)} --format=gnu --blocking-factor=1 "$@" ;; esac\n'
            + f'exec {shlex.quote(native_tar)} "$@"\n'
        )
        tar.chmod(0o700)
        environment["TEST_TAR"] = str(tar)
    environment.update(
        TEST_NVRAM=str(nvram), TEST_FSYNC=str(legacy_fsync), CFMGR_FSYNC_FAULT="clean"
    )
    return support, ram, mount, jffs, prior, environment


CREATE_SETUP = r"""
support=$1 ram=$2 mount=$3 cfmgr_test_jffs=$4
cfmgr_test_ram=$ram/context cfmgr_test_backup=$mount/CFBackup
printf 'imports\n' >"$ram/create-phase"
. "$support/modules/lib/config.sh"
. "$support/modules/lib/storage.sh"
. "$support/modules/lib/execution.sh"
. "$support/modules/backup.sh"
printf 'imports-complete\n' >"$ram/create-phase"
CFMGR_VERSION=0.1.0
cfmgr_test_started=$SECONDS
if [ "$TEST_LINUX" = 0 ]; then
    cfmgr_prerequisites_now() { cfmgr_probe_now=$((100+SECONDS-cfmgr_test_started)); }
fi
cfmgr_store_prepare() {
    printf 'store-prepare\n' >"$ram/create-phase"
    cfmgr_store_source=$support cfmgr_store_ram=$ram cfmgr_store_jffs=$cfmgr_test_jffs
    cfmgr_store_live=$support/config cfmgr_store_lock=$ram/lock
    cfmgr_store_context=$cfmgr_test_ram
    umask 077
    mkdir -m 700 "$cfmgr_store_context" || return 1
    exec 5<"$cfmgr_store_context" 8<"$cfmgr_store_jffs" 9<"$support"
    printf 'store-pins\n' >"$ram/create-phase"
    cfmgr_store_context_fd=5 cfmgr_store_borrowed=0 cfmgr_store_flock_entware=0
    # Native tool wrappers check the preopened descriptor during initial reads.
    # Real Store acquisition below still reopens, locks and proves contention.
    if [ "$TEST_LINUX" = 1 ]; then cfmgr_config_lock_fd0=1; fi
    cfmgr_store_sh=$TEST_SH cfmgr_store_env=$TEST_ENV cfmgr_store_awk=$TEST_AWK
    cfmgr_store_readlink=$TEST_READLINK cfmgr_store_wc=$TEST_WC cfmgr_store_ls=$TEST_LS
    cfmgr_store_sleep=$TEST_SLEEP cfmgr_store_flock=$TEST_FLOCK cfmgr_store_openssl=$TEST_OPENSSL
    cfmgr_store_dd=$TEST_DD cfmgr_store_cp=$TEST_CP cfmgr_store_mv=$TEST_MV cfmgr_store_fsync=$TEST_FSYNC
    printf 'store-clock\n' >"$ram/create-phase"
    cfmgr_prerequisites_now || return 1
    cfmgr_store_deadline=$((cfmgr_probe_now+20)) cfmgr_probe_pid='' cfmgr_probe_serial=0
    printf 'store-prepared\n' >"$ram/create-phase"
}
cfmgr_store_attachment_ok() { [ -d "$cfmgr_store_context" ] && [ ! -L "$cfmgr_store_context" ]; }
cfmgr_store_fd_is() { [ -f "$1" ] && [ ! -L "$1" ]; }
cfmgr_store_native_tool() {
    case $1 in
    /bin/nvram) [ -x "$TEST_NVRAM" ] ;;
    /bin/gzip) [ -x "$TEST_GZIP" ] ;;
    /bin/gunzip) [ -x "$TEST_GUNZIP" ] ;;
    /bin/tar) [ -x "$TEST_TAR" ] ;;
    *) [ -x "$1" ] ;;
    esac
}
cfmgr_archive_destination() {
    cfmgr_backup_mount=$mount cfmgr_backup_pinned=1 cfmgr_backup_folder_pinned=1
    exec 6<"$mount" 7<"$mount/CFBackup"
}
cfmgr_backup_attached() { [ -d "$mount/CFBackup" ] && [ ! -L "$mount/CFBackup" ]; }
# The unconfigured baseline has no owned Entware payload or history. These two
# missing-install admissions match that fixture and grant no read authority.
cfmgr_storage_pin() { return 1; }
cfmgr_archive_source_pin() { return 1; }
if [ "$TEST_LINUX" = 0 ]; then
    # Kernel UUID/memory observations are fixture inputs on macOS only.
    cfmgr_archive_uuid() { cfmgr_archive_uuid=00000000-0000-4000-8000-123456789abc; }
fi
"""


def create_failure_summary(creation):
    """Read only bounded fixed diagnostics; never read archive/config payloads."""
    support, ram, mount, _jffs, _prior, _environment = creation

    def tail(name, limit):
        try:
            with (ram / name).open("rb") as stream:
                size = stream.seek(0, os.SEEK_END)
                stream.seek(max(0, size - limit))
                return stream.read(limit).decode("ascii", errors="replace").splitlines()
        except OSError:
            return []

    mode = r"(?:store|archive|history)-[a-z0-9-]{1,48}"
    routes = [
        line if re.fullmatch(mode, line) else "[invalid-mode]"
        for line in tail("routes", 4096)[-24:]
    ]
    phase = tail("create-phase", 128)
    phase = phase[-1] if phase else "missing"
    if phase not in {
        "missing",
        "imports",
        "imports-complete",
        "lock-open",
        "action-start",
        "store-prepare",
        "store-pins",
        "store-clock",
        "store-prepared",
    }:
        phase = "invalid"
    probe = tail("create-probe", 256)
    probe = probe[-1] if probe else "missing"
    number = r"(?:[0-9]{1,20}|-)"
    begin = rf"begin {mode} {number} {number} {number} {number}"
    end = rf"end {mode} [0-9]{{1,3}} (?:invalid|reaped|unresolved|-) {number} (?:arguments|attachment|clock|deadline|lock-inheritance|native-supervisor|-)"
    if probe != "missing" and not re.fullmatch(rf"(?:{begin}|{end})", probe):
        probe = "invalid"
    save = tail("create-save", 512)
    save = save[-1] if save else "missing"
    scalar = r"(?:[a-z][a-z0-9-]{0,31}|-)"
    flag = r"[01-]"
    save_frame = (
        rf"save rc={number} status={scalar} result={scalar} pending={flag} "
        rf"config_lock={flag} archive_lock={flag} guard={flag} fd3=[01] fd4=[01] "
        rf"mode=(?:{mode}|-) exit={number} reason={scalar} now={number} deadline={number}"
    )
    if save != "missing" and not re.fullmatch(save_frame, save):
        save = "invalid"
    flags = {
        "context": (ram / "context").is_dir(),
        "lock": (ram / "lock").is_file(),
        "backup": (mount / "CFBackup").is_dir(),
        "preparing": (support / ".config-save.preparing").is_dir(),
        "save": (support / ".config-save").is_dir(),
        "retired": (support / ".config-save.retired").is_dir(),
    }
    return f"phase={phase}; probe={probe}; save={save}; routes_tail={routes}; flags={flags}"


def create_run(creation, shell):
    support, ram, mount, jffs, _prior, environment = creation
    supervisor = SETUP[SETUP.index("cfmgr_prerequisites_run() {") :]
    supervisor = supervisor.replace(
        "cfmgr_archive_attachment_ok || return 1",
        "cfmgr_store_attachment_ok || return 1",
    )
    native_call = '        cfmgr_test_real_run "$mode" "$context" "$sh" "$helper" "$env" "$awk" "$sleep" "$wc" "$tool" "$@"\n        return $?'
    assert supervisor.count(native_call) == 1
    supervisor = supervisor.replace(
        native_call,
        r'''        cfmgr_test_create_sample=0
        case $((${cfmgr_probe_serial:-0} % 64)) in 0) cfmgr_test_create_sample=1; printf 'begin %s %s %s %s %s\n' "$mode" "${cfmgr_probe_serial:--}" "${cfmgr_probe_now:--}" "${cfmgr_store_deadline:--}" "${cfmgr_archive_deadline:--}" >"$ram/create-probe" ;; esac
        if cfmgr_test_real_run "$mode" "$context" "$sh" "$helper" "$env" "$awk" "$sleep" "$wc" "$tool" "$@"; then cfmgr_test_create_code=0; else cfmgr_test_create_code=$?; fi
        case $cfmgr_test_create_sample:$cfmgr_test_create_code in 0:0) ;; *) printf 'end %s %s %s %s %s\n' "$mode" "$cfmgr_test_create_code" "${cfmgr_probe_status:--}" "${cfmgr_probe_exit:--}" "${cfmgr_probe_reason:--}" >"$ram/create-probe" ;; esac
        return "$cfmgr_test_create_code"''',
    )
    supervisor = supervisor.replace(
        "cfmgr_archive_attachment_ok\n}", "cfmgr_store_attachment_ok\n}"
    )
    supervisor = supervisor.replace(
        "case $tool in",
        'case " ${cfmgr_test_seen_modes:-} " in *" $mode "*) ;; *) printf "%s\\n" "$mode" >>"$ram/routes"; cfmgr_test_seen_modes="${cfmgr_test_seen_modes:-} $mode" ;; esac\n    case $mode in\n    store-count) tool=$TEST_RAW_WC ;;\n    store-snapshot) tool=$TEST_RAW_DD ;;\n    store-digest) tool=$TEST_RAW_OPENSSL ;;\n    esac\n    case $tool in',
        1,
    )
    supervisor = supervisor.replace(
        "/bin/date) tool=$TEST_DATE ;;",
        "/bin/date) tool=$TEST_DATE ;;\n    /bin/df) tool=$TEST_DF ;;\n    /bin/nvram) tool=$TEST_NVRAM ;;",
    )
    script = (
        CREATE_SETUP
        + supervisor
        + pause_definition(shell)
        + r"""
# Record real verifier outcomes before successful Store cleanup retires RAM.
cfmgr_archive_existing() {
    if cfmgr_test_existing "$@"; then result=0; else result=$?; fi
    printf '%s %s\n' "$1" "$cfmgr_create_existing_status" >>"$ram/recognized"
    return "$result"
}
# Preserve the real Save result before action cleanup changes its diagnostics.
cfmgr_store_archive_save() {
    if cfmgr_test_store_archive_save "$@"; then cfmgr_test_save_code=0; else cfmgr_test_save_code=$?; fi
    cfmgr_test_save_fd3=0 cfmgr_test_save_fd4=0
    if (: <&3) 2>/dev/null; then cfmgr_test_save_fd3=1; fi
    if (: <&4) 2>/dev/null; then cfmgr_test_save_fd4=1; fi
    printf 'save rc=%s status=%s result=%s pending=%s config_lock=%s archive_lock=%s guard=%s fd3=%s fd4=%s mode=%s exit=%s reason=%s now=%s deadline=%s\n' \
        "$cfmgr_test_save_code" "${cfmgr_probe_status:--}" "${cfmgr_store_result:--}" "${cfmgr_store_pending:--}" \
        "${cfmgr_config_lock_fd0:--}" "${cfmgr_store_archive_lock_held:--}" "${cfmgr_store_guard_owned:--}" \
        "$cfmgr_test_save_fd3" "$cfmgr_test_save_fd4" "${cfmgr_probe_mode:--}" "${cfmgr_probe_exit:--}" \
        "${cfmgr_probe_reason:--}" "${cfmgr_probe_now:--}" "${cfmgr_store_deadline:--}" >"$ram/create-save"
    return "$cfmgr_test_save_code"
}
cfmgr_archive_action create
"""
    )
    # Rename the definition in the private copied category, retaining the real
    # inspection and exporting only its final normalized classification.
    source = support / "modules/backup.sh"
    source.write_text(
        source.read_text().replace(
            "cfmgr_archive_existing() {", "cfmgr_test_existing() {", 1
        )
    )
    source = support / "modules/lib/config.sh"
    body = source.read_text()
    assert body.count("cfmgr_store_archive_save() {") == 1
    source.write_text(
        body.replace(
            "cfmgr_store_archive_save() {", "cfmgr_test_store_archive_save() {", 1
        )
    )
    # Linux fixture tools verify inherited lock identity even during the initial
    # read-only Store phase; the controller later acquires this same open file.
    script = script.replace(
        "cfmgr_archive_action create",
        'printf "lock-open\\n" >"$ram/create-phase"\n: >"$ram/lock"\nchmod 600 "$ram/lock"\nexec 0<>"$ram/lock"\nprintf "action-start\\n" >"$ram/create-phase"\ncfmgr_archive_action create',
    )
    # Native diagnostics reached probe 814 while still advancing through the
    # real verifier. Allow production's 600s create budget plus bounded setup/
    # cleanup for one measured complete run; retain the shorter host guard.
    timeout = 660 if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1" else 180
    try:
        return subprocess.run(
            [
                *shell,
                "-c",
                script,
                "archive-create",
                str(support),
                str(ram),
                str(mount),
                str(jffs),
            ],
            env=environment,
            capture_output=True,
            check=False,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        pytest.fail(
            f"Manual create exceeded {timeout}s; {create_failure_summary(creation)}",
            pytrace=False,
        )


def test_manual_create_real_store_capture_verify_publish_and_history(creation, shell):
    support, ram, mount, _jffs, prior, _environment = creation
    before = json.loads((support / "config").read_bytes())
    result = create_run(creation, shell)
    assert result.returncode == 0, (
        result.stdout,
        result.stderr,
        create_failure_summary(creation),
    )
    assert result.stderr == b"", result.stderr
    fields = result.stdout.decode().split()
    assert fields[:4] == ["CFMGR-ARCHIVE-ACTION", "1", "created", "1"]
    assert fields[4:8] == ["0", "YMD", "4", "1"]
    assert fields[-3:] == ["complete", "saved", "END"], create_failure_summary(creation)
    name = bytes.fromhex(fields[8]).decode()
    assert (ram / "recognized").read_text() == f"{prior.name} verified\n"
    assert prior.exists()
    archives = sorted((mount / "CFBackup").glob("CFbackup-*.tar.gz"))
    assert len(archives) == 2 and (mount / "CFBackup" / name) in archives
    with tarfile.open(
        fileobj=io.BytesIO(gzip.decompress((mount / "CFBackup" / name).read_bytes()))
    ) as archive:
        assert archive.getnames() == ["manifest", "inventory", "p00000001", "p00000002"]
        captured_config = archive.extractfile("p00000001").read()
        assert json.loads(captured_config) == before
        assert (
            archive.extractfile("p00000002").read()
            == b"informational fixture catalog\n"
        )
    after = json.loads((support / "config").read_bytes())
    assert after["generation"] == before["generation"] + 1
    assert after["backup"]["last_backup"]["archive_id"]
    assert not (ram / "context").exists()
    assert not list((mount / "CFBackup").glob(".create.*"))
    routes = (ram / "routes").read_text().splitlines()
    for mode in (
        "store-archive-plan",
        "history-parse",
        "archive-tar-create",
        "archive-gzip",
        "archive-gunzip",
        "archive-format-manifest",
        "archive-payload-match",
        "archive-publish",
        "store-move",
    ):
        assert mode in routes


def controller_boundary(shell, tmp_path, script):
    return subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"\nshift\n' + script,
            "archive-controller",
            str(ROOT / "modules/backup.sh"),
            str(tmp_path),
        ],
        capture_output=True,
        check=False,
        timeout=10,
    )


def test_definitive_foreign_set_parser_rejection_is_excluded(
    base_archive, shell, schema2_config
):
    _support, _ram, _mount, stage, _environment = base_archive
    raw = gzip.decompress(prior_archive(configured(schema2_config)))
    (stage / "raw").write_bytes(raw)
    with tarfile.open(fileobj=io.BytesIO(raw)) as contents:
        manifest = contents.extractfile("manifest").read()
    (stage / "manifest.hex").write_text("".join(f"{byte:02x}\n" for byte in manifest))
    passed(
        run(
            base_archive,
            shell,
            r"""
cfmgr_archive_inventory_limit=65536 cfmgr_format_owned=''
cfmgr_archive_saved_set_id=ffffffff-ffff-4fff-8fff-ffffffffffff
_cfmgr_archive_format_verify() {
    : >"$ram/foreign-parser-entered"
    cfmgr_archive_run archive-format-manifest 4096 "$cfmgr_store_awk" "$support/modules/backup.sh" "$stage/manifest.hex" "$cfmgr_format_expected_set"
}
cfmgr_archive_identity_check || exit 80
if cfmgr_archive_verify_owned "$stage/raw"; then exit 81; else [ "$?" = 1 ] || exit 82; fi
# Scratch cleanup may run later inode probes; the classified outcome persists.
[ "$cfmgr_archive_verification_status" = excluded ] && [ -f "$ram/foreign-parser-entered" ] || exit 83
""",
            timeout=20,
        )
    )


def test_unresolved_rotation_release_stops_all_action_cleanup(shell, tmp_path):
    result = controller_boundary(
        shell,
        tmp_path,
        r"""
cfmgr_backup_history_release() { cfmgr_probe_status=unresolved cfmgr_probe_pid=unresolved; return 3; }
# Action calls have no fixture operands; keep the temporary path in a global.
fixture=$1
cfmgr_store_prepare() { cfmgr_store_context=$fixture; }
cfmgr_archive_work() {
    cfmgr_history_lock_held=1 cfmgr_probe_status=reaped cfmgr_archive_saved_generation=8
    exec 3<"$fixture" 4<"$fixture"
    return 1
}
cfmgr_archive_source_release() { : >"$fixture/cleanup"; }
cfmgr_payload_cleanup() { : >"$fixture/cleanup"; }
cfmgr_archive_stage_close() { : >"$fixture/cleanup"; }
cfmgr_store_cleanup() { : >"$fixture/cleanup"; }
cfmgr_archive_action create
""",
    )
    assert result.returncode == 3, result
    assert (
        result.stdout
        == b"CFMGR-ARCHIVE-ACTION 1 unresolved 8 1 - 0 0 - none none END\n"
    )
    assert not (tmp_path / "cleanup").exists()


def test_published_archive_survives_reaped_owned_stage_cleanup_failure(shell, tmp_path):
    (tmp_path / "published.tar.gz").write_bytes(b"confirmed archive")
    (tmp_path / "unknown-stage-member").write_bytes(b"do not adopt")
    result = controller_boundary(
        shell,
        tmp_path,
        r"""
fixture=$1
cfmgr_store_prepare() { cfmgr_store_context=$fixture; }
cfmgr_archive_work() {
    cfmgr_create_result=created cfmgr_create_published=1
    cfmgr_create_name_hex=43466261636b75702d323032362e7461722e677a
    cfmgr_archive_saved_generation=9 cfmgr_archive_saved_format=YMD cfmgr_archive_saved_keep=4
    cfmgr_create_retention=complete cfmgr_create_history=saved
    cfmgr_probe_status=reaped cfmgr_archive_stage=$fixture
}
cfmgr_archive_source_release() { :; }
cfmgr_prerequisites_now() { cfmgr_probe_now=100; }
cfmgr_payload_cleanup() { :; }
cfmgr_archive_stage_close() { return 1; }
cfmgr_store_cleanup() { : >"$fixture/store-cleaned"; }
cfmgr_archive_action create
""",
    )
    assert result.returncode == 0, result
    assert result.stdout.startswith(b"CFMGR-ARCHIVE-ACTION 1 created 9 1 YMD 4 ")
    assert (
        result.stderr
        == b"[CFMGR] backup: warning: archive created; temporary cleanup is pending\n"
    )
    assert (tmp_path / "published.tar.gz").read_bytes() == b"confirmed archive"
    assert (tmp_path / "unknown-stage-member").read_bytes() == b"do not adopt"
    assert (tmp_path / "store-cleaned").exists()


@pytest.mark.parametrize("fault", ["uncertain-publish", "history-save"])
def test_controller_stops_after_uncertain_publish_and_reports_history_save_failure(
    shell, tmp_path, fault
):
    result = controller_boundary(
        shell,
        tmp_path,
        r"""
fixture=$1
cfmgr_create_operation=create cfmgr_create_published=0 cfmgr_create_config_sha=hash
cfmgr_store_pending=0 cfmgr_store_context=$fixture cfmgr_store_source=$fixture
cfmgr_probe_status=reaped cfmgr_probe_stdout=$fixture
cfmgr_store_pending() { cfmgr_store_pending=0; }
cfmgr_store_setup_ok() { :; }
cfmgr_store_archive_read() {
    cfmgr_archive_saved_format=YMD cfmgr_archive_saved_keep=4 cfmgr_archive_saved_set_id=set
    cfmgr_archive_saved_generation=9 cfmgr_store_snapshot=$fixture/config cfmgr_store_snapshot_bytes=1
}
cfmgr_store_lock_acquire() { :; }
cfmgr_store_archive_digest_admit() { :; }
cfmgr_store_digest() { cfmgr_store_digest_value=hash; }
cfmgr_store_run() { :; }
cfmgr_archive_plan_storage() { :; }
cfmgr_prerequisites_now() { cfmgr_probe_now=100; }
cfmgr_archive_destination() { :; }
cfmgr_archive_resources() { :; }
cfmgr_history_runtime_init() { :; }
cfmgr_storage_pin() { return 1; }
cfmgr_backup_history_observe() { cfmgr_history_has_payload=0; }
cfmgr_storage_release() { :; }
cfmgr_archive_stage_open() { :; }
cfmgr_archive_recognize_existing() { :; }
cfmgr_archive_choose_name() { :; }
cfmgr_archive_source_pin() { exec 3<"$fixture"; }
cfmgr_backup_history_lock() { exec 4<"$fixture"; cfmgr_history_lock_held=1; }
cfmgr_archive_capture_data() { (: <&3) && (: <&4); }
cfmgr_backup_history_release() { exec 4<&-; cfmgr_history_lock_held=0; }
cfmgr_archive_source_release() { exec 3<&-; }
cfmgr_archive_build() { if (: <&3) 2>/dev/null || (: <&4) 2>/dev/null; then return 2; fi; }
cfmgr_archive_format_hash() { cfmgr_format_hash=hash; }
cfmgr_archive_publish() {
    cfmgr_create_publish_attempted=1
    [ "$TEST_FAULT" != uncertain-publish ] || return 3
    cfmgr_create_published=1
}
cfmgr_archive_retention() { : >"$fixture/retention"; cfmgr_create_retention=complete; }
cfmgr_store_archive_save() {
    if (: <&3) 2>/dev/null || (: <&4) 2>/dev/null; then return 2; fi
    : >"$fixture/history-save"
    return 1
}
TEST_FAULT=FAULT
if cfmgr_archive_work; then code=0; else code=$?; fi
case $TEST_FAULT:$code in
uncertain-publish:3) [ ! -e "$fixture/retention" ] && [ ! -e "$fixture/history-save" ] ;;
history-save:0)
    [ -f "$fixture/retention" ] && [ -f "$fixture/history-save" ] &&
        [ "$cfmgr_create_result:$cfmgr_create_published:$cfmgr_create_history" = created:1:failed ] ;;
*) exit 81 ;;
esac
""".replace("TEST_FAULT=FAULT", "TEST_FAULT=" + fault),
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b""), result
