"""Native-only status projection and actual installed choice0 consumer.

No live router/provider input. Host supervision adapters are labelled; one Linux
case retains the actual bounded supervisor and fixed executable probe body.
"""

from __future__ import annotations

import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from entry_package_fixture import adapt_native, finish_package
from runtime_awk import awk_arguments, awk_program
from test_config_observation import commands, config, schema2_config
from test_dependency_reinstall import entry_run, installed_entry
from test_install import shell, tools
from test_prerequisites import pause_definition

ROOT = Path(__file__).resolve().parents[1]
BOOT = "12345678-1234-1234-1234-123456789abc"
NOW = 1_700_000_000
__all__ = ["commands", "config", "installed_entry", "schema2_config", "shell", "tools"]


HEALTH_SECRET = "cfut_fixture-secret_CANARY-123"
ZONE = "a" * 32
ACCOUNT = "b" * 32
LIST = "c" * 32


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
    result = subprocess.run(
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
            "CFMGR_HEALTH_BYTES": str(len(request.stdout)),
        },
    )
    assert result.stderr == b""
    assert HEALTH_SECRET.encode() not in result.stdout
    if case in {"valid", "partial", "unknown-pagination", "empty"}:
        assert result.returncode == 0
        state = "partial" if case in {"partial", "unknown-pagination"} else "verified"
        count = 0 if case == "empty" else 1
        assert (
            result.stdout
            == f"CFMGR-HEALTH-RESPONSE 1 {state} {count} api-read END\n".encode()
        )
    else:
        assert result.returncode != 0 and result.stdout == b""


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
    result = subprocess.run(
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
            "CFMGR_HEALTH_BYTES": str(len(request.stdout)),
        },
    )
    assert result.stderr == b""
    if expected is None:
        assert result.returncode != 0 and result.stdout == b""
    else:
        assert (
            result.returncode == 0
            and result.stdout
            == f"CFMGR-HEALTH-RESPONSE 1 {expected} 1 api-read END\n".encode()
        )


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
cfmgr_health_operations=247 cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_probe_serial=247
cfmgr_health_reserve health-date || exit 15
cfmgr_health_reserve health-date
[ "$?" = 1 ] && [ "$cfmgr_health_operations" = 248 ] || exit 16
cfmgr_health_operations=0 cfmgr_health_files=558
cfmgr_health_reserve health-date || exit 17
cfmgr_health_reserve health-date
[ "$?" = 1 ] && [ "$cfmgr_health_files" = 560 ] || exit 18
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
cfmgr_health_operations=20 cfmgr_health_files=40 cfmgr_health_bytes=327680 cfmgr_health_owned='' cfmgr_probe_serial=20
cfmgr_health_final_begin || exit 26
[ "$cfmgr_health_final_deadline" = 115 ] || exit 27
clock=111
cfmgr_health_final_begin || exit 28
[ "$cfmgr_health_final_deadline" = 115 ] || exit 29
cfmgr_health_reserve health-render || exit 30
cfmgr_health_reserve health-render-count || exit 31
[ "$cfmgr_health_final_operations:$cfmgr_health_final_files:$cfmgr_health_final_bytes" = 2:4:790528 ] || exit 32
[ "$cfmgr_health_operations:$cfmgr_health_files:$cfmgr_health_bytes" = 20:40:327680 ] || exit 33
cfmgr_health_reserve health-date
[ "$?" = 1 ] || exit 34
cfmgr_health_stage_reserve dashboard 32768
[ "$?" = 1 ] && [ "$cfmgr_health_files:$cfmgr_health_bytes" = 40:327680 ] || exit 43
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
for mode in health-scope health-frame health-request-check health-response health-trace health-count health-render-count health-wc-jq health-wc-sha health-count-pair health-current health-uuid health-date health-native health-jq-good health-jq-bad health-sha-bytes health-sha-good health-sha-bad health-timeout-exit health-timeout-expiry health-flock-first health-flock-compete health-flock-after health-flock-release health-flock-finish health-flock-entware-first health-flock-entware-compete health-flock-entware-after health-flock-entware-release health-flock-entware-finish health-curl-features health-ca-pem health-ca-decode health-curl-offline; do
    cfmgr_health_mode "$mode" || exit 10
    [ "$cfmgr_health_mode_limit:$cfmgr_health_mode_bytes:$cfmgr_health_mode_files" = 2:4096:2 ] || exit 11
done
for mode in health-request health-metadata health-native-metadata health-metadata-check health-realpath health-mount health-storage health-inventory health-curl-version health-dig-version health-fields health-config health-nvram health-space health-protected health-uname health-blkid; do
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
