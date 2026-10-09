#!/bin/sh
# Linux namespace-only consumer of the readonly root entry; no router execution.
# IO supplies checked ledger/framing state inside its isolated callbacks.
# shellcheck disable=SC2154
set -eu
[ "$#" -eq 6 ] || exit 2
repo=$1 work=$2 bb=$3 parent_mount=$4 parent_pid=$5 scenario=$6
fail() {
	printf 'execution root fixture failed: %s\n' "$*" >&2
	exit 1
}
[ "$scenario" = execution-root ] || exit 2
[ "$$" -eq 1 ] || fail 'fixture is not namespace init'
[ "$("$bb" readlink /proc/self/ns/mnt)" != "$parent_mount" ] || fail 'host mount namespace'
[ "$("$bb" readlink /proc/self/ns/pid)" != "$parent_pid" ] || fail 'host PID namespace'
# Both namespace checks precede every fixture mount; unshare made propagation
# private. The runner bounds and reaps this exact namespace init externally.
ram=$work/ram tools=$work/tools
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$ram"
guard=$ram/execution-root
"$bb" mkdir -m 700 "$guard"
# shellcheck source=/dev/null
. "$repo/modules/lib/io.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/storage.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/isolation.sh"

# Native observation only, with proof-only failed writes on the checked RO bind.
# No callback mount/unmount, children, alias writes or retained descriptors.
observe_root() {
	observer_root=$1 observer_ledger=$2
	[ "$3" = forwarded ] && [ "$#" -eq 3 ] || return 129
	"$bb" test -d /proc/self/fd/6 && "$bb" test "$observer_root" -ef /proc/self/fd/6 || return 129
	for observer_fd in 7 8 9; do
		"$bb" test "$guard/fd$observer_fd" -ef "/proc/self/fd/$observer_fd" || return 129
	done
	observer_saved_ifs=$IFS
	observer_body=${observer_ledger%%"$_io_lf"*}
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $observer_body
	IFS=$observer_saved_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] && [ "$7" = tmpfs ] || return 129
	observer_id=$2
	# Compare the actual inherited directory FD's mount ID independently of the
	# runtime's fdinfo parser. No outside-root descriptor is opened or retained.
	observer_fd_id=
	while IFS= read -r observer_line; do
		case $observer_line in mnt_id:*) observer_fd_id=${observer_line#mnt_id:} ;; esac
	done </proc/self/fdinfo/6
	# Native fdinfo emits horizontal whitespace before the decimal identity.
	# shellcheck disable=SC2086
	set -- $observer_fd_id
	[ "$#" -eq 1 ] && [ "$1" = "$observer_id" ] || return 129
	for observer_name in opt tmp; do
		"$bb" test -d "$observer_root/$observer_name" || return 129
		if (printf 'forbidden\n' >"$observer_root/$observer_name/late") 2>/dev/null; then
			return 129
		fi
		[ ! -e "$observer_root/$observer_name/late" ] || return 129
	done
	return 7
}

# Original FD6 must be restored, and FD7..9 remain the caller's files throughout.
printf 'six\n' >"$guard/fd6"
printf 'seven\n' >"$guard/fd7"
printf 'eight\n' >"$guard/fd8"
printf 'nine\n' >"$guard/fd9"
exec 6<"$guard/fd6" 7<"$guard/fd7" 8<"$guard/fd8" 9<"$guard/fd9"
status=0
cfmgr_isolation_root_test "$ram" "$guard" "$tools" /proc/self/mountinfo /proc/self/fdinfo/6 \
	"$repo/modules/lib/mountinfo.awk" "$repo/modules/lib/storageinfo.awk" observe_root forwarded || status=$?
[ "$status" -eq 7 ] || fail "ordinary callback status/teardown ($status)"
if IFS= read -r fd6 <&6 && IFS= read -r fd7 <&7 && IFS= read -r fd8 <&8 && IFS= read -r fd9 <&9; then :; else
	fail 'caller descriptors'
fi
[ "$fd6:$fd7:$fd8:$fd9" = six:seven:eight:nine ] || fail 'restored caller descriptors'
exec 6<&- 7<&- 8<&- 9<&-
if [ -d "$guard/execution/complete" ] && [ ! -L "$guard/execution/complete" ]; then :; else
	fail 'retained completion'
fi
for fallback in opt tmp; do
	[ ! -e "$guard/execution/image/$fallback/late" ] || fail 'backing fallback changed'
done
# A successful scenario cannot rely on namespace destruction to hide a mount.
ram_clean() {
	_cfmgr_io_mount_capture "$ram" "$repo/modules/lib/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ]
}
cfmgr_io_test "$ram" "$tools" workspace ram_clean || fail 'retained root mount'
"$bb" rm -rf "$guard"
"$bb" umount -n "$ram" || fail 'RAM mount cleanup'
printf 'execution root readonly fallbacks, actual lease and checked teardown passed\n'
