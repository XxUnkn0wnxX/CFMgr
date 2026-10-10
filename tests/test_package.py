"""Owned package-manifest reader framing and publication evidence."""

from __future__ import annotations

import hashlib
import shlex
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

LIB = Path(__file__).resolve().parents[1] / "modules/lib"
IO = LIB / "io.sh"
PACKAGE = LIB / "package.sh"
NATIVE_DIGEST = LIB / "native_digest.sh"
PATH_HELPER = LIB / "package_path.awk"
PARSER = LIB / "manifest.awk"
TOOL_NAMES = ("awk", "cat", "mkdir", "printf", "rm", "wc")
NATIVE_TOOL_NAMES = ("openssl", "env")
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def manifest(
    files: tuple[tuple[str, bytes, int], ...] | None = None,
    *,
    version: str = "12.34.56",
) -> bytes:
    """Build public input independently from the reader's canonical ledger."""
    if files is None:
        files = (("cfmgr.sh", b"entry", 0o755), ("modules/z.sh", b"z", 0o644))
    rows = [
        f"{path}: {len(data)} {hashlib.sha256(data).hexdigest().upper()} {mode:04o}\n"
        for path, data, mode in files
    ]
    return (
        f"manifest: 1\nversion: {version}\nconfig-schema: 1\npackage-api: 1\n" + "".join(rows)
    ).encode("ascii")


def expected_ledger(data: bytes) -> bytes:
    """Independent byte oracle for parser record order, hash case and footer."""
    lines = data.decode("ascii").splitlines()
    metadata = {line.split(": ", 1)[0]: line.split(": ", 1)[1] for line in lines[:4]}
    records = []
    total = 0
    for line in lines[4:]:
        destination, details = line.split(": ", 1)
        size, digest, mode = details.split(" ")
        records.append(f"file\t{destination}\t{size}\t{digest.lower()}\t{mode}\n")
        total += int(size)
    body = (
        f"manifest\t{metadata['manifest']}\n"
        f"version\t{metadata['version']}\n"
        f"config-schema\t{metadata['config-schema']}\n"
        f"package-api\t{metadata['package-api']}\n" + "".join(records)
    ).encode("ascii")
    return body + f"end\t{len(records)}\t{total}\t{len(body)}\n".encode("ascii")


def ledger_with_files(rows: tuple[tuple[str, str, str, str], ...]) -> bytes:
    body = b"manifest\t1\nversion\t12.34.56\nconfig-schema\t1\npackage-api\t1\n"
    body += b"".join(
        f"file\t{destination}\t{size}\t{digest}\t{mode}\n".encode("ascii")
        for destination, size, digest, mode in rows
    )
    total = sum(int(row[1]) for row in rows)
    return body + f"end\t{len(rows)}\t{total}\t{len(body)}\n".encode("ascii")


def expected_bytes_report(data: bytes) -> bytes:
    """Independent report oracle: change only the header and body-byte footer."""
    ledger = expected_ledger(data)
    old_body, footer = ledger.rsplit(b"end\t", 1)
    count, total, _body_bytes = footer[:-1].decode("ascii").split("\t")
    new_body = b"package-bytes\t1\n" + old_body[len(b"manifest\t1\n") :]
    return new_body + f"end\t{count}\t{total}\t{len(new_body)}\n".encode("ascii")


class PackageFixture:
    def __init__(self, router: RouterHarness, *, busybox: Path | None = None):
        self.router = router
        if router.busybox is None:
            for name in TOOL_NAMES:
                executable = shutil.which(name)
                assert executable is not None
                self.tool_path(name).symlink_to(Path(executable).resolve())
        else:
            router.busybox_applets(*TOOL_NAMES)
        for name in NATIVE_TOOL_NAMES:
            executable = shutil.which(name)
            assert executable is not None
            self.tool_path(name).symlink_to(Path(executable).resolve())
        hexdump = shutil.which("hexdump")
        if hexdump is not None:
            self.tool_path("hexdump").symlink_to(Path(hexdump).resolve())
        elif busybox is not None:
            self.tool_path("hexdump").symlink_to(busybox)
        else:
            pytest.fail("native hexdump is unavailable; it must be preinstalled")
        self.input = router.path("work/manifest.txt")
        self.source_root = router.path("work/source-root")
        self.source_root.mkdir()
        self.payloads = {"cfmgr.sh": b"entry", "modules/z.sh": b"z"}
        self.configure(self.payloads)
        self.input.chmod(0o600)
        self.helper = router.write("work/package_path.awk", PATH_HELPER.read_text())
        self.parser = router.write("work/manifest.awk", PARSER.read_text())

    @property
    def root(self) -> Path:
        return self.router.path("ram/tmp")

    @property
    def tools(self) -> Path:
        return self.router.path("bin")

    def tool_path(self, name: str) -> Path:
        # This direct path is used only for replacing a known fixture symlink.
        return self.router.root / "bin" / name

    def replace_tool(self, name: str, body: str) -> Path:
        path = self.tool_path(name)
        if path.is_symlink() or path.exists():
            path.unlink()
        return self.router.write(f"bin/{name}", "#!/bin/sh\n" + body, executable=True)

    def source(self) -> str:
        return f'. "{IO}"\n. "{PACKAGE}"\n'

    def verifier_source(self) -> str:
        return f'. "{IO}"\n. "{NATIVE_DIGEST}"\n. "{PACKAGE}"\n'

    def configure(self, payloads: dict[str, bytes]) -> None:
        self.payloads = payloads.copy()
        for relative, data in self.payloads.items():
            path = self.source_root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            path.chmod(0o600)
        rows = tuple(
            (path, data, 0o755 if path == "cfmgr.sh" else 0o644)
            for path, data in self.payloads.items()
        )
        self.input.write_bytes(manifest(rows))

    def verify(
        self, *, production: bool = False, args: tuple[str, ...] | None = None
    ) -> ShellResult:
        function = "cfmgr_package_verify_report" if production else "cfmgr_package_verify_test"
        supplied = (
            tuple(
                map(
                    str,
                    (self.root, self.tools, self.source_root, self.input, self.helper, self.parser),
                )
            )
            if args is None
            else args
        )
        if production:
            supplied = (
                tuple(map(str, (self.root, self.source_root, self.input, self.helper, self.parser)))
                if args is None
                else args
            )
        return self.router.run(self.verifier_source() + f'{function} "$@"\n', supplied)

    def public(
        self, *, production: bool = False, args: tuple[str, ...] | None = None
    ) -> ShellResult:
        function = "cfmgr_package_manifest_report" if production else "cfmgr_package_manifest_test"
        supplied = (
            tuple(map(str, (self.root, self.tools, self.input, self.helper, self.parser)))
            if args is None
            else args
        )
        if production:
            supplied = (
                tuple(map(str, (self.root, self.input, self.helper, self.parser)))
                if args is None
                else args
            )
        return self.router.run(
            self.source() + f'{function} "$@"\n',
            supplied,
        )

    def decode(self, paths: tuple[tuple[Path, int], ...]) -> ShellResult:
        callback = (
            "fixture_decode_group() {\n"
            "  shift\n"
            "  _decode_results=\n"
            "  _decode_body=\n"
            '  while [ "$#" -gt 1 ]; do\n'
            '    if _cfmgr_package_manifest_decode "$1" "$2"; then\n'
            "      _decode_status=0; _decode_body=$_package_manifest_body\n"
            "    else _decode_status=$?; fi\n"
            '    _decode_results="$_decode_results$_decode_status\n"\n'
            "    shift 2\n"
            "  done\n"
            '  cfmgr_io_stage_report "$_decode_results body\n$_decode_body"\n'
            "}\n"
        )
        args: list[str] = [str(self.root), str(self.tools)]
        for path, size in paths:
            args.extend((str(path), str(size)))
        return self.router.run(
            self.source()
            + callback
            + "decode_root=$1; decode_tools=$2; shift 2\n"
            + 'cfmgr_io_test "$decode_root" "$decode_tools" report fixture_decode_group "$@"\n',
            args,
        )


@pytest.fixture
def package(router: RouterHarness, pytestconfig: pytest.Config) -> PackageFixture:
    return PackageFixture(router, busybox=pytestconfig._cfmgr_busybox)


def quiet(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status
    assert result.stdout == result.stderr == ""


def test_native_reader_publishes_real_parser_ledger_exactly(package: PackageFixture) -> None:
    source = manifest()
    package.input.write_bytes(source)
    result = package.public()
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_ledger(source)
    assert list(package.root.glob("cfmgr-io.*")) == []


def test_reader_refuses_bad_api_paths_and_input_caps(package: PackageFixture) -> None:
    quiet(package.public(args=()), 2)
    quiet(package.public(args=(str(package.root), str(package.tools), str(package.input))), 2)

    for bad in (
        package.router.path("work/missing-manifest"),
        package.router.path("work/manifest-link"),
        package.router.path("work/manifest-dir"),
    ):
        if bad.name == "manifest-link":
            bad.symlink_to(package.input)
        elif bad.name == "manifest-dir":
            bad.mkdir()
        quiet(
            package.public(
                args=tuple(
                    map(str, (package.root, package.tools, bad, package.helper, package.parser))
                )
            )
        )

    oversized = package.router.path("work/oversized")
    oversized.write_bytes(b"x" * 65537)
    oversized.chmod(0o600)
    quiet(
        package.public(
            args=tuple(
                map(str, (package.root, package.tools, oversized, package.helper, package.parser))
            )
        )
    )

    bad_helper = package.router.path("work/helper-link")
    bad_helper.symlink_to(package.helper)
    quiet(
        package.public(
            args=tuple(
                map(str, (package.root, package.tools, package.input, bad_helper, package.parser))
            )
        ),
        2,
    )


def test_parser_and_decoder_reject_original_nul_and_framing_discrepancies(
    package: PackageFixture,
) -> None:
    source = manifest()
    package.input.write_bytes(source[:20] + b"\0" + source[20:])
    quiet(package.public())

    valid = expected_ledger(source)
    body = valid[: valid.rfind(b"end\t")]
    broken = (
        valid,
        valid[:-1],
        valid + b"extra\n",
        valid.replace(b"file\tcfmgr.sh", b"file\t\tcfmgr.sh", 1),
        valid.replace(b"end\t2\t6\t", b"end\t3\t6\t", 1),
        valid.replace(b"end\t2\t6\t", b"end\t2\t5\t", 1),
        ledger_with_files((("modules/zero.x", "0", "d" * 64, "0644"),)),
        ledger_with_files((("modules/leading-zero.x", "01", "e" * 64, "0644"),)),
        ledger_with_files((("modules/oversized.x", "1048577", "f" * 64, "0644"),)),
        valid.replace(hashlib.sha256(b"entry").hexdigest().encode("ascii"), b"g" * 64, 1),
        valid.replace(b"\t0755\n", b"\t0700\n", 1),
        body.replace(b"version\t12.34.56", b"version\t12\0.34.56") + valid[valid.rfind(b"end\t") :],
        ledger_with_files(
            tuple((f"modules/f{index:03}.x", "1", "a" * 64, "0644") for index in range(129))
        ),
        ledger_with_files(
            tuple((f"modules/g{index:03}.x", "1048576", "b" * 64, "0644") for index in range(8))
            + (("modules/overflow.x", "1", "c" * 64, "0644"),)
        ),
    )
    paths: list[tuple[Path, int]] = []
    for index, data in enumerate(broken):
        path = package.router.path(f"work/ledger-{index}")
        path.write_bytes(data)
        path.chmod(0o600)
        # Retain every original byte count, exposing NUL removal when shell
        # reads turn the byte stream into strings.
        paths.append((path, len(data)))
    result = package.decode(tuple(paths))
    assert result.returncode == 0 and result.stderr == ""
    expected_body = body.decode("ascii").split("end\t", 1)[0]
    assert result.stdout == ("0\n" + "1\n" * (len(broken) - 1) + " body\n" + expected_body)


def test_capture_producer_status_and_stderr_are_independent_failures(
    package: PackageFixture,
) -> None:
    package.replace_tool("cat", "/bin/cat >/dev/null\nexit 7\n")
    quiet(package.public())

    # Restore a real cat before isolating AWK's quiet parser status and diagnostics.
    package.tool_path("cat").unlink()
    package.tool_path("cat").symlink_to(Path(shutil.which("cat")).resolve())
    package.replace_tool("awk", "/bin/cat >/dev/null\nexit 2\n")
    quiet(package.public(), 2)
    package.replace_tool("awk", "/bin/cat >/dev/null\nprintf diagnostic >&2\nexit 2\n")
    quiet(package.public())
    package.replace_tool("cat", "printf x\nprintf diagnostic >&2\nexit 0\n")
    quiet(package.public())


def test_cleanup_and_final_publication_failures_suppress_success(package: PackageFixture) -> None:
    package.replace_tool("rm", "exit 1\n")
    quiet(package.public())

    package.tool_path("rm").unlink()
    package.tool_path("rm").symlink_to(Path(shutil.which("rm")).resolve())
    package.replace_tool(
        "printf",
        'case "$1" in %s) exit 1 ;; *) exec /usr/bin/printf "$@" ;; esac\n',
    )
    result = package.public()
    assert result.returncode == 1 and result.stdout == result.stderr == ""


def test_owner_signal_status_wins_during_native_capture(package: PackageFixture) -> None:
    package.replace_tool(
        "awk",
        'owner=$(/bin/ps -o ppid= -p "$PPID")\n'
        'set -- $owner\n/bin/kill -TERM "$1"\n/bin/sleep 1\nexit 0\n',
    )
    args = tuple(
        map(str, (package.root, package.tools, package.input, package.helper, package.parser))
    )
    script = package.source() + 'cfmgr_package_manifest_test "$@"\n'
    result = package.router.run(script, args, timeout=3)
    assert result.returncode == 143 and result.stdout == result.stderr == ""
    assert not list(package.root.glob("cfmgr-io.*"))


def test_source_only_loading_preserves_shell_state(router: RouterHarness) -> None:
    result = router.run(
        'IFS=x; set -f; umask 027; trap ":" TERM\n'
        "before_trap=$(trap); before_options=$(set +o); before_umask=$(umask); before_pwd=$PWD\n"
        f'. "{IO}"\n. "{NATIVE_DIGEST}"\n. "{PACKAGE}"\n'
        '[ "$IFS" = x ] && [ "$(trap)" = "$before_trap" ] && '
        '[ "$(set +o)" = "$before_options" ] && [ "$(umask)" = "$before_umask" ] && '
        '[ "$PWD" = "$before_pwd" ]\n'
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert list(router.path("ram/tmp").iterdir()) == []


def test_reader_preserves_status_quietness_and_caller_state(package: PackageFixture) -> None:
    script = (
        package.source()
        + 'IFS=x; set -f; umask 027; trap ":" TERM\n'
        + "before_trap=$(trap); before_options=$(set +o); before_umask=$(umask)\n"
        + 'cfmgr_package_manifest_test "$@"\nstatus=$?\n'
        + '[ "$IFS" = x ] && [ "$(trap)" = "$before_trap" ] && '
        + '[ "$(set +o)" = "$before_options" ] && [ "$(umask)" = "$before_umask" ] || exit 71\n'
        + 'exit "$status"\n'
    )
    args = tuple(
        map(str, (package.root, package.tools, package.input, package.helper, package.parser))
    )
    result = package.router.run(script, args)
    assert result.returncode == 0 and result.stdout.encode("ascii") == expected_ledger(
        package.input.read_bytes()
    )
    assert result.stderr == ""


def test_verifier_hashes_binary_members_and_publishes_recomputed_report(
    package: PackageFixture,
) -> None:
    payloads = {
        "cfmgr.sh": b"entry",
        "modules/binary.bin": bytes(range(256)) * 320,
        "modules/maximum.bin": bytes(range(256)) * 4096,
    }
    assert len(payloads["modules/binary.bin"]) > 65536
    assert len(payloads["modules/maximum.bin"]) == 1048576
    package.configure(payloads)
    result = package.verify()
    expected = expected_bytes_report(package.input.read_bytes())
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected
    assert list(package.root.glob("cfmgr-io.*")) == []


def test_production_verifier_report_uses_the_fixed_native_resolver(
    package: PackageFixture,
) -> None:
    result = package.verify(production=True)
    native_hexdump = any(
        (Path(directory) / "hexdump").is_file()
        and (Path(directory) / "hexdump").stat().st_mode & 0o111
        for directory in ("/sbin", "/bin", "/usr/sbin", "/usr/bin")
    )
    if native_hexdump:
        assert result.returncode == 0 and result.stderr == ""
        assert result.stdout.encode("ascii") == expected_bytes_report(package.input.read_bytes())
    else:
        quiet(result)


def test_verifier_rejects_actual_size_before_invoking_openssl(package: PackageFixture) -> None:
    package.configure({"cfmgr.sh": b"entry", "modules/size.bin": b"abc"})
    package.source_root.joinpath("cfmgr.sh").write_bytes(b"entries")
    marker = package.router.path("work/openssl-called")
    package.replace_tool("openssl", f"printf called > {shlex.quote(str(marker))}\nexit 9\n")
    quiet(package.verify())
    assert not marker.exists()


def test_later_same_size_hash_mismatch_prevents_report_publication(package: PackageFixture) -> None:
    package.configure({"cfmgr.sh": b"entry", "modules/a.bin": b"first", "modules/z.bin": b"later"})
    package.source_root.joinpath("modules/z.bin").write_bytes(b"other")
    quiet(package.verify())


def test_native_digest_rejects_failed_short_and_bad_hex_tools(package: PackageFixture) -> None:
    package.replace_tool("openssl", "exit 7\n")
    quiet(package.verify())

    package.replace_tool("openssl", "printf x\nexit 0\n")
    quiet(package.verify())

    package.tool_path("openssl").unlink()
    package.tool_path("openssl").symlink_to(Path(shutil.which("openssl")).resolve())
    package.replace_tool("hexdump", "printf bad\nexit 0\n")
    quiet(package.verify())
    bad_hex = "g" * 64
    package.replace_tool("hexdump", f"printf '%s' {shlex.quote(bad_hex)}\nexit 0\n")
    quiet(package.verify())


def verifier_refusal_group(
    package: PackageFixture,
    cases: tuple[tuple[int, str], ...],
) -> ShellResult:
    output_path = package.router.path("work/verify-output")
    calls = []
    for expected_status, source_root in cases:
        args = (
            package.root,
            package.tools,
            source_root,
            package.input,
            package.helper,
            package.parser,
        )
        calls.append(
            "check "
            + str(expected_status)
            + " "
            + " ".join(shlex.quote(str(argument)) for argument in args)
            + " || exit 91"
        )
    script = (
        package.verifier_source()
        + f"output={shlex.quote(str(output_path))}\n"
        + "check() {\n"
        + "  expected=$1; shift\n"
        + '  cfmgr_package_verify_test "$@" > "$output" 2>&1\n'
        + "  actual=$?\n"
        + '  [ "$actual" = "$expected" ] && [ ! -s "$output" ] || return 1\n'
        + "  printf '%s\\n' \"$actual\"\n"
        + "}\n"
        + "\n".join(calls)
        + "\n"
    )
    return package.router.run(script)


def test_verifier_rejects_bad_roots_and_declared_member_shapes_as_a_group(
    package: PackageFixture,
) -> None:
    file_root = package.router.path("work/source-file")
    file_root.write_text("not a directory", encoding="ascii")
    symlink_root = package.router.path("work/source-link")
    symlink_root.symlink_to(package.source_root)

    missing_root = package.router.path("work/missing-member-root")
    missing_root.mkdir()
    (missing_root / "cfmgr.sh").write_bytes(b"entry")
    (missing_root / "modules").mkdir()

    directory_root = package.router.path("work/nonregular-member-root")
    directory_root.mkdir()
    (directory_root / "cfmgr.sh").write_bytes(b"entry")
    (directory_root / "modules").mkdir()
    (directory_root / "modules/z.sh").mkdir()

    intermediate_root = package.router.path("work/intermediate-link-root")
    intermediate_root.mkdir()
    (intermediate_root / "cfmgr.sh").write_bytes(b"entry")
    target_modules = intermediate_root / "target-modules"
    target_modules.mkdir()
    (target_modules / "z.sh").write_bytes(b"z")
    (intermediate_root / "modules").symlink_to(target_modules)

    terminal_root = package.router.path("work/terminal-link-root")
    terminal_root.mkdir()
    (terminal_root / "cfmgr.sh").write_bytes(b"entry")
    (terminal_root / "modules").mkdir()
    target_file = terminal_root / "target-z"
    target_file.write_bytes(b"z")
    (terminal_root / "modules/z.sh").symlink_to(target_file)

    cases = (
        (2, "/"),
        (2, str(package.source_root) + "/"),
        (2, str(package.source_root) + "/."),
        (2, str(file_root)),
        (2, str(symlink_root)),
        (1, str(missing_root)),
        (1, str(directory_root)),
        (1, str(intermediate_root)),
        (1, str(terminal_root)),
    )
    result = verifier_refusal_group(package, cases)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "2\n2\n2\n2\n2\n1\n1\n1\n1\n"


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_composes_package_reader_and_io_owner(busybox_router: RouterHarness) -> None:
    package = PackageFixture(busybox_router, busybox=busybox_router.busybox)
    result = package.public()
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.encode("ascii") == expected_ledger(package.input.read_bytes())
    verifier = package.verify()
    assert verifier.returncode == 0 and verifier.stderr == ""
    assert verifier.stdout.encode("ascii") == expected_bytes_report(package.input.read_bytes())
