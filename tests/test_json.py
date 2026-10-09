"""Native JSON parsing evidence; stable input ownership remains a caller precondition."""

from __future__ import annotations

import json
import random
import shutil
from pathlib import Path

import pytest

from tests.harness import RouterHarness, ShellResult

SOURCE = Path(__file__).resolve().parents[1] / "modules/lib/json.awk"
HOST_AWKS = sorted(
    {
        str(Path(path).resolve())
        for path in ("/usr/bin/awk", "/usr/local/bin/awk", shutil.which("awk"))
        if path and Path(path).is_file()
    }
)
pytestmark = [pytest.mark.integration, pytest.mark.matrix("V42", evidence="host")]


class Number(str):
    """Preserve the lexical JSON number delivered by Python's independent parser."""


def oracle(document: bytes) -> str:
    def invalid_constant(value: str):
        raise ValueError(value)

    value = json.loads(
        document.decode("utf-8"),
        parse_int=Number,
        parse_float=Number,
        parse_constant=invalid_constant,
    )
    lines = []

    def visit(item, parent: int, location: str) -> None:
        node = len(lines) + 1
        if isinstance(item, dict):
            kind, payload = "object", "-"
        elif isinstance(item, list):
            kind, payload = "array", "-"
        elif isinstance(item, Number):
            kind, payload = "number", "n" + item
        elif isinstance(item, str):
            kind, payload = "string", "x" + item.encode("utf-8").hex()
        elif item is True:
            kind, payload = "true", "-"
        elif item is False:
            kind, payload = "false", "-"
        elif item is None:
            kind, payload = "null", "-"
        else:
            raise AssertionError(f"unexpected oracle value type {type(item)}")
        lines.append(f"{node}\t{parent}\t{location}\t{kind}\t{payload}\n")
        if isinstance(item, dict):
            for key, child in item.items():
                visit(child, node, "k" + key.encode("utf-8").hex())
        elif isinstance(item, list):
            for index, child in enumerate(item):
                visit(child, node, "i" + str(index))

    visit(value, 0, "r")
    body = "".join(lines)
    return body + f"end\t{len(lines)}\t{len(body.encode('ascii'))}\n"


@pytest.fixture(params=HOST_AWKS, ids=lambda path: path)
def native_awk(router: RouterHarness, request: pytest.FixtureRequest) -> RouterHarness:
    router.path("bin/awk").symlink_to(request.param)
    router.write("work/json.awk", SOURCE.read_text(encoding="utf-8"))
    return router


def invoke(
    router: RouterHarness,
    document: bytes,
    *,
    mode: str | None = "tokens",
    size: str | None = None,
    operands: tuple[str, ...] = (),
    locale: str = "C",
) -> ShellResult:
    # Invalid UTF-8/NUL fixtures bypass write(str), but preserve its size/privacy contract.
    assert len(document) <= router.FILE_LIMIT
    path = router.path("ram/input.json")
    path.write_bytes(document)
    path.chmod(0o600)
    args = []
    if size != "MISSING":
        args.extend(["-v", "cfmgr_json_size=" + (str(len(document)) if size is None else size)])
    if mode is not None:
        args.extend(["-v", "cfmgr_json_mode=" + mode])
    args.extend(["-f", str(router.path("work/json.awk")), *operands])
    return router.run('awk "$@" < "$RAM_ROOT/input.json"\n', args, env={"LC_ALL": locale})


def assert_rejected(result: ShellResult) -> None:
    assert result.returncode != 0
    assert result.stdout == ""
    assert result.stderr == ""


VALID_DOCUMENTS = [
    b"{}",
    b"[]",
    b"null",
    b"true",
    b"false",
    b'""',
    b"0",
    b"-0",
    b"0.0",
    b"-0.0",
    b"1E+00",
    b"1e-9999999999999999999999",
    b"9" * 500,
    b' { "": [true,false,null,{},[],"",1,-2.5e+40] } \n\t\r',
    b'{"1":1,"01":2,"1.0":3,"1e0":4}',
    b'[{"a":1},{"a":2}]',
    b'{"a\\t\\n\\u0000\\\\\\"": "\\b\\f\\n\\r\\t\\/\\\\\\""}',
    b'["\\u0000", "\\u007f", "\\u0080", "\\u07ff", "\\u0800", "\\uffff"]',
    b'["\\ud800\\udc00", "\\uDBFF\\uDFFF"]',
    json.dumps({"é": "𝄞", "e\u0301": "\U0010ffff", "nul": "\0"}, ensure_ascii=False).encode(),
    json.dumps(
        "\u007f\u0080\u07ff\u0800\ud7ff\ue000\uffff\U00010000\U0010ffff", ensure_ascii=False
    ).encode(),
]


@pytest.mark.parametrize("document", VALID_DOCUMENTS)
def test_valid_documents_match_python_preorder_oracle(
    native_awk: RouterHarness, document: bytes
) -> None:
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == oracle(document)
    assert result.stderr == ""
    validated = invoke(native_awk, document, mode="validate")
    assert validated.returncode == 0
    assert validated.stdout == validated.stderr == ""


def test_deterministic_nested_documents_match_oracle(native_awk: RouterHarness) -> None:
    rng = random.Random(8259)
    alphabet = ["a", "é", "𝄞", "\0", "\t", "\\", '"', "e\u0301"]

    def value(depth: int):
        if depth == 0:
            return rng.choice(
                [
                    None,
                    False,
                    True,
                    rng.randrange(-(10**25), 10**25),
                    "".join(rng.choices(alphabet, k=5)),
                ]
            )
        if rng.choice([True, False]):
            return [value(depth - 1) for _ in range(rng.randrange(4))]
        return {
            "".join(rng.choices(alphabet, k=3)) + str(index): value(depth - 1)
            for index in range(rng.randrange(4))
        }

    for index in range(20):
        document = json.dumps(value(4), ensure_ascii=index % 2 == 0, separators=(",", ":")).encode()
        result = invoke(native_awk, document)
        assert result.returncode == 0
        assert result.stdout == oracle(document)
        assert result.stderr == ""


INVALID_GRAMMAR = [
    b"",
    b" ",
    b"{}{}",
    b"null true",
    b"truex",
    b"True",
    b"FALSE",
    b"NaN",
    b"Infinity",
    b"+1",
    b"01",
    b"-01",
    b".1",
    b"1.",
    b"1e",
    b"1e+",
    b"1e-",
    b"--1",
    b"0x1",
    b"1 2",
    b"[",
    b"[1,]",
    b"[,1]",
    b"[1 2]",
    b"{",
    b"{a:1}",
    b'{"a" 1}',
    b'{"a":}',
    b'{"a":1,}',
    b'{"a":1 "b":2}',
    b'"',
    b'"\\"',
    b'"\\x20"',
    b'"\\v"',
    b'"\\u"',
    b'"\\u123"',
    b'"\\u12xz"',
    b'"\\ud800"',
    b'"\\udc00"',
    b'"\\ud800x"',
    b'"\\ud800\\u0041"',
    b'"\\ud800\\ud800"',
    b"\xef\xbb\xbf{}",
    b"\x0bnull",
    b"null\x0c",
    b'"raw\nline"',
    b'"raw\tbyte"',
    b'"\x01"',
    b'{"a":1,"a":2}',
    b'{"A":1,"\\u0041":2}',
    b'{"/":1,"\\/":2}',
    b'{"\\u0000":1,"\\u0000":2}',
    '{"é":1,"\\u00e9":2}'.encode(),
    '{"𝄞":1,"\\ud834\\udd1e":2}'.encode(),
]


@pytest.mark.parametrize("document", INVALID_GRAMMAR)
def test_invalid_syntax_duplicates_and_unicode_are_quiet(
    native_awk: RouterHarness, document: bytes
) -> None:
    assert_rejected(invoke(native_awk, document))
    assert_rejected(invoke(native_awk, document, mode="validate"))


@pytest.mark.parametrize(
    "raw",
    [
        b"\x80",
        b"\xbf",
        b"\xc0\x80",
        b"\xc1\xbf",
        b"\xc2",
        b"\xc2a",
        b"\xe0\x80\x80",
        b"\xe0\x9f\xbf",
        b"\xed\xa0\x80",
        b"\xed\xbf\xbf",
        b"\xe1\x80",
        b"\xe1\x80a",
        b"\xf0\x80\x80\x80",
        b"\xf0\x8f\xbf\xbf",
        b"\xf4\x90\x80\x80",
        b"\xf5\x80\x80\x80",
        b"\xff",
        b"\xfe",
        b"\xf1\x80\x80",
        b"\xf1\x80\x80a",
    ],
)
def test_invalid_raw_utf8(native_awk: RouterHarness, raw: bytes) -> None:
    assert_rejected(invoke(native_awk, b'"' + raw + b'"'))
    assert_rejected(invoke(native_awk, b'{"' + raw + b'":0}'))


@pytest.mark.parametrize(
    "document",
    [
        b"\0null",
        b"nu\0ll",
        b"null\0",
        b'"a\0b"',
        b"{}\0[]",
        b"\x1cnull",
        b"nu\x1cll",
        b"null\x1c",
        b'"a\x1cb"',
        b"{}\x1c[]",
    ],
)
def test_original_byte_framing_rejects_nul_and_separator(
    native_awk: RouterHarness, document: bytes
) -> None:
    assert_rejected(invoke(native_awk, document))


@pytest.mark.parametrize(
    "size",
    ["MISSING", "", "0", "01", "+1", "-1", "1.0", "1e0", " 1", "1 ", "65537", "9" * 100, "3", "5"],
)
def test_required_canonical_size_and_exact_length(native_awk: RouterHarness, size: str) -> None:
    assert_rejected(invoke(native_awk, b"null", size=size))


@pytest.mark.parametrize("mode", [None, "", "token", "Tokens", "validate ", "tokens\\n"])
def test_required_exact_mode(native_awk: RouterHarness, mode: str | None) -> None:
    # -v decodes \n into a newline. A literal newline instead makes native awk
    # reject its own CLI syntax before BEGIN; that diagnostic is outside the parser.
    assert_rejected(invoke(native_awk, b"null", mode=mode))


def test_file_operands_and_non_c_locale_are_refused(native_awk: RouterHarness) -> None:
    assert_rejected(invoke(native_awk, b"null", operands=("unexpected.json",)))
    assert_rejected(invoke(native_awk, b"null", locale="POSIX"))


def test_input_byte_limit_and_long_number_lexeme(native_awk: RouterHarness) -> None:
    document = b"null" + b" " * (65536 - 4)
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == oracle(document)
    assert_rejected(invoke(native_awk, document, size="65537"))
    # Max-size numeric input is textual; Python's configured bigint digit limit
    # cannot interfere because the independent oracle uses Number, not int.
    document = b"9" * 65536
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == oracle(document)
    assert result.stderr == ""


@pytest.mark.parametrize("text", ["a" * 16384, "é" * 8192, "\n" * 16384, "\u0800" * 5461 + "a"])
def test_decoded_string_byte_limit(native_awk: RouterHarness, text: str) -> None:
    document = json.dumps(text, ensure_ascii=False).encode()
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == oracle(document)
    assert_rejected(invoke(native_awk, json.dumps(text + "a", ensure_ascii=False).encode()))
    key_document = json.dumps({text: 0}, ensure_ascii=False).encode()
    key_result = invoke(native_awk, key_document)
    assert key_result.returncode == 0
    assert key_result.stdout == oracle(key_document)
    assert_rejected(invoke(native_awk, json.dumps({text + "a": 0}, ensure_ascii=False).encode()))


def test_node_and_container_depth_boundaries(native_awk: RouterHarness) -> None:
    document = ("[" + ",".join(["null"] * 4095) + "]").encode()
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == oracle(document)
    assert_rejected(invoke(native_awk, ("[" + ",".join(["null"] * 4096) + "]").encode()))
    for document in (b"[" * 32 + b"]" * 32, b"[" * 32 + b"0" + b"]" * 32):
        result = invoke(native_awk, document)
        assert result.returncode == 0
        assert result.stdout == oracle(document)
    assert_rejected(invoke(native_awk, b"[" * 33 + b"]" * 33))


def test_complete_token_output_budget(native_awk: RouterHarness) -> None:
    empty_strings = ',""' * 4000
    base = ("[1" + empty_strings + ',"",""]').encode()
    baseline_lines = oracle(base).splitlines(keepends=True)
    node_count = len(baseline_lines) - 1
    # At the exact cap the body size has six decimal digits. Reserve that footer,
    # then vary string bytes by two and the first number lexeme by one as needed.
    footer_size = len(f"end\t{node_count}\t131072\n")
    target_body_size = 131072 - footer_size
    assert 100000 <= target_body_size < 1000000
    remaining = target_body_size - len("".join(baseline_lines[:-1]).encode())
    number = "1"
    if remaining % 2:
        number = "10"
        remaining -= 1
    padding_length = remaining // 2
    assert 0 <= padding_length <= 2 * 16384
    first_padding = "q" * min(padding_length, 16384)
    second_padding = "q" * max(0, padding_length - 16384)
    suffix = ',"' + first_padding + '","' + second_padding + '"]'
    document = ("[" + number + empty_strings + suffix).encode()
    expected = oracle(document)
    assert len(expected.encode()) == 131072
    assert len(expected.splitlines(keepends=True)[-1]) == footer_size
    result = invoke(native_awk, document)
    assert result.returncode == 0
    assert result.stdout == expected
    # One extra number digit adds one output byte; no partial ledger may escape.
    overflow = ("[" + number + "0" + empty_strings + suffix).encode()
    assert len(oracle(overflow).encode()) == 131073
    assert_rejected(invoke(native_awk, overflow))
    result = invoke(native_awk, overflow, mode="validate")
    assert result.returncode == 0
    assert result.stdout == result.stderr == ""


@pytest.mark.busybox
@pytest.mark.matrix("V42", evidence="busybox")
def test_actual_busybox_framing_and_ledger(busybox_router: RouterHarness) -> None:
    busybox_router.busybox_applets("awk")
    busybox_router.write("work/json.awk", SOURCE.read_text(encoding="utf-8"))
    document = '{"𝄞":"\\u0000","values":[-0,1e999999999999999999,true]}'.encode()
    result = invoke(busybox_router, document)
    assert result.returncode == 0
    assert result.stdout == oracle(document)
    for document in (b"null\0", b"null\x1c", b'"\xed\xa0\x80"'):
        assert_rejected(invoke(busybox_router, document))
