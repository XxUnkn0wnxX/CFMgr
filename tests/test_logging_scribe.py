"""Scribe snapshots: bounded ownership and orchestration contracts.

These host adapters do not prove native BusyBox/mount or provider behavior.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest
from test_config_observation import commands, schema2_config
from test_install import shell
from test_logging import frame, sanitize

ROOT = Path(__file__).resolve().parents[1]
DRAFT = ROOT / "modules/lib/logging.sh"
__all__ = ["commands", "schema2_config", "shell"]


def invoke(shell, script: str, *arguments: Path | str):
    return subprocess.run(
        [
            *shell,
            "-c",
            '. "$1"; shift; ' + script,
            "scribe-test",
            str(DRAFT),
            *map(str, arguments),
        ],
        capture_output=True,
        check=False,
        timeout=5,
    )


def authority(*, off: bool = True) -> str:
    value = "0" if off else "1"
    digest = "a" * 64
    rows = ["CFMGR-LOGGING 1"]
    for role in ("ddns", "ip_sync", "cloudflared"):
        rows.append(
            f"FEATURE {role} {value} {value} {value} {value} 1 0 0 1 - 1 {digest} END"
        )
        policy = (
            "POLICY size 10485760 4 30 END"
            if role == "cloudflared"
            else "POLICY native - - - END"
        )
        rows.append(f"SAVED {role} {policy}")
    rows.append("END 6 END")
    return "\n".join(rows) + "\n"


def test_positive_owned_history_remains_eligible_with_features_off(shell, tmp_path):
    receipt = tmp_path / "authority"
    receipt.write_text(authority())
    result = invoke(
        shell,
        'cfmgr_scribe_authority_parse "$1" "$2" || exit $?; '
        'printf "%s %s %s\\n" "$cfmgr_scribe_have_ddns" "$cfmgr_scribe_have_ip_sync" "$cfmgr_scribe_have_cloudflared"',
        receipt,
        str(len(receipt.read_bytes())),
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"1 1 1\n", b"")


@pytest.mark.parametrize(
    "damage", ["missing_footer", "invalid_hash", "extra_row", "flags", "nul"]
)
def test_authority_frame_rejects_bad_or_ambiguous_proof(shell, tmp_path, damage):
    data = authority()
    if damage == "missing_footer":
        data = data.replace("END 6 END\n", "")
    elif damage == "invalid_hash":
        data = data.replace("a" * 64, "g" * 64, 1)
    elif damage == "extra_row":
        data += "unexpected\n"
    elif damage == "nul":
        data = data.replace("FEATURE ddns", "FEA\0TURE ddns", 1)
    else:
        data = data.replace("FEATURE ddns 0", "FEATURE ddns 2", 1)
    receipt = tmp_path / "authority"
    receipt.write_text(data)
    result = invoke(
        shell,
        'cfmgr_scribe_authority_parse "$1" "$2"',
        receipt,
        str(len(receipt.read_bytes())),
    )
    assert result.returncode != 0
    assert result.stdout == b""


@pytest.mark.parametrize(
    ("size", "valid"),
    [
        ("0", True),
        ("24576", True),
        ("2147483647", True),
        ("2147483648", False),
        ("9999999999", False),
        ("01", False),
        ("-1", False),
    ],
)
def test_source_extent_is_safe_for_32_bit_arithmetic(shell, size, valid):
    result = invoke(shell, 'cfmgr_scribe_source_size_valid "$1"', size)
    assert (result.returncode == 0) is valid
    assert result.stdout == b""


def test_current_logs_are_prioritized_before_retained_siblings(shell, tmp_path):
    opt = tmp_path / "opt"
    (opt / "var/log").mkdir(parents=True)
    (opt / "etc/logrotate.d").mkdir(parents=True)
    listing = tmp_path / "listing"
    order = tmp_path / "order"
    script = r"""
cfmgr_scribe_authority() {
    cfmgr_scribe_have_ddns=1 cfmgr_scribe_have_ip_sync=1 cfmgr_scribe_have_cloudflared=1
    cfmgr_scribe_sha_ddns=x cfmgr_scribe_sha_ip_sync=x cfmgr_scribe_sha_cloudflared=x
}
cfmgr_scribe_pin_source() { cfmgr_scribe_opt=$1; cfmgr_scribe_mount_id=7; }
cfmgr_scribe_admit_directory() { return 0; }
cfmgr_scribe_rule_owned() { return 0; }
cfmgr_log_fd_mount_ok() { return 0; }
cfmgr_scribe_run() { cfmgr_probe_stdout=$2; return 0; }
cfmgr_scribe_accept_snapshot() { printf '%s %s\n' "$1" "$2" >>"$3"; }
cfmgr_log_scribe_capture
"""
    # Bind adapter variables before overriding functions; snapshot adapter writes
    # a deterministic private observation, never an actual Scribe source.
    script = script.replace("cfmgr_scribe_opt=$1", f'cfmgr_scribe_opt="{opt}"')
    script = script.replace("cfmgr_probe_stdout=$2", f'cfmgr_probe_stdout="{listing}"')
    script = script.replace('>>"$3"', f'>>"{order}"')
    listing.write_text("cloudflared.log.1\nddns.log.2\nunrelated\n")
    # Only this host adapter substitutes directory existence for Linux FD
    # identity. Native CI must exercise the unmodified /proc check.
    import sys

    adapted = tmp_path / "logging-scribe-adapter.sh"
    source = DRAFT.read_text()
    if sys.platform == "darwin":
        source = source.replace(
            '[ "$cfmgr_scribe_logs" -ef /proc/self/fd/3 ]',
            '[ -d "$cfmgr_scribe_logs" ]',
        )
    adapted.write_text(source)
    result = subprocess.run(
        [*shell, "-c", '. "$1"; shift; ' + script, "scribe-test", str(adapted)],
        capture_output=True,
        check=False,
        timeout=5,
    )
    assert (result.returncode, result.stderr) == (0, b"")
    assert order.read_text().splitlines() == [
        "ddns current",
        "ip_sync current",
        "cloudflared current",
        "cloudflared 1",
        "ddns 2",
    ]


def test_unowned_sources_are_not_claimed_missing_without_opening_opt(shell):
    script = r"""
cfmgr_scribe_authority() {
    cfmgr_scribe_have_ddns=0 cfmgr_scribe_have_ip_sync=0 cfmgr_scribe_have_cloudflared=0
}
cfmgr_scribe_pin_source() { printf 'unexpected source read\n'; return 1; }
cfmgr_log_scribe_capture || exit $?
printf '%s %s %s %s\n' "$cfmgr_scribe_saved" "$cfmgr_scribe_missing" "$cfmgr_scribe_incomplete" "$cfmgr_scribe_unowned"
"""
    result = invoke(shell, script)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"0 0 0 3\n", b"")


def test_rotated_snapshot_name_collision_preserves_history(shell, tmp_path):
    boot = "12345678-1234-1234-1234-123456789abc"
    name = f"scribe-{boot}-5678-4321-ddns-2-1.log"
    (tmp_path / name).write_text("previous sanitized snapshot")
    script = r"""
cfmgr_log_walk=$1 cfmgr_log_boot=$2 cfmgr_log_start=5678 cfmgr_log_pid=4321
cfmgr_log_attached() { return 0; }
cfmgr_log_open_output() {
    (umask 077; set -C; : >"$cfmgr_log_walk/$1") || return 1
    cfmgr_log_output_created=1
}
cfmgr_scribe_output_open ddns 2 || exit $?
printf '%s\n' "$cfmgr_scribe_output_name"
"""
    result = invoke(shell, script, tmp_path, boot)
    next_name = f"scribe-{boot}-5678-4321-ddns-2-2.log"
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        (next_name + "\n").encode(),
        b"",
    )
    assert (tmp_path / name).read_text() == "previous sanitized snapshot"
    assert (tmp_path / next_name).read_bytes() == b""


@pytest.mark.parametrize(
    ("payload", "valid", "incomplete"),
    [
        (b"CFMGR-SANITIZED-LOG 1\nEND 0 0 0\n", True, b"0\n"),
        (b"CFMGR-SANITIZED-LOG 1\nredacted\nEND 0 1 1\n", True, b"1\n"),
        (b"CFMGR-SANITIZED-LOG 1\nredacted\nEND 1 1 1\n", False, b""),
        (b"CFMGR-SANITIZED-LOG 1\n\x00binary\nEND 0 1 1\n", False, b""),
        (b"CFMGR-SANITIZED-LOG 1\nEND 0 0 0", False, b""),
    ],
)
def test_sanitized_receipt_requires_exact_footer(
    shell, tmp_path, payload, valid, incomplete
):
    receipt = tmp_path / "sanitized"
    receipt.write_bytes(payload)
    result = invoke(
        shell,
        'cfmgr_scribe_sanitized_status "$1" "$2" || exit $?; printf "%s\\n" "$cfmgr_scribe_was_incomplete"',
        receipt,
        str(len(payload)),
    )
    assert (result.returncode == 0) is valid
    assert result.stdout == incomplete


def test_changed_authority_stops_before_snapshot_write(shell):
    script = r"""
cfmgr_log_result=saved cfmgr_scribe_stop=0
cfmgr_scribe_authority_unchanged() { return 1; }
cfmgr_scribe_source_attached() { return 0; }
cfmgr_scribe_output_open() { printf 'unexpected write\n'; return 1; }
if cfmgr_scribe_save_stage; then code=0; else code=$?; fi
printf '%s %s %s\n' "$code" "$cfmgr_scribe_stop" "$cfmgr_log_result"
"""
    result = invoke(shell, script)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"1 1 saved\n", b"")


def test_unresolved_authority_compare_propagates_without_new_write(shell):
    script = r"""
cfmgr_log_result=saved cfmgr_scribe_stop=0
cfmgr_scribe_authority_unchanged() { return 3; }
cfmgr_scribe_source_attached() { return 0; }
cfmgr_scribe_output_open() { printf 'unexpected write\n'; return 1; }
if cfmgr_scribe_save_stage; then code=0; else code=$?; fi
printf '%s %s %s\n' "$code" "$cfmgr_scribe_stop" "$cfmgr_log_result"
"""
    result = invoke(shell, script)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"3 0 saved\n", b"")


def test_sanitized_source_never_copies_secret_and_marks_excerpt(
    shell, commands, tmp_path
):
    canary = b"PRIVATE_SECRET_DO_NOT_COPY"
    raw = (
        b"truncated record fragment\n"
        b'{"level":"info","time":"2025-01-02T03:04:05Z",'
        b'"message":"Starting tunnel","token":"' + canary + b'"}\n'
    )
    output = sanitize(raw, commands, excerpt=True, source_role="cloudflared")
    assert output.returncode == 0
    assert canary not in output.stdout
    receipt = tmp_path / "sanitized"
    receipt.write_bytes(output.stdout)
    result = invoke(
        shell,
        'cfmgr_scribe_sanitized_status "$1" "$2" || exit $?; printf "%s\\n" "$cfmgr_scribe_was_incomplete"',
        receipt,
        str(len(output.stdout)),
    )
    assert (result.returncode, result.stdout, result.stderr) == (0, b"1\n", b"")
    binary = frame(b"\x00binary\n", commands)
    assert binary.returncode != 0
    assert binary.stdout == b""


def test_missing_current_source_is_counted_without_fabrication(shell, tmp_path):
    (tmp_path / "var/log").mkdir(parents=True)
    script = r"""
cfmgr_scribe_opt=$1 cfmgr_scribe_missing=0 cfmgr_scribe_attempted=0
cfmgr_scribe_source_attached() { return 0; }
cfmgr_scribe_snapshot ddns current || exit $?
printf '%s %s\n' "$cfmgr_scribe_missing" "$cfmgr_scribe_attempted"
"""
    result = invoke(shell, script, tmp_path)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"1 0\n", b"")
    assert not (tmp_path / "var/log/ddns.log").exists()


def test_source_count_cap_leaves_extra_candidate_unread(shell, tmp_path):
    logs = tmp_path / "var/log"
    logs.mkdir(parents=True)
    candidate = logs / "ddns.log.30"
    candidate.write_text("must remain untouched")
    script = r"""
cfmgr_scribe_opt=$1 cfmgr_scribe_missing=0 cfmgr_scribe_attempted=32 cfmgr_scribe_truncated=0
cfmgr_scribe_source_attached() { return 0; }
cfmgr_scribe_open_source() { printf 'unexpected read\n'; return 1; }
cfmgr_scribe_snapshot ddns 30 || exit $?
printf '%s %s\n' "$cfmgr_scribe_attempted" "$cfmgr_scribe_truncated"
"""
    result = invoke(shell, script, tmp_path)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"32 1\n", b"")
    assert candidate.read_text() == "must remain untouched"


def test_absent_path_after_source_loss_is_incomplete_not_missing(shell, tmp_path):
    (tmp_path / "var/log").mkdir(parents=True)
    script = r"""
cfmgr_scribe_opt=$1 cfmgr_scribe_missing=0 cfmgr_scribe_incomplete=0 cfmgr_scribe_attempted=0
cfmgr_scribe_source_attached() { return 1; }
cfmgr_scribe_accept_snapshot ddns current || exit $?
printf '%s %s\n' "$cfmgr_scribe_missing" "$cfmgr_scribe_incomplete"
"""
    result = invoke(shell, script, tmp_path)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"0 1\n", b"")


def test_changed_rule_defers_role_before_snapshot_publication(shell):
    script = r"""
cfmgr_log_result=saved cfmgr_scribe_stop=0 cfmgr_scribe_snapshot_role=ddns
cfmgr_scribe_have_ddns=1 cfmgr_scribe_sha_ddns=original cfmgr_scribe_ready_ddns=1
cfmgr_scribe_authority_unchanged() { return 0; }
cfmgr_scribe_source_attached() { return 0; }
cfmgr_scribe_rule_owned() { [ "$1:$2" = ddns:original ] || exit 20; return 1; }
cfmgr_scribe_output_open() { printf 'unexpected write\n'; return 1; }
if cfmgr_scribe_save_stage; then code=0; else code=$?; fi
printf '%s %s %s\n' "$code" "$cfmgr_scribe_ready_ddns" "$cfmgr_log_result"
"""
    result = invoke(shell, script)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"1 0 saved\n", b"")


def test_absent_log_directory_after_source_loss_is_incomplete(shell, tmp_path):
    opt = tmp_path / "opt"
    (opt / "etc/logrotate.d").mkdir(parents=True)
    script = r"""
cfmgr_scribe_authority() {
    cfmgr_scribe_have_ddns=1 cfmgr_scribe_have_ip_sync=0 cfmgr_scribe_have_cloudflared=0
    cfmgr_scribe_sha_ddns=x cfmgr_scribe_sha_ip_sync=x cfmgr_scribe_sha_cloudflared=x
}
cfmgr_scribe_pin_source() { cfmgr_scribe_opt=$1; }
cfmgr_scribe_admit_directory() { [ "$1" != "$cfmgr_scribe_opt/var/log" ]; }
cfmgr_scribe_rule_owned() { return 0; }
cfmgr_scribe_source_attached() { return 1; }
cfmgr_log_scribe_capture || exit $?
printf '%s %s %s\n' "$cfmgr_scribe_missing" "$cfmgr_scribe_incomplete" "$cfmgr_scribe_unowned"
"""
    script = script.replace("cfmgr_scribe_opt=$1", f'cfmgr_scribe_opt="{opt}"')
    result = invoke(shell, script)
    assert (result.returncode, result.stdout, result.stderr) == (0, b"0 1 2\n", b"")


@pytest.mark.parametrize(
    "change",
    [
        "unchanged",
        "off",
        "same-generation",
        "replace-after-compare",
        "mode-after-compare",
    ],
)
def test_fresh_config_descriptor_comparison_stops_changed_authority(
    shell, schema2_config, tmp_path, change
):
    """Real bytes/FDs; stat and compare adapters isolate freshness from supervision."""
    if sys.platform != "linux":
        pytest.skip("Linux file descriptor identity is required")
    value = json.loads(schema2_config)
    value["manager"]["developer"] = True
    value["manager"]["source"]["branch"] = "develop"
    original = json.dumps(value, separators=(",", ":")).encode()
    authority = tmp_path / "authority"
    authority.write_bytes(original)
    authority.chmod(0o600)
    if change == "off":
        value["manager"]["developer"] = False
    elif change == "same-generation":
        value["manager"]["source"]["branch"] = "feature"
    config = tmp_path / "config"
    config.write_text(json.dumps(value, separators=(",", ":")))
    config.chmod(0o600)
    if change == "same-generation":
        assert config.stat().st_size == len(original)
    replacement = tmp_path / "replacement"
    replacement.write_bytes(original)
    replacement.chmod(0o600)
    script = r"""
cfmgr_source=$1 cfmgr_scribe_authority_config=$2 cfmgr_scribe_authority_config_bytes=$3 cfmgr_test_change=$4
cfmgr_log_read_config() { printf 'unexpected reparsing\n'; exit 90; }
cfmgr_log_metadata() {
    IFS=' ' read -r cfmgr_log_meta_mode cfmgr_log_meta_inode cfmgr_log_meta_size cfmgr_test_links <<EOF_META
$(stat -c '%A %i %s %h' "$1")
EOF_META
    [ "$cfmgr_test_links" = 1 ]
}
cfmgr_scribe_run() {
    [ "$1" = diagnostic-compare ] || exit 91
    cmp -s /proc/self/fd/3 /proc/self/fd/4 || return 1
    case $cfmgr_test_change in
    replace-after-compare) mv "$cfmgr_source/replacement" "$cfmgr_source/config" ;;
    mode-after-compare) chmod 644 "$cfmgr_source/config" ;;
    esac
    return 0
}
cfmgr_log_attached() { return 0; }
cfmgr_scribe_authority_unchanged
"""
    result = invoke(shell, script, tmp_path, authority, str(len(original)), change)
    assert (result.returncode, result.stdout, result.stderr) == (
        0 if change == "unchanged" else 1,
        b"",
        b"",
    )
    assert authority.read_bytes() == original
