#!/bin/sh
# Namespace-only native RO views/data, private tmp/HOME and retained Opt.
# No installed payload, chroot or router execution; fixed exec proof only.
# IO supplies checked ledger/framing state inside its isolated callbacks.
# shellcheck disable=SC2154
set -eu
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH
[ "$#" -eq 6 ] || exit 2
repo=$1 work=$2 bb=$3 parent_mount=$4 parent_pid=$5 scenario=$6
fail() {
	printf 'native root fixture failed: %s\n' "$*" >&2
	exit 1
}
[ "$scenario" = native-root ] || exit 2
[ "$$" -eq 1 ] || fail 'fixture is not namespace init'
[ "$("$bb" readlink /proc/self/ns/mnt)" != "$parent_mount" ] || fail 'host mount namespace'
[ "$("$bb" readlink /proc/self/ns/pid)" != "$parent_pid" ] || fail 'host PID namespace'
# All mounts follow both namespace checks. The runner supplies private
# propagation and bounds/reaps this exact namespace init externally.
ram=$work/ram tools=$work/tools native_source=$work/native-source opt_source=$work/opt-source
"$bb" mkdir -m 700 "$native_source" "$opt_source"
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$ram"
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$native_source"
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$opt_source"
for view in bin sbin lib usr; do
	"$bb" mkdir -m 700 "$native_source/$view"
	printf '%s\n' "$view" >"$native_source/$view/marker"
done
# Remount the actual source filesystem readonly: a RO bind alone would leave
# its superblock RW and must be refused by the native-source admission profile.
"$bb" mount -n -i -o remount,ro "$native_source"
data_source=$ram/native-data-source
"$bb" mkdir -m 700 "$data_source" "$data_source/etc"
data_hosts='127.0.0.1	localhost\fixture

'
printf '%s' "$data_hosts" >"$data_source/etc/hosts"
: >"$data_source/etc/resolv.conf"
guard=$ram/native-root
"$bb" mkdir -m 700 "$guard"
# shellcheck source=/dev/null
. "$repo/modules/lib/io.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/storage.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/native_config.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/isolation.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/entware.sh"
# shellcheck source=/dev/null
. "$repo/modules/lib/entware_root.sh"

observe_native_data() {
	"$bb" test -d "$1/etc" && "$bb" test ! -L "$1/etc" || return 129
	for observer_data_name in hosts resolv.conf; do
		"$bb" test -f "$1/etc/$observer_data_name" && "$bb" test ! -L "$1/etc/$observer_data_name" || return 129
		if (printf 'forbidden\n' >"$1/etc/$observer_data_name") 2>/dev/null; then
			return 129
		fi
	done
	observer_hosts=$("$bb" cat "$1/etc/hosts" && "$bb" printf '.') || return 129
	[ "$observer_hosts" = "${data_hosts}." ] && [ ! -s "$1/etc/resolv.conf" ] || return 129
	if (printf 'forbidden\n' >"$1/etc/late") 2>/dev/null; then return 129; fi
	if "$bb" mkdir "$1/etc/late-dir" 2>/dev/null; then return 129; fi
	[ ! -e "$1/etc/late" ] && [ ! -e "$1/etc/late-dir" ]
}

observe_native_tmp() {
	observer_tmp=$1/tmp
	[ "${HOME-}" = "$outside_home" ] || return 129
	"$bb" test -d "$observer_tmp/cfmgr-home" && "$bb" test ! -L "$observer_tmp/cfmgr-home" || return 129
	_cfmgr_isolation_root_empty "$observer_tmp/cfmgr-home" || return 129
	[ "$("$bb" stat -c %a "$observer_tmp/cfmgr-home")" = 700 ] || return 129
	printf 'scratch\n' >"$observer_tmp/scratch" || return 129
	[ "$("$bb" cat "$observer_tmp/scratch")" = scratch ] || return 129
	"$bb" rm "$observer_tmp/scratch" || return 129
	# This tiny fixed proof script is the sole execution exception in the kernel
	# fixture observer. It tests mount exec permission, never an installed payload.
	printf '#!/bin/sh\nexit 23\n' >"$observer_tmp/exec-proof" || return 129
	"$bb" chmod 700 "$observer_tmp/exec-proof" || return 129
	observer_exec_status=0
	"$observer_tmp/exec-proof" || observer_exec_status=$?
	[ "$observer_exec_status" -eq 23 ] || return 129
	"$bb" rm "$observer_tmp/exec-proof" || return 129
	# Only 65 KiB is attempted against a 64 KiB cap, without an arbitrary wait.
	if "$bb" dd if=/dev/zero of="$observer_tmp/byte-cap" bs=1024 count=65 2>/dev/null; then return 129; fi
	observer_bytes=$("$bb" wc -c <"$observer_tmp/byte-cap") || return 129
	[ "$observer_bytes" -eq 65536 ] || return 129
	"$bb" rm "$observer_tmp/byte-cap" || return 129
	observer_inode=0 observer_inode_failed=0
	while [ "$observer_inode" -lt 9 ]; do
		if (: >"$observer_tmp/inode-$observer_inode") 2>/dev/null; then
			observer_inode=$((observer_inode + 1))
		else
			observer_inode_failed=1
			break
		fi
	done
	# The only existing inodes are the tmp root and its private empty HOME.
	[ "$observer_inode_failed" -eq 1 ] && [ "$observer_inode" -eq 6 ] || return 129
	while [ "$observer_inode" -gt 0 ]; do
		observer_inode=$((observer_inode - 1))
		"$bb" rm "$observer_tmp/inode-$observer_inode" || return 129
	done
	_cfmgr_isolation_root_empty "$observer_tmp/cfmgr-home"
}

observe_native_root() {
	observer_root=$1 observer_ledger=$2
	[ "$#" -eq 4 ] && [ "$3" = "$volume" ] && [ "$4" = forwarded ] || return 129
	"$bb" test -d /proc/self/fd/6 && "$bb" test "$observer_root" -ef /proc/self/fd/6 || return 129
	for observer_fd in 7 8; do
		"$bb" test "$guard/fd$observer_fd" -ef "/proc/self/fd/$observer_fd" || return 129
	done
	"$bb" test "$opt_source" -ef /proc/self/fd/9 &&
		"$bb" test "$observer_root/opt" -ef /proc/self/fd/9 || return 129
	printf 'anchored\n' >"$observer_root/opt/anchored" || return 129
	[ "$("$bb" cat /proc/self/fd/9/anchored)" = anchored ] &&
		[ "$("$bb" cat "$opt_source/anchored")" = anchored ] || return 129
	observer_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- ${observer_ledger%%"$_io_lf"*}
	IFS=$observer_saved_ifs
	[ "$#" -eq 11 ] && [ "$1" = mount ] && [ "$7" = tmpfs ] || return 129
	observer_id=$2
	observer_fd_id=
	while IFS= read -r observer_line; do
		case $observer_line in mnt_id:*) observer_fd_id=${observer_line#mnt_id:} ;; esac
	done </proc/self/fdinfo/6
	# shellcheck disable=SC2086
	set -- $observer_fd_id
	[ "$#" -eq 1 ] && [ "$1" = "$observer_id" ] || return 129
	observer_topology=${observer_ledger#*"$_io_lf"}
	observer_topology=${observer_topology%%"$_io_lf"*}
	[ "$observer_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'6' ] || return 129
	observe_native_data "$observer_root" || return 129
	observe_native_tmp "$observer_root" || return 129
	# Proof-only attempted writes demonstrate the admitted RO views/fallbacks;
	# no mount commands, descendants or descriptors are retained by this observer.
	for observer_name in bin sbin lib usr; do
		"$bb" test -d "$observer_root/$observer_name" || return 129
		case $observer_name in
		bin | sbin | lib | usr)
			[ "$("$bb" cat "$observer_root/$observer_name/marker")" = "$observer_name" ] || return 129
			;;
		esac
		if (printf 'forbidden\n' >"$observer_root/$observer_name/late") 2>/dev/null; then
			return 129
		fi
		[ ! -e "$observer_root/$observer_name/late" ] || return 129
	done
	return 7
}

printf 'six\n' >"$guard/fd6"
printf 'seven\n' >"$guard/fd7"
printf 'eight\n' >"$guard/fd8"
# FD9 is a real retained directory. FD8 is deliberately a regular fixture
# file; only its block metadata observation is synthetic. This does not prove
# an ext filesystem, real UUID approval or real block-device acquisition.
exec 6<"$guard/fd6" 7<"$guard/fd7" 8<"$guard/fd8" 9<"$opt_source"
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
volume=$(cfmgr_io_test "$ram" "$tools" report fixture_volume "$opt_source" && "$bb" printf '.') || fail 'Opt source volume'
volume=${volume%.}
volume_body=${volume%%'
'*}
saved_ifs=$IFS
IFS='	'
# shellcheck disable=SC2086
set -- $volume_body
IFS=$saved_ifs
fixture_device=$3
# This exact, bounded ls double reports the controlled source major/minor.
# The runtime still parses it through the real blockdev parser and checks FD9.
"$bb" cat >"$tools/ls" <<'BLOCK_LS'
#!/bin/sh
if [ "$#" -ne 2 ] || [ "$1" != -dnL ] || [ "$2" != /proc/self/fd/8 ]; then exit 2; fi
BLOCK_LS
"$bb" printf 'exec "%s" "brw------- 1 0 0 %s, %s Jan 1 00:00 /proc/self/fd/8\\n"\n' \
	"$tools/printf" "${fixture_device%%:*}" "${fixture_device#*:}" >>"$tools/ls"
"$bb" chmod 700 "$tools/ls"
# Replace the fixture symlink itself, never write through it into BusyBox.
# This wrapper delegates every real unmount and witnesses the live RO fallback
# before permitting tmp removal. All inputs are fixed by this namespace fixture.
CFMGR_KERNEL_BUSYBOX=$bb
CFMGR_KERNEL_OPT_FALLBACK=$guard/execution/root/opt
CFMGR_KERNEL_TMP=$guard/execution/root/tmp
CFMGR_KERNEL_OPT_WITNESS=$guard/opt-fallback-checked
export CFMGR_KERNEL_BUSYBOX CFMGR_KERNEL_OPT_FALLBACK CFMGR_KERNEL_TMP CFMGR_KERNEL_OPT_WITNESS
"$bb" rm "$tools/umount"
"$bb" cat >"$tools/umount" <<'REAL_UMOUNT'
#!/bin/sh
set -eu
bb=$CFMGR_KERNEL_BUSYBOX opt=$CFMGR_KERNEL_OPT_FALLBACK
scratch=$CFMGR_KERNEL_TMP witness=$CFMGR_KERNEL_OPT_WITNESS
if [ "$#" -eq 1 ] && [ "$1" = --help ]; then exec "$bb" umount --help; fi
target=''
for target do :; done
if [ "$target" = "$scratch" ]; then
	"$bb" test -d "$witness" && "$bb" test ! -L "$witness" || exit 129
fi
"$bb" umount "$@" || exit 129
if [ "$target" = "$opt" ]; then
	"$bb" test -d "$opt" && "$bb" test ! -L "$opt" || exit 129
	if ("$bb" printf 'forbidden\n' >"$opt/late") 2>/dev/null; then exit 129; fi
	"$bb" test ! -e "$opt/late" || exit 129
	"$bb" test ! -e "$witness" && "$bb" test ! -L "$witness" || exit 129
	"$bb" mkdir -m 700 "$witness" || exit 129
fi
REAL_UMOUNT
"$bb" chmod 700 "$tools/umount"
status=0
outside_home=${HOME-}
cfmgr_isolation_entware_root_test "$opt_source" "$volume" "$ram" "$guard" "$tools" /proc/self/mountinfo /proc/self/fdinfo/6 /proc/self/fdinfo/9 \
	"$native_source" "$data_source" 64 8 "$repo/modules/lib/mountinfo.awk" "$repo/modules/lib/storageinfo.awk" observe_native_root forwarded || status=$?
[ "$status" -eq 7 ] || fail "ordinary callback status/teardown ($status)"
_cfmgr_isolation_root_empty "$guard/opt-fallback-checked" || fail 'missing immediate RO Opt fallback/order witness'
if IFS= read -r fd6 <&6 && IFS= read -r fd7 <&7 && IFS= read -r fd8 <&8; then :; else
	fail 'caller descriptors'
fi
[ "$fd6:$fd7:$fd8" = six:seven:eight ] || fail 'restored caller descriptors'
"$bb" test "$opt_source" -ef /proc/self/fd/9 || fail 'retained caller directory descriptor'
exec 6<&- 7<&- 8<&- 9<&-
if [ -d "$guard/execution/complete" ] && [ ! -L "$guard/execution/complete" ]; then :; else
	fail 'retained completion'
fi
for view in bin sbin lib usr; do
	for evidence in source fallback intent mounted; do
		[ -f "$guard/execution/$evidence-$view" ] || fail 'missing child evidence'
	done
	[ "$("$bb" cat "$native_source/$view/marker")" = "$view" ] || fail 'source changed'
	if [ ! -e "$native_source/$view/late" ] && [ ! -e "$guard/execution/image/$view/late" ]; then :; else
		fail 'writable native view'
	fi
done
if [ -f "$guard/execution/base-root" ] && [ -f "$guard/execution/populated-root" ]; then :; else
	fail 'missing root evidence'
fi
image_hosts=$("$bb" cat "$guard/execution/image/etc/hosts" && "$bb" printf '.') || fail 'staged hosts readback'
if [ "$image_hosts" = "${data_hosts}." ] && [ ! -s "$guard/execution/image/etc/resolv.conf" ] &&
	[ ! -e "$guard/execution/image/etc/late" ] && [ ! -e "$guard/execution/image/etc/late-dir" ]; then :; else
	fail 'staged data changed'
fi
query=0
while [ "$query" -lt 78 ]; do
	[ -f "$guard/execution/query-$query" ] || fail 'missing unique query'
	query=$((query + 1))
done
[ ! -e "$guard/execution/query-78" ] || fail 'unexpected query count'
_cfmgr_isolation_root_empty "$guard/execution/image/opt" || fail 'Opt fallback changed'
[ "$("$bb" cat "$opt_source/anchored")" = anchored ] || fail 'anchored source write'
for evidence in source fallback intent mounted; do
	[ -f "$guard/execution/$evidence-opt" ] || fail 'missing Opt evidence'
done
_cfmgr_isolation_root_empty "$guard/execution/image/tmp" || fail 'tmp fallback changed'
for evidence in fallback intent mounted; do
	[ -f "$guard/execution/$evidence-tmp" ] || fail 'missing tmp evidence'
done
# Assert no surviving execution-root or native child mounts before cleanup;
# namespace destruction alone is never accepted as successful teardown.
tree_clean() {
	_cfmgr_io_mount_capture "$2" "$repo/modules/lib/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ]
}
cfmgr_io_test "$ram" "$tools" workspace tree_clean "$ram" || fail 'retained execution mount'
cfmgr_io_test "$ram" "$tools" workspace tree_clean "$native_source" || fail 'retained source child mount'
cfmgr_io_test "$ram" "$tools" workspace tree_clean "$opt_source" || fail 'retained Opt source child mount'
"$bb" rm -rf "$guard"
"$bb" umount -n "$opt_source" || fail 'Opt source mount cleanup'
"$bb" umount -n "$native_source" || fail 'source mount cleanup'
"$bb" umount -n "$ram" || fail 'RAM mount cleanup'
printf 'native RO views/data, private tmp/HOME, byte/inode caps, exec permission, retained Opt bind/write, root lease and Opt-first reverse teardown passed\n'
