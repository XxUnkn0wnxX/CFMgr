"""Real inherited-descriptor metadata checks for the native test wrapper."""

from __future__ import annotations

import os
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_native_root import NativeRootFixture


def same_inode(path: Path, target: Path) -> bool:
    try:
        left, right = os.stat(path), os.stat(target)
    except OSError:
        return False
    return (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_test_wrapper_observes_real_descriptor_metadata(router: RouterHarness) -> None:
    fixture = NativeRootFixture(router)
    fixture.prepare()

    directory = router.path("work/metadata directory")
    directory.mkdir()
    other_directory = router.path("work/metadata-other-directory")
    other_directory.mkdir()
    file_one = router.path("work/metadata-one")
    file_one.write_text("retained descriptor eight\n", encoding="ascii")
    file_one_hardlink = router.path("work/metadata-one-hardlink")
    os.link(file_one, file_one_hardlink)
    file_one_symlink = router.path("work/metadata-one-symlink")
    file_one_symlink.symlink_to(file_one)
    file_two = router.path("work/metadata-two")
    file_two.write_text("retained descriptor nine\n", encoding="ascii")
    missing = router.path("work/metadata-missing")
    dangling = router.path("work/metadata-dangling")
    dangling.symlink_to(missing)
    loop_a = router.path("work/metadata-loop-a")
    loop_b = router.path("work/metadata-loop-b")
    loop_a.symlink_to(loop_b)
    loop_b.symlink_to(loop_a)

    test_tool = shlex.quote(str(fixture.tools / "test"))
    output = shlex.quote(str(router.path("work/metadata.stdout")))
    error = shlex.quote(str(router.path("work/metadata.stderr")))
    fd6 = shlex.quote(str(directory))
    fd8 = shlex.quote(str(file_one))
    fd9 = shlex.quote(str(file_two))

    def expectation(path: Path, target: Path) -> int:
        return int(not same_inode(path, target))

    cases = [
        (0, ["-d", "/proc/self/fd/6"]),
        (1, ["-d", "/proc/self/fd/9"]),
        (expectation(directory, directory), [str(directory), "-ef", "/proc/self/fd/6"]),
        (expectation(other_directory, directory), [str(other_directory), "-ef", "/proc/self/fd/6"]),
        (
            expectation(file_one_hardlink, file_one),
            [str(file_one_hardlink), "-ef", "/proc/self/fd/8"],
        ),
        (
            expectation(file_one_symlink, file_one),
            [str(file_one_symlink), "-ef", "/proc/self/fd/8"],
        ),
        (expectation(file_two, file_one), [str(file_two), "-ef", "/proc/self/fd/8"]),
        (expectation(file_two, file_two), [str(file_two), "-ef", "/proc/self/fd/9"]),
        (expectation(missing, file_one), [str(missing), "-ef", "/proc/self/fd/8"]),
        (expectation(dangling, file_one), [str(dangling), "-ef", "/proc/self/fd/8"]),
        (expectation(loop_a, file_one), [str(loop_a), "-ef", "/proc/self/fd/8"]),
    ]
    checks = "\n".join(
        f"check {expected} " + " ".join(shlex.quote(argument) for argument in arguments)
        for expected, arguments in cases
    )
    script = f"""
test_tool={test_tool}
output={output}
error={error}
exec 6<{fd6}
exec 8<{fd8}
exec 9<{fd9}
check() {{
    expected=$1
    shift
    "$test_tool" "$@" >"$output" 2>"$error"
    actual=$?
    if [ "$actual" -ne "$expected" ] || [ -s "$output" ] || [ -s "$error" ]; then
        printf 'metadata check failed: expected=%s actual=%s args=%s\\n' \\
            "$expected" "$actual" "$*" >&2
        exit 90
    fi
}}
{checks}
exec 8<&-
check 1 {shlex.quote(str(file_one))} -ef /proc/self/fd/8
check 0 -d /proc/self/fd/6
check 1 -d /proc/self/fd/9
check {expectation(file_two, file_two)} {shlex.quote(str(file_two))} -ef /proc/self/fd/9
IFS= read -r retained <&9 || exit 91
[ "$retained" = 'retained descriptor nine' ] || exit 92
exec 6<&-
check 1 -d /proc/self/fd/6
check 1 {shlex.quote(str(directory))} -ef /proc/self/fd/6
"""
    result = router.run(script)
    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""
