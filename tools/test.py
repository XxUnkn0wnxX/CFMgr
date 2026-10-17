#!/usr/bin/env python3
"""Run the local runtime suite and its lightweight static checks."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENV_BIN = ROOT / ".venv" / "bin"
QUICK_TRAILER = "CFMgr-Quick-Tests:"
QUICK_NODE = re.compile(
    r"tests/test_[A-Za-z0-9_]+\.py::test_[A-Za-z0-9_]+"
    r"(?:\[[A-Za-z0-9_.-]{1,64}\])?",
    re.ASCII,
)
QUICK_MODULE = re.compile(r"tests/test_[A-Za-z0-9_]+\.py", re.ASCII)
CORE_OWNERS = frozenset({"backup", "manager", "status", "tooling"})
# Product groups follow modules/*.sh. Manager owns bootstrap/config/shared
# infrastructure's primary consumers; every group runs to protect cross-consumers.
# Tooling contains optional manual contributor checks, not a product module. Keep each main
# module together until measured >10-minute work requires a diagnostic split.
CORE_BATCHES: dict[str, tuple[str, tuple[str, ...]]] = {
    "backup": (
        "backup",
        (
            "archive_capture",
            "archive_verify",
            "archive_tools",
            "archive_transaction",
            "archive_history",
            "archive_payload",
            "archive_payload_semantics",
            "archive_create",
            "archive_menu",
            "archive_yaml",
            "archive_history_runtime",
            "archive_control",
            "archive_format",
            "archive_io",
            "archive_writer",
            "backup_storage",
            "backup_menu",
            "archive_config",
            "archive_store",
        ),
    ),
    "manager": (
        "manager",
        (
            "config",
            "config_schema2",
            "config_store",
            "config_observation",
            "manager_settings",
            "manager_settings_entry",
            "execution_tasks",
            "dependency_selection",
            "native",
            "package",
            "acquire",
            "acquire_install",
            "install",
            "install_reporting",
            "retained_launch",
            "entry_package",
            "dependencies",
            "dependency_consumer",
            "dependency_reinstall",
            "storage",
            "storage_mounts",
            "mountinfo",
            "prerequisites",
            "mount_keeper",
        ),
    ),
    "status": ("status", ("status",)),
    "tooling": ("tooling", ("dev_runners", "platforms", "router_probe")),
}


def core_matrix(
    *,
    root: Path | None = None,
    batches: dict[str, tuple[str, tuple[str, ...]]] | None = None,
) -> dict[str, list[dict[str, str]]]:
    """Validate all test ownership; emit only required product batch rows."""
    root = ROOT if root is None else root
    batches = CORE_BATCHES if batches is None else batches
    tests = root / "tests"
    if tests.is_symlink() or not tests.is_dir():
        raise ValueError("core tests directory must be a regular directory")
    modules = root / "modules"
    if modules.is_symlink() or not modules.is_dir():
        raise ValueError("core modules directory must be a regular directory")
    main_modules = set()
    for path in modules.glob("*.sh"):
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"nonregular core runtime module: {path.name}")
        main_modules.add(path.stem)
    if main_modules != CORE_OWNERS - {"tooling"}:
        raise ValueError("core runtime modules must exactly match product test owners")
    assigned: set[str] = set()
    owners: set[str] = set()
    rows = []
    for key, (owner, names) in batches.items():
        if not re.fullmatch(r"[a-z][a-z0-9-]{0,47}", key) or owner not in CORE_OWNERS:
            raise ValueError(f"invalid core owner/batch: {owner}/{key}")
        if not names:
            raise ValueError(f"empty core batch: {key}")
        for name in names:
            if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
                raise ValueError(f"invalid core test module name: {name}")
            path = f"tests/test_{name}.py"
            if path in assigned:
                raise ValueError(f"overlapping core test module: {path}")
            candidate = root / path
            if candidate.is_symlink() or not candidate.is_file():
                raise ValueError(f"missing or nonregular core test module: {path}")
            assigned.add(path)
        owners.add(owner)
        if owner != "tooling":
            rows.append({"owner": owner, "batch": key})
    if owners != CORE_OWNERS:
        raise ValueError("test partition must include every test owner")
    discovered = {
        path.relative_to(root).as_posix() for path in tests.rglob("test_*.py")
    }
    if discovered != assigned:
        raise ValueError(
            "unassigned core test modules: " + ", ".join(sorted(discovered - assigned))
        )
    return {"include": rows}


def core_batch_targets(key: str) -> list[str]:
    core_matrix()
    if key not in CORE_BATCHES:
        raise ValueError(f"unknown core batch: {key}")
    return [f"tests/test_{name}.py" for name in CORE_BATCHES[key][1]]


def validate_focused_paths(paths: str, *, root: Path | None = None) -> list[str]:
    """Validate a space-separated list of existing root test modules."""
    root = ROOT if root is None else root
    if (
        not paths
        or re.fullmatch(
            r"tests/test_[A-Za-z0-9_]+\.py(?: tests/test_[A-Za-z0-9_]+\.py){0,15}",
            paths,
            re.ASCII,
        )
        is None
    ):
        raise ValueError("expected 1 to 16 space-separated tests/test_NAME.py paths")
    selected = paths.split(" ")
    if len(set(selected)) != len(selected):
        raise ValueError("focused test paths must be distinct")
    if (root / "tests").is_symlink():
        raise ValueError("tests directory must not be a symlink")
    for relative in selected:
        candidate = root / relative
        if candidate.is_symlink() or not candidate.is_file():
            raise ValueError(f"focused test path is not a regular file: {relative}")
    return selected


def validate_quick_nodes(nodes: str, *, root: Path | None = None) -> list[str]:
    """Validate bounded whole-module selectors or pytest node IDs."""
    root = ROOT if root is None else root
    if not nodes:
        raise ValueError("one to eight test modules or pytest node IDs are required")
    selected = nodes.split(" ")
    if len(selected) > 8:
        raise ValueError("expected 1 to 8 test modules or pytest node IDs")
    if len(set(selected)) != len(selected):
        raise ValueError("quick selection targets must be distinct")

    module_selection = all(QUICK_MODULE.fullmatch(item) for item in selected)
    node_selection = all(QUICK_NODE.fullmatch(item) for item in selected)
    if not module_selection and not node_selection:
        if any(QUICK_MODULE.fullmatch(item) for item in selected):
            raise ValueError(
                "whole-module selectors cannot be mixed with pytest node IDs"
            )
        raise ValueError(
            "expected 1 to 8 tests/test_NAME.py modules or "
            "tests/test_NAME.py::test_NAME node IDs"
        )

    if module_selection:
        validate_focused_paths(" ".join(selected), root=root)
        return selected

    for module in dict.fromkeys(node.split("::", 1)[0] for node in selected):
        validate_focused_paths(module, root=root)
    return selected


def quick_pytest_selection_args(selection: list[str]) -> list[str]:
    """Exclude optional diagnostics for whole-module selections, not named nodes."""
    if not selection:
        raise ValueError("quick pytest selection cannot be empty")
    module_selection = all(QUICK_MODULE.fullmatch(item) for item in selection)
    node_selection = all(QUICK_NODE.fullmatch(item) for item in selection)
    if module_selection:
        return ["-m", "not diagnostic", *selection]
    if node_selection:
        return list(selection)
    raise ValueError("quick pytest selection cannot mix modules and node IDs")


def quick_selection(
    event_name: str,
    commit_message: str = "",
    dispatch_nodes: str = "",
    *,
    root: Path | None = None,
) -> list[str]:
    """Read a quick-test trailer on push or explicit node input on dispatch."""
    root = ROOT if root is None else root
    if event_name == "workflow_dispatch":
        return validate_quick_nodes(dispatch_nodes, root=root)
    if event_name != "push":
        raise ValueError("Quick Checks supports push trailers and manual dispatch only")

    lines = commit_message.splitlines()
    marker = re.compile(r"^\s*CFMgr-Quick-Tests(?:\b|$)")
    focused_marker = re.compile(r"^\s*CFMgr-Focused-Tests(?:\b|$)")
    quick_lines = [
        (index, line) for index, line in enumerate(lines) if marker.match(line)
    ]
    if any(focused_marker.match(line) for line in lines):
        raise ValueError("quick and focused CI trailers cannot be combined")
    if len(quick_lines) != 1:
        raise ValueError("exactly one CFMgr-Quick-Tests trailer is required")

    index, line = quick_lines[0]
    nonempty = [position for position, value in enumerate(lines) if value.strip()]
    if not line.startswith(QUICK_TRAILER) or not nonempty or index != nonempty[-1]:
        raise ValueError("CFMgr-Quick-Tests must be the final nonempty trailer line")
    value = line[len(QUICK_TRAILER) :]
    if not value.startswith(" "):
        raise ValueError("CFMgr-Quick-Tests requires a space before its node IDs")
    try:
        return validate_quick_nodes(value[1:], root=root)
    except ValueError as error:
        raise ValueError(f"invalid CFMgr-Quick-Tests selection: {error}") from error


def validate_local_targets(
    targets: list[str], *, root: Path | None = None
) -> list[str]:
    """Validate local pytest files or directories confined to tests/."""
    root = ROOT if root is None else root
    tests_root = root / "tests"
    if tests_root.is_symlink() or not tests_root.is_dir():
        raise ValueError("tests directory must be a regular directory")
    if not targets or any(not target for target in targets):
        raise ValueError("focused selection cannot be empty")
    if len(set(targets)) != len(targets):
        raise ValueError("focused targets must be distinct")

    resolved_tests = tests_root.resolve()
    validated: list[str] = []
    for target in targets:
        relative = Path(target)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError(f"focused target must stay within tests/: {target}")
        candidate = root / relative
        current = root
        has_symlink_component = False
        for part in relative.parts:
            current = current / part
            if current.is_symlink():
                has_symlink_component = True
                break
        if has_symlink_component:
            raise ValueError(f"focused target cannot use symlinks: {target}")
        try:
            candidate.resolve().relative_to(resolved_tests)
        except (OSError, ValueError) as error:
            raise ValueError(
                f"focused target must stay within tests/: {target}"
            ) from error
        if candidate.is_file():
            if candidate.suffix != ".py" or not candidate.name.startswith("test_"):
                raise ValueError(f"focused file must be a test module: {target}")
        elif not candidate.is_dir():
            raise ValueError(
                f"focused target is not an existing test file/directory: {target}"
            )
        validated.append(relative.as_posix())
    return validated


def _tool(name: str) -> str | None:
    """Prefer the repository venv, then use the caller's PATH."""
    candidate = VENV_BIN / name
    if candidate.is_file() and os.access(candidate, os.X_OK):
        return str(candidate)
    return shutil.which(name)


def _files(directories: tuple[str, ...], suffixes: tuple[str, ...]) -> list[Path]:
    found: list[Path] = []
    for relative in directories:
        directory = ROOT / relative
        if not directory.is_dir():
            continue
        found.extend(
            path
            for path in directory.rglob("*")
            if path.is_file() and not path.is_symlink() and path.suffix in suffixes
        )
    return sorted(found)


def _run(command: list[str], *, env: dict[str, str] | None = None) -> int:
    print("+ " + shlex.join(command), flush=True)
    try:
        return subprocess.run(command, cwd=ROOT, env=env, check=False).returncode
    except OSError as error:
        print(f"ERROR: could not run {command[0]}: {error}", file=sys.stderr)
        return 2


def _require_tool(name: str) -> str:
    path = _tool(name)
    if path is None:
        print(
            f"ERROR: required tool '{name}' is missing; install pinned developer "
            "requirements and the documented system tools.",
            file=sys.stderr,
        )
        raise SystemExit(2)
    return path


def _shell_files() -> list[Path]:
    shell_files = _files(("modules", "tests", "tools"), (".sh",))
    if (ROOT / "cfmgr.sh").is_file():
        shell_files.append(ROOT / "cfmgr.sh")
    return shell_files


def _shell_syntax_checks(test_shell: list[str]) -> int:
    shell_files = _shell_files()
    for path in shell_files:
        code = _run([*test_shell, "-n", str(path)])
        if code:
            return code
    if not shell_files:
        print("SKIP shell syntax checks: no runtime shell files found.")
    return 0


def _shellcheck_checks(shell_files: list[Path]) -> int:
    if not shell_files:
        print("SKIP ShellCheck: no runtime shell files found.")
        return 0
    shellcheck = _require_tool("shellcheck")
    return _run([shellcheck, *map(str, shell_files)])


def _static_checks(*, skip_shellcheck: bool = False) -> int:
    python_files = _files(("modules", "tests", "tools"), (".py",))
    shell_files = _shell_files()

    ruff = _require_tool("ruff")
    if python_files:
        for command in (
            [ruff, "check", *map(str, python_files)],
            [ruff, "format", "--check", *map(str, python_files)],
            [sys.executable, "-m", "compileall", "-q", *map(str, python_files)],
        ):
            code = _run(command)
            if code:
                return code
    else:
        print("SKIP Python static checks: no runtime Python files found.")

    if shell_files:
        if not skip_shellcheck:
            code = _shellcheck_checks(shell_files)
            if code:
                return code
        shfmt = _require_tool("shfmt")
        code = _run([shfmt, "-d", *map(str, shell_files)])
        if code:
            return code
    else:
        print("SKIP ShellCheck/shfmt: no runtime shell files found.")
    return 0


def _default_shell() -> list[str]:
    if sys.platform == "darwin":
        bash = Path("/usr/local/bin/bash")
        if not bash.is_file() or not os.access(bash, os.X_OK):
            raise RuntimeError(
                "Homebrew bash is required for host shell tests on macOS at "
                "/usr/local/bin/bash; macOS /bin/sh is not used."
            )
        return [str(bash), "--posix"]
    if sys.platform.startswith("linux"):
        return ["/bin/sh"]
    raise RuntimeError(f"no approved host test shell for platform {sys.platform!r}")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run serial CFMgr tests and lightweight source checks."
    )
    parser.add_argument(
        "--core-matrix",
        action="store_true",
        help="print the validated required product owner/batch matrix as JSON only",
    )
    parser.add_argument(
        "--core-batch",
        metavar="KEY",
        help="run every module assigned to one fixed core batch, excluding diagnostics",
    )
    parser.add_argument(
        "--checks-only",
        action="store_true",
        help="run source checks and selected-shell syntax without pytest",
    )
    parser.add_argument(
        "--reuse-preflight",
        action="store_true",
        help="reuse successful common host/native preflight checks; requires --core-batch",
    )
    parser.add_argument(
        "--focused",
        nargs="*",
        metavar="PATH",
        help="run selected test paths (bare --focused selects tests/)",
    )
    parser.add_argument(
        "-k",
        "--keyword",
        metavar="EXPR",
        help="pass a pytest keyword expression",
    )
    parser.add_argument(
        "--require-busybox",
        action="store_true",
        help="require BusyBox ash and run the selected suite; missing proof fails",
    )
    parser.add_argument(
        "--reuse-static",
        action="store_true",
        help="reuse successful common checks from this job's host stage; requires --require-busybox",
    )
    shellcheck_mode = parser.add_mutually_exclusive_group()
    shellcheck_mode.add_argument(
        "--shellcheck-only",
        action="store_true",
        help="run pinned ShellCheck over all runtime shell files without other checks",
    )
    shellcheck_mode.add_argument(
        "--skip-shellcheck",
        action="store_true",
        help="skip ShellCheck while retaining all other local checks",
    )
    parser.add_argument(
        "--include-diagnostics",
        action="store_true",
        help="include optional diagnostic pytest cases normally excluded from the required suite",
    )
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    if args.core_matrix:
        if (
            args.core_batch is not None
            or args.checks_only
            or args.reuse_preflight
            or args.focused is not None
            or args.keyword
            or args.require_busybox
            or args.reuse_static
            or args.shellcheck_only
            or args.skip_shellcheck
            or args.include_diagnostics
        ):
            print(
                "ERROR: --core-matrix cannot be combined with other modes.",
                file=sys.stderr,
            )
            return 2
        try:
            print(json.dumps(core_matrix(), separators=(",", ":")))
        except ValueError as error:
            print(f"ERROR: invalid core partition: {error}", file=sys.stderr)
            return 2
        return 0

    if args.shellcheck_only:
        if (
            args.focused is not None
            or args.keyword
            or args.require_busybox
            or args.reuse_static
            or args.include_diagnostics
            or args.core_batch is not None
            or args.checks_only
            or args.reuse_preflight
        ):
            print(
                "ERROR: --shellcheck-only cannot be combined with test selection or other modes.",
                file=sys.stderr,
            )
            return 2
        return _shellcheck_checks(_shell_files())

    if sys.version_info < (3, 11):
        print("Python 3.11 or newer is required.", file=sys.stderr)
        return 2

    if args.reuse_static and not args.require_busybox:
        print("ERROR: --reuse-static requires --require-busybox.", file=sys.stderr)
        return 2

    if args.core_batch is not None and (
        args.focused is not None
        or args.keyword
        or args.include_diagnostics
        or args.checks_only
    ):
        print(
            "ERROR: --core-batch cannot be combined with partial selection, diagnostics or --checks-only.",
            file=sys.stderr,
        )
        return 2
    if args.checks_only and (
        args.focused is not None or args.keyword or args.include_diagnostics
    ):
        print(
            "ERROR: --checks-only cannot be combined with test selection.",
            file=sys.stderr,
        )
        return 2
    if args.reuse_preflight and (
        args.core_batch is None or args.reuse_static or args.skip_shellcheck
    ):
        print(
            "ERROR: --reuse-preflight requires --core-batch and cannot combine with other static reuse/skip options.",
            file=sys.stderr,
        )
        return 2

    if os.environ.get("PYTEST_ADDOPTS", "").strip():
        print(
            "ERROR: PYTEST_ADDOPTS must be empty; pass filters with this runner's "
            "--focused and -k options so suite selection stays visible.",
            file=sys.stderr,
        )
        return 2

    focused_paths: list[str] | None = None
    if args.core_batch is not None:
        try:
            focused_paths = core_batch_targets(args.core_batch)
        except ValueError as error:
            print(f"ERROR: invalid core selection: {error}", file=sys.stderr)
            return 2
    if args.focused is not None:
        try:
            focused_paths = validate_local_targets(args.focused) if args.focused else []
        except ValueError as error:
            print(f"ERROR: invalid focused selection: {error}", file=sys.stderr)
            return 2

    try:
        selected_shell = (
            ["busybox", "ash"]
            if args.require_busybox
            else shlex.split(os.environ.get("CFMGR_TEST_SHELL", "")) or _default_shell()
        )
    except (RuntimeError, ValueError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2

    full_suite = not focused_paths or (focused_paths == ["tests"] and not args.keyword)
    if args.require_busybox and full_suite and not args.checks_only:
        storage_tests = ROOT / "tests" / "test_storage.py"
        if storage_tests.is_symlink() or not storage_tests.is_file():
            print(
                "ERROR: full BusyBox proof requires tests/test_storage.py.",
                file=sys.stderr,
            )
            return 2

    env = os.environ.copy()
    env["CFMGR_TEST_SHELL"] = shlex.join(selected_shell)
    env["PYTEST_DISABLE_PLUGIN_AUTOLOAD"] = "1"
    if args.require_busybox:
        env["CFMGR_REQUIRE_BUSYBOX"] = "1"
        if _run([*selected_shell, "-c", ":"]) != 0:
            print("ERROR: BusyBox ash preflight failed.", file=sys.stderr)
            return 2
        print("Required shell evidence: BusyBox ash.")
    else:
        if args.core_batch is not None:
            env["CFMGR_REQUIRE_BUSYBOX"] = "0"
        else:
            env.setdefault("CFMGR_REQUIRE_BUSYBOX", "0")
        print(f"Host shell evidence: {env['CFMGR_TEST_SHELL']}.")
        print("Platform limit: BusyBox/Linux proof requires --require-busybox.")

    if args.reuse_preflight:
        print(
            "Reusing required common host/native preflight checks for this complete core batch."
        )
    elif args.reuse_static:
        print(
            "Reusing successful planning, package, Ruff, compile and shfmt checks "
            "from the earlier host stage; ShellCheck is a separate optional manual check."
        )
    else:
        for command in ([sys.executable, "tools/check.py"], ["git", "diff", "--check"]):
            code = _run(list(command))
            if code:
                return code

        if (ROOT / "cfmgr.sh").is_file():
            code = _run([sys.executable, "tools/package.py", "--check"])
            if code:
                return code

    if not args.reuse_preflight:
        code = _shell_syntax_checks(selected_shell)
        if code:
            return code
    if not args.reuse_static and not args.reuse_preflight:
        code = _static_checks(skip_shellcheck=args.skip_shellcheck)
        if code:
            return code

    if args.checks_only:
        return 0

    try:
        __import__("pytest")
    except ImportError:
        print(
            "ERROR: pytest is missing from this Python interpreter; install "
            "requirements-dev.txt in the active environment.",
            file=sys.stderr,
        )
        return 2
    test_targets = (
        [str(ROOT / path) for path in focused_paths]
        if focused_paths
        else [str(ROOT / "tests")]
    )
    command = [
        sys.executable,
        "-m",
        "pytest",
        "-vv" if args.core_batch is not None else "-q",
        "-ra",
        "--strict-config",
        "--strict-markers",
        "--maxfail=1",
        "--durations=0" if args.core_batch is not None else "--durations=10",
    ]
    if args.include_diagnostics:
        print("Pytest selection: required suite plus optional diagnostic cases.")
    else:
        print(
            "Pytest selection: required suite; optional diagnostic cases excluded "
            "(use --include-diagnostics to include them)."
        )
        command.extend(("-m", "not diagnostic"))
    if args.keyword:
        command.extend(("-k", args.keyword))
    command.extend(test_targets)
    return _run(command, env=env)


if __name__ == "__main__":
    raise SystemExit(main())
