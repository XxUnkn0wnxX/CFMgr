"""Private native IO transactions using synthetic roots and instrumented host tools."""

from __future__ import annotations

import hashlib
import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_mountinfo import Mount, oracle, snapshot, topology_oracle

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/io.sh"
PARSER = ROOT / "modules/mountinfo.awk"
MOUNTS = [Mount("1"), Mount("2", point=b"/tmp/opt", root=b"/entware", device="8:1")]
TARGET = "/tmp/opt/bin/jq"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]
SHELLS = [
    pytest.param("/bin/sh", id="sh"),
    pytest.param(
        "/bin/dash",
        id="dash",
        marks=pytest.mark.skipif(not Path("/bin/dash").is_file(), reason="dash unavailable"),
    ),
]

# Tools are explicit fixture wrappers. Only cat/awk/wc/printf and owned RAM
# mkdir/rm operations are allowed; the Python dispatcher is HOST TEST CODE.
DISPATCHER = r"""
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

settings = json.loads(Path(sys.argv[1]).read_text())
tool, args = sys.argv[2], sys.argv[3:]
log = Path(settings["log"])
record = {"tool": tool, "args": args}
(log / (str(os.getpid()) + ".json")).write_text(json.dumps(record))
mode = settings.get("modes", {}).get(tool, "")
def write_all(fd, data):
    while data:
        count = os.write(fd, data)
        if count <= 0:
            raise OSError("short fixture write")
        data = data[count:]

if mode == "error":
    print("SECRET-provider-config", file=sys.stderr)
    sys.exit(7)
if mode == "invalid":
    print("SECRET invalid output")
    sys.exit(0)

if tool == "mkdir":
    assert args[:2] == ["-m", "700"] and len(args) == 3
    stage = Path(args[2])
    assert stage.parent == Path(settings["ram"]) and stage.name.startswith("cfmgr-io.")
    attempt = int(stage.name.rsplit(".", 1)[1])
    if mode == "signal":
        os.kill(os.getppid(), signal.SIGTERM)
        sys.exit(1)
    if attempt < settings.get("collisions", 0):
        if settings.get("collision_kind") == "symlink":
            stage.symlink_to(settings["foreign"])
        elif settings.get("collision_kind") == "file":
            stage.write_text("foreign")
        else:
            stage.mkdir()
            (stage / "foreign").write_text("preserve")
        sys.exit(1)
    stage.mkdir(mode=0o700)
    if mode == "readonly":
        stage.chmod(0o500)
    sys.exit(0)
if tool == "rm":
    assert args[0] == "-rf" and len(args) == 2
    stage = Path(args[1])
    assert stage.parent == Path(settings["ram"]) and stage.name.startswith("cfmgr-io.")
    assert not stage.is_symlink() and not (stage / "foreign").exists()
    observations = {"stage_mode": stage.stat().st_mode & 0o777, "files": {}}
    for path in stage.iterdir():
        if path.is_symlink():
            observations["files"][path.name] = {"symlink": True}
        elif path.is_file():
            data = path.read_bytes()
            assert len(data) <= 132096
            observations["files"][path.name] = {
                "mode": path.stat().st_mode & 0o777, "bytes": len(data),
                "head_hex": data[:128].hex(), "sha256": hashlib.sha256(data).hexdigest(),
            }
    (log / (str(os.getpid()) + ".observation")).write_text(json.dumps(observations))
    sys.exit(subprocess.call(["/bin/rm", *args]))
if tool == "cat" and args == ["produce"]:
    if mode == "signal-owner":
        # Producer's parent is the capture subshell; target its workspace owner,
        # not the external harness caller. This is HOST-only process inspection.
        owner = int(subprocess.check_output(
            ["/bin/ps", "-o", "ppid=", "-p", str(os.getppid())], text=True).strip())
        os.kill(owner, signal.SIGTERM)
    write_all(1, bytes.fromhex(settings.get("stdout_hex", "")))
    write_all(2, bytes.fromhex(settings.get("stderr_hex", "")))
    sys.exit(settings.get("producer_status", 0))
if tool == "awk" and "awk_output_hex" in settings:
    assert args[0] == "-v" and args[1].startswith("cfmgr_mountinfo_size=")
    assert args[-2:] == ["-f", settings["parser"]]
    assert args[2:-2] in ([], ["-v", "cfmgr_mountinfo_mode=topology"])
    os.write(1, bytes.fromhex(settings["awk_output_hex"]))
    os.write(2, bytes.fromhex(settings.get("awk_stderr_hex", "")))
    sys.exit(settings.get("awk_status", 0))
if tool == "printf":
    if mode == "partial-publication" and args[0] == "%s":
        os.write(1, args[1].encode()[:12])
        sys.exit(7)
    if mode == "partial-metadata" and args[0].startswith("capture"):
        os.write(1, b"capture\t0")
        sys.exit(0)
    if mode == "nul-metadata" and args[0].startswith("capture"):
        os.write(1, b"capture\x00\t0\t0\t0\n")
        sys.exit(0)
    executable = "/usr/bin/printf"
elif tool in ("cat", "wc", "awk"):
    executable = "/bin/cat" if tool == "cat" else "/usr/bin/" + tool
else:
    raise AssertionError("unexpected tool " + tool)
sys.exit(subprocess.call([executable, *args]))
"""


class IOFixture:
    def __init__(self, router: RouterHarness, shell: str = "/bin/sh"):
        self.router = router
        self.shell = shell
        router.path("work/calls").mkdir(mode=0o700)
        router.write("work/dispatcher.py", DISPATCHER)
        router.write("work/input", snapshot(MOUNTS).decode())
        router.write("ram/foreign", "preserve foreign target")
        self.settings = {
            "ram": str(router.path("ram/tmp")),
            "log": str(router.path("work/calls")),
            "foreign": str(router.path("ram/foreign")),
            "parser": str(PARSER),
            "modes": {},
        }
        self.settings_path = router.path("work/settings.json")
        self.save()
        for tool in ["mkdir", "rm", "cat", "wc", "awk", "printf"]:
            router.fake_tool(
                tool,
                f"exec {shlex.quote(sys.executable)} "
                f"{shlex.quote(str(router.path('work/dispatcher.py')))} "
                f'{shlex.quote(str(self.settings_path))} {tool} "$@"\n',
            )

    def save(self) -> None:
        self.settings_path.write_text(json.dumps(self.settings))
        self.settings_path.chmod(0o600)

    def run(self, script: str, args: list[str], *, timeout: float = 15) -> ShellResult:
        self.router.write("work/invoke.sh", f". {shlex.quote(str(SOURCE))}\n" + script)
        return self.router.run(
            f'exec {shlex.quote(self.shell)} "$CFMGR_TEST_ROOT/work/invoke.sh" "$@"\n',
            args,
            timeout=timeout,
            env={
                "_io_tools": "/opt/SECRET",
                "_io_stage": "/opt/SECRET-stage",
                "IFS": "x",
                "_mount_mode": "topology",
                "_mount_topology": "invalid inherited topology",
            },
        )

    def workspace(
        self, callback: str, *args: str, prefix: str = "", timeout: float = 15
    ) -> ShellResult:
        return self.run(
            prefix + "cfmgr_fixture_callback() {\n" + callback + "\n}\n"
            'cfmgr_io_test "$1" "$2" workspace cfmgr_fixture_callback "${3-}" "${4-}"\n',
            [str(self.router.path("ram/tmp")), str(self.router.path("bin")), *args],
            timeout=timeout,
        )

    def mount(self, target: str = TARGET, parser: Path = PARSER) -> ShellResult:
        return self.run(
            'cfmgr_io_test "$@"\n',
            [
                str(self.router.path("ram/tmp")),
                str(self.router.path("bin")),
                "mount",
                target,
                str(parser),
                str(self.router.path("work/input")),
            ],
        )

    def topology(self, target: str = TARGET) -> ShellResult:
        return self.run(
            'cfmgr_io_test "$@"\n',
            [
                str(self.router.path("ram/tmp")),
                str(self.router.path("bin")),
                "topology",
                target,
                str(PARSER),
                str(self.router.path("work/input")),
            ],
        )

    def consumer(self, ledger: bytes, *, mode: str = "select") -> ShellResult:
        """Validate captured bytes without repeating producer/workspace integration.

        Only acquisition and its already-verified status are replaced. The real
        consumer reads the staged files, checks fields/framing and uses real wc
        through _cfmgr_io_size, including NUL-sensitive original byte counts.
        """
        self.router.path("work/0.out").write_bytes(snapshot(MOUNTS))
        self.router.path("work/1.out").write_bytes(ledger)
        return self.run(
            "set -f\nLC_ALL=C; export LC_ALL\nIFS=' \t\n'\n"
            "_io_tab='\t'; _io_lf='\n'\n"
            "_io_stage=$1; _io_wc=/usr/bin/wc\n"
            "cfmgr_io_capture() { return 0; }\n"
            "_cfmgr_io_capture_status() { _io_producer=0; _io_err_bytes=0; }\n"
            '_cfmgr_io_mount_capture "$2" "$3" "$4" 0 1 "$5" || exit "$?"\n'
            'printf "%s" "$_mount_ledger"\n',
            [
                str(self.router.path("work")),
                TARGET,
                str(PARSER),
                str(self.router.path("work/input")),
                mode,
            ],
        )

    def calls(self) -> list[dict]:
        return [
            json.loads(path.read_text()) for path in self.router.path("work/calls").glob("*.json")
        ]

    def observations(self) -> list[dict]:
        return [
            json.loads(path.read_text())
            for path in self.router.path("work/calls").glob("*.observation")
        ]

    def clean(self) -> None:
        assert not list(self.router.path("ram/tmp").glob("cfmgr-io.*"))
        assert self.router.read("ram/foreign") == "preserve foreign target"


@pytest.fixture
def io(router: RouterHarness, request: pytest.FixtureRequest) -> IOFixture:
    return IOFixture(router, getattr(request, "param", "/bin/sh"))


def quiet(result: ShellResult, status: int) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == ""


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_capture_binary_status_and_private_permissions(io: IOFixture) -> None:
    out, err = b"A\x00B\n", b"synthetic error\n"
    io.settings.update(stdout_hex=out.hex(), stderr_hex=err.hex(), producer_status=7)
    io.save()
    result = io.workspace(
        "cfmgr_io_capture 0 128 128 cat produce || return 1\n"
        'IFS= read -r record < "$1/0.status" || return 1\n'
        '[ "$record" = "capture\t7\t4\t16" ] || return 1\n'
        "return 7"
    )
    quiet(result, 7)
    observed = io.observations()[0]
    assert observed["stage_mode"] == 0o700
    for name, data in [("0.out", out), ("0.err", err)]:
        record = observed["files"][name]
        assert record["mode"] == 0o600 and record["bytes"] == len(data)
        assert record["sha256"] == hashlib.sha256(data).hexdigest()
    assert observed["files"]["0.status"]["mode"] == 0o600
    io.clean()


@pytest.mark.parametrize(
    ("out_size", "err_size", "out_limit", "err_limit", "status"),
    [
        (0, 0, 0, 0, 0),
        (512, 0, 512, 0, 0),
        (513, 0, 513, 0, 0),
        (65536, 0, 65536, 0, 0),
        (0, 65536, 0, 65536, 0),
        (513, 0, 512, 0, 1),
        (0, 513, 0, 512, 1),
        (1, 0, 0, 1, 1),
        (8193, 0, 4096, 0, 1),
    ],
)
def test_exact_stream_limits_and_conservative_rounding(
    io: IOFixture,
    out_size: int,
    err_size: int,
    out_limit: int,
    err_limit: int,
    status: int,
) -> None:
    io.settings.update(stdout_hex=(b"o" * out_size).hex(), stderr_hex=(b"e" * err_size).hex())
    io.save()
    quiet(
        io.workspace('cfmgr_io_capture 0 "$2" "$3" cat produce', str(out_limit), str(err_limit)),
        status,
    )
    observation = io.observations()[0]
    for name in ["0.out", "0.err"]:
        assert (
            observation["files"][name]["bytes"] <= ((max(out_limit, err_limit) + 512) // 512) * 1024
        )
    io.clean()


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_failed_slot_is_consumed_and_never_reused(io: IOFixture) -> None:
    io.settings.update(stdout_hex=b"overflow".hex())
    io.save()
    quiet(
        io.workspace(
            "cfmgr_io_capture 0 1 1 cat produce; first=$?\n"
            "cfmgr_io_capture 0 128 128 cat produce; second=$?\n"
            '[ "$first" = 1 ] && [ "$second" = 1 ]'
        ),
        0,
    )
    assert len([call for call in io.calls() if call["tool"] == "cat"]) == 1
    io.clean()


def test_sixteen_slots_bound_capture_files(io: IOFixture) -> None:
    # Use native no-fault wc/printf here to avoid 64 Python dispatcher launches.
    io.router.path("bin/wc").unlink()
    io.router.path("bin/wc").symlink_to("/usr/bin/wc")
    io.router.path("bin/printf").unlink()
    io.router.path("bin/printf").symlink_to("/usr/bin/printf")
    quiet(
        io.workspace(
            'i=0\nwhile [ "$i" -lt 16 ]; do\n'
            'cfmgr_io_capture "$i" 0 0 cat produce || return 1; i=$((i+1)); done\n'
            'cfmgr_io_capture 16 0 0 cat produce; [ "$?" = 2 ]',
            timeout=45,
        ),
        0,
    )
    assert len(io.observations()[0]["files"]) == 48
    assert len([call for call in io.calls() if call["tool"] == "cat"]) == 16
    io.clean()


@pytest.mark.parametrize("kind", ["file", "symlink", "directory"])
@pytest.mark.parametrize("collisions", [2, 8])
def test_collisions_are_bounded_and_foreign_paths_preserved(
    io: IOFixture, kind: str, collisions: int
) -> None:
    io.settings.update(collisions=collisions, collision_kind=kind)
    io.save()
    quiet(io.workspace("return 0"), 0 if collisions < 8 else 1)
    stages = list(io.router.path("ram/tmp").glob("cfmgr-io.*"))
    assert len(stages) == collisions
    assert len([call for call in io.calls() if call["tool"] == "mkdir"]) == min(8, collisions + 1)
    assert io.router.read("ram/foreign") == "preserve foreign target"
    for path in stages:
        if kind == "directory":
            assert (path / "foreign").read_text() == "preserve"
        elif kind == "file":
            assert path.read_text() == "foreign"
        else:
            assert path.is_symlink() and path.read_text() == "preserve foreign target"


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_preexisting_capture_symlink_is_not_followed(io: IOFixture) -> None:
    quiet(
        io.workspace(
            'ln -s "$2" "$1/0.out" || return 1\ncfmgr_io_capture 0 128 128 cat produce',
            str(io.router.path("ram/foreign")),
        ),
        1,
    )
    # ln is fixture setup from fixed host PATH; capture's producer never runs.
    assert not any(call["tool"] == "cat" for call in io.calls())
    io.clean()


@pytest.mark.parametrize("tool", ["mkdir", "rm", "wc", "printf", "cat"])
def test_missing_required_tool_fails_quietly(io: IOFixture, tool: str) -> None:
    io.router.path(f"bin/{tool}").unlink()
    quiet(io.workspace("cfmgr_io_capture 0 128 128 cat produce"), 1)
    io.clean()


@pytest.mark.parametrize(
    ("tool", "mode"),
    [
        ("mkdir", "error"),
        ("mkdir", "readonly"),
        ("wc", "error"),
        ("wc", "invalid"),
        ("printf", "error"),
        ("printf", "partial-metadata"),
        ("printf", "nul-metadata"),
    ],
)
def test_io_and_metadata_failures_are_not_valid_captures(
    io: IOFixture, tool: str, mode: str
) -> None:
    io.settings["modes"][tool] = mode
    io.save()
    quiet(io.workspace("cfmgr_io_capture 0 128 128 cat produce"), 1)
    io.clean()


def test_ulimit_setup_failure_never_launches_producer(io: IOFixture) -> None:
    quiet(
        io.workspace("cfmgr_io_capture 0 128 128 cat produce", prefix="ulimit() { return 1; }\n"), 1
    )
    assert not any(call["tool"] == "cat" for call in io.calls())
    assert io.observations()[0]["files"]["0.status"]["bytes"] == 0
    io.clean()


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_native_mount_parser_handoff_and_cleanup(io: IOFixture) -> None:
    result = io.mount()
    assert result.returncode == 0
    assert result.stdout == oracle(MOUNTS, TARGET) and result.stderr == ""
    calls = io.calls()
    assert any(
        call["tool"] == "awk"
        and call["args"][:2] == ["-v", f"cfmgr_mountinfo_size={len(snapshot(MOUNTS))}"]
        for call in calls
    )
    io.clean()


@pytest.mark.parametrize(
    ("data", "target", "status"),
    [
        (b"", TARGET, 1),
        (b"invalid\n", TARGET, 1),
        (snapshot(MOUNTS)[:-1], TARGET, 1),
        (snapshot([Mount("1", point=b"/other")]), TARGET, 3),
        (snapshot([*MOUNTS, Mount("3")]), TARGET, 1),
        (snapshot(MOUNTS), "relative", 2),
    ],
)
def test_snapshot_acquisition_and_parser_failure_statuses(
    io: IOFixture, data: bytes, target: str, status: int
) -> None:
    path = io.router.path("work/input")
    path.write_bytes(data)
    path.chmod(0o600)
    quiet(io.mount(target), status)
    io.clean()


def test_oversized_acquired_snapshot_fails(io: IOFixture) -> None:
    # Simulate a native producer larger than the private fixture file budget.
    io.settings["modes"]["cat"] = "produce-large"
    io.router.fake_tool("cat", "printf '%65537s' x\n")
    quiet(io.mount(), 1)
    io.clean()


def mutated_ledger(index: int, value: bytes) -> bytes:
    """Preserve valid framing so malformed fields must fail their own checks."""
    fields = oracle(MOUNTS, TARGET).encode().split(b"\n")[0].split(b"\t")
    fields[index] = value
    body = b"\t".join(fields) + b"\n"
    return body + f"end\t{len(body)}\n".encode()


BAD_LEDGERS = [
    b"",
    b"mount\n",
    oracle(MOUNTS, TARGET).encode()[:-1],
    oracle(MOUNTS, TARGET).encode().split(b"\n")[0] + b"\n",
    oracle(MOUNTS, TARGET).encode() + b"extra\n",
    oracle(MOUNTS, TARGET).encode() + b"\x00",
    oracle(MOUNTS, TARGET).encode().replace(b"mount\t", b"mount\x00\t"),
    oracle(MOUNTS, TARGET).encode().replace(b"end\t", b"end\t0"),
    mutated_ledger(1, b"02"),
    mutated_ledger(1, b"0"),
    mutated_ledger(1, b"9" * 21),
    mutated_ledger(2, b"-1"),
    mutated_ledger(2, b"00"),
    mutated_ledger(3, b"8:01"),
    mutated_ledger(3, b"8:1:2"),
    mutated_ledger(4, b"2f2e2e"),
    mutated_ledger(5, b"2f2f"),
    mutated_ledger(6, b"bad/type"),
    mutated_ledger(6, b".ext4"),
    mutated_ledger(7, b""),
    mutated_ledger(7, b"gg"),
    mutated_ledger(8, b"00"),
    mutated_ledger(9, b"a"),
    mutated_ledger(10, b"2f2e"),
]


def test_consumer_accepts_complete_mount_ledger(io: IOFixture) -> None:
    expected = oracle(MOUNTS, TARGET).encode()
    result = io.consumer(expected)
    assert result.returncode == 0 and result.stdout.encode() == expected and result.stderr == ""
    assert io.calls() == []
    io.clean()


@pytest.mark.parametrize("ledger", BAD_LEDGERS)
def test_parser_zero_exit_requires_complete_exact_framing_and_fields(
    io: IOFixture, ledger: bytes
) -> None:
    quiet(io.consumer(ledger), 1)
    assert io.calls() == []
    io.clean()


@pytest.mark.parametrize("tool", ["cat", "awk"])
def test_native_producer_failures_do_not_publish_partial_results(io: IOFixture, tool: str) -> None:
    io.settings["modes"][tool] = "error"
    io.save()
    quiet(io.mount(), 1)
    io.clean()


def test_successful_parser_with_stderr_is_rejected(io: IOFixture) -> None:
    io.settings.update(
        awk_output_hex=oracle(MOUNTS, TARGET).encode().hex(), awk_stderr_hex=b"SECRET".hex()
    )
    io.save()
    quiet(io.mount(), 1)
    io.clean()


def test_cleanup_failure_prevents_success_ledger(io: IOFixture) -> None:
    io.settings["modes"]["rm"] = "error"
    io.save()
    quiet(io.mount(), 1)
    stages = list(io.router.path("ram/tmp").glob("cfmgr-io.*"))
    assert len(stages) == 1
    assert (stages[0] / "1.out").read_text() == oracle(MOUNTS, TARGET)


def test_final_publication_failure_is_nonzero_and_remains_incomplete(io: IOFixture) -> None:
    io.settings["modes"]["printf"] = "partial-publication"
    io.save()
    result = io.mount()
    assert result.returncode == 1 and result.stderr == ""
    assert result.stdout and "end\t" not in result.stdout
    io.clean()


@pytest.mark.parametrize("phase", ["mkdir", "cat"])
@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_signal_to_workspace_owner_cleans_known_owned_data(io: IOFixture, phase: str) -> None:
    io.settings["modes"][phase] = "signal" if phase == "mkdir" else "signal-owner"
    io.save()
    quiet(io.workspace("cfmgr_io_capture 0 128 128 cat produce"), 143)
    io.clean()


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_source_and_call_preserve_external_caller_state(io: IOFixture) -> None:
    result = io.run(
        "cfmgr_fixture_callback() { return 0; }\n"
        "IFS=x; SENTINEL=preserved; export SENTINEL; set -f; umask 027; trap ':' TERM\n"
        "before_options=$(set +o); before_trap=$(trap); before_pwd=$PWD\n"
        'cfmgr_io_test "$1" "$2" workspace cfmgr_fixture_callback; result=$?\n'
        '[ "$result" = 0 ] && [ "$IFS" = x ] && [ "$SENTINEL" = preserved ] && '
        '[ "$(umask)" = 0027 ] && [ "$before_options" = "$(set +o)" ] && '
        '[ "$before_trap" = "$(trap)" ] && [ "$before_pwd" = "$PWD" ]\n',
        [str(io.router.path("ram/tmp")), str(io.router.path("bin"))],
    )
    quiet(result, 0)
    io.clean()


def test_production_workspace_uses_fixed_tools_and_forwards_arguments(io: IOFixture) -> None:
    result = io.run(
        "cfmgr_fixture_callback() {\n"
        '[ "$2" = "value with spaces" ] || return 1\n'
        'cfmgr_io_capture 0 128 0 printf "%s\\n" "$2" || return 1\n'
        'IFS= read -r payload < "$1/0.out" || return 1\n'
        '[ "$payload" = "$2" ] || return 1\n'
        'IFS= read -r record < "$1/0.status" || return 1\n'
        '[ "$record" = "capture\t0\t18\t0" ]\n}\n'
        'cfmgr_io_with_workspace "$1" cfmgr_fixture_callback "$2"\n',
        [str(io.router.path("ram/tmp")), "value with spaces"],
    )
    quiet(result, 0)
    # Even inherited _io_tools/fixture PATH cannot select an injected producer.
    assert io.calls() == []
    io.clean()


@pytest.mark.parametrize(
    ("callback", "status", "output"),
    [
        ("return 0", 1, ""),
        ('cfmgr_io_stage_report "report\tok\nend\t10\n"', 0, "report\tok\nend\t10\n"),
        ('cfmgr_io_stage_report "report\tok\nend\t10\n"; return 1', 1, ""),
        ('cfmgr_io_stage_report "☃"', 2, ""),
        ('cfmgr_io_stage_report ""', 2, ""),
        ("cfmgr_io_stage_report first; cfmgr_io_stage_report second", 2, ""),
        ("cfmgr_io_stage_report first; cfmgr_io_stage_report second; return 0", 0, "first"),
    ],
)
def test_report_owner_requires_one_valid_staged_payload(
    io: IOFixture, callback: str, status: int, output: str
) -> None:
    result = io.run(
        "cfmgr_fixture_callback() {\n" + callback + "\n}\n"
        'cfmgr_io_test "$1" "$2" report cfmgr_fixture_callback\n',
        [str(io.router.path("ram/tmp")), str(io.router.path("bin"))],
    )
    assert result.returncode == status and result.stdout == output and result.stderr == ""
    io.clean()


def test_workspace_callback_cannot_stage_report(io: IOFixture) -> None:
    quiet(io.workspace("cfmgr_io_stage_report forbidden"), 2)
    io.clean()


def test_sourcing_only_defines_functions(router: RouterHarness) -> None:
    result = router.run(
        "IFS=x; set -f; umask 027; trap ':' TERM\n"
        "before_options=$(set +o); before_trap=$(trap); before_pwd=$PWD\n"
        f". {shlex.quote(str(SOURCE))}\n"
        '[ "$IFS" = x ] && [ "$(umask)" = 0027 ] && [ "$before_options" = "$(set +o)" ] && '
        '[ "$before_trap" = "$(trap)" ] && [ "$before_pwd" = "$PWD" ]\n'
    )
    quiet(result, 0)
    assert list(router.path("ram/tmp").iterdir()) == []


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_optional_busybox_private_io(busybox_router: RouterHarness) -> None:
    fixture = IOFixture(busybox_router)
    busybox_router.busybox_applets("sh")
    result = busybox_router.run(
        f". {shlex.quote(str(SOURCE))}\n"
        "cfmgr_fixture_callback() { cfmgr_io_capture 0 0 0 cat produce; }\n"
        f"cfmgr_io_test {shlex.quote(str(busybox_router.path('ram/tmp')))} "
        f"{shlex.quote(str(busybox_router.path('bin')))} workspace cfmgr_fixture_callback\n",
        timeout=15,
    )
    quiet(result, 0)
    fixture.clean()
    result = busybox_router.run(
        f'. {shlex.quote(str(SOURCE))}\ncfmgr_io_test "$@"\n',
        [
            str(busybox_router.path("ram/tmp")),
            str(busybox_router.path("bin")),
            "topology",
            TARGET,
            str(PARSER),
            str(busybox_router.path("work/input")),
        ],
        timeout=15,
    )
    assert (
        result.returncode == 0
        and result.stdout == topology_oracle(MOUNTS, TARGET)
        and result.stderr == ""
    )
    fixture.clean()


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_native_topology_handoff_retains_all_facts_and_exact_arguments(io: IOFixture) -> None:
    mounts = [
        Mount("1"),
        Mount(
            "2",
            point=b"/tmp/opt",
            root=b"/entware",
            device="8:1",
            optional=(
                "shared:9007199254740993",
                "master:" + "9" * 20,
                "unbindable",
                "future:value",
            ),
        ),
        Mount("3", point=TARGET.encode() + b"/child"),
    ]
    io.router.path("work/input").write_bytes(snapshot(mounts))
    result = io.topology()
    assert (
        result.returncode == 0
        and result.stdout == topology_oracle(mounts, TARGET)
        and result.stderr == ""
    )
    calls = io.calls()
    assert [call["args"] for call in calls if call["tool"] == "awk"] == [
        [
            "-v",
            f"cfmgr_mountinfo_size={len(snapshot(mounts))}",
            "-v",
            "cfmgr_mountinfo_mode=topology",
            "-f",
            str(PARSER),
        ]
    ]
    io.clean()


def framed_topology(line: bytes) -> bytes:
    body = oracle(MOUNTS, TARGET).encode().split(b"\n")[0] + b"\n" + line + b"\n"
    return body + b"end\t" + str(len(body)).encode() + b"\n"


@pytest.mark.parametrize(
    "mode,ledger",
    [
        pytest.param("mount", BAD_LEDGERS[2], id="missing-final-lf"),
        pytest.param("mount", BAD_LEDGERS[3], id="missing-footer"),
        pytest.param("mount", BAD_LEDGERS[4], id="extra-record"),
        pytest.param("mount", BAD_LEDGERS[5], id="nul-suffix-byte-count"),
        pytest.param("mount", BAD_LEDGERS[6], id="nul-inside-record"),
        pytest.param("mount", BAD_LEDGERS[7], id="footer-count-mismatch"),
        pytest.param("mount", mutated_ledger(1, b"02"), id="mount-field"),
        pytest.param(
            "topology", framed_topology(b"topology\t-\t-\t-\t2\t0\t0"), id="topology-field"
        ),
    ],
)
def test_parser_rejections_are_wired_through_full_capture(
    io: IOFixture, mode: str, ledger: bytes
) -> None:
    io.settings["awk_output_hex"] = ledger.hex()
    io.save()
    quiet(io.topology() if mode == "topology" else io.mount(), 1)
    assert any(call["tool"] == "awk" for call in io.calls())
    io.clean()


@pytest.mark.parametrize(
    "line",
    [
        b"topology\t-\t-\t-\t0\t0\t0",
        b"topology\t9007199254740993\t1\t99999999999999999999\t1\t4096\t1023",
    ],
)
def test_topology_consumer_accepts_supported_facts_without_policy(
    io: IOFixture, line: bytes
) -> None:
    expected = framed_topology(line)
    result = io.consumer(expected, mode="topology")
    assert result.returncode == 0 and result.stdout.encode() == expected and result.stderr == ""
    io.clean()


@pytest.mark.parametrize(
    "line",
    [
        b"topology\t0\t-\t-\t0\t0\t0",
        b"topology\t01\t-\t-\t0\t0\t0",
        b"topology\t" + b"9" * 21 + b"\t-\t-\t0\t0\t0",
        b"topology\t-\t+1\t-\t0\t0\t0",
        b"topology\t-\t-\t\t0\t0\t0",
        b"topology\t-\t-\t-\t2\t0\t0",
        b"topology\t-\t-\t-\t00\t0\t0",
        b"topology\t-\t-\t-\t0\t4097\t0",
        b"topology\t-\t-\t-\t0\t0\t1024",
        b"topology\t-\t-\t-\t0\t01\t0",
        b"topology\t-\t-\t-\t0\t0\t-1",
        b"topology\t-\t-\t-\t0\t" + b"9" * 20 + b"\t0",
        b"topology\t-\t-\t-\t0\t0\t0\t0",
        b"topology\t\t-\t-\t-\t0\t0\t0",
        b"topology\t-\t-\t-\t0\t0\t0\t",
        b"topology\t-\t-\t-\t0\t0\t0\r",
        b"topology\x00\t-\t-\t-\t0\t0\t0",
    ],
)
def test_topology_field_errors_are_rejected_with_correct_footer(io: IOFixture, line: bytes) -> None:
    quiet(io.consumer(framed_topology(line), mode="topology"), 1)
    assert io.calls() == []
    io.clean()


def test_topology_requires_three_records_exact_footer_and_original_bytes(io: IOFixture) -> None:
    proper = topology_oracle(MOUNTS, TARGET).encode()
    lines = proper.splitlines(keepends=True)
    for malformed in (
        proper[:-1],
        proper + b"\n",
        proper + b"\0",
        lines[0] + lines[2],
        lines[0] + lines[1] + lines[1] + lines[2],
        proper.replace(b"end\t", b"end\t0"),
    ):
        quiet(io.consumer(malformed, mode="topology"), 1)
    io.clean()


@pytest.mark.parametrize(
    "producer_status,stderr,status",
    [(1, b"", 1), (2, b"", 2), (3, b"", 3), (7, b"", 1), (0, b"SECRET", 1)],
)
def test_topology_producer_and_stderr_failures_are_quiet(
    io: IOFixture, producer_status: int, stderr: bytes, status: int
) -> None:
    io.settings.update(
        awk_output_hex=topology_oracle(MOUNTS, TARGET).encode().hex(),
        awk_status=producer_status,
        awk_stderr_hex=stderr.hex(),
    )
    io.save()
    quiet(io.topology(), status)
    io.clean()


def test_topology_cleanup_failure_prevents_publication(io: IOFixture) -> None:
    io.settings["modes"]["rm"] = "error"
    io.save()
    quiet(io.topology(), 1)
    assert len(list(io.router.path("ram/tmp").glob("cfmgr-io.*"))) == 1


@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_topology_public_entry_uses_fixed_proc_input_and_preserves_caller(io: IOFixture) -> None:
    expected = topology_oracle(MOUNTS, TARGET)
    result = io.run(
        "_cfmgr_io_mount_capture() {\n"
        '[ "$#" = 6 ] && [ "$3" = /proc/self/mountinfo ] && '
        '[ "$4" = 0 ] && [ "$5" = 1 ] && [ "$6" = topology ] || return 1\n'
        f"_mount_ledger={shlex.quote(expected)}\n}}\n"
        'IFS=x; set -f; umask 027; trap ":" TERM\nbefore=$(trap); options=$(set +o)\n'
        'cfmgr_io_topology_snapshot "$1" "$2" "$3"; code=$?\n'
        '[ "$code" = 0 ] && [ "$IFS" = x ] && [ "$(trap)" = "$before" ] && '
        '[ "$(set +o)" = "$options" ] && [ "$(umask)" = 0027 ]\n',
        [str(io.router.path("ram/tmp")), TARGET, str(PARSER)],
    )
    assert result.returncode == 0 and result.stdout == expected and result.stderr == ""
    assert io.calls() == []
    io.clean()


def test_topology_argument_and_internal_mode_contracts(io: IOFixture) -> None:
    quiet(io.run('cfmgr_io_topology_snapshot "$@"\n', []), 2)
    quiet(io.run('cfmgr_io_topology_snapshot "$@"\n', ["a", "b", "c", "d"]), 2)
    for mode in ("", "unknown"):
        quiet(
            io.run(
                'fixture_capture() { _cfmgr_io_mount_capture "$2" "$3" "$4" 0 1 "$5"; }\n'
                'cfmgr_io_test "$1" "$2" workspace fixture_capture "$3" "$4" "$5" "$6"\n',
                [
                    str(io.router.path("ram/tmp")),
                    str(io.router.path("bin")),
                    TARGET,
                    str(PARSER),
                    str(io.router.path("work/input")),
                    mode,
                ],
            ),
            2,
        )
    assert not any(call["tool"] in {"cat", "awk"} for call in io.calls())
    io.clean()


@pytest.mark.parametrize("explicit_select", [False, True])
@pytest.mark.parametrize("io", SHELLS, indirect=True)
def test_internal_capture_resets_topology_state_for_default_and_select(
    io: IOFixture, explicit_select: bool
) -> None:
    final_capture = '_cfmgr_io_mount_capture "$2" "$3" "$4" 2 3' + (
        " select" if explicit_select else ""
    )
    result = io.run(
        'fixture_capture() {\n_cfmgr_io_mount_capture "$2" "$3" "$4" 0 1 topology || return 1\n'
        + final_capture
        + '\n[ "$?" = 0 ] && [ "$_mount_mode" = select ] && '
        '[ -z "$_mount_topology" ] || return 1\ncfmgr_io_stage_report "$_mount_ledger"\n}\n'
        'cfmgr_io_test "$1" "$2" report fixture_capture "$3" "$4" "$5"\n',
        [
            str(io.router.path("ram/tmp")),
            str(io.router.path("bin")),
            TARGET,
            str(PARSER),
            str(io.router.path("work/input")),
        ],
    )
    assert (
        result.returncode == 0 and result.stdout == oracle(MOUNTS, TARGET) and result.stderr == ""
    )
    io.clean()
