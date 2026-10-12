#!/bin/sh
# Real ext4 mount/descriptor proof for tests/test_storage_mounts.py.
# This script runs as root only inside a private mount namespace created by the
# Python test. All images, mountpoints, and cleanup are confined to workdir.

set -eu

if [ "$#" -ne 7 ]; then
	printf 'storage mount fixture: expected seven arguments\n' >&2
	exit 2
fi

root=$1
case_name=$2
workdir=$3
readlink=$4
awk=$5
parent_namespace=$6
owner_uid=$7
case "$case_name" in
valid | alias_substitution | lazy_replacement | bind_identity | ro_noexec) ;;
*)
	printf 'storage mount fixture: invalid case\n' >&2
	exit 2
	;;
esac

fail() {
	printf 'storage mount fixture: %s\n' "$*" >&2
	exit 1
}

if [ ! -d "$workdir" ] || [ -L "$workdir" ]; then
	fail 'workdir must be a real directory'
fi
if [ "$("$readlink" -f "$workdir")" != "$workdir" ]; then
	fail 'workdir must be canonical'
fi
if [ "$(stat -c %u "$workdir")" != "$owner_uid" ]; then
	fail 'workdir owner changed'
fi
if [ "$(stat -c %a "$workdir")" != 700 ]; then
	fail 'workdir must have mode 700'
fi
if [ "$(id -u)" != 0 ]; then
	fail 'fixture requires its explicit privileged test invocation'
fi
if [ ! -f "$root/modules/lib/storage.sh" ] || [ ! -f "$root/modules/lib/mountinfo.awk" ]; then
	fail 'repository storage library is missing'
fi
if [ ! -x "$readlink" ] || [ ! -x "$awk" ]; then
	fail 'selected native tools are unavailable'
fi
if [ "$("$readlink" /proc/self/ns/mnt)" = "$parent_namespace" ]; then
	fail 'fixture is not in a distinct mount namespace'
fi

fixture=$workdir/cfmgr-storage-mount-fixture
if [ -e "$fixture" ] || [ -L "$fixture" ]; then
	fail 'owned fixture path already exists'
fi
mount_dir=$fixture/volume
bind_dir=$fixture/bind
alias=$fixture/opt
image=$fixture/volume.ext4
replacement_image=$fixture/replacement.ext4
device=
replacement_device=
library_loaded=0
cleanup_status=0

cleanup_issue() {
	printf 'storage mount fixture cleanup: %s\n' "$*" >&2
	cleanup_status=1
}

release_loop() {
	loop_device=$1
	loop_image=$2
	[ -n "$loop_device" ] || return 0
	associated=$(losetup --list --noheadings --raw --output NAME --associated "$loop_image") || {
		cleanup_issue "could not verify loop association for $loop_image"
		return
	}
	[ "$associated" = "$loop_device" ] || {
		cleanup_issue "loop association changed for $loop_image"
		return
	}
	losetup -d "$loop_device" || {
		cleanup_issue "could not detach owned loop device $loop_device"
		return
	}
	associated=$(losetup --list --noheadings --raw --output NAME --associated "$loop_image") || {
		cleanup_issue "could not verify loop release for $loop_image"
		return
	}
	[ -z "$associated" ] || cleanup_issue "owned loop remains attached to $loop_image"
}

cleanup() {
	original_status=$?
	trap - EXIT HUP INT TERM
	if [ "$library_loaded" -eq 1 ]; then
		cfmgr_storage_release >/dev/null 2>&1 || :
	fi
	if mountpoint -q "$bind_dir"; then
		umount "$bind_dir" || cleanup_issue "could not unmount $bind_dir"
	fi
	if mountpoint -q "$mount_dir"; then
		umount "$mount_dir" || cleanup_issue "could not unmount $mount_dir"
	fi
	if mountpoint -q "$bind_dir" || mountpoint -q "$mount_dir"; then
		cleanup_issue 'fixture mount remains; preserving owned evidence'
	fi
	if [ "$cleanup_status" -eq 0 ]; then
		release_loop "$replacement_device" "$replacement_image"
		release_loop "$device" "$image"
	fi
	if [ "$cleanup_status" -eq 0 ]; then
		rm -rf "$fixture" || cleanup_issue 'could not remove owned fixture files'
	fi
	if [ "$cleanup_status" -ne 0 ]; then
		printf 'storage mount fixture: preserving owned evidence at %s\n' "$fixture" >&2
		exit 1
	fi
	if [ -e "$fixture" ] || [ -L "$fixture" ]; then
		printf 'storage mount fixture: owned evidence remains at %s\n' "$fixture" >&2
		exit 1
	fi
	exit "$original_status"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

mkdir -p "$mount_dir" "$bind_dir"
truncate -s 32M "$image"
mkfs.ext4 -q -F -U random "$image"
device=$(losetup --find --show "$image") || fail 'could not allocate volume loop device'
mount -t ext4 "$device" "$mount_dir" || fail 'could not mount ext4 volume'
mkdir "$mount_dir/entware"
printf 'original volume data\n' >"$mount_dir/entware/marker"
ln -s "$mount_dir/entware" "$alias"
blkid "$device" >"$fixture/blkid-main"
main_uuid=$(blkid -s UUID -o value "$device")
[ -n "$main_uuid" ] || fail 'ext4 UUID was not observed'

if [ "$case_name" = lazy_replacement ]; then
	truncate -s 32M "$replacement_image"
	mkfs.ext4 -q -F -U random "$replacement_image"
	replacement_device=$(losetup --find --show "$replacement_image") ||
		fail 'could not allocate replacement loop device'
	blkid "$replacement_device" >"$fixture/blkid-replacement"
	replacement_uuid=$(blkid -s UUID -o value "$replacement_device")
	if [ -z "$replacement_uuid" ] || [ "$replacement_uuid" = "$main_uuid" ]; then
		fail 'replacement ext4 UUID was not distinct'
	fi
fi

# shellcheck disable=SC1091 # Source is the repository library selected by root.
. "$root/modules/lib/storage.sh"
library_loaded=1

pin() {
	cfmgr_storage_pin "$alias" "$readlink" "$awk" \
		"$root/modules/lib/mountinfo.awk" /proc/self
}

assert_released() {
	if (: <&6) 2>/dev/null; then
		fail 'descriptor 6 remained open after release'
	fi
	if (: <&7) 2>/dev/null; then
		fail 'descriptor 7 remained open after release'
	fi
}

# Globals below are outputs from cfmgr_storage_pin in the sourced library.
# shellcheck disable=SC2154
case "$case_name" in
valid)
	pin || fail 'valid ext4 attachment was rejected'
	[ "$cfmgr_storage_relative" = entware ] || fail 'wrong volume-relative path'
	[ "$cfmgr_storage_fsroot" = / ] || fail 'wrong filesystem root'
	# shellcheck disable=SC3013 # Required Linux/BusyBox fixture verifies production storage.sh descriptor -ef behavior.
	[ "$cfmgr_storage_mount" -ef /proc/self/fd/6 ] || fail 'mount descriptor identity did not match'
	# shellcheck disable=SC3013 # Required Linux/BusyBox fixture verifies production storage.sh descriptor -ef behavior.
	[ "$cfmgr_storage_opt" -ef /proc/self/fd/7 ] || fail 'opt descriptor identity did not match'
	cfmgr_storage_attached || fail 'valid pinned attachment did not remain attached'
	cfmgr_storage_uuid "$fixture/blkid-main" || fail 'valid ext4 UUID was rejected'
	[ "$cfmgr_storage_uuid_value" = "$main_uuid" ] || fail 'observed UUID differed from ext4 UUID'
	[ "$(cat "$mount_dir/entware/marker")" = 'original volume data' ] || fail 'original data changed'
	cfmgr_storage_release
	assert_released
	printf 'PASS: valid ext4 attachment, UUID, descriptor identity, and release\n'
	;;
alias_substitution)
	pin || fail 'valid starting attachment was rejected'
	mkdir "$fixture/substitute"
	printf 'substitute data\n' >"$fixture/substitute/marker"
	rm "$alias"
	ln -s "$fixture/substitute" "$alias"
	if cfmgr_storage_attached; then
		fail 'substituted alias remained attached'
	fi
	[ "$(cat "$mount_dir/entware/marker")" = 'original volume data' ] || fail 'original data changed'
	[ "$(cat "$fixture/substitute/marker")" = 'substitute data' ] || fail 'substitute data changed'
	cfmgr_storage_release
	assert_released
	printf 'PASS: alias substitution denied without changing either data set\n'
	;;
lazy_replacement)
	pin || fail 'valid starting attachment was rejected'
	cfmgr_storage_uuid "$fixture/blkid-main" || fail 'original UUID was rejected'
	original_uuid=$cfmgr_storage_uuid_value
	umount -l "$mount_dir" || fail 'could not lazily detach original volume'
	cfmgr_storage_attached && fail 'lazy-detached leftover mountpoint remained attached'
	[ "$(cat /proc/self/fd/7/marker)" = 'original volume data' ] || fail 'retained descriptor lost original data'
	[ ! -e "$mount_dir/entware/marker" ] || fail 'lazy detach exposed original data at the bare mountpoint'
	mount -t ext4 "$replacement_device" "$mount_dir" ||
		fail 'could not mount replacement volume at the original path'
	mkdir "$mount_dir/entware"
	printf 'replacement volume data\n' >"$mount_dir/entware/marker"
	if cfmgr_storage_attached; then
		fail 'lazy-detached descriptor accepted a replacement mount'
	fi
	if cfmgr_storage_uuid "$fixture/blkid-replacement"; then
		fail 'replacement mount UUID was accepted through the pinned source'
	fi
	[ -z "${cfmgr_storage_uuid_value:-}" ] || fail 'replacement UUID was adopted'
	[ "$(cat "$mount_dir/entware/marker")" = 'replacement volume data' ] || fail 'replacement data changed'
	[ "$replacement_uuid" != "$original_uuid" ] || fail 'replacement volume reused the original UUID'
	cfmgr_storage_release
	assert_released
	printf 'PASS: lazy detach denied replacement mount with a different UUID\n'
	;;
bind_identity)
	mount --bind "$mount_dir/entware" "$bind_dir" || fail 'could not create Entware bind mount'
	rm "$alias"
	ln -s "$bind_dir" "$alias"
	pin || fail 'valid bind-mounted attachment was rejected'
	[ "$cfmgr_storage_mount" = "$bind_dir" ] || fail 'bind mountpoint was not retained'
	[ "$cfmgr_storage_fsroot" = /entware ] || fail 'bind filesystem root was not retained'
	[ "$cfmgr_storage_relative" = . ] || fail 'bind mount relative path was not retained'
	# shellcheck disable=SC3013 # Required Linux/BusyBox fixture verifies production storage.sh descriptor -ef behavior.
	[ "$cfmgr_storage_mount" -ef /proc/self/fd/6 ] || fail 'bind mount descriptor identity did not match'
	cfmgr_storage_attached || fail 'valid bind-mounted attachment did not remain attached'
	cfmgr_storage_uuid "$fixture/blkid-main" || fail 'bind mount volume UUID was rejected'
	[ "$cfmgr_storage_uuid_value" = "$main_uuid" ] || fail 'bind mount UUID differed from its volume UUID'
	cfmgr_storage_release
	assert_released
	printf 'PASS: bind mount preserved filesystem-root and volume-relative identity\n'
	;;
ro_noexec)
	mount -o remount,ro "$mount_dir" || fail 'could not remount ext4 volume read-only'
	if pin; then
		cfmgr_storage_release
		fail 'read-only ext4 volume was admitted'
	fi
	assert_released
	mount -o remount,rw "$mount_dir" || fail 'could not restore ext4 volume read-write'
	mount --bind "$mount_dir" "$bind_dir" || fail 'could not create noexec bind mount'
	mount -o remount,bind,noexec "$bind_dir" || fail 'could not mark bind mount noexec'
	rm "$alias"
	ln -s "$bind_dir" "$alias"
	if pin; then
		cfmgr_storage_release
		fail 'noexec ext4 bind mount was admitted'
	fi
	assert_released
	printf 'PASS: read-only and noexec ext4 attachments were denied\n'
	;;
*) fail "unknown case: $case_name" ;;
esac
