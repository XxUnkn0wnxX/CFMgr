"""Real-tool supported archive verification; semantic callbacks are mandatory."""

from __future__ import annotations

import hashlib
import os
import shlex
import shutil
import subprocess
import sys

import pytest
from runtime_awk import awk_arguments
from test_archive_format import _rechecksum
from test_archive_io import ROOT, run
from test_archive_io import archive as io_archive
from test_archive_io import shell as io_shell

shell = io_shell
archive_io = io_archive
SET_ID = "12345678-1234-4abc-8abc-123456789abc"
ARCHIVE_ID = "abcdefab-1234-4abc-8abc-123456789abc"


@pytest.fixture
def archive(archive_io):
    support, ram, _mount, _stage, environment = archive_io
    for name in ("../backup.sh",):
        body = (ROOT / "modules/lib" / name).read_text()
        if sys.platform == "darwin" and name.endswith(".sh"):
            body = body.replace("/proc/self/fd/5", "${cfmgr_test_ram}").replace(
                "/proc/self/fd/7", "${cfmgr_test_backup}"
            )
        (support / "modules/lib" / name).write_text(body)
    # Record native tar admission: malformed headers must fail before this exec.
    trace = ram / "native-tar"
    tar = ram / "traced-tar"
    tar.write_text(
        f'#!/bin/sh\nprintf \'%s\\n\' "$*" >>{shlex.quote(str(trace))}\nexec {shlex.quote(environment["TEST_TAR"])} "$@"\n'
    )
    tar.chmod(0o700)
    environment["TEST_TAR_OVERRIDE"] = str(tar)
    return archive_io


def make_archive(
    archive, *, mutation="", manifest_change=None, write_raw=True, compact=False
):
    stage = archive[3]
    data = [
        b"config authority\n",
        b"catalog data\n",
        b"",
        bytes(range(256)) * 16,
        b"yaml snapshot\n" + b"x" * 498,
    ]
    roles = [
        "manager.config",
        "manager.catalog",
        "data.cloudflared.json",
        "history.cloudflared",
        "data.cloudflared.yaml",
    ]
    paths = [
        "addons/CFMgr.d/config",
        "addons/CFMgr.d/catalog.txt",
        "etc/cloudflared/profile.json",
        "var/log/cloudflared.log",
        "etc/cloudflared/config.yml",
    ]
    if compact:
        # Raw-header rejection and callback admission need only the two mandatory
        # members. Binary/empty/body traversal remains in the full positive case.
        data, roles, paths = data[:2], roles[:2], paths[:2]
    if mutation == "unsafe-path":
        paths[2] = "etc/cloudflared/../foreign.json"
    if mutation == "control-path":
        paths[2] = "etc/cloudflared/start.sh"
    rows = []
    for index, (body, role, path) in enumerate(zip(data, roles, paths), 1):
        digest = hashlib.sha256(body).hexdigest()
        if mutation == "hash" and index == 4:
            digest = "0" * 64
        rows.append(
            f"FILE p{index:08d} {role} {'jffs' if index <= 2 else 'entware'} {path.encode().hex()} 1 0600 {len(body)} {digest} {'prefix' if index == 4 else 'whole'}"
        )
        (stage / f"p{index:08d}").write_bytes(body)
    rows.append("NOTE data.cloudflared.certificate absent - optional END")
    if mutation == "long-line":
        rows.append(
            "NOTE history.cloudflared external " + (b"x" * 2100).hex() + " foreign END"
        )
    inventory = (
        "CFMGR-INVENTORY 1\n"
        + "\n".join(rows)
        + f"\nEND {len(data)} {len(rows) - len(data)} {sum(map(len, data))}\n"
    ).encode()
    manifest = (
        "CFMGR-ARCHIVE 1\n"
        f"SET {SET_ID}\nARCHIVE {ARCHIVE_ID}\n"
        "CREATED 1700000000 2024-02-29 23-59-59 55544330 +0000 DMY\n"
        "CONFIG 2 1\n"
        f"INVENTORY {len(rows)} {len(inventory)} {hashlib.sha256(inventory).hexdigest()} {len(data)} {sum(map(len, data))}\nEND\n"
    )
    if manifest_change:
        manifest = manifest_change(manifest)
    (stage / "manifest").write_text(manifest)
    (stage / "inventory").write_bytes(inventory)
    members = ["manifest", "inventory", *[f"p{i:08d}" for i in range(1, len(data) + 1)]]
    if mutation == "reordered":
        members[2:4] = members[3:1:-1]
    if mutation == "extra":
        (stage / "unexpected").write_bytes(b"foreign")
        members.append("unexpected")
    raw = stage / "candidate"
    if not write_raw:
        return raw, data
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        native = shutil.which(shlex.split(os.environ["CFMGR_TEST_SHELL"])[0])
        assert native
        command = [native, "tar", "-cf", str(raw), "-C", str(stage), *members]
    else:
        # Host adapter uses actual GNU old-GNU headers and exactly two zeros;
        # required CI uses the pinned vendor writer with no header rewriting.
        tar = shutil.which("gtar") or shutil.which("tar")
        assert tar
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
    subprocess.run(awk_arguments(command), check=True, capture_output=True, timeout=5)
    if mutation in ("link", "gnu-extension", "bad-checksum", "duplicate", "truncated"):
        content = bytearray(raw.read_bytes())
        if mutation == "link":
            content[156] = ord("2")
            content[:512] = _rechecksum(content[:512])
        elif mutation == "gnu-extension":
            content[156] = ord("L")
            content[:512] = _rechecksum(content[:512])
        elif mutation == "bad-checksum":
            content[148] ^= 1
        elif mutation == "duplicate":
            # Duplicate the first regular header/body; ordered-name gate rejects.
            first_size = len(manifest.encode())
            end = 512 + ((first_size + 511) // 512) * 512
            content[end:end] = content[:end]
        else:
            content = content[:-1]
        raw.write_bytes(content)
    return raw, data


CALLBACKS = r"""
cfmgr_archive_verify_payload() {
    [ -f "$9" ] || return 1
    case $1 in
    manager.config) IFS= read -r content <"$9"; [ "$content" = 'config authority' ] || return 1 ;;
    manager.catalog) IFS= read -r content <"$9"; [ "$content" = 'catalog data' ] || return 1 ;;
    esac
    printf '%s\n' "$1" >>"$ram/payload-callbacks"
    [ "${TEST_REJECT:-}" != payload ]
}
cfmgr_archive_verify_complete() {
    [ -f "$1" ] || return 1
    printf '%s\n' complete >>"$ram/complete-callback"
    [ "${TEST_REJECT:-}" != complete ]
}
"""


def verify(archive, shell, *, expected=SET_ID, callbacks=True):
    script = "cfmgr_archive_inventory_limit=65536\ncfmgr_archive_deadline=$((cfmgr_probe_now+60))\n"
    if callbacks:
        script += CALLBACKS
    else:
        # Consolidation defines the production callbacks in this same owner;
        # remove them explicitly to retain the missing-callback safety case.
        script += (
            "unset -f cfmgr_archive_verify_payload cfmgr_archive_verify_complete\n"
        )
    script += (
        'cfmgr_archive_format_verify "$stage/candidate" '
        + shlex.quote(expected)
        + '; code=$?; if [ "${TEST_CLEANUP:-0}" = 1 ]; then cfmgr_archive_format_cleanup || exit 91; fi; printf "code=%s verified=%s\\n" "$code" "$cfmgr_archive_verified"; exit "$code"'
    )
    return run(archive, shell, script, timeout=65)


def test_real_tool_end_to_end_binary_empty_boundary_and_callbacks(archive, shell):
    raw, _ = make_archive(archive)
    result = verify(archive, shell)
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"code=0 verified=1\n",
        b"",
    ), result
    assert (archive[1] / "payload-callbacks").read_text().splitlines() == [
        "manager.config",
        "manager.catalog",
        "data.cloudflared.json",
        "history.cloudflared",
        "data.cloudflared.yaml",
    ]
    calls = (archive[1] / "native-tar").read_text().splitlines()
    assert (
        len(calls) == 2 and calls[0].startswith("-tf ") and calls[1].startswith("-xOf ")
    )
    assert raw.exists()
    assert not list(archive[3].glob(".verify.*"))
    assert not list(archive[1].glob("archive-*.out"))
    assert not list(archive[1].glob("archive-*.err"))


@pytest.mark.parametrize(
    "mutation",
    [
        "link",
        "extra",
        "reordered",
        "duplicate",
        "truncated",
    ],
)
def test_raw_rejection_precedes_every_native_tar_call(archive, shell, mutation):
    make_archive(archive, mutation=mutation, compact=True)
    result = verify(archive, shell)
    assert result.returncode != 0 and b"verified=0" in result.stdout, result
    assert not (archive[1] / "native-tar").exists()
    assert not (archive[1] / "payload-callbacks").exists()


@pytest.mark.parametrize("mutation", ["hash", "unsafe-path"])
def test_inventory_and_hash_fail_closed(archive, shell, mutation):
    make_archive(archive, mutation=mutation)
    result = verify(archive, shell)
    assert result.returncode != 0 and b"verified=0" in result.stdout, result
    assert not (archive[1] / "complete-callback").exists()


@pytest.mark.parametrize("failure", ["missing", "payload", "complete", "wrong-set"])
def test_semantic_callbacks_and_expected_set_are_required(archive, shell, failure):
    make_archive(archive, compact=True)
    if failure in ("payload", "complete"):
        archive[4]["TEST_REJECT"] = failure
    if failure == "payload":
        archive[4]["TEST_CLEANUP"] = "1"
    result = verify(
        archive,
        shell,
        callbacks=failure != "missing",
        expected=ARCHIVE_ID if failure == "wrong-set" else SET_ID,
    )
    assert result.returncode != 0 and b"verified=0" in result.stdout, result
    if failure == "missing":
        assert not (archive[1] / "native-tar").exists()
    if failure == "payload":
        assert (archive[1] / "payload-callbacks").exists()
        assert not list(archive[3].glob(".verify.*"))
        assert (archive[3] / "candidate").exists()
    if failure == "complete":
        assert (archive[1] / "complete-callback").read_text() == "complete\n"


def metadata_parse(
    tmp_path, body, *, inventory=False, index="", expected=None, files=2, rows=None
):
    hexadecimal = tmp_path / "metadata.hex"
    hexadecimal.write_text("".join(f"{byte:02x}\n" for byte in body))
    environment = {
        **os.environ,
        "CFMGR_ARCHIVE_FORMAT_MODE": "inventory" if inventory else "manifest",
        "CFMGR_ARCHIVE_SET": SET_ID,
    }
    command = [
        shutil.which("awk") or "awk",
        "-f",
        "cfmgr-parser:backup_manifest",
    ]
    if inventory:
        idx = tmp_path / "index"
        idx.write_text(index)
        environment.update(
            CFMGR_ARCHIVE_INDEX=str(idx),
            CFMGR_ARCHIVE_FILES=str(files),
            CFMGR_ARCHIVE_ROWS=str(files if rows is None else rows),
            CFMGR_ARCHIVE_PAYLOAD_BYTES=expected or "0",
        )
        command += ["-f", "cfmgr-parser:backup_inventory"]
    return subprocess.run(
        awk_arguments([*command, str(hexadecimal)]),
        check=False,
        capture_output=True,
        env=environment,
        timeout=3,
    )


def test_manifest_and_inventory_decimal_math_never_rounds(tmp_path):
    manifest = f"CFMGR-ARCHIVE 1\nSET {SET_ID}\nARCHIVE {ARCHIVE_ID}\nCREATED 0 2024-02-29 00-00-00 55544330 +0000 YMD\nCONFIG 2 99999999999999999999\nINVENTORY 9007199254740993 123 {'a' * 64} 2 9223372036854775807\nEND\n".encode()
    parsed = metadata_parse(tmp_path, manifest)
    assert (
        parsed.returncode == 0
        and b"9007199254740993" in parsed.stdout
        and b"9223372036854775807" in parsed.stdout
    ), parsed
    sizes = [9007199254740992, 1]
    rows = [
        f"FILE p{i:08d} {role} jffs {path.encode().hex()} 1 0600 {size} {'0' * 64} whole"
        for i, role, path, size in zip(
            [1, 2],
            ["manager.config", "manager.catalog"],
            ["addons/CFMgr.d/config", "addons/CFMgr.d/catalog.txt"],
            sizes,
        )
    ]
    index = "manifest 1 512 0\ninventory 1 1536 1\np00000001 9007199254740992 2560 2\np00000002 1 9007199254743552 9007199254740994\n"
    correct = (
        "CFMGR-INVENTORY 1\n" + "\n".join(rows) + "\nEND 2 0 9007199254740993\n"
    ).encode()
    assert (
        metadata_parse(
            tmp_path, correct, inventory=True, index=index, expected="9007199254740993"
        ).returncode
        == 0
    )
    bad = correct.replace(b"END 2 0 9007199254740993", b"END 2 0 9007199254740992")
    assert (
        metadata_parse(
            tmp_path, bad, inventory=True, index=index, expected="9007199254740993"
        ).returncode
        != 0
    )


@pytest.mark.parametrize(
    "mutation",
    [
        "control-path",
        "long-line",
        "missing-lf",
        "bad-mode",
        "bad-date",
        "backslash",
        "unsafe-role",
    ],
)
def test_metadata_rejections_use_bounded_decoder_and_exact_grammar(
    archive, tmp_path, mutation
):
    make_archive(archive, write_raw=False)
    inventory = (archive[3] / "inventory").read_bytes()
    index = "manifest 1 512 0\ninventory 1 1536 1\n"
    for number, line in enumerate(inventory.decode().splitlines()[1:6], 1):
        fields = line.split(" ")
        index += f"p{number:08d} {fields[7]} 2560 2\n"
    arguments = {
        "inventory": True,
        "index": index,
        "expected": str(17 + 13 + 4096 + 512),
        "files": 5,
        "rows": 6,
    }
    valid = metadata_parse(tmp_path, inventory, **arguments)
    assert valid.returncode == 0, valid
    if mutation == "control-path":
        inventory = inventory.replace(
            b"etc/cloudflared/profile.json".hex().encode(),
            b"etc/cloudflared/start.sh".hex().encode(),
        )
    elif mutation == "long-line":
        inventory = inventory.replace(
            b"END 5 1 4638\n",
            b"NOTE history.cloudflared external "
            + (b"x" * 2100).hex().encode()
            + b" foreign END\nEND 5 2 4638\n",
        )
        arguments["rows"] = 7
    elif mutation == "missing-lf":
        inventory = inventory[:-1]
    elif mutation == "bad-mode":
        inventory = inventory.replace(b" 0600 ", b" 0700 ", 1)
    elif mutation == "backslash":
        inventory = inventory.replace(
            b"etc/cloudflared/profile.json".hex().encode(),
            b"etc/cloudflared/a\\b.json".hex().encode(),
        )
    elif mutation == "unsafe-role":
        inventory = inventory.replace(b"data.cloudflared.json", b"data.executable")
    if mutation == "bad-date":
        manifest = (
            (archive[3] / "manifest").read_bytes().replace(b"2024-02-29", b"2023-02-29")
        )
        result = metadata_parse(tmp_path, manifest)
    else:
        result = metadata_parse(tmp_path, inventory, **arguments)
    assert result.returncode != 0, result


def test_format_library_source_is_inert(shell, tmp_path):
    result = subprocess.run(
        awk_arguments(
            [
                *shell,
                "-c",
                '. "$1"; [ "$PWD" = "$2" ]',
                "format-source",
                str(ROOT / "modules/backup.sh"),
                str(tmp_path),
            ]
        ),
        cwd=tmp_path,
        check=False,
        capture_output=True,
        timeout=3,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_cleanup_refuses_substituted_owned_stage_file(archive, shell):
    passed = run(
        archive,
        shell,
        r"""
cfmgr_archive_write "$stage/owned" 4096 new original || exit $?
cfmgr_archive_format_record "$stage/owned" || exit $?
mv "$stage/owned" "$stage/old-owned"
printf foreign >"$stage/owned"
cfmgr_archive_format_cleanup && exit 81
[ -f "$stage/owned" ] && [ -f "$stage/old-owned" ]
""",
    )
    assert (passed.returncode, passed.stdout, passed.stderr) == (0, b"", b""), passed
    assert (archive[3] / "owned").read_bytes() == b"foreign"
