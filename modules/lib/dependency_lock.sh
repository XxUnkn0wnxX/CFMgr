#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only cooperative dependency exclusion; no worker or storage admission.
# ROOT and its ancestors are trusted private RAM, stable for every holder's
# lifetime. Never replace/unlink dependencies.lock while any holder remains.
# FD7 is inherited by cooperative children. Closing this owner's copy does not
# release their copies; arbitrary child completion/FD retention is not proved.
# Caller tracing must already be off before passing arguments.
# Owner state is inherited by its fixed retained-descriptor helper.
# shellcheck disable=SC2030,SC2031

cfmgr_dependency_lock_with() {
	_cfmgr_dependency_lock_owner production "$@" >/dev/null 2>&1
}

# Explicit trusted fixture API: ROOT FLOCK_EXECUTABLE CALLBACK [ARGS...].
cfmgr_dependency_lock_with_test() {
	_cfmgr_dependency_lock_owner fixture "$@" >/dev/null 2>&1
}

_cfmgr_dependency_lock_owner() (
	set +x
	set +e
	set +u
	set -f
	trap - 0 HUP INT TERM
	IFS=' 	'
	IFS="${IFS}
"
	umask 077
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	export PATH LC_ALL
	unset ENV BASH_ENV CDPATH LD_LIBRARY_PATH LD_PRELOAD
	[ "$#" -ge 1 ] || return 2
	_dependency_lock_mode=$1
	shift
	case $_dependency_lock_mode in
	production)
		[ "$#" -ge 2 ] || return 2
		_dependency_lock_root=$1
		shift
		_dependency_lock_flock=
		;;
	fixture)
		[ "$#" -ge 3 ] || return 2
		_dependency_lock_root=$1
		_dependency_lock_flock=$2
		_cfmgr_dependency_lock_path "$_dependency_lock_flock" || return 2
		shift 2
		;;
	*) return 2 ;;
	esac
	_cfmgr_dependency_lock_path "$_dependency_lock_root" || return 2
	[ "$_dependency_lock_root" != / ] || return 2
	case $1 in '' | [!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 2 ;; esac
	[ -d "$_dependency_lock_root" ] && [ ! -L "$_dependency_lock_root" ] || return 1
	_dependency_lock_file=${_dependency_lock_root%/}/dependencies.lock
	[ ! -L "$_dependency_lock_file" ] || return 1
	[ ! -e "$_dependency_lock_file" ] || [ -f "$_dependency_lock_file" ] || return 1
	if [ "$_dependency_lock_mode" = production ]; then
		for _dependency_lock_candidate in /usr/bin/flock /bin/flock /sbin/flock /usr/sbin/flock; do
			if [ -f "$_dependency_lock_candidate" ] && [ -x "$_dependency_lock_candidate" ]; then
				_dependency_lock_flock=$_dependency_lock_candidate
				break
			fi
		done
	fi
	[ -n "$_dependency_lock_flock" ] && [ -f "$_dependency_lock_flock" ] && [ -x "$_dependency_lock_flock" ] || return 1
	_dependency_lock_entered=0
	_cfmgr_dependency_lock_retained "$@" 7>>"$_dependency_lock_file"
	_dependency_lock_status=$?
	[ "$_dependency_lock_entered" -eq 1 ] || return 1
	return "$_dependency_lock_status"
)

_cfmgr_dependency_lock_path() (
	[ "$#" -eq 1 ] && [ "${#1}" -le 4096 ] || return 2
	case $1 in /) return 0 ;; /*) ;; *) return 2 ;; esac
	case $1 in *[[:cntrl:]]* | *//* | */./* | */../* | */. | */.. | */) return 2 ;; esac
)

_cfmgr_dependency_lock_retained() {
	_dependency_lock_entered=1
	"$_dependency_lock_flock" -n 7
	_dependency_lock_status=$?
	case $_dependency_lock_status in
	0) ;;
	*)
		[ "$_dependency_lock_status" -le 128 ] && return 1
		return 129
		;;
	esac
	_dependency_lock_callback=$1
	shift
	"$_dependency_lock_callback" "$@"
}
