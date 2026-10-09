#!/bin/sh
# One genuine lock/deadline/Entware/root/ordinary synthetic-opkg composition.
# FD8 class/UUID/storage acquisition and immutable native-source selection are
# synthetic. All group, lock, deadline, FD9/root leases and cleanup are real.
# Never execute installed opkg, firmware or router code.
# shellcheck disable=SC2154,SC2030,SC2031
set -eu
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH
[ "$#" -eq 6 ] || [ "$#" -eq 7 ] || exit 2
# Shared fixture preparation consumes work.
# shellcheck disable=SC2034
repo=$1 work=$2 bb=$3 parent_mount=$4 parent_pid=$5 scenario=$6
fail() {
	printf 'native dependency fixture failed: %s\n' "$*" >&2
	exit 1
}
[ "$scenario" = native-dependencies ] || exit 2
[ "$("$bb" readlink /proc/self/ns/mnt)" != "$parent_mount" ] || fail 'host mount namespace'
[ "$("$bb" readlink /proc/self/ns/pid)" != "$parent_pid" ] || fail 'host PID namespace'
# shellcheck source=/dev/null
. "$repo/tests/fixtures/kernel/native_setup.sh"
if [ "$#" -eq 6 ]; then
	[ "$$" -eq 1 ] || fail 'fixture is not namespace init'
	native_fixture_prepare native-dependencies
	native_fixture_opkg
	printf 'anchored\n' >"$opt_source/anchored"
	: >"$ram/dependencies.lock"
	lock_identity=$("$bb" stat -c '%d:%i' "$ram/dependencies.lock")
	"$bb" setsid "$bb" sh "$0" "$@" leader || fail 'composed dependency leader'
	for marker in root-returned storage-returned deadline/armed deadline/done deadline/ack execution/complete execution/dependencies/complete watchdog-fds-checked storage-acquired locked-release-checked; do
		_cfmgr_isolation_root_empty "$guard/$marker" || fail "missing checked $marker"
	done
	if [ -e "$ram/dependencies.active" ] || [ -L "$ram/dependencies.active" ]; then fail 'active marker retained'; fi
	if [ ! -f "$ram/dependencies.lock" ] || [ -L "$ram/dependencies.lock" ]; then fail 'lock removed or replaced'; fi
	[ "$("$bb" stat -c '%d:%i' "$ram/dependencies.lock")" = "$lock_identity" ] || fail 'changed stable lock'
	for marker in cancel expired; do
		if [ -e "$guard/deadline/$marker" ] || [ -L "$guard/deadline/$marker" ]; then fail 'cancelled/expired completion'; fi
	done
	"$bb" printf 'CFMGR_WORKER_DEPENDENCIES_V1 0\n' >"$guard/expected-result"
	"$bb" cmp -s "$guard/expected-result" "$guard/dependencies-result" || fail 'exact worker result'
	"$bb" printf 'dependencies repair shared native 0\n' >"$guard/expected-helper"
	"$bb" cmp -s "$guard/expected-helper" "$guard/execution/dependencies/status" || fail 'exact backend result'
	"$bb" cmp -s "$repo/modules/helpers/bootstrap.sh" "$guard/execution/dependencies/bootstrap" || fail 'immutable backend copy'
	"$bb" printf 'timeout\nsha256sum\nupdate\ninstall jq\njq\ntimeout\nsha256sum\n' >"$guard/expected-commands"
	"$bb" cmp -s "$guard/expected-commands" "$opt_source/dependency-commands" || fail 'normal opkg order'
	"$bb" dd if=/dev/zero of="$guard/expected-package" bs=4096 count=8 2>/dev/null
	"$bb" cmp -s "$guard/expected-package" "$opt_source/dependency-package-data" || fail 'unclipped 32KiB package write'
	"$bb" test -x "$opt_source/bin/jq" || fail 'installed synthetic jq'
	# Invoked by the controlled IO workspace, never directly.
	# shellcheck disable=SC2317,SC2329
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
	printf 'real native lock and armed dependency deadline, original storage/root leases, synthetic ordinary opkg repair/32KiB write, watchdog FD7/high aliases, done/ack/exact reap before owned release and stable lock passed\n'
	exit 0
fi
if [ "$7" != leader ] || [ "$$" -eq 1 ]; then fail 'invalid leader'; fi
native_fixture_context native-dependencies
native_fixture_load
# shellcheck source=/dev/null
. "$repo/modules/helpers/worker.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/dependency_lock.sh"
# shellcheck source=/dev/null
. "$repo/modules/helpers/dependencies.sh"
native_fixture_storage_metadata || fail 'actual Opt topology'
printf 'synthetic block fixture\n' >"$guard/block"
CFMGR_KERNEL_BUSYBOX=$bb
export CFMGR_KERNEL_BUSYBOX

# A private release-tool witness checks ack/reap and exclusion immediately
# before delegating the actual rmdir. All other tool discovery is unchanged.
CFMGR_KERNEL_GUARD=$guard
CFMGR_KERNEL_RAM=$ram
CFMGR_KERNEL_FLOCK=$(command -v flock) || fail 'native flock missing'
export CFMGR_KERNEL_GUARD CFMGR_KERNEL_RAM CFMGR_KERNEL_FLOCK
"$bb" cat >"$tools/dependencies-rmdir" <<'RELEASE'
#!/bin/sh
set -eu
bb=$CFMGR_KERNEL_BUSYBOX guard=$CFMGR_KERNEL_GUARD ram=$CFMGR_KERNEL_RAM
[ "$#" -eq 1 ] && [ "$1" = "$ram/dependencies.active" ] || exit 129
[ -d "$guard/deadline/done" ] && [ -d "$guard/deadline/ack" ] || exit 129
watcher=$("$bb" cat "$guard/watchdog-pid")
case $watcher in '' | *[!0123456789]*) exit 129 ;; esac
[ ! -e "/proc/$watcher" ] || exit 129
"$bb" test "$ram/dependencies.lock" -ef /proc/self/fd/7 || exit 129
exec 8>>"$ram/dependencies.lock"
if "$CFMGR_KERNEL_FLOCK" -n 8; then exit 129; fi
exec 8>&-
[ ! -e "$1/owner" ] && [ ! -L "$1/owner" ] || exit 129
"$bb" mkdir -m 700 "$guard/locked-release-checked"
exec "$bb" rmdir "$@"
RELEASE
"$bb" chmod 700 "$tools/dependencies-rmdir"
_cfmgr_worker_dependencies_tools() {
	_io_tools=''
	_io_lf='
'
	_io_tab='	'
	_io_wc=$(_cfmgr_io_find wc) && _isolation_printf=$(_cfmgr_io_find printf) &&
		_dependencies_mkdir=$(_cfmgr_io_find mkdir) && _dependencies_rm=$(_cfmgr_io_find rm) || return 1
	_dependencies_rmdir=$tools/dependencies-rmdir
}

# Replace only the storage-acquisition boundary. Real Entware admission compares
# caller UUID/filesystem authority, and the real root observer retains FD9.
cfmgr_storage_with() {
	[ "$#" -ge 7 ] && [ "$4" = _cfmgr_entware_admit ] || return 129
	[ "$1:$2:$3" = "$ram:$repo/modules/lib/mountinfo.awk:$repo/modules/lib/storageinfo.awk" ] || return 129
	_cfmgr_isolation_root_empty "$guard/deadline/armed" &&
		_cfmgr_worker_dependencies_active "$ram" "$guard" || return 129
	[ ! -e /proc/self/fd/8 ] && [ ! -e /proc/self/fd/9 ] || return 129
	"$bb" test "$ram/dependencies.lock" -ef /proc/self/fd/7 || return 129
	fixture_storage_held "$@" 8<"$guard/block" 9<"$opt_source"
}
fixture_storage_held() {
	"$bb" test "$guard/block" -ef /proc/self/fd/8 && "$bb" test "$opt_source" -ef /proc/self/fd/9 || return 129
	"$bb" mkdir -m 700 "$guard/storage-acquired" || return 129
	shift 4
	_cfmgr_entware_admit "$opt_source" "$volume" "$@"
}

# Immutable fixture source selection only; root lifecycle, binds and teardown
# use the actual native-config implementation and real original descriptors.
cfmgr_isolation_native_config_root_with() {
	[ "$#" -eq 14 ] && [ "$9" = _cfmgr_worker_dependencies_root ] || return 129
	[ "$1:$3:$4" = "$opt_source:$ram:$guard" ] || return 129
	"$bb" test "$guard/block" -ef /proc/self/fd/8 && "$bb" test "$opt_source" -ef /proc/self/fd/9 || return 129
	cfmgr_isolation_native_config_root_test "$1" "$2" "$3" "$4" "$tools" /proc/self/mountinfo /proc/self/fdinfo/6 /proc/self/fdinfo/9 \
		"$native_source" "$data_source" "$5" "$6" "$7" "$8" fixture_dependencies_root \
		"${10}" "${11}" "${12}" "${13}" "${14}"
}
fixture_dependencies_root() {
	[ "$#" -eq 8 ] && [ "$4" = "$guard" ] || return 129
	"$bb" test "$1" -ef /proc/self/fd/6 && "$bb" test "$ram/dependencies.lock" -ef /proc/self/fd/7 &&
		"$bb" test "$guard/block" -ef /proc/self/fd/8 && "$bb" test "$opt_source" -ef /proc/self/fd/9 || return 129
	_cfmgr_worker_pid_valid "$_worker_deadline_child" || return 129
	watcher_proc=/proc/$_worker_deadline_child/fd
	[ -d "$watcher_proc" ] || return 129
	"$bb" test /dev/null -ef "$watcher_proc/0" || return 129
	# Observe the watchdog shell itself; an exec child hides saved ash aliases.
	watcher_fd=3
	while [ "$watcher_fd" -le 63 ]; do
		for watcher_target in "$1" "$opt_source" "$guard/block" "$ram/dependencies.lock" "$guard/caller0" "$guard/caller1" "$guard/caller2" "$guard/caller7"; do
			if "$bb" test "$watcher_target" -ef "$watcher_proc/$watcher_fd"; then return 129; fi
		done
		watcher_fd=$((watcher_fd + 1))
	done
	[ -d "$watcher_proc" ] || return 129
	printf '%s\n' "$_worker_deadline_child" >"$guard/watchdog-pid" || return 129
	"$bb" mkdir -m 700 "$guard/watchdog-fds-checked" || return 129
	_cfmgr_worker_dependencies_root "$@"
}

printf 'caller stdin\n' >"$guard/caller0"
printf 'caller fd7\n' >"$guard/caller7"
# Supplying an old FD7 plus standard streams makes saved high-alias regressions
# observable in the watchdog shell, not just in its eventual exec children.
exec 0<"$guard/caller0" 1>"$guard/caller1" 2>"$guard/caller2" 7<"$guard/caller7"
cfmgr_worker_dependencies "$ram" "$guard" 14 1 64 8 "$repo/modules/lib/mountinfo.awk" \
	"$repo/modules/lib/storageinfo.awk" 11111111-1111-1111-1111-111111111111 2f \
	"$repo/modules/helpers/bootstrap.sh" repair shared native || fail 'composed dependency worker'
for caller_fd in 0 1 2 7; do
	"$bb" test "$guard/caller$caller_fd" -ef "/proc/self/fd/$caller_fd" || fail 'caller descriptor changed'
done
if [ -e /proc/self/fd/8 ] || [ -e /proc/self/fd/9 ]; then fail 'leaked storage descriptors'; fi
if [ -e "$ram/dependencies.active" ] || [ -L "$ram/dependencies.active" ]; then fail 'owned release missing'; fi
# A fresh descriptor can acquire the unchanged file after the completed owner.
exec 7<&-
exec 7>>"$ram/dependencies.lock"
"$CFMGR_KERNEL_FLOCK" -n 7 || fail 'lock retained after completed owner'
exec 7>&-
