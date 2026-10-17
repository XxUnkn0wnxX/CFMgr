"""Read-only history adapter contracts; host fixtures do not qualify Scribe tools."""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from runtime_awk import awk_arguments
from test_prerequisites import shell as prerequisite_shell

shell = prerequisite_shell
ROOT = Path(__file__).resolve().parents[1]
PARSER = "cfmgr-parser:backup_history"
RULE = """/opt/var/log/ddns.log {
    size 7M
    rotate 2
    maxage 0
    minage 0
    minsize 0
    maxsize 0
    start 1
    nocompress
    nodelaycompress
    nodateext
    missingok
    notifempty
    copytruncate
}
"""
GLOBAL = """weekly
minsize 512k
maxsize 4096k
rotate 4
maxage 30
delaycompress
create
dateext
missingok
notifempty
sharedscripts
postrotate
    /usr/bin/killall -HUP syslog-ng
endscript
"""
DEBUG = """reading config file /opt/etc/logrotate.conf
including /opt/etc/logrotate.d
reading config file A01global
reading config file cfmgr-ddns
reading config file messages
Allocating hash table for state file, size 64 entries
Handling 2 logs
rotating pattern: /opt/var/log/ddns.log  7340032 bytes (2 rotations)
considering log /opt/var/log/ddns.log
  log does not need rotating (log size is below the 'size' threshold)
rotating pattern: /opt/var/log/messages  4194304 bytes (4 rotations)
considering log /opt/var/log/messages
  log /opt/var/log/messages does not exist -- skipping
"""


@pytest.fixture(scope="module")
def awk_programs() -> list[list[str]]:
    awk = shutil.which("awk")
    assert awk
    commands = [[awk]]
    if os.environ.get("CFMGR_REQUIRE_BUSYBOX") == "1":
        busybox = shutil.which("busybox")
        assert (
            busybox
            and Path(busybox).resolve()
            == (ROOT / ".tmp/native-busybox/bin/busybox").resolve()
        )
        commands.append([busybox, "awk"])
    return commands


def parse(awk, mode, data, **environment):
    return subprocess.run(
        awk_arguments([*awk, "-f", str(PARSER)]),
        input=data.encode() if isinstance(data, str) else data,
        capture_output=True,
        check=False,
        env={
            **os.environ,
            "LC_ALL": "C",
            "CFMGR_HISTORY_MODE": mode,
            "CFMGR_HISTORY_LIMIT": "1048576",
            **environment,
        },
        timeout=5,
    )


def bundle(**changes):
    fields = {
        "script": 'readonly scribe_ver="v3.2.12"\nreadonly scriptVer_TAG="26041123"\n',
        "scribe-config": "SYSLOG_LOC=/tmp/syslog.log\nLR_CRONJOB_HOUR=3\n",
        "cron": "5 */3 * * * /jffs/scripts/scribe LogRotate #scribeLogRotate#\n",
        "process": "PROC 123 4000 "
        + b"/opt/sbin/syslog-ng".hex()
        + " 1 "
        + b"/opt/sbin/syslog-ng".hex()
        + " END\nCROND 124 4001 "
        + b"/var/spool/cron/crontabs".hex()
        + " END\n",
        "syslog-config": '@version: 4.7\n@include "/opt/etc/syslog-ng.d/"\n',
        "rotate-config": "include /opt/etc/logrotate.d\n",
        "rotate-debug": DEBUG,
        "syslog-version": "syslog-ng 4.7.1\n",
        "logrotate-version": "logrotate 3.22.0\n",
    }
    fields.update(changes)
    output = "".join(
        f"DATA {key} {(value or chr(10)).encode().hex()}\n"
        for key, value in fields.items()
    )
    for name, data in (
        ("A01global", GLOBAL),
        ("cfmgr-ddns", RULE),
        ("messages", "/opt/var/log/messages {\n size 4M\n}\n"),
    ):
        output += (
            f"FRAGMENT {('/opt/etc/logrotate.d/' + name).encode().hex()} "
            f"{data.encode().hex()}\n"
        )
    return output


def test_ready_profile_accepts_realistic_daemonized_process_and_observed_native_policy(
    awk_programs,
):
    for awk in awk_programs:
        result = parse(awk, "base", bundle())
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            b"BASE ready 3 123 4000 END\n",
            b"",
        )
        result = parse(
            awk,
            "assess",
            bundle(),
            CFMGR_HISTORY_FEATURE="ddns",
            CFMGR_HISTORY_POLICY="POLICY native - - - END",
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            b"EFFECTIVE ddns size 7340032 2 0 END\n",
            b"",
        )


@pytest.mark.parametrize(
    ("change", "reason"),
    [
        ({"script": 'readonly scribe_ver="v3.2.11"\n'}, "scribe-profile"),
        (
            {"cron": "5 */6 * * * /jffs/scripts/scribe LogRotate #scribeLogRotate#\n"},
            "rotation-schedule",
        ),
        ({"process": ""}, "inactive-or-ambiguous-process"),
        ({"syslog-config": '@include "/foreign/filters/"\n'}, "syslog-include"),
        ({"rotate-config": "include /foreign/logrotate.d\n"}, "unsupported-include"),
        ({"rotate-debug": DEBUG.replace("reading config file cfmgr-ddns\n", "")}, None),
    ],
)
def test_unready_base_is_explicit_without_execution(awk_programs, change, reason):
    for awk in awk_programs:
        expected_reason = reason
        result = parse(awk, "base", bundle(**change))
        if expected_reason is None:
            assert result.returncode == 0
            result = parse(
                awk,
                "assess",
                bundle(**change),
                CFMGR_HISTORY_FEATURE="ddns",
                CFMGR_HISTORY_POLICY="POLICY native - - - END",
            )
            expected_reason = "owned-rule-not-included"
        assert result.returncode != 0
        assert (
            result.stdout == f"CFMGR-HISTORY-ERROR 1 {expected_reason} END\n".encode()
        )


def test_cloudflared_saved_policy_tree_and_effective_rule_agreement(awk_programs):
    policy = {
        "mode": "weekly",
        "size": {"value": 12, "unit": "MiB"},
        "total_files": 4,
        "max_age_days": 7,
    }
    encoded = json.dumps(policy).encode()
    rule = (
        RULE.replace("ddns.log", "cloudflared.log")
        .replace("size 7M", "weekly\n    maxsize 12M")
        .replace("    maxsize 0\n", "")
        .replace("rotate 2", "rotate 3")
        .replace("maxage 0", "maxage 7")
    )
    source = bundle().replace(RULE.encode().hex(), rule.encode().hex())
    source = source.replace("cfmgr-ddns", "cfmgr-cloudflared").replace(
        b"cfmgr-ddns".hex(), b"cfmgr-cloudflared".hex()
    )
    # The embedded debug stream is encoded independently of the fragment path.
    source = source.replace(
        DEBUG.encode().hex(),
        DEBUG.replace("cfmgr-ddns", "cfmgr-cloudflared")
        .replace("ddns.log", "cloudflared.log")
        .encode()
        .hex(),
    )
    for awk in awk_programs:
        result = subprocess.run(
            awk_arguments(
                [
                    *awk,
                    "-v",
                    f"cfmgr_json_size={len(encoded)}",
                    "-v",
                    "cfmgr_json_mode=tree",
                    "-f",
                    "cfmgr-parser:json",
                    "-f",
                    str(PARSER),
                ]
            ),
            input=encoded,
            capture_output=True,
            check=False,
            env={
                **os.environ,
                "LC_ALL": "C",
                "CFMGR_HISTORY_MODE": "policy",
                "CFMGR_HISTORY_FEATURE": "cloudflared",
                "CFMGR_HISTORY_LIMIT": "1048576",
            },
            timeout=5,
        )
        assert (result.returncode, result.stdout, result.stderr) == (
            0,
            b"POLICY weekly 12582912 3 7 END\n",
            b"",
        )
        for expected, status in (
            (result.stdout.decode().strip(), 0),
            ("POLICY weekly 12582912 4 7 END", 1),
        ):
            assessed = parse(
                awk,
                "assess",
                source,
                CFMGR_HISTORY_FEATURE="cloudflared",
                CFMGR_HISTORY_POLICY=expected,
            )
            assert assessed.returncode == status, assessed.stdout
            if status:
                assert (
                    assessed.stdout
                    == b"CFMGR-HISTORY-ERROR 1 saved-policy-mismatch END\n"
                )


def test_count_one_omits_history_age_without_losing_saved_preference(awk_programs):
    rule = (
        RULE.replace("ddns.log", "cloudflared.log")
        .replace("rotate 2", "rotate 0")
        .replace("    maxage 0\n", "")
    )
    source = (
        bundle()
        .replace(RULE.encode().hex(), rule.encode().hex())
        .replace(b"cfmgr-ddns".hex(), b"cfmgr-cloudflared".hex())
    )
    source = source.replace(
        DEBUG.encode().hex(),
        DEBUG.replace("cfmgr-ddns", "cfmgr-cloudflared")
        .replace("ddns.log", "cloudflared.log")
        .encode()
        .hex(),
    )
    for awk in awk_programs:
        result = parse(
            awk,
            "assess",
            source,
            CFMGR_HISTORY_FEATURE="cloudflared",
            CFMGR_HISTORY_POLICY="POLICY size 7340032 0 7 END",
        )
        assert (result.returncode, result.stdout) == (
            0,
            b"EFFECTIVE cloudflared size 7340032 0 0 END\n",
        )


def test_installed_schedule_alone_does_not_prove_cron_is_running(awk_programs):
    process = f"PROC 123 4000 {b'/opt/sbin/syslog-ng'.hex()} 1 {b'/opt/sbin/syslog-ng'.hex()} END\n"
    for awk in awk_programs:
        result = parse(awk, "base", bundle(process=process))
        assert (
            result.stdout
            == b"CFMGR-HISTORY-ERROR 1 inactive-or-ambiguous-process END\n"
        )


def test_conflicting_family_and_inherited_policy_are_not_silently_admitted(
    awk_programs,
):
    cases = [
        (
            bundle().replace(
                GLOBAL.encode().hex(),
                (GLOBAL + "olddir /foreign/history\n").encode().hex(),
            ),
            "unsupported-global-policy",
        ),
        (
            bundle().replace(
                RULE.encode().hex(), RULE.replace("    maxsize 0\n", "").encode().hex()
            ),
            "unsafe-effective-policy",
        ),
        (
            bundle().replace(
                b"/opt/var/log/messages {\n size 4M\n}\n".hex(),
                b"/opt/var/log/*.log {\n size 4M\n}\n".hex(),
            ),
            "ambiguous-family-coverage",
        ),
        (
            bundle().replace(
                RULE.encode().hex(),
                RULE.replace("    nocompress\n", "    compress\n").encode().hex(),
            ),
            "unsupported-rule",
        ),
    ]
    for awk in awk_programs:
        for source, reason in cases:
            result = parse(
                awk,
                "assess",
                source,
                CFMGR_HISTORY_FEATURE="ddns",
                CFMGR_HISTORY_POLICY="POLICY native - - - END",
            )
            assert result.returncode != 0
            assert result.stdout == f"CFMGR-HISTORY-ERROR 1 {reason} END\n".encode()


def test_family_enumerates_actual_files_without_iterating_saved_count(awk_programs):
    source = "ddns.log\nddns.log.1\nddns.log.2147483647\nforeign.log\n"
    for awk in awk_programs:
        result = parse(
            awk,
            "family",
            "".join(f"{b:02x}\n" for b in source.encode()),
            CFMGR_HISTORY_FEATURE="ddns",
            CFMGR_HISTORY_ROTATE="2147483647",
        )
        assert result.returncode == 0
        assert result.stdout.count(b"MEMBER ") == 3
        assert result.stdout.endswith(b"FAMILY 3 END\n")
        result = parse(
            awk,
            "family",
            "".join(f"{b:02x}\n" for b in b"ddns.log.1.gz\n"),
            CFMGR_HISTORY_FEATURE="ddns",
            CFMGR_HISTORY_ROTATE="2",
        )
        assert (
            result.stdout == b"CFMGR-HISTORY-ERROR 1 unsupported-history-family END\n"
        )


def test_canonical_target_coverage_checks_path_and_filesystem_inode(awk_programs):
    logical = b"/opt/var/log/ddns.log".hex()
    canonical = b"/tmp/mnt/drive/entware/var/log/ddns.log".hex()
    unrelated = b"/var/log/other.log".hex()
    source = f"OWN {logical} {canonical} 8:1 42 live\nTARGET {logical} {canonical} 8:1 42 owning\n"
    for awk in awk_programs:
        for actual, device, inode, status in (
            (unrelated, "8:2", "42", 0),
            (canonical, "8:1", "42", 1),
            (unrelated, "8:1", "42", 1),
        ):
            result = parse(
                awk,
                "audit",
                source + f"TARGET {unrelated} {actual} {device} {inode} foreign\n",
            )
            assert result.returncode == status
            assert result.stdout == (
                b"CFMGR-HISTORY-ERROR 1 foreign-family-alias END\n"
                if status
                else b"COVERAGE ready END\n"
            )


DRIVER = r"""
import hashlib, json, os, stat, subprocess, sys
from pathlib import Path
root, context, repository, output, error, mode, *args = sys.argv[1:]
root, context, repository = map(Path, (root, context, repository))
sys.path.insert(0, str(repository / "tests"))
from runtime_awk import awk_program
if os.fstat(0).st_ino != (context/"config.lock").stat().st_ino:
    sys.exit(77)
def path(logical):
    p = Path(logical)
    return p if str(p).startswith(str(root)) or str(p).startswith(str(context)) else root / logical.lstrip("/")
def write(value):
    Path(output).write_bytes(value if isinstance(value, bytes) else value.encode())
try:
    if mode == "parse":
        kind, source, *extra = args
        env = dict(os.environ, LC_ALL="C", CFMGR_HISTORY_MODE=kind,
                   CFMGR_HISTORY_LIMIT="1048576")
        if extra:
            env["CFMGR_HISTORY_LABEL"] = extra[0]
            env["CFMGR_HISTORY_FEATURE"] = extra[0]
        if len(extra)>1:
            env["CFMGR_HISTORY_POLICY"] = extra[1]
            env["CFMGR_HISTORY_ROTATE"] = extra[1]
        command = json.loads(os.environ["HISTORY_TEST_AWK"])
        with open(source,"rb") as inp, open(output,"wb") as out, open(error,"wb") as err:
            result = subprocess.run([*command,awk_program("backup_history")],
                                    stdin=inp,stdout=out,stderr=err,env=env,check=False)
        sys.exit(result.returncode)
    elif mode == "policy":
        feature, encoded = args
        data=bytes.fromhex(encoded)
        env=dict(os.environ, LC_ALL="C", CFMGR_HISTORY_MODE="policy",
                 CFMGR_HISTORY_FEATURE=feature, CFMGR_HISTORY_LIMIT="1048576")
        command=json.loads(os.environ["HISTORY_TEST_AWK"])
        result=subprocess.run([*command,"-v",f"cfmgr_json_size={len(data)}","-v","cfmgr_json_mode=tree",
                               awk_program("json", "backup_history")],
                              input=data,capture_output=True,env=env,check=False)
        write(result.stdout); Path(error).write_bytes(result.stderr); sys.exit(result.returncode)
    elif mode in ("read","read-private"):
        data=path(args[0]).read_bytes()
        if args[0]=="/jffs/scripts/scribe": data=data[:8192]
        if len(data)>262144: sys.exit(1)
        write("".join(f"{b:02x}\n" for b in data))
    elif mode=="hash":
        write(hashlib.sha256(path(args[0]).read_bytes()).hexdigest()+" "+args[0]+"\n")
    elif mode=="meta":
        info=path(args[0]).lstat()
        write(f"{info.st_ino:7d} {stat.filemode(info.st_mode)} {info.st_nlink} 0 0 {info.st_size} {args[0]}\n")
    elif mode=="readlink": write(os.readlink(path(args[0]))+"\n")
    elif mode=="tool":
        if not os.access(path(args[0]),os.X_OK): sys.exit(1)
    elif mode in ("syslog-version","syslog-check","logrotate-version","logrotate-debug"):
        tool=path("/opt/sbin/"+("syslog-ng" if mode.startswith("syslog") else "logrotate"))
        operands={"syslog-version":["--version"],"syslog-check":["--syntax-only","-f","/opt/etc/syslog-ng.conf"],
                  "logrotate-version":["--version"],"logrotate-debug":["-d","/opt/etc/logrotate.conf"]}[mode]
        result=subprocess.run([str(tool),*operands],capture_output=True,check=False,
                              env=dict(os.environ,HISTORY_FIXTURE_ROOT=str(root)))
        write(result.stderr if mode=="logrotate-debug" else result.stdout)
        if mode!="logrotate-debug": Path(error).write_bytes(result.stderr)
        sys.exit(result.returncode)
    elif mode in ("cron","processes"): write((root/("cron" if mode=="cron" else "process")).read_bytes())
    elif mode=="list": write("\n".join(sorted(p.name for p in path(args[0]).iterdir()))+"\n")
    elif mode=="resolve":
        target=path(args[0]).resolve(strict=True); info=target.stat()
        write(f"RESOLVED {str(target).encode().hex()} {os.major(info.st_dev)}:{os.minor(info.st_dev)} {info.st_ino} END\n")
    elif mode=="lock":
        import fcntl
        fcntl.flock(4,fcntl.LOCK_EX|fcntl.LOCK_NB)
    else: sys.exit(2)
except (OSError,ValueError): sys.exit(1)
"""


@pytest.fixture
def history(tmp_path, awk_programs):
    root, ram = tmp_path / "root", tmp_path / "ram"
    root.mkdir()
    ram.mkdir()
    fields = {
        "/jffs/scripts/scribe": '#!/bin/sh\nreadonly scribe_ver="v3.2.12"\nreadonly scriptVer_TAG="26041123"\n',
        "/jffs/addons/scribe.d/config": "SYSLOG_LOC=/tmp/syslog.log\nLR_CRONJOB_HOUR=3\n",
        "/opt/etc/syslog-ng.conf": '@version: 4.7\n@include "/opt/etc/syslog-ng.d/"\n',
        "/opt/etc/logrotate.conf": "include /opt/etc/logrotate.d\n",
        "/opt/etc/logrotate.d/A01global": GLOBAL,
        "/opt/etc/logrotate.d/cfmgr-ddns": RULE,
        "/opt/etc/logrotate.d/messages": "/opt/var/log/messages {\n size 4M\n}\n",
        "/opt/var/log/ddns.log": "[CFMGR] DDNS: Info: retained Off history\n",
        "/opt/var/log/ddns.log.1": "older history\n",
        "/tmp/scribeLogRotate.flock": "",
        "/cron": "5 */3 * * * /jffs/scripts/scribe LogRotate #scribeLogRotate#\n",
        "/process": f"PROC 123 4000 {b'/opt/sbin/syslog-ng'.hex()} 1 {b'/opt/sbin/syslog-ng'.hex()} END\nCROND 124 4001 {b'/var/spool/cron/crontabs'.hex()} END\n",
        "/debug": DEBUG,
    }
    for name, value in fields.items():
        target = root / name.lstrip("/")
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(value)
        target.chmod(0o600)
    (root / "opt/etc/syslog-ng.d").mkdir()
    (root / "opt/bin").mkdir()
    (root / "opt/bin/scribe").symlink_to("/jffs/scripts/scribe")
    tools = {
        "syslog-ng": '#!/bin/sh\ncase "$1" in --version) echo "syslog-ng 4.7.1";; --syntax-only) exit 0;; *) exit 42;; esac\n',
        "logrotate": '#!/bin/sh\ncase "$1" in --version) echo "logrotate 3.22.0";; -d) cat "$HISTORY_FIXTURE_ROOT/debug" >&2;; *) exit 42;; esac\n',
    }
    for name, body in tools.items():
        target = root / "opt/sbin" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body)
        target.chmod(0o700)
    sha = hashlib.sha256(RULE.encode()).hexdigest()
    rows = [
        "CFMGR-PAYLOAD-PLAN 1 2 7",
        "STATE ddns 1 0",
        "STATE ip_sync 0 0",
        "STATE cloudflared 0 0",
        f"OWNER history.ddns {b'/opt/var/log/ddns.log'.hex()} 3 -",
        f"OWNER history-rule.ddns {b'/opt/etc/logrotate.d/cfmgr-ddns'.hex()} 3 {sha}",
        f"LOG ddns 1 0 0 {b'{"version":1}'.hex()}",
        "LOG ip_sync 0 0 0 -",
        "LOG cloudflared 0 0 0 -",
    ]
    plan = ram / "plan"
    plan.write_text("\n".join([*rows, f"END {len(rows)}"]) + "\n")
    driver = ram / "driver.py"
    driver.write_text(DRIVER)
    library = ram / "../backup.sh"
    body = (ROOT / "modules/backup.sh").read_text()
    body = body.replace(
        "/tmp/scribeLogRotate.flock", str(root / "tmp/scribeLogRotate.flock")
    )
    if sys.platform == "darwin":
        # fdescfs cannot traverse directory FDs; native Linux keeps actual pins.
        body = body.replace("/proc/self/fd/5", str(ram)).replace(
            "/proc/self/fd/4", str(root / "tmp/scribeLogRotate.flock")
        )
    library.write_text(body)
    return root, ram, plan, driver, library, awk_programs[-1]


def run_adapter(history, shell, after=""):
    root, ram, plan, driver, library, awk = history
    script = (
        r"""
        . "$1"
        cfmgr_history_context=$2
        exec 5<"$2"
        : >"$2/config.lock"
        exec 0<"$2/config.lock"
        cfmgr_backup_history_attached() { [ -d "$cfmgr_history_context" ]; }
        # Explicit host fixture callbacks: no production RAM/native claim.
        cfmgr_history_runtime_reserve() { :; }
        cfmgr_history_runtime_created() { :; }
        cfmgr_history_runtime_consume() { :; }
        cfmgr_history_runtime_checkpoint() { :; }
        cfmgr_history_runtime_write() { printf '%s\n' "$2" >>"$1"; }
        cfmgr_backup_history_probe() {
            history_test_seq=$((${history_test_seq:-0}+1))
            cfmgr_probe_stdout=$cfmgr_history_context/probe-$history_test_seq.out
            cfmgr_probe_stderr=$cfmgr_history_context/probe-$history_test_seq.err
            : >"$cfmgr_probe_stdout"
            : >"$cfmgr_probe_stderr"
            if "$HISTORY_TEST_PYTHON" "$HISTORY_TEST_DRIVER" "$HISTORY_TEST_ROOT" "$cfmgr_history_context" "$HISTORY_TEST_REPO" "$cfmgr_probe_stdout" "$cfmgr_probe_stderr" "$@"; then
                cfmgr_probe_exit=0
            else cfmgr_probe_exit=$?; fi
            cfmgr_probe_status=reaped
            [ "$cfmgr_probe_exit" = 0 ]
        }
        cfmgr_backup_history_observe "$3" || exit $?
    """
        + after
    )
    return subprocess.run(
        awk_arguments(
            [*shell, "-c", script, "history-test", str(library), str(ram), str(plan)]
        ),
        capture_output=True,
        check=False,
        env={
            **os.environ,
            "LC_ALL": "C",
            "HISTORY_TEST_PYTHON": sys.executable,
            "HISTORY_TEST_DRIVER": str(driver),
            "HISTORY_TEST_ROOT": str(root),
            "HISTORY_TEST_REPO": str(ROOT),
            "HISTORY_TEST_AWK": json.dumps(awk),
        },
        timeout=30,
    )


def test_off_history_adapter_observes_and_revalidates_under_existing_lock(
    history, shell
):
    root, _ram, _plan, _driver, _library, _awk = history
    before = {
        str(p): p.read_bytes()
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink()
    }
    result = run_adapter(
        history,
        shell,
        'cfmgr_backup_history_lock || exit $?; cat "$cfmgr_history_output"; cfmgr_backup_history_release',
    )
    assert result.returncode == 0, result.stderr.decode()
    assert b"EFFECTIVE ddns size 7340032 2 0 END\n" in result.stdout
    assert b"STATE ddns included eligible-owned-history END\n" in result.stdout
    assert result.stdout.count(b"FILE history.ddns ") == 2
    assert before == {
        str(p): p.read_bytes()
        for p in root.rglob("*")
        if p.is_file() and not p.is_symlink()
    }


def test_missing_scribe_is_unavailable_without_unmanaged_output(history, shell):
    root, *_ = history
    (root / "opt/bin/scribe").unlink()
    result = run_adapter(
        history,
        shell,
        'cfmgr_backup_history_lock || exit $?; cat "$cfmgr_history_output"; cfmgr_backup_history_release',
    )
    assert result.returncode == 0
    assert b"STATE ddns unavailable scribe-unavailable END\n" in result.stdout
    assert b"FILE " not in result.stdout


def test_owned_rule_substitution_is_rejected_at_rotation_checkpoint(history, shell):
    result = run_adapter(
        history,
        shell,
        'printf "\\n# changed\\n" >>"$HISTORY_TEST_ROOT/opt/etc/logrotate.d/cfmgr-ddns"; cfmgr_backup_history_lock',
    )
    assert result.returncode != 0


def test_live_symlink_is_never_admitted_as_owned_history(history, shell):
    root, *_ = history
    live = root / "opt/var/log/ddns.log"
    live.unlink()
    live.symlink_to(root / "opt/var/log/ddns.log.1")
    result = run_adapter(history, shell, 'cat "$cfmgr_history_output"')
    assert result.returncode == 0
    assert b"STATE ddns unavailable unsupported-or-stale-history END\n" in result.stdout
    assert b"FILE " not in result.stdout


def test_foreign_stanza_cannot_cover_owned_history_through_ancestor_alias(
    history, shell
):
    root, *_ = history
    (root / "foreign").mkdir()
    (root / "foreign/logs").symlink_to(root / "opt/var/log", target_is_directory=True)
    (root / "opt/etc/logrotate.d/foreign-alias").write_text(
        "/foreign/logs/ddns.log {\n    size 1M\n}\n"
    )
    debug = DEBUG.replace(
        "Handling 2 logs\n", "reading config file foreign-alias\nHandling 3 logs\n"
    )
    debug += "rotating pattern: /foreign/logs/ddns.log  1048576 bytes (1 rotations)\nconsidering log /foreign/logs/ddns.log\n"
    (root / "debug").write_text(debug)
    result = run_adapter(history, shell, 'cat "$cfmgr_history_output"')
    assert result.returncode == 0
    assert b"STATE ddns unavailable unsupported-or-stale-history END\n" in result.stdout
    assert b"FILE " not in result.stdout
