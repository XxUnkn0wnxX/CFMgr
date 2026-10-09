# SPDX-License-Identifier: GPL-3.0-or-later
# Framed projection of json.awk tokens, not full configuration approval.
# Caller supplies LC_ALL=C, zero operands, immutable bounded REGULAR stdin and
# independently checked canonical cfmgr_config_header_size (1..131072).
# Caller must separately establish the actual JSON producer's successful status:
# hex framing does not prove Unicode semantics or the original JSON syntax.
# No unknown value, setting or credential is returned or approved here.
# Native awk may report success after an output-write failure; consumers must
# verify this status, complete footer/body bytes and exact EOF before use.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") fail(2)
    if (cfmgr_config_header_size !~ /^[1-9][0-9]*$/ ||
        length(cfmgr_config_header_size) > 6 || cfmgr_config_header_size + 0 > 131072) fail(2)
    expected = cfmgr_config_header_size + 0
    # BusyBox can split at raw NUL despite RS. Original byte length and exact
    # EOF reject that loss, as well as any literal record separator.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected ||
        (getline extra) != 0) fail(1)
    if (substr(document, expected, 1) != "\n" || document ~ /[^\t\n -~]/) fail(1)

    records = split(document, rows, "\n")
    if (records < 3 || records > 4098 || rows[records] != "") fail(1)
    nodes = records - 2
    for (id = 1; id <= nodes; id++) {
        body_bytes += length(rows[id]) + 1
        node(rows[id], id)
    }
    if (split(rows[nodes + 1], footer, "\t") != 3 || footer[1] != "end" ||
        !decimal(footer[2], 4) || footer[2] + 0 != nodes ||
        !decimal(footer[3], 6) || footer[3] + 0 != body_bytes) fail(1)
    if (!schema_found || !generation_found || !developer_found) fail(1)

    body = "config-header\t1\t" generation "\t" developer "\n"
    printf "%send\t%d\n", body, length(body)
    exit 0
}

function fail(status) {
    exit status
}

function decimal(value, max_digits) {
    return length(value) <= max_digits && value ~ /^(0|[1-9][0-9]*)$/
}

function hex(value) {
    return length(value) <= 32768 && length(value) % 2 == 0 && value !~ /[^0-9a-f]/
}

function node(line, id,    fields, parent, location, kind, payload, key) {
    if (split(line, fields, "\t") != 5 || !decimal(fields[1], 4) ||
        fields[1] + 0 != id || !decimal(fields[2], 4)) fail(1)
    parent = fields[2] + 0
    location = fields[3]
    kind = fields[4]
    payload = fields[5]
    if (id == 1) {
        if (parent != 0 || location != "r" || kind != "object") fail(1)
    } else {
        if (parent < 1 || parent >= id || !(parent in container)) fail(1)
        # A sibling can close a subtree; its container can never be revisited.
        while (depth && stack[depth] != parent) delete stack[depth--]
        if (!depth) fail(1)
        if (container[parent] == "object") {
            if (substr(location, 1, 1) != "k" || !hex(substr(location, 2))) fail(1)
            key = parent SUBSEP location
            if (key in seen_key) fail(1)
            seen_key[key] = 1
        } else {
            if (location != sprintf("i%d", next_index[parent])) fail(1)
            next_index[parent]++
        }
    }

    if (kind == "object" || kind == "array") {
        if (payload != "-" || depth >= 32) fail(1)
        container[id] = kind
        stack[++depth] = id
    } else if (kind == "string") {
        if (substr(payload, 1, 1) != "x" || !hex(substr(payload, 2))) fail(1)
    } else if (kind == "number") {
        if (length(payload) > 65537 ||
            payload !~ /^n-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) fail(1)
    } else if (kind == "true" || kind == "false" || kind == "null") {
        if (payload != "-") fail(1)
    } else fail(1)

    if (parent != 1) return
    if (location == "k736368656d61") {
        if (kind != "number" || payload != "n1") fail(1)
        schema_found = 1
    } else if (location == "k67656e65726174696f6e") {
        generation = substr(payload, 2)
        if (kind != "number" || !decimal(generation, 10) || generation + 0 > 2147483647) fail(1)
        generation_found = 1
    } else if (location == "k646576656c6f706572") {
        if (kind != "true" && kind != "false") fail(1)
        developer = kind
        developer_found = 1
    }
}
