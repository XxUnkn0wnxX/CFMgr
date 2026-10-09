"""Installed Entware opkg capability selection and probing."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / "modules/bootstrap.sh"
COMMON = ("jq", "coreutils-timeout", "coreutils-sha256sum")
PACKAGE_TO_TOOL = {
    "jq": "jq",
    "coreutils-timeout": "timeout",
    "coreutils-sha256sum": "sha256sum",
    "bind-dig": "dig",
    "flock": "flock",
}
pytestmark = pytest.mark.integration

DISPATCHER = r"""
import hashlib
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

mode, settings_name, *args = sys.argv[1:]
settings_path = Path(settings_name)
settings = json.loads(settings_path.read_text())

def record(path, value):
    with Path(path).open("a") as stream:
        stream.write(json.dumps(value) + "\n")

if mode == "opkg":
    record(settings["opkg_log"], args)
    record(
        settings["environment_log"],
        {
            name: os.environ.get(name)
            for name in (
                "OPKG_CONF_DIR",
                "OPKG_OFFLINE_ROOT",
                "IPKG_CONF_DIR",
                "OFFLINE_ROOT",
                "TMPDIR",
                "http_proxy",
                "HTTPS_PROXY",
                "LD_LIBRARY_PATH",
                "OPENSSL_CONF",
                "WGETRC",
            )
        },
    )
    if args == ["update"]:
        if settings.get("update_status") is not None:
            sys.exit(int(settings["update_status"]))
        marker = Path(settings["update_once_marker"])
        if settings.get("fail_update") or (
            settings.get("fail_update_once") and not marker.exists()
        ):
            marker.write_text("failed\n")
            sys.exit(7)
        sys.exit(0)
    if args[:2] == ["--force-reinstall", "install"]:
        packages = args[2:]
    elif args and args[0] == "install":
        packages = args[1:]
    else:
        sys.exit(40)
    if settings.get("fail_install"):
        sys.exit(int(settings.get("install_status", 8)))
    if settings.get("install_status") is not None:
        sys.exit(int(settings["install_status"]))
    for package in packages:
        tool = settings["packages"].get(package)
        if tool is None:
            sys.exit(41)
        if package in settings.get("skip_install", []):
            continue
        target = Path(settings["bin"]) / tool
        target.write_text(
            "#!/bin/sh\nexec "
            + " ".join(
                shlex.quote(value)
                for value in (
                    sys.executable,
                    settings["dispatcher"],
                    "capability",
                    str(settings_path),
                    tool,
                )
            )
            + ' "$@"\n'
        )
        target.chmod(0o700)
    sys.exit(0)

if mode != "capability":
    sys.exit(42)
tool = settings.get("capability_name", args.pop(0) if args else "")
record(settings["probe_log"], [tool, args])
behavior = settings.get("bad_capabilities", {}).get(tool, "good")
if behavior == "fail":
    sys.exit(9)
if behavior == "fail_once":
    marker = Path(settings["update_once_marker"] + "-" + tool)
    if not marker.exists():
        marker.write_text("failed\n")
        sys.exit(9)
    behavior = "good"
if behavior == "uncertain":
    sys.exit(129)
if tool == "jq":
    data = sys.stdin.buffer.read()
    if args != ["-M", "-r", ".cfmgr"] or data != b'{"cfmgr":"ready"}\n':
        sys.exit(10)
    print("wrong" if behavior == "mismatch" else "ready")
elif tool == "sha256sum":
    data = sys.stdin.buffer.read()
    if args or data != b"abc":
        sys.exit(11)
    digest = hashlib.sha256(data).hexdigest()
    if behavior == "mismatch":
        digest = "0" * 64
    print(digest + "  -")
elif tool == "timeout":
    if args != ["1", "/bin/sh", "-c", "exit 0"]:
        sys.exit(12)
    sys.exit(subprocess.run(args[1:], check=False).returncode)
elif tool == "dig":
    if args != ["-v"]:
        sys.exit(13)
    print("DiG fixture")
elif tool == "flock":
    if args != ["--version"]:
        sys.exit(14)
    print("flock fixture")
else:
    sys.exit(15)
"""


class OpkgFixture:
    def __init__(
        self, router: RouterHarness, *, busybox: Path | None = None, name: str = ""
    ) -> None:
        self.router = router
        suffix = f" {name}" if name else ""
        self.root = router.path(f"ram/tmp/Entware root{suffix}")
        self.root.mkdir(mode=0o700)
        self.bin = self.root / "bin"
        self.bin.mkdir(mode=0o700)
        stem = f"work/opkg-{name or 'default'}"
        self.opkg_log = router.path(f"{stem}-calls.jsonl")
        self.environment_log = router.path(f"{stem}-environment.jsonl")
        self.probe_log = router.path(f"{stem}-probes.jsonl")
        self.settings_path = router.path(f"{stem}-settings.json")
        self.dispatcher = router.write(f"{stem}-dispatch.py", DISPATCHER)
        self.settings: dict[str, object] = {
            "bin": str(self.bin),
            "dispatcher": str(self.dispatcher),
            "opkg_log": str(self.opkg_log),
            "environment_log": str(self.environment_log),
            "probe_log": str(self.probe_log),
            "update_once_marker": str(router.path(f"{stem}-update-failed-once")),
            "packages": PACKAGE_TO_TOOL,
            "bad_capabilities": {},
            "skip_install": [],
        }
        self.save()
        self._write_executable(self.bin / "opkg", "opkg")
        self.busybox = busybox

    def _write_executable(self, path: Path, mode: str, *fixed_args: str) -> None:
        command = (
            sys.executable,
            str(self.dispatcher),
            mode,
            str(self.settings_path),
            *fixed_args,
        )
        script = "#!/bin/sh\nexec " + " ".join(map(shlex.quote, command)) + ' "$@"\n'
        path.write_text(script, encoding="utf-8")
        path.chmod(0o700)

    def seed(self, *tools: str) -> None:
        for tool in tools:
            path = self.bin / tool
            self._write_executable(path, "capability", tool)

    def save(self) -> None:
        self.settings_path.write_text(json.dumps(self.settings), encoding="utf-8")
        self.settings_path.chmod(0o600)

    def opkg_calls(self) -> list[list[str]]:
        if not self.opkg_log.exists():
            return []
        return [json.loads(line) for line in self.opkg_log.read_text().splitlines()]

    def probe_calls(self) -> list[list[str]]:
        if not self.probe_log.exists():
            return []
        return [json.loads(line) for line in self.probe_log.read_text().splitlines()]

    def opkg_environments(self) -> list[dict[str, str | None]]:
        if not self.environment_log.exists():
            return []
        return [json.loads(line) for line in self.environment_log.read_text().splitlines()]

    def invoke(self, body: str, *, shell: str | None = None) -> ShellResult:
        script = f". {shlex.quote(str(BOOTSTRAP))}\n" + body
        if shell is not None:
            runner = f"exec {shlex.quote(str(shell))} sh -c {shlex.quote(script)}"
            return self.router.run(runner, timeout=3)
        return self.router.run(script, timeout=3)

    def call(
        self, scope: str = "shared", lock_provider: str = "native", *, shell: str | None = None
    ):
        body = (
            f"cfmgr_bootstrap_dependencies_test {shlex.quote(str(self.root))} "
            f"{shlex.quote(scope)} {shlex.quote(lock_provider)}; status=$?\n"
            'printf "RESULT\\t%s\\n" "$status"\n'
        )
        return self.invoke(body, shell=shell)

    def reinstall_call(
        self, scope: str = "shared", lock_provider: str = "native", *, shell: str | None = None
    ):
        body = (
            f"cfmgr_bootstrap_reinstall_test {shlex.quote(str(self.root))} "
            f"{shlex.quote(scope)} {shlex.quote(lock_provider)}; status=$?\n"
            'printf "RESULT\\t%s\\n" "$status"\n'
        )
        return self.invoke(body, shell=shell)


def assert_result(result: ShellResult, code: int) -> None:
    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{code}\n"
    assert result.stderr == ""


@pytest.mark.matrix("V74", evidence="host")
def test_healthy_capabilities_are_a_noop_and_scope_only_probes_selected_tools(
    router: RouterHarness,
) -> None:
    fixture = OpkgFixture(router)
    fixture.seed("jq", "timeout", "sha256sum", "dig", "flock")

    assert_result(fixture.call("shared", "native"), 0)
    assert [row[0] for row in fixture.probe_calls()] == ["jq", "timeout", "sha256sum"]
    assert fixture.opkg_calls() == []

    fixture.settings["bad_capabilities"] = {"dig": "fail", "flock": "fail"}
    fixture.save()
    assert_result(fixture.call("shared", "native"), 0)
    assert [row[0] for row in fixture.probe_calls()] == [
        "jq",
        "timeout",
        "sha256sum",
        "jq",
        "timeout",
        "sha256sum",
    ]
    assert fixture.opkg_calls() == []

    fixture.settings["bad_capabilities"] = {}
    fixture.save()
    assert_result(fixture.call("tunnel", "entware"), 0)
    assert [row[0] for row in fixture.probe_calls()][-5:] == [
        "jq",
        "timeout",
        "sha256sum",
        "dig",
        "flock",
    ]
    assert fixture.opkg_calls() == []


@pytest.mark.matrix("V74", evidence="host")
def test_missing_capabilities_install_only_scoped_packages_in_fixed_order(
    router: RouterHarness,
) -> None:
    fixture = OpkgFixture(router)

    assert_result(fixture.call("tunnel", "entware"), 0)
    assert fixture.opkg_calls() == [
        ["update"],
        ["install", "jq", "coreutils-timeout", "coreutils-sha256sum", "bind-dig", "flock"],
    ]
    assert [row[0] for row in fixture.probe_calls()] == [
        "jq",
        "timeout",
        "sha256sum",
        "dig",
        "flock",
    ]


@pytest.mark.matrix("V74", evidence="host")
def test_usable_jq_full_is_kept_while_only_an_unusable_selected_tool_is_reinstalled(
    router: RouterHarness,
) -> None:
    fixture = OpkgFixture(router)
    fixture.seed("jq", "timeout", "sha256sum", "dig", "flock")
    fixture.settings["bad_capabilities"] = {"timeout": "fail_once"}
    fixture.save()

    assert_result(fixture.call("shared", "native"), 0)
    assert fixture.opkg_calls() == [["update"], ["install", "coreutils-timeout"]]
    assert (fixture.bin / "jq").exists()
    assert [row[0] for row in fixture.probe_calls()].count("jq") == 2
    assert [row[0] for row in fixture.probe_calls()].count("timeout") == 2
    assert [row[0] for row in fixture.probe_calls()].count("sha256sum") == 2
    assert not any(row[0] in {"dig", "flock"} for row in fixture.probe_calls())


@pytest.mark.matrix("V74", evidence="host")
def test_update_failure_stops_and_a_later_call_rechecks_and_retries(router: RouterHarness) -> None:
    fixture = OpkgFixture(router)
    fixture.settings["fail_update_once"] = True
    fixture.save()
    body = (
        "export OPKG_CONF_DIR=/poison OPKG_OFFLINE_ROOT=/poison IPKG_CONF_DIR=/poison\n"
        "export OFFLINE_ROOT=/poison TMPDIR=/poison\n"
        "export http_proxy=http://invalid HTTPS_PROXY=http://invalid\n"
        "export LD_LIBRARY_PATH=/poison OPENSSL_CONF=/poison WGETRC=/poison\n"
        "cfmgr_bootstrap_dependencies_test "
        f"{shlex.quote(str(fixture.root))} shared native; first=$?\n"
        "cfmgr_bootstrap_dependencies_test "
        f"{shlex.quote(str(fixture.root))} shared native; second=$?\n"
        'printf "RESULT\\t%s\\t%s\\n" "$first" "$second"\n'
    )

    result = fixture.invoke(body)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t1\t0\n"
    assert fixture.opkg_calls() == [
        ["update"],
        ["update"],
        ["install", *COMMON],
    ]
    assert len(fixture.opkg_environments()) == 3
    assert all(value is None for row in fixture.opkg_environments() for value in row.values())


@pytest.mark.matrix("V74", evidence="host")
def test_install_failure_stops_and_post_install_probe_failure_is_not_success(
    router: RouterHarness,
) -> None:
    install_failure = OpkgFixture(router)
    install_failure.settings["fail_install"] = True
    install_failure.save()
    assert_result(install_failure.call(), 1)
    assert install_failure.opkg_calls() == [["update"], ["install", *COMMON]]
    assert install_failure.probe_calls() == []

    post_probe = OpkgFixture(router, name="post-probe")
    post_probe.settings["skip_install"] = ["coreutils-sha256sum"]
    post_probe.save()
    assert_result(post_probe.call(), 1)
    assert post_probe.opkg_calls() == [["update"], ["install", *COMMON]]
    assert [row[0] for row in post_probe.probe_calls()] == ["jq", "timeout"]
    assert not (post_probe.bin / "sha256sum").exists()


@pytest.mark.parametrize(
    ("scope", "lock_provider", "packages", "tools"),
    [
        ("shared", "native", COMMON, ("jq", "timeout", "sha256sum")),
        (
            "tunnel",
            "native",
            (*COMMON, "bind-dig"),
            ("jq", "timeout", "sha256sum", "dig"),
        ),
        (
            "shared",
            "entware",
            (*COMMON, "flock"),
            ("jq", "timeout", "sha256sum", "flock"),
        ),
        (
            "tunnel",
            "entware",
            (*COMMON, "bind-dig", "flock"),
            ("jq", "timeout", "sha256sum", "dig", "flock"),
        ),
    ],
    ids=["shared-native", "tunnel-native", "shared-entware", "tunnel-entware"],
)
@pytest.mark.matrix("V74", evidence="host")
def test_explicit_reinstall_forces_every_selected_package_and_post_probe(
    router: RouterHarness,
    scope: str,
    lock_provider: str,
    packages: tuple[str, ...],
    tools: tuple[str, ...],
) -> None:
    fixture = OpkgFixture(router)
    fixture.seed(*tools)

    result = fixture.invoke(
        "export OFFLINE_ROOT=/poison TMPDIR=/poison\n"
        + f"cfmgr_bootstrap_reinstall_test {shlex.quote(str(fixture.root))} "
        + f"{shlex.quote(scope)} {shlex.quote(lock_provider)}; status=$?\n"
        + 'printf "RESULT\\t%s\\n" "$status"\n'
    )
    assert_result(result, 0)
    assert fixture.opkg_calls() == [
        ["update"],
        ["--force-reinstall", "install", *packages],
    ]
    assert [row[0] for row in fixture.probe_calls()] == list(tools)
    assert len(fixture.opkg_environments()) == 2
    assert all(value is None for row in fixture.opkg_environments() for value in row.values())


@pytest.mark.parametrize(
    ("operation", "tool_status", "expected"),
    [
        ("update", 7, 1),
        ("update", 129, 129),
        ("install", 8, 1),
        ("install", 129, 129),
    ],
    ids=["update-failure", "update-uncertain", "install-failure", "install-uncertain"],
)
@pytest.mark.matrix("V74", evidence="host")
def test_reinstall_stops_at_failed_or_uncertain_opkg_step(
    router: RouterHarness, operation: str, tool_status: int, expected: int
) -> None:
    fixture = OpkgFixture(router)
    setting = "update_status" if operation == "update" else "install_status"
    fixture.settings[setting] = tool_status
    fixture.save()

    assert_result(fixture.reinstall_call(), expected)
    expected_calls = [["update"]]
    if operation == "install":
        expected_calls.append(["--force-reinstall", "install", *COMMON])
    assert fixture.opkg_calls() == expected_calls
    assert fixture.probe_calls() == []


@pytest.mark.parametrize(
    ("fault", "expected"),
    [("ordinary", 1), ("uncertain", 129)],
    ids=["post-probe-failure", "post-probe-uncertain"],
)
@pytest.mark.matrix("V74", evidence="host")
def test_reinstall_requires_every_selected_post_probe(
    router: RouterHarness, fault: str, expected: int
) -> None:
    fixture = OpkgFixture(router)
    if fault == "ordinary":
        fixture.settings["bad_capabilities"] = {"sha256sum": "fail"}
    else:
        fixture.settings["bad_capabilities"] = {"timeout": "uncertain"}
    fixture.save()

    assert_result(fixture.reinstall_call(), expected)
    assert fixture.opkg_calls() == [
        ["update"],
        ["--force-reinstall", "install", *COMMON],
    ]
    probes = [row[0] for row in fixture.probe_calls()]
    assert probes == (["jq", "timeout", "sha256sum"] if fault == "ordinary" else ["jq", "timeout"])


@pytest.mark.matrix("V74", evidence="host")
def test_reinstall_api_validation_precedes_opkg(router: RouterHarness) -> None:
    fixture = OpkgFixture(router)
    missing_root = shlex.quote(str(fixture.root / "missing"))
    body = (
        "cfmgr_bootstrap_reinstall; a=$?\n"
        "cfmgr_bootstrap_reinstall shared native extra; b=$?\n"
        f"cfmgr_bootstrap_reinstall_test {shlex.quote(str(fixture.root))} shared; c=$?\n"
        f"cfmgr_bootstrap_reinstall_test {shlex.quote(str(fixture.root))} invalid native; d=$?\n"
        f"cfmgr_bootstrap_reinstall_test {shlex.quote(str(fixture.root))} shared invalid; e=$?\n"
        "cfmgr_bootstrap_reinstall_test relative/root shared native; f=$?\n"
        f"cfmgr_bootstrap_reinstall_test {missing_root} shared native; g=$?\n"
        'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" '
        '"$a" "$b" "$c" "$d" "$e" "$f" "$g"\n'
    )
    result = fixture.invoke(body)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t2\t2\t2\t2\t2\t2\t1\n"
    assert fixture.opkg_calls() == []
    assert fixture.probe_calls() == []


@pytest.mark.matrix("V74", evidence="host")
def test_production_reinstall_uses_literal_opt(router: RouterHarness) -> None:
    fixture = OpkgFixture(router)
    body = (
        "_cfmgr_bootstrap_reinstall_run() { "
        'printf "CALL\\t%s\\t%s\\t%s\\n" "$1" "$2" "$3"; }\n'
        "cfmgr_bootstrap_reinstall tunnel entware; status=$?\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = fixture.invoke(body)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "CALL\t/opt\ttunnel\tentware\nRESULT\t0\n"
    assert fixture.opkg_calls() == []


@pytest.mark.matrix("V74", evidence="host")
def test_native_probe_uncertainty_returns_129_without_package_mutation(
    router: RouterHarness,
) -> None:
    fixture = OpkgFixture(router)
    fixture.seed("jq", "timeout", "sha256sum")
    fixture.settings["bad_capabilities"] = {"jq": "uncertain"}
    fixture.save()
    result = fixture.call()
    assert_result(result, 129)
    assert fixture.opkg_calls() == []


@pytest.mark.matrix("V74", evidence="host")
def test_invalid_api_tokens_and_root_admission_fail_before_opkg(router: RouterHarness) -> None:
    fixture = OpkgFixture(router)
    body = (
        "cfmgr_bootstrap_dependencies_test "
        f"{shlex.quote(str(fixture.root))} shared; a=$?\n"
        "cfmgr_bootstrap_dependencies_test "
        f"{shlex.quote(str(fixture.root))} shared native extra; b=$?\n"
        f"cfmgr_bootstrap_dependencies_test {shlex.quote(str(fixture.root))} invalid native; c=$?\n"
        f"cfmgr_bootstrap_dependencies_test {shlex.quote(str(fixture.root))} tunnel invalid; d=$?\n"
        f"cfmgr_bootstrap_dependencies_test relative/root shared native; e=$?\n"
        "cfmgr_bootstrap_dependencies_test "
        f"{shlex.quote(str(fixture.root.parent / '..' / 'bad'))} shared native; f=$?\n"
        'printf "RESULT\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "$a" "$b" "$c" "$d" "$e" "$f"\n'
    )
    result = fixture.invoke(body)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t2\t2\t2\t2\t2\t2\n"
    assert fixture.opkg_calls() == []
    assert fixture.probe_calls() == []

    missing = router.path("ram/tmp/missing-entware")
    body = (
        f"cfmgr_bootstrap_dependencies_test {shlex.quote(str(missing))} shared native; a=$?\n"
        f"cfmgr_bootstrap_dependencies_test {shlex.quote(str(fixture.root))} shared native; b=$?\n"
        'printf "RESULT\\t%s\\t%s\\n" "$a" "$b"\n'
    )
    fixture.bin.joinpath("opkg").unlink()
    missing_result = fixture.invoke(body)
    assert missing_result.returncode == 0 and missing_result.stderr == ""
    assert missing_result.stdout == "RESULT\t1\t1\n"
    assert fixture.opkg_calls() == []
    assert fixture.probe_calls() == []


@pytest.mark.matrix("V74", evidence="host")
def test_production_route_uses_literal_opt_and_ignores_ambient_policy(
    router: RouterHarness,
) -> None:
    fixture = OpkgFixture(router)
    body = (
        "cfmgr_bootstrap_dependencies; noargs=$?\n"
        "cfmgr_bootstrap_dependencies shared native extra; extra=$?\n"
        "_bootstrap_scope=poison; _bootstrap_lock_provider=poison; _bootstrap_root=/ambient\n"
        "_cfmgr_bootstrap_dependencies_run() { "
        'printf "CALL\\t%s\\t%s\\t%s\\n" "$1" "$2" "$3"; }\n'
        "cfmgr_bootstrap_dependencies shared native; status=$?\n"
        'printf "RESULT\\t%s\\t%s\\t%s\\n" "$noargs" "$extra" "$status"\n'
    )
    result = fixture.invoke(body)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "CALL\t/opt\tshared\tnative\nRESULT\t2\t2\t0\n"
    assert fixture.opkg_calls() == []


@pytest.mark.matrix("V74", evidence="host")
def test_backend_preserves_caller_shell_state(router: RouterHarness) -> None:
    fixture = OpkgFixture(router)
    fixture.seed("jq", "timeout", "sha256sum")
    marker = router.path("work/opkg-exit-trap")
    body = (
        "set +f\nset -- alpha beta\nIFS=:\nLC_ALL=POSIX\numask 027\n"
        "_bootstrap_probe='ambient poison'; _bootstrap_packages='ambient packages'\n"
        f"trap 'printf fired >>{shlex.quote(str(marker))}' 0\n"
        "cfmgr_bootstrap_dependencies_test "
        f"{shlex.quote(str(fixture.root))} shared native; status=$?\n"
        "case $- in *f*) noglob=yes ;; *) noglob=no ;; esac\n"
        'printf "STATE\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n" "$status" "$noglob" '
        '"$#" "$1" "$2" "$IFS"\n'
        "umask\n"
    )
    result = fixture.invoke(body)
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "STATE\t0\tno\t2\talpha\tbeta\t:\n0027\n"
    assert marker.read_bytes() == b"fired"


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_shell_installs_only_shared_native_dependencies(
    busybox_router: RouterHarness,
) -> None:
    assert busybox_router.busybox is not None
    busybox_router.busybox_applets("printf", "[", "test")
    fixture = OpkgFixture(busybox_router, busybox=busybox_router.busybox)

    assert_result(fixture.call("shared", "native", shell=busybox_router.busybox), 0)
    assert_result(fixture.reinstall_call("shared", "native", shell=busybox_router.busybox), 0)
    assert fixture.opkg_calls() == [
        ["update"],
        ["install", *COMMON],
        ["update"],
        ["--force-reinstall", "install", *COMMON],
    ]
    assert [row[0] for row in fixture.probe_calls()] == [
        "jq",
        "timeout",
        "sha256sum",
        "jq",
        "timeout",
        "sha256sum",
    ]
