#!/usr/bin/env python3
"""Explicit Linux/root namespace proof; never elevate or execute the root pytest suite."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import struct
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


def contained_manifest(source: Path, executable: Path) -> bytes:
    """Hash only controlled fixture bytes, within the real closure's admission bounds."""
    entries = [
        (f"lib/{name}", source / "lib" / name)
        for name in ("ld-2.27.so", "libc-2.27.so", "libpthread-2.27.so", "librt-2.27.so")
    ]
    entries.extend((f"libexec/{name}", executable) for name in ("timeout-coreutils", "gzip-gnu"))
    rows = []
    total = 0
    for relative, path in entries:
        size = path.stat().st_size
        if not 0 < size <= 4194304:
            raise ValueError(f"contained fixture member exceeds closure bounds: {relative}")
        total += size
        if total > 8388608:
            raise ValueError("contained fixture total exceeds closure bounds")
        data = path.read_bytes()
        if len(data) != size:
            raise ValueError("controlled fixture changed while constructing manifest")
        rows.append(f"{relative}\t{size}\t{hashlib.sha256(data).hexdigest()}\n")
    manifest = "".join(rows).encode("ascii")
    if len(manifest) > 4096:
        raise ValueError("contained fixture manifest exceeds closure bounds")
    return manifest


def fixture_interpreter(data: bytes, replacement: str) -> bytes:
    """Patch only a bounded trusted host fixture's existing PT_INTERP bytes."""
    if not 0 < len(data) <= 4194304 or data[:4] != b"\x7fELF":
        raise ValueError("unsupported native fixture ELF")
    if len(data) < 64 or data[4] not in (1, 2) or data[5] not in (1, 2) or data[6] != 1:
        raise ValueError("unsupported native fixture ELF header")
    endian = "<" if data[5] == 1 else ">"
    if data[4] == 2:
        phoff = struct.unpack_from(endian + "Q", data, 32)[0]
        phsize, phcount = struct.unpack_from(endian + "HH", data, 54)
        expected_size = 56
    else:
        phoff = struct.unpack_from(endian + "I", data, 28)[0]
        phsize, phcount = struct.unpack_from(endian + "HH", data, 42)
        expected_size = 32
    if phsize != expected_size or not 0 < phcount <= 128:
        raise ValueError("unsupported native fixture program headers")
    table_end = phoff + phsize * phcount
    if phoff < (64 if data[4] == 2 else 52) or table_end > len(data):
        raise ValueError("native fixture program headers exceed file")
    regions = []
    for index in range(phcount):
        entry = phoff + phsize * index
        if struct.unpack_from(endian + "I", data, entry)[0] != 3:
            continue
        if data[4] == 2:
            offset = struct.unpack_from(endian + "Q", data, entry + 8)[0]
            size = struct.unpack_from(endian + "Q", data, entry + 32)[0]
        else:
            offset = struct.unpack_from(endian + "I", data, entry + 4)[0]
            size = struct.unpack_from(endian + "I", data, entry + 16)[0]
        if not 2 <= size <= 4096 or offset < table_end or offset + size > len(data):
            raise ValueError("native fixture interpreter exceeds bounded file region")
        original = data[offset : offset + size]
        if original[-1:] != b"\x00" or original[:1] != b"/" or b"\x00" in original[:-1]:
            raise ValueError("unsupported native fixture interpreter framing")
        regions.append((offset, size))
    if len(regions) != 1:
        raise ValueError("native fixture requires exactly one interpreter")
    encoded = replacement.encode("ascii") + b"\x00"
    offset, size = regions[0]
    if not replacement.startswith("/lib/") or ".." in replacement or len(encoded) > size:
        raise ValueError("replacement exceeds native fixture interpreter region")
    return data[:offset] + encoded.ljust(size, b"\x00") + data[offset + size :]


def native_witness_source(work: Path) -> Path:
    """Write the shared descriptor witness without staging a shell or loader."""
    witness = work / "native-fd-witness.c"
    witness.write_text(
        r"""#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
int main(int argc, char **argv) {
    for (int fd = 3; fd <= 63; fd++) {
#ifdef OUTSIDE
        if (fd == 6) continue;
#endif
        errno = 0;
        if (fcntl(fd, F_GETFD) != -1 || errno != EBADF) return 120;
    }
#ifdef OUTSIDE
    struct stat root, held;
    if ((argc != 5 && argc != 9) || stat(argv[1], &root) || fstat(6, &held) ||
        !S_ISDIR(held.st_mode) || root.st_dev != held.st_dev ||
        root.st_ino != held.st_ino) return 121;
    /* Fixed probes and the dependency handoff are the only outer call shapes. */
    if (argc == 5) {
        char *next[] = {"busybox", "chroot", argv[1], argv[2], argv[3], argv[4], 0};
        execv(HOST_BUSYBOX, next);
    } else {
        char *next[] = {"busybox", "chroot", argv[1], argv[2], argv[3], argv[4],
                        argv[5], argv[6], argv[7], argv[8], 0};
        execv(HOST_BUSYBOX, next);
    }
#else
    if (argc < 2) return 121;
    argv[0] = "busybox";
    execv("/bin/native-busybox", argv);
#endif
    return 122;
}
""",
        encoding="ascii",
    )
    return witness


def native_fixture(busybox: Path, work: Path, compiler: str, readelf: str) -> None:
    """Host-native shell/loader proof with fixture-only descriptor instrumentation."""
    staging = work / "native-staging"
    staging.mkdir(mode=0o700)
    (staging / "bin").mkdir(mode=0o700)
    (staging / "lib").mkdir(mode=0o700)
    headers = command([readelf, "-l", str(busybox)])
    match = re.search(r"Requesting program interpreter: (/[^\]\n]+)\]", headers)
    if match is None:
        raise ValueError("native shell fixture requires dynamic host BusyBox")
    loader = Path(match[1]).resolve(strict=True)
    if not loader.is_file():
        raise ValueError("native BusyBox loader unavailable")
    # Only this trusted test copy changes. Runtime's firmware view layout stays
    # bin/sbin/lib/usr; a host /lib64 interpreter is relocated inside fixture lib.
    interpreter = "/lib/cfmgr-ld.so"
    shell = staging / "bin/native-busybox"
    size = busybox.stat().st_size
    if not 0 < size <= 4194304:
        raise ValueError("native BusyBox exceeds fixture byte bound")
    original = busybox.read_bytes()
    if len(original) != size:
        raise ValueError("native BusyBox changed while reading fixture")
    shell.write_bytes(fixture_interpreter(original, interpreter))
    shell.chmod(stat.S_IMODE(busybox.stat().st_mode))
    patched = command([readelf, "-l", str(shell)])
    if re.findall(r"Requesting program interpreter: (/[^\]\n]+)\]", patched) != [interpreter]:
        raise ValueError("readelf rejected native fixture interpreter patch")
    shutil.copyfile(loader, staging / "lib/cfmgr-ld.so")
    (staging / "lib/cfmgr-ld.so").chmod(0o700)
    needed = re.findall(r"\(NEEDED\).*\[([^\]]+)\]", command([readelf, "-d", str(busybox)]))
    # ldd is used only for the explicitly trusted runner executable; never for
    # downloaded/extracted firmware or a caller-provided package payload.
    dependencies = command([native("ldd"), str(busybox)])
    found = {}
    for line in dependencies.splitlines():
        if "=>" not in line:
            if re.fullmatch(r"\s*(?:linux-vdso\.so\.\d+|/[^\s]+) \(0x[0-9a-f]+\)\s*", line):
                continue
            raise ValueError("unsupported native BusyBox dependency row")
        dependency = re.fullmatch(r"\s*([A-Za-z0-9_.+-]+) => (/[^\s]+) \(0x[0-9a-f]+\)\s*", line)
        if dependency is None:
            raise ValueError("unresolved native BusyBox dependency")
        name, absolute = dependency.groups()
        path = Path(absolute)
        if name in found or not absolute.startswith(("/lib/", "/usr/lib/")) or ".." in path.parts:
            raise ValueError("unsupported native BusyBox dependency layout")
        found[name] = path
    if sorted(found) != sorted(needed):
        raise ValueError("native BusyBox dependency closure differs from DT_NEEDED")
    for path in found.values():
        destination = staging / str(path).lstrip("/")
        destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        shutil.copyfile(path.resolve(strict=True), destination)
        destination.chmod(0o700)
    (staging / "bin/sh").symlink_to("native-busybox")
    # The outer shim observes FD6 through external exec; the inner shim is run
    # by real native ash after its first `exec 6<&-`. Both inspect FD3..63.
    witness = native_witness_source(work)
    common = [compiler, "-O2", "-Wall", "-Wextra", "-Werror", "-static", str(witness)]
    command([*common, "-o", str(staging / "bin/busybox")])
    command(
        [
            *common,
            "-DOUTSIDE",
            f"-DHOST_BUSYBOX={json.dumps(str(busybox))}",
            "-o",
            str(work / "native-chroot"),
        ]
    )


def opkg_fixture(work: Path, compiler: str, readelf: str) -> None:
    """Build only the trusted static stand-in; never execute installed opkg."""
    executable = work / "opkg-probe"
    command(
        [
            compiler,
            "-O2",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-static",
            str(FIXTURES / "opkg_probe.c"),
            "-o",
            str(executable),
        ]
    )
    headers = command([readelf, "-l", str(executable)])
    libraries = command([readelf, "-d", str(executable)])
    if "INTERP" in headers or "(NEEDED)" in libraries:
        raise ValueError("opkg stand-in must be fully static")


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
    unshare, compiler, readelf, filesystem, openssl = map(
        native, ("unshare", "gcc", "readelf", "stat", "openssl")
    )
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
        "rmdir",
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
        "dd",
        "cmp",
        "env",
        "ln",
        "chmod",
        "setsid",
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
            "dd",
            "cmp",
            "env",
            "ln",
            "chmod",
            "sleep",
            "chroot",
            "hexdump",
        ):
            (tools / applet).symlink_to(busybox)
        (tools / "openssl").symlink_to(openssl)
        common = [compiler, "-O2", "-Wall", "-Wextra", "-Werror", str(FIXTURES / "probe.c")]
        command([*common, "-static", "-o", str(source / "probe")])
        command(
            [
                compiler,
                "-O2",
                "-Wall",
                "-Wextra",
                "-Werror",
                "-static",
                str(FIXTURES / "worker_lifetime.c"),
                "-o",
                str(work / "worker-lifetime"),
            ]
        )
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
        # Fixed profile names are aliases for host-native bytes, not evidence of
        # Entware provenance, glibc2.27 or AArch64/ARM ABI compatibility.
        (source / "lib").mkdir(mode=0o700)
        shutil.copyfile(loader, source / "lib/ld-2.27.so")
        shutil.copyfile(libc, source / "lib/libc-2.27.so")
        for name in ("libpthread-2.27.so", "librt-2.27.so"):
            (source / "lib" / name).write_bytes(b"controlled unused library fixture\n")
        contained = work / "contained"
        command(
            [
                *common,
                "-Wl,--dynamic-linker=/opt/lib/ld-linux-aarch64.so.1",
                "-Wl,-rpath,/opt/lib",
                "-Wl,--disable-new-dtags",
                "-o",
                str(contained),
            ]
        )
        needed = re.findall(r"\(NEEDED\).*\[([^\]]+)\]", command([readelf, "-d", str(contained)]))
        if needed != ["libc.so.6"]:
            raise ValueError(f"unsupported contained fixture library closure: {needed}")
        (work / "contained-manifest").write_bytes(contained_manifest(source, contained))
        native_fixture(busybox, work, compiler, readelf)
        opkg_fixture(work, compiler, readelf)
        # The native-root scenario instruments its tools; the composed proof
        # needs fresh immutable tool links rather than that previous state.
        shutil.copytree(tools, work / "native-probe-tools", symlinks=True)
        shutil.copytree(tools, work / "native-dependencies-tools", symlinks=True)
        lane_start = time.monotonic()
        for scenario in (
            "success",
            "busy",
            "signal",
            "primitive",
            "image",
            "contained",
            "worker-lifetime",
            "execution-root",
            "native-root",
            "native-probe",
            "native-dependencies",
        ):
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
                        str(
                            FIXTURES
                            / {
                                "worker-lifetime": "worker_lifetime.sh",
                                "execution-root": "execution_root.sh",
                                "native-root": "native_root.sh",
                                "native-probe": "native_probe.sh",
                                "native-dependencies": "native_dependencies.sh",
                            }.get(scenario, "proof.sh")
                        ),
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
    print(
        "Linux kernel fixtures passed; host profile aliases do not prove Entware/ARM ABI, "
        "storage UUID/block or Merlin acceptance."
    )


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
