"""Fixed native-ash reference retention; mount lifetime uses storage's real fixture."""

from __future__ import annotations

import os
import signal
import subprocess
from pathlib import Path

import pytest
from test_storage_mounts import REQUIRE_BUSYBOX, ROOT
from test_storage_mounts import selected_shell as storage_selected_shell

selected_shell = storage_selected_shell

LIBRARY = ROOT / "modules/lib/mount_keeper.sh"
HELPER = ROOT / "modules/helpers/mount_keeper.sh"


@pytest.fixture(scope="module")
def keeper_tools(
    selected_shell: list[str], tmp_path_factory: pytest.TempPathFactory
) -> Path:
    if not REQUIRE_BUSYBOX:
        pytest.skip(
            "keeper process/fdinfo proof requires explicit Linux vendor BusyBox"
        )
    assert Path("/proc/self/fdinfo").is_dir(), (
        "Required keeper proof needs Linux procfs"
    )
    tools = tmp_path_factory.mktemp("keeper-tools")
    for applet in ("ash", "env", "mknod", "awk", "usleep", "[", "printf"):
        (tools / applet).symlink_to(selected_shell[0])
    return tools


@pytest.fixture
def keeper_setup() -> str:
    return r"""
set -f
umask 022
context=$1 tools=$2 root=$3
. "$root/modules/lib/prerequisites.sh"
. "$root/modules/lib/mount_keeper.sh"
cfmgr_mount_keeper_native() { (umask 077; "$2" "$3" p); }
start() {
    cfmgr_mount_keeper_start "$context" "$tools/ash" "$root/modules/helpers/mount_keeper.sh" \
        "$root/modules/lib/prerequisites.sh" "$tools/env" "$tools/mknod" "$tools/awk" "$tools/usleep"
}
cleanup() {
    # Test owns this one helper and never starts any package/task writer. Forced
    # failure cleanup is not production keeper-release or quiescence evidence.
    if [ -n "${cfmgr_keeper_pid:-}" ]; then
        if cfmgr_prerequisites_identity "$cfmgr_keeper_pid"; then
            if [ "$cfmgr_identity_start" = "$cfmgr_keeper_start" ]; then
                kill -KILL "$cfmgr_keeper_pid" 2>/dev/null || :
            fi
        fi
        wait "$cfmgr_keeper_pid" 2>/dev/null || :
    fi
    exec 3<&-
}
trap cleanup EXIT
'''


@pytest.fixture
def keeper_script(keeper_setup: str) -> str:
    return keeper_setup + r'''
# Invoke through a saved directory-stdin redirection frame. External shellexec
# must drop its saved copies before env exec; reserved outside FDs close too.
start_with_directory() { start; }
start_with_directory <"$context" || exit 10
set +f
for entry in /proc/"$cfmgr_keeper_pid"/fd/*; do
    number=${entry##*/}
    if [ "$number" -ge 4 ] && [ -d "$entry" ]; then exit 27; fi
done
set -f
printf '%s %s\n' "$cfmgr_keeper_pid" "$cfmgr_keeper_start" >"$context/test-child"
exec 4<"$context/original" 5<"$context/original" 6<"$context/original" 7<"$context/original" 8<"$context/original" 9<"$context/original"
id=$("$tools/awk" '/^mnt_id:/ { print $2 }' /proc/self/fdinfo/4)
"""


def run_keeper(
    selected_shell: list[str], keeper_tools: Path, tmp_path: Path, script: str
) -> subprocess.CompletedProcess[bytes]:
    os.chmod(tmp_path, 0o700)
    (tmp_path / "original").write_text("descriptor survives\n")
    try:
        return subprocess.run(
            [
                *selected_shell,
                "-c",
                script,
                "keeper-test",
                str(tmp_path),
                str(keeper_tools),
                str(ROOT),
            ],
            check=False,
            capture_output=True,
            timeout=12,
        )
    finally:
        # Timeout must not strand test-owned references. Check exact saved start
        # time before signalling; never adopt another process by reused PID.
        receipt = tmp_path / "test-child"
        if receipt.exists():
            pid, expected_start = receipt.read_text().split()
            stat = Path(f"/proc/{pid}/stat")
            if stat.exists():
                fields = stat.read_text().rsplit(") ", 1)[1].split()
                if fields[19] == expected_start and fields[0] != "Z":
                    os.kill(int(pid), signal.SIGKILL)


def assert_keeper_passed(result: subprocess.CompletedProcess[bytes]) -> None:
    assert result.returncode == 0, (
        f"keeper fixture failed: {result.stdout!r}\n{result.stderr.decode(errors='replace')}"
    )
    assert result.stdout == result.stderr == b""


def test_source_and_invalid_admission_do_not_mutate(
    selected_shell: list[str], tmp_path: Path
) -> None:
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            (
                '. "$1"; [ "${cfmgr_keeper_state-unset}" = unset ] || exit 1; '
                'cfmgr_mount_keeper_start invalid; [ "$?" = 2 ]'
            ),
            "fixture",
            str(LIBRARY),
        ],
        cwd=tmp_path,
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert_keeper_passed(result)
    assert list(tmp_path.iterdir()) == []


def test_recursive_file_and_directory_pins_preserve_parent_descriptors(
    selected_shell: list[str], keeper_tools: Path, keeper_script: str, tmp_path: Path
) -> None:
    script = (
        keeper_script
        + r"""
cfmgr_mount_keeper_retain "$id" 4<"$context" || exit 11
cfmgr_mount_keeper_retain "$id" 4<"$context/original" || exit 12
[ "$cfmgr_keeper_count" = 2 ] || exit 13
for fd in 4 5 6 7 8 9; do
    content=$("$tools/awk" '{print}' "/proc/self/fd/$fd")
    [ "$content" = 'descriptor survives' ] || exit 14
done
# A retry cannot replace a live keeper's identity, context or evidence.
saved_pid=$cfmgr_keeper_pid saved_context=$cfmgr_keeper_context
if start; then exit 15; else [ "$?" = 3 ] || exit 16; fi
[ "$cfmgr_keeper_pid" = "$saved_pid" ] && [ "$cfmgr_keeper_context" = "$saved_context" ] || exit 17
cfmgr_mount_keeper_release || exit 18
[ "$cfmgr_keeper_state" = released ] || exit 19
if (: <&3) 2>/dev/null; then exit 20; fi
"""
    )
    result = run_keeper(selected_shell, keeper_tools, tmp_path, script)
    assert_keeper_passed(result)
    for artifact in tmp_path.iterdir():
        if artifact.name not in {"original", "test-child"}:
            assert artifact.stat().st_mode & 0o777 == 0o600, artifact


@pytest.mark.parametrize("failure", ["death", "missing_pin", "unknown_ack", "deadline"])
def test_lost_reference_or_protocol_keeps_uncertainty(
    selected_shell: list[str],
    keeper_tools: Path,
    keeper_script: str,
    tmp_path: Path,
    failure: str,
) -> None:
    actions = {
        "death": r"""
kill -KILL "$cfmgr_keeper_pid"
wait "$cfmgr_keeper_pid" 2>/dev/null || :
if cfmgr_mount_keeper_check 0; then exit 21; else [ "$?" = 3 ] || exit 22; fi
if cfmgr_mount_keeper_release; then exit 23; else [ "$?" = 3 ] || exit 24; fi
""",
        "missing_pin": r"""
printf '2147483647\n' >>"$context/pins"
if cfmgr_mount_keeper_check 0; then exit 21; else [ "$?" = 3 ] || exit 22; fi
if cfmgr_mount_keeper_release; then exit 23; else [ "$?" = 3 ] || exit 24; fi
""",
        "unknown_ack": r"""
kill -STOP "$cfmgr_keeper_pid"
printf 'held 2 999 END\n' >"$context/receipt"
if cfmgr_mount_keeper_retain "$id" 4<"$context/original"; then exit 21; else [ "$?" = 3 ] || exit 22; fi
[ "$cfmgr_keeper_state" = retained ] || exit 23
if cfmgr_mount_keeper_release; then exit 24; else [ "$?" = 3 ] || exit 25; fi
""",
        "deadline": r"""
kill -STOP "$cfmgr_keeper_pid"
if cfmgr_mount_keeper_retain "$id" 4<"$context/original"; then exit 21; else [ "$?" = 3 ] || exit 22; fi
[ "$cfmgr_keeper_state" = retained ] || exit 23
if cfmgr_mount_keeper_release; then exit 24; else [ "$?" = 3 ] || exit 25; fi
""",
    }
    script = (
        keeper_script
        + '\ncfmgr_mount_keeper_retain "$id" 4<"$context" || exit 11\n'
        + actions[failure]
        + '[ -s "$context/pins" ] && [ -s "$context/receipt" ] || exit 26\n'
    )
    assert_keeper_passed(run_keeper(selected_shell, keeper_tools, tmp_path, script))


def test_nofile_headroom_rejects_before_files_or_child(
    selected_shell: list[str], keeper_tools: Path, tmp_path: Path
) -> None:
    script = r"""
. "$3/modules/lib/mount_keeper.sh"
ulimit -n 32
cfmgr_mount_keeper_start "$1" "$2/ash" "$3/modules/helpers/mount_keeper.sh" \
    "$3/modules/lib/prerequisites.sh" "$2/env" "$2/mknod" "$2/awk" "$2/usleep"
[ "$?" = 2 ]
"""
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            script,
            "fixture",
            str(tmp_path),
            str(keeper_tools),
            str(ROOT),
        ],
        check=False,
        capture_output=True,
        timeout=5,
    )
    assert_keeper_passed(result)
    assert list(tmp_path.iterdir()) == []


def test_orphan_and_signal_keep_frames_until_reviewed_release(
    selected_shell: list[str], keeper_tools: Path, keeper_script: str, tmp_path: Path
) -> None:
    os.chmod(tmp_path, 0o700)
    (tmp_path / "original").write_text("descriptor survives\n")
    script = (
        keeper_script
        + r"""
cfmgr_mount_keeper_retain "$id" 4<"$context" || exit 11
# Simulate controller disappearance without sending release or killing holder.
trap - EXIT
exit 0
"""
    )
    result = subprocess.run(
        [
            *selected_shell,
            "-c",
            script,
            "keeper-test",
            str(tmp_path),
            str(keeper_tools),
            str(ROOT),
        ],
        check=False,
        capture_output=True,
        timeout=8,
    )
    assert_keeper_passed(result)
    pid, start = (tmp_path / "test-child").read_text().split()
    proc = Path(f"/proc/{pid}")
    try:
        fields = (proc / "stat").read_text().rsplit(") ", 1)[1].split()
        assert fields[19] == start and fields[0] != "Z"
        os.kill(int(pid), signal.SIGTERM)
        expected = set((tmp_path / "pins").read_text().splitlines())
        held: set[str] = set()
        for descriptor in (proc / "fdinfo").iterdir():
            for line in descriptor.read_text().splitlines():
                if line.startswith("mnt_id:"):
                    held.add(line.split()[1])
        assert expected <= held
        fields = (proc / "stat").read_text().rsplit(") ", 1)[1].split()
        assert fields[19] == start and fields[0] != "Z"
    finally:
        # Known test-owned orphan only; no product task or mount writer exists.
        if (proc / "stat").exists():
            fields = (proc / "stat").read_text().rsplit(") ", 1)[1].split()
            if fields[19] == start and fields[0] != "Z":
                os.kill(int(pid), signal.SIGKILL)


def test_malformed_sequence_does_not_unwind_retained_frames(
    selected_shell: list[str], keeper_tools: Path, keeper_script: str, tmp_path: Path
) -> None:
    script = (
        keeper_script
        + r"""
i=0
while [ "$i" -lt 7 ]; do
    cfmgr_mount_keeper_retain "$id" 4<"$context" || exit 11
    i=$((i+1))
done
# Expected next sequence is8. Reject 08 without assigning/arithmetic or opening.
printf 'hold 08 %s\n' "$id" >&3
cfmgr_mount_keeper_check 0 || exit 12
# Invalid protocol retained frames; explicit qualified release remains possible.
cfmgr_mount_keeper_release || exit 13
"""
    )
    assert_keeper_passed(run_keeper(selected_shell, keeper_tools, tmp_path, script))


def test_control_read_eof_parks_with_open_frame(
    selected_shell: list[str], keeper_tools: Path, keeper_setup: str, tmp_path: Path
) -> None:
    # A finite regular control stream is deliberate fault injection, not an
    # admitted production FIFO. It opens one frame then produces persistent EOF.
    script = (
        keeper_setup
        + r"""
umask 077
cfmgr_keeper_context=$context cfmgr_keeper_awk=$tools/awk cfmgr_keeper_usleep=$tools/usleep
IFS= read -r self </proc/self/stat
cfmgr_keeper_owner=${self%% *}
cfmgr_prerequisites_identity "$cfmgr_keeper_owner" || exit 10
owner_start=$cfmgr_identity_start
IFS= read -r cfmgr_keeper_boot </proc/sys/kernel/random/boot_id
exec 4<"$context"
id=$("$tools/awk" '/^mnt_id:/ { print $2 }' /proc/self/fdinfo/4)
printf 'hold 1 %s\n' "$id" >"$context/finite-control"
"$tools/env" -i PATH="$tools:/bin:/usr/bin:/sbin:/usr/sbin" LC_ALL=C \
    "$tools/ash" "$root/modules/helpers/mount_keeper.sh" "$context" "$cfmgr_keeper_owner" \
    "$owner_start" "$cfmgr_keeper_boot" 8 "$tools/awk" "$root/modules/lib/prerequisites.sh" "$tools/usleep" \
    3<"$context/finite-control" 4<&- 5<&- 6<&- 7<&- 8<&- 9<&- </dev/null >"$context/stdout" 2>"$context/stderr" &
cfmgr_keeper_pid=$!
cfmgr_prerequisites_identity "$cfmgr_keeper_pid" || exit 11
cfmgr_keeper_start=$cfmgr_identity_start
printf '%s %s\n' "$cfmgr_keeper_pid" "$cfmgr_keeper_start" >"$context/test-child"
cfmgr_keeper_receipt='ready 0 0 END'
_cfmgr_keeper_wait held 1 "$id" || exit 12
ticks() {
    IFS= read -r stat_line <"/proc/$cfmgr_keeper_pid/stat" || return 1
    tail=${stat_line##*) }
    set -- $tail
    shift 11
    printf '%s\n' "$(($1 + $2))"
}
before=$(ticks)
"$tools/usleep" 150000
after=$(ticks)
[ "$((after-before))" -le "$cpu_budget" ] || exit 15
_cfmgr_keeper_owned || exit 13
found=0
set +f
for entry in /proc/"$cfmgr_keeper_pid"/fd/*; do
    if [ -d "$entry" ]; then found=1; fi
done
[ "$found" = 1 ] || exit 14
"""
    )
    assert_keeper_passed(run_keeper(selected_shell, keeper_tools, tmp_path, script))
