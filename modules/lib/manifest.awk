# SPDX-License-Identifier: GPL-3.0-or-later
# Bounded declared package inventory. Explicitly load package_path.awk first.
# Caller supplies immutable regular stdin, independently checked byte count,
# LC_ALL=C and no operands. Parsing does not verify source trust or file bytes.
# Consumers must check status, exact framing/footer and output write completion;
# native awk can report success after an output-write failure.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") cfmgr_manifest_invalid_invocation()
    if (cfmgr_manifest_size !~ /^[1-9][0-9]*$/ || length(cfmgr_manifest_size) > 5) cfmgr_manifest_invalid_invocation()
    expected_size = cfmgr_manifest_size + 0
    if (expected_size < 1 || expected_size > 65536) cfmgr_manifest_invalid_invocation()

    # ASCII 28 cannot occur in valid input; retain LF and original byte framing.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected_size) cfmgr_manifest_invalid_data()
    if ((getline extra_record) != 0) cfmgr_manifest_invalid_data()
    if (substr(document, length(document), 1) != "\n") cfmgr_manifest_invalid_data()

    cfmgr_manifest_parse()
    cfmgr_manifest_validate()
    printf "%s", output_body
    printf "%s", output_footer
    exit 0
}

function cfmgr_manifest_invalid_invocation() { exit 2 }
function cfmgr_manifest_invalid_data() { exit 1 }

function cfmgr_manifest_parse(    position, newline, line, split_at, key, value, fields, count, size) {
    position = 1
    while (position <= length(document)) {
        newline = index(substr(document, position), "\n")
        if (!newline) cfmgr_manifest_invalid_data()
        line = substr(document, position, newline - 1)
        if (length(line) > 1024 || line ~ /[^ -~]/) cfmgr_manifest_invalid_data()
        position += newline
        if (line == "" || substr(line, 1, 1) == "#") continue
        split_at = index(line, ": ")
        if (!split_at) cfmgr_manifest_invalid_data()
        key = substr(line, 1, split_at - 1)
        value = substr(line, split_at + 2)
        if (value == "" || substr(value, 1, 1) == " " || substr(value, length(value), 1) == " ") cfmgr_manifest_invalid_data()

        if (key == "manifest" || key == "version" || key == "config-schema" || key == "package-api") {
            if (key in metadata) cfmgr_manifest_invalid_data()
            metadata[key] = value
        } else {
            if (!cfmgr_package_destination_safe(key) || key in destinations) cfmgr_manifest_invalid_data()
            # A literal single-space regex preserves empty fields between spaces.
            count = split(value, fields, / /)
            if (count != 3) cfmgr_manifest_invalid_data()
            if (fields[1] !~ /^[1-9][0-9]*$/ || length(fields[1]) > 7) cfmgr_manifest_invalid_data()
            size = fields[1] + 0
            if (size < 1 || size > 1048576) cfmgr_manifest_invalid_data()
            if (length(fields[2]) != 64 || fields[2] !~ /^[A-Fa-f0-9]+$/) cfmgr_manifest_invalid_data()
            if (fields[3] != "0644" && fields[3] != "0755") cfmgr_manifest_invalid_data()
            if (key == "cfmgr.sh" && fields[3] != "0755") cfmgr_manifest_invalid_data()
            destinations[key] = 1
            file_count++
            if (file_count > 128) cfmgr_manifest_invalid_data()
            total_file_bytes += size
            if (total_file_bytes > 8388608) cfmgr_manifest_invalid_data()
            file_destination[file_count] = key
            file_size[file_count] = fields[1]
            file_hash[file_count] = tolower(fields[2])
            file_mode[file_count] = fields[3]
        }
    }
}

function cfmgr_manifest_version_valid(value,    components, count, position) {
    if (length(value) < 5 || length(value) > 128) return 0
    count = split(value, components, /\./)
    if (count != 3) return 0
    for (position = 1; position <= count; position++) {
        if (components[position] !~ /^(0|[1-9][0-9]*)$/) return 0
    }
    return 1
}

function cfmgr_manifest_validate(    i, j) {
    if (!("manifest" in metadata) || metadata["manifest"] != "1") cfmgr_manifest_invalid_data()
    if (!("version" in metadata) || !cfmgr_manifest_version_valid(metadata["version"])) cfmgr_manifest_invalid_data()
    if (!("config-schema" in metadata) || metadata["config-schema"] != "1") cfmgr_manifest_invalid_data()
    if (!("package-api" in metadata) || metadata["package-api"] != "1") cfmgr_manifest_invalid_data()
    if (file_count < 1 || file_count > 128 || !("cfmgr.sh" in destinations)) cfmgr_manifest_invalid_data()
    for (i = 1; i <= file_count; i++) {
        for (j = 1; j < i; j++) {
            if (cfmgr_package_path_conflicts(file_destination[i], file_destination[j])) cfmgr_manifest_invalid_data()
        }
    }

    output_body = "manifest\t1\n"
    output_body = output_body "version\t" metadata["version"] "\n"
    output_body = output_body "config-schema\t1\npackage-api\t1\n"
    for (i = 1; i <= file_count; i++) {
        output_body = output_body "file\t" file_destination[i] "\t" file_size[i] "\t" file_hash[i] "\t" file_mode[i] "\n"
    }
    output_footer = "end\t" file_count "\t" total_file_bytes "\t" length(output_body) "\n"
    if (length(output_body) + length(output_footer) > 65536) cfmgr_manifest_invalid_data()
}
