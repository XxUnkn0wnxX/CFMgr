#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Internal native timeout/gzip probes for the separate fixed-probe lifecycle.
# Sourcing defines functions only. This is not a root sandbox or general runner.
# The caller is the trusted isolated owner: GUARD is fresh/exclusive outside IO
# scratch, ROOT is exactly GUARD/root, active is set, and root/code/library/
# preload have already been admitted. Native tools and RAM ancestors are trusted.
# Caller tracing is off; no external descriptors beyond known FD3..9 are open.
# Only the fixed-probe lifecycle may call this helper after image admission;
# synchronous native isolation callbacks do not authorize it. Caller owns cleanup.
# Completion proves only that synchronous env/chroot returned; it proves neither
# wrapper exit nor descendant exit. Incomplete started work retains GUARD pending
# recovery. No mount, wait, signal, callback, arbitrary command, or tree removal.

cfmgr_supervision_test() {
	_cfmgr_supervision_reset
	[ "$#" -eq 4 ] && [ -n "$4" ] || return 2
	_cfmgr_supervision_run "$4" "$1" "$2" "$3"
}

_cfmgr_supervision_probe() {
	_cfmgr_supervision_reset
	[ "$#" -eq 3 ] || return 2
	_cfmgr_supervision_run '' "$1" "$2" "$3"
}

_cfmgr_supervision_reset() {
	_supervision_started=0
	_supervision_complete=0
	_supervision_status=
	_supervision_stdout=
	_supervision_stderr=
	_supervision_stdout_bytes=
	_supervision_stderr_bytes=
}

_cfmgr_supervision_run() {
	[ "$#" -eq 4 ] || return 2
	_supervision_tools=$1
	_supervision_guard=$2
	_supervision_root=$3
	_supervision_mode=$4
	case $_supervision_mode in timeout | gzip) ;; *) return 2 ;; esac
	[ -z "$_supervision_tools" ] || _cfmgr_supervision_path "$_supervision_tools" || return 2
	_cfmgr_supervision_path "$_supervision_guard" || return 2
	[ "$_supervision_root" = "$_supervision_guard/root" ] || return 2
	_cfmgr_supervision_path "$_supervision_root" || return 2
	[ -d "$_supervision_guard" ] && [ ! -L "$_supervision_guard" ] || return 1
	[ -f "$_supervision_guard/active" ] && [ ! -L "$_supervision_guard/active" ] || return 1
	[ -d "$_supervision_root" ] && [ ! -L "$_supervision_root" ] || return 1
	_supervision_probe=$_supervision_guard/probe
	[ ! -e "$_supervision_probe" ] && [ ! -L "$_supervision_probe" ] || return 1

	_supervision_mkdir=$(_cfmgr_supervision_find mkdir) || return 1
	_supervision_wc=$(_cfmgr_supervision_find wc) || return 1
	_supervision_printf=$(_cfmgr_supervision_find printf) || return 1
	_supervision_sleep=$(_cfmgr_supervision_find sleep) || return 1
	_supervision_env=$(_cfmgr_supervision_find env) || return 1
	_supervision_chroot=$(_cfmgr_supervision_find chroot) || return 1
	"$_supervision_mkdir" -m 700 "$_supervision_probe" || return 1
	for _supervision_name in stdout stderr status; do
		[ ! -e "$_supervision_probe/$_supervision_name" ] &&
			[ ! -L "$_supervision_probe/$_supervision_name" ] || return 1
	done

	# Set before background launch. No later failure can prove that the wrapper
	# or a descendant stopped; callers retain the guard when complete remains 0.
	_supervision_started=1
	_cfmgr_supervision_worker \
		"$_supervision_probe" "$_supervision_root" "$_supervision_mode" \
		"$_supervision_env" "$_supervision_chroot" "$_supervision_printf" \
		>/dev/null 2>&1 &
	case $_supervision_mode in timeout) _supervision_limit=5 ;; gzip) _supervision_limit=6 ;; esac
	_supervision_elapsed=0
	while :; do
		if _cfmgr_supervision_terminal "$_supervision_probe" "$_supervision_wc"; then
			return "$_supervision_status"
		else
			_supervision_terminal_status=$?
		fi
		[ "$_supervision_terminal_status" -ne 129 ] || return 129
		[ "$_supervision_complete" -eq 0 ] || return 1
		[ "$_supervision_elapsed" -lt "$_supervision_limit" ] || return 124
		"$_supervision_sleep" 1 || return 1
		_supervision_elapsed=$((_supervision_elapsed + 1))
	done
} >/dev/null 2>&1

_cfmgr_supervision_path() (
	LC_ALL=C
	export LC_ALL
	[ "$#" -eq 1 ] || return 1
	[ "${#1}" -le 4096 ] || return 1
	case $1 in /*) ;; *) return 1 ;; esac
	case $1 in
	/ | */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 1 ;;
	esac
)

_cfmgr_supervision_find() {
	case $1 in chroot | env | sleep | mkdir | wc | printf) ;; *) return 1 ;; esac
	if [ -n "$_supervision_tools" ]; then
		[ -d "$_supervision_tools" ] && [ ! -L "$_supervision_tools" ] || return 1
		[ -x "$_supervision_tools/$1" ] && [ ! -d "$_supervision_tools/$1" ] || return 1
		printf '%s\n' "$_supervision_tools/$1"
		return
	fi
	if [ "$1" = chroot ]; then
		[ -x /usr/sbin/chroot ] && [ ! -d /usr/sbin/chroot ] || return 1
		printf '%s\n' /usr/sbin/chroot
		return
	fi
	for _supervision_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_supervision_dir/$1" ] && [ ! -d "$_supervision_dir/$1" ]; then
			printf '%s\n' "$_supervision_dir/$1"
			return
		fi
	done
	return 1
}

_cfmgr_supervision_worker() {
	trap - 0 HUP INT TERM
	set +e
	set +u
	set +x
	set -f
	umask 077
	LC_ALL=C
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	export LC_ALL PATH
	unset ENV BASH_ENV CDPATH
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES TZ
	cd / || exit 1
	exec 0</dev/null
	exec 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&-
	exec >/dev/null 2>&1
	_supervision_probe=$1
	_supervision_root=$2
	_supervision_mode=$3
	_supervision_env=$4
	_supervision_chroot=$5
	_supervision_printf=$6
	# Nine 512-byte file-limit units allow overflow to be observed on 512-byte
	# systems while remaining bounded on 1024-byte implementations. The parent
	# accepts at most4096 original bytes in each capture.
	ulimit -f 9 || exit 1
	[ ! -e "$_supervision_probe/stdout" ] && [ ! -L "$_supervision_probe/stdout" ] || exit 1
	[ ! -e "$_supervision_probe/stderr" ] && [ ! -L "$_supervision_probe/stderr" ] || exit 1
	set -C
	: >"$_supervision_probe/stdout" 2>/dev/null || exit 1
	: >"$_supervision_probe/stderr" 2>/dev/null || exit 1
	set +C
	case $_supervision_mode in
	timeout)
		"$_supervision_env" -i LC_ALL=C PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_supervision_chroot" "$_supervision_root" /bootstrap/timeout-coreutils --version \
			>"$_supervision_probe/stdout" 2>"$_supervision_probe/stderr"
		;;
	gzip)
		"$_supervision_env" -i LC_ALL=C PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_supervision_chroot" "$_supervision_root" /bootstrap/timeout-coreutils \
			--foreground --kill-after=1 3 /bootstrap/gzip-gnu --version \
			>"$_supervision_probe/stdout" 2>"$_supervision_probe/stderr"
		;;
	esac
	_supervision_child_status=$?
	[ -f "$_supervision_probe/stdout" ] && [ ! -L "$_supervision_probe/stdout" ] || exit 1
	[ -f "$_supervision_probe/stderr" ] && [ ! -L "$_supervision_probe/stderr" ] || exit 1
	_supervision_body_bytes=$((6 + ${#_supervision_child_status}))
	# Publish completion as the final filesystem interaction. Never check a path,
	# remove a file, wait, or run a callback after this one terminal write.
	set -C
	"$_supervision_printf" 'done\t%s\nend\t%s\n' \
		"$_supervision_child_status" "$_supervision_body_bytes" \
		>"$_supervision_probe/status" 2>/dev/null
	_supervision_write_status=$?
	set +C
	exit "$_supervision_write_status"
}

_cfmgr_supervision_terminal() {
	_supervision_complete=0
	_supervision_status=
	_supervision_stdout=
	_supervision_stderr=
	_supervision_stdout_bytes=
	_supervision_stderr_bytes=
	[ "$#" -eq 2 ] || return 1
	_supervision_read_probe=$1
	_supervision_read_wc=$2
	[ -d "$_supervision_read_probe" ] && [ ! -L "$_supervision_read_probe" ] || return 1
	if _cfmgr_supervision_record "$_supervision_read_probe/status" "$_supervision_read_wc"; then
		_supervision_status=$_supervision_record_status
	else
		_supervision_terminal_read_status=$?
		case $_supervision_terminal_read_status in 1) return 1 ;; *) return 129 ;; esac
	fi
	_supervision_complete=1
	_supervision_stdout=$_supervision_read_probe/stdout
	_supervision_stderr=$_supervision_read_probe/stderr
	[ -f "$_supervision_stdout" ] && [ ! -L "$_supervision_stdout" ] || return 1
	[ -f "$_supervision_stderr" ] && [ ! -L "$_supervision_stderr" ] || return 1
	if _supervision_stdout_bytes=$(_cfmgr_supervision_size "$_supervision_read_wc" "$_supervision_stdout"); then :; else
		_supervision_terminal_read_status=$?
		[ "$_supervision_terminal_read_status" -eq 1 ] && return 1
		_supervision_complete=0
		return 129
	fi
	if _supervision_stderr_bytes=$(_cfmgr_supervision_size "$_supervision_read_wc" "$_supervision_stderr"); then :; else
		_supervision_terminal_read_status=$?
		[ "$_supervision_terminal_read_status" -eq 1 ] && return 1
		_supervision_complete=0
		return 129
	fi
	[ "$_supervision_stdout_bytes" -le 4096 ] && [ "$_supervision_stderr_bytes" -le 4096 ]
}

# Strict shared frame reader. Parsing never establishes caller completion.
_cfmgr_supervision_record() {
	_supervision_record_status=
	[ "$#" -eq 2 ] || return 1
	_supervision_record_file=$1
	[ -f "$_supervision_record_file" ] && [ ! -L "$_supervision_record_file" ] || return 1
	if _supervision_record_bytes=$(_cfmgr_supervision_size "$2" "$_supervision_record_file"); then :; else
		_supervision_record_read_status=$?
		case $_supervision_record_read_status in 1) return 1 ;; *) return 129 ;; esac
	fi
	[ "$_supervision_record_bytes" -le 32 ] || return 1
	_supervision_first=
	_supervision_second=
	_supervision_extra=
	if {
		if IFS= read -r _supervision_first; then _supervision_record_read_status=0; else _supervision_record_read_status=$?; fi
		case $_supervision_record_read_status in 0) ;; 1) return 1 ;; *) return 129 ;; esac
		if IFS= read -r _supervision_second; then _supervision_record_read_status=0; else _supervision_record_read_status=$?; fi
		case $_supervision_record_read_status in 0) ;; 1) return 1 ;; *) return 129 ;; esac
		if IFS= read -r _supervision_extra; then _supervision_record_read_status=0; else _supervision_record_read_status=$?; fi
		case $_supervision_record_read_status in 1) ;; 0) return 1 ;; *) return 129 ;; esac
		[ -z "$_supervision_extra" ] || return 1
	} <"$_supervision_record_file"; then :; else
		return 1
	fi
	_supervision_tab='	'
	case $_supervision_first in done"$_supervision_tab"*) ;; *) return 1 ;; esac
	_supervision_parsed_status=${_supervision_first#done"$_supervision_tab"}
	case $_supervision_parsed_status in
	0 | [1-9] | [1-9][0-9] | 1[0-9][0-9] | 2[0-4][0-9] | 25[0-5]) ;;
	*)
		return 1
		;;
	esac
	_supervision_body_bytes=$((6 + ${#_supervision_parsed_status}))
	_supervision_expected_first="done$_supervision_tab$_supervision_parsed_status"
	_supervision_expected_second="end$_supervision_tab$_supervision_body_bytes"
	[ "$_supervision_first" = "$_supervision_expected_first" ] || return 1
	[ "$_supervision_second" = "$_supervision_expected_second" ] || return 1
	[ "$_supervision_record_bytes" -eq "$((${#_supervision_expected_first} + ${#_supervision_expected_second} + 2))" ] || return 1
	_supervision_record_status=$_supervision_parsed_status
}

_cfmgr_supervision_size() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	LC_ALL=C
	export LC_ALL
	[ "$#" -eq 2 ] || return 1
	[ -f "$2" ] && [ ! -L "$2" ] || return 1
	_supervision_size=$(
		command exec <"$2" || exit 1
		exec "$1" -c
	)
	_supervision_size_status=$?
	if [ "$_supervision_size_status" -ne 0 ]; then
		[ "$_supervision_size_status" -le 128 ] && return 1
		return 129
	fi
	while :; do
		case $_supervision_size in ' '* | '	'*) _supervision_size=${_supervision_size#?} ;; *) break ;; esac
	done
	case $_supervision_size in '' | *[!0123456789]*) return 1 ;; esac
	case $_supervision_size in
	0 | [1-9] | [1-9][0-9] | [1-9][0-9][0-9] | [1-3][0-9][0-9][0-9] | 40[0-8][0-9] | 409[0-6]) ;;
	*) return 1 ;;
	esac
	command printf '%s\n' "$_supervision_size"
	_supervision_size_status=$?
	[ "$_supervision_size_status" -eq 0 ] && return 0
	[ "$_supervision_size_status" -le 128 ] && return 1
	return 129
) 2>/dev/null
