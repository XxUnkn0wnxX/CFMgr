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
	trap - 0
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
) >/dev/null 2>&1

# TOOLS DIRECTORY URL SIZE SHA256. Zero approves only the retained archive's
# exact bytes. Any nonzero result leaves all output unapproved and private.
_cfmgr_fetch_run() (
	trap - 0
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
		_cfmgr_closure_path "$_fetch_tools" || return 2
		[ -d "$_fetch_tools" ] && [ ! -L "$_fetch_tools" ] || return 2
	fi
	_cfmgr_closure_path "$_fetch_directory" || return 2
	[ "${#_fetch_url}" -le 2048 ] || return 2
	case $_fetch_url in https://?*) ;; *) return 2 ;; esac
	case $_fetch_url in *[[:cntrl:]]*) return 2 ;; esac
	case $_fetch_size in '' | 0* | *[!0123456789]*) return 2 ;; esac
	[ "${#_fetch_size}" -le 5 ] && [ "$_fetch_size" -le 65536 ] || return 2
	[ "${#_fetch_sha256}" -eq 64 ] || return 2
	case $_fetch_sha256 in *[!0123456789abcdef]*) return 2 ;; esac
	[ ! -e "$_fetch_directory" ] && [ ! -L "$_fetch_directory" ] || return 1
	# Clear inherited controls before the first external native executable,
	# including the env executable itself. Curl/OpenSSL receive only fixed env.
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	unset OPENSSL_CONF OPENSSL_CONF_INCLUDE OPENSSL_ENGINES OPENSSL_MODULES
	_fetch_mkdir=$(_cfmgr_fetch_find mkdir) || return 1
	_fetch_curl=$(_cfmgr_fetch_find curl) || return 1
	_fetch_env=$(_cfmgr_fetch_find env) || return 1
	_fetch_wc=$(_cfmgr_fetch_find wc) || return 1
	_fetch_openssl=$(_cfmgr_fetch_find openssl) || return 1
	_fetch_hexdump=$(_cfmgr_fetch_find hexdump) || return 1
	"$_fetch_mkdir" -m 700 "$_fetch_directory" || return 1
	[ -d "$_fetch_directory" ] && [ ! -L "$_fetch_directory" ] || return 1
	_fetch_artifact=$_fetch_directory/artifact.ipk
	_fetch_headers=$_fetch_directory/headers
	_fetch_status=$_fetch_directory/http-status
	_fetch_digest=$_fetch_directory/digest
	_fetch_hex=$_fetch_directory/digest.hex
	# 512/1024-byte shell units cap each of the three streamed regular files
	# at 66048/132096 bytes, regardless of Content-Length/curl option semantics.
	(
		ulimit -f 129 || exit 1
		set -C
		"$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_fetch_curl" -q --silent --fail --globoff --proto '=https' --proto-redir '=https' \
			--proxy '' --connect-timeout 10 --max-time 60 --retry 0 --max-redirs 0 \
			--max-filesize "$_fetch_size" --dump-header "$_fetch_headers" \
			--output "$_fetch_artifact" --write-out '%{http_code}' --url "$_fetch_url" \
			>"$_fetch_status" 2>/dev/null
	) || return 1
	[ "$(_cfmgr_closure_size "$_fetch_wc" "$_fetch_artifact")" = "$_fetch_size" ] || return 1
	_fetch_header_size=$(_cfmgr_closure_size "$_fetch_wc" "$_fetch_headers") || return 1
	[ "$_fetch_header_size" -gt 0 ] && [ "$_fetch_header_size" -le 16384 ] || return 1
	[ "$(_cfmgr_closure_size "$_fetch_wc" "$_fetch_status")" = 3 ] || return 1
	_fetch_http_code=
	IFS= read -r _fetch_http_code <"$_fetch_status" && return 1
	[ "$_fetch_http_code" = 200 ] || return 1
	_cfmgr_fetch_hash "$_fetch_artifact" "$_fetch_sha256" "$_fetch_digest" "$_fetch_hex" || return 1
) >/dev/null 2>&1

_cfmgr_fetch_find() {
	case $1 in mkdir | curl | env | wc | openssl | hexdump) ;; *) return 1 ;; esac
	if [ -n "$_fetch_tools" ]; then
		[ -x "$_fetch_tools/$1" ] && [ ! -d "$_fetch_tools/$1" ] || return 1
		command printf '%s\n' "$_fetch_tools/$1"
		return
	fi
	for _fetch_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_fetch_dir/$1" ] && [ ! -d "$_fetch_dir/$1" ]; then
			command printf '%s\n' "$_fetch_dir/$1"
			return
		fi
	done
	return 1
}

# Stable physically bounded INPUT, approved SHA256, fresh private DIGEST and HEX
# paths. The trusted caller has validated paths/hash and resolved native tools.
_cfmgr_fetch_hash() (
	[ "$#" -eq 4 ] || exit 1
	ulimit -f 1 || exit 1
	set -C
	"$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
		"$_fetch_openssl" dgst -sha256 -binary <"$1" >"$3" || exit 1
	[ "$(_cfmgr_closure_size "$_fetch_wc" "$3")" = 32 ] || exit 1
	"$_fetch_hexdump" -v -n 32 -e '1/1 "%02x"' <"$3" >"$4" || exit 1
	[ "$(_cfmgr_closure_size "$_fetch_wc" "$4")" = 64 ] || exit 1
	_fetch_actual_sha256=
	IFS= read -r _fetch_actual_sha256 <"$4" && exit 1
	[ "${#_fetch_actual_sha256}" -eq 64 ] || exit 1
	case $_fetch_actual_sha256 in *[!0123456789abcdef]*) exit 1 ;; esac
	[ "$_fetch_actual_sha256" = "$2" ]
)
