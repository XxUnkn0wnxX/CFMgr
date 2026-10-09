"""Tests for the quota-limited tmpfs under the checked native root."""

from __future__ import annotations

import json
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_native_root import (
    DATA_HOSTS,
    DATA_RESOLVER,
    TMP_DEVICE,
    TMP_INODE_LIMIT,
    TMP_LIMIT_KIB,
    TMP_MOUNT_ID,
    NativeRootFixture,
)
from tests.test_storage import IO, STORAGE

SOURCE = Path(__file__).resolve().parents[1] / "modules/lib/isolation.sh"


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_tmp_root_preserves_data_and_cleans_up_in_reverse_order(
    router: RouterHarness,
) -> None:
    fixture = NativeRootFixture(router)
    result = fixture.run_native(
        tmp_root=True,
        callback_status=7,
        callback_args=("native args", "*", "check-native-data", "check-native-tmp"),
    )
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith(
        "RESULT\t7\nFDSTATE\toriginal-seven\toriginal-eight\toriginal-nine\toriginal-six\n"
    )
    assert fixture.router.read("work/callback-data") == "staged data visible\n"
    assert fixture.router.read("work/callback-tmp") == "private home ready\n"
    assert (fixture.guard / "execution/image/etc/hosts").read_bytes() == DATA_HOSTS
    assert (fixture.guard / "execution/image/etc/resolv.conf").read_bytes() == DATA_RESOLVER
    assert (fixture.guard / "execution/complete").is_dir()
    root_ledger = fixture.callback_ledger.read_text().splitlines()
    assert root_ledger[0].startswith("mount\t900\t")
    assert root_ledger[1].split("\t")[6] == "5"
    tmp_ledger = (fixture.guard / "execution/mounted-tmp").read_text().splitlines()
    assert tmp_ledger[0].startswith(f"mount\t{TMP_MOUNT_ID}\t900\t{TMP_DEVICE}\t2f\t")
    assert tmp_ledger[0].split("\t")[6:8] == ["tmpfs", "63666d67722d746d70"]
    assert bytes.fromhex(tmp_ledger[0].split("\t")[9]).decode() == (
        f"rw,size={TMP_LIMIT_KIB}k,nr_inodes={TMP_INODE_LIMIT},mode=700"
    )
    assert (fixture.guard / "execution/intent-tmp").read_text() == "tmp\n"
    assert (fixture.guard / "execution/fallback-tmp").read_text().startswith("mount\t900\t")
    slots = sorted(
        (fixture.guard / "execution").glob("query-*"), key=lambda path: int(path.name[6:])
    )
    assert [path.name for path in slots] == [f"query-{index}" for index in range(64)]
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == ["tmp", "usr", "lib", "sbin", "bin", "root"]
    state = json.loads(fixture.state_path.read_text())
    assert [row["identifier"] for row in state["mounts"]] == ["1", "77", "88"]
    assert not state["tmp_mounted"]


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_busy_tmp_unmount_retains_the_owned_mount_and_stops_cleanup(
    router: RouterHarness,
) -> None:
    fixture = NativeRootFixture(router, "unmount-busy:tmp")
    result = fixture.run_native(
        tmp_root=True,
        callback_args=("native args", "*", "check-native-data", "check-native-tmp"),
    )
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert fixture.router.read("work/callback-tmp") == "private home ready\n"
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution/complete").exists()
    assert (fixture.guard / "execution/root/tmp/cfmgr-home").is_dir()
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == ["tmp"]
    state = json.loads(fixture.state_path.read_text())
    assert state["tmp_mounted"]
    assert any(row["identifier"] == TMP_MOUNT_ID for row in state["mounts"])


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("kib", "inodes", "expected"),
    [
        ("64", "8", 0),
        ("65536", "8192", 0),
        ("128", "16", 0),
        ("63", "8", 1),
        ("65", "8", 1),
        ("65537", "8", 1),
        ("99999999999999999999", "8", 1),
        ("64", "7", 1),
        ("64", "8193", 1),
        ("064", "8", 1),
        ("64", "08", 1),
        ("+64", "8", 1),
    ],
)
def test_tmp_quota_limits_are_canonical_and_bounded(
    router: RouterHarness, kib: str, inodes: str, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        'if _cfmgr_isolation_tmp_limits "$1" "$2"; then status=0; else status=1; fi\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [kib, inodes], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mount", "superblock", "expected"),
    [
        ("rw,nosuid,nodev,relatime", "rw,size=64k,nr_inodes=8,mode=700", 0),
        ("rw,nodev,relatime", "rw,size=64k,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,relatime", "rw,size=64k,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=128k,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=64k,size=64k,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=64k,size=128k,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=0k,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=64k,nr_inodes=16,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=64k,nr_inodes=8,nr_inodes=8,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=64k,nr_inodes=0,mode=700", 1),
        ("rw,nosuid,nodev,relatime", "rw,size=64k,nr_inodes=8,mode=755", 1),
        ("rw,nosuid,nodev,noexec,relatime", "rw,size=64k,nr_inodes=8,mode=700", 1),
    ],
)
def test_tmp_mount_and_superblock_options_are_exact(
    router: RouterHarness, mount: str, superblock: str, expected: int
) -> None:
    script = "\n".join(
        [
            f". {shlex.quote(str(IO))}",
            f". {shlex.quote(str(STORAGE))}",
            f". {shlex.quote(str(SOURCE))}",
            "_execution_tmp_kib=64; _execution_tmp_inodes=8",
            'if _cfmgr_isolation_tmp_options "$1" "$2"; then status=0; else status=1; fi',
            'printf "RESULT\\t%s\\n" "$status"',
        ]
    )
    result = router.run(script, [mount.encode().hex(), superblock.encode().hex()], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mutation", "expected"),
    [("valid", 0), ("parent", 1), ("mount-id", 1), ("device", 1), ("source", 1), ("point", 1)],
)
def test_tmp_mount_check_requires_a_distinct_exact_child_identity(
    router: RouterHarness, mutation: str, expected: int
) -> None:
    root_path = b"/ram/guard/execution/root".hex()
    root_point = root_path + "2f746d70"
    mount_options = b"rw,nosuid,nodev,relatime".hex()
    super_options = b"rw,size=64k,nr_inodes=8,mode=700".hex()
    source = b"cfmgr-tmp".hex()
    body = "\t".join(
        [
            "mount",
            "905",
            "900",
            "0:99",
            "2f",
            root_point,
            "tmpfs",
            source,
            mount_options,
            super_options,
            "2f",
        ]
    )
    root_body = "\t".join(
        [
            "mount",
            "900",
            "77",
            "0:77",
            "2f",
            root_path,
            "tmpfs",
            "746d706673",
            "726f",
            "7277",
            root_path,
        ]
    )
    source_common = "\t".join(
        [
            "mount",
            "88",
            "1",
            "0:88",
            "2f",
            "2f736f75726365",
            "squashfs",
            "2f6465762f6669726d77617265",
            "726f",
            "726f",
        ]
    )
    changed_source_common = "\t".join(
        [
            "mount",
            "905",
            "1",
            "0:99",
            "2f",
            "2f736f75726365",
            "squashfs",
            "2f6465762f6669726d77617265",
            "726f",
            "726f",
        ]
    )
    topology = shlex.quote("\t".join(["topology", "-", "-", "-", "0", "0", "0"]))
    script = "\n".join(
        [
            f". {shlex.quote(str(IO))}",
            f". {shlex.quote(str(STORAGE))}",
            f". {shlex.quote(str(SOURCE))}",
            f"_io_tab={shlex.quote(chr(9))}; _execution_tmp_kib=64; _execution_tmp_inodes=8",
            "_execution_mount_id=900; _isolation_ram_id=77; _execution_device=0:77",
            "_execution_native_ids='901 902 903 904'",
            f"_execution_base_body={shlex.quote(root_body)}",
            f"_execution_native_source_common={shlex.quote(source_common)}",
            f"_isolation_body={shlex.quote(body)}",
            "_isolation_id=905; _isolation_parent=900; _isolation_device=0:99",
            "_isolation_mount_root=2f; _isolation_point=" + root_point,
            "_isolation_fs=tmpfs; _isolation_fs_target=2f",
            f"_isolation_options={mount_options}; _isolation_super={super_options}",
            f"_isolation_topology={topology}",
            "case $1 in parent) _isolation_parent=899 ;; mount-id) _isolation_id=900 ;;",
            "device) _isolation_device=0:77 ;; source) _execution_native_source_common="
            + shlex.quote(changed_source_common)
            + " ;;",
            "point) _isolation_point=2f746d70 ;; esac",
            "if _cfmgr_isolation_private; then p=0; else p=1; fi",
            'if _cfmgr_isolation_tmp_options "$_isolation_options" "$_isolation_super"; '
            "then o=0; else o=1; fi",
            "if _cfmgr_isolation_tmp_check; then status=0; else status=1; fi",
            'printf "RESULT\\t%s\\n" "$status"',
        ]
    )
    result = router.run(script, [mutation], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_tmp_public_api_forwards_layout_quota_and_callback_arguments(
    router: RouterHarness,
) -> None:
    observed = router.path("work/native-tmp-owner-call")
    script = "\n".join(
        [
            f". {shlex.quote(str(IO))}",
            f". {shlex.quote(str(STORAGE))}",
            f". {shlex.quote(str(SOURCE))}",
            '_cfmgr_isolation_root_owner() { printf "%s\\n" "$@" >"$OWNER_CALL"; }',
            "cfmgr_isolation_native_tmp_root_with /trusted/ram /trusted/guard 64 8 "
            "mount.awk storage.awk callback 'arg with spaces' '*'",
            'printf "RESULT\\t0\\n"',
        ]
    )
    result = router.run(script, env={"OWNER_CALL": str(observed)}, timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == "RESULT\t0\n"
    assert observed.read_text().splitlines() == [
        "native-tmp",
        "production",
        "/trusted/ram",
        "/trusted/guard",
        "64",
        "8",
        "mount.awk",
        "storage.awk",
        "callback",
        "arg with spaces",
        "*",
    ]


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_tmp_public_api_rejects_missing_arguments(router: RouterHarness) -> None:
    script = "\n".join(
        [
            f". {shlex.quote(str(IO))}",
            f". {shlex.quote(str(STORAGE))}",
            f". {shlex.quote(str(SOURCE))}",
            "if cfmgr_isolation_native_tmp_root_test; then status=0; else status=$?; fi",
            'printf "RESULT\\t%s\\n" "$status"',
        ]
    )
    result = router.run(script, timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == "RESULT\t2\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_tmp_public_api_rejects_invalid_quota_before_reservation(
    router: RouterHarness,
) -> None:
    fixture = NativeRootFixture(router)
    result = fixture.run_native(tmp_root=True, limit_kib=65)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t2\n")
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution").exists()


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_tmp_home_creation_failure_is_uncertain_and_records_the_attempt(
    router: RouterHarness,
) -> None:
    tree = router.path("work/tmp-home-tree")
    (tree / "tmp").mkdir(parents=True)
    failing_mkdir = router.write(
        "work/failing-tmp-mkdir",
        '#!/bin/sh\n: >"$HOME_CREATE_WITNESS"\nexit 1\n',
        executable=True,
    )
    witness = router.path("work/tmp-home-create-attempt")
    script = "\n".join(
        [
            f". {shlex.quote(str(IO))}",
            f". {shlex.quote(str(STORAGE))}",
            f". {shlex.quote(str(SOURCE))}",
            "_execution_tmp_ready=1",
            f"_isolation_tree={shlex.quote(str(tree))}",
            f"_isolation_mkdir={shlex.quote(str(failing_mkdir))}",
            '_cfmgr_isolation_native_call() { shift; "$@"; }',
            "if _cfmgr_isolation_tmp_home_create; then status=0; else status=$?; fi",
            'printf "RESULT\\t%s\\n" "$status"',
        ]
    )
    result = router.run(script, env={"HOME_CREATE_WITNESS": str(witness)}, timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == "RESULT\t129\n"
    assert witness.is_file()


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize("mutation", ["valid", "intent", "fallback", "mounted"])
def test_tmp_saved_fifth_child_ledger_must_match_exactly(
    router: RouterHarness, mutation: str
) -> None:
    guard = router.path("work/tmp-saved-guard")
    guard.mkdir()

    def ledger(body: str) -> str:
        topology = "\t".join(["topology", "-", "-", "-", "0", "0", "0"])
        length = len(body.encode()) + len(topology.encode()) + 2
        return f"{body}\n{topology}\nend\t{length}\n"

    fallback = ledger(
        "\t".join(
            [
                "mount",
                "900",
                "77",
                "0:77",
                "2f",
                "2f746d70",
                "tmpfs",
                "746d706673",
                "72772c72656c6174696d65",
                "7277",
                "2f",
            ]
        )
    )
    mounted = ledger(
        "\t".join(
            [
                "mount",
                TMP_MOUNT_ID,
                "900",
                TMP_DEVICE,
                "2f",
                "2f746d702f746d70",
                "tmpfs",
                "63666d67722d746d70",
                "72772c6e6f737569642c6e6f646576",
                "72772c73697a653d36346b2c6e725f696e6f6465733d382c6d6f64653d373030",
                "2f",
            ]
        )
    )
    (guard / "intent-tmp").write_text(
        "tmp\n" if mutation != "intent" else "other\n", encoding="ascii"
    )
    (guard / "fallback-tmp").write_text(
        fallback if mutation != "fallback" else fallback + "changed\n", encoding="ascii"
    )
    (guard / "mounted-tmp").write_text(
        mounted if mutation != "mounted" else mounted + "changed\n", encoding="ascii"
    )
    script = "\n".join(
        [
            f". {shlex.quote(str(IO))}",
            f". {shlex.quote(str(STORAGE))}",
            f". {shlex.quote(str(SOURCE))}",
            f"_io_tab={shlex.quote(chr(9))}; _io_lf={shlex.quote(chr(10))}; _io_wc=/usr/bin/wc",
            "_isolation_guard=$1",
            f"_execution_tmp_fallback_ledger={shlex.quote(fallback)}",
            f"_execution_tmp_mounted_ledger={shlex.quote(mounted)}",
            "if _cfmgr_isolation_tmp_saved; then status=0; else status=1; fi",
            'printf "RESULT\\t%s\\n" "$status"',
        ]
    )
    result = router.run(script, [str(guard)], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{0 if mutation == 'valid' else 1}\n"
