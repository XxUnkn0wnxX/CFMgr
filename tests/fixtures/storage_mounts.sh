#!/bin/sh
# Real ext4 mount/descriptor proof for tests/test_storage_mounts.py.
# This script runs as root only inside a private mount namespace created by the
# Python test. All images, mountpoints, and cleanup are confined to workdir.

set -eu

if [ "$#" -ne 7 ] && [ "$#" -ne 8 ] && [ "$#" -ne 10 ] && [ "$#" -ne 11 ]; then
	printf 'storage mount fixture: expected seven arguments (plus selected BusyBox for view cases)\n' >&2
	exit 2
fi

root=$1
case_name=$2
workdir=$3
readlink=$4
awk=$5
parent_namespace=$6
owner_uid=$7
view_busybox=${8:-}
dependency_pid_namespace=${9:-}
# shellcheck disable=SC2034 # Dependency extension consumes this explicit fixture path.
dependency_process=${10:-}
# shellcheck disable=SC2034 # Installer fixture extension consumes this private adapter.
dependency_install_adapter=${11:-}
case "$case_name" in
	valid | alias_substitution | lazy_replacement | bind_identity | ro_noexec | backup_folder | backup_replacement | archive_source | view_compat | view_detach | view_cleanup | dependency_repair | dependency_update_failure | dependency_retry | dependency_daemon | dependency_threads | dependency_mixed | dependency_loss | dependency_installer) ;;
	*)
		printf 'storage mount fixture: invalid case\n' >&2
		exit 2
		;;
esac

fail() {
	printf 'storage mount fixture: %s\n' "$*" >&2
	case $case_name in dependency_*)
		printf 'dependency phase=%s native-mode=%s state=%s unresolved=%s claimed=%s\n' \
			"${cfmgr_dependencies_phase:-unset}" "${cfmgr_dependencies_native_mode:-unset}" "${cfmgr_dependencies_state:-unset}" \
			"${cfmgr_dependencies_native_unresolved:-0}" "${cfmgr_dependencies_claimed:-0}" >&2
		printf 'probe mode=%s status=%s reason=%s exit=%s pid=%s start=%s\n' \
			"${cfmgr_probe_mode:-unset}" "${cfmgr_probe_status:-unset}" "${cfmgr_probe_reason:-unset}" \
			"${cfmgr_probe_exit:-unset}" "${cfmgr_probe_pid:-unset}" "${cfmgr_probe_start:-unset}" >&2
		# Failure diagnostics use host setup tooling only, bounded to 512 bytes.
		# Never follow a symlink or read outside our explicitly owned RAM context.
		if [ -n "${cfmgr_install_context:-}" ] && [ -d "$cfmgr_install_context" ] && [ ! -L "$cfmgr_install_context" ]; then
			case ${cfmgr_probe_stderr:-} in "$cfmgr_install_context"/*.err)
				if [ -f "$cfmgr_probe_stderr" ] && [ ! -L "$cfmgr_probe_stderr" ] && [ -s "$cfmgr_probe_stderr" ]; then
					printf 'owned probe stderr (first 512 bytes):\n' >&2
					/usr/bin/head -c 512 "$cfmgr_probe_stderr" >&2
					printf '\n' >&2
				fi
				;;
			esac
		fi
		;;
	esac
	if [ "${view_loaded:-0}" = 1 ]; then
		printf 'view state=%s pending=%s sequence=%s keeper=%s last=%s\n' \
			"${cfmgr_view_state:-unset}" "${cfmgr_view_pending:-none}" "${cfmgr_view_sequence:-unset}" \
			"${cfmgr_keeper_state:-unset}" "${view_last_operation:-unset}" >&2
	fi
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
if [ ! -f "$root/modules/lib/storage.sh" ] || [ ! -f "$root/modules/backup.sh" ]; then
	fail 'repository storage or backup category is missing'
fi
# shellcheck disable=SC1091 # Inert category needed by every later cleanup path.
. "$root/modules/lib/storage.sh" || fail 'storage category could not load'
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
view_loaded=0
view_native_root=
view_ram=
view_observer=

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

# shellcheck disable=SC2154 # Fixed keeper identity utility exports these fields.
cleanup() {
	original_status=$?
	trap - EXIT HUP INT TERM
	if [ -n "$view_observer" ]; then
		kill -TERM "$view_observer" 2> /dev/null || :
		wait "$view_observer" 2> /dev/null || :
		view_observer=
	fi
	if [ "$view_loaded" -eq 1 ]; then
		cfmgr_view_test_quiet=1
		case ${cfmgr_view_state:-invalid} in building | ready | retained)
			if ! cfmgr_execution_view_release; then
				cleanup_issue 'guarded view could not be normally released'
				# Test owns this exact fixed keeper, and never launches package writers.
				# Failure fallback is recorded as failure, never product cleanup proof.
				if [ -n "${cfmgr_keeper_pid:-}" ]; then
					if cfmgr_prerequisites_identity "$cfmgr_keeper_pid"; then
						if [ "$cfmgr_identity_start" = "$cfmgr_keeper_start" ] && [ "$cfmgr_identity_parent" = "$cfmgr_keeper_owner" ]; then
							kill -KILL "$cfmgr_keeper_pid" 2> /dev/null || :
						else cleanup_issue 'keeper identity changed; refusing failure signal'; fi
					fi
					wait "$cfmgr_keeper_pid" 2> /dev/null || :
					cfmgr_keeper_state='fixture-reaped'
				fi
				exec 3<&-
				# Independent isolated-fixture authority only, with no live writers.
				cfmgr_view_pin_state=retired cfmgr_view_pending=''
				cfmgr_execution_view_release || cleanup_issue 'isolated view mounts remain after keeper reap'
			fi
			;;
		esac
		# Startup may have left an exact keeper before a usable view state exists.
		case ${cfmgr_keeper_state:-invalid} in active | retained)
			if [ -n "${cfmgr_keeper_pid:-}" ]; then
				cleanup_issue 'startup keeper remained; reaping exact test-owned helper'
				if cfmgr_prerequisites_identity "$cfmgr_keeper_pid"; then
					if [ "$cfmgr_identity_start" = "$cfmgr_keeper_start" ] && [ "$cfmgr_identity_parent" = "$cfmgr_keeper_owner" ]; then
						kill -KILL "$cfmgr_keeper_pid" 2> /dev/null || :
					else cleanup_issue 'startup keeper identity changed; refusing signal'; fi
				fi
				wait "$cfmgr_keeper_pid" 2> /dev/null || :
				exec 3<&-
			fi
			;;
		esac
	fi
	if [ "$library_loaded" -eq 1 ]; then
		if [ "${cfmgr_archive_source_pinned:-0}" = 1 ]; then
			if [ "${cfmgr_probe_status:-}" = unresolved ]; then
				cleanup_issue 'archive child ownership unresolved; retaining source pin'
			else cfmgr_archive_source_release; fi
		fi
		cfmgr_storage_release > /dev/null 2>&1 || :
	fi
	case $case_name in dependency_*)
		# These are this fixture controller's source/context pins. Never close them
		# while product ownership is unresolved; preserve that evidence instead.
		if [ "${cfmgr_dependencies_state:-none}" != retained ] && [ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ]; then
			case ${cfmgr_tasks_state:-none}:${cfmgr_keeper_state:-none} in
				running:* | retained:* | *:active | *:retained) ;;
				*) exec 0<&- 9<&- ;;
			esac
		fi
		;;
	esac
	if [ -n "$view_native_root" ]; then
		for view_fixture_point in "$view_native_root/tmp/mnt/usb/entware/nested" "$view_native_root/tmp/mnt/usb" "$view_native_root/proc" "$view_native_root/dev" "$view_ram"; do
			if mountpoint -q "$view_fixture_point"; then
				umount "$view_fixture_point" || cleanup_issue "could not normally release $view_fixture_point"
			fi
		done
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
	# Never delete through an unexpected/retained mount anywhere in the owned tree.
	if ! "$awk" "$(
		cfmgr_storage_awk_mountinfo
		printf '%s' "$cfmgr_awk_program"
	)" inventory-v1 "$fixture" /proc/self/mountinfo > "$fixture/cleanup.mounts"; then
		cleanup_issue 'could not verify final fixture mount absence'
	elif [ -s "$fixture/cleanup.mounts" ]; then
		cleanup_issue 'unexpected fixture mount remains; preserving owned evidence'
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
trap 'fail "interrupted or watchdog timeout"' HUP INT TERM

mkdir -m 700 "$fixture" || fail 'could not exclusively create private fixture directory'
mkdir -p "$mount_dir" "$bind_dir"
truncate -s 32M "$image"
mkfs.ext4 -q -F -U random "$image"
device=$(losetup --find --show "$image") || fail 'could not allocate volume loop device'
mount -t ext4 "$device" "$mount_dir" || fail 'could not mount ext4 volume'
mkdir "$mount_dir/entware"
printf 'original volume data\n' > "$mount_dir/entware/marker"
ln -s "$mount_dir/entware" "$alias"
blkid "$device" > "$fixture/blkid-main"
main_uuid=$(blkid -s UUID -o value "$device")
[ -n "$main_uuid" ] || fail 'ext4 UUID was not observed'

if [ "$case_name" = lazy_replacement ] || [ "$case_name" = view_detach ] || [ "$case_name" = backup_replacement ]; then
	truncate -s 32M "$replacement_image"
	mkfs.ext4 -q -F -U random "$replacement_image"
	replacement_device=$(losetup --find --show "$replacement_image") ||
		fail 'could not allocate replacement loop device'
	blkid "$replacement_device" > "$fixture/blkid-replacement"
	replacement_uuid=$(blkid -s UUID -o value "$replacement_device")
	if [ -z "$replacement_uuid" ] || [ "$replacement_uuid" = "$main_uuid" ]; then
		fail 'replacement ext4 UUID was not distinct'
	fi
fi

# shellcheck disable=SC1091 # Source is the repository library selected by root.
. "$root/modules/backup.sh"
library_loaded=1

pin() {
	cfmgr_storage_pin "$alias" "$readlink" "$awk" \
		"$root/modules/lib/storage.sh" /proc/self
}

assert_released() {
	if (: <&6) 2> /dev/null; then
		fail 'descriptor 6 remained open after release'
	fi
	if (: <&7) 2> /dev/null; then
		fail 'descriptor 7 remained open after release'
	fi
}

# Execution-view cases reuse this exact private namespace/ext4 image/cleanup.
# Native operations below use the selected static vendor BusyBox applets. Host
# tools above provide privileged fixture setup and the simulated external USB
# detach only; they are not the production native-operation supervisor.
# shellcheck disable=SC2154 # Imported view library supplies context/root state.
view_action() {
	view_action_mode=$1
	shift
	case $view_action_mode in
		inventory) "$view_busybox" awk "$(
			cfmgr_storage_awk_mountinfo
			printf '%s' "$cfmgr_awk_program"
		)" inventory-v1 "$1" /proc/self/mountinfo > "$2" ;;
		list) "$view_busybox" ls -1A "$1" > "$2" ;;
		identity)
			# shellcheck disable=SC2016 # Literal AWK fields are interpreted by AWK.
			"$view_busybox" ls -idn "$1" | "$view_busybox" awk '
			function bit(c,yes) { return index(yes,c)>0 }
			{ if (NR!=1 || NF<5 || length($2)!=10) exit 1
			  p=$2; special=0
			  if (bit(substr(p,4,1),"sS")) special+=4
			  if (bit(substr(p,7,1),"sS")) special+=2
			  if (bit(substr(p,10,1),"tT")) special+=1
			  mode=special ? special "" : ""
			  for (i=2;i<=8;i+=3) mode=mode (4*bit(substr(p,i,1),"r")+2*bit(substr(p,i+1,1),"w")+bit(substr(p,i+2,1),"xst"))
			  printf "%s\t%s\t%s\t%s\n",$1,mode,$4,$5 }
		' > "$2"
			;;
		readlink) "$view_busybox" readlink "$1" > "$2" ;;
		mkdir) "$view_busybox" mkdir -m "$2" "$1" ;;
		file) (
			umask 077
			set -C
			: > "$1"
		) ;;
		link) "$view_busybox" ln -s -- "$1" "$2" ;;
		chmod) "$view_busybox" chmod "$2" "$1" ;;
		copy) "$view_busybox" cp "$1" "$2" ;;
		root) "$view_busybox" mount -t tmpfs -o size=8m,mode=700 tmpfs "$1" ;;
		guard-root) "$view_busybox" mount -t tmpfs -o size=64k,mode=700 tmpfs "$1" ;;
		bind4) "$view_busybox" mount -o bind /proc/self/fd/4 "$1" ;;
		bind7)
			if [ "$cfmgr_view_test_fault" = partial ]; then
				printf 'bind7\n' > "$cfmgr_view_context/test-bind7-fault" || return 2
				return 1
			fi
			"$view_busybox" mount -o bind /proc/self/fd/7 "$1"
			;;
		private) "$view_busybox" mount -o make-private "$1" ;;
		unbindable) "$view_busybox" mount -o make-unbindable "$1" ;;
		seal) "$view_busybox" mount -o remount,ro "$1" ;;
		unmount) "$view_busybox" umount "$1" ;;
		awk) cfmgr_execution_view_awk "$@" ;;
		*) return 2 ;;
	esac
}

view_native() {
	view_last_operation="$1 ${2:-}"
	# Bounded foreground view commands; layered dependency cases use this only for
	# view construction/release while retaining real mounts and other callbacks.
	if (
		ulimit -f 4096
		view_action "$@"
	) > "$cfmgr_view_context/native.out" 2> "$cfmgr_view_context/native.err"; then
		[ ! -s "$cfmgr_view_context/native.out" ] && [ ! -s "$cfmgr_view_context/native.err" ] || return 1
		return 0
	else return $?; fi
}

cfmgr_execution_view_native() { view_native "$@"; }

# Fixed test adapter only: production callbacks require native supervision.
cfmgr_mount_keeper_native() {
	[ "$1" = fifo ] || return 2
	(
		umask 077
		"$2" "$3" p
	)
}

cfmgr_execution_view_keeper() {
	case $1 in
		start)
			mkdir -m 700 "$2/keeper" || return 1
			cfmgr_mount_keeper_start "$2/keeper" "$view_ram/ash" "$root/modules/helpers/worker.sh" \
				"$root/modules/lib/execution.sh" "$view_ram/env" "$view_ram/mknod" "$view_ram/awk" "$view_ram/usleep"
			;;
		retain) cfmgr_mount_keeper_retain "$2" ;;
		check) cfmgr_mount_keeper_check "$2" "$3" ;;
		release) cfmgr_mount_keeper_release ;;
		*) return 2 ;;
	esac
}

cfmgr_execution_view_quiescent() {
	# This package never launches package writers. All chroot checks run/reap in
	# foreground. A separate test-owned read-only observer can prove kernel EBUSY.
	[ "$cfmgr_view_test_quiet" = 1 ]
}

view_prepare() {
	case $view_busybox in /*) ;; *) fail 'explicit selected vendor BusyBox is required' ;; esac
	if [ ! -f "$view_busybox" ] || [ ! -x "$view_busybox" ]; then
		fail 'selected vendor BusyBox unavailable'
	fi
	view_version=$("$view_busybox" 2>&1) || :
	case $view_version in *'BusyBox v1.25.1'*) ;; *) fail 'selected BusyBox is not pinned vendor 1.25.1' ;; esac
	view_native_root=$fixture/native
	view_ram=$view_native_root/tmp/private-ram
	view_observer=
	cfmgr_view_test_quiet=1 cfmgr_view_test_fault=clean
	mkdir -m 755 "$view_native_root"
	mkdir -p "$view_native_root/bin" "$view_native_root/dev" "$view_native_root/proc" "$view_native_root/tmp/etc" "$view_native_root/tmp/feed" "$view_native_root/tmp/mnt/usb" "$view_native_root/tmp/foreign"
	mkdir -m 700 "$view_ram"
	mount -t tmpfs -o size=16m,mode=700 tmpfs "$view_ram" || fail 'private RAM context setup failed'
	cp "$view_busybox" "$view_native_root/bin/busybox"
	# This vendor ash uses external test/printf applets, as the router does.
	for view_applet in '[' printf; do
		ln -s busybox "$view_native_root/bin/$view_applet"
	done
	ln -s /tmp/etc "$view_native_root/etc"
	ln -s /tmp/mnt/usb/entware "$view_native_root/opt"
	case $case_name in
		dependency_* | view_cleanup) ;;
		*) printf 'native regular file\n' > "$view_native_root/native-file" ;;
	esac
	printf 'configured file feed\n' > "$view_native_root/tmp/feed/Packages"
	printf 'nameserver 127.0.0.1\n' > "$view_native_root/tmp/etc/resolv.conf"
	mount --bind /dev "$view_native_root/dev"
	mount --bind /proc "$view_native_root/proc"
	mount --bind "$mount_dir" "$view_native_root/tmp/mnt/usb"
	case $case_name in
		dependency_* | view_cleanup) ;;
		*)
			mkdir "$view_native_root/tmp/mnt/usb/entware/nested"
			mount -t tmpfs -o size=64k tmpfs "$view_native_root/tmp/mnt/usb/entware/nested"
			printf 'nested mount data\n' > "$view_native_root/tmp/mnt/usb/entware/nested/marker"
			;;
	esac
	rm "$alias"
	ln -s "$view_native_root/tmp/mnt/usb/entware" "$alias"
	pin || fail 'execution fixture storage pin failed'
	cfmgr_storage_uuid "$fixture/blkid-main" || fail 'execution fixture UUID failed'
	# Native execution helper tool is a symlink invoking the actual vendor awk.
	for view_keeper_applet in ash awk env mknod usleep '[' printf; do
		ln -s "$view_busybox" "$view_ram/$view_keeper_applet"
	done
	# shellcheck disable=SC1091 # Trusted repository source; no import execution.
	. "$root/modules/lib/execution.sh"
	view_loaded=1
	mkdir -m 700 "$view_ram/context"
}

view_create() {
	cfmgr_execution_view_create "$view_native_root" "$view_ram/context" "$view_ram/awk" "$readlink" "$root/modules/lib/storage.sh"
}

# shellcheck disable=SC2154 # Imported view library supplies the actual view root.
view_chroot() {
	"$view_busybox" chroot "$cfmgr_view_root" /bin/busybox sh -c "$1"
}

# Globals below are outputs from cfmgr_storage_pin in the sourced library.
# shellcheck disable=SC2154
case "$case_name" in
	backup_folder | backup_replacement | archive_source)
		# Only the fixed /tmp/mnt prefix is adapted into the owned fixture tree.
		# Production parsing, exact mount snapshots, FD identity, helper, native
		# supervisor and all real mounts remain unchanged. No host /tmp/mnt writes.
		sed "s|in /tmp/mnt/?\*)|in $fixture/?*)|" "$root/modules/lib/storage.sh" > "$fixture/backup-storage.sh"
		# shellcheck disable=SC1091 # Private copy differs only in the fixture root.
		. "$fixture/backup-storage.sh"
		# shellcheck disable=SC1091
		. "$root/modules/lib/execution.sh"
		# shellcheck disable=SC1091
		. "$root/modules/lib/config.sh"
		for backup_applet in sh awk sleep wc; do ln -s "$view_busybox" "$fixture/$backup_applet"; done
		mkdir -m 700 "$fixture/backup-probes"
		mkdir -p "$fixture/backup-source/modules/helpers" "$fixture/backup-source/modules/lib"
		sed "s|/tmp/mnt|$fixture|g" "$root/modules/helpers/worker.sh" > "$fixture/backup-source/modules/helpers/worker.sh"
		chmod 700 "$fixture/backup-source/modules/helpers/worker.sh"
		cp "$root/modules/lib/storage.sh" "$fixture/backup-source/modules/lib/storage.sh"
		cfmgr_store_source=$fixture/backup-source cfmgr_store_context=$fixture/backup-probes
		cfmgr_store_sh=$fixture/sh cfmgr_store_awk=$fixture/awk cfmgr_store_wc=$fixture/wc cfmgr_store_sleep=$fixture/sleep
		cfmgr_store_env=/usr/bin/env cfmgr_store_readlink=$readlink
		cfmgr_store_backup_gate=0 cfmgr_config_lock_fd0=0 cfmgr_probe_serial=0
		cfmgr_store_attachment_ok() { [ "$cfmgr_store_backup_gate" = 0 ] || cfmgr_backup_attached; }
		cfmgr_prerequisites_pause() { "$view_busybox" usleep 50000; }
		cfmgr_prerequisites_now || fail 'backup native clock unavailable'
		cfmgr_store_deadline=$((cfmgr_probe_now + 20))
		mount -o remount,noexec "$mount_dir" || fail 'backup noexec remount failed'
		cfmgr_backup_want_mount=$mount_dir cfmgr_backup_want_uuid=$main_uuid cfmgr_backup_want_filesystem=ext4 cfmgr_backup_want_root=/
		cfmgr_backup_want_snapshot=$("$awk" "$(
			cfmgr_storage_awk_mountinfo
			printf '%s' "$cfmgr_awk_program"
		)" "$mount_dir" /proc/self/mountinfo)
		cfmgr_backup_pin_selected || fail 'real noexec backup drive was not admitted'
		cfmgr_backup_prepare_folder || fail 'root backup folder was not created through the pinned mount'
		[ -d "$mount_dir/CFBackup" ] || fail 'backup folder was not created at the drive root'
		printf 'unrelated backup content\n' > "$mount_dir/CFBackup/keep"
		cfmgr_backup_prepare_folder || fail 'existing root backup folder was not prepared'
		[ "$(cat "$mount_dir/CFBackup/keep")" = 'unrelated backup content' ] || fail 'backup contents were changed'
		if [ "$case_name" = archive_source ]; then
			# The sole path adapter maps fixed /opt to this namespace's private alias.
			# Real ext4/bind mountinfo, blkid, FD3/5/6/7, and supervisor stay intact.
			# The source bind is read-only/noexec while the destination stays writable.
			# shellcheck disable=SC1091
			. "$root/modules/backup.sh"
			cfmgr_store_ls=/bin/ls
			cfmgr_store_native_tool() { [ -f "$1" ] && [ -x "$1" ]; }
			# shellcheck disable=SC2016 # Literal parameters belong to the fixed alias adapter.
			printf '#!/bin/sh\nif [ "$#" = 2 ] && [ "$1:$2" = -f:/opt ]; then exec "%s" -f "%s"; fi\nexec "%s" "$@"\n' \
				"$readlink" "$alias" "$readlink" > "$fixture/archive-readlink"
			chmod 700 "$fixture/archive-readlink"
			cfmgr_store_readlink=$fixture/archive-readlink
			mount --bind "$mount_dir/entware" "$bind_dir"
			mount -o remount,bind,ro,noexec "$bind_dir" || fail 'read-only source remount failed'
			rm "$alias"
			ln -s "$bind_dir" "$alias"
			exec 5< "$cfmgr_store_context"
			cfmgr_prerequisites_now || fail 'archive native clock unavailable'
			cfmgr_archive_deadline=$((cfmgr_probe_now + 15))
			cfmgr_archive_source_pin "$main_uuid" ext4 /entware . || fail 'read-only/noexec archive source rejected'
			cfmgr_archive_source_attached || fail 'source attachment failed after pin'
			cfmgr_backup_attached || fail 'source and destination did not coexist'
			[ -d /proc/self/fd/3 ] && [ -d /proc/self/fd/6 ] && [ -d /proc/self/fd/7 ] || fail 'concurrent pin missing'
			IFS= read -r archive_marker < /proc/self/fd/3/marker || fail 'pinned source data unreadable'
			[ "$archive_marker" = 'original volume data' ] || fail 'pinned source data changed'
			cfmgr_archive_io count 4096 /proc/self/fd/3/marker || fail 'native source count failed'
			rm "$alias"
			ln -s "$mount_dir" "$alias"
			if cfmgr_archive_source_attached; then fail 'changed source alias accepted'; fi
			if cfmgr_archive_copy /proc/self/fd/3/marker "$cfmgr_store_context/fallback" 0 21; then fail 'lost source accepted copy'; fi
			[ ! -e "$cfmgr_store_context/fallback" ] || fail 'lost source created fallback output'
			cfmgr_backup_attached || fail 'source loss destroyed destination pins'
			cfmgr_archive_source_release
			if (: <&3) 2> /dev/null; then fail 'source descriptor survived release'; fi
			cfmgr_backup_attached || fail 'source release destroyed destination pins'
			exec 5<&-
			printf 'PASS: read-only/noexec source3 coexists with destination6/7; alias loss refuses fallback writes\n'
		elif [ "$case_name" = backup_folder ]; then
			exec 7<&-
			cfmgr_backup_folder_pinned=0
			mv "$mount_dir/CFBackup" "$mount_dir/CFBackup.saved"
			ln -s "$mount_dir/CFBackup.saved" "$mount_dir/CFBackup"
			if cfmgr_backup_folder_admit; then fail 'backup folder symlink was admitted'; fi
			rm "$mount_dir/CFBackup"
			mv "$mount_dir/CFBackup.saved" "$mount_dir/CFBackup"
			mount -t tmpfs -o size=64k tmpfs "$mount_dir/CFBackup"
			if cfmgr_backup_folder_admit; then fail 'nested backup mount was admitted'; fi
			umount "$mount_dir/CFBackup"
			exec 6<&- 7<&-
			cfmgr_store_backup_gate=0 cfmgr_backup_pinned=0 cfmgr_backup_folder_pinned=0
			mount --bind "$mount_dir/entware" "$bind_dir"
			if cfmgr_backup_observe_mount "$bind_dir"; then fail 'Entware subtree bind was admitted as a backup drive'; fi
			printf 'PASS: noexec backup folder preserves contents; symlink, nested mount and Entware subtree bind refused\n'
		else
			umount -l "$mount_dir" || fail 'backup lazy detach failed'
			if cfmgr_backup_prepare_folder; then fail 'backup prepared folder on bare mountpoint'; fi
			[ ! -e "$mount_dir/CFBackup" ] || fail 'bare mountpoint received backup writes'
			mount -t ext4 "$replacement_device" "$mount_dir" || fail 'backup replacement mount failed'
			if cfmgr_backup_attached; then fail 'backup attachment adopted replacement'; fi
			if cfmgr_backup_prepare_folder; then fail 'backup prepared folder on replacement'; fi
			[ ! -e "$mount_dir/CFBackup" ] || fail 'replacement received backup writes'
			[ "$(cat /proc/self/fd/7/keep)" = 'unrelated backup content' ] || fail 'original pinned backup content changed'
			exec 6<&- 7<&-
			cfmgr_store_backup_gate=0 cfmgr_backup_pinned=0 cfmgr_backup_folder_pinned=0
			if cfmgr_backup_pin_selected; then fail 'stale selected snapshot admitted replacement'; fi
			printf 'PASS: backup lazy detach and replacement refuse writes and stale selection; original contents preserved\n'
		fi
		exec 6<&- 7<&-
		;;
	dependency_repair | dependency_update_failure | dependency_retry | dependency_daemon | dependency_threads | dependency_mixed | dependency_loss | dependency_installer)
		# shellcheck disable=SC1091 # Fixed repository fixture extension, no user input.
		. "$root/tests/fixtures/dependencies.sh"
		;;
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
		printf 'substitute data\n' > "$fixture/substitute/marker"
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
		printf 'replacement volume data\n' > "$mount_dir/entware/marker"
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
	view_compat)
		view_prepare
		view_create || fail 'guarded compatible view construction failed'
		[ "$cfmgr_view_state" = ready ] || fail 'view was not ready'
		# shellcheck disable=SC2016 # Literal commands execute inside the chroot.
		view_chroot '[ "$(/bin/busybox readlink /etc)" = /tmp/etc ] &&
		[ "$(/bin/busybox cat /native-file)" = "native regular file" ] &&
		[ "$(/bin/busybox cat /tmp/feed/Packages)" = "configured file feed" ] &&
		[ "$(/bin/busybox cat /etc/resolv.conf)" = "nameserver 127.0.0.1" ] &&
		[ "$(/bin/busybox cat /opt/nested/marker)" = "nested mount data" ] &&
		[ "$(/bin/busybox cat /tmp/mnt/usb/entware/nested/marker)" = "nested mount data" ] &&
		printf "writable temporary cache\n" >/tmp/cache-test &&
		printf "normal Entware path\n" >/opt/view-test &&
		[ -d /proc/self ] && [ -c /dev/null ] &&
		[ ! -e /tmp/private-ram/context/expected.mounts ]' || fail 'normal native paths failed inside real chroot'
		[ "$(cat "$view_native_root/tmp/cache-test")" = 'writable temporary cache' ] || fail 'native temporary view was restricted'
		[ "$(cat "$mount_dir/entware/view-test")" = 'normal Entware path' ] || fail 'FD7 view did not reach pinned volume'
		cfmgr_execution_view_recheck || fail 'healthy guarded view failed recheck'
		"$view_busybox" mount -t tmpfs -o size=64k tmpfs "$view_native_root/tmp/foreign"
		if cfmgr_execution_view_recheck; then fail 'source mount mutation was admitted'; fi
		"$view_busybox" umount "$view_native_root/tmp/foreign"
		cfmgr_execution_view_release || fail 'source-mutation view did not clean after quiescence'
		printf 'PASS: guarded native paths, real chroot, file feed, writable tmp, and both nested aliases\n'
		;;
	view_detach)
		view_prepare
		view_create || fail 'guarded detach view construction failed'
		view_chroot 'printf before-unplug >/opt/write-control && printf before-unplug >/tmp/mnt/usb/write-control' || fail 'healthy guarded writes failed before unplug'
		if [ "$(cat "$mount_dir/entware/write-control")" != before-unplug ] || [ "$(cat "$mount_dir/write-control")" != before-unplug ]; then
			fail 'healthy guarded writes did not reach the original volume'
		fi
		_cfmgr_view_call awk top "$cfmgr_view_root/opt" "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/opt.pin"
		IFS= read -r view_opt_pin < "$cfmgr_view_context/opt.pin"
		# Simulate Merlin USB removal by matching the actual device across ALL binds.
		# External lazy detach is fault injection only; view release never uses it.
		"$view_busybox" awk "$(
			cfmgr_storage_awk_mountinfo
			printf '%s' "$cfmgr_awk_program"
		)" inventory-v1 / /proc/self/mountinfo > "$fixture/device-mounts"
		# shellcheck disable=SC2016 # Literal AWK fields are interpreted by AWK.
		"$view_busybox" awk -F '\t' '
		BEGIN { device=ARGV[1]; ARGV[1]="" }
		$3==device { point[++n]=$5 }
		END { for (i=n;i>0;i--) print point[i] }
	' "$cfmgr_storage_device" "$fixture/device-mounts" > "$fixture/device-points"
		while IFS= read -r view_detach_point; do umount -l "$view_detach_point" || fail 'simulated device detach failed'; done < "$fixture/device-points"
		view_chroot 'printf still-running >/tmp/detach-control' || fail 'native view execution failed after unplug'
		[ "$(cat "$view_native_root/tmp/detach-control")" = still-running ] || fail 'native temporary writes stopped after unplug'
		cfmgr_mount_keeper_check || fail 'lazy detach lost keeper mount references'
		# The detached leaf has vanished from namespace inventory but remains held.
		"$view_busybox" awk "$(
			cfmgr_storage_awk_mountinfo
			printf '%s' "$cfmgr_awk_program"
		)" inventory-v1 / /proc/self/mountinfo > "$fixture/after-detach"
		# shellcheck disable=SC2016
		"$view_busybox" awk -F '\t' -v id="$view_opt_pin" '$1==id { found=1 } END { exit found ? 1 : 0 }' "$fixture/after-detach" || fail 'device leaf stayed namespace-visible'
		if view_chroot 'printf forbidden >/opt/blocked' 2> /dev/null; then fail 'detached /opt fallback accepted a write'; fi
		if view_chroot 'printf forbidden >/tmp/mnt/usb/blocked' 2> /dev/null; then fail 'detached canonical fallback accepted a write'; fi
		[ ! -e "$view_native_root/tmp/mnt/usb/blocked" ] || fail 'canonical bare path was changed'
		mount -t ext4 "$replacement_device" "$view_native_root/tmp/mnt/usb"
		printf 'replacement volume data\n' > "$view_native_root/tmp/mnt/usb/marker"
		if view_chroot 'printf forbidden >/tmp/mnt/usb/blocked' 2> /dev/null; then fail 'replacement volume leaked into guarded view'; fi
		[ ! -e "$view_native_root/tmp/mnt/usb/blocked" ] || fail 'replacement volume was changed'
		if cfmgr_execution_view_recheck; then fail 'detached source was still accepted'; fi
		# Release the fixture-owned replacement before reconciling detached mount IDs;
		# numeric mount IDs can be reused and are not process-ownership authority.
		umount "$view_native_root/tmp/mnt/usb"
		cfmgr_execution_view_release || fail 'detached guarded view did not clean after quiescence'
		printf 'PASS: device-matched lazy detach preserved RO guards at opt/canonical paths and excluded replacement\n'
		;;
	view_cleanup)
		view_prepare
		cfmgr_view_test_fault=partial
		if view_create; then fail 'partial bind failure was hidden'; fi
		[ -f "$cfmgr_view_context/test-bind7-fault" ] || fail 'construction did not reach the injected bind7 failure'
		[ "$cfmgr_view_state" != ready ] || fail 'partial construction became ready'
		cfmgr_execution_view_release || fail 'proved partial construction could not clean'
		cfmgr_view_test_fault=clean
		mkdir -m 700 "$view_ram/retry"
		cfmgr_execution_view_create "$view_native_root" "$view_ram/retry" "$view_ram/awk" "$readlink" "$root/modules/lib/storage.sh" || fail 'fresh retry view failed'
		cfmgr_view_test_quiet=0
		if cfmgr_execution_view_release; then fail 'release bypassed required quiescence'; fi
		cfmgr_view_test_quiet=1
		(
			cd "$cfmgr_view_root/opt"
			printf ready > "$cfmgr_view_context/observer.ready"
			exec /bin/sleep 15
		) &
		view_observer=$!
		view_observer_wait=0
		while [ ! -f "$cfmgr_view_context/observer.ready" ]; do
			[ "$view_observer_wait" -lt 20 ] || fail 'external read-only observer did not start'
			"$view_busybox" usleep 50000
			view_observer_wait=$((view_observer_wait + 1))
		done
		if cfmgr_execution_view_release; then fail 'busy owned mount was falsely released'; fi
		if [ "$cfmgr_view_state" != retained ] || [ ! -s "$cfmgr_view_context/expected.mounts" ]; then
			fail 'busy release lost evidence'
		fi
		"$view_busybox" mount -t tmpfs -o size=64k tmpfs "$cfmgr_view_root/opt"
		if cfmgr_execution_view_release; then fail 'foreign layer was adopted for cleanup'; fi
		"$view_busybox" umount "$cfmgr_view_root/opt"
		kill -TERM "$view_observer"
		wait "$view_observer" 2> /dev/null || :
		view_observer=
		cfmgr_execution_view_release || fail 'busy release did not recover after observer reaped'
		[ "$cfmgr_view_state" = released ] || fail 'successful release remained latched'
		printf 'PASS: partial rollback, required quiescence, busy retention, foreign rejection, and normal retry cleanup\n'
		;;
	*) fail "unknown case: $case_name" ;;
esac
