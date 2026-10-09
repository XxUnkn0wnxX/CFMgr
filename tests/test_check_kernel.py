"""Cheap runner safety checks; these never start a privileged namespace."""

from __future__ import annotations

import hashlib
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import pytest

from tools import check_kernel

pytestmark = [pytest.mark.unit, pytest.mark.matrix("V43", evidence="harness")]


@pytest.fixture(scope="module")
def native_outer_witness(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """Compile the real outer shim once; its target only prints NUL-framed argv."""
    compiler = shutil.which("cc")
    if compiler is None:
        pytest.skip("compiled native witness regression requires a host C compiler")
    work = tmp_path_factory.mktemp("native-outer-witness")
    target = work / "inert-busybox"
    target.write_text('#!/bin/sh\nprintf "%s\\000" "$@"\n', encoding="ascii")
    target.chmod(0o700)
    source = check_kernel.native_witness_source(work)
    executable = work / "native-chroot"
    check_kernel.command(
        [
            compiler,
            "-O2",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-DOUTSIDE",
            f"-DHOST_BUSYBOX={json.dumps(str(target))}",
            str(source),
            "-o",
            str(executable),
        ]
    )
    return executable


def run_native_outer_witness(
    executable: Path, argv: list[str], held: Path | None, extra_fd: int = 0
) -> subprocess.CompletedProcess[bytes]:
    # A fresh unprivileged launcher supplies real descriptors, including FD63
    # beyond POSIX shell redirection syntax. No chroot or script evaluation.
    launcher = """import os
import sys

held, extra, executable, *argv = sys.argv[1:]
if held:
    fd = os.open(held, os.O_RDONLY)
    os.dup2(fd, 6, inheritable=True)
    if fd != 6:
        os.close(fd)
if int(extra):
    fd = os.open(os.devnull, os.O_RDONLY)
    os.dup2(fd, int(extra), inheritable=True)
    os.set_inheritable(int(extra), True)
    if fd != int(extra):
        os.close(fd)
os.execv(executable, [executable, *argv])
"""
    return subprocess.run(
        [
            sys.executable,
            "-c",
            launcher,
            str(held) if held else "",
            str(extra_fd),
            str(executable),
            *argv,
        ],
        capture_output=True,
        timeout=5,
        check=False,
    )


def test_compiled_outer_witness_forwards_both_finite_native_call_shapes(
    native_outer_witness: Path, tmp_path: Path
) -> None:
    root = tmp_path / "native root"
    root.mkdir()
    script = 'exec 6<&-\nprintf "%s\\n" "$1"\n# literal $() and trailing newline\n'
    old = [str(root), "/bin/sh", "-c", script]
    vectors = [
        old,
        [*old, "cfmgr-dependencies", "repair", "shared", "native"],
        [*old, "cfmgr-dependencies", "reinstall", "tunnel", "entware"],
    ]
    for argv in vectors:
        result = run_native_outer_witness(native_outer_witness, argv, root)
        assert result.returncode == 0, (argv, result.stderr)
        assert result.stderr == b""
        assert result.stdout == b"".join(arg.encode() + b"\x00" for arg in ["chroot", *argv])


def test_compiled_outer_witness_rejects_extra_arguments_root_mismatch_and_leaked_fds(
    native_outer_witness: Path, tmp_path: Path
) -> None:
    root = tmp_path / "root"
    root.mkdir()
    other = tmp_path / "other"
    other.mkdir()
    regular = tmp_path / "regular"
    regular.write_text("not a directory", encoding="ascii")
    old = [str(root), "/bin/sh", "-c", "exec 6<&-\n"]
    cases = [
        ([], root, 0, 121),
        (old[:-1], root, 0, 121),
        ([*old, "extra"], root, 0, 121),
        ([*old, "cfmgr-dependencies", "repair", "shared"], root, 0, 121),
        ([*old, "cfmgr-dependencies", "repair", "shared", "native", "extra"], root, 0, 121),
        (old, None, 0, 121),
        (old, other, 0, 121),
        ([str(regular), *old[1:]], regular, 0, 121),
        (old, root, 3, 120),
        (old, root, 63, 120),
    ]
    for argv, held, extra_fd, status in cases:
        result = run_native_outer_witness(native_outer_witness, argv, held, extra_fd)
        assert result.returncode == status, (argv, held, extra_fd, result.stderr)
        assert result.stdout == result.stderr == b""


def test_help_never_checks_platform_or_privileges(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(check_kernel, "prove", Mock(side_effect=AssertionError("proof started")))
    with pytest.raises(SystemExit) as exited:
        check_kernel.main(["--help"])
    assert exited.value.code == 0


@pytest.mark.parametrize(
    "platform,uid,message", [("darwin", 0, "requires Linux"), ("linux", 1000, "explicit root")]
)
def test_unsupported_host_fails_before_tools_or_temp_storage(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    platform: str,
    uid: int,
    message: str,
) -> None:
    monkeypatch.setattr(check_kernel.sys, "platform", platform)
    monkeypatch.setattr(check_kernel.os, "geteuid", lambda: uid)
    native = Mock(side_effect=AssertionError("tool resolution started"))
    monkeypatch.setattr(check_kernel, "native", native)
    assert check_kernel.main(["--busybox", "/missing/busybox"]) == 1
    assert message in capsys.readouterr().err
    native.assert_not_called()


def test_namespace_timeout_kills_and_waits_exact_launched_parent(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    child = SimpleNamespace(
        communicate=Mock(side_effect=subprocess.TimeoutExpired("unshare", 15)),
        kill=Mock(),
        wait=Mock(return_value=-9),
    )
    launch = Mock(return_value=child)
    monkeypatch.setattr(check_kernel.subprocess, "Popen", launch)
    with pytest.raises(subprocess.TimeoutExpired):
        check_kernel.namespace(["/trusted/unshare"])
    launch.assert_called_once()
    child.kill.assert_called_once_with()
    child.wait.assert_called_once_with(timeout=5)


def test_cleanup_rejects_changed_root_symlink(tmp_path: Path) -> None:
    retained = tmp_path / "retained"
    retained.mkdir()
    (retained / "sentinel").write_text("retained")
    work = tmp_path / "cfmgr-kernel-replaced"
    work.symlink_to(retained, target_is_directory=True)
    with pytest.raises(ValueError, match="refusing cleanup"):
        check_kernel.owned_cleanup(work, tmp_path, (0, 0))
    assert (retained / "sentinel").read_text() == "retained"


def test_contained_manifest_hashes_exact_fixed_fixture_rows(tmp_path: Path) -> None:
    library = tmp_path / "lib"
    library.mkdir()
    names = ("ld-2.27.so", "libc-2.27.so", "libpthread-2.27.so", "librt-2.27.so")
    entries = []
    for name in names:
        data = name.encode("ascii") + b"\x00\n"
        (library / name).write_bytes(data)
        entries.append((f"lib/{name}", data))
    executable = tmp_path / "controlled-probe"
    data = b"controlled binary\x00\n"
    executable.write_bytes(data)
    entries.extend((f"libexec/{name}", data) for name in ("timeout-coreutils", "gzip-gnu"))
    expected = "".join(
        f"{relative}\t{len(data)}\t{hashlib.sha256(data).hexdigest()}\n"
        for relative, data in entries
    ).encode("ascii")
    assert check_kernel.contained_manifest(tmp_path, executable) == expected
    assert len(expected) <= 4096


@pytest.mark.parametrize("size", [0, 4194305])
def test_contained_manifest_rejects_member_before_reading(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, size: int
) -> None:
    (tmp_path / "lib").mkdir()
    with (tmp_path / "lib/ld-2.27.so").open("wb") as member:
        member.truncate(size)
    read = Mock(side_effect=AssertionError("unbounded fixture read"))
    monkeypatch.setattr(Path, "read_bytes", read)
    with pytest.raises(ValueError, match="member exceeds closure bounds"):
        check_kernel.contained_manifest(tmp_path, tmp_path / "controlled-probe")
    read.assert_not_called()


def dynamic_fixture(elf_class: int = 2, endian: str = "<") -> tuple[bytes, int, int]:
    """Small inert ELF framing only; no executable payload or host ABI claim."""
    data = bytearray(256)
    data[:7] = b"\x7fELF" + bytes((elf_class, 1 if endian == "<" else 2, 1))
    offset = 192
    original = b"/lib64/ld-linux-x86-64.so.2\x00"
    data[offset : offset + len(original)] = original
    if elf_class == 2:
        struct.pack_into(endian + "Q", data, 32, 64)
        struct.pack_into(endian + "HH", data, 54, 56, 1)
        struct.pack_into(endian + "I", data, 64, 3)
        struct.pack_into(endian + "Q", data, 72, offset)
        struct.pack_into(endian + "Q", data, 96, len(original))
    else:
        struct.pack_into(endian + "I", data, 28, 52)
        struct.pack_into(endian + "HH", data, 42, 32, 1)
        struct.pack_into(endian + "I", data, 52, 3)
        struct.pack_into(endian + "I", data, 56, offset)
        struct.pack_into(endian + "I", data, 68, len(original))
    return bytes(data), offset, len(original)


@pytest.mark.parametrize("elf_class,endian", [(1, "<"), (1, ">"), (2, "<"), (2, ">")])
def test_fixture_interpreter_changes_only_original_bounded_region(
    elf_class: int, endian: str
) -> None:
    original, offset, size = dynamic_fixture(elf_class, endian)
    changed = check_kernel.fixture_interpreter(original, "/lib/cfmgr-ld.so")
    assert len(changed) == len(original)
    assert changed[:offset] == original[:offset]
    assert changed[offset + size :] == original[offset + size :]
    assert changed[offset : offset + size] == b"/lib/cfmgr-ld.so\x00".ljust(size, b"\x00")


@pytest.mark.parametrize(
    "fault",
    ["header", "table", "missing", "overlap", "past-end", "nul", "relative", "long"],
)
def test_fixture_interpreter_rejects_unsupported_layout_without_mutating(fault: str) -> None:
    original, offset, size = dynamic_fixture()
    malformed = bytearray(original)
    replacement = "/lib/cfmgr-ld.so"
    if fault == "header":
        malformed[4] = 0
    elif fault == "table":
        struct.pack_into("<Q", malformed, 32, 240)
    elif fault == "missing":
        struct.pack_into("<I", malformed, 64, 1)
    elif fault == "overlap":
        struct.pack_into("<Q", malformed, 72, 80)
    elif fault == "past-end":
        struct.pack_into("<Q", malformed, 96, 4096)
    elif fault == "nul":
        malformed[offset + size - 1] = 65
    elif fault == "relative":
        replacement = "lib/cfmgr-ld.so"
    elif fault == "long":
        replacement = "/lib/" + "x" * 64
    before = bytes(malformed)
    with pytest.raises(ValueError):
        check_kernel.fixture_interpreter(before, replacement)
    assert bytes(malformed) == before


def test_native_fixture_verifies_patched_loader_and_stages_exact_dependency_bytes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    work = tmp_path / "work"
    work.mkdir()
    busybox = tmp_path / "busybox"
    original, _, _ = dynamic_fixture()
    busybox.write_bytes(original)
    busybox.chmod(0o755)
    loader = tmp_path / "host-loader"
    loader.write_bytes(b"trusted loader fixture")
    library = tmp_path / "host-library"
    library.write_bytes(b"trusted libc fixture")
    calls = []

    def host_command(argv: list[str], **_: object) -> str:
        calls.append(argv)
        if argv[:2] == ["readelf", "-l"]:
            interpreter = str(loader) if argv[2] == str(busybox) else "/lib/cfmgr-ld.so"
            return f"[Requesting program interpreter: {interpreter}]\n"
        if argv[:2] == ["readelf", "-d"]:
            return "(NEEDED) Shared library: [libc.so.6]\n"
        if argv[0] == "ldd":
            return "linux-vdso.so.1 (0x1234)\nlibc.so.6 => /lib/fixture/libc.so.6 (0x5678)\n"
        assert argv[0] == "gcc" and "-static" in argv
        return ""

    resolve = Path.resolve

    def fixture_resolve(path: Path, strict: bool = False) -> Path:
        if str(path) == "/lib/fixture/libc.so.6":
            return library
        return resolve(path, strict=strict)

    monkeypatch.setattr(check_kernel, "command", host_command)
    monkeypatch.setattr(check_kernel, "native", lambda name: name)
    monkeypatch.setattr(Path, "resolve", fixture_resolve)
    check_kernel.native_fixture(busybox, work, "gcc", "readelf")
    staged = work / "native-staging"
    assert (staged / "bin/native-busybox").read_bytes() == check_kernel.fixture_interpreter(
        original, "/lib/cfmgr-ld.so"
    )
    assert (staged / "bin/native-busybox").stat().st_mode & 0o777 == 0o755
    assert busybox.read_bytes() == original
    assert (staged / "lib/cfmgr-ld.so").read_bytes() == loader.read_bytes()
    assert (staged / "lib/fixture/libc.so.6").read_bytes() == library.read_bytes()
    assert (staged / "bin/sh").readlink() == Path("native-busybox")
    assert len([call for call in calls if call[0] == "gcc"]) == 2


@pytest.mark.parametrize("response", ["/lib/wrong.so", "/lib/cfmgr-ld.so\nsecond"])
def test_native_fixture_rejects_unverified_patch_before_dependency_tools(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, response: str
) -> None:
    busybox = tmp_path / "busybox"
    busybox.write_bytes(dynamic_fixture()[0])
    loader = tmp_path / "loader"
    loader.write_bytes(b"trusted loader")
    calls = []

    def host_command(argv: list[str], **_: object) -> str:
        calls.append(argv)
        assert argv[:2] == ["readelf", "-l"]
        interpreter = str(loader) if argv[2] == str(busybox) else response
        return f"[Requesting program interpreter: {interpreter}]\n"

    monkeypatch.setattr(check_kernel, "command", host_command)
    with pytest.raises(ValueError, match="readelf rejected"):
        check_kernel.native_fixture(busybox, tmp_path, "gcc", "readelf")
    assert len(calls) == 2


def test_opkg_fixture_builds_trusted_source_static_and_checks_loader_boundaries(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls = []

    def host_command(argv: list[str], **_: object) -> str:
        calls.append(argv)
        return ""

    monkeypatch.setattr(check_kernel, "command", host_command)
    check_kernel.opkg_fixture(tmp_path, "gcc", "readelf")
    assert calls == [
        [
            "gcc",
            "-O2",
            "-Wall",
            "-Wextra",
            "-Werror",
            "-static",
            str(check_kernel.FIXTURES / "opkg_probe.c"),
            "-o",
            str(tmp_path / "opkg-probe"),
        ],
        ["readelf", "-l", str(tmp_path / "opkg-probe")],
        ["readelf", "-d", str(tmp_path / "opkg-probe")],
    ]


@pytest.mark.parametrize(
    "headers,libraries",
    [("INTERP 0x200\n", ""), ("", "(NEEDED) Shared library: [libc.so.6]\n")],
)
def test_opkg_fixture_rejects_interpreter_or_dependency(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, headers: str, libraries: str
) -> None:
    def host_command(argv: list[str], **_: object) -> str:
        return headers if argv[:2] == ["readelf", "-l"] else libraries

    monkeypatch.setattr(check_kernel, "command", host_command)
    with pytest.raises(ValueError, match="fully static"):
        check_kernel.opkg_fixture(tmp_path, "gcc", "readelf")
