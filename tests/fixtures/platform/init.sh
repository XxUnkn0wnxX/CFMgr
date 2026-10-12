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
cfmgr_install_metadata() {
	cfmgr_install_listing=$(/bin/ls -ldn "$1") || return 1
	printf '%s\n' "$cfmgr_install_listing" | /usr/bin/awk -v mode="$2" '
		{ n++; if (NF < 9 || $1 != mode || $3 != "0" || $4 != "0") bad=1 }
		END { exit (n == 1 && !bad ? 0 : 1) }'
}
mount -t proc proc /proc || fail proc
mount -t sysfs sysfs /sys || fail sysfs
mkdir -p /tmp || fail temp-root
read -r expected_kernel expected_busybox expected_version </cfmgr/identity
[ "$(uname -r)" = "$expected_kernel" ] || fail kernel-version
busybox_banner=$(/bin/busybox 2>&1)
case $busybox_banner in
"BusyBox v$expected_version "*) ;;
*) fail busybox-version ;;
esac
printf '%s\n' "CFMGR_KERNEL=$expected_kernel" "CFMGR_BUSYBOX=$expected_busybox:$expected_version"
mount -t ext4 /dev/vda /mnt/cfmgr-scratch || fail ext4
if [ ! -d /mnt/cfmgr-scratch/feeds ] || [ ! -d /mnt/cfmgr-scratch/tmp ]; then fail dirty-volume; fi
# Definition-only sourcing must not create scratch state.
set -- --define
# shellcheck source=/dev/null
. /cfmgr/probe.sh || fail definitions
# shellcheck disable=SC2012 # The private fixture directory has bounded test-owned names.
if [ -n "$(ls -A /mnt/cfmgr-scratch/tmp)" ]; then fail source-mutation; fi
/bin/sh /cfmgr/probe.sh --run /mnt/cfmgr-scratch/tmp || fail native-probe
if [ ! -d /mnt/cfmgr-scratch/tmp ] || [ -n "$(ls -A /mnt/cfmgr-scratch/tmp)" ]; then
	fail probe-cleanup
fi
exec 3</dev/null
fsync_diagnostic=$(/bin/fsync /proc/self/fd/3 2>&1)
fsync_result=$?
if [ "$fsync_result" != 0 ] || [ -z "$fsync_diagnostic" ]; then
	fail native-error-fixture
fi
case $fsync_diagnostic in
"fsync: /proc/self/fd/3: "*) ;;
*) fail native-error-diagnostic ;;
esac
if cfmgr_storage_flush_fd /bin/fsync; then
	fail accepted-zero-exit-diagnostic
fi
exec 3<&-
printf '%s\n' 'CFMGR_STORAGE=OK'
feed_total=$(wc -l </cfmgr/feeds)
feed_index=0
# This exact stub emulates the Merlin NVRAM setting that allows custom JFFS
# scripts. The guest validates real JFFS2 and filesystem behavior, not NVRAM.
[ "$(/bin/nvram get jffs2_scripts)" = 1 ] || fail scripts-setting
mount -t jffs2 /dev/mtdblock0 /jffs || fail jffs2-mount
/bin/mkdir -m 755 /jffs/scripts /jffs/addons || fail jffs2-layout
while read -r feed architecture jq_version coreutils_version flock_version dig_version; do
	/bin/mkdir -p "/mnt/cfmgr-scratch/feeds/$feed" || fail feed-stage-dir
	/bin/cp -R "/feeds/$feed/opt" "/mnt/cfmgr-scratch/feeds/$feed/" || fail feed-stage-copy
	[ -x "/mnt/cfmgr-scratch/feeds/$feed/opt/bin/jq" ] || fail feed-empty
	/bin/chmod 755 "/mnt/cfmgr-scratch/feeds/$feed/opt" || fail feed-mode
	mount -o bind "/mnt/cfmgr-scratch/feeds/$feed/opt" /opt || fail feed-mount
	[ "$(/opt/bin/jq --version)" = "jq-$jq_version" ] || fail jq-version
	if [ ! -L /opt/bin/timeout ] || [ "$(readlink /opt/bin/timeout)" != ../libexec/timeout-coreutils ]; then fail timeout-alternative; fi
	if [ ! -L /opt/bin/sha256sum ] || [ "$(readlink /opt/bin/sha256sum)" != ../libexec/sha256sum-coreutils ]; then fail sha-alternative; fi
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
	/opt/bin/util-linux-flock -n /mnt/cfmgr-scratch/tmp/owned-lock /bin/sh -c ':' || fail flock
	rm /mnt/cfmgr-scratch/tmp/owned-lock || fail flock-cleanup
	[ "$(/opt/bin/dig -v)" = "DiG $dig_version" ] || fail dig-version
	unset LD_LIBRARY_PATH
	if ! install_output=$(/bin/sh /cfmgr/package/cfmgr.sh --install 2>&1); then
		printf '%s\n' "$install_output"
		fail install-command
	fi
	case $install_output in *'CFMgr fresh installation complete.'*) ;; *) fail install-message ;; esac
	[ "$(/jffs/scripts/cfmgr.sh --version)" = 'CFMgr 0.1.0 (development placeholder)' ] || fail installed-version
	[ "$(
		IFS= read -r cfmgr_setup_state </jffs/addons/CFMgr.d/setup-state
		printf '%s' "$cfmgr_setup_state"
	)" = 'CFMGR-SETUP 1 0.1.0 complete' ] || fail install-state
	[ "$(/opt/bin/jq -er --arg feed "$feed" '.schema == 1 and .generation == 1 and .manager.check_updates == true and .manager.auto_update == false and .ddns.configured == false and .ddns.enabled == false and .ip_sync.configured == false and .ip_sync.enabled == false and .cloudflared.configured == false and .cloudflared.enabled == false and .cloudflared.installed == false and .cloudflared.maintenance_enabled == false and .cloudflared.token == null and .logging.ddns.enabled == false and .logging.ip_sync.enabled == false and .logging.cloudflared.enabled == false and .backup.destination == null and .storage.entware.filesystem == "ext4" and .storage.entware.root == ("/feeds/" + $feed + "/opt") and .storage.entware.relative == "." and (.storage.entware.uuid | test("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"))' /jffs/addons/CFMgr.d/config)" = true ] || fail install-defaults
	cfmgr_install_metadata /jffs/addons/CFMgr.d/config -rw------- || fail install-config-mode
	if [ ! -x /jffs/scripts/cfmgr.sh ] || ! cfmgr_install_metadata /jffs/scripts/cfmgr.sh -rwxr-xr-x; then
		fail install-entry-mode
	fi
	# shellcheck disable=SC2012 # The script directory starts empty and is fixture-owned.
	[ "$(ls -A /jffs/scripts)" = cfmgr.sh ] || fail install-feature-hooks
	if [ -e /opt/etc/cloudflared ] || [ -e /opt/var/log/cloudflared.log ]; then fail install-feature-state; fi
	/bin/cp /jffs/addons/CFMgr.d/config /cfmgr/config.expected || fail config-copy
	/opt/libexec/sha256sum-coreutils -c /cfmgr/installed.sha256 || fail install-payload
	if /bin/sh /cfmgr/package/cfmgr.sh --install; then fail reinstall-accepted; fi
	/usr/bin/cmp /cfmgr/config.expected /jffs/addons/CFMgr.d/config || fail reinstall-mutated-config
	/bin/printf 'invalid config\n' >/jffs/addons/CFMgr.d/config || fail corrupt-config-fixture
	/bin/cp /jffs/addons/CFMgr.d/config /cfmgr/config.corrupt || fail corrupt-config-copy
	if /bin/sh /cfmgr/package/cfmgr.sh --install; then fail corrupt-config-accepted; fi
	/usr/bin/cmp /cfmgr/config.corrupt /jffs/addons/CFMgr.d/config || fail corrupt-config-replaced
	/bin/cp /cfmgr/config.expected /jffs/addons/CFMgr.d/config || fail config-restore
	/bin/printf 'CFMGR-SETUP 1 0.1.0 incomplete\n' >/jffs/addons/CFMgr.d/setup-state || fail guard-fixture
	/bin/cp /jffs/addons/CFMgr.d/setup-state /cfmgr/state.incomplete || fail guard-copy
	if /bin/sh /cfmgr/package/cfmgr.sh --install; then fail incomplete-state-accepted; fi
	/usr/bin/cmp /cfmgr/config.expected /jffs/addons/CFMgr.d/config || fail guard-mutated-config
	/usr/bin/cmp /cfmgr/state.incomplete /jffs/addons/CFMgr.d/setup-state || fail guard-replaced
	umount /opt || fail feed-unmount
	[ -z "$(ls -A /mnt/cfmgr-scratch/tmp)" ] || fail dependency-cleanup
	printf '%s\n' "CFMGR_FEED=$feed:$architecture:OK" "CFMGR_INSTALL=$feed:OK"
	feed_index=$((feed_index + 1))
	if [ "$feed_index" -lt "$feed_total" ]; then
		# Clear only the exact package/config generation created above. Require
		# both fixture-owned roots empty before treating the next feed as fresh.
		/bin/rm -rf /jffs/addons/CFMgr.d || fail install-reset-addons
		/bin/rm -f /jffs/scripts/cfmgr.sh || fail install-reset-entry
		/bin/rm -rf "/mnt/cfmgr-scratch/feeds/$feed" || fail feed-reset
		# shellcheck disable=SC2012 # These fixture-owned reset roots have safe names.
		[ -z "$(ls -A /jffs/scripts)" ] || fail install-reset-scripts-dirty
		[ -z "$(ls -A /jffs/addons)" ] || fail install-reset-addons-dirty
		[ -z "$(ls -A /mnt/cfmgr-scratch/feeds)" ] || fail feed-reset-dirty
	fi
done </cfmgr/feeds
umount /jffs || fail jffs2-unmount
printf '%s\n' "CFMGR_PLATFORM_OK_v1:$expected_kernel:$expected_busybox"
poweroff -f
