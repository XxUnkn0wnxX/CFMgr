#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Fixed reviewed-byte extraction; trusted closure.sh/fetch.sh already sourced.
# Source defines functions only. Native parsers see only hash-approved private
# copies, and tar writes selected member bytes to stdout, never archive paths.
# Trusted native tools/private RAM ancestors, stable readable SOURCE, disabled
# tracing before invocation and no other writers are preconditions. Success
# leaves ordinary mode-600 program data; there is no execution or ABI approval.
# The caller owns interruption/cleanup. Failures retain all partial files; no
# hard native IO deadline or safe removal while a producer remains is promised.
# Per-entry subshell state is inherited by its nested trusted helper calls.
# shellcheck disable=SC2030,SC2031

# Explicit trusted fixture API; production always supplies literal empty TOOLS.
cfmgr_archive_test() (
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
	[ "$#" -eq 14 ] && [ -n "$1" ] || return 2
	_cfmgr_archive_run "$@"
	_cfmgr_fetch_public_status "$?"
) >/dev/null 2>&1

# TOOLS DIRECTORY SOURCE followed by reviewed archive/outer/data-gz/data-tar
# size/hash pairs, fixed MEMBER and its size/hash. No original-source EOF scan.
_cfmgr_archive_run() (
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
	[ "$#" -eq 14 ] || return 2
	_fetch_tools=$1
	_archive_directory=$2
	_archive_source=$3
	_archive_size=$4
	_archive_sha256=$5
	_archive_outer_size=$6
	_archive_outer_sha256=$7
	_archive_data_gz_size=$8
	_archive_data_gz_sha256=$9
	_archive_data_tar_size=${10}
	_archive_data_tar_sha256=${11}
	_archive_member=${12}
	_archive_member_size=${13}
	_archive_member_sha256=${14}
	if [ -n "$_fetch_tools" ]; then
		_cfmgr_fetch_path "$_fetch_tools"
		_cfmgr_fetch_protocol_status "$?" || return "$?"
		[ -d "$_fetch_tools" ] && [ ! -L "$_fetch_tools" ] || return 2
	fi
	_cfmgr_fetch_path "$_archive_directory"
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_cfmgr_fetch_path "$_archive_source"
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	for _archive_limit_value in "$_archive_size" "$_archive_outer_size" "$_archive_data_gz_size"; do
		_cfmgr_archive_size "$_archive_limit_value" 65536
		_cfmgr_fetch_protocol_status "$?" || return "$?"
	done
	for _archive_limit_value in "$_archive_data_tar_size" "$_archive_member_size"; do
		_cfmgr_archive_size "$_archive_limit_value" 131072
		_cfmgr_fetch_protocol_status "$?" || return "$?"
	done
	for _archive_hash_value in "$_archive_sha256" "$_archive_outer_sha256" \
		"$_archive_data_gz_sha256" "$_archive_data_tar_sha256" "$_archive_member_sha256"; do
		[ "${#_archive_hash_value}" -eq 64 ] || return 2
		case $_archive_hash_value in *[!0123456789abcdef]*) return 2 ;; esac
	done
	case $_archive_member in ./opt/libexec/timeout-coreutils | ./opt/libexec/gzip-gnu) ;; *) return 2 ;; esac
	_cfmgr_closure_file "$_archive_source" || return 10
	[ ! -e "$_archive_directory" ] && [ ! -L "$_archive_directory" ] || return 10
	# Clear injection controls before the first external executable, including
	# env itself. Every dd/gunzip/tar/hash producer receives only fixed env.
	unset ENV BASH_ENV CDPATH TZ GZIP TAR_OPTIONS
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	unset OPENSSL_CONF OPENSSL_CONF_INCLUDE OPENSSL_ENGINES OPENSSL_MODULES
	_archive_mkdir=$(_cfmgr_fetch_find mkdir)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_archive_dd=$(_cfmgr_fetch_find dd)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_archive_gunzip=$(_cfmgr_fetch_find gunzip)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_archive_tar=$(_cfmgr_fetch_find tar)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_env=$(_cfmgr_fetch_find env)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_wc=$(_cfmgr_fetch_find wc)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_openssl=$(_cfmgr_fetch_find openssl)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	_fetch_hexdump=$(_cfmgr_fetch_find hexdump)
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	"$_archive_mkdir" -m 700 "$_archive_directory"
	_cfmgr_fetch_native_status "$?" || return "$?"
	[ -d "$_archive_directory" ] && [ ! -L "$_archive_directory" ] || return 10
	_archive_copy=$_archive_directory/archive.ipk
	_archive_outer=$_archive_directory/outer.tar
	_archive_data_gz=$_archive_directory/data.tar.gz
	_archive_data_tar=$_archive_directory/data.tar
	_archive_program=$_archive_directory/program
	# The only read of the unapproved SOURCE is capped independently of EOF.
	(
		trap - 0 HUP INT TERM
		set -C || exit 10
		command exec <"$_archive_source" >"$_archive_copy" 2>/dev/null || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_archive_dd" bs=65536 count=2
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_cfmgr_archive_verify "$_archive_copy" "$_archive_size" "$_archive_sha256" archive
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	# Each physical output cap allows overflow evidence before exact acceptance.
	# These are separate synchronous commands, never tar-z or shell pipelines.
	(
		trap - 0 HUP INT TERM
		ulimit -f "$(((_archive_outer_size + 512) / 512))" || exit 10
		set -C || exit 10
		command exec <"$_archive_copy" >"$_archive_outer" 2>/dev/null || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_archive_gunzip" -c
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_cfmgr_archive_verify "$_archive_outer" "$_archive_outer_size" "$_archive_outer_sha256" outer
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	(
		trap - 0 HUP INT TERM
		ulimit -f "$(((_archive_data_gz_size + 512) / 512))" || exit 10
		set -C || exit 10
		command exec <"$_archive_outer" >"$_archive_data_gz" 2>/dev/null || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_archive_tar" -xOf - ./data.tar.gz
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_cfmgr_archive_verify "$_archive_data_gz" "$_archive_data_gz_size" "$_archive_data_gz_sha256" data-gz
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	(
		trap - 0 HUP INT TERM
		ulimit -f "$(((_archive_data_tar_size + 512) / 512))" || exit 10
		set -C || exit 10
		command exec <"$_archive_data_gz" >"$_archive_data_tar" 2>/dev/null || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_archive_gunzip" -c
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_cfmgr_archive_verify "$_archive_data_tar" "$_archive_data_tar_size" "$_archive_data_tar_sha256" data-tar
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	(
		trap - 0 HUP INT TERM
		ulimit -f "$(((_archive_member_size + 512) / 512))" || exit 10
		set -C || exit 10
		command exec <"$_archive_data_tar" >"$_archive_program" 2>/dev/null || exit 10
		exec "$_fetch_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
			"$_archive_tar" -xOf - "$_archive_member"
	)
	_cfmgr_fetch_native_status "$?" || return "$?"
	_cfmgr_archive_verify "$_archive_program" "$_archive_member_size" "$_archive_member_sha256" program
	_cfmgr_fetch_protocol_status "$?"
) >/dev/null 2>&1

_cfmgr_archive_size() {
	[ "$#" -eq 2 ] || return 2
	case $1 in '' | 0* | *[!0123456789]*) return 2 ;; esac
	[ "${#1}" -le 6 ] && [ "$1" -le "$2" ] || return 2
}

# Stage labels and output paths are fixed by the trusted caller above.
_cfmgr_archive_verify() {
	_archive_actual_size=$(_cfmgr_closure_size_owned "$_fetch_wc" "$1")
	_cfmgr_fetch_protocol_status "$?" || return "$?"
	[ "$_archive_actual_size" = "$2" ] || return 10
	_cfmgr_fetch_hash "$1" "$3" "$_archive_directory/$4.digest" "$_archive_directory/$4.hex"
	_cfmgr_fetch_protocol_status "$?"
}
