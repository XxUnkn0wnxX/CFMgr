#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Requires the trusted io.sh definitions already loaded by the internal caller.
# Sourcing defines functions only. Observation is read-only, not authorization
# to write or run Opt code, and not an atomic device-generation lease.
# FD9/FD8 remain held through all checks and staging inside the IO owner; guarded
# function-call redirections restore them before private cleanup/publication.
# Caller tracing must be off, and signals must be routed to the IO owner.
# Native blocked IO has no hard wall-clock deadline until supervision exists.
# Shared IO-owner state is assigned by io.sh, never by sourcing this library.
# shellcheck disable=SC2154

cfmgr_storage_observe() {
	[ "$#" -eq 3 ] || return 2
	cfmgr_io_with_report "$1" _cfmgr_storage_begin /opt /proc/self/mountinfo /proc/self/fdinfo/9 '' "$2" "$3"
}

# Explicit trusted fixture API only: ROOT TOOLS TARGET MOUNT_INPUT FDINFO_INPUT
# BLOCK_FILE MOUNT_PARSER STORAGE_PARSER. Regular block-file mapping is test-only.
cfmgr_storage_test() {
	[ "$#" -eq 8 ] && [ -n "$2" ] && [ -n "$6" ] || return 2
	cfmgr_io_test "$1" "$2" report _cfmgr_storage_begin "$3" "$4" "$5" "$6" "$7" "$8"
}

_cfmgr_storage_ok() {
	_cfmgr_io_capture_status "$1" || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ]
}

_cfmgr_storage_line() {
	_storage_line=
	_storage_extra=
	{ IFS= read -r _storage_line && ! IFS= read -r _storage_extra && [ -z "$_storage_extra" ]; } <"$_io_stage/$1.out" || return 1
	_storage_bytes=$(_cfmgr_io_size "$_io_stage/$1.out") || return 1
	[ "$_storage_bytes" -eq "$((${#_storage_line} + 1))" ]
}

_cfmgr_storage_resolve() {
	cfmgr_io_capture "$1" 4097 4096 readlink -f "$_storage_target" || return 1
	_cfmgr_storage_ok "$1" && _cfmgr_storage_line "$1" || return 1
	[ "${#_storage_line}" -le 4096 ] || return 1
	case $_storage_line in
	/ | /*)
		case $_storage_line in *[[:cntrl:]]* | *//* | */./* | */../* | */. | */..) return 1 ;; esac
		[ "$_storage_line" = / ] || [ "${_storage_line%/}" = "$_storage_line" ] || return 1
		;;
	*) return 1 ;;
	esac
}

# Parser observations have exactly two fields, followed by the standard footer.
# Original byte count catches read's NUL removal and missing/extra terminators.
_cfmgr_storage_ledger() {
	_storage_body=
	_storage_footer=
	_storage_extra=
	{ IFS= read -r _storage_body && IFS= read -r _storage_footer && ! IFS= read -r _storage_extra && [ -z "$_storage_extra" ]; } <"$_io_stage/$1.out" || return 1
	_storage_bytes=$(_cfmgr_io_size "$_io_stage/$1.out") || return 1
	_storage_value=${_storage_body#"$2$_io_tab"}
	[ "$_storage_body" = "$2$_io_tab$_storage_value" ] && [ -n "$_storage_value" ] || return 1
	case $_storage_value in *"$_io_tab"*) return 1 ;; esac
	_storage_body_bytes=$((${#_storage_body} + 1))
	[ "$_storage_footer" = "end$_io_tab$_storage_body_bytes" ] || return 1
	[ "$_storage_bytes" -eq "$((_storage_body_bytes + ${#_storage_footer} + 1))" ] || return 1
	case $2 in
	fdinfo) _cfmgr_io_decimal "$_storage_value" positive || return 1 ;;
	blockdev)
		case $_storage_value in *:*) ;; *) return 1 ;; esac
		_cfmgr_io_decimal "${_storage_value%%:*}" nonnegative && _cfmgr_io_decimal "${_storage_value#*:}" nonnegative || return 1
		;;
	exthex)
		_storage_uuid_hex=
		_storage_rest=$_storage_value
		for _storage_width in 8 4 4 4 12; do
			_storage_piece=${_storage_rest%%-*}
			[ "${#_storage_piece}" -eq "$_storage_width" ] || return 1
			case $_storage_piece in *[!0123456789abcdef]*) return 1 ;; esac
			_storage_uuid_hex=$_storage_uuid_hex$_storage_piece
			_storage_rest=${_storage_rest#"$_storage_piece"}
			if [ "$_storage_width" -ne 12 ]; then
				case $_storage_rest in -*) _storage_rest=${_storage_rest#-} ;; *) return 1 ;; esac
			fi
		done
		[ -z "$_storage_rest" ] && [ "$_storage_uuid_hex" != 00000000000000000000000000000000 ] || return 1
		;;
	*) return 2 ;;
	esac
}

_cfmgr_storage_parse() {
	_storage_parse_size=$(_cfmgr_io_size "$_io_stage/$1.out") || return 1
	[ "$_storage_parse_size" -le 4096 ] || return 1
	cfmgr_io_capture "$2" 4096 4096 awk -v "cfmgr_storageinfo_mode=$3" -v "cfmgr_storageinfo_size=$_storage_parse_size" -f "$_storage_parser" <"$_io_stage/$1.out" || return 1
	_cfmgr_io_capture_status "$2" || return 1
	[ "$_io_err_bytes" -eq 0 ] || return 1
	case $_io_producer in 0) ;; 3) return 3 ;; *) return 1 ;; esac
	_cfmgr_storage_ledger "$2" "$3"
}

# Decode only previously checked byte-hex, then enforce the selected printable
# canonical /dev profile. No input-derived printf format or shell evaluation.
_cfmgr_storage_source() {
	[ "${#1}" -le 512 ] || return 3
	_storage_hex=$1
	_storage_escaped=
	while :; do
		case $_storage_hex in '') break ;; esac
		_storage_pair_tail=${_storage_hex#??}
		_storage_pair=${_storage_hex%"$_storage_pair_tail"}
		case $_storage_pair in [23456][0123456789abcdef] | 7[0123456789abcde]) ;; *) return 3 ;; esac
		_storage_number=0
		for _storage_digit_index in 1 2; do
			_storage_tail=${_storage_hex#?}
			_storage_digit=${_storage_hex%"$_storage_tail"}
			case $_storage_digit in a) _storage_digit=10 ;; b) _storage_digit=11 ;; c) _storage_digit=12 ;; d) _storage_digit=13 ;; e) _storage_digit=14 ;; f) _storage_digit=15 ;; esac
			_storage_number=$((_storage_number * 16 + _storage_digit))
			_storage_hex=$_storage_tail
		done
		_storage_escaped="${_storage_escaped}\\0$((_storage_number / 64))$(((_storage_number / 8) % 8))$((_storage_number % 8))"
	done
	_storage_source=$("$_io_printf" '%b' "$_storage_escaped") || return 1
	[ "${#_storage_source}" -eq "$((${#1} / 2))" ] || return 1
	case $_storage_source in
	/dev/?*) ;; *) return 3 ;;
	esac
	case $_storage_source in *[!\ -~]* | *//* | */./* | */../* | */. | */.. | */) return 3 ;; esac
}

_cfmgr_storage_mount_fields() {
	_storage_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$_storage_saved_ifs
	_storage_mount_id=$2
	_storage_device=$4
	_storage_type=$7
	_storage_source_hex=$8
	_storage_report_fields="$2$_io_tab$4$_io_tab$7$_io_tab$5$_io_tab$6$_io_tab${11}$_io_tab$9$_io_tab${10}"
	case $_storage_type in ext2 | ext3 | ext4) ;; *) return 3 ;; esac
}

_cfmgr_storage_no_sb() (
	# Options are hex; comma delimiters are2c and sb= bytes are73623d. Match only
	# token starts so an unrelated value containing these bytes is not rejected.
	for _sb_list in "$1" "$2"; do
		_sb_start=1
		while :; do
			case $_sb_list in '') break ;; esac
			case $_sb_start in 1)
				case $_sb_list in 73623d*) return 3 ;; esac
				;;
			esac
			case $_sb_list in 2c*) _sb_start=1 ;; *) _sb_start=0 ;; esac
			_sb_list=${_sb_list#??}
		done
	done
)

_cfmgr_storage_fdinfo() {
	cfmgr_io_capture "$1" 4096 4096 cat "$_storage_fdinfo" || return 1
	_cfmgr_storage_ok "$1" || return 1
	_cfmgr_storage_parse "$1" "$2" fdinfo || return "$?"
	[ "$_storage_value" = "$_storage_mount_id" ] || return 1
	"$_storage_test_command" "$_storage_target" -ef /proc/self/fd/9 >/dev/null 2>&1 || return 1
}

_cfmgr_storage_ls() {
	cfmgr_io_capture "$1" 4096 4096 ls -dnL /proc/self/fd/8 || return 1
	_cfmgr_storage_ok "$1" && _cfmgr_storage_line "$1" || return 1
	case $_storage_line in b*) ;; *) return 1 ;; esac
	_storage_ls_line=$_storage_line
	_cfmgr_storage_parse "$1" "$2" blockdev || return "$?"
	[ "$_storage_value" = "$_storage_device" ] || return 1
}

_cfmgr_storage_begin() {
	[ "$#" -eq 7 ] || return 2
	_storage_target=$2
	_storage_mount_input=$3
	_storage_fdinfo=$4
	_storage_block_fixture=$5
	_storage_mount_parser=$6
	_storage_parser=$7
	for _storage_code in "$_storage_mount_parser" "$_storage_parser"; do
		case $_storage_code in /*) ;; *) return 2 ;; esac
		[ -f "$_storage_code" ] && [ ! -L "$_storage_code" ] && [ -r "$_storage_code" ] || return 2
	done
	_storage_test_command=$(_cfmgr_io_find test) || return 1
	_cfmgr_storage_resolve 0 || return 1
	_storage_resolved=$_storage_line
	"$_storage_test_command" -d "$_storage_resolved" >/dev/null 2>&1 || return 1
	# Function-call redirections remain guardable without unavailable command/exec
	# wrappers and retain descriptors in this owner through observation/staging.
	_storage_directory_entered=0
	_cfmgr_storage_directory 9<"$_storage_resolved"
	_storage_open_status=$?
	[ "$_storage_directory_entered" -eq 1 ] || return 1
	return "$_storage_open_status"
}

_cfmgr_storage_directory() {
	_storage_directory_entered=1
	"$_storage_test_command" -d /proc/self/fd/9 >/dev/null 2>&1 || return 1
	_cfmgr_io_mount_capture "$_storage_resolved" "$_storage_mount_parser" "$_storage_mount_input" 1 2 || return "$?"
	_storage_initial_mount=$_mount_body
	_cfmgr_storage_mount_fields || return "$?"
	_storage_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$_storage_saved_ifs
	_cfmgr_storage_no_sb "$9" "${10}" || return "$?"
	_cfmgr_storage_fdinfo 3 4 || return "$?"
	_cfmgr_storage_source "$_storage_source_hex" || return "$?"
	if [ -n "$_storage_block_fixture" ]; then
		[ -f "$_storage_block_fixture" ] && [ ! -L "$_storage_block_fixture" ] || return 1
		_storage_open_block=$_storage_block_fixture
	else
		[ -b "$_storage_source" ] || return 1
		_storage_open_block=$_storage_source
	fi
	_storage_block_entered=0
	_cfmgr_storage_block 8<"$_storage_open_block"
	_storage_open_status=$?
	[ "$_storage_block_entered" -eq 1 ] || return 1
	return "$_storage_open_status"
}

_cfmgr_storage_block() {
	_storage_block_entered=1
	_cfmgr_storage_ls 5 6 || return "$?"
	_storage_initial_ls=$_storage_ls_line
	cfmgr_io_capture 7 2304 4096 hexdump -v -n1152 -e '1/1 "%02x"' <&8 || return 1
	_cfmgr_storage_ok 7 || return 1
	_cfmgr_storage_parse 7 8 exthex || return "$?"
	_storage_uuid=$_storage_value
	_cfmgr_storage_resolve 9 || return 1
	[ "$_storage_line" = "$_storage_resolved" ] || return 1
	_cfmgr_io_mount_capture "$_storage_resolved" "$_storage_mount_parser" "$_storage_mount_input" 10 11 || return "$?"
	[ "$_mount_body" = "$_storage_initial_mount" ] || return 1
	_cfmgr_storage_fdinfo 12 13 || return "$?"
	_cfmgr_storage_ls 14 15 || return "$?"
	[ "$_storage_ls_line" = "$_storage_initial_ls" ] || return 1
	_storage_report="volume$_io_tab$_storage_report_fields$_io_tab$_storage_uuid$_io_lf"
	_storage_report="${_storage_report}end$_io_tab${#_storage_report}$_io_lf"
	cfmgr_io_stage_report "$_storage_report"
}
