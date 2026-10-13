"""Native retained-config observation, bounded receipts and byte-preserving edits."""

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
UUID = "01234567-89ab-cdef-0123-456789abcdef"
OBSERVATION = {
    "CFMGR_CONFIG_UUID": UUID,
    "CFMGR_CONFIG_FILESYSTEM": "ext4",
    "CFMGR_CONFIG_ROOT": "/mnt/usb",
    "CFMGR_CONFIG_RELATIVE": "entware",
}


@pytest.fixture(scope="module")
def commands() -> tuple[list[str], list[str]]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    shell = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert shell and shutil.which(shell[0]), "Selected POSIX test shell is missing"
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        assert sys.platform == "linux", "Required native BusyBox proof needs Linux"
        assert Path(shell[0]).name == "busybox" and shell[1:] == ["ash"]
        awk = [shell[0], "awk"]
    else:
        executable = shutil.which("awk")
        assert executable, "Actual native awk is required"
        awk = [executable]
    return shell, awk


@pytest.fixture(scope="module")
def config(commands: tuple[list[str], list[str]]) -> bytes:
    jq = shutil.which("jq")
    assert jq, "Actual jq is required to construct retained settings"
    result = subprocess.run(
        [
            *commands[0],
            "-c",
            '. "$1"; shift; cfmgr_config_defaults "$@"',
            "config-observation-test",
            str(ROOT / "modules/lib/config.sh"),
            str(Path(jq).resolve()),
            "https://github.com/example/CFMgr",
            "develop",
            UUID,
            "ext4",
            "/mnt/usb",
            "entware",
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stderr) == (0, b"")
    return result.stdout


def invoke(
    commands: tuple[list[str], list[str]],
    tmp_path: Path,
    data: bytes,
    mode: str,
    observation: dict[str, str] | None = None,
    *,
    size: int | None = None,
) -> subprocess.CompletedProcess[bytes]:
    snapshot = tmp_path / "private immutable config"
    snapshot.write_bytes(data)
    snapshot.chmod(0o600)
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("CFMGR_CONFIG_")
    }
    environment.update({"LC_ALL": "C", **(observation or {})})
    with snapshot.open("rb") as source:
        return subprocess.run(
            [
                *commands[1],
                "-v",
                f"cfmgr_json_size={len(data) if size is None else size}",
                "-v",
                "cfmgr_json_mode=tree",
                "-v",
                f"cfmgr_config_mode={mode}",
                "-f",
                str(ROOT / "modules/lib/json.awk"),
                "-f",
                str(ROOT / "modules/lib/config_observation.awk"),
            ],
            stdin=source,
            env=environment,
            capture_output=True,
            check=False,
            timeout=5,
        )


def receipt(
    old: str, new: str, changed: int, input_size: int, output_size: int
) -> bytes:
    return (
        f"CFMGR-CONFIG 1 {old} {new} {changed} {input_size} {output_size} END\n"
    ).encode()


def test_generated_config_check_and_noop_are_exact(commands, config, tmp_path) -> None:
    for mode in ("check", "observe", "patch"):
        result = invoke(commands, tmp_path, config, mode, OBSERVATION)
        expected = (
            config
            if mode == "patch"
            else receipt("1", "1", 0, len(config), len(config))
        )
        assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")
    # check is intentionally independent of any current-storage observation.
    checked = invoke(commands, tmp_path, config, "check")
    assert (checked.returncode, checked.stdout) == (
        0,
        receipt("1", "1", 0, len(config), len(config)),
    )


def settings_invoke(
    commands: tuple[list[str], list[str]],
    tmp_path: Path,
    data: bytes,
    mode: str,
    *,
    mask: str | None = None,
    check: str | None = None,
    auto: str | None = None,
    size: int | None = None,
) -> subprocess.CompletedProcess[bytes]:
    settings = {
        "CFMGR_SETTINGS_MASK": mask,
        "CFMGR_SETTINGS_CHECK": check,
        "CFMGR_SETTINGS_AUTO": auto,
    }
    observation = {key: value for key, value in settings.items() if value is not None}
    return invoke(
        commands,
        tmp_path,
        data,
        mode,
        observation,
        size=size,
    )


def settings_receipt(
    old: str,
    new: str,
    changed: int,
    check: int,
    auto: int,
    developer: int,
    input_size: int,
    output_size: int,
) -> bytes:
    return (
        f"CFMGR-SETTINGS-PATCH 1 {old} {new} {changed} {check} {auto} "
        f"{developer} {input_size} {output_size} END\n"
    ).encode()


def test_settings_read_returns_saved_values_and_preserves_contradiction(
    commands, config, tmp_path
) -> None:
    defaults = settings_invoke(commands, tmp_path, config, "settings-read")
    assert (defaults.returncode, defaults.stdout, defaults.stderr) == (
        0,
        b"CFMGR-SETTINGS 1 1 1 0 0 END\n",
        b"",
    )
    value = json.loads(config)
    value["manager"].update(check_updates=False, auto_update=True, developer=True)
    data = json.dumps(value, indent=2).encode() + b"\n"
    result = settings_invoke(commands, tmp_path, data, "settings-read")
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-SETTINGS 1 1 0 1 1 END\n",
        b"",
    )
    assert (tmp_path / "private immutable config").read_bytes() == data


@pytest.mark.parametrize(
    (
        "check",
        "auto",
        "mask",
        "wanted_check",
        "wanted_auto",
        "expected_check",
        "expected_auto",
    ),
    [
        (False, False, "check", "1", "0", 1, 0),  # Check On owns Check.
        (True, True, "check", "0", "0", 0, 0),  # Check Off closes Auto too.
        (False, False, "auto", "0", "1", 1, 1),  # Auto On closes Check too.
        (True, True, "auto", "0", "0", 1, 0),  # Auto Off owns Auto.
    ],
)
def test_settings_intents_close_over_fresh_values(
    commands,
    config,
    tmp_path,
    check,
    auto,
    mask,
    wanted_check,
    wanted_auto,
    expected_check,
    expected_auto,
) -> None:
    value = json.loads(config)
    value["generation"] = 7
    value["manager"].update(
        check_updates=check,
        auto_update=auto,
        developer=True,
    )
    base = json.dumps(value, ensure_ascii=False, indent=2).encode() + b"\n"
    # Preserve a deliberately noncanonical unknown field and huge raw number.
    original = b'{\n  "future" : {"large":900719925474099312345},\n' + base[1:]
    patched = settings_invoke(
        commands,
        tmp_path,
        original,
        "settings-patch",
        mask=mask,
        check=wanted_check,
        auto=wanted_auto,
    )
    assert patched.returncode == 0, patched.stderr
    expected = original.replace(b'"generation": 7', b'"generation": 8')
    if expected_check != check:
        expected = expected.replace(
            f'"check_updates": {str(check).lower()}'.encode(),
            f'"check_updates": {str(bool(expected_check)).lower()}'.encode(),
        )
    if expected_auto != auto:
        expected = expected.replace(
            f'"auto_update": {str(auto).lower()}'.encode(),
            f'"auto_update": {str(bool(expected_auto)).lower()}'.encode(),
        )
    assert patched.stdout == expected
    result = json.loads(patched.stdout)
    assert result["generation"] == (
        8 if (expected_check, expected_auto) != (check, auto) else 7
    )
    assert result["manager"]["check_updates"] is bool(expected_check)
    assert result["manager"]["auto_update"] is bool(expected_auto)
    assert result["manager"]["developer"] is True
    assert result["future"]["large"] == 900719925474099312345
    observed = settings_invoke(
        commands,
        tmp_path,
        original,
        "settings-observe",
        mask=mask,
        check=wanted_check,
        auto=wanted_auto,
    )
    changed = int((expected_check, expected_auto) != (check, auto))
    assert (observed.returncode, observed.stdout, observed.stderr) == (
        0,
        settings_receipt(
            "7",
            "8" if changed else "7",
            changed,
            expected_check,
            expected_auto,
            1,
            len(original),
            len(patched.stdout),
        ),
        b"",
    )


def test_settings_observe_uses_latest_same_generation_candidate(
    commands, config, tmp_path
) -> None:
    # A same-generation edit between review and observe is the current base. The
    # selected Auto Off intent must preserve its latest Check value and all bytes.
    latest = config.replace(b'"check_updates":true', b'"check_updates":false')
    latest = latest.replace(b'"developer":false', b'"developer":true')
    observed = settings_invoke(
        commands,
        tmp_path,
        latest,
        "settings-observe",
        mask="auto",
        check="0",
        auto="0",
    )
    assert observed.returncode == 0, observed.stderr
    patched = settings_invoke(
        commands,
        tmp_path,
        latest,
        "settings-patch",
        mask="auto",
        check="0",
        auto="0",
    )
    assert patched.returncode == 0
    assert patched.stdout == latest
    assert observed.stdout == settings_receipt(
        "1", "1", 0, 0, 0, 1, len(latest), len(latest)
    )


def test_settings_explicit_conflict_and_invalid_mask_are_rejected(
    commands, config, tmp_path
) -> None:
    for mask, check, auto in (
        ("both", "0", "1"),
        ("other", "1", "0"),
        ("check", "true", "0"),
        ("auto", "0", ""),
    ):
        result = settings_invoke(
            commands,
            tmp_path,
            config,
            "settings-observe",
            mask=mask,
            check=check,
            auto=auto,
        )
        assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def test_settings_generation_increment_noop_and_overflow(
    commands, config, tmp_path
) -> None:
    original = config.replace(b'"generation":1', b'"generation":9999999999999999999')
    unchanged = settings_invoke(
        commands,
        tmp_path,
        original,
        "settings-observe",
        mask="auto",
        check="0",
        auto="0",
    )
    assert unchanged.stdout == settings_receipt(
        "9999999999999999999",
        "9999999999999999999",
        0,
        1,
        0,
        0,
        len(original),
        len(original),
    )
    changed = settings_invoke(
        commands,
        tmp_path,
        original,
        "settings-observe",
        mask="auto",
        check="0",
        auto="1",
    )
    assert changed.stdout == settings_receipt(
        "9999999999999999999",
        "10000000000000000000",
        1,
        1,
        1,
        0,
        len(original),
        len(original),
    )
    overflow = original.replace(
        b'"generation":9999999999999999999',
        b'"generation":99999999999999999999',
    )
    rejected = settings_invoke(
        commands,
        tmp_path,
        overflow,
        "settings-observe",
        mask="auto",
        check="0",
        auto="1",
    )
    assert (rejected.returncode, rejected.stdout, rejected.stderr) == (1, b"", b"")


def test_settings_patch_rejects_candidate_over_limit_without_output(
    commands, config, tmp_path
) -> None:
    value = json.loads(config)
    value["manager"].update(check_updates=True, auto_update=True)
    original = json.dumps(value, separators=(",", ":")).encode()
    original += b" " * (65535 - len(original))
    result = settings_invoke(
        commands,
        tmp_path,
        original,
        "settings-patch",
        mask="check",
        check="0",
        auto="0",
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


@pytest.mark.parametrize(
    ("configured", "enabled", "installed", "maintenance", "scope"),
    [
        (False, False, False, False, "shared"),
        (False, False, True, True, "shared"),
        (True, False, True, True, "tunnel"),
        (True, True, True, False, "tunnel"),
        (False, True, True, True, None),
    ],
)
def test_dependency_scope_uses_configured_tunnel_including_off(
    commands, config, tmp_path, configured, enabled, installed, maintenance, scope
) -> None:
    value = json.loads(config)
    value["cloudflared"].update(
        configured=configured,
        enabled=enabled,
        installed=installed,
        maintenance_enabled=maintenance,
    )
    value["history"]["cloudflared"] = {"private": "must-not-appear"}
    data = json.dumps(value).encode()
    result = invoke(commands, tmp_path, data, "scope")
    if scope is None:
        assert result.returncode != 0 and result.stdout == b""
    else:
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            f"CFMGR-SCOPE 1 1 {scope} END\n".encode(),
            b"",
        )
    # Scope never edits the original data or relaxes full-schema validation.
    assert (tmp_path / "private immutable config").read_bytes() == data
    del value["history"]
    invalid = invoke(commands, tmp_path, json.dumps(value).encode(), "scope")
    assert invalid.returncode != 0 and invalid.stdout == b""


def test_changed_observation_preserves_unrelated_bytes_and_reparses(
    commands, config, tmp_path
) -> None:
    # Unknown fields, huge raw numbers, formatting and escape choices survive.
    original = config.replace(
        b'"generation":1,',
        b'"future":{"precise":90071992547409931234567890,"escape":"\\u00e9"},\n  "generation" : 1,',
    ).replace(b'"check_updates":true', b'"check_updates":false')
    observation = {
        **OBSERVATION,
        "CFMGR_CONFIG_UUID": "abcdef01-2345-6789-abcd-0123456789ab",
        "CFMGR_CONFIG_FILESYSTEM": "ext3",
        "CFMGR_CONFIG_ROOT": '/mnt/relabelled "disk"\\literal',
        "CFMGR_CONFIG_RELATIVE": "entware moved",
    }
    expected = original.replace(b'"generation" : 1', b'"generation" : 2')
    for field, env_key in zip(
        ("uuid", "filesystem", "root", "relative"), OBSERVATION, strict=True
    ):
        old_value = json.dumps(OBSERVATION[env_key]).encode()
        new_value = json.dumps(observation[env_key]).encode()
        expected = expected.replace(
            f'"{field}":'.encode() + old_value, f'"{field}":'.encode() + new_value
        )
    patched = invoke(commands, tmp_path, original, "patch", observation)
    assert (patched.returncode, patched.stdout, patched.stderr) == (0, expected, b"")
    observed = invoke(commands, tmp_path, original, "observe", observation)
    assert (observed.returncode, observed.stdout, observed.stderr) == (
        0,
        receipt("1", "2", 1, len(original), len(patched.stdout)),
        b"",
    )
    parsed = json.loads(patched.stdout)
    assert parsed["manager"]["check_updates"] is False
    assert parsed["future"]["precise"] == 90071992547409931234567890
    checked = invoke(commands, tmp_path, patched.stdout, "check")
    assert checked.stdout == receipt("2", "2", 0, len(expected), len(expected))
    assert checked.returncode == 0


@pytest.mark.parametrize("generation", ["9007199254740999", "9999999999999999999"])
def test_generation_carry_is_decimal_string_arithmetic(
    commands, config, tmp_path, generation
) -> None:
    original = config.replace(b'"generation":1', b'"generation":' + generation.encode())
    new = str(int(generation) + 1)
    observation = {**OBSERVATION, "CFMGR_CONFIG_ROOT": "/mnt/renamed"}
    patched = invoke(commands, tmp_path, original, "patch", observation)
    assert patched.returncode == 0
    assert b'"generation":' + new.encode() + b"," in patched.stdout
    observed = invoke(commands, tmp_path, original, "observe", observation)
    assert observed.stdout == receipt(
        generation, new, 1, len(original), len(patched.stdout)
    )


def test_generation_overflow_rejects_change_but_preserves_noop(
    commands, config, tmp_path
) -> None:
    original = config.replace(b'"generation":1', b'"generation":99999999999999999999')
    unchanged = invoke(commands, tmp_path, original, "patch", OBSERVATION)
    assert (unchanged.returncode, unchanged.stdout) == (0, original)
    for mode in ("observe", "patch"):
        changed = invoke(
            commands,
            tmp_path,
            original,
            mode,
            {**OBSERVATION, "CFMGR_CONFIG_ROOT": "/elsewhere"},
        )
        assert (changed.returncode, changed.stdout, changed.stderr) == (1, b"", b"")


@pytest.mark.parametrize(
    "failure", ["duplicate", "truncated", "schema", "control-type"]
)
def test_bad_retained_config_produces_no_candidate(
    commands, config, tmp_path, failure
) -> None:
    originals = {
        "duplicate": config.replace(b'"schema":1', b'"schema":1,"\\u0073chema":1'),
        "truncated": config[:-3],
        "schema": config.replace(b'"schema":1', b'"schema":2'),
        "control-type": config.replace(
            b'"auto_update":false', b'"auto_update":"false"'
        ),
    }
    result = invoke(commands, tmp_path, originals[failure], "patch", OBSERVATION)
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def test_invalid_observation_and_wrong_byte_count_are_rejected(
    commands, config, tmp_path
) -> None:
    for observation in (
        {**OBSERVATION, "CFMGR_CONFIG_UUID": "not-a-uuid"},
        {**OBSERVATION, "CFMGR_CONFIG_FILESYSTEM": "vfat"},
        {**OBSERVATION, "CFMGR_CONFIG_RELATIVE": "../outside"},
        {**OBSERVATION, "CFMGR_CONFIG_ROOT": "/mnt/bad\npath"},
    ):
        result = invoke(commands, tmp_path, config, "patch", observation)
        assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")
    mismatched = invoke(commands, tmp_path, config, "check", size=len(config) + 1)
    assert (mismatched.returncode, mismatched.stdout) == (1, b"")
    for malformed in (
        config + b"\x00",
        config.replace(b'"/mnt/usb"', b'"/mnt/\xff"'),
    ):
        rejected = invoke(commands, tmp_path, malformed, "patch", OBSERVATION)
        assert (rejected.returncode, rejected.stdout, rejected.stderr) == (1, b"", b"")


def test_retained_utf8_backslash_paths_survive_noop_and_other_changes(
    commands, config, tmp_path
) -> None:
    root = "/mnt/café\\disk"
    observation = {**OBSERVATION, "CFMGR_CONFIG_ROOT": root}
    for ascii_escapes in (False, True):
        original = config.replace(
            b'"/mnt/usb"', json.dumps(root, ensure_ascii=ascii_escapes).encode()
        )
        unchanged = invoke(commands, tmp_path, original, "patch", observation)
        assert (unchanged.returncode, unchanged.stdout) == (0, original)
        changed = invoke(
            commands,
            tmp_path,
            original,
            "patch",
            {**observation, "CFMGR_CONFIG_FILESYSTEM": "ext2"},
        )
        assert (changed.returncode, changed.stdout) == (
            0,
            original.replace(b'"generation":1', b'"generation":2').replace(
                b'"filesystem":"ext4"', b'"filesystem":"ext2"'
            ),
        )


def test_candidate_size_limit_is_checked_before_output(
    commands, config, tmp_path
) -> None:
    # A long unchanged string is unnecessary: legal trailing JSON whitespace proves
    # the byte-budget boundary without increasing parser/token work.
    original = config + b" " * (65536 - len(config))
    assert invoke(commands, tmp_path, original, "check").returncode == 0
    observation = {**OBSERVATION, "CFMGR_CONFIG_ROOT": "/mnt/longer-label"}
    for mode in ("observe", "patch"):
        result = invoke(commands, tmp_path, original, mode, observation)
        assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")
