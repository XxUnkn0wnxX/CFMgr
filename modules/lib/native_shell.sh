#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Fixed synchronous launch only, inside a trusted active native-config owner.
# Caller owns immutable native code/ancestors, frozen aliases, admitted FD8/9,
# no application FD above9 and aggregate process-group/deadline supervision.
# A successful probe admits no arbitrary executable, opkg, NSS or TLS behavior.
# Source-only; trusted io/native_config/isolation helpers are already loaded.
# The exit helper inherits the isolated probe's state.
# shellcheck disable=SC2154,SC2030,SC2031

cfmgr_native_shell_probe() (
	set +x
	set +e
	set +u
	set +C
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
	_native_shell_reserved=0 _native_shell_complete=0
	trap '_cfmgr_native_shell_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	[ "$#" -eq 1 ] || return 2
	[ "${_io_active-}" = 1 ] && [ "${_isolation_mode-}" = root ] &&
		[ "${_execution_layout-}" = native-devices ] && [ "${_execution_config_extended-}" = 1 ] &&
		[ "${_entware_root_ready-}" = 1 ] && [ "${_execution_reserved-}" = 1 ] &&
		[ "${_execution_io_complete-}" = 0 ] && [ "${_isolation_interrupted-}" = 0 ] || return 2
	case ${_execution_kind-} in
	production) [ -z "${_isolation_tools-}" ] || return 2 ;;
	fixture) _cfmgr_isolation_path "${_isolation_tools-}" && [ -d "$_isolation_tools" ] || return 2 ;;
	*) return 2 ;;
	esac
	_native_shell_root=$1
	for _native_shell_path in "$_native_shell_root" "${_execution_guard-}" "${_isolation_guard-}"; do
		_cfmgr_isolation_path "$_native_shell_path" && [ "$_native_shell_path" != / ] || return 2
		_cfmgr_native_config_directory "$_native_shell_path" || return 2
	done
	[ "$_native_shell_root" = "${_isolation_tree-}" ] &&
		[ "$_isolation_guard" = "$_execution_guard/execution" ] &&
		[ "$_native_shell_root" = "$_isolation_guard/root" ] || return 2
	_native_shell_dir=$_isolation_guard/native-shell
	# All executables are fixed native tools or the explicit trusted fixture set.
	_native_shell_env=$(_cfmgr_native_shell_tool env) || return 1
	_native_shell_chroot=$(_cfmgr_native_shell_tool chroot) || return 1
	_native_shell_cat=$(_cfmgr_native_shell_tool cat) || return 1
	_io_wc=$(_cfmgr_native_shell_tool wc) || return 1
	_isolation_printf=$(_cfmgr_native_shell_tool printf) || return 1
	_native_shell_mkdir=$(_cfmgr_native_shell_tool mkdir) || return 1
	_native_shell_test=$(_cfmgr_native_shell_tool test) || return 1
	_io_lf='
'
	_cfmgr_isolation_read "$_isolation_guard/active" &&
		[ "$_isolation_text" = "callback$_io_lf" ] || return 2
	"$_native_shell_test" -d /proc/self/fd/6 &&
		"$_native_shell_test" "$_native_shell_root" -ef /proc/self/fd/6 || return 2
	for _native_shell_path in etc/ld.so.cache etc/ld.so.preload; do
		[ ! -e "$_native_shell_root/$_native_shell_path" ] &&
			[ ! -L "$_native_shell_root/$_native_shell_path" ] || return 1
	done
	for _native_shell_path in bin/sh bin/busybox; do
		[ -f "$_native_shell_root/$_native_shell_path" ] &&
			[ -x "$_native_shell_root/$_native_shell_path" ] || return 1
	done
	[ ! -e "$_native_shell_dir" ] && [ ! -L "$_native_shell_dir" ] || return 1
	_native_shell_reserved=1
	"$_native_shell_mkdir" -m 700 "$_native_shell_dir" || return 129
	_cfmgr_native_config_directory "$_native_shell_dir" || return 129
	# Reservation and every later failure retain evidence and forbid teardown.
	(
		set -C
		ulimit -f 9 || exit 129
		: >"$_native_shell_dir/stdout" && : >"$_native_shell_dir/stderr" || exit 129
	) || return 129
	(
		# Only this dedicated child changes descriptor state. FD6 pins the root
		# through native env/chroot and is closed by the first inner operation.
		trap - 0 HUP INT QUIT TERM
		cd / || exit 129
		ulimit -f 9 || exit 129
		exec 3<&- 4<&- 5<&- 7<&- 8<&- 9<&-
		exec "$_native_shell_env" -i PATH=/sbin:/bin:/usr/sbin:/usr/bin LC_ALL=C \
			HOME=/tmp/cfmgr-home TMPDIR=/tmp "$_native_shell_chroot" "$_native_shell_root" /bin/sh -c '
exec 6<&-
/bin/busybox test -d /tmp/cfmgr-home || exit 1
/bin/busybox test -c /dev/null || exit 1
/bin/busybox printf "CFMGR_NATIVE_SHELL_V1\n"
'
	) </dev/null >"$_native_shell_dir/stdout" 2>"$_native_shell_dir/stderr"
	_native_shell_status=$?
	[ "$_native_shell_status" -le 128 ] || return 129
	_native_shell_out=$(_cfmgr_io_size "$_native_shell_dir/stdout") || return 129
	_native_shell_err=$(_cfmgr_io_size "$_native_shell_dir/stderr") || return 129
	[ "$_native_shell_out" -le 4096 ] && [ "$_native_shell_err" -le 4096 ] || return 129
	_native_shell_ledger="native-shell $_native_shell_status $_native_shell_out $_native_shell_err$_io_lf"
	_cfmgr_isolation_write "$_native_shell_dir/status" "$_native_shell_ledger" || return 129
	# Read with a non-LF suffix and compare original byte length, so NUL or
	# terminal LF loss cannot turn a malformed response into the sentinel.
	_native_shell_text=$("$_native_shell_cat" "$_native_shell_dir/stdout" && "$_isolation_printf" '.') || return 129
	case $_native_shell_text in *.) ;; *) return 129 ;; esac
	_native_shell_text=${_native_shell_text%.}
	[ "${#_native_shell_text}" -eq "$_native_shell_out" ] || return 129
	"$_native_shell_mkdir" -m 700 "$_native_shell_dir/complete" || return 129
	_cfmgr_isolation_root_empty "$_native_shell_dir/complete" || return 129
	_native_shell_complete=1
	[ "$_native_shell_status" -eq 0 ] && [ "$_native_shell_err" -eq 0 ] &&
		[ "$_native_shell_text" = "CFMGR_NATIVE_SHELL_V1$_io_lf" ] || return 1
) >/dev/null 2>&1

_cfmgr_native_shell_tool() (
	case $1 in env | chroot | cat | wc | printf | mkdir | test) ;; *) return 2 ;; esac
	if [ "$_execution_kind" = fixture ]; then
		[ -x "$_isolation_tools/$1" ] && [ ! -d "$_isolation_tools/$1" ] || return 1
		printf '%s\n' "$_isolation_tools/$1"
		return
	fi
	for _native_shell_tool_dir in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_native_shell_tool_dir/$1" ] && [ ! -d "$_native_shell_tool_dir/$1" ]; then
			printf '%s/%s\n' "$_native_shell_tool_dir" "$1"
			return
		fi
	done
	return 1
)

_cfmgr_native_shell_exit() {
	_native_shell_exit=$1
	trap - 0
	if [ "$_native_shell_reserved" -eq 1 ] &&
		{ [ "$_native_shell_complete" -ne 1 ] || [ "$_native_shell_exit" -gt 128 ]; }; then
		_native_shell_exit=129
	fi
	exit "$_native_shell_exit"
}
