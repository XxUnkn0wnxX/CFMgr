"""Bounded native fetch tests use inert synthetic bytes, never package execution."""

from __future__ import annotations

import hashlib
import json
import os
import shlex
import shutil
import ssl
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
FETCH = ROOT / "modules/fetch.sh"
BOOTSTRAP = ROOT / "modules/bootstrap.sh"
CATALOG = ROOT / "docs/evidence/bootstrap-catalog.json"
PROFILES = ("aarch64-k3.10", "armv7sf-k3.2", "mipselsf-k3.4")
PACKAGES = ("coreutils-timeout", "gzip")
TOOLS = ("mkdir", "curl", "env", "wc", "openssl", "hexdump")
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def native_program(name: str) -> str:
    path = shutil.which(name, path="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin")
    if path is None:
        pytest.fail(f"required host tool {name} is unavailable; it must be preinstalled")
    return os.path.realpath(path)


class FetchFixture:
    def __init__(self, router: RouterHarness, *, busybox: Path | None = None):
        self.router = router
        self.tools = router.path("work/native tools")
        self.tools.mkdir(mode=0o700)
        for name in TOOLS:
            if name == "curl":
                continue
            if name == "hexdump" and busybox is not None:
                self.tools.joinpath(name).symlink_to(busybox)
            else:
                self.tools.joinpath(name).symlink_to(native_program(name))
        self.directory = router.path("ram/tmp/download")
        self.body = router.path("work/synthetic.ipk")
        self.body.write_bytes(b"opaque, synthetic package bytes\x00\xff\n")
        self.body.chmod(0o600)
        self.args_capture = router.path("work/curl-argv")
        self.env_capture = router.path("work/curl-env")

    def fake_curl(
        self,
        *,
        body: bytes | None = None,
        status: str = "200",
        header: bytes | None = None,
        exit_code: int = 0,
        overflow: bool = False,
    ) -> None:
        source = self.body
        if body is not None:
            source = self.router.path("work/curl-body")
            source.write_bytes(body)
            source.chmod(0o600)
        header_path = self.router.path("work/curl-header")
        if header is None:
            length = len(source.read_bytes())
            header = f"HTTP/1.1 200 OK\r\nContent-Length: {length}\r\n\r\n".encode()
        header_path.write_bytes(header)
        script = (
            "#!/bin/sh\nset -eu\n"
            f": > {shlex.quote(str(self.args_capture))}\n"
            'for _arg do printf "%s\\n" "$_arg" >>'
            f"{shlex.quote(str(self.args_capture))}; done\n"
            f"printf 'PATH=%s\\nLC_ALL=%s\\nOPENSSL_CONF=%s\\nHOME=%s\\n"
            f"CURL_HOME=%s\\nCURL_CA_BUNDLE=%s\\nLD_LIBRARY_PATH=%s\\nHTTPS_PROXY=%s\\n' "
            f'"${{PATH-unset}}" "${{LC_ALL-unset}}" "${{OPENSSL_CONF-unset}}" '
            f'"${{HOME-unset}}" "${{CURL_HOME-unset}}" "${{CURL_CA_BUNDLE-unset}}" '
            f'"${{LD_LIBRARY_PATH-unset}}" "${{HTTPS_PROXY-unset}}" '
            f"> {shlex.quote(str(self.env_capture))}\n"
            "_out= _headers=\n"
            'while [ "$#" -gt 0 ]; do\n'
            "  case $1 in --output) _out=$2; shift 2 ;; "
            "--dump-header) _headers=$2; shift 2 ;; *) shift ;; esac\n"
            "done\n"
        )
        if overflow:
            script += (
                f"{shlex.quote(sys.executable)} -c "
                + shlex.quote(
                    "import signal, sys; signal.signal(signal.SIGXFSZ, signal.SIG_IGN); "
                    "p=sys.argv[1]; f=open(p,'wb',buffering=0); "
                    "\ntry: f.write(b'X'*200000)\nexcept OSError: pass\nf.close()"
                )
                + ' "$_out"\n'
            )
        else:
            script += f'/bin/cp {shlex.quote(str(source))} "$_out"\n'
        script += (
            f'/bin/cp {shlex.quote(str(header_path))} "$_headers"\n'
            f"printf '%s' {shlex.quote(status)}\n"
            f"exit {exit_code}\n"
        )
        self.tools.joinpath("curl").write_text(script, encoding="utf-8")
        self.tools.joinpath("curl").chmod(0o700)

    def invoke(
        self,
        *,
        url: str = "https://fixture.invalid/package.ipk",
        size: int | None = None,
        digest: str | None = None,
        directory: Path | None = None,
        env: dict[str, str] | None = None,
        shell: str | None = "/bin/sh",
        preserve_state: bool = False,
    ) -> ShellResult:
        data = self.body.read_bytes()
        size = len(data) if size is None else size
        digest = hashlib.sha256(data).hexdigest() if digest is None else digest
        target = self.directory if directory is None else directory
        state_setup = ""
        state_result = ""
        if preserve_state:
            marker = self.router.path("work/outer-exit-trap")
            state_setup = (
                f"IFS='~,:'\nset +f\numask 027\ntrap 'printf x >> {shlex.quote(str(marker))}' 0\n"
            )
            state_result = (
                '_state_ifs=$([ "$IFS" = "~,:" ] && printf yes || printf no)\n'
                '_state_glob=$([ "${-#*f}" = "$-" ] && printf yes || printf no)\n'
                "_state_umask=$(umask)\n"
                'printf "\\t%s:%s:%s" "$_state_ifs" "$_state_glob" "$_state_umask"\n'
            )
        subject = self.router.write(
            "work/invoke-fetch.sh",
            f". {shlex.quote(str(ROOT / 'modules/closure.sh'))}\n"
            f". {shlex.quote(str(BOOTSTRAP))}\n"
            f". {shlex.quote(str(FETCH))}\n" + state_setup + 'cfmgr_fetch_test "$@"\n'
            "_fetch_status=$?\n"
            'printf "RESULT\\t%s" "$_fetch_status"\n' + state_result + 'printf "\\n"\n',
        )
        if shell is None:
            if self.router.busybox is None:
                raise ValueError("BusyBox shell was requested without a BusyBox fixture")
            invocation = f'exec {shlex.quote(str(self.router.busybox))} sh "$@"\n'
        else:
            invocation = f'exec {shlex.quote(shell)} "$@"\n'
        args = [str(self.tools), str(target), url, str(size), digest]
        return self.router.run(invocation, [str(subject), *args], timeout=10, env=env)


def test_archive_selector_matches_all_reviewed_catalogue_identities(router: RouterHarness) -> None:
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    rows = []
    for profile in PROFILES:
        for package in PACKAGES:
            entry = catalog["profiles"][profile]["packages"][package]
            rows.append((profile, package, entry["url"], str(entry["size"]), entry["sha256"]))
    script = (
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        + "\n".join(
            f"_cfmgr_bootstrap_archive {shlex.quote(profile)} {shlex.quote(package)} || exit 7\n"
            'printf "%s\\t%s\\t%s\\t%s\\t%s\\n" '
            f"{shlex.quote(profile)} {shlex.quote(package)} "
            '"$_bootstrap_url" "$_bootstrap_size" "$_bootstrap_sha256"'
            for profile, package, *_ in rows
        )
        + "\n"
    )
    result = router.run(script)

    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.splitlines() == ["\t".join(row) for row in rows]


def test_production_fetch_uses_selected_native_identity_and_rejects_bad_route(
    router: RouterHarness,
) -> None:
    captured = router.path("work/production-fetch-args")
    directory = router.path("ram/tmp/production-fetch")
    script = (
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        f". {shlex.quote(str(FETCH))}\n"
        "_cfmgr_fetch_run() {\n"
        '  [ "$#" -eq 5 ] && [ -z "$1" ] || return 9\n'
        f'  printf "%s\\t%s\\t%s\\t%s\\n" "$2" "$3" "$4" "$5" >{shlex.quote(str(captured))}\n'
        "  return 0\n"
        "}\n"
        'cfmgr_bootstrap_fetch armv7sf-k3.2 gzip "$DIRECTORY"\n'
        "_good=$?\n"
        'cfmgr_bootstrap_fetch unknown gzip "$DIRECTORY"; _bad_profile=$?\n'
        'cfmgr_bootstrap_fetch armv7sf-k3.2 unknown "$DIRECTORY"; _bad_package=$?\n'
        "cfmgr_bootstrap_fetch armv7sf-k3.2 gzip; _bad_count=$?\n"
        'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\n" "$_good" "$_bad_profile" '
        '"$_bad_package" "$_bad_count"\n'
    )
    script = f"DIRECTORY={shlex.quote(str(directory))}\n" + script
    result = router.run(
        script,
        env={
            "LD_LIBRARY_PATH": "/ambient/injected-libraries",
            "OPENSSL_CONF": "/ambient/openssl.cnf",
            "_fetch_tools": "/ambient/tools",
            "_bootstrap_url": "https://ambient.invalid/archive.ipk",
            "_bootstrap_size": "1",
            "_bootstrap_sha256": "0" * 64,
        },
    )

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\t2\t2\t2\n" and result.stderr == ""
    expected = json.loads(CATALOG.read_text(encoding="utf-8"))["profiles"]["armv7sf-k3.2"][
        "packages"
    ]["gzip"]
    assert captured.read_text().splitlines() == [
        "\t".join(
            (
                str(directory),
                expected["url"],
                str(expected["size"]),
                expected["sha256"],
            )
        )
    ]


def test_fixture_fetch_accepts_exact_bytes_and_clears_ambient_configuration(
    router: RouterHarness,
) -> None:
    fixture = FetchFixture(router)
    fixture.body.write_bytes(bytes(range(256)) * 256)
    fixture.fake_curl()
    poisoned = {
        "CURL_HOME": "/ambient/curl",
        "CURL_CA_BUNDLE": "/ambient/ca.pem",
        "LD_LIBRARY_PATH": "/ambient/injected-libraries",
        "OPENSSL_CONF": "/ambient/openssl.cnf",
        "HTTPS_PROXY": "http://ambient.invalid:9",
    }
    result = fixture.invoke(env=poisoned, preserve_state=True)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\tyes:yes:0027\n" and result.stderr == ""
    assert router.path("work/outer-exit-trap").read_text() == "x"
    directory = fixture.directory
    artifact = directory / "artifact.ipk"
    assert artifact.read_bytes() == fixture.body.read_bytes()
    assert artifact.stat().st_size == 65_536
    assert artifact.stat().st_mode & 0o777 == 0o600
    assert directory.stat().st_mode & 0o777 == 0o700
    for name in ("headers", "http-status", "digest", "digest.hex"):
        assert (directory / name).stat().st_mode & 0o777 == 0o600
    assert (directory / "http-status").read_bytes() == b"200"
    assert (directory / "digest").read_bytes() == hashlib.sha256(fixture.body.read_bytes()).digest()
    assert (directory / "digest.hex").read_text() == hashlib.sha256(
        fixture.body.read_bytes()
    ).hexdigest()
    argv = fixture.args_capture.read_text().splitlines()
    assert argv[0] == "-q"
    assert "--silent" in argv and "--fail" in argv and "--globoff" in argv
    for option, value in (
        ("--proto", "=https"),
        ("--proto-redir", "=https"),
        ("--connect-timeout", "10"),
        ("--max-time", "60"),
        ("--retry", "0"),
        ("--max-redirs", "0"),
        ("--max-filesize", str(len(fixture.body.read_bytes()))),
    ):
        assert argv[argv.index(option) + 1] == value
    assert "-L" not in argv and "--location" not in argv and "-k" not in argv
    assert argv[argv.index("--proxy") + 1] == ""
    assert argv[argv.index("--url") + 1] == "https://fixture.invalid/package.ipk"
    assert argv[argv.index("--dump-header") + 1] == str(directory / "headers")
    assert argv[argv.index("--output") + 1] == str(artifact)
    assert argv[argv.index("--write-out") + 1] == "%{http_code}"
    captured_env = dict(line.split("=", 1) for line in fixture.env_capture.read_text().splitlines())
    assert captured_env["PATH"] == "/sbin:/bin:/usr/sbin:/usr/bin"
    assert captured_env["LC_ALL"] == "C"
    assert captured_env["OPENSSL_CONF"] == "/dev/null"
    assert captured_env["HOME"] == "unset"
    assert all(captured_env[name] == "unset" for name in poisoned if name != "OPENSSL_CONF")


@pytest.mark.parametrize(
    ("case", "body", "status", "header", "exit_code", "expected_size", "expected_digest"),
    [
        pytest.param(
            "producer-error",
            None,
            "200",
            b"HTTP/1.1 200 OK\r\n\r\n",
            22,
            None,
            None,
            id="producer-status",
        ),
        pytest.param(
            "redirect",
            None,
            "302",
            b"HTTP/1.1 302 Found\r\n\r\n",
            0,
            None,
            None,
            id="redirect-status",
        ),
        pytest.param(
            "short-body", b"short", "200", b"HTTP/1.1 200 OK\r\n\r\n", 0, 80, None, id="short-body"
        ),
        pytest.param(
            "wrong-hash",
            None,
            "200",
            b"HTTP/1.1 200 OK\r\n\r\n",
            0,
            None,
            "0" * 64,
            id="digest-mismatch",
        ),
        pytest.param(
            "status-framing",
            None,
            "200\n",
            b"HTTP/1.1 200 OK\r\n\r\n",
            0,
            None,
            None,
            id="extra-status-byte",
        ),
        pytest.param("large-header", None, "200", b"H" * 16385, 0, None, None, id="header-limit"),
    ],
)
def test_fixture_fetch_rejects_unapproved_or_incomplete_responses(
    router: RouterHarness,
    case: str,
    body: bytes | None,
    status: str,
    header: bytes,
    exit_code: int,
    expected_size: int | None,
    expected_digest: str | None,
) -> None:
    fixture = FetchFixture(router)
    fixture.fake_curl(body=body, status=status, header=header, exit_code=exit_code)
    result = fixture.invoke(size=expected_size, digest=expected_digest)

    assert result.returncode == 0, f"{case}: {result}"
    assert result.stdout == "RESULT\t1\n" and result.stderr == ""
    assert fixture.directory.is_dir()
    assert (fixture.directory / "artifact.ipk").exists()
    assert (fixture.directory / "headers").exists()


def test_fixture_fetch_rejects_physical_overflow_despite_producer_success(
    router: RouterHarness,
) -> None:
    fixture = FetchFixture(router)
    fixture.fake_curl(overflow=True)
    result = fixture.invoke(size=34)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\n" and result.stderr == ""
    artifact = fixture.directory / "artifact.ipk"
    assert artifact.is_file()
    assert 34 < artifact.stat().st_size <= 132_096
    assert (fixture.directory / "headers").is_file()
    assert (fixture.directory / "http-status").read_bytes() == b"200"


def test_native_curl_transfers_trusted_loopback_tls_and_rejects_redirect(
    router: RouterHarness,
) -> None:
    fixture = FetchFixture(router)
    key = router.path("work/loopback.key")
    certificate = router.path("work/loopback.crt")
    config = router.write(
        "work/openssl.cnf",
        "[req]\n"
        "distinguished_name = dn\n"
        "x509_extensions = extensions\n"
        "prompt = no\n"
        "[dn]\n"
        "CN = 127.0.0.1\n"
        "[extensions]\n"
        "subjectAltName = IP:127.0.0.1\n",
    )
    generated = subprocess.run(
        [
            native_program("openssl"),
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-keyout",
            str(key),
            "-out",
            str(certificate),
            "-days",
            "1",
            "-config",
            str(config),
        ],
        capture_output=True,
        timeout=10,
        check=False,
        env={"PATH": "", "LC_ALL": "C"},
    )
    assert generated.returncode == 0, generated.stderr.decode(errors="replace")
    payload = fixture.body.read_bytes()
    requests: list[str] = []

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            requests.append(self.path)
            if self.path == "/redirect":
                self.send_response(302)
                self.send_header("Location", "/package.ipk")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, _format: str, *_args: object) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(certificate, key)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    native_curl = native_program("curl")
    wrapper = (
        "#!/bin/sh\n"
        f"CURL_CA_BUNDLE={shlex.quote(str(certificate))}\n"
        f'export CURL_CA_BUNDLE\nexec {shlex.quote(native_curl)} "$@"\n'
    )
    fixture.tools.joinpath("curl").write_text(wrapper, encoding="utf-8")
    fixture.tools.joinpath("curl").chmod(0o700)
    origin = f"https://127.0.0.1:{server.server_port}"
    try:
        success = fixture.invoke(url=f"{origin}/package.ipk")
        assert success.returncode == 0, success
        assert success.stdout == "RESULT\t0\n" and success.stderr == ""
        assert (fixture.directory / "artifact.ipk").read_bytes() == payload
        assert b"200 OK" in (fixture.directory / "headers").read_bytes()
        assert b"Content-Length" in (fixture.directory / "headers").read_bytes()

        redirect_dir = router.path("ram/tmp/redirect-download")
        redirect = fixture.invoke(url=f"{origin}/redirect", directory=redirect_dir)
        assert redirect.returncode == 0, redirect
        assert redirect.stdout == "RESULT\t1\n" and redirect.stderr == ""
        assert (redirect_dir / "http-status").read_bytes() == b"302"
        assert requests == ["/package.ipk", "/redirect"], "curl must not follow redirects"
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)


def test_invalid_arguments_and_existing_output_nodes_never_call_curl(router: RouterHarness) -> None:
    fixture = FetchFixture(router)
    marker = router.path("work/curl-called")
    fixture.tools.joinpath("curl").write_text(
        f"#!/bin/sh\n: > {shlex.quote(str(marker))}\nexit 1\n", encoding="utf-8"
    )
    fixture.tools.joinpath("curl").chmod(0o700)
    cases: list[tuple[str, list[str], int]] = [
        ("bad-count", [str(fixture.tools), str(fixture.directory)], 2),
        (
            "bad-scheme",
            [str(fixture.tools), str(fixture.directory), "http://bad", "1", "0" * 64],
            2,
        ),
        ("bad-size", [str(fixture.tools), str(fixture.directory), "https://x", "01", "0" * 64], 2),
        (
            "oversize",
            [str(fixture.tools), str(fixture.directory), "https://x", "65537", "0" * 64],
            2,
        ),
        ("bad-hash", [str(fixture.tools), str(fixture.directory), "https://x", "1", "A" * 64], 2),
        (
            "bad-tools",
            [
                str(fixture.router.path("work/missing")),
                str(fixture.directory),
                "https://x",
                "1",
                "0" * 64,
            ],
            2,
        ),
        (
            "bad-directory",
            [str(fixture.tools), "relative/download", "https://x", "1", "0" * 64],
            2,
        ),
    ]
    for name, args, expected in cases:
        subject = router.write(
            "work/invalid-fetch.sh",
            f". {shlex.quote(str(ROOT / 'modules/closure.sh'))}\n"
            f". {shlex.quote(str(FETCH))}\n"
            'cfmgr_fetch_test "$@"\n'
            "_fetch_status=$?\n"
            'printf "RESULT\\t%s\\n" "$_fetch_status"\n',
        )
        result = router.run('exec /bin/sh "$@"\n', [str(subject), *args])
        assert result.returncode == 0, f"{name}: {result}"
        assert result.stdout == f"RESULT\t{expected}\n" and result.stderr == ""
        assert not fixture.directory.exists(), f"{name} must reject before mkdir"
    for node_name, create in (
        ("directory", lambda path: path.mkdir()),
        ("regular", lambda path: path.write_bytes(b"keep")),
        ("symlink", lambda path: path.symlink_to("missing-target")),
        ("fifo", os.mkfifo),
    ):
        target = router.path(f"ram/tmp/existing-{node_name}")
        create(target)
        subject = router.write(
            "work/existing-fetch.sh",
            f". {shlex.quote(str(ROOT / 'modules/closure.sh'))}\n"
            f". {shlex.quote(str(FETCH))}\n"
            'cfmgr_fetch_test "$@"\n'
            "_fetch_status=$?\n"
            'printf "RESULT\\t%s\\n" "$_fetch_status"\n',
        )
        result = router.run(
            'exec /bin/sh "$@"\n',
            [str(subject), str(fixture.tools), str(target), "https://x", "1", "0" * 64],
        )
        assert result.returncode == 0, f"existing {node_name}: {result}"
        assert result.stdout == "RESULT\t1\n" and result.stderr == ""
        assert target.exists() or target.is_symlink()
    assert not marker.exists(), "invalid calls and existing output must stop before curl"


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_busybox_fetch_consumer_accepts_exact_synthetic_bytes(
    busybox_router: RouterHarness,
) -> None:
    fixture = FetchFixture(busybox_router, busybox=busybox_router.busybox)
    fixture.fake_curl()
    result = fixture.invoke(shell=None)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\n" and result.stderr == ""
    assert (fixture.directory / "artifact.ipk").read_bytes() == fixture.body.read_bytes()
