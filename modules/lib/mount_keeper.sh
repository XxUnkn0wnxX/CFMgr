#!/bin/sh
# Source-inert controller for one fixed native-ash mount-reference keeper.
# Caller admits fresh private RAM context and all explicit tools/code. Required:
# cfmgr_mount_keeper_native fifo MKNOD PATH (bounded/reaped mknod PATH p, umask077).
# cfmgr_prerequisites_identity is the narrow fixed-process identity utility.
# FD3 is reserved control; retain borrows FD4 via caller function redirection.
# Pins are lifetime evidence only while check succeeds; never task ownership.

# shellcheck disable=SC2034 # Proc uptime second field is deliberately consumed.
_cfmgr_keeper_now() {
	IFS=' ' read -r cfmgr_keeper_uptime cfmgr_keeper_idle </proc/uptime || return 3
	cfmgr_keeper_now=${cfmgr_keeper_uptime%%.*}
	case $cfmgr_keeper_now in '' | *[!0-9]*) return 3 ;; esac
}

# shellcheck disable=SC2154 # Narrow prerequisite identity utility exports these fields.
_cfmgr_keeper_owned() {
	cfmgr_prerequisites_identity "$cfmgr_keeper_pid" || return 3
	if [ "$cfmgr_identity_start" != "$cfmgr_keeper_start" ] || [ "$cfmgr_identity_parent" != "$cfmgr_keeper_owner" ]; then return 3; fi
	[ "$cfmgr_identity_state" != Z ] || return 3
	IFS= read -r cfmgr_keeper_current_boot </proc/sys/kernel/random/boot_id || return 3
	[ "$cfmgr_keeper_current_boot" = "$cfmgr_keeper_boot" ] || return 3
}

_cfmgr_keeper_wait() {
	# KIND SEQUENCE ID; one complete fixed receipt, no unterminated extra bytes.
	_cfmgr_keeper_now || return 3
	cfmgr_keeper_deadline=$((cfmgr_keeper_now + 5))
	while :; do
		_cfmgr_keeper_owned || return 3
		if [ -f "$cfmgr_keeper_context/receipt" ]; then
			cfmgr_keeper_line='' cfmgr_keeper_extra=''
			{
				if IFS= read -r cfmgr_keeper_line; then
					if IFS= read -r cfmgr_keeper_extra; then cfmgr_keeper_extra=invalid; fi
				else cfmgr_keeper_line=''; fi
			} <"$cfmgr_keeper_context/receipt"
			if [ -z "$cfmgr_keeper_extra" ]; then
				if [ "$cfmgr_keeper_line" = "$1 $2 $3 END" ]; then
					cfmgr_keeper_receipt=$cfmgr_keeper_line
					return 0
				fi
				if [ "$cfmgr_keeper_line" = "failed $2 $3 END" ]; then
					cfmgr_keeper_receipt=$cfmgr_keeper_line
					return 1
				fi
			fi
			# Previous complete receipt can remain until the current write starts.
			if [ -n "$cfmgr_keeper_line" ] && [ "$cfmgr_keeper_line" != "$cfmgr_keeper_receipt" ]; then return 3; fi
		fi
		_cfmgr_keeper_now || return 3
		[ "$cfmgr_keeper_now" -lt "$cfmgr_keeper_deadline" ] || return 3
		"$cfmgr_keeper_usleep" 10000 || return 3
	done
}

_cfmgr_keeper_fdscan() {
	# ACK can precede printf's saved-FD restoration. Retry the complete bounded
	# scan; never accept partial output or assume saved descriptor numbers.
	_cfmgr_keeper_now || return 3
	cfmgr_keeper_scan_deadline=$((cfmgr_keeper_now + 5))
	while :; do
		_cfmgr_keeper_owned || return 3
		# shellcheck disable=SC2016
		if (
			# Do not change caller's no-glob flag (native identity callers use -f).
			set +f
			set -- /proc/"$cfmgr_keeper_pid"/fdinfo/*
			[ "$#" -le 1024 ] || exit 1
			"$cfmgr_keeper_awk" '
			/^mnt_id:/ { if (NF!=2 || $2 !~ /^[1-9][0-9]*$/) bad=1; ids[$2]=1; count[FILENAME]++ }
			END { for (i=1;i<ARGC;i++) if (count[ARGV[i]]!=1) bad=1
			  if (bad || ARGC>1025) exit 1; for (id in ids) print id }
			' "$@"
		) >"$cfmgr_keeper_context/fds.current" 2>"$cfmgr_keeper_context/fds.err"; then return 0; fi
		_cfmgr_keeper_now || return 3
		[ "$cfmgr_keeper_now" -lt "$cfmgr_keeper_scan_deadline" ] || return 3
		"$cfmgr_keeper_usleep" 10000 || return 3
	done
}

cfmgr_mount_keeper_check() {
	# Optional additional pin reservation (0/1), and required visible ledger.
	[ "$#" -le 2 ] || return 2
	case ${1:-0} in 0 | 1) ;; *) return 2 ;; esac
	[ "${cfmgr_keeper_state:-invalid}" = active ] || return 3
	_cfmgr_keeper_owned || return 3
	_cfmgr_keeper_fdscan || return 3
	# Baseline descriptors are admitted keeper I/O/script references, not pins.
	# shellcheck disable=SC2016
	"$cfmgr_keeper_awk" '
		FILENAME==ARGV[1] { allowed[$1]=1; next }
		FILENAME==ARGV[2] { allowed[$1]=1; required[$1]=1; next }
		{ if (!($1 in allowed)) bad=1; found[$1]=1 }
		END { for (id in required) if (!(id in found)) bad=1; exit bad ? 1 : 0 }
	' "$cfmgr_keeper_context/fds.base" "$cfmgr_keeper_context/pins" "$cfmgr_keeper_context/fds.current" || return 3
	if [ "$#" -eq 2 ]; then
		# shellcheck disable=SC2016
		"$cfmgr_keeper_awk" -F '\t' '
			FILENAME==ARGV[1] { pinned[$1]=1; next }
			{ if (!($1 in pinned)) bad=1 }
			END { exit bad ? 1 : 0 }
		' "$cfmgr_keeper_context/pins" "$2" || return 3
	fi
	_cfmgr_keeper_owned || return 3
	if [ "${1:-0}" = 1 ] && [ "$cfmgr_keeper_count" -ge "$cfmgr_keeper_limit" ]; then return 1; fi
}

# CONTEXT ASH HELPER PREREQUISITE_LIBRARY ENV MKNOD AWK USLEEP
# The fixed FIFO callback must supervise/reap its mknod operation. No tool/path
# defaults are taken from environment. All context files are retained on failure.
# shellcheck disable=SC2034,SC2154
cfmgr_mount_keeper_start() {
	# Never discard a keeper identity or FIFO that may still hold references.
	case ${cfmgr_keeper_state:-invalid} in active | retained)
		[ -z "${cfmgr_keeper_pid:-}" ] || return 3
		if (: <&3) 2>/dev/null; then return 3; fi
		;;
	esac
	cfmgr_keeper_state=invalid
	[ "$#" -eq 8 ] || return 2
	for cfmgr_keeper_argument; do
		case $cfmgr_keeper_argument in /*) ;; *) return 2 ;; esac
		case $cfmgr_keeper_argument in *[!\ -~]* | *//* | */./* | */../* | */. | */.. | */) return 2 ;; esac
	done
	[ -d "$1" ] && [ ! -L "$1" ] || return 2
	if (: <&3) 2>/dev/null; then return 2; fi
	cfmgr_keeper_pid=''
	cfmgr_keeper_context=$1 cfmgr_keeper_shell=$2 cfmgr_keeper_helper=$3 cfmgr_keeper_prerequisites=$4
	cfmgr_keeper_env=$5 cfmgr_keeper_mknod=$6 cfmgr_keeper_awk=$7 cfmgr_keeper_usleep=$8
	# shellcheck disable=SC3045 # Pinned native ash/Linux descriptor-limit admission.
	cfmgr_keeper_nofile=$(ulimit -n) || return 2
	case $cfmgr_keeper_nofile in '' | *[!0-9]*) return 2 ;; esac
	[ "$cfmgr_keeper_nofile" -ge 48 ] || return 2
	# Two redirection frames per retained mount, plus tool/control headroom.
	cfmgr_keeper_limit=$(((cfmgr_keeper_nofile - 32) / 2))
	[ "$cfmgr_keeper_limit" -le 256 ] || cfmgr_keeper_limit=256
	cfmgr_keeper_count=0 cfmgr_keeper_sequence=0 cfmgr_keeper_receipt=''
	(
		umask 077
		set -C
		for cfmgr_keeper_file in pins receipt stdout stderr fds.current fds.base fds.err; do
			: >"$1/$cfmgr_keeper_file" || exit 1
		done
	) || return 2
	cfmgr_keeper_state=retained
	IFS= read -r cfmgr_keeper_self </proc/self/stat || return 2
	cfmgr_keeper_owner=${cfmgr_keeper_self%% *}
	cfmgr_prerequisites_identity "$cfmgr_keeper_owner" || return 2
	cfmgr_keeper_owner_start=$cfmgr_identity_start
	IFS= read -r cfmgr_keeper_boot </proc/sys/kernel/random/boot_id || return 2
	cfmgr_mount_keeper_native fifo "$cfmgr_keeper_mknod" "$1/control" || return 3
	[ -p "$1/control" ] && [ ! -L "$1/control" ] || return 3
	# Linux FIFO O_RDWR does not wait for a peer; private admission precedes open.
	exec 3<>"$1/control" || return 3
	# Native applets may live in /usr/bin. An admitted fixture applet directory
	# deliberately precedes these native directories; no ambient PATH survives.
	"$cfmgr_keeper_env" -i PATH="${cfmgr_keeper_shell%/*}:/bin:/usr/bin:/sbin:/usr/sbin" LC_ALL=C LANGUAGE='' \
		"$cfmgr_keeper_shell" "$cfmgr_keeper_helper" "$1" "$cfmgr_keeper_owner" "$cfmgr_keeper_owner_start" "$cfmgr_keeper_boot" \
		"$cfmgr_keeper_limit" "$cfmgr_keeper_awk" "$cfmgr_keeper_prerequisites" "$cfmgr_keeper_usleep" \
		3<>"$1/control" 4<&- 5<&- 6<&- 7<&- 8<&- 9<&- </dev/null >"$1/stdout" 2>"$1/stderr" &
	cfmgr_keeper_pid=$!
	cfmgr_prerequisites_identity "$cfmgr_keeper_pid" || return 3
	cfmgr_keeper_start=$cfmgr_identity_start
	_cfmgr_keeper_wait ready 0 0 || return 3
	_cfmgr_keeper_fdscan || return 3
	# Private RAM copy by shell; no extra native utility/operation dispatch.
	while IFS= read -r cfmgr_keeper_base_id; do printf '%s\n' "$cfmgr_keeper_base_id"; done <"$1/fds.current" >"$1/fds.base" || return 3
	cfmgr_keeper_state=active
	cfmgr_mount_keeper_check 0
}

# EXPECTED_MOUNT_ID, with actual already-proved target inherited on FD4.
# Call as: cfmgr_mount_keeper_retain ID 4<"$target"; caller FD4 is restored.
cfmgr_mount_keeper_retain() {
	[ "$#" -eq 1 ] || return 2
	case $1 in '' | 0* | *[!0-9]*) return 2 ;; esac
	[ "${#1}" -le 10 ] || return 2
	cfmgr_mount_keeper_check 0 || return 3
	[ "$cfmgr_keeper_count" -lt "$cfmgr_keeper_limit" ] || return 1
	[ -d /proc/self/fd/4 ] || [ -f /proc/self/fd/4 ] || return 2
	# shellcheck disable=SC2016
	"$cfmgr_keeper_awk" -v expected="$1" '/^mnt_id:/ { n++; if ($2!=expected) bad=1 } END { exit n!=1 || bad ? 1 : 0 }' /proc/self/fdinfo/4 || return 3
	[ "$cfmgr_keeper_sequence" -lt 999999999 ] || return 3
	cfmgr_keeper_sequence=$((cfmgr_keeper_sequence + 1))
	printf 'hold %s %s\n' "$cfmgr_keeper_sequence" "$1" >&3 || return 3
	if _cfmgr_keeper_wait held "$cfmgr_keeper_sequence" "$1"; then
		printf '%s\n' "$1" >>"$cfmgr_keeper_context/pins" || return 3
		cfmgr_keeper_count=$((cfmgr_keeper_count + 1))
		cfmgr_mount_keeper_check 0 || {
			cfmgr_keeper_state=retained
			return 3
		}
	else
		cfmgr_keeper_hold_code=$?
		if [ "$cfmgr_keeper_hold_code" -eq 1 ] && cfmgr_mount_keeper_check 0; then return 1; fi
		cfmgr_keeper_state=retained
		return 3
	fi
}

# Independently proved quiescence belongs to caller. This releases/reaps only
# the fixed keeper child; current exact mount ledger must precede this call.
# shellcheck disable=SC2154
cfmgr_mount_keeper_release() {
	cfmgr_mount_keeper_check 0 || return 3
	# Retire command admission before sending the one release. Uncertain release
	# cannot enqueue another outstanding command or advertise reference authority.
	cfmgr_keeper_state=retained
	[ "$cfmgr_keeper_sequence" -lt 999999999 ] || return 3
	cfmgr_keeper_sequence=$((cfmgr_keeper_sequence + 1))
	printf 'release %s 0\n' "$cfmgr_keeper_sequence" >&3 || return 3
	# Release receipt is written before recursive frames unwind. A reaped zero
	# exit is the completion proof; disappearing PID/receipt alone is insufficient.
	_cfmgr_keeper_now || return 3
	cfmgr_keeper_deadline=$((cfmgr_keeper_now + 5))
	while :; do
		cfmgr_prerequisites_identity "$cfmgr_keeper_pid" || break
		if [ "$cfmgr_identity_start" != "$cfmgr_keeper_start" ] || [ "$cfmgr_identity_parent" != "$cfmgr_keeper_owner" ]; then return 3; fi
		[ "$cfmgr_identity_state" != Z ] || break
		_cfmgr_keeper_now || return 3
		[ "$cfmgr_keeper_now" -lt "$cfmgr_keeper_deadline" ] || return 3
		"$cfmgr_keeper_usleep" 10000 || return 3
	done
	if wait "$cfmgr_keeper_pid"; then :; else
		cfmgr_keeper_state=retained
		return 3
	fi
	cfmgr_keeper_line='' cfmgr_keeper_extra=''
	{
		IFS= read -r cfmgr_keeper_line || return 3
		if IFS= read -r cfmgr_keeper_extra; then return 3; fi
		[ -z "$cfmgr_keeper_extra" ] || return 3
	} <"$cfmgr_keeper_context/receipt"
	[ "$cfmgr_keeper_line" = "released $cfmgr_keeper_sequence 0 END" ] || return 3
	exec 3<&-
	cfmgr_keeper_state=released
}
