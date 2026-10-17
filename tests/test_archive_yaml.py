"""Real AWK admission of complete, byte-preserved advanced Cloudflared YAML."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest
from runtime_awk import awk_arguments

ROOT = Path(__file__).resolve().parents[1]
PARSER = "cfmgr-parser:backup_yaml"
UUID = "8ea7c314-f0cd-4ca9-813e-44bbdeaa4001"
CREDENTIALS = "/opt/etc/cloudflared/selected.json"
IDENTITY = f"tunnel: {UUID}\ncredentials-file: {CREDENTIALS}\n"


@pytest.fixture(scope="module")
def awk_programs() -> list[tuple[str, list[str]]]:
    found = shutil.which("awk")
    assert found, "Host awk is required for YAML reader tests"
    programs = [("host awk", [found])]
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        shell = os.environ.get("CFMGR_TEST_SHELL", "").split()
        assert shell[:2] == ["busybox", "ash"]
        busybox = shutil.which("busybox")
        expected = ROOT / ".tmp/native-busybox/bin/busybox"
        assert busybox and Path(busybox).resolve() == expected.resolve(), (
            "Required YAML proof must use staged vendor BusyBox"
        )
        programs.append(("pinned BusyBox awk", [busybox, "awk"]))
    return programs


def _invoke(
    awk: list[str],
    source: bytes,
    *,
    budget: int | str = 262144,
    framed: bool = False,
) -> subprocess.CompletedProcess[bytes]:
    data = source if framed else b"".join(f"{b:02x}\n".encode() for b in source)
    return subprocess.run(
        awk_arguments([*awk, "-f", str(PARSER)]),
        input=data,
        capture_output=True,
        check=False,
        env={**os.environ, "LC_ALL": "C", "CFMGR_YAML_METADATA_LIMIT": str(budget)},
        timeout=5,
    )


def _success(
    awk_programs: list[tuple[str, list[str]]],
    source: str,
    inputs: list[tuple[str, str]] | None = None,
    controls: list[tuple[str, str]] | None = None,
) -> None:
    inputs, controls = inputs or [], controls or []
    expected = f"CFMGR-YAML 1\nIDENTITY {UUID} {CREDENTIALS.encode().hex()}\n"
    expected += "".join(
        f"INPUT {i} {role} {value.encode().hex()}\n"
        for i, (role, value) in enumerate(inputs, 1)
    )
    expected += "".join(
        f"CONTROL {role} {value.encode().hex()}\n" for role, value in controls
    )
    expected += f"END {len(inputs)} {len(controls)}\n"
    original = source.encode()
    for label, awk in awk_programs:
        result = _invoke(awk, original)
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            expected.encode(),
            b"",
        ), label
        assert source.encode() == original


def _failure(
    awk_programs: list[tuple[str, list[str]]], source: str | bytes, reason: str
) -> None:
    data = source.encode() if isinstance(source, str) else source
    for label, awk in awk_programs:
        result = _invoke(awk, data)
        assert result.returncode != 0, label
        assert result.stdout == f"CFMGR-YAML-ERROR 1 {reason} END\n".encode(), label
        assert result.stderr == b"", label


def test_published_application_dependency_inventory(awk_programs) -> None:
    source = f'''---
# Unicode commentary survives: café 路由器
"tunnel": "{UUID.upper()}" # exact selected tunnel
'credentials-file': '{CREDENTIALS}'
origincert: /opt/etc/cloudflared/cert.pem
cacert: "/foreign/edge:ca#bundle.pem"
origin-ca-pool: null
originRequest:
  connectTimeout: 30s
  caPool: '/opt/etc/cloudflared/global-ca.pem'
ingress:
  - hostname: 'it''s.example.test'
    service: "https://localhost:443/a#b"
    originRequest:
      caPool: /opt/etc/cloudflared/site-ca.pem
      httpHostHeader: 'host: quoted # data'
  - hostname: internal.example.test
    service: unix:/run/origin.sock
    originRequest:
      caPool: /foreign/shared-ca.pem
  - service: http_status:404
logfile: /opt/var/log/cloudflared.log
pidfile: null
...\n'''
    _success(
        awk_programs,
        source,
        inputs=[
            ("origincert", "/opt/etc/cloudflared/cert.pem"),
            ("cacert", "/foreign/edge:ca#bundle.pem"),
            ("caPool", "/opt/etc/cloudflared/global-ca.pem"),
            ("caPool", "/opt/etc/cloudflared/site-ca.pem"),
            ("caPool", "/foreign/shared-ca.pem"),
        ],
        controls=[("logfile", "/opt/var/log/cloudflared.log")],
    )


def test_private_network_alias_crlf_and_no_final_newline(awk_programs) -> None:
    source = (
        IDENTITY.replace("credentials-file", "cred-file")
        + """warp-routing:
  enabled: true
protocol: quic
edge-ip-version: auto
no-autoupdate: true
token: null
token-file: ''
credentials-contents: ~
config:
origincert: ""
log-directory: /opt/var/log/cloudflared
trace-output: /opt/var/log/trace.json"""
    )
    _success(
        awk_programs,
        source.replace("\n", "\r\n"),
        controls=[
            ("log-directory", "/opt/var/log/cloudflared"),
            ("trace-output", "/opt/var/log/trace.json"),
        ],
    )


def test_block_scalars_and_unknown_nested_data_do_not_invent_identity(
    awk_programs,
) -> None:
    source = (
        IDENTITY
        + """description: |-
  tunnel: deadbeef-dead-beef-dead-beefdeadbeef
  credentials-file: /foreign/not-a-real-reference
  originRequest:
    caPool: /foreign/not-a-real-ca
notes: >2+
  useful multiline text
  another line
unrelated:
  tunnel: nested-name
  credentials-file: /foreign/also-not-root
  labels:
    - alpha
    - 'beta: # quoted'
    - label: entry
      enabled: true
"""
    )
    _success(awk_programs, source)
    _failure(
        awk_programs,
        source.replace(IDENTITY, ""),
        "missing-identity",
    )


def test_json_compatible_escapes_and_quoted_tab(awk_programs) -> None:
    source = IDENTITY.replace(CREDENTIALS, '"\\/opt/etc/cloudflared/selected.json"')
    source += r"""cacert: "/foreign/\u0063a.pem"
comment: "escaped \b\f\n\r\t and \u00e9 \ud83d\ude80"
label: 'literal	tab'
"""
    _success(awk_programs, source, [("cacert", "/foreign/ca.pem")])


def test_unrelated_nested_headers_and_null_containers(awk_programs) -> None:
    source = (
        IDENTITY
        + """originRequest: null
ingress: ~
metadata:
  headers:
    Token: preserved-value
    Config: ordinary-value
    TUNNEL: nested-name
    CaPool: ignored-metadata
    OriginRequest: ordinary-value
  description: café 路由器 🚀
"""
    )
    _success(awk_programs, source)
    _success(
        awk_programs,
        IDENTITY + "originRequest: Null\ningress: NULL\n",
    )
    _failure(
        awk_programs,
        IDENTITY + "originRequest: null\n  caPool: /foreign/hidden.pem\n",
        "invalid-indentation",
    )


@pytest.mark.parametrize(
    ("extra", "reason"),
    [
        ("tunnel: other\n", "duplicate-key"),
        ("cred-file: /opt/other.json\n", "duplicate-authority"),
        ("Tunnel: hidden\n", "ambiguous-key-case"),
        ("originrequest:\n  capool: /foreign/ca.pem\n", "ambiguous-key-case"),
        ("originRequest:\n  capool: /foreign/ca.pem\n", "ambiguous-key-case"),
        (
            "ingress:\n  - service: http_status:404\n    OriginRequest: null\n",
            "ambiguous-key-case",
        ),
        (
            "ingress:\n  - service: http_status:404\n    service: https://localhost\n",
            "duplicate-key",
        ),
        ("token: SECRET-MUST-NOT-LEAK\n", "conflicting-authority"),
        ("token-file: /foreign/token\n", "conflicting-authority"),
        ("credentials-contents: SECRET-MUST-NOT-LEAK\n", "conflicting-authority"),
        ("config: /foreign/other.yml\n", "conflicting-authority"),
        ("token: NuLl\n", "conflicting-authority"),
        ("cacert:\n  path: /foreign/ca.pem\n", "unsupported-field-scalar"),
        ("originRequest: {caPool: /foreign/ca.pem}\n", "unsupported-syntax"),
        ("ingress: []\n", "unsupported-syntax"),
        ("ingress:\n  -\n    - service: http_status:404\n", "unsupported-container"),
        ("foo: &anchor value\n", "unsupported-syntax"),
        ("foo: *anchor\n", "unsupported-syntax"),
        ("<<: defaults\n", "unsupported-merge"),
        ("foo: !tag value\n", "unsupported-syntax"),
        ("---\n", "multiple-documents"),
        ("%YAML 1.2\n", "unsupported-directive"),
        ("foo:\n   child: 1\n  sibling: 2\n", "invalid-indentation"),
        ("foo:\n\tchild: 1\n", "unsupported-tab"),
        ("foo: 'unterminated\n", "malformed-quote"),
        ('foo: "bad\\x41"\n', "unsupported-escape"),
        ("cacert: |\n  /foreign/ca.pem\n", "unsupported-field-scalar"),
        ("cacert: /foreign/../ca.pem\n", "invalid-path"),
        ("cacert: /foreign//ca.pem\n", "invalid-path"),
        ('cacert: "relative.pem"\n', "invalid-path"),
    ],
)
def test_ambiguous_or_unsafe_yaml_fails_without_partial_receipts(
    awk_programs, extra: str, reason: str
) -> None:
    _failure(awk_programs, IDENTITY + extra, reason)


@pytest.mark.parametrize(
    "bad_uuid",
    [
        "UUID",
        "<tunnel-uuid>",
        "tunnel-name",
        "0" * 36,
        "00000000-0000-0000-0000-000000000000",
    ],
)
def test_placeholder_identity_fails(awk_programs, bad_uuid: str) -> None:
    _failure(awk_programs, IDENTITY.replace(UUID, bad_uuid), "invalid-identity")


def test_input_byte_and_syntax_bounds(awk_programs) -> None:
    _failure(awk_programs, IDENTITY.encode() + b"foo: invalid\x00\n", "invalid-control")
    _failure(awk_programs, IDENTITY.encode() + b"foo: a\rb\n", "invalid-line-ending")
    _failure(awk_programs, IDENTITY + "foo: " + "x" * 65532, "unsupported-line-size")
    source = IDENTITY + "".join("  " * i + f"level{i}:\n" for i in range(65))
    _failure(awk_programs, source, "unsupported-depth")
    for _label, awk in awk_programs:
        for framing in (b"6A\n", b"0\n", b"61extra\n", b"61\n\n"):
            result = _invoke(awk, framing, framed=True)
            assert (result.returncode, result.stdout) == (
                1,
                b"CFMGR-YAML-ERROR 1 invalid-hex END\n",
            )
        result = _invoke(awk, IDENTITY.encode(), budget=128)
        assert (result.returncode, result.stdout) == (
            1,
            b"CFMGR-YAML-ERROR 1 metadata-limit END\n",
        )
        result = _invoke(awk, IDENTITY.encode(), budget="01")
        assert result.stdout == b"CFMGR-YAML-ERROR 1 invalid-budget END\n"


def test_invalid_utf8_is_rejected_before_yaml_admission(awk_programs) -> None:
    # Distinct invalid byte structures, all inside otherwise harmless comments.
    for invalid in (
        b"\x80",  # orphan continuation
        b"\xc0\xaf",  # overlong two-byte form
        b"\xe0\x80\xaf",  # overlong three-byte form
        b"\xed\xa0\x80",  # surrogate
        b"\xf0\x80\x80\xaf",  # overlong four-byte form
        b"\xf4\x90\x80\x80",  # above Unicode maximum
        b"\xe2x\xa1",  # invalid continuation
        b"\xf5\x80\x80\x80",  # invalid initial byte
        b"\xe2\x82",  # truncated at EOF
    ):
        _failure(awk_programs, IDENTITY.encode() + b"# " + invalid, "invalid-utf8")
