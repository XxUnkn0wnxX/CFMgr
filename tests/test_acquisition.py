"""Materialize two inert synthetic bootstrap tools through the real consumers."""

from __future__ import annotations

import gzip
import hashlib
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_archive import (
    APPLET_TOOLS,
    BOOTSTRAP,
    FETCH,
    native_program,
    tar_bytes,
)

ROOT = Path(__file__).resolve().parents[1]
CLOSURE = ROOT / "modules/closure.sh"
NATIVE_TOOLS = ("mkdir", "curl", "wc", "openssl", "hexdump", "env", "dd", "gunzip", "tar")
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def materialize_call(*args: object) -> str:
    quoted = " ".join(shlex.quote(str(value)) for value in args)
    return f"cfmgr_bootstrap_materialize_test {quoted}\n"


def synthetic_package(member: str, content: bytes) -> dict[str, bytes | str]:
    data_tar = tar_bytes(
        [
            ("./", None),
            ("./opt/", None),
            ("./opt/libexec/", None),
            (member, content),
            ("./opt/libexec/extra", b"excluded inert member\n"),
        ]
    )
    data_gz = gzip.compress(data_tar, mtime=0)
    outer_tar = tar_bytes(
        [
            ("./debian-binary", b"2.0\n"),
            (
                "./control.tar.gz",
                gzip.compress(tar_bytes([("./control", b"Package: fixture\n")]), mtime=0),
            ),
            ("./data.tar.gz", data_gz),
        ]
    )
    archive = gzip.compress(outer_tar, mtime=0)
    return {
        "archive": archive,
        "outer": outer_tar,
        "data_gz": data_gz,
        "data_tar": data_tar,
        "program": content,
        "url": f"https://fixture.invalid/{Path(member).name}.ipk",
        "member": member,
    }


class AcquisitionFixture:
    def __init__(self, router: RouterHarness, *, busybox: Path | None = None):
        self.router = router
        self.busybox = busybox
        self.tools = router.path("work/acquisition tools")
        self.tools.mkdir(mode=0o700)
        for name in NATIVE_TOOLS:
            if name == "curl":
                continue
            target = (
                busybox
                if busybox is not None and name in APPLET_TOOLS
                else Path(native_program(name))
            )
            self.tools.joinpath(name).symlink_to(target)

        self.directory = router.path("ram/tmp/materialized")
        self.packages = {
            "coreutils-timeout": synthetic_package(
                "./opt/libexec/timeout-coreutils", b"synthetic timeout bytes\x00\xff\n"
            ),
            "gzip": synthetic_package("./opt/libexec/gzip-gnu", b"synthetic gzip bytes\x00\xfe\n"),
        }
        self.inputs = {}
        for key, package in self.packages.items():
            path = router.path(f"work/{key}.ipk")
            path.write_bytes(package["archive"])
            path.chmod(0o600)
            self.inputs[key] = path
        self.events = router.path("work/materialize-events")
        self.fetch_env = router.path("work/fetch-environment")
        self._install_curl()

    def _install_curl(self, *, fail_url: str | None = None) -> None:
        cases = "\n".join(
            (
                f"  {shlex.quote(str(package['url']))}) "
                f"_source={shlex.quote(str(self.inputs[key]))}; _tag={key} ;;"
            )
            for key, package in self.packages.items()
        )
        script = (
            "#!/bin/sh\n"
            "_out= _headers= _url=\n"
            'while [ "$#" -gt 0 ]; do\n'
            "  case $1 in --output) _out=$2; shift 2 ;; --dump-header) _headers=$2; shift 2 ;; "
            "--url) _url=$2; shift 2 ;; *) shift ;; esac\n"
            "done\n"
            f"case $_url in\n{cases}\n  *) exit 10 ;;\nesac\n"
            f"printf 'fetch:%s\\n' \"$_tag\" >> {shlex.quote(str(self.events))}\n"
            "printf 'PATH=%s\\tLC_ALL=%s\\tOPENSSL_CONF=%s\\tGZIP=%s\\t"
            "TAR_OPTIONS=%s\\tLD_LIBRARY_PATH=%s\\tHTTPS_PROXY=%s\\tCWD=%s\\n' "
            '"${PATH-unset}" "${LC_ALL-unset}" "${OPENSSL_CONF-unset}" "${GZIP-unset}" '
            '"${TAR_OPTIONS-unset}" "${LD_LIBRARY_PATH-unset}" "${HTTPS_PROXY-unset}" "$(pwd -P)" '
            f">> {shlex.quote(str(self.fetch_env))}\n"
            "_stdin=eof\nIFS= read -r _line && _stdin=content\n"
            "_fds=closed\n"
            'for _fd in 3 4 5 6 7 8 9; do eval "(: <&$_fd)" 2>/dev/null && _fds=open; done\n'
            'printf \'STDIN=%s\\tFDS=%s\\n\' "$_stdin" "$_fds" >> '
            f"{shlex.quote(str(self.fetch_env))}\n"
            "case $_tag in coreutils-timeout) _size="
            + str(len(self.packages["coreutils-timeout"]["archive"]))
            + " ;; "
            "gzip) _size=" + str(len(self.packages["gzip"]["archive"])) + " ;; esac\n"
            'printf "HTTP/1.1 200 OK\\r\\nContent-Length: %s\\r\\n\\r\\n" "$_size" >"$_headers"\n'
            '"/bin/cp" "$_source" "$_out" || exit 11\n'
            + (
                f'[ "$_url" != {shlex.quote(fail_url)} ] || exit 9\n'
                if fail_url is not None
                else ""
            )
            + "printf 200\n"
        )
        curl = self.tools / "curl"
        if curl.is_symlink():
            curl.unlink()
        curl.write_text(script, encoding="utf-8")
        curl.chmod(0o700)

    def override_selectors(self) -> str:
        archive_cases = []
        payload_cases = []
        for key, package in self.packages.items():
            data = package["archive"]
            archive_cases.append(
                f"{key}) _bootstrap_url={shlex.quote(str(package['url']))}; "
                f"_bootstrap_size={len(data)}; _bootstrap_sha256={digest(data)} ;;"
            )
            payload_cases.append(
                f"{key}) _bootstrap_outer_size={len(package['outer'])}; "
                f"_bootstrap_outer_sha256={digest(package['outer'])}; "
                f"_bootstrap_data_gz_size={len(package['data_gz'])}; "
                f"_bootstrap_data_gz_sha256={digest(package['data_gz'])}; "
                f"_bootstrap_data_tar_size={len(package['data_tar'])}; "
                f"_bootstrap_data_tar_sha256={digest(package['data_tar'])}; "
                f"_bootstrap_member={shlex.quote(str(package['member']))}; "
                f"_bootstrap_member_size={len(package['program'])}; "
                f"_bootstrap_member_sha256={digest(package['program'])} ;;"
            )
        return (
            "_cfmgr_bootstrap_archive() {\n"
            '  [ "$#" -eq 2 ] && [ "$1" = aarch64-k3.10 ] || return 2\n'
            "  case $2 in\n"
            + "\n".join(f"    {row}" for row in archive_cases)
            + "\n    *) return 2 ;;\n  esac\n}\n"
            "_cfmgr_bootstrap_payload() {\n"
            '  [ "$#" -eq 2 ] && [ "$1" = aarch64-k3.10 ] || return 2\n'
            "  case $2 in\n"
            + "\n".join(f"    {row}" for row in payload_cases)
            + "\n    *) return 2 ;;\n  esac\n}\n"
        )

    def instrument_parsers(self) -> None:
        for name in ("dd", "gunzip", "tar"):
            target = self.tools / name
            original = target.resolve()
            target.unlink()
            target.write_text(
                "#!/bin/sh\n"
                f"printf '%s\\n' {shlex.quote(name)} >> {shlex.quote(str(self.events))}\n"
                f'exec {shlex.quote(str(original))} "$@"\n',
                encoding="utf-8",
            )
            target.chmod(0o700)

    def invoke(self, body: str, *, env: dict[str, str] | None = None) -> ShellResult:
        script = (
            f". {shlex.quote(str(CLOSURE))}\n"
            f". {shlex.quote(str(FETCH))}\n"
            f". {shlex.quote(str(BOOTSTRAP))}\n"
            f". {shlex.quote(str(ROOT / 'modules/archive.sh'))}\n" + body
        )
        return self.router.run(script, env=env, timeout=10)


def test_production_entry_passes_literal_empty_tools_and_rejects_bad_calls(
    router: RouterHarness,
) -> None:
    captured = router.path("work/materialize-route")
    directory = router.path("ram/tmp/route")
    script = (
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        "_cfmgr_bootstrap_materialize_run() {\n"
        '  [ "$#" -eq 3 ] && [ "$2" = aarch64-k3.10 ] || return 8\n'
        f'  printf "%s\\t%s\\t%s\\n" "$1" "$2" "$3" > {shlex.quote(str(captured))}\n'
        "}\n"
        f"cfmgr_bootstrap_materialize aarch64-k3.10 {shlex.quote(str(directory))}; _good=$?\n"
        f"cfmgr_bootstrap_materialize unknown {shlex.quote(str(directory))}; _unknown=$?\n"
        f"cfmgr_bootstrap_materialize aarch64-k3.10; _count=$?\n"
        'printf "RESULT\\t%s\\t%s\\t%s\\n" "$_good" "$_unknown" "$_count"\n'
    )
    result = router.run(
        script,
        env={
            "_fetch_tools": "/ambient/tools",
            "_bootstrap_url": "https://ambient.invalid/poison.ipk",
            "_bootstrap_size": "1",
            "_bootstrap_sha256": "0" * 64,
        },
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t0\t8\t2\n"
    assert captured.read_text().splitlines() == [f"\taarch64-k3.10\t{directory}"]


def test_native_materialization_fetches_then_extracts_both_packages_and_preserves_caller(
    router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(router)
    fixture.instrument_parsers()
    marker = router.path("work/materialize-exit-trap")
    caller_input = router.write("work/materialize-caller-input", "caller input remains\n")
    state = (
        "IFS='~,:'\nset +f\numask 027\n"
        f"trap 'printf x >> {shlex.quote(str(marker))}' 0\n"
        f"exec 0<{shlex.quote(str(caller_input))}\n"
        "exec 3</dev/null 4</dev/null 5</dev/null 6</dev/null 7</dev/null 8</dev/null 9</dev/null\n"
    )
    after = (
        '_ifs=$([ "$IFS" = "~,:" ] && printf yes || printf no)\n'
        '_glob=$([ "${-#*f}" = "$-" ] && printf yes || printf no)\n'
        "_umask=$(umask)\n"
        'for _fd in 3 4 5 6 7 8 9; do eval "(: <&$_fd)" 2>/dev/null || exit 9; done\n'
        'IFS= read -r _caller_line && [ "$_caller_line" = "caller input remains" ] || exit 10\n'
        'printf "STATE\\t%s:%s:%s\\n" "$_ifs" "$_glob" "$_umask"\n'
    )
    result = fixture.invoke(
        fixture.override_selectors()
        + state
        + materialize_call("aarch64-k3.10", fixture.directory, fixture.tools)
        + '_status=$?\nprintf "RESULT\\t%s\\n" "$_status"\n'
        + after,
        env={
            "GZIP": "--verbose",
            "TAR_OPTIONS": "--absolute-names",
            "LD_LIBRARY_PATH": "/ambient/injected-libraries",
            "OPENSSL_CONF": "/ambient/openssl.cnf",
            "HTTPS_PROXY": "https://ambient.invalid:9999",
        },
    )

    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t0\nSTATE\tyes:yes:0027\n"
    assert marker.read_text() == "x"
    assert fixture.events.read_text().splitlines() == [
        "fetch:coreutils-timeout",
        "dd",
        "gunzip",
        "tar",
        "gunzip",
        "tar",
        "fetch:gzip",
        "dd",
        "gunzip",
        "tar",
        "gunzip",
        "tar",
    ]
    assert fixture.fetch_env.read_text().splitlines() == [
        "PATH=/sbin:/bin:/usr/sbin:/usr/bin\tLC_ALL=C\tOPENSSL_CONF=/dev/null\tGZIP=unset\t"
        "TAR_OPTIONS=unset\tLD_LIBRARY_PATH=unset\tHTTPS_PROXY=unset\tCWD=/",
        "STDIN=eof\tFDS=closed",
        "PATH=/sbin:/bin:/usr/sbin:/usr/bin\tLC_ALL=C\tOPENSSL_CONF=/dev/null\tGZIP=unset\t"
        "TAR_OPTIONS=unset\tLD_LIBRARY_PATH=unset\tHTTPS_PROXY=unset\tCWD=/",
        "STDIN=eof\tFDS=closed",
    ]
    assert fixture.directory.stat().st_mode & 0o777 == 0o700
    for key, name in (("coreutils-timeout", "timeout"), ("gzip", "gzip")):
        root = fixture.directory / name
        package = fixture.packages[key]
        assert fixture.inputs[key].read_bytes() == package["archive"]
        assert (root / "program").read_bytes() == package["program"]
        for path in root.iterdir():
            assert path.stat().st_mode & 0o777 == 0o600
        download = fixture.directory / f"{name}-download"
        assert (download / "artifact.ipk").read_bytes() == package["archive"]
        assert not (root / "opt").exists()


def test_second_fetch_failure_retains_first_package_and_stops_before_gzip_parser(
    router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(router)
    gzip_url = str(fixture.packages["gzip"]["url"])
    fixture._install_curl(fail_url=gzip_url)
    fixture.instrument_parsers()
    result = fixture.invoke(
        fixture.override_selectors()
        + materialize_call("aarch64-k3.10", fixture.directory, fixture.tools)
        + '_status=$?\nprintf "RESULT\\t%s\\n" "$_status"\n'
    )

    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t1\n"
    assert (fixture.directory / "timeout/program").read_bytes() == fixture.packages[
        "coreutils-timeout"
    ]["program"]
    assert (fixture.directory / "gzip-download/artifact.ipk").read_bytes() == fixture.packages[
        "gzip"
    ]["archive"]
    assert not (fixture.directory / "gzip").exists()
    assert fixture.events.read_text().splitlines() == [
        "fetch:coreutils-timeout",
        "dd",
        "gunzip",
        "tar",
        "gunzip",
        "tar",
        "fetch:gzip",
    ]


def test_materialize_api_rejects_invalid_arguments_before_creating_output(
    router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(router)
    bad_tools = router.path("work/not-a-tools-directory")
    bad_tools.mkdir(mode=0o700)
    invalid_calls = (
        ("aarch64-k3.10", router.path("ram/tmp/bad-count")),
        ("unknown", router.path("ram/tmp/bad-profile"), fixture.tools),
        ("aarch64-k3.10", "relative/output", fixture.tools),
        ("aarch64-k3.10", router.path("ram/tmp/bad-tools"), "relative/tools"),
        ("aarch64-k3.10", router.path("ram/tmp/empty-tools"), ""),
        ("aarch64-k3.10", bad_tools, fixture.tools),
    )
    calls = "".join(
        f"{materialize_call(*args).rstrip()}; _case{index}=$?\n"
        for index, args in enumerate(invalid_calls)
    )
    result_fields = " ".join(f'"$_case{index}"' for index in range(len(invalid_calls)))
    calls += f'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" {result_fields}\n'
    result = fixture.invoke(fixture.override_selectors() + calls)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t2\t2\t2\t2\t2\t1\n"
    for name in ("bad-count", "bad-profile", "bad-tools", "empty-tools"):
        assert not router.path(f"ram/tmp/{name}").exists()
    assert not fixture.events.exists()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_busybox_shell_and_native_applets_materialize_synthetic_packages(
    busybox_router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(busybox_router, busybox=busybox_router.busybox)
    result = fixture.invoke(
        fixture.override_selectors()
        + materialize_call("aarch64-k3.10", fixture.directory, fixture.tools)
        + '_status=$?\nprintf "RESULT\\t%s\\n" "$_status"\n'
    )
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t0\n"
    for name in ("timeout", "gzip"):
        assert (fixture.directory / name / "program").is_file()
