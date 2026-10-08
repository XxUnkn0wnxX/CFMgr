"""Synthetic native diagnostic evidence; no router, network or Entware execution."""

from __future__ import annotations

import json
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/diagnostic.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V75", evidence="host")]

# Each command is explicitly exposed and instrumented. Only owned fixture paths
# may be modified. Real host awk/wc/sh provide primitive evidence, while the
# other tools model contracts (not router capability or firmware provenance).
DISPATCHER = r"""
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

settings = json.loads(Path(sys.argv[1]).read_text())
tool, args = sys.argv[2], sys.argv[3:]
ram = Path(settings["ram"]).resolve()
with open(Path(settings["log"]) / (str(os.getpid()) + ".json"), "w") as log:
    log.write(json.dumps({"tool": tool, "args": args, "path": os.environ.get("PATH"),
                          "locale": os.environ.get("LC_ALL"),
                          "openssl_conf": os.environ.get("OPENSSL_CONF"),
                          "startup": [key for key in ("ENV", "BASH_ENV", "LD_PRELOAD",
                                      "LD_LIBRARY_PATH", "CDPATH", "OPENSSL_ENGINES",
                                      "OPENSSL_FIPS", "OPENSSL_MODULES", "OPENSSL_CONF_INCLUDE",
                                      "RANDFILE") if key in os.environ]}) + "\n")
behavior = settings.get("behaviors", {}).get(tool, "")
if behavior == "error":
    print("SECRET-provider-token /private/config ip=192.0.2.9", file=sys.stderr)
    sys.exit(7)
if behavior == "invalid":
    print("SECRET-provider-token\tserial=SECRET")
    sys.exit(0)
if behavior == "flood":
    sys.stdout.write("SECRET" * 4000)
    sys.stdout.flush()
    sys.exit(0)
if behavior.startswith("signal"):
    selected_signal = {"signal": signal.SIGTERM, "signal-hup": signal.SIGHUP,
                       "signal-int": signal.SIGINT}[behavior]
    os.killpg(os.getpgrp(), selected_signal)
    sys.exit(0)

def owned(value):
    path = Path(value)
    assert path.is_absolute()
    assert path.parent.resolve() == ram or ram in path.parent.resolve().parents
    assert path.name not in ("", ".", "..")
    return path

if tool == "mkdir":
    assert len(args) == 1
    path = owned(args[0])
    attempt = int(path.name.rsplit(".", 1)[1])
    if attempt < settings.get("collisions", 0):
        path.mkdir(exist_ok=True)
        (path / "foreign").write_text("preserve")
        sys.exit(1)
    status = subprocess.call(["/bin/mkdir", *args])
    if behavior == "readonly-stage" and status == 0:
        path.chmod(0o500)
    sys.exit(status)
if tool == "rm":
    assert len(args) == 2 and args[0] == "-rf"
    path = owned(args[1])
    assert path.name.startswith("cfmgr-diagnostic.")
    assert not (path / "foreign").exists()
    sys.exit(subprocess.call(["/bin/rm", *args]))
if tool == "ln":
    assert args[0:2] == ["-s", "bytes"] and len(args) == 3
    owned(args[2]).symlink_to("bytes")
elif tool == "readlink":
    assert args[0] == "-f" and len(args) == 2
    print(owned(args[1]).resolve())
elif tool == "sh":
    assert len(args) == 2 and args[0] == "-c"
    assert args[1] in ('[ "$((2147483646 + 1))" = 2147483647 ]',
                       'command -v printf >/dev/null 2>&1', 'exit 0')
    if behavior == "no-command-v" and args[1].startswith("command"):
        sys.exit(127)
    sys.exit(subprocess.call(["/bin/sh", *args]))
elif tool == "printf":
    assert args == [r"%s:%x\n", "cfmgr", "65535"]
    sys.exit(subprocess.call(["/usr/bin/printf", *args]))
elif tool in ("test", "["):
    assert args[0] == "2147483647" and args[1] in ("-eq", "-lt")
    assert args[2] == "2147483647"
    assert args[3:] == (["]"] if tool == "[" else [])
    sys.exit(subprocess.call(["/bin/" + tool, *args]))
elif tool in ("awk", "wc"):
    if tool == "wc":
        assert args == ["-c"]
    else:
        assert len(args) == 1 and 'RS=sprintf("%c",28)' in args[0]
    sys.exit(subprocess.call(["/usr/bin/" + tool, *args]))
elif tool == "openssl":
    if args == ["version"]:
        print("OpenSSL 1.1.1w synthetic banner")
    else:
        assert len(args) == 3 and args[:2] == ["dgst", "-sha256"]
        assert owned(args[2]).read_bytes() == b"cfmgr"
        digest = "837235063554f1ef1090d60302be6822d1da1b0d48ae82f5b0d18f6e60d0a97d"
        print("SHA256(" + args[2] + ")= " + digest)
elif tool == "curl":
    assert args == ["-q", "--fail", "--silent", "--show-error", "--connect-timeout", "2",
                    "--max-time", "5", "--proto", "=https", "--proto-redir", "=https",
                    "--max-redirs", "0", "--tlsv1.2", "--version"]
    print("curl 8.17.0 synthetic banner\nFeatures: no-network")
elif tool == "nvram":
    assert len(args) == 2 and args[0] == "get"
    values = dict(productid="GT-AX11000", firmver="3004", buildno="388.12", extendno="12_2")
    assert args[1] in values
    print(settings.get("context", {}).get(args[1], values[args[1]]))
elif tool == "uname":
    assert len(args) == 1 and args[0] in ("-r", "-m")
    print("4.1.27" if args[0] == "-r" else "aarch64")
elif tool == "busybox":
    assert not args
    print("BusyBox v1.25.1 synthetic banner\nUsage: not real BusyBox")
elif tool == "flock":
    assert args[0] == "-n"
    if args[1] == "9":
        assert len(args) == 2
        fd = 9
    else:
        assert len(args) == 5 and args[3:] == ["-c", "exit 0"]
        assert Path(args[2]).name == "sh"
        fd = os.open(owned(args[1]), os.O_WRONLY | os.O_CREAT, 0o600)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(1)
    if args[1] != "9":
        sys.exit(subprocess.call([args[2], *args[3:]]))
else:
    raise AssertionError("availability-only tool executed: " + tool)
"""

TOOLS = [
    "mkdir",
    "rm",
    "ln",
    "readlink",
    "sh",
    "awk",
    "wc",
    "openssl",
    "curl",
    "nvram",
    "uname",
    "busybox",
    "flock",
    "printf",
    "test",
    "[",
    "logger",
    "cru",
    "tar",
    "gzip",
]


class DiagnosticFixture:
    def __init__(self, router: RouterHarness):
        self.router = router
        self.settings = {
            "ram": str(router.path("ram/tmp")),
            "log": str(router.path("work/calls")),
            "behaviors": {},
        }
        Path(self.settings["log"]).mkdir(mode=0o700)
        router.write("work/dispatcher.py", DISPATCHER)
        self.settings_path = router.path("work/settings.json")
        self.save()
        for tool in TOOLS:
            router.fake_tool(
                tool,
                f"exec {shlex.quote(sys.executable)} "
                f"{shlex.quote(str(router.path('work/dispatcher.py')))} "
                f'{shlex.quote(str(self.settings_path))} {shlex.quote(tool)} "$@"\n',
            )
        self.checkout = router.path("work/checkout with spaces")
        (self.checkout / "modules").mkdir(parents=True)
        router.write(
            "work/checkout with spaces/cfmgr", (ROOT / "cfmgr.sh").read_text(), executable=True
        )
        self.wrapper = self.checkout / "modules/diagnostic.sh"
        self.wrapper.write_text(
            f". {shlex.quote(str(SOURCE))}\n"
            "cfmgr_diagnostic_main() {\n"
            f"cfmgr_diagnostic_test {shlex.quote(str(router.path('bin')))} "
            f"{shlex.quote(str(router.path('ram/tmp')))}\n}}\n"
        )
        self.wrapper.chmod(0o600)

    def save(self) -> None:
        self.settings_path.write_text(json.dumps(self.settings))
        self.settings_path.chmod(0o600)

    def run(self, argument: str = "--doctor", entry: Path | None = None) -> ShellResult:
        return self.router.run(
            f'exec {shlex.quote(str(entry or self.checkout / "cfmgr"))} "$@"\n',
            [argument],
            timeout=15,
            env={
                "CFMGR_MODULE": "/opt/secret",
                "PROVIDER_TOKEN": "SECRET-provider-token",
                "OPENSSL_CONF": "/opt/SECRET-config",
                "OPENSSL_ENGINES": "/opt/SECRET-engine",
                "OPENSSL_FIPS": "1",
                "OPENSSL_MODULES": "/opt/SECRET-provider",
                "OPENSSL_CONF_INCLUDE": "/opt/SECRET-include",
                "RANDFILE": "/opt/SECRET-rand",
                "_diag_sh": "/opt/SECRET-sh",
            },
        )

    def calls(self) -> list[dict]:
        path = Path(self.settings["log"])
        return [json.loads(record.read_text()) for record in path.glob("*.json")]

    def assert_clean(self) -> None:
        assert not list(self.router.path("ram/tmp").glob("cfmgr-diagnostic.*"))


@pytest.fixture
def diagnostic(router: RouterHarness) -> DiagnosticFixture:
    return DiagnosticFixture(router)


def rows(result: ShellResult) -> dict[str, list[str]]:
    assert result.stderr == ""
    lines = result.stdout.splitlines()
    assert lines[0] == "CFMgr 0.1.0 development native diagnostics (partial health coverage)"
    data = [line.split("\t") for line in lines[1:]]
    assert all(len(row) == 5 and row[1] in {"PASS", "FAIL", "SKIP"} for row in data)
    assert len({row[0] for row in data}) == len(data)
    return {row[0]: row[1:] for row in data}


def test_aliases_identical_and_no_operational_actions(diagnostic: DiagnosticFixture) -> None:
    first = diagnostic.run("--doctor")
    second = diagnostic.run("--diagnostic")
    assert first.returncode == second.returncode == 3, first.stdout
    assert first.stdout == second.stdout
    report = rows(first)
    for identifier in [
        "RAM.STAGE",
        "SHELL.INT31",
        "WC.BYTES",
        "AWK.FRAMING",
        "OPENSSL.SHA256",
        "CURL.OPTIONS",
        "READLINK.CANONICAL",
        "FLOCK.OPTIONS",
    ]:
        assert report[identifier][0] == "PASS"
    assert report["LOCAL.STATUS"][0] == "SKIP"
    assert report["FLOCK.CONTENTION"][0] == "SKIP"
    assert report["CONTEXT.buildno"][-1] == "buildno=388.12"
    assert report["DIAGNOSTIC.SUMMARY"][0] == "SKIP"
    assert report["NETWORK.HTTPS"][0] == "SKIP"
    calls = diagnostic.calls()
    assert {call["args"][1] for call in calls if call["tool"] == "nvram"} == {
        "productid",
        "firmver",
        "buildno",
        "extendno",
    }
    assert not {"logger", "cru", "tar", "gzip"} & {call["tool"] for call in calls}
    assert all(
        call["path"] == "/sbin:/bin:/usr/sbin:/usr/bin"
        and call["locale"] == "C"
        and not call["startup"]
        and call["openssl_conf"] == "/dev/null"
        for call in calls
    )
    assert "SECRET" not in first.stdout
    diagnostic.assert_clean()


def test_entware_inventory_never_executes_unverified_packages(
    diagnostic: DiagnosticFixture,
) -> None:
    for package in ["jq", "timeout", "sha256sum", "dig"]:
        diagnostic.router.write(
            f"opt/bin/{package}", "#!/bin/sh\nprintf 'SECRET-opt-executed'\n", executable=True
        )
    report = rows(diagnostic.run())
    assert report["OPT.STORAGE"][0] == "SKIP"
    for package in ["jq", "coreutils-timeout", "coreutils-sha256sum", "bind-dig", "flock"]:
        row = report[f"PACKAGE.{package}"]
        assert row[0] == "SKIP" and "status unknown" in row[-1] and "OPT.STORAGE" in row[-1]
    diagnostic.assert_clean()


@pytest.mark.parametrize("argument", ["--help", "--version", "--install", "--unknown", "0"])
def test_simple_dispatch_never_sources_module(diagnostic: DiagnosticFixture, argument: str) -> None:
    diagnostic.wrapper.write_text("printf 'SECRET-module-loaded'\nexit 99\n")
    result = diagnostic.run(argument)
    assert result.returncode == (0 if argument in {"--help", "--version"} else 2)
    assert "SECRET" not in result.stdout + result.stderr
    assert not diagnostic.calls()
    if argument in {"--help", "--version"}:
        assert "development" in result.stdout


@pytest.mark.parametrize("absolute", [False, True])
def test_checkout_symlink_invocation(diagnostic: DiagnosticFixture, absolute: bool) -> None:
    link = diagnostic.router.path("work/linked cfmgr")
    link.symlink_to(diagnostic.checkout / "cfmgr" if absolute else "checkout with spaces/cfmgr")
    result = diagnostic.run(entry=link)
    assert result.returncode == 3
    assert rows(result)["AWK.FRAMING"][0] == "PASS"
    diagnostic.assert_clean()


@pytest.mark.parametrize(
    ("tool", "availability", "probe"),
    [
        ("sh", "NATIVE.SH", "SHELL.INT31"),
        ("awk", "NATIVE.AWK", "AWK.FRAMING"),
        ("wc", "NATIVE.WC", "WC.BYTES"),
        ("openssl", "NATIVE.OPENSSL", "OPENSSL.SHA256"),
        ("curl", "NATIVE.CURL", "CURL.OPTIONS"),
        ("readlink", "NATIVE.READLINK", "READLINK.CANONICAL"),
        ("ln", "NATIVE.LN", "READLINK.CANONICAL"),
        ("mkdir", "NATIVE.MKDIR", "RAM.STAGE"),
        ("rm", "NATIVE.RM", "RAM.STAGE"),
    ],
)
def test_missing_tool_has_distinct_prerequisite_skip(
    diagnostic: DiagnosticFixture,
    tool: str,
    availability: str,
    probe: str,
) -> None:
    diagnostic.router.path(f"bin/{tool}").unlink()
    result = diagnostic.run()
    assert result.returncode == 1
    report = rows(result)
    assert report[availability][0] == "FAIL" and "missing" in report[availability][-1]
    assert report[probe][0] == "SKIP" and availability in report[probe][-1]
    diagnostic.assert_clean()


@pytest.mark.parametrize(
    ("tool", "probe"),
    [
        ("sh", "SHELL.INT31"),
        ("awk", "AWK.FRAMING"),
        ("wc", "WC.BYTES"),
        ("openssl", "OPENSSL.SHA256"),
        ("curl", "CURL.OPTIONS"),
        ("readlink", "READLINK.CANONICAL"),
        ("printf", "PRINTF.FORMAT"),
        ("test", "TEST.INTEGER"),
        ("[", "BRACKET.INTEGER"),
    ],
)
@pytest.mark.parametrize("behavior", ["invalid", "error"])
def test_present_unusable_tool_fails_with_redacted_output(
    diagnostic: DiagnosticFixture,
    tool: str,
    probe: str,
    behavior: str,
) -> None:
    diagnostic.settings["behaviors"][tool] = behavior
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 1
    assert rows(result)[probe][0] == "FAIL"
    assert "SECRET" not in result.stdout + result.stderr
    diagnostic.assert_clean()


@pytest.mark.parametrize(
    "value", ["SECRET\tcredential", "SECRET\nserial", "A" * 49, "$(touch injected)", ""]
)
def test_context_output_is_rejected_and_not_echoed(
    diagnostic: DiagnosticFixture, value: str
) -> None:
    diagnostic.settings["context"] = {"productid": value}
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 3
    assert rows(result)["CONTEXT.productid"][0] == "SKIP"
    assert "SECRET" not in result.stdout + result.stderr
    assert value not in result.stdout if value else True
    diagnostic.assert_clean()


def test_informational_command_v_failure_does_not_fail_report(
    diagnostic: DiagnosticFixture,
) -> None:
    diagnostic.settings["behaviors"]["sh"] = "no-command-v"
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 3
    assert rows(result)["SHELL.COMMAND-V"][:2] == ["FAIL", "info"]
    diagnostic.assert_clean()


@pytest.mark.parametrize("collisions", [2, 8])
def test_stage_collision_attempts_never_remove_foreign_data(
    diagnostic: DiagnosticFixture, collisions: int
) -> None:
    diagnostic.settings["collisions"] = collisions
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == (3 if collisions < 8 else 1)
    assert rows(result)["RAM.STAGE"][0] == ("PASS" if collisions < 8 else "FAIL")
    stages = list(diagnostic.router.path("ram/tmp").glob("cfmgr-diagnostic.*"))
    assert len(stages) == collisions
    assert all((stage / "foreign").read_text() == "preserve" for stage in stages)
    assert len([call for call in diagnostic.calls() if call["tool"] == "mkdir"]) == min(
        collisions + 1, 8
    )


def test_signal_cleans_owned_stage(diagnostic: DiagnosticFixture) -> None:
    diagnostic.settings["behaviors"]["curl"] = "signal"
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 143
    assert "SECRET" not in result.stdout + result.stderr
    assert rows(result)["DIAGNOSTIC.SUMMARY"][-1] == "diagnostic interrupted"
    diagnostic.assert_clean()


@pytest.mark.parametrize(("behavior", "status"), [("signal", 143), ("signal-hup", 129)])
def test_interrupted_stage_creation_stops_retries(
    diagnostic: DiagnosticFixture,
    behavior: str,
    status: int,
) -> None:
    diagnostic.settings["behaviors"]["mkdir"] = behavior
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == status
    assert rows(result)["DIAGNOSTIC.SUMMARY"][-1] == "diagnostic interrupted"
    assert len([call for call in diagnostic.calls() if call["tool"] == "mkdir"]) == 1
    diagnostic.assert_clean()


def test_missing_sh_ignores_inherited_private_variable(diagnostic: DiagnosticFixture) -> None:
    diagnostic.router.path("bin/sh").unlink()
    result = diagnostic.run()
    assert result.returncode == 1
    report = rows(result)
    assert report["FLOCK.OPTIONS"][0] == "SKIP"
    assert "NATIVE.SH" in report["FLOCK.OPTIONS"][-1]
    assert not any(call["tool"] == "flock" for call in diagnostic.calls())
    assert "SECRET" not in result.stdout + result.stderr
    diagnostic.assert_clean()


def test_unexpected_output_is_bounded_and_redacted(diagnostic: DiagnosticFixture) -> None:
    diagnostic.settings["behaviors"]["curl"] = "flood"
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 1
    assert rows(result)["CURL.OPTIONS"][0] == "FAIL"
    assert "SECRET" not in result.stdout + result.stderr
    diagnostic.assert_clean()


def test_symlink_fixture_failure_skips_readlink_probe(diagnostic: DiagnosticFixture) -> None:
    diagnostic.settings["behaviors"]["ln"] = "error"
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 1
    report = rows(result)
    assert report["LN.FIXTURE"][0] == "FAIL"
    assert report["READLINK.CANONICAL"][0] == "SKIP"
    assert "LN.FIXTURE" in report["READLINK.CANONICAL"][-1]
    assert "SECRET" not in result.stdout + result.stderr
    diagnostic.assert_clean()


def test_owned_stage_write_failure_is_visible(diagnostic: DiagnosticFixture) -> None:
    diagnostic.settings["behaviors"]["mkdir"] = "readonly-stage"
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 1
    report = rows(result)
    assert report["RAM.IO"][0] == "FAIL"
    assert report["RAM.CLEANUP"][0] == "PASS"
    assert report["DIAGNOSTIC.SUMMARY"][0] == "FAIL"
    diagnostic.assert_clean()


def test_cleanup_failure_changes_incomplete_to_failed(diagnostic: DiagnosticFixture) -> None:
    diagnostic.settings["behaviors"]["rm"] = "error"
    diagnostic.save()
    result = diagnostic.run()
    assert result.returncode == 1
    report = rows(result)
    assert report["RAM.CLEANUP"][0] == "FAIL"
    assert report["DIAGNOSTIC.SUMMARY"][0] == "FAIL"
    assert "SECRET" not in result.stdout + result.stderr
    stages = list(diagnostic.router.path("ram/tmp").glob("cfmgr-diagnostic.*"))
    assert len(stages) == 1 and stages[0].stat().st_mode & 0o777 == 0o700
    assert all(
        path.stat().st_mode & 0o777 == 0o600
        for path in stages[0].iterdir()
        if not path.is_symlink()
    )


def test_relative_entry_ignores_spoofed_pwd(diagnostic: DiagnosticFixture) -> None:
    result = diagnostic.router.run(
        "PWD=/opt/SECRET; export PWD\nexec './checkout with spaces/cfmgr' --doctor\n",
        timeout=15,
    )
    assert result.returncode == 3, result.stdout + result.stderr
    assert rows(result)["RAM.CLEANUP"][0] == "PASS"
    diagnostic.assert_clean()


@pytest.mark.parametrize("arguments", [[], ["--doctor", "extra"], ["--version", "extra"]])
def test_invalid_cli_argument_count_never_sources_module(
    diagnostic: DiagnosticFixture,
    arguments: list[str],
) -> None:
    diagnostic.wrapper.write_text("printf 'SECRET-module-loaded'\nexit 99\n")
    result = diagnostic.router.run(
        f'exec {shlex.quote(str(diagnostic.checkout / "cfmgr"))} "$@"\n',
        arguments,
    )
    assert result.returncode == 2
    assert "SECRET" not in result.stdout + result.stderr
    assert not diagnostic.calls()


def test_sourcing_library_has_no_side_effects(router: RouterHarness) -> None:
    result = router.run(
        "set -f\numask 027\nSENTINEL=preserved\ntrap ':' TERM\n"
        "before=$(set +o); before_umask=$(umask); before_cwd=$PWD; before_trap=$(trap)\n"
        f". {shlex.quote(str(SOURCE))}\n"
        '[ "$SENTINEL" = preserved ] && [ "$before" = "$(set +o)" ] && '
        '[ "$before_umask" = "$(umask)" ] && [ "$before_cwd" = "$PWD" ] && '
        '[ "$before_trap" = "$(trap)" ]\n'
    )
    assert result.returncode == 0 and result.stdout == result.stderr == ""
    assert not list(router.path("ram/tmp").glob("cfmgr-diagnostic.*"))


@pytest.mark.busybox
@pytest.mark.matrix("V75", evidence="busybox")
def test_explicit_busybox_shell_with_synthetic_native_tools(busybox_router: RouterHarness) -> None:
    diagnostic = DiagnosticFixture(busybox_router)
    result = busybox_router.run(
        f". {shlex.quote(str(SOURCE))}\ncfmgr_diagnostic_test "
        f"{shlex.quote(str(busybox_router.path('bin')))} "
        f"{shlex.quote(str(busybox_router.path('ram/tmp')))}\n",
        timeout=15,
    )
    assert result.returncode == 3
    assert rows(result)["RAM.STAGE"][0] == "PASS"
    diagnostic.assert_clean()
