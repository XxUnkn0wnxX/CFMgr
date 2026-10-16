"""Full installed-entry menu regression for retained package integrity."""

from __future__ import annotations

import hashlib
import os
import shlex
import shutil
import subprocess
from pathlib import Path

import pytest
from entry_package_fixture import adapt_native, finish_package
from test_config_observation import commands as _commands
from test_config_observation import config as _config
from test_dependency_reinstall import entry_run as _entry_run
from test_install import package as _package
from test_install import shell as _shell
from test_install import tools as _tools

ROOT = Path(__file__).resolve().parents[1]
package = _package
shell = _shell
tools = _tools
config = _config
commands = _commands
entry_run = _entry_run
__all__ = ["commands", "config", "entry_run", "package", "shell", "tools"]


@pytest.fixture
def installed_package(
    package: Path,
    shell: list[str],
    tools: dict[str, str],
    config: bytes,
    tmp_path: Path,
) -> tuple[Path, Path, Path, Path]:
    adapted = tmp_path / "adapted-package"
    shutil.copytree(package, adapted)
    jffs = tmp_path / "jffs"
    scripts = jffs / "scripts"
    addons = jffs / "addons"
    support = addons / "CFMgr.d"
    scripts.mkdir(parents=True)
    support.mkdir(mode=0o700, parents=True)
    support.chmod(0o700)

    shutil.copy2(adapted / "catalog.txt", support / "catalog.txt")
    shutil.copy2(adapted / "manifest.txt", support / "manifest.txt")
    shutil.copytree(adapted / "modules", support / "modules")
    (support / "config").write_bytes(config)
    (support / "config").chmod(0o600)
    (support / "setup-state").write_text("CFMGR-SETUP 1 0.1.0 complete\n")
    (support / "setup-state").chmod(0o600)

    entry = scripts / "cfmgr.sh"
    shutil.copy2(adapted / "cfmgr.sh", entry)
    finish_package(entry, support, tools, shell, adapt=True)
    shutil.copy2(support / "manifest.txt", adapted / "manifest.txt")
    assert entry.stat().st_mode & 0o777 == 0o755
    return entry, support, adapted / "manifest.txt", tmp_path


def test_complete_installed_package_reaches_real_menu_and_exits(
    shell: list[str], installed_package: tuple[Path, Path, Path, Path]
) -> None:
    entry, support, manifest, _tmp_path = installed_package
    assert (support / "modules/manager_settings.sh").read_bytes() == (
        ROOT / "modules/manager_settings.sh"
    ).read_bytes()
    assert manifest.read_bytes() == (support / "manifest.txt").read_bytes()

    result = entry_run(shell, entry, ["--internal-launch"], b"e\n", terminal=True)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"0 Check status" in result.stdout
    assert b"e Exit" in result.stdout
    assert b"launch: error" not in result.stderr


@pytest.mark.parametrize(
    "module_name, action",
    [
        ("manager_settings.sh", []),
        ("manager_settings.sh", ["reinstall"]),
        ("lib/package.sh", []),
        ("lib/package.sh", ["reinstall"]),
    ],
)
def test_installed_entry_refuses_modified_module_before_import_or_menu(
    shell: list[str],
    installed_package: tuple[Path, Path, Path, Path],
    module_name: str,
    action: list[str],
) -> None:
    entry, support, manifest, tmp_path = installed_package
    module = support / "modules" / module_name
    marker = tmp_path / "manager-settings-sourced"
    original_manifest = manifest.read_bytes()
    original_mode = module.stat().st_mode & 0o777
    with module.open("a") as stream:
        stream.write(f"\nprintf '%s\\n' sentinel > {shlex.quote(str(marker))}\n")
    module.chmod(original_mode)

    assert (support / "manifest.txt").read_bytes() == original_manifest
    assert module.stat().st_uid == os.geteuid()
    assert module.stat().st_mode & 0o777 == original_mode
    assert entry.read_text().splitlines().count("CFMGR_VERSION=0.1.0") == 1

    result = entry_run(
        shell, entry, ["--internal-launch", *action], b"e\n", terminal=True
    )
    assert not marker.exists(), (result.stdout, result.stderr)
    assert b"0 Check status" not in result.stdout, (result.stdout, result.stderr)
    assert result.returncode != 0, (result.stdout, result.stderr)


@pytest.mark.parametrize("damage", ["duplicate", "missing", "mixed", "nul", "no-lf"])
def test_entry_rejects_inconsistent_metadata_before_menu(
    shell, installed_package, damage
):
    entry, support, _, _ = installed_package
    manifest = support / "manifest.txt"
    rows = manifest.read_bytes().splitlines(keepends=True)
    if damage == "duplicate":
        rows.append(rows[-1])
    elif damage == "missing":
        rows = [row for row in rows if not row.endswith(b"modules/lib/package.sh\n")]
    elif damage == "mixed":
        rows[0] = b"CFMGR-MANIFEST 2 0.1.0 2 1\n"
    elif damage == "nul":
        rows[-1] = rows[-1].replace(b"\n", b"\0\n")
    else:
        rows[-1] = rows[-1].rstrip(b"\n")
    manifest.write_bytes(b"".join(rows))
    result = entry_run(shell, entry, ["--internal-launch"], b"e\n", terminal=True)
    assert result.returncode != 0, (result.stdout, result.stderr)
    assert b"0 Check status" not in result.stdout


@pytest.mark.parametrize("schema", [1, 2])
def test_complete_generation_preserves_passive_extensions_without_loading(
    shell, tools, installed_package, schema
):
    entry, support, _, tmp_path = installed_package
    marker = tmp_path / "extension-executed"
    extension = support / "modules/extension/deeper/owned.sh"
    extension.parent.mkdir(parents=True)
    extension.write_text(f"printf bad >{shlex.quote(str(marker))}\n")
    extension.chmod(0o644)
    private = support / "owned/deeper/keep"
    private.parent.mkdir(parents=True)
    private.write_bytes(b"preserved private extension\n")
    finish_package(entry, support, tools, shell)
    if schema == 1:
        manifest = support / "manifest.txt"
        manifest.write_bytes(
            manifest.read_bytes().replace(
                b"CFMGR-MANIFEST 2 0.1.0 1 1\n", b"CFMGR-MANIFEST 1 0.1.0\n", 1
            )
        )
    result = entry_run(shell, entry, ["--internal-launch"], b"e\n", terminal=True)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"0 Check status" in result.stdout
    assert not marker.exists()
    assert private.read_bytes() == b"preserved private extension\n"


@pytest.mark.parametrize("fault", ["append", "producer-failure"])
def test_native_digest_rejects_extra_bytes_and_failed_reader(
    shell, tools, tmp_path, fault
):
    data = tmp_path / "payload"
    original = b"checked prefix\n"
    data.write_bytes(original + (b"appended code\n" if fault == "append" else b""))
    prefix = (ROOT / "cfmgr.sh").read_text().split("\ncase ${1-} in", 1)[0]
    if fault == "producer-failure":
        reader = tmp_path / "failed-dd"
        if shell[1:] == ["ash"]:
            actual = shlex.join([str(Path(tools["sh"]).resolve()), "dd"])
        else:
            actual = shlex.quote(shutil.which("dd"))
        reader.write_text(f'#!/bin/sh\n{actual} "$@"\nexit 1\n')
        reader.chmod(0o755)
        prefix = prefix.replace("/bin/dd", str(reader))
    prefix = adapt_native(prefix, tmp_path / "jffs", tools, shell)
    script = (
        prefix + '\ncfmgr_entry_hash "$1" "$2" && [ "$cfmgr_entry_digest" = "$3" ]\n'
    )
    result = subprocess.run(
        [
            *shell,
            "-c",
            script,
            "digest",
            str(data),
            str(len(original)),
            hashlib.sha256(original).hexdigest(),
        ],
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert result.returncode != 0, (result.stdout, result.stderr)
