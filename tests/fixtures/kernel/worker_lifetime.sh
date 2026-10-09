#!/bin/sh
# Linux namespace-only mechanism fixture; no router or operational worker code.
# The imported IO owner assigns the mount ledger and framing variables below.
# shellcheck disable=SC2154
set -eu
[ "$#" -eq 6 ] || exit 2
repo=$1 work=$2 bb=$3 parent_mount=$4 parent_pid=$5 scenario=$6
fail() {
	printf 'worker lifetime fixture failed: %s\n' "$*" >&2
	exit 1
}
[ "$scenario" = worker-lifetime ] || exit 2
[ "$$" -eq 1 ] || fail 'fixture is not namespace init'
[ "$("$bb" readlink /proc/self/ns/mnt)" != "$parent_mount" ] || fail 'host mount namespace'
[ "$("$bb" readlink /proc/self/ns/pid)" != "$parent_pid" ] || fail 'host PID namespace'
# util-linux established private propagation. Both identity checks above precede
# every fixture mount, including the RAM parent and the read-only root bind.
ram=$work/ram tools=$work/tools
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$ram"
guard=$ram/worker-lifetime image=$ram/worker-lifetime/image root=$ram/worker-lifetime/root
opt=$guard/writable-opt
"$bb" mkdir -m 700 "$guard" "$image" "$image/opt" "$image/tmp" "$root" "$opt"
"$bb" mount -n -i -o bind "$image" "$root"
"$bb" mount -n -i -o make-private "$root"
"$bb" mount -n -i -o remount,bind,ro,nosuid,nodev "$image" "$root"
# shellcheck source=/dev/null
. "$repo/modules/io.sh"
# shellcheck disable=SC2317,SC2329
root_record() {
	_cfmgr_io_mount_capture "$root" "$repo/modules/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ] || return 1
	expected_hex=$(printf '%s' "$root" | "$bb" hexdump -v -e '1/1 "%02x"') || return 1
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	[ "$#" -eq 11 ] && [ "$6" = "$expected_hex" ] && [ "$7" = tmpfs ] || return 1
	case ${9} in 726f | 726f2c*) ;; *) return 1 ;; esac
	cfmgr_io_stage_report "$2$_io_lf"
}
root_mount_id=$(cfmgr_io_test "$ram" "$tools" report root_record) || fail 'actual private readonly root record'
"$work/worker-lifetime" "$root" "$guard" "$opt" "$image" "$root_mount_id" || fail 'native controller'
[ "$("$bb" cat "$guard/complete")" = complete ] || fail 'missing proven completion'
# No namespace discard may hide retained fixture mounts on a successful path.
# shellcheck disable=SC2317,SC2329
ram_clean() {
	_cfmgr_io_mount_capture "$ram" "$repo/modules/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ]
}
cfmgr_io_test "$ram" "$tools" workspace ram_clean || fail 'retained fixture mount'
"$bb" rm -rf "$guard"
"$bb" umount -n "$ram" || fail 'RAM mount cleanup'
printf 'worker lifetime filesystem quiescence passed; descendant reaping is separate\n'
