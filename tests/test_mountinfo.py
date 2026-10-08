"""Host mountinfo selection evidence, separate from live storage approval."""

from __future__ import annotations

import random
import shutil
from collections import Counter
from dataclasses import dataclass, replace
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

SOURCE = Path(__file__).resolve().parents[1] / "modules/mountinfo.awk"
HOST_AWKS = sorted(
    {
        str(Path(path).resolve())
        for path in ("/usr/bin/awk", "/usr/local/bin/awk", shutil.which("awk"))
        if path and Path(path).is_file()
    }
)
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V74", evidence="host")]


@dataclass(frozen=True)
class Mount:
    identifier: str
    parent: str = "0"
    device: str = "0:1"
    root: bytes = b"/"
    point: bytes = b"/"
    options: bytes = b"rw,relatime"
    kind: str = "ext4"
    source: bytes = b"/dev/synthetic"
    super_options: bytes = b"rw"
    optional: tuple[str, ...] = ()


def escaped(value: bytes) -> bytes:
    mapping = {32: b"\\040", 9: b"\\011", 10: b"\\012", 92: b"\\134"}
    return b"".join(mapping.get(byte, bytes([byte])) for byte in value)


def snapshot(mounts: list[Mount]) -> bytes:
    records = []
    for mount in mounts:
        fields = [
            mount.identifier.encode(),
            mount.parent.encode(),
            mount.device.encode(),
            escaped(mount.root),
            escaped(mount.point),
            mount.options,
            *[item.encode() for item in mount.optional],
            b"-",
            mount.kind.encode(),
            escaped(mount.source),
            mount.super_options,
        ]
        records.append(b" ".join(fields) + b"\n")
    return b"".join(records)


def components(path: bytes) -> tuple[bytes, ...]:
    return tuple(path.split(b"/")[1:]) if path != b"/" else ()


def oracle(mounts: list[Mount], target: str) -> str:
    target_parts = components(target.encode())
    covering = [
        mount
        for mount in mounts
        if target_parts[: len(components(mount.point))] == components(mount.point)
    ]
    if not covering:
        raise LookupError("no covering mount")
    if any(count > 1 for count in Counter(mount.point for mount in covering).values()):
        raise ValueError("ambiguous ancestor")
    selected = max(covering, key=lambda mount: len(components(mount.point)))
    relative = target_parts[len(components(selected.point)) :]
    filesystem_target = b"/" + b"/".join(components(selected.root) + relative)
    body = (
        "\t".join(
            [
                "mount",
                selected.identifier,
                selected.parent,
                selected.device,
                selected.root.hex(),
                selected.point.hex(),
                selected.kind,
                selected.source.hex(),
                selected.options.hex(),
                selected.super_options.hex(),
                filesystem_target.hex(),
            ]
        )
        + "\n"
    )
    return body + f"end\t{len(body.encode('ascii'))}\n"


@pytest.fixture(params=HOST_AWKS, ids=lambda path: path)
def native_awk(router: RouterHarness, request: pytest.FixtureRequest) -> RouterHarness:
    router.path("bin/awk").symlink_to(request.param)
    router.write("work/mountinfo.awk", SOURCE.read_text())
    return router


def invoke(
    router: RouterHarness,
    data: bytes,
    target: str | None = "/tmp/opt/bin/jq",
    *,
    size: str | None = None,
    locale: str = "C",
    operands: tuple[str, ...] = (),
) -> ShellResult:
    assert len(data) <= router.FILE_LIMIT
    path = router.path("ram/mountinfo")
    path.write_bytes(data)
    path.chmod(0o600)
    args = []
    if size != "MISSING":
        args.extend(["-v", "cfmgr_mountinfo_size=" + (str(len(data)) if size is None else size)])
    args.extend(["-f", str(router.path("work/mountinfo.awk")), *operands])
    environment = {"LC_ALL": locale}
    if target is not None:
        environment["CFMGR_MOUNT_TARGET"] = target
    return router.run('awk "$@" < "$RAM_ROOT/mountinfo"\n', args, env=environment)


def rejected(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status
    assert result.stdout == result.stderr == ""


def selected(router: RouterHarness, mounts: list[Mount], target: str) -> ShellResult:
    result = invoke(router, snapshot(mounts), target)
    assert result.returncode == 0, result
    assert result.stdout == oracle(mounts, target)
    assert result.stderr == ""
    lines = result.stdout.splitlines()
    assert len(lines) == 2 and lines[1].startswith("end\t")
    assert int(lines[1].split("\t")[1]) == len((lines[0] + "\n").encode("ascii"))
    return result


BASE = [
    Mount("1", kind="rootfs", source=b"rootfs"),
    Mount("2", parent="1", point=b"/tmp", kind="tmpfs", source=b"tmpfs"),
    Mount("3", parent="1", device="8:1", point=b"/mnt/usb", optional=("shared:12",)),
    Mount("4", parent="2", device="8:1", root=b"/entware", point=b"/tmp/opt"),
]


@pytest.mark.parametrize(
    "target",
    ["/", "/bin/sh", "/mnt/usb", "/mnt/usb/a", "/tmp/opt", "/tmp/opt/bin/jq", "/tmp/optical/x"],
)
def test_root_usb_bind_and_component_boundaries(native_awk: RouterHarness, target: str) -> None:
    selected(native_awk, BASE, target)


def test_bind_root_changes_filesystem_target(native_awk: RouterHarness) -> None:
    result = selected(native_awk, BASE, "/tmp/opt/bin/jq")
    assert result.stdout.split("\t")[10].split("\n")[0] == b"/entware/bin/jq".hex()


@pytest.mark.parametrize("point", [b"/", b"/tmp", b"/tmp/opt"])
@pytest.mark.parametrize("reverse", [False, True])
def test_any_duplicate_covering_ancestor_is_ambiguous(
    native_awk: RouterHarness,
    point: bytes,
    reverse: bool,
) -> None:
    mounts = [*BASE, Mount("99", point=point)]
    rejected(invoke(native_awk, snapshot(mounts[::-1] if reverse else mounts)))


def test_unrelated_overmounts_do_not_make_selection_ambiguous(native_awk: RouterHarness) -> None:
    mounts = [*BASE, Mount("90", point=b"/other"), Mount("91", point=b"/other")]
    selected(native_awk, mounts, "/tmp/opt/bin/jq")


@pytest.mark.parametrize("target", ["/missing", "/usb2/file", "/us"])
def test_no_covering_mount_is_distinct_status(native_awk: RouterHarness, target: str) -> None:
    rejected(invoke(native_awk, snapshot([Mount("1", point=b"/usb")]), target), 3)


def test_escaped_bytes_and_non_utf8_are_preserved(native_awk: RouterHarness) -> None:
    mounts = [
        Mount("1"),
        Mount(
            "2",
            point=b"/white space/\\key",
            root=b"/tab\tline\n\\root",
            source=b"/dev/name\twith\nspace \\and\xff",
        ),
        Mount("3", point=b"/unrelated\t\n", root=b"/\xff"),
    ]
    selected(native_awk, mounts, "/white space/\\key/child")


def test_target_backslashes_bypass_awk_v_escape_decoding(native_awk: RouterHarness) -> None:
    mounts = [Mount("1"), Mount("2", point=b"/literal\\040\\n\\x41")]
    selected(native_awk, mounts, "/literal\\040\\n\\x41/bin")


def test_large_identifiers_stay_lexically_distinct(native_awk: RouterHarness) -> None:
    mounts = [
        Mount("9007199254740992", parent="99999999999999999999"),
        Mount(
            "9007199254740993",
            parent="9007199254740992",
            point=b"/tmp/opt",
            device="99999999999999999999:9007199254740993",
        ),
    ]
    selected(native_awk, mounts, "/tmp/opt/bin/jq")
    rejected(invoke(native_awk, snapshot([*mounts, replace(mounts[0], point=b"/different")])))


@pytest.mark.parametrize(
    ("kind", "options", "super_options"),
    [
        ("ext4", b"ro,noexec,nodev", b"rw"),
        ("tmpfs", b"rw,nosuid", b"rw,size=64k"),
        ("proc", b"ro", b"ro"),
        ("fuse.sshfs", b"rw", b"rw,unknown=1:2\\040value"),
    ],
)
def test_parser_reports_facts_without_storage_policy(
    native_awk: RouterHarness,
    kind: str,
    options: bytes,
    super_options: bytes,
) -> None:
    selected(native_awk, [Mount("1", kind=kind, options=options, super_options=super_options)], "/")


def test_optional_fields_include_unknown_forward_compatible_tags(native_awk: RouterHarness) -> None:
    mounts = [
        Mount(
            "1",
            optional=(
                "shared:99999999999999999999",
                "master:1",
                "propagate_from:2",
                "unbindable",
                "future",
                "other:foo:bar",
            ),
        )
    ]
    selected(native_awk, mounts, "/")


@pytest.mark.parametrize(
    "target",
    [
        None,
        "",
        "relative",
        "//",
        "/a//b",
        "/.",
        "/..",
        "/a/./b",
        "/a/../b",
        "/a/",
        "/a\t",
        "/a\n",
        "/a\r",
        "/a\x1c",
        "/a\x7f",
        "/" + "x" * 4096,
    ],
)
def test_target_contract_rejections_are_usage_errors(
    native_awk: RouterHarness, target: str | None
) -> None:
    rejected(invoke(native_awk, snapshot([Mount("1")]), target), 2)


def test_target_maximum_bytes_are_accepted(native_awk: RouterHarness) -> None:
    selected(native_awk, [Mount("1")], "/" + "x" * 4095)
    selected(native_awk, [Mount("1")], "/" + "é" * 2047 + "x")


@pytest.mark.parametrize(
    "size",
    [
        "MISSING",
        "",
        "0",
        "01",
        "+1",
        "-1",
        "1.0",
        "1e2",
        "65537",
        "9" * 20,
        " 1",
        r"1\n",
        "$(touch injected)",
    ],
)
def test_size_contract_rejections(native_awk: RouterHarness, size: str) -> None:
    rejected(invoke(native_awk, snapshot([Mount("1")]), size=size), 2)
    assert not native_awk.path("work/injected").exists()


@pytest.mark.parametrize("locale", ["POSIX", "en_US.UTF-8"])
def test_requires_byte_locale(native_awk: RouterHarness, locale: str) -> None:
    rejected(invoke(native_awk, snapshot([Mount("1")]), locale=locale), 2)


@pytest.mark.parametrize("operands", [("unopened-file",), ("extra=value",), ("-",)])
def test_filename_and_assignment_operands_are_rejected_before_open(
    native_awk: RouterHarness,
    operands: tuple[str, ...],
) -> None:
    rejected(invoke(native_awk, snapshot([Mount("1")]), operands=operands), 2)


@pytest.mark.parametrize("offset", [-1, 1])
def test_original_byte_count_must_match(native_awk: RouterHarness, offset: int) -> None:
    data = snapshot([Mount("1")])
    rejected(invoke(native_awk, data, size=str(len(data) + offset)))


@pytest.mark.parametrize("control", [b"\x00", b"\x1c"])
@pytest.mark.parametrize("position", ["start", "middle", "end"])
def test_nul_and_framing_separator_are_rejected(
    native_awk: RouterHarness,
    control: bytes,
    position: str,
) -> None:
    data = snapshot([Mount("1")])
    at = {"start": 0, "middle": len(data) // 2, "end": len(data)}[position]
    rejected(invoke(native_awk, data[:at] + control + data[at:]))


@pytest.mark.parametrize(
    "data", [b"\n", b"\n\n", b"", snapshot([Mount("1")])[:-1], snapshot([Mount("1")]) + b"\n"]
)
def test_blank_and_truncated_records(native_awk: RouterHarness, data: bytes) -> None:
    rejected(invoke(native_awk, data, size="1" if not data else None))


BAD_FIELDS = [
    ("identifier", "0"),
    ("identifier", "01"),
    ("identifier", "-1"),
    ("identifier", "1.0"),
    ("identifier", "9" * 21),
    ("parent", "00"),
    ("parent", "-1"),
    ("parent", "9" * 21),
    ("device", "1"),
    ("device", "1:2:3"),
    ("device", "01:0"),
    ("device", "0:00"),
    ("device", "-1:0"),
    ("device", "9" * 21 + ":1"),
    ("root", b"relative"),
    ("root", b"//"),
    ("root", b"/a/../b"),
    ("root", b"/a/"),
    ("point", b"/a//b"),
    ("point", b"/./a"),
    ("point", b"/.."),
    ("kind", "bad/type"),
    ("kind", "bad\tname"),
    ("options", b""),
    ("options", b",rw"),
    ("options", b"rw,"),
    ("options", b"rw,,nodev"),
    ("options", b"ro,rw"),
    ("options", b"rw,rw"),
    ("options", b"rw,nodev,nodev"),
    ("super_options", b""),
    ("super_options", b"ro,rw"),
    ("super_options", b"rw,foo,foo"),
    ("optional", ("shared",)),
    ("optional", ("shared:0",)),
    ("optional", ("master:01",)),
    ("optional", ("propagate_from:" + "9" * 21,)),
    ("optional", ("unbindable:1",)),
    ("optional", ("shared:1", "shared:2")),
    ("optional", ("future", "future:x")),
    ("optional", ("future:",)),
    ("optional", (":x",)),
]


@pytest.mark.parametrize(("field", "value"), BAD_FIELDS)
def test_malformed_required_and_optional_fields_are_quiet(
    native_awk: RouterHarness,
    field: str,
    value,
) -> None:
    rejected(invoke(native_awk, snapshot([replace(Mount("1"), **{field: value})])))


@pytest.mark.parametrize(
    "escape", [b"\\", b"\\04", b"\\000", b"\\041", b"\\777", b"\\x20", b"\\\\", b"\\0400\\bad"]
)
@pytest.mark.parametrize("field", [3, 4, 8])
def test_unknown_or_truncated_path_and_source_escapes(
    native_awk: RouterHarness,
    escape: bytes,
    field: int,
) -> None:
    fields = snapshot([Mount("1")]).rstrip(b"\n").split(b" ")
    fields[field] += escape
    rejected(invoke(native_awk, b" ".join(fields) + b"\n"))


@pytest.mark.parametrize(
    "transform",
    [
        lambda data: data.replace(b" ", b"  ", 1),
        lambda data: b" " + data,
        lambda data: data[:-1] + b" \n",
        lambda data: data.replace(b" ", b"\t", 1),
        lambda data: data.replace(b" - ", b" "),
        lambda data: data.replace(b" - ", b" - - "),
        lambda data: data[:-1] + b" extra\n",
        lambda data: data.replace(b"rw", b"rw\r", 1),
    ],
)
def test_malformed_record_grammar(native_awk: RouterHarness, transform) -> None:
    rejected(invoke(native_awk, transform(snapshot([Mount("1")]))))


def padded(mount: Mount, total: int) -> Mount:
    base = replace(mount, super_options=b"rw,pad=")
    remaining = total - len(snapshot([base]))
    assert remaining >= 0
    return replace(base, super_options=base.super_options + b"x" * remaining)


def test_line_limit_includes_terminal_lf(native_awk: RouterHarness) -> None:
    exact = padded(Mount("1"), 8192)
    assert len(snapshot([exact])) == 8192
    selected(native_awk, [exact], "/")
    oversized = padded(Mount("1"), 8193)
    assert len(snapshot([oversized])) == 8193
    rejected(invoke(native_awk, snapshot([oversized])))


def test_snapshot_maximum_exact_bytes(native_awk: RouterHarness) -> None:
    mounts = [
        padded(Mount(str(index + 1), point=b"/" if index == 0 else f"/s{index}".encode()), 8192)
        for index in range(8)
    ]
    assert len(snapshot(mounts)) == 65536
    selected(native_awk, mounts, "/")
    # The caller's independently counted oversized snapshot is rejected before
    # reading it; do not exceed the harness's private fixture file budget.
    rejected(invoke(native_awk, snapshot([Mount("1")]), size="65537"), 2)


def test_record_count_exact_boundary(native_awk: RouterHarness) -> None:
    mounts = [Mount(str(index + 1), point=f"/m{index}".encode()) for index in range(1024)]
    selected(native_awk, mounts, "/m0/file")
    extra = [*mounts, Mount("1025", point=b"/last")]
    assert len(snapshot(extra)) < 65536
    rejected(invoke(native_awk, snapshot(extra), "/m0/file"))


def test_generated_valid_trees_match_independent_component_oracle(
    native_awk: RouterHarness,
) -> None:
    rng = random.Random(7401)
    for sample in range(20):
        mounts = [Mount("1")]
        points = {b"/"}
        for number in range(2, 35):
            parent = rng.choice(mounts)
            point = parent.point.rstrip(b"/") + f"/s{sample}_{number}".encode()
            assert point not in points
            points.add(point)
            mounts.append(
                Mount(
                    str(9007199254740992 + number),
                    parent=parent.identifier,
                    point=point,
                    root=f"/bind{number}/sub".encode(),
                    device=f"8:{number}",
                    options=rng.choice([b"rw", b"ro,nodev"]),
                    super_options=b"rw",
                )
            )
        chosen = rng.choice(mounts)
        target = chosen.point.rstrip(b"/").decode() + "/bin/tool"
        rng.shuffle(mounts)
        selected(native_awk, mounts, target)


@pytest.mark.busybox
@pytest.mark.matrix("V74", evidence="busybox")
def test_optional_actual_busybox_mountinfo(busybox_router: RouterHarness) -> None:
    busybox_router.busybox_applets("awk")
    busybox_router.write("work/mountinfo.awk", SOURCE.read_text())
    selected(busybox_router, BASE, "/tmp/opt/bin/jq")
    rejected(invoke(busybox_router, snapshot([*BASE, Mount("99")])))
