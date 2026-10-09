"""Fixed character-device views inside the checked Entware execution root."""

from __future__ import annotations

import json
import os
import shlex
import shutil
import sys
from pathlib import Path
from textwrap import dedent

import pytest

from tests.harness import RouterHarness
from tests.test_entware_root import assert_native_config_bytes, run_native_opt
from tests.test_execution_root import ROOT

STORAGEINFO = ROOT / "modules/lib/storageinfo.awk"
DEVICE_LINES = {
    "charnull": b" 123 crw------- 1 0 0 1, 3 Jan 1 00:00 null\n",
    "charurandom": b"123 crw------- 1 0 0 1, 9 Jan 1 00:00 urandom\n",
}


def _parse_device(router: RouterHarness, data: bytes, mode: str):
    awk = shutil.which("awk")
    assert awk is not None
    router.path("bin/awk").symlink_to(awk)
    parser = router.write("work/storageinfo.awk", STORAGEINFO.read_text(encoding="utf-8"))
    observation = router.path("ram/device-observation")
    observation.write_bytes(data)
    return router.run(
        'awk "$@" < "$RAM_ROOT/device-observation"\n',
        [
            "-v",
            f"cfmgr_storageinfo_mode={mode}",
            "-v",
            f"cfmgr_storageinfo_size={len(data)}",
            "-f",
            str(parser),
        ],
        env={"LC_ALL": "C"},
    )


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mode", "line", "inode"),
    [
        ("charnull", DEVICE_LINES["charnull"], "123"),
        ("charurandom", DEVICE_LINES["charurandom"], "123"),
        ("charnull", b" " + b"9" * 20 + DEVICE_LINES["charnull"][4:], "9" * 20),
    ],
)
def test_device_parser_emits_exact_profile_and_preserves_inode_text(
    router: RouterHarness, mode: str, line: bytes, inode: str
) -> None:
    result = _parse_device(router, line, mode)
    body = f"{mode}\t{inode}\n"
    assert result.returncode == 0, result
    assert result.stderr == "", (result.stdout, result.stderr)
    assert result.stdout == body + f"end\t{len(body.encode())}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mode", "line"),
    [
        ("charnull", DEVICE_LINES["charnull"].replace(b"crw-------", b"brw-------")),
        ("charnull", DEVICE_LINES["charnull"].replace(b"1, 3", b"1, 9")),
        ("charurandom", DEVICE_LINES["charurandom"].replace(b"urandom", b"null")),
        ("charurandom", DEVICE_LINES["charurandom"].replace(b"1 0 0", b"1 0 1")),
        ("charnull", DEVICE_LINES["charnull"].replace(b"123 ", b"0 ")),
        ("charnull", DEVICE_LINES["charnull"] + b"trailing\n"),
    ],
)
def test_device_parser_rejects_untrusted_identity_fields_quietly(
    router: RouterHarness, mode: str, line: bytes
) -> None:
    result = _parse_device(router, line, mode)
    assert result.returncode == 1, result
    assert result.stdout == result.stderr == ""


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_devices_fixture_rejects_bad_api_before_reservation(
    router: RouterHarness,
) -> None:
    result = router.run(
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/storage.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/native_config.sh"\n'
        f'. "{ROOT}/modules/lib/isolation.sh"\n'
        f'. "{ROOT}/modules/lib/entware_root.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        'cfmgr_isolation_native_devices_root_test "$@"; status=$?\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t2\n"
    assert result.stderr == ""
    assert not router.path("ram/tmp/cfmgr-execution-guard/execution").exists()


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_native_config_root_sets_only_its_literal_extended_policy(
    router: RouterHarness,
) -> None:
    observed = router.path("work/root-config-policy")
    script = (
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/storage.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/native_config.sh"\n'
        f'. "{ROOT}/modules/lib/isolation.sh"\n'
        f'. "{ROOT}/modules/lib/entware_root.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        f'. "{ROOT}/modules/lib/native_config_root.sh"\n'
        "cfmgr_isolation_native_config_root_with; with_status=$?\n"
        "cfmgr_isolation_native_config_root_test; test_status=$?\n"
        '_cfmgr_native_devices_reset() { printf "%s\\t%s\\n" '
        '"$_execution_config_extended" "$_execution_layout" >>"$CFMGR_POLICY_LOG"; }\n'
        "_execution_config_extended=1\n"
        "_cfmgr_isolation_root_owner native-config fixture; config_status=$?\n"
        "_execution_config_extended=1\n"
        "_cfmgr_isolation_root_owner native-devices fixture; legacy_status=$?\n"
        'printf "API\\t%s\\t%s\\n" "$with_status" "$test_status"\n'
        'printf "OWNER\\t%s\\t%s\\n" "$config_status" "$legacy_status"\n'
    )
    result = router.run(script, env={"CFMGR_POLICY_LOG": str(observed)})

    assert result.returncode == 0, result
    assert result.stdout == "API\t2\t2\nOWNER\t2\t2\n"
    assert result.stderr == ""
    assert not router.path("ram/tmp/cfmgr-execution-guard/execution").exists()
    assert observed.read_text().splitlines() == [
        "1\tnative-devices",
        "0\tnative-devices",
    ]


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("options", "expected"),
    [
        ("ro,nosuid,noexec,relatime", 0),
        ("ro,noexec,relatime", 1),
        ("ro,nosuid,relatime", 1),
        ("rw,nosuid,noexec,relatime", 1),
        ("ro,nosuid,noexec,nodev,relatime", 1),
        ("ro,nosuid,noexec,suid,relatime", 1),
        ("ro,nosuid,noexec,exec,relatime", 1),
    ],
)
def test_device_mount_options_require_explicit_ro_nosuid_noexec_and_default_dev(
    router: RouterHarness, options: str, expected: int
) -> None:
    script = (
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/entware_root.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        '_cfmgr_native_devices_options "$1" 7277; printf "STATUS\\t%s\\n" "$?"\n'
    )
    result = router.run(script, [options.encode().hex()])
    assert result.returncode == 0, result
    assert result.stdout == f"STATUS\t{expected}\n"
    assert result.stderr == ""


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("fail_minor", "expected", "expected_nodes"),
    [("", 0, {"null", "urandom"}), ("9", 129, {"null"})],
    ids=["both-fixed-nodes-created", "second-node-failure-retains-first"],
)
def test_device_prepare_creates_only_fixed_nodes_and_fails_closed(
    router: RouterHarness, fail_minor: str, expected: int, expected_nodes: set[str]
) -> None:
    image = router.path("ram/image")
    image.mkdir(mode=0o700)
    log = router.path("work/mknod.jsonl")
    tool = router.write(
        "work/mknod-double.py",
        dedent(
            r"""
            import json, sys
            from pathlib import Path
            settings = json.loads(Path(sys.argv[1]).read_text())
            args = sys.argv[2:]
            with Path(settings["log"]).open("a") as stream:
                stream.write(json.dumps(args) + "\n")
            if args[-1] == settings["fail_minor"]:
                sys.exit(7)
            path = Path(args[2])
            path.touch(exist_ok=False)
            path.chmod(0o600)
            """
        ),
    )
    tool.chmod(0o700)
    settings = router.write(
        "work/mknod-settings.json",
        json.dumps({"log": str(log), "fail_minor": fail_minor}),
    )
    mknod = router.write(
        "work/mknod-double",
        f"#!/bin/sh\nexec {shlex.quote(shutil.which('python3') or os.sys.executable)} "
        f'{shlex.quote(str(tool))} {shlex.quote(str(settings))} "$@"\n',
        executable=True,
    )
    script = (
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/isolation.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/entware_root.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        f"_execution_image={shlex.quote(str(image))}; "
        f"_isolation_tree={shlex.quote(str(router.path('ram/root')))}\n"
        f"_isolation_mkdir=/bin/mkdir; _native_devices_mknod={shlex.quote(str(mknod))}\n"
        "_cfmgr_native_devices_source() { return 0; }\n"
        '_cfmgr_native_devices_prepare; printf "STATUS\\t%s\\n" "$?"\n'
    )
    result = router.run(script)
    assert result.returncode == 0, result
    assert result.stdout == f"STATUS\t{expected}\n"
    assert result.stderr == ""
    nodes = {path.name for path in (image / "dev").iterdir()}
    assert nodes == expected_nodes
    assert all(
        path.is_file() and path.stat().st_mode & 0o777 == 0o600
        for path in (image / "dev").iterdir()
    )
    calls = [json.loads(line) for line in log.read_text().splitlines()]
    assert calls == [
        ["-m", "600", str(image / "dev/null"), "c", "1", "3"],
        ["-m", "600", str(image / "dev/urandom"), "c", "1", "9"],
    ]


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("fault", "first_status", "second_status", "baseline"),
    [
        ("", 0, 0, True),
        ("metadata-change", 0, 1, True),
        ("metadata-cleanup-fails", 1, 1, False),
    ],
    ids=["stable-inode-positive-control", "changed-inode-refused", "failed-io-cleanup"],
)
def test_device_metadata_requires_fresh_io_and_pins_inode(
    router: RouterHarness, fault: str, first_status: int, second_status: int, baseline: bool
) -> None:
    from tests.test_native_root import NativeRootFixture

    fixture = NativeRootFixture(router, fault=fault)
    fixture.devices_enabled = True
    fixture.guard.joinpath("execution/image/dev").mkdir(parents=True, mode=0o700)
    (fixture.guard / "execution/image/dev/null").write_bytes(b"fixture node placeholder\n")
    (fixture.guard / "execution/image/dev/null").chmod(0o600)
    fixture.prepare()
    if fault == "metadata-cleanup-fails":
        fixture._tool(
            "rm",
            "#!/bin/sh\n"
            'case "$*" in *cfmgr-io.*) /bin/rm "$@"; exit 7 ;; esac\n'
            'exec /bin/rm "$@"\n',
        )
    script = (
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/storage.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/isolation.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        f"_isolation_root={shlex.quote(str(fixture.ramroot))}; "
        f"_isolation_guard={shlex.quote(str(fixture.guard / 'execution'))}; "
        f"_isolation_tools={shlex.quote(str(fixture.tools))}; "
        f"_isolation_test={shlex.quote(str(fixture.tools / 'test'))}\n"
        f"_isolation_printf={shlex.quote(str(fixture.tools / 'printf'))}; "
        f"_isolation_storage_parser={shlex.quote(str(ROOT / 'modules/lib/storageinfo.awk'))}\n"
        f"_execution_image={shlex.quote(str(fixture.guard / 'execution/image'))}; "
        f"_io_wc={shlex.quote(str(fixture.tools / 'wc'))}; "
        "_io_tab=$(printf '\\t'); _io_lf='\n'\n"
        "_cfmgr_native_devices_reset; _native_devices_name=null\n"
        "_cfmgr_native_devices_metadata; first=$?\n"
        "_cfmgr_native_devices_metadata; second=$?\n"
        'printf "STATUS\\t%s\\t%s\\t%s\\n" "$first" "$second" "$_native_devices_observations"\n'
    )
    result = router.run(script)
    assert result.returncode == 0, result
    assert result.stdout == f"STATUS\t{first_status}\t{second_status}\t2\n", (
        result.stdout,
        fixture.tool_log.read_text(),
        list((fixture.guard / "execution").iterdir()),
    )
    assert result.stderr == ""
    metadata_path = fixture.guard / "execution/metadata-null"
    assert metadata_path.exists() is baseline
    if baseline:
        assert metadata_path.read_text(encoding="ascii").startswith("charnull\t")
    assert len(list((fixture.guard / "execution").glob("device-observation-*"))) == 2
    calls = [
        json.loads(path.read_text()) for path in fixture.tool_log.parent.glob("native-ls-*.json")
    ]
    assert [call[1] for call in calls if call[1][0] == "-dni"] == [["-dni", "null"]] * 2


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
def test_device_source_check_requires_the_exact_image_filesystem_target(
    router: RouterHarness,
) -> None:
    from tests.test_native_root import NativeRootFixture

    fixture = NativeRootFixture(router)
    fixture.devices_enabled = True
    image_dev = fixture.guard / "execution/image/dev"
    image_dev.mkdir(parents=True, mode=0o700)
    (image_dev / "null").write_bytes(b"fixture node placeholder\n")
    fixture.prepare()
    ram_body = (
        f"mount\t77\t1\t0:77\t2f\t{os.fsencode(fixture.ramroot).hex()}\ttmpfs\t746d706673\t"
        "72772c72656c6174696d65\t7277\t2f"
    )
    topology = "topology\t-\t-\t-\t0\t0\t0"
    expected_root = f"{os.fsencode(fixture.guard / 'execution/image').hex()}2f6465762f6e756c6c"
    script = (
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/storage.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/isolation.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        f"_io_tab=$(printf '\\t'); _io_lf='{chr(10)}'\n"
        f"_isolation_test={shlex.quote(str(fixture.tools / 'test'))}; "
        f"_execution_image={shlex.quote(str(fixture.guard / 'execution/image'))}; "
        f"_execution_source_root={os.fsencode(fixture.guard / 'execution/image').hex()}\n"
        f"_isolation_id=77; _isolation_ram_id=77; _isolation_body={shlex.quote(ram_body)}; "
        f"_execution_ram_body={shlex.quote(ram_body)}\n"
        f"_isolation_topology={shlex.quote(topology)}\n"
        "_cfmgr_native_devices_name null\n"
        f"_isolation_fs_target={expected_root}; _cfmgr_native_devices_source_check; good=$?\n"
        "_isolation_fs_target=2f77726f6e67; _cfmgr_native_devices_source_check; bad=$?\n"
        'printf "RESULT\\t%s\\t%s\\n" "$good" "$bad"\n'
    )
    result = router.run(script)
    assert result.returncode == 0, result
    assert result.stdout == "RESULT\t0\t1\n"
    assert result.stderr == ""


def _device_remove_fixture(router: RouterHarness, busy: bool) -> tuple[str, list[str]]:
    guard = router.path("ram/guard")
    image_dev = router.path("ram/image/dev")
    root_dev = router.path("ram/root/dev")
    guard.mkdir(mode=0o700)
    image_dev.mkdir(parents=True, mode=0o700)
    root_dev.mkdir(parents=True, mode=0o700)
    source = image_dev / "urandom"
    source.write_bytes(b"host placeholder, never read as a device\n")
    source.chmod(0o600)
    target = root_dev / "urandom"
    os.link(source, target)
    source_point = os.fsencode(source).hex()
    root_point = os.fsencode(router.path("ram/root")).hex()
    target_point = os.fsencode(target).hex()
    target_fs = f"{os.fsencode(router.path('ram/image')).hex()}2f6465762f7572616e646f6d"
    tmp_mounted = "mount\t905\t900\n"
    opt_mounted = "mount\t906\t900\n"
    source_body = (
        f"mount\t77\t1\t0:77\t2f\t{source_point}\ttmpfs\t746d706673\t"
        "72772c72656c6174696d65\t7277\t" + source_point
    )
    base_body = (
        f"mount\t900\t77\t0:77\t2f\t{root_point}\ttmpfs\t746d706673\t"
        f"72772c72656c6174696d65\t7277\t{os.fsencode(router.path('ram/image')).hex()}"
    )
    mounted_body = (
        f"mount\t908\t900\t0:77\t{source_point}\t{target_point}\ttmpfs\t746d706673\t"
        f"726f2c6e6f737569642c6e6f657865632c72656c6174696d65\t7277\t{source_point}"
    )
    fallback_body = base_body.rsplit("\t", 1)[0] + "\t" + target_fs
    topology = "topology\t-\t-\t-\t0\t0\t0"

    def ledger(body: str) -> str:
        preceding = body + "\n" + topology + "\n"
        return preceding + f"end\t{len(preceding.encode())}\n"

    source_ledger = ledger(source_body)
    mounted_ledger = ledger(mounted_body)
    fallback_ledger = ledger(fallback_body)
    metadata_body = "charurandom\t123\n"
    metadata = metadata_body + f"end\t{len(metadata_body)}\n"
    files = {
        "source-urandom": source_ledger,
        "fallback-urandom": fallback_ledger,
        "mounted-urandom": mounted_ledger,
        "metadata-urandom": metadata,
        "intent-urandom": "urandom\n",
    }
    for name, content in files.items():
        (guard / name).write_text(content, encoding="ascii")

    settings = {
        "busy": busy,
        "target": str(target),
        "source": str(source),
        "log": str(router.path("work/device-remove.log")),
    }
    settings_path = router.write("work/device-remove.json", json.dumps(settings))
    tool = router.write(
        "work/device-remove-tool.py",
        dedent(
            r"""
            import json, os, sys
            from pathlib import Path
            config = json.loads(Path(sys.argv[1]).read_text())
            mode, args = sys.argv[2], sys.argv[3:]
            if mode == "test":
                if len(args) == 2 and args[0] == "-c":
                    ok = Path(args[1]).is_file()
                elif len(args) == 3 and args[0] == "!" and args[1] == "-L":
                    ok = not Path(args[2]).is_symlink()
                elif len(args) == 3 and args[1] == "-ef":
                    left, right = os.stat(args[0]), os.stat(args[2])
                    ok = (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)
                else:
                    raise AssertionError(args)
                sys.exit(0 if ok else 1)
            if mode == "umount":
                Path(config["log"]).open("a").write(json.dumps(args) + "\n")
                sys.exit(7 if config["busy"] else 0)
            raise AssertionError(mode)
            """
        ),
    )
    tool.chmod(0o700)
    test_tool = router.write(
        "work/device-test",
        f"#!/bin/sh\nexec {shlex.quote(shutil.which('python3') or sys.executable)} "
        f'{shlex.quote(str(tool))} {shlex.quote(str(settings_path))} test "$@"\n',
        executable=True,
    )
    umount_tool = router.write(
        "work/device-umount",
        f"#!/bin/sh\nexec {shlex.quote(shutil.which('python3') or sys.executable)} "
        f'{shlex.quote(str(tool))} {shlex.quote(str(settings_path))} umount "$@"\n',
        executable=True,
    )
    rm_tool = router.write("work/device-rm", '#!/bin/sh\nexec /bin/rm "$@"\n', executable=True)
    printf_tool = router.write(
        "work/device-printf", '#!/bin/sh\nexec /usr/bin/printf "$@"\n', executable=True
    )
    wc = shutil.which("wc")
    assert wc
    script = (
        f'. "{ROOT}/modules/lib/io.sh"\n'
        f'. "{ROOT}/modules/lib/storage.sh"\n'
        f'. "{ROOT}/modules/lib/entware.sh"\n'
        f'. "{ROOT}/modules/lib/isolation.sh"\n'
        f'. "{ROOT}/modules/lib/native_devices.sh"\n'
        f"_io_tab=$(printf '\\t')\n_io_lf='{chr(10)}'\n_io_wc=$1\n"
        f"_isolation_guard={shlex.quote(str(guard))}; "
        f"_isolation_root={shlex.quote(str(router.path('ram')))}\n"
        "_isolation_mode=root; _isolation_interrupted=0\n"
        f"_isolation_tree={shlex.quote(str(router.path('ram/root')))}\n"
        f"_execution_image={shlex.quote(str(router.path('ram/image')))}\n"
        f"_execution_base_body={shlex.quote(base_body)}\n"
        f"_execution_source_root={os.fsencode(router.path('ram/image')).hex()}\n"
        "_execution_mount_id=900; _isolation_ram_id=77; _execution_native_ids='901 902 903 904'\n"
        f"_execution_tmp_mounted_ledger={shlex.quote(tmp_mounted)}; "
        f"_entware_root_mounted_ledger={shlex.quote(opt_mounted)}\n"
        f"_isolation_test={shlex.quote(str(test_tool))}; "
        f"_isolation_umount={shlex.quote(str(umount_tool))}\n"
        f"_isolation_rm={shlex.quote(str(rm_tool))}; "
        f"_isolation_printf={shlex.quote(str(printf_tool))}\n"
        f"_io_wc={shlex.quote(wc)}; _isolation_umount_profile=modern\n"
        f"_native_devices_urandom_source={shlex.quote(source_ledger)}\n"
        f"_native_devices_urandom_fallback={shlex.quote(fallback_ledger)}\n"
        f"_native_devices_urandom_mounted={shlex.quote(mounted_ledger)}\n"
        f"_native_devices_urandom_metadata={shlex.quote(metadata)}\n"
        "_native_devices_count=2; _native_devices_observations=12\n"
        f"_isolation_topology={shlex.quote(topology)}\n"
        "_isolation_options=726f2c6e6f737569642c6e6f657865632c72656c6174696d65\n"
        "_isolation_super=7277\n"
        f"_cfmgr_isolation_query() {{\n"
        "  _remove_queries=$((_remove_queries + 1))\n"
        "  _isolation_id=908; _isolation_parent=900; _isolation_device=0:77\n"
        "  _isolation_fs=tmpfs\n"
        f"  _isolation_mount_root={shlex.quote(source_point)}\n"
        f"  _isolation_fs_target={shlex.quote(source_point)}\n"
        f"  _isolation_point={shlex.quote(target_point)}\n"
        "  _isolation_options=726f2c6e6f737569642c6e6f657865632c72656c6174696d65\n"
        "  _isolation_super=7277\n"
        f'  if [ "$_remove_queries" -eq 1 ]; then\n'
        f"    _isolation_body={shlex.quote(mounted_body)}\n"
        f"    _isolation_ledger={shlex.quote(mounted_ledger)}\n"
        "  else\n"
        f"    _isolation_body={shlex.quote(fallback_body)}\n"
        f"    _isolation_ledger={shlex.quote(fallback_ledger)}\n"
        "    _isolation_options=72772c72656c6174696d65\n"
        "  fi\n"
        "  return 0\n"
        "}\n"
        "_cfmgr_native_devices_metadata() { _metadata_calls=$((_metadata_calls + 1)); return 0; }\n"
        "_remove_queries=0; _metadata_calls=0\n"
        "_cfmgr_native_devices_remove urandom; status=$?\n"
        'printf "RESULT\\t%s\\nQUERIES\\t%s\\nMETADATA\\t%s\\nCOUNT\\t%s\\n" '
        '"$status" "$_remove_queries" "$_metadata_calls" "$_native_devices_count"\n'
        'if [ -e "$_isolation_guard/active" ]; then\n'
        '  IFS= read -r active < "$_isolation_guard/active"\n'
        '  printf "ACTIVE\\tyes\\t%s\\n" "$active"\n'
        "else\n"
        '  printf "ACTIVE\\tno\\t-\\n"\n'
        "fi\n"
    )
    return script, [str(wc), str(guard), str(source), str(target)]


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("busy", "expected_status", "queries", "metadata", "count"),
    [(True, 129, 1, 0, 2), (False, 0, 2, 1, 1)],
    ids=["busy-umount", "successful-fallback"],
)
def test_device_remove_requires_observed_unmount_and_fallback(
    router: RouterHarness,
    busy: bool,
    expected_status: int,
    queries: int,
    metadata: int,
    count: int,
) -> None:
    script, args = _device_remove_fixture(router, busy)
    result = router.run(script, args)
    assert result.returncode == 0, result
    assert result.stdout == (
        f"RESULT\t{expected_status}\nQUERIES\t{queries}\nMETADATA\t{metadata}\n"
        f"COUNT\t{count}\n" + ("ACTIVE\tyes\tumount-urandom\n" if busy else "ACTIVE\tno\t-\n")
    )
    assert result.stderr == ""
    umount_log = router.path("work/device-remove.log")
    assert umount_log.read_text().splitlines() == [
        json.dumps(["-n", str(router.path("ram/root/dev/urandom"))])
    ]


@pytest.mark.integration
@pytest.mark.matrix("V74", evidence="host")
def test_native_devices_compose_with_entware_and_retain_each_inode_observation(
    router: RouterHarness,
) -> None:
    fixture, storage, result = run_native_opt(
        router, callback_status=7, devices_root=True, native_config_root=True
    )

    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == "RESULT\t7\nFDIDENT\t1\t1\nFDSTATE\toriginal-seven\toriginal-six\n"
    observation = json.loads(router.read("work/entware-callback.json"))
    assert observation["volume_ledger"] == storage.expected()
    assert observation["args"] == [
        "arg with spaces",
        "*",
        "status-7",
        b"127.0.0.1\tlocalhost\\native-data\n".hex(),
        "",
    ]
    assert observation["root_ledger"].splitlines()[1].split("\t")[6] == "8"
    assert_native_config_bytes(fixture)
    assert set(observation["device_nodes"]) == {"null", "urandom"}
    for name in ("null", "urandom"):
        assert observation["device_nodes"][name][1] == observation["device_nodes"][name][2]
        mounted = (fixture.guard / f"execution/mounted-{name}").read_text().splitlines()
        fields = mounted[0].split("\t")
        assert fields[:4] == ["mount", "907" if name == "null" else "908", "900", "0:77"]
        assert fields[6:10] == [
            "tmpfs",
            "746d706673",
            "726f2c6e6f737569642c6e6f657865632c72656c6174696d65",
            "7277",
        ]
        assert (
            fields[10]
            == (
                b"/"
                + os.fsencode(
                    (fixture.guard / "execution/image/dev" / name).relative_to(fixture.ramroot)
                )
            ).hex()
        )
        fallback = (fixture.guard / f"execution/fallback-{name}").read_text().splitlines()[0]
        fallback_fields = fallback.split("\t")
        assert fallback_fields[1:4] == ["900", "77", "0:77"]
        assert fallback_fields[6:10] == [
            "tmpfs",
            "746d706673",
            "726f2c6e6f737569642c6e6f6465762c72656c6174696d65",
            "7277",
        ]
        expected_source = (fixture.guard / "execution/image/dev" / name).relative_to(
            fixture.ramroot
        )
        assert fields[4] == (b"/" + os.fsencode(expected_source)).hex()
        assert fallback_fields[10] == (b"/" + os.fsencode(expected_source)).hex()
    assert (fixture.guard / "execution/complete").is_dir()

    queries = sorted(
        (fixture.guard / "execution").glob("query-*"),
        key=lambda path: int(path.name[6:]),
    )
    assert [path.name for path in queries] == [f"query-{index}" for index in range(106)]
    metadata = [
        json.loads(path.read_text())
        for path in fixture.tool_log.parent.glob("native-ls-*.json")
        if json.loads(path.read_text())[1][:1] == ["-dni"]
    ]
    assert sorted(tuple(record[1]) for record in metadata) == sorted(
        [("-dni", name) for name in ("null", "urandom") for _ in range(6)]
    )
    state = json.loads(fixture.state_path.read_text())
    assert [row["identifier"] for row in state["mounts"]] == [
        "1",
        "77",
        "88",
        "42",
    ]
    calls = [json.loads(line) for line in fixture.tool_log.read_text().splitlines()]
    mknods = [(args[2], args[4:]) for tool, args in calls if tool == "mknod"]
    assert mknods == [
        (str(fixture.guard / "execution/image/dev/null"), ["1", "3"]),
        (str(fixture.guard / "execution/image/dev/urandom"), ["1", "9"]),
    ]
    unmounts = [
        Path(args[-1]).name for tool, args in calls if tool == "umount" and args != ["--help"]
    ]
    assert unmounts == ["opt", "urandom", "null", "tmp", "usr", "lib", "sbin", "bin", "root"]
