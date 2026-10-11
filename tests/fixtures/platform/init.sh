#!/bin/sh
# Disposable QEMU init only. Never run this fixture on a router or workstation.
PATH=/sbin:/bin:/usr/sbin:/usr/bin
LC_ALL=C
export PATH LC_ALL
[ "$$" -eq 1 ] || exit 2
mount -t devtmpfs devtmpfs /dev || exit 1
exec </dev/console >/dev/console 2>&1

fail() {
	printf '%s\n' "CFMGR_PLATFORM_FAIL:$1"
	poweroff -f
	exit 1
}
mount -t proc proc /proc || fail proc
mount -t sysfs sysfs /sys || fail sysfs
read -r expected_kernel expected_busybox expected_version </cfmgr/identity
[ "$(uname -r)" = "$expected_kernel" ] || fail kernel-version
busybox_banner=$(/bin/busybox 2>&1)
case $busybox_banner in
"BusyBox v$expected_version "*) ;;
*) fail busybox-version ;;
esac
printf '%s\n' "CFMGR_KERNEL=$expected_kernel" "CFMGR_BUSYBOX=$expected_busybox:$expected_version"
mount -t ext4 /dev/vda /tmp/mnt/MERLIN || fail ext4
[ "$(ls -A /mnt/MERLIN)" = lost+found ] || fail dirty-volume
# Definition-only sourcing must not create scratch state.
set -- --define
# shellcheck source=/dev/null
. /cfmgr/probe.sh || fail definitions
[ "$(ls -A /mnt/MERLIN)" = lost+found ] || fail source-mutation
/bin/sh /cfmgr/probe.sh --run /mnt/MERLIN/tmp || fail native-probe
[ -d /mnt/MERLIN/tmp ] && [ -z "$(ls -A /mnt/MERLIN/tmp)" ] || fail probe-cleanup
exec 3</dev/null
fsync_diagnostic=$(/bin/fsync /proc/self/fd/3 2>&1)
fsync_result=$?
[ "$fsync_result" = 0 ] && [ -n "$fsync_diagnostic" ] || fail native-error-fixture
case $fsync_diagnostic in
"/proc/self/fd/3: "*) ;;
*) fail native-error-diagnostic ;;
esac
if cfmgr_storage_flush_fd /bin/fsync; then
	fail accepted-zero-exit-diagnostic
fi
exec 3<&-
printf '%s\n' 'CFMGR_STORAGE=OK'
while read -r feed architecture jq_version coreutils_version flock_version dig_version; do
	mount -o bind "/feeds/$feed/opt" /opt || fail feed-mount
	LD_LIBRARY_PATH=/opt/lib
	export LD_LIBRARY_PATH
	[ "$(/opt/bin/jq --version)" = "jq-$jq_version" ] || fail jq-version
	printf '%s\n' '{"values":[1,2]}' | /opt/bin/jq -e '.values[1] == 2' || fail jq-valid
	if printf '%s\n' '{broken' | /opt/bin/jq -e '.'; then
		fail jq-invalid
	fi
	for command in timeout sha256sum; do
		version_output=$(/opt/libexec/"$command"-coreutils --version) || fail coreutils-version
		read -r first_line <<EOV
$version_output
EOV
		[ "$first_line" = "$command (GNU coreutils) $coreutils_version" ] || fail coreutils-version
	done
	/opt/libexec/timeout-coreutils 0.1 /bin/sh -c 'sleep 1'
	[ "$?" = 124 ] || fail timeout-expiry
	printf '%s\n' 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  /cfmgr/sha-input' |
		/opt/libexec/sha256sum-coreutils -c - || fail sha-known-bytes
	[ "$(/opt/bin/util-linux-flock --version)" = "util-linux-flock from util-linux $flock_version" ] || fail flock-version
	/opt/bin/util-linux-flock -n /mnt/MERLIN/tmp/owned-lock /bin/sh -c ':' || fail flock
	rm /mnt/MERLIN/tmp/owned-lock || fail flock-cleanup
	[ "$(/opt/bin/dig -v)" = "DiG $dig_version" ] || fail dig-version
	unset LD_LIBRARY_PATH
	umount /opt || fail feed-unmount
	[ -z "$(ls -A /mnt/MERLIN/tmp)" ] || fail dependency-cleanup
	printf '%s\n' "CFMGR_FEED=$feed:$architecture:OK"
done </cfmgr/feeds
printf '%s\n' "CFMGR_PLATFORM_OK_v1:$expected_kernel:$expected_busybox"
poweroff -f
