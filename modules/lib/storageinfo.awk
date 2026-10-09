# SPDX-License-Identifier: GPL-3.0-or-later
# Observation parsing only, not mounted-volume, UUID or writability authority.
# Caller supplies LC_ALL=C, literal known mode, independently verified canonical
# size, and a private stable bounded REGULAR file on stdin. No filename operands.
# Device paths use ENVIRON, avoiding awk -v escape interpretation. Acquisition,
# supervision and live identity checks belong to the caller. Consumers verify
# producer status, body bytes, terminal footer and exact EOF before using data;
# native awk can report success after a failed output write.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") fail(2)
    if (cfmgr_storageinfo_mode != "fdinfo" && cfmgr_storageinfo_mode != "blkid" &&
        cfmgr_storageinfo_mode != "blockdev" && cfmgr_storageinfo_mode != "exthex" &&
        cfmgr_storageinfo_mode != "charnull" && cfmgr_storageinfo_mode != "charurandom") fail(2)
    if (cfmgr_storageinfo_size !~ /^(0|[1-9][0-9]*)$/ || length(cfmgr_storageinfo_size) > 4) fail(2)
    expected = cfmgr_storageinfo_size + 0
    if (expected > 4096) fail(2)
    if (cfmgr_storageinfo_mode == "blkid") {
        device = ENVIRON["CFMGR_BLKID_DEVICE"]
        if (length(device) > 256 || device !~ /^\/dev\/.+/ || device ~ /[[:cntrl:]]/ ||
            substr(device, length(device), 1) == "/" || index(device, "//") ||
            device ~ /(^|\/)\.\.?($|\/)/) fail(2)
        for (i = 1; i <= 255; i++) byte["b" sprintf("%c", i)] = i
    }

    RS = sprintf("%c", 28)
    record = getline document
    if (expected == 0) {
        if (record != 0) fail(1)
        document = ""
    } else {
        if (record != 1 || length(document) != expected) fail(1)
        if ((getline extra) != 0) fail(1)
    }

    if (cfmgr_storageinfo_mode == "fdinfo") body = fdinfo(document)
    else if (cfmgr_storageinfo_mode == "blkid") body = blkid(document)
    else if (cfmgr_storageinfo_mode == "blockdev") body = blockdev(document)
    else if (cfmgr_storageinfo_mode == "charnull" || cfmgr_storageinfo_mode == "charurandom")
        body = chardev(document, cfmgr_storageinfo_mode)
    else body = exthex(document)
    footer = sprintf("end\t%d\n", length(body))
    if (length(body) + length(footer) > 4096) fail(1)
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

function fdinfo(document,    start, remaining, end, count, line, colon, key, value, seen, mount_id) {
    if (document == "" || substr(document, length(document), 1) != "\n") fail(1)
    start = 1
    count = 0
    while (start <= length(document)) {
        remaining = substr(document, start)
        end = index(remaining, "\n")
        if (!end || ++count > 64) fail(1)
        line = substr(remaining, 1, end - 1)
        colon = index(line, ":")
        if (!colon) fail(1)
        key = substr(line, 1, colon - 1)
        if (key !~ /^[A-Za-z_][A-Za-z0-9_]*$/) fail(1)
        value = substr(line, colon + 1)
        if (value !~ /^[ \t]/) fail(1)
        sub(/^[ \t]+/, "", value)
        if (value !~ /^[\t -~]+$/ || (("k" key) in seen)) fail(1)
        seen["k" key] = 1
        if (key == "pos") {
            if (!decimal(value, 0)) fail(1)
        } else if (key == "flags") {
            if (length(value) > 16 || value !~ /^[0-7]+$/) fail(1)
        } else if (key == "mnt_id") {
            if (!decimal(value, 1)) fail(1)
            mount_id = value
        }
        start += end
    }
    if (!("kpos" in seen) || !("kflags" in seen)) fail(1)
    if (!("kmnt_id" in seen)) fail(3)
    return "fdinfo\t" mount_id "\n"
}

# Native BusyBox emits attributes in LABEL, UUID, TYPE order without escaping
# label quotes. Even valid LABEL-bearing text can impersonate a UUID attribute;
# validate its grammar, then return3 without identity. Label-free observations
# remain facts only and require independent retained-volume approval later.
function blkid(document,    line, prefix, rest, key, value, quote, rank, previous, seen, uuid, type) {
    if (document == "") fail(3)
    if (substr(document, length(document), 1) != "\n") fail(1)
    line = substr(document, 1, length(document) - 1)
    if (line ~ /[[:cntrl:]]/) fail(1)
    prefix = device ": "
    if (substr(line, 1, length(prefix)) != prefix) fail(1)
    rest = substr(line, length(prefix) + 1)
    if (rest == "") fail(1)
    previous = 0
    while (rest != "") {
        if (match(rest, /^(LABEL|UUID|TYPE)="/) != 1) fail(1)
        key = substr(rest, 1, RLENGTH - 2)
        rest = substr(rest, RLENGTH + 1)
        quote = index(rest, "\"")
        if (!quote) fail(1)
        value = substr(rest, 1, quote - 1)
        rest = substr(rest, quote + 1)
        rank = (key == "LABEL" ? 1 : (key == "UUID" ? 2 : 3))
        if (rank <= previous || (("a" key) in seen)) fail(1)
        seen["a" key] = 1
        previous = rank
        if (key == "UUID") {
            if (length(value) < 1 || length(value) > 128 || value !~ /^[A-Fa-f0-9-]+$/) fail(1)
            uuid = value
        } else if (key == "TYPE") {
            if (length(value) < 1 || length(value) > 64 || value !~ /^[A-Za-z0-9_][A-Za-z0-9_.+-]*$/) fail(1)
            type = value
        }
        if (rest != "") {
            if (substr(rest, 1, 1) != " " || length(rest) == 1 || substr(rest, 2, 1) == " ") fail(1)
            rest = substr(rest, 2)
        }
    }
    if (("aLABEL" in seen) || !("aUUID" in seen)) fail(3)
    return "blkid\t" hex(uuid) "\t" (("aTYPE" in seen) ? hex(type) : "-") "\n"
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

# Selected LC_C BusyBox ls -dnL profile: mode, links, numeric owner/group,
# major-comma, minor, English month, day, HH:MM or four-digit year, fixed FD path.
# A matching ten-field non-block device record has unavailable identity (status3).
# Other layouts, including nine-field regular files, are malformed (status1).
function blockdev(document,    line, fields, count, major, minor, stamp, pair) {
    if (document == "" || substr(document, length(document), 1) != "\n") fail(1)
    line = substr(document, 1, length(document) - 1)
    if (line ~ /[[:cntrl:]]/ || substr(line, 1, 1) == " " || substr(line, length(line), 1) == " ") fail(1)
    count = split(line, fields, / +/)
    if (count != 10 || fields[10] != "/proc/self/fd/8") fail(1)
    if (fields[1] !~ /^[bcdlps-][r-][w-][xsS-][r-][w-][xsS-][r-][w-][xtT-]$/ ||
        !decimal(fields[2], 1) || !decimal(fields[3], 0) || !decimal(fields[4], 0)) fail(1)
    if (fields[5] !~ /^[0-9]+,$/) fail(1)
    major = normalize(substr(fields[5], 1, length(fields[5]) - 1))
    minor = normalize(fields[6])
    if (fields[7] !~ /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$/ ||
        !decimal(fields[8], 1) || length(fields[8]) > 2 || fields[8] + 0 > 31) fail(1)
    stamp = fields[9]
    if (stamp ~ /^[0-9][0-9]:[0-9][0-9]$/) {
        split(stamp, pair, ":")
        if (pair[1] + 0 > 23 || pair[2] + 0 > 59) fail(1)
    } else if (stamp !~ /^[0-9][0-9][0-9][0-9]$/ || stamp == "0000") fail(1)
    if (substr(fields[1], 1, 1) != "b") fail(3)
    return "blockdev\t" major ":" minor "\n"
}

function normalize(value) {
    if (value !~ /^[0-9]+$/ || length(value) > 20) fail(1)
    sub(/^0+/, "", value)
    return (value == "" ? "0" : value)
}

# Exact first1152 device bytes, hex in original byte order. Unsupported magic,
# non-dynamic revision or all-zero UUID returns3; malformed acquisition returns1.
function exthex(document,    uuid) {
    if (length(document) != 2304 || document !~ /^[0-9a-f]+$/) fail(1)
    if ("m" substr(document, 2161, 4) != "m53ef" || "r" substr(document, 2201, 8) != "r01000000") fail(3)
    uuid = substr(document, 2257, 32)
    if ("u" uuid == "u00000000000000000000000000000000") fail(3)
    return "exthex\t" substr(uuid, 1, 8) "-" substr(uuid, 9, 4) "-" substr(uuid, 13, 4) "-" substr(uuid, 17, 4) "-" substr(uuid, 21, 12) "\n"
}

# Fixed owned-device ls -dni profile, from a private image/dev cwd. Preserve
# inode text exactly; floating-point conversion cannot identify a 20-digit inode.
function chardev(document, mode,    line, fields, count, stamp, pair, name, minor) {
    if (document == "" || substr(document, length(document), 1) != "\n") fail(1)
    line = substr(document, 1, length(document) - 1)
    if (line ~ /[[:cntrl:]]/ || substr(line, length(line), 1) == " ") fail(1)
    sub(/^ +/, "", line)
    count = split(line, fields, / +/)
    name = (mode == "charnull" ? "null" : "urandom")
    minor = (mode == "charnull" ? "3" : "9")
    if (count != 11 || !decimal(fields[1], 1) || fields[2] != "crw-------" ||
        fields[3] != "1" || fields[4] != "0" || fields[5] != "0" ||
        fields[6] != "1," || fields[7] != minor || fields[11] != name) fail(1)
    if (fields[8] !~ /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$/ ||
        !decimal(fields[9], 1) || length(fields[9]) > 2 || fields[9] + 0 > 31) fail(1)
    stamp = fields[10]
    if (stamp ~ /^[0-9][0-9]:[0-9][0-9]$/) {
        split(stamp, pair, ":")
        if (pair[1] + 0 > 23 || pair[2] + 0 > 59) fail(1)
    } else if (stamp !~ /^[0-9][0-9][0-9][0-9]$/ || stamp == "0000") fail(1)
    return mode "\t" fields[1] "\n"
}
