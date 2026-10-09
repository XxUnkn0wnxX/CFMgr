#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only fixed native probe composition. All trusted dependencies are
# explicitly sourced by the caller. No CLI, payload, opkg or network authority.
# Caller owns private reserved RAM/guard, immutable code, frozen aliases,
# independently selected storage authority and a dedicated cron process group.
# No application FD above9 may be inherited. Guard/evidence are never reused.
# The private callbacks inherit only their isolated composition owner's state.
# shellcheck disable=SC2030,SC2031,SC2154

# Keep this a normal function: the public deadline entry must inspect the
# original shell's process-group identity before it forks the deadline owner.
cfmgr_worker_native_probe() {
	if _cfmgr_worker_native_probe_api "$@"; then :; else
		case $? in 2) return 2 ;; *) return 129 ;; esac
	fi
	if cfmgr_worker_deadline_with "$2" "$3" "$4" _cfmgr_worker_native_probe_run "$@"; then
		if _cfmgr_worker_native_probe_result "$2"; then return 0; else return 129; fi
	else
		case $? in
		1)
			if _cfmgr_worker_native_probe_result "$2"; then return 129; else
				case $? in 1) return 1 ;; *) return 129 ;; esac
			fi
			;;
		*) return 129 ;;
		esac
	fi
}

_cfmgr_worker_native_probe_api() (
	set +x
	set +e
	set +u
	set -f
	_cfmgr_worker_native_environment
	[ "$#" -eq 10 ] || return 2
	_cfmgr_worker_deadline_api "$2" "$3" "$4" _cfmgr_worker_native_probe_run || return 2
	for _native_probe_path in "$1" "$2" "$7" "$8"; do
		_cfmgr_isolation_path "$_native_probe_path" && [ "$_native_probe_path" != / ] || return 2
	done
	_cfmgr_native_config_directory "$1" && _cfmgr_native_config_directory "$2" || return 2
	[ "${2%/*}" = "$1" ] || return 2
	[ -f "$7" ] && [ ! -L "$7" ] && [ -r "$7" ] &&
		[ -f "$8" ] && [ ! -L "$8" ] && [ -r "$8" ] || return 2
	_cfmgr_isolation_tmp_limits "$5" "$6" && _cfmgr_entware_uuid "$9" || return 2
	[ "${#10}" -le 8192 ] && _cfmgr_io_hex_path "${10}" || return 2
	_cfmgr_worker_native_probe_fresh "$2" deadline execution probe-success probe-negative root-returned || return 129
) >/dev/null 2>&1

_cfmgr_worker_native_probe_fresh() (
	_native_probe_guard=$1
	shift
	for _native_probe_name; do
		case $_native_probe_name in deadline | execution | probe-success | probe-negative | root-returned) ;; *) return 129 ;; esac
		[ ! -e "$_native_probe_guard/$_native_probe_name" ] &&
			[ ! -L "$_native_probe_guard/$_native_probe_name" ] || return 129
	done
)

_cfmgr_worker_native_probe_result() (
	set +x
	set +e
	set +u
	set -f
	_cfmgr_worker_native_environment
	[ "$#" -eq 1 ] || return 129
	_cfmgr_isolation_root_empty "$1/root-returned" || return 129
	if [ -e "$1/probe-success" ] || [ -L "$1/probe-success" ]; then
		_cfmgr_worker_native_probe_fresh "$1" probe-negative &&
			_cfmgr_isolation_root_empty "$1/probe-success" || return 129
		return 0
	fi
	_cfmgr_worker_native_probe_fresh "$1" probe-success &&
		_cfmgr_isolation_root_empty "$1/probe-negative" || return 129
	return 1
) >/dev/null 2>&1

_cfmgr_worker_native_probe_mkdir() (
	_cfmgr_worker_native_environment
	for _native_probe_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -f "$_native_probe_dir/mkdir" ] && [ -x "$_native_probe_dir/mkdir" ]; then
			printf '%s/mkdir\n' "$_native_probe_dir"
			return
		fi
	done
	return 129
)

_cfmgr_worker_native_probe_publish() {
	[ "$#" -eq 2 ] || return 129
	case $2 in probe-success | probe-negative | root-returned) ;; *) return 129 ;; esac
	_cfmgr_worker_native_probe_fresh "$1" "$2" || return 129
	"$_native_probe_mkdir" -m 700 "$1/$2" || return 129
	_cfmgr_isolation_root_empty "$1/$2" || return 129
}

_cfmgr_worker_native_probe_run() (
	set +x
	set +e
	set +u
	set +C
	set -f
	trap - 0 HUP INT QUIT TERM
	trap 'exit 129' HUP INT QUIT TERM
	_native_probe_complete=0
	trap '_cfmgr_worker_native_probe_exit "$?"' 0
	_cfmgr_worker_native_environment
	IFS=' 	'
	IFS="${IFS}
"
	umask 077
	[ "$#" -eq 10 ] || return 129
	_cfmgr_isolation_root_empty "$2/deadline/armed" || return 129
	_cfmgr_worker_native_probe_fresh "$2" execution probe-success probe-negative root-returned || return 129
	_native_probe_mkdir=$(_cfmgr_worker_native_probe_mkdir) || return 129
	if cfmgr_entware_with "$1" "$7" "$8" "$9" "${10}" _cfmgr_worker_native_probe_storage \
		"$1" "$2" "$5" "$6" "$7" "$8"; then :; else return 129; fi
	_cfmgr_worker_native_probe_result "$2"
	_native_probe_result=$?
	case $_native_probe_result in 0 | 1) ;; *) return 129 ;; esac
	_native_probe_complete=1
	return "$_native_probe_result"
) >/dev/null 2>&1

_cfmgr_worker_native_probe_storage() {
	# Original retained FD8/9 and the exact checked target/ledger are forwarded.
	[ "$#" -eq 8 ] || return 129
	if cfmgr_isolation_native_config_root_with "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" \
		_cfmgr_worker_native_probe_root "$4"; then :; else return 129; fi
	_cfmgr_worker_native_probe_publish "$4" root-returned
}

_cfmgr_worker_native_probe_root() {
	# Native-config owner prepends ROOT, root ledger and retained-volume ledger.
	[ "$#" -eq 4 ] || return 129
	_cfmgr_worker_native_probe_fresh "$4" probe-success probe-negative root-returned || return 129
	cfmgr_native_shell_probe "$1"
	case $? in
	0) _cfmgr_worker_native_probe_publish "$4" probe-success || return 129 ;;
	1) _cfmgr_worker_native_probe_publish "$4" probe-negative || return 129 ;;
	*) return 129 ;;
	esac
	# A completed negative probe is still a normally completed root callback.
	return 0
}

_cfmgr_worker_native_probe_exit() {
	_native_probe_exit=$1
	trap - 0
	if [ "$_native_probe_complete" -ne 1 ] || [ "$_native_probe_exit" -gt 128 ]; then
		_native_probe_exit=129
	fi
	exit "$_native_probe_exit"
}
