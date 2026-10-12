"""Focused behavior tests for the planning checker and developer test runner."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

from tools import check
from tools import test as runner


def make_valid_planning_tree(root: Path) -> None:
    specification = ["# Product plan", ""]
    checklist = ["# Checklist", ""]
    readme = ["# Product", "", "## Planned product goals", ""]
    for goal in range(1, 17):
        specification.extend([f"## {goal}. Goal {goal}", ""])
        checklist.extend([f"### {goal}. Goal {goal}", ""])
        readme.append(f"| {goal} | [Goal {goal}](PLAN_V2.md#{goal}-goal-{goal}) |")
        row_count = 10 if goal <= 13 else 9
        for subgoal in range(1, row_count + 1):
            identifier = f"S{goal:02d}.{subgoal:02d}"
            title = f"Feature {identifier}"
            requirement = f"Observable behavior for {identifier}."
            specification.append(f"| {identifier} | {title} | {requirement} |")
            checklist.append(
                f"| [ ] | [ ] | {identifier} | **{title}:** {requirement} |"
            )
        specification.append("")
        checklist.append("")

    root.mkdir(parents=True, exist_ok=True)
    (root / "PLAN_V2.md").write_text("\n".join(specification), encoding="utf-8")
    (root / "PLAN_V2_checklist.md").write_text("\n".join(checklist), encoding="utf-8")
    (root / "README.md").write_text("\n".join(readme) + "\n", encoding="utf-8")


def test_planning_checker_accepts_all_goals_rows_and_readme_links(
    tmp_path: Path,
) -> None:
    make_valid_planning_tree(tmp_path)
    assert check.validate(tmp_path) == []


def test_planning_checker_rejects_a_specification_checklist_mismatch(
    tmp_path: Path,
) -> None:
    make_valid_planning_tree(tmp_path)
    path = tmp_path / "PLAN_V2_checklist.md"
    text = path.read_text(encoding="utf-8")
    path.write_text(
        text.replace("Observable behavior for S01.01.", "Changed behavior."),
        encoding="utf-8",
    )
    assert any("subgoal content differs" in error for error in check.validate(tmp_path))


@pytest.mark.parametrize(
    ("document", "expected"),
    [
        ("[missing guide](missing.md)\n", "local link target is missing"),
        ("Private path: /Users/example/private-data\n", "literal personal home path"),
    ],
)
def test_planning_checker_rejects_broken_links_and_personal_paths(
    tmp_path: Path, document: str, expected: str
) -> None:
    make_valid_planning_tree(tmp_path)
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "developer.md").write_text(document, encoding="utf-8")
    assert any(expected in error for error in check.validate(tmp_path))


def _capture_runner(
    monkeypatch: pytest.MonkeyPatch,
) -> tuple[list[tuple[list[str], dict[str, str] | None]], list[list[str]]]:
    commands: list[tuple[list[str], dict[str, str] | None]] = []
    static_shells: list[list[str]] = []

    def fake_run(command: list[str], *, env: dict[str, str] | None = None) -> int:
        commands.append((command, env))
        return 0

    def fake_static() -> int:
        return 0

    def fake_syntax(shell: list[str]) -> int:
        static_shells.append(shell)
        return 0

    monkeypatch.setattr(runner, "_run", fake_run)
    monkeypatch.setattr(runner, "_static_checks", fake_static)
    monkeypatch.setattr(runner, "_shell_syntax_checks", fake_syntax)
    monkeypatch.setattr(runner, "_default_shell", lambda: ["/bin/test-shell"])
    monkeypatch.delenv("PYTEST_ADDOPTS", raising=False)
    return commands, static_shells


def test_runner_refuses_ambient_pytest_options_before_execution(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setenv("PYTEST_ADDOPTS", "-k unrelated")
    monkeypatch.setattr(sys, "argv", ["tools/test.py"])
    assert runner.main() == 2
    assert commands == []
    assert "PYTEST_ADDOPTS must be empty" in capsys.readouterr().err


def test_runner_passes_multiple_focused_paths_to_required_busybox(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "tools/test.py",
            "--focused",
            "tests/test_install.py",
            "tests/test_prerequisites.py",
            "--require-busybox",
        ],
    )
    assert runner.main() == 0
    pytest_command, pytest_env = commands[-1]
    assert pytest_command[-2:] == [
        str(runner.ROOT / "tests/test_install.py"),
        str(runner.ROOT / "tests/test_prerequisites.py"),
    ]
    assert pytest_env is not None
    assert pytest_env["CFMGR_REQUIRE_BUSYBOX"] == "1"


def test_runner_rejects_invalid_focused_paths_before_checks(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(
        sys, "argv", ["tools/test.py", "--focused", "tests/test_x.py;unsafe"]
    )
    assert runner.main() == 2
    assert commands == []
    assert "invalid focused selection" in capsys.readouterr().err


def test_runner_stops_after_a_failed_static_gate(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands: list[list[str]] = []
    monkeypatch.delenv("PYTEST_ADDOPTS", raising=False)
    monkeypatch.setattr(
        sys, "argv", ["tools/test.py", "--focused", "tests/test_router_probe.py"]
    )
    monkeypatch.setattr(
        runner,
        "_run",
        lambda command, **kwargs: commands.append(command) or 0,
    )
    monkeypatch.setattr(runner, "_default_shell", lambda: ["/bin/test-shell"])
    monkeypatch.setattr(runner, "_static_checks", lambda: 7)
    assert runner.main() == 7
    assert not any("pytest" in command for command in commands)


def test_runner_default_keeps_full_tests_directory_selection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands, shell_syntax = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py"])
    assert runner.main() == 0
    assert [command for command, _ in commands[:3]] == [
        [sys.executable, "tools/check.py"],
        ["git", "diff", "--check"],
        [sys.executable, "tools/package.py", "--check"],
    ]
    assert shell_syntax == [["/bin/test-shell"]]
    assert commands[-1][0][-1] == str(runner.ROOT / "tests")


def test_runner_explicit_tests_directory_retains_keyword_filter(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    tests = tmp_path / "tests"
    tests.mkdir()
    (tests / "test_sample.py").write_text("", encoding="utf-8")
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(
        sys, "argv", ["tools/test.py", "--focused", "tests", "-k", "sample"]
    )
    assert runner.main() == 0
    command = commands[-1][0]
    assert command[command.index("-k") : command.index("-k") + 2] == ["-k", "sample"]
    assert command[-1] == str(tests)


def test_runner_full_busybox_requires_storage_suite_before_checks(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    tests = tmp_path / "tests"
    tests.mkdir()
    (tests / "test_sample.py").write_text("", encoding="utf-8")
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--require-busybox"])
    assert runner.main() == 2
    assert commands == []
    assert "requires tests/test_storage.py" in capsys.readouterr().err


def test_runner_package_check_fails_before_static_checks_and_pytest(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    (tmp_path / "cfmgr.sh").write_text("entry fixture\n", encoding="utf-8")
    commands: list[list[str]] = []
    static_calls: list[list[str]] = []
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(sys, "argv", ["tools/test.py"])
    monkeypatch.delenv("PYTEST_ADDOPTS", raising=False)
    monkeypatch.setattr(runner, "_default_shell", lambda: ["/bin/test-shell"])

    def fake_run(command: list[str], **kwargs) -> int:
        commands.append(command)
        if command[1:] == ["tools/package.py", "--check"]:
            return 12
        return 0

    monkeypatch.setattr(runner, "_run", fake_run)
    monkeypatch.setattr(runner, "_static_checks", lambda: static_calls.append([]) or 0)
    assert runner.main() == 12
    assert commands == [
        [sys.executable, "tools/check.py"],
        ["git", "diff", "--check"],
        [sys.executable, "tools/package.py", "--check"],
    ]
    assert static_calls == []


def test_runner_passes_focused_path_and_keyword_to_pytest(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands, static_shells = _capture_runner(monkeypatch)
    monkeypatch.setenv("CFMGR_TEST_SHELL", "/bin/test-shell --posix")
    monkeypatch.setattr(
        sys,
        "argv",
        [
            "tools/test.py",
            "--focused",
            "tests/test_router_probe.py",
            "-k",
            "password_auth",
        ],
    )
    assert runner.main() == 0
    assert static_shells == [["/bin/test-shell", "--posix"]]
    pytest_command, pytest_env = commands[-1]
    assert pytest_command[:3] == [sys.executable, "-m", "pytest"]
    assert pytest_command[3:5] == ["-q", "-ra"]
    assert pytest_command[5:7] == ["--strict-config", "--strict-markers"]
    assert pytest_command[7:11] == [
        "--maxfail=1",
        "--durations=10",
        "-m",
        "not diagnostic",
    ]
    assert pytest_command[11:13] == ["-k", "password_auth"]
    assert pytest_command[-1] == str(runner.ROOT / "tests/test_router_probe.py")
    assert pytest_env is not None
    assert pytest_env["CFMGR_TEST_SHELL"] == "/bin/test-shell --posix"


def test_runner_bare_focused_keeps_tests_directory_selection(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--focused"])
    assert runner.main() == 0
    assert commands[-1][0][-1] == str(runner.ROOT / "tests")


@pytest.mark.parametrize("include_diagnostics", [False, True])
def test_runner_diagnostic_selection_is_explicit(
    monkeypatch: pytest.MonkeyPatch, capsys, include_diagnostics: bool
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    argv = ["tools/test.py"]
    if include_diagnostics:
        argv.append("--include-diagnostics")
    monkeypatch.setattr(sys, "argv", argv)

    assert runner.main() == 0
    command = commands[-1][0]
    output = capsys.readouterr().out
    if include_diagnostics:
        assert "--include-diagnostics" not in command
        assert "plus optional diagnostic cases" in output
    else:
        marker_index = command.index("-m", 3)
        assert command[marker_index : marker_index + 2] == [
            "-m",
            "not diagnostic",
        ]
        assert "optional diagnostic cases excluded" in output


def test_quick_selection_accepts_final_push_trailer_and_manual_nodes(
    tmp_path: Path,
) -> None:
    tests = tmp_path / "tests"
    tests.mkdir()
    (tests / "test_sample.py").write_text("", encoding="utf-8")
    nodes = (
        "tests/test_sample.py::test_sample "
        "tests/test_sample.py::test_parameterized[repair_case]"
    )
    assert runner.quick_selection(
        "push", f"diagnose failure\n\nCFMgr-Quick-Tests: {nodes}", root=tmp_path
    ) == nodes.split(" ")
    assert runner.quick_selection(
        "workflow_dispatch",
        "CFMgr-Quick-Tests: ignored-on-dispatch",
        nodes,
        root=tmp_path,
    ) == nodes.split(" ")


@pytest.mark.parametrize(
    "message",
    [
        "CFMgr-Quick-Tests:",
        "CFMgr-Quick-Tests: tests/test_sample.py::test_sample\nextra text",
        (
            "CFMgr-Quick-Tests: tests/test_sample.py::test_sample\n"
            "CFMgr-Quick-Tests: tests/test_sample.py::test_sample"
        ),
        "CFMgr-Quick-Tests: tests/test_sample.py::test_sample; echo unsafe",
        "CFMgr-Quick-Tests: tests/../test_sample.py::test_sample",
        "CFMgr-Quick-Tests: tests/test_missing.py::test_sample",
        "CFMgr-Quick-Tests: -k",
        (
            "CFMgr-Quick-Tests: tests/test_sample.py::test_sample\n"
            "CFMgr-Focused-Tests: tests/test_sample.py"
        ),
    ],
)
def test_quick_selection_rejects_malformed_or_conflicting_push_trailers(
    tmp_path: Path, message: str
) -> None:
    (tmp_path / "tests").mkdir()
    (tmp_path / "tests/test_sample.py").write_text("", encoding="utf-8")
    with pytest.raises(ValueError):
        runner.quick_selection("push", message, root=tmp_path)


def test_quick_selection_rejects_duplicate_and_symlink_modules(
    tmp_path: Path,
) -> None:
    tests = tmp_path / "tests"
    tests.mkdir()
    sample = tests / "test_sample.py"
    sample.write_text("", encoding="utf-8")
    with pytest.raises(ValueError, match="distinct"):
        runner.quick_selection(
            "workflow_dispatch",
            dispatch_nodes=(
                "tests/test_sample.py::test_sample tests/test_sample.py::test_sample"
            ),
            root=tmp_path,
        )
    link = tests / "test_link.py"
    link.symlink_to(sample)
    with pytest.raises(ValueError, match="regular file"):
        runner.quick_selection(
            "workflow_dispatch",
            dispatch_nodes="tests/test_link.py::test_sample",
            root=tmp_path,
        )


def test_quick_selection_rejects_empty_or_oversized_lists(
    tmp_path: Path,
) -> None:
    tests = tmp_path / "tests"
    tests.mkdir()
    paths = []
    for index in range(17):
        name = f"tests/test_case_{index}.py"
        (tmp_path / name).write_text("", encoding="utf-8")
        paths.append(name)
    with pytest.raises(ValueError):
        runner.quick_selection("workflow_dispatch", dispatch_nodes="", root=tmp_path)
    nodes = " ".join(f"{path}::test_case" for path in paths[:9])
    with pytest.raises(ValueError, match="1 to 8"):
        runner.quick_selection("workflow_dispatch", dispatch_nodes=nodes, root=tmp_path)


def test_runner_selects_full_busybox_suite_without_executing_it(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands, static_shells = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--require-busybox"])
    assert runner.main() == 0
    assert static_shells == [["busybox", "ash"]]
    assert commands[0][0] == ["busybox", "ash", "-c", ":"]
    pytest_command, pytest_env = commands[-1]
    assert pytest_command[:3] == [sys.executable, "-m", "pytest"]
    assert pytest_command[-1] == str(runner.ROOT / "tests")
    assert pytest_env is not None
    assert pytest_env["CFMGR_TEST_SHELL"] == "busybox ash"
    assert pytest_env["CFMGR_REQUIRE_BUSYBOX"] == "1"


def test_runner_reuses_common_checks_but_keeps_busybox_syntax_and_suite(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    commands: list[tuple[list[str], dict[str, str] | None]] = []
    common_checks: list[bool] = []

    def fake_run(command: list[str], *, env: dict[str, str] | None = None) -> int:
        commands.append((command, env))
        return 0

    monkeypatch.setattr(runner, "_run", fake_run)
    monkeypatch.setattr(
        runner, "_static_checks", lambda: common_checks.append(True) or 0
    )
    monkeypatch.setattr(
        sys, "argv", ["tools/test.py", "--require-busybox", "--reuse-static"]
    )
    monkeypatch.delenv("PYTEST_ADDOPTS", raising=False)

    assert runner.main() == 0
    assert common_checks == []
    assert commands[0][0] == ["busybox", "ash", "-c", ":"]
    syntax_commands = [
        command
        for command, _ in commands
        if command[:2] == ["busybox", "ash"]
        and len(command) == 4
        and command[2] == "-n"
    ]
    assert {Path(command[3]) for command in syntax_commands} == set(
        runner._shell_files()
    )
    pytest_command, pytest_env = commands[-1]
    assert pytest_command[-1] == str(runner.ROOT / "tests")
    assert "--durations=10" in pytest_command
    assert "not diagnostic" in pytest_command
    assert pytest_env is not None
    assert pytest_env["CFMGR_TEST_SHELL"] == "busybox ash"
    assert pytest_env["CFMGR_REQUIRE_BUSYBOX"] == "1"
    assert (
        "Reusing successful planning, package, Ruff, compile, ShellCheck and shfmt checks"
        in capsys.readouterr().out
    )


def test_runner_rejects_static_reuse_without_required_busybox(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--reuse-static"])

    assert runner.main() == 2
    assert commands == []
    assert "--reuse-static requires --require-busybox" in capsys.readouterr().err
