"""Archive filename admission, retention ordering, and resource bounds."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
from pathlib import Path

import pytest
from runtime_awk import awk_arguments
from test_prerequisites import shell as prerequisite_shell

shell = prerequisite_shell

ROOT = Path(__file__).resolve().parents[1]
CONTROL = "cfmgr-parser:backup_archive_control"
RESOURCES = ROOT / "modules/backup.sh"
IO = ROOT / "modules/backup.sh"
UUID = "01234567-89ab-cdef-0123-456789abcdef"
NEW = "CFbackup-100.tar.gz"


@pytest.fixture(scope="module")
def awk_programs() -> list[tuple[str, list[str]]]:
    host = shutil.which("awk")
    assert host, "Host awk is required for archive control tests"
    programs = [("host awk", [host])]
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        selected = shlex.split(os.environ.get("CFMGR_TEST_SHELL", ""))
        assert selected[:2] == ["busybox", "ash"]
        busybox = shutil.which("busybox")
        expected = ROOT / ".tmp/native-busybox/bin/busybox"
        assert busybox and Path(busybox).resolve() == expected.resolve()
        programs.append(("pinned BusyBox awk", [busybox, "awk"]))
    return programs


def _invoke(
    awk: list[str],
    data: bytes,
    mode: str,
    *,
    tmp_path: Path | None = None,
    keep: str = "3",
    new: str = NEW,
):
    environment = {
        **os.environ,
        "LC_ALL": "C",
        "CFMGR_ARCHIVE_CONTROL_MODE": mode,
        "CFMGR_ARCHIVE_KEEP": keep,
        "CFMGR_ARCHIVE_NEW_NAME": new,
    }
    command = [*awk, "-f", str(CONTROL)]
    if mode in {"retention", "browse"}:
        assert tmp_path is not None
        ledger = tmp_path / "ledger.receipt"
        ledger.write_bytes(data)
        command.append(str(ledger))
        data = b""
    return subprocess.run(
        awk_arguments(command),
        input=data,
        env=environment,
        capture_output=True,
        check=False,
        timeout=5,
    )


def _record(name: str, epoch: int, archive_id: str, *, day="2026-10-17") -> str:
    return f"ARCHIVE {name} 123 4096 {'a' * 64} {epoch} {day} {archive_id} END"


def _ledger(records: list[str]) -> bytes:
    return ("\n".join(records) + "\n").encode()


def test_names_mode_selects_only_admitted_archive_basenames(awk_programs):
    names = [
        NEW,
        "CFbackup-1700000000_2026-10-17.tar.gz",
        "foreign.tar.gz",
        "CFbackup-nope.tar.gz",
        "CFbackup-1.tar",
        "-CFbackup-1.tar.gz",
        "/CFbackup-2.tar.gz",
        "CFbackup-3.tar.gz/../../outside",
        "CFbackup-4.tar.gz -> /foreign/target",
        "CFbackup-1--2.tar.gz",
        "CFbackup-1__2.tar.gz",
    ]
    expected = (NEW + "\nCFbackup-1700000000_2026-10-17.tar.gz\n").encode()
    for _label, awk in awk_programs:
        result = _invoke(awk, ("\n".join(names) + "\n").encode(), "names")
        assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")


def test_browser_review_projects_actual_states_paths_and_history_without_secrets(
    awk_programs, tmp_path
):
    plan = tmp_path / "plan"
    capture = tmp_path / "capture"
    inventory = tmp_path / "inventory"
    secret = "never-display-this-token"
    plan.write_text(
        "CFMGR-PAYLOAD-PLAN 1 2 7\n"
        "STATE ddns 1 0\nSTATE ip_sync 0 0\nSTATE cloudflared 0 0\n"
        "CLOUD token 0 0 1 1 private-runtime-ref private-cert-ref private-account private-tunnel\n"
        "LOG ddns 1 0 1 deadbeef\nLOG ip_sync 0 0 0 -\nLOG cloudflared 0 0 0 -\n"
        f"AUTH private json account tunnel {secret.encode().hex()}\n"
        f"STORAGE source-uuid ext4 {b'/'.hex()} {b'etc/cloudflared'.hex()}\n"
        "END 12\n"
    )
    capture.write_text(
        "CFMGR-CAPTURE-PLAN 1 2 7\n"
        f"AUTH private account tunnel {secret.encode().hex()}\n"
        f"EXTERNAL data.cloudflared.yaml {b'/opt/foreign-ca.pem'.hex()} input-reference\nEND 3\n"
    )
    path = b"addons/CFMgr.d/setup-drafts".hex()
    inventory.write_text(
        "CFMGR-INVENTORY 1\n"
        f"FILE p00000003 data.setup-drafts jffs {path} 7 0600 42 {'a' * 64} whole\n"
        "NOTE history.ddns unavailable - entware-unavailable END\nEND 1 1 42\n"
    )
    for _label, awk in awk_programs:
        result = subprocess.run(
            awk_arguments(
                [*awk, "-f", CONTROL, str(plan), str(capture), str(inventory)]
            ),
            env={**os.environ, "LC_ALL": "C", "CFMGR_ARCHIVE_CONTROL_MODE": "review"},
            capture_output=True,
            check=False,
            timeout=5,
        )
        assert (result.returncode, result.stderr) == (0, b"")
        output = result.stdout.decode()
        assert "STATE ddns 1 0 END" in output
        assert "CLOUD token 0 0 1 1 END" in output
        assert "LOG ddns 1 0 1 1 END" in output
        assert f"FILE data.setup-drafts jffs {path} 42 whole END" in output
        assert "NOTE history.ddns unavailable - entware-unavailable END" in output
        assert "EXTERNAL data.cloudflared.yaml" in output
        assert "CURRENT readiness-unknown auth-unknown END" in output
        for forbidden in (
            secret,
            secret.encode().hex(),
            "AUTH",
            "private-",
            "deadbeef",
        ):
            assert forbidden not in output
        # A malformed projected column cannot partially expose earlier rows.
        bad = plan.read_text().replace("STATE ddns 1 0", "STATE ddns 1 secret")
        original = plan.read_text()
        plan.write_text(bad)
        rejected = subprocess.run(
            awk_arguments(
                [*awk, "-f", CONTROL, str(plan), str(capture), str(inventory)]
            ),
            env={**os.environ, "LC_ALL": "C", "CFMGR_ARCHIVE_CONTROL_MODE": "review"},
            capture_output=True,
            check=False,
            timeout=5,
        )
        assert (rejected.returncode, rejected.stdout) == (1, b"")
        plan.write_text(original)


def test_browser_list_orders_manifest_chronology_with_deterministic_ties(
    awk_programs, tmp_path
):
    def row(name, epoch, archive_id):
        return (
            f"BROWSE {name} {UUID} {archive_id} {epoch} "
            "2026-11-01 01-30-00 55544330 +0000 DMY 2 7 END"
        )

    older = row("CFbackup-999.tar.gz", 9, UUID)
    tied_a = row("CFbackup-001.tar.gz", 10, UUID)
    tied_b = row("CFbackup-002.tar.gz", 10, UUID)
    latest_id = "11234567-89ab-cdef-0123-456789abcdef"
    newest = row("CFbackup-000.tar.gz", 10, latest_id)
    for _label, awk in awk_programs:
        for rows in ([tied_a, newest, older, tied_b], [tied_b, older, newest, tied_a]):
            result = _invoke(awk, _ledger(rows), "browse", tmp_path=tmp_path)
            assert (result.returncode, result.stderr) == (0, b"")
            assert result.stdout.decode().splitlines() == [
                f"CFMGR-ARCHIVE-ITEM 1 {index} {record.removeprefix('BROWSE ')}"
                for index, record in enumerate([newest, tied_b, tied_a, older], 1)
            ]
        rejected = _invoke(awk, _ledger([tied_a, tied_a]), "browse", tmp_path=tmp_path)
        assert (rejected.returncode, rejected.stdout) == (1, b"")


def test_retention_keeps_new_after_clock_rollback_and_orders_by_epoch(
    awk_programs, tmp_path
):
    # Filenames, dates around a DST boundary, and input order disagree with
    # chronology. Epoch ordering is absolute; the new archive survives rollback.
    records = [
        _record(
            "CFbackup-001.tar.gz",
            1,
            "00000000-0000-0000-0000-000000000001",
            day="2026-11-02",
        ),
        _record(NEW, 5, UUID, day="2026-11-01"),
        _record(
            "CFbackup-999.tar.gz",
            20,
            "00000000-0000-0000-0000-000000000020",
            day="2026-10-31",
        ),
        _record(
            "CFbackup-002.tar.gz",
            10,
            "00000000-0000-0000-0000-000000000010",
            day="2026-11-01",
        ),
    ]
    for _label, awk in awk_programs:
        result = _invoke(
            awk, _ledger(records), "retention", tmp_path=tmp_path, keep="3"
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            (
                _record(
                    "CFbackup-001.tar.gz",
                    1,
                    "00000000-0000-0000-0000-000000000001",
                    day="2026-11-02",
                )
                + "\n"
            ).encode(),
            b"",
        )


def test_retention_uses_uuid_then_name_for_epoch_ties_deterministically(
    awk_programs, tmp_path
):
    same_uuid = "00000000-0000-0000-0000-000000000001"
    records = [
        _record("CFbackup-010.tar.gz", 50, same_uuid),
        _record(NEW, 1, UUID),
        _record("CFbackup-009.tar.gz", 50, "00000000-0000-0000-0000-000000000001"),
        _record("CFbackup-011.tar.gz", 50, "00000000-0000-0000-0000-000000000002"),
    ]
    expected = (_record("CFbackup-009.tar.gz", 50, same_uuid) + "\n").encode()
    for _label, awk in awk_programs:
        first = _invoke(awk, _ledger(records), "retention", tmp_path=tmp_path, keep="3")
        second = _invoke(
            awk,
            _ledger(list(reversed(records))),
            "retention",
            tmp_path=tmp_path,
            keep="3",
        )
        assert (first.returncode, first.stdout, first.stderr) == (0, expected, b"")
        assert (second.returncode, second.stdout, second.stderr) == (0, expected, b"")


def test_retention_emits_removals_oldest_first_independent_of_input_order(
    awk_programs, tmp_path
):
    uuid_a = "00000000-0000-0000-0000-000000000001"
    uuid_b = "00000000-0000-0000-0000-000000000002"
    records = [
        _record("CFbackup-20.tar.gz", 2, uuid_b),
        _record("CFbackup-2.tar.gz", 2, uuid_a),
        _record("CFbackup-30.tar.gz", 30, uuid_a),
        _record("CFbackup-1.tar.gz", 1, uuid_a),
        _record("CFbackup-10.tar.gz", 2, uuid_a),
        _record("CFbackup-40.tar.gz", 40, uuid_b),
        _record(NEW, 0, UUID),
    ]
    expected = _ledger(
        [
            _record("CFbackup-1.tar.gz", 1, uuid_a),
            _record("CFbackup-10.tar.gz", 2, uuid_a),
            _record("CFbackup-2.tar.gz", 2, uuid_a),
            _record("CFbackup-20.tar.gz", 2, uuid_b),
        ]
    )
    for _label, awk in awk_programs:
        result = _invoke(awk, _ledger(records), "retention", tmp_path=tmp_path)
        assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")


@pytest.mark.parametrize(
    "bad_record",
    [
        "ARCHIVE broken.tar.gz 123 1 " + "a" * 64 + " 1 2026-10-17 " + UUID + " END",
        f"ARCHIVE CFbackup-1.tar.gz 0 1 {'a' * 64} 1 2026-10-17 {UUID} END",
        f"ARCHIVE CFbackup-1.tar.gz 123 -1 {'a' * 64} 1 2026-10-17 {UUID} END",
        f"ARCHIVE CFbackup-1.tar.gz 123 1 {'A' * 64} 1 2026-10-17 {UUID} END",
        f"ARCHIVE CFbackup-1.tar.gz 123 1 {'a' * 64} 01 2026-10-17 {UUID} END",
        f"ARCHIVE CFbackup-1.tar.gz 123 1 {'a' * 64} 1 2026-1-01 {UUID} END",
        f"ARCHIVE CFbackup-1.tar.gz 123 1 {'a' * 64} 1 2026-10-17 not-a-uuid END",
        f"ARCHIVE CFbackup-1.tar.gz 123 1 {'a' * 64} 1 2026-10-17 {UUID} extra",
    ],
)
def test_retention_refuses_malformed_or_ambiguous_ledger(
    awk_programs, bad_record, tmp_path
):
    good = _record(NEW, 1, UUID)
    for _label, awk in awk_programs:
        result = _invoke(
            awk, _ledger([good, bad_record]), "retention", tmp_path=tmp_path
        )
        assert (result.returncode, result.stdout) == (1, b"")


@pytest.mark.parametrize(
    ("memory_kib", "expected"),
    [(40960, 0), (40959, 1), (32768, 1)],
)
def test_resource_memory_reserve_boundaries(shell, tmp_path, memory_kib, expected):
    script = """
. "$1"
. "$2"
cfmgr_store_line=
cfmgr_archive_run() { printf '%s\\n' "$MEMORY_KIB" >"$RECEIPT"; cfmgr_probe_stdout=$RECEIPT; }
cfmgr_store_read_line() { IFS= read -r cfmgr_store_line <"$1"; }
cfmgr_archive_uint() { case ${1-} in ''|*[!0-9]*) return 1;; esac; [ "${#1}" -le 19 ] && [ "$1" -le 9223372036854775296 ]; }
cfmgr_archive_format_retire() { :; }
if cfmgr_archive_resources; then code=0; else code=$?; fi
printf '%s %s %s\\n' "$code" "${cfmgr_archive_inventory_limit:-0}" "${cfmgr_archive_directory_kib:-0}"
"""
    receipt = tmp_path / "memory.receipt"
    environment = {
        **os.environ,
        "MEMORY_KIB": str(memory_kib),
        "RECEIPT": str(receipt),
    }
    result = subprocess.run(
        awk_arguments(
            [*shell, "-c", script, "archive-resource", str(IO), str(RESOURCES)]
        ),
        env=environment,
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert int(result.stdout.split()[0]) == expected


@pytest.mark.parametrize(
    ("free_bytes", "new_bytes", "expected"),
    [(80_000_000, 1_000_000, 1), (200_000_000, 1_000_000, 0)],
)
def test_resource_space_reserve_bounds_copy_and_transform_peak(
    shell, free_bytes, new_bytes, expected
):
    # This isolates the reserve arithmetic; it does not exercise native disk
    # admission or prove the actual router's available memory/storage.
    script = """
. "$1"
. "$2"
cfmgr_archive_space() { cfmgr_archive_free=$TEST_FREE_BYTES; }
cfmgr_capture_payload_bytes=$TEST_PAYLOAD_BYTES
cfmgr_capture_inventory_bytes=65536
cfmgr_capture_files=3
if cfmgr_archive_space_reserve "$TEST_NEW_BYTES"; then code=0; else code=$?; fi
printf '%s\\n' "$code"
"""
    environment = {
        **os.environ,
        "TEST_FREE_BYTES": str(free_bytes),
        "TEST_NEW_BYTES": str(new_bytes),
        "TEST_PAYLOAD_BYTES": "8000000",
    }
    result = subprocess.run(
        awk_arguments(
            [*shell, "-c", script, "archive-space-arithmetic", str(IO), str(RESOURCES)]
        ),
        env=environment,
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert int(result.stdout) == expected


def test_resource_space_reserve_rejects_overflow_before_multiplication(
    shell,
):
    # Arithmetic-only boundary: this value must fail the checked precondition
    # before shell multiplication can wrap.
    script = """
. "$1"
. "$2"
cfmgr_archive_space() { cfmgr_archive_free=9223372036854775807; }
cfmgr_capture_payload_bytes=0
cfmgr_capture_inventory_bytes=65536
cfmgr_capture_files=1
if cfmgr_archive_space_reserve 9223372036854775296; then code=0; else code=$?; fi
printf '%s\\n' "$code"
"""
    result = subprocess.run(
        awk_arguments(
            [*shell, "-c", script, "archive-space-overflow", str(IO), str(RESOURCES)]
        ),
        env=os.environ,
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert int(result.stdout) != 0
