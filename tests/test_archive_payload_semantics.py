"""PEM framing and semantic joins for native archive payload verification."""

from __future__ import annotations

import base64
import gzip
import hashlib
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from runtime_awk import awk_arguments
from test_archive_io import ROOT, run
from test_archive_io import archive as io_archive
from test_archive_io import shell as io_shell
from test_archive_payload import (
    ACCOUNT,
    SET_ID,
    TUNNEL,
    advanced_config,
    capture_rows,
    invoke_index,
    invoke_payload,
    make_plan,
    serialize,
    yaml_receipt,
)

pytest_plugins = ["test_config_observation"]

shell = io_shell
archive_io = io_archive


def pem_document(token: bytes, legacy: bool = True) -> bytes:
    blocks = []
    if legacy:
        blocks.extend(
            [
                b"-----BEGIN PRIVATE KEY-----\nYWJjZA==\n-----END PRIVATE KEY-----\n",
                b"-----BEGIN CERTIFICATE-----\nYWJjZA==\n-----END CERTIFICATE-----\n",
            ]
        )
    blocks.append(
        b"-----BEGIN ARGO TUNNEL TOKEN-----\n"
        + base64.b64encode(token)
        + b"\n-----END ARGO TUNNEL TOKEN-----\n"
    )
    return b"\n".join(blocks)


@pytest.mark.parametrize(
    "relative,accepted",
    [
        ("CFMgr/backup/profile.json", False),
        ("nested/CFMgr/diagnostics/report.json", False),
        ("CFMgr/profile.json", True),
        ("backup/profile.json", True),
    ],
)
def test_payload_plan_excludes_operational_tree_without_banning_managed_names(
    commands, schema2_config, tmp_path, relative, accepted
):
    value = advanced_config(schema2_config)
    owner = next(
        item
        for item in value["ownership"]["components"]
        if item["component"] == "data.cloudflared.input.ca_bundle"
    )
    owner["path"] = "/opt/etc/cloudflared/" + relative
    result = invoke_payload(commands, tmp_path, serialize(value), "plan")
    assert result.stderr == b""
    assert result.returncode == (0 if accepted else 1), result.stdout
    if accepted:
        assert owner["path"].encode().hex().encode() in result.stdout
    else:
        assert result.stdout == b""


def test_draft_review_reports_only_feature_stage_after_same_strict_validation(
    commands, tmp_path
):
    document = serialize(
        {
            "schema": 1,
            "generation": 7,
            "drafts": {
                "ddns": {
                    "schema": 1,
                    "stage": "secret-stage-identifier",
                    "inputs": {"token": "secret-draft-token"},
                    "validation": {"private": "secret-validation-value"},
                },
                "ip_sync": None,
            },
        }
    )
    environment = {"CFMGR_PAYLOAD_GENERATION": "7"}
    ordinary = invoke_payload(commands, tmp_path, document, "drafts", environment)
    assert (ordinary.returncode, ordinary.stdout, ordinary.stderr) == (
        0,
        b"CFMGR-PAYLOAD 1 drafts inert END\n",
        b"",
    )
    review = invoke_payload(commands, tmp_path, document, "drafts-review", environment)
    assert (review.returncode, review.stdout, review.stderr) == (
        0,
        b"CFMGR-DRAFT 1 ddns incomplete END\nCFMGR-PAYLOAD 1 drafts inert END\n",
        b"",
    )
    rejected = invoke_payload(
        commands, tmp_path, document, "drafts-review", {"CFMGR_PAYLOAD_GENERATION": "8"}
    )
    assert rejected.returncode == 1 and not rejected.stdout


def invoke_pem(commands, tmp_path, body: bytes):
    source = tmp_path / "pem.hex"
    source.write_text("".join(f"{byte:02x}\n" for byte in body))
    return subprocess.run(
        awk_arguments([*commands[1], "-f", "cfmgr-parser:backup_pem", str(source)]),
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=5,
    )


def test_pem_framing_decodes_original_token_and_rejects_bad_blocks(commands, tmp_path):
    token = b'{"zoneID":"zone","accountID":"Account literal","apiToken":"opaque"}\n'
    result = invoke_pem(commands, tmp_path, pem_document(token))
    assert (result.returncode, result.stderr) == (0, b"")
    fields = result.stdout.decode().strip().split(" ")
    assert fields[:2] == ["CFMGR-PEM", "1"] and fields[-1] == "END"
    decoded = subprocess.run(
        awk_arguments([shutil.which("openssl") or "openssl", "base64", "-d", "-A"]),
        input=fields[2].encode(),
        capture_output=True,
        check=True,
        timeout=5,
    )
    assert decoded.stdout == token
    assert b"opaque" not in result.stdout
    valid = pem_document(token)
    malformed = [
        valid + b"-----BEGIN UNKNOWN-----\nYWJj\n-----END UNKNOWN-----\n",
        valid
        + b"-----BEGIN ARGO TUNNEL TOKEN-----\nYWJj\n-----END ARGO TUNNEL TOKEN-----\n",
        valid.replace(b"END ARGO TUNNEL TOKEN", b"END CERTIFICATE"),
        valid.replace(b"YWJjZA==", b"YWJjZA="),
        valid + b"\x00",
        valid.replace(b"-----END ARGO TUNNEL TOKEN-----", b"-----END ARGO TUNNEL TOKE"),
    ]
    for body in malformed:
        refused = invoke_pem(commands, tmp_path, body)
        assert (refused.returncode, refused.stdout) == (1, b""), body[:80]


def _match(tmp_path: Path, plan: bytes, inventory: bytes):
    plan_path, inventory_path = tmp_path / "capture", tmp_path / "inventory"
    plan_path.write_bytes(plan)
    inventory_path.write_bytes(inventory)
    return subprocess.run(
        awk_arguments(
            [
                shutil.which("awk") or "awk",
                "-f",
                "cfmgr-parser:backup_payload_match",
                str(plan_path),
                str(inventory_path),
            ]
        ),
        env={**os.environ, "LC_ALL": "C"},
        capture_output=True,
        check=False,
        timeout=5,
    )


def _inventory_for(plan: bytes, *, extra=False) -> bytes:
    rows, files, total = [], 0, 0
    for row in plan.decode().splitlines()[1:-1]:
        fields = row.split()
        if fields[0] == "FILE":
            _, role, _required, scope, pathhex, generation, expected, _capture = fields
            body = (role + "\n").encode()
            digest = expected if expected != "-" else hashlib.sha256(body).hexdigest()
            files += 1
            total += len(body)
            rows.append(
                f"FILE p{files:08d} {role} {scope} {pathhex} {generation} 0600 {len(body)} {digest} whole"
            )
        elif fields[0] == "NOTE":
            rows.append(row)
        elif fields[0] == "EXTERNAL":
            _, role, pathhex, reason = fields
            rows.append(f"NOTE {role} external {pathhex} {reason} END")
        elif fields[0] == "HISTORY":
            _, role, _pathhex, _generation = fields
            rows.append(f"NOTE {role} unavailable - no-source END")
    for role in ("history.ddns", "history.ip_sync", "history.cloudflared"):
        if not any(row.startswith(f"NOTE {role} ") for row in rows):
            rows.append(f"NOTE {role} not_applicable - no-owned-data END")
    if extra:
        rows.append(
            f"FILE p{files + 1:08d} foreign jffs {b'foreign'.hex()} 1 0600 1 {'0' * 64} whole"
        )
        files += 1
    return (
        "CFMGR-INVENTORY 1\n"
        + "\n".join(rows)
        + f"\nEND {files} {len(rows) - files} {total}\n"
    ).encode()


def test_semantic_join_accepts_exact_capture_and_refuses_unplanned_file(
    commands, schema2_config, tmp_path
):
    plan = make_plan(commands, tmp_path, serialize(advanced_config(schema2_config)))
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
    capture = invoke_index(commands, tmp_path, plan, yaml)
    capture_rows(capture)
    inventory = _inventory_for(capture.stdout)
    result = _match(tmp_path, capture.stdout, inventory)
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-PAYLOAD-MATCH 1 complete END\n",
        b"",
    )
    refused = _match(
        tmp_path, capture.stdout, _inventory_for(capture.stdout, extra=True)
    )
    assert (refused.returncode, refused.stdout) == (1, b"")


@pytest.fixture
def archive(archive_io):
    support, ram, mount, _stage, _environment = archive_io
    names = ("../backup.sh", "config.sh")
    for name in names:
        body = (ROOT / "modules/lib" / name).read_text()
        if sys.platform == "darwin" and name.endswith(".sh"):
            body = body.replace("/proc/self/fd/5", str(ram)).replace(
                "/proc/self/fd/7", str(mount / "CFMgr/backup")
            )
        (support / "modules/lib" / name).write_text(body)
    return archive_io


def test_real_archive_verifier_runs_payload_callbacks_with_native_tools(
    archive, shell, schema2_config
):
    _support, _ram, mount, stage, _environment = archive
    config = advanced_config(schema2_config)
    config["ownership"]["components"] = [
        row
        for row in config["ownership"]["components"]
        if row["component"]
        in {
            "data.cloudflared.yaml",
            "data.cloudflared.json",
            "data.cloudflared.certificate",
            "data.cloudflared.certificate-recovery",
        }
    ]
    certificate = pem_document(
        serialize(
            {
                "zoneID": "zone",
                "accountID": ACCOUNT,
                "apiToken": "private-api-token",
            }
        ),
        legacy=False,
    )
    certificate_hash = hashlib.sha256(certificate).hexdigest()
    config["credentials"]["cert"]["sha256"] = certificate_hash
    for owner in config["ownership"]["components"]:
        if owner["component"].startswith("data.cloudflared.certificate"):
            owner["sha256"] = certificate_hash
    bodies = [
        serialize(config),
        b"catalog\n",
        f"tunnel: {TUNNEL}\ncredentials-file: /opt/etc/cloudflared/credentials.json\n".encode(),
        serialize(
            {
                "AccountTag": ACCOUNT,
                "TunnelID": TUNNEL,
                "TunnelSecret": "fixture-private-value",
            }
        ),
        certificate,
    ]
    roles = [
        "manager.config",
        "manager.catalog",
        "data.cloudflared.yaml",
        "data.cloudflared.json",
        "data.cloudflared.certificate",
    ]
    paths = [
        "addons/CFMgr.d/config",
        "addons/CFMgr.d/catalog.txt",
        "etc/cloudflared/config.yml",
        "etc/cloudflared/credentials.json",
        "etc/cloudflared/cert.pem",
    ]
    rows = []
    for index, (body, role, path) in enumerate(zip(bodies, roles, paths), 1):
        rows.append(
            f"FILE p{index:08d} {role} {'jffs' if index <= 2 else 'entware'} {path.encode().hex()} 1 0600 {len(body)} {hashlib.sha256(body).hexdigest()} whole"
        )
        (stage / f"p{index:08d}").write_bytes(body)
    rows += [
        f"NOTE data.cloudflared.certificate-recovery absent {b'addons/CFMgr.d/cert.pem'.hex()} absent END",
        "NOTE data.setup-drafts not_applicable - no-owned-data END",
        "NOTE data.cloudflared.yaml-backup not_applicable - no-owned-data END",
        "NOTE history.ddns not_applicable - no-owned-data END",
        "NOTE history.ip_sync not_applicable - no-owned-data END",
        "NOTE history.cloudflared not_applicable - no-owned-data END",
    ]
    inventory = (
        "CFMGR-INVENTORY 1\n"
        + "\n".join(rows)
        + f"\nEND {len(bodies)} {len(rows) - len(bodies)} {sum(map(len, bodies))}\n"
    ).encode()
    manifest = (
        "CFMGR-ARCHIVE 1\n"
        f"SET {SET_ID}\nARCHIVE abcdefab-1234-4abc-8abc-123456789abc\n"
        "CREATED 1700000000 2024-02-29 23-59-59 55544330 +0000 YMD\n"
        "CONFIG 2 1\n"
        f"INVENTORY {len(rows)} {len(inventory)} {hashlib.sha256(inventory).hexdigest()} {len(bodies)} {sum(map(len, bodies))}\nEND\n"
    ).encode()
    (stage / "manifest").write_bytes(manifest)
    (stage / "inventory").write_bytes(inventory)
    raw = stage / "candidate"
    tar = shutil.which("gtar") or shutil.which("tar")
    members = ["manifest", "inventory", *[f"p{i:08d}" for i in range(1, 6)]]
    command = [
        tar,
        "--format=gnu",
        "--blocking-factor=1",
        "-cf",
        str(raw),
        "-C",
        str(stage),
        *members,
    ]
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        native = shutil.which(os.environ["CFMGR_TEST_SHELL"].split()[0])
        command = [native, "tar", "-cf", str(raw), "-C", str(stage), *members]
    subprocess.run(awk_arguments(command), check=True, capture_output=True, timeout=5)
    selected = mount / "CFMgr/backup/CFbackup-2024-02-29.tar.gz"
    selected.write_bytes(gzip.compress(raw.read_bytes(), mtime=0))
    selected_digest = hashlib.sha256(selected.read_bytes()).hexdigest()
    selected_size = selected.stat().st_size
    sibling = mount / "CFMgr/backup/foreign.tar.gz"
    sibling.write_bytes(b"preserve unrelated data\n")
    script = """
cfmgr_archive_inventory_limit=65536
cfmgr_archive_deadline=$((cfmgr_probe_now+600))
cfmgr_format_owned='' cfmgr_format_receipts='' cfmgr_payload_ram_owned=''
# Space is explicit host fixture data; separate space-policy tests retain real
# admission/overflow proof. This consumer still performs real native copies,
# gzip, tar, hash, semantic callbacks and the single supervised unlink.
cfmgr_archive_space() { cfmgr_archive_free=1073741824; }
cfmgr_browser_name=CFbackup-2024-02-29.tar.gz cfmgr_browser_operation=delete
cfmgr_browser_expected_inode=$1 cfmgr_browser_expected_bytes=$2 cfmgr_browser_expected_sha=$3
# A foreign saved local set must not constrain an explicitly selected source.
cfmgr_archive_saved_set_id=12345678-1234-4abc-8abc-123456789abc
    if ! cfmgr_archive_browser_selected; then
        printf 'failed mode=%s exit=%s status=%s reason=%s probe=%s now=%s deadline=%s\\n' \
            "$cfmgr_probe_mode" "$cfmgr_probe_exit" "$cfmgr_probe_status" \
            "$cfmgr_probe_reason" "$cfmgr_probe_serial" "$cfmgr_probe_now" "$cfmgr_archive_deadline"
        exit 1
    fi
    [ "$cfmgr_browser_result:$cfmgr_browser_deleted:$cfmgr_browser_count" = deleted:1:1 ] || exit 2
    [ "$cfmgr_browser_set" = 01234567-89ab-cdef-0123-456789abcdef ] || exit 3
    [ -f "$stage/candidate" ] && [ ! -e "$mount/CFMgr/backup/$cfmgr_browser_name" ] || exit 4
printf 'verified=%s callbacks=%s\\n' "$cfmgr_archive_verified" "$cfmgr_payload_schema"
printf '%s\\n' "$cfmgr_browser_effects"
"""
    # Exercise the complete positive journey under production create's 600s
    # deadline. The stripped vendor ash forks for test/printf; its previous
    # arbitrary 60s fixture budget expired after 281 supervised operations.
    # The complete native case measured 79.45s; a 120s outer guard catches hangs.
    # Dedicated I/O cases retain
    # the short deadline, cancellation and ownership/reaping assertions.
    result = run(
        archive,
        shell,
        script,
        selected.stat().st_ino,
        selected_size,
        selected_digest,
        timeout=90 if sys.platform == "darwin" else 150,
    )
    assert result.returncode == 0, (
        result.stdout.decode(),
        result.stderr.decode()[-1800:],
    )
    assert result.stdout.startswith(b"verified=1 callbacks=2\n")
    assert b"CFMGR-ARCHIVE-EFFECT 1 STATE cloudflared 1 0 END\n" in result.stdout
    assert b"CFMGR-ARCHIVE-EFFECT 1 CLOUD advanced 1 0 1 1 END\n" in result.stdout
    assert b"CFMGR-ARCHIVE-EFFECT 1 SCHEMA 2 current END\n" in result.stdout
    assert sibling.read_bytes() == b"preserve unrelated data\n"
    assert not selected.exists()
    assert (stage / "p00000001").read_bytes() == serialize(config)
    assert (
        b"private-api-token" not in result.stdout
        and b"fixture-private-value" not in result.stdout
    )
    assert b"private-api-token".hex().encode() not in result.stdout
    assert b"fixture-private-value".hex().encode() not in result.stdout
    assert b"AUTH" not in result.stdout
