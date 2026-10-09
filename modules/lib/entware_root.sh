#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only; trusted io/storage/entware/native_config/isolation are loaded.
# Entry is confined to an independently admitted Entware callback holding the
# original FD8/FD9. Framing checks do not approve a new UUID or storage identity.
# The synchronous native observer may retain no descriptors or asynchronous users.
# Helpers consume state established inside the isolated wrapper/root/IO owners.
# shellcheck disable=SC2030,SC2031,SC2154

cfmgr_isolation_entware_root_with() {
	_cfmgr_entware_root_owner production "$@" >/dev/null 2>&1
}

cfmgr_isolation_entware_root_test() {
	_cfmgr_entware_root_owner fixture "$@" >/dev/null 2>&1
}

_cfmgr_entware_root_owner() (
	set +x
	set +e
	set +u
	set -f
	trap - 0 HUP INT QUIT TERM
	trap 'exit 129' HUP INT QUIT TERM
	umask 077
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	export PATH LC_ALL
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	IFS=' 	'
	IFS="${IFS}
"
	_entware_root_kind=$1
	shift
	_entware_root_resolved='' _entware_root_volume='' _entware_root_fdinfo=''
	_entware_root_facts='' _entware_root_uuid='' _entware_root_source_ledger=''
	_entware_root_fallback_ledger='' _entware_root_mounted_ledger=''
	_entware_root_first_identity='' _entware_root_first_body='' _entware_root_ready=0
	case $_entware_root_kind in
	production) [ "$#" -ge 9 ] || return 2 ;;
	fixture) [ "$#" -ge 15 ] || return 2 ;;
	*) return 2 ;;
	esac
	_entware_root_resolved=$1 _entware_root_volume=$2
	_cfmgr_isolation_path "$_entware_root_resolved" || return 2
	_io_tab='	'
	_io_lf='
'
	_cfmgr_entware_root_volume "$_entware_root_volume" || return 2
	shift 2
	case $_entware_root_kind in
	production)
		_entware_root_fdinfo=/proc/self/fdinfo/9
		_cfmgr_isolation_root_owner native-opt production "$@"
		;;
	fixture)
		_entware_root_ram=$1 _entware_root_guard=$2 _entware_root_tools=$3
		_entware_root_input=$4 _entware_root_root_fdinfo=$5 _entware_root_fdinfo=$6
		_cfmgr_isolation_path "$_entware_root_fdinfo" && [ "$_entware_root_fdinfo" != / ] || return 2
		shift 6
		_cfmgr_isolation_root_owner native-opt fixture "$_entware_root_ram" "$_entware_root_guard" \
			"$_entware_root_tools" "$_entware_root_input" "$_entware_root_root_fdinfo" "$@"
		;;
	esac
)

# Rebuild every field and the footer, rejecting empty/extra fields or records.
_cfmgr_entware_root_volume() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 65536 ] || return 1
	_entware_root_body=${1%%"$_io_lf"*}
	[ "$1" = "$_entware_root_body${_io_lf}end$_io_tab$((${#_entware_root_body} + 1))$_io_lf" ] || return 1
	_entware_root_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_entware_root_body
	IFS=$_entware_root_saved_ifs
	[ "$#" -eq 10 ] && [ "$1" = volume ] || return 1
	[ "$_entware_root_body" = "$1$_io_tab$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab$9$_io_tab${10}" ] || return 1
	_cfmgr_io_decimal "$2" positive || return 1
	case $3 in *:*) ;; *) return 1 ;; esac
	_cfmgr_io_decimal "${3%%:*}" nonnegative && _cfmgr_io_decimal "${3#*:}" nonnegative || return 1
	case $_entware_root_kind:$4 in
	production:ext2 | production:ext3 | production:ext4 | fixture:ext2 | fixture:ext3 | fixture:ext4 | fixture:tmpfs) ;;
	*) return 1 ;;
	esac
	for _entware_root_hex in "$5" "$6" "$7"; do
		[ "${#_entware_root_hex}" -le 8192 ] && _cfmgr_io_hex_path "$_entware_root_hex" || return 1
	done
	_cfmgr_io_hex "$8" && _cfmgr_io_hex "$9" && _cfmgr_entware_uuid "${10}" || return 1
	_entware_root_facts="$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab$9"
	_entware_root_uuid=${10}
}

_cfmgr_entware_root_source_check() {
	_cfmgr_isolation_private || return 1
	[ "$_isolation_facts" = "$_entware_root_facts" ] || return 1
	_cfmgr_entware_options "$_isolation_options" "$_isolation_super" || return 1
	"$_isolation_test" -d "$_entware_root_resolved" &&
		"$_isolation_test" ! -L "$_entware_root_resolved"
}

# Separate bounded IO owners inspect the inherited descriptors without opening
# the source/block pathname or reading FD8's inherited file offset.
_cfmgr_entware_root_fd_action() {
	_storage_parser=$_isolation_storage_parser
	_storage_fdinfo=$_entware_root_fdinfo
	_storage_target=$_entware_root_resolved
	_storage_test_command=$_isolation_test
	_storage_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_entware_root_facts
	IFS=$_storage_saved_ifs
	_storage_mount_id=$1 _storage_device=$2
	"$_isolation_test" -d /proc/self/fd/9 || return 1
	_cfmgr_storage_fdinfo 0 1 && _cfmgr_storage_ls 2 3
}

_cfmgr_entware_root_fd_check() {
	if [ -n "$_isolation_tools" ]; then
		cfmgr_io_test "$_isolation_root" "$_isolation_tools" workspace _cfmgr_entware_root_fd_action
	else
		cfmgr_io_with_workspace "$_isolation_root" _cfmgr_entware_root_fd_action
	fi
}

_cfmgr_entware_root_source() {
	_cfmgr_isolation_query "$_entware_root_resolved" 2 && _cfmgr_entware_root_source_check || return 1
	if [ -n "$_entware_root_source_ledger" ]; then
		[ "$_isolation_ledger" = "$_entware_root_source_ledger" ] || return 1
	else
		_entware_root_source_ledger=$_isolation_ledger
		_cfmgr_isolation_write "$_isolation_guard/source-opt" "$_entware_root_source_ledger" || return 1
	fi
	_cfmgr_entware_root_fd_check
}

# Require effective RW/exec on both lists, and explicit safe per-mount flags.
_cfmgr_entware_root_options() (
	[ "$#" -eq 2 ] || return 1
	_cfmgr_io_hex "$1" && _cfmgr_io_hex "$2" && _cfmgr_entware_options "$1" "$2" || return 1
	_entware_root_nosuid=0 _entware_root_nodev=0 _entware_root_list=0
	for _entware_root_options in "$1" "$2"; do
		_entware_root_start=1
		while :; do
			case $_entware_root_options in '') break ;; esac
			case $_entware_root_start in 1)
				case $_entware_root_options in
				73756964 | 737569642c* | 646576 | 6465762c*) return 1 ;;
				6e6f73756964 | 6e6f737569642c*) [ "$_entware_root_list" -ne 0 ] || _entware_root_nosuid=1 ;;
				6e6f646576 | 6e6f6465762c*) [ "$_entware_root_list" -ne 0 ] || _entware_root_nodev=1 ;;
				esac
				;;
			esac
			case $_entware_root_options in 2c*) _entware_root_start=1 ;; *) _entware_root_start=0 ;; esac
			_entware_root_options=${_entware_root_options#??}
		done
		_entware_root_list=1
	done
	[ "$_entware_root_nosuid" -eq 1 ] && [ "$_entware_root_nodev" -eq 1 ]
)

_cfmgr_entware_root_name() {
	_execution_view=opt _execution_view_hex=6f7074 _execution_view_path=$_isolation_tree/opt
	_execution_view_source_ledger=$_entware_root_source_ledger
}

_cfmgr_entware_root_view_check() {
	_cfmgr_entware_root_name
	_cfmgr_isolation_native_view_check || return 1
	_entware_root_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_execution_base_body
	IFS=$_entware_root_saved_ifs
	[ "$_isolation_point" = "${6}2f6f7074" ] || return 1
	case " $_execution_native_ids " in *" $_isolation_id "*) return 1 ;; esac
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- ${_execution_tmp_mounted_ledger%%"$_io_lf"*}
	IFS=$_entware_root_saved_ifs
	[ "$_isolation_id" != "$2" ]
}

_cfmgr_entware_root_saved() {
	for _entware_root_piece in source fallback mounted; do
		_cfmgr_isolation_read "$_isolation_guard/$_entware_root_piece-opt" || return 1
		case $_entware_root_piece in
		source) [ "$_isolation_text" = "$_entware_root_source_ledger" ] || return 1 ;;
		fallback) [ "$_isolation_text" = "$_entware_root_fallback_ledger" ] || return 1 ;;
		mounted) [ "$_isolation_text" = "$_entware_root_mounted_ledger" ] || return 1 ;;
		esac
	done
	_cfmgr_isolation_read "$_isolation_guard/intent-opt" || return 1
	[ "$_isolation_text" = "opt$_io_lf" ]
}

_cfmgr_entware_root_build() {
	_cfmgr_entware_root_name
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_fallback_check || return 129
	_entware_root_fallback_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/fallback-opt" "$_entware_root_fallback_ledger" || return 129
	_cfmgr_isolation_write "$_isolation_guard/intent-opt" "opt$_io_lf" || return 129
	_cfmgr_entware_root_source || return 129
	_cfmgr_isolation_native_call bind-opt "$_isolation_mount" -n -i -o bind /proc/self/fd/9 "$_isolation_tree/opt" || return 129
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_entware_root_view_check &&
		_cfmgr_entware_options "$_isolation_options" "$_isolation_super" || return 129
	_entware_root_first_identity=$_execution_view_identity _entware_root_first_body=$_isolation_body
	_cfmgr_isolation_native_call private-opt "$_isolation_mount" -n -i -o make-private "$_isolation_tree/opt" || return 129
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_entware_root_view_check || return 129
	[ "$_execution_view_identity" = "$_entware_root_first_identity" ] && [ "$_isolation_body" = "$_entware_root_first_body" ] || return 129
	_cfmgr_isolation_native_call remount-opt "$_isolation_mount" -n -i -o remount,bind,rw,nosuid,nodev,exec \
		/proc/self/fd/9 "$_isolation_tree/opt" || return 129
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_entware_root_view_check &&
		_cfmgr_entware_root_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_execution_view_identity" = "$_entware_root_first_identity" ] || return 129
	_entware_root_mounted_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/mounted-opt" "$_entware_root_mounted_ledger" || return 129
	_entware_root_ready=1
}

_cfmgr_entware_root_layout_check() {
	[ "$_entware_root_ready" -eq 1 ] && _cfmgr_entware_root_saved || return 1
	_cfmgr_entware_root_source || return 1
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_entware_root_view_check &&
		_cfmgr_entware_root_options "$_isolation_options" "$_isolation_super" || return 1
	[ "$_isolation_ledger" = "$_entware_root_mounted_ledger" ]
}

_cfmgr_entware_root_remove() {
	_cfmgr_entware_root_saved || return 129
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_entware_root_view_check &&
		_cfmgr_entware_root_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_isolation_ledger" = "$_entware_root_mounted_ledger" ] || return 129
	_cfmgr_isolation_unmount umount-opt "$_isolation_tree/opt" || return 129
	_cfmgr_entware_root_name
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_isolation_native_fallback_check || return 129
	[ "$_isolation_ledger" = "$_entware_root_fallback_ledger" ] || return 129
	_entware_root_ready=0
}
