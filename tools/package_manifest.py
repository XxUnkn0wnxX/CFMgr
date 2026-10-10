#!/usr/bin/env python3
"""Inventory one immutable local Git commit; never install or execute its payload."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO

ROOT = Path(__file__).resolve().parents[1]
TIMEOUT = 30
MAX_FILES = 128
MAX_FILE_BYTES = 1_048_576
MAX_TOTAL_BYTES = 8_388_608
MAX_MANIFEST_BYTES = 65_536
COMMIT = re.compile(r"[0-9a-fA-F]{40}")
TREE_HEADER = re.compile(rb"([0-7]{6}) (blob|tree|commit) ([0-9a-f]{40}) +([0-9]+|-)")
COMPONENT = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]{0,99}")
DECLARATION = re.compile(rb"[ \t]*(?:(?:export|readonly)[ \t]+)?CFMGR_VERSION=")
VERSION = re.compile(rb"CFMGR_VERSION=((?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*))")


class ManifestError(Exception):
    """The selected package or its local acquisition/validation is invalid."""


@dataclass(frozen=True)
class _Entry:
    path: str
    oid: str
    size: int
    mode: str


def _environment() -> dict[str, str]:
    # The caller cannot redirect repository/object/config selection. Empty
    # GIT_ALLOW_PROTOCOL overrides even local per-protocol transport allowances.
    environment = {key: value for key, value in os.environ.items() if not key.startswith("GIT_")}
    environment.update(
        LC_ALL="C",
        GIT_CONFIG_NOSYSTEM="1",
        GIT_CONFIG_GLOBAL=os.devnull,
        GIT_NO_REPLACE_OBJECTS="1",
        GIT_NO_LAZY_FETCH="1",
        GIT_ALLOW_PROTOCOL="",
        GIT_OPTIONAL_LOCKS="0",
        GIT_TERMINAL_PROMPT="0",
    )
    return environment


def _run(
    command: list[str],
    environment: dict[str, str],
    data: bytes | None = None,
    *,
    stream: BinaryIO | None = None,
) -> bytes:
    try:
        result = subprocess.run(
            command,
            input=data,
            stdin=stream if stream is not None else (subprocess.DEVNULL if data is None else None),
            capture_output=True,
            env=environment,
            timeout=TIMEOUT,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ManifestError(f"local {command[0]} acquisition/validation failed") from error
    if result.returncode != 0 or result.stderr:
        raise ManifestError(f"local {command[0]} acquisition/validation failed")
    return result.stdout


def _destination(path: str, *, placeholder: bool = False) -> None:
    parts = path.split("/")
    if (
        not 1 <= len(path) <= 240
        or any(COMPONENT.fullmatch(part) is None for part in parts[:-1])
        or (not placeholder and COMPONENT.fullmatch(parts[-1]) is None)
        or (path != "cfmgr.sh" and not path.startswith("modules/"))
        or any(
            path == reserved or path.startswith(reserved + "/")
            for reserved in (
                "modules/config",
                "modules/catalog.txt",
            )
        )
    ):
        raise ManifestError("unsafe or reserved package destination")


def _inventory(raw: bytes) -> list[_Entry]:
    if not raw or not raw.endswith(b"\0"):
        raise ManifestError("missing or malformed Git tree inventory")
    entries = []
    seen: set[str] = set()
    destinations: set[str] = set()
    total = 0
    for record in raw[:-1].split(b"\0"):
        header, separator, raw_path = record.partition(b"\t")
        match = TREE_HEADER.fullmatch(header)
        if not separator or match is None:
            raise ManifestError("malformed Git tree record")
        try:
            path = raw_path.decode("ascii")
        except UnicodeDecodeError as error:
            raise ManifestError("non-ASCII package destination") from error
        mode, kind, oid, raw_size = match.groups()
        if path in seen:
            raise ManifestError("duplicate package destination")
        seen.add(path)
        if kind == b"tree" and mode == b"040000" and raw_size == b"-":
            # Include trees in the listing so unsafe or nonregular placeholders
            # cannot hide as empty directories; directories are not payloads.
            if path == "cfmgr.sh":
                raise ManifestError("the package entry must be a regular Git blob")
            if path != "modules":
                _destination(path)
            continue
        if kind != b"blob" or mode not in (b"100644", b"100755"):
            raise ManifestError("package destinations must be regular Git blobs")
        if re.fullmatch(rb"0|[1-9][0-9]*", raw_size) is None or len(raw_size) > 7:
            raise ManifestError("invalid package blob size")
        size = int(raw_size)
        placeholder = path.startswith("modules/") and path.rsplit("/", 1)[-1] == ".gitkeep"
        _destination(path, placeholder=placeholder)
        destinations.add(path)
        if placeholder:
            if mode != b"100644" or size != 0:
                raise ManifestError("package placeholders must be empty nonexecutable blobs")
            continue
        if not 1 <= size <= MAX_FILE_BYTES:
            raise ManifestError("package blob size exceeds the supported bounds")
        if path == "cfmgr.sh" and mode != b"100755":
            raise ManifestError("the package entry must be executable")
        total += size
        if len(entries) >= MAX_FILES or total > MAX_TOTAL_BYTES:
            raise ManifestError("package inventory exceeds the supported bounds")
        entries.append(_Entry(path, oid.decode("ascii"), size, "0" + mode.decode("ascii")[-3:]))
    if "cfmgr.sh" not in destinations:
        raise ManifestError("the package entry is missing")
    entries.sort(key=lambda entry: entry.path)
    for entry in entries:
        parts = entry.path.split("/")
        if any("/".join(parts[:end]) in destinations for end in range(1, len(parts))):
            raise ManifestError("conflicting package destinations")
    return entries


def _blobs(raw: bytes, entries: list[_Entry]) -> list[bytes]:
    blobs = []
    position = 0
    for entry in entries:
        header = f"{entry.oid} blob {entry.size}\n".encode("ascii")
        if not raw.startswith(header, position):
            raise ManifestError("Git blob batch metadata does not match the frozen inventory")
        position += len(header)
        end = position + entry.size
        if end >= len(raw) or raw[end : end + 1] != b"\n":
            raise ManifestError("truncated or malformed Git blob batch")
        blobs.append(raw[position:end])
        position = end + 1
    if position != len(raw):
        raise ManifestError("unexpected trailing Git blob batch data")
    return blobs


def _version(entry: bytes) -> str:
    # A metadata declaration convention, not shell interpretation. CR, quotes,
    # indentation, export/readonly and dynamic values are not literal metadata.
    candidates = [line for line in entry.split(b"\n") if DECLARATION.match(line)]
    if len(candidates) != 1:
        raise ManifestError("the entry must have exactly one literal version declaration")
    match = VERSION.fullmatch(candidates[0])
    if match is None or len(match[1]) > 128:
        raise ManifestError("the entry version declaration is not canonical literal metadata")
    return match[1].decode("ascii")


def _validate(
    document: bytes,
    version: str,
    entries: list[_Entry],
    hashes: list[str],
    environment: dict[str, str],
) -> None:
    # These are trusted developer-checkout parsers, never the selected commit's
    # source. Check their complete output, including status/framing/write result.
    try:
        # The production parser's contract requires independently immutable
        # regular stdin. This owned transient file is closed/deleted on exit.
        with tempfile.TemporaryFile() as stream:
            stream.write(document)
            stream.flush()
            if os.fstat(stream.fileno()).st_size != len(document):
                raise ManifestError("incomplete temporary manifest input")
            stream.seek(0)
            output = _run(
                [
                    "awk",
                    "-v",
                    f"cfmgr_manifest_size={len(document)}",
                    "-f",
                    str(ROOT / "modules/lib/package_path.awk"),
                    "-f",
                    str(ROOT / "modules/lib/manifest.awk"),
                ],
                environment,
                stream=stream,
            )
    except OSError as error:
        raise ManifestError("temporary manifest validation failed") from error
    body = f"manifest\t1\nversion\t{version}\nconfig-schema\t1\npackage-api\t1\n"
    body += "".join(
        f"file\t{entry.path}\t{entry.size}\t{digest}\t{entry.mode}\n"
        for entry, digest in zip(entries, hashes, strict=True)
    )
    encoded_body = body.encode("ascii")
    expected = encoded_body + (
        f"end\t{len(entries)}\t{sum(entry.size for entry in entries)}\t{len(encoded_body)}\n"
    ).encode("ascii")
    if len(output) > MAX_MANIFEST_BYTES or output != expected:
        raise ManifestError("trusted manifest parser returned an incomplete or mismatched ledger")


def generate_manifest(repository: Path, commit: str) -> bytes:
    """Return validated metadata for raw payload blobs at one full SHA-1 commit.

    repository is an existing directory within the intended repository (including
    bare repositories). This inventory establishes neither origin trust nor
    installed-file safety, and makes no repository or payload changes.
    """
    if COMMIT.fullmatch(commit) is None:
        raise ManifestError("commit must be a full 40-hex SHA-1 commit ID")
    commit = commit.lower()
    environment = _environment()
    try:
        resolved = repository.resolve()
    except (OSError, RuntimeError) as error:
        raise ManifestError("the repository directory cannot be resolved") from error
    git = ["git", "-C", str(resolved), "--no-replace-objects"]
    identity = _run([*git, "cat-file", "--batch-check"], environment, f"{commit}\n".encode("ascii"))
    if re.fullmatch(commit.encode("ascii") + rb" commit [0-9]+\n", identity) is None:
        raise ManifestError("the selected object is not the exact requested commit")
    entries = _inventory(
        _run(
            [
                *git,
                "ls-tree",
                "-r",
                "-t",
                "-l",
                "-z",
                "--full-tree",
                commit,
                "--",
                "cfmgr.sh",
                "modules",
            ],
            environment,
        )
    )
    request = "".join(f"{entry.oid}\n" for entry in entries).encode("ascii")
    blobs = _blobs(_run([*git, "cat-file", "--batch"], environment, request), entries)
    version = _version(blobs[0])  # ASCII ordering places the required cfmgr.sh first.
    hashes = [hashlib.sha256(blob).hexdigest() for blob in blobs]
    lines = ["manifest: 1", f"version: {version}", "config-schema: 1", "package-api: 1"]
    lines.extend(
        f"{entry.path}: {entry.size} {digest} {entry.mode}"
        for entry, digest in zip(entries, hashes, strict=True)
    )
    document = ("\n".join(lines) + "\n").encode("ascii")
    if len(document) > MAX_MANIFEST_BYTES:
        raise ManifestError("manifest exceeds the supported byte bound")
    _validate(document, version, entries, hashes, environment)
    return document


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo",
        type=Path,
        default=ROOT,
        help="existing directory within the intended local repository",
    )
    parser.add_argument("--commit", required=True, help="full 40-hex SHA-1 commit ID")
    args = parser.parse_args(argv)
    try:
        document = generate_manifest(args.repo, args.commit)
    except (ManifestError, OSError) as error:
        print(f"package manifest failed: {error}", file=sys.stderr)
        return 1
    try:
        if sys.stdout.buffer.write(document) != len(document):
            raise OSError("incomplete stdout manifest write")
        sys.stdout.buffer.flush()
    except OSError as error:
        print(f"package manifest output failed: {error}", file=sys.stderr)
        # Prevent Python's shutdown flush from retrying a failed buffered write
        # and replacing the promised exit status 1 with its own status 120.
        try:
            with open(os.devnull, "wb") as sink:
                os.dup2(sink.fileno(), sys.stdout.fileno())
        except (OSError, ValueError):
            pass
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
