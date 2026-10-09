"""Opaque bounded acquisition of the fixed native configuration set."""

from __future__ import annotations

import json
import shlex
import shutil
import sys
from pathlib import Path
from textwrap import dedent

import pytest

from tests.harness import RouterHarness
from tests.test_native_config import (
    IO_SOURCE,
    SOURCE,
    NativeConfigFixture,
    quiet,
)

EXTRA_CAP = 65_536
CA_CAP = 1_048_576


def _set_payloads(fixture: NativeConfigFixture, payloads: dict[str, bytes]) -> None:
    for name, payload in payloads.items():
        fixture.extra_payloads[name] = payload
        source = fixture.extra_sources[name]
        if source.is_symlink():
            source.unlink()
        source.write_bytes(payload)


def _destination(fixture: NativeConfigFixture, name: str) -> Path:
    if name == "ca-certificates.crt":
        return fixture.etc() / "ssl/certs/ca-certificates.crt"
    return fixture.etc() / name


def _extra_copy_consumer(
    router: RouterHarness, fault: str
) -> tuple[str, list[str], dict[str, Path]]:
    source = router.path("work/extra-source")
    source.write_bytes(b"opaque\x00bytes\n")
    destination = router.path("ram/image/etc/extra")
    destination.parent.mkdir(parents=True, mode=0o700)
    probe = router.path("ram/tmp/io-stage/native-config-extra-0.eof")
    probe.parent.mkdir(parents=True, mode=0o700)
    descriptor = router.write("work/fd-six", "before-helper\nafter-helper\n")
    log = router.path("work/dd-observations.jsonl")
    settings = router.write("work/dd-settings.json", json.dumps({"fault": fault, "log": str(log)}))
    dd_program = router.write(
        "work/dd-double.py",
        dedent(
            r"""
            import json, os, resource, sys
            from pathlib import Path
            config = json.loads(Path(sys.argv[1]).read_text())
            args = sys.argv[2:]
            probe = "bs=1" in args
            limit = resource.getrlimit(resource.RLIMIT_FSIZE)[0]
            with Path(config["log"]).open("a") as stream:
                stream.write(json.dumps({"args": args, "probe": probe, "limit": limit}) + "\n")
            if probe:
                if config["fault"] == "probe-fail":
                    sys.exit(7)
                sys.stdout.buffer.write(os.read(0, 1))
                sys.exit(0)
            if config["fault"] == "short-bulk":
                sys.stdout.buffer.write(os.read(0, 3))
                sys.exit(0)
            data = sys.stdin.buffer.read()
            if config["fault"] == "bulk-fail":
                sys.stdout.buffer.write(data[:3])
                sys.exit(7)
            if config["fault"] == "truncated-zero":
                sys.stdout.buffer.write(data[:-1])
                sys.exit(0)
            if config["fault"] == "same-size-corruption":
                sys.stdout.buffer.write(bytes([data[0] ^ 1]) + data[1:])
                sys.exit(0)
            if config["fault"] == "bulk-write-fail":
                try:
                    sys.stdout.buffer.write(b"x" * 200000)
                    sys.stdout.buffer.flush()
                except OSError:
                    sys.exit(7)
                sys.exit(0)
            sys.stdout.buffer.write(data)
            """
        ),
    )
    dd_program.chmod(0o700)
    dd = router.write(
        "bin/dd",
        f"#!/bin/sh\nexec {shlex.quote(sys.executable)} {shlex.quote(str(dd_program))} "
        f'{shlex.quote(str(settings))} "$@"\n',
        executable=True,
    )
    cmp_real = shutil.which("cmp")
    assert cmp_real is not None
    cmp = router.write(
        "bin/cmp",
        '#!/bin/sh\nprintf \'%s\\n\' "$*" >>"$CFMGR_CMP_LOG"\n'
        'if [ "$CFMGR_FAULT" = cmp-fail ]; then exit 8; fi\n'
        f'exec {shlex.quote(cmp_real)} "$@"\n',
        executable=True,
    )
    script = (
        f". {shlex.quote(str(SOURCE))}\n"
        f"_native_dd={shlex.quote(str(dd))}; _native_cmp={shlex.quote(str(cmp))}\n"
        f"_io_wc={shlex.quote(shutil.which('wc') or '/usr/bin/wc')}\n"
        f"_io_stage={shlex.quote(str(probe.parent))}\n"
        f"CFMGR_FAULT={shlex.quote(fault)}; export CFMGR_FAULT\n"
        f"CFMGR_CMP_LOG={shlex.quote(str(router.path('work/cmp-calls')))}; export CFMGR_CMP_LOG\n"
        f"exec 6<{shlex.quote(str(descriptor))}\n"
        "IFS= read -r before <&6\n"
        f"_cfmgr_native_config_extra_copy {shlex.quote(str(source))} "
        f"{shlex.quote(str(destination))} {shlex.quote(str(probe))} 65536 16; status=$?\n"
        "IFS= read -r after <&6 || after=EOF\n"
        'printf "RESULT\\t%s\\t%s\\t%s\\n" "$status" "$before" "$after"\n'
    )
    return (
        script,
        [],
        {
            "source": source,
            "destination": destination,
            "probe": probe,
            "log": log,
            "cmp_log": router.path("work/cmp-calls"),
        },
    )


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("fault", "status", "destination", "probe", "cmp_calls"),
    [
        ("", 0, b"opaque\x00bytes\n", b"", 1),
        ("short-bulk", 1, b"opa", b"q", 0),
        ("bulk-fail", 1, b"opa", None, 0),
        ("bulk-write-fail", 1, "bounded", None, 0),
        ("probe-fail", 1, b"opaque\x00bytes\n", b"", 0),
        ("truncated-zero", 1, b"opaque\x00bytes", b"", 1),
        ("same-size-corruption", 1, b"npaque\x00bytes\n", b"", 1),
        ("cmp-fail", 1, b"opaque\x00bytes\n", b"", 1),
    ],
    ids=[
        "copy-and-preserve-fd-offset",
        "short-read-probe-sees-unread-byte",
        "bulk-producer-failure-retains-partial-file",
        "bulk-write-file-limit-retains-partial-file",
        "eof-producer-failure",
        "zero-exit-truncation-refused",
        "same-size-corruption-refused-by-cmp",
        "comparison-failure-refused",
    ],
)
def test_extra_copy_checks_both_reads_size_and_comparison(
    router: RouterHarness,
    fault: str,
    status: int,
    destination: bytes | str,
    probe: bytes | None,
    cmp_calls: int,
) -> None:
    script, args, paths = _extra_copy_consumer(router, fault)

    result = router.run(script, args)

    assert result.returncode == 0, result
    assert result.stdout == f"RESULT\t{status}\tbefore-helper\tafter-helper\n"
    assert result.stderr == ""
    dest_path, probe_path = paths["destination"], paths["probe"]
    assert dest_path.exists()
    if destination == "bounded":
        assert 0 < dest_path.stat().st_size <= 131_072
    else:
        assert dest_path.read_bytes() == destination
    assert probe_path.exists() is (probe is not None)
    if probe is not None:
        assert probe_path.read_bytes() == probe
    cmp_log = paths["cmp_log"]
    calls = cmp_log.read_text().splitlines() if cmp_log.exists() else []
    assert len(calls) == cmp_calls
    assert calls == ([f"-s {paths['source']} {dest_path}"] if cmp_calls else [])
    observations = [json.loads(line) for line in paths["log"].read_text().splitlines()]
    if fault == "":
        assert [record["args"] for record in observations] == [
            ["bs=4096", "count=16"],
            ["bs=1", "count=1"],
        ]
        assert observations[0]["limit"] <= 131_072
        assert observations[1]["limit"] <= 1_024


@pytest.mark.unit
@pytest.mark.parametrize("collision", ["destination", "probe"])
def test_extra_copy_never_adopts_existing_output_or_probe(
    router: RouterHarness, collision: str
) -> None:
    script, args, paths = _extra_copy_consumer(router, "")
    artifact = paths[collision]
    artifact.write_bytes(b"keep foreign bytes\n")

    result = router.run(script, args)

    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t1\tbefore-helper\tafter-helper\n"
    assert result.stderr == ""
    assert artifact.read_bytes() == b"keep foreign bytes\n"
    assert not paths["log"].exists()


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_extra_size_refuses_failed_or_invalid_count_evidence(router: RouterHarness) -> None:
    source = router.write("work/bounded-count-input", "x")
    counter = router.fake_tool(
        "wc",
        'case "$CFMGR_COUNT_MODE" in\n'
        "  failed) printf '0\\n'; exit 7 ;;\n"
        "  malformed) printf '1 extra\\n' ;;\n"
        "  oversized) printf '1048577\\n' ;;\n"
        "esac\n",
    )
    result = router.run(
        f". {shlex.quote(str(SOURCE))}\n"
        f"_io_wc={shlex.quote(str(counter))}\n"
        "for CFMGR_COUNT_MODE in failed malformed oversized; do\n"
        "  export CFMGR_COUNT_MODE\n"
        f"  count=$(_cfmgr_native_config_extra_size {shlex.quote(str(source))} 1048576)\n"
        "  status=$?\n"
        '  printf "%s\\t%s\\t%s\\n" "$CFMGR_COUNT_MODE" "$status" "$count"\n'
        "done\n",
    )

    assert result.returncode == 0, result
    assert result.stdout == "failed\t1\t\nmalformed\t1\t\noversized\t1\t\n"
    assert result.stderr == ""
    assert source.read_text() == "x"


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_extended_stage_preserves_opaque_bytes_and_exact_limits(
    router: RouterHarness,
) -> None:
    fixture = NativeConfigFixture(router, extended=True, preserve_fd6=True)
    payloads = {
        "nsswitch.conf": b"hosts: files dns\x00opaque\n",
        "wgetrc": b"",
        "openssl.cnf": bytes(range(256)) * 256,
        "ca-certificates.crt": bytes(range(256)) * 4096,
    }
    _set_payloads(fixture, payloads)
    openssl_source = fixture.extra_sources["openssl.cnf"]
    openssl_target = fixture.source_root / "etc/openssl.payload"
    openssl_source.replace(openssl_target)
    openssl_source.symlink_to(openssl_target.name)

    result = fixture.run(timeout=30)

    quiet(result, 0)
    assert fixture.stage_status() == 0
    assert router.path("work/helper-state-preserved").is_file()
    assert router.path("work/fd-state-preserved").is_file()
    assert not router.path("work/helper-state-changed").exists()
    assert (fixture.etc() / "hosts").read_bytes() == b"127.0.0.1\tlocalhost\\x\n\n"
    assert (fixture.etc() / "resolv.conf").read_bytes() == b""
    assert openssl_source.is_symlink()
    for name, payload in payloads.items():
        destination = _destination(fixture, name)
        assert destination.read_bytes() == payload
        assert destination.stat().st_mode & 0o777 == 0o600
    assert len(payloads["openssl.cnf"]) == EXTRA_CAP
    assert len(payloads["ca-certificates.crt"]) == CA_CAP
    assert (fixture.etc() / "ssl").stat().st_mode & 0o777 == 0o700
    assert (fixture.etc() / "ssl/certs").stat().st_mode & 0o777 == 0o700
    assert not list(router.path("ram/tmp").glob("cfmgr-io.*"))


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("name", "payload"),
    [
        ("nsswitch.conf", b"x" * (EXTRA_CAP + 1)),
        ("ca-certificates.crt", b"x" * (CA_CAP + 1)),
    ],
    ids=["small-file-cap-plus-one", "certificate-cap-plus-one"],
)
def test_extended_stage_refuses_each_size_class_and_retains_bounded_partial_image(
    router: RouterHarness, name: str, payload: bytes
) -> None:
    fixture = NativeConfigFixture(router, extended=True)
    _set_payloads(fixture, {name: payload})

    quiet(fixture.run(timeout=20), 1)

    assert fixture.stage_status() == 1
    assert (fixture.etc() / "hosts").read_bytes() == b"127.0.0.1\tlocalhost\\x\n\n"
    assert (fixture.etc() / "resolv.conf").read_bytes() == b""
    partial = _destination(fixture, name)
    assert partial.is_file() and not partial.is_symlink()
    assert partial.stat().st_size <= (CA_CAP if name == "ca-certificates.crt" else EXTRA_CAP)
    order = ["nsswitch.conf", "wgetrc", "openssl.cnf", "ca-certificates.crt"]
    for later in order[order.index(name) + 1 :]:
        assert not _destination(fixture, later).exists()
    assert not list(router.path("ram/tmp").glob("cfmgr-io.*"))


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize("source_shape", ["missing", "directory"])
def test_extended_stage_requires_each_fixed_source_to_be_a_regular_file(
    router: RouterHarness, source_shape: str
) -> None:
    fixture = NativeConfigFixture(router, extended=True)
    source = fixture.extra_sources["wgetrc"]
    source.unlink()
    if source_shape == "directory":
        source.mkdir()

    quiet(fixture.run(), 1)

    assert fixture.stage_status() == 1
    assert not fixture.etc().exists()


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_extended_stage_requires_fresh_eof_artifacts_before_old_mutation(
    router: RouterHarness,
) -> None:
    fixture = NativeConfigFixture(router, extended=True)
    fixture.script = fixture.script.replace(
        "scratch=$1; shift\n",
        'scratch=$1; shift\n: >"$scratch/native-config-extra-2.eof"\n',
    )
    router.write("work/invoke.sh", fixture.script)

    quiet(fixture.run("fail-cleanup"), 1)

    assert fixture.stage_status() == 1
    assert not fixture.etc().exists()
    stages = list(router.path("ram/tmp").glob("cfmgr-io.*"))
    assert len(stages) == 1
    assert (stages[0] / "native-config-extra-2.eof").read_bytes() == b""


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_extended_outer_io_cleanup_failure_overrides_successful_staging(
    router: RouterHarness,
) -> None:
    fixture = NativeConfigFixture(router, extended=True)

    quiet(fixture.run("fail-cleanup", timeout=20), 1)

    assert fixture.stage_status() == 0
    assert (fixture.etc() / "hosts").read_bytes() == b"127.0.0.1\tlocalhost\\x\n\n"
    assert (
        _destination(fixture, "ca-certificates.crt")
    ).read_bytes() == b"fixture-cert-bundle\x00\n"
    stages = list(router.path("ram/tmp").glob("cfmgr-io.*"))
    assert len(stages) == 1


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_extended_bad_api_and_missing_io_context_return_two(router: RouterHarness) -> None:
    fixture = NativeConfigFixture(router, extended=True)
    result = router.run(
        f". {shlex.quote(str(IO_SOURCE))}\n"
        f". {shlex.quote(str(SOURCE))}\n"
        "cfmgr_native_config_extended_test; status=$?\n"
        'printf "STATUS\\t%s\\n" "$status"\n'
        'cfmgr_native_config_extended_test "$1" "$2"; status=$?\n'
        'printf "STATUS\\t%s\\n" "$status"\n',
        [str(fixture.image), str(fixture.source_root)],
    )

    assert result.returncode == 0, result
    assert result.stdout == "STATUS\t2\nSTATUS\t2\n"
    assert result.stderr == ""
    assert not fixture.etc().exists()


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_extended_source_only_production_dispatch_preserves_fixed_api(
    router: RouterHarness,
) -> None:
    image = str(router.path("ram/tmp/image with space"))
    result = router.run(
        f". {shlex.quote(str(IO_SOURCE))}\n"
        "IFS=x; set -f; umask 027; trap ':' TERM\n"
        "before_options=$(set +o); before_trap=$(trap); before_pwd=$PWD\n"
        f". {shlex.quote(str(SOURCE))}\n"
        '[ "$IFS" = x ] && [ "$(umask)" = 0027 ] && [ "$before_options" = "$(set +o)" ] && '
        '[ "$before_trap" = "$(trap)" ] && [ "$before_pwd" = "$PWD" ] || exit 9\n'
        "_cfmgr_native_config_extended_run() {\n"
        '  printf \'%s\\n\' "$@" >"$CFMGR_TEST_ROOT/work/dispatch"\n'
        "}\n"
        'cfmgr_native_config_extended_stage "$1"; status=$?\n'
        '[ "$status" = 0 ] && [ "$IFS" = x ] && [ "$(umask)" = 0027 ] && '
        '[ "$before_options" = "$(set +o)" ] && [ "$before_trap" = "$(trap)" ] && '
        '[ "$before_pwd" = "$PWD" ]\n',
        [image],
    )

    quiet(result, 0)
    assert router.read("work/dispatch").splitlines() == ["production", image, "/"]
