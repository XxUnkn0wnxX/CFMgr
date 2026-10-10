#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Pure address normalization, scope classification and supplied-observation
# comparison; no route, ownership or publish authority.
# Sourcing defines functions. Subshell bodies isolate caller state and scratch.

cfmgr_ipv4_normalize() (
	[ "$#" -eq 1 ] || return 1
	case $1 in
	'' | *[!0123456789.]*) return 1 ;;
	esac
	[ "${#1}" -le 15 ] || return 1
	_cfmgr_ip4_remaining=$1
	_cfmgr_ip4_count=0
	while :; do
		_cfmgr_ip4_octet=${_cfmgr_ip4_remaining%%.*}
		case $_cfmgr_ip4_octet in
		'' | 0[0123456789]*) return 1 ;;
		esac
		[ "${#_cfmgr_ip4_octet}" -le 3 ] || return 1
		[ "$_cfmgr_ip4_octet" -le 255 ] || return 1
		_cfmgr_ip4_count=$((_cfmgr_ip4_count + 1))
		[ "$_cfmgr_ip4_count" -le 4 ] || return 1
		case $_cfmgr_ip4_remaining in
		*.*) _cfmgr_ip4_remaining=${_cfmgr_ip4_remaining#*.} ;;
		*) break ;;
		esac
	done
	[ "$_cfmgr_ip4_count" -eq 4 ] || return 1
	printf '%s\n' "$1"
)

cfmgr_ipv6_normalize() (
	[ "$#" -eq 1 ] || return 1
	case $1 in
	'' | *[!0123456789abcdefABCDEF:.]*) return 1 ;;
	esac
	[ "${#1}" -le 45 ] || return 1
	_cfmgr_ip6_address=$1
	case $_cfmgr_ip6_address in
	*.*)
		# A strict terminal IPv4 tail occupies exactly two hexadecimal groups.
		_cfmgr_ip6_prefix=${_cfmgr_ip6_address%:*}
		[ "$_cfmgr_ip6_prefix" != "$_cfmgr_ip6_address" ] || return 1
		_cfmgr_ip6_ipv4=$(cfmgr_ipv4_normalize "${_cfmgr_ip6_address##*:}") || return 1
		IFS=.
		set -f
		# Canonical IPv4 contains only validated decimal octets and dots.
		# shellcheck disable=SC2086
		set -- $_cfmgr_ip6_ipv4
		_cfmgr_ip6_tail=$(printf '%x:%x' "$(($1 * 256 + $2))" "$(($3 * 256 + $4))")
		_cfmgr_ip6_address=$_cfmgr_ip6_prefix:$_cfmgr_ip6_tail
		;;
	esac
	# No dotted syntax may remain outside the terminal tail just converted.
	case $_cfmgr_ip6_address in
	*[!0123456789abcdefABCDEF:]*) return 1 ;;
	esac
	_cfmgr_ip6_compressed=0
	case $_cfmgr_ip6_address in
	*::*)
		_cfmgr_ip6_compressed=1
		_cfmgr_ip6_left=${_cfmgr_ip6_address%%::*}
		_cfmgr_ip6_right=${_cfmgr_ip6_address#*::}
		case $_cfmgr_ip6_right in
		*::*) return 1 ;;
		esac
		;;
	*)
		_cfmgr_ip6_left=$_cfmgr_ip6_address
		_cfmgr_ip6_right=
		;;
	esac

	_cfmgr_ip6_count=0
	_cfmgr_ip6_side=0
	_cfmgr_ip6_left_groups=
	_cfmgr_ip6_right_groups=
	for _cfmgr_ip6_remaining in "$_cfmgr_ip6_left" "$_cfmgr_ip6_right"; do
		_cfmgr_ip6_groups=
		if [ -n "$_cfmgr_ip6_remaining" ]; then
			case $_cfmgr_ip6_remaining in
			:* | *:) return 1 ;;
			esac
			while :; do
				_cfmgr_ip6_group=${_cfmgr_ip6_remaining%%:*}
				[ -n "$_cfmgr_ip6_group" ] && [ "${#_cfmgr_ip6_group}" -le 4 ] || return 1
				_cfmgr_ip6_value=0
				while [ -n "$_cfmgr_ip6_group" ]; do
					_cfmgr_ip6_rest=${_cfmgr_ip6_group#?}
					_cfmgr_ip6_digit=${_cfmgr_ip6_group%"$_cfmgr_ip6_rest"}
					case $_cfmgr_ip6_digit in
					[aA]) _cfmgr_ip6_digit=10 ;;
					[bB]) _cfmgr_ip6_digit=11 ;;
					[cC]) _cfmgr_ip6_digit=12 ;;
					[dD]) _cfmgr_ip6_digit=13 ;;
					[eE]) _cfmgr_ip6_digit=14 ;;
					[fF]) _cfmgr_ip6_digit=15 ;;
					esac
					_cfmgr_ip6_value=$((_cfmgr_ip6_value * 16 + _cfmgr_ip6_digit))
					_cfmgr_ip6_group=$_cfmgr_ip6_rest
				done
				_cfmgr_ip6_hex=$(printf '%x' "$_cfmgr_ip6_value")
				_cfmgr_ip6_groups="$_cfmgr_ip6_groups$_cfmgr_ip6_hex "
				_cfmgr_ip6_count=$((_cfmgr_ip6_count + 1))
				[ "$_cfmgr_ip6_count" -le 8 ] || return 1
				case $_cfmgr_ip6_remaining in
				*:*) _cfmgr_ip6_remaining=${_cfmgr_ip6_remaining#*:} ;;
				*) break ;;
				esac
			done
		fi
		if [ "$_cfmgr_ip6_side" -eq 0 ]; then
			_cfmgr_ip6_left_groups=$_cfmgr_ip6_groups
		else
			_cfmgr_ip6_right_groups=$_cfmgr_ip6_groups
		fi
		_cfmgr_ip6_side=1
	done

	_cfmgr_ip6_full=$_cfmgr_ip6_left_groups
	if [ "$_cfmgr_ip6_compressed" -eq 1 ]; then
		[ "$_cfmgr_ip6_count" -lt 8 ] || return 1
		_cfmgr_ip6_missing=$((8 - _cfmgr_ip6_count))
		while [ "$_cfmgr_ip6_missing" -gt 0 ]; do
			_cfmgr_ip6_full="${_cfmgr_ip6_full}0 "
			_cfmgr_ip6_missing=$((_cfmgr_ip6_missing - 1))
		done
	else
		[ "$_cfmgr_ip6_count" -eq 8 ] || return 1
	fi
	_cfmgr_ip6_full=$_cfmgr_ip6_full$_cfmgr_ip6_right_groups
	IFS=' '
	set -f
	# Exactly eight canonical hex groups, separated by our own spaces.
	# shellcheck disable=SC2086
	set -- $_cfmgr_ip6_full

	_cfmgr_ip6_index=0
	_cfmgr_ip6_run_length=0
	_cfmgr_ip6_best_length=1
	_cfmgr_ip6_best_start=-1
	for _cfmgr_ip6_group in "$@"; do
		if [ "$_cfmgr_ip6_group" = 0 ]; then
			if [ "$_cfmgr_ip6_run_length" -eq 0 ]; then
				_cfmgr_ip6_run_start=$_cfmgr_ip6_index
			fi
			_cfmgr_ip6_run_length=$((_cfmgr_ip6_run_length + 1))
			# Strict greater-than retains the leftmost run on a tie.
			if [ "$_cfmgr_ip6_run_length" -gt "$_cfmgr_ip6_best_length" ]; then
				_cfmgr_ip6_best_length=$_cfmgr_ip6_run_length
				_cfmgr_ip6_best_start=$_cfmgr_ip6_run_start
			fi
		else
			_cfmgr_ip6_run_length=0
		fi
		_cfmgr_ip6_index=$((_cfmgr_ip6_index + 1))
	done

	_cfmgr_ip6_output=
	_cfmgr_ip6_skip=0
	_cfmgr_ip6_index=0
	for _cfmgr_ip6_group in "$@"; do
		if [ "$_cfmgr_ip6_index" -eq "$_cfmgr_ip6_best_start" ]; then
			_cfmgr_ip6_output=$_cfmgr_ip6_output::
			_cfmgr_ip6_skip=$_cfmgr_ip6_best_length
		fi
		if [ "$_cfmgr_ip6_skip" -gt 0 ]; then
			_cfmgr_ip6_skip=$((_cfmgr_ip6_skip - 1))
		else
			case $_cfmgr_ip6_output in
			'' | *:) _cfmgr_ip6_output=$_cfmgr_ip6_output$_cfmgr_ip6_group ;;
			*) _cfmgr_ip6_output=$_cfmgr_ip6_output:$_cfmgr_ip6_group ;;
			esac
		fi
		_cfmgr_ip6_index=$((_cfmgr_ip6_index + 1))
	done
	printf '%s\n' "$_cfmgr_ip6_output"
)

# Address-scope classification only; `global` does not imply reachability or ownership.
cfmgr_ipv4_classify() (
	[ "$#" -eq 1 ] || return 1
	_cfmgr_ip4_classified=$(cfmgr_ipv4_normalize "$1") || return 1
	[ "$_cfmgr_ip4_classified" = "$1" ] || return 1
	IFS=.
	set -f
	# The existing normalizer guarantees four canonical decimal octets.
	# shellcheck disable=SC2086
	set -- $_cfmgr_ip4_classified
	_cfmgr_ip4_a=$1
	_cfmgr_ip4_b=$2
	_cfmgr_ip4_c=$3
	_cfmgr_ip4_d=$4
	_cfmgr_ip4_scope=global
	case $_cfmgr_ip4_a in
	0 | 127) _cfmgr_ip4_scope=nonpublic ;;
	10) _cfmgr_ip4_scope=private ;;
	100)
		if [ "$_cfmgr_ip4_b" -ge 64 ] && [ "$_cfmgr_ip4_b" -le 127 ]; then
			_cfmgr_ip4_scope=shared
		fi
		;;
	169)
		if [ "$_cfmgr_ip4_b" -eq 254 ]; then _cfmgr_ip4_scope=nonpublic; fi
		;;
	172)
		if [ "$_cfmgr_ip4_b" -ge 16 ] && [ "$_cfmgr_ip4_b" -le 31 ]; then
			_cfmgr_ip4_scope=private
		fi
		;;
	192)
		if [ "$_cfmgr_ip4_b" -eq 168 ]; then
			_cfmgr_ip4_scope=private
		elif [ "$_cfmgr_ip4_b" -eq 0 ] && [ "$_cfmgr_ip4_c" -eq 0 ] &&
			[ "$_cfmgr_ip4_d" -ne 9 ] && [ "$_cfmgr_ip4_d" -ne 10 ]; then
			_cfmgr_ip4_scope=nonpublic
		elif [ "$_cfmgr_ip4_b" -eq 0 ] && [ "$_cfmgr_ip4_c" -eq 2 ]; then
			_cfmgr_ip4_scope=nonpublic
		elif [ "$_cfmgr_ip4_b" -eq 88 ] && [ "$_cfmgr_ip4_c" -eq 99 ]; then
			_cfmgr_ip4_scope=nonpublic
		fi
		;;
	198)
		if { [ "$_cfmgr_ip4_b" -ge 18 ] && [ "$_cfmgr_ip4_b" -le 19 ]; } ||
			{ [ "$_cfmgr_ip4_b" -eq 51 ] && [ "$_cfmgr_ip4_c" -eq 100 ]; }; then
			_cfmgr_ip4_scope=nonpublic
		fi
		;;
	203)
		if [ "$_cfmgr_ip4_b" -eq 0 ] && [ "$_cfmgr_ip4_c" -eq 113 ]; then
			_cfmgr_ip4_scope=nonpublic
		fi
		;;
	*)
		if [ "$_cfmgr_ip4_a" -ge 224 ]; then _cfmgr_ip4_scope=nonpublic; fi
		;;
	esac
	printf '%s\n' "$_cfmgr_ip4_scope"
)

# Address-scope classification only; categories do not authorize publication.
cfmgr_ipv6_classify() (
	[ "$#" -eq 1 ] || return 1
	_cfmgr_ip6_classified=$(cfmgr_ipv6_normalize "$1") || return 1
	_cfmgr_ip6_scope_left=$_cfmgr_ip6_classified
	_cfmgr_ip6_scope_right=
	case $_cfmgr_ip6_classified in
	*::*)
		_cfmgr_ip6_scope_left=${_cfmgr_ip6_classified%%::*}
		_cfmgr_ip6_scope_right=${_cfmgr_ip6_classified#*::}
		;;
	esac
	IFS=:
	set -f
	_cfmgr_ip6_scope_count=0
	for _cfmgr_ip6_scope_side in "$_cfmgr_ip6_scope_left" "$_cfmgr_ip6_scope_right"; do
		# Both sides contain only canonical hextets from the existing normalizer.
		# shellcheck disable=SC2086
		set -- $_cfmgr_ip6_scope_side
		_cfmgr_ip6_scope_count=$((_cfmgr_ip6_scope_count + $#))
	done
	_cfmgr_ip6_scope_missing=$((8 - _cfmgr_ip6_scope_count))
	_cfmgr_ip6_scope_full=$_cfmgr_ip6_scope_left
	while [ "$_cfmgr_ip6_scope_missing" -gt 0 ]; do
		_cfmgr_ip6_scope_full=$_cfmgr_ip6_scope_full:0
		_cfmgr_ip6_scope_missing=$((_cfmgr_ip6_scope_missing - 1))
	done
	if [ -n "$_cfmgr_ip6_scope_right" ]; then
		_cfmgr_ip6_scope_full=$_cfmgr_ip6_scope_full:$_cfmgr_ip6_scope_right
	fi
	_cfmgr_ip6_scope_full=${_cfmgr_ip6_scope_full#:}
	# Exactly eight canonical hexadecimal words; no octal or wide arithmetic.
	# shellcheck disable=SC2086
	set -- $_cfmgr_ip6_scope_full
	_cfmgr_ip6_scope_first=$((0x$1))
	_cfmgr_ip6_scope_second=$((0x$2))
	_cfmgr_ip6_scope=nonpublic
	if [ "$_cfmgr_ip6_scope_first" -ge 8192 ] && [ "$_cfmgr_ip6_scope_first" -le 16383 ]; then
		_cfmgr_ip6_scope=global
	fi

	if [ "$((_cfmgr_ip6_scope_first & 65024))" -eq 64512 ]; then
		# fc00::/7, including both ULA halves.
		_cfmgr_ip6_scope=private
	elif [ "$1:$2:$3:$4:$5:$6" = 0:0:0:0:0:ffff ] ||
		{ [ "$1:$2:$3:$4:$5:$6" = 0:0:0:0:0:0 ] &&
			[ "$7:$8" != 0:0 ] && [ "$7:$8" != 0:1 ]; } ||
		[ "$1:$2:$3:$4:$5:$6" = 64:ff9b:0:0:0:0 ] ||
		[ "$1:$2:$3" = 64:ff9b:1 ] ||
		[ "$1:$2" = 2001:0 ] || [ "$1" = 2002 ]; then
		# Mapped, compatible, well-known/local translation, Teredo and 6to4.
		_cfmgr_ip6_scope=transition
	elif { [ "$1:$2:$3:$4:$5:$6:$7" = 2001:1:0:0:0:0:0 ] &&
		{ [ "$8" = 1 ] || [ "$8" = 2 ] || [ "$8" = 3 ]; }; } ||
		[ "$1:$2" = 2001:3 ] || [ "$1:$2:$3" = 2001:4:112 ] ||
		{ [ "$1" = 2001 ] && [ "$_cfmgr_ip6_scope_second" -ge 32 ] &&
			[ "$_cfmgr_ip6_scope_second" -le 63 ]; } ||
		[ "$1:$2:$3" = 2620:4f:8000 ]; then
		# Point exceptions, AMT, AS112, ORCHIDv2 /28, DET /28 and direct AS112.
		_cfmgr_ip6_scope=special
	elif { [ "$1" = 2001 ] && [ "$_cfmgr_ip6_scope_second" -le 511 ]; } ||
		[ "$1:$2" = 2001:db8 ] || [ "$1" = 3ffe ] ||
		{ [ "$1" = 3fff ] && [ "$_cfmgr_ip6_scope_second" -le 4095 ]; }; then
		# Remaining 2001::/23, documentation and retired 6bone space.
		_cfmgr_ip6_scope=nonpublic
	fi
	printf '%s\n' "$_cfmgr_ip6_scope"
)

# Compare caller-supplied IPv4 observations; this does not establish freshness or reachability.
cfmgr_ipv4_observation_report() (
	[ "$#" -eq 2 ] || return 1

	_cfmgr_ip4_obs_wan=$1
	_cfmgr_ip4_obs_external=$2
	_cfmgr_ip4_obs_wan_scope=
	_cfmgr_ip4_obs_external_scope=
	_cfmgr_ip4_obs_wan_valid=1
	_cfmgr_ip4_obs_external_valid=1
	if [ "$_cfmgr_ip4_obs_wan" != - ]; then
		if _cfmgr_ip4_obs_wan_scope=$(cfmgr_ipv4_classify "$_cfmgr_ip4_obs_wan"); then
			:
		else
			_cfmgr_ip4_obs_wan_valid=0
		fi
	fi
	if [ "$_cfmgr_ip4_obs_external" != - ]; then
		if _cfmgr_ip4_obs_external_scope=$(cfmgr_ipv4_classify "$_cfmgr_ip4_obs_external"); then
			:
		else
			_cfmgr_ip4_obs_external_valid=0
		fi
	fi
	[ "$_cfmgr_ip4_obs_wan_valid" -eq 1 ] &&
		[ "$_cfmgr_ip4_obs_external_valid" -eq 1 ] || return 1

	_cfmgr_ip4_obs_state=unknown
	_cfmgr_ip4_obs_address=-
	_cfmgr_ip4_obs_nat=unknown
	if [ "$_cfmgr_ip4_obs_wan" = - ]; then
		_cfmgr_ip4_obs_reason=wan-unavailable
	elif [ "$_cfmgr_ip4_obs_wan_scope" = nonpublic ]; then
		_cfmgr_ip4_obs_reason=wan-nonpublic
	elif [ "$_cfmgr_ip4_obs_external" = - ]; then
		_cfmgr_ip4_obs_reason=external-unavailable
	elif [ "$_cfmgr_ip4_obs_external_scope" != global ]; then
		_cfmgr_ip4_obs_reason=external-nonpublic
	elif [ "$_cfmgr_ip4_obs_wan_scope" = global ]; then
		_cfmgr_ip4_obs_state=active
		if [ "$_cfmgr_ip4_obs_wan" = "$_cfmgr_ip4_obs_external" ]; then
			_cfmgr_ip4_obs_address=$_cfmgr_ip4_obs_wan
			_cfmgr_ip4_obs_nat=false
			_cfmgr_ip4_obs_reason=address-match
		else
			_cfmgr_ip4_obs_address=$_cfmgr_ip4_obs_external
			_cfmgr_ip4_obs_nat=true
			_cfmgr_ip4_obs_reason=address-mismatch
		fi
	else
		_cfmgr_ip4_obs_state=active
		_cfmgr_ip4_obs_address=$_cfmgr_ip4_obs_external
		_cfmgr_ip4_obs_nat=true
		if [ "$_cfmgr_ip4_obs_wan_scope" = private ]; then
			_cfmgr_ip4_obs_reason=private-wan
		else
			_cfmgr_ip4_obs_reason=shared-wan
		fi
	fi

	_cfmgr_ip4_obs_row=$(printf 'ipv4-observation\t1\t%s\t%s\t%s\t%s' \
		"$_cfmgr_ip4_obs_state" "$_cfmgr_ip4_obs_address" \
		"$_cfmgr_ip4_obs_nat" "$_cfmgr_ip4_obs_reason") || return 1
	_cfmgr_ip4_obs_body_bytes=$((${#_cfmgr_ip4_obs_row} + 1))
	printf '%s\nend\t%s\n' "$_cfmgr_ip4_obs_row" "$_cfmgr_ip4_obs_body_bytes"
)
