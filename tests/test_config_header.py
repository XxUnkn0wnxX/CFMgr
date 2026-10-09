"""Bounded header projection from real JSON tokens; no config ownership claim."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult
from tests.test_json import SOURCE as JSON_SOURCE
from tests.test_json import invoke as invoke_json
from tests.test_json import oracle

SOURCE = Path(__file__).resolve().parents[1] / "modules/lib/config_header.awk"
SEED = (
    b'{"schema":1,"generation":7,"developer":true,'
    b'"opaque":{"credential":"fixture-secret","list":["",null]},"last":-0.1E+999}'
)
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V42", evidence="host")]


@pytest.fixture
def native_awk(router: RouterHarness) -> RouterHarness:
    executable = shutil.which("awk")
    assert executable is not None, "host awk is required"
    router.path("bin/awk").symlink_to(Path(executable).resolve())
    router.write("work/json.awk", JSON_SOURCE.read_text(encoding="utf-8"))
    return router


def produce(router: RouterHarness, document: bytes) -> bytes:
    result = invoke_json(router, document)
    # Consumer success cannot substitute for actual producer success.
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == oracle(document)
    return result.stdout.encode("ascii")


def consume(
    router: RouterHarness,
    tokens: bytes,
    *,
    size: str | None = None,
    operands: tuple[str, ...] = (),
    locale: str = "C",
) -> ShellResult:
    # Explicit bounded fixture bytes include the ledger cap (above the generic
    # harness text limit) and one over-limit refusal; stdin stays a regular file.
    assert len(tokens) <= 131073
    path = router.path("ram/header-tokens")
    path.write_bytes(tokens)
    path.chmod(0o600)
    args = []
    if size != "MISSING":
        args.extend(
            ["-v", "cfmgr_config_header_size=" + (str(len(tokens)) if size is None else size)]
        )
    args.extend(["-f", str(SOURCE), *operands])
    return router.run('awk "$@" < "$RAM_ROOT/header-tokens"\n', args, env={"LC_ALL": locale})


def rejected(result: ShellResult, status: int = 1) -> None:
    assert result.returncode == status, result
    assert result.stdout == result.stderr == "", result


@pytest.mark.parametrize(
    ("document", "expected"),
    [
        (b'{"schema":1,"generation":0,"developer":false}', "config-header\t1\t0\tfalse\nend\t24\n"),
        (
            b'{"schema":1,"generation":2147483647,"developer":true}',
            "config-header\t1\t2147483647\ttrue\nend\t32\n",
        ),
        (SEED, "config-header\t1\t7\ttrue\nend\t23\n"),
        (
            b'{"developer":true,"nested":{"schema":99,"generation":-9,"developer":false},'
            b'"generation":7,"schema":1}',
            "config-header\t1\t7\ttrue\nend\t23\n",
        ),
        (
            b'{"\\u0073chema":1,"generation":0,"developer":false,'
            b'"credentials":{"nul":"\\u0000","setting":[{},[],null,false,1e999]}}',
            "config-header\t1\t0\tfalse\nend\t24\n",
        ),
    ],
    ids=["zero", "uint31-maximum", "opaque-secret", "top-level-only", "decoded-key"],
)
def test_real_producer_projects_only_required_top_level_header(
    native_awk: RouterHarness, document: bytes, expected: str
) -> None:
    result = consume(native_awk, produce(native_awk, document))
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == expected


@pytest.mark.parametrize(
    "document",
    [
        b"[1,0,false]",
        b'{"generation":0,"developer":false}',
        b'{"schema":1,"developer":false}',
        b'{"schema":1,"generation":0}',
        b'{"nested":{"schema":1,"generation":0,"developer":false}}',
        b'{"schema":2,"generation":0,"developer":false}',
        b'{"schema":1.0,"generation":0,"developer":false}',
        b'{"schema":1,"generation":-0,"developer":false}',
        b'{"schema":1,"generation":1e0,"developer":false}',
        b'{"schema":1,"generation":2147483648,"developer":false}',
        b'{"schema":1,"generation":"0","developer":false}',
        b'{"schema":1,"generation":0,"developer":"false"}',
    ],
    ids=[
        "root-array",
        "missing-schema",
        "missing-generation",
        "missing-developer",
        "nested",
        "schema-version",
        "schema-lexeme",
        "signed-zero",
        "generation-exponent",
        "generation-overflow",
        "generation-type",
        "developer-type",
    ],
)
def test_valid_json_with_unusable_header_is_quietly_refused(
    native_awk: RouterHarness, document: bytes
) -> None:
    rejected(consume(native_awk, produce(native_awk, document)))


def framed(rows: list[str]) -> bytes:
    body = "".join(row + "\n" for row in rows).encode("ascii")
    return body + f"end\t{len(rows)}\t{len(body)}\n".encode("ascii")


def consume_group(router: RouterHarness, cases: list[tuple[str, bytes]]) -> ShellResult:
    args = [str(SOURCE)]
    for index, (label, data) in enumerate(cases):
        assert len(data) <= 131072
        path = router.path(f"ram/header-case-{index}")
        path.write_bytes(data)
        path.chmod(0o600)
        args.extend([label, str(len(data)), str(path)])
    # One owned shell for independent immutable cases; every awk still reads
    # its own regular file. Exact output exposes even one partial ledger leak.
    return router.run(
        "source=$1; shift\n"
        'while [ "$#" -gt 0 ]; do\n'
        '    awk -v "cfmgr_config_header_size=$2" -f "$source" <"$3"\n'
        "    status=$?\n"
        '    printf "%s\\t%s\\n" "$1" "$status"\n'
        "    shift 3\n"
        "done\n",
        args,
    )


def corrupted(tokens: bytes, fault: str) -> bytes:
    rows = tokens.decode("ascii").splitlines()[:-1]
    if fault in {"missing-lf", "truncated-footer", "extra-record", "raw-nul", "raw-rs", "raw-cr"}:
        return {
            "missing-lf": tokens[:-1],
            "truncated-footer": tokens[:-3],
            "extra-record": tokens + b"extra\n",
            "raw-nul": tokens.replace(b"fixture", b"fixture\x00", 1) + b"\x00",
            "raw-rs": tokens[:9] + b"\x1c" + tokens[9:],
            "raw-cr": tokens.replace(b"\n", b"\r\n", 1),
        }[fault]
    if fault == "footer-count":
        return tokens.replace(b"end\t10\t", b"end\t9\t")
    if fault == "footer-bytes":
        return framed(rows).rsplit(b"\t", 1)[0] + b"\t0\n"
    if fault == "footer-canonical":
        return tokens.replace(b"end\t10\t", b"end\t010\t")
    if fault == "duplicate-object-key":
        rows.append("11\t1\tk6c617374\tnumber\tn10")
        return framed(rows)
    if fault == "closed-parent":
        rows.append("11\t7\ti2\tnull\t-")
        return framed(rows)
    edits = {
        "id-gap": (2, 0, "4"),
        "id-canonical": (2, 0, "03"),
        "future-parent": (2, 1, "4"),
        "leaf-parent": (4, 1, "4"),
        "parent-canonical": (2, 1, "01"),
        "root-location": (0, 2, "k"),
        "array-duplicate": (8, 2, "i0"),
        "array-gap": (8, 2, "i2"),
        "object-key-framing": (5, 2, "k6"),
        "string-framing": (5, 4, "xabc"),
        "number-framing": (9, 4, "n01"),
        "container-payload": (4, 4, "x"),
        "boolean-payload": (3, 4, "n1"),
        "unknown-type": (5, 3, "command"),
    }
    if fault == "extra-field":
        rows[5] += "\textra"
    else:
        row, column, value = edits[fault]
        fields = rows[row].split("\t")
        fields[column] = value
        rows[row] = "\t".join(fields)
    # Correct the footer after structural corruption so footer mismatch alone
    # cannot make an otherwise vacuous structure test pass.
    return framed(rows)


def test_corrected_footer_does_not_hide_corrupt_token_structure(
    native_awk: RouterHarness,
) -> None:
    tokens = produce(native_awk, SEED)
    faults = [
        "missing-lf",
        "truncated-footer",
        "extra-record",
        "raw-nul",
        "raw-rs",
        "raw-cr",
        "footer-count",
        "footer-bytes",
        "footer-canonical",
        "duplicate-object-key",
        "closed-parent",
        "id-gap",
        "id-canonical",
        "future-parent",
        "leaf-parent",
        "parent-canonical",
        "root-location",
        "array-duplicate",
        "array-gap",
        "object-key-framing",
        "string-framing",
        "number-framing",
        "container-payload",
        "boolean-payload",
        "unknown-type",
        "extra-field",
    ]
    result = consume_group(native_awk, [(fault, corrupted(tokens, fault)) for fault in faults])
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == "".join(f"{fault}\t1\n" for fault in faults)


def test_consumer_node_and_container_depth_caps(native_awk: RouterHarness) -> None:
    header = [
        "1\t0\tr\tobject\t-",
        "2\t1\tk736368656d61\tnumber\tn1",
        "3\t1\tk67656e65726174696f6e\tnumber\tn7",
        "4\t1\tk646576656c6f706572\ttrue\t-",
    ]
    cases = []
    for count in (4096, 4097):
        rows = [*header, "5\t1\tk6f7061717565\tarray\t-"]
        rows.extend(f"{node}\t5\ti{node - 6}\tnull\t-" for node in range(6, count + 1))
        cases.append((f"nodes-{count}", framed(rows)))
    for depth in (32, 33):
        rows = list(header)
        parent = 1
        for node in range(5, depth + 4):
            rows.append(f"{node}\t{parent}\tk61\tobject\t-")
            parent = node
        cases.append((f"depth-{depth}", framed(rows)))
    # Headers and exact footers remain valid at both boundaries. These are
    # consumer guards, without another producer JSON limit matrix.
    result = consume_group(native_awk, cases)
    assert result.returncode == 0 and result.stderr == "", result
    expected = "config-header\t1\t7\ttrue\nend\t23\n"
    assert result.stdout == (
        expected + "nodes-4096\t0\nnodes-4097\t1\n" + expected + "depth-32\t0\ndepth-33\t1\n"
    )


def test_invalid_declared_size_contract_has_status_two(native_awk: RouterHarness) -> None:
    tokens = produce(native_awk, SEED)
    for size in ("MISSING", "", "0", "01", "+1", "1e0", "131073", "9999999"):
        rejected(consume(native_awk, tokens, size=size), 2)


def test_exact_input_size_and_invocation_are_independent_gates(native_awk: RouterHarness) -> None:
    tokens = produce(native_awk, SEED)
    for size in (str(len(tokens) - 1), str(len(tokens) + 1)):
        rejected(consume(native_awk, tokens, size=size))
    rejected(consume(native_awk, tokens, operands=("unexpected",)), 2)
    rejected(consume(native_awk, tokens, locale="POSIX"), 2)
    rejected(consume(native_awk, b"x"))


def test_exact_ledger_byte_cap_with_real_producer(native_awk: RouterHarness) -> None:
    value = {"schema": 1, "generation": 0, "developer": False, "opaque": [""] * 4, "padding": 1}
    document = json.dumps(value, separators=(",", ":")).encode()
    base = oracle(document).encode("ascii")
    body = base[: base.rfind(b"end\t")]
    needed = 131072 - len(b"end\t10\t131072\n") - len(body)
    if needed % 2:
        value["padding"] = 10
        needed -= 1
    for index in range(4):
        length = min(16384, needed // 2)
        value["opaque"][index] = "q" * length
        needed -= 2 * length
    assert needed == 0
    document = json.dumps(value, separators=(",", ":")).encode()
    assert len(document) <= 65536
    tokens = produce(native_awk, document)
    assert len(tokens) == 131072
    result = consume(native_awk, tokens)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == "config-header\t1\t0\tfalse\nend\t24\n"
    rejected(consume(native_awk, tokens + b"\n"), 2)


@pytest.mark.busybox
@pytest.mark.matrix("V42", evidence="busybox")
def test_real_busybox_producer_header_and_original_nul_framing(
    busybox_router: RouterHarness,
) -> None:
    busybox_router.busybox_applets("awk")
    busybox_router.write("work/json.awk", JSON_SOURCE.read_text(encoding="utf-8"))
    tokens = produce(busybox_router, SEED)
    result = consume(busybox_router, tokens)
    assert result.returncode == 0 and result.stderr == "", result
    assert result.stdout == "config-header\t1\t7\ttrue\nend\t23\n"
    rejected(consume(busybox_router, tokens + b"\x00"))
