"""Focused behavior tests for the planning checker and developer test runner."""

from __future__ import annotations

import copy
import importlib.util
import io
import json
import os
import re
import subprocess
import sys
import textwrap
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

    def fake_static(*, skip_shellcheck: bool = False) -> int:
        del skip_shellcheck
        return 0

    def fake_syntax(shell: list[str]) -> int:
        static_shells.append(shell)
        return 0

    monkeypatch.setattr(runner, "_run", fake_run)
    monkeypatch.setattr(runner, "_static_checks", fake_static)
    monkeypatch.setattr(runner, "_shell_syntax_checks", fake_syntax)
    monkeypatch.setattr(runner, "_default_shell", lambda: ["/bin/test-shell"])
    monkeypatch.delenv("CFMGR_TEST_SHELL", raising=False)
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
    monkeypatch.setattr(runner, "_static_checks", lambda **kwargs: 7)
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


def test_quick_module_groups_exclude_diagnostics_but_named_nodes_do_not(
    tmp_path: Path,
) -> None:
    tests = tmp_path / "tests"
    tests.mkdir()
    (tests / "test_sample.py").write_text("", encoding="utf-8")
    (tests / "test_other.py").write_text("", encoding="utf-8")
    modules = "tests/test_sample.py tests/test_other.py"
    selected_modules = runner.quick_selection(
        "workflow_dispatch", dispatch_nodes=modules, root=tmp_path
    )
    assert selected_modules == modules.split(" ")
    assert runner.quick_pytest_selection_args(selected_modules) == [
        "-m",
        "not diagnostic",
        *modules.split(" "),
    ]
    assert (
        runner.quick_selection(
            "push", f"diagnose modules\n\nCFMgr-Quick-Tests: {modules}", root=tmp_path
        )
        == selected_modules
    )

    named_diagnostic = "tests/test_sample.py::test_thread_case"
    selected_node = runner.quick_selection(
        "workflow_dispatch", dispatch_nodes=named_diagnostic, root=tmp_path
    )
    assert runner.quick_pytest_selection_args(selected_node) == [named_diagnostic]
    with pytest.raises(ValueError, match="cannot be mixed"):
        runner.quick_selection(
            "workflow_dispatch",
            dispatch_nodes=f"{modules.split()[0]} {named_diagnostic}",
            root=tmp_path,
        )


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
        "CFMgr-Quick-Tests: tests/test_sample.py tests/test_sample.py::test_sample",
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
    modules = " ".join(paths[:9])
    with pytest.raises(ValueError, match="1 to 8"):
        runner.quick_selection(
            "workflow_dispatch", dispatch_nodes=modules, root=tmp_path
        )


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
    output = capsys.readouterr().out
    assert (
        "Reusing successful planning, package, Ruff, compile and shfmt checks" in output
    )
    assert "ShellCheck is a separate optional manual check" in output


def test_runner_rejects_static_reuse_without_required_busybox(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    commands, _ = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--reuse-static"])

    assert runner.main() == 2
    assert commands == []
    assert "--reuse-static requires --require-busybox" in capsys.readouterr().err


def test_shellcheck_only_uses_all_shell_files_and_propagates_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    for directory, filename in (
        ("modules", "module.sh"),
        ("tests", "test_fixture.sh"),
        ("tools", "runner.sh"),
    ):
        target = tmp_path / directory / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(":\n", encoding="utf-8")
    (tmp_path / "cfmgr.sh").write_text(":\n", encoding="utf-8")
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--shellcheck-only"])
    monkeypatch.setattr(runner, "_require_tool", lambda name: "/tools/shellcheck")
    commands: list[list[str]] = []

    def fail_shellcheck(command: list[str], **kwargs) -> int:
        del kwargs
        commands.append(command)
        return 17

    monkeypatch.setattr(runner, "_run", fail_shellcheck)
    monkeypatch.setattr(
        runner,
        "_shell_syntax_checks",
        lambda shell: pytest.fail("unexpected syntax checks"),
    )
    monkeypatch.setattr(
        runner,
        "_static_checks",
        lambda **kwargs: pytest.fail("unexpected static checks"),
    )

    shell_files = runner._shell_files()
    assert runner.main() == 17
    assert commands == [["/tools/shellcheck", *map(str, shell_files)]]
    assert len(shell_files) == 4


def test_static_checks_keep_shellcheck_by_default_and_skip_only_when_requested(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    python_files = [Path("tests/test_dev_runners.py")]
    shell_files = [Path("modules/example.sh"), Path("cfmgr.sh")]
    monkeypatch.setattr(
        runner,
        "_files",
        lambda directories, suffixes: python_files if suffixes == (".py",) else [],
    )
    monkeypatch.setattr(runner, "_shell_files", lambda: shell_files)
    monkeypatch.setattr(runner, "_require_tool", lambda name: f"/tools/{name}")
    commands: list[list[str]] = []

    def record(command: list[str], **kwargs) -> int:
        del kwargs
        commands.append(command)
        return 0

    monkeypatch.setattr(runner, "_run", record)
    assert runner._static_checks() == 0
    assert ["/tools/shellcheck", *map(str, shell_files)] in commands
    assert ["/tools/shfmt", "-d", *map(str, shell_files)] in commands

    commands.clear()
    assert runner._static_checks(skip_shellcheck=True) == 0
    assert not any(command[0] == "/tools/shellcheck" for command in commands)
    assert ["/tools/ruff", "check", *map(str, python_files)] in commands
    assert ["/tools/ruff", "format", "--check", *map(str, python_files)] in commands
    assert [
        sys.executable,
        "-m",
        "compileall",
        "-q",
        *map(str, python_files),
    ] in commands
    assert ["/tools/shfmt", "-d", *map(str, shell_files)] in commands


def make_core_test_tree(root: Path) -> None:
    (root / "tests").mkdir()
    (root / "modules").mkdir()
    for owner in runner.CORE_OWNERS - {"tooling"}:
        (root / "modules" / f"{owner}.sh").write_text("", encoding="utf-8")
    for _owner, names in runner.CORE_BATCHES.values():
        for name in names:
            (root / "tests" / f"test_{name}.py").write_text("", encoding="utf-8")


def test_core_partition_covers_every_module_once_and_every_owner() -> None:
    matrix = runner.core_matrix()
    assert {row["owner"] for row in matrix["include"]} == runner.CORE_OWNERS - {
        "tooling"
    }
    assigned = [
        path
        for batch in runner.CORE_BATCHES
        for path in runner.core_batch_targets(batch)
    ]
    assert len(assigned) == len(set(assigned))
    assert set(assigned) == {
        path.relative_to(runner.ROOT).as_posix()
        for path in (runner.ROOT / "tests").rglob("test_*.py")
    }


@pytest.mark.parametrize(
    ("defect", "expected"),
    [
        ("new-module", "unassigned"),
        ("missing-module", "missing or nonregular"),
        ("unknown-module", "missing or nonregular"),
        ("overlap", "overlapping"),
        ("unknown-owner", "invalid core owner"),
        ("missing-owner", "every test owner"),
        ("empty-batch", "empty core batch"),
        ("symlink-module", "missing or nonregular"),
        ("new-main-module", "exactly match product test owners"),
        ("missing-main-module", "exactly match product test owners"),
        ("symlink-main-module", "nonregular core runtime module"),
    ],
)
def test_core_partition_refuses_drift(
    tmp_path: Path, defect: str, expected: str
) -> None:
    make_core_test_tree(tmp_path)
    batches = dict(runner.CORE_BATCHES)
    if defect == "new-module":
        (tmp_path / "tests/test_new.py").write_text("", encoding="utf-8")
    elif defect == "missing-module":
        (tmp_path / "tests/test_archive_capture.py").unlink()
    elif defect == "unknown-module":
        batches["backup"] = ("backup", ("not_a_real_test",))
    elif defect == "overlap":
        batches["backup-extra"] = ("backup", ("archive_capture",))
    elif defect == "unknown-owner":
        batches["backup"] = ("unknown", ("archive_capture",))
    elif defect == "missing-owner":
        del batches["status"]
    elif defect == "empty-batch":
        batches["backup"] = ("backup", ())
    elif defect == "symlink-module":
        path = tmp_path / "tests/test_archive_capture.py"
        path.unlink()
        path.symlink_to(tmp_path / "tests/test_archive_verify.py")
    elif defect == "new-main-module":
        (tmp_path / "modules/ddns.sh").write_text("", encoding="utf-8")
    elif defect == "missing-main-module":
        (tmp_path / "modules/status.sh").unlink()
    elif defect == "symlink-main-module":
        path = tmp_path / "modules/status.sh"
        path.unlink()
        path.symlink_to(tmp_path / "modules/backup.sh")
    with pytest.raises(ValueError, match=expected):
        runner.core_matrix(root=tmp_path, batches=batches)


def test_core_matrix_prints_only_valid_json_without_running_checks(
    monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    commands, shells = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--core-matrix"])
    assert runner.main() == 0
    assert json.loads(capsys.readouterr().out) == runner.core_matrix()
    assert commands == shells == []


def test_core_matrix_drift_fails_without_emitting_a_partial_matrix(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys
) -> None:
    make_core_test_tree(tmp_path)
    (tmp_path / "tests/test_new.py").write_text("", encoding="utf-8")
    monkeypatch.setattr(runner, "ROOT", tmp_path)
    commands, shells = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--core-matrix"])
    assert runner.main() == 2
    output = capsys.readouterr()
    assert output.out == ""
    assert "unassigned core test modules: tests/test_new.py" in output.err
    assert commands == shells == []


def test_core_batch_without_reuse_keeps_common_checks_and_syntax(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    commands, shells = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", "--core-batch", "status"])
    assert runner.main() == 0
    assert shells == [["/bin/test-shell"]]
    assert [command for command, _ in commands[:3]] == [
        [sys.executable, "tools/check.py"],
        ["git", "diff", "--check"],
        [sys.executable, "tools/package.py", "--check"],
    ]
    assert commands[-1][0][-2:] == [
        str(runner.ROOT / "tests/test_status.py"),
        str(runner.ROOT / "tests/test_logging_native.py"),
    ]


@pytest.mark.parametrize("busybox", [False, True])
def test_core_batch_reuses_preflight_and_runs_complete_visible_selection(
    monkeypatch: pytest.MonkeyPatch, busybox: bool
) -> None:
    commands, shells = _capture_runner(monkeypatch)
    monkeypatch.setenv("CFMGR_REQUIRE_BUSYBOX", "1")
    monkeypatch.setattr(
        runner,
        "_static_checks",
        lambda **kwargs: pytest.fail("unexpected repeated common checks"),
    )
    argv = ["tools/test.py", "--core-batch", "backup", "--reuse-preflight"]
    if busybox:
        argv.append("--require-busybox")
    monkeypatch.setattr(sys, "argv", argv)
    assert runner.main() == 0
    assert shells == []
    assert len(commands) == (2 if busybox else 1)
    if busybox:
        assert commands[0][0] == ["busybox", "ash", "-c", ":"]
    command, env = commands[-1]
    assert "-vv" in command and "-q" not in command
    assert "--durations=0" in command
    targets = [str(runner.ROOT / path) for path in runner.core_batch_targets("backup")]
    assert command[-len(targets) :] == targets
    assert command[command.index("-m", 3) : command.index("-m", 3) + 2] == [
        "-m",
        "not diagnostic",
    ]
    assert env is not None
    assert env["CFMGR_REQUIRE_BUSYBOX"] == ("1" if busybox else "0")


@pytest.mark.parametrize(
    "argv",
    [
        ["--core-batch", "missing"],
        ["--core-batch", "status", "-k", "partial"],
        ["--core-batch", "status", "--focused", "tests/test_status.py"],
        ["--core-batch", "status", "--include-diagnostics"],
        ["--core-batch", "status", "--checks-only"],
        ["--reuse-preflight"],
        ["--require-busybox", "--reuse-preflight"],
        ["--core-batch", "status", "--reuse-preflight", "--skip-shellcheck"],
        [
            "--core-batch",
            "status",
            "--reuse-preflight",
            "--reuse-static",
            "--require-busybox",
        ],
        ["--checks-only", "--focused"],
        ["--checks-only", "-k", "partial"],
        ["--checks-only", "--include-diagnostics"],
        ["--core-matrix", "--core-batch", "status"],
        ["--core-matrix", "--checks-only"],
        ["--core-matrix", "--skip-shellcheck"],
        ["--shellcheck-only", "--checks-only"],
        ["--shellcheck-only", "--core-batch", "status"],
    ],
)
def test_core_runner_rejects_conflicting_or_partial_modes_before_execution(
    monkeypatch: pytest.MonkeyPatch, argv: list[str]
) -> None:
    commands, shells = _capture_runner(monkeypatch)
    monkeypatch.setattr(sys, "argv", ["tools/test.py", *argv])
    assert runner.main() == 2
    assert commands == shells == []


@pytest.mark.parametrize("busybox", [False, True])
def test_checks_only_proves_syntax_without_pytest(
    monkeypatch: pytest.MonkeyPatch, busybox: bool
) -> None:
    commands, shells = _capture_runner(monkeypatch)
    argv = ["tools/test.py", "--checks-only", "--skip-shellcheck"]
    if busybox:
        argv = ["tools/test.py", "--checks-only", "--require-busybox", "--reuse-static"]
    monkeypatch.setattr(sys, "argv", argv)
    assert runner.main() == 0
    assert shells == [["busybox", "ash"] if busybox else ["/bin/test-shell"]]
    assert not any("pytest" in command for command, _ in commands)
    if busybox:
        assert [command for command, _ in commands] == [["busybox", "ash", "-c", ":"]]
    else:
        assert [sys.executable, "tools/check.py"] in [
            command for command, _ in commands
        ]


@pytest.mark.parametrize("stage", ["PREFLIGHT_RESULT", "DISPATCH_RESULT"])
@pytest.mark.parametrize("event", ["push", "pull_request"])
@pytest.mark.parametrize(
    "result", ["success", "failure", "skipped", "cancelled", "missing"]
)
def test_required_core_aggregate_refuses_any_non_successful_stage(
    stage: str, result: str, event: str
) -> None:
    workflow = (runner.ROOT / ".github/workflows/checks.yml").read_text()
    aggregate = workflow.split("  checks:\n", 1)[1]
    script = textwrap.dedent(
        aggregate.split("python3 - <<'PY'\n", 1)[1].split("          PY", 1)[0]
    )
    env = os.environ.copy()
    env.update(
        PREFLIGHT_RESULT="success",
        DISPATCH_RESULT="skipped" if event == "pull_request" else "success",
        GITHUB_EVENT_NAME=event,
    )
    if result == "missing":
        env.pop(stage)
    else:
        env[stage] = result
    completed = subprocess.run(
        [sys.executable, "-c", script], env=env, capture_output=True, check=False
    )
    expected = (
        "skipped"
        if stage == "DISPATCH_RESULT" and event == "pull_request"
        else "success"
    )
    assert completed.returncode == (0 if result == expected else 1), completed.stderr


def test_core_calls_every_main_module_workflow_and_requires_its_result() -> None:
    workflow = (runner.ROOT / ".github/workflows/checks.yml").read_text()
    jobs = dict(
        re.findall(
            r"(?ms)^  ([a-z-]+):\n(.*?)(?=^  [a-z-]+:\n|\Z)",
            workflow.split("jobs:\n", 1)[1],
        )
    )
    assert set(jobs) == {"preflight", "dispatch", "checks", "cancel-children"}
    assert 'owners = ("backup", "manager", "status")' in jobs["dispatch"]
    assert "needs: [preflight, dispatch]" in jobs["checks"]
    assert "if: ${{ !cancelled() }}" in jobs["checks"]
    assert (
        "actions: read" in jobs["checks"]
        and "collect_module_checks.py" in jobs["checks"]
    )
    for name in ("dispatch", "cancel-children"):
        assert "actions: write" in jobs[name]
        assert "actions/checkout" not in jobs[name]
        assert (
            "github.event_name == 'push' || github.event_name == 'workflow_dispatch'"
            in jobs[name]
        )
        assert "github.ref == 'refs/heads/develop'" in jobs[name]
    assert "workflow_run:" not in workflow and "pull_request_target:" not in workflow
    assert "--core-batch tooling" not in workflow
    assert "tools-checks.yml" not in workflow


@pytest.mark.parametrize("owner", sorted(runner.CORE_OWNERS - {"tooling"}))
def test_main_module_sidebar_workflow_pins_its_batch_and_manual_preflight(
    owner: str,
) -> None:
    workflow = (runner.ROOT / f".github/workflows/{owner}-checks.yml").read_text()
    assert workflow.startswith(f"name: {owner.title()} Checks\n")
    assert "  workflow_dispatch:\n" in workflow
    assert "  workflow_call:\n" not in workflow
    assert "  pull_request:\n    branches: [develop]\n" in workflow
    assert "      candidate_sha:\n" in workflow
    assert "          ref: ${{ github.sha }}\n" in workflow
    assert "    timeout-minutes: 10\n" in workflow
    assert (
        f"    name: {owner.title()} Checks (${{{{ matrix.platform }}}})\n" in workflow
    )
    assert "      fail-fast: false\n" in workflow
    assert "      max-parallel: 2\n" in workflow
    assert "        platform: [host, busybox]\n" in workflow
    assert "continue-on-error:" not in workflow
    assert "uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1" in workflow
    assert "          persist-credentials: false\n" in workflow
    assert "        uses: ./.github/actions/module-checks\n" in workflow
    assert f"          batch: {owner}\n" in workflow
    assert "          platform: ${{ matrix.platform }}\n" in workflow
    assert "          reuse-preflight: false\n" in workflow
    assert (
        "concurrency:" in workflow
        and "pr-{0}" in workflow
        and "orchestrated-{0}" in workflow
        and "manual-{0}" in workflow
    )
    assert "  push:" not in workflow
    assert (
        "Validate exact candidate" in workflow
        and "Verify checked out candidate" in workflow
    )
    assert "'docs/**'" in workflow and "'**/*.md'" in workflow


@pytest.mark.parametrize(
    ("filename", "display"),
    [
        ("quick-checks.yml", "Dev Checks"),
        ("lint.yml", "Lint Checks"),
        ("diagnostics.yml", "Diagnostics Checks"),
        ("tools-checks.yml", "Tools Checks"),
    ],
)
def test_optional_sidebar_workflows_keep_manual_dispatch_only(
    filename: str, display: str
) -> None:
    workflow = (runner.ROOT / ".github/workflows" / filename).read_text()
    assert workflow.startswith(f"name: {display}\n")
    assert "  workflow_dispatch:\n" in workflow
    assert "  push:" not in workflow and "  pull_request:" not in workflow


def test_tools_workflow_runs_complete_optional_batch_with_its_own_preflight() -> None:
    workflow = (runner.ROOT / ".github/workflows/tools-checks.yml").read_text()
    assert "  workflow_call:" not in workflow
    assert "    timeout-minutes: 10\n" in workflow
    assert "        uses: ./.github/actions/module-checks\n" in workflow
    assert "          batch: tooling\n" in workflow
    assert "          reuse-preflight: false\n" in workflow
    assert "          platform:" not in workflow
    action = (runner.ROOT / ".github/actions/module-checks/action.yml").read_text()
    assert "    default: 'both'\n" in action.split("  platform:\n", 1)[1]
    assert runner.core_batch_targets("tooling") == [
        "tests/test_dev_runners.py",
        "tests/test_platforms.py",
        "tests/test_router_probe.py",
    ]


@pytest.mark.parametrize(
    ("platform", "expected"),
    [("host", 0), ("busybox", 0), ("both", 0), ("all", 2), ("", 2), ("host;false", 2)],
)
def test_module_action_rejects_nonfixed_platforms_before_setup(
    platform: str, expected: int
) -> None:
    action = (runner.ROOT / ".github/actions/module-checks/action.yml").read_text()
    validation = textwrap.dedent(
        action.split("      run: |\n", 1)[1].split("\n    - name:", 1)[0]
    )
    env = os.environ.copy()
    env.update(
        CFMGR_CORE_BATCH="backup",
        CFMGR_REUSE_PREFLIGHT="false",
        CFMGR_TEST_PLATFORM=platform,
    )
    completed = subprocess.run(
        ["/bin/bash", "-c", validation], env=env, capture_output=True, check=False
    )
    assert completed.returncode == expected, completed.stderr


def test_module_action_preserves_complete_platform_tests_and_preflight_guards() -> None:
    action = (runner.ROOT / ".github/actions/module-checks/action.yml").read_text()
    native_setup = action.split(
        "    - name: Prepare verified native vendor BusyBox\n", 1
    )[1].split("\n    - name:", 1)[0]
    assert "if: ${{ inputs.platform != 'host' }}" in native_setup
    common = action.split(
        "    - name: Run common checks and selected shell syntax\n", 1
    )[1].split("\n    - name:", 1)[0]
    assert "if: ${{ inputs.reuse-preflight != 'true' }}" in common
    assert "test_args=(--checks-only --skip-shellcheck)" in common
    assert 'if [[ "$CFMGR_TEST_PLATFORM" == busybox ]]; then' in common
    assert "test_args+=(--require-busybox)" in common
    syntax = action.split("    - name: Run mandatory BusyBox syntax\n", 1)[1].split(
        "\n    - name:", 1
    )[0]
    assert "inputs.reuse-preflight != 'true' && inputs.platform == 'both'" in syntax
    host = action.split("    - name: Run complete assigned host batch\n", 1)[1].split(
        "\n    - name:", 1
    )[0]
    assert "if: ${{ inputs.platform != 'busybox' }}" in host
    assert 'tools/test.py --core-batch "$CFMGR_CORE_BATCH" --reuse-preflight' in host
    native = action.split("    - name: Run complete assigned BusyBox batch\n", 1)[1]
    assert "!cancelled() && inputs.platform != 'host'" in native
    assert (
        "steps.tools.outcome == 'success' && steps.busybox.outcome == 'success'"
        in native
    )
    assert "inputs.reuse-preflight == 'true'" in native
    assert "steps.common.outcome == 'success'" in native
    assert (
        "inputs.platform == 'busybox' || steps.native_syntax.outcome == 'success'"
        in native
    )
    assert (
        'tools/test.py --core-batch "$CFMGR_CORE_BATCH" --require-busybox --reuse-preflight'
        in native
    )
    assert "continue-on-error:" not in action


@pytest.fixture
def module_collection():
    spec = importlib.util.spec_from_file_location(
        "collect_module_checks", runner.ROOT / ".github/collect_module_checks.py"
    )
    collector = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(collector)
    repository, sha, parent = "example/CFMgr", "a" * 40, "123"
    runs, jobs = {}, {}
    mapping = {}
    for index, owner in enumerate(collector.OWNERS, 1):
        run_id = 100 + index
        mapping[owner] = {"id": run_id, "attempt": 1}
        runs[run_id] = {
            "id": run_id,
            "repository": {"full_name": repository},
            "workflow_id": index,
            "path": f".github/workflows/{owner}-checks.yml",
            "event": "workflow_dispatch",
            "display_title": collector.title(owner, sha, parent=parent),
            "head_sha": sha,
            "run_attempt": 1,
            "status": "completed",
            "conclusion": "success",
        }
        jobs[run_id] = {
            "total_count": 2,
            "jobs": [
                {
                    "name": f"{owner.title()} Checks ({platform})",
                    "run_id": run_id,
                    "status": "completed",
                    "conclusion": "success",
                    "steps": [
                        {
                            "name": name,
                            "number": number,
                            "status": "completed",
                            "conclusion": "success",
                        }
                        for number, name in enumerate(
                            (
                                "Validate exact candidate",
                                "Check out source",
                                "Verify checked out candidate",
                                f"Run complete {owner} checks",
                            ),
                            1,
                        )
                    ],
                }
                for platform in ("host", "busybox")
            ],
        }

    class FakeAPI:
        def __init__(self):
            self.calls = []
            self.elapsed = 0
            self.hook = lambda path: None

        def get(self, path):
            self.calls.append(path)
            self.hook(path)
            workflow = re.fullmatch(
                r"/actions/workflows/(backup|manager|status)-checks.yml", path
            )
            if workflow:
                owner = workflow[1]
                return {
                    "id": collector.OWNERS.index(owner) + 1,
                    "path": f".github/workflows/{owner}-checks.yml",
                }
            if "/workflows/" in path:
                owner = path.split("/workflows/", 1)[1].split("-checks.yml", 1)[0]
                return {
                    "workflow_runs": [
                        copy.deepcopy(run)
                        for run in runs.values()
                        if run["workflow_id"] == collector.OWNERS.index(owner) + 1
                    ]
                }
            run_id = int(path.split("/runs/", 1)[1].split("/", 1)[0])
            return copy.deepcopy(jobs[run_id] if "/jobs?" in path else runs[run_id])

        def collect(self, *, pr=False):
            return collector.collect(
                self,
                repository,
                sha,
                "pull_request" if pr else "push",
                parent,
                "7" if pr else None,
                {} if pr else mapping,
                clock=lambda: self.elapsed,
                sleep=self.advance,
            )

        def advance(self, seconds):
            assert 0 < seconds <= 15
            self.elapsed += seconds

    return collector, FakeAPI(), runs, jobs, mapping


@pytest.mark.parametrize("pr", [False, True])
def test_module_collector_accepts_exact_success_and_pr_merge_title_without_head_equivalence(
    module_collection, pr
):
    collector, api, runs, _jobs, mapping = module_collection
    for owner, selected in mapping.items():
        run = runs[selected["id"]]
        run["path"] += "@refs/heads/develop"
        if pr:
            run.update(
                event="pull_request",
                head_sha="b" * 40,
                display_title=collector.title(owner, "a" * 40, pr="7"),
            )
    assert api.collect(pr=pr) == {
        owner: selected["id"] for owner, selected in mapping.items()
    }


@pytest.mark.parametrize(
    "defect",
    [
        "sha",
        "path",
        "repo",
        "workflow-id",
        "title",
        "event",
        "run-id",
        "attempt",
        "job-id",
        "missing-job",
        "duplicate-job",
        "missing-step",
        "skipped-step",
        "failed-job",
        "cancelled-run",
        "changed-attempt",
    ],
)
def test_module_collector_rejects_mismatched_or_nonpassing_evidence(
    module_collection, defect
):
    collector, api, runs, jobs, _mapping = module_collection
    run = runs[101]
    if defect in {"sha", "path", "workflow-id", "title", "event", "run-id", "attempt"}:
        key, value = {
            "sha": ("head_sha", "b" * 40),
            "path": ("path", ".github/workflows/foreign.yml@main"),
            "workflow-id": ("workflow_id", 99),
            "title": ("display_title", "unrelated"),
            "event": ("event", "push"),
            "run-id": ("id", 999),
            "attempt": ("run_attempt", 2),
        }[defect]
        run[key] = value
    elif defect == "repo":
        run["repository"]["full_name"] = "other/CFMgr"
    elif defect == "job-id":
        jobs[101]["jobs"][0]["run_id"] = 999
    elif defect == "missing-job":
        jobs[101]["jobs"].pop()
    elif defect == "duplicate-job":
        jobs[101]["jobs"][1] = copy.deepcopy(jobs[101]["jobs"][0])
    elif defect == "missing-step":
        jobs[101]["jobs"][0]["steps"].pop()
    elif defect == "skipped-step":
        jobs[101]["jobs"][0]["steps"][-1]["conclusion"] = "skipped"
    elif defect == "failed-job":
        jobs[101]["jobs"][0]["conclusion"] = "failure"
    elif defect == "cancelled-run":
        run["conclusion"] = "cancelled"
    else:
        api.hook = lambda path: run.update(run_attempt=2) if "/jobs?" in path else None
    with pytest.raises(collector.CollectionError):
        api.collect()


def test_module_collector_waits_for_requested_rerun_attempt_and_has_finite_polling(
    module_collection,
):
    collector, api, _runs, _jobs, mapping = module_collection
    mapping["backup"]["attempt"] = 2
    with pytest.raises(collector.CollectionError, match="15 minutes"):
        api.collect()
    assert api.elapsed == 900
    assert not any("/runs/101/attempts/" in call for call in api.calls)


def test_module_collector_drops_prior_success_when_new_pr_run_is_pending(
    module_collection,
):
    collector, api, runs, _jobs, mapping = module_collection
    for owner, selected in mapping.items():
        runs[selected["id"]].update(
            event="pull_request", display_title=collector.title(owner, "a" * 40, pr="7")
        )
    runs[102]["status"] = "queued"

    def advance(seconds):
        api.elapsed += seconds
        runs[201] = dict(runs[101], id=201, status="queued")
        runs[102]["status"] = "completed"

    api.advance = advance
    with pytest.raises(collector.CollectionError, match="15 minutes"):
        api.collect(pr=True)


def dispatch_script():
    workflow = (runner.ROOT / ".github/workflows/checks.yml").read_text()
    return textwrap.dedent(
        workflow.split("      - name: Dispatch exact independent runs\n", 1)[1]
        .split("python3 - <<'PY'\n", 1)[1]
        .split("          PY", 1)[0]
    )


def run_inline_dispatch():
    exec(dispatch_script(), {})  # noqa: S102 - Execute the fixed workflow script with its API mocked.


@pytest.fixture
def dispatch_api(monkeypatch, tmp_path):
    import signal
    import urllib.request

    repo, sha = "example/CFMgr", "a" * 40
    for key, value in {
        "GITHUB_REPOSITORY": repo,
        "GITHUB_SHA": sha,
        "GITHUB_RUN_ID": "123",
        "GITHUB_RUN_ATTEMPT": "1",
        "GITHUB_EVENT_NAME": "push",
        "GITHUB_REF": "refs/heads/develop",
        "GH_TOKEN": "synthetic",
        "GITHUB_OUTPUT": str(tmp_path / "output"),
        "GITHUB_STEP_SUMMARY": str(tmp_path / "summary"),
    }.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(signal, "signal", lambda *args: None)
    calls = []
    state = {"current": sha, "prior": False, "fail": None}

    class Response(io.BytesIO):
        status = 200

    class Opener:
        def open(self, request, timeout):
            assert timeout == 20
            path = request.full_url.split(f"/repos/{repo}", 1)[1]
            calls.append(
                (
                    request.method,
                    path,
                    json.loads(request.data) if request.data else None,
                )
            )
            if path == "/git/ref/heads/develop":
                data = {"object": {"sha": state["current"]}}
            else:
                owner = next(
                    (
                        owner
                        for owner in ("backup", "manager", "status")
                        if f"/{owner}-checks.yml" in path
                    ),
                    "backup",
                )
                index = ("backup", "manager", "status").index(owner) + 1
                if path.endswith("/dispatches"):
                    if state["fail"] == owner:
                        raise OSError("synthetic dispatch failure")
                    data = {
                        "workflow_run_id": 100 + index,
                        "run_url": f"https://api.github.com/repos/{repo}/actions/runs/{100 + index}",
                        "html_url": f"https://github.com/{repo}/actions/runs/{100 + index}",
                    }
                    if state.get("invalid") == "id":
                        data["workflow_run_id"] = True
                    elif state.get("invalid") == "url":
                        data["run_url"] = "https://example.invalid/run"
                    elif state.get("invalid") == "status":
                        response = Response(json.dumps(data).encode())
                        response.status = 204
                        return response
                elif "/runs?" in path:
                    data = {
                        "workflow_runs": [
                            {
                                "id": 100 + index,
                                "run_attempt": 1,
                                "status": "completed",
                                "repository": {"full_name": repo},
                                "path": f".github/workflows/{owner}-checks.yml@develop",
                                "workflow_id": index,
                                "event": "workflow_dispatch",
                                "head_sha": sha,
                                "display_title": f"{owner.title()} Checks parent=123 sha={sha}",
                            }
                        ]
                        if state["prior"]
                        else []
                    }
                elif request.method == "POST":
                    response = Response(b"")
                    response.status = 202
                    return response
                else:
                    data = {
                        "id": index,
                        "path": f".github/workflows/{owner}-checks.yml",
                        "state": "active",
                    }
            return Response(json.dumps(data).encode())

    monkeypatch.setattr(urllib.request, "build_opener", lambda *args: Opener())
    return calls, state, tmp_path


def test_inline_dispatch_uses_returned_ids_and_cleans_partial_failure(dispatch_api):
    calls, state, directory = dispatch_api
    run_inline_dispatch()
    mapping = json.loads((directory / "output").read_text().split("=", 1)[1])
    assert mapping == {
        owner: {"id": 101 + index, "attempt": 1}
        for index, owner in enumerate(("backup", "manager", "status"))
    }
    assert not any("/runs?" in path for _, path, _ in calls)
    assert all(
        body["inputs"]["candidate_sha"] == "a" * 40
        for _, path, body in calls
        if path.endswith("/dispatches")
    )
    calls.clear()
    state["fail"] = "status"
    with pytest.raises(OSError):
        run_inline_dispatch()
    assert [
        path
        for method, path, _ in calls
        if method == "POST" and path.endswith("/cancel")
    ] == ["/actions/runs/101/cancel", "/actions/runs/102/cancel"]


def test_inline_dispatch_reruns_exact_prior_ids_for_advanced_ref(
    dispatch_api, monkeypatch
):
    calls, state, directory = dispatch_api
    state.update(current="b" * 40, prior=True)
    monkeypatch.setenv("GITHUB_RUN_ATTEMPT", "2")
    run_inline_dispatch()
    assert [path for method, path, _ in calls if method == "POST"] == [
        f"/actions/runs/{run_id}/rerun" for run_id in (101, 102, 103)
    ]
    mapping = json.loads((directory / "output").read_text().split("=", 1)[1])
    assert all(run["attempt"] == 2 for run in mapping.values())
    calls.clear()
    state["prior"] = False
    with pytest.raises(RuntimeError, match="missing exact child"):
        run_inline_dispatch()
    assert not any(method == "POST" for method, _, _ in calls)


def test_inline_dispatch_rejects_fork_pr_before_any_api_call(dispatch_api, monkeypatch):
    calls, _state, _directory = dispatch_api
    monkeypatch.setenv("GITHUB_EVENT_NAME", "pull_request")
    monkeypatch.setenv("GITHUB_REF", "refs/pull/7/merge")
    with pytest.raises(SystemExit, match="trusted develop"):
        run_inline_dispatch()
    assert calls == []


@pytest.mark.parametrize("invalid", ["id", "url", "status"])
def test_inline_dispatch_requires_documented_exact_run_receipt(dispatch_api, invalid):
    calls, state, _directory = dispatch_api
    state["invalid"] = invalid
    with pytest.raises(RuntimeError):
        run_inline_dispatch()
    if invalid != "url":
        assert not any(path.endswith("/cancel") for _, path, _ in calls)


@pytest.mark.parametrize("candidate", ["", "a" * 40, "b" * 40])
def test_module_candidate_input_matches_event_before_checkout(candidate):
    workflow = (runner.ROOT / ".github/workflows/backup-checks.yml").read_text()
    script = textwrap.dedent(
        workflow.split("python3 - <<'PY'\n", 1)[1].split("          PY", 1)[0]
    )
    env = dict(
        os.environ, GITHUB_SHA="a" * 40, CFMGR_CANDIDATE=candidate, CFMGR_PARENT="123"
    )
    completed = subprocess.run(
        [sys.executable, "-c", script], env=env, capture_output=True, check=False
    )
    assert completed.returncode == (1 if candidate == "b" * 40 else 0), completed.stderr
