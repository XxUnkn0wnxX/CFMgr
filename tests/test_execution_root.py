"""Checked execution-root entry with inert, stateful mount and unmount doubles."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.isolation_helpers import FOCUSED_ISOLATION_QUERY
from tests.test_mountinfo import Mount, snapshot
from tests.test_storage import IO, STORAGE

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/isolation.sh"
MOUNT_PARSER = ROOT / "modules/mountinfo.awk"
STORAGE_PARSER = ROOT / "modules/storageinfo.awk"
ROOT_MOUNT_ID = "900"
RAM_MOUNT_ID = "77"

DISPATCHER = r"""
import json
import os
import subprocess
import sys
from pathlib import Path

settings = json.loads(Path(sys.argv[2]).read_text())
state_path = Path(settings["state"])
state = json.loads(state_path.read_text())
tool, args = sys.argv[3], sys.argv[4:]
log = Path(settings["tool_log"])

def mountinfo_bytes(rows):
    escaped = {32: b"\\040", 9: b"\\011", 10: b"\\012", 92: b"\\134"}
    records = []
    for row in rows:
        def field(name):
            value = bytes.fromhex(row[name])
            return b"".join(escaped.get(byte, bytes([byte])) for byte in value)
        fields = [
            row["identifier"].encode(), row["parent"].encode(), row["device"].encode(),
            field("root"), field("point"), bytes.fromhex(row["options"]),
            *(value.encode() for value in row["optional"]), b"-", row["kind"].encode(),
            field("source"), bytes.fromhex(row["super_options"]),
        ]
        records.append(b" ".join(fields) + b"\n")
    return b"".join(records)

with log.open("a") as stream:
    stream.write(json.dumps([tool, args]) + "\n")

if tool == "mount":
    if args[:3] != ["-n", "-i", "-o"] or len(args) < 5:
        raise AssertionError((tool, args))
    option_arg = args[3]
    if option_arg == "bind" and len(args) == 6:
        image, target = args[-2:]
        relative = Path(image).relative_to(Path(settings["ramroot"]))
        root = b"/" + str(relative).encode()
        row = dict(state["ram_mount"])
        row.update(
            identifier=settings["root_mount_id"],
            parent=settings["ram_mount_id"],
            root=root.hex(),
            point=os.fsencode(target).hex(),
            options=b"rw,relatime".hex(),
            optional=[],
        )
        state["mounts"].append(row)
    elif option_arg == "make-private" and len(args) == 5:
        pass
    elif option_arg == "remount,bind,ro,nosuid,nodev,exec" and len(args) == 6:
        row = next(row for row in state["mounts"] if row["identifier"] == settings["root_mount_id"])
        row["options"] = b"ro,nosuid,nodev,relatime".hex()
    else:
        raise AssertionError((tool, args))
    state_path.write_text(json.dumps(state))
    Path(settings["mount_input"]).write_bytes(mountinfo_bytes(state["mounts"]))
    sys.exit(0)

if tool == "umount":
    if args == ["--help"]:
        sys.stdout.buffer.write(
            b"BusyBox v1.36.1 (fixture) multi-call binary.\n\n"
            b"Usage: umount [OPTIONS] FILESYSTEM|DIRECTORY\n\n"
            b"\t-d\tFree loop device if it has been used\n"
        )
        sys.exit(0)
    if len(args) != 2 or args[0] != "-n":
        raise AssertionError((tool, args))
    if state["fault"] != "umount-busy":
        state["mounts"] = [
            row
            for row in state["mounts"]
            if row["identifier"] != settings["root_mount_id"]
        ]
        state_path.write_text(json.dumps(state))
        Path(settings["mount_input"]).write_bytes(mountinfo_bytes(state["mounts"]))
    sys.exit(0)

if tool == "test":
    if args == ["-d", "/proc/self/fd/6"]:
        try:
            import stat

            sys.exit(0 if stat.S_ISDIR(os.fstat(6).st_mode) else 1)
        except OSError:
            sys.exit(1)
    if len(args) == 3 and args[1:] == ["-ef", "/proc/self/fd/6"]:
        try:
            path = os.stat(args[0])
            fd = os.fstat(6)
        except OSError:
            sys.exit(1)
        sys.exit(0 if (path.st_dev, path.st_ino) == (fd.st_dev, fd.st_ino) else 1)
    sys.exit(subprocess.call(["/usr/bin/test", *args]))

if tool == "readlink":
    if len(args) == 2 and args[0] == "-f":
        print(os.path.realpath(args[1]))
        sys.exit(0)
    sys.exit(2)

raise AssertionError((tool, args))
"""


def _mount_row(mount: Mount) -> dict[str, object]:
    return {
        "identifier": mount.identifier,
        "parent": mount.parent,
        "device": mount.device,
        "root": mount.root.hex(),
        "point": mount.point.hex(),
        "options": mount.options.hex(),
        "kind": mount.kind,
        "source": mount.source.hex(),
        "super_options": mount.super_options.hex(),
        "optional": list(mount.optional),
    }


CALLBACK = r"""
fixture_callback() {
    : >"$CFMGR_TEST_ROOT/work/callback-entered"
    case ${3-} in
        exit-owner)
            exit 0
            ;;
    esac
    "$PYTHON" "$CFMGR_TEST_ROOT/work/root-callback.py" "$@"
}
"""

CALLBACK_SCRIPT = r"""
import os
import stat
import sys
from pathlib import Path

root = Path(sys.argv[1])
ledger = sys.argv[2]
args = sys.argv[3:]
lease = os.fstat(6)
directory = os.stat(root)
if not stat.S_ISDIR(lease.st_mode) or (lease.st_dev, lease.st_ino) != (
    directory.st_dev,
    directory.st_ino,
):
    sys.exit(91)
if any(not stat.S_ISREG(os.fstat(fd).st_mode) for fd in (7, 8, 9)):
    sys.exit(92)
if not ledger.startswith("mount\t900\t"):
    sys.exit(93)
if "signal-term" in args:
    import signal

    args.remove("signal-term")
    (Path(os.environ["CFMGR_TEST_ROOT"]) / "work/term-sent").write_text("sent\n")
    os.kill(os.getppid(), signal.SIGTERM)
status = 0
if args and args[0].startswith("status-"):
    status = int(args.pop(0)[7:])
base = Path(os.environ["CFMGR_TEST_ROOT"]) / "work"
(base / "callback-root").write_text(str(root) + "\n")
(base / "callback-ledger").write_text(ledger + "\n")
(base / "callback-args").write_text("".join(f"<{arg}>\n" for arg in args))
sys.exit(status)
"""


class ExecutionRootFixture:
    def __init__(self, router: RouterHarness, fault: str = "") -> None:
        self.router = router
        self.ramroot = router.path("ram/tmp")
        self.guard = self.ramroot / "cfmgr-execution-guard"
        self.guard.mkdir(mode=0o700)
        self.tools = router.path("work/execution-tools")
        self.tools.mkdir(mode=0o700)
        self.image = self.guard / "execution/image"
        self.mount_input = router.path("work/root-mountinfo")
        self.fdinfo_input = router.path("work/root-fdinfo")
        self.state_path = router.path("work/root-state.json")
        self.tool_log = router.path("work/root-tools.jsonl")
        self.callback_root = router.path("work/callback-root")
        self.callback_ledger = router.path("work/callback-ledger")
        self.callback_args = router.path("work/callback-args")

        ram_mount = Mount(
            identifier=RAM_MOUNT_ID,
            parent="0",
            device="0:77",
            root=b"/",
            point=str(self.ramroot).encode(),
            options=b"rw,relatime",
            kind="tmpfs",
            source=b"tmpfs",
            super_options=b"rw",
        )
        self.state: dict[str, object] = {
            "fault": fault,
            "mounts": [_mount_row(ram_mount)],
            "ram_mount": _mount_row(ram_mount),
        }
        self.save()
        self.mount_input.write_bytes(snapshot([ram_mount]))
        self.fdinfo_input.write_text(
            f"pos:\t0\nflags:\t0100000\nmnt_id:\t{ROOT_MOUNT_ID}\n", encoding="ascii"
        )
        self.tool_log.write_text("", encoding="utf-8")
        if router.busybox is not None:
            router.busybox_applets("[", "test", "printf")
        router.write("work/root-callback.py", CALLBACK_SCRIPT)
        router.write("work/root-dispatch.py", DISPATCHER)
        self._tool("mount", self._wrapper("mount"))
        self._tool("umount", self._wrapper("umount"))
        self._tool("mkdir", '#!/bin/sh\nexec /bin/mkdir "$@"\n')
        rm_script = "#!/bin/sh\n"
        if fault == "io-cleanup-fails":
            complete = shlex.quote(str(self.guard / "execution/complete"))
            rm_script += (
                "for argument do case $argument in *cfmgr-io.*) "
                f"[ ! -d {complete} ] || exit 7 ;; esac; done\n"
            )
        rm_script += 'exec /bin/rm "$@"\n'
        self._tool("rm", rm_script)
        for name in ("printf",):
            self._tool(name, f'#!/bin/sh\nexec /usr/bin/{name} "$@"\n')
        self._tool("test", self._wrapper("test"))
        self._tool("readlink", self._wrapper("readlink"))
        (self.tools / "[").symlink_to(self.tools / "test")
        for name, candidates in {
            "awk": ("/usr/bin/awk", "/usr/bin/nawk"),
            "cat": ("/bin/cat", "/usr/bin/cat"),
            "wc": ("/usr/bin/wc", "/bin/wc"),
        }.items():
            target = next((Path(path) for path in candidates if Path(path).exists()), None)
            if target is not None:
                (self.tools / name).symlink_to(target)

    def _tool(self, name: str, content: str) -> None:
        self.router.write(f"work/execution-tools/{name}", content, executable=True)

    def _wrapper(self, tool: str) -> str:
        return (
            "#!/bin/sh\nexec "
            + shlex.quote(sys.executable)
            + " "
            + shlex.quote(str(self.router.path("work/root-dispatch.py")))
            + " "
            + shlex.quote(str(ROOT))
            + " "
            + shlex.quote(str(self.router.path("work/root-settings.json")))
            + " "
            + shlex.quote(tool)
            + ' "$@"\n'
        )

    def save(self) -> None:
        self.state_path.write_text(json.dumps(self.state), encoding="utf-8")

    def prepare(self) -> None:
        settings = {
            "state": str(self.state_path),
            "tool_log": str(self.tool_log),
            "mount_input": str(self.mount_input),
            "ramroot": str(self.ramroot),
            "root_mount_id": ROOT_MOUNT_ID,
            "ram_mount_id": RAM_MOUNT_ID,
        }
        self.router.path("work/root-settings.json").write_text(json.dumps(settings))

    def run(
        self,
        *,
        shell: str | None = None,
        callback_status: int = 0,
        callback_args: tuple[str, ...] = ("arg with spaces", "*"),
        guard_collision: bool = False,
        malformed: bool = False,
        callback_exits: bool = False,
        fdinfo_mount_id: str = ROOT_MOUNT_ID,
        focused_query: bool = False,
    ) -> ShellResult:
        self.prepare()
        self.fdinfo_input.write_text(
            f"pos:\t0\nflags:\t0100000\nmnt_id:\t{fdinfo_mount_id}\n", encoding="ascii"
        )
        if guard_collision:
            occupied = self.guard / "execution"
            occupied.mkdir(mode=0o700)
            (occupied / "prior-state").write_text("retain", encoding="utf-8")
        prefix = (
            f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            + (FOCUSED_ISOLATION_QUERY if focused_query else "")
            + CALLBACK
            + 'exec 7<"$CFMGR_TEST_ROOT/work/fd-seven" '
            + '8<"$CFMGR_TEST_ROOT/work/fd-eight" 9<"$CFMGR_TEST_ROOT/work/fd-nine"\n'
            + 'exec 6<"$CFMGR_TEST_ROOT/work/fd-six"\n'
            + 'cfmgr_isolation_root_test "$@"; status=$?\n'
            + 'printf "RESULT\\t%s\\n" "$status"\n'
            + "IFS= read -r seven <&7; IFS= read -r eight <&8; IFS= read -r nine <&9; "
            + "IFS= read -r six <&6\n"
            + 'printf "FDSTATE\\t%s\\t%s\\t%s\\t%s\\n" "$seven" "$eight" "$nine" "$six"\n'
        )
        paths = [
            "relative" if malformed else str(self.ramroot),
            str(self.guard),
            str(self.tools),
            str(self.mount_input),
            str(self.fdinfo_input),
            str(MOUNT_PARSER),
            str(STORAGE_PARSER),
            "fixture_callback",
            *(("exit-owner",) if callback_exits else ()),
            f"status-{callback_status}",
            *callback_args,
        ]
        self.router.write("work/fd-six", "original-six\n")
        self.router.write("work/fd-seven", "original-seven\n")
        self.router.write("work/fd-eight", "original-eight\n")
        self.router.write("work/fd-nine", "original-nine\n")
        script = prefix
        if shell is not None:
            invoke = self.router.write("work/invoke-execution-root.sh", script)
            script = f'exec {shlex.quote(shell)} sh "$@"\n'
            paths = [str(invoke), *paths]
        return self.router.run(script, paths, timeout=12, env={"PYTHON": sys.executable})


@pytest.fixture
def execution_root(router: RouterHarness) -> ExecutionRootFixture:
    return ExecutionRootFixture(router)


def _assert_complete(fixture: ExecutionRootFixture, result: ShellResult, status: int) -> None:
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith(
        f"RESULT\t{status}\nFDSTATE\toriginal-seven\toriginal-eight\toriginal-nine\toriginal-six\n"
    )
    execution = fixture.guard / "execution"
    assert (execution / "complete").is_dir()
    assert fixture.guard.is_dir()
    assert fixture.image.is_dir()
    state = json.loads(fixture.state_path.read_text())
    assert [row["identifier"] for row in state["mounts"]] == [RAM_MOUNT_ID]


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_uses_actual_fd_lease_and_completes_without_dropping_guard(
    execution_root: ExecutionRootFixture,
) -> None:
    result = execution_root.run(callback_status=7)
    _assert_complete(execution_root, result, 7)
    assert execution_root.callback_root.read_text().strip() == str(
        execution_root.guard / "execution/root"
    )
    assert execution_root.callback_ledger.read_text().startswith("mount\t900\t")
    assert execution_root.callback_args.read_text() == "<arg with spaces>\n<*>\n"


@pytest.mark.parametrize(
    ("fault", "complete"), [("umount-busy", False), ("io-cleanup-fails", True)]
)
@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_uncertainty_retains_guard_at_cleanup_boundary(
    router: RouterHarness, fault: str, complete: bool
) -> None:
    fixture = ExecutionRootFixture(router, fault)
    result = fixture.run(callback_status=7, focused_query=True)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.splitlines()[0] == "RESULT\t129"
    assert fixture.guard.is_dir()
    assert (fixture.guard / "execution").is_dir()
    assert (fixture.guard / "execution/complete").is_dir() is complete
    state = json.loads(fixture.state_path.read_text())
    mounted = ROOT_MOUNT_ID in {row["identifier"] for row in state["mounts"]}
    assert mounted is (fault == "umount-busy")
    if fault == "io-cleanup-fails":
        assert list(fixture.ramroot.glob("cfmgr-io.*"))


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_refuses_guard_collision_before_mounts(
    execution_root: ExecutionRootFixture,
) -> None:
    result = execution_root.run(guard_collision=True)
    assert result.returncode == 0, result
    assert result.stdout.splitlines()[0] == "RESULT\t1"
    assert (execution_root.guard / "execution/prior-state").read_text() == "retain"
    assert execution_root.tool_log.read_text() == ""


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_malformed_api_has_no_mount_or_reservation_effects(
    router: RouterHarness,
) -> None:
    fixture = ExecutionRootFixture(router)
    result = fixture.run(malformed=True)
    assert result.returncode == 0, result
    assert result.stdout.splitlines()[0] == "RESULT\t2"
    assert fixture.tool_log.read_text() == ""
    assert not (fixture.guard / "execution").exists()


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_production_entry_clears_fixture_tool_selectors(
    router: RouterHarness,
) -> None:
    ramroot = router.path("ram/tmp")
    guard = ramroot / "production-boundary-guard"
    guard.mkdir(mode=0o700)
    observed = router.path("work/production-selector")
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_io_tools=/fixture/poison; _isolation_tools=/fixture/poison\n"
        "_cfmgr_isolation_tool() { "
        f'printf \'%s\\t%s\\t%s\\n\' "$1" "$_io_tools" '
        f'"$_isolation_tools" >{shlex.quote(str(observed))}; '
        "return 1; }\n"
        f"cfmgr_isolation_root_with {shlex.quote(str(ramroot))} "
        f"{shlex.quote(str(guard))} {shlex.quote(str(MOUNT_PARSER))} "
        f"{shlex.quote(str(STORAGE_PARSER))} fixture_callback\n"
        'printf "RESULT\\t%s\\n" "$?"\n'
    )
    result = router.run(script, timeout=3)
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\n"
    assert result.stderr == ""
    assert observed.read_text() == "mount\t\t\n"
    assert not (guard / "execution").exists()


@pytest.mark.parametrize(
    "mutation",
    [
        "valid",
        "id",
        "parent",
        "device",
        "filesystem",
        "mount-root",
        "fs-target",
        "source",
        "peer",
        "child",
    ],
    ids=[
        "admitted",
        "changed-id",
        "changed-parent",
        "changed-device",
        "changed-fs",
        "changed-root",
        "changed-target",
        "changed-source",
        "propagation-peer",
        "submount",
    ],
)
@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_root_mount_policy_rejects_changed_identity_or_nonprivate_topology(
    router: RouterHarness, mutation: str
) -> None:
    root_hex = b"/cfmgr-execution/image".hex()
    point_hex = b"/ram/guard/execution/root".hex()
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        f"_io_tab='\t'; _execution_source_root={root_hex}\n"
        "_execution_device=0:77; _execution_fs=tmpfs; _execution_super=7277; "
        "_isolation_super=7277; _isolation_ram_id=77\n"
        "_isolation_id=900; _isolation_parent=77; _isolation_device=0:77\n"
        "_isolation_fs=tmpfs; _isolation_mount_root=$_execution_source_root\n"
        "_isolation_fs_target=$_execution_source_root; _source_hex=746d706673\n"
        "_execution_source=746d706673\n"
        '_isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-${_io_tab}0${_io_tab}0${_io_tab}0"\n'
        "case $1 in\n"
        "id) _isolation_id=77 ;; parent) _isolation_parent=78 ;;\n"
        "device) _isolation_device=0:78 ;; filesystem) _isolation_fs=ext4 ;;\n"
        f"mount-root) _isolation_mount_root={b'/changed'.hex()} ;; "
        f"fs-target) _isolation_fs_target={b'/elsewhere'.hex()} ;;\n"
        "source) _source_hex=646576746d706673 ;;\n"
        'peer) _isolation_topology="topology${_io_tab}10'
        '${_io_tab}-${_io_tab}-${_io_tab}0${_io_tab}0${_io_tab}0" ;;\n'
        'child) _isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-'
        '${_io_tab}0${_io_tab}0${_io_tab}1" ;;\n'
        "esac\n"
        f'_isolation_body="mount${{_io_tab}}900${{_io_tab}}77${{_io_tab}}0:77${{_io_tab}}{root_hex}${{_io_tab}}{point_hex}${{_io_tab}}tmpfs${{_io_tab}}$_source_hex${{_io_tab}}726f2c6e6f737569642c6e6f6465762c72656c6174696d65${{_io_tab}}7277${{_io_tab}}{root_hex}"\n'
        "if _cfmgr_isolation_root_mount_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [mutation], timeout=3)
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{0 if mutation == 'valid' else 1}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("descriptor", "expected"),
    [("same-directory", 0), ("regular-file", 1), ("other-directory", 1)],
)
def test_root_fd_action_checks_open_directory_identity(
    router: RouterHarness, descriptor: str, expected: int
) -> None:
    fixture = ExecutionRootFixture(router)
    fixture.prepare()
    tree = router.path("work/fd-tree")
    other = router.path("work/fd-other")
    regular = router.path("work/fd-regular")
    tree.mkdir()
    other.mkdir()
    regular.write_text("not a directory\n", encoding="ascii")
    fd_path = {
        "same-directory": tree,
        "regular-file": regular,
        "other-directory": other,
    }[descriptor]
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "cfmgr_io_capture() { return 0; }\n"
        "_cfmgr_storage_ok() { return 0; }\n"
        "_cfmgr_storage_parse() { _storage_value=900; return 0; }\n"
        "_execution_mount_id=900; _isolation_storage_parser=$4\n"
        "_execution_fdinfo=$5; _isolation_tree=$1; _isolation_test=$3/test\n"
        'exec 6<"$2"\n'
        "if _cfmgr_isolation_root_fd_action; then status=0; else status=$?; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(
        script,
        [
            str(tree),
            str(fd_path),
            str(fixture.tools),
            str(STORAGE_PARSER),
            str(fixture.fdinfo_input),
        ],
        timeout=3,
    )
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{expected}\n"
    assert result.stderr == ""


@pytest.mark.parametrize(
    ("mount_options", "super_options", "expected"),
    [
        (b"ro,nosuid,nodev,relatime", b"rw", 0),
        (b"rw,nosuid,nodev,relatime", b"rw", 1),
        (b"ro,nosuid,noexec,nodev,relatime", b"rw", 1),
        (b"ro,suid,nodev,relatime", b"rw", 1),
        (b"ro,nosuid,nodev,relatime", b"ro", 1),
    ],
    ids=["readonly-nosuid-nodev-exec", "writable", "noexec", "suid", "readonly-superblock"],
)
@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_root_image_mount_flags_are_checked_as_tokens(
    router: RouterHarness, mount_options: bytes, super_options: bytes, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        'if _cfmgr_isolation_image_options "$1" "$2"; then status=0; else status=1; fi\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [mount_options.hex(), super_options.hex()], timeout=3)
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("outcome", "expected_status", "active_after"),
    [
        ("status0", 0, False),
        ("status1", 129, True),
        ("status143", 129, True),
        ("interrupted-success", 129, True),
    ],
)
def test_root_native_call_clears_active_only_after_uninterrupted_success(
    router: RouterHarness, outcome: str, expected_status: int, active_after: bool
) -> None:
    ramroot = router.path("ram/tmp")
    guard = ramroot / "native-call-guard"
    guard.mkdir(mode=0o700)
    work = router.path("work/native-call")
    work.mkdir()
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_isolation_guard=$1; _isolation_printf=/usr/bin/printf; _isolation_rm=/bin/rm\n"
        "_io_wc=/usr/bin/wc; _io_lf='\n'; _isolation_interrupted=0\n"
        "native_action() {\n"
        '  IFS= read -r active <"$_isolation_guard/active" || return 90\n'
        '  printf \'%s\\n\' "$active" >"$2/native-active"\n'
        "  case $1 in\n"
        "    status0) return 0 ;;\n"
        "    status1) return 1 ;;\n"
        "    status143) return 143 ;;\n"
        "    interrupted-success) _isolation_interrupted=1; return 0 ;;\n"
        "  esac\n"
        "}\n"
        'if _cfmgr_isolation_root_call native native_action "$3" "$2"; '
        "then status=0; else status=$?; fi\n"
        'if [ -e "$_isolation_guard/active" ]; then active=1; else active=0; fi\n'
        'printf "RESULT\\t%s\\t%s\\n" "$status" "$active"\n'
    )
    result = router.run(script, [str(guard), str(work), outcome], timeout=3)
    assert result.returncode == 0, result
    active_value = int(active_after)
    assert result.stdout == f"RESULT\t{expected_status}\t{active_value}\n"
    assert (work / "native-active").read_text() == "native\n"
    if active_after:
        assert (guard / "active").read_text() == "native\n"
    else:
        assert not (guard / "active").exists()


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_early_callback_exit_zero_is_uncertain(router: RouterHarness) -> None:
    fixture = ExecutionRootFixture(router)
    result = fixture.run(callback_exits=True, focused_query=True)
    assert result.returncode == 0, result
    assert result.stdout.splitlines()[0] == "RESULT\t129"
    assert router.path("work/callback-entered").is_file()
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution/complete").exists()
    state = json.loads(fixture.state_path.read_text())
    assert ROOT_MOUNT_ID in {row["identifier"] for row in state["mounts"]}


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_term_signal_keeps_mounted_root_uncertain(router: RouterHarness) -> None:
    fixture = ExecutionRootFixture(router)
    result = fixture.run(callback_args=("signal-term",), focused_query=True)
    assert result.returncode == 0, result
    assert result.stdout.splitlines()[0] == "RESULT\t129"
    assert router.path("work/callback-entered").is_file()
    assert router.path("work/term-sent").read_text() == "sent\n"
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution/complete").exists()
    state = json.loads(fixture.state_path.read_text())
    assert ROOT_MOUNT_ID in {row["identifier"] for row in state["mounts"]}
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    assert not any(tool == "umount" and args != ["--help"] for tool, args in calls)


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_rejects_fdinfo_mount_id_mismatch_before_callback(
    execution_root: ExecutionRootFixture,
) -> None:
    result = execution_root.run(fdinfo_mount_id="901", focused_query=True)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert not execution_root.callback_root.exists()
    assert not (execution_root.guard / "execution/complete").exists()
    state = json.loads(execution_root.state_path.read_text())
    assert ROOT_MOUNT_ID in {row["identifier"] for row in state["mounts"]}


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_execution_root_callback_137_is_uncertain_and_retains_mount(
    execution_root: ExecutionRootFixture,
) -> None:
    result = execution_root.run(callback_status=137, focused_query=True)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert execution_root.callback_root.exists()
    assert execution_root.guard.is_dir()
    assert not (execution_root.guard / "execution/complete").exists()
    state = json.loads(execution_root.state_path.read_text())
    assert ROOT_MOUNT_ID in {row["identifier"] for row in state["mounts"]}


@pytest.mark.integration
@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_execution_root_preserves_callback_and_fd_lease(
    busybox_router: RouterHarness,
) -> None:
    assert busybox_router.busybox is not None
    fixture = ExecutionRootFixture(busybox_router)
    result = fixture.run(shell=str(busybox_router.busybox), callback_status=0)
    _assert_complete(fixture, result, 0)
    assert fixture.callback_ledger.read_text().startswith("mount\t900\t")
