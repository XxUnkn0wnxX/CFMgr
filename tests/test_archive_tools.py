"""Smoke-test the pinned native BusyBox archive and date applets in CI."""

from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import time
from pathlib import Path

import pytest
from runtime_awk import awk_program


@pytest.fixture(scope="module")
def vendor_busybox() -> Path:
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") != "1":
        pytest.skip("Pinned native BusyBox capability proof runs in required CI mode")
    shell = shlex.split(os.environ.get("CFMGR_TEST_SHELL", ""))
    assert shell[:2] == ["busybox", "ash"], (
        "Required BusyBox shell selection is missing"
    )
    executable = shutil.which(shell[0])
    expected = Path(__file__).resolve().parents[1] / ".tmp/native-busybox/bin/busybox"
    assert executable is not None, "Required native BusyBox executable is missing"
    assert Path(executable).resolve() == expected.resolve(), (
        "Required CI capability proof must use the staged vendor BusyBox"
    )
    assert os.access(executable, os.X_OK), "Native BusyBox is not executable"
    return Path(executable)


def test_native_tar_gzip_and_date_capabilities(
    vendor_busybox: Path, tmp_path: Path
) -> None:
    root = tmp_path / "source"
    root.mkdir()
    members = {
        "manifest": b"archive fixture\n",
        "inventory": b"",
        "p00000001": bytes(range(256)) * 2 + b"tail",
    }
    for name, data in members.items():
        (root / name).write_bytes(data)
    file_list = tmp_path / "files.list"
    file_list.write_text("".join(f"{name}\n" for name in members))
    archive = tmp_path / "files.tar"
    env = {**os.environ, "LC_ALL": "C", "TZ": "UTC0"}

    subprocess.run(
        [
            str(vendor_busybox),
            "tar",
            "-cf",
            str(archive),
            "-C",
            str(root),
            "-T",
            str(file_list),
        ],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    )
    listing = (
        subprocess.run(
            [str(vendor_busybox), "tar", "-tf", str(archive)],
            check=True,
            env=env,
            capture_output=True,
            timeout=5,
        )
        .stdout.decode()
        .splitlines()
    )
    assert listing == list(members)
    contents = subprocess.run(
        [str(vendor_busybox), "tar", "-xOf", str(archive)],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    ).stdout
    assert contents == b"".join(members.values())

    # Join source-derived parser grammar to the actual native writer. Host tar
    # variants do not substitute for its old-GNU headers and two-block trailer.
    raw = archive.read_bytes()
    parser = awk_program("backup_tar")
    offset = 0
    for name, data in members.items():
        body = offset + 512
        following = body + ((len(data) + 511) // 512) * 512
        receipt = subprocess.run(
            [str(vendor_busybox), "awk", parser],
            input=raw[offset:body].hex().encode(),
            env={
                **env,
                "CFMGR_TAR_OFFSET": str(offset),
                "CFMGR_TAR_BYTES": str(len(raw)),
            },
            check=True,
            capture_output=True,
            timeout=5,
        )
        expected = (
            f"CFMGR-TAR-HEADER 1 file {name} {len(data)} {body} {following} END\n"
        ).encode()
        assert (receipt.stdout, receipt.stderr) == (expected, b"")
        offset = following
    assert raw[offset:] == bytes(1024)

    compressed = subprocess.run(
        [str(vendor_busybox), "gzip", "-c", str(archive)],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    ).stdout
    packed = tmp_path / "files.tar.gz"
    packed.write_bytes(compressed)
    subprocess.run(
        [str(vendor_busybox), "gunzip", "-t", str(packed)],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    )
    expanded = subprocess.run(
        [str(vendor_busybox), "gunzip", "-c", str(packed)],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    ).stdout
    assert expanded == archive.read_bytes()

    # Archive verification seeks regular files and reads bounded raw headers.
    header = subprocess.run(
        [
            str(vendor_busybox),
            "dd",
            f"if={archive}",
            "iflag=skip_bytes",
            "skip=13",
            "bs=512",
            "count=1",
        ],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    ).stdout
    assert len(header) == 512
    assert header == archive.read_bytes()[13:525]
    encoded = subprocess.run(
        [
            str(vendor_busybox),
            "hexdump",
            "-v",
            "-n",
            "512",
            "-s",
            "13",
            "-e",
            '1/1 "%02x"',
            str(archive),
        ],
        check=True,
        env=env,
        capture_output=True,
        timeout=5,
    ).stdout
    assert encoded == header.hex().encode()

    before = int(time.time())
    formatted = (
        subprocess.run(
            [str(vendor_busybox), "date", "+%s|%Y-%m-%d|%H:%M:%S|%z"],
            check=True,
            env=env,
            capture_output=True,
            timeout=5,
        )
        .stdout.decode()
        .strip()
    )
    after = int(time.time())
    epoch, day, clock, zone = formatted.split("|")
    assert before <= int(epoch) <= after
    assert re.fullmatch(r"\d{4}-\d{2}-\d{2}", day)
    assert re.fullmatch(r"\d{2}:\d{2}:\d{2}", clock)
    assert zone == "+0000"
