#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only finite handoff to the independently trusted immutable bundled
# bootstrap backend. Requires explicitly sourced native_exec/io/root helpers.
# Caller owns retained Opt/native-config admission, trusted package/native code,
# accepted ordinary opkg/script behavior and the aggregate group/deadline.
# Path/size/framing are not provenance. No rollback or descendant quiescence is
# claimed: the enclosing root owner still decides checked ordinary teardown.
# shellcheck disable=SC2154,SC2030,SC2031

cfmgr_native_dependencies() (
	set +x
	set +e
	set +u
	set +C
	set -f
	_cfmgr_native_exec_environment
	IFS=' 	'
	IFS="${IFS}
"
	umask 077
	_native_shell_reserved=0 _native_shell_complete=0
	trap '_cfmgr_native_shell_exit "$?"' 0
	trap 'exit 129' HUP INT QUIT TERM
	[ "$#" -eq 5 ] || return 2
	case $3 in repair | reinstall) ;; *) return 2 ;; esac
	case $4 in shared | tunnel) ;; *) return 2 ;; esac
	case $5 in native | entware) ;; *) return 2 ;; esac
	_cfmgr_isolation_path "$2" && [ "$2" != / ] || return 2
	_native_dependencies_source=$2
	_native_dependencies_action=$3 _native_dependencies_scope=$4 _native_dependencies_lock=$5
	_cfmgr_native_exec_context "$1" || return "$?"
	_native_shell_dir=$_isolation_guard/dependencies
	_native_dependencies_private=$_native_shell_root/tmp/cfmgr-dependencies
	[ -f "$_native_dependencies_source" ] && [ ! -L "$_native_dependencies_source" ] &&
		[ -r "$_native_dependencies_source" ] || return 1
	_native_dependencies_size=$(_cfmgr_io_size "$_native_dependencies_source") || return 1
	[ "$_native_dependencies_size" -ge 1 ] || return 1
	for _native_dependencies_binary in bin/busybox opt/bin/opkg; do
		[ -f "$_native_shell_root/$_native_dependencies_binary" ] &&
			[ -x "$_native_shell_root/$_native_dependencies_binary" ] || return 1
	done
	for _native_dependencies_path in "$_native_shell_dir" "$_native_dependencies_private"; do
		[ ! -e "$_native_dependencies_path" ] && [ ! -L "$_native_dependencies_path" ] || return 1
	done
	_native_shell_reserved=1
	"$_native_shell_mkdir" -m 700 "$_native_shell_dir" || return 129
	_cfmgr_native_config_directory "$_native_shell_dir" || return 129
	# The only source-copy ceiling belongs to this subshell, never the payload.
	(
		set -C
		ulimit -f 129 || exit 129
		"$_native_shell_cat" "$_native_dependencies_source" >"$_native_shell_dir/bootstrap"
	) || return 129
	_native_dependencies_copied=$(_cfmgr_io_size "$_native_shell_dir/bootstrap") || return 129
	[ "$_native_dependencies_copied" -eq "$_native_dependencies_size" ] || return 129
	_native_dependencies_text=$("$_native_shell_cat" "$_native_shell_dir/bootstrap" && "$_isolation_printf" '.') || return 129
	case $_native_dependencies_text in *.) ;; *) return 129 ;; esac
	_native_dependencies_text=${_native_dependencies_text%.}
	[ "${#_native_dependencies_text}" -eq "$_native_dependencies_copied" ] || return 129
	"$_native_shell_mkdir" -m 700 "$_native_dependencies_private" || return 129
	_cfmgr_native_config_directory "$_native_dependencies_private" &&
		_cfmgr_isolation_root_empty "$_native_dependencies_private" || return 129
	_native_dependencies_script='
exec 6<&-
'
	_native_dependencies_script=$_native_dependencies_script$_native_dependencies_text
	# Always terminate the bundled source, including an unterminated comment.
	# Expand the finite selectors/status only in the launched inner shell.
	# shellcheck disable=SC2016
	_native_dependencies_script=$_native_dependencies_script'
case $1 in
repair)
    if cfmgr_bootstrap_dependencies "$2" "$3"; then
        _native_dependencies_status=0
    else
        _native_dependencies_status=$?
    fi
    ;;
reinstall)
    if cfmgr_bootstrap_reinstall "$2" "$3"; then
        _native_dependencies_status=0
    else
        _native_dependencies_status=$?
    fi
    ;;
*) exit 129 ;;
esac
case $_native_dependencies_status in 0|1) ;; *) exit 129 ;; esac
(
    umask 077
    set -C
    ulimit -f 1 || exit 129
    /bin/busybox printf "CFMGR_DEPENDENCIES_V1 %s\n" "$_native_dependencies_status" > /tmp/cfmgr-dependencies/result
) || exit 129
exit "$_native_dependencies_status"
'
	(
		trap - 0 HUP INT QUIT TERM
		cd / || exit 129
		# No file-size limit here or in env/chroot/backend ancestry: ordinary
		# opkg writes must not inherit the old tiny version-probe capture cap.
		exec 3<&- 4<&- 5<&- 7<&- 8<&- 9<&-
		exec "$_native_shell_env" -i PATH=/sbin:/bin:/usr/sbin:/usr/bin LC_ALL=C \
			HOME=/tmp/cfmgr-home TMPDIR=/tmp "$_native_shell_chroot" "$_native_shell_root" \
			/bin/sh -c "$_native_dependencies_script" cfmgr-dependencies \
			"$_native_dependencies_action" "$_native_dependencies_scope" "$_native_dependencies_lock"
	) </dev/null >/dev/null 2>&1
	_native_dependencies_status=$?
	case $_native_dependencies_status in 0 | 1) ;; *) return 129 ;; esac
	[ -f "$_native_dependencies_private/result" ] && [ ! -L "$_native_dependencies_private/result" ] &&
		[ -r "$_native_dependencies_private/result" ] || return 129
	_native_dependencies_expected="CFMGR_DEPENDENCIES_V1 $_native_dependencies_status$_io_lf"
	_native_dependencies_record_size=$(_cfmgr_io_size "$_native_dependencies_private/result") || return 129
	[ "$_native_dependencies_record_size" -eq "${#_native_dependencies_expected}" ] || return 129
	_cfmgr_isolation_read "$_native_dependencies_private/result" || return 129
	[ "$_isolation_text" = "$_native_dependencies_expected" ] || return 129
	_cfmgr_isolation_write "$_native_shell_dir/status" \
		"dependencies $_native_dependencies_action $_native_dependencies_scope $_native_dependencies_lock $_native_dependencies_status$_io_lf" || return 129
	"$_native_shell_mkdir" -m 700 "$_native_shell_dir/complete" || return 129
	_cfmgr_isolation_root_empty "$_native_shell_dir/complete" || return 129
	_native_shell_complete=1
	return "$_native_dependencies_status"
) >/dev/null 2>&1
