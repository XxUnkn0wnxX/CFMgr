"""Offline native admission plus the same secure policy against private local TLS."""

from __future__ import annotations

import http.server
import os
import shutil
import ssl
import subprocess
import sys
import threading
from pathlib import Path

import pytest
from test_install import HOST_TRANSACTION, ROOT
from test_install import install as host_install
from test_install import legacy_fsync as install_fsync
from test_install import package as install_package
from test_install import tools as install_tools
from test_prerequisites import REQUIRE_BUSYBOX, pause_definition
from test_prerequisites import shell as prerequisite_shell

shell = prerequisite_shell
base_tools = install_tools
legacy_fsync = install_fsync
package = install_package
NATIVE = ROOT / "modules/lib/native.sh"


@pytest.fixture(scope="module")
def native_tools(
    base_tools: dict[str, str],
    shell: list[str],
    tmp_path_factory: pytest.TempPathFactory,
) -> dict[str, str]:
    result = dict(base_tools)
    for name in ("curl", "openssl", "rmdir"):
        actual = shutil.which(name)
        assert actual, f"Actual developer {name} is required for TLS capability proof"
        result[name] = actual
    if REQUIRE_BUSYBOX:
        directory = tmp_path_factory.mktemp("native-vendor-applets")
        for name in (
            "env",
            "awk",
            "wc",
            "ls",
            "mkdir",
            "cp",
            "chmod",
            "mv",
            "rmdir",
            "fsync",
        ):
            target = directory / name
            target.symlink_to(Path(shell[0]).resolve())
            result[name] = str(target)
    return result


@pytest.fixture(scope="module")
def tls_material(
    native_tools: dict[str, str], tmp_path_factory: pytest.TempPathFactory
) -> Path:
    directory = tmp_path_factory.mktemp("synthetic-native-tls")
    openssl = native_tools["openssl"]

    def command(*arguments: str) -> None:
        subprocess.run(
            [openssl, *arguments],
            cwd=directory,
            check=True,
            capture_output=True,
            timeout=5,
            env={"PATH": os.defpath, "OPENSSL_CONF": "/dev/null"},
        )

    for name in ("trusted", "untrusted"):
        command(
            "req",
            "-x509",
            "-newkey",
            "ec",
            "-pkeyopt",
            "ec_paramgen_curve:prime256v1",
            "-nodes",
            "-keyout",
            f"{name}.key",
            "-out",
            f"{name}.pem",
            "-days",
            "1",
            "-subj",
            f"/CN=CFMgr synthetic {name}",
            "-addext",
            "basicConstraints=critical,CA:TRUE",
        )
    command(
        "req",
        "-new",
        "-newkey",
        "ec",
        "-pkeyopt",
        "ec_paramgen_curve:prime256v1",
        "-nodes",
        "-keyout",
        "server.key",
        "-out",
        "server.csr",
        "-subj",
        "/CN=127.0.0.1",
    )
    (directory / "extensions").write_text("subjectAltName=IP:127.0.0.1\n")
    command(
        "x509",
        "-req",
        "-in",
        "server.csr",
        "-CA",
        "trusted.pem",
        "-CAkey",
        "trusted.key",
        "-CAcreateserial",
        "-out",
        "server.pem",
        "-days",
        "1",
        "-extfile",
        "extensions",
    )
    return directory


@pytest.fixture(scope="module")
def tls_server(tls_material: Path):
    class Handler(http.server.BaseHTTPRequestHandler):
        requests = 0

        def do_HEAD(self) -> None:
            type(self).requests += 1
            if self.path == "/redirect":
                self.send_response(302)
                self.send_header("Location", "/redirect-target")
            else:
                self.send_response(200)
            self.end_headers()

        def log_message(self, *_arguments: object) -> None:
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(tls_material / "server.pem", tls_material / "server.key")
    server.socket = context.wrap_socket(server.socket, server_side=True)
    thread = threading.Thread(
        target=server.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True
    )
    thread.start()
    try:
        yield server.server_port, Handler
    finally:
        server.shutdown()
        thread.join(timeout=2)
        server.server_close()
        assert not thread.is_alive(), "Owned TLS fixture thread failed to stop"


HOST_SUPERVISOR = (
    "cfmgr_prerequisites_run() {"
    + HOST_TRANSACTION.split("cfmgr_prerequisites_run() {", 1)[1].split(
        "cfmgr_test_install() {", 1
    )[0]
)


def native_invoke(
    shell: list[str],
    native_tools: dict[str, str],
    fsync: Path,
    context: Path,
    ca: Path,
    body: str,
    *arguments: str | Path,
) -> subprocess.CompletedProcess[bytes]:
    context.mkdir(mode=0o700)
    keys = (
        "sh",
        "env",
        "awk",
        "sleep",
        "wc",
        "ls",
        "mkdir",
        "cp",
        "chmod",
        "mv",
        "timeout",
    )
    setup = r"""
root=$1 cfmgr_install_context=$2 test_curl=$3 test_openssl=$4 test_ca=$5
shift 5
cfmgr_install_sh=$1 cfmgr_install_env=$2 cfmgr_install_awk=$3 cfmgr_install_sleep=$4
cfmgr_install_wc=$5 cfmgr_install_ls=$6 cfmgr_install_mkdir=$7 cfmgr_install_cp=$8 cfmgr_install_chmod=$9
shift 9
cfmgr_install_mv=$1 cfmgr_test_timeout=$2 cfmgr_install_fsync=$3
shift 3
cfmgr_install_source=$root cfmgr_install_jffs=$cfmgr_install_context cfmgr_install_opt=$cfmgr_install_context
cfmgr_test_fault=clean cfmgr_test_detached=0 cfmgr_probe_serial=0
. "$root/modules/helpers/bootstrap.sh"
. "$root/modules/lib/prerequisites.sh"
. "$root/modules/lib/native.sh"
cfmgr_bootstrap_attached() { return 0; }
cfmgr_prerequisites_attachment_ok() { return 0; }
"""
    setup += pause_definition(shell)
    if sys.platform != "linux":
        # Host adapter replaces unavailable /proc ownership only. Mandatory CI
        # exercises the real supervisor and selected vendor mutation applets.
        setup += HOST_SUPERVISOR.replace(
            "LANGUAGE= CFMGR_FSYNC_FAULT=",
            "LANGUAGE= OPENSSL_CONF=/dev/null CFMGR_FSYNC_FAULT=",
        )
    return subprocess.run(
        [
            *shell,
            "-c",
            setup + body,
            "native-test",
            str(ROOT),
            str(context),
            native_tools["curl"],
            native_tools["openssl"],
            str(ca),
            *(native_tools[key] for key in keys),
            native_tools.get("fsync", str(fsync)),
            *map(str, arguments),
        ],
        check=False,
        capture_output=True,
        timeout=15,
        env={**os.environ, "LC_ALL": "C", "LANGUAGE": ""},
    )


def test_source_is_inert(shell: list[str], tmp_path: Path) -> None:
    result = subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; [ "$PWD" = "$2" ]',
            "native-source",
            str(NATIVE),
            str(ROOT),
        ],
        cwd=ROOT,
        check=False,
        capture_output=True,
        timeout=2,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert list(tmp_path.iterdir()) == []


def test_offline_admission_and_fixed_tls_policy(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tls_server,
    tmp_path: Path,
) -> None:
    port, handler = tls_server
    before = handler.requests
    body = r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca" || { printf '%s\n' "$cfmgr_native_reason"; exit 10; }
[ "$cfmgr_native_ready" = 1 ] && [ ! -e "$cfmgr_install_context/native.directory" ] || exit 11
# The only request below is the explicit caller-selected local HTTPS operation.
HOME=$1 CURL_HOME=$1 CURL_CA_BUNDLE=$2 SSL_CERT_FILE=$2 SSL_CERT_DIR=$1
OPENSSL_CONF=$1/openssl.cnf http_proxy=http://127.0.0.1:9 https_proxy=http://127.0.0.1:9 ALL_PROXY=http://127.0.0.1:9
export HOME CURL_HOME CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR OPENSSL_CONF http_proxy https_proxy ALL_PROXY
cfmgr_native_https "$3" || exit 12
cfmgr_native_https "${3}redirect" || exit 16
[ "$cfmgr_native_status" = 302 ] || exit 17
cfmgr_native_https "$4" && exit 13
cfmgr_native_ca=$2
cfmgr_native_https "$3" && exit 14
cfmgr_native_ca=$1/invalid.pem
cfmgr_native_https "$3" && exit 15
exit 0
"""
    contaminants = tmp_path / "contaminants"
    contaminants.mkdir()
    (contaminants / ".curlrc").write_text("insecure\nproxy = http://127.0.0.1:9\n")
    (contaminants / "openssl.cnf").write_text("invalid OpenSSL configuration [\n")
    (contaminants / "invalid.pem").write_text("invalid trust\n")
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        body,
        contaminants,
        tls_material / "untrusted.pem",
        f"https://127.0.0.1:{port}/",
        f"https://localhost:{port}/",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert handler.requests == before + 2, (
        "TLS failures and unfollowed redirects must not produce extra HEAD requests"
    )


def test_offline_admission_never_connects(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
) -> None:
    # Actual curl resolves options and rejects HTTP without opening a socket.
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca"
""",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    receipts = list((tmp_path / "context").glob("native-curl-offline.*.out"))
    assert len(receipts) == 1 and receipts[0].read_bytes() == b"000\n"
    assert not list((tmp_path / "context").glob("native-curl-https.*"))


@pytest.mark.parametrize("damage", ["zero", "base64", "der", "der-tail", "truncated"])
def test_bad_ca_fails_offline_before_mutation(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
    damage: str,
) -> None:
    certificate = (tls_material / "trusted.pem").read_text()
    values = {
        "zero": "# no certificates\n",
        "base64": "-----BEGIN CERTIFICATE-----\n?AAA\n-----END CERTIFICATE-----\n",
        "der": "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n",
        "der-tail": certificate
        + "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n",
        "truncated": certificate.removesuffix("-----END CERTIFICATE-----\n"),
    }
    ca = tmp_path / "invalid.pem"
    ca.write_text(values[damage])
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        ca,
        r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca"
status=$?
[ "$status" = 1 ] && [ "$cfmgr_native_ready" = 0 ] && [ ! -e "$cfmgr_install_context/native.source" ]
""",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    if damage in ("der", "der-tail"):
        assert list((tmp_path / "context").glob("native-ca-decode.*.err")), (
            "Must reach actual native DER decoding"
        )


def test_capath_rechecked_and_colon_rejected(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
) -> None:
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca" || exit 10
set -f
ln -s "$test_ca" "$cfmgr_install_context/deadbeef.0"
cfmgr_native_https https://127.0.0.1:9/ && exit 11
[ "$cfmgr_native_reason" = capath ] || exit 12
cfmgr_native_check "$cfmgr_install_context:other" "$test_curl" "$test_openssl" "$test_ca"
[ "$?" = 2 ]
""",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert not list((tmp_path / "context").glob("native-curl-https.*"))


def test_native_supervisor_clears_loader_before_env_startup(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
) -> None:
    if sys.platform != "linux":
        pytest.skip("Loader-before-env proof requires actual Linux native supervisor")
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        r"""
export LD_PRELOAD=/cfmgr-nonexistent-preload LD_LIBRARY_PATH=/cfmgr-nonexistent-library
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca" || exit 10
exit 0
""",
    )
    assert result.returncode == 0 and result.stdout == b""
    # Native ash external controller tests can report the intentionally missing
    # loader input before the launch boundary; the trusted public entry clears
    # it earlier. Every actual supervised executable must have clean stderr.
    for output in (tmp_path / "context").glob("*.err"):
        if output.name.startswith("native-curl-offline."):
            assert b"protocol" in output.read_bytes().lower()
        else:
            assert output.read_bytes() == b""
    assert b"cfmgr-nonexistent-preload" not in b"".join(
        output.read_bytes() for output in (tmp_path / "context").glob("*.err")
    )


def test_preexisting_scratch_directory_is_preserved(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
) -> None:
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        r"""
mkdir "$cfmgr_install_context/native.directory"
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca"
[ "$?" = 2 ] && [ -d "$cfmgr_install_context/native.directory" ] && [ "$cfmgr_native_reason" = context-not-fresh ]
""",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert not list((tmp_path / "context").glob("native-curl-version.*"))


def test_bad_status_framing_and_userinfo_never_pass(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
) -> None:
    wrapper = tmp_path / "bad-curl"
    wrapper.write_text("#!/bin/sh\ncat bad-status\n")
    wrapper.chmod(0o755)
    payloads = [b"200\nextra\n", b"200\ntrailing", b"200\n\x00", b"200", b"200\x00\n"]
    files = []
    for index, payload in enumerate(payloads):
        filename = tmp_path / f"status-{index}"
        filename.write_bytes(payload)
        files.append(filename)
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca" || exit 10
cfmgr_native_https https://user@127.0.0.1:9/; [ "$?" = 2 ] || exit 11
cfmgr_native_curl=$1; shift
for status_file do
    cp "$status_file" "$cfmgr_install_context/bad-status"
    cfmgr_native_https https://127.0.0.1:9/ && exit 12
done
exit 0
""",
        wrapper,
        *files,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


def test_native_work_failed_admission_never_reaches_transaction(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tmp_path: Path,
) -> None:
    ca = tmp_path / "zero-certificate.pem"
    ca.write_text("# zero certificates\n")
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        ca,
        r"""
cfmgr_bootstrap_retained() { return 0; }
# Private adapter supplies host paths; the real installer controller and native
# check run unchanged, without pretending host tests prove firmware admission.
cfmgr_bootstrap_native_admission() {
    cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca"
}
cfmgr_bootstrap_transaction() { printf unexpected >"$cfmgr_install_context/transaction"; }
cfmgr_bootstrap_native_work
status=$?
[ "$status" = 1 ] && [ "$cfmgr_native_reason" = ca-pem ] && [ ! -e "$cfmgr_install_context/transaction" ]
""",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize("failure", ["https", "ssl", "option", "loader"])
def test_unusable_curl_is_rejected_before_ram_mutation(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
    failure: str,
) -> None:
    executable = tmp_path / "unusable-curl"
    if failure == "loader":
        executable.write_text("#!/cfmgr/nonexistent-native-loader\nexit 0\n")
    else:
        protocols = "http" if failure == "https" else "http https"
        features = "IPv6" if failure == "ssl" else "SSL IPv6"
        executable.write_text(f"""#!/bin/sh
if [ "$2" = -V ]; then
    printf 'curl 8.17.0 fixture\\nProtocols: {protocols}\\nFeatures: {features}\\n'
    exit 0
fi
exit 2
""")
    executable.chmod(0o755)
    tools = {**native_tools, "curl": str(executable)}
    result = native_invoke(
        shell,
        tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca"
[ "$?" = 1 ] && [ "$cfmgr_native_ready" = 0 ] && [ ! -e "$cfmgr_install_context/native.source" ]
""",
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


@pytest.mark.parametrize(
    "failure", ["copy", "publish", "unresolved", "cleanup-unresolved"]
)
def test_mutation_failures_clean_owned_directory_or_retain_uncertainty(
    shell: list[str],
    native_tools: dict[str, str],
    legacy_fsync: Path,
    tls_material: Path,
    tmp_path: Path,
    failure: str,
) -> None:
    tool = tmp_path / "failed-mutation"
    tool.write_text(
        "#!/bin/sh\nexit 1\n"
        if failure == "copy"
        else f"""#!/bin/sh
[ "$1" != -n ] || exit 1
exec {native_tools["mv"]} "$@"
"""
    )
    tool.chmod(0o755)
    body = r"""
# This unit focuses on mutation failure ownership; real offline TLS qualification
# is already exercised separately, without repeating its external setup here.
cfmgr_native_offline() { return 0; }
"""
    if failure in ("unresolved", "cleanup-unresolved"):
        body += f"cfmgr_test_failure={failure}\n"
        body += r"""
cfmgr_native_action() {
    if [ "$1" = install-copy ]; then
        [ "$cfmgr_test_failure" != cleanup-unresolved ] || return 1
        return 3
    fi
    if [ "$cfmgr_test_failure" = cleanup-unresolved ] && [ "$cfmgr_native_reason" = cleanup ]; then return 3; fi
    if [ "$1" = native-rmdir ]; then
        cfmgr_prerequisites_run "$1" "$cfmgr_install_context" "$cfmgr_install_sh" "$root/modules/helpers/probe.sh" \
            "$cfmgr_install_env" "$cfmgr_install_awk" "$cfmgr_install_sleep" "$cfmgr_install_wc" /bin/rmdir "$2" || return $?
    else cfmgr_bootstrap_action "$@" || return $?; fi
    cfmgr_native_output=$cfmgr_probe_stdout cfmgr_native_error=$cfmgr_probe_stderr cfmgr_native_exit=$cfmgr_probe_exit
}
"""
    else:
        body += (
            "cfmgr_install_cp=$1\n" if failure == "copy" else "cfmgr_install_mv=$1\n"
        )
    body += r"""
cfmgr_native_check "$cfmgr_install_context" "$test_curl" "$test_openssl" "$test_ca"
status=$?
[ "$cfmgr_native_ready" = 0 ] && [ -f "$cfmgr_install_context/native.source" ] || exit 10
"""
    body += (
        '[ "$status" = 3 ] && [ -d "$cfmgr_install_context/native.directory" ] || exit 11\n'
        'cfmgr_native_check /different-context "$test_curl" "$test_openssl" "$test_ca"\n'
        '[ "$?" = 3 ] && [ "$cfmgr_native_context" = "$cfmgr_install_context" ]\n'
        if failure in ("unresolved", "cleanup-unresolved")
        else '[ "$status" = 1 ] && [ ! -e "$cfmgr_install_context/native.directory" ]\n'
    )
    result = native_invoke(
        shell,
        native_tools,
        legacy_fsync,
        tmp_path / "context",
        tls_material / "trusted.pem",
        body,
        tool,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")


NATIVE_CONSUMER = r"""
cfmgr_test_install() {
    test_package=$1 test_jffs=$2 test_opt=$3 test_context=$4 test_owner=$5
    test_sh=$6 test_env=$7 test_awk=$8 test_readlink=$9
    shift 9
    test_sleep=$1 test_wc=$2 test_ls=$3 test_fsync=$4 test_mkdir=$5 test_cp=$6 test_chmod=$7 test_mv=$8 test_sha=$9
    shift 9
    test_jq=$1 test_uuid=$2 test_fs=$3 test_fsroot=$4 test_relative=$5 test_df=$6
    shift 8
    test_curl=$1 test_openssl=$2 test_ca=$3 test_alias=$4
    . "$test_alias"
    . "$test_package/modules/helpers/bootstrap.sh"
    . "$test_package/modules/lib/prerequisites.sh"
    . "$test_package/modules/lib/native.sh"
    cfmgr_bootstrap_attached() { [ "$cfmgr_test_detached" = 0 ] && [ -d "$test_jffs" ] && [ -d "$test_opt" ]; }
    cfmgr_bootstrap_retained() { return 0; }
    cfmgr_bootstrap_native_admission() {
        cfmgr_native_check "$test_context" "$test_curl" "$test_openssl" "$test_ca"
    }
    # Firmware-only storage/root/controller admission is explicitly adapted;
    # actual offline native check, RAM option probes and transaction stay real.
    cfmgr_bootstrap_metadata() { return 0; }
    cfmgr_storage_uuid() { cfmgr_storage_uuid_value=$test_uuid; }
    cfmgr_prerequisites_check() { return 0; }
    cfmgr_prerequisites_run() {
        if [ "$1" = blkid ]; then
            cfmgr_probe_exit=0 cfmgr_probe_stderr=$test_context/fixture-empty
            : >"$cfmgr_probe_stderr"
            return 0
        fi
        cfmgr_test_host_run "$@"
    }
    cfmgr_bootstrap_transaction() {
        [ "$cfmgr_native_ready" = 1 ] && [ "$1" = "$test_package" ] && [ "$2" = /jffs ] || return 91
        # Restore actual metadata/attachment function definitions before running
        # the unchanged transaction body with existing host fixture operands.
        . "$test_package/modules/helpers/bootstrap.sh"
        cfmgr_bootstrap_attached() { [ "$cfmgr_test_detached" = 0 ] && [ -d "$test_jffs" ] && [ -d "$test_opt" ]; }
        cfmgr_test_real_transaction "$test_package" "$test_jffs" "$test_opt" "$test_context" "$test_owner" \
            "$test_sh" "$test_env" "$test_awk" "$test_readlink" "$test_sleep" "$test_wc" "$test_ls" "$test_fsync" \
            "$test_mkdir" "$test_cp" "$test_chmod" "$test_mv" "$test_sha" "$test_jq" \
            "$test_uuid" "$test_fs" "$test_fsroot" "$test_relative" "$test_df"
    }
    cfmgr_install_source=$test_package cfmgr_install_jffs=$test_jffs cfmgr_install_opt=$test_opt cfmgr_install_context=$test_context
    cfmgr_install_sh=$test_sh cfmgr_install_env=$test_env cfmgr_install_awk=$test_awk cfmgr_install_readlink=$test_readlink
    cfmgr_install_sleep=$test_sleep cfmgr_install_wc=$test_wc cfmgr_install_ls=$test_ls cfmgr_install_fsync=$test_fsync
    cfmgr_install_mkdir=$test_mkdir cfmgr_install_cp=$test_cp cfmgr_install_chmod=$test_chmod cfmgr_install_mv=$test_mv
    cfmgr_install_owner=$test_owner cfmgr_storage_opt=$test_opt cfmgr_storage_source=/fixture-device
    cfmgr_storage_filesystem=$test_fs cfmgr_storage_fsroot=$test_fsroot cfmgr_storage_relative=$test_relative
    cfmgr_install_nvram=$test_context/fixture-nvram
    printf '#!/bin/sh\nprintf "1\\n"\n' >"$cfmgr_install_nvram"
    chmod 755 "$cfmgr_install_nvram"
    cfmgr_bootstrap_native_work
    result=$?
    exec 5<&-
    return "$result"
}
cfmgr_test_install "$@"
"""


def test_native_work_real_admission_continues_to_real_transaction(
    shell: list[str],
    base_tools: dict[str, str],
    legacy_fsync: Path,
    native_tools: dict[str, str],
    tls_material: Path,
    package: Path,
    tmp_path: Path,
) -> None:
    source = (package / "modules/helpers/bootstrap.sh").read_bytes()
    definition = b"cfmgr_bootstrap_transaction() {"
    assert source.count(definition) == 1
    renamed = source.replace(definition, b"cfmgr_test_real_transaction() {", 1)
    assert renamed.replace(b"cfmgr_test_real_transaction() {", definition, 1) == source
    alias = tmp_path / "private-bootstrap-alias.sh"
    alias.write_bytes(renamed)
    prefix = HOST_TRANSACTION.split("cfmgr_test_install() {", 1)[0]
    prefix = prefix.replace("cfmgr_prerequisites_run() {", "cfmgr_test_host_run() {", 1)
    prefix = prefix.replace(
        "LANGUAGE= CFMGR_FSYNC_FAULT=",
        "LANGUAGE= OPENSSL_CONF=/dev/null CFMGR_FSYNC_FAULT=",
    )
    result = host_install(
        shell,
        base_tools,
        legacy_fsync,
        package,
        tmp_path,
        script=prefix + NATIVE_CONSUMER,
        extra=(
            native_tools["curl"],
            native_tools["openssl"],
            tls_material / "trusted.pem",
            alias,
        ),
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    assert (
        (tmp_path / "jffs/addons/CFMgr.d/setup-state")
        .read_bytes()
        .endswith(b" complete\n")
    )
    assert (tmp_path / "jffs/scripts/cfmgr.sh").read_bytes() == (
        package / "cfmgr.sh"
    ).read_bytes()
    assert not list(tmp_path.glob("ram-*/native-curl-https.*"))
    assert list(tmp_path.glob("ram-*/native-ca-decode.*.out"))


def test_status_count_uncertainty_retires_https_admission(
    shell: list[str], tmp_path: Path
) -> None:
    output = tmp_path / "status"
    error = tmp_path / "error"
    output.write_bytes(b"200\n")
    error.write_bytes(b"")
    script = r"""
. "$1"
cfmgr_native_context=$2 cfmgr_native_ca=$3 cfmgr_native_ready=1
cfmgr_native_action() {
    if [ "$1" = install-wc ]; then return 3; fi
    cfmgr_native_output=$3/status cfmgr_native_error=$3/error cfmgr_native_exit=0
}
cfmgr_native_https https://127.0.0.1:9/
[ "$?" = 3 ] && [ "$cfmgr_native_ready" = 0 ] || exit 10
cfmgr_native_check /new-context /new-curl /new-openssl /new-ca
[ "$?" = 3 ] && [ "$cfmgr_native_context" = "$2" ] || exit 11
cfmgr_native_https https://127.0.0.1:9/
[ "$?" = 3 ]
"""
    result = subprocess.run(
        [*shell, "-c", script, "native-status", NATIVE, tmp_path, output],
        check=False,
        capture_output=True,
        timeout=2,
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
