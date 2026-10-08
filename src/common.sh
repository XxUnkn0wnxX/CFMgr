#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Pure parsing helpers only. Sourcing defines functions without running commands.
# Subshell function bodies keep scratch state out of their caller's shell.

cfmgr_decimal_normalize() (
	[ "$#" -eq 1 ] || return 1
	case $1 in
	'' | *[!0123456789]*) return 1 ;;
	esac
	[ "${#1}" -le 128 ] || return 1
	_cfmgr_decimal=$1
	while :; do
		case $_cfmgr_decimal in
		0*) _cfmgr_decimal=${_cfmgr_decimal#0} ;;
		*) break ;;
		esac
	done
	printf '%s\n' "${_cfmgr_decimal:-0}"
)

cfmgr_decimal_compare() (
	[ "$#" -eq 2 ] || return 1
	_cfmgr_left=$(cfmgr_decimal_normalize "$1") || return 1
	_cfmgr_right=$(cfmgr_decimal_normalize "$2") || return 1
	if [ "${#_cfmgr_left}" -lt "${#_cfmgr_right}" ]; then
		printf '%s\n' -1
		return 0
	fi
	if [ "${#_cfmgr_left}" -gt "${#_cfmgr_right}" ]; then
		printf '%s\n' 1
		return 0
	fi
	while [ -n "$_cfmgr_left" ]; do
		_cfmgr_left_tail=${_cfmgr_left#?}
		_cfmgr_right_tail=${_cfmgr_right#?}
		_cfmgr_left_digit=${_cfmgr_left%"$_cfmgr_left_tail"}
		_cfmgr_right_digit=${_cfmgr_right%"$_cfmgr_right_tail"}
		if [ "$_cfmgr_left_digit" -lt "$_cfmgr_right_digit" ]; then
			printf '%s\n' -1
			return 0
		fi
		if [ "$_cfmgr_left_digit" -gt "$_cfmgr_right_digit" ]; then
			printf '%s\n' 1
			return 0
		fi
		_cfmgr_left=$_cfmgr_left_tail
		_cfmgr_right=$_cfmgr_right_tail
	done
	printf '%s\n' 0
)

cfmgr_uint31() (
	[ "$#" -eq 1 ] || return 1
	_cfmgr_uint=$(cfmgr_decimal_normalize "$1") || return 1
	_cfmgr_uint_comparison=$(cfmgr_decimal_compare "$_cfmgr_uint" 2147483647) || return 1
	[ "$_cfmgr_uint_comparison" != 1 ] || return 1
	printf '%s\n' "$_cfmgr_uint"
)

# Exactly three canonical decimal components, not general SemVer.
cfmgr_version_compare() (
	[ "$#" -eq 2 ] || return 1
	for _cfmgr_version in "$1" "$2"; do
		[ "${#_cfmgr_version}" -le 128 ] || return 1
		case $_cfmgr_version in
		*[!0123456789.]* | '') return 1 ;;
		*.*.*) ;;
		*) return 1 ;;
		esac
		_cfmgr_major=${_cfmgr_version%%.*}
		_cfmgr_rest=${_cfmgr_version#*.}
		_cfmgr_minor=${_cfmgr_rest%%.*}
		_cfmgr_patch=${_cfmgr_rest#*.}
		case $_cfmgr_patch in
		*.*) return 1 ;;
		esac
		for _cfmgr_component in "$_cfmgr_major" "$_cfmgr_minor" "$_cfmgr_patch"; do
			case $_cfmgr_component in
			'' | 0[0123456789]*) return 1 ;;
			esac
		done
	done
	_cfmgr_left_version=$1
	_cfmgr_right_version=$2
	for _cfmgr_index in 1 2 3; do
		_cfmgr_left_component=${_cfmgr_left_version%%.*}
		_cfmgr_right_component=${_cfmgr_right_version%%.*}
		_cfmgr_comparison=$(cfmgr_decimal_compare \
			"$_cfmgr_left_component" "$_cfmgr_right_component") || return 1
		if [ "$_cfmgr_comparison" != 0 ]; then
			printf '%s\n' "$_cfmgr_comparison"
			return 0
		fi
		_cfmgr_left_version=${_cfmgr_left_version#*.}
		_cfmgr_right_version=${_cfmgr_right_version#*.}
	done
	printf '%s\n' 0
)

cfmgr_sha256_normalize() (
	[ "$#" -eq 1 ] || return 1
	[ "${#1}" -eq 64 ] || return 1
	case $1 in
	*[!0123456789abcdefABCDEF]*) return 1 ;;
	esac
	_cfmgr_digest=$1
	_cfmgr_lower_digest=
	while [ -n "$_cfmgr_digest" ]; do
		_cfmgr_digest_tail=${_cfmgr_digest#?}
		_cfmgr_hex=${_cfmgr_digest%"$_cfmgr_digest_tail"}
		case $_cfmgr_hex in
		A) _cfmgr_hex=a ;;
		B) _cfmgr_hex=b ;;
		C) _cfmgr_hex=c ;;
		D) _cfmgr_hex=d ;;
		E) _cfmgr_hex=e ;;
		F) _cfmgr_hex=f ;;
		esac
		_cfmgr_lower_digest=$_cfmgr_lower_digest$_cfmgr_hex
		_cfmgr_digest=$_cfmgr_digest_tail
	done
	printf '%s\n' "$_cfmgr_lower_digest"
)
