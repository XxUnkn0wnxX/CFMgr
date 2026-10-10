"""Synthetic owned-root lifecycle; every mount/umount is a stateful double."""

from __future__ import annotations

import json
import os
import shlex
import sys
from dataclasses import asdict, replace
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.isolation_helpers import FOCUSED_ISOLATION_QUERY
from tests.test_closure import PROFILE_FILES, manifest_bytes, native_path
from tests.test_mountinfo import Mount, snapshot
from tests.test_storage import IO, STORAGE, StorageFixture

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/lib/isolation.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]
UMOUNT_HELP = {
    "legacy": b"BusyBox v1.25.1 (fixture) multi-call binary.\n\n"
    b"Usage: umount [OPTIONS] FILESYSTEM|DIRECTORY\n\n"
    b"\t-D\tDon't free loop device even if it has been used\n",
    "modern": b"BusyBox v1.36.1 (fixture) multi-call binary.\n\n"
    b"Usage: umount [OPTIONS] FILESYSTEM|DIRECTORY\n\n"
    b"\t-d\tFree loop device if it has been used\n",
}

# Delegates only existing read-only storage observations to their established
# double. Neither mount nor umount can reach a host executable, even on faults.
DISPATCHER = r"""
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys

sys.path.insert(0, sys.argv[1])

settings_file = Path(sys.argv[2])
settings = json.loads(settings_file.read_text())
tool, args = sys.argv[3], sys.argv[4:]
state_file = Path(settings["state"])
state = json.loads(state_file.read_text())
guard = Path(settings["ram"]) / "cfmgr-isolation"
tree = guard / "root"
fault = settings.get("isolation_fault", "")
log = Path(settings["isolation_log"])
prior = list(log.glob("*.json"))
record = {"tool": tool, "args": args, "sequence": len(prior)}
for fd in (8, 9):
    try:
        held = os.fstat(fd)
        record["fd" + str(fd)] = [held.st_dev, held.st_ino, stat.S_IFMT(held.st_mode)]
    except OSError:
        pass
(log / (str(os.getpid()) + ".json")).write_text(json.dumps(record))


def save():
    state_file.write_text(json.dumps(state))


def snapshot_bytes():
    escape = {32: b"\\040", 9: b"\\011", 10: b"\\012", 92: b"\\134"}

    def field(name, row):
        return b"".join(escape.get(byte, bytes([byte])) for byte in bytes.fromhex(row[name]))

    lines = []
    for row in state["mounts"]:
        fields = [
            row["identifier"].encode(),
            row["parent"].encode(),
            row["device"].encode(),
            field("root", row),
            field("point", row),
            bytes.fromhex(row["options"]),
            *(value.encode() for value in row["optional"]),
            b"-",
            row["kind"].encode(),
            field("source", row),
            bytes.fromhex(row["super_options"]),
        ]
        lines.append(b" ".join(fields) + b"\n")
    return b"".join(lines)


if tool == "mount":
    assert (guard / "active").is_file()
    if args[:4] in (
        ["-n", "-i", "-o", "bind"],
        ["-n", "-i", "-o", "bind,ro"],
    ):
        source, destination = args[4:]
        kind = (
            "null"
            if source == "/dev/null"
            else "image"
            if args[3] == "bind,ro"
            else "opt"
        )
        intent = "opt" if kind == "image" else kind
        assert (guard / ("intent-" + intent)).read_text() == intent + "\n"
        assert destination == str(tree / ("dev/null" if kind == "null" else "opt"))
        if kind == "opt":
            assert source == "/proc/self/fd/9" and "fd9" in record
            held, original = os.fstat(9), os.stat(settings["target"])
            assert (held.st_dev, held.st_ino) == (original.st_dev, original.st_ino)
        if kind == "image":
            assert source == settings["closure_source"]
            assert Path(source).is_dir() and Path(source).parent == guard / "closure"
            assert (guard / "intent-opt").read_text() == "opt\n"
        if fault == "bind-" + kind + "-error":
            sys.exit(7)
        source_path = Path(
            "/dev/null"
            if kind == "null"
            else settings["closure_source"]
            if kind == "image"
            else settings["target"]
        )
        source_row = max(
            (
                row
                for row in state["mounts"]
                if Path(os.fsdecode(bytes.fromhex(row["point"]))) == source_path
                or Path(os.fsdecode(bytes.fromhex(row["point"]))) in source_path.parents
            ),
            key=lambda row: len(Path(os.fsdecode(bytes.fromhex(row["point"]))).parts),
        )
        filesystem_target = Path(
            os.fsdecode(bytes.fromhex(source_row["root"]))
        ) / source_path.relative_to(Path(os.fsdecode(bytes.fromhex(source_row["point"]))))
        row = dict(source_row)
        row.update(
            identifier={"null": "61", "opt": "62", "image": "63"}[kind],
            parent="11",
            root=os.fsencode(filesystem_target).hex(),
            point=os.fsencode(destination).hex(),
            optional=[] if kind == "image" else ["shared:77"],
        )
        state["mounts"].append(row)
        save()
        if fault == "bind-" + kind + "-partial":
            sys.exit(7)
        if fault == "signal-mount":
            os.kill(os.getppid(), signal.SIGTERM)
        sys.exit(0)
    if args[:4] == ["-n", "-i", "-o", "remount,bind,ro,nosuid,nodev,exec"]:
        source, destination = args[4:]
        assert source == settings["closure_source"]
        assert destination == str(tree / "opt")
        row = next(
            item
            for item in state["mounts"]
            if bytes.fromhex(item["point"]) == os.fsencode(destination)
        )
        if fault == "image-remount-identity":
            row["identifier"] = "64"
        elif fault == "image-remount-device":
            row["device"] = "8:999"
        elif fault == "image-remount-rw":
            row["options"] = b"rw,nosuid,nodev,exec".hex()
        elif fault == "image-remount-noexec":
            row["options"] = b"ro,nosuid,nodev,noexec".hex()
        else:
            row["options"] = b"ro,nosuid,nodev,exec".hex()
        save()
        sys.exit(0)
    assert args[:4] == ["-n", "-i", "-o", "make-private"] and len(args) == 5
    destination = args[4]
    if fault == "private-error" or (
        destination == str(tree / "opt") and fault == "private-image-error"
    ):
        sys.exit(7)
    row = next(
        item for item in state["mounts"] if bytes.fromhex(item["point"]) == os.fsencode(destination)
    )
    row["optional"] = []
    if fault == "post-device":
        row["device"] = "8:999"
    if fault == "post-shared":
        row["optional"] = ["shared:99"]
    save()
    sys.exit(0)
if tool == "umount":
    flags = ["-D", "-n"] if settings["umount_profile"] == "legacy" else ["-n"]
    assert args[:-1] == flags
    assert (guard / "active").is_file()
    destination = args[-1]
    assert destination in (str(tree / "opt"), str(tree / "dev/null"))
    if fault == "umount-error" or (
        fault == "umount-null-error" and destination == str(tree / "dev/null")
    ):
        sys.exit(7)
    if fault != "umount-false-success":
        state["mounts"] = [
            item
            for item in state["mounts"]
            if bytes.fromhex(item["point"]) != os.fsencode(destination)
        ]
        save()
        closure_source = settings.get("closure_source")
        if closure_source and destination == str(tree / "opt"):
            image_root = Path(closure_source)
            for directory, children, files in os.walk(image_root, topdown=False):
                for name in files:
                    path = Path(directory) / name
                    if not path.is_symlink():
                        path.chmod(0o600)
                for name in children:
                    path = Path(directory) / name
                    if not path.is_symlink():
                        path.chmod(0o700)
            image_root.chmod(0o700)
    sys.exit(0)
if tool == "cat" and args == [settings["mount_input"]]:
    if fault == "signal-query" and guard.exists():
        owner = int(
            subprocess.check_output(
                ["/bin/ps", "-o", "ppid=", "-p", str(os.getppid())], text=True
            ).strip()
        )
        os.kill(owner, signal.SIGTERM)
    # Faults before removal affect the fresh topology, never a cached record.
    if fault == "source-change" and guard.exists() and not state.get("injected"):
        next(item for item in state["mounts"] if item["identifier"] == "42")["root"] = (
            b"/changed".hex()
        )
        state["injected"] = True
        save()
    if (guard / "mounted-opt").exists() and not state.get("injected"):
        if fault == "missing-intents":
            (guard / "intent-null").unlink()
            (guard / "intent-opt").unlink()
            state["injected"] = True
            save()
        if fault in ("foreign", "stacked", "descendant"):
            row = dict(next(item for item in state["mounts"] if item["identifier"] == "62"))
            row["identifier"] = "99"
            if fault == "foreign":
                state["mounts"] = [item for item in state["mounts"] if item["identifier"] != "62"]
            if fault == "descendant":
                row["point"] += b"/child".hex()
            state["mounts"].append(row)
            state["injected"] = True
            save()
    if (
        fault == "image-descendant"
        and (guard / "closure/opt").is_dir()
        and not state.get("injected")
    ):
        row = dict(next(item for item in state["mounts"] if item["identifier"] == "11"))
        row.update(
            identifier="98",
            parent="11",
            point=os.fsencode(guard / "closure/opt/child").hex(),
        )
        state["mounts"].append(row)
        state["injected"] = True
        save()
    if fault == "probe-error" and any(item["identifier"] == "61" for item in state["mounts"]):
        os.write(2, b"SECRET probe failure\n")
        sys.exit(7)
    os.write(1, snapshot_bytes())
    sys.exit(0)
if tool == "readlink" and len(args) == 2 and args[0] == "-f":
    if args[1] == settings["ram"] and fault == "ram-symlink":
        print(settings["other"])
    else:
        print(str(Path(args[1]).resolve()))
    sys.exit(0)
if tool == "test" and (
    args == ["-c", "/dev/null"]
    or args == ["-c", str(tree / "dev/null")]
    or args == ["/dev/null", "-ef", str(tree / "dev/null")]
):
    sys.exit(1 if fault == "null-type" else 0)
if tool == "test" and args == ["-d", "/proc/self/fd/9"]:
    sys.exit(0 if stat.S_ISDIR(os.fstat(9).st_mode) else 1)
if tool == "test" and args == [settings["target"], "-ef", "/proc/self/fd/9"]:
    current, held = os.stat(args[0]), os.fstat(9)
    sys.exit(0 if (current.st_dev, current.st_ino) == (held.st_dev, held.st_ino) else 1)
if tool == "test":
    sys.exit(subprocess.call(["/bin/test", *args]))
if tool == "chroot":
    record["environment"] = dict(os.environ)
    (log / (str(os.getpid()) + ".json")).write_text(json.dumps(record))
    assert args and args[0] == str(tree)
    assert (guard / "active").read_text().strip() == "probe-" + settings["probe_mode"]
    assert os.readlink(tree / "bootstrap/timeout-coreutils") == "/opt/libexec/timeout-coreutils"
    assert os.readlink(tree / "bootstrap/gzip-gnu") == "/opt/libexec/gzip-gnu"
    assert not (tree / "offline/opt").exists()
    image = next(item for item in state["mounts"] if item["identifier"] == "63")
    record["image_mount"] = image
    (log / (str(os.getpid()) + ".json")).write_text(json.dumps(record))
    assert bytes.fromhex(image["options"]) == b"ro,nosuid,nodev,exec"
    assert bytes.fromhex(image["super_options"]) == b"rw"
    mode = settings["probe_mode"]
    expected = (
        [str(tree), "/bootstrap/timeout-coreutils", "--version"]
        if mode == "timeout"
        else [
            str(tree),
            "/bootstrap/timeout-coreutils",
            "--foreground",
            "--kill-after=1",
            "3",
            "/bootstrap/gzip-gnu",
            "--version",
        ]
    )
    assert args == expected
    output_size = settings.get("probe_output_size", 16)
    os.write(1, b"P" * output_size)
    os.write(2, b"")
    sys.exit(settings.get("probe_child_status", 0))
if tool == "printf":
    if (
        fault == "metadata-short"
        and len(args) == 2
        and args[0] == "%s"
        and args[1].startswith("mount\t")
    ):
        os.write(1, args[1][:-1].encode())
        sys.exit(0)
    if (
        fault == "record-error"
        and len(args) == 2
        and args[0] == "%s"
        and args[1].startswith("mount\t61")
    ):
        state["record_writes"] = state.get("record_writes", 0) + 1
        save()
        if state["record_writes"] == 2:
            sys.exit(7)
    sys.exit(subprocess.call(["/usr/bin/printf", *args]))
if tool == "rm":
    assert args[0] in ("-f", "-rf") and len(args) == 2
    destination = Path(args[1])
    if destination == guard:
        assert not any(
            bytes.fromhex(item["point"]).startswith(os.fsencode(str(guard)) + b"/")
            for item in state["mounts"]
        )
        if fault == "guard-rm-error":
            sys.exit(7)
    else:
        assert destination.name == "active" or destination.name.startswith("cfmgr-io.")
    sys.exit(subprocess.call(["/bin/rm", *args]))
# Existing storage fixture commands remain synthetic; only its awk child is an
# actual parser. Pass retained descriptors through this delegation explicitly.
sys.exit(
    subprocess.call(
        [sys.executable, settings["storage_dispatcher"], str(settings_file), tool, *args],
        pass_fds=tuple(fd for fd in (8, 9) if "fd" + str(fd) in record),
    )
)
"""

# Focused lifecycle evidence: keep the real outer/nested IO owners, retained
# descriptors, stateful observations, parser, framing checks and mutation paths.
# Storage acquisition and bounded captures have their own suites; the explicit
# full-stack roundtrips and query-signal case below still exercise both here.
FOCUSED_BOUNDARIES = (
    r"""
cfmgr_storage_with_test() {
    cfmgr_io_test "$1" "$2" workspace fixture_storage_entry "$@"
}
fixture_storage_entry() {
    _fixture_target=$4
    _fixture_block=$7
    shift 9
    _fixture_begin=$1
    shift
    "$_fixture_begin" "$_fixture_target" "$_fixture_volume" "$@" \
        9<"$_fixture_target" 8<"$_fixture_block"
}
"""
    + FOCUSED_ISOLATION_QUERY
)

CALLBACK = r"""
import json
import os
from pathlib import Path
import signal
import stat
import sys

settings = json.loads(Path(sys.argv[1]).read_text())
root = Path(sys.argv[2])
guard = root.parent
assert root == Path(settings["ram"]) / "cfmgr-isolation/root"
assert (guard / "active").read_text() == "callback\n"
assert all((root / name).is_dir() for name in ("opt", "dev", "bootstrap", "tmp", "offline"))
assert all(
    (root / name).stat().st_mode & 0o777 == 0o700
    for name in ("", "opt", "dev", "bootstrap", "tmp", "offline")
)
assert not (root / "proc").exists() and not (root / "bin").exists()
assert stat.S_ISDIR(os.fstat(9).st_mode)
assert stat.S_ISREG(os.fstat(8).st_mode)  # Explicit fixture-only block mapping.
state = json.loads(Path(settings["state"]).read_text())
assert {row["identifier"] for row in state["mounts"]} >= {"61", "62"}
assert all(not row["optional"] for row in state["mounts"] if row["identifier"] in ("61", "62"))
Path(settings["callback_log"]).write_text(
    json.dumps({"args": sys.argv[2:], "fd9_inode": os.fstat(9).st_ino})
)
os.write(1, b"SECRET ignored callback output\n")
os.write(2, b"SECRET ignored callback error\n")
if settings.get("isolation_fault") == "signal-callback":
    os.kill(os.getppid(), signal.SIGTERM)
sys.exit(settings.get("callback_status", 0))
"""


def encoded(mount: Mount) -> dict:
    fields = asdict(mount)
    for name in ("root", "point", "source", "options", "super_options"):
        fields[name] = fields[name].hex()
    return fields


class IsolationFixture:
    def __init__(self, router: RouterHarness, shell: str, *, probe_busybox: Path | None = None):
        self.probe_busybox = probe_busybox
        self.storage = StorageFixture(router, shell)
        self.router = router
        self.guard = router.path("ram/tmp/cfmgr-isolation")
        self.settings = self.storage.settings
        self.ram = Mount(
            "11",
            point=os.fsencode(router.path("ram/tmp")),
            kind="tmpfs",
            device="0:11",
            source=b"tmpfs",
        )
        self.null = Mount("12", point=b"/dev", kind="tmpfs", device="0:5", source=b"devtmpfs")
        self.mounts = [
            Mount("1", kind="squashfs", options=b"ro", super_options=b"ro"),
            self.ram,
            self.null,
            self.storage.mounts[0],
        ]
        router.path("work/isolation-calls").mkdir(mode=0o700)
        router.write("work/isolation-dispatcher.py", DISPATCHER)
        router.write("work/isolation-callback.py", CALLBACK)
        self.settings.update(
            state=str(router.path("work/state.json")),
            storage_dispatcher=str(router.path("work/dispatcher.py")),
            isolation_log=str(router.path("work/isolation-calls")),
            callback_log=str(router.path("work/callback.observation")),
            umount_profile="modern" if shell == "/bin/dash" else "legacy",
        )
        router.path("work/umount-help").write_bytes(UMOUNT_HELP[self.settings["umount_profile"]])
        self.save()
        for tool in (
            "mount",
            "umount",
            "readlink",
            "test",
            "cat",
            "ls",
            "hexdump",
            "rm",
            "printf",
        ):
            path = router.root / "bin" / tool
            if path.is_symlink():
                path.unlink()
            bypass = ""
            if tool == "printf":
                bypass = 'case $1 in "capture"* | "%b") exec /usr/bin/printf "$@" ;; esac\n'
            elif tool == "umount":
                bypass = (
                    'if [ "$#" = 1 ] && [ "$1" = --help ]; then exec /bin/cat '
                    + shlex.quote(str(router.path("work/umount-help")))
                    + " >&2; fi\n"
                )
            elif tool == "test":
                # Preserve stateful null/FD checks in Python; run ordinary
                # fixture filesystem predicates directly through native test.
                tree_null = shlex.quote(str(self.guard / "root/dev/null"))
                target = shlex.quote(str(self.storage.target))
                bypass = (
                    'if [ "$#" = 2 ] && [ "$1" = "-c" ] && [ "$2" = "/dev/null" ]; then\n'
                    "    :\n"
                    f'elif [ "$#" = 2 ] && [ "$1" = "-c" ] && [ "$2" = {tree_null} ]; then\n'
                    "    :\n"
                    'elif [ "$#" = 3 ] && [ "$1" = "/dev/null" ] && [ "$2" = "-ef" ] && \\\n'
                    f'     [ "$3" = {tree_null} ]; then\n'
                    "    :\n"
                    'elif [ "$#" = 2 ] && [ "$1" = "-d" ] && [ "$2" = "/proc/self/fd/9" ]; then\n'
                    "    :\n"
                    f'elif [ "$#" = 3 ] && [ "$1" = {target} ] && [ "$2" = "-ef" ] && \\\n'
                    '     [ "$3" = "/proc/self/fd/9" ]; then\n'
                    "    :\n"
                    'else exec /bin/test "$@"; fi\n'
                )
            router.fake_tool(
                tool,
                bypass + f"exec {shlex.quote(sys.executable)} "
                f"{shlex.quote(str(router.path('work/isolation-dispatcher.py')))} "
                f"{shlex.quote(str(ROOT))} {shlex.quote(str(self.storage.settings_path))} "
                f'{tool} "$@"\n',
            )
        # No lifecycle case faults these tools or asserts their invocation logs.
        # Keep the actual parser and mkdir, avoiding Python pass-throughs.
        for tool, executable in (("awk", "/usr/bin/awk"), ("mkdir", "/bin/mkdir")):
            path = router.root / "bin" / tool
            path.unlink()
            path.symlink_to(executable)
        router.path("bin/printf").rename(router.path("bin/printf-fault"))

    def save(self) -> None:
        self.storage.save()
        self.router.path("work/state.json").write_text(
            json.dumps({"mounts": [encoded(mount) for mount in self.mounts]})
        )
        self.router.path("work/state.json").chmod(0o600)

    def prepare_probe(self, mode: str = "gzip") -> None:
        """Prepare trusted synthetic closure inputs for the explicit probe API."""
        assert mode in {"timeout", "gzip"}
        profile = "armv7sf-k3.2"
        inputs = self.router.path("work/probe-inputs")
        inputs.mkdir(mode=0o700)
        contents: dict[str, bytes] = {}
        for index, relative in enumerate(PROFILE_FILES[profile], 1):
            data = f"synthetic probe image member {index}\n".encode()
            contents[relative] = data
            if relative.startswith("libexec/"):
                source = inputs / Path(relative).name
            else:
                source = self.storage.target / relative
            source.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
            source.write_bytes(data)
            source.chmod(0o600)
        self.probe_manifest = self.router.path("work/probe-manifest.tsv")
        self.probe_manifest.write_bytes(manifest_bytes(profile, contents))
        self.probe_manifest.chmod(0o600)
        self.probe_timeout = inputs / "timeout-coreutils"
        self.probe_gzip = inputs / "gzip-gnu"
        self.probe_mode = mode
        self.settings.update(
            closure_source=str(self.guard / "closure/opt"),
            probe_mode=mode,
            probe_child_status=0,
            probe_output_size=16,
        )
        self.save()
        for name in ("dd", "env", "openssl", "ln", "chmod", "hexdump"):
            path = self.router.path("bin/" + name)
            if path.exists() or path.is_symlink():
                path.unlink()
            path.symlink_to(native_path(name, self.probe_busybox or self.router.busybox))
        self.router.fake_tool(
            "chroot",
            f"exec {shlex.quote(sys.executable)} "
            f"{shlex.quote(str(self.router.path('work/isolation-dispatcher.py')))} "
            f"{shlex.quote(str(ROOT))} {shlex.quote(str(self.storage.settings_path))} "
            'chroot "$@"\n',
        )
        self.router.path("bin/sleep").symlink_to("/bin/sleep")

    def restore_probe_fixture_permissions(self) -> None:
        """Make only this synthetic image removable by the host fixture teardown."""
        image = self.guard / "closure/opt"
        if not image.is_dir() or image.is_symlink():
            return
        for directory, children, files in os.walk(image, topdown=False):
            for name in files:
                path = Path(directory) / name
                if not path.is_symlink():
                    path.chmod(0o600)
            for name in children:
                path = Path(directory) / name
                if not path.is_symlink():
                    path.chmod(0o700)
        image.chmod(0o700)

    def run_probe(
        self,
        *,
        fault: str = "",
        mode: str = "gzip",
        bad_manifest: bool = False,
    ) -> ShellResult:
        self.prepare_probe(mode)
        self.settings["isolation_fault"] = fault
        self.save()
        if bad_manifest:
            manifest = bytearray(self.probe_manifest.read_bytes())
            digest = manifest.index(b"\t") + 1
            digest = manifest.index(b"\t", digest) + 1
            manifest[digest] = ord("0") if manifest[digest] != ord("0") else ord("1")
            self.probe_manifest.write_bytes(manifest)
        printf = self.router.path("bin/printf")
        if printf.is_symlink():
            printf.unlink()
        printf.symlink_to("/usr/bin/printf")
        self.router.write(
            "work/invoke-probe.sh",
            f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
            f". {shlex.quote(str(ROOT / 'modules/lib/native_digest.sh'))}\n"
            f". {shlex.quote(str(ROOT / 'modules/lib/closure.sh'))}\n"
            f". {shlex.quote(str(ROOT / 'modules/lib/supervision.sh'))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            f"_fixture_volume={shlex.quote(self.storage.expected())}\n"
            + FOCUSED_BOUNDARIES
            + 'cfmgr_isolation_probe_test "$@"\n',
        )
        args = [
            str(self.router.path("ram/tmp")),
            str(self.router.path("bin")),
            str(self.storage.target),
            str(self.router.path("work/mountinfo")),
            str(self.router.path("work/fdinfo")),
            str(self.router.path("work/block")),
            str(ROOT / "modules/lib/mountinfo.awk"),
            str(ROOT / "modules/lib/storageinfo.awk"),
            "armv7sf-k3.2",
            str(self.probe_manifest),
            str(self.probe_timeout),
            str(self.probe_gzip),
            mode,
        ]
        return self.router.run(
            f'exec {shlex.quote(self.storage.shell)} "$@"\n',
            [str(self.router.path("work/invoke-probe.sh")), *args],
            timeout=30,
            env={"IFS": "x"},
        )

    def run(
        self,
        *,
        arguments: tuple[str, ...] = (),
        prefix: str = "",
        suffix: str = "",
        callback: str = "fixture_callback",
        overlap: bool = False,
        callback_exit: bool = False,
        full_stack: bool = False,
    ) -> ShellResult:
        # Only these two cases need the native-write fault double. All other
        # cases still perform real metadata writes with the native printf.
        printf = self.router.root / "bin/printf"
        if printf.is_symlink():
            printf.unlink()
        printf.symlink_to(
            self.router.path("bin/printf-fault")
            if self.settings.get("isolation_fault") in {"metadata-short", "record-error"}
            else "/usr/bin/printf"
        )
        self.router.write(
            "work/invoke-isolation.sh",
            f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
            f". {shlex.quote(str(SOURCE))}\n"
            + (
                ""
                if full_stack
                else f"_fixture_volume={shlex.quote(self.storage.expected())}\n"
                + FOCUSED_BOUNDARIES
            )
            + prefix
            + "fixture_callback() {\n"
            + (self.overlap_body() if overlap else "")
            + f"{shlex.quote(sys.executable)} "
            f"{shlex.quote(str(self.router.path('work/isolation-callback.py')))} "
            f'{shlex.quote(str(self.storage.settings_path))} "$@"\n'
            + ('exit "$?"\n' if callback_exit else 'return "$?"\n')
            + '}\ncfmgr_isolation_test "$@"\n'
            + suffix,
        )
        args = [
            str(self.router.path("ram/tmp")),
            str(self.router.path("bin")),
            str(self.storage.target),
            str(self.router.path("work/mountinfo")),
            str(self.router.path("work/fdinfo")),
            str(self.router.path("work/block")),
            str(ROOT / "modules/lib/mountinfo.awk"),
            str(ROOT / "modules/lib/storageinfo.awk"),
            callback,
            *arguments,
        ]
        return self.router.run(
            f'exec {shlex.quote(self.storage.shell)} "$@"\n',
            [str(self.router.path("work/invoke-isolation.sh")), *args],
            timeout=60,
            env={
                "_isolation_tools": "/opt/SECRET",
                "_isolation_null_recorded": "1",
                "_isolation_callback": "false",
                "_isolation_umount_profile": "modern",
                "IFS": "x",
            },
        )

    def overlap_body(self) -> str:
        args = [
            str(self.router.path("ram/tmp")),
            str(self.router.path("bin")),
            str(self.storage.target),
            str(self.router.path("work/mountinfo")),
            str(self.router.path("work/fdinfo")),
            str(self.router.path("work/block")),
            str(ROOT / "modules/lib/mountinfo.awk"),
            str(ROOT / "modules/lib/storageinfo.awk"),
            "unused_callback",
        ]
        return (
            "cfmgr_isolation_test "
            + " ".join(map(shlex.quote, args))
            + '; [ "$?" = 1 ] || return 7\n'
        )

    def calls(self) -> list[dict]:
        return sorted(
            (
                json.loads(path.read_text())
                for path in self.router.path("work/isolation-calls").glob("*.json")
            ),
            key=lambda item: item["sequence"],
        )

    def mutations(self) -> list[dict]:
        return [item for item in self.calls() if item["tool"] in {"mount", "umount"}]

    def quiet(self, result: ShellResult, status: int = 1) -> None:
        assert result.returncode == status, result
        assert result.stdout == result.stderr == ""
        assert not list(self.router.path("ram/tmp").glob("cfmgr-io.*"))


@pytest.fixture(
    params=[
        "/bin/sh",
        pytest.param(
            "/bin/dash",
            marks=pytest.mark.skipif(not Path("/bin/dash").is_file(), reason="dash unavailable"),
        ),
    ]
)
def isolation(router: RouterHarness, request: pytest.FixtureRequest) -> IsolationFixture:
    return IsolationFixture(router, request.param)


def test_owned_root_roundtrip_uses_retained_storage_and_exact_native_commands(
    isolation: IsolationFixture,
) -> None:
    arguments = ("", "spaces\ttabs\nlines", "$(touch SECRET)")
    isolation.quiet(isolation.run(arguments=arguments, full_stack=True), 0)
    observed = json.loads(isolation.router.path("work/callback.observation").read_text())
    assert observed["args"] == [
        str(isolation.guard / "root"),
        isolation.storage.expected(),
        *arguments,
    ]
    assert observed["fd9_inode"] == isolation.storage.target.stat().st_ino
    tree = str(isolation.guard / "root")
    delegated_tests = {tuple(item["args"]) for item in isolation.calls() if item["tool"] == "test"}
    assert {
        ("-c", "/dev/null"),
        ("-c", tree + "/dev/null"),
        ("/dev/null", "-ef", tree + "/dev/null"),
        ("-d", "/proc/self/fd/9"),
        (str(isolation.storage.target), "-ef", "/proc/self/fd/9"),
    } <= delegated_tests
    assert ("-d", str(isolation.storage.target)) not in delegated_tests
    assert all(
        "fd9" in item
        for item in isolation.calls()
        if item["tool"] == "test" and "/proc/self/fd/9" in item["args"]
    )
    unmount_flags = ["-n"] if isolation.settings["umount_profile"] == "modern" else ["-D", "-n"]
    assert [item["args"] for item in isolation.mutations()] == [
        ["-n", "-i", "-o", "bind", "/dev/null", tree + "/dev/null"],
        ["-n", "-i", "-o", "make-private", tree + "/dev/null"],
        ["-n", "-i", "-o", "bind", "/proc/self/fd/9", tree + "/opt"],
        ["-n", "-i", "-o", "make-private", tree + "/opt"],
        [*unmount_flags, tree + "/opt"],
        [*unmount_flags, tree + "/dev/null"],
    ]
    assert not isolation.guard.exists()


@pytest.fixture
def native(router: RouterHarness) -> IsolationFixture:
    return IsolationFixture(router, "/bin/sh")


@pytest.mark.parametrize(
    "help_bytes,producer_status,expected_status,profile",
    [
        pytest.param(UMOUNT_HELP["legacy"], 0, 0, "legacy", id="legacy-without-advertised-n"),
        pytest.param(UMOUNT_HELP["modern"], 0, 0, "modern", id="modern-without-advertised-n"),
        pytest.param(UMOUNT_HELP["modern"] + b"\n" * 27, 0, 0, "modern", id="32-lines"),
        pytest.param(
            UMOUNT_HELP["legacy"] + UMOUNT_HELP["modern"].splitlines(keepends=True)[-1],
            0,
            1,
            "",
            id="conflicting-loop-options",
        ),
        pytest.param(
            UMOUNT_HELP["modern"] + UMOUNT_HELP["modern"].splitlines(keepends=True)[-1],
            0,
            1,
            "",
            id="duplicate-loop-option",
        ),
        pytest.param(
            UMOUNT_HELP["legacy"].replace(b"-D", b"-a"), 0, 1, "", id="missing-loop-option"
        ),
        pytest.param(
            UMOUNT_HELP["legacy"].replace(b"-D", b"-Dextra"), 0, 1, "", id="unknown-option"
        ),
        pytest.param(
            UMOUNT_HELP["modern"].replace(b"Free loop", b"Detach loop"),
            0,
            1,
            "",
            id="unknown-description",
        ),
        pytest.param(
            UMOUNT_HELP["modern"].replace(b"BusyBox", b"OtherTool"), 0, 1, "", id="not-busybox"
        ),
        pytest.param(
            UMOUNT_HELP["modern"].replace(b"Usage: umount", b"Usage: mount"),
            0,
            1,
            "",
            id="wrong-usage",
        ),
        pytest.param(UMOUNT_HELP["modern"][:-1], 0, 1, "", id="missing-final-lf"),
        pytest.param(
            UMOUNT_HELP["modern"].replace(b"Free", b"Fr\0ee"), 0, 1, "", id="nul-reconstruction"
        ),
        pytest.param(UMOUNT_HELP["modern"] + b"\xff\n", 0, 1, "", id="non-ascii"),
        pytest.param(UMOUNT_HELP["modern"] + b"\x01\n", 0, 1, "", id="control-byte"),
        pytest.param(UMOUNT_HELP["modern"] + b"\n" * 28, 0, 1, "", id="33-lines"),
        pytest.param(UMOUNT_HELP["modern"] + b"x" * 4096 + b"\n", 0, 1, "", id="over-4096-bytes"),
        pytest.param(
            UMOUNT_HELP["modern"] + b"x" * 16384 + b"\n", 0, 1, "", id="producer-file-limit"
        ),
        pytest.param(UMOUNT_HELP["modern"], 7, 1, "", id="producer-failure"),
        pytest.param(UMOUNT_HELP["modern"], 129, 129, "", id="producer-hup"),
        pytest.param(UMOUNT_HELP["modern"], 130, 130, "", id="producer-int"),
        pytest.param(UMOUNT_HELP["modern"], 143, 143, "", id="producer-term"),
    ],
)
def test_native_umount_help_admission_is_strict_and_bounded(
    router: RouterHarness,
    help_bytes: bytes,
    producer_status: int,
    expected_status: int,
    profile: str,
) -> None:
    # No storage, captures or mount doubles: exercise actual admission/file
    # framing with a tiny read-only help producer and native wc.
    guard = router.path("work/profile")
    guard.mkdir(mode=0o700)
    help_file = router.path("work/native-help")
    help_file.write_bytes(help_bytes)
    executable = router.fake_tool(
        "umount",
        '[ "$#" = 1 ] && [ "$1" = --help ] || exit 2\n'
        + f"/bin/cat {shlex.quote(str(help_file))} >&2\nexit {producer_status}\n",
    )
    result = router.run(
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(SOURCE))}\n"
        + f"_isolation_guard={shlex.quote(str(guard))}\n"
        + f"_isolation_umount={shlex.quote(str(executable))}\n"
        + "_io_wc=/usr/bin/wc\n_io_tab='\t'\n_io_lf='\n'\n"
        # The actual IO owner silences callback stderr, including native shell
        # diagnostics when the bounded producer reaches its file limit.
        + "_cfmgr_isolation_umount_admit 2>/dev/null\nstatus=$?\n"
        + 'printf "%s\\t%s\\n" "$status" "$_isolation_umount_profile"\n',
        env={"_isolation_umount_profile": "inherited-untrusted"},
    )
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == f"{expected_status}\t{profile}\n"
    if len(help_bytes) > 16384:
        assert (guard / "umount-help").stat().st_size <= 16384


def test_unknown_umount_help_fails_before_queries_and_removes_only_fresh_guard(
    native: IsolationFixture,
) -> None:
    native.router.path("work/umount-help").write_bytes(b"Unsupported native command\n")
    native.quiet(native.run())
    assert not native.guard.exists() and native.mutations() == []
    assert not any(item["tool"] == "cat" for item in native.calls())


@pytest.mark.parametrize(
    "profile",
    [
        "ram-disk",
        "ram-ro",
        "ram-noexec",
        "ram-shared",
        "ram-child",
        "source-unknown",
        "source-shared",
        "source-child",
        "source-noexec",
        "null-nodev",
    ],
)
def test_admission_failure_prevents_every_mount_and_removes_only_fresh_guard(
    native: IsolationFixture, profile: str
) -> None:
    change = {
        "ram-disk": (1, {"kind": "ext4"}),
        "ram-ro": (1, {"options": b"ro"}),
        "ram-noexec": (1, {"options": b"rw,noexec"}),
        "ram-shared": (1, {"optional": ("shared:1",)}),
        "source-unknown": (3, {"optional": ("future:1",)}),
        "source-shared": (3, {"optional": ("shared:2",)}),
        "source-noexec": (3, {"options": b"rw,noexec"}),
        "null-nodev": (2, {"options": b"rw,nodev"}),
    }.get(profile)
    if change:
        index, fields = change
        native.mounts[index] = replace(native.mounts[index], **fields)
        if index == 3:
            native.storage.mounts[0] = native.mounts[index]
    else:
        parent = native.router.path("ram/tmp") if profile == "ram-child" else native.storage.target
        native.mounts.append(Mount("50", point=os.fsencode(parent / "child")))
    native.save()
    native.quiet(native.run())
    assert native.mutations() == [] and not native.guard.exists()


@pytest.mark.parametrize("kind", ["directory", "file", "symlink"])
def test_existing_guard_is_pending_and_never_adopted(native: IsolationFixture, kind: str) -> None:
    if kind == "directory":
        native.guard.mkdir(mode=0o700)
        (native.guard / "foreign").write_text("retained")
    elif kind == "file":
        native.guard.write_text("retained")
    else:
        native.guard.symlink_to(native.storage.target)
    native.quiet(native.run())
    assert native.mutations() == []
    assert not any(
        item["tool"] == "rm" and item["args"][-1] == str(native.guard) for item in native.calls()
    )
    assert native.guard.is_symlink() if kind == "symlink" else native.guard.exists()


@pytest.mark.parametrize(
    "fault", ["ram-symlink", "source-change", "metadata-short", "bind-null-error", "null-type"]
)
def test_ordinary_pre_mount_or_proven_absent_failure_can_remove_fresh_guard(
    native: IsolationFixture, fault: str
) -> None:
    native.settings["isolation_fault"] = fault
    native.save()
    native.quiet(native.run())
    assert not native.guard.exists()
    assert not native.router.path("work/callback.observation").exists()
    assert not any(item["tool"] == "umount" for item in native.mutations())


@pytest.mark.parametrize(
    "fault",
    [
        "bind-null-partial",
        "bind-opt-partial",
        "private-error",
        "post-device",
        "post-shared",
        "probe-error",
        "record-error",
    ],
)
def test_uncertain_unrecorded_bind_retains_guard_without_speculative_unmount(
    native: IsolationFixture, fault: str
) -> None:
    native.settings["isolation_fault"] = fault
    native.save()
    native.quiet(native.run())
    assert native.guard.is_dir() and (native.guard / "intent-null").is_file()
    assert not native.router.path("work/callback.observation").exists()
    assert not any(item["tool"] == "umount" for item in native.mutations())
    assert not any(
        item["tool"] == "rm" and item["args"][-1] == str(native.guard) for item in native.calls()
    )


@pytest.mark.parametrize(
    "fault",
    [
        "foreign",
        "stacked",
        "descendant",
        "missing-intents",
        "umount-error",
        "umount-false-success",
        "umount-null-error",
    ],
)
def test_cleanup_refuses_unproved_or_busy_mounts_and_retains_guard(
    native: IsolationFixture, fault: str
) -> None:
    native.settings["isolation_fault"] = fault
    native.save()
    native.quiet(native.run())
    assert native.guard.is_dir()
    assert native.router.path("work/callback.observation").is_file()
    assert not any(
        item["tool"] == "rm" and item["args"][-1] == str(native.guard) for item in native.calls()
    )
    removals = [item for item in native.mutations() if item["tool"] == "umount"]
    assert len(removals) == (
        2 if fault == "umount-null-error" else 1 if fault.startswith("umount-") else 0
    )
    state = json.loads(native.router.path("work/state.json").read_text())
    assert any(
        bytes.fromhex(row["point"]).startswith(os.fsencode(native.guard)) for row in state["mounts"]
    )


@pytest.mark.parametrize("fault", ["signal-mount", "signal-callback"])
def test_signal_during_active_operation_preserves_guard_and_skips_unmount(
    isolation: IsolationFixture, fault: str
) -> None:
    isolation.settings["isolation_fault"] = fault
    isolation.save()
    isolation.quiet(isolation.run(), 143)
    assert isolation.guard.is_dir()
    assert (isolation.guard / "active").is_file()
    assert not any(item["tool"] == "umount" for item in isolation.mutations())


def test_signal_during_full_capture_query_preserves_guard_and_skips_unmount(
    native: IsolationFixture,
) -> None:
    # The fake cat signals its capture owner via the actual capture subprocess.
    native.settings["isolation_fault"] = "signal-query"
    native.save()
    native.quiet(native.run(full_stack=True), 143)
    assert native.guard.is_dir() and not (native.guard / "active").exists()
    assert not any(item["tool"] == "umount" for item in native.mutations())


def test_callback_failure_is_preserved_after_verified_ordered_cleanup(
    isolation: IsolationFixture,
) -> None:
    isolation.settings["callback_status"] = 7
    isolation.save()
    isolation.quiet(isolation.run(), 7)
    assert not isolation.guard.exists()
    assert [item["args"][-1] for item in isolation.mutations() if item["tool"] == "umount"] == [
        str(isolation.guard / "root/opt"),
        str(isolation.guard / "root/dev/null"),
    ]


def test_bind_root_and_target_relative_path_are_preserved(native: IsolationFixture) -> None:
    source = replace(
        native.mounts[3], root=b"/bind-root", point=os.fsencode(native.router.path("work"))
    )
    native.mounts[3] = source
    native.storage.mounts[0] = source
    native.save()
    native.quiet(native.run(), 0)
    assert not native.guard.exists()
    callback = json.loads(native.router.path("work/callback.observation").read_text())
    assert callback["args"][1] == native.storage.expected()


def test_overlapping_attempt_is_rejected_without_disturbing_live_guard(
    native: IsolationFixture,
) -> None:
    native.quiet(native.run(overlap=True), 0)
    assert len(native.mutations()) == 6 and not native.guard.exists()


def test_cleanup_rm_failure_remains_failure_after_mounts_are_proved_absent(
    native: IsolationFixture,
) -> None:
    native.settings["isolation_fault"] = "guard-rm-error"
    native.save()
    native.quiet(native.run())
    assert native.guard.is_dir()
    assert len([item for item in native.mutations() if item["tool"] == "umount"]) == 2


def test_sourcing_only_defines_functions_and_bad_api_never_starts_io(router: RouterHarness) -> None:
    result = router.run(
        'IFS=x; set -f; umask 027; trap ":" TERM\nbefore=$(trap); options=$(set +o)\n'
        + f". {shlex.quote(str(STORAGE))}\n. {shlex.quote(str(SOURCE))}\n"
        + r"""
cfmgr_isolation_with /trusted /m /s 'bad;callback'; [ "$?" = 2 ] || exit 1
cfmgr_isolation_with /trusted /m /s; [ "$?" = 2 ] || exit 1
cfmgr_isolation_test a b c d e f g h; [ "$?" = 2 ] || exit 1
[ "$IFS" = x ] && [ "$(trap)" = "$before" ] &&
[ "$(set +o)" = "$options" ] && [ "$(umask)" = 0027 ]
"""
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert list(router.path("ram/tmp").iterdir()) == []


def test_public_entry_has_fixed_inputs_and_preserves_empty_callback_arguments(
    router: RouterHarness,
) -> None:
    result = router.run(
        f". {shlex.quote(str(STORAGE))}\n. {shlex.quote(str(SOURCE))}\n"
        + r"""
cfmgr_storage_with() {
    [ "$#" = 7 ] && [ "$1" = /trusted ] && [ "$2" = /m ] &&
    [ "$3" = /s ] && [ "$4" = _cfmgr_isolation_begin ] &&
    [ "$5" = cb ] && [ -z "$6" ] && [ "$7" = '$(false)' ] &&
    [ -z "$_isolation_tools" ] && [ "$_isolation_input" = /proc/self/mountinfo ]
}
cfmgr_isolation_with /trusted /m /s cb '' '$(false)'
""",
        env={"_isolation_tools": "/opt/SECRET", "_isolation_input": "/opt/SECRET"},
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""


@pytest.mark.parametrize("status", [0, 7])
def test_callback_early_exit_keeps_guard_without_false_success(
    isolation: IsolationFixture, status: int
) -> None:
    isolation.settings["callback_status"] = status
    isolation.save()
    isolation.quiet(isolation.run(callback_exit=True), 1 if status == 0 else status)
    assert isolation.guard.is_dir() and (isolation.guard / "active").read_text() == "callback\n"
    assert not any(item["tool"] == "umount" for item in isolation.mutations())
    assert not any(
        item["tool"] == "rm" and item["args"][-1] == str(isolation.guard)
        for item in isolation.calls()
    )


def test_failed_second_bind_unwinds_only_verified_null_mount(native: IsolationFixture) -> None:
    native.settings["isolation_fault"] = "bind-opt-error"
    native.save()
    native.quiet(native.run())
    assert (
        not native.guard.exists() and not native.router.path("work/callback.observation").exists()
    )
    removals = [item["args"] for item in native.mutations() if item["tool"] == "umount"]
    assert removals == [["-D", "-n", str(native.guard / "root/dev/null")]]


def test_private_parent_path_with_spaces_supports_complete_lifecycle(router: RouterHarness) -> None:
    nested = RouterHarness(router.path("work/private RAM parent"))
    fixture = IsolationFixture(nested, "/bin/sh")
    fixture.quiet(fixture.run(), 0)
    assert not fixture.guard.exists()


def test_fast_fixture_serializer_matches_independent_mount_snapshot(
    native: IsolationFixture,
) -> None:
    native.mounts[1] = replace(
        native.mounts[1],
        root=b"/ram space\tline\nback\\slash",
        source=b"tmp space\tline\nback\\slash",
    )
    native.mounts.append(Mount("90", point=b"/unrelated space\tline\nback\\slash"))
    native.save()
    result = native.router.run(
        '"$1" "$2"\n',
        [str(native.router.root / "bin/cat"), str(native.router.path("work/mountinfo"))],
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode() == snapshot(native.mounts)
