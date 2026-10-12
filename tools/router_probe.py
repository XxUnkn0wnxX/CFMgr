#!/usr/bin/env python3
"""Explicitly run the CFMgr storage probe on a Merlin router over SSH.

This developer-only launcher reads clone-local connection settings. It never
executes SSH unless --run is supplied and streams the reviewed shell sources
without rewriting them.
"""

from __future__ import annotations

import argparse
import ipaddress
import json
import os
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / "tools" / "router.local.json"
CONFIG_TEMPLATE = ROOT / "tools" / "router.local.json.template"
STORAGE_LIBRARY = ROOT / "modules" / "lib" / "storage.sh"
PROBE_SCRIPT = ROOT / "tools" / "router-storage-probe.sh"
LOCAL_TEMP = ROOT / ".tmp"
ASKPASS_CONFIG_ENV = "CFMGR_ROUTER_ASKPASS_CONFIG"
MAX_CONFIG_BYTES = 16 * 1024
MAX_PATH_BYTES = 4096
HOST_PATTERN = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,254}\Z")
USER_PATTERN = re.compile(r"[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}\Z")
PASSWORD_PROMPT = re.compile(r"[A-Za-z0-9_.@:\[\]-]+'s password: *", re.IGNORECASE)


class ConfigError(ValueError):
    """A local router configuration is missing or invalid."""


def _no_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ConfigError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _reject_constant(token: str) -> None:
    raise ConfigError(f"invalid JSON constant: {token}")


def _validate_text(value: Any, name: str, *, maximum: int) -> str:
    if not isinstance(value, str) or not value:
        raise ConfigError(
            f"{name} must be a non-empty string of at most {maximum} bytes"
        )
    if any(ord(character) < 0x20 or ord(character) > 0x7E for character in value):
        raise ConfigError(f"{name} must contain printable ASCII only")
    if len(value) > maximum:
        raise ConfigError(
            f"{name} must be a non-empty string of at most {maximum} bytes"
        )
    return value


def _validate_scratch(value: Any) -> str:
    path = _validate_text(value, "scratch_dir", maximum=MAX_PATH_BYTES)
    if not path.startswith("/") or path == "/" or path.endswith("/"):
        raise ConfigError("scratch_dir must be a normalized absolute directory path")
    components = path.split("/")
    if any(component in ("", ".", "..") for component in components[1:]):
        raise ConfigError("scratch_dir must be a normalized absolute directory path")
    return path


def _validate_ssh_target(value: Any) -> str:
    target = _validate_text(value, "ssh_target", maximum=255)
    if target.startswith("-") or target.count("@") > 1:
        raise ConfigError(
            "ssh_target must be a host, SSH alias, or user@host without options"
        )
    if "@" in target:
        username, host = target.split("@", 1)
        if not USER_PATTERN.fullmatch(username):
            raise ConfigError("ssh_target has an invalid SSH username")
    else:
        host = target
    if host.startswith("[") and host.endswith("]"):
        address = host[1:-1]
        try:
            ipaddress.IPv6Address(address)
        except ipaddress.AddressValueError as error:
            raise ConfigError(
                "bracketed ssh_target must contain an IPv6 address"
            ) from error
    elif ":" in host:
        try:
            ipaddress.IPv6Address(host)
        except ipaddress.AddressValueError as error:
            raise ConfigError(
                "colon-containing ssh_target must be a valid IPv6 address"
            ) from error
    elif not HOST_PATTERN.fullmatch(host):
        raise ConfigError(
            "ssh_target must be a host, SSH alias, or user@host without options"
        )
    return target


def _validate_config(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ConfigError("configuration must be one JSON object")
    allowed = {
        "mode",
        "ssh_target",
        "ssh_user",
        "ssh_password",
        "scratch_dir",
        "ssh_port",
        "ssh_identity_file",
    }
    unknown = sorted(set(value) - allowed)
    missing = sorted({"mode", "ssh_target", "scratch_dir"} - set(value))
    if unknown:
        raise ConfigError("unknown configuration key(s): " + ", ".join(unknown))
    if missing:
        raise ConfigError("missing configuration key(s): " + ", ".join(missing))

    mode = value["mode"]
    if mode not in ("KEY", "USR"):
        raise ConfigError("mode must be exactly KEY or USR")
    target = _validate_ssh_target(value["ssh_target"])
    username: str | None = None
    if "ssh_user" in value and value["ssh_user"] not in (None, ""):
        username = _validate_text(value["ssh_user"], "ssh_user", maximum=128)
        if not USER_PATTERN.fullmatch(username):
            raise ConfigError("ssh_user must be a simple SSH login name")
    if mode == "USR" and username is None:
        raise ConfigError("mode USR requires a non-empty ssh_user")
    if username is not None and "@" in target:
        raise ConfigError("set ssh_user or embed a username in ssh_target, not both")

    password: str | None = None
    if "ssh_password" in value:
        supplied_password = value["ssh_password"]
        if supplied_password is None or supplied_password == "":
            password = None
        elif not isinstance(supplied_password, str):
            raise ConfigError("ssh_password must be a string, null, or empty")
        else:
            try:
                encoded_password = supplied_password.encode("utf-8")
            except UnicodeEncodeError as error:
                raise ConfigError("ssh_password contains invalid Unicode") from error
            if len(encoded_password) > MAX_PATH_BYTES or any(
                character in supplied_password for character in "\x00\r\n"
            ):
                raise ConfigError(
                    "ssh_password must be at most 4096 UTF-8 bytes without line breaks"
                )
            password = supplied_password

    if mode == "USR" and password is None:
        raise ConfigError("mode USR requires a non-empty ssh_password")

    config: dict[str, Any] = {
        "mode": mode,
        "ssh_target": target,
        "scratch_dir": _validate_scratch(value["scratch_dir"]),
        "ssh_user": username,
        "ssh_password": password,
    }
    if "ssh_port" in value and value["ssh_port"] not in (None, ""):
        port = value["ssh_port"]
        if (
            isinstance(port, bool)
            or not isinstance(port, int)
            or not 1 <= port <= 65535
        ):
            raise ConfigError("ssh_port must be an integer from 1 through 65535")
        config["ssh_port"] = port
    else:
        config["ssh_port"] = None
    if "ssh_identity_file" in value and value["ssh_identity_file"] not in (None, ""):
        identity = _validate_text(
            value["ssh_identity_file"], "ssh_identity_file", maximum=MAX_PATH_BYTES
        )
        identity_path = Path(identity).expanduser()
        if (
            not identity_path.is_absolute()
            or not identity_path.is_file()
            or not os.access(identity_path, os.R_OK)
        ):
            raise ConfigError(
                "ssh_identity_file must name a readable local file with an absolute or ~/ path"
            )
        config["ssh_identity_file"] = str(identity_path)
    else:
        config["ssh_identity_file"] = None
    return config


def load_config(path: Path) -> dict[str, Any]:
    try:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NONBLOCK", 0))
        with os.fdopen(descriptor, "rb") as stream:
            metadata = os.fstat(stream.fileno())
            if not stat.S_ISREG(metadata.st_mode):
                raise ConfigError(f"configuration must be a regular file: {path}")
            raw = stream.read(MAX_CONFIG_BYTES + 1)
    except ConfigError:
        raise
    except OSError as error:
        if error.errno == 2 and path == DEFAULT_CONFIG:
            raise ConfigError(
                f"configuration not found: {DEFAULT_CONFIG.relative_to(ROOT)}\n"
                f"Copy {CONFIG_TEMPLATE.relative_to(ROOT)} to "
                f"{DEFAULT_CONFIG.relative_to(ROOT)} and edit the SSH target and scratch path."
            ) from error
        raise ConfigError(
            f"cannot read configuration {path}: {error.strerror or error}"
        ) from error
    if len(raw) > MAX_CONFIG_BYTES:
        raise ConfigError(f"configuration exceeds {MAX_CONFIG_BYTES} bytes")
    try:
        decoded = raw.decode("utf-8")
        parsed = json.loads(
            decoded,
            object_pairs_hook=_no_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ConfigError(f"invalid UTF-8 JSON configuration: {error}") from error
    config = _validate_config(parsed)
    if config["ssh_password"] is not None:
        if not hasattr(os, "getuid"):
            raise ConfigError(
                "password authentication requires POSIX file ownership checks"
            )
        if (
            metadata.st_uid != os.getuid()
            or metadata.st_mode & 0o077
            or not metadata.st_mode & 0o400
        ):
            raise ConfigError(
                "password-bearing config must be owned by the current user and "
                "readable only by that user; set it to mode 600 (for example, chmod 600 PATH)"
            )
    return config


def _remote_command(scratch_dir: str) -> str:
    return shlex.join(["/bin/sh", "-s", "--", "--run", scratch_dir])


def _payload() -> bytes:
    return STORAGE_LIBRARY.read_bytes() + b"\n" + PROBE_SCRIPT.read_bytes()


def _ssh_argv(config: dict[str, Any], ssh_path: str) -> list[str]:
    argv = [ssh_path]
    if config.get("ssh_port") is not None:
        argv.extend(["-p", str(config["ssh_port"])])
    if config["mode"] == "KEY" and config.get("ssh_identity_file") is not None:
        argv.extend(["-i", config["ssh_identity_file"]])
    if config["mode"] == "KEY":
        argv.extend(["-o", "BatchMode=yes", "-o", "PreferredAuthentications=publickey"])
    else:
        argv.extend(
            [
                "-o",
                "BatchMode=no",
                "-o",
                "NumberOfPasswordPrompts=1",
                "-o",
                "StrictHostKeyChecking=yes",
                "-o",
                "PreferredAuthentications=password",
                "-o",
                "PubkeyAuthentication=no",
            ]
        )
    target = config["ssh_target"]
    if config["mode"] == "USR":
        target = f"{config['ssh_user']}@{target}"
    argv.extend(["--", target, _remote_command(config["scratch_dir"])])
    return argv


def _is_password_prompt(prompt: str) -> bool:
    return bool(PASSWORD_PROMPT.fullmatch(prompt))


def _askpass_main(argv: list[str]) -> int:
    # SSH_ASKPASS may request passwords only. Host-key, key-passphrase,
    # keyboard-interactive/OTP and any unrecognized prompts receive no secret.
    if len(argv) != 1 or not _is_password_prompt(argv[0]):
        return 1
    config_path = os.environ.get(ASKPASS_CONFIG_ENV)
    if not config_path:
        return 1
    try:
        askpass_config = load_config(Path(config_path))
    except (ConfigError, OSError, ValueError):
        return 1
    if askpass_config.get("mode") != "USR":
        return 1
    password = askpass_config.get("ssh_password")
    if password is None:
        return 1
    sys.stdout.write(password + "\n")
    return 0


def _askpass_environment(config_path: Path, helper_dir: Path) -> dict[str, str]:
    helper = helper_dir / "askpass"
    script = Path(__file__).resolve()
    helper.write_text(
        "#!/bin/sh\nexec "
        + shlex.quote(sys.executable)
        + " "
        + shlex.quote(str(script))
        + ' --askpass "$@"\n',
        encoding="utf-8",
    )
    helper.chmod(0o700)
    environment = os.environ.copy()
    environment["SSH_ASKPASS"] = str(helper)
    environment["SSH_ASKPASS_REQUIRE"] = "force"
    environment[ASKPASS_CONFIG_ENV] = str(config_path.resolve())
    environment.setdefault("DISPLAY", "cfmgr-askpass")
    return environment


def _run_with_password_askpass(
    argv: list[str], payload: bytes, config_path: Path
) -> subprocess.CompletedProcess[bytes]:
    if os.name != "posix":
        raise ConfigError(
            "SSH password prompts require a POSIX SSH_ASKPASS environment"
        )
    try:
        if LOCAL_TEMP.is_symlink():
            raise ConfigError(
                "project .tmp directory must not be a symlink for password authentication"
            )
        LOCAL_TEMP.mkdir(mode=0o700, parents=True, exist_ok=True)
        if not LOCAL_TEMP.is_dir():
            raise ConfigError("project .tmp path is not a directory")
        with tempfile.TemporaryDirectory(
            prefix="router-askpass-", dir=LOCAL_TEMP
        ) as temporary_directory:
            helper_dir = Path(temporary_directory)
            environment = _askpass_environment(config_path, helper_dir)
            return subprocess.run(
                argv,
                input=payload,
                check=False,
                env=environment,
                start_new_session=True,
            )
    except ConfigError:
        raise
    except OSError as error:
        raise ConfigError(
            f"could not run SSH password authentication: {error.strerror or error}"
        ) from error


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the opt-in CFMgr storage probe on a configured Merlin router.",
        epilog=(
            "Key or agent authentication is recommended. An optional SSH password "
            "may be read from the private, ignored local config file. "
            "The remote probe writes one private 30-byte test file only below "
            "scratch_dir, verifies its flush/rename/readback, and removes only "
            "its verified artifacts. It does not change router settings or services."
        ),
    )
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument(
        "--check-config",
        action="store_true",
        help="validate local settings only; never connect",
    )
    action.add_argument(
        "--run",
        action="store_true",
        help="connect by SSH and explicitly run the remote probe",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=DEFAULT_CONFIG,
        metavar="PATH",
        help="local JSON settings file (default: tools/router.local.json)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    if argv is None:
        argv = sys.argv[1:]
    if argv and argv[0] == "--askpass":
        return _askpass_main(argv[1:])
    args = _parse_args(argv)
    try:
        config = load_config(args.config)
        if args.check_config:
            print(f"Configuration valid for SSH target {config['ssh_target']}.")
            print(f"Scratch directory: {config['scratch_dir']}")
            print("No SSH connection or router command was run.")
            return 0

        ssh_path = shutil.which("ssh")
        if ssh_path is None:
            raise ConfigError("ssh executable was not found on PATH")
        try:
            payload = _payload()
        except OSError as error:
            missing_source = error.filename
            try:
                display_path = Path(missing_source).relative_to(ROOT)
            except (TypeError, ValueError):
                display_path = missing_source
            raise ConfigError(
                f"cannot read required probe source {display_path}: {error.strerror or error}"
            ) from error
        print(
            "About to connect and run the probe: it creates one private "
            "30-byte file below the configured scratch directory, checks "
            "native flush/rename/readback, then removes its verified artifacts. "
            "The scratch directory itself is retained; settings and services "
            "are not changed.",
            flush=True,
        )
        try:
            ssh_argv = _ssh_argv(config, ssh_path)
            if config["mode"] == "USR":
                result = _run_with_password_askpass(ssh_argv, payload, args.config)
            else:
                result = subprocess.run(ssh_argv, input=payload, check=False)
        except OSError as error:
            raise ConfigError(f"could not start ssh: {error}") from error
        return result.returncode
    except ConfigError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print(
            "Interrupted while waiting for SSH; check the router output for probe cleanup status.",
            file=sys.stderr,
        )
        return 130


if __name__ == "__main__":
    raise SystemExit(main())
