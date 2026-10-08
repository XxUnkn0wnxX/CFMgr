"""Retained-FD observations on synthetic roots; no mounted-volume approval."""

from __future__ import annotations

import json
import os
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_mountinfo import Mount, snapshot
from tests.test_storageinfo import BLOCK_LINE, ext_bytes, ledger

ROOT = Path(__file__).resolve().parents[1]
IO = ROOT / "modules/io.sh"
STORAGE = ROOT / "modules/storage.sh"
MOUNT_PARSER = ROOT / "modules/mountinfo.awk"
STORAGE_PARSER = ROOT / "modules/storageinfo.awk"
UUID = "00112233-4455-6677-8899-aabbccddeeff"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]
SHELLS = [
    pytest.param("/bin/sh", id="sh"),
    pytest.param(
        "/bin/dash",
        id="dash",
        marks=pytest.mark.skipif(not Path("/bin/dash").is_file(), reason="dash unavailable"),
    ),
]

# Explicit host-only tools inspect actual inherited descriptors. Production code
# never imports this dispatcher or selects its paths through the environment.
DISPATCHER = r"""
import fcntl
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys

settings = json.loads(Path(sys.argv[1]).read_text())
tool, args = sys.argv[2], sys.argv[3:]
log = Path(settings["log"])
calls = [json.loads(path.read_text()) for path in log.glob("*.json")]
count = 1 + sum(item["tool"] == tool for item in calls)
record = {"tool": tool, "args": args, "count": count}
for fd in (8, 9):
    try:
        held = os.fstat(fd)
        record["fd" + str(fd)] = [held.st_dev, held.st_ino, stat.S_IFMT(held.st_mode)]
        assert fcntl.fcntl(fd, fcntl.F_GETFL) & os.O_ACCMODE == os.O_RDONLY
    except OSError:
        pass
record["sequence"] = len(calls)
(log / (str(os.getpid()) + ".json")).write_text(json.dumps(record))
fault = settings.get("fault", "")
if fault == tool + "-error":
    os.write(2, b"SECRET ignored native error\n")
    sys.exit(7)
if tool == "rm":
    stage = Path(args[1])
    assert args[0] == "-rf" and stage.parent == Path(settings["ram"])
    summary = {"files": sorted(path.name for path in stage.iterdir())}
    (log / "cleanup.observation").write_text(json.dumps(summary))
    sys.exit(subprocess.call(["/bin/rm", *args]))
if tool == "readlink":
    assert args == ["-f", settings["target"]]
    resolved = str(Path(settings["target"]).resolve())
    if fault == "path-change" and count == 2:
        resolved = settings["other"]
    if fault == "directory-open":
        Path(resolved).chmod(0)
    print(resolved)
elif tool == "test":
    if args == ["-d", settings["target"]]:
        target = Path(args[1])
        assert target.is_dir()
        if fault == "directory-race":
            target.rmdir()
            target.write_bytes(b"substituted regular file")
        sys.exit(0)
    if args == ["-d", "/proc/self/fd/9"]:
        sys.exit(0 if stat.S_ISDIR(os.fstat(9).st_mode) else 1)
    assert args == [settings["target"], "-ef", "/proc/self/fd/9"]
    if settings.get("native_fdinfo"):
        sys.exit(subprocess.call(["/usr/bin/test", *args], pass_fds=(9,)))
    current, held = os.stat(args[0]), os.fstat(9)
    sys.exit(0 if (current.st_dev, current.st_ino) == (held.st_dev, held.st_ino) else 1)
elif tool == "cat":
    if args == [settings["mount_input"]]:
        data = Path(args[0]).read_bytes()
        if fault == "mount-change" and count > 1:
            data = data.replace(b"8:1", b"8:2")
    else:
        assert args == [settings["fdinfo"]]
        data = Path(args[0]).read_bytes()
        if fault == "mnt-change" and count > 2:
            data = data.replace(b"mnt_id:\t42", b"mnt_id:\t43")
    os.write(1, data)
elif tool == "ls":
    assert args == ["-dnL", "/proc/self/fd/8"]
    assert "fd8" in record
    line = bytes.fromhex(settings["ls_hex"])
    if fault == "rdev-mismatch" or (fault == "rdev-change" and count == 2):
        line = line.replace(b"008, 0001", b"008, 0002")
    if fault == "block-replace-before-read" and count == 1:
        path = Path(settings["block"])
        original = path.read_bytes()
        path.rename(path.with_name("original-block"))
        replacement = bytearray(original)
        replacement[1128:1144] = bytes.fromhex("ffeeddccbbaa99887766554433221100")
        path.write_bytes(replacement)
    os.write(1, line)
elif tool == "hexdump":
    assert args == ["-v", "-n1152", "-e", '1/1 "%02x"']
    held, incoming = os.fstat(8), os.fstat(0)
    assert (held.st_dev, held.st_ino) == (incoming.st_dev, incoming.st_ino)
    assert "fd8" in record and "fd9" in record
    data = os.read(0, 1152)
    output = data.hex().encode()
    if fault == "hex-short": output = output[:-2]
    if fault == "hex-extra": output += b"00"
    if fault == "directory-replace":
        target = Path(settings["target"])
        target.rename(target.with_name("original-retained"))
        target.mkdir()
    if fault == "block-replace":
        path = Path(settings["block"])
        path.rename(path.with_name("original-block"))
        path.write_bytes(b"replacement")
    if fault == "signal":
        owner = int(subprocess.check_output(
            ["/bin/ps", "-o", "ppid=", "-p", str(os.getppid())], text=True).strip())
        os.kill(owner, signal.SIGTERM)
    os.write(1, output)
elif tool == "awk":
    if fault.startswith("parser-") and "cfmgr_storageinfo_mode=exthex" in args:
        body = ("exthex\t" + settings["uuid"] + "\n").encode()
        output = body + b"end\t" + str(len(body)).encode() + b"\n"
        if fault == "parser-truncated": output = output[:-1]
        if fault == "parser-footer": output = output.replace(b"end\t", b"end\t0")
        if fault == "parser-nul": output = output.replace(b"exthex", b"exthex\x00")
        if fault == "parser-extra": output += b"extra\n"
        if fault == "parser-zero": output = b""
        os.write(1, output)
    else:
        sys.exit(subprocess.call(settings["awk"] + args))
else:
    raise AssertionError(tool)
"""


CALLBACK_PROBE = r"""
import fcntl
import json
import os
from pathlib import Path
import signal
import stat
import sys

settings = json.loads(Path(sys.argv[1]).read_text())
log = Path(settings["log"])
output = log / "callback.observation"
record = {"args": sys.argv[2:], "count": 1}
if output.exists():
    record["count"] += json.loads(output.read_text())["count"]
for fd in (8, 9):
    held = os.fstat(fd)
    assert fcntl.fcntl(fd, fcntl.F_GETFL) & os.O_ACCMODE == os.O_RDONLY
    record["fd" + str(fd)] = [held.st_dev, held.st_ino, stat.S_IFMT(held.st_mode)]
assert stat.S_ISDIR(os.fstat(9).st_mode)
os.lseek(8, 0, os.SEEK_SET)
record["block_hex"] = os.read(8, 1152).hex()
record["producer_order"] = [item["tool"] for item in sorted(
    (json.loads(path.read_text()) for path in log.glob("*.json")),
    key=lambda item: item["sequence"])]
stages = list(Path(settings["ram"]).glob("cfmgr-io.*"))
assert len(stages) == 1
record["capture_files"] = len(list(stages[0].iterdir()))
assert not (log / "cleanup.observation").exists()
output.write_text(json.dumps(record))
os.write(1, b"SECRET callback stdout\n")
os.write(2, b"SECRET callback stderr\n")
if settings.get("callback_signal"):
    os.kill(os.getppid(), signal.SIGTERM)
sys.exit(settings.get("callback_status", 0))
"""


class StorageFixture:
    def __init__(self, router: RouterHarness, shell: str = "/bin/sh", *, busybox: bool = False):
        self.router, self.shell = router, shell
        router.path("work/calls").mkdir(mode=0o700)
        router.path("work/volume").mkdir(mode=0o700)
        router.path("work/other").mkdir(mode=0o700)
        router.write("work/dispatcher.py", DISPATCHER)
        self.target = router.path("work/volume")
        self.mounts = [
            Mount("42", point=os.fsencode(self.target), device="8:1", source=b"/dev/synthetic")
        ]
        router.write("work/mountinfo", snapshot(self.mounts).decode())
        router.write("work/fdinfo", "pos:\t0\nflags:\t0100000\nmnt_id:\t42\n")
        router.path("work/block").write_bytes(ext_bytes())
        router.path("work/block").chmod(0o600)
        self.settings = {
            "ram": str(router.path("ram/tmp")),
            "log": str(router.path("work/calls")),
            "target": str(self.target),
            "other": str(router.path("work/other")),
            "mount_input": str(router.path("work/mountinfo")),
            "fdinfo": str(router.path("work/fdinfo")),
            "block": str(router.path("work/block")),
            "ls_hex": BLOCK_LINE.hex(),
            "uuid": UUID,
            "awk": [str(router.busybox), "awk"] if busybox else ["/usr/bin/awk"],
        }
        self.settings_path = router.path("work/settings.json")
        self.save()
        for tool, executable in [
            ("mkdir", "/bin/mkdir"),
            ("wc", "/usr/bin/wc"),
            ("printf", "/usr/bin/printf"),
        ]:
            router.path("bin/" + tool).symlink_to(executable)
        for tool in ("rm", "readlink", "test", "cat", "ls", "hexdump", "awk"):
            router.fake_tool(
                tool,
                f"exec {shlex.quote(sys.executable)} "
                f"{shlex.quote(str(router.path('work/dispatcher.py')))} "
                f'{shlex.quote(str(self.settings_path))} {tool} "$@"\n',
            )

    def save(self) -> None:
        self.settings_path.write_text(json.dumps(self.settings))
        self.settings_path.chmod(0o600)

    def callback_prefix(self) -> str:
        self.router.write("work/callback.py", CALLBACK_PROBE)
        return (
            "fixture_callback() {\n"
            f"{shlex.quote(sys.executable)} "
            f"{shlex.quote(str(self.router.path('work/callback.py')))} "
            f'{shlex.quote(str(self.settings_path))} "$@"\n'
            'return "$?"\n}\n'
        )

    def callback_observation(self) -> dict:
        return json.loads(self.router.path("work/calls/callback.observation").read_text())

    def run(
        self,
        *,
        prefix: str = "",
        suffix: str = "",
        block_mapping: bool = True,
        reserve_slot: bool = False,
        callback: str | None = None,
        callback_args: tuple[str, ...] = (),
    ) -> ShellResult:
        if callback is not None:
            invocation = 'cfmgr_storage_with_test "$@"\n'
        elif reserve_slot:
            prefix += 'fixture_reserved() { : >"$1/7.status"; _cfmgr_storage_begin "$@"; }\n'
            invocation = (
                'cfmgr_io_test "$1" "$2" report fixture_reserved "$3" "$4" "$5" "$6" "$7" "$8"\n'
            )
        elif block_mapping:
            invocation = 'cfmgr_storage_test "$@"\n'
        else:
            invocation = (
                'cfmgr_io_test "$1" "$2" report _cfmgr_storage_begin "$3" "$4" "$5" "" "$7" "$8"\n'
            )
        self.router.write(
            "work/invoke.sh",
            f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
            + prefix
            + invocation
            + suffix,
        )
        args = [
            str(self.router.path("ram/tmp")),
            str(self.router.path("bin")),
            str(self.target),
            str(self.router.path("work/mountinfo")),
            str(self.settings["fdinfo"]),
            str(self.router.path("work/block")),
            str(MOUNT_PARSER),
            str(STORAGE_PARSER),
        ]
        if callback is not None:
            args += [callback, *callback_args]
        script = '"$@"\n' if self.router.busybox else f'exec {shlex.quote(self.shell)} "$@"\n'
        if self.router.busybox:
            script = f'exec {shlex.quote(str(self.router.busybox))} sh "$@"\n'
        return self.router.run(
            script,
            [str(self.router.path("work/invoke.sh")), *args],
            timeout=45,
            env={
                "_storage_block_fixture": str(self.router.path("work/block")),
                "_storage_mode": "with",
                "_storage_callback": "stale_callback",
                "IFS": "x",
            },
        )

    def calls(self) -> list[dict]:
        return sorted(
            (
                json.loads(path.read_text())
                for path in self.router.path("work/calls").glob("*.json")
            ),
            key=lambda item: item["sequence"],
        )

    def clean(self) -> None:
        assert list(self.router.path("ram/tmp").glob("cfmgr-io.*")) == []

    def expected(self) -> str:
        mount = self.mounts[0]
        relative = self.target.relative_to(Path(os.fsdecode(mount.point)))
        filesystem_target = Path(os.fsdecode(mount.root)) / relative
        return ledger(
            "volume",
            mount.identifier,
            mount.device,
            mount.kind,
            mount.root.hex(),
            mount.point.hex(),
            os.fsencode(filesystem_target).hex(),
            mount.options.hex(),
            mount.super_options.hex(),
            UUID,
        )


@pytest.fixture
def storage(router: RouterHarness, request: pytest.FixtureRequest) -> StorageFixture:
    return StorageFixture(router, getattr(request, "param", "/bin/sh"))


def quiet(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == ""


@pytest.mark.parametrize("storage", SHELLS, indirect=True)
def test_retained_observation_uses_all_slots_and_original_descriptors(
    storage: StorageFixture,
) -> None:
    result = storage.run()
    assert result.returncode == 0 and result.stderr == "" and result.stdout == storage.expected(), (
        result
    )
    calls = storage.calls()
    assert [item["tool"] for item in calls] == [
        "readlink",
        "test",
        "test",
        "cat",
        "awk",
        "cat",
        "awk",
        "test",
        "ls",
        "awk",
        "hexdump",
        "awk",
        "readlink",
        "cat",
        "awk",
        "cat",
        "awk",
        "test",
        "ls",
        "awk",
        "rm",
    ]
    assert all("fd9" in item for item in calls[2:-1])
    assert "fd8" in next(item for item in calls if item["tool"] == "hexdump")
    observed = json.loads(storage.router.path("work/calls/cleanup.observation").read_text())
    assert len(observed["files"]) == 48
    storage.clean()


@pytest.mark.parametrize(
    "fault",
    [
        "path-change",
        "mount-change",
        "mnt-change",
        "rdev-mismatch",
        "rdev-change",
        "directory-replace",
        "directory-race",
        "readlink-error",
        "cat-error",
        "ls-error",
        "hexdump-error",
        "hex-short",
        "hex-extra",
        "parser-truncated",
        "parser-footer",
        "parser-nul",
        "parser-extra",
        "parser-zero",
    ],
)
def test_faults_never_publish_partial_observation(storage: StorageFixture, fault: str) -> None:
    storage.settings["fault"] = fault
    storage.save()
    quiet(storage.run())
    storage.clean()


@pytest.mark.parametrize("profile", ["tmpfs", "mount-sb", "super-sb", "source"])
def test_unsupported_profile_is_rejected_before_block_data_read(
    storage: StorageFixture, profile: str
) -> None:
    from dataclasses import replace

    change = {
        "tmpfs": {"kind": "tmpfs"},
        "mount-sb": {"options": b"rw,sb=1"},
        "super-sb": {"super_options": b"rw,sb=0"},
        "source": {"source": b"UUID=not-a-device"},
    }[profile]
    storage.mounts[0] = replace(storage.mounts[0], **change)
    storage.router.path("work/mountinfo").write_bytes(snapshot(storage.mounts))
    quiet(storage.run(), 3)
    assert not any(item["tool"] in {"ls", "hexdump"} for item in storage.calls())
    storage.clean()


@pytest.mark.parametrize("field", ["missing", "mismatch"])
def test_fdinfo_must_join_selected_mount(storage: StorageFixture, field: str) -> None:
    storage.router.path("work/fdinfo").write_bytes(
        b"pos:\t0\nflags:\t0100000\n" + (b"mnt_id:\t43\n" if field == "mismatch" else b"")
    )
    quiet(storage.run(), 3 if field == "missing" else 1)
    assert not any(item["tool"] == "hexdump" for item in storage.calls())
    storage.clean()


def test_nonblock_metadata_is_rejected_before_data_read(storage: StorageFixture) -> None:
    storage.settings["ls_hex"] = b"-rw-r--r-- 1 0 0 1152 Oct 9 12:34 /proc/self/fd/8\n".hex()
    storage.save()
    quiet(storage.run())
    assert not any(item["tool"] == "hexdump" for item in storage.calls())
    storage.clean()


def test_production_path_does_not_use_inherited_regular_block_mapping(
    storage: StorageFixture,
) -> None:
    quiet(storage.run(block_mapping=False))
    assert not any(item["tool"] in {"ls", "hexdump"} for item in storage.calls())
    storage.clean()


@pytest.mark.parametrize("kind", ["directory", "block"])
@pytest.mark.skipif(
    os.geteuid() == 0, reason="permission-denied open requires an unprivileged host"
)
def test_failed_descriptor_open_is_quiet_io_failure(storage: StorageFixture, kind: str) -> None:
    if kind == "directory":
        storage.settings["fault"] = "directory-open"
        storage.save()
    else:
        storage.router.path("work/block").chmod(0)
    try:
        quiet(storage.run())
        storage.clean()
    finally:
        storage.target.chmod(0o700)
        storage.router.path("work/block").chmod(0o600)


def test_original_block_descriptor_survives_path_replacement(storage: StorageFixture) -> None:
    storage.settings["fault"] = "block-replace"
    storage.save()
    result = storage.run()
    assert result.returncode == 0 and result.stdout == storage.expected() and result.stderr == ""
    assert storage.router.path("work/block").read_bytes() == b"replacement"
    storage.clean()


def test_bind_root_and_deeper_target_are_distinct_observation_fields(
    storage: StorageFixture,
) -> None:
    from dataclasses import replace

    storage.mounts[0] = replace(
        storage.mounts[0], point=os.fsencode(storage.router.path("work")), root=b"/bind-root"
    )
    storage.router.path("work/mountinfo").write_bytes(snapshot(storage.mounts))
    result = storage.run()
    assert result.returncode == 0 and result.stdout == storage.expected() and result.stderr == ""
    fields = result.stdout.splitlines()[0].split("\t")
    assert fields[4] == b"/bind-root".hex() and fields[6] == b"/bind-root/volume".hex()
    assert fields[4] != fields[6]
    storage.clean()


def test_original_block_is_read_after_path_replacement_before_hexdump(
    storage: StorageFixture,
) -> None:
    storage.settings["fault"] = "block-replace-before-read"
    storage.save()
    result = storage.run()
    assert result.returncode == 0 and result.stdout == storage.expected() and result.stderr == ""
    held = [item for item in storage.calls() if item["tool"] in {"ls", "hexdump"}]
    assert len(held) == 3 and held[0]["fd8"] == held[1]["fd8"] == held[2]["fd8"]
    assert held[1]["fd8"][1] != storage.router.path("work/block").stat().st_ino
    assert storage.router.path("work/block").read_bytes()[1128:1144] != ext_bytes()[1128:1144]
    storage.clean()


def test_consumed_capture_slot_never_reused_by_observation(storage: StorageFixture) -> None:
    quiet(storage.run(reserve_slot=True))
    assert not any(item["tool"] == "hexdump" for item in storage.calls())
    storage.clean()


def test_storage_source_only_defines_functions(router: RouterHarness) -> None:
    result = router.run(
        'IFS=x; set -f; umask 027; trap ":" TERM\n'
        "before=$(trap); options=$(set +o); cwd=$PWD\n"
        f". {shlex.quote(str(STORAGE))}\n"
        '[ "$IFS" = x ] && [ "$(trap)" = "$before" ] && '
        '[ "$(set +o)" = "$options" ] && [ "$PWD" = "$cwd" ] && [ "$(umask)" = 0027 ]\n'
    )
    quiet(result, 0)
    assert list(router.path("ram/tmp").iterdir()) == []


def test_signal_and_cleanup_failure_never_publish(storage: StorageFixture) -> None:
    storage.settings["fault"] = "signal"
    storage.save()
    quiet(storage.run(), 143)
    storage.clean()


def test_cleanup_failure_suppresses_complete_staged_observation(storage: StorageFixture) -> None:
    storage.settings["fault"] = "rm-error"
    storage.save()
    quiet(storage.run())
    assert len(list(storage.router.path("ram/tmp").glob("cfmgr-io.*"))) == 1


@pytest.mark.parametrize("with_callback", [False, True])
@pytest.mark.parametrize("storage", SHELLS, indirect=True)
def test_caller_descriptors_traps_and_environment_are_preserved(
    storage: StorageFixture, with_callback: bool
) -> None:
    storage.router.write("work/caller8", "original8\n")
    storage.router.write("work/caller9", "original9\n")
    prefix = (
        f"exec 8<{shlex.quote(str(storage.router.path('work/caller8')))} "
        f"9<{shlex.quote(str(storage.router.path('work/caller9')))}\n"
        'IFS=x; set -f; umask 027; trap ":" TERM\n'
        "before=$(trap); options=$(set +o)\n"
    )
    suffix = (
        "result=$?\nIFS= read -r first <&8; IFS= read -r second <&9\n"
        '[ "$result" = 0 ] && [ "$first" = original8 ] && [ "$second" = original9 ] && '
        '[ "$IFS" = x ] && [ "$(trap)" = "$before" ] && '
        '[ "$(set +o)" = "$options" ] && [ "$(umask)" = 0027 ]\n'
    )
    if with_callback:
        prefix += storage.callback_prefix()
    result = storage.run(
        prefix=prefix,
        suffix=suffix,
        callback="fixture_callback" if with_callback else None,
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == ("" if with_callback else storage.expected())
    if with_callback:
        assert storage.callback_observation()["args"] == [str(storage.target), storage.expected()]
    storage.clean()


@pytest.mark.skipif(sys.platform != "linux", reason="actual proc FD inheritance requires Linux")
def test_unprivileged_linux_directory_rename_keeps_fd_but_fails_current_path(
    router: RouterHarness,
) -> None:
    fixture = StorageFixture(router)
    directory = os.open(fixture.target, os.O_RDONLY | os.O_DIRECTORY)
    try:
        text = Path(f"/proc/self/fdinfo/{directory}").read_text()
        mount_id = next(
            line.split(":", 1)[1].strip()
            for line in text.splitlines()
            if line.startswith("mnt_id:")
        )
    finally:
        os.close(directory)
    from dataclasses import replace

    fixture.mounts[0] = replace(fixture.mounts[0], identifier=mount_id)
    router.path("work/mountinfo").write_bytes(snapshot(fixture.mounts))
    fixture.settings.update(
        fdinfo="/proc/self/fdinfo/9", native_fdinfo=True, fault="directory-replace"
    )
    fixture.save()
    quiet(fixture.run())
    tests = [item for item in fixture.calls() if item["tool"] == "test" and "-ef" in item["args"]]
    assert len(tests) == 2 and tests[0]["fd9"] == tests[1]["fd9"]
    assert router.path("work/original-retained").is_dir() and fixture.target.is_dir()
    fixture.clean()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_optional_busybox_retained_observation(busybox_router: RouterHarness) -> None:
    fixture = StorageFixture(busybox_router, busybox=True)
    result = fixture.run()
    assert result.returncode == 0 and result.stdout == fixture.expected() and result.stderr == ""
    fixture.clean()
    # Reuse the dedicated BusyBox shell/awk path for the retained callback too.
    fixture.router.path("work/calls/cleanup.observation").unlink()
    result = fixture.run(prefix=fixture.callback_prefix(), callback="fixture_callback")
    quiet(result, 0)
    assert fixture.callback_observation()["args"] == [str(fixture.target), fixture.expected()]
    fixture.clean()


@pytest.mark.parametrize("replace_block", [False, True])
@pytest.mark.parametrize("storage", SHELLS, indirect=True)
def test_trusted_callback_receives_completed_observation_and_original_fds(
    storage: StorageFixture, replace_block: bool
) -> None:
    if replace_block:
        storage.settings["fault"] = "block-replace-before-read"
        storage.save()
    arguments = ("", "spaces and\ttabs\nnewlines", "$(touch SECRET)", "'; exit 7 #", "*")
    quiet(
        storage.run(
            prefix=storage.callback_prefix(), callback="fixture_callback", callback_args=arguments
        ),
        0,
    )
    observed = storage.callback_observation()
    assert observed["count"] == 1
    assert observed["args"] == [str(storage.target), storage.expected(), *arguments]
    assert observed["block_hex"] == ext_bytes().hex()
    assert observed["capture_files"] == 48
    calls = storage.calls()
    assert observed["producer_order"] == [item["tool"] for item in calls[:-1]]
    assert calls[-2]["tool"] == "awk" and calls[-1]["tool"] == "rm"
    assert observed["fd8"] == next(item["fd8"] for item in calls if item["tool"] == "hexdump")
    assert observed["fd9"] == next(item["fd9"] for item in calls if item["tool"] == "hexdump")
    assert "fd8" not in calls[-1] and "fd9" not in calls[-1]
    if replace_block:
        assert observed["fd8"][1] != storage.router.path("work/block").stat().st_ino
    assert not storage.router.path("work/SECRET").exists()
    storage.clean()


@pytest.mark.parametrize(
    "fault", ["mount-change", "mnt-change", "rdev-change", "parser-truncated", "hex-short"]
)
def test_callback_is_never_invoked_after_unproved_observation(
    storage: StorageFixture, fault: str
) -> None:
    storage.settings["fault"] = fault
    storage.save()
    quiet(storage.run(prefix=storage.callback_prefix(), callback="fixture_callback"))
    assert not storage.router.path("work/calls/callback.observation").exists()
    storage.clean()


def test_callback_failure_status_is_preserved_and_output_discarded(storage: StorageFixture) -> None:
    storage.settings["callback_status"] = 7
    storage.save()
    quiet(storage.run(prefix=storage.callback_prefix(), callback="fixture_callback"), 7)
    assert storage.callback_observation()["count"] == 1
    storage.clean()


def test_callback_success_cannot_override_owned_cleanup_failure(storage: StorageFixture) -> None:
    storage.settings["fault"] = "rm-error"
    storage.save()
    quiet(storage.run(prefix=storage.callback_prefix(), callback="fixture_callback"))
    assert storage.callback_observation()["count"] == 1
    assert len(list(storage.router.path("ram/tmp").glob("cfmgr-io.*"))) == 1


@pytest.mark.parametrize("storage", SHELLS, indirect=True)
def test_callback_signal_cleans_workspace_and_preserves_signal_status(
    storage: StorageFixture,
) -> None:
    storage.settings["callback_signal"] = True
    storage.save()
    quiet(storage.run(prefix=storage.callback_prefix(), callback="fixture_callback"), 143)
    assert storage.callback_observation()["count"] == 1
    storage.clean()


def test_observe_ignores_inherited_callback_selector(storage: StorageFixture) -> None:
    prefix = 'stale_callback() { printf "SECRET"; return 7; }\n'
    result = storage.run(prefix=prefix)
    assert result.returncode == 0 and result.stdout == storage.expected() and result.stderr == ""
    storage.clean()


@pytest.mark.parametrize("callback", ["", "9bad", "a-b", "a/b", "a;exit", "x\ny", "$(true)"])
def test_bad_callback_name_is_rejected_before_observation(
    storage: StorageFixture, callback: str
) -> None:
    quiet(storage.run(callback=callback), 2)
    assert storage.calls() == []
    storage.clean()


def test_missing_callback_arguments_are_usage_errors(storage: StorageFixture) -> None:
    result = storage.run(
        prefix='cfmgr_storage_with "a" "b" "c"; [ "$?" = 2 ] || exit 1\n', callback=""
    )
    quiet(result, 2)
    assert storage.calls() == []
    storage.clean()


def test_production_with_entry_uses_fixed_inputs_and_status_only_owner(
    router: RouterHarness,
) -> None:
    router.write(
        "work/invoke.sh",
        f". {shlex.quote(str(STORAGE))}\n"
        + r"""
cfmgr_io_with_workspace() {
    [ "$#" = 11 ] && [ "$2" = _cfmgr_storage_with_begin ] &&
    [ "$3" = /opt ] && [ "$4" = /proc/self/mountinfo ] &&
    [ "$5" = /proc/self/fdinfo/9 ] && [ -z "$6" ] &&
    [ "$7" = /trusted/mount.awk ] && [ "$8" = /trusted/storage.awk ] &&
    [ "$9" = fixture_callback ] && [ -z "${10}" ] && [ "${11}" = '$(false)' ]
}
IFS=x; set -f; umask 027; trap ':' TERM
before=$(trap); options=$(set +o)
cfmgr_storage_with /trusted/ram /trusted/mount.awk /trusted/storage.awk \
    fixture_callback '' '$(false)'
result=$?
[ "$result" = 0 ] && [ "$IFS" = x ] && [ "$(trap)" = "$before" ] &&
[ "$(set +o)" = "$options" ] && [ "$(umask)" = 0027 ]
""",
    )
    quiet(router.run('/bin/sh "$1"\n', [str(router.path("work/invoke.sh"))]), 0)


def test_unavailable_trusted_function_is_invoked_only_after_observation(
    storage: StorageFixture,
) -> None:
    quiet(storage.run(callback="_missing_callback"), 127)
    calls = storage.calls()
    assert calls[-2]["tool"] == "awk" and calls[-1]["tool"] == "rm"
    assert (
        len(json.loads(storage.router.path("work/calls/cleanup.observation").read_text())["files"])
        == 48
    )
    storage.clean()
