"""Complete installed fixture metadata and literal native-platform adapters."""

from __future__ import annotations

import os
import shlex
import shutil
import tempfile
from pathlib import Path

from tools import package as package_builder

ROOT = Path(__file__).resolve().parents[1]


def complete_modules(support: Path) -> None:
    """Fill missing payloads without replacing a consumer's explicit adapters."""
    for source in (ROOT / "modules").rglob("*"):
        if source.name == ".DS_Store":
            continue
        target = support / source.relative_to(ROOT)
        if source.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif not target.exists():
            shutil.copy2(source, target)


def adapt_native(text: str, jffs: Path, tools: dict[str, str], shell: list[str]) -> str:
    """Run actual firmware applets in vendor CI and actual host tools elsewhere."""
    names = {
        "/usr/bin/readlink": "readlink",
        "/usr/bin/awk": "awk",
        "/bin/ls": "ls",
        "/bin/dd": "dd",
        "/usr/bin/wc": "wc",
        "/usr/bin/env": "env",
        "/usr/bin/printf": "printf",
        "/usr/sbin/openssl": "openssl",
    }
    paths = {name: tools.get(name) or shutil.which(name) for name in names.values()}
    assert all(paths.values()), "Actual native package verification tools are required"
    if shell[1:] == ["ash"]:
        applets = jffs.parent / "native-entry-applets"
        applets.mkdir(exist_ok=True)
        vendor = Path(tools["sh"]).resolve(strict=True)
        for name in names.values():
            if name == "openssl":
                continue
            target = applets / name
            if not target.exists():
                target.symlink_to(vendor)
            paths[name] = str(target)
    text = text.replace("/jffs", str(jffs))
    # / is firmware-root-owned while isolated fixture descendants are user-owned.
    text = text.replace("$3!=0", f"($3!=0 && $3!={os.geteuid()})")
    for literal, name in names.items():
        text = text.replace(literal, str(paths[name]))
    shell_args = [] if shell[1:] == ["ash"] else shell[1:]
    return text.replace(" /bin/sh ", " " + shlex.join([tools["sh"], *shell_args]) + " ")


def finish_package(
    entry: Path,
    support: Path,
    tools: dict[str, str],
    shell: list[str],
    *,
    adapt: bool = False,
) -> None:
    """Regenerate real catalog/hash records after every consumer fixture edit."""
    complete_modules(support)
    if adapt:
        entry.write_text(
            adapt_native(entry.read_text(), entry.parent.parent, tools, shell)
        )
        verifier = support / "modules/lib/package.sh"
        verifier.write_text(
            adapt_native(verifier.read_text(), entry.parent.parent, tools, shell)
        )
    entry.chmod(0o755)
    for item in (support / "modules").rglob("*"):
        if item.is_file() and item.stat().st_mode & 0o777 == 0o600:
            item.chmod(0o644)
    with tempfile.TemporaryDirectory(prefix="cfmgr-entry-metadata-") as directory:
        stage = Path(directory)
        shutil.copy2(entry, stage / "cfmgr.sh")
        shutil.copytree(support / "modules", stage / "modules")
        catalog = stage / "catalog.txt"
        catalog.write_bytes(package_builder.catalog(stage))
        catalog.chmod(0o644)
        manifest = package_builder.manifest(stage)
        (support / "catalog.txt").write_bytes(catalog.read_bytes())
        (support / "manifest.txt").write_bytes(manifest)
    for name in ("catalog.txt", "manifest.txt"):
        (support / name).chmod(0o644)
