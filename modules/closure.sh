#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Fixed-profile copying/integrity only; no execution, provenance or ELF admission.
# Source defines functions only. The trusted native owner disables tracing and
# supplies approved identities, stable private inputs, retained BASE and fresh
# private RAM GUARD outside IO scratch. Trusted ancestors/native tools and no
# other writers are preconditions, not atomic path or hostile-root guarantees.
# The caller must first construct/acquire MANIFEST within 4096 original bytes in
# private RAM. Its wc check is defensive acceptance validation, not a bounded
# acquisition primitive: native wc reads the supplied file through EOF.
# Caller owns signals/cleanup. Failure retains partial staging; nothing is removed.

_cfmgr_closure_stage() {
	_cfmgr_closure_reset
	[ "$#" -eq 5 ] || return 2
	_cfmgr_closure_run '' "$1" "$2" "$3" "$4" "$5" /proc/self/fd/9
}

# Explicit trusted fixture API; never selected through production environment.
cfmgr_closure_test() {
	_cfmgr_closure_reset
	[ "$#" -eq 7 ] && [ -n "$7" ] || return 2
	_cfmgr_closure_run "$7" "$1" "$2" "$3" "$4" "$5" "$6"
}

_cfmgr_closure_reset() {
	_closure_complete=0
	_closure_opt=
	_closure_total=
}

_cfmgr_closure_run() {
	[ "$#" -eq 7 ] || return 2
	_closure_tools=$1
	_closure_guard=$2
	_closure_profile=$3
	_closure_manifest_file=$4
	_closure_timeout=$5
	_closure_gzip=$6
	_closure_base=$7
	case $_closure_profile in
	aarch64-k3.10) _closure_loader=ld-linux-aarch64.so.1 ;;
	armv7sf-k3.2) _closure_loader=ld-linux.so.3 ;;
	mipselsf-k3.4) _closure_loader=ld.so.1 ;;
	*) return 2 ;;
	esac
	for _closure_path in "$_closure_guard" "$_closure_manifest_file" "$_closure_timeout" "$_closure_gzip"; do
		_cfmgr_closure_path "$_closure_path" || return 2
	done
	[ -d "$_closure_guard" ] && [ ! -L "$_closure_guard" ] || return 1
	if [ -n "$_closure_tools" ]; then
		_cfmgr_closure_path "$_closure_tools" && _cfmgr_closure_path "$_closure_base" || return 2
		[ -d "$_closure_tools" ] && [ ! -L "$_closure_tools" ] || return 1
		[ -d "$_closure_base" ] && [ ! -L "$_closure_base" ] || return 1
	else
		[ "$_closure_base" = /proc/self/fd/9 ] && [ -d /proc/self/fd/9 ] || return 1
	fi
	[ -d "$_closure_base/lib" ] && [ ! -L "$_closure_base/lib" ] || return 1
	_cfmgr_closure_file "$_closure_timeout" && _cfmgr_closure_file "$_closure_gzip" || return 1
	_closure_stage=$_closure_guard/closure
	[ ! -e "$_closure_stage" ] && [ ! -L "$_closure_stage" ] || return 1
	_closure_mkdir=$(_cfmgr_closure_find mkdir) || return 1
	_closure_dd=$(_cfmgr_closure_find dd) || return 1
	_closure_wc=$(_cfmgr_closure_find wc) || return 1
	_closure_env=$(_cfmgr_closure_find env) || return 1
	_closure_openssl=$(_cfmgr_closure_find openssl) || return 1
	_closure_hexdump=$(_cfmgr_closure_find hexdump) || return 1
	_closure_ln=$(_cfmgr_closure_find ln) || return 1
	_closure_chmod=$(_cfmgr_closure_find chmod) || return 1
	_cfmgr_closure_manifest "$_closure_profile" "$_closure_manifest_file" "$_closure_wc" || return 1
	# Admit every source's shape before allocating or copying any staging file.
	while IFS= read -r _closure_row; do
		_closure_relative=${_closure_row%%"$_closure_tab"*}
		case $_closure_relative in
		lib/*) _cfmgr_closure_file "$_closure_base/$_closure_relative" || return 1 ;;
		esac
	done <<EOF_MANIFEST
$_closure_manifest_text
EOF_MANIFEST
	_cfmgr_closure_build || return 1
	_closure_opt=$_closure_stage/opt
	_closure_total=$_closure_manifest_total
	_closure_complete=1
} >/dev/null 2>&1

_cfmgr_closure_path() (
	LC_ALL=C
	export LC_ALL
	[ "$#" -eq 1 ] && [ "${#1}" -le 4096 ] || return 1
	case $1 in /*) ;; *) return 1 ;; esac
	case $1 in / | */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 1 ;; esac
)

_cfmgr_closure_file() {
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -r "$1" ]
}

_cfmgr_closure_find() {
	case $1 in mkdir | dd | wc | env | openssl | hexdump | ln | chmod) ;; *) return 1 ;; esac
	if [ -n "$_closure_tools" ]; then
		[ -x "$_closure_tools/$1" ] && [ ! -d "$_closure_tools/$1" ] || return 1
		printf '%s\n' "$_closure_tools/$1"
		return
	fi
	for _closure_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_closure_dir/$1" ] && [ ! -d "$_closure_dir/$1" ]; then
			printf '%s\n' "$_closure_dir/$1"
			return
		fi
	done
	return 1
}

# Caller locale is C; input is a stable, already bounded private RAM manifest.
# Exact fixed rows reconstruct every original byte, including
# each terminal LF; shell normalization/NUL removal therefore cannot be accepted.
_cfmgr_closure_manifest() {
	_closure_manifest_text=
	_closure_manifest_total=
	if _cfmgr_closure_manifest_read "$@"; then
		return 0
	else
		_closure_manifest_result=$?
	fi
	_closure_manifest_text=
	_closure_manifest_total=
	return "$_closure_manifest_result"
} >/dev/null 2>&1

_cfmgr_closure_manifest_read() {
	[ "$#" -eq 3 ] || return 2
	_closure_parse_profile=$1
	_closure_parse_file=$2
	_closure_parse_wc=$3
	case $_closure_parse_profile in aarch64-k3.10 | armv7sf-k3.2 | mipselsf-k3.4) ;; *) return 2 ;; esac
	_cfmgr_closure_file "$_closure_parse_file" || return 1
	_closure_manifest_bytes=$(_cfmgr_closure_size "$_closure_parse_wc" "$_closure_parse_file") || return 1
	[ "$_closure_manifest_bytes" -gt 0 ] && [ "$_closure_manifest_bytes" -le 4096 ] || return 1
	_closure_tab=$(printf '\t')
	_closure_lf='
'
	set -- lib/ld-2.27.so lib/libc-2.27.so lib/libpthread-2.27.so lib/librt-2.27.so
	if [ "$_closure_parse_profile" != aarch64-k3.10 ]; then
		set -- "$@" lib/libgcc_s.so.1
	fi
	set -- "$@" libexec/timeout-coreutils libexec/gzip-gnu
	_closure_parse_text=
	_closure_parse_total=0
	{
		for _closure_expected; do
			_closure_line=
			IFS= read -r _closure_line || return 1
			case $_closure_line in "$_closure_expected$_closure_tab"*) ;; *) return 1 ;; esac
			_closure_fields=${_closure_line#"$_closure_expected$_closure_tab"}
			_closure_length=${_closure_fields%%"$_closure_tab"*}
			_closure_hash=${_closure_fields#*"$_closure_tab"}
			[ "$_closure_fields" != "$_closure_hash" ] || return 1
			case $_closure_length in '' | 0* | *[!0123456789]*) return 1 ;; esac
			[ "${#_closure_length}" -le 7 ] && [ "$_closure_length" -le 4194304 ] || return 1
			[ "${#_closure_hash}" -eq 64 ] || return 1
			case $_closure_hash in *[!0123456789abcdef]*) return 1 ;; esac
			_closure_parse_total=$((_closure_parse_total + _closure_length))
			[ "$_closure_parse_total" -le 8388608 ] || return 1
			_closure_parse_text=$_closure_parse_text$_closure_line$_closure_lf
		done
		_closure_line=
		! IFS= read -r _closure_line && [ -z "$_closure_line" ] || return 1
	} <"$_closure_parse_file" || return 1
	[ "${#_closure_parse_text}" -eq "$_closure_manifest_bytes" ] || return 1
	_closure_manifest_text=$_closure_parse_text
	_closure_manifest_total=$_closure_parse_total
}

_cfmgr_closure_size() (
	[ "$#" -eq 2 ] && _cfmgr_closure_file "$2" || return 1
	_closure_count=$("$1" -c <"$2") || return 1
	while :; do
		case $_closure_count in ' '* | '	'*) _closure_count=${_closure_count#?} ;; *) break ;; esac
	done
	case $_closure_count in '' | *[!0123456789]* | 0[0123456789]*) return 1 ;; esac
	[ "${#_closure_count}" -le 8 ] || return 1
	printf '%s\n' "$_closure_count"
) 2>/dev/null

_cfmgr_closure_build() (
	trap - 0
	set +e
	set +u
	set -f
	umask 077
	LC_ALL=C
	export LC_ALL
	"$_closure_mkdir" -m 700 "$_closure_stage" || return 1
	"$_closure_mkdir" -m 700 "$_closure_stage/opt" "$_closure_stage/opt/lib" \
		"$_closure_stage/opt/libexec" "$_closure_stage/metadata" || return 1
	_closure_index=0
	while IFS= read -r _closure_row; do
		[ -n "$_closure_row" ] || break
		_closure_relative=${_closure_row%%"$_closure_tab"*}
		_closure_fields=${_closure_row#*"$_closure_tab"}
		_closure_length=${_closure_fields%%"$_closure_tab"*}
		_closure_expected_hash=${_closure_fields#*"$_closure_tab"}
		case $_closure_relative in
		lib/*) _closure_source=$_closure_base/$_closure_relative ;;
		libexec/timeout-coreutils) _closure_source=$_closure_timeout ;;
		libexec/gzip-gnu) _closure_source=$_closure_gzip ;;
		*) return 1 ;;
		esac
		_closure_destination=$_closure_stage/opt/$_closure_relative
		_closure_index=$((_closure_index + 1))
		_cfmgr_closure_copy "$_closure_source" "$_closure_destination" "$_closure_length" || return 1
		_closure_copied=$(_cfmgr_closure_size "$_closure_wc" "$_closure_destination") || return 1
		[ "$_closure_copied" -eq "$_closure_length" ] || return 1
		_cfmgr_closure_hash "$_closure_destination" "$_closure_expected_hash" "$_closure_index" || return 1
	done <<EOF_MANIFEST
$_closure_manifest_text
EOF_MANIFEST
	for _closure_link in libc.so.6 libpthread.so.0 librt.so.1 "$_closure_loader"; do
		case $_closure_link in
		libc.so.6) _closure_target=libc-2.27.so ;;
		libpthread.so.0) _closure_target=libpthread-2.27.so ;;
		librt.so.1) _closure_target=librt-2.27.so ;;
		*) _closure_target=ld-2.27.so ;;
		esac
		"$_closure_ln" -s "$_closure_target" "$_closure_stage/opt/lib/$_closure_link" || return 1
	done
	"$_closure_chmod" 0555 "$_closure_stage/opt/lib/ld-2.27.so" \
		"$_closure_stage/opt/lib/libc-2.27.so" "$_closure_stage/opt/lib/libpthread-2.27.so" \
		"$_closure_stage/opt/lib/librt-2.27.so" "$_closure_stage/opt/libexec/timeout-coreutils" \
		"$_closure_stage/opt/libexec/gzip-gnu" || return 1
	if [ "$_closure_profile" != aarch64-k3.10 ]; then
		"$_closure_chmod" 0444 "$_closure_stage/opt/lib/libgcc_s.so.1" || return 1
	fi
	"$_closure_chmod" 0555 "$_closure_stage/opt/lib" "$_closure_stage/opt/libexec" "$_closure_stage/opt" || return 1
)

_cfmgr_closure_copy() (
	[ "$#" -eq 3 ] || return 1
	_closure_blocks=$((($3 + 65536) / 65536))
	set -C
	"$_closure_dd" bs=65536 count="$_closure_blocks" \
		<"$1" >"$2"
)

_cfmgr_closure_hash() (
	[ "$#" -eq 3 ] || return 1
	# Clear inherited controls before the first external env/OpenSSL execution.
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	unset OPENSSL_CONF OPENSSL_CONF_INCLUDE OPENSSL_ENGINES OPENSSL_MODULES
	_closure_digest=$_closure_stage/metadata/$3.digest
	_closure_hex_file=$_closure_stage/metadata/$3.hex
	ulimit -f 1 || return 1
	set -C
	"$_closure_env" -i LC_ALL=C OPENSSL_CONF=/dev/null PATH=/sbin:/bin:/usr/sbin:/usr/bin \
		"$_closure_openssl" dgst -sha256 -binary <"$1" >"$_closure_digest" || return 1
	[ "$(_cfmgr_closure_size "$_closure_wc" "$_closure_digest")" = 32 ] || return 1
	"$_closure_hexdump" -v -n 32 -e '1/1 "%02x"' <"$_closure_digest" >"$_closure_hex_file" || return 1
	[ "$(_cfmgr_closure_size "$_closure_wc" "$_closure_hex_file")" = 64 ] || return 1
	_closure_hash_value=
	IFS= read -r _closure_hash_value <"$_closure_hex_file" && return 1
	[ "${#_closure_hash_value}" -eq 64 ] || return 1
	case $_closure_hash_value in *[!0123456789abcdef]*) return 1 ;; esac
	[ "$_closure_hash_value" = "$2" ]
)
