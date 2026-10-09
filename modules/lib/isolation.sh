#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Internal owned-root lifecycle; trusted io.sh/storage.sh definitions required.
# Fixed probes additionally require trusted closure.sh/supervision.sh definitions.
# Native-data/tmp/Opt roots also require native_config.sh definitions.
# Native Opt additionally requires explicitly loaded entware_root.sh helpers.
# The fixed-device profile also requires native_devices.sh definitions.
# Failed preparation retains its guard because normalized failure does not
# prove that an interrupted intermediate left no producer.
# Sourcing defines functions only; no CLI or general Opt execution approval.
# ROOT/native firmware/parser code are trusted. Native callback APIs admit only
# synchronous native work: no mounts, asynchronous users, Entware, or owner
# metadata/trap changes. Fixed probes use only the separate completion gate.
# Caller tracing must already be off. Route signals to the active IO owner.
# An active mutation/callback or unproved mount retains the guard for manual
# recovery. Path checks are observations, not atomic namespace/device leases.
# Per-entry subshell state is inherited by its nested trusted callbacks.
# shellcheck disable=SC2154,SC2030,SC2031

cfmgr_isolation_with() (
	_isolation_mode=native
	_isolation_probe_pending=0
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
	_isolation_mode=native
	_isolation_probe_pending=0
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

# Only fixed timeout/gzip probes. The caller has already bounded/acquired the
# private manifest and approved hashes, provenance and the fixed ELF profile.
# Trust is not derived from caller-supplied hashes or this staging operation.
cfmgr_isolation_probe() (
	_isolation_mode=probe
	_isolation_probe_pending=0
	[ "$#" -eq 8 ] || return 2
	_isolation_root=$1
	_isolation_parser=$2
	_isolation_storage_parser=$3
	_isolation_probe_profile=$4
	_isolation_probe_manifest=$5
	_isolation_probe_timeout=$6
	_isolation_probe_gzip=$7
	_isolation_probe_mode=$8
	_isolation_tools=
	_isolation_input=/proc/self/mountinfo
	_cfmgr_isolation_probe_args || return 2
	cfmgr_storage_with "$_isolation_root" "$_isolation_parser" "$_isolation_storage_parser" \
		_cfmgr_isolation_probe_begin _cfmgr_isolation_probe_run
)

# Storage fixture fields, then PROFILE MANIFEST TIMEOUT_FILE GZIP_FILE MODE.
cfmgr_isolation_probe_test() (
	_isolation_mode=probe
	_isolation_probe_pending=0
	[ "$#" -eq 13 ] && [ -n "$2" ] && [ -n "$6" ] || return 2
	_isolation_root=$1
	_isolation_tools=$2
	_isolation_target=$3
	_isolation_input=$4
	_isolation_fdinfo=$5
	_isolation_block=$6
	_isolation_parser=$7
	_isolation_storage_parser=$8
	_isolation_probe_profile=$9
	_isolation_probe_manifest=${10}
	_isolation_probe_timeout=${11}
	_isolation_probe_gzip=${12}
	_isolation_probe_mode=${13}
	_cfmgr_isolation_probe_args || return 2
	for _isolation_path in "$_isolation_tools" "$_isolation_target" "$_isolation_input" "$_isolation_fdinfo" "$_isolation_block"; do
		_cfmgr_closure_path "$_isolation_path" || return 2
	done
	cfmgr_storage_with_test "$_isolation_root" "$_isolation_tools" "$_isolation_target" \
		"$_isolation_input" "$_isolation_fdinfo" "$_isolation_block" "$_isolation_parser" \
		"$_isolation_storage_parser" _cfmgr_isolation_probe_begin _cfmgr_isolation_probe_run
)

_cfmgr_isolation_probe_args() {
	case $_isolation_probe_profile in aarch64-k3.10 | armv7sf-k3.2 | mipselsf-k3.4) ;; *) return 2 ;; esac
	case $_isolation_probe_mode in timeout | gzip) ;; *) return 2 ;; esac
	_cfmgr_isolation_path "$_isolation_root" || return 2
	for _isolation_path in "$_isolation_parser" "$_isolation_storage_parser" \
		"$_isolation_probe_manifest" "$_isolation_probe_timeout" "$_isolation_probe_gzip"; do
		_cfmgr_closure_path "$_isolation_path" || return 2
	done
}

_cfmgr_isolation_path() (
	case $1 in / | /*) ;; *) return 1 ;; esac
	[ "${#1}" -le 4096 ] || return 1
	case $1 in *[[:cntrl:]]* | *//* | */./* | */../* | */. | */.. | ?*/) return 1 ;; esac
)

_cfmgr_isolation_tool() (
	case $1 in mount | umount | mkdir | rm | printf | test | ln | mknod) ;; *) return 2 ;; esac
	if [ -n "$_isolation_tools" ]; then
		[ -x "$_isolation_tools/$1" ] && [ ! -d "$_isolation_tools/$1" ] || return 1
		printf '%s\n' "$_isolation_tools/$1"
	elif [ "$1" = mount ] || [ "$1" = umount ]; then
		[ -x "/bin/$1" ] && [ ! -d "/bin/$1" ] || return 1
		printf '/bin/%s\n' "$1"
	elif [ "$1" = ln ] || [ "$1" = mknod ]; then
		for _isolation_dir in /sbin /bin /usr/sbin /usr/bin; do
			if [ -x "$_isolation_dir/$1" ] && [ ! -d "$_isolation_dir/$1" ]; then
				printf '%s/%s\n' "$_isolation_dir" "$1"
				return
			fi
		done
		return 1
	else
		_cfmgr_io_find "$1"
	fi
)

# Owned mount/intent metadata is <=64KiB and <=3 LF records. Reconstruct exact bytes:
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

# BusyBox changed loop cleanup from default/-D to opt-in/-d. Admit only its
# unambiguous full help advertisement, without assuming firmware/version or -n
# help visibility (Merlin can hide -n with MTAB_SUPPORT disabled).
_cfmgr_isolation_umount_admit() {
	_isolation_umount_profile=
	_isolation_umount_help=$_isolation_guard/umount-help
	[ ! -e "$_isolation_umount_help" ] && [ ! -L "$_isolation_umount_help" ] || return 1
	(
		# POSIX file-limit units are 512 bytes; leave headroom above the 4KiB
		# accepted output while bounding a faulty producer's staged file.
		ulimit -f 16 || exit 1
		set -C
		"$_isolation_umount" --help >"$_isolation_umount_help" 2>&1
	)
	_isolation_help_status=$?
	case $_isolation_help_status in 0) ;; 129 | 130 | 143) return "$_isolation_help_status" ;; *) return 1 ;; esac
	_cfmgr_isolation_umount_classify "$_isolation_umount_help"
}

_cfmgr_isolation_umount_classify() {
	_isolation_umount_profile=
	_isolation_help_profile=
	_isolation_help_size=$(_cfmgr_io_size "$1") || return 1
	[ "$_isolation_help_size" -gt 0 ] && [ "$_isolation_help_size" -le 4096 ] || return 1
	_isolation_help_text=
	_isolation_help_line=
	_isolation_help_lines=0
	_isolation_help_usage=0
	while IFS= read -r _isolation_help_line; do
		_isolation_help_lines=$((_isolation_help_lines + 1))
		[ "$_isolation_help_lines" -le 32 ] || return 1
		case $_isolation_help_line in *[!\ -~"$_io_tab"]*) return 1 ;; esac
		_isolation_help_text=$_isolation_help_text$_isolation_help_line$_io_lf
		if [ "$_isolation_help_lines" -eq 1 ]; then
			case $_isolation_help_line in "BusyBox v"[0123456789]*" multi-call binary.") ;; *) return 1 ;; esac
		fi
		case $_isolation_help_line in "Usage: umount" | "Usage: umount "*) _isolation_help_usage=$((_isolation_help_usage + 1)) ;; esac
		_isolation_help_option=$_isolation_help_line
		while :; do
			case $_isolation_help_option in " "* | "$_io_tab"*) _isolation_help_option=${_isolation_help_option#?} ;; *) break ;; esac
		done
		case $_isolation_help_option in
		-D* | -d*)
			[ -z "$_isolation_help_profile" ] || return 1
			_isolation_help_description=${_isolation_help_option#??}
			case $_isolation_help_description in " "* | "$_io_tab"*) ;; *) return 1 ;; esac
			while :; do
				case $_isolation_help_description in " "* | "$_io_tab"*) _isolation_help_description=${_isolation_help_description#?} ;; *) break ;; esac
			done
			case $_isolation_help_option in
			-D*)
				[ "$_isolation_help_description" = "Don't free loop device even if it has been used" ] || return 1
				_isolation_help_profile=legacy
				;;
			-d*)
				[ "$_isolation_help_description" = "Free loop device if it has been used" ] || return 1
				_isolation_help_profile=modern
				;;
			esac
			;;
		esac
	done <"$1"
	[ -z "$_isolation_help_line" ] && [ "${#_isolation_help_text}" -eq "$_isolation_help_size" ] && [ "$_isolation_help_usage" -eq 1 ] && [ -n "$_isolation_help_profile" ] || return 1
	_isolation_umount_profile=$_isolation_help_profile
}

_cfmgr_isolation_unmount() {
	case $_isolation_umount_profile in
	legacy) _cfmgr_isolation_native_call "$1" "$_isolation_umount" -D -n "$2" ;;
	modern) _cfmgr_isolation_native_call "$1" "$_isolation_umount" -n "$2" ;;
	*) return 1 ;;
	esac
}

# Each query uses a fresh two-capture IO owner, outside the mounted tree. Its
# checked ledger is written exclusively, then checked again after IO cleanup.
# Old/bare use 16 queries; native profiles use 64/78/106. No slot reuse
# or unbounded retries. Native/native-data use 56 observations; native-tmp uses 64.
# A complete probe uses14: three admission, source recheck, null bind, image
# parent, three image steps, two checks per unmount, and final RAM cleanup.
_cfmgr_isolation_query_action() {
	_cfmgr_io_mount_capture "$2" "$_isolation_parser" "$_isolation_input" 0 1 topology || return 1
	if [ "$4" = 1 ] || [ "$4" = 2 ]; then
		case $4 in 1) _isolation_canonical_target=$_isolation_root ;; 2) _isolation_canonical_target=$2 ;; esac
		cfmgr_io_capture 2 4097 4096 readlink -f "$_isolation_canonical_target" || return 1
		_cfmgr_storage_ok 2 && _cfmgr_storage_line 2 || return 1
		[ "$_storage_line" = "$_isolation_canonical_target" ] || return 1
	fi
	_cfmgr_isolation_write "$3" "$_mount_ledger"
}

_cfmgr_isolation_query() {
	# Only literal owner/layouts select ceilings; no ambient limit is read.
	case ${_isolation_mode-}:${_execution_layout-} in
	root:native-devices) [ "$_isolation_queries" -lt 106 ] || return 1 ;;
	root:native-opt) [ "$_isolation_queries" -lt 78 ] || return 1 ;;
	root:native | root:native-data | root:native-tmp) [ "$_isolation_queries" -lt 64 ] || return 1 ;;
	*) [ "$_isolation_queries" -lt 16 ] || return 1 ;;
	esac
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
	_isolation_parent=$3
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

# The final image has per-mount RO/nosuid/nodev and exec capability, while the
# admitted RAM superblock remains RW/exec. Explicit contradictory flags reject.
_cfmgr_isolation_image_options() (
	[ "$#" -eq 2 ] || return 1
	_cfmgr_isolation_options "$2" "$2" ram || return 1
	_cfmgr_isolation_readonly_options "$1"
)

_cfmgr_isolation_readonly_options() (
	_image_options=$1
	_image_ro=0
	_image_nosuid=0
	_image_nodev=0
	_image_start=1
	while :; do
		case $_image_options in '') break ;; esac
		if [ "$_image_start" -eq 1 ]; then
			case $_image_options in
			726f | 726f2c*) _image_ro=1 ;;
			6e6f73756964 | 6e6f737569642c*) _image_nosuid=1 ;;
			6e6f646576 | 6e6f6465762c*) _image_nodev=1 ;;
			7277 | 72772c* | 6e6f65786563 | 6e6f657865632c* | 73756964 | 737569642c* | 646576 | 6465762c*) return 1 ;;
			esac
		fi
		case $_image_options in 2c*) _image_start=1 ;; *) _image_start=0 ;; esac
		_image_options=${_image_options#??}
	done
	[ "$_image_ro$_image_nosuid$_image_nodev" = 111 ]
)

_cfmgr_isolation_active() {
	_cfmgr_isolation_write "$_isolation_guard/active" "$1$_io_lf"
}

_cfmgr_isolation_clear() {
	"$_isolation_rm" -f "$_isolation_guard/active" || return 1
	[ ! -e "$_isolation_guard/active" ] && [ ! -L "$_isolation_guard/active" ]
}

_cfmgr_isolation_native_call() {
	case ${_isolation_mode-} in root)
		_cfmgr_isolation_root_call "$@"
		return "$?"
		;;
	esac
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

_cfmgr_isolation_image_stage() {
	# The preparation marker protects even partially copied image subdirectories.
	_isolation_stage_attempted=1
	_closure_complete=0
	_closure_opt=
	_closure_total=
	if [ -n "$_isolation_tools" ]; then
		cfmgr_closure_test "$_isolation_guard" "$_isolation_probe_profile" "$_isolation_probe_manifest" \
			"$_isolation_probe_timeout" "$_isolation_probe_gzip" "$_isolation_target" "$_isolation_tools" || return 1
	else
		_cfmgr_closure_stage "$_isolation_guard" "$_isolation_probe_profile" "$_isolation_probe_manifest" \
			"$_isolation_probe_timeout" "$_isolation_probe_gzip" || return 1
	fi
	[ "$_closure_complete" = 1 ] && [ "$_closure_opt" = "$_isolation_guard/closure/opt" ] || return 1
	case $_closure_total in '' | 0* | *[!0123456789]*) return 1 ;; esac
	[ "${#_closure_total}" -le 7 ] && [ "$_closure_total" -le 8388608 ] || return 1
	for _isolation_dir in "$_isolation_guard/closure" "$_closure_opt" "$_closure_opt/lib" "$_closure_opt/libexec"; do
		[ -d "$_isolation_dir" ] && [ ! -L "$_isolation_dir" ] || return 1
	done
	_isolation_image=$_closure_opt
	# Staging's outside alias is now frozen. Recheck its unchanged private RAM
	# identity with no descendants before admitting it as a bind source.
	_cfmgr_isolation_absent "$_isolation_image" 63666d67722d69736f6c6174696f6e2f636c6f737572652f6f7074 || return 1
	_isolation_image_root=$_isolation_fs_target
	_isolation_image_device=$_isolation_device
	_isolation_image_fs=$_isolation_fs
	_isolation_image_super=$_isolation_super
}

_cfmgr_isolation_image_check() {
	[ "$_isolation_parent" = "$_isolation_ram_id" ] &&
		[ "$_isolation_id" != "$_isolation_ram_id" ] && [ "$_isolation_id" != "$_isolation_source_id" ] || return 1
	[ "$_isolation_device" = "$_isolation_image_device" ] &&
		[ "$_isolation_fs" = "$_isolation_image_fs" ] && [ "$_isolation_super" = "$_isolation_image_super" ] || return 1
	# For the canonical queried destination, mount-root == filesystem-target
	# means there is no relative suffix: the selected mount is exactly that path.
	[ "$_isolation_mount_root" = "$_isolation_image_root" ] &&
		[ "$_isolation_mount_root" = "$_isolation_fs_target" ] || return 1
	_isolation_image_identity="$_isolation_id$_io_tab$_isolation_parent$_io_tab$_isolation_device$_io_tab$_isolation_fs$_io_tab$_isolation_mount_root$_io_tab$_isolation_point$_io_tab$_isolation_fs_target"
}

_cfmgr_isolation_image_bind() {
	# Prove this destination is still the private RAM parent with no submounts.
	_cfmgr_isolation_absent "$_isolation_tree/opt" 63666d67722d69736f6c6174696f6e2f726f6f742f6f7074 || return 1
	_isolation_attempted=1
	_cfmgr_isolation_write "$_isolation_guard/intent-opt" "opt$_io_lf" || return 1
	_cfmgr_isolation_native_call bind-opt "$_isolation_mount" -n -i -o bind,ro \
		"$_isolation_image" "$_isolation_tree/opt" || return "$?"
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_isolation_image_check &&
		_cfmgr_isolation_private || return 1
	_isolation_image_first=$_isolation_image_identity
	_cfmgr_isolation_native_call private-opt "$_isolation_mount" -n -i -o make-private "$_isolation_tree/opt" || return "$?"
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_isolation_image_check &&
		_cfmgr_isolation_private || return 1
	[ "$_isolation_image_identity" = "$_isolation_image_first" ] || return 1
	_cfmgr_isolation_native_call remount-opt "$_isolation_mount" -n -i -o remount,bind,ro,nosuid,nodev,exec \
		"$_isolation_image" "$_isolation_tree/opt" || return "$?"
	_cfmgr_isolation_query "$_isolation_tree/opt" 0 && _cfmgr_isolation_image_check &&
		_cfmgr_isolation_private || return 1
	[ "$_isolation_image_identity" = "$_isolation_image_first" ] || return 1
	_cfmgr_isolation_image_options "$_isolation_options" "$_isolation_super" || return 1
	_cfmgr_isolation_write "$_isolation_guard/mounted-opt" "$_isolation_ledger" || return 1
	_isolation_opt_body=$_isolation_body
	_isolation_opt_ledger=$_isolation_ledger
	_isolation_opt_recorded=1
}

_cfmgr_isolation_probe_run() {
	_cfmgr_isolation_active "probe-$_isolation_probe_mode" || return 1
	_supervision_started=0
	_supervision_complete=0
	_supervision_status=
	_isolation_probe_pending=1
	if [ -n "$_isolation_tools" ]; then
		cfmgr_supervision_test "$_isolation_guard" "$_isolation_tree" "$_isolation_probe_mode" "$_isolation_tools"
	else
		_cfmgr_supervision_probe "$_isolation_guard" "$_isolation_tree" "$_isolation_probe_mode"
	fi
	_isolation_probe_status=$?
	case $_isolation_probe_status in 129 | 130 | 143) return "$_isolation_probe_status" ;; esac
	case $_supervision_started:$_supervision_complete in
	0:0)
		[ "$_isolation_probe_status" -ne 0 ] || _isolation_probe_status=1
		;;
	1:1)
		case $_supervision_status in
		0 | [1-9] | [1-9][0-9] | 1[0-9][0-9] | 2[0-4][0-9] | 25[0-5]) ;;
		*) return 1 ;;
		esac
		;;
	*)
		[ "$_isolation_probe_status" -ne 0 ] || _isolation_probe_status=1
		return "$_isolation_probe_status"
		;;
	esac
	_cfmgr_isolation_clear || return 1
	_isolation_probe_pending=0
	return "$_isolation_probe_status"
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
	_cfmgr_isolation_unmount "umount-$1" "$2" || return "$?"
	_cfmgr_isolation_absent "$2" "$4"
}

_cfmgr_isolation_cleanup() {
	[ ! -e "$_isolation_guard/active" ] && [ ! -L "$_isolation_guard/active" ] || return 1
	# No syscall intent yet: only the freshly owned ordinary RAM directory exists.
	if [ "$_isolation_attempted" -eq 0 ] && [ "$_isolation_null_recorded" -eq 0 ] && [ "$_isolation_opt_recorded" -eq 0 ] && [ ! -e "$_isolation_guard/intent-null" ] && [ ! -e "$_isolation_guard/intent-opt" ]; then
		if [ "$_isolation_stage_attempted" -eq 1 ]; then
			_cfmgr_isolation_query "$_isolation_root" 0 && _cfmgr_isolation_private || return 1
			[ "$_isolation_body" = "$_isolation_ram_body" ] || return 1
		fi
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
	_cfmgr_isolation_umount_admit || return "$?"
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
	# Protect every private producer, including nested shells that can normalize
	# interruption to ordinary failure. Clear only on full preparation success.
	_cfmgr_isolation_active prepare || return 1
	if [ "$_isolation_mode" = probe ]; then
		_cfmgr_isolation_image_stage || return 1
	fi
	"$_isolation_mkdir" -m 700 "$_isolation_tree" "$_isolation_tree/opt" "$_isolation_tree/dev" "$_isolation_tree/bootstrap" "$_isolation_tree/tmp" "$_isolation_tree/offline" || return 1
	_cfmgr_isolation_write "$_isolation_tree/dev/null" "$_io_lf" || return 1
	if [ "$_isolation_mode" = probe ]; then
		"$_isolation_ln" -s /opt/libexec/timeout-coreutils "$_isolation_tree/bootstrap/timeout-coreutils" &&
			"$_isolation_ln" -s /opt/libexec/gzip-gnu "$_isolation_tree/bootstrap/gzip-gnu" || return 1
	fi
	_cfmgr_isolation_clear || return 1
	_cfmgr_isolation_bind null /dev/null "$_isolation_tree/dev/null" "$_isolation_null_device" "$_isolation_null_root" "$_isolation_null_fs" || return "$?"
	if [ "$_isolation_mode" = probe ]; then
		_cfmgr_isolation_image_bind || return "$?"
		_cfmgr_isolation_probe_run
		return "$?"
	fi
	_cfmgr_isolation_bind opt /proc/self/fd/9 "$_isolation_tree/opt" "$_isolation_source_device" "$_isolation_source_root" "$_isolation_source_fs" || return "$?"
	_cfmgr_isolation_active callback || return 1
	"$_isolation_callback" "$_isolation_tree" "$_isolation_volume" "$@"
	_isolation_callback_status=$?
	case $_isolation_callback_status in 129 | 130 | 143) return "$_isolation_callback_status" ;; esac
	_cfmgr_isolation_clear || return 1
	return "$_isolation_callback_status"
}

_cfmgr_isolation_begin() {
	_isolation_mode=native
	_cfmgr_isolation_begin_common "$@"
}

_cfmgr_isolation_probe_begin() {
	_isolation_mode=probe
	_cfmgr_isolation_begin_common "$@"
}

_cfmgr_isolation_begin_common() {
	_isolation_resolved=$1
	_isolation_volume=$2
	_isolation_callback=$3
	shift 3
	_isolation_guard=${_isolation_root%/}/cfmgr-isolation
	_isolation_tree=$_isolation_guard/root
	_isolation_queries=0
	_isolation_probe_pending=0
	_isolation_stage_attempted=0
	_isolation_attempted=0
	_isolation_interrupted=0
	_isolation_umount_profile=
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
	if [ "$_isolation_mode" = probe ]; then
		_isolation_ln=$(_cfmgr_isolation_tool ln) || return 1
	fi
	[ ! -e "$_isolation_guard" ] && [ ! -L "$_isolation_guard" ] || return 1
	"$_isolation_mkdir" -m 700 "$_isolation_guard" || return 1
	_cfmgr_isolation_run "$@"
	_isolation_result=$?
	[ "$_isolation_interrupted" -eq 0 ] || return "$_isolation_interrupted"
	case $_isolation_result in 129 | 130 | 143) return "$_isolation_result" ;; esac
	if [ "$_isolation_probe_pending" -eq 1 ]; then
		[ "$_isolation_result" -ne 0 ] || return 1
		return "$_isolation_result"
	fi
	_cfmgr_isolation_cleanup
	_isolation_cleanup_status=$?
	[ "$_isolation_interrupted" -eq 0 ] || return "$_isolation_interrupted"
	[ "$_isolation_cleanup_status" -eq 0 ] || return 1
	_isolation_complete=1
	return "$_isolation_result"
}

# Separate readonly root foundation. GUARD is an exclusive existing direct RAM
# child; callback is synchronous native observation only, without mount/Entware,
# asynchronous users, trap/metadata/FD6 changes or retained descriptors. FD7..9
# are preserved. No application FD above9 is supported. Caller owns deadlines.
cfmgr_isolation_root_with() {
	_cfmgr_isolation_root_owner bare production "$@" >/dev/null 2>&1
}

# Explicit inert host inputs/tools only, never selected from ambient controls.
cfmgr_isolation_root_test() {
	_cfmgr_isolation_root_owner bare fixture "$@" >/dev/null 2>&1
}

# Fixed readonly firmware views only; this still admits no payload or chroot.
cfmgr_isolation_native_root_with() {
	_cfmgr_isolation_root_owner native production "$@" >/dev/null 2>&1
}

cfmgr_isolation_native_root_test() {
	_cfmgr_isolation_root_owner native fixture "$@" >/dev/null 2>&1
}

# The fixed data phase is internal; no caller-selected staging callback/payload.
cfmgr_isolation_native_data_root_with() {
	_cfmgr_isolation_root_owner native-data production "$@" >/dev/null 2>&1
}

cfmgr_isolation_native_data_root_test() {
	_cfmgr_isolation_root_owner native-data fixture "$@" >/dev/null 2>&1
}

cfmgr_isolation_native_tmp_root_with() {
	_cfmgr_isolation_root_owner native-tmp production "$@" >/dev/null 2>&1
}

cfmgr_isolation_native_tmp_root_test() {
	_cfmgr_isolation_root_owner native-tmp fixture "$@" >/dev/null 2>&1
}

_cfmgr_isolation_root_owner() (
	set +x
	set +e
	set +u
	set -f
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
	umask 077
	_execution_reserved=0
	_execution_complete=0
	trap '_cfmgr_isolation_root_owner_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	_execution_layout=$1 _execution_kind=$2
	shift 2
	case $_execution_layout in bare | native | native-data | native-tmp | native-opt | native-devices) ;; *) return 2 ;; esac
	_execution_native_source_root=/
	_execution_data_source_root=/
	_execution_tmp_kib='' _execution_tmp_inodes='' _execution_tmp_ready=0
	_execution_tmp_fallback_ledger='' _execution_tmp_mounted_ledger='' _execution_tmp_first_ledger=''
	_execution_tmp_home=''
	if [ "$_execution_layout" = native-devices ]; then
		_cfmgr_native_devices_reset || return 2
	fi
	case $_execution_kind in
	production)
		[ "$#" -ge 5 ] || return 2
		_isolation_root=$1 _execution_guard=$2
		if [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
			[ "$#" -ge 7 ] || return 2
			_execution_tmp_kib=$3 _execution_tmp_inodes=$4
			shift 2
		fi
		_isolation_parser=$3 _isolation_storage_parser=$4 _isolation_callback=$5
		_isolation_tools=
		_isolation_input=/proc/self/mountinfo
		_execution_fdinfo=/proc/self/fdinfo/6
		shift 5
		;;
	fixture)
		_isolation_root=$1 _execution_guard=$2 _isolation_tools=$3
		_isolation_input=$4 _execution_fdinfo=$5
		case $_execution_layout in
		native)
			[ "$#" -ge 9 ] || return 2
			_execution_native_source_root=$6
			shift
			;;
		native-data)
			[ "$#" -ge 10 ] || return 2
			_execution_native_source_root=$6 _execution_data_source_root=$7
			shift 2
			;;
		native-tmp | native-opt | native-devices)
			[ "$#" -ge 12 ] || return 2
			_execution_native_source_root=$6 _execution_data_source_root=$7
			_execution_tmp_kib=$8 _execution_tmp_inodes=$9
			shift 4
			;;
		bare)
			[ "$#" -ge 8 ] || return 2
			;;
		esac
		_isolation_parser=$6 _isolation_storage_parser=$7 _isolation_callback=$8
		[ -n "$_isolation_tools" ] || return 2
		shift 8
		;;
	*) return 2 ;;
	esac
	_isolation_mode=root
	_isolation_guard=$_execution_guard/execution
	_execution_image=$_isolation_guard/image
	_isolation_tree=$_isolation_guard/root
	for _execution_path in "$_isolation_root" "$_execution_guard" "$_isolation_parser" \
		"$_isolation_storage_parser" "$_isolation_guard" "$_execution_image/opt" "$_isolation_tree" \
		"$_isolation_input" "$_execution_fdinfo"; do
		_cfmgr_isolation_path "$_execution_path" && [ "$_execution_path" != / ] || return 2
	done
	[ -z "$_isolation_tools" ] || _cfmgr_isolation_path "$_isolation_tools" || return 2
	if [ "$_execution_layout" != bare ]; then
		_cfmgr_isolation_path "$_execution_native_source_root" || return 2
		for _execution_view in bin sbin lib usr; do
			_cfmgr_isolation_path "${_execution_native_source_root%/}/$_execution_view" &&
				_cfmgr_isolation_path "$_execution_image/$_execution_view" || return 2
		done
	fi
	if [ "$_execution_layout" = native-data ] || [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		for _execution_path in "$_execution_data_source_root" \
			"${_execution_data_source_root%/}/etc/hosts" "${_execution_data_source_root%/}/etc/resolv.conf" \
			"$_execution_image/etc" "$_execution_image/etc/hosts" "$_execution_image/etc/resolv.conf"; do
			_cfmgr_isolation_path "$_execution_path" || return 2
		done
	fi
	if [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		_cfmgr_isolation_tmp_limits "$_execution_tmp_kib" "$_execution_tmp_inodes" || return 2
		_cfmgr_isolation_path "$_isolation_tree/tmp/cfmgr-home" || return 2
	fi
	if [ "$_execution_layout" = native-devices ]; then
		for _execution_path in "$_execution_image/dev" "$_execution_image/dev/null" "$_execution_image/dev/urandom" \
			"$_isolation_tree/dev/null" "$_isolation_tree/dev/urandom"; do
			_cfmgr_isolation_path "$_execution_path" || return 2
		done
	fi
	[ "${_execution_guard%/*}" = "$_isolation_root" ] || return 2
	_cfmgr_storage_callback_name "$_isolation_callback" || return 2
	cd / || return 1
	[ -d "$_isolation_root" ] && [ ! -L "$_isolation_root" ] &&
		[ -d "$_execution_guard" ] && [ ! -L "$_execution_guard" ] || return 1
	[ ! -e "$_isolation_guard" ] && [ ! -L "$_isolation_guard" ] || return 1
	_io_tools=$_isolation_tools
	_isolation_mount=$(_cfmgr_isolation_tool mount) || return 1
	_isolation_umount=$(_cfmgr_isolation_tool umount) || return 1
	_isolation_mkdir=$(_cfmgr_isolation_tool mkdir) || return 1
	_isolation_rm=$(_cfmgr_isolation_tool rm) || return 1
	_isolation_printf=$(_cfmgr_isolation_tool printf) || return 1
	_isolation_test=$(_cfmgr_isolation_tool test) || return 1
	_io_wc=$(_cfmgr_io_find wc) || return 1
	if [ "$_execution_layout" = native-devices ]; then
		_native_devices_mknod=$(_cfmgr_isolation_tool mknod) || return 1
	fi
	_io_tab='	'
	_io_lf='
'
	# Reservation is authoritative outside IO: even IO's own scratch-cleanup
	# failure must remain uncertainty after the filesystem operation completed.
	_execution_reserved=1
	"$_isolation_mkdir" -m 700 "$_isolation_guard" || return 129
	[ -d "$_isolation_guard" ] && [ ! -L "$_isolation_guard" ] || return 129
	if [ -n "$_isolation_tools" ]; then
		cfmgr_io_test "$_isolation_root" "$_isolation_tools" workspace _cfmgr_isolation_root_io "$@" || return 129
	else
		cfmgr_io_with_workspace "$_isolation_root" _cfmgr_isolation_root_io "$@" || return 129
	fi
	_cfmgr_isolation_root_empty "$_isolation_guard/complete" || return 129
	_cfmgr_isolation_read "$_isolation_guard/result" || return 129
	_execution_result=${_isolation_text%%"$_io_lf"*}
	_execution_status=${_execution_result#"callback$_io_tab"}
	case $_execution_status in 0 | [1-9] | [1-9][0-9] | 1[01][0-9] | 12[0-8]) ;; *) return 129 ;; esac
	_execution_expected="callback$_io_tab$_execution_status$_io_lf"
	_execution_expected="${_execution_expected}end$_io_tab${#_execution_expected}$_io_lf"
	[ "$_isolation_text" = "$_execution_expected" ] || return 129
	_execution_complete=1
	return "$_execution_status"
)

_cfmgr_isolation_root_owner_exit() {
	_execution_exit=$1
	trap - 0
	if [ "$_execution_reserved" -eq 1 ] && { [ "$_execution_complete" -ne 1 ] || [ "$_execution_exit" -gt 128 ]; }; then
		_execution_exit=129
	fi
	exit "$_execution_exit"
}

_cfmgr_isolation_root_empty() (
	[ -d "$1" ] && [ ! -L "$1" ] || return 1
	set +f
	for _execution_entry in "$1"/* "$1"/.[!.]* "$1"/..?*; do
		[ ! -e "$_execution_entry" ] && [ ! -L "$_execution_entry" ] || return 1
	done
)

_cfmgr_isolation_root_io_exit() {
	_execution_exit=$1
	[ "$_execution_io_complete" -eq 1 ] && [ "$_execution_exit" -eq 0 ] || _execution_exit=129
	_cfmgr_io_finish "$_execution_exit"
}

# Unlike older lifecycle callers, any nonzero native result keeps active intent.
# Normalized failure may never authorize teardown in this separate owner.
_cfmgr_isolation_root_call() {
	_cfmgr_isolation_active "$1" || return 129
	shift
	"$@" || return 129
	[ "$_isolation_interrupted" -eq 0 ] || return 129
	_cfmgr_isolation_clear || return 129
}

_cfmgr_isolation_root_ram_path() {
	_cfmgr_isolation_query "$1" 0 && _cfmgr_isolation_private || return 1
	[ "${_isolation_body%"$_io_tab"*}" = "${_execution_ram_body%"$_io_tab"*}" ]
}

_cfmgr_isolation_root_mount_check() {
	_cfmgr_isolation_private || return 1
	[ "$_isolation_id" != "$_isolation_ram_id" ] && [ "$_isolation_parent" = "$_isolation_ram_id" ] || return 1
	[ "$_isolation_device" = "$_execution_device" ] && [ "$_isolation_fs" = "$_execution_fs" ] &&
		[ "$_isolation_super" = "$_execution_super" ] || return 1
	[ "$_isolation_mount_root" = "$_execution_source_root" ] &&
		[ "$_isolation_fs_target" = "$_execution_source_root" ] || return 1
	_execution_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_isolation_body
	IFS=$_execution_saved_ifs
	[ "$8" = "$_execution_source" ] || return 1
	_execution_identity="$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab${11}"
}

# This fresh IO transaction consumes only cat+awk and observes inherited FD6.
_cfmgr_isolation_root_fd_action() {
	cfmgr_io_capture 0 4096 4096 cat "$_execution_fdinfo" || return 1
	_cfmgr_storage_ok 0 || return 1
	_storage_parser=$_isolation_storage_parser
	_cfmgr_storage_parse 0 1 fdinfo || return 1
	[ "$_storage_value" = "$_execution_mount_id" ] || return 1
	"$_isolation_test" -d /proc/self/fd/6 &&
		"$_isolation_test" "$_isolation_tree" -ef /proc/self/fd/6
}

_cfmgr_isolation_root_lease() {
	if [ -n "$_isolation_tools" ]; then
		cfmgr_io_test "$_isolation_root" "$_isolation_tools" workspace _cfmgr_isolation_root_fd_action || return 129
	else
		cfmgr_io_with_workspace "$_isolation_root" _cfmgr_isolation_root_fd_action || return 129
	fi
	if [ "$_execution_layout" != bare ]; then
		_cfmgr_isolation_native_layout_check || return 129
		[ "$_execution_checked_root_ledger" = "$_execution_root_ledger" ] || return 129
	else
		_cfmgr_isolation_query "$_isolation_tree" 0 && _cfmgr_isolation_private || return 129
		[ "$_isolation_ledger" = "$_execution_root_ledger" ] || return 129
	fi
	_cfmgr_isolation_active callback || return 129
	if [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		"$_isolation_callback" "$_isolation_tree" "$_execution_root_ledger" "$_entware_root_volume" "$@"
	else
		"$_isolation_callback" "$_isolation_tree" "$_execution_root_ledger" "$@"
	fi
	_execution_callback_status=$?
	[ "$_execution_callback_status" -le 128 ] && [ "$_isolation_interrupted" -eq 0 ] || return 129
	"$_isolation_test" "$_isolation_tree" -ef /proc/self/fd/6 || return 129
	_cfmgr_isolation_clear || return 129
}

_cfmgr_isolation_root_io() {
	shift
	_execution_io_complete=0
	_isolation_interrupted=0
	_isolation_queries=0
	trap '_cfmgr_isolation_root_io_exit "$?"' 0
	trap '_isolation_interrupted=129; exit 129' HUP INT QUIT TERM
	_cfmgr_isolation_umount_admit || return 129
	_cfmgr_isolation_active prepare || return 129
	"$_isolation_mkdir" -m 700 "$_execution_image" "$_execution_image/opt" "$_execution_image/tmp" "$_isolation_tree" || return 129
	if [ "$_execution_layout" != bare ]; then
		for _execution_view in bin sbin lib usr; do
			"$_isolation_mkdir" -m 700 "$_execution_image/$_execution_view" || return 129
			_cfmgr_isolation_root_empty "$_execution_image/$_execution_view" || return 129
		done
	fi
	[ -d "$_execution_image" ] && [ ! -L "$_execution_image" ] || return 129
	for _execution_directory in "$_execution_image/opt" "$_execution_image/tmp" "$_isolation_tree"; do
		_cfmgr_isolation_root_empty "$_execution_directory" || return 129
	done
	_cfmgr_isolation_query "$_isolation_root" 1 && _cfmgr_isolation_private || return 129
	case $_isolation_fs in tmpfs | ramfs) ;; *) return 129 ;; esac
	_cfmgr_isolation_options "$_isolation_options" "$_isolation_super" ram || return 129
	_execution_ram_body=$_isolation_body
	_isolation_ram_id=$_isolation_id
	_execution_device=$_isolation_device _execution_fs=$_isolation_fs _execution_super=$_isolation_super
	_execution_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_isolation_body "$@"
	IFS=$_execution_saved_ifs
	_execution_source=$8
	shift 11
	_cfmgr_isolation_root_ram_path "$_execution_image" || return 129
	_execution_source_root=$_isolation_fs_target
	_cfmgr_isolation_root_ram_path "$_isolation_tree" || return 129
	_execution_prior_body=$_isolation_body
	if [ "$_execution_layout" = native-data ] || [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		# This outer workspace has no captures yet: queries used nested owners.
		# The checked data subtree becomes RO through the base root bind itself.
		case $_execution_kind in
		production) cfmgr_native_config_stage "$_execution_image" || return 129 ;;
		fixture) cfmgr_native_config_test "$_execution_image" "$_execution_data_source_root" || return 129 ;;
		esac
	fi
	if [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		_cfmgr_entware_root_source || return 129
	fi
	if [ "$_execution_layout" = native-devices ]; then
		_cfmgr_native_devices_prepare || return 129
	fi
	_cfmgr_isolation_clear || return 129
	_cfmgr_isolation_write "$_isolation_guard/intent-root" "root$_io_lf" || return 129
	_cfmgr_isolation_native_call bind-root "$_isolation_mount" -n -i -o bind "$_execution_image" "$_isolation_tree" || return 129
	_cfmgr_isolation_query "$_isolation_tree" 0 && _cfmgr_isolation_root_mount_check &&
		_cfmgr_isolation_options "$_isolation_options" "$_isolation_super" ram || return 129
	_execution_first_identity=$_execution_identity
	_execution_first_body=$_isolation_body
	_cfmgr_isolation_native_call private-root "$_isolation_mount" -n -i -o make-private "$_isolation_tree" || return 129
	_cfmgr_isolation_query "$_isolation_tree" 0 && _cfmgr_isolation_root_mount_check || return 129
	[ "$_execution_identity" = "$_execution_first_identity" ] && [ "$_isolation_body" = "$_execution_first_body" ] || return 129
	_cfmgr_isolation_native_call remount-root "$_isolation_mount" -n -i -o remount,bind,ro,nosuid,nodev,exec \
		"$_execution_image" "$_isolation_tree" || return 129
	_cfmgr_isolation_query "$_isolation_tree" 0 && _cfmgr_isolation_root_mount_check &&
		_cfmgr_isolation_image_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_execution_identity" = "$_execution_first_identity" ] || return 129
	_execution_mount_id=$_isolation_id
	_execution_root_ledger=$_isolation_ledger
	_execution_base_ledger=$_isolation_ledger
	_execution_base_body=$_isolation_body
	_cfmgr_isolation_write "$_isolation_guard/mounted-root" "$_execution_root_ledger" || return 129
	if [ "$_execution_layout" != bare ]; then
		_cfmgr_isolation_write "$_isolation_guard/base-root" "$_execution_base_ledger" || return 129
		_execution_native_count=0
		_execution_native_ids=
		_execution_native_source_common=
		_execution_native_source_base=
		_execution_bin_record='' _execution_sbin_record='' _execution_lib_record='' _execution_usr_record=''
		for _execution_view in bin sbin lib usr; do
			_cfmgr_isolation_native_build "$_execution_view" || return 129
		done
		if [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
			_cfmgr_isolation_tmp_build || return 129
		fi
		if [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
			_cfmgr_entware_root_build || return 129
		fi
		if [ "$_execution_layout" = native-devices ]; then
			_cfmgr_native_devices_build null && _cfmgr_native_devices_build urandom || return 129
		fi
		_cfmgr_isolation_native_layout_check || return 129
		_execution_root_ledger=$_execution_checked_root_ledger
		_cfmgr_isolation_write "$_isolation_guard/populated-root" "$_execution_root_ledger" || return 129
	fi
	_cfmgr_isolation_root_lease "$@" 6<"$_isolation_tree" || return 129
	# Scoped redirection has closed the root lease and restored caller FD6.
	cd / || return 129
	[ ! -e "$_isolation_guard/active" ] && [ ! -L "$_isolation_guard/active" ] || return 129
	if [ "$_execution_layout" != bare ]; then
		_cfmgr_isolation_native_layout_check || return 129
		[ "$_execution_checked_root_ledger" = "$_execution_root_ledger" ] || return 129
		_cfmgr_isolation_read "$_isolation_guard/populated-root" || return 129
		[ "$_isolation_text" = "$_execution_root_ledger" ] || return 129
		if [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
			_cfmgr_entware_root_remove || return 129
		fi
		if [ "$_execution_layout" = native-devices ]; then
			_cfmgr_native_devices_remove urandom && _cfmgr_native_devices_remove null || return 129
			[ "$_native_devices_count" -eq 0 ] && [ "$_native_devices_observations" -eq 12 ] || return 129
		fi
		if [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
			_cfmgr_isolation_tmp_remove || return 129
		fi
		for _execution_view in usr lib sbin bin; do
			_cfmgr_isolation_native_remove "$_execution_view" || return 129
		done
		[ "$_execution_native_count" -eq 0 ] || return 129
		_execution_root_ledger=$_execution_base_ledger
		_cfmgr_isolation_read "$_isolation_guard/base-root" || return 129
		[ "$_isolation_text" = "$_execution_base_ledger" ] || return 129
	fi
	_cfmgr_isolation_query "$_isolation_tree" 0 && _cfmgr_isolation_private || return 129
	[ "$_isolation_ledger" = "$_execution_root_ledger" ] || return 129
	_cfmgr_isolation_read "$_isolation_guard/intent-root" || return 129
	[ "$_isolation_text" = "root$_io_lf" ] || return 129
	_cfmgr_isolation_read "$_isolation_guard/mounted-root" || return 129
	[ "$_isolation_text" = "$_execution_root_ledger" ] || return 129
	_cfmgr_isolation_unmount umount-root "$_isolation_tree" || return 129
	_cfmgr_isolation_query "$_isolation_tree" 0 && _cfmgr_isolation_private || return 129
	[ "$_isolation_body" = "$_execution_prior_body" ] || return 129
	_cfmgr_isolation_query "$_isolation_root" 0 && _cfmgr_isolation_private || return 129
	[ "$_isolation_body" = "$_execution_ram_body" ] || return 129
	_execution_result="callback$_io_tab$_execution_callback_status$_io_lf"
	_execution_result="${_execution_result}end$_io_tab${#_execution_result}$_io_lf"
	_cfmgr_isolation_write "$_isolation_guard/result" "$_execution_result" || return 129
	"$_isolation_mkdir" -m 700 "$_isolation_guard/complete" || return 129
	_cfmgr_isolation_root_empty "$_isolation_guard/complete" || return 129
	_execution_io_complete=1
	return 0
}

# Source and child superblock must both remain readonly executable observations.
_cfmgr_isolation_native_source_options() (
	[ "$#" -eq 2 ] || return 1
	for _native_options in "$1" "$2"; do
		_native_ro=0
		_native_start=1
		while :; do
			case $_native_options in '') break ;; esac
			case $_native_start in 1)
				case $_native_options in
				726f | 726f2c*) _native_ro=1 ;;
				7277 | 72772c* | 6e6f65786563 | 6e6f657865632c*) return 1 ;;
				esac
				;;
			esac
			case $_native_options in 2c*) _native_start=1 ;; *) _native_start=0 ;; esac
			_native_options=${_native_options#??}
		done
		[ "$_native_ro" -eq 1 ] || return 1
	done
)

_cfmgr_isolation_native_view_options() (
	[ "$#" -eq 2 ] || return 1
	_cfmgr_isolation_native_source_options "$2" "$2" || return 1
	_cfmgr_isolation_readonly_options "$1"
)

_cfmgr_isolation_native_name() {
	_execution_view=$1
	case $_execution_view in
	bin) _execution_view_hex=62696e ;;
	sbin) _execution_view_hex=7362696e ;;
	lib) _execution_view_hex=6c6962 ;;
	usr) _execution_view_hex=757372 ;;
	*) return 1 ;;
	esac
	_execution_view_path=$_isolation_tree/$_execution_view
	_execution_view_source_path=${_execution_native_source_root%/}/$_execution_view
}

# Called only after a checked canonical source query. All four observations
# share one covering mount/body; only their filesystem-target suffix differs.
_cfmgr_isolation_native_source_check() {
	"$_isolation_test" -d "$_execution_view_source_path" &&
		"$_isolation_test" ! -L "$_execution_view_source_path" || return 1
	_cfmgr_isolation_private || return 1
	case $_execution_kind:$_isolation_fs in
	production:ubifs | production:squashfs | fixture:ubifs | fixture:squashfs | fixture:tmpfs) ;;
	*) return 1 ;;
	esac
	_cfmgr_isolation_native_source_options "$_isolation_options" "$_isolation_super" || return 1
	case $_isolation_fs_target in *"2f$_execution_view_hex") ;; *) return 1 ;; esac
	_execution_observed_source_base=${_isolation_fs_target%"2f$_execution_view_hex"}
	[ -n "$_execution_observed_source_base" ] || _execution_observed_source_base=2f
	_cfmgr_io_hex_path "$_execution_observed_source_base" || return 1
	_execution_observed_source_common=${_isolation_body%"$_io_tab"*}
	if [ -z "$_execution_native_source_common" ]; then
		_execution_native_source_common=$_execution_observed_source_common
		_execution_native_source_base=$_execution_observed_source_base
	else
		[ "$_execution_observed_source_common" = "$_execution_native_source_common" ] &&
			[ "$_execution_observed_source_base" = "$_execution_native_source_base" ] || return 1
	fi
}

_cfmgr_isolation_native_fallback_check() {
	_cfmgr_isolation_private || return 1
	_execution_expected_fallback="${_execution_base_body%"$_io_tab"*}$_io_tab${_execution_source_root}2f$_execution_view_hex"
	[ "$_isolation_body" = "$_execution_expected_fallback" ] &&
		_cfmgr_isolation_root_empty "$_execution_view_path"
}

_cfmgr_isolation_native_view_check() {
	_cfmgr_isolation_private || return 1
	_execution_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- ${_execution_view_source_ledger%%"$_io_lf"*}
	IFS=$_execution_saved_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] || return 1
	[ "$_isolation_parent" = "$_execution_mount_id" ] && [ "$_isolation_id" != "$_execution_mount_id" ] &&
		[ "$_isolation_id" != "$_isolation_ram_id" ] && [ "$_isolation_id" != "$2" ] || return 1
	[ "$_isolation_device" = "$4" ] && [ "$_isolation_fs" = "$7" ] && [ "$_isolation_super" = "${10}" ] || return 1
	[ "$_isolation_mount_root" = "${11}" ] && [ "$_isolation_fs_target" = "${11}" ] || return 1
	_execution_expected_view_source=$8
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_isolation_body
	IFS=$_execution_saved_ifs
	[ "$8" = "$_execution_expected_view_source" ] || return 1
	"$_isolation_test" -d "$_execution_view_path" && "$_isolation_test" ! -L "$_execution_view_path" || return 1
	_execution_view_identity="$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab${11}"
}

# Fixed-name memory copies prevent changed metadata from becoming new authority.
# Each copy is exactly source/fallback/mounted, three checked LF records each.
_cfmgr_isolation_native_save() {
	_execution_record=$_execution_view_source_ledger$_execution_view_fallback_ledger$_execution_view_mounted_ledger
	case $_execution_view in
	bin) _execution_bin_record=$_execution_record ;;
	sbin) _execution_sbin_record=$_execution_record ;;
	lib) _execution_lib_record=$_execution_record ;;
	usr) _execution_usr_record=$_execution_record ;;
	*) return 1 ;;
	esac
}

_cfmgr_isolation_native_load() {
	case $_execution_view in
	bin) _execution_record=$_execution_bin_record ;;
	sbin) _execution_record=$_execution_sbin_record ;;
	lib) _execution_record=$_execution_lib_record ;;
	usr) _execution_record=$_execution_usr_record ;;
	*) return 1 ;;
	esac
	for _execution_piece in source fallback mounted; do
		_execution_piece_text=
		for _execution_line_index in 1 2 3; do
			_execution_piece_line=${_execution_record%%"$_io_lf"*}
			[ "$_execution_record" != "$_execution_piece_line" ] || return 1
			_execution_piece_text=$_execution_piece_text$_execution_piece_line$_io_lf
			_execution_record=${_execution_record#*"$_io_lf"}
		done
		_cfmgr_isolation_read "$_isolation_guard/$_execution_piece-$_execution_view" || return 1
		[ "$_isolation_text" = "$_execution_piece_text" ] || return 1
		case $_execution_piece in
		source) _execution_view_source_ledger=$_execution_piece_text ;;
		fallback) _execution_view_fallback_ledger=$_execution_piece_text ;;
		mounted) _execution_view_mounted_ledger=$_execution_piece_text ;;
		esac
	done
	[ -z "$_execution_record" ] || return 1
	_cfmgr_isolation_read "$_isolation_guard/intent-$_execution_view" || return 1
	[ "$_isolation_text" = "$_execution_view$_io_lf" ]
}

_cfmgr_isolation_native_build() {
	_cfmgr_isolation_native_name "$1" || return 129
	_cfmgr_isolation_query "$_execution_view_source_path" 2 && _cfmgr_isolation_native_source_check || return 129
	_execution_view_source_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/source-$_execution_view" "$_execution_view_source_ledger" || return 129
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_fallback_check || return 129
	_execution_view_fallback_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/fallback-$_execution_view" "$_execution_view_fallback_ledger" || return 129
	_cfmgr_isolation_write "$_isolation_guard/intent-$_execution_view" "$_execution_view$_io_lf" || return 129
	_cfmgr_isolation_query "$_execution_view_source_path" 2 && _cfmgr_isolation_native_source_check || return 129
	[ "$_isolation_ledger" = "$_execution_view_source_ledger" ] || return 129
	_cfmgr_isolation_native_call "bind-$_execution_view" "$_isolation_mount" -n -i -o bind \
		"$_execution_view_source_path" "$_execution_view_path" || return 129
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_view_check &&
		_cfmgr_isolation_native_source_options "$_isolation_options" "$_isolation_super" || return 129
	case " $_execution_native_ids " in *" $_isolation_id "*) return 129 ;; esac
	_execution_view_first_identity=$_execution_view_identity
	_execution_view_first_body=$_isolation_body
	_cfmgr_isolation_native_call "private-$_execution_view" "$_isolation_mount" -n -i -o make-private "$_execution_view_path" || return 129
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_view_check || return 129
	[ "$_execution_view_identity" = "$_execution_view_first_identity" ] && [ "$_isolation_body" = "$_execution_view_first_body" ] || return 129
	_cfmgr_isolation_native_call "remount-$_execution_view" "$_isolation_mount" -n -i -o remount,bind,ro,nosuid,nodev,exec \
		"$_execution_view_source_path" "$_execution_view_path" || return 129
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_view_check &&
		_cfmgr_isolation_native_view_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_execution_view_identity" = "$_execution_view_first_identity" ] || return 129
	_execution_view_mounted_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/mounted-$_execution_view" "$_execution_view_mounted_ledger" || return 129
	_cfmgr_isolation_native_save || return 129
	_execution_native_ids="$_execution_native_ids $_isolation_id"
	_execution_native_count=$((_execution_native_count + 1))
}

# Whole-root count is necessary but never sufficient: every fixed leaf is
# freshly queried and compared with its complete immutable ledger and intent.
_cfmgr_isolation_native_layout_check() {
	[ "$_execution_native_count" -eq 4 ] || return 1
	_execution_expected_children=4
	case $_execution_layout in
	native-tmp) _execution_expected_children=5 ;;
	native-opt) _execution_expected_children=6 ;;
	native-devices) _execution_expected_children=8 ;;
	esac
	_cfmgr_isolation_query "$_isolation_tree" 0 || return 1
	[ "$_isolation_body" = "$_execution_base_body" ] &&
		[ "$_isolation_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab$_execution_expected_children" ] || return 1
	_execution_checked_root_ledger=$_isolation_ledger
	for _execution_checked_view in bin sbin lib usr; do
		_cfmgr_isolation_native_name "$_execution_checked_view" && _cfmgr_isolation_native_load || return 1
		_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_view_check &&
			_cfmgr_isolation_native_view_options "$_isolation_options" "$_isolation_super" || return 1
		[ "$_isolation_ledger" = "$_execution_view_mounted_ledger" ] || return 1
	done
	if [ "$_execution_layout" = native-tmp ] || [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		[ "$_execution_tmp_ready" -eq 1 ] && _cfmgr_isolation_tmp_saved || return 1
		_cfmgr_isolation_query "$_isolation_tree/tmp" 0 && _cfmgr_isolation_tmp_check || return 1
		[ "$_isolation_ledger" = "$_execution_tmp_mounted_ledger" ] || return 1
		[ -d "$_execution_tmp_home" ] && [ ! -L "$_execution_tmp_home" ] || return 1
	fi
	if [ "$_execution_layout" = native-opt ] || [ "$_execution_layout" = native-devices ]; then
		_cfmgr_entware_root_layout_check || return 1
	fi
	if [ "$_execution_layout" = native-devices ]; then
		_cfmgr_native_devices_layout_check || return 1
	fi
}

_cfmgr_isolation_native_remove() {
	_cfmgr_isolation_native_name "$1" && _cfmgr_isolation_native_load || return 129
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_view_check &&
		_cfmgr_isolation_native_view_options "$_isolation_options" "$_isolation_super" || return 129
	[ "$_isolation_ledger" = "$_execution_view_mounted_ledger" ] || return 129
	_cfmgr_isolation_unmount "umount-$_execution_view" "$_execution_view_path" || return 129
	_cfmgr_isolation_query "$_execution_view_path" 0 && _cfmgr_isolation_native_fallback_check || return 129
	[ "$_isolation_ledger" = "$_execution_view_fallback_ledger" ] || return 129
	_execution_native_count=$((_execution_native_count - 1))
}

_cfmgr_isolation_tmp_limits() (
	[ "$#" -eq 2 ] || return 1
	for _tmp_limit in "$1" "$2"; do
		case $_tmp_limit in '' | 0* | *[!0123456789]*) return 1 ;; esac
	done
	[ "${#1}" -le 5 ] && [ "${#2}" -le 4 ] || return 1
	[ "$1" -ge 64 ] && [ "$1" -le 65536 ] && [ "$(($1 % 64))" -eq 0 ] &&
		[ "$2" -ge 8 ] && [ "$2" -le 8192 ]
)

_cfmgr_isolation_tmp_decimal_hex() {
	_execution_tmp_number_hex=
	_execution_tmp_number=$1
	while :; do
		case $_execution_tmp_number in '') return 0 ;; esac
		_execution_tmp_tail=${_execution_tmp_number#?}
		_execution_tmp_digit=${_execution_tmp_number%"$_execution_tmp_tail"}
		case $_execution_tmp_digit in [0123456789]) ;; *) return 1 ;; esac
		_execution_tmp_number_hex=${_execution_tmp_number_hex}3$_execution_tmp_digit
		_execution_tmp_number=$_execution_tmp_tail
	done
}

# Effective superblock keys must occur once, with the exact approved values.
_cfmgr_isolation_tmp_options() (
	[ "$#" -eq 2 ] || return 1
	_cfmgr_io_hex "$1" && _cfmgr_io_hex "$2" || return 1
	_cfmgr_isolation_tmp_limits "$_execution_tmp_kib" "$_execution_tmp_inodes" || return 1
	_cfmgr_isolation_options "$1" "$2" ram || return 1
	_cfmgr_isolation_tmp_decimal_hex "$_execution_tmp_kib" || return 1
	_tmp_size=73697a653d${_execution_tmp_number_hex}6b
	_cfmgr_isolation_tmp_decimal_hex "$_execution_tmp_inodes" || return 1
	_tmp_inodes=6e725f696e6f6465733d$_execution_tmp_number_hex
	_tmp_size_seen=0 _tmp_inode_seen=0 _tmp_mode_seen=0
	_tmp_nosuid=0 _tmp_nodev=0 _tmp_phase=mount
	for _tmp_list in "$1" "$2"; do
		_tmp_rest=${_tmp_list}2c _tmp_token=
		while :; do
			case $_tmp_rest in '') break ;; esac
			_tmp_tail=${_tmp_rest#??}
			_tmp_pair=${_tmp_rest%"$_tmp_tail"}
			_tmp_rest=$_tmp_tail
			case $_tmp_pair in
			2c) ;;
			*)
				_tmp_token=$_tmp_token$_tmp_pair
				continue
				;;
			esac
			case $_tmp_token in
			'' | 73756964 | 646576) return 1 ;;
			6e6f73756964) [ "$_tmp_phase" != mount ] || _tmp_nosuid=1 ;;
			6e6f646576) [ "$_tmp_phase" != mount ] || _tmp_nodev=1 ;;
			73697a653d*)
				[ "$_tmp_phase" = super ] && [ "$_tmp_size_seen" -eq 0 ] && [ "$_tmp_token" = "$_tmp_size" ] || return 1
				_tmp_size_seen=1
				;;
			6e725f696e6f6465733d*)
				[ "$_tmp_phase" = super ] && [ "$_tmp_inode_seen" -eq 0 ] && [ "$_tmp_token" = "$_tmp_inodes" ] || return 1
				_tmp_inode_seen=1
				;;
			6d6f64653d*)
				[ "$_tmp_phase" = super ] && [ "$_tmp_mode_seen" -eq 0 ] && [ "$_tmp_token" = 6d6f64653d373030 ] || return 1
				_tmp_mode_seen=1
				;;
			esac
			_tmp_token=
		done
		_tmp_phase=super
	done
	[ "$_tmp_nosuid:$_tmp_nodev:$_tmp_size_seen:$_tmp_inode_seen:$_tmp_mode_seen" = 1:1:1:1:1 ]
)

_cfmgr_isolation_tmp_check() {
	_cfmgr_isolation_private && _cfmgr_isolation_tmp_options "$_isolation_options" "$_isolation_super" || return 1
	[ "$_isolation_fs" = tmpfs ] && [ "$_isolation_mount_root" = 2f ] && [ "$_isolation_fs_target" = 2f ] || return 1
	[ "$_isolation_parent" = "$_execution_mount_id" ] && [ "$_isolation_id" != "$_execution_mount_id" ] &&
		[ "$_isolation_id" != "$_isolation_ram_id" ] && [ "$_isolation_device" != "$_execution_device" ] || return 1
	case " $_execution_native_ids " in *" $_isolation_id "*) return 1 ;; esac
	_execution_tmp_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_execution_base_body
	IFS=$_execution_tmp_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] || return 1
	[ "$_isolation_point" = "${6}2f746d70" ] || return 1
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_execution_native_source_common
	IFS=$_execution_tmp_ifs
	[ "$#" -eq 10 ] && [ "$1" = mount ] || return 1
	[ "$_isolation_id" != "$2" ] && [ "$_isolation_device" != "$4" ] || return 1
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_isolation_body
	IFS=$_execution_tmp_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] && [ "$8" = 63666d67722d746d70 ]
}

_cfmgr_isolation_tmp_fallback_check() {
	_execution_view_path=$_isolation_tree/tmp _execution_view_hex=746d70
	_cfmgr_isolation_native_fallback_check
}

_cfmgr_isolation_tmp_saved() {
	_cfmgr_isolation_read "$_isolation_guard/intent-tmp" || return 1
	[ "$_isolation_text" = "tmp$_io_lf" ] || return 1
	_cfmgr_isolation_read "$_isolation_guard/fallback-tmp" || return 1
	[ "$_isolation_text" = "$_execution_tmp_fallback_ledger" ] || return 1
	_cfmgr_isolation_read "$_isolation_guard/mounted-tmp" || return 1
	[ "$_isolation_text" = "$_execution_tmp_mounted_ledger" ]
}

_cfmgr_isolation_tmp_home_create() {
	[ "$_execution_tmp_ready" -eq 1 ] && _cfmgr_isolation_root_empty "$_isolation_tree/tmp" || return 129
	_execution_tmp_home=$_isolation_tree/tmp/cfmgr-home
	_cfmgr_isolation_native_call home-tmp "$_isolation_mkdir" -m 700 "$_execution_tmp_home" || return 129
	_cfmgr_isolation_root_empty "$_execution_tmp_home" || return 129
}

_cfmgr_isolation_tmp_build() {
	_cfmgr_isolation_query "$_isolation_tree/tmp" 0 && _cfmgr_isolation_tmp_fallback_check || return 129
	_execution_tmp_fallback_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/fallback-tmp" "$_execution_tmp_fallback_ledger" || return 129
	_cfmgr_isolation_write "$_isolation_guard/intent-tmp" "tmp$_io_lf" || return 129
	_cfmgr_isolation_native_call mount-tmp "$_isolation_mount" -n -i -t tmpfs \
		-o "rw,nosuid,nodev,exec,mode=700,size=${_execution_tmp_kib}k,nr_inodes=$_execution_tmp_inodes" \
		cfmgr-tmp "$_isolation_tree/tmp" || return 129
	_cfmgr_isolation_query "$_isolation_tree/tmp" 0 && _cfmgr_isolation_tmp_check || return 129
	_execution_tmp_first_ledger=$_isolation_ledger
	_cfmgr_isolation_native_call private-tmp "$_isolation_mount" -n -i -o make-private "$_isolation_tree/tmp" || return 129
	_cfmgr_isolation_query "$_isolation_tree/tmp" 0 && _cfmgr_isolation_tmp_check || return 129
	[ "$_isolation_ledger" = "$_execution_tmp_first_ledger" ] || return 129
	_execution_tmp_mounted_ledger=$_isolation_ledger
	_cfmgr_isolation_write "$_isolation_guard/mounted-tmp" "$_execution_tmp_mounted_ledger" || return 129
	_execution_tmp_ready=1
	_cfmgr_isolation_tmp_home_create
}

_cfmgr_isolation_tmp_remove() {
	[ "$_execution_tmp_ready" -eq 1 ] && _cfmgr_isolation_tmp_saved || return 129
	_cfmgr_isolation_query "$_isolation_tree/tmp" 0 && _cfmgr_isolation_tmp_check || return 129
	[ "$_isolation_ledger" = "$_execution_tmp_mounted_ledger" ] || return 129
	_cfmgr_isolation_unmount umount-tmp "$_isolation_tree/tmp" || return 129
	_cfmgr_isolation_query "$_isolation_tree/tmp" 0 && _cfmgr_isolation_tmp_fallback_check || return 129
	[ "$_isolation_ledger" = "$_execution_tmp_fallback_ledger" ] || return 129
	_execution_tmp_ready=0
}

# Native/native-data success uses 56 queries: base construction 6; four view
# phases 6 each; three whole-layout checks 5 each (prelease, withinlease,
# postcallback); reverse removal 2 each; final base-root teardown 3.
# All metadata slots remain unique.
# Native-tmp uses 64: add build 3, one leaf in each layout check 3, teardown 2.

# Native Opt adds initial source 1, build 5, three whole-layout additions 6,
# and teardown 2 to native-tmp 64: exactly 78 distinct mount queries.

# Fixed devices add initial source 2, build 10, whole-layout additions 12 and
# teardown 4 to retained Opt 78: exactly 106 mount queries, metadata separate.
