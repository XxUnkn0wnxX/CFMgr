#!/usr/bin/env python3
"""Build or verify the deterministic trusted-local runtime package."""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.0"
SAFE = re.compile(r"[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*\Z")


def inventory(root: Path) -> list[Path]:
    files = [root / "cfmgr.sh", root / "catalog.txt"]
    modules = root / "modules"
    if modules.is_symlink() or not modules.is_dir():
        raise ValueError("Missing regular modules directory")
    objects = sorted(modules.rglob("*"))
    if len(objects) > 1024:
        raise ValueError("Package exceeds bounded object inventory")
    parents = {
        parent
        for item in objects
        if item.is_file() and item.name != ".DS_Store"
        for parent in item.parents
        if parent != root and root in parent.parents
    }
    for item in objects:
        if item.name == ".DS_Store":
            if item.is_symlink() or not item.is_file():
                raise ValueError(f"Nonregular package object: {item.relative_to(root)}")
            continue
        if item.is_dir() and item not in parents:
            raise ValueError("Unlisted empty package directory")
        relative = item.relative_to(root).as_posix()
        if not SAFE.fullmatch(relative) or any(
            part in {".", ".."} for part in item.relative_to(root).parts
        ):
            raise ValueError(f"Unsafe package path: {relative}")
        if item.is_symlink() or not (item.is_file() or item.is_dir()):
            raise ValueError(f"Nonregular package object: {relative}")
        if item.is_file():
            files.append(item)
    for item in files:
        if item.is_symlink() or not item.is_file():
            raise ValueError(f"Missing regular package file: {item.name}")
        if item.stat().st_mode & 0o7777 not in {0o644, 0o755}:
            raise ValueError(f"Unsupported package mode: {item.name}")
        if item.stat().st_size > 1048576:
            raise ValueError(f"Oversized package file: {item.name}")
    if len(files) > 512 or sum(item.stat().st_size for item in files) > 16777216:
        raise ValueError("Package exceeds bounded inventory")
    entry = (root / "cfmgr.sh").read_text()
    if (
        f"CFMGR_VERSION={VERSION}\n" not in entry
        or (root / "cfmgr.sh").stat().st_mode & 0o777 != 0o755
    ):
        raise ValueError("Entry version/mode mismatch")
    return sorted(files, key=lambda item: item.relative_to(root).as_posix())


def catalog(root: Path) -> bytes:
    lines = [f"CFMGR-CATALOG 1 {VERSION}"]
    modules = root / "modules"
    if modules.is_symlink() or not modules.is_dir():
        raise ValueError("Missing modules directory")
    for item in sorted(modules.rglob("*")):
        if item.is_symlink():
            raise ValueError("Symlink in package")
        if item.name == ".DS_Store":
            if not item.is_file():
                raise ValueError(f"Nonregular package object: {item.relative_to(root)}")
            continue
        if item.is_file():
            relative = item.relative_to(root).as_posix()
            kind = (
                "library"
                if "/lib/" in relative
                else "helper"
                if "/helpers/" in relative
                else "data"
            )
            lines.append(f"{relative}\t{kind}")
    return ("\n".join(lines) + "\n").encode()


def manifest(root: Path) -> bytes:
    lines = [f"CFMGR-MANIFEST 1 {VERSION}"]
    for item in inventory(root):
        content = item.read_bytes()
        lines.append(
            f"{item.stat().st_mode & 0o777:04o}\t{len(content)}\t{hashlib.sha256(content).hexdigest()}\t{item.relative_to(root).as_posix()}"
        )
    return ("\n".join(lines) + "\n").encode()


def ignore_finder_metadata(directory: str, names: list[str]) -> list[str]:
    """Omit regular Finder sidecars while leaving unsafe objects for validation."""
    ignored = []
    for name in names:
        if name != ".DS_Store":
            continue
        item = Path(directory) / name
        if item.is_file() and not item.is_symlink():
            ignored.append(name)
    return ignored


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--write",
        action="store_true",
        help="regenerate this repository's catalog and manifest",
    )
    group.add_argument(
        "--check",
        action="store_true",
        help="reject stale or invalid repository package metadata",
    )
    group.add_argument(
        "--output",
        type=Path,
        help="build a complete package in an absent/empty destination",
    )
    args = parser.parse_args()
    try:
        root = ROOT
        if args.output is not None:
            root = args.output.absolute()
            if root.exists() and (
                root.is_symlink() or not root.is_dir() or any(root.iterdir())
            ):
                raise ValueError("Output must be absent or an empty regular directory")
            # Validate source inventory before copying; never dereference symlinks.
            inventory(ROOT)
            root.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / "cfmgr.sh", root / "cfmgr.sh")
            shutil.copytree(
                ROOT / "modules",
                root / "modules",
                ignore=ignore_finder_metadata,
            )
        expected_catalog = catalog(root)
        if args.check:
            if (root / "catalog.txt").read_bytes() != expected_catalog or (
                root / "manifest.txt"
            ).read_bytes() != manifest(root):
                raise ValueError("Package metadata is stale or corrupt")
        else:
            (root / "catalog.txt").write_bytes(expected_catalog)
            os.chmod(root / "catalog.txt", 0o644)
            (root / "manifest.txt").write_bytes(manifest(root))
            os.chmod(root / "manifest.txt", 0o644)
    except (OSError, UnicodeError, ValueError) as error:
        parser.exit(1, f"Package rejected: {error}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
