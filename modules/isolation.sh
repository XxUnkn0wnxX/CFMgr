#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Internal owned-root lifecycle; requires trusted io.sh/storage.sh definitions.
# Sourcing defines functions only. No chroot, Opt execution, or write approval.
# ROOT/native firmware/parser code are trusted; callbacks are synchronous native
# work only: no mounts, asynchronous users, Entware, or owner-metadata/trap changes.
# Caller tracing must already be off. Route signals to the active IO owner.
# An active mutation/callback or unproved mount retains the guard for manual
# recovery. Path checks are observations, not atomic namespace/device leases.
# Per-entry subshell state is inherited by its nested trusted callbacks.
# shellcheck disable=SC2154,SC2030,SC2031

cfmgr_isolation_with() (
	[ "$#" -ge 4 ] || return 2
	_cfmgr_storage_callback_name "$4" || return 2
	_isolation_root=$1
	_isolation_parser=$2
	_isolation_storage_parser=$3
	_isolation_tools=
	_isolation_input=/proc/self/mountinfo
	_cfmgr_isolation_path "$_isolation_root" || return 2
	shift 3
	cfmgr_storage_with "$_isolation_root" "$_isolation_parser" "$_isolation_storage_parser" _cfmgr_isolation_begin "$@"
)

# Explicit fixture API: storage_with_test's first eight arguments, then callback.
cfmgr_isolation_test() (
	[ "$#" -ge 9 ] && [ -n "$2" ] && [ -n "$6" ] || return 2
	_cfmgr_storage_callback_name "$9" || return 2
	_isolation_root=$1
	_isolation_tools=$2
	_isolation_target=$3
	_isolation_input=$4
	_isolation_fdinfo=$5
	_isolation_block=$6
	_isolation_parser=$7
	_isolation_storage_parser=$8
	_cfmgr_isolation_path "$_isolation_root" || return 2
	shift 8
	cfmgr_storage_with_test "$_isolation_root" "$_isolation_tools" "$_isolation_target" "$_isolation_input" "$_isolation_fdinfo" "$_isolation_block" "$_isolation_parser" "$_isolation_storage_parser" _cfmgr_isolation_begin "$@"
)

_cfmgr_isolation_path() (
	case $1 in / | /*) ;; *) return 1 ;; esac
	[ "${#1}" -le 4096 ] || return 1
	case $1 in *[[:cntrl:]]* | *//* | */./* | */../* | */. | */.. | ?*/) return 1 ;; esac
)

_cfmgr_isolation_tool() (
	case $1 in mount | umount | mkdir | rm | printf | test) ;; *) return 2 ;; esac
	if [ -n "$_isolation_tools" ]; then
		[ -x "$_isolation_tools/$1" ] && [ ! -d "$_isolation_tools/$1" ] || return 1
		printf '%s\n' "$_isolation_tools/$1"
	elif [ "$1" = mount ] || [ "$1" = umount ]; then
		[ -x "/bin/$1" ] && [ ! -d "/bin/$1" ] || return 1
		printf '/bin/%s\n' "$1"
	else
		_cfmgr_io_find "$1"
	fi
)

# All owned metadata is <=64KiB and <=3 LF records. Reconstruct exact bytes:
# shell read can discard NUL, and native printf can report false write success.
_cfmgr_isolation_read() {
	_isolation_text=
	_isolation_line=
	_isolation_lines=0
	while IFS= read -r _isolation_line; do
		_isolation_lines=$((_isolation_lines + 1))
		[ "$_isolation_lines" -le 3 ] || return 1
		_isolation_text=$_isolation_text$_isolation_line$_io_lf
		[ "${#_isolation_text}" -le 65536 ] || return 1
	done <"$1"
	[ -z "$_isolation_line" ] || return 1
	_isolation_size=$(_cfmgr_io_size "$1") || return 1
	[ "$_isolation_size" -eq "${#_isolation_text}" ]
}

_cfmgr_isolation_write() {
	[ -n "$2" ] && [ "${#2}" -le 65536 ] || return 1
	[ ! -e "$1" ] && [ ! -L "$1" ] || return 1
	(
		set -C
		"$_isolation_printf" '%s' "$2" >"$1"
	) || return 1
	_cfmgr_isolation_read "$1" || return 1
	[ "$_isolation_text" = "$2" ]
}

# Each query uses a fresh two-capture IO owner, outside the mounted tree. Its
# checked ledger is written exclusively, then checked again after IO cleanup.
# At most16 queries /16 metadata files; no slot reuse or unbounded retries.
_cfmgr_isolation_query_action() {
	_cfmgr_io_mount_capture "$2" "$_isolation_parser" "$_isolation_input" 0 1 topology || return 1
	if [ "$4" = 1 ]; then
		cfmgr_io_capture 2 4097 4096 readlink -f "$_isolation_root" || return 1
		_cfmgr_storage_ok 2 && _cfmgr_storage_line 2 || return 1
		[ "$_storage_line" = "$_isolation_root" ] || return 1
	fi
	_cfmgr_isolation_write "$3" "$_mount_ledger"
}

_cfmgr_isolation_query() {
	[ "$_isolation_queries" -lt 16 ] || return 1
	_isolation_query_file=$_isolation_guard/query-$_isolation_queries
	_isolation_queries=$((_isolation_queries + 1))
	if [ -n "$_isolation_tools" ]; then
		cfmgr_io_test "$_isolation_root" "$_isolation_tools" workspace _cfmgr_isolation_query_action "$1" "$_isolation_query_file" "$2"
	else
		cfmgr_io_with_workspace "$_isolation_root" _cfmgr_isolation_query_action "$1" "$_isolation_query_file" "$2"
	fi
	_isolation_query_status=$?
	case $_isolation_query_status in
	0) ;;
	129 | 130 | 143)
		_isolation_interrupted=$_isolation_query_status
		return "$_isolation_query_status"
		;;
	*) return 1 ;;
	esac
	_cfmgr_isolation_read "$_isolation_query_file" || return 1
	[ "$_isolation_lines" -eq 3 ] || return 1
	{ IFS= read -r _isolation_body && IFS= read -r _mount_topology && IFS= read -r _isolation_footer; } <"$_isolation_query_file" || return 1
	[ "$_isolation_footer" = "end$_io_tab$((${#_isolation_body} + ${#_mount_topology} + 2))" ] || return 1
	_cfmgr_io_topology_fields || return 1
	_isolation_topology=$_mount_topology
	_isolation_ledger=$_isolation_text
	_isolation_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_isolation_body
	IFS=$_isolation_saved_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] || return 1
	_isolation_id=$2
	_isolation_device=$4
	_isolation_fs=$7
	_isolation_mount_root=$5
	_isolation_point=$6
	_isolation_fs_target=${11}
	_isolation_options=$9
	_isolation_super=${10}
	_isolation_facts="$2$_io_tab$4$_io_tab$7$_io_tab$5$_io_tab$6$_io_tab${11}$_io_tab$9$_io_tab${10}"
}

_cfmgr_isolation_private() {
	[ "$_isolation_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ]
}

# Options are byte-hex. Walk token starts without per-byte external test calls.
_cfmgr_isolation_options() (
	for _options in "$1" "$2"; do
		_rw=0
		_start=1
		while :; do
			case $_options in '') break ;; esac
			case $_start in 1)
				case $_options in
				7277 | 72772c*) _rw=1 ;;
				726f | 726f2c*) return 1 ;;
				6e6f65786563 | 6e6f657865632c*) [ "$3" = null ] || return 1 ;;
				6e6f646576 | 6e6f6465762c*) [ "$3" != null ] || return 1 ;;
				esac
				;;
			esac
			case $_options in 2c*) _start=1 ;; *) _start=0 ;; esac
			_options=${_options#??}
		done
		[ "$_rw" -eq 1 ] || return 1
	done
)

_cfmgr_isolation_active() {
	_cfmgr_isolation_write "$_isolation_guard/active" "$1$_io_lf"
}

_cfmgr_isolation_clear() {
	"$_isolation_rm" -f "$_isolation_guard/active" || return 1
	[ ! -e "$_isolation_guard/active" ] && [ ! -L "$_isolation_guard/active" ]
}

_cfmgr_isolation_native_call() {
	_cfmgr_isolation_active "$1" || return 1
	shift
	"$@"
	_isolation_call_status=$?
	case $_isolation_call_status in 129 | 130 | 143) return "$_isolation_call_status" ;; esac
	_cfmgr_isolation_clear || return 1
	[ "$_isolation_call_status" -eq 0 ]
}

_cfmgr_isolation_bind() {
	# Monotonic evidence: missing intent metadata can never mean no syscall.
	_isolation_attempted=1
	_cfmgr_isolation_write "$_isolation_guard/intent-$1" "$1$_io_lf" || return 1
	_cfmgr_isolation_native_call "bind-$1" "$_isolation_mount" -n -i -o bind "$2" "$3" || return "$?"
	_cfmgr_isolation_native_call "private-$1" "$_isolation_mount" -n -i -o make-private "$3" || return "$?"
	_cfmgr_isolation_query "$3" 0 || return 1
	_cfmgr_isolation_private || return 1
	[ "$_isolation_mount_root" = "$_isolation_fs_target" ] && [ "$_isolation_mount_root" = "$5" ] && [ "$_isolation_id" != "$_isolation_ram_id" ] || return 1
	[ "$_isolation_device" = "$4" ] && [ "$_isolation_fs" = "$6" ] || return 1
	_cfmgr_isolation_options "$_isolation_options" "$_isolation_super" "$1" || return 1
	if [ "$1" = null ]; then
		[ "$_isolation_id" != "$_isolation_null_id" ] || return 1
		"$_isolation_test" -c "$3" && "$_isolation_test" /dev/null -ef "$3" || return 1
	else
		[ "$_isolation_id" != "$_isolation_source_id" ] || return 1
	fi
	_cfmgr_isolation_write "$_isolation_guard/mounted-$1" "$_isolation_ledger" || return 1
	case $1 in null)
		_isolation_null_body=$_isolation_body
		_isolation_null_ledger=$_isolation_ledger
		_isolation_null_recorded=1
		;;
	opt)
		_isolation_opt_body=$_isolation_body
		_isolation_opt_ledger=$_isolation_ledger
		_isolation_opt_recorded=1
		;;
	esac
}

_cfmgr_isolation_absent() {
	_cfmgr_isolation_query "$1" 0 || return 1
	_cfmgr_isolation_private || return 1
	_isolation_ram_fs=${_isolation_ram_body##*"$_io_tab"}
	case $_isolation_ram_fs in 2f) ;; *) _isolation_ram_fs=${_isolation_ram_fs}2f ;; esac
	[ "$_isolation_body" = "${_isolation_ram_body%"$_io_tab"*}$_io_tab$_isolation_ram_fs$2" ]
}

_cfmgr_isolation_remove() {
	_cfmgr_isolation_query "$2" 0 || return 1
	_cfmgr_isolation_private || return 1
	[ "$_isolation_body" = "$3" ] || return 1
	_cfmgr_isolation_read "$_isolation_guard/intent-$1" || return 1
	[ "$_isolation_text" = "$1$_io_lf" ] || return 1
	_cfmgr_isolation_read "$_isolation_guard/mounted-$1" || return 1
	case $1 in
	opt) [ "$_isolation_text" = "$_isolation_opt_ledger" ] || return 1 ;;
	null) [ "$_isolation_text" = "$_isolation_null_ledger" ] || return 1 ;;
	esac
	_cfmgr_isolation_native_call "umount-$1" "$_isolation_umount" -D -n "$2" || return "$?"
	_cfmgr_isolation_absent "$2" "$4"
}

_cfmgr_isolation_cleanup() {
	[ ! -e "$_isolation_guard/active" ] && [ ! -L "$_isolation_guard/active" ] || return 1
	# No syscall intent yet: only the freshly owned ordinary RAM directory exists.
	if [ "$_isolation_attempted" -eq 0 ] && [ "$_isolation_null_recorded" -eq 0 ] && [ "$_isolation_opt_recorded" -eq 0 ] && [ ! -e "$_isolation_guard/intent-null" ] && [ ! -e "$_isolation_guard/intent-opt" ]; then
		"$_isolation_rm" -rf "$_isolation_guard" || return 1
		[ ! -e "$_isolation_guard" ] && [ ! -L "$_isolation_guard" ]
		return
	fi
	if [ "$_isolation_opt_recorded" -eq 1 ]; then
		_cfmgr_isolation_remove opt "$_isolation_tree/opt" "$_isolation_opt_body" 63666d67722d69736f6c6174696f6e2f726f6f742f6f7074 || return 1
	elif [ "$_isolation_attempted" -eq 1 ]; then
		_cfmgr_isolation_absent "$_isolation_tree/opt" 63666d67722d69736f6c6174696f6e2f726f6f742f6f7074 || return 1
	fi
	if [ "$_isolation_null_recorded" -eq 1 ]; then
		_cfmgr_isolation_remove null "$_isolation_tree/dev/null" "$_isolation_null_body" 63666d67722d69736f6c6174696f6e2f726f6f742f6465762f6e756c6c || return 1
	elif [ "$_isolation_attempted" -eq 1 ]; then
		_cfmgr_isolation_absent "$_isolation_tree/dev/null" 63666d67722d69736f6c6174696f6e2f726f6f742f6465762f6e756c6c || return 1
	fi
	_cfmgr_isolation_query "$_isolation_root" 0 && _cfmgr_isolation_private || return 1
	[ "$_isolation_body" = "$_isolation_ram_body" ] || return 1
	"$_isolation_rm" -rf "$_isolation_guard" || return 1
	[ ! -e "$_isolation_guard" ] && [ ! -L "$_isolation_guard" ]
}

_cfmgr_isolation_run() {
	_cfmgr_isolation_query "$_isolation_root" 1 && _cfmgr_isolation_private || return 1
	case $_isolation_fs in tmpfs | ramfs) ;; *) return 1 ;; esac
	_cfmgr_isolation_options "$_isolation_options" "$_isolation_super" ram || return 1
	_isolation_ram_body=$_isolation_body
	_isolation_ram_id=$_isolation_id
	_cfmgr_isolation_query "$_isolation_resolved" 0 && _cfmgr_isolation_private || return 1
	[ "$_isolation_facts" = "$_isolation_volume_facts" ] || return 1
	case $_isolation_fs in ext2 | ext3 | ext4) ;; *) return 1 ;; esac
	_cfmgr_isolation_options "$_isolation_options" "$_isolation_super" opt || return 1
	_isolation_source_id=$_isolation_id
	_isolation_source_device=$_isolation_device
	_isolation_source_root=$_isolation_fs_target
	_isolation_source_fs=$_isolation_fs
	_cfmgr_isolation_query /dev/null 0 || return 1
	_cfmgr_isolation_options "$_isolation_options" "$_isolation_super" null || return 1
	_isolation_null_id=$_isolation_id
	_isolation_null_device=$_isolation_device
	_isolation_null_root=$_isolation_fs_target
	_isolation_null_fs=$_isolation_fs
	"$_isolation_test" -c /dev/null && "$_isolation_test" -d /proc/self/fd/9 && "$_isolation_test" "$_isolation_resolved" -ef /proc/self/fd/9 || return 1
	"$_isolation_mkdir" -m 700 "$_isolation_tree" "$_isolation_tree/opt" "$_isolation_tree/dev" "$_isolation_tree/bootstrap" "$_isolation_tree/tmp" "$_isolation_tree/offline" || return 1
	_cfmgr_isolation_write "$_isolation_tree/dev/null" "$_io_lf" || return 1
	_cfmgr_isolation_bind null /dev/null "$_isolation_tree/dev/null" "$_isolation_null_device" "$_isolation_null_root" "$_isolation_null_fs" || return "$?"
	_cfmgr_isolation_bind opt /proc/self/fd/9 "$_isolation_tree/opt" "$_isolation_source_device" "$_isolation_source_root" "$_isolation_source_fs" || return "$?"
	_cfmgr_isolation_active callback || return 1
	"$_isolation_callback" "$_isolation_tree" "$_isolation_volume" "$@"
	_isolation_callback_status=$?
	case $_isolation_callback_status in 129 | 130 | 143) return "$_isolation_callback_status" ;; esac
	_cfmgr_isolation_clear || return 1
	return "$_isolation_callback_status"
}

_cfmgr_isolation_begin() {
	_isolation_resolved=$1
	_isolation_volume=$2
	_isolation_callback=$3
	shift 3
	_isolation_guard=${_isolation_root%/}/cfmgr-isolation
	_isolation_tree=$_isolation_guard/root
	_isolation_queries=0
	_isolation_attempted=0
	_isolation_interrupted=0
	_isolation_null_recorded=0
	_isolation_opt_recorded=0
	_isolation_ram_body=
	_isolation_null_body=
	_isolation_opt_body=
	_isolation_null_ledger=
	_isolation_opt_ledger=
	_cfmgr_isolation_volume_fields || return 1
	_cfmgr_isolation_begin_args "$@"
}

_cfmgr_isolation_volume_fields() {
	_isolation_saved_ifs=$IFS
	IFS=$_io_tab
	_isolation_volume_body=${_isolation_volume%%"$_io_lf"*}
	# shellcheck disable=SC2086
	set -- $_isolation_volume_body
	IFS=$_isolation_saved_ifs
	# The volume ledger was fully verified by storage; use its first eight facts.
	[ "$#" -eq 10 ] && [ "$1" = volume ] || return 1
	_isolation_volume_facts="$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab$9"
}

# Installed only in the dedicated storage IO owner. EXIT never guesses mount
# cleanup: premature success becomes failure, signals/nonzero remain unchanged,
# and only the ordinary private IO scratch cleanup is delegated to io.sh.
_cfmgr_isolation_exit() {
	_isolation_exit_status=$1
	if [ "$_isolation_exit_status" -eq 0 ] && [ "$_isolation_complete" -ne 1 ]; then
		_isolation_exit_status=1
	fi
	_cfmgr_io_finish "$_isolation_exit_status"
}

_cfmgr_isolation_begin_args() {
	_isolation_complete=0
	trap '_cfmgr_isolation_exit "$?"' 0
	_isolation_mount=$(_cfmgr_isolation_tool mount) || return 1
	_isolation_umount=$(_cfmgr_isolation_tool umount) || return 1
	_isolation_mkdir=$(_cfmgr_isolation_tool mkdir) || return 1
	_isolation_rm=$(_cfmgr_isolation_tool rm) || return 1
	_isolation_printf=$(_cfmgr_isolation_tool printf) || return 1
	_isolation_test=$(_cfmgr_isolation_tool test) || return 1
	[ ! -e "$_isolation_guard" ] && [ ! -L "$_isolation_guard" ] || return 1
	"$_isolation_mkdir" -m 700 "$_isolation_guard" || return 1
	_cfmgr_isolation_run "$@"
	_isolation_result=$?
	[ "$_isolation_interrupted" -eq 0 ] || return "$_isolation_interrupted"
	case $_isolation_result in 129 | 130 | 143) return "$_isolation_result" ;; esac
	_cfmgr_isolation_cleanup
	_isolation_cleanup_status=$?
	[ "$_isolation_interrupted" -eq 0 ] || return "$_isolation_interrupted"
	[ "$_isolation_cleanup_status" -eq 0 ] || return 1
	_isolation_complete=1
	return "$_isolation_result"
}
