"""Focused completion-protocol checks for the reviewed acquisition subtree."""

from __future__ import annotations

import shlex
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_acquisition import AcquisitionFixture

ROOT = Path(__file__).resolve().parents[1]
CLOSURE = ROOT / "modules/closure.sh"
FETCH = ROOT / "modules/fetch.sh"
BOOTSTRAP = ROOT / "modules/bootstrap.sh"
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


def test_owned_materializer_resets_and_accepts_only_audited_results(
    router: RouterHarness,
) -> None:
    script = (
        f". {shlex.quote(str(CLOSURE))}\n"
        f". {shlex.quote(str(FETCH))}\n"
        f". {shlex.quote(str(BOOTSTRAP))}\n"
        '_cfmgr_bootstrap_materialize_run() { return "$_test_result"; }\n'
        "for _test_result in 0 10 2 1 129; do\n"
        "  _materialize_complete=7\n"
        '  _cfmgr_bootstrap_materialize_owned "" aarch64-k3.10 /tmp/materialize\n'
        "  _test_status=$?\n"
        '  printf "%s\\t%s\\n" "$_test_result" "$_test_status:$_materialize_complete"\n'
        "done\n"
    )
    result = router.run(script)

    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout.splitlines() == [
        "0\t0:1",
        "10\t1:1",
        "2\t129:0",
        "1\t129:0",
        "129\t129:0",
    ]


def test_public_and_owned_status_mapping_runs_under_caller_errexit(
    router: RouterHarness,
) -> None:
    for label, owned, worker_status, expected_status, expected_complete in (
        ("public", False, 10, 1, "0"),
        ("owned-complete-failure", True, 10, 1, "1"),
        ("owned-uncertain", True, 129, 129, "0"),
    ):
        marker = router.path(f"work/errexit-{label}")
        entry = (
            '_cfmgr_bootstrap_materialize_owned "" aarch64-k3.10 /tmp/materialize\n'
            if owned
            else "cfmgr_bootstrap_materialize aarch64-k3.10 /tmp/materialize\n"
        )
        script = (
            f". {shlex.quote(str(CLOSURE))}\n"
            f". {shlex.quote(str(FETCH))}\n"
            f". {shlex.quote(str(BOOTSTRAP))}\n"
            f"_cfmgr_bootstrap_materialize_run() {{ return {worker_status}; }}\n"
            "_materialize_complete=0\n"
            f'trap \'printf "%s\\\\n" "$_materialize_complete" > {shlex.quote(str(marker))}\' 0\n'
            "set -e\n" + entry + "printf after-call > " + shlex.quote(str(marker)) + "\n"
        )
        result = router.run(script)

        assert result.returncode == expected_status, f"{label}: {result}"
        assert marker.read_text().strip() == expected_complete


def test_native_curl_exit_10_is_completed_failure_and_stops_materialization(
    router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(router)
    timeout_url = str(fixture.packages["coreutils-timeout"]["url"])
    fixture._install_curl(fail_url=timeout_url, fail_status=10)
    fixture.instrument_parsers()
    result = fixture.invoke(
        fixture.override_selectors()
        + f"_cfmgr_bootstrap_materialize_owned {shlex.quote(str(fixture.tools))} "
        + f"aarch64-k3.10 {shlex.quote(str(fixture.directory))}\n"
        + '_status=$?\nprintf "RESULT\\t%s\\t%s\\n" "$_status" "$_materialize_complete"\n'
    )

    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t1\t1\n"
    assert (fixture.directory / "timeout-download/artifact.ipk").read_bytes() == fixture.packages[
        "coreutils-timeout"
    ]["archive"]
    assert fixture.events.read_text().splitlines() == ["fetch:coreutils-timeout"]
    assert not (fixture.directory / "timeout").exists()


def test_archive_hash_rejection_is_completed_failure_for_materialization_owner(
    router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(router)
    fixture.instrument_parsers()
    result = fixture.invoke(
        fixture.override_selectors(bad_outer_sha="coreutils-timeout")
        + f"_cfmgr_bootstrap_materialize_owned {shlex.quote(str(fixture.tools))} "
        + f"aarch64-k3.10 {shlex.quote(str(fixture.directory))}\n"
        + '_status=$?\nprintf "RESULT\\t%s\\t%s\\n" "$_status" "$_materialize_complete"\n'
    )

    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t1\t1\n"
    assert (fixture.directory / "timeout-download/artifact.ipk").is_file()
    assert (fixture.directory / "timeout/archive.ipk").is_file()
    assert fixture.events.read_text().splitlines() == [
        "fetch:coreutils-timeout",
        "dd",
        "gunzip",
    ]
    assert (fixture.directory / "timeout/outer.tar").is_file()
    assert not (fixture.directory / "timeout/data.tar.gz").exists()


def invoke_expected_wc_uncertainty(fixture: AcquisitionFixture) -> ShellResult:
    expected_count = len(fixture.packages["coreutils-timeout"]["archive"])
    wc = fixture.tools / "wc"
    wc.unlink()
    wc.write_text(f"#!/bin/sh\nprintf '{expected_count}\\n'\nexit 129\n", encoding="utf-8")
    wc.chmod(0o700)
    return fixture.invoke(
        fixture.override_selectors()
        + f"_cfmgr_bootstrap_materialize_owned {shlex.quote(str(fixture.tools))} "
        + f"aarch64-k3.10 {shlex.quote(str(fixture.directory))}\n"
        + '_status=$?\nprintf "RESULT\\t%s\\t%s\\n" "$_status" "$_materialize_complete"\n'
    )


def assert_wc_uncertainty_retains_partial(fixture: AcquisitionFixture, result: ShellResult) -> None:
    assert result.returncode == 0 and result.stderr == ""
    assert result.stdout == "RESULT\t129\t0\n"
    assert (fixture.directory / "timeout-download/artifact.ipk").read_bytes() == fixture.packages[
        "coreutils-timeout"
    ]["archive"]
    assert fixture.events.read_text().splitlines() == ["fetch:coreutils-timeout"]
    assert not (fixture.directory / "timeout").exists()


def test_expected_wc_count_with_uncertain_status_does_not_complete_owner(
    router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(router)
    result = invoke_expected_wc_uncertainty(fixture)
    assert_wc_uncertainty_retains_partial(fixture, result)


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_busybox_materializer_keeps_wc_uncertainty_uncompleted(
    busybox_router: RouterHarness,
) -> None:
    fixture = AcquisitionFixture(busybox_router, busybox=busybox_router.busybox)
    result = invoke_expected_wc_uncertainty(fixture)
    assert_wc_uncertainty_retains_partial(fixture, result)
