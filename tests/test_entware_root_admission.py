"""Cheap admission and identity checks for the Entware Opt root."""

from __future__ import annotations

import os
import shlex
import sys
from pathlib import Path

import pytest

from tests.harness import RouterHarness

ROOT = Path(__file__).resolve().parents[1]
IO = ROOT / "modules/lib/io.sh"
STORAGE = ROOT / "modules/lib/storage.sh"
ENTWARE = ROOT / "modules/lib/entware.sh"
NATIVE_CONFIG = ROOT / "modules/lib/native_config.sh"
ISOLATION = ROOT / "modules/lib/isolation.sh"
ENTWARE_ROOT = ROOT / "modules/lib/entware_root.sh"
MOUNT_PARSER = ROOT / "modules/lib/mountinfo.awk"
STORAGE_PARSER = ROOT / "modules/lib/storageinfo.awk"
UUID = "00112233-4455-6677-8899-aabbccddeeff"


def _sources() -> str:
    return "\n".join(
        f". {shlex.quote(str(path))}"
        for path in (IO, STORAGE, ENTWARE, NATIVE_CONFIG, ISOLATION, ENTWARE_ROOT)
    )


def _volume(*, filesystem: str = "ext4", uuid: str = UUID) -> str:
    fields = [
        "volume",
        "42",
        "8:1",
        filesystem,
        "2f",
        "2f6d6e74",
        "2f6d6e742f656e7477617265",
        "726f",
        "726f",
        uuid,
    ]
    body = "\t".join(fields)
    return f"{body}\nend\t{len(body) + 1}\n"


def _frame(body: str, topology: str = "topology\t-\t-\t-\t0\t0\t0") -> str:
    return f"{body}\n{topology}\nend\t{len(body) + len(topology) + 2}\n"


def _host_fd_test_tool(router: RouterHarness) -> Path:
    program = (
        "import os, stat, sys\n"
        "args = sys.argv[1:]\n"
        "if args[:1] == ['-d']:\n"
        "    path = args[1]\n"
        "    ok = stat.S_ISDIR(os.fstat(9).st_mode) "
        "if path == '/proc/self/fd/9' else os.path.isdir(path)\n"
        "elif args[:2] == ['!', '-L']:\n"
        "    ok = not os.path.islink(args[2])\n"
        "elif len(args) == 3 and args[1:] == ['-ef', '/proc/self/fd/9']:\n"
        "    left, right = os.stat(args[0]), os.fstat(9)\n"
        "    ok = (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)\n"
        "else:\n"
        "    raise SystemExit(2)\n"
        "raise SystemExit(0 if ok else 1)\n"
    )
    script = f"#!/bin/sh\nexec {shlex.quote(sys.executable)} - \"$@\" <<'PY'\n{program}PY\n"
    return router.write("bin/test", script, executable=True)


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("kind", "volume", "expected"),
    [
        ("production", _volume(), 0),
        ("fixture", _volume(), 0),
        ("fixture", _volume(filesystem="tmpfs"), 0),
        ("production", _volume(filesystem="tmpfs"), 1),
        ("fixture", _volume(uuid=UUID.upper()), 1),
        ("fixture", _volume() + "extra\n", 1),
    ],
    ids=[
        "production-ext",
        "fixture-ext",
        "fixture-tmpfs",
        "production-no-tmpfs",
        "uuid-case",
        "extra-record",
    ],
)
def test_entware_volume_framing_is_canonical_and_kind_scoped(
    router: RouterHarness, kind: str, volume: str, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        "_io_tab='\t'; _io_lf='\n'; _entware_root_kind=$1\n"
        'if _cfmgr_entware_root_volume "$2"; then status=0; else status=1; fi\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [kind, volume], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    "case",
    ["short-api", "bad-volume", "valid-volume"],
    ids=["short-api", "bad-volume", "valid-volume-dispatch"],
)
def test_entware_root_rejects_bad_api_or_volume_before_reservation(
    router: RouterHarness, case: str
) -> None:
    resolved = router.path("work/source")
    resolved.mkdir()
    ramroot = router.path("ram/root")
    ramroot.mkdir()
    guard = ramroot / "guard"
    marker = router.path("ram/dispatched")
    script = (
        f"{_sources()}\n"
        f"_cfmgr_isolation_root_owner() {{ : > {shlex.quote(str(marker))}; return 0; }}\n"
        'cfmgr_isolation_entware_root_test "$@"; status=$?\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    args = [
        str(resolved),
        "not-a-volume-ledger" if case != "valid-volume" else _volume(),
        str(ramroot),
        str(guard),
        str(router.path("bin")),
        str(router.path("work/mountinfo")),
        str(router.path("work/root-fdinfo")),
        str(router.path("work/opt-fdinfo")),
        str(router.path("work/native-source")),
        str(router.path("work/data-source")),
        "64",
        "8",
        str(MOUNT_PARSER),
        str(STORAGE_PARSER),
        "callback",
    ]
    if case == "short-api":
        args.pop()
    result = router.run(script, args, timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    expected = 0 if case == "valid-volume" else 2
    assert result.stdout == f"RESULT\t{expected}\n"
    assert marker.exists() is (case == "valid-volume")
    assert not guard.exists()


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mount", "superblock", "expected"),
    [
        ("rw,nosuid,nodev,exec", "rw", 0),
        ("rw,nodev,exec", "rw,nosuid", 1),
        ("rw,nosuid,exec", "rw,nodev", 1),
        ("ro,nosuid,nodev,exec", "rw", 1),
        ("rw,nosuid,nodev,noexec", "rw", 1),
        ("rw,suid,nodev,exec", "rw", 1),
        ("rw,nosuid,dev,exec", "rw", 1),
    ],
    ids=[
        "safe-mount",
        "missing-mount-nosuid",
        "missing-mount-nodev",
        "read-only",
        "noexec",
        "suid",
        "dev",
    ],
)
def test_entware_opt_options_require_rw_exec_and_safe_flags(
    router: RouterHarness, mount: str, superblock: str, expected: int
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        'if _cfmgr_entware_root_options "$1" "$2"; then status=0; else status=1; fi\n'
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [mount.encode().hex(), superblock.encode().hex()], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mutation", "expected"),
    [("valid", 0), ("facts", 1), ("topology", 1), ("symlink", 1)],
    ids=["positive-control", "volume-facts-changed", "descendant-topology", "source-symlink"],
)
def test_entware_source_check_requires_saved_facts_private_mount_and_real_directory(
    router: RouterHarness, mutation: str, expected: int
) -> None:
    source = router.path("work/source-check")
    source.mkdir()
    target = source
    if mutation == "symlink":
        target = router.path("work/source-alias")
        target.symlink_to(source, target_is_directory=True)
    test_tool = _host_fd_test_tool(router)
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        "_io_tab='\t'; _entware_root_kind=fixture\n"
        "_entware_root_facts='42\t8:1\text4\t2f\t2f\t2f\t7277\t7277'\n"
        "_isolation_facts=$_entware_root_facts\n"
        "_isolation_topology='topology\t-\t-\t-\t0\t0\t0'\n"
        "_isolation_options=7277; _isolation_super=7277\n"
        f"_isolation_test={shlex.quote(str(test_tool))}; "
        f"_entware_root_resolved={shlex.quote(str(target))}\n"
        'case "$1" in facts) _isolation_facts="42${_io_tab}8:2'
        '${_io_tab}ext4${_io_tab}2f${_io_tab}2f${_io_tab}2f${_io_tab}7277${_io_tab}7277" ;;\n'
        '  topology) _isolation_topology="topology${_io_tab}-${_io_tab}-${_io_tab}-'
        '${_io_tab}0${_io_tab}0${_io_tab}1" ;; esac\n'
        "if _cfmgr_entware_root_source_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [mutation], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("mutation", "expected"),
    [
        ("valid", 0),
        ("parent", 1),
        ("point", 1),
        ("source", 1),
        ("root", 1),
        ("device", 1),
        ("id-root", 1),
        ("id-tmp", 1),
        ("id-native", 1),
    ],
    ids=[
        "positive-control",
        "parent",
        "point",
        "source",
        "mount-root",
        "device",
        "root-id",
        "tmp-id",
        "native-id",
    ],
)
def test_entware_opt_view_requires_exact_child_identity(
    router: RouterHarness, mutation: str, expected: int
) -> None:
    opt = router.path("work/execution/root/opt")
    opt.mkdir(parents=True)
    source = router.path("work/source")
    source.mkdir()
    tree_hex = os.fsencode(opt.parent).hex()
    source_path_hex = os.fsencode(source).hex()
    source_target = "2f"
    source_ledger_body = (
        f"mount\t88\t1\t0:88\t2f\t{source_path_hex}\text4\t{source_path_hex}"
        f"\t7277\t7277\t{source_target}"
    )
    source_ledger = _frame(source_ledger_body)
    changed_source_body = (
        f"mount\t906\t900\t0:88\t2f\t{tree_hex}2f6f7074\text4\t"
        f"{b'/dev/other'.hex()}\t72772c6e6f737569642c6e6f6465762c65786563\t7277\t2f"
    )
    test_tool = _host_fd_test_tool(router)
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(NATIVE_CONFIG))}\n. {shlex.quote(str(ISOLATION))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        "_io_tab='\t'; _io_lf='\n'; _isolation_test=$1\n"
        f"_isolation_tree={shlex.quote(str(opt.parent))}; _execution_mount_id=900; "
        "_isolation_ram_id=77\n"
        f"_execution_base_body='mount\t900\t77\t0:77\t2f\t{tree_hex}\ttmpfs\t746d706673\t7277\t7277\t2f'\n"
        "_execution_native_ids='901 902 903 904'\n"
        f"_isolation_body='mount\t906\t900\t0:88\t2f\t{tree_hex}2f6f7074\text4\t{source_path_hex}\t72772c6e6f737569642c6e6f6465762c65786563\t7277\t2f'\n"
        "_isolation_topology='topology\t-\t-\t-\t0\t0\t0'\n"
        f"_entware_root_source_ledger={shlex.quote(source_ledger)}\n"
        f"_execution_tmp_mounted_ledger='mount\t905\t900\t0:99\t2f\t{tree_hex}2f746d70\ttmpfs\t63666d67722d746d70\t7277\t7277\t2f'\n"
        "_isolation_parent=900; _isolation_id=906; _isolation_device=0:88\n"
        f"_isolation_mount_root=2f; _isolation_point={tree_hex}2f6f7074\n"
        "_isolation_fs=ext4; _isolation_fs_target=2f; "
        "_isolation_options=72772c6e6f737569642c6e6f6465762c65786563; "
        "_isolation_super=7277\n"
        "case $2 in\n"
        "  parent) _isolation_parent=899 ;; point) _isolation_point=2f6f7074 ;;\n"
        f"  source) _isolation_body={shlex.quote(changed_source_body)} ;;\n"
        "  root) _isolation_mount_root=2f6f74686572 ;; device) _isolation_device=0:89 ;;\n"
        "  id-root) _isolation_id=900 ;; id-tmp) _isolation_id=905 ;;\n"
        "  id-native) _isolation_id=903 ;;\n"
        "esac\n"
        "if _cfmgr_entware_root_view_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [str(test_tool), mutation], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("layout", "queries", "expected", "after"),
    [
        ("native-opt", "78", 1, "78"),
        ("native-opt", "77", 1, "78"),
    ],
    ids=["opt-ceiling-78", "opt-ceiling-77"],
)
def test_entware_opt_query_ceiling_is_literal(
    router: RouterHarness, layout: str, queries: str, expected: int, after: str
) -> None:
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(ISOLATION))}\n"
        f"_isolation_mode=root; _execution_layout=$1; _isolation_queries=$2\n"
        "CFMGR_QUERY_LIMIT=999999; export CFMGR_QUERY_LIMIT\n"
        "if _cfmgr_isolation_query /unconsulted 0; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\t%s\\n" "$status" "$_isolation_queries"\n'
    )
    result = router.run(script, [layout, queries], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\t{after}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    ("target", "fdinfo_id", "block_device", "expected"),
    [
        ("same", "42", "8:1", 0),
        ("other", "42", "8:1", 1),
        ("same", "42", "8:2", 1),
        ("same", "43", "8:1", 1),
        ("regular-fd9", "42", "8:1", 1),
    ],
    ids=[
        "fd9-directory-source",
        "fd9-source-mismatch",
        "fd8-device-mismatch",
        "fd9-mount-id-mismatch",
        "fd9-regular-file",
    ],
)
def test_entware_fd_admission_checks_source_and_storage_metadata(
    router: RouterHarness, target: str, fdinfo_id: str, block_device: str, expected: int
) -> None:
    source = router.path("work/volume")
    source.mkdir()
    other = router.path("work/other-volume")
    other.mkdir()
    block = router.write("work/block", "fixture block descriptor\n")
    fdinfo = router.write("work/fdinfo", "pos:\t0\nflags:\t0100000\nmnt_id:\t42\n")
    chosen = source if target in {"same", "regular-fd9"} else other
    fd9_target = block if target == "regular-fd9" else source
    test_tool = _host_fd_test_tool(router)
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(ENTWARE))}\n. {shlex.quote(str(ENTWARE_ROOT))}\n"
        "cfmgr_io_capture() {\n"
        '  case $4 in cat) _storage_capture_output="pos:\\t0\\n'
        'flags:\\t0100000\\nmnt_id:\\t42\\n" ;;\n'
        '    ls) _storage_capture_output="b 8, 1 0 0 /dev/fake" ;; esac\n'
        "}\n"
        "_cfmgr_storage_ok() { return 0; }\n"
        "_cfmgr_storage_line() { _storage_line=$_storage_capture_output; }\n"
        "_cfmgr_storage_parse() {\n"
        f"  case $3 in fdinfo) _storage_value={fdinfo_id} ;; "
        f"blockdev) _storage_value={block_device} ;; esac\n"
        "}\n"
        "_io_tab='\t'; _isolation_storage_parser=unused\n"
        f"_entware_root_fdinfo={shlex.quote(str(fdinfo))}; "
        f"_entware_root_resolved={shlex.quote(str(chosen))}\n"
        f"_entware_root_facts='42\t8:1\text4\t2f\t2f\t2f\t726f\t726f'\n"
        f"_isolation_test={shlex.quote(str(test_tool))}; "
        f"_storage_test_command={shlex.quote(str(test_tool))}\n"
        f"_storage_fdinfo={shlex.quote(str(fdinfo))}; "
        f"_storage_target={shlex.quote(str(chosen))}\n"
        f"_storage_mount_id=42; _storage_device=8:1; exec "
        f"8<{shlex.quote(str(block))} 9<{shlex.quote(str(fd9_target))}\n"
        "if _cfmgr_entware_root_fd_action; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(script, [str(source)], timeout=3)
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{expected}\n"


@pytest.mark.unit
@pytest.mark.matrix("V74", evidence="host")
@pytest.mark.parametrize(
    "changed_opt", [False, True], ids=["six-child-positive-control", "changed-opt-ledger"]
)
def test_native_opt_layout_checks_opt_ledger_even_when_root_count_is_six(
    router: RouterHarness, changed_opt: bool
) -> None:
    guard = router.path("work/layout-guard/execution")
    guard.mkdir(parents=True)
    root = router.path("work/layout-root")
    (root / "tmp/cfmgr-home").mkdir(parents=True)
    source = router.path("work/layout-volume")
    source.mkdir()
    root_path_hex = os.fsencode(root).hex()
    source_path_hex = os.fsencode(source).hex()
    root_body = f"mount\t900\t77\t0:77\t2f\t{root_path_hex}\ttmpfs\t746d706673\t7277\t7277\t2f"
    root_topology = "topology\t-\t-\t-\t0\t0\t6"
    root_ledger = _frame(root_body, root_topology)
    source_ledger = _frame(
        f"mount\t42\t1\t8:1\t2f\t{source_path_hex}\text4\t2f6465762f73646131\t7277\t7277\t2f"
    )
    source_topology = "topology\t-\t-\t-\t0\t0\t0"
    ledgers = {}
    for index, name in enumerate(("bin", "sbin", "lib", "usr", "tmp", "opt")):
        body = (
            f"mount\t{901 + index}\t900\t0:88\t2f\t"
            f"{root_path_hex}2f{name.encode().hex()}\text4\t2f6465762f73646131"
            "\t72772c6e6f737569642c6e6f646576\t7277\t2f"
        )
        ledgers[name] = _frame(body)
    fallback_body = (
        f"mount\t900\t77\t0:77\t2f\t{root_path_hex}2f696d6167652f6f7074"
        "\ttmpfs\t746d706673\t7277\t7277\t2f"
    )
    fallback_ledger = _frame(fallback_body)
    saved_opt = ledgers["opt"]
    changed = saved_opt.replace("0:88", "0:89", 1)
    for name in ("source-opt", "fallback-opt", "mounted-opt"):
        (guard / name).write_text(
            {
                "source-opt": source_ledger,
                "fallback-opt": fallback_ledger,
                "mounted-opt": saved_opt,
            }[name],
            encoding="ascii",
        )
    (guard / "intent-opt").write_text("opt\n", encoding="ascii")
    actual_opt = changed if changed_opt else saved_opt
    query_log = router.path("work/layout-queries")
    query_log.write_text("", encoding="ascii")
    test_tool = _host_fd_test_tool(router)
    script = (
        f". {shlex.quote(str(IO))}\n. {shlex.quote(str(STORAGE))}\n"
        f". {shlex.quote(str(ENTWARE))}\n"
        f". {shlex.quote(str(NATIVE_CONFIG))}\n. {shlex.quote(str(ISOLATION))}\n"
        f". {shlex.quote(str(ENTWARE_ROOT))}\n"
        "_io_tab='\t'; _io_lf='\n'; _execution_layout=native-opt; _execution_native_count=4\n"
        "_io_wc=/usr/bin/wc\n"
        f"_isolation_tree={shlex.quote(str(root))}; _isolation_guard={shlex.quote(str(guard))}\n"
        f"_entware_root_resolved={shlex.quote(str(source))}; "
        f"_isolation_test={shlex.quote(str(test_tool))}\n"
        f"_execution_base_body={shlex.quote(root_body)}; "
        f"_execution_root_ledger={shlex.quote(root_ledger)}\n"
        "_execution_tmp_ready=1; _execution_tmp_home=$_isolation_tree/tmp/cfmgr-home\n"
        "_execution_native_ids='901 902 903 904'; _execution_mount_id=900\n"
        "_isolation_ram_id=77; _execution_device=0:77\n"
        "_layout_opt_saved=$1; _layout_bin=$2; _layout_sbin=$3\n"
        "_layout_lib=$4; _layout_usr=$5; _layout_tmp=$6\n"
        "_layout_opt_actual=$7\n"
        "_execution_tmp_mounted_ledger=$_layout_tmp\n"
        f"_entware_root_ready=1; _entware_root_facts='42\t8:1\text4\t2f\t"
        f"{source_path_hex}\t2f\t7277\t7277'; "
        f"_entware_root_source_ledger={shlex.quote(source_ledger)}; "
        f"_entware_root_fallback_ledger={shlex.quote(fallback_ledger)}; "
        "_entware_root_mounted_ledger=$_layout_opt_saved\n"
        "_cfmgr_entware_root_fd_check() { return 0; }\n"
        "_cfmgr_isolation_native_name() {\n"
        "  _execution_view=$1; _execution_view_path=$_isolation_tree/$1\n"
        "}\n"
        "_cfmgr_isolation_native_load() {\n"
        "  case $_execution_view in\n"
        "    bin) _execution_view_mounted_ledger=$_layout_bin ;;\n"
        "    sbin) _execution_view_mounted_ledger=$_layout_sbin ;;\n"
        "    lib) _execution_view_mounted_ledger=$_layout_lib ;;\n"
        "    usr) _execution_view_mounted_ledger=$_layout_usr ;;\n"
        "  esac\n"
        "}\n"
        "_cfmgr_isolation_native_view_check() { return 0; }\n"
        "_cfmgr_isolation_native_view_options() { return 0; }\n"
        "_cfmgr_isolation_tmp_saved() { return 0; }\n"
        "_cfmgr_isolation_tmp_check() { return 0; }\n"
        "_cfmgr_entware_root_view_check() { return 0; }\n"
        "_cfmgr_entware_root_options() { return 0; }\n"
        "_cfmgr_isolation_query() {\n"
        f'  printf "%s\\n" "$1" >>{shlex.quote(str(query_log))}\n'
        "  case $1 in\n"
        f'    "$_isolation_tree")\n'
        f"      _isolation_body={shlex.quote(root_body)}\n"
        f"      _isolation_topology={shlex.quote(root_topology)}\n"
        f"      _isolation_ledger={shlex.quote(root_ledger)} ;;\n"
        f'    "$_entware_root_resolved")\n'
        f"      _isolation_body={shlex.quote(source_ledger.splitlines()[0])}\n"
        f"      _isolation_topology={shlex.quote(source_topology)}\n"
        f"      _isolation_ledger={shlex.quote(source_ledger)}\n"
        "      _isolation_facts=$_entware_root_facts\n"
        "      _isolation_options=7277; _isolation_super=7277 ;;\n"
        '    "$_isolation_tree/opt") _isolation_ledger=$_layout_opt_actual ;;\n'
        "    *)\n"
        "      _execution_view=${1##*/}\n"
        "      case $_execution_view in\n"
        "        bin) _isolation_ledger=$_layout_bin ;;\n"
        "        sbin) _isolation_ledger=$_layout_sbin ;;\n"
        "        lib) _isolation_ledger=$_layout_lib ;;\n"
        "        usr) _isolation_ledger=$_layout_usr ;;\n"
        "        tmp) _isolation_ledger=$_layout_tmp ;;\n"
        "      esac ;;\n"
        "  esac\n"
        '  _isolation_body=${_isolation_ledger%%"$_io_lf"*}; return 0\n'
        "}\n"
        "if _cfmgr_isolation_native_layout_check; then status=0; else status=1; fi\n"
        'printf "RESULT\\t%s\\n" "$status"\n'
    )
    result = router.run(
        script,
        [saved_opt, *[ledgers[name] for name in ("bin", "sbin", "lib", "usr", "tmp")], actual_opt],
        timeout=3,
    )
    assert result.returncode == 0, result
    assert result.stderr == ""
    assert result.stdout == f"RESULT\t{1 if changed_opt else 0}\n"
    queries = query_log.read_text(encoding="ascii").splitlines()
    assert str(root) in queries
    assert str(source) in queries
    assert {str(root / name) for name in ("bin", "sbin", "lib", "usr", "tmp", "opt")} <= set(
        queries
    )
