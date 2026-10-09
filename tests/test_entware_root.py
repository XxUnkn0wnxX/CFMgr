"""Compose an admitted Entware volume with the native execution root."""

from __future__ import annotations

import json
import shlex
import sys
from dataclasses import replace
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.isolation_helpers import FOCUSED_ISOLATION_QUERY
from tests.test_execution_root import MOUNT_PARSER, ROOT, STORAGE_PARSER
from tests.test_native_root import (
    DATA_HOSTS,
    DATA_RESOLVER,
    HOST_MOUNT_ID,
    RAM_MOUNT_ID,
    ROOT_MOUNT_ID,
    SOURCE_MOUNT_ID,
    TMP_MOUNT_ID,
    NativeRootFixture,
)
from tests.test_storage import IO, STORAGE, StorageFixture

ENTWARE = ROOT / "modules/lib/entware.sh"
NATIVE_CONFIG = ROOT / "modules/lib/native_config.sh"
ENTWARE_ROOT = ROOT / "modules/lib/entware_root.sh"
ISOLATION = ROOT / "modules/lib/isolation.sh"

CALLBACK_PROBE = r"""
import json
import os
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
root_ledger, volume_ledger = sys.argv[2:4]
args = sys.argv[4:]
assert os.environ["HOME"] == str(Path(os.environ["CFMGR_TEST_ROOT"]) / "home")
assert root.is_dir() and (root / "opt").is_dir()
assert (root / "etc/hosts").read_bytes() == bytes.fromhex(sys.argv[-2])
assert (root / "etc/resolv.conf").read_bytes() == bytes.fromhex(sys.argv[-1])
home = root / "tmp/cfmgr-home"
assert home.is_dir() and home.stat().st_mode & 0o777 == 0o700
assert not list(home.iterdir())
fd6, fd8, fd9 = os.fstat(6), os.fstat(8), os.fstat(9)
root_stat = root.stat()
source_stat = Path(os.environ["CFMGR_VOLUME_ROOT"]).stat()
block_stat = Path(os.environ["CFMGR_BLOCK_FILE"]).stat()
assert (fd6.st_dev, fd6.st_ino) == (root_stat.st_dev, root_stat.st_ino)
assert stat.S_ISDIR(fd9.st_mode)
assert (fd9.st_dev, fd9.st_ino) == (source_stat.st_dev, source_stat.st_ino)
assert stat.S_ISREG(fd8.st_mode)
assert (fd8.st_dev, fd8.st_ino) == (block_stat.st_dev, block_stat.st_ino)
assert args[:2] == ["arg with spaces", "*"]
assert args[-2:] == [sys.argv[-2], sys.argv[-1]]
assert root_ledger.splitlines()[1].split("\t")[6] == "6"
observation = {
    "root": str(root),
    "root_ledger": root_ledger,
    "volume_ledger": volume_ledger,
    "args": args,
    "fd6": [fd6.st_dev, fd6.st_ino],
    "fd8": [fd8.st_dev, fd8.st_ino],
    "fd9": [fd9.st_dev, fd9.st_ino],
    "home": os.environ["HOME"],
}
Path(os.environ["CFMGR_TEST_ROOT"], "work/entware-callback.json").write_text(
    json.dumps(observation)
)
status = int(args[2].removeprefix("status-"))
sys.exit(status)
"""

POST_CALLBACK_PROBE = r"""
import json
import os
import sys

seen = json.loads(open(sys.argv[1], encoding="utf-8").read())
same8 = [os.fstat(8).st_dev, os.fstat(8).st_ino] == seen["fd8"]
same9 = [os.fstat(9).st_dev, os.fstat(9).st_ino] == seen["fd9"]
print(f"FDIDENT\t{int(same8)}\t{int(same9)}")
"""


def run_native_opt(
    router: RouterHarness,
    *,
    fault: str = "",
    shell: str | None = None,
    callback_status: int = 7,
    callback_args: tuple[str, ...] = ("arg with spaces", "*"),
    focused_query: bool = True,
) -> tuple[NativeRootFixture, StorageFixture, ShellResult]:
    """Run the native-opt fixture while retaining real host FDs 8 and 9."""
    # Storage contributes retained data; its tool doubles must not replace the
    # execution harness applets, particularly the real BusyBox consumer.
    storage = StorageFixture(RouterHarness(router.path("work/retained-storage")))
    fixture = NativeRootFixture(router, fault)
    fixture.tmp_enabled = True
    volume_mount = replace(storage.mounts[0], parent=HOST_MOUNT_ID)
    fixture.opt_enabled = True
    fixture.opt_volume_mount_object = volume_mount
    fixture.opt_volume_mount = {
        "identifier": volume_mount.identifier,
        "parent": volume_mount.parent,
        "device": volume_mount.device,
        "root": volume_mount.root.hex(),
        "point": volume_mount.point.hex(),
        "options": volume_mount.options.hex(),
        "kind": volume_mount.kind,
        "source": volume_mount.source.hex(),
        "super_options": volume_mount.super_options.hex(),
        "optional": [],
    }
    fixture.opt_volume_root = storage.target
    fixture.prepare()
    opt_fdinfo = router.write(
        "work/opt-fdinfo",
        f"pos:\t0\nflags:\t0100000\nmnt_id:\t{volume_mount.identifier}\n",
    )
    callback = router.write("work/entware-root-callback.py", CALLBACK_PROBE)
    post_callback = router.write("work/entware-root-fd-check.py", POST_CALLBACK_PROBE)
    script = (
        f". {shlex.quote(str(IO))}\n"
        f". {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(NATIVE_CONFIG))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        + (FOCUSED_ISOLATION_QUERY if focused_query else "")
        + "fixture_callback() {\n"
        f'  {shlex.quote(sys.executable)} {shlex.quote(str(callback))} "$@"\n'
        '  return "$?"\n'
        "}\n"
        'exec 7<"$CFMGR_TEST_ROOT/work/fd-seven" '
        f"8<{shlex.quote(str(storage.router.path('work/block')))} "
        f"9<{shlex.quote(str(storage.target))} "
        '6<"$CFMGR_TEST_ROOT/work/fd-six"\n'
        'cfmgr_isolation_entware_root_test "$@"; status=$?\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
        "IFS= read -r seven <&7; IFS= read -r six <&6\n"
        f"{shlex.quote(sys.executable)} {shlex.quote(str(post_callback))} "
        f"{shlex.quote(str(router.path('work/entware-callback.json')))}\n"
        'printf "FDSTATE\\t%s\\t%s\\n" "$seven" "$six"\n'
    )
    args = [
        str(storage.target),
        storage.expected(),
        str(fixture.ramroot),
        str(fixture.guard),
        str(fixture.tools),
        str(fixture.mount_input),
        str(fixture.fdinfo_input),
        str(opt_fdinfo),
        str(fixture.source_root),
        str(fixture.data_source_root),
        "64",
        "8",
        str(MOUNT_PARSER),
        str(STORAGE_PARSER),
        "fixture_callback",
        *callback_args,
        f"status-{callback_status}",
        DATA_HOSTS.hex(),
        DATA_RESOLVER.hex(),
    ]
    router.write("work/fd-six", "original-six\n")
    router.write("work/fd-seven", "original-seven\n")
    if shell is not None:
        invoke = router.write("work/invoke-entware-root.sh", script)
        script = f'exec {shlex.quote(shell)} sh "$@"\n'
        args = [str(invoke), *args]
    result = router.run(
        script,
        args,
        timeout=60,
        env={
            "CFMGR_VOLUME_ROOT": str(storage.target),
            "CFMGR_BLOCK_FILE": str(storage.router.path("work/block")),
            "PYTHON": sys.executable,
        },
    )
    return fixture, storage, result


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_entware_root_uses_retained_volume_and_cleans_native_opt_first(
    router: RouterHarness,
) -> None:
    fixture, storage, result = run_native_opt(router, callback_status=7)

    assert result.returncode == 0, result
    assert result.stderr == "", (result.stdout, result.stderr)
    assert result.stdout == ("RESULT\t7\nFDIDENT\t1\t1\nFDSTATE\toriginal-seven\toriginal-six\n")
    assert (fixture.guard / "execution/complete").is_dir()
    observation = json.loads(router.read("work/entware-callback.json"))
    assert observation["root"] == str(fixture.guard / "execution/root")
    assert observation["volume_ledger"] == storage.expected()
    assert observation["args"] == [
        "arg with spaces",
        "*",
        "status-7",
        DATA_HOSTS.hex(),
        DATA_RESOLVER.hex(),
    ]
    assert observation["home"] == str(router.path("home"))
    assert observation["root_ledger"].splitlines()[0].startswith("mount\t900\t")
    assert observation["root_ledger"].splitlines()[1].split("\t")[6] == "6"
    assert (fixture.guard / "execution/image/etc/hosts").read_bytes() == DATA_HOSTS
    assert (fixture.guard / "execution/image/etc/resolv.conf").read_bytes() == DATA_RESOLVER
    assert (
        (fixture.guard / "execution/mounted-tmp")
        .read_text()
        .startswith(f"mount\t{TMP_MOUNT_ID}\t{ROOT_MOUNT_ID}\t")
    )
    opt_ledger = (fixture.guard / "execution/mounted-opt").read_text()
    assert opt_ledger.startswith("mount\t906\t900\t8:1\t")

    query_slots = sorted(
        (fixture.guard / "execution").glob("query-*"), key=lambda path: int(path.name[6:])
    )
    assert [path.name for path in query_slots] == [f"query-{index}" for index in range(78)]
    descriptor_observations = [
        json.loads(path.read_text()) for path in fixture.tool_log.parent.glob("native-ls-*.json")
    ]
    assert descriptor_observations == [["ls", ["-dnL", "/proc/self/fd/8"]]] * 5
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    assert any(
        tool == "mount"
        and args[3:]
        == [
            "bind",
            "/proc/self/fd/9",
            str(fixture.guard / "execution/root/opt"),
        ]
        for tool, args in calls
    )
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == ["opt", "tmp", "usr", "lib", "sbin", "bin", "root"]
    state = json.loads(fixture.state_path.read_text())
    assert [row["identifier"] for row in state["mounts"]] == [
        HOST_MOUNT_ID,
        RAM_MOUNT_ID,
        SOURCE_MOUNT_ID,
        "42",
    ]
    assert state["opt_mounted"] is False
    assert storage.expected() == observation["volume_ledger"]


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_entware_root_busy_opt_is_witnessed_and_stops_teardown(
    router: RouterHarness,
) -> None:
    fixture, _storage, result = run_native_opt(router, fault="unmount-busy:opt", callback_status=0)

    assert result.returncode == 0, result
    assert result.stderr == "", (result.stdout, result.stderr)
    assert result.stdout == ("RESULT\t129\nFDIDENT\t1\t1\nFDSTATE\toriginal-seven\toriginal-six\n")
    assert json.loads(router.read("work/entware-callback.json"))["args"][:2] == [
        "arg with spaces",
        "*",
    ]
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution/complete").exists()
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == ["opt"]
    state = json.loads(fixture.state_path.read_text())
    assert state["opt_mounted"] is True
    assert any(row["identifier"] == "906" for row in state["mounts"])


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_entware_root_fixture_rejects_bad_api_before_reservation(router: RouterHarness) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n"
        f". {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(NATIVE_CONFIG))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        'cfmgr_isolation_entware_root_test "$@"; status=$?\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script)
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t2\n"
    assert result.stderr == ""
