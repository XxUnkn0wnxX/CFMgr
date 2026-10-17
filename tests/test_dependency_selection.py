"""Behavioral contracts for source-inert dependency selection helpers."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "modules/lib/execution.sh"
PACKAGES = (
    "jq",
    "jq-full",
    "coreutils-timeout",
    "coreutils-sha256sum",
    "flock",
    "bind-dig",
)
DEFAULT_STATUS: dict[str, str | None] = dict.fromkeys(PACKAGES)


@pytest.fixture(scope="module")
def shell() -> list[str]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    command = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert command and shutil.which(command[0]), "Selected POSIX test shell is missing"
    return command


@pytest.fixture(scope="module")
def tools() -> dict[str, str]:
    resolved = {name: shutil.which(name) for name in ("awk", "wc")}
    missing = [name for name, path in resolved.items() if not path]
    assert not missing, f"Actual tools are missing: {', '.join(missing)}"
    return {name: path for name, path in resolved.items() if path}


def invoke(
    shell: list[str], script: str, *arguments: str | Path
) -> subprocess.CompletedProcess[bytes]:
    return subprocess.run(
        [*shell, "-c", script, "dependency-test", str(LIBRARY), *map(str, arguments)],
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
        check=False,
        capture_output=True,
        timeout=5,
    )


def make_receipt(
    states: dict[str, str | None] | None = None,
    *,
    metadata: tuple[str, ...] = (),
    duplicate_fields: dict[str, tuple[str, ...]] | None = None,
) -> bytes:
    """Build the fixed helper protocol with ordinary opkg status records."""
    observed = states if states is not None else DEFAULT_STATUS
    repeated = duplicate_fields or {}
    lines = ["ready END"]
    for package in PACKAGES:
        lines.append(f"status {package} BEGIN")
        status = observed.get(package)
        if status is not None:
            lines.extend(
                (
                    f"Package: {package}",
                    "Version: 1.2.3-r0",
                    f"Status: {status}",
                    *metadata,
                    *repeated.get(package, ()),
                    "",
                )
            )
        lines.append(f"status {package} 0 END")
    lines.append("queried 0 END")
    return ("\n".join(lines) + "\n").encode()


def select(
    shell: list[str],
    tools: dict[str, str],
    tmp_path: Path,
    missing: str,
    data: bytes,
) -> subprocess.CompletedProcess[bytes]:
    receipt = tmp_path / "receipt"
    receipt.write_bytes(data)
    return invoke(
        shell,
        '. "$1"; cfmgr_dependencies_select "$2" "$3" "$4" "$5"',
        tools["awk"],
        missing,
        receipt,
        tools["wc"],
    )


def test_source_is_inert_and_empty_inventory_is_healthy(
    shell: list[str], tmp_path: Path
) -> None:
    result = invoke(
        shell,
        'cd "$2"; before=$PWD; old_path=$PATH; caller_sentinel=kept; '
        '. "$1"; cfmgr_dependencies_inventory "" || exit $?; '
        '[ "$PWD" = "$before" ] && [ "$PATH" = "$old_path" ] && '
        '[ "$caller_sentinel" = kept ] && [ -z "$cfmgr_dependencies_missing" ]',
        tmp_path,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_inventory_accepts_only_the_fixed_ordered_set(shell: list[str]) -> None:
    expected = "jq coreutils-timeout coreutils-sha256sum flock bind-dig"
    result = invoke(
        shell,
        '. "$1"; cfmgr_dependencies_inventory "$2" && '
        'printf "%s\\n" "$cfmgr_dependencies_missing"',
        expected,
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        f"{expected}\n".encode(),
        b"",
    )


@pytest.mark.parametrize("inventory", ["unknown", "jq jq", "jq\tflock", "*"])
def test_invalid_inventory_is_rejected_without_filesystem_mutation(
    shell: list[str], tmp_path: Path, inventory: str
) -> None:
    # Make the wildcard resolve to an otherwise valid token; it still must not
    # turn caller syntax into an accepted package inventory.
    sentinel = tmp_path / "jq"
    sentinel.write_text("preserve\n")
    before = sorted((entry.name, entry.read_bytes()) for entry in tmp_path.iterdir())
    result = invoke(
        shell,
        'cd "$2"; . "$1"; cfmgr_dependencies_inventory "$3"',
        tmp_path,
        inventory,
    )
    after = sorted((entry.name, entry.read_bytes()) for entry in tmp_path.iterdir())
    assert result.returncode == 2
    assert result.stdout == b""
    assert before == after


def test_selector_emits_only_selected_absent_and_installed_packages(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    states = {
        "jq-full": "install user installed",
        "coreutils-sha256sum": "install ok installed",
        "bind-dig": "install user installed",
    }
    result = select(
        shell,
        tools,
        tmp_path,
        "jq coreutils-timeout coreutils-sha256sum",
        make_receipt(states, metadata=("Depends: libfoo (>= 1), bar",)),
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"r-jq-full i-coreutils-timeout r-coreutils-sha256sum\n",
        b"",
    )


def test_selector_accepts_multiline_opkg_metadata_and_maps_installed_jq_full(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    states = {"jq-full": "install user installed"}
    metadata = (
        "Conffiles:",
        " /opt/etc/example.conf abcdef0123456789",
        "Description: jq full package",
        " supports multiline descriptions",
    )
    result = select(
        shell, tools, tmp_path, "jq", make_receipt(states, metadata=metadata)
    )
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"r-jq-full\n",
        b"",
    )


@pytest.mark.parametrize(
    "status",
    ["install ok installed", "install user installed"],
)
def test_selector_accepts_real_installed_status_flags(
    shell: list[str], tools: dict[str, str], tmp_path: Path, status: str
) -> None:
    result = select(shell, tools, tmp_path, "flock", make_receipt({"flock": status}))
    assert (result.returncode, result.stdout) == (0, b"r-flock\n")


def test_selector_rejects_ambiguous_installed_jq_providers(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    result = select(
        shell,
        tools,
        tmp_path,
        "jq",
        make_receipt(
            {"jq": "install ok installed", "jq-full": "install user installed"}
        ),
    )
    assert result.returncode != 0 and result.stdout == b""


@pytest.mark.parametrize(
    "status",
    [
        "remove user installed",
        "install unknown installed",
        "install ok unknown-state",
        "install ok",
        "install ok installed extra",
    ],
)
def test_selector_rejects_untrustworthy_status_fields(
    shell: list[str], tools: dict[str, str], tmp_path: Path, status: str
) -> None:
    result = select(shell, tools, tmp_path, "flock", make_receipt({"flock": status}))
    assert result.returncode != 0 and result.stdout == b""


@pytest.mark.parametrize(
    "mutation",
    [
        "duplicate-query",
        "missing-query",
        "unknown-empty-query",
        "duplicate-ready-header",
        "ready-header-extra-token",
        "query-header-extra-token",
        "query-end-extra-token",
        "footer-extra-token",
        "record-after-footer",
        "orphan-continuation",
        "duplicate-package-field",
        "package-prefix-extra-space",
        "status-prefix-extra-space",
        "version-prefix-extra-space",
        "missing-footer",
    ],
)
def test_selector_rejects_incomplete_or_duplicate_query_records(
    shell: list[str],
    tools: dict[str, str],
    tmp_path: Path,
    mutation: str,
) -> None:
    receipt = make_receipt({"flock": "install ok installed"})
    if mutation == "duplicate-query":
        receipt = receipt.replace(
            b"status bind-dig BEGIN\n",
            b"status bind-dig BEGIN\nstatus jq BEGIN\nstatus jq 0 END\n",
        )
    elif mutation == "missing-query":
        receipt = receipt.replace(b"status bind-dig BEGIN\n", b"")
        receipt = receipt.replace(b"status bind-dig 0 END\n", b"")
    elif mutation == "unknown-empty-query":
        receipt = receipt.replace(b"status bind-dig BEGIN\n", b"status mystery BEGIN\n")
        receipt = receipt.replace(b"status bind-dig 0 END\n", b"status mystery 0 END\n")
    elif mutation == "duplicate-ready-header":
        receipt = receipt.replace(
            b"status jq BEGIN\n", b"ready END\nstatus jq BEGIN\n", 1
        )
    elif mutation == "ready-header-extra-token":
        receipt = receipt.replace(b"ready END\n", b"ready END extra\n", 1)
    elif mutation == "query-header-extra-token":
        receipt = receipt.replace(b"status jq BEGIN\n", b"status jq BEGIN extra\n", 1)
    elif mutation == "query-end-extra-token":
        receipt = receipt.replace(b"status jq 0 END\n", b"status jq 0 END extra\n", 1)
    elif mutation == "footer-extra-token":
        receipt = receipt.replace(b"queried 0 END\n", b"queried 0 END extra\n")
    elif mutation == "record-after-footer":
        receipt += b"status bind-dig BEGIN\nstatus bind-dig 0 END\n"
    elif mutation == "orphan-continuation":
        receipt = receipt.replace(
            b"Status: install ok installed\n",
            b"Status: install ok installed\n orphan text\n",
            1,
        )
    elif mutation == "duplicate-package-field":
        receipt = make_receipt(
            {"flock": "install ok installed"},
            duplicate_fields={"flock": ("Version: 2.0",)},
        )
    elif mutation == "package-prefix-extra-space":
        receipt = receipt.replace(b"Package: flock\n", b"Package : flock\n", 1)
    elif mutation == "status-prefix-extra-space":
        receipt = receipt.replace(
            b"Status: install ok installed\n", b"Status : install ok installed\n", 1
        )
    elif mutation == "version-prefix-extra-space":
        receipt = receipt.replace(b"Version: 1.2.3-r0\n", b"Version : 1.2.3-r0\n", 1)
    else:
        receipt = receipt.removesuffix(b"queried 0 END\n")
    result = select(shell, tools, tmp_path, "flock", receipt)
    assert result.returncode != 0 and result.stdout == b""


@pytest.mark.parametrize(
    "data",
    [
        make_receipt({"flock": "install ok installed"})[:-1],
        make_receipt({"flock": "install ok installed"}) + b"unexpected\n",
        make_receipt({"flock": "install ok installed"}) + b"\x00",
    ],
    ids=["missing-final-newline", "trailing-content", "nul-byte"],
)
def test_selector_rejects_truncated_or_trailing_receipt_bytes(
    shell: list[str], tools: dict[str, str], tmp_path: Path, data: bytes
) -> None:
    result = select(shell, tools, tmp_path, "flock", data)
    assert result.returncode != 0 and result.stdout == b""


def test_selector_fails_when_receipt_or_byte_count_query_fails(
    shell: list[str], tools: dict[str, str], tmp_path: Path
) -> None:
    missing_receipt = tmp_path / "does-not-exist"
    read_failure = invoke(
        shell,
        '. "$1"; cfmgr_dependencies_select "$2" flock "$3" "$4"',
        tools["awk"],
        missing_receipt,
        tools["wc"],
    )
    wc_failure = select(
        shell,
        {**tools, "wc": "/bin/false"},
        tmp_path,
        "flock",
        make_receipt(),
    )
    assert read_failure.returncode != 0 and read_failure.stdout == b""
    assert wc_failure.returncode != 0 and wc_failure.stdout == b""
