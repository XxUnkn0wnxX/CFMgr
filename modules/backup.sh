#!/bin/sh
# Category owner: backup. Sourcing defines functions only.

# ---- backup ----
# Source-inert backup destination backend. Trusted entry imports storage, Store
# and execution categories explicitly. Destination operations grant no restore
# or Entware mutation authority.
#
# API: cfmgr_backup_action list | check | recover |
#      save MOUNT_HEX UUID_HEX FILESYSTEM_HEX ROOT_HEX SNAPSHOT_HEX
# list/check are read-only. Save is explicit reviewed selection, even for one
# drive; its snapshot comes from that action's list row, never saved config.
# Exactly one header comes first, then optional DEST, then COUNT DRIVE records:
# CFMGR-BACKUP 1 RESULT GENERATION PENDING AVAILABILITY COUNT END
# CFMGR-BACKUP-DEST 1 MOUNT_HEX UUID_HEX FILESYSTEM_HEX ROOT_HEX END
# CFMGR-BACKUP-DRIVE 1 INDEX LABEL_HEX MOUNT_HEX UUID_HEX FS_HEX ROOT_HEX SNAPSHOT_HEX END
# COUNT is 0..32, indices contiguous from1. Lowercase hex contains complete byte
# strings, never evaluated. Public decode accepts printable ASCII, <=1024 bytes;
# snapshots additionally permit tabs and <=8192 bytes (internal use only).
# status0: list/checked/saved/unchanged/recovered; availability none/available/unavailable.
# status1: unavailable/busy/recovery; status3: unresolved. Failures emit only a
# header (generation0/count0/availability unavailable); pending is truthful.
# Invalid API arguments return2 without a frame. A failed Save may have prepared
# an inert CFBackup folder; contents are preserved, never rolled back/deleted.
# The subshell owns FD0/3/4/5/8/9 via Store and reserves FD6/7 for backup only.
# shellcheck disable=SC2030,SC2031,SC2034,SC2154,SC3013

cfmgr_backup_unhex() {
	[ "$#" -eq 2 ] || return 2
	case $1 in '' | *[!0-9a-f]*) return 1 ;; esac
	[ "$((${#1} % 2))" = 0 ] && [ "${#1}" -le 16384 ] || return 1
	cfmgr_backup_decoded=$(CFMGR_BACKUP_ENCODED=$1 CFMGR_BACKUP_ENCODING=$2 /usr/bin/awk '
		BEGIN {
			digits="0123456789abcdef"; s=ENVIRON["CFMGR_BACKUP_ENCODED"]; mode=ENVIRON["CFMGR_BACKUP_ENCODING"]
			if(mode!="text" && mode!="snapshot")exit 1
			if(mode=="text" && length(s)>2048)exit 1
			for(i=1;i<=length(s);i+=2){n=(index(digits,substr(s,i,1))-1)*16+index(digits,substr(s,i+1,1))-1
				if((n<32 || n>126) && !(mode=="snapshot" && n==9))exit 1
				out=out sprintf("%c",n)}
			printf "%s",out
		}') || return 1
}

cfmgr_backup_decode() (
	[ "$#" -eq 1 ] && cfmgr_backup_unhex "$1" text || return 1
	printf '%s\n' "$cfmgr_backup_decoded"
)

cfmgr_backup_hex() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 8192 ] || return 1
	CFMGR_BACKUP_TEXT=$1 /usr/bin/awk 'BEGIN {
		for(i=9;i<=126;i++)byte[sprintf("%c",i)]=i
		s=ENVIRON["CFMGR_BACKUP_TEXT"]
		for(i=1;i<=length(s);i++){c=substr(s,i,1);if(!(c in byte) || (byte[c]<32 && byte[c]!=9))exit 1;out=out sprintf("%02x",byte[c])}
		printf "%s",out
	}'
}

cfmgr_backup_action() (
	case ${1:-}:$# in list:1 | check:1 | recover:1 | save:6) ;; *) exit 2 ;; esac
	cfmgr_backup_operation=$1
	if [ "$1" = save ]; then
		cfmgr_backup_unhex "$2" text || exit 2
		cfmgr_backup_want_mount=$cfmgr_backup_decoded
		cfmgr_backup_unhex "$3" text || exit 2
		cfmgr_backup_want_uuid=$cfmgr_backup_decoded
		cfmgr_backup_unhex "$4" text || exit 2
		cfmgr_backup_want_filesystem=$cfmgr_backup_decoded
		cfmgr_backup_unhex "$5" text || exit 2
		cfmgr_backup_want_root=$cfmgr_backup_decoded
		cfmgr_backup_unhex "$6" snapshot || exit 2
		cfmgr_backup_want_snapshot=$cfmgr_backup_decoded
	fi
	cfmgr_store_result=unavailable cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0
	cfmgr_store_context='' cfmgr_probe_pid='' cfmgr_probe_status=invalid
	cfmgr_store_pending=0 cfmgr_config_lock_fd0=0 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0 cfmgr_store_flock_entware=0
	cfmgr_store_scope=backup cfmgr_store_backup_gate=0 cfmgr_backup_pinned=0 cfmgr_backup_folder_pinned=0
	cfmgr_backup_result=unavailable cfmgr_backup_availability=unavailable cfmgr_backup_count=0 cfmgr_backup_saved_present=0
	if cfmgr_store_prepare && cfmgr_backup_work; then cfmgr_backup_code=0; else cfmgr_backup_code=$?; fi
	# No new probes or descriptor replacement if the supervisor lost ownership.
	if [ "$cfmgr_backup_code" = 3 ] || { [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; }; then
		cfmgr_backup_code=3 cfmgr_backup_result=unresolved cfmgr_store_pending=1
	else
		# Drive loss must never prevent native RAM cleanup. Disable only after
		# quiescence; JFFS recovery is independently handled by the public Store.
		cfmgr_store_backup_gate=0
		exec 0<&- 6<&- 7<&-
		cfmgr_config_lock_fd0=0 cfmgr_store_interrupt=0
		if [ -n "${cfmgr_store_context:-}" ] && ! cfmgr_store_cleanup; then
			cfmgr_backup_result=recovery cfmgr_backup_code=1 cfmgr_store_pending=1
		fi
	fi
	if [ "$cfmgr_backup_code" != 0 ]; then
		case $cfmgr_backup_result in saved | unchanged | recovered | list | checked) cfmgr_backup_result=unavailable ;; esac
		cfmgr_backup_count=0 cfmgr_backup_saved_present=0 cfmgr_store_generation=0 cfmgr_backup_availability=unavailable
		[ "$cfmgr_backup_code" != 4 ] || cfmgr_backup_code=1
	fi
	printf 'CFMGR-BACKUP 1 %s %s %s %s %s END\n' "$cfmgr_backup_result" "$cfmgr_store_generation" "$cfmgr_store_pending" "$cfmgr_backup_availability" "$cfmgr_backup_count"
	if [ "$cfmgr_backup_saved_present" = 1 ]; then
		printf 'CFMGR-BACKUP-DEST 1 %s %s %s %s END\n' "$cfmgr_backup_saved_mount_hex" "$cfmgr_backup_saved_uuid_hex" "$cfmgr_backup_saved_filesystem_hex" "$cfmgr_backup_saved_root_hex"
	fi
	# Context cleanup has already run: completed rows remain only in this bounded
	# shell variable. Never emit partial list output from a failed action.
	[ "$cfmgr_backup_count" = 0 ] || printf '%s\n' "$cfmgr_backup_rows"
	exit "$cfmgr_backup_code"
)

cfmgr_backup_work() {
	if [ "$cfmgr_backup_operation" = recover ]; then
		cfmgr_store_operation=recover cfmgr_store_mask=both cfmgr_store_want_check=0 cfmgr_store_want_auto=0
		if cfmgr_store_work; then :; else
			cfmgr_backup_recover_code=$? cfmgr_backup_result=$cfmgr_store_result
			return "$cfmgr_backup_recover_code"
		fi
		cfmgr_backup_result=$cfmgr_store_result
		cfmgr_store_backup_read || return $?
		cfmgr_backup_availability=none
		[ "$cfmgr_backup_saved_present" = 0 ] || cfmgr_backup_availability=unavailable
		return 0
	fi
	cfmgr_store_pending
	if cfmgr_store_setup_ok; then :; else
		[ "$?" != 3 ] || return 3
		cfmgr_store_pending=1
	fi
	cfmgr_store_backup_read || return $?
	case $cfmgr_backup_operation in
	list)
		cfmgr_backup_list && cfmgr_backup_check_saved || return $?
		cfmgr_backup_result=list
		;;
	check)
		cfmgr_backup_check_saved || return $?
		cfmgr_backup_result=checked
		;;
	save)
		[ "$cfmgr_store_pending" = 0 ] || {
			cfmgr_backup_result=recovery
			return 1
		}
		cfmgr_store_native_tool /sbin/blkid && cfmgr_store_native_tool /bin/chmod || return 1
		cfmgr_backup_pin_selected || return $?
		if cfmgr_store_backup_save; then :; else
			cfmgr_backup_save_code=$?
			case $cfmgr_store_result in busy | recovery) cfmgr_backup_result=$cfmgr_store_result ;; esac
			return "$cfmgr_backup_save_code"
		fi
		cfmgr_backup_result=$cfmgr_store_result cfmgr_backup_availability=available
		cfmgr_store_backup_read || return $?
		;;
	esac
}

cfmgr_backup_list() {
	cfmgr_store_native_tool /sbin/blkid || return 1
	cfmgr_store_run store-backup-mounts "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/storage.sh" /tmp/mnt || return $?
	cfmgr_backup_inventory=$cfmgr_probe_stdout cfmgr_backup_rows='' cfmgr_backup_scanned=0
	cfmgr_backup_availability=none
	[ "$cfmgr_backup_saved_present" = 0 ] || cfmgr_backup_availability=unavailable
	# FD0 may later hold the config lock; avoid redirecting it for enumeration.
	while IFS= read -r cfmgr_backup_record <&3; do
		cfmgr_backup_scanned=$((cfmgr_backup_scanned + 1))
		[ "$cfmgr_backup_scanned" -le 64 ] || return 1
		if cfmgr_backup_mount_record "$cfmgr_backup_record"; then :; else continue; fi
		cfmgr_backup_list_snapshot=$cfmgr_backup_snapshot
		if cfmgr_backup_observe_uuid; then :; else
			cfmgr_backup_list_code=$?
			[ "$cfmgr_backup_list_code" != 3 ] || return 3
			cfmgr_prerequisites_now && [ "$cfmgr_probe_now" -lt "$cfmgr_store_deadline" ] || return 1
			continue
		fi
		cfmgr_backup_list_uuid=$cfmgr_backup_uuid cfmgr_backup_list_label=$cfmgr_backup_label
		cfmgr_backup_observe_mount "$cfmgr_backup_mount" || return $?
		[ "$cfmgr_backup_snapshot" = "$cfmgr_backup_list_snapshot" ] || return 1
		cfmgr_backup_count=$((cfmgr_backup_count + 1))
		[ "$cfmgr_backup_count" -le 32 ] || return 1
		cfmgr_backup_list_mount_hex=$(cfmgr_backup_hex "$cfmgr_backup_mount") &&
			cfmgr_backup_list_uuid_hex=$(cfmgr_backup_hex "$cfmgr_backup_list_uuid") &&
			cfmgr_backup_list_fs_hex=$(cfmgr_backup_hex "$cfmgr_backup_filesystem") &&
			cfmgr_backup_list_root_hex=$(cfmgr_backup_hex "$cfmgr_backup_root") &&
			cfmgr_backup_list_label_hex=$(cfmgr_backup_hex "$cfmgr_backup_list_label") &&
			cfmgr_backup_list_snapshot_hex=$(cfmgr_backup_hex "$cfmgr_backup_snapshot") || return 1
		if [ "$cfmgr_backup_saved_present" = 1 ] &&
			[ "$cfmgr_backup_saved_mount_hex" = "$cfmgr_backup_list_mount_hex" ] &&
			[ "$cfmgr_backup_saved_uuid_hex" = "$cfmgr_backup_list_uuid_hex" ] &&
			[ "$cfmgr_backup_saved_filesystem_hex" = "$cfmgr_backup_list_fs_hex" ] &&
			[ "$cfmgr_backup_saved_root_hex" = "$cfmgr_backup_list_root_hex" ]; then cfmgr_backup_availability=available; fi
		cfmgr_backup_row="CFMGR-BACKUP-DRIVE 1 $cfmgr_backup_count $cfmgr_backup_list_label_hex $cfmgr_backup_list_mount_hex $cfmgr_backup_list_uuid_hex $cfmgr_backup_list_fs_hex $cfmgr_backup_list_root_hex $cfmgr_backup_list_snapshot_hex END"
		if [ "$cfmgr_backup_count" = 1 ]; then cfmgr_backup_rows=$cfmgr_backup_row; else cfmgr_backup_rows="$cfmgr_backup_rows
$cfmgr_backup_row"; fi
	done 3<"$cfmgr_backup_inventory"
}

cfmgr_backup_check_saved() {
	cfmgr_backup_availability=none
	[ "$cfmgr_backup_saved_present" = 1 ] || return 0
	cfmgr_backup_availability=unavailable
	cfmgr_store_native_tool /sbin/blkid || return 0
	cfmgr_backup_want_mount=$(cfmgr_backup_decode "$cfmgr_backup_saved_mount_hex") &&
		cfmgr_backup_want_uuid=$(cfmgr_backup_decode "$cfmgr_backup_saved_uuid_hex") &&
		cfmgr_backup_want_filesystem=$(cfmgr_backup_decode "$cfmgr_backup_saved_filesystem_hex") &&
		cfmgr_backup_want_root=$(cfmgr_backup_decode "$cfmgr_backup_saved_root_hex") || return 1
	if cfmgr_backup_observe_mount "$cfmgr_backup_want_mount"; then :; else
		[ "$?" != 3 ] || return 3
		return 0
	fi
	cfmgr_backup_want_snapshot=$cfmgr_backup_snapshot
	if cfmgr_backup_pin_selected && cfmgr_backup_folder_admit; then cfmgr_backup_availability=available; else [ "$?" != 3 ] || return 3; fi
	return 0
}

cfmgr_backup_ui_hex() {
	[ "$#" -eq 2 ] || return 1
	case $1 in '' | *[!0-9a-f]*) return 1 ;; esac
	[ "$((${#1} % 2))" = 0 ] && [ "${#1}" -le "$2" ]
}

cfmgr_backup_ui_uint() {
	[ "$#" -eq 2 ] || return 1
	case $1 in 0 | [1-9]*) ;; *) return 1 ;; esac
	case $1 in *[!0-9]*) return 1 ;; esac
	[ "${#1}" -le "$2" ]
}

cfmgr_backup_ui_parse_frame() {
	[ "${#cfmgr_backup_ui_raw}" -le 1048576 ] || return 1
	cfmgr_backup_ui_header=0 cfmgr_backup_ui_dest=0 cfmgr_backup_ui_count=0
	cfmgr_backup_ui_rows='' cfmgr_backup_ui_exit='' cfmgr_backup_ui_sentinel=0
	cfmgr_backup_ui_lines=0 cfmgr_backup_ui_dest_mount='' cfmgr_backup_ui_dest_uuid=''
	cfmgr_backup_ui_dest_filesystem='' cfmgr_backup_ui_dest_root=''
	while IFS= read -r cfmgr_backup_ui_line; do
		cfmgr_backup_ui_lines=$((cfmgr_backup_ui_lines + 1))
		[ "$cfmgr_backup_ui_lines" -le 35 ] || return 1
		case $cfmgr_backup_ui_line in
		'CFMGR-BACKUP-EXIT '*)
			[ "$cfmgr_backup_ui_sentinel" = 0 ] || return 1
			IFS=' ' read -r cfmgr_backup_ui_tag cfmgr_backup_ui_exit cfmgr_backup_ui_extra <<EOF_BACKUP_EXIT
$cfmgr_backup_ui_line
EOF_BACKUP_EXIT
			[ "$cfmgr_backup_ui_line" = "CFMGR-BACKUP-EXIT $cfmgr_backup_ui_exit" ] && [ -z "$cfmgr_backup_ui_extra" ] || return 1
			case $cfmgr_backup_ui_exit in 0 | 1 | 3) ;; *) return 1 ;; esac
			cfmgr_backup_ui_sentinel=1
			;;
		*)
			[ "$cfmgr_backup_ui_sentinel" = 0 ] || return 1
			if [ "$cfmgr_backup_ui_header" = 0 ]; then
				IFS=' ' read -r cfmgr_backup_ui_tag cfmgr_backup_ui_schema cfmgr_backup_ui_result \
					cfmgr_backup_ui_generation cfmgr_backup_ui_pending cfmgr_backup_ui_availability \
					cfmgr_backup_ui_expected_count cfmgr_backup_ui_end cfmgr_backup_ui_extra <<EOF_BACKUP_HEADER
$cfmgr_backup_ui_line
EOF_BACKUP_HEADER
				[ "$cfmgr_backup_ui_line" = "CFMGR-BACKUP 1 $cfmgr_backup_ui_result $cfmgr_backup_ui_generation $cfmgr_backup_ui_pending $cfmgr_backup_ui_availability $cfmgr_backup_ui_expected_count END" ] || return 1
				cfmgr_backup_ui_uint "$cfmgr_backup_ui_generation" 20 && cfmgr_backup_ui_uint "$cfmgr_backup_ui_expected_count" 2 || return 1
				case $cfmgr_backup_ui_expected_count in 0 | [1-9] | [12][0-9] | 3[0-2]) ;; *) return 1 ;; esac
				case $cfmgr_backup_ui_pending in 0 | 1) ;; *) return 1 ;; esac
				case $cfmgr_backup_ui_availability in none | available | unavailable) ;; *) return 1 ;; esac
				[ "$cfmgr_backup_ui_result" != unresolved ] || [ "$cfmgr_backup_ui_pending" = 1 ] || return 1
				cfmgr_backup_ui_header=1
			elif [ "${cfmgr_backup_ui_line%% *}" = CFMGR-BACKUP-DEST ]; then
				[ "$cfmgr_backup_ui_dest" = 0 ] && [ "$cfmgr_backup_ui_count" = 0 ] || return 1
				IFS=' ' read -r cfmgr_backup_ui_tag cfmgr_backup_ui_schema cfmgr_backup_ui_mount_hex \
					cfmgr_backup_ui_uuid_hex cfmgr_backup_ui_filesystem_hex cfmgr_backup_ui_root_hex \
					cfmgr_backup_ui_end cfmgr_backup_ui_extra <<EOF_BACKUP_DEST
$cfmgr_backup_ui_line
EOF_BACKUP_DEST
				[ "$cfmgr_backup_ui_line" = "CFMGR-BACKUP-DEST 1 $cfmgr_backup_ui_mount_hex $cfmgr_backup_ui_uuid_hex $cfmgr_backup_ui_filesystem_hex $cfmgr_backup_ui_root_hex END" ] || return 1
				cfmgr_backup_ui_hex "$cfmgr_backup_ui_mount_hex" 2048 && cfmgr_backup_ui_hex "$cfmgr_backup_ui_uuid_hex" 2048 &&
					cfmgr_backup_ui_hex "$cfmgr_backup_ui_filesystem_hex" 2048 && cfmgr_backup_ui_hex "$cfmgr_backup_ui_root_hex" 2048 || return 1
				cfmgr_backup_ui_dest_mount=$(cfmgr_backup_decode "$cfmgr_backup_ui_mount_hex") &&
					cfmgr_backup_ui_dest_uuid=$(cfmgr_backup_decode "$cfmgr_backup_ui_uuid_hex") &&
					cfmgr_backup_ui_dest_filesystem=$(cfmgr_backup_decode "$cfmgr_backup_ui_filesystem_hex") &&
					cfmgr_backup_ui_dest_root=$(cfmgr_backup_decode "$cfmgr_backup_ui_root_hex") || return 1
				case $cfmgr_backup_ui_dest_mount in /tmp/mnt/?*) ;; *) return 1 ;; esac
				[ "$cfmgr_backup_ui_dest_root" = / ] || return 1
				cfmgr_backup_ui_dest=1
			else
				[ "${cfmgr_backup_ui_line%% *}" = CFMGR-BACKUP-DRIVE ] || return 1
				cfmgr_backup_ui_count=$((cfmgr_backup_ui_count + 1))
				[ "$cfmgr_backup_ui_count" -le 32 ] || return 1
				IFS=' ' read -r cfmgr_backup_ui_tag cfmgr_backup_ui_schema cfmgr_backup_ui_index \
					cfmgr_backup_ui_label_hex cfmgr_backup_ui_mount_hex cfmgr_backup_ui_uuid_hex \
					cfmgr_backup_ui_filesystem_hex cfmgr_backup_ui_root_hex cfmgr_backup_ui_snapshot_hex \
					cfmgr_backup_ui_end cfmgr_backup_ui_extra <<EOF_BACKUP_DRIVE
$cfmgr_backup_ui_line
EOF_BACKUP_DRIVE
				[ "$cfmgr_backup_ui_line" = "CFMGR-BACKUP-DRIVE 1 $cfmgr_backup_ui_index $cfmgr_backup_ui_label_hex $cfmgr_backup_ui_mount_hex $cfmgr_backup_ui_uuid_hex $cfmgr_backup_ui_filesystem_hex $cfmgr_backup_ui_root_hex $cfmgr_backup_ui_snapshot_hex END" ] || return 1
				[ "$cfmgr_backup_ui_index" = "$cfmgr_backup_ui_count" ] || return 1
				cfmgr_backup_ui_hex "$cfmgr_backup_ui_label_hex" 2048 && cfmgr_backup_ui_hex "$cfmgr_backup_ui_mount_hex" 2048 &&
					cfmgr_backup_ui_hex "$cfmgr_backup_ui_uuid_hex" 2048 && cfmgr_backup_ui_hex "$cfmgr_backup_ui_filesystem_hex" 2048 &&
					cfmgr_backup_ui_hex "$cfmgr_backup_ui_root_hex" 2048 && cfmgr_backup_ui_hex "$cfmgr_backup_ui_snapshot_hex" 16384 || return 1
				cfmgr_backup_ui_label=$(cfmgr_backup_decode "$cfmgr_backup_ui_label_hex") &&
					cfmgr_backup_ui_mount=$(cfmgr_backup_decode "$cfmgr_backup_ui_mount_hex") &&
					cfmgr_backup_ui_uuid=$(cfmgr_backup_decode "$cfmgr_backup_ui_uuid_hex") &&
					cfmgr_backup_ui_filesystem=$(cfmgr_backup_decode "$cfmgr_backup_ui_filesystem_hex") &&
					cfmgr_backup_ui_root=$(cfmgr_backup_decode "$cfmgr_backup_ui_root_hex") || return 1
				case $cfmgr_backup_ui_mount in /tmp/mnt/?*) ;; *) return 1 ;; esac
				[ "$cfmgr_backup_ui_root" = / ] || return 1
				cfmgr_backup_unhex "$cfmgr_backup_ui_snapshot_hex" snapshot || return 1
				if [ -z "$cfmgr_backup_ui_rows" ]; then cfmgr_backup_ui_rows=$cfmgr_backup_ui_line; else
					cfmgr_backup_ui_rows="$cfmgr_backup_ui_rows
$cfmgr_backup_ui_line"
				fi
			fi
			;;
		esac
	done <<EOF_BACKUP_FRAME
$cfmgr_backup_ui_raw
EOF_BACKUP_FRAME
	[ "$cfmgr_backup_ui_header:$cfmgr_backup_ui_sentinel:$cfmgr_backup_ui_count" = "1:1:$cfmgr_backup_ui_expected_count" ] || return 1
	case $cfmgr_backup_ui_action_name:$cfmgr_backup_ui_exit:$cfmgr_backup_ui_result in
	list:0:list | check:0:checked | save:0:saved | save:0:unchanged | recover:0:recovered | recover:0:unchanged | \
		list:1:unavailable | check:1:unavailable | save:1:unavailable | recover:1:unavailable | \
		list:1:busy | check:1:busy | save:1:busy | recover:1:busy | \
		list:1:recovery | check:1:recovery | save:1:recovery | recover:1:recovery | \
		list:3:unresolved | check:3:unresolved | save:3:unresolved | recover:3:unresolved) ;;
	*) return 1 ;;
	esac
	if [ "$cfmgr_backup_ui_exit" != 0 ]; then
		[ "$cfmgr_backup_ui_generation:$cfmgr_backup_ui_expected_count:$cfmgr_backup_ui_availability:$cfmgr_backup_ui_dest:$cfmgr_backup_ui_count" = 0:0:unavailable:0:0 ] || return 1
		cfmgr_backup_ui_known=0
	else
		cfmgr_backup_ui_known=1
		[ "$cfmgr_backup_ui_generation" != 0 ] || return 1
	fi
	if [ "$cfmgr_backup_ui_exit" = 0 ]; then
		case $cfmgr_backup_ui_availability:$cfmgr_backup_ui_dest in available:1 | none:0 | unavailable:1) ;; *) return 1 ;; esac
	fi
	case $cfmgr_backup_ui_action_name:$cfmgr_backup_ui_exit in
	check:0)
		[ "$cfmgr_backup_ui_count" = 0 ] || return 1
		;;
	save:0)
		[ "$cfmgr_backup_ui_dest:$cfmgr_backup_ui_availability:$cfmgr_backup_ui_pending:$cfmgr_backup_ui_count" = 1:available:0:0 ] || return 1
		;;
	recover:0)
		[ "$cfmgr_backup_ui_pending:$cfmgr_backup_ui_count" = 0:0 ] || return 1
		;;
	*) ;;
	esac
}

cfmgr_backup_ui_action() {
	cfmgr_backup_ui_action_name=$1
	cfmgr_backup_ui_raw=$(
		cfmgr_backup_action "$@"
		cfmgr_backup_ui_action_exit=$?
		printf 'CFMGR-BACKUP-EXIT %s\n' "$cfmgr_backup_ui_action_exit"
	)
	if cfmgr_backup_ui_parse_frame; then :; else
		printf '[CFMGR] backup: error: invalid backend result; destination state is unknown\n' >&2
		return 2
	fi
}

cfmgr_backup_ui_report() {
	case $cfmgr_backup_ui_result in
	busy) printf '[CFMGR] backup: warning: storage or settings lock is busy\n' >&2 ;;
	unavailable) printf '[CFMGR] backup: warning: backup storage or saved destination is unavailable\n' >&2 ;;
	recovery) printf '[CFMGR] backup: warning: pending recovery must be completed before Save\n' >&2 ;;
	unresolved) printf '[CFMGR] backup: error: operation is unresolved; leaving Backup / Restore\n' >&2 ;;
	esac
}

cfmgr_backup_ui_show_state() {
	if [ "${cfmgr_backup_ui_known:-1}" = 0 ]; then
		printf '%s\n' 'Saved destination: unknown (backend unavailable)' 'Backup drives: unavailable'
	else
		if [ "$cfmgr_backup_ui_dest" = 1 ]; then
			case $cfmgr_backup_ui_availability in
			available) printf 'Saved destination: %s/CFBackup (available)\n' "$cfmgr_backup_ui_dest_mount" ;;
			*) printf 'Saved destination: %s/CFBackup (unavailable)\n' "$cfmgr_backup_ui_dest_mount" ;;
			esac
		else printf '%s\n' 'Saved destination: unset'; fi
		if [ "$cfmgr_backup_ui_count" = 0 ]; then
			printf '%s\n' 'Backup drives: none available'
		else
			printf 'Backup drives: %s available\n' "$cfmgr_backup_ui_count"
		fi
	fi
	[ "$cfmgr_backup_ui_pending" != 1 ] || printf '%s\n' 'Pending recovery: yes'
	[ -z "$cfmgr_backup_ui_staged_mount" ] || printf 'Staged selection: %s\n' "$cfmgr_backup_ui_staged_mount"
}

cfmgr_backup_ui_refresh() {
	if cfmgr_backup_ui_action list; then :; else return 2; fi
	cfmgr_backup_ui_report
	[ "$cfmgr_backup_ui_exit" != 3 ] || return 3
}

cfmgr_backup_ui_post_operation() {
	cfmgr_backup_ui_report
	[ "$cfmgr_backup_ui_exit" != 3 ] || return 3
	cfmgr_backup_ui_staged_row='' cfmgr_backup_ui_staged_mount=''
	cfmgr_backup_ui_refresh
}

cfmgr_backup_ui_drive_fields() {
	IFS=' ' read -r cfmgr_backup_ui_tag cfmgr_backup_ui_schema cfmgr_backup_ui_index \
		cfmgr_backup_ui_label_hex cfmgr_backup_ui_mount_hex cfmgr_backup_ui_uuid_hex \
		cfmgr_backup_ui_filesystem_hex cfmgr_backup_ui_root_hex cfmgr_backup_ui_snapshot_hex \
		cfmgr_backup_ui_end cfmgr_backup_ui_extra <<EOF_BACKUP_DRIVE_FIELDS
$1
EOF_BACKUP_DRIVE_FIELDS
	cfmgr_backup_ui_label=$(cfmgr_backup_decode "$cfmgr_backup_ui_label_hex") &&
		cfmgr_backup_ui_mount=$(cfmgr_backup_decode "$cfmgr_backup_ui_mount_hex")
}

cfmgr_backup_ui_select_drive() {
	if [ "$cfmgr_backup_ui_count" = 0 ]; then
		printf '%s\n' 'No backup drives are available.'
		return 0
	fi
	printf '%s\n' 'Backup drives:'
	while IFS= read -r cfmgr_backup_ui_drive_row; do
		cfmgr_backup_ui_drive_fields "$cfmgr_backup_ui_drive_row" || return 1
		printf '%s) %s | %s\n' "$cfmgr_backup_ui_index" "$cfmgr_backup_ui_label" "$cfmgr_backup_ui_mount"
	done <<EOF_BACKUP_DRIVE_LIST
$cfmgr_backup_ui_rows
EOF_BACKUP_DRIVE_LIST
	printf '%s' 'Drive number (or e to cancel): '
	if IFS= read -r cfmgr_backup_ui_choice; then :; else
		cfmgr_backup_ui_leave=1
		return 0
	fi
	[ "$cfmgr_backup_ui_choice" != e ] || return 0
	case $cfmgr_backup_ui_choice in '' | *[!0-9]*)
		printf '%s\n' 'Invalid drive selection.'
		return 0
		;;
	esac
	while IFS= read -r cfmgr_backup_ui_drive_row; do
		cfmgr_backup_ui_drive_fields "$cfmgr_backup_ui_drive_row" || return 1
		if [ "$cfmgr_backup_ui_index" = "$cfmgr_backup_ui_choice" ]; then
			cfmgr_backup_ui_staged_row=$cfmgr_backup_ui_drive_row
			cfmgr_backup_ui_staged_mount=$cfmgr_backup_ui_mount
			printf 'Staged selection: %s | %s\n' "$cfmgr_backup_ui_label" "$cfmgr_backup_ui_mount"
			return 0
		fi
	done <<EOF_BACKUP_DRIVE_SELECT
$cfmgr_backup_ui_rows
EOF_BACKUP_DRIVE_SELECT
	printf '%s\n' 'Invalid drive selection.'
}

cfmgr_backup_ui_save() {
	[ -n "$cfmgr_backup_ui_staged_row" ] || {
		printf '%s\n' 'Select a backup drive before saving a destination.'
		return 0
	}
	cfmgr_backup_ui_drive_fields "$cfmgr_backup_ui_staged_row" || return 1
	cfmgr_backup_ui_save_path=$cfmgr_backup_ui_mount/CFBackup
	printf 'Prepare %s and save this destination? Existing contents are preserved. [y/N/e] ' "$cfmgr_backup_ui_save_path"
	if IFS= read -r cfmgr_backup_ui_answer; then :; else
		cfmgr_backup_ui_leave=1
		return 0
	fi
	case $cfmgr_backup_ui_answer in y | Y | yes | YES) ;; e) return 0 ;; *)
		printf '%s\n' 'Save cancelled; no changes were written.'
		return 0
		;;
	esac
	if cfmgr_backup_ui_action save "$cfmgr_backup_ui_mount_hex" "$cfmgr_backup_ui_uuid_hex" \
		"$cfmgr_backup_ui_filesystem_hex" "$cfmgr_backup_ui_root_hex" "$cfmgr_backup_ui_snapshot_hex"; then :; else return 2; fi
	if [ "$cfmgr_backup_ui_exit" = 0 ]; then
		printf 'Destination saved: %s/CFBackup\n' "$cfmgr_backup_ui_dest_mount"
	else
		printf '%s\n' 'Save did not complete; CFBackup may have been prepared and existing contents were preserved.' >&2
	fi
	cfmgr_backup_ui_post_operation
}

cfmgr_backup_ui_recover() {
	[ "$cfmgr_backup_ui_pending" = 1 ] || return 0
	printf '%s' 'Recover the previous Save? No backup drive is needed. [y/N/e] '
	if IFS= read -r cfmgr_backup_ui_answer; then :; else
		cfmgr_backup_ui_leave=1
		return 0
	fi
	case $cfmgr_backup_ui_answer in y | Y | yes | YES) ;; e) return 0 ;; *)
		printf '%s\n' 'Recovery cancelled; no changes were written.'
		return 0
		;;
	esac
	if cfmgr_backup_ui_action recover; then :; else return 2; fi
	if [ "$cfmgr_backup_ui_exit" = 0 ]; then printf '%s\n' 'Previous Save recovered; no settings were replayed.'; fi
	cfmgr_backup_ui_post_operation
}

cfmgr_backup_menu() {
	cfmgr_backup_ui_staged_row='' cfmgr_backup_ui_staged_mount='' cfmgr_backup_ui_leave=0
	if cfmgr_backup_ui_refresh; then :; else
		cfmgr_backup_ui_refresh_code=$?
		return 0
	fi
	if cfmgr_backup_archive_ui_read; then :; else
		cfmgr_backup_archive_read_code=$?
		[ "$cfmgr_backup_archive_read_code" != 3 ] || return 0
	fi
	while [ "$cfmgr_backup_ui_leave" = 0 ]; do
		printf '%s\n' 'Backup / Restore: manual archive and destination management'
		cfmgr_backup_ui_show_state
		printf '%s\n' '1 Select backup drive' '2 Create archive' '3 Archive preferences' 's Save destination' 'e Back'
		[ "$cfmgr_backup_ui_pending" != 1 ] || printf '%s\n' 'r Recover previous Save'
		if [ "${cfmgr_archive_ui_preferences_known:-0}" = 1 ]; then
			if { [ "$cfmgr_archive_ui_format" != - ] || [ "$cfmgr_archive_ui_keep" != 0 ]; }; then
				printf 'Archive preferences: %s date order, retain %s archives\n' "$cfmgr_archive_ui_format" "$cfmgr_archive_ui_keep"
			else printf '%s\n' 'Archive preferences: unset (choose date order and retention)'; fi
		else printf '%s\n' 'Archive preferences: unknown'; fi
		IFS= read -r cfmgr_backup_ui_choice || return 0
		case $cfmgr_backup_ui_choice in
		1)
			if cfmgr_backup_ui_select_drive; then :; else cfmgr_backup_ui_leave=1; fi
			;;
		s)
			if cfmgr_backup_ui_save; then :; else
				cfmgr_backup_ui_operation_code=$?
				[ "$cfmgr_backup_ui_operation_code" != 3 ] || return 0
				[ "$cfmgr_backup_ui_operation_code" != 2 ] || return 0
			fi
			;;
		r)
			if cfmgr_backup_ui_recover; then :; else
				cfmgr_backup_ui_operation_code=$?
				[ "$cfmgr_backup_ui_operation_code" != 3 ] || return 0
				[ "$cfmgr_backup_ui_operation_code" != 2 ] || return 0
			fi
			;;
		2)
			if cfmgr_backup_archive_create; then :; else
				cfmgr_backup_archive_code=$?
				[ "$cfmgr_backup_archive_code" != 3 ] || cfmgr_backup_ui_leave=1
			fi
			;;
		3)
			if cfmgr_backup_archive_preferences; then :; else
				cfmgr_backup_archive_code=$?
				[ "$cfmgr_backup_archive_code" != 3 ] || cfmgr_backup_ui_leave=1
			fi
			;;
		e) return 0 ;;
		esac
	done
}

# ---- backup archive ----
# Manual archive controller within the backup category. Trusted entry imports
# shared config, storage and execution categories explicitly.
# No provider, activation, install, schedule or restore operation occurs here.
# API: cfmgr_archive_action read | preferences DMY|MDY|YMD 3|4|5 | create
# One bounded CFMGR-ARCHIVE-ACTION v1 frame; private payload receipts never print.
# shellcheck disable=SC2034,SC2154,SC2030,SC2031

cfmgr_archive_action() (
	case ${1:-}:$# in read:1 | create:1) ;; preferences:3)
		case $2:$3 in DMY:[345] | MDY:[345] | YMD:[345]) ;; *) exit 2 ;; esac
		;;
	*) exit 2 ;;
	esac
	cfmgr_create_operation=$1 cfmgr_archive_want_format=${2:-} cfmgr_archive_want_keep=${3:-}
	cfmgr_store_scope=settings cfmgr_store_backup_gate=0 cfmgr_store_archive_lock_held=0
	cfmgr_store_result=unavailable cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0
	cfmgr_store_pending=0 cfmgr_config_lock_fd0=0 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0 cfmgr_store_flock_entware=0
	cfmgr_store_context='' cfmgr_probe_pid='' cfmgr_probe_status=invalid
	cfmgr_backup_pinned=0 cfmgr_backup_folder_pinned=0 cfmgr_archive_source_pinned=0
	cfmgr_create_result=unavailable cfmgr_create_published=0 cfmgr_create_publish_attempted=0 cfmgr_create_name_hex=-
	cfmgr_create_retention=none cfmgr_create_history=none cfmgr_create_ram_serial=0
	cfmgr_archive_saved_format=- cfmgr_archive_saved_keep=0 cfmgr_archive_saved_set_id=- cfmgr_archive_saved_generation=0
	cfmgr_archive_stage='' cfmgr_archive_format_tracking=0 cfmgr_format_owned='' cfmgr_format_receipts=''
	cfmgr_payload_ram_owned='' cfmgr_history_lock_held=0 cfmgr_history_ready=0
	if cfmgr_store_prepare && cfmgr_archive_work; then cfmgr_create_code=0; else cfmgr_create_code=$?; fi
	if [ "$cfmgr_create_code" = 3 ] || { [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; }; then
		cfmgr_create_code=3 cfmgr_create_result=unresolved cfmgr_store_pending=1
		[ "$cfmgr_create_published" = 0 ] || cfmgr_create_retention=unresolved
	else
		# Cancellation stops work first. A separate bounded cleanup allowance is
		# only for positively owned temporary data after every child has reaped.
		cfmgr_store_interrupt=0
		if [ "${cfmgr_history_lock_held:-0}" = 1 ]; then
			if cfmgr_backup_history_release; then :; else
				cfmgr_create_release_code=$?
				if [ "$cfmgr_create_release_code" = 3 ]; then
					cfmgr_create_code=3 cfmgr_create_result=unresolved cfmgr_store_pending=1
				else cfmgr_create_code=1; fi
			fi
		fi
		if [ "$cfmgr_create_code" != 3 ]; then
			cfmgr_archive_source_release
			if [ -n "$cfmgr_archive_stage" ]; then
				if cfmgr_prerequisites_now; then
					cfmgr_archive_deadline=$((cfmgr_probe_now + 20))
					if cfmgr_payload_cleanup && cfmgr_archive_stage_close; then :; else
						cfmgr_create_cleanup_code=$?
						if [ "$cfmgr_create_cleanup_code" = 3 ] || [ "${cfmgr_probe_status:-}" != reaped ]; then
							cfmgr_create_code=3 cfmgr_create_result=unresolved cfmgr_store_pending=1
						elif [ "$cfmgr_create_published" = 0 ]; then
							cfmgr_create_code=1
						else
							cfmgr_store_pending=1
							printf '[CFMGR] backup: warning: archive created; temporary cleanup is pending\n' >&2
						fi
					fi
				else
					cfmgr_store_pending=1
					if [ "$cfmgr_create_published" = 1 ]; then
						printf '[CFMGR] backup: warning: archive created; temporary cleanup is pending\n' >&2
					else cfmgr_create_code=1; fi
				fi
			fi
		fi
		if [ "$cfmgr_create_code" != 3 ]; then
			cfmgr_store_backup_gate=0 cfmgr_backup_pinned=0 cfmgr_backup_folder_pinned=0
			exec 0<&- 3<&- 4<&- 6<&- 7<&-
			cfmgr_config_lock_fd0=0
			if [ -n "$cfmgr_store_context" ] && ! cfmgr_store_cleanup; then
				cfmgr_store_pending=1
				[ "$cfmgr_create_published" = 1 ] || {
					cfmgr_create_result=recovery
					cfmgr_create_code=1
				}
			fi
		fi
	fi
	case $cfmgr_create_code in 0 | 1 | 3) ;; *) cfmgr_create_code=1 ;; esac
	if [ "$cfmgr_create_code" != 0 ] && [ "$cfmgr_create_result" = unavailable ]; then
		case $cfmgr_store_result in busy | recovery) cfmgr_create_result=$cfmgr_store_result ;; esac
	fi
	cfmgr_create_set_present=0
	[ "$cfmgr_archive_saved_set_id" = - ] || cfmgr_create_set_present=1
	printf 'CFMGR-ARCHIVE-ACTION 1 %s %s %s %s %s %s %s %s %s END\n' "$cfmgr_create_result" "$cfmgr_archive_saved_generation" "$cfmgr_store_pending" \
		"$cfmgr_archive_saved_format" "$cfmgr_archive_saved_keep" "$cfmgr_create_set_present" "$cfmgr_create_name_hex" "$cfmgr_create_retention" "$cfmgr_create_history"
	exit "$cfmgr_create_code"
)

cfmgr_archive_work() {
	cfmgr_store_pending
	if cfmgr_store_setup_ok; then :; else
		cfmgr_create_setup_code=$?
		[ "$cfmgr_create_setup_code" != 3 ] || return 3
		cfmgr_store_pending=1
	fi
	cfmgr_store_archive_read || return $?
	if [ "$cfmgr_create_operation" = read ]; then
		cfmgr_create_result='read'
		return 0
	fi
	[ "$cfmgr_store_pending" = 0 ] || {
		cfmgr_create_result=recovery
		return 1
	}
	if [ "$cfmgr_create_operation" = preferences ]; then
		cfmgr_archive_preferences || return $?
		cfmgr_create_result=$cfmgr_store_result
		cfmgr_store_archive_read
		return $?
	fi
	case $cfmgr_archive_saved_format:$cfmgr_archive_saved_keep in DMY:[345] | MDY:[345] | YMD:[345]) ;; *)
		cfmgr_create_result=preferences-needed
		return 1
		;;
	esac
	cfmgr_store_lock_acquire && cfmgr_store_setup_ok || return $?
	cfmgr_store_pending
	[ "$cfmgr_store_pending" = 0 ] || {
		cfmgr_create_result=recovery
		return 1
	}
	cfmgr_store_archive_lock_held=1
	cfmgr_store_archive_read || return $?
	if [ "$cfmgr_archive_saved_set_id" = - ]; then
		cfmgr_archive_want_format=$cfmgr_archive_saved_format cfmgr_archive_want_keep=$cfmgr_archive_saved_keep
		cfmgr_archive_preferences && cfmgr_store_archive_read || return $?
	fi
	# The complete immutable config snapshot is the authority for this archive.
	cfmgr_create_config=$cfmgr_store_snapshot cfmgr_create_config_bytes=$cfmgr_store_snapshot_bytes
	cfmgr_store_archive_digest_admit && cfmgr_store_digest "$cfmgr_create_config" || return $?
	cfmgr_create_config_sha=$cfmgr_store_digest_value
	cfmgr_store_run store-archive-plan "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib" "$cfmgr_create_config" "$cfmgr_create_config_bytes" || return $?
	cfmgr_create_plan=$cfmgr_probe_stdout
	cfmgr_archive_plan_storage || return $?
	cfmgr_prerequisites_now || return 1
	cfmgr_archive_deadline=$((cfmgr_probe_now + 600)) cfmgr_archive_format_tracking=1
	cfmgr_archive_destination && cfmgr_archive_resources || return $?
	# Read-only history tool admission uses Entware6/7 before source3/rotation4.
	cfmgr_store_backup_gate=0 cfmgr_backup_pinned=0 cfmgr_backup_folder_pinned=0
	exec 6<&- 7<&-
	cfmgr_history_context=$cfmgr_store_context cfmgr_history_limit=$cfmgr_archive_inventory_limit
	cfmgr_history_deadline=$cfmgr_archive_deadline cfmgr_history_memory_kib=$cfmgr_archive_directory_kib
	cfmgr_history_runtime_init native || return $?
	if cfmgr_storage_pin /opt "$cfmgr_store_readlink" "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/storage.sh" /proc/self; then
		if cfmgr_history_runtime_init entware; then :; else
			cfmgr_create_history_code=$?
			[ "$cfmgr_create_history_code" != 3 ] || return 3
			cfmgr_history_runtime_init native || return $?
		fi
	fi
	cfmgr_backup_history_observe "$cfmgr_create_plan" || return $?
	cfmgr_storage_release
	cfmgr_prerequisites_now || return 1
	cfmgr_store_deadline=$((cfmgr_probe_now + 20))
	cfmgr_archive_destination && cfmgr_archive_stage_open || return $?
	cfmgr_create_result=failed
	cfmgr_capture_payload_bytes=0 cfmgr_capture_inventory_bytes=0 cfmgr_capture_files=0
	cfmgr_archive_recognize_existing && cfmgr_archive_choose_name || return $?
	if cfmgr_archive_source_pin "$cfmgr_history_want_uuid" "$cfmgr_history_want_filesystem" "$cfmgr_history_want_root" "$cfmgr_history_want_relative"; then
		if [ "${cfmgr_history_has_payload:-0}" = 1 ]; then cfmgr_history_runtime_init source || return $?; fi
	else
		cfmgr_create_source_code=$?
		[ "$cfmgr_create_source_code" != 3 ] || return 3
		[ "${cfmgr_history_has_payload:-0}" != 1 ] || return 1
	fi
	cfmgr_backup_history_lock || return $?
	cfmgr_archive_capture_data "$cfmgr_create_plan" "$cfmgr_create_config" || return $?
	cfmgr_backup_history_release && cfmgr_archive_source_release || return $?
	cfmgr_archive_build || return $?
	# Direct editor changes cannot silently turn an earlier snapshot into the
	# current successful history. The cooperative writer lock remains held.
	cfmgr_archive_format_hash /proc/self/fd/8/addons/CFMgr.d/config || return $?
	[ "$cfmgr_format_hash" = "$cfmgr_create_config_sha" ] || return 1
	if cfmgr_archive_publish; then :; else
		cfmgr_create_publish_code=$?
		[ "$cfmgr_create_published" = 0 ] || return 3
		return "$cfmgr_create_publish_code"
	fi
	cfmgr_create_result=created
	if cfmgr_archive_retention; then :; else
		cfmgr_create_retention_code=$?
		[ "$cfmgr_create_retention_code" != 3 ] && [ "${cfmgr_probe_status:-}" = reaped ] || return 3
		cfmgr_create_retention=failed
	fi
	cfmgr_create_history=failed
	cfmgr_prerequisites_now || return 0
	cfmgr_store_deadline=$((cfmgr_probe_now + 20))
	cfmgr_archive_want_format=$cfmgr_archive_saved_format cfmgr_archive_want_keep=$cfmgr_archive_saved_keep cfmgr_archive_want_set_id=$cfmgr_archive_saved_set_id
	cfmgr_archive_want_id=$cfmgr_create_id cfmgr_archive_want_at=$cfmgr_create_epoch
	cfmgr_archive_want_date=$cfmgr_create_day cfmgr_archive_want_time=$cfmgr_create_clock cfmgr_archive_want_zone=$cfmgr_create_zone
	cfmgr_archive_want_generation=$cfmgr_archive_saved_generation
	if cfmgr_store_archive_save history; then cfmgr_create_history=saved; else
		[ "$?" != 3 ] || return 3
	fi
	return 0
}

cfmgr_archive_preferences() {
	cfmgr_archive_want_set_id=$cfmgr_archive_saved_set_id
	if [ "$cfmgr_archive_want_set_id" = - ]; then
		cfmgr_archive_uuid || return 1
		cfmgr_archive_want_set_id=$cfmgr_archive_uuid
	fi
	cfmgr_store_archive_save preferences
}

cfmgr_archive_plan_storage() {
	cfmgr_create_storage_seen=0
	while IFS=' ' read -r cfmgr_create_tag cfmgr_create_p1 cfmgr_create_p2 cfmgr_create_p3 cfmgr_create_p4 cfmgr_create_extra <&1; do
		[ "$cfmgr_create_tag" = STORAGE ] || continue
		[ "$cfmgr_create_storage_seen" = 0 ] && [ -z "$cfmgr_create_extra" ] || return 1
		cfmgr_create_storage_seen=1 cfmgr_history_want_uuid=$cfmgr_create_p1 cfmgr_history_want_filesystem=$cfmgr_create_p2
		cfmgr_backup_unhex "$cfmgr_create_p3" text || return 1
		cfmgr_history_want_root=$cfmgr_backup_decoded
		cfmgr_backup_unhex "$cfmgr_create_p4" text || return 1
		cfmgr_history_want_relative=$cfmgr_backup_decoded
	done 1<"$cfmgr_create_plan"
	[ "$cfmgr_create_storage_seen" = 1 ]
}

cfmgr_archive_destination() {
	cfmgr_store_backup_read && cfmgr_backup_check_saved || return $?
	[ "$cfmgr_backup_availability" = available ] && [ "${cfmgr_backup_folder_pinned:-0}" = 1 ]
}

# ---- backup archive capture ----
# Source-inert payload capture coordinator using internal capture,
# payload and archive format/I/O functions. Controller owns config0/source3/rotation4 and phase
# admission. PLAN and CONFIG_SNAPSHOT are already validated private RAM data.
# Caller retires payload RAM only after capture, before the full verifier.
# shellcheck disable=SC2034,SC2154,SC2094

cfmgr_archive_capture_semantic_rejection() {
	# Only a positively identified trusted parser rejection is optional damage.
	[ "${cfmgr_probe_status:-}:${cfmgr_probe_exit:-}:${cfmgr_probe_reason:-}" = reaped:1: ] &&
		[ -f "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	case ${cfmgr_probe_mode:-} in archive-payload-pem | archive-payload-json) ;; *) return 1 ;; esac
}

cfmgr_archive_capture_new_scratch_remove() {
	# Retire only new inode-admitted stage scratch, preserving the prior ledger.
	cfmgr_ac_scratch_tokens=$cfmgr_format_owned
	for cfmgr_ac_scratch_token in $cfmgr_ac_scratch_tokens; do
		case " $cfmgr_ac_cert_baseline " in *" $cfmgr_ac_scratch_token "*) continue ;; esac
		cfmgr_archive_format_remove "$cfmgr_archive_stage/${cfmgr_ac_scratch_token%:*}" || return $?
	done
}

cfmgr_archive_capture_certificate() {
	# ROLE required|optional SCOPE RELATIVEHEX GENERATION EXPECTEDSHA.
	cfmgr_ac_cert_role=$1 cfmgr_ac_cert_need=$2 cfmgr_ac_cert_scope=$3
	cfmgr_ac_cert_hex=$4 cfmgr_ac_cert_generation=$5 cfmgr_ac_cert_expected=$6
	if cfmgr_capture_source "$3" "$4"; then :; else
		cfmgr_ac_cert_code=$?
		[ "$cfmgr_ac_cert_need" = optional ] || return "$cfmgr_ac_cert_code"
		case $cfmgr_ac_cert_code in
		4) cfmgr_capture_note "$cfmgr_ac_cert_role" absent "$cfmgr_ac_cert_hex" absent ;;
		5) cfmgr_capture_note "$cfmgr_ac_cert_role" unavailable "$cfmgr_ac_cert_hex" storage-unavailable ;;
		*) return "$cfmgr_ac_cert_code" ;;
		esac
		return $?
	fi
	cfmgr_ac_cert_input=$cfmgr_capture_source
	cfmgr_capture_metadata "$cfmgr_ac_cert_input" || return $?
	# Unsupported oversized certificates fail bounded capture. Do not copy a
	# huge candidate or call an operational admission failure semantic damage.
	[ "$cfmgr_capture_size" -le 65536 ] || return 1
	cfmgr_capture_member || return 1
	cfmgr_ac_cert_member=$cfmgr_capture_member
	cfmgr_ac_cert_candidate=$cfmgr_archive_stage/$cfmgr_ac_cert_member
	cfmgr_capture_snapshot "$cfmgr_ac_cert_input" "$cfmgr_ac_cert_candidate" whole || return $?
	cfmgr_ac_cert_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/$cfmgr_ac_cert_member
	cfmgr_ac_cert_sha=$cfmgr_capture_sha cfmgr_ac_cert_bytes=$cfmgr_capture_bytes cfmgr_ac_cert_inode=''
	for cfmgr_ac_cert_token in $cfmgr_format_owned; do
		case $cfmgr_ac_cert_token in "$cfmgr_ac_cert_member":*) cfmgr_ac_cert_inode=${cfmgr_ac_cert_token##*:} ;; esac
	done
	[ -n "$cfmgr_ac_cert_inode" ] || return 1
	cfmgr_ac_cert_damaged=0
	[ "$cfmgr_capture_sha" = "$cfmgr_ac_cert_expected" ] || cfmgr_ac_cert_damaged=1
	cfmgr_archive_format_retire || return $?
	cfmgr_ac_cert_baseline=$cfmgr_format_owned
	if [ "$cfmgr_ac_cert_damaged" = 0 ]; then
		if cfmgr_payload_certificate_decode "$cfmgr_ac_cert_anchor" &&
			cfmgr_payload_json certificate-json "$cfmgr_payload_result" "$cfmgr_payload_certificate_account"; then :; else
			cfmgr_ac_cert_code=$?
			cfmgr_archive_capture_semantic_rejection || return "$cfmgr_ac_cert_code"
			cfmgr_ac_cert_damaged=1
			cfmgr_archive_capture_new_scratch_remove || return $?
		fi
	fi
	if [ "$cfmgr_ac_cert_damaged" = 1 ]; then
		[ "$cfmgr_ac_cert_need" = optional ] || return 1
		cfmgr_archive_format_remove "$cfmgr_ac_cert_candidate" || return $?
		# The final mandatory inventory matcher requires a valid other copy.
		cfmgr_capture_note "$cfmgr_ac_cert_role" unavailable "$cfmgr_ac_cert_hex" damaged
		return $?
	fi
	cfmgr_archive_format_inode "$cfmgr_ac_cert_anchor" && [ "$cfmgr_format_inode" = "$cfmgr_ac_cert_inode" ] || return 1
	cfmgr_archive_format_hash "$cfmgr_ac_cert_anchor" && [ "$cfmgr_format_hash" = "$cfmgr_ac_cert_sha" ] || return 1
	_cfmgr_capture_commit "$cfmgr_ac_cert_role" "$cfmgr_ac_cert_scope" "$cfmgr_ac_cert_hex" \
		"$cfmgr_ac_cert_generation" "$cfmgr_ac_cert_expected" whole "$cfmgr_ac_cert_member" "$cfmgr_ac_cert_sha" "$cfmgr_ac_cert_bytes"
}

cfmgr_archive_capture_yaml_prepare() {
	cfmgr_ac_yaml=''
	while IFS=' ' read -r cfmgr_ac_tag cfmgr_ac_a cfmgr_ac_b cfmgr_ac_c cfmgr_ac_d cfmgr_ac_e cfmgr_ac_rest <&1; do
		[ "$cfmgr_ac_tag:$cfmgr_ac_a" = FILE:data.cloudflared.yaml ] || continue
		[ -z "$cfmgr_ac_yaml$cfmgr_ac_rest" ] && [ "$cfmgr_ac_b" = required ] || return 1
		case $cfmgr_ac_c in
		2f6f70742f?*) cfmgr_ac_yaml_scope=entware cfmgr_ac_yaml_hex=${cfmgr_ac_c#2f6f70742f} ;;
		2f6a6666732f?*) cfmgr_ac_yaml_scope=jffs cfmgr_ac_yaml_hex=${cfmgr_ac_c#2f6a6666732f} ;;
		*) return 1 ;;
		esac
		cfmgr_capture_source "$cfmgr_ac_yaml_scope" "$cfmgr_ac_yaml_hex" || return $?
		cfmgr_ac_yaml=$cfmgr_archive_stage/capture-yaml
		cfmgr_capture_snapshot "$cfmgr_capture_source" "$cfmgr_ac_yaml" whole || return $?
		cfmgr_archive_format_retire || return $?
		cfmgr_payload_yaml "/proc/self/fd/7/$cfmgr_archive_stage_leaf/capture-yaml" || return $?
	done 1<"$cfmgr_ac_plan"
}

cfmgr_archive_capture_history() {
	[ "${cfmgr_history_ready:-0}" = 1 ] && cfmgr_archive_input "${cfmgr_history_output:-}" || return 1
	cfmgr_ac_cloud_skip=0 cfmgr_ac_cloud_mode='' cfmgr_ac_cloud_input=''
	# Classify the live writer before any Cloud history member is admitted.
	# Unknown writer ownership excludes this optional feature as a whole.
	while IFS=' ' read -r cfmgr_ac_tag cfmgr_ac_a cfmgr_ac_b cfmgr_ac_c cfmgr_ac_d cfmgr_ac_e cfmgr_ac_more <&1; do
		[ "$cfmgr_ac_tag:$cfmgr_ac_a:$cfmgr_ac_d" = FILE:history.cloudflared:live ] || continue
		[ -z "$cfmgr_ac_cloud_input" ] && [ "$cfmgr_ac_e:$cfmgr_ac_more" = END: ] || return 1
		case $cfmgr_ac_b in 2f6f70742f?*) ;; *) return 1 ;; esac
		cfmgr_capture_source entware "${cfmgr_ac_b#2f6f70742f}" || return $?
		cfmgr_ac_cloud_input=$cfmgr_capture_source
		if cfmgr_archive_cloud_capture_mode "$cfmgr_ac_cloud_input"; then
			case ${cfmgr_archive_capture_mode:-} in whole | prefix) cfmgr_ac_cloud_mode=$cfmgr_archive_capture_mode ;; *) return 1 ;; esac
		else
			cfmgr_ac_cloud_code=$?
			[ "$cfmgr_ac_cloud_code" = 4 ] || return "$cfmgr_ac_cloud_code"
			cfmgr_ac_cloud_skip=1
		fi
	done 1<"$cfmgr_history_output"
	cfmgr_ac_history_header=0 cfmgr_ac_history_end=0 cfmgr_ac_history_states=''
	while IFS=' ' read -r cfmgr_ac_tag cfmgr_ac_a cfmgr_ac_b cfmgr_ac_c cfmgr_ac_d cfmgr_ac_e cfmgr_ac_more <&1; do
		[ "$cfmgr_ac_history_end" = 0 ] || return 1
		case $cfmgr_ac_tag in
		CFMGR-HISTORY)
			[ "$cfmgr_ac_history_header:$cfmgr_ac_a:$cfmgr_ac_b$cfmgr_ac_c$cfmgr_ac_d$cfmgr_ac_e$cfmgr_ac_more" = 0:1: ] || return 1
			cfmgr_ac_history_header=1
			;;
		FILE)
			[ "$cfmgr_ac_history_header:${cfmgr_history_lock_held:-0}:$cfmgr_ac_e:$cfmgr_ac_more" = 1:1:END: ] || return 1
			case $cfmgr_ac_a in history.ddns | history.ip_sync | history.cloudflared) ;; *) return 1 ;; esac
			case $cfmgr_ac_b in 2f6f70742f?*) cfmgr_ac_history_hex=${cfmgr_ac_b#2f6f70742f} ;; *) return 1 ;; esac
			cfmgr_ac_history_role=$cfmgr_ac_a cfmgr_ac_history_generation=$cfmgr_ac_c
			[ "$cfmgr_ac_history_role:$cfmgr_ac_cloud_skip" != history.cloudflared:1 ] || continue
			cfmgr_archive_capture_mode=whole
			case $cfmgr_ac_d in
			live)
				if [ "$cfmgr_ac_history_role" = history.cloudflared ]; then
					cfmgr_archive_capture_mode=$cfmgr_ac_cloud_mode
				fi
				;;
			rotation) ;;
			*) return 1 ;;
			esac
			case $cfmgr_archive_capture_mode in whole | prefix) ;; *) return 1 ;; esac
			cfmgr_capture_file "$cfmgr_ac_history_role" entware "$cfmgr_ac_history_hex" "$cfmgr_ac_history_generation" - "$cfmgr_archive_capture_mode" || return $?
			if [ "$cfmgr_ac_history_role:$cfmgr_ac_d" = history.cloudflared:live ]; then
				cfmgr_archive_cloud_capture_revalidate "$cfmgr_ac_cloud_input" || return $?
			fi
			;;
		STATE)
			[ "$cfmgr_ac_history_header:$cfmgr_ac_d:$cfmgr_ac_e$cfmgr_ac_more" = 1:END: ] || return 1
			case $cfmgr_ac_a in ddns | ip_sync | cloudflared) ;; *) return 1 ;; esac
			case " $cfmgr_ac_history_states " in *" $cfmgr_ac_a "*) return 1 ;; esac
			case $cfmgr_ac_b in included | absent | unavailable | not_applicable) ;; *) return 1 ;; esac
			cfmgr_ac_history_states="${cfmgr_ac_history_states:+$cfmgr_ac_history_states }$cfmgr_ac_a"
			if [ "$cfmgr_ac_a:$cfmgr_ac_cloud_skip" = cloudflared:1 ]; then
				cfmgr_ac_b=unavailable cfmgr_ac_c=writer-unknown
			fi
			cfmgr_capture_note "history.$cfmgr_ac_a" "$cfmgr_ac_b" - "$cfmgr_ac_c" || return $?
			;;
		EFFECTIVE) [ "$cfmgr_ac_history_header" = 1 ] || return 1 ;; # Owned adapter policy evidence; no payload path.
		END)
			[ "$cfmgr_ac_history_header:$cfmgr_ac_a$cfmgr_ac_b$cfmgr_ac_c$cfmgr_ac_d$cfmgr_ac_e$cfmgr_ac_more" = 1: ] || return 1
			cfmgr_ac_history_end=1
			;;
		*) return 1 ;;
		esac
	done 1<"$cfmgr_history_output"
	[ "$cfmgr_ac_history_end" = 1 ] || return 1
	for cfmgr_ac_feature in ddns ip_sync cloudflared; do
		case " $cfmgr_ac_history_states " in *" $cfmgr_ac_feature "*) ;; *) return 1 ;; esac
	done
}

cfmgr_archive_capture_data() {
	[ "$#" = 2 ] && [ "${1%/*}" = "$cfmgr_store_context" ] && [ "${2%/*}" = "$cfmgr_store_context" ] &&
		cfmgr_archive_input "$1" && cfmgr_archive_input "$2" && cfmgr_archive_identity_check || return 1
	cfmgr_ac_plan=$1 cfmgr_ac_config=$2
	cfmgr_capture_payload_bytes=0 cfmgr_capture_inventory_bytes=0 cfmgr_capture_files=0
	cfmgr_payload_plan=$1 cfmgr_payload_yaml='-'
	cfmgr_archive_format_tracking=1
	cfmgr_archive_capture_yaml_prepare && cfmgr_payload_index && cfmgr_capture_start || return $?
	while IFS=' ' read -r cfmgr_ac_tag cfmgr_ac_a cfmgr_ac_b cfmgr_ac_c cfmgr_ac_d cfmgr_ac_e cfmgr_ac_f cfmgr_ac_g cfmgr_ac_more <&1; do
		case $cfmgr_ac_tag in
		FILE)
			[ -z "$cfmgr_ac_more" ] && [ "$cfmgr_ac_g" = whole ] || return 1
			case $cfmgr_ac_a in
			data.cloudflared.certificate | data.cloudflared.certificate-recovery)
				cfmgr_archive_capture_certificate "$cfmgr_ac_a" "$cfmgr_ac_b" "$cfmgr_ac_c" "$cfmgr_ac_d" "$cfmgr_ac_e" "$cfmgr_ac_f" || return $?
				continue
				;;
			manager.config)
				cfmgr_capture_file "$cfmgr_ac_a" "$cfmgr_ac_c" "$cfmgr_ac_d" "$cfmgr_ac_e" "$cfmgr_ac_f" whole "$cfmgr_ac_config" || return $?
				;;
			data.cloudflared.yaml)
				[ -n "$cfmgr_ac_yaml" ] || return 1
				cfmgr_capture_file "$cfmgr_ac_a" "$cfmgr_ac_c" "$cfmgr_ac_d" "$cfmgr_ac_e" "$cfmgr_ac_f" whole "/proc/self/fd/7/$cfmgr_archive_stage_leaf/capture-yaml" || return $?
				;;
			*) cfmgr_capture_file "$cfmgr_ac_a" "$cfmgr_ac_c" "$cfmgr_ac_d" "$cfmgr_ac_e" "$cfmgr_ac_f" whole || return $? ;;
			esac
			cfmgr_ac_last=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_capture_last##*/}
			case $cfmgr_ac_a in
			data.cloudflared.json) cfmgr_payload_json runtime-json "$cfmgr_ac_last" "$cfmgr_payload_authority" || return $? ;;
			data.setup-drafts) cfmgr_payload_json drafts "$cfmgr_ac_last" "$cfmgr_ac_e" || return $? ;;
			esac
			;;
		NOTE)
			[ "$cfmgr_ac_e:$cfmgr_ac_f$cfmgr_ac_g$cfmgr_ac_more" = END: ] || return 1
			if [ "$cfmgr_ac_a:$cfmgr_ac_b" = data.setup-drafts:not_applicable ]; then
				if cfmgr_capture_source jffs 6164646f6e732f43464d67722e642f73657475702d647261667473; then
					return 1
				else [ "$?" = 4 ] || return 1; fi
			fi
			cfmgr_capture_note "$cfmgr_ac_a" "$cfmgr_ac_b" "$cfmgr_ac_c" "$cfmgr_ac_d" || return $?
			;;
		EXTERNAL)
			[ -z "$cfmgr_ac_d$cfmgr_ac_e$cfmgr_ac_f$cfmgr_ac_g$cfmgr_ac_more" ] || return 1
			cfmgr_capture_note "$cfmgr_ac_a" external "$cfmgr_ac_b" "$cfmgr_ac_c" || return $?
			;;
		CFMGR-CAPTURE-PLAN | BACKUP | AUTH | CERT | HISTORY | END) ;;
		*) return 1 ;;
		esac
	done 1<"$cfmgr_payload_capture_plan"
	[ -z "$cfmgr_ac_yaml" ] || cfmgr_archive_format_remove "$cfmgr_ac_yaml" || return $?
	cfmgr_archive_capture_history && cfmgr_capture_finish || return $?
	cfmgr_archive_identity_check || return $?
	cfmgr_archive_run archive-payload-match 4096 "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" \
		"$cfmgr_payload_capture_plan" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/inventory" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" && [ "$cfmgr_store_line" = 'CFMGR-PAYLOAD-MATCH 1 complete END' ] || return 1
	cfmgr_archive_identity_check && cfmgr_archive_format_retire
}

# ---- backup archive format ----
# Source-inert supported-format verifier; no restore/publication authority.
# Imports backup category I/O functions and its admitted Store/destination context.
# Caller supplies cfmgr_archive_inventory_limit, absolute archive deadline and
# disk budget for raw + concatenated bodies + one payload slice. Sources3 and
# rotation4 must be released. Callbacks must preserve the verifier's read FD4.
# On failure retain scratch/receipts; cleanup requires proved child quiescence.
# shellcheck disable=SC2034,SC2154 # Fixed imports and validated exported results.

cfmgr_archive_format_inode() {
	# Stage reads can block on detached storage: supervise them. RAM receipt
	# bookkeeping retains Store's bounded native-RAM cleanup boundary instead.
	case $1 in
	"$cfmgr_store_context"/* | /proc/self/fd/5/*) cfmgr_archive_format_ram_inode "$1" ;;
	*)
		cfmgr_archive_identity_check || return $?
		cfmgr_archive_inode "$1" || return $?
		cfmgr_format_requested_inode=$cfmgr_archive_inode
		cfmgr_archive_identity_check || return $?
		cfmgr_format_inode=$cfmgr_format_requested_inode
		;;
	esac
}

cfmgr_archive_format_ram_inode() {
	cfmgr_format_inode_line=$("$cfmgr_store_ls" -id "$1") || return 1
	IFS=' ' read -r cfmgr_format_inode cfmgr_format_inode_rest <<EOF_FORMAT_INODE
$cfmgr_format_inode_line
EOF_FORMAT_INODE
	cfmgr_archive_uint "$cfmgr_format_inode" && [ "$cfmgr_format_inode" -gt 0 ]
}

cfmgr_archive_format_track_receipts() {
	# Called by archive_run only for a positively reaped operation. Fixed probe
	# filenames are whitespace-free; store inode evidence before retirement.
	for cfmgr_format_receipt in "$cfmgr_probe_stdout" "$cfmgr_probe_stderr"; do
		[ "${cfmgr_format_receipt%/*}" = "$cfmgr_store_context" ] && [ -f "$cfmgr_format_receipt" ] && [ ! -L "$cfmgr_format_receipt" ] || return 1
		cfmgr_format_receipt_name=${cfmgr_format_receipt##*/}
		case $cfmgr_format_receipt_name in archive-*.[0-9]*.out | archive-*.[0-9]*.err) ;; *) return 1 ;; esac
		cfmgr_archive_format_ram_inode "$cfmgr_format_receipt" || return 1
		cfmgr_format_receipts="${cfmgr_format_receipts:+$cfmgr_format_receipts }$cfmgr_format_receipt_name:$cfmgr_format_inode"
	done
}

cfmgr_archive_format_retire() {
	# Same bounded synchronous native-RAM cleanup boundary as Store cleanup.
	# No new supervised-rm receipts are created, and no glob/tree scan is used.
	[ "${cfmgr_probe_status:-}" = reaped ] && cfmgr_archive_attachment_ok || return 1
	cfmgr_store_native_tool /bin/rm || return 1
	set --
	for cfmgr_format_receipt_token in ${cfmgr_format_receipts:-}; do
		cfmgr_format_receipt_name=${cfmgr_format_receipt_token%:*}
		cfmgr_format_receipt_expected=${cfmgr_format_receipt_token##*:}
		cfmgr_format_receipt=/proc/self/fd/5/$cfmgr_format_receipt_name
		[ -f "$cfmgr_format_receipt" ] && [ ! -L "$cfmgr_format_receipt" ] || return 1
		cfmgr_archive_format_ram_inode "$cfmgr_format_receipt" || return 1
		[ "$cfmgr_format_inode" = "$cfmgr_format_receipt_expected" ] || return 1
		set -- "$@" "$cfmgr_format_receipt_name"
	done
	[ "$#" -le 128 ] || return 1
	if [ "$#" -gt 0 ]; then
		(
			cd "/proc/self/fd/5" || exit 1
			# shellcheck disable=SC3013
			[ . -ef "$cfmgr_store_context" ] || exit 1
			exec /bin/rm -f "$@"
		) || return 1
	fi
	cfmgr_format_receipts=''
}

cfmgr_archive_format_record() {
	[ "${1%/*}" = "$cfmgr_archive_stage" ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_archive_format_inode "$1" || return 1
	cfmgr_format_owned="${cfmgr_format_owned:+$cfmgr_format_owned }${1##*/}:$cfmgr_format_inode"
}

cfmgr_archive_format_new() {
	cfmgr_format_new_path=$cfmgr_archive_stage/$cfmgr_format_prefix-$1
	cfmgr_archive_write "$cfmgr_format_new_path" 4096 new '' || return $?
	cfmgr_archive_format_record "$cfmgr_format_new_path"
}

cfmgr_archive_format_remove() {
	# Stage filesystem unlink remains a supervised direct native child. RAM
	# receipts from this operation are separately retired only after reap.
	cfmgr_format_remove_name=${1##*/} cfmgr_format_remove_found=0 cfmgr_format_owned_next=''
	for cfmgr_format_owned_token in $cfmgr_format_owned; do
		if [ "${cfmgr_format_owned_token%:*}" = "$cfmgr_format_remove_name" ]; then
			cfmgr_format_remove_expected=${cfmgr_format_owned_token##*:}
			cfmgr_format_remove_found=1
		else cfmgr_format_owned_next="${cfmgr_format_owned_next:+$cfmgr_format_owned_next }$cfmgr_format_owned_token"; fi
	done
	[ "$cfmgr_format_remove_found" = 1 ] && [ "${cfmgr_probe_status:-}" = reaped ] && [ ! -L "$1" ] || return 1
	cfmgr_archive_format_inode "$1" && [ "$cfmgr_format_inode" = "$cfmgr_format_remove_expected" ] || return 1
	cfmgr_archive_run archive-unlink 4096 /bin/rm "/proc/self/fd/7/$cfmgr_archive_stage_leaf" "$cfmgr_archive_stage" "$cfmgr_format_remove_name" || return $?
	cfmgr_archive_identity_check || return $?
	cfmgr_format_owned=$cfmgr_format_owned_next
	cfmgr_archive_format_retire
}

cfmgr_archive_format_cleanup() {
	cfmgr_format_cleanup_tracking=${cfmgr_archive_format_tracking:-0}
	cfmgr_archive_format_tracking=1
	if _cfmgr_archive_format_cleanup; then cfmgr_format_cleanup_code=0; else cfmgr_format_cleanup_code=$?; fi
	cfmgr_archive_format_tracking=$cfmgr_format_cleanup_tracking
	return "$cfmgr_format_cleanup_code"
}

_cfmgr_archive_format_cleanup() {
	[ "${cfmgr_probe_status:-}" = reaped ] || return 1
	while [ -n "${cfmgr_format_owned:-}" ]; do
		cfmgr_format_cleanup_token=${cfmgr_format_owned%% *}
		cfmgr_archive_format_remove "$cfmgr_archive_stage/${cfmgr_format_cleanup_token%:*}" || return $?
	done
	cfmgr_archive_format_retire
}

cfmgr_archive_format_copy() {
	[ ! -e "$2" ] && [ ! -L "$2" ] || return 1
	if cfmgr_archive_copy "$1" "$2" "$3" "$4"; then cfmgr_format_copy_code=0; else cfmgr_format_copy_code=$?; fi
	# A reaped failed writer can leave its exclusively created partial output.
	# Record that identity too; unresolved writers retain all evidence untouched.
	if [ "${cfmgr_probe_status:-}" = reaped ] && [ -f "$2" ] && [ ! -L "$2" ]; then
		cfmgr_archive_format_record "$2" || return 1
	fi
	return "$cfmgr_format_copy_code"
}

cfmgr_archive_format_stream() {
	# Fixed stream operation with one new owned output (MODE CAP INPUT OUTPUT).
	[ ! -e "$4" ] && [ ! -L "$4" ] || return 1
	if cfmgr_archive_io "$@"; then cfmgr_format_stream_code=0; else cfmgr_format_stream_code=$?; fi
	if [ "${cfmgr_probe_status:-}" = reaped ] && [ -f "$4" ] && [ ! -L "$4" ]; then
		cfmgr_archive_format_record "$4" || return 1
	fi
	return "$cfmgr_format_stream_code"
}

cfmgr_archive_format_hash() {
	cfmgr_archive_io digest 4096 "$1" || return $?
	cfmgr_store_read_line "$cfmgr_archive_output" || return 1
	IFS=' ' read -r cfmgr_format_hash cfmgr_format_hash_path <<EOF_FORMAT_HASH
$cfmgr_store_line
EOF_FORMAT_HASH
	cfmgr_format_hash_path=${cfmgr_format_hash_path#\*}
	[ "$cfmgr_format_hash_path" = "$1" ] && [ "${#cfmgr_format_hash}" = 64 ] || return 1
	case $cfmgr_format_hash in *[!0-9a-f]*) return 1 ;; esac
}

cfmgr_archive_format_walk() {
	cfmgr_archive_format_new index || return 1
	cfmgr_format_index=$cfmgr_format_new_path
	cfmgr_format_index_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_index##*/}
	cfmgr_format_offset=0 cfmgr_format_sum=0 cfmgr_format_members=0 cfmgr_format_zeros=0
	while [ "$cfmgr_format_offset" -lt "$cfmgr_format_raw_bytes" ]; do
		cfmgr_format_header=$cfmgr_archive_stage/$cfmgr_format_prefix-header
		cfmgr_archive_format_copy "$cfmgr_format_raw" "$cfmgr_format_header" "$cfmgr_format_offset" 512 || return $?
		# Exact copy just proved512 bytes. The header parser itself requires
		# exactly1024 hex characters, avoiding duplicate native WC scans here.
		cfmgr_archive_run archive-hexdump 4096 /usr/bin/hexdump "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_header##*/}" || return $?
		cfmgr_archive_run archive-tar-header 4096 "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" "$cfmgr_probe_stdout" "$cfmgr_format_offset" "$cfmgr_format_raw_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_format_marker cfmgr_format_version cfmgr_format_kind cfmgr_format_member cfmgr_format_size cfmgr_format_body cfmgr_format_next cfmgr_format_end cfmgr_format_extra <<EOF_FORMAT_HEADER
$cfmgr_store_line
EOF_FORMAT_HEADER
		[ "$cfmgr_format_marker:$cfmgr_format_version:$cfmgr_format_end:$cfmgr_format_extra" = CFMGR-TAR-HEADER:1:END: ] || return 1
		cfmgr_archive_uint "$cfmgr_format_size" && cfmgr_archive_uint "$cfmgr_format_body" && cfmgr_archive_uint "$cfmgr_format_next" || return 1
		if [ "$cfmgr_format_kind" = zero ]; then
			cfmgr_format_zeros=$((cfmgr_format_zeros + 1))
			[ "$cfmgr_format_zeros" -le 2 ] || return 1
		else
			[ "$cfmgr_format_kind" = file ] && [ "$cfmgr_format_zeros" = 0 ] || return 1
			case $cfmgr_format_members in
			0)
				[ "$cfmgr_format_member" = manifest ] && [ "$cfmgr_format_size" -gt 0 ] && [ "$cfmgr_format_size" -le 4096 ] || return 1
				cfmgr_format_manifest_size=$cfmgr_format_size
				;;
			1)
				[ "$cfmgr_format_member" = inventory ] && [ "$cfmgr_format_size" -gt 0 ] && [ "$cfmgr_format_size" -le "$cfmgr_archive_inventory_limit" ] || return 1
				cfmgr_format_inventory_size=$cfmgr_format_size
				;;
			*)
				[ "$cfmgr_format_members" -le 100000000 ] || return 1
				cfmgr_format_expected=$(printf 'p%08d' "$((cfmgr_format_members - 1))")
				[ "$cfmgr_format_member" = "$cfmgr_format_expected" ] || return 1
				;;
			esac
			[ "$cfmgr_format_sum" -le "$((9223372036854775296 - cfmgr_format_size))" ] || return 1
			cfmgr_archive_write "$cfmgr_format_index" "$cfmgr_archive_inventory_limit" append "$cfmgr_format_member $cfmgr_format_size $cfmgr_format_body $cfmgr_format_sum
" || return $?
			cfmgr_format_sum=$((cfmgr_format_sum + cfmgr_format_size))
			cfmgr_format_members=$((cfmgr_format_members + 1))
		fi
		cfmgr_format_offset=$cfmgr_format_next
		cfmgr_archive_format_remove "$cfmgr_format_header" || return $?
	done
	[ "$cfmgr_format_zeros" = 2 ] && [ "$cfmgr_format_members" -ge 4 ] && [ "$cfmgr_format_offset" = "$cfmgr_format_raw_bytes" ]
}

cfmgr_archive_format_metadata() {
	cfmgr_format_manifest=$cfmgr_archive_stage/$cfmgr_format_prefix-manifest
	cfmgr_format_inventory=$cfmgr_archive_stage/$cfmgr_format_prefix-inventory
	cfmgr_archive_format_copy "$cfmgr_format_bodies_anchor" "$cfmgr_format_manifest" 0 "$cfmgr_format_manifest_size" || return $?
	cfmgr_archive_format_copy "$cfmgr_format_bodies_anchor" "$cfmgr_format_inventory" "$cfmgr_format_manifest_size" "$cfmgr_format_inventory_size" || return $?
	cfmgr_format_manifest_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_manifest##*/}
	cfmgr_format_inventory_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_inventory##*/}
	cfmgr_format_hex=$cfmgr_archive_stage/$cfmgr_format_prefix-hex
	cfmgr_archive_format_stream metahex "$((cfmgr_format_manifest_size * 3))" "$cfmgr_format_manifest_anchor" "$cfmgr_format_hex" || return $?
	cfmgr_archive_run archive-format-manifest 4096 "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_hex##*/}" "$cfmgr_format_expected_set" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_format_marker cfmgr_format_version cfmgr_format_set cfmgr_format_id cfmgr_format_epoch cfmgr_format_day cfmgr_format_clock cfmgr_format_timezone cfmgr_format_zone cfmgr_format_order cfmgr_format_schema cfmgr_format_generation cfmgr_format_rows cfmgr_format_inventory_bytes cfmgr_format_inventory_sha cfmgr_format_files cfmgr_format_payload_bytes cfmgr_format_end cfmgr_format_extra <<EOF_FORMAT_MANIFEST
$cfmgr_store_line
EOF_FORMAT_MANIFEST
	[ "$cfmgr_format_marker:$cfmgr_format_version:$cfmgr_format_end:$cfmgr_format_extra" = CFMGR-MANIFEST:1:END: ] && [ "$cfmgr_format_inventory_bytes" = "$cfmgr_format_inventory_size" ] && [ "$cfmgr_format_files" = "$((cfmgr_format_members - 2))" ] || return 1
	[ "$cfmgr_format_payload_bytes" = "$((cfmgr_format_sum - cfmgr_format_manifest_size - cfmgr_format_inventory_size))" ] || return 1
	cfmgr_archive_format_hash "$cfmgr_format_inventory_anchor" || return $?
	[ "$cfmgr_format_hash" = "$cfmgr_format_inventory_sha" ] || return 1
	cfmgr_archive_format_remove "$cfmgr_format_hex" || return $?
	[ "$cfmgr_format_inventory_size" -le "$(((9223372036854775296 - 4096) / 3))" ] || return 1
	cfmgr_archive_format_stream metahex "$((cfmgr_format_inventory_size * 3))" "$cfmgr_format_inventory_anchor" "$cfmgr_format_hex" || return $?
	cfmgr_archive_run archive-format-inventory "$((cfmgr_format_inventory_size * 2 + 4096))" "$cfmgr_store_awk" \
		"$cfmgr_store_source/modules/backup.sh" "$cfmgr_store_source/modules/backup.sh" \
		"/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_hex##*/}" "$cfmgr_format_index_anchor" "$cfmgr_format_rows $cfmgr_format_files $cfmgr_format_payload_bytes" || return $?
	# Preserve this normalized bounded-line stream while other receipts retire.
	cfmgr_format_records=$cfmgr_archive_stage/$cfmgr_format_prefix-records
	cfmgr_format_records_source=$cfmgr_probe_stdout
	cfmgr_archive_measure "$cfmgr_format_records_source" || return $?
	cfmgr_archive_format_copy "$cfmgr_format_records_source" "$cfmgr_format_records" 0 "$cfmgr_archive_bytes" || return $?
	cfmgr_archive_format_remove "$cfmgr_format_hex" || return $?
	cfmgr_archive_format_remove "$cfmgr_format_manifest" || return $?
	cfmgr_archive_format_retire
}

cfmgr_archive_format_payloads() {
	cfmgr_format_seen=0 cfmgr_format_complete=0
	cfmgr_format_stream_position=$((cfmgr_format_manifest_size + cfmgr_format_inventory_size))
	cfmgr_format_records_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_records##*/}
	exec 4<"$cfmgr_format_records_anchor" || return 1
	while IFS=' ' read -r cfmgr_format_tag cfmgr_format_name cfmgr_format_role cfmgr_format_scope cfmgr_format_pathhex cfmgr_format_file_generation cfmgr_format_mode cfmgr_format_size cfmgr_format_sha cfmgr_format_capture cfmgr_format_stream_offset cfmgr_format_extra <&4; do
		[ "$cfmgr_format_complete" = 0 ] || return 1
		if [ "$cfmgr_format_tag" = COMPLETE ]; then
			[ "$cfmgr_format_name" = "$cfmgr_format_files" ] && [ "$cfmgr_format_scope" = "$cfmgr_format_payload_bytes" ] && [ -z "$cfmgr_format_pathhex$cfmgr_format_file_generation$cfmgr_format_mode$cfmgr_format_size$cfmgr_format_sha$cfmgr_format_capture$cfmgr_format_stream_offset$cfmgr_format_extra" ] || return 1
			cfmgr_format_complete=1
			continue
		fi
		[ "$cfmgr_format_tag" = PAYLOAD ] && [ -z "$cfmgr_format_extra" ] && [ "$cfmgr_format_stream_offset" = "$cfmgr_format_stream_position" ] || return 1
		cfmgr_format_slice=$cfmgr_archive_stage/$cfmgr_format_prefix-payload
		cfmgr_archive_format_copy "$cfmgr_format_bodies_anchor" "$cfmgr_format_slice" "$cfmgr_format_stream_offset" "$cfmgr_format_size" || return $?
		cfmgr_format_slice_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_slice##*/}
		cfmgr_archive_format_hash "$cfmgr_format_slice_anchor" || return $?
		[ "$cfmgr_format_hash" = "$cfmgr_format_sha" ] || return 1
		cfmgr_archive_verify_payload "$cfmgr_format_role" "$cfmgr_format_scope" "$cfmgr_format_pathhex" "$cfmgr_format_file_generation" "$cfmgr_format_mode" "$cfmgr_format_size" "$cfmgr_format_sha" "$cfmgr_format_capture" "$cfmgr_format_slice_anchor" || return 1
		cfmgr_format_stream_position=$((cfmgr_format_stream_position + cfmgr_format_size))
		cfmgr_format_seen=$((cfmgr_format_seen + 1))
		cfmgr_archive_format_remove "$cfmgr_format_slice" || return $?
	done
	exec 4<&-
	[ "$cfmgr_format_complete" = 1 ] && [ "$cfmgr_format_seen" = "$cfmgr_format_files" ] && [ "$cfmgr_format_stream_position" = "$cfmgr_format_sum" ] || return 1
	cfmgr_archive_verify_complete "$cfmgr_format_inventory_anchor"
}

_cfmgr_archive_format_verify() {
	cfmgr_archive_measure "$cfmgr_format_raw" || return $?
	cfmgr_format_raw_bytes=$cfmgr_archive_bytes
	[ "$cfmgr_format_raw_bytes" -ge 2048 ] || return 1
	cfmgr_archive_format_walk || return $?
	# The caller admits actual available disk space; these checked quantities
	# keep its raw + body stream + largest one-slice estimate representable.
	[ "$cfmgr_format_raw_bytes" -le "$((9223372036854775296 - cfmgr_format_sum))" ] || return 1
	cfmgr_format_peak_bytes=$((cfmgr_format_raw_bytes + cfmgr_format_sum))
	# Any one body is bounded by the total body stream.
	[ "$cfmgr_format_peak_bytes" -le "$((9223372036854775296 - cfmgr_format_sum))" ] || return 1
	cfmgr_format_peak_bytes=$((cfmgr_format_peak_bytes + cfmgr_format_sum))
	# Metadata-only hex/normalized records and index/listing overhead are also
	# stage-local. The controller admits actual space; this estimate must not
	# wrap while it accounts for raw + stream + one slice + metadata scratch.
	[ "$cfmgr_format_inventory_size" -le "$((9223372036854775296 / 7))" ] || return 1
	cfmgr_format_metadata_reserve=$((cfmgr_format_inventory_size * 7))
	cfmgr_format_metadata_overhead=$((4096 + cfmgr_format_members * 160))
	[ "$cfmgr_format_metadata_reserve" -le "$((9223372036854775296 - cfmgr_format_metadata_overhead))" ] || return 1
	cfmgr_format_metadata_reserve=$((cfmgr_format_metadata_reserve + cfmgr_format_metadata_overhead))
	[ "$cfmgr_format_peak_bytes" -le "$((9223372036854775296 - cfmgr_format_metadata_reserve))" ] || return 1
	cfmgr_format_peak_bytes=$((cfmgr_format_peak_bytes + cfmgr_format_metadata_reserve))
	cfmgr_format_listing=$cfmgr_archive_stage/$cfmgr_format_prefix-listing
	cfmgr_archive_format_stream tar-list "$((cfmgr_format_members * 10))" "$cfmgr_format_raw" "$cfmgr_format_listing" || return $?
	cfmgr_archive_run archive-list-compare 4096 "$cfmgr_store_awk" "$cfmgr_format_index_anchor" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_listing##*/}" || return $?
	cfmgr_format_bodies=$cfmgr_archive_stage/$cfmgr_format_prefix-bodies
	cfmgr_archive_format_stream tar-bodies "$cfmgr_format_sum" "$cfmgr_format_raw" "$cfmgr_format_bodies" || return $?
	[ "$cfmgr_archive_bytes" = "$cfmgr_format_sum" ] || return 1
	cfmgr_format_bodies_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_format_bodies##*/}
	cfmgr_archive_format_retire || return 1
	cfmgr_archive_format_metadata && cfmgr_archive_format_payloads || return $?
	cfmgr_archive_format_cleanup
}

cfmgr_archive_format_verify() {
	# OWNED_RAW EXPECTED_SET_UUID. The raw file must be an immutable owned
	# direct child of the current private stage. Failure grants no acceptance.
	cfmgr_archive_verified=0 cfmgr_archive_verification_status=incomplete
	cfmgr_archive_set_id='' cfmgr_archive_id='' cfmgr_archive_epoch='' cfmgr_archive_day='' cfmgr_archive_clock=''
	cfmgr_archive_timezone_hex='' cfmgr_archive_utc_offset='' cfmgr_archive_date_order=''
	cfmgr_archive_config_schema='' cfmgr_archive_config_generation=''
	[ "$#" -eq 2 ] && [ -n "${cfmgr_archive_stage:-}" ] && [ "${1%/*}" = "$cfmgr_archive_stage" ] && [ -f "$1" ] && [ ! -L "$1" ] || return 2
	[ "${cfmgr_archive_source_pinned:-0}" != 1 ] && [ -z "${cfmgr_format_owned:-}${cfmgr_format_receipts:-}" ] || return 2
	if (: <&3) 2>/dev/null || (: <&4) 2>/dev/null; then return 2; fi
	type cfmgr_archive_verify_payload >/dev/null 2>&1 && type cfmgr_archive_verify_complete >/dev/null 2>&1 || return 2
	cfmgr_archive_uint "${cfmgr_archive_inventory_limit:-}" && [ "$cfmgr_archive_inventory_limit" -gt 0 ] || return 2
	case ${2} in *[!0-9a-f-]* | '') return 2 ;; esac
	[ "${#2}" = 36 ] || return 2
	cfmgr_archive_attachment_ok || return 1
	cfmgr_format_serial=${cfmgr_format_serial:-0}
	cfmgr_archive_uint "$cfmgr_format_serial" && [ "${#cfmgr_format_serial}" -le 6 ] || return 2
	cfmgr_format_serial=$((${cfmgr_format_serial:-0} + 1))
	cfmgr_format_prefix=.verify.$cfmgr_format_serial
	cfmgr_format_raw=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${1##*/}
	cfmgr_format_expected_set=$2 cfmgr_archive_format_tracking=1
	if _cfmgr_archive_format_verify; then cfmgr_format_code=0; else cfmgr_format_code=$?; fi
	# Only a completed trusted parser rejection positively excludes a candidate.
	# I/O, resource, decompressor and unclassified failures remain incomplete.
	if [ "$cfmgr_format_code" = 1 ] && [ "${cfmgr_probe_status:-}:${cfmgr_probe_exit:-}:${cfmgr_probe_reason:-}" = reaped:1: ] &&
		[ -f "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stderr" ]; then
		case ${cfmgr_probe_mode:-} in
		archive-tar-header | archive-format-manifest | archive-format-inventory | archive-payload-plan | archive-payload-json | archive-payload-pem | archive-payload-match)
			cfmgr_archive_verification_status=excluded
			;;
		esac
	fi
	# YAML exit 1 also reports the current metadata budget being exhausted.
	# Keep it incomplete so an uninspected valid archive cannot authorize pruning.
	exec 4<&-
	cfmgr_archive_format_tracking=0
	[ "$cfmgr_format_code" = 0 ] || return "$cfmgr_format_code"
	cfmgr_archive_set_id=$cfmgr_format_set cfmgr_archive_id=$cfmgr_format_id
	cfmgr_archive_epoch=$cfmgr_format_epoch cfmgr_archive_day=$cfmgr_format_day cfmgr_archive_clock=$cfmgr_format_clock
	cfmgr_archive_timezone_hex=$cfmgr_format_timezone cfmgr_archive_utc_offset=$cfmgr_format_zone cfmgr_archive_date_order=$cfmgr_format_order
	cfmgr_archive_config_schema=$cfmgr_format_schema cfmgr_archive_config_generation=$cfmgr_format_generation
	cfmgr_archive_verified=1 cfmgr_archive_verification_status=verified
}

# ---- backup archive io ----
# Source-inert native archive operations. This is execution/storage groundwork,
# not archive admission, a verifier, payload policy, or publication authority.
# Shared inputs: execution/storage categories and the admitted config Store context.
# Caller supplies an absolute uptime deadline; no archive default is invented.
# FD0 lock, 3 optional source, 4 caller rotation lock, 5 RAM, 6/7 destination,
# 8 JFFS, 9 support. Release source3 before any Store flush/guard phase.
# Locked native children close9: JFFS inputs use root8-relative admitted paths.
# Each operation retains unique archive-*.out/.err receipts, including counts.
# The caller retires consumed pairs only after proved quiescence and anchored
# ownership; preserve still-needed snapshots/results and unresolved evidence.
# Do this during long member/header loops; Store's RAM-file bound is unchanged.
# shellcheck disable=SC2034,SC2154 # Controller imports and exported results.

cfmgr_archive_uint() {
	# Canonical decimals only; leave room for rounding a byte cap to512 blocks.
	# Refuse unsupported shell arithmetic instead of overflowing a copy length.
	[ "$#" -eq 1 ] && [ "${#1}" -le 19 ] || return 1
	case $1 in '' | *[!0-9]* | 0?*) return 1 ;; esac
	[ "$((2147483647 + 1))" = 2147483648 ] && [ "$1" -le 9223372036854775296 ]
}

cfmgr_archive_attachment_ok() {
	cfmgr_store_attachment_ok && cfmgr_backup_attached || return 1
	[ "${cfmgr_backup_folder_pinned:-0}" = 1 ] || return 1
	if [ -n "${cfmgr_archive_stage:-}" ]; then
		case ${cfmgr_archive_stage_leaf:-} in '' | . | .. | *[!A-Za-z0-9_.-]*) return 1 ;; esac
		[ "$cfmgr_archive_stage" = "$cfmgr_backup_mount/CFBackup/$cfmgr_archive_stage_leaf" ] || return 1
		[ -d "$cfmgr_archive_stage" ] && [ ! -L "$cfmgr_archive_stage" ] || return 1
		# shellcheck disable=SC3013
		[ "$cfmgr_archive_stage" -ef "/proc/self/fd/7/$cfmgr_archive_stage_leaf" ] || return 1
	fi
	if [ -n "${cfmgr_archive_append_path:-}" ]; then
		[ -f "$cfmgr_archive_append_path" ] && [ ! -L "$cfmgr_archive_append_path" ] || return 1
	fi
	[ "${cfmgr_archive_source_pinned:-0}" != 1 ] || cfmgr_archive_source_attached
}

cfmgr_archive_input() {
	# The controller owns role/path admission. Reads use pinned roots or its
	# private RAM/stage snapshot; never reopen /opt or a mounted pathname.
	[ "$#" -eq 1 ] && _cfmgr_storage_path "$1" || return 1
	case $1 in
	/proc/self/fd/3/?*)
		[ "${cfmgr_archive_source_pinned:-0}" = 1 ] || return 1
		cfmgr_archive_input_root=/proc/self/fd/3
		;;
	/proc/self/fd/5/?*) cfmgr_archive_input_root=/proc/self/fd/5 ;;
	/proc/self/fd/7/?*) cfmgr_archive_input_root=/proc/self/fd/7 ;;
	/proc/self/fd/8/?*) cfmgr_archive_input_root=/proc/self/fd/8 ;;
	"$cfmgr_store_context"/?*)
		[ "${1%/*}" = "$cfmgr_store_context" ] || return 1
		cfmgr_archive_input_root=$cfmgr_store_context
		;;
	*) return 1 ;;
	esac
	[ -f "$1" ] || return 1
	cfmgr_archive_input_component=$1
	while [ "$cfmgr_archive_input_component" != "$cfmgr_archive_input_root" ]; do
		[ ! -L "$cfmgr_archive_input_component" ] || return 1
		cfmgr_archive_input_component=${cfmgr_archive_input_component%/*}
	done
}

cfmgr_archive_output_path() {
	[ "$#" -eq 1 ] && _cfmgr_storage_path "$1" || return 2
	cfmgr_archive_name=${1##*/}
	case $cfmgr_archive_name in '' | . | .. | *[!A-Za-z0-9_.-]*) return 2 ;; esac
	cfmgr_archive_directory=${1%/*}
	case $cfmgr_archive_directory in
	# The directory component avoids passing the proc magic symlink itself to
	# workers that require a nonsymlink directory anchor before the -ef check.
	"$cfmgr_store_context") cfmgr_archive_anchor=/proc/self/fd/5/. ;;
	"${cfmgr_archive_stage:-}") cfmgr_archive_anchor=/proc/self/fd/7/$cfmgr_archive_stage_leaf ;;
	*) return 2 ;;
	esac
	# shellcheck disable=SC3013
	[ -d "$cfmgr_archive_directory" ] && [ ! -L "$cfmgr_archive_directory" ] &&
		[ "$cfmgr_archive_directory" -ef "$cfmgr_archive_anchor" ]
}

cfmgr_archive_run() {
	# Internal fixed mode, byte cap, admitted tool, fixed operands.
	cfmgr_archive_run_mode=$1 cfmgr_archive_limit=$2 cfmgr_archive_run_tool=$3
	shift 3
	cfmgr_archive_uint "$cfmgr_archive_limit" && [ "$cfmgr_archive_limit" -gt 0 ] || return 2
	cfmgr_archive_attachment_ok && cfmgr_store_native_tool "$cfmgr_archive_run_tool" || return 1
	if cfmgr_prerequisites_run "$cfmgr_archive_run_mode" "$cfmgr_store_context" "$cfmgr_store_sh" \
		"$cfmgr_store_source/modules/helpers/worker.sh" "$cfmgr_store_env" "$cfmgr_store_awk" \
		"$cfmgr_store_sleep" "$cfmgr_store_wc" "$cfmgr_archive_run_tool" "$@"; then
		cfmgr_archive_run_code=0
	else cfmgr_archive_run_code=$?; fi
	if [ "${cfmgr_archive_format_tracking:-0}" = 1 ] && [ "${cfmgr_probe_status:-}" = reaped ]; then
		cfmgr_archive_format_track_receipts || return 1
	fi
	[ "$cfmgr_archive_run_code" = 0 ] || return "$cfmgr_archive_run_code"
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_archive_inode() {
	# Fixed supervised metadata operation, never called by a watch callback.
	[ "$#" -eq 1 ] && [ ! -L "$1" ] && { [ -f "$1" ] || [ -d "$1" ]; } || return 2
	cfmgr_archive_run archive-inode 4096 "$cfmgr_store_ls" "$1" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_archive_inode cfmgr_archive_inode_rest <<EOF_ARCHIVE_INODE
$cfmgr_store_line
EOF_ARCHIVE_INODE
	cfmgr_archive_uint "$cfmgr_archive_inode" && [ "$cfmgr_archive_inode" -gt 0 ]
}

cfmgr_archive_identity_check() {
	# Logical operation admission/completion, outside the supervisor/watch loop.
	# Keep successful caller receipts available after these additional probes.
	cfmgr_archive_identity_out=${cfmgr_probe_stdout:-} cfmgr_archive_identity_err=${cfmgr_probe_stderr:-}
	cfmgr_archive_identity_exit=${cfmgr_probe_exit:-}
	cfmgr_archive_attachment_ok || return 1
	if [ -n "${cfmgr_archive_stage:-}" ]; then
		cfmgr_archive_inode "/proc/self/fd/7/$cfmgr_archive_stage_leaf" || return $?
		[ "$cfmgr_archive_inode" = "${cfmgr_archive_stage_inode:-}" ] || return 1
	fi
	if [ -n "${cfmgr_archive_append_path:-}" ]; then
		cfmgr_archive_inode "$cfmgr_archive_append_path" || return $?
		[ "$cfmgr_archive_inode" = "$cfmgr_archive_append_inode" ] || return 1
	fi
	cfmgr_probe_stdout=$cfmgr_archive_identity_out cfmgr_probe_stderr=$cfmgr_archive_identity_err
	cfmgr_probe_exit=$cfmgr_archive_identity_exit
}

cfmgr_archive_measure() {
	cfmgr_archive_run archive-count 4096 "$cfmgr_store_wc" "$1" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' 	' read -r cfmgr_archive_bytes cfmgr_archive_extra <<EOF_ARCHIVE_COUNT
$cfmgr_store_line
EOF_ARCHIVE_COUNT
	[ "$cfmgr_archive_extra" = "$1" ] && cfmgr_archive_uint "$cfmgr_archive_bytes"
}

cfmgr_archive_write() {
	cfmgr_archive_identity_check || return $?
	if _cfmgr_archive_write "$@"; then
		if cfmgr_archive_identity_check; then cfmgr_archive_write_result=0; else cfmgr_archive_write_result=$?; fi
	else cfmgr_archive_write_result=$?; fi
	if [ "${cfmgr_probe_status:-}" = reaped ]; then cfmgr_archive_append_path=''; fi
	return "$cfmgr_archive_write_result"
}

_cfmgr_archive_write() {
	# Small generated metadata only; stage writes still receive native child
	# deadlines/ownership and exact post-write size checks. No shell evaluation.
	[ "$#" -eq 4 ] && [ "${#4}" -le 4096 ] && cfmgr_archive_uint "$2" && [ "$2" -gt 0 ] || return 2
	cfmgr_archive_write_path=$1 cfmgr_archive_write_cap=$2
	cfmgr_archive_output_path "$1" || return 2
	case $3 in
	new) [ ! -e "$1" ] && [ ! -L "$1" ] || return 1 ;;
	append)
		[ -f "$1" ] && [ ! -L "$1" ] || return 1
		cfmgr_archive_run archive-meta 4096 "$cfmgr_store_ls" "$1" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_archive_append_inode cfmgr_archive_inode_rest <<EOF_ARCHIVE_WRITE_INODE
$cfmgr_store_line
EOF_ARCHIVE_WRITE_INODE
		cfmgr_archive_uint "$cfmgr_archive_append_inode" && [ "$cfmgr_archive_append_inode" -gt 0 ] || return 1
		cfmgr_archive_append_path=$1
		cfmgr_archive_identity_check || return $?
		;;
	*) return 2 ;;
	esac
	if cfmgr_archive_run archive-write "$2" /usr/bin/printf "$cfmgr_archive_anchor" "$cfmgr_archive_directory" "$cfmgr_archive_name" "$3" "$4"; then
		cfmgr_archive_write_code=0
	else cfmgr_archive_write_code=$?; fi
	[ "$cfmgr_archive_write_code" = 0 ] || return "$cfmgr_archive_write_code"
	if [ "${cfmgr_archive_write_path%/*}" = "$cfmgr_store_context" ]; then
		cfmgr_archive_write_input=$cfmgr_archive_write_path
	else cfmgr_archive_write_input=/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_archive_write_path##*/}; fi
	cfmgr_archive_measure "$cfmgr_archive_write_input" && [ "$cfmgr_archive_bytes" -le "$cfmgr_archive_write_cap" ]
}

cfmgr_archive_io() {
	cfmgr_archive_identity_check || return $?
	_cfmgr_archive_io "$@" || return $?
	cfmgr_archive_identity_check
}

_cfmgr_archive_io() {
	# MODE CAP OPERANDS. CAP is a validated input-derived maximum, not a log
	# quota. Scalar modes use4096. Stream outputs must be new owned direct
	# children of the private stage/RAM context. tar bodies/list modes require
	# prior complete raw-header admission by the verifier, including extensions.
	[ "$#" -ge 2 ] || return 2
	cfmgr_archive_mode=$1 cfmgr_archive_cap=$2 cfmgr_archive_output=''
	shift 2
	cfmgr_archive_uint "$cfmgr_archive_cap" && [ "$cfmgr_archive_cap" -gt 0 ] || return 2
	case $cfmgr_archive_mode in
	count | meta | digest | gunzip-test | hexdump)
		[ "$#" -eq 1 ] && [ "$cfmgr_archive_cap" = 4096 ] && cfmgr_archive_input "$1" || return 2
		case $cfmgr_archive_mode in
		count) cfmgr_archive_tool=$cfmgr_store_wc ;;
		meta) cfmgr_archive_tool=$cfmgr_store_ls ;;
		digest) cfmgr_archive_tool=$cfmgr_store_openssl ;;
		gunzip-test) cfmgr_archive_tool=/bin/gunzip ;;
		hexdump)
			cfmgr_archive_measure "$1" || return $?
			[ "$cfmgr_archive_bytes" -le 512 ] || return 2
			cfmgr_archive_tool=/usr/bin/hexdump
			;;
		esac
		cfmgr_archive_run "archive-$cfmgr_archive_mode" 4096 "$cfmgr_archive_tool" "$1" || return $?
		;;
	timezone | date)
		[ "$cfmgr_archive_cap" = 4096 ] || return 2
		case $cfmgr_archive_mode in
		timezone)
			[ "$#" -eq 0 ] || return 2
			cfmgr_archive_run archive-timezone 4096 /bin/nvram time_zone_x || return $?
			;;
		date)
			[ "$#" -eq 1 ] || return 2
			cfmgr_archive_run archive-date 4096 /bin/date "$1" || return $?
			;;
		esac
		;;
	gzip | gunzip | tar-list | tar-verbose | tar-bodies | metahex | base64)
		[ "$#" -eq 2 ] && cfmgr_archive_input "$1" && cfmgr_archive_output_path "$2" || return 2
		cfmgr_archive_output=$2
		case $cfmgr_archive_mode in gzip) cfmgr_archive_tool=/bin/gzip ;; gunzip) cfmgr_archive_tool=/bin/gunzip ;; metahex) cfmgr_archive_tool=/usr/bin/hexdump ;; base64) cfmgr_archive_tool=$cfmgr_store_openssl ;; *) cfmgr_archive_tool=/bin/tar ;; esac
		cfmgr_archive_run "archive-$cfmgr_archive_mode" "$cfmgr_archive_cap" "$cfmgr_archive_tool" \
			"$1" "$cfmgr_archive_anchor" "$cfmgr_archive_directory" "$cfmgr_archive_name" || return $?
		;;
	tar-create)
		[ "$#" -eq 3 ] && [ "$1" = "${cfmgr_archive_stage:-}" ] && cfmgr_archive_input "$2" && cfmgr_archive_output_path "$3" || return 2
		cfmgr_archive_output=$3
		cfmgr_archive_run archive-tar-create "$cfmgr_archive_cap" /bin/tar \
			"/proc/self/fd/7/$cfmgr_archive_stage_leaf" "$cfmgr_archive_anchor" "$cfmgr_archive_directory" "$cfmgr_archive_name" "$2" || return $?
		;;
	*) return 2 ;;
	esac
	cfmgr_archive_receipt_out=$cfmgr_probe_stdout cfmgr_archive_receipt_err=$cfmgr_probe_stderr
	[ -n "$cfmgr_archive_output" ] || cfmgr_archive_output=$cfmgr_probe_stdout
	cfmgr_archive_measure "$cfmgr_archive_output" || return $?
	[ "$cfmgr_archive_bytes" -le "$cfmgr_archive_cap" ] || return 1
	cfmgr_probe_stdout=$cfmgr_archive_receipt_out cfmgr_probe_stderr=$cfmgr_archive_receipt_err
}

cfmgr_archive_copy() {
	cfmgr_archive_identity_check || return $?
	if _cfmgr_archive_copy "$@"; then
		if cfmgr_archive_identity_check; then cfmgr_archive_copy_result=0; else cfmgr_archive_copy_result=$?; fi
	else cfmgr_archive_copy_result=$?; fi
	if [ "${cfmgr_probe_status:-}" = reaped ]; then cfmgr_archive_append_path=''; fi
	return "$cfmgr_archive_copy_result"
}

_cfmgr_archive_copy() {
	# INPUT NEW_OUTPUT OFFSET LENGTH. Exact initial prefix/range; appended bytes
	# beyond LENGTH are ignored. The controller separately checks source identity,
	# initial size and allowed writer policy before/after this operation.
	[ "$#" -eq 4 ] && cfmgr_archive_input "$1" && cfmgr_archive_output_path "$2" &&
		cfmgr_archive_uint "$3" && cfmgr_archive_uint "$4" || return 2
	[ "$3" -le "$((9223372036854775296 - $4))" ] || return 2
	cfmgr_archive_output=''
	cfmgr_archive_copy_input=$1 cfmgr_archive_copy_output=$2 cfmgr_archive_copy_offset=$3 cfmgr_archive_copy_length=$4
	cfmgr_archive_copy_blocks=$(($4 / 4096)) cfmgr_archive_copy_tail=$(($4 % 4096))
	cfmgr_archive_copy_anchor=$cfmgr_archive_anchor cfmgr_archive_copy_directory=$cfmgr_archive_directory cfmgr_archive_copy_name=$cfmgr_archive_name
	cfmgr_archive_attachment_ok || return 1
	if [ "$4" -gt 0 ] && [ "$4" -le 4096 ]; then
		cfmgr_archive_run archive-copy-small "$4" /bin/dd "$1" "$cfmgr_archive_copy_anchor" \
			"$cfmgr_archive_copy_directory" "$cfmgr_archive_copy_name" "$3" "$4" || return $?
		cfmgr_archive_measure "$cfmgr_archive_copy_output" || return $?
		[ "$cfmgr_archive_bytes" = "$cfmgr_archive_copy_length" ] || return 1
		cfmgr_archive_output=$cfmgr_archive_copy_output
		return 0
	fi
	if [ "$cfmgr_archive_copy_blocks" -gt 0 ]; then
		cfmgr_archive_run archive-copy-blocks "$4" /bin/dd "$1" "$cfmgr_archive_copy_anchor" \
			"$cfmgr_archive_copy_directory" "$cfmgr_archive_copy_name" "$3" "$cfmgr_archive_copy_blocks" || return $?
	else
		# dd count0 retains exclusive creation and anchored zero-length handling.
		cfmgr_archive_run archive-copy-blocks 4096 /bin/dd "$1" "$cfmgr_archive_copy_anchor" \
			"$cfmgr_archive_copy_directory" "$cfmgr_archive_copy_name" "$3" 0 || return $?
	fi
	cfmgr_archive_measure "$2" || return $?
	[ "$cfmgr_archive_bytes" = "$((cfmgr_archive_copy_blocks * 4096))" ] || return 1
	if [ "$cfmgr_archive_copy_tail" -gt 0 ]; then
		cfmgr_archive_run archive-meta 4096 "$cfmgr_store_ls" "$cfmgr_archive_copy_output" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_archive_append_inode cfmgr_archive_inode_rest <<EOF_ARCHIVE_COPY_INODE
$cfmgr_store_line
EOF_ARCHIVE_COPY_INODE
		cfmgr_archive_uint "$cfmgr_archive_append_inode" && [ "$cfmgr_archive_append_inode" -gt 0 ] || return 1
		cfmgr_archive_append_path=$cfmgr_archive_copy_output
		cfmgr_archive_identity_check || return $?
		cfmgr_archive_run archive-copy-tail "$cfmgr_archive_copy_length" /bin/dd "$cfmgr_archive_copy_input" \
			"$cfmgr_archive_copy_anchor" "$cfmgr_archive_copy_directory" "$cfmgr_archive_copy_name" \
			"$((cfmgr_archive_copy_offset + cfmgr_archive_copy_blocks * 4096))" "$cfmgr_archive_copy_tail" || return $?
		cfmgr_archive_measure "$cfmgr_archive_copy_output" || return $?
	fi
	[ "$cfmgr_archive_bytes" = "$cfmgr_archive_copy_length" ] || return 1
	cfmgr_archive_output=$cfmgr_archive_copy_output
}

# ---- backup archive menu ----
# Source-inert manual archive menu consumer. The installed entry imports this
# after modules/backup.sh; all mutation remains behind reviewed backend actions.
# shellcheck disable=SC2030,SC2031,SC2034

cfmgr_archive_ui_uint() {
	[ "$#" -eq 2 ] || return 1
	case $1 in 0 | [1-9]*) ;; *) return 1 ;; esac
	case $1 in *[!0-9]*) return 1 ;; esac
	[ "${#1}" -le "$2" ]
}

cfmgr_archive_ui_name() {
	[ "$#" -eq 1 ] && [ "${#1}" -lt 64 ] || return 1
	case $1 in CFbackup-*.tar.gz)
		cfmgr_archive_ui_name_stamp=${1#CFbackup-}
		cfmgr_archive_ui_name_stamp=${cfmgr_archive_ui_name_stamp%.tar.gz}
		;;
	*) return 1 ;; esac
	[ -n "$cfmgr_archive_ui_name_stamp" ] || return 1
	case $cfmgr_archive_ui_name_stamp in *[!0-9_-]*) return 1 ;; esac
}

cfmgr_archive_ui_parse_frame() {
	[ "${#cfmgr_archive_ui_raw}" -le 8192 ] || return 1
	cfmgr_archive_ui_lines=0 cfmgr_archive_ui_header=0 cfmgr_archive_ui_sentinel=0
	while IFS= read -r cfmgr_archive_ui_line; do
		cfmgr_archive_ui_lines=$((cfmgr_archive_ui_lines + 1))
		[ "$cfmgr_archive_ui_lines" -le 2 ] || return 1
		case $cfmgr_archive_ui_line in
		'CFMGR-ARCHIVE-EXIT '*)
			[ "$cfmgr_archive_ui_sentinel" = 0 ] || return 1
			IFS=' ' read -r cfmgr_archive_ui_tag cfmgr_archive_ui_exit cfmgr_archive_ui_extra <<EOF_ARCHIVE_EXIT
$cfmgr_archive_ui_line
EOF_ARCHIVE_EXIT
			[ "$cfmgr_archive_ui_line" = "CFMGR-ARCHIVE-EXIT $cfmgr_archive_ui_exit" ] && [ -z "$cfmgr_archive_ui_extra" ] || return 1
			case $cfmgr_archive_ui_exit in 0 | 1 | 3) ;; *) return 1 ;; esac
			cfmgr_archive_ui_sentinel=1
			;;
		*)
			[ "$cfmgr_archive_ui_header" = 0 ] && [ "$cfmgr_archive_ui_sentinel" = 0 ] || return 1
			IFS=' ' read -r cfmgr_archive_ui_tag cfmgr_archive_ui_schema cfmgr_archive_ui_result \
				cfmgr_archive_ui_generation cfmgr_archive_ui_pending cfmgr_archive_ui_format \
				cfmgr_archive_ui_keep cfmgr_archive_ui_set_present cfmgr_archive_ui_name_hex \
				cfmgr_archive_ui_retention cfmgr_archive_ui_history cfmgr_archive_ui_end cfmgr_archive_ui_extra <<EOF_ARCHIVE_HEADER
$cfmgr_archive_ui_line
EOF_ARCHIVE_HEADER
			[ "$cfmgr_archive_ui_line" = "CFMGR-ARCHIVE-ACTION 1 $cfmgr_archive_ui_result $cfmgr_archive_ui_generation $cfmgr_archive_ui_pending $cfmgr_archive_ui_format $cfmgr_archive_ui_keep $cfmgr_archive_ui_set_present $cfmgr_archive_ui_name_hex $cfmgr_archive_ui_retention $cfmgr_archive_ui_history END" ] || return 1
			cfmgr_archive_ui_uint "$cfmgr_archive_ui_generation" 20 || return 1
			case $cfmgr_archive_ui_pending in 0 | 1) ;; *) return 1 ;; esac
			case $cfmgr_archive_ui_set_present in 0 | 1) ;; *) return 1 ;; esac
			case $cfmgr_archive_ui_format in - | DMY | MDY | YMD) ;; *) return 1 ;; esac
			case $cfmgr_archive_ui_keep in 0 | 3 | 4 | 5) ;; *) return 1 ;; esac
			case $cfmgr_archive_ui_name_hex in
			-) cfmgr_archive_ui_name_value='' ;;
			*)
				case $cfmgr_archive_ui_name_hex in *[!0-9a-f]*) return 1 ;; esac
				[ "$((${#cfmgr_archive_ui_name_hex} % 2))" = 0 ] && [ "${#cfmgr_archive_ui_name_hex}" -le 126 ] || return 1
				cfmgr_archive_ui_name_value=$(cfmgr_backup_decode "$cfmgr_archive_ui_name_hex") || return 1
				cfmgr_archive_ui_name "$cfmgr_archive_ui_name_value" || return 1
				;;
			esac
			case $cfmgr_archive_ui_retention in none | complete | failed | unresolved) ;; *) return 1 ;; esac
			case $cfmgr_archive_ui_history in none | saved | failed) ;; *) return 1 ;; esac
			cfmgr_archive_ui_header=1
			;;
		esac
	done <<EOF_ARCHIVE_FRAME
$cfmgr_archive_ui_raw
EOF_ARCHIVE_FRAME
	[ "$cfmgr_archive_ui_header:$cfmgr_archive_ui_sentinel" = 1:1 ] || return 1
	case $cfmgr_archive_ui_action_name:$cfmgr_archive_ui_exit:$cfmgr_archive_ui_result in
	read:0:read | preferences:0:saved | preferences:0:unchanged | create:0:created | \
		read:1:unavailable | read:1:busy | read:1:recovery | read:1:failed | \
		preferences:1:unavailable | preferences:1:busy | preferences:1:recovery | preferences:1:failed | \
		create:1:unavailable | create:1:busy | create:1:recovery | create:1:preferences-needed | create:1:failed | create:1:collision | \
		read:3:unresolved | preferences:3:unresolved | create:3:unresolved) ;;
	*) return 1 ;;
	esac
	if [ "$cfmgr_archive_ui_exit" = 3 ]; then [ "$cfmgr_archive_ui_pending" = 1 ] || return 1; fi
	if [ "$cfmgr_archive_ui_action_name" = create ] && [ "$cfmgr_archive_ui_result" = created ]; then
		[ -n "$cfmgr_archive_ui_name_value" ] || return 1
		case $cfmgr_archive_ui_retention:$cfmgr_archive_ui_history in complete:saved | complete:failed | failed:saved | failed:failed) ;; *) return 1 ;; esac
	elif [ "$cfmgr_archive_ui_action_name" = create ] && [ "$cfmgr_archive_ui_result" = unresolved ]; then
		: # A published archive may still be before retention and history updates.
	else
		[ "$cfmgr_archive_ui_name_hex:$cfmgr_archive_ui_retention:$cfmgr_archive_ui_history" = '-:none:none' ] || return 1
	fi
	case $cfmgr_archive_ui_action_name:$cfmgr_archive_ui_result in
	read:read | preferences:saved | preferences:unchanged | create:created | \
		read:unavailable | read:busy | read:recovery | read:failed | read:unresolved | \
		preferences:unavailable | preferences:busy | preferences:recovery | preferences:failed | preferences:unresolved | \
		create:unavailable | create:busy | create:recovery | create:preferences-needed | create:failed | create:collision | create:unresolved) ;;
	*) return 1 ;;
	esac
	case $cfmgr_archive_ui_action_name:$cfmgr_archive_ui_result in
	read:read | preferences:saved | preferences:unchanged | create:created)
		[ "$cfmgr_archive_ui_generation" != 0 ] || return 1
		;;
	*) : ;; # Failure can follow a successful read of a known generation.
	esac
}

cfmgr_archive_ui_clear() {
	cfmgr_archive_ui_result=unknown cfmgr_archive_ui_generation=0 cfmgr_archive_ui_pending=1
	cfmgr_archive_ui_format=- cfmgr_archive_ui_keep=0 cfmgr_archive_ui_set_present=0
	cfmgr_archive_ui_name_hex=- cfmgr_archive_ui_name_value=''
	cfmgr_archive_ui_retention=none cfmgr_archive_ui_history=none cfmgr_archive_ui_exit=3
	cfmgr_archive_ui_preferences_known=0
}

cfmgr_backup_archive_ui_action() {
	cfmgr_archive_ui_action_name=$1
	cfmgr_archive_ui_clear
	cfmgr_archive_ui_raw=$(
		cfmgr_archive_action "$@"
		cfmgr_archive_ui_action_exit=$?
		printf 'CFMGR-ARCHIVE-EXIT %s\n' "$cfmgr_archive_ui_action_exit"
	)
	if cfmgr_archive_ui_parse_frame; then :; else
		printf '[CFMGR] backup: error: invalid archive backend result; archive state is unknown\n' >&2
		cfmgr_archive_ui_clear
		return 3
	fi
}

cfmgr_backup_archive_ui_read() {
	if cfmgr_backup_archive_ui_action read; then :; else
		cfmgr_archive_ui_preferences_known=0
		cfmgr_archive_ui_set_present=0 cfmgr_archive_ui_format=- cfmgr_archive_ui_keep=0
		case $cfmgr_archive_ui_result in
		unknown) return 3 ;;
		busy) printf '[CFMGR] backup: warning: archive settings lock is busy; preferences are unknown\n' >&2 ;;
		unresolved) printf '[CFMGR] backup: error: archive operation is unresolved; leaving Backup / Restore\n' >&2 ;;
		*) printf '[CFMGR] backup: warning: archive preferences are unavailable\n' >&2 ;;
		esac
		[ "$cfmgr_archive_ui_exit" != 3 ] || return 3
		return 1
	fi
	if [ "$cfmgr_archive_ui_exit" != 0 ]; then
		cfmgr_archive_ui_preferences_known=0
		cfmgr_archive_ui_set_present=0 cfmgr_archive_ui_format=- cfmgr_archive_ui_keep=0
		case $cfmgr_archive_ui_result in
		unknown) return 3 ;;
		busy) printf '[CFMGR] backup: warning: archive settings lock is busy; preferences are unknown\n' >&2 ;;
		unresolved)
			printf '[CFMGR] backup: error: archive operation is unresolved; leaving Backup / Restore\n' >&2
			return 3
			;;
		*) printf '[CFMGR] backup: warning: archive preferences are unavailable\n' >&2 ;;
		esac
		return 1
	fi
	cfmgr_archive_ui_preferences_known=1
}

cfmgr_backup_archive_preferences() {
	if cfmgr_backup_archive_ui_read; then :; else
		cfmgr_archive_ui_read_code=$?
		[ "$cfmgr_archive_ui_read_code" != 3 ] || return 3
	fi
	if [ "$cfmgr_archive_ui_preferences_known" = 1 ] && { [ "$cfmgr_archive_ui_format" != - ] || [ "$cfmgr_archive_ui_keep" != 0 ]; }; then
		printf 'Current date order: %s. Choose DMY (31/12/2026), MDY (12/31/2026), or YMD (2026-12-31).\n' "$cfmgr_archive_ui_format"
	else
		printf '%s\n' 'Choose date order: DMY (31/12/2026), MDY (12/31/2026), or YMD (2026-12-31).'
	fi
	printf '%s' 'Date order (DMY/MDY/YMD, or e to cancel): '
	IFS= read -r cfmgr_archive_ui_new_format || return 0
	[ "$cfmgr_archive_ui_new_format" != e ] || return 0
	case $cfmgr_archive_ui_new_format in DMY | MDY | YMD) ;; *)
		printf '%s\n' 'Invalid date order.'
		return 0
		;;
	esac
	if [ "$cfmgr_archive_ui_preferences_known" = 1 ] && [ "$cfmgr_archive_ui_set_present" = 1 ]; then
		printf 'Current retention: %s archives. Choose 3, 4, or 5.\n' "$cfmgr_archive_ui_keep"
	else printf '%s\n' 'Choose retention: 3, 4, or 5 archives.'; fi
	printf '%s' 'Retention (3/4/5, or e to cancel): '
	IFS= read -r cfmgr_archive_ui_new_keep || return 0
	[ "$cfmgr_archive_ui_new_keep" != e ] || return 0
	case $cfmgr_archive_ui_new_keep in 3 | 4 | 5) ;; *)
		printf '%s\n' 'Invalid retention.'
		return 0
		;;
	esac
	printf 'Save archive preferences: %s date order, retain %s archives? [y/N/e] ' "$cfmgr_archive_ui_new_format" "$cfmgr_archive_ui_new_keep"
	IFS= read -r cfmgr_archive_ui_answer || return 0
	case $cfmgr_archive_ui_answer in y | Y | yes | YES) ;; e) return 0 ;; *)
		printf '%s\n' 'Preference change cancelled; no changes were written.'
		return 0
		;;
	esac
	if cfmgr_backup_archive_ui_action preferences "$cfmgr_archive_ui_new_format" "$cfmgr_archive_ui_new_keep" && [ "$cfmgr_archive_ui_exit" = 0 ]; then
		cfmgr_archive_ui_preferences_known=1
		printf 'Archive preferences %s: %s date order, retain %s archives. Existing archives were not pruned.\n' \
			"$cfmgr_archive_ui_result" "$cfmgr_archive_ui_new_format" "$cfmgr_archive_ui_new_keep"
	else
		case $cfmgr_archive_ui_result in
		unknown) return 3 ;;
		busy) printf '[CFMGR] backup: warning: archive settings lock is busy; preferences were not saved\n' >&2 ;;
		unresolved)
			printf '[CFMGR] backup: error: archive preference save is unresolved; leaving Backup / Restore\n' >&2
			return 3
			;;
		*) printf '[CFMGR] backup: warning: archive preferences were not saved (%s)\n' "$cfmgr_archive_ui_result" >&2 ;;
		esac
	fi
}

cfmgr_backup_archive_create() {
	if [ "${cfmgr_archive_ui_preferences_known:-0}" != 1 ]; then
		printf '%s\n' 'Archive preferences are unknown; review option 3 before creating an archive.'
		return 0
	fi
	case $cfmgr_archive_ui_format:$cfmgr_archive_ui_keep in
	DMY:3 | DMY:4 | DMY:5 | MDY:3 | MDY:4 | MDY:5 | YMD:3 | YMD:4 | YMD:5) ;;
	*)
		printf '%s\n' 'Choose archive date order and retention in option 3 before creating an archive.'
		return 0
		;;
	esac
	printf '%s\n' \
		"Create a manual CFMgr data archive using $cfmgr_archive_ui_format dates and retaining $cfmgr_archive_ui_keep archives?" \
		'Archive contents are unencrypted and may contain operational credentials.' \
		'Files are written with private permissions where supported; filesystem privacy is best-effort.'
	printf '%s' 'Create archive? [y/N/e] '
	IFS= read -r cfmgr_archive_ui_answer || return 0
	case $cfmgr_archive_ui_answer in y | Y | yes | YES) ;; e) return 0 ;; *)
		printf '%s\n' 'Archive creation cancelled; no changes were made.'
		return 0
		;;
	esac
	if cfmgr_backup_archive_ui_action create && [ "$cfmgr_archive_ui_exit" = 0 ]; then
		printf 'Archive created: %s\n' "$cfmgr_archive_ui_name_value"
		case $cfmgr_archive_ui_retention in complete) printf '%s\n' 'Archive retention completed.' ;; failed) printf '%s\n' 'Archive created, but retention did not complete.' >&2 ;; esac
		case $cfmgr_archive_ui_history in saved) printf '%s\n' 'Archive history saved.' ;; failed) printf '%s\n' 'Archive created, but history was not saved.' >&2 ;; esac
	else
		case $cfmgr_archive_ui_result in
		unknown) return 3 ;;
		unresolved)
			printf '[CFMGR] backup: error: archive operation is unresolved; leaving Backup / Restore\n' >&2
			[ -z "$cfmgr_archive_ui_name_value" ] || printf 'Published archive name: %s\n' "$cfmgr_archive_ui_name_value"
			return 3
			;;
		busy) printf '[CFMGR] backup: warning: archive storage or settings lock is busy\n' >&2 ;;
		preferences-needed) printf '%s\n' 'Set archive date order and retention in option 3 before creating an archive.' ;;
		collision) printf '%s\n' 'An archive with that name already exists; no archive was replaced.' ;;
		*) printf '[CFMGR] backup: warning: archive was not created (%s)\n' "$cfmgr_archive_ui_result" >&2 ;;
		esac
	fi
}

# ---- backup archive resources ----
# Source-inert measured RAM/disk admission for manual archives. Resource limits
# bound temporary work; they do not alter saved logging size/count policies.
# shellcheck disable=SC2034,SC2154

cfmgr_archive_resources() {
	cfmgr_archive_run archive-memory 4096 "$cfmgr_store_awk" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" && cfmgr_archive_uint "$cfmgr_store_line" || return 1
	[ "$cfmgr_store_line" -gt 16384 ] && [ "$cfmgr_store_line" -le 9007199254740 ] || return 1
	cfmgr_archive_memory_kib=$((cfmgr_store_line - 8192))
	cfmgr_archive_inventory_limit=$((cfmgr_archive_memory_kib * 1024 / 32))
	[ "$cfmgr_archive_inventory_limit" -le 16777216 ] || cfmgr_archive_inventory_limit=16777216
	cfmgr_archive_directory_kib=$((cfmgr_archive_memory_kib / 4))
	[ "$cfmgr_archive_directory_kib" -le 65536 ] || cfmgr_archive_directory_kib=65536
	[ "$cfmgr_archive_directory_kib" -ge 8192 ] && [ "$cfmgr_archive_inventory_limit" -ge 65536 ] || return 1
	cfmgr_archive_format_retire
}

cfmgr_archive_space() {
	cfmgr_archive_identity_check || return $?
	cfmgr_archive_run archive-space 4096 /bin/df /proc/self/fd/7 || return $?
	cfmgr_archive_space_receipt=$cfmgr_probe_stdout
	cfmgr_archive_run archive-space-values 4096 "$cfmgr_store_awk" "$cfmgr_archive_space_receipt" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" && cfmgr_archive_uint "$cfmgr_store_line" || return 1
	[ "$cfmgr_store_line" -le 9007199254740 ] || return 1
	cfmgr_archive_free=$((cfmgr_store_line * 1024))
	cfmgr_archive_identity_check
}

cfmgr_archive_space_reserve() {
	# Capture retains payload, writer tar, gzip, verifier raw/body/slice and
	# metadata hex. Re-admit against actual free space before every full file.
	cfmgr_archive_uint "$1" || return 2
	cfmgr_archive_space || return $?
	cfmgr_archive_reserve_payload=${cfmgr_capture_payload_bytes:-0}
	[ "$1" -le "$((9223372036854775296 / 16 - cfmgr_archive_reserve_payload))" ] || return 1
	cfmgr_archive_reserve_payload=$((cfmgr_archive_reserve_payload + $1))
	cfmgr_archive_reserve_metadata=$((${cfmgr_capture_inventory_bytes:-0} + 4096))
	cfmgr_archive_reserve_headers=$((${cfmgr_capture_files:-0} + 3))
	# Include semantic YAML's three-byte hex scratch and worst-case compressed
	# output; creation retires original payload/raw before semantic verification.
	cfmgr_archive_required=$((cfmgr_archive_reserve_payload * 10 + cfmgr_archive_reserve_metadata * 16 + cfmgr_archive_reserve_headers * 16384 + 1048576))
	[ "$cfmgr_archive_required" -gt 0 ] && [ "$cfmgr_archive_free" -ge "$cfmgr_archive_required" ]
}

cfmgr_archive_uuid() {
	# The kernel generates an opaque ID; reads do not touch persistent config.
	IFS= read -r cfmgr_archive_uuid </proc/sys/kernel/random/uuid || return 1
	case $cfmgr_archive_uuid in *[!0-9a-f-]*) return 1 ;; esac
	IFS=- read -r cfmgr_archive_u1 cfmgr_archive_u2 cfmgr_archive_u3 cfmgr_archive_u4 cfmgr_archive_u5 cfmgr_archive_u6 <<EOF_ARCHIVE_UUID
$cfmgr_archive_uuid
EOF_ARCHIVE_UUID
	[ "${#cfmgr_archive_uuid}:${#cfmgr_archive_u1}:${#cfmgr_archive_u2}:${#cfmgr_archive_u3}:${#cfmgr_archive_u4}:${#cfmgr_archive_u5}:${#cfmgr_archive_u6}" = 36:8:4:4:4:12:0 ]
}

cfmgr_archive_clock() {
	cfmgr_archive_io timezone 4096 || return $?
	cfmgr_store_read_line "$cfmgr_archive_output" || return 1
	cfmgr_archive_zone=$cfmgr_store_line
	cfmgr_archive_zone_hex=$(cfmgr_backup_hex "$cfmgr_archive_zone") || return 1
	cfmgr_archive_io date 4096 "$cfmgr_archive_zone" || return $?
	cfmgr_store_read_line "$cfmgr_archive_output" || return 1
	IFS='|' read -r cfmgr_archive_epoch cfmgr_archive_day cfmgr_archive_clock_time cfmgr_archive_offset cfmgr_archive_clock_extra <<EOF_ARCHIVE_DATE
$cfmgr_store_line
EOF_ARCHIVE_DATE
	[ -z "$cfmgr_archive_clock_extra" ] && [ "$cfmgr_store_line" = "$cfmgr_archive_epoch|$cfmgr_archive_day|$cfmgr_archive_clock_time|$cfmgr_archive_offset" ] || return 1
	cfmgr_archive_uint "$cfmgr_archive_epoch" && [ "${#cfmgr_archive_epoch}" -le 10 ] || return 1
	case $cfmgr_archive_day:$cfmgr_archive_clock_time:$cfmgr_archive_offset in
	[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]:[0-9][0-9]-[0-9][0-9]-[0-9][0-9]:[+-][0-9][0-9][0-9][0-9]) ;;
	*) return 1 ;;
	esac
	cfmgr_archive_year=${cfmgr_archive_day%%-*} cfmgr_archive_monthday=${cfmgr_archive_day#*-}
	cfmgr_archive_month=${cfmgr_archive_monthday%-*} cfmgr_archive_date=${cfmgr_archive_monthday#*-}
	case $cfmgr_archive_saved_format in
	DMY) cfmgr_archive_date_label=$cfmgr_archive_date-$cfmgr_archive_month-$cfmgr_archive_year ;;
	MDY) cfmgr_archive_date_label=$cfmgr_archive_month-$cfmgr_archive_date-$cfmgr_archive_year ;;
	YMD) cfmgr_archive_date_label=$cfmgr_archive_day ;;
	*) return 1 ;;
	esac
	# Complete calendar/offset validation also occurs in the manifest verifier
	# before publication. Neither the filename nor router locale selects order.
	cfmgr_archive_format_retire
}

# ---- backup archive transaction ----
# Source-inert private stage, complete candidate recognition and publication.
# Only the manual controller calls these functions while config exclusion holds.
# shellcheck disable=SC2034,SC2154,SC3013

cfmgr_archive_ram_new() {
	cfmgr_create_ram_serial=$((${cfmgr_create_ram_serial:-0} + 1))
	cfmgr_create_ram=$cfmgr_store_context/create-$cfmgr_create_ram_serial
	(
		umask 077
		set -C
		cd /proc/self/fd/5 && : >"${cfmgr_create_ram##*/}"
	) || return 1
}

cfmgr_archive_ram_preserve() {
	cfmgr_create_preserve_input=$1
	cfmgr_archive_measure "$1" || return $?
	[ "$cfmgr_archive_bytes" -le "$cfmgr_archive_inventory_limit" ] || return 1
	cfmgr_create_ram_serial=$((${cfmgr_create_ram_serial:-0} + 1))
	cfmgr_create_ram=$cfmgr_store_context/create-$cfmgr_create_ram_serial
	cfmgr_archive_copy "$cfmgr_create_preserve_input" "$cfmgr_create_ram" 0 "$cfmgr_archive_bytes"
}

cfmgr_archive_stage_open() {
	cfmgr_archive_uuid || return 1
	cfmgr_create_id=$cfmgr_archive_uuid
	cfmgr_archive_stage_leaf=.create.$cfmgr_create_id
	[ ! -e "/proc/self/fd/7/$cfmgr_archive_stage_leaf" ] && [ ! -L "/proc/self/fd/7/$cfmgr_archive_stage_leaf" ] || return 1
	cfmgr_archive_run archive-stage-mkdir 4096 /bin/mkdir /proc/self/fd/7 "$cfmgr_backup_mount/CFBackup" "$cfmgr_archive_stage_leaf" || return $?
	cfmgr_archive_stage=$cfmgr_backup_mount/CFBackup/$cfmgr_archive_stage_leaf
	# Initial admission is the only stage operation without a saved inode.
	cfmgr_archive_inode "/proc/self/fd/7/$cfmgr_archive_stage_leaf" || return $?
	cfmgr_archive_stage_inode=$cfmgr_archive_inode
	cfmgr_archive_identity_check || return $?
	if cfmgr_archive_run archive-chmod 4096 /bin/chmod /proc/self/fd/7 "$cfmgr_backup_mount/CFBackup" "$cfmgr_archive_stage_leaf" 700; then :; else
		[ "$?" != 3 ] || return 3
	fi
	cfmgr_archive_identity_check && cfmgr_archive_format_retire
}

cfmgr_archive_stage_close() {
	[ -n "${cfmgr_archive_stage:-}" ] || return 0
	cfmgr_archive_identity_check && cfmgr_archive_format_cleanup || return $?
	cfmgr_create_closing_stage=$cfmgr_archive_stage
	# The directory intentionally disappears during this one supervised rmdir.
	# Parent/root pins remain active; no stage file operation follows this phase.
	cfmgr_archive_stage=''
	if cfmgr_archive_run archive-stage-rmdir 4096 /bin/rmdir /proc/self/fd/7 "$cfmgr_backup_mount/CFBackup" "$cfmgr_archive_stage_leaf"; then :; else
		cfmgr_create_close_code=$? cfmgr_archive_stage=$cfmgr_create_closing_stage
		return "$cfmgr_create_close_code"
	fi
	[ ! -e "/proc/self/fd/7/$cfmgr_archive_stage_leaf" ] && [ ! -L "/proc/self/fd/7/$cfmgr_archive_stage_leaf" ] || return 1
	cfmgr_archive_stage='' cfmgr_archive_stage_leaf='' cfmgr_archive_stage_inode=''
	cfmgr_archive_format_retire
}

cfmgr_archive_verify_owned() {
	# The caller's compressed/raw files must survive the verifier's scratch
	# cleanup. Preserve its exact ownership ledger independently in all outcomes.
	cfmgr_archive_verification_status=incomplete
	cfmgr_create_verify_owned=$cfmgr_format_owned
	cfmgr_archive_format_retire && cfmgr_payload_cleanup || return $?
	cfmgr_format_owned=''
	if cfmgr_archive_format_verify "$1" "$cfmgr_archive_saved_set_id"; then cfmgr_create_verify_code=0; else cfmgr_create_verify_code=$?; fi
	cfmgr_format_owned="${cfmgr_format_owned:+$cfmgr_format_owned }$cfmgr_create_verify_owned"
	cfmgr_archive_format_tracking=1
	if [ "$cfmgr_create_verify_code" = 3 ] || [ "${cfmgr_probe_status:-}" != reaped ]; then return 3; fi
	if cfmgr_payload_cleanup; then :; else
		cfmgr_create_verify_cleanup_code=$?
		cfmgr_archive_verification_status=incomplete
		return "$cfmgr_create_verify_cleanup_code"
	fi
	return "$cfmgr_create_verify_code"
}

cfmgr_archive_existing() {
	# A foreign/corrupt/unsupported regular archive never grants pruning rights.
	# This function's caller cleans owned candidate scratch before continuing.
	cfmgr_create_existing_status=incomplete
	cfmgr_create_existing_name=$1
	cfmgr_create_existing_input=/proc/self/fd/7/$1
	cfmgr_archive_input "$cfmgr_create_existing_input" || return 1
	cfmgr_capture_snapshot "$cfmgr_create_existing_input" "$cfmgr_archive_stage/existing.gz" whole container || return $?
	cfmgr_create_existing_inode=${cfmgr_capture_before_identity%%:*}
	cfmgr_create_existing_size=$cfmgr_capture_bytes cfmgr_create_existing_sha=$cfmgr_capture_sha
	cfmgr_archive_space || return $?
	# Existing compressed bytes are already allocated. Bound expansion against
	# current free space, including the semantic YAML hex/slice peak.
	[ "$cfmgr_archive_free" -gt 1048576 ] || return 1
	cfmgr_create_expand_cap=$(((cfmgr_archive_free - 1048576) / 8))
	[ "$cfmgr_create_expand_cap" -ge 2048 ] || return 1
	cfmgr_archive_format_stream gunzip "$cfmgr_create_expand_cap" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/existing.gz" "$cfmgr_archive_stage/existing.raw" || return $?
	if cfmgr_archive_verify_owned "$cfmgr_archive_stage/existing.raw"; then :; else
		cfmgr_create_existing_code=$?
		cfmgr_create_existing_status=$cfmgr_archive_verification_status
		return "$cfmgr_create_existing_code"
	fi
	[ "$cfmgr_archive_verified" = 1 ] || return 1
	cfmgr_create_record="ARCHIVE $cfmgr_create_existing_name $cfmgr_create_existing_inode $cfmgr_create_existing_size $cfmgr_create_existing_sha $cfmgr_archive_epoch $cfmgr_archive_day $cfmgr_archive_id END"
	cfmgr_archive_ledger_append "$cfmgr_create_record" || return $?
	cfmgr_create_existing_status=verified
}

cfmgr_archive_ledger_append() {
	[ "${#1}" -le 1024 ] || return 1
	cfmgr_create_ledger_bytes=$((${cfmgr_create_ledger_bytes:-0} + ${#1} + 1))
	[ "$cfmgr_create_ledger_bytes" -le "$cfmgr_archive_inventory_limit" ] && cfmgr_archive_attachment_ok || return 1
	# Only generated metadata is appended to our already admitted RAM receipt.
	printf '%s\n' "$1" >>"$cfmgr_create_ledger"
}

cfmgr_archive_recognize_existing() {
	cfmgr_archive_ram_new || return 1
	cfmgr_create_ledger=$cfmgr_create_ram cfmgr_create_ledger_bytes=0 cfmgr_create_scan_complete=0
	cfmgr_archive_identity_check || return $?
	cfmgr_archive_run archive-directory "$cfmgr_archive_inventory_limit" "$cfmgr_store_ls" /proc/self/fd/7 "$cfmgr_backup_mount/CFBackup" "$cfmgr_archive_directory_kib" || return $?
	cfmgr_create_directory=$cfmgr_probe_stdout
	cfmgr_archive_run archive-control "$cfmgr_archive_inventory_limit" "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" names "$cfmgr_create_directory" 0 - || return $?
	cfmgr_archive_ram_preserve "$cfmgr_probe_stdout" || return $?
	cfmgr_create_candidates=$cfmgr_create_ram
	cfmgr_archive_format_retire || return 1
	cfmgr_create_scan_complete=1
	while IFS= read -r cfmgr_create_candidate <&1; do
		cfmgr_archive_identity_check || return $?
		if cfmgr_archive_existing "$cfmgr_create_candidate"; then :; else
			cfmgr_create_candidate_code=$?
			[ "$cfmgr_create_candidate_code" != 3 ] && [ "${cfmgr_probe_status:-}" = reaped ] || return 3
			[ "${cfmgr_create_existing_status:-incomplete}" = excluded ] || cfmgr_create_scan_complete=0
			cfmgr_prerequisites_now && [ "$cfmgr_probe_now" -lt "$cfmgr_archive_deadline" ] && cfmgr_archive_attachment_ok || return 1
		fi
		cfmgr_payload_cleanup && cfmgr_archive_format_cleanup || return $?
	done 1<"$cfmgr_create_candidates"
}

cfmgr_archive_choose_name() {
	cfmgr_archive_clock || return $?
	cfmgr_create_epoch=$cfmgr_archive_epoch cfmgr_create_day=$cfmgr_archive_day
	cfmgr_create_clock=$cfmgr_archive_clock_time cfmgr_create_zone=$cfmgr_archive_zone
	cfmgr_create_zone_hex=$cfmgr_archive_zone_hex cfmgr_create_offset=$cfmgr_archive_offset
	cfmgr_create_same_day=0
	while IFS=' ' read -r cfmgr_create_tag cfmgr_create_old_name cfmgr_create_old_inode cfmgr_create_old_size cfmgr_create_old_sha cfmgr_create_old_epoch cfmgr_create_old_day cfmgr_create_old_id cfmgr_create_old_end <&1; do
		[ "$cfmgr_create_old_day" != "$cfmgr_create_day" ] || cfmgr_create_same_day=1
	done 1<"$cfmgr_create_ledger"
	cfmgr_create_name=CFbackup-$cfmgr_archive_date_label
	[ "$cfmgr_create_same_day" = 0 ] || cfmgr_create_name=${cfmgr_create_name}_$cfmgr_create_clock
	cfmgr_create_name=$cfmgr_create_name.tar.gz
	if [ -e "/proc/self/fd/7/$cfmgr_create_name" ] || [ -L "/proc/self/fd/7/$cfmgr_create_name" ]; then
		cfmgr_create_result=collision
		return 1
	fi
}

cfmgr_archive_build() {
	cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/inventory" || return $?
	cfmgr_create_inventory_sha=$cfmgr_format_hash
	cfmgr_create_manifest="CFMGR-ARCHIVE 1
SET $cfmgr_archive_saved_set_id
ARCHIVE $cfmgr_create_id
CREATED $cfmgr_create_epoch $cfmgr_create_day $cfmgr_create_clock $cfmgr_create_zone_hex $cfmgr_create_offset $cfmgr_archive_saved_format
CONFIG $cfmgr_archive_saved_schema $cfmgr_archive_saved_generation
INVENTORY $((cfmgr_capture_files + cfmgr_capture_notes)) $cfmgr_capture_inventory_bytes $cfmgr_create_inventory_sha $cfmgr_capture_files $cfmgr_capture_payload_bytes
END
"
	cfmgr_archive_write "$cfmgr_archive_stage/manifest" 4096 new "$cfmgr_create_manifest" && cfmgr_archive_format_record "$cfmgr_archive_stage/manifest" || return $?
	cfmgr_archive_ram_new || return 1
	cfmgr_create_members=$cfmgr_create_ram
	printf '%s\n' manifest inventory >>"$cfmgr_create_members" || return 1
	cfmgr_create_member_index=1
	while [ "$cfmgr_create_member_index" -le "$cfmgr_capture_files" ]; do
		printf 'p%08d\n' "$cfmgr_create_member_index" >>"$cfmgr_create_members" || return 1
		cfmgr_create_member_index=$((cfmgr_create_member_index + 1))
	done
	cfmgr_archive_space_reserve 0 || return $?
	cfmgr_create_raw_cap=$((cfmgr_capture_payload_bytes + cfmgr_capture_inventory_bytes + 4096 + (cfmgr_capture_files + 2) * 1024 + 1024))
	[ "$cfmgr_create_raw_cap" -le "$((9223372036854775296 / 2 - 64))" ] || return 1
	if cfmgr_archive_io tar-create "$cfmgr_create_raw_cap" "$cfmgr_archive_stage" "$cfmgr_create_members" "$cfmgr_archive_stage/created.raw"; then cfmgr_create_tar_code=0; else cfmgr_create_tar_code=$?; fi
	if [ "${cfmgr_probe_status:-}" = reaped ] && [ -f "$cfmgr_archive_stage/created.raw" ] && [ ! -L "$cfmgr_archive_stage/created.raw" ]; then
		cfmgr_archive_format_record "$cfmgr_archive_stage/created.raw" || return 1
	fi
	[ "$cfmgr_create_tar_code" = 0 ] || return "$cfmgr_create_tar_code"
	cfmgr_archive_measure "/proc/self/fd/7/$cfmgr_archive_stage_leaf/created.raw" || return $?
	cfmgr_create_raw_bytes=$cfmgr_archive_bytes
	cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/created.raw" || return $?
	cfmgr_create_raw_sha=$cfmgr_format_hash
	cfmgr_create_gzip_cap=$((cfmgr_create_raw_bytes * 2 + 64))
	cfmgr_archive_format_stream gzip "$cfmgr_create_gzip_cap" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/created.raw" "$cfmgr_archive_stage/candidate.tar.gz" || return $?
	cfmgr_archive_format_stream gunzip "$cfmgr_create_raw_bytes" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" "$cfmgr_archive_stage/candidate.raw" || return $?
	[ "$cfmgr_archive_bytes" = "$cfmgr_create_raw_bytes" ] || return 1
	cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.raw" || return $?
	[ "$cfmgr_format_hash" = "$cfmgr_create_raw_sha" ] || return 1
	# Retire original payloads/metadata/raw before semantic YAML scratch grows.
	cfmgr_create_keep_owned='' cfmgr_create_retire_owned=''
	for cfmgr_create_owned_token in $cfmgr_format_owned; do
		case ${cfmgr_create_owned_token%:*} in
		candidate.tar.gz | candidate.raw) cfmgr_create_keep_owned="${cfmgr_create_keep_owned:+$cfmgr_create_keep_owned }$cfmgr_create_owned_token" ;;
		*) cfmgr_create_retire_owned="${cfmgr_create_retire_owned:+$cfmgr_create_retire_owned }$cfmgr_create_owned_token" ;;
		esac
	done
	cfmgr_format_owned=$cfmgr_create_retire_owned
	if cfmgr_archive_format_cleanup; then cfmgr_create_retire_code=0; else cfmgr_create_retire_code=$?; fi
	cfmgr_format_owned="${cfmgr_format_owned:+$cfmgr_format_owned }$cfmgr_create_keep_owned"
	[ "$cfmgr_create_retire_code" = 0 ] || return "$cfmgr_create_retire_code"
	cfmgr_archive_verify_owned "$cfmgr_archive_stage/candidate.raw" || return $?
	[ "$cfmgr_archive_verified:$cfmgr_archive_id:$cfmgr_archive_epoch:$cfmgr_archive_day:$cfmgr_archive_config_generation" = "1:$cfmgr_create_id:$cfmgr_create_epoch:$cfmgr_create_day:$cfmgr_archive_saved_generation" ] || return 1
	cfmgr_archive_format_remove "$cfmgr_archive_stage/candidate.raw"
}

cfmgr_archive_flush_owned() {
	[ "${cfmgr_archive_source_pinned:-0}" != 1 ] && cfmgr_archive_identity_check || return 1
	if (: <&3) 2>/dev/null; then return 2; fi
	[ ! -L "$1" ] && { [ -f "$1" ] || [ -d "$1" ]; } || return 1
	exec 3<"$1" || return 1
	if cfmgr_archive_run archive-flush 4096 "$cfmgr_store_fsync"; then cfmgr_create_flush_code=0; else cfmgr_create_flush_code=$?; fi
	[ "$cfmgr_create_flush_code" != 3 ] || return 3
	exec 3<&-
	[ "$cfmgr_create_flush_code" = 0 ] && cfmgr_archive_identity_check
}

cfmgr_archive_publish() {
	cfmgr_archive_identity_check || return $?
	cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" || return $?
	cfmgr_create_published_sha=$cfmgr_format_hash
	cfmgr_archive_measure "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" || return $?
	cfmgr_create_published_size=$cfmgr_archive_bytes
	cfmgr_archive_format_inode "$cfmgr_archive_stage/candidate.tar.gz" || return $?
	cfmgr_create_published_inode=$cfmgr_format_inode
	if cfmgr_archive_run archive-chmod 4096 /bin/chmod "/proc/self/fd/7/$cfmgr_archive_stage_leaf" "$cfmgr_archive_stage" candidate.tar.gz 600; then :; else [ "$?" != 3 ] || return 3; fi
	cfmgr_archive_flush_owned "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" || return $?
	cfmgr_archive_identity_check || return $?
	# Native mv -n plus absent destination and post-move identity checks preserve
	# cooperative ownership. This is not renameat2 exclusion against root edits.
	if [ -e "/proc/self/fd/7/$cfmgr_create_name" ] || [ -L "/proc/self/fd/7/$cfmgr_create_name" ]; then
		cfmgr_create_result=collision
		return 1
	fi
	cfmgr_create_publish_attempted=1
	if cfmgr_archive_run archive-publish 4096 "$cfmgr_store_mv" "/proc/self/fd/7/$cfmgr_archive_stage_leaf" "$cfmgr_archive_stage" /proc/self/fd/7 "$cfmgr_backup_mount/CFBackup" candidate.tar.gz "$cfmgr_create_name"; then :; else
		cfmgr_create_publish_move_code=$?
		[ "$cfmgr_create_publish_move_code" != 3 ] && [ "${cfmgr_probe_status:-}" = reaped ] || return 3
		# A reaped failed move is ordinary nonpublication only when the pinned
		# destination is still absent and the exact candidate remains intact.
		cfmgr_archive_identity_check || return 3
		[ ! -e "/proc/self/fd/7/$cfmgr_create_name" ] && [ ! -L "/proc/self/fd/7/$cfmgr_create_name" ] || return 3
		cfmgr_archive_format_inode "$cfmgr_archive_stage/candidate.tar.gz" && [ "$cfmgr_format_inode" = "$cfmgr_create_published_inode" ] || return 3
		cfmgr_archive_measure "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" && [ "$cfmgr_archive_bytes" = "$cfmgr_create_published_size" ] || return 3
		cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" && [ "$cfmgr_format_hash" = "$cfmgr_create_published_sha" ] || return 3
		return 1
	fi
	cfmgr_archive_identity_check || return 3
	[ ! -e "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" ] && [ ! -L "/proc/self/fd/7/$cfmgr_archive_stage_leaf/candidate.tar.gz" ] || return 3
	cfmgr_archive_format_inode "/proc/self/fd/7/$cfmgr_create_name" && [ "$cfmgr_format_inode" = "$cfmgr_create_published_inode" ] || return 3
	cfmgr_archive_measure "/proc/self/fd/7/$cfmgr_create_name" && [ "$cfmgr_archive_bytes" = "$cfmgr_create_published_size" ] || return 3
	cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_create_name" && [ "$cfmgr_format_hash" = "$cfmgr_create_published_sha" ] || return 3
	cfmgr_create_published=1 cfmgr_create_name_hex=$(cfmgr_backup_hex "$cfmgr_create_name")
	# The renamed archive leaves temporary cleanup authority immediately.
	cfmgr_create_remaining_owned=''
	for cfmgr_create_owned_token in $cfmgr_format_owned; do
		[ "${cfmgr_create_owned_token%:*}" = candidate.tar.gz ] || cfmgr_create_remaining_owned="${cfmgr_create_remaining_owned:+$cfmgr_create_remaining_owned }$cfmgr_create_owned_token"
	done
	cfmgr_format_owned=$cfmgr_create_remaining_owned
	cfmgr_archive_flush_owned /proc/self/fd/7 || return $?
	cfmgr_create_record="ARCHIVE $cfmgr_create_name $cfmgr_create_published_inode $cfmgr_create_published_size $cfmgr_create_published_sha $cfmgr_create_epoch $cfmgr_create_day $cfmgr_create_id END"
	cfmgr_archive_ledger_append "$cfmgr_create_record"
}

cfmgr_archive_retention() {
	cfmgr_create_retention=failed
	[ "${cfmgr_create_published:-0}" = 1 ] && [ "${cfmgr_create_scan_complete:-0}" = 1 ] || return 1
	cfmgr_prerequisites_now || return 1
	cfmgr_archive_deadline=$((cfmgr_probe_now + 180))
	cfmgr_archive_run archive-control "$cfmgr_archive_inventory_limit" "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" retention "$cfmgr_create_ledger" "$cfmgr_archive_saved_keep" "$cfmgr_create_name" || return $?
	cfmgr_archive_ram_preserve "$cfmgr_probe_stdout" || return $?
	cfmgr_create_prune=$cfmgr_create_ram
	cfmgr_archive_format_retire || return 1
	while IFS=' ' read -r cfmgr_create_tag cfmgr_create_old_name cfmgr_create_old_inode cfmgr_create_old_size cfmgr_create_old_sha cfmgr_create_old_epoch cfmgr_create_old_day cfmgr_create_old_id cfmgr_create_old_end <&1; do
		[ "$cfmgr_create_tag:$cfmgr_create_old_end" = ARCHIVE:END ] && [ "$cfmgr_create_old_name" != "$cfmgr_create_name" ] || return 1
		# Recheck successful new publication before every irreversible old unlink.
		cfmgr_archive_format_inode "/proc/self/fd/7/$cfmgr_create_name" && [ "$cfmgr_format_inode" = "$cfmgr_create_published_inode" ] || return 1
		cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_create_name" && [ "$cfmgr_format_hash" = "$cfmgr_create_published_sha" ] || return 1
		cfmgr_archive_format_inode "/proc/self/fd/7/$cfmgr_create_old_name" && [ "$cfmgr_format_inode" = "$cfmgr_create_old_inode" ] || return 1
		cfmgr_archive_measure "/proc/self/fd/7/$cfmgr_create_old_name" && [ "$cfmgr_archive_bytes" = "$cfmgr_create_old_size" ] || return 1
		cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_create_old_name" && [ "$cfmgr_format_hash" = "$cfmgr_create_old_sha" ] || return 1
		cfmgr_archive_identity_check || return $?
		cfmgr_archive_run archive-archive-remove 4096 /bin/rm /proc/self/fd/7 "$cfmgr_backup_mount/CFBackup" "$cfmgr_create_old_name" || return $?
		cfmgr_archive_identity_check || return $?
		[ ! -e "/proc/self/fd/7/$cfmgr_create_old_name" ] && [ ! -L "/proc/self/fd/7/$cfmgr_create_old_name" ] || return 1
		cfmgr_archive_format_retire || return 1
	done 1<"$cfmgr_create_prune"
	cfmgr_archive_flush_owned /proc/self/fd/7 || return $?
	cfmgr_create_retention=complete
}

# ---- backup capture ----
# Source-inert stable source capture for the explicit archive transaction.
# Config exclusion and any admitted rotation exclusion are held by controller.
# All output is an owned flat stage member; source paths never select code.
# shellcheck disable=SC2034,SC2154

cfmgr_capture_decode() {
	# At most1024 printable ASCII bytes. Pure shell mapping avoids an external
	# decoder or printf escape evaluation while config0/source3 remain pinned.
	cfmgr_capture_encoded=$1 cfmgr_capture_relative='' cfmgr_capture_budget=1024
	cfmgr_capture_ascii=' !"#$%&'"'"'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~'
	case $cfmgr_capture_encoded in '' | *[!0-9a-f]*) return 2 ;; esac
	while :; do
		case $cfmgr_capture_encoded in '') return 0 ;; esac
		case $cfmgr_capture_budget in 0) return 2 ;; esac
		cfmgr_capture_pair=${cfmgr_capture_encoded%"${cfmgr_capture_encoded#??}"}
		case ${#cfmgr_capture_pair} in 2) ;; *) return 2 ;; esac
		cfmgr_capture_value=$((0x$cfmgr_capture_pair))
		case $cfmgr_capture_value in 3[2-9] | [4-9][0-9] | 1[01][0-9] | 12[0-6]) ;; *) return 2 ;; esac
		cfmgr_capture_chars=$cfmgr_capture_ascii cfmgr_capture_index=$((cfmgr_capture_value - 32))
		while :; do
			case $cfmgr_capture_index in 0) break ;; esac
			cfmgr_capture_chars=${cfmgr_capture_chars#?} cfmgr_capture_index=$((cfmgr_capture_index - 1))
		done
		cfmgr_capture_relative=$cfmgr_capture_relative${cfmgr_capture_chars%"${cfmgr_capture_chars#?}"}
		cfmgr_capture_encoded=${cfmgr_capture_encoded#??} cfmgr_capture_budget=$((cfmgr_capture_budget - 1))
	done
}

cfmgr_capture_source() {
	# SCOPE RELATIVE_PATH_HEX. Prove a safe ancestor chain even for absence.
	cfmgr_archive_attachment_ok && cfmgr_capture_decode "$2" || return 1
	case $cfmgr_capture_relative in '' | /* | */../* | ../* | */./* | ./* | */.. | */. | *//* | *\\*) return 1 ;; esac
	case $1 in
	jffs) cfmgr_capture_root=/proc/self/fd/8 cfmgr_capture_original=$cfmgr_store_jffs ;;
	entware)
		[ "${cfmgr_archive_source_pinned:-0}" = 1 ] || return 5
		cfmgr_capture_root=/proc/self/fd/3
		cfmgr_capture_original=$cfmgr_archive_source_root
		;;
	*) return 1 ;;
	esac
	cfmgr_capture_source=$cfmgr_capture_root/$cfmgr_capture_relative
	cfmgr_capture_cursor=$cfmgr_capture_root cfmgr_capture_remaining=$cfmgr_capture_relative
	while :; do
		[ -d "$cfmgr_capture_cursor" ] && [ -r "$cfmgr_capture_cursor" ] && [ -x "$cfmgr_capture_cursor" ] || return 1
		cfmgr_capture_component=${cfmgr_capture_remaining%%/*}
		cfmgr_capture_parent=$cfmgr_capture_cursor cfmgr_capture_original_parent=$cfmgr_capture_original
		cfmgr_capture_cursor=$cfmgr_capture_cursor/$cfmgr_capture_component
		cfmgr_capture_original=$cfmgr_capture_original/$cfmgr_capture_component
		[ ! -L "$cfmgr_capture_cursor" ] || return 1
		if [ ! -e "$cfmgr_capture_cursor" ]; then
			# A failed stat alone cannot distinguish ENOENT from EIO/access
			# failure. Require a successful bounded parent-directory listing.
			cfmgr_archive_identity_check || return $?
			cfmgr_archive_run archive-directory "$cfmgr_archive_inventory_limit" "$cfmgr_store_ls" \
				"$cfmgr_capture_parent/." "$cfmgr_capture_original_parent" "$cfmgr_archive_directory_kib" || return $?
			cfmgr_capture_listing=$cfmgr_probe_stdout
			while IFS= read -r cfmgr_capture_entry <&1; do
				[ "$cfmgr_capture_entry" != "$cfmgr_capture_component" ] || return 1
			done 1<"$cfmgr_capture_listing"
			cfmgr_archive_identity_check || return $?
			return 4
		fi
		case $cfmgr_capture_remaining in */*) cfmgr_capture_remaining=${cfmgr_capture_remaining#*/} ;; *) break ;; esac
	done
	cfmgr_archive_input "$cfmgr_capture_source"
}

cfmgr_capture_metadata() {
	cfmgr_archive_io meta 4096 "$1" || return $?
	cfmgr_store_read_line "$cfmgr_archive_output" || return 1
	IFS=' ' read -r cfmgr_capture_inode cfmgr_capture_mode cfmgr_capture_links cfmgr_capture_uid cfmgr_capture_gid cfmgr_capture_size cfmgr_capture_meta_rest <<EOF_CAPTURE_META
$cfmgr_store_line
EOF_CAPTURE_META
	cfmgr_archive_uint "$cfmgr_capture_inode" && [ "$cfmgr_capture_inode" -gt 0 ] &&
		cfmgr_archive_uint "$cfmgr_capture_size" || return 1
	if [ "${2:-source}" = container ]; then
		# A retained compressed container is inert bytes. FAT/NTFS may emulate
		# executable bits and ownership; its decoded source payload stays strict.
		cfmgr_archive_uint "$cfmgr_capture_uid" && cfmgr_archive_uint "$cfmgr_capture_gid" || return 1
		case $cfmgr_capture_mode in -[r-][w-][x-][r-][w-][x-][r-][w-][x-]) ;; *) return 1 ;; esac
	else
		[ "${2:-source}" = source ] && [ "$cfmgr_capture_uid" = 0 ] || return 1
		# Data only. Do not launder an executable by removing its mode in the tar.
		case $cfmgr_capture_mode in -[r-][w-]-[r-][w-]-[r-][w-]-) ;; *) return 1 ;; esac
	fi
	cfmgr_capture_identity="$cfmgr_capture_inode:$cfmgr_capture_mode:$cfmgr_capture_uid:$cfmgr_capture_gid"
}

cfmgr_capture_snapshot() {
	# INPUT NEW_OUTPUT whole|prefix [source|container]. The strict source
	# profile is default; only retained compressed-container reads select container.
	# Prefix is only for an admitted append-only
	# Cloudflared live writer; ordinary files require stable exact bytes.
	cfmgr_capture_input=$1 cfmgr_capture_output=$2 cfmgr_capture_kind=$3 cfmgr_capture_profile=${4:-source}
	case $cfmgr_capture_profile:$3 in source:whole | source:prefix | container:whole) ;; *) return 2 ;; esac
	case $3 in whole) ;; prefix) [ "${cfmgr_history_lock_held:-0}" = 1 ] || return 1 ;; *) return 2 ;; esac
	cfmgr_capture_metadata "$1" "$cfmgr_capture_profile" || return $?
	cfmgr_capture_before_identity=$cfmgr_capture_identity cfmgr_capture_before_size=$cfmgr_capture_size
	cfmgr_archive_space_reserve "$cfmgr_capture_before_size" || return $?
	if [ "$cfmgr_capture_kind" = whole ]; then
		cfmgr_archive_format_hash "$cfmgr_capture_input" || return $?
		cfmgr_capture_before_sha=$cfmgr_format_hash
	fi
	cfmgr_archive_format_copy "$cfmgr_capture_input" "$cfmgr_capture_output" 0 "$cfmgr_capture_before_size" || return $?
	cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_capture_output##*/}" || return $?
	cfmgr_capture_sha=$cfmgr_format_hash
	if [ "$cfmgr_capture_kind" = whole ]; then
		[ "$cfmgr_capture_sha" = "$cfmgr_capture_before_sha" ] || return 1
		cfmgr_archive_format_hash "$cfmgr_capture_input" || return $?
		[ "$cfmgr_capture_sha" = "$cfmgr_format_hash" ] || return 1
	else
		cfmgr_capture_compare=$cfmgr_archive_stage/capture-prefix-check
		cfmgr_archive_format_copy "$cfmgr_capture_input" "$cfmgr_capture_compare" 0 "$cfmgr_capture_before_size" || return $?
		cfmgr_archive_format_hash "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_capture_compare##*/}" || return $?
		[ "$cfmgr_capture_sha" = "$cfmgr_format_hash" ] || return 1
		cfmgr_archive_format_remove "$cfmgr_capture_compare" || return $?
	fi
	cfmgr_capture_metadata "$cfmgr_capture_input" "$cfmgr_capture_profile" || return $?
	[ "$cfmgr_capture_identity" = "$cfmgr_capture_before_identity" ] || return 1
	if [ "$cfmgr_capture_kind" = whole ]; then
		[ "$cfmgr_capture_size" = "$cfmgr_capture_before_size" ] || return 1
	else [ "$cfmgr_capture_size" -ge "$cfmgr_capture_before_size" ] || return 1; fi
	cfmgr_capture_bytes=$cfmgr_capture_before_size
	cfmgr_archive_identity_check
}

cfmgr_capture_append() {
	# Only parent-generated canonical rows enter this private inventory.
	[ "${#1}" -le 4096 ] && cfmgr_archive_attachment_ok || return 1
	cfmgr_capture_inventory_growth=$((${#1} + 1))
	[ "$cfmgr_capture_inventory_growth" -le "$((cfmgr_archive_inventory_limit - cfmgr_capture_inventory_bytes))" ] || return 1
	cfmgr_archive_write "$cfmgr_capture_inventory" "$cfmgr_archive_inventory_limit" append "$1
" || return $?
	cfmgr_capture_inventory_bytes=$((cfmgr_capture_inventory_bytes + cfmgr_capture_inventory_growth))
}

cfmgr_capture_note() {
	[ "$#" -eq 4 ] || return 2
	cfmgr_capture_append "NOTE $1 $2 $3 $4 END" || return 1
	cfmgr_capture_notes=$((cfmgr_capture_notes + 1))
	cfmgr_archive_format_retire
}

cfmgr_capture_member() {
	[ "$cfmgr_capture_files" -lt 99999999 ] || return 1
	cfmgr_capture_number=00000000$((cfmgr_capture_files + 1))
	cfmgr_capture_member=p${cfmgr_capture_number#"${cfmgr_capture_number%????????}"}
}

_cfmgr_capture_commit() {
	# Internal already-proved snapshot fields: role scope hex generation
	# expected-sha capture member original-sha exact-bytes. No source adoption.
	cfmgr_capture_role=$1 cfmgr_capture_scope=$2 cfmgr_capture_hex=$3 cfmgr_capture_generation=$4
	cfmgr_capture_expected=$5 cfmgr_capture_type=$6 cfmgr_capture_member=$7 cfmgr_capture_sha=$8 cfmgr_capture_bytes=$9
	[ "$cfmgr_capture_expected" = - ] || [ "$cfmgr_capture_sha" = "$cfmgr_capture_expected" ] || return 1
	[ "$cfmgr_capture_bytes" -le "$((9223372036854775296 - cfmgr_capture_payload_bytes))" ] || return 1
	cfmgr_capture_append "FILE $cfmgr_capture_member $cfmgr_capture_role $cfmgr_capture_scope $cfmgr_capture_hex $cfmgr_capture_generation 0600 $cfmgr_capture_bytes $cfmgr_capture_sha $cfmgr_capture_type" || return 1
	cfmgr_capture_files=$((cfmgr_capture_files + 1))
	cfmgr_capture_payload_bytes=$((cfmgr_capture_payload_bytes + cfmgr_capture_bytes))
	cfmgr_capture_last=$cfmgr_archive_stage/$cfmgr_capture_member
	cfmgr_archive_format_retire
}

cfmgr_capture_file() {
	# ROLE SCOPE RELATIVEHEX GENERATION EXPECTEDSHA|- whole|prefix [SNAPSHOT]
	cfmgr_capture_file_role=$1 cfmgr_capture_file_scope=$2 cfmgr_capture_file_hex=$3 cfmgr_capture_file_generation=$4
	cfmgr_capture_file_expected=$5 cfmgr_capture_file_type=$6
	if [ "$#" = 7 ]; then
		cfmgr_archive_input "$7" || return 1
		cfmgr_capture_source=$7
	else cfmgr_capture_source "$2" "$3" || return $?; fi
	cfmgr_capture_member || return 1
	cfmgr_capture_snapshot "$cfmgr_capture_source" "$cfmgr_archive_stage/$cfmgr_capture_member" "$cfmgr_capture_file_type" || return $?
	_cfmgr_capture_commit "$cfmgr_capture_file_role" "$cfmgr_capture_file_scope" "$cfmgr_capture_file_hex" \
		"$cfmgr_capture_file_generation" "$cfmgr_capture_file_expected" "$cfmgr_capture_file_type" \
		"$cfmgr_capture_member" "$cfmgr_capture_sha" "$cfmgr_capture_bytes"
}

cfmgr_capture_start() {
	cfmgr_capture_files=0 cfmgr_capture_notes=0 cfmgr_capture_payload_bytes=0
	cfmgr_capture_inventory=$cfmgr_archive_stage/inventory
	cfmgr_archive_write "$cfmgr_capture_inventory" "$cfmgr_archive_inventory_limit" new 'CFMGR-INVENTORY 1
' || return $?
	cfmgr_archive_format_record "$cfmgr_capture_inventory" || return 1
	cfmgr_capture_inventory_bytes=18
}

cfmgr_capture_finish() {
	cfmgr_capture_append "END $cfmgr_capture_files $cfmgr_capture_notes $cfmgr_capture_payload_bytes" || return 1
	cfmgr_archive_measure "/proc/self/fd/7/$cfmgr_archive_stage_leaf/inventory" || return $?
	[ "$cfmgr_archive_bytes" = "$cfmgr_capture_inventory_bytes" ] && cfmgr_archive_format_retire
}

# ---- backup history ----
# Source-inert read-only Scribe history adapter. Imports no code and never runs
# Scribe, sources configuration, rotates files, repairs cron or creates a lock.
# Parent supplies an admitted private RAM cfmgr_history_context, positive
# cfmgr_history_limit, cfmgr_backup_history_attached and the fixed supervised
# callback cfmgr_backup_history_probe MODE [OPERANDS]. Callbacks export the
# existing cfmgr_probe_{stdout,stderr,status,exit} contract and preserve FD0.
# No stdin-taking child may discard FD0: retain it as FD9 before redirection.
# Private receipt loops borrow FD1 as a read cursor. Callbacks must use their
# explicit private stdout/stderr receipts, never inherited stdout.
#
# Callback modes and exact operands (all output bounded by caller budget):
# parse MODE INPUT [LABEL_OR_FEATURE] [POLICY_OR_ROTATE]: trusted history AWK.
# policy FEATURE JSONHEX: decode admitted policy to bounded RAM; config JSON getter tree
# followed by history AWK policy mode, with independently counted input bytes.
# read PATH: native hexdump -v -e '1/1 "%02x\n"' PATH; script reads only the
# first8192 bytes into owned RAM before this separate supervised hexdump stage.
# hash PATH: native openssl dgst -sha256 -r PATH; meta PATH: native ls -ildn.
# Source read/hash/meta callbacks must first admit the complete ancestor chain
# against retained Entware/JFFS/RAM identities; endpoint ls alone is insufficient.
# During capture use the source FD3 anchor; no bare /opt fallback is admitted.
# read-private PATH: same hexdump, only our owned completed RAM receipts.
# readlink /opt/bin/scribe: native readlink (not -f; exact integration link).
# syslog-version: admitted /opt/sbin/syslog-ng --version.
# syslog-check: admitted /opt/sbin/syslog-ng --syntax-only -f FIXED_CONFIG.
# logrotate-version: admitted /opt/sbin/logrotate --version.
# logrotate-debug: admitted /opt/sbin/logrotate -d /opt/etc/logrotate.conf;
# debug is read-only, never -f; stderr is the expected bounded debug stream.
# cron: fixed native nvram get http_username, validate one bounded account-name
# component, then snapshot existing /var/spool/cron/crontabs/ACCOUNT after full
# native-path admission. Never execute cru or assume root/$USER. list FIXED_DIR:
# native ls -1A FIXED_DIR. Query callbacks return raw completed bounded receipts.
# processes: bounded /proc scan, recheck PID/start around exe+NUL argv reads;
# exact admitted syslog-ng executable inode/mount only, <=64 arguments. Emit
# PROC PID START HEX(/opt/sbin/syslog-ng) ARGC HEX_ARG... END. Preserve actual
# argv; do not infer args from ps or require -F. Unknown ownership is return3.
# Also prove exactly one active native BusyBox crond with admitted actual
# executable/applet argv and effective /var/spool/cron/crontabs directory; emit
# CROND PID START HEX(/var/spool/cron/crontabs) END. Default-directory admission
# needs the retained source profile, not an inference from absent -c alone.
# resolve ABSOLUTE_PATH: native readlink -f, then observed filesystem device
# major:minor from bounded mountinfo plus inode from native ls -id; recheck
# canonical path/identity. Emit RESOLVED CANONICAL_LOWERHEX MAJOR:MINOR INODE END.
# Only existing endpoints are admitted. Foreign logrotate targets are data-only
# observations; they grant no copy/read-content or execution authority.
# lock: admitted existing flock -xn 4; lock FD4 is opened read-only here first.
#
# Observe before destination pinning with admitted writable/executable Entware;
# lock+revalidate after source admission, before capture. Parent owns scratch
# cleanup only after all children are proved quiescent. Return3 preserves evidence.
# shellcheck disable=SC2034,SC2154,SC2094 # Each callback writes fresh receipts.

cfmgr_history_call() {
	cfmgr_backup_history_attached || return 1
	if cfmgr_backup_history_probe "$@"; then :; else return $?; fi
	[ "${cfmgr_probe_status:-}" = reaped ] && [ "${cfmgr_probe_exit:-}" = 0 ] &&
		[ -f "$cfmgr_probe_stdout" ] && [ ! -L "$cfmgr_probe_stdout" ] &&
		[ -f "$cfmgr_probe_stderr" ] && [ ! -L "$cfmgr_probe_stderr" ] || return 1
	# Only debug has expected stderr; the callback supplies its selected stream
	# as stdout without changing exact child status or concealing diagnostics.
	[ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_history_result=$cfmgr_probe_stdout
	cfmgr_backup_history_attached
}

cfmgr_history_new() {
	cfmgr_backup_history_attached && cfmgr_history_runtime_reserve 128 || return 1
	cfmgr_history_serial=$((${cfmgr_history_serial:-0} + 1))
	cfmgr_history_new_path=$cfmgr_history_context/history-$cfmgr_history_serial
	(
		umask 077
		set -C
		cd /proc/self/fd/5 || exit 1
		[ . -ef "$cfmgr_history_context" ] || exit 1
		: >"${cfmgr_history_new_path##*/}"
	) || return 1
	cfmgr_history_runtime_created "$cfmgr_history_new_path" || return $?
	cfmgr_history_owned="${cfmgr_history_owned:+$cfmgr_history_owned }${cfmgr_history_new_path##*/}"
}

cfmgr_history_line() {
	cfmgr_history_line_value='' cfmgr_history_extra=''
	IFS= read -r cfmgr_history_line_value <"$1" || return 1
	{
		IFS= read -r cfmgr_history_line_value && ! IFS= read -r cfmgr_history_extra
	} <"$1" && [ -z "$cfmgr_history_extra" ] || return 1
	cfmgr_history_runtime_consume "$1"
}

cfmgr_history_meta() {
	cfmgr_history_call meta "$1" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	IFS=' ' read -r cfmgr_history_inode cfmgr_history_mode cfmgr_history_links cfmgr_history_uid cfmgr_history_gid cfmgr_history_bytes cfmgr_history_name <<EOF_HISTORY_META
$cfmgr_history_line_value
EOF_HISTORY_META
	case $cfmgr_history_inode:$cfmgr_history_bytes in *[!0-9:]* | :* | *:) return 1 ;; esac
	[ "$cfmgr_history_uid:$cfmgr_history_gid" = 0:0 ] || return 1
	case $cfmgr_history_mode in ?????w* | ????????w*) return 1 ;; esac
	case $2:$cfmgr_history_mode in file:-?????????) [ "$cfmgr_history_links" = 1 ] || return 1 ;; directory:d?????????) ;; *) return 1 ;; esac
	cfmgr_history_meta_value=$cfmgr_history_inode:$cfmgr_history_mode:$cfmgr_history_uid:$cfmgr_history_gid:$cfmgr_history_bytes
}

cfmgr_history_hash() {
	cfmgr_history_call hash "$1" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	IFS=' ' read -r cfmgr_history_digest cfmgr_history_hash_path <<EOF_HISTORY_HASH
$cfmgr_history_line_value
EOF_HISTORY_HASH
	cfmgr_history_hash_path=${cfmgr_history_hash_path#\*}
	[ "${#cfmgr_history_digest}" = 64 ] && [ "$cfmgr_history_hash_path" = "$1" ] || return 1
	case $cfmgr_history_digest in *[!0-9a-f]*) return 1 ;; esac
}

cfmgr_history_read() {
	# PATH LABEL [expected immutable SHA]. All source paths come from fixed
	# constants or the validated direct-child logrotate include inventory.
	cfmgr_history_path=$1 cfmgr_history_label=$2 cfmgr_history_expected=${3:--}
	cfmgr_history_meta "$cfmgr_history_path" file || return $?
	cfmgr_history_before_meta=$cfmgr_history_meta_value
	cfmgr_history_hash "$cfmgr_history_path" || return $?
	cfmgr_history_before_hash=$cfmgr_history_digest
	[ "$cfmgr_history_expected" = - ] || [ "$cfmgr_history_expected" = "$cfmgr_history_before_hash" ] || return 1
	cfmgr_history_call read "$cfmgr_history_path" || return $?
	cfmgr_history_hex_source=$cfmgr_history_result
	cfmgr_history_call parse pack "$cfmgr_history_hex_source" "$cfmgr_history_label" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	cfmgr_history_packed=$cfmgr_history_line_value
	cfmgr_history_meta "$cfmgr_history_path" file || return $?
	[ "$cfmgr_history_meta_value" = "$cfmgr_history_before_meta" ] || return 1
	cfmgr_history_hash "$cfmgr_history_path" || return $?
	[ "$cfmgr_history_digest" = "$cfmgr_history_before_hash" ] || return 1
	cfmgr_history_runtime_write "$cfmgr_history_fingerprints" "$cfmgr_history_path $cfmgr_history_before_hash" || return $?
	[ "$cfmgr_history_label" != fragment ] || return 0
	cfmgr_history_runtime_write "$cfmgr_history_bundle" "$cfmgr_history_packed"
}

cfmgr_history_query() {
	cfmgr_history_query_label=$1
	shift
	cfmgr_history_call "$@" || return $?
	if [ "$cfmgr_history_query_label" = cron ] && [ -n "${cfmgr_hr_cron_fingerprint:-}" ]; then
		cfmgr_history_runtime_write "$cfmgr_history_fingerprints" "$cfmgr_hr_cron_fingerprint" || return $?
	fi
	cfmgr_history_call read-private "$cfmgr_history_result" || return $?
	cfmgr_history_call parse pack "$cfmgr_history_result" "$cfmgr_history_query_label" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	cfmgr_history_runtime_write "$cfmgr_history_bundle" "$cfmgr_history_line_value"
}

cfmgr_history_base() {
	cfmgr_history_call readlink /opt/bin/scribe || return $?
	cfmgr_history_line "$cfmgr_history_result" && [ "$cfmgr_history_line_value" = /jffs/scripts/scribe ] || return 1
	for cfmgr_history_tool in /opt/sbin/syslog-ng /opt/sbin/logrotate; do
		cfmgr_history_hash "$cfmgr_history_tool" || return $?
		cfmgr_history_runtime_write "$cfmgr_history_fingerprints" "$cfmgr_history_tool $cfmgr_history_digest" || return $?
	done
	for cfmgr_history_directory in /opt/etc/syslog-ng.d /opt/etc/logrotate.d /opt/var/log; do
		cfmgr_history_meta "$cfmgr_history_directory" directory || return $?
	done
	cfmgr_history_read /jffs/scripts/scribe script || return $?
	cfmgr_history_read /jffs/addons/scribe.d/config scribe-config || return $?
	cfmgr_history_read /opt/etc/syslog-ng.conf syslog-config || return $?
	cfmgr_history_read /opt/etc/logrotate.conf rotate-config || return $?
	cfmgr_history_query syslog-version syslog-version || return $?
	cfmgr_history_query logrotate-version logrotate-version || return $?
	cfmgr_history_call syslog-check || return $?
	cfmgr_history_query cron cron || return $?
	cfmgr_history_query process processes || return $?
	cfmgr_history_call logrotate-debug || return $?
	cfmgr_history_call read-private "$cfmgr_history_result" || return $?
	cfmgr_history_debug=$cfmgr_history_result
	cfmgr_history_call parse pack "$cfmgr_history_debug" rotate-debug || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	cfmgr_history_runtime_write "$cfmgr_history_bundle" "$cfmgr_history_line_value" || return $?
	cfmgr_history_call parse includes "$cfmgr_history_debug" || return $?
	cfmgr_history_includes_file=$cfmgr_history_result
	while IFS=' ' read -r cfmgr_history_marker cfmgr_history_include_hex cfmgr_history_end cfmgr_history_more <&1; do
		[ "$cfmgr_history_marker:$cfmgr_history_end:$cfmgr_history_more" = INCLUDE:END: ] || return 1
		# Decode is fixed trusted parser mode, never printf backslash expansion.
		cfmgr_history_call parse path "$cfmgr_history_includes_file" "$cfmgr_history_include_hex" || return $?
		cfmgr_history_line "$cfmgr_history_result" || return 1
		cfmgr_history_include=$cfmgr_history_line_value
		[ "$cfmgr_history_include" != /opt/etc/logrotate.conf ] || continue
		cfmgr_history_read "$cfmgr_history_include" fragment || return $?
		# Replace only our generated DATA label; the third field is lowerhex.
		IFS=' ' read -r cfmgr_history_marker cfmgr_history_label cfmgr_history_content <<EOF_HISTORY_FRAGMENT
$cfmgr_history_packed
EOF_HISTORY_FRAGMENT
		cfmgr_history_runtime_write "$cfmgr_history_bundle" "FRAGMENT $cfmgr_history_include_hex $cfmgr_history_content" || return $?
	done 1<"$cfmgr_history_includes_file"
	cfmgr_history_call parse base "$cfmgr_history_bundle" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	case $cfmgr_history_line_value in 'BASE ready '*' END') ;; *) return 1 ;; esac
	cfmgr_history_base_result=$cfmgr_history_line_value
}

cfmgr_backup_history_observe() {
	[ "$#" = 1 ] || return 1
	[ "${cfmgr_history_lock_held:-0}" = 0 ] || return 1
	cfmgr_history_lock_held=0 cfmgr_history_owned=${cfmgr_history_owned:-} cfmgr_history_plan=$1
	_cfmgr_backup_history_observe "$1" || return $?
	cfmgr_history_runtime_checkpoint "$cfmgr_history_output" "$cfmgr_history_fingerprints"
}

_cfmgr_backup_history_observe() {
	cfmgr_history_ready=0 cfmgr_history_base_ready=0 cfmgr_history_has_payload=0
	cfmgr_history_call parse plan "$1" || return $?
	cfmgr_history_requests=$cfmgr_history_result
	cfmgr_history_new || return $?
	cfmgr_history_output=$cfmgr_history_new_path
	cfmgr_history_new || return $?
	cfmgr_history_bundle=$cfmgr_history_new_path
	cfmgr_history_new || return $?
	cfmgr_history_fingerprints=$cfmgr_history_new_path
	cfmgr_history_runtime_write "$cfmgr_history_output" 'CFMGR-HISTORY 1' || return $?
	while IFS=' ' read -r cfmgr_history_marker cfmgr_history_feature cfmgr_history_request cfmgr_history_reason cfmgr_history_generation cfmgr_history_rule_sha cfmgr_history_policy_hex cfmgr_history_end cfmgr_history_more <&1; do
		[ "$cfmgr_history_marker:$cfmgr_history_end:$cfmgr_history_more" = REQUEST:END: ] || return 1
		case $cfmgr_history_feature in ddns | ip_sync | cloudflared) ;; *) return 1 ;; esac
		if [ "$cfmgr_history_request" = request ]; then
			if [ "$cfmgr_history_base_ready" = 0 ]; then
				if cfmgr_history_base; then cfmgr_history_base_ready=1; else
					cfmgr_history_code=$?
					case $cfmgr_history_code in 2 | 3) return "$cfmgr_history_code" ;; esac
					cfmgr_history_base_ready=unavailable
				fi
			fi
			if [ "$cfmgr_history_base_ready" != 1 ]; then
				cfmgr_history_request=unavailable cfmgr_history_reason=scribe-unavailable
			elif cfmgr_history_feature; then
				cfmgr_history_request=$cfmgr_history_feature_state cfmgr_history_reason=eligible-owned-history
			else
				cfmgr_history_code=$?
				case $cfmgr_history_code in 2 | 3) return "$cfmgr_history_code" ;; esac
				cfmgr_history_request=unavailable cfmgr_history_reason=unsupported-or-stale-history
			fi
		fi
		cfmgr_history_runtime_write "$cfmgr_history_output" "STATE $cfmgr_history_feature $cfmgr_history_request $cfmgr_history_reason END" || return $?
	done 1<"$cfmgr_history_requests"
	cfmgr_history_runtime_write "$cfmgr_history_output" END || return $?
	cfmgr_history_ready=1
}

cfmgr_history_feature() {
	cfmgr_history_live_name=$cfmgr_history_feature
	[ "$cfmgr_history_feature" != ip_sync ] || cfmgr_history_live_name=ip-sync
	cfmgr_history_rule=/opt/etc/logrotate.d/cfmgr-$cfmgr_history_live_name
	cfmgr_history_hash "$cfmgr_history_rule" || return $?
	[ "$cfmgr_history_digest" = "$cfmgr_history_rule_sha" ] || return 1
	cfmgr_history_call policy "$cfmgr_history_feature" "$cfmgr_history_policy_hex" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	cfmgr_history_policy=$cfmgr_history_line_value
	cfmgr_history_call parse assess "$cfmgr_history_bundle" "$cfmgr_history_feature" "$cfmgr_history_policy" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	IFS=' ' read -r cfmgr_history_marker cfmgr_history_check_feature cfmgr_history_effective_mode cfmgr_history_effective_size cfmgr_history_rotate cfmgr_history_age cfmgr_history_end cfmgr_history_more <<EOF_HISTORY_EFFECTIVE
$cfmgr_history_line_value
EOF_HISTORY_EFFECTIVE
	[ "$cfmgr_history_marker:$cfmgr_history_check_feature:$cfmgr_history_end:$cfmgr_history_more" = "EFFECTIVE:$cfmgr_history_feature:END:" ] || return 1
	cfmgr_history_effective=$cfmgr_history_line_value
	cfmgr_history_call list /opt/var/log || return $?
	cfmgr_history_call read-private "$cfmgr_history_result" || return $?
	cfmgr_history_call parse family "$cfmgr_history_result" "$cfmgr_history_feature" "$cfmgr_history_rotate" || return $?
	cfmgr_history_members=$cfmgr_history_result
	cfmgr_history_new || return $?
	cfmgr_history_coverage=$cfmgr_history_new_path
	cfmgr_history_resolve /opt || return $?
	cfmgr_history_opt_device=$cfmgr_history_resolved_device
	cfmgr_history_opt_canonical=$cfmgr_history_resolved_canonical
	cfmgr_history_resolve /opt/var/log || return $?
	[ "$cfmgr_history_resolved_device" = "$cfmgr_history_opt_device" ] &&
		[ "$cfmgr_history_resolved_canonical" = "${cfmgr_history_opt_canonical}2f7661722f6c6f67" ] || return 1
	cfmgr_history_log_canonical=$cfmgr_history_resolved_canonical
	cfmgr_history_feature_state=absent
	# Validate every actually enumerated file before publishing any feature row.
	while IFS=' ' read -r cfmgr_history_marker cfmgr_history_pathhex cfmgr_history_kind cfmgr_history_end cfmgr_history_more <&1; do
		[ "$cfmgr_history_marker" != FAMILY ] || continue
		[ "$cfmgr_history_marker:$cfmgr_history_end:$cfmgr_history_more" = MEMBER:END: ] || return 1
		cfmgr_history_call parse path "$cfmgr_history_members" "$cfmgr_history_pathhex" || return $?
		cfmgr_history_line "$cfmgr_history_result" || return 1
		cfmgr_history_member_path=$cfmgr_history_line_value
		cfmgr_history_meta "$cfmgr_history_member_path" file || return $?
		cfmgr_history_member_inode=$cfmgr_history_inode
		cfmgr_history_resolve "$cfmgr_history_member_path" || return $?
		cfmgr_history_member_suffix=${cfmgr_history_pathhex#2f6f70742f7661722f6c6f672f}
		[ "$cfmgr_history_resolved_device" = "$cfmgr_history_opt_device" ] &&
			[ "$cfmgr_history_resolved_inode" = "$cfmgr_history_member_inode" ] &&
			[ "$cfmgr_history_resolved_canonical" = "${cfmgr_history_log_canonical}2f$cfmgr_history_member_suffix" ] || return 1
		cfmgr_history_runtime_write "$cfmgr_history_coverage" "OWN $cfmgr_history_pathhex $cfmgr_history_resolved_canonical $cfmgr_history_resolved_device $cfmgr_history_resolved_inode $cfmgr_history_kind" || {
			cfmgr_history_code=$?
			[ "$cfmgr_history_code" != 3 ] || return 3
			return 2
		}
		cfmgr_history_feature_state=included
	done 1<"$cfmgr_history_members"
	cfmgr_history_call parse targets "$cfmgr_history_debug" "$cfmgr_history_feature" || return $?
	cfmgr_history_targets=$cfmgr_history_result
	while IFS=' ' read -r cfmgr_history_marker cfmgr_history_target_hex cfmgr_history_scope cfmgr_history_exists cfmgr_history_end cfmgr_history_more <&1; do
		[ "$cfmgr_history_marker:$cfmgr_history_end:$cfmgr_history_more" = TARGET:END: ] || return 1
		if [ "$cfmgr_history_exists" = absent ]; then
			cfmgr_history_runtime_write "$cfmgr_history_coverage" "ABSENT $cfmgr_history_target_hex $cfmgr_history_scope" || {
				cfmgr_history_code=$?
				[ "$cfmgr_history_code" != 3 ] || return 3
				return 2
			}
		else
			[ "$cfmgr_history_exists" = present ] || return 1
			cfmgr_history_call parse target-path "$cfmgr_history_targets" "$cfmgr_history_target_hex" || return $?
			cfmgr_history_line "$cfmgr_history_result" || return 1
			cfmgr_history_resolve "$cfmgr_history_line_value" || return $?
			cfmgr_history_runtime_write "$cfmgr_history_coverage" "TARGET $cfmgr_history_target_hex $cfmgr_history_resolved_canonical $cfmgr_history_resolved_device $cfmgr_history_resolved_inode $cfmgr_history_scope" || {
				cfmgr_history_code=$?
				[ "$cfmgr_history_code" != 3 ] || return 3
				return 2
			}
		fi
	done 1<"$cfmgr_history_targets"
	cfmgr_history_call parse audit "$cfmgr_history_coverage" || return $?
	cfmgr_history_runtime_write "$cfmgr_history_output" "$cfmgr_history_effective" || {
		cfmgr_history_code=$?
		[ "$cfmgr_history_code" != 3 ] || return 3
		return 2
	}
	while IFS=' ' read -r cfmgr_history_marker cfmgr_history_pathhex cfmgr_history_kind cfmgr_history_end cfmgr_history_more <&1; do
		[ "$cfmgr_history_marker" != FAMILY ] || continue
		cfmgr_history_runtime_write "$cfmgr_history_output" "FILE history.$cfmgr_history_feature $cfmgr_history_pathhex $cfmgr_history_generation $cfmgr_history_kind END" || {
			cfmgr_history_code=$?
			[ "$cfmgr_history_code" != 3 ] || return 3
			return 2
		}
		cfmgr_history_has_payload=1
	done 1<"$cfmgr_history_members"
}

cfmgr_history_resolve() {
	cfmgr_history_call resolve "$1" || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	IFS=' ' read -r cfmgr_history_marker cfmgr_history_resolved_canonical cfmgr_history_resolved_device cfmgr_history_resolved_inode cfmgr_history_end cfmgr_history_more <<EOF_HISTORY_RESOLVED
$cfmgr_history_line_value
EOF_HISTORY_RESOLVED
	[ "$cfmgr_history_marker:$cfmgr_history_end:$cfmgr_history_more" = RESOLVED:END: ] || return 1
	case $cfmgr_history_resolved_canonical in '' | *[!0-9a-f]*) return 1 ;; esac
	case $cfmgr_history_resolved_device in '' | *[!0-9:]* | :* | *: | *:*:*) return 1 ;; *:*) ;; *) return 1 ;; esac
	case $cfmgr_history_resolved_inode in '' | 0 | *[!0-9]*) return 1 ;; esac
}

cfmgr_backup_history_lock() {
	[ "${cfmgr_history_ready:-0}" = 1 ] && [ "${cfmgr_history_lock_held:-0}" = 0 ] || return 1
	[ "${cfmgr_history_has_payload:-0}" = 1 ] || return 0
	cfmgr_history_rotation_meta || return $?
	cfmgr_history_rotation_identity=$cfmgr_history_meta_value
	[ -f /tmp/scribeLogRotate.flock ] && [ ! -L /tmp/scribeLogRotate.flock ] || return 1
	exec 4</tmp/scribeLogRotate.flock || return 1
	if [ ! /tmp/scribeLogRotate.flock -ef /proc/self/fd/4 ]; then
		exec 4<&-
		return 1
	fi
	if cfmgr_history_call lock; then :; else
		cfmgr_history_code=$?
		if [ "$cfmgr_history_code" = 3 ]; then
			cfmgr_history_lock_held=unresolved
			return 3
		fi
		exec 4<&-
		return "$cfmgr_history_code"
	fi
	cfmgr_history_lock_held=1
	cfmgr_backup_history_revalidate
}

cfmgr_backup_history_revalidate() {
	[ "${cfmgr_history_ready:-0}:${cfmgr_history_lock_held:-0}" = 1:1 ] &&
		[ ! -L /tmp/scribeLogRotate.flock ] && [ /tmp/scribeLogRotate.flock -ef /proc/self/fd/4 ] || return 1
	cfmgr_history_rotation_meta || return $?
	[ "$cfmgr_history_meta_value" = "$cfmgr_history_rotation_identity" ] || return 1
	# Re-evaluate actual tools/schedule/process/include/family scope under the
	# rotation lock. The previous receipt must agree exactly; no newly discovered
	# file becomes payload authority through a changed observation. Reuse the
	# fresh observation's already-checked hashes instead of hashing all sources
	# once here and then again while rebuilding the same evidence.
	cfmgr_history_previous_output=$cfmgr_history_output
	cfmgr_history_previous_fingerprints=$cfmgr_history_fingerprints
	_cfmgr_backup_history_observe "$cfmgr_history_plan" || return $?
	cfmgr_history_call parse compare "$cfmgr_history_fingerprints" "$cfmgr_history_previous_fingerprints" || return $?
	cfmgr_history_call parse compare "$cfmgr_history_output" "$cfmgr_history_previous_output" || return $?
	cfmgr_history_rotation_meta || return $?
	[ "$cfmgr_history_meta_value" = "$cfmgr_history_rotation_identity" ] &&
		[ /tmp/scribeLogRotate.flock -ef /proc/self/fd/4 ] || return 1
	cfmgr_history_output=$cfmgr_history_previous_output
	cfmgr_history_fingerprints=$cfmgr_history_previous_fingerprints
	cfmgr_history_runtime_checkpoint "$cfmgr_history_output" "$cfmgr_history_fingerprints"
}

cfmgr_backup_history_release() {
	[ "${cfmgr_history_lock_held:-0}" != unresolved ] || return 3
	[ "${cfmgr_history_lock_held:-0}" = 1 ] || return 0
	# Capture may have retained archive receipts since the last history probe.
	cfmgr_history_runtime_seed || return 1
	cfmgr_history_rotation_meta || return $?
	[ "$cfmgr_history_meta_value" = "$cfmgr_history_rotation_identity" ] &&
		[ ! -L /tmp/scribeLogRotate.flock ] && [ /tmp/scribeLogRotate.flock -ef /proc/self/fd/4 ] || return 1
	exec 4<&-
	cfmgr_history_lock_held=0
}

# ---- backup history runtime ----
# Production fixed callbacks for the backup history adapter. No repair/installation or
# source-time work. Shared execution/storage/config categories and internal archive
# integer helpers. Parent owns phase transitions and the descriptor lifetimes.
#
# cfmgr_history_runtime_init native|entware|source requires caller-admitted positive
# cfmgr_history_limit, absolute cfmgr_history_deadline and child-only
# cfmgr_history_memory_kib (8192..65536). Initial Entware pins are6/7; capture
# revalidation uses source3 and rotation4. Context5/JFFS8/support9/config0 persist.
# Every external operation below uses the existing direct-child supervisor.
# shellcheck disable=SC2034,SC2154,SC3013,SC2094

cfmgr_history_runtime_init() {
	[ "$#" = 1 ] && cfmgr_archive_uint "${cfmgr_history_limit:-}" && [ "$cfmgr_history_limit" -gt 0 ] || return 2
	# Include receipts created by intervening archive/Store consumers BEFORE
	# any phase-admission probe can allocate another supervised output pair.
	cfmgr_history_runtime_seed || return 1
	# A failed optional phase admission must not change the caller phase/pins.
	cfmgr_hr_saved_phase=${cfmgr_hr_phase:-native} cfmgr_hr_saved_anchor=${cfmgr_hr_anchor:-}
	cfmgr_hr_saved_root=${cfmgr_hr_root:-} cfmgr_hr_saved_snapshot=${cfmgr_hr_snapshot:-}
	if _cfmgr_history_runtime_init "$@"; then
		return 0
	else
		cfmgr_hr_init_code=$?
		cfmgr_hr_phase=$cfmgr_hr_saved_phase cfmgr_hr_anchor=$cfmgr_hr_saved_anchor
		cfmgr_hr_root=$cfmgr_hr_saved_root cfmgr_hr_snapshot=$cfmgr_hr_saved_snapshot
		return "$cfmgr_hr_init_code"
	fi
}

_cfmgr_history_runtime_init() {
	[ "$#" = 1 ] || return 2
	case $1 in
	native) cfmgr_hr_anchor='' cfmgr_hr_root='' cfmgr_hr_snapshot='' ;;
	entware)
		[ "${cfmgr_storage_pinned:-0}" = 1 ] || return 1
		cfmgr_hr_anchor=/proc/self/fd/7 cfmgr_hr_root=$cfmgr_storage_opt
		cfmgr_hr_snapshot=$cfmgr_storage_snapshot
		;;
	source)
		[ "${cfmgr_archive_source_pinned:-0}" = 1 ] || return 1
		cfmgr_hr_anchor=/proc/self/fd/3 cfmgr_hr_root=$cfmgr_archive_source_root
		cfmgr_hr_snapshot=$cfmgr_archive_source_snapshot
		;;
	*) return 2 ;;
	esac
	cfmgr_hr_phase=$1 cfmgr_history_context=$cfmgr_store_context
	cfmgr_archive_uint "${cfmgr_history_limit:-}" && [ "$cfmgr_history_limit" -gt 0 ] &&
		cfmgr_archive_uint "${cfmgr_history_deadline:-}" &&
		cfmgr_archive_uint "${cfmgr_history_memory_kib:-}" &&
		[ "$cfmgr_history_memory_kib" -ge 8192 ] && [ "$cfmgr_history_memory_kib" -le 65536 ] || return 2
	cfmgr_hr_support_relative=${cfmgr_store_source#"$cfmgr_store_jffs"/}
	[ "$cfmgr_hr_support_relative" != "$cfmgr_store_source" ] || return 2
	cfmgr_hr_lib=/proc/self/fd/8/$cfmgr_hr_support_relative/modules/lib
	cfmgr_backup_history_attached || return 1
	if [ "$cfmgr_hr_phase" = native ]; then return 0; fi
	IFS='	' read -r cfmgr_hr_mount_id cfmgr_hr_mount_parent cfmgr_hr_device cfmgr_hr_mount_root cfmgr_hr_mount_point cfmgr_hr_mount_fs cfmgr_hr_mount_source cfmgr_hr_mount_flags cfmgr_hr_mount_super <<EOF_HISTORY_MOUNT
$cfmgr_hr_snapshot
EOF_HISTORY_MOUNT
	case ,$cfmgr_hr_mount_flags, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_hr_mount_super, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_hr_mount_flags,$cfmgr_hr_mount_super, in *,noexec,*) return 1 ;; esac
	cfmgr_backup_history_attached || return 1
	cfmgr_hr_support_relative=${cfmgr_store_source#"$cfmgr_store_jffs"/}
	[ "$cfmgr_hr_support_relative" != "$cfmgr_store_source" ] || return 2
	cfmgr_hr_lib=/proc/self/fd/8/$cfmgr_hr_support_relative/modules/lib
	if [ "$cfmgr_hr_phase" = entware ]; then
		[ "$cfmgr_storage_filesystem:$cfmgr_storage_fsroot:$cfmgr_storage_relative" = \
			"${cfmgr_history_want_filesystem:-}:${cfmgr_history_want_root:-}:${cfmgr_history_want_relative:-}" ] || return 1
		cfmgr_hr_native /sbin/blkid || return $?
		cfmgr_hr_run history-blkid 4096 /sbin/blkid "$cfmgr_storage_source" || return $?
		cfmgr_hr_run history-volume 4096 "$cfmgr_store_awk" "$cfmgr_hr_result" "$cfmgr_storage_source" \
			"$cfmgr_storage_filesystem" "${cfmgr_history_want_uuid:-}" || return $?
		cfmgr_hr_line "$cfmgr_hr_result" && [ "$cfmgr_hr_line" = "UUID $cfmgr_history_want_uuid END" ] || return 1
		cfmgr_hr_initial_root=$cfmgr_hr_root cfmgr_hr_initial_snapshot=$cfmgr_hr_snapshot
	else
		[ "$cfmgr_hr_root:$cfmgr_hr_snapshot" = "${cfmgr_hr_initial_root:-}:${cfmgr_hr_initial_snapshot:-}" ] &&
			[ "${cfmgr_archive_source_want_uuid:-}:${cfmgr_archive_source_want_fs:-}:${cfmgr_archive_source_want_root:-}:${cfmgr_archive_source_want_relative:-}" = \
				"${cfmgr_history_want_uuid:-}:${cfmgr_history_want_filesystem:-}:${cfmgr_history_want_root:-}:${cfmgr_history_want_relative:-}" ] || return 1
	fi
	cfmgr_hr_input=${cfmgr_hr_lib%/lib}/backup.sh cfmgr_hr_base=/proc/self/fd/8
	cfmgr_hr_expected=$cfmgr_store_source/modules/backup.sh
	cfmgr_hr_protect
}

cfmgr_backup_history_attached() {
	cfmgr_store_attachment_ok || return 1
	case ${cfmgr_hr_phase:-} in
	native) return 0 ;;
	entware) cfmgr_storage_attached ;;
	source)
		cfmgr_archive_source_attached || return 1
		[ "${cfmgr_backup_folder_pinned:-0}" != 1 ] || cfmgr_backup_attached
		;;
	*) return 1 ;;
	esac
}

cfmgr_hr_run() {
	# Fixed mode, exact output cap, trusted tool, literal operands. No arbitrary
	# process executor: the helper and supervisor both validate finite modes.
	cfmgr_hr_run_mode=$1 cfmgr_history_probe_limit=$2 cfmgr_hr_run_tool=$3
	shift 3
	cfmgr_archive_uint "$cfmgr_history_probe_limit" && [ "$cfmgr_history_probe_limit" -gt 0 ] &&
		cfmgr_backup_history_attached || return 1
	cfmgr_history_runtime_reserve "$((${cfmgr_hr_pending:-0} + 512))" || return $?
	cfmgr_hr_available=$((cfmgr_history_limit - cfmgr_hr_live_bytes - ${cfmgr_hr_pending:-0} - 512))
	[ "$cfmgr_hr_available" -ge 2 ] || return 1
	[ "$cfmgr_history_probe_limit" -le "$((cfmgr_hr_available / 2))" ] || cfmgr_history_probe_limit=$((cfmgr_hr_available / 2))
	if cfmgr_prerequisites_run "$cfmgr_hr_run_mode" "$cfmgr_store_context" "$cfmgr_store_sh" \
		"$cfmgr_store_source/modules/helpers/worker.sh" "$cfmgr_store_env" "$cfmgr_store_awk" \
		"$cfmgr_store_sleep" "$cfmgr_store_wc" "$cfmgr_hr_run_tool" "$@"; then
		cfmgr_hr_run_code=0
	else cfmgr_hr_run_code=$?; fi
	# Unresolved supervision preserves all evidence immediately. An accounting
	# failure must never turn that state into an ordinary, cleanable error.
	[ "$cfmgr_hr_run_code" != 3 ] || return 3
	[ "${cfmgr_probe_status:-}" != reaped ] || cfmgr_hr_register_pair || return 1
	[ "$cfmgr_hr_run_code" = 0 ] || return "$cfmgr_hr_run_code"
	case $cfmgr_hr_run_mode in
	history-proc-list | history-writer-fd-list)
		if [ "${cfmgr_probe_status:-}:$cfmgr_probe_exit:${cfmgr_probe_reason:-}" = reaped:4: ] &&
			[ ! -s "$cfmgr_probe_stdout" ] && [ ! -s "$cfmgr_probe_stderr" ]; then return 4; fi
		;;
	esac
	[ "$cfmgr_probe_exit" = 0 ] || return 1
	if [ "$cfmgr_hr_run_mode" = history-logrotate-debug ]; then
		# Keep the original raw stderr file; expose it as the callback's selected
		# successful debug stream. The old stdout must be empty, not concealed.
		[ ! -s "$cfmgr_probe_stdout" ] || return 1
		cfmgr_hr_debug_stream=$cfmgr_probe_stderr
		cfmgr_probe_stderr=$cfmgr_probe_stdout cfmgr_probe_stdout=$cfmgr_hr_debug_stream
	else [ ! -s "$cfmgr_probe_stderr" ] || return 1; fi
	cfmgr_hr_result=$cfmgr_probe_stdout
}

cfmgr_hr_line() {
	cfmgr_store_read_line "$1" || return 1
	cfmgr_hr_line=$cfmgr_store_line
	cfmgr_history_runtime_consume "$1"
}

cfmgr_hr_ram_meta() {
	# Explicit Store-style RAM-only receipt boundary: the directory is privately
	# FD5-pinned and all file names are generated. No USB/JFFS lookup is allowed.
	[ "${1%/*}" = "$cfmgr_store_context" ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_hr_ram_line=$("$cfmgr_store_ls" -ildn "$1") || return 1
	IFS=' ' read -r cfmgr_hr_ram_inode cfmgr_hr_ram_mode cfmgr_hr_ram_links cfmgr_hr_ram_uid cfmgr_hr_ram_gid cfmgr_hr_ram_size cfmgr_hr_ram_name <<EOF_HISTORY_RAM_META
$cfmgr_hr_ram_line
EOF_HISTORY_RAM_META
	cfmgr_archive_uint "$cfmgr_hr_ram_inode" && [ "$cfmgr_hr_ram_inode" -gt 0 ] && cfmgr_archive_uint "$cfmgr_hr_ram_size"
}

cfmgr_hr_register_pair() {
	[ "${cfmgr_probe_status:-}" = reaped ] || return 1
	for cfmgr_hr_register_path in "$cfmgr_probe_stdout" "$cfmgr_probe_stderr"; do
		cfmgr_hr_ram_meta "$cfmgr_hr_register_path" || return 1
		[ "$cfmgr_hr_ram_size" -le "$cfmgr_history_probe_limit" ] || return 1
		cfmgr_hr_charge "$cfmgr_hr_register_path" || return 1
		cfmgr_hr_receipts="${cfmgr_hr_receipts:+$cfmgr_hr_receipts }${cfmgr_hr_register_path##*/}:$cfmgr_hr_ram_inode"
	done
}

cfmgr_history_runtime_seed() {
	cfmgr_store_attachment_ok || return 1
	# Charge every retained Store/controller receipt once at each phase boundary.
	# No other producer runs between history probes; births/retirement below keep
	# the totals current without an external stat census on every invocation.
	cfmgr_hr_live_bytes=0 cfmgr_hr_live_files=0
	case $- in *f*) cfmgr_hr_seed_noglob=1 ;; *) cfmgr_hr_seed_noglob=0 ;; esac
	set +f
	set -- "$cfmgr_store_context"/* "$cfmgr_store_context"/.[!.]* "$cfmgr_store_context"/..?*
	[ "$cfmgr_hr_seed_noglob" = 0 ] || set -f
	for cfmgr_hr_seed_path; do
		[ -e "$cfmgr_hr_seed_path" ] || [ -L "$cfmgr_hr_seed_path" ] || continue
		cfmgr_hr_ram_meta "$cfmgr_hr_seed_path" || return 1
		cfmgr_hr_charge "$cfmgr_hr_seed_path" || return 1
	done
	cfmgr_hr_account_context=$cfmgr_store_context
}

cfmgr_hr_charge() {
	cfmgr_hr_growth=$((cfmgr_hr_ram_size + ${#1} - ${#cfmgr_store_context} - 1 + 64))
	[ "$cfmgr_hr_growth" -le "$((cfmgr_history_limit - cfmgr_hr_live_bytes))" ] || return 1
	cfmgr_hr_live_bytes=$((cfmgr_hr_live_bytes + cfmgr_hr_growth))
	cfmgr_hr_live_files=$((cfmgr_hr_live_files + 1))
	[ "$cfmgr_hr_live_files" -le 512 ]
}

cfmgr_hr_retire() {
	cfmgr_hr_ram_meta "$1" || return 1
	[ "$cfmgr_hr_ram_inode" = "$2" ] || return 1
	cfmgr_hr_live_bytes=$((cfmgr_hr_live_bytes - cfmgr_hr_ram_size - ${#1} + ${#cfmgr_store_context} + 1 - 64))
	cfmgr_hr_live_files=$((cfmgr_hr_live_files - 1))
	(cd /proc/self/fd/5 && exec /bin/rm -f "${1##*/}")
}

cfmgr_history_runtime_reserve() {
	[ "$#" = 1 ] && cfmgr_archive_uint "$1" && cfmgr_backup_history_attached || return 1
	[ "${cfmgr_hr_account_context:-}" = "$cfmgr_store_context" ] || cfmgr_history_runtime_seed || return 1
	# Two fresh supervised receipts must fit Store's complete 512-file cleanup
	# bound, including files created before this history adapter was entered.
	[ "$cfmgr_hr_live_files" -le 510 ] &&
		[ "$1" -le "$((cfmgr_history_limit - cfmgr_hr_live_bytes))" ]
}

cfmgr_history_runtime_consume() {
	# Retire only this positively reaped internal receipt pair. A caller may
	# hold many other exported parser/debug records; those remain registered.
	[ "$#" = 1 ] && [ "${cfmgr_probe_status:-}" = reaped ] && cfmgr_backup_history_attached || return 1
	[ "${1%/*}" = "$cfmgr_store_context" ] || return 1
	cfmgr_hr_consume_stem=${1##*/}
	case $cfmgr_hr_consume_stem in history-*.[0-9]*.out | history-*.[0-9]*.err) cfmgr_hr_consume_stem=${cfmgr_hr_consume_stem%.*} ;; *) return 0 ;; esac
	cfmgr_hr_kept=''
	for cfmgr_hr_consume_token in ${cfmgr_hr_receipts:-}; do
		cfmgr_hr_consume_leaf=${cfmgr_hr_consume_token%:*}
		case $cfmgr_hr_consume_leaf in "$cfmgr_hr_consume_stem.out" | "$cfmgr_hr_consume_stem.err")
			cfmgr_hr_ram_meta "$cfmgr_store_context/$cfmgr_hr_consume_leaf" || return 1
			[ "$cfmgr_hr_ram_inode" = "${cfmgr_hr_consume_token##*:}" ] || return 1
			cfmgr_hr_retire "$cfmgr_store_context/$cfmgr_hr_consume_leaf" "${cfmgr_hr_consume_token##*:}" || return 1
			;;
		*) cfmgr_hr_kept="${cfmgr_hr_kept:+$cfmgr_hr_kept }$cfmgr_hr_consume_token" ;;
		esac
	done
	cfmgr_hr_receipts=$cfmgr_hr_kept
}

cfmgr_history_runtime_write() {
	[ "$#" = 2 ] && [ "${1%/*}" = "$cfmgr_store_context" ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	case ${1##*/} in history-[0-9]*) ;; *) return 2 ;; esac
	cfmgr_hr_pending=$((${#2} + 1))
	if cfmgr_hr_run history-append 4096 /usr/bin/printf /proc/self/fd/5 "$cfmgr_store_context" "${1##*/}" "$2" "$cfmgr_history_limit"; then
		cfmgr_hr_write_code=0
	else cfmgr_hr_write_code=$?; fi
	cfmgr_hr_live_bytes=$((cfmgr_hr_live_bytes + cfmgr_hr_pending))
	cfmgr_hr_pending=0
	[ "$cfmgr_hr_write_code" = 0 ] || return "$cfmgr_hr_write_code"
	cfmgr_history_runtime_consume "$cfmgr_probe_stdout"
}

cfmgr_hr_private() {
	[ "$#" = 1 ] && [ "${1%/*}" = "$cfmgr_store_context" ] &&
		[ -f "$1" ] && [ ! -L "$1" ] || return 1
	case ${1##*/} in history-[0-9]* | history-*.[0-9]*.out | history-*.[0-9]*.err | payload-[0-9]* | store-archive-plan.[0-9]*.out) ;; *) return 1 ;; esac
	cfmgr_hr_input=/proc/self/fd/5/${1##*/}
}

cfmgr_hr_map() {
	# Only fixed source metadata, generated direct fragments and actual owned
	# numbered families are admitted. Foreign paths belong only to resolve.
	cfmgr_hr_logical=$1 cfmgr_hr_base=''
	case $1:${cfmgr_hr_phase:-} in /opt*:native) return 1 ;; esac
	case $1 in
	/opt | /opt/bin | /opt/etc | /opt/etc/syslog-ng.d | /opt/etc/logrotate.d | /opt/var/log)
		cfmgr_hr_relative=${1#/opt}
		;;
	/opt/bin/cloudflared | /opt/sbin/syslog-ng | /opt/sbin/logrotate | /opt/etc/syslog-ng.conf | /opt/etc/logrotate.conf)
		cfmgr_hr_relative=${1#/opt}
		;;
	/opt/etc/logrotate.d/?*)
		cfmgr_hr_leaf=${1##*/}
		case $cfmgr_hr_leaf in *[!A-Za-z0-9_-]*) return 1 ;; esac
		[ "${1%/*}" = /opt/etc/logrotate.d ] || return 1
		cfmgr_hr_relative=${1#/opt}
		;;
	/opt/var/log/ddns.log* | /opt/var/log/ip-sync.log* | /opt/var/log/cloudflared.log*)
		cfmgr_hr_leaf=${1##*/}
		case $cfmgr_hr_leaf in ddns.log | ip-sync.log | cloudflared.log) ;;
		*)
			cfmgr_hr_rotation=${cfmgr_hr_leaf#*.log.}
			cfmgr_archive_uint "$cfmgr_hr_rotation" && [ "$cfmgr_hr_rotation" -gt 0 ] || return 1
			;;
		esac
		[ "${1%/*}" = /opt/var/log ] || return 1
		cfmgr_hr_relative=${1#/opt}
		;;
	/jffs/scripts/scribe | /jffs/addons/scribe.d/config)
		cfmgr_hr_base=/proc/self/fd/8 cfmgr_hr_relative=${1#/jffs}
		cfmgr_hr_expected=$cfmgr_store_jffs$cfmgr_hr_relative
		;;
	/tmp/scribeLogRotate.flock)
		cfmgr_hr_base=/tmp cfmgr_hr_relative=/scribeLogRotate.flock cfmgr_hr_expected=$1
		;;
	*)
		cfmgr_hr_private "$1" || return 1
		cfmgr_hr_base=/proc/self/fd/5 cfmgr_hr_relative=/${1##*/}
		cfmgr_hr_expected=$cfmgr_store_context$cfmgr_hr_relative
		;;
	esac
	if [ -z "$cfmgr_hr_base" ]; then
		cfmgr_hr_base=$cfmgr_hr_anchor cfmgr_hr_expected=$cfmgr_hr_root$cfmgr_hr_relative
	fi
	cfmgr_hr_input=$cfmgr_hr_base${cfmgr_hr_relative:-/.}
}

cfmgr_hr_meta_raw() {
	cfmgr_hr_run history-meta 4096 "$cfmgr_store_ls" "$1" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	IFS=' ' read -r cfmgr_hr_inode cfmgr_hr_mode cfmgr_hr_links cfmgr_hr_uid cfmgr_hr_gid cfmgr_hr_size cfmgr_hr_meta_name <<EOF_HISTORY_NATIVE_META
$cfmgr_hr_line
EOF_HISTORY_NATIVE_META
	cfmgr_archive_uint "$cfmgr_hr_inode" && [ "$cfmgr_hr_inode" -gt 0 ] &&
		cfmgr_archive_uint "$cfmgr_hr_size"
}

cfmgr_hr_protect() {
	# Mapped endpoint and every relative ancestor are checked under phase pins.
	cfmgr_hr_protect_path=$cfmgr_hr_input cfmgr_hr_protect_root=$cfmgr_hr_base
	while :; do
		cfmgr_hr_meta_raw "$cfmgr_hr_protect_path" || return $?
		[ "$cfmgr_hr_uid" = 0 ] || return 1
		case $cfmgr_hr_mode in -????????? | d?????????) ;; *) return 1 ;; esac
		case $cfmgr_hr_protect_path:$cfmgr_hr_mode in /tmp/.:drwxrwxrwt | /tmp:drwxrwxrwt) ;; *)
			case $cfmgr_hr_mode in ?????w???? | ????????w?) return 1 ;; esac
			;;
		esac
		[ "$cfmgr_hr_protect_path" != "$cfmgr_hr_protect_root/." ] || break
		cfmgr_hr_protect_path=${cfmgr_hr_protect_path%/*}
		if [ "$cfmgr_hr_protect_path" = "$cfmgr_hr_protect_root" ] || [ "$cfmgr_hr_protect_root:$cfmgr_hr_protect_path" = /: ]; then cfmgr_hr_protect_path=$cfmgr_hr_protect_root/.; fi
	done
	cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "$cfmgr_hr_input" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" && [ "$cfmgr_hr_line" = "$cfmgr_hr_expected" ]
}

cfmgr_hr_admit() {
	cfmgr_hr_map "$1" && cfmgr_hr_protect
}

cfmgr_hr_native() {
	# Extra native tools not prepared by Store are admitted with already trusted
	# native readlink/ls. No candidate is executed to learn its own provenance.
	[ "$#" = 1 ] || return 2
	case $1 in /usr/bin/hexdump | /bin/nvram | /usr/sbin/openssl | /usr/bin/flock | /bin/busybox | /sbin/blkid) ;; *) return 2 ;; esac
	case " ${cfmgr_hr_native_admitted:-} " in *" $1 "*)
		[ -f "$1" ] && [ -x "$1" ]
		return $?
		;;
	esac
	cfmgr_hr_native_path=$1
	cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "$1" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	case $cfmgr_hr_line in "$cfmgr_hr_native_path" | /bin/busybox) ;; *) return 1 ;; esac
	cfmgr_hr_native_target=$cfmgr_hr_line cfmgr_hr_native_cursor=$cfmgr_hr_line
	while :; do
		cfmgr_hr_meta_raw "$cfmgr_hr_native_cursor" || return $?
		[ "$cfmgr_hr_uid" = 0 ] || return 1
		case $cfmgr_hr_mode in -????????? | d?????????) ;; *) return 1 ;; esac
		case $cfmgr_hr_mode in ?????w???? | ????????w?) return 1 ;; esac
		[ "$cfmgr_hr_native_cursor" != / ] || break
		cfmgr_hr_native_cursor=${cfmgr_hr_native_cursor%/*}
		[ -n "$cfmgr_hr_native_cursor" ] || cfmgr_hr_native_cursor=/
	done
	[ -x "$cfmgr_hr_native_path" ] || return 1
	cfmgr_hr_native_admitted="${cfmgr_hr_native_admitted:+$cfmgr_hr_native_admitted }$cfmgr_hr_native_path"
}

cfmgr_hr_tool() {
	cfmgr_hr_tool_logical=$1
	cfmgr_hr_admit "$1" || return $?
	cfmgr_hr_tool_path=$cfmgr_hr_input
	cfmgr_hr_meta_raw "$cfmgr_hr_tool_path" || return $?
	[ -x "$cfmgr_hr_tool_path" ] || return 1
	cfmgr_hr_tool_identity=$cfmgr_hr_device:$cfmgr_hr_inode:$cfmgr_hr_mode:$cfmgr_hr_uid:$cfmgr_hr_gid
	case $cfmgr_hr_tool_logical in
	/opt/sbin/syslog-ng)
		[ -z "${cfmgr_hr_syslog_identity:-}" ] || [ "$cfmgr_hr_syslog_identity" = "$cfmgr_hr_tool_identity" ] || return 1
		cfmgr_hr_syslog_identity=$cfmgr_hr_tool_identity
		;;
	/opt/sbin/logrotate)
		[ -z "${cfmgr_hr_rotate_identity:-}" ] || [ "$cfmgr_hr_rotate_identity" = "$cfmgr_hr_tool_identity" ] || return 1
		cfmgr_hr_rotate_identity=$cfmgr_hr_tool_identity
		;;
	*) return 2 ;;
	esac
}

cfmgr_hr_measure() {
	cfmgr_hr_run history-count 4096 "$cfmgr_store_wc" "$1" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	IFS=' 	' read -r cfmgr_hr_bytes cfmgr_hr_count_name <<EOF_HISTORY_NATIVE_COUNT
$cfmgr_hr_line
EOF_HISTORY_NATIVE_COUNT
	cfmgr_archive_uint "$cfmgr_hr_bytes" && [ "$cfmgr_hr_count_name" = "$1" ]
}

cfmgr_hr_text_frame() {
	# The fixed trusted helper receives literal data operands, never -v/program
	# interpolation. Generated frame receipts stay supervised and size checked.
	cfmgr_hr_run history-frame "$cfmgr_history_limit" "$cfmgr_store_awk" "$1" "${2:-}" "${3:-}" "${4:-}" "${5:-}"
}

cfmgr_backup_history_probe() {
	[ "$#" -ge 1 ] && cfmgr_backup_history_attached || return 1
	cfmgr_hr_operation=$1
	case $cfmgr_hr_operation:${cfmgr_hr_phase:-} in parse:* | policy:* | read-private:*) ;; *:native) return 1 ;; esac
	shift
	case $cfmgr_hr_operation in
	meta)
		[ "$#" = 1 ] || return 2
		cfmgr_hr_admit "$1" || return $?
		cfmgr_hr_run history-meta 4096 "$cfmgr_store_ls" "$cfmgr_hr_input"
		;;
	hash)
		[ "$#" = 1 ] || return 2
		cfmgr_hr_admit "$1" || return $?
		cfmgr_hr_hash_logical=$1 cfmgr_hr_hash_input=$cfmgr_hr_input
		cfmgr_hr_native /usr/sbin/openssl || return $?
		cfmgr_hr_run history-digest 4096 /usr/sbin/openssl "$cfmgr_hr_hash_input" || return $?
		cfmgr_hr_line "$cfmgr_hr_result" || return 1
		IFS=' ' read -r cfmgr_hr_hash cfmgr_hr_hash_name <<EOF_HISTORY_RUNTIME_HASH
$cfmgr_hr_line
EOF_HISTORY_RUNTIME_HASH
		cfmgr_hr_hash_name=${cfmgr_hr_hash_name#\*}
		[ "${#cfmgr_hr_hash}" = 64 ] && [ "$cfmgr_hr_hash_name" = "$cfmgr_hr_hash_input" ] || return 1
		case $cfmgr_hr_hash in *[!0-9a-f]*) return 1 ;; esac
		cfmgr_hr_text_frame hash "$cfmgr_hr_hash" "$cfmgr_hr_hash_logical"
		;;
	read | read-private)
		[ "$#" = 1 ] || return 2
		if [ "$cfmgr_hr_operation" = read-private ]; then
			cfmgr_hr_private "$1" || return 1
		else cfmgr_hr_admit "$1" || return $?; fi
		cfmgr_hr_read_input=$cfmgr_hr_input
		cfmgr_hr_native /usr/bin/hexdump || return $?
		if [ "$1" = /jffs/scripts/scribe ]; then
			cfmgr_hr_run history-script-prefix 8192 "$cfmgr_store_dd" "$cfmgr_hr_read_input" || return $?
			cfmgr_hr_read_input=$cfmgr_hr_result
		fi
		cfmgr_hr_measure "$cfmgr_hr_read_input" || return $?
		[ "$cfmgr_hr_bytes" -le "$((cfmgr_history_limit / 3))" ] || return 1
		cfmgr_hr_run history-hexdump "$cfmgr_history_limit" /usr/bin/hexdump "$cfmgr_hr_read_input"
		;;
	readlink)
		[ "$#:$1" = 1:/opt/bin/scribe ] || return 2
		cfmgr_hr_run history-readlink 4096 "$cfmgr_store_readlink" "$cfmgr_hr_anchor/bin/scribe"
		;;
	syslog-version | syslog-check | logrotate-version | logrotate-debug)
		[ "$#" = 0 ] || return 2
		case $cfmgr_hr_operation in syslog-*) cfmgr_hr_tool /opt/sbin/syslog-ng ;; *) cfmgr_hr_tool /opt/sbin/logrotate ;; esac || return $?
		cfmgr_hr_exec_tool=$cfmgr_hr_tool_path
		case $cfmgr_hr_operation in
		syslog-check) cfmgr_hr_admit /opt/etc/syslog-ng.conf || return $? ;;
		logrotate-debug) cfmgr_hr_admit /opt/etc/logrotate.conf || return $? ;;
		esac
		cfmgr_hr_run "history-$cfmgr_hr_operation" "$cfmgr_history_limit" "$cfmgr_hr_exec_tool"
		;;
	list)
		[ "$#:$1" = 1:/opt/var/log ] && cfmgr_hr_admit "$1" || return 1
		cfmgr_hr_run history-directory "$cfmgr_history_limit" "$cfmgr_store_ls" "$cfmgr_hr_input" "$cfmgr_history_memory_kib"
		;;
	cron) [ "$#" = 0 ] && cfmgr_hr_cron ;;
	rotation) [ "$#" = 0 ] && cfmgr_hr_rotation ;;
	processes) [ "$#" = 0 ] && cfmgr_hr_processes ;;
	resolve) [ "$#" = 1 ] && cfmgr_hr_resolve "$1" ;;
	parse) cfmgr_hr_parse "$@" ;;
	policy) [ "$#" = 2 ] && cfmgr_hr_policy "$1" "$2" ;;
	lock)
		[ "$#" = 0 ] && [ ! -L /tmp/scribeLogRotate.flock ] &&
			[ /tmp/scribeLogRotate.flock -ef /proc/self/fd/4 ] || return 1
		cfmgr_hr_native /usr/bin/flock || return $?
		cfmgr_hr_run history-lock 4096 /usr/bin/flock
		;;
	*) return 2 ;;
	esac
}

cfmgr_history_runtime_created() {
	[ "$#" = 1 ] && cfmgr_hr_ram_meta "$1" || return 1
	case ${1##*/} in history-[0-9]*) ;; *) return 1 ;; esac
	cfmgr_hr_charge "$1" || return 1
	cfmgr_hr_generated="${cfmgr_hr_generated:+$cfmgr_hr_generated }${1##*/}:$cfmgr_hr_ram_inode"
}

cfmgr_history_runtime_checkpoint() {
	# Only successful, positively quiescent observation can retire old evidence.
	[ "$#" = 2 ] && [ "${cfmgr_probe_status:-}" = reaped ] && cfmgr_backup_history_attached || return 1
	cfmgr_hr_checkpoint_keep="$1 $2" cfmgr_hr_checkpoint_tokens='' cfmgr_history_owned=''
	for cfmgr_hr_checkpoint_token in ${cfmgr_hr_generated:-} ${cfmgr_hr_receipts:-}; do
		cfmgr_hr_checkpoint_leaf=${cfmgr_hr_checkpoint_token%:*}
		cfmgr_hr_ram_meta "$cfmgr_store_context/$cfmgr_hr_checkpoint_leaf" || return 1
		[ "$cfmgr_hr_ram_inode" = "${cfmgr_hr_checkpoint_token##*:}" ] || return 1
		case " $cfmgr_hr_checkpoint_keep " in *" $cfmgr_store_context/$cfmgr_hr_checkpoint_leaf "*)
			cfmgr_hr_checkpoint_tokens="${cfmgr_hr_checkpoint_tokens:+$cfmgr_hr_checkpoint_tokens }$cfmgr_hr_checkpoint_token"
			cfmgr_history_owned="${cfmgr_history_owned:+$cfmgr_history_owned }$cfmgr_hr_checkpoint_leaf"
			;;
		*) cfmgr_hr_retire "$cfmgr_store_context/$cfmgr_hr_checkpoint_leaf" "${cfmgr_hr_checkpoint_token##*:}" || return 1 ;;
		esac
	done
	cfmgr_hr_generated=$cfmgr_hr_checkpoint_tokens cfmgr_hr_receipts=''
	cfmgr_history_runtime_reserve 0
}

cfmgr_hr_parse() {
	[ "$#" -ge 2 ] && [ "$#" -le 4 ] || return 2
	cfmgr_hr_parse_mode=$1 cfmgr_hr_parse_label=${3:-} cfmgr_hr_parse_aux=${4:-}
	cfmgr_hr_private "$2" || return 1
	cfmgr_hr_parse_input=$cfmgr_hr_input
	if [ "$cfmgr_hr_parse_mode" = compare ]; then
		cfmgr_hr_private "$cfmgr_hr_parse_label" || return 1
		cfmgr_hr_parse_label=$cfmgr_hr_input
	fi
	cfmgr_hr_run history-parse "$cfmgr_history_limit" "$cfmgr_store_awk" "${cfmgr_hr_lib%/lib}/backup.sh" \
		"$cfmgr_hr_parse_mode" "$cfmgr_hr_parse_input" "$cfmgr_history_limit" "$cfmgr_hr_parse_label" "$cfmgr_hr_parse_aux"
}

cfmgr_hr_policy() {
	cfmgr_hr_policy_feature=$1
	cfmgr_hr_run history-policy-decode 65536 "$cfmgr_store_awk" "$2" || return $?
	cfmgr_hr_policy_input=$cfmgr_hr_result
	cfmgr_hr_measure "$cfmgr_hr_policy_input" || return $?
	cfmgr_hr_run history-policy-json 4096 "$cfmgr_store_awk" "$cfmgr_hr_lib" "$cfmgr_hr_policy_input" \
		"$cfmgr_hr_bytes" "$cfmgr_hr_policy_feature" "$cfmgr_history_limit"
}

cfmgr_hr_native_path() {
	# Data endpoints on native filesystems still require a complete protected
	# ancestor chain. No foreign file contents are inspected here.
	cfmgr_hr_input=$1 cfmgr_hr_expected=$1 cfmgr_hr_base=/
	cfmgr_hr_protect
}

cfmgr_hr_mount_identity() {
	cfmgr_hr_run history-mount 8192 "$cfmgr_store_awk" "$cfmgr_hr_lib/storage.sh" "$1" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	IFS='	' read -r cfmgr_hr_observed_mount cfmgr_hr_observed_parent cfmgr_hr_observed_device cfmgr_hr_observed_rest <<EOF_HISTORY_MOUNT_IDENTITY
$cfmgr_hr_line
EOF_HISTORY_MOUNT_IDENTITY
	cfmgr_archive_uint "$cfmgr_hr_observed_mount" || return 1
	case $cfmgr_hr_observed_device in *[!0-9:]* | :* | *: | '') return 1 ;; esac
	cfmgr_hr_observed_mount_identity=$cfmgr_hr_line
}

cfmgr_hr_rotation() {
	# Scribe opens/truncates this exact existing lock before flock. Its content,
	# write bits and mtime are not authority; held inode/mount/owner are.
	[ ! -L /tmp/scribeLogRotate.flock ] || return 1
	cfmgr_hr_meta_raw /tmp/scribeLogRotate.flock || return $?
	case $cfmgr_hr_mode:$cfmgr_hr_uid:$cfmgr_hr_links in -?????????:0:1) ;; *) return 1 ;; esac
	cfmgr_hr_rotation_inode=$cfmgr_hr_inode
	cfmgr_hr_mount_identity /tmp/scribeLogRotate.flock || return $?
	cfmgr_hr_text_frame text "ROTATION $cfmgr_hr_rotation_inode $cfmgr_hr_observed_mount $cfmgr_hr_observed_device END
"
}

cfmgr_history_rotation_meta() {
	cfmgr_history_call rotation || return $?
	cfmgr_history_line "$cfmgr_history_result" || return 1
	IFS=' ' read -r cfmgr_history_rotation_tag cfmgr_history_rotation_inode cfmgr_history_rotation_mount cfmgr_history_rotation_device cfmgr_history_rotation_end cfmgr_history_rotation_extra <<EOF_HISTORY_ROTATION_META
$cfmgr_history_line_value
EOF_HISTORY_ROTATION_META
	[ "$cfmgr_history_rotation_tag:$cfmgr_history_rotation_end:$cfmgr_history_rotation_extra" = ROTATION:END: ] || return 1
	cfmgr_archive_uint "$cfmgr_history_rotation_inode" && cfmgr_archive_uint "$cfmgr_history_rotation_mount" || return 1
	case $cfmgr_history_rotation_device in *[!0-9:]* | :* | *: | '') return 1 ;; esac
	cfmgr_history_meta_value=$cfmgr_history_rotation_inode:$cfmgr_history_rotation_mount:$cfmgr_history_rotation_device
}

cfmgr_hr_cron_boundary() {
	# This is native scheduler DATA, not executable/config authority. /var may
	# be a root-owned sticky tmpfs; no nonsticky /tmp canonical alias is allowed.
	cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "$cfmgr_hr_cron_path" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	[ "$cfmgr_hr_line" = "$cfmgr_hr_cron_path" ] && [ ! -L "$cfmgr_hr_cron_path" ] || return 1
	cfmgr_hr_cron_chain=''
	for cfmgr_hr_cron_dir in / /var /var/spool /var/spool/cron /var/spool/cron/crontabs; do
		cfmgr_hr_meta_raw "$cfmgr_hr_cron_dir" || return $?
		case $cfmgr_hr_mode:$cfmgr_hr_uid in d?????????:0) ;; *) return 1 ;; esac
		if [ "$cfmgr_hr_cron_dir" = /var ]; then
			case $cfmgr_hr_mode in drwxr-xr-x | drwxrwxrwt) ;; *) return 1 ;; esac
		else case $cfmgr_hr_mode in ?????w???? | ????????w?) return 1 ;; esac fi
		cfmgr_hr_cron_chain=$cfmgr_hr_cron_chain:$cfmgr_hr_inode:$cfmgr_hr_mode
	done
	cfmgr_hr_meta_raw "$cfmgr_hr_cron_path" || return $?
	case $cfmgr_hr_mode:$cfmgr_hr_uid:$cfmgr_hr_links in -?????????:0:1) ;; *) return 1 ;; esac
	[ "$cfmgr_hr_size" -gt 0 ] && [ "$cfmgr_hr_size" -le "$((cfmgr_history_limit / 8))" ] || return 1
	cfmgr_hr_cron_bytes=$cfmgr_hr_size
	cfmgr_hr_cron_file=$cfmgr_hr_inode:$cfmgr_hr_mode:$cfmgr_hr_size
	cfmgr_hr_mount_identity "$cfmgr_hr_cron_path" || return $?
	cfmgr_hr_cron_observed=$cfmgr_hr_cron_chain:$cfmgr_hr_cron_file:$cfmgr_hr_observed_mount_identity
}

cfmgr_hr_cron() {
	cfmgr_hr_cron_admitted=0
	if _cfmgr_hr_cron; then return 0; else cfmgr_hr_cron_code=$?; fi
	[ "$cfmgr_hr_cron_code" != 3 ] || return 3
	# Once the initial scheduler snapshot has been admitted, changed bytes or
	# identity are a failed observation, never an optional-history absence.
	[ "$cfmgr_hr_cron_admitted" = 0 ] || return 2
	return "$cfmgr_hr_cron_code"
}

_cfmgr_hr_cron() {
	cfmgr_hr_native /bin/nvram || return $?
	cfmgr_hr_run history-account 4096 /bin/nvram || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	case $cfmgr_hr_line in '' | . | .. | *[!A-Za-z0-9_-]*) return 1 ;; esac
	[ "${#cfmgr_hr_line}" -le 64 ] || return 1
	cfmgr_hr_cron_account=$cfmgr_hr_line
	cfmgr_hr_cron_path=/var/spool/cron/crontabs/$cfmgr_hr_cron_account
	cfmgr_hr_cron_boundary || return $?
	cfmgr_hr_cron_admitted=1
	cfmgr_hr_cron_before=$cfmgr_hr_cron_observed cfmgr_hr_cron_size=$cfmgr_hr_cron_bytes
	cfmgr_hr_run history-cron-read "$cfmgr_hr_cron_size" "$cfmgr_store_dd" "$cfmgr_hr_cron_path" "$cfmgr_hr_cron_size" || return $?
	cfmgr_hr_cron_result=$cfmgr_hr_result cfmgr_hr_cron_stderr=$cfmgr_probe_stderr
	cfmgr_hr_measure "$cfmgr_hr_cron_result" || return $?
	[ "$cfmgr_hr_bytes" = "$cfmgr_hr_cron_size" ] || return 1
	cfmgr_hr_writer_digest "$cfmgr_hr_cron_result" || return $?
	cfmgr_hr_cron_sha=$cfmgr_hr_writer_sha
	cfmgr_hr_cron_boundary || return $?
	[ "$cfmgr_hr_cron_observed" = "$cfmgr_hr_cron_before" ] || return 1
	cfmgr_hr_run history-cron-read "$cfmgr_hr_cron_size" "$cfmgr_store_dd" "$cfmgr_hr_cron_path" "$cfmgr_hr_cron_size" || return $?
	cfmgr_hr_cron_second=$cfmgr_hr_result
	cfmgr_hr_measure "$cfmgr_hr_cron_second" || return $?
	[ "$cfmgr_hr_bytes" = "$cfmgr_hr_cron_size" ] || return 1
	cfmgr_hr_writer_digest "$cfmgr_hr_cron_second" || return $?
	[ "$cfmgr_hr_writer_sha" = "$cfmgr_hr_cron_sha" ] || return 1
	cfmgr_history_runtime_consume "$cfmgr_hr_cron_second" || return $?
	cfmgr_hr_cron_boundary || return $?
	[ "$cfmgr_hr_cron_observed" = "$cfmgr_hr_cron_before" ] || return 1
	cfmgr_hr_run history-account 4096 /bin/nvram || return $?
	cfmgr_hr_line "$cfmgr_hr_result" && [ "$cfmgr_hr_line" = "$cfmgr_hr_cron_account" ] || return 1
	cfmgr_hr_cron_fingerprint="cron $cfmgr_hr_cron_account $cfmgr_hr_cron_path $cfmgr_hr_cron_before $cfmgr_hr_cron_sha"
	# Restore BOTH retained files. Later metadata probes consumed their own pair.
	[ -f "$cfmgr_hr_cron_result" ] && [ -f "$cfmgr_hr_cron_stderr" ] && [ ! -s "$cfmgr_hr_cron_stderr" ] || return 1
	cfmgr_probe_stdout=$cfmgr_hr_cron_result cfmgr_probe_stderr=$cfmgr_hr_cron_stderr cfmgr_hr_result=$cfmgr_hr_cron_result
}

cfmgr_hr_resolve() {
	cfmgr_hr_resolve_logical=$1
	case $1 in /*) ;; *) return 1 ;; esac
	[ "${#1}" -le 1024 ] || return 1
	case $1 in /opt | /opt/*)
		cfmgr_hr_resolve_input=$cfmgr_hr_anchor${1#/opt}
		[ -n "$cfmgr_hr_anchor" ] || return 1
		;;
	*) cfmgr_hr_resolve_input=$1 ;;
	esac
	cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "$cfmgr_hr_resolve_input" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	cfmgr_hr_resolve_canonical=$cfmgr_hr_line
	cfmgr_hr_meta_raw "$cfmgr_hr_resolve_canonical" || return $?
	cfmgr_hr_resolve_inode=$cfmgr_hr_inode
	case $cfmgr_hr_mode in -????????? | d?????????) ;; *) return 1 ;; esac
	cfmgr_hr_run history-mount 8192 "$cfmgr_store_awk" "$cfmgr_hr_lib/storage.sh" "$cfmgr_hr_resolve_canonical" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	IFS='	' read -r cfmgr_hr_rm_id cfmgr_hr_rm_parent cfmgr_hr_resolve_device cfmgr_hr_rm_rest <<EOF_HISTORY_RESOLVE_MOUNT
$cfmgr_hr_line
EOF_HISTORY_RESOLVE_MOUNT
	cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "$cfmgr_hr_resolve_input" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" && [ "$cfmgr_hr_line" = "$cfmgr_hr_resolve_canonical" ] || return 1
	cfmgr_hr_meta_raw "$cfmgr_hr_resolve_canonical" || return $?
	[ "$cfmgr_hr_inode" = "$cfmgr_hr_resolve_inode" ] || return 1
	cfmgr_hr_text_frame resolved "$cfmgr_hr_resolve_canonical" "$cfmgr_hr_resolve_device" "$cfmgr_hr_resolve_inode"
}

cfmgr_hr_stat() {
	# No external command in the scan loop: matched native ash lacks builtin
	# test/printf. Parse only stat identity, then inspect bounded candidates.
	# A task may disappear after enumeration; callers already classify absence.
	IFS= read -r cfmgr_hr_stat_line 2>/dev/null <"/proc/$1/stat" || return 1
	cfmgr_hr_stat_pid=${cfmgr_hr_stat_line%% *}
	cfmgr_hr_stat_comm=${cfmgr_hr_stat_line#*(}
	cfmgr_hr_stat_comm=${cfmgr_hr_stat_comm%)*}
	cfmgr_hr_stat_tail=${cfmgr_hr_stat_line##*) }
	case $- in *f*) cfmgr_hr_stat_noglob=1 ;; *) cfmgr_hr_stat_noglob=0 ;; esac
	set -f
	# Numeric Linux stat fields have no pathname meaning.
	# shellcheck disable=SC2086
	set -- $cfmgr_hr_stat_tail
	[ "$cfmgr_hr_stat_noglob" = 1 ] || set +f
	case $# in 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19) return 1 ;; esac
	shift 19
	cfmgr_hr_stat_start=$1
	case $cfmgr_hr_stat_pid:$cfmgr_hr_stat_start in *[!0-9:]* | :* | *:) return 1 ;; esac
}

cfmgr_hr_processes() {
	cfmgr_hr_native /bin/busybox && cfmgr_hr_native /usr/bin/hexdump || return $?
	cfmgr_hr_tool /opt/sbin/syslog-ng || return $?
	cfmgr_hr_syslog_inode=$cfmgr_hr_inode
	cfmgr_hr_run history-proc-list "$cfmgr_history_limit" "$cfmgr_store_awk" "$cfmgr_history_memory_kib" || return $?
	cfmgr_hr_run history-proc-pids "$cfmgr_history_limit" "$cfmgr_store_awk" "$cfmgr_hr_result" || return $?
	cfmgr_hr_pids=$cfmgr_hr_result cfmgr_hr_process_text='' cfmgr_hr_scan_count=0
	while IFS= read -r cfmgr_hr_pid <&1; do
		cfmgr_hr_scan_count=$((cfmgr_hr_scan_count + 1))
		case $((cfmgr_hr_scan_count <= cfmgr_history_limit / 2)) in 1) ;; *) return 1 ;; esac
		cfmgr_hr_stat "$cfmgr_hr_pid" || continue
		case $cfmgr_hr_stat_comm in syslog-ng) cfmgr_hr_kind=syslog ;; crond | busybox) cfmgr_hr_kind=cron ;; *) continue ;; esac
		cfmgr_hr_pid_start=$cfmgr_hr_stat_start
		cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "/proc/$cfmgr_hr_pid/exe" || return $?
		cfmgr_hr_line "$cfmgr_hr_result" || return 1
		case $cfmgr_hr_kind:$cfmgr_hr_line in "syslog:$cfmgr_hr_root/sbin/syslog-ng" | cron:/bin/busybox) ;; *) continue ;; esac
		cfmgr_hr_run history-proc-meta 4096 "$cfmgr_store_ls" "/proc/$cfmgr_hr_pid/exe" || return $?
		cfmgr_hr_line "$cfmgr_hr_result" || return 1
		IFS=' ' read -r cfmgr_hr_proc_inode cfmgr_hr_proc_rest <<EOF_HISTORY_PROC_INODE
$cfmgr_hr_line
EOF_HISTORY_PROC_INODE
		[ "$cfmgr_hr_kind" != syslog ] || [ "$cfmgr_hr_proc_inode" = "$cfmgr_hr_syslog_inode" ] || return 1
		cfmgr_hr_run history-hexdump 32768 /usr/bin/hexdump "/proc/$cfmgr_hr_pid/cmdline" || return $?
		if cfmgr_hr_run history-argv 32768 "$cfmgr_store_awk" "$cfmgr_hr_result" "$cfmgr_hr_kind" "$cfmgr_hr_pid" "$cfmgr_hr_pid_start"; then
			:
		else
			cfmgr_hr_argv_code=$?
			[ "$cfmgr_hr_argv_code" != 3 ] || return 3
			[ "${cfmgr_probe_exit:-}" = 4 ] && [ "${cfmgr_probe_status:-}" = reaped ] && continue
			return "$cfmgr_hr_argv_code"
		fi
		cfmgr_hr_line "$cfmgr_hr_result" || return 1
		cfmgr_hr_candidate_row=$cfmgr_hr_line
		cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "/proc/$cfmgr_hr_pid/exe" || return $?
		cfmgr_hr_line "$cfmgr_hr_result" || return 1
		case $cfmgr_hr_kind:$cfmgr_hr_line in "syslog:$cfmgr_hr_root/sbin/syslog-ng" | cron:/bin/busybox) ;; *) return 1 ;; esac
		cfmgr_hr_run history-proc-meta 4096 "$cfmgr_store_ls" "/proc/$cfmgr_hr_pid/exe" || return $?
		cfmgr_hr_line "$cfmgr_hr_result" || return 1
		IFS=' ' read -r cfmgr_hr_proc_after_inode cfmgr_hr_proc_rest <<EOF_HISTORY_PROC_AFTER
$cfmgr_hr_line
EOF_HISTORY_PROC_AFTER
		[ "$cfmgr_hr_proc_after_inode" = "$cfmgr_hr_proc_inode" ] || return 1
		cfmgr_hr_stat "$cfmgr_hr_pid" && [ "$cfmgr_hr_stat_start" = "$cfmgr_hr_pid_start" ] || return 1
		cfmgr_hr_process_text="$cfmgr_hr_process_text$cfmgr_hr_candidate_row
"
		[ "${#cfmgr_hr_process_text}" -le "$cfmgr_history_limit" ] || return 1
	done 1<"$cfmgr_hr_pids"
	cfmgr_hr_text_frame text "$cfmgr_hr_process_text"
}

# Relevant managed logger admission. Process names discover candidates only;
# executable ownership, source-backed argv and the actual append FD grant use.
cfmgr_hr_writer_parse() {
	cfmgr_hr_run history-writer-parse 4096 "$cfmgr_store_awk" "${cfmgr_hr_lib%/lib}/backup.sh" "$1" "$2" "${3:-}" || return $?
	cfmgr_hr_line "$cfmgr_hr_result"
}

cfmgr_hr_writer_digest() {
	cfmgr_hr_native /usr/sbin/openssl || return $?
	cfmgr_hr_run history-digest 4096 /usr/sbin/openssl "$1" || return $?
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	cfmgr_hr_writer_sha=${cfmgr_hr_line%% *}
	[ "${#cfmgr_hr_writer_sha}" = 64 ] || return 1
	case $cfmgr_hr_writer_sha in *[!0-9a-f]*) return 1 ;; esac
}

cfmgr_hr_writer_failure() {
	[ "$1" != 3 ] || return 3
	[ -d "/proc/$cfmgr_hr_writer_pid" ] || return 5
	return 4
}

cfmgr_hr_writer_identity() {
	cfmgr_hr_stat "$cfmgr_hr_writer_pid" || {
		cfmgr_hr_writer_failure 1
		return $?
	}
	[ "$cfmgr_hr_stat_comm:$cfmgr_hr_stat_start" = "cloudflared:$cfmgr_hr_writer_start" ] || return 4
	cfmgr_hr_run history-realpath 4096 "$cfmgr_store_readlink" "/proc/$cfmgr_hr_writer_pid/exe" || {
		cfmgr_hr_writer_failure "$?"
		return $?
	}
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	[ "$cfmgr_hr_line" = "$cfmgr_hr_root/bin/cloudflared" ] || return 4
	cfmgr_hr_run history-proc-meta 4096 "$cfmgr_store_ls" "/proc/$cfmgr_hr_writer_pid/exe" || {
		cfmgr_hr_writer_failure "$?"
		return $?
	}
	cfmgr_hr_line "$cfmgr_hr_result" || return 1
	IFS=' ' read -r cfmgr_hr_writer_observed_inode cfmgr_hr_writer_meta_rest <<EOF_HISTORY_WRITER_INODE
$cfmgr_hr_line
EOF_HISTORY_WRITER_INODE
	[ "$cfmgr_hr_writer_observed_inode" = "$cfmgr_hr_writer_inode" ] || return 4
	cfmgr_hr_writer_digest "/proc/$cfmgr_hr_writer_pid/exe" || {
		cfmgr_hr_writer_failure "$?"
		return $?
	}
	[ "$cfmgr_hr_writer_sha" = "$cfmgr_hr_writer_expected_sha" ] || return 4
	IFS= read -r cfmgr_hr_writer_current_boot </proc/sys/kernel/random/boot_id || return 1
	[ "$cfmgr_hr_writer_current_boot" = "$cfmgr_hr_writer_boot" ] || return 4
}

cfmgr_hr_writer_observe() {
	cfmgr_hr_writer_count=0 cfmgr_hr_writer_pid='' cfmgr_hr_writer_evidence=''
	IFS= read -r cfmgr_hr_writer_boot </proc/sys/kernel/random/boot_id || return 1
	cfmgr_hr_run history-proc-list "$cfmgr_history_limit" "$cfmgr_store_awk" "$cfmgr_history_memory_kib" || return $?
	cfmgr_hr_run history-proc-pids "$cfmgr_history_limit" "$cfmgr_store_awk" "$cfmgr_hr_result" || return $?
	cfmgr_hr_writer_pids=$cfmgr_hr_result cfmgr_hr_writer_scanned=0
	while IFS= read -r cfmgr_hr_writer_candidate <&1; do
		cfmgr_hr_writer_scanned=$((cfmgr_hr_writer_scanned + 1))
		[ "$cfmgr_hr_writer_scanned" -le 4096 ] || return 4
		# Unrelated disappearing processes grant no authority and are irrelevant.
		if cfmgr_hr_stat "$cfmgr_hr_writer_candidate"; then :; else
			[ ! -d "/proc/$cfmgr_hr_writer_candidate" ] || return 4
			continue
		fi
		case $cfmgr_hr_stat_comm in cloudflared) ;; *) continue ;; esac
		cfmgr_hr_writer_count=$((cfmgr_hr_writer_count + 1))
		[ "$cfmgr_hr_writer_count" = 1 ] || return 4
		cfmgr_hr_writer_pid=$cfmgr_hr_writer_candidate cfmgr_hr_writer_start=$cfmgr_hr_stat_start
	done 1<"$cfmgr_hr_writer_pids"
	cfmgr_history_runtime_consume "$cfmgr_hr_writer_pids" || return $?
	[ "$cfmgr_hr_writer_count" != 0 ] || {
		cfmgr_hr_writer_evidence=absent
		return 0
	}
	cfmgr_hr_writer_expected_sha='' cfmgr_hr_writer_generation='' cfmgr_hr_writer_owner=0
	while IFS=' ' read -r cfmgr_hr_w_tag cfmgr_hr_w_a cfmgr_hr_w_b cfmgr_hr_w_c cfmgr_hr_w_d cfmgr_hr_w_more <&1; do
		case $cfmgr_hr_w_tag:$cfmgr_hr_w_a in
		WRITER:cloudflared)
			[ -z "$cfmgr_hr_writer_expected_sha$cfmgr_hr_w_more" ] && [ "$cfmgr_hr_w_b" = 2f6f70742f62696e2f636c6f7564666c61726564 ] || return 4
			cfmgr_archive_uint "$cfmgr_hr_w_c" && [ "$cfmgr_hr_w_c" -gt 0 ] || return 4
			cfmgr_hr_writer_expected_sha=$cfmgr_hr_w_d cfmgr_hr_writer_generation=$cfmgr_hr_w_c
			;;
		OWNER:history.cloudflared)
			[ "$cfmgr_hr_w_b" = 2f6f70742f7661722f6c6f672f636c6f7564666c617265642e6c6f67 ] || return 4
			cfmgr_hr_writer_owner=$((cfmgr_hr_writer_owner + 1))
			;;
		esac
	done 1<"$cfmgr_history_plan"
	[ "$cfmgr_hr_writer_owner:${#cfmgr_hr_writer_expected_sha}" = 1:64 ] || return 4
	case $cfmgr_hr_writer_expected_sha in *[!0-9a-f]*) return 4 ;; esac
	cfmgr_hr_admit /opt/bin/cloudflared || {
		cfmgr_hr_writer_failure "$?"
		return $?
	}
	cfmgr_hr_writer_binary=$cfmgr_hr_input
	cfmgr_hr_meta_raw "$cfmgr_hr_writer_binary" || return $?
	cfmgr_hr_writer_inode=$cfmgr_hr_inode
	case $cfmgr_hr_mode:$cfmgr_hr_uid in -?????????:0) ;; *) return 4 ;; esac
	cfmgr_hr_writer_digest "$cfmgr_hr_writer_binary" || return $?
	[ "$cfmgr_hr_writer_sha" = "$cfmgr_hr_writer_expected_sha" ] || return 4
	cfmgr_hr_writer_identity || return $?
	cfmgr_hr_native /usr/bin/hexdump || return $?
	cfmgr_hr_run history-hexdump 98304 /usr/bin/hexdump "/proc/$cfmgr_hr_writer_pid/cmdline" || {
		cfmgr_hr_writer_failure "$?"
		return $?
	}
	cfmgr_hr_writer_argv=$cfmgr_hr_result
	cfmgr_hr_writer_digest "$cfmgr_hr_writer_argv" || return $?
	cfmgr_hr_writer_argv_sha=$cfmgr_hr_writer_sha
	if cfmgr_hr_writer_parse argv "$cfmgr_hr_writer_argv"; then :; else
		cfmgr_hr_writer_code=$?
		[ "$cfmgr_hr_writer_code" != 3 ] || return 3
		return 4
	fi
	[ "$cfmgr_hr_line" = 'ARGV supported END' ] || return 4
	cfmgr_history_runtime_consume "$cfmgr_hr_writer_argv" || return $?
	cfmgr_hr_writer_matches=0 cfmgr_hr_writer_fd_evidence='' cfmgr_hr_writer_fd_count=0
	cfmgr_hr_run history-writer-fd-list 4096 "$cfmgr_store_awk" "$cfmgr_hr_writer_pid" "$cfmgr_history_memory_kib" || return $?
	cfmgr_hr_writer_fd_list=$cfmgr_hr_result
	while IFS= read -r cfmgr_hr_writer_fd <&1; do
		cfmgr_hr_writer_info=/proc/$cfmgr_hr_writer_pid/fdinfo/$cfmgr_hr_writer_fd
		cfmgr_hr_writer_fd_count=$((cfmgr_hr_writer_fd_count + 1))
		[ "$cfmgr_hr_writer_fd_count" -le 256 ] || return 4
		case $cfmgr_hr_writer_fd in '' | *[!0-9]*) return 4 ;; esac
		cfmgr_hr_writer_flags='' cfmgr_hr_writer_flags_count=0 cfmgr_hr_writer_info_lines=0
		while IFS=' 	' read -r cfmgr_hr_writer_key cfmgr_hr_writer_value cfmgr_hr_writer_more <&1; do
			cfmgr_hr_writer_info_lines=$((cfmgr_hr_writer_info_lines + 1))
			[ "$cfmgr_hr_writer_info_lines" -le 8 ] || return 4
			case $cfmgr_hr_writer_key in flags:)
				[ -z "$cfmgr_hr_writer_more" ] || return 4
				cfmgr_hr_writer_flags=$cfmgr_hr_writer_value
				cfmgr_hr_writer_flags_count=$((cfmgr_hr_writer_flags_count + 1))
				break
				;;
			esac
		done 1<"$cfmgr_hr_writer_info" || return 4
		[ "$cfmgr_hr_writer_flags_count" = 1 ] || return 4
		case $cfmgr_hr_writer_flags in '' | *[!0-7]*) return 4 ;; esac
		[ "${#cfmgr_hr_writer_flags}" -le 11 ] || return 4
		cfmgr_hr_writer_flags_number=$((0$cfmgr_hr_writer_flags))
		[ "$((cfmgr_hr_writer_flags_number % 4))" = 1 ] && [ "$((cfmgr_hr_writer_flags_number / 1024 % 2))" = 1 ] || continue
		cfmgr_hr_writer_fd_path=/proc/$cfmgr_hr_writer_pid/fd/$cfmgr_hr_writer_fd
		[ "$cfmgr_hr_writer_fd_path" -ef "$cfmgr_hr_writer_source" ] || continue
		cfmgr_hr_writer_matches=$((cfmgr_hr_writer_matches + 1))
		[ "$cfmgr_hr_writer_matches" = 1 ] || return 4
		cfmgr_hr_writer_fd_evidence=$cfmgr_hr_writer_fd:$cfmgr_hr_writer_flags
	done 1<"$cfmgr_hr_writer_fd_list"
	cfmgr_history_runtime_consume "$cfmgr_hr_writer_fd_list" || return $?
	[ "$cfmgr_hr_writer_matches" = 1 ] || return 4
	cfmgr_hr_writer_identity || return $?
	cfmgr_hr_writer_evidence=$cfmgr_hr_writer_boot:$cfmgr_hr_writer_pid:$cfmgr_hr_writer_start:$cfmgr_hr_writer_inode:$cfmgr_hr_writer_expected_sha:$cfmgr_hr_writer_generation:$cfmgr_hr_writer_argv_sha:$cfmgr_hr_writer_fd_evidence
}

cfmgr_archive_cloud_capture_mode() {
	[ "$#" = 1 ] && [ "${cfmgr_history_lock_held:-0}:${cfmgr_config_lock_fd0:-0}" = 1:1 ] &&
		[ "${cfmgr_hr_phase:-}" = source ] && cfmgr_backup_history_attached || return 1
	[ "$1" -ef /proc/self/fd/3/var/log/cloudflared.log ] || return 1
	cfmgr_hr_writer_source=$1
	# Capture producers may have retained new receipts since the phase boundary.
	cfmgr_history_runtime_seed || return 1
	if cfmgr_hr_writer_observe; then :; else
		cfmgr_hr_writer_code=$?
		[ "$cfmgr_hr_writer_code" = 5 ] || return "$cfmgr_hr_writer_code"
		# One fresh complete discovery can establish ordinary process exit.
		cfmgr_hr_writer_observe || {
			cfmgr_hr_writer_code=$?
			[ "$cfmgr_hr_writer_code" != 5 ] || cfmgr_hr_writer_code=4
			return "$cfmgr_hr_writer_code"
		}
	fi
	cfmgr_hr_writer_saved=$cfmgr_hr_writer_evidence
	case $cfmgr_hr_writer_saved in absent) cfmgr_archive_capture_mode=whole ;; *) cfmgr_archive_capture_mode=prefix ;; esac
}

cfmgr_archive_cloud_capture_revalidate() {
	[ "$#" = 1 ] && [ "$1" = "${cfmgr_hr_writer_source:-}" ] &&
		[ "${cfmgr_history_lock_held:-0}:${cfmgr_config_lock_fd0:-0}" = 1:1 ] && cfmgr_backup_history_attached || return 1
	cfmgr_history_runtime_seed || return 1
	if cfmgr_hr_writer_observe; then :; else
		cfmgr_hr_writer_code=$?
		[ "$cfmgr_hr_writer_code" != 3 ] || return 3
		return 1
	fi
	[ "$cfmgr_hr_writer_evidence" = "$cfmgr_hr_writer_saved" ]
}

# ---- backup payload ----
# Source-inert archive data semantics. Fixed native parsers consume owned
# snapshots; no provider, runtime activation or archive-selected executable.
# Uses internal archive I/O/format and backup text encoding. Controller supplies the
# admitted inventory-memory budget. RAM results are private and never UI text.
# shellcheck disable=SC2034,SC2154

cfmgr_payload_ram_record() {
	[ "${1%/*}" = "$cfmgr_store_context" ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_archive_format_inode "$1" || return 1
	cfmgr_payload_ram_owned="${cfmgr_payload_ram_owned:+$cfmgr_payload_ram_owned }${1##*/}:$cfmgr_format_inode"
}

cfmgr_payload_ram_name() {
	cfmgr_payload_serial=$((${cfmgr_payload_serial:-0} + 1))
	cfmgr_payload_ram=$cfmgr_store_context/payload-$cfmgr_payload_serial
}

cfmgr_payload_preserve() {
	cfmgr_payload_input=$1 cfmgr_payload_limit=$2
	cfmgr_archive_measure "$cfmgr_payload_input" || return $?
	[ "$cfmgr_archive_bytes" -le "$cfmgr_payload_limit" ] || return 1
	cfmgr_payload_ram_name
	cfmgr_archive_copy "$cfmgr_payload_input" "$cfmgr_payload_ram" 0 "$cfmgr_archive_bytes" || return $?
	cfmgr_payload_ram_record "$cfmgr_payload_ram" || return 1
	cfmgr_payload_result=$cfmgr_payload_ram
}

cfmgr_payload_cleanup() {
	[ -z "${cfmgr_payload_ram_owned:-}" ] || {
		[ "${cfmgr_probe_status:-}" = reaped ] && cfmgr_archive_attachment_ok && cfmgr_store_native_tool /bin/rm || return 1
		set --
		for cfmgr_payload_token in $cfmgr_payload_ram_owned; do
			cfmgr_payload_name=${cfmgr_payload_token%:*}
			case $cfmgr_payload_name in payload-[0-9]*) ;; *) return 1 ;; esac
			[ -f "/proc/self/fd/5/$cfmgr_payload_name" ] && [ ! -L "/proc/self/fd/5/$cfmgr_payload_name" ] || return 1
			cfmgr_archive_format_inode "/proc/self/fd/5/$cfmgr_payload_name" || return 1
			[ "$cfmgr_format_inode" = "${cfmgr_payload_token##*:}" ] || return 1
			set -- "$@" "$cfmgr_payload_name"
		done
		[ "$#" -le 32 ] || return 1
		(cd /proc/self/fd/5 && exec /bin/rm -f "$@") || return 1
	}
	cfmgr_payload_ram_owned='' cfmgr_payload_plan='' cfmgr_payload_yaml='-' cfmgr_payload_json=''
	cfmgr_payload_certificate='' cfmgr_payload_recovery='' cfmgr_payload_authority=''
	cfmgr_payload_capture_plan='' cfmgr_payload_certificate_account=''
}

cfmgr_payload_json() {
	# MODE INPUT AUXILIARY. AUX is a private authority path, account hex, or
	# generation. It never supplies shell syntax or an executable/code path.
	cfmgr_payload_json_mode=$1 cfmgr_payload_json_input=$2 cfmgr_payload_json_aux=$3
	cfmgr_archive_measure "$2" || return $?
	[ "$cfmgr_archive_bytes" -gt 0 ] && [ "$cfmgr_archive_bytes" -le 65536 ] || return 1
	cfmgr_archive_run archive-payload-json 532480 "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib" \
		"$cfmgr_payload_json_mode" "$cfmgr_payload_json_input" "$cfmgr_archive_bytes" "$cfmgr_payload_json_aux" || return $?
	if [ "$cfmgr_payload_json_mode" = plan ]; then
		cfmgr_payload_preserve "$cfmgr_probe_stdout" 532480 || return $?
		cfmgr_payload_plan=$cfmgr_payload_result
	else
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		cfmgr_payload_expected=matched
		[ "$cfmgr_payload_json_mode" != drafts ] || cfmgr_payload_expected=inert
		[ "$cfmgr_store_line" = "CFMGR-PAYLOAD 1 $cfmgr_payload_json_mode $cfmgr_payload_expected END" ] || return 1
	fi
}

cfmgr_payload_hex() {
	cfmgr_payload_hex_input=$1
	cfmgr_archive_measure "$1" || return $?
	[ "$cfmgr_archive_bytes" -gt 0 ] && [ "$cfmgr_archive_bytes" -le "$((9223372036854775296 / 3))" ] || return 1
	cfmgr_payload_serial=$((${cfmgr_payload_serial:-0} + 1))
	cfmgr_payload_hex=$cfmgr_archive_stage/payload-$cfmgr_payload_serial.hex
	cfmgr_archive_io metahex "$((cfmgr_archive_bytes * 3))" "$cfmgr_payload_hex_input" "$cfmgr_payload_hex" || return $?
	cfmgr_archive_format_record "$cfmgr_payload_hex"
}

cfmgr_payload_yaml() {
	cfmgr_payload_hex "$1" || return $?
	cfmgr_archive_run archive-payload-yaml "$cfmgr_archive_inventory_limit" "$cfmgr_store_awk" \
		"$cfmgr_store_source/modules/backup.sh" "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_payload_hex##*/}" "$cfmgr_archive_inventory_limit" || return $?
	cfmgr_payload_preserve "$cfmgr_probe_stdout" "$cfmgr_archive_inventory_limit" || return $?
	cfmgr_payload_yaml=$cfmgr_payload_result
	cfmgr_archive_format_remove "$cfmgr_payload_hex"
}

cfmgr_payload_certificate_decode() {
	cfmgr_archive_measure "$1" || return $?
	[ "$cfmgr_archive_bytes" -gt 0 ] && [ "$cfmgr_archive_bytes" -le 65536 ] || return 1
	cfmgr_payload_hex "$1" || return $?
	cfmgr_archive_run archive-payload-pem 131072 "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" \
		"/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_payload_hex##*/}" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_payload_tag cfmgr_payload_version cfmgr_payload_base64 cfmgr_payload_end cfmgr_payload_extra <<EOF_PAYLOAD_PEM
$cfmgr_store_line
EOF_PAYLOAD_PEM
	[ "$cfmgr_payload_tag:$cfmgr_payload_version:$cfmgr_payload_end:$cfmgr_payload_extra" = CFMGR-PEM:1:END: ] || return 1
	cfmgr_payload_ram_name
	(
		umask 077
		set -C
		cd /proc/self/fd/5 && printf '%s\n' "$cfmgr_payload_base64" >"${cfmgr_payload_ram##*/}"
	) || return 1
	cfmgr_payload_ram_record "$cfmgr_payload_ram" || return 1
	cfmgr_payload_encoded=$cfmgr_payload_ram
	cfmgr_payload_serial=$((cfmgr_payload_serial + 1))
	cfmgr_payload_decoded=$cfmgr_archive_stage/payload-$cfmgr_payload_serial.decoded
	cfmgr_archive_io base64 65536 "$cfmgr_payload_encoded" "$cfmgr_payload_decoded" || return $?
	cfmgr_archive_format_record "$cfmgr_payload_decoded" || return 1
	cfmgr_payload_preserve "/proc/self/fd/7/$cfmgr_archive_stage_leaf/${cfmgr_payload_decoded##*/}" 65536 || return $?
	cfmgr_archive_format_remove "$cfmgr_payload_decoded" && cfmgr_archive_format_remove "$cfmgr_payload_hex"
}

cfmgr_payload_index() {
	cfmgr_archive_run archive-payload-index "$cfmgr_archive_inventory_limit" "$cfmgr_store_awk" \
		"$cfmgr_store_source/modules/backup.sh" "$cfmgr_payload_plan" "${cfmgr_payload_yaml:--}" "$cfmgr_archive_inventory_limit" || return $?
	cfmgr_payload_preserve "$cfmgr_probe_stdout" "$cfmgr_archive_inventory_limit" || return $?
	cfmgr_payload_capture_plan=$cfmgr_payload_result
	cfmgr_payload_index_lines=0 cfmgr_payload_index_end=0 cfmgr_payload_auth_line=''
	cfmgr_payload_certificate_account='' cfmgr_payload_index_backup=0
	# Temporarily borrow stdout for a read-only control stream. Children have
	# their own captured stdout; config0, source3, rotation4 and support9 stay
	# pinned. The surrounding redirection restores the API output afterward.
	while IFS=' ' read -r cfmgr_payload_tag cfmgr_payload_a cfmgr_payload_b cfmgr_payload_c cfmgr_payload_d cfmgr_payload_rest <&1; do
		[ "$cfmgr_payload_index_end" = 0 ] || return 1
		cfmgr_payload_index_lines=$((cfmgr_payload_index_lines + 1))
		case $cfmgr_payload_tag in
		CFMGR-CAPTURE-PLAN)
			[ "$cfmgr_payload_index_lines:$cfmgr_payload_a" = 1:1 ] && [ -z "$cfmgr_payload_d$cfmgr_payload_rest" ] || return 1
			cfmgr_payload_schema=$cfmgr_payload_b cfmgr_payload_generation=$cfmgr_payload_c
			;;
		BACKUP)
			[ "$cfmgr_payload_index_backup" = 0 ] && [ -z "$cfmgr_payload_d$cfmgr_payload_rest" ] || return 1
			cfmgr_payload_index_backup=1 cfmgr_payload_date_order=$cfmgr_payload_a cfmgr_payload_keep=$cfmgr_payload_b cfmgr_payload_set_id=$cfmgr_payload_c
			;;
		AUTH)
			[ -z "$cfmgr_payload_auth_line$cfmgr_payload_rest" ] || return 1
			cfmgr_payload_auth_line="CFMGR-AUTH 1 $cfmgr_payload_a $cfmgr_payload_b $cfmgr_payload_c $cfmgr_payload_d END"
			;;
		CERT)
			[ -z "$cfmgr_payload_certificate_account$cfmgr_payload_rest" ] || return 1
			cfmgr_payload_certificate_account=$cfmgr_payload_b
			;;
		END)
			[ "$cfmgr_payload_a" = "$((cfmgr_payload_index_lines - 1))" ] && [ -z "$cfmgr_payload_b$cfmgr_payload_c$cfmgr_payload_d$cfmgr_payload_rest" ] || return 1
			cfmgr_payload_index_end=1
			;;
		FILE | NOTE | EXTERNAL | HISTORY) ;;
		*) return 1 ;;
		esac
	done 1<"$cfmgr_payload_capture_plan"
	[ "$cfmgr_payload_index_end:$cfmgr_payload_index_backup" = 1:1 ] || return 1
	if [ -n "$cfmgr_payload_auth_line" ]; then
		cfmgr_payload_ram_name
		(
			umask 077
			set -C
			cd /proc/self/fd/5 && printf '%s\n' "$cfmgr_payload_auth_line" >"${cfmgr_payload_ram##*/}"
		) || return 1
		cfmgr_payload_ram_record "$cfmgr_payload_ram" || return 1
		cfmgr_payload_authority=$cfmgr_payload_ram
	fi
}

cfmgr_archive_verify_payload() {
	[ "$#" -eq 9 ] || return 1
	case $1 in
	manager.config) cfmgr_payload_json plan "$9" - ;;
	manager.catalog) [ "$6" -gt 0 ] && [ "$6" -le 1048576 ] ;; # Informational data; never code selection.
	data.cloudflared.yaml) cfmgr_payload_yaml "$9" ;;
	data.cloudflared.json)
		cfmgr_payload_preserve "$9" 65536 || return $?
		cfmgr_payload_json=$cfmgr_payload_result
		;;
	data.cloudflared.certificate | data.cloudflared.certificate-recovery)
		cfmgr_payload_certificate_decode "$9" || return $?
		if [ "$1" = data.cloudflared.certificate ]; then cfmgr_payload_certificate=$cfmgr_payload_result; else cfmgr_payload_recovery=$cfmgr_payload_result; fi
		;;
	data.setup-drafts) cfmgr_payload_json drafts "$9" "$4" ;;
	data.cloudflared.yaml-backup | data.cloudflared.input.* | history.ddns | history.ip_sync | history.cloudflared) return 0 ;;
	*) return 1 ;;
	esac
}

cfmgr_archive_verify_complete() {
	cfmgr_payload_inventory=$1
	[ -n "$cfmgr_payload_plan" ] && cfmgr_payload_index || return $?
	[ "$cfmgr_payload_schema:$cfmgr_payload_generation:$cfmgr_payload_set_id:$cfmgr_payload_date_order" = \
		"$cfmgr_format_schema:$cfmgr_format_generation:$cfmgr_format_set:$cfmgr_format_order" ] || return 1
	case $cfmgr_payload_keep in 3 | 4 | 5) ;; *) return 1 ;; esac
	if [ -n "$cfmgr_payload_json" ]; then
		[ -n "$cfmgr_payload_authority" ] && cfmgr_payload_json runtime-json "$cfmgr_payload_json" "$cfmgr_payload_authority" || return 1
	fi
	for cfmgr_payload_cert_data in "$cfmgr_payload_certificate" "$cfmgr_payload_recovery"; do
		[ -n "$cfmgr_payload_cert_data" ] || continue
		[ -n "$cfmgr_payload_certificate_account" ] && cfmgr_payload_json certificate-json "$cfmgr_payload_cert_data" "$cfmgr_payload_certificate_account" || return 1
	done
	cfmgr_archive_run archive-payload-match 4096 "$cfmgr_store_awk" "$cfmgr_store_source/modules/backup.sh" \
		"$cfmgr_payload_capture_plan" "$cfmgr_payload_inventory" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" && [ "$cfmgr_store_line" = 'CFMGR-PAYLOAD-MATCH 1 complete END' ] || return 1
	cfmgr_archive_format_retire
}

# ---- Backup destination and retained archive source policy ----
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
	cfmgr_store_run store-backup-mount "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/storage.sh" "$1" || return $?
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
	[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_backup_mount" /proc/self/mountinfo)" = "$cfmgr_backup_snapshot" ] || return 1
	cfmgr_backup_fd_mount 6 || return 1
	if [ "${cfmgr_backup_folder_pinned:-0}" = 1 ]; then
		[ ! -L "$cfmgr_backup_mount/CFBackup" ] && [ "$cfmgr_backup_mount/CFBackup" -ef /proc/self/fd/7 ] || return 1
		[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_backup_mount/CFBackup" /proc/self/mountinfo)" = "$cfmgr_backup_snapshot" ] || return 1
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
	[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_backup_mount/CFBackup" /proc/self/mountinfo)" = "$cfmgr_backup_snapshot" ] || return 1
	{ exec 7<&3; } 3<"$cfmgr_backup_mount/CFBackup" || return 1
	cfmgr_backup_folder_pinned=1
	cfmgr_backup_attached
}

# Concurrent archive source attachment. This deliberately does not call the
# Entware execution pin helper: destination6/7 must survive, and read-only or
# noexec source mounts are valid data sources. UUID evidence is supervised.
cfmgr_archive_source_release() {
	exec 3<&-
	cfmgr_archive_source_pinned=0
}

cfmgr_archive_source_pin() {
	# Saved UUID FILESYSTEM FSROOT RELATIVE; no config reads or alias fallback.
	[ "$#" -eq 4 ] && [ "${cfmgr_archive_source_pinned:-0}" != 1 ] || return 2
	# FD3 must be free; never discard another owner's descriptor.
	if (: <&3) 2>/dev/null; then return 2; fi
	case $2 in ext2 | ext3 | ext4) ;; *) return 1 ;; esac
	_cfmgr_storage_path "$3" || return 2
	case $4 in
	.) ;;
	'' | /* | *[!\ -~]* | *//* | ./* | ../* | */./* | */../* | */. | */.. | */) return 2 ;;
	esac
	cfmgr_archive_source_want_uuid=$1 cfmgr_archive_source_want_fs=$2
	cfmgr_archive_source_want_root=$3 cfmgr_archive_source_want_relative=$4
	cfmgr_archive_run archive-source-realpath 4096 "$cfmgr_store_readlink" /opt || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_archive_source_root=$cfmgr_store_line
	_cfmgr_storage_path "$cfmgr_archive_source_root" &&
		[ -d "$cfmgr_archive_source_root" ] && [ ! -L "$cfmgr_archive_source_root" ] || return 1
	cfmgr_archive_run archive-source-mount 8192 "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/storage.sh" "$cfmgr_archive_source_root" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_archive_source_snapshot=$cfmgr_store_line
	IFS='	' read -r cfmgr_archive_source_id cfmgr_archive_source_parent cfmgr_archive_source_device \
		cfmgr_archive_source_fsroot cfmgr_archive_source_mount cfmgr_archive_source_fs \
		cfmgr_archive_source_device_path cfmgr_archive_source_options cfmgr_archive_source_super cfmgr_archive_source_extra <<EOF_ARCHIVE_SOURCE
$cfmgr_archive_source_snapshot
EOF_ARCHIVE_SOURCE
	[ -z "$cfmgr_archive_source_extra" ] && [ -b "$cfmgr_archive_source_device_path" ] &&
		[ "$cfmgr_archive_source_fs:$cfmgr_archive_source_fsroot" = "$cfmgr_archive_source_want_fs:$cfmgr_archive_source_want_root" ] || return 1
	_cfmgr_storage_path "$cfmgr_archive_source_mount" && [ ! -L "$cfmgr_archive_source_mount" ] || return 1
	# A real block mount at /opt is admissible; a bare directory left behind
	# under another filesystem is not a substitute for its former attachment.
	[ "$cfmgr_archive_source_root" != /opt ] || [ "$cfmgr_archive_source_mount" = /opt ] || return 1
	if [ "$cfmgr_archive_source_root" = "$cfmgr_archive_source_mount" ]; then
		cfmgr_archive_source_relative=.
	else
		case $cfmgr_archive_source_root in "$cfmgr_archive_source_mount"/?*) ;; *) return 1 ;; esac
		cfmgr_archive_source_relative=${cfmgr_archive_source_root#"$cfmgr_archive_source_mount"/}
	fi
	[ "$cfmgr_archive_source_relative" = "$cfmgr_archive_source_want_relative" ] || return 1
	cfmgr_archive_run archive-source-blkid 8192 /sbin/blkid "$cfmgr_archive_source_device_path" || return $?
	cfmgr_archive_source_uuid=$(
		cfmgr_storage_awk=$cfmgr_store_awk cfmgr_storage_source=$cfmgr_archive_source_device_path cfmgr_storage_filesystem=$cfmgr_archive_source_fs
		cfmgr_storage_uuid "$cfmgr_probe_stdout" && printf '%s\n' "$cfmgr_storage_uuid_value"
	) || return 1
	[ "$cfmgr_archive_source_uuid" = "$cfmgr_archive_source_want_uuid" ] || return 1
	exec 3<"$cfmgr_archive_source_root" || return 1
	cfmgr_archive_source_pinned=1
	if ! cfmgr_archive_source_attached; then
		cfmgr_archive_source_release
		return 1
	fi
}

# shellcheck disable=SC3013
cfmgr_archive_source_attached() {
	[ "${cfmgr_archive_source_pinned:-0}" = 1 ] && [ ! -L "$cfmgr_archive_source_root" ] &&
		[ "$cfmgr_archive_source_root" -ef /proc/self/fd/3 ] || return 1
	[ "$("$cfmgr_store_readlink" -f /opt)" = "$cfmgr_archive_source_root" ] || return 1
	[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_archive_source_root" /proc/self/mountinfo)" = "$cfmgr_archive_source_snapshot" ] || return 1
	# Exact kernel mount identity catches lazy detach/replacement even when an
	# inode remains reachable through its retained open directory descriptor.
	# shellcheck disable=SC2016
	"$cfmgr_store_awk" 'BEGIN{id=ARGV[1];ARGV[1]=""} $1=="mnt_id:"{n++;if(NF!=2 || $2!=id)bad=1} END{exit(n!=1 || bad)}' \
		"$cfmgr_archive_source_id" /proc/self/fdinfo/3
}

cfmgr_backup_awk_backup_yaml() {
	# CFMGR-AWK-BEGIN backup_yaml
	cfmgr_awk_program='
# Read-only supported-subset YAML identity/dependency reader. Input is native
# hexdump -v -e 1/1 "%02x\n"; original YAML is never rewritten. The caller
# supplies a positive CFMGR_YAML_METADATA_LIMIT byte budget and LC_ALL=C.

function fail(reason) {
	if (!failure) { failure = reason; print "CFMGR-YAML-ERROR 1 " failure " END" }
	failure_printed=1
	exit 1
}
function charge(bytes) {
	if (bytes > budget - used) fail("metadata-limit")
	used += bytes
}
# Streaming Unicode admission keeps no source-sized auxiliary buffer. The
# first continuation bounds exclude overlong forms, surrogates and >U+10FFFF.
function utf8(byte) {
	if (utf8_remaining) {
		if (byte<utf8_min || byte>utf8_max) fail("invalid-utf8")
		utf8_remaining--; utf8_min=128; utf8_max=191
		return
	}
	if (byte<128) return
	utf8_min=128; utf8_max=191
	if (byte>=194 && byte<=223) utf8_remaining=1
	else if (byte>=224 && byte<=239) {
		utf8_remaining=2
		if (byte==224) utf8_min=160
		else if (byte==237) utf8_max=159
	} else if (byte>=240 && byte<=244) {
		utf8_remaining=3
		if (byte==240) utf8_min=144
		else if (byte==244) utf8_max=143
	} else fail("invalid-utf8")
}
function trim(s) { sub(/^ +/, "", s); sub(/ +$/, "", s); return s }
function hex(s,    out,i) {
	out = ""
	for (i = 1; i <= length(s); i++) out = out sprintf("%02x", ordinal[substr(s,i,1)])
	return out
}
function unicode(n) {
	if (n < 128) return sprintf("%c", n)
	if (n < 2048) return sprintf("%c%c", 192+int(n/64), 128+n%64)
	if (n < 65536) return sprintf("%c%c%c", 224+int(n/4096), 128+int(n/64)%64, 128+n%64)
	return sprintf("%c%c%c%c", 240+int(n/262144), 128+int(n/4096)%64, 128+int(n/64)%64, 128+n%64)
}
function ucode(s,    i,n,c) {
	if (length(s) != 4 || s ~ /[^0-9a-fA-F]/) fail("unsupported-escape")
	n = 0
	for (i=1; i<=4; i++) { c=index("0123456789abcdef",tolower(substr(s,i,1)))-1; n=n*16+c }
	return n
}
# Decode one scalar, recording whether it was quoted. Comments are stripped by
# lexical(), so closing quotes must exhaust the scalar. No multiline scalars.
function scalar(s,    q,out,i,c,e,n,low,closed) {
	s=trim(s); quoted=0
	q=substr(s,1,1)
	if (q!="\"" && q!="\047") {
		if (s ~ /^[\[\{&*!%@`]/ || s ~ /\t/) fail("unsupported-syntax")
		if (s ~ /:($| )/) fail("unsupported-scalar")
		return s
	}
	quoted=1; out=""; closed=0
	for (i=2; i<=length(s); i++) {
		c=substr(s,i,1)
		if (c==q) {
			if (q=="\047" && substr(s,i+1,1)=="\047") { out=out "\047"; i++; continue }
			if (i!=length(s)) fail("malformed-quote")
			closed=1; break
		}
		if (q=="\"" && c=="\\") {
			e=substr(s,++i,1)
			if (e=="\"" || e=="\\" || e=="/") out=out e
			else if (e=="b") out=out sprintf("%c",8)
			else if (e=="f") out=out sprintf("%c",12)
			else if (e=="n") out=out "\n"
			else if (e=="r") out=out "\r"
			else if (e=="t") out=out "\t"
			else if (e=="u") {
				n=ucode(substr(s,i+1,4)); i+=4
				if (n>=55296 && n<=56319) {
					if (substr(s,i+1,2)!="\\u") fail("unsupported-escape")
					low=ucode(substr(s,i+3,4)); i+=6
					if (low<56320 || low>57343) fail("unsupported-escape")
					n=65536+(n-55296)*1024+low-56320
				} else if (n>=56320 && n<=57343) fail("unsupported-escape")
				out=out unicode(n)
			} else fail("unsupported-escape")
		} else out=out c
	}
	if (!closed) fail("malformed-quote")
	return out
}
# Locate mapping separators and comments without interpreting quoted contents.
function lexical(s,    i,c,q,escaped,nextc) {
	q=""; colon=0
	for (i=1; i<=length(s); i++) {
		c=substr(s,i,1); nextc=substr(s,i+1,1)
		if (q!="") {
			if (q=="\"" && c=="\\") { i++; continue }
			if (c==q) {
				if (q=="\047" && nextc=="\047") { i++; continue }
				q=""
			}
		} else {
			if (c=="\t") fail("unsupported-tab")
			if ((c=="\"" || c=="\047") && (i==1 || substr(s,i-1,1) ~ /[ :\-]/)) q=c
			else if (c=="#" && (i==1 || substr(s,i-1,1)==" ")) return trim(substr(s,1,i-1))
			else if (!colon && c==":" && (nextc=="" || nextc==" ")) colon=i
		}
	}
	if (q!="") fail("malformed-quote")
	return trim(s)
}
function path(s,    parts,n,i) {
	if (length(s)>1024 || s!~/^\// || s~/[^ -~]/ || s~/\\/) fail("invalid-path")
	n=split(s,parts,"/")
	for (i=2; i<=n; i++) if (parts[i]=="" || parts[i]=="." || parts[i]=="..") fail("invalid-path")
	return s
}
function uuid(s,    parts,n,i) {
	n=split(s,parts,"-")
	if (n!=5 || length(parts[1])!=8 || length(parts[2])!=4 || length(parts[3])!=4 || length(parts[4])!=4 || length(parts[5])!=12) fail("invalid-identity")
	for (i=1; i<=n; i++) if (parts[i]~/[^0-9a-fA-F]/) fail("invalid-identity")
	if (s=="00000000-0000-0000-0000-000000000000") fail("invalid-identity")
	return tolower(s)
}
function push(indent,kind,role) {
	if (depth>=64) fail("unsupported-depth")
	charge(64); depth++; frame_indent[depth]=indent; frame_kind[depth]=kind
	frame_role[depth]=role; frame_id[depth]=sprintf("%.0f",++map_serial)
}
function input(role,value,    row) {
	row="INPUT " sprintf("%.0f",input_count+1) " " role " " hex(path(value)) "\n"
	charge(length(value)+length(row)+32); inputs[++input_count]=row
}
function control(role,value,    row) {
	row="CONTROL " role " " hex(path(value)) "\n"
	charge(length(value)+length(row)+32); controls[++control_count]=row
}
function recognize(key,context,    folded,canonical) {
	folded=tolower(key)
	canonical=""
	if (context=="root" && (folded in recognized)) canonical=recognized[folded]
	else if (context=="origin" && folded=="capool") canonical="caPool"
	else if (context=="ingress-item" && folded=="originrequest") canonical="originRequest"
	if (canonical!="" && canonical!=key) fail("ambiguous-key-case")
	if (key=="<<") fail("unsupported-merge")
	field="ordinary"; role="other"
	if (context=="root") {
		if (key=="tunnel") field="identity"
		else if (key=="credentials-file" || key=="cred-file") field="credentials"
		else if (key=="origincert" || key=="cacert" || key=="origin-ca-pool") field="input"
		else if (key=="token" || key=="token-file" || key=="credentials-contents" || key=="config") field="authority"
		else if (key=="logfile" || key=="log-directory" || key=="pidfile" || key=="trace-output") field="control"
		else if (key=="originRequest") role="origin"
		else if (key=="ingress") role="ingress"
	} else if (context=="origin" && key=="caPool") field="input"
	else if (context=="ingress-item" && key=="originRequest") role="origin"
}
function mapping(text,indent,    key,value,empty,id,wasquoted,bh) {
	text=lexical(text)
	if (!colon) fail("expected-mapping")
	key=scalar(substr(text,1,colon-1))
	if (key=="<<") fail("unsupported-merge")
	if (key!~/^[A-Za-z0-9_.-]+$/) fail("unsupported-key")
	value=trim(substr(text,colon+1)); id=frame_id[depth] SUBSEP key
	if (id in keys) fail("duplicate-key")
	charge(length(id)+length(key)+32); keys[id]=1
	recognize(key,frame_role[depth])
	if (field=="credentials") { if (credential_seen++) fail("duplicate-authority"); credential_key=key }
	if (substr(value,1,1)=="|" || substr(value,1,1)==">") {
		if (field!="ordinary" || role!="other") fail("unsupported-field-scalar")
		bh=substr(value,2)
		if (length(bh)>2 || bh!~/^([+-]?[1-9]?|[1-9][+-]?)$/) fail("unsupported-block-scalar")
		block=1; block_parent=indent; block_min=0
		gsub(/[+-]/,"",bh); if (bh!="") block_min=indent+(bh+0)
		return
	}
	value=scalar(value); wasquoted=quoted
	empty=(!wasquoted && (value=="" || value=="~" || value=="null" || value=="Null" || value=="NULL"))
	if (field=="identity") { if (empty || value=="") fail("missing-identity"); identity=uuid(value); charge(length(identity)+64) }
	else if (field=="credentials") { if (empty || value=="") fail("missing-credentials"); credentials=path(value); charge(length(credentials)*3+64) }
	else if (field=="input" && !empty && value!="") input(key,value)
	else if (field=="control" && !empty && value!="") control(key,value)
	else if (field=="authority" && !empty && value!="") fail("conflicting-authority")
	# A syntactically empty value may introduce a child container on the next
	# significant line. Scalar-owned fields must never acquire hidden children.
	if (trim(substr(text,colon+1))=="") {
		pending=1; pending_indent=indent; pending_role=role
		pending_scalar=(field!="ordinary")
	} else if (role!="other" && !empty) fail("unsupported-container")
}
function line(s,    indent,text,kind,rest,context,item_indent) {
	indent=match(s,/[^ ]/)-1
	if (s ~ /^ *$/) return
	if (indent<0) indent=length(s)
	if (block) {
		if (indent>block_parent) {
			if (!block_min) block_min=indent
			if (indent<block_min) fail("invalid-indentation")
			if (s~/\t/) fail("unsupported-tab")
			return
		}
		block=0
	}
	text=lexical(substr(s,indent+1))
	if (text=="") return
	if (text=="---") {
		if (indent || document || started || ended) fail("multiple-documents")
		document=1; return
	}
	if (text=="...") {
		if (indent || !started || ended) fail("invalid-document")
		ended=1; return
	}
	if (ended) fail("multiple-documents")
	if (substr(text,1,1)=="%") fail("unsupported-directive")
	if (!started) { if (indent) fail("invalid-indentation"); push(0,"map","root"); started=1 }
	if (pending) {
		pending=0
		if (indent>pending_indent) {
			if (pending_scalar) fail("unsupported-field-scalar")
			kind=(text=="-" || text~/^- /) ? "seq" : "map"
			if ((pending_role=="ingress" && kind!="seq") || ((pending_role=="origin" || pending_role=="ingress-item") && kind!="map")) fail("unsupported-container")
			push(indent,kind,pending_role)
		}
	}
	while (depth>1 && indent<frame_indent[depth]) depth--
	if (indent!=frame_indent[depth]) fail("invalid-indentation")
	if (frame_kind[depth]=="seq") {
		if (text!="-" && text!~/^- /) fail("expected-sequence")
		item_indent=indent+match(substr(text,2),/[^ ]/)
		rest=trim(substr(text,2)); context=frame_role[depth]=="ingress" ? "ingress-item" : "other"
		if (rest=="") { pending=1; pending_indent=indent; pending_role=context; pending_scalar=0; return }
		lexical(rest)
		if (colon) { push(item_indent,"map",context); mapping(rest,item_indent) }
		else { if (context=="ingress-item") fail("expected-mapping"); if (rest~/^- /) fail("unsupported-sequence"); scalar(rest) }
	} else mapping(text,indent)
}
BEGIN {
	budget=ENVIRON["CFMGR_YAML_METADATA_LIMIT"]
	if (budget!~/^[1-9][0-9]*$/ || length(budget)>16 || (length(budget)==16 && "x" budget>"x9007199254740991")) fail("invalid-budget")
	budget+=0; used=64; if (used>budget) fail("metadata-limit")
	for (i=0; i<256; i++) ordinal[sprintf("%c",i)]=i
	n=split("tunnel credentials-file cred-file origincert cacert origin-ca-pool originRequest ingress token token-file credentials-contents config logfile log-directory pidfile trace-output", names, " ")
	for (i=1; i<=n; i++) recognized[tolower(names[i])]=names[i]
}
{
	if (length($0)!=2 || $0~/[^0-9a-f]/) fail("invalid-hex")
	byte=(index("0123456789abcdef",substr($0,1,1))-1)*16+index("0123456789abcdef",substr($0,2,1))-1
	utf8(byte)
	if (carriage && byte!=10) fail("invalid-line-ending")
	if (byte==13) { carriage=1; next }
	if (byte==10) { line(buffer); buffer=""; carriage=0; next }
	if (byte<32 && byte!=9 || byte==127) fail("invalid-control")
	if (length(buffer)>=65536) fail("unsupported-line-size")
	buffer=buffer sprintf("%c",byte)
}
END {
	if (!failure) {
		if (utf8_remaining) failure="invalid-utf8"
		else if (carriage) failure="invalid-line-ending"
		else if (length(buffer)) line(buffer)
	}
	if (!failure && (!started || identity=="")) failure="missing-identity"
	if (!failure && credentials=="") failure="missing-credentials"
	if (failure) { if (!failure_printed) print "CFMGR-YAML-ERROR 1 " failure " END"; exit 1 }
	header="CFMGR-YAML 1\nIDENTITY " identity " " hex(credentials) "\n"
	trailer="END " sprintf("%.0f %.0f",input_count,control_count) "\n"
	output_size=length(header)+length(trailer)
	for (i=1; i<=input_count; i++) output_size+=length(inputs[i])
	for (i=1; i<=control_count; i++) output_size+=length(controls[i])
	if (output_size>budget) fail("metadata-limit")
	printf "%s", header
	for (i=1; i<=input_count; i++) printf "%s", inputs[i]
	for (i=1; i<=control_count; i++) printf "%s", controls[i]
	printf "%s", trailer
}
'
	# CFMGR-AWK-END backup_yaml
}

cfmgr_backup_awk_backup_manifest() {
	# CFMGR-AWK-BEGIN backup_manifest
	cfmgr_awk_program='
# Fixed archive metadata decoder/shared exact-decimal grammar. Inputs are native
# hexdump records (two lowercase hex digits per LF), never unbounded text lines.
# Inventory mode adds backup inventory getter; no archive-selected code is loaded.
function am_fail() { am_bad=1; exit 1 }
function am_uint(s, max) {
    return s ~ /^(0|[1-9][0-9]*)$/ && am_cmp(s,max)<=0
}
function am_cmp(a,b, i,x,y) {
    if(length(a)!=length(b))return length(a)<length(b)?-1:1
    for(i=1;i<=length(a);i++){x=substr(a,i,1)+0;y=substr(b,i,1)+0;if(x!=y)return x<y?-1:1}
    return 0
}
function am_add(a,b, i,x,y,n,carry,out) {
    out="";carry=0
    for(i=0;i<length(a)||i<length(b)||carry;i++) {
        x=i<length(a)?substr(a,length(a)-i,1)+0:0;y=i<length(b)?substr(b,length(b)-i,1)+0:0
        n=x+y+carry;out=sprintf("%d",n%10) out;carry=int(n/10)
    }
    if(am_cmp(out,am_max)>0)am_fail()
    return out
}
function am_hex(s,n) { return length(s)==n && s!~/[^0-9a-f]/ }
function am_uuid(s, t) {
    if(length(s)!=36 || substr(s,9,1)!="-" || substr(s,14,1)!="-" || substr(s,19,1)!="-" || substr(s,24,1)!="-")return 0
    t=s;gsub(/-/,"",t);return am_hex(t,32)
}
function am_printhex(s, max, i,a,b,c,out) {
    if(length(s)<2 || length(s)>2*max || length(s)%2 || s~/[^0-9a-f]/)am_fail()
    out=""
    for(i=1;i<=length(s);i+=2) {
        a=index("0123456789abcdef",substr(s,i,1))-1;b=index("0123456789abcdef",substr(s,i+1,1))-1;c=a*16+b
        if(c<32 || c>126)am_fail()
        out=out sprintf("%c",c)
    }
    return out
}
function am_generation(s) {return length(s)<=20 && s~/^[1-9][0-9]*$/}
function am_calendar(day,clock, d,t,y,m,n,maxday) {
    if(day!~/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ || clock!~/^[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/)return 0
    split(day,d,"-");split(clock,t,"-");y=d[1]+0;m=d[2]+0;n=d[3]+0
    if(y<1 || m<1 || m>12 || n<1 || t[1]+0>23 || t[2]+0>59 || t[3]+0>59)return 0
    maxday=(m==4||m==6||m==9||m==11)?30:31
    if(m==2)maxday=(y%4==0 && (y%100!=0||y%400==0))?29:28
    return n<=maxday
}
function am_manifest(line, n,a) {
    n=split(line,a," ");am_lines++
    if(am_lines==1){if(line!="CFMGR-ARCHIVE 1")am_fail()}
    else if(am_lines==2){if(n!=2 || a[1]!="SET" || !am_uuid(a[2]) || a[2]!=ENVIRON["CFMGR_ARCHIVE_SET"])am_fail();am_set=a[2]}
    else if(am_lines==3){if(n!=2 || a[1]!="ARCHIVE" || !am_uuid(a[2]))am_fail();am_archive=a[2]}
    else if(am_lines==4){
        if(n!=7 || a[1]!="CREATED" || !am_uint(a[2],"9999999999") || !am_calendar(a[3],a[4]) || a[6]!~/^[+-][0-9][0-9][0-9][0-9]$/ || substr(a[6],2,2)+0>23 || substr(a[6],4,2)+0>59 || a[7]!~/^(DMY|MDY|YMD)$/)am_fail()
        am_printhex(a[5],256);am_created=a[2] " " a[3] " " a[4] " " a[5] " " a[6] " " a[7]
    }
    else if(am_lines==5){if(n!=3 || a[1]!="CONFIG" || a[2]!~/^[12]$/ || !am_generation(a[3]))am_fail();am_config=a[2] " " a[3]}
    else if(am_lines==6){
        if(n!=6 || a[1]!="INVENTORY" || !am_uint(a[2],am_max) || !am_uint(a[3],am_max) || a[3]=="0" || !am_hex(a[4],64) || !am_uint(a[5],"99999999") || a[5]+0<2 || !am_uint(a[6],am_max))am_fail()
        am_inventory=a[2] " " a[3] " " a[4] " " a[5] " " a[6]
    }
    else if(am_lines==7){if(line!="END")am_fail()}
    else am_fail()
}
BEGIN {
    am_max="9223372036854775807";am_mode=ENVIRON["CFMGR_ARCHIVE_FORMAT_MODE"]
    if(am_mode!="manifest" && am_mode!="inventory")am_fail()
}
{
    am_ready=0
    if(length($0)!=2 || $0~/[^0-9a-f]/)am_fail()
    am_char=(index("0123456789abcdef",substr($0,1,1))-1)*16+index("0123456789abcdef",substr($0,2,1))-1
    am_bytes++
    if(am_char==10) {
        if(length(am_line)+1>4096)am_fail()
        am_decoded=am_line;am_line="";am_ready=1
        if(am_decoded=="" || am_decoded~/^ | $|  /)am_fail()
        if(am_mode=="manifest")am_manifest(am_decoded)
    } else {
        if(am_char<32 || am_char>126 || length(am_line)>=4095)am_fail()
        am_line=am_line sprintf("%c",am_char)
    }
}
END {
    if(am_bad)exit 1
    if(am_line!="" || !am_ready || !NR)am_fail()
    if(am_mode=="manifest") {
        if(am_lines!=7 || am_bytes>4096)am_fail()
        print "CFMGR-MANIFEST 1 " am_set " " am_archive " " am_created " " am_config " " am_inventory " END"
    }
}
'
	# CFMGR-AWK-END backup_manifest
}

cfmgr_backup_awk_backup_payload_index() {
	# CFMGR-AWK-BEGIN backup_payload_index
	cfmgr_awk_program='
# Join private, fully validated config/YAML receipts into a data capture plan.
# Caller bounds and owns both immutable inputs. No source files are opened here.
# ARGV: config-plan YAML-receipt-or-dash. Output is private; AUTH contains secrets.
function bx_fail() { bx_bad=1; exit 1 }
function bx_hex(s,    i,out) {
    out=""; for(i=1;i<=length(s);i++) out=out sprintf("%02x",bx_ord[substr(s,i,1)])
    return out
}
function bx_decode(s,    i,out,n) {
    if(s=="" || length(s)%2 || s~/[^0-9a-f]/) bx_fail()
    out=""
    for(i=1;i<=length(s);i+=2) {
        n=(index("0123456789abcdef",substr(s,i,1))-1)*16+index("0123456789abcdef",substr(s,i+1,1))-1
        if(n<32 || n>126) bx_fail()
        out=out sprintf("%c",n)
    }
    return out
}
function bx_emit(row) { bx_bytes+=length(row)+1; if(bx_bytes>bx_limit)bx_fail(); bx_rows[++bx_count]=row }
function bx_file(role,need,pathhex,gen,sha,    path,scope,relative) {
    if(bx_selected[role]++) bx_fail()
    path=bx_decode(pathhex)
    if(substr(path,1,6)=="/jffs/"){scope="jffs";relative=substr(path,7)}
    else if(substr(path,1,5)=="/opt/"){scope="entware";relative=substr(path,6)}
    else bx_fail()
    bx_emit("FILE " role " " need " " scope " " bx_hex(relative) " " gen " " sha " whole")
    bx_file_row[role]=bx_count
}
function bx_required(role,    row) {
    row=bx_file_row[role]
    if(!row)bx_fail()
    # Rows remain private until the entire join succeeds. Any input purpose
    # other than management origincert requires bytes, regardless of the order
    # of duplicate references to the same selected certificate pathname.
    sub(" optional "," required ",bx_rows[row])
    bx_need[role]="required"
}
function bx_read_plan(path,    row,a,n,lines,ended,role) {
    while((getline row <path)>0) {
        if(ended || length(row)>131072)bx_fail()
        n=split(row,a," ");lines++
        if(lines==1) {
            if(n!=4 || a[1]!="CFMGR-PAYLOAD-PLAN" || a[2]!="1")bx_fail()
            bx_schema=a[3];bx_gen=a[4]
        } else if(a[1]=="FILE") {
            if(n!=6 || bx_files[a[2]]++)bx_fail()
            role=a[2];bx_file_role[++bx_nfiles]=role;bx_need[role]=a[3];bx_path[role]=a[4];bx_gen_for[role]=a[5];bx_sha[role]=a[6]
        } else if(a[1]=="OWNER") {
            if(n!=5 || bx_owners[a[2]]++)bx_fail()
            role=a[2];bx_owner_path[role]=a[3];bx_owner_gen[role]=a[4];bx_owner_sha[role]=a[5]
            if(role~/^data\.cloudflared\.input\./) {
                if(bx_input_owner[a[3]]!="")bx_fail()
                bx_input_owner[a[3]]=role
            }
        } else if(a[1]=="AUTH") {
            if(n!=6 || bx_auth[a[2]]!="")bx_fail()
            bx_auth[a[2]]=a[4] " " a[5] " " a[6];bx_auth_tunnel[a[2]]=a[5]
        } else if(a[1]=="CLOUD") {
            if(n!=10 || bx_cloud++)bx_fail()
            bx_method=a[2];bx_configured=a[3];bx_runtime=a[7];bx_account=a[9];bx_tunnel=a[10]
        } else if(a[1]=="CERT") {
            if(n!=5 || bx_cert++)bx_fail()
            bx_cert_frame=row
        } else if(a[1]=="BACKUP") {
            if(n!=4 || bx_backup++)bx_fail()
            bx_backup_frame=row
        } else if(a[1]=="STATE") {
            if(n!=4 || bx_state_seen[a[2]]++)bx_fail()
            bx_state_configured[a[2]]=a[3]
        } else if(a[1]=="LOG") {
            if(n!=6 || bx_log_seen[a[2]]++)bx_fail()
            bx_log_eligible[a[2]]=(a[3]=="1" && a[5]=="0" && a[6]!="-")
        } else if(a[1]=="END") {
            if(n!=2 || a[2]!=lines-1)bx_fail();ended=1
        } else if(a[1]!~/^(STORAGE|LEGACY|WRITER)$/)bx_fail()
    }
    close(path)
    if(!ended || bx_nfiles<2 || bx_file_role[1]!="manager.config" || bx_file_role[2]!="manager.catalog" || bx_backup!=1)bx_fail()
}
function bx_yaml(path,    row,a,n,lines,ended,inputs,controls,ref,identity,key,chosen,value) {
    if(path=="-") { if(bx_files["data.cloudflared.yaml"])bx_fail();return }
    if(!bx_files["data.cloudflared.yaml"] || !bx_files["data.cloudflared.json"])bx_fail()
    while((getline row <path)>0) {
        if(ended || length(row)>4096)bx_fail()
        n=split(row,a," ");lines++
        if(lines==1) { if(row!="CFMGR-YAML 1")bx_fail() }
        else if(lines==2) {
            if(n!=3 || a[1]!="IDENTITY" || a[3]!=bx_path["data.cloudflared.json"])bx_fail()
            identity=a[2]
        } else if(a[1]=="INPUT") {
            if(n!=4 || a[2]!=++inputs)bx_fail()
            if(a[3]!~/^(origincert|cacert|origin-ca-pool|caPool)$/)bx_fail()
            ref=a[4];bx_decode(ref)
            if(ref==bx_path["data.cloudflared.certificate"] || ref==bx_path["data.cloudflared.certificate-recovery"]) {
                if(a[3]!="origincert")bx_required(ref==bx_path["data.cloudflared.certificate"] ? "data.cloudflared.certificate" : "data.cloudflared.certificate-recovery")
                continue
            }
            if(bx_seen_input[ref]++)continue
            if(ref in bx_input_owner) {
                key=bx_input_owner[ref]
                bx_file(key,"required",ref,bx_owner_gen[key],bx_owner_sha[key])
            } else bx_emit("EXTERNAL data.cloudflared.yaml " ref " input-reference")
        } else if(a[1]=="CONTROL") {
            if(n!=3 || a[2]!~/^(logfile|log-directory|pidfile|trace-output)$/)bx_fail()
            controls++;bx_decode(a[3]);bx_emit("NOTE data.cloudflared.yaml external " a[3] " output-reference END")
        } else if(a[1]=="END") {
            if(n!=3 || a[2]!=inputs || a[3]!=controls)bx_fail();ended=1
        } else bx_fail()
    }
    close(path);if(!ended || identity=="")bx_fail()
    if(bx_configured=="1" && bx_method=="advanced") {
        chosen=bx_runtime
        if(!(chosen in bx_auth) || bx_auth_tunnel[chosen]!=identity || tolower(bx_decode(bx_tunnel))!=identity)bx_fail()
        split(bx_auth[chosen],a," ");if("h" a[1]!="h" bx_account)bx_fail()
    } else {
        for(key in bx_auth) if(bx_auth_tunnel[key]==identity) {
            if(chosen!="" && "v" bx_auth[chosen]!="v" bx_auth[key])bx_fail()
            if(chosen=="" || key<chosen)chosen=key
        }
        if(chosen=="")bx_fail()
    }
    bx_emit("AUTH " chosen " " bx_auth[chosen])
}
BEGIN {
    if(ARGC!=3 || ENVIRON["LC_ALL"]!="C")bx_fail()
    bx_limit=ENVIRON["CFMGR_PAYLOAD_INDEX_LIMIT"]
    if(bx_limit!~/^[1-9][0-9]*$/ || length(bx_limit)>9 || bx_limit>16777216)bx_fail()
    for(bx_i=32;bx_i<=126;bx_i++)bx_ord[sprintf("%c",bx_i)]=bx_i
    bx_read_plan(ARGV[1]);bx_emit("CFMGR-CAPTURE-PLAN 1 " bx_schema " " bx_gen);bx_emit(bx_backup_frame)
    for(bx_i=1;bx_i<=bx_nfiles;bx_i++) {
        bx_role=bx_file_role[bx_i]
        bx_file(bx_role,bx_need[bx_role],bx_path[bx_role],bx_gen_for[bx_role],bx_sha[bx_role])
    }
    if(bx_cert)bx_emit(bx_cert_frame)
    split("data.cloudflared.yaml data.cloudflared.json data.cloudflared.certificate data.cloudflared.certificate-recovery",bx_absent," ")
    for(bx_i=1;bx_i<=4;bx_i++)if(!bx_files[bx_absent[bx_i]])bx_emit("NOTE " bx_absent[bx_i] " not_applicable - no-owned-data END")
    split("data.setup-drafts data.cloudflared.yaml-backup",bx_extras," ")
    for(bx_i=1;bx_i<=2;bx_i++) {
        bx_role=bx_extras[bx_i]
        if(bx_owners[bx_role])bx_file(bx_role,"required",bx_owner_path[bx_role],bx_owner_gen[bx_role],bx_owner_sha[bx_role])
        else bx_emit("NOTE " bx_role " not_applicable - no-owned-data END")
    }
    split("ddns ip_sync cloudflared",bx_features," ")
    for(bx_i=1;bx_i<=3;bx_i++) {
        bx_feature=bx_features[bx_i];bx_role="history." bx_feature
        if(bx_state_configured[bx_feature]=="1" && bx_log_eligible[bx_feature] && bx_owners[bx_role] && bx_owners["history-rule." bx_feature])
            bx_emit("HISTORY " bx_role " " bx_owner_path[bx_role] " " bx_owner_gen[bx_role])
    }
    bx_yaml(ARGV[2]);bx_emit("END " bx_count)
    for(bx_i=1;bx_i<=bx_count;bx_i++)print bx_rows[bx_i]
    exit 0
}
'
	# CFMGR-AWK-END backup_payload_index
}

cfmgr_backup_awk_backup_cloud_writer() {
	# CFMGR-AWK-BEGIN backup_cloud_writer
	cfmgr_awk_program='
# Bounded native FD/argv observation parser. No tokens or raw process data are
# emitted on failure. Hex input retains actual NUL argv boundaries.
function fail() { bad=1; exit 1 }
function hexbyte(s, i,n,c) {
    n=0
    for(i=1;i<=2;i++) { c=index("0123456789abcdef",substr(s,i,1))-1; if(c<0)fail(); n=n*16+c }
    return n
}
function argcheck( i,t,k,v,p,phase,logs,runs,seen,position) {
    if(argc<4 || argc>128 || argv[1]!="/opt/bin/cloudflared")fail()
    phase=0
    for(i=2;i<=argc;i++) {
        t=argv[i]
        if(t=="tunnel" && phase==0) { phase=1; continue }
        if(t=="run" && phase==1) { phase=2; runs++; continue }
        if(t ~ /^--/) {
            if(position)fail()
            p=index(t,"="); k=p?substr(t,1,p-1):t; v=p?substr(t,p+1):""
            if(seen[k]++)fail()
            if(k=="--no-autoupdate") { if(p || phase==2)fail(); continue }
            if(k=="--token" || k=="--token-file") { if(phase!=2)fail() }
            else if(k=="--protocol" || k=="--credentials-file") {}
            else if(k=="--logfile" || k=="--config" || k=="--log-directory" || k=="--loglevel" ||
                    k=="--transport-loglevel" || k=="--metrics" || k=="--edge-ip-version" ||
                    k=="--retries" || k=="--origincert") { if(phase==2)fail() }
            else fail()
            if(!p) { if(i==argc)fail(); v=argv[++i]; if(v ~ /^-/)fail() }
            if(v=="")fail()
            if(k=="--logfile") { if(v!="/opt/var/log/cloudflared.log")fail(); logs++ }
            continue
        }
        if(phase!=2 || ++position>1 || length(t)!=36 || t !~ /^[0-9a-fA-F-]+$/ ||
           substr(t,9,1)!="-" || substr(t,14,1)!="-" || substr(t,19,1)!="-" || substr(t,24,1)!="-")fail()
        v=t; gsub(/-/,"",v); if(length(v)!=32 || v~/[^0-9a-fA-F]/)fail()
    }
    if(phase!=2 || runs!=1 || logs!=1)fail()
    print "ARGV supported END"
}
BEGIN { if(cfmgr_writer_mode!="argv")fail() }
{
    if($0 !~ /^[0-9a-f][0-9a-f]$/ || ++bytes>32768)fail()
    n=hexbyte($0)
    if(n==0) { if(length(token)>4096)fail(); argv[++argc]=token; token=""; finalnul=1 }
    else { if(n<32 || n>126)fail(); token=token sprintf("%c",n); finalnul=0 }
}
END { if(bad || !finalnul)exit 1; argcheck() }

'
	# CFMGR-AWK-END backup_cloud_writer
}

cfmgr_backup_awk_backup_payload() {
	# CFMGR-AWK-BEGIN backup_payload
	cfmgr_awk_program='
# SPDX-License-Identifier: GPL-3.0-or-later
# Trusted consumer of config JSON getters immutable bounded tree. Plan mode additionally
# requires the complete config_observation archive-data validation. Other fixed
# modes validate runtime JSON, decoded certificate JSON or inert draft envelopes.
# All receipts are private internal data. They must never be displayed as UI.

function bp_id(parent,key) { return bp_child[parent,"k" bp_hex(key)] }
function bp_type(id,allowed,    kind) {
    if(!id) reject()
    kind=cfmgr_json_tree_kind[id]
    if(kind=="true" || kind=="false") kind="boolean"
    if(!index("|" allowed "|","|" kind "|")) reject()
    return id
}
function bp_field(parent,key,kind) { return bp_type(bp_id(parent,key),kind) }
function bp_hex(value,    i,result,code) {
    result=""
    for(i=1;i<=length(value);i++) {
        code=byte_value["b" substr(value,i,1)]
        if(!code) reject()
        result=result byte_hex[code]
    }
    return result
}
function bp_decode(value,    i,n,result) {
    if(length(value)%2 || value~/[^0-9a-f]/) reject()
    result=""
    for(i=1;i<=length(value);i+=2) {
        n=hex_value["h" substr(value,i,1)]*16+hex_value["h" substr(value,i+1,1)]
        if(n<32 || n>126) reject()
        result=result sprintf("%c",n)
    }
    return result
}
function bp_string_hex(parent,key,nullable,    id,value) {
    id=bp_field(parent,key,(nullable ? "string|null" : "string"))
    if(cfmgr_json_tree_kind[id]=="null") return "-"
    value=substr(cfmgr_json_tree_payload[id],2)
    if(value=="") reject()
    return value
}
function bp_text(parent,key,nullable,    value) {
    value=bp_string_hex(parent,key,nullable)
    return value=="-" ? "" : bp_decode(value)
}
function bp_number(parent,key) { return substr(cfmgr_json_tree_payload[bp_field(parent,key,"number")],2) }
function bp_bool(parent,key) { return cfmgr_json_tree_kind[bp_field(parent,key,"boolean")]=="true" }
function bp_le(a,b) { return length(a)<length(b) || (length(a)==length(b) && "n" a<="n" b) }
function bp_gen(value) { if(value!~/^[1-9][0-9]*$/ || length(value)>20) reject(); return value }
function bp_uuid(value,    a,n,i) {
    n=split(value,a,"-")
    if(n!=5 || length(a[1])!=8 || length(a[2])!=4 || length(a[3])!=4 || length(a[4])!=4 || length(a[5])!=12) reject()
    for(i=1;i<=n;i++) if(a[i]!~/^[0-9a-fA-F]+$/) reject()
    value=tolower(value)
    if(value=="00000000-0000-0000-0000-000000000000") reject()
    return value
}
function bp_hash(value) { if(length(value)!=64 || value~/[^0-9a-f]/) reject(); return value }
function bp_path(value,    a,n,i) {
    if(length(value)<2 || length(value)>1024 || value!~/^\// || value~/[^ -~]/ || index(value,"\\") || value~/\/$/) reject()
    n=split(value,a,"/")
    for(i=2;i<=n;i++) if(a[i]=="" || a[i]=="." || a[i]=="..") reject()
    return value
}
function bp_managed(value,    a,n,i) {
    bp_path(value)
    if(substr(value,1,21)!="/opt/etc/cloudflared/") reject()
    n=split(substr(value,22),a,"/")
    for(i=1;i<=n;i++) if(a[i]~/^\./ || a[i]~/^(import|staging|CFBackup)$/) reject()
    if(a[n]~/^(cloudflared|cfmgr|cfmgr.sh|catalog.txt|manifest.txt|setup-state|setup-in-progress|config.lock)$/ || a[n]~/\.(sh|so|bin|exe|py|lock|pid|old)$/) reject()
    return value
}
function bp_emit(line) {
    bp_output_bytes+=length(line)+1
    if(bp_output_bytes>expected_size*8+8192) reject()
    bp_rows[++bp_count]=line
}
function bp_owner_role(value) {
    return value~/^(data\.(setup-drafts|cloudflared\.(yaml|json|certificate|certificate-recovery|yaml-backup))|history\.(ddns|ip_sync|cloudflared)|history-rule\.(ddns|ip_sync|cloudflared))$/ || value~/^data\.cloudflared\.input\.[A-Za-z][A-Za-z0-9._-]*$/
}
function bp_role_path(role,path,    feature) {
    if(role=="data.setup-drafts") { if(path!="/jffs/addons/CFMgr.d/setup-drafts") reject() }
    else if(role=="data.cloudflared.certificate-recovery") { if(path!="/jffs/addons/CFMgr.d/cert.pem") reject() }
    else if(role=="data.cloudflared.yaml") { if(path!="/opt/etc/cloudflared/config.yml") reject() }
    else if(role=="data.cloudflared.yaml-backup") { if(path!="/opt/etc/cloudflared/config.yml.bak") reject() }
    else if(role~/^data\.cloudflared\./) bp_managed(path)
    else {
        feature=role; sub(/^history(-rule)?\./,"",feature)
        if(feature=="ip_sync") feature="ip-sync"
        if(role~/^history-rule\./) { if(path!="/opt/etc/logrotate.d/cfmgr-" feature) reject() }
        else if(path!="/opt/var/log/" feature ".log") reject()
    }
}
function bp_plan(    schema,generation,storage,features,i,name,feature,cloud,refs,paths,identity,registry,record,key,kind,owners,item,role,path,gen,sha,logging,policy,method,configured,runtime,cert,live,recovery,yaml,json) {
    if(!co_observation_ready || cfmgr_config_mode!="archive-data") reject()
    schema=bp_number(1,"schema"); generation=bp_gen(bp_number(1,"generation"))
    bp_emit("CFMGR-PAYLOAD-PLAN 1 " schema " " generation)
    bp_emit("FILE manager.config required " bp_hex("/jffs/addons/CFMgr.d/config") " " generation " -")
    bp_emit("FILE manager.catalog required " bp_hex("/jffs/addons/CFMgr.d/catalog.txt") " " generation " -")
    storage=bp_field(bp_field(1,"storage","object"),"entware","object")
    bp_emit("STORAGE " bp_text(storage,"uuid",0) " " bp_text(storage,"filesystem",0) " " bp_string_hex(storage,"root",0) " " bp_string_hex(storage,"relative",0))
    split("ddns ip_sync cloudflared",features," ")
    for(i=1;i<=3;i++) {
        name=features[i]; feature=bp_field(1,name,"object")
        # Schema1 has no selected typed authority. Never pretend a configured
        # opaque legacy feature is a complete portable data backup.
        if(schema=="1" && bp_bool(feature,"configured")) reject()
        bp_emit("STATE " name " " bp_bool(feature,"configured") " " bp_bool(feature,"enabled"))
    }
    co_archive_saved()
    bp_emit("BACKUP " co_archive_format " " co_archive_keep " " (co_archive_saved_set=="" ? "-" : co_archive_saved_set))
    if(schema=="1") { bp_emit("LEGACY unconfigured END"); return }
    registry=bp_field(1,"credentials","object")
    for(i=2;i<=cfmgr_json_tree_count;i++) {
        if(cfmgr_json_tree_parent[i]!=registry) continue
        key=substr(cfmgr_json_tree_location[i],2); kind=bp_text(i,"kind",0)
        if(kind=="cloudflared_json") bp_emit("AUTH " key " json " bp_string_hex(i,"account_tag",0) " " bp_uuid(bp_text(i,"tunnel_id",0)) " " bp_string_hex(i,"tunnel_secret",0))
        # Opaque runtime/API tokens remain in the private config payload; no
        # second token receipt is necessary for archive semantic validation.
    }
    owners=bp_field(bp_field(1,"ownership","object"),"components","array")
    for(i=0;(item=bp_child[owners,"i" i]);i++) {
        role=bp_text(item,"component",0)
        if(role=="cloudflared") {
            path=bp_text(item,"path",0); gen=bp_gen(bp_number(item,"generation")); sha=bp_text(item,"sha256",1)
            # Observation authority for a matched live writer only. A missing
            # binary association cannot block inactive/core data backup.
            if(path=="/opt/bin/cloudflared" && sha!="" && bp_le(gen,generation))
                bp_emit("WRITER cloudflared " bp_hex(path) " " gen " " bp_hash(sha))
            continue
        }
        if(!bp_owner_role(role)) continue
        path=bp_text(item,"path",0); bp_role_path(role,path)
        gen=bp_gen(bp_number(item,"generation")); if(!bp_le(gen,generation)) reject()
        sha=bp_text(item,"sha256",1)
        if(role!~/^(data\.cloudflared\.(yaml|json)|history\.(ddns|ip_sync|cloudflared))$/ && sha=="") reject()
        if(sha!="") bp_hash(sha)
        bp_owner_path[role]=path; bp_owner_gen[role]=gen; bp_owner_sha[role]=(sha=="" ? "-" : sha)
        bp_emit("OWNER " role " " bp_hex(path) " " gen " " bp_owner_sha[role])
    }
    cloud=bp_field(1,"cloudflared","object"); refs=bp_field(cloud,"credential_refs","object")
    paths=bp_field(cloud,"paths","object"); identity=bp_field(cloud,"expected_identity","object")
    method=bp_text(cloud,"method",1); configured=bp_bool(cloud,"configured")
    runtime=bp_string_hex(refs,"runtime",1); cert=bp_string_hex(refs,"certificate",1)
    bp_emit("CLOUD " (method=="" ? "-" : method) " " configured " " bp_bool(cloud,"enabled") " " bp_bool(cloud,"installed") " " bp_bool(cloud,"maintenance_enabled") " " runtime " " cert " " bp_string_hex(identity,"account_id",1) " " bp_string_hex(identity,"tunnel_id",1))
    yaml=bp_text(paths,"yaml",1); json=bp_text(paths,"json",1)
    if((configured && method=="advanced") || ("data.cloudflared.yaml" in bp_owner_path) || ("data.cloudflared.json" in bp_owner_path)) {
        if(yaml!="/opt/etc/cloudflared/config.yml" || json=="") reject()
        bp_managed(json)
        if(("data.cloudflared.yaml" in bp_owner_path) && bp_owner_path["data.cloudflared.yaml"]!=yaml) reject()
        if(("data.cloudflared.json" in bp_owner_path) && bp_owner_path["data.cloudflared.json"]!=json) reject()
        if(!(configured && method=="advanced") && (!("data.cloudflared.yaml" in bp_owner_path) || !("data.cloudflared.json" in bp_owner_path))) reject()
        bp_emit("FILE data.cloudflared.yaml required " bp_hex(yaml) " " (("data.cloudflared.yaml" in bp_owner_gen) ? bp_owner_gen["data.cloudflared.yaml"] : generation) " -")
        bp_emit("FILE data.cloudflared.json required " bp_hex(json) " " (("data.cloudflared.json" in bp_owner_gen) ? bp_owner_gen["data.cloudflared.json"] : generation) " -")
    }
    if(cert!="-") {
        record=bp_child[registry,"k" cert]; bp_type(record,"object")
        live=bp_text(record,"path",0); recovery=bp_text(record,"recovery_path",0)
        bp_managed(live); if(recovery!="/jffs/addons/CFMgr.d/cert.pem") reject()
        gen=bp_gen(bp_number(record,"generation")); if(!bp_le(gen,generation)) reject()
        sha=bp_hash(bp_text(record,"sha256",0))
        for(i=1;i<=2;i++) {
            role=(i==1 ? "data.cloudflared.certificate" : "data.cloudflared.certificate-recovery"); path=(i==1 ? live : recovery)
            if((role in bp_owner_path) && (bp_owner_path[role]!=path || bp_owner_gen[role]!=gen || bp_owner_sha[role]!=sha)) reject()
            bp_emit("FILE " role " optional " bp_hex(path) " " gen " " sha)
        }
        bp_emit("CERT " cert " " bp_string_hex(record,"account_id",0) " " gen " " sha)
    }
    logging=bp_field(1,"logging","object")
    for(i=1;i<=3;i++) {
        name=features[i]; feature=bp_field(logging,name,"object"); policy=bp_field(feature,"policy","object|null")
        bp_emit("LOG " name " " bp_bool(feature,"configured") " " bp_bool(feature,"enabled") " " bp_bool(feature,"opt_out") " " (cfmgr_json_tree_kind[policy]=="null" ? "-" : bp_hex(substr(document,cfmgr_json_tree_start[policy],cfmgr_json_tree_end[policy]-cfmgr_json_tree_start[policy]+1))))
    }
}
function bp_unique_keys(keys,    allowed,n,a,i,key,lower,seen) {
    n=split(keys,a," "); for(i=1;i<=n;i++) allowed[tolower(a[i])]=a[i]
    for(i=2;i<=cfmgr_json_tree_count;i++) {
        if(cfmgr_json_tree_parent[i]!=1) continue
        key=bp_decode(substr(cfmgr_json_tree_location[i],2)); lower=tolower(key)
        if((lower in allowed) && key!=allowed[lower]) reject()
    }
}
function bp_runtime_json(    account,tunnel,secret,path,line,extra,a,count,saved_rs) {
    bp_type(1,"object"); bp_unique_keys("AccountTag TunnelID TunnelSecret")
    account=bp_string_hex(1,"AccountTag",0); tunnel=bp_uuid(bp_text(1,"TunnelID",0)); secret=bp_string_hex(1,"TunnelSecret",0)
    path=ENVIRON["CFMGR_PAYLOAD_AUTHORITY"]
    if(path=="") reject()
    saved_rs=RS; RS="\n"
    if((getline line <path)!=1 || length(line)>131072 || (getline extra <path)!=0) reject()
    close(path); RS=saved_rs
    count=split(line,a," ")
    if(count!=7 || line!="CFMGR-AUTH 1 " a[3] " " a[4] " " a[5] " " a[6] " END" || a[1]!="CFMGR-AUTH" || a[2]!="1" || a[7]!="END") reject()
    if(a[3]!~/^[0-9a-f]+$/ || length(a[3])%2 || a[6]!~/^[0-9a-f]+$/ || length(a[6])%2) reject()
    if("s" account!="s" a[4] || "s" tunnel!="s" a[5] || "s" secret!="s" a[6]) reject()
    bp_emit("CFMGR-PAYLOAD 1 runtime-json matched END")
}
function bp_certificate_json(    account) {
    bp_type(1,"object"); bp_unique_keys("zoneID accountID apiToken endpoint")
    bp_string_hex(1,"zoneID",0); bp_string_hex(1,"apiToken",0)
    account=bp_string_hex(1,"accountID",0)
    if("s" account!="s" ENVIRON["CFMGR_PAYLOAD_ACCOUNT_HEX"]) reject()
    if(bp_id(1,"endpoint")) bp_type(bp_id(1,"endpoint"),"string")
    bp_emit("CFMGR-PAYLOAD 1 certificate-json matched END")
}
function bp_drafts(    drafts,generation,i,name,item,stage) {
    bp_type(1,"object"); if(bp_number(1,"schema")!="1") reject()
    generation=bp_gen(bp_number(1,"generation"))
    if("g" generation!="g" ENVIRON["CFMGR_PAYLOAD_GENERATION"]) reject()
    drafts=bp_field(1,"drafts","object")
    for(i=2;i<=cfmgr_json_tree_count;i++) {
        if(cfmgr_json_tree_parent[i]!=drafts) continue
        name=bp_decode(substr(cfmgr_json_tree_location[i],2))
        if(name!~/^(ddns|ip_sync)$/) reject()
        if(cfmgr_json_tree_kind[i]=="null") continue
        item=bp_type(i,"object"); if(bp_number(item,"schema")!="1") reject()
        stage=bp_text(item,"stage",0); if(length(stage)>64 || stage!~/^[A-Za-z][A-Za-z0-9._-]*$/) reject()
        bp_field(item,"inputs","object"); bp_field(item,"validation","object")
    }
    bp_emit("CFMGR-PAYLOAD 1 drafts inert END")
}
BEGIN {
    if(!cfmgr_json_tree_ready || cfmgr_json_mode!="tree") reject()
    for(bp_i=2;bp_i<=cfmgr_json_tree_count;bp_i++) bp_child[cfmgr_json_tree_parent[bp_i],cfmgr_json_tree_location[bp_i]]=bp_i
    bp_mode=ENVIRON["CFMGR_PAYLOAD_MODE"]
    if(bp_mode=="plan") bp_plan()
    else if(bp_mode=="runtime-json") bp_runtime_json()
    else if(bp_mode=="certificate-json") bp_certificate_json()
    else if(bp_mode=="drafts") bp_drafts()
    else reject()
    if(bp_mode=="plan") bp_emit("END " bp_count)
    for(bp_i=1;bp_i<=bp_count;bp_i++) print bp_rows[bp_i]
    exit 0
}
'
	# CFMGR-AWK-END backup_payload
}

cfmgr_backup_awk_backup_pem() {
	# CFMGR-AWK-BEGIN backup_pem
	cfmgr_awk_program='
# Bounded Cloudflared origin-certificate PEM framing. Input is one lower-hex
# byte per physical line, from a caller-owned <=65536-byte immutable snapshot.
# The only output is a complete private base64 receipt. Native OpenSSL decodes
# it and backup payload getter independently checks the resulting token JSON.
function pc_fail() { pc_bad=1; exit 1 }
function pc_line(s,    label) {
    sub(/\r$/,"",s)
    if(s~/^-----BEGIN /) {
        if(pc_block!="" || s!~/^-----BEGIN (ARGO TUNNEL TOKEN|PRIVATE KEY|CERTIFICATE)-----$/)pc_fail()
        label=s;sub(/^-----BEGIN /,"",label);sub(/-----$/,"",label)
        pc_block=label;pc_body="";return
    }
    if(s~/^-----END /) {
        if(pc_block=="" || s!="-----END " pc_block "-----" || pc_body=="" || length(pc_body)%4)pc_fail()
        if(pc_body!~/^[A-Za-z0-9+\/]+=?=?$/ || pc_body~/=[^=]/)pc_fail()
        if(pc_block=="ARGO TUNNEL TOKEN") {if(pc_tokens++)pc_fail();pc_token=pc_body}
        pc_block="";return
    }
    if(pc_block=="") {if(s!~/^[ \t]*$/)pc_fail();return}
    if(s=="" || s~/[^A-Za-z0-9+\/=]/ || length(s)>128)pc_fail()
    pc_body=pc_body s
}
BEGIN { pc_digits="0123456789abcdef" }
{
    if(++pc_bytes>65536 || length($0)!=2 || $0~/[^0-9a-f]/)pc_fail()
    pc_byte=(index(pc_digits,substr($0,1,1))-1)*16+index(pc_digits,substr($0,2,1))-1
    if(pc_byte==10) {pc_line(pc_buffer);pc_buffer="";next}
    if(pc_byte!=9 && pc_byte!=13 && (pc_byte<32 || pc_byte>126))pc_fail()
    if(length(pc_buffer)>=160)pc_fail()
    pc_buffer=pc_buffer sprintf("%c",pc_byte)
}
END {
    if(pc_bad)exit 1
    if(length(pc_buffer))pc_line(pc_buffer)
    if(pc_bad || pc_block!="" || pc_tokens!=1)exit 1
    print "CFMGR-PEM 1 " pc_token " END"
}
'
	# CFMGR-AWK-END backup_pem
}

cfmgr_backup_awk_backup_archive_control() {
	# CFMGR-AWK-BEGIN backup_archive_control
	cfmgr_awk_program='
# Inert archive directory/retention control. Inputs are private bounded receipts;
# no input selects code or a path outside the admitted CFBackup directory.
function ac_fail() { ac_bad=1; exit 1 }
function ac_uint(s) { return s ~ /^(0|[1-9][0-9]*)$/ && length(s)<=19 }
function ac_hex(s,n) { return length(s)==n && s !~ /[^0-9a-f]/ }
function ac_uuid(s, a) {
    return length(s)==36 && split(s,a,"-")==5 && ac_hex(a[1],8) && ac_hex(a[2],4) && ac_hex(a[3],4) && ac_hex(a[4],4) && ac_hex(a[5],12)
}
function ac_name(s) {
    return length(s)<=64 && s ~ /^CFbackup-[0-9][0-9_-]*\.tar\.gz$/ && s !~ /__|--/
}
function ac_newer(epoch,id,name,other, a) {
    split(other,a," ")
    if(length(epoch)!=length(a[6]))return length(epoch)>length(a[6])
    if("x" epoch!="x" a[6])return "x" epoch>"x" a[6]
    if("x" id!="x" a[8])return "x" id>"x" a[8]
    return "x" name>"x" a[2]
}
function ac_older(left,right, a,b) {
    split(left,a," "); split(right,b," ")
    if(length(a[6])!=length(b[6]))return length(a[6])<length(b[6])
    if(a[6]!=b[6])return ("x" a[6])<("x" b[6])
    if(a[8]!=b[8])return ("x" a[8])<("x" b[8])
    return ("x" a[2])<("x" b[2])
}
function ac_record(line, a) {
    if(length(line)>1024 || split(line,a," ")!=9 || line!="ARCHIVE " a[2] " " a[3] " " a[4] " " a[5] " " a[6] " " a[7] " " a[8] " END")return 0
    return ac_name(a[2]) && ac_uint(a[3]) && a[3]!="0" && ac_uint(a[4]) && ac_hex(a[5],64) && ac_uint(a[6]) && length(a[6])<=10 && a[7] ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ && ac_uuid(a[8])
}
BEGIN {
    ac_mode=ENVIRON["CFMGR_ARCHIVE_CONTROL_MODE"]
    ac_keep=ENVIRON["CFMGR_ARCHIVE_KEEP"]
    ac_new=ENVIRON["CFMGR_ARCHIVE_NEW_NAME"]
    if(ac_mode!="names" && ac_mode!="retention")ac_fail()
    if(ac_mode=="retention" && (ac_keep!~/^[345]$/ || !ac_name(ac_new)))ac_fail()
}
{
    if(ac_mode=="names") { if(ac_name($0))print $0; next }
    if(!ac_record($0,ac_fields))ac_fail()
    if(ac_seen[ac_fields[2]]++)ac_fail()
    if(ac_fields[2]==ac_new) { ac_found++; next }
    # Keep the new publication even after a clock rollback, plus the newest
    # keep-1 prior complete archives. Fixed <=4 slots; no quadratic full sort.
    ac_position=ac_keep
    for(ac_i=1;ac_i<ac_keep;ac_i++) {
        if(!(ac_i in ac_top) || ac_newer(ac_fields[6],ac_fields[8],ac_fields[2],ac_top[ac_i])) { ac_position=ac_i; break }
    }
    if(ac_position<ac_keep) {
        for(ac_i=ac_keep-1;ac_i>ac_position;ac_i--)ac_top[ac_i]=ac_top[ac_i-1]
        ac_top[ac_position]=$0
    }
}
END {
    if(ac_bad)exit 1
    if(ac_mode=="names")exit 0
    if(ac_found!=1)exit 1
    ac_retain[ac_new]=1
    for(ac_i=1;ac_i<ac_keep;ac_i++)if(ac_i in ac_top) { split(ac_top[ac_i],ac_fields," "); ac_retain[ac_fields[2]]=1 }
    close(ARGV[1])
    while((ac_status=(getline ac_line < ARGV[1]))>0) {
        if(!ac_record(ac_line,ac_fields))exit 1
        if(!(ac_fields[2] in ac_retain))ac_remove[++ac_count]=ac_line
    }
    if(ac_status<0)exit 1
    # Bottom-up stable merge sort: removals are emitted oldest first without
    # quadratic work, shelling out, or changing the fixed-size keep selection.
    for(ac_width=1;ac_width<ac_count;ac_width*=2) {
        for(ac_start=1;ac_start<=ac_count;ac_start+=2*ac_width) {
            ac_mid=ac_start+ac_width; if(ac_mid>ac_count+1)ac_mid=ac_count+1
            ac_end=ac_start+2*ac_width; if(ac_end>ac_count+1)ac_end=ac_count+1
            ac_left=ac_start; ac_right=ac_mid; ac_out=ac_start
            while(ac_left<ac_mid && ac_right<ac_end) {
                if(!ac_older(ac_remove[ac_right],ac_remove[ac_left]))ac_sorted[ac_out++]=ac_remove[ac_left++]
                else ac_sorted[ac_out++]=ac_remove[ac_right++]
            }
            while(ac_left<ac_mid)ac_sorted[ac_out++]=ac_remove[ac_left++]
            while(ac_right<ac_end)ac_sorted[ac_out++]=ac_remove[ac_right++]
        }
        for(ac_i=1;ac_i<=ac_count;ac_i++) { ac_remove[ac_i]=ac_sorted[ac_i]; delete ac_sorted[ac_i] }
    }
    for(ac_i=1;ac_i<=ac_count;ac_i++)print ac_remove[ac_i]
}
'
	# CFMGR-AWK-END backup_archive_control
}

cfmgr_backup_awk_backup_tar() {
	# CFMGR-AWK-BEGIN backup_tar
	cfmgr_awk_program='
# API: read one 1024-character lowercase-hex header from stdin. The caller sets
# CFMGR_TAR_OFFSET and CFMGR_TAR_BYTES to canonical decimal values. A valid
# header emits one CFMGR-TAR-HEADER v1 receipt; invalid input emits no stdout.

function bad() {
	exit 1
}

function byte_at(pos,    pair, hi, lo) {
	pair = substr(record, pos * 2 + 1, 2)
	hi = index("0123456789abcdef", substr(pair, 1, 1)) - 1
	lo = index("0123456789abcdef", substr(pair, 2, 1)) - 1
	if (hi < 0 || lo < 0) bad()
	return hi * 16 + lo
}

function zero_range(start, count,    i) {
	for (i = start; i < start + count; i++)
		if (bytes[i] != 0) return 0
	return 1
}

function octal_field(start, width,    i, value, digit, ended, digits) {
	value = "0"
	ended = 0
	digits = 0
	for (i = start; i < start + width; i++) {
		digit = bytes[i]
		if (digit >= 48 && digit <= 55) {
			if (ended) bad()
			value = dec_add(dec_mul_small(value, 8), sprintf("%d", digit - 48))
			digits++
		} else if (digit == 0) {
			if (i != start + width - 1) bad()
			ended = 1
		} else {
			bad()
		}
	}
	if (digits == 0) bad()
	return value
}

function dec_normalize(value) {
	sub(/^0+/, "", value)
	return value == "" ? "0" : value
}

function dec_compare(left, right,    i, a, b) {
	left = dec_normalize(left)
	right = dec_normalize(right)
	if (length(left) < length(right)) return -1
	if (length(left) > length(right)) return 1
	for (i = 1; i <= length(left); i++) {
		a = substr(left, i, 1) + 0
		b = substr(right, i, 1) + 0
		if (a < b) return -1
		if (a > b) return 1
	}
	return 0
}

function dec_add(left, right,    i, a, b, carry, digit, result) {
	left = dec_normalize(left)
	right = dec_normalize(right)
	carry = 0
	result = ""
	for (i = 0; i < length(left) || i < length(right) || carry; i++) {
		a = i < length(left) ? substr(left, length(left) - i, 1) + 0 : 0
		b = i < length(right) ? substr(right, length(right) - i, 1) + 0 : 0
		digit = a + b + carry
		carry = int(digit / 10)
		result = sprintf("%d", digit % 10) result
	}
	return dec_normalize(result)
}

function dec_mul_small(value, multiplier,    i, digit, carry, product, result) {
	value = dec_normalize(value)
	carry = 0
	result = ""
	for (i = length(value); i > 0; i--) {
		digit = substr(value, i, 1) + 0
		product = digit * multiplier + carry
		carry = int(product / 10)
		result = sprintf("%d", product % 10) result
	}
	while (carry > 0) {
		result = sprintf("%d", carry % 10) result
		carry = int(carry / 10)
	}
	return dec_normalize(result)
}

function divmod_512(value,    i, digit, current, quotient, remainder) {
	quotient = ""
	remainder = 0
	for (i = 1; i <= length(value); i++) {
		digit = substr(value, i, 1) + 0
		current = remainder * 10 + digit
		quotient = quotient sprintf("%d", int(current / 512))
		remainder = current % 512
	}
	division_q = dec_normalize(quotient)
	division_r = remainder
}

function decimal_operand(value,    i, digit) {
	if (value == "" || (length(value) > 1 && substr(value, 1, 1) == "0")) return 0
	for (i = 1; i <= length(value); i++) {
		digit = substr(value, i, 1)
		if (digit < "0" || digit > "9") return 0
	}
	return dec_compare(value, "9223372036854775807") <= 0
}

function read_size(    i, value) {
	if (bytes[125] == 128) {
		if (bytes[126] != 0 || bytes[127] != 0 || bytes[128] != 0) bad()
		value = "0"
		for (i = 129; i <= 136; i++) {
			value = dec_mul_small(value, 256)
			value = dec_add(value, sprintf("%d", bytes[i]))
		}
		if (dec_compare(value, "68719476735") <= 0) bad()
		return value
	}
	if (bytes[125] >= 64) bad()
	return octal_field(125, 12)
}

function printable_field(start, width,    i, ended, b, characters) {
	ended = 0
	characters = 0
	for (i = start; i < start + width; i++) {
		b = bytes[i]
		if (b == 0) ended = 1
		else if (ended || b < 32 || b > 126) return 0
		else characters++
	}
	return characters == 0 || characters <= 31
}

function name_field(    i, nul, name, b) {
	nul = 0
	name = ""
	for (i = 1; i <= 100; i++) {
		b = bytes[i]
		if (b == 0) {
			nul = i
			break
		}
		name = name sprintf("%c", b)
	}
	if (!nul || nul == 1 || nul > 100 || !zero_range(nul + 1, 100 - nul)) bad()
	if (name == "manifest" || name == "inventory") return name
	if (length(name) == 9 && substr(name, 1, 1) == "p" && substr(name, 2) ~ /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/) return name
	bad()
}

function valid_checksum(    i, expected, actual) {
	if (bytes[149] < 48 || bytes[149] > 55 || bytes[150] < 48 || bytes[150] > 55 || bytes[151] < 48 || bytes[151] > 55 || bytes[152] < 48 || bytes[152] > 55 || bytes[153] < 48 || bytes[153] > 55 || bytes[154] < 48 || bytes[154] > 55) bad()
	if (bytes[155] != 0 || bytes[156] != 32) bad()
	expected = 0
	for (i = 149; i <= 154; i++) expected = expected * 8 + bytes[i] - 48
	actual = 0
	for (i = 1; i <= 512; i++)
		actual += (i >= 149 && i <= 156) ? 32 : bytes[i]
	if (actual != expected) bad()
}

function run(    line, extra, i, offset, total, name, size, body_offset, next_offset, padded) {
	if ((getline line) <= 0) bad()
	if (length(line) == 1025 && substr(line, 1025, 1) == "\r") bad()
	if (length(line) != 1024) bad()
	if (getline extra > 0) bad()
	record = line
	if (!decimal_operand(ENVIRON["CFMGR_TAR_OFFSET"]) || !decimal_operand(ENVIRON["CFMGR_TAR_BYTES"])) bad()
	offset = ENVIRON["CFMGR_TAR_OFFSET"]
	total = ENVIRON["CFMGR_TAR_BYTES"]
	divmod_512(offset)
	if (division_r != 0 || dec_compare(dec_add(offset, "512"), total) > 0) bad()
	for (i = 1; i <= 512; i++) bytes[i] = byte_at(i - 1)
	if (zero_range(1, 512)) {
		body_offset = dec_add(offset, "512")
		printf "CFMGR-TAR-HEADER 1 zero - 0 %s %s END\n", body_offset, body_offset
		return
	}
	valid_checksum()
	if (bytes[157] != 48 || !zero_range(158, 100) || !zero_range(330, 16) || !zero_range(346, 155) || !zero_range(501, 12)) bad()
	if (bytes[258] != 117 || bytes[259] != 115 || bytes[260] != 116 || bytes[261] != 97 || bytes[262] != 114 || bytes[263] != 32 || bytes[264] != 32 || bytes[265] != 0) bad()
	if (!printable_field(266, 32) || !printable_field(298, 32)) bad()
	if (dec_compare(octal_field(101, 8), "4095") > 0) bad()
	octal_field(109, 8)
	octal_field(117, 8)
	octal_field(137, 12)
	name = name_field()
	size = read_size()
	body_offset = dec_add(offset, "512")
	divmod_512(size)
	padded = division_q
	if (division_r != 0) padded = dec_add(padded, "1")
	padded = dec_mul_small(padded, 512)
	next_offset = dec_add(body_offset, padded)
	if (dec_compare(next_offset, total) > 0) bad()
	printf "CFMGR-TAR-HEADER 1 file %s %s %s %s END\n", name, size, body_offset, next_offset
}

BEGIN {
	LC_ALL = "C"
	run()
	exit 0
}
'
	# CFMGR-AWK-END backup_tar
}

cfmgr_backup_awk_backup_payload_match() {
	# CFMGR-AWK-BEGIN backup_payload_match
	cfmgr_awk_program='
# Required semantic inventory join after raw-format/hash and per-file validation.
# Inputs are caller-owned bounded complete receipts, not arbitrary source data.
# ARGV: capture-plan, inventory. No code/data extraction or live authority.
function bm_fail() { bm_bad=1;exit 1 }
function bm_unhex(s,    out,i,n) {
    out="";if(s=="" || length(s)%2 || s~/[^0-9a-f]/)bm_fail()
    for(i=1;i<=length(s);i+=2) {
        n=(index("0123456789abcdef",substr(s,i,1))-1)*16+index("0123456789abcdef",substr(s,i+1,1))-1
        if(n<32 || n>126)bm_fail();out=out sprintf("%c",n)
    }
    return out
}
function bm_read_plan(path,    row,a,n,lines,ended,key,base) {
    while((getline row <path)>0) {
        if(ended || length(row)>131072)bm_fail()
        n=split(row,a," ");lines++
        if(lines==1) {if(n!=4 || a[1]!="CFMGR-CAPTURE-PLAN" || a[2]!="1")bm_fail()}
        else if(a[1]=="FILE") {
            if(n!=8 || a[8]!="whole")bm_fail()
            key=a[2] SUBSEP a[4] SUBSEP a[5]
            if(bm_need[key]!="")bm_fail()
            bm_need[key]=a[3];bm_generation[key]=a[6];bm_digest[key]=a[7];bm_role[key]=a[2]
            if(a[3]=="optional")bm_optional_path[a[2]]=a[5]
        } else if(a[1]=="HISTORY") {
            if(n!=4 || bm_history[a[2]]!="")bm_fail()
            base=bm_unhex(a[3]);if(substr(base,1,5)!="/opt/")bm_fail()
            bm_history[a[2]]=substr(base,6);bm_history_gen[a[2]]=a[4]
        } else if(a[1]=="NOTE") {
            if(n!=6)bm_fail();bm_notes[row]=1
        } else if(a[1]=="EXTERNAL") {
            if(n!=4)bm_fail();bm_external[a[2] SUBSEP a[3]]=1
        } else if(a[1]=="END") {
            if(n!=2 || a[2]!=lines-1)bm_fail();ended=1
        } else if(a[1]!~/^(BACKUP|AUTH|CERT)$/)bm_fail()
    }
    close(path);if(!ended)bm_fail()
}
function bm_inventory(path,    row,a,n,lines,ended,key,plain,rotation,role) {
    while((getline row <path)>0) {
        if(ended || length(row)>4096)bm_fail()
        n=split(row,a," ");lines++
        if(lines==1){if(row!="CFMGR-INVENTORY 1")bm_fail()}
        else if(a[1]=="FILE") {
            if(n!=10)bm_fail()
            role=a[3];key=role SUBSEP a[4] SUBSEP a[5]
            if(role~/^history\./) {
                if(a[4]!="entware" || !(role in bm_history) || "g" a[6]!="g" bm_history_gen[role])bm_fail()
                plain=bm_unhex(a[5])
                if(plain!=bm_history[role]) {
                    if(substr(plain,1,length(bm_history[role])+1)!=bm_history[role] ".")bm_fail()
                    rotation=substr(plain,length(bm_history[role])+2)
                    if(rotation!~/^[1-9][0-9]*$/)bm_fail()
                }
                bm_history_files[role]++
            } else {
                if(!(key in bm_need) || bm_seen[key]++ || "g" a[6]!="g" bm_generation[key])bm_fail()
                if(bm_digest[key]!="-" && "h" a[9]!="h" bm_digest[key])bm_fail()
                if(a[10]!="whole" && !(role~/^data\.cloudflared\.(certificate|certificate-recovery)$/ && a[10]=="recovered"))bm_fail()
                if(role~/^data\.cloudflared\.(certificate|certificate-recovery)$/)bm_cert_files++
            }
        } else if(a[1]=="NOTE") {
            if(n!=6)bm_fail()
            if(row in bm_notes)bm_note_seen[row]=1
            if(a[3]=="external")bm_external_seen[a[2] SUBSEP a[4]]=1
            if(a[2]~/^history\./ && a[4]=="-") {
                if(bm_history_note[a[2]]!="")bm_fail()
                bm_history_note[a[2]]=a[3]
            }
            if(a[2]~/^data\.cloudflared\.(certificate|certificate-recovery)$/ && a[3]~/^(absent|unavailable)$/) {
                if(a[4]!=bm_optional_path[a[2]] || a[5]!~/^(absent|damaged|storage-unavailable)$/)bm_fail()
                bm_optional_note[a[2]]=1
                if(a[5]=="damaged")bm_cert_damaged=1
            }
        } else if(a[1]=="END") {if(n!=4)bm_fail();ended=1}
        else bm_fail()
    }
    close(path);if(!ended)bm_fail()
    for(key in bm_need)if(!bm_seen[key] && (bm_need[key]=="required" || !bm_optional_note[bm_role[key]]))bm_fail()
    for(key in bm_notes)if(!bm_note_seen[key])bm_fail()
    for(key in bm_external)if(!bm_external_seen[key])bm_fail()
    if(bm_cert_damaged && !bm_cert_files)bm_fail()
    split("history.ddns history.ip_sync history.cloudflared",bm_families," ")
    for(key=1;key<=3;key++) {
        role=bm_families[key]
        if(bm_history_files[role]) {if(bm_history_note[role]!="included")bm_fail()}
        else if(role in bm_history) {if(bm_history_note[role]!~/^(absent|unavailable)$/)bm_fail()}
        else if(bm_history_note[role]!~/^(not_applicable|unavailable)$/)bm_fail()
    }
}
BEGIN {
    if(ARGC!=3 || ENVIRON["LC_ALL"]!="C")bm_fail()
    bm_read_plan(ARGV[1]);bm_inventory(ARGV[2])
    print "CFMGR-PAYLOAD-MATCH 1 complete END"
    exit 0
}
'
	# CFMGR-AWK-END backup_payload_match
}

cfmgr_backup_awk_backup_history() {
	# CFMGR-AWK-BEGIN backup_history
	cfmgr_awk_program='
# Read-only archive history supported-profile parser. Fixed modes are selected
# by CFMGR_HISTORY_MODE; data never supplies AWK code or output paths. Policy
# mode follows config JSON getter tree admission; other modes consume bounded snapshots.

function hh_fail(reason) {
	if (!hh_bad) print "CFMGR-HISTORY-ERROR 1 " reason " END"
	hh_bad=1; exit 1
}
function hh_trim(s) { sub(/^[ \t]+/,"",s); sub(/[ \t]+$/,"",s); return s }
function hh_hex(s,    i,out) {
	out=""; for(i=1;i<=length(s);i++) out=out sprintf("%02x",hh_ord[substr(s,i,1)])
	return out
}
function hh_decode(s,    i,n,out) {
	if(length(s)%2 || s~/[^0-9a-f]/) hh_fail("framing")
	out=""
	for(i=1;i<=length(s);i+=2) {
		n=(index("0123456789abcdef",substr(s,i,1))-1)*16+index("0123456789abcdef",substr(s,i+1,1))-1
		if(n==0 || n==127 || n<32 && n!=9 && n!=10 && n!=13) hh_fail("control")
		out=out sprintf("%c",n)
	}
	return out
}
function hh_uint(s,max) { return s~/^(0|[1-9][0-9]*)$/ && (length(s)<length(max) || length(s)==length(max) && "n" s<="n" max) }
function hh_add(a,b,    i,v,carry,out) {
	out=""; carry=0
	for(i=0;i<length(a)||i<length(b)||carry;i++) {
		v=carry+(i<length(a)?substr(a,length(a)-i,1)+0:0)+(i<length(b)?substr(b,length(b)-i,1)+0:0)
		out=(v%10) out; carry=int(v/10)
	}
	if(!hh_uint(out,"9223372036854775807")) hh_fail("policy-overflow")
	return out
}
function hh_mul(s,times,    i) { for(i=1;i<=times;i++) s=hh_add(s,s); return s }
function hh_size(s,    unit,n) {
	unit=substr(s,length(s),1); n=s
	if(unit~/[kKMG]/) n=substr(s,1,length(s)-1)
	if(!hh_uint(n,"9223372036854775807")) hh_fail("unsupported-policy")
	if(unit=="k" || unit=="K") return hh_mul(n,10)
	if(unit=="M") return hh_mul(n,20)
	if(unit=="G") return hh_mul(n,30)
	return n
}
function hh_unquote(s) {
	if(s~/^"[^"\\]*"$/ || s~/^\047[^\047\\]*\047$/) return substr(s,2,length(s)-2)
	return s
}
function hh_lines(s,a) { gsub(/\r\n/,"\n",s); if(s~/\r/) hh_fail("line-ending"); return split(s,a,"\n") }
function hh_clean(s) { sub(/#.*/,"",s); return hh_trim(s) }
function hh_path(s) { return s~/^\/opt\/etc\/logrotate[.]d\/[A-Za-z0-9_-]+$/ || s=="/opt/etc/logrotate.conf" }

function hh_plan(line,    a,n,f,base,role) {
	n=split(line,a," "); hh_plan_rows++
	if(hh_plan_complete) hh_fail("plan")
	if(hh_plan_rows==1) { if(n!=4 || a[1]!="CFMGR-PAYLOAD-PLAN" || a[2]!="1") hh_fail("plan"); return }
	if(a[1]=="END") { if(n!=2 || a[2]!=sprintf("%.0f",hh_plan_rows-1)) hh_fail("plan"); hh_plan_complete=1; return }
	if(a[1]=="STATE") {
		f=a[2]; if(n!=4 || f!~/^(ddns|ip_sync|cloudflared)$/ || hh_state_seen[f]++ || a[3]!~/^[01]$/ || a[4]!~/^[01]$/) hh_fail("plan")
		hh_configured[f]=a[3]
	} else if(a[1]=="LOG") {
		f=a[2]; if(n!=6 || f!~/^(ddns|ip_sync|cloudflared)$/ || hh_log_seen[f]++ || a[3]!~/^[01]$/ || a[4]!~/^[01]$/ || a[5]!~/^[01]$/) hh_fail("plan")
		hh_log[f]=a[3]; hh_optout[f]=a[5]; hh_policy_hex[f]=a[6]
	} else if(a[1]=="OWNER" && a[2]~/^history(-rule)?[.]/) {
		role=a[2]; f=role; sub(/^history(-rule)?[.]/,"",f)
		base=(f=="ip_sync"?"ip-sync":f)
		if(n!=5 || f!~/^(ddns|ip_sync|cloudflared)$/ || hh_owner_seen[role]++ || a[3]!=hh_hex(role~/^history-rule/?"/opt/etc/logrotate.d/cfmgr-" base:"/opt/var/log/" base ".log") || a[4]!~/^[1-9][0-9]*$/) hh_fail("plan")
		hh_owner_gen[role]=a[4]; hh_owner_sha[role]=a[5]
	}
}
function hh_plan_end(    i,f,status,reason,gen,sha) {
	if(!hh_plan_complete) hh_fail("plan")
	for(i=1;i<=3;i++) {
		f=(i==1?"ddns":(i==2?"ip_sync":"cloudflared")); status="request"; reason="eligible"
		gen=hh_owner_gen["history." f]; sha=hh_owner_sha["history-rule." f]
		if(!hh_state_seen[f]) hh_fail("plan")
		if(hh_configured[f]!="1" || hh_log[f]!="1" || hh_optout[f]=="1") { status="not_applicable"; reason="not-requested" }
		else if(gen=="" || sha=="" || length(sha)!=64 || sha~/[^0-9a-f]/ || hh_policy_hex[f]=="-") { status="unavailable"; reason="ownership-or-policy" }
		hh_requests[i]="REQUEST " f " " status " " reason " " (gen==""?"-":gen) " " (sha==""?"-":sha) " " (hh_policy_hex[f]==""?"-":hh_policy_hex[f]) " END"
	}
	for(i=1;i<=3;i++) print hh_requests[i]
}
function hh_child(parent,key,    i,want) {
	want="k" hh_hex(key)
	for(i=2;i<=cfmgr_json_tree_count;i++) if(cfmgr_json_tree_parent[i]==parent && cfmgr_json_tree_location[i]==want) return i
	hh_fail("policy")
}
function hh_json_text(parent,key,    id) {
	id=hh_child(parent,key)
	if(cfmgr_json_tree_kind[id]!="string") hh_fail("policy")
	return hh_decode(substr(cfmgr_json_tree_payload[id],2))
}
function hh_json_number(parent,key,max,nullable,    id,value) {
	id=hh_child(parent,key)
	if(nullable && cfmgr_json_tree_kind[id]=="null") return "0"
	value=substr(cfmgr_json_tree_payload[id],2)
	if(cfmgr_json_tree_kind[id]!="number" || !hh_uint(value,max)) hh_fail("policy")
	return value
}
function hh_policy(    feature,mode,size,unit,value,total,age,id,i) {
	if(!cfmgr_json_tree_ready || cfmgr_json_tree_kind[1]!="object") hh_fail("policy")
	feature=ENVIRON["CFMGR_HISTORY_FEATURE"]
	if(feature=="ddns" || feature=="ip_sync") {
		if(hh_json_number(1,"version","1",0)!="1") hh_fail("policy")
		print "POLICY native - - - END"; return
	}
	if(feature!="cloudflared") hh_fail("policy")
	mode=hh_json_text(1,"mode"); if(mode!~/^(size|daily|weekly|monthly)$/) hh_fail("policy")
	id=hh_child(1,"size"); if(cfmgr_json_tree_kind[id]!="object") hh_fail("policy")
	value=hh_json_number(id,"value","9223372036854775807",0); if(value=="0") hh_fail("policy")
	unit=hh_json_text(id,"unit"); if(unit!~/^(B|KiB|MiB|GiB)$/) hh_fail("policy")
	size=hh_mul(value,(unit=="B"?0:(unit=="KiB"?10:(unit=="MiB"?20:30))))
	total=hh_json_number(1,"total_files","2147483648",0); if(total=="0") hh_fail("policy")
	age=hh_json_number(1,"max_age_days","30",1)
	print "POLICY " mode " " size " " sprintf("%.0f",total-1) " " age " END"
}
function hh_include_scan(text,    a,n,i,line,p,count) {
	n=hh_lines(text,a)
	for(i=1;i<=n;i++) {
		line=hh_trim(a[i])
		if(line~/^reading config file /) {
			p=substr(line,length("reading config file ")+1)
			if(p!~/\//) p="/opt/etc/logrotate.d/" p
			if(!hh_path(p) || hh_includes[p]++) hh_fail("unsupported-include")
			hh_include_order[++hh_include_count]=p
		} else if(line~/^including / && line!="including /opt/etc/logrotate.d") hh_fail("unsupported-include")
	}
	if(!hh_includes["/opt/etc/logrotate.conf"] || !hh_includes["/opt/etc/logrotate.d/A01global"]) hh_fail("include-chain")
}
function hh_process(text,    lines,n,i,a,k,argc,j,arg,cfg,found,cfg_seen,cron_found) {
	n=hh_lines(text,lines)
	for(i=1;i<=n;i++) {
		if(lines[i]=="") continue
		k=split(lines[i],a," ")
		if(a[1]=="CROND") {
			if(k!=5 || !hh_uint(a[2],"2147483647") || a[2]=="0" || !hh_uint(a[3],"18446744073709551615") || a[4]!=hh_hex("/var/spool/cron/crontabs") || a[5]!="END") hh_fail("cron-process")
			cron_found++; continue
		}
		if(k<7 || a[1]!="PROC" || !hh_uint(a[2],"2147483647") || a[2]=="0" || !hh_uint(a[3],"18446744073709551615") || a[4]!=hh_hex("/opt/sbin/syslog-ng") || !hh_uint(a[5],"64")) hh_fail("process")
		argc=a[5]+0; if(argc<1 || k!=argc+6 || a[k]!="END" || hh_decode(a[6])!="/opt/sbin/syslog-ng") hh_fail("process")
		cfg="/opt/etc/syslog-ng.conf"; cfg_seen=0
		for(j=7;j<k;j++) {
			arg=hh_decode(a[j])
			if(arg=="-f" || arg=="--cfgfile") { if(++j>=k || cfg_seen++) hh_fail("process"); cfg=hh_decode(a[j]) }
			else if(arg~/^--cfgfile=/) { if(cfg_seen++) hh_fail("process"); cfg=substr(arg,11) }
			else if(arg!~/^(-[Fevd]+|--foreground|--stderr|--verbose|--debug|--no-caps)$/) hh_fail("unsupported-process-options")
		}
		if(cfg!="/opt/etc/syslog-ng.conf") hh_fail("effective-config")
		found++; hh_pid=a[2]; hh_start=a[3]
	}
	if(found!=1 || cron_found!=1) hh_fail("inactive-or-ambiguous-process")
}
function hh_base(    a,n,i,line,k,v,schedule,count,p,scriptver,scripttag,sysloc,cadence,rootinclude) {
	if(!("script" in hh_data) || !("scribe-config" in hh_data) || !("cron" in hh_data) || !("process" in hh_data) || !("syslog-config" in hh_data) || !("rotate-config" in hh_data) || !("rotate-debug" in hh_data) || !("syslog-version" in hh_data) || !("logrotate-version" in hh_data)) hh_fail("base-evidence")
	n=hh_lines(hh_data["script"],a)
	for(i=1;i<=n;i++) {
		line=hh_trim(a[i])
		if(line=="readonly scribe_ver=\"v3.2.12\"") scriptver++
		if(line=="readonly scriptVer_TAG=\"26041123\"") scripttag++
	}
	if(scriptver!=1 || scripttag!=1) hh_fail("scribe-profile")
	n=hh_lines(hh_data["scribe-config"],a)
	for(i=1;i<=n;i++) {
		line=hh_clean(a[i]); k=index(line,"="); if(!k) continue
		v=hh_unquote(hh_trim(substr(line,k+1))); line=hh_trim(substr(line,1,k-1))
		if(line=="SYSLOG_LOC") { if(sysloc!="") hh_fail("scribe-config"); sysloc=v }
		if(line=="LR_CRONJOB_HOUR") { if(cadence!="") hh_fail("scribe-config"); cadence=v }
	}
	if(sysloc!="/tmp/syslog.log" && sysloc!="/jffs/syslog.log") hh_fail("scribe-config")
	if(cadence!~/^(2|3|4|6|8|12|24)$/) hh_fail("scribe-config")
	schedule="5 " (cadence=="24"?"0":"*/" cadence) " * * * /jffs/scripts/scribe LogRotate"
	n=hh_lines(hh_data["cron"],a)
	hh_cron_shell="/bin/sh"
	for(i=1;i<=n;i++) {
		line=hh_trim(a[i])
		if(line ~ /^SHELL[ 	]*=/) { sub(/^SHELL[ 	]*=[ 	]*/,"",line); hh_cron_shell=hh_trim(line); continue }
		if(index(line,"scribeLogRotate") || index(line,"/jffs/scripts/scribe LogRotate")) {
			if(hh_cron_shell!="/bin/sh")hh_fail("cron-shell")
			if(line!~/#scribeLogRotate#/) hh_fail("rotation-schedule")
			gsub(/#scribeLogRotate#/,"",line); gsub(/[ \t]+/," ",line); line=hh_trim(line)
			if(line!=schedule) hh_fail("rotation-schedule"); count++
		}
	}
	if(count!=1) hh_fail("rotation-schedule")
	if(hh_data["syslog-version"]!~/syslog-ng[ \t]+[0-9]+[.][0-9]+/ || hh_data["logrotate-version"]!~/logrotate[ \t]+[0-9]+[.][0-9]+/) hh_fail("tool-version")
	hh_process(hh_data["process"])
	n=hh_lines(hh_data["syslog-config"],a); count=0
	for(i=1;i<=n;i++) if(hh_clean(a[i])=="@include \"/opt/etc/syslog-ng.d/\"") count++
	if(count!=1) hh_fail("syslog-include")
	n=hh_lines(hh_data["rotate-config"],a)
	for(i=1;i<=n;i++) {
		line=hh_clean(a[i]); if(line~/^include[ \t]+/) { if(line!="include /opt/etc/logrotate.d") hh_fail("unsupported-include"); rootinclude++ }
	}
	if(rootinclude!=1) hh_fail("include-chain")
	hh_include_scan(hh_data["rotate-debug"])
	for(i=1;i<=hh_include_count;i++) {
		p=hh_include_order[i]
		if(p!="/opt/etc/logrotate.conf" && !(p in hh_fragment)) hh_fail("include-evidence")
	}
	print "BASE ready " cadence " " hh_pid " " hh_start " END"
}
function hh_rule(text,base,    lines,n,i,line,a,k,key,value,opened,closed) {
	n=hh_lines(text,lines)
	for(i=1;i<=n;i++) {
		line=hh_clean(lines[i]); if(line=="") continue
		if(!opened) { if(line!=base " {" && line!="\"" base "\" {") hh_fail("rule-scope"); opened=1; continue }
		if(line=="}") { if(closed) hh_fail("rule-scope"); closed=1; continue }
		if(closed) hh_fail("rule-scope")
		k=split(line,a,/[ \t]+/); key=a[1]; value=a[2]
		if(hh_rule_seen[key]++) hh_fail("rule-ambiguity")
		if(key~/^(size|maxsize|minsize)$/) { if(k!=2) hh_fail("rule-directive"); hh_effect[key]=hh_size(value) }
		else if(key~/^(rotate|maxage|minage|start)$/) { if(k!=2 || !hh_uint(value,"2147483647")) hh_fail("rule-directive"); hh_effect[key]=value }
		else if(key~/^(daily|weekly|monthly)$/) { if(k!=1 || hh_effect["mode"]!="") hh_fail("rule-ambiguity"); hh_effect["mode"]=key }
		else if(key~/^(nocompress|nodelaycompress|nodateext|missingok|notifempty|copytruncate|nocreate|nosharedscripts)$/) { if(k!=1) hh_fail("rule-directive"); hh_effect[key]="1" }
		else hh_fail("unsupported-rule")
	}
	if(!opened || !closed) hh_fail("rule-scope")
	for(key in hh_required) if(hh_effect[key]!=hh_required[key]) hh_fail("unsafe-effective-policy")
	# No historical files exist when rotate is zero. A saved age preference is
	# preserved independently; the rule need not express inapplicable maxage.
	if(hh_effect["rotate"]=="0") hh_effect["maxage"]="0"
	if(hh_effect["rotate"]=="" || hh_effect["start"]!="1" || hh_effect["minsize"]!="0" || hh_effect["minage"]!="0" || hh_effect["maxage"]=="") hh_fail("unsafe-effective-policy")
	if(hh_effect["size"]!="") {
		if(hh_effect["mode"]!="" || hh_effect["size"]=="0" || hh_effect["maxsize"]!="0") hh_fail("unsafe-effective-policy")
		hh_observed_mode="size"; hh_observed_size=hh_effect["size"]
	} else {
		if(hh_effect["mode"]=="" || hh_effect["maxsize"]=="" || hh_effect["maxsize"]=="0") hh_fail("unsafe-effective-policy")
		hh_observed_mode=hh_effect["mode"]; hh_observed_size=hh_effect["maxsize"]
	}
}
# Non-owned fragments are never interpreted as ownership. Conservative token
# coverage checks reject potential family matches and nested include semantics.
function hh_foreign(text,base,    lines,n,i,line,header,a,k,j,pat,stanza,script,key,prefix) {
	n=hh_lines(text,lines)
	for(i=1;i<=n;i++) {
		line=hh_clean(lines[i]); if(line=="") continue
		if(script) { if(line=="endscript") script=0; continue }
		if(line=="include /opt/etc/logrotate.d") continue
		if(line~/^include[ \t]/) hh_fail("unsupported-include")
		if(index(line,base)) hh_fail("foreign-family-coverage")
		if(index(line,"{")) {
			if(stanza) hh_fail("unsupported-foreign-rule")
			header=hh_trim(substr(line,1,index(line,"{")-1)); k=split(header,a,/[ \t]+/)
			for(j=1;j<=k;j++) {
				pat=hh_unquote(a[j])
				if(pat~/[?*\[]/) {
					prefix=pat; sub(/[?*\[].*$/,"",prefix)
					if(prefix=="" || substr(base,1,length(prefix))==prefix || substr(prefix,1,length(base))==base) hh_fail("ambiguous-family-coverage")
				}
			}
			stanza=1
		} else if(line=="}") { if(!stanza) hh_fail("unsupported-foreign-rule"); stanza=0 }
		else if(line~/^(postrotate|prerotate|firstaction|lastaction)$/) script=1
		else if(!stanza) {
			split(line,a,/[ \t]+/); key=a[1]
			# The owned rule explicitly neutralizes these inherited settings.
			# Unknown global semantics (olddir/extension/addextension/etc.) can
			# change family paths and must never be silently interpreted away.
			if(key!~/^(hourly|daily|weekly|monthly|yearly|size|minsize|maxsize|minage|maxage|rotate|start|compress|nocompress|delaycompress|nodelaycompress|create|nocreate|dateext|nodateext|dateformat|missingok|nomissingok|notifempty|ifempty|sharedscripts|nosharedscripts)$/) hh_fail("unsupported-global-policy")
		}
	}
	if(stanza || script) hh_fail("unsupported-foreign-rule")
}
function hh_assess(    f,base,owned,i,p,policy,a,n,mode,size,rotate,age) {
	f=ENVIRON["CFMGR_HISTORY_FEATURE"]; if(f!~/^(ddns|ip_sync|cloudflared)$/) hh_fail("feature")
	base="/opt/var/log/" (f=="ip_sync"?"ip-sync":f) ".log"; owned="/opt/etc/logrotate.d/cfmgr-" (f=="ip_sync"?"ip-sync":f)
	hh_include_scan(hh_data["rotate-debug"])
	if(!hh_includes[owned] || !(owned in hh_fragment)) hh_fail("owned-rule-not-included")
	for(i=1;i<=hh_include_count;i++) {
		p=hh_include_order[i]
		if(p=="/opt/etc/logrotate.conf") hh_foreign(hh_data["rotate-config"],base)
		else if(p!=owned) { if(!(p in hh_fragment)) hh_fail("include-evidence"); hh_foreign(hh_fragment[p],base) }
	}
	hh_required["nocompress"]=hh_required["nodelaycompress"]=hh_required["nodateext"]=hh_required["missingok"]=hh_required["notifempty"]=hh_required["copytruncate"]="1"
	hh_rule(hh_fragment[owned],base)
	policy=ENVIRON["CFMGR_HISTORY_POLICY"]; n=split(policy,a," ")
	if(n!=6 || a[1]!="POLICY" || a[6]!="END") hh_fail("policy")
	if(f=="cloudflared") {
		if(a[2]!=hh_observed_mode || "n" a[3]!="n" hh_observed_size || "n" a[4]!="n" hh_effect["rotate"] || (a[4]!="0" && "n" a[5]!="n" hh_effect["maxage"])) hh_fail("saved-policy-mismatch")
	} else if(a[2]!="native" || hh_observed_mode!="size" || hh_effect["maxage"]!="0") hh_fail("native-policy")
	print "EFFECTIVE " f " " hh_observed_mode " " hh_observed_size " " hh_effect["rotate"] " " hh_effect["maxage"] " END"
}
function hh_family(text,    f,base,lines,n,i,name,suffix,max,count) {
	f=ENVIRON["CFMGR_HISTORY_FEATURE"]; if(f!~/^(ddns|ip_sync|cloudflared)$/) hh_fail("feature")
	base=(f=="ip_sync"?"ip-sync":f) ".log"; max=ENVIRON["CFMGR_HISTORY_ROTATE"]
	if(!hh_uint(max,"2147483647")) hh_fail("policy")
	n=hh_lines(text,lines)
	for(i=1;i<=n;i++) {
		name=lines[i]; if(name=="") continue
		if(name==base) hh_family_rows[++count]="MEMBER " hh_hex("/opt/var/log/" name) " live END"
		else if(substr(name,1,length(base)+1)==base ".") {
			suffix=substr(name,length(base)+2)
			if(suffix!~/^[1-9][0-9]*$/ || !hh_uint(suffix,max)) hh_fail("unsupported-history-family")
			hh_family_rows[++count]="MEMBER " hh_hex("/opt/var/log/" name) " rotation END"
		}
	}
	for(i=1;i<=count;i++) print hh_family_rows[i]
	print "FAMILY " sprintf("%.0f",count) " END"
}
function hh_targets(text,    f,base,lines,n,i,line,scope,path,count,own_seen,j) {
	f=ENVIRON["CFMGR_HISTORY_FEATURE"]; if(f!~/^(ddns|ip_sync|cloudflared)$/) hh_fail("feature")
	base="/opt/var/log/" (f=="ip_sync"?"ip-sync":f) ".log"
	n=hh_lines(text,lines)
	for(i=1;i<=n;i++) {
		line=hh_trim(lines[i])
		if(line~/^rotating pattern: /) {
			scope=(index(line,"rotating pattern: " base " ")==1 || index(line,"rotating pattern: \"" base "\" ")==1)?"owning":"foreign"
		} else if(line~/^considering log /) {
			if(scope=="") hh_fail("debug-target-scope")
			path=substr(line,length("considering log ")+1)
			if(path!~/^\// || path~/[^ -~]/ || length(path)>1024) hh_fail("debug-target-path")
			if(scope=="owning") { if(path!=base) hh_fail("debug-target-scope"); own_seen++ }
			count++; hh_target_path[count]=path; hh_target_scope[count]=scope
		} else if(count && line=="log " hh_target_path[count] " does not exist -- skipping") hh_target_absent[count]=1
	}
	if(own_seen!=1) hh_fail("debug-target-scope")
	for(i=1;i<=count;i++) print "TARGET " hh_hex(hh_target_path[i]) " " hh_target_scope[i] " " (hh_target_absent[i]?"absent":"present") " END"
}
function hh_audit(line,    a,n,key) {
	n=split(line,a," ")
	if(a[1]=="OWN") {
		if(n!=6 || a[6]!~/^(live|rotation)$/ || hh_audit_foreign) hh_fail("coverage-framing")
		key=a[4] ":" a[5]; hh_own_canonical[a[3]]=1; hh_own_inode[key]=1
		hh_own_logical[a[2]]=a[3] " " key
		if(a[6]=="live") hh_own_live=a[2]
	} else if(a[1]=="TARGET") {
		if(n!=6 || a[6]!~/^(owning|foreign)$/) hh_fail("coverage-framing")
		hh_audit_foreign=1; key=a[4] ":" a[5]
		if(a[6]=="foreign") {
			if((a[3] in hh_own_canonical) || (key in hh_own_inode)) hh_fail("foreign-family-alias")
		} else {
			if(!(a[2] in hh_own_logical) || hh_own_logical[a[2]]!=a[3] " " key) hh_fail("observation-changed")
			hh_audit_live_seen=a[2]
		}
	} else if(a[1]=="ABSENT") {
		if(n!=3 || a[3]!~/^(owning|foreign)$/) hh_fail("coverage-framing")
		hh_audit_foreign=1
		if(a[3]=="owning" && (a[2] in hh_own_logical)) hh_fail("observation-changed")
	} else hh_fail("coverage-framing")
}
BEGIN {
	hh_mode=ENVIRON["CFMGR_HISTORY_MODE"]; hh_limit=ENVIRON["CFMGR_HISTORY_LIMIT"]
	if(!hh_uint(hh_limit,"9007199254740991") || hh_limit=="0") hh_fail("budget")
	for(hh_i=1;hh_i<256;hh_i++) hh_ord[sprintf("%c",hh_i)]=hh_i
	if(hh_mode=="policy") { hh_policy(); exit 0 }
	if(hh_mode=="path" || hh_mode=="target-path") {
		hh_pathname=hh_decode(ENVIRON["CFMGR_HISTORY_LABEL"])
		if(hh_mode=="target-path") { if(hh_pathname!~/^\// || hh_pathname~/[^ -~]/ || length(hh_pathname)>1024) hh_fail("path") }
		else if(!hh_path(hh_pathname) && hh_pathname!~/^\/opt\/var\/log\/(ddns|ip-sync|cloudflared)[.]log([.][1-9][0-9]*)?$/) hh_fail("path")
		print hh_pathname; exit 0
	}
	if(hh_mode!~/^(plan|pack|includes|base|assess|family|compare|targets|audit)$/) hh_fail("mode")
}
{
	hh_bytes+=length($0)+1; if(hh_bytes>hh_limit) hh_fail("metadata-limit")
	if(hh_mode=="compare") {
		if((getline hh_compare_line < ENVIRON["CFMGR_HISTORY_LABEL"])!=1 || "x" hh_compare_line!="x" $0) hh_fail("observation-changed")
	} else if(hh_mode=="plan") hh_plan($0)
	else if(hh_mode=="audit") hh_audit($0)
	else if(hh_mode=="pack" || hh_mode=="includes" || hh_mode=="family" || hh_mode=="targets") {
		if(length($0)!=2 || $0~/[^0-9a-f]/) hh_fail("framing")
		hh_packed=hh_packed $0
	} else {
		hh_n=split($0,hh_fields," ")
		if(hh_n!=3 || hh_fields[1]!~/^(DATA|FRAGMENT)$/ || hh_fields[3]~/[^0-9a-f]/) hh_fail("framing")
		if(hh_fields[1]=="DATA") { if(hh_fields[2] in hh_data) hh_fail("framing"); hh_data[hh_fields[2]]=hh_decode(hh_fields[3]) }
		else { hh_pathname=hh_decode(hh_fields[2]); if(!hh_path(hh_pathname) || hh_pathname in hh_fragment) hh_fail("framing"); hh_fragment[hh_pathname]=hh_decode(hh_fields[3]) }
	}
}
END {
	if(hh_bad) exit 1
	if(hh_mode=="compare") {
		if((getline hh_compare_line < ENVIRON["CFMGR_HISTORY_LABEL"])!=0) hh_fail("observation-changed")
		close(ENVIRON["CFMGR_HISTORY_LABEL"]); print "SAME END"
	} else if(hh_mode=="audit") {
		if(hh_own_live!="" && hh_audit_live_seen!=hh_own_live) hh_fail("observation-changed")
		print "COVERAGE ready END"
	} else if(hh_mode=="targets") hh_targets(hh_decode(hh_packed))
	else if(hh_mode=="plan") hh_plan_end()
	else if(hh_mode=="pack") {
		hh_label=ENVIRON["CFMGR_HISTORY_LABEL"]; if(hh_label!~/^[A-Za-z0-9_.-]+$/) hh_fail("framing")
		if(hh_packed=="") hh_packed="0a"
		print "DATA " hh_label " " hh_packed
	} else if(hh_mode=="includes") {
		hh_include_scan(hh_decode(hh_packed))
		for(hh_i=1;hh_i<=hh_include_count;hh_i++) print "INCLUDE " hh_hex(hh_include_order[hh_i]) " END"
	} else if(hh_mode=="base") hh_base()
	else if(hh_mode=="assess") hh_assess()
	else if(hh_mode=="family") hh_family(hh_decode(hh_packed))
}
'
	# CFMGR-AWK-END backup_history
}

cfmgr_backup_awk_backup_inventory() {
	# CFMGR-AWK-BEGIN backup_inventory
	cfmgr_awk_program='
# Fixed streaming inventory grammar. Shared decoder/math: backup manifest getter.
# CFMGR_ARCHIVE_INDEX is the trusted raw-header index, never archive-selected.
function ai_role(role) {
    return role~/^(manager\.(config|catalog)|data\.(setup-drafts|cloudflared\.(yaml|json|certificate|certificate-recovery|yaml-backup))|history\.(ddns|ip_sync|cloudflared))$/ ||
        (length(role)<=length("data.cloudflared.input.")+64 && role~/^data\.cloudflared\.input\.[A-Za-z][A-Za-z0-9_.-]*$/)
}
function ai_path(path, n,p,i) {
    if(path~/^\/|\\|\/$|\/\//)return 0
    n=split(path,p,"/")
    for(i=1;i<=n;i++)if(p[i]=="" || p[i]=="." || p[i]=="..")return 0
    return 1
}
function ai_data(path, n,p,i,b) {
    if(substr(path,1,16)!="etc/cloudflared/")return 0
    n=split(path,p,"/")
    for(i=1;i<=n;i++)if(p[i]~/^\./ || p[i]~/^(import|staging|CFBackup)$/)return 0
    b=p[n]
    return b!~/^(cloudflared|cfmgr|cfmgr\.sh|catalog\.txt|manifest\.txt|setup-state|setup-in-progress|config\.lock)$/ && b!~/\.(sh|so|bin|exe|py|lock|pid|old)$/
}
function ai_file(a, path,base,rotation,n,idx,name,size,raw,stream,extra) {
    if(!ai_role(a[3]) || a[4]!~/^(jffs|entware)$/ || !am_generation(a[6]) || a[7]!~/^0[0246][0246][0246]$/ || !am_uint(a[8],am_max) || !am_hex(a[9],64) || a[10]!~/^(whole|prefix|recovered)$/)am_fail()
    path=am_printhex(a[5],1024);if(!ai_path(path))am_fail()
    ai_files++;if(ai_files>99999999 || a[2]!=sprintf("p%08d",ai_files))am_fail()
    if(ai_files==1 && a[3]!="manager.config")am_fail()
    if(ai_files==2 && a[3]!="manager.catalog")am_fail()
    if(ai_pairs[a[3] SUBSEP a[4] SUBSEP path]++)am_fail()
    if(a[3]!~/^history\./ && ai_single[a[3]]++)am_fail()
    if(a[3]=="manager.config"){if(a[4]!="jffs" || path!="addons/CFMgr.d/config")am_fail()}
    else if(a[3]=="manager.catalog"){if(a[4]!="jffs" || path!="addons/CFMgr.d/catalog.txt")am_fail()}
    else if(a[3]=="data.setup-drafts"){if(a[4]!="jffs" || path!="addons/CFMgr.d/setup-drafts")am_fail()}
    else if(a[3]=="data.cloudflared.certificate-recovery"){if(a[4]!="jffs" || path!="addons/CFMgr.d/cert.pem")am_fail()}
    else if(a[3]~/^history\./) {
        if(a[4]!="entware")am_fail()
        base=(a[3]=="history.ddns"?"var/log/ddns.log":(a[3]=="history.ip_sync"?"var/log/ip-sync.log":"var/log/cloudflared.log"))
        if(path!=base){if(substr(path,1,length(base)+1)!=base ".")am_fail();rotation=substr(path,length(base)+2);if(rotation!~/^[1-9][0-9]*$/)am_fail()}
    } else if(a[4]!="entware" || !ai_data(path))am_fail()
    if(a[10]=="prefix" && (a[3]!="history.cloudflared" || path!="var/log/cloudflared.log"))am_fail()
    if(a[10]=="recovered" && a[3]!~/^data\.cloudflared\.(certificate|certificate-recovery)$/)am_fail()
    if((getline idx < ai_index)<=0)am_fail()
    n=split(idx,ai_header," ")
    if(n!=4 || ai_header[1]!=a[2] || "x" ai_header[2]!="x" a[8])am_fail()
    ai_sum=am_add(ai_sum,a[8])
    # Internal receipt adds the checked body-stream offset to the ten fields.
    print "PAYLOAD " a[2] " " a[3] " " a[4] " " a[5] " " a[6] " " a[7] " " a[8] " " a[9] " " a[10] " " ai_header[4]
}
function ai_line(line, n,a,extra) {
    n=split(line,a," ")
    if(!ai_started){if(line!="CFMGR-INVENTORY 1")am_fail();ai_started=1;return}
    if(ai_ended)am_fail()
    if(a[1]=="FILE") {if(n!=10)am_fail();ai_rows=am_add(ai_rows,"1");ai_file(a)}
    else if(a[1]=="NOTE") {
        if(n!=6 || !ai_role(a[2]) || a[3]!~/^(included|absent|unavailable|external|not_applicable)$/ || a[5]!~/^[a-z][a-z0-9-]*$/ || length(a[5])>64 || a[6]!="END")am_fail()
        if(a[4]!="-")am_printhex(a[4],1024)
        ai_notes=am_add(ai_notes,"1");ai_rows=am_add(ai_rows,"1")
    } else if(a[1]=="END") {
        if(n!=4 || "x" a[2]!="x" sprintf("%d",ai_files) || "x" a[3]!="x" ai_notes || "x" a[4]!="x" ai_sum || ai_files<2 || "x" ai_rows!="x" ENVIRON["CFMGR_ARCHIVE_ROWS"] || "x" ai_sum!="x" ENVIRON["CFMGR_ARCHIVE_PAYLOAD_BYTES"] || "x" sprintf("%d",ai_files)!="x" ENVIRON["CFMGR_ARCHIVE_FILES"])am_fail()
        if((getline extra < ai_index)!=0)am_fail()
        ai_ended=1
    } else am_fail()
}
BEGIN {
    ai_index=ENVIRON["CFMGR_ARCHIVE_INDEX"];ai_sum=ai_notes=ai_rows="0"
    if(am_mode!="inventory" || ai_index=="")am_fail()
    # Raw walk already proved these metadata bodies; payload rows follow.
    if((getline ai_first < ai_index)<=0 || split(ai_first,ai_header," ")!=4 || ai_header[1]!="manifest")am_fail()
    if((getline ai_second < ai_index)<=0 || split(ai_second,ai_header," ")!=4 || ai_header[1]!="inventory")am_fail()
}
{if(am_ready)ai_line(am_decoded)}
END {
    if(am_bad || !ai_ended)exit 1
    print "COMPLETE " sprintf("%d",ai_files) " " ai_notes " " ai_sum
}
'
	# CFMGR-AWK-END backup_inventory
}
