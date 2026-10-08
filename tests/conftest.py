"""Central fixture and evidence registration for host-only development tests."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

from tests.harness import RouterHarness, matrix_ids

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_LEVELS = frozenset({"harness", "host", "busybox"})


def validate_matrix_marker(marker: pytest.Mark, known: frozenset[str]) -> None:
    if not marker.args or any(
        not isinstance(identifier, str) or identifier not in known for identifier in marker.args
    ):
        raise ValueError(f"matrix requires known PLAN IDs; received {marker.args!r}")
    if (
        set(marker.kwargs) != {"evidence"}
        or not isinstance(marker.kwargs["evidence"], str)
        or marker.kwargs["evidence"] not in EVIDENCE_LEVELS
    ):
        raise ValueError("matrix evidence must be harness, host, or busybox")


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption("--busybox", metavar="PATH", help="required executable BusyBox for this run")


def pytest_configure(config: pytest.Config) -> None:
    value = config.getoption("busybox")
    config._cfmgr_busybox = None
    if value is not None:
        executable = Path(value).expanduser().resolve()
        if not executable.is_file() or not os.access(executable, os.X_OK):
            raise pytest.UsageError(f"requested BusyBox is unavailable: {value}")
        try:
            version = subprocess.run(
                [str(executable)],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
                env={"PATH": "", "LC_ALL": "C"},
            )
            shell = subprocess.run(
                [str(executable), "sh", "-c", "exit 0"],
                capture_output=True,
                timeout=3,
                check=False,
                env={"PATH": "", "LC_ALL": "C"},
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise pytest.UsageError(f"requested BusyBox cannot run: {error}") from error
        banner = version.stdout + version.stderr
        if "BusyBox v" not in banner or shell.returncode != 0:
            raise pytest.UsageError("requested executable is not a working BusyBox with sh")
        config._cfmgr_busybox = executable
        config._cfmgr_busybox_version = banner.splitlines()[0]


def pytest_report_header(config: pytest.Config) -> list[str]:
    busybox = getattr(config, "_cfmgr_busybox_version", "unavailable; busybox tests skipped")
    return [
        "CFMgr evidence: synthetic harness/host only; PLAN V cases remain separately assessed",
        f"BusyBox: {busybox}",
    ]


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    known = matrix_ids(ROOT / "PLAN.md")
    for item in items:
        # Function/class markers override the module's default evidence mapping.
        marker = item.get_closest_marker("matrix")
        if marker is not None:
            try:
                validate_matrix_marker(marker, known)
            except ValueError as error:
                raise pytest.UsageError(f"{item.nodeid}: {error}") from error
            item.user_properties.append(("matrix_ids", ",".join(marker.args)))
            item.user_properties.append(("evidence", marker.kwargs["evidence"]))
        if item.get_closest_marker("busybox") and config._cfmgr_busybox is None:
            item.add_marker(pytest.mark.skip(reason="BusyBox unavailable; supply --busybox PATH"))


def pytest_terminal_summary(terminalreporter: pytest.TerminalReporter) -> None:
    evidence: dict[tuple[str, str], dict[str, int]] = {}
    for status, reports in terminalreporter.stats.items():
        if status not in {"passed", "failed", "error", "skipped", "xfailed", "xpassed"}:
            continue
        for report in reports:
            if getattr(report, "when", None) not in {"call", "setup"}:
                continue
            # Setup reports occur in stats only for failures/skips, avoiding double counts.
            properties = dict(getattr(report, "user_properties", ()))
            for identifier in properties.get("matrix_ids", "").split(","):
                if identifier:
                    key = identifier, properties["evidence"]
                    counts = evidence.setdefault(key, {})
                    counts[status] = counts.get(status, 0) + 1
    if evidence:
        terminalreporter.write_sep("-", "Matrix mappings (evidence counts, not V-case verdicts)")
        for (identifier, level), counts in sorted(evidence.items()):
            summary = ", ".join(f"{status}={count}" for status, count in sorted(counts.items()))
            terminalreporter.write_line(f"{identifier} [{level}]: {summary}")


@pytest.fixture
def router(tmp_path: Path) -> RouterHarness:
    return RouterHarness(tmp_path / "router")


@pytest.fixture
def busybox_router(tmp_path: Path, pytestconfig: pytest.Config) -> RouterHarness:
    executable = pytestconfig._cfmgr_busybox
    if executable is None:
        pytest.skip("BusyBox unavailable; supply --busybox PATH")
    return RouterHarness(tmp_path / "busybox-router", busybox=executable)
