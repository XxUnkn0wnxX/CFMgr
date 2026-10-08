#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Internal reviewed-archive acquisition; trusted closure.sh already sourced.
# Source defines functions only. No extraction, execution or storage approval.
# Trusted native tools/private RAM ancestors, tracing disabled before invocation
# and no other writers are preconditions. Failure retains every partial file.
# The caller owns interruptions/cleanup and must not remove resources while a
# producer could remain active. Curl limits do not prove a hard action deadline.
# Per-entry subshell state is inherited by its nested trusted helper calls.
# shellcheck disable=SC2030,SC2031

# Explicit trusted fixture API only; production always supplies empty TOOLS.
cfmgr_fetch_test() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	umask 077
	LC_ALL=C
	export LC_ALL
	IFS=' 	'
	IFS="${IFS}
"
	[ "$#" -eq 5 ] && [ -n "$1" ] || return 2
	_cfmgr_fetch_run "$@"
	_cfmgr_fetch_public_status "$?"
) >/dev/null 2>&1

# TOOLS DIRECTORY URL SIZE SHA256. Zero approves only the retained archive's
# exact bytes. Any nonzero result leaves all output unapproved and private.
_cfmgr_fetch_run() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	umask 077
	LC_ALL=C
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	export LC_ALL PATH
	IFS=' 	'
	IFS="${IFS}
"
	[ "$#" -eq 5 ] || return 2
	_fetch_tools=$1
	_fetch_directory=$2
	_fetch_url=$3
	_fetch_size=$4
	_fetch_sha256=$5
	if [ -n "$_fetch_tools" ]; then
		_cfmgr_fetch_path "$_fetch_tools"
		_cfmgr_fetch_protocol_status "$?" || return "$?"
		[ -d "$_fetch_tools" ] && [ ! -L "$_fetch_tools" ] || return 2
	fi
	_cfmgr_fetch_path "$_fetch_directory"
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "${#_fetch_url}" -le 2048 ] || return 2
	case $_fetch_url in https://?*) ;; *) return 2 ;; esac
	case $_fetch_url in *[[:cntrl:]]*) return 2 ;; esac
	case $_fetch_size in '' | 0* | *[!0123456789]*) return 2 ;; esac
	[ "${#_fetch_size}" -le 5 ] && [ "$_fetch_size" -le 65536 ] || return 2
	[ "${#_fetch_sha256}" -eq 64 ] || return 2
	case $_fetch_sha256 in *[!0123456789abcdef]*) return 2 ;; esac
	[ ! -e "$_fetch_directory" ] && [ ! -L "$_fetch_directory" ] || return 10
	# Clear inherited controls before the first external native executable,
	# including the env executable itself. Curl/OpenSSL receive only fixed env.
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	unset OPENSSL_CONF OPENSSL_CONF_INCLUDE OPENSSL_ENGINES OPENSSL_MODULES
	_fetch_mkdir=$(_cfmgr_fetch_find mkdir)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_curl=$(_cfmgr_fetch_find curl)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_env=$(_cfmgr_fetch_find env)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_wc=$(_cfmgr_fetch_find wc)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_openssl=$(_cfmgr_fetch_find openssl)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_hexdump=$(_cfmgr_fetch_find hexdump)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	"$_fetch_mkdir" -m 700 "$_fetch_directory"
	_cfmgr_fetch_native_status "$?" || return "$?"
	[ -d "$_fetch_directory" ] && [ ! -L "$_fetch_directory" ] || return 10
	_fetch_artifact=$_fetch_directory/artifact.ipk
	_fetch_headers=$_fetch_directory/headers
	_fetch_status=$_fetch_directory/http-status
	_fetch_digest=$_fetch_directory/digest
	_fetch_hex=$_fetch_directory/digest.hex
	# 512/1024-byte shell units cap each of the three streamed regular files
	# at 66048/132096 bytes, regardless of Content-Length/curl option semantics.
	(
		trap - 0 HUP INT TERM
		ulimit -f 129 || exit 10
		set -C || exit 10
		command exec >"$_fetch_status" 2>/dev/null || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_fetch_curl" -q --silent --fail --globoff --proto '=https' --proto-redir '=https' \
			--proxy '' --connect-timeout 10 --max-time 60 --retry 0 --max-redirs 0 \
			--max-filesize "$_fetch_size" --dump-header "$_fetch_headers" \
			--output "$_fetch_artifact" --write-out '%{http_code}' --url "$_fetch_url"
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_fetch_artifact_size=$(_cfmgr_closure_size_owned "$_fetch_wc" "$_fetch_artifact")
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "$_fetch_artifact_size" = "$_fetch_size" ] || return 10
	_fetch_header_size=$(_cfmgr_closure_size_owned "$_fetch_wc" "$_fetch_headers")
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "$_fetch_header_size" -gt 0 ] && [ "$_fetch_header_size" -le 16384 ] || return 10
	_fetch_status_size=$(_cfmgr_closure_size_owned "$_fetch_wc" "$_fetch_status")
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "$_fetch_status_size" = 3 ] || return 10
	_fetch_http_code=
	IFS= read -r _fetch_http_code <"$_fetch_status"
	_fetch_read_status=$?
	[ "$_fetch_read_status" -le 1 ] || return 129
	[ "$_fetch_read_status" = 1 ] && [ "$_fetch_http_code" = 200 ] || return 10
	_cfmgr_fetch_hash "$_fetch_artifact" "$_fetch_sha256" "$_fetch_digest" "$_fetch_hex"
	_cfmgr_fetch_protocol_status "$?"
) >/dev/null 2>&1

_cfmgr_fetch_find() {
	[ "$#" -eq 1 ] || return 2
	case $1 in mkdir | curl | env | wc | openssl | hexdump | dd | gunzip | tar) ;; *) return 2 ;; esac
	if [ -n "$_fetch_tools" ]; then
		[ -x "$_fetch_tools/$1" ] && [ ! -d "$_fetch_tools/$1" ] || return 10
		command printf '%s\n' "$_fetch_tools/$1"
		_cfmgr_fetch_native_status "$?"
		return "$?"
	fi
	for _fetch_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_fetch_dir/$1" ] && [ ! -d "$_fetch_dir/$1" ]; then
			command printf '%s\n' "$_fetch_dir/$1"
			_cfmgr_fetch_native_status "$?"
			return "$?"
		fi
	done
	return 10
}

# Stable physically bounded INPUT, approved SHA256, fresh private DIGEST and HEX
# paths. The trusted caller has validated paths/hash and resolved native tools.
_cfmgr_fetch_hash() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	LC_ALL=C
	export LC_ALL
	[ "$#" -eq 4 ] || return 2
	ulimit -f 1 || return 10
	set -C || return 10
	(
		command exec <"$1" >"$3" || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_fetch_openssl" dgst -sha256 -binary
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_fetch_hash_size=$(_cfmgr_closure_size_owned "$_fetch_wc" "$3")
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "$_fetch_hash_size" = 32 ] || return 10
	(
		command exec <"$3" >"$4" || exit 10
		exec "$_fetch_hexdump" -v -n 32 -e '1/1 "%02x"'
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_fetch_hash_size=$(_cfmgr_closure_size_owned "$_fetch_wc" "$4")
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "$_fetch_hash_size" = 64 ] || return 10
	_fetch_actual_sha256=
	IFS= read -r _fetch_actual_sha256 <"$4"
	_fetch_read_status=$?
	[ "$_fetch_read_status" -le 1 ] || return 129
	[ "$_fetch_read_status" = 1 ] && [ "${#_fetch_actual_sha256}" -eq 64 ] || return 10
	case $_fetch_actual_sha256 in *[!0123456789abcdef]*) return 10 ;; esac
	[ "$_fetch_actual_sha256" = "$2" ] || return 10
)

# Classification happens only immediately after an exec-ended single producer
# or a direct synchronous native utility. Multi-command helpers use protocol.
_cfmgr_fetch_native_status() {
	[ "$#" -eq 1 ] || return 129
	case $1 in 0) return 0 ;; esac
	[ "$1" -le 128 ] && return 10
	return 129
}

_cfmgr_fetch_protocol_status() {
	[ "$#" -eq 1 ] || return 129
	case $1 in 0 | 10 | 2 | 129) return "$1" ;; *) return 129 ;; esac
}

_cfmgr_fetch_public_status() {
	case $1 in 0 | 2) return "$1" ;; *) return 1 ;; esac
}

_cfmgr_fetch_path() (
	trap - 0 HUP INT TERM
	LC_ALL=C
	export LC_ALL
	[ "$#" -eq 1 ] && [ "${#1}" -le 4096 ] || return 2
	case $1 in /*) ;; *) return 2 ;; esac
	case $1 in / | */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 2 ;; esac
)
