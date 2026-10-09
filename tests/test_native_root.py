"""Fixed native firmware views inside the checked execution root."""

from __future__ import annotations

import json
import os
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.isolation_helpers import FOCUSED_ISOLATION_QUERY
from tests.test_execution_root import (
    CALLBACK,
    MOUNT_PARSER,
    RAM_MOUNT_ID,
    ROOT,
    ROOT_MOUNT_ID,
    SOURCE,
    STORAGE_PARSER,
    ExecutionRootFixture,
    _mount_row,
)
from tests.test_mountinfo import Mount, snapshot
from tests.test_storage import IO, STORAGE

VIEWS = ("bin", "sbin", "lib", "usr")
SOURCE_MOUNT_ID = "88"
HOST_MOUNT_ID = "1"
VIEW_IDS = {name: str(901 + index) for index, name in enumerate(VIEWS)}
NATIVE_DISPATCHER = r"""
import json
import os
import stat
import sys
from pathlib import Path

settings = json.loads(Path(sys.argv[2]).read_text())
state_path = Path(settings["state"])
state = json.loads(state_path.read_text())
tool, args = sys.argv[3], sys.argv[4:]
log = Path(settings["tool_log"])
with log.open("a") as stream:
    stream.write(json.dumps([tool, args]) + "\n")

def mountinfo_bytes(rows):
    escaped = {32: b"\\040", 9: b"\\011", 10: b"\\012", 92: b"\\134"}
    def field(name, row):
        return b"".join(escaped.get(byte, bytes([byte])) for byte in bytes.fromhex(row[name]))
    records = []
    for row in rows:
        fields = [
            row["identifier"].encode(), row["parent"].encode(), row["device"].encode(),
            field("root", row), field("point", row), bytes.fromhex(row["options"]),
            *(value.encode() for value in row["optional"]), b"-", row["kind"].encode(),
            field("source", row), bytes.fromhex(row["super_options"]),
        ]
        records.append(b" ".join(fields) + b"\n")
    return b"".join(records)

def publish():
    state_path.write_text(json.dumps(state))
    Path(settings["mount_input"]).write_bytes(mountinfo_bytes(state["mounts"]))

def find_at(point):
    encoded = os.fsencode(point).hex()
    return next(row for row in state["mounts"] if row["point"] == encoded)

if tool == "mount":
    if args[:3] != ["-n", "-i", "-o"] or len(args) < 5:
        raise AssertionError((tool, args))
    options = args[3]
    root_target = settings["root_target"]
    source_root = settings["source_root"]
    if options == "make-private" and len(args) == 5:
        target = args[4]
        row = find_at(target)
        row["optional"] = []
        publish()
        sys.exit(0)
    if len(args) != 6:
        raise AssertionError((tool, args))
    source, target = args[4:]
    if options == "bind":
        if target == root_target:
            relative = Path(source).relative_to(Path(settings["ramroot"]))
            for name in state["view_ids"]:
                (Path(target) / name).mkdir(mode=0o700, exist_ok=True)
            row = dict(state["ram_mount"])
            row.update(
                identifier=settings["root_mount_id"],
                parent=settings["ram_mount_id"],
                root=(b"/" + str(relative).encode()).hex(),
                point=os.fsencode(target).hex(),
                options=b"rw,relatime".hex(),
                optional=[],
            )
        else:
            name = Path(target).name
            if name not in state["view_ids"] or target != str(Path(root_target) / name):
                raise AssertionError((tool, args))
            expected_source = str(Path(source_root) / name)
            if source != expected_source:
                raise AssertionError((tool, args))
            relative = Path(source).relative_to(Path(source_root))
            row = dict(state["source_mount"])
            row.update(
                identifier=state["view_ids"][name],
                parent=settings["root_mount_id"],
                root=(b"/" + str(relative).encode()).hex(),
                point=os.fsencode(target).hex(),
                options=bytes.fromhex(state["source_mount"]["options"]).hex(),
                optional=[],
            )
            fault = state["fault"]
            if fault == f"wrong-parent:{name}":
                row["parent"] = "779"
            elif fault == f"wrong-device:{name}":
                row["device"] = "0:889"
            elif fault == f"wrong-source:{name}":
                row["source"] = b"/dev/other".hex()
            elif fault == f"extra-child:{name}":
                extra = dict(row)
                extra.update(
                    identifier="990",
                    parent=row["identifier"],
                    root=b"/extra".hex(),
                    point=os.fsencode(target + "/extra").hex(),
                )
                state["mounts"].append(extra)
        state["mounts"].append(row)
        publish()
        sys.exit(0)
    if options == "remount,bind,ro,nosuid,nodev,exec":
        row = find_at(target)
        row["options"] = b"ro,nosuid,nodev,relatime".hex()
        name = Path(target).name
        fault = state["fault"]
        if fault == f"replaced-child:{name}" and target != root_target:
            row["identifier"] = "991"
        if fault == f"remount-error:{name}":
            sys.exit(7)
        publish()
        sys.exit(0)
    raise AssertionError((tool, args))

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
    target = args[1]
    fault = state["fault"]
    if fault == "unmount-busy:" + Path(target).name:
        sys.exit(0)
    state["mounts"] = [row for row in state["mounts"] if row["point"] != os.fsencode(target).hex()]
    if fault == "fallback-change:" + Path(target).name:
        fallback = next(
            row for row in state["mounts"] if row["identifier"] == settings["root_mount_id"]
        )
        fallback["device"] = "0:777"
    publish()
    sys.exit(0)

if tool == "test":
    if args == ["-d", "/proc/self/fd/6"]:
        try:
            sys.exit(0 if stat.S_ISDIR(os.fstat(6).st_mode) else 1)
        except OSError:
            sys.exit(1)
    if len(args) == 3 and args[1:] == ["-ef", "/proc/self/fd/6"]:
        try:
            path_stat = os.stat(args[0])
            fd_stat = os.fstat(6)
        except OSError:
            sys.exit(1)
        same_inode = (path_stat.st_dev, path_stat.st_ino) == (fd_stat.st_dev, fd_stat.st_ino)
        sys.exit(0 if same_inode else 1)
    negate = args[:1] == ["!"]
    if negate:
        args = args[1:]
    try:
        if len(args) == 2 and args[0] in ("-d", "-e", "-f", "-L"):
            info = os.lstat(args[1]) if args[0] == "-L" else os.stat(args[1])
            result = {
                "-d": stat.S_ISDIR(info.st_mode),
                "-e": True,
                "-f": stat.S_ISREG(info.st_mode),
                "-L": stat.S_ISLNK(info.st_mode),
            }[args[0]]
        elif len(args) == 3 and args[1] == "-ef":
            left, right = os.stat(args[0]), os.stat(args[2])
            result = (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)
        else:
            raise AssertionError((tool, args))
    except OSError:
        result = False
    sys.exit(0 if result != negate else 1)

raise AssertionError((tool, args))
"""


class NativeRootFixture(ExecutionRootFixture):
    """Extend the existing stateful root fixture; bare-root defaults stay intact."""

    def __init__(self, router: RouterHarness, fault: str = "") -> None:
        super().__init__(router, fault)
        self.source_root = router.path("work/native-source")
        self.source_root.mkdir(mode=0o700)
        for name in VIEWS:
            path = self.source_root / name
            if fault == "source-alias" and name == "bin":
                path.symlink_to("usr", target_is_directory=True)
            else:
                path.mkdir(mode=0o700)
                (path / "source-marker").write_text(name + "\n", encoding="ascii")
        host = Mount(
            identifier=HOST_MOUNT_ID,
            parent="0",
            device="0:1",
            root=b"/",
            point=b"/",
            options=b"rw,relatime",
            kind="tmpfs",
            source=b"host",
            super_options=b"rw",
        )
        ram = Mount(
            identifier=RAM_MOUNT_ID,
            parent=HOST_MOUNT_ID,
            device="0:77",
            root=b"/",
            point=str(self.ramroot).encode(),
            options=b"rw,relatime",
            kind="tmpfs",
            source=b"tmpfs",
            super_options=b"rw",
        )
        source_options = b"rw,relatime" if fault == "source-writable" else b"ro,relatime"
        source_super = b"rw" if fault == "source-super-writable" else b"ro"
        source = Mount(
            identifier=SOURCE_MOUNT_ID,
            parent=HOST_MOUNT_ID,
            device="0:88",
            root=b"/",
            point=str(self.source_root).encode(),
            options=source_options,
            kind="squashfs",
            source=b"/dev/firmware",
            super_options=source_super,
        )
        self.state["mounts"] = [_mount_row(host), _mount_row(ram), _mount_row(source)]
        if fault == "source-descendant":
            descendant = _mount_row(
                Mount(
                    identifier="89",
                    parent=SOURCE_MOUNT_ID,
                    device="0:88",
                    root=b"/bin/child",
                    point=os.fsencode(self.source_root / "bin/child"),
                    options=source_options,
                    kind="squashfs",
                    source=b"/dev/firmware",
                    super_options=source_super,
                )
            )
            self.state["mounts"].append(descendant)
        self.state["ram_mount"] = _mount_row(ram)
        self.state["source_mount"] = _mount_row(source)
        self.state["view_ids"] = VIEW_IDS
        self.save()
        self.mount_input.write_bytes(snapshot([host, ram, source]))
        self.router.write("work/native-dispatch.py", NATIVE_DISPATCHER)
        self._tool("mount", self._native_wrapper("mount"))
        self._tool("umount", self._native_wrapper("umount"))
        self._tool("test", self._native_test_wrapper())

    def _native_wrapper(self, tool: str) -> str:
        return (
            "#!/bin/sh\nexec "
            + shlex.quote(sys.executable)
            + " "
            + shlex.quote(str(self.router.path("work/native-dispatch.py")))
            + " "
            + shlex.quote(str(ROOT))
            + " "
            + shlex.quote(str(self.router.path("work/root-settings.json")))
            + " "
            + shlex.quote(tool)
            + ' "$@"\n'
        )

    def _native_test_wrapper(self) -> str:
        python = shlex.quote(sys.executable)
        dispatcher = shlex.quote(str(self.router.path("work/native-dispatch.py")))
        root = shlex.quote(str(ROOT))
        settings = shlex.quote(str(self.router.path("work/root-settings.json")))
        return (
            "#!/bin/sh\n"
            'if [ "$#" -eq 2 ] && [ "$1" = -d ] && '
            '[ "$2" = /proc/self/fd/6 ]; then\n'
            f'    exec {python} {dispatcher} {root} {settings} test "$@"\n'
            "fi\n"
            'if [ "$#" -eq 3 ] && [ "$2" = -ef ] && '
            '[ "$3" = /proc/self/fd/6 ]; then\n'
            f'    exec {python} {dispatcher} {root} {settings} test "$@"\n'
            "fi\n"
            'test "$@"\n'
        )

    def prepare(self) -> None:
        super().prepare()
        settings_path = self.router.path("work/root-settings.json")
        settings = json.loads(settings_path.read_text())
        settings.update(
            source_root=str(self.source_root),
            root_target=str(self.guard / "execution/root"),
            view_ids=VIEW_IDS,
        )
        settings_path.write_text(json.dumps(settings), encoding="utf-8")

    def run_native(
        self,
        *,
        shell: str | None = None,
        callback_status: int = 0,
        callback_args: tuple[str, ...] = ("native args", "*"),
        source_root: Path | None = None,
        focused_query: bool = True,
    ) -> ShellResult:
        self.prepare()
        self.fdinfo_input.write_text(
            f"pos:\t0\nflags:\t0100000\nmnt_id:\t{ROOT_MOUNT_ID}\n", encoding="ascii"
        )
        script = (
            f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            + (FOCUSED_ISOLATION_QUERY if focused_query else "")
            + CALLBACK
            + 'exec 7<"$CFMGR_TEST_ROOT/work/fd-seven" '
            + '8<"$CFMGR_TEST_ROOT/work/fd-eight" 9<"$CFMGR_TEST_ROOT/work/fd-nine"\n'
            + 'exec 6<"$CFMGR_TEST_ROOT/work/fd-six"\n'
            + 'cfmgr_isolation_native_root_test "$@"; status=$?\n'
            + 'printf "RESULT\\t%s\\n" "$status"\n'
            + "IFS= read -r seven <&7; IFS= read -r eight <&8; IFS= read -r nine <&9; "
            + "IFS= read -r six <&6\n"
            + 'printf "FDSTATE\\t%s\\t%s\\t%s\\t%s\\n" "$seven" "$eight" "$nine" "$six"\n'
        )
        source = source_root or self.source_root
        paths = [
            str(self.ramroot),
            str(self.guard),
            str(self.tools),
            str(self.mount_input),
            str(self.fdinfo_input),
            str(source),
            str(MOUNT_PARSER),
            str(STORAGE_PARSER),
            "fixture_callback",
            f"status-{callback_status}",
            *callback_args,
        ]
        for name in ("six", "seven", "eight", "nine"):
            self.router.write(f"work/fd-{name}", f"original-{name}\n")
        if shell is not None:
            invoke = self.router.write("work/invoke-native-root.sh", script)
            script = f'exec {shlex.quote(shell)} sh "$@"\n'
            paths = [str(invoke), *paths]
        return self.router.run(
            script,
            paths,
            timeout=60,
            env={"PYTHON": sys.executable, "CFMGR_NATIVE_ROOT": "1"},
        )


@pytest.fixture
def native_root(router: RouterHarness) -> NativeRootFixture:
    return NativeRootFixture(router)


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_root_completes_fixed_four_views_and_unmounts_in_reverse_order(
    native_root: NativeRootFixture,
) -> None:
    result = native_root.run_native(callback_status=7)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith(
        "RESULT\t7\nFDSTATE\toriginal-seven\toriginal-eight\toriginal-nine\toriginal-six\n"
    )
    assert (native_root.guard / "execution/complete").is_dir()
    assert native_root.callback_root.read_text().strip() == str(
        native_root.guard / "execution/root"
    )
    ledger = native_root.callback_ledger.read_text().splitlines()
    assert ledger[0].startswith("mount\t900\t")
    assert ledger[1].split("\t")[6] == "4"
    assert native_root.callback_args.read_text() == "<native args>\n<*>\n"
    query_slots = sorted(
        (native_root.guard / "execution").glob("query-*"), key=lambda path: int(path.name[6:])
    )
    assert [path.name for path in query_slots] == [f"query-{index}" for index in range(56)]
    for name in VIEWS:
        assert (native_root.guard / f"execution/intent-{name}").read_text() == name + "\n"
        assert (native_root.guard / f"execution/source-{name}").read_text().startswith("mount\t")
        fallback = (native_root.guard / f"execution/fallback-{name}").read_text()
        assert fallback.startswith("mount\t900\t")
        assert (
            (native_root.guard / f"execution/mounted-{name}")
            .read_text()
            .startswith(f"mount\t{VIEW_IDS[name]}\t")
        )
    calls = [json.loads(line) for line in native_root.tool_log.read_text().splitlines()]
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == ["usr", "lib", "sbin", "bin", "root"]
    state = json.loads(native_root.state_path.read_text())
    assert [row["identifier"] for row in state["mounts"]] == [
        HOST_MOUNT_ID,
        RAM_MOUNT_ID,
        SOURCE_MOUNT_ID,
    ]
    assert {VIEW_IDS[name] for name in VIEWS}.isdisjoint(
        {row["identifier"] for row in state["mounts"]}
    )


@pytest.mark.integration
@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_native_root_completes_fixed_views(
    busybox_router: RouterHarness,
) -> None:
    assert busybox_router.busybox is not None
    fixture = NativeRootFixture(busybox_router)
    result = fixture.run_native(shell=str(busybox_router.busybox), focused_query=False)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t0\n")
    ledger = fixture.callback_ledger.read_text().splitlines()
    assert ledger[0].startswith("mount\t900\t")
    assert ledger[1].split("\t")[6] == "4"


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize("fault", ["extra-child:bin", "remount-error:bin"])
def test_native_root_rejects_unmatched_child_topology_without_callback(
    router: RouterHarness, fault: str
) -> None:
    fixture = NativeRootFixture(router, fault)
    result = fixture.run_native()
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert not fixture.callback_root.exists()
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution/complete").exists()
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    mount_calls = [args for tool, args in calls if tool == "mount"]
    if fault == "extra-child:bin":
        assert any(args[3:5] == ["bind", str(fixture.source_root / "bin")] for args in mount_calls)
    else:
        assert any(
            args[3] == "remount,bind,ro,nosuid,nodev,exec"
            and args[-1] == str(fixture.guard / "execution/root/bin")
            for args in mount_calls
        )
    assert not any(tool == "umount" and args != ["--help"] for tool, args in calls)


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_root_rejects_aliased_source_view(
    router: RouterHarness,
) -> None:
    fixture = NativeRootFixture(router, "source-alias")
    result = fixture.run_native()
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert not fixture.callback_root.exists()
    assert fixture.guard.is_dir()
    assert not (fixture.guard / "execution/complete").exists()


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_root_retains_guard_when_child_unmount_is_unproved(
    router: RouterHarness,
) -> None:
    fault = "unmount-busy:usr"
    fixture = NativeRootFixture(router, fault)
    result = fixture.run_native()
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert fixture.callback_root.exists()
    assert fixture.guard.is_dir()
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == ["usr"]


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mutation", "expected"),
    [
        ("valid", 0),
        ("parent", 1),
        ("device", 1),
        ("source", 1),
        ("mount-root", 1),
        ("filesystem-target", 1),
        ("view-id", 1),
        ("extra-child", 1),
    ],
    ids=[
        "positive-control",
        "wrong-parent",
        "wrong-device",
        "wrong-source",
        "wrong-mount-root",
        "wrong-filesystem-target",
        "reused-mount-id",
        "descendant-mount",
    ],
)
def test_native_view_check_requires_the_exact_saved_child_identity(
    router: RouterHarness, mutation: str, expected: int
) -> None:
    source_path = router.path("work/native-source/bin")
    source_path.mkdir(parents=True)
    target_path = router.path("work/native-root/bin")
    target_path.mkdir(parents=True)
    test_tool = router.write("work/native-test", '#!/bin/sh\ntest "$@"\n', executable=True)
    source_hex = os.fsencode(source_path.parent).hex()
    source_target = source_hex + "2f62696e"
    target_hex = os.fsencode(target_path).hex()
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_io_tab='\t'; _io_lf='\n'; _isolation_test=$1\n"
        "_execution_view=bin; _execution_view_hex=62696e; _execution_view_path=$2\n"
        f"_source_expected={b'/dev/firmware'.hex()}; [ $3 != source ] || "
        f"_source_expected={b'/dev/other'.hex()}\n"
        '_execution_view_source_ledger="mount${_io_tab}88${_io_tab}1${_io_tab}0:88${_io_tab}'
        f"{source_hex}${{_io_tab}}{source_hex}${{_io_tab}}squashfs${{_io_tab}}$_source_expected"
        "${_io_tab}726f2c72656c6174696d65${_io_tab}726f${_io_tab}"
        f"{source_target}${{_io_lf}}topology${{_io_tab}}-${{_io_tab}}-${{_io_tab}}-"
        '${_io_tab}0${_io_tab}0${_io_tab}0${_io_lf}end${_io_tab}1${_io_lf}"\n'
        "_execution_mount_id=900; _isolation_ram_id=77\n"
        "_isolation_id=901; _isolation_parent=900; _isolation_device=0:88\n"
        "_isolation_fs=squashfs; _isolation_mount_root="
        f"{source_target}; _isolation_fs_target={source_target}\n"
        f"_isolation_point={target_hex}; _execution_view_path=$2\n"
        "_isolation_options=726f2c6e6f737569642c6e6f646576; _isolation_super=726f\n"
        '_isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-${_io_tab}0${_io_tab}0${_io_tab}0"\n'
        '_isolation_body="mount${_io_tab}901${_io_tab}900${_io_tab}0:88${_io_tab}'
        "$_isolation_mount_root${_io_tab}$_isolation_point${_io_tab}squashfs${_io_tab}"
        f"{b'/dev/firmware'.hex()}${{_io_tab}}$_isolation_options${{_io_tab}}$_isolation_super"
        '${_io_tab}$_isolation_fs_target"\n'
        "case $3 in parent) _isolation_parent=899 ;; device) _isolation_device=0:89 ;;\n"
        "source) : ;;\n"
        f"mount-root) _isolation_mount_root={b'/other'.hex()} ;;\n"
        f"filesystem-target) _isolation_fs_target={b'/other'.hex()} ;;\n"
        "view-id) _isolation_id=88 ;;\n"
        'extra-child) _isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-'
        '${_io_tab}0${_io_tab}0${_io_tab}1" ;;\n'
        "esac\n"
        "if _cfmgr_isolation_native_view_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [str(test_tool), str(target_path), mutation], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mutation", "expected", "checked"),
    [("valid", 0, "root bin sbin lib usr"), ("saved-bin-id", 1, "root bin")],
    ids=["positive-control", "count-four-but-child-ledger-changed"],
)
def test_native_layout_check_requires_each_saved_child_ledger(
    router: RouterHarness, mutation: str, expected: int, checked: str
) -> None:
    guard = router.path("work/native-layout-guard")
    guard.mkdir()
    (guard / "execution").mkdir()
    root_dir = router.path("work/native-layout-root")
    for name in VIEWS:
        (root_dir / name).mkdir(parents=True)
    tools = router.path("work/native-layout-tools")
    tools.mkdir()
    test_tool = router.write(
        "work/native-layout-tools/test", '#!/bin/sh\ntest "$@"\n', executable=True
    )
    query_log = router.path("work/native-layout-queries")
    query_log.write_text("", encoding="ascii")
    root_body = "mount\t900\t77\t0:77\t2f\t2f726f6f74\ttmpfs\t746d706673\t"
    root_body += "726f2c6e6f737569642c6e6f646576\t7277\t2f696d616765"
    root_topology = "topology\t-\t-\t-\t0\t0\t4"

    def framed(body: str, topology: str) -> str:
        return f"{body}\n{topology}\nend\t{len(body) + len(topology) + 2}\n"

    root_ledger = framed(root_body, root_topology)
    view_metadata: dict[str, str] = {}
    actual_ledgers: dict[str, str] = {}
    for name in VIEWS:
        name_hex = name.encode("ascii").hex()
        source_point = f"2f736f757263652f{name_hex}"
        source_body = (
            f"mount\t88\t1\t0:88\t2f\t{source_point}\tsquashfs\t2f6465762f726f"
            f"\t726f2c72656c6174696d65\t726f\t{source_point}"
        )
        source_ledger = framed(source_body, "topology\t-\t-\t-\t0\t0\t0")
        fallback_body = root_body.rsplit("\t", 1)[0] + f"\t2f696d6167652f{name_hex}"
        fallback_ledger = framed(fallback_body, "topology\t-\t-\t-\t0\t0\t0")
        mounted_body = (
            f"mount\t{VIEW_IDS[name]}\t900\t0:88\t{source_point}\t2f726f6f742f{name_hex}"
            f"\tsquashfs\t2f6465762f726f\t726f2c6e6f737569642c6e6f646576\t726f"
            f"\t{source_point}"
        )
        actual_ledger = framed(mounted_body, "topology\t-\t-\t-\t0\t0\t0")
        actual_ledgers[name] = actual_ledger
        saved_mounted_body = mounted_body
        if mutation == "saved-bin-id" and name == "bin":
            saved_mounted_body = mounted_body.replace("mount\t901\t", "mount\t991\t", 1)
        saved_mounted_ledger = framed(saved_mounted_body, "topology\t-\t-\t-\t0\t0\t0")
        record = source_ledger + fallback_ledger + saved_mounted_ledger
        view_metadata[name] = record
        for piece, value in (
            ("source", source_ledger),
            ("fallback", fallback_ledger),
            ("mounted", saved_mounted_ledger),
        ):
            router.write(f"work/native-layout-guard/{piece}-{name}", value)
        router.write(f"work/native-layout-guard/intent-{name}", name + "\n")
    records = [view_metadata[name] for name in VIEWS]
    actual_mounts = [actual_ledgers[name] for name in VIEWS]
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_io_tab='\t'; _io_lf='\n'; _io_wc=/usr/bin/wc; _isolation_test=$1\n"
        f"_isolation_guard={shlex.quote(str(guard))}; "
        f"_isolation_tree={shlex.quote(str(root_dir))}\n"
        "_execution_native_count=4; _execution_mount_id=900; _isolation_ram_id=77\n"
        "_execution_base_body=$2\n"
        f"_execution_root_ledger={shlex.quote(root_ledger)}\n"
        "_execution_bin_record=$3; _execution_sbin_record=$4; "
        "_execution_lib_record=$5; _execution_usr_record=$6\n"
        "_actual_bin=$7; _actual_sbin=$8; _actual_lib=$9; _actual_usr=${10}\n"
        f"_query_log={shlex.quote(str(query_log))}; "
        f"_root_topology={shlex.quote(root_topology)}\n"
        "_cfmgr_isolation_query() {\n"
        '  case $1 in "$_isolation_tree")\n'
        '    printf "root\\n" >>"$_query_log"; _isolation_body=$_execution_base_body; '
        "_isolation_topology=$_root_topology; _isolation_ledger=$_execution_root_ledger ;;\n"
        "  *)\n"
        "    _execution_checked_view=${1##*/}; "
        'printf "%s\\n" "$_execution_checked_view" >>"$_query_log"\n'
        "    case $_execution_checked_view in\n"
        "      bin) _isolation_ledger=$_actual_bin ;; sbin) _isolation_ledger=$_actual_sbin ;;\n"
        "      lib) _isolation_ledger=$_actual_lib ;; usr) _isolation_ledger=$_actual_usr ;;\n"
        "    esac\n"
        '    _isolation_body=${_isolation_ledger%%"$_io_lf"*}\n'
        '    _isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-'
        '${_io_tab}0${_io_tab}0${_io_tab}0"\n'
        "    _old_ifs=$IFS; IFS=$_io_tab; set -- $_isolation_body; IFS=$_old_ifs\n"
        "    _isolation_id=$2; _isolation_parent=$3; _isolation_device=$4; "
        "_isolation_mount_root=$5; _isolation_point=$6; _isolation_fs=$7; "
        "_isolation_options=$9; _isolation_super=${10}; _isolation_fs_target=${11} ;;\n"
        "  esac\n}\n"
        "if _cfmgr_isolation_native_layout_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [str(test_tool), root_body, *records, *actual_mounts], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"
    assert " ".join(query_log.read_text().splitlines()) == checked


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("case", "expected"),
    [
        ("valid", 0),
        ("writable-mount", 1),
        ("writable-superblock", 1),
        ("noexec-superblock", 1),
        ("descendant", 1),
    ],
    ids=[
        "positive-control",
        "writable-source",
        "writable-superblock",
        "noexec",
        "descendant-mount",
    ],
)
def test_native_source_check_rejects_writable_or_mounted_views(
    router: RouterHarness, case: str, expected: int
) -> None:
    source_path = router.path("work/native-source/bin")
    source_path.mkdir(parents=True)
    source_hex = os.fsencode(source_path.parent).hex()
    source_target = source_hex + "2f62696e"
    test_tool = router.write("work/native-test", '#!/bin/sh\ntest "$@"\n', executable=True)
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_io_tab='\t'; _isolation_test=$1; _execution_view=bin; _execution_view_hex=62696e\n"
        "_execution_view_source_path=$2; _execution_kind=fixture\n"
        "_isolation_fs=squashfs; _isolation_options=726f2c72656c6174696d65; _isolation_super=726f\n"
        f"_isolation_fs_target={source_target}; _isolation_mount_root={source_hex}\n"
        '_isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-${_io_tab}0${_io_tab}0${_io_tab}0"\n'
        f'_isolation_body="mount${{_io_tab}}88${{_io_tab}}1${{_io_tab}}0:88${{_io_tab}}{source_hex}'
        f"${{_io_tab}}{source_hex}${{_io_tab}}squashfs${{_io_tab}}{b'/dev/firmware'.hex()}"
        "${_io_tab}726f2c72656c6174696d65${_io_tab}726f${_io_tab}"
        f'{source_target}"\n'
        "_execution_native_source_common=; _execution_native_source_base=\n"
        "case $3 in writable-mount) _isolation_options=7277 ;;\n"
        "writable-superblock) _isolation_super=7277 ;;\n"
        "noexec-superblock) _isolation_super=726f2c6e6f65786563 ;;\n"
        'descendant) _isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-'
        '${_io_tab}0${_io_tab}0${_io_tab}1" ;;\n'
        "esac\n"
        "if _cfmgr_isolation_native_source_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [str(test_tool), str(source_path), case], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("layout", "expected"), [("legacy", 1), ("native", 1)], ids=["old-ceiling", "native-ceiling"]
)
def test_native_query_budget_is_literal_and_bounded(
    router: RouterHarness, layout: str, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_isolation_queries=$1; _isolation_mode=root; _execution_layout=$2\n"
        "if _cfmgr_isolation_query /unconsulted 0; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    query_count = "16" if layout == "legacy" else "64"
    mode = "bare" if layout == "legacy" else "native"
    result = router.run(script, [query_count, mode], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mutation", "expected"),
    [("valid", 0), ("fallback-device", 1)],
    ids=["positive-control", "fallback-changed"],
)
def test_native_view_fallback_requires_the_exact_saved_root(
    router: RouterHarness, mutation: str, expected: int
) -> None:
    view_path = router.path("work/native-root/bin")
    view_path.mkdir(parents=True)
    test_tool = router.write("work/native-test", '#!/bin/sh\ntest "$@"\n', executable=True)
    root_hex = b"/ram/guard/execution/image".hex()
    view_hex = b"/ram/guard/execution/root".hex()
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_io_tab='\t'; _isolation_test=$1; _execution_view=bin; _execution_view_hex=62696e\n"
        f"_execution_view_path=$2; _execution_source_root={root_hex}\n"
        "_device=0:77; [ $3 != fallback-device ] || _device=0:78\n"
        '_execution_base_body="mount${_io_tab}900${_io_tab}77${_io_tab}0:77'
        f"${{_io_tab}}{b'/ram/guard/execution/image'.hex()}"
        f"${{_io_tab}}{b'/ram/guard/execution/root'.hex()}${{_io_tab}}tmpfs"
        f"${{_io_tab}}{b'tmpfs'.hex()}${{_io_tab}}{b'ro,nosuid,nodev,relatime'.hex()}"
        f'${{_io_tab}}{b"rw".hex()}${{_io_tab}}{root_hex}"\n'
        f'_isolation_body="mount${{_io_tab}}900${{_io_tab}}77${{_io_tab}}$_device'
        f"${{_io_tab}}{b'/ram/guard/execution/image'.hex()}${{_io_tab}}{view_hex}"
        f"${{_io_tab}}tmpfs${{_io_tab}}{b'tmpfs'.hex()}"
        f"${{_io_tab}}{b'ro,nosuid,nodev,relatime'.hex()}${{_io_tab}}{b'rw'.hex()}"
        f'${{_io_tab}}{root_hex}2f62696e"\n'
        '_isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-${_io_tab}0${_io_tab}0${_io_tab}0"\n'
        "if _cfmgr_isolation_native_fallback_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [str(test_tool), str(view_path), mutation], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mount_options", "super_options", "expected"),
    [
        (b"ro,relatime", b"ro", 0),
        (b"rw,relatime", b"ro", 1),
        (b"ro,noexec", b"ro", 1),
        (b"ro,relatime", b"rw", 1),
    ],
    ids=["readonly", "writable-mount", "noexec", "writable-superblock"],
)
def test_native_source_policy_requires_readonly_executable_mount(
    router: RouterHarness, mount_options: bytes, super_options: bytes, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        'if _cfmgr_isolation_native_source_options "$1" "$2"; then status=0; else status=1; fi\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [mount_options.hex(), super_options.hex()], timeout=3)
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mount_options", "super_options", "expected"),
    [
        (b"ro,nosuid,nodev,relatime", b"ro", 0),
        (b"rw,nosuid,nodev,relatime", b"ro", 1),
        (b"ro,nosuid,noexec,nodev,relatime", b"ro", 1),
        (b"ro,nosuid,nodev,relatime", b"rw", 1),
    ],
    ids=["positive-control", "writable", "noexec", "writable-superblock"],
)
def test_native_view_options_require_readonly_exec_mount_and_superblock(
    router: RouterHarness, mount_options: bytes, super_options: bytes, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        'if _cfmgr_isolation_native_view_options "$1" "$2"; then status=0; else status=1; fi\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [mount_options.hex(), super_options.hex()], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"
