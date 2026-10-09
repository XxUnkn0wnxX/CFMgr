#!/bin/sh
# One genuine deadline/Entware/root/native-shell/cleanup composition proof.
# Storage acquisition is explicitly synthetic: regular FD8 and observed tmpfs
# Opt metadata, with real authority comparison and original FD9 retention.
# No physical block/UUID, ext media, firmware or router acceptance is claimed.
# shellcheck disable=SC2154,SC2030,SC2031
set -eu
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH
[ "$#" -eq 6 ] || [ "$#" -eq 7 ] || exit 2
# work is consumed by the shared fixture context.
# shellcheck disable=SC2034
repo=$1 work=$2 bb=$3 parent_mount=$4 parent_pid=$5 scenario=$6
fail() {
	printf 'native probe fixture failed: %s\n' "$*" >&2
	exit 1
}
[ "$scenario" = native-probe ] || exit 2
[ "$("$bb" readlink /proc/self/ns/mnt)" != "$parent_mount" ] || fail 'host mount namespace'
[ "$("$bb" readlink /proc/self/ns/pid)" != "$parent_pid" ] || fail 'host PID namespace'
# shellcheck source=/dev/null
. "$repo/tests/fixtures/kernel/native_setup.sh"
if [ "$#" -eq 6 ]; then
	[ "$$" -eq 1 ] || fail 'fixture is not namespace init'
	native_fixture_prepare native-probe
	# setsid creates the actual isolated cron-like group leader. Namespace init
	# remains outside that group, so cancellation cannot affect the host/runner.
	"$bb" setsid "$bb" sh "$0" "$@" leader || fail 'composed leader'
	for marker in probe-success root-returned deadline/armed deadline/done deadline/ack execution/complete watchdog-fds-checked storage-acquired; do
		_cfmgr_isolation_root_empty "$guard/$marker" || fail "missing checked $marker"
	done
	[ ! -e "$guard/probe-negative" ] && [ ! -L "$guard/probe-negative" ] || fail 'conflicting outcome'
	[ ! -e "$guard/deadline/cancel" ] && [ ! -L "$guard/deadline/cancel" ] || fail 'cancelled completion'
	[ ! -e "$guard/deadline/expired" ] || fail 'expired completion'
	"$bb" printf 'CFMGR_NATIVE_SHELL_V1\n' >"$guard/expected"
	"$bb" cmp -s "$guard/expected" "$guard/execution/native-shell/stdout" || fail 'exact native response'
	[ ! -s "$guard/execution/native-shell/stderr" ] || fail 'native stderr'
	# shellcheck disable=SC2329
	tree_clean() {
		_cfmgr_io_mount_capture "$2" "$repo/modules/lib/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
		[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ]
	}
	cfmgr_io_test "$ram" "$tools" workspace tree_clean "$ram" || fail 'retained execution mount'
	cfmgr_io_test "$ram" "$tools" workspace tree_clean "$native_source" || fail 'retained native mount'
	cfmgr_io_test "$ram" "$tools" workspace tree_clean "$opt_source" || fail 'retained Opt mount'
	"$bb" rm -rf "$guard"
	"$bb" umount -n "$opt_source" || fail 'Opt source cleanup'
	"$bb" umount -n "$native_source" || fail 'native source cleanup'
	"$bb" umount -n "$ram" || fail 'RAM cleanup'
	printf 'real armed deadline, synthetic storage original FD8/9 acquisition/authority, native root/shell and cleanup, watchdog own-process fd aliases, done/ack/exact wait passed\n'
	exit 0
fi
[ "$7" = leader ] && [ "$$" -ne 1 ] || fail 'invalid leader'
native_fixture_context native-probe
native_fixture_load
# shellcheck source=/dev/null
. "$repo/modules/helpers/worker.sh"
# shellcheck source=/dev/null
. "$repo/modules/helpers/native_probe.sh"
cfmgr_worker_group_check || fail 'actual original-shell group admission'
# Real mount topology feeds the fixture ledger and retained-root checks. UUID
# approval remains independently supplied by the caller, not this observation.
fixture_volume() {
	_cfmgr_io_mount_capture "$2" "$repo/modules/lib/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ] || return 1
	fixture_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$fixture_saved_ifs
	fixture_body="volume$_io_tab$2$_io_tab$4$_io_tab$7$_io_tab$5$_io_tab$6$_io_tab${11}$_io_tab$9$_io_tab${10}$_io_tab"'11111111-1111-1111-1111-111111111111'
	cfmgr_io_stage_report "$fixture_body${_io_lf}end$_io_tab$((${#fixture_body} + 1))$_io_lf"
}
volume=$(cfmgr_io_test "$ram" "$tools" report fixture_volume "$opt_source" && "$bb" printf '.') || fail 'actual Opt topology'
volume=${volume%.}
volume_body=${volume%%'
'*}
IFS='	'
# shellcheck disable=SC2086
set -- $volume_body
fixture_device=$3
IFS=' 	
'
printf 'synthetic block fixture\n' >"$guard/block"
# The real retained-root observer still parses blockdev metadata and verifies
# FD9. Only FD8's regular-file class is replaced by an exact synthetic response.
"$bb" cat >"$tools/ls" <<'BLOCK_LS'
#!/bin/sh
if [ "$#" -eq 2 ] && [ "$1" = -dni ]; then
	case $2 in null | urandom) exec "$CFMGR_KERNEL_BUSYBOX" ls "$@" ;; esac
fi
if [ "$#" -ne 2 ] || [ "$1" != -dnL ] || [ "$2" != /proc/self/fd/8 ]; then exit 2; fi
BLOCK_LS
"$bb" printf 'exec "%s" "brw------- 1 0 0 %s, %s Jan 1 00:00 /proc/self/fd/8\\n"\n' \
	"$tools/printf" "${fixture_device%%:*}" "${fixture_device#*:}" >>"$tools/ls"
"$bb" chmod 700 "$tools/ls"
CFMGR_KERNEL_BUSYBOX=$bb
export CFMGR_KERNEL_BUSYBOX

# Explicit test-only storage boundary. Production Entware still invokes and
# verifies its real admission callback before the fixed root composition.
cfmgr_storage_with() {
	[ "$#" -ge 7 ] && [ "$4" = _cfmgr_entware_admit ] || return 129
	[ "$1:$2:$3" = "$ram:$repo/modules/lib/mountinfo.awk:$repo/modules/lib/storageinfo.awk" ] || return 129
	_cfmgr_isolation_root_empty "$guard/deadline/armed" || return 129
	[ ! -e /proc/self/fd/8 ] && [ ! -e /proc/self/fd/9 ] || return 129
	# Acquisition occurs only after readiness. Never reopen inside root work.
	fixture_storage_held "$@" 8<"$guard/block" 9<"$opt_source"
}
fixture_storage_held() {
	"$bb" test "$guard/block" -ef /proc/self/fd/8 && "$bb" test "$opt_source" -ef /proc/self/fd/9 || return 129
	"$bb" mkdir -m 700 "$guard/storage-acquired" || return 129
	shift 4
	_cfmgr_entware_admit "$opt_source" "$volume" "$@"
}

# Source-profile fixture seam only: all lifecycle/leases/probe/cleanup are real.
cfmgr_isolation_native_config_root_with() {
	[ "$#" -eq 10 ] && [ "$9" = _cfmgr_worker_native_probe_root ] || return 129
	[ "$1:$3:$4" = "$opt_source:$ram:$guard" ] || return 129
	"$bb" test "$guard/block" -ef /proc/self/fd/8 && "$bb" test "$opt_source" -ef /proc/self/fd/9 || return 129
	cfmgr_isolation_native_config_root_test "$1" "$2" "$3" "$4" "$tools" /proc/self/mountinfo /proc/self/fdinfo/6 /proc/self/fdinfo/9 \
		"$native_source" "$data_source" "$5" "$6" "$7" "$8" fixture_probe_root "${10}"
}
fixture_probe_root() {
	[ "$#" -eq 4 ] && [ "$4" = "$guard" ] || return 129
	"$bb" test "$1" -ef /proc/self/fd/6 && "$bb" test "$guard/block" -ef /proc/self/fd/8 &&
		"$bb" test "$opt_source" -ef /proc/self/fd/9 || return 129
	_cfmgr_worker_pid_valid "$_worker_deadline_child" || return 129
	watcher_proc=/proc/$_worker_deadline_child/fd
	[ -d "$watcher_proc" ] || return 129
	"$bb" test /dev/null -ef "$watcher_proc/0" || return 129
	# Inspect the watchdog shell itself, including ash's saved high redirections;
	# an exec child's descriptors would incorrectly drop those aliases first.
	watcher_fd=3
	while [ "$watcher_fd" -le 63 ]; do
		for watcher_target in "$1" "$opt_source" "$guard/block"; do
			if "$bb" test "$watcher_target" -ef "$watcher_proc/$watcher_fd"; then return 129; fi
		done
		watcher_fd=$((watcher_fd + 1))
	done
	[ -d "$watcher_proc" ] || return 129
	"$bb" mkdir -m 700 "$guard/watchdog-fds-checked" || return 129
	_cfmgr_worker_native_probe_root "$@"
}
cfmgr_worker_native_probe "$ram" "$guard" 14 1 64 8 "$repo/modules/lib/mountinfo.awk" \
	"$repo/modules/lib/storageinfo.awk" 11111111-1111-1111-1111-111111111111 2f || fail 'composed native worker'
[ ! -e /proc/self/fd/8 ] && [ ! -e /proc/self/fd/9 ] || fail 'leaked acquired descriptors'
