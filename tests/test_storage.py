"""Native flush prerequisite: host fault contracts and separate Linux applet proof."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LIBRARY = ROOT / "modules/lib/storage.sh"
PROBE = ROOT / "tools/router-storage-probe.sh"
REQUIRE_BUSYBOX = os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1"


@pytest.fixture(scope="module")
def shell() -> list[str]:
    default = "/usr/local/bin/bash --posix" if sys.platform == "darwin" else "/bin/sh"
    command = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert command and shutil.which(command[0]), "Selected POSIX test shell is missing"
    if REQUIRE_BUSYBOX:
        assert Path(command[0]).name == "busybox" and command[1:] == ["ash"], (
            "Required BusyBox coverage must select busybox ash"
        )
    return command


@pytest.fixture(scope="module")
def legacy_fsync(tmp_path_factory: pytest.TempPathFactory) -> Path:
    compiler = shlex.split(os.environ.get("CC", "cc"))
    assert compiler and shutil.which(compiler[0]), (
        "C compiler required for errno fixture"
    )
    output = tmp_path_factory.mktemp("storage-fixture") / "legacy fsync"
    subprocess.run(
        [
            *compiler,
            "-std=c99",
            "-Wall",
            "-Wextra",
            "-Werror",
            str(ROOT / "tests/fixtures/fsync_legacy.c"),
            "-o",
            str(output),
        ],
        check=True,
        capture_output=True,
        timeout=30,
    )
    return output


def invoke(
    shell: list[str],
    script: str,
    *arguments: str | Path,
    fault: str = "clean",
    trace: bool = True,
) -> subprocess.CompletedProcess[bytes]:
    environment = os.environ.copy()
    environment.update(
        LC_ALL="POSIX",
        LANGUAGE="foreign-language",
        CFMGR_FSYNC_FAULT=fault,
    )
    if trace:
        environment["CFMGR_FSYNC_TRACE"] = "1"
    else:
        environment.pop("CFMGR_FSYNC_TRACE", None)
    return subprocess.run(
        [*shell, "-c", script, "storage-test", str(LIBRARY), *map(str, arguments)],
        env=environment,
        check=False,
        capture_output=True,
        timeout=10,
    )


FLUSH = '. "$1"; exec 3<"$3"; cfmgr_storage_flush_fd "$2" 4>&1'


def test_canonical_attachment_path_does_not_trim_unsafe_names(
    shell: list[str], tmp_path: Path
) -> None:
    readlink = shutil.which("greadlink") or shutil.which("readlink")
    assert readlink, "Native canonical-path reader is required"
    safe = tmp_path / "Entware data"
    safe.mkdir()
    unsafe = tmp_path / "Entware data\n"
    unsafe.mkdir()
    alias = tmp_path / "opt"
    alias.symlink_to(safe, target_is_directory=True)
    script = '. "$1"; cfmgr_storage_readlink=$2; _cfmgr_storage_canonical "$3"'
    result = invoke(shell, script, readlink, alias)
    assert result.returncode == 0, result.stderr
    assert result.stdout == os.fsencode(safe.resolve()) + b"\n"
    alias.unlink()
    alias.symlink_to(unsafe, target_is_directory=True)
    result = invoke(shell, script, readlink, alias)
    assert result.returncode != 0
    assert result.stdout == b""


def test_volume_uuid_requires_complete_matching_native_observation(
    shell: list[str], tmp_path: Path
) -> None:
    awk = shutil.which("awk")
    assert awk, "Native awk is required"
    uuid = "12345678-1234-abcd-9876-123456789abc"
    record = f'/dev/sdb1: LABEL="Entware data" UUID="{uuid}" TYPE="ext4"\n'
    observed = tmp_path / "blkid.out"
    script = (
        '. "$1"; cfmgr_storage_awk=$2; cfmgr_storage_source=/dev/sdb1; '
        'cfmgr_storage_filesystem=ext4; cfmgr_storage_uuid "$3" || exit $?; '
        'printf "%s\\n" "$cfmgr_storage_uuid_value"'
    )
    # The verified Merlin baseline disables FEATURE_BLKID_TYPE. Filesystem
    # admission comes from the separately verified mountinfo snapshot.
    for valid in (record, record.replace(' TYPE="ext4"', "")):
        observed.write_text(valid)
        result = invoke(shell, script, awk, observed)
        assert result.returncode == 0, result.stderr
        assert result.stdout == uuid.encode() + b"\n"
    for invalid in (
        record.replace("/dev/sdb1", "/dev/sda1"),
        record.replace('TYPE="ext4"', 'TYPE="tmpfs"'),
        record.replace('TYPE="ext4"', 'TYPE=""'),
        record.replace(f'UUID="{uuid}" ', ""),
        record + record,
        record.replace('TYPE="ext4"', f'UUID="{uuid}" TYPE="ext4"'),
        record.replace(uuid, "not-a-uuid"),
        record.replace("Entware data", 'Entware" UUID="injected'),
        record + "unrelated trailing record\n",
    ):
        observed.write_text(invalid)
        result = invoke(shell, script, awk, observed)
        assert result.returncode != 0, invalid
        assert result.stdout == b"", invalid


@pytest.mark.parametrize("directory", [False, True], ids=["file", "directory"])
def test_clean_flush_preserves_target_and_caller_state(
    shell: list[str], legacy_fsync: Path, tmp_path: Path, directory: bool
) -> None:
    target = tmp_path / "owned object"
    if directory:
        target.mkdir()
    else:
        target.write_bytes(b"unchanged data\n")
    before = target.stat()
    result = invoke(
        shell,
        '. "$1"; exec 3<"$3"; cfmgr_flush_result=caller-owned; '
        'cfmgr_storage_flush_fd "$2" 4>&1 || exit $?; '
        '[ "$LC_ALL" = POSIX ] && [ "$LANGUAGE" = foreign-language ] && '
        '[ "$cfmgr_flush_result" = caller-owned ] && (: <&3)',
        legacy_fsync,
        target,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"x", b"")
    after = target.stat()
    assert (after.st_ino, after.st_size, after.st_mtime_ns) == (
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
    )
    assert sorted(tmp_path.iterdir()) == [target]
    if not directory:
        assert target.read_bytes() == b"unchanged data\n"


@pytest.mark.parametrize(
    "fault", ["fsync", "newline", "stdout", "open", "nonzero", "signal"]
)
def test_faults_reject_silently_and_invoke_once(
    shell: list[str], legacy_fsync: Path, tmp_path: Path, fault: str
) -> None:
    target = tmp_path / "private name never diagnosed"
    target.write_bytes(b"preserved")
    result = invoke(shell, FLUSH, legacy_fsync, target, fault=fault)
    assert (result.returncode, result.stdout, result.stderr) == (1, b"x", b"")
    assert target.read_bytes() == b"preserved"
    assert list(tmp_path.iterdir()) == [target]


def test_fixture_reproduces_zero_exit_errno_defect(
    shell: list[str], legacy_fsync: Path, tmp_path: Path
) -> None:
    target = tmp_path / "target"
    target.touch()
    result = invoke(
        shell,
        'exec 3<"$3"; LC_ALL=C LANGUAGE= "$2" /proc/self/fd/3',
        legacy_fsync,
        target,
        fault="fsync",
        trace=False,
    )
    assert result.returncode == 0
    assert result.stdout == b""
    assert result.stderr.startswith(b"/proc/self/fd/3: ")
    assert b"Bad file descriptor" in result.stderr


@pytest.mark.parametrize(
    "call",
    [
        "cfmgr_storage_flush_fd",
        'cfmgr_storage_flush_fd "$2" extra',
        "cfmgr_storage_flush_fd relative",
        'cfmgr_storage_flush_fd ""',
        'cfmgr_storage_flush_fd "$3/missing"',
        'cfmgr_storage_flush_fd "$3"',
        'cfmgr_storage_flush_fd "$3/not-executable"',
        'exec 3<&-; cfmgr_storage_flush_fd "$2"',
    ],
)
def test_invalid_calls_do_not_execute_backend(
    shell: list[str], legacy_fsync: Path, tmp_path: Path, call: str
) -> None:
    target = tmp_path / "not-executable"
    target.write_bytes(b"not executable")
    result = invoke(
        shell,
        f'. "$1"; exec 3<"$3/not-executable"; {{ {call}; }} 4>&1',
        legacy_fsync,
        tmp_path,
    )
    assert (result.returncode, result.stdout, result.stderr) == (2, b"", b"")


def test_unusable_executable_diagnostics_are_contained(
    shell: list[str], tmp_path: Path
) -> None:
    target = tmp_path / "target"
    target.write_bytes(b"preserved")
    executable = tmp_path / "broken executable"
    executable.write_bytes(b"\x7fELF\x00broken")
    executable.chmod(0o700)
    result = invoke(shell, FLUSH, executable, target, trace=False)
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")
    assert target.read_bytes() == b"preserved"


def test_source_is_inert_and_probe_requires_explicit_run(shell: list[str]) -> None:
    source = invoke(
        shell,
        'exec 3<&-; cfmgr_flush_result=caller-owned; . "$1"; '
        '[ "$cfmgr_flush_result" = caller-owned ] && '
        '[ "$LC_ALL" = POSIX ] && [ "$LANGUAGE" = foreign-language ] && '
        "! ( : <&3 ) 2>/dev/null",
    )
    assert (source.returncode, source.stdout, source.stderr) == (0, b"", b"")
    for arguments in ([], ["--run"]):
        probe = subprocess.run(
            [*shell, str(PROBE), *arguments],
            check=False,
            capture_output=True,
            timeout=10,
        )
        assert probe.returncode == 2
        assert b"probe is inert" in probe.stdout
        assert probe.stderr == b""
    help_result = subprocess.run(
        [*shell, str(PROBE), "--help"], check=False, capture_output=True, timeout=10
    )
    assert help_result.returncode == 0 and help_result.stderr == b""
    assert b"ABSOLUTE_SCRATCH_DIR" in help_result.stdout
    for destination in ("relative", "/mnt/../tmp", "/mnt/unsafe\n/tmp"):
        invalid = subprocess.run(
            [*shell, str(PROBE), "--run", destination],
            check=False,
            capture_output=True,
            timeout=10,
        )
        assert invalid.returncode == 2 and invalid.stdout == b""
        assert b"not admitted" in invalid.stderr


@pytest.fixture(scope="module")
def native_fsync(tmp_path_factory: pytest.TempPathFactory) -> Path:
    """Only an actual Linux utility can prove /proc fd reopening here."""
    if sys.platform != "linux" or not Path("/proc/self/fd").is_dir():
        if REQUIRE_BUSYBOX:
            pytest.fail("Required Linux /proc descriptor integration is unavailable")
        pytest.skip(
            "Native /proc fd reopening requires Linux; host errno fixture is separate"
        )
    busybox = shutil.which("busybox")
    if busybox:
        applets = subprocess.run(
            [busybox, "--list"], capture_output=True, check=True, timeout=10
        ).stdout.splitlines()
        if b"fsync" in applets:
            executable = tmp_path_factory.mktemp("native-fsync") / "fsync"
            executable.symlink_to(busybox)
            return executable
    if REQUIRE_BUSYBOX:
        pytest.fail("Required BusyBox fsync applet is missing")
    executable_name = shutil.which("fsync")
    if executable_name:
        return Path(executable_name).absolute()
    pytest.skip("No installed native fsync or BusyBox fsync applet")


@pytest.mark.parametrize("directory", [False, True], ids=["file", "directory"])
def test_linux_native_proc_reopen(
    shell: list[str], native_fsync: Path, tmp_path: Path, directory: bool
) -> None:
    target = tmp_path / "actual native target"
    if directory:
        target.mkdir()
    else:
        target.write_bytes(b"native flush content\n")
    before = target.stat()
    result = invoke(shell, FLUSH, native_fsync, target, trace=False)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    after = target.stat()
    assert (after.st_ino, after.st_size, after.st_mtime_ns) == (
        before.st_ino,
        before.st_size,
        before.st_mtime_ns,
    )
    assert list(tmp_path.iterdir()) == [target]


def test_linux_busybox_zero_exit_diagnostic_is_rejected_silently(
    request: pytest.FixtureRequest, shell: list[str], tmp_path: Path
) -> None:
    if not REQUIRE_BUSYBOX:
        pytest.skip("Pinned vendor BusyBox is required for this diagnostic contract")
    native_busybox_fsync = request.getfixturevalue("native_fsync")
    # BusyBox opens with O_NOATIME: the non-root runner must own this inode.
    # Keep a writer on fd 5 so the read-only fd 3 reopen cannot block.
    fifo = tmp_path / "owned unsupported flush target"
    os.mkfifo(fifo, 0o600)
    open_fifo = '. "$1"; exec 5<>"$3"; exec 3<"$3"; '
    diagnostic = invoke(
        shell,
        open_fifo + 'LC_ALL=C LANGUAGE= "$2" /proc/self/fd/3',
        native_busybox_fsync,
        fifo,
        trace=False,
    )
    assert (diagnostic.returncode, diagnostic.stdout) == (0, b"")
    assert diagnostic.stderr.startswith(b"fsync: /proc/self/fd/3: ")
    assert diagnostic.stderr[len(b"fsync: /proc/self/fd/3: ") :].strip()
    result = invoke(
        shell,
        open_fifo + 'cfmgr_storage_flush_fd "$2" 4>&1',
        native_busybox_fsync,
        fifo,
        trace=False,
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def invoke_probe(
    shell: list[str],
    script: str,
    *,
    environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[bytes]:
    """Source the complete inert interface, then exercise its actual functions."""
    env = os.environ.copy()
    env.update(
        CFMGR_PROBE_LIBRARY=str(LIBRARY),
        CFMGR_PROBE_SOURCE=str(PROBE),
        LC_ALL="C",
        LANGUAGE="",
    )
    env.pop("CFMGR_FSYNC_TRACE", None)
    if environment:
        env.update(environment)
    return subprocess.run(
        [
            *shell,
            "-c",
            '. "$CFMGR_PROBE_LIBRARY"; set -- --define; '
            '. "$CFMGR_PROBE_SOURCE"; ' + script,
        ],
        env=env,
        capture_output=True,
        check=False,
        timeout=10,
    )


def test_probe_uid_and_mount_admission(shell: list[str], tmp_path: Path) -> None:
    status = tmp_path / "status"
    mounts = tmp_path / "mounts"
    for rows, accepted in (
        ("Name:\tsh\nUid:\t0\t0\t0\t0\n", True),
        ("Uid:\t0\t1000\t0\t0\n", False),
        ("Uid:\t0\t0\t0\n", False),
        ("Uid:\t0\t0\t0\t0\nUid:\t0\t0\t0\t0\n", False),
        ("Name:\tsh\n", False),
    ):
        status.write_text(rows)
        result = invoke_probe(
            shell,
            'cfmgr_probe_root_uid "$CFMGR_STATUS"',
            environment={"CFMGR_STATUS": str(status)},
        )
        assert (result.returncode == 0) is accepted, rows
    for rows, accepted in (
        ("/dev/test /jffs jffs2 rw,noatime 0 0\n", True),
        ("/dev/test /jffs jffs2 ro,noatime 0 0\n", False),
        ("/dev/test /jffs ext4 rw 0 0\n", False),
        ("/dev/test /elsewhere jffs2 rw 0 0\n", False),
        (
            "/dev/test /jffs jffs2 rw 0 0\n/dev/other /jffs jffs2 ro 0 0\n",
            False,
        ),
    ):
        mounts.write_text(rows)
        result = invoke_probe(
            shell,
            'cfmgr_probe_mounted /jffs jffs2 "$CFMGR_MOUNTS"',
            environment={"CFMGR_MOUNTS": str(mounts)},
        )
        assert (result.returncode == 0) is accepted, rows


def test_probe_mount_selection_is_portable_and_literal(
    shell: list[str], tmp_path: Path
) -> None:
    mounts = tmp_path / "mount table"
    mount = r"/tmp/mnt/Other drive\name"
    record = r"/dev/sdc2 /tmp/mnt/Other\040drive\134name ext4 rw,noatime 0 0" + "\n"
    script = 'cfmgr_probe_mount_record "$CFMGR_MOUNT" external "$CFMGR_MOUNTS"'
    for contents, accepted in (
        (record, True),
        (record.replace("ext4", "ext3"), True),
        (record.replace("rw,noatime", "ro,noatime"), False),
        (record.replace("ext4", "tmpfs"), False),
        (record.replace("/dev/sdc2", "tmpfs"), False),
        (record + record, False),
        (record.replace(r"\040", r"\011"), False),
    ):
        mounts.write_text(contents)
        result = invoke_probe(
            shell,
            script,
            environment={"CFMGR_MOUNT": mount, "CFMGR_MOUNTS": str(mounts)},
        )
        assert (result.returncode == 0) is accepted, contents
        assert result.stdout == (b"/dev/sdc2\n" if accepted else b"")


def test_probe_metadata_requires_exact_owner_mode_and_one_row(
    shell: list[str], tmp_path: Path
) -> None:
    target = tmp_path / "owned file"
    target.write_bytes(b"unchanged")
    target.chmod(0o600)
    env = {"CFMGR_TARGET": str(target), "CFMGR_OWNER": str(os.getuid())}
    result = invoke_probe(
        shell,
        'cfmgr_probe_metadata "$CFMGR_TARGET" -rw------- "$CFMGR_OWNER"',
        environment=env,
    )
    assert result.returncode == 0
    for body in (
        'cfmgr_probe_metadata "$CFMGR_TARGET" -rw-r--r-- "$CFMGR_OWNER"',
        'cfmgr_probe_metadata "$CFMGR_TARGET" -rw------- 999999',
        (
            'ls() { printf "%s\\n" "-rw------- 1 0 0 30 Jan 1 00:00 stage" '
            '"-rw------- 1 0 0 30 Jan 1 00:00 stage"; }; '
            'cfmgr_probe_metadata "$CFMGR_TARGET" -rw-------'
        ),
    ):
        assert invoke_probe(shell, body, environment=env).returncode == 1
    assert target.read_bytes() == b"unchanged"


def test_probe_missing_native_command_fails_before_writes(
    shell: list[str], tmp_path: Path
) -> None:
    commands = tmp_path / "commands"
    commands.mkdir()
    # An incomplete native-style PATH deliberately lacks mv, id and stat.
    for name in ("awk", "ls", "mkdir"):
        executable = shutil.which(name)
        assert executable
        (commands / name).symlink_to(executable)
    before = sorted(tmp_path.rglob("*"))
    result = invoke_probe(
        shell,
        "PATH=$CFMGR_COMMANDS; cfmgr_probe_preflight "
        '"$CFMGR_MISSING" "$CFMGR_MISSING" "$CFMGR_MISSING"',
        environment={
            "CFMGR_COMMANDS": str(commands),
            "CFMGR_MISSING": str(tmp_path / "missing"),
        },
    )
    assert (result.returncode, result.stdout, result.stderr) == (2, b"", b"")
    assert sorted(tmp_path.rglob("*")) == before


@pytest.fixture(scope="module")
def linux_proc() -> None:
    if sys.platform != "linux" or not Path("/proc/self/fd").is_dir():
        if REQUIRE_BUSYBOX:
            pytest.fail("Required probe descriptor ownership needs Linux /proc")
        pytest.skip("Probe held-descriptor cleanup requires Linux /proc")


def test_linux_probe_preflight_without_id_or_stat(
    shell: list[str], legacy_fsync: Path, linux_proc: None, tmp_path: Path
) -> None:
    commands = tmp_path / "commands"
    commands.mkdir()
    for name in ("awk", "ls", "mkdir", "mv", "rm", "rmdir", "cmp", "readlink"):
        executable = shutil.which(name)
        assert executable
        (commands / name).symlink_to(executable)
    # [ and printf/pwd may be shell builtins, or external native applets.
    for name in ("[", "printf", "pwd"):
        executable = shutil.which(name)
        if executable:
            (commands / name).symlink_to(executable)
    status = tmp_path / "root status"
    status.write_text("Uid:\t0\t0\t0\t0\n")
    result = invoke_probe(
        shell,
        "PATH=$CFMGR_COMMANDS; cfmgr_probe_preflight "
        '"$CFMGR_STATUS" /proc/mounts "$CFMGR_BACKEND"',
        environment={
            "CFMGR_COMMANDS": str(commands),
            "CFMGR_STATUS": str(status),
            "CFMGR_BACKEND": str(legacy_fsync),
        },
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert not (commands / "id").exists()
    assert not (commands / "stat").exists()


@pytest.mark.parametrize(
    "scenario",
    ["clean", "new-parent", "flush-failure", "signal", "replaced-file", "moved-root"],
)
def test_linux_probe_cleanup_and_identity(
    shell: list[str],
    legacy_fsync: Path,
    linux_proc: None,
    tmp_path: Path,
    scenario: str,
) -> None:
    parent = tmp_path / "scratch space"
    if scenario != "new-parent":
        parent.mkdir(mode=0o755)
        (parent / "pre-existing").write_bytes(b"preserved")
        before = parent.stat()
    hooks = {
        "signal": "cfmgr_storage_flush_fd() { read -r cfmgr_test_pid cfmgr_test_rest "
        '</proc/self/stat; kill -TERM "$cfmgr_test_pid"; }; ',
        "replaced-file": "cfmgr_storage_flush_fd() { rm stage; "
        'printf "%s" foreign >stage; return 1; }; ',
        "moved-root": 'cfmgr_storage_flush_fd() { mv "$cfmgr_probe_root" '
        '"$cfmgr_probe_root.moved"; mkdir "$cfmgr_probe_root"; return 1; }; ',
    }
    setup = 'exec 7<"$CFMGR_MOUNT"; cd /proc/self/fd/7; '
    result = invoke_probe(
        shell,
        hooks.get(scenario, "")
        + setup
        + 'cfmgr_probe_write "$CFMGR_PARENT" "$CFMGR_BACKEND" '
        '"$CFMGR_PARENT_MISSING" "$CFMGR_OWNER"',
        environment={
            "CFMGR_MOUNT": str(tmp_path),
            "CFMGR_PARENT": str(parent),
            "CFMGR_BACKEND": str(legacy_fsync),
            "CFMGR_PARENT_MISSING": "1" if scenario == "new-parent" else "0",
            "CFMGR_OWNER": str(os.getuid()),
            "CFMGR_FSYNC_FAULT": "fsync" if scenario == "flush-failure" else "clean",
        },
    )
    assert result.returncode == (0 if scenario in ("clean", "new-parent") else 1)
    assert parent.is_dir(), "The configured USB scratch base must remain"
    if scenario == "new-parent":
        assert parent.stat().st_mode & 0o777 == 0o700
        assert list(parent.iterdir()) == []
    else:
        assert parent.stat().st_mode == before.st_mode
        assert (parent / "pre-existing").read_bytes() == b"preserved"
    scratch = [path for path in parent.iterdir() if path.name.startswith(".cfmgr-")]
    if scenario == "replaced-file":
        assert len(scratch) == 1
        assert (scratch[0] / "stage").read_bytes() == b"foreign"
        assert b"ownership uncertain; retain" in result.stderr
    elif scenario == "moved-root":
        assert len(scratch) == 2
        moved = next(path for path in scratch if path.name.endswith(".moved"))
        assert (moved / "stage").read_bytes() == b"CFMgr native storage probe v1\n"
        assert b"ownership uncertain; retain" in result.stderr
    else:
        assert scratch == []
        assert b"Probe cleanup verified:" in result.stdout
        assert result.stderr == b""
    if scenario in ("clean", "new-parent"):
        assert b"staged rename/readback passed" in result.stdout


def test_pin_rejects_unadmitted_category_before_observing_storage(shell, tmp_path):
    category = tmp_path / "category.sh"
    category.write_text("# inert fixture category\n")
    link = tmp_path / "linked.sh"
    link.symlink_to(category)
    trace = tmp_path / "observed"
    tool = shutil.which("awk")
    readlink = shutil.which("readlink")
    assert tool and readlink
    script = r"""
. "$1"
cfmgr_test_trace=$6
_cfmgr_storage_canonical() { : >"$cfmgr_test_trace"; return 1; }
if cfmgr_storage_pin /opt "$2" "$3" "$4" /proc/self; then code=0; else code=$?; fi
printf "%s\n" "$code"
"""
    # The category guard must stop missing/symlink source before even native
    # attachment observation; a regular source is the positive control.
    for source, expected, observed in (
        (tmp_path / "missing.sh", 2, False),
        (link, 2, False),
        (category, 1, True),
    ):
        result = subprocess.run(
            [
                *shell,
                "-c",
                script,
                "category-admission",
                str(ROOT / "modules/lib/storage.sh"),
                readlink,
                tool,
                str(source),
                "reserved",
                str(trace),
            ],
            capture_output=True,
            check=False,
            timeout=3,
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            f"{expected}\n".encode(),
            b"",
        )
        assert trace.exists() == observed
