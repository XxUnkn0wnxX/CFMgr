"""Terminal summary evidence-count regressions."""

from __future__ import annotations

from types import SimpleNamespace

import pytest

from tests.conftest import pytest_terminal_summary

pytestmark = [pytest.mark.unit, pytest.mark.matrix("V43", evidence="harness")]


def test_terminal_summary_ignores_successful_setup_reports() -> None:
    properties = [("matrix_ids", "V43"), ("evidence", "harness")]

    def report(when: str) -> SimpleNamespace:
        return SimpleNamespace(when=when, user_properties=properties)

    class TerminalReporter:
        stats = {
            "": [report("setup")],
            "passed": [report("call")],
            "failed": [report("call")],
            "skipped": [report("call")],
        }

        def __init__(self) -> None:
            self.lines: list[str] = []

        def write_sep(self, *_args: object) -> None:
            pass

        def write_line(self, line: str) -> None:
            self.lines.append(line)

    terminalreporter = TerminalReporter()
    pytest_terminal_summary(terminalreporter)  # type: ignore[arg-type]

    assert terminalreporter.lines == ["V43 [harness]: failed=1, passed=1, skipped=1"]
