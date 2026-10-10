#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Functions-only native size/digest observations of caller-owned immutable files.
# Trusted tools/runtime, already bounded acquisition, private fresh scratch and
# unaliased ancestors are caller prerequisites. Native readers consume to EOF;
# these checks add no source trust, hard deadline, signal owner or cleanup.

# 0 success, 10 completed rejection, 2 invalid API, 129 uncertainty.
_cfmgr_native_size_owned() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	LC_ALL=C
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	export LC_ALL PATH
	[ "$#" -eq 2 ] && [ -n "$1" ] || return 2
	[ -f "$2" ] && [ ! -L "$2" ] && [ -r "$2" ] || return 10
	# Redirection/exec failures stay inside the capture; no count is trusted
	# until its producer status has been classified.
	_native_size_count=$(exec "$1" -c <"$2")
	_native_size_status=$?
	case $_native_size_status in
	0) ;;
	*)
		[ "$_native_size_status" -le 128 ] && return 10
		return 129
		;;
	esac
	while :; do
		case $_native_size_count in ' '* | '	'*) _native_size_count=${_native_size_count#?} ;; *) break ;; esac
	done
	case $_native_size_count in '' | *[!0123456789]* | 0[0123456789]*) return 10 ;; esac
	[ "${#_native_size_count}" -le 8 ] || return 10
	printf '%s\n' "$_native_size_count"
	_native_size_status=$?
	[ "$_native_size_status" -eq 0 ] && return 0
	[ "$_native_size_status" -le 128 ] && return 10
	return 129
) 2>/dev/null

# FILE EXPECTED DIGEST_PATH HEX_PATH WC ENV OPENSSL HEXDUMP; status 0/1.
# Scratch remains with the caller even after failure. One digest/hex pair uses
# at most 96 accepted bytes; the subshell file limit also bounds failed writes.
_cfmgr_native_digest_match() (
	set +x
	set +e
	set +u
	set -f
	umask 077
	LC_ALL=C
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	export LC_ALL PATH
	[ "$#" -eq 8 ] || return 1
	[ -f "$1" ] && [ ! -L "$1" ] && [ -r "$1" ] || return 1
	[ "${#2}" -eq 64 ] || return 1
	case $2 in *[!0123456789abcdef]*) return 1 ;; esac
	[ -n "$3" ] && [ -n "$4" ] && [ "$3" != "$4" ] || return 1
	for _native_digest_path in "$3" "$4"; do
		[ ! -e "$_native_digest_path" ] && [ ! -L "$_native_digest_path" ] || return 1
	done
	# Clear inherited loader/OpenSSL controls before the first external tool.
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	unset OPENSSL_CONF OPENSSL_CONF_INCLUDE OPENSSL_ENGINES OPENSSL_MODULES
	ulimit -f 1 || return 1
	set -C
	"$6" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
		"$7" dgst -sha256 -binary <"$1" >"$3" || return 1
	_native_digest_size=$(_cfmgr_native_size_owned "$5" "$3") || return 1
	[ "$_native_digest_size" = 32 ] || return 1
	"$8" -v -n 32 -e '1/1 "%02x"' <"$3" >"$4" || return 1
	_native_digest_size=$(_cfmgr_native_size_owned "$5" "$4") || return 1
	[ "$_native_digest_size" = 64 ] || return 1
	_native_digest_value=
	if IFS= read -r _native_digest_value <"$4"; then return 1; fi
	[ "${#_native_digest_value}" -eq 64 ] || return 1
	case $_native_digest_value in *[!0123456789abcdef]*) return 1 ;; esac
	[ "$_native_digest_value" = "$2" ]
) 2>/dev/null
