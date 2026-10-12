#!/bin/sh
# Native flush prerequisite, not a transaction or storage-admission layer.
# The caller must admit the executable and storage, own/exclude mutation of the
# target, and open that regular file or directory read-only on inherited fd 3.
# The caller owns fd 3's lifetime and must supervise/reap the action under its
# storage/ownership guards. Kernel I/O can remain uninterruptible: this function
# provides neither a deadline nor proof of a complete durable publication.
# The admitted native utility must have the reviewed bounded text diagnostics.
# Merlin fsync can return zero after fsync(2) fails; any diagnostic is a failure.
# No filesystem operation occurs when this library is sourced.

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
		"$cfmgr_storage_awk" -f "$cfmgr_storage_parser" \
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
		"$cfmgr_storage_awk" -f "$cfmgr_storage_parser" \
			"$cfmgr_storage_opt" "$cfmgr_storage_proc/mountinfo"
	) || return 1
	[ "$_cfmgr_storage_current" = "$cfmgr_storage_snapshot" ]
}

cfmgr_storage_uuid() {
	# Parse the bounded native blkid result as data. The caller separately proves
	# that the native child succeeded and that the attachment remained unchanged.
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
				if (bad || lines != 1 || !seen["UUID"] || value["TYPE"] != filesystem) exit 1
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
