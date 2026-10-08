"""Bounded native image staging; synthetic bytes do not prove ELF admission."""

from __future__ import annotations

import hashlib
import os
import shlex
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/closure.sh"
PROFILE_FILES = {
    "aarch64-k3.10": (
        "lib/ld-2.27.so",
        "lib/libc-2.27.so",
        "lib/libpthread-2.27.so",
        "lib/librt-2.27.so",
        "libexec/timeout-coreutils",
        "libexec/gzip-gnu",
    ),
    "armv7sf-k3.2": (
        "lib/ld-2.27.so",
        "lib/libc-2.27.so",
        "lib/libpthread-2.27.so",
        "lib/librt-2.27.so",
        "lib/libgcc_s.so.1",
        "libexec/timeout-coreutils",
        "libexec/gzip-gnu",
    ),
    "mipselsf-k3.4": (
        "lib/ld-2.27.so",
        "lib/libc-2.27.so",
        "lib/libpthread-2.27.so",
        "lib/librt-2.27.so",
        "lib/libgcc_s.so.1",
        "libexec/timeout-coreutils",
        "libexec/gzip-gnu",
    ),
}
LINKS = {
    "libc.so.6": "libc-2.27.so",
    "libpthread.so.0": "libpthread-2.27.so",
    "librt.so.1": "librt-2.27.so",
}
LOADER_LINK = {
    "aarch64-k3.10": ("ld-linux-aarch64.so.1", "ld-2.27.so"),
    "armv7sf-k3.2": ("ld-linux.so.3", "ld-2.27.so"),
    "mipselsf-k3.4": ("ld.so.1", "ld-2.27.so"),
}
TOOL_NAMES = ("mkdir", "dd", "wc", "env", "openssl", "hexdump", "ln", "chmod")
pytestmark = pytest.mark.integration


def manifest_bytes(profile: str, contents: dict[str, bytes]) -> bytes:
    rows = []
    for relative in PROFILE_FILES[profile]:
        data = contents.get(relative, b"x")
        rows.append(f"{relative}\t{len(data)}\t{hashlib.sha256(data).hexdigest()}\n".encode())
    return b"".join(rows)


def manifest_sizes(profile: str, sizes: dict[str, int]) -> bytes:
    return b"".join(
        f"{relative}\t{sizes.get(relative, 1)}\t{'0' * 64}\n".encode()
        for relative in PROFILE_FILES[profile]
    )


def native_path(name: str, busybox: Path | None = None) -> str:
    path = shutil.which(name, path="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin")
    if path is None and name == "hexdump" and busybox is not None:
        path = str(busybox)
    if path is None:
        pytest.fail(f"required native {name} is unavailable; it must be preinstalled")
    return os.path.realpath(path)


class ClosureFixture:
    def __init__(self, router: RouterHarness, busybox: Path | None = None):
        self.router = router
        self.guard = router.path("ram/tmp/closure guard")
        self.guard.mkdir(mode=0o700)
        self.base = router.path("opt/approved base")
        (self.base / "lib").mkdir(parents=True, mode=0o700)
        (self.base / "libexec").mkdir(mode=0o700)
        self.inputs = router.path("work/inputs")
        self.inputs.mkdir(mode=0o700)
        self.tools = router.path("work/native tools")
        self.tools.mkdir(mode=0o700)
        self.manifest = router.path("work/manifest.tsv")
        self.profile = "armv7sf-k3.2"
        self.contents: dict[str, bytes] = {}
        for index, relative in enumerate(PROFILE_FILES[self.profile], 1):
            data = f"synthetic opaque image member {index}\n".encode()
            self.contents[relative] = data
            source = self.source(relative)
            source.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
            source.write_bytes(data)
            source.chmod(0o600)
        self.write_manifest()
        for name in TOOL_NAMES:
            router.path(f"work/native tools/{name}").symlink_to(
                native_path(name, router.busybox or busybox)
            )

    def source(self, relative: str) -> Path:
        if relative.startswith("libexec/"):
            return self.inputs / Path(relative).name
        return self.base / relative

    def write_manifest(self, data: bytes | None = None) -> None:
        self.manifest.write_bytes(
            data if data is not None else manifest_bytes(self.profile, self.contents)
        )
        self.manifest.chmod(0o600)

    def run(self, *, shell: str | None = None, base: Path | None = None) -> ShellResult:
        script = (
            f". {shlex.quote(str(SOURCE))}\n"
            'cfmgr_closure_test "$@"\n'
            "_closure_rc=$?\n"
            'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\n" "$_closure_rc" '
            '"$_closure_complete" "${_closure_total:-unset}" "${_closure_opt:-unset}"\n'
        )
        subject = self.router.write("work/closure-invoke.sh", script)
        if shell:
            invocation = f'exec {shlex.quote(shell)} "$@"\n'
        elif self.router.busybox:
            invocation = f'exec {shlex.quote(str(self.router.busybox))} sh "$@"\n'
        else:
            invocation = 'exec /bin/sh "$@"\n'
        return self.router.run(
            invocation,
            [
                str(subject),
                str(self.guard),
                self.profile,
                str(self.manifest),
                str(self.inputs / "timeout-coreutils"),
                str(self.inputs / "gzip-gnu"),
                str(base or self.base),
                str(self.tools),
            ],
            timeout=15,
        )

    def assert_success(self, result: ShellResult) -> None:
        assert result.stderr == ""
        fields = result.stdout.strip().split("\t")
        assert fields == [
            "RESULT",
            "0",
            "1",
            str(sum(map(len, self.contents.values()))),
            str(self.guard / "closure/opt"),
        ]


@pytest.fixture
def closure(router: RouterHarness, pytestconfig: pytest.Config) -> ClosureFixture:
    return ClosureFixture(router, pytestconfig._cfmgr_busybox)


@pytest.mark.matrix("V74", evidence="host")
def test_small_native_stage_copies_hashes_and_builds_fixed_profile_layout(
    closure: ClosureFixture,
) -> None:
    result = closure.run()
    closure.assert_success(result)
    opt = closure.guard / "closure/opt"
    expected_paths = [
        *PROFILE_FILES[closure.profile],
        *(f"lib/{name}" for name in LINKS),
        f"lib/{LOADER_LINK[closure.profile][0]}",
    ]
    assert sorted(
        path.relative_to(opt).as_posix() for path in opt.rglob("*") if not path.is_dir()
    ) == sorted(expected_paths)
    for relative, expected in closure.contents.items():
        staged = opt / relative
        assert staged.read_bytes() == expected
        assert staged.stat().st_mode & 0o777 == (
            0o444 if relative == "lib/libgcc_s.so.1" else 0o555
        )
    for name, target in {
        **LINKS,
        LOADER_LINK[closure.profile][0]: LOADER_LINK[closure.profile][1],
    }.items():
        link = opt / "lib" / name
        assert link.is_symlink() and os.readlink(link) == target
    assert (opt / "lib").stat().st_mode & 0o777 == 0o555
    assert (opt / "libexec").stat().st_mode & 0o777 == 0o555
    assert (closure.guard / "closure").stat().st_mode & 0o777 == 0o700


@pytest.mark.matrix("V74", evidence="host")
def test_hash_mismatch_retains_partial_stage_without_publishing_completion(
    closure: ClosureFixture,
) -> None:
    original = closure.contents["lib/ld-2.27.so"]
    closure.contents["lib/ld-2.27.so"] = b"X" * len(original)
    closure.write_manifest()
    closure.contents["lib/ld-2.27.so"] = original
    result = closure.run()
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.strip().split("\t") == ["RESULT", "1", "0", "unset", "unset"]
    partial = closure.guard / "closure/opt/lib/ld-2.27.so"
    assert partial.read_bytes() == original
    assert partial.stat().st_mode & 0o777 == 0o600
    private_dirs = [
        path
        for path in (closure.guard / "closure").iterdir()
        if path.is_dir() and path.name != "opt"
    ]
    assert private_dirs and all(path.stat().st_mode & 0o777 == 0o700 for path in private_dirs)


@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize("source_shape", ["overlong", "short"])
def test_bounded_copy_rejects_overlong_and_short_sources_without_completion(
    closure: ClosureFixture, source_shape: str
) -> None:
    relative = "lib/ld-2.27.so"
    source = closure.source(relative)
    if source_shape == "overlong":
        source_data = b"L" * (2 * 65536 + 17)
        copied_size = 65536
    else:
        source_data = b"short"
        copied_size = len(source_data)
    source.write_bytes(source_data)

    result = closure.run()
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.strip().split("\t") == ["RESULT", "1", "0", "unset", "unset"]
    partial = closure.guard / "closure/opt/lib/ld-2.27.so"
    assert partial.stat().st_size == copied_size
    assert partial.read_bytes() == source_data[:copied_size]


@pytest.mark.matrix("V74", evidence="host")
def test_manifest_consumer_checks_profiles_grammar_and_resource_limits(
    router: RouterHarness,
) -> None:
    manifest_dir = router.path("work/manifests")
    manifest_dir.mkdir(mode=0o700)
    good_by_profile = {profile: manifest_bytes(profile, {}) for profile in PROFILE_FILES}
    limit_file = list(PROFILE_FILES["aarch64-k3.10"])
    good_by_profile["aarch64-k3.10-file-max"] = manifest_sizes(
        "aarch64-k3.10", {limit_file[0]: 4_194_304}
    )
    good_by_profile["aarch64-k3.10-total-max"] = manifest_sizes(
        "aarch64-k3.10", {limit_file[0]: 4_194_304, limit_file[1]: 4_194_300}
    )
    over_total = manifest_sizes(
        "aarch64-k3.10", {limit_file[0]: 4_194_304, limit_file[1]: 4_194_301}
    )
    first_row = good_by_profile["aarch64-k3.10"].splitlines()[0]
    bad = {
        "reversed": b"".join(reversed(good_by_profile["aarch64-k3.10"].splitlines(keepends=True))),
        "missing": b"".join(good_by_profile["aarch64-k3.10"].splitlines(keepends=True)[:-1]),
        "extra": good_by_profile["aarch64-k3.10"] + b"comment\n",
        "extra-field": good_by_profile["aarch64-k3.10"].replace(b"\n", b"\textra\n", 1),
        "bad-path": good_by_profile["aarch64-k3.10"].replace(
            b"lib/ld-2.27.so", b"lib/../ld-2.27.so", 1
        ),
        "empty-line": good_by_profile["aarch64-k3.10"] + b"\n",
        "empty": b"",
        "torn": good_by_profile["aarch64-k3.10"].rstrip(b"\n"),
        "nul": good_by_profile["aarch64-k3.10"].replace(b"\t1\t", b"\t1\x00\t", 1),
        "uppercase-digest": b"".join(
            b"\t".join(
                [
                    row.split(b"\t")[0],
                    row.split(b"\t")[1],
                    b"A" + row.split(b"\t")[2][1:],
                ]
            )
            + b"\n"
            for row in good_by_profile["aarch64-k3.10"].splitlines()
        ),
        "bad-digest": b"\n".join(
            [
                b"\t".join(
                    [
                        first_row.split(b"\t")[0],
                        first_row.split(b"\t")[1],
                        first_row.split(b"\t")[2][:-1] + b"g",
                    ]
                ),
                *good_by_profile["aarch64-k3.10"].splitlines()[1:],
            ]
        )
        + b"\n",
        "zero-size": good_by_profile["aarch64-k3.10"].replace(b"\t1\t", b"\t0\t", 1),
        "leading-zero": good_by_profile["aarch64-k3.10"].replace(b"\t1\t", b"\t01\t", 1),
        "oversize-file": good_by_profile["aarch64-k3.10"].replace(b"\t1\t", b"\t4194305\t", 1),
        "oversize-total": over_total,
        "oversize-manifest": b"#" * 4097,
    }
    cases: list[tuple[str, str, bytes, int, int]] = []
    for profile, data in good_by_profile.items():
        actual_profile = profile.removesuffix("-file-max").removesuffix("-total-max")
        total = sum(int(row.split(b"\t")[1]) for row in data.splitlines())
        cases.append((profile, actual_profile, data, 0, total))
    cases.extend((name, "aarch64-k3.10", data, 1, 0) for name, data in bad.items())
    cases.append(("bad-profile", "unsupported", good_by_profile["aarch64-k3.10"], 2, 0))
    for name, _, data, _, _ in cases:
        (manifest_dir / name).write_bytes(data)
    missing_path = manifest_dir / "missing-file"
    output_dir = router.path("work/parsed manifests")
    output_dir.mkdir(mode=0o700)
    wc = native_path("wc")
    script = (
        f". {shlex.quote(str(SOURCE))}\n"
        "while [ $# -gt 0 ]; do\n"
        "  label=$1; profile=$2; path=$3; expected=$4; total=$5; output=$6; shift 6\n"
        "  _closure_manifest_text=stale; _closure_manifest_total=777\n"
        '  _cfmgr_closure_manifest "$profile" "$path" "' + shlex.quote(wc) + '"; rc=$?\n'
        '  if [ "$rc" -eq 0 ]; then printf "%s" "$_closure_manifest_text" >"$output"; fi\n'
        '  if [ -n "$_closure_manifest_text" ]; then text_state=present; else '
        "text_state=clear; fi\n"
        '  printf "%s\\t%s\\t%s\\t%s\\t%s\\n" "$label" "$expected" "$rc" '
        '"${_closure_manifest_total:-0}" "$text_state"\n'
        "done\n"
    )
    args = [
        item
        for name, profile, _, expected, total in cases
        for item in (
            name,
            profile,
            str(manifest_dir / name),
            str(expected),
            str(total),
            str(output_dir / name),
        )
    ]
    args += [
        "missing-file",
        "aarch64-k3.10",
        str(missing_path),
        "1",
        "0",
        str(output_dir / "missing-file"),
    ]
    result = router.run(script, args, timeout=8)
    assert result.returncode == 0 and result.stderr == ""
    observations = [line.split("\t") for line in result.stdout.splitlines()]
    assert observations == [
        [name, str(expected), str(expected), str(total), "present" if expected == 0 else "clear"]
        for name, _, _, expected, total in cases
    ] + [["missing-file", "1", "1", "0", "clear"]]
    for name, _, data, expected, _ in cases:
        captured = output_dir / name
        assert captured.read_bytes() == data if expected == 0 else not captured.exists()
    assert not (output_dir / "missing-file").exists()


@pytest.mark.matrix("V74", evidence="host")
def test_source_symlink_is_rejected_without_following_it(closure: ClosureFixture) -> None:
    source = closure.base / "lib/libc-2.27.so"
    outside = closure.router.path("work/outside member")
    outside.write_bytes(closure.contents["lib/libc-2.27.so"])
    source.unlink()
    source.symlink_to(outside)
    result = closure.run()
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.strip().split("\t") == ["RESULT", "1", "0", "unset", "unset"]
    assert not (closure.guard / "closure/opt/lib/libc-2.27.so").exists()


@pytest.mark.matrix("V74", evidence="host")
def test_native_stage_runs_under_secondary_host_shell(
    router: RouterHarness, pytestconfig: pytest.Config
) -> None:
    shell = shutil.which("dash") or shutil.which("bash")
    if shell is None:
        pytest.skip("no secondary POSIX shell is available")
    closure = ClosureFixture(router, pytestconfig._cfmgr_busybox)
    result = closure.run(shell=os.path.realpath(shell))
    closure.assert_success(result)


@pytest.mark.parametrize("prior", ["directory", "dangling-link"])
@pytest.mark.matrix("V74", evidence="host")
def test_existing_stage_is_never_adopted_or_reused(closure: ClosureFixture, prior: str) -> None:
    destination = closure.guard / "closure"
    if prior == "directory":
        destination.mkdir(mode=0o700)
    else:
        destination.symlink_to(closure.guard / "missing target")
    result = closure.run()
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.strip().split("\t") == ["RESULT", "1", "0", "unset", "unset"]
    assert destination.is_symlink() if prior == "dangling-link" else destination.is_dir()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_native_stage_runs_under_busybox_shell(busybox_router: RouterHarness) -> None:
    closure = ClosureFixture(busybox_router)
    result = closure.run()
    closure.assert_success(result)
