#!/bin/sh
# Opt-in router diagnostic, requiring separate permission to execute.
# Stream verified storage.sh followed by this script to a native environment:
# ssh router '/usr/bin/env -i PATH=/sbin:/bin:/usr/sbin:/usr/bin LC_ALL=C /bin/sh -s -- --run'
# The stream defines cfmgr_storage_flush_fd before this script is evaluated.
# This tests native file/directory flush and a tiny JFFS write/rename/readback;
# it does not establish power-loss recovery, fault injection or Save acceptance.

if [ "$#" -ne 1 ] || [ "$1" != '--run' ]; then
	printf '%s\n' 'Router storage probe is inert. Explicit --run and execution permission are required.'
	exit 2
fi

cfmgr_router_storage_probe() (
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	LANGUAGE=
	export PATH LC_ALL LANGUAGE
	umask 077
	type cfmgr_storage_flush_fd >/dev/null 2>&1 || return 2
	[ "$(id -u)" = 0 ] || return 2
	[ -d /jffs ] && [ ! -L /jffs ] || return 2
	[ -d /jffs/addons ] && [ ! -L /jffs/addons ] || return 2
	awk '$2 == "/jffs" && $3 == "jffs2" && $4 ~ /(^|,)rw(,|$)/ { n++ }
		END { exit (n == 1 ? 0 : 1) }' /proc/mounts || return 2
	[ -x /bin/fsync ] || return 2
	cfmgr_probe_root=/jffs/addons/.cfmgr-storage-probe-$$
	[ ! -e "$cfmgr_probe_root" ] && [ ! -L "$cfmgr_probe_root" ] || return 2
	# mkdir is exclusive; no existing directory or symlink is adopted.
	mkdir -m 700 "$cfmgr_probe_root" || return 2
	cfmgr_probe_root_id=$(stat -c '%d:%i:%u:%a' "$cfmgr_probe_root") || {
		printf '%s\n' "Probe ownership uncertain; retain $cfmgr_probe_root" >&2
		return 1
	}
	case $cfmgr_probe_root_id in
	*:0:700) ;;
	*)
		printf '%s\n' "Probe permissions uncertain; retain $cfmgr_probe_root" >&2
		return 1
		;;
	esac
	cd "$cfmgr_probe_root" || return 1
	cfmgr_probe_file_id=
	cfmgr_probe_result=1

	# Called only by the exit trap, including early failure and interruption.
	# shellcheck disable=SC2329
	cfmgr_probe_cleanup() {
		exec 3<&-
		if [ -L "$cfmgr_probe_root" ] ||
			[ "$(pwd -P)" != "$cfmgr_probe_root" ] ||
			[ "$(stat -c '%d:%i:%u:%a' .)" != "$cfmgr_probe_root_id" ] ||
			[ "$(stat -c '%d:%i:%u:%a' "$cfmgr_probe_root")" != "$cfmgr_probe_root_id" ]; then
			printf '%s\n' "Probe ownership changed; retain $cfmgr_probe_root" >&2
			return 1
		fi
		for cfmgr_probe_file in stage committed; do
			if [ -e "$cfmgr_probe_file" ] || [ -L "$cfmgr_probe_file" ]; then
				if [ -z "$cfmgr_probe_file_id" ] || [ -L "$cfmgr_probe_file" ] ||
					[ ! -f "$cfmgr_probe_file" ] ||
					[ "$(stat -c '%d:%i:%u:%a' "$cfmgr_probe_file")" != "$cfmgr_probe_file_id" ]; then
					printf '%s\n' "Probe file ownership uncertain; retain $cfmgr_probe_root" >&2
					return 1
				fi
				rm "$cfmgr_probe_file" || return 1
			fi
		done
		cd /jffs/addons || return 1
		rmdir "$cfmgr_probe_root"
	}
	trap 'cfmgr_probe_result=$?; trap - 0; if ! cfmgr_probe_cleanup; then cfmgr_probe_result=1; fi; exit "$cfmgr_probe_result"' 0
	trap 'exit 1' HUP INT TERM
	set -C
	printf '%s\n' 'CFMgr native storage probe v1' >stage || return 1
	cfmgr_probe_file_id=$(stat -c '%d:%i:%u:%a' stage) || return 1
	exec 3<stage
	cfmgr_storage_flush_fd /bin/fsync || return 1
	exec 3<&-
	exec 3<.
	cfmgr_storage_flush_fd /bin/fsync || return 1
	exec 3<&-
	mv stage committed || return 1
	exec 3<committed
	cfmgr_storage_flush_fd /bin/fsync || return 1
	exec 3<&-
	exec 3<.
	cfmgr_storage_flush_fd /bin/fsync || return 1
	exec 3<&-
	printf '%s\n' 'CFMgr native storage probe v1' | cmp -s - committed || return 1
	printf '%s\n' 'Native file/directory flush and staged rename/readback passed; cleanup follows.'
)

cfmgr_router_storage_probe
