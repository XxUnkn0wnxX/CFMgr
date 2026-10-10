#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Fixed owned JSON-token capture; explicitly source trusted io.sh first.
# Caller supplies private immutable regular input and trusted parser/ancestors.
# Contents remain files. Producer success is required before downstream framing
# validation; this adds no acquisition, source trust or hard deadline.
# shellcheck disable=SC2154

# INPUT JSON_PARSER RAW_SLOT TOKEN_SLOT; output is a file/count pair, not tokens
# in argv or shell variables. A downstream consumer must validate token framing.
_cfmgr_json_tokens_capture() {
	[ "$#" -eq 4 ] && [ "${_io_active-}" = 1 ] || return 2
	_json_tokens_file=
	_json_tokens_bytes=
	_json_input=$1
	_json_parser=$2
	_json_raw_slot=$3
	_json_token_slot=$4
	for _json_slot in "$3" "$4"; do
		case $_json_slot in [0123456789] | 1[012345]) ;; *) return 2 ;; esac
	done
	[ "$3" != "$4" ] || return 2
	case $_json_parser in /*) ;; *) return 2 ;; esac
	[ -f "$_json_parser" ] && [ ! -L "$_json_parser" ] && [ -r "$_json_parser" ] || return 2
	[ -f "$_json_input" ] && [ ! -L "$_json_input" ] && [ -r "$_json_input" ] || return 1
	cfmgr_io_capture "$_json_raw_slot" 65536 4096 cat <"$_json_input" || return 1
	_cfmgr_io_capture_status "$_json_raw_slot" || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	_json_raw_bytes=$_io_out_bytes
	[ "$_json_raw_bytes" -gt 0 ] || return 1
	_cfmgr_io_json_tokens_capture "$_json_token_slot" "$_json_parser" "$_json_raw_bytes" \
		<"$_io_stage/$_json_raw_slot.out" || return 1
	_cfmgr_io_capture_status "$_json_token_slot" || return 1
	[ "$_io_err_bytes" -eq 0 ] || return 1
	case $_io_producer in 0) ;; 2) return 2 ;; *) return 1 ;; esac
	[ "$_io_out_bytes" -gt 0 ] || return 1
	_json_tokens_file=$_io_stage/$_json_token_slot.out
	_json_tokens_bytes=$_io_out_bytes
}
