#!/bin/sh
# Source-inert backup destination backend. Trusted entry imports storage, Store
# and prerequisites explicitly. No archive/restore or Entware authority here.
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
	cfmgr_store_run store-backup-mounts "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/mountinfo.awk" /tmp/mnt || return $?
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
	while [ "$cfmgr_backup_ui_leave" = 0 ]; do
		printf '%s\n' 'Backup / Restore: destination management only' 'Archive creation and restore are unavailable.'
		cfmgr_backup_ui_show_state
		printf '%s\n' '1 Select backup drive' 's Save destination' 'e Back'
		[ "$cfmgr_backup_ui_pending" != 1 ] || printf '%s\n' 'r Recover previous Save'
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
		e) return 0 ;;
		esac
	done
}
