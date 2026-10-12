"""Local contracts for the explicit developer-only Merlin SSH probe launcher."""

from __future__ import annotations

import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

import pytest

from tools import router_probe


def write_config(path: Path, **updates: object) -> Path:
    values: dict[str, object] = {
        "mode": "KEY",
        "ssh_target": "router.example",
        "scratch_dir": "/mnt/USB drive/probe work",
        "ssh_port": 2222,
    }
    values.update(updates)
    path.write_text(json.dumps(values), encoding="utf-8")
    return path


def test_check_config_is_local_only(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    config = write_config(tmp_path / "router.json")

    def forbidden_run(*args, **kwargs):
        pytest.fail("--check-config must never invoke SSH")

    monkeypatch.setattr(router_probe.subprocess, "run", forbidden_run)
    monkeypatch.setattr(router_probe.shutil, "which", lambda name: pytest.fail(name))
    assert router_probe.main(["--check-config", "--config", str(config)]) == 0
    output = capsys.readouterr().out
    assert "router.example" in output
    assert "/mnt/USB drive/probe work" in output
    assert "No SSH connection" in output


def test_run_streams_exact_sources_and_quotes_scratch_as_remote_data(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    identity = tmp_path / "ssh identity"
    identity.write_text("local fixture", encoding="utf-8")
    config_path = write_config(
        tmp_path / "router.json",
        ssh_target="developer@router.example",
        ssh_identity_file=str(identity),
    )
    captured: dict[str, object] = {}

    def fake_run(argv, *, input, check):
        captured.update(argv=argv, input=input, check=check)
        return subprocess.CompletedProcess(argv, 0)

    monkeypatch.setattr(router_probe.subprocess, "run", fake_run)
    monkeypatch.setattr(router_probe.shutil, "which", lambda name: "/usr/bin/ssh")
    assert router_probe.main(["--run", "--config", str(config_path)]) == 0

    argv = captured["argv"]
    assert argv[:8] == [
        "/usr/bin/ssh",
        "-p",
        "2222",
        "-i",
        str(identity),
        "-o",
        "BatchMode=yes",
        "-o",
    ]
    assert argv[8:11] == [
        "PreferredAuthentications=publickey",
        "--",
        "developer@router.example",
    ]
    assert shlex.split(argv[11]) == [
        "/bin/sh",
        "-s",
        "--",
        "--run",
        "/mnt/USB drive/probe work",
    ]
    assert (
        captured["input"]
        == router_probe.STORAGE_LIBRARY.read_bytes()
        + b"\n"
        + router_probe.PROBE_SCRIPT.read_bytes()
    )
    assert captured["check"] is False
    output = capsys.readouterr().out
    assert "30-byte file" in output
    assert "services are not changed" in output


@pytest.mark.parametrize(
    ("raw", "message"),
    [
        (
            '{"mode":"KEY","ssh_target":"host","ssh_target":"other","scratch_dir":"/mnt/x"}',
            "duplicate",
        ),
        ('{"ssh_target":"host","scratch_dir":"/mnt/x"}', "mode"),
        ('{"mode":"key","ssh_target":"host","scratch_dir":"/mnt/x"}', "mode"),
        (
            '{"mode":"KEY","ssh_target":"-oProxyCommand=bad","scratch_dir":"/mnt/x"}',
            "ssh_target",
        ),
        (
            '{"mode":"KEY","ssh_target":"host","scratch_dir":"/mnt/../jffs"}',
            "normalized",
        ),
        (
            '{"mode":"KEY","ssh_target":"host","scratch_dir":"/mnt/x","ssh_port":true}',
            "integer",
        ),
        (
            '{"mode":"KEY","ssh_target":"host","scratch_dir":"/mnt/x","extra":"x"}',
            "unknown",
        ),
        (
            '{"mode":"KEY","ssh_target":"host","scratch_dir":"/mnt/x","ssh_port":NaN}',
            "constant",
        ),
    ],
)
def test_invalid_configuration_is_rejected_without_ssh(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys,
    raw: str,
    message: str,
) -> None:
    config_path = tmp_path / "router.json"
    config_path.write_text(raw, encoding="utf-8")
    monkeypatch.setattr(router_probe.shutil, "which", lambda name: pytest.fail(name))
    monkeypatch.setattr(
        router_probe.subprocess, "run", lambda *a, **k: pytest.fail("SSH started")
    )
    assert router_probe.main(["--run", "--config", str(config_path)]) == 2
    assert message in capsys.readouterr().err


def test_missing_default_config_points_to_generic_template(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    missing_default = router_probe.ROOT / "tools" / "router.not-created-for-test.json"
    monkeypatch.setattr(router_probe, "DEFAULT_CONFIG", missing_default)
    assert router_probe.main(["--check-config"]) == 2
    error = capsys.readouterr().err
    assert "tools/router.local.json.template" in error
    assert "tools/router.local.json" in error


def test_fifo_config_is_rejected_without_waiting(tmp_path: Path) -> None:
    fifo = tmp_path / "router.json"
    os.mkfifo(fifo)
    with pytest.raises(router_probe.ConfigError, match="regular file"):
        router_probe.load_config(fifo)


def test_missing_probe_source_fails_before_ssh(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    config = write_config(tmp_path / "router.json")
    monkeypatch.setattr(
        router_probe, "STORAGE_LIBRARY", tmp_path / "missing storage.sh"
    )
    monkeypatch.setattr(router_probe.shutil, "which", lambda name: "/usr/bin/ssh")
    monkeypatch.setattr(
        router_probe.subprocess,
        "run",
        lambda *args, **kwargs: pytest.fail("SSH must not start without the payload"),
    )
    assert router_probe.main(["--run", "--config", str(config)]) == 2
    error = capsys.readouterr().err
    assert "cannot read required probe source" in error
    assert "missing storage.sh" in error


@pytest.mark.parametrize("status", [0, 9])
def test_password_auth_uses_private_askpass_and_cleans_it_up(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys,
    status: int,
) -> None:
    password = "FAKE_router_password_4926"
    config = write_config(
        tmp_path / "router.json",
        mode="USR",
        ssh_user="fake-user",
        ssh_password=password,
        ssh_port="",
    )
    config.chmod(0o600)
    capture_path = tmp_path / "fake ssh capture.json"
    fake_ssh = tmp_path / "fake ssh"
    fake_ssh_python = tmp_path / "fake_ssh.py"
    fake_ssh_python.write_text(
        "import hashlib, json, os, stat, subprocess, sys\n"
        "from pathlib import Path\n"
        "helper = Path(os.environ['SSH_ASKPASS'])\n"
        'accepted = subprocess.run([str(helper), "fake-user@router.example\'s password: "], capture_output=True, check=False)\n'
        "hostkey = subprocess.run([str(helper), 'Are you sure you want to continue connecting (yes/no/[fingerprint])?'], capture_output=True, check=False)\n"
        "otp = subprocess.run([str(helper), 'Verification code: '], capture_output=True, check=False)\n"
        "generic = subprocess.run([str(helper), 'Password: '], capture_output=True, check=False)\n"
        "record = {\n"
        " 'argv': sys.argv[1:],\n"
        " 'stdin_sha256': hashlib.sha256(sys.stdin.buffer.read()).hexdigest(),\n"
        " 'env': {key: os.environ.get(key) for key in ('SSH_ASKPASS', 'SSH_ASKPASS_REQUIRE', 'DISPLAY', 'CFMGR_ROUTER_ASKPASS_CONFIG')},\n"
        f" 'env_contains_password': any({password!r} in value for value in os.environ.values()),\n"
        " 'helper_mode': stat.S_IMODE(helper.stat().st_mode),\n"
        " 'helper_dir_mode': stat.S_IMODE(helper.parent.stat().st_mode),\n"
        " 'helper_path': str(helper),\n"
        " 'helper_source': helper.read_text(),\n"
        " 'accepted': {'status': accepted.returncode, 'stdout': accepted.stdout.decode()},\n"
        " 'hostkey': {'status': hostkey.returncode, 'stdout': hostkey.stdout.decode()},\n"
        " 'otp': {'status': otp.returncode, 'stdout': otp.stdout.decode()},\n"
        " 'generic': {'status': generic.returncode, 'stdout': generic.stdout.decode()},\n"
        "}\n"
        "Path(os.environ['TEST_CAPTURE']).write_text(json.dumps(record))\n"
        "raise SystemExit(int(os.environ['TEST_SSH_STATUS']))\n",
        encoding="utf-8",
    )
    fake_ssh.write_text(
        "#!/bin/sh\nexec "
        + shlex.quote(sys.executable)
        + " "
        + shlex.quote(str(fake_ssh_python))
        + ' "$@"\n',
        encoding="utf-8",
    )
    fake_ssh.chmod(0o700)
    monkeypatch.setattr(router_probe.shutil, "which", lambda name: str(fake_ssh))
    monkeypatch.setenv("TEST_CAPTURE", str(capture_path))
    monkeypatch.setenv("TEST_SSH_STATUS", str(status))
    assert router_probe.main(["--run", "--config", str(config)]) == status
    output = capsys.readouterr().out

    record = json.loads(capture_path.read_text(encoding="utf-8"))
    assert "--" in record["argv"]
    assert "fake-user@router.example" in record["argv"]
    assert "-o" in record["argv"]
    assert "BatchMode=no" in record["argv"]
    assert "NumberOfPasswordPrompts=1" in record["argv"]
    assert "StrictHostKeyChecking=yes" in record["argv"]
    assert "PreferredAuthentications=password" in record["argv"]
    assert "PubkeyAuthentication=no" in record["argv"]
    assert "-p" not in record["argv"]
    assert password not in record["argv"]
    assert record["stdin_sha256"] == hashlib.sha256(router_probe._payload()).hexdigest()
    assert record["env"][router_probe.ASKPASS_CONFIG_ENV] == str(config.resolve())
    assert record["env"]["SSH_ASKPASS_REQUIRE"] == "force"
    assert record["env"]["DISPLAY"]
    assert all(password not in str(value) for value in record["env"].values())
    assert record["env_contains_password"] is False
    assert record["helper_mode"] == 0o700
    assert record["helper_dir_mode"] == 0o700
    assert password not in record["helper_source"]
    assert record["accepted"] == {"status": 0, "stdout": password + "\n"}
    for prompt in ("hostkey", "otp", "generic"):
        assert record[prompt]["status"] != 0
        assert record[prompt]["stdout"] == ""
    assert not Path(record["helper_path"]).exists()
    assert password not in output


def test_password_config_requires_private_current_user_file(
    tmp_path: Path,
) -> None:
    password = "FAKE_private_password"
    config = write_config(tmp_path / "router.json", ssh_password=password)
    config.chmod(0o644)
    with pytest.raises(router_probe.ConfigError, match="mode 600") as failure:
        router_probe.load_config(config)
    assert password not in str(failure.value)


@pytest.mark.parametrize(
    ("fields", "message"),
    [
        ({"mode": "USR"}, "ssh_user"),
        ({"mode": "USR", "ssh_user": "fake-user"}, "ssh_password"),
    ],
)
def test_user_password_mode_requires_both_credentials(
    tmp_path: Path, fields: dict[str, object], message: str
) -> None:
    config = write_config(tmp_path / "router.json", **fields)
    with pytest.raises(router_probe.ConfigError, match=message):
        router_probe.load_config(config)


def test_key_mode_ignores_stored_user_password_and_uses_explicit_overrides(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    identity = tmp_path / "custom identity"
    identity.write_text("key fixture", encoding="utf-8")
    password = "FAKE_ignored_in_KEY_mode"
    config = write_config(
        tmp_path / "router.json",
        mode="KEY",
        ssh_user="ignored-user",
        ssh_password=password,
        ssh_identity_file=str(identity),
        ssh_port=2222,
    )
    config.chmod(0o600)
    captured: dict[str, object] = {}

    def fake_run(argv, **kwargs):
        captured.update(argv=argv, kwargs=kwargs)
        return subprocess.CompletedProcess(argv, 0)

    monkeypatch.setattr(router_probe.shutil, "which", lambda name: "/usr/bin/ssh")
    monkeypatch.setattr(router_probe.subprocess, "run", fake_run)
    monkeypatch.setattr(
        router_probe,
        "_run_with_password_askpass",
        lambda *args: pytest.fail("KEY mode must not use password askpass"),
    )
    assert router_probe.main(["--run", "--config", str(config)]) == 0
    argv = captured["argv"]
    assert "-p" in argv and "2222" in argv
    assert "-i" in argv and str(identity) in argv
    assert "ignored-user@router.example" not in argv
    assert "router.example" in argv
    assert "BatchMode=yes" in argv
    assert "PreferredAuthentications=publickey" in argv
    assert "BatchMode=no" not in argv
    assert password not in argv
    assert "env" not in captured["kwargs"]
    assert "start_new_session" not in captured["kwargs"]
    assert password not in capsys.readouterr().out


@pytest.mark.parametrize("port", [None, ""])
def test_key_mode_blank_port_and_credentials_use_global_ssh_config(
    tmp_path: Path, port: int | str | None
) -> None:
    config = write_config(
        tmp_path / "router.json",
        mode="KEY",
        ssh_user="",
        ssh_password="",
        ssh_port=port,
        ssh_identity_file="",
    )
    loaded = router_probe.load_config(config)
    argv = router_probe._ssh_argv(loaded, "/usr/bin/ssh")
    assert "-p" not in argv
    assert "-i" not in argv
    assert argv[-2] == "router.example"
    assert "BatchMode=yes" in argv
    assert "PreferredAuthentications=publickey" in argv


def test_embedded_and_separate_ssh_user_cannot_both_be_set(tmp_path: Path) -> None:
    config = write_config(
        tmp_path / "router.json",
        ssh_target="embedded-user@router.example",
        ssh_user="separate-user",
    )
    with pytest.raises(router_probe.ConfigError, match="not both"):
        router_probe.load_config(config)


@pytest.mark.parametrize(
    "target", ["2001:db8::1", "[2001:db8::1]", "admin@[2001:db8::1]"]
)
def test_ipv6_ssh_targets_are_admitted_safely(tmp_path: Path, target: str) -> None:
    config = write_config(tmp_path / "router.json", ssh_target=target)
    assert router_probe.load_config(config)["ssh_target"] == target


def test_remote_status_is_propagated(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    config = write_config(tmp_path / "router.json")
    monkeypatch.setattr(router_probe.shutil, "which", lambda name: "/usr/bin/ssh")
    monkeypatch.setattr(
        router_probe.subprocess,
        "run",
        lambda argv, **kwargs: subprocess.CompletedProcess(argv, 7),
    )
    assert router_probe.main(["--run", "--config", str(config)]) == 7


def test_shipped_template_contains_only_generic_connection_values() -> None:
    template = router_probe.CONFIG_TEMPLATE.read_text(encoding="utf-8")
    data = json.loads(template)
    assert data["ssh_target"] == "router.example"
    assert data["mode"] == "USR"
    assert data["ssh_user"] == "fake-user"
    assert data["ssh_password"] == "fake-password"
    assert data["ssh_port"] == 2222
    assert data["scratch_dir"] == "/mnt/USB/probe-work"
    assert "/Users/" not in template
    assert "router@" not in template
