# SPDX-License-Identifier: GPL-3.0-or-later
# Bounded source catalog grammar/projection. Caller supplies immutable regular
# stdin, its independently checked byte count, LC_ALL=C, and no operands.
# Explicitly load package_path.awk before this parser with a separate -f.
# This selects data only; it does not establish source trust or package validity.
# Before consuming output, callers must verify parser status, exact framing and
# byte counts; native awk can report success after an output-write failure.

BEGIN {
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") invalid_invocation()
    if (cfmgr_catalog_size !~ /^[1-9][0-9]*$/ || length(cfmgr_catalog_size) > 5) invalid_invocation()
    expected_size = cfmgr_catalog_size + 0
    if (expected_size < 1 || expected_size > 32768) invalid_invocation()

    # ASCII 28 is not valid catalog text. A distinct record separator keeps LF
    # and all other bytes available for exact size and framing checks.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected_size) invalid_data()
    if ((getline extra_record) != 0) invalid_data()
    if (length(document) < 1 || substr(document, length(document), 1) != "\n") invalid_data()

    parse_document()
    validate_catalog()
    emit_catalog()
    exit 0
}

function invalid_invocation() { exit 2 }
function invalid_data() { exit 1 }

function parse_document(    position, newline, line, split_at, key, value, count) {
    position = 1
    while (position <= length(document)) {
        newline = index(substr(document, position), "\n")
        if (!newline) invalid_data()
        line = substr(document, position, newline - 1)
        if (length(line) > 1024 || line ~ /[^ -~]/) invalid_data()
        position += newline
        if (line == "" || substr(line, 1, 1) == "#") continue
        split_at = index(line, ": ")
        if (!split_at) invalid_data()
        key = substr(line, 1, split_at - 1)
        value = substr(line, split_at + 2)
        if (value == "" || substr(value, 1, 1) == " " || substr(value, length(value), 1) == " ") invalid_data()

        if (key == "catalog" || key == "repository" || key == "branch" || key == "manifest") {
            if (key in metadata) invalid_data()
            metadata[key] = value
        } else {
            if (!cfmgr_package_destination_safe(key)) invalid_data()
            if (key in destinations) invalid_data()
            destinations[key] = 1
            file_count++
            if (file_count > 128) invalid_data()
            file_destination[file_count] = key
            file_url[file_count] = value
        }
    }
}

function validate_catalog(    owner, repository, repository_path, repository_parts, i, j, left, right) {
    if (!("catalog" in metadata) || metadata["catalog"] != "1") invalid_data()
    if (!("repository" in metadata) || substr(metadata["repository"], 1, 19) != "https://github.com/") invalid_data()
    repository_path = substr(metadata["repository"], 20)
    if (split(repository_path, repository_parts, "/") != 2) invalid_data()
    owner = repository_parts[1]
    repository = repository_parts[2]
    if (!valid_owner(owner) || !valid_repository(repository)) invalid_data()
    expected_raw_prefix = "https://raw.githubusercontent.com/" owner "/" repository "/{commit}/"

    if (!("branch" in metadata)) invalid_data()
    if (metadata["branch"] != "main" && metadata["branch"] != "develop") {
        if (length(metadata["branch"]) != 40 || metadata["branch"] !~ /^[A-Fa-f0-9]+$/) invalid_data()
        metadata["branch"] = tolower(metadata["branch"])
    }
    if (!("manifest" in metadata) || !raw_url(metadata["manifest"], expected_raw_prefix)) invalid_data()
    if (file_count < 1 || file_count > 128) invalid_data()
    if (!("cfmgr.sh" in destinations)) invalid_data()

    for (i = 1; i <= file_count; i++) {
        if (!raw_url(file_url[i], expected_raw_prefix)) invalid_data()
        left = file_destination[i]
        for (j = 1; j < i; j++) {
            right = file_destination[j]
            if (cfmgr_package_path_conflicts(left, right)) invalid_data()
        }
    }

    output_body = "catalog\t1\n"
    output_body = output_body "repository\t" owner "\t" repository "\n"
    output_body = output_body "branch\t" metadata["branch"] "\n"
    output_body = output_body "manifest\t" metadata["manifest"] "\n"
    for (i = 1; i <= file_count; i++) output_body = output_body "file\t" file_destination[i] "\t" file_url[i] "\n"
    output_footer = "end\t" file_count "\t" length(output_body) "\n"
    if (length(output_body) + length(output_footer) > 65536) invalid_data()
}

function raw_url(url, prefix,    path) {
    if (substr(url, 1, length(prefix)) != prefix) return 0
    path = substr(url, length(prefix) + 1)
    return cfmgr_package_path_safe(path)
}

function valid_owner(value,    last) {
    if (length(value) < 1 || length(value) > 39 || value !~ /^[A-Za-z0-9][A-Za-z0-9-]*$/) return 0
    last = substr(value, length(value), 1)
    return last ~ /^[A-Za-z0-9]$/
}

function valid_repository(value) {
    return length(value) >= 1 && length(value) <= 100 && value ~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/
}

function emit_catalog() {
    printf "%s", output_body
    printf "%s", output_footer
}
