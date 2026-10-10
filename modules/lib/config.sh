#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Owned header/lifecycle projections; source trusted io.sh/json.sh first.
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

cfmgr_config_lifecycle_report() {
	[ "$#" -eq 4 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_config_lifecycle_action "$2" "$3" "$4"
}

cfmgr_config_lifecycle_test() {
	[ "$#" -eq 5 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_config_lifecycle_action "$3" "$4" "$5"
}

_cfmgr_config_header_action() {
	[ "$#" -eq 4 ] && [ "${_io_active-}" = 1 ] || return 2
	_cfmgr_config_projection_action header "$@"
}

_cfmgr_config_lifecycle_action() {
	[ "$#" -eq 4 ] && [ "${_io_active-}" = 1 ] || return 2
	_cfmgr_config_projection_action lifecycle "$@"
}

# Fixed internal projection selector; no ambient mode or operational callbacks.
_cfmgr_config_projection_action() {
	[ "$#" -eq 5 ] && [ "${_io_active-}" = 1 ] || return 2
	_cfmgr_config_projection_capture "$1" "$3" "$4" "$5" || return "$?"
	case $1 in
	header) cfmgr_io_stage_report "$_config_header_ledger" ;;
	lifecycle) cfmgr_io_stage_report "$_config_lifecycle_ledger" ;;
	esac
}

# Same owner and fixed slots, with publication left to the composing action.
_cfmgr_config_projection_capture() {
	[ "$#" -eq 4 ] && [ "${_io_active-}" = 1 ] || return 2
	case $1 in header | lifecycle) ;; *) return 2 ;; esac
	_config_projection_mode=$1
	case $4 in /*) ;; *) return 2 ;; esac
	[ -f "$4" ] && [ ! -L "$4" ] && [ -r "$4" ] || return 2
	_cfmgr_json_tokens_capture "$2" "$3" 0 1 || return "$?"
	cfmgr_io_capture 2 256 4096 awk -v "cfmgr_config_header_size=$_json_tokens_bytes" \
		-v "cfmgr_config_header_mode=$_config_projection_mode" -f "$4" <"$_json_tokens_file" || return 1
	_cfmgr_io_capture_status 2 || return 1
	[ "$_io_err_bytes" -eq 0 ] || return 1
	case $_io_producer in 0) ;; 2) return 2 ;; *) return 1 ;; esac
	case $_config_projection_mode in
	header)
		_cfmgr_config_header_decode "$_io_stage/2.out" "$_io_out_bytes"
		;;
	lifecycle)
		_cfmgr_config_lifecycle_decode "$_io_stage/2.out" "$_io_out_bytes"
		;;
	esac
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
	_cfmgr_config_projection_header "$_config_header_line" config-header || return 1
	_config_generation=$_config_checked_generation
	_config_developer=$_config_checked_developer
	_config_header_body=$_config_header_line$_io_lf
	_config_header_expected_footer="end$_io_tab${#_config_header_body}"
	[ "$_config_header_footer" = "$_config_header_expected_footer" ] &&
		[ "$_config_header_bytes" -eq "$((${#_config_header_body} + ${#_config_header_expected_footer} + 1))" ] || return 1
	_config_header_ledger=$_config_header_body$_config_header_footer$_io_lf
}

# Shared fixed header-row validation; lifecycle publishes these fields only
# after every feature row, relationship, footer and original byte count passes.
_cfmgr_config_projection_header() {
	_config_expected_kind=$2
	_config_projection_line=$1
	_config_saved_ifs=$IFS
	IFS=$_io_tab
	# Owner has noglob set; reconstruction rejects empty/tab field collapse.
	# shellcheck disable=SC2086
	set -- $_config_projection_line
	IFS=$_config_saved_ifs
	[ "$#" -eq 4 ] && [ "$1" = "$_config_expected_kind" ] && [ "$2" = 1 ] || return 1
	case $3 in '' | *[!0123456789]* | 0[0123456789]*) return 1 ;; esac
	[ "${#3}" -le 10 ] && _cfmgr_config_generation_bound "$3" || return 1
	case $4 in true | false) ;; *) return 1 ;; esac
	[ "$1$_io_tab$2$_io_tab$3$_io_tab$4" = "$_config_projection_line" ] || return 1
	_config_checked_generation=$3
	_config_checked_developer=$4
}

_cfmgr_config_lifecycle_decode() {
	[ "$#" -eq 2 ] && [ "${_io_active-}" = 1 ] || return 2
	_config_lifecycle_ledger=
	_config_generation=
	_config_developer=
	_config_cloudflared_configured=
	_config_cloudflared_enabled=
	_config_cloudflared_maintenance_enabled=
	_config_cloudflared_mode=
	_config_ddns_configured=
	_config_ddns_enabled=
	_config_ip_sync_configured=
	_config_ip_sync_enabled=
	_config_lifecycle_file=$1
	_config_lifecycle_bytes=$2
	_cfmgr_io_limit "$2" && [ "$2" -gt 0 ] && [ "$2" -le 256 ] || return 1
	[ -f "$1" ] && [ ! -L "$1" ] && [ -r "$1" ] || return 1
	_config_lifecycle_header=
	_config_lifecycle_cloudflared=
	_config_lifecycle_ddns=
	_config_lifecycle_ip_sync=
	_config_lifecycle_footer=
	_config_lifecycle_extra=
	{
		IFS= read -r _config_lifecycle_header && IFS= read -r _config_lifecycle_cloudflared &&
			IFS= read -r _config_lifecycle_ddns && IFS= read -r _config_lifecycle_ip_sync &&
			IFS= read -r _config_lifecycle_footer && ! IFS= read -r _config_lifecycle_extra &&
			[ -z "$_config_lifecycle_extra" ]
	} <"$_config_lifecycle_file" || return 1
	_cfmgr_config_projection_header "$_config_lifecycle_header" config-lifecycle || return 1
	_config_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_config_lifecycle_cloudflared
	IFS=$_config_saved_ifs
	[ "$#" -eq 5 ] && [ "$1" = cloudflared ] || return 1
	for _config_flag in "$2" "$3" "$4"; do
		case $_config_flag in true | false) ;; *) return 1 ;; esac
	done
	case $5 in none | token | advanced) ;; *) return 1 ;; esac
	[ "$1$_io_tab$2$_io_tab$3$_io_tab$4$_io_tab$5" = "$_config_lifecycle_cloudflared" ] || return 1
	[ "$3" != true ] || { [ "$2" = true ] && [ "$4" = true ]; } || return 1
	case $2:$5 in false:none | true:token | true:advanced) ;; *) return 1 ;; esac
	_config_lifecycle_cf_configured=$2
	_config_lifecycle_cf_enabled=$3
	_config_lifecycle_cf_maintenance=$4
	_config_lifecycle_cf_mode=$5
	_cfmgr_config_lifecycle_feature "$_config_lifecycle_ddns" ddns || return 1
	_config_lifecycle_ddns_configured=$_config_feature_configured
	_config_lifecycle_ddns_enabled=$_config_feature_enabled
	_cfmgr_config_lifecycle_feature "$_config_lifecycle_ip_sync" ip-sync || return 1
	_config_lifecycle_body=$_config_lifecycle_header$_io_lf$_config_lifecycle_cloudflared$_io_lf
	_config_lifecycle_body=$_config_lifecycle_body$_config_lifecycle_ddns$_io_lf$_config_lifecycle_ip_sync$_io_lf
	_config_lifecycle_expected_footer="end$_io_tab${#_config_lifecycle_body}"
	[ "$_config_lifecycle_footer" = "$_config_lifecycle_expected_footer" ] &&
		[ "$_config_lifecycle_bytes" -eq "$((${#_config_lifecycle_body} + ${#_config_lifecycle_expected_footer} + 1))" ] || return 1
	_config_lifecycle_ledger=$_config_lifecycle_body$_config_lifecycle_footer$_io_lf
	_config_generation=$_config_checked_generation
	_config_developer=$_config_checked_developer
	_config_cloudflared_configured=$_config_lifecycle_cf_configured
	_config_cloudflared_enabled=$_config_lifecycle_cf_enabled
	_config_cloudflared_maintenance_enabled=$_config_lifecycle_cf_maintenance
	_config_cloudflared_mode=$_config_lifecycle_cf_mode
	_config_ddns_configured=$_config_lifecycle_ddns_configured
	_config_ddns_enabled=$_config_lifecycle_ddns_enabled
	_config_ip_sync_configured=$_config_feature_configured
	_config_ip_sync_enabled=$_config_feature_enabled
}

_cfmgr_config_lifecycle_feature() {
	_config_feature_line=$1
	_config_feature_name=$2
	_config_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_config_feature_line
	IFS=$_config_saved_ifs
	[ "$#" -eq 3 ] && [ "$1" = "$_config_feature_name" ] || return 1
	case $2 in true | false) ;; *) return 1 ;; esac
	case $3 in true | false) ;; *) return 1 ;; esac
	[ "$3" != true ] || [ "$2" = true ] || return 1
	[ "$1$_io_tab$2$_io_tab$3" = "$_config_feature_line" ] || return 1
	_config_feature_configured=$2
	_config_feature_enabled=$3
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
