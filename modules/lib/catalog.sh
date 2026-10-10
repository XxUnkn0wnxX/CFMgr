#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only catalog request plans; explicitly source trusted io.sh/package.sh.
# Inputs/code and ancestors are trusted, private, immutable and unaliased.
# Local manifest provenance and branch-to-commit correspondence are unproved.
# No source acquisition, hashing, execution or installation is performed here.
# IO-owned variables are initialized by the explicitly sourced owner.
# shellcheck disable=SC2154

cfmgr_catalog_plan_report() {
	[ "$#" -eq 7 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_catalog_plan_action "$2" "$3" "$4" "$5" "$6" "$7"
}

# Explicit trusted fixture tools, never selected by production environment.
cfmgr_catalog_plan_test() {
	[ "$#" -eq 8 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_catalog_plan_action "$3" "$4" "$5" "$6" "$7" "$8"
}

_cfmgr_catalog_plan_action() {
	[ "$#" -eq 7 ] && [ "${_io_active-}" = 1 ] || return 2
	_cfmgr_catalog_commit_valid "$7" || return 2
	_cfmgr_catalog_capture "$2" "$4" "$5" 0 1 || return "$?"
	_cfmgr_catalog_select "$7" || return "$?"
	_cfmgr_package_manifest_capture "$3" "$4" "$6" 2 3 || return "$?"
	_cfmgr_catalog_join || return "$?"
	cfmgr_io_stage_report "$_catalog_plan_ledger"
}

# INPUT PATH_HELPER PARSER RAW_SLOT RESULT_SLOT. Keep this and selection usable
# before a manifest exists; slots share the one IO owner's checked budget.
_cfmgr_catalog_capture() {
	[ "$#" -eq 5 ] && [ "${_io_active-}" = 1 ] || return 2
	_catalog_body=
	_catalog_ledger=
	_catalog_files=
	_catalog_count=0
	_catalog_input=$1
	_catalog_helper=$2
	_catalog_parser=$3
	_catalog_raw_slot=$4
	_catalog_result_slot=$5
	for _catalog_slot in "$4" "$5"; do
		case $_catalog_slot in [0123456789] | 1[012345]) ;; *) return 2 ;; esac
	done
	[ "$4" != "$5" ] || return 2
	for _catalog_code in "$2" "$3"; do
		case $_catalog_code in /*) ;; *) return 2 ;; esac
		[ -f "$_catalog_code" ] && [ ! -L "$_catalog_code" ] && [ -r "$_catalog_code" ] || return 2
	done
	[ -f "$_catalog_input" ] && [ ! -L "$_catalog_input" ] && [ -r "$_catalog_input" ] || return 1
	cfmgr_io_capture "$_catalog_raw_slot" 32768 4096 cat <"$_catalog_input" || return 1
	_cfmgr_io_capture_status "$_catalog_raw_slot" || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	_catalog_raw_bytes=$_io_out_bytes
	[ "$_catalog_raw_bytes" -gt 0 ] || return 1
	cfmgr_io_capture "$_catalog_result_slot" 65536 4096 awk \
		-v "cfmgr_catalog_size=$_catalog_raw_bytes" -f "$_catalog_helper" -f "$_catalog_parser" \
		<"$_io_stage/$_catalog_raw_slot.out" || return 1
	_cfmgr_io_capture_status "$_catalog_result_slot" || return 1
	[ "$_io_err_bytes" -eq 0 ] || return 1
	case $_io_producer in 0) ;; 2) return 2 ;; *) return 1 ;; esac
	_cfmgr_catalog_decode "$_io_stage/$_catalog_result_slot.out" "$_io_out_bytes"
}

# Check the parser's transport, not its source-path/repository/URL grammar.
# Reconstructing all original bytes rejects shell NUL stripping and truncation.
_cfmgr_catalog_decode() {
	[ "$#" -eq 2 ] && [ "${_io_active-}" = 1 ] || return 2
	_catalog_body=
	_catalog_ledger=
	_catalog_count=0
	_catalog_owner=
	_catalog_repository=
	_catalog_selector=
	_catalog_manifest_url=
	_catalog_files=
	_catalog_line=
	_catalog_extra=
	_catalog_footer=
	_catalog_file=$1
	_catalog_expected=$2
	_cfmgr_io_limit "$_catalog_expected" && [ "$_catalog_expected" -gt 0 ] || return 1
	[ -f "$_catalog_file" ] && [ ! -L "$_catalog_file" ] && [ -r "$_catalog_file" ] || return 1
	_cfmgr_catalog_records <"$_catalog_file"
}

_cfmgr_catalog_field() {
	[ "$#" -eq 1 ] && [ -n "$1" ] || return 1
	case $1 in *[!\ -~]*) return 1 ;; esac
}

_cfmgr_catalog_records() {
	IFS= read -r _catalog_line || return 1
	[ "$_catalog_line" = "catalog$_io_tab"'1' ] || return 1
	IFS= read -r _catalog_line || return 1
	case $_catalog_line in "repository$_io_tab"*) ;; *) return 1 ;; esac
	_catalog_rest=${_catalog_line#*"$_io_tab"}
	_catalog_owner=${_catalog_rest%%"$_io_tab"*}
	_catalog_repository=${_catalog_rest#*"$_io_tab"}
	[ "$_catalog_rest" != "$_catalog_repository" ] || return 1
	_cfmgr_catalog_field "$_catalog_owner" && _cfmgr_catalog_field "$_catalog_repository" || return 1
	IFS= read -r _catalog_line || return 1
	case $_catalog_line in "branch$_io_tab"*) ;; *) return 1 ;; esac
	_catalog_selector=${_catalog_line#*"$_io_tab"}
	_cfmgr_catalog_field "$_catalog_selector" || return 1
	IFS= read -r _catalog_line || return 1
	case $_catalog_line in "manifest$_io_tab"*) ;; *) return 1 ;; esac
	_catalog_manifest_url=${_catalog_line#*"$_io_tab"}
	_cfmgr_catalog_field "$_catalog_manifest_url" || return 1
	_catalog_body="catalog${_io_tab}1${_io_lf}repository$_io_tab$_catalog_owner$_io_tab$_catalog_repository$_io_lf"
	_catalog_body="${_catalog_body}branch$_io_tab$_catalog_selector${_io_lf}manifest$_io_tab$_catalog_manifest_url$_io_lf"
	while IFS= read -r _catalog_line; do
		case $_catalog_line in
		"end$_io_tab"*)
			[ "$_catalog_count" -gt 0 ] || return 1
			_catalog_footer="end$_io_tab$_catalog_count$_io_tab${#_catalog_body}"
			[ "$_catalog_line" = "$_catalog_footer" ] || return 1
			_catalog_extra=
			if IFS= read -r _catalog_extra || [ -n "$_catalog_extra" ]; then return 1; fi
			[ "$((${#_catalog_body} + ${#_catalog_footer} + 1))" -eq "$_catalog_expected" ] || return 1
			_catalog_ledger=$_catalog_body$_catalog_footer$_io_lf
			return 0
			;;
		esac
		case $_catalog_line in *[!\ -~"$_io_tab"]*) return 1 ;; esac
		_catalog_saved_ifs=$IFS
		IFS=$_io_tab
		# The owner has noglob set. Rebuild fields to reject tab/empty collapse.
		# shellcheck disable=SC2086
		set -- $_catalog_line
		IFS=$_catalog_saved_ifs
		[ "$#" -eq 3 ] && [ "$1" = file ] || return 1
		_cfmgr_catalog_field "$2" && _cfmgr_catalog_field "$3" || return 1
		_catalog_rebuilt="$1$_io_tab$2$_io_tab$3"
		[ "$_catalog_rebuilt" = "$_catalog_line" ] || return 1
		_catalog_count=$((_catalog_count + 1))
		[ "$_catalog_count" -le 128 ] || return 1
		_catalog_files=$_catalog_files$_catalog_rebuilt$_io_lf
		_catalog_body=$_catalog_body$_catalog_rebuilt$_io_lf
	done
	return 1
}

_cfmgr_catalog_commit_valid() {
	[ "$#" -eq 1 ] && [ "${#1}" -eq 40 ] || return 1
	case $1 in *[!0123456789abcdef]*) return 1 ;; esac
}

# Selection does not require a manifest; branch correspondence is caller-owned.
_cfmgr_catalog_select() {
	[ "$#" -eq 1 ] && [ "${_io_active-}" = 1 ] || return 2
	_catalog_pinned_manifest=
	_catalog_selected_files=
	_cfmgr_catalog_commit_valid "$1" || return 2
	_catalog_commit=$1
	case $_catalog_selector in main | develop) ;; *) [ "$_catalog_selector" = "$1" ] || return 1 ;; esac
	_cfmgr_catalog_pin_url "$_catalog_manifest_url" || return 1
	_catalog_pinned_manifest=$_catalog_pinned_url
	_catalog_inventory=$_catalog_files
	while [ -n "$_catalog_inventory" ]; do
		_catalog_row=${_catalog_inventory%%"$_io_lf"*}
		_catalog_inventory=${_catalog_inventory#*"$_io_lf"}
		_catalog_rest=${_catalog_row#*"$_io_tab"}
		_catalog_destination=${_catalog_rest%%"$_io_tab"*}
		_catalog_url=${_catalog_rest#*"$_io_tab"}
		_cfmgr_catalog_pin_url "$_catalog_url" || return 1
		_catalog_selected_files="${_catalog_selected_files}file$_io_tab$_catalog_destination$_io_tab$_catalog_pinned_url$_io_lf"
	done
}

# Replace exactly one literal placeholder; no evaluation or source-path mapping.
_cfmgr_catalog_pin_url() {
	case $1 in *'{commit}'*) ;; *) return 1 ;; esac
	_catalog_url_before=${1%%'{commit}'*}
	_catalog_url_after=${1#*'{commit}'}
	case $_catalog_url_after in *'{commit}'*) return 1 ;; esac
	_catalog_pinned_url=$_catalog_url_before$_catalog_commit$_catalog_url_after
}

# Accepted catalog/manifest projections only; exact key removal detects missing,
# substituted and extra destinations without making URL paths equal to keys.
_cfmgr_catalog_join() {
	[ "$#" -eq 0 ] && [ "${_io_active-}" = 1 ] || return 2
	_catalog_plan_body=
	_catalog_plan_ledger=
	[ "$_catalog_count" -eq "$_package_manifest_count" ] || return 1
	_catalog_plan_body="source-plan${_io_tab}1${_io_lf}repository$_io_tab$_catalog_owner$_io_tab$_catalog_repository$_io_lf"
	_catalog_plan_body="${_catalog_plan_body}selector$_io_tab$_catalog_selector${_io_lf}commit$_io_tab$_catalog_commit$_io_lf"
	_catalog_plan_body="${_catalog_plan_body}manifest$_io_tab$_catalog_pinned_manifest${_io_lf}version$_io_tab$_package_manifest_version$_io_lf"
	_catalog_plan_body="${_catalog_plan_body}config-schema${_io_tab}1${_io_lf}package-api${_io_tab}1$_io_lf"
	_catalog_remaining=$_io_lf$_catalog_selected_files
	_catalog_inventory=$_package_manifest_body
	_catalog_join_count=0
	while [ -n "$_catalog_inventory" ]; do
		_catalog_row=${_catalog_inventory%%"$_io_lf"*}
		_catalog_inventory=${_catalog_inventory#*"$_io_lf"}
		case $_catalog_row in "file$_io_tab"*) ;; *) continue ;; esac
		_catalog_saved_ifs=$IFS
		IFS=$_io_tab
		# Accepted manifest cardinality and noglob were established by its owner.
		# shellcheck disable=SC2086
		set -- $_catalog_row
		IFS=$_catalog_saved_ifs
		_catalog_key="file$_io_tab$2$_io_tab"
		case $_catalog_remaining in *"$_io_lf$_catalog_key"*) ;; *) return 1 ;; esac
		_catalog_match=${_catalog_remaining#*"$_io_lf$_catalog_key"}
		_catalog_url=${_catalog_match%%"$_io_lf"*}
		_catalog_match=$_catalog_key$_catalog_url
		_catalog_before=${_catalog_remaining%%"$_io_lf$_catalog_match$_io_lf"*}
		_catalog_after=${_catalog_remaining#*"$_io_lf$_catalog_match$_io_lf"}
		_catalog_remaining=$_catalog_before$_io_lf$_catalog_after
		_catalog_plan_body="$_catalog_plan_body$_catalog_row$_io_tab$_catalog_url$_io_lf"
		_catalog_join_count=$((_catalog_join_count + 1))
	done
	[ "$_catalog_join_count" -eq "$_package_manifest_count" ] && [ "$_catalog_remaining" = "$_io_lf" ] || return 1
	_catalog_plan_ledger="${_catalog_plan_body}end$_io_tab$_package_manifest_count$_io_tab$_package_manifest_total$_io_tab${#_catalog_plan_body}$_io_lf"
	[ "${#_catalog_plan_ledger}" -le 65536 ]
}
