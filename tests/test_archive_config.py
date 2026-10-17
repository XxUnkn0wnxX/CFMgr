"""Archive preference and history observations over retained config bytes."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from test_config_observation import commands, config, invoke, schema2_config

ROOT = Path(__file__).resolve().parents[1]
__all__ = ["commands", "config", "schema2_config"]
SET_ID = "01234567-89ab-cdef-0123-456789abcdef"
ARCHIVE_ID = "abcdef01-2345-6789-abcd-ef0123456789"
PREFERENCES = {
    "CFMGR_ARCHIVE_FORMAT": "YMD",
    "CFMGR_ARCHIVE_KEEP": "4",
    "CFMGR_ARCHIVE_SET_ID": SET_ID,
}
HISTORY = {
    "CFMGR_ARCHIVE_SET_ID": SET_ID,
    "CFMGR_ARCHIVE_ID": ARCHIVE_ID,
    "CFMGR_ARCHIVE_AT": "1792100000",
    "CFMGR_ARCHIVE_DATE": "2026-10-16",
    "CFMGR_ARCHIVE_TIME": "12-34-56",
    "CFMGR_ARCHIVE_ZONE": "AEST-10AEDT,M10.1.0,M4.1.0/3",
    "CFMGR_ARCHIVE_FORMAT": "YMD",
    "CFMGR_ARCHIVE_GENERATION": "1",
}


def archive_invoke(commands, tmp_path, data, mode, values=None):
    return invoke(commands, tmp_path, data, mode, values or {})


def assert_ordinary_readers(commands, tmp_path, data: bytes) -> None:
    checked = invoke(commands, tmp_path, data, "check")
    settings = invoke(commands, tmp_path, data, "settings-read")
    assert checked.returncode == settings.returncode == 0
    assert checked.stderr == settings.stderr == b""
    assert checked.stdout.endswith(b" END\n")
    assert settings.stdout.endswith(b" END\n")


def configured(data: bytes, *, last_backup=None) -> bytes:
    value = json.loads(data)
    value["backup"]["date_format"] = "YMD"
    value["backup"]["retention"] = 4
    value["backup"]["set_id"] = SET_ID
    if last_backup is not None:
        value["backup"]["last_backup"] = last_backup
    return (json.dumps(value, indent=2) + "\n").encode()


def test_archive_read_supports_legacy_optional_preferences(
    commands, config, schema2_config, tmp_path
) -> None:
    result = archive_invoke(commands, tmp_path, config, "archive-read")
    assert (result.returncode, result.stdout, result.stderr) == (
        0,
        b"CFMGR-ARCHIVE-CONFIG 1 1 1 - 0 - END\n",
        b"",
    )
    schema2 = archive_invoke(commands, tmp_path, schema2_config, "archive-read")
    assert (schema2.returncode, schema2.stdout) == (
        0,
        b"CFMGR-ARCHIVE-CONFIG 1 2 1 - 0 - END\n",
    )


def test_fresh_config_has_null_set_id_and_fresh_rejects_nonnull(
    commands, schema2_config, tmp_path
) -> None:
    value = json.loads(schema2_config)
    assert value["backup"]["set_id"] is None
    result = archive_invoke(commands, tmp_path, schema2_config, "fresh")
    assert (result.returncode, result.stdout, result.stderr) == (0, b"", b"")
    value["backup"].pop("set_id")
    absent = archive_invoke(
        commands, tmp_path, (json.dumps(value) + "\n").encode(), "fresh"
    )
    assert (absent.returncode, absent.stdout, absent.stderr) == (0, b"", b"")
    value["backup"]["set_id"] = SET_ID
    invalid = archive_invoke(
        commands, tmp_path, (json.dumps(value) + "\n").encode(), "fresh"
    )
    assert (invalid.returncode, invalid.stdout, invalid.stderr) == (1, b"", b"")


def test_preferences_patch_inserts_only_missing_keys_and_preserves_unknown_bytes(
    commands, config, tmp_path
) -> None:
    original = config.replace(
        b'"generation":1,',
        b'"future" : {"precise":900719925474099312345}, "generation":1,',
    )
    original = original.replace(b'"retention":null,', b"")
    result = archive_invoke(
        commands, tmp_path, original, "archive-preferences-patch", PREFERENCES
    )
    assert result.returncode == 0, result.stderr
    parsed = json.loads(result.stdout)
    assert parsed["generation"] == 2
    assert parsed["backup"]["date_format"] == "YMD"
    assert parsed["backup"]["retention"] == 4
    assert parsed["backup"]["set_id"] == SET_ID
    assert parsed["future"]["precise"] == 900719925474099312345
    assert b'"future" : {"precise":900719925474099312345}' in result.stdout
    expected = original.replace(b'"generation":1,', b'"generation":2,')
    expected = expected.replace(
        b'"last_backup":null}',
        f'"last_backup":null,"date_format":"YMD","retention":4,"set_id":"{SET_ID}"}}'.encode(),
    )
    assert result.stdout == expected
    assert_ordinary_readers(commands, tmp_path, result.stdout)
    checked = archive_invoke(commands, tmp_path, result.stdout, "archive-read")
    assert checked.stdout == f"CFMGR-ARCHIVE-CONFIG 1 1 2 YMD 4 {SET_ID} END\n".encode()


def test_destination_save_preserves_selected_set_id(commands, config, tmp_path) -> None:
    original = configured(config)
    environment = {
        "CFMGR_BACKUP_MOUNT": "/tmp/mnt/archive",
        "CFMGR_BACKUP_UUID": "archive-volume",
        "CFMGR_BACKUP_FILESYSTEM": "ext4",
        "CFMGR_BACKUP_ROOT": "/mnt/archive",
    }
    saved = archive_invoke(commands, tmp_path, original, "backup-patch", environment)
    assert saved.returncode == 0, saved.stderr
    assert json.loads(saved.stdout)["backup"]["set_id"] == SET_ID


def test_preferences_noop_keeps_bytes_and_observe_receipt_is_exact(
    commands, config, tmp_path
) -> None:
    original = configured(config)
    expected = (
        f"CFMGR-ARCHIVE-PATCH 1 1 1 0 1 0 0 {len(original)} {len(original)} END\n"
    ).encode()
    observed = archive_invoke(
        commands, tmp_path, original, "archive-preferences-observe", PREFERENCES
    )
    patched = archive_invoke(
        commands, tmp_path, original, "archive-preferences-patch", PREFERENCES
    )
    assert (observed.returncode, observed.stdout, observed.stderr) == (0, expected, b"")
    assert (patched.returncode, patched.stdout, patched.stderr) == (0, original, b"")
    assert_ordinary_readers(commands, tmp_path, patched.stdout)


def test_preferences_set_id_insertion_preserves_nested_last_backup_extension(
    commands, schema2_config, tmp_path
) -> None:
    value = json.loads(schema2_config)
    value["backup"]["last_backup"] = {
        "schema": 1,
        "generation": 1,
        "at": 1,
        "date_format": "YMD",
        "local_date": "2000-01-01",
        "local_time": "00-00-00",
        "timezone": "UTC0",
        "set_id": SET_ID,
        "archive_id": ARCHIVE_ID,
        "future": {"nested": {"raw": 900719925474099312345}},
    }
    value["backup"].pop("set_id")
    original = json.dumps(value, indent=2).encode() + b"\n"
    result = archive_invoke(
        commands, tmp_path, original, "archive-preferences-patch", PREFERENCES
    )
    assert result.returncode == 0, result.stderr
    parsed = json.loads(result.stdout)
    assert parsed["backup"]["set_id"] == SET_ID
    assert (
        parsed["backup"]["last_backup"]["future"]
        == value["backup"]["last_backup"]["future"]
    )
    assert b'"raw": 900719925474099312345' in result.stdout
    assert_ordinary_readers(commands, tmp_path, result.stdout)


@pytest.mark.parametrize(
    "values",
    [
        {**PREFERENCES, "CFMGR_ARCHIVE_SET_ID": ARCHIVE_ID},
        {**PREFERENCES, "CFMGR_ARCHIVE_FORMAT": "ymd"},
        {**PREFERENCES, "CFMGR_ARCHIVE_KEEP": "2"},
        {**PREFERENCES, "CFMGR_ARCHIVE_KEEP": "04"},
        {**PREFERENCES, "CFMGR_ARCHIVE_SET_ID": "ABCDEF01-2345-6789-abcd-ef0123456789"},
    ],
)
def test_preferences_reject_foreign_ids_and_invalid_selection(
    commands, config, tmp_path, values
) -> None:
    original = configured(config)
    result = archive_invoke(
        commands, tmp_path, original, "archive-preferences-observe", values
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def test_preferences_refuse_generation_overflow(commands, config, tmp_path) -> None:
    original = configured(config).replace(
        b'"generation": 1,', b'"generation": 99999999999999999999,'
    )
    changed = {**PREFERENCES, "CFMGR_ARCHIVE_FORMAT": "DMY"}
    result = archive_invoke(
        commands, tmp_path, original, "archive-preferences-patch", changed
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def test_history_patch_updates_known_fields_and_retains_nested_extensions(
    commands, config, tmp_path
) -> None:
    prior = {
        "schema": 1,
        "generation": 1,
        "at": 1,
        "date_format": "DMY",
        "local_date": "2000-01-01",
        "local_time": "00-00-00",
        "timezone": "UTC0",
        "set_id": SET_ID,
        "archive_id": ARCHIVE_ID,
        "future": {"raw": 900719925474099312345},
    }
    original = configured(config, last_backup=prior)
    observed = archive_invoke(
        commands, tmp_path, original, "archive-history-observe", HISTORY
    )
    assert (tmp_path / "private immutable config").read_bytes() == original
    patched = archive_invoke(
        commands, tmp_path, original, "archive-history-patch", HISTORY
    )
    assert observed.returncode == patched.returncode == 0
    assert (
        observed.stdout
        == (
            f"CFMGR-ARCHIVE-PATCH 1 1 2 1 1 0 0 {len(original)} {len(patched.stdout)} END\n"
        ).encode()
    )
    assert json.loads(patched.stdout)["backup"]["last_backup"] == {
        **prior,
        "generation": 1,
        "at": 1792100000,
        "date_format": "YMD",
        "local_date": "2026-10-16",
        "local_time": "12-34-56",
        "timezone": HISTORY["CFMGR_ARCHIVE_ZONE"],
        "archive_id": ARCHIVE_ID,
    }
    assert b'"future": {' in patched.stdout
    assert b'"raw": 900719925474099312345' in patched.stdout
    assert_ordinary_readers(commands, tmp_path, patched.stdout)
    result = archive_invoke(
        commands, tmp_path, patched.stdout, "archive-history-patch", HISTORY
    )
    assert result.stdout == patched.stdout
    assert_ordinary_readers(commands, tmp_path, result.stdout)


def test_history_patch_creates_record_from_null_without_changing_other_backup_fields(
    commands, config, tmp_path
) -> None:
    original = configured(config)
    value = json.loads(original)
    value["backup"]["last_backup"] = None
    original = (json.dumps(value, indent=2) + "\n").encode()
    result = archive_invoke(
        commands, tmp_path, original, "archive-history-patch", HISTORY
    )
    assert result.returncode == 0, result.stderr
    parsed = json.loads(result.stdout)
    assert parsed["generation"] == 2
    assert parsed["backup"]["destination"] == value["backup"]["destination"]
    assert parsed["backup"]["last_backup"]["timezone"] == HISTORY["CFMGR_ARCHIVE_ZONE"]
    assert parsed["backup"]["last_backup"]["schema"] == 1
    assert_ordinary_readers(commands, tmp_path, result.stdout)


def test_history_patch_rejects_malformed_existing_record(
    commands, config, tmp_path
) -> None:
    original = configured(config, last_backup={"future": {"kept": True}})
    result = archive_invoke(
        commands, tmp_path, original, "archive-history-patch", HISTORY
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("CFMGR_ARCHIVE_DATE", "2025-02-29"),
        ("CFMGR_ARCHIVE_DATE", "0000-01-01"),
        ("CFMGR_ARCHIVE_TIME", "24-00-00"),
        ("CFMGR_ARCHIVE_TIME", "12-60-00"),
        ("CFMGR_ARCHIVE_AT", "01"),
        ("CFMGR_ARCHIVE_AT", "10000000000"),
        ("CFMGR_ARCHIVE_ZONE", "UTC\n0"),
        ("CFMGR_ARCHIVE_ZONE", "x" * 1025),
        ("CFMGR_ARCHIVE_FORMAT", "MDY"),
        ("CFMGR_ARCHIVE_SET_ID", ARCHIVE_ID),
        ("CFMGR_ARCHIVE_GENERATION", "0"),
        ("CFMGR_ARCHIVE_GENERATION", "2"),
        ("CFMGR_ARCHIVE_ID", "not-a-uuid"),
    ],
)
def test_history_rejects_invalid_inputs_before_output(
    commands, config, tmp_path, key, value
) -> None:
    original = configured(config)
    result = archive_invoke(
        commands, tmp_path, original, "archive-history-observe", {**HISTORY, key: value}
    )
    assert (result.returncode, result.stdout, result.stderr) == (1, b"", b"")


def test_archive_modes_validate_optional_settings_in_schema1_and_schema2(
    commands, config, schema2_config, tmp_path
) -> None:
    for source in (config, schema2_config):
        absent = json.loads(source)
        absent["backup"].pop("set_id", None)
        if absent["schema"] == 1:
            absent["backup"].pop("date_format", None)
            absent["backup"].pop("retention", None)
            absent["backup"].pop("last_backup", None)
        accepted = archive_invoke(
            commands, tmp_path, (json.dumps(absent) + "\n").encode(), "archive-read"
        )
        assert accepted.returncode == 0
        if absent["schema"] == 2:
            for key in ("date_format", "retention", "last_backup"):
                value = json.loads(source)
                value["backup"].pop(key, None)
                missing_required = archive_invoke(
                    commands,
                    tmp_path,
                    (json.dumps(value) + "\n").encode(),
                    "archive-read",
                )
                assert (missing_required.returncode, missing_required.stdout) == (
                    1,
                    b"",
                )
        value = json.loads(source)
        value["backup"]["set_id"] = "ABCDEF01-2345-6789-abcd-ef0123456789"
        invalid_id = (json.dumps(value) + "\n").encode()
        result = archive_invoke(commands, tmp_path, invalid_id, "archive-read")
        assert (result.returncode, result.stdout) == (1, b"")
        value["backup"]["set_id"] = None
        value["backup"]["date_format"] = "wrong"
        result = archive_invoke(
            commands, tmp_path, (json.dumps(value) + "\n").encode(), "archive-read"
        )
        assert (result.returncode, result.stdout) == (1, b"")
        value["backup"]["date_format"] = None
        value["backup"]["retention"] = 2
        result = archive_invoke(
            commands, tmp_path, (json.dumps(value) + "\n").encode(), "archive-read"
        )
        assert (result.returncode, result.stdout) == (1, b"")
