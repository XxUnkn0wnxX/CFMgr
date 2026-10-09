# SPDX-License-Identifier: GPL-3.0-or-later
# Functions only: explicitly load before the catalog or manifest parser.
# These source-relative paths do not establish installed-file ownership.

function cfmgr_package_path_safe(path,    parts, count, position) {
    if (length(path) < 1 || length(path) > 240) return 0
    if (substr(path, 1, 1) == "/" || substr(path, length(path), 1) == "/" || index(path, "//")) return 0
    count = split(path, parts, "/")
    if (count < 1) return 0
    for (position = 1; position <= count; position++) {
        if (length(parts[position]) < 1 || length(parts[position]) > 100) return 0
        if (parts[position] !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/) return 0
    }
    return 1
}

function cfmgr_package_destination_safe(path) {
    if (!cfmgr_package_path_safe(path)) return 0
    if (path != "cfmgr.sh" && substr(path, 1, 8) != "modules/") return 0
    if (path == "modules/config" || substr(path, 1, 15) == "modules/config/" ||
        path == "modules/catalog.txt" || substr(path, 1, 20) == "modules/catalog.txt/") return 0
    return 1
}

function cfmgr_package_path_conflicts(left, right) {
    return (left "") == (right "") || substr(left, 1, length(right) + 1) == right "/" ||
        substr(right, 1, length(left) + 1) == left "/"
}
