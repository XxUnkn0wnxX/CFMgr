#!/bin/sh
# Source-inert native settings store plus cooperative operational writer lock.
# Settings never admit Entware or providers; observation keeps its admitted flock.
# Public API: read | save check|auto|both CHECK(0|1) AUTO(0|1) | recover.
# Exactly one CFMGR-STORE v1 receipt describes the result, never status0 alone.
# The transaction subshell owns FD0 lock, FD3 flush, FD4 guard, FD5 RAM,
# FD8 JFFS and FD9 support. UI stdin and caller state remain untouched.
# Cooperative lock + immediate raw freshness checks are not CAS against root
# editors. Same-mount publication/fsync is representative proof, not JFFS2 beta.
# shellcheck disable=SC2030,SC2031,SC2034,SC2154,SC3013
# Helpers run inside the API subshell; observation initializes its own borrowed state.
cfmgr_config_store() (
	cfmgr_store_result=unavailable cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0
	cfmgr_store_pending=0 cfmgr_config_lock_fd0=0 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0 cfmgr_store_flock_entware=0
	case ${1:-}:$# in read:1 | recover:1) ;; save:4)
		case $2:$3:$4 in check:[01]:[01] | auto:[01]:[01] | both:[01]:[01]) ;; *) exit 2 ;; esac
		[ "$2:$3:$4" != both:0:1 ] || exit 2
		;;
	*) exit 2 ;;
	esac
	cfmgr_store_operation=$1 cfmgr_store_mask=${2:-both} cfmgr_store_want_check=${3:-0} cfmgr_store_want_auto=${4:-0}
	if cfmgr_store_prepare && cfmgr_store_work; then cfmgr_store_code=0; else cfmgr_store_code=$?; fi
	if [ "$cfmgr_store_code" = 3 ]; then
		cfmgr_store_result=unresolved cfmgr_store_pending=1
	else
		# Release by close after reap, never unlock a child's shared description.
		exec 0<&-
		cfmgr_config_lock_fd0=0 cfmgr_store_interrupt=0
		if [ -n "${cfmgr_store_context:-}" ] && ! cfmgr_store_cleanup; then
			cfmgr_store_result=recovery cfmgr_store_code=1 cfmgr_store_pending=1
		fi
	fi
	[ "$cfmgr_store_code" != 4 ] || cfmgr_store_code=1
	if [ "$cfmgr_store_code" != 0 ]; then cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0; fi
	printf 'CFMGR-STORE 1 %s %s %s %s %s %s END\n' "$cfmgr_store_result" "$cfmgr_store_generation" "$cfmgr_store_check" "$cfmgr_store_auto" "$cfmgr_store_developer" "$cfmgr_store_pending"
	exit "$cfmgr_store_code"
)

cfmgr_store_prepare() {
	cfmgr_store_source=/jffs/addons/CFMgr.d cfmgr_store_jffs=/jffs cfmgr_store_ram=/tmp/cfmgr
	cfmgr_store_live=$cfmgr_store_source/config cfmgr_store_lock=$cfmgr_store_ram/config.lock
	cfmgr_store_sh=/bin/sh cfmgr_store_env=/usr/bin/env cfmgr_store_awk=/usr/bin/awk cfmgr_store_readlink=/usr/bin/readlink
	cfmgr_store_wc=/usr/bin/wc cfmgr_store_ls=/bin/ls cfmgr_store_sleep=/bin/sleep cfmgr_store_flock=/usr/bin/flock
	cfmgr_store_openssl=/usr/sbin/openssl cfmgr_store_dd=/bin/dd cfmgr_store_cp=/bin/cp cfmgr_store_mv=/bin/mv cfmgr_store_fsync=/bin/fsync
	for cfmgr_store_path in /jffs /jffs/addons "$cfmgr_store_source" /tmp; do
		[ -d "$cfmgr_store_path" ] && [ ! -L "$cfmgr_store_path" ] && [ "$(/usr/bin/readlink -f "$cfmgr_store_path")" = "$cfmgr_store_path" ] || return 1
	done
	# Trusted entry admits this library and prerequisites before source. Store
	# independently protects every fixed file it will execute/read as code.
	for cfmgr_store_code_path in "$cfmgr_store_source/modules/helpers/probe.sh" "$cfmgr_store_source/modules/lib/json.awk" "$cfmgr_store_source/modules/lib/config_observation.awk" "$cfmgr_store_source/modules/lib/mountinfo.awk"; do
		cfmgr_store_protected "$cfmgr_store_code_path" || return 1
	done
	for cfmgr_store_tool_path in "$cfmgr_store_sh" "$cfmgr_store_env" "$cfmgr_store_awk" "$cfmgr_store_readlink" "$cfmgr_store_wc" "$cfmgr_store_ls" "$cfmgr_store_sleep" "$cfmgr_store_dd" "$cfmgr_store_cp" "$cfmgr_store_mv" "$cfmgr_store_fsync" /bin/mkdir /bin/rm /bin/rmdir /bin/df /bin/usleep; do
		cfmgr_store_native_tool "$cfmgr_store_tool_path" || return 1
	done
	cfmgr_store_jffs_mount=$(/usr/bin/awk -f "$cfmgr_store_source/modules/lib/mountinfo.awk" /jffs /proc/self/mountinfo) || return 1
	cfmgr_store_tmp_mount=$(/usr/bin/awk -f "$cfmgr_store_source/modules/lib/mountinfo.awk" /tmp /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_store_id cfmgr_store_parent cfmgr_store_device cfmgr_store_root cfmgr_store_point cfmgr_store_type cfmgr_store_mount_source cfmgr_store_mount_flags cfmgr_store_mount_super <<EOF_JFFS
$cfmgr_store_jffs_mount
EOF_JFFS
	[ "$cfmgr_store_point:$cfmgr_store_type" = /jffs:jffs2 ] && cfmgr_store_mount_writable || return 1
	IFS='	' read -r cfmgr_store_id cfmgr_store_parent cfmgr_store_device cfmgr_store_root cfmgr_store_point cfmgr_store_type cfmgr_store_mount_source cfmgr_store_mount_flags cfmgr_store_mount_super <<EOF_RAM
$cfmgr_store_tmp_mount
EOF_RAM
	case $cfmgr_store_type in tmpfs | ramfs | rootfs) ;; *) return 1 ;; esac
	cfmgr_store_mount_writable || return 1
	[ "$(/usr/bin/awk -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_store_source" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] || return 1
	if [ ! -e "$cfmgr_store_ram" ] && [ ! -L "$cfmgr_store_ram" ]; then /bin/mkdir -m 700 "$cfmgr_store_ram" || return 1; fi
	cfmgr_store_admit_private "$cfmgr_store_ram" directory && cfmgr_store_admit_private "$cfmgr_store_source" directory || return 1
	IFS= read -r cfmgr_store_self </proc/self/stat || return 1
	cfmgr_store_pid=${cfmgr_store_self%% *}
	cfmgr_prerequisites_identity "$cfmgr_store_pid" || return 1
	cfmgr_store_context=$cfmgr_store_ram/settings.$cfmgr_store_pid.$cfmgr_identity_start
	umask 077
	/bin/mkdir -m 700 "$cfmgr_store_context" || return 1
	exec 5<"$cfmgr_store_context" 8<"$cfmgr_store_jffs" 9<"$cfmgr_store_source" || return 3
	cfmgr_store_context_fd=5 cfmgr_store_borrowed=0 cfmgr_probe_pid='' cfmgr_probe_serial=0
	trap 'cfmgr_store_interrupt=1' HUP INT TERM
	cfmgr_prerequisites_now || return 1
	cfmgr_store_deadline=$((cfmgr_probe_now + 20))
}

# Fixed root/native metadata admission before acquiring the RAM lock. It never
# changes modes or follows a caller/config-selected executable or symlink.
cfmgr_store_admit_private() {
	[ ! -L "$1" ] || return 1
	cfmgr_store_metadata=$(/bin/ls -ldn "$1") || return 1
	IFS=' ' read -r cfmgr_store_mode cfmgr_store_links cfmgr_store_uid cfmgr_store_rest <<EOF_MODE
$cfmgr_store_metadata
EOF_MODE
	case $2:$cfmgr_store_mode:$cfmgr_store_uid in directory:drwx------:0 | file:-rw-------:0) return 0 ;; *) return 1 ;; esac
}

cfmgr_store_mount_writable() {
	case ,$cfmgr_store_mount_flags, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_store_mount_super, in *,rw,*) ;; *) return 1 ;; esac
}

cfmgr_store_protected() {
	cfmgr_store_protected_path=$1
	while :; do
		[ ! -L "$cfmgr_store_protected_path" ] || return 1
		cfmgr_store_protected_meta=$("$cfmgr_store_ls" -ldn "$cfmgr_store_protected_path") || return 1
		IFS=' ' read -r cfmgr_store_protected_mode cfmgr_store_protected_links cfmgr_store_protected_uid cfmgr_store_rest <<EOF_PROTECTED
$cfmgr_store_protected_meta
EOF_PROTECTED
		[ "$cfmgr_store_protected_uid" = 0 ] || return 1
		case $cfmgr_store_protected_mode in -????????? | d?????????) ;; *) return 1 ;; esac
		case $cfmgr_store_protected_mode in ?????w???? | ????????w?) return 1 ;; esac
		[ "$cfmgr_store_protected_path" != / ] || break
		cfmgr_store_protected_path=${cfmgr_store_protected_path%/*}
		[ -n "$cfmgr_store_protected_path" ] || cfmgr_store_protected_path=/
	done
}

cfmgr_store_fd_is() { [ ! -L "$1" ] && [ "$1" -ef "/proc/self/fd/$2" ]; }

cfmgr_store_attachment_ok() {
	if [ "${cfmgr_store_borrowed:-0}" = 1 ]; then cfmgr_launch_attachment_ok || return 1; fi
	[ "$cfmgr_store_interrupt" = 0 ] && cfmgr_store_fd_is "$cfmgr_store_context" "$cfmgr_store_context_fd" &&
		cfmgr_store_fd_is "$cfmgr_store_source" 9 && cfmgr_store_fd_is "$cfmgr_store_jffs" 8 || return 1
	[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_store_source" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] &&
		[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_store_jffs" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] &&
		[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" /tmp /proc/self/mountinfo)" = "$cfmgr_store_tmp_mount" ] || return 1
	if [ "$cfmgr_config_lock_fd0" = 1 ]; then cfmgr_store_fd_is "$cfmgr_store_lock" 0 || return 1; fi
	if [ "$cfmgr_store_guard_owned" = 1 ]; then
		[ "$("$cfmgr_store_awk" -f "$cfmgr_store_source/modules/lib/mountinfo.awk" "$cfmgr_store_guard" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] || return 1
		if cfmgr_store_fd_is "$cfmgr_store_guard" 4; then
			:
		elif [ -n "${cfmgr_store_guard_next:-}" ] && [ "${cfmgr_probe_mode:-}" = store-move ] && cfmgr_store_fd_is "$cfmgr_store_guard_next" 4; then
			:
		elif [ "${cfmgr_store_retiring:-0}:${cfmgr_probe_mode:-}" = 1:store-rmdir ] && [ -n "${cfmgr_probe_pid:-}" ]; then
			cfmgr_store_deleted=$("$cfmgr_store_ls" -Ldn /proc/self/fd/4) || return 1
			IFS=' ' read -r cfmgr_store_deleted_mode cfmgr_store_deleted_links cfmgr_store_deleted_uid cfmgr_store_rest <<EOF_DELETED
$cfmgr_store_deleted
EOF_DELETED
			[ "$cfmgr_store_deleted_mode:$cfmgr_store_deleted_links:$cfmgr_store_deleted_uid" = drwx------:0:0 ] || return 1
		else return 1; fi
	fi
}

cfmgr_store_run() {
	cfmgr_store_run_mode=$1 cfmgr_store_run_tool=$2
	shift 2
	cfmgr_store_attachment_ok || return 1
	cfmgr_prerequisites_now || return 1
	[ "$cfmgr_probe_now" -lt "$cfmgr_store_deadline" ] || return 1
	cfmgr_prerequisites_run "$cfmgr_store_run_mode" "$cfmgr_store_context" "$cfmgr_store_sh" "$cfmgr_store_source/modules/helpers/probe.sh" \
		"$cfmgr_store_env" "$cfmgr_store_awk" "$cfmgr_store_sleep" "$cfmgr_store_wc" "$cfmgr_store_run_tool" "$@" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_store_read_line() {
	cfmgr_store_line='' cfmgr_store_tail=''
	{
		IFS= read -r cfmgr_store_line || return 1
		if IFS= read -r cfmgr_store_tail; then return 1; fi
		[ -z "$cfmgr_store_tail" ]
	} <"$1"
}

cfmgr_store_count() {
	cfmgr_store_run store-count "$cfmgr_store_wc" "$1" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_store_bytes cfmgr_store_extra <<EOF_COUNT
$cfmgr_store_line
EOF_COUNT
	case $cfmgr_store_bytes:$cfmgr_store_extra in *[!0-9:]*) return 1 ;; esac
	[ -n "$cfmgr_store_bytes" ] && [ -z "$cfmgr_store_extra" ] && [ "${#cfmgr_store_bytes}" -le 6 ] && [ "$cfmgr_store_bytes" -le 65536 ]
}

cfmgr_store_metadata() {
	cfmgr_store_run store-meta "$cfmgr_store_ls" "$1" || return $?
	cfmgr_store_meta_raw=$cfmgr_probe_stdout
	cfmgr_store_run store-meta-frame "$cfmgr_store_awk" "$cfmgr_store_meta_raw" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_store_meta=$cfmgr_store_line
}

cfmgr_store_snapshot() {
	cfmgr_store_snapshot_source=$1
	cfmgr_store_metadata "$cfmgr_store_snapshot_source" || return $?
	cfmgr_store_snapshot_meta=$cfmgr_store_meta
	cfmgr_store_run store-snapshot "$cfmgr_store_dd" "$1" || return $?
	cfmgr_store_snapshot=$cfmgr_probe_stdout
	cfmgr_store_count "$cfmgr_store_snapshot" || return $?
	[ "$cfmgr_store_bytes" -gt 0 ] || return 1
	cfmgr_store_snapshot_bytes=$cfmgr_store_bytes
	[ "$cfmgr_store_snapshot_bytes" = "${cfmgr_store_snapshot_meta#*:}" ] || return 1
	cfmgr_store_metadata "$cfmgr_store_snapshot_source" || return $?
	[ "$cfmgr_store_snapshot_meta" = "$cfmgr_store_meta" ]
}

cfmgr_store_parse() {
	cfmgr_store_run store-settings "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/json.awk" "$cfmgr_store_source/modules/lib/config_observation.awk" \
		"$1" "$2" "$3" "$cfmgr_store_mask" "$cfmgr_store_want_check" "$cfmgr_store_want_auto"
}

cfmgr_store_flags() {
	cfmgr_store_parse settings-read "$1" "$2" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_store_tag cfmgr_store_schema cfmgr_store_generation cfmgr_store_check cfmgr_store_auto cfmgr_store_developer cfmgr_store_end cfmgr_store_extra <<EOF_FLAGS
$cfmgr_store_line
EOF_FLAGS
	[ "$cfmgr_store_tag:$cfmgr_store_schema:$cfmgr_store_end:$cfmgr_store_extra" = CFMGR-SETTINGS:1:END: ] || return 1
	case $cfmgr_store_generation in '' | 0* | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_store_generation}" -le 20 ] || return 1
	case $cfmgr_store_check:$cfmgr_store_auto:$cfmgr_store_developer in [01]:[01]:[01]) ;; *) return 1 ;; esac
	[ "$cfmgr_store_line" = "CFMGR-SETTINGS 1 $cfmgr_store_generation $cfmgr_store_check $cfmgr_store_auto $cfmgr_store_developer END" ]
}

cfmgr_store_native_tool() {
	[ -f "$1" ] && [ -x "$1" ] || return 1
	cfmgr_store_tool_target=$("$cfmgr_store_readlink" -f "$1") || return 1
	case $cfmgr_store_tool_target in "$1" | /bin/busybox) ;; *) return 1 ;; esac
	cfmgr_store_tool_metadata=$("$cfmgr_store_ls" -ldn "$cfmgr_store_tool_target") || return 1
	IFS=' ' read -r cfmgr_store_tool_mode cfmgr_store_tool_links cfmgr_store_tool_uid cfmgr_store_rest <<EOF_TOOL
$cfmgr_store_tool_metadata
EOF_TOOL
	[ "$cfmgr_store_tool_uid" = 0 ] || return 1
	case $cfmgr_store_tool_mode in -?????????) ;; *) return 1 ;; esac
	case $cfmgr_store_tool_mode in ?????w???? | ????????w?) return 1 ;; esac
	cfmgr_store_protected "$cfmgr_store_tool_target"
}

cfmgr_store_digest_admit() {
	cfmgr_store_native_tool "$cfmgr_store_openssl" || return 1
	(
		umask 077
		set -C
		printf abc >"$cfmgr_store_context/sha-vector"
	) || return 1
	cfmgr_store_digest "$cfmgr_store_context/sha-vector" || return $?
	[ "$cfmgr_store_digest_value" = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]
}

cfmgr_store_digest() {
	cfmgr_store_run store-digest "$cfmgr_store_openssl" "$1" || return $?
	cfmgr_store_digest_raw=$cfmgr_probe_stdout
	cfmgr_store_count "$cfmgr_store_digest_raw" || return $?
	[ "$cfmgr_store_bytes" = 72 ] || return 1
	cfmgr_store_run store-digest-frame "$cfmgr_store_awk" "$cfmgr_store_digest_raw" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_store_digest_value=$cfmgr_store_line
	[ "${#cfmgr_store_digest_value}" = 64 ] || return 1
	case $cfmgr_store_digest_value in *[!0-9a-f]*) return 1 ;; esac
}

cfmgr_store_pending() {
	cfmgr_store_pending=0
	for cfmgr_store_phase in .storage-observation .config-save.preparing .config-save .config-save.retired; do
		if [ -e "$cfmgr_store_source/$cfmgr_store_phase" ] || [ -L "$cfmgr_store_source/$cfmgr_store_phase" ]; then cfmgr_store_pending=1; fi
	done
}

cfmgr_store_lock_acquire() {
	if [ "${cfmgr_store_flock_entware:-0}" = 1 ]; then
		cfmgr_prerequisites_admit_tool "$cfmgr_store_flock" || return $?
	else cfmgr_store_native_tool "$cfmgr_store_flock" || return 1; fi
	cfmgr_store_run store-lock-create "$cfmgr_store_sh" "$cfmgr_store_lock" || return $?
	cfmgr_store_admit_private "$cfmgr_store_lock" file || return 1
	exec 0<>"$cfmgr_store_lock" || return 1
	cfmgr_config_lock_fd0=1
	cfmgr_store_fd_is "$cfmgr_store_lock" 0 || return 1
	if cfmgr_store_run store-lock "$cfmgr_store_flock"; then :; else
		cfmgr_store_lock_code=$?
		[ "$cfmgr_store_lock_code" != 3 ] || return 3
		if [ "$cfmgr_probe_mode:${cfmgr_probe_status:-}:$cfmgr_probe_exit:${cfmgr_probe_reason:-}" = store-lock:reaped:1: ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]; then cfmgr_store_result=busy; fi
		return 1
	fi
	# A fresh independent open must contend AFTER the helper that acquired the
	# inherited description exits. This admits semantics, not executability alone.
	if cfmgr_store_run store-lock-test "$cfmgr_store_flock" "$cfmgr_store_lock"; then return 1; else
		cfmgr_store_lock_code=$?
		[ "$cfmgr_store_lock_code" != 3 ] || return 3
	fi
	[ "$cfmgr_probe_mode:${cfmgr_probe_status:-}:$cfmgr_probe_exit:${cfmgr_probe_reason:-}" = store-lock-test:reaped:1: ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]
}

cfmgr_store_flush() {
	cfmgr_store_attachment_ok || return 1
	[ ! -L "$1" ] && { [ -f "$1" ] || [ -d "$1" ]; } || return 1
	exec 3<"$1" || return 1
	if cfmgr_store_run store-flush "$cfmgr_store_fsync"; then cfmgr_store_flush_code=0; else cfmgr_store_flush_code=$?; fi
	exec 3<&-
	return "$cfmgr_store_flush_code"
}

cfmgr_store_cleanup() {
	cfmgr_store_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 1
	cfmgr_store_items=0
	for cfmgr_store_item in "$cfmgr_store_context"/*; do
		[ -e "$cfmgr_store_item" ] || continue
		[ -f "$cfmgr_store_item" ] && [ ! -L "$cfmgr_store_item" ] || return 1
		cfmgr_store_items=$((cfmgr_store_items + 1))
		[ "$cfmgr_store_items" -le 512 ] || return 1
	done
	for cfmgr_store_item in "$cfmgr_store_context"/*; do
		[ -f "$cfmgr_store_item" ] || continue
		/bin/rm -f "$cfmgr_store_item" || return 1
	done
	/bin/rmdir "$cfmgr_store_context" || return 1
	exec 4<&- 5<&- 8<&- 9<&-
}

cfmgr_store_setup_ok() {
	for cfmgr_store_blocker in entry.stage .setup.complete .storage-observation; do
		[ ! -e "$cfmgr_store_source/$cfmgr_store_blocker" ] && [ ! -L "$cfmgr_store_source/$cfmgr_store_blocker" ] || return 1
	done
	cfmgr_store_snapshot "$cfmgr_store_source/setup-state" || return $?
	[ "$cfmgr_store_snapshot_bytes" -le 128 ] || return 1
	cfmgr_store_read_line "$cfmgr_store_snapshot" || return 1
	[ "$cfmgr_store_line" = "CFMGR-SETUP 1 $CFMGR_VERSION complete" ]
}

cfmgr_store_work() {
	cfmgr_store_pending
	if [ "$cfmgr_store_operation" = read ]; then
		if cfmgr_store_setup_ok; then :; else
			[ "$?" != 3 ] || return 3
			cfmgr_store_pending=1
		fi
		cfmgr_store_snapshot "$cfmgr_store_live" || return $?
		cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_result='read'
		return 0
	fi
	if cfmgr_store_setup_ok; then :; else
		cfmgr_store_setup_code=$?
		[ "$cfmgr_store_setup_code" != 3 ] || return 3
		cfmgr_store_result=recovery cfmgr_store_pending=1
		return 1
	fi
	cfmgr_store_lock_acquire || return $?
	cfmgr_store_setup_ok || return $?
	cfmgr_store_digest_admit || return $?
	if [ "$cfmgr_store_operation" = recover ]; then
		cfmgr_store_recover
		return $?
	fi
	cfmgr_store_pending
	if [ "$cfmgr_store_pending" = 1 ]; then
		cfmgr_store_result=recovery
		return 1
	fi
	cfmgr_store_attempt=0
	while [ "$cfmgr_store_attempt" -lt 2 ]; do
		cfmgr_store_attempt=$((cfmgr_store_attempt + 1))
		cfmgr_store_snapshot "$cfmgr_store_live" || return $?
		cfmgr_store_base=$cfmgr_store_snapshot cfmgr_store_base_bytes=$cfmgr_store_snapshot_bytes
		cfmgr_store_flags "$cfmgr_store_base" "$cfmgr_store_base_bytes" || return $?
		cfmgr_store_base_generation=$cfmgr_store_generation
		cfmgr_store_digest "$cfmgr_store_base" || return $?
		cfmgr_store_base_sha=$cfmgr_store_digest_value
		cfmgr_store_parse settings-observe "$cfmgr_store_base" "$cfmgr_store_base_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_store_tag cfmgr_store_schema cfmgr_store_old cfmgr_store_new cfmgr_store_changed cfmgr_store_target_check cfmgr_store_target_auto cfmgr_store_target_dev cfmgr_store_input_bytes cfmgr_store_target_bytes cfmgr_store_end cfmgr_store_extra <<EOF_PATCH
$cfmgr_store_line
EOF_PATCH
		[ "$cfmgr_store_tag:$cfmgr_store_schema:$cfmgr_store_end:$cfmgr_store_extra" = CFMGR-SETTINGS-PATCH:1:END: ] &&
			[ "$cfmgr_store_old:$cfmgr_store_input_bytes" = "$cfmgr_store_base_generation:$cfmgr_store_base_bytes" ] || return 1
		case $cfmgr_store_changed:$cfmgr_store_target_check:$cfmgr_store_target_auto:$cfmgr_store_target_dev in [01]:[01]:[01]:[01]) ;; *) return 1 ;; esac
		case $cfmgr_store_new:$cfmgr_store_target_bytes in *[!0-9:]* | :* | *:) return 1 ;; esac
		[ "${#cfmgr_store_new}" -le 20 ] && [ "$cfmgr_store_target_bytes" -gt 0 ] && [ "$cfmgr_store_target_bytes" -le 65536 ] || return 1
		if [ "$cfmgr_store_changed" = 0 ]; then
			if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then :; else
				cfmgr_store_match_code=$?
				[ "$cfmgr_store_match_code" = 4 ] || return "$cfmgr_store_match_code"
				cfmgr_store_result=stale
				return 1
			fi
			cfmgr_store_result=unchanged
			return 0
		fi
		cfmgr_store_parse settings-patch "$cfmgr_store_base" "$cfmgr_store_base_bytes" || return $?
		cfmgr_store_candidate=$cfmgr_probe_stdout
		cfmgr_store_count "$cfmgr_store_candidate" || return $?
		[ "$cfmgr_store_bytes" = "$cfmgr_store_target_bytes" ] || return 1
		cfmgr_store_flags "$cfmgr_store_candidate" "$cfmgr_store_target_bytes" || return $?
		[ "$cfmgr_store_generation:$cfmgr_store_check:$cfmgr_store_auto:$cfmgr_store_developer" = "$cfmgr_store_new:$cfmgr_store_target_check:$cfmgr_store_target_auto:$cfmgr_store_target_dev" ] || return 1
		cfmgr_store_digest "$cfmgr_store_candidate" || return $?
		cfmgr_store_candidate_sha=$cfmgr_store_digest_value
		cfmgr_store_prepare_guard || return $?
		if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then
			cfmgr_store_publish
			return $?
		else
			cfmgr_store_stale_code=$?
			[ "$cfmgr_store_stale_code" = 4 ] || return "$cfmgr_store_stale_code"
			# Only this invocation's complete finite preparing directory is ours.
			cfmgr_store_remove_guard || return $?
			cfmgr_store_result=stale
		fi
	done
	return 1
}

cfmgr_store_live_matches() {
	cfmgr_store_expected_sha=$1 cfmgr_store_expected_bytes=$2
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_expected_bytes" ] || return 4
	cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
	[ "$cfmgr_store_digest_value" = "$cfmgr_store_expected_sha" ] || return 4
}

cfmgr_store_copy() {
	cfmgr_store_run store-copy "$cfmgr_store_cp" "$1" "$2" || return $?
	cfmgr_store_admit_private "$2" file || return 1
	cfmgr_store_flush "$2"
}

cfmgr_store_prepare_guard() {
	cfmgr_store_pending
	[ "$cfmgr_store_pending" = 0 ] || {
		cfmgr_store_result=recovery
		return 1
	}
	# Same-JFFS old/candidate plus erase-block and metadata allowance, before
	# creating persistent intent or any live change.
	cfmgr_store_space_needed=$(((cfmgr_store_base_bytes + cfmgr_store_target_bytes + 262144 + 1023) / 1024))
	cfmgr_store_run store-space /bin/df "$cfmgr_store_jffs" || return $?
	cfmgr_store_space_raw=$cfmgr_probe_stdout
	cfmgr_store_run store-space-frame "$cfmgr_store_awk" "$cfmgr_store_space_raw" "$cfmgr_store_space_needed" || return $?
	cfmgr_store_guard=$cfmgr_store_source/.config-save.preparing
	cfmgr_store_run store-mkdir /bin/mkdir "$cfmgr_store_guard" || return $?
	cfmgr_store_guard_owned=1 cfmgr_store_pending=1 cfmgr_store_result=recovery
	exec 4<"$cfmgr_store_guard" || return 3
	cfmgr_store_copy "$cfmgr_store_base" "$cfmgr_store_guard/old" || return $?
	cfmgr_store_copy "$cfmgr_store_candidate" "$cfmgr_store_guard/candidate" || return $?
	cfmgr_store_digest "$cfmgr_store_guard/old" || return $?
	[ "$cfmgr_store_digest_value" = "$cfmgr_store_base_sha" ] || return 1
	cfmgr_store_digest "$cfmgr_store_guard/candidate" || return $?
	[ "$cfmgr_store_digest_value" = "$cfmgr_store_candidate_sha" ] || return 1
	cfmgr_store_intent=$cfmgr_store_context/intent.$cfmgr_store_attempt
	(
		umask 077
		set -C
		printf 'CFMGR-SETTINGS-INTENT 1 %s %s %s %s %s %s END\n' "$cfmgr_store_base_generation" "$cfmgr_store_new" "$cfmgr_store_base_bytes" "$cfmgr_store_target_bytes" "$cfmgr_store_base_sha" "$cfmgr_store_candidate_sha" >"$cfmgr_store_intent"
	) || return 1
	cfmgr_store_copy "$cfmgr_store_intent" "$cfmgr_store_guard/intent" || return $?
	cfmgr_store_flush "$cfmgr_store_guard" && cfmgr_store_flush "$cfmgr_store_source"
}

cfmgr_store_move_guard() {
	[ ! -e "$2" ] && [ ! -L "$2" ] || return 1
	cfmgr_store_guard_next=$2
	if cfmgr_store_run store-move "$cfmgr_store_mv" "$1" "$2"; then cfmgr_store_move_code=0; else cfmgr_store_move_code=$?; fi
	[ "$cfmgr_store_move_code" = 0 ] || return "$cfmgr_store_move_code"
	cfmgr_store_guard=$2 cfmgr_store_guard_next=''
	cfmgr_store_flush "$cfmgr_store_source"
}

cfmgr_store_publish() {
	cfmgr_store_move_guard "$cfmgr_store_guard" "$cfmgr_store_source/.config-save" || return $?
	if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then :; else
		cfmgr_store_match_code=$?
		[ "$cfmgr_store_match_code" = 4 ] || return "$cfmgr_store_match_code"
		cfmgr_store_result=stale
		return 1
	fi
	cfmgr_store_admit_private "$cfmgr_store_live" file || return 1
	cfmgr_store_run store-move "$cfmgr_store_mv" "$cfmgr_store_guard/candidate" "$cfmgr_store_live" || return $?
	cfmgr_store_flush "$cfmgr_store_live" && cfmgr_store_flush "$cfmgr_store_source" || return $?
	cfmgr_store_live_matches "$cfmgr_store_candidate_sha" "$cfmgr_store_target_bytes" || return $?
	cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
	[ "$cfmgr_store_generation:$cfmgr_store_check:$cfmgr_store_auto:$cfmgr_store_developer" = "$cfmgr_store_new:$cfmgr_store_target_check:$cfmgr_store_target_auto:$cfmgr_store_target_dev" ] || return 1
	cfmgr_store_move_guard "$cfmgr_store_guard" "$cfmgr_store_source/.config-save.retired" || return $?
	cfmgr_store_remove_guard || return $?
	cfmgr_store_result=saved cfmgr_store_pending=0
}

cfmgr_store_remove_guard() {
	cfmgr_store_attachment_ok && cfmgr_store_admit_private "$cfmgr_store_guard" directory || return 1
	cfmgr_store_guard_inventory || return $?
	for cfmgr_store_guard_item in "$cfmgr_store_guard/old" "$cfmgr_store_guard/candidate" "$cfmgr_store_guard/intent"; do
		[ -e "$cfmgr_store_guard_item" ] || continue
		cfmgr_store_admit_private "$cfmgr_store_guard_item" file || return 1
		cfmgr_store_run store-remove /bin/rm "$cfmgr_store_guard_item" || return $?
	done
	cfmgr_store_retiring=1
	if cfmgr_store_run store-rmdir /bin/rmdir "$cfmgr_store_guard"; then cfmgr_store_retire_code=0; else cfmgr_store_retire_code=$?; fi
	cfmgr_store_retiring=0
	[ "$cfmgr_store_retire_code" = 0 ] || return "$cfmgr_store_retire_code"
	exec 4<&-
	cfmgr_store_guard_owned=0 cfmgr_store_pending=0
	cfmgr_store_flush "$cfmgr_store_source"
}

cfmgr_store_recover() {
	cfmgr_store_result=recovery
	[ ! -e "$cfmgr_store_source/.storage-observation" ] && [ ! -L "$cfmgr_store_source/.storage-observation" ] || return 1
	cfmgr_store_phase_count=0
	for cfmgr_store_phase in .config-save.preparing .config-save .config-save.retired; do
		if [ -e "$cfmgr_store_source/$cfmgr_store_phase" ] || [ -L "$cfmgr_store_source/$cfmgr_store_phase" ]; then
			cfmgr_store_phase_count=$((cfmgr_store_phase_count + 1))
			cfmgr_store_guard=$cfmgr_store_source/$cfmgr_store_phase
		fi
	done
	if [ "$cfmgr_store_phase_count" = 0 ]; then
		cfmgr_store_snapshot "$cfmgr_store_live" || return $?
		cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_result=unchanged cfmgr_store_pending=0
		return 0
	fi
	[ "$cfmgr_store_phase_count" = 1 ] && cfmgr_store_admit_private "$cfmgr_store_guard" directory || return 1
	exec 4<"$cfmgr_store_guard" || return 3
	cfmgr_store_guard_owned=1 cfmgr_store_pending=1
	cfmgr_store_guard_inventory || return $?
	if [ "$cfmgr_store_guard" = "$cfmgr_store_source/.config-save.retired" ]; then
		cfmgr_store_validate_retired || return $?
		cfmgr_store_remove_guard || return $?
	else
		cfmgr_store_snapshot "$cfmgr_store_guard/intent" || return $?
		cfmgr_store_run store-intent "$cfmgr_store_awk" "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_store_old cfmgr_store_new cfmgr_store_base_bytes cfmgr_store_target_bytes cfmgr_store_base_sha cfmgr_store_candidate_sha <<EOF_INTENT
$cfmgr_store_line
EOF_INTENT
		cfmgr_store_snapshot "$cfmgr_store_guard/old" || return $?
		[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_base_bytes" ] || return 1
		cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_base_bytes" || return $?
		[ "$cfmgr_store_generation" = "$cfmgr_store_old" ] || return 1
		cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
		[ "$cfmgr_store_digest_value" = "$cfmgr_store_base_sha" ] || return 1
		if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then
			# Never replay a candidate when live remains the exact old generation.
			cfmgr_store_snapshot "$cfmgr_store_guard/candidate" || return $?
			[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_target_bytes" ] || return 1
			cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
			[ "$cfmgr_store_generation" = "$cfmgr_store_new" ] || return 1
			cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
			[ "$cfmgr_store_digest_value" = "$cfmgr_store_candidate_sha" ] || return 1
		elif [ "$?" = 3 ]; then
			return 3
		elif cfmgr_store_live_matches "$cfmgr_store_candidate_sha" "$cfmgr_store_target_bytes"; then
			cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
			[ "$cfmgr_store_generation" = "$cfmgr_store_new" ] || return 1
			cfmgr_store_flush "$cfmgr_store_live" && cfmgr_store_flush "$cfmgr_store_source" || return $?
		else
			[ "$?" != 3 ] || return 3
			return 1
		fi
		cfmgr_store_move_guard "$cfmgr_store_guard" "$cfmgr_store_source/.config-save.retired" || return $?
		cfmgr_store_remove_guard || return $?
	fi
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
	cfmgr_store_result=recovered cfmgr_store_pending=0
}

cfmgr_store_guard_inventory() {
	cfmgr_store_guard_count=0
	for cfmgr_store_guard_item in "$cfmgr_store_guard"/* "$cfmgr_store_guard"/.[!.]* "$cfmgr_store_guard"/..?*; do
		[ -e "$cfmgr_store_guard_item" ] || [ -L "$cfmgr_store_guard_item" ] || continue
		case ${cfmgr_store_guard_item##*/} in old | candidate | intent) ;; *) return 1 ;; esac
		cfmgr_store_admit_private "$cfmgr_store_guard_item" file || return 1
		cfmgr_store_count "$cfmgr_store_guard_item" || return $?
		cfmgr_store_guard_count=$((cfmgr_store_guard_count + 1))
		[ "$cfmgr_store_guard_count" -le 3 ] || return 1
	done
}

cfmgr_store_validate_retired() {
	# Validate current state before discarding any recovery payload. A complete
	# intent must bind live exactly; only an empty retired directory can lack an
	# intent (our fixed cleanup order removes intent last). Nonempty partial or
	# alien evidence is preserved rather than guessed.
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	cfmgr_store_retired_live=$cfmgr_store_snapshot cfmgr_store_retired_bytes=$cfmgr_store_snapshot_bytes
	cfmgr_store_flags "$cfmgr_store_retired_live" "$cfmgr_store_retired_bytes" || return $?
	cfmgr_store_retired_generation=$cfmgr_store_generation
	cfmgr_store_digest "$cfmgr_store_retired_live" || return $?
	cfmgr_store_retired_sha=$cfmgr_store_digest_value
	if [ -e "$cfmgr_store_guard/intent" ]; then
		cfmgr_store_snapshot "$cfmgr_store_guard/intent" || return $?
		cfmgr_store_run store-intent "$cfmgr_store_awk" "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_store_old cfmgr_store_new cfmgr_store_base_bytes cfmgr_store_target_bytes cfmgr_store_base_sha cfmgr_store_candidate_sha <<EOF_RETIRED
$cfmgr_store_line
EOF_RETIRED
		case $cfmgr_store_retired_sha:$cfmgr_store_retired_bytes:$cfmgr_store_retired_generation in
		"$cfmgr_store_base_sha:$cfmgr_store_base_bytes:$cfmgr_store_old" | "$cfmgr_store_candidate_sha:$cfmgr_store_target_bytes:$cfmgr_store_new") ;;
		*) return 1 ;;
		esac
		for cfmgr_store_retired_item in old candidate; do
			[ -e "$cfmgr_store_guard/$cfmgr_store_retired_item" ] || continue
			case $cfmgr_store_retired_item in
			old) cfmgr_store_retired_item_sha=$cfmgr_store_base_sha cfmgr_store_retired_item_bytes=$cfmgr_store_base_bytes cfmgr_store_retired_item_gen=$cfmgr_store_old ;;
			candidate) cfmgr_store_retired_item_sha=$cfmgr_store_candidate_sha cfmgr_store_retired_item_bytes=$cfmgr_store_target_bytes cfmgr_store_retired_item_gen=$cfmgr_store_new ;;
			esac
			cfmgr_store_snapshot "$cfmgr_store_guard/$cfmgr_store_retired_item" || return $?
			[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_retired_item_bytes" ] || return 1
			cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
			[ "$cfmgr_store_generation" = "$cfmgr_store_retired_item_gen" ] || return 1
			cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
			[ "$cfmgr_store_digest_value" = "$cfmgr_store_retired_item_sha" ] || return 1
		done
	else [ "$cfmgr_store_guard_count" = 0 ] || return 1; fi
	cfmgr_store_flush "$cfmgr_store_live" && cfmgr_store_flush "$cfmgr_store_source" || return $?
	cfmgr_store_live_matches "$cfmgr_store_retired_sha" "$cfmgr_store_retired_bytes"
}

# Operational observation borrows its already-admitted native context/FD pins;
# it retains the original publication transaction and existing Entware fallback.
cfmgr_config_store_observation_lock() {
	cfmgr_store_source=$cfmgr_install_source cfmgr_store_jffs=$cfmgr_install_jffs cfmgr_store_ram=/tmp/cfmgr
	cfmgr_store_context=$cfmgr_install_context cfmgr_store_context_fd=$cfmgr_install_context_fd
	cfmgr_store_lock=$cfmgr_store_ram/config.lock cfmgr_store_borrowed=1 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0
	cfmgr_store_jffs_mount=$cfmgr_install_jffs_snapshot cfmgr_store_tmp_mount=$cfmgr_install_tmp_snapshot
	cfmgr_store_sh=$cfmgr_install_sh cfmgr_store_env=$cfmgr_install_env cfmgr_store_awk=$cfmgr_install_awk
	cfmgr_store_sleep=$cfmgr_install_sleep cfmgr_store_wc=$cfmgr_install_wc cfmgr_store_ls=$cfmgr_install_ls cfmgr_store_readlink=$cfmgr_install_readlink
	cfmgr_store_result=unavailable cfmgr_config_lock_fd0=0 cfmgr_store_flock_entware=0 cfmgr_store_flock=/usr/bin/flock
	case ${cfmgr_prereq_flock_provider:-none} in
	native) ;;
	entware) cfmgr_store_flock_entware=1 cfmgr_store_flock=/opt/bin/flock ;;
	*) return 1 ;;
	esac
	cfmgr_store_admit_private "$cfmgr_store_ram" directory || return 1
	cfmgr_prerequisites_now || return 1
	cfmgr_store_deadline=$((cfmgr_probe_now + 20))
	cfmgr_store_lock_acquire || return $?
	cfmgr_store_pending
	[ "$cfmgr_store_pending" = 0 ]
}
