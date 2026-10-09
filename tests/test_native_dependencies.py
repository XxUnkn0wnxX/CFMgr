"""Fixed native handoff to the bundled normal-opkg dependency backend."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_bootstrap import BOOTSTRAP, COMMON, OpkgFixture
from tests.test_native_shell import NativeShellFixture, quiet

pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


class NativeDependenciesFixture:
    """Compose the real bootstrap backend under the inert native chroot."""

    def __init__(
        self,
        router: RouterHarness,
        *,
        busybox: Path | None = None,
        mode: str = "dependencies",
    ) -> None:
        self.router = router
        self.shell = NativeShellFixture(router, mode, busybox=busybox)
        self.root = self.shell.native_root
        (self.root / "tmp").mkdir(mode=0o700)
        self.opkg = OpkgFixture(
            router,
            busybox=busybox,
            name="native-dependencies",
            root=self.root / "opt",
        )
        self.fd_witness = router.path("work/native-dependencies-fds.jsonl")
        self.opkg.settings["fd_witness"] = str(self.fd_witness)
        self.opkg.save()
        router.write("work/native-dependencies-opt-root", str(self.opkg.root))
        self.execution = self.shell.execution
        self.private = self.root / "tmp/cfmgr-dependencies"
        self.evidence = self.execution / "dependencies"

    def call(
        self,
        *,
        action: str = "repair",
        scope: str = "shared",
        lock_provider: str = "native",
        source: str | Path = BOOTSTRAP,
        suffix: tuple[str, ...] | None = None,
        context: str = "",
    ) -> ShellResult:
        args = (
            (
                str(source),
                action,
                scope,
                lock_provider,
            )
            if suffix is None
            else suffix
        )
        return self.shell.run(
            probe="dependencies",
            suffix=args,
            context=context,
        )

    def assert_outcome(self, result: ShellResult, status: int) -> None:
        quiet(result, 0)
        assert result.stdout == f"RESULT\t{status}\n"

    def assert_complete(
        self,
        action: str,
        scope: str,
        lock_provider: str,
        status: int,
        *,
        source: Path = BOOTSTRAP,
    ) -> None:
        assert (self.evidence / "bootstrap").read_bytes() == source.read_bytes()
        assert (self.evidence / "status").read_bytes() == (
            f"dependencies {action} {scope} {lock_provider} {status}\n".encode("ascii")
        )
        assert (self.evidence / "complete").is_dir()
        assert list((self.evidence / "complete").iterdir()) == []
        assert (self.private / "result").read_bytes() == (
            f"CFMGR_DEPENDENCIES_V1 {status}\n".encode("ascii")
        )


def _fd_rows(fixture: NativeDependenciesFixture) -> list[list[int]]:
    if not fixture.fd_witness.exists():
        return []
    return [json.loads(line) for line in fixture.fd_witness.read_text().splitlines()]


def test_healthy_repair_is_noop_and_publishes_exact_result(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router)
    fixture.opkg.seed("jq", "timeout", "sha256sum")

    result = fixture.call()

    fixture.assert_outcome(result, 0)
    fixture.assert_complete("repair", "shared", "native", 0)
    assert fixture.opkg.opkg_calls() == []
    assert [row[0] for row in fixture.opkg.probe_calls()] == ["jq", "timeout", "sha256sum"]
    assert fixture.shell.witness["argv"][-4:] == [
        "cfmgr-dependencies",
        "repair",
        "shared",
        "native",
    ]
    script = fixture.shell.witness["script"]
    assert script.lstrip("\n").startswith("exec 6<&-\n" + BOOTSTRAP.read_text())
    assert fixture.shell.witness["fd6_is_directory"] is True
    assert fixture.shell.witness["fds"] == [6]
    assert _fd_rows(fixture) == []


def test_missing_only_repair_writes_large_payload_and_closes_child_descriptors(
    router: RouterHarness,
) -> None:
    fixture = NativeDependenciesFixture(router)
    payload_size = 32 * 1024
    fixture.opkg.settings["payload_size"] = payload_size
    fixture.opkg.save()

    result = fixture.call()

    fixture.assert_outcome(result, 0)
    fixture.assert_complete("repair", "shared", "native", 0)
    assert fixture.opkg.opkg_calls() == [
        ["update"],
        ["install", *COMMON],
    ]
    assert [row[0] for row in fixture.opkg.probe_calls()] == ["jq", "timeout", "sha256sum"]
    payload = fixture.opkg.root / "share/native-dependency-payload"
    assert payload.stat().st_size == payload_size
    assert payload.read_bytes() == b"p" * payload_size
    assert _fd_rows(fixture) == [[], []]
    assert all(value is None for row in fixture.opkg.opkg_environments() for value in row.values())


def test_selected_reinstall_keeps_normal_scope_and_lock_arguments(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router)
    fixture.opkg.seed("jq", "timeout", "sha256sum", "dig", "flock")

    result = fixture.call(action="reinstall", scope="tunnel", lock_provider="entware")

    fixture.assert_outcome(result, 0)
    fixture.assert_complete("reinstall", "tunnel", "entware", 0)
    assert fixture.opkg.opkg_calls() == [
        ["update"],
        [
            "--force-reinstall",
            "install",
            "jq",
            "coreutils-timeout",
            "coreutils-sha256sum",
            "bind-dig",
            "flock",
        ],
    ]
    assert [row[0] for row in fixture.opkg.probe_calls()] == [
        "jq",
        "timeout",
        "sha256sum",
        "dig",
        "flock",
    ]


@pytest.mark.parametrize(
    ("failure", "expected_calls", "expected_probes"),
    [
        ("update", [["update"]], []),
        ("post-check", [["update"], ["install", *COMMON]], ["jq", "timeout"]),
    ],
    ids=["ordinary-opkg-failure", "post-check-failure"],
)
def test_ordinary_backend_and_post_check_failures_are_completed_negative(
    router: RouterHarness,
    failure: str,
    expected_calls: list[list[str]],
    expected_probes: list[str],
) -> None:
    fixture = NativeDependenciesFixture(router)
    if failure == "update":
        fixture.opkg.settings["update_status"] = 7
    else:
        fixture.opkg.settings["skip_install"] = ["coreutils-sha256sum"]
    fixture.opkg.save()

    result = fixture.call()

    fixture.assert_outcome(result, 1)
    fixture.assert_complete("repair", "shared", "native", 1)
    assert fixture.opkg.opkg_calls() == expected_calls
    assert [row[0] for row in fixture.opkg.probe_calls()] == expected_probes


@pytest.mark.parametrize(
    ("suffix", "expected"),
    [
        ((str(BOOTSTRAP), "repair", "invalid", "native"), 2),
        ((str(BOOTSTRAP), "repair", "shared", "invalid"), 2),
        ((str(BOOTSTRAP), "invalid", "shared", "native"), 2),
        (("relative/bootstrap.sh", "repair", "shared", "native"), 2),
        ((str(BOOTSTRAP), "repair", "shared"), 2),
        ((str(BOOTSTRAP), "repair", "shared", "native", "extra"), 2),
    ],
    ids=["scope", "lock-provider", "action", "source-syntax", "few-args", "extra-arg"],
)
def test_finite_api_and_source_syntax_refuse_before_effects(
    router: RouterHarness, suffix: tuple[str, ...], expected: int
) -> None:
    fixture = NativeDependenciesFixture(router)

    result = fixture.call(suffix=suffix)

    fixture.assert_outcome(result, expected)
    assert not fixture.shell.witness_path.exists()
    assert not fixture.evidence.exists()
    assert not fixture.private.exists()


@pytest.mark.parametrize(
    "source_kind",
    ["missing", "empty", "oversized", "symlink"],
    ids=["missing", "empty", "over-65536", "symlink"],
)
def test_unavailable_or_unframed_source_refuses_before_reservation(
    router: RouterHarness, source_kind: str
) -> None:
    fixture = NativeDependenciesFixture(router)
    source = router.path(f"work/native-bootstrap-{source_kind}")
    if source_kind == "empty":
        source.write_bytes(b"")
    elif source_kind == "oversized":
        source.write_bytes(b"x" * 65_537)
    elif source_kind == "symlink":
        source.symlink_to(BOOTSTRAP)

    result = fixture.call(source=source)

    fixture.assert_outcome(result, 1)
    assert not fixture.shell.witness_path.exists()
    assert not fixture.evidence.exists()
    assert not fixture.private.exists()


def test_copied_nul_framing_failure_retains_external_reservation(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router)
    source = router.write("work/native-bootstrap-nul", "echo safe\n\x00tail")

    result = fixture.call(source=source)

    fixture.assert_outcome(result, 129)
    assert (fixture.evidence / "bootstrap").read_bytes() == b"echo safe\n\x00tail"
    assert not fixture.shell.witness_path.exists()
    assert not (fixture.evidence / "status").exists()
    assert not (fixture.evidence / "complete").exists()


def test_maximum_unterminated_source_gets_separator_before_fixed_trailer(
    router: RouterHarness,
) -> None:
    fixture = NativeDependenciesFixture(router)
    prefix = b"cfmgr_bootstrap_dependencies() { return 0; }\n#"
    source_bytes = prefix + b"x" * (65_536 - len(prefix))
    assert len(source_bytes) == 65_536
    source = router.path("work/native-bootstrap-maximum")
    source.write_bytes(source_bytes)

    result = fixture.call(source=source)

    fixture.assert_outcome(result, 0)
    fixture.assert_complete("repair", "shared", "native", 0, source=source)
    script = fixture.shell.witness["script"]
    assert script.lstrip("\n").startswith("exec 6<&-\n" + source_bytes.decode("ascii") + "\n")


def test_preexisting_evidence_collision_is_preserved_before_launch(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router)
    fixture.evidence.mkdir(mode=0o700)
    prior = fixture.evidence / "prior"
    prior.write_bytes(b"keep\n")

    result = fixture.call()

    fixture.assert_outcome(result, 1)
    assert prior.read_bytes() == b"keep\n"
    assert not fixture.shell.witness_path.exists()
    assert not fixture.private.exists()


def test_early_exit_without_result_is_uncertain_and_retained(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router)
    source = router.write("work/native-bootstrap-exit", "exit 0\n")

    result = fixture.call(source=source)

    fixture.assert_outcome(result, 129)
    assert fixture.shell.witness_path.exists()
    assert (fixture.evidence / "bootstrap").read_bytes() == b"exit 0\n"
    assert not (fixture.private / "result").exists()
    assert not (fixture.evidence / "complete").exists()


def test_direct_exit_must_match_the_child_result_record(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router, mode="dependencies-exit-mismatch")
    fixture.opkg.settings["update_status"] = 7
    fixture.opkg.save()

    result = fixture.call()

    fixture.assert_outcome(result, 129)
    assert (fixture.private / "result").read_bytes() == b"CFMGR_DEPENDENCIES_V1 1\n"
    assert not (fixture.evidence / "status").exists()
    assert not (fixture.evidence / "complete").exists()


@pytest.mark.parametrize(
    "mode",
    [
        "dependencies-result-malformed",
        "dependencies-result-oversized",
        "dependencies-result-symlink",
    ],
    ids=["malformed", "oversized", "symlink"],
)
def test_result_record_must_be_exact_regular_bounded_data(router: RouterHarness, mode: str) -> None:
    fixture = NativeDependenciesFixture(router, mode=mode)
    fixture.opkg.seed("jq", "timeout", "sha256sum")

    result = fixture.call()

    fixture.assert_outcome(result, 129)
    assert fixture.shell.witness_path.exists()
    assert not (fixture.evidence / "status").exists()
    assert not (fixture.evidence / "complete").exists()


def test_result_writer_failure_is_uncertain_and_retains_reservation(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router, mode="dependencies-writer-fail")
    fixture.opkg.seed("jq", "timeout", "sha256sum")

    result = fixture.call()

    fixture.assert_outcome(result, 129)
    assert fixture.shell.witness_path.exists()
    assert (fixture.private / "result").read_bytes() == b""
    assert not (fixture.evidence / "status").exists()
    assert not (fixture.evidence / "complete").exists()


def test_external_publication_failure_retains_child_result_and_guard(router: RouterHarness) -> None:
    fixture = NativeDependenciesFixture(router)
    fixture.opkg.seed("jq", "timeout", "sha256sum")

    result = fixture.call(context="_cfmgr_isolation_write() { return 1; }")

    fixture.assert_outcome(result, 129)
    assert (fixture.private / "result").read_bytes() == b"CFMGR_DEPENDENCIES_V1 0\n"
    assert fixture.shell.witness_path.exists()
    assert not (fixture.evidence / "complete").exists()


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_actual_busybox_runs_finite_backend_handoff(busybox_router: RouterHarness) -> None:
    assert busybox_router.busybox is not None
    fixture = NativeDependenciesFixture(busybox_router, busybox=busybox_router.busybox)
    fixture.opkg.seed("jq", "timeout", "sha256sum")

    result = fixture.call(action="reinstall")

    fixture.assert_outcome(result, 0)
    fixture.assert_complete("reinstall", "shared", "native", 0)
    assert fixture.opkg.opkg_calls() == [
        ["update"],
        ["--force-reinstall", "install", *COMMON],
    ]
