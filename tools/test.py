#!/usr/bin/env python3
"""Run the local runtime suite and its lightweight static checks."""

from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VENV_BIN = ROOT / ".venv" / "bin"


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
        nargs="?",
        const="tests",
        metavar="PATH",
        help="run one test path (default: tests) instead of the full suite",
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
        help="require BusyBox ash and run the full suite; missing proof fails",
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

    if args.require_busybox and (args.focused is not None or args.keyword):
        print(
            "ERROR: --require-busybox runs the full suite; do not combine it with "
            "--focused or -k.",
            file=sys.stderr,
        )
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

    if args.require_busybox:
        storage_tests = ROOT / "tests" / "test_storage.py"
        if not storage_tests.is_file():
            print(
                "ERROR: BusyBox proof requires tests/test_storage.py.",
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
    test_target = str(ROOT / args.focused) if args.focused else str(ROOT / "tests")
    if not Path(test_target).exists():
        print(f"ERROR: test target does not exist: {test_target}", file=sys.stderr)
        return 2
    command = [
        sys.executable,
        "-m",
        "pytest",
        "-q",
        "-ra",
        "--strict-config",
        "--strict-markers",
    ]
    if args.keyword:
        command.extend(("-k", args.keyword))
    command.append(test_target)
    return _run(command, env=env)


if __name__ == "__main__":
    raise SystemExit(main())
