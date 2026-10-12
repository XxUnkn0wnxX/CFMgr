"""Passive, code-defined fresh configuration defaults."""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "modules/lib/config.sh"
UUID = "01234567-89ab-cdef-0123-456789abcdef"
DEFAULTS = (
    "https://github.com/example/CFMgr",
    "develop",
    UUID,
    "ext4",
    "/",
    "entware",
)


@pytest.fixture(scope="module")
def shell() -> list[str]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    command = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert command and shutil.which(command[0]), "Selected POSIX test shell is missing"
    return command


@pytest.fixture(scope="module")
def jq() -> str:
    executable = shutil.which("jq")
    assert executable, "Actual jq is required for config default tests"
    resolved = str(Path(executable).resolve())
    assert Path(resolved).is_absolute() and os.access(resolved, os.X_OK)
    return resolved


def invoke(
    shell: list[str],
    jq: str,
    arguments: tuple[str, ...] = DEFAULTS,
    *,
    executable: str | None = None,
    cwd: Path | None = None,
) -> subprocess.CompletedProcess[bytes]:
    command = '. "$1"; cfmgr_config_defaults "$2" "$3" "$4" "$5" "$6" "$7" "$8"'
    return subprocess.run(
        [
            *shell,
            "-c",
            command,
            "config-test",
            str(LIBRARY),
            executable or jq,
            *arguments,
        ],
        cwd=cwd,
        env={**os.environ, "LC_ALL": "POSIX", "LANGUAGE": "foreign-language"},
        check=False,
        capture_output=True,
        timeout=5,
    )


def expected_config(
    repository: str, branch: str, uuid: str, filesystem: str, fsroot: str, relative: str
) -> dict[str, object]:
    return {
        "schema": 1,
        "generation": 1,
        "manager": {
            "check_updates": True,
            "auto_update": False,
            "developer": False,
            "source": {"repository": repository, "branch": branch, "commit": ""},
        },
        "storage": {
            "entware": {
                "uuid": uuid,
                "filesystem": filesystem,
                "root": fsroot,
                "relative": relative,
            }
        },
        "ddns": {
            "configured": False,
            "enabled": False,
            "credentials": None,
            "zone_id": "",
            "records": [],
            "primary_hostname": "",
            "ttl": None,
            "proxied": None,
            "forced_refresh_days": 14,
            "address_family": "auto",
        },
        "ip_sync": {
            "configured": False,
            "enabled": False,
            "credentials": None,
            "account_id": "",
            "targets": [],
            "address_family": "auto",
        },
        "cloudflared": {
            "configured": False,
            "enabled": False,
            "installed": False,
            "maintenance_enabled": False,
            "method": None,
            "token": None,
            "account_tag": "",
            "tunnel_id": "",
            "tunnel_secret": None,
            "credential_refs": {
                "runtime": None,
                "management": None,
                "certificate": None,
            },
            "binary_auto_update": None,
        },
        "network": {"address_family": "auto", "selected_wan": None},
        "logging": {
            feature: {
                "configured": False,
                "enabled": False,
                "opt_out": False,
                "policy": None,
            }
            for feature in ("ddns", "ip_sync", "cloudflared")
        },
        "backup": {"destination": None, "retention": None, "last_backup": None},
        "credentials": {},
        "ownership": {},
        "history": {"ddns": None, "ip_sync": None, "cloudflared": None},
    }


def test_source_is_inert_and_preserves_caller_state(
    shell: list[str], tmp_path: Path
) -> None:
    result = subprocess.run(
        [
            *shell,
            "-c",
            (
                'before_pwd=$PWD; before_ifs=$IFS; . "$1"; '
                '[ "$PWD" = "$before_pwd" ] && [ "$IFS" = "$before_ifs" ] && '
                '[ "$LC_ALL" = POSIX ] && [ "$LANGUAGE" = foreign-language ]'
            ),
            "config-test",
            str(LIBRARY),
        ],
        cwd=tmp_path,
        env={**os.environ, "LC_ALL": "POSIX", "LANGUAGE": "foreign-language"},
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_defaults_are_complete_passive_json_with_typed_empty_values(
    shell: list[str], jq: str
) -> None:
    result = invoke(shell, jq)
    assert result.returncode == 0, result.stderr
    assert result.stderr == b""
    assert result.stdout.count(b"\n") == 1
    assert json.loads(result.stdout) == expected_config(*DEFAULTS)


def test_argument_values_remain_literal_data(
    shell: list[str], jq: str, tmp_path: Path
) -> None:
    branch = 'release$(>"sentinel")'
    result = invoke(
        shell,
        jq,
        (DEFAULTS[0], branch, *DEFAULTS[2:]),
        cwd=tmp_path,
    )
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["manager"]["source"]["branch"] == branch
    assert not (tmp_path / "sentinel").exists()


def test_entware_can_occupy_the_verified_mount_root(shell: list[str], jq: str) -> None:
    args = (*DEFAULTS[:-1], ".")
    result = invoke(shell, jq, args)
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout)["storage"]["entware"]["relative"] == "."


def test_supervised_constructor_replaces_its_child_process(
    shell: list[str], jq: str
) -> None:
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; shift; cfmgr_config_defaults_exec "$@"; printf unexpected-return',
            "config-exec-test",
            str(LIBRARY),
            jq,
            *DEFAULTS,
        ],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert json.loads(result.stdout) == expected_config(*DEFAULTS)


def test_invalid_arguments_are_rejected_without_stdout(
    shell: list[str], jq: str
) -> None:
    invalid = (
        ("repository", "http://github.com/example/CFMgr"),
        ("repository", "https://github.com/example/CFMgr/extra"),
        ("repository", "https://github.com/example/CFMgr?branch=main"),
        ("branch", ""),
        ("branch", "has whitespace"),
        ("branch", "has\nnewline"),
        ("uuid", "01234567-89ab-cdef-0123-456789abcdeg"),
        ("uuid", "01234567-89ab-cdef-0123-456789abcde-"),
        ("filesystem", "xfs"),
        ("fsroot", "relative"),
        ("fsroot", "/mnt//volume"),
        ("fsroot", "/mnt/../volume"),
        ("fsroot", "/mnt/"),
        ("relative", "/opt/entware"),
        ("relative", "../entware"),
        ("relative", "packages/../../etc"),
        ("relative", "packages//entware"),
    )
    positions = {
        "repository": 0,
        "branch": 1,
        "uuid": 2,
        "filesystem": 3,
        "fsroot": 4,
        "relative": 5,
    }
    for name, value in invalid:
        args = list(DEFAULTS)
        args[positions[name]] = value
        result = invoke(shell, jq, tuple(args))
        assert result.returncode == 2, name
        assert result.stdout == b"", name
        assert result.stderr == b"", name


def test_jq_must_be_absolute_executable_and_failure_propagates(
    shell: list[str], jq: str, tmp_path: Path
) -> None:
    relative = invoke(shell, jq, executable="jq")
    missing = invoke(shell, jq, executable=str(tmp_path / "missing-jq"))
    assert (relative.returncode, relative.stdout, relative.stderr) == (2, b"", b"")
    assert (missing.returncode, missing.stdout, missing.stderr) == (2, b"", b"")

    failed_jq = tmp_path / "failing jq"
    failed_jq.write_text("#!/bin/sh\nprintf partial\nexit 7\n", encoding="utf-8")
    failed_jq.chmod(0o700)
    failed = invoke(shell, jq, executable=str(failed_jq))
    assert failed.returncode == 7
    assert failed.stdout == b""
