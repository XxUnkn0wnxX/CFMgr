"""Fail-closed parsing of Linux mountinfo records for storage admission."""

from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest
from runtime_awk import awk_arguments

ROOT = Path(__file__).resolve().parents[1]
PARSER = "cfmgr-parser:mountinfo"
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
        version = subprocess.run(
            awk_arguments([busybox]), capture_output=True, check=False, timeout=5
        )
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
    awk: list[str],
    target: str,
    records: str,
    *,
    subtree: bool = False,
    inventory: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    return subprocess.run(
        awk_arguments(
            [
                *awk,
                "-f",
                str(PARSER),
                *(["inventory-v1"] if inventory else ["subtree-v1"] if subtree else []),
                target,
                "-",
            ]
        ),
        input=records.encode("utf-8"),
        capture_output=True,
        check=False,
        env=environment,
        timeout=5,
    )


def assert_rejected(
    awk: list[str], target: str, records: str, *, subtree: bool = False
) -> None:
    result = run_parser(awk, target, records, subtree=subtree)
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
            assert_rejected(awk, target, records, subtree=True)


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


def test_subtree_selects_exact_descendants_in_input_order_and_decodes_literals(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    target = "/opt/CFMgr data\\literal"
    records = (
        "\n".join(
            (
                mount_record(1, 1),
                mount_record(2, 1, mountpoint=target + "-sibling"),
                mount_record(
                    3,
                    1,
                    root="/cache\\data",
                    mountpoint=target + "/cache",
                    source="volume backup\\set",
                    optional=("master:4", "propagate_from:2"),
                ),
                mount_record(4, 1, mountpoint=target),
                mount_record(5, 4, mountpoint=target + "/later"),
            )
        )
        + "\n"
    )
    expected = (
        f"3\t1\t8:1\t/cache\\data\t{target}/cache\text4\tvolume backup\\set\trw\trw\tmaster:4,propagate_from:2\n"
        f"4\t1\t8:1\t/\t{target}\text4\t/dev/root\trw\trw\tprivate\n"
        f"5\t4\t8:1\t/\t{target}/later\text4\t/dev/root\trw\trw\tprivate\n"
    ).encode()
    for name, awk in awk_programs:
        result = run_parser(awk, target, records, subtree=True)
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            expected,
            b"",
        ), name


def test_subtree_root_and_propagation_order_are_deterministic(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    records = (
        "\n".join(
            (
                mount_record(
                    1,
                    1,
                    optional=("propagate_from:3", "master:2", "shared:1"),
                ),
                mount_record(2, 1, mountpoint="/opt", optional=("shared:4",)),
                mount_record(3, 1, mountpoint="/tmp", optional=("unbindable",)),
                mount_record(4, 1, mountpoint="/private"),
            )
        )
        + "\n"
    )
    for name, awk in awk_programs:
        result = run_parser(awk, "/", records, subtree=True)
        assert result.returncode == 0 and result.stderr == b"", (name, result.stderr)
        rows = [line.split("\t") for line in result.stdout.decode().splitlines()]
        assert [row[0] for row in rows] == ["1", "2", "3", "4"]
        assert all(len(row) == 10 for row in rows)
        assert [row[-1] for row in rows] == [
            "shared:1,master:2,propagate_from:3",
            "shared:4",
            "unbindable",
            "private",
        ]
        # The existing interface still selects the root and emits precisely its
        # historical nine fields, independent of propagation/input ordering.
        legacy = run_parser(awk, "/", records)
        assert (legacy.returncode, legacy.stdout, legacy.stderr) == (
            0,
            b"1\t1\t8:1\t/\t/\text4\t/dev/root\trw\trw\n",
            b"",
        )


def test_subtree_no_matches_and_empty_input_succeed_without_covering_lookup(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    for name, awk in awk_programs:
        for records in ("", mount_record(1, 1) + "\n"):
            result = run_parser(awk, "/missing", records, subtree=True)
            assert (result.returncode, result.stdout, result.stderr) == (0, b"", b""), (
                name
            )


def test_subtree_validates_entire_input_before_any_output(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    good = mount_record(1, 1, mountpoint="/owned") + "\n"
    invalid_tails = (
        "2 1 8:1 / /outside rw - ext4\n",
        mount_record(2, 1, mountpoint="/outside", optional=("shared:0",)) + "\n",
        mount_record(2, 1, mountpoint="/outside", optional=("master:1", "master:2"))
        + "\n",
        mount_record(2, 1, mountpoint="/outside", optional=("propagate_from:1",))
        + "\n",
        mount_record(2, 1, mountpoint="/outside", optional=("unbindable", "shared:1"))
        + "\n",
    )
    for name, awk in awk_programs:
        for bad in invalid_tails:
            assert_rejected(awk, "/owned", good + bad, subtree=True)
        # No matches still requires valid data, rather than returning early.
        assert_rejected(awk, "/missing", invalid_tails[0], subtree=True)
        # Keep the legacy lookup's historical optional-tag acceptance unchanged.
        legacy = run_parser(awk, "/owned", good + invalid_tails[-1])
        assert (legacy.returncode, legacy.stdout, legacy.stderr) == (
            0,
            b"1\t1\t8:1\t/\t/owned\text4\t/dev/root\trw\trw\n",
            b"",
        ), name


def test_subtree_rejects_stacked_points_only_inside_requested_tree(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    inside = (
        mount_record(1, 1, mountpoint="/owned")
        + "\n"
        + mount_record(2, 1, mountpoint="/owned/nested")
        + "\n"
        + mount_record(3, 1, mountpoint="/owned/nested")
        + "\n"
    )
    outside = (
        mount_record(1, 1, mountpoint="/outside")
        + "\n"
        + mount_record(2, 1, mountpoint="/outside")
        + "\n"
        + mount_record(3, 1, mountpoint="/owned")
        + "\n"
    )
    for name, awk in awk_programs:
        assert_rejected(awk, "/owned", inside, subtree=True)
        result = run_parser(awk, "/owned", outside, subtree=True)
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            b"3\t1\t8:1\t/\t/owned\text4\t/dev/root\trw\trw\tprivate\n",
            b"",
        ), name


def test_subtree_enforces_exact_bounds_without_partial_output(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    records = "".join(
        mount_record(mount_id, 1, mountpoint=f"/owned/{mount_id}") + "\n"
        for mount_id in range(1, 4097)
    )
    line_prefix = mount_record(1, 1, mountpoint="/owned", source="x")
    boundary = mount_record(
        1, 1, mountpoint="/owned", source="x" * (8192 - len(line_prefix) + 1)
    )
    assert len(boundary) == 8192
    oversized = boundary + "x\n"
    for name, awk in awk_programs:
        result = run_parser(awk, "/owned", records, subtree=True)
        assert result.returncode == 0 and result.stderr == b"", (name, result.stderr)
        assert len(result.stdout.splitlines()) == 4096
        result = run_parser(awk, "/owned", boundary + "\n", subtree=True)
        assert result.returncode == 0 and result.stderr == b"", (name, result.stderr)
        assert len(result.stdout.splitlines()) == 1
        assert_rejected(
            awk,
            "/owned",
            records + mount_record(4097, 1, mountpoint="/last") + "\n",
            subtree=True,
        )
        assert_rejected(awk, "/owned", oversized, subtree=True)


def test_inventory_preserves_validated_stacks_and_parent_identity(
    awk_programs: list[tuple[str, list[str]]],
) -> None:
    records = (
        mount_record(1, 1)
        + "\n"
        + mount_record(
            2,
            1,
            mountpoint="/owned",
            filesystem="tmpfs",
            source="tmpfs",
            mount_options="ro",
        )
        + "\n"
        + mount_record(3, 2, mountpoint="/owned", root="/entware")
        + "\n"
    )
    for name, awk in awk_programs:
        result = run_parser(awk, "/owned", records, inventory=True)
        assert result.returncode == 0 and result.stderr == b"", (name, result.stderr)
        rows = [line.split("\t") for line in result.stdout.decode().splitlines()]
        assert [row[:2] for row in rows] == [["2", "1"], ["3", "2"]]
        assert all(len(row) == 10 for row in rows)
        assert [row[7] for row in rows] == ["ro", "rw"]
        assert_rejected(awk, "/owned", records, subtree=True)
        bad = run_parser(awk, "/owned", records + "bad tail\n", inventory=True)
        assert bad.returncode != 0 and bad.stdout == b""
