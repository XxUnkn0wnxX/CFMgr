"""Synthetic POSIX-shell fixtures. This is isolation by convention, not an OS sandbox.

Only trusted repository scripts belong here: absolute host paths, shell builtins,
network syscalls, and descendants that deliberately escape the process group are
not confined. PATH has no host commands unless a test explicitly supplies tools.
Group cleanup uses the session created for trusted fixture code; it is not an
absolute proof against PID/group-ID reuse after the leader has been reaped.
"""

from __future__ import annotations

import os
import selectors
import signal
import subprocess
import tempfile
import time
from collections.abc import Mapping, Sequence
from contextlib import suppress
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class ShellResult:
    argv: tuple[str, ...]
    returncode: int
    stdout: str
    stderr: str


class ShellFailure(RuntimeError):
    def __init__(self, message: str, result: ShellResult):
        super().__init__(message)
        self.result = result


class ShellTimeout(ShellFailure):
    """The subprocess exceeded its whole-action deadline."""


class OutputLimitExceeded(ShellFailure):
    """Combined stdout/stderr exceeded the capture budget."""


def matrix_ids(plan: Path) -> frozenset[str]:
    """Read canonical IDs, without duplicating the PLAN validation matrix."""
    section = plan.read_text(encoding="utf-8").split("## Validation matrix\n", 1)[1]
    section = section.split("\n## ", 1)[0]
    return frozenset(
        row.split("|")[1].strip() for row in section.splitlines() if row.startswith("| V")
    )


class RouterHarness:
    """Private fixture tree plus bounded, owned shell subprocesses on POSIX hosts."""

    FILE_LIMIT = 64 * 1024
    OUTPUT_LIMIT = 128 * 1024
    INPUT_LIMIT = 64 * 1024
    RESERVED_ENV = frozenset(
        {
            "PATH",
            "HOME",
            "TMPDIR",
            "ENV",
            "BASH_ENV",
            "SHELLOPTS",
            "BASHOPTS",
            "CFMGR_TEST_ROOT",
            "JFFS_ROOT",
            "OPT_ROOT",
            "RAM_ROOT",
        }
    )

    def __init__(self, root: Path, *, busybox: Path | None = None):
        self.root = root.resolve()
        self.busybox = busybox
        for relative in ("jffs", "opt", "ram/tmp", "home", "bin", "work"):
            self.path(relative).mkdir(parents=True, mode=0o700, exist_ok=True)
        self.root.chmod(0o700)

    def path(self, relative: str | Path) -> Path:
        """Reject absolute/traversing paths and symlink components for fixture I/O."""
        relative = Path(relative)
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("fixture path must be relative and cannot traverse parents")
        candidate = self.root / relative
        current = self.root
        for part in relative.parts:
            current /= part
            if current.is_symlink():
                raise ValueError("fixture path cannot traverse a symlink")
        return candidate

    def write(self, relative: str | Path, content: str, *, executable: bool = False) -> Path:
        data = content.encode("utf-8")
        if len(data) > self.FILE_LIMIT:
            raise ValueError("fixture file exceeds size budget")
        path = self.path(relative)
        path.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        path.write_bytes(data)
        path.chmod(0o700 if executable else 0o600)
        return path

    def read(self, relative: str | Path) -> str:
        with self.path(relative).open("rb") as stream:
            data = stream.read(self.FILE_LIMIT + 1)
        if len(data) > self.FILE_LIMIT:
            raise ValueError("fixture file exceeds size budget")
        return data.decode("utf-8")

    def fake_tool(self, name: str, body: str) -> Path:
        if not name or Path(name).name != name or name in {".", ".."}:
            raise ValueError("fake tool must be a single filename")
        return self.write(f"bin/{name}", "#!/bin/sh\nset -eu\n" + body, executable=True)

    def busybox_applets(self, *names: str) -> None:
        """Expose only explicitly requested applets from the selected real BusyBox."""
        if self.busybox is None:
            raise ValueError("BusyBox was not selected")
        for name in names:
            if not name or Path(name).name != name or name in {".", ".."}:
                raise ValueError("applet must be a single filename")
            self.path(f"bin/{name}").symlink_to(self.busybox)

    def environment(self, extra: Mapping[str, str] | None = None) -> dict[str, str]:
        environment = {
            "PATH": str(self.root / "bin"),
            "HOME": str(self.root / "home"),
            "TMPDIR": str(self.root / "ram/tmp"),
            "LC_ALL": "C",
            "TZ": "UTC",
            "CFMGR_TEST_ROOT": str(self.root),
            "JFFS_ROOT": str(self.root / "jffs"),
            "OPT_ROOT": str(self.root / "opt"),
            "RAM_ROOT": str(self.root / "ram"),
        }
        for key, value in (extra or {}).items():
            if key in self.RESERVED_ENV or not key or "=" in key or "\0" in key + value:
                raise ValueError(f"invalid or reserved environment key: {key!r}")
            environment[key] = value
        return environment

    def run(
        self,
        script: str,
        args: Sequence[str] = (),
        *,
        stdin: str = "",
        cwd: str = "work",
        env: Mapping[str, str] | None = None,
        timeout: float = 3.0,
        output_limit: int = OUTPUT_LIMIT,
    ) -> ShellResult:
        """Run a trusted synthetic script, reap its group even after normal exit.

        Input uses a private file rather than a pipe that could block the runner.
        Capture is bounded while the child runs, including inherited child pipes.
        """
        if not 0 < timeout <= 60 or not 0 < output_limit <= self.OUTPUT_LIMIT:
            raise ValueError("timeout/output limit must fit the harness budgets")
        data = stdin.encode("utf-8")
        if len(data) > self.INPUT_LIMIT:
            raise ValueError("stdin exceeds size budget")
        script_path = self.write("work/subject.sh", script)
        working_directory = self.path(cwd)
        if not working_directory.is_dir():
            raise ValueError("cwd must be an existing fixture directory")
        shell = [str(self.busybox), "sh"] if self.busybox else ["/bin/sh"]
        argv = [*shell, str(script_path), *args]
        output = {"stdout": bytearray(), "stderr": bytearray()}
        reason: type[ShellFailure] | None = None
        deadline = time.monotonic() + timeout
        with tempfile.TemporaryFile(dir=self.path("ram/tmp")) as input_file:
            input_file.write(data)
            input_file.seek(0)
            process = subprocess.Popen(
                argv,
                cwd=working_directory,
                env=self.environment(env),
                stdin=input_file,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                start_new_session=True,
            )
            try:
                with selectors.DefaultSelector() as selector:
                    assert process.stdout is not None and process.stderr is not None
                    for name, pipe in (("stdout", process.stdout), ("stderr", process.stderr)):
                        os.set_blocking(pipe.fileno(), False)
                        selector.register(pipe, selectors.EVENT_READ, name)
                    while selector.get_map():
                        remaining = deadline - time.monotonic()
                        if remaining <= 0:
                            reason = ShellTimeout
                            break
                        for key, _ in selector.select(min(0.05, remaining)):
                            chunk = os.read(key.fd, 8192)
                            if not chunk:
                                selector.unregister(key.fileobj)
                            else:
                                available = output_limit - sum(map(len, output.values()))
                                output[key.data].extend(chunk[:available])
                                if len(chunk) > available:
                                    reason = OutputLimitExceeded
                                    break
                        if reason is not None or process.poll() is not None:
                            break
                    if reason is None:
                        try:
                            process.wait(timeout=max(0.001, deadline - time.monotonic()))
                        except subprocess.TimeoutExpired:
                            reason = ShellTimeout
            finally:
                try:
                    self._stop_group(process)
                    # Read buffered bytes only; no waiting on descendants' open pipes.
                    for name, pipe in (("stdout", process.stdout), ("stderr", process.stderr)):
                        assert pipe is not None
                        while True:
                            try:
                                chunk = os.read(pipe.fileno(), 8192)
                            except BlockingIOError:
                                break
                            if not chunk:
                                break
                            available = output_limit - sum(map(len, output.values()))
                            output[name].extend(chunk[:available])
                            if len(chunk) > available and reason is None:
                                reason = OutputLimitExceeded
                            if len(chunk) > available:
                                break
                finally:
                    # A denied group signal must not leak pipe/input descriptors.
                    assert process.stdout is not None and process.stderr is not None
                    process.stdout.close()
                    process.stderr.close()
        result = ShellResult(
            tuple(argv),
            process.returncode,
            output["stdout"].decode("utf-8", errors="replace"),
            output["stderr"].decode("utf-8", errors="replace"),
        )
        if reason is not None:
            raise reason(reason.__doc__ or reason.__name__, result)
        return result

    @staticmethod
    def _stop_group(process: subprocess.Popen[bytes]) -> None:
        # The session/group was created for this invocation, never selected by name.
        try:
            for sig in (signal.SIGTERM, signal.SIGKILL):
                process.poll()
                try:
                    os.killpg(process.pid, sig)
                except ProcessLookupError:
                    # Once absent, never signal this potentially reusable PGID again.
                    break
                except PermissionError as denied:
                    # Darwin excludes zombies AND processes in the kernel's exit
                    # transition from killpg. EPERM can precede waitpid readiness.
                    # Independently reap within a short bound before retrying once.
                    try:
                        process.wait(timeout=0.1)
                    except subprocess.TimeoutExpired:
                        raise denied from None
                    try:
                        os.killpg(process.pid, sig)
                    except ProcessLookupError:
                        break
                    # Any persistent denial propagates, including live descendants.
                if sig == signal.SIGTERM:
                    time.sleep(0.05)
            process.wait(timeout=1)
        except OSError:
            # Best effort for our unreaped direct child if group cleanup is denied.
            # This cannot prove descendant cleanup; the original denial still fails.
            if process.returncode is None:
                with suppress(ProcessLookupError, PermissionError):
                    process.kill()
                with suppress(subprocess.TimeoutExpired):
                    process.wait(timeout=0.1)
            raise
