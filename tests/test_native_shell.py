"""Fixed native shell launch contracts using an inert chroot stand-in."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
IO = ROOT / "modules/lib/io.sh"
NATIVE_CONFIG = ROOT / "modules/lib/native_config.sh"
ISOLATION = ROOT / "modules/lib/isolation.sh"
SOURCE = ROOT / "modules/lib/native_exec.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


class NativeShellFixture:
    """A source-only owner context with a host-side, inert chroot witness."""

    def __init__(
        self, router: RouterHarness, mode: str = "success", *, busybox: Path | None = None
    ) -> None:
        self.router = router
        self.guard = router.path("ram/tmp/native-shell-guard")
        self.guard.mkdir(mode=0o700)
        self.execution = self.guard / "execution"
        self.execution.mkdir(mode=0o700)
        self.native_root = self.execution / "root"
        for relative in ("bin", "etc"):
            (self.native_root / relative).mkdir(parents=True, mode=0o700)
        (self.native_root / "bin/sh").symlink_to("/bin/sh")
        (self.native_root / "bin/busybox").symlink_to(busybox or "/bin/sh")
        self.actual_busybox = busybox

        self.tools = router.path("work/native-shell-tools")
        self.tools.mkdir(mode=0o700)
        self.witness_path = router.path("work/native-shell-witness.json")
        self.mode = mode
        for name, candidates in {
            "cat": ("/bin/cat", "/usr/bin/cat"),
            "wc": ("/usr/bin/wc", "/bin/wc"),
            "printf": ("/usr/bin/printf", "/bin/printf"),
            "mkdir": ("/bin/mkdir", "/usr/bin/mkdir"),
            "env": ("/usr/bin/env", "/bin/env"),
        }.items():
            executable = next((Path(path) for path in candidates if Path(path).is_file()), None)
            assert executable is not None
            (self.tools / name).symlink_to(executable)
        test_script = """import os
import stat
import subprocess
import sys

args = sys.argv[1:]
if args == ["-d", "/proc/self/fd/6"]:
    try:
        sys.exit(0 if stat.S_ISDIR(os.fstat(6).st_mode) else 1)
    except OSError:
        sys.exit(1)
if len(args) == 3 and args[1:] == ["-ef", "/proc/self/fd/6"]:
    try:
        left, right = os.stat(args[0]), os.fstat(6)
        sys.exit(0 if (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino) else 1)
    except OSError:
        sys.exit(1)
sys.exit(subprocess.call(["/usr/bin/test", *args]))
"""
        self._write_python_tool("work/native-shell-test", test_script)
        (self.tools / "test").symlink_to(router.path("work/native-shell-test"))
        self._write_chroot()

        self.active = self.execution / "active"
        self.active.write_bytes(b"callback\n")
        self.invoke = router.write("work/invoke-native-shell.sh", self._invoke_script())

    def _write_chroot(self) -> None:
        script = rf"""import json
import os
import signal
import shlex
import stat
import subprocess
import sys
from pathlib import Path

def _fd_open(fd):
    try:
        os.fstat(fd)
        return True
    except OSError:
        return False

def _fd_is_directory(fd):
    try:
        return stat.S_ISDIR(os.fstat(fd).st_mode)
    except OSError:
        return False

fixture_root = Path({str(self.router.root)!r})
actual_busybox = {str(self.actual_busybox) if self.actual_busybox else None!r}
actual_opkg = fixture_root / "work/native-opkg"
root, shell, option, script = sys.argv[1:]
record = {{
    "argv": sys.argv[1:],
    # The inert shell wrapper adds its own fixed host metadata before Python.
    "environment": {{key: value for key, value in os.environ.items()
                    if key not in {{"PWD", "SHLVL", "__CF_USER_TEXT_ENCODING"}}}},
    "fds": [fd for fd in range(3, 64) if _fd_open(fd)],
    "fd6_is_directory": _fd_is_directory(6),
    "root": root,
    "script": script,
}}
fixture_root.joinpath("work/native-shell-witness.json").write_text(
    json.dumps(record), encoding="utf-8"
)
mode = fixture_root.joinpath("work/native-shell-mode").read_text().strip()
if mode == "signal":
    os.kill(os.getpid(), signal.SIGTERM)
if mode == "oversized":
    sys.stdout.buffer.write(b"x" * 8192)
    raise SystemExit(0)
if mode == "bad-sentinel":
    sys.stdout.buffer.write(b"WRONG\n")
    raise SystemExit(0)
if mode == "nul":
    sys.stdout.buffer.write(b"CFMGR_NATIVE_SHELL_V1\x00\n")
    raise SystemExit(0)
if mode == "extra-newline":
    sys.stdout.buffer.write(b"CFMGR_NATIVE_SHELL_V1\n\n")
    raise SystemExit(0)
if mode == "unterminated":
    sys.stdout.buffer.write(b"CFMGR_NATIVE_SHELL_V1")
    raise SystemExit(0)
if mode == "stderr":
    sys.stderr.buffer.write(b"native error\n")
    raise SystemExit(0)
if mode.startswith("status-"):
    sys.stdout.buffer.write(b"CFMGR_NATIVE_SHELL_V1\n")
    raise SystemExit(int(mode[7:]))

pass_fds = (6,) if _fd_open(6) else ()
if actual_busybox and mode == "busybox":
    adapted = script.replace("/bin/busybox", shlex.quote(actual_busybox))
    adapted = adapted.replace("/tmp/cfmgr-home", "/tmp")
    command = [actual_busybox, "sh", "-c", adapted]
elif mode == "opkg":
    busybox = fixture_root.joinpath("work/native-shell-busybox.py")
    if actual_busybox:
        adapted = script.replace("/bin/busybox", shlex.quote(actual_busybox))
    else:
        adapted = script.replace("/bin/busybox", shlex.quote(str(busybox)))
    adapted = adapted.replace("/tmp/cfmgr-home", "/tmp")
    adapted = adapted.replace("/opt/bin/opkg", shlex.quote(str(actual_opkg)))
    command = ([actual_busybox, "sh", "-c", adapted] if actual_busybox
               else ["/bin/sh", "-c", adapted])
else:
    busybox = fixture_root.joinpath("work/native-shell-busybox.py")
    adapted = script.replace("/bin/busybox", shlex.quote(str(busybox)))
    command = ["/bin/sh", "-c", adapted]
result = subprocess.run(command, check=False, pass_fds=pass_fds)
raise SystemExit(result.returncode)
"""
        self._write_python_tool("work/native-shell-chroot", script)
        self.router.write("work/native-shell-mode", self.mode + "\n")
        busybox_script = rf"""import json
import os
import sys
from pathlib import Path

def _fd_open(fd):
    try:
        os.fstat(fd)
        return True
    except OSError:
        return False

fixture_root = Path({str(self.router.root)!r})
record = {{
    "argv": sys.argv[1:],
    "fd6_open": _fd_open(6),
}}
with fixture_root.joinpath("work/native-shell-busybox-witness.jsonl").open("a") as stream:
    stream.write(json.dumps(record) + "\n")
if sys.argv[1:] in (["test", "-d", "/tmp/cfmgr-home"], ["test", "-d", "/tmp"]):
    raise SystemExit(0)
if sys.argv[1:] == ["test", "-c", "/dev/null"]:
    raise SystemExit(0)
if sys.argv[1:] == ["printf", "CFMGR_NATIVE_SHELL_V1\\n"]:
    sys.stdout.buffer.write(b"CFMGR_NATIVE_SHELL_V1\n")
    raise SystemExit(0)
raise SystemExit(91)
"""
        self._write_python_tool("work/native-shell-busybox.py", busybox_script)
        (self.tools / "chroot").symlink_to(self.router.path("work/native-shell-chroot"))

    def _write_python_tool(self, relative: str, source: str) -> None:
        self.router.write(relative + ".py", source)
        self.router.write(
            relative,
            "#!/bin/sh\nunset PWD SHLVL __CF_USER_TEXT_ENCODING\nexec "
            + shlex.quote(sys.executable)
            + " "
            + shlex.quote(str(self.router.path(relative + ".py")))
            + ' "$@"\n',
            executable=True,
        )

    def _invoke_script(self) -> str:
        return (
            f". {shlex.quote(str(IO))}\n"
            f". {shlex.quote(str(NATIVE_CONFIG))}\n"
            f". {shlex.quote(str(ISOLATION))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            "_io_active=1\n"
            "_isolation_mode=root\n"
            "_execution_layout=native-devices\n"
            "_execution_config_extended=1\n"
            "_entware_root_ready=1\n"
            "_execution_reserved=1\n"
            "_execution_io_complete=0\n"
            "_isolation_interrupted=0\n"
            "_execution_kind=fixture\n"
            f"_execution_guard={shlex.quote(str(self.guard))}\n"
            f"_isolation_guard={shlex.quote(str(self.execution))}\n"
            f"_isolation_tree={shlex.quote(str(self.native_root))}\n"
            f"_isolation_tools={shlex.quote(str(self.tools))}\n"
            'exec 8<"$3" 9<"$4"\n'
            "exec 3</dev/null 4</dev/null 5</dev/null 7</dev/null\n"
            'exec 6<"$1"\n'
            "root=$2; shift 4\n"
            "set -C; before_options=$(set +o)\n"
            'cfmgr_native_shell_probe "$root" "$@"; result=$?\n'
            '[ "$before_options" = "$(set +o)" ] || exit 93\n'
            'printf "RESULT\\t%s\\n" "$result"\n'
            f"{shlex.quote(str(self.tools / 'test'))} -d /proc/self/fd/6 || exit 92\n"
            "IFS= read -r eight <&8; IFS= read -r nine <&9\n"
            '[ "$eight:$nine" = owner-eight:owner-nine ] || exit 92\n'
        )

    def run(
        self,
        *,
        root: Path | None = None,
        suffix: tuple[str, ...] = (),
        context: str = "",
        probe: str = "shell",
    ) -> ShellResult:
        invocation = self._invoke_script()
        if probe == "opkg":
            invocation = invocation.replace(
                'cfmgr_native_shell_probe "$root" "$@"; result=$?',
                'cfmgr_native_opkg_probe "$root" "$@"; result=$?',
                1,
            )
        elif probe == "both":
            invocation = invocation.replace(
                'cfmgr_native_shell_probe "$root" "$@"; result=$?',
                'cfmgr_native_shell_probe "$root"; shell_result=$?\n'
                'cfmgr_native_opkg_probe "$root" "$@"; result=$?\n'
                '[ "$shell_result" -eq 0 ] || exit 94',
                1,
            )
        else:
            assert probe == "shell"
        if context:
            invocation = invocation.replace('exec 6<"$1"\n', f'exec 6<"$1"\n{context}\n', 1)
        self.router.write("work/invoke-native-shell.sh", invocation)
        shell = f"{shlex.quote(str(self.actual_busybox))} sh" if self.actual_busybox else "/bin/sh"
        return self.router.run(
            f'exec {shell} {shlex.quote(str(self.invoke))} "$@"\n',
            [
                str(self.native_root),
                str(root or self.native_root),
                str(self.router.write("work/fd-eight", "owner-eight\n")),
                str(self.router.write("work/fd-nine", "owner-nine\n")),
                *suffix,
            ],
        )

    def run_through_root_lease(self) -> ShellResult:
        self.active.unlink()
        script = (
            f". {shlex.quote(str(IO))}\n"
            f". {shlex.quote(str(NATIVE_CONFIG))}\n"
            f". {shlex.quote(str(ISOLATION))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            "_io_active=1; _isolation_mode=root; _execution_layout=native-devices\n"
            "_execution_config_extended=1; _entware_root_ready=1; _execution_reserved=1\n"
            "_execution_io_complete=0; _isolation_interrupted=0; _execution_kind=fixture\n"
            f"_execution_guard={shlex.quote(str(self.guard))}\n"
            f"_isolation_guard={shlex.quote(str(self.execution))}\n"
            f"_isolation_tree={shlex.quote(str(self.native_root))}\n"
            f"_isolation_tools={shlex.quote(str(self.tools))}\n"
            f"_isolation_test={shlex.quote(str(self.tools / 'test'))}\n"
            f"_isolation_printf={shlex.quote(str(self.tools / 'printf'))}\n"
            "_isolation_rm=/bin/rm\n"
            f"_io_wc={shlex.quote(str(self.tools / 'wc'))}\n"
            "_io_lf='\n'; _execution_root_ledger=fixture-ledger\n"
            "_execution_checked_root_ledger=fixture-ledger\n"
            "_isolation_root=/; _isolation_callback=native_callback\n"
            'exec 6<"$1"\n'
            "cfmgr_io_test() { return 0; }\n"
            "_cfmgr_isolation_native_layout_check() { return 0; }\n"
            'native_callback() { cfmgr_native_shell_probe "$1"; return "$?"; }\n'
            "_cfmgr_isolation_root_lease; result=$?\n"
            'printf "RESULT\\t%s\\n" "$result"\n'
            'IFS= read -r active <"$_isolation_guard/active" || exit 94\n'
            '[ "$active" = callback ] || exit 95\n'
        )
        path = self.router.write("work/invoke-native-shell-root-lease.sh", script)
        return self.router.run(
            f'exec /bin/sh {shlex.quote(str(path))} "$@"\n',
            [str(self.native_root)],
        )

    @property
    def witness(self) -> dict[str, object]:
        return json.loads(self.witness_path.read_text(encoding="utf-8"))

    @property
    def busybox_witnesses(self) -> list[dict[str, object]]:
        return [
            json.loads(line)
            for line in self.router.read("work/native-shell-busybox-witness.jsonl").splitlines()
        ]


def quiet(result: ShellResult, status: int) -> None:
    assert result.returncode == status
    assert result.stderr == ""


def test_fixed_launch_observes_clean_environment_and_descriptor_boundary(
    router: RouterHarness,
) -> None:
    fixture = NativeShellFixture(router)
    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t0\n"
    witness = fixture.witness
    assert witness["argv"][:3] == [str(fixture.native_root), "/bin/sh", "-c"]
    assert witness["argv"][3].lstrip("\n").startswith("exec 6<&-\n")
    assert witness["environment"] == {
        "PATH": "/sbin:/bin:/usr/sbin:/usr/bin",
        "LC_ALL": "C",
        "HOME": "/tmp/cfmgr-home",
        "TMPDIR": "/tmp",
    }
    assert witness["fd6_is_directory"] is True
    assert witness["fds"] == [6]
    assert fixture.busybox_witnesses == [
        {"argv": ["test", "-d", "/tmp/cfmgr-home"], "fd6_open": False},
        {"argv": ["test", "-c", "/dev/null"], "fd6_open": False},
        {"argv": ["printf", "CFMGR_NATIVE_SHELL_V1\\n"], "fd6_open": False},
    ]
    assert (fixture.execution / "native-shell/complete").is_dir()


@pytest.mark.parametrize(
    ("mode", "expected"),
    [
        ("bad-sentinel", 1),
        ("stderr", 1),
        ("status-7", 1),
        ("extra-newline", 1),
        ("unterminated", 1),
        ("nul", 129),
        ("signal", 129),
        ("oversized", 129),
    ],
)
def test_child_outcomes_require_bounded_verified_completion(
    router: RouterHarness, mode: str, expected: int
) -> None:
    fixture = NativeShellFixture(router, mode)

    result = fixture.run()
    quiet(result, 0)
    assert result.stdout == f"RESULT\t{expected}\n"

    assert fixture.witness_path.is_file()
    assert (fixture.execution / "native-shell").is_dir()
    if expected == 129:
        assert not (fixture.execution / "native-shell/complete").exists()
    else:
        assert (fixture.execution / "native-shell/complete").is_dir()


@pytest.mark.parametrize("forbidden", ["ld.so.cache", "ld.so.preload"])
def test_rejects_dangling_loader_cache_and_preload_before_launch(
    router: RouterHarness, forbidden: str
) -> None:
    fixture = NativeShellFixture(router)
    (fixture.native_root / f"etc/{forbidden}").symlink_to("missing-file")

    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t1\n"
    assert not fixture.witness_path.exists()
    assert not (fixture.execution / "native-shell").exists()


@pytest.mark.parametrize(
    "context",
    [
        "_io_active=0",
        "_execution_layout=native",
        "_execution_config_extended=0",
        "_entware_root_ready=0",
        "_execution_reserved=0",
        "_execution_io_complete=1",
        "_execution_kind=unknown",
    ],
)
def test_wrong_owner_context_refuses_before_reservation(
    router: RouterHarness, context: str
) -> None:
    fixture = NativeShellFixture(router)

    result = fixture.run(context=context)

    quiet(result, 0)
    assert result.stdout == "RESULT\t2\n"
    assert not fixture.witness_path.exists()
    assert not (fixture.execution / "native-shell").exists()


def test_requires_exact_active_callback_marker(router: RouterHarness) -> None:
    fixture = NativeShellFixture(router)
    fixture.active.write_bytes(b"prepare\n")

    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t2\n"
    assert not fixture.witness_path.exists()
    assert not (fixture.execution / "native-shell").exists()


def test_malformed_api_and_root_identity_refuse_without_effects(router: RouterHarness) -> None:
    fixture = NativeShellFixture(router)
    other_root = fixture.execution / "other-root"
    other_root.mkdir()

    malformed = fixture.run(suffix=("unexpected",))
    wrong_root = fixture.run(root=other_root)
    wrong_fd = fixture.run(context=f"exec 6<{shlex.quote(str(other_root))}")

    quiet(malformed, 0)
    quiet(wrong_root, 0)
    quiet(wrong_fd, 0)
    assert malformed.stdout == wrong_root.stdout == wrong_fd.stdout == "RESULT\t2\n"
    assert not fixture.witness_path.exists()
    assert not (fixture.execution / "native-shell").exists()


def test_collision_preserves_existing_evidence_and_prevents_launch(router: RouterHarness) -> None:
    fixture = NativeShellFixture(router)
    collision = fixture.execution / "native-shell"
    collision.mkdir()
    prior = collision / "prior-state"
    prior.write_bytes(b"retain exactly\n")

    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t1\n"
    assert prior.read_bytes() == b"retain exactly\n"
    assert not fixture.witness_path.exists()


@pytest.mark.parametrize("binary", ["sh", "busybox"])
def test_unavailable_fixed_executable_refuses_before_launch(
    router: RouterHarness, binary: str
) -> None:
    fixture = NativeShellFixture(router)
    (fixture.native_root / f"bin/{binary}").unlink()

    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t1\n"
    assert not fixture.witness_path.exists()


@pytest.mark.parametrize("failure", ["count", "completion"])
def test_post_reservation_observation_failure_is_uncertain_and_retained(
    router: RouterHarness, failure: str
) -> None:
    fixture = NativeShellFixture(router)
    if failure == "count":
        (fixture.tools / "wc").unlink()
        count_file = router.path("work/wc-count")
        router.write(
            "work/native-shell-tools/wc",
            "#!/bin/sh\n"
            f"count_file={shlex.quote(str(count_file))}\n"
            'count=0; [ ! -f "$count_file" ] || read -r count <"$count_file"\n'
            'count=$((count + 1)); printf "%s\\n" "$count" >"$count_file"\n'
            '[ "$count" -lt 2 ] || exit 7\n'
            'exec /usr/bin/wc "$@"\n',
            executable=True,
        )
    else:
        (fixture.tools / "mkdir").unlink()
        router.write(
            "work/native-shell-tools/mkdir",
            "#!/bin/sh\n"
            'for argument do case "$argument" in */native-shell/complete) exit 7 ;; esac; done\n'
            'exec /bin/mkdir "$@"\n',
            executable=True,
        )

    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t129\n"
    assert fixture.witness_path.is_file()
    assert (fixture.execution / "native-shell").is_dir()
    assert not (fixture.execution / "native-shell/complete").exists()


def test_root_lease_propagates_probe_uncertainty_and_retains_callback_intent(
    router: RouterHarness,
) -> None:
    fixture = NativeShellFixture(router, "signal")

    result = fixture.run_through_root_lease()

    quiet(result, 0)
    assert result.stdout == "RESULT\t129\n"
    assert fixture.witness_path.is_file()
    assert (fixture.execution / "native-shell").is_dir()
    assert fixture.active.read_bytes() == b"callback\n"
    assert not (fixture.execution / "native-shell/complete").exists()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_runs_the_fixed_inner_probe(busybox_router: RouterHarness) -> None:
    assert busybox_router.busybox is not None
    fixture = NativeShellFixture(busybox_router, "busybox", busybox=busybox_router.busybox)

    result = fixture.run()

    quiet(result, 0)
    assert result.stdout == "RESULT\t0\n"
    assert fixture.witness["argv"][1:3] == ["/bin/sh", "-c"]
    assert (fixture.execution / "native-shell/complete").is_dir()
