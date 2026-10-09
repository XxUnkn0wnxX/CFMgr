#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Callback-only opaque native data staging inside a trusted active IO workspace.
# Caller owns canonical private RAM IMAGE/ancestors, stable sources and signals.
# Source targets may be firmware links; no hostile-root or file-generation lease.
# Failure retains partial staging. Admission requires this helper's0 AND enclosing
# IO cleanup0. No resolver syntax/readiness, execution or broader config closure.
# Sourcing defines functions only. Trusted io.sh must already be loaded.
# The isolated helper state is intentionally inherited by its private callees.
# shellcheck disable=SC2154,SC2030,SC2031

cfmgr_native_config_stage() {
	case $# in 1) ;; *) return 2 ;; esac
	_cfmgr_native_config_run production "$1" / >/dev/null 2>&1
}

cfmgr_native_config_test() {
	case $# in 2) ;; *) return 2 ;; esac
	_cfmgr_native_config_run fixture "$1" "$2" >/dev/null 2>&1
}

_cfmgr_native_config_path() {
	[ "${#1}" -le 4096 ] || return 1
	case $1 in /) return 0 ;; /*) ;; *) return 1 ;; esac
	case $1 in */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 1 ;; esac
}

# Physical resolution rejects an ancestor alias without new capture slots.
_cfmgr_native_config_directory() (
	[ -d "$1" ] && [ ! -L "$1" ] || return 1
	cd -P "$1" || return 1
	[ "$PWD" = "$1" ]
)

_cfmgr_native_config_run() (
	set +x
	set +e
	set +u
	set -f
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	export PATH LC_ALL
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	IFS=' 	'
	IFS="${IFS}
"
	umask 077
	[ "$#" -eq 3 ] && [ "${_io_active-}" = 1 ] || return 2
	_native_image=$2
	case $1 in production) _native_source=/ ;; fixture) _native_source=$3 ;; *) return 2 ;; esac
	_native_etc=$_native_image/etc
	_native_hosts=${_native_source%/}/etc/hosts
	_native_resolv=${_native_source%/}/etc/resolv.conf
	for _native_path in "${_io_root-}" "${_io_stage-}" "$_native_image" "$_native_source" \
		"$_native_etc" "$_native_etc/hosts" "$_native_etc/resolv.conf" "$_native_hosts" "$_native_resolv"; do
		_cfmgr_native_config_path "$_native_path" || return 2
	done
	for _native_directory in "$_io_root" "$_io_stage" "$_native_image" "$_native_source"; do
		_cfmgr_native_config_directory "$_native_directory" || return 2
	done
	[ "$_native_image" != "$_io_root" ] && [ "$_io_stage" != "$_io_root" ] || return 2
	case $_native_image in "${_io_root%/}/"*) ;; *) return 2 ;; esac
	case $_io_stage in "${_io_root%/}/"*) ;; *) return 2 ;; esac
	case $_native_image in "$_io_stage" | "$_io_stage"/*) return 2 ;; esac
	case ${_io_tools+x} in x) ;; *) return 2 ;; esac
	for _native_tool in "${_io_mkdir-}" "${_io_printf-}" "${_io_wc-}"; do
		_cfmgr_native_config_path "$_native_tool" && [ -x "$_native_tool" ] && [ ! -d "$_native_tool" ] || return 2
	done
	_native_tab='	'
	[ "${_io_tab-}" = "$_native_tab" ] || return 2
	_native_cat=$(_cfmgr_io_find cat) || return 1
	# All twelve capture artifacts must be fresh before any image mutation.
	for _native_slot in 0 1 2 3; do
		for _native_suffix in out err status; do
			_native_artifact=$_io_stage/$_native_slot.$_native_suffix
			_cfmgr_native_config_path "$_native_artifact" || return 2
			[ ! -e "$_native_artifact" ] && [ ! -L "$_native_artifact" ] || return 1
		done
	done
	[ ! -e "$_native_etc" ] && [ ! -L "$_native_etc" ] || return 1
	# Both target shapes and accepted bounded byte strings precede reservation.
	[ -f "$_native_hosts" ] && [ -r "$_native_hosts" ] &&
		[ -f "$_native_resolv" ] && [ -r "$_native_resolv" ] || return 1
	_cfmgr_native_config_capture 0 "$_native_hosts" || return 1
	_native_hosts_text=$_native_text
	_cfmgr_native_config_capture 1 "$_native_resolv" || return 1
	_native_resolv_text=$_native_text
	"$_io_mkdir" -m 700 "$_native_etc" || return 1
	[ -d "$_native_etc" ] && [ ! -L "$_native_etc" ] || return 1
	_cfmgr_native_config_write "$_native_etc/hosts" "$_native_hosts_text" || return 1
	_cfmgr_native_config_write "$_native_etc/resolv.conf" "$_native_resolv_text" || return 1
	_cfmgr_native_config_verify 2 "$_native_etc/hosts" "$_native_hosts_text" || return 1
	_cfmgr_native_config_verify 3 "$_native_etc/resolv.conf" "$_native_resolv_text"
)

_cfmgr_native_config_capture() {
	cfmgr_io_capture "$1" 65536 4096 cat "$2" || return 1
	_cfmgr_io_capture_status "$1" || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	# The non-LF sentinel preserves every terminal LF in command substitution.
	# C-locale length must equal original captured bytes: shell NUL removal or
	# truncation cannot become accepted text, including for an empty source.
	_native_text=$("$_native_cat" "$_io_stage/$1.out" && "$_io_printf" '.') || return 1
	case $_native_text in *.) ;; *) return 1 ;; esac
	_native_text=${_native_text%.}
	[ "${#_native_text}" -eq "$_io_out_bytes" ]
}

_cfmgr_native_config_write() (
	umask 077
	set -C
	[ ! -e "$1" ] && [ ! -L "$1" ] || return 1
	# Same conservative512-byte accounting as IO; accepted data is <=65536.
	ulimit -f 129 || return 1
	"$_io_printf" '%s' "$2" >"$1"
)

_cfmgr_native_config_verify() {
	[ -f "$2" ] && [ ! -L "$2" ] || return 1
	_native_written=$(_cfmgr_io_size "$2") || return 1
	[ "$_native_written" -eq "${#3}" ] || return 1
	_cfmgr_native_config_capture "$1" "$2" || return 1
	[ "$_native_text" = "$3" ]
}
