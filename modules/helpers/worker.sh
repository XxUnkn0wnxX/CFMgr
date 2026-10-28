#!/bin/sh
# shellcheck disable=SC2034,SC2154 # Explicit fixed category inputs/output fields.
# Fixed supervised process entry modes; no dynamic command loading.
case ${1-} in
dependency)
	shift
	# Fixed in-view installed-opkg launch handshake. No arbitrary command/data eval.
	# FD9 is the copied regular script handoff, FD0 gate, FD1 bounded phase receipt.
	set -f
	umask 077
	[ "$#" -eq 3 ] || exit 2
	# shellcheck disable=SC2034 # All three explicit native paths are admitted as launch ABI.
	awk=$1 readlink=$2 usleep=$3
	for tool; do
		case $tool in /*) ;; *) exit 2 ;; esac
		[ -f "$tool" ] && [ -x "$tool" ] || exit 2
	done
	cd / || exit 2
	script_fd=''
	# ash opened its script with CLOEXEC before running the first command.
	set +f
	for fdinfo in /proc/self/fdinfo/*; do
		fd=${fdinfo##*/}
		case $fd in '' | *[!0-9]*) exit 2 ;; esac
		[ "$fd" -ge 10 ] || continue
		# shellcheck disable=SC3013 # Real held regular-file identity, not a pathname claim.
		if [ "/proc/$$/fd/$fd" -ef /proc/self/fd/9 ] && [ -f "/proc/$$/fd/$fd" ]; then
			[ -z "$script_fd" ] || exit 2
			script_fd=$fd
		else exit 2; fi
	done
	set -f
	[ -n "$script_fd" ] || exit 2
	exec 9<&-
	audit() {
		# Parent descriptor namespace: external native AWK must inspect the ash PID,
		# not /proc/self (which would identify AWK rather than the launch helper).
		(
			set +f
			for audit_info in /proc/"$$"/fdinfo/*; do
				audit_fd=${audit_info##*/}
				case $audit_fd in 0 | 1 | 2) continue ;; esac
				[ "$audit_fd" = "$script_fd" ] && [ -f "/proc/$$/fd/$audit_fd" ] || exit 2
				# shellcheck disable=SC2016
				"$awk" '/^flags:/ { n++; f=$2; p=length(f)-6; if (f !~ /^[0-7]+$/ || p<1 || substr(f,p,1) !~ /^[2367]$/) bad=1 }
			  END { exit n!=1 || bad ? 1 : 0 }' "$audit_info" || exit 2
			done
		)
	}
	audit || exit 2
	printf 'ready END\n'
	IFS=' ' read -r request end extra || exit 2
	[ "$request:$end:$extra" = query:END: ] || exit 2
	# No package data is constrained by this status-query-only file-size limit.
	opkg() (
		PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin:/usr/sbin
		export PATH
		exec /opt/bin/opkg "$@"
	)
	if opkg --version </dev/null >/dev/null 2>/dev/null; then :; else
		code=$?
		printf 'failed version %s END\n' "$code"
		exit 1
	fi
	for package in jq jq-full coreutils-timeout coreutils-sha256sum flock bind-dig; do
		printf 'status %s BEGIN\n' "$package"
		# Pinned opkg status accepts only its first operand. Query each fixed name.
		if (ulimit -f 128 && opkg status "$package" </dev/null) 2>/dev/null; then query_exit=0; else query_exit=$?; fi
		printf '\nstatus %s %s END\n' "$package" "$query_exit"
		[ "$query_exit" -eq 0 ] || exit 1
	done
	printf 'queried 0 END\n'
	# Fixed capped selection comes only from the controller after status validation.
	IFS= read -r request || exit 2
	[ "${#request}" -le 256 ] || exit 2
	old_ifs=$IFS
	IFS=' '
	# Finite tokens become argv, never shell code or arbitrary paths.
	# shellcheck disable=SC2086
	set -- $request
	IFS=$old_ifs
	[ "$#" -ge 3 ] && [ "$#" -le 7 ] && [ "$1" = repair ] || exit 2
	shift
	install='' reinstall=''
	while [ "$#" -gt 1 ]; do
		case $1 in
		i-jq | i-jq-full | i-coreutils-timeout | i-coreutils-sha256sum | i-flock | i-bind-dig) install="$install ${1#i-}" ;;
		r-jq | r-jq-full | r-coreutils-timeout | r-coreutils-sha256sum | r-flock | r-bind-dig) reinstall="$reinstall ${1#r-}" ;;
		*) exit 2 ;;
		esac
		shift
	done
	[ "$1" = END ] || exit 2
	exec 0</dev/null
	audit || exit 2
	printf 'update BEGIN\n'
	if opkg update >/dev/null 2>/dev/null; then :; else
		code=$?
		printf 'failed update %s END\n' "$code"
		exit 1
	fi
	if [ -n "$install" ]; then
		old_ifs=$IFS
		IFS=' '
		# shellcheck disable=SC2086
		set -- $install
		IFS=$old_ifs
		printf 'install BEGIN\n'
		if opkg install "$@" >/dev/null 2>/dev/null; then :; else
			code=$?
			printf 'failed install %s END\n' "$code"
			exit 1
		fi
	fi
	if [ -n "$reinstall" ]; then
		old_ifs=$IFS
		IFS=' '
		# shellcheck disable=SC2086
		set -- $reinstall
		IFS=$old_ifs
		printf 'reinstall BEGIN\n'
		if opkg --force-reinstall install "$@" >/dev/null 2>/dev/null; then :; else
			code=$?
			printf 'failed reinstall %s END\n' "$code"
			exit 1
		fi
	fi
	printf 'complete 0 END\n'

	exit $?
	;;
mount-keeper)
	shift
	# Fixed native-ash mount-reference child, never a package/task supervisor.
	# Recursive redirection frames stay live until explicit identity-checked release.
	# Parent loss, malformed messages, EOF and ordinary signals never unwind pins.
	set -f
	umask 077
	[ "$#" -eq 8 ] || exit 2
	keeper_context=$1 keeper_owner=$2 keeper_owner_start=$3 keeper_boot=$4
	keeper_limit=$5 keeper_awk=$6 keeper_prerequisites=$7 keeper_usleep=$8
	# shellcheck disable=SC1090 # Explicit hash-admitted repository identity utility.
	. "$keeper_prerequisites" || exit 2
	trap '' HUP INT QUIT TERM PIPE USR1 USR2 ALRM
	keeper_sequence=0 keeper_count=0 keeper_broken=0

	# shellcheck disable=SC2154 # Explicit narrow prerequisite identity import.
	keeper_controller() {
		cfmgr_prerequisites_identity "$keeper_owner" || return 1
		if [ "$cfmgr_identity_start" != "$keeper_owner_start" ] || [ "$cfmgr_identity_state" = Z ]; then return 1; fi
		IFS= read -r keeper_current_boot </proc/sys/kernel/random/boot_id || return 1
		[ "$keeper_current_boot" = "$keeper_boot" ]
	}

	keeper_wait() {
		# FD0 now FIFO; surrounding saved redirection frames retain all mount refs.
		printf '%s %s %s END\n' "$1" "$2" "$3" >"$keeper_context/receipt" || keeper_broken=1
		while :; do
			keeper_command='' keeper_next='' keeper_id='' keeper_extra=''
			if ! IFS=' ' read -r keeper_command keeper_next keeper_id keeper_extra; then
				# O_RDWR prevents normal EOF; retain even if read was interrupted/failed.
				keeper_broken=1
				"$keeper_usleep" 100000 || :
				continue
			fi
			# Canonical decimals before any arithmetic: ash treats 08 as invalid octal.
			case $keeper_next in '' | 0* | *[!0-9]*)
				keeper_broken=1
				continue
				;;
			esac
			case $keeper_id in '' | *[!0-9]* | 0?*)
				keeper_broken=1
				continue
				;;
			esac
			if [ -n "$keeper_extra" ] || [ "${#keeper_next}" -gt 9 ] || [ "${#keeper_id}" -gt 10 ]; then
				keeper_broken=1
				continue
			fi
			if [ "$keeper_next" != "$((keeper_sequence + 1))" ]; then
				keeper_broken=1
				continue
			fi
			keeper_controller || {
				keeper_broken=1
				continue
			}
			keeper_sequence=$keeper_next
			case $keeper_command in
			release)
				[ "$keeper_id" = 0 ] || {
					keeper_broken=1
					continue
				}
				printf 'released %s 0 END\n' "$keeper_sequence" >"$keeper_context/receipt" || {
					keeper_broken=1
					continue
				}
				return 0
				;;
			hold)
				if [ "$keeper_broken" -ne 0 ] || [ "$keeper_id" = 0 ] || [ "$keeper_count" -ge "$keeper_limit" ]; then
					printf 'failed %s %s END\n' "$keeper_sequence" "$keeper_id" >"$keeper_context/receipt" || keeper_broken=1
					continue
				fi
				# Only the verified controller's already-proved FD4 is transferred.
				if keeper_next_frame "$keeper_sequence" "$keeper_id" <"/proc/$keeper_owner/fd/4"; then return 0; fi
				printf 'failed %s %s END\n' "$keeper_sequence" "$keeper_id" >"$keeper_context/receipt" || keeper_broken=1
				;;
			*) keeper_broken=1 ;;
			esac
		done
	}

	keeper_next_frame() {
		# ACK only inside the frame opened from the controller descriptor.
		# shellcheck disable=SC2016
		if [ -d /proc/self/fd/0 ] || [ -f /proc/self/fd/0 ]; then
			if "$keeper_awk" -v expected="$2" '/^mnt_id:/ { n++; if ($2!=expected) bad=1 } END { exit n!=1 || bad ? 1 : 0 }' "/proc/$$/fdinfo/0"; then
				keeper_count=$((keeper_count + 1))
				keeper_wait held "$1" "$2" <&3
				return $?
			fi
		fi
		# An opened but mismatched object is uncertainty; never unwind its frame.
		keeper_broken=1
		keeper_wait uncertain "$1" "$2" <&3
	}

	keeper_controller || exit 2
	keeper_wait ready 0 0 <&3

	exit $?
	;;
esac
# shellcheck disable=SC2034 # Fixed sourced view parser consumes explicit fields.
# Fixed prerequisite probes. Paths are admitted by the caller, never discovered here.
set -f
case $(($# >= 1)) in 1) ;; *) exit 2 ;; esac
mode=$1
shift
case "$mode" in
exit-seven)
	[ "$#" -eq 0 ] || exit 2
	exit 7
	;;
sleep-short)
	[ "$#" -eq 2 ] || exit 2
	# Direct workstation tests can exercise GNU timeout, but cannot prove
	# Linux ownership. The production supervisor rejects hosts without proc.
	[ -r /proc/self/stat ] || exec "$1" 1
	# Before exec, record the one child GNU timeout owns. No child commands here.
	IFS= read -r boot </proc/sys/kernel/random/boot_id || exit 2
	IFS= read -r identity </proc/self/stat || exit 2
	pid=${identity%% *}
	tail=${identity##*) }
	old_ifs=$IFS
	IFS=' '
	# Linux stat's numeric tail is deliberately split; pathname expansion is off.
	# shellcheck disable=SC2086
	set -- "$1" "$2" $tail
	IFS=$old_ifs
	native_sleep=$1
	context=$2
	shift 2
	ppid=$2
	shift 19
	start=$1
	set -C
	printf '%s %s %s %s\n' "$pid" "$ppid" "$start" "$boot" >"$context/timeout.child" || exit 2
	exec "$native_sleep" 1
	;;
esac
case $(($# >= 2)) in 1) ;; *) exit 2 ;; esac
tool=$1
context=$2
shift 2
case "$tool:$context" in /*:/*) ;; *) exit 2 ;; esac
[ -f "$tool" ] && [ -x "$tool" ] && [ -d "$context" ] || exit 2
cd "$context" || exit 2
case $mode in health-* | diagnostic-*)
	set +x
	set +v
	ulimit -c 0 || exit 2
	;;
esac
# Health owns distinct reservations/deadlines; these fixed bodies remain the
# same native, read-only implementations. No installation mutation alias exists.
case $mode in
health-snapshot) mode=status-snapshot ;;
health-config) mode=status-config ;;
health-native) mode=status-native ;;
health-fields) mode=status-fields ;;
health-metadata) mode=status-metadata ;;
health-count) mode=status-count ;;
health-date) mode=status-date ;;
health-nvram) mode=status-nvram ;;
health-space) mode=status-space ;;
health-mount) mode=status-mount ;;
health-render-count) mode=status-count ;;
status-render-count) mode=status-count ;;
health-curl-version) mode=native-curl-version ;;
health-curl-features) mode=native-curl-features ;;
health-ca-pem) mode=native-ca-pem ;;
health-ca-decode) mode=native-ca-decode ;;
health-curl-offline) mode=native-curl-offline ;;
esac
case $mode in
health-log-account) mode=history-account ;;
health-log-pids) cfmgr_worker_health_pids=1 mode=history-proc-list ;;
health-log-link) mode=history-readlink ;;
health-log-proc-meta) mode=history-proc-meta ;;
health-log-hex) mode=history-hexdump ;;
health-log-argv) mode=history-argv ;;
health-log-version) mode=history-syslog-version ;;
health-log-syntax) mode=history-syslog-check ;;
health-log-debug) mode=history-logrotate-debug ;;
health-log-cron) mode=history-cron-read ;;
esac
case $mode in
health-jq-good | health-jq-bad | health-sha-bytes | health-sha-good | health-sha-bad | health-timeout-exit | health-timeout-expiry | health-flock-first | health-flock-compete | health-flock-after | health-flock-release | health-flock-finish | health-flock-entware-first | health-flock-entware-compete | health-flock-entware-after | health-flock-entware-release | health-flock-entware-finish | health-dig-version | health-blkid) mode=${mode#health-} ;;
esac
cfmgr_worker_program() {
	# Import only the fixed category required by this admitted mode.
	# shellcheck disable=SC1090 # Explicit package-admitted category operands.
	case $mode in
	store-archive-plan | history-policy-json | archive-payload-json)
		case $1 in */lib) ;; *) exit 2 ;; esac
		. "$1/config.sh" || exit 2
		. "${1%/lib}/backup.sh" || exit 2
		;;
	diagnostic-config | store-archive-config | store-backup-config | store-settings)
		. "$1" || exit 2
		;;
	launch-config-check | launch-config-scope | launch-config-observe | launch-config-patch)
		. "$2" || exit 2
		;;
	install-config-check)
		. "$2/modules/lib/config.sh" || exit 2
		;;
	status-config | health-inventory | health-scope | health-request | health-response | health-cloud-plan | health-cloud-authority | health-backup-plan | status-render | health-render)
		. "$1" || exit 2
		case $mode in status-render | health-render) ;; *) . "$2" || exit 2 ;; esac
		;;
	archive-control | archive-browser-review | archive-browser-manifest | history-writer-parse | history-parse | history-mount | archive-payload-yaml | archive-payload-index | archive-payload-match | archive-payload-pem | archive-tar-header | archive-format-manifest | archive-format-inventory | archive-source-mount | store-backup-mounts | store-backup-mount | diagnostic-mount | status-native | status-fields | status-mount | repair-inventory | health-request-check | health-trace | health-frame)
		. "$1" || exit 2
		;;
	esac
	case $mode in
	health-inventory | health-scope | health-request | health-cloud-plan | health-cloud-authority | health-backup-plan)
		cfmgr_config_awk_json
		cfmgr_worker_json=$cfmgr_awk_program
		cfmgr_config_awk_config_schema
		cfmgr_worker_json="$cfmgr_worker_json
$cfmgr_awk_program"
		cfmgr_config_awk_config_observation
		cfmgr_worker_json="$cfmgr_worker_json
$cfmgr_awk_program"
		case $mode in health-backup-plan) cfmgr_status_awk_health_backup_plan ;; health-cloud-plan | health-cloud-authority) cfmgr_status_awk_health_cloud ;; *) cfmgr_status_awk_health ;; esac
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	health-response)
		cfmgr_config_awk_json
		cfmgr_worker_json=$cfmgr_awk_program
		cfmgr_status_awk_health_wire
		cfmgr_worker_json="$cfmgr_worker_json
$cfmgr_awk_program"
		cfmgr_status_awk_health_response
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	health-request-check | health-trace | health-frame) cfmgr_status_awk_health_wire ;;
	store-archive-plan | archive-payload-json)
		cfmgr_config_awk_json
		cfmgr_worker_json=$cfmgr_awk_program
		if [ "$mode" = store-archive-plan ] || [ "$2" = plan ]; then
			cfmgr_config_awk_config_schema
			cfmgr_worker_json="$cfmgr_worker_json
$cfmgr_awk_program"
			cfmgr_config_awk_config_observation
			cfmgr_worker_json="$cfmgr_worker_json
$cfmgr_awk_program"
		fi
		cfmgr_backup_awk_backup_payload
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	history-policy-json)
		cfmgr_config_awk_json
		cfmgr_worker_json=$cfmgr_awk_program
		cfmgr_backup_awk_backup_history
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	diagnostic-config | store-archive-config | store-backup-config | store-settings | launch-config-check | launch-config-scope | launch-config-observe | launch-config-patch | install-config-check)
		cfmgr_config_awk_json
		cfmgr_worker_json=$cfmgr_awk_program
		cfmgr_config_awk_config_schema
		cfmgr_worker_json="$cfmgr_worker_json
$cfmgr_awk_program"
		cfmgr_config_awk_config_observation
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	status-config)
		cfmgr_config_awk_json
		cfmgr_worker_json=$cfmgr_awk_program
		cfmgr_status_awk_status
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	archive-control | archive-browser-review) cfmgr_backup_awk_backup_archive_control ;;
	history-parse) cfmgr_backup_awk_backup_history ;;
	history-writer-parse) cfmgr_backup_awk_backup_cloud_writer ;;
	history-mount | archive-source-mount | store-backup-mounts | store-backup-mount | status-mount | diagnostic-mount | repair-inventory) cfmgr_storage_awk_mountinfo ;;
	archive-payload-yaml) cfmgr_backup_awk_backup_yaml ;;
	archive-payload-index) cfmgr_backup_awk_backup_payload_index ;;
	archive-payload-match) cfmgr_backup_awk_backup_payload_match ;;
	archive-payload-pem) cfmgr_backup_awk_backup_pem ;;
	archive-tar-header) cfmgr_backup_awk_backup_tar ;;
	archive-format-manifest | archive-browser-manifest) cfmgr_backup_awk_backup_manifest ;;
	archive-format-inventory)
		cfmgr_backup_awk_backup_manifest
		cfmgr_worker_json=$cfmgr_awk_program
		cfmgr_backup_awk_backup_inventory
		cfmgr_awk_program="$cfmgr_worker_json
$cfmgr_awk_program"
		;;
	status-native | status-fields) cfmgr_status_awk_status_native ;;
	status-render | health-render) cfmgr_status_awk_health_render ;;
	esac
	# Merlin MAX_ARG_STRLEN is 32 4K pages. Keep a conservative 96KiB program
	# cap, leaving per-argument headroom and room for bounded argv/environment data.
	case $((${#cfmgr_awk_program} <= 98304)) in 1) ;; *) exit 2 ;; esac
}

cfmgr_worker_health_input() {
	# A private input is one regular child of the attached report context.
	case $1 in "$context"/*) ;; *) return 2 ;; esac
	case ${1#"$context"/} in '' | *[!A-Za-z0-9._-]* | *..*) return 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ]
}
# Acquisition aliases retain the supervisor's distinct native-only admission;
# their executable/grammar is the same fixed trusted bootstrap implementation.
case $mode in
diagnostic-scribe-authority)
	[ "$#" -eq 5 ] || exit 2
	for cfmgr_scribe_parser in "$1" "$2" "$3"; do [ -f "$cfmgr_scribe_parser" ] && [ ! -L "$cfmgr_scribe_parser" ] || exit 1; done
	case $5 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$5" -le 65536 ] && [ -f "$4" ] && [ ! -L "$4" ] || exit 2
	# shellcheck disable=SC1090 # Fixed package-admitted category operands only.
	. "$1" || exit 2
	# shellcheck disable=SC1090 # Fixed package-admitted category operands only.
	. "$2" || exit 2
	# shellcheck disable=SC1090 # Fixed package-admitted category operands only.
	. "$3" || exit 2
	cfmgr_config_awk_json
	cfmgr_scribe_program=$cfmgr_awk_program
	cfmgr_config_awk_config_schema
	cfmgr_scribe_program="$cfmgr_scribe_program
$cfmgr_awk_program"
	cfmgr_config_awk_config_observation
	cfmgr_scribe_program="$cfmgr_scribe_program
$cfmgr_awk_program"
	cfmgr_backup_awk_backup_history_policy
	cfmgr_scribe_program="$cfmgr_scribe_program
$cfmgr_awk_program"
	cfmgr_status_awk_health_logging_authority
	cfmgr_scribe_program="$cfmgr_scribe_program
$cfmgr_awk_program"
	[ "${#cfmgr_scribe_program}" -le 98304 ] || exit 2
	exec 3<"$4" || exit 1
	[ "$4" -ef /proc/self/fd/3 ] && [ ! -L "$4" ] || exit 1
	exec 9<&0 || exit 2
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" -v cfmgr_config_mode=archive-data "$cfmgr_scribe_program" <&3
	;;
diagnostic-list)
	[ "$#" -eq 0 ] && [ -d /proc/self/fd/3 ] || exit 2
	exec "$tool" -1A /proc/self/fd/3
	;;
diagnostic-digest)
	[ "$#" -eq 0 ] && [ -f /proc/self/fd/3 ] || exit 2
	exec 9<&0 || exit 2
	exec "$tool" dgst -sha256 -r <&3
	;;
diagnostic-source)
	[ "$#" -eq 1 ] && [ -f /proc/self/fd/3 ] || exit 2
	case $1 in '' | *[!0-9]* | 0[0-9]*) exit 2 ;; esac
	[ "${#1}" -le 7 ] && [ "$1" -le 2097152 ] || exit 2
	exec 9<&0 || exit 2
	exec "$tool" bs=1024 "skip=$1" count=24 <&3 2>/dev/null
	;;
diagnostic-count)
	[ "$#" -eq 0 ] && [ -f /proc/self/fd/3 ] || exit 2
	exec 9<&0 || exit 2
	exec "$tool" -c <&3
	;;
diagnostic-frame)
	[ "$#" -eq 3 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f /proc/self/fd/3 ] || exit 2
	case $2 in '' | *[!0-9]* | 0[0-9]*) exit 2 ;; esac
	[ "$2" -le 24576 ] || exit 2
	case $3 in 0 | 1) ;; *) exit 2 ;; esac
	# shellcheck disable=SC1090 # Fixed package-admitted category operands only.
	. "$1" || exit 2
	cfmgr_logging_awk_log_frame
	exec 9<&0 || exit 2
	exec "$tool" -v expected_bytes="$2" -v excerpt="$3" "$cfmgr_awk_program" <&3
	;;
diagnostic-sanitize)
	[ "$#" -eq 5 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] && [ -f /proc/self/fd/3 ] || exit 2
	case $3 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$3" -le 65536 ] || exit 2
	case $4 in 0 | 1) ;; *) exit 2 ;; esac
	case $5 in ddns | ip_sync | cloudflared) ;; *) exit 2 ;; esac
	# shellcheck disable=SC1090 # Fixed package-admitted category operands only.
	. "$1" || exit 2
	# shellcheck disable=SC1090 # Fixed package-admitted category operands only.
	. "$2" || exit 2
	cfmgr_config_awk_json
	cfmgr_scribe_program=$cfmgr_awk_program
	cfmgr_logging_awk_log_sanitize
	cfmgr_scribe_program="$cfmgr_scribe_program
$cfmgr_awk_program"
	[ "${#cfmgr_scribe_program}" -le 98304 ] || exit 2
	exec 9<&0 || exit 2
	exec "$tool" -v cfmgr_json_size="$3" -v cfmgr_json_mode=tree -v cfmgr_log_excerpt="$4" -v cfmgr_log_source="$5" "$cfmgr_scribe_program" <&3
	;;
diagnostic-compare)
	[ "$#" -eq 0 ] && [ -f /proc/self/fd/3 ] && [ -f /proc/self/fd/4 ] || exit 2
	exec "$tool" -s /proc/self/fd/3 /proc/self/fd/4
	;;

diagnostic-date)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -u '+%Y-%m-%dT%H:%M:%SZ'
	;;

diagnostic-realpath)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	exec "$tool" -f "$1"
	;;
diagnostic-meta)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	exec "$tool" -ildn "$1"
	;;
diagnostic-mount)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in /*) ;; *) exit 2 ;; esac
	# cfmgr_worker_program imports storage.sh and selects mountinfo AWK.
	cfmgr_worker_program "$@" || exit 2
	exec "$tool" "$cfmgr_awk_program" "$2" /proc/self/mountinfo
	;;
diagnostic-mkdir)
	[ "$#" -eq 1 ] && [ -d /proc/self/fd/7 ] || exit 2
	case $1 in '' | . | .. | */* | *[!\ -~]*) exit 2 ;; esac
	exec "$tool" -m 700 "/proc/self/fd/7/$1"
	;;
diagnostic-create)
	[ "$#" -eq 1 ] && [ -d /proc/self/fd/7 ] || exit 2
	case $1 in developer.log | health-[0-9a-f]*.log | scribe-[A-Za-z0-9._-]*.log) ;; *) exit 2 ;; esac
	case $1 in *[!A-Za-z0-9._-]* | *..*) exit 2 ;; esac
	umask 077
	set -C
	: >"/proc/self/fd/7/$1" || exit 1
	exit 0
	;;
diagnostic-lock)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 0
	;;
diagnostic-copy | diagnostic-tail)
	[ "$#" -eq 1 ] && [ -f /proc/self/fd/3 ] && [ -f /proc/self/fd/4 ] || exit 2
	case $1 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	case $mode in
	diagnostic-copy)
		[ "$1" -le 48 ] || exit 2
		set -- bs=4096 "count=$1"
		;;
	diagnostic-tail)
		[ "$1" -le 4095 ] || exit 2
		set -- bs=1 "count=$1"
		;;
	esac
	# Do not cap total retained file size. The input extent is independently
	# bounded and the direct native writer remains the supervised child.
	# shellcheck disable=SC3045 # Native BusyBox soft limit; bounded input controls append size.
	ulimit -S -f unlimited || exit 2
	# stdin becomes the bounded stage, so the capture lock must first be
	# duplicated into FD9; the native child then holds it through exec.
	exec 9<&0 || exit 2
	exec "$tool" "$@" <&3 >&4 2>/dev/null
	;;
diagnostic-convert)
	[ "$#" -eq 2 ] || exit 2
	case $1 in encode | decode) ;; *) exit 2 ;; esac
	# Source value travels as an argv operand, never an awk -v assignment.
	exec "$tool" 'BEGIN {
		mode=ARGV[1]; value=ARGV[2]; ARGV[1]=ARGV[2]="";
		digits="0123456789abcdef"; for (i=32;i<=126;i++) ordinal[sprintf("%c",i)]=i;
		if (mode=="encode") {
			if (length(value)<1 || length(value)>1024) exit 1;
			for (i=1;i<=length(value);i++) {c=substr(value,i,1); if (!(c in ordinal)) exit 1; n=ordinal[c]; out=out sprintf("%02x",n)}
		} else {
			if (length(value)<2 || length(value)>2048 || length(value)%2 || value !~ /^[0-9a-f]+$/) exit 1;
			for (i=1;i<=length(value);i+=2) {n=(index(digits,substr(value,i,1))-1)*16+index(digits,substr(value,i+1,1))-1; if (n<32 || n>126) exit 1; out=out sprintf("%c",n)}
		}
		print out
	}' "$1" "$2"
	;;
diagnostic-config)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f /proc/self/fd/3 ] || exit 2
	case $2 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$2" -le 65536 ] || exit 2
	# Preserve the capture lock through exec when redirecting stdin to JSON.
	exec 9<&0 || exit 2
	cfmgr_worker_program "$@" || exit 2
	exec "$tool" -v cfmgr_config_mode=diagnostic-read -v cfmgr_json_mode=tree -v cfmgr_json_size="$2" "$cfmgr_awk_program" <&3
	;;
diagnostic-header)
	[ "$#" -eq 0 ] && [ -f /proc/self/fd/3 ] || exit 2
	exec 9<&0 || exit 2
	exec "$tool" bs=1 count=18 <&3 2>/dev/null
	;;
acquire-curl-version) mode=native-curl-version ;;
acquire-curl-offline) mode=native-curl-offline ;;
acquire-curl-features) mode=native-curl-features ;;
acquire-ca-pem) mode=native-ca-pem ;;
acquire-ca-decode) mode=native-ca-decode ;;
acquire-wc) mode='install-wc' ;;
acquire-ls) mode='install-ls' ;;
esac
case "$mode" in
health-realpath)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in /*) ;; *) exit 2 ;; esac
	case $1 in *[!\ -~]* | *\\*) exit 2 ;; esac
	case $((${#1} <= 4096)) in 1) ;; *) exit 2 ;; esac
	exec "$tool" -f "$1"
	;;
health-native-metadata)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in
	busybox) set -- /usr/bin /bin /bin/busybox ;;
	regular) set -- /usr/bin /usr/bin/flock ;;
	missing) set -- ;;
	*) exit 2 ;;
	esac
	exec "$tool" -ildn / /usr /usr/sbin /usr/sbin/curl /usr/sbin/openssl /rom /rom/etc /rom/etc/ssl /rom/etc/ssl/certs /rom/etc/ssl/certs/ca-certificates.crt "$@"
	;;
health-entware-metadata)
	case $(($# >= 1 && $# <= 13)) in 1) ;; *) exit 2 ;; esac
	for metadata_path; do
		case $metadata_path in /*) ;; *) exit 2 ;; esac
		case $metadata_path in *[!\ -~]* | *\\*) exit 2 ;; esac
		case $((${#metadata_path} <= 4096)) in 1) ;; *) exit 2 ;; esac
	done
	exec "$tool" -ildn "$@"
	;;
health-metadata-check)
	case $# in 4) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $3 in native | entware) ;; *) exit 2 ;; esac
	case $((${#4} <= 32768)) in 1) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	cfmgr_status_awk_health_metadata
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4"
	;;
health-compare)
	case $# in 2) ;; *) exit 2 ;; esac
	[ "$2" = "$context/comparison" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	. "$1" || exit 2
	cfmgr_status_awk_health_wire
	comparison_wire=$cfmgr_awk_program
	cfmgr_status_awk_health_compare
	cfmgr_awk_program="$comparison_wire
$cfmgr_awk_program"
	case $((${#cfmgr_awk_program} <= 98304)) in 1) ;; *) exit 2 ;; esac
	export CFMGR_HEALTH_MODE=health-compare
	exec "$tool" "$cfmgr_awk_program" "$2" "$context"
	;;
health-log-authority)
	case $# in 5) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	. "$2" || exit 2
	. "$3" || exit 2
	case $5 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$5" -le 65536 ] && [ -f "$4" ] && [ ! -L "$4" ] || exit 2
	cfmgr_config_awk_json
	log_program=$cfmgr_awk_program
	cfmgr_config_awk_config_schema
	log_program="$log_program
$cfmgr_awk_program"
	cfmgr_config_awk_config_observation
	log_program="$log_program
$cfmgr_awk_program"
	cfmgr_backup_awk_backup_history_policy
	log_program="$log_program
$cfmgr_awk_program"
	cfmgr_status_awk_health_logging_authority
	cfmgr_awk_program="$log_program
$cfmgr_awk_program"
	case $((${#cfmgr_awk_program} <= 98304)) in 1) ;; *) exit 2 ;; esac
	exec 8<"$4" || exit 1
	[ "$4" -ef /proc/self/fd/8 ] && [ ! -L "$4" ] || exit 1
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" -v cfmgr_config_mode=archive-data "$cfmgr_awk_program" <&8
	;;
health-log-inspect | health-log-process)
	case $# in 5) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	cfmgr_status_awk_health_logging
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4" "$5"
	;;
health-log-metadata | health-log-hash | health-log-count)
	case $(($# >= 1 && $# <= 13)) in 1) ;; *) exit 2 ;; esac
	for log_path; do
		case $log_path in /*) ;; *) exit 2 ;; esac
		case $log_path in *[!\ -~]* | *\\* | */../* | */./* | *//*) exit 2 ;; esac
		case $((${#log_path} <= 1024)) in 1) ;; *) exit 2 ;; esac
	done
	case $mode in
	health-log-metadata) exec "$tool" -ildn "$@" ;;
	health-log-hash) exec "$tool" dgst -sha256 -r "$@" ;;
	health-log-count) exec "$tool" -lc "$@" ;;
	esac
	;;
health-log-script)
	case $# in 2) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec 8<"$1" || exit 1
	[ "$1" -ef /proc/self/fd/8 ] || exit 1
	exec "$tool" bs=8192 count=1 <&8 2>/dev/null
	;;
health-log-includes | health-log-bundle | health-log-base | health-log-assess | health-log-path)
	. "$1" || exit 2
	cfmgr_backup_awk_backup_history
	export CFMGR_HISTORY_LIMIT=11534336
	case $mode in
	health-log-includes)
		case $# in 4) ;; *) exit 2 ;; esac
		export CFMGR_HISTORY_MODE=includes-raw CFMGR_HISTORY_CONTEXT="$context" CFMGR_HISTORY_RAW_NAME="${2##*/}" CFMGR_HISTORY_RAW_BYTES="$3" CFMGR_HISTORY_RAW_LF="$4"
		exec "$tool" "$cfmgr_awk_program" </dev/null
		;;
	health-log-bundle)
		case $# in 3) ;; *) exit 2 ;; esac
		export CFMGR_HISTORY_MODE=health-bundle CFMGR_HISTORY_CONTEXT="$context" CFMGR_HISTORY_BUNDLE_LIMIT="$3"
		;;
	health-log-base)
		case $# in 2) ;; *) exit 2 ;; esac
		export CFMGR_HISTORY_MODE=base
		;;
	health-log-path)
		case $# in 2) ;; *) exit 2 ;; esac
		export CFMGR_HISTORY_MODE=path CFMGR_HISTORY_LABEL="$2"
		exec "$tool" "$cfmgr_awk_program" </dev/null
		;;
	health-log-assess)
		case $# in 5) ;; *) exit 2 ;; esac
		case $5 in ddns | ip_sync | cloudflared) ;; *) exit 2 ;; esac
		[ -f "$3" ] && [ ! -L "$3" ] || exit 2
		export CFMGR_HISTORY_MODE=health-assess CFMGR_HISTORY_POLICY_FILE="$3" CFMGR_HISTORY_POLICY_BYTES="$4" CFMGR_HISTORY_FEATURE="$5"
		;;
	esac
	[ -f "$2" ] && [ ! -L "$2" ] || exit 2
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
health-flat-list)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in /jffs/addons/CFMgr.d | /jffs/addons/CFMgr.d/modules | /jffs/addons/CFMgr.d/modules/lib | /jffs/addons/CFMgr.d/modules/helpers | /jffs/addons/CFMgr.d/modules/hooks) ;; *) exit 2 ;; esac
	[ -d "$1" ] && [ ! -L "$1" ] || exit 1
	exec 8<"$1" || exit 1
	[ "$1" -ef /proc/self/fd/8 ] && [ ! -L "$1" ] || exit 1
	cd /proc/self/fd/8 || exit 1
	[ "$1" -ef . ] && [ ! -L "$1" ] || exit 1
	ulimit -v 65536 || exit 2
	exec "$tool" -1A .
	;;
health-flat-check)
	case $# in 5) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$2" || exit 2
	. "$1" || exit 2
	cfmgr_status_awk_health_flat
	ulimit -v 65536 || exit 2
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4" "$5"
	;;
health-package-check)
	case $# in 3) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$3" || exit 2
	. "$1" || exit 2
	. "$2" || exit 2
	cfmgr_package_awk_package_records
	package_program=$cfmgr_awk_program
	cfmgr_status_awk_health_package
	cfmgr_awk_program="$package_program
$cfmgr_awk_program"
	case $((${#cfmgr_awk_program} <= 98304)) in 1) ;; *) exit 2 ;; esac
	ulimit -v 65536 || exit 2
	exec "$tool" "$cfmgr_awk_program" "$context" "$3"
	;;

health-hooks-authority)
	case $# in 4) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$3" || exit 2
	case $4 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	case $((${#4} <= 5)) in 1) ;; *) exit 2 ;; esac
	[ "$4" -le 65536 ] || exit 2
	. "$1" || exit 2
	. "$2" || exit 2
	cfmgr_config_awk_json
	hooks_program=$cfmgr_awk_program
	cfmgr_config_awk_config_schema
	hooks_program="$hooks_program
$cfmgr_awk_program"
	cfmgr_config_awk_config_observation
	hooks_program="$hooks_program
$cfmgr_awk_program"
	cfmgr_status_awk_health_hooks_authority
	cfmgr_awk_program="$hooks_program
$cfmgr_awk_program"
	case $((${#cfmgr_awk_program} <= 98304)) in 1) ;; *) exit 2 ;; esac
	exec 8<"$3" || exit 1
	[ "$3" -ef /proc/self/fd/8 ] && [ ! -L "$3" ] || exit 1
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$4" -v cfmgr_config_mode=archive-data "$cfmgr_awk_program" <&8
	;;
health-hooks-cron)
	case $# in 6) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$2" && cfmgr_worker_health_input "$3" || exit 2
	. "$1" || exit 2
	cfmgr_status_awk_health_hooks_cron
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4" "$5" "$6"
	;;
health-hooks-frame)
	case $# in 4) ;; *) exit 2 ;; esac
	case $2 in authority | jobs) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$3" || exit 2
	. "$1" || exit 2
	cfmgr_status_awk_health_hooks_frame
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4"
	;;

health-backup-plan)
	case $# in 6) ;; *) exit 2 ;; esac
	case $3 in "$context"/health-*.out) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$3" || exit 2
	case $4:$5:$6 in *[!0-9:]* | :* | *::*) exit 2 ;; esac
	case $((${#4} <= 5 && ${#5} <= 10)) in 1) ;; *) exit 2 ;; esac
	[ "$4" -gt 0 ] && [ "$4" -le 65536 ] || exit 2
	case $6 in 0 | 1) ;; *) exit 2 ;; esac
	export CFMGR_HEALTH_BACKUP_NOW="$5" CFMGR_HEALTH_BACKUP_CLOCK="$6"
	exec 8<"$3" || exit 1
	[ -f /proc/self/fd/8 ] && [ "$3" -ef /proc/self/fd/8 ] && [ ! -L "$3" ] || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$4" -v cfmgr_config_mode=archive-data "$cfmgr_awk_program" <&8
	;;
health-backup-observe)
	case $# in 5) ;; *) exit 2 ;; esac
	case $2 in frame | mount | identity | folder) ;; *) exit 2 ;; esac
	for backup_input in "$3" "$4" "$5"; do
		case $backup_input in -) continue ;; "$context"/health-*.out) ;; *) exit 2 ;; esac
		cfmgr_worker_health_input "$backup_input" || exit 2
	done
	[ "$3" != - ] || exit 2
	case $2:$4:$5 in frame:-:- | mount:*:- | identity:*:* | folder:*:-) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	cfmgr_status_awk_health_backup_observation
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4" "$5"
	;;
health-backup-uuid)
	case $# in 4) ;; *) exit 2 ;; esac
	case $2 in "$context"/health-blkid.*.out) ;; *) exit 2 ;; esac
	cfmgr_worker_health_input "$2" || exit 2
	case $3 in /dev/*) ;; *) exit 2 ;; esac
	case $3 in *[!A-Za-z0-9_./-]* | */../* | */./* | *//*) exit 2 ;; esac
	case $4 in '' | *[!A-Za-z0-9_+.-]*) exit 2 ;; esac
	case $((${#3} <= 1024 && ${#4} <= 32)) in 1) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	cfmgr_backup_awk_backup_uuid
	exec "$tool" "$cfmgr_awk_program" "$3" "$4" "$2"
	;;
health-cloud-frame)
	case $# in 3) ;; *) exit 2 ;; esac
	case $3 in plan | join) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	cfmgr_status_awk_health_selected
	exec "$tool" "$cfmgr_awk_program" "frame-$3" "$2" - - -
	;;
health-cloud-plan | health-cloud-authority)
	case $# in 5) ;; *) exit 2 ;; esac
	case $5 in plan | runtime-authority | certificate-account) ;; *) exit 2 ;; esac
	case $mode:$5 in health-cloud-plan:plan | health-cloud-authority:runtime-authority | health-cloud-authority:certificate-account) ;; *) exit 2 ;; esac
	[ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $4 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$4" -le 65536 ] || exit 2
	export CFMGR_HEALTH_CLOUD="$5"
	exec 8<"$3" || exit 1
	[ -f /proc/self/fd/8 ] && [ "$3" -ef /proc/self/fd/8 ] && [ ! -L "$3" ] || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$4" -v cfmgr_config_mode=archive-data "$cfmgr_awk_program" <&8
	;;
health-selected-check | health-cloud-join)
	case $# in 5) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	cfmgr_status_awk_health_selected
	case $mode in health-selected-check)
		export CFMGR_HEALTH_SELECTED_PATH="$5"
		set -- metadata "$2" "$3" "$4"
		;;
	*) set -- yaml-join "$2" "$3" "$4" "$5" ;; esac
	exec "$tool" "$cfmgr_awk_program" "$@"
	;;
health-selected-metadata)
	case $(($# >= 1 && $# <= 13)) in 1) ;; *) exit 2 ;; esac
	for selected_path; do
		case $selected_path in /*) ;; *) exit 2 ;; esac
		case $selected_path in *[!\ -~]* | *\\*) exit 2 ;; esac
		case $((${#selected_path} <= 1024)) in 1) ;; *) exit 2 ;; esac
	done
	exec "$tool" -ildn "$@"
	;;
health-selected-copy | health-selected-hex | health-selected-hash)
	case $# in 2) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in '' | *[!0-9]* | 0?*) exit 2 ;; esac
	case $((${#2} <= 10)) in 1) ;; *) exit 2 ;; esac
	exec 8<"$1" || exit 1
	[ -f /proc/self/fd/8 ] && [ "$1" -ef /proc/self/fd/8 ] && [ ! -L "$1" ] || exit 1
	case $mode in
	health-selected-copy) exec "$tool" bs=4096 count="$((($2 + 4095) / 4096 + 1))" <&8 2>/dev/null ;;
	health-selected-hex) exec "$tool" -v -n "$2" -e '1/1 "%02x\n"' <&8 ;;
	health-selected-hash) exec "$tool" dgst -sha256 -r <&8 ;;
	esac
	;;
health-cloud-yaml | health-cloud-pem)
	case $# in 2) ;; *) exit 2 ;; esac
	. "$1" || exit 2
	case $mode in
	health-cloud-yaml)
		export CFMGR_YAML_METADATA_LIMIT=262144
		cfmgr_backup_awk_backup_yaml
		;;
	health-cloud-pem)
		export CFMGR_PEM_MODE=health-base64
		cfmgr_backup_awk_backup_pem
		;;
	esac
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
health-cloud-decode)
	case $# in 1) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" base64 -d -A -in "$1"
	;;
health-cloud-json)
	case $# in 5) ;; *) exit 2 ;; esac
	case $2 in runtime-json | certificate-json) ;; *) exit 2 ;; esac
	case $4 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$4" -le 65536 ] && [ -f "$3" ] && [ ! -L "$3" ] && [ -f "$5" ] && [ ! -L "$5" ] || exit 2
	# Only an owned authority file path crosses the environment boundary.
	case $2 in runtime-json) export CFMGR_PAYLOAD_AUTHORITY="$5" ;; certificate-json) export CFMGR_PAYLOAD_ACCOUNT_FILE="$5" ;; esac
	export CFMGR_PAYLOAD_MODE="$2" CFMGR_PAYLOAD_HEALTH=1
	. "$1/config.sh" || exit 2
	. "${1%/lib}/backup.sh" || exit 2
	cfmgr_config_awk_json
	cloud_json=$cfmgr_awk_program
	cfmgr_backup_awk_backup_payload
	cfmgr_awk_program="$cloud_json
$cfmgr_awk_program"
	case $((${#cfmgr_awk_program} <= 98304)) in 1) ;; *) exit 2 ;; esac
	exec 8<"$3" || exit 1
	[ -f /proc/self/fd/8 ] && [ "$3" -ef /proc/self/fd/8 ] && [ ! -L "$3" ] || exit 1
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$4" "$cfmgr_awk_program" <&8
	;;
health-uname)
	case $# in 0) ;; *) exit 2 ;; esac
	exec "$tool" -m
	;;
health-protected | health-current | health-storage | health-uuid)
	case $# in 4) ;; *) exit 2 ;; esac
	export CFMGR_HEALTH_LOCAL="$mode"
	. "$1" || exit 2
	cfmgr_status_awk_health_local
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4"
	;;
health-wc-jq | health-wc-sha)
	case $# in 0) ;; *) exit 2 ;; esac
	set +f
	case $mode in health-wc-jq) set -- "$context"/health-jq-good.*.out ;; *) set -- "$context"/health-sha-bytes.*.out ;; esac
	set -f
	case $# in 1) ;; *) exit 1 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 1
	exec "$tool" -c <"$1"
	;;
health-count-get)
	case $# in 3) ;; *) exit 2 ;; esac
	case $1 in "$context"/health-get.*.out) ;; *) exit 2 ;; esac
	health_count_get_base=${1##*/}
	health_count_get_serial=${health_count_get_base#health-get.}
	health_count_get_serial=${health_count_get_serial%.out}
	case $health_count_get_serial in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$2" = "$context/health-get.$health_count_get_serial.body" ] && [ "$3" = "$context/health-get.$health_count_get_serial.headers" ] || exit 2
	[ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	exec "$tool" -c "$1" "$2" "$3"
	;;
health-inventory | health-scope | health-request)
	case $# in 10) ;; *) exit 2 ;; esac
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 2; done
	[ -f "$3" ] && [ ! -L "$3" ] || exit 1
	case $4 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$4" -le 65536 ] || exit 2
	case $5 in ddns | ip_sync | cloudflared) ;; *) exit 2 ;; esac
	case $6 in zone | dns | list | items | tunnel | connections | trace) ;; *) exit 2 ;; esac
	case $8:${9}:${10} in [46]:[01]:[01]) ;; *) exit 2 ;; esac
	export CFMGR_HEALTH_MODE="$mode" CFMGR_HEALTH_FEATURE="$5" CFMGR_HEALTH_KIND="$6" CFMGR_HEALTH_SELECTOR="$7" CFMGR_HEALTH_FAMILY="$8" CFMGR_HEALTH_PUBLIC="${9}" CFMGR_HEALTH_IPV6="${10}"
	exec 8<"$3" || exit 1
	[ -f /proc/self/fd/8 ] && [ "$3" -ef /proc/self/fd/8 ] && [ ! -L "$3" ] || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$4" -v cfmgr_config_mode=archive-data "$cfmgr_awk_program" <&8
	;;
health-request-check | health-frame | health-trace)
	case $# in 4) ;; *) exit 2 ;; esac
	[ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $3 in '' | *[!0-9]* | 0?*) exit 2 ;; esac
	[ "$3" -le 32768 ] || exit 2
	export CFMGR_HEALTH_MODE="$mode" CFMGR_HEALTH_INPUT="$2" CFMGR_HEALTH_BYTES="$3" CFMGR_HEALTH_KIND="$4"
	if [ "$mode" = health-request-check ]; then
		[ "$2" -ef /proc/self/fd/6 ] && [ -f /proc/self/fd/6 ] || exit 1
	fi
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program"
	;;
health-response)
	case $# in 7) ;; *) exit 2 ;; esac
	for input in "$3" "$5" "$6"; do
		[ -f "$input" ] && [ ! -L "$input" ] || exit 2
		case $input in "$context"/health-*.out | "$context"/health-get.*.body) ;; *) exit 2 ;; esac
	done
	case $4 in '' | *[!0-9]* | 0*) exit 2 ;; esac
	[ "$4" -le 32768 ] || exit 2
	export CFMGR_HEALTH_MODE=health-response CFMGR_HEALTH_SCOPE="$5" CFMGR_HEALTH_INPUT="$6" CFMGR_HEALTH_BYTES="$7"
	# Controller passes only pinned private descriptor paths: no secret operands.
	cfmgr_worker_program "$@"
	exec 8<"$3" || exit 1
	[ -f /proc/self/fd/8 ] && [ "$3" -ef /proc/self/fd/8 ] || exit 1
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$4" "$cfmgr_awk_program" <&8
	;;
health-get)
	case $# in 6) ;; *) exit 2 ;; esac
	case $6 in 4 | 6) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/6 ] && [ -f /proc/self/fd/6 ] || exit 1
	[ -f "$2" ] && [ ! -L "$2" ] && [ "$3" = "$context" ] || exit 2
	case $4:$5 in "$context"/health-get.*.body:"$context"/health-get.*.headers) ;; *) exit 2 ;; esac
	[ ! -e "$4" ] && [ ! -L "$4" ] && [ ! -e "$5" ] && [ ! -L "$5" ] || exit 1
	umask 077
	set -C
	exec 8>"$4" 7>"$5" || exit 1
	exec "$tool" -q --silent --show-error --globoff --request GET \
		"--ipv$6" \
		--proto '=https' --proto-redir '=https' --tlsv1.2 --cacert "$2" --capath "$3" \
		--proxy '' --noproxy '*' --max-redirs 0 --retry 0 --connect-timeout 1 --max-time 3 \
		--max-filesize 32768 --output /proc/self/fd/8 --dump-header /proc/self/fd/7 \
		--write-out '%{http_code}\n' --config /proc/self/fd/6
	;;
store-archive-plan)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $3 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$3" -gt 0 ] && [ "$3" -le 65536 ] || exit 2
	export CFMGR_PAYLOAD_MODE=plan
	exec 9<&0 || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$3" -v cfmgr_config_mode=archive-data "$cfmgr_awk_program" <"$2"
	;;
archive-control)
	[ "$#" -eq 5 ] && [ -f "$1" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $2 in names | retention | browse) ;; *) exit 2 ;; esac
	export CFMGR_ARCHIVE_CONTROL_MODE="$2" CFMGR_ARCHIVE_KEEP="$4" CFMGR_ARCHIVE_NEW_NAME="$5"
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$3"
	;;
archive-browser-review)
	[ "$#" -eq 4 ] && [ -f "$1" ] || exit 2
	for input in "$2" "$3" "$4"; do [ -f "$input" ] && [ ! -L "$input" ] || exit 2; done
	export CFMGR_ARCHIVE_CONTROL_MODE=review
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4"
	;;
archive-chmod)
	[ "$#" -eq 4 ] && [ -d "$1" ] && [ "$1" -ef "$2" ] || exit 2
	case $3 in '' | . | .. | */*) exit 2 ;; esac
	case $4 in 600 | 700) ;; *) exit 2 ;; esac
	cd "$1" && [ ! -L "$3" ] || exit 1
	exec "$tool" "$4" "$3"
	;;
history-meta | history-proc-meta | history-inode | history-count | history-digest | history-realpath | history-readlink | history-hexdump | history-script-prefix | history-blkid)
	case $# in 1) ;; *) exit 2 ;; esac
	case $mode in
	history-meta) exec "$tool" -ildn "$1" ;;
	history-proc-meta) exec "$tool" -iLdn "$1" ;;
	history-inode) exec "$tool" -id "$1" ;;
	history-count) exec "$tool" -c "$1" ;;
	history-digest) exec "$tool" dgst -sha256 -r "$1" ;;
	history-realpath) exec "$tool" -f "$1" ;;
	history-readlink) exec "$tool" "$1" ;;
	history-hexdump) exec "$tool" -v -e '1/1 "%02x\n"' "$1" ;;
	history-script-prefix) exec "$tool" if="$1" bs=8192 count=1 2>/dev/null ;;
	history-blkid) exec "$tool" "$1" ;;
	esac
	;;
history-directory)
	[ "$#" -eq 2 ] || exit 2
	dir=$1 memory=$2
	case $memory in '' | *[!0-9]*) exit 2 ;; esac
	[ "$memory" -ge 8192 ] && [ "$memory" -le 65536 ] || exit 2
	# shellcheck disable=SC3045 # Matched native ash supports child-only virtual-memory cap.
	ulimit -v "$memory" || exit 2
	cd "$dir" || exit 1
	exec "$tool" -1A .
	;;
history-proc-list | history-writer-fd-list)
	case $mode in
	history-proc-list)
		case $# in 1) ;; *) exit 2 ;; esac
		dir=/proc maximum=4096 memory=$1
		;;
	history-writer-fd-list)
		[ "$#" -eq 2 ] || exit 2
		case $1 in '' | *[!0-9]*) exit 2 ;; esac
		case $((${#1} <= 10)) in 1) ;; *) exit 2 ;; esac
		dir=/proc/$1/fdinfo maximum=256 memory=$2
		;;
	esac
	case $memory in '' | *[!0-9]*) exit 2 ;; esac
	[ "$memory" -ge 8192 ] && [ "$memory" -le 65536 ] || exit 2
	# shellcheck disable=SC3045 # Child-only VM cap before terminal numeric glob.
	ulimit -v "$memory" || exit 2
	cd "$dir" || exit 1
	# Names only: native ls stats every entry and unrelated exit churn can fail
	# its whole result. Relevant identities are checked separately by the parent.
	set +f
	set -- [0-9]*
	set -f
	case $(($# <= maximum)) in 1) ;; *) exit 4 ;; esac
	# BEGIN validates the entire argument list before any output and then exits;
	# AWK never opens numeric names as files, including vanished/dangling entries.
	case ${cfmgr_worker_health_pids:-0} in 1)
		exec "$tool" 'BEGIN {if(ARGC<2)exit 4;for(i=1;i<ARGC;i++)if(ARGV[i]!~/^[0-9]+$/||length(ARGV[i])>10)exit 4;print "CFMGR-HEALTH-PIDS 1 " ARGC-1;for(i=1;i<ARGC;i++)print ARGV[i];print "END " ARGC-1;exit}' "$@"
		;;
	esac
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN {if(ARGC<2)exit 4;for(i=1;i<ARGC;i++)if(ARGV[i]!~/^[0-9]+$/||length(ARGV[i])>10)exit 4;for(i=1;i<ARGC;i++)print ARGV[i];exit}' "$@"
	;;
history-account)
	case $# in 0) ;; *) exit 2 ;; esac
	exec "$tool" get http_username
	;;
history-cron-read)
	case $# in 2) ;; *) exit 2 ;; esac
	case $1 in /var/spool/cron/crontabs/*) ;; *) exit 2 ;; esac
	case ${1##*/} in '' | . | .. | *[!A-Za-z0-9_-]*) exit 2 ;; esac
	case $2 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$2" -gt 0 ] || exit 2
	# Child-only source descriptor; parent3 and inherited lock0/rotation4 stay.
	[ ! -L "$1" ] && [ -f "$1" ] || exit 1
	exec 3<"$1" || exit 1
	[ "$1" -ef /proc/self/fd/3 ] || exit 1
	exec "$tool" if=/proc/self/fd/3 bs=1 count="$2" 2>/dev/null
	;;
history-lock)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -xn 4
	;;
history-syslog-version | history-syslog-check | history-logrotate-version | history-logrotate-debug)
	case $# in 0) ;; *) exit 2 ;; esac
	case $mode in
	history-syslog-version | history-logrotate-version) exec "$tool" --version ;;
	history-syslog-check) exec "$tool" --syntax-only -f /opt/etc/syslog-ng.conf ;;
	history-logrotate-debug) exec "$tool" -d /opt/etc/logrotate.conf ;;
	esac
	;;
history-parse)
	[ "$#" -eq 6 ] && [ -f "$1" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $2 in plan | pack | includes | base | assess | family | path | target-path | targets | audit | compare) ;; *) exit 2 ;; esac
	case $4 in '' | *[!0-9]*) exit 2 ;; esac
	export CFMGR_HISTORY_MODE="$2" CFMGR_HISTORY_LIMIT="$4" CFMGR_HISTORY_LABEL="$5" CFMGR_HISTORY_FEATURE="$5" CFMGR_HISTORY_POLICY="$6" CFMGR_HISTORY_ROTATE="$6"
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$3"
	;;
history-policy-decode)
	[ "$#" -eq 1 ] || exit 2
	export CFMGR_HISTORY_JSON_HEX="$1"
	exec "$tool" 'BEGIN {h=ENVIRON["CFMGR_HISTORY_JSON_HEX"]; if(length(h)>131072 || length(h)%2 || h~/[^0-9a-f]/)exit 1; for(i=1;i<=length(h);i+=2){a=index("0123456789abcdef",substr(h,i,1))-1;b=index("0123456789abcdef",substr(h,i+1,1))-1;n=a*16+b;if(!n)exit 1;printf "%c",n}}'
	;;
history-policy-json)
	[ "$#" -eq 5 ] && [ -d "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $3:$5 in *[!0-9:]* | :* | *:) exit 2 ;; esac
	[ "$3" -gt 0 ] && [ "$3" -le 65536 ] || exit 2
	case $4 in ddns | ip_sync | cloudflared) ;; *) exit 2 ;; esac
	export CFMGR_HISTORY_MODE=policy CFMGR_HISTORY_FEATURE="$4" CFMGR_HISTORY_LIMIT="$5"
	exec 9<&0 || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$3" "$cfmgr_awk_program" <"$2"
	;;
history-mount)
	[ "$#" -eq 2 ] && [ -f "$1" ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "/proc/self/mountinfo"
	;;
history-volume)
	[ "$#" -eq 4 ] && [ -f "$1" ] || exit 2
	export CFMGR_H_DEVICE="$2" CFMGR_H_FS="$3" CFMGR_H_UUID="$4"
	exec "$tool" 'BEGIN{d=ENVIRON["CFMGR_H_DEVICE"];f=ENVIRON["CFMGR_H_FS"];u=ENVIRON["CFMGR_H_UUID"]} {if(NR!=1||index($0,d ": ")!=1)exit 1;s=substr($0,length(d)+3);n=split(s,a," ");for(i=1;i<=n;i++){if(a[i]~/^UUID="[A-Za-z0-9-]+"$/){x=a[i];sub(/^UUID="/,"",x);sub(/"$/,"",x);if(x!=u||seen++)exit 1}if(a[i]~/^TYPE="[A-Za-z0-9]+"$/){x=a[i];sub(/^TYPE="/,"",x);sub(/"$/,"",x);if(x!=f||types++)exit 1}}}END{if(NR!=1||seen!=1||types!=1)exit 1;print "UUID " u " END"}' "$1"
	;;
history-proc-pids)
	[ "$#" -eq 1 ] && [ -f "$1" ] || exit 2
	exec "$tool" '/^[1-9][0-9]*$/ {if(length($0)>10)exit 1;print}' "$1"
	;;
history-writer-parse)
	[ "$#" -eq 4 ] && [ -f "$1" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $2 in argv) ;; *) exit 2 ;; esac
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_writer_mode="$2" -v cfmgr_writer_arg="$4" "$cfmgr_awk_program" "$3"
	;;
history-argv)
	case $# in 4) ;; *) exit 2 ;; esac
	[ -f "$1" ] || exit 2
	case $2 in syslog | cron) ;; *) exit 2 ;; esac
	export CFMGR_H_KIND="$2" CFMGR_H_PID="$3" CFMGR_H_START="$4"
	exec "$tool" 'function fail(){bad=1;exit 1} function hex(s, z,i){for(i=1;i<=length(s);i++)z=z sprintf("%02x",ord[substr(s,i,1)]);return z} BEGIN{for(i=1;i<128;i++)ord[sprintf("%c",i)]=i;k=ENVIRON["CFMGR_H_KIND"];p=ENVIRON["CFMGR_H_PID"];t=ENVIRON["CFMGR_H_START"]} {if($0!~/^[0-9a-f][0-9a-f]$/)fail();if($0=="00"){if(++n>64||arg=="")fail();a[n]=arg;arg="";next}v=(index("0123456789abcdef",substr($0,1,1))-1)*16+index("0123456789abcdef",substr($0,2,1))-1;if(v<32||v>126)fail();arg=arg sprintf("%c",v)} END{if(bad||arg!=""||!n)exit 1;if(k=="syslog"){s="PROC " p " " t " 2f6f70742f7362696e2f7379736c6f672d6e67 " n;for(i=1;i<=n;i++)s=s " " hex(a[i]);print s " END";exit}i=2;if(a[1]=="/bin/busybox"||a[1]=="busybox"){if(a[2]!="crond")exit 4;i=3}else if(a[1]!="crond"&&a[1]!="/usr/sbin/crond")exit 4;cfg="/var/spool/cron/crontabs";for(;i<=n;i++){if(a[i]=="-l"){if(++i>n||a[i]!~/^[0-9]+$/)exit 1}else if(a[i]~/^-l[0-9]+$/){}else if(a[i]=="-c"){if(++i>n||a[i]!=cfg)exit 1}else if(a[i]=="-f"||a[i]=="-b"||a[i]=="-S"){}else exit 1}print "CROND " p " " t " " hex(cfg) " END"}' "$1"
	;;
history-frame)
	[ "$#" -eq 5 ] || exit 2
	export CFMGR_H_OP="$1" CFMGR_H_A="$2" CFMGR_H_B="$3" CFMGR_H_C="$4" CFMGR_H_D="$5"
	exec "$tool" 'function hex(s, z,i){for(i=1;i<=length(s);i++)z=z sprintf("%02x",ord[substr(s,i,1)]);return z}BEGIN{for(i=1;i<128;i++)ord[sprintf("%c",i)]=i;o=ENVIRON["CFMGR_H_OP"];a=ENVIRON["CFMGR_H_A"];b=ENVIRON["CFMGR_H_B"];c=ENVIRON["CFMGR_H_C"];d=ENVIRON["CFMGR_H_D"];if(o=="hash")print a " *" b;else if(o=="resolved")print "RESOLVED " hex(a) " " b " " c " END";else if(o=="text")printf "%s",a;else exit 2}'
	;;
history-append)
	[ "$#" -eq 5 ] && [ -d "$1" ] && [ "$1" -ef "$2" ] || exit 2
	case $3 in history-[0-9]*) ;; *) exit 2 ;; esac
	case $3 in */* | *[!A-Za-z0-9-]*) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	cd "$1" && [ -f "$3" ] && [ ! -L "$3" ] || exit 1
	exec 2>>"$3" || exit 1
	[ "$3" -ef /proc/self/fd/2 ] || exit 1
	exec "$tool" '%s\n' "$4" >&2
	;;
archive-payload-json)
	[ "$#" -eq 5 ] && [ -d "$1" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $4 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$4" -gt 0 ] && [ "$4" -le 65536 ] || exit 2
	lib=$1 payload_mode=$2 input=$3 bytes=$4 auxiliary=$5
	# Retain writer exclusion even though the bounded JSON reader uses stdin.
	exec 9<&0 || exit 1
	export CFMGR_PAYLOAD_MODE="$payload_mode"
	case $payload_mode in
	plan)
		cfmgr_worker_program "$@"
		exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$bytes" -v cfmgr_config_mode=archive-data \
			"$cfmgr_awk_program" <"$input"
		;;
	runtime-json) export CFMGR_PAYLOAD_AUTHORITY="$auxiliary" ;;
	certificate-json) export CFMGR_PAYLOAD_ACCOUNT_HEX="$auxiliary" ;;
	drafts | drafts-review) export CFMGR_PAYLOAD_GENERATION="$auxiliary" ;;
	*) exit 2 ;;
	esac
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_mode=tree -v cfmgr_json_size="$bytes" "$cfmgr_awk_program" <"$input"
	;;
archive-payload-yaml)
	[ "$#" -eq 3 ] || exit 2
	export CFMGR_YAML_METADATA_LIMIT="$3"
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
archive-payload-index)
	[ "$#" -eq 4 ] || exit 2
	export CFMGR_PAYLOAD_INDEX_LIMIT="$4"
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "$3"
	;;
archive-payload-match)
	[ "$#" -eq 3 ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "$3"
	;;
archive-payload-pem)
	[ "$#" -eq 2 ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
archive-memory)
	[ "$#" -eq 0 ] || exit 2
	# Native 3.4 may lack MemAvailable; use its conservative MemFree instead.
	# shellcheck disable=SC2016
	exec "$tool" '$1=="MemAvailable:" {a=$2;na++} $1=="MemFree:" {f=$2;nf++}
		END {v=(na==1?a:f);if(na>1 || (!na && nf!=1) || v!~/^[0-9]+$/ || v<1)exit 1;print v}' /proc/meminfo
	;;
archive-space)
	[ "$#" -eq 1 ] && [ -d "$1" ] || exit 2
	exec "$tool" -Pk "$1"
	;;
archive-space-values)
	[ "$#" -eq 1 ] || exit 2
	# Device and numeric columns precede a possibly spaced mountpoint.
	# shellcheck disable=SC2016
	exec "$tool" 'NR>2 || length($0)>4096 {bad=1} NR==2 {if(NF<6 || $2!~/^[0-9]+$/ || $3!~/^[0-9]+$/ || $4!~/^[0-9]+$/ || $5!~/^[0-9]+%$/)bad=1;available=$4} END{if(bad || NR!=2)exit 1;print available}' "$1"
	;;
archive-directory)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ ! -L "$2" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] || exit 1
	case $3 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$3" -ge 8192 ] && [ "$3" -le 65536 ] || exit 2
	# Native ls allocates its entry list before output. The child-only address
	# space limit bounds that allocation even when CFMgr/backup has foreign files.
	# shellcheck disable=SC3045 # Native BusyBox ash supports this fixed limit.
	ulimit -v "$3" || exit 2
	cd "$1" || exit 1
	exec "$tool" -1A .
	;;
archive-stage-mkdir | archive-stage-rmdir)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ ! -L "$2" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] || exit 1
	case $3 in .create.[a-f0-9-]*) ;; *) exit 2 ;; esac
	case $3 in *[!a-z0-9.-]*) exit 2 ;; esac
	cd "$1" || exit 1
	if [ "$mode" = archive-stage-mkdir ]; then
		[ ! -e "$3" ] && [ ! -L "$3" ] || exit 1
		umask 077
		exec "$tool" "$3"
	fi
	[ -d "$3" ] && [ ! -L "$3" ] || exit 1
	exec "$tool" "$3"
	;;
archive-stage-meta)
	[ "$#" -eq 1 ] && [ -d "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -id "$1"
	;;
archive-flush)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" /proc/self/fd/3
	;;
archive-publish)
	[ "$#" -eq 6 ] && [ -d "$1" ] && [ -d "$3" ] && [ ! -L "$2" ] && [ ! -L "$4" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] && [ "$3" -ef "$4" ] || exit 1
	[ "$5" = candidate.tar.gz ] || exit 2
	case $6 in CFbackup-*.tar.gz) ;; *) exit 2 ;; esac
	case $6 in *[!A-Za-z0-9_.-]*) exit 2 ;; esac
	[ -f "$1/$5" ] && [ ! -L "$1/$5" ] || exit 1
	cd "$3" || exit 1
	[ ! -e "$6" ] && [ ! -L "$6" ] || exit 1
	exec "$tool" -n "$1/$5" "$6"
	;;
archive-archive-remove)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ ! -L "$2" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] || exit 1
	case $3 in CFbackup-*.tar.gz) ;; *) exit 2 ;; esac
	case $3 in *[!A-Za-z0-9_.-]*) exit 2 ;; esac
	cd "$1" || exit 1
	[ -f "$3" ] && [ ! -L "$3" ] || exit 1
	exec "$tool" -f "$3"
	;;
store-archive-config)
	[ "$#" -eq 14 ] && [ -f "$1" ] && [ -f "$2" ] && [ -f "$4" ] && [ ! -L "$4" ] || exit 2
	case $3 in archive-read | archive-preferences-observe | archive-preferences-patch | archive-history-observe | archive-history-patch) ;; *) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 65536 ] || exit 2
	export CFMGR_ARCHIVE_FORMAT="$6" CFMGR_ARCHIVE_KEEP="$7" CFMGR_ARCHIVE_SET_ID="$8" CFMGR_ARCHIVE_ID="$9"
	export CFMGR_ARCHIVE_AT="${10}" CFMGR_ARCHIVE_DATE="${11}" CFMGR_ARCHIVE_TIME="${12}" CFMGR_ARCHIVE_ZONE="${13}" CFMGR_ARCHIVE_GENERATION="${14}"
	exec 9<&0 || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_config_mode="$3" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" "$cfmgr_awk_program" <"$4"
	;;
archive-tar-header)
	[ "$#" -eq 4 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	export CFMGR_TAR_OFFSET="$3" CFMGR_TAR_BYTES="$4"
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
archive-format-manifest)
	[ "$#" -eq 3 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	export CFMGR_ARCHIVE_FORMAT_MODE=manifest CFMGR_ARCHIVE_SET="$3"
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
archive-browser-manifest)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	export CFMGR_ARCHIVE_FORMAT_MODE=discover
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2"
	;;
archive-format-inventory)
	[ "$#" -eq 5 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] && [ -f "$3" ] && [ ! -L "$3" ] && [ -f "$4" ] && [ ! -L "$4" ] || exit 2
	# Parameter frame is trusted normalized manifest output, never code.
	IFS=' ' read -r CFMGR_ARCHIVE_ROWS CFMGR_ARCHIVE_FILES CFMGR_ARCHIVE_PAYLOAD_BYTES extra <<EOF_ARCHIVE_PARAMETERS
$5
EOF_ARCHIVE_PARAMETERS
	[ -z "$extra" ] || exit 2
	CFMGR_ARCHIVE_INDEX=$4
	export CFMGR_ARCHIVE_ROWS CFMGR_ARCHIVE_FILES CFMGR_ARCHIVE_PAYLOAD_BYTES CFMGR_ARCHIVE_INDEX CFMGR_ARCHIVE_FORMAT_MODE=inventory
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$3"
	;;
archive-list-compare)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN{idx=ARGV[1];ARGV[1]=""} {if((getline row < idx)<=0 || split(row,a," ")!=4 || $0!=a[1])bad=1} END{if((getline row < idx)!=0 || bad)exit 1}' "$1" "$2"
	;;
archive-unlink)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ ! -L "$1" ] && [ ! -L "$2" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] || exit 1
	case $3 in '' | . | .. | *[!A-Za-z0-9_.-]*) exit 2 ;; esac
	cd "$1" || exit 1
	[ -f "$3" ] && [ ! -L "$3" ] || exit 1
	exec "$tool" -f "$3"
	;;
archive-write)
	[ "$#" -eq 5 ] && [ -d "$1" ] && [ ! -L "$1" ] && [ ! -L "$2" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] || exit 1
	case $3 in '' | . | .. | *[!A-Za-z0-9_.-]*) exit 2 ;; esac
	[ "${#5}" -le 4096 ] || exit 2
	cd "$1" || exit 1
	umask 077
	case $4 in
	new)
		[ ! -e "$3" ] && [ ! -L "$3" ] || exit 1
		set -C
		exec 1>"$3" || exit 1
		;;
	append)
		[ -f "$3" ] && [ ! -L "$3" ] || exit 1
		exec 2<"$3" || exit 1
		exec 1>>"$3" || exit 1
		# shellcheck disable=SC3013
		[ ! -L "$3" ] && [ "$3" -ef /proc/self/fd/1 ] && [ /proc/self/fd/1 -ef /proc/self/fd/2 ] || exit 1
		;;
	*) exit 2 ;;
	esac
	# Firmware ash disables builtin printf; exec the admitted applet directly
	# so a blocked metadata write remains the supervisor's one owned child.
	exec "$tool" '%s' "$5"
	;;
archive-inode)
	[ "$#" -eq 1 ] && [ ! -L "$1" ] && { [ -f "$1" ] || [ -d "$1" ]; } || exit 2
	exec "$tool" -id "$1"
	;;
archive-stage-inodes)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ ! -L "$1" ] && [ -d "$2" ] && [ ! -L "$2" ] || exit 2
	# shellcheck disable=SC3013
	[ "$1" -ef "$2" ] || exit 2
	case $3 in '' | . | .. | *[!A-Za-z0-9_.-]*) exit 2 ;; esac
	stage_inode_target=$1/$3
	[ ! -L "$stage_inode_target" ] && { [ -f "$stage_inode_target" ] || [ -d "$stage_inode_target" ]; } || exit 2
	# Matched native ls stats each operand in order before sorting its output.
	# Repeated stage operands therefore bracket the target's fresh observation.
	exec "$tool" -id "$1" "$stage_inode_target" "$1"
	;;
archive-count | archive-meta | archive-digest | archive-gunzip-test | archive-hexdump)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $mode in
	archive-count) exec "$tool" -c "$1" ;;
	archive-meta) exec "$tool" -ildn "$1" ;;
	archive-digest) exec "$tool" dgst -sha256 -r "$1" ;;
	archive-gunzip-test) exec "$tool" -t "$1" ;;
	archive-hexdump) exec "$tool" -v -e '1/1 "%02x"' "$1" ;;
	esac
	;;
archive-header-hex)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in '' | *[!0-9]* | 0?*) exit 2 ;; esac
	[ "${#2}" -le 19 ] && [ "$2" -le 9223372036854775296 ] || exit 2
	exec "$tool" -v -n 512 -s "$2" -e '1/1 "%02x"' "$1"
	;;
archive-source-realpath)
	[ "$#" -eq 1 ] && [ "$1" = /opt ] || exit 2
	exec "$tool" -f /opt
	;;
archive-source-mount)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "/proc/self/mountinfo"
	;;
archive-source-blkid)
	[ "$#" -eq 1 ] && [ -b "$1" ] || exit 2
	exec "$tool" "$1"
	;;
archive-timezone)
	[ "$#" -eq 1 ] && [ "$1" = time_zone_x ] || exit 2
	exec "$tool" get time_zone_x
	;;
archive-date)
	[ "$#" -eq 1 ] && [ -n "$1" ] && [ "${#1}" -le 256 ] || exit 2
	case $1 in *[!\ -~]*) exit 2 ;; esac
	TZ=$1
	export TZ
	exec "$tool" '+%s|%Y-%m-%d|%H-%M-%S|%z'
	;;
archive-copy-blocks | archive-copy-tail | archive-copy-small | archive-gzip | archive-gunzip | archive-tar-list | archive-tar-verbose | archive-tar-bodies | archive-tar-create | archive-metahex | archive-base64)
	# Fixed controller operands: INPUT ANCHORED_DIR ORIGINAL_DIR BASENAME ...
	# Cwd, retained by the final exec, anchors every output open to the pinned
	# volume. A detached original pathname can never create a fallback file.
	[ "$#" -ge 4 ] && [ -d "$2" ] && [ ! -L "$2" ] && [ ! -L "$3" ] || exit 2
	# shellcheck disable=SC3013
	[ "$2" -ef "$3" ] || exit 1
	case $4 in '' | . | .. | *[!A-Za-z0-9_.-]*) exit 2 ;; esac
	cd "$2" || exit 1
	# shellcheck disable=SC3013
	[ . -ef "$3" ] || exit 1
	input=$1 output=$4
	case $mode in
	archive-copy-blocks | archive-copy-tail | archive-copy-small)
		[ "$#" -eq 6 ] && [ -f "$input" ] && [ ! -L "$input" ] || exit 2
		case $5:$6 in *[!0-9:]* | :* | *:) exit 2 ;; esac
		if [ "$mode" = archive-copy-small ]; then [ "$6" -gt 0 ] && [ "$6" -le 4096 ] || exit 2; fi
		if [ "$mode" = archive-copy-tail ]; then
			[ "$6" -gt 0 ] && [ "$6" -le 4095 ] && [ -f "$output" ] && [ ! -L "$output" ] || exit 2
			# Pin the append target before opening it writable; no write occurs
			# until both descriptors identify the same nonsymlink regular file.
			exec 2<"$output" || exit 1
			exec 1>>"$output" || exit 1
			# shellcheck disable=SC3013
			[ ! -L "$output" ] && [ "$output" -ef /proc/self/fd/1 ] && [ /proc/self/fd/1 -ef /proc/self/fd/2 ] || exit 1
			exec "$tool" if="$input" iflag=skip_bytes skip="$5" bs="$6" count=1 2>/dev/null
		fi
		;;
	archive-tar-create)
		[ "$#" -eq 5 ] && [ -d "$input" ] && [ ! -L "$input" ] && [ -f "$5" ] && [ ! -L "$5" ] || exit 2
		# The list contains explicit portable relative members, never options.
		while IFS= read -r member || [ -n "$member" ]; do
			case $member in '' | /* | -* | *[!A-Za-z0-9_./-]* | *//* | . | .. | */./* | */../* | ./* | ../* | */. | */..) exit 2 ;; esac
		done <"$5"
		;;
	*) [ "$#" -eq 4 ] && [ -f "$input" ] && [ ! -L "$input" ] || exit 2 ;;
	esac
	[ ! -e "$output" ] && [ ! -L "$output" ] || exit 1
	umask 077
	set -C
	exec 1>"$output" || exit 1
	case $mode in
	archive-copy-blocks) exec "$tool" if="$input" iflag=skip_bytes skip="$5" bs=4096 count="$6" 2>/dev/null ;;
	archive-copy-small) exec "$tool" if="$input" iflag=skip_bytes skip="$5" bs="$6" count=1 2>/dev/null ;;
	archive-gzip | archive-gunzip) exec "$tool" -c "$input" ;;
	archive-metahex) exec "$tool" -v -e '1/1 "%02x\n"' "$input" ;;
	archive-base64) exec "$tool" base64 -d -A -in "$input" ;;
	archive-tar-create) exec "$tool" -cf - -C "$input" -T "$5" ;;
	archive-tar-list) exec "$tool" -tf "$input" ;;
	archive-tar-verbose) exec "$tool" -tvf "$input" ;;
	# Caller must admit all raw headers first, including GNU extension sizes.
	archive-tar-bodies) exec "$tool" -xOf "$input" ;;
	esac
	;;
acquire-lines)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -l <"$1"
	;;
acquire-text)
	[ "$#" -eq 4 ] || exit 2
	case $2:$3:$4 in *[!0-9:]* | :* | *:) exit 2 ;; esac
	case $4 in 0 | 1) ;; *) exit 2 ;; esac
	# Native WC LF count + byte count detect NUL splitting/truncation in old
	# awk. A strict frame additionally requires its final LF; scripts may omit it.
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN{bytes=ARGV[1];lines=ARGV[2];strict=ARGV[3];ARGV[1]=ARGV[2]=ARGV[3]=""}
		{total+=length($0)+1}
		END{if(NR==lines){if(total!=bytes)exit 1}else if(strict || NR!=lines+1 || total-1!=bytes)exit 1}' "$2" "$3" "$4" "$1"
	;;
acquire-api | acquire-raw)
	[ "$#" -eq 5 ] || exit 2
	case "$1:$2:$4" in /*:/*:/*) ;; *) exit 2 ;; esac
	case $2 in *:*) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 1048576 ] || exit 2
	case $mode:$3 in acquire-api:https://api.github.com/repos/*/commits/* | acquire-raw:https://raw.githubusercontent.com/*) ;; *) exit 2 ;; esac
	[ ! -e "$4" ] && [ ! -L "$4" ] || exit 1
	# Pin a new private body before curl. Neither its path nor a substituted
	# stage can redirect a write after this open; no redirects/fallback are used.
	umask 077
	set -C
	exec 8>"$4" || exit 1
	if [ "$mode" = acquire-api ]; then
		set -- "$1" "$2" "$3" "$5" --header 'Accept: application/vnd.github.sha' --header 'X-GitHub-Api-Version: 2022-11-28'
	else set -- "$1" "$2" "$3" "$5"; fi
	cfmgr_acquire_ca=$1 cfmgr_acquire_capath=$2 cfmgr_acquire_url=$3 cfmgr_acquire_limit=$4
	shift 4
	exec "$tool" -q --silent --show-error --proto '=https' --proto-redir '=https' \
		--tlsv1.2 --cacert "$cfmgr_acquire_ca" --capath "$cfmgr_acquire_capath" --proxy '' --noproxy '*' \
		--connect-timeout 5 --max-time 10 --max-filesize "$cfmgr_acquire_limit" \
		--output /proc/self/fd/8 --write-out '%{http_code}\n' "$@" --url "$cfmgr_acquire_url"
	;;
acquire-digest)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" dgst -sha256 -r <"$1"
	;;
acquire-shell)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -n "$1"
	;;
acquire-extract)
	[ "$#" -eq 3 ] && [ -d "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	# Only this trusted, package-admitted installed category is sourced.
	# shellcheck disable=SC1090
	. "$2" || exit 2
	cfmgr_package_awk_extract_exec "$tool" "$1" "$3"
	exit 2
	;;
acquire-awk-file)
	[ "$#" -eq 2 ] && [ "$1" = "$context/acquire.syntax.awk" ] || exit 2
	[ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $2 in *.awk) ;; *) exit 2 ;; esac
	# Passive extension parsers retain the same pre-publication syntax gate.
	exec "$tool" -f "$1" -f "$2" /dev/null
	;;

acquire-awk)
	[ "$#" -eq 2 ] && [ "$1" = "$context/acquire.syntax.awk" ] || exit 2
	[ -f "$1" ] && [ ! -L "$1" ] && [ -n "$2" ] && [ "${#2}" -le 98304 ] || exit 2
	# The candidate literal is a separate supervised extractor receipt, never
	# shell code. Fatal first BEGIN bypasses all candidate BEGIN and END rules.
	cfmgr_syntax_program='BEGIN { print "CFMGR-AWK-PARSED 1"; fflush(); print 1/(NR-NR) }
'"$2"
	[ "${#cfmgr_syntax_program}" -le 98304 ] || exit 2
	exec "$tool" "$cfmgr_syntax_program" /dev/null
	;;

acquire-mkdir)
	[ "$#" -eq 1 ] && [ ! -e "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -m 700 "$1"
	;;
acquire-chmod)
	[ "$#" -eq 2 ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $1 in 0644 | 0755) ;; *) exit 2 ;; esac
	exec "$tool" "$1" "$2"
	;;
acquire-remove | acquire-rmdir)
	[ "$#" -eq 1 ] && [ ! -L "$1" ] || exit 2
	case $mode in acquire-remove)
		[ -f "$1" ] || exit 2
		exec "$tool" -f "$1"
		;;
	*)
		[ -d "$1" ] || exit 2
		exec "$tool" "$1"
		;;
	esac
	;;
acquire-entry)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN {version=ARGV[1];ARGV[1]=""} /^CFMGR_VERSION=/ {n++;if($0!="CFMGR_VERSION=" version)bad=1} END{exit (n!=1 || bad)}' "$2" "$1"
	;;
acquire-manifest)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" '
		BEGIN {FS="\t";version=ARGV[1];ARGV[1]=""}
		NR==1 {if($0!="CFMGR-MANIFEST 2 " version " 1 2")bad=1;next}
		{
			if(NF!=4 || length($0)>512 || $1!~/^0(644|755)$/ || $2!~/^(0|[1-9][0-9]*)$/ || $2>1048576 ||
			length($3)!=64 || $3~/[^0-9a-f]/ || length($4)>256 || $4!~/^[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)*$/ ||
			$4~/(^|\/)(\.|\.\.)(\/|$)/ || seen[$4]++ || (prev!="" && $4<=prev)){bad=1;next}
			if($4!="cfmgr.sh" && $4!="catalog.txt" && $4!~/^modules\//)bad=1
			if($4=="cfmgr.sh" && $1!="0755")bad=1
			path=$4;depth=0;while(sub(/\/[^\/]+$/,"",path)){if(seen[path] || ++depth>16)bad=1}
			prev=$4;total+=$2;count++;if(count>512 || total>16777216)bad=1
			print
		}
		END {
			required="cfmgr.sh catalog.txt modules/backup.sh modules/helpers/worker.sh modules/lib/config.sh modules/lib/execution.sh modules/lib/logging.sh modules/lib/network.sh modules/lib/package.sh modules/lib/storage.sh modules/manager.sh modules/status.sh"
			n=split(required,names," ");for(i=1;i<=n;i++)if(!seen[names[i]])bad=1
			if(bad || count<2)exit 1
		}' "$2" "$1"
	;;
acquire-catalog)
	[ "$#" -eq 3 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN{FS="\t";version=ARGV[1];ARGV[1]=""}
		NR==FNR{if($4~/^modules\//)expected[$4]=1;next}
		FNR==1{if($0!="CFMGR-CATALOG 1 " version)bad=1;next}
		{kind=($1~/^modules\/lib\//?"library":($1~/^modules\/helpers\//?"helper":"data"));if(NF!=2 || !expected[$1] || seen[$1]++ || $2!=kind)bad=1}
		END{for(path in expected)if(!seen[path])bad=1;if(bad)exit 1}' "$3" "$1" "$2"
	;;
store-backup-config)
	[ "$#" -eq 9 ] || exit 2
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 1; done
	[ -f "$4" ] && [ ! -L "$4" ] || exit 1
	case $3 in backup-read | backup-observe | backup-patch) ;; *) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 65536 ] || exit 1
	export CFMGR_BACKUP_MOUNT="$6" CFMGR_BACKUP_UUID="$7" CFMGR_BACKUP_FILESYSTEM="$8" CFMGR_BACKUP_ROOT="$9"
	# JSON replaces stdin; retain any inherited writer lock until this child exits.
	exec 9<&0 || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_config_mode="$3" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" "$cfmgr_awk_program" <"$4"
	;;
store-backup-mounts | store-backup-mount)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in /tmp/mnt | /tmp/mnt/?*) ;; *) exit 2 ;; esac
	cfmgr_worker_program "$@"
	case $mode in
	store-backup-mounts) exec "$tool" "$cfmgr_awk_program" subtree-v1 "$2" "/proc/self/mountinfo" ;;
	*) exec "$tool" "$cfmgr_awk_program" "$2" "/proc/self/mountinfo" ;;
	esac
	;;
store-backup-blkid)
	[ "$#" -eq 1 ] && [ -b "$1" ] || exit 2
	exec "$tool" "$1"
	;;
store-backup-mkdir)
	[ "$#" -eq 0 ] && [ -d /proc/self/fd/6 ] || exit 2
	[ ! -e /proc/self/fd/6/CFMgr ] && [ ! -L /proc/self/fd/6/CFMgr ] || exit 1
	exec "$tool" /proc/self/fd/6/CFMgr
	;;
store-backup-leaf-mkdir)
	[ "$#" -eq 0 ] && [ -d /proc/self/fd/7 ] || exit 2
	[ ! -e /proc/self/fd/7/backup ] && [ ! -L /proc/self/fd/7/backup ] || exit 1
	exec "$tool" /proc/self/fd/7/backup
	;;
store-backup-chmod)
	[ "$#" -eq 0 ] && [ -d /proc/self/fd/7 ] || exit 2
	exec "$tool" 700 /proc/self/fd/7
	;;
store-settings)
	[ "$#" -eq 8 ] || exit 2
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 1; done
	[ -f "$4" ] && [ ! -L "$4" ] || exit 1
	case $3 in settings-read | settings-observe | settings-patch | diagnostic-read | diagnostic-observe | diagnostic-patch) ;; *) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 65536 ] || exit 1
	export CFMGR_SETTINGS_MASK="$6" CFMGR_SETTINGS_CHECK="$7" CFMGR_SETTINGS_AUTO="$8"
	# Shared settings reads also run inside the archive's borrowed-lock Save.
	exec 9<&0 || exit 1
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_config_mode="$3" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" "$cfmgr_awk_program" <"$4"
	;;
store-count | store-meta | store-snapshot | store-digest)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 1
	case $mode in
	store-count) exec "$tool" -c <"$1" ;;
	store-meta) exec "$tool" -ildn "$1" ;;
	store-snapshot)
		exec 8<"$1" || exit 1
		[ -f /proc/self/fd/8 ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/8 ] || exit 1
		# BusyBox dd has no status=none. Errors still return nonzero; caller
		# requires exact metadata/size before and after this capped read.
		exec "$tool" bs=4096 count=17 <&8 2>/dev/null
		;;
	store-digest) exec "$tool" dgst -sha256 -r <"$1" ;;
	esac
	;;
store-meta-frame)
	[ "$#" -eq 1 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'NR!=1 || NF<7 || $1!~/^[0-9]+$/ || $2!="-rw-------" || $4!=0 || $6!~/^[0-9]+$/ || $6<1 || $6>65536 {bad=1; exit 1} {print $1 ":" $6} END {if(bad || NR!=1) exit 1}' "$1"
	;;
store-digest-frame)
	[ "$#" -eq 1 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'NR!=1 || length($0)!=71 || substr($0,65)!=" *stdin" || substr($0,1,64)~/[^0-9a-fA-F]/ {bad=1; exit 1} {print tolower(substr($0,1,64))} END {if(bad || NR!=1) exit 1}' "$1"
	;;
store-lock-create)
	[ "$#" -eq 1 ] || exit 2
	if [ -e "$1" ] || [ -L "$1" ]; then exit 0; fi
	umask 077
	set -C
	: >"$1"
	;;
store-lock)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 0
	;;
store-lock-test)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 1
	exec 4<>"$1" || exit 1
	exec "$tool" -n 4
	;;
store-flush)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" /proc/self/fd/3
	;;
store-copy)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ ! -e "$2" ] && [ ! -L "$2" ] || exit 1
	exec "$tool" "$1" "$2"
	;;
store-mkdir)
	[ "$#" -eq 1 ] && [ ! -e "$1" ] && [ ! -L "$1" ] || exit 1
	exec "$tool" -m 700 "$1"
	;;
store-move)
	[ "$#" -eq 2 ] && [ ! -L "$1" ] && [ ! -L "$2" ] || exit 1
	exec "$tool" "$1" "$2"
	;;
store-remove | store-rmdir)
	[ "$#" -eq 1 ] && [ ! -L "$1" ] || exit 1
	case $mode in store-remove) exec "$tool" -f "$1" ;; *) exec "$tool" "$1" ;; esac
	;;
store-space)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -Pk "$1"
	;;
store-space-frame)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" -v needed="$2" 'NR>2 || length($0)>1024 {bad=1; exit 1} NR==2 {if(NF!=6 || $4!~/^[0-9]+$/ || $4<needed) bad=1} END {if(bad || NR!=2) exit 1}' "$1"
	;;
store-intent)
	[ "$#" -eq 2 ] || exit 2
	# Fixed ASCII frame; decimal generation increment is string arithmetic.
	# shellcheck disable=SC2016
	exec "$tool" -v size="$2" '
	function gen(s) {return s~/^[1-9][0-9]*$/ && length(s)<=20}
	function inc(s, i,d,r,c) {c=1;r="";for(i=length(s);i>0;i--){d=substr(s,i,1)+c;c=d>9;r=(d%10) r}return (c?"1":"") r}
	NR!=1 || length($0)+1!=size || NF!=9 || $1!="CFMGR-SETTINGS-INTENT" || $2!="1" || $9!="END" || !gen($3) || !gen($4) || ("g" inc($3))!=("g" $4) || $5!~/^[1-9][0-9]*$/ || $6!~/^[1-9][0-9]*$/ || $5>65536 || $6>65536 || length($7)!=64 || length($8)!=64 || $7~/[^0-9a-f]/ || $8~/[^0-9a-f]/ {bad=1;exit 1}
	{if($0!=$1 " " $2 " " $3 " " $4 " " $5 " " $6 " " $7 " " $8 " " $9){bad=1;exit 1};print $3 " " $4 " " $5 " " $6 " " $7 " " $8}
	END {if(bad || NR!=1) exit 1}' "$1"
	;;
status-date)
	case $# in 0) ;; *) exit 2 ;; esac
	exec "$tool" +%s
	;;
status-native)
	case $# in 2) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" resources "$2"
	;;
status-fields)
	case $# in 4) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $2 in nvram | space | mount | metadata | setup) ;; *) exit 2 ;; esac
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "$3" "$4"
	;;
status-metadata)
	case $# in 1) ;; *) exit 2 ;; esac
	exec "$tool" -ildn "$1"
	;;
status-count)
	case $# in 1) ;; *) exit 1 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 1
	exec "$tool" -c <"$1"
	;;
status-snapshot)
	case $# in 1) ;; *) exit 1 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 1
	# Only the owned wrapper opens the source; no child is spawned before exec.
	# Native metadata was separately admitted. Pin and recheck its regular inode;
	# capped dd cannot follow a growing source indefinitely. Caller compares
	# immutable output size and fresh metadata before interpreting any JSON.
	exec 8<"$1" || exit 1
	[ -f /proc/self/fd/8 ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/8 ] || exit 1
	exec "$tool" bs=4096 count=17 <&8 2>/dev/null
	;;
status-config)
	case $# in 11) ;; *) exit 2 ;; esac
	case $4 in select | render) ;; *) exit 2 ;; esac
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 1; done
	[ -f "$3" ] && [ ! -L "$3" ] || exit 1
	case ${11} in '' | *[!0-9]*) exit 1 ;; esac
	[ "${11}" -gt 0 ] && [ "${11}" -le 65536 ] || exit 1
	export CFMGR_STATUS_MODE="$4" CFMGR_STATUS_NOW="$5" CFMGR_STATUS_BOOT="$6" CFMGR_STATUS_REPOSITORY="$7" CFMGR_STATUS_BRANCH="$8" CFMGR_STATUS_WAN="$9" CFMGR_STATUS_CLOCK="${10}"
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_size="${11}" -v cfmgr_json_mode=tree "$cfmgr_awk_program" <"$3"
	;;
status-render | health-render)
	case $# in 4) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in "$context"/dashboard) [ -f "$2" ] && [ ! -L "$2" ] || exit 2 ;; *) exit 2 ;; esac
	case $3 in -) ;; "$context"/rows) [ -f "$3" ] && [ ! -L "$3" ] || exit 2 ;; *) exit 2 ;; esac
	case $4 in 10 | 1[0-9] | [2-9][0-9] | 100) ;; *) exit 2 ;; esac
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$4" "$2" "$3"
	;;
status-nvram)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in productid | firmver | buildno | extendno | ntp_ready | wan0_primary | wan1_primary | wan0_proto | wan1_proto | wan0_ifname | wan1_ifname | wan0_pppoe_ifname | wan1_pppoe_ifname | wan0_ipaddr | wan1_ipaddr) ;; *) exit 2 ;; esac
	exec "$tool" get "$1"
	;;
status-realpath)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /jffs | /opt) ;; *) exit 2 ;; esac
	exec "$tool" -f "$1"
	;;
status-mount)
	case $# in 2) ;; *) exit 2 ;; esac
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in /*) ;; *) exit 2 ;; esac
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" "$2" "/proc/self/mountinfo"
	;;
status-space)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in /jffs | /opt) ;; *) exit 2 ;; esac
	exec "$tool" -Pk "$1"
	;;
native-dns-native-srv | native-dns-native-a)
	case $mode:$# in native-dns-native-srv:1) dns_host=_v2-origintunneld._tcp.argotunnel.com ;; native-dns-native-a:2) dns_host=$2 ;; *) exit 2 ;; esac
	case $mode in
	*-srv) dns_type=SRV ;;
	*)
		dns_type=A
		case $dns_host in '' | -* | *[!A-Za-z0-9.-]*) exit 2 ;; *.argotunnel.com) ;; *) exit 2 ;; esac
		[ "${#dns_host}" -le 253 ] || exit 2
		;;
	esac
	# Complete fixed argv always includes a host. No-host Usage is ambiguous.
	case $1 in
	q) exec "$tool" -q "$dns_type" "$dns_host" ;;
	long) exec "$tool" "--type=$dns_type" "$dns_host" ;;
	type) exec "$tool" "-type=$dns_type" -retry=1 -timeout=2 "$dns_host" ;;
	*) exit 2 ;;
	esac
	;;
native-dns-dig-srv)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" +time=2 +tries=1 +short SRV _v2-origintunneld._tcp.argotunnel.com
	;;
native-dns-dig-a)
	[ "$#" -eq 2 ] && [ "$1" = short ] || exit 2
	case $2 in '' | -* | *[!A-Za-z0-9.-]*) exit 2 ;; *.argotunnel.com) ;; *) exit 2 ;; esac
	[ "${#2}" -le 253 ] || exit 2
	exec "$tool" +time=2 +tries=1 +short A "$2"
	;;
native-dns-classify)
	[ "$#" -eq 3 ] || exit 2
	case $3 in '' | *[!0-9]*) exit 2 ;; esac
	# shellcheck disable=SC2016 # Fixed awk code, operands remain file data.
	exec "$tool" -v query_exit="$3" '
	 FILENAME==ARGV[1] { output=output $0 "\n"; next }
	 { error=error $0 "\n" }
	 END {
	   if (query_exit==0 && output!="" && error=="") { print "answer"; exit }
	   if (query_exit==1 && output=="" && error=="Invalid query type \"SRV\"\n") { print "unsupported"; exit }
	   if (query_exit==1 && output=="" && error=="nslookup: invalid query type \"\"\n") { print "syntax"; exit }
	   if (query_exit!=0 && output=="") {
	     count=split(error,lines,"\n"); usage=banner=description=optional=0; bad=0
	     for(i=1;i<=count;i++) {
	       if(lines[i]=="") continue
	       if(lines[i] ~ /^BusyBox v[0-9]+\.[0-9]+\.[0-9]+ .*multi-call binary\.$/) { banner++; continue }
	       if(lines[i]=="Usage: nslookup [HOST] [SERVER]") { usage++; continue }
	       if(lines[i]=="Query the nameserver for the IP address of the given HOST") { description++; continue }
	       if(lines[i]=="optionally using a specified DNS server") { optional++; continue }
	       bad=1
	     }
	     if(usage==1 && banner==1 && description==1 && optional==1 && !bad) { print "usage"; exit }
	   }
	   print "deferred"
	 }' "$1" "$2"
	;;
native-dns-parse-srv)
	[ "$#" -eq 2 ] || exit 2
	case $1 in native | dig) ;; *) exit 2 ;; esac
	# shellcheck disable=SC2016
	exec "$tool" -v provider="$1" '
	 function hostname(s,    n,a,i) {
	   sub(/\.$/,"",s)
	   if(length(s)>253 || s !~ /^[A-Za-z0-9.-]+$/ || s !~ /\.argotunnel\.com$/) return 0
	   n=split(s,a,"."); for(i=1;i<=n;i++) if(length(a[i])<1 || length(a[i])>63 || a[i] !~ /^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$/) return 0
	   return 1
	 }
	 function record(priority,weight,port,target) {
	   target=tolower(target)
	   if(priority !~ /^[0-9]+$/ || weight !~ /^[0-9]+$/ || length(priority)>5 || length(weight)>5 || priority>65535 || weight>65535 || port!="7844" || !hostname(target)) { bad=1; return }
	   sub(/\.$/,"",target)
	   if(!seen[target]++ && count<2) { count++; targets[count]=target }
	 }
	 length($0)>1024 || NR>64 || $0 ~ /[^ -~\t]/ { bad=1 }
	 provider=="dig" { if(NF!=4) bad=1; else record($1,$2,$3,$4); next }
	 provider=="native" && tolower($1)=="_v2-origintunneld._tcp.argotunnel.com" && $2=="service" && $3=="=" {
	   if(NF!=7) bad=1; else record($4,$5,$6,$7); next
	 }
	 provider=="native" && ($0=="" || $0=="Non-authoritative answer:" || $1=="Server:" || $1=="Address:") { next }
	 { bad=1 }
	 END { if(bad || !count) exit 1; for(i=1;i<=count;i++) printf "%s%s",targets[i],(i==count ? "\n" : " ") }
	' "$2"
	;;
native-dns-parse-a)
	[ "$#" -eq 3 ] || exit 2
	case $1 in native | dig) ;; *) exit 2 ;; esac
	# shellcheck disable=SC2016
	exec "$tool" -v provider="$1" -v target="$2" '
	 function ipv4(s,    a,n,i) {
	   n=split(s,a,"."); if(n!=4) return 0
	   for(i=1;i<=4;i++) if(a[i] !~ /^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0
	   return a[1]!=0 && a[1]!=127 && a[1]<224 && !(a[1]==169 && a[2]==254)
	 }
	 length($0)>1024 || NR>64 || $0 ~ /[^ -~\t]/ { bad=1 }
	 provider=="dig" { if(NF!=1 || !ipv4($1)) bad=1; else answers++; next }
	 provider=="native" && $1=="Name:" {
	   name=tolower($2); sub(/\.$/,"",name); if(NF!=2 || name!=target) bad=1; answer_name=1; next
	 }
	 provider=="native" && $1=="Address:" {
	   if(answer_name) { if(NF!=2 || !ipv4($2)) bad=1; else answers++ }
	   next
	 }
	 provider=="native" && ($0=="" || $0=="Non-authoritative answer:" || $1=="Server:") { next }
	 { bad=1 }
	 END { if(bad || !answers) exit 1; print "verified" }
	' "$3"
	;;
launch-config-check | launch-config-scope | launch-config-observe | launch-config-patch)
	case "$mode:$#" in launch-config-check:4 | launch-config-scope:4 | launch-config-observe:8 | launch-config-patch:8) ;; *) exit 2 ;; esac
	case $1 in '' | *[!0-9]*) exit 2 ;; esac
	[ "${#1}" -le 5 ] && [ "$1" -le 65536 ] || exit 2
	for path in "$2" "$3" "$4"; do
		case $path in /*) ;; *) exit 2 ;; esac
		[ -f "$path" ] && [ ! -L "$path" ] || exit 2
	done
	config_mode=${mode#launch-config-}
	if [ "$config_mode" = observe ] || [ "$config_mode" = patch ]; then
		CFMGR_CONFIG_UUID=$5 CFMGR_CONFIG_FILESYSTEM=$6 CFMGR_CONFIG_ROOT=$7 CFMGR_CONFIG_RELATIVE=$8
		export CFMGR_CONFIG_UUID CFMGR_CONFIG_FILESYSTEM CFMGR_CONFIG_ROOT CFMGR_CONFIG_RELATIVE
	fi
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_size="$1" -v cfmgr_json_mode=tree -v cfmgr_config_mode="$config_mode" "$cfmgr_awk_program" <"$4"
	;;
launch-copy)
	[ "$#" -eq 2 ] || exit 2
	[ -f "$1" ] && [ ! -L "$1" ] && [ ! -e "$2" ] && [ ! -L "$2" ] || exit 2
	exec "$tool" "$1" "$2"
	;;
launch-ls | launch-wc | launch-sha | launch-remove | launch-rmdir | launch-readonly)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	case $mode in
	launch-ls) exec "$tool" -ldn "$1" ;;
	launch-wc) exec "$tool" -c <"$1" ;;
	launch-sha) exec "$tool" <"$1" ;;
	launch-readonly)
		[ -f "$1" ] && [ ! -L "$1" ] || exit 2
		exec "$tool" 400 "$1"
		;;
	launch-remove)
		[ -f "$1" ] && [ ! -L "$1" ] || exit 2
		exec "$tool" "$1"
		;;
	launch-rmdir)
		# Native BusyBox -ef verifies the exact held Linux directory inode.
		# shellcheck disable=SC3013
		[ -d "$1" ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/4 ] || exit 2
		exec "$tool" "$1"
		;;
	esac
	;;
install-report-ls)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /usr/bin/logger | /usr/bin | /usr | /bin/busybox | /bin | /) ;; *) exit 2 ;; esac
	exec "$tool" -ldn "$1"
	;;
install-report)
	[ "$#" -eq 1 ] && [ "$1" = storage-lost ] || exit 2
	exec "$tool" -p user.err -t CFMGR '[CFMGR] Manager: Error: Entware storage lost; installation stopped'
	;;
launch-report)
	[ "$#" -eq 1 ] && [ "$1" = storage-unavailable ] || exit 2
	exec "$tool" -t CFMGR '[CFMGR] launch: error: Entware attachment unavailable; operation stopped'
	;;
repair-inventory)
	[ "$#" -eq 3 ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" "$cfmgr_awk_program" inventory-v1 "$2" "/proc/self/mountinfo" >"$3"
	;;
repair-awk)
	# shellcheck disable=SC2034 # Fixed imported library uses these explicit fields.
	[ "$#" -ge 5 ] && [ "$#" -le 13 ] || exit 2
	cfmgr_view_awk=cfmgr_probe_awk_exec cfmgr_view_context=$2 cfmgr_view_native_root=$3
	# Fixed controller-admitted RAM snapshot, never environment/source payload.
	# shellcheck disable=SC1090 # Caller-admitted private RAM library snapshot.
	. "$1" || exit 2
	cfmgr_probe_awk_exec() { exec "$tool" "$@"; }
	shift 3
	cfmgr_execution_view_awk "$@"
	;;
repair-identity)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -idn "$1"
	;;
repair-identity-parse)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" '
		function bit(c,yes) { return index(yes,c)>0 }
		{ if (NR!=1 || NF<5 || length($2)!=10) exit 1
		  p=$2; special=0
		  if (bit(substr(p,4,1),"sS")) special+=4
		  if (bit(substr(p,7,1),"sS")) special+=2
		  if (bit(substr(p,10,1),"tT")) special+=1
		  mode=special ? special "" : ""
		  for (i=2;i<=8;i+=3) mode=mode (4*bit(substr(p,i,1),"r")+2*bit(substr(p,i+1,1),"w")+bit(substr(p,i+2,1),"xst"))
		  printf "%s\t%s\t%s\t%s\n",$1,mode,$4,$5 }
		END { if (NR!=1) exit 1 }
	' "$1" >"$2"
	;;
repair-readlink | repair-list)
	[ "$#" -eq 2 ] || exit 2
	if [ "$mode" = repair-list ]; then exec "$tool" -1A "$1" >"$2"; fi
	exec "$tool" "$1" >"$2"
	;;
repair-copy)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" "$1" "$2"
	;;
repair-mkdir)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" -m "$2" "$1"
	;;
repair-chmod)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" "$2" "$1"
	;;
repair-link)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" -s -- "$1" "$2"
	;;
repair-file)
	[ "$#" -eq 1 ] || exit 2
	umask 077
	set -C
	: >"$1"
	;;
repair-root | repair-guard-root)
	[ "$#" -eq 1 ] || exit 2
	if [ "$mode" = repair-root ]; then exec "$tool" -t tmpfs -o size=8m,mode=700 tmpfs "$1"; fi
	exec "$tool" -t tmpfs -o size=64k,mode=700 tmpfs "$1"
	;;
repair-bind4)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o bind /proc/self/fd/4 "$1"
	;;
repair-bind7)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o bind /proc/self/fd/7 "$1"
	;;
repair-private)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o make-private "$1"
	;;
repair-unbindable)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o make-unbindable "$1"
	;;
repair-seal)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o remount,ro "$1"
	;;
repair-unmount)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" "$1"
	;;
repair-fifo)
	[ "$#" -eq 1 ] || exit 2
	umask 077
	exec "$tool" "$1" p
	;;
repair-remove)
	[ "$#" -ge 1 ] && [ "$#" -le 64 ] || exit 2
	LC_ALL=C
	export LC_ALL
	remove_bytes=0
	for remove_path; do
		case $remove_path in /*) ;; *) exit 2 ;; esac
		remove_bytes=$((remove_bytes + ${#remove_path} + 1))
		[ "$remove_bytes" -le 8192 ] || exit 2
	done
	exec "$tool" "$@"
	;;
repair-retire)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	# shellcheck disable=SC3013 # Exact inherited Linux claim inode, not a new name.
	[ -d "$1" ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/5 ] || exit 2
	exec "$tool" "$1"
	;;
repair-rmdir)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" "$1"
	;;
repair-report)
	[ "$#" -eq 1 ] || exit 2
	case $1 in
	storage-lost) message='[CFMGR] dependencies: error: Entware attachment lost; cleanup pending' ;;
	cleanup-pending) message='[CFMGR] dependencies: error: dependency cleanup pending' ;;
	cleanup-complete) message='[CFMGR] dependencies: error: Entware operation stopped; owned mounts released' ;;
	*) exit 2 ;;
	esac
	exec "$tool" -t CFMGR "$message"
	;;
repair-signal)
	[ "$#" -eq 2 ] || exit 2
	case $1 in '' | 0* | *[!0-9]*) exit 2 ;; esac
	case $2 in TERM | KILL) ;; *) exit 2 ;; esac
	exec "$tool" -"$2" "$1"
	;;
native-curl-version)
	case $# in 0) ;; *) exit 2 ;; esac
	exec "$tool" -q -V
	;;
native-curl-offline | native-curl-https)
	case "$mode:$#" in native-curl-offline:2) set -- "$1" "$2" http://127.0.0.1:9/ ;; native-curl-https:3) ;; *) exit 2 ;; esac
	case "$1:$2" in /*:/*) ;; *) exit 2 ;; esac
	case "$2" in *:*) exit 2 ;; esac
	if [ "$mode" = native-curl-https ]; then case $3 in https://*) ;; *) exit 2 ;; esac fi
	# One policy shared by offline option admission and the real HTTPS primitive.
	# -q MUST be first: ignore every curlrc. No redirects, proxy, implicit trust,
	# or environment-configured OpenSSL/loader state survives env-i launch.
	exec "$tool" -q --silent --show-error --proto '=https' --proto-redir '=https' \
		--tlsv1.2 --cacert "$1" --capath "$2" --proxy '' --noproxy '*' \
		--connect-timeout 1 --max-time 1 --head --output /dev/null --write-out '%{http_code}\n' --url "$3"
	;;
native-ca-decode)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in /*) ;; *) exit 2 ;; esac
	exec "$tool" crl2pkcs7 -nocrl -certfile "$1" -out /dev/null
	;;
native-rmdir)
	[ "$#" -eq 1 ] || exit 2
	case $1 in "$context/native.directory") ;; *) exit 2 ;; esac
	exec "$tool" "$1"
	;;
native-curl-features)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in "$context"/*) ;; *) exit 2 ;; esac
	# shellcheck disable=SC2016
	exec "$tool" '
		NR==1 { if ($1!="curl" || $2 !~ /^[0-9]+[.][0-9]+[.][0-9]+/) bad=1 }
		length($0)>4096 || NR>32 { bad=1 }
		$1=="Protocols:" { protocols++; for (i=2;i<=NF;i++) if ($i=="https") https=1 }
		$1=="Features:" { features++; for (i=2;i<=NF;i++) if ($i=="SSL") ssl=1 }
		END { exit bad || protocols!=1 || features!=1 || !https || !ssl ? 1 : 0 }
	' "$1"
	;;
native-ca-pem)
	case $# in 1) ;; *) exit 2 ;; esac
	case $1 in /*) ;; *) exit 2 ;; esac
	# Framing/count is separate: OpenSSL can decode a zero-certificate bundle.
	# shellcheck disable=SC2016
	exec "$tool" '
		length($0)>4096 || NR>32768 || $0 ~ /[^ -~]/ { bad=1; exit 1 }
		$0=="-----BEGIN CERTIFICATE-----" { if (inside || ++certs>1024) bad=1; inside=1; bytes=0; padded=0; next }
		$0=="-----END CERTIFICATE-----" { if (!inside || !bytes || bytes%4) bad=1; inside=0; next }
		inside { if (padded || length($0)<1 || length($0)>76 || $0 !~ /^[A-Za-z0-9+\/]+(=|==)?$/) bad=1
		  if (index($0,"=")) padded=1; bytes+=length($0); next }
		$0!~/^ *$/ && $0!~/^#/ { bad=1 }
		END { exit bad || inside || certs<1 ? 1 : 0 }
	' "$1"
	;;
install-config)
	[ "$#" -eq 7 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	# The trusted local package has been inventoried and hash-verified before
	# this finite import. The filename is fixed, never supplied as arbitrary code.
	# shellcheck disable=SC1091
	. "$1/modules/lib/config.sh" || exit 2
	shift
	cfmgr_config_defaults_exec "$tool" "$@"
	exit 2
	;;
install-copy | install-rename | install-publish)
	[ "$#" -eq 2 ] || exit 2
	case "$1:$2" in /*:/*) ;; *) exit 2 ;; esac
	case "$mode" in
	install-copy) exec "$tool" "$1" "$2" ;;
	install-rename) exec "$tool" -f "$1" "$2" ;;
	install-publish) exec "$tool" -n "$1" "$2" ;;
	esac
	;;
install-config-check)
	[ "$#" -eq 3 ] || exit 2
	case $1:$2 in /*:/*) ;; *) exit 2 ;; esac
	case $3 in '' | *[!0-9]*) exit 2 ;; esac
	[ "${#3}" -le 5 ] && [ "$3" -gt 0 ] && [ "$3" -le 65536 ] || exit 2
	for parser in "$2/modules/lib/config.sh" "$2/modules/lib/config.sh" "$2/modules/lib/config.sh"; do
		[ -f "$parser" ] && [ ! -L "$parser" ] || exit 2
	done
	[ -f "$1" ] && [ ! -L "$1" ] || exit 2
	cfmgr_worker_program "$@"
	exec "$tool" -v cfmgr_json_size="$3" -v cfmgr_json_mode=tree -v cfmgr_config_mode=fresh \
		"$cfmgr_awk_program" <"$1"
	;;
install-sha | install-wc | install-ls | install-mkdir-private | install-mkdir-public | install-chmod-private | install-chmod-readonly | install-chmod-executable | install-df | install-remove)
	[ "$#" -eq 1 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	case "$mode" in
	install-sha) exec "$tool" <"$1" ;;
	install-wc) exec "$tool" -c <"$1" ;;
	install-ls) exec "$tool" -ldn "$1" ;;
	install-remove)
		case $1 in */.setup.complete) ;; *) exit 2 ;; esac
		[ -f "$1" ] && [ ! -L "$1" ] || exit 1
		exec "$tool" "$1"
		;;

	install-mkdir-private) exec "$tool" -m 700 "$1" ;;
	install-mkdir-public) exec "$tool" -m 755 "$1" ;;
	install-chmod-private) exec "$tool" 600 "$1" ;;
	install-chmod-readonly) exec "$tool" 644 "$1" ;;
	install-chmod-executable) exec "$tool" 755 "$1" ;;
	install-df) exec "$tool" -Pk "$1" ;;
	esac
	;;
install-flush)
	[ "$#" -eq 0 ] || exit 2
	(: <&3) 2>/dev/null || exit 2
	exec "$tool" /proc/self/fd/3
	;;
install-nvram)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" get jffs2_scripts
	;;
jq-good)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -er '.answer[1] == 2 and .ok == true' json.good
	;;
jq-bad)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -e . json.bad
	;;
wc-jq)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -c <jq-good.out
	;;
wc-sha)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -c <sha-bytes.out
	;;
sha-bytes)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" bytes
	;;
sha-good)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" --check --status checksum.good
	;;
sha-bad)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" --check --status checksum.bad
	;;
timeout-exit)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" --foreground --kill-after=0.05s 0.5s "$1" "$2" exit-seven
	;;
timeout-expiry)
	[ "$#" -eq 3 ] || exit 2
	exec "$tool" --foreground --kill-after=0.05s 0.1s "$1" "$2" sleep-short "$3" "$context"
	;;
flock-first | flock-entware-first)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 4
	;;
flock-compete | flock-after | flock-entware-compete | flock-entware-after)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 5
	;;
flock-release | flock-entware-release)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -u 4
	;;
flock-finish | flock-entware-finish)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -u 5
	;;
dig-version)
	[ "$#" -eq 0 ] || exit 2
	# ISC BIND prints its successful -v banner on stderr. This probe only
	# establishes executability; normalize that fixed version invocation.
	exec "$tool" -v 2>&1
	;;
blkid)
	[ "$#" -eq 1 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	[ -b "$1" ] || exit 2
	exec "$tool" "$1"
	;;
*) exit 2 ;;
esac
