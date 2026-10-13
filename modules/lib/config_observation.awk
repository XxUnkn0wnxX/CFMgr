# SPDX-License-Identifier: GPL-3.0-or-later
# Subsequent trusted consumer of json.awk tree mode. No file operands; immutable
# private stdin and LC_ALL=C are caller obligations. Only fixed modes use -v;
# observation strings enter through ENVIRON to avoid awk assignment decoding.
# check/observe emit one receipt; patch emits only original/patched JSON bytes.
# Caller must check status, receipt framing and independently measured output.
BEGIN {
    if (!cfmgr_json_tree_ready || cfmgr_json_mode != "tree") reject()
    if (cfmgr_config_mode != "check" && cfmgr_config_mode != "observe" &&
        cfmgr_config_mode != "patch" && cfmgr_config_mode != "scope") reject()

    for (co_i = 2; co_i <= cfmgr_json_tree_count; co_i++)
        co_child[cfmgr_json_tree_parent[co_i], cfmgr_json_tree_location[co_i]] = co_i

    co_type(1, "object")
    co_schema = co_field(1, "schema", "number")
    if (cfmgr_json_tree_payload[co_schema] != "n1") reject()
    co_generation = co_field(1, "generation", "number")
    co_old = substr(cfmgr_json_tree_payload[co_generation], 2)
    if (co_old !~ /^[1-9][0-9]*$/ || length(co_old) > 20) reject()
    co_new = co_old

    co_manager = co_field(1, "manager", "object")
    co_field(co_manager, "check_updates", "boolean")
    co_field(co_manager, "auto_update", "boolean")
    co_field(co_manager, "developer", "boolean")
    co_field(co_manager, "developer_log_directory", "string|null")
    co_source = co_field(co_manager, "source", "object")
    co_field(co_source, "repository", "string")
    co_field(co_source, "branch", "string")
    co_field(co_source, "commit", "string")
    co_storage = co_field(1, "storage", "object")
    co_entware = co_field(co_storage, "entware", "object")
    co_ids[1] = co_field(co_entware, "uuid", "string")
    co_ids[2] = co_field(co_entware, "filesystem", "string")
    co_ids[3] = co_field(co_entware, "root", "string")
    co_ids[4] = co_field(co_entware, "relative", "string")
    for (co_i = 1; co_i <= 4; co_i++)
        co_saved[co_i] = co_decode(substr(cfmgr_json_tree_payload[co_ids[co_i]], 2))
    co_observation_valid(co_saved[1], co_saved[2], co_saved[3], co_saved[4])

    co_features[1] = "ddns"
    co_features[2] = "ip_sync"
    co_features[3] = "cloudflared"
    co_logging = co_field(1, "logging", "object")
    co_history = co_field(1, "history", "object")
    for (co_i = 1; co_i <= 3; co_i++) {
        co_feature = co_field(1, co_features[co_i], "object")
        co_field(co_feature, "configured", "boolean")
        co_field(co_feature, "enabled", "boolean")
        co_log = co_field(co_logging, co_features[co_i], "object")
        co_field(co_log, "configured", "boolean")
        co_field(co_log, "enabled", "boolean")
        co_field(co_log, "opt_out", "boolean")
        co_field(co_log, "policy", "object|string|null")
        co_field(co_history, co_features[co_i], "object|array|string|null")
    }
    co_ddns = co_field(1, "ddns", "object")
    co_field(co_ddns, "credentials", "object|string|null")
    co_field(co_ddns, "records", "array")
    co_field(co_ddns, "proxied", "boolean|null")
    co_sync = co_field(1, "ip_sync", "object")
    co_field(co_sync, "credentials", "object|string|null")
    co_field(co_sync, "targets", "array")
    co_cloud = co_field(1, "cloudflared", "object")
    co_cloud_configured = co_field(co_cloud, "configured", "boolean")
    co_cloud_enabled = co_field(co_cloud, "enabled", "boolean")
    if (cfmgr_json_tree_kind[co_cloud_enabled] == "true" &&
        cfmgr_json_tree_kind[co_cloud_configured] != "true") reject()
    co_field(co_cloud, "installed", "boolean")
    co_field(co_cloud, "maintenance_enabled", "boolean")
    co_field(co_cloud, "binary_auto_update", "boolean|null")
    co_refs = co_field(co_cloud, "credential_refs", "object")
    co_field(co_refs, "runtime", "string|null")
    co_field(co_refs, "management", "string|null")
    co_field(co_refs, "certificate", "string|null")
    co_network = co_field(1, "network", "object")
    co_field(co_network, "address_family", "string")
    co_field(co_network, "selected_wan", "string|number|null")
    co_field(1, "backup", "object")
    co_field(1, "credentials", "object")
    co_field(1, "ownership", "object")

    if (cfmgr_config_mode == "scope") {
        printf "CFMGR-SCOPE 1 %s %s END\n", co_old,
            (cfmgr_json_tree_kind[co_cloud_configured] == "true" ? "tunnel" : "shared")
        exit 0
    }

    co_changed = 0
    co_result = document
    if (cfmgr_config_mode != "check") {
        co_current[1] = ENVIRON["CFMGR_CONFIG_UUID"]
        co_current[2] = ENVIRON["CFMGR_CONFIG_FILESYSTEM"]
        co_current[3] = ENVIRON["CFMGR_CONFIG_ROOT"]
        co_current[4] = ENVIRON["CFMGR_CONFIG_RELATIVE"]
        co_observation_valid(co_current[1], co_current[2], co_current[3], co_current[4])
        for (co_i = 1; co_i <= 4; co_i++) {
            # Encoding also verifies literal environment UTF-8 before any output.
            co_encoded[co_i] = co_quote(co_current[co_i])
            if ("v" co_current[co_i] != "v" co_saved[co_i]) co_changed = 1
        }
        if (co_changed) {
            co_new = co_increment(co_old)
            co_replacement[co_generation] = co_new
            for (co_i = 1; co_i <= 4; co_i++)
                if ("v" co_current[co_i] != "v" co_saved[co_i])
                    co_replacement[co_ids[co_i]] = co_encoded[co_i]
            co_result = ""
            co_cursor = 1
            # Preorder IDs also order these non-overlapping scalar spans.
            for (co_i = 1; co_i <= cfmgr_json_tree_count; co_i++) {
                if (!(co_i in co_replacement)) continue
                co_result = co_result substr(document, co_cursor,
                    cfmgr_json_tree_start[co_i] - co_cursor) co_replacement[co_i]
                co_cursor = cfmgr_json_tree_end[co_i] + 1
            }
            co_result = co_result substr(document, co_cursor)
        }
    }
    if (length(co_result) > 65536) reject()
    if (cfmgr_config_mode == "patch") printf "%s", co_result
    else printf "CFMGR-CONFIG 1 %s %s %d %d %d END\n", co_old, co_new,
        co_changed, expected_size, length(co_result)
    exit 0
}

function co_hex(value,    i, result, character) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        character = substr(value, i, 1)
        if (!("b" character in byte_value)) reject()
        result = result byte_hex[byte_value["b" character]]
    }
    return result
}

function co_type(id, allowed,    kind) {
    if (!id) reject()
    kind = cfmgr_json_tree_kind[id]
    if (kind == "true" || kind == "false") kind = "boolean"
    if (index("|" allowed "|", "|" kind "|") == 0) reject()
    return id
}

function co_field(parent, key, allowed) {
    return co_type(co_child[parent, "k" co_hex(key)], allowed)
}

function co_decode(value,    i, code, result) {
    result = ""
    for (i = 1; i <= length(value); i += 2) {
        code = hex_value["h" substr(value, i, 1)] * 16 + hex_value["h" substr(value, i + 1, 1)]
        # This decoder is only for observation fields, where controls are forbidden.
        if (code < 32 || code == 127) reject()
        result = result sprintf("%c", code)
    }
    return result
}

function co_path(value, absolute,    i, code) {
    if (length(value) == 0 || length(value) > 4096) reject()
    for (i = 1; i <= length(value); i++) {
        code = byte_value["b" substr(value, i, 1)]
        if (code < 32 || code == 127) reject()
    }
    if (index(value, "//") || value ~ /(^|\/)\.\.?\// || value ~ /\/\.\.?$/) reject()
    if (absolute) {
        if (substr(value, 1, 1) != "/" || (value != "/" && value ~ /\/$/)) reject()
    } else {
        if (substr(value, 1, 1) == "/" || value ~ /\/$/ || value == "..") reject()
    }
}

function co_observation_valid(uuid, filesystem, root, relative,    groups, count, i) {
    count = split(uuid, groups, "-")
    if (count != 5 || length(groups[1]) != 8 || length(groups[2]) != 4 ||
        length(groups[3]) != 4 || length(groups[4]) != 4 || length(groups[5]) != 12) reject()
    for (i = 1; i <= 5; i++) if (groups[i] !~ /^[0-9a-fA-F]+$/) reject()
    if (filesystem != "ext2" && filesystem != "ext3" && filesystem != "ext4") reject()
    co_path(root, 1)
    co_path(relative, 0)
}

function co_increment(value,    i, digit_value, carry, result) {
    carry = 1
    result = ""
    for (i = length(value); i >= 1; i--) {
        digit_value = substr(value, i, 1) + carry
        carry = (digit_value == 10)
        if (carry) digit_value = 0
        result = sprintf("%d", digit_value) result
    }
    if (carry) result = "1" result
    if (length(result) > 20) reject()
    return result
}

function co_quote(value,    saved_document, saved_position, result, character, start) {
    saved_document = document
    saved_position = position
    document = value
    position = 1
    result = "\""
    while (position <= length(document)) {
        start = position
        character = peek()
        raw_utf8_hex(character)
        if (character == "\"" || character == "\\") result = result "\\"
        result = result substr(document, start, position - start)
    }
    document = saved_document
    position = saved_position
    return result "\""
}
