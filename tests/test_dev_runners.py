"""Focused behavior tests for the planning checker and developer test runner."""

from __future__ import annotations

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
    assert commands[-1][0][-1] == str(runner.ROOT / "tests/test_status.py")


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


@pytest.mark.parametrize(
    "stage", ["PREFLIGHT_RESULT", "BACKUP_RESULT", "MANAGER_RESULT", "STATUS_RESULT"]
)
@pytest.mark.parametrize(
    "result", ["success", "failure", "skipped", "cancelled", "missing"]
)
def test_required_core_aggregate_refuses_any_non_successful_stage(
    stage: str, result: str
) -> None:
    workflow = (runner.ROOT / ".github/workflows/checks.yml").read_text()
    aggregate = workflow.split("  checks:\n", 1)[1]
    script = textwrap.dedent(
        aggregate.split("python3 - <<'PY'\n", 1)[1].rsplit("          PY", 1)[0]
    )
    env = os.environ.copy()
    env.update(
        PREFLIGHT_RESULT="success",
        BACKUP_RESULT="success",
        MANAGER_RESULT="success",
        STATUS_RESULT="success",
    )
    if result == "missing":
        env.pop(stage)
    else:
        env[stage] = result
    completed = subprocess.run(
        [sys.executable, "-c", script], env=env, capture_output=True, check=False
    )
    assert completed.returncode == (0 if result == "success" else 1), completed.stderr


def test_core_calls_every_main_module_workflow_and_requires_its_result() -> None:
    workflow = (runner.ROOT / ".github/workflows/checks.yml").read_text()
    jobs = dict(
        re.findall(
            r"(?ms)^  ([a-z]+):\n(.*?)(?=^  [a-z]+:\n|\Z)",
            workflow.split("jobs:\n", 1)[1],
        )
    )
    owners = runner.CORE_OWNERS - {"tooling"}
    assert set(jobs) == owners | {"preflight", "checks"}
    for owner in owners:
        assert "    needs: preflight\n" in jobs[owner]
        assert f"    uses: ./.github/workflows/{owner}-checks.yml\n" in jobs[owner]
        assert "      reuse-preflight: true\n" in jobs[owner]
        assert f"${{{{ needs.{owner}.result }}}}" in jobs["checks"]
    assert "needs: [preflight, backup, manager, status]" in jobs["checks"]
    assert "if: ${{ always() }}" in jobs["checks"]
    assert "--core-batch tooling" not in workflow
    assert "tools-checks.yml" not in workflow


@pytest.mark.parametrize("owner", sorted(runner.CORE_OWNERS - {"tooling"}))
def test_main_module_sidebar_workflow_pins_its_batch_and_manual_preflight(
    owner: str,
) -> None:
    workflow = (runner.ROOT / f".github/workflows/{owner}-checks.yml").read_text()
    assert workflow.startswith(f"name: {owner.title()} Checks\n")
    assert "  workflow_dispatch:\n" in workflow
    assert "  workflow_call:\n" in workflow
    assert "        type: boolean\n        default: false\n" in workflow
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
    assert (
        "          reuse-preflight: ${{ inputs.reuse-preflight || false }}\n"
        in workflow
    )
    assert "concurrency:" not in workflow
    assert "  push:" not in workflow and "  pull_request:" not in workflow


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
