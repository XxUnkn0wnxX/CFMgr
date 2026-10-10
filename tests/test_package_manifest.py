"""Deterministic developer inventory from immutable Git package snapshots."""

from __future__ import annotations

import hashlib
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

from tools.package_manifest import ManifestError, _version, generate_manifest, main

ROOT = Path(__file__).resolve().parents[1]
GIT = shutil.which("git")
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V32", evidence="host")]


def git(repository: Path, *args: str, env: dict[str, str] | None = None) -> str:
    """Run fixture Git with user config, hooks and network-independent identity disabled."""
    assert GIT is not None
    child_env = {
        "PATH": os.environ.get("PATH", ""),
        "HOME": str(repository.parent),
        "LC_ALL": "C",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_TERMINAL_PROMPT": "0",
        "GIT_AUTHOR_NAME": "CFMgr test",
        "GIT_AUTHOR_EMAIL": "cfmgr-test@example.invalid",
        "GIT_COMMITTER_NAME": "CFMgr test",
        "GIT_COMMITTER_EMAIL": "cfmgr-test@example.invalid",
    }
    if env:
        child_env.update(env)
    result = subprocess.run(
        [GIT, *args],
        cwd=repository,
        env=child_env,
        capture_output=True,
        check=False,
        timeout=10,
    )
    assert result.returncode == 0, result.stderr.decode("utf-8", "replace")
    return result.stdout.decode("ascii").strip()


def write_package(repository: Path, *, version: str, payloads: dict[str, bytes]) -> None:
    entry = f"#!/bin/sh\nCFMGR_VERSION={version}\nexit 0\n".encode("ascii")
    (repository / "cfmgr.sh").write_bytes(entry)
    (repository / "cfmgr.sh").chmod(0o755)
    for relative, payload in payloads.items():
        path = repository / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)


def commit_all(repository: Path, message: str) -> str:
    git(repository, "add", "--all")
    git(repository, "-c", "core.hooksPath=/dev/null", "commit", "--quiet", "-m", message)
    return git(repository, "rev-parse", "HEAD")


def new_repository(path: Path) -> Path:
    path.mkdir()
    git(path, "init", "--quiet", "--initial-branch=main")
    return path


def literal_manifest(version: str, files: tuple[tuple[str, bytes, int], ...]) -> bytes:
    """Independent byte/hash/order oracle for the public manifest format."""
    body = f"manifest: 1\nversion: {version}\nconfig-schema: 1\npackage-api: 1\n"
    rows = []
    for destination, data, mode in files:
        rows.append(f"{destination}: {len(data)} {hashlib.sha256(data).hexdigest()} {mode:04o}\n")
    body += "".join(sorted(rows, key=lambda row: row.split(":", 1)[0].encode("ascii")))
    return body.encode("ascii")


def test_manifest_is_independent_raw_byte_hash_mode_and_ascii_order_oracle(
    tmp_path: Path,
) -> None:
    repository = new_repository(tmp_path / "repo")
    entry = b"#!/bin/sh\nCFMGR_VERSION=12.34.56\nexit 0\n"
    nested = b"\x00nested\xff\n"
    executable = b"#!/bin/sh\n"
    write_package(
        repository,
        version="12.34.56",
        payloads={
            "modules/z-last.dat": b"z\n",
            "modules/helpers/deep/exec.sh": executable,
            "modules/a-first.dat": nested,
            "modules/ignored/.gitkeep": b"",
        },
    )
    (repository / "modules/helpers/deep/exec.sh").chmod(0o755)
    (repository / "README.md").write_text("outside package\n", encoding="ascii")
    commit = commit_all(repository, "first package")

    expected_files = (
        ("cfmgr.sh", entry, 0o755),
        ("modules/a-first.dat", nested, 0o644),
        ("modules/helpers/deep/exec.sh", executable, 0o755),
        ("modules/z-last.dat", b"z\n", 0o644),
    )
    assert generate_manifest(repository, commit) == literal_manifest("12.34.56", expected_files)


def test_selected_snapshot_ignores_dirty_files_and_later_ref_movement(tmp_path: Path) -> None:
    repository = new_repository(tmp_path / "repo")
    write_package(repository, version="1.2.3", payloads={"modules/data.bin": b"committed"})
    first = commit_all(repository, "first")
    expected_first = literal_manifest(
        "1.2.3",
        (
            ("cfmgr.sh", b"#!/bin/sh\nCFMGR_VERSION=1.2.3\nexit 0\n", 0o755),
            ("modules/data.bin", b"committed", 0o644),
        ),
    )

    (repository / "modules/data.bin").write_bytes(b"dirty working tree")
    assert generate_manifest(repository, first) == expected_first
    # A directory inside the repository must still select the complete commit tree.
    assert generate_manifest(repository / "modules", first) == expected_first

    write_package(repository, version="9.8.7", payloads={"modules/data.bin": b"later ref"})
    second = commit_all(repository, "second")
    assert second != first
    assert generate_manifest(repository, first) == expected_first
    assert generate_manifest(repository, second) == literal_manifest(
        "9.8.7",
        (
            ("cfmgr.sh", b"#!/bin/sh\nCFMGR_VERSION=9.8.7\nexit 0\n", 0o755),
            ("modules/data.bin", b"later ref", 0o644),
        ),
    )


def test_git_replacement_and_inherited_repository_redirects_cannot_change_snapshot(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    repository = new_repository(tmp_path / "repo")
    write_package(repository, version="2.3.4", payloads={"modules/value": b"original"})
    original = commit_all(repository, "original")
    expected = literal_manifest(
        "2.3.4",
        (
            ("cfmgr.sh", b"#!/bin/sh\nCFMGR_VERSION=2.3.4\nexit 0\n", 0o755),
            ("modules/value", b"original", 0o644),
        ),
    )

    write_package(repository, version="8.7.6", payloads={"modules/value": b"replacement"})
    replacement_commit = commit_all(repository, "replacement")
    git(repository, "replace", original, replacement_commit)

    # These ambient variables would otherwise make Git inspect an unrelated repo or object DB.
    other = new_repository(tmp_path / "other")
    write_package(other, version="0.0.1", payloads={"modules/value": b"wrong repo"})
    commit_all(other, "unrelated")
    hostile = {
        "GIT_DIR": str(other / ".git"),
        "GIT_WORK_TREE": str(other),
        "GIT_OBJECT_DIRECTORY": str(other / ".git/objects"),
        "GIT_ALTERNATE_OBJECT_DIRECTORIES": str(other / ".git/objects"),
        "GIT_CONFIG_COUNT": "1",
        "GIT_CONFIG_KEY_0": "core.replaceRefs",
        "GIT_CONFIG_VALUE_0": "refs/replace/",
    }
    # Verify the actual subprocess boundary also neutralizes inherited Git controls.
    import tools.package_manifest as package_manifest

    observed: list[dict[str, str]] = []
    regular_parser_input: list[bool] = []
    real_run = subprocess.run

    def recording_run(*args: object, **kwargs: object) -> subprocess.CompletedProcess[bytes]:
        child_env = kwargs.get("env")
        if isinstance(child_env, dict):
            observed.append(child_env.copy())
        command = args[0] if args else None
        if isinstance(command, list) and command and command[0] == "awk":
            stream = kwargs.get("stdin")
            regular_parser_input.append(
                hasattr(stream, "fileno") and stat.S_ISREG(os.fstat(stream.fileno()).st_mode)  # type: ignore[union-attr]
            )
        return real_run(*args, **kwargs)  # type: ignore[arg-type]

    for key, value in hostile.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(package_manifest.subprocess, "run", recording_run)
    assert generate_manifest(repository, original) == expected

    assert observed
    git_env = observed[0]
    assert git_env.get("GIT_NO_REPLACE_OBJECTS") == "1"
    assert git_env.get("GIT_NO_LAZY_FETCH") == "1"
    assert git_env.get("GIT_ALLOW_PROTOCOL") == ""
    assert git_env.get("GIT_CONFIG_NOSYSTEM") == "1"
    assert git_env.get("GIT_CONFIG_GLOBAL") == os.devnull
    assert "GIT_DIR" not in git_env
    assert "GIT_WORK_TREE" not in git_env
    assert "GIT_OBJECT_DIRECTORY" not in git_env
    assert "GIT_ALTERNATE_OBJECT_DIRECTORIES" not in git_env
    assert "GIT_CONFIG_COUNT" not in git_env
    assert "GIT_CONFIG_KEY_0" not in git_env
    assert "GIT_CONFIG_VALUE_0" not in git_env
    assert regular_parser_input == [True]


def test_version_is_read_as_data_and_must_be_one_literal_full_line(tmp_path: Path) -> None:
    repository = new_repository(tmp_path / "repo")
    marker = tmp_path / "executed"
    entry = (
        "#!/bin/sh\n"
        "# CFMGR_VERSION=99.99.99 is only a comment\n"
        "CFMGR_VERSION=3.4.5\n"
        f"touch {marker}\n"
        "exit 0\n"
    ).encode("ascii")
    (repository / "cfmgr.sh").write_bytes(entry)
    (repository / "cfmgr.sh").chmod(0o755)
    (repository / "modules").mkdir()
    (repository / "modules/file").write_bytes(b"payload")
    good = commit_all(repository, "literal version")
    assert generate_manifest(repository, good) == literal_manifest(
        "3.4.5",
        (
            ("cfmgr.sh", entry, 0o755),
            ("modules/file", b"payload", 0o644),
        ),
    )
    assert not marker.exists()

    bad_entries = (
        b"#!/bin/sh\n# CFMGR_VERSION=3.4.5 is only a comment\n",
        b"#!/bin/sh\nCFMGR_VERSION=3.4.5\nCFMGR_VERSION=3.4.5\n",
        b"#!/bin/sh\nexport CFMGR_VERSION=3.4.5\n",
        b"#!/bin/sh\nCFMGR_VERSION=03.4.5\n",
    )
    for index, invalid_entry in enumerate(bad_entries):
        (repository / "cfmgr.sh").write_bytes(invalid_entry)
        commit = commit_all(repository, f"invalid version {index}")
        with pytest.raises(ManifestError):
            generate_manifest(repository, commit)
        assert not marker.exists()


def test_host_version_rejects_nul_and_ascii28_but_accepts_unrelated_bytes() -> None:
    candidate = b"CFMGR_VERSION=1.2.3\n"
    assert _version(b"\x80\r\nunrelated\n" + candidate) == "1.2.3"
    for control in (b"\x00", b"\x1c"):
        for entry in (
            control + candidate,
            candidate + control,
            b"# unrelated " + control + b" byte\n" + candidate,
        ):
            with pytest.raises(ManifestError):
                _version(entry)

    version_128 = b"9" * 41 + b"." + b"8" * 42 + b"." + b"7" * 43
    version_129 = b"9" * 43 + b"." + b"8" * 42 + b"." + b"7" * 42
    assert len(version_128) == 128 and len(version_129) == 129
    assert _version(b"CFMGR_VERSION=" + version_128) == version_128.decode("ascii")
    with pytest.raises(ManifestError):
        _version(b"CFMGR_VERSION=" + version_129)


def test_rejects_noncommit_inputs_and_invalid_placeholder_records(tmp_path: Path) -> None:
    repository = new_repository(tmp_path / "repo")
    write_package(repository, version="1.0.0", payloads={"modules/file": b"payload"})
    commit = commit_all(repository, "base")
    blob = git(repository, "rev-parse", f"{commit}:cfmgr.sh")
    tree = git(repository, "rev-parse", f"{commit}^{{tree}}")

    for selector in (
        "HEAD",
        "main",
        commit[:12],
        commit + "^",
        blob,
        tree,
        "not-a-commit",
    ):
        with pytest.raises(ManifestError):
            generate_manifest(repository, selector)

    (repository / "cfmgr.sh").chmod(0o644)
    nonexecutable_entry = commit_all(repository, "nonexecutable entry")
    with pytest.raises(ManifestError):
        generate_manifest(repository, nonexecutable_entry)
    (repository / "cfmgr.sh").chmod(0o755)

    (repository / "modules/.gitkeep").write_bytes(b"not empty")
    invalid_placeholder = commit_all(repository, "nonempty placeholder")
    with pytest.raises(ManifestError):
        generate_manifest(repository, invalid_placeholder)

    (repository / "modules/.gitkeep").unlink()
    (repository / "modules/.gitkeep").symlink_to("file")
    symlink_placeholder = commit_all(repository, "symlink placeholder")
    with pytest.raises(ManifestError):
        generate_manifest(repository, symlink_placeholder)


def test_corrupted_git_and_trusted_parser_responses_are_rejected(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsysbinary: pytest.CaptureFixture[bytes],
) -> None:
    repository = new_repository(tmp_path / "repo")
    write_package(repository, version="4.5.6", payloads={"modules/file": b"payload"})
    commit = commit_all(repository, "response framing package")

    import tools.package_manifest as package_manifest

    responses: list[tuple[list[str], int, bytes, bytes]] = []
    real_run = subprocess.run

    def record_response(*args: object, **kwargs: object) -> subprocess.CompletedProcess[bytes]:
        result = real_run(*args, **kwargs)  # type: ignore[arg-type]
        command = args[0]
        assert isinstance(command, list)
        responses.append((command, result.returncode, result.stdout, result.stderr))
        return result

    monkeypatch.setattr(package_manifest.subprocess, "run", record_response)
    expected = generate_manifest(repository, commit)
    assert expected.startswith(b"manifest: 1\nversion: 4.5.6\n")
    batch_indices = [
        index
        for index, (command, _, _, _) in enumerate(responses)
        if len(command) >= 2 and command[-2:] == ["cat-file", "--batch"]
    ]
    awk_indices = [
        index
        for index, (command, _, _, _) in enumerate(responses)
        if command and command[0] == "awk"
    ]
    assert len(batch_indices) == len(awk_indices) == 1
    assert all(status == 0 and not stderr for _, status, _, stderr in responses)

    def replay_corrupted(target: int, corrupt: object, *, cli: bool = False) -> None:
        consumed = 0

        def replay(*args: object, **kwargs: object) -> subprocess.CompletedProcess[bytes]:
            nonlocal consumed
            command = args[0]
            assert isinstance(command, list)
            assert consumed < len(responses)
            saved_command, status, stdout, stderr = responses[consumed]
            assert command == saved_command
            if consumed == target:
                assert callable(corrupt)
                stdout = corrupt(stdout)
            consumed += 1
            return subprocess.CompletedProcess(command, status, stdout, stderr)

        with monkeypatch.context() as context:
            context.setattr(package_manifest.subprocess, "run", replay)
            if cli:
                assert main(["--repo", str(repository), "--commit", commit]) == 1
                captured = capsysbinary.readouterr()
                assert captured.out == b""
            else:
                with pytest.raises(ManifestError):
                    generate_manifest(repository, commit)
        assert consumed == target + 1

    batch_index = batch_indices[0]
    replay_corrupted(batch_index, lambda data: data[:-1])
    replay_corrupted(
        batch_index,
        lambda data: data.replace(b" blob ", b" tree ", 1),
    )
    replay_corrupted(batch_index, lambda data: data + b"trailing")

    awk_index = awk_indices[0]
    replay_corrupted(awk_index, lambda _data: b"", cli=True)
    replay_corrupted(awk_index, lambda _data: b"manifest\t1\nend\t0\t0\t0\n")


def test_rejects_empty_payload_and_selected_symlink(tmp_path: Path) -> None:
    repository = new_repository(tmp_path / "repo")
    write_package(repository, version="1.0.0", payloads={"modules/empty": b""})
    empty = commit_all(repository, "empty payload")
    with pytest.raises(ManifestError):
        generate_manifest(repository, empty)

    (repository / "modules/empty").unlink()
    (repository / "modules/link").symlink_to("missing-target")
    symlink = commit_all(repository, "symlink payload")
    with pytest.raises(ManifestError):
        generate_manifest(repository, symlink)


def test_accepts_file_count_limit_and_rejects_the_next_file(tmp_path: Path) -> None:
    repository = new_repository(tmp_path / "repo")
    payloads = {f"modules/item-{index:03d}": b"x" for index in range(127)}
    write_package(repository, version="1.0.0", payloads=payloads)
    maximum = commit_all(repository, "maximum file count")
    result = generate_manifest(repository, maximum)
    assert result.count(b"\n") == 4 + 128
    assert result.startswith(b"manifest: 1\nversion: 1.0.0\n")
    assert result.endswith(b"\n")

    (repository / "modules/item-128").write_bytes(b"x")
    over_limit = commit_all(repository, "too many files")
    with pytest.raises(ManifestError):
        generate_manifest(repository, over_limit)


def test_file_and_aggregate_byte_limits_at_and_above_boundaries(tmp_path: Path) -> None:
    repository = new_repository(tmp_path / "repo")
    maximum_file = b"x" * 1_048_576
    write_package(repository, version="1.0.0", payloads={"modules/single": maximum_file})
    exact_file = commit_all(repository, "maximum individual file")
    assert generate_manifest(repository, exact_file).startswith(b"manifest: 1\n")

    (repository / "modules/single").write_bytes(maximum_file + b"x")
    oversized_file = commit_all(repository, "oversized individual file")
    with pytest.raises(ManifestError):
        generate_manifest(repository, oversized_file)

    entry_size = len(b"#!/bin/sh\nCFMGR_VERSION=1.0.0\nexit 0\n")
    (repository / "modules/single").unlink()
    payloads = {f"modules/full-{index}": b"x" * 1_048_576 for index in range(7)}
    payloads["modules/last"] = b"x" * (1_048_576 - entry_size)
    write_package(repository, version="1.0.0", payloads=payloads)
    exact_total = commit_all(repository, "maximum aggregate bytes")
    assert generate_manifest(repository, exact_total).startswith(b"manifest: 1\n")

    (repository / "modules/last").write_bytes(b"x" * (1_048_576 - entry_size + 1))
    oversized_total = commit_all(repository, "aggregate bytes over limit")
    with pytest.raises(ManifestError):
        generate_manifest(repository, oversized_total)


def test_cli_status_and_stdout_contract(
    tmp_path: Path, capsysbinary: pytest.CaptureFixture[bytes]
) -> None:
    repository = new_repository(tmp_path / "repo")
    write_package(repository, version="1.2.3", payloads={"modules/file": b"payload"})
    commit = commit_all(repository, "valid cli package")
    expected = literal_manifest(
        "1.2.3",
        (
            ("cfmgr.sh", b"#!/bin/sh\nCFMGR_VERSION=1.2.3\nexit 0\n", 0o755),
            ("modules/file", b"payload", 0o644),
        ),
    )

    assert main(["--repo", str(repository), "--commit", commit.upper()]) == 0
    captured = capsysbinary.readouterr()
    assert captured.out == expected
    assert captured.err == b""

    with pytest.raises(SystemExit) as usage:
        main(["--repo", str(repository)])
    assert usage.value.code == 2
    captured = capsysbinary.readouterr()
    assert captured.out == b""
    assert b"usage" in captured.err.lower()

    assert main(["--repo", str(repository), "--commit", "HEAD"]) == 1
    captured = capsysbinary.readouterr()
    assert captured.out == b""
