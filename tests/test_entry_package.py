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


def native_health_entry(tmp_path: Path, files: dict[str, bytes]) -> Path:
    """Adapt only fixed native kernel/output paths in a standalone trusted copy."""
    proc = tmp_path / "proc"
    proc.mkdir()
    for name, data in files.items():
        target = proc / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    output = shutil.which("printf")
    assert output, "The fixed native output applet is required"
    entry = tmp_path / "cfmgr.sh"
    entry.write_text(
        (ROOT / "cfmgr.sh")
        .read_text()
        .replace("/proc/", str(proc) + "/")
        .replace("/usr/bin/printf", output)
        .replace("/jffs", str(tmp_path / "absent-jffs"))
    )
    return entry


def test_standalone_health_aliases_use_only_native_snapshot(shell, tmp_path):
    entry = native_health_entry(
        tmp_path,
        {
            "uptime": b"120.25 11.00\n",
            "loadavg": b"0.10 0.20 0.30 1/100 123\n",
            "meminfo": b"MemTotal: 102400 kB\nMemFree: 20000 kB\nMemAvailable: 30000 kB\n",
            "sys/kernel/osrelease": b"4.1.52-test\n",
        },
    )
    outputs = []
    for alias in ("--health", "--doctor", "--diagnostic"):
        result = subprocess.run(
            [*shell, str(entry), alias],
            capture_output=True,
            timeout=3,
            check=False,
            env={
                **os.environ,
                "CFMGR_INTERNAL_LAUNCH": "1",
                "COLUMNS": "80",
                "TERM": "xterm-256color",
                "CFMGR_SOURCE": str(tmp_path / "untrusted-source"),
            },
        )
        assert result.returncode == 0, (result.stdout, result.stderr)
        assert result.stderr == b""
        outputs.append(result.stdout)
    assert len(set(outputs)) == 1
    output = outputs[0]
    assert b"Uptime: 120.25 seconds" in output
    assert b"Load (1/5/15 minutes): 0.10 / 0.20 / 0.30" in output
    assert b"total 102400 kB; available 30000 kB" in output
    assert b"Kernel release: 4.1.52-test" in output
    assert b"package.extension [FAIL]" in output
    assert b"config.validation [SKIP]" in output
    assert b"network.readiness [SKIP]" in output
    assert b"\x1b" not in output
    assert not (tmp_path / "absent-jffs").exists()
    assert sorted(path.name for path in tmp_path.iterdir()) == ["cfmgr.sh", "proc"]


@pytest.mark.parametrize("kind", ["missing", "unsafe", "old-kernel"])
def test_native_health_retains_independent_checks_when_data_unavailable(
    shell, tmp_path, kind
):
    files = {}
    if kind == "unsafe":
        files = {
            "uptime": b"123\x1b[2JSECRET 0\n",
            "loadavg": b"0.1 0.2 TOKEN 1/10 123\n",
            "meminfo": b"MemTotal: SECRET kB\nMemAvailable: 123 kB\n",
            "sys/kernel/osrelease": b"kernel\x1b[2JSECRET",
        }
    elif kind == "old-kernel":
        files = {"meminfo": b"MemTotal: 102400 kB\nMemFree: 20000 kB\n"}
    entry = native_health_entry(tmp_path, files)
    result = subprocess.run(
        [*shell, str(entry), "--health"],
        capture_output=True,
        timeout=3,
        check=False,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stderr == b""
    assert b"system.native [PASS]" in result.stdout
    assert b"system.uptime [UNKNOWN]" in result.stdout
    assert b"system.load [UNKNOWN]" in result.stdout
    assert b"system.kernel [UNKNOWN]" in result.stdout
    assert b"config.validation [SKIP]" in result.stdout
    assert b"SECRET" not in result.stdout and b"TOKEN" not in result.stdout
    assert b"\x1b" not in result.stdout
    if kind == "old-kernel":
        assert b"system.memory [WARN]" in result.stdout
        assert b"free 20000 kB; available estimate unsupported" in b" ".join(
            result.stdout.splitlines()
        )
    else:
        assert b"system.memory [UNKNOWN]" in result.stdout


def test_health_aliases_reject_extra_arguments_before_observation(shell, tmp_path):
    entry = native_health_entry(tmp_path, {})
    for alias in ("--health", "--doctor", "--diagnostic"):
        result = subprocess.run(
            [*shell, str(entry), alias, "extra"],
            capture_output=True,
            timeout=3,
            check=False,
        )
        assert result.returncode == 2
        assert result.stdout == result.stderr == b""


@pytest.mark.parametrize(
    "data",
    [
        b"MemTotal: 0 kB\nMemAvailable: 0 kB\n",
        b"MemTotal: 100 kB\nMemAvailable: 101 kB\n",
        b"MemTotal: 100 kB\nMemFree: 101 kB\n",
        b"MemTotal: 100 kB\nMemTotal: 100 kB\nMemAvailable: 20 kB\n",
        b"MemTotal: 0100 kB\nMemAvailable: 20 kB\n",
        b"MemTotal: 100 kB\nMemAvailable: 000 kB\n",
    ],
)
def test_native_health_rejects_ambiguous_or_inconsistent_memory(shell, tmp_path, data):
    entry = native_health_entry(tmp_path, {"meminfo": data})
    result = subprocess.run(
        [*shell, str(entry), "--health"],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"system.memory [UNKNOWN]" in result.stdout


def test_native_rows_wrap_without_builtin_output_or_test_and_reject_controls(
    shell, tmp_path
):
    entry = native_health_entry(tmp_path, {})
    prefix = entry.read_text().split("\ncase ${1-} in", 1)[0]
    alias_setup = (
        "shopt -s expand_aliases\n"
        if Path(shell[0]).name.lower().endswith("bash")
        else ""
    )
    script = (
        alias_setup
        + "cfmgr_test_disabled_bracket() { return 93; }\nalias '['=cfmgr_test_disabled_bracket\n"
        + prefix
        + r"""
printf() { return 91; }
test() { return 92; }
[ probe ]
cfmgr_bracket_probe=$?
case $cfmgr_bracket_probe in 93) ;; *) exit 95 ;; esac
cfmgr_entry_health_row system.example UNKNOWN 'A safe detail longer than the narrow terminal width.' unknown 'Inspect native prerequisites.' system.native
"""
    )
    result = subprocess.run(
        [*shell, "-c", script],
        capture_output=True,
        check=False,
        timeout=3,
        env={**os.environ, "COLUMNS": "20"},
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout and max(map(len, result.stdout.splitlines())) <= 20
    assert b"\x1b" not in result.stdout
    unsafe = subprocess.run(
        [
            *shell,
            "-c",
            prefix
            + '\ncfmgr_entry_health_row system.example UNKNOWN "$1" unknown None\n',
            "row",
            "unsafe\x1b[2J",
        ],
        capture_output=True,
        check=False,
        timeout=3,
    )
    assert unsafe.returncode == 2
    assert unsafe.stdout == unsafe.stderr == b""


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


def health_admit(shell, entry, support):
    prefix = entry.read_text().split("\ncase ${1-} in", 1)[0]
    script = (
        prefix
        + r"""
cfmgr_source=$1
if cfmgr_entry_health_admit; then printf 'backup=%s manager=%s package=%s catalog=%s\n' "$cfmgr_health_backup" "$cfmgr_health_manager" "$cfmgr_health_package" "$cfmgr_health_catalog"; exit 0; fi
printf '%s\n' "$cfmgr_health_problem"
exit 1
"""
    )
    return subprocess.run(
        [*shell, "-c", script, str(entry), str(support)],
        capture_output=True,
        check=False,
        timeout=5,
    )


def test_health_closure_admits_without_unrelated_payload_or_installed_entry(
    shell, installed_package
):
    entry, support, _, tmp_path = installed_package
    (support / "modules/backup.sh").unlink()
    (support / "modules/manager.sh").unlink()
    manifest = support / "manifest.txt"
    manifest.write_bytes(
        b"".join(
            row
            for row in manifest.read_bytes().splitlines(keepends=True)
            if b"\tmodules/backup.sh\n" not in row
        )
    )
    standalone = tmp_path / "standalone.sh"
    shutil.copy2(entry, standalone)
    entry.unlink()
    result = health_admit(shell, standalone, support)
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert result.stdout == (
        b"backup=missing manager=untrusted package=verified catalog=verified\n"
    )
    assert result.stderr == b""

    # Same development version does not pair a different trusted entry with an
    # installed generation. The invocation itself must match the manifest hash.
    with standalone.open("a") as stream:
        stream.write("\n# different development entry\n")
    mismatch = health_admit(shell, standalone, support)
    assert mismatch.returncode == 1
    assert b"Trusted entry does not match" in mismatch.stdout


@pytest.mark.parametrize(
    "flag,record,path",
    [
        ("backup", "modules/backup.sh", "modules/backup.sh"),
        ("manager", "modules/manager.sh", "modules/manager.sh"),
        ("package", "modules/lib/package.sh", "modules/lib/package.sh"),
        ("catalog", "catalog.txt", "catalog.txt"),
    ],
)
def test_health_optional_records_are_admitted_independently(
    shell, installed_package, flag, record, path
):
    entry, support, _, _ = installed_package
    optional = {
        "backup": "verified",
        "manager": "verified",
        "package": "verified",
        "catalog": "verified",
    }
    verified = health_admit(shell, entry, support)
    assert verified.returncode == 0, (verified.stdout, verified.stderr)
    assert (
        verified.stdout
        == b"backup=verified manager=verified package=verified catalog=verified\n"
    )

    member = support / path
    original = member.read_bytes()
    member.write_bytes(bytes([original[0] ^ 1]) + original[1:])
    optional[flag] = "untrusted"
    tampered = health_admit(shell, entry, support)
    assert tampered.returncode == 0, (tampered.stdout, tampered.stderr)
    assert tampered.stdout == (
        " ".join(f"{name}={state}" for name, state in optional.items()).encode() + b"\n"
    )

    member.write_bytes(original)
    manifest = support / "manifest.txt"
    manifest.write_bytes(
        b"".join(
            row
            for row in manifest.read_bytes().splitlines(keepends=True)
            if f"\t{record}\n".encode() not in row
        )
    )
    optional[flag] = "missing"
    absent = health_admit(shell, entry, support)
    assert absent.returncode == 0, (absent.stdout, absent.stderr)
    assert absent.stdout == (
        " ".join(f"{name}={state}" for name, state in optional.items()).encode() + b"\n"
    )


@pytest.mark.parametrize(
    "member",
    [
        "status.sh",
        "lib/storage.sh",
        "lib/execution.sh",
        "lib/config.sh",
        "lib/network.sh",
        "helpers/worker.sh",
    ],
)
def test_health_entry_refuses_each_changed_closure_member_before_import(
    shell, installed_package, member
):
    entry, support, _, tmp_path = installed_package
    marker = tmp_path / "untrusted-module-sourced"
    module = support / "modules" / member
    with module.open("a") as stream:
        stream.write(f"\nprintf hacked > {shlex.quote(str(marker))}\n")
    result = subprocess.run(
        [*shell, str(entry), "--health"],
        capture_output=True,
        check=False,
        timeout=5,
        env={**os.environ, "COLUMNS": "100"},
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"system.native [PASS]" in result.stdout
    assert b"package.extension [FAIL]" in result.stdout
    assert f"Diagnostic member missing or untrusted: modules/{member}.".encode() in (
        result.stdout
    )
    assert b"config.validation [SKIP]" in result.stdout
    assert not marker.exists()


@pytest.mark.parametrize("damage", ["duplicate", "nul", "no-lf", "mixed"])
def test_health_closure_requires_one_strict_compatible_manifest_view(
    shell, installed_package, damage
):
    entry, support, _, _ = installed_package
    manifest = support / "manifest.txt"
    data = manifest.read_bytes()
    if damage == "duplicate":
        data += data.splitlines(keepends=True)[-1]
    elif damage == "nul":
        data = data.replace(b"modules/status.sh\n", b"modules/status.sh\0\n")
    elif damage == "mixed":
        data = data.replace(b" 1 2\n", b" 2 1\n", 1)
    else:
        data = data.rstrip(b"\n")
    manifest.write_bytes(data)
    result = health_admit(shell, entry, support)
    assert result.returncode == 1
    assert b"Protected compatible manifest" in result.stdout


def test_health_closure_rejects_writable_helper_ancestry(shell, installed_package):
    entry, support, _, _ = installed_package
    (support / "modules/helpers").chmod(0o777)
    result = health_admit(shell, entry, support)
    assert result.returncode == 1
    assert b"Protected installed diagnostic ancestry" in result.stdout


def test_health_manifest_rejects_failed_reader_even_after_complete_bytes(
    shell, tools, installed_package
):
    entry, support, _, tmp_path = installed_package
    native_dd = adapt_native("/bin/dd", entry.parent.parent, tools, shell)
    reader = tmp_path / "failed-reader"
    reader.write_text(f'#!/bin/sh\n{shlex.quote(native_dd)} "$@"\nexit 1\n')
    reader.chmod(0o755)
    entry.write_text(entry.read_text().replace(native_dd, str(reader)))
    result = health_admit(shell, entry, support)
    assert result.returncode == 1
    assert b"Protected compatible manifest" in result.stdout
    assert b"Trusted entry does not match" not in result.stdout


def test_complete_installed_package_reaches_real_menu_and_exits(
    shell: list[str], installed_package: tuple[Path, Path, Path, Path]
) -> None:
    entry, support, manifest, _tmp_path = installed_package
    assert (support / "modules/manager.sh").read_bytes() == (
        ROOT / "modules/manager.sh"
    ).read_bytes()
    assert manifest.read_bytes() == (support / "manifest.txt").read_bytes()

    # Keep native admission diagnostics in pytest's failure-only capture. This
    # isolated fixture contains no live configuration or private credentials.
    result = entry_run(
        [*shell, "-x"], entry, ["--internal-launch"], b"e\n", terminal=True
    )
    assert result.returncode == 0, (result.stdout, result.stderr)
    assert b"0 Check status" in result.stdout
    assert b"e Exit" in result.stdout
    assert b"launch: error" not in result.stderr


@pytest.mark.parametrize(
    "module_name, action",
    [
        ("manager.sh", []),
        ("manager.sh", ["reinstall"]),
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
                b"CFMGR-MANIFEST 2 0.1.0 1 2\n", b"CFMGR-MANIFEST 1 0.1.0\n", 1
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
