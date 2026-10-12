#!/usr/bin/env python3
"""Explicit developer-only vendor BusyBox and ARM guest proof; never a router tool."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import inspect
import io
import json
import os
import posixpath
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import urllib.parse
import urllib.request
from functools import lru_cache
from pathlib import Path, PurePosixPath
from typing import Any, BinaryIO

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/platform"
MANIFEST = ROOT / "tests/fixtures/platforms.json"
VERSIONS = {"4.1.51", "4.1.52", "4.19.183", "4.19.294"}
MAX_DOWNLOAD = 256 * 1024 * 1024
MAX_PACKAGE = 32 * 1024 * 1024
RECIPE_VERSION = 1


class PlatformError(Exception):
    """Missing, malformed or failed platform evidence."""


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise PlatformError(message)


def _token(value: Any, label: str) -> str:
    _require(
        isinstance(value, str) and bool(re.fullmatch(r"[A-Za-z0-9_.+-]+", value)), label
    )
    return value


def _pin(value: Any, length: int = 64) -> str:
    _require(
        isinstance(value, str) and bool(re.fullmatch(rf"[0-9a-f]{{{length}}}", value)),
        "invalid source digest",
    )
    return value


def _relative(value: str) -> PurePosixPath:
    _require(
        isinstance(value, str) and "\x00" not in value and "\n" not in value,
        "invalid archive path",
    )
    path = PurePosixPath(value)
    _require(
        not path.is_absolute() and ".." not in path.parts,
        f"unsafe archive path: {value}",
    )
    return path


def _https(value: str, hosts: set[str]) -> str:
    parsed = urllib.parse.urlsplit(value)
    _require(
        parsed.scheme == "https"
        and parsed.hostname in hosts
        and not parsed.username
        and not parsed.password
        and not parsed.query
        and not parsed.fragment,
        "untrusted source URL",
    )
    return value


def load_manifest(path: Path = MANIFEST) -> dict[str, Any]:
    manifest = json.loads(path.read_text())
    _require(manifest.get("schema") == 1, "unsupported platform schema")
    busyboxes = manifest["busyboxes"]
    ids = [_token(item["id"], "invalid BusyBox id") for item in busyboxes]
    _require(
        len(ids) == len(set(ids)) and bool(ids), "duplicate or absent BusyBox sources"
    )
    for item in busyboxes:
        _require(
            item["version"] == "1.25.1"
            and item["repository"] == "https://github.com/RMerl/asuswrt-merlin.ng.git",
            "vendor BusyBox source mismatch",
        )
        _pin(item["commit"], 40)
        _require(
            item["path"] == "release/src/router/busybox",
            "unexpected vendor source path",
        )
    kernels = manifest["kernels"]
    _require(
        {item["version"] for item in kernels} == VERSIONS
        and len(kernels) == len(VERSIONS),
        "four exact kernel profiles required",
    )
    for item in kernels:
        _require(item["busybox"] in ids, "missing kernel BusyBox source")
        _require(
            item["toolchain"]
            == ("4.9.4" if item["version"].startswith("4.1.") else "8.5.0"),
            "kernel compiler compatibility mismatch",
        )
        expected = f"https://www.kernel.org/pub/linux/kernel/v4.x/linux-{item['version']}.tar.xz"
        _require(item["url"] == expected, "kernel archive identity mismatch")
        _pin(item["sha256"])
        _pin(item["merlin"]["commit"], 40)
        _relative(item["merlin"]["path"])
    toolchains = manifest["toolchains"]
    _require(
        set(toolchains) == {"4.9.4", "8.5.0"}, "both pinned kernel compilers required"
    )
    for version, toolchain in toolchains.items():
        expected = f"https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/x86_64/{version}/x86_64-gcc-{version}-nolibc-aarch64-linux.tar.xz"
        _require(
            toolchain["url"] == expected, "kernel compiler archive identity mismatch"
        )
        _pin(toolchain["sha256"])
        _require(
            toolchain["version"] == version
            and toolchain["version_option"]
            == ("-dumpversion" if version == "4.9.4" else "-dumpfullversion")
            and toolchain["prefix"]
            == f"gcc-{version}-nolibc/aarch64-linux/bin/aarch64-linux-"
            and toolchain["host_packages"]
            == (["libc6", "libmpc3", "libgmp10"] if version == "4.9.4" else ["libc6"]),
            "kernel compiler identity mismatch",
        )
    _require(
        toolchains["8.5.0"]["runtime"] is None, "unexpected modern compiler runtime"
    )
    runtime = toolchains["4.9.4"]["runtime"]
    _require(
        runtime["url"]
        == "https://archive.debian.org/debian/pool/main/m/mpfr4/libmpfr4_3.1.5-1_amd64.deb"
        and runtime["package"] == "libmpfr4"
        and runtime["version"] == "3.1.5-1"
        and runtime["architecture"] == "amd64"
        and runtime["library"] == "usr/lib/x86_64-linux-gnu/libmpfr.so.4.1.5"
        and runtime["soname"] == "libmpfr.so.4",
        "kernel compiler runtime identity mismatch",
    )
    _pin(runtime["sha256"])
    _pin(runtime["library_sha256"])
    _require(
        manifest["dependency_sets"]
        == {
            "shared": ["jq", "coreutils-timeout", "coreutils-sha256sum"],
            "conditional": ["flock", "bind-dig"],
        },
        "dependency command contract mismatch",
    )
    feeds = manifest["feeds"]
    _require(
        {item["id"] for item in feeds} == {"aarch64-k3.10", "armv7sf-k3.2"}
        and len(feeds) == 2,
        "both ARM Entware feeds required",
    )
    for feed in feeds:
        expected_arch = "aarch64-3.10" if feed["id"] == "aarch64-k3.10" else "armv7-3.2"
        _require(feed["architecture"] == expected_arch, "feed ABI mismatch")
        names = [
            _token(item["name"], "invalid package name") for item in feed["packages"]
        ]
        _require(len(names) == len(set(names)), "duplicate package pins")
        required = set(
            manifest["dependency_sets"]["shared"]
            + manifest["dependency_sets"]["conditional"]
        )
        _require(required <= set(names), "missing dependency command package")
        for package in feed["packages"]:
            _token(package["version"], "invalid package version")
            _require(
                package["filename"]
                == f"{package['name']}_{package['version']}_{expected_arch}.ipk",
                "package filename identity mismatch",
            )
            _pin(package["sha256"])
            _require(
                set(package["depends"]) <= set(names),
                "incomplete pinned dependency closure",
            )
    return manifest


def kernel_toolchain(
    manifest: dict[str, Any], kernel: dict[str, Any]
) -> dict[str, Any]:
    return manifest["toolchains"][kernel["toolchain"]]


def verify_hash(path: Path, expected: str) -> None:
    _pin(expected)
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    _require(digest.hexdigest() == expected, f"SHA256 mismatch: {path.name}")


def download(
    url: str, expected: str, destination: Path, *, limit: int = MAX_DOWNLOAD
) -> Path:
    _https(
        url,
        {
            "www.kernel.org",
            "mirrors.edge.kernel.org",
            "cdn.kernel.org",
            "bin.entware.net",
            "archive.debian.org",
        },
    )
    if destination.exists():
        verify_hash(destination, expected)
        return destination
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    try:
        request = urllib.request.Request(
            url, headers={"User-Agent": "CFMgr-platform-CI/1"}
        )
        with (
            urllib.request.urlopen(request, timeout=60) as source,
            temporary.open("xb") as target,
        ):
            _https(
                source.geturl(),
                {
                    "www.kernel.org",
                    "mirrors.edge.kernel.org",
                    "cdn.kernel.org",
                    "bin.entware.net",
                    "archive.debian.org",
                },
            )
            total = 0
            while chunk := source.read(1024 * 1024):
                total += len(chunk)
                _require(total <= limit, "download size bound exceeded")
                target.write(chunk)
        verify_hash(temporary, expected)
        temporary.replace(destination)
    finally:
        if temporary.exists():
            temporary.unlink()
    return destination


def _parents_safe(root: Path, relative: PurePosixPath) -> Path:
    cursor = root
    _require(root.is_dir() and not root.is_symlink(), "unsafe extraction root")
    for part in relative.parts[:-1]:
        cursor /= part
        _require(not cursor.is_symlink(), "archive traverses existing symlink")
        cursor.mkdir(exist_ok=True)
        _require(cursor.is_dir(), "archive parent is not a directory")
    return root.joinpath(*relative.parts)


def extract_tar(
    source: Path | BinaryIO,
    root: Path,
    *,
    package: bool = False,
    limit: int = 1536 * 1024 * 1024,
) -> None:
    """Never follow archive symlinks; absolute /opt links are staged inertly last."""
    root.mkdir(parents=True, exist_ok=True)
    links: list[tuple[tarfile.TarInfo, PurePosixPath]] = []
    count = total = 0
    arguments = (
        {"name": str(source)} if isinstance(source, Path) else {"fileobj": source}
    )
    with tarfile.open(mode="r:*", **arguments) as archive:
        for member in archive:
            count += 1
            total += member.size
            _require(
                count <= (8192 if package else 100000)
                and total <= limit
                and member.size <= MAX_DOWNLOAD,
                "archive expansion bound exceeded",
            )
            relative = _relative(member.name)
            if not relative.parts:
                _require(member.isdir(), "invalid archive root entry")
                continue
            if package:
                _require(relative.parts[0] == "opt", "package writes outside opt")
            destination = _parents_safe(root, relative)
            if member.issym() or member.islnk():
                _require(
                    "\x00" not in member.linkname and "\n" not in member.linkname,
                    "invalid archive link",
                )
                target = PurePosixPath(member.linkname)
                if target.is_absolute():
                    _require(
                        package and member.issym() and target.parts[:2] == ("/", "opt"),
                        "unsafe absolute archive link",
                    )
                    normalized = posixpath.normpath(member.linkname)
                    _require(
                        normalized == "/opt" or normalized.startswith("/opt/"),
                        "archive link escapes opt",
                    )
                else:
                    combined = (
                        member.linkname
                        if member.islnk()
                        else posixpath.join(str(relative.parent), member.linkname)
                    )
                    normalized = posixpath.normpath(combined)
                    _require(
                        normalized != ".." and not normalized.startswith("../"),
                        "archive link escapes root",
                    )
                    if package:
                        _require(
                            normalized == "opt" or normalized.startswith("opt/"),
                            "archive link escapes opt",
                        )
                links.append((member, relative))
            elif member.isdir():
                _require(
                    not destination.is_symlink(), "archive directory overwrites symlink"
                )
                destination.mkdir(exist_ok=True)
                _require(destination.is_dir(), "archive directory collision")
            elif member.isfile():
                _require(
                    not destination.exists() and not destination.is_symlink(),
                    "duplicate archive file or symlink collision",
                )
                stream = archive.extractfile(member)
                _require(stream is not None, "missing archive member data")
                with stream, destination.open("xb") as output:
                    shutil.copyfileobj(stream, output, length=1024 * 1024)
                destination.chmod(member.mode & 0o777)
            else:
                raise PlatformError("archive special file is not permitted")
    for member, relative in links:
        destination = _parents_safe(root, relative)
        if (
            destination.is_symlink()
            and member.issym()
            and os.readlink(destination) == member.linkname
        ):
            continue
        _require(
            not destination.exists() and not destination.is_symlink(),
            "archive link collision",
        )
        if member.issym():
            destination.symlink_to(member.linkname)
        else:
            target = _relative(member.linkname)
            target_path = _parents_safe(root, target)
            _require(
                target_path.is_file() and not target_path.is_symlink(),
                "invalid archive hardlink",
            )
            os.link(target_path, destination)


def ipk_data(path: Path) -> io.BytesIO:
    """Read only data.tar.* from tar or ar containers, never maintainer scripts."""
    _require(path.stat().st_size <= MAX_PACKAGE, "package container too large")
    data = path.read_bytes()
    members: list[tuple[str, bytes]] = []
    if data.startswith(b"!<arch>\n"):
        offset = 8
        while offset < len(data):
            header = data[offset : offset + 60]
            _require(
                len(header) == 60 and header[58:60] == b"`\n",
                "invalid ar package header",
            )
            name = header[:16].decode("ascii").rstrip().rstrip("/")
            size = int(header[48:58])
            _require(
                0 <= size <= MAX_PACKAGE and offset + 60 + size <= len(data),
                "invalid ar package size",
            )
            members.append((name, data[offset + 60 : offset + 60 + size]))
            offset += 60 + size + size % 2
            _require(len(members) <= 8, "too many ar package members")
    else:
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:*") as outer:
            for member in outer:
                _require(
                    member.isfile() and member.size <= MAX_PACKAGE and len(members) < 8,
                    "invalid tar package member",
                )
                stream = outer.extractfile(member)
                _require(stream is not None, "missing package member")
                with stream:
                    members.append((str(_relative(member.name)), stream.read()))
    payloads = [
        contents
        for name, contents in members
        if re.fullmatch(r"data\.tar\.(gz|xz|bz2)", name)
    ]
    _require(len(payloads) == 1, "one package data archive required")
    return io.BytesIO(payloads[0])


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    timeout: int = 900,
    input_data: bytes | None = None,
) -> None:
    print("+ " + " ".join(command), flush=True)
    environment = os.environ.copy()
    environment.update(
        LC_ALL="C",
        GIT_TERMINAL_PROMPT="0",
        GIT_CONFIG_GLOBAL="/dev/null",
        GIT_CONFIG_SYSTEM="/dev/null",
    )
    subprocess.run(
        command, cwd=cwd, env=environment, input=input_data, check=True, timeout=timeout
    )


def configuration(fragment: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in fragment.read_text().splitlines():
        if line and not line.startswith("#"):
            key, value = line.split("=", 1)
            _require(
                key.startswith("CONFIG_") and key not in values,
                "invalid configuration fragment",
            )
            values[key] = value
    return values


def apply_configuration(path: Path, values: dict[str, str]) -> None:
    pattern = re.compile(r"^(CONFIG_[A-Z0-9_]+)=|^# (CONFIG_[A-Z0-9_]+) is not set$")
    lines = []
    for line in path.read_text().splitlines():
        match = pattern.match(line)
        key = (match[1] or match[2]) if match else None
        if key not in values:
            lines.append(line)
    for key, value in values.items():
        lines.append(f"# {key} is not set" if value == "n" else f"{key}={value}")
    path.write_text("\n".join(lines) + "\n")


def check_busybox_symbols(source: Path, values: dict[str, str]) -> None:
    # allnoconfig generates each Config.in from the pinned vendor Config.src
    # and embedded applet declarations. Reject typos even in disabled options.
    symbols: set[str] = set()
    for path in source.rglob("Config.in"):
        symbols.update(
            "CONFIG_" + symbol
            for symbol in re.findall(
                r"^\s*(?:menu)?config\s+(\w+)\b", path.read_text(), re.MULTILINE
            )
        )
    unknown = set(values) - symbols
    _require(
        not unknown,
        "unknown vendor BusyBox configuration: " + ", ".join(sorted(unknown)),
    )


def check_configuration(path: Path, values: dict[str, str]) -> None:
    lines = set(path.read_text().splitlines())
    for key, value in values.items():
        expected = f"# {key} is not set" if value == "n" else f"{key}={value}"
        # Optional version-specific disabled symbols may not exist at all.
        if value != "n":
            _require(expected in lines, f"required configuration absent: {key}")
        else:
            _require(
                f"{key}=y" not in lines and f"{key}=m" not in lines,
                f"forbidden configuration enabled: {key}",
            )


@lru_cache(maxsize=2)
def compiler_identity(target: str = "arm") -> bytes:
    """Include native Kconfig/dtc and cross-libc compiler package identities."""
    _require(target in {"arm", "native"}, "unknown compiler target")
    packages_required = ["gcc", "libc6-dev"]
    if target == "arm":
        packages_required = ["gcc", "gcc-arm-linux-gnueabi", "libc6-dev-armel-cross"]
    packages = subprocess.check_output(["dpkg-query", "-W", *packages_required])
    identity = packages + subprocess.check_output(["gcc", "--version"])
    if target == "arm":
        identity += subprocess.check_output(["arm-linux-gnueabi-gcc", "--version"])
    return identity


def build_key(
    kind: str,
    item: dict[str, Any],
    toolchain: dict[str, Any] | None = None,
    *,
    target: str = "arm",
) -> str:
    # Hash the actual builder/helper definitions, not guest tests or Entware pins.
    # This keeps runtime fixes from invalidating expensive immutable kernel work.
    _require(target in {"arm", "native"}, "unknown build target")
    _require(kind == "busybox" or target == "arm", "native target is BusyBox only")
    pins = (
        {"source": item["sha256"]}
        if kind == "kernel"
        else {key: item[key] for key in ("commit", "path", "repository", "version")}
    )
    if kind == "busybox":
        pins["target"] = target
    if toolchain is not None:
        # The archive pins compiler binaries and built-in headers together.
        pins["toolchain"] = toolchain
    digest = hashlib.sha256(json.dumps(pins, sort_keys=True).encode())
    digest.update(compiler_identity(target))
    digest.update((FIXTURES / (kind + ".config")).read_bytes())
    for function in (
        configuration,
        apply_configuration,
        check_configuration,
        run,
        extract_tar,
        _parents_safe,
        _relative,
        build_kernel if kind == "kernel" else build_busybox,
    ):
        digest.update(inspect.getsource(function).encode())
    if kind == "busybox":
        digest.update(inspect.getsource(check_busybox_symbols).encode())
        digest.update(inspect.getsource(verify_elf).encode())
        digest.update(inspect.getsource(stage_busybox_support).encode())
        digest.update((FIXTURES / "busybox-support/rtconfig.h").read_bytes())
    else:
        digest.update(inspect.getsource(kernel_configuration).encode())
        _require(toolchain is not None, "kernel cache key requires selected compiler")
        digest.update(kernel_runtime_identity(tuple(toolchain["host_packages"])))
        for function in (
            prepare_kernel_compiler,
            kernel_command,
            compiler_preflight,
            verify_elf,
        ):
            digest.update(inspect.getsource(function).encode())
        if toolchain["runtime"] is not None:
            for function in (stage_kernel_runtime, ipk_data):
                digest.update(inspect.getsource(function).encode())
    digest.update(str(RECIPE_VERSION).encode())
    return digest.hexdigest()


def stage_busybox_support(source: Path) -> None:
    # Use an explicit local include directory, without patching vendor sources or
    # borrowing firmware-generated board settings from a router source tree.
    support = source / ".cfmgr-generic-headers"
    support.mkdir()
    shutil.copyfile(FIXTURES / "busybox-support/rtconfig.h", support / "rtconfig.h")


def build_busybox(item: dict[str, str], cache: Path, *, target: str = "arm") -> Path:
    key = build_key("busybox", item, target=target)
    prefix = "arm-linux-gnueabi-" if target == "arm" else ""
    architecture = "armv7-3.2" if target == "arm" else "x86_64"
    output = cache / "busybox" / key
    binary = output / "busybox"
    receipt = output / "verified.json"
    if receipt.is_file() and binary.is_file():
        saved = json.loads(receipt.read_text())
        verify_elf(binary, architecture)
        verify_hash(binary, saved["sha256"])
        _require(
            saved["commit"] == item["commit"]
            and saved["recipe"] == key
            and saved["target"] == target,
            "BusyBox cache receipt mismatch",
        )
        return binary
    build = ROOT / ".tmp/platform-builds/busybox" / key
    _require(
        not build.exists(),
        "unfinished BusyBox build; inspect retained cache before retry",
    )
    build.mkdir(parents=True)
    checkout = build / "vendor"
    run(["git", "init", str(checkout)])
    run(["git", "-C", str(checkout), "remote", "add", "origin", item["repository"]])
    run(["git", "-C", str(checkout), "sparse-checkout", "init", "--cone"])
    run(["git", "-C", str(checkout), "sparse-checkout", "set", item["path"]])
    run(
        [
            "git",
            "-c",
            "protocol.version=2",
            "-C",
            str(checkout),
            "fetch",
            "--depth=1",
            "--filter=blob:none",
            "origin",
            item["commit"],
        ]
    )
    run(["git", "-C", str(checkout), "checkout", "--detach", "FETCH_HEAD"])
    actual = subprocess.check_output(
        ["git", "-C", str(checkout), "rev-parse", "HEAD"], text=True
    ).strip()
    _require(actual == item["commit"], "vendor checkout commit mismatch")
    source = checkout / item["path"]
    stage_busybox_support(source)
    make = [
        "make",
        "ARCH=" + ("arm" if target == "arm" else "x86_64"),
        "CROSS_COMPILE=" + prefix,
        # The vendor Makefile can otherwise add board flags/shared include paths.
        "HND_ROUTER=n",
        "HND_ROUTER_BE_4916=n",
        "HOSTCFLAGS=-O2 -fcommon",
        "EXTRA_CFLAGS=-include sys/sysmacros.h -I.cfmgr-generic-headers",
    ]
    run([*make, "allnoconfig"], cwd=source)
    values = configuration(FIXTURES / "busybox.config")
    check_busybox_symbols(source, values)
    apply_configuration(source / ".config", values)
    run([*make, "oldconfig"], cwd=source, input_data=b"\n" * 2048)
    check_configuration(source / ".config", values)
    run([*make, "-j2"], cwd=source)
    output.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / "busybox", binary)
    verify_elf(binary, architecture)
    receipt.write_text(
        json.dumps(
            {
                "commit": actual,
                "recipe": key,
                "target": target,
                "sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
            },
            indent=2,
        )
        + "\n"
    )
    return binary


def verify_elf(path: Path, architecture: str) -> None:
    _require(stat.S_ISREG(path.lstat().st_mode), "expected regular ABI executable")
    header = path.read_bytes()[:20]
    abis = {"aarch64-3.10": (2, 183), "armv7-3.2": (1, 40), "x86_64": (2, 62)}
    _require(architecture in abis, "unknown executable ABI")
    expected_class, expected_machine = abis[architecture]
    _require(
        len(header) == 20
        and header[:4] == b"\x7fELF"
        and header[4] == expected_class
        and header[5] == 1
        and int.from_bytes(header[18:20], "little") == expected_machine,
        "executable ABI mismatch",
    )


@lru_cache(maxsize=2)
def kernel_runtime_identity(packages: tuple[str, ...]) -> bytes:
    """Selected compiler's host ABI providers, never BusyBox inputs."""
    return subprocess.check_output(["dpkg-query", "-W", *packages])


def stage_kernel_runtime(runtime: dict[str, str], downloads: Path, cache: Path) -> Path:
    archive = download(
        runtime["url"],
        runtime["sha256"],
        downloads / "libmpfr4_3.1.5-1_amd64.deb",
        limit=MAX_PACKAGE,
    )
    root = cache / "toolchain/runtime" / runtime["sha256"]
    if not root.exists():
        # Only data.tar.*: no dpkg install or maintainer script execution.
        extract_tar(ipk_data(archive), root, limit=8 * 1024 * 1024)
    library = _parents_safe(root, _relative(runtime["library"]))
    verify_elf(library, "x86_64")
    _require(
        int.from_bytes(library.read_bytes()[16:18], "little") == 3,
        "compiler runtime must be an ELF shared object",
    )
    verify_hash(library, runtime["library_sha256"])
    soname = library.parent / runtime["soname"]
    _require(
        soname.is_symlink() and os.readlink(soname) == library.name,
        "compiler runtime SONAME link mismatch",
    )
    _require(
        {path.name for path in library.parent.iterdir()} == {library.name, soname.name},
        "unexpected private compiler runtime library",
    )
    return library.parent


def kernel_command(command: list[str], runtime: Path | None) -> list[str]:
    # Replace, rather than append to, ambient paths; never mutate os.environ.
    if runtime is None:
        return ["env", "-u", "LD_LIBRARY_PATH", *command]
    return ["env", "LD_LIBRARY_PATH=" + str(runtime.resolve()), *command]


def compiler_preflight(
    compiler: str, runtime: Path | None, cache: Path, toolchain: dict[str, Any]
) -> None:
    _require(Path(compiler + "gcc").is_file(), "pinned kernel compiler is absent")
    version = subprocess.check_output(
        kernel_command([compiler + "gcc", toolchain["version_option"]], runtime),
        text=True,
        timeout=30,
    ).strip()
    _require(version == toolchain["version"], "pinned kernel compiler version mismatch")
    work = cache / "toolchain/preflight"
    work.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="compile-", dir=work) as directory:
        root = Path(directory)
        source = root / "probe.c"
        object_file = root / "probe.o"
        source.write_text(
            "#include <stddef.h>\n"
            "size_t cfmgr_compiler_probe(size_t value) { return value + 1; }\n"
        )
        # -c exercises cc1, the compiler's own headers and the AArch64 assembler.
        # No target libc, linking, guest execution or expensive kernel build.
        run(
            kernel_command(
                [
                    compiler + "gcc",
                    "-O2",
                    "-ffreestanding",
                    "-c",
                    str(source),
                    "-o",
                    str(object_file),
                ],
                runtime,
            ),
            timeout=30,
        )
        verify_elf(object_file, "aarch64-3.10")
        _require(
            int.from_bytes(object_file.read_bytes()[16:18], "little") == 1,
            "compiler preflight must produce an ELF relocatable object",
        )


def prepare_kernel_compiler(
    toolchain: dict[str, Any], downloads: Path, cache: Path
) -> tuple[str, Path | None]:
    archive = download(
        toolchain["url"],
        toolchain["sha256"],
        downloads / f"kernel-compiler-{toolchain['version']}.tar.xz",
    )
    root = cache / "toolchain" / toolchain["sha256"]
    if not root.exists():
        extract_tar(archive, root)
    compiler = str(root / toolchain["prefix"])
    runtime = (
        stage_kernel_runtime(toolchain["runtime"], downloads, cache)
        if toolchain["runtime"] is not None
        else None
    )
    compiler_preflight(compiler, runtime, cache, toolchain)
    return compiler, runtime


def compiler_input_key(toolchain: dict[str, Any]) -> str:
    """Share only identical pinned compiler bytes and their verification recipe."""
    digest = hashlib.sha256(json.dumps(toolchain, sort_keys=True).encode())
    functions = [
        prepare_compiler_inputs,
        prepare_kernel_compiler,
        compiler_preflight,
        kernel_command,
        download,
        verify_hash,
        verify_elf,
        extract_tar,
        _parents_safe,
        _relative,
        _input_receipt,
        _finish_inputs,
    ]
    if toolchain["runtime"] is not None:
        functions.extend((stage_kernel_runtime, ipk_data))
    for function in functions:
        digest.update(inspect.getsource(function).encode())
    return digest.hexdigest()


def feed_input_key(manifest: dict[str, Any]) -> str:
    pins = [
        {
            "id": feed["id"],
            "packages": [
                {key: package[key] for key in ("filename", "sha256")}
                for package in sorted(
                    feed["packages"], key=lambda item: item["filename"]
                )
            ],
        }
        for feed in sorted(manifest["feeds"], key=lambda item: item["id"])
    ]
    digest = hashlib.sha256(json.dumps(pins, sort_keys=True).encode())
    for function in (
        prepare_feed_inputs,
        download,
        verify_hash,
        _input_receipt,
        _finish_inputs,
    ):
        digest.update(inspect.getsource(function).encode())
    return digest.hexdigest()


def _input_receipt(root: Path) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    receipt = _parents_safe(root, PurePosixPath("verified.json"))
    _require(not receipt.is_symlink(), "unsafe input cache receipt")
    if receipt.exists():
        _require(receipt.is_file(), "invalid input cache receipt")
        receipt.unlink()
    return receipt


def _finish_inputs(root: Path, receipt: Path, key: str) -> None:
    _require(not any(root.rglob("*.part")), "unfinished input cache download")
    receipt.write_text(json.dumps({"key": key}, sort_keys=True) + "\n")


def prepare_compiler_inputs(
    toolchain: dict[str, Any], cache: Path
) -> tuple[str, Path | None]:
    key = compiler_input_key(toolchain)
    root = cache / "compiler-inputs" / key
    receipt = _input_receipt(root)
    compiler, runtime = prepare_kernel_compiler(toolchain, root / "downloads", root)
    # Only the immutable compiler/runtime/archive bundle is saved, never probes.
    preflight = root / "toolchain/preflight"
    if preflight.exists():
        _require(
            preflight.is_dir() and not preflight.is_symlink(),
            "unsafe compiler preflight directory",
        )
        preflight.rmdir()
    _finish_inputs(root, receipt, key)
    return compiler, runtime


def prepare_feed_inputs(manifest: dict[str, Any], cache: Path) -> Path:
    key = feed_input_key(manifest)
    root = cache / "feed-inputs" / key
    receipt = _input_receipt(root)
    for feed in manifest["feeds"]:
        for package in feed["packages"]:
            download(
                f"https://bin.entware.net/{feed['id']}/{package['filename']}",
                package["sha256"],
                root / feed["id"] / package["filename"],
                limit=MAX_PACKAGE,
            )
    _finish_inputs(root, receipt, key)
    return root


def prepare_kernel_source(kernel: dict[str, Any], cache: Path) -> Path:
    return download(
        kernel["url"],
        kernel["sha256"],
        cache
        / "kernel-inputs"
        / kernel["sha256"]
        / f"linux-{kernel['version']}.tar.xz",
    )


def stage_feeds(manifest: dict[str, Any], downloads: Path, root: Path) -> None:
    for feed in manifest["feeds"]:
        destination = root / "feeds" / feed["id"]
        for package in feed["packages"]:
            url = f"https://bin.entware.net/{feed['id']}/{package['filename']}"
            archive = download(
                url,
                package["sha256"],
                downloads / feed["id"] / package["filename"],
                limit=MAX_PACKAGE,
            )
            extract_tar(
                ipk_data(archive), destination, package=True, limit=128 * 1024 * 1024
            )
        # These pinned Entware packages declare opkg alternatives in their
        # control metadata; the disposable fixture creates the same links
        # without running package maintainer scripts.
        for command in ("timeout", "sha256sum"):
            alternative = destination / "opt/bin" / command
            _require(
                not alternative.exists() and not alternative.is_symlink(),
                "unexpected Entware alternative",
            )
            alternative.symlink_to(f"../libexec/{command}-coreutils")
        for name in (
            "bin/jq",
            "libexec/timeout-coreutils",
            "libexec/sha256sum-coreutils",
            "bin/util-linux-flock",
            "bin/dig",
        ):
            verify_elf(destination / "opt" / name, feed["architecture"])


def newc_archive(root: Path, destination: Path) -> None:
    """Small deterministic newc writer; preserves inert links without host traversal."""
    with (
        destination.open("wb") as output,
        gzip.GzipFile(filename="", mode="wb", fileobj=output, mtime=0) as compressed,
    ):
        inode = 1

        def entry(name: str, mode: int, data: bytes, links: int = 1) -> None:
            nonlocal inode
            encoded = name.encode() + b"\x00"
            fields = [
                inode,
                mode,
                0,
                0,
                links,
                0,
                len(data),
                0,
                0,
                0,
                0,
                len(encoded),
                0,
            ]
            header = b"070701" + b"".join(f"{field:08x}".encode() for field in fields)
            compressed.write(header + encoded)
            compressed.write(b"\x00" * (-(len(header) + len(encoded)) % 4))
            compressed.write(data)
            compressed.write(b"\x00" * (-len(data) % 4))
            inode += 1

        for directory, children, files in os.walk(root, followlinks=False):
            children.sort()
            files.sort()
            for name in [*children, *files]:
                path = Path(directory) / name
                info = path.lstat()
                relative = path.relative_to(root).as_posix()
                if stat.S_ISLNK(info.st_mode):
                    data = os.readlink(path).encode()
                    mode = stat.S_IFLNK | 0o777
                elif stat.S_ISDIR(info.st_mode):
                    data = b""
                    mode = info.st_mode & ~0o6000
                elif stat.S_ISREG(info.st_mode):
                    data = path.read_bytes()
                    mode = info.st_mode & ~0o6000
                else:
                    raise PlatformError("unexpected initramfs special file")
                entry(
                    relative,
                    mode,
                    data,
                    2 if stat.S_ISDIR(info.st_mode) else 1,
                )
        entry("TRAILER!!!", 0, b"")


def prepare_guest(
    manifest: dict[str, Any],
    kernel: dict[str, Any],
    busybox: Path,
    downloads: Path,
    work: Path,
    package: Path,
) -> Path:
    root = work / "root"
    _require(not root.exists(), "guest root must be fresh")
    root.mkdir()
    for name in (
        "bin",
        "sbin",
        "usr/bin",
        "usr/sbin",
        "proc",
        "sys",
        "dev",
        "cfmgr",
        "opt",
        "jffs",
        "tmp",
        "mnt/cfmgr-scratch",
    ):
        (root / name).mkdir(parents=True, exist_ok=True)
    shutil.copy2(busybox, root / "bin/busybox")
    bin_applets = [
        "sh",
        "cat",
        "echo",
        "ls",
        "mkdir",
        "cp",
        "chmod",
        "df",
        "mv",
        "rm",
        "rmdir",
        "fsync",
        "readlink",
        "pwd",
        "test",
        "[",
        "printf",
        "uname",
        "sleep",
        "usleep",
        "wc",
        "flock",
        "blkid",
        "mount",
        "umount",
    ]
    for name in bin_applets:
        (root / "bin" / name).symlink_to("busybox")
    for name in ("awk", "cmp", "env", "printf", "readlink", "wc"):
        (root / "usr/bin" / name).symlink_to("../../bin/busybox")
    (root / "usr/bin/flock").symlink_to("../../bin/busybox")
    (root / "sbin/blkid").symlink_to("../bin/busybox")
    (root / "sbin/poweroff").symlink_to("../bin/busybox")
    nvram = root / "bin/nvram"
    nvram.write_text(
        "#!/bin/sh\n"
        '[ "$#" -eq 2 ] && [ "$1" = get ] && [ "$2" = jffs2_scripts ] || exit 2\n'
        "printf '1\\n'\n"
    )
    nvram.chmod(0o755)
    shutil.copy2(FIXTURES / "init.sh", root / "init")
    (root / "init").chmod(0o755)
    library = (ROOT / "modules/lib/storage.sh").read_bytes()
    (root / "cfmgr/probe.sh").write_bytes(
        library + (ROOT / "tools/router-storage-probe.sh").read_bytes()
    )
    item = next(
        item for item in manifest["busyboxes"] if item["id"] == kernel["busybox"]
    )
    (root / "cfmgr/identity").write_text(
        f"{kernel['version']} {item['id']} {item['version']}\n"
    )
    (root / "cfmgr/sha-input").write_bytes(b"abc")
    feed_lines = []
    for feed in manifest["feeds"]:
        packages = {
            package["name"]: package["version"].rsplit("-", 1)[0]
            for package in feed["packages"]
        }
        feed_lines.append(
            " ".join(
                [
                    feed["id"],
                    feed["architecture"],
                    packages["jq"],
                    packages["coreutils-timeout"],
                    packages["flock"],
                    packages["bind-dig"],
                ]
            )
        )
    (root / "cfmgr/feeds").write_text("\n".join(feed_lines) + "\n")
    shutil.copytree(package, root / "cfmgr/package")
    volume = work / "volume"
    volume.mkdir()
    (volume / "tmp").mkdir()
    (volume / "feeds").mkdir()
    stage_feeds(manifest, downloads, root)
    package_entries = []
    for source in sorted(path for path in package.rglob("*") if path.is_file()):
        relative = source.relative_to(package).as_posix()
        target = (
            "/jffs/scripts/cfmgr.sh"
            if relative == "cfmgr.sh"
            else f"/jffs/addons/CFMgr.d/{relative}"
        )
        package_entries.append(
            (hashlib.sha256(source.read_bytes()).hexdigest(), target)
        )
    (root / "cfmgr/installed.sha256").write_text(
        "".join(f"{digest}  {target}\n" for digest, target in package_entries)
    )
    archive = work / "initramfs.cpio.gz"
    newc_archive(root, archive)
    return archive


def kernel_configuration(version: str) -> dict[str, str]:
    values = configuration(FIXTURES / "kernel.config")
    if version.startswith("4.1."):
        values["CONFIG_CC_STACKPROTECTOR_NONE"] = "y"
        # This legacy absolute-address option was removed before 4.19.
        values["CONFIG_MTDRAM_ABS_POS"] = "0x0"
    else:
        # The 4.1 ARM64 sources build these unconditionally without Kconfig symbols.
        values["CONFIG_POSIX_TIMERS"] = "y"
        values["CONFIG_ARM_PSCI_FW"] = "y"
        # 4.19 gates MMIO transport behind this menu; 4.1 has no such symbol.
        values["CONFIG_VIRTIO_MENU"] = "y"
    return values


def build_kernel(
    kernel: dict[str, Any],
    compiler: str,
    downloads: Path,
    cache: Path,
    recipe: str,
    runtime: Path | None,
) -> Path:
    version = kernel["version"]
    output = cache / "kernels" / version / recipe
    image = output / "Image"
    receipt = output / "verified.json"
    if image.is_file() and receipt.is_file():
        saved = json.loads(receipt.read_text())
        _require(
            saved["source"] == kernel["sha256"] and saved["recipe"] == recipe,
            "kernel cache receipt mismatch",
        )
        verify_hash(image, saved["sha256"])
        return image
    archive = download(
        kernel["url"], kernel["sha256"], downloads / f"linux-{version}.tar.xz"
    )
    build = ROOT / ".tmp/platform-builds/kernels" / version / recipe
    _require(
        not build.exists(),
        "unfinished kernel build; inspect retained cache before retry",
    )
    build.mkdir(parents=True)
    extract_tar(archive, build / "linux")
    source = build / "linux" / f"linux-{version}"
    make = kernel_command(
        [
            "make",
            "ARCH=arm64",
            "CROSS_COMPILE=" + compiler,
            "HOSTCFLAGS=-O2 -fcommon",
        ],
        runtime,
    )
    run([*make, "allnoconfig"], cwd=source)
    values = kernel_configuration(version)
    apply_configuration(source / ".config", values)
    run([*make, "olddefconfig"], cwd=source)
    check_configuration(source / ".config", values)
    release = subprocess.check_output(
        [*make, "-s", "kernelrelease"], cwd=source, text=True
    ).strip()
    _require(release == version, "built kernel release mismatch")
    run([*make, "-j2", "Image"], cwd=source, timeout=1800)
    output.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / "arch/arm64/boot/Image", image)
    receipt.write_text(
        json.dumps(
            {
                "source": kernel["sha256"],
                "recipe": recipe,
                "sha256": hashlib.sha256(image.read_bytes()).hexdigest(),
            },
            indent=2,
        )
        + "\n"
    )
    return image


def verify_guest_log(
    log: str, kernel: dict[str, Any], manifest: dict[str, Any]
) -> None:
    lines = log.replace("\r", "").splitlines()
    item = next(
        item for item in manifest["busyboxes"] if item["id"] == kernel["busybox"]
    )
    required = [
        f"CFMGR_KERNEL={kernel['version']}",
        f"CFMGR_BUSYBOX={item['id']}:{item['version']}",
        "CFMGR_STORAGE=OK",
        f"CFMGR_PLATFORM_OK_v1:{kernel['version']}:{item['id']}",
    ]
    required.extend(
        marker
        for feed in manifest["feeds"]
        for marker in (
            f"CFMGR_FEED={feed['id']}:{feed['architecture']}:OK",
            f"CFMGR_INSTALL={feed['id']}:OK",
        )
    )
    _require(
        not any("CFMGR_PLATFORM_FAIL:" in line for line in lines),
        "guest explicitly reported failure",
    )
    for marker in required:
        _require(
            lines.count(marker) == 1, f"missing or duplicate guest proof: {marker}"
        )


def boot_guest(
    image: Path,
    initramfs: Path,
    kernel: dict[str, Any],
    manifest: dict[str, Any],
    work: Path,
) -> None:
    disk = work / "scratch.ext4"
    with disk.open("xb") as output:
        output.truncate(64 * 1024 * 1024)
    run(
        [
            "mke2fs",
            "-q",
            "-F",
            "-t",
            "ext4",
            "-d",
            str(work / "volume"),
            "-b",
            "1024",
            "-O",
            "^64bit,^metadata_csum,^orphan_file,^metadata_csum_seed",
            str(disk),
        ]
    )
    command = [
        "qemu-system-aarch64",
        "-machine",
        "virt,gic-version=2,highmem=off",
        "-cpu",
        "cortex-a53",
        "-accel",
        "tcg",
        "-smp",
        "1",
        "-m",
        "256M",
        "-object",
        "rng-random,id=cfmgr-rng,filename=/dev/urandom",
        "-device",
        "virtio-rng-device,rng=cfmgr-rng",
        "-nographic",
        "-no-reboot",
        "-net",
        "none",
        "-kernel",
        str(image),
        "-initrd",
        str(initramfs),
        "-append",
        "console=ttyAMA0 rdinit=/init panic=1",
        "-drive",
        f"file={disk},format=raw,if=none,id=scratch",
        "-device",
        "virtio-blk-device,drive=scratch",
    ]
    log = work / "guest.log"
    try:
        with log.open("wb") as output:
            result = subprocess.run(
                command,
                stdout=output,
                stderr=subprocess.STDOUT,
                check=False,
                # Legacy ARM startup plus both guarded Entware install proofs.
                timeout=600,
            )
    finally:
        text = log.read_text(errors="replace")
        print(text, end="", flush=True)
    _require(result.returncode == 0, f"QEMU exited {result.returncode}")
    verify_guest_log(text, kernel, manifest)


def require_linux_host() -> None:
    _require(
        sys.platform == "linux" and os.uname().machine == "x86_64",
        "explicit platform builds require Linux x86_64 CI",
    )


def execute_native_busybox(manifest: dict[str, Any]) -> None:
    """Build only the pinned baseline applets for the required host Linux suite."""
    require_linux_host()
    for tool in ("make", "gcc", "git", "dpkg-query"):
        _require(shutil.which(tool) is not None, f"missing native build tool: {tool}")
    item = next(item for item in manifest["busyboxes"] if item["id"] == "baseline")
    binary = build_busybox(item, ROOT / ".tmp/platform-cache", target="native")
    verify_elf(binary, "x86_64")
    expected = hashlib.sha256(binary.read_bytes()).hexdigest()
    destination = _parents_safe(ROOT, PurePosixPath(".tmp/native-busybox/bin/busybox"))
    _require(
        not destination.is_symlink()
        and (not destination.exists() or destination.is_file()),
        "unsafe native BusyBox destination",
    )
    shutil.copyfile(binary, destination)
    verify_hash(destination, expected)
    verify_elf(destination, "x86_64")
    destination.chmod(0o755)
    print(f"Verified native vendor BusyBox staged at {destination.relative_to(ROOT)}")


def build_platform_package(destination: Path) -> None:
    run([sys.executable, str(ROOT / "tools/package.py"), "--output", str(destination)])


def execute(manifest: dict[str, Any], selected: str | None) -> None:
    require_linux_host()
    for tool in (
        "make",
        "gcc",
        "git",
        "arm-linux-gnueabi-gcc",
        "qemu-system-aarch64",
        "mke2fs",
        "bc",
        "bison",
        "flex",
    ):
        _require(shutil.which(tool) is not None, f"missing platform tool: {tool}")
    cache = ROOT / ".tmp/platform-cache"
    feed_downloads = cache / "feed-inputs" / feed_input_key(manifest)
    compilers: dict[str, tuple[str, Path | None]] = {}
    work_root = ROOT / ".tmp/platform-runs"
    work_root.mkdir(parents=True, exist_ok=True)
    package_work = Path(tempfile.mkdtemp(prefix="package-", dir=work_root))
    package = package_work / "package"
    package_ready = False
    for kernel in manifest["kernels"]:
        if selected and kernel["version"] != selected:
            continue
        toolchain = kernel_toolchain(manifest, kernel)
        if toolchain["version"] not in compilers:
            compilers[toolchain["version"]] = prepare_compiler_inputs(toolchain, cache)
        compiler, runtime = compilers[toolchain["version"]]
        busybox_item = next(
            item for item in manifest["busyboxes"] if item["id"] == kernel["busybox"]
        )
        binary = build_busybox(busybox_item, cache)
        recipe = build_key("kernel", kernel, toolchain)
        downloads = cache / "kernel-inputs" / kernel["sha256"]
        image = build_kernel(kernel, compiler, downloads, cache, recipe, runtime)
        if not package_ready:
            build_platform_package(package)
            package_ready = True
        # The guest resets only paths it just installed between feed profiles;
        # the actual JFFS2 mount remains live and all installs stay observable.
        work = Path(tempfile.mkdtemp(prefix=kernel["version"] + "-", dir=work_root))
        initramfs = prepare_guest(
            manifest, kernel, binary, feed_downloads, work, package
        )
        boot_guest(image, initramfs, kernel, manifest, work)
        print(
            f"Accepted generic guest proof: {kernel['version']} / {kernel['busybox']}; logs retained at {work.relative_to(ROOT)}",
            flush=True,
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--run",
        action="store_true",
        help="explicit Linux CI downloads, builds and disposable guests",
    )
    parser.add_argument(
        "--kernel",
        choices=sorted(VERSIONS),
        help="one exact profile; default runs serially",
    )
    parser.add_argument(
        "--native-busybox",
        action="store_true",
        help="explicit Linux x86_64 baseline BusyBox build only; no ARM guests or feeds",
    )
    parser.add_argument(
        "--cache-keys",
        action="store_true",
        help="CI cache keys only; probes local compiler package versions without builds or downloads",
    )
    preparation = parser.add_mutually_exclusive_group()
    preparation.add_argument(
        "--prepare-compiler",
        action="store_true",
        help="verify selected prebuilt compiler inputs before saving their CI cache",
    )
    preparation.add_argument(
        "--prepare-feeds",
        action="store_true",
        help="verify both pinned Entware archive closures before saving their CI cache",
    )
    preparation.add_argument(
        "--prepare-kernel-source",
        action="store_true",
        help="verify one kernel source archive without building or booting",
    )
    args = parser.parse_args()
    try:
        preparing = (
            args.prepare_compiler or args.prepare_feeds or args.prepare_kernel_source
        )
        _require(
            not preparing or not (args.run or args.cache_keys or args.native_busybox),
            "input preparation cannot be combined with runtime or cache-key modes",
        )
        _require(
            not preparing
            or (args.kernel is not None and not args.prepare_feeds)
            or (args.prepare_feeds and args.kernel is None),
            "compiler/source preparation requires one kernel; feed preparation is shared",
        )
        _require(
            not (args.native_busybox and (args.run or args.kernel)),
            "--native-busybox cannot be combined with --run or --kernel",
        )
        manifest = load_manifest()
        if preparing:
            cache = ROOT / ".tmp/platform-cache"
            if args.prepare_feeds:
                prepare_feed_inputs(manifest, cache)
            else:
                kernel = next(
                    item
                    for item in manifest["kernels"]
                    if item["version"] == args.kernel
                )
                if args.prepare_compiler:
                    require_linux_host()
                    prepare_compiler_inputs(kernel_toolchain(manifest, kernel), cache)
                else:
                    prepare_kernel_source(kernel, cache)
        elif args.native_busybox:
            if args.cache_keys:
                require_linux_host()
                busybox = next(
                    item for item in manifest["busyboxes"] if item["id"] == "baseline"
                )
                print("busybox=" + build_key("busybox", busybox, target="native"))
            else:
                execute_native_busybox(manifest)
        elif args.cache_keys:
            _require(
                not args.run and args.kernel is not None,
                "cache keys require one --kernel without --run",
            )
            kernel = next(
                item for item in manifest["kernels"] if item["version"] == args.kernel
            )
            busybox = next(
                item
                for item in manifest["busyboxes"]
                if item["id"] == kernel["busybox"]
            )
            print(
                "kernel="
                + build_key("kernel", kernel, kernel_toolchain(manifest, kernel))
            )
            print("busybox=" + build_key("busybox", busybox))
            print("compiler=" + compiler_input_key(kernel_toolchain(manifest, kernel)))
            print("feeds=" + feed_input_key(manifest))
            print("source=" + kernel["sha256"])
        elif args.run:
            execute(manifest, args.kernel)
        else:
            for kernel in manifest["kernels"]:
                if not args.kernel or kernel["version"] == args.kernel:
                    print(
                        f"{kernel['version']}: vendor BusyBox {kernel['busybox']}; both ARM Entware feeds; execution pending"
                    )
            print(
                "Manifest validated offline; no downloads, builds or guest execution."
            )
        return 0
    except (
        PlatformError,
        KeyError,
        ValueError,
        OSError,
        tarfile.TarError,
        subprocess.SubprocessError,
    ) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
