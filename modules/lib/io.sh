#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Private RAM transactions only; no storage authorization or hard deadline.
# Sourcing only defines functions. Public entries isolate caller state.
# Caller must disable tracing BEFORE passing arguments; isolated entries disable
# tracing internally, but cannot conceal an already-traced outer invocation.
# Trusted RAM parent/native firmware/code and bounded internal callbacks are
# preconditions. Production never selects tools/input/code through environment.
# Signals delivered to the workspace OWNER are handled; signalling only its
# external caller does not automatically signal this subshell. Callers must
# supervise/route signals and allow owner cleanup (SIGKILL is not recoverable).

cfmgr_io_with_workspace() {
	[ "$#" -ge 2 ] || return 2
	_cfmgr_io_owner '' "$1" workspace "$@"
}

# Controlled callback may stage one bounded ASCII report, published only after
# status0 and successful owned cleanup. Workspace callbacks remain status-only.
cfmgr_io_with_report() {
	[ "$#" -ge 2 ] || return 2
	_cfmgr_io_owner '' "$1" report "$@"
}

cfmgr_io_stage_report() {
	[ "$#" -eq 1 ] && [ "${_io_active-}" = 1 ] && [ "${_io_report-}" = 1 ] || return 2
	[ "$_io_publish" -eq 0 ] && [ -n "$1" ] && [ "${#1}" -le 65536 ] || return 2
	case $1 in *[!\ -~"$_io_tab$_io_lf"]*) return 2 ;; esac
	_io_result=$1
	_io_publish=1
}

cfmgr_io_mount_snapshot() {
	[ "$#" -eq 3 ] || return 2
	_cfmgr_io_owner '' "$1" mount "$2" "$3" /proc/self/mountinfo
}

cfmgr_io_topology_snapshot() {
	[ "$#" -eq 3 ] || return 2
	_cfmgr_io_owner '' "$1" topology "$2" "$3" /proc/self/mountinfo
}

# Explicit trusted test API, never exposed through the production CLI.
# ROOT TOOLS workspace CALLBACK [ARGS] | ROOT TOOLS mount TARGET PARSER INPUT
# ROOT TOOLS topology TARGET PARSER INPUT
cfmgr_io_test() {
	[ "$#" -ge 4 ] || return 2
	_cfmgr_io_owner "$2" "$1" "$3" "$@"
}

_cfmgr_io_find() (
	case $1 in awk | cat | wc | printf | test | '[' | mkdir | rm | readlink | ls | hexdump) ;; *) return 2 ;; esac
	if [ -n "$_io_tools" ]; then
		[ -x "$_io_tools/$1" ] && [ ! -d "$_io_tools/$1" ] || return 1
		printf '%s\n' "$_io_tools/$1"
		return
	fi
	for _find_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_find_dir/$1" ] && [ ! -d "$_find_dir/$1" ]; then
			printf '%s\n' "$_find_dir/$1"
			return
		fi
	done
	return 1
)

_cfmgr_io_limit() (
	[ "$#" -eq 1 ] || return 1
	case $1 in '' | *[!0123456789]* | 0[0123456789]*) return 1 ;; esac
	[ "${#1}" -le 5 ] && [ "$1" -le 65536 ]
)

_cfmgr_io_decimal() (
	[ "$#" -eq 2 ] || return 1
	case $1 in '' | *[!0123456789]* | 0[0123456789]*) return 1 ;; esac
	[ "${#1}" -le 20 ] || return 1
	[ "$2" = nonnegative ] || [ "$1" != 0 ]
)

_cfmgr_io_hex() (
	[ -n "$1" ] || return 1
	case $1 in *[!0123456789abcdef]*) return 1 ;; esac
	[ "$((${#1} % 2))" -eq 0 ] || return 1
	_hex=$1
	while :; do
		case $_hex in '') return 0 ;; 00*) return 1 ;; *) _hex=${_hex#??} ;; esac
	done
)

_cfmgr_io_hex_path() (
	_cfmgr_io_hex "$1" || return 1
	case $1 in 2f) return 0 ;; 2f*) ;; *) return 1 ;; esac
	_path=${1#??}
	_component=
	while :; do
		case $_path in
		'')
			[ -n "$_component" ] && [ "$_component" != 2e ] && [ "$_component" != 2e2e ]
			return
			;;
		2f*)
			[ -n "$_component" ] && [ "$_component" != 2e ] && [ "$_component" != 2e2e ] || return 1
			_component=
			;;
		*)
			_tail=${_path#??}
			_component=$_component${_path%"$_tail"}
			;;
		esac
		_path=${_path#??}
	done
)

_cfmgr_io_slots() (
	set +f
	_slots=0
	for _slot_file in "$_io_stage"/*.status; do
		if [ -e "$_slot_file" ] || [ -L "$_slot_file" ]; then
			_slots=$((_slots + 1))
			[ "$_slots" -le 16 ] || return 1
		fi
	done
)

_cfmgr_io_size() (
	[ -f "$1" ] && [ ! -L "$1" ] || return 1
	_count=$("$_io_wc" -c <"$1") || return 1
	# wc may pad its one canonical count; noglob and fixed IFS are required.
	# shellcheck disable=SC2086
	set -- $_count
	[ "$#" -eq 1 ] && _cfmgr_io_limit "$1" || return 1
	printf '%s\n' "$1"
) 2>/dev/null

# Valid only inside the controlled workspace callback. Slots 0..15 are consumed
# even on failure and cannot be reused. 16 captures => at most48 capture files.
# RETURN0 MEANS CAPTURE COMPLETED, NOT PRODUCER SUCCESS: caller MUST read/check
# SLOT.status (capture TAB producer_status TAB stdout_bytes TAB stderr_bytes LF)
# before using SLOT.out/.err. Failed captures leave no usable status ledger.
cfmgr_io_capture() (
	set +x
	set +e
	set +u
	umask 077
	set -f
	IFS=' 	'
	IFS="${IFS}
"
	[ "$#" -ge 4 ] && [ "${_io_active-}" = 1 ] || return 2
	case $1 in [0123456789] | 1[012345]) ;; *) return 2 ;; esac
	_cap_slot=$1
	_cap_out=$_io_stage/$_cap_slot.out
	_cap_err=$_io_stage/$_cap_slot.err
	_cap_status=$_io_stage/$_cap_slot.status
	# Reserve status first: every valid-slot attempt consumes its slot.
	_cfmgr_io_slots || return 1
	set -C
	# A failing redirection on the special builtin ':' can exit dash/ash before
	# its || handler. Contain that exit so every collision returns IO status1.
	(: >"$_cap_status") || return 1
	_cfmgr_io_slots || return 1
	[ ! -e "$_cap_out" ] && [ ! -L "$_cap_out" ] && [ ! -e "$_cap_err" ] && [ ! -L "$_cap_err" ] || return 1
	_cfmgr_io_limit "$2" && _cfmgr_io_limit "$3" || return 2
	_cap_out_limit=$2
	_cap_err_limit=$3
	case $4 in cat | awk | wc | printf | test | '[' | readlink | ls | hexdump) ;; *) return 2 ;; esac
	_cap_command=$(_cfmgr_io_find "$4") || return 1
	shift 4
	_cap_ceiling=$_cap_out_limit
	[ "$_cap_err_limit" -le "$_cap_ceiling" ] || _cap_ceiling=$_cap_err_limit
	# Use512-byte units conservatively:512/1024-byte implementations both permit
	# legitimate limit-sized output. Disk ceiling per stream is at most
	# ceil((max_limit+1)/512)*1024 bytes (<=132096); final byte caps are exact.
	# The extra byte makes overflow observable even at an exact512-byte boundary,
	# instead of accepting a short native write clipped exactly to the byte cap.
	_cap_blocks=$(((_cap_ceiling + 512) / 512))
	ulimit -f "$_cap_blocks" || return 1
	"$_cap_command" "$@" >"$_cap_out" 2>"$_cap_err"
	_cap_producer=$?
	# IO creation failures must not be mistaken for a valid producer failure.
	[ -f "$_cap_out" ] && [ ! -L "$_cap_out" ] && [ -f "$_cap_err" ] && [ ! -L "$_cap_err" ] || return 1
	_cap_out_bytes=$(_cfmgr_io_size "$_cap_out") || return 1
	_cap_err_bytes=$(_cfmgr_io_size "$_cap_err") || return 1
	[ "$_cap_out_bytes" -le "$_cap_out_limit" ] && [ "$_cap_err_bytes" -le "$_cap_err_limit" ] || return 1
	"$_io_printf" 'capture\t%s\t%s\t%s\n' "$_cap_producer" "$_cap_out_bytes" "$_cap_err_bytes" >>"$_cap_status" || return 1
	_cap_expected="capture$_io_tab$_cap_producer$_io_tab$_cap_out_bytes$_io_tab$_cap_err_bytes"
	_cap_read=
	_cap_extra=
	{ IFS= read -r _cap_read && ! IFS= read -r _cap_extra && [ -z "$_cap_extra" ]; } <"$_cap_status" || return 1
	[ "$_cap_read" = "$_cap_expected" ] || return 1
	_cap_status_bytes=$(_cfmgr_io_size "$_cap_status") || return 1
	[ "$_cap_status_bytes" -eq "$((${#_cap_expected} + 1))" ]
) 2>/dev/null

_cfmgr_io_capture_status() {
	_status_line=
	IFS= read -r _status_line <"$_io_stage/$1.status" || return 1
	# Capture already verified the exact regular-file metadata framing/byte count.
	_status_rest=${_status_line#capture"$_io_tab"}
	_io_producer=${_status_rest%%"$_io_tab"*}
	[ "$_status_rest" != "$_status_line" ] || return 1
	_status_rest=${_status_rest#*"$_io_tab"}
	_io_out_bytes=${_status_rest%%"$_io_tab"*}
	_io_err_bytes=${_status_rest#*"$_io_tab"}
}

_cfmgr_io_mount_action() {
	[ "$#" -eq 4 ] || return 2
	_cfmgr_io_mount_capture "$2" "$3" "$4" 0 1 || return "$?"
	cfmgr_io_stage_report "$_mount_ledger"
}

_cfmgr_io_topology_action() {
	[ "$#" -eq 4 ] || return 2
	_cfmgr_io_mount_capture "$2" "$3" "$4" 0 1 topology || return "$?"
	cfmgr_io_stage_report "$_mount_ledger"
}

_cfmgr_io_topology_fields() {
	_topology_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_topology
	IFS=$_topology_saved_ifs
	[ "$#" -eq 7 ] && [ "$1" = topology ] || return 1
	_topology_rebuilt="$1$_io_tab$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7"
	[ "$_topology_rebuilt" = "$_mount_topology" ] || return 1
	for _topology_id in "$2" "$3" "$4"; do
		[ "$_topology_id" = - ] || _cfmgr_io_decimal "$_topology_id" positive || return 1
	done
	case $5 in 0 | 1) ;; *) return 1 ;; esac
	# Validate bounded canonical decimal before numeric comparisons. IDs above
	# remain lexical; only the two small counts enter shell integer operations.
	_cfmgr_io_limit "$6" && _cfmgr_io_limit "$7" || return 1
	[ "$6" -le 4096 ] && [ "$7" -le 1023 ]
}

# Internal checked mount capture. Explicit distinct slots allow other owned
# observations to share the16-slot budget. Optional sixth argument is literal
# select/topology; five-argument callers retain selection behavior. Outputs:
# _mount_body, _mount_topology (empty in select), and complete _mount_ledger.
_cfmgr_io_mount_capture() {
	_mount_mode=select
	_mount_topology=
	_mount_body=
	_mount_ledger=
	[ "$#" -eq 5 ] || [ "$#" -eq 6 ] || return 2
	if [ "$#" -eq 6 ]; then
		case $6 in select | topology) _mount_mode=$6 ;; *) return 2 ;; esac
	fi
	_mount_target=$1
	_mount_parser=$2
	_mount_input=$3
	_mount_raw_slot=$4
	_mount_result_slot=$5
	[ "$_mount_raw_slot" != "$_mount_result_slot" ] || return 2
	case $_mount_parser in /*) ;; *) return 2 ;; esac
	[ -f "$_mount_parser" ] && [ ! -L "$_mount_parser" ] && [ -r "$_mount_parser" ] || return 2
	[ -f "$_mount_input" ] && [ ! -L "$_mount_input" ] || return 1
	cfmgr_io_capture "$_mount_raw_slot" 65536 4096 cat "$_mount_input" || return 1
	_cfmgr_io_capture_status "$_mount_raw_slot" || return 1
	[ "$_io_producer" -eq 0 ] && [ "$_io_err_bytes" -eq 0 ] || return 1
	_mount_size=$(_cfmgr_io_size "$_io_stage/$_mount_raw_slot.out") || return 1
	[ "$_mount_size" -gt 0 ] || return 1
	CFMGR_MOUNT_TARGET=$_mount_target
	export CFMGR_MOUNT_TARGET
	if [ "$_mount_mode" = topology ]; then
		cfmgr_io_capture "$_mount_result_slot" 65536 4096 awk -v "cfmgr_mountinfo_size=$_mount_size" -v cfmgr_mountinfo_mode=topology -f "$_mount_parser" <"$_io_stage/$_mount_raw_slot.out" || return 1
	else
		cfmgr_io_capture "$_mount_result_slot" 65536 4096 awk -v "cfmgr_mountinfo_size=$_mount_size" -f "$_mount_parser" <"$_io_stage/$_mount_raw_slot.out" || return 1
	fi
	_cfmgr_io_capture_status "$_mount_result_slot" || return 1
	case $_io_producer in 0) ;; 1 | 2 | 3) return "$_io_producer" ;; *) return 1 ;; esac
	[ "$_io_err_bytes" -eq 0 ] || return 1
	_mount_bytes=$(_cfmgr_io_size "$_io_stage/$_mount_result_slot.out") || return 1
	_mount_body=
	_mount_footer=
	_mount_extra=
	if [ "$_mount_mode" = topology ]; then
		{ IFS= read -r _mount_body && IFS= read -r _mount_topology && IFS= read -r _mount_footer && ! IFS= read -r _mount_extra && [ -z "$_mount_extra" ]; } <"$_io_stage/$_mount_result_slot.out" || return 1
	else
		{ IFS= read -r _mount_body && IFS= read -r _mount_footer && ! IFS= read -r _mount_extra && [ -z "$_mount_extra" ]; } <"$_io_stage/$_mount_result_slot.out" || return 1
	fi
	_mount_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$_mount_saved_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] || return 1
	_mount_rebuilt="$1$_io_tab$2$_io_tab$3$_io_tab$4$_io_tab$5$_io_tab$6$_io_tab$7$_io_tab$8$_io_tab$9$_io_tab${10}$_io_tab${11}"
	[ "$_mount_rebuilt" = "$_mount_body" ] || return 1
	_cfmgr_io_decimal "$2" positive && _cfmgr_io_decimal "$3" nonnegative || return 1
	case $4 in *:*) ;; *) return 1 ;; esac
	_cfmgr_io_decimal "${4%%:*}" nonnegative && _cfmgr_io_decimal "${4#*:}" nonnegative || return 1
	_cfmgr_io_hex_path "$5" && _cfmgr_io_hex_path "$6" && _cfmgr_io_hex_path "${11}" || return 1
	case $7 in
	'' | [!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.+-]*) return 1 ;;
	esac
	for _mount_hex in "$8" "$9" "${10}"; do _cfmgr_io_hex "$_mount_hex" || return 1; done
	_mount_body_bytes=$((${#_mount_body} + 1))
	_mount_ledger=$_mount_body$_io_lf
	if [ "$_mount_mode" = topology ]; then
		_cfmgr_io_topology_fields || return 1
		_mount_body_bytes=$((_mount_body_bytes + ${#_mount_topology} + 1))
		_mount_ledger=$_mount_ledger$_mount_topology$_io_lf
	fi
	[ "$_mount_footer" = "end$_io_tab$_mount_body_bytes" ] || return 1
	[ "$_mount_bytes" -eq "$((_mount_body_bytes + ${#_mount_footer} + 1))" ] || return 1
	_mount_ledger=$_mount_ledger$_mount_footer$_io_lf
	[ "${#_mount_ledger}" -le 65536 ]
}

_cfmgr_io_finish() {
	_finish_status=$1
	case $_io_signal in 129 | 130 | 143) _finish_status=$_io_signal ;; esac
	trap - 0
	trap '' HUP INT TERM
	if [ -n "$_io_stage" ]; then
		if ! "$_io_rm" -rf "$_io_stage" >/dev/null 2>&1 || [ -e "$_io_stage" ] || [ -L "$_io_stage" ]; then
			case $_finish_status in 129 | 130 | 143) ;; *) _finish_status=1 ;; esac
		fi
	fi
	if [ "$_finish_status" -eq 0 ] && [ "$_io_publish" -eq 1 ]; then
		# The future consumer must also verify complete framing/status: a partial
		# pipe write cannot be proved complete by a native printf exit code alone.
		"$_io_printf" '%s' "$_io_result" || _finish_status=1
	fi
	exit "$_finish_status"
}

_cfmgr_io_owner() (
	set +x
	set +e
	set +u
	set -f
	IFS=' 	'
	IFS="${IFS}
"
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	export PATH LC_ALL
	unset ENV BASH_ENV CDPATH LD_LIBRARY_PATH LD_PRELOAD
	umask 077
	[ "$#" -ge 4 ] || return 2
	_io_tools=$1
	_io_root=$2
	_io_action=$3
	shift 3
	_io_active=0
	_io_stage=
	_io_publish=0
	_io_report=0
	_io_result=
	_io_signal=0
	_io_tab='	'
	_io_lf='
'
	case $_io_root in /*) ;; *) return 2 ;; esac
	[ -d "$_io_root" ] && [ ! -L "$_io_root" ] || return 2
	# POSIX forwarding: test entry repeats ROOT/TOOLS/ACTION; production workspace
	# repeats ROOT so public wrappers need no caller-visible scratch variables.
	if [ -n "$_io_tools" ]; then
		[ "$#" -ge 3 ] || return 2
		shift 3
	elif [ "$_io_action" = workspace ] || [ "$_io_action" = report ]; then
		[ "$#" -ge 1 ] || return 2
		shift
	fi
	case $_io_action in
	workspace | report)
		[ "$#" -ge 1 ] || return 2
		case $1 in '' | [0123456789]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 2 ;; esac
		_io_callback=$1
		[ "$_io_action" != report ] || _io_report=1
		shift
		;;
	mount)
		[ "$#" -eq 3 ] || return 2
		_io_callback=_cfmgr_io_mount_action
		_io_report=1
		;;
	topology)
		[ "$#" -eq 3 ] || return 2
		_io_callback=_cfmgr_io_topology_action
		_io_report=1
		;;
	*) return 2 ;;
	esac
	_io_mkdir=$(_cfmgr_io_find mkdir) || return 1
	_io_rm=$(_cfmgr_io_find rm) || return 1
	_io_wc=$(_cfmgr_io_find wc) || return 1
	_io_printf=$(_cfmgr_io_find printf) || return 1
	trap '_cfmgr_io_finish "$?"' 0
	trap '_io_signal=129' HUP
	trap '_io_signal=130' INT
	trap '_io_signal=143' TERM
	_io_attempt=0
	while [ "$_io_attempt" -lt 8 ]; do
		_io_candidate=$_io_root/cfmgr-io.$$.$_io_attempt
		if [ ! -e "$_io_candidate" ] && [ ! -L "$_io_candidate" ]; then
			if { "$_io_mkdir" -m 700 "$_io_candidate" >/dev/null 2>&1; } 2>/dev/null; then
				_io_stage=$_io_candidate
				break
			fi
		fi
		[ "$_io_signal" -eq 0 ] || exit "$_io_signal"
		_io_attempt=$((_io_attempt + 1))
	done
	[ "$_io_signal" -eq 0 ] || exit "$_io_signal"
	[ -n "$_io_stage" ] || return 1
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM
	_io_active=1
	# Controlled callback output is never a publication channel.
	"$_io_callback" "$_io_stage" "$@" >/dev/null 2>&1
	_io_callback_status=$?
	if [ "$_io_report" -eq 1 ] && [ "$_io_callback_status" -eq 0 ] && [ "$_io_publish" -ne 1 ]; then
		_io_callback_status=1
	fi
	# The slot grammar and exclusive reservation bound attempts to16 slots.
	_cfmgr_io_slots || _io_callback_status=1
	exit "$_io_callback_status"
) 2>/dev/null
