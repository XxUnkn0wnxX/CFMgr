#!/bin/sh
# Opt-in diagnostic: JFFS needs explicit permission; the optional USB scratch
# destination follows the user's separate temporary-command-test permission.
# Stream verified storage.sh followed by this script through router /bin/sh.
# --define only defines developer-test functions and performs no filesystem work.
# Native flush/rename/readback evidence is not power-loss or Save acceptance.

cfmgr_probe_root_uid() {
	awk '$1 == "Uid:" { n++; if (NF != 5 || $2 != "0" || $3 != "0" || $4 != "0" || $5 != "0") bad=1 }
		END { exit (n == 1 && !bad ? 0 : 1) }' "$1"
}

cfmgr_probe_metadata() {
	# The operand is controlled, has no newline, and must describe one object.
	cfmgr_probe_listing=$(ls -ldn "$1") || return 1
	printf '%s\n' "$cfmgr_probe_listing" | awk -v mode="$2" -v owner="${3:-0}" '
		{ n++; if (NF < 9 || $1 != mode || $3 != owner) bad=1 }
		END { exit (n == 1 && !bad ? 0 : 1) }'
}

cfmgr_probe_preflight() {
	# All external commands are admitted before mkdir or file creation.
	for cfmgr_probe_tool in awk ls mkdir mv rm rmdir cmp readlink '[' printf pwd; do
		type "$cfmgr_probe_tool" >/dev/null 2>&1 || return 2
	done
	type cfmgr_storage_flush_fd >/dev/null 2>&1 || return 2
	[ -f "$3" ] && [ -x "$3" ] || return 2
	[ -d /proc/self/fd ] || return 2
	cfmgr_probe_root_uid "$1" || return 2
	[ -r "$2" ] || return 2
}

cfmgr_probe_mounted() {
	# Count every row for this mountpoint, including any inadmissible row.
	awk -v mountpoint="$1" -v filesystem="$2" '
		$2 == mountpoint { n++; if ($3 != filesystem || $4 !~ /(^|,)rw(,|$)/) bad=1 }
		END { exit (n == 1 && !bad ? 0 : 1) }' "$3"
}

cfmgr_probe_identity() {
	[ ! -L "$1" ] && [ "$1" -ef "/proc/self/fd/$2" ] || return 1
	case $3 in
	drwx------) [ -d "$1" ] || return 1 ;;
	-rw-------) [ -f "$1" ] || return 1 ;;
	*) return 1 ;;
	esac
	cfmgr_probe_metadata "$1" "$3" "${4:-0}"
}

cfmgr_probe_write() (
	# Caller has admitted a real, canonical mounted destination. fd 6 pins the
	# retained parent directory, including creation anchored at admitted fd 7;
	# fd 4/5 pin scratch and payload. The private directory excludes ordinary writers;
	# these checks do not claim atomic exclusion of a hostile root process.
	cfmgr_probe_parent=$1
	cfmgr_probe_backend=$2
	cfmgr_probe_parent_missing=$3
	# Only the definition-only test interface supplies a non-root fixture owner.
	# The runnable CLI always supplies 0 after checking all native UID fields.
	cfmgr_probe_owner=$4
	cfmgr_probe_root=$cfmgr_probe_parent/.cfmgr-storage-probe-$$
	cfmgr_probe_root_created=0
	cfmgr_probe_root_pinned=0
	cfmgr_probe_file_pinned=0
	cfmgr_probe_result=1
	umask 077

	# shellcheck disable=SC2329
	cfmgr_probe_cleanup() {
		exec 3<&-
		if [ "$cfmgr_probe_root_created" = 1 ]; then
			if [ "$cfmgr_probe_root_pinned" != 1 ] ||
				[ "$(pwd -P)" != "$cfmgr_probe_root" ] ||
				! cfmgr_probe_identity . 4 drwx------ "$cfmgr_probe_owner" ||
				! cfmgr_probe_identity "$cfmgr_probe_root" 4 drwx------ "$cfmgr_probe_owner"; then
				printf '%s\n' "Probe ownership uncertain; retain $cfmgr_probe_root" >&2
				return 1
			fi
			for cfmgr_probe_file in stage committed; do
				if [ -e "$cfmgr_probe_file" ] || [ -L "$cfmgr_probe_file" ]; then
					if [ "$cfmgr_probe_file_pinned" != 1 ] ||
						! cfmgr_probe_identity "$cfmgr_probe_file" 5 -rw------- "$cfmgr_probe_owner"; then
						printf '%s\n' "Probe file ownership uncertain; retain $cfmgr_probe_root" >&2
						return 1
					fi
					rm "$cfmgr_probe_file" || return 1
				fi
			done
			[ "$cfmgr_probe_parent" -ef /proc/self/fd/6 ] && [ ! -L "$cfmgr_probe_parent" ] || return 1
			cd /proc/self/fd/6 || return 1
			# Recheck the name after leaving the held directory, before rmdir.
			cfmgr_probe_identity "$cfmgr_probe_root" 4 drwx------ "$cfmgr_probe_owner" || return 1
			rmdir "$cfmgr_probe_root" || return 1
		fi
		exec 4<&- 5>&- 6<&-
		if [ "$cfmgr_probe_root_created" = 1 ]; then
			printf '%s\n' "Probe cleanup verified: $cfmgr_probe_root"
		fi
	}
	trap 'cfmgr_probe_result=$?; trap - 0; if ! cfmgr_probe_cleanup; then cfmgr_probe_result=1; fi; exit "$cfmgr_probe_result"' 0
	trap 'exit 1' HUP INT TERM
	if [ "$cfmgr_probe_parent_missing" = 1 ]; then
		# The caller is already in the admitted USB root and holds fd 7.
		[ . -ef /proc/self/fd/7 ] && [ "${cfmgr_probe_parent%/*}" -ef /proc/self/fd/7 ] || return 2
		mkdir -m 700 tmp || return 2
		exec 6<tmp || return 1
		cfmgr_probe_identity "$cfmgr_probe_parent" 6 drwx------ "$cfmgr_probe_owner" || return 1
	else
		[ -d "$cfmgr_probe_parent" ] && [ ! -L "$cfmgr_probe_parent" ] || return 2
		exec 6<"$cfmgr_probe_parent" || return 1
	fi
	[ "$cfmgr_probe_parent" -ef /proc/self/fd/6 ] && [ ! -L "$cfmgr_probe_parent" ] || return 1
	cd /proc/self/fd/6 || return 1
	[ "$(pwd -P)" = "$cfmgr_probe_parent" ] || return 1
	[ ! -e "$cfmgr_probe_root" ] && [ ! -L "$cfmgr_probe_root" ] || return 2
	mkdir -m 700 ".cfmgr-storage-probe-$$" || return 2
	cfmgr_probe_root_created=1
	exec 4<".cfmgr-storage-probe-$$" || return 1
	cfmgr_probe_root_pinned=1
	cfmgr_probe_identity "$cfmgr_probe_root" 4 drwx------ "$cfmgr_probe_owner" || return 1
	cd /proc/self/fd/4 || return 1
	printf '%s\n' "Probe scratch: $cfmgr_probe_root"
	set -C
	exec 5>stage || return 1
	cfmgr_probe_file_pinned=1
	cfmgr_probe_identity stage 5 -rw------- "$cfmgr_probe_owner" || return 1
	printf '%s\n' 'CFMgr native storage probe v1' >&5 || return 1
	exec 3</proc/self/fd/5
	cfmgr_storage_flush_fd "$cfmgr_probe_backend" || return 1
	exec 3<&-
	exec 3</proc/self/fd/4
	cfmgr_storage_flush_fd "$cfmgr_probe_backend" || return 1
	exec 3<&-
	[ ! -e committed ] && [ ! -L committed ] || return 1
	cfmgr_probe_identity stage 5 -rw------- "$cfmgr_probe_owner" || return 1
	mv stage committed || return 1
	cfmgr_probe_identity committed 5 -rw------- "$cfmgr_probe_owner" || return 1
	exec 3</proc/self/fd/5
	cfmgr_storage_flush_fd "$cfmgr_probe_backend" || return 1
	exec 3<&-
	exec 3</proc/self/fd/4
	cfmgr_storage_flush_fd "$cfmgr_probe_backend" || return 1
	exec 3<&-
	printf '%s\n' 'CFMgr native storage probe v1' | cmp -s - committed || return 1
	printf '%s\n' 'Native file/directory flush and staged rename/readback passed; cleanup follows.'
)

cfmgr_router_storage_probe() (
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	LANGUAGE=
	export PATH LC_ALL LANGUAGE
	umask 077
	cfmgr_probe_preflight /proc/self/status /proc/mounts /bin/fsync || return 2
	cfmgr_probe_parent_missing=0
	case $1 in
	/jffs/addons)
		[ -d /jffs ] && [ ! -L /jffs ] || return 2
		[ -d /jffs/addons ] && [ ! -L /jffs/addons ] || return 2
		[ "$(readlink -f /jffs/addons)" = /jffs/addons ] || return 2
		cfmgr_probe_mounted /jffs jffs2 /proc/mounts || return 2
		cfmgr_probe_parent=/jffs/addons
		;;
	/mnt/MERLIN/tmp)
		[ -d /mnt/MERLIN ] && [ ! -L /mnt/MERLIN ] || return 2
		[ "$(readlink -f /mnt/MERLIN)" = /tmp/mnt/MERLIN ] || return 2
		exec 7</tmp/mnt/MERLIN || return 2
		cd /proc/self/fd/7 || return 2
		[ "$(pwd -P)" = /tmp/mnt/MERLIN ] && [ /tmp/mnt/MERLIN -ef /proc/self/fd/7 ] || return 2
		cfmgr_probe_mounted /tmp/mnt/MERLIN ext4 /proc/mounts || return 2
		cfmgr_probe_parent=/tmp/mnt/MERLIN/tmp
		if [ -e "$cfmgr_probe_parent" ] || [ -L "$cfmgr_probe_parent" ]; then
			[ -d "$cfmgr_probe_parent" ] && [ ! -L "$cfmgr_probe_parent" ] || return 2
			[ "$(readlink -f "$cfmgr_probe_parent")" = "$cfmgr_probe_parent" ] || return 2
		else
			cfmgr_probe_parent_missing=1
		fi
		;;
	*) return 2 ;;
	esac
	cfmgr_probe_write "$cfmgr_probe_parent" /bin/fsync "$cfmgr_probe_parent_missing" 0
)

case $#:$1 in
1:--define) : ;;
1:--run) cfmgr_router_storage_probe /jffs/addons ;;
2:--run)
	if [ "$2" = /mnt/MERLIN/tmp ]; then
		cfmgr_router_storage_probe "$2"
	else
		printf '%s\n' 'Router storage probe is inert. Only JFFS or the explicit USB scratch destination is allowed.'
		exit 2
	fi
	;;
*)
	printf '%s\n' 'Router storage probe is inert. Explicit --run and execution permission are required.'
	exit 2
	;;
esac
