"""Backup destination identity and same-context scoped Store integration.

Host adapters replace mount/native admission only; real parser, transaction,
filesystem, lock and fixed probe remain. Mount fixtures separately prove Linux
namespace/FD identity, noexec admission and replacement safety.
"""

from __future__ import annotations

import json
import shlex
import subprocess

import pytest
from test_config_store import ADAPTER, ROOT, run_store
from test_config_store import commands as config_commands
from test_config_store import config as store_config
from test_config_store import legacy_fsync as store_fsync
from test_config_store import store_fixture as config_store_fixture
from test_install import shell as install_shell
from test_install import tools as install_tools

shell = install_shell
tools = install_tools
store_fixture = config_store_fixture
commands = config_commands
config = store_config
legacy_fsync = store_fsync


@pytest.mark.parametrize(
    "filesystem,identity,accepted",
    [
        ("ext4", 'UUID="ABCD-1234" TYPE="ext4"', True),
        ("vfat", 'LABEL="Duplicate Drive" UUID="ABCD-1234" TYPE="vfat"', True),
        ("tfat", 'UUID="ABCD-1234" TYPE="vfat"', True),
        ("fuseblk", 'UUID="0123456789ABCDEF" TYPE="ntfs"', True),
        ("ufsd", 'UUID="0123456789ABCDEF" TYPE="ntfs"', True),
        ("ufsd", 'UUID="0123456789ABCDEF" TYPE="hfsplus"', True),
        ("ufsd", 'UUID="0123456789ABCDEF"', False),
        ("tfat", 'UUID="ABCD-1234" TYPE="ntfs"', False),
        ("vfat", 'TYPE="vfat"', False),
        ("vfat", 'UUID="a" UUID="b" TYPE="vfat"', False),
    ],
)
def test_backup_uuid_policy_is_independent_of_entware_guid(
    shell, tools, tmp_path, filesystem, identity, accepted
):
    output = tmp_path / "blkid"
    output.write_text("/dev/fixture: " + identity + "\n")
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; cfmgr_store_awk=$2; cfmgr_backup_device_path=/dev/fixture; cfmgr_backup_filesystem=$3; cfmgr_backup_uuid_parse "$4" || exit $?; printf "%s\\n%s\\n" "$cfmgr_backup_uuid" "$cfmgr_backup_label"',
            "backup-identity",
            ROOT / "modules/backup.sh",
            tools["awk"],
            filesystem,
            output,
        ],
        check=False,
        capture_output=True,
        timeout=3,
    )
    assert (result.returncode == 0) is accepted, result.stderr
    if accepted:
        assert result.stdout.splitlines()[0] in (b"abcd-1234", b"0123456789abcdef")


def test_hex_display_helper_preserves_literal_data_and_rejects_bad_frames(shell):
    values = ["/tmp/mnt/Drive name\\literal", "Duplicate Drive", "e;$(touch x)"]
    script = '. "$1"; shift; for item do cfmgr_backup_decode "$item" || exit 1; done'
    good = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "backup-decode",
            ROOT / "modules/backup.sh",
            *[s.encode().hex() for s in values],
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (good.returncode, good.stdout, good.stderr) == (
        0,
        ("\n".join(values) + "\n").encode(),
        b"",
    )
    for encoded in ("", "abc", "AA", "00", "0a", "09", "c3a9", "20" * 1025):
        result = subprocess.run(
            [
                *shell,
                "-c",
                script,
                "backup-decode",
                ROOT / "modules/backup.sh",
                encoded,
            ],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert result.returncode == 1 and result.stdout == b""


@pytest.fixture
def backup_fixture(store_fixture):
    source, ram, *_ = store_fixture
    for relative in ("modules/backup.sh", "modules/lib/storage.sh"):
        destination = source / relative
        destination.write_bytes((ROOT / relative).read_bytes())
    drive = ram / "Drive with spaces"
    drive.mkdir()
    return store_fixture


# Private mount-policy adapter. These tests prove the real backup_action ->
# INTERNAL Store route without requiring mounted disks on a contributor's host.
# Real mount/FD policy remains in tests/fixtures/storage_mounts.sh.
BACKUP_ADAPTER = ADAPTER.replace(
    'cfmgr_config_store "$@"',
    r"""
. "$source/modules/lib/storage.sh"
. "$source/modules/backup.sh"
cfmgr_store_native_tool() { case $1 in /sbin/blkid) return 0 ;; *) [ -x "$1" ] ;; esac; }
cfmgr_backup_attached() { [ ! -e "$ram/lost" ]; }
cfmgr_store_attachment_ok() {
    [ -d "$cfmgr_store_context" ] && [ ! -L "$cfmgr_store_context" ] || return 1
    [ "${cfmgr_store_backup_gate:-0}" != 1 ] || cfmgr_backup_attached
}
cfmgr_backup_pin_selected() {
    [ "$cfmgr_backup_want_snapshot" = snapshot ] || return 1
    cfmgr_backup_mount="$ram/Drive with spaces" cfmgr_backup_pinned=1 cfmgr_store_backup_gate=1
    cfmgr_backup_attached
}
cfmgr_backup_prepare_folder() {
    [ "$cfmgr_config_lock_fd0" = 1 ] || return 99
    cfmgr_backup_attached || return 1
    if [ ! -d "$cfmgr_backup_mount/CFMgr/backup" ]; then mkdir -p "$cfmgr_backup_mount/CFMgr/backup"; fi
}
cfmgr_backup_check_saved() {
    cfmgr_backup_availability=none
    [ "$cfmgr_backup_saved_present" != 1 ] || cfmgr_backup_availability=unavailable
}
cfmgr_backup_action "$@"
""",
)

DESTINATION = {
    "schema": 1,
    "mountpoint": "/tmp/mnt/Drive with spaces\\literal",
    "uuid": "abcd-1234",
    "filesystem": "vfat",
    "root": "/",
}


def selection(snapshot="snapshot"):
    return tuple(
        value.encode().hex()
        for value in [
            *(DESTINATION[key] for key in ("mountpoint", "uuid", "filesystem", "root")),
            snapshot,
        ]
    )


def test_backend_save_is_scoped_noop_and_saved_missing_is_readable(
    shell, tools, backup_fixture
):
    source, ram, *_ = backup_fixture
    before = (source / "config").read_bytes()
    result = run_store(
        shell, tools, backup_fixture, "save", *selection(), script=BACKUP_ADAPTER
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout.startswith(
        b"CFMGR-BACKUP 1 saved 2 0 available 0 END\nCFMGR-BACKUP-DEST 1 "
    )
    expected = before.replace(b'"generation":1', b'"generation":2').replace(
        b'"destination":null',
        b'"destination":' + json.dumps(DESTINATION, separators=(",", ":")).encode(),
    )
    assert (source / "config").read_bytes() == expected
    assert (ram / "Drive with spaces/CFMgr/backup").is_dir()
    noop = run_store(
        shell, tools, backup_fixture, "save", *selection(), script=BACKUP_ADAPTER
    )
    assert noop.returncode == 0 and b"unchanged 2 0 available" in noop.stdout
    assert (source / "config").read_bytes() == expected
    missing = run_store(shell, tools, backup_fixture, "check", script=BACKUP_ADAPTER)
    assert missing.returncode == 0 and b"checked 2 0 unavailable" in missing.stdout
    assert b"CFMGR-BACKUP-DEST 1 " in missing.stdout
    assert not (ram / "context").exists()


def test_drive_loss_before_publication_preserves_inert_folder_and_jffs_recovery(
    shell, tools, backup_fixture
):
    source, ram, *_ = backup_fixture
    before = (source / "config").read_bytes()
    script = BACKUP_ADAPTER.replace(
        "*/.config-save)\n",
        '*/.config-save)\n            : >"$ram/lost"\n',
    )
    stopped = run_store(
        shell, tools, backup_fixture, "save", *selection(), script=script
    )
    assert stopped.returncode == 1, (stopped.stdout, stopped.stderr)
    assert stopped.stdout == b"CFMGR-BACKUP 1 recovery 0 1 unavailable 0 END\n"
    assert (source / "config").read_bytes() == before
    assert (ram / "Drive with spaces/CFMgr/backup").is_dir()
    assert list(source.glob(".config-save*"))
    # Recovery is native/JFFS-only; it never calls backup_pin/preparation or
    # replays the candidate while the exact old generation remains live.
    recovered = run_store(
        shell, tools, backup_fixture, "recover", script=BACKUP_ADAPTER
    )
    assert recovered.returncode == 0, (recovered.stdout, recovered.stderr)
    assert recovered.stdout == b"CFMGR-BACKUP 1 recovered 1 0 none 0 END\n"
    assert (source / "config").read_bytes() == before
    assert (ram / "Drive with spaces/CFMgr/backup").is_dir()
    assert not list(source.glob(".config-save*"))


def test_drive_loss_after_publication_preserves_candidate_until_verified_recovery(
    shell, tools, backup_fixture
):
    source, ram, *_ = backup_fixture
    before = (source / "config").read_bytes()
    script = BACKUP_ADAPTER.replace(
        "post-publish-flush) published=1 ;;",
        'post-publish-loss) : >"$ram/lost" ;;\n'
        "        post-publish-flush) published=1 ;;",
    )
    assert script != BACKUP_ADAPTER
    stopped = run_store(
        shell,
        tools,
        backup_fixture,
        "save",
        *selection(),
        scenario="post-publish-loss",
        script=script,
    )
    assert stopped.returncode == 1, (stopped.stdout, stopped.stderr)
    assert stopped.stdout == b"CFMGR-BACKUP 1 recovery 0 1 unavailable 0 END\n"
    candidate = (source / "config").read_bytes()
    current = json.loads(candidate)
    assert current["generation"] == 2
    assert current["backup"]["destination"] == DESTINATION
    guard = source / ".config-save"
    assert (guard / "old").read_bytes() == before
    intent = (guard / "intent").read_bytes()
    assert (ram / "Drive with spaces/CFMgr/backup").is_dir()
    # An exposed recovery flush error cannot erase evidence or claim recovery.
    failed = run_store(
        shell,
        tools,
        backup_fixture,
        "recover",
        scenario="flush-error",
        script=BACKUP_ADAPTER,
    )
    assert failed.returncode == 1, (failed.stdout, failed.stderr)
    assert failed.stdout == b"CFMGR-BACKUP 1 recovery 0 1 unavailable 0 END\n"
    assert (source / "config").read_bytes() == candidate
    assert (guard / "old").read_bytes() == before
    assert (guard / "intent").read_bytes() == intent
    # JFFS-only recovery verifies the committed candidate without the drive.
    recovered = run_store(
        shell, tools, backup_fixture, "recover", script=BACKUP_ADAPTER
    )
    assert recovered.returncode == 0, (recovered.stdout, recovered.stderr)
    assert recovered.stdout.startswith(
        b"CFMGR-BACKUP 1 recovered 2 0 unavailable 0 END\n"
    )
    assert b"CFMGR-BACKUP-DEST 1 " in recovered.stdout
    assert (source / "config").read_bytes() == candidate
    assert (ram / "Drive with spaces/CFMgr/backup").is_dir()
    assert not list(source.glob(".config-save*"))


def test_stale_selection_and_read_only_check_never_prepare_folder(
    shell, tools, backup_fixture
):
    source, ram, *_ = backup_fixture
    before = (source / "config").read_bytes()
    result = run_store(
        shell,
        tools,
        backup_fixture,
        "save",
        *selection("old snapshot"),
        script=BACKUP_ADAPTER,
    )
    assert result.returncode == 1 and b" unavailable " in result.stdout
    assert not (ram / "Drive with spaces/CFMgr/backup").exists()
    checked = run_store(shell, tools, backup_fixture, "check", script=BACKUP_ADAPTER)
    assert (
        checked.returncode == 0
        and checked.stdout == b"CFMGR-BACKUP 1 checked 1 0 none 0 END\n"
    )
    assert (source / "config").read_bytes() == before
    assert not (ram / "Drive with spaces/CFMgr/backup").exists()


def test_busy_or_pending_save_never_prepares_folder(shell, tools, backup_fixture):
    import fcntl

    source, ram, *_ = backup_fixture
    lock = ram / "config.lock"
    lock.touch(mode=0o600)
    before = (source / "config").read_bytes()
    with lock.open("r+b") as owner:
        fcntl.flock(owner, fcntl.LOCK_EX | fcntl.LOCK_NB)
        result = run_store(
            shell, tools, backup_fixture, "save", *selection(), script=BACKUP_ADAPTER
        )
        assert result.returncode == 1 and b"busy 0 0 unavailable" in result.stdout
    assert not (ram / "Drive with spaces/CFMgr/backup").exists()
    (source / ".config-save").mkdir(mode=0o700)
    pending = run_store(
        shell, tools, backup_fixture, "save", *selection(), script=BACKUP_ADAPTER
    )
    assert pending.returncode == 1 and b"recovery 0 1 unavailable" in pending.stdout
    assert not (ram / "Drive with spaces/CFMgr/backup").exists()
    assert (source / "config").read_bytes() == before


@pytest.mark.parametrize("fault", ["normal", "changed"])
def test_list_frames_duplicate_labels_literal_paths_and_no_partial_success(
    shell, tools, backup_fixture, fault
):
    source, ram, *_ = backup_fixture
    points = ["/tmp/mnt/Drive one\\literal", "/tmp/mnt/nested/Drive two"]
    records = [
        f"{index}\t1\t8:{index}\t/\t{point}\tvfat\t/dev/fixture{index}\trw,noexec\trw"
        for index, point in enumerate(points, 20)
    ]
    setup = f"record1={shlex.quote(records[0])}\nrecord2={shlex.quote(records[1])}\n"
    adapter = BACKUP_ADAPTER.replace(
        "case $mode in\n",
        "case $mode in\n"
        '    store-backup-mounts) printf \'%s\\tprivate\\n\' "$record1" "$record2" >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"; cfmgr_probe_exit=0; return 0 ;;\n',
        1,
    ).replace(
        'cfmgr_backup_action "$@"',
        r"""
cfmgr_backup_mount_record() {
    IFS='\t' read -r cfmgr_backup_id unused unused cfmgr_backup_root cfmgr_backup_mount cfmgr_backup_filesystem unused unused unused unused <<EOF_RECORD
$1
EOF_RECORD
    case $cfmgr_backup_id in 20) cfmgr_backup_snapshot=$record1 ;; 21) cfmgr_backup_snapshot=$record2 ;; *) return 1 ;; esac
}
cfmgr_backup_observe_uuid() { cfmgr_backup_uuid=abcd-1234 cfmgr_backup_label='Duplicate Drive'; }
cfmgr_backup_observe_mount() {
    [ "$scenario" != changed ] || return 1
    case $1 in
    '/tmp/mnt/Drive one\literal') cfmgr_backup_mount_record "$record1" ;;
    '/tmp/mnt/nested/Drive two') cfmgr_backup_mount_record "$record2" ;;
    *) return 1 ;;
    esac
}
cfmgr_backup_action "$@"
""".replace("IFS='\\t'", "IFS='\t'"),
    )
    result = run_store(
        shell, tools, backup_fixture, "list", scenario=fault, script=setup + adapter
    )
    if fault == "changed":
        assert result.returncode == 1
        assert result.stdout == b"CFMGR-BACKUP 1 unavailable 0 0 unavailable 0 END\n"
    else:
        assert result.returncode == 0, (result.stdout, result.stderr)
        lines = result.stdout.decode().splitlines()
        assert lines[0] == "CFMGR-BACKUP 1 list 1 0 none 2 END"
        assert len(lines) == 3
        for index, line in enumerate(lines[1:]):
            fields = line.split()
            assert fields[:3] == ["CFMGR-BACKUP-DRIVE", "1", str(index + 1)]
            assert bytes.fromhex(fields[3]).decode() == "Duplicate Drive"
            assert bytes.fromhex(fields[4]).decode() == points[index]
            assert bytes.fromhex(fields[8]).decode() == records[index]
            assert fields[9:] == ["END"]
    assert result.stderr == b""
    assert not (ram / "Drive with spaces/CFMgr/backup").exists()
    assert not (ram / "config.lock").exists()
    assert json.loads((source / "config").read_bytes())["backup"]["destination"] is None
