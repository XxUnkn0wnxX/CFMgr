#!/bin/sh
# Category owner: storage. Sourcing defines functions only.

# ---- storage ----
# Native flush prerequisite, not a transaction or storage-admission layer.
# The caller must admit the executable and storage, own/exclude mutation of the
# target, and open that regular file or directory read-only on inherited fd 3.
# The caller owns fd 3's lifetime and must supervise/reap the action under its
# storage/ownership guards. Kernel I/O can remain uninterruptible: this function
# provides neither a deadline nor proof of a complete durable publication.
# The admitted native utility must have the reviewed bounded text diagnostics.
# Merlin fsync can return zero after fsync(2) fails; any diagnostic is a failure.
# No filesystem operation occurs when this library is sourced.
# shellcheck disable=SC2034,SC2154 # Fixed backup/Store imports and exported identity fields.

cfmgr_storage_flush_fd() (
	[ "$#" -eq 1 ] || return 2
	case $1 in
	/*) ;;
	*) return 2 ;;
	esac
	[ -f "$1" ] && [ -x "$1" ] || return 2
	# Validate inheritance without opening a pathname or changing the descriptor.
	(: <&3) 2>/dev/null || return 2
	# The fixed operand bounds native errno diagnostics. Appending the marker
	# inside substitution preserves even newline-only output, which command
	# substitution would otherwise trim. It is appended only after exit zero.
	cfmgr_flush_result=$(
		{
			LC_ALL=C LANGUAGE='' "$1" /proc/self/fd/3 &&
				printf '%s' 'CFMGR_FLUSH_OK_v1'
		} 2>&1
	) || return 1
	[ "$cfmgr_flush_result" = 'CFMGR_FLUSH_OK_v1' ] || return 1
)

# Native attachment observation for the prerequisite/installation controller.
# The controller reserves descriptors 6/7, supplies trusted native tools/code,
# and independently obtains/checks the persistent filesystem UUID. A mountinfo
# snapshot alone is NOT persistent volume identity or writable-storage admission.
# These functions never create files, mount/unmount, or select a substitute volume.

_cfmgr_storage_path() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 4096 ] || return 1
	case $1 in
	/*) ;;
	*) return 1 ;;
	esac
	case $1 in
	*[!\ -~]* | *//* | */./* | */../* | */. | */..) return 1 ;;
	/) ;;
	*/) return 1 ;;
	esac
}

_cfmgr_storage_canonical() {
	_cfmgr_storage_path "$1" || return 1
	_cfmgr_storage_resolved=$(
		"$cfmgr_storage_readlink" -f "$1" && printf '\n.'
	) || return 1
	# Preserve newlines until validation; plain command substitution could turn an
	# unsafe newline-bearing pathname into a different, apparently safe pathname.
	case $_cfmgr_storage_resolved in
	*'

.') _cfmgr_storage_resolved=${_cfmgr_storage_resolved%'

.'} ;;
	*) return 1 ;;
	esac
	_cfmgr_storage_path "$_cfmgr_storage_resolved" || return 1
	printf '%s\n' "$_cfmgr_storage_resolved"
}

_cfmgr_storage_mount_id() {
	# The dollar expressions are AWK fields, not shell expansions.
	# shellcheck disable=SC2016
	"$cfmgr_storage_awk" '
		$1 == "mnt_id:" {
			n++
			if (NF != 2 || $2 !~ /^[1-9][0-9]*$/) bad=1
			value=$2
		}
		END { if (n != 1 || bad) exit 1; print value }
	' "$cfmgr_storage_proc/fdinfo/$1"
}

cfmgr_storage_release() {
	# Only the controller owning the reserved descriptors may call this function.
	exec 6<&- 7<&-
	cfmgr_storage_pinned=0
}

# Outputs include the mount/volume-relative fields used by the controller.
# shellcheck disable=SC2034
cfmgr_storage_pin() {
	# OPT_ALIAS READLINK AWK MOUNTINFO_PARSER PROC_SELF_DIR
	# Arguments are internal controller inputs, never an environment override.
	[ "$#" -eq 5 ] || return 2
	cfmgr_storage_pinned=0
	for _cfmgr_storage_argument; do
		_cfmgr_storage_path "$_cfmgr_storage_argument" || return 2
	done
	cfmgr_storage_alias=$1
	cfmgr_storage_readlink=$2
	cfmgr_storage_awk=$3
	cfmgr_storage_parser=$4
	cfmgr_storage_proc=$5
	[ -f "$cfmgr_storage_readlink" ] && [ -x "$cfmgr_storage_readlink" ] &&
		[ -f "$cfmgr_storage_awk" ] && [ -x "$cfmgr_storage_awk" ] &&
		[ -f "$cfmgr_storage_parser" ] && [ ! -L "$cfmgr_storage_parser" ] || return 2
	cfmgr_storage_opt=$(_cfmgr_storage_canonical "$cfmgr_storage_alias") || return 1
	[ -d "$cfmgr_storage_opt" ] && [ ! -L "$cfmgr_storage_opt" ] || return 1
	cfmgr_storage_snapshot=$(
		cfmgr_storage_mountinfo "$cfmgr_storage_awk" \
			"$cfmgr_storage_opt" "$cfmgr_storage_proc/mountinfo"
	) || return 1
	IFS='	' read -r cfmgr_storage_mount_id cfmgr_storage_parent_id \
		cfmgr_storage_device cfmgr_storage_fsroot cfmgr_storage_mount \
		cfmgr_storage_filesystem cfmgr_storage_source cfmgr_storage_options \
		cfmgr_storage_superoptions <<EOF
$cfmgr_storage_snapshot
EOF
	# These initial capability profiles admit Linux ext filesystems. A bind mount
	# retains its filesystem-root component for the persistent identity check.
	case $cfmgr_storage_filesystem in ext2 | ext3 | ext4) ;; *) return 1 ;; esac
	[ -b "$cfmgr_storage_source" ] || return 1
	case ,$cfmgr_storage_options, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_storage_options, in *,noexec,* | *,ro,*) return 1 ;; esac
	case ,$cfmgr_storage_superoptions, in *,rw,*) ;; *) return 1 ;; esac
	[ "$(_cfmgr_storage_canonical "$cfmgr_storage_mount")" = "$cfmgr_storage_mount" ] || return 1
	exec 6<"$cfmgr_storage_mount" || return 1
	if ! exec 7<"$cfmgr_storage_opt"; then
		exec 6<&-
		return 1
	fi
	cfmgr_storage_pinned=1
	if ! cfmgr_storage_attached; then
		cfmgr_storage_release
		return 1
	fi
	if [ "$cfmgr_storage_opt" = "$cfmgr_storage_mount" ]; then
		cfmgr_storage_relative=.
	else
		cfmgr_storage_relative=${cfmgr_storage_opt#"$cfmgr_storage_mount"/}
	fi
}

# Native BusyBox test -ef is verified by the descriptor and kernel fixtures.
# shellcheck disable=SC3013
cfmgr_storage_attached() {
	[ "${cfmgr_storage_pinned:-0}" = 1 ] || return 1
	[ -d "$cfmgr_storage_opt" ] && [ -d "$cfmgr_storage_mount" ] &&
		[ ! -L "$cfmgr_storage_opt" ] && [ ! -L "$cfmgr_storage_mount" ] &&
		[ "$cfmgr_storage_opt" -ef "$cfmgr_storage_proc/fd/7" ] &&
		[ "$cfmgr_storage_mount" -ef "$cfmgr_storage_proc/fd/6" ] || return 1
	[ "$(_cfmgr_storage_canonical "$cfmgr_storage_alias")" = "$cfmgr_storage_opt" ] || return 1
	[ "$(_cfmgr_storage_mount_id 6)" = "$cfmgr_storage_mount_id" ] &&
		[ "$(_cfmgr_storage_mount_id 7)" = "$cfmgr_storage_mount_id" ] || return 1
	_cfmgr_storage_current=$(
		cfmgr_storage_mountinfo "$cfmgr_storage_awk" \
			"$cfmgr_storage_opt" "$cfmgr_storage_proc/mountinfo"
	) || return 1
	[ "$_cfmgr_storage_current" = "$cfmgr_storage_snapshot" ]
}

cfmgr_storage_uuid() {
	# Parse the bounded native blkid result as data. The caller separately proves
	# that the native child succeeded and that the attachment remained unchanged.
	# Merlin's native blkid can omit TYPE; mountinfo already supplies the admitted
	# filesystem. If blkid also supplies TYPE, it must agree with that observation.
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || return 2
	cfmgr_storage_uuid_value=$(
		# AWK consumes literal operands, avoiding -v escape interpretation.
		# shellcheck disable=SC2016
		"$cfmgr_storage_awk" '
			BEGIN { source=ARGV[1]; filesystem=ARGV[2]; ARGV[1]=""; ARGV[2]="" }
			{
				if (++lines != 1 || length($0) > 4096 || $0 ~ /[[:cntrl:]]/) { bad=1; next }
				prefix=source ": "
				if (substr($0,1,length(prefix)) != prefix) { bad=1; next }
				rest=substr($0,length(prefix)+1)
				while (rest != "") {
					if (!match(rest,/^[A-Z_]+="/)) { bad=1; break }
					key=substr(rest,1,RLENGTH-2)
					rest=substr(rest,RLENGTH+1)
					end=index(rest,"\"")
					if (!end || seen[key]++) { bad=1; break }
					value[key]=substr(rest,1,end-1)
					rest=substr(rest,end+1)
					if (rest == " ") rest=""
					else if (rest != "") {
						if (substr(rest,1,1) != " ") { bad=1; break }
						rest=substr(rest,2)
					}
				}
			}
			END {
				if (bad || lines != 1 || !seen["UUID"] || (seen["TYPE"] && value["TYPE"] != filesystem)) exit 1
				uuid=value["UUID"]
				if (length(uuid) != 36 || uuid ~ /[^0-9A-Fa-f-]/ ||
				    substr(uuid,9,1) != "-" || substr(uuid,14,1) != "-" ||
				    substr(uuid,19,1) != "-" || substr(uuid,24,1) != "-") exit 1
				gsub(/-/,"",uuid)
				if (length(uuid) != 32) exit 1
				print tolower(value["UUID"])
			}
		' "$cfmgr_storage_source" "$cfmgr_storage_filesystem" "$1"
	) || return 1
	[ -n "$cfmgr_storage_uuid_value" ]
}

cfmgr_storage_awk_mountinfo() {
	# CFMGR-AWK-BEGIN mountinfo
	cfmgr_awk_program='
# Read-only parser for /proc/self/mountinfo.
# Invocation: cfmgr_storage_mountinfo "$native_awk" "$canonical_target" /proc/self/mountinfo
# Subtree: cfmgr_storage_mountinfo "$native_awk" subtree-v1 "$canonical_target" INPUT
# Batch: cfmgr_storage_mountinfo "$native_awk" targets-v1 TARGET... INPUT
# inventory-v1 uses the same operands/output but retains stacked mountpoints.
# Subtree output adds propagation as field 10 and preserves input order. All
# records must validate before any interface emits output.
# The target is a literal ARGV operand so backslashes are not reinterpreted by awk.
# Input is bounded to 4096 records of at most 8192 bytes each. Escapes are decoded
# only in root, mountpoint, and source; tabs, newlines, controls, and unknown
# escapes fail closed. The caller must compare this observation with held FDs and
# persistent storage identity; this parser does not admit or identify storage.

BEGIN {
	MAX_RECORDS = 4096
	MAX_LINE = 8192
	if (ARGV[1] == "targets-v1") {
		target_mode = 1
		target_count = ARGC - 3
		if (target_count < 1 || target_count > 6) {
			fail("invalid target count")
		}
		ARGV[1] = ""
		for (target_index = 1; target_index <= target_count; target_index++) {
			targets[target_index] = ARGV[target_index + 1]
			ARGV[target_index + 1] = ""
			if (!canonical_path(targets[target_index])) {
				fail("invalid target")
			}
		}
	} else if (ARGV[1] == "subtree-v1" || ARGV[1] == "inventory-v1") {
		stack_inventory = (ARGV[1] == "inventory-v1")
		subtree = 1
		target = ARGV[2]
		ARGV[1] = ARGV[2] = ""
	} else {
		target = ARGV[1]
		ARGV[1] = ""
	}
	if (!target_mode && !canonical_path(target)) {
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
	if (index(value, "\\") == 0) {
		return value
	}
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
		if (seen_subtree_point[mountpoint]++ && !stack_inventory) {
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
	if (target_mode) {
		for (target_index = 1; target_index <= target_count; target_index++) {
			if (!path_contains(targets[target_index], mountpoint)) {
				continue
			}
			if (length(mountpoint) > target_best_length[target_index]) {
				target_best_length[target_index] = length(mountpoint)
				target_best_count[target_index] = 1
				target_best_record[target_index] = record
			} else if (length(mountpoint) == target_best_length[target_index]) {
				target_best_count[target_index]++
			}
		}
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
	if (target_mode) {
		for (target_index = 1; target_index <= target_count; target_index++) {
			if (target_best_count[target_index] == 0) {
				fail("target not found")
			}
			if (target_best_count[target_index] != 1) {
				fail("ambiguous mount")
			}
		}
		for (target_index = 1; target_index <= target_count; target_index++) {
			print target_best_record[target_index]
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
'
	# CFMGR-AWK-END mountinfo
}

# Fixed mount parser invocation using this already-admitted category.
cfmgr_storage_mountinfo() {
	cfmgr_storage_parser_tool=$1
	shift
	cfmgr_storage_awk_mountinfo
	"$cfmgr_storage_parser_tool" "$cfmgr_awk_program" "$@"
}

# ---- Native filesystem admission probes ----
cfmgr_native_mode() {
	cfmgr_native_step mutation-metadata install-ls "$1" || return $?
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	IFS=' ' read -r cfmgr_native_mode cfmgr_native_links cfmgr_native_uid cfmgr_native_gid cfmgr_native_rest <"$cfmgr_native_output" || return 1
	[ "$cfmgr_native_mode" = "$2" ]
}

cfmgr_native_mutations() {
	# Finite names, exclusively claimed before use; no native/JFFS host writes.
	(
		umask 077
		set -C
		printf 'original\n' >"$cfmgr_native_context/native.source" &&
			printf 'retained\n' >"$cfmgr_native_context/native.destination"
	) || return 1
	cfmgr_native_step mutation-mkdir install-mkdir-private "$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_dir_owned=1
	cfmgr_native_mode "$cfmgr_native_context/native.directory" drwx------ || return $?
	cfmgr_native_step mutation-rmdir native-rmdir "$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_dir_owned=0
	cfmgr_native_step mutation-mkdir install-mkdir-public "$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_dir_owned=1
	cfmgr_native_mode "$cfmgr_native_context/native.directory" drwxr-xr-x || return $?
	cfmgr_native_step mutation-copy install-copy "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.copy" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_step mutation-rename install-rename "$cfmgr_native_context/native.copy" "$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	IFS= read -r cfmgr_native_text <"$cfmgr_native_context/native.destination" || return 1
	[ "$cfmgr_native_text" = original ] && [ ! -e "$cfmgr_native_context/native.copy" ] || return 1
	cfmgr_native_step mutation-publish install-publish "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	[ -f "$cfmgr_native_context/native.source" ] && [ ! -L "$cfmgr_native_context/native.source" ] || return 1
	printf 'retained\n' >"$cfmgr_native_context/native.destination" || return 1
	cfmgr_native_step mutation-publish install-publish "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	IFS= read -r cfmgr_native_text <"$cfmgr_native_context/native.destination" || return 1
	[ "$cfmgr_native_text" = retained ] && [ -f "$cfmgr_native_context/native.source" ] || return 1
	cfmgr_native_step mutation-publish install-publish "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.published" || return $?
	cfmgr_native_zero || return 1
	IFS= read -r cfmgr_native_text <"$cfmgr_native_context/native.published" || return 1
	[ "$cfmgr_native_text" = original ] && [ ! -e "$cfmgr_native_context/native.source" ] || return 1
	for cfmgr_native_permission in private readonly executable; do
		cfmgr_native_step mutation-chmod "install-chmod-$cfmgr_native_permission" "$cfmgr_native_context/native.destination" || return $?
		cfmgr_native_zero || return 1
		case $cfmgr_native_permission in private) cfmgr_native_expected=-rw------- ;; readonly) cfmgr_native_expected=-rw-r--r-- ;; executable) cfmgr_native_expected=-rwxr-xr-x ;; esac
		cfmgr_native_mode "$cfmgr_native_context/native.destination" "$cfmgr_native_expected" || return $?
	done
	# FD3 is free before prerequisite flock/view work. Borrow it for the same
	# fsync probe used by the installer, including native errno/diagnostics.
	cfmgr_native_step mutation-flush install-flush 3<"$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_step mutation-flush install-flush 3<"$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
}

cfmgr_native_cleanup() {
	# Only the exclusively claimed empty scratch directory needs removal. Flat
	# regular evidence remains for the controller's existing bounded cleanup.
	if [ -e "$cfmgr_native_context/native.directory" ] || [ -L "$cfmgr_native_context/native.directory" ]; then
		[ "$cfmgr_native_dir_owned" = 1 ] && [ -d "$cfmgr_native_context/native.directory" ] && [ ! -L "$cfmgr_native_context/native.directory" ] || return 3
		cfmgr_native_step cleanup native-rmdir "$cfmgr_native_context/native.directory" || return $?
		cfmgr_native_zero || return 3
	fi
}
