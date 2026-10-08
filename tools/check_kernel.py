#!/usr/bin/env python3
"""Explicit Linux/root namespace proof; never elevate or execute the root pytest suite."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/kernel"
ENV = {"PATH": "/usr/sbin:/usr/bin:/sbin:/bin", "LC_ALL": "C", "HOME": "/"}


def command(argv: list[str], *, timeout: int = 15) -> str:
    completed = subprocess.run(
        argv, env=ENV, check=True, capture_output=True, text=True, timeout=timeout
    )
    return completed.stdout


def native(name: str) -> str:
    path = shutil.which(name, path=ENV["PATH"])
    if path is None:
        raise ValueError(f"required native tool unavailable: {name}")
    return str(Path(path).resolve())


def namespace(argv: list[str]) -> None:
    # Killing this exact util-linux parent triggers --kill-child=KILL for its
    # namespace init. Init death kills namespace descendants; then reap parent.
    child = subprocess.Popen(argv, env=ENV, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        output, errors = child.communicate(timeout=15)
    except BaseException:
        child.kill()
        child.wait(timeout=5)
        raise
    sys.stdout.buffer.write(output)
    sys.stderr.buffer.write(errors)
    if child.returncode:
        raise ValueError(f"namespace proof failed with status {child.returncode}")


def owned_cleanup(work: Path, parent: Path, identity: tuple[int, int]) -> None:
    held = work.lstat()
    if (
        work.parent != parent
        or not work.name.startswith("cfmgr-kernel-")
        or not stat.S_ISDIR(held.st_mode)
        or held.st_uid != 0
        or stat.S_IMODE(held.st_mode) != 0o700
        or (held.st_dev, held.st_ino) != identity
    ):
        raise ValueError("refusing cleanup: private fixture root identity changed")
    shutil.rmtree(work)


def prove(args: argparse.Namespace) -> None:
    if sys.platform != "linux":
        raise ValueError("kernel proof requires Linux; host doubles are separate evidence")
    if os.geteuid() != 0:
        raise ValueError("kernel proof requires explicit root invocation; never auto-sudo")
    busybox = Path(args.busybox)
    if not busybox.is_absolute() or not busybox.is_file() or not os.access(busybox, os.X_OK):
        raise ValueError("--busybox must select an executable by absolute path")
    busybox = busybox.resolve()
    if "BusyBox" not in command([str(busybox), "--help"]):
        raise ValueError("selected executable is not BusyBox")
    unshare, compiler, readelf, filesystem = map(native, ("unshare", "gcc", "readelf", "stat"))
    if "util-linux" not in command([unshare, "--version"]):
        raise ValueError("kernel proof requires util-linux unshare")
    applets = set(command([str(busybox), "--list"]).splitlines())
    required = {
        "sh",
        "awk",
        "cat",
        "wc",
        "printf",
        "test",
        "mkdir",
        "rm",
        "readlink",
        "mount",
        "umount",
        "chroot",
        "mkfifo",
        "sleep",
        "kill",
        "grep",
        "cp",
        "hexdump",
    }
    if required - applets:
        raise ValueError(f"missing BusyBox applets: {', '.join(sorted(required - applets))}")
    parent = Path(args.work_parent)
    if not parent.is_absolute() or parent.resolve() != parent or not parent.is_dir():
        raise ValueError("work parent must be an existing canonical absolute directory")
    if command([filesystem, "-f", "-c", "%T", str(parent)]).strip() not in {"ext2/ext3", "ext4"}:
        raise ValueError("source fixture requires an actual ext2/3/4 filesystem")
    parent_mount = os.readlink("/proc/self/ns/mnt")
    parent_pid = os.readlink("/proc/self/ns/pid")
    work = Path(tempfile.mkdtemp(prefix="cfmgr-kernel-", dir=parent))
    identity = (work.stat().st_dev, work.stat().st_ino)
    cleanup = True
    try:
        source = work / "source"
        source.mkdir(mode=0o700)
        (source / "sentinel").write_text("controlled fixture\n")
        (work / "ram").mkdir(mode=0o700)
        tools = work / "tools"
        tools.mkdir(mode=0o700)
        for applet in (
            "awk",
            "cat",
            "wc",
            "printf",
            "test",
            "mkdir",
            "rm",
            "readlink",
            "mount",
            "umount",
        ):
            (tools / applet).symlink_to(busybox)
        common = [compiler, "-O2", "-Wall", "-Wextra", "-Werror", str(FIXTURES / "probe.c")]
        command([*common, "-static", "-o", str(source / "probe")])
        # Discover the compiler's actual glibc closure before selecting an Opt
        # interpreter; never guess the runner's architecture or loader path.
        discovery = work / "discovery"
        command([*common, "-o", str(discovery)])
        headers = command([readelf, "-l", str(discovery)])
        match = re.search(r"Requesting program interpreter: (/[^\]\n]+)\]", headers)
        if match is None:
            raise ValueError("compiler did not provide a supported dynamic interpreter")
        loader = Path(match[1]).resolve(strict=True)
        libc = Path(command([compiler, "-print-file-name=libc.so.6"]).strip()).resolve(strict=True)
        if not loader.is_file() or not libc.is_file():
            raise ValueError("compiler loader/libc closure is unavailable")
        shutil.copyfile(loader, source / "loader")
        (source / "loader").chmod(0o700)
        shutil.copyfile(libc, source / "libc.so.6")
        dynamic = work / "dynamic"
        command(
            [
                *common,
                "-Wl,--dynamic-linker=/opt/loader",
                "-Wl,-rpath,/opt",
                "-Wl,--disable-new-dtags",
                "-o",
                str(dynamic),
            ]
        )
        needed = re.findall(r"\(NEEDED\).*\[([^\]]+)\]", command([readelf, "-d", str(dynamic)]))
        if needed != ["libc.so.6"]:
            raise ValueError(f"unsupported fixture library closure: {needed}")
        lane_start = time.monotonic()
        for scenario in ("success", "busy", "signal", "primitive"):
            print(f"Kernel proof: {scenario}", flush=True)
            started = time.monotonic()
            cleanup = False
            try:
                namespace(
                    [
                        unshare,
                        "--mount",
                        "--pid",
                        "--fork",
                        "--kill-child=KILL",
                        "--mount-proc",
                        "--propagation",
                        "private",
                        str(busybox),
                        "sh",
                        str(FIXTURES / "proof.sh"),
                        str(ROOT),
                        str(work),
                        str(busybox),
                        parent_mount,
                        parent_pid,
                        scenario,
                    ]
                )
                cleanup = True
            finally:
                print(f"Kernel {scenario}: {time.monotonic() - started:.2f}s", flush=True)
        print(f"Kernel namespace total: {time.monotonic() - lane_start:.2f}s (excluding build)")
    finally:
        if cleanup:
            # Normal unshare completion waited for namespace init. No namespace
            # descriptor is opened or retained by this host process.
            owned_cleanup(work, parent, identity)
        else:
            # Parent death/kill waiting alone cannot prove synchronous namespace
            # teardown. Never recursively delete a possibly still mounted tree.
            print(f"Retaining fixture tree after namespace failure: {work}", file=sys.stderr)
    print("Linux kernel fixtures passed; storage UUID/block and Merlin acceptance remain unproved.")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--busybox", required=True, help="absolute path to native BusyBox")
    parser.add_argument("--work-parent", default="/tmp", help="canonical ext2/3/4 fixture parent")
    args = parser.parse_args(argv)
    started = time.monotonic()
    try:
        prove(args)
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(f"kernel proof failed: {error}", file=sys.stderr)
        return 1
    finally:
        print(f"Kernel command total: {time.monotonic() - started:.2f}s", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
