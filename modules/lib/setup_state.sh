#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Supplied setup-state projection; source trusted io.sh/json.sh/config.sh first.
# Private immutable inputs/code/ancestors and unaliased ownership are caller
# prerequisites. This checks recorded claims, not installation or authority.
# shellcheck disable=SC2154

cfmgr_setup_state_report() {
	[ "$#" -eq 5 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_setup_state_action "$2" "$3" "$4" "$5"
}

# Explicit trusted fixture tools, never a production environment selector.
cfmgr_setup_state_test() {
	[ "$#" -eq 6 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_setup_state_action "$3" "$4" "$5" "$6"
}

_cfmgr_setup_state_action() {
	[ "$#" -eq 5 ] && [ "${_io_active-}" = 1 ] || return 2
	_setup_config_check=
	[ -f "$2" ] && [ ! -L "$2" ] && [ -r "$2" ] || return 1
	cfmgr_io_capture 3 256 4096 cat <"$2" || return 1
	_cfmgr_io_capture_status 3 || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	_cfmgr_setup_state_decode "$_io_stage/3.out" "$_io_out_bytes" || return "$?"
	case $_setup_state in
	retained | installing | removing-keep | removing-wipe | resetting)
		_setup_config_check=not-read
		;;
	installed | reset-passive)
		_cfmgr_config_projection_capture lifecycle "$3" "$4" "$5" || return "$?"
		# The relationship seam deliberately accepts no positional arguments.
		# shellcheck disable=SC2119
		_cfmgr_setup_state_config_check || return "$?"
		;;
	esac
	_setup_report_body="setup-state${_io_tab}1$_io_tab$_setup_state$_io_tab$_setup_generation$_io_tab$_setup_identity$_io_lf"
	_setup_report_body="${_setup_report_body}config-check$_io_tab$_setup_config_check$_io_lf"
	cfmgr_io_stage_report "${_setup_report_body}end$_io_tab${#_setup_report_body}$_io_lf"
}

# Fixed four-row guard, reconstructed against the original captured byte count.
_cfmgr_setup_state_decode() {
	[ "$#" -eq 2 ] && [ "${_io_active-}" = 1 ] || return 2
	_setup_state=
	_setup_generation=
	_setup_identity=
	_cfmgr_io_limit "$2" && [ "$2" -gt 0 ] && [ "$2" -le 256 ] || return 1
	[ -f "$1" ] && [ ! -L "$1" ] && [ -r "$1" ] || return 1
	_setup_guard_header=
	_setup_guard_state=
	_setup_guard_generation=
	_setup_guard_identity=
	_setup_guard_extra=
	{
		IFS= read -r _setup_guard_header && IFS= read -r _setup_guard_state &&
			IFS= read -r _setup_guard_generation && IFS= read -r _setup_guard_identity &&
			! IFS= read -r _setup_guard_extra && [ -z "$_setup_guard_extra" ]
	} <"$1" || return 1
	[ "$_setup_guard_header" = 'setup-state: 1' ] || return 1
	case $_setup_guard_state in 'state: '*) ;; *) return 1 ;; esac
	_setup_checked_state=${_setup_guard_state#state: }
	case $_setup_checked_state in
	installed | retained | installing | removing-keep | removing-wipe | resetting | reset-passive) ;;
	*) return 1 ;;
	esac
	case $_setup_guard_generation in 'generation: '*) ;; *) return 1 ;; esac
	_setup_checked_generation=${_setup_guard_generation#generation: }
	case $_setup_checked_generation in
	unknown)
		case $_setup_checked_state in
		installing | removing-keep | removing-wipe | resetting) ;;
		*) return 1 ;;
		esac
		;;
	'' | *[!0123456789]* | 0[0123456789]*) return 1 ;;
	*)
		[ "${#_setup_checked_generation}" -le 10 ] &&
			_cfmgr_config_generation_bound "$_setup_checked_generation" || return 1
		;;
	esac
	case $_setup_guard_identity in 'identity: '*) ;; *) return 1 ;; esac
	_setup_checked_identity=${_setup_guard_identity#identity: }
	case $_setup_checked_identity in '' | *[!0123456789abcdef]*) return 1 ;; esac
	[ "${#_setup_checked_identity}" -eq 32 ] || return 1
	_setup_guard_expected="setup-state: 1${_io_lf}state: $_setup_checked_state${_io_lf}generation: $_setup_checked_generation${_io_lf}identity: $_setup_checked_identity$_io_lf"
	[ "${#_setup_guard_expected}" -eq "$2" ] || return 1
	_setup_state=$_setup_checked_state
	_setup_generation=$_setup_checked_generation
	_setup_identity=$_setup_checked_identity
}

# Only decoded guard/lifecycle fields enter this saved-state relationship check.
# shellcheck disable=SC2120
_cfmgr_setup_state_config_check() {
	[ "$#" -eq 0 ] && [ "${_io_active-}" = 1 ] || return 2
	_setup_config_check=
	[ "$_setup_generation" = "$_config_generation" ] || return 1
	case $_setup_state in
	installed) _setup_config_check=lifecycle-match ;;
	reset-passive)
		for _setup_flag in "$_config_developer" "$_config_cloudflared_configured" \
			"$_config_cloudflared_enabled" "$_config_cloudflared_maintenance_enabled" \
			"$_config_ddns_configured" "$_config_ddns_enabled" \
			"$_config_ip_sync_configured" "$_config_ip_sync_enabled"; do
			[ "$_setup_flag" = false ] || return 1
		done
		[ "$_config_cloudflared_mode" = none ] || return 1
		_setup_config_check=passive-match
		;;
	*) return 2 ;;
	esac
}
