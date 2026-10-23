"""Filesystem publication and retention checks for manual archive creation."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pytest
from test_archive_io import archive as source_archive_fixture
from test_archive_io import passed, run
from test_prerequisites import shell as prerequisite_shell

archive = source_archive_fixture
shell = prerequisite_shell


def _quote_host_anchors(archive) -> None:
    backup_source = archive[0] / "modules/backup.sh"
    source = backup_source.read_text()
    if sys.platform == "darwin":
        source = source.replace("cd ${cfmgr_test_ram}", 'cd "${cfmgr_test_ram}"')
        source = source.replace(
            ' ${cfmgr_test_backup} "$cfmgr_backup_mount/CFMgr/backup"',
            ' "${cfmgr_test_backup}" "$cfmgr_backup_mount/CFMgr/backup"',
        )
    # The marker proves old/new validation reached the injected unlink failure.
    source = source.replace(
        "cfmgr_archive_run() {",
        """cfmgr_archive_run() {
    if [ "$1:${TEST_PURGE_FAIL:-0}" = archive-archive-remove:1 ]; then
        printf reached >"$cfmgr_store_context/purge-attempt"
        return 1
    fi
""",
        1,
    )
    backup_source.write_text(source)


def _old_archive(mount: Path, index: int, epoch: int) -> tuple[Path, str]:
    name = f"CFbackup-{epoch}.tar.gz"
    path = mount / "CFMgr/backup" / name
    data = f"verified prior archive {index}\n".encode()
    path.write_bytes(data)
    record = (
        f"ARCHIVE {name} {path.stat().st_ino} {len(data)} "
        f"{hashlib.sha256(data).hexdigest()} {epoch} 2026-10-17 "
        f"00000000-0000-4000-8000-{index:012d} END"
    )
    return path, record


def _transaction_script(old_names: list[str], *, failures: bool) -> str:
    names = " ".join(old_names)
    if failures:
        retention = f"""
# Changed bytes keep the same inode and block every old deletion.
printf changed >"$cfmgr_backup_mount/CFMgr/backup/$cfmgr_create_name"
if cfmgr_archive_retention; then exit 74; else [ "$?" = 1 ] || exit 75; fi
for old in {names}; do [ -f "$cfmgr_backup_mount/CFMgr/backup/$old" ] || exit 76; done
printf 'new verified archive' >"$cfmgr_backup_mount/CFMgr/backup/$cfmgr_create_name"
# A changed old candidate blocks pruning before any unlink.
printf changed >"$cfmgr_backup_mount/CFMgr/backup/{old_names[0]}"
if cfmgr_archive_retention; then exit 80; else [ "$?" = 1 ] || exit 81; fi
for old in {names}; do [ -f "$cfmgr_backup_mount/CFMgr/backup/$old" ] || exit 82; done
printf 'verified prior archive 1\n' >"$cfmgr_backup_mount/CFMgr/backup/{old_names[0]}"

# Inject the first unlink failure independently of host root permissions.
TEST_PURGE_FAIL=1
if cfmgr_archive_retention; then exit 83; else [ "$?" = 1 ] || exit 84; fi
[ -f "$cfmgr_store_context/purge-attempt" ] || exit 85
for old in {names}; do [ -f "$cfmgr_backup_mount/CFMgr/backup/$old" ] || exit 86; done
TEST_PURGE_FAIL=0

# Missing-new is last: recreation changes inode and must not conceal a later
# old-file or unlink check behind the new-file identity check.
rm "$cfmgr_backup_mount/CFMgr/backup/$cfmgr_create_name"
if cfmgr_archive_retention; then exit 77; else [ "$?" = 1 ] || exit 78; fi
for old in {names}; do [ -f "$cfmgr_backup_mount/CFMgr/backup/$old" ] || exit 79; done
printf 'new verified archive' >"$cfmgr_backup_mount/CFMgr/backup/$cfmgr_create_name"
"""
    else:
        retention = """
cfmgr_archive_retention || exit 87

# Publication collision leaves the candidate and published archive intact.
printf collision >"$cfmgr_archive_stage/candidate.tar.gz"
if cfmgr_archive_publish; then exit 88; else [ "$cfmgr_create_result" = collision ] || exit 89; fi
"""
    return f"""
cfmgr_store_fsync=/bin/true
cfmgr_store_mv=/bin/mv
TEST_PURGE_FAIL=0
cfmgr_archive_inventory_limit=1048576
cfmgr_archive_format_tracking=1
cfmgr_format_receipts=
cfmgr_create_ledger=$cfmgr_store_context/ledger
cfmgr_create_ledger_bytes=$(wc -c < "$cfmgr_create_ledger")
cfmgr_create_name=CFbackup-100.tar.gz
cfmgr_create_epoch=100 cfmgr_create_day=2026-10-17 cfmgr_create_id=00000000-0000-4000-8000-999999999999
cfmgr_create_published=0 cfmgr_create_result=
cfmgr_archive_saved_keep=3 cfmgr_create_scan_complete=1
cfmgr_archive_saved_set_id=00000000-0000-4000-8000-111111111111
cfmgr_archive_stage_leaf=stage cfmgr_archive_stage=$cfmgr_backup_mount/CFMgr/backup/stage
cfmgr_archive_format_inode "$cfmgr_archive_stage/candidate.tar.gz" || exit 71
cfmgr_format_owned=candidate.tar.gz:$cfmgr_format_inode
cfmgr_archive_identity_check || exit 72
if [ "$TEST_LINUX" = 0 ]; then
    # macOS lacks the fixture's native directory-fsync descriptor contract.
    cfmgr_archive_flush_owned() {{ cfmgr_archive_identity_check; }}
    # The host fixture has no /proc/uptime; use a monotonically advancing clock.
    cfmgr_prerequisites_now() {{ cfmgr_probe_now=$((cfmgr_probe_now + 1)); }}
fi
cfmgr_archive_publish || exit 73
[ "$cfmgr_create_published" = 1 ] && [ -z "$cfmgr_format_owned" ] || exit 90
[ ! -e "$cfmgr_archive_stage/candidate.tar.gz" ] || exit 91
{retention}
"""


def test_publish_and_retention_preserve_new_archive_and_retention_limit(archive, shell):
    _quote_host_anchors(archive)
    _support, ram, mount, stage, _environment = archive
    old = [_old_archive(mount, index, 200 + index) for index in range(1, 5)]
    (mount / "CFMgr/backup/notes.txt").write_text("leave me")
    diagnostics = mount / "CFMgr/diagnostics"
    diagnostics.mkdir()
    (diagnostics / "report").write_text("preserve diagnostics")
    candidate = stage / "candidate.tar.gz"
    data = b"new verified archive"
    candidate.write_bytes(data)
    original_inode = candidate.stat().st_ino
    (ram / "ledger").write_text("\n".join(record for _path, record in old) + "\n")

    result = run(
        archive,
        shell,
        _transaction_script([path.name for path, _ in old], failures=False),
        timeout=45,
    )
    passed(result)

    backup = mount / "CFMgr/backup"
    published = backup / "CFbackup-100.tar.gz"
    assert published.read_bytes() == data
    assert published.stat().st_ino == original_inode
    assert candidate.read_bytes() == b"collision"
    assert {path.name for path, _record in old if path.exists()} == {
        old[-1][0].name,
        old[-2][0].name,
    }
    assert (backup / "notes.txt").read_text() == "leave me"
    assert (diagnostics / "report").read_text() == "preserve diagnostics"


def test_retention_blocks_old_deletion_on_changed_new_or_old_and_keeps_new_on_purge_failure(
    archive, shell
):
    _quote_host_anchors(archive)
    _support, ram, mount, stage, _environment = archive
    old = [_old_archive(mount, index, 200 + index) for index in range(1, 5)]
    candidate = stage / "candidate.tar.gz"
    data = b"new verified archive"
    candidate.write_bytes(data)
    (ram / "ledger").write_text("\n".join(record for _path, record in old) + "\n")

    result = run(
        archive,
        shell,
        _transaction_script([path.name for path, _ in old], failures=True),
        timeout=45,
    )
    passed(result)

    published = mount / "CFMgr/backup/CFbackup-100.tar.gz"
    assert published.read_bytes() == data
    assert all(path.exists() for path, _record in old)
    assert (ram / "purge-attempt").read_text() == "reached"


@pytest.mark.parametrize("move", ["intact", "moved", "moved-detached"])
def test_failed_publication_requires_positive_nonpublication_proof(
    archive, shell, move
):
    _quote_host_anchors(archive)
    support, ram, mount, stage, environment = archive
    environment["TEST_MOVE"] = move
    source = support / "modules/backup.sh"
    source.write_text(
        source.read_text().replace(
            "cfmgr_archive_run() {", "cfmgr_test_archive_run() {", 1
        )
    )
    (ram / "ledger").write_bytes(b"")
    (stage / "candidate.tar.gz").write_bytes(b"verified candidate")
    prefix = _transaction_script([], failures=False).split(
        "cfmgr_archive_publish || exit 73", 1
    )[0]
    script = (
        r"""
cfmgr_archive_run() {
    if [ "$1" = archive-publish ]; then
        case $TEST_MOVE in
        moved) cfmgr_test_archive_run "$@" || return $? ;;
        moved-detached)
            cfmgr_test_archive_run "$@" || return $?
            cfmgr_archive_identity_check() { return 1; }
            return 0 ;;
        esac
        return 1
    fi
    cfmgr_test_archive_run "$@"
}
"""
        + prefix
        + r"""
cfmgr_create_name_hex=-
if cfmgr_archive_publish; then exit 92; else code=$?; fi
[ "$cfmgr_create_publish_attempted:$cfmgr_create_published:$cfmgr_create_name_hex" = 1:0:- ] || exit 93
case $TEST_MOVE:$code in intact:1 | moved:3 | moved-detached:3) ;; *) exit 94 ;; esac
[ ! -s "$cfmgr_create_ledger" ] || exit 95
"""
    )
    passed(run(archive, shell, script, timeout=30))
    assert (mount / "CFMgr/backup/CFbackup-100.tar.gz").exists() == (move != "intact")
    assert (stage / "candidate.tar.gz").exists() == (move == "intact")


def test_incomplete_scan_blocks_every_retention_operation(archive, shell):
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_create_published=1 cfmgr_create_scan_complete=0
cfmgr_archive_run() { : >"$ram/retention-operation"; return 1; }
if cfmgr_archive_retention; then exit 81; else [ "$?" = 1 ] || exit 82; fi
[ "$cfmgr_create_retention" = failed ] && [ ! -e "$ram/retention-operation" ]
""",
        )
    )


def test_unclassified_gunzip_failure_is_incomplete_not_excluded(archive, shell):
    _quote_host_anchors(archive)
    _support, _ram, mount, _stage, _environment = archive
    container = mount / "CFMgr/backup/CFbackup-bad.tar.gz"
    container.write_bytes(b"unclassified decompression failure\n")
    container.chmod(0o777)
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_inventory_limit=1048576 cfmgr_archive_format_tracking=1
cfmgr_archive_space_reserve() { return 0; }
cfmgr_archive_space() { cfmgr_archive_free=16777216; }
cfmgr_create_existing_status=excluded
if cfmgr_archive_existing CFbackup-bad.tar.gz; then exit 81; else [ "$?" = 1 ] || exit 82; fi
[ "$cfmgr_create_existing_status:$cfmgr_probe_status" = incomplete:reaped ] || exit 83
""",
            timeout=30,
        )
    )


def test_real_yaml_budget_failure_leaves_inspection_incomplete(archive, shell):
    stage = archive[3]
    yaml = (
        b"tunnel: 8ea7c314-f0cd-4ca9-813e-44bbdeaa4001\n"
        b"credentials-file: /opt/etc/cloudflared/selected.json\n"
    )
    (stage / "raw").write_bytes(b"classification boundary")
    (stage / "yaml.hex").write_text("".join(f"{byte:02x}\n" for byte in yaml))
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_inventory_limit=65536 cfmgr_format_owned=''
_cfmgr_archive_format_verify() {
    cfmgr_archive_run archive-payload-yaml 4096 "$cfmgr_store_awk" "$support/modules/backup.sh" "$stage/yaml.hex" 128
}
if cfmgr_archive_format_verify "$stage/raw" 12345678-1234-4abc-8abc-123456789abc; then exit 81; else [ "$?" = 1 ] || exit 82; fi
cfmgr_store_read_line "$cfmgr_probe_stdout" || exit 83
[ "$cfmgr_store_line" = 'CFMGR-YAML-ERROR 1 metadata-limit END' ] || exit 84
[ "$cfmgr_archive_verification_status" = incomplete ] || exit 85
cfmgr_create_published=1 cfmgr_create_scan_complete=0
cfmgr_archive_run() { : >"$ram/retention-operation"; return 1; }
if cfmgr_archive_retention; then exit 86; else [ "$?" = 1 ] || exit 87; fi
[ "$cfmgr_create_retention" = failed ] && [ ! -e "$ram/retention-operation" ]
""",
        )
    )


def test_preverification_failure_resets_prior_exclusion(archive, shell):
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_verification_status=excluded
cfmgr_format_owned=''
cfmgr_archive_format_retire() { return 1; }
if cfmgr_archive_verify_owned unused; then exit 81; else [ "$?" = 1 ] || exit 82; fi
[ "$cfmgr_archive_verification_status" = incomplete ]
""",
        )
    )


@pytest.mark.parametrize("status,complete", [("excluded", "1"), ("incomplete", "0")])
def test_recognition_propagates_complete_candidate_inspection(
    archive, shell, status, complete
):
    _quote_host_anchors(archive)
    _support, _ram, mount, _stage, environment = archive
    for day in ("01", "02"):
        (mount / f"CFMgr/backup/CFbackup-2000-01-{day}.tar.gz").write_bytes(
            b"candidate"
        )
    environment.update(TEST_STATUS=status, TEST_COMPLETE=complete)
    if sys.platform == "darwin":
        worker = archive[0] / "modules/helpers/worker.sh"
        worker.write_text(worker.read_text().replace('ulimit -v "$3" || exit 2', ":"))
    passed(
        run(
            archive,
            shell,
            r"""
cfmgr_archive_inventory_limit=65536 cfmgr_archive_directory_kib=16384
cfmgr_archive_format_tracking=1 cfmgr_create_inspections=0
cfmgr_archive_deadline=$((cfmgr_probe_now+100))
if [ "$TEST_LINUX" = 0 ]; then cfmgr_prerequisites_now() { cfmgr_probe_now=100; }; fi
cfmgr_archive_existing() {
    cfmgr_create_inspections=$((cfmgr_create_inspections+1))
    case $cfmgr_create_inspections in 1) cfmgr_create_existing_status=$TEST_STATUS; return 1 ;; esac
    cfmgr_create_existing_status=verified
}
cfmgr_archive_recognize_existing || exit 81
[ "$cfmgr_create_inspections:$cfmgr_create_scan_complete" = "2:$TEST_COMPLETE" ] || exit 82
""",
            timeout=20,
        )
    )
