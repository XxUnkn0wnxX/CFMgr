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
from tests.test_storageinfo import BLOCK_LINE

NATIVE_CONFIG = ROOT / "modules/lib/native_config.sh"
DATA_HOSTS = b"127.0.0.1\tlocalhost\\native-data\n"
DATA_RESOLVER = b""
TMP_MOUNT_ID = "905"
TMP_DEVICE = "0:99"
TMP_LIMIT_KIB = 64
TMP_INODE_LIMIT = 8
VIEWS = ("bin", "sbin", "lib", "usr")
SOURCE_MOUNT_ID = "88"
HOST_MOUNT_ID = "1"
VIEW_IDS = {name: str(901 + index) for index, name in enumerate(VIEWS)}
DEVICE_IDS = {"null": "907", "urandom": "908"}
NATIVE_DISPATCHER = r"""
import json
import os
import shutil
import stat
import sys
from pathlib import Path

settings = json.loads(Path(sys.argv[2]).read_text())
state_path = Path(settings["state"])
state = json.loads(state_path.read_text())
tool, args = sys.argv[3], sys.argv[4:]
device_ids = {"null": "907", "urandom": "908"}
log = Path(settings["tool_log"])
if tool == "ls":
    # Captured commands inherit a file-size ceiling. Keep each observation's
    # evidence small instead of appending to the cumulative lifecycle log.
    with log.with_name(f"native-ls-{os.getpid()}.json").open("x") as stream:
        stream.write(json.dumps([tool, args]))
elif tool not in ("readlink", "test"):
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
    if args[:3] == ["-n", "-i", "-t"]:
        if len(args) != 8 or args[3] != "tmpfs" or args[4] != "-o":
            raise AssertionError((tool, args))
        expected_options = (
            f"rw,nosuid,nodev,exec,mode=700,size={settings['limit_kib']}k,"
            f"nr_inodes={settings['inode_limit']}"
        )
        if args[5] != expected_options or args[6] != "cfmgr-tmp":
            raise AssertionError((tool, args))
        target = args[7]
        if target != str(Path(settings["root_target"]) / "tmp"):
            raise AssertionError((tool, args))
        root_row = find_at(settings["root_target"])
        row = dict(root_row)
        row.update(
            identifier=settings["tmp_mount_id"],
            parent=settings["root_mount_id"],
            device=settings["tmp_device"],
            root=b"/".hex(),
            point=os.fsencode(target).hex(),
            options=b"rw,nosuid,nodev,relatime".hex(),
            kind="tmpfs",
            source=b"cfmgr-tmp".hex(),
            super_options=(
                f"rw,size={settings['limit_kib']}k,nr_inodes={settings['inode_limit']},mode=700"
            ).encode().hex(),
            optional=[],
        )
        state["mounts"].append(row)
        state["tmp_mounted"] = True
        publish()
        sys.exit(0)
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
            image_etc = Path(source) / "etc"
            if image_etc.is_dir():
                shutil.copytree(image_etc, Path(target) / "etc", symlinks=True)
                state["mirrored_data_root"] = target
            for name in state["view_ids"]:
                (Path(target) / name).mkdir(mode=0o700, exist_ok=True)
            if settings.get("native_tmp"):
                (Path(target) / "tmp").mkdir(mode=0o700, exist_ok=True)
            if settings.get("native_opt"):
                (Path(target) / "opt").mkdir(mode=0o700, exist_ok=True)
            if settings.get("native_devices"):
                source_dev = Path(source) / "dev"
                target_dev = Path(target) / "dev"
                target_dev.mkdir(mode=0o700, exist_ok=True)
                for name in ("null", "urandom"):
                    os.link(source_dev / name, target_dev / name)
            row = dict(state["ram_mount"])
            row.update(
                identifier=settings["root_mount_id"],
                parent=settings["ram_mount_id"],
                root=(b"/" + str(relative).encode()).hex(),
                point=os.fsencode(target).hex(),
                options=b"rw,relatime".hex(),
                optional=[],
            )
        elif settings.get("native_opt") and target == str(Path(root_target) / "opt"):
            if source != "/proc/self/fd/9":
                raise AssertionError((tool, args))
            row = dict(settings["volume_mount"])
            row.update(
                identifier=settings["opt_mount_id"],
                parent=settings["root_mount_id"],
                point=os.fsencode(target).hex(),
                options=b"rw,relatime".hex(),
                optional=[],
            )
            state["opt_mounted"] = True
        elif settings.get("native_devices") and target in {
            str(Path(root_target) / "dev/null"),
            str(Path(root_target) / "dev/urandom"),
        }:
            name = Path(target).name
            expected_source = str(Path(settings["image_target"]) / "dev" / name)
            if source != expected_source:
                raise AssertionError((tool, args))
            if os.stat(source).st_ino != os.stat(target).st_ino:
                raise AssertionError(("device bind inode mismatch", source, target))
            row = dict(state["ram_mount"])
            row.update(
                identifier=device_ids[name],
                parent=settings["root_mount_id"],
                root=(
                    b"/"
                    + os.fsencode(Path(settings["image_target"]).relative_to(settings["ramroot"]))
                    + b"/dev/"
                    + name.encode()
                ).hex(),
                point=os.fsencode(target).hex(),
                options=bytes.fromhex(state["ram_mount"]["options"]).hex(),
                optional=[],
            )
            state.setdefault("device_mounted", {})[name] = True
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
    if options == "remount,bind,rw,nosuid,nodev,exec" and settings.get("native_opt"):
        row = find_at(target)
        if target != str(Path(root_target) / "opt") or source != "/proc/self/fd/9":
            raise AssertionError((tool, args))
        row["options"] = b"rw,nosuid,nodev,relatime,exec".hex()
        publish()
        sys.exit(0)
    if options == "remount,bind,ro,nosuid,noexec,dev" and settings.get("native_devices"):
        row = find_at(target)
        name = Path(target).name
        if target != str(Path(root_target) / "dev" / name):
            raise AssertionError((tool, args))
        row["options"] = b"ro,nosuid,noexec,relatime".hex()
        state.setdefault("device_mounted", {})[name] = True
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
    if target == state.get("mirrored_data_root"):
        shutil.rmtree(Path(target) / "etc")
        state.pop("mirrored_data_root")
    if target == str(Path(settings["root_target"]) / "tmp") and state.get("tmp_mounted"):
        for child in Path(target).iterdir():
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
        state["tmp_mounted"] = False
    if target == str(Path(settings["root_target"]) / "opt") and state.get("opt_mounted"):
        state["opt_mounted"] = False
    if settings.get("native_devices") and Path(target).name in device_ids:
        state.setdefault("device_mounted", {})[Path(target).name] = False
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
    if args == ["-d", "/proc/self/fd/9"]:
        try:
            sys.exit(0 if stat.S_ISDIR(os.fstat(9).st_mode) else 1)
        except OSError:
            sys.exit(1)
    if len(args) == 2 and args[0] == "-c":
        device = Path(args[1])
        allowed = {"null": "1,3", "urandom": "1,9"}
        if settings.get("native_devices") and device.name in allowed and device.is_file():
            sys.exit(0)
        sys.exit(1)
    if len(args) == 3 and args[1:] in (
        ["-ef", "/proc/self/fd/8"],
        ["-ef", "/proc/self/fd/9"],
    ):
        fd = 8 if args[2].endswith("/8") else 9
        try:
            path_stat = os.stat(args[0])
            fd_stat = os.fstat(fd)
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

if tool == "ls" and args == ["-dnL", "/proc/self/fd/8"]:
    if not stat.S_ISREG(os.fstat(8).st_mode):
        sys.exit(1)
    sys.stdout.write(settings["block_line"])
    sys.exit(0)

if tool == "ls" and len(args) == 2 and args[0] == "-dni" and args[1] in ("null", "urandom"):
    if not settings.get("native_devices"):
        sys.exit(1)
    name = args[1]
    source = Path.cwd() / name
    if not source.is_file():
        sys.exit(1)
    inode = source.stat().st_ino
    if state["fault"] == "metadata-change":
        metadata_calls = sum(
            json.loads(record.read_text())[1][:1] == ["-dni"]
            for record in log.parent.glob("native-ls-*.json")
        )
        if metadata_calls >= 2:
            inode += 1
    minor = "3" if name == "null" else "9"
    sys.stdout.write(f"{inode} crw------- 1 0 0 1, {minor} Jan 1 00:00 {name}\n")
    sys.exit(0)

if tool == "mknod":
    if len(args) != 6 or args[:2] != ["-m", "600"] or args[3] != "c":
        raise AssertionError((tool, args))
    path, major, minor = args[2], args[4], args[5]
    name = Path(path).name
    expected = {"null": ("1", "3"), "urandom": ("1", "9")}
    if (
        not settings.get("native_devices")
        or name not in expected
        or (major, minor) != expected[name]
    ):
        raise AssertionError((tool, args))
    node = Path(path)
    if not node.is_absolute():
        node = Path.cwd() / node
    node.touch(exist_ok=False)
    node.chmod(0o600)
    state.setdefault("device_nodes", {})[name] = {
        "major": major,
        "minor": minor,
        "inode": node.stat().st_ino,
    }
    state_path.write_text(json.dumps(state))
    sys.exit(0)

if tool == "readlink" and len(args) == 2 and args[0] == "-f":
    print(os.path.realpath(args[1]))
    sys.exit(0)

raise AssertionError((tool, args))
"""


class NativeRootFixture(ExecutionRootFixture):
    """Extend the existing stateful root fixture; bare-root defaults stay intact."""

    def __init__(self, router: RouterHarness, fault: str = "") -> None:
        super().__init__(router, fault)
        self.tmp_enabled = False
        self.tmp_limit_kib = TMP_LIMIT_KIB
        self.tmp_inode_limit = TMP_INODE_LIMIT
        self.opt_enabled = False
        self.opt_mount_id = "906"
        self.opt_volume_mount: dict[str, object] = {}
        self.opt_volume_mount_object: Mount | None = None
        self.opt_volume_root: Path | None = None
        self.devices_enabled = False
        self.block_line = BLOCK_LINE.decode("ascii")
        self.source_root = router.path("work/native-source")
        self.source_root.mkdir(mode=0o700)
        self.data_source_root = router.path("work/native-data-source")
        (self.data_source_root / "etc").mkdir(parents=True, mode=0o700)
        hosts = DATA_HOSTS
        if fault == "data-nul":
            hosts = b"127.0.0.1\x00localhost\n"
        (self.data_source_root / "etc/hosts").write_bytes(hosts)
        (self.data_source_root / "etc/resolv.conf").write_bytes(DATA_RESOLVER)
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
        self.mount_objects = [host, ram, source]
        if fault == "source-descendant":
            descendant = Mount(
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
            self.mount_objects.append(descendant)
            self.state["mounts"].append(_mount_row(descendant))
        self.state["ram_mount"] = _mount_row(ram)
        self.state["source_mount"] = _mount_row(source)
        self.state["view_ids"] = VIEW_IDS
        self.save()
        self.mount_input.write_bytes(snapshot([host, ram, source]))
        self.router.write("work/native-dispatch.py", NATIVE_DISPATCHER)
        self._tool("mount", self._native_wrapper("mount"))
        self._tool("umount", self._native_wrapper("umount"))
        self._tool("test", self._native_test_wrapper())
        self._tool("ls", self._native_wrapper("ls"))
        self._tool("readlink", self._native_wrapper("readlink"))
        self._tool("mknod", self._native_wrapper("mknod"))

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
            'if [ "$#" -eq 2 ] && [ "$1" = -d ]; then\n'
            '    case "$2" in /proc/self/fd/6|/proc/self/fd/9)\n'
            f'        exec {python} {dispatcher} {root} {settings} test "$@"\n'
            "    esac\n"
            "fi\n"
            'if [ "$#" -eq 2 ] && [ "$1" = -c ]; then\n'
            f'    exec {python} {dispatcher} {root} {settings} test "$@"\n'
            "fi\n"
            'if [ "$#" -eq 3 ] && [ "$2" = -ef ]; then\n'
            '    case "$3" in /proc/self/fd/6|/proc/self/fd/8|/proc/self/fd/9)\n'
            f'    exec {python} {dispatcher} {root} {settings} test "$@"\n'
            "    esac\n"
            "fi\n"
            'test "$@"\n'
        )

    def prepare(self) -> None:
        super().prepare()
        if self.opt_enabled:
            assert self.opt_volume_root is not None
            assert self.opt_volume_mount_object is not None
            mounts = [*self.mount_objects, self.opt_volume_mount_object]
            self.state["mounts"] = [_mount_row(mount) for mount in mounts]
            self.save()
            self.mount_input.write_bytes(snapshot(mounts))
        settings_path = self.router.path("work/root-settings.json")
        settings = json.loads(settings_path.read_text())
        settings.update(
            source_root=str(self.source_root),
            data_source_root=str(self.data_source_root),
            native_tmp=self.tmp_enabled,
            native_opt=self.opt_enabled,
            native_devices=self.devices_enabled,
            limit_kib=self.tmp_limit_kib,
            inode_limit=self.tmp_inode_limit,
            tmp_mount_id=TMP_MOUNT_ID,
            tmp_device=TMP_DEVICE,
            opt_mount_id=self.opt_mount_id,
            volume_mount=self.opt_volume_mount,
            volume_root=str(self.opt_volume_root or ""),
            block_line=self.block_line,
            root_target=str(self.guard / "execution/root"),
            image_target=str(self.guard / "execution/image"),
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
        data_root: bool = False,
        data_source_root: Path | None = None,
        tmp_root: bool = False,
        devices_root: bool = False,
        limit_kib: int = TMP_LIMIT_KIB,
        inode_limit: int = TMP_INODE_LIMIT,
        focused_query: bool = True,
    ) -> ShellResult:
        with_data = data_root or tmp_root
        self.tmp_enabled = tmp_root
        self.devices_enabled = devices_root
        self.tmp_limit_kib = limit_kib
        self.tmp_inode_limit = inode_limit
        self.prepare()
        if with_data:
            callback_path = self.router.path("work/root-callback.py")
            callback = callback_path.read_text(encoding="utf-8")
            needle = 'base = Path(os.environ["CFMGR_TEST_ROOT"]) / "work"\n'
            assert needle in callback
            check = (
                needle
                + (
                    'if "check-native-data" in args:\n'
                    + '    args.remove("check-native-data")\n'
                    + '    etc = root / "etc"\n'
                    + f'    if (etc / "hosts").read_bytes().hex() != "{DATA_HOSTS.hex()}" or '
                    + f'(etc / "resolv.conf").read_bytes().hex() != "{DATA_RESOLVER.hex()}":\n'
                    + "        sys.exit(94)\n"
                    + '    (base / "callback-data").write_text("staged data visible\\n")\n'
                    if data_root or tmp_root
                    else ""
                )
                + (
                    'if "check-native-tmp" in args:\n'
                    + '    args.remove("check-native-tmp")\n'
                    + '    home = root / "tmp/cfmgr-home"\n'
                    + "    if (not home.is_dir() or home.stat().st_mode & 0o777 != 0o700 "
                    + "or list(home.iterdir())):\n"
                    + "        sys.exit(95)\n"
                    + '    expected_home = os.path.join(os.environ["CFMGR_TEST_ROOT"], "home")\n'
                    + '    if os.environ.get("HOME") != expected_home:\n'
                    + "        sys.exit(96)\n"
                    + '    (base / "callback-tmp").write_text("private home ready\\n")\n'
                    if tmp_root
                    else ""
                )
            )
            callback_path.write_text(callback.replace(needle, check, 1), encoding="utf-8")
        self.fdinfo_input.write_text(
            f"pos:\t0\nflags:\t0100000\nmnt_id:\t{ROOT_MOUNT_ID}\n", encoding="ascii"
        )
        script = (
            f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            + (f". {shlex.quote(str(NATIVE_CONFIG))}\n" if with_data else "")
            + (FOCUSED_ISOLATION_QUERY if focused_query else "")
            + CALLBACK
            + 'exec 7<"$CFMGR_TEST_ROOT/work/fd-seven" '
            + '8<"$CFMGR_TEST_ROOT/work/fd-eight" 9<"$CFMGR_TEST_ROOT/work/fd-nine"\n'
            + 'exec 6<"$CFMGR_TEST_ROOT/work/fd-six"\n'
            + (
                'cfmgr_isolation_native_tmp_root_test "$@"; status=$?\n'
                if tmp_root
                else (
                    'cfmgr_isolation_native_data_root_test "$@"; status=$?\n'
                    if data_root
                    else 'cfmgr_isolation_native_root_test "$@"; status=$?\n'
                )
            )
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
        ]
        if with_data:
            paths.append(str(data_source_root or self.data_source_root))
        if tmp_root:
            paths.extend([str(limit_kib), str(inode_limit)])
        paths.extend(
            [
                str(MOUNT_PARSER),
                str(STORAGE_PARSER),
                "fixture_callback",
                f"status-{callback_status}",
                *callback_args,
            ]
        )
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
def test_actual_busybox_native_devices_keep_entware_data_and_home_observable(
    busybox_router: RouterHarness,
) -> None:
    assert busybox_router.busybox is not None
    from tests.test_entware_root import run_native_opt

    fixture, _storage, result = run_native_opt(
        busybox_router,
        shell=str(busybox_router.busybox),
        callback_status=0,
        callback_args=("arg with spaces", "*"),
        focused_query=False,
        devices_root=True,
    )
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == ("RESULT\t0\nFDIDENT\t1\t1\nFDSTATE\toriginal-seven\toriginal-six\n")
    observation = json.loads(fixture.router.read("work/entware-callback.json"))
    ledger = observation["root_ledger"].splitlines()
    assert ledger[0].startswith("mount\t900\t")
    assert ledger[1].split("\t")[6] == "8"
    assert observation["args"][:2] == [
        "arg with spaces",
        "*",
    ]
    assert (fixture.guard / "execution/image/etc/hosts").read_bytes() == DATA_HOSTS
    assert (fixture.guard / "execution/image/etc/resolv.conf").read_bytes() == DATA_RESOLVER
    assert set(observation["device_nodes"]) == {"null", "urandom"}
    for name, node in observation["device_nodes"].items():
        assert node[1] == node[2]
        assert (fixture.guard / f"execution/mounted-{name}").is_file()
    assert (
        (fixture.guard / "execution/mounted-tmp")
        .read_text()
        .startswith(f"mount\t{TMP_MOUNT_ID}\t{ROOT_MOUNT_ID}\t{TMP_DEVICE}\t")
    )
    assert (
        (fixture.guard / "execution/mounted-opt").read_text().startswith("mount\t906\t900\t8:1\t")
    )
    assert not (fixture.guard / "execution/root/etc").exists()


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
    ("layout", "mutation", "expected", "checked"),
    [
        ("native", "valid", 0, "root bin sbin lib usr"),
        ("native", "saved-bin-id", 1, "root bin"),
        ("native-tmp", "valid", 0, "root bin sbin lib usr tmp"),
        ("native-tmp", "tmp-child-changed", 1, "root bin sbin lib usr tmp"),
    ],
    ids=[
        "native-positive-control",
        "native-count-four-but-child-ledger-changed",
        "native-tmp-positive-control",
        "native-tmp-count-five-but-saved-tmp-ledger-changed",
    ],
)
def test_native_layout_check_requires_each_saved_child_ledger(
    router: RouterHarness, layout: str, mutation: str, expected: int, checked: str
) -> None:
    guard = router.path("work/native-layout-guard")
    guard.mkdir()
    (guard / "execution").mkdir()
    root_dir = router.path("work/native-layout-root")
    for name in VIEWS:
        (root_dir / name).mkdir(parents=True)
    if layout == "native-tmp":
        (root_dir / "tmp/cfmgr-home").mkdir(parents=True, mode=0o700)
    tools = router.path("work/native-layout-tools")
    tools.mkdir()
    test_tool = router.write(
        "work/native-layout-tools/test", '#!/bin/sh\ntest "$@"\n', executable=True
    )
    query_log = router.path("work/native-layout-queries")
    query_log.write_text("", encoding="ascii")
    root_path_hex = os.fsencode(root_dir).hex()
    root_body = f"mount\t900\t77\t0:77\t2f\t{root_path_hex}\ttmpfs\t746d706673\t"
    root_body += "726f2c6e6f737569642c6e6f646576\t7277\t2f696d616765"
    image_target_hex = root_body.rsplit("\t", 1)[1]
    root_topology = f"topology\t-\t-\t-\t0\t0\t{5 if layout == 'native-tmp' else 4}"

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
            f"mount\t{VIEW_IDS[name]}\t900\t0:88\t{source_point}\t{root_path_hex}2f{name_hex}"
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
    actual_tmp = ""
    tmp_source_common = ""
    if layout == "native-tmp":
        tmp_path_hex = root_path_hex + "2f746d70"
        tmp_topology = "topology\t-\t-\t-\t0\t0\t0"
        tmp_source_common = "\t".join(
            [
                "mount",
                "88",
                "1",
                "0:88",
                "2f",
                "2f736f75726365",
                "squashfs",
                "2f6465762f726f",
                "726f2c72656c6174696d65",
                "726f",
            ]
        )
        tmp_fallback = framed(
            root_body.rsplit("\t", 1)[0] + f"\t{image_target_hex}2f746d70", tmp_topology
        )
        tmp_mounted_body = (
            f"mount\t{TMP_MOUNT_ID}\t900\t{TMP_DEVICE}\t2f\t{tmp_path_hex}"
            f"\ttmpfs\t63666d67722d746d70\t72772c6e6f737569642c6e6f646576"
            "\t72772c73697a653d36346b2c6e725f696e6f6465733d382c6d6f64653d373030\t2f"
        )
        saved_tmp_ledger = framed(tmp_mounted_body, tmp_topology)
        if mutation == "tmp-child-changed":
            tmp_mounted_body = tmp_mounted_body.replace(
                f"mount\t{TMP_MOUNT_ID}\t", "mount\t906\t", 1
            )
        actual_tmp = framed(tmp_mounted_body, tmp_topology)
        for name, value in (
            ("intent-tmp", "tmp\n"),
            ("fallback-tmp", tmp_fallback),
            ("mounted-tmp", saved_tmp_ledger),
        ):
            router.write(f"work/native-layout-guard/{name}", value)
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_io_tab='\t'; _io_lf='\n'; _io_wc=/usr/bin/wc; _isolation_test=$1\n"
        f"_isolation_guard={shlex.quote(str(guard))}; "
        f"_isolation_tree={shlex.quote(str(root_dir))}\n"
        "_execution_native_count=4; _execution_mount_id=900; _isolation_ram_id=77\n"
        f"_execution_layout={layout}; _execution_tmp_ready=1; _execution_tmp_kib=64; "
        "_execution_tmp_inodes=8\n"
        f"_execution_tmp_home={shlex.quote(str(root_dir / 'tmp/cfmgr-home'))}\n"
        "_execution_base_body=$2\n"
        f"_execution_root_ledger={shlex.quote(root_ledger)}\n"
        + (
            f"_execution_tmp_fallback_ledger={shlex.quote(tmp_fallback)}\n"
            f"_execution_tmp_mounted_ledger={shlex.quote(saved_tmp_ledger)}\n"
            "_execution_native_ids='901 902 903 904'; _execution_device=0:77\n"
            f"_execution_native_source_common={shlex.quote(tmp_source_common)}\n"
            if layout == "native-tmp"
            else ""
        )
        + "_execution_bin_record=$3; _execution_sbin_record=$4; "
        "_execution_lib_record=$5; _execution_usr_record=$6\n"
        "_actual_bin=$7; _actual_sbin=$8; _actual_lib=$9; _actual_usr=${10}; _actual_tmp=${11}\n"
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
        "      tmp) _isolation_ledger=$_actual_tmp ;;\n"
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
    result = router.run(
        script, [str(test_tool), root_body, *records, *actual_mounts, actual_tmp], timeout=3
    )
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
    ("layout", "expected"),
    [("legacy", 1), ("native", 1), ("native-data", 1), ("native-tmp", 1)],
    ids=["old-ceiling", "native-ceiling", "native-data-ceiling", "native-tmp-ceiling"],
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
    mode = "bare" if layout == "legacy" else layout
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
