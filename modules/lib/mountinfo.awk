# Read-only parser for /proc/self/mountinfo.
# Usage: LC_ALL=C awk -f modules/lib/mountinfo.awk "$canonical_target" /proc/self/mountinfo
# Subtree usage: awk -f modules/lib/mountinfo.awk subtree-v1 "$canonical_target" INPUT
# Subtree output adds propagation as field 10 and preserves input order. All
# records must validate before either interface emits output.
# The target is a literal ARGV operand so backslashes are not reinterpreted by awk.
# Input is bounded to 4096 records of at most 8192 bytes each. Escapes are decoded
# only in root, mountpoint, and source; tabs, newlines, controls, and unknown
# escapes fail closed. The caller must compare this observation with held FDs and
# persistent storage identity; this parser does not admit or identify storage.

BEGIN {
	MAX_RECORDS = 4096
	MAX_LINE = 8192
	if (ARGV[1] == "subtree-v1") {
		subtree = 1
		target = ARGV[2]
		ARGV[1] = ARGV[2] = ""
	} else {
		target = ARGV[1]
		ARGV[1] = ""
	}
	if (!canonical_path(target)) {
		fail("invalid target")
	}
}

function fail(reason) {
	if (!failed) {
		print "mountinfo: " reason > "/dev/stderr"
		close("/dev/stderr")
	}
	failed = 1
	exit 1
}

function decimal(value, allow_zero) {
	if (length(value) > 10 || value !~ /^(0|[1-9][0-9]*)$/) {
		return 0
	}
	if (!allow_zero && value == "0") {
		return 0
	}
	return 1
}

function canonical_path(value, parts, count, i) {
	if (value == "" || substr(value, 1, 1) != "/" || value ~ /\/\// ||
	    value ~ /[[:cntrl:]]/ || (length(value) > 1 && substr(value, length(value), 1) == "/")) {
		return 0
	}
	if (value == "/") {
		return 1
	}
	count = split(substr(value, 2), parts, "/")
	for (i = 1; i <= count; i++) {
		if (parts[i] == "" || parts[i] == "." || parts[i] == "..") {
			return 0
		}
	}
	return 1
}

function decode(value, result, i, character, escaped) {
	result = ""
	decode_ok = 1
	for (i = 1; i <= length(value); i++) {
		character = substr(value, i, 1)
		if (character != "\\") {
			result = result character
			continue
		}
		escaped = substr(value, i + 1, 3)
		if (escaped == "040") {
			result = result " "
		} else if (escaped == "134") {
			result = result "\\"
		} else {
			decode_ok = 0
			return ""
		}
		i += 3
	}
	return result
}

function path_contains(path, point) {
	if (point == "/") {
		return 1
	}
	return path == point || substr(path, 1, length(point) + 1) == point "/"
}

{
	if (failed) {
		exit 1
	}
	record_count++
	if (record_count > MAX_RECORDS || length($0) > MAX_LINE) {
		fail("input limit exceeded")
	}
	if ($0 == "" || $0 ~ /[[:cntrl:]]/ || substr($0, 1, 1) == " " ||
	    substr($0, length($0), 1) == " ") {
		fail("invalid record")
	}

	field_count = split($0, fields, / /)
	for (field_index = 1; field_index <= field_count; field_index++) {
		if (fields[field_index] == "") {
			fail("invalid record")
		}
	}
	separator = field_count - 3
	if (separator < 7 || fields[separator] != "-") {
		fail("invalid record")
	}
	for (field_index = 7; field_index < separator; field_index++) {
		if (fields[field_index] == "-") {
			fail("invalid separator")
		}
	}
	if (!decimal(fields[1], 0) || !decimal(fields[2], 0) ||
	    fields[3] !~ /^(0|[1-9][0-9]*):(0|[1-9][0-9]*)$/) {
		fail("invalid numeric field")
	}
	if (seen_mount_id[fields[1]]++) {
		fail("duplicate mount id")
	}
	device_count = split(fields[3], device, ":")
	if (device_count != 2 || !decimal(device[1], 1) || !decimal(device[2], 1)) {
		fail("invalid numeric field")
	}

	root = decode(fields[4])
	if (!decode_ok || !canonical_path(root)) {
		fail("invalid path field")
	}
	mountpoint = decode(fields[5])
	if (!decode_ok || !canonical_path(mountpoint)) {
		fail("invalid path field")
	}
	if (fields[6] !~ /^[!-~]+$/ || fields[field_count] !~ /^[!-~]+$/ ||
	    fields[separator + 1] !~ /^[A-Za-z0-9][A-Za-z0-9_+.-]*$/) {
		fail("invalid text field")
	}
	source = decode(fields[separator + 2])
	if (!decode_ok || source == "" || source ~ /[[:cntrl:]]/) {
		fail("invalid source field")
	}

	seen_shared = 0
	seen_master = 0
	seen_propagate_from = 0
	seen_unbindable = 0
	for (field_index = 7; field_index < separator; field_index++) {
		optional = fields[field_index]
		if (optional == "unbindable") {
			if (seen_unbindable++) {
				fail("invalid optional field")
			}
			continue
		}
		if (optional !~ /^(shared|master|propagate_from):[0-9]+$/) {
			fail("invalid optional field")
		}
		colon = index(optional, ":")
		tag = substr(optional, 1, colon - 1)
		group_id = substr(optional, colon + 1)
		if (!decimal(group_id, 0)) {
			fail("invalid optional field")
		}
		if (tag == "shared") {
			shared_group = group_id
			if (seen_shared++) {
				fail("invalid optional field")
			}
		} else if (tag == "master") {
			master_group = group_id
			if (seen_master++) {
				fail("invalid optional field")
			}
		} else if (tag == "propagate_from") {
			propagate_group = group_id
			if (seen_propagate_from++) {
				fail("invalid optional field")
			}
		}
	}
	if (seen_propagate_from && !seen_master) {
		fail("invalid optional field")
	}
	if (subtree && seen_unbindable && (seen_shared || seen_master || seen_propagate_from)) {
		fail("invalid optional field")
	}

	record = fields[1] "\t" fields[2] "\t" fields[3] "\t" root "\t" \
		mountpoint "\t" fields[separator + 1] "\t" source "\t" fields[6] "\t" \
		fields[field_count]
	if (subtree) {
		if (!path_contains(mountpoint, target)) {
			next
		}
		if (seen_subtree_point[mountpoint]++) {
			fail("ambiguous mount")
		}
		propagation = ""
		if (seen_shared) {
			propagation = "shared:" shared_group
		}
		if (seen_master) {
			propagation = propagation (propagation == "" ? "" : ",") "master:" master_group
		}
		if (seen_propagate_from) {
			propagation = propagation (propagation == "" ? "" : ",") "propagate_from:" propagate_group
		}
		if (seen_unbindable) {
			propagation = propagation (propagation == "" ? "" : ",") "unbindable"
		}
		if (propagation == "") {
			propagation = "private"
		}
		subtree_records[++subtree_count] = record "\t" propagation
		next
	}

	if (!path_contains(target, mountpoint)) {
		next
	}
	if (length(mountpoint) > best_length) {
		best_length = length(mountpoint)
		best_count = 1
		best_record = record
	} else if (length(mountpoint) == best_length) {
		best_count++
	}
}

END {
	if (failed) {
		exit 1
	}
	if (subtree) {
		for (record_index = 1; record_index <= subtree_count; record_index++) {
			print subtree_records[record_index]
		}
		exit 0
	}
	if (record_count == 0 || best_count == 0) {
		fail("target not found")
	}
	if (best_count != 1) {
		fail("ambiguous mount")
	}
	print best_record
}
