#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Pure address normalization and coarse IPv4 scope classification; no route,
# ownership or publish authority.
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
