"""Real data capture; host source authority adapters are explicitly labelled."""

from __future__ import annotations

import hashlib
import os
import shlex
import sys

import pytest
from test_archive_io import ROOT, passed, run
from test_archive_io import archive as io_archive
from test_archive_io import shell as io_shell
from test_archive_payload import (
    ACCOUNT,
    SECRET,
    TUNNEL,
    advanced_config,
    make_plan,
    serialize,
)
from test_archive_payload_semantics import pem_document

pytest_plugins = ["test_config_observation"]
shell = io_shell
archive_io = io_archive


@pytest.fixture
def archive(archive_io):
    support, ram, _mount, _stage, _environment = archive_io
    source, jffs = ram.parent / "source", ram.parent / "jffs"
    source.mkdir()
    jffs.mkdir()
    names = ("../backup.sh", "config.sh")
    for name in names:
        body = (ROOT / "modules/lib" / name).read_text()
        if name == "../backup.sh" and os.geteuid() != 0:
            # Host-only source-owner admission adapter: real native metadata
            # and every content operation remain unchanged. This does not
            # establish router root ownership on a non-root workstation.
            body = body.replace(
                '[ "$cfmgr_capture_uid" = 0 ]',
                f'[ "$cfmgr_capture_uid" = {os.geteuid()} ]',
            )
        if sys.platform == "darwin" and name.endswith(".sh"):
            for fd, variable in ((3, "source"), (5, "ram"), (7, "backup"), (8, "jffs")):
                body = body.replace(
                    f"/proc/self/fd/{fd}", f"${{cfmgr_test_{variable}}}"
                )
            body = body.replace("cd ${cfmgr_test_ram}", 'cd "${cfmgr_test_ram}"')
        (support / "modules/lib" / name).write_text(body)
    if sys.platform == "darwin":
        # macOS does not provide Linux address-space enforcement. Actual
        # directory reads remain; the native child-only VM limit is CI proof.
        helper = support / "modules/helpers/worker.sh"
        helper.write_text(helper.read_text().replace('ulimit -v "$3" || exit 2', ":"))
        path = support / "modules/backup.sh"
        body = (
            path.read_text()
            .replace("/proc/self/fd/3", "${cfmgr_test_source}")
            .replace("/proc/self/fd/8", "${cfmgr_test_jffs}")
        )
        path.write_text(body)
    return archive_io


CAPTURE_SETUP = r"""
cfmgr_test_source=$1 cfmgr_test_jffs=$2
exec 3<"$cfmgr_test_source" 8<"$cfmgr_test_jffs"
cfmgr_archive_inventory_limit=65536 cfmgr_archive_directory_kib=65536
cfmgr_archive_deadline=$((cfmgr_probe_now+100))
cfmgr_archive_source_pinned=1
cfmgr_archive_source_root=$cfmgr_test_source cfmgr_store_jffs=$cfmgr_test_jffs
cfmgr_archive_source_attached() {
    [ -d "$cfmgr_test_source" ] || return 1
    if [ "$TEST_LINUX" = 1 ]; then
        [ "$cfmgr_test_source" -ef /proc/self/fd/3 ] && [ "$cfmgr_test_jffs" -ef /proc/self/fd/8 ]
    fi
}
# Resource-policy admission belongs to the controller. Tests exercise actual
# metadata/hash/copy/parser/write operations within their small owned tree.
cfmgr_archive_space_reserve() { cfmgr_archive_uint "$1"; }
cfmgr_archive_cloud_capture_mode() { cfmgr_archive_capture_mode=whole; }
cfmgr_archive_cloud_capture_revalidate() { return 0; }
"""


def capture_run(archive, shell, script, *, timeout=110):
    ram = archive[1]
    if sys.platform == "darwin":
        script = script.replace("/proc/self/fd/8", "${cfmgr_test_jffs}").replace(
            "/proc/self/fd/3", "${cfmgr_test_source}"
        )
    return run(
        archive,
        shell,
        CAPTURE_SETUP + script,
        ram.parent / "source",
        ram.parent / "jffs",
        timeout=timeout,
    )


def populate(
    archive, commands, schema2_config, *, bad_recovery=False, unowned_drafts=False
):
    ram = archive[1]
    source, jffs = ram.parent / "source", ram.parent / "jffs"
    config = advanced_config(schema2_config)
    drafts = serialize(
        {
            "schema": 1,
            "generation": 1,
            "drafts": {
                "ddns": None,
                "ip_sync": {
                    "schema": 1,
                    "stage": "input",
                    "inputs": {},
                    "validation": {},
                },
            },
        }
    )
    yaml = (
        f"# preserve this whole file, including unrelated settings\ntunnel: {TUNNEL}\ncredentials-file: /opt/etc/cloudflared/credentials.json\n"
        "origincert: /opt/etc/cloudflared/cert.pem\noriginRequest:\n  caPool: /opt/etc/cloudflared/ca.pem\n"
        "logfile: /opt/var/log/cloudflared.log\n# trailing content\n"
    ).encode()
    cert = pem_document(
        serialize(
            {
                "zoneID": "zone",
                "accountID": ACCOUNT,
                "apiToken": "private-capture-token",
            }
        ),
        legacy=False,
    )
    bodies = {
        "data.cloudflared.yaml": yaml,
        "data.cloudflared.json": serialize(
            {"AccountTag": ACCOUNT, "TunnelID": TUNNEL, "TunnelSecret": SECRET}
        ),
        "data.cloudflared.certificate": cert,
        "data.cloudflared.certificate-recovery": cert,
        "data.setup-drafts": drafts,
        "data.cloudflared.yaml-backup": b"full prior yaml\x00\xff\n",
        "data.cloudflared.input.ca_bundle": b"opaque CA input\x00\xff\n",
    }
    config["credentials"]["cert"]["sha256"] = hashlib.sha256(cert).hexdigest()
    owners = []
    for owner in config["ownership"]["components"]:
        role = owner["component"]
        if role in bodies:
            owner["sha256"] = hashlib.sha256(bodies[role]).hexdigest()
            if unowned_drafts and role == "data.setup-drafts":
                continue
        owners.append(owner)
    config["ownership"]["components"] = owners
    for owner in advanced_config(schema2_config)["ownership"]["components"]:
        role = owner["component"]
        if role not in bodies:
            continue
        root = source if owner["path"].startswith("/opt/") else jffs
        relative = owner["path"].split("/", 2)[2]
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(bodies[role])
    if bad_recovery:
        (jffs / "addons/CFMgr.d/cert.pem").write_bytes(b"stable damaged certificate\n")
    catalog = jffs / "addons/CFMgr.d/catalog.txt"
    catalog.write_bytes(b"exact catalog bytes\n")
    (source / "var/log").mkdir(parents=True)
    history = b"off feature retained history\x00\xff\n"
    (source / "var/log/cloudflared.log").write_bytes(history)
    (source / "var/log/cloudflared.log.1").write_bytes(b"rotation\x00\xff\n")
    snapshot = serialize(config)
    (ram / "config-snapshot").write_bytes(snapshot)
    (ram / "plan").write_bytes(make_plan(commands, ram, snapshot))
    (ram / "history").write_text(
        "CFMGR-HISTORY 1\n"
        f"FILE history.cloudflared {b'/opt/var/log/cloudflared.log'.hex()} 1 live END\n"
        f"FILE history.cloudflared {b'/opt/var/log/cloudflared.log.1'.hex()} 1 rotation END\n"
        "STATE ddns not_applicable no-owned-data END\nSTATE ip_sync not_applicable no-owned-data END\n"
        "STATE cloudflared included eligible-owned-history END\nEND\n"
    )
    return {
        **bodies,
        "manager.config": snapshot,
        "manager.catalog": catalog.read_bytes(),
        "history.cloudflared": history,
    }


def start_capture(archive, shell):
    return capture_run(
        archive,
        shell,
        r"""
cfmgr_history_ready=1 cfmgr_history_output=$ram/history cfmgr_history_lock_held=1
exec 4<"$ram/history"
cfmgr_archive_capture_data "$ram/plan" "$ram/config-snapshot"
""",
        # Preserve the full owned-data fixture on slower macOS process launches.
        # Native supervision and its existing 100s fixture deadline are unchanged.
        timeout=180 if sys.platform == "darwin" else 110,
    )


def test_populated_capture_preserves_full_bytes_and_off_history(
    archive, shell, commands, schema2_config
):
    expected = populate(archive, commands, schema2_config)
    result = start_capture(archive, shell)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b""), result
    stage = archive[3]
    lines = (stage / "inventory").read_text().splitlines()
    files = [line.split() for line in lines if line.startswith("FILE ")]
    for fields in files:
        role = fields[2]
        body = (stage / fields[1]).read_bytes()
        if role == "history.cloudflared" and bytes.fromhex(fields[4]).decode().endswith(
            ".1"
        ):
            assert body == b"rotation\x00\xff\n"
        else:
            assert body == expected[role]
        assert len(body) == int(fields[7])
        assert hashlib.sha256(body).hexdigest() == fields[8]
    roles = {fields[2] for fields in files}
    assert set(expected) <= roles
    assert "NOTE history.cloudflared included - eligible-owned-history END" in lines
    assert not list(stage.glob("capture-*"))
    assert not list(stage.glob("payload-*"))


@pytest.mark.parametrize(
    "failure", ["required-absent", "unowned-drafts", "symlink-ancestor"]
)
def test_capture_required_absence_and_foreign_data_fail_closed(
    archive, shell, commands, schema2_config, failure
):
    populate(
        archive, commands, schema2_config, unowned_drafts=failure == "unowned-drafts"
    )
    source = archive[1].parent / "source"
    if failure == "unowned-drafts":
        snapshot = schema2_config
        (archive[1] / "config-snapshot").write_bytes(snapshot)
        (archive[1] / "plan").write_bytes(make_plan(commands, archive[1], snapshot))
    if failure == "required-absent":
        (source / "etc/cloudflared/credentials.json").unlink()
    if failure == "symlink-ancestor":
        directory = source / "etc/cloudflared"
        directory.rename(source / "foreign")
        directory.symlink_to(source / "foreign", target_is_directory=True)
    before = {
        path: path.read_bytes()
        for path in (archive[1].parent / "jffs").rglob("*")
        if path.is_file()
    }
    result = start_capture(archive, shell)
    assert result.returncode != 0
    assert {path: path.read_bytes() for path in before} == before
    assert (archive[1].parent / "jffs/addons/CFMgr.d/setup-drafts").exists()


@pytest.mark.parametrize(
    "change",
    ["whole-mutate", "whole-short", "prefix-append", "prefix-mutate", "prefix-shrink"],
)
def test_snapshot_real_writer_changes_and_partial_ownership(archive, shell, change):
    ram, stage = archive[1], archive[3]
    source = ram.parent / "jffs/input"
    original = b"a" * 1024
    source.write_bytes(original)
    marker = ram / "dd-seen"
    tool = ram / "changing-dd"
    actual = archive[4]["TEST_DD"]
    operation = {
        "whole-mutate": f"printf b | dd of={shlex.quote(str(source))} bs=1 count=1 conv=notrunc 2>/dev/null",
        "whole-short": f"printf tiny >{shlex.quote(str(source))}",
        "prefix-append": f"printf appended >>{shlex.quote(str(source))}",
        "prefix-mutate": f"printf b | dd of={shlex.quote(str(source))} bs=1 count=1 conv=notrunc 2>/dev/null",
        "prefix-shrink": f"printf tiny >{shlex.quote(str(source))}",
    }[change]
    when = (
        f"[ -e {shlex.quote(str(marker))} ]"
        if change in {"prefix-mutate", "prefix-shrink"}
        else f"[ ! -e {shlex.quote(str(marker))} ]"
    )
    tool.write_text(
        f'#!/bin/sh\nif {when}; then {operation}; fi\n: >{shlex.quote(str(marker))}\nexec {shlex.quote(actual)} "$@"\n'
    )
    tool.chmod(0o700)
    archive[4]["TEST_DD"] = str(tool)
    kind = "prefix" if change.startswith("prefix") else "whole"
    script = f"""
cfmgr_archive_format_tracking=1
cfmgr_history_lock_held=1
exec 4<"$ram/dd-seen-lock"
cfmgr_capture_snapshot "/proc/self/fd/8/input" "$stage/snapshot" {kind}
code=$?
"""
    (ram / "dd-seen-lock").touch()
    if change == "prefix-append":
        script += '[ "$code:$cfmgr_capture_bytes" = 0:1024 ] || exit 80\n'
    else:
        script += '[ "$code" != 0 ] || exit 81\ncase " $cfmgr_format_owned " in *" snapshot:"*) ;; *) exit 82 ;; esac\ncfmgr_archive_format_cleanup || exit $?\n'
    passed(capture_run(archive, shell, script, timeout=20))
    if change == "prefix-append":
        assert (stage / "snapshot").read_bytes() == original
        assert source.read_bytes() == original + b"appended"
    else:
        assert not (stage / "snapshot").exists()


@pytest.mark.parametrize("damage", ["hash", "semantic"])
def test_optional_certificate_damage_requires_valid_other_copy(archive, shell, damage):
    ram = archive[1]
    cert = pem_document(
        serialize({"zoneID": "zone", "accountID": ACCOUNT, "apiToken": "private"}),
        legacy=False,
    )
    live, recovery = (
        ram.parent / "source/etc/cloudflared/cert.pem",
        ram.parent / "jffs/addons/CFMgr.d/cert.pem",
    )
    live.parent.mkdir(parents=True)
    recovery.parent.mkdir(parents=True)
    live.write_bytes(cert)
    malformed = b"stable malformed PEM\n"
    recovery.write_bytes(malformed)
    good_hash, bad_hash = (
        hashlib.sha256(cert).hexdigest(),
        hashlib.sha256(malformed).hexdigest(),
    )
    live_hex, recovery_hex = (
        b"etc/cloudflared/cert.pem".hex(),
        b"addons/CFMgr.d/cert.pem".hex(),
    )
    # Hash mismatch has a real valid live copy. Semantic rejection tests the
    # no-valid-copy failure using the same fixed real PEM parser.
    if damage == "semantic":
        live.unlink()
    (ram / "certificate-plan").write_text(
        "CFMGR-CAPTURE-PLAN 1 2 1\n"
        f"FILE data.cloudflared.certificate optional entware {live_hex} 1 {good_hash} whole\n"
        f"FILE data.cloudflared.certificate-recovery optional jffs {recovery_hex} 1 {good_hash if damage == 'hash' else bad_hash} whole\n"
        "END 3\n"
    )
    script = f"""
cfmgr_archive_format_tracking=1
cfmgr_payload_certificate_account={ACCOUNT.encode().hex()}
cfmgr_capture_start || exit $?
cfmgr_archive_capture_certificate data.cloudflared.certificate optional entware {live_hex} 1 {good_hash} || exit $?
cfmgr_archive_capture_certificate data.cloudflared.certificate-recovery optional jffs {recovery_hex} 1 {good_hash if damage == "hash" else bad_hash} || exit $?
for feature in ddns ip_sync cloudflared; do cfmgr_capture_note "history.$feature" not_applicable - no-owned-data || exit $?; done
cfmgr_capture_finish || exit $?
cfmgr_archive_run archive-payload-match 4096 "$TEST_AWK" "$support/modules/backup.sh" "$ram/certificate-plan" "/proc/self/fd/7/stage/inventory"
code=$?
"""
    script += '[ "$code" = 0 ]' if damage == "hash" else '[ "$code" != 0 ]'
    passed(capture_run(archive, shell, script, timeout=35))
    inventory = (archive[3] / "inventory").read_text()
    assert " damaged END" in inventory
    assert ("FILE p00000001 data.cloudflared.certificate " in inventory) == (
        damage == "hash"
    )
    assert not list(archive[3].glob("payload-*"))


@pytest.mark.parametrize("writer", ["unknown", "changed"])
def test_cloud_history_preflight_and_postcapture_writer_gate(archive, shell, writer):
    ram = archive[1]
    directory = ram.parent / "source/var/log"
    directory.mkdir(parents=True)
    for name in ("ddns.log", "cloudflared.log", "cloudflared.log.1"):
        (directory / name).write_bytes((name + "\n").encode())
    rows = ["CFMGR-HISTORY 1"]
    # Rotation deliberately precedes live: unknown must exclude both.
    for feature, name, kind in (
        ("cloudflared", "cloudflared.log.1", "rotation"),
        ("ddns", "ddns.log", "live"),
        ("cloudflared", "cloudflared.log", "live"),
    ):
        rows.append(
            f"FILE history.{feature} {('/opt/var/log/' + name).encode().hex()} 1 {kind} END"
        )
    rows += [
        "STATE ddns included eligible-owned-history END",
        "STATE ip_sync not_applicable no-owned-data END",
        "STATE cloudflared included eligible-owned-history END",
        "END",
    ]
    (ram / "history").write_text("\n".join(rows) + "\n")
    script = r"""
cfmgr_archive_format_tracking=1
cfmgr_history_ready=1 cfmgr_history_output=$ram/history cfmgr_history_lock_held=1
exec 4<"$ram/history"
cfmgr_capture_start || exit $?
"""
    if writer == "unknown":
        script += "cfmgr_archive_cloud_capture_mode() { return 4; }\ncfmgr_archive_capture_history && cfmgr_capture_finish"
    else:
        script += "cfmgr_archive_cloud_capture_revalidate() { return 1; }\ncfmgr_archive_capture_history && exit 81; exit 0"
    passed(capture_run(archive, shell, script, timeout=25))
    inventory = (archive[3] / "inventory").read_text()
    if writer == "unknown":
        assert "NOTE history.cloudflared unavailable - writer-unknown END" in inventory
        assert " history.cloudflared entware " not in inventory
        assert " history.ddns entware " in inventory
    else:
        assert "writer-unknown" not in inventory
        assert " history.cloudflared entware " in inventory


def test_absent_below_symlink_is_not_optional_absence(archive, shell):
    source = archive[1].parent / "source"
    (source / "foreign").mkdir()
    (source / "etc").symlink_to(source / "foreign", target_is_directory=True)
    hexpath = b"etc/cloudflared/missing.pem".hex()
    passed(
        capture_run(
            archive, shell, f'cfmgr_capture_source entware {hexpath}; [ "$?" = 1 ]'
        )
    )


def test_prefix_requires_rotation_lock_and_decoder_is_bounded(archive, shell):
    (archive[1].parent / "jffs/input").write_bytes(b"prefix")
    text = "".join(chr(value) for value in range(32, 127))
    script = f"""
cfmgr_capture_decode {text.encode().hex()} || exit $?
[ "$cfmgr_capture_relative" = {shlex.quote(text)} ] || exit 80
cfmgr_capture_decode 0a && exit 81
cfmgr_history_lock_held=0
cfmgr_capture_snapshot "/proc/self/fd/8/input" "$stage/snapshot" prefix && exit 82
[ ! -e "$stage/snapshot" ]
"""
    passed(capture_run(archive, shell, script))
