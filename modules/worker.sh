#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only top-level process-group admission for a trusted cron entry.
# This is a read-only snapshot, not worker launch, supervision or kill authority.
# Caller tracing must already be off. No ambient proc path or fixture API exists.

cfmgr_worker_group_check() {
	[ "$#" -eq 0 ] || return 2
	_cfmgr_worker_read_current 2>/dev/null 6</proc/self/stat
}

# Called in the original shell with function-scoped FD6. Keep the first proc
# read in that process; a forked shell would have a different /proc/self record.
_cfmgr_worker_read_current() {
	_worker_self_pid=$$
	_worker_stat_record=
	_worker_stat_extra=
	if IFS= read -r _worker_stat_record <&6; then :; else return 1; fi
	if IFS= read -r _worker_stat_extra <&6; then return 1; fi
	[ -z "$_worker_stat_extra" ] || return 1
	[ "${#_worker_stat_record}" -le 4096 ] || return 1
	_cfmgr_worker_stat_admitted "$_worker_stat_record" "$_worker_self_pid"
}

# Linux prints comm without escaping it. Use the last closing delimiter because
# the command name may contain spaces or parentheses.
_cfmgr_worker_stat_admitted() (
	[ "$#" -eq 2 ] || return 1
	LC_ALL=C
	export LC_ALL
	IFS=' '
	set -f
	_worker_stat_record=$1
	_worker_expected_pid=$2
	[ "${#_worker_stat_record}" -le 4096 ] || return 1
	_worker_lf='
'
	case $_worker_stat_record in *"$_worker_lf"*) return 1 ;; esac
	case $_worker_stat_record in *" ("*) ;; *) return 1 ;; esac
	_worker_stat_pid=${_worker_stat_record%% *}
	_cfmgr_worker_pid_valid "$_worker_stat_pid" || return 1
	_cfmgr_worker_pid_valid "$_worker_expected_pid" || return 1
	_worker_stat_rest=${_worker_stat_record#* }
	case $_worker_stat_rest in \(*) ;; *) return 1 ;; esac
	case $_worker_stat_rest in *\)\ *) ;; *) return 1 ;; esac
	_worker_stat_tail=${_worker_stat_rest##*\) }
	# Fields 3 through 24 provide state, group, and a real stat suffix.
	# Remaining kernel fields are not selectors for this admission.
	# shellcheck disable=SC2086
	set -- $_worker_stat_tail
	[ "$#" -ge 22 ] || return 1
	case $1 in R | S | D | Z | T | t | X | x | K | W | P | I) ;; *) return 1 ;; esac
	_worker_stat_group=$3
	_cfmgr_worker_pid_valid "$_worker_stat_group" || return 1
	[ "$_worker_stat_pid" = "$_worker_expected_pid" ] &&
		[ "$_worker_stat_group" = "$_worker_expected_pid" ]
)

_cfmgr_worker_pid_valid() {
	[ "$#" -eq 1 ] || return 1
	case $1 in '' | 0 | 0* | *[!0123456789]*) return 1 ;; esac
	case ${#1} in
	1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9) return 0 ;;
	10)
		case $1 in
		1????????? | 20???????? | 21[0-3]??????? | 214[0-6]?????? | 2147[0-3]????? | \
			21474[0-7]???? | 214748[0-2]??? | 2147483[0-5]?? | 21474836[0-3]? | 214748364[0-7])
			return 0
			;;
		esac
		;;
	esac
	return 1
}
