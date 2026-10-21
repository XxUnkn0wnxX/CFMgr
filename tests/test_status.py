"""Native-only status projection and actual installed choice0 consumer.

No live router/provider input. Host supervision adapters are labelled; one Linux
case retains the actual bounded supervisor and fixed executable probe body.
"""

from __future__ import annotations

import hashlib
import ipaddress
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import pytest
from entry_package_fixture import adapt_native, finish_package, full_health_package
from runtime_awk import awk_arguments, awk_program
from test_config_observation import commands, config, schema2_config
from test_dependency_reinstall import entry_run, installed_entry
from test_entry_package import installed_package as _installed_package_fixture
from test_install import package as _package_fixture
from test_install import shell, tools
from test_prerequisites import pause_definition

package = _package_fixture
installed_package = _installed_package_fixture

ROOT = Path(__file__).resolve().parents[1]
BOOT = "12345678-1234-1234-1234-123456789abc"
NOW = 1_700_000_000
__all__ = ["commands", "config", "installed_entry", "schema2_config", "shell", "tools"]


HEALTH_SECRET = "cfut_fixture-secret_CANARY-123"
ZONE = "a" * 32
ACCOUNT = "b" * 32
LIST = "c" * 32


def test_health_backup_projection_keeps_history_private(commands, schema2_config):
    value = json.loads(schema2_config)
    value["backup"]["destination"] = {
        "schema": 1,
        "mountpoint": "/tmp/mnt/private-drive",
        "uuid": "abcd-1234",
        "filesystem": "vfat",
        "root": "/",
    }
    value["backup"]["set_id"] = BOOT
    value["backup"]["last_backup"] = {
        "schema": 1,
        "at": NOW - 30,
        "set_id": BOOT,
        "archive_id": BOOT,
        "generation": value["generation"],
        "date_format": "YMD",
        "local_date": "private-date-CANARY",
        "local_time": "private-time-CANARY",
        "timezone": "UTC",
    }
    for clock, at, expected_age in (
        ("1", NOW - 30, "30"),
        ("0", NOW - 30, "unknown"),
        ("1", NOW + 1, "unknown"),
    ):
        value["backup"]["last_backup"]["at"] = at
        data = json.dumps(value).encode()
        result = subprocess.run(
            [
                *commands[1],
                "-v",
                f"cfmgr_json_size={len(data)}",
                "-v",
                "cfmgr_json_mode=tree",
                "-v",
                "cfmgr_config_mode=archive-data",
                awk_program(
                    "json", "config_schema", "config_observation", "health_backup_plan"
                ),
            ],
            input=data,
            capture_output=True,
            check=False,
            timeout=3,
            env={
                **os.environ,
                "LC_ALL": "C",
                "CFMGR_HEALTH_BACKUP_NOW": str(NOW),
                "CFMGR_HEALTH_BACKUP_CLOCK": clock,
            },
        )
        assert (result.returncode, result.stderr) == (0, b"")
        assert (
            f"HISTORY\trecorded\t{expected_age}\tsame-set\n".encode() in result.stdout
        )
        assert (
            b"private-date-CANARY" not in result.stdout
            and b"private-time-CANARY" not in result.stdout
        )
        assert BOOT.encode() not in result.stdout


@pytest.mark.parametrize(
    "filesystem,kind,identity",
    [("tfat", "vfat", "ABCD-1234"), ("ufsd", "ntfs", "0123456789ABCDEF")],
)
def test_health_backup_worker_reuses_broad_uuid_policy(
    shell, tools, tmp_path, filesystem, kind, identity
):
    private = tmp_path / "private"
    private.mkdir()
    observed = private / "health-blkid.1.out"
    observed.write_text(f'/dev/fixture: UUID="{identity}" TYPE="{kind}"\n')
    result = subprocess.run(
        [
            *shell,
            ROOT / "modules/helpers/worker.sh",
            "health-backup-uuid",
            adapt_native("/usr/bin/awk", tmp_path / "jffs", tools, shell),
            private,
            ROOT / "modules/backup.sh",
            observed,
            "/dev/fixture",
            filesystem,
        ],
        capture_output=True,
        check=False,
        timeout=3,
        env={**os.environ, "LC_ALL": "C"},
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        identity.lower().encode() + b"\n-\n",
        b"",
    )


@pytest.mark.parametrize(
    "damage", ["none", "missing-folder", "mount-replaced", "unresolved"]
)
def test_health_backup_actual_worker_identity_and_readonly_limits(
    shell, tools, tmp_path, damage
):
    """Actual private worker/parsers; mount, device and canonical facts are fixtures.

    The full Linux entry journey separately exercises real supervision and caps.
    This small case proves refusal after replacement and unresolved propagation.
    """
    private = tmp_path / "private"
    private.mkdir()
    point = tmp_path / "selected-drive"
    point.mkdir()
    if damage != "missing-folder":
        (point / "CFBackup").mkdir()
    plan = private / "health-backup-plan.1.out"
    plan.write_text(
        f"CFMGR-HEALTH-BACKUP\t1\nDESTINATION\t1\t{point}\nIDENTITY\tabcd-1234\ttfat\t/\nHISTORY\tnever\tunknown\tunknown\nEND\t4\n"
    )
    script = r"""
root=$1 base=$2 selected_sh=$3 selected_awk=$4 selected_ls=$5 damage=$6
. "$root/modules/status.sh"
cfmgr_source=$root cfmgr_status_context=$base/private cfmgr_health_backup=verified
cfmgr_health_backup_plan=$base/private/health-backup-plan.1.out
cfmgr_health_backup_point=$base/selected-drive cfmgr_health_backup_state=UNKNOWN
serial=1 mounts=0
cfmgr_health_canonical() { cfmgr_health_resolved=$1; }
cfmgr_health_run() {
    mode=$1; shift 2
    serial=$((serial + 1))
    cfmgr_probe_stdout=$cfmgr_status_context/$mode.$serial.out
    cfmgr_probe_stderr=$cfmgr_status_context/$mode.$serial.err
    cfmgr_probe_exit=0
    : >"$cfmgr_probe_stdout"; : >"$cfmgr_probe_stderr"
    case $mode in
    health-mount)
        mounts=$((mounts + 1))
        [ "$damage" != unresolved ] || return 3
        mount_id=8
        [ "$damage:$mounts" != mount-replaced:2 ] || mount_id=9
        printf '%s\t1\t8:1\t/\t%s\ttfat\t/dev/fixture\tro,noexec\tro\n' "$mount_id" "$cfmgr_health_backup_point" >"$cfmgr_probe_stdout"
        ;;
    health-blkid) printf '%s\n' '/dev/fixture: UUID="ABCD-1234" TYPE="vfat"' >"$cfmgr_probe_stdout" ;;
    health-metadata) "$selected_ls" -ildn "$1" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr" || cfmgr_probe_exit=$? ;;
    *) "$selected_sh" "$root/modules/helpers/worker.sh" "$mode" "$selected_awk" "$cfmgr_status_context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr" || cfmgr_probe_exit=$? ;;
    esac
    return 0
}
if cfmgr_health_backup_observe; then result=0; else result=$?; fi
printf '%s %s %s %s %s\n' "$result" "$cfmgr_health_backup_state" "${cfmgr_health_backup_access:-unknown}" "${cfmgr_health_backup_folder:-unverified}" "$mounts"
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "backup-health",
            ROOT,
            tmp_path,
            tools["sh"],
            adapt_native("/usr/bin/awk", tmp_path / "jffs", tools, shell),
            adapt_native("/bin/ls", tmp_path / "jffs", tools, shell),
            damage,
        ],
        capture_output=True,
        check=False,
        timeout=5,
        env={**os.environ, "LC_ALL": "C"},
    )
    assert (result.returncode, result.stderr) == (0, b"")
    expected = {
        "none": b"0 PASS ro observed 3\n",
        "missing-folder": b"0 PASS ro unverified 3\n",
        "mount-replaced": b"1 UNKNOWN ro unverified 2\n",
        "unresolved": b"3 UNKNOWN unknown unverified 1\n",
    }
    assert result.stdout == expected[damage]


@pytest.fixture(scope="module")
def health_config(schema2_config):
    value = json.loads(schema2_config)
    value["credentials"] = {
        "api-a": {"schema": 1, "kind": "cloudflare_api_token", "value": HEALTH_SECRET},
        "api-b": {"schema": 1, "kind": "cloudflare_api_token", "value": HEALTH_SECRET},
        "runtime": {
            "schema": 1,
            "kind": "cloudflared_token",
            "value": "runtime-CANARY",
        },
    }
    value["ddns"].update(
        configured=True,
        credential_ref="api-a",
        zone_id=ZONE,
        primary_hostname="example.test",
        records=[
            {"id": "local-record-4", "name": "example.test", "type": "A"},
            {"id": "local-record-6", "name": "*.example.test", "type": "AAAA"},
        ],
        ttl={"mode": "auto"},
        proxied=True,
    )
    value["ip_sync"].update(
        configured=True,
        credential_ref="api-b",
        account_id=ACCOUNT,
        targets=[
            {"role": "primary", "id": LIST, "name": "owned-list", "families": ["ipv4"]}
        ],
    )
    value["cloudflared"].update(
        configured=True,
        method="token",
        credential_refs={
            "runtime": "runtime",
            "management": "api-b",
            "dns": None,
            "certificate": None,
        },
        expected_identity={"account_id": ACCOUNT, "tunnel_id": BOOT},
    )
    return value


def health_projection(
    commands,
    value,
    mode="health-scope",
    *,
    feature="ddns",
    kind="dns",
    selector="local-record-4",
    family="4",
    public="0",
    ipv6="0",
):
    payload = json.dumps(value).encode()
    return subprocess.run(
        [
            *commands[1],
            "-v",
            f"cfmgr_json_size={len(payload)}",
            "-v",
            "cfmgr_json_mode=tree",
            "-v",
            "cfmgr_config_mode=archive-data",
            awk_program("json", "config_schema", "config_observation", "health"),
        ],
        input=payload,
        capture_output=True,
        check=False,
        timeout=3,
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_HEALTH_MODE": mode,
            "CFMGR_HEALTH_FEATURE": feature,
            "CFMGR_HEALTH_KIND": kind,
            "CFMGR_HEALTH_SELECTOR": selector,
            "CFMGR_HEALTH_FAMILY": family,
            "CFMGR_HEALTH_PUBLIC": public,
            "CFMGR_HEALTH_IPV6": ipv6,
        },
    )


@pytest.mark.parametrize(
    "feature,kind,selector,suffix",
    [
        ("ddns", "zone", "-", f"zones/{ZONE}"),
        (
            "ddns",
            "dns",
            "local-record-4",
            f"zones/{ZONE}/dns_records?name=example.test&type=A&per_page=50",
        ),
        (
            "ddns",
            "dns",
            "local-record-6",
            f"zones/{ZONE}/dns_records?name=%2A.example.test&type=AAAA&per_page=50",
        ),
        ("ip_sync", "list", "primary", f"accounts/{ACCOUNT}/rules/lists/{LIST}"),
        (
            "ip_sync",
            "items",
            "primary",
            f"accounts/{ACCOUNT}/rules/lists/{LIST}/items?per_page=50",
        ),
        ("cloudflared", "tunnel", "-", f"accounts/{ACCOUNT}/cfd_tunnel/{BOOT}"),
        (
            "cloudflared",
            "connections",
            "-",
            f"accounts/{ACCOUNT}/cfd_tunnel/{BOOT}/connections",
        ),
    ],
)
def test_health_private_projection_uses_configured_resource_and_safe_request(
    commands, health_config, feature, kind, selector, suffix
):
    selected = {"feature": feature, "kind": kind, "selector": selector}
    scope = health_projection(commands, health_config, **selected)
    request = health_projection(commands, health_config, "health-request", **selected)
    assert scope.returncode == request.returncode == 0, (scope.stderr, request.stderr)
    assert scope.stderr == request.stderr == b""
    assert HEALTH_SECRET.encode() not in scope.stdout
    assert b" eligible " in scope.stdout
    assert int(scope.stdout.split()[9]) == len(request.stdout)
    assert (
        request.stdout
        == (
            f'url = "https://api.cloudflare.com/client/v4/{suffix}"\nheader = "Authorization: Bearer {HEALTH_SECRET}"\n'
        ).encode()
    )
    assert (
        b"tokens/verify" not in request.stdout
        and b"local-record-" not in request.stdout
    )


@pytest.mark.parametrize(
    "token,allowed",
    [
        ("legacy-token", True),
        ("cfat_current-token", True),
        ("A" * 2048, True),
        ("A" * 2049, False),
        ('unsafe"quote', False),
        ("unsafe\\escape", False),
        ("white space", False),
    ],
    ids=["legacy", "prefixed", "maximum", "oversize", "quote", "backslash", "space"],
)
def test_health_token_grammar_fails_closed_without_public_secret(
    commands, health_config, token, allowed
):
    value = json.loads(json.dumps(health_config))
    value["credentials"]["api-a"]["value"] = token
    scope = health_projection(commands, value)
    request = health_projection(commands, value, "health-request")
    assert scope.returncode == 0
    assert token.encode() not in scope.stdout
    assert (request.returncode == 0) == allowed
    if not allowed:
        assert b" credential-local-only " in scope.stdout and request.stdout == b""


@pytest.mark.parametrize(
    "case,expected",
    [
        ("absent", "eligible"),
        ("latest-auth", "historical-auth"),
        ("latest-throttle", "historical-throttle"),
        ("latest-none", "eligible"),
        ("latest-null", "historical-auth"),
        ("event-auth", "historical-auth"),
        ("sixth-auth", "historical-auth"),
        ("unknown-extension", "eligible"),
        ("malformed", None),
    ],
)
def test_health_historical_hold_map_is_explicit_and_never_current_auth(
    commands, health_config, case, expected
):
    value = json.loads(json.dumps(health_config))
    event = {"result": "failed", "reason": "auth", "at": NOW}
    status = {"schema": 1, "generation": 1}
    if case.startswith("latest-"):
        reason = case.removeprefix("latest-")
        status["latest"] = None if reason == "null" else {**event, "reason": reason}
        status["events"] = [event]
    elif case == "event-auth":
        status["events"] = [event]
    elif case == "sixth-auth":
        status["events"] = [{**event, "reason": "none"}] * 5 + [event]
    elif case == "unknown-extension":
        status["unrelated"] = {"auth": "invalid", "token": HEALTH_SECRET}
    elif case == "malformed":
        status["latest"] = {"reason": "auth"}
    if case != "absent":
        value["history"]["ddns"] = {"status": status}
    result = health_projection(commands, value)
    if expected is None:
        assert result.returncode != 0 and result.stdout == b""
    else:
        assert result.returncode == 0 and result.stdout.split()[2].decode() == expected
    assert HEALTH_SECRET.encode() not in result.stdout + result.stderr
    # A different feature retains its own history decision when authority is valid.
    other = health_projection(
        commands, value, feature="ip_sync", kind="list", selector="primary"
    )
    assert (other.returncode == 0) == (expected is not None)


def test_health_public_trace_and_schema_authority_default_to_deny(
    commands, health_config, config
):
    assert (
        health_projection(commands, health_config, kind="trace").stdout.split()[2]
        == b"eligibility-unproved"
    )
    assert (
        health_projection(
            commands, health_config, kind="trace", family="6", public="1"
        ).stdout.split()[2]
        == b"eligibility-unproved"
    )
    admitted = health_projection(
        commands,
        health_config,
        "health-request",
        kind="trace",
        family="6",
        public="1",
        ipv6="1",
    )
    assert (
        admitted.returncode == 0
        and admitted.stdout == b'url = "https://cloudflare.com/cdn-cgi/trace"\n'
    )
    legacy = health_projection(commands, json.loads(config))
    assert legacy.returncode != 0 and legacy.stdout == b""


def health_wire(commands, tmp_path, kind, contents, *, mode="health-frame", size=0):
    private = tmp_path / "wire"
    private.write_bytes(contents)
    return subprocess.run(
        [*commands[1], awk_program("health_wire")],
        capture_output=True,
        check=False,
        timeout=3,
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_HEALTH_MODE": mode,
            "CFMGR_HEALTH_INPUT": str(private),
            "CFMGR_HEALTH_BYTES": str(size),
            "CFMGR_HEALTH_KIND": kind,
        },
    )


def health_response_run(commands, scope_file, request_file, payload):
    return subprocess.run(
        [
            *commands[1],
            "-v",
            "cfmgr_json_mode=tree",
            "-v",
            f"cfmgr_json_size={len(payload)}",
            awk_program("json", "health_wire", "health_response"),
        ],
        input=payload,
        capture_output=True,
        check=False,
        timeout=3,
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_HEALTH_MODE": "health-response",
            "CFMGR_HEALTH_SCOPE": str(scope_file),
            "CFMGR_HEALTH_INPUT": str(request_file),
            "CFMGR_HEALTH_BYTES": str(request_file.stat().st_size),
        },
    )


def health_v2_value(raw):
    address, slash, prefix = raw.partition("/")
    packed = ipaddress.ip_address(address).packed.hex()
    family = "4" if len(packed) == 8 else "6"
    width = 32 if family == "4" else 128
    return f"VALUE {family} {packed} {prefix if slash else width}"


def health_v2_receipt(kind, state, family, values):
    lines = [f"CFMGR-HEALTH-RESPONSE 2 {state} {len(values)} {kind} {family}"]
    lines.extend(health_v2_value(value) for value in values)
    lines.append(f"END {len(values)}")
    return ("\n".join(lines) + "\n").encode()


def health_compare_run(
    commands, context, entries, *, worker=False, shell=None, awk_tool=None
):
    context.mkdir(parents=True, exist_ok=True)
    manifest_lines = ["CFMGR-HEALTH-COMPARISON 1"]
    for index, (role, ordinal, family, contents) in enumerate(entries, start=1):
        prefix = "health-trace" if role == "TRACE" else "health-response"
        basename = f"{prefix}.{index}.out"
        (context / basename).write_bytes(contents)
        manifest_lines.append(f"{role} {ordinal} {family} {basename}")
    manifest_lines.append(f"END {len(entries)}")
    manifest = context / "comparison"
    manifest.write_text("\n".join(manifest_lines) + "\n")
    if worker:
        assert awk_tool and Path(awk_tool).is_absolute()
        status_source = context / "status.sh"
        status_source.write_text((ROOT / "modules/status.sh").read_text())
        return subprocess.run(
            [
                *shell,
                str(ROOT / "modules/helpers/worker.sh"),
                "health-compare",
                awk_tool,
                str(context),
                str(status_source),
                str(manifest),
            ],
            capture_output=True,
            check=False,
            timeout=3,
            env={**os.environ, "LC_ALL": "C"},
        )
    return subprocess.run(
        [
            *commands[1],
            awk_program("health_wire", "health_compare"),
            str(manifest),
            str(context),
        ],
        capture_output=True,
        check=False,
        timeout=3,
        env={**os.environ, "LC_ALL": "C", "CFMGR_HEALTH_MODE": "health-compare"},
    )


@pytest.mark.parametrize(
    "damage",
    [
        "none",
        "extra-option",
        "missing-lf",
        "duplicate-header",
        "backslash",
        "lookalike-host",
        "wrong-kind",
    ],
)
def test_health_wire_admits_exact_generated_curl_grammar(
    commands, health_config, tmp_path, damage
):
    request = health_projection(commands, health_config, "health-request").stdout
    if damage == "extra-option":
        request += b"insecure\n"
    elif damage == "missing-lf":
        request = request.rstrip(b"\n")
    elif damage == "duplicate-header":
        request += request.splitlines(keepends=True)[1]
    elif damage == "backslash":
        request = request.replace(b"Bearer ", b"Bearer bad\\")
    elif damage == "lookalike-host":
        request = request.replace(
            b"api.cloudflare.com", b"api.cloudflare.com.evil.test"
        )
    result = health_wire(
        commands,
        tmp_path,
        "zone" if damage == "wrong-kind" else "dns",
        request,
        mode="health-request-check",
        size=len(request),
    )
    assert (result.returncode == 0) == (damage == "none")
    assert result.stdout == result.stderr == b""


@pytest.mark.parametrize(
    "case",
    [
        "valid",
        "partial",
        "unknown-pagination",
        "empty",
        "wrong-name",
        "wrong-type",
        "local-id",
        "api-error",
        "nul",
        "invalid-content",
        "invalid-proxy",
        "invalid-ttl",
    ],
)
def test_health_response_is_typed_exact_and_never_claims_partial_absence(
    commands, health_config, tmp_path, case
):
    scope = health_projection(commands, health_config)
    request = health_projection(commands, health_config, "health-request")
    scope_file, request_file = tmp_path / "scope", tmp_path / "request"
    scope_file.write_bytes(scope.stdout)
    request_file.write_bytes(request.stdout)
    record = {
        "id": "d" * 32,
        "name": "example.test",
        "type": "A",
        "content": "8.8.8.8",
        "proxied": True,
        "ttl": 1,
    }
    body = {
        "success": True,
        "errors": [],
        "result": [record],
        "result_info": {"page": 1, "total_pages": 1, "total_count": 1, "count": 1},
    }
    if case == "partial":
        body["result_info"].update(total_pages=2, total_count=2)
    elif case == "unknown-pagination":
        body.pop("result_info")
    elif case == "empty":
        body["result"] = []
        body["result_info"].update(total_count=0, count=0)
    elif case == "wrong-name":
        record["name"] = "other.test"
    elif case == "wrong-type":
        record["type"] = "AAAA"
    elif case == "local-id":
        record["id"] = "local-record-4"
    elif case == "api-error":
        body.update(success=False, errors=[{"message": HEALTH_SECRET}])
    elif case == "invalid-content":
        record["content"] = "999.1.1.1"
    elif case == "invalid-proxy":
        record["proxied"] = "true"
    elif case == "invalid-ttl":
        record["ttl"] = 2
    payload = json.dumps(body).encode()
    if case == "nul":
        payload += b"\0"
    result = health_response_run(commands, scope_file, request_file, payload)
    assert result.stderr == b""
    assert HEALTH_SECRET.encode() not in result.stdout
    if case in {"valid", "partial", "unknown-pagination", "empty"}:
        assert result.returncode == 0
        state = "partial" if case in {"partial", "unknown-pagination"} else "verified"
        count = 0 if case == "empty" else 1
        value = "" if count == 0 else health_v2_value(record["content"]) + "\n"
        assert (
            result.stdout
            == (
                f"CFMGR-HEALTH-RESPONSE 2 {state} {count} dns 4\n{value}END {count}\n"
            ).encode()
        )
    else:
        assert result.returncode != 0 and result.stdout == b""


@pytest.mark.parametrize(
    "content",
    ["2606:4700::ABCD", "::ffff:192.0.2.1"],
    ids=["compressed-ipv6", "dotted-ipv4-tail"],
)
def test_health_dns_receipt_canonicalizes_ipv6_and_dotted_tail(
    commands, health_config, tmp_path, content
):
    scope = health_projection(
        commands, health_config, kind="dns", selector="local-record-6", family="6"
    )
    request = health_projection(
        commands,
        health_config,
        "health-request",
        kind="dns",
        selector="local-record-6",
        family="6",
    )
    scope_file, request_file = tmp_path / "scope", tmp_path / "request"
    scope_file.write_bytes(scope.stdout)
    request_file.write_bytes(request.stdout)
    body = {
        "success": True,
        "errors": [],
        "result": [
            {
                "id": "d" * 32,
                "name": "*.example.test",
                "type": "AAAA",
                "content": content,
                "proxied": True,
                "ttl": 1,
            }
        ],
        "result_info": {"page": 1, "total_pages": 1, "total_count": 1, "count": 1},
    }
    result = health_response_run(
        commands, scope_file, request_file, json.dumps(body).encode()
    )
    assert result.returncode == 0 and result.stderr == b""
    assert result.stdout == health_v2_receipt("dns", "verified", "6", [content])


@pytest.mark.parametrize("kind", ["dns", "items"])
@pytest.mark.parametrize("count,accepted", [(50, True), (51, False)])
def test_health_v2_receipts_bound_values_and_round_trip_complete_frames(
    commands, health_config, tmp_path, kind, count, accepted
):
    selected = {
        "feature": "ddns" if kind == "dns" else "ip_sync",
        "kind": kind,
        "selector": "local-record-4" if kind == "dns" else "primary",
        "family": "4",
    }
    scope = health_projection(commands, health_config, **selected)
    request = health_projection(commands, health_config, "health-request", **selected)
    scope_file, request_file = tmp_path / "scope", tmp_path / "request"
    scope_file.write_bytes(scope.stdout)
    request_file.write_bytes(request.stdout)
    if kind == "dns":
        records = [
            {
                "id": f"{index:032x}",
                "name": "example.test",
                "type": "A",
                "content": f"8.8.8.{index + 1}",
                "proxied": True,
                "ttl": 1,
            }
            for index in range(count)
        ]
        info = {"page": 1, "total_pages": 1, "total_count": count, "count": count}
    else:
        records = [
            {"id": f"{index:032x}", "ip": f"10.0.0.{index + 1}"}
            for index in range(count)
        ]
        info = {"cursors": {}}
    body = {"success": True, "errors": [], "result": records, "result_info": info}
    result = health_response_run(
        commands, scope_file, request_file, json.dumps(body).encode()
    )
    assert result.stderr == b""
    if not accepted:
        assert result.returncode != 0 and result.stdout == b""
        return
    assert result.returncode == 0 and len(result.stdout) <= 4096
    assert (
        result.stdout.splitlines()[0]
        == (
            f"CFMGR-HEALTH-RESPONSE 2 verified {count} {kind} "
            f"{'4' if kind == 'dns' else 'mixed'}"
        ).encode()
    )
    assert result.stdout.splitlines()[-1] == f"END {count}".encode()
    assert len(result.stdout.splitlines()) == count + 2
    framed = health_wire(commands, tmp_path, "response", result.stdout)
    assert framed.returncode == 0 and framed.stdout == framed.stderr == b""


def test_health_v2_frame_rejects_receipts_over_4096_bytes(commands, tmp_path):
    oversized = (
        b"CFMGR-HEALTH-RESPONSE 2 verified 0 dns 4\n" + b"x" * 4097 + b"\nEND 0\n"
    )
    result = health_wire(commands, tmp_path, "response", oversized)
    assert result.returncode != 0 and result.stdout == result.stderr == b""


def test_health_compare_worker_caps_seven_inputs_and_emits_at_most_five_safe_rows(
    commands, shell, tools, tmp_path
):
    trace4 = b"CFMGR-HEALTH-RESPONSE 1 observed 1 ipv4:8.8.8.8 END\n"
    trace6 = b"CFMGR-HEALTH-RESPONSE 1 observed 1 ipv6:2606:4700::1111 END\n"
    entries = [
        ("DNS", "1", "4", health_v2_receipt("dns", "verified", "4", ["8.8.8.8"])),
        ("DNS", "2", "4", health_v2_receipt("dns", "verified", "4", ["1.1.1.1"])),
        (
            "DNS",
            "3",
            "6",
            health_v2_receipt("dns", "verified", "6", ["2606:4700::1111"]),
        ),
        (
            "ITEMS",
            "1",
            "4",
            health_v2_receipt("items", "verified", "mixed", ["8.0.0.0/8"]),
        ),
        (
            "ITEMS",
            "2",
            "6",
            health_v2_receipt("items", "verified", "mixed", ["2606:4700::/32"]),
        ),
        ("TRACE", "1", "4", trace4),
        ("TRACE", "2", "6", trace6),
    ]
    result = health_compare_run(
        commands,
        tmp_path / "compare-worker",
        entries,
        worker=True,
        shell=shell,
        awk_tool=tools["awk"],
    )
    assert result.returncode == 0 and result.stderr == b""
    assert result.stdout == (
        b"CFMGR-HEALTH-COMPARE 1\n"
        b"ROW ddns.record.1 PASS dns-equal\n"
        b"ROW ddns.record.2 WARN dns-different\n"
        b"ROW ddns.record.3 PASS dns-equal\n"
        b"ROW ip_sync.primary.ipv4 PASS list-member\n"
        b"ROW ip_sync.secondary.ipv6 PASS list-member\n"
        b"END 5\n"
    )


def test_health_compare_missing_family_and_partial_list_are_explicit(
    commands, tmp_path
):
    entries = [
        (
            "DNS",
            "1",
            "6",
            health_v2_receipt("dns", "verified", "6", ["2606:4700::1111"]),
        ),
        (
            "ITEMS",
            "1",
            "46",
            health_v2_receipt("items", "partial", "mixed", ["8.0.0.0/8"]),
        ),
        ("TRACE", "1", "4", b"CFMGR-HEALTH-RESPONSE 1 observed 1 ipv4:8.8.8.8 END\n"),
    ]
    result = health_compare_run(commands, tmp_path / "partial-compare", entries)
    assert result.returncode == 0 and result.stderr == b""
    assert result.stdout == (
        b"CFMGR-HEALTH-COMPARE 1\n"
        b"ROW ddns.record.1 UNKNOWN current-family-unavailable\n"
        b"ROW ip_sync.primary.ipv4 PASS list-member-partial\n"
        b"ROW ip_sync.primary.ipv6 UNKNOWN current-family-unavailable\n"
        b"END 3\n"
    )


@pytest.mark.parametrize(
    "receipt",
    [
        (
            b"CFMGR-HEALTH-RESPONSE 2 verified 2 items mixed\n"
            b"VALUE 4 08000000 8\nVALUE 4 invalid 8\nEND 2\n"
        ),
        (
            b"CFMGR-HEALTH-RESPONSE 2 verified 1 items mixed\n"
            b"VALUE 4 08000000 8\nEND 0\n"
        ),
    ],
    ids=["malformed-value-after-hit", "malformed-footer"],
)
def test_health_compare_rejects_malformed_full_receipt_before_positive(
    commands, tmp_path, receipt
):
    entries = [
        ("ITEMS", "1", "4", receipt),
        ("TRACE", "1", "4", b"CFMGR-HEALTH-RESPONSE 1 observed 1 ipv4:8.8.8.8 END\n"),
    ]
    result = health_compare_run(commands, tmp_path / "malformed-compare", entries)
    assert result.returncode != 0 and result.stdout == b""


@pytest.mark.parametrize(
    "kind,state,values,current,expected",
    [
        ("dns", "verified", [], "8.8.8.8", "WARN dns-absent"),
        ("dns", "verified", ["8.8.8.8", "1.1.1.1"], "8.8.8.8", "WARN dns-multiple"),
        ("dns", "partial", ["8.8.8.8"], "8.8.8.8", "UNKNOWN dns-partial"),
        ("items", "partial", ["9.0.0.0/8"], "8.8.8.8", "UNKNOWN list-partial-no-match"),
        ("items", "verified", ["8.0.0.0/9"], "8.127.255.254", "PASS list-member"),
        ("items", "verified", ["8.0.0.0/10"], "8.63.255.254", "PASS list-member"),
        ("items", "verified", ["8.0.0.0/11"], "8.32.0.1", "WARN list-no-match"),
        (
            "items",
            "verified",
            ["2606:4700::1110/126"],
            "2606:4700::1113",
            "PASS list-member",
        ),
        (
            "items",
            "verified",
            ["2606:4700::1110/127"],
            "2606:4700::1112",
            "WARN list-no-match",
        ),
    ],
)
def test_health_compare_complete_dns_and_cidr_boundaries(
    commands, tmp_path, kind, state, values, current, expected
):
    family = str(ipaddress.ip_address(current).version)
    entries = [
        (
            "DNS" if kind == "dns" else "ITEMS",
            "1",
            family,
            health_v2_receipt(
                kind, state, family if kind == "dns" else "mixed", values
            ),
        ),
        (
            "TRACE",
            "1",
            family,
            f"CFMGR-HEALTH-RESPONSE 1 observed 1 ipv{family}:{current} END\n".encode(),
        ),
    ]
    result = health_compare_run(commands, tmp_path / "comparison", entries)
    check_id = "ddns.record.1" if kind == "dns" else f"ip_sync.primary.ipv{family}"
    assert (result.returncode, result.stderr) == (0, b"")
    assert result.stdout == (
        f"CFMGR-HEALTH-COMPARE 1\nROW {check_id} {expected}\nEND 1\n".encode()
    )


@pytest.mark.parametrize(
    "ip,family,allowed",
    [
        ("8.8.8.8", "4", True),
        ("100.64.1.2", "4", False),
        ("192.168.1.2", "4", False),
        ("2606:4700::1111", "6", True),
        ("2001:db8::1", "6", False),
        ("8.8.8.8", "6", False),
    ],
)
def test_health_trace_receipts_only_export_current_public_family(
    commands, tmp_path, ip, family, allowed
):
    body = f"fl=fixture\nip={ip}\nloc=TEST\n".encode()
    result = health_wire(
        commands, tmp_path, family, body, mode="health-trace", size=len(body)
    )
    assert (result.returncode == 0) == allowed
    assert result.stderr == b""
    if allowed:
        assert (
            result.stdout
            == f"CFMGR-HEALTH-RESPONSE 1 observed 1 ipv{family}:{ip} END\n".encode()
        )
    else:
        assert result.stdout == b""


def test_health_budget_reserves_before_work_and_preserves_unknown_ownership(
    shell, tmp_path
):
    script = r"""
. "$1/modules/status.sh"
. "$1/modules/lib/execution.sh"
cfmgr_health_active=1 cfmgr_health_operations=0 cfmgr_health_requests=0 cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_health_owned=''
cfmgr_health_collect_deadline=140 cfmgr_probe_serial=0 cfmgr_probe_pid='' cfmgr_health_incomplete=0
cfmgr_status_attachment_ok() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=100; }
cfmgr_prerequisites_run health-unknown "$2" /bin/sh /not-a-helper /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc /not-a-tool
[ "$?" = 2 ] && [ "$cfmgr_health_operations" = 0 ] || exit 10
cfmgr_health_operations=11 cfmgr_health_requests=11 cfmgr_health_files=44 cfmgr_health_bytes=2883584 cfmgr_probe_serial=11
cfmgr_health_reserve health-get || exit 11
[ "$cfmgr_health_operations:$cfmgr_health_requests:$cfmgr_health_files:$cfmgr_health_bytes" = 12:12:48:3145728 ] || exit 12
cfmgr_health_reserve health-get
[ "$?" = 1 ] && [ "$cfmgr_health_operations" = 12 ] && [ "$cfmgr_health_incomplete" = 1 ] || exit 13
cfmgr_probe_pid=preserve-owned cfmgr_probe_status=unresolved
cfmgr_prerequisites_run health-date
[ "$?" = 3 ] && [ "$cfmgr_probe_pid" = preserve-owned ] || exit 14
cfmgr_probe_pid=''
cfmgr_prerequisites_now() { cfmgr_probe_now=140; }
cfmgr_health_reserve health-date
[ "$?" = 1 ] && [ "$cfmgr_health_operations" = 12 ] || exit 15
"""
    result = subprocess.run(
        [*shell, "-c", script, "budget", str(ROOT), str(tmp_path)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout == result.stderr == b"" and list(tmp_path.iterdir()) == []


def test_health_scope_holds_do_not_merge_secrets_and_429_stops_provider(
    shell, tmp_path
):
    script = r"""
. "$1/modules/status.sh"
cfmgr_health_provider_stop=0 cfmgr_health_scope_holds=''
cfmgr_health_scope=api-a.zone.aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
cfmgr_health_http 403 || exit 10
case "$cfmgr_health_scope_holds" in *api-a.zone*) ;; *) exit 11 ;; esac
case "$cfmgr_health_scope_holds" in *api-b*) exit 12 ;; esac
[ "$cfmgr_health_provider_stop" = 0 ] && [ "$cfmgr_health_result" = auth-rejected-read ] || exit 13
cfmgr_health_http 429 || exit 14
[ "$cfmgr_health_provider_stop" = 1 ] && [ "$cfmgr_health_result" = provider-throttle ] || exit 15
for code in 6 7 60 77; do
    cfmgr_health_transport=ready
    cfmgr_health_transport_exit "$code"
    [ "$?" = 1 ] && [ "$cfmgr_health_transport" = unavailable ] || exit 16
done
cfmgr_health_transport=ready
cfmgr_health_transport_exit 28
[ "$?" = 0 ] && [ "$cfmgr_health_transport" = ready ] || exit 17
"""
    result = subprocess.run(
        [*shell, "-c", script, "scope", str(ROOT)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize(
    "ip,after,expected",
    [
        ("10.0.0.1", None, "verified"),
        ("10.0.0.0/8", "next-page", "partial"),
        ("2001:db8::/32", "", "verified"),
        ("::ffff:192.0.2.1", None, "verified"),
        ("10.0.0.0/7", None, None),
        ("2001:db8::/11", None, None),
        ("not-an-ip", None, None),
    ],
)
def test_health_list_items_use_typed_cursor_pagination_and_provider_ip_semantics(
    commands, health_config, tmp_path, ip, after, expected
):
    scope = health_projection(
        commands, health_config, feature="ip_sync", kind="items", selector="primary"
    )
    request = health_projection(
        commands,
        health_config,
        "health-request",
        feature="ip_sync",
        kind="items",
        selector="primary",
    )
    scope_file, request_file = tmp_path / "scope", tmp_path / "request"
    scope_file.write_bytes(scope.stdout)
    request_file.write_bytes(request.stdout)
    cursors = {} if after is None else {"after": after}
    body = {
        "success": True,
        "errors": [],
        "result": [{"id": "d" * 32, "ip": ip}],
        "result_info": {"cursors": cursors},
    }
    payload = json.dumps(body).encode()
    result = health_response_run(commands, scope_file, request_file, payload)
    assert result.stderr == b""
    if expected is None:
        assert result.returncode != 0 and result.stdout == b""
    else:
        state = "partial" if expected == "partial" else "verified"
        receipt = (
            f"CFMGR-HEALTH-RESPONSE 2 {state} 1 items mixed\n"
            f"{health_v2_value(ip)}\nEND 1\n"
        )
        assert result.returncode == 0 and result.stdout == receipt.encode()
        framed = health_wire(
            commands, tmp_path, "response", result.stdout, mode="health-frame"
        )
        assert framed.returncode == 0 and framed.stdout == framed.stderr == b""


def test_health_limits_and_explicit_clock_gate_fail_before_collection(shell, tmp_path):
    script = r"""
. "$1/modules/status.sh"
cfmgr_status_prepare() { cfmgr_probe_now=100; cfmgr_status_deadline=110; }
cfmgr_health_clock_ready=1 cfmgr_health_public_eligible=1 cfmgr_health_ipv6_ready=1 cfmgr_health_native_admitted=1
cfmgr_health_begin || exit 10
[ "$cfmgr_health_clock_ready:$cfmgr_health_public_eligible:$cfmgr_health_ipv6_ready:$cfmgr_health_native_admitted" = 0:0:0:0 ] || exit 11
[ "$cfmgr_health_deadline:$cfmgr_health_collect_deadline:$cfmgr_status_deadline" = 145:140:110 ] || exit 12
cfmgr_health_transport=ready
cfmgr_health_project() { exit 13; }
cfmgr_health_get ddns zone - 4
[ "$?" = 1 ] && [ "$cfmgr_health_operations" = 0 ] || exit 14
cfmgr_status_attachment_ok() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=100; }
cfmgr_health_operations=503 cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_probe_serial=503
cfmgr_health_reserve health-date || exit 15
cfmgr_health_reserve health-date
[ "$?" = 1 ] && [ "$cfmgr_health_operations" = 504 ] || exit 16
cfmgr_health_operations=0 cfmgr_health_files=1134
cfmgr_health_reserve health-date || exit 17
cfmgr_health_reserve health-date
[ "$?" = 1 ] && [ "$cfmgr_health_files" = 1136 ] || exit 18
cfmgr_health_files=1135
cfmgr_health_stage_reserve comparison 2048 || exit 23
cfmgr_health_stage_reserve dashboard 32768
[ "$?" = 1 ] && [ "$cfmgr_health_files" = 1136 ] || exit 24
cfmgr_health_operations=0 cfmgr_health_files=0 cfmgr_health_bytes=11272192
cfmgr_health_reserve health-snapshot || exit 19
cfmgr_health_reserve health-date
[ "$?" = 1 ] && [ "$cfmgr_health_bytes" = 11534336 ] || exit 20
cfmgr_health_rows=95 shown=0
cfmgr_status_row() { shown=$((shown+1)); }
cfmgr_health_row system.example UNKNOWN details unknown None system.time || exit 21
cfmgr_health_row system.example UNKNOWN details unknown None system.time
[ "$?" = 1 ] && [ "$shown:$cfmgr_health_rows" = 1:96 ] || exit 22
"""
    result = subprocess.run(
        [*shell, "-c", script, "limits", str(ROOT)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert not list(tmp_path.iterdir())


def test_health_cleanup_validates_full_inventory_then_removes_owned_batches(
    shell, tmp_path
):
    context = tmp_path / "private-context"
    context.mkdir(mode=0o700)
    names = [f"health-date.{i}.out" for i in range(1, 66)]
    for name in names:
        (context / name).write_bytes(b"owned fixture\n")
    foreign = context / "unregistered"
    foreign.write_bytes(b"preserve foreign fixture\n")
    script = r"""
. "$1/modules/status.sh"
cfmgr_status_context=$2 cfmgr_health_owned=$3 cfmgr_probe_pid='' cfmgr_probe_status=reaped checked=0
cfmgr_status_attachment_ok() { checked=$((checked+1)); [ -d "$cfmgr_status_context" ]; }
if cfmgr_health_cleanup; then printf 'clean %s\n' "$checked"; else printf 'retained %s\n' "$?"; fi
"""
    args = [
        *shell,
        "-c",
        script,
        "cleanup",
        str(ROOT),
        str(context),
        "\n" + "\n".join(names),
    ]
    refused = subprocess.run(args, capture_output=True, check=False, timeout=3)
    assert refused.stdout == b"retained 1\n" and refused.stderr == b""
    assert all((context / name).read_bytes() == b"owned fixture\n" for name in names)
    assert foreign.read_bytes() == b"preserve foreign fixture\n"
    foreign.unlink()
    cleaned = subprocess.run(args, capture_output=True, check=False, timeout=3)
    assert cleaned.stdout == b"clean 3\n" and cleaned.stderr == b""
    assert not context.exists()


def test_health_tls_callback_is_read_only_and_failed_admission_retires_readiness(shell):
    script = r"""
. "$1/modules/status.sh"
. "$1/modules/lib/network.sh"
cfmgr_health_active=1 cfmgr_health_native_admitted=0 cfmgr_health_transport=ready
cfmgr_health_tls_check
[ "$?" = 2 ] && [ "$cfmgr_health_transport" = unavailable ] || exit 10
cfmgr_health_curl=/native/curl cfmgr_health_openssl=/native/openssl modes=''
cfmgr_health_run() { modes="$modes $1"; cfmgr_probe_stdout=/private/out cfmgr_probe_stderr=/private/err cfmgr_probe_exit=0; }
cfmgr_health_native_action native-curl-version || exit 11
cfmgr_health_native_action native-curl-features /private/version || exit 12
cfmgr_health_native_action native-ca-pem /native/ca || exit 13
cfmgr_health_native_action native-ca-decode /native/ca || exit 14
cfmgr_health_native_action native-curl-offline /native/ca /private || exit 15
cfmgr_health_native_action install-wc /native/ca || exit 16
[ "$modes" = ' health-curl-version health-curl-features health-ca-pem health-ca-decode health-curl-offline health-count' ] || exit 17
cfmgr_health_native_action install-mkdir /must-not-write
[ "$?" = 2 ] && [ "$cfmgr_native_output:$cfmgr_native_error:$cfmgr_native_exit" = /private/out:/private/err:0 ] || exit 18
"""
    result = subprocess.run(
        [*shell, "-c", script, "tls-callback", str(ROOT)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def project(commands, tmp_path, data, *, clock="1", boot=BOOT, wan="0"):
    payload = json.dumps(data).encode() if isinstance(data, dict) else data
    return subprocess.run(
        awk_arguments(
            [
                *commands[1],
                "-v",
                f"cfmgr_json_size={len(payload)}",
                "-v",
                "cfmgr_json_mode=tree",
                "-f",
                "cfmgr-parser:json",
                "-f",
                "cfmgr-parser:status",
            ]
        ),
        input=payload,
        capture_output=True,
        check=False,
        timeout=3,
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_STATUS_MODE": "render",
            "CFMGR_STATUS_NOW": str(NOW),
            "CFMGR_STATUS_BOOT": boot,
            "CFMGR_STATUS_WAN": wan,
            "CFMGR_STATUS_CLOCK": clock,
            "CFMGR_STATUS_REPOSITORY": "https://github.com/example/CFMgr",
            "CFMGR_STATUS_BRANCH": "develop",
        },
    )


def record():
    return {
        "schema": 1,
        "generation": 1,
        "ipv4": {"result": "verified", "value": "8.8.8.8", "at": NOW - 60},
        "ipv6": {"result": "removed", "value": None, "at": NOW - 90},
        "latest": {"result": "partial", "reason": "auth", "at": NOW - 50},
        "observation": {
            "origin": "runtime",
            "boot_id": BOOT,
            "at": NOW - 30,
            "running": True,
            "connection": "waiting",
            "logging": "unavailable",
            "cleanup": True,
            "installed_version": "2026.1.0",
        },
    }


def test_typed_history_state_separation_and_privacy(commands, config, tmp_path):
    value = json.loads(config)
    value["ddns"].update(configured=True, enabled=False, credentials="TOP_SECRET")
    value["cloudflared"].update(
        configured=True, enabled=False, installed=True, maintenance_enabled=True
    )
    for name in ("ddns", "ip_sync", "cloudflared"):
        value["history"][name] = {"status": record(), "private_token": "TOP_SECRET"}
        value["history"][name]["status"]["events"] = [
            {"at": NOW - i, "result": "pending", "reason": "throttle"} for i in range(8)
        ]
    value["history"]["network"] = {
        "status": {
            "schema": 1,
            "generation": 1,
            "boot_id": BOOT,
            "selected_wan": "0",
            "ipv4": {"value": "9.9.9.9", "at": NOW - 20, "source": "discovery"},
            "ipv6": {
                "value": "2606:4700::1111",
                "at": NOW - 20,
                "source": "interface",
                "eligible": True,
            },
        }
    }
    result = project(commands, tmp_path, value)
    assert result.returncode == 0, result.stderr
    out = result.stdout.decode()
    assert "configured=On; enabled=Off" in out
    assert "installed=On; maintenance=On" in out
    assert "Last verified IPv4 (historical): verified 8.8.8.8" in out
    assert "Last verified IPv6 (historical): removed; at" in out
    assert "Last outcome (historical): partial; auth" in out
    assert "Observed running=On; connection=waiting" in out
    assert "recorded cleanup required" in out
    assert "Recorded public IPv4 (historical): 9.9.9.9" in out
    assert "Recorded eligible IPv6 (historical): 2606:4700::1111" in out
    assert out.count("Recent ") == 5
    assert "TOP_SECRET" not in out and "\x1b" not in out


@pytest.mark.parametrize(
    "change", ["generation", "boot", "restored", "future", "clock"]
)
def test_stale_or_untrusted_current_claims_keep_historical_outcome(
    commands, config, tmp_path, change
):
    value = json.loads(config)
    current = record()
    if change == "generation":
        current["generation"] = 2
    if change == "boot":
        current["observation"]["boot_id"] = "87654321-4321-4321-4321-cba987654321"
    if change == "restored":
        current["observation"]["origin"] = "restored"
    if change == "future":
        current["observation"]["at"] = NOW + 1
    value["history"]["ddns"] = {"status": current}
    result = project(commands, tmp_path, value, clock="0" if change == "clock" else "1")
    assert result.returncode == 0
    assert b"Last verified IPv4 (historical): verified" in result.stdout
    assert b"Observed running=" not in result.stdout
    assert b"stale/restored/untrusted observation" in result.stdout
    assert b"recorded cleanup required" in result.stdout
    if change == "clock":
        assert b"time/age Unknown" in result.stdout


def test_partial_invalid_and_terminal_unsafe_config_sections(
    commands, config, tmp_path
):
    value = json.loads(config)
    value.pop("manager")
    value["ddns"].update(configured=False, enabled=True)
    value["ip_sync"] = {"configured": False, "enabled": False}
    value["history"]["ddns"] = {"status": record()}
    value["history"]["ddns"]["status"]["latest"]["reason"] = "auth\u001b[2JSECRET"
    result = project(commands, tmp_path, value)
    assert result.returncode == 0
    assert b"invalid enabled-without-configured" in result.stdout
    assert b"IP-Sync: configured=Off; enabled=Off" in result.stdout
    assert b"invalid typed record" in result.stdout
    assert b"SECRET" not in result.stdout and b"\x1b" not in result.stdout
    for data in (
        b"{broken",
        b'{"schema":9,"generation":1}',
        b'{"schema":1,' + b" " * 65536 + b"}",
    ):
        failed = project(commands, tmp_path, data)
        assert failed.returncode != 0 and failed.stdout == b""


@pytest.mark.parametrize(
    ("check", "auto", "developer", "expected", "suppression"),
    [
        (
            True,
            False,
            False,
            "Manager updates: saved Check=On; saved Auto=Off; effective Check=On; effective Auto=Off",
            False,
        ),
        (
            False,
            True,
            False,
            "Manager updates: saved Check=Off; saved Auto=On; effective Check=Off; effective Auto=Off",
            False,
        ),
        (
            True,
            True,
            True,
            "Manager updates: saved Check=On; saved Auto=On; effective Check=Off; effective Auto=Off",
            True,
        ),
        (
            "true",
            True,
            False,
            "Manager updates: saved Check=Unknown; saved Auto=On; effective Check=Unknown; effective Auto=Unknown",
            False,
        ),
        (
            True,
            True,
            "false",
            "Manager updates: saved Check=On; saved Auto=On; effective Check=Unknown; effective Auto=Unknown",
            False,
        ),
    ],
)
def test_manager_status_distinguishes_saved_and_effective_updates(
    commands, config, tmp_path, check, auto, developer, expected, suppression
):
    value = json.loads(config)
    value["manager"].update(
        check_updates=check,
        auto_update=auto,
        developer=developer,
    )
    result = project(commands, tmp_path, value)
    assert result.returncode == 0
    output = result.stdout.decode()
    assert expected in output
    note = "developer mode suppresses manager updates; saved preferences are retained"
    assert (note in output) is suppression


def test_health_terminal_renderer_groups_raw_dashboard_and_summarizes_severity(
    commands, tmp_path
):
    dashboard = tmp_path / "dashboard"
    dashboard.write_text(
        "\nCFMgr 0.1.0 - local status\nuptime: 5s\nload: 0.1 0.2 0.3\n"
        "Selected WAN: wan0\nConfiguration: local schema 2\n"
        "DDNS: configured=On; enabled=Off\n  Last outcome: historical success\n"
        "IP-Sync: configured=Off; enabled=Off\n  Next: configure IP-Sync first\n"
        "Cloudflared: configured=Off; enabled=Off\n  Runtime: Unknown\n"
        "Issue: retained storage observation requires cleanup/recovery\n"
        "Status uses local evidence; no network or feature action was performed.\n\n"
    )
    rows = tmp_path / "rows"
    rows.write_text(
        "network.ipv4\tUNKNOWN\tUnknown evidence\t20s\tCheck router mode\tsystem.time\n"
        "system.time\tWARN\tClock is not ready\t1s\tCheck NTP\t-\n"
        "package.entry\tFAIL\tRequired entry is missing\tnow\tRecover installation\t-\n"
    )
    result = subprocess.run(
        [*commands[1], awk_program("health_render"), "64", str(dashboard), str(rows)],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, result.stderr
    output = result.stdout.decode()
    assert output.index("Issue summary") < output.index("package.entry [FAIL]")
    assert output.index("package.entry [FAIL]") < output.index("system.time [WARN]")
    assert output.index("system.time [WARN]") < output.index("network.ipv4 [UNKNOWN]")
    assert output.index("Issue summary") < output.index("CFMgr 0.1.0")
    assert (
        output.index("Router/resources")
        < output.index("Manager")
        < output.index("Network")
    )
    assert (
        output.index("Network")
        < output.index("DDNS")
        < output.index("IP-Sync")
        < output.index("Cloudflared")
    )
    assert output.index("Cloudflared") < output.index("Integrations")
    assert output.index("DDNS") < output.index("Last outcome: historical success")
    assert output.rindex("Status uses local evidence") > output.rindex("== network ==")
    assert all(field in output for field in ("Age:", "Next:", "Dependency:"))
    assert b"\x1b" not in result.stdout and max(map(len, output.splitlines())) <= 64


def test_health_terminal_renderer_bounds_maximum_narrow_report_and_rejects_bad_rows(
    commands, tmp_path
):
    dashboard = tmp_path / "dashboard"
    dashboard.write_text("x" * 16383 + "\n")
    rows = tmp_path / "rows"
    row_lines = []
    for i in range(96):
        check_id = f"g{i:02d}" + "x" * 61
        row = "\t".join((check_id, "UNKNOWN", "d" * 512, "a" * 64, "n" * 512, "p" * 64))
        assert len(row) == 1228
        row_lines.append(row)
    rows.write_text("\n".join(row_lines) + "\n")
    argv = [*commands[1], awk_program("health_render"), "10", str(dashboard), str(rows)]
    bounded = subprocess.run(
        argv,
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert bounded.returncode == 0, bounded.stderr
    output = bounded.stdout.decode("ascii")
    assert len(bounded.stdout) <= 196608 and max(map(len, output.splitlines())) <= 10
    normalized = "".join(output.split())
    assert all(f"g{i:02d}" + "x" * 61 in normalized for i in range(96))
    assert "Dependency:" in normalized and b"\x1b" not in bounded.stdout

    rows.write_text("x" * 65 + "\tPASS\td\ta\tn\t-\n")
    rejected = subprocess.run(
        argv,
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert rejected.returncode != 0 and rejected.stdout == b""
    assert rejected.stderr == b""

    rows.write_text("x\x1b[31m\tPASS\td\ta\tn\t-\n")
    controls = subprocess.run(
        argv,
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert controls.returncode != 0 and controls.stdout == b""
    assert controls.stderr == b""

    dashboard.write_text("x" * 16384 + "\n")
    rows.write_text("")
    oversized = subprocess.run(
        [*commands[1], awk_program("health_render"), "10", str(dashboard), "-"],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert oversized.returncode != 0 and oversized.stdout == b""


@pytest.mark.parametrize(
    ("ip", "classification"),
    [
        ("10.0.0.1", "Private"),
        ("172.20.0.1", "Private"),
        ("100.64.0.1", "Shared-CGNAT"),
        ("100.128.0.1", "Public"),
        ("192.0.2.1", "Non-public"),
        ("192.0.3.1", "Public"),
        ("198.51.101.1", "Public"),
        ("203.0.114.1", "Public"),
    ],
)
def test_native_wan_ipv4_classification(commands, tmp_path, ip, classification):
    raw = tmp_path / "native.out"
    raw.write_text(ip + "\n")
    result = subprocess.run(
        awk_arguments(
            [
                *commands[1],
                "-f",
                "cfmgr-parser:status_native",
                "nvram",
                str(raw),
                "wan0_ipaddr",
            ]
        ),
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.stdout == f"{ip} ({classification})\n".encode()


@pytest.mark.parametrize(
    "ip", ["fd00::1", "fe80::1", "2001:db8::1", "2001:4860::1:", "2606:4700::1111/64"]
)
def test_ineligible_or_malformed_ipv6_is_never_public_evidence(
    commands, config, tmp_path, ip
):
    value = json.loads(config)
    value["history"]["network"] = {
        "status": {
            "schema": 1,
            "generation": 1,
            "ipv6": {"value": ip, "at": NOW, "source": "interface", "eligible": True},
        }
    }
    result = project(commands, tmp_path, value)
    assert b"Recorded eligible IPv6: Unavailable" in result.stdout
    assert ip.encode() not in result.stdout


@pytest.fixture
def status_fixture(tmp_path, tools, shell):
    source = tmp_path / "source"
    (source / "modules/lib").mkdir(parents=True)
    (source / "modules/helpers").mkdir()
    for relative in (
        "modules/status.sh",
        "modules/lib/config.sh",
        "modules/lib/storage.sh",
        "modules/helpers/worker.sh",
    ):
        original = (ROOT / relative).read_text()
        adapted = original
        if relative == "modules/status.sh":
            adapted = adapted.replace("$3!=0", f"$3!={os.getuid()}")
        if relative == "modules/status.sh":
            adapted = adapted.replace('a[4]!="0"', f'a[4]!="{os.getuid()}"')
            adapted = adapted.replace('f[4]!="0"', f'f[4]!="{os.getuid()}"')
            adapted = adapted.replace(
                '[ "$cfmgr_status_meta_uid" = 0 ]',
                f'[ "$cfmgr_status_meta_uid" = {os.getuid()} ]',
            )
        if relative == "modules/helpers/worker.sh" and sys.platform == "darwin":
            adapted = adapted.replace("/proc/self/fd/8", "/dev/fd/8").replace(
                '"$1" -ef /dev/fd/8', "-f /dev/fd/8"
            )
        (source / relative).write_text(adapted)
        (source / relative).chmod((ROOT / relative).stat().st_mode & 0o777)
    assert os.access(source / "modules/helpers/worker.sh", os.X_OK)
    proc = tmp_path / "proc"
    (proc / "sys/kernel/random").mkdir(parents=True)
    (proc / "self").mkdir()
    (proc / "uptime").write_text("1234.56 999.00\n")
    (proc / "loadavg").write_text("0.10 0.20 0.30 1/10 50\n")
    (proc / "meminfo").write_text("MemTotal: 1024 kB\nMemAvailable: 640 kB\n")
    (proc / "sys/kernel/random/boot_id").write_text(BOOT + "\n")
    (proc / "self/mountinfo").write_text(
        "1 9 0:1 / / rw - tmpfs tmpfs rw\n2 1 0:2 / /jffs rw - jffs2 jffs rw\n3 1 8:1 / /mnt/usb rw - ext4 /dev/sda1 rw\n"
    )
    fake = tmp_path / "native"
    fake.mkdir()
    bodies = {
        "nvram": "case $2 in productid) echo GT-AX11000 ;; firmver) echo 3004 ;; buildno) echo 388 ;; extendno) echo 8_4 ;; ntp_ready | wan0_primary) echo 1 ;; wan1_primary) echo 0 ;; wan0_proto) echo dhcp ;; wan0_ifname) echo eth0 ;; wan0_ipaddr) echo 100.64.1.2 ;; *) exit 1 ;; esac\n",
        "date": f"echo {NOW}\n",
        "df": "printf '%s\\n' 'Filesystem 1K-blocks Used Available Use% Mounted on' '/dev/fixture 1024 100 924 10% /opt'\n",
        "readlink": "case $2 in /jffs) echo /jffs ;; /opt) echo /mnt/usb/entware ;; *) exit 1 ;; esac\n",
    }
    for name, body in bodies.items():
        (fake / name).write_text("#!/bin/sh\n" + body)
        (fake / name).chmod(0o700)
    # Caller-only host path/ownership forwarding, actual status/probe/parser bodies.
    probe = (
        (source / "modules/helpers/worker.sh")
        .read_text()
        .replace("/proc/self/mountinfo", str(proc / "self/mountinfo"))
    )
    (source / "modules/helpers/worker.sh").write_text(probe)
    return source, proc, fake


STATUS_CONSUMER = r"""
. "$1/modules/status.sh"
base=$2 cfmgr_source=$1 scenario=$3
cfmgr_status_sh=$4 cfmgr_status_awk=$5
CFMGR_VERSION=0.1.0 CFMGR_REPOSITORY=https://github.com/example/CFMgr CFMGR_BRANCH=develop
cfmgr_prerequisites_now() { cfmgr_probe_now=${fake_now:-100}; }
cfmgr_status_prepare() {
    cfmgr_status_context=$base/ram
    mkdir -m 700 "$cfmgr_status_context" || return 1
    exec 9<"$cfmgr_status_context"
    cfmgr_status_interrupted=0 cfmgr_status_budget_exhausted=0 cfmgr_probe_pid=''
    cfmgr_status_deadline=110
    cfmgr_status_final_deadline='' cfmgr_status_final_operations=0
    cfmgr_prerequisites_now
}
cfmgr_status_attachment_ok() { [ -d "$cfmgr_status_context" ] && [ ! -L "$cfmgr_status_context" ]; }
cfmgr_prerequisites_run() {
    case $1 in health-*) cfmgr_health_reserve "$1" || return $? ;; status-render | status-render-count) cfmgr_status_final_reserve || return $? ;; esac
    mode=$1 context=$2 helper=$4 selected_tool=$9
    shift 9
    cfmgr_probe_serial=$((${cfmgr_probe_serial:-0}+1))
    cfmgr_probe_stdout=$context/$mode.$cfmgr_probe_serial.out
    cfmgr_probe_stderr=$context/$mode.$cfmgr_probe_serial.err
    cfmgr_probe_status=reaped cfmgr_probe_pid='' cfmgr_probe_reason=''
    printf '%s\n' "$mode" >>"$base/routes"
    case ${mode#health-} in
    date | status-date) selected_tool=$base/native/date ;;
    native | status-native) selected_tool=$cfmgr_status_awk; set -- "$1" "$base/proc" ;;
    metadata-check | render | status-render | protected | current | storage | uuid | inventory | fields | config | mount | status-fields | status-config | status-mount) selected_tool=$cfmgr_status_awk ;;
    realpath | status-realpath) selected_tool=$base/native/readlink ;;
    space | status-space) selected_tool=$base/native/df ;;
    nvram | status-nvram)
        selected_tool=$base/native/nvram
        if [ "$scenario" = unresolved ]; then cfmgr_probe_status=unresolved cfmgr_probe_pid=fixture; return 3; fi
        [ "$scenario" != budget ] || fake_now=111
        ;;
    esac
    LC_ALL=C "$cfmgr_status_sh" "$helper" "$mode" "$selected_tool" "$context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"
    cfmgr_probe_exit=$?
    return 0
}
if cfmgr_status_native; then code=0; else code=$?; fi
printf 'status-code=%s\n' "$code"
"""


@pytest.mark.parametrize(
    "scenario",
    [
        "normal",
        "corrupt",
        "symlink",
        "fifo",
        "oversized",
        "budget",
        "unresolved",
        "save-guards",
    ],
)
def test_real_status_consumer_native_resources_and_failure_survival(
    status_fixture, config, tools, shell, tmp_path, scenario
):
    source, _proc, _fake = status_fixture
    candidate = source / "config"
    candidate.write_bytes(config)
    candidate.chmod(0o600)
    (source / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (source / "setup-state").chmod(0o600)
    if scenario == "corrupt":
        candidate.write_bytes(b"{broken\n")
    if scenario == "oversized":
        candidate.write_bytes(b" " * 65537)
    if scenario in {"symlink", "fifo"}:
        candidate.unlink()
        if scenario == "symlink":
            candidate.symlink_to(source / "setup-state")
        else:
            os.mkfifo(candidate, 0o600)
    if scenario == "save-guards":
        (source / ".config-save.preparing").write_text("in progress\n")
        (source / ".config-save").mkdir()
        (source / ".config-save.retired").symlink_to(source / "missing-target")
    before = (source / "setup-state").read_bytes()
    result = subprocess.run(
        awk_arguments(
            [
                *shell,
                "-c",
                STATUS_CONSUMER.replace(
                    "if cfmgr_status_native;",
                    "cfmgr_health_active=1 cfmgr_status_page=full\nif cfmgr_status_native;",
                ),
                "status-consumer",
                str(source),
                str(tmp_path),
                scenario,
                tools["sh"],
                tools["awk"],
            ]
        ),
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    out = result.stdout.decode()
    if scenario == "unresolved":
        retained = (tmp_path / "ram/dashboard").read_text()
        assert "uptime: 1234s" in retained and "384/1024 KiB used" in retained
        assert "uptime:" not in out
    else:
        assert "uptime: 1234s" in out and "384/1024 KiB used" in out
    if scenario == "normal":
        assert (
            "Selected WAN: 0" in out
            and "eth0" in out
            and "100.64.1.2 (Shared-CGNAT)" in out
        )
        assert "/opt mount: ext4 mounted" in out and "924 KiB available" in out
        assert (
            "Last verified IPv4: Never" in out and "configured=Off; enabled=Off" in out
        )
    if scenario in {"corrupt", "symlink", "fifo", "oversized"}:
        assert "Configuration: Unavailable" in out
    if scenario == "budget":
        assert "probe budget exhausted" in out
    if scenario == "save-guards":
        warning = (
            "Issue: pending configuration Save/recovery guard; use explicit recovery"
        )
        assert out.count(warning) == 1
        assert (source / ".config-save.preparing").read_text() == "in progress\n"
        assert (source / ".config-save").is_dir()
        assert (source / ".config-save.retired").is_symlink()
    assert (
        "status-code=3" in out if scenario == "unresolved" else "status-code=0" in out
    )
    assert (tmp_path / "ram").exists() == (scenario == "unresolved")
    assert (source / "setup-state").read_bytes() == before
    modes = (tmp_path / "routes").read_text().splitlines()
    assert all(mode.startswith("status-") for mode in modes)
    if scenario == "unresolved":
        assert not {"status-render", "status-render-count"}.intersection(modes)
    assert "TOP_SECRET" not in out


@pytest.mark.parametrize("scenario", ["normal", "corrupt", "unresolved"])
def test_verified_health_extension_uses_local_consumer_and_preserves_owned_cleanup(
    status_fixture, config, tools, shell, tmp_path, scenario
):
    source, _proc, _fake = status_fixture
    candidate = source / "config"
    candidate.write_bytes(b"{broken\n" if scenario == "corrupt" else config)
    candidate.chmod(0o600)
    (source / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (source / "setup-state").chmod(0o600)
    before = candidate.read_bytes()
    prefix = (ROOT / "cfmgr.sh").read_text().split("\ncase ${1-} in", 1)[0]
    prefix = adapt_native(prefix, tmp_path / "jffs", tools, shell)
    consumer = STATUS_CONSUMER.replace(
        "if cfmgr_status_native;", "if cfmgr_status_health_native;"
    )
    result = subprocess.run(
        awk_arguments(
            [
                *shell,
                "-c",
                prefix + "\n" + consumer,
                "health-consumer",
                str(source),
                str(tmp_path),
                scenario,
                tools["sh"],
                tools["awk"],
            ]
        ),
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    out = result.stdout
    assert out.count(b"package.extension [PASS]") == (scenario != "unresolved")
    assert out.count(b"package.backup [FAIL]") == 2 * (scenario != "unresolved")
    assert out.count(b"package.manager [FAIL]") == 2 * (scenario != "unresolved")
    assert b"CFMgr 0.1.0 - local status" not in out
    assert b"uptime:" not in out
    assert b"TOP_SECRET" not in out and b"\x1b" not in out
    assert candidate.read_bytes() == before
    modes = (tmp_path / "routes").read_text().splitlines()
    assert modes and all(mode.startswith("health-") for mode in modes)
    if scenario == "unresolved":
        assert b"status-code=3" in out
        assert (tmp_path / "ram").is_dir()
    else:
        assert b"status-code=0" in out
        assert not (tmp_path / "ram").exists()
        assert b"Selected WAN: 0" in out
        assert (b"Configuration: Unavailable" in out) == (scenario == "corrupt")


@pytest.mark.parametrize("page", ["basic", "health", "standalone-health"])
def test_installed_choice_zero_returns_without_operational_preparation(
    installed_entry, status_fixture, config, tools, shell, tmp_path, page
):
    entry, marker = installed_entry
    support = entry.parent.parent / "addons/CFMgr.d"
    source, _, _ = status_fixture
    for relative in (
        "modules/status.sh",
        "modules/lib/config.sh",
        "modules/lib/storage.sh",
        "modules/helpers/worker.sh",
    ):
        shutil.copyfile(source / relative, support / relative)
    data = support / "config"
    data.write_bytes(config)
    data.chmod(0o600)
    (support / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (support / "setup-state").chmod(0o600)
    functions = STATUS_CONSUMER[
        STATUS_CONSUMER.index("cfmgr_prerequisites_now()") : STATUS_CONSUMER.index(
            "if cfmgr_status_native;"
        )
    ]
    with (support / "modules/status.sh").open("a") as destination:
        destination.write(
            "\nbase="
            + shlex.quote(str(tmp_path))
            + "\nscenario=normal\ncfmgr_status_sh="
            + shlex.quote(tools["sh"])
            + "\ncfmgr_status_awk="
            + shlex.quote(tools["awk"])
            + "\n"
            + functions
        )
    finish_package(entry, support, tools, shell)
    original = data.read_bytes()
    invoked = entry
    if page == "standalone-health":
        invoked = tmp_path / "trusted-standalone.sh"
        shutil.copy2(entry, invoked)
        entry.unlink()
    result = entry_run(
        shell,
        invoked,
        ["--health"] if page != "basic" else [],
        b"0\nao\ne\ne\n",
        terminal=True,
        timeout=10,
    )
    assert result.returncode == 0, result.stderr
    if page == "basic":
        assert b"CFMgr 0.1.0 - local status" in result.stdout
        assert result.stdout.count(b"0 Check status") >= 2
    else:
        assert b"CFMgr 0.1.0 - health diagnostics" in result.stdout
        assert result.stdout.count(b"package.extension [PASS]") == 1
        assert b"package.extension [FAIL]" not in result.stdout
        assert b"0 Check status" not in result.stdout
        assert b"configured=Off; enabled=Off" in result.stdout
        assert b"CFMgr 0.1.0 - local status" not in result.stdout
    assert b"shared dependencies verified" not in result.stdout
    assert (
        not marker.exists()
        and data.read_bytes() == original
        and not (tmp_path / "ram").exists()
    )
    assert all(
        mode.startswith("status-" if page == "basic" else "health-")
        for mode in (tmp_path / "routes").read_text().splitlines()
    )
    if page == "standalone-health":
        assert not entry.exists()


@pytest.mark.parametrize("scenario", ["normal", "budget"])
def test_linux_status_real_supervisor_and_aggregate_budget(
    status_fixture, config, tools, shell, tmp_path, scenario
):
    if sys.platform != "linux":
        pytest.skip("real native status ownership requires Linux proc/FD semantics")
    source, _, fake = status_fixture
    (source / "config").write_bytes(config)
    (source / "config").chmod(0o600)
    (source / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (source / "setup-state").chmod(0o600)
    if scenario == "budget":
        (fake / "nvram").write_text(
            "#!/bin/sh\nprintf '%s\\n' \"$$\" >>"
            + shlex.quote(str(tmp_path / "owned-probes"))
            + "\nexec /bin/sleep 3\n"
        )
    # Exact status consumer body, with literal shell/default path forwarders only.
    original = (source / "modules/status.sh").read_text()
    adapted = original.replace("cfmgr_status_run() {", "cfmgr_status_actual_run() {", 1)
    native_call = (
        'cfmgr_prerequisites_run "$cfmgr_status_mode" "$cfmgr_status_context" /bin/sh '
        + "\\\n"
    )
    selected_call = native_call.replace("/bin/sh ", shlex.quote(tools["sh"]) + " ")
    assert original.count(native_call) == 1
    adapted = adapted.replace(native_call, selected_call, 1)
    assert (
        adapted.replace(selected_call, native_call, 1).replace(
            "cfmgr_status_actual_run() {", "cfmgr_status_run() {", 1
        )
        == original
    )
    alias = source / "status-supervised.sh"
    alias.write_text(adapted)
    driver = r"""
. "$1/modules/lib/execution.sh"
. "$2/status-supervised.sh"
cfmgr_source=$2 base=$3
CFMGR_VERSION=0.1.0 CFMGR_REPOSITORY=https://github.com/example/CFMgr CFMGR_BRANCH=develop
cfmgr_status_prepare() {
    cfmgr_status_context=$base/ram
    mkdir -m 700 "$cfmgr_status_context" || return 1
    exec 9<"$cfmgr_status_context"
    cfmgr_status_interrupted=0 cfmgr_status_budget_exhausted=0 cfmgr_probe_pid=''
    cfmgr_prerequisites_now || return 1
    cfmgr_status_deadline=$((cfmgr_probe_now + 10))
    cfmgr_status_final_deadline='' cfmgr_status_final_operations=0
}
cfmgr_status_run() {
    selected_mode=$1 selected_tool=$2; shift 2
    printf '%s\n' "$selected_mode" >>"$base/routes"
    case $selected_mode in
    status-date) selected_tool=$base/native/date ;;
    status-nvram) selected_tool=$base/native/nvram ;;
    space | status-space) selected_tool=$base/native/df ;;
    realpath | status-realpath) selected_tool=$base/native/readlink ;;
    status-native) set -- "$1" "$base/proc" ;;
    esac
    cfmgr_status_actual_run "$selected_mode" "$selected_tool" "$@"
}
cfmgr_status_native
"""
    driver = driver.replace(
        "cfmgr_status_native\n", pause_definition(shell) + "\ncfmgr_status_native\n", 1
    )
    result = subprocess.run(
        awk_arguments(
            [
                *shell,
                "-c",
                driver,
                "status-real-supervision",
                str(ROOT),
                str(source),
                str(tmp_path),
            ]
        ),
        capture_output=True,
        check=False,
        timeout=18,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"uptime: 1234s" in result.stdout
    assert not (tmp_path / "ram").exists()
    if scenario == "normal":
        assert b"Last verified IPv4: Never" in result.stdout
    else:
        assert b"probe budget exhausted" in result.stdout
        for pid in (tmp_path / "owned-probes").read_text().splitlines():
            assert not Path(f"/proc/{pid}").exists(), "bounded collector was orphaned"


def test_health_inventory_is_strict_private_and_caps_ddns_schedule(
    commands, health_config
):
    value = json.loads(json.dumps(health_config))
    value["ddns"]["records"].extend(
        [
            {"id": f"local-{i}", "name": f"node{i}.example.test", "type": "A"}
            for i in range(3)
        ]
    )
    result = health_projection(commands, value, mode="health-inventory")
    assert result.returncode == 0, result.stderr
    lines = result.stdout.decode().splitlines()
    assert lines[0] == "CFMGR-HEALTH-INVENTORY 1" and lines[-1] == "END"
    assert sum(line.startswith("target ddns ") for line in lines) == 3
    assert "additional ddns 2" in lines
    assert "family ip_sync primary ipv4" in lines
    assert (
        HEALTH_SECRET.encode() not in result.stdout
        and ACCOUNT.encode() not in result.stdout
    )
    value["history"]["ddns"] = {"status": {"schema": "malformed"}}
    refused = health_projection(commands, value, mode="health-inventory")
    assert refused.returncode != 0 and refused.stdout == b""


@pytest.mark.parametrize(
    "flags,interface,expected",
    [
        ("00", "eth0", True),
        ("80", "eth0", True),
        ("08", "eth0", False),
        ("20", "eth0", False),
        ("40", "eth0", False),
        ("00", "eth1", False),
    ],
)
def test_health_ipv6_eligibility_requires_current_usable_selected_interface(
    commands, tmp_path, flags, interface, expected
):
    source = tmp_path / "if_inet6"
    source.write_text(
        f"26064700000000000000000000001111 02 40 00 {flags} {interface}\n"
    )
    result = subprocess.run(
        [*commands[1], awk_program("health_local"), str(source), "eth0", "-"],
        env={**os.environ, "CFMGR_HEALTH_LOCAL": "health-current"},
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert (result.returncode == 0) == expected
    assert result.stdout == (b"current-global-ipv6\n" if expected else b"")


def test_health_provider_schedule_and_safe_staged_rows(shell, tmp_path):
    inventory = tmp_path / "inventory"
    inventory.write_text(
        "CFMGR-HEALTH-INVENTORY 1\nfeature ddns 1 1 eligible\n"
        "target ddns dns local1 4\ntarget ddns dns local2 6\ntarget ddns dns local3 4\nadditional ddns 2\n"
        "feature ip_sync 1 1 eligible\ntarget ip_sync list primary 4\nfamily ip_sync primary ipv4\n"
        "target ip_sync list secondary 4\nfamily ip_sync secondary ipv6\nfeature cloudflared 1 1 eligible\nEND\n"
    )
    script = r"""
. "$1/modules/status.sh"
cfmgr_status_context=$2 cfmgr_health_inventory=$2/inventory cfmgr_health_rows=0 cfmgr_health_staging=1 cfmgr_health_ipv6_ready=1
exec 3>"$2/rows"
cfmgr_health_get() {
    /usr/bin/printf '%s %s %s %s\n' "$@" >>"$cfmgr_status_context/requests"
    cfmgr_health_result=observed-read cfmgr_health_result_file=$cfmgr_status_context/response
    cfmgr_health_scope_eligible=1 cfmgr_health_scope=$1.scope
    /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 1 verified 1 api-read END\n' >"$cfmgr_health_result_file"
}
cfmgr_health_provider_collect || exit 10
[ "$cfmgr_health_rows" = 15 ] || exit 11
cfmgr_health_row invalid PASS 'bad	detail' current action report
[ "$?" = 2 ] || exit 12
"""
    result = subprocess.run(
        [*shell, "-c", script, "schedule", str(ROOT), str(tmp_path)],
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    requests = (tmp_path / "requests").read_text().splitlines()
    assert len(requests) == 12
    assert requests[-2:] == ["ddns trace - 4", "ddns trace - 6"]
    rows = (tmp_path / "rows").read_text().splitlines()
    assert len(rows) == 15 and all(len(line.split("\t")) == 6 for line in rows)
    assert any(line.startswith("ddns.additional\tUNKNOWN\t") for line in rows)
    assert any(line.startswith("ip_sync.secondary.ipv6\tUNKNOWN\t") for line in rows)


def test_health_provider_comparison_controller_keeps_prior_receipt_on_scope_hold(
    shell, tools, tmp_path
):
    (tmp_path / "inventory").write_text(
        "CFMGR-HEALTH-INVENTORY 1\nfeature ddns 1 1 eligible\n"
        "target ddns dns first 4\ntarget ddns dns held 4\ntarget ddns dns later 4\n"
        "feature ip_sync 1 1 eligible\ntarget ip_sync list primary 4\n"
        "family ip_sync primary ipv6\nfeature cloudflared 0 0 unconfigured\nEND\n"
    )
    script = r"""
. "$1/modules/status.sh"
cfmgr_source=$1 cfmgr_status_context=$2 cfmgr_health_inventory=$2/inventory
test_shell=$3 test_awk=$4
cfmgr_health_active=1 cfmgr_health_operations=0 cfmgr_health_files=0 cfmgr_health_bytes=0
cfmgr_health_collect_deadline=40 cfmgr_health_rows=0 cfmgr_health_staging=1 cfmgr_health_ipv6_ready=0 cfmgr_health_scope_holds=''
cfmgr_health_owned='' cfmgr_health_compare_count=0 cfmgr_health_compare_pending=''
cfmgr_status_attachment_ok() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=0; }
exec 3>"$2/rows"
cfmgr_health_get_serial=0
cfmgr_health_get() {
    cfmgr_health_scope=$1.scope cfmgr_health_scope_eligible=1 cfmgr_health_result=observed-read
    if [ "$2:$3" = dns:later ]; then cfmgr_health_result=scope-auth-hold; return 1; fi
    /usr/bin/printf '%s %s %s %s\n' "$@" >>"$cfmgr_status_context/requests"
    cfmgr_health_get_serial=$((cfmgr_health_get_serial + 1))
    if [ "$2:$3" = dns:held ]; then
        cfmgr_health_scope_holds="$cfmgr_health_scope_holds
$cfmgr_health_scope"
        cfmgr_health_result=auth-rejected-read
        return 1
    fi
    case $2 in
    dns)
        cfmgr_health_result_file=$cfmgr_status_context/health-response.$cfmgr_health_get_serial.out
        /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 2 verified 1 dns 4\nVALUE 4 08080808 32\nEND 1\n' >"$cfmgr_health_result_file"
        ;;
    items)
        cfmgr_health_result_file=$cfmgr_status_context/health-response.$cfmgr_health_get_serial.out
        /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 2 verified 1 items mixed\nVALUE 4 08000000 8\nEND 1\n' >"$cfmgr_health_result_file"
        ;;
    trace)
        cfmgr_health_result_file=$cfmgr_status_context/health-trace.$cfmgr_health_get_serial.out
        /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 1 observed 1 ipv4:8.8.8.8 END\n' >"$cfmgr_health_result_file"
        ;;
    *)
        cfmgr_health_result_file=$cfmgr_status_context/health-response.$cfmgr_health_get_serial.out
        /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 1 verified 1 api-read END\n' >"$cfmgr_health_result_file"
        ;;
    esac
    cfmgr_health_owned="$cfmgr_health_owned
${cfmgr_health_result_file##*/}"
}
cfmgr_health_run() {
    [ "$1" = health-compare ] || return 2
    if "$test_shell" "$cfmgr_source/modules/helpers/worker.sh" health-compare "$test_awk" "$cfmgr_status_context" "$3" "$4" >"$cfmgr_status_context/compare.out" 2>"$cfmgr_status_context/compare.err"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi
    cfmgr_probe_stdout=$cfmgr_status_context/compare.out cfmgr_probe_stderr=$cfmgr_status_context/compare.err
    return 0
}
cfmgr_health_provider_collect
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "compare-controller",
            str(ROOT),
            str(tmp_path),
            tools["sh"],
            tools["awk"],
        ],
        capture_output=True,
        timeout=5,
        check=False,
    )
    assert (result.returncode, result.stderr) == (0, b""), result.stdout
    requests = (tmp_path / "requests").read_text().splitlines()
    assert requests == [
        "ddns zone - 4",
        "ddns dns first 4",
        "ddns dns held 4",
        "ip_sync list primary 4",
        "ip_sync items primary 4",
        "ip_sync trace - 4",
    ]
    rows = (tmp_path / "rows").read_text().splitlines()
    assert any(line.startswith("ddns.record.1\tPASS\t") for line in rows)
    assert any(line.startswith("ddns.record.2\tUNKNOWN\t") for line in rows)
    assert any(line.startswith("ip_sync.primary.ipv6\tUNKNOWN\t") for line in rows)
    assert any(line.startswith("ddns.record.3\tSKIP\t") for line in rows)


@pytest.mark.parametrize(
    "case,traces", [("late-auth", 0), ("transient", 1), ("independent", 1)]
)
def test_health_public_candidates_recheck_late_scope_holds(
    shell, tmp_path, case, traces
):
    (tmp_path / "inventory").write_text(
        "CFMGR-HEALTH-INVENTORY 1\nfeature ddns 1 1 eligible\ntarget ddns dns record 4\n"
        + (
            "feature ip_sync 1 1 eligible\ntarget ip_sync list primary 4\n"
            if case == "independent"
            else ""
        )
        + "END\n"
    )
    script = r"""
. "$1/modules/status.sh"
cfmgr_status_context=$2 cfmgr_health_inventory=$2/inventory cfmgr_health_rows=0 cfmgr_health_staging=1 cfmgr_health_ipv6_ready=0 cfmgr_health_scope_holds='' test_case=$3
exec 3>"$2/rows"
cfmgr_health_get() {
    cfmgr_health_scope_eligible=1 cfmgr_health_scope=$1.scope cfmgr_health_result=observed-read cfmgr_health_result_file=$cfmgr_status_context/response
    /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 1 verified 1 api-read END\n' >"$cfmgr_health_result_file"
    if [ "$2" = trace ]; then /usr/bin/printf '%s\n' "$1" >>"$cfmgr_status_context/traces"; fi
    if [ "$1:$2" = ddns:dns ] && [ "$test_case" != transient ]; then
        cfmgr_health_scope_holds="$cfmgr_health_scope_holds
$cfmgr_health_scope"
        cfmgr_health_result=auth-rejected-read
        return 1
    fi
    if [ "$test_case" = transient ] && [ "$2" != trace ]; then cfmgr_health_result=transient-transport; return 1; fi
}
cfmgr_health_provider_collect
"""
    result = subprocess.run(
        [*shell, "-c", script, "candidates", str(ROOT), str(tmp_path), case],
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    trace_file = tmp_path / "traces"
    assert (
        len(trace_file.read_text().splitlines()) if trace_file.exists() else 0
    ) == traces
    if case == "independent":
        assert trace_file.read_text() == "ip_sync\n"


@pytest.mark.parametrize(
    "mode,owner,kind,accepted",
    [
        ("-rwxr-xr-x", "0", "file", True),
        ("-rwxrwxr-x", "0", "file", False),
        ("-rwxr-xrwx", "0", "file", False),
        ("-rwxr-xr-x", "1", "file", False),
        ("lrwxrwxrwx", "0", "file", False),
        ("-rwxr-xr-x", "0", "directory", False),
    ],
)
def test_health_native_metadata_requires_protected_root_owned_type(
    commands, tmp_path, mode, owner, kind, accepted
):
    metadata = tmp_path / "metadata"
    metadata.write_text(f"1 {mode} 1 {owner} 0 123 Oct 21 native\n")
    result = subprocess.run(
        [*commands[1], awk_program("health_local"), str(metadata), kind, "-"],
        env={**os.environ, "CFMGR_HEALTH_LOCAL": "health-protected"},
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert (result.returncode == 0) == accepted
    assert result.stdout == (b"protected\n" if accepted else b"")


def test_health_storage_identity_requires_complete_retained_tuple(
    commands, health_config, tmp_path
):
    projected = health_projection(commands, health_config, mode="health-inventory")
    assert projected.returncode == 0
    inventory = tmp_path / "inventory"
    inventory.write_bytes(projected.stdout)
    saved = health_config["storage"]["entware"]
    mount = tmp_path / "mount"
    mount.write_text(
        f"3\t1\t8:1\t{saved['root']}\t/mnt/usb\t{saved['filesystem']}\t/dev/sda1\trw\trw\n"
    )
    expected = "/mnt/usb" + (
        "" if saved["relative"] == "." else "/" + saved["relative"]
    )
    argv = [
        *commands[1],
        awk_program("health_local"),
        str(mount),
        str(inventory),
        expected,
    ]
    env = {**os.environ, "CFMGR_HEALTH_LOCAL": "health-storage"}
    valid = subprocess.run(argv, env=env, capture_output=True, timeout=3, check=False)
    assert (
        valid.returncode == 0
        and valid.stdout.decode().split("\t")[0] == saved["uuid"].lower()
    )
    mount.write_text(mount.read_text().replace("\trw\trw\n", "\trw,noexec\trw\n"))
    refused = subprocess.run(argv, env=env, capture_output=True, timeout=3, check=False)
    assert refused.returncode != 0 and refused.stdout == b""


@pytest.mark.parametrize(
    "alias,source,payload",
    [
        ("health-wc-jq", "health-jq-good", b"true\n"),
        ("health-wc-sha", "health-sha-bytes", b"abc  bytes\n"),
    ],
)
def test_health_capability_count_aliases_select_one_private_receipt(
    shell, tmp_path, alias, source, payload
):
    (tmp_path / f"{source}.1.out").write_bytes(payload)
    argv = [
        *shell,
        str(ROOT / "modules/helpers/worker.sh"),
        alias,
        shutil.which("wc"),
        str(tmp_path),
    ]
    valid = subprocess.run(argv, capture_output=True, check=False, timeout=3)
    assert (
        valid.returncode == 0
        and int(valid.stdout) == len(payload)
        and valid.stderr == b""
    )
    (tmp_path / f"{source}.2.out").write_bytes(payload)
    ambiguous = subprocess.run(argv, capture_output=True, check=False, timeout=3)
    assert ambiguous.returncode != 0 and ambiguous.stdout == b""


def test_health_canonical_path_refuses_additional_or_incomplete_lines(shell, tmp_path):
    script = r"""
. "$1/modules/status.sh"
cfmgr_probe_stdout=$2/path cfmgr_probe_stderr=$2/empty cfmgr_probe_exit=0
: >"$cfmgr_probe_stderr"
cfmgr_health_run() { return 0; }
printf '/mnt/usb/entware\n' >"$cfmgr_probe_stdout"
cfmgr_health_canonical /opt || exit 10
printf '/mnt/usb/entware\nother\n' >"$cfmgr_probe_stdout"
if cfmgr_health_canonical /opt; then exit 11; fi
printf '/mnt/usb/entware' >"$cfmgr_probe_stdout"
if cfmgr_health_canonical /opt; then exit 12; fi
"""
    result = subprocess.run(
        [*shell, "-c", script, "canonical", str(ROOT), str(tmp_path)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_report_finalization_deadlines_are_immutable_and_cannot_restart_collection(
    shell,
):
    script = r"""
. "$1/modules/status.sh"
. "$1/modules/lib/execution.sh"
cfmgr_status_attachment_ok() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=$clock; }
cfmgr_probe_pid='' cfmgr_status_deadline=110 cfmgr_status_final_deadline='' cfmgr_status_final_operations=0 clock=105
cfmgr_status_final_begin || exit 10
[ "$cfmgr_status_final_deadline" = 108 ] || exit 11
clock=106
cfmgr_status_final_begin || exit 12
[ "$cfmgr_status_final_deadline" = 108 ] || exit 13
for stage in 1 2 3; do cfmgr_status_final_reserve || exit 14; done
if cfmgr_status_final_reserve; then exit 15; fi
[ "$cfmgr_status_final_operations" = 3 ] || exit 16
cfmgr_status_run status-count /not-a-tool /not-a-file
[ "$?" = 1 ] || exit 17
cfmgr_probe_now=106 cfmgr_probe_deadline=108
cfmgr_prerequisites_report_deadline 108 || exit 18
[ "$cfmgr_probe_deadline" = 108 ] || exit 19
cfmgr_probe_now=107 cfmgr_probe_deadline=109
cfmgr_prerequisites_report_deadline 108 || exit 20
[ "$cfmgr_probe_deadline" = 108 ] || exit 21
cfmgr_probe_now=108
if cfmgr_prerequisites_report_deadline 108; then exit 22; fi
cfmgr_status_final_deadline='' clock=111
cfmgr_status_final_begin || exit 23
[ "$cfmgr_status_final_deadline" = 113 ] || exit 24
cfmgr_probe_pid=owned cfmgr_probe_status=unresolved
cfmgr_prerequisites_run status-render
[ "$?" = 3 ] && [ "$cfmgr_probe_pid" = owned ] || exit 25
cfmgr_probe_pid=''
cfmgr_health_active=1 cfmgr_health_deadline=145 cfmgr_health_collect_deadline=140 cfmgr_health_final_deadline='' clock=110
cfmgr_health_final_operations=0 cfmgr_health_final_files=0 cfmgr_health_final_bytes=0
cfmgr_health_operations=504 cfmgr_health_files=1136 cfmgr_health_bytes=327680 cfmgr_health_owned='' cfmgr_probe_serial=20
cfmgr_health_final_begin || exit 26
[ "$cfmgr_health_final_deadline" = 115 ] || exit 27
clock=111
cfmgr_health_final_begin || exit 28
[ "$cfmgr_health_final_deadline" = 115 ] || exit 29
cfmgr_health_reserve health-render || exit 30
cfmgr_health_reserve health-render-count || exit 31
[ "$cfmgr_health_final_operations:$cfmgr_health_final_files:$cfmgr_health_final_bytes" = 2:4:790528 ] || exit 32
[ "$cfmgr_health_operations:$cfmgr_health_files:$cfmgr_health_bytes" = 504:1136:327680 ] || exit 33
cfmgr_health_reserve health-date
[ "$?" = 1 ] || exit 34
cfmgr_health_stage_reserve dashboard 32768
[ "$?" = 1 ] && [ "$cfmgr_health_files:$cfmgr_health_bytes" = 1136:327680 ] || exit 43
cfmgr_probe_now=110 cfmgr_probe_deadline=112
cfmgr_prerequisites_report_deadline "$cfmgr_health_final_deadline" || exit 35
[ "$cfmgr_probe_deadline" = 112 ] || exit 36
cfmgr_probe_now=114 cfmgr_probe_deadline=116
cfmgr_prerequisites_report_deadline "$cfmgr_health_final_deadline" || exit 37
[ "$cfmgr_probe_deadline" = 115 ] || exit 38
clock=115
if cfmgr_health_reserve health-render-count; then exit 39; fi
cfmgr_health_final_deadline='' clock=143
cfmgr_health_final_begin || exit 40
[ "$cfmgr_health_final_deadline" = 145 ] || exit 41
cfmgr_probe_pid=owned cfmgr_probe_status=unresolved
cfmgr_prerequisites_run health-render
[ "$?" = 3 ] && [ "$cfmgr_probe_pid" = owned ] || exit 42
"""
    result = subprocess.run(
        [*shell, "-c", script, "report-finalization", str(ROOT)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_basic_renderer_failure_uses_only_fixed_safe_fallback(
    status_fixture, tools, shell, tmp_path
):
    source, _, _ = status_fixture
    driver = STATUS_CONSUMER.replace(
        "if cfmgr_status_native;",
        'cfmgr_status_work() { printf "PRIVATE-CANARY\\033[31m\\n"; }\nif cfmgr_status_native;',
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            driver,
            "render-failure",
            str(source),
            str(tmp_path),
            "normal",
            tools["sh"],
            tools["awk"],
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0 and result.stderr == b""
    assert (
        result.stdout
        == b"Report\nnot\navailable\nCheck\nlocal\nstatus\nstatus-code=1\n"
    )
    assert not (tmp_path / "ram").exists()


def test_health_scope_tiny_bound_clears_long_ineligible_identity(
    commands, health_config
):
    value = json.loads(json.dumps(health_config))
    credential = value["credentials"].pop("api-a")
    long_ref = "r" * 3000
    value["credentials"][long_ref] = credential
    value["ddns"]["credential_ref"] = long_ref
    denied = health_projection(commands, value)
    assert denied.returncode == 0, denied.stderr
    fields = denied.stdout.decode().split()
    assert fields[2] == "credential-local-only"
    assert [fields[i] for i in (4, 6, 7, 8)] == ["-"] * 4
    assert len(denied.stdout) < 1024 and long_ref.encode() not in denied.stdout
    assert health_projection(commands, value, "health-request").returncode != 0
    value["credentials"].pop(long_ref)
    reference = "r" * 64
    value["credentials"][reference] = {**credential, "value": "A" * 2048}
    value["ddns"]["credential_ref"] = reference
    name = "*." + ".".join(["a" * 63] * 3 + ["b" * 59])
    assert len(name) == 253
    value["ddns"]["records"][1]["name"] = name
    scope = health_projection(commands, value, selector="local-record-6", kind="dns")
    request = health_projection(
        commands, value, "health-request", selector="local-record-6", kind="dns"
    )
    assert scope.returncode == request.returncode == 0
    assert len(scope.stdout) <= 1024 and len(request.stdout) <= 4096
    assert ("A" * 2048).encode() not in scope.stdout
    assert b"%2A." in request.stdout and ("A" * 2048).encode() in request.stdout


def metadata_batch(commands, tmp_path, profile, spec, records):
    raw = tmp_path / "metadata-batch"
    raw.write_text("".join(records))
    return subprocess.run(
        [*commands[1], awk_program("health_metadata"), str(raw), profile, spec],
        capture_output=True,
        check=False,
        timeout=3,
    )


def native_metadata_records():
    paths = [
        "/",
        "/usr",
        "/usr/sbin",
        "/usr/sbin/curl",
        "/usr/sbin/openssl",
        "/rom",
        "/rom/etc",
        "/rom/etc/ssl",
        "/rom/etc/ssl/certs",
        "/rom/etc/ssl/certs/ca-certificates.crt",
        "/usr/bin",
        "/bin",
        "/bin/busybox",
    ]
    files = {
        "/usr/sbin/curl",
        "/usr/sbin/openssl",
        "/rom/etc/ssl/certs/ca-certificates.crt",
        "/bin/busybox",
    }
    return [
        f"{i + 1} {'-rwxr-xr-x' if path in files else 'drwxr-xr-x'} 1 0 0 100 Oct 21 12:00 {path}\n"
        for i, path in enumerate(paths)
    ]


@pytest.mark.parametrize(
    "case,expected",
    [
        ("normal", (1, 1, 1, 1)),
        ("missing-flock", (1, 1, 1, 0)),
        ("duplicate-curl", (0, 1, 1, 1)),
        ("missing-ca-parent", (1, 1, 0, 1)),
        ("writable-shared", (0, 0, 1, 0)),
        ("wrong-owner-openssl", (1, 0, 1, 1)),
        ("symlink-curl", (0, 1, 1, 1)),
        ("regular-flock", (1, 1, 1, 1)),
    ],
)
def test_health_native_batch_preserves_independent_exact_members(
    commands, tmp_path, case, expected
):
    records = native_metadata_records()
    spec = "busybox 1 1 1 1"
    if case == "missing-flock":
        records = records[:10]
        spec = "missing 1 1 1 0"
    if case == "duplicate-curl":
        records.append(records[3])
    if case == "missing-ca-parent":
        records.pop(7)
    if case == "writable-shared":
        records[1] = records[1].replace("drwxr-xr-x", "drwxrwxr-x")
    if case == "wrong-owner-openssl":
        records[4] = records[4].replace(" 1 0 0 ", " 1 7 0 ")
    if case == "symlink-curl":
        records[3] = (
            records[3]
            .replace("-rwxr-xr-x", "lrwxrwxrwx")
            .replace("/usr/sbin/curl\n", "/usr/sbin/curl -> /untrusted/curl\n")
        )
    if case == "regular-flock":
        records = records[:11] + [
            "14 -rwxr-xr-x 1 0 0 100 Oct 21 12:00 /usr/bin/flock\n"
        ]
        spec = "regular 1 1 1 1"
    result = metadata_batch(commands, tmp_path, "native", spec, list(reversed(records)))
    assert result.returncode == 0 and result.stderr == b""
    assert (
        result.stdout
        == (
            "CFMGR-HEALTH-METADATA 1\n"
            + "".join(
                f"member {member} {state}\n"
                for member, state in zip(
                    ("curl", "openssl", "ca", "flock"), expected, strict=True
                )
            )
            + "END\n"
        ).encode()
    )


def test_health_entware_batch_handles_spaces_and_missing_tools_independently(
    commands, tmp_path
):
    root = "/mnt/volume with spaces"
    opt = root + "/entware"
    spec = "\n".join(
        f"{role}\t{kind}\t{path}"
        for role, kind, path in [
            ("storage", "directory", root),
            ("storage", "directory", opt),
            ("jq", "directory", root),
            ("jq", "directory", opt),
            ("jq", "directory", opt + "/bin"),
            ("jq", "file", opt + "/bin/jq"),
            ("timeout", "directory", root),
            ("timeout", "directory", opt),
            ("timeout", "directory", opt + "/bin"),
            ("timeout", "file", opt + "/bin/timeout"),
        ]
    )
    records = [
        f"{i + 1} {'-rwxr-xr-x' if path.endswith('/jq') else 'drwxr-xr-x'} 1 0 0 100 Oct 21 12:00 {path}\n"
        for i, path in enumerate((root, opt, opt + "/bin", opt + "/bin/jq"))
    ]
    result = metadata_batch(
        commands, tmp_path, "entware", spec, list(reversed(records))
    )
    assert result.returncode == 0 and result.stderr == b""
    assert b"member storage 1\nmember jq 1\nmember timeout 0\n" in result.stdout
    assert b"member sha 0\nmember flock 0\nmember dig 0\n" in result.stdout
    duplicate = metadata_batch(
        commands, tmp_path, "entware", spec, records + [records[-1]]
    )
    assert b"member storage 1\nmember jq 0\nmember timeout 0\n" in duplicate.stdout
    unexpected = metadata_batch(
        commands,
        tmp_path,
        "entware",
        spec,
        records + [records[-1].replace("/jq\n", "/jq-extra\n")],
    )
    assert unexpected.returncode == 0
    assert all(
        line.endswith(b" 0")
        for line in unexpected.stdout.splitlines()
        if line.startswith(b"member ")
    )


def test_health_tiny_allowlist_reserves_native_and_host_units(shell):
    script = r"""
. "$1/modules/status.sh"
for mode in health-scope health-frame health-request-check health-trace health-count health-render-count health-wc-jq health-wc-sha health-count-get health-current health-uuid health-date health-native health-jq-good health-jq-bad health-sha-bytes health-sha-good health-sha-bad health-timeout-exit health-timeout-expiry health-flock-first health-flock-compete health-flock-after health-flock-release health-flock-finish health-flock-entware-first health-flock-entware-compete health-flock-entware-after health-flock-entware-release health-flock-entware-finish health-curl-features health-ca-pem health-ca-decode health-curl-offline; do
    cfmgr_health_mode "$mode" || exit 10
    [ "$cfmgr_health_mode_limit:$cfmgr_health_mode_bytes:$cfmgr_health_mode_files" = 2:4096:2 ] || exit 11
done
for mode in health-request health-response health-compare health-metadata health-native-metadata health-metadata-check health-realpath health-mount health-storage health-inventory health-curl-version health-dig-version health-fields health-config health-nvram health-space health-protected health-uname health-blkid; do
    cfmgr_health_mode "$mode" || exit 12
    [ "$cfmgr_health_mode_limit:$cfmgr_health_mode_bytes" = 8:16384 ] || exit 13
done
cfmgr_health_mode health-entware-metadata || exit 14
[ "$cfmgr_health_mode_limit:$cfmgr_health_mode_bytes" = 128:262144 ] || exit 15
"""
    result = subprocess.run(
        [*shell, "-c", script, "quota-table", str(ROOT)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize("damage", ["valid", "outside", "symlink", "wrong-role"])
def test_health_count_get_worker_counts_only_owned_get_files(shell, tmp_path, damage):
    context = tmp_path / "private context"
    context.mkdir()
    http = context / "health-get.1.out"
    body = context / "health-get.1.body"
    headers = context / "health-get.1.headers"
    http.write_bytes(b"200\n")
    body.write_bytes(b"body")
    headers.write_bytes(b"head")
    if damage == "symlink":
        headers.unlink()
        headers.symlink_to(body)
    elif damage == "wrong-role":
        body.rename(context / "health-get.1.headers")
    outside = tmp_path / "outside.body"
    outside.write_bytes(b"outside")
    operands = [str(http), str(body), str(headers)]
    if damage == "outside":
        operands[1] = str(outside)
    if damage == "wrong-role":
        operands[2] = str(context / "health-get.1.body")
    result = subprocess.run(
        [
            *shell,
            str(ROOT / "modules/helpers/worker.sh"),
            "health-count-get",
            shutil.which("wc") or "/usr/bin/wc",
            str(context),
            *operands,
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode == 0) == (damage == "valid")
    assert result.stderr == b""
    if damage == "valid":
        assert len(result.stdout.splitlines()) == 4
        assert result.stdout.splitlines()[-1].rstrip().endswith(b"total")


@pytest.mark.parametrize(
    "damage,accepted,size_valid",
    [
        ("valid", True, 1),
        ("extra-line", False, 0),
        ("partial-trailing", False, 0),
        ("wrong-label", False, 0),
        ("bad-sum", False, 0),
        ("wrong-http-size", False, 0),
        ("oversize-body", False, 1),
    ],
)
def test_health_count_get_controller_validates_native_wc_frame(
    shell, tmp_path, damage, accepted, size_valid
):
    script = r"""
. "$1/modules/status.sh"
cfmgr_status_context=$2 cfmgr_health_http_file=$2/health-get.1.out
cfmgr_health_body=$2/health-get.1.body cfmgr_health_headers=$2/health-get.1.headers
: >"$2/count.err"
cfmgr_probe_stderr=$2/count.err cfmgr_probe_exit=0
cfmgr_health_run() {
    cfmgr_probe_stdout=$cfmgr_status_context/count.out
    case $test_case in
    oversize-body) /usr/bin/printf '4 %s\n32769 %s\n4 %s\n32777 total\n' "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    wrong-http-size) /usr/bin/printf '3 %s\n4 %s\n4 %s\n11 total\n' "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    wrong-label) /usr/bin/printf '4 wrong\n4 %s\n4 %s\n12 total\n' "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    bad-sum) /usr/bin/printf '4 %s\n4 %s\n4 %s\n13 total\n' "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    extra-line) /usr/bin/printf '4 %s\n4 %s\n4 %s\n12 total\nextra\n' "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    partial-trailing) /usr/bin/printf '4 %s\n4 %s\n4 %s\n12 total\nextra' "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    *) /usr/bin/printf '4 %s\n4 %s\n4 %s\n12 total\n' "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout" ;;
    esac
}
test_case=$3
expected=$4 wanted_valid=$5
if cfmgr_health_sizes; then code=0; else code=$?; fi
[ "$code:$cfmgr_health_size_valid" = "$expected:$wanted_valid" ] || {
    /usr/bin/printf '%s %s %s %s %s %s\n' "$code" "$cfmgr_health_size_valid" "${cfmgr_health_http_bytes:-missing}" "${cfmgr_health_body_bytes:-missing}" "${cfmgr_health_header_bytes:-missing}" "${cfmgr_health_count_total:-missing}"
    exit 10
}
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "count-frame",
            str(ROOT),
            str(tmp_path),
            damage,
            str(0 if accepted else 1),
            str(size_valid),
        ],
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize(
    "case,expected,held,stopped",
    [
        ("success", 0, 0, 0),
        ("auth-large", 1, 1, 0),
        ("throttle-large", 1, 0, 1),
        ("malformed-count", 1, 0, 0),
        ("malformed-status", 1, 0, 0),
    ],
)
def test_health_get_counts_status_before_http_hold_and_size_rejection(
    shell, tools, tmp_path, case, expected, held, stopped
):
    script = r"""
. "$1/modules/status.sh"
cfmgr_source=$1 cfmgr_status_context=$2 cfmgr_health_transport=ready cfmgr_health_clock_ready=1
cfmgr_health_scope_holds='' cfmgr_health_provider_stop=0 cfmgr_probe_serial=4 modes=''
: >"$2/empty"
cfmgr_health_project() {
    case $1 in
    health-scope)
        cfmgr_probe_stdout=$cfmgr_status_context/scope
        /usr/bin/printf 'CFMGR-HEALTH-SCOPE 1 eligible ddns ddns.zone dns resource name A 96 END\n' >"$cfmgr_probe_stdout"
        ;;
    health-request)
        cfmgr_probe_stdout=$cfmgr_status_context/request
        /usr/bin/printf 'url = "https://api.cloudflare.com/client/v4/zones/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"\nheader = "Authorization: Bearer fixture-token"\n' >"$cfmgr_probe_stdout"
        ;;
    esac
    cfmgr_probe_exit=0 cfmgr_probe_stderr=$cfmgr_status_context/empty
}
cfmgr_health_count() { cfmgr_health_size=96; }
cfmgr_health_frame() {
    case $2 in scope | response) return 0 ;; *) exit 19 ;; esac
}
cfmgr_health_run() {
    modes="$modes $1"
    cfmgr_probe_stderr=$cfmgr_status_context/empty cfmgr_probe_exit=0
    case $1 in
    health-request-check) cfmgr_probe_stdout=$cfmgr_status_context/empty ;;
    health-get)
        cfmgr_probe_stdout=$cfmgr_status_context/health-get.5.out cfmgr_probe_exit=0
        cfmgr_health_body=$cfmgr_status_context/health-get.5.body
        cfmgr_health_headers=$cfmgr_status_context/health-get.5.headers
        case $test_case in
        auth-large) code=403 size=32769 ;;
        throttle-large) code=429 size=32769 ;;
        malformed-status) code=abc size=4 ;;
        *) code=200 size=4 ;;
        esac
        /usr/bin/printf '%s\n' "$code" >"$cfmgr_probe_stdout"
        "$test_dd" if=/dev/zero of="$cfmgr_health_body" bs=1 count="$size" 2>/dev/null
        /usr/bin/printf 'head' >"$cfmgr_health_headers"
        ;;
    health-count-get)
        cfmgr_probe_stdout=$cfmgr_status_context/count.out
        if [ "$test_case" = malformed-count ]; then
            /usr/bin/printf '4 wrong\n4 %s\n4 %s\n12 total\n' "$cfmgr_health_body" "$cfmgr_health_headers" >"$cfmgr_probe_stdout"
        else
            /usr/bin/printf '4 %s\n%s %s\n4 %s\n%s total\n' "$cfmgr_health_http_file" "$size" "$cfmgr_health_body" "$cfmgr_health_headers" "$((size + 8))" >"$cfmgr_probe_stdout"
        fi
        ;;
    health-response)
        cfmgr_probe_stdout=$cfmgr_status_context/response
        /usr/bin/printf 'CFMGR-HEALTH-RESPONSE 1 verified 1 api-read END\n' >"$cfmgr_probe_stdout"
        ;;
    *) return 2 ;;
    esac
}
test_case=$3
test_dd=$6 test_wc=$7
if _cfmgr_health_get ddns zone - 4; then code=0; else code=$?; fi
[ "$code" = "$4" ] || exit 10
observed_hold=0
[ -z "$cfmgr_health_scope_holds" ] || observed_hold=1
[ "$observed_hold:$cfmgr_health_provider_stop" = "$8:$9" ] || exit 18
case $test_case in
auth-large) case "$cfmgr_health_result:$cfmgr_health_scope_holds" in auth-rejected-read:*ddns.zone*) ;; *) exit 11 ;; esac ;;
throttle-large) [ "$cfmgr_health_result:$cfmgr_health_provider_stop" = provider-throttle:1 ] || exit 12 ;;
success) [ "$cfmgr_health_result" = observed-read ] || exit 13 ;;
malformed-count) [ "$cfmgr_health_size_valid:$cfmgr_health_result" = 0:transport-unverified ] || exit 14 ;;
malformed-status) [ "$cfmgr_health_result" = transport-unverified ] || exit 17 ;;
esac
case $test_case in auth-large | throttle-large)
    case $modes in *health-get*health-count-get*) ;; *) exit 15 ;; esac
    case $modes in *health-response*) exit 16 ;; esac
    ;;
esac
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "get-controller",
            str(ROOT),
            str(tmp_path),
            case,
            str(expected),
            tools["sh"],
            shutil.which("dd"),
            tools["wc"],
            str(held),
            str(stopped),
        ],
        capture_output=True,
        timeout=5,
        check=False,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize(
    "variant,size", [("busybox", 13), ("regular", 12), ("missing", 10)]
)
def test_health_native_metadata_worker_has_fixed_members(
    shell, tmp_path, variant, size
):
    tool = tmp_path / "ls"
    tool.write_text('#!/bin/sh\nexec /usr/bin/printf "%s\\n" "$@"\n')
    tool.chmod(0o700)
    result = subprocess.run(
        [
            *shell,
            str(ROOT / "modules/helpers/worker.sh"),
            "health-native-metadata",
            str(tool),
            str(tmp_path),
            variant,
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0 and result.stderr == b""
    operands = result.stdout.decode().splitlines()
    assert operands[0] == "-ildn" and len(operands[1:]) == size
    assert operands[1:11] == [
        "/",
        "/usr",
        "/usr/sbin",
        "/usr/sbin/curl",
        "/usr/sbin/openssl",
        "/rom",
        "/rom/etc",
        "/rom/etc/ssl",
        "/rom/etc/ssl/certs",
        "/rom/etc/ssl/certs/ca-certificates.crt",
    ]
    assert len(set(operands[1:])) == size


def test_health_entware_metadata_worker_and_parser_preserve_spaced_paths(
    commands, shell, tmp_path
):
    root = tmp_path / "volume with spaces"
    toolroot = root / "entware"
    bindir = toolroot / "bin"
    bindir.mkdir(parents=True)
    candidate = bindir / "jq"
    candidate.write_text("fixture\n")
    candidate.chmod(0o700)
    paths = (root, toolroot, bindir, candidate)
    result = subprocess.run(
        [
            *shell,
            str(ROOT / "modules/helpers/worker.sh"),
            "health-entware-metadata",
            shutil.which("ls"),
            str(tmp_path),
            *map(str, paths),
        ],
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0 and result.stderr == b""
    raw = tmp_path / "metadata"
    raw.write_bytes(result.stdout)
    spec = "\n".join(
        f"{member}\t{kind}\t{path}"
        for member, kind, path in [
            ("storage", "directory", root),
            ("storage", "directory", toolroot),
            ("jq", "directory", root),
            ("jq", "directory", toolroot),
            ("jq", "directory", bindir),
            ("jq", "file", candidate),
        ]
    )
    # Host UID forwarding only; production requires literal UID0. The real LS
    # byte format/path handling and complete membership validator stay intact.
    program = awk_program("health_metadata").replace(
        'f[4]!="0"', f'f[4]!="{os.getuid()}"'
    )
    validated = subprocess.run(
        [*commands[1], program, str(raw), "entware", spec],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert validated.returncode == 0 and validated.stderr == b""
    assert b"member storage 1\nmember jq 1\n" in validated.stdout


def test_status_snapshot_uses_four_stages_and_rechecks_inode_size(shell, tmp_path):
    source = tmp_path / "private config"
    source.write_bytes(b"abc")
    snapshot = tmp_path / "snapshot"
    snapshot.write_bytes(b"abc")
    (tmp_path / "count").write_text("3\n")
    for name, inode in [("before", 12), ("changed", 13)]:
        (tmp_path / name).write_text(
            f"{inode} -rw------- 1 0 0 3 Oct 21 12:00 {source}\n"
        )
    script = r"""
. "$1/modules/status.sh"
source_path=$2 stage_dir=$3 calls=0 changed=0
cfmgr_status_run() {
    calls=$((calls+1))
    case $1 in
    status-metadata) cfmgr_probe_stdout=$stage_dir/before; if [ "$calls:$changed" = 4:1 ]; then cfmgr_probe_stdout=$stage_dir/changed; fi ;;
    status-snapshot) cfmgr_probe_stdout=$stage_dir/snapshot ;;
    status-count) cfmgr_probe_stdout=$stage_dir/count ;;
    *) exit 20 ;;
    esac
}
cfmgr_status_snapshot "$source_path" || exit 10
[ "$calls:$cfmgr_status_snapshot_inode:$cfmgr_status_snapshot_bytes" = 4:12:3 ] || exit 11
calls=0 changed=1
if cfmgr_status_snapshot "$source_path"; then exit 12; fi
[ "$calls" = 4 ] || exit 13
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "snapshot-stages",
            str(ROOT),
            str(source),
            str(tmp_path),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize(
    "case",
    [
        "extra-line",
        "missing-lf",
        "wrong-path",
        "symlink",
        "wrong-owner",
        "size-overflow",
    ],
)
def test_status_snapshot_metadata_rejects_ambiguous_native_receipt(
    shell, tmp_path, case
):
    path = "/private/source with spaces/config"
    line = f"12 -rw------- 1 0 0 65536 Oct 21 12:00 {path}\n"
    if case == "extra-line":
        line += "extra\n"
    if case == "missing-lf":
        line = line.rstrip("\n")
    if case == "wrong-path":
        line = line.replace("/config\n", "/config-extra\n")
    if case == "symlink":
        line = line.replace("-rw-------", "lrw-------")
    if case == "wrong-owner":
        line = line.replace(" 1 0 0 ", " 1 7 0 ")
    if case == "size-overflow":
        line = line.replace("65536", "65537")
    receipt = tmp_path / "metadata"
    receipt.write_text(line)
    script = '. "$1/modules/status.sh"; cfmgr_probe_stdout=$2; if cfmgr_status_snapshot_metadata "$3"; then exit 9; fi'
    result = subprocess.run(
        [*shell, "-c", script, "snapshot-metadata", str(ROOT), str(receipt), path],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="actual tiny quota and owned supervisor exit proof requires Linux proc/FD semantics",
)
@pytest.mark.parametrize(
    "overflow", [False, True], ids=["expected-rejection", "sigxfsz-prefix"]
)
def test_health_tiny_quota_rejects_signaled_jq_error_prefix(
    shell, tools, tmp_path, overflow
):
    context = tmp_path / "private-context"
    context.mkdir(mode=0o700)
    tool = tmp_path / "jq-fixture"
    program = (
        'BEGIN { print "parse error: fixed fixture" > "/dev/stderr"; '
        + ('for(i=0;i<4096;i++) printf "x" > "/dev/stderr"; ' if overflow else "")
        + "exit 4 }"
    )
    tool.write_text(
        "#!/bin/sh\nexec "
        + shlex.quote(tools["awk"])
        + " "
        + shlex.quote(program)
        + "\n"
    )
    tool.chmod(0o700)
    script = (
        r"""
root=$1 cfmgr_status_context=$2 selected_tool=$3 selected_sh=$4 selected_env=$5 selected_awk=$6 selected_sleep=$7 selected_wc=$8 overflow=$9
. "$root/modules/status.sh"
. "$root/modules/lib/execution.sh"
exec 9<"$cfmgr_status_context"
cfmgr_status_interrupted=0 cfmgr_probe_serial=0 cfmgr_probe_pid=''
cfmgr_health_active=1 cfmgr_health_operations=0 cfmgr_health_requests=0 cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_health_owned=''
cfmgr_prerequisites_now || exit 10
cfmgr_health_collect_deadline=$((cfmgr_probe_now+10))
cfmgr_health_stage_reserve json.bad 8192 || exit 11
/usr/bin/printf '{broken\n' >"$cfmgr_status_context/json.bad"
"""
        + pause_definition(shell)
        + r"""
if cfmgr_prerequisites_run health-jq-bad "$cfmgr_status_context" "$selected_sh" "$root/modules/helpers/worker.sh" "$selected_env" "$selected_awk" "$selected_sleep" "$selected_wc" "$selected_tool"; then code=0; else code=$?; fi
[ "$cfmgr_probe_status" = reaped ] || exit 12
if [ "$overflow" = 1 ]; then
    [ "$code" = 1 ] && [ "$cfmgr_probe_reason" = child-signal ] && [ "$cfmgr_probe_exit" -ge 128 ] || exit 13
else
    [ "$code:$cfmgr_probe_exit" = 0:4 ] || exit 14
fi
IFS= read -r prefix <"$cfmgr_probe_stderr" || exit 15
[ "$prefix" = 'parse error: fixed fixture' ] || exit 16
cfmgr_health_cleanup || exit 17
"""
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "tiny-supervisor",
            str(ROOT),
            str(context),
            str(tool),
            *(tools[key] for key in ("sh", "env", "awk", "sleep", "wc")),
            "1" if overflow else "0",
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == b"" and not context.exists()


def test_health_metadata_capacity_is_explicit_report_incompleteness(shell):
    script = r"""
. "$1/modules/status.sh"
cfmgr_health_opt_mount=/owned cfmgr_health_metadata_spec='' cfmgr_health_metadata_paths='' cfmgr_health_metadata_members=0 cfmgr_health_incomplete=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do cfmgr_health_metadata_walk jq "/owned/file$i" file || exit 10; done
if cfmgr_health_metadata_walk jq /owned/overflow file; then exit 11; fi
[ "$cfmgr_health_incomplete:$cfmgr_health_reason" = 1:budget ] || exit 12
"""
    result = subprocess.run(
        [*shell, "-c", script, "metadata-capacity", str(ROOT)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_health_realpath_dispatch_reaches_worker_for_fixed_controller_candidates(
    shell, tools, tmp_path
):
    target = tmp_path / "owned executable with spaces"
    target.write_text("fixture\n")
    target.chmod(0o700)
    link = tmp_path / "logical-link"
    link.symlink_to(target)
    script = r"""
. "$1/modules/status.sh"
root=$1 base=$2 selected_sh=$3 selected_readlink=$4
cfmgr_status_context=$base
cfmgr_health_run() {
    [ "$1:$2" = health-realpath:/usr/bin/readlink ] || exit 20
    /usr/bin/printf '%s\n' "$3" >>"$base/candidates"
    case $3 in /usr/sbin/curl | /usr/sbin/openssl | /rom/etc/ssl/certs/ca-certificates.crt | /usr/bin/flock | /opt/bin/jq) ;;
    *) exit 21 ;;
    esac
    cfmgr_probe_stdout=$base/path cfmgr_probe_stderr=$base/error
    if "$selected_sh" "$root/modules/helpers/worker.sh" health-realpath "$selected_readlink" "$base" "$base/logical-link" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi
    return 0
}
for candidate in /usr/sbin/curl /usr/sbin/openssl /rom/etc/ssl/certs/ca-certificates.crt /usr/bin/flock /opt/bin/jq; do
    cfmgr_health_canonical "$candidate" || exit 10
    [ "$cfmgr_health_resolved" = "$base/owned executable with spaces" ] || exit 11
done
# The path adapter exercises actual dispatch, not firmware trust: the native
# identity gate must reject this owned path for the fixed production candidate.
if cfmgr_health_admit_native /usr/sbin/curl executable; then exit 12; fi
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "health-realpath",
            str(ROOT),
            str(tmp_path),
            tools["sh"],
            tools["readlink"],
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert (tmp_path / "candidates").read_text().splitlines() == [
        "/usr/sbin/curl",
        "/usr/sbin/openssl",
        "/rom/etc/ssl/certs/ca-certificates.crt",
        "/usr/bin/flock",
        "/opt/bin/jq",
        "/usr/sbin/curl",
    ]
    basic = subprocess.run(
        [
            *shell,
            str(ROOT / "modules/helpers/worker.sh"),
            "status-realpath",
            tools["readlink"],
            str(tmp_path),
            str(link),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert basic.returncode == 2 and basic.stdout == basic.stderr == b""


def cloud_projection(commands, data, mode):
    return subprocess.run(
        [
            *commands[1],
            "-v",
            f"cfmgr_json_size={len(data)}",
            "-v",
            "cfmgr_json_mode=tree",
            "-v",
            "cfmgr_config_mode=archive-data",
            awk_program("json", "config_schema", "config_observation", "health_cloud"),
        ],
        input=data,
        env={**os.environ, "LC_ALL": "C", "CFMGR_HEALTH_CLOUD": mode},
        capture_output=True,
        check=False,
        timeout=3,
    )


def test_health_cloud_projections_keep_authority_out_of_path_policy_plan(
    commands, schema2_config
):
    from test_archive_payload import ACCOUNT, SECRET, TUNNEL, advanced_config, serialize

    value = advanced_config(schema2_config)
    data = serialize(value)
    plan = cloud_projection(commands, data, "plan")
    assert (plan.returncode, plan.stderr) == (0, b"")
    assert plan.stdout.startswith(b"CFMGR-CLOUD-PLAN\t1\nSTATE\t1\t0\t1\t1\tadvanced\n")
    assert all(
        secret.encode() not in plan.stdout
        for secret in (ACCOUNT, SECRET, TUNNEL, "advanced" + "-ref")
    )
    assert (
        b"FILE\tyaml\tsupported\t/opt/etc/cloudflared/config.yml\tmatched\t1\t-\n"
        in plan.stdout
    )
    assert plan.stdout.endswith(f"END\t{len(plan.stdout.splitlines()) - 1}\n".encode())
    authority = cloud_projection(commands, data, "runtime-authority")
    assert (authority.returncode, authority.stderr) == (0, b"")
    assert (
        authority.stdout
        == f"CFMGR-AUTH 1 {b'advanced'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()} END\n".encode()
    )
    account = cloud_projection(commands, data, "certificate-account")
    assert (
        account.stdout
        == f"CFMGR-CERT-ACCOUNT 1 {ACCOUNT.encode().hex()} END\n".encode()
    )
    value["cloudflared"]["method"] = "token"
    value["credentials"]["runtime-token"] = {
        "schema": 1,
        "kind": "cloudflared_token",
        "value": SECRET,
    }
    value["cloudflared"]["credential_refs"]["runtime"] = "runtime-token"
    token = serialize(value)
    assert cloud_projection(commands, token, "runtime-authority").returncode == 1
    assert (
        cloud_projection(commands, token, "certificate-account").stdout
        == account.stdout
    )
    value["cloudflared"]["paths"]["yaml"] = "/opt/" + "x" * 1500
    unsupported = cloud_projection(commands, serialize(value), "plan")
    assert unsupported.returncode == 0
    assert b"FILE\tyaml\tunsupported\t-\tconflict\t" in unsupported.stdout
    value["history"]["cloudflared"] = {"extension": True}
    assert cloud_projection(commands, serialize(value), "plan").returncode == 0
    value["history"]["cloudflared"] = {"status": {"schema": 2}}
    invalid = cloud_projection(commands, serialize(value), "plan")
    assert (invalid.returncode, invalid.stdout, invalid.stderr) == (1, b"", b"")


@pytest.mark.parametrize(
    "mutation",
    ["none", "duplicate", "symlink", "private-mode", "missing", "writable-ancestor"],
)
def test_health_selected_metadata_requires_every_exact_ancestor(
    commands, tmp_path, mutation
):
    target = "/protected volume/selected credential.json"
    paths = [target, "/protected volume", "/"]
    lines = [
        f"12 -rw------- 1 0 0 32 Jan 1 00:00 {target}",
        "11 drwxr-xr-x 2 0 0 64 Jan 1 00:00 /protected volume",
        "2 drwxr-xr-x 2 0 0 64 Jan 1 00:00 /",
    ]
    if mutation == "duplicate":
        lines[1] = lines[0]
    elif mutation == "symlink":
        lines[0] = lines[0].replace("-rw-------", "lrwxrwxrwx") + " -> /other"
    elif mutation == "private-mode":
        lines[0] = lines[0].replace("-rw-------", "-rw-r--r--")
    elif mutation == "missing":
        lines.pop()
    elif mutation == "writable-ancestor":
        lines[1] = lines[1].replace("drwxr-xr-x", "drwxrwxr-x")
    receipt = tmp_path / "ls receipt"
    receipt.write_text("\n".join(reversed(lines)) + "\n")
    result = subprocess.run(
        [
            *commands[1],
            awk_program("health_selected"),
            "metadata",
            str(receipt),
            "private",
            "\n".join(paths),
        ],
        env={**os.environ, "LC_ALL": "C", "CFMGR_HEALTH_SELECTED_PATH": target},
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.stderr == b""
    assert (result.returncode, result.stdout) == (
        (0, b"CFMGR-SELECTED 1 12 32 END\n") if mutation == "none" else (1, b"")
    )


@pytest.mark.parametrize("conflict", [False, True])
def test_health_cloud_private_yaml_join_keeps_identity_private(
    commands, tmp_path, conflict
):
    from test_archive_payload import ACCOUNT, SECRET, TUNNEL, yaml_receipt

    authority = tmp_path / "private auth"
    authority.write_text(
        f"CFMGR-AUTH 1 {b'runtime'.hex()} {ACCOUNT.encode().hex()} {TUNNEL} {SECRET.encode().hex()} END\n"
    )
    selected = "/opt/etc/cloudflared/selected.json"
    receipt = tmp_path / "yaml receipt"
    receipt.write_bytes(
        yaml_receipt(
            selected,
            TUNNEL if not conflict else "different",
            inputs=["/opt/etc/cloudflared/cert.pem"],
            controls=[("logfile", "/opt/var/log/cloud.log")],
        )
    )
    result = subprocess.run(
        [
            *commands[1],
            awk_program("health_selected"),
            "yaml-join",
            str(receipt),
            str(authority),
            selected,
            "-",
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.stderr == b""
    if conflict:
        assert (result.returncode, result.stdout) == (
            0,
            b"CFMGR-CLOUD-YAML-MISMATCH 1 END\n",
        )
    else:
        assert (result.returncode, result.stdout) == (
            0,
            b"CFMGR-CLOUD-YAML\t1\t1\t1\nINPUT\t1\torigincert\t/opt/etc/cloudflared/cert.pem\texternal\t-\t-\nEND\t1\n",
        )
    assert all(
        value.encode() not in result.stdout for value in (ACCOUNT, SECRET, TUNNEL)
    )


def test_health_selected_worker_pins_hash_and_never_executes_binary(
    shell, tools, tmp_path
):
    import hashlib

    candidate = tmp_path / "binary with spaces"
    candidate.write_bytes(b"#!/bin/sh\necho MUST_NOT_EXECUTE\n")
    candidate.chmod(0o700)
    original = (ROOT / "modules/helpers/worker.sh").read_text()
    adapted = original
    if sys.platform == "darwin":
        adapted = adapted.replace("/proc/self/fd/8", "/dev/fd/8").replace(
            '"$1" -ef /dev/fd/8', "-f /dev/fd/8"
        )
    worker = tmp_path / "worker"
    worker.write_text(adapted)
    result = subprocess.run(
        [
            *shell,
            str(worker),
            "health-selected-hash",
            shutil.which("openssl"),
            str(tmp_path),
            str(candidate),
            str(candidate.stat().st_size),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0 and result.stderr == b""
    assert (
        result.stdout.split()[0]
        == hashlib.sha256(candidate.read_bytes()).hexdigest().encode()
    )
    assert b"MUST_NOT_EXECUTE" not in result.stdout
    linked = tmp_path / "link"
    linked.symlink_to(candidate)
    refused = subprocess.run(
        [
            *shell,
            str(worker),
            "health-selected-hash",
            shutil.which("openssl"),
            str(tmp_path),
            str(linked),
            "32",
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (refused.returncode, refused.stdout, refused.stderr) == (2, b"", b"")
    copied = subprocess.run(
        [
            *shell,
            str(worker),
            "health-selected-copy",
            shutil.which("dd"),
            str(tmp_path),
            str(candidate),
            str(candidate.stat().st_size),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (copied.returncode, copied.stdout, copied.stderr) == (
        0,
        candidate.read_bytes(),
        b"",
    )


def test_health_cloud_collector_uses_real_private_parsers_and_owned_input_digest(
    shell, tools, schema2_config, tmp_path
):
    """Real fixed workers; host ownership/metadata and supervision are adapters."""
    import base64
    import hashlib

    from test_archive_payload import ACCOUNT, SECRET, TUNNEL, advanced_config, serialize

    source = tmp_path / "source"
    (source / "modules/lib").mkdir(parents=True)
    (source / "modules/helpers").mkdir()
    context = tmp_path / "private context"
    context.mkdir(mode=0o700)
    selected = tmp_path / "selected files"
    selected.mkdir(mode=0o700)
    binary = selected / "cloudflared"
    binary.write_bytes(b"#!/bin/sh\necho MUST_NOT_EXECUTE\n")
    binary.chmod(0o700)
    credential = selected / "credentials.json"
    credential.write_bytes(
        serialize({"AccountTag": ACCOUNT, "TunnelID": TUNNEL, "TunnelSecret": SECRET})
    )
    certificate_json = serialize(
        {
            "zoneID": "fixture-zone",
            "accountID": ACCOUNT,
            "apiToken": "certificate-CANARY",
        }
    )
    body = base64.b64encode(certificate_json)
    pem = (
        b"-----BEGIN ARGO TUNNEL TOKEN-----\n"
        + b"\n".join(body[i : i + 64] for i in range(0, len(body), 64))
        + b"\n-----END ARGO TUNNEL TOKEN-----\n"
    )
    certificate = selected / "cert.pem"
    recovery = selected / "recovery.pem"
    certificate.write_bytes(pem)
    recovery.write_bytes(pem)
    dependency = selected / "ca.pem"
    dependency.write_bytes(b"fixture protected dependency\n")
    yaml = selected / "config.yml"
    yaml.write_text(
        f"tunnel: {TUNNEL}\ncredentials-file: '{credential}'\ncacert: '{dependency}'\n"
    )
    files = {
        "yaml": yaml,
        "json": credential,
        "certificate": certificate,
        "certificate-recovery": recovery,
        "binary": binary,
        "input.ca_bundle": dependency,
    }
    for role, path in files.items():
        if role != "binary":
            path.chmod(0o600)
    value = advanced_config(schema2_config)
    value["cloudflared"]["paths"] = {
        "yaml": str(yaml),
        "json": str(credential),
        "certificate": str(certificate),
    }
    value["credentials"]["cert"].update(
        path=str(certificate),
        recovery_path=str(recovery),
        sha256=hashlib.sha256(pem).hexdigest(),
    )
    value["ownership"]["components"] = [
        {
            "schema": 1,
            "component": "cloudflared"
            if role == "binary"
            else f"data.cloudflared.{role}",
            "path": str(path),
            "generation": 1,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        for role, path in files.items()
    ]
    config_file = source / "retained config"
    config_file.write_bytes(serialize(value))
    config_file.chmod(0o600)
    for relative in (
        "modules/status.sh",
        "modules/backup.sh",
        "modules/lib/config.sh",
        "modules/helpers/worker.sh",
    ):
        text = (ROOT / relative).read_text()
        if relative == "modules/status.sh":
            assert text.count('hc_file("binary","/opt/bin/cloudflared"') == 1
            text = text.replace(
                'hc_file("binary","/opt/bin/cloudflared"',
                f'hc_file("binary","{binary}"',
            )
        if relative == "modules/helpers/worker.sh" and sys.platform == "darwin":
            text = (
                text.replace("/proc/self/fd/8", "/dev/fd/8")
                .replace('"$1" -ef /dev/fd/8', "-f /dev/fd/8")
                .replace('"$3" -ef /dev/fd/8', "-f /dev/fd/8")
            )
        (source / relative).write_text(text)
    ls = tmp_path / "owned-ls-adapter"
    ls.write_text(
        f"#!{Path(sys.executable).resolve()}\nimport os,stat,sys\nfor path in sys.argv[2:]:\n s=os.lstat(path); mode=stat.filemode(s.st_mode)\n if stat.S_ISDIR(s.st_mode): mode='drwxr-xr-x'\n print(f'{{s.st_ino}} {{mode}} {{s.st_nlink}} 0 0 {{s.st_size}} Jan 1 00:00 {{path}}')\n"
    )
    ls.chmod(0o700)
    openssl = tmp_path / "owned-openssl-adapter"
    openssl.write_text(
        f'#!{tools["sh"]}\n{shlex.quote(tools["env"])} >{shlex.quote(str(tmp_path / "child environment"))}\nexec {shlex.quote(shutil.which("openssl"))} "$@"\n'
    )
    openssl.chmod(0o700)
    script = r"""
source=$1 base=$2 selected_sh=$3 selected_awk=$4 selected_dd=$5 selected_hex=$6 selected_wc=$7 selected_readlink=$8 selected_env=${10}
LC_ALL=C; export LC_ALL
. "$source/modules/status.sh"
cfmgr_status_context="$base/private context" cfmgr_source=$source
cfmgr_health_active=1 cfmgr_health_operations=0 cfmgr_health_requests=0 cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_health_owned='' cfmgr_probe_serial=0
cfmgr_health_collect_deadline=40 cfmgr_health_final_deadline='' cfmgr_health_incomplete=0
cfmgr_health_config="$source/retained config" cfmgr_health_config_bytes=$9 cfmgr_health_inventory=validated
cfmgr_health_backup=verified cfmgr_health_native_openssl_ok=1 cfmgr_health_openssl="$base/owned-openssl-adapter"
cfmgr_status_attachment_ok() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=0; }
cfmgr_health_row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
cfmgr_health_run() {
    cfmgr_health_reserve "$1" || return $?
    mode=$1 tool=$2; shift 2
    printf '%s\n' "$mode" >>"$base/routes"
    printf '%s\n' "$tool" "$@" >>"$base/launch arguments"
    case $tool in /usr/bin/awk) tool=$selected_awk ;; /bin/ls) tool="$base/owned-ls-adapter" ;; /bin/dd) tool=$selected_dd ;; /usr/bin/hexdump) tool=$selected_hex ;; /usr/bin/wc) tool=$selected_wc ;; /usr/bin/readlink) tool=$selected_readlink ;; esac
    cfmgr_probe_serial=$((cfmgr_probe_serial + 1))
    cfmgr_probe_stdout="$cfmgr_status_context/$cfmgr_health_label.out" cfmgr_probe_stderr="$cfmgr_status_context/$cfmgr_health_label.err"
    if (ulimit -f "$cfmgr_health_mode_limit" && exec "$selected_env" -i LC_ALL=C "$selected_sh" "$source/modules/helpers/worker.sh" "$mode" "$tool" "$cfmgr_status_context" "$@") >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi
    return 0
}
cfmgr_health_cloud_collect || exit $?
printf 'LEDGER %s %s %s\n' "$cfmgr_health_operations" "$cfmgr_health_files" "$cfmgr_health_bytes"
"""
    args = [
        *shell,
        "-c",
        script,
        "health-cloud",
        str(source),
        str(tmp_path),
        tools["sh"],
        tools["awk"],
        shutil.which("dd"),
        shutil.which("hexdump"),
        tools["wc"],
        tools["readlink"],
        str(config_file.stat().st_size),
        tools["env"],
    ]
    normal = subprocess.run(args, capture_output=True, check=False, timeout=12)
    assert (normal.returncode, normal.stderr) == (0, b""), normal.stdout
    for row in (
        "yaml.identity",
        "runtime.local",
        "certificate.live",
        "certificate-recovery",
        "binary",
        "yaml.input.1",
    ):
        assert f"cloudflared.{row}\tPASS\t".encode() in normal.stdout, normal.stdout
    assert b"MUST_NOT_EXECUTE" not in normal.stdout
    modes = (tmp_path / "routes").read_text().splitlines()
    assert modes.count("health-cloud-pem") == modes.count("health-cloud-decode") == 1
    assert modes.count("health-cloud-plan") == 1
    assert all(
        secret.encode() not in normal.stdout
        for secret in (ACCOUNT, SECRET, TUNNEL, "certificate-CANARY", str(selected))
    )
    assert all(
        secret
        not in (tmp_path / "launch arguments").read_text()
        + (tmp_path / "child environment").read_text()
        for secret in (ACCOUNT, SECRET, TUNNEL, "certificate-CANARY")
    )
    # A matching owned input is hashed, rather than silently becoming an
    # external availability-only pass after its bytes change.
    dependency.write_bytes(b"changed protected dependency\n")
    changed = subprocess.run(args, capture_output=True, check=False, timeout=12)
    assert changed.returncode == 0 and changed.stderr == b""
    assert b"cloudflared.yaml.input.1\tFAIL\t" in changed.stdout

    value["cloudflared"]["method"] = "token"
    value["credentials"]["runtime-token"] = {
        "schema": 1,
        "kind": "cloudflared_token",
        "value": SECRET,
    }
    value["cloudflared"]["credential_refs"].update(
        runtime="runtime-token", certificate=None
    )
    value["cloudflared"]["paths"]["certificate"] = None
    value["ownership"]["components"] = [
        item
        for item in value["ownership"]["components"]
        if ".certificate" not in item["component"]
    ]
    config_file.write_bytes(serialize(value))
    token_args = args.copy()
    token_args[-2] = str(config_file.stat().st_size)
    token = subprocess.run(token_args, capture_output=True, check=False, timeout=8)
    assert token.returncode == 0 and token.stderr == b""
    assert b"cloudflared.certificate.live\tSKIP\t" in token.stdout
    assert b"cloudflared.certificate-recovery\tSKIP\t" in token.stdout


def test_health_cloud_rejects_partial_plan_before_any_file_open_and_keeps_budget_unknown(
    shell, tools, tmp_path
):
    partial = tmp_path / "partial plan"
    partial.write_text("CFMGR-CLOUD-PLAN\t1\nSTATE\t1\t0\t1\t1\tadvanced\n")
    empty = tmp_path / "empty"
    empty.write_text("")
    yaml = tmp_path / "yaml receipt"
    yaml.write_text("CFMGR-YAML 1\nIDENTITY ignored ignored\nEND 0 0\n")
    script = r"""
. "$1/modules/status.sh"
root=$1 base=$2 awk=$3
cfmgr_source=$root cfmgr_health_inventory=validated cfmgr_health_config=unused cfmgr_health_config_bytes=1
cfmgr_health_row() { printf '%s %s\n' "$1" "$2"; }
cfmgr_health_run() {
    printf '%s\n' "$1" >>"$base/routes"
    cfmgr_probe_exit=0 cfmgr_probe_stderr="$base/empty" cfmgr_probe_stdout="$base/partial plan"
    case $1 in
    health-cloud-plan) ;;
    health-count) "$4" >/dev/null 2>&1; return 2 ;;
    health-cloud-frame)
        cfmgr_probe_stdout="$base/frame"
        if "$awk" "$program" frame-plan "$base/partial plan" - - - >"$cfmgr_probe_stdout"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi ;;
    *) exit 20 ;;
    esac
}
cfmgr_health_count() { cfmgr_health_size=51; }
program=$4
cfmgr_health_cloud_collect || exit 10
cfmgr_health_cloud_role=json cfmgr_health_cloud_authority=private cfmgr_health_cloud_snapshot=private cfmgr_health_cloud_extent=1 cfmgr_health_backup=verified cfmgr_health_cloud_owner=matched cfmgr_health_cloud_state=UNKNOWN
cfmgr_health_run() { cfmgr_health_incomplete=1; return 1; }
cfmgr_health_cloud_semantics || exit 11
[ "$cfmgr_health_cloud_state" = UNKNOWN ] || exit 12
cfmgr_health_cloud_role=yaml cfmgr_health_cloud_json_support=supported cfmgr_health_cloud_state=UNKNOWN
cfmgr_health_cloud_hex() { cfmgr_health_cloud_hex_file=private; }
cfmgr_health_run() {
    case $1 in health-cloud-yaml) cfmgr_probe_exit=0 cfmgr_probe_stderr="$base/empty" cfmgr_probe_stdout="$base/yaml receipt" ;; health-cloud-join) cfmgr_health_incomplete=1; return 1 ;; *) exit 21 ;; esac
}
if cfmgr_health_cloud_semantics; then :; else [ "$?" = 1 ] || exit 13; fi
[ "$cfmgr_health_cloud_state" = UNKNOWN ] || exit 14
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "health-incomplete",
            str(ROOT),
            str(tmp_path),
            tools["awk"],
            awk_program("health_selected"),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"cloudflared.local UNKNOWN\n",
        b"",
    )
    assert (tmp_path / "routes").read_text().splitlines() == [
        "health-cloud-plan",
        "health-cloud-frame",
    ]


def logging_parser(commands, mode, input_path, spec, argument="normal"):
    return subprocess.run(
        [
            *commands[1],
            awk_program("health_logging"),
            mode,
            str(input_path),
            str(spec),
            argument,
        ],
        capture_output=True,
        check=False,
        env={**os.environ, "LC_ALL": "C"},
        timeout=3,
    )


def test_health_logging_authority_separates_requested_from_enabled(
    commands, schema2_config
):
    # The saved policy getter is shared by both consumers; no secret is emitted.
    value = json.loads(schema2_config)
    value["credentials"]["canary"] = {
        "schema": 1,
        "kind": "cloudflare_api_token",
        "value": HEALTH_SECRET,
    }
    value["logging"]["cloudflared"].update(
        configured=True,
        enabled=False,
        policy={
            "schema": 1,
            "mode": "weekly",
            "size": {"value": 7, "unit": "MiB"},
            "total_files": 3,
            "max_age_days": None,
        },
    )
    data = json.dumps(value, separators=(",", ":")).encode()
    result = subprocess.run(
        [
            *commands[1],
            "-v",
            "cfmgr_json_mode=tree",
            "-v",
            f"cfmgr_json_size={len(data)}",
            "-v",
            "cfmgr_config_mode=archive-data",
            awk_program(
                "json",
                "config_schema",
                "config_observation",
                "backup_history_policy",
                "health_logging_authority",
            ),
        ],
        input=data,
        capture_output=True,
        check=False,
        env={**os.environ, "LC_ALL": "C"},
        timeout=3,
    )
    assert (result.returncode, result.stderr) == (0, b""), result.stdout
    assert b"FEATURE cloudflared 0 0 1 0 0 0 0 - - - - END\n" in result.stdout
    assert b"SAVED cloudflared POLICY weekly 7340032 2 0 END\n" in result.stdout
    assert HEALTH_SECRET.encode() not in result.stdout
    value["logging"]["cloudflared"]["policy"]["mode"] = "invalid"
    data = json.dumps(value, separators=(",", ":")).encode()
    invalid = subprocess.run(
        [
            *commands[1],
            "-v",
            "cfmgr_json_mode=tree",
            "-v",
            f"cfmgr_json_size={len(data)}",
            "-v",
            "cfmgr_config_mode=archive-data",
            awk_program(
                "json",
                "config_schema",
                "config_observation",
                "backup_history_policy",
                "health_logging_authority",
            ),
        ],
        input=data,
        capture_output=True,
        check=False,
        env={**os.environ, "LC_ALL": "C"},
        timeout=3,
    )
    assert invalid.returncode != 0 and invalid.stdout == b""


def test_health_logging_metadata_missing_member_and_count_hash_frames(
    commands, tmp_path
):
    spec = tmp_path / "spec"
    spec.write_text(
        "good\t/opt/etc/good\tpublic\twhole\nmissing\t/opt/etc/missing\tpublic\twhole\n"
    )
    raw = tmp_path / "raw"
    raw.write_text(
        "1 drwxr-xr-x 1 0 0 0 Jan 1 00:00 /\n2 drwxr-xr-x 1 0 0 0 Jan 1 00:00 /opt\n3 drwxr-xr-x 1 0 0 0 Jan 1 00:00 /opt/etc\n4 -rw-r--r-- 1 0 0 12 Jan 1 00:00 /opt/etc/good\n"
    )
    result = logging_parser(commands, "metadata", raw, spec)
    assert (result.returncode, result.stderr) == (0, b"")
    assert b"MEMBER\tgood\t1\t4\t12\t-rw-r--r--\t" in result.stdout
    assert b"MEMBER\tmissing\t0\t-\t-\t-\t" in result.stdout
    raw.write_text(raw.read_text() + "5 -rw-r--r-- 1 0 0 1 Jan 1 00:00 /extra\n")
    assert logging_parser(commands, "metadata", raw, spec).returncode != 0
    spec.write_text("one\t/private/one\ntwo\t/private/two\n")
    raw.write_text("1 3 /private/one\n2 5 /private/two\n3 8 total\n")
    assert (
        logging_parser(commands, "counts", raw, spec).stdout
        == b"COUNT\tone\t3\t1\nCOUNT\ttwo\t5\t2\n"
    )
    for damage in (
        "1 3 /private/one\n2 5 /private/two\n4 8 total\n",
        "1 3 /private/one\n2 5 /private/two\n3 8 total",
        "1 3 /private/one\n2 5 /private/one\n3 8 total\n",
    ):
        raw.write_text(damage)
        assert logging_parser(commands, "counts", raw, spec).returncode != 0
    raw.write_text("a" * 64 + " */private/one\n" + "b" * 64 + " */private/two\n")
    assert (
        logging_parser(commands, "hashes", raw, spec).stdout
        == b"HASH\tone\t" + b"a" * 64 + b"\nHASH\ttwo\t" + b"b" * 64 + b"\n"
    )


@pytest.mark.parametrize("kind", ["syslog", "cron"])
def test_health_logging_native_argv_receipt_matches_process_contract(
    shell, tools, tmp_path, kind
):
    argv = (
        ["/opt/sbin/syslog-ng", "--foreground"]
        if kind == "syslog"
        else ["crond", "-c", "/var/spool/cron/crontabs"]
    )
    payload = b"\0".join(value.encode() for value in argv) + b"\0"
    raw = tmp_path / "argv.hex"
    raw.write_text("".join(f"{value:02x}\n" for value in payload))
    result = subprocess.run(
        [
            *shell,
            str(ROOT / "modules/helpers/worker.sh"),
            "health-log-argv",
            tools["awk"],
            str(tmp_path),
            str(raw),
            kind,
            "123",
            "4000",
        ],
        env={"LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=3,
    )
    expected = (
        "PROC 123 4000 "
        + argv[0].encode().hex()
        + " 2 "
        + " ".join(value.encode().hex() for value in argv)
        + " END\n"
        if kind == "syslog"
        else "CROND 123 4000 " + argv[2].encode().hex() + " END\n"
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        expected.encode(),
        b"",
    )


def test_health_logging_process_assembler_keeps_argv_in_private_files(
    commands, tmp_path
):
    receipt = tmp_path / "health-log-argv.1.out"
    canary = b"private-argv-CANARY"
    receipt.write_bytes(
        b"PROC 123 456 2f6f70742f7362696e2f7379736c6f672d6e67 2 "
        + b"/opt/sbin/syslog-ng".hex().encode()
        + b" "
        + canary.hex().encode()
        + b" END\n"
    )
    index = tmp_path / "index"
    index.write_text(
        "CANDIDATE\tsyslog\t123\t456\thealth-log-argv.1.out\t/mounted/opt/sbin/syslog-ng\t99\n"
    )
    result = logging_parser(commands, "process", index, tmp_path)
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        receipt.read_bytes(),
        b"",
    )
    assert canary not in result.stdout
    index.write_text(index.read_text().replace("123\t456", "123\t457"))
    assert logging_parser(commands, "process", index, tmp_path).returncode != 0


@pytest.mark.parametrize("damage", ["none", "same-size", "warning"])
def test_health_logging_actual_workers_share_nine_roles_and_three_policies(
    shell, tools, health_config, tmp_path, damage
):
    """Real collector/parser workers; host identity and supervision are adapters."""
    import hashlib

    from test_archive_history import DEBUG, GLOBAL, RULE

    health_config = json.loads(json.dumps(health_config))
    source = tmp_path / "source"
    context = tmp_path / "private"
    opt = tmp_path / "mounted" / "entware"
    jffs = tmp_path / "jffs"
    context.mkdir(mode=0o700)
    for directory in (
        source / "modules/helpers",
        source / "modules/lib",
        opt / "etc/logrotate.d",
        opt / "etc/syslog-ng.d",
        opt / "sbin",
        opt / "bin",
        jffs / "scripts",
        jffs / "addons/scribe.d",
    ):
        directory.mkdir(parents=True, exist_ok=True)
    for relative in (
        "modules/status.sh",
        "modules/backup.sh",
        "modules/helpers/worker.sh",
        "modules/lib/config.sh",
    ):
        text = (ROOT / relative).read_text()
        if relative == "modules/helpers/worker.sh" and sys.platform == "darwin":
            text = (
                text.replace("/proc/self/fd/8", "/dev/fd/8")
                .replace('"$1" -ef /dev/fd/8', "-f /dev/fd/8")
                .replace('"$4" -ef /dev/fd/8', "-f /dev/fd/8")
            )
        (source / relative).write_text(text)
    (jffs / "scripts/scribe").write_text(
        'readonly scribe_ver="v3.2.12"\nreadonly scriptVer_TAG="26041123"\n'
        + "#prefix-only padding\n" * 800
    )
    (jffs / "addons/scribe.d/config").write_text(
        "SYSLOG_LOC=/tmp/syslog.log\nLR_CRONJOB_HOUR=3\n"
    )
    (opt / "etc/syslog-ng.conf").write_text(
        '@version: 4.7\n@include "/opt/etc/syslog-ng.d/"\n'
    )
    (opt / "etc/logrotate.conf").write_text("include /opt/etc/logrotate.d\n")
    (opt / "bin/scribe").symlink_to("/jffs/scripts/scribe")
    advisory = "warning: logrotate in debug mode does nothing except printing debug messages!  Consider using verbose mode (-v) instead if this is not what you want.\n\n"
    debug = advisory + DEBUG.replace(
        "reading config file cfmgr-ddns\n",
        "reading config file cfmgr-ddns\nreading config file cfmgr-ip-sync\nreading config file cfmgr-cloudflared\n",
    )
    if damage == "warning":
        debug += "warning: real configuration warning\n"
    (opt / "etc/logrotate.d/A01global").write_text(GLOBAL)
    (opt / "etc/logrotate.d/messages").write_text(
        "/opt/var/log/messages {\n size 4M\n}\n"
    )
    for feature in ("ddns", "ip_sync", "cloudflared"):
        base = feature.replace("_", "-")
        rule = RULE.replace("ddns", base)
        (opt / f"etc/logrotate.d/cfmgr-{base}").write_text(rule)
        health_config["logging"][feature].update(
            configured=True,
            enabled=False,
            policy={"schema": 1, "version": 1}
            if feature != "cloudflared"
            else {
                "schema": 1,
                "mode": "size",
                "size": {"value": 7, "unit": "MiB"},
                "total_files": 3,
                "max_age_days": None,
            },
        )
        health_config["ownership"]["components"].extend(
            [
                {
                    "schema": 1,
                    "component": f"history.{feature}",
                    "path": f"/opt/var/log/{base}.log",
                    "generation": 1,
                    "sha256": None,
                },
                {
                    "schema": 1,
                    "component": f"history-rule.{feature}",
                    "path": f"/opt/etc/logrotate.d/cfmgr-{base}",
                    "generation": 1,
                    "sha256": hashlib.sha256(rule.encode()).hexdigest(),
                },
            ]
        )
    if damage == "same-size":
        (tmp_path / "changed-rule").write_text(RULE.replace("size 7M", "size 8M"))
    config_file = source / "retained"
    config_file.write_text(json.dumps(health_config, separators=(",", ":")))
    for name, version in (
        ("syslog-ng", "syslog-ng 4.7.1"),
        ("logrotate", "logrotate 3.22.0"),
    ):
        tool = opt / "sbin" / name
        tool.write_text(
            f"#!{tools['sh']}\ncase $1 in --version) printf '%s\\n' {shlex.quote(version)} ;; --syntax-only) [ \"$2:$3\" = '-f:/opt/etc/syslog-ng.conf' ] ;; -d) [ \"$2\" = /opt/etc/logrotate.conf ] || exit 9; printf '%s' {shlex.quote(debug)} >&2 ;; *) exit 9 ;; esac\n"
        )
        tool.chmod(0o700)
    ls = tmp_path / "ls-adapter"
    ls.write_text(
        f"#!{Path(sys.executable).resolve()}\nimport os,stat,sys\nfor path in sys.argv[2:]:\n try:s=os.lstat(path)\n except OSError:continue\n mode='drwxr-xr-x' if stat.S_ISDIR(s.st_mode) else stat.filemode(s.st_mode)\n print(f'{{s.st_ino}} {{mode}} {{s.st_nlink}} 0 0 {{s.st_size}} Jan 1 00:00 {{path}}')\n"
    )
    ls.chmod(0o700)
    cron = context / "health-log-cron.900.out"
    cron.write_text("5 */3 * * * /jffs/scripts/scribe LogRotate #scribeLogRotate#\n")
    proc = context / "health-log-process.901.out"
    proc.write_text(
        "PROC 123 4000 "
        + b"/opt/sbin/syslog-ng".hex()
        + " 1 "
        + b"/opt/sbin/syslog-ng".hex()
        + " END\nCROND 124 4001 "
        + b"/var/spool/cron/crontabs".hex()
        + " END\n"
    )
    script = r"""
source=$1 base=$2 selected_sh=$3 selected_awk=$4 selected_env=$5 selected_wc=$6 selected_dd=$7 selected_readlink=$8 selected_ssl=$9
LC_ALL=C; export LC_ALL
. "$source/modules/status.sh"
cfmgr_source=$source cfmgr_status_context=$base/private
cfmgr_health_active=1 cfmgr_health_operations=0 cfmgr_health_requests=0 cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_health_owned='' cfmgr_probe_serial=0
cfmgr_health_collect_deadline=40 cfmgr_health_final_deadline='' cfmgr_health_incomplete=0 cfmgr_health_protected_cache=''
cfmgr_health_config=$source/retained cfmgr_health_config_bytes=${10} cfmgr_health_inventory=validated
cfmgr_health_backup=verified cfmgr_health_native_openssl_ok=1 cfmgr_health_openssl=$selected_ssl cfmgr_health_entware_ready=1
cfmgr_health_opt=$base/mounted/entware cfmgr_health_opt_mount=$base/mounted
cfmgr_status_attachment_ok() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=0; }
cfmgr_health_entware_attachment() { return 0; }
cfmgr_health_selected_attached() { return 0; }
cfmgr_health_selected_resolve() {
    case $cfmgr_health_selected_logical in /opt/*) cfmgr_health_resolved=$cfmgr_health_opt/${cfmgr_health_selected_logical#/opt/} ;; /jffs/*) cfmgr_health_resolved=$base/jffs/${cfmgr_health_selected_logical#/jffs/} ;; *) cfmgr_health_resolved=$cfmgr_health_selected_logical ;; esac
    [ -f "$cfmgr_health_resolved" ] && [ ! -L "$cfmgr_health_resolved" ]
}
cfmgr_health_log_cron() { cfmgr_health_cron_ready=1 cfmgr_health_cron_file=$base/private/health-log-cron.900.out; cfmgr_health_cron_bytes=$("$selected_wc" -c <"$cfmgr_health_cron_file"); }
cfmgr_health_log_processes() { cfmgr_health_process_ready=1 cfmgr_health_process_file=$base/private/health-log-process.901.out; }
cfmgr_health_row() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
cfmgr_health_run() {
    cfmgr_health_reserve "$1" || return $?
    mode=$1 tool=$2; shift 2
    printf '%s\n' "$mode" "$tool" "$@" >>"$base/arguments"
    case $tool in /usr/bin/awk) tool=$selected_awk ;; /bin/ls) tool=$base/ls-adapter ;; /bin/dd) tool=$selected_dd ;; /usr/bin/wc) tool=$selected_wc ;; /usr/bin/readlink) tool=$selected_readlink ;; /opt/sbin/*) tool=$cfmgr_health_opt/sbin/${tool##*/} ;; esac
    if [ "$mode" = health-log-link ]; then set -- "$cfmgr_health_opt/bin/scribe"; fi
    cfmgr_probe_serial=$((cfmgr_probe_serial + 1))
    cfmgr_probe_stdout=$cfmgr_status_context/$cfmgr_health_label.out cfmgr_probe_stderr=$cfmgr_status_context/$cfmgr_health_label.err
    if (ulimit -f "$cfmgr_health_mode_limit"; exec "$selected_env" -i LC_ALL=C "$selected_sh" "$source/modules/helpers/worker.sh" "$mode" "$tool" "$cfmgr_status_context" "$@") >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi
    if [ "$mode" = health-selected-copy ] && [ -f "$base/changed-rule" ]; then
        case $1 in */cfmgr-ddns) "$selected_dd" if="$base/changed-rule" of="$1" bs=4096 count=1 conv=notrunc 2>/dev/null ;; esac
    fi
    printf '%s %s\n' "$mode" "$cfmgr_probe_exit" >>"$base/routes"
    return 0
}
cfmgr_health_logging_collect || exit $?
printf 'LEDGER %s %s %s\n' "$cfmgr_health_operations" "$cfmgr_health_files" "$cfmgr_health_bytes"
# Cross the 13-operand native batch boundary once. Nested spec creation must
# preserve the aggregate count receipt's reserved limit.
if [ ! -e "$base/changed-rule" ]; then
    count_spec='' count_index=1
    while [ "$count_index" -le 14 ]; do
        printf 'one\ntwo\n' >"$cfmgr_status_context/count.$count_index"
        count_spec="${count_spec}r$count_index	$cfmgr_status_context/count.$count_index
"
        count_index=$((count_index + 1))
    done
    cfmgr_health_log_spec_write "$count_spec" || exit 31
    cfmgr_health_log_group counts "$cfmgr_health_log_spec_file" || exit 32
    count_index=0
    while IFS='	' read -r tag role bytes lines; do
        [ "$tag:$bytes:$lines" = COUNT:8:2 ] || exit 33
        count_index=$((count_index + 1))
    done <"$cfmgr_health_log_group_file"
    [ "$count_index" = 14 ] && [ "$cfmgr_health_log_append_limit" = 1825 ] || exit 34
fi
"""
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "health-logging",
            str(source),
            str(tmp_path),
            tools["sh"],
            tools["awk"],
            tools["env"],
            tools["wc"],
            shutil.which("dd"),
            tools["readlink"],
            shutil.which("openssl"),
            str(config_file.stat().st_size),
        ],
        capture_output=True,
        check=False,
        timeout=20,
    )
    assert (result.returncode, result.stderr) == (0, b""), result.stdout
    if damage in ("same-size", "warning"):
        assert b"logging.base\tUNKNOWN\t" in result.stdout, result.stdout
        assert b".policy\tPASS\t" not in result.stdout
        return
    assert b"logging.base\tPASS\t" in result.stdout, (
        result.stdout,
        (tmp_path / "routes").read_text(),
    )
    for feature in ("ddns", "ip_sync", "cloudflared"):
        assert f"logging.{feature}.policy\tPASS\t".encode() in result.stdout, (
            result.stdout
        )
    assert (
        HEALTH_SECRET.encode()
        not in result.stdout + (tmp_path / "arguments").read_bytes()
    )
    assert b"weekly" not in (tmp_path / "arguments").read_bytes()
    print(result.stdout.decode())


def test_health_logging_cron_requires_three_boundaries_both_accounts_and_equal_content(
    shell, tmp_path
):
    script = r"""
. "$1/modules/status.sh"
base=$2 damage=$3
cfmgr_status_context=$base
cfmgr_health_native_openssl_ok=1
cfmgr_health_admit_native() { return 0; }
cfmgr_health_log_spec_write() { serial=$((${serial:-0}+1));cfmgr_health_log_spec_file=$base/spec.$serial;printf '%s' "$1" >"$cfmgr_health_log_spec_file"; }
cfmgr_health_log_cron_boundary() {
    boundaries=$((${boundaries:-0}+1));cfmgr_health_log_cron_identity=owned cfmgr_health_log_cron_bytes=3
    if [ "$damage:$boundaries" = identity:2 ]; then cfmgr_health_log_cron_identity=changed; fi
}
cfmgr_health_run() {
    mode=$1;shift 2
    serial=$((${serial:-0}+1));cfmgr_probe_stdout=$base/out.$serial;cfmgr_probe_stderr=$base/err.$serial;: >"$cfmgr_probe_stderr";cfmgr_probe_exit=0
    case $mode in
    health-log-account) accounts=$((${accounts:-0}+1));if [ "$damage:$accounts" = account:2 ];then printf 'changed\n';else printf 'root\n';fi >"$cfmgr_probe_stdout" ;;
    health-log-cron) printf 'ok\n' >"$cfmgr_probe_stdout" ;;
    *) return 9 ;;
    esac
}
cfmgr_health_log_group() {
    serial=$((${serial:-0}+1));cfmgr_health_log_group_file=$base/group.$serial
    case $1 in
    counts) printf 'COUNT\tfirst\t3\t1\nCOUNT\tsecond\t3\t1\n' >"$cfmgr_health_log_group_file" ;;
    hashes) if [ "$damage" = content ]; then second=changed;else second=same;fi;printf 'HASH\tfirst\tsame\nHASH\tsecond\t%s\n' "$second" >"$cfmgr_health_log_group_file" ;;
    esac
}
if cfmgr_health_log_cron;then code=0;else code=$?;fi
printf '%s %s %s %s\n' "$code" "$cfmgr_health_cron_ready" "${boundaries:-0}" "${accounts:-0}"
"""
    for damage, expected in (
        ("none", b"0 1 3 2\n"),
        ("identity", b"1 0 2 1\n"),
        ("account", b"1 0 3 2\n"),
        ("content", b"1 0 3 1\n"),
    ):
        result = subprocess.run(
            [*shell, "-c", script, "cron-test", str(ROOT), str(tmp_path), damage],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            expected,
            b"",
        ), damage


def test_health_logging_process_uncertain_scan_never_claims_complete(shell, tmp_path):
    script = r"""
. "$1/modules/status.sh"
base=$2 damage=$3
cfmgr_status_context=$base cfmgr_source=$1 cfmgr_health_collect_deadline=100 cfmgr_health_opt=$base/opt
cfmgr_health_admit_native() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=0; }
cfmgr_health_run() { cfmgr_probe_stdout=$base/pids;cfmgr_probe_stderr=$base/err;printf 'CFMGR-HEALTH-PIDS 1 1\n101\nEND 1\n' >"$cfmgr_probe_stdout";cfmgr_probe_status=reaped;cfmgr_probe_pid=102;if [ "$damage" = owned ];then cfmgr_probe_pid=101;fi;: >"$cfmgr_probe_stderr";cfmgr_probe_exit=0;if [ "$damage" = truncated ];then printf 'CFMGR-HEALTH-PIDS 1 1\n101\n' >"$cfmgr_probe_stdout";fi; }
cfmgr_health_log_stage() { cfmgr_health_log_stage_file=$base/index;: >"$cfmgr_health_log_stage_file"; }
cfmgr_health_log_stat() { [ "$damage" != incomplete ] || return 1;cfmgr_health_log_stat_comm=unrelated; }
cfmgr_health_log_parse() { cfmgr_probe_stdout=$base/process;: >"$cfmgr_probe_stdout"; }
if cfmgr_health_log_processes;then code=0;else code=$?;fi
printf '%s %s %s\n' "$code" "$cfmgr_health_process_ready" "$cfmgr_health_process_scan_complete"
"""
    for damage, expected in (
        ("normal", b"0 1 1\n"),
        ("incomplete", b"1 0 0\n"),
        ("owned", b"0 1 1\n"),
        ("truncated", b"1 0 0\n"),
    ):
        result = subprocess.run(
            [*shell, "-c", script, "process-test", str(ROOT), str(tmp_path), damage],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")


def test_health_logging_process_identity_and_noncrond_are_rechecked_privately(
    shell, tools, tmp_path
):
    source = tmp_path / "source"
    (source / "modules/helpers").mkdir(parents=True)
    (source / "modules/helpers/worker.sh").write_text(
        (ROOT / "modules/helpers/worker.sh").read_text()
    )
    context = tmp_path / "private"
    context.mkdir()
    opt = tmp_path / "opt"
    (opt / "sbin").mkdir(parents=True)
    (opt / "sbin/syslog-ng").write_text("fixture executable identity\n")
    proc = tmp_path / "proc/101"
    proc.mkdir(parents=True)
    (tmp_path / "busybox").write_text("native identity fixture\n")
    (proc / "exe").symlink_to(opt / "sbin/syslog-ng")
    text = (ROOT / "modules/status.sh").read_text()
    start = text.index("cfmgr_health_log_stat()")
    end = text.index("cfmgr_health_log_cron_boundary()", start)
    text = (
        text[:start]
        + text[start:end]
        .replace('"/proc/', f'"{tmp_path}/proc/')
        .replace("/bin/busybox", str(tmp_path / "busybox"))
        + text[end:]
    )
    (source / "modules/status.sh").write_text(text)
    # Raw argv lives solely in a private byte/receipt file throughout collection.
    canary = "private-process-CANARY"
    raw = b"/opt/sbin/syslog-ng\0--debug\0" + canary.encode() + b"\0"
    hexdump = context / "hex"
    hexdump.write_text("".join(f"{b:02x}\n" for b in raw))
    script = r"""
base=$1 source=$2 selected_sh=$3 selected_awk=$4 damage=$5
. "$source/modules/status.sh"
cfmgr_source=$source cfmgr_status_context=$base/private cfmgr_health_opt=$base/opt cfmgr_health_collect_deadline=100
cfmgr_health_admit_native() { return 0; }
cfmgr_prerequisites_now() { cfmgr_probe_now=0; }
cfmgr_health_log_stage() { cfmgr_health_log_stage_file=$base/private/index;: >"$cfmgr_health_log_stage_file"; }
cfmgr_health_canonical() { if [ "$damage" = noncrond ];then cfmgr_health_resolved=$base/busybox;else cfmgr_health_resolved=$base/opt/sbin/syslog-ng;fi; }
cfmgr_health_run() {
    mode=$1;shift 2
    serial=$((${serial:-0}+1));cfmgr_probe_stdout=$base/private/$mode.$serial.out cfmgr_probe_stderr=$base/private/$mode.$serial.err
    cfmgr_probe_exit=0 cfmgr_probe_status=reaped;: >"$cfmgr_probe_stderr"
    printf '%s\n' "$mode" "$@" >>"$base/arguments"
    case $mode in
    health-log-pids) printf 'CFMGR-HEALTH-PIDS 1 1\n101\nEND 1\n' >"$cfmgr_probe_stdout" ;;
    health-log-proc-meta)
        metacalls=$((${metacalls:-0}+1));inode=99
        [ "$damage:$metacalls" != inode:2 ] || inode=100
        printf '%s -rwxr-xr-x 1 0 0 100 Jan 1 00:00 executable\n' "$inode" >"$cfmgr_probe_stdout"
        if [ "$damage:$metacalls" = start:2 ];then printf '101 (syslog-ng) S 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 999 0\n' >"$base/proc/101/stat";fi
        ;;
    health-log-hex) cfmgr_probe_stdout=$base/private/hex ;;
    health-log-argv)
        "$selected_sh" "$source/modules/helpers/worker.sh" health-log-argv "$selected_awk" "$cfmgr_status_context" "$@" >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr" || cfmgr_probe_exit=$?
        ;;
    *) return 9 ;;
    esac
}
cfmgr_health_log_parse() {
    "$selected_sh" "$source/modules/helpers/worker.sh" health-log-process "$selected_awk" "$cfmgr_status_context" "$source/modules/status.sh" "$1" "$2" "$3" - >"$base/private/process" || return $?
    cfmgr_probe_stdout=$base/private/process
}
if cfmgr_health_log_processes;then code=0;else code=$?;fi
printf '%s %s %s %s\n' "$code" "$cfmgr_health_process_ready" "$cfmgr_health_process_scan_complete" "${metacalls:-0}"
"""
    for damage, expected in (
        ("none", b"0 1 1 2\n"),
        ("inode", b"1 0 0 2\n"),
        ("start", b"1 0 0 2\n"),
        ("noncrond", b"0 1 1 2\n"),
    ):
        comm = "busybox" if damage == "noncrond" else "syslog-ng"
        (proc / "exe").unlink()
        (proc / "exe").symlink_to(
            tmp_path / "busybox" if damage == "noncrond" else opt / "sbin/syslog-ng"
        )
        candidate_raw = b"/bin/busybox\0httpd\0" if damage == "noncrond" else raw
        hexdump.write_text("".join(f"{b:02x}\n" for b in candidate_raw))
        (proc / "stat").write_text(f"101 ({comm}) S " + "0 " * 18 + "456 0\n")
        result = subprocess.run(
            [
                *shell,
                "-c",
                script,
                "identity-test",
                str(tmp_path),
                str(source),
                tools["sh"],
                tools["awk"],
                damage,
            ],
            capture_output=True,
            check=False,
            env={**os.environ, "LC_ALL": "C"},
            timeout=4,
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            expected,
            b"",
        ), damage
        assert canary not in (tmp_path / "arguments").read_text()
        assert canary.encode() not in result.stdout + result.stderr


def test_health_logging_mount_anchor_and_native_append_eof(commands, shell, tmp_path):
    spec = tmp_path / "spec"
    spec.write_text("rule\t/tmp/mnt/volume/entware/etc/rule\tpublic\twhole\n")
    raw = tmp_path / "raw"
    paths = (
        "/",
        "/tmp",
        "/tmp/mnt",
        "/tmp/mnt/volume",
        "/tmp/mnt/volume/entware",
        "/tmp/mnt/volume/entware/etc",
    )
    raw.write_text(
        "".join(
            f"{i} {'drwxrwxrwt' if path == '/tmp' else 'drwxr-xr-x'} 1 0 0 0 Jan 1 00:00 {path}\n"
            for i, path in enumerate(paths, 1)
        )
        + "8 -rw-r--r-- 1 0 0 3 Jan 1 00:00 /tmp/mnt/volume/entware/etc/rule\n"
    )
    result = logging_parser(
        commands,
        "metadata",
        raw,
        spec,
        "normal\t/tmp/mnt/volume/entware\t/tmp/mnt/volume",
    )
    assert (
        result.returncode == 0
        and b"MEMBER\trule\t1\t8\t3\t-rw-r--r--\t" in result.stdout
    )
    assert (
        b"MEMBER\trule\t0\t" in logging_parser(commands, "metadata", raw, spec).stdout
    )
    raw.write_bytes(b"complete\nunterminated")
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1/modules/status.sh"; cfmgr_health_log_append_bytes=0 cfmgr_health_log_append_limit=65536; cfmgr_health_log_append "$2/raw" "$2/output"',
            "append-test",
            str(ROOT),
            str(tmp_path),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 1 and result.stderr == b""
    assert (tmp_path / "output").read_bytes() == b"complete\n"


def test_health_logging_append_never_exceeds_its_reserved_extent(shell, tmp_path):
    (tmp_path / "raw").write_bytes(b"first\nsecond\n")
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1/modules/status.sh"; cfmgr_health_log_append_bytes=0 cfmgr_health_log_append_limit=6; cfmgr_health_log_append "$2/raw" "$2/output"; [ "$?" = 1 ] && [ "$cfmgr_health_reason" = budget ]',
            "append-bound",
            str(ROOT),
            str(tmp_path),
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert (tmp_path / "output").read_bytes() == b"first\n"


def test_health_logging_ordinary_failure_keeps_later_groups_available(shell):
    for failure, expected in ((1, b"logging.observation UNKNOWN\nlater\n"), (3, b"")):
        script = r"""
. "$1/modules/status.sh"
_cfmgr_health_logging_collect() { return "$2"; }
cfmgr_health_row() { printf '%s %s\n' "$1" "$2"; }
cfmgr_health_logging_collect "$1" "$2" || exit $?
printf 'later\n'
"""
        # The injected failure is immutable test code; no product data selects it.
        script = script.replace('return "$2"', f"return {failure}")
        result = subprocess.run(
            [*shell, "-c", script, "logging-fallback", str(ROOT), str(failure)],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0 if failure == 1 else 3,
            expected,
            b"",
        )


CROND_SPOOL_HEX = b"2f7661722f73706f6f6c2f63726f6e2f63726f6e74616273"


def run_health_hooks_getter(commands, tmp_path, value):
    data = json.dumps(value, separators=(",", ":")).encode()
    program = awk_program("json", "config_schema", "config_observation")
    program += awk_program("health_hooks_authority")
    result = subprocess.run(
        [
            *commands[1],
            "-v",
            "cfmgr_json_mode=tree",
            "-v",
            f"cfmgr_json_size={len(data)}",
            "-v",
            "cfmgr_config_mode=archive-data",
            program,
        ],
        input=data,
        capture_output=True,
        check=False,
        env={**os.environ, "LC_ALL": "C"},
        timeout=5,
    )
    return result


def test_health_hooks_private_getter_projects_only_fixed_current_owners(
    commands, schema2_config, tmp_path
):
    value = json.loads(schema2_config)
    generation = int(value["generation"])
    digest = "a" * 64
    value["ownership"]["components"] = [
        {
            "schema": 1,
            "component": "private-canary-component",
            "path": "/jffs/scripts/wan-event",
            "generation": generation,
            "sha256": digest,
        },
        {
            "schema": 1,
            "component": "private-canary-arbitrary-owner",
            "path": "/tmp/private-canary-path",
            "generation": generation,
            "sha256": "b" * 64,
        },
        {
            "schema": 1,
            "component": "future-owner",
            "path": "/jffs/scripts/ddns-start",
            "generation": generation + 1,
            "sha256": "c" * 64,
        },
    ]
    result = run_health_hooks_getter(commands, tmp_path, value)
    assert (result.returncode, result.stderr) == (0, b""), (
        result.stdout,
        result.stderr,
    )
    assert result.stdout.startswith(f"CFMGR-HOOKS 1 {generation}\n".encode())
    assert f"HOOK wan-event {generation} {digest} END\n".encode() in result.stdout
    assert b"HOOK ddns-start - - END\n" in result.stdout
    assert b"/tmp/private-canary-path" not in result.stdout
    assert b"private-canary-component" not in result.stdout
    assert b"private-canary-arbitrary-owner" not in result.stdout
    assert b"future-owner" not in result.stdout
    assert result.stdout.endswith(b"END 7 END\n")


def test_health_hooks_private_getter_rejects_duplicate_fixed_path(
    commands, schema2_config, tmp_path
):
    value = json.loads(schema2_config)
    generation = int(value["generation"])
    value["ownership"]["components"] = [
        {
            "schema": 1,
            "component": f"owner-{index}",
            "path": "/jffs/scripts/wan-event",
            "generation": generation,
            "sha256": "d" * 64,
        }
        for index in (1, 2)
    ]
    result = run_health_hooks_getter(commands, tmp_path, value)
    assert result.returncode != 0
    assert result.stdout == b""


def run_health_hooks_cron(commands, tmp_path, cron: bytes, process: bytes):
    cron_file = tmp_path / "cron.snapshot"
    process_file = tmp_path / "process.receipt"
    cron_file.write_bytes(cron)
    process_file.write_bytes(process)
    program = awk_program("health_hooks_cron")
    result = subprocess.run(
        [
            *commands[1],
            program,
            str(cron_file),
            str(process_file),
            str(len(cron)),
            str(cron.count(b"\n")),
            str(len(process)),
        ],
        capture_output=True,
        check=False,
        env={**os.environ, "LC_ALL": "C"},
        timeout=5,
    )
    return result


def valid_crond_receipt():
    return b"CROND 123 4001 " + CROND_SPOOL_HEX + b" END\n"


def test_health_hooks_cron_exact_labels_schedule_and_shell_are_counted_privately(
    commands, tmp_path
):
    cron = (
        b"SHELL=/bin/sh\n"
        b"# comment containing #CFMgrWatchdog#\n"
        b"* * * * * /jffs/addons/CFMgr.d/cfmgr watchdog #CFMgrWatchdog#\n"
        b"37 3 * * * /jffs/addons/CFMgr.d/cfmgr update #CFMgrCloudflaredUpdate#\n"
        b"* * * * * /tmp/foreign fooCFMgrWatchdog #near-label\n"
    )
    result = run_health_hooks_cron(commands, tmp_path, cron, valid_crond_receipt())
    assert (result.returncode, result.stderr) == (0, b""), (
        result.stdout,
        result.stderr,
    )
    assert b"JOB watchdog 1 exact admitted END\n" in result.stdout
    assert b"JOB cloud-update 1 exact admitted END\n" in result.stdout
    assert b"CFMgr.d/cfmgr" not in result.stdout
    assert b"/tmp/foreign" not in result.stdout
    assert result.stdout.endswith(b"END 2 END\n")


def test_health_hooks_cron_duplicate_mismatch_and_unverified_default_are_distinct(
    commands, tmp_path
):
    cron = (
        b"* * * * * /jffs/addons/CFMgr.d/cfmgr watchdog #CFMgrWatchdog#\n"
        b"* * * * * /jffs/addons/CFMgr.d/cfmgr watchdog #CFMgrWatchdog#\n"
        b"37 4 * * * /jffs/addons/CFMgr.d/cfmgr update #CFMgrCloudflaredUpdate#\n"
    )
    result = run_health_hooks_cron(commands, tmp_path, cron, valid_crond_receipt())
    assert result.returncode == 0
    assert b"JOB watchdog 2 ambiguous unknown END\n" in result.stdout
    assert b"JOB cloud-update 1 mismatch unknown END\n" in result.stdout


def test_health_hooks_cron_reuses_snapshot_without_scribe_evidence(
    commands, tools, tmp_path
):
    # Exercise the actual observer shell function with only its shared
    # cron/process inputs. No Scribe file, binary, getter or recollection exists.
    cron = (
        b"SHELL=/bin/sh\n"
        b"* * * * * /jffs/addons/CFMgr.d/cfmgr watchdog #CFMgrWatchdog#\n"
        b"37 3 * * * /jffs/addons/CFMgr.d/cfmgr update #CFMgrCloudflaredUpdate#\n"
    )
    cron_file = tmp_path / "cron.snapshot"
    process_file = tmp_path / "process.receipt"
    cron_file.write_bytes(cron)
    process_file.write_bytes(valid_crond_receipt())
    script = r"""
. "$1/modules/status.sh"
cfmgr_source=$1
cfmgr_status_context=$2
test_awk=$6
cfmgr_health_cron_ready=1 cfmgr_health_process_ready=1 cfmgr_health_process_scan_complete=1
cfmgr_health_cron_file=$3 cfmgr_health_process_file=$4 cfmgr_health_cron_bytes=$5
cfmgr_health_log_spec_write() { cfmgr_health_log_spec_file=$cfmgr_status_context/spec; : >"$cfmgr_health_log_spec_file"; }
cfmgr_health_log_group() {
    cfmgr_health_log_group_file=$cfmgr_status_context/counts
    lf=$(wc -l <"$cfmgr_health_cron_file") || return 1
    printf 'COUNT\tcron-observer\t%s\t%s\n' "$cfmgr_health_cron_bytes" "$lf" >"$cfmgr_health_log_group_file"
}
cfmgr_health_count() {
    cfmgr_health_size=$(wc -c <"$1") || return 1
    [ "$cfmgr_health_size" -le "$2" ]
}
cfmgr_health_run() {
    mode=$1; shift 3
    serial=$((${serial:-0} + 1))
    cfmgr_probe_stdout=$cfmgr_status_context/out.$serial cfmgr_probe_stderr=$cfmgr_status_context/err.$serial
    : >"$cfmgr_probe_stderr"
    case $mode in
        health-hooks-cron)
            cfmgr_status_awk_health_hooks_cron
            "$test_awk" "$cfmgr_awk_program" "$1" "$2" "$3" "$4" "$5" >"$cfmgr_probe_stdout"
            cfmgr_probe_exit=$?
            ;;
        health-hooks-frame)
            cfmgr_status_awk_health_hooks_frame
            "$test_awk" "$cfmgr_awk_program" "$1" "$2" "$3" >"$cfmgr_probe_stdout"
            cfmgr_probe_exit=$?
            ;;
        *) return 2 ;;
    esac
    return 0
}
    if cfmgr_health_hooks_cron_observe; then printf 'OBSERVER_OK\n'; else printf 'OBSERVER_FAIL %s\n' "$?"; fi
cat "$cfmgr_health_hooks_jobs"
"""
    result = subprocess.run(
        [
            *commands[0],
            "-c",
            script,
            "hook-cron-test",
            str(ROOT),
            str(tmp_path),
            str(cron_file),
            str(process_file),
            str(len(cron)),
            adapt_native("/usr/bin/awk", tmp_path / "jffs", tools, commands[0]),
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stderr) == (0, b""), (
        result.stdout,
        result.stderr.decode().splitlines()[-100:],
    )
    assert b"JOB watchdog 1 exact admitted END\n" in result.stdout
    assert b"JOB cloud-update 1 exact admitted END\n" in result.stdout


def test_health_hooks_cron_rejects_bad_frames_and_process_identity(commands, tmp_path):
    valid = b"SHELL=/bin/sh\n* * * * * /x #CFMgrWatchdog#\n"
    malformed = (
        valid[:-1],
        valid.replace(b"SHELL=/bin/sh", b"SHELL=/bin/sh\x00"),
        valid + b"#" * 4097 + b"\n",
    )
    for index, cron in enumerate(malformed):
        case = tmp_path / str(index)
        case.mkdir()
        result = run_health_hooks_cron(commands, case, cron, valid_crond_receipt())
        assert result.returncode != 0
        assert result.stdout == b""
    wrong_process = b"CROND 123 4001 2f746d70 END\n"
    result = run_health_hooks_cron(commands, tmp_path, valid, wrong_process)
    assert result.returncode != 0
    assert result.stdout == b""


@pytest.mark.skipif(
    sys.platform != "linux",
    reason="actual health supervision requires Linux proc and FDs",
)
def test_linux_full_health_entry_normal_journey(
    shell, tools, installed_package, schema2_config, capsys
):
    """One normal integrated run per selected host/native shell, CI execution only.

    Real: entry admission, health and prerequisite dispatch, private parsers,
    numeric reservations, Linux clock/identity/signals/reap, directory and private
    file FDs, cleanup. Explicit firmware boundaries: mountinfo/block-device facts,
    NVRAM/account ownership, syslog/logrotate executable observations, immutable
    daemon facts, and HTTP response executable. No mounts or external requests.
    Existing stall tests independently cover supervisor failures and real TLS.
    """
    entry, support, _, _ = installed_package
    # The shallow owned root keeps the real bounded metadata ancestor inventory
    # representative instead of spending it on pytest's host directory nesting.
    with tempfile.TemporaryDirectory(prefix="cfh-", dir="/tmp") as directory:
        base = Path(directory)
        package = full_health_package(
            entry, support, base, tools, shell, schema2_config
        )
        selected = package["entry"]
        audit = base / "audit"

        def immutable_inventory():
            return {
                str(path.relative_to(base)): (
                    path.lstat().st_ino,
                    path.lstat().st_mode,
                    os.readlink(path)
                    if path.is_symlink()
                    else hashlib.sha256(path.read_bytes()).hexdigest(),
                )
                for path in base.rglob("*")
                if (path.is_file() or path.is_symlink())
                and path.parts[len(base.parts)] not in {"audit", "ram"}
            }

        before = immutable_inventory()
        started = time.monotonic()
        process = subprocess.Popen(
            [*shell, str(selected), "--health"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
            env={
                "PATH": os.environ["PATH"],
                "LC_ALL": "C",
                "TERM": "dumb",
                "COLUMNS": "100",
            },
        )
        try:
            stdout, stderr = process.communicate(timeout=55)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.communicate()
            pytest.fail(
                "full health entry exceeded its 45-second report envelope and cleanup margin"
            )
        elapsed = time.monotonic() - started
        ledger_path = audit / "ledger"
        assert ledger_path.is_file(), (process.returncode, stdout, stderr)
        ledger = ledger_path.read_text().split()
        assert len(ledger) == 10, ledger
        (
            operations,
            files,
            reserved,
            requests,
            rows,
            final_ops,
            final_files,
            final_bytes,
            seconds,
        ) = map(int, ledger[:9])
        # Keep the measured partial ledger in any failed CI assertion. Count caps
        # remain production-owned; the fixture never raises/bypasses a limit.
        measured = {
            "operations": operations,
            "files": files,
            "bytes": reserved,
            "requests": requests,
            "rows": rows,
            "final_operations": final_ops,
            "final_files": final_files,
            "final_bytes": final_bytes,
            "report_seconds": seconds,
            "wall_seconds": elapsed,
            "reason": ledger[9],
        }
        with capsys.disabled():
            print("full-health normal ledger:", measured, flush=True)
        if (audit / "process-diagnostic").exists():
            print((audit / "process-diagnostic").read_text())
        if ledger[9] != "normal" or requests != 12:
            print("full-health observed rows:\n" + (audit / "rows").read_text())
            print("full-health routes:\n" + (audit / "routes").read_text())
        assert process.returncode == 0 and stderr == b"", (measured, stdout, stderr)
        assert ledger[9] == "normal", measured
        assert requests == 12 and 0 < rows <= 96 and 0 < seconds < 45, measured
        assert operations <= 504 and files <= 1136, measured
        assert reserved + final_bytes <= 12 * 1024 * 1024, measured
        assert final_ops <= 8 and final_files <= 16 and elapsed < 50, measured
        assert immutable_inventory() == before, (
            "health changed a retained fixture source"
        )
        assert not Path((audit / "context").read_text().strip()).exists()
        assert list((base / "ram").iterdir()) == [], (
            "owned health context survived cleanup"
        )
        route_rows = [
            row.split() for row in (audit / "routes").read_text().splitlines()
        ]
        modes = [row[0] for row in route_rows]
        for mode in (
            "health-config",
            "health-inventory",
            "health-native-metadata",
            "health-entware-metadata",
            "health-cloud-yaml",
            "health-cloud-json",
            "health-cloud-pem",
            "health-get",
            "health-render",
        ):
            assert mode in modes, (mode, measured, modes)
        for row in route_rows:
            if row[3].isdigit():
                assert not Path("/proc", row[3]).exists(), (
                    "owned supervised child survived the report"
                )
        request_kinds = (audit / "requests").read_text().splitlines()
        assert {kind: request_kinds.count(kind) for kind in set(request_kinds)} == {
            "zone": 1,
            "dns": 3,
            "list": 2,
            "items": 2,
            "tunnel": 1,
            "connections": 1,
            "trace4": 1,
            "trace6": 1,
        }, (measured, request_kinds)
        raw_rows = (audit / "rows").read_text()
        assert len(raw_rows.splitlines()) == rows
        assert ".integration\t" not in raw_rows and "report.budget\t" not in raw_rows, (
            measured,
            raw_rows,
        )
        for expected in (
            "config.authority",
            "storage.entware",
            "cloudflared.runtime.local",
            "cloudflared.yaml.identity",
            "cloudflared.certificate.live",
            "cloudflared.binary",
        ):
            assert expected + "\tPASS\t" in raw_rows, (expected, measured, raw_rows)
        for expected in (
            "backup.destination\tPASS\t",
            "backup.access\tUNKNOWN\t",
            "backup.history\tSKIP\t",
            "hooks.files\tPASS\t",
            "hooks.integrity\tPASS\t",
            "hooks.watchdog\tPASS\t",
            "hooks.cloud-update\tPASS\t",
            "hooks.dispatch\tUNKNOWN\t",
            "logging.base\tPASS\t",
            "logging.ddns.policy\tPASS\t",
            "logging.ip_sync.policy\tPASS\t",
            "logging.cloudflared.policy\tPASS\t",
            "package.inventory\tPASS\t",
            "recovery.guards\tPASS\t",
        ):
            assert expected in raw_rows, (expected, measured, raw_rows)
        for canary in package["canaries"]:
            assert canary.encode() not in stdout + stderr
            assert canary not in (audit / "network-environment").read_text()
        assert b"MUST_NOT_EXECUTE" not in stdout + stderr
        assert (
            "cfmgr_fixture_actual_run"
            in (base / "jffs/addons/CFMgr.d/modules/lib/execution.sh").read_text()
        )
        assert len((audit / "transformations").read_text().splitlines()) == sum(
            path.is_file() and path.name != ".DS_Store"
            for path in (ROOT / "modules").rglob("*")
        )


@pytest.mark.parametrize(
    "damage,expected",
    [
        ("none", "PASS"),
        ("unlisted", "FAIL"),
        ("unlisted-space", "FAIL"),
        ("passive", "UNKNOWN"),
        ("passive-nested", "UNKNOWN"),
        ("placeholder", None),
        ("worker-mode", None),
        ("original", None),
        ("installed-entry", None),
        ("changed-metadata", None),
        ("catalog-tail", None),
    ],
)
def test_health_package_complete_binding(commands, tmp_path, damage, expected):
    """Private receipt fixtures exercise the shared full grammar and binding.

    Native metadata, actual installed entry and supervisor are separately covered
    by the full Linux journey. These mutations must never manufacture a PASS.
    """
    fixed = {
        "entry": "cfmgr.sh",
        "catalog": "catalog.txt",
        "backup": "modules/backup.sh",
        "manager": "modules/manager.sh",
        "status": "modules/status.sh",
        "helpers-empty": "modules/helpers/.gitkeep",
        "worker": "modules/helpers/worker.sh",
        "hooks-empty": "modules/hooks/.gitkeep",
        "lib-empty": "modules/lib/.gitkeep",
        "config": "modules/lib/config.sh",
        "execution": "modules/lib/execution.sh",
        "network": "modules/lib/network.sh",
        "package": "modules/lib/package.sh",
        "storage": "modules/lib/storage.sh",
    }
    paths = sorted(fixed.values())
    if damage in {"passive", "passive-nested"}:
        paths.append(
            "modules/passive-dir/data"
            if damage == "passive-nested"
            else "modules/passive.dat"
        )
        paths.sort()
    catalog = "CFMGR-CATALOG 1 0.1.0\n" + "".join(
        f"{p}\t{'library' if '/lib/' in p else 'helper' if '/helpers/' in p else 'data'}\n"
        for p in paths
        if p.startswith("modules/")
    )
    payloads = {p: b"" if p.endswith(".gitkeep") else b"fixture\n" for p in paths}
    payloads["catalog.txt"] = catalog.encode()
    if damage == "placeholder":
        payloads["modules/lib/.gitkeep"] = b"not empty\n"
    records = {
        p: (
            "0755" if p in {"cfmgr.sh", "modules/helpers/worker.sh"} else "0644",
            str(len(payloads[p])),
            hashlib.sha256(payloads[p]).hexdigest(),
            p,
        )
        for p in paths
    }
    manifest = "CFMGR-MANIFEST 2 0.1.0 1 2\n" + "".join(
        "\t".join(records[p]) + "\n" for p in paths
    )
    sources = {"manifest": manifest, "catalog": catalog}
    dirs = {
        "d0": "modules",
        "d1": "modules/lib",
        "d2": "modules/helpers",
        "d3": "modules/hooks",
    }
    for role, directory in dirs.items():
        names = {
            p.removeprefix(directory + "/").split("/")[0]
            for p in paths
            if p.startswith(directory + "/")
        }
        if damage in {"unlisted", "unlisted-space"} and role == "d0":
            names.add("extra file.sh" if damage == "unlisted-space" else "unexpected")
        sources[role] = "".join(n + "\n" for n in sorted(names))
    metadata = []
    for index, (role, p) in enumerate(fixed.items(), start=1):
        permission = "-rwxr-xr-x" if records[p][0] == "0755" else "-rw-r--r--"
        if damage == "worker-mode" and role == "worker":
            permission = "-rw-r--r--"
        metadata.append(
            f"MEMBER\t{role}\t1\t{index}\t{records[p][1]}\t{permission}\tprotected-chain\n"
        )
    metadata.append(
        f"MEMBER\tmanifest\t1\t20\t{len(manifest)}\t-rw-r--r--\tprotected-chain\n"
    )
    metadata.extend(
        f"MEMBER\t{r}\t1\t{21 + i}\t128\tdrwxr-xr-x\tprotected-chain\n"
        for i, r in enumerate(dirs)
    )
    before = "".join(metadata)
    after = (
        before.replace("MEMBER\tentry\t1\t1\t", "MEMBER\tentry\t1\t999\t")
        if damage == "changed-metadata"
        else before
    )
    hashes = "".join(
        f"HASH\t{r}\t{('f' * 64 if damage == 'installed-entry' and r == 'entry' else records[fixed[r]][2])}\n"
        for r in ("entry", "catalog")
    )
    index = "CFMGR-PACKAGE\t1\t0.1.0\tverified:verified:verified:verified\n"
    for role, p in fixed.items():
        if role.endswith("empty"):
            continue
        record = records[p]
        if damage == "original" and role == "status":
            record = (record[0], record[1], "0" * 64, record[3])
        index += "ORIGINAL\t" + "\t".join(record) + "\n"
    counts = ""
    for role, content in sources.items():
        if damage == "catalog-tail" and role == "catalog":
            content = content.rstrip("\n")
        (tmp_path / role).write_text(content)
        index += f"SOURCE\t{role}\t{role}\n"
        counts += f"COUNT\t{role}\t{len(content)}\t{content.count(chr(10))}\n"
    for role, content in {
        "COUNTS": counts,
        "BEFORE": before,
        "AFTER": after,
        "HASHES": hashes,
    }.items():
        (tmp_path / role).write_text(content)
        index += f"{role}\t{role}\n"
    (tmp_path / "index").write_text(index + "END\n")
    result = subprocess.run(
        [
            *commands[1],
            awk_program("package_records", "health_package"),
            tmp_path,
            tmp_path / "index",
        ],
        capture_output=True,
        check=False,
        timeout=3,
        env={**os.environ, "LC_ALL": "C"},
    )
    if expected is None:
        assert result.returncode != 0 and not result.stdout
    else:
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            f"CFMGR-PACKAGE 1 {expected} END\n".encode(),
            b"",
        )


@pytest.mark.parametrize(
    "listing,complete,expected",
    [
        (b"config\nsetup.complete\n", "1", "PASS"),
        (b"config\n.config-save.retired\n", "1", "WARN"),
        (b"entry.stage\nbad\x01name\n", "0", "WARN"),
        (b"config\n", "0", "UNKNOWN"),
        (b"config", "1", "UNKNOWN"),
        (b"config\nconfig\n", "1", "UNKNOWN"),
    ],
)
def test_health_recovery_complete_listing_required(
    commands, tmp_path, listing, complete, expected
):
    snapshot = tmp_path / "listing"
    snapshot.write_bytes(listing)
    result = subprocess.run(
        [
            *commands[1],
            awk_program("health_flat"),
            snapshot,
            str(len(listing)),
            str(listing.count(b"\n")),
            complete,
        ],
        capture_output=True,
        check=False,
        timeout=3,
        env={**os.environ, "LC_ALL": "C"},
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        f"CFMGR-GUARDS 1 {expected} END\n".encode(),
        b"",
    )


@pytest.mark.parametrize("late_result", [1, 3])
def test_health_recovery_observed_guard_survives_metadata_failure(
    shell, tmp_path, late_result
):
    """State containment only: native flat listing is covered by the full journey."""
    script = r"""
. "$1/modules/status.sh"
cfmgr_source=$2 cfmgr_health_config=unavailable cfmgr_health_package=missing
metadata_calls=0
cfmgr_health_log_spec_write() { cfmgr_health_log_spec_file=$cfmgr_source/spec; }
late=$3
cfmgr_health_log_metadata() {
    metadata_calls=$((metadata_calls + 1))
    [ "$metadata_calls" = 1 ] || return "$late"
    cfmgr_health_log_metadata_file=$cfmgr_source/metadata
}
cfmgr_health_log_member() { cfmgr_health_log_member_ok=1 cfmgr_health_log_member_identity=protected; }
cfmgr_health_flat_list() { cfmgr_health_flat_file=$cfmgr_source/listing cfmgr_health_flat_complete=1; }
cfmgr_health_log_group() {
    cfmgr_health_log_group_file=$cfmgr_source/counts
    printf 'COUNT\troot\t12\t1\n' >"$cfmgr_health_log_group_file"
}
cfmgr_health_run() {
    cfmgr_probe_stdout=$cfmgr_source/receipt cfmgr_probe_stderr=$cfmgr_source/error cfmgr_probe_exit=0
    printf 'CFMGR-GUARDS 1 WARN END\n' >"$cfmgr_probe_stdout"
    : >"$cfmgr_probe_stderr"
}
cfmgr_health_row() { printf '%s %s\n' "$1" "$2"; }
if cfmgr_health_recovery_collect; then rc=0; else rc=$?; fi
printf 'RESULT %s\n' "$rc"
"""
    result = subprocess.run(
        [*shell, "-c", script, "recovery-state", ROOT, tmp_path, str(late_result)],
        capture_output=True,
        check=False,
        timeout=3,
    )
    expected = (
        b"recovery.guards WARN\nRESULT 0\n" if late_result == 1 else b"RESULT 3\n"
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, expected, b"")
