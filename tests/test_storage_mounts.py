"""Real Linux ext4 mount and descriptor proof for storage attachment checks."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tests/fixtures/storage_mounts.sh"
REQUIRE_BUSYBOX = os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1"


@pytest.fixture(scope="module")
def selected_shell() -> list[str]:
    default = "/bin/sh"
    shell = shlex.split(os.environ.get("CFMGR_TEST_SHELL", default))
    assert shell, "Selected POSIX test shell is empty"
    executable = shutil.which(shell[0])
    assert executable, f"Selected POSIX test shell is missing: {shell[0]}"
    shell[0] = executable
    if REQUIRE_BUSYBOX:
        assert Path(shell[0]).name == "busybox" and shell[1:] == ["ash"], (
            "Required BusyBox coverage must select busybox ash"
        )
    return shell


@pytest.fixture(scope="module")
def fixture_tools(selected_shell: list[str]) -> tuple[list[str], str, str, str]:
    if not REQUIRE_BUSYBOX:
        pytest.skip(
            "real ext4 mount fixtures run only in the explicit required BusyBox validation"
        )
    assert sys.platform == "linux", "Required BusyBox mount proof requires Linux"

    required = (
        "sudo",
        "unshare",
        "timeout",
        "truncate",
        "mkfs.ext4",
        "losetup",
        "mount",
        "umount",
        "mountpoint",
        "blkid",
        "readlink",
        "awk",
        "stat",
        "id",
    )
    paths: dict[str, str] = {}
    for name in required:
        executable = shutil.which(name)
        assert executable, f"Required Linux mount fixture tool is missing: {name}"
        paths[name] = executable

    sudo = paths["sudo"]
    unshare = paths["unshare"]
    # Capability failures are failures on Linux CI, not skips. This verifies
    # that the exact private mount namespace requested by the fixture is usable.
    probe = subprocess.run(
        [sudo, "-n", unshare, "--mount", "--propagation", "private", "/bin/true"],
        check=False,
        capture_output=True,
        timeout=10,
    )
    assert probe.returncode == 0, (
        "Linux storage fixture requires passwordless sudo and private mount namespaces: "
        f"{probe.stderr.decode(errors='replace')}"
    )
    return selected_shell, paths["readlink"], paths["awk"], paths["timeout"]


def run_fixture(
    fixture_tools: tuple[list[str], str, str, str], case: str, workdir: Path
) -> subprocess.CompletedProcess[bytes]:
    shell, readlink, awk, timeout = fixture_tools
    os.chmod(workdir, 0o700)
    parent_namespace = os.readlink("/proc/self/ns/mnt")
    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    command = [
        shutil.which("sudo") or "sudo",
        "-n",
        shutil.which("unshare") or "unshare",
        "--mount",
        "--propagation",
        "private",
        timeout,
        "--signal=TERM",
        "--kill-after=2",
        "25",
        *shell,
        str(FIXTURE),
        str(ROOT),
        case,
        str(workdir),
        readlink,
        awk,
        parent_namespace,
        str(os.getuid()),
        shell[0],
    ]
    result = subprocess.run(
        command,
        env=environment,
        check=False,
        capture_output=True,
        timeout=30,
    )
    # The fixture owns this exact child path and removes it in its EXIT trap.
    # Preserve its diagnostics if uncertain cleanup deliberately retained data.
    assert list(workdir.iterdir()) == [], (
        "Storage fixture left private files behind:\n"
        f"stdout: {result.stdout.decode(errors='replace')}\n"
        f"stderr: {result.stderr.decode(errors='replace')}"
    )
    return result


def assert_fixture_passed(
    result: subprocess.CompletedProcess[bytes], case: str
) -> None:
    assert result.returncode == 0, (
        f"Linux storage mount fixture failed ({case}):\n"
        f"stdout: {result.stdout.decode(errors='replace')}\n"
        f"stderr: {result.stderr.decode(errors='replace')}"
    )
    assert result.stderr == b"", result.stderr.decode(errors="replace")
    assert result.stdout.startswith(b"PASS: "), result.stdout.decode(errors="replace")


def test_real_ext4_attachment_uuid_and_descriptor_lifetime(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "valid", tmp_path)
    assert_fixture_passed(result, "valid")


def test_alias_substitution_is_denied_without_changing_data(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "alias_substitution", tmp_path)
    assert_fixture_passed(result, "alias_substitution")


def test_lazy_detach_does_not_adopt_different_uuid_replacement(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "lazy_replacement", tmp_path)
    assert_fixture_passed(result, "lazy_replacement")


def test_bind_mount_preserves_filesystem_root_and_volume_relative_identity(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "bind_identity", tmp_path)
    assert_fixture_passed(result, "bind_identity")


def test_read_only_and_noexec_ext4_mounts_are_denied(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path
) -> None:
    result = run_fixture(fixture_tools, "ro_noexec", tmp_path)
    assert_fixture_passed(result, "ro_noexec")


@pytest.mark.parametrize("case", ["backup_folder", "backup_replacement"])
def test_backup_destination_real_mount_safety(fixture_tools, tmp_path, case):
    result = run_fixture(fixture_tools, case, tmp_path)
    assert_fixture_passed(result, case)


def test_archive_source_pin_preserves_destination_and_denies_alias_loss(
    fixture_tools, tmp_path
):
    result = run_fixture(fixture_tools, "archive_source", tmp_path)
    assert_fixture_passed(result, "archive_source")


def test_fixture_rejects_wrong_argument_count_before_setup(
    selected_shell: list[str],
) -> None:
    result = subprocess.run(
        [*selected_shell, str(FIXTURE)],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 2
    assert result.stdout == b""
    assert result.stderr.startswith(b"storage mount fixture: expected seven arguments")


def test_fixture_rejects_unknown_case_before_setup(
    selected_shell: list[str], tmp_path: Path
) -> None:
    result = subprocess.run(
        [
            *selected_shell,
            str(FIXTURE),
            str(ROOT),
            "invalid-case",
            str(tmp_path),
            "/bin/readlink",
            "/usr/bin/awk",
            "mnt:[parent]",
            str(os.getuid()),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 2
    assert result.stdout == b""
    assert result.stderr.startswith(b"storage mount fixture: invalid case")
    assert list(tmp_path.iterdir()) == []


@pytest.mark.parametrize("case", ["view_compat", "view_detach", "view_cleanup"])
def test_guarded_execution_view_real_mounts(
    fixture_tools: tuple[list[str], str, str, str], tmp_path: Path, case: str
) -> None:
    result = run_fixture(fixture_tools, case, tmp_path)
    assert_fixture_passed(result, case)


def test_execution_view_source_is_inert(
    selected_shell: list[str], tmp_path: Path
) -> None:
    before = list(tmp_path.iterdir())
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            (
                'before=$PWD; . "$1"; . "$2"; [ "$PWD" = "$before" ] && '
                '[ "${cfmgr_view_state-unset}" = unset ]'
            ),
            "fixture",
            str(ROOT / "modules/lib/storage.sh"),
            str(ROOT / "modules/lib/execution.sh"),
        ],
        cwd=tmp_path,
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == result.stderr == b""
    assert list(tmp_path.iterdir()) == before


def ledger_row(
    mount_id: int,
    parent: int,
    point: str,
    *,
    device: str = "0:22",
    fsroot: str = "/",
    options: str = "rw,relatime",
    propagation: str = "private",
) -> str:
    return (
        f"{mount_id}\t{parent}\t{device}\t{fsroot}\t{point}\ttmpfs\ttmpfs\t"
        f"{options}\trw,size=64k\t{propagation}\n"
    )


@pytest.fixture(scope="module")
def ledger_tools(
    selected_shell: list[str], tmp_path_factory: pytest.TempPathFactory
) -> tuple[list[str], str]:
    if REQUIRE_BUSYBOX:
        awk = tmp_path_factory.mktemp("native-ledger") / "awk"
        awk.symlink_to(selected_shell[0])
        return selected_shell, str(awk)
    awk = shutil.which("awk")
    assert awk, "Host ledger parser requires AWK"
    return selected_shell, awk


def run_ledger(
    ledger_tools: tuple[list[str], str], mode: str, *arguments: str | Path
) -> subprocess.CompletedProcess[bytes]:
    shell, awk = ledger_tools
    return subprocess.run(
        [
            *shell,
            "-c",
            'cfmgr_view_awk=$1; shift; . "$1"; shift; cfmgr_execution_view_awk "$@"',
            "ledger",
            awk,
            str(ROOT / "modules/lib/execution.sh"),
            mode,
            *(str(argument) for argument in arguments),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )


def test_ledger_keeps_exact_layers_and_rejects_foreign_cleanup(
    ledger_tools: tuple[list[str], str], tmp_path: Path
) -> None:
    expected = tmp_path / "expected"
    current = tmp_path / "current"
    namespace = tmp_path / "namespace"
    recovered = tmp_path / "recovered"
    top = tmp_path / "top"
    guard = ledger_row(20, 1, "/owned/opt", options="ro,relatime")
    leaf = ledger_row(21, 20, "/owned/opt", device="8:1")
    expected.write_text(guard + leaf)
    current.write_text(guard + leaf)
    namespace.write_text(guard + leaf)
    assert run_ledger(ledger_tools, "top", "/owned/opt", current, top).returncode == 0
    assert top.read_text() == "21\n"
    assert (
        run_ledger(
            ledger_tools, "recover", expected, namespace, current, recovered
        ).returncode
        == 0
    )
    assert recovered.read_bytes() == expected.read_bytes()
    # A device leaf disappearing from the full namespace may be reconciled;
    # a moved, reused, or hidden ID elsewhere remains ambiguous.
    current.write_text(guard)
    namespace.write_text(guard)
    assert (
        run_ledger(
            ledger_tools, "recover", expected, namespace, current, recovered
        ).returncode
        == 0
    )
    assert recovered.read_text() == guard
    namespace.write_text(guard + ledger_row(21, 1, "/elsewhere"))
    assert (
        run_ledger(
            ledger_tools, "recover", expected, namespace, current, recovered
        ).returncode
        == 1
    )
    assert recovered.read_bytes() == b""
    current.write_text(guard + leaf + ledger_row(22, 21, "/owned/opt"))
    namespace.write_bytes(current.read_bytes())
    assert (
        run_ledger(
            ledger_tools, "recover", expected, namespace, current, recovered
        ).returncode
        == 1
    )
    assert recovered.read_bytes() == b""


def test_ledger_requires_private_cover_and_exact_bind_properties(
    ledger_tools: tuple[list[str], str], tmp_path: Path
) -> None:
    namespace = tmp_path / "namespace"
    namespace.write_text(ledger_row(1, 0, "/"))
    assert (
        run_ledger(ledger_tools, "cover-private", "/ram/context", namespace).returncode
        == 0
    )
    namespace.write_text(
        ledger_row(1, 0, "/") + ledger_row(2, 1, "/ram", propagation="shared:2")
    )
    assert (
        run_ledger(ledger_tools, "cover-private", "/ram/context", namespace).returncode
        == 1
    )
    source = tmp_path / "source"
    bound = tmp_path / "bound"
    source.write_text(ledger_row(10, 1, "/volume", device="8:1", fsroot="/sub"))
    bound.write_text(
        ledger_row(20, 1, "/owned/opt", device="8:1", fsroot="/sub/entware")
    )
    assert (
        run_ledger(
            ledger_tools, "bind-proof", "/volume/entware", "/owned/opt", source, bound
        ).returncode
        == 0
    )
    bound.write_text(
        ledger_row(
            20,
            1,
            "/owned/opt",
            device="8:1",
            fsroot="/sub/entware",
            options="ro,relatime",
        )
    )
    assert (
        run_ledger(
            ledger_tools, "bind-proof", "/volume/entware", "/owned/opt", source, bound
        ).returncode
        == 1
    )
    bound.write_text(
        ledger_row(20, 1, "/owned/opt", device="8:2", fsroot="/sub/entware")
    )
    assert (
        run_ledger(
            ledger_tools, "bind-proof", "/volume/entware", "/owned/opt", source, bound
        ).returncode
        == 1
    )


def test_execution_view_rejects_reserved_descriptor_before_mutation(
    selected_shell: list[str], tmp_path: Path
) -> None:
    context = tmp_path / "context"
    context.mkdir()
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            (
                '. "$1"; . "$2"; shift 2; exec 4<"$1"; '
                "cfmgr_execution_view_native() { echo unexpected; return 3; }; "
                'cfmgr_execution_view_create "$@"; code=$?; '
                '[ "$code" = 2 ] && [ "$cfmgr_view_state" = invalid ]'
            ),
            "fixture",
            str(ROOT / "modules/lib/storage.sh"),
            str(ROOT / "modules/lib/execution.sh"),
            str(tmp_path),
            str(context),
            "/usr/bin/awk",
            "/bin/readlink",
            str(ROOT / "modules/lib/storage.sh"),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == result.stderr == b""
    assert list(context.iterdir()) == []


def test_unresolved_native_operation_preserves_intent_and_blocks_release(
    selected_shell: list[str], tmp_path: Path
) -> None:
    (tmp_path / "expected.mounts").touch()
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            (
                '. "$1"; cfmgr_view_context=$2; cfmgr_view_sequence=0; '
                "cfmgr_view_pending=; cfmgr_view_state=building; cfmgr_view_pin_state=active; "
                "cfmgr_execution_view_keeper() { return 0; }; "
                "cfmgr_execution_view_native() { "
                'case $1 in inventory) : >"$3" ;; awk) return 0 ;; '
                "root) return 3 ;; *) echo unexpected; return 2 ;; esac; }; "
                "cfmgr_execution_view_quiescent() { return 0; }; "
                "_cfmgr_view_mutate root /owned/view; code=$?; "
                '[ "$code" = 3 ] && [ -n "$cfmgr_view_pending" ] || exit 1; '
                "cfmgr_execution_view_release; code=$?; "
                '[ "$code" = 3 ] && [ "$cfmgr_view_state" = retained ]'
            ),
            "fixture",
            str(ROOT / "modules/lib/execution.sh"),
            str(tmp_path),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout == result.stderr == b""
    assert (tmp_path / "intent.1").read_text() == "root\t/owned/view\n"
    assert not (tmp_path / "done.1").exists()
    assert (tmp_path / "expected.mounts").read_bytes() == b""
