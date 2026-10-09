"""Native execution-root composition with bounded configuration data."""

from __future__ import annotations

import json
import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness
from tests.test_execution_root import ROOT
from tests.test_native_root import (
    DATA_HOSTS,
    DATA_RESOLVER,
    NATIVE_CONFIG,
    VIEW_IDS,
    VIEWS,
    NativeRootFixture,
)
from tests.test_storage import IO, STORAGE

SOURCE = ROOT / "modules/lib/isolation.sh"


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_data_root_stages_before_bind_and_cleans_complete_layout(
    router: RouterHarness,
) -> None:
    fixture = NativeRootFixture(router)
    result = fixture.run_native(
        data_root=True,
        callback_status=7,
        callback_args=("native args", "*", "check-native-data"),
    )

    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith(
        "RESULT\t7\nFDSTATE\toriginal-seven\toriginal-eight\toriginal-nine\toriginal-six\n"
    )
    image_etc = fixture.guard / "execution/image/etc"
    assert (image_etc / "hosts").read_bytes() == DATA_HOSTS
    assert (image_etc / "resolv.conf").read_bytes() == DATA_RESOLVER
    assert image_etc.stat().st_mode & 0o777 == 0o700
    assert (image_etc / "hosts").stat().st_mode & 0o777 == 0o600
    assert (image_etc / "resolv.conf").stat().st_mode & 0o777 == 0o600
    assert router.read("work/callback-data") == "staged data visible\n"
    assert fixture.callback_args.read_text() == "<native args>\n<*>\n"
    assert fixture.guard.joinpath("execution/complete").is_dir()
    assert not (fixture.guard / "execution/root/etc").exists()

    query_slots = sorted(
        (fixture.guard / "execution").glob("query-*"),
        key=lambda path: int(path.name[6:]),
    )
    assert [path.name for path in query_slots] == [f"query-{index}" for index in range(56)]
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    removed = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert removed == [*reversed(VIEWS), "root"]
    state = json.loads(fixture.state_path.read_text())
    assert [row["identifier"] for row in state["mounts"]] == ["1", "77", "88"]
    assert {VIEW_IDS[name] for name in VIEWS}.isdisjoint(
        {row["identifier"] for row in state["mounts"]}
    )


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_invalid_staged_data_stops_before_any_bind_or_callback(router: RouterHarness) -> None:
    fixture = NativeRootFixture(router, "data-nul")
    result = fixture.run_native(data_root=True, callback_args=("check-native-data",))

    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout.startswith("RESULT\t129\n")
    assert fixture.guard.is_dir()
    assert (fixture.guard / "execution/image").is_dir()
    assert not (fixture.guard / "execution/complete").exists()
    assert not (fixture.guard / "execution/intent-root").exists()
    assert not fixture.callback_root.exists()
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    assert not any(tool == "mount" for tool, _ in calls)


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_data_root_rejects_bad_arity_without_reserving_guard(
    router: RouterHarness,
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n. {shlex.quote(str(NATIVE_CONFIG))}\n"
        "cfmgr_isolation_native_data_root_test; status=$?\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t2\n"
    assert result.stderr == ""


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_data_production_entry_uses_literal_layout_and_forwards_arguments(
    router: RouterHarness,
) -> None:
    marker = router.path("work/native-data-dispatch")
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "_cfmgr_isolation_root_owner() {\n"
        '  printf \'%s\\n\' "$@" >"$CFMGR_TEST_ROOT/work/native-data-dispatch"\n'
        "}\n"
        'cfmgr_isolation_native_data_root_with "$@"\n'
    )
    args = [
        "/trusted/ram",
        "/trusted/guard",
        "/trusted/mountinfo.awk",
        "/trusted/storageinfo.awk",
        "observer",
        "arg with spaces",
    ]
    result = router.run(script, args)

    assert result.returncode == 0, result
    assert result.stdout == result.stderr == ""
    assert marker.read_text().splitlines() == ["native-data", "production", *args]
