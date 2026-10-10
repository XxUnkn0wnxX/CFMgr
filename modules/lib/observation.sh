#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Pure supplied observation freshness policy. Source trusted common.sh first.
# Sourcing defines functions only; the subshell isolates caller state and scratch.
# ID shape/equality proves neither authentication nor complete acquisition. IDs
# bind family/profile/WAN/protocol/interface/address/prefix/source policy/relevant
# config, including administrative/family intent and observation kind/result.
# Known not-applicable values differ from missing acquisition. Supply a coherent
# current snapshot with recomputed ID; recheck identity/generation before use.
# OBSERVED is floored monotonic time no later than acquisition; NOW follows
# collection. Finite lifetime is conservative relative to OBSERVED, including
# acquisition delay. Strict age caps conservatively bound the actual elapsed age.
# Inactive/removal observations require the same freshness; no action authority.

cfmgr_observation_freshness_report() (
	[ "$#" -eq 10 ] || return 1
	for _cfmgr_obs_boot in "$1" "$2"; do
		[ "$_cfmgr_obs_boot" != - ] || continue
		[ "${#_cfmgr_obs_boot}" -eq 36 ] || return 1
		_cfmgr_obs_boot_remaining=$_cfmgr_obs_boot
		for _cfmgr_obs_group_length in 8 4 4 4 12; do
			_cfmgr_obs_group=${_cfmgr_obs_boot_remaining%%-*}
			[ "${#_cfmgr_obs_group}" -eq "$_cfmgr_obs_group_length" ] || return 1
			case $_cfmgr_obs_group in
			*[!0123456789abcdef]*) return 1 ;;
			esac
			if [ "$_cfmgr_obs_group_length" -eq 12 ]; then
				[ "$_cfmgr_obs_boot_remaining" = "$_cfmgr_obs_group" ] || return 1
			else
				[ "$_cfmgr_obs_boot_remaining" != "$_cfmgr_obs_group" ] || return 1
				_cfmgr_obs_boot_remaining=${_cfmgr_obs_boot_remaining#*-}
			fi
		done
	done
	for _cfmgr_obs_number in "$3" "$4" "$7" "$8"; do
		[ "$_cfmgr_obs_number" != - ] || continue
		[ "${#_cfmgr_obs_number}" -le 10 ] || return 1
		_cfmgr_obs_normalized=$(cfmgr_uint31 "$_cfmgr_obs_number") || return 1
		[ "$_cfmgr_obs_normalized" = "$_cfmgr_obs_number" ] || return 1
	done
	for _cfmgr_obs_id in "$5" "$6"; do
		[ "$_cfmgr_obs_id" != - ] || continue
		[ "${#_cfmgr_obs_id}" -eq 64 ] || return 1
		case $_cfmgr_obs_id in
		*[!0123456789abcdef]*) return 1 ;;
		esac
	done
	[ "${#9}" -le 10 ] || return 1
	_cfmgr_obs_max_age=$(cfmgr_uint31 "$9") || return 1
	[ "$_cfmgr_obs_max_age" = "$9" ] || return 1
	[ "$_cfmgr_obs_max_age" -ge 1 ] && [ "$_cfmgr_obs_max_age" -le 86400 ] || return 1
	_cfmgr_obs_valid_for=${10}
	case $_cfmgr_obs_valid_for in
	forever | -) ;;
	*)
		[ "${#_cfmgr_obs_valid_for}" -le 10 ] || return 1
		_cfmgr_obs_normalized=$(cfmgr_uint31 "$_cfmgr_obs_valid_for") || return 1
		[ "$_cfmgr_obs_normalized" = "$_cfmgr_obs_valid_for" ] || return 1
		;;
	esac

	# Validate every operand before considering even a known identity mismatch.
	_cfmgr_obs_state=unknown
	_cfmgr_obs_age=-
	if [ "$1" != - ] && [ "$2" != - ] && [ "$1" != "$2" ]; then
		_cfmgr_obs_state=stale
		_cfmgr_obs_reason=boot-changed
	elif [ "$3" != - ] && [ "$4" != - ] && [ "$3" != "$4" ]; then
		_cfmgr_obs_state=stale
		_cfmgr_obs_reason=generation-changed
	elif [ "$5" != - ] && [ "$6" != - ] && [ "$5" != "$6" ]; then
		_cfmgr_obs_state=stale
		_cfmgr_obs_reason=source-changed
	elif [ "$1" = - ] || [ "$2" = - ]; then
		_cfmgr_obs_reason=boot-unavailable
	elif [ "$3" = - ] || [ "$4" = - ]; then
		_cfmgr_obs_reason=generation-unavailable
	elif [ "$5" = - ] || [ "$6" = - ]; then
		_cfmgr_obs_reason=source-unavailable
	elif [ "$7" = - ] || [ "$8" = - ]; then
		_cfmgr_obs_reason=clock-unavailable
	elif [ "$8" -lt "$7" ]; then
		_cfmgr_obs_reason=clock-regressed
	else
		# Canonical uint31 operands and ordering bound subtraction to uint31.
		_cfmgr_obs_age=$(($8 - $7))
		if [ "$_cfmgr_obs_age" -ge "$_cfmgr_obs_max_age" ]; then
			_cfmgr_obs_state=stale
			_cfmgr_obs_reason=max-age-expired
		elif [ "$_cfmgr_obs_valid_for" = - ]; then
			_cfmgr_obs_reason=lifetime-unavailable
		elif [ "$_cfmgr_obs_valid_for" != forever ] &&
			[ "$_cfmgr_obs_age" -ge "$_cfmgr_obs_valid_for" ]; then
			_cfmgr_obs_state=stale
			_cfmgr_obs_reason=lifetime-expired
		else
			_cfmgr_obs_state=current
			_cfmgr_obs_reason=fresh
		fi
	fi

	# Validated ASCII fields make shell length exact; count the body LF too.
	_cfmgr_obs_row=$(printf 'observation-freshness\t1\t%s\t%s\t%s' \
		"$_cfmgr_obs_state" "$_cfmgr_obs_age" "$_cfmgr_obs_reason") || return 1
	_cfmgr_obs_body_bytes=$((${#_cfmgr_obs_row} + 1))
	printf '%s\nend\t%s\n' "$_cfmgr_obs_row" "$_cfmgr_obs_body_bytes" || return 1
) 2>/dev/null
