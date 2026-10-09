# SPDX-License-Identifier: GPL-3.0-or-later
# Mount selection facts only: not storage approval, UUID or live identity proof.
# Caller supplies LC_ALL=C, a private immutable bounded REGULAR snapshot on stdin,
# its independently verified original byte count, and an already canonical target
# in ENVIRON["CFMGR_MOUNT_TARGET"]. No operands or input-derived -v assignments.
# Acquisition, supervision, file ownership and mount races belong to the caller.
# Missing/empty/select mode preserves selection output. Literal topology mode
# additionally reports selected propagation fields and a strict descendant record count;
# unknown optional tags remain facts, not a policy or authorization decision.
# Before consuming output, verify status, exact body byte count, terminal footer
# and exact EOF. Native awk can report success even when an output write fails.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") fail(2)
    if (cfmgr_mountinfo_mode != "" && cfmgr_mountinfo_mode != "select" && cfmgr_mountinfo_mode != "topology") fail(2)
    if (cfmgr_mountinfo_size !~ /^[1-9][0-9]*$/ || length(cfmgr_mountinfo_size) > 5) fail(2)
    expected = cfmgr_mountinfo_size + 0
    if (expected > 65536) fail(2)
    target = ENVIRON["CFMGR_MOUNT_TARGET"]
    if (length(target) > 4096 || !canonical(target) || target ~ /[[:cntrl:]]/) fail(2)

    # BusyBox may split at NUL and other awks may truncate C strings. Compare the
    # intact first record to the original count, then require exact EOF.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected) fail(1)
    if ((getline extra) != 0) fail(1)
    if (substr(document, length(document), 1) != "\n") fail(1)
    for (i = 1; i <= 255; i++) byte["b" sprintf("%c", i)] = i
    escape["e040"] = " "
    escape["e011"] = "\t"
    escape["e012"] = "\n"
    escape["e134"] = "\\"

    start = 1
    count = 0
    descendants = 0
    best_length = -1
    while (start <= length(document)) {
        remaining = substr(document, start)
        end = index(remaining, "\n")
        if (!end || end > 8192 || ++count > 1024) fail(1)
        parse_line(substr(remaining, 1, end - 1))
        start += end
    }
    if (best_length < 0) fail(3)
    relative = (best_point == "/" ? (target == "/" ? "" : target) : substr(target, length(best_point) + 1))
    filesystem_target = (best_root == "/" ? (relative == "" ? "/" : relative) : best_root relative)
    body = "mount\t" best_id "\t" best_parent "\t" best_device "\t" hex(best_root) "\t" hex(best_point) "\t" best_type "\t" hex(best_source) "\t" hex(best_options) "\t" hex(best_super) "\t" hex(filesystem_target) "\n"
    if (cfmgr_mountinfo_mode == "topology") {
        body = body "topology\t" best_shared "\t" best_master "\t" best_propagate_from "\t" best_unbindable "\t" best_unknown "\t" descendants "\n"
    }
    footer = sprintf("end\t%d\n", length(body))
    if (length(body) + length(footer) > 65536) fail(1)
    printf "%s%s", body, footer
    exit 0
}

function fail(status) {
    exit status
}

function decimal(value, positive) {
    if (length(value) < 1 || length(value) > 20 || value !~ /^(0|[1-9][0-9]*)$/) return 0
    return !positive || ("d" value != "d0")
}

function canonical(path) {
    if (path == "/") return 1
    return substr(path, 1, 1) == "/" && substr(path, length(path), 1) != "/" && index(path, "//") == 0 && path !~ /(^|\/)\.\.?($|\/)/
}

function decode(value,    result, position, character, code) {
    result = ""
    for (position = 1; position <= length(value); position++) {
        character = substr(value, position, 1)
        if (character == "\\") {
            code = "e" substr(value, position + 1, 3)
            if (!(code in escape)) fail(1)
            character = escape[code]
            position += 3
        }
        result = result character
    }
    return result
}

function hex(value,    result, position, key) {
    result = ""
    for (position = 1; position <= length(value); position++) {
        key = "b" substr(value, position, 1)
        if (!(key in byte)) fail(1)
        result = result sprintf("%02x", byte[key])
    }
    return result
}

function options(value,    parts, total, position, seen, key) {
    total = split(value, parts, ",")
    if (!total) fail(1)
    for (position = 1; position <= total; position++) {
        if (parts[position] == "") fail(1)
        key = "o" parts[position]
        if (key in seen) fail(1)
        seen[key] = 1
    }
    if (("oro" in seen) && ("orw" in seen)) fail(1)
}

function optional(value,    colon, tag, payload) {
    colon = index(value, ":")
    tag = (colon ? substr(value, 1, colon - 1) : value)
    payload = (colon ? substr(value, colon + 1) : "")
    if (tag !~ /^[A-Za-z0-9_][A-Za-z0-9_.+-]*$/ || (colon && payload !~ /^[!-~]+$/)) fail(1)
    if (("t" tag) in optional_seen) fail(1)
    optional_seen["t" tag] = 1
    if (tag == "shared" || tag == "master" || tag == "propagate_from") {
        if (!colon || !decimal(payload, 1)) fail(1)
        optional_value["t" tag] = payload
    } else if (tag == "unbindable") {
        if (colon) fail(1)
        current_unbindable = 1
    } else current_unknown++
}

function covers(point) {
    return point == "/" || ("p" point == "p" target) || (substr(target, 1, length(point) + 1) == point "/")
}

function parse_line(line,    fields, total, position, separator, pair, root, point, source, key) {
    if (line == "" || line ~ /[[:cntrl:]]/ || substr(line, 1, 1) == " " || substr(line, length(line), 1) == " " || index(line, "  ")) fail(1)
    # Proc mountinfo uses one ASCII space between fields; path whitespace is escaped.
    # Explicit regex avoids awk's special whitespace-collapsing split separator.
    total = split(line, fields, / /)
    if (total < 10) fail(1)
    for (position = 1; position <= total; position++) if (fields[position] == "") fail(1)
    if (!decimal(fields[1], 1) || !decimal(fields[2], 0)) fail(1)
    key = "i" fields[1]
    if (key in ids) fail(1)
    ids[key] = 1
    if (split(fields[3], pair, ":") != 2 || !decimal(pair[1], 0) || !decimal(pair[2], 0)) fail(1)
    root = decode(fields[4])
    point = decode(fields[5])
    if (!canonical(root) || !canonical(point)) fail(1)
    options(fields[6])
    for (key in optional_seen) delete optional_seen[key]
    optional_value["tshared"] = "-"
    optional_value["tmaster"] = "-"
    optional_value["tpropagate_from"] = "-"
    current_unbindable = 0
    current_unknown = 0
    separator = 0
    for (position = 7; position <= total; position++) {
        if (fields[position] == "-") { separator = position; break }
        optional(fields[position])
    }
    if (!separator || total != separator + 3) fail(1)
    if (fields[separator + 1] !~ /^[A-Za-z0-9_][A-Za-z0-9_.+-]*$/) fail(1)
    source = decode(fields[separator + 2])
    options(fields[separator + 3])
    # Count validated records, not visible mountpoints: hidden/duplicate strict
    # descendants still matter. Equal points and prefix-collision siblings do not.
    if ("p" point != "p" target && (target == "/" || substr(point, 1, length(target) + 1) == target "/")) descendants++
    if (covers(point)) {
        key = "m" hex(point)
        # Even a unique deeper child can be hidden by a duplicate ancestor mount.
        if (key in covering) fail(1)
        covering[key] = 1
        if (length(point) > best_length) {
            best_length = length(point)
            best_id = fields[1]
            best_parent = fields[2]
            best_device = fields[3]
            best_root = root
            best_point = point
            best_type = fields[separator + 1]
            best_source = source
            best_options = fields[6]
            best_super = fields[separator + 3]
            best_shared = optional_value["tshared"]
            best_master = optional_value["tmaster"]
            best_propagate_from = optional_value["tpropagate_from"]
            best_unbindable = current_unbindable
            best_unknown = current_unknown
        }
    }
}
