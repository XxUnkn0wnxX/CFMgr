#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only native group admission and deadline for a trusted cron entry.
# Group checks are read-only snapshots; only the dedicated deadline entry may
# supervise/signal its group. Neither API admits an Entware or private-root job.
# Caller tracing must already be off. No ambient proc path or fixture API exists.
# The fixed watchdog deliberately inherits its isolated owner's private state.
# shellcheck disable=SC2030,SC2031

_cfmgr_worker_native_environment() {
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	export PATH LC_ALL
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
}

# The public snapshot has a deliberately empty argument list.
# shellcheck disable=SC2120
cfmgr_worker_group_check() {
	case $# in 0) ;; *) return 2 ;; esac
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
	case $_worker_stat_extra in '') ;; *) return 1 ;; esac
	_cfmgr_worker_stat_admitted "$_worker_stat_record" "$_worker_self_pid"
}

# Linux prints comm without escaping it. Use the last closing delimiter because
# the command name may contain spaces or parentheses.
_cfmgr_worker_stat_admitted() (
	set +x
	set +e
	set +u
	case $# in 2) ;; *) return 1 ;; esac
	_cfmgr_worker_stat_checked "$1" "$2" "$2"
)

_cfmgr_worker_stat_in_group() (
	set +x
	set +e
	set +u
	case $# in 2) ;; *) return 1 ;; esac
	_cfmgr_worker_stat_checked "$1" '' "$2"
)

_cfmgr_worker_stat_checked() (
	set +x
	set +e
	set +u
	_cfmgr_worker_native_environment
	IFS=' '
	set -f
	[ "$#" -eq 3 ] || return 1
	_worker_stat_record=$1
	_worker_expected_pid=$2
	_worker_expected_group=$3
	[ "${#_worker_stat_record}" -le 4096 ] || return 1
	_worker_lf='
'
	case $_worker_stat_record in *"$_worker_lf"*) return 1 ;; esac
	case $_worker_stat_record in *" ("*) ;; *) return 1 ;; esac
	_worker_stat_pid=${_worker_stat_record%% *}
	_cfmgr_worker_pid_valid "$_worker_stat_pid" || return 1
	[ -z "$_worker_expected_pid" ] || _cfmgr_worker_pid_valid "$_worker_expected_pid" || return 1
	_cfmgr_worker_pid_valid "$_worker_expected_group" || return 1
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
	{ [ -z "$_worker_expected_pid" ] || [ "$_worker_stat_pid" = "$_worker_expected_pid" ]; } &&
		[ "$_worker_stat_group" = "$_worker_expected_group" ]
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

# Dedicated trusted cron group only: no foreign members or later unrelated work.
# GUARD is already exclusive stable private RAM. This entry never removes it.
# The synchronous native callback includes its cleanup; no Entware/root launch
# is admitted here. No FD above9 is permitted at entry. Kernel/scheduler delays
# and externally stopped/killed supervisors preclude an absolute kill guarantee.
cfmgr_worker_deadline_with() {
	_cfmgr_worker_deadline_api "$@" || return 2
	case $$ in 1) return 1 ;; esac
	# shellcheck disable=SC2119
	cfmgr_worker_group_check || return 1
	_cfmgr_worker_deadline_owner "$$" "$@" >/dev/null 2>&1
}

_cfmgr_worker_deadline_api() (
	set +x
	set +e
	set +u
	_cfmgr_worker_native_environment
	[ "$#" -ge 4 ] || return 2
	[ "${#1}" -le 4096 ] || return 2
	case $1 in /*) ;; *) return 2 ;; esac
	case $1 in / | */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 2 ;; esac
	case $2 in '' | 0* | *[!0123456789]*) return 2 ;; esac
	[ "${#2}" -le 4 ] && [ "$2" -ge 4 ] && [ "$2" -le 3600 ] || return 2
	case $3 in '' | 0* | *[!0123456789]*) return 2 ;; esac
	[ "${#3}" -le 2 ] && [ "$3" -le 30 ] && [ "$3" -lt "$2" ] || return 2
	case $4 in '' | [!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 2 ;; esac
) >/dev/null 2>&1

_cfmgr_worker_deadline_seconds_valid() {
	case $# in 1) ;; *) return 1 ;; esac
	case $1 in 0) return 0 ;; esac
	_cfmgr_worker_pid_valid "$1"
}

# The one explicit internal test seam. Production always reads native uptime;
# no environment/input selects a clock. Whole seconds are canonical uint31.
_cfmgr_worker_deadline_clock_now() (
	set +x
	set +e
	set +u
	set -f
	_cfmgr_worker_native_environment
	_worker_clock_record=
	_worker_clock_extra=
	_cfmgr_worker_deadline_clock_read 6</proc/uptime
) 2>/dev/null

_cfmgr_worker_deadline_clock_read() {
	IFS= read -r _worker_clock_record <&6 || return 1
	if IFS= read -r _worker_clock_extra <&6; then return 1; fi
	[ -z "$_worker_clock_extra" ] && [ "${#_worker_clock_record}" -le 256 ] || return 1
	IFS=' '
	# shellcheck disable=SC2086
	set -- $_worker_clock_record
	[ "$#" -eq 2 ] || return 1
	for _worker_clock_value in "$1" "$2"; do
		case $_worker_clock_value in *[!0123456789.]* | *.*.*) return 1 ;; esac
		case $_worker_clock_value in *.*) ;; *) return 1 ;; esac
		_worker_clock_whole=${_worker_clock_value%.*}
		case $_worker_clock_whole in '' | 0[0123456789]*) return 1 ;; esac
		case ${_worker_clock_value##*.} in [0123456789][0123456789]) ;; *) return 1 ;; esac
	done
	_worker_clock_seconds=${1%.*}
	_cfmgr_worker_deadline_seconds_valid "$_worker_clock_seconds" || return 1
	command printf '%s\n' "$_worker_clock_seconds"
}

_cfmgr_worker_deadline_group_current() {
	_worker_group_record=
	_worker_group_extra=
	IFS= read -r _worker_group_record <&6 || return 1
	if IFS= read -r _worker_group_extra <&6; then return 1; fi
	case $_worker_group_extra in '') ;; *) return 1 ;; esac
	_cfmgr_worker_stat_in_group "$_worker_group_record" "$1"
}

_cfmgr_worker_deadline_tools() {
	_worker_deadline_mkdir=
	_worker_deadline_sleep=
	for _worker_native_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -z "$_worker_deadline_mkdir" ] && [ -f "$_worker_native_dir/mkdir" ] && [ -x "$_worker_native_dir/mkdir" ]; then
			_worker_deadline_mkdir=$_worker_native_dir/mkdir
		fi
		if [ -z "$_worker_deadline_sleep" ] && [ -f "$_worker_native_dir/sleep" ] && [ -x "$_worker_native_dir/sleep" ]; then
			_worker_deadline_sleep=$_worker_native_dir/sleep
		fi
	done
	[ -n "$_worker_deadline_mkdir" ] && [ -n "$_worker_deadline_sleep" ]
}

_cfmgr_worker_deadline_refresh() {
	_worker_deadline_sample=$(_cfmgr_worker_deadline_clock_now) || return 1
	_cfmgr_worker_deadline_seconds_valid "$_worker_deadline_sample" || return 1
	[ "$_worker_deadline_sample" -ge "$_worker_deadline_last" ] || return 1
	_worker_deadline_last=$_worker_deadline_sample
	_worker_deadline_elapsed=$((_worker_deadline_sample - _worker_deadline_epoch))
}

_cfmgr_worker_deadline_before_cutoff() {
	_cfmgr_worker_deadline_refresh || return 1
	if [ "$_worker_deadline_elapsed" -ge "$_worker_deadline_cutoff" ]; then
		_worker_deadline_expired=1
		return 1
	fi
}

# 0 valid empty marker,1 absent,2 invalid. Fixed trusted names only.
_cfmgr_worker_deadline_marker() (
	case $1 in armed | done | ack | cancel | expired) ;; *) return 2 ;; esac
	_worker_marker=$_worker_deadline_state/$1
	[ -e "$_worker_marker" ] || [ -L "$_worker_marker" ] || return 1
	[ -d "$_worker_marker" ] && [ ! -L "$_worker_marker" ] || return 2
	set +f
	for _worker_entry in "$_worker_marker"/* "$_worker_marker"/.[!.]* "$_worker_marker"/..?*; do
		[ ! -e "$_worker_entry" ] && [ ! -L "$_worker_entry" ] || return 2
	done
)

_cfmgr_worker_deadline_poll() {
	while :; do
		[ "$_worker_deadline_interrupted" -eq 0 ] || return 1
		case $1 in
		armed) _cfmgr_worker_deadline_before_cutoff || return 1 ;;
		ack)
			_cfmgr_worker_deadline_refresh || return 1
			if [ "$_worker_deadline_elapsed" -ge "$_worker_deadline_total" ]; then
				_worker_deadline_expired=1
				return 1
			fi
			;;
		*) return 1 ;;
		esac
		_cfmgr_worker_deadline_marker "$1"
		_worker_marker_status=$?
		case $_worker_marker_status in 0) return 0 ;; 1) ;; *) return 1 ;; esac
		[ "$_worker_deadline_polls" -lt "$_worker_deadline_total" ] || return 1
		_worker_deadline_polls=$((_worker_deadline_polls + 1))
		"$_worker_deadline_sleep" 1 || return 1
	done
}

# Only an admitted actor in the unchanged dedicated group calls this. Group0
# includes the cancelling actor. A returned KILL failure is uncertainty129,
# never callback completion; the guard remains even if publication failed.
_cfmgr_worker_deadline_cancel() {
	[ "$_worker_deadline_disarmed" -eq 0 ] || exit 1
	trap '' HUP INT QUIT TERM
	_worker_cancel_valid=0
	if _cfmgr_worker_deadline_refresh; then
		_worker_cancel_valid=1
		_worker_cancel_elapsed=$_worker_deadline_elapsed
	fi
	"$_worker_deadline_mkdir" -m 700 "$_worker_deadline_state/cancel" >/dev/null 2>&1 || :
	if [ "$_worker_deadline_expired" -eq 1 ]; then
		"$_worker_deadline_mkdir" -m 700 "$_worker_deadline_state/expired" >/dev/null 2>&1 || :
	fi
	command kill -TERM 0 || :
	_cfmgr_worker_deadline_refresh || _worker_cancel_valid=0
	_worker_cancel_polls=0
	while [ "$_worker_cancel_valid" -eq 1 ] && [ "$_worker_cancel_polls" -lt "$_worker_deadline_grace" ]; do
		[ "$_worker_deadline_elapsed" -lt "$_worker_deadline_total" ] || break
		[ "$((_worker_deadline_elapsed - _worker_cancel_elapsed))" -lt "$_worker_deadline_grace" ] || break
		_worker_cancel_polls=$((_worker_cancel_polls + 1))
		"$_worker_deadline_sleep" 1 || break
		_cfmgr_worker_deadline_refresh || break
	done
	command kill -KILL 0
	exit 129
}

_cfmgr_worker_deadline_owner() (
	set +x
	set +e
	set +u
	set -f
	trap - 0 HUP INT QUIT TERM
	IFS=' 	'
	IFS="${IFS}
"
	_cfmgr_worker_native_environment
	umask 077
	_worker_deadline_leader=$1
	_worker_deadline_guard=$2
	_worker_deadline_total=$3
	_worker_deadline_grace=$4
	_worker_deadline_callback=$5
	shift 5
	_worker_deadline_cutoff=$((_worker_deadline_total - _worker_deadline_grace))
	_worker_deadline_interrupted=0
	_worker_deadline_expired=0
	_worker_deadline_disarmed=0
	_worker_deadline_polls=0
	_cfmgr_worker_deadline_group_current "$_worker_deadline_leader" 6</proc/self/stat || return 1
	_worker_deadline_epoch=$(_cfmgr_worker_deadline_clock_now) || return 1
	_cfmgr_worker_deadline_seconds_valid "$_worker_deadline_epoch" || return 1
	_worker_deadline_last=$_worker_deadline_epoch
	_worker_deadline_elapsed=0
	[ -d "$_worker_deadline_guard" ] && [ ! -L "$_worker_deadline_guard" ] || return 1
	_cfmgr_worker_deadline_tools || return 1
	"$_worker_deadline_sleep" 0 || return 1
	_worker_deadline_state=$_worker_deadline_guard/deadline
	[ ! -e "$_worker_deadline_state" ] && [ ! -L "$_worker_deadline_state" ] || return 1
	"$_worker_deadline_mkdir" -m 700 "$_worker_deadline_state" || return 1
	_cfmgr_worker_deadline_before_cutoff || return 1
	trap '_worker_deadline_interrupted=1' HUP INT QUIT TERM
	_cfmgr_worker_deadline_watchdog >/dev/null 2>&1 &
	_worker_deadline_child=$!
	_cfmgr_worker_pid_valid "$_worker_deadline_child" || _cfmgr_worker_deadline_cancel
	_cfmgr_worker_deadline_poll armed || _cfmgr_worker_deadline_cancel
	if [ "$_worker_deadline_interrupted" -eq 0 ] && _cfmgr_worker_deadline_before_cutoff; then :; else
		_cfmgr_worker_deadline_cancel
	fi
	("$_worker_deadline_callback" "$@")
	_worker_deadline_status=$?
	[ "$_worker_deadline_status" -le 128 ] && [ "$_worker_deadline_interrupted" -eq 0 ] || _cfmgr_worker_deadline_cancel
	_cfmgr_worker_deadline_before_cutoff || _cfmgr_worker_deadline_cancel
	"$_worker_deadline_mkdir" -m 700 "$_worker_deadline_state/done" || _cfmgr_worker_deadline_cancel
	_cfmgr_worker_deadline_poll ack || _cfmgr_worker_deadline_cancel
	wait "$_worker_deadline_child"
	_worker_deadline_wait=$?
	if [ "$_worker_deadline_wait" -eq 0 ] && [ "$_worker_deadline_interrupted" -eq 0 ] &&
		_cfmgr_worker_deadline_marker ack; then :; else
		_cfmgr_worker_deadline_cancel
	fi
	return "$_worker_deadline_status"
)

# Runs once in its own shell, never into the execution root. Irreversible disarm
# precedes ack: after that decision every path exits without group signalling.
_cfmgr_worker_deadline_watchdog() {
	trap - 0
	trap '' HUP INT QUIT TERM
	exec 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
	cd / || exit 1
	exec 0</dev/null
	_cfmgr_worker_deadline_group_current "$_worker_deadline_leader" 6</proc/self/stat || exit 1
	_cfmgr_worker_deadline_before_cutoff || _cfmgr_worker_deadline_cancel
	[ -x "$_worker_deadline_mkdir" ] && [ -x "$_worker_deadline_sleep" ] || exit 1
	"$_worker_deadline_sleep" 0 || _cfmgr_worker_deadline_cancel
	"$_worker_deadline_mkdir" -m 700 "$_worker_deadline_state/armed" || _cfmgr_worker_deadline_cancel
	_worker_watch_polls=0
	while :; do
		_cfmgr_worker_deadline_marker cancel
		_worker_marker_status=$?
		case $_worker_marker_status in 1) ;; *) _cfmgr_worker_deadline_cancel ;; esac
		_cfmgr_worker_deadline_marker "done"
		_worker_marker_status=$?
		case $_worker_marker_status in
		0)
			_cfmgr_worker_deadline_before_cutoff || _cfmgr_worker_deadline_cancel
			# This is the final decision point. No later branch may signal.
			_worker_deadline_disarmed=1
			"$_worker_deadline_mkdir" -m 700 "$_worker_deadline_state/ack" || exit 1
			exit 0
			;;
		1) ;;
		*) _cfmgr_worker_deadline_cancel ;;
		esac
		_cfmgr_worker_deadline_before_cutoff || _cfmgr_worker_deadline_cancel
		[ "$_worker_watch_polls" -lt "$_worker_deadline_total" ] || _cfmgr_worker_deadline_cancel
		_worker_watch_polls=$((_worker_watch_polls + 1))
		"$_worker_deadline_sleep" 1 || _cfmgr_worker_deadline_cancel
	done
}
