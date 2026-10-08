#!/usr/bin/env python3
"""Run reproducible developer checks from the local venv; never use router/provider state."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SH_SHEBANG = re.compile(rb"^#!\s*(?:\S*/sh|/usr/bin/env\s+sh)(?:\s|$)")


def shell_sources(root: Path) -> list[Path]:
    sources = []
    for folder, directories, filenames in os.walk(root):
        directories[:] = [
            name
            for name in directories
            if name
            not in {".git", ".venv", ".tmp", "tmp", "__pycache__", ".pytest_cache", ".ruff_cache"}
            and not (Path(folder) / name).is_symlink()
        ]
        for name in filenames:
            path = Path(folder) / name
            if path.is_symlink():
                continue
            with path.open("rb") as stream:
                first_line = stream.readline(256)
            if path.suffix == ".sh" or name.endswith(".sh.in") or SH_SHEBANG.match(first_line):
                sources.append(path)
    return sorted(sources)


def executable(value: str, label: str) -> str:
    resolved = shutil.which(value)
    if resolved is None:
        raise ValueError(f"required {label} executable is unavailable: {value}")
    return str(Path(resolved).resolve())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--busybox", help="require actual BusyBox shell/applet checks at PATH")
    parser.add_argument("--shellcheck", default="shellcheck")
    parser.add_argument("--shfmt", default=str(Path(sys.executable).parent / "shfmt"))
    parser.add_argument("--jobs", type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    if sys.version_info < (3, 11) or sys.prefix == sys.base_prefix:
        parser.error("run with Python >=3.11 from the development virtualenv")
    try:
        shellcheck = executable(args.shellcheck, "ShellCheck")
        shfmt = executable(args.shfmt, "shfmt")
        busybox = executable(args.busybox, "BusyBox") if args.busybox is not None else None
    except ValueError as error:
        parser.error(str(error))
    commands = [
        [sys.executable, "-m", "pip", "check"],
        [sys.executable, "-m", "ruff", "check", "tests", "tools"],
        [sys.executable, "-m", "ruff", "format", "--check", "tests", "tools"],
        [sys.executable, "-m", "compileall", "-q", "tests", "tools"],
        [shellcheck, "--version"],
        [shfmt, "--version"],
    ]
    sources = shell_sources(ROOT)
    for source in sources:
        commands.append(["/bin/sh", "-n", str(source)])
        if busybox:
            commands.append([busybox, "sh", "-n", str(source)])
    if sources:
        commands.extend(
            [
                [shellcheck, "--shell=sh", *map(str, sources)],
                [shfmt, "-ln", "posix", "-d", *map(str, sources)],
            ]
        )
    else:
        print("No .sh/.sh.in source files yet; shell source checks have no inputs.", flush=True)
    pytest = [sys.executable, "-m", "pytest"]
    if args.jobs == 2:
        pytest.extend(["-n", "2", "--dist=load", "--max-worker-restart=0"])
    if busybox:
        pytest.append(f"--busybox={busybox}")
    else:
        print("BusyBox unavailable/unselected: compatibility remains unverified.", flush=True)
    commands.append(pytest)
    for command in commands:
        print(f"+ {shlex_join(command)}", flush=True)
        try:
            # The full suite has no arbitrary aggregate cap: terminating pytest
            # externally can strand deliberately separate harness sessions.
            # Shell subjects have their own per-invocation deadlines and cleanup.
            timeout = None if command is pytest else 120
            completed = subprocess.run(command, cwd=ROOT, check=False, timeout=timeout)
        except (OSError, subprocess.TimeoutExpired) as error:
            print(f"check failed: {error}", file=sys.stderr)
            return 1
        if completed.returncode:
            return completed.returncode if completed.returncode > 0 else 1
    return 0


def shlex_join(command: list[str]) -> str:
    # Display only; never execute a joined shell command.
    import shlex

    return shlex.join(command)


if __name__ == "__main__":
    raise SystemExit(main())
