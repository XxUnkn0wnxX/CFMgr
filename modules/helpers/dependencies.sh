#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only fixed dependency worker; explicitly source trusted io/isolation/
# native-config/Entware/native-dependencies/dependency-lock/worker libraries.
# Caller owns a dedicated cron group, immutable code and storage authority,
# stable private RAM/guard, frozen aliases and no application descriptor above9.
# The lock/active marker coordinate CFMgr only. Normal opkg/script behavior is
# accepted; no rollback, descendant-quiescence or absolute kill claim is added.
# Guard/evidence are retained. No marker recovery, CLI or retry policy exists.
# shellcheck disable=SC2030,SC2031,SC2154

# Keep admission in the actual original shell, before the isolated owner forks.
cfmgr_worker_dependencies() {
	_cfmgr_worker_dependencies_api "$@" || return "$?"
	[ "$$" -ne 1 ] || return 1
	# shellcheck disable=SC2119
	cfmgr_worker_group_check || return 1
	# Conditional context also contains fatal owner redirections and premature
	# zero exits. API2 is possible only from the original validation above.
	if _cfmgr_worker_dependencies_owner "$$" "$@"; then return 129; else
		case $? in
		16) return 0 ;;
		17 | 1) return 1 ;;
		*) return 129 ;;
		esac
	fi
}

_cfmgr_worker_dependencies_api() (
	set +x
	set +e
	set +u
	set -f
	_cfmgr_worker_native_environment
	[ "$#" -eq 14 ] || return 2
	_cfmgr_worker_deadline_api "$2" "$3" "$4" _cfmgr_worker_dependencies_run || return 2
	for _dependencies_path in "$1" "$2" "$7" "$8" "${11}"; do
		_cfmgr_isolation_path "$_dependencies_path" && [ "$_dependencies_path" != / ] || return 2
	done
	_cfmgr_native_config_directory "$1" && _cfmgr_native_config_directory "$2" || return 2
	[ "${2%/*}" = "$1" ] || return 2
	[ -f "$7" ] && [ ! -L "$7" ] && [ -r "$7" ] &&
		[ -f "$8" ] && [ ! -L "$8" ] && [ -r "$8" ] || return 2
	_cfmgr_isolation_tmp_limits "$5" "$6" && _cfmgr_entware_uuid "$9" || return 2
	[ "${#10}" -le 8192 ] && _cfmgr_io_hex_path "${10}" || return 2
	case ${12} in repair | reinstall) ;; *) return 2 ;; esac
	case ${13} in shared | tunnel) ;; *) return 2 ;; esac
	case ${14} in native | entware) ;; *) return 2 ;; esac
	[ -f "${11}" ] && [ ! -L "${11}" ] && [ -r "${11}" ] || return 1
	_cfmgr_worker_dependencies_fresh "$2" deadline execution dependencies-result root-returned storage-returned
) >/dev/null 2>&1

_cfmgr_worker_dependencies_fresh() (
	_dependencies_guard=$1
	shift
	for _dependencies_name; do
		case $_dependencies_name in deadline | execution | dependencies-result | root-returned | storage-returned) ;; *) return 129 ;; esac
		[ ! -e "$_dependencies_guard/$_dependencies_name" ] &&
			[ ! -L "$_dependencies_guard/$_dependencies_name" ] || return 129
	done
)

_cfmgr_worker_dependencies_tools() {
	# Ignore ambient fixture selectors; the production entry resolves fixed tools.
	_io_tools=''
	_io_lf='
'
	_io_tab='	'
	_io_wc=$(_cfmgr_io_find wc) && _isolation_printf=$(_cfmgr_io_find printf) &&
		_dependencies_mkdir=$(_cfmgr_io_find mkdir) && _dependencies_rm=$(_cfmgr_io_find rm) &&
		_dependencies_rmdir=$(_cfmgr_io_find rmdir)
}

_cfmgr_worker_dependencies_owner() (
	set +x
	set +e
	set +u
	set +C
	set -f
	_dependencies_owner_complete=0 _dependencies_owner_latched=129
	trap '_cfmgr_worker_dependencies_owner_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	_cfmgr_worker_native_environment
	IFS=' 	'
	IFS="${IFS}
"
	umask 077
	# Permanent exec detachment precedes opening lock FD7. Function redirections
	# would leave ash's saved caller descriptors alive under high aliases.
	exec 0</dev/null 1>/dev/null 2>/dev/null 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<&-
	[ "$#" -eq 15 ] || return 129
	if cd / && _cfmgr_worker_dependencies_tools; then :; else
		_dependencies_owner_latched=1 _dependencies_owner_complete=1
		return 1
	fi
	cfmgr_dependency_lock_with "$2" _cfmgr_worker_dependencies_locked "$@"
	_dependencies_owner_status=$?
	# No filesystem read or launch follows the locked release commit point.
	case $_dependencies_owner_status in
	16 | 17 | 1)
		_dependencies_owner_latched=$_dependencies_owner_status _dependencies_owner_complete=1
		return "$_dependencies_owner_latched"
		;;
	*) return 129 ;;
	esac
)

_cfmgr_worker_dependencies_owner_exit() {
	_dependencies_owner_exit=$1
	trap - 0
	case $_dependencies_owner_latched in 1 | 16 | 17) ;; *) _dependencies_owner_complete=0 ;; esac
	if [ "$_dependencies_owner_complete" -ne 1 ] ||
		[ "$_dependencies_owner_exit" -ne "$_dependencies_owner_latched" ]; then
		_dependencies_owner_exit=129
	fi
	exit "$_dependencies_owner_exit"
}

# Existing exact framing rejects NULs, partial records and extra LF records.
# Check the bounded byte count before read allocates any record content.
_cfmgr_worker_dependencies_record() {
	[ "$#" -eq 2 ] || return 129
	_dependencies_record_size=$(_cfmgr_io_size "$1") || return 129
	[ "$_dependencies_record_size" -eq "${#2}" ] || return 129
	_cfmgr_isolation_read "$1" && [ "$_isolation_text" = "$2" ] || return 129
}

_cfmgr_worker_dependencies_helper_result() {
	[ "$#" -eq 5 ] || return 129
	case $5 in 0 | 1) ;; *) return 129 ;; esac
	_cfmgr_isolation_root_empty "$1/execution/dependencies/complete" &&
		_cfmgr_worker_dependencies_record "$1/execution/dependencies/status" \
			"dependencies $2 $3 $4 $5$_io_lf" || return 129
}

_cfmgr_worker_dependencies_result() {
	[ "$#" -eq 4 ] || return 129
	_dependencies_result_size=$(_cfmgr_io_size "$1/dependencies-result") || return 129
	[ "$_dependencies_result_size" -le 64 ] || return 129
	_cfmgr_isolation_read "$1/dependencies-result" || return 129
	case $_isolation_text in
	"CFMGR_WORKER_DEPENDENCIES_V1 0$_io_lf") _dependencies_outcome=0 ;;
	"CFMGR_WORKER_DEPENDENCIES_V1 1$_io_lf") _dependencies_outcome=1 ;;
	*) return 129 ;;
	esac
	_cfmgr_worker_dependencies_helper_result "$@" "$_dependencies_outcome" &&
		_cfmgr_isolation_root_empty "$1/execution/complete" &&
		_cfmgr_isolation_root_empty "$1/root-returned" &&
		_cfmgr_isolation_root_empty "$1/storage-returned" || return 129
}

_cfmgr_worker_dependencies_active() (
	[ "$#" -eq 2 ] || return 129
	_dependencies_active=$1/dependencies.active
	_cfmgr_native_config_directory "$_dependencies_active" || return 129
	_cfmgr_worker_dependencies_record "$_dependencies_active/owner" \
		"CFMGR_DEPENDENCIES_OWNER_V1$_io_lf$2$_io_lf" || return 129
	set +f
	for _dependencies_entry in "$_dependencies_active"/* "$_dependencies_active"/.[!.]* "$_dependencies_active"/..?*; do
		[ "$_dependencies_entry" = "$_dependencies_active/owner" ] && continue
		[ ! -e "$_dependencies_entry" ] && [ ! -L "$_dependencies_entry" ] || return 129
	done
)

_cfmgr_worker_dependencies_publish() {
	[ "$#" -eq 2 ] || return 129
	case $2 in root-returned | storage-returned) ;; *) return 129 ;; esac
	_cfmgr_worker_dependencies_fresh "$1" "$2" &&
		"$_dependencies_mkdir" -m 700 "$1/$2" &&
		_cfmgr_isolation_root_empty "$1/$2" || return 129
}

_cfmgr_worker_dependencies_locked() (
	set +x
	set +e
	set +u
	set +C
	set -f
	_dependencies_locked_complete=0 _dependencies_latched=129
	trap '_cfmgr_worker_dependencies_locked_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	[ "$#" -eq 15 ] || return 129
	_dependencies_leader=$1
	shift
	_dependencies_active=$1/dependencies.active
	[ ! -e "$_dependencies_active" ] && [ ! -L "$_dependencies_active" ] || return 129
	_cfmgr_worker_deadline_owner "$_dependencies_leader" "$2" "$3" "$4" \
		_cfmgr_worker_dependencies_run "$@"
	_dependencies_deadline_status=$?
	[ "$_dependencies_deadline_status" -eq 0 ] || return 129
	_cfmgr_isolation_root_empty "$2/deadline/done" &&
		_cfmgr_isolation_root_empty "$2/deadline/ack" || return 129
	for _dependencies_marker in cancel expired; do
		[ ! -e "$2/deadline/$_dependencies_marker" ] && [ ! -L "$2/deadline/$_dependencies_marker" ] || return 129
	done
	_cfmgr_worker_dependencies_result "$2" "${12}" "${13}" "${14}" &&
		_cfmgr_worker_dependencies_active "$1" "$2" || return 129
	# Validate every fallible fact before release. Remove only our exact record,
	# never recursively delete evidence or replace/unlink dependencies.lock.
	_dependencies_latched=$((16 + _dependencies_outcome))
	"$_dependencies_rm" "$_dependencies_active/owner" || return 129
	"$_dependencies_rmdir" "$_dependencies_active" || return 129
	# Successful rmdir commits release. A later signal may lose delivery but
	# cannot authorize another launch or imply resources were not completed.
	_dependencies_locked_complete=1
	return "$_dependencies_latched"
)

_cfmgr_worker_dependencies_locked_exit() {
	_dependencies_locked_exit=$1
	trap - 0
	case $_dependencies_latched in 16 | 17) ;; *) _dependencies_locked_complete=0 ;; esac
	if [ "$_dependencies_locked_complete" -ne 1 ] ||
		[ "$_dependencies_locked_exit" -ne "$_dependencies_latched" ]; then
		_dependencies_locked_exit=129
	fi
	exit "$_dependencies_locked_exit"
}

_cfmgr_worker_dependencies_run() (
	set +x
	set +e
	set +u
	set +C
	set -f
	_dependencies_run_complete=0
	trap '_cfmgr_worker_dependencies_run_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	[ "$#" -eq 14 ] || return 129
	_cfmgr_isolation_root_empty "$2/deadline/armed" || return 129
	_cfmgr_worker_dependencies_fresh "$2" execution dependencies-result root-returned storage-returned || return 129
	_dependencies_active=$1/dependencies.active
	[ ! -e "$_dependencies_active" ] && [ ! -L "$_dependencies_active" ] || return 129
	"$_dependencies_mkdir" -m 700 "$_dependencies_active" || return 129
	_cfmgr_native_config_directory "$_dependencies_active" &&
		_cfmgr_isolation_root_empty "$_dependencies_active" || return 129
	_cfmgr_isolation_write "$_dependencies_active/owner" \
		"CFMGR_DEPENDENCIES_OWNER_V1$_io_lf$2$_io_lf" || return 129
	cfmgr_entware_with "$1" "$7" "$8" "$9" "${10}" _cfmgr_worker_dependencies_storage \
		"$1" "$2" "$5" "$6" "$7" "$8" "${11}" "${12}" "${13}" "${14}"
	_dependencies_storage_status=$?
	[ "$_dependencies_storage_status" -eq 0 ] || return 129
	_cfmgr_worker_dependencies_publish "$2" storage-returned &&
		_cfmgr_worker_dependencies_result "$2" "${12}" "${13}" "${14}" || return 129
	_dependencies_run_complete=1
	return 0
)

_cfmgr_worker_dependencies_run_exit() {
	_dependencies_run_exit=$1
	trap - 0
	[ "$_dependencies_run_complete" -eq 1 ] && [ "$_dependencies_run_exit" -eq 0 ] || _dependencies_run_exit=129
	exit "$_dependencies_run_exit"
}

_cfmgr_worker_dependencies_storage() (
	set +x
	set +e
	set +u
	_dependencies_storage_complete=0
	trap '_cfmgr_worker_dependencies_storage_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	[ "$#" -eq 12 ] || return 129
	cfmgr_isolation_native_config_root_with "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" \
		_cfmgr_worker_dependencies_root "$4" "$9" "${10}" "${11}" "${12}"
	_dependencies_root_status=$?
	[ "$_dependencies_root_status" -eq 0 ] || return 129
	_cfmgr_worker_dependencies_publish "$4" root-returned || return 129
	_dependencies_storage_complete=1
	return 0
)

_cfmgr_worker_dependencies_storage_exit() {
	_dependencies_storage_exit=$1
	trap - 0
	[ "$_dependencies_storage_complete" -eq 1 ] && [ "$_dependencies_storage_exit" -eq 0 ] || _dependencies_storage_exit=129
	exit "$_dependencies_storage_exit"
}

_cfmgr_worker_dependencies_root() (
	set +x
	set +e
	set +u
	_dependencies_root_complete=0
	trap '_cfmgr_worker_dependencies_root_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	[ "$#" -eq 8 ] || return 129
	_cfmgr_worker_dependencies_fresh "$4" dependencies-result root-returned storage-returned || return 129
	cfmgr_native_dependencies "$1" "$5" "$6" "$7" "$8"
	_dependencies_backend_status=$?
	case $_dependencies_backend_status in 0 | 1) ;; *) return 129 ;; esac
	_cfmgr_worker_dependencies_helper_result "$4" "$6" "$7" "$8" "$_dependencies_backend_status" || return 129
	_cfmgr_isolation_write "$4/dependencies-result" \
		"CFMGR_WORKER_DEPENDENCIES_V1 $_dependencies_backend_status$_io_lf" || return 129
	_dependencies_root_complete=1
	return 0
)

_cfmgr_worker_dependencies_root_exit() {
	_dependencies_root_exit=$1
	trap - 0
	[ "$_dependencies_root_complete" -eq 1 ] && [ "$_dependencies_root_exit" -eq 0 ] || _dependencies_root_exit=129
	exit "$_dependencies_root_exit"
}
