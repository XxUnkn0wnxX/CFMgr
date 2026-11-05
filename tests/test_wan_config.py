"""WAN preferences stay bounded and preserve retained configuration data."""

import json

import pytest
from test_config_observation import commands, config, schema2_config, settings_invoke
from test_config_store import (
    ADAPTER,
    legacy_fsync,
    run_store,
    shell,
    store_fixture,
    tools,
)

__all__ = ["commands", "config", "schema2_config"]


def call(commands, tmp_path, value, mode, packet="-", generation="0"):
    return settings_invoke(
        commands, tmp_path, value, mode, mask=packet, check=generation, auto="0"
    )


def encoded(value):
    return json.dumps(value, separators=(",", ":")).encode()


@pytest.mark.parametrize("fixture", ["config", "schema2_config"])
def test_legacy_and_inventory(request, fixture, commands, tmp_path):
    value = json.loads(request.getfixturevalue(fixture))
    value["network"]["selected_wan"] = 1
    raw = encoded(value)
    result = call(commands, tmp_path, raw, "wan-read")
    assert result.returncode == 0, result.stderr
    assert b" legacy retained wan:1 wan:1 END" in result.stdout
    packet = "confirmed|manual:1|wan:1,manual:1=6574682431"
    patched = call(commands, tmp_path, raw, "wan-patch", packet, "1")
    assert patched.returncode == 0, patched.stderr
    new = json.loads(patched.stdout)
    assert new["generation"] == 2
    assert new["network"]["selected_wan"] is None
    assert new["network"]["wan_inventory"]["sources"][1]["interface"] == "eth$1"
    assert new["ip_sync"] == value["ip_sync"]
    assert call(commands, tmp_path, patched.stdout, "wan-read").returncode == 0
    assert call(commands, tmp_path, raw, "wan-patch", packet, "2").returncode != 0


def test_retention_validation_and_deferred(commands, schema2_config, tmp_path):
    value = json.loads(schema2_config)
    value["network"]["wan_inventory"] = {
        "schema": 1,
        "state": "confirmed",
        "primary": "wan:0",
        "extension": {"x": 1},
        "sources": [
            {"id": "wan:0", "kind": "firmware", "unit": 0, "extra": 9},
            {"id": "manual:1", "kind": "interface", "interface": "old", "extra": 8},
        ],
    }
    value["network"]["selected_wan"] = 0
    raw = encoded(value)
    result = call(
        commands, tmp_path, raw, "wan-patch", "deferred|manual:1|manual:1=6e6577", "1"
    )
    assert result.returncode == 0, result.stderr
    updated = json.loads(result.stdout)
    inventory = updated["network"]["wan_inventory"]
    assert inventory["extension"] == {"x": 1}
    assert inventory["sources"] == [
        {"id": "manual:1", "kind": "interface", "interface": "new", "extra": 8}
    ]
    assert updated["network"]["selected_wan"] is None
    assert updated["ip_sync"] == value["ip_sync"]
    inventory["schema"] = 2
    assert call(commands, tmp_path, encoded(updated), "wan-read").returncode != 0


@pytest.mark.parametrize(
    "packet",
    [
        "confirmed|-|-",
        "confirmed|wan:256|wan:256",
        "confirmed|manual:1|manual:1=2f",
        "confirmed|manual:1|manual:1=61,manual:2=61",
        "deferred|wan:0|-",
    ],
)
def test_invalid_intent_rejected(commands, schema2_config, tmp_path, packet):
    assert (
        call(commands, tmp_path, schema2_config, "wan-patch", packet, "1").returncode
        != 0
    )


def test_guarded_store_save_stale_and_read(shell, tools, store_fixture):
    script = ADAPTER.replace('cfmgr_config_store "$@"', 'cfmgr_config_wan_store "$@"')
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    read = run_store(shell, tools, store_fixture, "read", script=script)
    assert read.returncode == 0, (read.stdout, read.stderr)
    assert b"read 1 0 absent unconfirmed - - END" in read.stdout
    assert (source / "config").read_bytes() == before
    saved = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "1",
        "confirmed",
        "wan:0",
        "wan:0",
        script=script,
    )
    assert saved.returncode == 0, (saved.stdout, saved.stderr)
    assert b"saved 2 0 inventory confirmed wan:0 wan:0 END" in saved.stdout
    after = (source / "config").read_bytes()
    stale = run_store(
        shell, tools, store_fixture, "save", "1", "deferred", "-", "-", script=script
    )
    assert stale.returncode != 0 and b" stale " in stale.stdout
    assert (source / "config").read_bytes() == after


__all__ += ["legacy_fsync", "shell", "store_fixture", "tools"]


def test_narrow_read_ignores_unrelated_damage_but_rejects_invalid_inventory(
    commands, schema2_config, tmp_path
):
    value = json.loads(schema2_config)
    value["ip_sync"] = "damaged"
    raw = encoded(value)
    assert call(commands, tmp_path, raw, "wan-read").returncode == 0
    assert (
        call(commands, tmp_path, raw, "wan-observe", "deferred|-|-", "1").returncode
        != 0
    )
    value["network"]["wan_inventory"] = {"schema": 2}
    assert call(commands, tmp_path, encoded(value), "wan-read").returncode != 0


def test_legacy_unresolved_and_projection_mismatch(commands, config, tmp_path):
    value = json.loads(config)
    for retained in ("1", "wan1"):
        value["network"]["selected_wan"] = retained
        assert (
            b"legacy retained wan:1 wan:1"
            in call(commands, tmp_path, encoded(value), "wan-read").stdout
        )
    for retained in ("unexpected", "auto"):
        value["network"]["selected_wan"] = retained
        assert (
            b"unresolved unknown - -"
            in call(commands, tmp_path, encoded(value), "wan-read").stdout
        )
        assert (
            call(
                commands, tmp_path, encoded(value), "wan-patch", "deferred|-|-", "1"
            ).returncode
            != 0
        )
        replacement = call(
            commands,
            tmp_path,
            encoded(value),
            "wan-patch",
            "confirmed|wan:0|wan:0",
            "1",
        )
        assert replacement.returncode == 0, replacement.stderr
        assert json.loads(replacement.stdout)["network"]["selected_wan"] == 0
    value["network"]["wan_inventory"] = {
        "schema": 1,
        "state": "confirmed",
        "primary": "wan:0",
        "sources": [{"id": "wan:0", "kind": "firmware", "unit": 0}],
    }
    assert call(commands, tmp_path, encoded(value), "wan-read").returncode != 0


def test_inventory_is_not_passive_fresh_state_and_noop_preserves_exact_bytes(
    commands, schema2_config, tmp_path
):
    packet = "confirmed|manual:1|manual:1=65746830"
    patched = call(commands, tmp_path, schema2_config, "wan-patch", packet, "1")
    assert patched.returncode == 0, patched.stderr
    repeated = call(commands, tmp_path, patched.stdout, "wan-patch", packet, "2")
    assert (repeated.returncode, repeated.stdout) == (0, patched.stdout)
    value = json.loads(patched.stdout)
    value["generation"] = 1
    assert call(commands, tmp_path, encoded(value), "fresh").returncode != 0


def test_interrupted_wan_save_recovers_without_replaying_confirmation(
    shell, tools, store_fixture
):
    source, *_ = store_fixture
    before = (source / "config").read_bytes()
    script = ADAPTER.replace('cfmgr_config_store "$@"', 'cfmgr_config_wan_store "$@"')
    stopped = run_store(
        shell,
        tools,
        store_fixture,
        "save",
        "1",
        "confirmed",
        "wan:0",
        "wan:0",
        scenario="publish-stop",
        script=script,
    )
    assert stopped.returncode == 1, (stopped.stdout, stopped.stderr)
    assert b"recovery 0 1 absent unconfirmed - - END" in stopped.stdout
    assert (source / "config").read_bytes() == before
    assert (source / ".config-save").is_dir()
    recovered = run_store(shell, tools, store_fixture, "recover", script=script)
    assert (recovered.returncode, recovered.stdout) == (
        0,
        b"CFMGR-WAN-STORE 1 recovered 1 0 absent unconfirmed - - END\n",
    )
    assert (source / "config").read_bytes() == before
    assert not list(source.glob(".config-save*"))
