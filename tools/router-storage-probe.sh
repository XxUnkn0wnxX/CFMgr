#!/bin/sh
# Opt-in developer diagnostic; the operator explicitly selects the destination.
# Stream verified storage.sh followed by this script through router /bin/sh.
# --define only defines developer-test functions and performs no filesystem work.
# Native flush/rename/readback evidence is not power-loss or Save acceptance.
# Native BusyBox test -ef is required and verified by the descriptor fixtures.
# shellcheck disable=SC3013

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
	cfmgr_probe_mount_record "$1" "$2" "$3" >/dev/null
}

cfmgr_probe_mount_record() {
	# Literal ARGV operands preserve spaces/backslashes without awk -v decoding.
	# /proc/mounts escapes spaces; controls and unknown encodings fail closed.
	awk '
		function decode(value, result, part, code) {
			result=""
			while (length(value)) {
				part=substr(value,1,1)
				if (part == "\\") {
					code=substr(value,1,4)
					if (code == "\\040") part=" "
					else if (code == "\\134") part="\\"
					else { bad=1; return "" }
					value=substr(value,5)
				} else value=substr(value,2)
				result=result part
			}
			return result
		}
		BEGIN { mountpoint=ARGV[1]; filesystem=ARGV[2]; ARGV[1]=""; ARGV[2]="" }
		{
			if (NR > 4096 || length($0) > 8192 || NF != 6) { bad=1; next }
			if (decode($2) != mountpoint) next
			n++
			if ((filesystem == "external" && $3 !~ /^ext[234]$/) ||
			    (filesystem != "external" && $3 != filesystem) ||
			    $4 !~ /(^|,)rw(,|$)/ || $4 ~ /(^|,)ro(,|$)/) bad=1
			source=decode($1)
			if (source !~ /^\/dev\// || source ~ /[[:cntrl:]]/) bad=1
		}
		END { if (n != 1 || bad) exit 1; print source }
	' "$1" "$2" "$3"
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

	# Invoked by the EXIT trap; older ShellCheck cannot trace that callback.
	# shellcheck disable=SC2329,SC2317
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
		cfmgr_probe_basename=${cfmgr_probe_parent##*/}
		mkdir -m 700 "$cfmgr_probe_basename" || return 2
		exec 6<"$cfmgr_probe_basename" || return 1
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
	[ "$#" -eq 1 ] || return 2
	_cfmgr_storage_path "$1" || return 2
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
	/*/*)
		# A retained scratch base directly below an existing external mount.
		# Native path normalization keeps aliases but never invents a stale mount.
		cfmgr_probe_requested=$1
		cfmgr_probe_mount_alias=${cfmgr_probe_requested%/*}
		cfmgr_probe_basename=${cfmgr_probe_requested##*/}
		[ -d "$cfmgr_probe_mount_alias" ] || return 2
		cfmgr_probe_mount=$(readlink -f "$cfmgr_probe_mount_alias" && printf '\n.') || return 2
		case $cfmgr_probe_mount in
		*'

.') cfmgr_probe_mount=${cfmgr_probe_mount%'

.'} ;;
		*) return 2 ;;
		esac
		_cfmgr_storage_path "$cfmgr_probe_mount" || return 2
		cfmgr_probe_device=$(cfmgr_probe_mount_record "$cfmgr_probe_mount" external /proc/mounts) || return 2
		[ -b "$cfmgr_probe_device" ] || return 2
		exec 7<"$cfmgr_probe_mount" || return 2
		cd /proc/self/fd/7 || return 2
		[ "$(pwd -P)" = "$cfmgr_probe_mount" ] && [ "$cfmgr_probe_mount" -ef /proc/self/fd/7 ] || return 2
		cfmgr_probe_parent=$cfmgr_probe_mount/$cfmgr_probe_basename
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

cfmgr_probe_help() {
	printf '%s\n' \
		'CFMgr router storage probe (explicit opt-in)' \
		'Usage: /bin/sh router-storage-probe.sh --run ABSOLUTE_SCRATCH_DIR' \
		'       /bin/sh router-storage-probe.sh --help' \
		'The scratch directory must be directly below a mounted ext2/3/4 volume.' \
		'An existing scratch directory and its contents/permissions are preserved.' \
		'An absent scratch directory is created privately and retained afterward.' \
		'Explicit /jffs/addons is also supported; obtain permission before JFFS writes.' \
		'Writes one 30-byte file in a new private .cfmgr-storage-probe-PID directory,' \
		'checks flush/rename/readback, then removes only verified owned artifacts.' \
		'No settings, services or packages are changed. This is not power-loss proof.' \
		'From a checkout, use tools/router_probe.py with the ignored local config.'
}

case $#:${1-} in
1:--define) : ;;
1:--help) cfmgr_probe_help ;;
2:--run)
	# A local checkout can import its own explicit library; streamed execution
	# prepends the reviewed source. Help/invalid invocation performs no import.
	if ! type cfmgr_storage_flush_fd >/dev/null 2>&1; then
		cfmgr_probe_library=${0%/*}/../modules/lib/storage.sh
		if [ -f "$cfmgr_probe_library" ] && [ ! -L "$cfmgr_probe_library" ]; then
			# shellcheck source=/dev/null
			. "$cfmgr_probe_library"
		else
			printf '%s\n' 'Missing storage library; use the checkout developer launcher.' >&2
			exit 2
		fi
	fi
	if ! cfmgr_router_storage_probe "$2"; then
		printf '%s\n' 'Probe failed or storage was not admitted; inspect any retained ownership warning.' >&2
		exit 2
	fi
	;;
*)
	printf '%s\n' 'Router storage probe is inert. Explicit --run with a destination is required.'
	cfmgr_probe_help
	exit 2
	;;
esac
