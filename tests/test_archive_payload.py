"""Private archive payload plans and typed JSON envelopes."""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

from runtime_awk import awk_arguments
from test_config_observation import commands, config, schema2_config

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["commands", "config", "schema2_config"]
ACCOUNT = "Account literal"
TUNNEL = "12345678-1234-1234-1234-123456789abc"
SECRET = "fixture-private-value"
CERT_HASH = "a" * 64
SET_ID = "01234567-89ab-cdef-0123-456789abcdef"


def invoke_payload(commands, tmp_path, data: bytes, mode: str, values=None):
    environment = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("CFMGR_PAYLOAD_")
    }
    environment.update({"LC_ALL": "C", "CFMGR_PAYLOAD_MODE": mode, **(values or {})})
    arguments = [
        *commands[1],
        "-v",
        f"cfmgr_json_size={len(data)}",
        "-v",
        "cfmgr_json_mode=tree",
        "-f",
        "cfmgr-parser:json",
    ]
    if mode == "plan":
        arguments.extend(
            [
                "-v",
                "cfmgr_config_mode=archive-data",
                "-f",
                "cfmgr-parser:config_schema",
                "-f",
                "cfmgr-parser:config_observation",
            ]
        )
    arguments.extend(["-f", "cfmgr-parser:backup_payload"])
    return subprocess.run(
        awk_arguments(arguments),
        input=data,
        env=environment,
        capture_output=True,
        check=False,
        timeout=5,
    )


def serialize(value) -> bytes:
    return (json.dumps(value, separators=(",", ":")) + "\n").encode()


def plan_rows(result: subprocess.CompletedProcess[bytes]) -> list[str]:
    assert result.returncode == 0, result.stderr
    assert result.stderr == b""
    lines = result.stdout.decode("ascii").splitlines()
    assert lines and lines[0].startswith("CFMGR-PAYLOAD-PLAN 1 ")
    assert lines[-1].startswith("END ")
    assert lines[-1] == f"END {len(lines) - 1}"
    return lines


def assert_refused(result: subprocess.CompletedProcess[bytes]) -> None:
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def advanced_config(data: bytes) -> dict:
    value = json.loads(data)
    value["credentials"] = {
        "advanced": {
            "schema": 1,
            "kind": "cloudflared_json",
            "account_tag": ACCOUNT,
            "tunnel_id": TUNNEL,
            "tunnel_secret": SECRET,
        },
        "cert": {
            "schema": 1,
            "kind": "cloudflared_certificate",
            "account_id": ACCOUNT,
            "path": "/opt/etc/cloudflared/cert.pem",
            "recovery_path": "/jffs/addons/CFMgr.d/cert.pem",
            "sha256": CERT_HASH,
            "generation": 1,
            "provenance": "import",
            "format": "provider-validated-format",
        },
    }
    value["cloudflared"].update(
        configured=True,
        enabled=False,
        installed=True,
        maintenance_enabled=True,
        method="advanced",
        expected_identity={"account_id": ACCOUNT, "tunnel_id": TUNNEL},
        paths={
            "yaml": "/opt/etc/cloudflared/config.yml",
            "json": "/opt/etc/cloudflared/credentials.json",
            "certificate": "/opt/etc/cloudflared/cert.pem",
        },
        credential_refs={
            "runtime": "advanced",
            "management": None,
            "dns": None,
            "certificate": "cert",
        },
    )
    value["backup"].update(date_format="YMD", retention=3, set_id=SET_ID)
    value["logging"]["cloudflared"].update(
        configured=True,
        enabled=False,
        opt_out=False,
        policy={
            "schema": 1,
            "mode": "daily",
            "size": {"value": 10, "unit": "MiB"},
            "total_files": 5,
            "max_age_days": 30,
        },
    )
    value["ownership"]["components"] = [
        {
            "schema": 1,
            "component": "data.cloudflared.yaml",
            "path": "/opt/etc/cloudflared/config.yml",
            "generation": 1,
            "sha256": None,
        },
        {
            "schema": 1,
            "component": "data.cloudflared.json",
            "path": "/opt/etc/cloudflared/credentials.json",
            "generation": 1,
            "sha256": None,
        },
        {
            "schema": 1,
            "component": "data.cloudflared.certificate",
            "path": "/opt/etc/cloudflared/cert.pem",
            "generation": 1,
            "sha256": CERT_HASH,
        },
        {
            "schema": 1,
            "component": "data.cloudflared.certificate-recovery",
            "path": "/jffs/addons/CFMgr.d/cert.pem",
            "generation": 1,
            "sha256": CERT_HASH,
        },
        {
            "schema": 1,
            "component": "history.ddns",
            "path": "/opt/var/log/ddns.log",
            "generation": 1,
            "sha256": "b" * 64,
        },
        {
            "schema": 1,
            "component": "history-rule.ddns",
            "path": "/opt/etc/logrotate.d/cfmgr-ddns",
            "generation": 1,
            "sha256": "c" * 64,
        },
        {
            "schema": 1,
            "component": "data.setup-drafts",
            "path": "/jffs/addons/CFMgr.d/setup-drafts",
            "generation": 1,
            "sha256": "d" * 64,
        },
        {
            "schema": 1,
            "component": "data.cloudflared.input.ca_bundle",
            "path": "/opt/etc/cloudflared/ca.pem",
            "generation": 1,
            "sha256": "e" * 64,
        },
        {
            "schema": 1,
            "component": "data.cloudflared.yaml-backup",
            "path": "/opt/etc/cloudflared/config.yml.bak",
            "generation": 1,
            "sha256": "f" * 64,
        },
        {
            "schema": 1,
            "component": "history.cloudflared",
            "path": "/opt/var/log/cloudflared.log",
            "generation": 1,
            "sha256": "1" * 64,
        },
        {
            "schema": 1,
            "component": "history-rule.cloudflared",
            "path": "/opt/etc/logrotate.d/cfmgr-cloudflared",
            "generation": 1,
            "sha256": "2" * 64,
        },
    ]
    return value


def make_plan(commands, tmp_path, data: bytes) -> bytes:
    result = invoke_payload(commands, tmp_path, data, "plan")
    plan_rows(result)
    return result.stdout


def invoke_index(
    commands, tmp_path, plan: bytes, yaml: bytes | None, *, limit="1048576"
):
    plan_path = tmp_path / "private capture plan"
    plan_path.write_bytes(plan)
    plan_path.chmod(0o600)
    yaml_path = "-"
    if yaml is not None:
        receipt_path = tmp_path / "private YAML receipt"
        receipt_path.write_bytes(yaml)
        receipt_path.chmod(0o600)
        yaml_path = str(receipt_path)
    return subprocess.run(
        awk_arguments(
            [
                *commands[1],
                "-f",
                "cfmgr-parser:backup_payload_index",
                str(plan_path),
                yaml_path,
            ]
        ),
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_PAYLOAD_INDEX_LIMIT": limit,
        },
        capture_output=True,
        check=False,
        timeout=5,
    )


def capture_rows(result: subprocess.CompletedProcess[bytes]) -> list[str]:
    assert (result.returncode, result.stderr) == (0, b""), result.stderr
    rows = result.stdout.decode("ascii").splitlines()
    assert rows and rows[0].startswith("CFMGR-CAPTURE-PLAN 1 ")
    assert rows[-1] == f"END {len(rows) - 1}"
    return rows


def yaml_receipt(json_path: str, identity: str, inputs=(), controls=()) -> bytes:
    rows = ["CFMGR-YAML 1", f"IDENTITY {identity} {json_path.encode().hex()}"]
    rows.extend(
        f"INPUT {i} origincert {path.encode().hex()}"
        for i, path in enumerate(inputs, 1)
    )
    rows.extend(f"CONTROL {name} {path.encode().hex()}" for name, path in controls)
    rows.append(f"END {len(inputs)} {len(controls)}")
    return ("\n".join(rows) + "\n").encode()


def token_config(data: bytes) -> dict:
    value = json.loads(data)
    value["credentials"] = {
        "runtime-token": {"schema": 1, "kind": "cloudflared_token", "value": SECRET}
    }
    value["cloudflared"].update(
        configured=True,
        enabled=False,
        installed=True,
        maintenance_enabled=False,
        method="token",
        credential_refs={
            "runtime": "runtime-token",
            "management": None,
            "dns": None,
            "certificate": None,
        },
    )
    return value


def test_plan_includes_fresh_native_config_without_live_file_dependencies(
    commands, schema2_config, tmp_path
) -> None:
    lines = plan_rows(invoke_payload(commands, tmp_path, schema2_config, "plan"))
    assert lines[:5] == [
        "CFMGR-PAYLOAD-PLAN 1 2 1",
        f"FILE manager.config required {b'/jffs/addons/CFMgr.d/config'.hex()} 1 -",
        f"FILE manager.catalog required {b'/jffs/addons/CFMgr.d/catalog.txt'.hex()} 1 -",
        (
            "STORAGE 01234567-89ab-cdef-0123-456789abcdef ext4 "
            f"{b'/mnt/usb'.hex()} {b'entware'.hex()}"
        ),
        "STATE ddns 0 0",
    ]
    assert "STATE ip_sync 0 0" in lines
    assert "STATE cloudflared 0 0" in lines
    assert not any(
        line.startswith(("AUTH ", "CERT ", "FILE data.cloudflared.")) for line in lines
    )


def test_plan_rejects_configured_legacy_but_preserves_unconfigured_legacy(
    commands, config, tmp_path
) -> None:
    lines = plan_rows(invoke_payload(commands, tmp_path, config, "plan"))
    assert "LEGACY unconfigured END" in lines
    assert lines[-1].startswith("END ")
    legacy = json.loads(config)
    legacy["ddns"]["configured"] = True
    assert_refused(invoke_payload(commands, tmp_path, serialize(legacy), "plan"))


def test_token_mode_needs_no_yaml_or_certificate_and_keeps_token_opaque(
    commands, schema2_config, tmp_path
) -> None:
    value = token_config(schema2_config)
    lines = plan_rows(invoke_payload(commands, tmp_path, serialize(value), "plan"))
    cloud = next(line for line in lines if line.startswith("CLOUD "))
    assert cloud.startswith("CLOUD token 1 0 1 0 ")
    assert "runtime-token" not in "\n".join(lines)
    assert SECRET.encode() not in "\n".join(lines).encode()
    assert not any(
        line.startswith(
            ("FILE data.cloudflared.yaml ", "FILE data.cloudflared.json ", "CERT ")
        )
        for line in lines
    )


def test_advanced_plan_validates_typed_credentials_and_owned_paths(
    commands, schema2_config, tmp_path
) -> None:
    value = advanced_config(schema2_config)
    lines = plan_rows(invoke_payload(commands, tmp_path, serialize(value), "plan"))
    expected_owners = {
        "OWNER data.cloudflared.yaml "
        + b"/opt/etc/cloudflared/config.yml".hex()
        + " 1 -",
        "OWNER data.cloudflared.json "
        + b"/opt/etc/cloudflared/credentials.json".hex()
        + " 1 -",
        "OWNER data.cloudflared.certificate "
        + b"/opt/etc/cloudflared/cert.pem".hex()
        + f" 1 {CERT_HASH}",
        "OWNER data.cloudflared.certificate-recovery "
        + b"/jffs/addons/CFMgr.d/cert.pem".hex()
        + f" 1 {CERT_HASH}",
        "OWNER history.ddns " + b"/opt/var/log/ddns.log".hex() + " 1 " + "b" * 64,
        "OWNER history-rule.ddns "
        + b"/opt/etc/logrotate.d/cfmgr-ddns".hex()
        + " 1 "
        + "c" * 64,
        "OWNER data.setup-drafts "
        + b"/jffs/addons/CFMgr.d/setup-drafts".hex()
        + " 1 "
        + "d" * 64,
    }
    assert expected_owners <= set(lines)
    assert (
        f"AUTH {b'advanced'.hex()} json {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()}"
        in lines
    )
    assert (
        "CERT " + b"cert".hex() + " " + ACCOUNT.encode().hex() + f" 1 {CERT_HASH}"
        in lines
    )
    assert (
        f"FILE data.cloudflared.certificate-recovery optional {b'/jffs/addons/CFMgr.d/cert.pem'.hex()} 1 {CERT_HASH}"
        in lines
    )
    assert SECRET.encode() not in "\n".join(lines).encode()

    invalid = advanced_config(schema2_config)
    invalid["ownership"]["components"][0]["path"] = "/etc/passwd"
    assert_refused(invoke_payload(commands, tmp_path, serialize(invalid), "plan"))


def test_runtime_json_requires_exact_private_authority_and_rejects_case_ambiguity(
    commands, tmp_path
) -> None:
    document = serialize(
        {"AccountTag": ACCOUNT, "TunnelID": TUNNEL, "TunnelSecret": SECRET}
    )
    authority = tmp_path / "private authority"
    authority.write_text(
        f"CFMGR-AUTH 1 {b'runtime-ref'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()} END\n"
    )
    authority.chmod(0o600)
    result = invoke_payload(
        commands,
        tmp_path,
        document,
        "runtime-json",
        {"CFMGR_PAYLOAD_AUTHORITY": str(authority)},
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-PAYLOAD 1 runtime-json matched END\n",
        b"",
    )
    assert SECRET.encode() not in result.stdout

    bad_authority = authority.read_text().replace(TUNNEL, TUNNEL.upper())
    authority.write_text(bad_authority)
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            document,
            "runtime-json",
            {"CFMGR_PAYLOAD_AUTHORITY": str(authority)},
        )
    )
    authority.write_text(
        f"CFMGR-AUTH 1 {b'runtime-ref'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {b'wrong-secret'.hex()} END\n"
    )
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            document,
            "runtime-json",
            {"CFMGR_PAYLOAD_AUTHORITY": str(authority)},
        )
    )
    authority.write_text(
        f"CFMGR-AUTH 1 {b'runtime-ref'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()} END\nextra\n"
    )
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            document,
            "runtime-json",
            {"CFMGR_PAYLOAD_AUTHORITY": str(authority)},
        )
    )
    ambiguous = (
        b'{"AccountTag":"Account literal","accounttag":"other",'
        b'"TunnelID":"12345678-1234-1234-1234-123456789abc",'
        b'"TunnelSecret":"fixture-private-value"}\n'
    )
    authority.write_text(
        f"CFMGR-AUTH 1 {b'runtime-ref'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()} END\n"
    )
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            ambiguous,
            "runtime-json",
            {"CFMGR_PAYLOAD_AUTHORITY": str(authority)},
        )
    )


def test_certificate_json_matches_account_and_never_receipts_api_token(
    commands, tmp_path
) -> None:
    api_token = "private-api-token-fixture"
    document = serialize(
        {
            "zoneID": "zone-id",
            "accountID": ACCOUNT,
            "apiToken": api_token,
            "endpoint": "https://api.example.test",
        }
    )
    result = invoke_payload(
        commands,
        tmp_path,
        document,
        "certificate-json",
        {"CFMGR_PAYLOAD_ACCOUNT_HEX": ACCOUNT.encode().hex()},
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-PAYLOAD 1 certificate-json matched END\n",
        b"",
    )
    assert api_token.encode() not in result.stdout
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            document,
            "certificate-json",
            {"CFMGR_PAYLOAD_ACCOUNT_HEX": b"other-account".hex()},
        )
    )
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            serialize(
                {
                    "zoneID": "zone",
                    "accountID": ACCOUNT,
                    "apiToken": api_token,
                    "endpoint": 1,
                }
            ),
            "certificate-json",
            {"CFMGR_PAYLOAD_ACCOUNT_HEX": ACCOUNT.encode().hex()},
        )
    )


def test_drafts_accept_only_inert_ddns_ip_sync_envelopes_and_matching_generation(
    commands, tmp_path
) -> None:
    document = serialize(
        {
            "schema": 1,
            "generation": 7,
            "drafts": {
                "ddns": {
                    "schema": 1,
                    "stage": "review",
                    "inputs": {"hostname": "example.test"},
                    "validation": {"valid": True},
                },
                "ip_sync": None,
            },
        }
    )
    expected = b"CFMGR-PAYLOAD 1 drafts inert END\n"
    result = invoke_payload(
        commands, tmp_path, document, "drafts", {"CFMGR_PAYLOAD_GENERATION": "7"}
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")
    assert_refused(
        invoke_payload(
            commands, tmp_path, document, "drafts", {"CFMGR_PAYLOAD_GENERATION": "8"}
        )
    )
    invalid = json.loads(document)
    invalid["drafts"]["cloudflared"] = None
    assert_refused(
        invoke_payload(
            commands,
            tmp_path,
            serialize(invalid),
            "drafts",
            {"CFMGR_PAYLOAD_GENERATION": "7"},
        )
    )


def test_payload_index_token_plan_needs_no_yaml_receipt(
    commands, schema2_config, tmp_path
) -> None:
    plan = make_plan(commands, tmp_path, serialize(token_config(schema2_config)))
    rows = capture_rows(invoke_index(commands, tmp_path, plan, None))
    assert rows[:4] == [
        "CFMGR-CAPTURE-PLAN 1 2 1",
        "BACKUP - 0 -",
        f"FILE manager.config required jffs {b'addons/CFMgr.d/config'.hex()} 1 - whole",
        f"FILE manager.catalog required jffs {b'addons/CFMgr.d/catalog.txt'.hex()} 1 - whole",
    ]
    assert "NOTE data.setup-drafts not_applicable - no-owned-data END" in rows
    assert (
        "NOTE data.cloudflared.yaml-backup not_applicable - no-owned-data END" in rows
    )
    assert not any(
        row.startswith(("AUTH ", "HISTORY ", "FILE data.cloudflared.yaml "))
        for row in rows
    )


def test_payload_index_joins_advanced_yaml_owned_and_external_inputs(
    commands, schema2_config, tmp_path
) -> None:
    value = advanced_config(schema2_config)
    plan = make_plan(commands, tmp_path, serialize(value))
    yaml = yaml_receipt(
        "/opt/etc/cloudflared/credentials.json",
        TUNNEL,
        inputs=(
            "/opt/etc/cloudflared/cert.pem",
            "/jffs/addons/CFMgr.d/cert.pem",
            "/opt/etc/cloudflared/external/ca.pem",
            "/opt/etc/cloudflared/ca.pem",
        ),
        controls=(("logfile", "/opt/var/log/cloudflared.log"),),
    )
    rows = capture_rows(invoke_index(commands, tmp_path, plan, yaml))
    assert "BACKUP YMD 3 " + SET_ID in rows
    assert (
        f"FILE data.cloudflared.yaml required entware {b'etc/cloudflared/config.yml'.hex()} 1 - whole"
        in rows
    )
    assert (
        f"FILE data.cloudflared.json required entware {b'etc/cloudflared/credentials.json'.hex()} 1 - whole"
        in rows
    )
    assert (
        f"FILE data.cloudflared.input.ca_bundle required entware {b'etc/cloudflared/ca.pem'.hex()} 1 {'e' * 64} whole"
        in rows
    )
    assert (
        f"EXTERNAL data.cloudflared.yaml {b'/opt/etc/cloudflared/external/ca.pem'.hex()} input-reference"
        in rows
    )
    assert not any(
        b"external/ca.pem".hex() in row and row.startswith("FILE ") for row in rows
    )
    assert (
        f"NOTE data.cloudflared.yaml external {b'/opt/var/log/cloudflared.log'.hex()} output-reference END"
        in rows
    )
    assert (
        f"AUTH {b'advanced'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()}"
        in rows
    )
    assert f"CERT {b'cert'.hex()} {ACCOUNT.encode().hex()} 1 {CERT_HASH}" in rows
    assert (
        f"FILE data.setup-drafts required jffs {b'addons/CFMgr.d/setup-drafts'.hex()} 1 {'d' * 64} whole"
        in rows
    )
    assert (
        f"FILE data.cloudflared.yaml-backup required entware {b'etc/cloudflared/config.yml.bak'.hex()} 1 {'f' * 64} whole"
        in rows
    )
    assert (
        f"HISTORY history.cloudflared {b'/opt/var/log/cloudflared.log'.hex()} 1" in rows
    )

    missing_rule = json.loads(serialize(value))
    missing_rule["ownership"]["components"] = [
        item
        for item in missing_rule["ownership"]["components"]
        if item["component"] != "history-rule.cloudflared"
    ]
    plan = make_plan(commands, tmp_path, serialize(missing_rule))
    no_history = capture_rows(invoke_index(commands, tmp_path, plan, yaml))
    assert not any(row.startswith("HISTORY ") for row in no_history)

    opted_out = json.loads(serialize(value))
    opted_out["logging"]["cloudflared"]["opt_out"] = True
    plan = make_plan(commands, tmp_path, serialize(opted_out))
    no_history = capture_rows(invoke_index(commands, tmp_path, plan, yaml))
    assert not any(row.startswith("HISTORY ") for row in no_history)


def test_payload_index_rejects_wrong_yaml_identity_and_json_path(
    commands, schema2_config, tmp_path
) -> None:
    plan = make_plan(commands, tmp_path, serialize(advanced_config(schema2_config)))
    wrong_path = yaml_receipt("/opt/etc/cloudflared/other.json", TUNNEL)
    assert_refused(invoke_index(commands, tmp_path, plan, wrong_path))
    wrong_uuid = yaml_receipt(
        "/opt/etc/cloudflared/credentials.json",
        "87654321-4321-4321-4321-cba987654321",
    )
    assert_refused(invoke_index(commands, tmp_path, plan, wrong_uuid))


def test_payload_index_rejects_ambiguous_inactive_authorities(
    commands, schema2_config, tmp_path
) -> None:
    value = json.loads(schema2_config)
    value["cloudflared"]["paths"] = {
        "yaml": "/opt/etc/cloudflared/config.yml",
        "json": "/opt/etc/cloudflared/credentials.json",
        "certificate": None,
    }
    value["credentials"] = {
        "inactive-a": {
            "schema": 1,
            "kind": "cloudflared_json",
            "account_tag": "account-a",
            "tunnel_id": TUNNEL,
            "tunnel_secret": "secret-a",
        },
        "inactive-b": {
            "schema": 1,
            "kind": "cloudflared_json",
            "account_tag": "account-b",
            "tunnel_id": TUNNEL,
            "tunnel_secret": "secret-b",
        },
    }
    value["ownership"]["components"] = [
        {
            "schema": 1,
            "component": "data.cloudflared.yaml",
            "path": "/opt/etc/cloudflared/config.yml",
            "generation": 1,
            "sha256": None,
        },
        {
            "schema": 1,
            "component": "data.cloudflared.json",
            "path": "/opt/etc/cloudflared/credentials.json",
            "generation": 1,
            "sha256": None,
        },
    ]
    plan = make_plan(commands, tmp_path, serialize(value))
    yaml = yaml_receipt("/opt/etc/cloudflared/credentials.json", TUNNEL)
    assert_refused(invoke_index(commands, tmp_path, plan, yaml))


def test_payload_index_rejects_bad_plan_yaml_terminal_and_output_limit(
    commands, schema2_config, tmp_path
) -> None:
    plan = make_plan(commands, tmp_path, schema2_config)
    rows = plan.decode().splitlines()
    backup_index = next(i for i, row in enumerate(rows) if row.startswith("BACKUP "))
    bad_metadata = rows.copy()
    bad_metadata[backup_index] = "BACKUP YMD 3"
    assert_refused(
        invoke_index(
            commands, tmp_path, ("\n".join(bad_metadata) + "\n").encode(), None
        )
    )

    bad_terminal = rows.copy()
    bad_terminal[-1] = "END 999"
    assert_refused(
        invoke_index(
            commands, tmp_path, ("\n".join(bad_terminal) + "\n").encode(), None
        )
    )
    assert_refused(invoke_index(commands, tmp_path, plan, None, limit="1"))

    malformed_yaml = yaml_receipt(
        "/opt/etc/cloudflared/credentials.json", TUNNEL
    ).replace(b"END 0 0\n", b"END 0 1\n")
    advanced_plan = make_plan(
        commands, tmp_path, serialize(advanced_config(schema2_config))
    )
    assert_refused(invoke_index(commands, tmp_path, advanced_plan, malformed_yaml))


def test_payload_index_upgrades_selected_certificate_for_non_origincert_input(
    commands, schema2_config, tmp_path
) -> None:
    cases = (
        ("/opt/etc/cloudflared/cert.pem", "origincert", "cacert"),
        ("/opt/etc/cloudflared/cert.pem", "cacert", "origincert"),
        ("/jffs/addons/CFMgr.d/cert.pem", "origincert", "caPool"),
        ("/jffs/addons/CFMgr.d/cert.pem", "caPool", "origincert"),
    )
    for selected_path, first_role, second_role in cases:
        value = advanced_config(schema2_config)
        value["ownership"]["components"] = [
            row
            for row in value["ownership"]["components"]
            if row["component"]
            in {
                "data.cloudflared.yaml",
                "data.cloudflared.json",
                "data.cloudflared.certificate",
                "data.cloudflared.certificate-recovery",
            }
        ]
        config_plan = make_plan(commands, tmp_path, serialize(value))
        yaml = (
            yaml_receipt(
                "/opt/etc/cloudflared/credentials.json",
                TUNNEL,
                inputs=(selected_path, selected_path),
            )
            .replace(b" 1 origincert ", f" 1 {first_role} ".encode())
            .replace(b" 2 origincert ", f" 2 {second_role} ".encode())
        )
        capture = invoke_index(commands, tmp_path, config_plan, yaml)
        rows = capture_rows(capture)
        target = (
            "data.cloudflared.certificate"
            if selected_path.startswith("/opt/")
            else "data.cloudflared.certificate-recovery"
        )
        target_row = next(row for row in rows if row.startswith(f"FILE {target} "))
        assert target_row.split()[2] == "required", (first_role, second_role, rows)

        # Both certificate files are absent in this candidate. A non-origincert
        # INPUT must have upgraded the selected row, so the optional absence
        # receipt cannot satisfy the semantic join.
        inventory_rows = []
        files = total = 0
        for row in rows[2:-1]:
            fields = row.split()
            if fields[0] == "FILE":
                _, role, _need, scope, pathhex, generation, digest, _capture = fields
                if role.startswith("data.cloudflared.certificate"):
                    inventory_rows.append(f"NOTE {role} absent {pathhex} absent END")
                    continue
                files += 1
                inventory_rows.append(
                    f"FILE p{files:08d} {role} {scope} {pathhex} {generation} 0600 1 {'d' * 64 if digest == '-' else digest} whole"
                )
                total += 1
            elif fields[0] == "NOTE":
                inventory_rows.append(row)
        inventory = (
            "CFMGR-INVENTORY 1\n"
            + "\n".join(inventory_rows)
            + f"\nEND {files} {len(inventory_rows) - files} {total}\n"
        ).encode()
        capture_path = tmp_path / "capture-plan"
        inventory_path = tmp_path / "inventory"
        capture_path.write_bytes(capture.stdout)
        inventory_path.write_bytes(inventory)
        match = subprocess.run(
            awk_arguments(
                [
                    *commands[1],
                    "-f",
                    "cfmgr-parser:backup_payload_match",
                    str(capture_path),
                    str(inventory_path),
                ]
            ),
            env={**os.environ, "LC_ALL": "C"},
            capture_output=True,
            check=False,
            timeout=5,
        )
        assert_refused(match)
