#!/usr/bin/env python3
"""Run the local runtime suite and its lightweight static checks."""

from __future__ import annotations

import argparse
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENV_BIN = ROOT / ".venv" / "bin"
FOCUSED_TRAILER = "CFMgr-Focused-Tests:"


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


def focused_selection(
    event_name: str, commit_message: str, *, root: Path | None = None
) -> tuple[str, list[str]]:
    """Return a validated workflow mode and selection from the push trailer."""
    if event_name != "push":
        return "full", []

    lines = commit_message.splitlines()
    trailer_lines = [
        (index, line)
        for index, line in enumerate(lines)
        if re.match(r"^\s*CFMgr-Focused-Tests(?:\b|$)", line)
    ]
    if not trailer_lines:
        return "full", []
    if len(trailer_lines) != 1:
        raise ValueError("exactly one CFMgr-Focused-Tests trailer is allowed")

    index, line = trailer_lines[0]
    nonempty = [position for position, value in enumerate(lines) if value.strip()]
    if not line.startswith(FOCUSED_TRAILER) or not nonempty or index != nonempty[-1]:
        raise ValueError("CFMgr-Focused-Tests must be the final nonempty trailer line")
    value = line[len(FOCUSED_TRAILER) :]
    if not value.startswith(" "):
        raise ValueError("CFMgr-Focused-Tests requires a space before its paths")
    value = value[1:]
    try:
        paths = validate_focused_paths(value, root=root)
    except ValueError as error:
        raise ValueError(f"invalid CFMgr-Focused-Tests selection: {error}") from error
    return "focused", paths


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


def _static_checks(test_shell: list[str]) -> int:
    python_files = _files(("modules", "tests", "tools"), (".py",))
    shell_files = _files(("modules", "tests", "tools"), (".sh",))
    if (ROOT / "cfmgr.sh").is_file():
        shell_files.append(ROOT / "cfmgr.sh")

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
        shellcheck = _require_tool("shellcheck")
        shfmt = _require_tool("shfmt")
        for path in shell_files:
            code = _run([*test_shell, "-n", str(path)])
            if code:
                return code
        for command in (
            [shellcheck, *map(str, shell_files)],
            [shfmt, "-d", *map(str, shell_files)],
        ):
            code = _run(command)
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
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    if sys.version_info < (3, 11):
        print("Python 3.11 or newer is required.", file=sys.stderr)
        return 2

    if os.environ.get("PYTEST_ADDOPTS", "").strip():
        print(
            "ERROR: PYTEST_ADDOPTS must be empty; pass filters with this runner's "
            "--focused and -k options so suite selection stays visible.",
            file=sys.stderr,
        )
        return 2

    focused_paths: list[str] | None = None
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
    if args.require_busybox and full_suite:
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
        env.setdefault("CFMGR_REQUIRE_BUSYBOX", "0")
        print(f"Host shell evidence: {env['CFMGR_TEST_SHELL']}.")
        print("Platform limit: BusyBox/Linux proof requires --require-busybox.")

    for command in ([sys.executable, "tools/check.py"], ["git", "diff", "--check"]):
        code = _run(list(command))
        if code:
            return code

    if (ROOT / "cfmgr.sh").is_file():
        code = _run([sys.executable, "tools/package.py", "--check"])
        if code:
            return code

    code = _static_checks(selected_shell)
    if code:
        return code

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
        "-q",
        "-ra",
        "--strict-config",
        "--strict-markers",
        "--maxfail=1",
    ]
    if args.keyword:
        command.extend(("-k", args.keyword))
    command.extend(test_targets)
    return _run(command, env=env)


if __name__ == "__main__":
    raise SystemExit(main())
