"""Pinned Cloud logger argv admission; production proc proof is Linux-only."""

from __future__ import annotations

import os
import shutil
import subprocess

import pytest
from runtime_awk import awk_program

UUID = "12345678-1234-1234-1234-123456789abc"
LOG = "/opt/var/log/cloudflared.log"


def argv_result(arguments):
    data = b"\0".join(item.encode() for item in arguments) + b"\0"
    return subprocess.run(
        [
            shutil.which("awk"),
            "-v",
            "cfmgr_writer_mode=argv",
            awk_program("backup_cloud_writer"),
        ],
        input="".join(f"{byte:02x}\n" for byte in data).encode(),
        capture_output=True,
        check=False,
        timeout=3,
        env={**os.environ, "LC_ALL": "C"},
    )


@pytest.mark.parametrize(
    "arguments",
    [
        ["--logfile", LOG, "tunnel", "run"],
        ["tunnel", f"--logfile={LOG}", "run", UUID],
        [
            "--no-autoupdate",
            "tunnel",
            "--logfile",
            LOG,
            "--retries",
            "3",
            "run",
            "--token-file",
            "/private/token",
        ],
        [
            "--protocol",
            "http2",
            "tunnel",
            "--logfile",
            LOG,
            "run",
            "--credentials-file",
            "/private/credentials",
        ],
    ],
)
def test_supported_explicit_file_logger_scopes(arguments):
    result = argv_result(["/opt/bin/cloudflared", *arguments])
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"ARGV supported END\n",
        b"",
    )


@pytest.mark.parametrize(
    "arguments",
    [
        ["tunnel", "run", "--logfile", LOG],
        ["--token", "secret", "tunnel", "--logfile", LOG, "run"],
        ["--logfile", LOG, "tunnel", "--token-file", "/token", "run"],
        ["--logfile", LOG, "tunnel", "run", "--no-autoupdate"],
        ["--logfile", LOG, "tunnel", "run", "--config", "/config"],
        ["--logfile", LOG, "tunnel", "run", "alias"],
        ["--logfile", LOG, "tunnel", "run", UUID, "--protocol", "http2"],
        ["--logfile", LOG, "tunnel", "--logfile", LOG, "run"],
        ["--logfile", "", "tunnel", "run"],
        ["--logfile", LOG, "tunnel", "--unknown", "value", "run"],
        ["--logfile", LOG, "tunnel", "run", "--", UUID],
        ["--logfile", "/foreign/log", "tunnel", "run"],
    ],
)
def test_ambiguous_invocation_is_private_unknown(arguments):
    result = argv_result(["/opt/bin/cloudflared", *arguments])
    assert result.returncode == 1
    assert result.stdout == result.stderr == b""
