"""Bounded internal timeout/gzip probe supervision; no namespace or Opt execution."""

from __future__ import annotations

import json
import shlex
import shutil
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/supervision.sh"
DASH = shutil.which("dash")
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]

DISPATCHER = r"""
import json
import os
from pathlib import Path
import signal
import sys
import time

settings = json.loads(Path(sys.argv[1]).read_text())
tool, args = sys.argv[2], sys.argv[3:]
log = Path(settings["log"])

def record(value):
    with log.open("a") as stream:
        stream.write(json.dumps(value) + "\n")

def calls():
    if not log.exists():
        return []
    return [json.loads(line) for line in log.read_text().splitlines()]

if tool == "chroot":
    descriptors = []
    for fd in range(3, 10):
        try:
            os.fstat(fd)
            descriptors.append(fd)
        except OSError:
            pass
    record({"tool": tool, "args": args, "env": dict(os.environ), "fds": descriptors,
            "cwd": os.getcwd()})
    if settings.get("behavior") == "signal-wrapper":
        os.kill(os.getppid(), signal.SIGTERM)
    if settings.get("behavior") == "late":
        deadline = time.monotonic() + 2
        while not Path(settings["release"]).exists():
            if time.monotonic() >= deadline:
                raise AssertionError("fixture release deadline")
            time.sleep(0.001)
    if settings.get("behavior") in {"hang", "sleep-error"}:
        while True:
            time.sleep(0.1)
    output_size = settings.get("stdout_bytes", 20)
    data = b"V" * output_size
    while data:
        written = os.write(1, data)
        if written <= 0:
            raise OSError("short fixture write")
        data = data[written:]
    os.write(2, b"fixture stderr\n")
    sys.exit(settings.get("child_status", 0))
if tool == "sleep":
    assert args == ["1"]
    record({"tool": tool, "args": args})
    if settings.get("behavior") == "sleep-error":
        sys.exit(7)
    deadline = time.monotonic() + 1
    while not any(item["tool"] == "chroot" for item in calls()):
        if time.monotonic() >= deadline:
            raise AssertionError("poll reached sleep before the fixture child started")
        time.sleep(0.001)
    time.sleep(0.005)
    sys.exit(0)
if tool == "printf":
    if settings.get("behavior") == "terminal-write-error":
        sys.exit(7)
    os.execv("/usr/bin/printf", ["/usr/bin/printf", *args])
raise AssertionError((tool, args))
"""


class SupervisionFixture:
    def __init__(self, router: RouterHarness):
        self.router = router
        self.guard = router.path("ram/tmp/supervision guard")
        self.guard.mkdir(mode=0o700)
        (self.guard / "active").write_text("probe\n")
        self.root = self.guard / "root"
        self.root.mkdir(mode=0o700)
        self.probe = self.guard / "probe"
        self.tools = router.path("work/native tools")
        self.tools.mkdir(mode=0o700)
        self.settings_path = router.path("work/settings.json")
        self.log = router.path("work/calls.jsonl")
        self.settings: dict[str, object] = {
            "log": str(self.log),
            "probe": str(self.probe),
            "behavior": "",
            "stdout_bytes": 20,
            "child_status": 0,
            "release": str(router.path("work/release")),
        }
        self.fd8 = router.write("work/caller-eight", "caller-eight\n")
        self.fd9 = router.write("work/caller-nine", "caller-nine\n")
        self.traps = router.path("work/owner-traps")
        self.save()
        router.write("work/dispatcher.py", DISPATCHER)
        for name in ("chroot", "sleep", "printf"):
            router.write(
                f"work/native tools/{name}",
                "#!/bin/sh\nset -eu\nexec "
                f"{shlex.quote(sys.executable)} "
                f"{shlex.quote(str(router.path('work/dispatcher.py')))} "
                f'{shlex.quote(str(self.settings_path))} {name} "$@"\n',
                executable=True,
            )
        for name, path in (
            ("mkdir", "/bin/mkdir"),
            ("wc", "/usr/bin/wc"),
            ("env", "/usr/bin/env"),
        ):
            router.path(f"work/native tools/{name}").symlink_to(path)

    def save(self) -> None:
        self.settings_path.write_text(json.dumps(self.settings))
        self.settings_path.chmod(0o600)

    def calls(self) -> list[dict]:
        if not self.log.exists():
            return []
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def run(
        self,
        mode: str = "timeout",
        *,
        timeout: float = 3,
        prefix: str = "",
        suffix: str = "",
        args: list[str] | None = None,
        shell: str | None = None,
    ) -> ShellResult:
        exit_trap = shlex.quote(f'printf "owner-exit\\n" >>{shlex.quote(str(self.traps))}')
        signal_trap = shlex.quote(f'printf "owner-signal\\n" >>{shlex.quote(str(self.traps))}')
        script = (
            f". {shlex.quote(str(SOURCE))}\n"
            + "IFS=x; set -f; umask 000\n"
            + f"trap {exit_trap} 0\n"
            + f"trap {signal_trap} HUP INT TERM\n"
            + "before_traps=$(trap); before_options=$(set +o); before_umask=$(umask)\n"
            + f"exec 3<{shlex.quote(str(self.fd8))} 4<{shlex.quote(str(self.fd8))} "
            + f"5<{shlex.quote(str(self.fd8))} 6<{shlex.quote(str(self.fd8))} "
            + f"7<{shlex.quote(str(self.fd8))} 8<{shlex.quote(str(self.fd8))} "
            + f"9<{shlex.quote(str(self.fd9))}\n"
            + prefix
            + "_supervision_stdout=stale; _supervision_stderr=stale\n"
            + "_supervision_stdout_bytes=77; _supervision_stderr_bytes=77\n"
            'cfmgr_supervision_test "$@"\n'
            "_probe_status=$?\n"
            "printf 'RESULT\\t%s\\t%s\\t%s\\n' \"$_probe_status\" "
            '"$_supervision_started" "$_supervision_complete"\n'
            "printf 'CHILD\\t%s\\n' \"${_supervision_status:-unset}\"\n"
            + "case $IFS in x) : ;; *) exit 7 ;; esac\n"
            + 'case "$(trap)" in "$before_traps") : ;; *) exit 7 ;; esac\n'
            + 'case "$(set +o)" in "$before_options") : ;; *) exit 7 ;; esac\n'
            + 'case "$(umask)" in "$before_umask") : ;; *) exit 7 ;; esac\n'
            + "IFS= read -r eight <&8; IFS= read -r nine <&9\n"
            + "case $eight:$nine in caller-eight:caller-nine) : ;; *) exit 7 ;; esac\n"
            + "case $_supervision_complete in 0)\n"
            + "  case $_supervision_stdout$_supervision_stderr$_supervision_stdout_bytes"
            + "$_supervision_stderr_bytes in '') : ;; *) exit 7 ;; esac\n"
            + "esac\n"
            + suffix
        )
        arguments = (
            args if args is not None else [str(self.guard), str(self.root), mode, str(self.tools)]
        )
        if shell is not None:
            invoke = self.router.write("work/invoke-supervision.sh", script)
            script = f'exec {shlex.quote(shell)} "$@"\n'
            arguments = [str(invoke), *arguments]
        return self.router.run(
            script,
            arguments,
            timeout=timeout,
            env={"SUPERVISION_SECRET": "must-not-enter-native-probe"},
        )


@pytest.fixture
def supervision(router: RouterHarness) -> SupervisionFixture:
    return SupervisionFixture(router)


def result_state(result: ShellResult) -> tuple[int, int, int, str]:
    assert result.returncode == 0, result
    assert result.stderr == ""
    lines = result.stdout.splitlines()
    first = lines[0].split("\t")
    second = lines[1].split("\t")
    assert first[0] == "RESULT" and second[0] == "CHILD"
    return int(first[1]), int(first[2]), int(first[3]), second[1]


@pytest.mark.parametrize(
    "mode,shell",
    [
        ("timeout", None),
        pytest.param(
            "gzip", DASH, marks=pytest.mark.skipif(DASH is None, reason="dash unavailable")
        ),
    ],
)
def test_probe_invokes_only_fixed_chroot_arguments_and_sanitized_environment(
    supervision: SupervisionFixture, mode: str, shell: str | None
) -> None:
    result = supervision.run(mode, shell=shell)
    assert result_state(result) == (0, 1, 1, "0")
    child = next(call for call in supervision.calls() if call["tool"] == "chroot")
    if mode == "timeout":
        assert child["args"] == [
            str(supervision.root),
            "/bootstrap/timeout-coreutils",
            "--version",
        ]
    else:
        assert child["args"] == [
            str(supervision.root),
            "/bootstrap/timeout-coreutils",
            "--foreground",
            "--kill-after=1",
            "3",
            "/bootstrap/gzip-gnu",
            "--version",
        ]
    assert child["env"]["LC_ALL"] == "C"
    assert child["env"]["PATH"] == "/sbin:/bin:/usr/sbin:/usr/bin"
    assert "SUPERVISION_SECRET" not in child["env"]
    assert not any(name.startswith("LD_") for name in child["env"])
    assert child["fds"] == []
    assert child["cwd"] == "/"
    assert supervision.traps.read_text() == "owner-exit\n"
    assert supervision.probe.stat().st_mode & 0o777 == 0o700
    assert all(
        (supervision.probe / name).stat().st_mode & 0o777 == 0o600
        for name in ("stdout", "stderr", "status")
    )
    assert (supervision.probe / "stdout").read_bytes() == b"V" * 20
    assert (supervision.probe / "stderr").read_bytes() == b"fixture stderr\n"
    status_record = (supervision.probe / "status").read_bytes()
    body = b"done\t0\n"
    assert status_record == body + f"end\t{len(body)}\n".encode()


@pytest.mark.parametrize("child_status", [7, 124])
def test_child_failure_status_is_complete_and_preserved(
    router: RouterHarness, child_status: int
) -> None:
    supervision = SupervisionFixture(router)
    supervision.settings["child_status"] = child_status
    supervision.save()
    result = supervision.run()
    assert result_state(result) == (child_status, 1, 1, str(child_status))
    assert (supervision.probe / "status").is_file()


@pytest.mark.parametrize("requested_bytes", [4097, 16384])
def test_capture_overflow_fails_after_valid_child_completion(
    supervision: SupervisionFixture,
    requested_bytes: int,
) -> None:
    supervision.settings["stdout_bytes"] = requested_bytes
    supervision.save()
    result = supervision.run()
    status, started, complete, child_status = result_state(result)
    assert (status, started, complete) == (1, 1, 1)
    if requested_bytes == 4097:
        assert child_status == "0"
    else:
        assert child_status not in {"0", "unset"}
    assert 4096 < (supervision.probe / "stdout").stat().st_size <= 9 * 1024
    assert (supervision.probe / "status").is_file()


def test_poll_expiry_is_incomplete_and_retains_owned_probe(
    supervision: SupervisionFixture,
) -> None:
    supervision.settings["behavior"] = "hang"
    supervision.save()
    result = supervision.run(timeout=3)
    assert result_state(result) == (124, 1, 0, "unset")
    assert len([call for call in supervision.calls() if call["tool"] == "sleep"]) == 5
    assert (supervision.probe / "stdout").is_file()
    assert (supervision.probe / "stderr").is_file()
    assert not (supervision.probe / "status").exists()


def test_terminal_write_failure_is_incomplete_and_retains_captures(
    supervision: SupervisionFixture,
) -> None:
    supervision.settings["behavior"] = "terminal-write-error"
    supervision.save()
    result = supervision.run(timeout=3)
    assert result_state(result) == (124, 1, 0, "unset")
    assert len([call for call in supervision.calls() if call["tool"] == "sleep"]) == 5
    assert (supervision.probe / "stdout").is_file()
    assert (supervision.probe / "stderr").is_file()
    assert (supervision.probe / "status").read_bytes() == b""


def test_terminal_reader_checks_exact_framing_and_resets_helper_state(
    router: RouterHarness,
) -> None:
    probe = router.path("ram/tmp/terminal probe")
    probe.mkdir(mode=0o700)
    (probe / "stdout").write_bytes(b"")
    (probe / "stderr").write_bytes(b"")
    script = (
        f". {shlex.quote(str(SOURCE))}\n"
        'probe="$1"\nwc="$2"\n'
        "check_record() {\n"
        "  label=$1; expected=$2; shift 2\n"
        '  printf "%b" "$1" >"$probe/status"\n'
        "  _supervision_complete=1; _supervision_status=77\n"
        "  _supervision_stdout=stale; _supervision_stderr=stale\n"
        "  _supervision_stdout_bytes=77; _supervision_stderr_bytes=77\n"
        '  _cfmgr_supervision_terminal "$probe" "$wc"; rc=$?\n'
        '  if [ "$expected" = 1 ]; then\n'
        '    [ -z "$_supervision_stdout$_supervision_stderr" ] && '
        '    [ -z "$_supervision_stdout_bytes$_supervision_stderr_bytes" ] || exit 7\n  fi\n'
        '  printf "%s\\t%s\\t%s\\t%s\\t%s\\n" "$label" "$expected" "$rc" '
        '"$_supervision_complete" "${_supervision_status:-unset}"\n'
        "}\n"
        "check_record good-zero 0 'done\\t0\\nend\\t7\\n'\n"
        "check_record good-124 0 'done\\t124\\nend\\t9\\n'\n"
        "check_record no-final-lf 1 'done\\t0\\nend\\t7'\n"
        "check_record duplicate 1 'done\\t0\\nend\\t7\\ndone\\t0\\nend\\t7\\n'\n"
        "check_record nul 1 'done\\t\\0000\\nend\\t7\\n'\n"
        "check_record oversized 1 'done\\t0\\nend\\t7\\n12345678901234567890123456789012345\\n'\n"
        "check_record status-range 1 'done\\t256\\nend\\t9\\n'\n"
        "check_record status-leading-zero 1 'done\\t00\\nend\\t8\\n'\n"
        "check_record footer-mismatch 1 'done\\t0\\nend\\t5\\n'\n"
    )
    result = router.run(
        script,
        [str(probe), "/usr/bin/wc"],
        timeout=3,
    )
    assert result.returncode == 0, result
    observations = [line.split("\t") for line in result.stdout.splitlines()]
    assert [row[0] for row in observations] == [
        "good-zero",
        "good-124",
        "no-final-lf",
        "duplicate",
        "nul",
        "oversized",
        "status-range",
        "status-leading-zero",
        "footer-mismatch",
    ]
    assert observations[0] == ["good-zero", "0", "0", "1", "0"]
    assert observations[1] == ["good-124", "0", "0", "1", "124"]
    assert all(row[1:] == ["1", "1", "0", "unset"] for row in observations[2:])


def test_uncertain_terminal_record_or_capture_size_resets_completion(
    router: RouterHarness,
) -> None:
    probe = router.path("ram/tmp/uncertain terminal")
    probe.mkdir(mode=0o700)
    record = probe / "status"
    record.write_bytes(b"done\t0\nend\t7\n")
    (probe / "stdout").write_bytes(b"")
    (probe / "stderr").write_bytes(b"")
    record_bytes = len(record.read_bytes())
    counter = router.path("work/wc-count")

    for label, wc_body in (
        ("record", f"printf '{record_bytes}\\n'\nexit 129\n"),
        (
            "capture",
            "if [ -r "
            + shlex.quote(str(counter))
            + " ]; then IFS= read -r _count <"
            + shlex.quote(str(counter))
            + "; else _count=0; fi\n"
            + '_count=$((_count + 1)); printf "%s\\n" "$_count" >'
            + shlex.quote(str(counter))
            + "\ncase $_count in\n"
            + f"1) printf '{record_bytes}\\n' ;;\n"
            + "2) printf '0\\n'; exit 129 ;;\n"
            + "*) printf '0\\n' ;;\nesac\n",
        ),
    ):
        wc = router.write(
            f"work/uncertain-wc-{label}",
            "#!/bin/sh\n" + wc_body,
            executable=True,
        )
        counter.unlink(missing_ok=True)
        script = (
            f". {shlex.quote(str(SOURCE))}\n"
            f"_cfmgr_supervision_terminal {shlex.quote(str(probe))} {shlex.quote(str(wc))}\n"
            "_rc=$?\n"
            'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\n" "$_rc" '
            '"$_supervision_complete" "$_supervision_status" '
            '"$_supervision_stdout_bytes$_supervision_stderr_bytes"\n'
        )
        result = router.run(script)
        assert result.returncode == 0 and result.stderr == "", f"{label}: {result}"
        expected_fields = "0\t" if label == "capture" else "\t"
        assert result.stdout == f"RESULT\t129\t0\t{expected_fields}\n", f"{label}: {result}"


@pytest.mark.parametrize(
    "invalid",
    [
        "mode",
        "root",
        "active",
        "tools",
        "empty-tools",
        "long-path",
        "probe",
        "probe-link",
        "mkdir-error",
    ],
)
def test_probe_rejects_invalid_contract_before_start(router: RouterHarness, invalid: str) -> None:
    supervision = SupervisionFixture(router)
    args = [str(supervision.guard), str(supervision.root), "timeout", str(supervision.tools)]
    expected = 1
    if invalid == "mode":
        args[2] = "arbitrary"
        expected = 2
    elif invalid == "root":
        args[1] = str(supervision.guard / "elsewhere")
        expected = 2
    elif invalid == "active":
        (supervision.guard / "active").unlink()
    elif invalid == "tools":
        args[3] = str(supervision.tools / "missing")
    elif invalid == "empty-tools":
        args[3] = ""
        expected = 2
    elif invalid == "long-path":
        args[0] = "/" + "a" * 4096
        args[1] = args[0] + "/root"
        expected = 2
    elif invalid == "probe":
        supervision.probe.mkdir()
    elif invalid == "probe-link":
        supervision.probe.symlink_to(supervision.root, target_is_directory=True)
    elif invalid == "mkdir-error":
        (supervision.tools / "mkdir").unlink()
        router.write(
            "work/native tools/mkdir",
            "#!/bin/sh\nprintf 'fixture mkdir error\\n' >&2\nexit 1\n",
            executable=True,
        )
    result = supervision.run(args=args)
    assert result_state(result) == (expected, 0, 0, "unset")
    assert supervision.calls() == []
    assert supervision.traps.read_text() == "owner-exit\n"
    if invalid not in {"probe", "probe-link"}:
        assert not supervision.probe.exists()


@pytest.mark.parametrize("behavior,expected", [("signal-wrapper", 124), ("sleep-error", 1)])
def test_interrupted_wrapper_or_failed_sleep_cannot_publish_completion(
    supervision: SupervisionFixture, behavior: str, expected: int
) -> None:
    supervision.settings["behavior"] = behavior
    supervision.save()
    result = supervision.run()
    assert result_state(result) == (expected, 1, 0, "unset")
    assert supervision.probe.is_dir()
    assert supervision.traps.read_text() == "owner-exit\n"
    if behavior == "signal-wrapper":
        assert not (supervision.probe / "status").exists()


def test_late_terminal_requires_a_fresh_explicit_observation(
    supervision: SupervisionFixture,
) -> None:
    supervision.settings["behavior"] = "late"
    supervision.save()
    suffix = (
        f": >{shlex.quote(str(supervision.settings['release']))}\n"
        "attempt=0\n"
        'while ! _cfmgr_supervision_terminal "$_supervision_probe" "$_supervision_wc"; do\n'
        '  [ "$attempt" -lt 10 ] || exit 7\n'
        '  "$_supervision_sleep" 1 || exit 7\n'
        "  attempt=$((attempt + 1))\ndone\n"
        'printf \'LATE\\t%s\\t%s\\n\' "$_supervision_complete" "$_supervision_status"\n'
    )
    result = supervision.run(suffix=suffix)
    assert result_state(result) == (124, 1, 0, "unset")
    assert result.stdout.splitlines()[2] == "LATE\t1\t0"
    assert supervision.probe.is_dir()
    assert supervision.traps.read_text() == "owner-exit\n"


def test_worker_startup_failure_retains_reserved_probe(supervision: SupervisionFixture) -> None:
    # Restrict only this owned fixture process. Worker cannot raise its file limit;
    # polling stays fast and no filesystem output is attempted by the caller.
    (supervision.tools / "sleep").write_text("#!/bin/sh\nexit 0\n")
    script = (
        f". {shlex.quote(str(SOURCE))}\n"
        "ulimit -S -f 0; ulimit -H -f 0\n"
        'cfmgr_supervision_test "$@"; rc=$?\n'
        "printf 'RESULT\\t%s\\t%s\\t%s\\n' \"$rc\" "
        '"$_supervision_started" "$_supervision_complete"\n'
        "printf 'CHILD\\t%s\\n' \"${_supervision_status:-unset}\"\n"
    )
    result = supervision.router.run(
        script, [str(supervision.guard), str(supervision.root), "timeout", str(supervision.tools)]
    )
    assert result_state(result) == (124, 1, 0, "unset")
    assert supervision.probe.is_dir()
    assert not any(supervision.probe.iterdir())
    assert supervision.calls() == []


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_probe_with_required_busybox_shell_and_native_applets(
    busybox_router: RouterHarness,
) -> None:
    busybox_router.busybox_applets("printf", "[", "test")
    supervision = SupervisionFixture(busybox_router)
    assert busybox_router.busybox is not None
    for name in ("mkdir", "wc", "env", "printf"):
        tool = supervision.tools / name
        tool.unlink()
        tool.symlink_to(busybox_router.busybox)
    assert result_state(supervision.run()) == (0, 1, 1, "0")
    child = next(call for call in supervision.calls() if call["tool"] == "chroot")
    assert child["fds"] == [] and child["cwd"] == "/"
    assert supervision.traps.read_text() == "owner-exit\n"


def test_size_accepts_only_native_leading_whitespace_and_canonical_digits(
    router: RouterHarness,
) -> None:
    data = router.write("work/size-input", "x")
    wc = router.write("work/size-wc", '#!/bin/sh\nprintf "%b" "$SIZE_FIXTURE"\n', executable=True)
    cases = [
        ("  \\t1\\n", "1"),
        ("0\\n", "0"),
        ("1\\t2\\n", "reject"),
        ("junk\\t1\\n", "reject"),
        ("01\\n", "reject"),
        ("4097\\n", "reject"),
    ]
    script = (
        f". {shlex.quote(str(SOURCE))}\n"
        "wc=$1; data=$2; shift 2\n"
        "for SIZE_FIXTURE do\n"
        "  export SIZE_FIXTURE\n"
        '  value=$(_cfmgr_supervision_size "$wc" "$data") || value=reject\n'
        '  printf "%s\\n" "$value"\n'
        "done\n"
    )
    result = router.run(script, [str(wc), str(data), *(value for value, _ in cases)])
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.splitlines() == [expected for _, expected in cases]


@pytest.mark.parametrize(
    ("module", "consumer", "ordinary_failure"),
    [
        ("closure.sh", "_cfmgr_closure_size_owned", 10),
        ("supervision.sh", "_cfmgr_supervision_size", 1),
    ],
)
def test_native_size_readers_reject_failed_producers_and_preserve_uncertainty(
    router: RouterHarness, module: str, consumer: str, ordinary_failure: int
) -> None:
    data = router.write("work/size-input", "x")
    failed = router.write("work/wc-failed", "#!/bin/sh\nprintf '1\\n'\nexit 7\n", executable=True)
    signalled = router.write(
        "work/wc-signalled", '#!/bin/sh\n/bin/kill -TERM "$$"\n', executable=True
    )
    result = router.run(
        f". {shlex.quote(str(SOURCE.with_name(module)))}\n"
        + "consumer=$1; data=$2; shift 2\nfor producer do\n"
        + '  value=$("$consumer" "$producer" "$data"); status=$?\n'
        + '  printf "<%s> %s\\n" "$value" "$status"\ndone\n',
        [
            consumer,
            str(data),
            "/usr/bin/wc",
            str(failed),
            str(router.path("work/absent-wc")),
            str(signalled),
        ],
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.splitlines() == [
        "<1> 0",
        f"<> {ordinary_failure}",
        f"<> {ordinary_failure}",
        "<> 129",
    ]
