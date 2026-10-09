#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only; trusted io/storage/entware/native_config/isolation/entware_root
# definitions are explicitly loaded. Fixed owned nodes only; no host /dev import.
# Readonly device mounts still permit character IO. Metadata never reads nodes.
# State belongs to the isolated root owner and its synchronous IO callbacks.
# shellcheck disable=SC2030,SC2031,SC2154

cfmgr_isolation_native_devices_root_with() {
	_cfmgr_entware_root_owner native-devices production "$@" >/dev/null 2>&1
}

cfmgr_isolation_native_devices_root_test() {
	_cfmgr_entware_root_owner native-devices fixture "$@" >/dev/null 2>&1
}

_cfmgr_native_devices_reset() {
	_native_devices_observations=0 _native_devices_count=0
	_native_devices_null_source='' _native_devices_null_fallback='' _native_devices_null_mounted='' _native_devices_null_metadata=''
	_native_devices_urandom_source='' _native_devices_urandom_fallback='' _native_devices_urandom_mounted='' _native_devices_urandom_metadata=''
	_native_devices_name='' _native_devices_name_hex='' _native_devices_minor=''
	_native_devices_path='' _native_devices_source_path='' _native_devices_metadata=''
	_native_devices_source_ledger='' _native_devices_fallback_ledger='' _native_devices_mounted_ledger=''
	_native_devices_first_identity='' _native_devices_first_body='' _native_devices_identity=''
	_native_devices_mknod=''
}

_cfmgr_native_devices_name() {
	_native_devices_name=$1
	case $_native_devices_name in
	null)
		_native_devices_name_hex=6e756c6c _native_devices_minor=3
		_native_devices_source_ledger=$_native_devices_null_source _native_devices_fallback_ledger=$_native_devices_null_fallback
		_native_devices_mounted_ledger=$_native_devices_null_mounted _native_devices_metadata=$_native_devices_null_metadata
		;;
	urandom)
		_native_devices_name_hex=7572616e646f6d _native_devices_minor=9
		_native_devices_source_ledger=$_native_devices_urandom_source _native_devices_fallback_ledger=$_native_devices_urandom_fallback
		_native_devices_mounted_ledger=$_native_devices_urandom_mounted _native_devices_metadata=$_native_devices_urandom_metadata
		;;
	*) return 1 ;;
	esac
	_native_devices_source_path=$_execution_image/dev/$_native_devices_name
	_native_devices_path=$_isolation_tree/dev/$_native_devices_name
}

_cfmgr_native_devices_save() {
	case $_native_devices_name in
	null)
		_native_devices_null_source=$_native_devices_source_ledger _native_devices_null_fallback=$_native_devices_fallback_ledger
		_native_devices_null_mounted=$_native_devices_mounted_ledger _native_devices_null_metadata=$_native_devices_metadata
		;;
	urandom)
		_native_devices_urandom_source=$_native_devices_source_ledger _native_devices_urandom_fallback=$_native_devices_fallback_ledger
		_native_devices_urandom_mounted=$_native_devices_mounted_ledger _native_devices_urandom_metadata=$_native_devices_metadata
		;;
	*) return 1 ;;
	esac
}

# ls uses fixed basenames only after changing into the physically checked private
# directory. Capture/parser output and the fresh guard record are bounded.
_cfmgr_native_devices_metadata_action() {
	cd -P "$_execution_image/dev" && [ "$PWD" = "$_execution_image/dev" ] || return 1
	"$_isolation_test" -c "$_native_devices_name" && "$_isolation_test" ! -L "$_native_devices_name" || return 1
	cfmgr_io_capture 0 4096 4096 ls -dni "$_native_devices_name" || return 1
	_cfmgr_storage_ok 0 || return 1
	_storage_parser=$_isolation_storage_parser
	_cfmgr_storage_parse 0 1 "char$_native_devices_name" || return 1
	_cfmgr_isolation_read "$_io_stage/1.out" || return 1
	_cfmgr_isolation_write "$2" "$_isolation_text"
}

_cfmgr_native_devices_metadata() {
	[ "$_native_devices_observations" -lt 12 ] || return 1
	_native_devices_observation=$_isolation_guard/device-observation-$_native_devices_observations
	_native_devices_observations=$((_native_devices_observations + 1))
	if [ -n "$_isolation_tools" ]; then
		cfmgr_io_test "$_isolation_root" "$_isolation_tools" workspace _cfmgr_native_devices_metadata_action "$_native_devices_observation" || return 1
	else
		cfmgr_io_with_workspace "$_isolation_root" _cfmgr_native_devices_metadata_action "$_native_devices_observation" || return 1
	fi
	# IO cleanup must have returned zero before this observation can be authority.
	_cfmgr_isolation_read "$_native_devices_observation" || return 1
	_native_devices_observed_metadata=$_isolation_text
	_native_devices_inode=${_isolation_text%%"$_io_lf"*}
	_native_devices_inode=${_native_devices_inode#"char$_native_devices_name$_io_tab"}
	_cfmgr_io_decimal "$_native_devices_inode" positive || return 1
	_native_devices_expected="char$_native_devices_name$_io_tab$_native_devices_inode$_io_lf"
	[ "$_isolation_text" = "${_native_devices_expected}end$_io_tab${#_native_devices_expected}$_io_lf" ] || return 1
	if [ -z "$_native_devices_metadata" ]; then
		_native_devices_metadata=$_native_devices_observed_metadata
		_cfmgr_isolation_write "$_isolation_guard/metadata-$_native_devices_name" "$_native_devices_metadata" || return 1
		_cfmgr_native_devices_save || return 1
	else
		[ "$_native_devices_observed_metadata" = "$_native_devices_metadata" ] || return 1
		_cfmgr_isolation_read "$_isolation_guard/metadata-$_native_devices_name" || return 1
		[ "$_isolation_text" = "$_native_devices_metadata" ] || return 1
	fi
}

_cfmgr_native_devices_source_check() {
	_cfmgr_isolation_private || return 1
	[ "$_isolation_id" = "$_isolation_ram_id" ] &&
		[ "${_isolation_body%"$_io_tab"*}" = "${_execution_ram_body%"$_io_tab"*}" ] || return 1
	[ "$_isolation_fs_target" = "${_execution_source_root}2f6465762f$_native_devices_name_hex" ] || return 1
	"$_isolation_test" -c "$_native_devices_source_path" && "$_isolation_test" ! -L "$_native_devices_source_path"
}

_cfmgr_native_devices_source() {
	_cfmgr_isolation_query "$_native_devices_source_path" 2 && _cfmgr_native_devices_source_check || return 1
	if [ -n "$_native_devices_source_ledger" ]; then
		[ "$_isolation_ledger" = "$_native_devices_source_ledger" ] || return 1
	else
		_native_devices_source_ledger=$_isolation_ledger
		_cfmgr_isolation_write "$_isolation_guard/source-$_native_devices_name" "$_native_devices_source_ledger" || return 1
		_cfmgr_native_devices_save || return 1
	fi
	_cfmgr_native_devices_metadata
}

_cfmgr_native_devices_prepare() {
	[ ! -e "$_execution_image/dev" ] && [ ! -L "$_execution_image/dev" ] || return 129
	"$_isolation_mkdir" -m 700 "$_execution_image/dev" || return 129
	_cfmgr_isolation_root_empty "$_execution_image/dev" || return 129
	for _native_devices_initial in null urandom; do
		_cfmgr_native_devices_name "$_native_devices_initial" || return 129
		[ ! -e "$_native_devices_source_path" ] && [ ! -L "$_native_devices_source_path" ] || return 129
		"$_native_devices_mknod" -m 600 "$_native_devices_source_path" c 1 "$_native_devices_minor" || return 129
		_cfmgr_native_devices_source || return 129
	done
}

# Explicit RO/nosuid/noexec on the child; dev is the default and need not be
# spelled by mountinfo. The original RAM superblock remains RW/executable.
_cfmgr_native_devices_options() (
	[ "$#" -eq 2 ] && _cfmgr_io_hex "$1" && _cfmgr_io_hex "$2" || return 1
	_cfmgr_entware_options "$2" "$2" || return 1
	_native_devices_ro=0 _native_devices_nosuid=0 _native_devices_noexec=0
	_native_devices_options=$1 _native_devices_start=1
	while :; do
		case $_native_devices_options in '') break ;; esac
		case $_native_devices_start in 1)
			case $_native_devices_options in
			726f | 726f2c*) _native_devices_ro=1 ;;
			6e6f73756964 | 6e6f737569642c*) _native_devices_nosuid=1 ;;
			6e6f65786563 | 6e6f657865632c*) _native_devices_noexec=1 ;;
			7277 | 72772c* | 73756964 | 737569642c* | 6e6f646576 | 6e6f6465762c* | 65786563 | 657865632c*) return 1 ;;
			esac
			;;
		esac
		case $_native_devices_options in 2c*) _native_devices_start=1 ;; *) _native_devices_start=0 ;; esac
		_native_devices_options=${_native_devices_options#??}
	done
	[ "$_native_devices_ro:$_native_devices_nosuid:$_native_devices_noexec" = 1:1:1 ]
)

_cfmgr_native_devices_view_check() {
	_cfmgr_isolation_private || return 1
	_native_devices_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- ${_native_devices_source_ledger%%"$_io_lf"*}
	IFS=$_native_devices_saved_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] || return 1
	[ "$_isolation_parent" = "$_execution_mount_id" ] && [ "$_isolation_id" != "$_execution_mount_id" ] &&
		[ "$_isolation_id" != "$_isolation_ram_id" ] || return 1
	[ "$_isolation_device" = "$4" ] && [ "$_isolation_fs" = "$7" ] && [ "$_isolation_super" = "${10}" ] || return 1
	[ "$_isolation_mount_root" = "${11}" ] && [ "$_isolation_fs_target" = "${11}" ] || return 1
	_native_devices_expected_source=$8
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_execution_base_body
	IFS=$_native_devices_saved_ifs
	[ "$_isolation_point" = "${6}2f6465762f$_native_devices_name_hex" ] || return 1
	case " $_execution_native_ids " in *" $_isolation_id "*) return 1 ;; esac
	for _native_devices_other in "$_execution_tmp_mounted_ledger" "$_entware_root_mounted_ledger"; do
		IFS=$_io_tab
		# shellcheck disable=SC2086
		set -- ${_native_devices_other%%"$_io_lf"*}
		IFS=$_native_devices_saved_ifs
		[ "$_isolation_id" != "$2" ] || return 1
	done
	case $_native_devices_name in
	null) _native_devices_other=$_native_devices_urandom_mounted ;;
	urandom) _native_devices_other=$_native_devices_null_mounted ;;
	esac
	if [ -n "$_native_devices_other" ]; then
		IFS=$_io_tab
		# shellcheck disable=SC2086
		set -- ${_native_devices_other%%"$_io_lf"*}
		IFS=$_native_devices_saved_ifs
		[ "$_isolation_id" != "$2" ] || return 1
	fi
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_isolation_body
	IFS=$_native_devices_saved_ifs
	[ "$8" = "$_native_devices_expected_source" ] || return 1
	"$_isolation_test" -c "$_native_devices_path" && "$_isolation_test" ! -L "$_native_devices_path" &&
		"$_isolation_test" "$_native_devices_source_path" -ef "$_native_devices_path" || return 1
	_native_devices_identity="$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab${11}"
}

_cfmgr_native_devices_fallback_check() {
	_cfmgr_isolation_private || return 1
	[ "$_isolation_body" = "${_execution_base_body%"$_io_tab"*}$_io_tab${_execution_source_root}2f6465762f$_native_devices_name_hex" ] || return 1
	"$_isolation_test" -c "$_native_devices_path" && "$_isolation_test" ! -L "$_native_devices_path" &&
		"$_isolation_test" "$_native_devices_source_path" -ef "$_native_devices_path"
}

_cfmgr_native_devices_saved() {
	for _native_devices_piece in source fallback mounted metadata; do
		_cfmgr_isolation_read "$_isolation_guard/$_native_devices_piece-$_native_devices_name" || return 1
		case $_native_devices_piece in
		source) [ "$_isolation_text" = "$_native_devices_source_ledger" ] || return 1 ;;
		fallback) [ "$_isolation_text" = "$_native_devices_fallback_ledger" ] || return 1 ;;
		mounted) [ "$_isolation_text" = "$_native_devices_mounted_ledger" ] || return 1 ;;
		metadata) [ "$_isolation_text" = "$_native_devices_metadata" ] || return 1 ;;
		esac
	done
	_cfmgr_isolation_read "$_isolation_guard/intent-$_native_devices_name" || return 1
	[ "$_isolation_text" = "$_native_devices_name$_io_lf" ]
}

_cfmgr_native_devices_build() {
	_cfmgr_native_devices_name "$1" || return 129
	_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_fallback_check || return 129
	_native_devices_fallback_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/fallback-$_native_devices_name" "$_native_devices_fallback_ledger" || return 129
	_cfmgr_isolation_write "$_isolation_guard/intent-$_native_devices_name" "$_native_devices_name$_io_lf" || return 129
	_cfmgr_native_devices_source || return 129
	_cfmgr_isolation_native_call "bind-$_native_devices_name" "$_isolation_mount" -n -i -o bind \
		"$_native_devices_source_path" "$_native_devices_path" || return 129
	_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_view_check &&
		_cfmgr_entware_options "$_isolation_options" "$_isolation_super" || return 129
	_native_devices_first_identity=$_native_devices_identity _native_devices_first_body=$_isolation_body
	_cfmgr_isolation_native_call "private-$_native_devices_name" "$_isolation_mount" -n -i -o make-private "$_native_devices_path" || return 129
	_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_view_check || return 129
	[ "$_native_devices_identity" = "$_native_devices_first_identity" ] && [ "$_isolation_body" = "$_native_devices_first_body" ] || return 129
	_cfmgr_isolation_native_call "remount-$_native_devices_name" "$_isolation_mount" -n -i -o remount,bind,ro,nosuid,noexec,dev \
		"$_native_devices_source_path" "$_native_devices_path" || return 129
	_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_view_check &&
		_cfmgr_native_devices_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_native_devices_identity" = "$_native_devices_first_identity" ] || return 129
	_native_devices_mounted_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/mounted-$_native_devices_name" "$_native_devices_mounted_ledger" || return 129
	_cfmgr_native_devices_save || return 129
	_native_devices_count=$((_native_devices_count + 1))
}

_cfmgr_native_devices_layout_check() {
	[ "$_native_devices_count" -eq 2 ] || return 1
	for _native_devices_checked in null urandom; do
		_cfmgr_native_devices_name "$_native_devices_checked" && _cfmgr_native_devices_saved || return 1
		_cfmgr_native_devices_source || return 1
		_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_view_check &&
			_cfmgr_native_devices_options "$_isolation_options" "$_isolation_super" || return 1
		[ "$_isolation_ledger" = "$_native_devices_mounted_ledger" ] || return 1
	done
}

_cfmgr_native_devices_remove() {
	_cfmgr_native_devices_name "$1" && _cfmgr_native_devices_saved || return 129
	_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_view_check &&
		_cfmgr_native_devices_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_isolation_ledger" = "$_native_devices_mounted_ledger" ] || return 129
	_cfmgr_isolation_unmount "umount-$_native_devices_name" "$_native_devices_path" || return 129
	_cfmgr_isolation_query "$_native_devices_path" 0 && _cfmgr_native_devices_fallback_check || return 129
	[ "$_isolation_ledger" = "$_native_devices_fallback_ledger" ] || return 129
	_cfmgr_native_devices_metadata || return 129
	_native_devices_count=$((_native_devices_count - 1))
}
