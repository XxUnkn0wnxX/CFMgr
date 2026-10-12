"""Offline runner safety and evidence oracles; no kernel build or network."""

from __future__ import annotations

import copy
import gzip
import hashlib
import io
import json
import os
import re
import subprocess
import tarfile
from pathlib import Path

import pytest

from tools import test_platforms as platforms


@pytest.fixture(scope="module")
def manifest() -> dict:
    return platforms.load_manifest()


@pytest.fixture(autouse=True)
def offline_kernel_runtime_identity(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        platforms, "kernel_runtime_identity", lambda: b"fixed host runtime packages"
    )


def archive_bytes(entries: list[tuple[str, bytes | str, bytes]]) -> bytes:
    output = io.BytesIO()
    with tarfile.open(fileobj=output, mode="w:gz") as archive:
        for name, contents, kind in entries:
            info = tarfile.TarInfo(name)
            info.type = kind
            info.mode = 0o755
            if kind == tarfile.SYMTYPE:
                info.linkname = str(contents)
                archive.addfile(info)
            else:
                assert isinstance(contents, bytes)
                info.size = len(contents)
                archive.addfile(info, io.BytesIO(contents))
    return output.getvalue()


def test_manifest_rejects_missing_profile_closure_or_digest(
    manifest: dict, tmp_path: Path
) -> None:
    cases = []
    missing_kernel = copy.deepcopy(manifest)
    missing_kernel["kernels"].pop()
    cases.append(missing_kernel)
    wrong_hash = copy.deepcopy(manifest)
    wrong_hash["toolchain"]["sha256"] = "guess"
    cases.append(wrong_hash)
    for field, value in (
        ("url", "https://example.com/libmpfr4.deb"),
        ("architecture", "arm64"),
        ("soname", "libmpfr.so.6"),
        ("sha256", "guess"),
        ("library_sha256", "guess"),
    ):
        wrong_runtime = copy.deepcopy(manifest)
        wrong_runtime["toolchain"]["runtime"][field] = value
        cases.append(wrong_runtime)
    missing_dependency = copy.deepcopy(manifest)
    missing_dependency["feeds"][0]["packages"].pop()
    cases.append(missing_dependency)
    wrong_vendor = copy.deepcopy(manifest)
    wrong_vendor["busyboxes"][0]["repository"] = "https://busybox.net/"
    cases.append(wrong_vendor)
    wrong_abi = copy.deepcopy(manifest)
    wrong_abi["feeds"][1]["architecture"] = "aarch64-3.10"
    cases.append(wrong_abi)
    for index, value in enumerate(cases):
        fixture = tmp_path / f"invalid-{index}.json"
        fixture.write_text(json.dumps(value))
        with pytest.raises(platforms.PlatformError):
            platforms.load_manifest(fixture)


def test_cached_download_requires_exact_hash_without_network(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    target = tmp_path / "archive"
    target.write_bytes(b"pinned bytes")
    expected = hashlib.sha256(target.read_bytes()).hexdigest()

    def forbidden_network(*args: object, **kwargs: object) -> None:
        pytest.fail("Cached/offline verification attempted a network request")

    monkeypatch.setattr(platforms.urllib.request, "urlopen", forbidden_network)
    assert (
        platforms.download("https://www.kernel.org/source.tar.xz", expected, target)
        == target
    )
    with pytest.raises(platforms.PlatformError, match="SHA256 mismatch"):
        platforms.download("https://www.kernel.org/source.tar.xz", "0" * 64, target)
    assert target.read_bytes() == b"pinned bytes"


@pytest.mark.parametrize(
    "entries",
    [
        [("../escape", b"bad", tarfile.REGTYPE)],
        [("/absolute", b"bad", tarfile.REGTYPE)],
        [("etc/config", b"bad", tarfile.REGTYPE)],
        [("opt/link", "/tmp/escape", tarfile.SYMTYPE)],
        [("opt/link", "../../escape", tarfile.SYMTYPE)],
        [
            ("opt/link", "/opt/lib", tarfile.SYMTYPE),
            ("opt/link/escape", b"bad", tarfile.REGTYPE),
        ],
        [("opt/device", b"", tarfile.CHRTYPE)],
    ],
)
def test_extraction_rejects_host_escape_or_special_files(
    tmp_path: Path, entries: list[tuple[str, bytes | str, bytes]]
) -> None:
    with pytest.raises(platforms.PlatformError):
        platforms.extract_tar(
            io.BytesIO(archive_bytes(entries)), tmp_path / "stage", package=True
        )
    assert not (tmp_path / "escape").exists()


def test_package_extraction_keeps_absolute_opt_links_inert(tmp_path: Path) -> None:
    root = tmp_path / "stage"
    payload = archive_bytes(
        [
            ("./opt/lib/libc-2.27.so", b"library", tarfile.REGTYPE),
            ("./opt/lib/libc.so.6", "/opt/lib/libc-2.27.so", tarfile.SYMTYPE),
        ]
    )
    platforms.extract_tar(io.BytesIO(payload), root, package=True)
    link = root / "opt/lib/libc.so.6"
    assert link.is_symlink()
    assert link.readlink() == Path("/opt/lib/libc-2.27.so")
    assert (root / "opt/lib/libc-2.27.so").read_bytes() == b"library"
    traversal = archive_bytes([("opt/lib/libc.so.6/escape", b"bad", tarfile.REGTYPE)])
    with pytest.raises(platforms.PlatformError, match="symlink"):
        platforms.extract_tar(io.BytesIO(traversal), root, package=True)
    with pytest.raises(platforms.PlatformError, match="bound"):
        platforms.extract_tar(
            io.BytesIO(payload), tmp_path / "bounded", package=True, limit=1
        )


def test_ipk_tar_and_ar_extract_only_data_not_maintainer_scripts(
    tmp_path: Path,
) -> None:
    data = archive_bytes([("opt/bin/tool", b"binary", tarfile.REGTYPE)])
    control = archive_bytes([("postinst", b"DO NOT RUN", tarfile.REGTYPE)])
    tar_package = archive_bytes(
        [
            ("debian-binary", b"2.0\n", tarfile.REGTYPE),
            ("control.tar.gz", control, tarfile.REGTYPE),
            ("data.tar.gz", data, tarfile.REGTYPE),
        ]
    )
    ar_package = bytearray(b"!<arch>\n")
    for name, contents in (
        ("debian-binary", b"2.0\n"),
        ("control.tar.gz", control),
        ("data.tar.gz", data),
    ):
        header = f"{name + '/':<16}{0:<12}{0:<6}{0:<6}{'100644':<8}{len(contents):<10}`\n".encode()
        assert len(header) == 60
        ar_package.extend(header + contents + (b"\n" if len(contents) % 2 else b""))
    for name, contents in (("tar.ipk", tar_package), ("ar.ipk", bytes(ar_package))):
        package = tmp_path / name
        package.write_bytes(contents)
        root = tmp_path / name.removesuffix(".ipk")
        platforms.extract_tar(platforms.ipk_data(package), root, package=True)
        assert (root / "opt/bin/tool").read_bytes() == b"binary"
        assert not (root / "postinst").exists()


def test_guest_proof_requires_every_exact_marker(manifest: dict) -> None:
    kernel = manifest["kernels"][0]
    lines = [
        "CFMGR_KERNEL=4.1.51",
        "CFMGR_BUSYBOX=baseline:1.25.1",
        "CFMGR_STORAGE=OK",
        *[
            f"CFMGR_FEED={feed['id']}:{feed['architecture']}:OK"
            for feed in manifest["feeds"]
        ],
        "CFMGR_PLATFORM_OK_v1:4.1.51:baseline",
    ]
    log = "\r\n".join(lines)
    platforms.verify_guest_log(log, kernel, manifest)
    for failed in (
        log.replace("4.1.51", "4.19.294"),
        log.replace(lines[-1], ""),
        log.replace(lines[2], ""),
        log + "\nCFMGR_PLATFORM_FAIL:storage\n",
        log + "\n" + lines[-1],
        "QEMU exited successfully\n",
    ):
        with pytest.raises(platforms.PlatformError):
            platforms.verify_guest_log(failed, kernel, manifest)


def elf_header(elf_class: int, machine: int) -> bytes:
    header = bytearray(20)
    header[:4] = b"\x7fELF"
    header[4:6] = bytes((elf_class, 1))
    header[18:20] = machine.to_bytes(2, "little")
    return bytes(header)


def test_elf_machine_and_class_must_match_each_target(tmp_path: Path) -> None:
    for architecture, elf_class, machine in (
        ("aarch64-3.10", 2, 183),
        ("armv7-3.2", 1, 40),
        ("x86_64", 2, 62),
    ):
        executable = tmp_path / architecture
        executable.write_bytes(elf_header(elf_class, machine))
        platforms.verify_elf(executable, architecture)
        other = "armv7-3.2" if elf_class == 2 else "aarch64-3.10"
        with pytest.raises(platforms.PlatformError, match="ABI"):
            platforms.verify_elf(executable, other)
    with pytest.raises(platforms.PlatformError, match="unknown executable ABI"):
        platforms.verify_elf(executable, "unknown")


def test_initramfs_writer_preserves_links_and_root_owned_modes(tmp_path: Path) -> None:
    root = tmp_path / "root"
    (root / "bin").mkdir(parents=True)
    (root / "bin/busybox").write_bytes(b"executable")
    (root / "bin/busybox").chmod(0o755)
    (root / "bin/sh").symlink_to("busybox")
    (root / "opt").symlink_to("/opt")
    output = tmp_path / "initramfs.gz"
    platforms.newc_archive(root, output)
    archive = gzip.decompress(output.read_bytes())
    offset = 0
    entries = {}
    while offset < len(archive):
        assert archive[offset : offset + 6] == b"070701"
        fields = [
            int(archive[offset + 6 + index * 8 : offset + 14 + index * 8], 16)
            for index in range(13)
        ]
        mode, uid, gid, size, name_size = (
            fields[1],
            fields[2],
            fields[3],
            fields[6],
            fields[11],
        )
        name_start = offset + 110
        name = archive[name_start : name_start + name_size - 1].decode()
        data_start = (name_start + name_size + 3) & ~3
        entries[name] = (mode, uid, gid, archive[data_start : data_start + size])
        offset = (data_start + size + 3) & ~3
        if name == "TRAILER!!!":
            break
    assert entries["bin/busybox"] == (0o100755, 0, 0, b"executable")
    assert entries["bin/sh"] == (0o120777, 0, 0, b"busybox")
    assert entries["opt"] == (0o120777, 0, 0, b"/opt")


def test_kernel_cache_key_tracks_build_inputs_without_guest_or_feed_changes(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixtures = tmp_path / "fixtures"
    fixtures.mkdir()
    kernel_config = fixtures / "kernel.config"
    kernel_config.write_bytes((platforms.FIXTURES / "kernel.config").read_bytes())
    (fixtures / "busybox.config").write_bytes(
        (platforms.FIXTURES / "busybox.config").read_bytes()
    )
    (fixtures / "init.sh").write_text("guest v1\n")
    monkeypatch.setattr(platforms, "FIXTURES", fixtures)
    monkeypatch.setattr(
        platforms, "compiler_identity", lambda target="arm": b"fixed compiler packages"
    )
    kernel = copy.deepcopy(manifest["kernels"][0])
    toolchain = copy.deepcopy(manifest["toolchain"])
    original = platforms.build_key("kernel", kernel, toolchain)
    (fixtures / "init.sh").write_text("guest v2\n")
    kernel["busybox"] = "ax-current"
    assert platforms.build_key("kernel", kernel, toolchain) == original
    toolchain["sha256"] = "0" * 64
    assert platforms.build_key("kernel", kernel, toolchain) != original
    toolchain = manifest["toolchain"]
    changed_runtime = copy.deepcopy(toolchain)
    changed_runtime["runtime"]["sha256"] = "0" * 64
    assert platforms.build_key("kernel", kernel, changed_runtime) != original
    kernel_config.write_text(kernel_config.read_text() + "CONFIG_TEST_DIFFERENT=y\n")
    assert platforms.build_key("kernel", kernel, toolchain) != original


def test_kernel_runtime_package_identity_invalidates_only_kernel(
    manifest: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(platforms, "compiler_identity", lambda target="arm": b"gcc")
    item = manifest["busyboxes"][0]
    keys = {
        target: platforms.build_key("busybox", item, target=target)
        for target in ("arm", "native")
    }
    kernel = manifest["kernels"][0]
    original = platforms.build_key("kernel", kernel, manifest["toolchain"])
    monkeypatch.setattr(platforms, "kernel_runtime_identity", lambda: b"changed mpc")
    assert platforms.build_key("kernel", kernel, manifest["toolchain"]) != original
    for target, key in keys.items():
        assert platforms.build_key("busybox", item, target=target) == key


def test_private_compiler_runtime_is_hash_verified_data_only(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime = copy.deepcopy(manifest["toolchain"]["runtime"])
    library_bytes = bytearray(elf_header(2, 62))
    library_bytes[16:18] = (3).to_bytes(2, "little")
    data = archive_bytes(
        [
            (runtime["library"], bytes(library_bytes), tarfile.REGTYPE),
            (
                "usr/lib/x86_64-linux-gnu/libmpfr.so.4",
                "libmpfr.so.4.1.5",
                tarfile.SYMTYPE,
            ),
        ]
    )
    package_bytes = archive_bytes(
        [
            ("data.tar.gz", data, tarfile.REGTYPE),
            (
                "control.tar.gz",
                archive_bytes([("postinst", b"DO NOT RUN", tarfile.REGTYPE)]),
                tarfile.REGTYPE,
            ),
        ]
    )
    downloads = tmp_path / "downloads"
    downloads.mkdir()
    package = downloads / "libmpfr4_3.1.5-1_amd64.deb"
    package.write_bytes(package_bytes)
    runtime["sha256"] = hashlib.sha256(package_bytes).hexdigest()
    runtime["library_sha256"] = hashlib.sha256(library_bytes).hexdigest()

    def forbidden_network(*args: object, **kwargs: object) -> None:
        pytest.fail("Private runtime regression attempted a network request")

    monkeypatch.setattr(platforms.urllib.request, "urlopen", forbidden_network)
    cache = tmp_path / "cache"
    directory = platforms.stage_kernel_runtime(runtime, downloads, cache)
    assert (
        directory
        == cache / "toolchain/runtime" / runtime["sha256"] / "usr/lib/x86_64-linux-gnu"
    )
    root = cache / "toolchain/runtime" / runtime["sha256"]
    assert not (root / "postinst").exists()
    assert platforms.stage_kernel_runtime(runtime, downloads, cache) == directory
    extra = directory / "libgmp.so.10"
    extra.write_bytes(b"unverified loader input")
    with pytest.raises(platforms.PlatformError, match="unexpected private"):
        platforms.stage_kernel_runtime(runtime, downloads, cache)
    extra.unlink()
    library = directory / "libmpfr.so.4.1.5"
    library.write_bytes(bytes(library_bytes) + b"corruption")
    with pytest.raises(platforms.PlatformError, match="SHA256 mismatch"):
        platforms.stage_kernel_runtime(runtime, downloads, cache)
    library.write_bytes(elf_header(1, 40))
    with pytest.raises(platforms.PlatformError, match="ABI"):
        platforms.stage_kernel_runtime(runtime, downloads, cache)
    library.write_bytes(library_bytes)
    soname = directory / "libmpfr.so.4"
    soname.unlink()
    soname.symlink_to("/unrelated/libmpfr.so.6")
    with pytest.raises(platforms.PlatformError, match="SONAME"):
        platforms.stage_kernel_runtime(runtime, downloads, cache)
    package.write_bytes(b"corrupted package")
    with pytest.raises(platforms.PlatformError, match="SHA256 mismatch"):
        platforms.stage_kernel_runtime(runtime, downloads, cache)
    for index, entries in enumerate(
        (
            [("control.tar.gz", b"no data", tarfile.REGTYPE)],
            [
                (
                    "data.tar.gz",
                    archive_bytes([("../escape", b"bad", tarfile.REGTYPE)]),
                    tarfile.REGTYPE,
                )
            ],
        )
    ):
        package.write_bytes(archive_bytes(entries))
        runtime["sha256"] = hashlib.sha256(package.read_bytes()).hexdigest()
        with pytest.raises(platforms.PlatformError):
            platforms.stage_kernel_runtime(
                runtime, downloads, tmp_path / f"bad-{index}"
            )
    assert not (tmp_path / "escape").exists()


def test_compiler_preflight_exercises_cc1_headers_and_assembler_with_scoped_env(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    compiler = str(tmp_path / "aarch64-linux-")
    Path(compiler + "gcc").touch()
    runtime = tmp_path / "private runtime"
    runtime.mkdir()
    monkeypatch.setenv("LD_LIBRARY_PATH", "/ambient/runtime")
    commands = []

    def version(command: list[str], **kwargs: object) -> str:
        commands.append(command)
        assert kwargs == {"text": True, "timeout": 30}
        return "4.9.4\n"

    def compile_object(command: list[str], **kwargs: object) -> None:
        commands.append(command)
        assert kwargs == {"timeout": 30}
        assert "-c" in command and "-ffreestanding" in command
        source = Path(command[command.index("-c") + 1])
        assert "#include <stddef.h>" in source.read_text()
        output = Path(command[command.index("-o") + 1])
        header = bytearray(elf_header(2, 183))
        header[16:18] = (1).to_bytes(2, "little")
        output.write_bytes(header)

    monkeypatch.setattr(platforms.subprocess, "check_output", version)
    monkeypatch.setattr(platforms, "run", compile_object)
    platforms.compiler_preflight(compiler, runtime, tmp_path / "cache")
    assert len(commands) == 2
    for command in commands:
        assert command[:2] == ["env", "LD_LIBRARY_PATH=" + str(runtime)]
    assert os.environ["LD_LIBRARY_PATH"] == "/ambient/runtime"
    assert not list((tmp_path / "cache/toolchain/preflight").iterdir())

    def broken_cc1(command: list[str], **kwargs: object) -> None:
        raise subprocess.CalledProcessError(1, command)

    monkeypatch.setattr(platforms, "run", broken_cc1)
    with pytest.raises(subprocess.CalledProcessError):
        platforms.compiler_preflight(compiler, runtime, tmp_path / "cache")
    assert not list((tmp_path / "cache/toolchain/preflight").iterdir())


def test_every_kernel_make_phase_has_private_runtime_environment(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(platforms, "ROOT", tmp_path)
    monkeypatch.setenv("LD_LIBRARY_PATH", "/ambient/runtime")
    kernel = manifest["kernels"][0]
    version = kernel["version"]
    runtime = tmp_path / "private runtime"
    runtime.mkdir()
    commands = []
    monkeypatch.setattr(platforms, "download", lambda *args: tmp_path / "archive")

    def stage(source: Path, root: Path) -> None:
        (root / f"linux-{version}").mkdir(parents=True)

    def make(command: list[str], *, cwd: Path, **kwargs: object) -> None:
        commands.append(command)
        if command[-1] == "allnoconfig":
            (cwd / ".config").write_text("")
        if command[-1] == "Image":
            image = cwd / "arch/arm64/boot/Image"
            image.parent.mkdir(parents=True)
            image.write_bytes(b"mock kernel image")

    def release(command: list[str], **kwargs: object) -> str:
        commands.append(command)
        return version + "\n"

    monkeypatch.setattr(platforms, "extract_tar", stage)
    monkeypatch.setattr(platforms, "run", make)
    monkeypatch.setattr(platforms.subprocess, "check_output", release)
    platforms.build_kernel(
        kernel,
        "compiler-",
        tmp_path / "downloads",
        tmp_path / "cache",
        "recipe",
        runtime,
    )
    assert [command[-1] for command in commands] == [
        "allnoconfig",
        "olddefconfig",
        "kernelrelease",
        "Image",
    ]
    for command in commands:
        assert command[:3] == ["env", "LD_LIBRARY_PATH=" + str(runtime), "make"]
    assert os.environ["LD_LIBRARY_PATH"] == "/ambient/runtime"


def test_platform_execution_stops_at_failed_compiler_preflight(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(platforms, "ROOT", tmp_path)
    monkeypatch.setattr(platforms, "require_linux_host", lambda: None)
    monkeypatch.setattr(platforms.shutil, "which", lambda tool: tool)
    monkeypatch.setattr(platforms, "download", lambda *args: tmp_path / "archive")
    monkeypatch.setattr(platforms, "extract_tar", lambda *args: None)
    monkeypatch.setattr(platforms, "stage_kernel_runtime", lambda *args: tmp_path)

    def fail_preflight(*args: object) -> None:
        raise platforms.PlatformError("compiler preflight failed")

    def forbidden_build(*args: object) -> None:
        pytest.fail("Platform build or boot proceeded after failed compiler preflight")

    monkeypatch.setattr(platforms, "compiler_preflight", fail_preflight)
    monkeypatch.setattr(platforms, "build_busybox", forbidden_build)
    monkeypatch.setattr(platforms, "build_kernel", forbidden_build)
    monkeypatch.setattr(platforms, "boot_guest", forbidden_build)
    with pytest.raises(platforms.PlatformError, match="compiler preflight failed"):
        platforms.execute(manifest, "4.1.51")


def test_native_compiler_and_cache_identity_are_separate_from_arm(
    manifest: dict, monkeypatch: pytest.MonkeyPatch
) -> None:
    commands = []

    def output(command: list[str]) -> bytes:
        commands.append(command)
        return b"compiler identity"

    monkeypatch.setattr(platforms.subprocess, "check_output", output)
    assert platforms.compiler_identity.__wrapped__("native")
    assert commands == [["dpkg-query", "-W", "gcc", "libc6-dev"], ["gcc", "--version"]]
    monkeypatch.setattr(
        platforms, "compiler_identity", lambda target="arm": b"same compiler"
    )
    item = manifest["busyboxes"][0]
    native = platforms.build_key("busybox", item, target="native")
    assert native != platforms.build_key("busybox", item, target="arm")
    monkeypatch.setattr(
        platforms, "compiler_identity", lambda target="arm": b"changed compiler"
    )
    assert platforms.build_key("busybox", item, target="native") != native


def test_generic_header_staging_preserves_vendor_source_and_invalidates_only_busybox(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixtures = tmp_path / "fixtures"
    fixtures.mkdir()
    for name in ("busybox.config", "kernel.config", "busybox-support/rtconfig.h"):
        target = fixtures / name
        target.parent.mkdir(exist_ok=True)
        target.write_bytes((platforms.FIXTURES / name).read_bytes())
    monkeypatch.setattr(platforms, "FIXTURES", fixtures)
    monkeypatch.setattr(
        platforms, "compiler_identity", lambda target="arm": b"fixed compiler"
    )
    source = tmp_path / "vendor source"
    source.mkdir()
    vendor = source / "rm.c"
    vendor.write_text("#include <rtconfig.h>\n/* retained vendor source */\n")
    original = vendor.read_bytes()
    platforms.stage_busybox_support(source)
    header = source / ".cfmgr-generic-headers/rtconfig.h"
    assert header.read_bytes() == (fixtures / "busybox-support/rtconfig.h").read_bytes()
    assert not re.search(
        rb"^\s*#\s*define\s+RTCONFIG_", header.read_bytes(), re.MULTILINE
    )
    assert vendor.read_bytes() == original
    with pytest.raises(FileExistsError):
        platforms.stage_busybox_support(source)
    item = manifest["busyboxes"][0]
    keys = {
        target: platforms.build_key("busybox", item, target=target)
        for target in ("arm", "native")
    }
    kernel = manifest["kernels"][0]
    kernel_key = platforms.build_key("kernel", kernel, manifest["toolchain"])
    with (fixtures / "busybox-support/rtconfig.h").open("ab") as output:
        output.write(b"/* changed generic build support */\n")
    for target, key in keys.items():
        assert platforms.build_key("busybox", item, target=target) != key
    assert platforms.build_key("kernel", kernel, manifest["toolchain"]) == kernel_key


def test_native_cache_requires_native_elf_and_target_receipt(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(platforms, "build_key", lambda *args, **kwargs: "native-key")
    item = manifest["busyboxes"][0]
    output = tmp_path / "busybox/native-key"
    output.mkdir(parents=True)
    binary = output / "busybox"
    receipt = output / "verified.json"
    binary.write_bytes(elf_header(1, 40))

    def write_receipt(target: str) -> None:
        receipt.write_text(
            json.dumps(
                {
                    "commit": item["commit"],
                    "recipe": "native-key",
                    "target": target,
                    "sha256": hashlib.sha256(binary.read_bytes()).hexdigest(),
                }
            )
        )

    write_receipt("native")
    with pytest.raises(platforms.PlatformError, match="ABI mismatch"):
        platforms.build_busybox(item, tmp_path, target="native")
    binary.write_bytes(elf_header(2, 62))
    write_receipt("arm")
    with pytest.raises(platforms.PlatformError, match="receipt mismatch"):
        platforms.build_busybox(item, tmp_path, target="native")
    write_receipt("native")
    assert platforms.build_busybox(item, tmp_path, target="native") == binary


def test_native_mode_stages_only_verified_binary_and_refuses_symlinks(
    manifest: dict, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(platforms, "ROOT", tmp_path)
    monkeypatch.setattr(platforms, "require_linux_host", lambda: None)

    def forbidden_kernel_prerequisite(*args: object) -> None:
        pytest.fail("Native BusyBox attempted to acquire kernel compiler prerequisites")

    monkeypatch.setattr(
        platforms, "stage_kernel_runtime", forbidden_kernel_prerequisite
    )
    monkeypatch.setattr(platforms, "compiler_preflight", forbidden_kernel_prerequisite)
    checked = []
    monkeypatch.setattr(
        platforms.shutil, "which", lambda tool: checked.append(tool) or tool
    )
    binary = tmp_path / "cached-busybox"
    binary.write_bytes(elf_header(2, 62))

    def build(item: dict, cache: Path, *, target: str) -> Path:
        assert item["id"] == "baseline" and target == "native"
        assert cache == tmp_path / ".tmp/platform-cache"
        return binary

    monkeypatch.setattr(platforms, "build_busybox", build)
    platforms.execute_native_busybox(manifest)
    assert checked == ["make", "gcc", "git", "dpkg-query"]
    destination = tmp_path / ".tmp/native-busybox/bin/busybox"
    assert destination.read_bytes() == binary.read_bytes()
    assert destination.stat().st_mode & 0o777 == 0o755
    destination.unlink()
    untouched = tmp_path / "untouched"
    untouched.write_text("preserve")
    destination.symlink_to(untouched)
    with pytest.raises(platforms.PlatformError, match="unsafe native"):
        platforms.execute_native_busybox(manifest)
    assert untouched.read_text() == "preserve"


def test_native_cli_routing_rejects_guest_combinations_and_non_linux_host(
    manifest: dict, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture
) -> None:
    monkeypatch.setattr(platforms, "load_manifest", lambda: manifest)
    called = []
    monkeypatch.setattr(
        platforms, "execute_native_busybox", lambda data: called.append(data)
    )
    monkeypatch.setattr(platforms.sys, "argv", ["runner", "--native-busybox"])
    assert platforms.main() == 0 and called == [manifest]
    called.clear()
    for extra in (["--run"], ["--kernel", "4.1.51"]):
        monkeypatch.setattr(
            platforms.sys, "argv", ["runner", "--native-busybox", *extra]
        )
        assert platforms.main() == 1 and not called
    monkeypatch.setattr(platforms.sys, "platform", "darwin")
    monkeypatch.setattr(
        platforms.sys, "argv", ["runner", "--native-busybox", "--cache-keys"]
    )
    assert platforms.main() == 1
    assert "Linux x86_64" in capsys.readouterr().err


def test_busybox_fragment_rejects_unknown_enabled_and_disabled_symbols(
    tmp_path: Path,
) -> None:
    (tmp_path / "Config.in").write_text("config STATIC\n\tbool\n")
    shell = tmp_path / "shell"
    shell.mkdir()
    (shell / "Config.in").write_text(
        "config FEATURE_SH_IS_ASH\n\tbool\nconfig ASH_BUILTIN_TEST\n\tbool\n"
    )
    values = {
        "CONFIG_STATIC": "y",
        "CONFIG_FEATURE_SH_IS_ASH": "y",
        "CONFIG_ASH_BUILTIN_TEST": "n",
    }
    platforms.check_busybox_symbols(tmp_path, values)
    for value in ("y", "n"):
        with pytest.raises(platforms.PlatformError, match="CONFIG_SH_IS_ASH"):
            platforms.check_busybox_symbols(
                tmp_path, values | {"CONFIG_SH_IS_ASH": value}
            )


def test_kernel_configuration_preserves_version_specific_required_symbols() -> None:
    for version in sorted(platforms.VERSIONS):
        values = platforms.kernel_configuration(version)
        assert values["CONFIG_SMP"] == "y"
        assert values["CONFIG_STACKPROTECTOR"] == "n"
        if version.startswith("4.1."):
            assert values["CONFIG_CC_STACKPROTECTOR_NONE"] == "y"
            assert "CONFIG_ARM_PSCI_FW" not in values
            assert "CONFIG_POSIX_TIMERS" not in values
        else:
            assert "CONFIG_CC_STACKPROTECTOR_NONE" not in values
            assert values["CONFIG_ARM_PSCI_FW"] == "y"
            assert values["CONFIG_POSIX_TIMERS"] == "y"


def test_busybox_fragment_clears_allnoconfig_shell_none_choice(tmp_path: Path) -> None:
    config = tmp_path / ".config"
    config.write_text(
        "# CONFIG_ASH is not set\n"
        "# CONFIG_FEATURE_SH_IS_ASH is not set\n"
        "CONFIG_FEATURE_SH_IS_NONE=y\n"
    )
    values = platforms.configuration(platforms.FIXTURES / "busybox.config")
    platforms.apply_configuration(config, values)
    lines = config.read_text().splitlines()
    assert "CONFIG_ASH=y" in lines
    assert "CONFIG_FEATURE_SH_IS_ASH=y" in lines
    assert "# CONFIG_FEATURE_SH_IS_NONE is not set" in lines
    assert "CONFIG_FEATURE_SH_IS_NONE=y" not in lines
