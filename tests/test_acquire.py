"""Focused remote-acquisition consumer tests with a private HTTPS fixture."""

from __future__ import annotations

import hashlib
import http.server
import os
import shlex
import ssl
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import TypedDict

import pytest
from test_install import package as _package
from test_install import tools as base_tools
from test_native import host_mv_profile
from test_native import native_tools as _native_tools
from test_native import tls_material as _tls_material
from test_prerequisites import pause_definition, shell

native_tools = _native_tools
tls_material = _tls_material
package = _package
__all__ = [
    "_native_tools",
    "_tls_material",
    "base_tools",
    "host_mv_profile",
    "native_tools",
    "package",
    "shell",
    "tls_material",
]


class Response(TypedDict, total=False):
    status: int
    headers: dict[str, str]
    body: bytes
    chunked: bool
    delay: float


class ServerState(TypedDict):
    routes: dict[str, Response | list[Response]]
    requests: list[tuple[str, dict[str, str]]]
    lock: threading.Lock


@pytest.fixture(scope="module")
def acquire_tls_cert(request: pytest.FixtureRequest) -> tuple[Path, Path]:
    native_tools = request.getfixturevalue("native_tools")
    tls_material = request.getfixturevalue("tls_material")
    tmp_path_factory = request.getfixturevalue("tmp_path_factory")
    directory = tmp_path_factory.mktemp("synthetic-acquire-tls")
    (directory / "extensions").write_text(
        "subjectAltName=DNS:api.github.com,DNS:raw.githubusercontent.com\n"
    )
    subprocess.run(
        [
            native_tools["openssl"],
            "x509",
            "-req",
            "-in",
            str(tls_material / "server.csr"),
            "-CA",
            str(tls_material / "trusted.pem"),
            "-CAkey",
            str(tls_material / "trusted.key"),
            "-CAserial",
            str(directory / "ca.srl"),
            "-CAcreateserial",
            "-out",
            str(directory / "server.pem"),
            "-days",
            "1",
            "-extfile",
            str(directory / "extensions"),
        ],
        cwd=directory,
        check=True,
        capture_output=True,
        timeout=5,
        env={"PATH": os.defpath, "OPENSSL_CONF": "/dev/null"},
    )
    return directory / "server.pem", tls_material / "server.key"


@pytest.fixture(scope="module")
def acquire_tls_server(acquire_tls_cert: tuple[Path, Path]):
    state: ServerState = {"routes": {}, "requests": [], "lock": threading.Lock()}

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def do_GET(self) -> None:
            with state["lock"]:
                state["requests"].append((self.path, dict(self.headers)))
                route = state["routes"].get(self.path)
                if isinstance(route, list):
                    response = route.pop(0) if len(route) > 1 else route[0]
                else:
                    response = route
            if response is None:
                status, headers, body = 404, {}, b"not found\n"
                delay, chunked = 0, False
            else:
                status = response.get("status", 200)
                headers = response.get("headers", {})
                body = response.get("body", b"")
                delay = response.get("delay", 0)
                chunked = response.get("chunked", False)
            if delay:
                time.sleep(delay)
            self.send_response(status)
            for name, value in headers.items():
                self.send_header(name, value)
            if chunked:
                self.send_header("Transfer-Encoding", "chunked")
            elif "Content-Length" not in headers:
                self.send_header("Content-Length", str(len(body)))
            if "Connection" not in headers:
                self.send_header("Connection", "close")
            self.end_headers()
            if chunked:
                for offset in range(0, len(body), 1024):
                    block = body[offset : offset + 1024]
                    self.wfile.write(f"{len(block):X}\r\n".encode() + block + b"\r\n")
                self.wfile.write(b"0\r\n\r\n")
            else:
                self.wfile.write(body)
            self.close_connection = True

        def log_message(self, *_arguments: object) -> None:
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    server.daemon_threads = True
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(*acquire_tls_cert)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(
        target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True
    )
    thread.start()
    try:
        yield server.server_port, state
    finally:
        server.shutdown()
        thread.join(timeout=2)
        server.server_close()
        assert not thread.is_alive(), "Owned acquisition TLS fixture failed to stop"


def package_responses(
    package: Path,
    owner: str,
    repo: str,
    branch: str,
    revision: str,
    *,
    overrides: dict[str, bytes] | None = None,
) -> dict[str, Response | list[Response]]:
    """Build exact API/raw fixtures from one immutable installed package."""
    api_path = f"/repos/{owner}/{repo}/commits/{branch}"
    raw_root = f"/{owner}/{repo}/{revision}"
    payloads = {
        item.relative_to(package).as_posix(): item.read_bytes()
        for item in package.rglob("*")
        if item.is_file() and item.name != "manifest.txt"
    }
    payloads["manifest.txt"] = (package / "manifest.txt").read_bytes()
    payloads.update(overrides or {})
    routes: dict[str, Response | list[Response]] = {
        api_path: {"body": (revision + "\n").encode()},
    }
    routes.update(
        {
            f"{raw_root}/{relative}": {
                "body": body,
                "headers": {"Content-Length": str(len(body))},
            }
            for relative, body in payloads.items()
        }
    )
    return routes


def reset_routes(
    state: ServerState, routes: dict[str, Response | list[Response]]
) -> None:
    with state["lock"]:
        state["routes"].clear()
        state["routes"].update(routes)
        state["requests"].clear()


def request_paths(state: ServerState) -> list[str]:
    with state["lock"]:
        return [path for path, _headers in state["requests"]]


def routed_curl(actual_curl: str, port: int, directory: Path) -> Path:
    """Route only the two pinned TLS hostnames to the private HTTPS server."""
    wrapper = directory / "curl-local-github"
    wrapper.write_text(
        "#!/bin/sh\n"
        '[ "$1" = -q ] || exit 2\n'
        "shift\n"
        f"exec {shlex.quote(actual_curl)} "
        "-q "
        f"--connect-to api.github.com:443:127.0.0.1:{port} "
        f'--connect-to raw.githubusercontent.com:443:127.0.0.1:{port} "$@"\n'
    )
    wrapper.chmod(0o700)
    return wrapper


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _probe(
    shell: list[str],
    tools: dict[str, str],
    context: Path,
    mode: str,
    *arguments: str | Path,
) -> subprocess.CompletedProcess[bytes]:
    tool = tools["sh"] if mode == "acquire-shell" else tools["awk"]
    return subprocess.run(
        [
            *shell,
            str(Path(__file__).resolve().parents[1] / "modules/helpers/probe.sh"),
            mode,
            tool,
            str(context),
            *map(str, arguments),
        ],
        check=False,
        capture_output=True,
        timeout=3,
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
    )


def test_acquire_manifest_and_entry_probes_enforce_exact_version(
    shell: list[str], native_tools: dict[str, str], package: Path, tmp_path: Path
) -> None:
    context = tmp_path / "probe-context"
    context.mkdir(mode=0o700)
    manifest = package / "manifest.txt"
    accepted = _probe(
        shell, native_tools, context, "acquire-manifest", manifest, "0.1.0"
    )
    assert accepted.returncode == 0, accepted.stderr.decode(errors="replace")
    assert accepted.stdout.splitlines()[0].split(b"\t")[3] == b"catalog.txt"

    bad_manifest = context / "bad-manifest.txt"
    bad_manifest.write_bytes(manifest.read_bytes().replace(b" 1 1\n", b" 2 1\n", 1))
    rejected = _probe(
        shell, native_tools, context, "acquire-manifest", bad_manifest, "0.1.0"
    )
    assert rejected.returncode != 0

    manifest_bytes = manifest.read_bytes()
    lines = manifest_bytes.splitlines(keepends=True)
    helper = b"modules/lib/acquire.sh"
    unsafe_path = manifest_bytes.replace(b"catalog.txt", b"../catalog.txt", 1)
    missing_helper = b"".join(line for line in lines if helper not in line)
    incompatible_schema = manifest_bytes.replace(
        b"CFMGR-MANIFEST 2 0.1.0 1 1", b"CFMGR-MANIFEST 2 0.1.0 1 2", 1
    )
    malformed = b"<html>not a package manifest</html>\n"
    for name, content in (
        ("unsafe-path", unsafe_path),
        ("missing-helper", missing_helper),
        ("config-schema", incompatible_schema),
        ("html", malformed),
    ):
        candidate_manifest = context / f"{name}.txt"
        candidate_manifest.write_bytes(content)
        rejected_case = _probe(
            shell,
            native_tools,
            context,
            "acquire-manifest",
            candidate_manifest,
            "0.1.0",
        )
        assert rejected_case.returncode != 0, f"accepted invalid manifest case: {name}"

    entry = package / "cfmgr.sh"
    accepted_entry = _probe(
        shell, native_tools, context, "acquire-entry", entry, "0.1.0"
    )
    assert accepted_entry.returncode == 0
    duplicate = context / "duplicate-version.sh"
    duplicate.write_bytes(entry.read_bytes() + b"\nCFMGR_VERSION=0.1.0\n")
    rejected_entry = _probe(
        shell, native_tools, context, "acquire-entry", duplicate, "0.1.0"
    )
    assert rejected_entry.returncode != 0
    wrong_version = context / "wrong-version.sh"
    wrong_version.write_bytes(
        entry.read_bytes().replace(b"CFMGR_VERSION=0.1.0", b"CFMGR_VERSION=9.9.9", 1)
    )
    rejected_version = _probe(
        shell, native_tools, context, "acquire-entry", wrong_version, "0.1.0"
    )
    assert rejected_version.returncode != 0


def test_acquire_awk_probe_parses_candidate_without_running_it(
    shell: list[str], native_tools: dict[str, str], tmp_path: Path
) -> None:
    context = tmp_path / "probe-context"
    context.mkdir(mode=0o700)
    marker = tmp_path / "candidate-ran"
    prefix = context / "acquire.syntax.awk"
    candidate = context / "candidate.awk"
    prefix.write_text(
        'BEGIN { print "CFMGR-AWK-PARSED 1"; fflush(); print 1/(NR-NR) }\n'
    )
    candidate.write_text(
        f'BEGIN {{ print "begin" > "{marker}" }}\nEND {{ print "end" > "{marker}" }}\n'
    )
    valid = _probe(shell, native_tools, context, "acquire-awk", prefix, candidate)
    assert valid.returncode != 0
    assert valid.stdout.splitlines() == [b"CFMGR-AWK-PARSED 1"]
    assert b"division by zero" in valid.stderr.lower()
    assert not marker.exists()

    candidate.write_text(
        f'BEGIN {{ print "begin" > "{marker}" }}\nthis is invalid !!!\n'
    )
    malformed = _probe(shell, native_tools, context, "acquire-awk", prefix, candidate)
    assert malformed.returncode != 0
    assert b"CFMGR-AWK-PARSED 1" not in malformed.stdout
    assert not marker.exists()

    bad_shell = context / "candidate.sh"
    bad_shell.write_text("if then\n")
    shell_result = _probe(shell, native_tools, context, "acquire-shell", bad_shell)
    assert shell_result.returncode != 0


def _native_fetch(
    shell: list[str],
    native_tools: dict[str, str],
    context: Path,
    ca: Path,
    curl: Path,
    url_mode: str,
    url: str,
    destination: Path,
    maximum: int,
    *,
    deadline_seconds: int = 30,
) -> subprocess.CompletedProcess[bytes]:
    root = Path(__file__).resolve().parents[1]
    capath = context / "capath"
    capath.mkdir(exist_ok=True)
    source = r"""
root=$1 context=$2 ca=$3 curl=$4 capath=$5
shift 5
. "$root/modules/helpers/bootstrap.sh"
. "$root/modules/lib/prerequisites.sh"
. "$root/modules/lib/native.sh"
. "$root/modules/lib/acquire.sh"
cfmgr_install_source=$root cfmgr_install_context=$context
cfmgr_install_sh=$1 cfmgr_install_env=$2 cfmgr_install_awk=$3
cfmgr_install_sleep=$4 cfmgr_install_wc=$5 cfmgr_install_ls=$6
cfmgr_install_chmod=$7 cfmgr_install_mkdir=$8
shift 8
url_mode=$1 url=$2 destination=$3 maximum=$4 deadline_seconds=$5
shift 5
cfmgr_native_context=$capath cfmgr_native_ca=$ca cfmgr_native_curl=$curl
IFS=' ' read -r uptime _ </proc/uptime
cfmgr_native_ready=1 cfmgr_acquire_active=1 cfmgr_acquire_deadline=$((${uptime%%.*}+deadline_seconds))
cfmgr_acquire_attached() { [ -d "$cfmgr_install_context" ] && [ "$cfmgr_acquire_active" = 1 ]; }
cfmgr_prerequisites_attachment_ok() { return 0; }
cfmgr_native_action() { cfmgr_acquire_native_action "$@"; }
PLACEHOLDER
if cfmgr_acquire_fetch "$url_mode" "$url" "$destination" "$maximum"; then status=0; else status=$?; fi
[ "$cfmgr_probe_status" = reaped ] || exit 91
exit "$status"
"""
    source = source.replace("PLACEHOLDER", pause_definition(shell))
    command = subprocess.run(
        [
            *shell,
            "-c",
            source,
            "acquire-fetch",
            str(root),
            str(context),
            str(ca),
            str(curl),
            str(capath),
            native_tools["sh"],
            native_tools["env"],
            native_tools["awk"],
            native_tools["sleep"],
            native_tools["wc"],
            native_tools["ls"],
            native_tools["chmod"],
            native_tools["mkdir"],
            url_mode,
            url,
            str(destination),
            str(maximum),
            str(deadline_seconds),
        ],
        check=False,
        capture_output=True,
        timeout=10,
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": "", "OPENSSL_CONF": "/dev/null"},
    )
    return command


@pytest.mark.skipif(
    sys.platform != "linux", reason="requires the production /proc child supervisor"
)
def test_acquire_get_enforces_tls_headers_status_bounds_and_reaps_children(
    shell: list[str],
    native_tools: dict[str, str],
    tls_material: Path,
    acquire_tls_server: tuple[int, ServerState],
    package: Path,
    tmp_path: Path,
) -> None:
    port, state = acquire_tls_server
    owner, repo, branch = "fixture-owner", "fixture-repo", "moving/branch"
    revision = "0123456789abcdef0123456789abcdef01234567"
    routes = package_responses(package, owner, repo, branch, revision)
    api_path = f"/repos/{owner}/{repo}/commits/{branch}"
    routes[api_path] = {"body": revision.encode()}
    reset_routes(state, routes)
    curl = routed_curl(native_tools["curl"], port, tmp_path)
    context = tmp_path / "acquire-context"
    context.mkdir(mode=0o700)
    api_context = context / "api"
    api_context.mkdir(mode=0o700)
    sha_file = api_context / "sha"
    api = _native_fetch(
        shell,
        native_tools,
        api_context,
        tls_material / "trusted.pem",
        curl,
        "api",
        f"https://api.github.com{api_path}",
        sha_file,
        41,
    )
    assert api.returncode == 0, api.stderr.decode(errors="replace")
    assert sha_file.read_bytes() == revision.encode()
    with state["lock"]:
        api_requests = [
            headers for path, headers in state["requests"] if path == api_path
        ]
    assert len(api_requests) == 1
    assert api_requests[0].get("Accept") == "application/vnd.github.sha"
    assert api_requests[0].get("X-GitHub-Api-Version") == "2022-11-28"

    raw_context = context / "raw"
    raw_context.mkdir(mode=0o700)
    manifest = raw_context / "manifest"
    raw = _native_fetch(
        shell,
        native_tools,
        raw_context,
        tls_material / "trusted.pem",
        curl,
        "raw",
        f"https://raw.githubusercontent.com/{owner}/{repo}/{revision}/manifest.txt",
        manifest,
        131072,
    )
    assert raw.returncode == 0, raw.stderr.decode(errors="replace")
    assert manifest.read_bytes() == (package / "manifest.txt").read_bytes()
    paths = request_paths(state)
    assert paths == [api_path, f"/{owner}/{repo}/{revision}/manifest.txt"]

    routes[api_path] = {
        "status": 302,
        "headers": {
            "Location": f"https://raw.githubusercontent.com/{owner}/{repo}/{revision}/manifest.txt"
        },
        "body": b"redirect\n",
    }
    reset_routes(state, routes)
    redirect_context = context / "redirect"
    redirect_context.mkdir(mode=0o700)
    rejected = _native_fetch(
        shell,
        native_tools,
        redirect_context,
        tls_material / "trusted.pem",
        curl,
        "api",
        f"https://api.github.com{api_path}",
        redirect_context / "body",
        41,
    )
    assert rejected.returncode != 0
    assert request_paths(state) == [api_path]

    routes[api_path] = {
        "body": b"short",
        "headers": {"Content-Length": "20"},
    }
    reset_routes(state, routes)
    incomplete_context = context / "incomplete"
    incomplete_context.mkdir(mode=0o700)
    incomplete = _native_fetch(
        shell,
        native_tools,
        incomplete_context,
        tls_material / "trusted.pem",
        curl,
        "api",
        f"https://api.github.com{api_path}",
        incomplete_context / "body",
        41,
    )
    assert incomplete.returncode != 0
    assert request_paths(state) == [api_path]

    routes[api_path] = {"body": b"x" * 128, "chunked": True}
    reset_routes(state, routes)
    oversized_context = context / "oversized"
    oversized_context.mkdir(mode=0o700)
    oversized = _native_fetch(
        shell,
        native_tools,
        oversized_context,
        tls_material / "trusted.pem",
        curl,
        "api",
        f"https://api.github.com{api_path}",
        oversized_context / "body",
        8,
    )
    assert oversized.returncode != 0
    assert request_paths(state) == [api_path]

    routes[api_path] = {"body": b"slow", "delay": 3}
    reset_routes(state, routes)
    deadline_context = context / "deadline"
    deadline_context.mkdir(mode=0o700)
    started = time.monotonic()
    deadline = _native_fetch(
        shell,
        native_tools,
        deadline_context,
        tls_material / "trusted.pem",
        curl,
        "api",
        f"https://api.github.com{api_path}",
        deadline_context / "body",
        41,
        deadline_seconds=2,
    )
    elapsed = time.monotonic() - started
    assert deadline.returncode != 0
    assert elapsed < 3
    assert request_paths(state) == [api_path]
