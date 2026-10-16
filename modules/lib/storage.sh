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
		"$cfmgr_storage_awk" -f "$cfmgr_storage_parser" \
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

# Backup destinations have their own policy/state. These helpers never select
# Entware, execute a saved pathname, or mutate an unpinned destination.
# FD6 pins the chosen mount and FD7, when present, pins its literal CFBackup.
# shellcheck disable=SC2034,SC2154,SC3013
cfmgr_backup_mount_record() {
	IFS='	' read -r cfmgr_backup_id cfmgr_backup_parent cfmgr_backup_device cfmgr_backup_root \
		cfmgr_backup_mount cfmgr_backup_filesystem cfmgr_backup_device_path cfmgr_backup_options \
		cfmgr_backup_super cfmgr_backup_propagation cfmgr_backup_extra <<EOF_BACKUP_MOUNT
$1
EOF_BACKUP_MOUNT
	[ -z "$cfmgr_backup_extra" ] || return 1
	[ "$cfmgr_backup_root" = / ] || return 1
	case $cfmgr_backup_mount in /tmp/mnt/?*) ;; *) return 1 ;; esac
	_cfmgr_storage_path "$cfmgr_backup_mount" && _cfmgr_storage_path "$cfmgr_backup_root" || return 1
	[ "${#cfmgr_backup_mount}" -le 1024 ] && [ "${#cfmgr_backup_root}" -le 1024 ] || return 1
	[ -d "$cfmgr_backup_mount" ] && [ ! -L "$cfmgr_backup_mount" ] && [ -b "$cfmgr_backup_device_path" ] || return 1
	case ,$cfmgr_backup_options, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_backup_super, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_backup_options, in *,ro,*) return 1 ;; esac
	[ "$("$cfmgr_store_readlink" -f "$cfmgr_backup_mount")" = "$cfmgr_backup_mount" ] || return 1
	cfmgr_backup_snapshot=$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
		"$cfmgr_backup_id" "$cfmgr_backup_parent" "$cfmgr_backup_device" "$cfmgr_backup_root" \
		"$cfmgr_backup_mount" "$cfmgr_backup_filesystem" "$cfmgr_backup_device_path" "$cfmgr_backup_options" "$cfmgr_backup_super")
}

cfmgr_backup_uuid_parse() {
	# Parse one bounded blkid record, preserving filesystem-specific UUID syntax.
	# LABEL is optional display data; it can never become a pathname or command.
	# shellcheck disable=SC2016
	cfmgr_backup_identity=$("$cfmgr_store_awk" '
		BEGIN {source=ARGV[1]; fs=ARGV[2]; ARGV[1]=ARGV[2]=""}
		NR!=1 || length($0)>4096 || $0~/[[:cntrl:]]/ {bad=1; next}
		{
			prefix=source ": "; if(substr($0,1,length(prefix))!=prefix){bad=1;next}
			rest=substr($0,length(prefix)+1)
			while(rest!="") {
				if(!match(rest,/^[A-Z_]+="/)){bad=1;break}
				key=substr(rest,1,RLENGTH-2);rest=substr(rest,RLENGTH+1);stop=index(rest,"\"")
				if(!stop || seen[key]++){bad=1;break};value[key]=substr(rest,1,stop-1);rest=substr(rest,stop+1)
				if(rest==" ")rest="";else if(rest!=""){if(substr(rest,1,1)!=" "){bad=1;break};rest=substr(rest,2)}
			}
		}
		END {
			type=value["TYPE"]; compatible=(!seen["TYPE"] || type==fs)
			if(fs=="vfat" || fs=="tfat") compatible=(type=="vfat")
			if(fs=="ntfs" || fs=="ntfs3" || fs=="tntfs" || fs=="fuseblk") compatible=(type=="ntfs")
			if(fs=="ufsd") compatible=(type=="ntfs" || type=="hfs" || type=="hfsplus")
			if(bad || NR!=1 || !seen["UUID"] || !compatible ||
			length(value["UUID"])>128 || value["UUID"]!~/^[A-Za-z0-9][A-Za-z0-9._:-]*$/ ||
			length(value["LABEL"])>256 || value["LABEL"]~/[^ -~]/)exit 1
			if(type=="vfat" && (length(value["UUID"])!=9 || value["UUID"]!~/^[0-9A-Fa-f]+-[0-9A-Fa-f]+$/ || substr(value["UUID"],5,1)!="-"))exit 1
			if(type=="ntfs" && (length(value["UUID"])!=16 || value["UUID"]!~/^[0-9A-Fa-f]+$/))exit 1
			uuid=value["UUID"];if(uuid~/^[0-9A-Fa-f-]+$/)uuid=tolower(uuid)
			print uuid;print (value["LABEL"]==""?"-":value["LABEL"])
		}' "$cfmgr_backup_device_path" "$cfmgr_backup_filesystem" "$1") || return 1
	{
		IFS= read -r cfmgr_backup_uuid && IFS= read -r cfmgr_backup_label
	} <<EOF_BACKUP_IDENTITY
$cfmgr_backup_identity
EOF_BACKUP_IDENTITY
}

cfmgr_backup_observe_mount() {
	cfmgr_store_run store-backup-mount "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/mountinfo.awk" "$1" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_backup_mount_record "$cfmgr_store_line"
}

cfmgr_backup_observe_uuid() {
	cfmgr_store_run store-backup-blkid /sbin/blkid "$cfmgr_backup_device_path" || return $?
	cfmgr_backup_uuid_parse "$cfmgr_probe_stdout"
}

# Fixed read-only gate: no blkid, store_run, config parsing, or recursive gate.
# shellcheck disable=SC3013
cfmgr_backup_attached() {
	[ "${cfmgr_backup_pinned:-0}" = 1 ] && [ ! -L "$cfmgr_backup_mount" ] &&
		[ "$cfmgr_backup_mount" -ef /proc/self/fd/6 ] || return 1
	[ "$("$cfmgr_store_readlink" -f "$cfmgr_backup_mount")" = "$cfmgr_backup_mount" ] || return 1
	[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_backup_mount" /proc/self/mountinfo)" = "$cfmgr_backup_snapshot" ] || return 1
	cfmgr_backup_fd_mount 6 || return 1
	if [ "${cfmgr_backup_folder_pinned:-0}" = 1 ]; then
		[ ! -L "$cfmgr_backup_mount/CFBackup" ] && [ "$cfmgr_backup_mount/CFBackup" -ef /proc/self/fd/7 ] || return 1
		[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_backup_mount/CFBackup" /proc/self/mountinfo)" = "$cfmgr_backup_snapshot" ] || return 1
		cfmgr_backup_fd_mount 7 || return 1
	fi
}

cfmgr_backup_fd_mount() {
	# shellcheck disable=SC2016
	"$cfmgr_store_awk" 'BEGIN {id=ARGV[1]; ARGV[1]=""} $1=="mnt_id:" {n++;if(NF!=2 || $2!=id)bad=1} END {exit (n!=1 || bad)}' \
		"$cfmgr_backup_id" "/proc/self/fdinfo/$1"
}

cfmgr_backup_pin_selected() {
	cfmgr_backup_observe_mount "$cfmgr_backup_want_mount" || return $?
	[ "$cfmgr_backup_mount:$cfmgr_backup_filesystem:$cfmgr_backup_root" = "$cfmgr_backup_want_mount:$cfmgr_backup_want_filesystem:$cfmgr_backup_want_root" ] &&
		[ "$cfmgr_backup_snapshot" = "$cfmgr_backup_want_snapshot" ] || return 1
	{ exec 6<&3; } 3<"$cfmgr_backup_mount" || return 1
	cfmgr_backup_pinned=1 cfmgr_store_backup_gate=1
	cfmgr_backup_attached || return 1
	cfmgr_backup_observe_uuid || return $?
	[ "$cfmgr_backup_uuid" = "$cfmgr_backup_want_uuid" ] && cfmgr_backup_attached
}

cfmgr_backup_prepare_folder() {
	cfmgr_backup_attached || return 1
	if [ ! -e "$cfmgr_backup_mount/CFBackup" ] && [ ! -L "$cfmgr_backup_mount/CFBackup" ]; then
		cfmgr_store_run store-backup-mkdir /bin/mkdir || return $?
	fi
	cfmgr_backup_folder_admit || return $?
	# Permission emulation failures on FAT/NTFS do not invalidate a real drive.
	if cfmgr_store_run store-backup-chmod /bin/chmod; then :; else
		cfmgr_backup_chmod_code=$?
		[ "$cfmgr_backup_chmod_code" -ne 3 ] || return 3
	fi
	cfmgr_backup_attached
}

cfmgr_backup_folder_admit() {
	cfmgr_backup_attached && [ -d "$cfmgr_backup_mount/CFBackup" ] && [ ! -L "$cfmgr_backup_mount/CFBackup" ] || return 1
	[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_backup_mount/CFBackup" /proc/self/mountinfo)" = "$cfmgr_backup_snapshot" ] || return 1
	{ exec 7<&3; } 3<"$cfmgr_backup_mount/CFBackup" || return 1
	cfmgr_backup_folder_pinned=1
	cfmgr_backup_attached
}
