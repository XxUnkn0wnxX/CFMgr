"""Owned projection of saved feature activation intent and Cloudflared mode."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_config_header import consume_group
from tests.test_config_header_report import (
    NATIVE_AWK,
    assert_clean,
    decode_group,
    lifecycle_report,
    make_config_fixture,
)
from tests.test_json import oracle as json_token_oracle

pytestmark = [pytest.mark.integration, pytest.mark.matrix("V42", evidence="host")]


def feature_config(
    *,
    cloudflared: dict[str, object] | None = None,
    ddns: dict[str, object] | None = None,
    ip_sync: dict[str, object] | None = None,
    generation: int = 7,
    developer: bool = True,
) -> dict[str, object]:
    features: dict[str, object] = {
        "cloudflared": cloudflared
        if cloudflared is not None
        else {
            "configured": False,
            "enabled": False,
            "maintenance_enabled": False,
            "mode": "none",
        },
        "ddns": ddns if ddns is not None else {"configured": False, "enabled": False},
        "ip-sync": ip_sync if ip_sync is not None else {"configured": False, "enabled": False},
    }
    return {
        "schema": 1,
        "generation": generation,
        "developer": developer,
        "features": features,
        "opaque": {"credential": "fixture-secret", "last_attempt": None},
    }


def document(value: dict[str, object]) -> bytes:
    return json.dumps(value, separators=(",", ":")).encode("ascii")


def token_ledger(value: dict[str, object]) -> bytes:
    return json_token_oracle(document(value)).encode("ascii")


def expected_lifecycle(value: dict[str, object]) -> bytes:
    features = value["features"]
    assert isinstance(features, dict)
    cloudflared = features["cloudflared"]
    ddns = features["ddns"]
    ip_sync = features["ip-sync"]
    assert isinstance(cloudflared, dict)
    assert isinstance(ddns, dict)
    assert isinstance(ip_sync, dict)

    def bool_text(flag: object) -> str:
        return "true" if flag else "false"

    body = (
        f"config-lifecycle\t1\t{value['generation']}\t{bool_text(value['developer'])}\n"
        + "cloudflared\t"
        + "\t".join(
            bool_text(cloudflared[key]) for key in ("configured", "enabled", "maintenance_enabled")
        )
        + f"\t{cloudflared['mode']}\n"
        + "ddns\t"
        + "\t".join(bool_text(ddns[key]) for key in ("configured", "enabled"))
        + "\n"
        + "ip-sync\t"
        + "\t".join(bool_text(ip_sync[key]) for key in ("configured", "enabled"))
        + "\n"
    ).encode("ascii")
    return body + f"end\t{len(body)}\n".encode("ascii")


def lifecycle_cases() -> list[tuple[str, dict[str, object], int]]:
    passive = feature_config(generation=0, developer=False)
    advanced = feature_config(
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "advanced",
        },
        ddns={"configured": True, "enabled": False},
        ip_sync={"configured": True, "enabled": False},
    )
    maintenance = feature_config(
        cloudflared={
            "configured": False,
            "enabled": False,
            "maintenance_enabled": True,
            "mode": "none",
        }
    )
    cases: list[tuple[str, dict[str, object], int]] = [
        ("passive", passive, 0),
        ("advanced-on", advanced, 0),
        ("maintenance-only", maintenance, 0),
    ]

    def invalid(name: str, update) -> None:
        value = feature_config()
        update(value)
        cases.append((name, value, 1))

    invalid("missing-features", lambda value: value.pop("features"))
    invalid("wrong-features-type", lambda value: value.__setitem__("features", []))
    invalid("missing-child", lambda value: value["features"].pop("ddns"))

    def root_lookalike(value: dict[str, object]) -> None:
        features = value.pop("features")
        value["opaque"]["features"] = features

    invalid("nested-root-lookalike", root_lookalike)

    def feature_parent_lookalike(value: dict[str, object]) -> None:
        features = value["features"]
        cloudflared = features.pop("cloudflared")
        features["other"] = {}
        features["other"]["cloudflared"] = cloudflared

    invalid("nested-feature-lookalike", feature_parent_lookalike)

    def wrong_child_type(value: dict[str, object]) -> None:
        value["features"]["ddns"] = []

    invalid("wrong-child-type", wrong_child_type)

    def nested_lookalike(value: dict[str, object]) -> None:
        cloudflared = value["features"]["cloudflared"]
        cloudflared.pop("configured")
        cloudflared["nested"] = {"configured": False}

    invalid("nested-lookalike", nested_lookalike)

    def missing_flag(value: dict[str, object]) -> None:
        value["features"]["ip-sync"].pop("enabled")

    invalid("missing-boolean", missing_flag)

    def wrong_boolean(value: dict[str, object]) -> None:
        value["features"]["ddns"]["enabled"] = "false"

    invalid("wrong-boolean-type", wrong_boolean)

    def missing_maintenance(value: dict[str, object]) -> None:
        value["features"]["cloudflared"].pop("maintenance_enabled")

    invalid("missing-maintenance", missing_maintenance)

    def wrong_maintenance_type(value: dict[str, object]) -> None:
        value["features"]["cloudflared"]["maintenance_enabled"] = 1

    invalid("wrong-maintenance-type", wrong_maintenance_type)

    def missing_mode(value: dict[str, object]) -> None:
        value["features"]["cloudflared"].pop("mode")

    invalid("missing-mode", missing_mode)

    def wrong_mode_type(value: dict[str, object]) -> None:
        value["features"]["cloudflared"]["mode"] = True

    invalid("wrong-mode-type", wrong_mode_type)

    def cloudflared_enabled_unconfigured(value: dict[str, object]) -> None:
        cloudflared = value["features"]["cloudflared"]
        cloudflared.update(enabled=True, maintenance_enabled=True)

    invalid("cloudflared-enabled-unconfigured", cloudflared_enabled_unconfigured)

    def ddns_enabled_unconfigured(value: dict[str, object]) -> None:
        value["features"]["ddns"]["enabled"] = True

    invalid("ddns-enabled-unconfigured", ddns_enabled_unconfigured)

    def ip_sync_enabled_unconfigured(value: dict[str, object]) -> None:
        value["features"]["ip-sync"]["enabled"] = True

    invalid("ip-sync-enabled-unconfigured", ip_sync_enabled_unconfigured)

    def cloudflared_missing_maintenance_gate(value: dict[str, object]) -> None:
        cloudflared = value["features"]["cloudflared"]
        cloudflared.update(configured=True, enabled=True, maintenance_enabled=False, mode="token")

    invalid("cloudflared-enabled-without-maintenance", cloudflared_missing_maintenance_gate)

    def configured_none_mode(value: dict[str, object]) -> None:
        value["features"]["cloudflared"].update(configured=True, mode="none")

    invalid("configured-none-mode", configured_none_mode)

    def unconfigured_token_mode(value: dict[str, object]) -> None:
        value["features"]["cloudflared"]["mode"] = "token"

    invalid("unconfigured-token-mode", unconfigured_token_mode)

    def unknown_mode(value: dict[str, object]) -> None:
        value["features"]["cloudflared"]["mode"] = "off"

    invalid("unknown-mode", unknown_mode)
    return cases


def test_lifecycle_owner_reports_passive_on_and_maintenance_state(
    router: RouterHarness, pytestconfig: pytest.Config
) -> None:
    package, config, json_parser, header_parser = make_config_fixture(
        router, pytestconfig._cfmgr_busybox
    )
    passive = feature_config(generation=0, developer=False)
    token_on = feature_config(
        generation=22,
        developer=True,
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "token",
        },
        ddns={"configured": True, "enabled": True},
        ip_sync={"configured": False, "enabled": False},
    )
    maintenance_only = feature_config(
        generation=23,
        cloudflared={
            "configured": False,
            "enabled": False,
            "maintenance_enabled": True,
            "mode": "none",
        },
        ddns={"configured": True, "enabled": False},
        ip_sync={"configured": True, "enabled": False},
    )
    for name, value in (
        ("passive", passive),
        ("token-on-without-installed-evidence", token_on),
        ("maintenance-only", maintenance_only),
    ):
        input_path = router.path(f"work/lifecycle-{name}.json")
        input_path.write_bytes(document(value))
        input_path.chmod(0o600)
        result = lifecycle_report(package, input_path, json_parser, header_parser)
        assert result.returncode == 0 and result.stderr == "", result
        assert result.stdout.encode("ascii") == expected_lifecycle(value)
        assert_clean(package)

    invalid_on = feature_config()
    invalid_on["features"]["ddns"].update(enabled=True)
    input_path = router.path("work/lifecycle-invalid.json")
    input_path.write_bytes(document(invalid_on))
    input_path.chmod(0o600)
    failed = lifecycle_report(package, input_path, json_parser, header_parser)
    assert failed.returncode == 1
    assert failed.stdout == failed.stderr == ""
    assert_clean(package)


def test_lifecycle_parser_checks_required_fields_parent_paths_and_implications_as_a_group(
    router: RouterHarness,
) -> None:
    router.path("bin/awk").symlink_to(NATIVE_AWK)
    cases = lifecycle_cases()
    result = consume_group(
        router,
        [(name, token_ledger(value)) for name, value, _status in cases],
        mode="lifecycle",
    )
    expected = b""
    for name, value, status in cases:
        if status == 0:
            expected += expected_lifecycle(value) + f"{name}\t0\n".encode("ascii")
        else:
            expected += f"{name}\t1\n".encode("ascii")
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.encode("ascii") == expected


def test_lifecycle_decoder_rejects_bad_projection_framing_as_a_group(
    router: RouterHarness, pytestconfig: pytest.Config
) -> None:
    package, _, _, _ = make_config_fixture(router, pytestconfig._cfmgr_busybox)
    valid_value = feature_config(
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "token",
        },
        ddns={"configured": True, "enabled": True},
    )
    valid = expected_lifecycle(valid_value)
    maximum = expected_lifecycle(feature_config(generation=2147483647))
    root = router.path("work/lifecycle-projections")
    root.mkdir()
    cases: list[tuple[int, Path, int]] = []

    def add(name: str, data: bytes, status: int = 1) -> None:
        path = root / name
        path.write_bytes(data)
        cases.append((status, path, len(data)))

    add("valid", valid, 0)
    add("maximum-generation", maximum, 0)
    nul = valid.replace(b"\ttrue\n", b"\tt\x00rue\n", 1)
    add("nul", nul)
    body, _footer = valid.rsplit(b"end\t", 1)
    add("footer", body + f"end\t{len(body) + 1}\n".encode("ascii"))
    add("missing-lf", valid[:-1])
    add("trailing-record", valid + b"extra\n")
    add("partial-trailing-record", valid + b"extra")
    rows = valid.decode("ascii").splitlines()[:-1]

    def add_rows(name: str, changed: list[str]) -> None:
        body = "".join(row + "\n" for row in changed).encode("ascii")
        add(name, body + f"end\t{len(body)}\n".encode("ascii"))

    changed = rows.copy()
    changed[1], changed[2] = changed[2], changed[1]
    add_rows("swapped-feature-rows", changed)
    add_rows("missing-feature-row", rows[:-1])
    changed = rows.copy()
    changed[2] = "ddns\tperhaps\ttrue"
    add_rows("invalid-boolean", changed)
    changed = rows.copy()
    changed[1] = "cloudflared\ttrue\ttrue\tfalse\ttoken"
    add_rows("cloudflared-enabled-without-maintenance", changed)
    changed = rows.copy()
    changed[1] = "cloudflared\ttrue\ttrue\ttrue\tnone"
    add_rows("cloudflared-invalid-mode-relation", changed)
    changed = rows.copy()
    changed[2] = "ddns\tfalse\ttrue"
    add_rows("ddns-enabled-unconfigured", changed)
    changed = rows.copy()
    changed[3] = "ip-sync\tfalse\ttrue"
    add_rows("ip-sync-enabled-unconfigured", changed)
    result = decode_group(package, tuple(cases), lifecycle=True)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == "0\n0\n" + "1\n" * 12
    assert_clean(package)


@pytest.mark.busybox
@pytest.mark.matrix("V42", evidence="busybox")
def test_actual_busybox_composes_lifecycle_report_at_generation_maximum(
    busybox_router: RouterHarness,
) -> None:
    package, config, json_parser, header_parser = make_config_fixture(
        busybox_router, busybox_router.busybox
    )
    value = feature_config(
        generation=2147483647,
        developer=False,
        cloudflared={
            "configured": True,
            "enabled": True,
            "maintenance_enabled": True,
            "mode": "advanced",
        },
        ddns={"configured": True, "enabled": False},
    )
    config.write_bytes(document(value))
    result = lifecycle_report(package, config, json_parser, header_parser)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout.encode("ascii") == expected_lifecycle(value)
    assert_clean(package)
