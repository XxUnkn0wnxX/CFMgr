# SPDX-License-Identifier: GPL-3.0-or-later
# Native JSON parsing proof, not an input-ownership or API transport wrapper.
# Caller MUST supply LC_ALL=C and a private, immutable, bounded REGULAR file on
# stdin, with an independently checked original wc -c byte count. No operands.
# Pipes/growing files cannot be made finite or ownership-safe by this parser.
# Required -v variables: cfmgr_json_size (canonical 1..65536), cfmgr_json_mode
# (validate or tokens). No input contents appear in diagnostics; failures are quiet.
# Awk -v decodes escapes: pass verified decimal size and a literal known mode,
# never unvalidated configuration/provider text as a -v assignment.
# Native awk may exit 0 despite a failed output write. Before using ANY token,
# consumers must verify parser status, exact node/body-byte counts and the terminal
# footer (no subsequent data). The footer does not prove file I/O ownership.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") reject()
    if (cfmgr_json_size !~ /^[1-9][0-9]*$/ || length(cfmgr_json_size) > 5) reject()
    expected_size = cfmgr_json_size + 0
    if (expected_size > 65536) reject()
    if (cfmgr_json_mode != "validate" && cfmgr_json_mode != "tokens") reject()

    # BusyBox awk splits records at raw NUL even with a different RS. Do not
    # reconstruct records/newlines: length plus exact EOF detects lost bytes.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected_size) reject()
    if ((getline extra_record) != 0) reject()

    for (n = 1; n <= 255; n++) byte_value["b" sprintf("%c", n)] = n
    for (n = 0; n < 16; n++) {
        hex_value["h" substr("0123456789abcdef", n + 1, 1)] = n
        hex_value["h" substr("0123456789ABCDEF", n + 1, 1)] = n
    }
    escape_hex["e\""] = "22"
    escape_hex["e\\"] = "5c"
    escape_hex["e/"] = "2f"
    escape_hex["eb"] = "08"
    escape_hex["ef"] = "0c"
    escape_hex["en"] = "0a"
    escape_hex["er"] = "0d"
    escape_hex["et"] = "09"

    position = 1
    nodes = 0
    output_size = 0
    parse_value(0, "r", 0)
    whitespace()
    if (position != length(document) + 1) reject()
    # All syntax, Unicode, duplicate keys and resource limits pass before output.
    if (cfmgr_json_mode == "tokens") {
        footer = sprintf("end\t%d\t%d\n", nodes, output_size)
        if (output_size + length(footer) > 131072) reject()
        for (n = 1; n <= nodes; n++) printf "%s", ledger[n]
        printf "%s", footer
    }
    exit 0
}

function reject() {
    exit 1
}

function peek() {
    return substr(document, position, 1)
}

function whitespace(    character) {
    while (position <= length(document)) {
        character = peek()
        if (character != " " && character != "\t" && character != "\r" && character != "\n") break
        position++
    }
}

function token(id, parent, location, kind, payload,    line) {
    if (cfmgr_json_mode != "tokens") return
    line = id "\t" parent "\t" location "\t" kind "\t" payload "\n"
    output_size += length(line)
    if (output_size > 131072) reject()
    ledger[id] = line
}

function parse_value(parent, location, depth,    id, character, key, index_number, kind) {
    whitespace()
    character = peek()
    id = ++nodes
    if (nodes > 4096) reject()
    if (character == "{" || character == "[") {
        if (depth >= 32) reject()
        kind = (character == "{" ? "object" : "array")
        token(id, parent, location, kind, "-")
        position++
        whitespace()
        if (kind == "object") {
            if (peek() == "}") { position++; return }
            while (1) {
                if (peek() != "\"") reject()
                parse_string()
                key = "k" string_hex
                # Prefixes prevent awk numeric-string coercion of decoded keys.
                if ((id SUBSEP key) in seen_key) reject()
                seen_key[id SUBSEP key] = 1
                whitespace()
                if (peek() != ":") reject()
                position++
                parse_value(id, key, depth + 1)
                whitespace()
                if (peek() == "}") { position++; return }
                if (peek() != ",") reject()
                position++
                whitespace()
            }
        } else {
            if (peek() == "]") { position++; return }
            index_number = 0
            while (1) {
                parse_value(id, "i" index_number, depth + 1)
                index_number++
                whitespace()
                if (peek() == "]") { position++; return }
                if (peek() != ",") reject()
                position++
            }
        }
    } else if (character == "\"") {
        parse_string()
        token(id, parent, location, "string", "x" string_hex)
    } else if (character == "t" || character == "f" || character == "n") {
        kind = (character == "t" ? "true" : (character == "f" ? "false" : "null"))
        if (substr(document, position, length(kind)) != kind) reject()
        position += length(kind)
        token(id, parent, location, kind, "-")
    } else {
        parse_number()
        token(id, parent, location, "number", "n" number_text)
    }
}

function digit(character) {
    return character != "" && character ~ /^[0123456789]$/
}

function parse_number(    start, character) {
    start = position
    if (peek() == "-") position++
    character = peek()
    if (character == "0") position++
    else {
        if (character !~ /^[123456789]$/) reject()
        while (digit(peek())) position++
    }
    if (peek() == ".") {
        position++
        if (!digit(peek())) reject()
        while (digit(peek())) position++
    }
    if (peek() == "e" || peek() == "E") {
        position++
        if (peek() == "+" || peek() == "-") position++
        if (!digit(peek())) reject()
        while (digit(peek())) position++
    }
    # Never convert JSON numbers: bigint, signed zero and huge exponents survive.
    number_text = substr(document, start, position - start)
}

function read_hex4(    value, count, character) {
    value = 0
    for (count = 0; count < 4; count++) {
        character = peek()
        if (!("h" character in hex_value)) reject()
        value = value * 16 + hex_value["h" character]
        position++
    }
    return value
}

function unicode_hex(codepoint) {
    if (codepoint < 128) return sprintf("%02x", codepoint)
    if (codepoint < 2048)
        return sprintf("%02x%02x", 192 + int(codepoint / 64), 128 + codepoint % 64)
    if (codepoint < 65536)
        return sprintf("%02x%02x%02x", 224 + int(codepoint / 4096),
                       128 + int(codepoint / 64) % 64, 128 + codepoint % 64)
    return sprintf("%02x%02x%02x%02x", 240 + int(codepoint / 262144),
                   128 + int(codepoint / 4096) % 64, 128 + int(codepoint / 64) % 64,
                   128 + codepoint % 64)
}

function raw_utf8_hex(    first, count, index_number, next_byte, encoded, character) {
    character = peek()
    if (!("b" character in byte_value)) reject()
    first = byte_value["b" character]
    if (first < 32) reject()
    if (first < 128) { position++; return sprintf("%02x", first) }
    if (first >= 194 && first <= 223) count = 2
    else if (first >= 224 && first <= 239) count = 3
    else if (first >= 240 && first <= 244) count = 4
    else reject()
    encoded = sprintf("%02x", first)
    position++
    for (index_number = 1; index_number < count; index_number++) {
        character = peek()
        if (!("b" character in byte_value)) reject()
        next_byte = byte_value["b" character]
        if (next_byte < 128 || next_byte > 191) reject()
        if (index_number == 1) {
            if (first == 224 && next_byte < 160) reject()
            if (first == 237 && next_byte > 159) reject()
            if (first == 240 && next_byte < 144) reject()
            if (first == 244 && next_byte > 143) reject()
        }
        encoded = encoded sprintf("%02x", next_byte)
        position++
    }
    return encoded
}

function parse_string(    character, fragment, codepoint, low, decoded_size) {
    if (peek() != "\"") reject()
    position++
    string_hex = ""
    decoded_size = 0
    while (position <= length(document)) {
        character = peek()
        if (character == "\"") { position++; return }
        if (character == "\\") {
            position++
            character = peek()
            if (character == "u") {
                position++
                codepoint = read_hex4()
                if (codepoint >= 55296 && codepoint <= 56319) {
                    if (substr(document, position, 2) != "\\u") reject()
                    position += 2
                    low = read_hex4()
                    if (low < 56320 || low > 57343) reject()
                    codepoint = 65536 + (codepoint - 55296) * 1024 + low - 56320
                } else if (codepoint >= 56320 && codepoint <= 57343) reject()
                # Escaped NUL becomes hex "00", never a NUL in an awk C string.
                fragment = unicode_hex(codepoint)
            } else {
                if (!("e" character in escape_hex)) reject()
                fragment = escape_hex["e" character]
                position++
            }
        } else fragment = raw_utf8_hex()
        decoded_size += length(fragment) / 2
        if (decoded_size > 16384) reject()
        string_hex = string_hex fragment
    }
    reject()
}
