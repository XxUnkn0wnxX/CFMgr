"""Typed, private diagnostic record and Scribe log projection."""

from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest
from runtime_awk import awk_arguments

pytest_plugins = ["test_config_observation"]

ROOT = Path(__file__).resolve().parents[1]
LOGGING = ROOT / "modules/lib/logging.sh"
EXECUTION = ROOT / "modules/lib/execution.sh"
STATUS = ROOT / "modules/status.sh"
UTC = "2025-01-02T03:04:05Z"


def frame(
    source: bytes, commands, *, excerpt: bool = False
) -> subprocess.CompletedProcess:
    return subprocess.run(
        awk_arguments(
            [
                *commands[1],
                "-v",
                f"expected_bytes={len(source)}",
                "-v",
                f"excerpt={int(excerpt)}",
                "-f",
                "cfmgr-parser:log_frame",
            ]
        ),
        input=source,
        capture_output=True,
        env={**os.environ, "LC_ALL": "C"},
        check=False,
        timeout=5,
    )


def sanitize(
    source: bytes, commands, *, excerpt: bool = False, source_role: str = "cloudflared"
) -> subprocess.CompletedProcess:
    framed = frame(source, commands, excerpt=excerpt)
    if framed.returncode:
        return framed
    return subprocess.run(
        awk_arguments(
            [
                *commands[1],
                "-v",
                f"cfmgr_json_size={len(framed.stdout)}",
                "-v",
                "cfmgr_json_mode=tree",
                "-v",
                f"cfmgr_log_excerpt={int(excerpt)}",
                "-v",
                f"cfmgr_log_source={source_role}",
                "-f",
                "cfmgr-parser:json",
                "-f",
                "cfmgr-parser:log_sanitize",
            ]
        ),
        input=framed.stdout,
        capture_output=True,
        env={**os.environ, "LC_ALL": "C"},
        check=False,
        timeout=5,
    )


@pytest.mark.parametrize(
    "source,expected",
    [
        (
            b'{"level":"info","time":"2025-01-02T03:04:05Z","message":"Registered tunnel connection","connIndex":1,"connection":"UUID-CANARY-731","ip":"198.41.200.63","location":"syd06","protocol":"quic"}\n',
            b"Cloudflared: info: Registered tunnel connection index=1 protocol=quic at=2025-01-02T03:04:05Z\n",
        ),
        (
            b'{"level":"error","time":"2025-01-02T03:04:05Z","message":"Lost connection with the edge","error":"PRIVATE-ERROR-CANARY"}\n',
            b"Cloudflared: error: Lost connection with the edge at=2025-01-02T03:04:05Z\n",
        ),
        (
            b'{"level":"info","time":"2025-01-02T03:04:05Z","message":"Retrying connection in up to 2s"}\n',
            b"Cloudflared: info: Retrying connection in 2s at=2025-01-02T03:04:05Z\n",
        ),
    ],
)
def test_json_scribe_rows_reconstruct_allowlisted_events(commands, source, expected):
    result = sanitize(source, commands)
    assert result.returncode == 0, result.stderr
    assert expected in result.stdout
    for secret in (
        b"UUID-CANARY",
        b"198.41.200.63",
        b"syd06",
        b"PRIVATE-ERROR-CANARY",
    ):
        assert secret not in result.stdout
    assert result.stdout.endswith(b"END 1 0 0\n")


def test_console_scribe_row_masks_identifiers_and_preserves_safe_fields(commands):
    source = (
        f"{UTC} INF Registered tunnel connection connIndex=1 "
        "connection=deadbeef-cafe-7310 event=0 ip=198.41.200.63 "
        "location=syd06 protocol=quic\n"
    ).encode()
    result = sanitize(source, commands)
    assert result.returncode == 0, result.stderr
    assert (
        b"Cloudflared: info: Registered tunnel connection "
        b"index=1 protocol=quic at=" + UTC.encode() + b"\n"
    ) in result.stdout
    for secret in (b"deadbeef-cafe-7310", b"198.41.200.63", b"syd06"):
        assert secret not in result.stdout
    assert result.stdout.endswith(b"END 1 0 0\n")


@pytest.mark.parametrize("version", ["SECRET_CANARY", "1.2.3-CANARY", "1.2.3.4.5"])
def test_version_event_rejects_token_like_or_unbounded_values(commands, version):
    source = (
        f'{{"level":"info","time":"{UTC}","message":"Version {version}"}}\n'
    ).encode()
    result = sanitize(source, commands)
    assert result.returncode == 0, result.stderr
    assert b"Version " + version.encode() not in result.stdout
    assert b"source record redacted; capture incomplete" in result.stdout
    assert result.stdout.endswith(b"END 0 1 1\n")


def test_numeric_version_event_and_timestamp_are_bounded(commands):
    source = (
        f'{{"level":"info","time":"{UTC}","message":"Version 2025.1.0"}}\n'.encode()
    )
    result = sanitize(source, commands)
    assert result.returncode == 0, result.stderr
    assert b"Cloudflared: info: Version 2025.1.0 at=" + UTC.encode() in result.stdout
    assert result.stdout.endswith(b"END 1 0 0\n")

    for timestamp in (
        "2025-02-31T03:04:05Z",
        "2025-01-02T24:04:05Z",
        "2025-01-02T03:04:05.1234567890Z",
        "2025-01-02T03:04:05." + "1" * 100 + "Z",
    ):
        malformed = f'{{"level":"info","time":"{timestamp}","message":"Starting tunnel"}}\n'.encode()
        rejected = sanitize(malformed, commands)
        assert rejected.returncode == 0, rejected.stderr
        assert b"Starting tunnel at=" not in rejected.stdout
        assert rejected.stdout.endswith(b"END 0 1 1\n")


def test_ddns_and_ip_sync_sources_reconstruct_only_evidenced_event_forms(
    commands,
):
    ddns = b"[CFMGR] DDNS: Info: IPv4 updated: 203.0.113.10\n"
    result = sanitize(ddns, commands, source_role="ddns")
    assert b"[CFMGR] DDNS: Info: IPv4 updated: 203.0.113.10\n" in result.stdout
    assert result.stdout.endswith(b"END 1 0 0\n")

    ip_sync = b"[CFMGR] IP-Sync: Warning: Rate limited; retry in 5m\n"
    result = sanitize(ip_sync, commands, source_role="ip_sync")
    assert b"[CFMGR] IP-Sync: Warning: Rate limited; retry in 5m\n" in result.stdout
    assert result.stdout.endswith(b"END 1 0 0\n")

    for wrong_source, record in (
        ("ddns", b"[CFMGR] IP-Sync: Warning: Rate limited; retry in 5m\n"),
        ("ip_sync", ddns),
        (
            "ddns",
            b'{"level":"info","time":"'
            + UTC.encode()
            + b'","message":"Starting tunnel"}\n',
        ),
    ):
        rejected = sanitize(record, commands, source_role=wrong_source)
        assert b"source record redacted; capture incomplete" in rejected.stdout
        assert b"Cloudflared:" not in rejected.stdout
        assert rejected.stdout.endswith(b"END 0 1 1\n")


def test_unknown_json_and_free_text_are_redacted_and_incomplete(commands):
    source = (
        b'{"level":"error","time":"2025-01-02T03:04:05Z",'
        b'"message":"failed request Authorization: Bearer TOKEN-CANARY-908",'
        b'"url":"https://private.example/CANARY"}\n'
        b"unstructured API key=RAW-CANARY-123\n"
    )
    result = sanitize(source, commands)
    assert result.returncode == 0, result.stderr
    assert result.stdout.count(b"source record redacted; capture incomplete") == 2
    for secret in (b"TOKEN-CANARY-908", b"private.example", b"RAW-CANARY-123"):
        assert secret not in result.stdout
    assert result.stdout.endswith(b"END 0 2 1\n")


def test_excerpt_discards_partial_first_line_and_marks_capture_incomplete(
    commands,
):
    source = (
        b"partial-fragment\n"
        + b'{"level":"info","time":"'
        + UTC.encode()
        + b'","message":"Starting tunnel"}\n'
    )
    result = sanitize(source, commands, excerpt=True)
    assert result.returncode == 0, result.stderr
    assert b"partial-fragment" not in result.stdout
    assert b"Starting tunnel" in result.stdout
    assert result.stdout.endswith(b"END 1 0 1\n")


@pytest.mark.parametrize(
    "source",
    [
        b'{"level":"info","time":"x","message":"Starting tunnel"}',
        b"safe line\x00binary\n",
        b"unsafe\x01control\n",
        b"x" * 4097 + b"\n",
    ],
)
def test_frame_refuses_ambiguous_or_unbounded_source(commands, source):
    assert frame(source, commands).returncode != 0


def test_frame_enforces_total_snapshot_bound(commands):
    assert frame((b"x" * 4096 + b"\n") * 7, commands).returncode != 0


def test_incomplete_trailing_record_fails_closed(commands):
    complete = (
        b'{"level":"info","time":"' + UTC.encode() + b'","message":"Starting tunnel"}\n'
    )
    incomplete = complete + b'{"level":"info","message":"TOKEN-CANARY'
    result = sanitize(incomplete, commands)
    assert result.returncode != 0
    assert b"Starting tunnel" not in result.stdout
    assert b"TOKEN-CANARY" not in result.stdout


def test_unknown_source_role_is_rejected(commands):
    result = sanitize(b"safe\n", commands, source_role="manager")
    assert result.returncode != 0
    assert b"Cloudflared" not in result.stdout


@pytest.mark.parametrize(
    "role,value,expected",
    [
        (
            "cloudflare_dns_update",
            "abcdefghXYZ",
            "Cloudflare API token (DNS update): ****XYZ\n",
        ),
        ("management_api", "123456789", "Cloudflare management API key: ****789\n"),
        ("runtime_tunnel", "short", "Cloudflared runtime tunnel token: ****\n"),
        (
            "cloudflare_dns_update",
            "eyJhbGci.payload.sig",
            "Cloudflare API token (DNS update): ****\n",
        ),
        ("certificate", "PrivateKeyCANARY111", "Cloudflare certificate: ****\n"),
    ],
)
def test_credential_formatter_discloses_only_eligible_opaque_suffix(
    commands, role, value, expected
):
    result = subprocess.run(
        [
            *commands[0],
            "-c",
            '. "$1"; cfmgr_logging_mask_credential "$2" "$3"',
            "logging-test",
            str(LOGGING),
            role,
            value,
        ],
        capture_output=True,
        env={**os.environ, "LC_ALL": "C"},
        check=False,
        timeout=5,
    )
    assert result.returncode == 0
    assert result.stdout.decode() == expected
    assert value.encode() not in result.stdout


CAPTURE_MOCK = r"""
cfmgr_log_capture() {
    if [ -f "$capture_calls" ]; then IFS= read -r capture_number <"$capture_calls"; else capture_number=0; fi
    capture_number=$((capture_number + 1))
    printf '%s\n' "$capture_number" >"$capture_calls"
    printf 'capture-%s\n' "$capture_number" >>"$trace"
    printf 'BEGIN %s %s\n%s\nEND\n' "$capture_number" "$1" "$2" >>"$payload"
    case $scenario in
    disabled-first)
        if [ "$capture_number" = 1 ]; then
            printf 'CFMGR-LOG-CAPTURE 1 disabled read - END\n'
        else printf 'CFMGR-LOG-CAPTURE 1 saved read - END\n'; fi
        ;;
    unavailable) printf 'CFMGR-LOG-CAPTURE 1 unavailable unavailable - END\n' ;;
    invalid) printf 'CAPTURE-RECEIPT-CANARY\n' ;;
    nonzero-saved) printf 'CFMGR-LOG-CAPTURE 1 saved read - END\n'; return 9 ;;
    mutate-state)
        cfmgr_probe_pid=CAPTURE-CHANGED
        cfmgr_probe_status=CAPTURE-CHANGED
        cfmgr_probe_exit=99
        printf 'CFMGR-LOG-CAPTURE 1 saved read - END\n'
        ;;
    *) printf 'CFMGR-LOG-CAPTURE 1 saved read - END\n' ;;
    esac
}
"""


def run_log_shell(commands, tmp_path, modules, body, *, scenario="saved", work_rc=0):
    trace = tmp_path / "log-trace"
    payload = tmp_path / "log-payload"
    calls = tmp_path / "capture-calls"
    script = (
        '. "$1"\n'
        + "\n".join(f'. "${{{index}}}"' for index in range(2, 2 + len(modules)))
        + "\n"
        + "trace=$"
        + str(2 + len(modules))
        + " payload=$"
        + str(3 + len(modules))
        + " capture_calls=$"
        + str(4 + len(modules))
        + " scenario=$"
        + str(5 + len(modules))
        + " work_rc=$"
        + str(6 + len(modules))
        + "\n"
        + CAPTURE_MOCK
        + "\n"
        + body
    )
    arguments = [
        *commands[0],
        "-c",
        script,
        "logging-consumer-test",
        str(LOGGING),
        *map(str, modules),
        str(trace),
        str(payload),
        str(calls),
        scenario,
        str(work_rc),
    ]
    result = subprocess.run(
        arguments,
        capture_output=True,
        env={**os.environ, "LC_ALL": "C"},
        check=False,
        timeout=10,
    )
    return result, trace, payload, calls


@pytest.mark.parametrize(
    ("work_rc", "expected_event"),
    [
        (0, b"CFMGR-EVENT 1 "),
        (7, b"failure 7\n"),
    ],
)
def test_live_status_consumer_flushes_start_before_work_and_keeps_outcome(
    commands, tmp_path, work_rc, expected_event
):
    body = r"""
cfmgr_log_available=1
_cfmgr_status_native_work() {
    printf 'work\n' >>"$trace"
    printf 'STDOUT-SECRET-CANARY\n'
    return "$work_rc"
}
cfmgr_status_native
"""
    result, trace, payload, calls = run_log_shell(
        commands, tmp_path, [STATUS], body, work_rc=work_rc
    )
    assert result.returncode == work_rc
    order = trace.read_text().splitlines()
    assert order[0] == "capture-1"
    assert order[1] == "work"
    assert order[2] == "capture-2"
    captured = payload.read_bytes()
    assert b"status status started 0" in captured
    assert expected_event in captured
    assert b"STDOUT-SECRET-CANARY" not in captured
    assert calls.read_text().splitlines()[-1] == "2"


def test_status_code_three_is_unresolved_and_does_not_flush_final_event(
    commands, tmp_path
):
    body = r"""
cfmgr_log_available=1
_cfmgr_status_native_work() { printf 'work\n' >>"$trace"; return 3; }
cfmgr_status_native
"""
    result, trace, payload, calls = run_log_shell(
        commands, tmp_path, [STATUS], body, work_rc=3
    )
    assert result.returncode == 3
    assert trace.read_text().splitlines() == ["capture-1", "work"]
    assert calls.read_text().splitlines() == ["1"]
    captured = payload.read_bytes()
    assert b"status status started 0" in captured
    assert b"status status unresolved" not in captured


def test_finish_records_deferred_outcome_as_a_fixed_typed_event(commands, tmp_path):
    body = r"""
cfmgr_log_available=1
cfmgr_log_begin status health
cfmgr_log_finish deferred 0
"""
    result, _, payload, calls = run_log_shell(commands, tmp_path, [], body)
    assert result.returncode == 0, result.stderr
    assert calls.read_text().splitlines() == ["2"]
    assert b"status health deferred 0" in payload.read_bytes()


@pytest.mark.parametrize("scenario", ["unavailable", "invalid", "nonzero-saved"])
def test_capture_failures_never_change_operation_rc_or_claim_saved(
    commands, tmp_path, scenario
):
    body = r"""
cfmgr_log_available=1
_cfmgr_status_native_work() { printf 'work\n' >>"$trace"; return 7; }
cfmgr_status_native
"""
    result, _, payload, calls = run_log_shell(
        commands, tmp_path, [STATUS], body, scenario=scenario, work_rc=7
    )
    assert result.returncode == 7
    assert calls.read_text().splitlines() == ["2"]
    assert (
        b"CAPTURE-RECEIPT-CANARY"
        not in result.stdout + result.stderr + payload.read_bytes()
    )
    assert b"saved" not in result.stdout.lower()
    assert b"operation result is unchanged" in result.stderr


def test_disabled_capture_receipt_prevents_later_flushes_and_keeps_result(
    commands, tmp_path
):
    body = r"""
cfmgr_log_available=1
_cfmgr_status_native_work() { printf 'work\n' >>"$trace"; return 7; }
cfmgr_status_native
"""
    result, _, payload, calls = run_log_shell(
        commands, tmp_path, [STATUS], body, scenario="disabled-first", work_rc=7
    )
    assert result.returncode == 7
    assert calls.read_text().splitlines() == ["1"]
    assert b"status status started 0" in payload.read_bytes()
    assert b"status status failure 7" not in payload.read_bytes()


def test_unreaped_owned_child_suppresses_flush_after_start(commands, tmp_path):
    body = r"""
cfmgr_log_available=1
cfmgr_log_begin status status
cfmgr_probe_pid=12345 cfmgr_probe_status=running
cfmgr_log_finish success 0
"""
    result, _, payload, calls = run_log_shell(commands, tmp_path, [], body)
    assert result.returncode == 0, result.stderr
    assert calls.read_text().splitlines() == ["1"]
    assert b"status status started 0" in payload.read_bytes()
    assert b"status status success 0" not in payload.read_bytes()


def test_event_allowlist_excludes_untrusted_fields_and_stdout(commands, tmp_path):
    body = r"""
cfmgr_log_available=1
cfmgr_log_begin status status
cfmgr_log_event execution dependency-task failure 7
cfmgr_log_event SECRET-COMPONENT dependency-task failure 7
cfmgr_log_event execution "dependency-task;TOKEN-CANARY" failure 7
cfmgr_log_event execution dependency-task SECRET-RESULT 7
cfmgr_log_event execution dependency-task failure STDOUT-CANARY
cfmgr_log_flush finished
"""
    result, _, payload, _ = run_log_shell(commands, tmp_path, [], body)
    assert result.returncode == 0, result.stderr
    captured = payload.read_bytes()
    assert captured.count(b"CFMGR-EVENT") == 2
    assert b"execution dependency-task failure 7" in captured
    for secret in (
        b"SECRET-COMPONENT",
        b"TOKEN-CANARY",
        b"SECRET-RESULT",
        b"STDOUT-CANARY",
    ):
        assert secret not in captured


def test_event_queue_caps_rows_and_bytes_and_reports_omitted_count(commands, tmp_path):
    body = r"""
cfmgr_log_available=1
cfmgr_log_begin execution dependency-task
i=0
while [ "$i" -lt 1025 ]; do
    cfmgr_log_event execution dependency-task success 0
    i=$((i + 1))
done
printf 'queued=%s bytes=%s omitted=%s\n' "$cfmgr_log_event_count" "${#cfmgr_log_buffer}" "$cfmgr_log_omitted" >>"$trace"
cfmgr_log_flush finished
"""
    result, trace, payload, _ = run_log_shell(commands, tmp_path, [], body)
    assert result.returncode == 0, result.stderr
    stats_line = next(
        line for line in trace.read_text().splitlines() if line.startswith("queued=")
    )
    stats = stats_line.split()
    assert stats[0] == "queued=1024"
    buffer_bytes = int(stats[1].split("=", 1)[1])
    assert buffer_bytes <= 131072
    assert stats[2] == "omitted=1"
    captured = (
        payload.read_bytes().split(b"BEGIN 2 developer\n", 1)[1].split(b"\nEND\n", 1)[0]
    )
    assert captured.count(b"CFMGR-EVENT") == 1024
    assert b"CFMGR-OMITTED 1 1" in captured
    assert len(captured) <= 131072


def test_execution_wrappers_log_fixed_mode_and_task_results_only(commands, tmp_path):
    body = r"""
cfmgr_log_available=1 cfmgr_log_recording=1 cfmgr_log_capturing=0
cfmgr_probe_mode=store-settings cfmgr_probe_exit=7
_cfmgr_prerequisites_run() { printf 'ARGV-SECRET-CANARY\n'; return 5; }
if cfmgr_prerequisites_run store-settings /private/path SECRET-CANARY; then probe_rc=0; else probe_rc=$?; fi
_cfmgr_execution_tasks_run() { printf 'STDOUT-SECRET-CANARY\n'; return 6; }
if cfmgr_execution_tasks_run SECRET-ARGV-CANARY; then task_rc=0; else task_rc=$?; fi
cfmgr_log_flush finished
printf 'probe-rc=%s task-rc=%s\n' "$probe_rc" "$task_rc" >>"$trace"
"""
    result, trace, payload, _ = run_log_shell(commands, tmp_path, [EXECUTION], body)
    assert result.returncode == 0, result.stderr
    assert b"ARGV-SECRET-CANARY" in result.stdout
    assert b"STDOUT-SECRET-CANARY" in result.stdout
    assert trace.read_text().splitlines()[-1] == "probe-rc=5 task-rc=6"
    captured = payload.read_bytes()
    assert b"execution store-settings failure 7" in captured
    assert b"execution dependency-task failure 6" in captured
    for secret in (b"ARGV-SECRET-CANARY", b"SECRET-ARGV-CANARY", b"/private/path"):
        assert secret not in captured


def test_capture_mock_mutations_do_not_escape_command_substitution(commands, tmp_path):
    body = r"""
cfmgr_log_available=1
cfmgr_probe_pid=parent-sentinel cfmgr_probe_status=reaped cfmgr_probe_exit=17
cfmgr_log_begin status status
printf 'probe=%s status=%s exit=%s\n' "$cfmgr_probe_pid" "$cfmgr_probe_status" "$cfmgr_probe_exit" >>"$trace"
"""
    result, trace, _, _ = run_log_shell(
        commands, tmp_path, [], body, scenario="mutate-state"
    )
    assert result.returncode == 0, result.stderr
    assert (
        trace.read_text().splitlines()[-1]
        == "probe=parent-sentinel status=reaped exit=17"
    )
