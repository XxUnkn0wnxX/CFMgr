#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Owned native manifest reports; explicitly source trusted io.sh first.
# Byte verification additionally requires explicitly sourced native_digest.sh.
# Input/code and their ancestors must be trusted, immutable and unaliased.
# These path checks are not atomic hostile-filesystem admission or provenance.
# Source loading only defines functions; public entries use the IO owner to
# isolate state, bound captures and clean up before publishing one report.
# IO-owned variables are initialized by the explicitly sourced owner.
# shellcheck disable=SC2154

cfmgr_package_manifest_report() {
	[ "$#" -eq 4 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_package_manifest_action "$2" "$3" "$4"
}

# Explicit fixture-only tool selection, never a production environment input.
cfmgr_package_manifest_test() {
	[ "$#" -eq 5 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_package_manifest_action "$3" "$4" "$5"
}

# SOURCE_ROOT is already private/immutable, acquired within 1 MiB per input and
# 8 MiB aggregate. Native size/hash checks read to EOF, not bounded acquisition.
# This verifies only declared bytes; modes remain desired package attributes.
cfmgr_package_verify_report() {
	[ "$#" -eq 5 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_package_verify_action "$2" "$3" "$4" "$5"
}

cfmgr_package_verify_test() {
	[ "$#" -eq 6 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_package_verify_action "$3" "$4" "$5" "$6"
}

# Check declared files/parents against a bounded native namespace observation.
# This relies on native traversal accuracy, not provenance or hostile traversal.
cfmgr_package_tree_report() {
	[ "$#" -eq 5 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_package_tree_action "$2" "$3" "$4" "$5"
}

cfmgr_package_tree_test() {
	[ "$#" -eq 6 ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_package_tree_action "$3" "$4" "$5" "$6"
}

_cfmgr_package_verify_action() {
	[ "$#" -eq 5 ] && [ "${_io_active-}" = 1 ] || return 2
	_cfmgr_package_verify_prepare "$2" "$3" "$4" "$5" || return "$?"
	_cfmgr_package_verify_bytes || return 1
	_cfmgr_package_verify_report package-bytes
}

_cfmgr_package_tree_action() {
	[ "$#" -eq 5 ] && [ "${_io_active-}" = 1 ] || return 2
	_cfmgr_package_verify_prepare "$2" "$3" "$4" "$5" || return "$?"
	_cfmgr_package_tree_inventory || return 1
	_cfmgr_package_verify_bytes || return 1
	_cfmgr_package_verify_report package-tree
}

# One owner and one accepted manifest feed either report; no nested public IO.
_cfmgr_package_verify_prepare() {
	_package_verify_root=$1
	_package_verify_index=0
	_package_verify_body=
	_package_verify_ledger=
	[ "${#_package_verify_root}" -le 4096 ] || return 2
	case $_package_verify_root in /*) ;; *) return 2 ;; esac
	case $_package_verify_root in / | */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 2 ;; esac
	[ -d "$_package_verify_root" ] && [ ! -L "$_package_verify_root" ] &&
		[ -r "$_package_verify_root" ] && [ -x "$_package_verify_root" ] || return 2
	_cfmgr_package_manifest_capture "$2" "$3" "$4" 0 1
}

_cfmgr_package_verify_bytes() {
	_package_verify_env=$(_cfmgr_package_verify_find env) || return 1
	_package_verify_openssl=$(_cfmgr_package_verify_find openssl) || return 1
	_package_verify_hexdump=$(_cfmgr_package_verify_find hexdump) || return 1
	# Decode already checked every field. Read that accepted body directly,
	# retaining its order and attributes as the sole inventory source.
	_package_verify_inventory=$_package_manifest_body
	while [ -n "$_package_verify_inventory" ]; do
		_package_verify_row=${_package_verify_inventory%%"$_io_lf"*}
		_package_verify_inventory=${_package_verify_inventory#*"$_io_lf"}
		case $_package_verify_row in "file$_io_tab"*) ;; *) continue ;; esac
		_package_verify_saved_ifs=$IFS
		IFS=$_io_tab
		# Trusted owner has noglob set; cardinality was established by D4.
		# shellcheck disable=SC2086
		set -- $_package_verify_row
		IFS=$_package_verify_saved_ifs
		_cfmgr_package_verify_member "$2" || return 1
		_package_verify_size=$(_cfmgr_native_size_owned "$_io_wc" "$_package_verify_file") || return 1
		[ "$_package_verify_size" = "$3" ] || return 1
		_package_verify_index=$((_package_verify_index + 1))
		_cfmgr_native_digest_match "$_package_verify_file" "$4" \
			"$_io_stage/package-$_package_verify_index.digest" \
			"$_io_stage/package-$_package_verify_index.hex" "$_io_wc" \
			"$_package_verify_env" "$_package_verify_openssl" "$_package_verify_hexdump" || return 1
	done
	[ "$_package_verify_index" -eq "$_package_manifest_count" ] || return 1
}

_cfmgr_package_verify_report() {
	_package_verify_header="manifest${_io_tab}1$_io_lf"
	_package_verify_body="$1${_io_tab}1$_io_lf${_package_manifest_body#"$_package_verify_header"}"
	_package_verify_ledger="${_package_verify_body}end$_io_tab$_package_manifest_count$_io_tab$_package_manifest_total$_io_tab${#_package_verify_body}$_io_lf"
	cfmgr_io_stage_report "$_package_verify_ledger"
}

# Build the namespace solely from the accepted manifest, then consume one
# fixed native listing. LF delimiters are safe because accepted paths are ASCII
# without controls. Its finite 64 KiB cap also bounds the expected set.
_cfmgr_package_tree_inventory() {
	_package_tree_expected="$_io_lf.$_io_lf"
	_package_tree_inventory=$_package_manifest_body
	while [ -n "$_package_tree_inventory" ]; do
		_package_tree_record=${_package_tree_inventory%%"$_io_lf"*}
		_package_tree_inventory=${_package_tree_inventory#*"$_io_lf"}
		case $_package_tree_record in "file$_io_tab"*) ;; *) continue ;; esac
		_package_tree_relative=${_package_tree_record#*"$_io_tab"}
		_package_tree_relative=${_package_tree_relative%%"$_io_tab"*}
		_cfmgr_package_tree_expect "./$_package_tree_relative" || return 1
		while :; do
			case $_package_tree_relative in */*) ;; *) break ;; esac
			_package_tree_relative=${_package_tree_relative%/*}
			_package_tree_directory=$_package_verify_root/$_package_tree_relative
			[ -d "$_package_tree_directory" ] && [ ! -L "$_package_tree_directory" ] &&
				[ -r "$_package_tree_directory" ] && [ -x "$_package_tree_directory" ] || return 1
			_cfmgr_package_tree_expect "./$_package_tree_relative" || return 1
		done
	done
	# Keep the owner/caller cwd unchanged; find never follows links or executes
	# prepared source. Capture owns all three slot2 files in the same IO stage.
	(cd "$_package_verify_root" && cfmgr_io_capture 2 65536 4096 find . -print) || return 1
	_cfmgr_io_capture_status 2 || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	_package_tree_capture_bytes=$_io_out_bytes
	[ "$_package_tree_capture_bytes" -gt 0 ] && [ "$_package_tree_capture_bytes" -le 65536 ] || return 1
	_package_tree_remaining=$_package_tree_expected
	_package_tree_read_bytes=0
	_package_tree_line=
	_cfmgr_package_tree_records <"$_io_stage/2.out"
}

_cfmgr_package_tree_expect() {
	case $_package_tree_expected in *"$_io_lf$1$_io_lf"*) return 0 ;; esac
	_package_tree_expected=$_package_tree_expected$1$_io_lf
	[ "$((${#_package_tree_expected} - 1))" -le 65536 ]
}

# Never trust shell read normalization: reconstruct every LF and compare with
# capture's original byte measurement, catching NUL stripping and partial rows.
_cfmgr_package_tree_records() {
	while IFS= read -r _package_tree_line; do
		case $_package_tree_remaining in *"$_io_lf$_package_tree_line$_io_lf"*) ;; *) return 1 ;; esac
		_package_tree_before=${_package_tree_remaining%%"$_io_lf$_package_tree_line$_io_lf"*}
		_package_tree_after=${_package_tree_remaining#*"$_io_lf$_package_tree_line$_io_lf"}
		_package_tree_remaining=$_package_tree_before$_io_lf$_package_tree_after
		_package_tree_read_bytes=$((_package_tree_read_bytes + ${#_package_tree_line} + 1))
		_package_tree_line=
	done
	[ -z "$_package_tree_line" ] && [ "$_package_tree_remaining" = "$_io_lf" ] &&
		[ "$_package_tree_read_bytes" -eq "$_package_tree_capture_bytes" ]
}

# Native digest tools only. The IO owner fixes fixture selection/production PATH.
_cfmgr_package_verify_find() (
	[ "$#" -eq 1 ] || return 1
	case $1 in env | openssl | hexdump) ;; *) return 1 ;; esac
	if [ -n "$_io_tools" ]; then
		[ -x "$_io_tools/$1" ] && [ ! -d "$_io_tools/$1" ] || return 1
		printf '%s\n' "$_io_tools/$1"
		return
	fi
	for _package_verify_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_package_verify_dir/$1" ] && [ ! -d "$_package_verify_dir/$1" ]; then
			printf '%s\n' "$_package_verify_dir/$1"
			return
		fi
	done
	return 1
)

# Destination grammar belongs to the trusted parser; check physical components
# below the caller's prepared root without following intermediate/terminal links.
_cfmgr_package_verify_member() {
	_package_verify_relative=$1
	_package_verify_file=$_package_verify_root
	while :; do
		case $_package_verify_relative in
		*/*)
			_package_verify_file=$_package_verify_file/${_package_verify_relative%%/*}
			_package_verify_relative=${_package_verify_relative#*/}
			[ -d "$_package_verify_file" ] && [ ! -L "$_package_verify_file" ] &&
				[ -x "$_package_verify_file" ] || return 1
			;;
		*) break ;;
		esac
	done
	_package_verify_file=$_package_verify_file/$_package_verify_relative
	[ -f "$_package_verify_file" ] && [ ! -L "$_package_verify_file" ] && [ -r "$_package_verify_file" ]
}

_cfmgr_package_manifest_action() {
	[ "$#" -eq 4 ] || return 2
	_cfmgr_package_manifest_capture "$2" "$3" "$4" 0 1 || return "$?"
	cfmgr_io_stage_report "$_package_manifest_ledger"
}

# Controlled owner callback only. Slots are distinct, consumed even on failure,
# and share the existing IO owner's budget; no competing traps or cleanup.
_cfmgr_package_manifest_capture() {
	[ "${_io_active-}" = 1 ] || return 2
	_package_manifest_body=
	_package_manifest_ledger=
	_package_manifest_count=0
	_package_manifest_total=0
	_package_manifest_version=
	_package_manifest_raw_bytes=
	[ "$#" -eq 5 ] || return 2
	_package_manifest_input=$1
	_package_manifest_helper=$2
	_package_manifest_parser=$3
	_package_manifest_raw_slot=$4
	_package_manifest_result_slot=$5
	for _package_manifest_slot in "$4" "$5"; do
		case $_package_manifest_slot in [0123456789] | 1[012345]) ;; *) return 2 ;; esac
	done
	[ "$4" != "$5" ] || return 2
	for _package_manifest_code in "$2" "$3"; do
		case $_package_manifest_code in /*) ;; *) return 2 ;; esac
		[ -f "$_package_manifest_code" ] && [ ! -L "$_package_manifest_code" ] &&
			[ -r "$_package_manifest_code" ] || return 2
	done
	[ -f "$_package_manifest_input" ] && [ ! -L "$_package_manifest_input" ] &&
		[ -r "$_package_manifest_input" ] || return 1
	# No filename operand: even an input name beginning '-' stays regular stdin.
	cfmgr_io_capture "$_package_manifest_raw_slot" 65536 4096 cat <"$_package_manifest_input" || return 1
	_cfmgr_io_capture_status "$_package_manifest_raw_slot" || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	_package_manifest_raw_bytes=$_io_out_bytes
	[ "$_package_manifest_raw_bytes" -gt 0 ] || return 1
	cfmgr_io_capture "$_package_manifest_result_slot" 65536 4096 awk \
		-v "cfmgr_manifest_size=$_package_manifest_raw_bytes" \
		-f "$_package_manifest_helper" -f "$_package_manifest_parser" \
		<"$_io_stage/$_package_manifest_raw_slot.out" || return 1
	_cfmgr_io_capture_status "$_package_manifest_result_slot" || return 1
	[ "$_io_err_bytes" -eq 0 ] || return 1
	case $_io_producer in 0) ;; 2) return 2 ;; *) return 1 ;; esac
	_cfmgr_package_manifest_decode "$_io_stage/$_package_manifest_result_slot.out" "$_io_out_bytes"
}

# Check the trusted parser's transport ledger, not its path/version semantics.
# EXPECTED_BYTES comes from capture's independently measured original bytes:
# reconstructing all tabs/LFs and comparing it detects shell NUL stripping,
# collapsed empty fields, truncation and short successful parser writes.
_cfmgr_package_manifest_decode() {
	[ "${_io_active-}" = 1 ] || return 2
	_package_manifest_body=
	_package_manifest_ledger=
	_package_manifest_count=0
	_package_manifest_total=0
	_package_manifest_version=
	_package_manifest_line=
	_package_manifest_extra=
	_package_manifest_footer=
	_package_manifest_rebuilt=
	[ "$#" -eq 2 ] || return 2
	_package_manifest_file=$1
	_package_manifest_expected=$2
	_cfmgr_io_limit "$_package_manifest_expected" || return 1
	[ "$_package_manifest_expected" -gt 0 ] || return 1
	[ -f "$_package_manifest_file" ] && [ ! -L "$_package_manifest_file" ] &&
		[ -r "$_package_manifest_file" ] || return 1
	_cfmgr_package_manifest_records <"$_package_manifest_file"
}

_cfmgr_package_manifest_records() {
	IFS= read -r _package_manifest_line || return 1
	[ "$_package_manifest_line" = "manifest$_io_tab"'1' ] || return 1
	IFS= read -r _package_manifest_line || return 1
	case $_package_manifest_line in "version$_io_tab"*) ;; *) return 1 ;; esac
	_package_manifest_version=${_package_manifest_line#"version$_io_tab"}
	[ -n "$_package_manifest_version" ] && [ "${#_package_manifest_version}" -le 128 ] || return 1
	case $_package_manifest_version in *[!\ -~]*) return 1 ;; esac
	IFS= read -r _package_manifest_line || return 1
	[ "$_package_manifest_line" = "config-schema$_io_tab"'1' ] || return 1
	IFS= read -r _package_manifest_line || return 1
	[ "$_package_manifest_line" = "package-api$_io_tab"'1' ] || return 1
	_package_manifest_body="manifest${_io_tab}1${_io_lf}version$_io_tab$_package_manifest_version$_io_lf"
	_package_manifest_body="${_package_manifest_body}config-schema${_io_tab}1${_io_lf}package-api${_io_tab}1$_io_lf"
	while IFS= read -r _package_manifest_line; do
		case $_package_manifest_line in
		"end$_io_tab"*)
			[ "$_package_manifest_count" -gt 0 ] || return 1
			_package_manifest_footer="end$_io_tab$_package_manifest_count$_io_tab$_package_manifest_total$_io_tab${#_package_manifest_body}"
			[ "$_package_manifest_line" = "$_package_manifest_footer" ] || return 1
			if IFS= read -r _package_manifest_extra || [ -n "$_package_manifest_extra" ]; then
				return 1
			fi
			[ "$((${#_package_manifest_body} + ${#_package_manifest_footer} + 1))" -eq "$_package_manifest_expected" ] || return 1
			_package_manifest_ledger=$_package_manifest_body$_package_manifest_footer$_io_lf
			return 0
			;;
		esac
		case $_package_manifest_line in *[!\ -~"$_io_tab"]*) return 1 ;; esac
		_package_manifest_saved_ifs=$IFS
		IFS=$_io_tab
		# Owner has noglob set. Reconstruction rejects IFS tab/empty collapse.
		# shellcheck disable=SC2086
		set -- $_package_manifest_line
		IFS=$_package_manifest_saved_ifs
		[ "$#" -eq 5 ] && [ "$1" = file ] || return 1
		_package_manifest_rebuilt="$1$_io_tab$2$_io_tab$3$_io_tab$4$_io_tab$5"
		[ "$_package_manifest_rebuilt" = "$_package_manifest_line" ] || return 1
		[ -n "$2" ] && [ "${#2}" -le 240 ] || return 1
		# Only these bounded sizes enter shell arithmetic. Version components
		# above remain lexical, including arbitrarily large supported components.
		case $3 in '' | 0* | *[!0123456789]*) return 1 ;; esac
		[ "${#3}" -le 7 ] && [ "$3" -le 1048576 ] || return 1
		[ "${#4}" -eq 64 ] || return 1
		case $4 in *[!0123456789abcdef]*) return 1 ;; esac
		case $5 in 0644 | 0755) ;; *) return 1 ;; esac
		_package_manifest_count=$((_package_manifest_count + 1))
		_package_manifest_total=$((_package_manifest_total + $3))
		[ "$_package_manifest_count" -le 128 ] && [ "$_package_manifest_total" -le 8388608 ] || return 1
		_package_manifest_body=$_package_manifest_body$_package_manifest_rebuilt$_io_lf
	done
	# Failed read means missing LF/footer, even if a final partial line was read.
	return 1
}
