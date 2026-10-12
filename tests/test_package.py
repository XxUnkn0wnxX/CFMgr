"""Acceptance tests for deterministic trusted-local package construction."""

from __future__ import annotations

import hashlib
import os
import sys
from pathlib import Path

import pytest

from tools import package as package_builder


def source_tree(root: Path) -> dict[str, tuple[bytes, int]]:
    files = {
        "cfmgr.sh": (b"#!/bin/sh\nCFMGR_VERSION=0.1.0\n", 0o755),
        "catalog.txt": (b"stale placeholder\n", 0o644),
        "modules/helpers/bootstrap.sh": (b"#!/bin/sh\n", 0o755),
        "modules/lib/config.sh": (b"config='passive'\n", 0o644),
        "modules/data/schema.json": (b"{}\n", 0o644),
    }
    for relative, (contents, mode) in files.items():
        target = root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(contents)
        target.chmod(mode)
    return files


def invoke(
    monkeypatch: pytest.MonkeyPatch,
    root: Path,
    *arguments: str,
) -> int:
    monkeypatch.setattr(package_builder, "ROOT", root)
    monkeypatch.setattr(sys, "argv", ["package.py", *arguments])
    return package_builder.main()


def expected_catalog() -> bytes:
    return (
        b"CFMGR-CATALOG 1 0.1.0\n"
        b"modules/data/schema.json\tdata\n"
        b"modules/helpers/bootstrap.sh\thelper\n"
        b"modules/lib/config.sh\tlibrary\n"
    )


def expected_manifest(files: dict[str, tuple[bytes, int]]) -> bytes:
    packaged = {**files, "catalog.txt": (expected_catalog(), 0o644)}
    lines = ["CFMGR-MANIFEST 1 0.1.0"]
    for relative in sorted(packaged):
        contents, mode = packaged[relative]
        lines.append(
            f"{mode:04o}\t{len(contents)}\t{hashlib.sha256(contents).hexdigest()}\t{relative}"
        )
    return ("\n".join(lines) + "\n").encode()


def test_output_is_complete_deterministic_and_exactly_hashed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    files = source_tree(source)
    destination = tmp_path / "built package"
    repeated = tmp_path / "repeated package"

    assert invoke(monkeypatch, source, "--output", str(destination)) == 0
    assert invoke(monkeypatch, source, "--output", str(repeated)) == 0

    assert (destination / "catalog.txt").read_bytes() == expected_catalog()
    assert (destination / "manifest.txt").read_bytes() == expected_manifest(files)
    for relative, (contents, mode) in files.items():
        target = destination / relative
        if relative != "catalog.txt":
            assert target.read_bytes() == contents
            assert target.stat().st_mode & 0o777 == mode
    assert sorted(
        path.relative_to(destination).as_posix()
        for path in destination.rglob("*")
        if path.is_file()
    ) == sorted([*files, "manifest.txt"])
    assert {
        path.relative_to(destination).as_posix(): path.read_bytes()
        for path in destination.rglob("*")
        if path.is_file()
    } == {
        path.relative_to(repeated).as_posix(): path.read_bytes()
        for path in repeated.rglob("*")
        if path.is_file()
    }


def test_finder_metadata_is_excluded_from_catalog_manifest_and_output(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    clean_source = tmp_path / "clean-source"
    source_tree(clean_source)
    metadata_source = tmp_path / "metadata-source"
    source_tree(metadata_source)
    sidecar = metadata_source / "modules/helpers/.DS_Store"
    sidecar.write_bytes(b"Finder metadata must not ship\n")
    clean_output = tmp_path / "clean-output"
    metadata_output = tmp_path / "metadata-output"

    assert invoke(monkeypatch, clean_source, "--output", str(clean_output)) == 0
    assert invoke(monkeypatch, metadata_source, "--output", str(metadata_output)) == 0

    def packaged_files(root: Path) -> dict[str, bytes]:
        return {
            item.relative_to(root).as_posix(): item.read_bytes()
            for item in root.rglob("*")
            if item.is_file()
        }

    output_files = packaged_files(metadata_output)
    assert output_files == packaged_files(clean_output)
    assert b".DS_Store" not in output_files["catalog.txt"]
    assert b".DS_Store" not in output_files["manifest.txt"]
    assert not any(path.endswith(".DS_Store") for path in output_files)


@pytest.mark.parametrize("unsafe_object", ["symlink", "nonregular"])
def test_finder_metadata_name_does_not_bypass_unsafe_object_rejection(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    unsafe_object: str,
) -> None:
    source = tmp_path / "source"
    source_tree(source)
    sidecar = source / "modules/lib/.DS_Store"
    if unsafe_object == "symlink":
        sidecar.symlink_to(tmp_path / "outside")
    else:
        os.mkfifo(sidecar)
    destination = tmp_path / "rejected-output"

    with pytest.raises(SystemExit) as rejected:
        invoke(monkeypatch, source, "--output", str(destination))

    assert rejected.value.code == 1
    assert not destination.exists()


def test_finder_only_directory_is_rejected_before_output_copy(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    source_tree(source)
    sidecar_directory = source / "modules/metadata-only"
    sidecar_directory.mkdir()
    (sidecar_directory / ".DS_Store").write_bytes(b"Finder metadata\n")
    destination = tmp_path / "rejected-output"

    with pytest.raises(SystemExit) as rejected:
        invoke(monkeypatch, source, "--output", str(destination))

    assert rejected.value.code == 1
    assert not destination.exists()


def test_check_rejects_stale_package_metadata(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    source_tree(source)
    assert invoke(monkeypatch, source, "--write") == 0
    assert invoke(monkeypatch, source, "--check") == 0

    (source / "manifest.txt").write_text("stale\n")
    with pytest.raises(SystemExit) as rejected:
        invoke(monkeypatch, source, "--check")
    assert rejected.value.code == 1


@pytest.mark.parametrize("unsafe_input", ["symlink", "nonregular", "mode", "path"])
def test_unsafe_source_is_rejected_before_output_copy(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    unsafe_input: str,
) -> None:
    source = tmp_path / "source"
    source_tree(source)
    if unsafe_input == "symlink":
        (source / "modules/lib/escape").symlink_to(tmp_path / "outside")
    elif unsafe_input == "nonregular":
        os.mkfifo(source / "modules/lib/pipe")
    elif unsafe_input == "mode":
        (source / "modules/lib/config.sh").chmod(0o600)
    else:
        (source / "modules/lib/unsafe\nname").write_text("unsafe\n")
    destination = tmp_path / "rejected-output"

    with pytest.raises(SystemExit) as rejected:
        invoke(monkeypatch, source, "--output", str(destination))

    assert rejected.value.code == 1
    assert not destination.exists()


def test_nonempty_output_is_refused_without_changing_existing_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    source_tree(source)
    destination = tmp_path / "existing-output"
    destination.mkdir()
    sentinel = destination / "keep.txt"
    sentinel.write_text("preserve exactly\n")

    with pytest.raises(SystemExit) as rejected:
        invoke(monkeypatch, source, "--output", str(destination))

    assert rejected.value.code == 1
    assert sentinel.read_text() == "preserve exactly\n"
    assert sorted(path.name for path in destination.iterdir()) == ["keep.txt"]
