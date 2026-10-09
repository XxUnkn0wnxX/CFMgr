#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Requires trusted io.sh/storage.sh definitions already loaded. Source-only.
# Caller-approved volume identity is independent of the current observation.
# Admission is not an atomic write lease or proof of physical media health.
# The trusted native callback must be synchronous, retain no asynchronous users,
# and route signals to the storage IO owner. Caller tracing must already be off.

cfmgr_entware_with() {
	_cfmgr_entware_owner production "$@"
}

# Explicit trusted fixture API: the eight storage fixture inputs, followed by
# EXPECTED_UUID EXPECTED_FS_TARGET_HEX CALLBACK [ARGS...].
cfmgr_entware_with_test() {
	_cfmgr_entware_owner fixture "$@"
}

_cfmgr_entware_owner() (
	set +x
	set +e
	set +u
	set -f
	trap - 0 HUP INT TERM
	umask 077
	IFS=' 	'
	IFS="${IFS}
"
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	export PATH LC_ALL
	unset ENV BASH_ENV CDPATH LD_LIBRARY_PATH LD_PRELOAD
	[ "$#" -ge 1 ] || return 2
	_entware_mode=$1
	shift
	case $_entware_mode in
	production)
		[ "$#" -ge 6 ] || return 2
		_entware_root=$1
		_entware_mount_parser=$2
		_entware_storage_parser=$3
		shift 3
		;;
	fixture)
		[ "$#" -ge 11 ] || return 2
		_entware_root=$1
		_entware_tools=$2
		_entware_target=$3
		_entware_mount_input=$4
		_entware_fdinfo_input=$5
		_entware_block_file=$6
		_entware_mount_parser=$7
		_entware_storage_parser=$8
		shift 8
		;;
	*) return 2 ;;
	esac
	_cfmgr_entware_uuid "$1" || return 2
	[ "${#2}" -le 8192 ] && _cfmgr_io_hex_path "$2" || return 2
	_cfmgr_storage_callback_name "$3" || return 2
	case $_entware_mode in
	production)
		cfmgr_storage_with "$_entware_root" "$_entware_mount_parser" "$_entware_storage_parser" _cfmgr_entware_admit "$@"
		;;
	fixture)
		cfmgr_storage_with_test "$_entware_root" "$_entware_tools" "$_entware_target" "$_entware_mount_input" "$_entware_fdinfo_input" "$_entware_block_file" "$_entware_mount_parser" "$_entware_storage_parser" _cfmgr_entware_admit "$@"
		;;
	esac
) >/dev/null 2>&1

_cfmgr_entware_uuid() (
	[ "$#" -eq 1 ] && [ "${#1}" -eq 36 ] || return 2
	_entware_uuid_rest=$1
	for _entware_uuid_width in 8 4 4 4 12; do
		_entware_uuid_piece=${_entware_uuid_rest%%-*}
		[ "${#_entware_uuid_piece}" -eq "$_entware_uuid_width" ] || return 2
		case $_entware_uuid_piece in *[!0123456789abcdef]*) return 2 ;; esac
		_entware_uuid_rest=${_entware_uuid_rest#"$_entware_uuid_piece"}
		if [ "$_entware_uuid_width" -ne 12 ]; then
			case $_entware_uuid_rest in -*) _entware_uuid_rest=${_entware_uuid_rest#-} ;; *) return 2 ;; esac
		fi
	done
	[ -z "$_entware_uuid_rest" ] && [ "$1" != 00000000-0000-0000-0000-000000000000 ]
)

# Only storage invokes this callback, with its already verified complete ledger
# and both original descriptors retained. Forward the original bytes unchanged.
_cfmgr_entware_admit() {
	[ "$#" -ge 5 ] || return 2
	_cfmgr_entware_volume_ready "$2" "$3" "$4" || return 1
	_entware_admitted_target=$1
	_entware_admitted_ledger=$2
	_entware_callback=$5
	shift 5
	"$_entware_callback" "$_entware_admitted_target" "$_entware_admitted_ledger" "$@"
}

_cfmgr_entware_volume_ready() (
	[ "$#" -eq 3 ] || return 1
	_entware_expected_uuid=$2
	_entware_expected_fs=$3
	_entware_lf='
'
	_entware_body=${1%%"$_entware_lf"*}
	IFS='	'
	set -f
	# Storage verifies the ledger framing and supported ext profile. Split only
	# its ten nonempty facts; no ledger-derived selector or command is executed.
	# shellcheck disable=SC2086
	set -- $_entware_body
	[ "$#" -eq 10 ] && [ "$1" = volume ] || return 1
	[ "${10}" = "$_entware_expected_uuid" ] && [ "$7" = "$_entware_expected_fs" ] || return 1
	_cfmgr_entware_options "$8" "$9"
)

# Byte-aligned option tokens: comma is 2c. Values containing rw/ro/noexec bytes
# do not count as flags. Both lists must explicitly admit RW and execution.
_cfmgr_entware_options() (
	[ "$#" -eq 2 ] || return 1
	for _entware_options in "$1" "$2"; do
		_entware_rw=0
		_entware_token_start=1
		while :; do
			case $_entware_options in '') break ;; esac
			case $_entware_token_start in
			1)
				case $_entware_options in
				7277 | 72772c*) _entware_rw=1 ;;
				726f | 726f2c* | 6e6f65786563 | 6e6f657865632c*) return 1 ;;
				esac
				;;
			esac
			case $_entware_options in 2c*) _entware_token_start=1 ;; *) _entware_token_start=0 ;; esac
			_entware_options=${_entware_options#??}
		done
		[ "$_entware_rw" -eq 1 ] || return 1
	done
)
