#!/bin/sh
# Source-inert, local-only status consumer. No operational preparation/repair.
# Imports are fixed installed paths admitted by the trusted entry; no data sourcing.
# A private report context holds bounded native snapshots and a config projection.
# Status runs in a subshell so menu descriptors, traps and launch state survive.
# shellcheck disable=SC2034,SC2154,SC3013
cfmgr_status_attachment_ok() {
	[ "${cfmgr_status_interrupted:-0}" = 0 ] && [ ! -L "$cfmgr_status_context" ] &&
		[ "$cfmgr_status_context" -ef /proc/self/fd/9 ]
}

cfmgr_status_run() {
	cfmgr_status_mode=$1 cfmgr_status_tool=$2
	shift 2
	cfmgr_prerequisites_now || return 2
	if [ "$cfmgr_probe_now" -ge "$cfmgr_status_deadline" ]; then
		cfmgr_status_budget_exhausted=1
		return 1
	fi
	cfmgr_prerequisites_run "$cfmgr_status_mode" "$cfmgr_status_context" /bin/sh \
		"$cfmgr_source/modules/helpers/probe.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_status_tool" "$@" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_status_cleanup() {
	cfmgr_status_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "$cfmgr_probe_status" = reaped ] || return 1
	cfmgr_status_count=0
	for cfmgr_status_file in "$cfmgr_status_context"/*; do
		[ -e "$cfmgr_status_file" ] || continue
		[ -f "$cfmgr_status_file" ] && [ ! -L "$cfmgr_status_file" ] || return 1
		cfmgr_status_count=$((cfmgr_status_count + 1))
		[ "$cfmgr_status_count" -le 96 ] || return 1
	done
	for cfmgr_status_file in "$cfmgr_status_context"/*; do
		[ -f "$cfmgr_status_file" ] || continue
		/bin/rm -f "$cfmgr_status_file" || return 1
	done
	/bin/rmdir "$cfmgr_status_context" || return 1
	exec 9<&-
}

cfmgr_status_prepare() {
	# Root-owned RAM and fixed native tools only; Entware is never executed.
	[ -d /tmp ] && [ ! -L /tmp ] && [ "$(/usr/bin/readlink -f /tmp)" = /tmp ] || return 1
	cfmgr_status_mount=$(/usr/bin/awk -f "$cfmgr_source/modules/lib/mountinfo.awk" /tmp /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_status_id cfmgr_status_parent cfmgr_status_device cfmgr_status_root cfmgr_status_point cfmgr_status_type cfmgr_status_rest <<EOF_MOUNT
$cfmgr_status_mount
EOF_MOUNT
	case $cfmgr_status_type in tmpfs | ramfs | rootfs) ;; *) return 1 ;; esac
	cfmgr_prerequisites_identity "$$" || return 1
	cfmgr_status_context=/tmp/cfmgr-status.$$.$cfmgr_identity_start
	umask 077
	/bin/mkdir -m 700 "$cfmgr_status_context" || return 1
	exec 9<"$cfmgr_status_context" || return 1
	cfmgr_status_interrupted=0 cfmgr_probe_pid='' cfmgr_status_budget_exhausted=0
	cfmgr_prerequisites_now || return 1
	cfmgr_status_deadline=$((cfmgr_probe_now + 10))
	trap 'cfmgr_status_interrupted=1' HUP INT TERM
}

cfmgr_status_native() (
	for cfmgr_status_path in "$cfmgr_source/modules/helpers/probe.sh" "$cfmgr_source/modules/lib/json.awk" \
		"$cfmgr_source/modules/lib/status.awk" "$cfmgr_source/modules/lib/status_native.awk" "$cfmgr_source/modules/lib/mountinfo.awk"; do
		if [ ! -f "$cfmgr_status_path" ] || [ -L "$cfmgr_status_path" ] ||
			! /usr/bin/awk 'NR!=1 || $3!=0 || $1!~/^-/ || substr($1,6,1)=="w" || substr($1,9,1)=="w" { bad=1 } END { exit NR!=1 || bad }' <<EOF_STATUS_METADATA; then
$(/bin/ls -ldn "$cfmgr_status_path")
EOF_STATUS_METADATA
			printf '[CFMGR] status: warning: required native reporting module unavailable\n'
			exit 1
		fi
	done
	cfmgr_status_prepare || {
		printf '[CFMGR] status: warning: native report context unavailable\n'
		exit 1
	}
	if cfmgr_status_work; then cfmgr_status_code=0; else cfmgr_status_code=$?; fi
	if [ "$cfmgr_status_code" = 3 ]; then
		printf '[CFMGR] status: error: owned probe unresolved; report cleanup required\n'
		exit 3
	fi
	# A signal prevents further collection but reaped children permit cleanup.
	cfmgr_status_interrupted=0
	cfmgr_status_cleanup || {
		printf '[CFMGR] status: warning: report cleanup required\n'
		exit 1
	}
	exit "$cfmgr_status_code"
)

cfmgr_status_work() {
	printf '\nCFMgr %s - local status\n' "$CFMGR_VERSION"
	# Each independent failure retains the remaining native/local report.
	cfmgr_status_now=0 cfmgr_status_boot=unknown cfmgr_status_wan=auto cfmgr_status_clock=0
	if cfmgr_status_run status-date /bin/date; then
		IFS= read -r cfmgr_status_now <"$cfmgr_probe_stdout"
		case $cfmgr_status_now in '' | *[!0-9]* | 0*) cfmgr_status_now=0 ;; esac
	elif [ "$?" = 3 ]; then return 3; fi
	if cfmgr_status_run status-native /usr/bin/awk "$cfmgr_source/modules/lib/status_native.awk" /proc; then
		cfmgr_status_native_output=$cfmgr_probe_stdout
		# Typed receipts contain only allowlisted native resource fields.
		while IFS='	' read -r cfmgr_status_key cfmgr_status_value; do
			case $cfmgr_status_key in
			boot) cfmgr_status_boot=$cfmgr_status_value ;;
			uptime | load | memory) printf '%s: %s\n' "$cfmgr_status_key" "$cfmgr_status_value" ;;
			esac
		done <"$cfmgr_status_native_output"
	else
		[ "$?" != 3 ] || return 3
		printf 'Resources: Unavailable\n'
	fi
	cfmgr_status_config=unavailable
	if cfmgr_status_snapshot "$cfmgr_source/config"; then
		cfmgr_status_config=$cfmgr_status_snapshot_file
		cfmgr_status_config_bytes=$cfmgr_status_snapshot_bytes
		if cfmgr_status_project select; then
			IFS= read -r cfmgr_status_wan <"$cfmgr_probe_stdout"
		else
			[ "$?" != 3 ] || return 3
			cfmgr_status_config=unavailable
		fi
	else
		[ "$?" != 3 ] || return 3
	fi
	# Narrow, fixed nvram get operands; no raw dump and no fallback WAN guess.
	for cfmgr_status_key in productid firmver buildno extendno ntp_ready; do
		cfmgr_status_nvram "$cfmgr_status_key" || return $?
	done
	if [ "$cfmgr_status_wan" = auto ]; then
		cfmgr_status_nvram wan0_primary || return $?
		cfmgr_status_primary0=$cfmgr_status_value
		cfmgr_status_nvram wan1_primary || return $?
		case $cfmgr_status_primary0:$cfmgr_status_value in 1:0) cfmgr_status_wan=0 ;; 0:1) cfmgr_status_wan=1 ;; *) cfmgr_status_wan=unknown ;; esac
	fi
	printf 'Selected WAN: %s\n' "$cfmgr_status_wan"
	case $cfmgr_status_wan in 0 | 1)
		cfmgr_status_nvram "wan${cfmgr_status_wan}_proto" || return $?
		case $cfmgr_status_value in
		dhcp | static) cfmgr_status_nvram "wan${cfmgr_status_wan}_ifname" || return $? ;;
		pppoe | pptp | l2tp) cfmgr_status_nvram "wan${cfmgr_status_wan}_pppoe_ifname" || return $? ;;
		*) printf 'WAN interface: Unknown (unsupported protocol)\n' ;;
		esac
		cfmgr_status_nvram "wan${cfmgr_status_wan}_ipaddr" || return $?
		;;
	*) printf 'WAN interface/address: Unknown\n' ;;
	esac
	for cfmgr_status_target in /jffs /opt; do
		if cfmgr_status_mount "$cfmgr_status_target"; then
			printf '%s mount: ' "$cfmgr_status_target"
			IFS= read -r cfmgr_status_value <"$cfmgr_probe_stdout"
			printf '%s\n' "$cfmgr_status_value"
			if cfmgr_status_space "$cfmgr_status_target"; then
				printf '%s space: ' "$cfmgr_status_target"
				IFS= read -r cfmgr_status_value <"$cfmgr_probe_stdout"
				printf '%s\n' "$cfmgr_status_value"
			else
				[ "$?" != 3 ] || return 3
				printf '%s space: Unavailable\n' "$cfmgr_status_target"
			fi
		else
			[ "$?" != 3 ] || return 3
			printf '%s mount/space: Unavailable or unmounted\n' "$cfmgr_status_target"
		fi
	done
	if cfmgr_status_snapshot "$cfmgr_source/setup-state" &&
		cfmgr_status_fields setup "$cfmgr_status_snapshot_file" "$CFMGR_VERSION"; then
		printf 'Installation: retained setup complete\n'
	else
		[ "$?" != 3 ] || return 3
		printf 'Issue: retained setup incomplete/unavailable; use recovery\n'
	fi
	if cfmgr_status_run status-metadata /bin/ls "$cfmgr_source/.storage-observation"; then
		printf 'Issue: retained storage observation requires cleanup/recovery\n'
	else
		[ "$?" != 3 ] || return 3
	fi
	cfmgr_status_save_pending=0
	for cfmgr_status_save_guard in .config-save.preparing .config-save .config-save.retired; do
		if [ -e "$cfmgr_source/$cfmgr_status_save_guard" ] || [ -L "$cfmgr_source/$cfmgr_status_save_guard" ]; then
			cfmgr_status_save_pending=1
			break
		fi
	done
	[ "$cfmgr_status_save_pending" = 0 ] || printf 'Issue: pending configuration Save/recovery guard; use explicit recovery\n'
	if [ "$cfmgr_status_config" != unavailable ] && cfmgr_status_project render; then
		# The parser emits only a safe typed projection, never input bytes/errors.
		while IFS= read -r cfmgr_status_line; do printf '%s\n' "$cfmgr_status_line"; done <"$cfmgr_probe_stdout"
	else
		[ "$?" != 3 ] || return 3
		printf 'Configuration: Unavailable or invalid; recover retained settings\nDDNS/IP-Sync/Cloudflared: Unknown\nProvider history: Unavailable\n'
	fi
	[ "$cfmgr_status_budget_exhausted" = 0 ] || printf 'Issue: native probe budget exhausted; remaining evidence unavailable\n'
	printf 'Status uses local evidence; no network or feature action was performed.\n\n'
}

cfmgr_status_project() {
	cfmgr_status_run status-config /usr/bin/awk "$cfmgr_source/modules/lib/json.awk" \
		"$cfmgr_source/modules/lib/status.awk" "$cfmgr_status_config" "$1" "$cfmgr_status_now" "$cfmgr_status_boot" \
		"$CFMGR_REPOSITORY" "$CFMGR_BRANCH" "$cfmgr_status_wan" "$cfmgr_status_clock" "$cfmgr_status_config_bytes"
}

cfmgr_status_nvram() {
	cfmgr_status_value=unknown
	if cfmgr_status_run status-nvram /bin/nvram "$1" && cfmgr_status_fields nvram "$cfmgr_probe_stdout" "$1"; then
		IFS= read -r cfmgr_status_value <"$cfmgr_probe_stdout"
		case $1 in wan0_primary | wan1_primary) return 0 ;; ntp_ready) [ "$cfmgr_status_value" != Ready ] || cfmgr_status_clock=1 ;; esac
		printf '%s: %s\n' "$1" "$cfmgr_status_value"
	else
		[ "$?" != 3 ] || return 3
		case $1 in wan0_primary | wan1_primary) return 0 ;; esac
		printf '%s: Unavailable\n' "$1"
	fi
}

# Collection stages exec exactly one owned native command. Projection is a
# separate bounded awk stage, so a hung nvram/df/dd never leaves a wrapper child.
cfmgr_status_fields() {
	cfmgr_status_run status-fields /usr/bin/awk "$cfmgr_source/modules/lib/status_native.awk" "$1" "$2" "$3"
}

cfmgr_status_snapshot() {
	cfmgr_status_run status-metadata /bin/ls "$1" || return $?
	cfmgr_status_fields metadata "$cfmgr_probe_stdout" - || return $?
	IFS=' ' read -r cfmgr_status_snapshot_inode cfmgr_status_snapshot_bytes <"$cfmgr_probe_stdout" || return 1
	cfmgr_status_snapshot_metadata="$cfmgr_status_snapshot_inode $cfmgr_status_snapshot_bytes"
	cfmgr_status_run status-snapshot /bin/dd "$1" || return $?
	cfmgr_status_snapshot_file=$cfmgr_probe_stdout
	cfmgr_status_run status-count /usr/bin/wc "$cfmgr_status_snapshot_file" || return $?
	IFS=' ' read -r cfmgr_status_snapshot_actual cfmgr_status_snapshot_extra <"$cfmgr_probe_stdout" || return 1
	[ -z "$cfmgr_status_snapshot_extra" ] && [ "$cfmgr_status_snapshot_actual" = "$cfmgr_status_snapshot_bytes" ] || return 1
	cfmgr_status_run status-metadata /bin/ls "$1" || return $?
	cfmgr_status_fields metadata "$cfmgr_probe_stdout" - || return $?
	IFS= read -r cfmgr_status_snapshot_after <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_status_snapshot_after" = "$cfmgr_status_snapshot_metadata" ]
}

cfmgr_status_mount() {
	cfmgr_status_run status-realpath /usr/bin/readlink "$1" || return $?
	IFS= read -r cfmgr_status_mount_target <"$cfmgr_probe_stdout" || return 1
	case $cfmgr_status_mount_target in /*) ;; *) return 1 ;; esac
	case $cfmgr_status_mount_target in *[!\ -~]* | *\\* | */../* | */./* | *//*) return 1 ;; esac
	cfmgr_status_run status-mount /usr/bin/awk "$cfmgr_source/modules/lib/mountinfo.awk" "$cfmgr_status_mount_target" || return $?
	cfmgr_status_fields mount "$cfmgr_probe_stdout" "$1"
}

cfmgr_status_space() {
	cfmgr_status_run status-space /bin/df "$1" || return $?
	cfmgr_status_fields space "$cfmgr_probe_stdout" -
}
