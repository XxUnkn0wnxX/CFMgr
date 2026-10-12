"""Fail-closed parsing of Linux mountinfo records for storage admission."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PARSER = ROOT / "modules/lib/mountinfo.awk"
REQUIRE_BUSYBOX = os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1"


@pytest.fixture(scope="module")
def awk_programs() -> list[tuple[str, list[str]]]:
    host_awk = Path("/usr/bin/awk")
    if not host_awk.is_file() or not os.access(host_awk, os.X_OK):
        found = shutil.which("awk")
        assert found, "Host awk is required for mountinfo parser tests"
        host_awk = Path(found)
    programs = [("host awk", [str(host_awk)])]
    if REQUIRE_BUSYBOX:
        busybox = shutil.which("busybox")
        assert busybox, "Required pinned BusyBox is missing"
        version = subprocess.run([busybox], capture_output=True, check=False, timeout=5)
        assert re.search(rb"BusyBox v1\.25\.1\b", version.stdout + version.stderr), (
            "Mountinfo BusyBox proof requires the pinned 1.25.1 fixture"
        )
        programs.append(("pinned BusyBox awk", [busybox, "awk"]))
    return programs


def encode_mount_field(value: str) -> str:
    return value.replace("\\", "\\134").replace(" ", "\\040")


def mount_record(
    mount_id: int,
    parent_id: int,
    *,
    root: str = "/",
    mountpoint: str = "/",
    mount_options: str = "rw",
    optional: tuple[str, ...] = (),
    filesystem: str = "ext4",
    source: str = "/dev/root",
    super_options: str = "rw",
) -> str:
    before_separator = [
        str(mount_id),
        str(parent_id),
        "8:1",
        encode_mount_field(root),
        encode_mount_field(mountpoint),
        mount_options,
        *optional,
        "-",
        filesystem,
        encode_mount_field(source),
        super_options,
    ]
    return " ".join(before_separator)


def run_parser(
    awk: list[str], target: str, records: str
) -> subprocess.CompletedProcess[bytes]:
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    return subprocess.run(
        [*awk, "-f", str(PARSER), target, "-"],
        input=records.encode("utf-8"),
        capture_output=True,
        check=False,
        env=environment,
        timeout=5,
    )


def assert_rejected(awk: list[str], target: str, records: str) -> None:
    result = run_parser(awk, target, records)
    assert result.returncode != 0
    assert result.stdout == b""
    assert result.stderr.startswith(b"mountinfo: ")
    assert len(result.stderr) < 80


def test_selects_longest_component_boundary_and_decodes_fields(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    target = "/opt/CFMgr data\\literal/cache/file"
    records = (
        "\n".join(
            (
                mount_record(1, 1, optional=("shared:1",)),
                mount_record(2, 1, mountpoint="/opt/CFMgr data-other"),
                mount_record(
                    3,
                    1,
                    root="/bind\\root",
                    mountpoint="/opt/CFMgr data",
                    mount_options="rw,nosuid",
                    optional=("master:4", "propagate_from:2"),
                    source="volume backup\\set",
                    super_options="rw,relatime",
                ),
                mount_record(
                    4,
                    3,
                    root="/cache\\data",
                    mountpoint="/opt/CFMgr data\\literal/cache",
                    filesystem="fuse.overlayfs",
                    source="overlay source\\label",
                    super_options="rw,lowerdir=/rom",
                ),
            )
        )
        + "\n"
    )
    expected = [
        "4",
        "3",
        "8:1",
        "/cache\\data",
        "/opt/CFMgr data\\literal/cache",
        "fuse.overlayfs",
        "overlay source\\label",
        "rw",
        "rw,lowerdir=/rom",
    ]
    for name, awk in awk_programs:
        result = run_parser(awk, target, records)
        assert result.returncode == 0, (name, result.stderr)
        assert result.stderr == b""
        assert result.stdout.endswith(b"\n")
        assert result.stdout.decode().rstrip("\n").split("\t") == expected


def test_root_mount_record_has_exact_field_order(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    records = (
        mount_record(
            12,
            11,
            filesystem="rootfs",
            source="rootfs",
            mount_options="ro",
            super_options="ro,size=16m",
        )
        + "\n"
    )
    expected = ["12", "11", "8:1", "/", "/", "rootfs", "rootfs", "ro", "ro,size=16m"]
    for name, awk in awk_programs:
        result = run_parser(awk, "/opt/CFMgr", records)
        assert result.returncode == 0, (name, result.stderr)
        assert result.stdout.decode().rstrip("\n").split("\t") == expected


def test_malformed_records_fail_without_partial_output(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    malformed = {
        "truncated record": "1 1 8:1 / / rw - ext4\n",
        "missing separator": "1 1 8:1 / / rw ext4 /dev/root rw\n",
        "extra separator": "1 1 8:1 / / rw - ext4 - /dev/root rw\n",
        "bad mount id": "x 1 8:1 / / rw - ext4 /dev/root rw\n",
        "bad device number": "1 1 8:x / / rw - ext4 /dev/root rw\n",
        "unknown escape": "1 1 8:1 /bad\\011name / rw - ext4 /dev/root rw\n",
        "unknown optional tag": "1 1 8:1 / / rw mystery:3 - ext4 /dev/root rw\n",
        "tab control": "1 1 8:1 / / rw\t - ext4 /dev/root rw\n",
        "noncanonical mountpoint": "1 1 8:1 / /opt/../CFMgr rw - ext4 /dev/root rw\n",
    }
    for name, awk in awk_programs:
        for bad_record in malformed.values():
            assert_rejected(awk, "/opt/CFMgr", mount_record(99, 1) + "\n" + bad_record)


def test_duplicate_ids_and_stacked_best_mounts_are_ambiguous(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    target = "/jffs/addons/CFMgr.d"
    cases = (
        mount_record(1, 1) + "\n" + mount_record(1, 1, mountpoint="/other") + "\n",
        mount_record(1, 1) + "\n" + mount_record(2, 1) + "\n",
    )
    for name, awk in awk_programs:
        for records in cases:
            assert_rejected(awk, target, records)


def test_target_paths_must_be_canonical_and_absent_target_fails(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    records = (
        mount_record(1, 1) + "\n" + mount_record(2, 1, mountpoint="/opt/CFMgr2") + "\n"
    )
    invalid_targets = (
        "relative",
        "//opt/CFMgr",
        "/opt/CFMgr/",
        "/opt/./CFMgr",
        "/opt/../CFMgr",
        "/opt/\tCFMgr",
        "/opt/\nCFMgr",
    )
    for name, awk in awk_programs:
        assert_rejected(
            awk, "/opt/CFMgr", records.replace(mount_record(1, 1) + "\n", "")
        )
        for target in invalid_targets:
            assert_rejected(awk, target, records)


def test_line_and_record_limits_are_enforced(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    oversized = mount_record(1, 1, source="x" * 8192) + "\n"
    too_many_records = "".join(
        mount_record(mount_id, 1) + "\n" for mount_id in range(1, 4098)
    )
    for name, awk in awk_programs:
        assert_rejected(awk, "/opt/CFMgr", oversized)
        assert_rejected(awk, "/opt/CFMgr", too_many_records)
