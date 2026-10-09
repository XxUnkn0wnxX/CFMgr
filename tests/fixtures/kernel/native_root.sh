#!/bin/sh
# Namespace-only native readonly views/data; no payload, chroot/router execution.
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
ram=$work/ram tools=$work/tools native_source=$work/native-source
"$bb" mkdir -m 700 "$native_source"
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$ram"
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$native_source"
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

observe_native_root() {
	observer_root=$1 observer_ledger=$2
	[ "$#" -eq 3 ] && [ "$3" = forwarded ] || return 129
	"$bb" test -d /proc/self/fd/6 && "$bb" test "$observer_root" -ef /proc/self/fd/6 || return 129
	for observer_fd in 7 8 9; do
		"$bb" test "$guard/fd$observer_fd" -ef "/proc/self/fd/$observer_fd" || return 129
	done
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
	[ "$observer_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'4' ] || return 129
	observe_native_data "$observer_root" || return 129
	# Proof-only attempted writes demonstrate the admitted RO views/fallbacks;
	# no mount commands, descendants or descriptors are retained by this observer.
	for observer_name in bin sbin lib usr opt tmp; do
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
printf 'nine\n' >"$guard/fd9"
exec 6<"$guard/fd6" 7<"$guard/fd7" 8<"$guard/fd8" 9<"$guard/fd9"
status=0
cfmgr_isolation_native_data_root_test "$ram" "$guard" "$tools" /proc/self/mountinfo /proc/self/fdinfo/6 \
	"$native_source" "$data_source" "$repo/modules/lib/mountinfo.awk" "$repo/modules/lib/storageinfo.awk" observe_native_root forwarded || status=$?
[ "$status" -eq 7 ] || fail "ordinary callback status/teardown ($status)"
if IFS= read -r fd6 <&6 && IFS= read -r fd7 <&7 && IFS= read -r fd8 <&8 && IFS= read -r fd9 <&9; then :; else
	fail 'caller descriptors'
fi
[ "$fd6:$fd7:$fd8:$fd9" = six:seven:eight:nine ] || fail 'restored caller descriptors'
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
while [ "$query" -lt 56 ]; do
	[ -f "$guard/execution/query-$query" ] || fail 'missing unique query'
	query=$((query + 1))
done
[ ! -e "$guard/execution/query-56" ] || fail 'unexpected query count'
# Assert no surviving execution-root or native child mounts before cleanup;
# namespace destruction alone is never accepted as successful teardown.
tree_clean() {
	_cfmgr_io_mount_capture "$2" "$repo/modules/lib/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ]
}
cfmgr_io_test "$ram" "$tools" workspace tree_clean "$ram" || fail 'retained execution mount'
cfmgr_io_test "$ram" "$tools" workspace tree_clean "$native_source" || fail 'retained source child mount'
"$bb" rm -rf "$guard"
"$bb" umount -n "$native_source" || fail 'source mount cleanup'
"$bb" umount -n "$ram" || fail 'RAM mount cleanup'
printf 'native readonly views/data, actual root lease and checked reverse teardown passed\n'
