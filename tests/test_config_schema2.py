"""Typed schema2 authority through actual bounded readers and scoped writers.

Schema1 byte-preservation regressions retain their original explicit fixture.
No provider, firmware settings or lifecycle effects are exercised here.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path

import pytest
from test_backup_menu import (
    _installed_settings_entry,
    installed_backup_entry,
)
from test_config_observation import (
    BACKUP_DESTINATION,
    OBSERVATION,
    commands,
    config,
    invoke,
    schema2_config,
    settings_invoke,
)
from test_config_store import run_store, store_fixture
from test_install import legacy_fsync, package, shell, tools
from test_manager_settings_entry import installed_settings_entry, run_entry
from test_retained_launch import launch_host, retained_package
from test_status import project, record

ROOT = Path(__file__).resolve().parents[1]
__all__ = [
    "_installed_settings_entry",
    "commands",
    "config",
    "installed_backup_entry",
    "installed_settings_entry",
    "legacy_fsync",
    "package",
    "retained_package",
    "schema2_config",
    "shell",
    "store_fixture",
    "tools",
]
TUNNEL = "12345678-1234-1234-1234-123456789abc"
SECRET = "fixture-private-value"


@pytest.fixture(scope="module")
def populated(schema2_config):
    value = json.loads(schema2_config)
    value["credentials"] = {
        "shared-api": {"schema": 1, "kind": "cloudflare_api_token", "value": SECRET},
        "runtime-token": {"schema": 1, "kind": "cloudflared_token", "value": SECRET},
        "advanced": {
            "schema": 1,
            "kind": "cloudflared_json",
            "account_tag": "Account literal",
            "tunnel_id": TUNNEL,
            "tunnel_secret": SECRET,
        },
        "certificate": {
            "schema": 1,
            "kind": "cloudflared_certificate",
            "account_id": "Account literal",
            "path": "/opt/etc/cloudflared/cert.pem",
            "recovery_path": "/jffs/addons/CFMgr.d/certificate",
            "sha256": "a" * 64,
            "generation": 1,
            "provenance": "import",
            "format": "provider-validated-format",
        },
    }
    value["ddns"].update(
        configured=True,
        enabled=False,
        credential_ref="shared-api",
        zone_id="Zone literal",
        primary_hostname="example.test",
        records=[
            {"id": "web4", "name": "example.test", "type": "A"},
            {"id": "web6", "name": "example.test", "type": "AAAA"},
        ],
        ttl={"mode": "auto"},
        proxied=True,
        timeouts={
            "schema": 1,
            "request_timeout_seconds": 20,
            "connect_timeout_seconds": 5,
            "completion_timeout_seconds": 30,
        },
    )
    value["ip_sync"].update(
        configured=True,
        enabled=True,
        credential_ref="shared-api",
        account_id="Account literal",
        address_family="dual",
        targets=[
            {
                "role": "primary",
                "id": "IPv6 target",
                "name": "Primary",
                "families": ["ipv6"],
            },
            {
                "role": "secondary",
                "id": "IPv4 target",
                "name": "Secondary",
                "families": ["ipv4"],
            },
        ],
        retry={
            "schema": 1,
            "attempts": 4,
            "request_timeout_seconds": 20,
            "connect_timeout_seconds": 5,
            "batch_timeout_seconds": 120,
        },
    )
    value["cloudflared"].update(
        configured=True,
        enabled=False,
        installed=False,
        maintenance_enabled=True,
        method="advanced",
        expected_identity={"account_id": "Account literal", "tunnel_id": TUNNEL},
        paths={
            "yaml": "/opt/etc/cloudflared/config.yml",
            "json": "/opt/etc/cloudflared/credentials.json",
            "certificate": "/opt/etc/cloudflared/cert.pem",
        },
        credential_refs={
            "runtime": "advanced",
            "management": "shared-api",
            "dns": "shared-api",
            "certificate": "certificate",
        },
        readiness={
            "schema": 1,
            "response_timeout_seconds": 2,
            "command_timeout_seconds": 3,
        },
        watchdog={"schema": 1, "reconnect_grace_seconds": 60, "stability_seconds": 300},
        binary_auto_update=True,
    )
    value["network"].update(
        selected_wan=1,
        discovery={
            "schema": 1,
            "interval_seconds": 300,
            "request_timeout_seconds": 20,
            "connect_timeout_seconds": 5,
        },
    )
    for feature in ("ddns", "ip_sync"):
        value["logging"][feature].update(
            configured=True, enabled=False, policy={"schema": 1, "version": 1}
        )
    value["logging"]["cloudflared"].update(
        configured=True,
        enabled=True,
        policy={
            "schema": 1,
            "mode": "daily",
            "size": {"value": 10, "unit": "MiB"},
            "total_files": 5,
            "max_age_days": 30,
        },
    )
    value["backup"].update(
        retention=3,
        date_format="YMD",
        last_backup={
            "schema": 1,
            "generation": 1,
            "at": 1700000000,
            "local_date": "2023-11-14",
            "local_time": "22:13:20",
            "timezone": "UTC",
            "date_format": "YMD",
            "set_id": "fixture-set",
            "archive_id": "fixture-archive",
        },
    )
    value["ownership"].update(
        components=[
            {
                "schema": 1,
                "component": "cloudflared",
                "path": "/opt/bin/cloudflared",
                "generation": 1,
                "sha256": "b" * 64,
            }
        ],
        migration={
            "schema": 1,
            "source_schema": 1,
            "source": "Reviewed import",
            "state": "complete",
            "generation": 1,
        },
    )
    value["history"]["ddns"] = {
        "status": record(),
        "ordinary_extension": "keep literal \\ data",
    }
    value["history"]["ddns"]["status"]["events"] = [
        {"result": "pending", "reason": "network", "at": 1700000000 - i}
        for i in range(8)
    ]
    value["future ordinary"] = {"secret-like": SECRET, "literal": "$(touch sentinel)"}
    return value


def payload(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode()


def test_populated_real_readers_and_exact_scoped_patch(commands, populated, tmp_path):
    original = payload(populated)
    for mode in ("check", "scope", "settings-read", "backup-read"):
        result = invoke(commands, tmp_path, original, mode)
        assert (result.returncode, result.stderr) == (0, b""), (mode, result.stdout)
    unchanged = invoke(commands, tmp_path, original, "patch", OBSERVATION)
    assert (unchanged.returncode, unchanged.stdout) == (0, original)
    changed = invoke(
        commands,
        tmp_path,
        original,
        "patch",
        {**OBSERVATION, "CFMGR_CONFIG_FILESYSTEM": "ext3"},
    )
    assert changed.stdout == original.replace(
        b'"generation": 1,', b'"generation": 2,', 1
    ).replace(b'"filesystem": "ext4"', b'"filesystem": "ext3"')
    settings = settings_invoke(
        commands,
        tmp_path,
        original,
        "settings-patch",
        mask="check",
        check="0",
        auto="0",
    )
    assert settings.stdout == original.replace(
        b'"generation": 1,', b'"generation": 2,', 1
    ).replace(b'"check_updates": true', b'"check_updates": false')
    environment = {
        f"CFMGR_BACKUP_{key}": BACKUP_DESTINATION[source]
        for key, source in [
            ("MOUNT", "mountpoint"),
            ("UUID", "uuid"),
            ("FILESYSTEM", "filesystem"),
            ("ROOT", "root"),
        ]
    }
    backup = invoke(commands, tmp_path, original, "backup-patch", environment)
    expected = original.replace(b'"generation": 1,', b'"generation": 2,', 1).replace(
        b'"destination": null',
        b'"destination": '
        + json.dumps(BACKUP_DESTINATION, separators=(",", ":")).encode(),
    )
    assert (backup.returncode, backup.stdout) == (0, expected)
    # Same secret values do not merge independent authorities or references.
    assert json.loads(backup.stdout)["credentials"] == populated["credentials"]
    assert not (tmp_path / "sentinel").exists()


@pytest.mark.parametrize("method", ["token", "advanced", "maintenance-only"])
def test_independent_states_and_runtime_methods(commands, populated, tmp_path, method):
    value = copy.deepcopy(populated)
    cloud = value["cloudflared"]
    if method == "token":
        cloud.update(
            method="token",
            enabled=True,
            installed=True,
            expected_identity={"account_id": None, "tunnel_id": None},
            credential_refs={
                "runtime": "runtime-token",
                "management": None,
                "certificate": None,
                "dns": None,
            },
            paths={"yaml": None, "json": None, "certificate": None},
        )
        # One shared dual-family target complements the split IPv6-primary
        # fixture used by the other methods without another consumer startup.
        value["ip_sync"]["targets"] = [
            {
                "role": "primary",
                "id": "Shared target",
                "name": "Shared",
                "families": ["ipv4", "ipv6"],
            }
        ]
        value["ddns"]["records"][0].update(
            ttl={"mode": "seconds", "value": 120}, proxied=False
        )
    elif method == "maintenance-only":
        cloud.update(
            configured=False,
            enabled=False,
            method=None,
            expected_identity={"account_id": None, "tunnel_id": None},
            credential_refs={
                "runtime": None,
                "management": None,
                "certificate": None,
                "dns": None,
            },
            paths={"yaml": None, "json": None, "certificate": None},
        )
    result = invoke(commands, tmp_path, payload(value), "check")
    assert (result.returncode, result.stderr) == (0, b"")


INVALID = [
    (("schema",), 3),
    (("cloudflared", "method"), "token|advanced"),
    (("network", "address_family"), "ipv4|ipv6"),
    (("manager", "source", "branch"), "../outside"),
    (("ddns", "enabled"), "true"),
    (("ddns", "credential_ref"), "missing"),
    (("ddns", "credential_ref"), "runtime-token"),
    (("ddns", "credentials"), None),
    (("cloudflared", "token"), None),
    (("ddns", "forced_refresh_days"), 0),
    (("ddns", "forced_refresh_days"), 1000),
    (("ddns", "primary_hostname"), "missing.test"),
    (("ddns", "ttl"), {"mode": "seconds", "value": 60}),
    (("ddns", "timeouts", "schema"), 2),
    (("ddns", "timeouts", "connect_timeout_seconds"), 10),
    (("ddns", "timeouts", "completion_timeout_seconds"), 24),
    (("ip_sync", "retry", "attempts"), 5),
    (("ip_sync", "retry", "batch_timeout_seconds"), 19),
    (("ip_sync", "targets", 1, "id"), "IPv6 target"),
    (("ip_sync", "targets", 1, "families"), ["ipv6"]),
    (("cloudflared", "expected_identity", "account_id"), "Other account"),
    (
        ("cloudflared", "expected_identity", "tunnel_id"),
        "87654321-4321-4321-4321-cba987654321",
    ),
    (("cloudflared", "paths", "json"), None),
    (("cloudflared", "paths", "certificate"), "/different"),
    (("cloudflared", "credential_refs", "certificate"), "shared-api"),
    (("cloudflared", "readiness", "command_timeout_seconds"), 1),
    (("cloudflared", "watchdog", "stability_seconds"), 59),
    (("network", "selected_wan"), "wan0"),
    (("network", "discovery", "interval_seconds"), 301),
    (("network", "discovery", "connect_timeout_seconds"), None),
    (("logging", "ddns", "policy", "size"), {"value": 10, "unit": "MiB"}),
    (("logging", "cloudflared", "policy", "compression"), False),
    (("logging", "cloudflared", "policy", "max_age_days"), 31),
    (("logging", "cloudflared", "policy", "size", "value"), 8796093022208),
    (("logging", "cloudflared", "policy", "total_files"), 2147483649),
    (("backup", "retention"), 2),
    (("backup", "date_format"), "arbitrary"),
    (("credentials", "certificate", "format"), ""),
    (("credentials", "advanced", "schema"), 2),
    (("history", "ddns", "status", "ipv4", "value"), "192.0.2.1"),
    (
        ("history", "ddns", "status", "ipv6"),
        {"result": "verified", "value": "fd00::1", "at": 1700000000},
    ),
    (("ownership", "components", 0, "generation"), 0),
    (("ownership", "migration", "schema"), 2),
    (("history", "ddns", "status", "schema"), 2),
    (("history", "ddns", "status", "observation", "running"), False),
    (("history", "ddns", "status", "latest", "reason"), "raw-secret-error"),
]


@pytest.mark.parametrize(("path", "replacement"), INVALID)
def test_invalid_authority_refuses_before_any_output(
    commands, populated, tmp_path, path, replacement
):
    value = copy.deepcopy(populated)
    target = value
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = replacement
    # A request20/connect10 pair is legal, so this case selects a lower request.
    if path == ("ddns", "timeouts", "connect_timeout_seconds"):
        value["ddns"]["timeouts"]["request_timeout_seconds"] = 5
    if path == ("history", "ddns", "status", "observation", "running"):
        value["history"]["ddns"]["status"]["observation"]["connection"] = "connected"
    original = payload(value)
    result = invoke(
        commands,
        tmp_path,
        original,
        "settings-patch",
        {
            "CFMGR_SETTINGS_MASK": "check",
            "CFMGR_SETTINGS_CHECK": "0",
            "CFMGR_SETTINGS_AUTO": "0",
        },
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")
    assert (tmp_path / "private immutable config").read_bytes() == original


@pytest.mark.parametrize(
    ("unit", "maximum"),
    [
        ("B", 9223372036854775807),
        ("KiB", 9007199254740991),
        ("MiB", 8796093022207),
        ("GiB", 8589934591),
    ],
)
def test_log_boundaries_are_exact_decimal_lexemes(
    commands, populated, tmp_path, unit, maximum
):
    value = copy.deepcopy(populated)
    policy = value["logging"]["cloudflared"]["policy"]
    policy.update(size={"value": maximum, "unit": unit}, total_files=2147483648)
    accepted = invoke(commands, tmp_path, payload(value), "check")
    assert (accepted.returncode, accepted.stderr) == (0, b"")
    policy["size"]["value"] += 1
    refused = invoke(commands, tmp_path, payload(value), "check")
    assert (refused.returncode, refused.stdout) == (1, b"")


def test_tolerant_status_privacy_and_five_event_display(commands, populated, tmp_path):
    value = copy.deepcopy(populated)
    value["ddns"].update(configured=False, enabled=True)
    value.pop("manager")
    result = project(commands, tmp_path, value)
    assert result.returncode == 0
    assert b"local schema2" in result.stdout
    assert b"invalid enabled-without-configured" in result.stdout
    assert result.stdout.count(b"Recent ") == 5
    assert SECRET.encode() not in result.stdout and b"\x1b" not in result.stdout


def test_schema2_fresh_gate_is_shared_and_rejects_configured_data(
    commands, schema2_config, populated, tmp_path
):
    fresh = invoke(commands, tmp_path, schema2_config, "fresh")
    assert (fresh.returncode, fresh.stdout, fresh.stderr) == (0, b"", b"")
    invalid = invoke(commands, tmp_path, payload(populated), "fresh")
    assert (invalid.returncode, invalid.stdout) == (1, b"")


def test_populated_store_transaction_preserves_authority(
    shell, tools, store_fixture, populated
):
    source, *_ = store_fixture
    original = payload(populated)
    (source / "config").write_bytes(original)
    result = run_store(shell, tools, store_fixture, "save", "check", "0", "0")
    assert (result.returncode, result.stderr) == (0, b"")
    assert b"CFMGR-STORE 1 saved 2 0 0 0 0 END" in result.stdout
    assert (source / "config").read_bytes() == original.replace(
        b'"generation": 1,', b'"generation": 2,', 1
    ).replace(b'"check_updates": true', b'"check_updates": false')


@pytest.mark.parametrize("scenario", ["healthy", "replace"])
def test_populated_actual_retained_launch(
    shell, tools, legacy_fsync, retained_package, populated, tmp_path, scenario
):
    value = copy.deepcopy(populated)
    value["storage"]["entware"].update(uuid=TUNNEL, root="/")
    original = payload(value)
    # This complete populated fixture executes about 188 supervised native
    # probes. A loaded older host made normal progress through publication and
    # into cleanup at the old 20s harness cap. Keep per-probe/product deadlines;
    # allow the aggregate fixture 30s, while legacy launch tests retain 20s.
    result, support = launch_host(
        shell,
        tools,
        legacy_fsync,
        retained_package,
        original,
        tmp_path,
        scenario,
        timeout=30,
    )
    assert result.returncode == 0, result.stderr
    assert b"status=0 " in result.stdout, (result.stdout, result.stderr)
    expected = original
    if scenario == "replace":
        expected = original.replace(
            b'"generation": 1,', b'"generation": 2,', 1
        ).replace(TUNNEL.encode(), b"87654321-4321-4321-4321-cba987654321", 1)
    assert (support / "config").read_bytes() == expected


def test_populated_manager_menu_save(shell, installed_settings_entry, populated):
    entry, support, *_ = installed_settings_entry
    original = payload(populated)
    (support / "config").write_bytes(original)
    result = run_entry(shell, entry, b"ao\n2\n1\ns\ny\ne\ne\ne\n")
    assert result.returncode == 0, result.stderr
    assert b"Preferences saved." in result.stdout
    changed = json.loads((support / "config").read_bytes())
    assert changed["schema"] == 2 and changed["generation"] == 2
    assert changed["credentials"] == populated["credentials"]


def test_populated_backup_menu_save(shell, installed_backup_entry, populated):
    entry, support, ram = installed_backup_entry
    (support / "config").write_bytes(payload(populated))
    result = run_entry(shell, entry, b"4\n1\n1\ns\ny\ne\ne\n")
    assert result.returncode == 0, result.stderr
    changed = json.loads((support / "config").read_bytes())
    assert changed["schema"] == 2 and changed["generation"] == 2
    assert changed["backup"]["destination"]["mountpoint"] == "/tmp/mnt/Drive one"
    assert changed["credentials"] == populated["credentials"]
    assert (ram / "Drive one/CFMgr/backup").is_dir()


@pytest.mark.parametrize(
    ("section", "key", "selected"),
    [
        (
            "network",
            "discovery",
            {
                "schema": 1,
                "interval_seconds": 300,
                "request_timeout_seconds": 20,
                "connect_timeout_seconds": 5,
            },
        ),
        ("backup", "retention", 3),
        ("backup", "date_format", "YMD"),
        ("history", "ddns", {"status": {"schema": 1, "generation": 1}}),
        (
            "ownership",
            "migration",
            {
                "schema": 1,
                "source_schema": 1,
                "source": "import",
                "state": "complete",
                "generation": 1,
            },
        ),
    ],
)
def test_fresh_refuses_selected_advisory_and_policy_data(
    commands, schema2_config, tmp_path, section, key, selected
):
    value = json.loads(schema2_config)
    value[section][key] = selected
    original = payload(value)
    assert invoke(commands, tmp_path, original, "check").returncode == 0
    refused = invoke(commands, tmp_path, original, "fresh")
    assert (refused.returncode, refused.stdout, refused.stderr) == (1, b"", b"")


def test_invalid_schema2_store_save_keeps_exact_live_data(
    shell, tools, store_fixture, populated
):
    source, *_ = store_fixture
    value = copy.deepcopy(populated)
    value["ddns"]["credential_ref"] = "runtime-token"
    original = payload(value)
    (source / "config").write_bytes(original)
    result = run_store(shell, tools, store_fixture, "save", "check", "0", "0")
    assert result.returncode != 0
    assert (source / "config").read_bytes() == original
    assert not (source / ".config-save").exists()


def test_backup_destination_extensions_survive_known_field_save(
    commands, populated, tmp_path
):
    value = copy.deepcopy(populated)
    value["backup"]["destination"] = {
        **BACKUP_DESTINATION,
        "ordinary extension": {"literal": "preserve \\ bytes", "schema": 9},
    }
    original = payload(value)
    environment = {
        "CFMGR_BACKUP_MOUNT": "/tmp/mnt/New drive",
        "CFMGR_BACKUP_UUID": BACKUP_DESTINATION["uuid"],
        "CFMGR_BACKUP_FILESYSTEM": BACKUP_DESTINATION["filesystem"],
        "CFMGR_BACKUP_ROOT": BACKUP_DESTINATION["root"],
    }
    result = invoke(commands, tmp_path, original, "backup-patch", environment)
    expected = original.replace(b'"generation": 1,', b'"generation": 2,', 1).replace(
        json.dumps(BACKUP_DESTINATION["mountpoint"]).encode(), b'"/tmp/mnt/New drive"'
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")


def test_diagnostic_projection_and_scoped_patch_preserve_unrelated_bytes(
    commands, populated, tmp_path
):
    populated["manager"]["developer"] = True
    original = payload(populated)
    path = "/tmp/mnt/CFMgr volume/captures"
    encoded = path.encode().hex()
    projected = invoke(commands, tmp_path, original, "diagnostic-read")
    assert (projected.returncode, projected.stdout, projected.stderr) == (
        0,
        b"CFMGR-DIAGNOSTIC-CONFIG 1 1 1 - END\n",
        b"",
    )
    result = settings_invoke(
        commands, tmp_path, original, "diagnostic-patch", mask=encoded
    )
    expected = original.replace(b'"generation": 1,', b'"generation": 2,', 1).replace(
        b'"developer_log_directory": null',
        b'"developer_log_directory": "/tmp/mnt/CFMgr volume/captures"',
        1,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")
    read = invoke(commands, tmp_path, expected, "diagnostic-read")
    assert read.stdout == f"CFMGR-DIAGNOSTIC-CONFIG 1 2 1 {encoded} END\n".encode()
    unchanged = settings_invoke(
        commands, tmp_path, expected, "diagnostic-patch", mask=encoded
    )
    assert (unchanged.returncode, unchanged.stdout) == (0, expected)
    restored = settings_invoke(
        commands, tmp_path, expected, "diagnostic-patch", mask="-"
    )
    assert restored.returncode == 0
    assert restored.stdout == original.replace(
        b'"generation": 1,', b'"generation": 3,', 1
    )


@pytest.mark.parametrize(
    "value",
    ["", "/", "relative", "/tmp//x", "/tmp/../x", "/tmp/x/", "/tmp/\nfoo", "/tmp/é"],
)
def test_diagnostic_patch_rejects_unsafe_lexical_path(
    commands, schema2_config, tmp_path, value
):
    result = settings_invoke(
        commands,
        tmp_path,
        schema2_config,
        "diagnostic-patch",
        mask=value.encode().hex(),
    )
    assert result.returncode != 0
    assert result.stdout == b""


def test_diagnostic_projection_marks_known_unsafe_saved_override(
    commands, config, tmp_path
):
    # The legacy schema did not validate this field as a pathname. Keep a
    # distinguishable unsafe selection; a caller must never treat it as Auto.
    data = config.replace(
        b'"developer_log_directory":null', b'"developer_log_directory":"relative"'
    )
    result = invoke(commands, tmp_path, data, "diagnostic-read")
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-DIAGNOSTIC-CONFIG 1 1 0 ! END\n",
        b"",
    )


def test_diagnostic_projection_ignores_unrelated_incomplete_settings(
    commands, tmp_path
):
    # The immutable JSON tree and manager fields remain independently checked.
    data = b'{"schema":2,"generation":7,"manager":{"developer":false,"developer_log_directory":"/tmp/mnt/drive/debug"},"ddns":null}'
    result = invoke(commands, tmp_path, data, "diagnostic-read")
    encoded = b"/tmp/mnt/drive/debug".hex().encode()
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-DIAGNOSTIC-CONFIG 1 7 0 " + encoded + b" END\n",
        b"",
    )
    invalid = data.replace(
        b'"developer_log_directory":"/tmp/mnt/drive/debug"',
        b'"developer_log_directory":42',
    )
    result = invoke(commands, tmp_path, invalid, "diagnostic-read")
    assert (result.returncode, result.stdout) == (
        0,
        b"CFMGR-DIAGNOSTIC-CONFIG 1 7 0 ! END\n",
    )
    duplicate = data.replace(
        b'"developer":false', b'"developer":false,"developer":true'
    )
    result = invoke(commands, tmp_path, duplicate, "diagnostic-read")
    assert result.returncode != 0
    assert result.stdout == b""
