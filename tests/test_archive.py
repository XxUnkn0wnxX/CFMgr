"""Fixed reviewed archive extraction consumes only inert synthetic bytes."""

from __future__ import annotations

import gzip
import hashlib
import io
import json
import os
import shlex
import shutil
import sys
import tarfile
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
CLOSURE = ROOT / "modules/closure.sh"
FETCH = ROOT / "modules/fetch.sh"
BOOTSTRAP = ROOT / "modules/bootstrap.sh"
ARCHIVE = ROOT / "modules/archive.sh"
CATALOG = ROOT / "docs/evidence/bootstrap-catalog.json"
PROFILES = ("aarch64-k3.10", "armv7sf-k3.2", "mipselsf-k3.4")
PACKAGES = ("coreutils-timeout", "gzip")
APPLET_TOOLS = ("dd", "gunzip", "tar", "wc", "hexdump", "mkdir", "env")
NATIVE_TOOLS = (*APPLET_TOOLS, "openssl")
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def native_program(name: str) -> str:
    path = shutil.which(name, path="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin")
    if path is None:
        pytest.fail(f"required host tool {name} is unavailable; it must be preinstalled")
    return os.path.realpath(path)


def tar_bytes(members: list[tuple[str, bytes | None]]) -> bytes:
    stream = io.BytesIO()
    with tarfile.open(fileobj=stream, mode="w", format=tarfile.USTAR_FORMAT) as archive:
        for name, content in members:
            item = tarfile.TarInfo(name)
            item.uid = item.gid = item.mtime = 0
            item.uname = item.gname = ""
            item.mode = 0o755 if content is None else 0o644
            if content is None:
                item.type = tarfile.DIRTYPE
                item.size = 0
                archive.addfile(item)
            else:
                item.size = len(content)
                archive.addfile(item, io.BytesIO(content))
    return stream.getvalue()


class ArchiveFixture:
    def __init__(
        self,
        router: RouterHarness,
        *,
        busybox: Path | None = None,
        name: str = "case",
    ):
        self.router = router
        self.busybox = busybox
        self.name = name
        self.directory = router.path(f"ram/tmp/extracted-{name}")
        self.source = router.path(f"work/synthetic-{name}.ipk")
        self.program = b"synthetic inert program\x00with opaque bytes\xff\n"
        self.other = b"an unselected archive member\n"
        self.data_tar = tar_bytes(
            [
                ("./", None),
                ("./opt/", None),
                ("./opt/libexec/", None),
                ("./opt/libexec/timeout-coreutils", self.program),
                ("./opt/libexec/unselected", self.other),
            ]
        )
        self.data_gz = gzip.compress(self.data_tar, mtime=0)
        control_tar = tar_bytes([("./control", b"Package: synthetic\n")])
        control_gz = gzip.compress(control_tar, mtime=0)
        self.outer_tar = tar_bytes(
            [
                ("./debian-binary", b"2.0\n"),
                ("./control.tar.gz", control_gz),
                ("./data.tar.gz", self.data_gz),
            ]
        )
        self.archive = gzip.compress(self.outer_tar, mtime=0)
        self.source.write_bytes(self.archive)
        self.source.chmod(0o600)
        self.tools = router.path(f"work/native tools-{name}")
        self.tools.mkdir(mode=0o700)
        for tool_name in NATIVE_TOOLS:
            target = (
                busybox
                if busybox is not None and tool_name in APPLET_TOOLS
                else Path(native_program(tool_name))
            )
            self.tools.joinpath(tool_name).symlink_to(target)
        self.calls = router.path(f"work/tool-calls-{self.name}")
        self.environment_log = router.path(f"work/tool-environment-{self.name}")

    def metadata(self) -> list[str]:
        return [
            str(self.tools),
            str(self.directory),
            str(self.source),
            str(len(self.archive)),
            sha256(self.archive),
            str(len(self.outer_tar)),
            sha256(self.outer_tar),
            str(len(self.data_gz)),
            sha256(self.data_gz),
            str(len(self.data_tar)),
            sha256(self.data_tar),
            "./opt/libexec/timeout-coreutils",
            str(len(self.program)),
            sha256(self.program),
        ]

    def instrument(self, *, fail_after: str | None = None, overflow_gunzip: bool = False) -> None:
        for name in NATIVE_TOOLS:
            target = (
                self.busybox
                if self.busybox is not None and name in APPLET_TOOLS
                else Path(native_program(name))
            )
            if self.busybox is not None and name in APPLET_TOOLS:
                command = f'exec {shlex.quote(str(target))} {name} "$@"\n'
            else:
                command = f'{shlex.quote(str(target))} "$@"\n'
            prefix = (
                f"#!/bin/sh\nprintf '%s\\n' {shlex.quote(name)} >> {shlex.quote(str(self.calls))}\n"
            )
            if name in {"tar", "gunzip"}:
                prefix += (
                    f"printf 'GZIP=%s\\tTAR_OPTIONS=%s\\tPATH=%s\\t"
                    f"LD_LIBRARY_PATH=%s\\tOPENSSL_CONF=%s\\n' "
                    f'"${{GZIP-unset}}" "${{TAR_OPTIONS-unset}}" "${{PATH-unset}}" '
                    f'"${{LD_LIBRARY_PATH-unset}}" "${{OPENSSL_CONF-unset}}" '
                    f">> {shlex.quote(str(self.environment_log))}\n"
                )
            if overflow_gunzip and name == "gunzip":
                code = (
                    "import signal,sys; signal.signal(signal.SIGXFSZ,signal.SIG_IGN); "
                    "out=sys.stdout.buffer\ntry: out.write(b'X'*200000); out.flush()\n"
                    "except OSError: pass"
                )
                command = f"{shlex.quote(sys.executable)} -c {shlex.quote(code)}\nexit 0\n"
            elif fail_after == name:
                command = (
                    f'{shlex.quote(str(target))} "$@"\n'
                    "_producer_status=$?\n"
                    '[ "$_producer_status" -eq 0 ] || exit "$_producer_status"\n'
                    "exit 1\n"
                )
                if self.busybox is not None and name in APPLET_TOOLS:
                    command = (
                        f'{shlex.quote(str(target))} {name} "$@"\n'
                        "_producer_status=$?\n"
                        '[ "$_producer_status" -eq 0 ] || exit "$_producer_status"\n'
                        "exit 1\n"
                    )
            wrapper = self.tools / name
            wrapper.unlink()
            wrapper.write_text(prefix + command, encoding="utf-8")
            wrapper.chmod(0o700)

    def run(
        self, args: list[str] | None = None, *, env: dict[str, str] | None = None
    ) -> ShellResult:
        subject = self.router.write(
            "work/invoke-archive.sh",
            f". {shlex.quote(str(CLOSURE))}\n"
            f". {shlex.quote(str(FETCH))}\n"
            f". {shlex.quote(str(BOOTSTRAP))}\n"
            f". {shlex.quote(str(ARCHIVE))}\n"
            'cfmgr_archive_test "$@"\n'
            "_archive_status=$?\n"
            'printf "RESULT\\t%s\\n" "$_archive_status"\n',
        )
        arguments = [str(subject), *(args or self.metadata())]
        if self.router.busybox is not None:
            invocation = f'exec {shlex.quote(str(self.router.busybox))} sh "$@"\n'
        else:
            invocation = 'exec /bin/sh "$@"\n'
        return self.router.run(invocation, arguments, env=env)

    def production_shell(self, body: str, *, env: dict[str, str] | None = None) -> ShellResult:
        script = (
            f". {shlex.quote(str(CLOSURE))}\n"
            f". {shlex.quote(str(FETCH))}\n"
            f". {shlex.quote(str(BOOTSTRAP))}\n"
            f". {shlex.quote(str(ARCHIVE))}\n" + body
        )
        return self.router.run(script, env=env)

    def producer_calls(self) -> list[str]:
        all_calls = self.calls.read_text().splitlines() if self.calls.exists() else []
        return [name for name in all_calls if name in {"dd", "gunzip", "tar"}]


def test_compiled_payload_identities_match_all_six_catalogue_records(router: RouterHarness) -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    rows = []
    for profile in PROFILES:
        for package in PACKAGES:
            extraction = catalog["profiles"][profile]["packages"][package]["extraction"]
            rows.append(
                (
                    profile,
                    package,
                    str(extraction["outer_tar_size"]),
                    extraction["outer_tar_sha256"],
                    str(extraction["data_gz_size"]),
                    extraction["data_gz_sha256"],
                    str(extraction["data_tar_size"]),
                    extraction["data_tar_sha256"],
                    extraction["selected_member"],
                    str(extraction["selected_size"]),
                    extraction["selected_sha256"],
                )
            )
    script = (
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        + "\n".join(
            f"_cfmgr_bootstrap_payload {shlex.quote(profile)} {shlex.quote(package)} || exit 8\n"
            'printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" '
            f"{shlex.quote(profile)} {shlex.quote(package)} "
            '"$_bootstrap_outer_size" "$_bootstrap_outer_sha256" '
            '"$_bootstrap_data_gz_size" "$_bootstrap_data_gz_sha256" '
            '"$_bootstrap_data_tar_size" "$_bootstrap_data_tar_sha256" '
            '"$_bootstrap_member" "$_bootstrap_member_size" "$_bootstrap_member_sha256"'
            for profile, package, *_ in rows
        )
        + "\n"
    )
    result = router.run(script)

    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.splitlines() == ["\t".join(row) for row in rows]


def test_production_extract_uses_compiled_identity_empty_tools_and_rejects_bad_route(
    router: RouterHarness,
) -> None:
    fixture = ArchiveFixture(router)
    captured = router.path("work/production-extract-args")
    body = (
        "_cfmgr_archive_run() {\n"
        '  [ "$#" -eq 14 ] && [ -z "$1" ] || return 9\n'
        f'  printf "%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" '
        '"$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}" "${12}" "${13}" "${14}" '
        f"> {shlex.quote(str(captured))}\n"
        "  return 0\n"
        "}\n"
        f"SOURCE={shlex.quote(str(fixture.source))}\n"
        f"DIRECTORY={shlex.quote(str(fixture.directory))}\n"
        'cfmgr_bootstrap_extract armv7sf-k3.2 gzip "$SOURCE" "$DIRECTORY"\n'
        "_good=$?\n"
        'cfmgr_bootstrap_extract unknown gzip "$SOURCE" "$DIRECTORY"; _profile=$?\n'
        'cfmgr_bootstrap_extract armv7sf-k3.2 unknown "$SOURCE" "$DIRECTORY"; _package=$?\n'
        'cfmgr_bootstrap_extract armv7sf-k3.2 gzip "$SOURCE"; _count=$?\n'
        'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\n" "$_good" "$_profile" "$_package" "$_count"\n'
    )
    result = fixture.production_shell(
        body,
        env={
            "_fetch_tools": "/ambient/tools",
            "_bootstrap_url": "https://ambient.invalid/archive.ipk",
            "_bootstrap_size": "1",
            "_bootstrap_sha256": "0" * 64,
            "_bootstrap_outer_sha256": "0" * 64,
            "GZIP": "--verbose",
            "TAR_OPTIONS": "--absolute-names",
        },
    )

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\t2\t2\t2\n" and result.stderr == ""
    expected = json.loads(CATALOG.read_text(encoding="utf-8"))["profiles"]["armv7sf-k3.2"]
    package = expected["packages"]["gzip"]
    extraction = package["extraction"]
    values = [
        str(fixture.directory),
        str(fixture.source),
        str(package["size"]),
        package["sha256"],
        str(extraction["outer_tar_size"]),
        extraction["outer_tar_sha256"],
        str(extraction["data_gz_size"]),
        extraction["data_gz_sha256"],
        str(extraction["data_tar_size"]),
        extraction["data_tar_sha256"],
        extraction["selected_member"],
        str(extraction["selected_size"]),
        extraction["selected_sha256"],
    ]
    assert captured.read_text().splitlines() == ["\t" + "\t".join(values)]


def test_native_pipeline_extracts_only_selected_synthetic_member_and_preserves_state(
    router: RouterHarness,
) -> None:
    fixture = ArchiveFixture(router)
    fixture.instrument()
    marker = router.path("work/archive-exit-trap")
    script = (
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(FETCH))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        f". {shlex.quote(str(ARCHIVE))}\n"
        "IFS='~,:'\nset +f\numask 027\n"
        f"trap 'printf x >> {shlex.quote(str(marker))}' 0\n"
        'cfmgr_archive_test "$@"\n'
        "_status=$?\n"
        '_state_ifs=$([ "$IFS" = "~,:" ] && printf yes || printf no)\n'
        '_state_glob=$([ "${-#*f}" = "$-" ] && printf yes || printf no)\n'
        "_state_umask=$(umask)\n"
        'printf "RESULT\\t%s\\t%s:%s:%s\\n" "$_status" "$_state_ifs" '
        '"$_state_glob" "$_state_umask"\n'
    )
    result = router.run(
        'exec /bin/sh "$@"\n',
        [str(router.write("work/archive-state.sh", script)), *fixture.metadata()],
        env={
            "GZIP": "--verbose",
            "TAR_OPTIONS": "--absolute-names",
            "LD_LIBRARY_PATH": "/ambient/injected-libraries",
            "OPENSSL_CONF": "/ambient/openssl.cnf",
        },
    )

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\tyes:yes:0027\n" and result.stderr == ""
    assert marker.read_text() == "x"
    assert fixture.source.read_bytes() == fixture.archive
    assert (fixture.directory / "program").read_bytes() == fixture.program
    assert (fixture.directory / "data.tar").read_bytes() == fixture.data_tar
    assert (fixture.directory / "data.tar.gz").read_bytes() == fixture.data_gz
    assert (fixture.directory / "outer.tar").read_bytes() == fixture.outer_tar
    assert (fixture.directory / "archive.ipk").read_bytes() == fixture.archive
    for name in ("archive.ipk", "outer.tar", "data.tar.gz", "data.tar", "program"):
        assert (fixture.directory / name).stat().st_mode & 0o777 == 0o600
    assert fixture.directory.stat().st_mode & 0o777 == 0o700
    assert not (fixture.directory / "opt").exists()
    assert fixture.producer_calls() == ["dd", "gunzip", "tar", "gunzip", "tar"]
    environment = fixture.environment_log.read_text().splitlines()
    assert len(environment) == 4
    assert all(
        "GZIP=unset\tTAR_OPTIONS=unset\tPATH=/sbin:/bin:/usr/sbin:/usr/bin"
        "\tLD_LIBRARY_PATH=unset\tOPENSSL_CONF=/dev/null" in line
        for line in environment
    )


def test_preparser_identity_and_oversize_input_stop_after_bounded_copy(
    router: RouterHarness,
) -> None:
    for label, oversize, alter_hash in (
        ("wrong-archive-hash", False, True),
        ("oversize-source", True, False),
    ):
        fixture = ArchiveFixture(router, name=label)
        fixture.instrument()
        source_before = fixture.source.read_bytes()
        if oversize:
            fixture.source.write_bytes(fixture.archive + b"X" * 140000)
        args = fixture.metadata()
        if alter_hash:
            args[4] = "0" * 64
        result = fixture.run(args)

        assert result.returncode == 0, f"{label}: {result}"
        assert result.stdout == "RESULT\t1\n" and result.stderr == ""
        copied = fixture.directory / "archive.ipk"
        assert copied.is_file()
        assert copied.stat().st_size <= 131072
        assert fixture.source.read_bytes() == (
            fixture.archive + b"X" * 140000 if oversize else source_before
        )
        assert fixture.producer_calls() == ["dd"]
        assert not (fixture.directory / "outer.tar").exists()


def test_intermediate_hash_failure_stops_before_tar(router: RouterHarness) -> None:
    fixture = ArchiveFixture(router)
    fixture.instrument()
    changed_outer = bytearray(fixture.outer_tar)
    changed_outer[512] = ord("3")
    changed_outer_bytes = bytes(changed_outer)
    fixture.archive = gzip.compress(changed_outer_bytes, mtime=0)
    fixture.source.write_bytes(fixture.archive)
    args = fixture.metadata()
    result = fixture.run(args)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\n" and result.stderr == ""
    assert (fixture.directory / "archive.ipk").read_bytes() == fixture.archive
    assert (fixture.directory / "outer.tar").read_bytes() == changed_outer_bytes
    assert fixture.producer_calls() == ["dd", "gunzip"]
    assert not (fixture.directory / "data.tar.gz").exists()


def test_successful_tar_output_with_nonzero_status_stops_next_stage(router: RouterHarness) -> None:
    fixture = ArchiveFixture(router)
    fixture.instrument(fail_after="tar")
    result = fixture.run()

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\n" and result.stderr == ""
    assert (fixture.directory / "data.tar.gz").read_bytes() == fixture.data_gz
    assert fixture.producer_calls() == ["dd", "gunzip", "tar"]
    assert not (fixture.directory / "data.tar").exists()


def test_bounded_decompressor_output_is_rejected_even_if_producer_returns_zero(
    router: RouterHarness,
) -> None:
    fixture = ArchiveFixture(router)
    fixture.instrument(overflow_gunzip=True)
    result = fixture.run()

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\n" and result.stderr == ""
    outer = fixture.directory / "outer.tar"
    assert outer.is_file()
    maximum = 2 * ((len(fixture.outer_tar) + 512) // 512) * 512
    assert len(fixture.outer_tar) < outer.stat().st_size <= maximum
    assert fixture.producer_calls() == ["dd", "gunzip"]


def test_final_member_hash_mismatch_retains_private_bytes(router: RouterHarness) -> None:
    fixture = ArchiveFixture(router)
    fixture.instrument()
    args = fixture.metadata()
    args[13] = "0" * 64
    result = fixture.run(args)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\n" and result.stderr == ""
    assert (fixture.directory / "program").read_bytes() == fixture.program
    assert (fixture.directory / "program").stat().st_mode & 0o777 == 0o600
    assert fixture.producer_calls() == ["dd", "gunzip", "tar", "gunzip", "tar"]


def test_invalid_metadata_and_existing_output_nodes_stop_before_tools(
    router: RouterHarness,
) -> None:
    fixture = ArchiveFixture(router)
    fixture.instrument()
    baseline = fixture.metadata()
    source_link = router.path("work/source-link")
    source_link.symlink_to(fixture.source)
    bad_cases: list[tuple[str, list[str], int]] = []
    for name, index, value in (
        ("leading-zero-size", 3, "0" + baseline[3]),
        ("bad-digest", 4, "A" * 64),
        ("unsafe-member", 11, "./opt/libexec/../gzip-gnu"),
        ("bad-member-size", 12, "0001"),
        ("oversize-data-tar", 9, "131073"),
        ("bad-member-digest", 13, "g" * 64),
        ("symlink-source", 2, str(source_link)),
        ("bad-tools", 0, str(router.path("work/missing-tools"))),
        ("bad-directory", 1, "relative/output"),
        ("bad-source", 2, str(router.path("work/missing-source"))),
    ):
        args = baseline.copy()
        args[1] = str(router.path(f"ram/tmp/invalid-{name}"))
        args[index] = value
        expected = 1 if name in {"bad-source", "symlink-source"} else 2
        bad_cases.append((name, args, expected))
    cases = [("bad-count", baseline[:-1], 2), *bad_cases]
    for name, args, expected in cases:
        result = fixture.run(args)
        assert result.returncode == 0, f"{name}: {result}"
        assert result.stdout == f"RESULT\t{expected}\n" and result.stderr == "", name
        assert not Path(args[1]).exists()
    for label, create in (
        ("directory", lambda path: path.mkdir()),
        ("regular", lambda path: path.write_bytes(b"keep")),
        ("dangling-symlink", lambda path: path.symlink_to("missing-target")),
        ("fifo", os.mkfifo),
    ):
        target = router.path(f"ram/tmp/existing-{label}")
        create(target)
        args = baseline.copy()
        args[1] = str(target)
        result = fixture.run(args)
        assert result.returncode == 0, f"{label}: {result}"
        assert result.stdout == "RESULT\t1\n" and result.stderr == ""
        assert target.exists() or target.is_symlink()
        if label == "regular":
            assert target.read_bytes() == b"keep"
    assert not fixture.calls.exists() or fixture.calls.read_text() == ""


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_busybox_shell_and_applets_extract_only_selected_synthetic_member(
    busybox_router: RouterHarness,
) -> None:
    fixture = ArchiveFixture(busybox_router, busybox=busybox_router.busybox)
    result = fixture.run()

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\n" and result.stderr == ""
    assert (fixture.directory / "program").read_bytes() == fixture.program
    assert not (fixture.directory / "opt").exists()
