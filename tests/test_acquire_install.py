"""One pinned HTTPS snapshot through trusted acquisition and the real installer.

Only Merlin root/tool admission and Entware discovery are fixture adapters.
Acquisition orchestration, verification, native child supervision, source/stage
FDs, fixed probes, package transaction and cleanup are production functions.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from test_acquire import acquire_tls_cert as acquire_cert
from test_acquire import acquire_tls_server as acquire_server
from test_acquire import base_tools as acquire_base_tools
from test_acquire import host_mv_profile as acquire_mv_profile
from test_acquire import native_tools as acquire_native_tools
from test_acquire import package as acquire_package
from test_acquire import package_responses, request_paths, reset_routes, routed_curl
from test_acquire import shell as acquire_shell
from test_acquire import tls_material as acquire_tls_material
from test_install import legacy_fsync as install_fsync
from test_install import snapshot
from test_prerequisites import pause_definition

ROOT = Path(__file__).resolve().parents[1]
shell = acquire_shell
base_tools = acquire_base_tools
host_mv_profile = acquire_mv_profile
native_tools = acquire_native_tools
tls_material = acquire_tls_material
package = acquire_package
acquire_tls_cert = acquire_cert
acquire_tls_server = acquire_server
legacy_fsync = install_fsync

pytestmark = pytest.mark.skipif(
    sys.platform != "linux",
    reason="real acquisition stage/source FDs and supervisor require Linux proc",
)


def candidate(
    package: Path,
    target: Path,
    *,
    version="9.8.7",
    fault=None,
    marker: Path | None = None,
) -> Path:
    shutil.copytree(package, target)
    entry = target / "cfmgr.sh"
    entry.write_bytes(
        entry.read_bytes().replace(
            b"CFMGR_VERSION=0.1.0\n", f"CFMGR_VERSION={version}\n".encode(), 1
        )
    )
    catalog = target / "catalog.txt"
    catalog.write_bytes(
        catalog.read_bytes().replace(
            b"CFMGR-CATALOG 1 0.1.0\n", f"CFMGR-CATALOG 1 {version}\n".encode(), 1
        )
    )
    if marker is not None:
        # If a candidate entry/bootstrap/probe is used as a verifier/import,
        # even a self-consistent package exposes it before any installation.
        payload = f"printf 'candidate executed\\n' >> '{marker}'\n".encode()
        for relative in (
            "cfmgr.sh",
            "modules/helpers/bootstrap.sh",
            "modules/helpers/probe.sh",
        ):
            item = target / relative
            data = item.read_bytes()
            item.write_bytes(
                data[: data.index(b"\n") + 1] + payload + data[data.index(b"\n") + 1 :]
            )
    if fault == "syntax":
        script = target / "modules/helpers/bootstrap.sh"
        script.write_bytes(script.read_bytes() + b"\ncase\n")
    rows = [f"CFMGR-MANIFEST 2 {version} {2 if fault == 'abi' else 1} 1"]
    files = sorted(
        [
            item
            for item in target.rglob("*")
            if item.is_file() and item.name != "manifest.txt"
        ],
        key=lambda item: item.relative_to(target).as_posix(),
    )
    for item in files:
        body = item.read_bytes()
        rows.append(
            f"{item.stat().st_mode & 0o777:04o}\t{len(body)}\t{hashlib.sha256(body).hexdigest()}\t{item.relative_to(target).as_posix()}"
        )
    (target / "manifest.txt").write_text("\n".join(rows) + "\n")
    if fault == "hash":
        # Same-size valid shell/comment/version, so size/catalog/syntax checks
        # cannot substitute for the independent acquired-byte digest gate.
        entry.write_bytes(
            entry.read_bytes().replace(b"# shellcheck", b"# Shellcheck", 1)
        )
    return target


CONSUMER = r"""
root=$1 fixture=$2 fixture_curl=$3 fixture_ca=$4 fixture_fsync=$5 fixture_owner=$6
shift 6
. "$root/modules/lib/storage.sh"
. "$root/modules/lib/prerequisites.sh"
. "$root/modules/lib/native.sh"
. "$root/modules/helpers/bootstrap.sh"
. "$root/modules/lib/acquire.sh"
# CFMGR_TEST_PAUSE
CFMGR_VERSION=0.1.0 CFMGR_REPOSITORY=https://github.com/fixture-owner/fixture-repo CFMGR_BRANCH=moving/branch
cfmgr_bootstrap_native_prepare() {
    cfmgr_install_source=$root cfmgr_install_jffs=$fixture/jffs cfmgr_install_opt=$fixture/opt
    cfmgr_install_owner=$fixture_owner cfmgr_install_private_context=$fixture/ram/acquire
    cfmgr_install_context=$cfmgr_install_private_context cfmgr_install_context_fd=0 cfmgr_install_source_fd=9
    cfmgr_install_sh=$TEST_SH cfmgr_install_env=$TEST_ENV cfmgr_install_awk=$TEST_AWK
    cfmgr_install_readlink=$TEST_READLINK cfmgr_install_sleep=$TEST_SLEEP cfmgr_install_wc=$TEST_WC
    cfmgr_install_ls=$TEST_LS cfmgr_install_mkdir=$TEST_MKDIR cfmgr_install_cp=$TEST_CP
    cfmgr_install_chmod=$TEST_CHMOD cfmgr_install_mv=$TEST_MV cfmgr_install_df=$TEST_DF
    cfmgr_install_sha=$TEST_SHA256SUM cfmgr_install_jq=$TEST_JQ cfmgr_install_fsync=$fixture_fsync
    mkdir -m 700 "$cfmgr_install_context" || return 1
    exec 0<"$cfmgr_install_context" 8<"$cfmgr_install_jffs" 9<"$root"
    cfmgr_install_tmp_snapshot=$("$TEST_AWK" -f "$root/modules/lib/mountinfo.awk" "$cfmgr_install_context" /proc/self/mountinfo) || return 1
    cfmgr_install_jffs_snapshot=$("$TEST_AWK" -f "$root/modules/lib/mountinfo.awk" "$cfmgr_install_jffs" /proc/self/mountinfo) || return 1
    cfmgr_install_interrupted=0 cfmgr_probe_pid='' cfmgr_probe_serial=0 cfmgr_probe_status=invalid
    umask 077
    cfmgr_bootstrap_signals
}
cfmgr_acquire_admit() {
    cfmgr_native_curl=$fixture_curl cfmgr_native_openssl=$TEST_OPENSSL cfmgr_native_ca=$fixture_ca
    cfmgr_native_acquire_check "$cfmgr_install_context" "$cfmgr_native_curl" "$cfmgr_native_openssl" "$cfmgr_native_ca" || return $?
    printf abc > "$cfmgr_install_context/acquire.vector"
    cfmgr_acquire_digest "$cfmgr_install_context/acquire.vector" || return $?
    [ "$cfmgr_acquire_digest" = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]
}
cfmgr_bootstrap_native() {
    printf 'installer entered\n' > "$fixture/installer-entered"
    [ "$cfmgr_acquire_active" = 0 ] && [ -z "${cfmgr_acquire_deadline:-}" ] || return 90
    [ "$CFMGR_VERSION" = 9.8.7 ] || return 91
    fixture_source=$1 fixture_context=$fixture/ram/install
    mkdir -m 700 "$fixture_context" || return 92
    # Independent installer pins replace the child's inherited source/stage
    # FDs. The parent's stage6 pin must survive these child-local changes.
    exec 9<"$fixture_source" 6<"$fixture/opt" 7<"$fixture/opt" 5<"$fixture_context" 0<&-
    cfmgr_install_context_fd=5
    cfmgr_bootstrap_transaction "$fixture_source" "$fixture/jffs" "$fixture/opt" "$fixture_context" "$fixture_owner" \
        "$TEST_SH" "$TEST_ENV" "$TEST_AWK" "$TEST_READLINK" "$TEST_SLEEP" "$TEST_WC" "$TEST_LS" "$fixture_fsync" \
        "$TEST_MKDIR" "$TEST_CP" "$TEST_CHMOD" "$TEST_MV" "$TEST_SHA256SUM" "$TEST_JQ" \
        01234567-89ab-cdef-0123-456789abcdef ext4 / entware "$TEST_DF"
}
cfmgr_bootstrap_attached() {
    [ "$cfmgr_install_interrupted" = 0 ] && [ "$cfmgr_install_source" -ef /proc/self/fd/9 ] &&
        [ "$cfmgr_install_jffs" -ef /proc/self/fd/8 ] && [ "$cfmgr_install_opt" -ef /proc/self/fd/7 ]
}
cfmgr_acquire_native "$root"
"""


def run_consumer(shell, tools, fsync, fixture, curl, ca):
    environment = {
        **os.environ,
        "LC_ALL": "C",
        "LANGUAGE": "",
        "CFMGR_FSYNC_FAULT": "clean",
    }
    environment.update({f"TEST_{key.upper()}": value for key, value in tools.items()})
    return subprocess.run(
        [
            *shell,
            "-c",
            CONSUMER.replace("# CFMGR_TEST_PAUSE", pause_definition(shell), 1),
            "acquire-install",
            ROOT,
            fixture,
            curl,
            ca,
            fsync,
            str(os.getuid()),
        ],
        env=environment,
        capture_output=True,
        check=False,
        timeout=220,
    )


def roots(path: Path) -> Path:
    for child in ("jffs", "opt", "ram"):
        (path / child).mkdir(mode=0o700, parents=True)
    return path


def test_pinned_https_snapshot_reaches_real_installer_then_retained_guard_blocks_fetch(
    shell,
    native_tools,
    package,
    legacy_fsync,
    tls_material,
    acquire_tls_server,
    tmp_path,
):
    port, state = acquire_tls_server
    upstream = candidate(package, tmp_path / "upstream")
    revision = "0123456789abcdef0123456789abcdef01234567"
    later = "abcdef0123456789abcdef0123456789abcdef01"
    routes = package_responses(
        upstream, "fixture-owner", "fixture-repo", "moving/branch", revision
    )
    api = "/repos/fixture-owner/fixture-repo/commits/moving/branch"
    routes[api] = [
        {"body": revision.encode()},
        {"body": (later + "\n").encode()},
    ]
    reset_routes(state, routes)
    curl = routed_curl(native_tools["curl"], port, tmp_path)
    fixture = roots(tmp_path / "router")
    fsync = native_tools.get("fsync", str(legacy_fsync))
    result = run_consumer(
        shell, native_tools, fsync, fixture, curl, tls_material / "trusted.pem"
    )
    assert result.returncode == 0, (result.stdout, result.stderr[-6000:])
    assert result.stdout == result.stderr == b""
    support = fixture / "jffs/addons/CFMgr.d"
    assert (fixture / "jffs/scripts/cfmgr.sh").read_bytes() == (
        upstream / "cfmgr.sh"
    ).read_bytes()
    assert (support / "setup-state").read_bytes() == b"CFMGR-SETUP 1 9.8.7 complete\n"
    assert (support / "manifest.txt").read_bytes() == (
        upstream / "manifest.txt"
    ).read_bytes()
    assert (fixture / "installer-entered").exists()
    data = json.loads((support / "config").read_bytes())
    assert data["manager"]["source"] == {
        "repository": "https://github.com/fixture-owner/fixture-repo",
        "branch": "moving/branch",
        "commit": "",
    }
    for feature in ("ddns", "ip_sync", "cloudflared"):
        assert not data[feature]["configured"] and not data[feature]["enabled"]
    assert data["backup"]["destination"] is None
    for row in (upstream / "manifest.txt").read_text().splitlines()[1:]:
        mode, _size, _digest, relative = row.split("\t")
        installed = (
            fixture / "jffs/scripts/cfmgr.sh"
            if relative == "cfmgr.sh"
            else support / relative
        )
        assert installed.read_bytes() == (upstream / relative).read_bytes()
        assert installed.stat().st_mode & 0o777 == int(mode, 8)
    assert not (fixture / "ram/acquire").exists(), (
        "Parent must clean its pinned acquired stage after the installer repins FD6/7"
    )
    paths = request_paths(state)
    assert paths.count(api) == 1
    assert all(
        path == api or path.startswith(f"/fixture-owner/fixture-repo/{revision}/")
        for path in paths
    )
    assert len(paths) == len((upstream / "manifest.txt").read_text().splitlines()) + 1
    before = snapshot(fixture / "jffs")
    reset_routes(state, routes)
    repeated = run_consumer(
        shell, native_tools, fsync, fixture, curl, tls_material / "trusted.pem"
    )
    assert repeated.returncode != 0 and request_paths(state) == []
    assert snapshot(fixture / "jffs") == before


@pytest.mark.parametrize("fault", ["abi", "syntax", "hash"])
def test_rejected_package_never_executes_candidate_code(
    shell,
    native_tools,
    package,
    legacy_fsync,
    tls_material,
    acquire_tls_server,
    tmp_path,
    fault,
):
    port, state = acquire_tls_server
    marker = tmp_path / "candidate-executed"
    upstream = candidate(package, tmp_path / "upstream", fault=fault, marker=marker)
    revision = "0123456789abcdef0123456789abcdef01234567"
    reset_routes(
        state,
        package_responses(
            upstream, "fixture-owner", "fixture-repo", "moving/branch", revision
        ),
    )
    curl = routed_curl(native_tools["curl"], port, tmp_path)
    fixture = roots(tmp_path / "router")
    result = run_consumer(
        shell,
        native_tools,
        native_tools.get("fsync", str(legacy_fsync)),
        fixture,
        curl,
        tls_material / "trusted.pem",
    )
    assert result.returncode != 0, (result.stdout, result.stderr)
    assert not marker.exists()
    assert not (fixture / "installer-entered").exists()
    assert list((fixture / "jffs").iterdir()) == []
    assert list((fixture / "opt").iterdir()) == []
    assert not (fixture / "ram/acquire").exists()
    paths = request_paths(state)
    assert paths.count("/repos/fixture-owner/fixture-repo/commits/moving/branch") == 1
    if fault == "abi":
        assert len(paths) == 2
        assert b"incompatible manifest format" in result.stderr
