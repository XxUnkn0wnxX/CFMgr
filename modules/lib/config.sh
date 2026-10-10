#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Owned header projection only; explicitly source trusted io.sh/json.sh first.
# Private immutable input/code/ancestors and unaliased ownership are caller
# prerequisites. No other setting, credential or installed state is approved.
# shellcheck disable=SC2154

cfmgr_config_header_report() {
	[ "$#" -eq 4 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_config_header_action "$2" "$3" "$4"
}

# Explicit trusted fixture tools, never a production environment selector.
cfmgr_config_header_test() {
	[ "$#" -eq 5 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_config_header_action "$3" "$4" "$5"
}

_cfmgr_config_header_action() {
	[ "$#" -eq 4 ] && [ "${_io_active-}" = 1 ] || return 2
	case $4 in /*) ;; *) return 2 ;; esac
	[ -f "$4" ] && [ ! -L "$4" ] && [ -r "$4" ] || return 2
	_cfmgr_json_tokens_capture "$2" "$3" 0 1 || return "$?"
	cfmgr_io_capture 2 256 4096 awk -v "cfmgr_config_header_size=$_json_tokens_bytes" \
		-f "$4" <"$_json_tokens_file" || return 1
	_cfmgr_io_capture_status 2 || return 1
	[ "$_io_err_bytes" -eq 0 ] || return 1
	case $_io_producer in 0) ;; 2) return 2 ;; *) return 1 ;; esac
	_cfmgr_config_header_decode "$_io_stage/2.out" "$_io_out_bytes" || return "$?"
	cfmgr_io_stage_report "$_config_header_ledger"
}

# Reconstruct the tiny projection against the original captured bytes so read
# normalization cannot conceal NUL, incomplete final LF or trailing data.
_cfmgr_config_header_decode() {
	[ "$#" -eq 2 ] && [ "${_io_active-}" = 1 ] || return 2
	_config_header_ledger=
	_config_generation=
	_config_developer=
	_config_header_file=$1
	_config_header_bytes=$2
	_cfmgr_io_limit "$2" && [ "$2" -gt 0 ] && [ "$2" -le 256 ] || return 1
	[ -f "$1" ] && [ ! -L "$1" ] && [ -r "$1" ] || return 1
	_config_header_line=
	_config_header_footer=
	_config_header_extra=
	{
		IFS= read -r _config_header_line && IFS= read -r _config_header_footer &&
			! IFS= read -r _config_header_extra && [ -z "$_config_header_extra" ]
	} <"$_config_header_file" || return 1
	_config_saved_ifs=$IFS
	IFS=$_io_tab
	# Owner has noglob set; reconstruction rejects empty/tab field collapse.
	# shellcheck disable=SC2086
	set -- $_config_header_line
	IFS=$_config_saved_ifs
	[ "$#" -eq 4 ] && [ "$1" = config-header ] && [ "$2" = 1 ] || return 1
	_config_generation=$3
	_config_developer=$4
	case $3 in '' | *[!0123456789]* | 0[0123456789]*) return 1 ;; esac
	[ "${#3}" -le 10 ] || return 1
	_cfmgr_config_generation_bound "$3" || return 1
	case $4 in true | false) ;; *) return 1 ;; esac
	_config_header_body="$1$_io_tab$2$_io_tab$3$_io_tab$4"
	[ "$_config_header_body" = "$_config_header_line" ] || return 1
	_config_header_body=$_config_header_body$_io_lf
	_config_header_expected_footer="end$_io_tab${#_config_header_body}"
	[ "$_config_header_footer" = "$_config_header_expected_footer" ] &&
		[ "$_config_header_bytes" -eq "$((${#_config_header_body} + ${#_config_header_expected_footer} + 1))" ] || return 1
	_config_header_ledger=$_config_header_body$_config_header_footer$_io_lf
}

# The generation is already canonical and <=10 digits. Compare only individual
# digits to avoid overflowing a target's integer range on malformed projections.
_cfmgr_config_generation_bound() {
	[ "${#1}" -eq 10 ] || return 0
	_config_generation_left=$1
	_config_generation_right=2147483647
	while [ -n "$_config_generation_left" ]; do
		_config_generation_left_tail=${_config_generation_left#?}
		_config_generation_right_tail=${_config_generation_right#?}
		_config_generation_left_digit=${_config_generation_left%"$_config_generation_left_tail"}
		_config_generation_right_digit=${_config_generation_right%"$_config_generation_right_tail"}
		[ "$_config_generation_left_digit" -ge "$_config_generation_right_digit" ] || return 0
		[ "$_config_generation_left_digit" -le "$_config_generation_right_digit" ] || return 1
		_config_generation_left=$_config_generation_left_tail
		_config_generation_right=$_config_generation_right_tail
	done
}
