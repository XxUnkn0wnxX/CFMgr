#!/bin/sh
# shellcheck disable=SC2034,SC2154 # Explicit category inputs and output fields.
# Category owner: execution. Sourcing defines functions only.

# ---- prerequisites ----
# Source-inert capability checks. The caller owns admission, context and attachment.
# cfmgr_prerequisites_attachment_ok and cfmgr_prerequisites_admit_tool are
# mandatory, fixed trusted caller functions. Admission: 0 safe, 1 missing/unusable,
# 2 unsafe, 3 unresolved ownership. Rechecks require a new private context.
# Return: 0 capability present, 1 unusable, 2 invalid/native supervision unavailable,
# 3 unresolved ownership. Result variables are capability evidence, never readiness.

cfmgr_prerequisites_identity() {
	cfmgr_identity_read=0
	case "$1" in '' | *[!0-9]*) return 1 ;; esac
	# A task can disappear before open; callers classify absence themselves.
	IFS= read -r cfmgr_identity_line 2>/dev/null <"/proc/$1/stat" || return 1
	cfmgr_identity_read=1
	case ${cfmgr_identity_line%% *} in "$1") ;; *) return 1 ;; esac
	cfmgr_identity_tail=${cfmgr_identity_line##*) }
	cfmgr_identity_ifs=$IFS
	IFS=' '
	# Numeric proc fields are deliberately split, with pathname expansion disabled.
	# shellcheck disable=SC2086
	set -- $cfmgr_identity_tail
	IFS=$cfmgr_identity_ifs
	[ "$#" -ge 20 ] || return 1
	cfmgr_identity_state=$1
	cfmgr_identity_parent=$2
	shift 19
	cfmgr_identity_start=$1
	case "$cfmgr_identity_parent:$cfmgr_identity_start" in *[!0-9:]* | :*) return 1 ;; esac
}

cfmgr_prerequisites_owned() {
	# A failed read may mean this exact direct child was already reaped by ash.
	# A positively read mismatch remains unknown even if the task then vanishes.
	if ! cfmgr_prerequisites_identity "$cfmgr_probe_pid"; then
		if [ "$cfmgr_identity_read" -eq 0 ] && [ ! -e "/proc/$cfmgr_probe_pid" ] && [ ! -L "/proc/$cfmgr_probe_pid" ]; then return 1; fi
		return 3
	fi
	case $cfmgr_identity_start in "$cfmgr_probe_start") ;; *) return 3 ;; esac
	case $cfmgr_identity_parent in "$cfmgr_probe_owner") ;; *) return 3 ;; esac
	IFS= read -r cfmgr_probe_current_boot </proc/sys/kernel/random/boot_id || return 3
	case $cfmgr_probe_current_boot in "$cfmgr_probe_boot") ;; *) return 3 ;; esac
}

# Observe only the launched direct child. Absence allows its exact wait; unknown
# ownership retains evidence and never authorizes signalling or a blocking wait.
_cfmgr_prerequisites_observe() {
	if cfmgr_prerequisites_owned; then cfmgr_probe_observation=0; else cfmgr_probe_observation=$?; fi
	case "$cfmgr_probe_observation" in
	0 | 1) return 0 ;;
	*)
		cfmgr_probe_status=unresolved
		return 3
		;;
	esac
}

cfmgr_prerequisites_child() {
	case $cfmgr_probe_mode in timeout-expiry | health-timeout-expiry) ;; *) return 0 ;; esac
	[ -f "$cfmgr_probe_context/timeout.child" ] || return 1
	IFS=' ' read -r cfmgr_probe_child_pid cfmgr_probe_child_parent cfmgr_probe_child_start cfmgr_probe_child_boot cfmgr_probe_child_extra <"$cfmgr_probe_context/timeout.child" || return 1
	case $cfmgr_probe_child_extra in '') ;; *) return 1 ;; esac
	case $cfmgr_probe_child_parent in "$cfmgr_probe_pid") ;; *) return 1 ;; esac
	case $cfmgr_probe_child_boot in "$cfmgr_probe_boot") ;; *) return 1 ;; esac
	case "$cfmgr_probe_child_pid:$cfmgr_probe_child_start" in *[!0-9:]* | :*) return 1 ;; esac
	if [ ! -d "/proc/$cfmgr_probe_child_pid" ]; then
		return 0
	fi
	cfmgr_prerequisites_identity "$cfmgr_probe_child_pid" || return $?
	case $cfmgr_identity_start in "$cfmgr_probe_child_start") ;; *) return 1 ;; esac
	case $cfmgr_identity_parent in "$cfmgr_probe_pid") ;; *) return 1 ;; esac
}

# shellcheck disable=SC2034
cfmgr_prerequisites_now() {
	IFS=' ' read -r cfmgr_probe_uptime cfmgr_probe_idle </proc/uptime || return 1
	cfmgr_probe_now=${cfmgr_probe_uptime%%.*}
	case "$cfmgr_probe_now" in '' | *[!0-9]*) return 1 ;; esac
}

# Final report probes use the existing two-second supervision slice, clamped
# to the immutable phase deadline. Check again after supervisor clock admission.
cfmgr_prerequisites_report_deadline() {
	case $1 in '' | *[!0-9]*) return 2 ;; esac
	[ "$cfmgr_probe_now" -lt "$1" ] || return 1
	[ "$cfmgr_probe_deadline" -le "$1" ] || cfmgr_probe_deadline=$1
}

# Check the native supervision substrate even when every required tool is absent.
cfmgr_prerequisites_supervisor() {
	IFS= read -r cfmgr_probe_boot </proc/sys/kernel/random/boot_id || return 2
	IFS= read -r cfmgr_probe_self </proc/self/stat || return 2
	cfmgr_probe_owner=${cfmgr_probe_self%% *}
	cfmgr_prerequisites_now || return 2
}

# Firmware sleep accepts whole seconds. The admitted native usleep applet keeps
# supervision responsive without requiring FEATURE_FLOAT_SLEEP or Entware.
cfmgr_prerequisites_pause() {
	case "$#:${1:-}" in
	0:) /bin/usleep 50000 ;;
	1:first) /bin/usleep 10000 ;;
	*) return 2 ;;
	esac
}

_cfmgr_prerequisites_attachment() {
	case ${cfmgr_config_lock_fd0:-0} in 1) cfmgr_store_fd_is "${cfmgr_store_lock:-}" 0 || return 1 ;; esac
	case ${cfmgr_probe_mode:-none} in
	acquire-*) cfmgr_acquire_attached ;;
	install-report | install-report-ls) cfmgr_bootstrap_native_attached ;;
	launch-*) cfmgr_launch_attachment_ok ;;
	status-* | health-*) cfmgr_status_attachment_ok ;;
	store-*) cfmgr_store_attachment_ok ;;
	archive-*) cfmgr_archive_attachment_ok ;;
	history-*) cfmgr_backup_history_attached ;;
	repair-*) cfmgr_dependencies_attachment_ok ;;
	*) cfmgr_prerequisites_attachment_ok ;;
	esac
}

# Exports cfmgr_probe_* results for the admitted controller.
# shellcheck disable=SC2034
cfmgr_prerequisites_run() {
	# MODE CONTEXT SH PROBE ENV AWK SLEEP WC TOOL [FIXED_OPERANDS...]
	# Fresh private RAM context and tool admission belong to the controller.
	# Output files are retained; return 3 also retains child identities/guards.
	# Health reservations precede every file creation/spawn, and an unresolved
	# owned child must never be erased by another attempted health operation.
	case ${cfmgr_health_active:-0}:$1 in
	1:jq-* | 1:sha-* | 1:wc-jq | 1:wc-sha | 1:timeout-* | 1:flock-* | 1:dig-version)
		cfmgr_health_borrowed=$1
		shift
		set -- "health-$cfmgr_health_borrowed" "$@"
		;;
	esac
	case ${1:-} in health-*) cfmgr_health_reserve "$1" || return $? ;; esac
	case ${1:-} in status-render | status-render-count) cfmgr_status_final_reserve || return $? ;; esac
	cfmgr_probe_status=invalid
	cfmgr_probe_exit=
	cfmgr_probe_pid=
	cfmgr_probe_start='' cfmgr_probe_owner='' cfmgr_probe_boot=''
	cfmgr_probe_child_pid=
	cfmgr_probe_child_start='' cfmgr_probe_child_parent='' cfmgr_probe_child_boot=''
	cfmgr_probe_stdout='' cfmgr_probe_stderr=''
	cfmgr_probe_reason=arguments
	[ "$#" -ge 9 ] || return 2
	case $1 in
	repair-remove) ;; # Its existing exact finite operand gate remains below.
	store-archive-config) [ "$#" -eq 23 ] || return 2 ;;
	*) [ "$#" -le 22 ] || return 2 ;;
	esac
	cfmgr_probe_mode=$1 cfmgr_probe_context=$2 cfmgr_probe_shell=$3
	cfmgr_probe_helper=$4 cfmgr_probe_env=$5 cfmgr_probe_awk=$6
	cfmgr_probe_sleep=$7 cfmgr_probe_wc=$8 cfmgr_probe_tool=$9
	case "$cfmgr_probe_mode" in
	health-inventory | health-scope | health-request) [ "$#" -eq 19 ] || return 2 ;;
	health-get) [ "$#" -eq 15 ] || return 2 ;;
	health-response) [ "$#" -eq 16 ] || return 2 ;;
	health-protected | health-current | health-storage | health-uuid | health-request-check | health-trace | health-frame | health-render) [ "$#" -eq 13 ] || return 2 ;;
	health-config) [ "$#" -eq 20 ] || return 2 ;;
	health-snapshot | health-nvram | health-space | health-realpath | health-metadata | health-count | health-render-count | health-curl-features | health-ca-pem | health-ca-decode) [ "$#" -eq 10 ] || return 2 ;;
	health-fields) [ "$#" -eq 13 ] || return 2 ;;
	health-native | health-mount | health-curl-offline | health-count-pair) [ "$#" -eq 11 ] || return 2 ;;
	health-blkid) [ "$#" -eq 10 ] || return 2 ;;
	health-jq-good | health-jq-bad | health-sha-bytes | health-sha-good | health-sha-bad | health-wc-jq | health-wc-sha | health-timeout-exit | health-timeout-expiry | health-flock-first | health-flock-compete | health-flock-after | health-flock-release | health-flock-finish | health-flock-entware-first | health-flock-entware-compete | health-flock-entware-after | health-flock-entware-release | health-flock-entware-finish | health-dig-version | health-uname | health-date | health-curl-version) [ "$#" -eq 9 ] || return 2 ;;
	history-meta | history-proc-meta | history-inode | history-count | history-digest | history-realpath | history-readlink | history-hexdump | history-script-prefix | history-blkid | history-proc-list | history-proc-pids | history-policy-decode) [ "$#" -eq 10 ] || return 2 ;;
	history-directory | history-mount | history-cron-read | history-writer-fd-list) [ "$#" -eq 11 ] || return 2 ;;
	history-volume | history-argv | history-writer-parse) [ "$#" -eq 13 ] || return 2 ;;
	history-parse) [ "$#" -eq 15 ] || return 2 ;;
	history-policy-json | history-append | history-frame) [ "$#" -eq 14 ] || return 2 ;;
	history-account | history-lock | history-syslog-version | history-syslog-check | history-logrotate-version | history-logrotate-debug) [ "$#" -eq 9 ] || return 2 ;;
	store-archive-plan | archive-control)
		case $cfmgr_probe_mode in store-archive-plan) [ "$#" -eq 12 ] ;; *) [ "$#" -eq 14 ] ;; esac || return 2
		;;
	archive-chmod) [ "$#" -eq 13 ] || return 2 ;;
	archive-count | archive-meta | archive-inode | archive-digest | archive-gunzip-test | archive-timezone | archive-date | archive-source-realpath | archive-source-blkid | archive-hexdump) [ "$#" -eq 10 ] || return 2 ;;
	archive-source-mount | archive-header-hex) [ "$#" -eq 11 ] || return 2 ;;
	archive-tar-header) [ "$#" -eq 13 ] || return 2 ;;
	archive-payload-json | archive-write) [ "$#" -eq 14 ] || return 2 ;;
	archive-payload-yaml | archive-payload-match | archive-stage-inodes) [ "$#" -eq 12 ] || return 2 ;;
	archive-payload-index) [ "$#" -eq 13 ] || return 2 ;;
	archive-browser-review) [ "$#" -eq 13 ] || return 2 ;;
	archive-browser-manifest) [ "$#" -eq 11 ] || return 2 ;;
	archive-payload-pem) [ "$#" -eq 11 ] || return 2 ;;
	archive-memory | archive-flush) [ "$#" -eq 9 ] || return 2 ;;
	archive-space | archive-space-values | archive-stage-meta) [ "$#" -eq 10 ] || return 2 ;;
	archive-directory | archive-stage-mkdir | archive-stage-rmdir | archive-archive-remove) [ "$#" -eq 12 ] || return 2 ;;
	archive-publish) [ "$#" -eq 15 ] || return 2 ;;
	archive-format-inventory) [ "$#" -eq 14 ] || return 2 ;;
	archive-format-manifest | archive-unlink) [ "$#" -eq 12 ] || return 2 ;;
	archive-list-compare) [ "$#" -eq 11 ] || return 2 ;;
	archive-copy-blocks | archive-copy-tail | archive-copy-small) [ "$#" -eq 15 ] || return 2 ;;
	archive-tar-create) [ "$#" -eq 14 ] || return 2 ;;
	archive-gzip | archive-gunzip | archive-tar-list | archive-tar-verbose | archive-tar-bodies | archive-metahex | archive-base64) [ "$#" -eq 13 ] || return 2 ;;
	acquire-api | acquire-raw) [ "$#" -eq 14 ] || return 2 ;;
	acquire-curl-version) [ "$#" -eq 9 ] || return 2 ;;
	acquire-curl-offline | acquire-manifest | acquire-entry | acquire-chmod) [ "$#" -eq 11 ] || return 2 ;;
	acquire-extract) [ "$#" -eq 12 ] || return 2 ;;
	acquire-awk | acquire-awk-file) [ "$#" -eq 11 ] || return 2 ;;
	acquire-catalog) [ "$#" -eq 12 ] || return 2 ;;
	acquire-text) [ "$#" -eq 13 ] || return 2 ;;
	acquire-curl-features | acquire-ca-pem | acquire-ca-decode | acquire-wc | acquire-lines | acquire-ls | acquire-digest | acquire-shell | acquire-mkdir | acquire-remove | acquire-rmdir) [ "$#" -eq 10 ] || return 2 ;;
	store-backup-config) [ "$#" -eq 18 ] || return 2 ;;
	store-archive-config) [ "$#" -eq 23 ] || return 2 ;;
	store-backup-mounts | store-backup-mount) [ "$#" -eq 11 ] || return 2 ;;
	store-backup-blkid) [ "$#" -eq 10 ] || return 2 ;;
	store-backup-mkdir | store-backup-chmod) [ "$#" -eq 9 ] || return 2 ;;
	store-settings) [ "$#" -eq 17 ] || return 2 ;;
	store-copy | store-move | store-intent | store-space-frame) [ "$#" -eq 11 ] || return 2 ;;
	store-lock | store-flush) [ "$#" -eq 9 ] || return 2 ;;
	store-count | store-meta | store-meta-frame | store-snapshot | store-digest | store-digest-frame | store-lock-create | store-lock-test | store-mkdir | store-remove | store-rmdir | store-space) [ "$#" -eq 10 ] || return 2 ;;
	status-config) [ "$#" -eq 20 ] || return 2 ;;
	status-snapshot | status-nvram | status-space | status-realpath | status-metadata | status-count | status-render-count) [ "$#" -eq 10 ] || return 2 ;;
	status-fields) [ "$#" -eq 13 ] || return 2 ;;
	status-native | status-mount) [ "$#" -eq 11 ] || return 2 ;;
	status-render) [ "$#" -eq 13 ] || return 2 ;;
	status-date) [ "$#" -eq 9 ] || return 2 ;;
	launch-config-check | launch-config-scope) [ "$#" -eq 13 ] || return 2 ;;
	launch-config-observe | launch-config-patch) [ "$#" -eq 17 ] || return 2 ;;
	launch-copy) [ "$#" -eq 11 ] || return 2 ;;
	launch-ls | launch-wc | launch-sha | launch-remove | launch-rmdir | launch-report | launch-readonly) [ "$#" -eq 10 ] || return 2 ;;
	repair-awk) [ "$#" -ge 14 ] && [ "$#" -le 22 ] || return 2 ;;
	repair-inventory) [ "$#" -eq 12 ] || return 2 ;;
	repair-identity-parse | repair-readlink | repair-list | repair-copy | repair-mkdir | repair-chmod | repair-link | repair-signal) [ "$#" -eq 11 ] || return 2 ;;
	repair-remove) [ "$#" -ge 10 ] && [ "$#" -le 73 ] || return 2 ;;
	repair-report | repair-identity | repair-file | repair-root | repair-guard-root | repair-bind4 | repair-bind7 | repair-private | repair-unbindable | repair-seal | repair-unmount | repair-fifo | repair-rmdir | repair-retire) [ "$#" -eq 10 ] || return 2 ;;
	native-curl-offline) [ "$#" -eq 11 ] || return 2 ;;
	native-curl-https) [ "$#" -eq 12 ] || return 2 ;;
	native-curl-version) [ "$#" -eq 9 ] || return 2 ;;
	native-dns-native-srv) [ "$#" -eq 10 ] || return 2 ;;
	native-dns-dig-srv) [ "$#" -eq 9 ] || return 2 ;;
	native-dns-native-a | native-dns-dig-a | native-dns-parse-srv) [ "$#" -eq 11 ] || return 2 ;;
	native-dns-classify | native-dns-parse-a) [ "$#" -eq 12 ] || return 2 ;;
	native-curl-features | native-ca-pem | native-ca-decode | native-rmdir) [ "$#" -eq 10 ] || return 2 ;;
	install-copy | install-rename | install-publish) [ "$#" -eq 11 ] || return 2 ;;
	install-report | install-report-ls | install-sha | install-wc | install-ls | install-mkdir-private | install-mkdir-public | install-chmod-private | install-chmod-readonly | install-chmod-executable | install-df | install-remove) [ "$#" -eq 10 ] || return 2 ;;
	install-flush | install-nvram) [ "$#" -eq 9 ] || return 2 ;;
	install-config-check) [ "$#" -eq 12 ] || return 2 ;;
	install-config) [ "$#" -eq 16 ] || return 2 ;;
	jq-good | jq-bad | sha-bytes | sha-good | sha-bad | wc-jq | wc-sha | timeout-exit | timeout-expiry | flock-first | flock-compete | flock-after | flock-release | flock-finish | flock-entware-first | flock-entware-compete | flock-entware-after | flock-entware-release | flock-entware-finish | dig-version) [ "$#" -eq 9 ] || return 2 ;;
	blkid)
		[ "$#" -eq 10 ] || return 2
		case "${10}" in /*) ;; *) return 2 ;; esac
		[ -b "${10}" ] || return 2
		;;
	*) return 2 ;;
	esac
	for cfmgr_probe_path in "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_env" "$cfmgr_probe_awk" "$cfmgr_probe_sleep" "$cfmgr_probe_wc" "$cfmgr_probe_tool"; do
		case "$cfmgr_probe_path" in /*) ;; *) return 2 ;; esac
		[ -f "$cfmgr_probe_path" ] && [ -x "$cfmgr_probe_path" ] || return 2
	done
	case "$cfmgr_probe_context" in /*) ;; *) return 2 ;; esac
	[ -d "$cfmgr_probe_context" ] || return 2
	cfmgr_probe_reason=native-supervisor
	cfmgr_prerequisites_supervisor || return 2
	cfmgr_probe_deadline=$((cfmgr_probe_now + 2))
	case $cfmgr_probe_mode in health-*)
		case $cfmgr_probe_mode in
		health-get) cfmgr_probe_deadline=$((cfmgr_probe_now + 4)) ;;
		health-render | health-render-count) cfmgr_prerequisites_report_deadline "${cfmgr_health_final_deadline:-}" || return $? ;;
		esac
		case $cfmgr_probe_mode in health-render | health-render-count) ;; *)
			[ "$cfmgr_health_collect_deadline" -ge "$cfmgr_probe_deadline" ] || cfmgr_probe_deadline=$cfmgr_health_collect_deadline
			;;
		esac
		;;
	esac
	case $cfmgr_probe_mode in history-*)
		cfmgr_archive_uint "${cfmgr_history_deadline:-}" && [ "$cfmgr_history_deadline" -gt "$cfmgr_probe_now" ] || return 1
		cfmgr_probe_deadline=$cfmgr_history_deadline
		;;
	esac
	case $cfmgr_probe_mode in archive-*)
		cfmgr_archive_uint "${cfmgr_archive_deadline:-}" && [ "$cfmgr_archive_deadline" -gt "$cfmgr_probe_now" ] || return 2
		cfmgr_archive_uint "${cfmgr_archive_limit:-}" && [ "$cfmgr_archive_limit" -gt 0 ] || return 2
		cfmgr_probe_deadline=$cfmgr_archive_deadline
		;;
	esac
	case $cfmgr_probe_mode in native-dns-native-srv | native-dns-native-a | native-dns-dig-srv | native-dns-dig-a) cfmgr_probe_deadline=$((cfmgr_probe_now + 4)) ;; esac
	case $cfmgr_probe_mode in acquire-api | acquire-raw) cfmgr_probe_deadline=$((cfmgr_probe_now + 12)) ;; esac
	case $cfmgr_probe_mode in acquire-*)
		case ${cfmgr_acquire_deadline:-} in '' | *[!0-9]*) return 2 ;; esac
		[ "$cfmgr_probe_now" -lt "$cfmgr_acquire_deadline" ] || return 1
		[ "$cfmgr_acquire_deadline" -ge "$cfmgr_probe_deadline" ] || cfmgr_probe_deadline=$cfmgr_acquire_deadline
		;;
	esac
	case $cfmgr_probe_mode in store-*)
		case ${cfmgr_store_deadline:-} in
		'' | *[!0-9]*) return 2 ;;
		*)
			[ "$cfmgr_probe_now" -lt "$cfmgr_store_deadline" ] || return 1
			[ "$cfmgr_store_deadline" -ge "$cfmgr_probe_deadline" ] || cfmgr_probe_deadline=$cfmgr_store_deadline
			;;
		esac
		;;
	esac
	case $cfmgr_probe_mode in status-*)
		case $cfmgr_probe_mode in
		status-render | status-render-count) cfmgr_prerequisites_report_deadline "${cfmgr_status_final_deadline:-}" || return $? ;;
		*)
			case ${cfmgr_status_deadline:-} in
			[0-9]*) [ "$cfmgr_status_deadline" -ge "$cfmgr_probe_deadline" ] || cfmgr_probe_deadline=$cfmgr_status_deadline ;;
			esac
			;;
		esac
		;;
	esac
	case $cfmgr_probe_mode in repair-*)
		case ${cfmgr_dependencies_operation_deadline:-} in
		'') ;;
		*[!0-9]*) return 2 ;;
		*)
			[ "$cfmgr_probe_now" -lt "$cfmgr_dependencies_operation_deadline" ] || return 1
			[ "$cfmgr_dependencies_operation_deadline" -ge "$cfmgr_probe_deadline" ] || cfmgr_probe_deadline=$cfmgr_dependencies_operation_deadline
			;;
		esac
		;;
	esac
	_cfmgr_prerequisites_attachment || {
		cfmgr_probe_reason=attachment
		return 1
	}
	cfmgr_probe_label=$cfmgr_probe_mode
	case "$cfmgr_probe_mode" in
	health-timeout-exit) set -- "$@" "$cfmgr_probe_shell" "$cfmgr_probe_helper" ;;
	health-timeout-expiry) set -- "$@" "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_sleep" ;;
	esac
	case "$cfmgr_probe_mode" in
	install-* | native-* | repair-* | launch-* | status-* | health-* | store-* | acquire-* | archive-* | history-*)
		cfmgr_probe_serial=${cfmgr_probe_serial:-0}
		case "$cfmgr_probe_serial" in '' | *[!0-9]*) return 2 ;; esac
		[ "${#cfmgr_probe_serial}" -le 6 ] || return 2
		cfmgr_probe_serial=$((cfmgr_probe_serial + 1))
		cfmgr_probe_label=$cfmgr_probe_mode.$cfmgr_probe_serial
		;;
	esac
	cfmgr_probe_stdout=$cfmgr_probe_context/$cfmgr_probe_label.out
	cfmgr_probe_stderr=$cfmgr_probe_context/$cfmgr_probe_label.err
	# A fresh private context and noclobber avoid replacing retained evidence.
	(
		umask 077
		set -C
		: >"$cfmgr_probe_stdout" && : >"$cfmgr_probe_stderr"
	) || return 2
	case ${cfmgr_config_lock_fd0:-0} in
	1)
		if _cfmgr_prerequisites_start_locked "$@" 9<&0; then :; else
			cfmgr_probe_reason=lock-inheritance
			return 2
		fi
		;;
	*)
		(_cfmgr_prerequisites_exec "$@") >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr" &
		cfmgr_probe_pid=$!
		;;
	esac
	# Save identity before supervising. A vanished immediate child is already reapable.
	if cfmgr_prerequisites_identity "$cfmgr_probe_pid"; then
		cfmgr_probe_start=$cfmgr_identity_start
		case $cfmgr_identity_parent in
		"$cfmgr_probe_owner") ;;
		*)
			cfmgr_probe_status=unresolved
			return 3
			;;
		esac
	elif [ "$cfmgr_identity_read" -eq 0 ] && [ ! -e "/proc/$cfmgr_probe_pid" ] && [ ! -L "/proc/$cfmgr_probe_pid" ]; then
		cfmgr_probe_start=
	else
		cfmgr_probe_status=unresolved
		return 3
	fi
	cfmgr_probe_reason=
	cfmgr_probe_first_pause=1
	while :; do
		_cfmgr_prerequisites_observe || return 3
		[ "$cfmgr_probe_observation" -eq 1 ] && break
		case $cfmgr_identity_state in Z) break ;; esac
		if ! _cfmgr_prerequisites_attachment; then cfmgr_probe_reason=attachment; fi
		cfmgr_prerequisites_now || cfmgr_probe_reason=clock
		[ "$cfmgr_probe_now" -lt "$cfmgr_probe_deadline" ] || cfmgr_probe_reason=deadline
		case $cfmgr_probe_reason in
		'') ;;
		*)
			# The timeout mode has exactly one fixed child. Missing ownership evidence
			# cannot be replaced by assuming that killing timeout ends its child.
			cfmgr_prerequisites_child || {
				cfmgr_probe_status=unresolved
				return 3
			}
			case $cfmgr_probe_child_pid in
			'') ;;
			*)
				if [ -d "/proc/$cfmgr_probe_child_pid" ]; then
					cfmgr_prerequisites_child || {
						cfmgr_probe_status=unresolved
						return 3
					}
					kill -TERM "$cfmgr_probe_child_pid" || :
				fi
				;;
			esac
			_cfmgr_prerequisites_observe || return 3
			if [ "$cfmgr_probe_observation" -eq 0 ]; then
				case $cfmgr_identity_state in Z) ;; *) kill -TERM "$cfmgr_probe_pid" || : ;; esac
			fi
			break
			;;
		esac
		case $cfmgr_probe_first_pause in
		1)
			# Give short children one early completion check; continuing work keeps
			# the ordinary pause cadence. Failure/termination pauses stay unchanged.
			cfmgr_probe_first_pause=0
			cfmgr_prerequisites_pause first
			;;
		*) cfmgr_prerequisites_pause ;;
		esac || {
			cfmgr_probe_status=unresolved
			return 3
		}
	done
	case $cfmgr_probe_reason in
	'') ;;
	*)
		cfmgr_probe_attempt=0
		while [ "$cfmgr_probe_attempt" -lt 10 ]; do
			_cfmgr_prerequisites_observe || return 3
			[ "$cfmgr_probe_observation" -eq 1 ] && break
			case $cfmgr_identity_state in Z) break ;; esac
			cfmgr_prerequisites_pause || {
				cfmgr_probe_status=unresolved
				return 3
			}
			cfmgr_probe_attempt=$((cfmgr_probe_attempt + 1))
		done
		_cfmgr_prerequisites_observe || return 3
		if [ "$cfmgr_probe_observation" -eq 0 ]; then
			case $cfmgr_identity_state in
			Z) ;;
			*)
				# Never force the parent out before it has reaped the tracked child.
				cfmgr_prerequisites_child || {
					cfmgr_probe_status=unresolved
					return 3
				}
				case $cfmgr_probe_child_pid in
				'') ;;
				*)
					if [ -d "/proc/$cfmgr_probe_child_pid" ]; then
						kill -KILL "$cfmgr_probe_child_pid" || :
						cfmgr_probe_status=unresolved
						return 3
					fi
					;;
				esac
				_cfmgr_prerequisites_observe || return 3
				if [ "$cfmgr_probe_observation" -eq 0 ]; then
					case $cfmgr_identity_state in
					Z) ;;
					*)
						kill -KILL "$cfmgr_probe_pid" || :
						cfmgr_prerequisites_pause || :
						;;
					esac
				fi
				;;
			esac
		fi
		;;
	esac
	_cfmgr_prerequisites_observe || return 3
	if [ "$cfmgr_probe_observation" -eq 0 ]; then
		case $cfmgr_identity_state in
		Z) ;;
		*)
			cfmgr_probe_status=unresolved
			return 3
			;;
		esac
	fi
	if wait "$cfmgr_probe_pid"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi
	case $cfmgr_probe_mode in
	timeout-expiry | health-timeout-expiry)
		if ! cfmgr_prerequisites_child || [ -d "/proc/$cfmgr_probe_child_pid" ]; then
			cfmgr_probe_status=unresolved
			return 3
		fi
		;;
	esac
	_cfmgr_prerequisites_attachment || cfmgr_probe_reason=attachment
	cfmgr_probe_status=reaped
	case $cfmgr_probe_reason in '') ;; *) return 1 ;; esac
	return 0
}

cfmgr_prerequisites_text() {
	# Only bounded regular outputs and a native WC count produced by run are passed.
	IFS=' 	' read -r cfmgr_prereq_count cfmgr_prereq_count_extra <"$3" || return 1
	[ -z "$cfmgr_prereq_count_extra" ] && [ "$cfmgr_prereq_count" = "$((${#2} + 1))" ] || return 1
	{
		IFS= read -r cfmgr_prereq_line && [ "$cfmgr_prereq_line" = "$2" ] || return 1
		cfmgr_prereq_extra=''
		if IFS= read -r cfmgr_prereq_extra; then return 1; fi
		[ -z "$cfmgr_prereq_extra" ]
	} <"$1"
}

cfmgr_prerequisites_output() {
	cfmgr_prereq_original=$cfmgr_probe_stdout
	[ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_prerequisites_run "$1" "$cfmgr_prereq_context" "$cfmgr_prereq_shell" "$cfmgr_prereq_helper" "$cfmgr_prereq_env" "$cfmgr_prereq_awk" "$cfmgr_prereq_sleep" "$cfmgr_prereq_wc" "$cfmgr_prereq_wc" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_prerequisites_text "$cfmgr_prereq_original" "$2" "$cfmgr_probe_stdout"
}

# Convert an ordinary reaped probe failure into capability evidence, while
# attachment, clock, invalid supervision and unresolved ownership remain fatal.
cfmgr_prerequisites_probe_code() {
	case "$1" in
	0) return 0 ;;
	1)
		case "$cfmgr_probe_reason" in attachment | clock) return 2 ;; esac
		return 1
		;;
	3) return 3 ;;
	*) return 2 ;;
	esac
}

# One capability's finite probes. Failure stops this capability only after reap;
# callers collect other ordinary deficiencies, never continue a fatal failure.
cfmgr_prerequisites_capability() {
	case "$1" in
	jq) cfmgr_prereq_modes='jq-good jq-bad' ;;
	timeout) cfmgr_prereq_modes='timeout-exit timeout-expiry' ;;
	sha) cfmgr_prereq_modes='sha-bytes sha-good sha-bad' ;;
	*) return 2 ;;
	esac
	for cfmgr_prereq_mode in $cfmgr_prereq_modes; do
		if cfmgr_prerequisites_run "$cfmgr_prereq_mode" "$cfmgr_prereq_context" "$cfmgr_prereq_shell" "$cfmgr_prereq_helper" "$cfmgr_prereq_env" "$cfmgr_prereq_awk" "$cfmgr_prereq_sleep" "$cfmgr_prereq_wc" "$2"; then
			cfmgr_prereq_code=0
		else
			cfmgr_prereq_code=$?
		fi
		cfmgr_prerequisites_probe_code "$cfmgr_prereq_code" || return $?
		case "$cfmgr_prereq_mode:$cfmgr_probe_exit" in
		jq-good:0)
			if cfmgr_prerequisites_output wc-jq true; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
			cfmgr_prerequisites_probe_code "$cfmgr_prereq_code" || return $?
			;;
		jq-bad:0) return 1 ;;
		jq-bad:*)
			[ ! -s "$cfmgr_probe_stdout" ] && IFS= read -r cfmgr_prereq_line <"$cfmgr_probe_stderr" || return 1
			case "$cfmgr_prereq_line" in 'parse error:'* | 'jq: parse error:'*) ;; *) return 1 ;; esac
			;;
		timeout-exit:7 | timeout-expiry:124 | sha-good:0 | sha-bad:1) ;;
		sha-bytes:0)
			if cfmgr_prerequisites_output wc-sha 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  bytes'; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
			cfmgr_prerequisites_probe_code "$cfmgr_prereq_code" || return $?
			;;
		*) return 1 ;;
		esac
		case "$cfmgr_prereq_mode" in
		timeout-* | sha-good | sha-bad) [ ! -s "$cfmgr_probe_stdout" ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1 ;;
		esac
	done
}

# Exports cfmgr_prereq_* capability results for the admitted controller.
# shellcheck disable=SC2034
cfmgr_prerequisites_admit_selected() {
	case ${cfmgr_health_active:-0} in
	1) cfmgr_health_admit_entware "$1" ;;
	*) cfmgr_prerequisites_admit_tool "$1" ;;
	esac
}

cfmgr_prerequisites_check() {
	# SCOPE CONTEXT SH PROBE ENV AWK SLEEP WC NATIVE_FLOCK JQ TIMEOUT SHA
	# ENTWARE_FLOCK DIG NATIVE_DNS_PROOF; optional absent paths use '-'.
	# Native DNS proof is current caller-qualified SRV/A evidence, never a guess.
	# cfmgr_prereq_missing is an ordered fixed package list for later repair.
	# Partial inventory on a fatal return is not an authorization to repair.
	cfmgr_prereq_result=invalid cfmgr_prereq_missing=''
	cfmgr_prereq_jq=unknown cfmgr_prereq_timeout=unknown cfmgr_prereq_sha=unknown
	cfmgr_prereq_flock=unknown cfmgr_prereq_flock_provider=none
	cfmgr_prereq_dns=not-required cfmgr_prereq_dns_provider=none
	[ "$#" -eq 15 ] || return 2
	cfmgr_prereq_scope=$1 cfmgr_prereq_context=$2 cfmgr_prereq_shell=$3
	cfmgr_prereq_helper=$4 cfmgr_prereq_env=$5 cfmgr_prereq_awk=$6
	cfmgr_prereq_sleep=$7 cfmgr_prereq_wc=$8 cfmgr_prereq_native_flock=$9 cfmgr_prereq_jq_path=${10}
	shift 10
	cfmgr_prereq_timeout_path=$1 cfmgr_prereq_sha_path=$2
	cfmgr_prereq_entware_flock=$3 cfmgr_prereq_dig=$4 cfmgr_prereq_native_dns=$5
	case "$cfmgr_prereq_scope" in shared | tunnel) ;; *) return 2 ;; esac
	case "$cfmgr_prereq_native_dns" in unknown | srv-a-verified) ;; *) return 2 ;; esac
	case "$cfmgr_prereq_context" in /*) ;; *) return 2 ;; esac
	[ -d "$cfmgr_prereq_context" ] || return 2
	case ${cfmgr_health_active:-0} in
	1) cfmgr_status_attachment_ok && cfmgr_health_entware_attachment || return $? ;;
	*) cfmgr_prerequisites_attachment_ok || return 2 ;;
	esac
	cfmgr_prerequisites_supervisor || return 2
	case ${cfmgr_health_active:-0} in 1)
		for cfmgr_health_scratch in json.good json.bad bytes checksum.good checksum.bad lock timeout.child; do
			cfmgr_health_stage_reserve "$cfmgr_health_scratch" 8192 || return $?
		done
		;;
	esac
	(
		umask 077
		set -C
		printf '%s\n' '{"answer":[1,2],"ok":true}' >"$cfmgr_prereq_context/json.good" &&
			printf '%s\n' '{broken' >"$cfmgr_prereq_context/json.bad" &&
			printf abc >"$cfmgr_prereq_context/bytes" &&
			printf '%s\n' 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  bytes' >"$cfmgr_prereq_context/checksum.good" &&
			printf '%s\n' 'aa7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  bytes' >"$cfmgr_prereq_context/checksum.bad"
	) || return 2
	cfmgr_prereq_result=checking-capabilities
	for cfmgr_prereq_capability in jq timeout sha; do
		case "$cfmgr_prereq_capability" in
		jq) cfmgr_prereq_tool=$cfmgr_prereq_jq_path cfmgr_prereq_package=jq ;;
		timeout) cfmgr_prereq_tool=$cfmgr_prereq_timeout_path cfmgr_prereq_package=coreutils-timeout ;;
		sha) cfmgr_prereq_tool=$cfmgr_prereq_sha_path cfmgr_prereq_package=coreutils-sha256sum ;;
		esac
		if [ "$cfmgr_prereq_tool" = - ]; then
			cfmgr_prereq_code=1
		elif cfmgr_prerequisites_admit_selected "$cfmgr_prereq_tool"; then
			if cfmgr_prerequisites_capability "$cfmgr_prereq_capability" "$cfmgr_prereq_tool"; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
		else
			cfmgr_prereq_code=$?
		fi
		case "$cfmgr_prereq_code" in 0) cfmgr_prereq_state=usable ;; 1) cfmgr_prereq_state=unusable ;; 3) return 3 ;; *) return 2 ;; esac
		case "$cfmgr_prereq_capability" in jq) cfmgr_prereq_jq=$cfmgr_prereq_state ;; timeout) cfmgr_prereq_timeout=$cfmgr_prereq_state ;; sha) cfmgr_prereq_sha=$cfmgr_prereq_state ;; esac
		[ "$cfmgr_prereq_code" -eq 0 ] || cfmgr_prereq_missing="${cfmgr_prereq_missing:+$cfmgr_prereq_missing }$cfmgr_prereq_package"
	done
	# Separate open descriptions prove contention. Parent-held descriptors retain
	# locks after the short flock executable exits; no background holder is needed.
	if (: <&4) 2>/dev/null || (: <&5) 2>/dev/null; then return 2; fi
	(
		umask 077
		set -C
		: >"$cfmgr_prereq_context/lock"
	) || return 2
	exec 4<>"$cfmgr_prereq_context/lock" 5<>"$cfmgr_prereq_context/lock"
	cfmgr_prereq_flock=unusable
	for cfmgr_prereq_candidate in native entware; do
		case "$cfmgr_prereq_candidate" in native) cfmgr_prereq_tool=$cfmgr_prereq_native_flock ;; entware) cfmgr_prereq_tool=$cfmgr_prereq_entware_flock ;; esac
		[ "$cfmgr_prereq_tool" != - ] || continue
		if [ "$cfmgr_prereq_candidate" = entware ]; then
			if cfmgr_prerequisites_admit_selected "$cfmgr_prereq_tool"; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
			case "$cfmgr_prereq_code" in
			0) ;;
			1) continue ;;
			*)
				exec 4>&- 5>&-
				[ "$cfmgr_prereq_code" -ne 3 ] || return 3
				return 2
				;;
			esac
		fi
		cfmgr_prereq_flock=usable
		for cfmgr_prereq_mode in flock-first flock-compete flock-release flock-after flock-finish; do
			cfmgr_prereq_run_mode=$cfmgr_prereq_mode
			[ "$cfmgr_prereq_candidate" != entware ] || cfmgr_prereq_run_mode=flock-entware-${cfmgr_prereq_mode#flock-}
			if cfmgr_prerequisites_run "$cfmgr_prereq_run_mode" "$cfmgr_prereq_context" "$cfmgr_prereq_shell" "$cfmgr_prereq_helper" "$cfmgr_prereq_env" "$cfmgr_prereq_awk" "$cfmgr_prereq_sleep" "$cfmgr_prereq_wc" "$cfmgr_prereq_tool"; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
			if cfmgr_prerequisites_probe_code "$cfmgr_prereq_code"; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
			case "$cfmgr_prereq_code" in
			0) ;;
			1)
				cfmgr_prereq_flock=unusable
				break
				;;
			*)
				exec 4>&- 5>&-
				return "$cfmgr_prereq_code"
				;;
			esac
			case "$cfmgr_prereq_mode:$cfmgr_probe_exit" in flock-compete:1 | flock-first:0 | flock-release:0 | flock-after:0 | flock-finish:0) ;; *)
				cfmgr_prereq_flock=unusable
				break
				;;
			esac
			if [ -s "$cfmgr_probe_stdout" ] || [ -s "$cfmgr_probe_stderr" ]; then
				cfmgr_prereq_flock=unusable
				break
			fi
		done
		if [ "$cfmgr_prereq_flock" = usable ]; then
			cfmgr_prereq_flock_provider=$cfmgr_prereq_candidate
			break
		fi
		# Release descriptors before considering a different implementation.
		exec 4>&- 5>&-
		exec 4<>"$cfmgr_prereq_context/lock" 5<>"$cfmgr_prereq_context/lock"
	done
	exec 4>&- 5>&-
	[ "$cfmgr_prereq_flock" = usable ] || cfmgr_prereq_missing="${cfmgr_prereq_missing:+$cfmgr_prereq_missing }flock"
	if [ "$cfmgr_prereq_scope" = tunnel ]; then
		if [ "$cfmgr_prereq_native_dns" = srv-a-verified ]; then
			cfmgr_prereq_dns=native-srv-a-qualified cfmgr_prereq_dns_provider=native
		else
			cfmgr_prereq_dns=unusable
			if [ "$cfmgr_prereq_dig" = - ]; then
				cfmgr_prereq_code=1
			elif cfmgr_prerequisites_admit_selected "$cfmgr_prereq_dig"; then
				if cfmgr_prerequisites_run dig-version "$cfmgr_prereq_context" "$cfmgr_prereq_shell" "$cfmgr_prereq_helper" "$cfmgr_prereq_env" "$cfmgr_prereq_awk" "$cfmgr_prereq_sleep" "$cfmgr_prereq_wc" "$cfmgr_prereq_dig"; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
				if cfmgr_prerequisites_probe_code "$cfmgr_prereq_code"; then
					if [ "$cfmgr_probe_exit" -eq 0 ] && [ -s "$cfmgr_probe_stdout" ] && [ ! -s "$cfmgr_probe_stderr" ]; then cfmgr_prereq_code=0; else cfmgr_prereq_code=1; fi
				else cfmgr_prereq_code=$?; fi
			else cfmgr_prereq_code=$?; fi
			case "$cfmgr_prereq_code" in
			0)
				# Executability only; the tunnel consumer must prove live SRV/A queries.
				cfmgr_prereq_dns=dig-executable cfmgr_prereq_dns_provider=entware
				;;
			1) cfmgr_prereq_missing="${cfmgr_prereq_missing:+$cfmgr_prereq_missing }bind-dig" ;;
			3) return 3 ;;
			*) return 2 ;;
			esac
		fi
	fi
	cfmgr_prereq_result=capabilities-checked
	[ -z "$cfmgr_prereq_missing" ]
}

# Pinned ash resets background FD0 before command redirects; 0<&0 is a no-op.
# Invocation-scoped 9<&0 preserves the lock across that fork. This tiny function
# performs no attachment checks while parent9 aliases the lock; return restores
# its support pin before supervision. Child9 closes after duplication to0, and
# no probe mode consumes9. Independent contention still admits lock semantics.
_cfmgr_prerequisites_start_locked() {
	(_cfmgr_prerequisites_exec "$@") 0<&9 9<&- >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr" &
	cfmgr_probe_pid=$!
}

_cfmgr_prerequisites_exec() {
	# Clear loader/config input before even execing the env utility. env-i
	# sanitizes its child, but cannot protect env own dynamic-loader startup.
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE \
		LD_ORIGIN_PATH LD_ASSUME_KERNEL LD_BIND_NOW LD_TRACE_LOADED_OBJECTS \
		DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH \
		DYLD_FALLBACK_LIBRARY_PATH DYLD_FALLBACK_FRAMEWORK_PATH \
		OPENSSL_CONF OPENSSL_MODULES OPENSSL_ENGINES CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR
	case "$cfmgr_probe_mode" in
	health-*)
		set +x
		set +v
		ulimit -c 0 || exit 2
		exec 3>&-
		cfmgr_health_mode "$cfmgr_probe_mode" || exit 2
		ulimit -f "$cfmgr_health_mode_limit" || exit 2
		;;
	history-*)
		cfmgr_archive_uint "${cfmgr_history_probe_limit:-}" || exit 2
		cfmgr_history_child_limit=$cfmgr_history_probe_limit
		if [ "$cfmgr_probe_mode" = history-append ]; then cfmgr_history_child_limit=${14}; fi
		ulimit -f "$(((cfmgr_history_child_limit + 511) / 512))" || exit 2
		;;
	store-archive-plan) ulimit -f 1040 || exit 2 ;;
	archive-*)
		# Native ash uses 512-byte blocks. Post-run WC enforces exact bytes on
		# host shells whose ulimit units differ. Never inherit the probe quota.
		# Browsing deliberately caps a single gunzip prefix. No core containing
		# private archive bytes may be left when that writer reaches SIGXFSZ.
		case $cfmgr_probe_mode in archive-gunzip) ulimit -c 0 || exit 2 ;; esac
		cfmgr_archive_uint "${cfmgr_archive_limit:-}" || exit 2
		ulimit -f "$(((cfmgr_archive_limit + 511) / 512))" || exit 2
		;;
	acquire-api | acquire-raw)
		# Native ash uses 512-byte file-limit blocks; host bash may use1024.
		# Exact native WC validation also enforces the declared byte boundary.
		case ${14} in '' | *[!0-9]*) exit 2 ;; esac
		[ "${14}" -gt 0 ] && [ "${14}" -le 1048576 ] || exit 2
		ulimit -f "$(((${14} + 511) / 512))" || exit 2
		;;
	repair-*) ulimit -f 8192 || exit 2 ;;
	acquire-extract) ulimit -f 192 || exit 2 ;;
	acquire-manifest) ulimit -f 512 || exit 2 ;;
	status-snapshot | store-snapshot | store-settings | store-copy | store-backup-config | store-archive-config | store-backup-mounts | store-backup-mount) ulimit -f 128 || exit 2 ;;
	install-copy | launch-copy) ulimit -f 2048 || exit 2 ;;
	status-render) ulimit -f 64 || exit 2 ;;
	launch-config-patch) ulimit -f 128 || exit 2 ;;
	*) ulimit -f 8 || exit 2 ;;
	esac
	case "$cfmgr_probe_mode" in
	install-* | native-* | repair-* | launch-* | status-* | health-* | store-* | acquire-* | archive-* | history-*)
		shift 9
		exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" "$@"
		;;
	timeout-exit) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" "$cfmgr_probe_shell" "$cfmgr_probe_helper" ;;
	timeout-expiry) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_sleep" ;;
	blkid) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" blkid "$cfmgr_probe_tool" "$cfmgr_probe_context" "${10}" ;;
	*) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" ;;
	esac
}

# ---- dependencies ----
# Source-inert normal installed-opkg repair controller. Shared selection/claim
# policy is separate from root/task supervision. No dependency environment input.
# shellcheck disable=SC2034,SC2154 # Explicit imported/exported controller fields.
# Trusted caller supplies native operation/admission/context cleanup callbacks.

# Strict finite missing inventory: complete ordinary prerequisite failure only.
cfmgr_dependencies_inventory() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 128 ] || return 2
	# Reject caller control/glob syntax before field splitting. The subshell
	# fixes splitting without changing the controller's flags or IFS.
	case $1 in *[!a-z0-9\ -]*) return 2 ;; esac
	(
		set -f
		IFS=' '
		cfmgr_dependencies_seen=' '
		for cfmgr_dependencies_package in $1; do
			case $cfmgr_dependencies_package in jq | coreutils-timeout | coreutils-sha256sum | flock | bind-dig) ;; *) exit 2 ;; esac
			case $cfmgr_dependencies_seen in *" $cfmgr_dependencies_package "*) exit 2 ;; esac
			cfmgr_dependencies_seen="$cfmgr_dependencies_seen$cfmgr_dependencies_package "
		done
	) || return 2
	cfmgr_dependencies_missing=$1
}

# Parse fixed opkg status records from the bounded in-view query receipt. Never
# change a provider on an ambiguous/incomplete status database observation.
# shellcheck disable=SC2016
cfmgr_dependencies_select() {
	[ "$#" -eq 4 ] || return 2
	cfmgr_dependencies_inventory "$2" || return 2
	cfmgr_dependencies_query_bytes=$("$4" -c <"$3") || return 1
	case $cfmgr_dependencies_query_bytes in '' | *[!0-9\ ]*) return 1 ;; esac
	[ "$cfmgr_dependencies_query_bytes" -le 65536 ] || return 1
	"$1" -v expected="$cfmgr_dependencies_query_bytes" -v missing="$2" '
		function known(p) { return p ~ /^(jq|jq-full|coreutils-timeout|coreutils-sha256sum|flock|bind-dig)$/ }
		function finish() {
		  if (package=="") return
		  if (seen[package]++ || status=="" || version=="") bad=1
		  if (split(status,parts," ")!=3 || parts[1] !~ /^(unknown|install|deinstall|purge)$/ ||
		    parts[3] !~ /^(not-installed|config-files|installed|unpacked|half-configured|half-installed|post-inst-failed|removal-failed)$/) bad=1
		  for (key in flags_seen) delete flags_seen[key]
		  flags_count=split(parts[2],flags,",")
		  for (f=1;f<=flags_count;f++) if (flags_seen[flags[f]]++ || flags[f] !~ /^(ok|reinstreq|hold|replace|noprune|prefer|obsolete|user)$/ || (flags[f]=="ok" && flags_count!=1)) bad=1
		  if (parts[3]!="not-installed" && parts[3]!="config-files") installed[package]=1
		  package=status=version=""
		}
		{ bytes+=length($0)+1 }
		length($0)>4096 || NR>512 || $0 ~ /[^ -~\t]/ { bad=1 }
		$0=="ready END" { if (NR!=1 || ready++ || ended) bad=1; next }
		$1=="status" && $3=="BEGIN" { if (NF!=3 || !ready || ended || inside || !known($2) || queries[$2]++) bad=1; query=$2; records=0; metadata=0; begun++; inside=1; next }
		$1=="status" && $4=="END" { finish(); if (NF!=4 || !inside || $2!=query || $3!="0" || ended) bad=1; inside=0; next }
		$0 ~ /^queried [0-9]+ END$/ { finish(); if (NF!=3 || inside || $2!="0" || ended++) bad=1; next }
		!inside { bad=1; next }
		/^Package: / { finish(); if (records++) bad=1; package=substr($0,10)
		  if (package!=query) bad=1
		  if (package!="jq" && package!="jq-full" && package!="coreutils-timeout" && package!="coreutils-sha256sum" && package!="flock" && package!="bind-dig") bad=1; next }
		/^Status: / { if (status!="" || package=="") bad=1; status=substr($0,9); metadata=0; next }
		/^Version: / { if (version!="" || package=="") bad=1; version=substr($0,10); metadata=0; next }
		$0=="" { finish(); next }
		/^(Package|Status|Version):/ { bad=1; next }
		$0 ~ /^[A-Za-z0-9-]+:( |$)/ { metadata=1; next }
		/^ / { if (!metadata) bad=1; next }
		{ bad=1 }
		END { if (bytes!=expected || inside || begun!=6 || ended!=1 || bad || (installed["jq"] && installed["jq-full"])) exit 1
		  count=split(missing,items," "); output=""
		  for (i=1;i<=count;i++) { p=items[i]; if (p=="jq" && installed["jq-full"]) p="jq-full"
		    output=output (output=="" ? "" : " ") (installed[p] ? "r-" : "i-") p }
		  print output }
	' "$3"
}

# Claim receipt carries only kernel-derived owner identity, never mutable config.
_cfmgr_dependencies_owner_active() {
	cfmgr_dependencies_claim_admit "$cfmgr_dependencies_context" || return 3
	cfmgr_dependencies_owner_pid='' cfmgr_dependencies_owner_start='' cfmgr_dependencies_owner_boot='' cfmgr_dependencies_extra=''
	if [ ! -f "$cfmgr_dependencies_context/owner" ]; then
		# Exclusive mkdir can precede the owner receipt. Wait without adoption.
		return 0
	fi
	[ ! -L "$cfmgr_dependencies_context/owner" ] || return 3
	cfmgr_dependencies_owner_bytes=$("$cfmgr_dependencies_wc" -c <"$cfmgr_dependencies_context/owner") || return 3
	case $cfmgr_dependencies_owner_bytes in '' | *[!0-9\ ]*) return 3 ;; esac
	[ "$cfmgr_dependencies_owner_bytes" -le 96 ] || return 3
	cfmgr_dependencies_owner_line='' cfmgr_dependencies_owner_tail=''
	{
		IFS= read -r cfmgr_dependencies_owner_line || return 3
		if IFS= read -r cfmgr_dependencies_owner_tail; then return 3; fi
		[ -z "$cfmgr_dependencies_owner_tail" ] || return 3
	} <"$cfmgr_dependencies_context/owner" || return 3
	[ "$cfmgr_dependencies_owner_bytes" -eq "$((${#cfmgr_dependencies_owner_line} + 1))" ] || return 3
	IFS=' ' read -r cfmgr_dependencies_owner_pid cfmgr_dependencies_owner_start cfmgr_dependencies_owner_boot cfmgr_dependencies_extra <<EOF_OWNER
$cfmgr_dependencies_owner_line
EOF_OWNER
	[ -z "$cfmgr_dependencies_extra" ] || return 3
	case $cfmgr_dependencies_owner_pid:$cfmgr_dependencies_owner_start in *[!0-9:]* | :* | *: | 0* | *:0*) return 3 ;; esac
	[ "${#cfmgr_dependencies_owner_pid}" -le 10 ] && [ "${#cfmgr_dependencies_owner_start}" -le 20 ] || return 3
	[ "$cfmgr_dependencies_owner_line" = "$cfmgr_dependencies_owner_pid $cfmgr_dependencies_owner_start $cfmgr_dependencies_owner_boot" ] || return 3
	IFS= read -r cfmgr_dependencies_current_boot </proc/sys/kernel/random/boot_id || return 3
	[ "$cfmgr_dependencies_owner_boot" = "$cfmgr_dependencies_current_boot" ] || return 3
	cfmgr_prerequisites_identity "$cfmgr_dependencies_owner_pid" || return 3
	[ "$cfmgr_identity_start" = "$cfmgr_dependencies_owner_start" ] && [ "$cfmgr_identity_state" != Z ] || return 3
}

_cfmgr_dependencies_wait() {
	_cfmgr_tasks_now || return 3
	cfmgr_dependencies_wait_deadline=$((cfmgr_tasks_now + 120))
	while [ -e "$cfmgr_dependencies_context" ] || [ -L "$cfmgr_dependencies_context" ]; do
		if _cfmgr_dependencies_owner_active; then
			:
		else
			# Successful cleanup can remove the claim during any observation.
			# Only complete disappearance permits the caller's fresh post-probes;
			# an unreadable, stale or replaced claim still present stays unresolved.
			[ ! -e "$cfmgr_dependencies_context" ] && [ ! -L "$cfmgr_dependencies_context" ] || return 3
			break
		fi
		_cfmgr_tasks_now || return 3
		[ "$cfmgr_tasks_now" -lt "$cfmgr_dependencies_wait_deadline" ] || return 3
		[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
		"$cfmgr_dependencies_usleep" 50000 || return 3
	done
	cfmgr_dependencies_result=coalesced
}

# MISSING SHARED_PARENT SOURCE NATIVE_ROOT SH ENV AWK READLINK USLEEP WC MKNOD CHROOT
# Empty inventory is an inert no-op unless an existing shared worker needs waiting.
# Only the exclusive claimant creates a view/launches installed opkg. Waiters
# return once for fresh caller probes, never re-launch within this invocation.
cfmgr_dependencies_repair() {
	[ "$#" -eq 12 ] || return 2
	case ${cfmgr_dependencies_state:-none} in retained) return 3 ;; esac
	cfmgr_dependencies_inventory "$1" || return 2
	cfmgr_dependencies_parent=$2 cfmgr_dependencies_source=$3 cfmgr_dependencies_native_root=$4
	cfmgr_dependencies_shell=$5 cfmgr_dependencies_env=$6 cfmgr_dependencies_awk=$7 cfmgr_dependencies_readlink=$8 cfmgr_dependencies_usleep=$9
	shift 9
	cfmgr_dependencies_wc=$1 cfmgr_dependencies_mknod=$2 cfmgr_dependencies_chroot=$3
	cfmgr_dependencies_context=$cfmgr_dependencies_parent/dependencies
	cfmgr_dependencies_result=invalid cfmgr_dependencies_loss=0 cfmgr_dependencies_reason=admission cfmgr_dependencies_failure=none cfmgr_dependencies_worker_failed=0
	cfmgr_dependencies_claimed=0 cfmgr_dependencies_snapshot_ready=0 cfmgr_dependencies_cleaning=0 cfmgr_dependencies_native_unresolved=0
	if [ -e "$cfmgr_dependencies_context" ] || [ -L "$cfmgr_dependencies_context" ]; then
		_cfmgr_dependencies_wait
		return $?
	fi
	[ -n "$cfmgr_dependencies_missing" ] || {
		cfmgr_dependencies_result=healthy
		return 0
	}
	_cfmgr_tasks_now || return 3
	cfmgr_dependencies_operation_deadline=$((cfmgr_tasks_now + 120))
	cfmgr_keeper_outer_deadline=$cfmgr_dependencies_operation_deadline
	if cfmgr_dependencies_admit; then :; else
		cfmgr_dependencies_code=$?
		if [ "$cfmgr_dependencies_code" -eq 3 ]; then
			cfmgr_dependencies_native_unresolved=1 cfmgr_dependencies_state=retained
			cfmgr_dependencies_native_pid=$cfmgr_probe_pid cfmgr_dependencies_native_start=$cfmgr_probe_start cfmgr_dependencies_native_boot=$cfmgr_probe_boot
		fi
		return "$cfmgr_dependencies_code"
	fi
	cfmgr_dependencies_snapshot_ready=0
	cfmgr_dependencies_native copy "$cfmgr_dependencies_source/modules/helpers/worker.sh" "$cfmgr_install_context/repair-worker.sh" || return 3
	cfmgr_dependencies_native chmod "$cfmgr_install_context/repair-worker.sh" 700 || return 3
	cfmgr_dependencies_native copy "$cfmgr_dependencies_source/modules/lib/storage.sh" "$cfmgr_install_context/repair-storage.sh" || return 3
	cfmgr_dependencies_snapshot_ready=1
	if cfmgr_dependencies_native mkdir "$cfmgr_dependencies_context" 700; then :; else
		cfmgr_dependencies_code=$?
		[ "$cfmgr_dependencies_code" -ne 3 ] || return 3
		if [ -d "$cfmgr_dependencies_context" ]; then
			_cfmgr_dependencies_wait
			return $?
		fi
		return "$cfmgr_dependencies_code"
	fi
	cfmgr_dependencies_state=retained cfmgr_dependencies_phase=preparing
	cfmgr_dependencies_claim_admit "$cfmgr_dependencies_context" || return 3
	exec 5<"$cfmgr_dependencies_context" || return 3
	cfmgr_dependencies_claimed=1
	cfmgr_prerequisites_identity "$$" || return 3
	cfmgr_dependencies_owner_start=$cfmgr_identity_start
	IFS= read -r cfmgr_dependencies_owner_boot </proc/sys/kernel/random/boot_id || return 3
	(
		umask 077
		set -C
		printf '%s %s %s\n' "$$" "$cfmgr_dependencies_owner_start" "$cfmgr_dependencies_owner_boot" >"$cfmgr_dependencies_context/owner"
	) || return 3
	# Snapshot all cleanup code while source and storage are still attached.

	for cfmgr_dependencies_code_file in modules/helpers/worker.sh modules/lib/execution.sh modules/lib/storage.sh; do
		cfmgr_dependencies_native copy "$cfmgr_dependencies_source/$cfmgr_dependencies_code_file" "$cfmgr_dependencies_context/${cfmgr_dependencies_code_file##*/}" || {
			_cfmgr_dependencies_early_cleanup "$?"
			return $?
		}
	done
	cfmgr_dependencies_native chmod "$cfmgr_dependencies_context/worker.sh" 700 || {
		_cfmgr_dependencies_early_cleanup "$?"
		return $?
	}
	cfmgr_tasks_context=$cfmgr_dependencies_context cfmgr_tasks_awk=$cfmgr_dependencies_awk cfmgr_tasks_readlink=$cfmgr_dependencies_readlink cfmgr_tasks_usleep=$cfmgr_dependencies_usleep
	cfmgr_tasks_parser=$cfmgr_dependencies_context/storage.sh cfmgr_tasks_state=quiescent
	(
		umask 077
		set -C
		: >"$cfmgr_dependencies_context/foreign.ids"
	) || return 3
	cfmgr_dependencies_phase=construction
	if cfmgr_execution_view_create "$cfmgr_dependencies_native_root" "$cfmgr_dependencies_context" "$cfmgr_dependencies_awk" "$cfmgr_dependencies_readlink" "$cfmgr_dependencies_context/storage.sh"; then
		cfmgr_dependencies_phase=launch
		cfmgr_dependencies_inside_tools || return 3
		if cfmgr_execution_tasks_start "$cfmgr_dependencies_context" "$cfmgr_dependencies_env" "$cfmgr_dependencies_chroot" "$cfmgr_dependencies_shell" "$cfmgr_dependencies_context/worker.sh" \
			"$cfmgr_dependencies_awk" "$cfmgr_dependencies_readlink" "$cfmgr_dependencies_usleep" "$cfmgr_dependencies_inside_shell" "$cfmgr_dependencies_inside_awk" "$cfmgr_dependencies_inside_readlink" "$cfmgr_dependencies_inside_usleep"; then
			if cfmgr_dependencies_select "$cfmgr_dependencies_awk" "$cfmgr_dependencies_missing" "$cfmgr_dependencies_context/receipt" "$cfmgr_dependencies_wc" >"$cfmgr_dependencies_context/selection"; then
				IFS= read -r cfmgr_dependencies_selection <"$cfmgr_dependencies_context/selection" || return 3
				cfmgr_dependencies_phase=repair
				cfmgr_dependencies_code=0
				if type cfmgr_dependencies_before_repair >/dev/null 2>&1; then
					if cfmgr_dependencies_before_repair; then :; else cfmgr_dependencies_code=$?; fi
				fi
				if [ "$cfmgr_dependencies_code" -eq 3 ]; then
					# The native recheck's unresolved child must retain every guard;
					# do not issue a worker request or begin further cleanup probes.
					cfmgr_dependencies_native_unresolved=1
					return 3
				fi
				if [ "$cfmgr_dependencies_code" -eq 0 ]; then
					if cfmgr_execution_tasks_run "$cfmgr_dependencies_selection"; then cfmgr_dependencies_code=0; else
						cfmgr_dependencies_code=$?
						[ "$cfmgr_dependencies_code" -ne 1 ] || cfmgr_dependencies_worker_failed=1
					fi
				fi
			else cfmgr_dependencies_code=1; fi
		else cfmgr_dependencies_code=$?; fi
	else cfmgr_dependencies_code=$?; fi
	case ${cfmgr_tasks_state:-none} in running | retained)
		if cfmgr_execution_tasks_finish; then :; else
			cfmgr_dependencies_reason=cleanup-pending
			cfmgr_dependencies_report cleanup-pending || :
			return 3
		fi
		;;
	esac
	# A view/sweep refusal can bypass the task runner's normal final storage
	# observation. Recheck only after owned work is resolved, before releasing
	# protection; unresolved native children retain every guard without probes.
	[ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ] || return 3
	if ! cfmgr_storage_attached; then
		cfmgr_tasks_loss=1
		cfmgr_execution_tasks_event storage-lost || return 3
	fi
	cfmgr_dependencies_phase=cleanup
	_cfmgr_tasks_now || return 3
	cfmgr_dependencies_operation_deadline=$((cfmgr_tasks_now + 60))
	cfmgr_keeper_outer_deadline=$cfmgr_dependencies_operation_deadline
	if cfmgr_execution_view_release; then :; else return 3; fi
	if [ "$cfmgr_dependencies_loss" = 1 ]; then
		if cfmgr_dependencies_report cleanup-complete; then :; else
			[ "$?" -ne 3 ] || return 3
		fi
		cfmgr_dependencies_code=1
	fi
	# Only a complete ordinary worker failure receipt qualifies as DNS-only
	# opkg failure. Refusal, loss, interruption and unknown ownership never do.
	if [ "$cfmgr_dependencies_worker_failed" = 1 ] && [ "${cfmgr_install_dependency_action:-normal}" = normal ] &&
		[ "${cfmgr_tasks_state:-none}:${cfmgr_tasks_exit:-0}:${cfmgr_tasks_survivors:-1}" = quiescent:1:0 ] &&
		[ "${cfmgr_install_interrupted:-0}:${cfmgr_tasks_action_refused:-1}:${cfmgr_tasks_loss:-1}:$cfmgr_dependencies_loss" = 0:0:0:0 ]; then
		# shellcheck disable=SC2016 # Fixed awk program reads the bounded worker receipt.
		if "$cfmgr_dependencies_awk" '
		  length($0)>4096 || NR>512 { bad=1; exit 1 }
		  /^failed (update|install) [1-9][0-9]* END$/ { n++; terminal=NR }
		  END { exit bad || n!=1 || terminal!=NR ? 1 : 0 }
		' "$cfmgr_dependencies_context/receipt"; then cfmgr_dependencies_failure=opkg; fi
	fi
	cfmgr_dependencies_cleanup || return 3
	# A resolved full cleanup retires transient ownership uncertainty for retry.
	if [ "$cfmgr_dependencies_code" -eq 3 ]; then cfmgr_dependencies_code=1; fi
	exec 5<&-
	cfmgr_dependencies_claimed=0 cfmgr_dependencies_state=complete
	cfmgr_dependencies_operation_deadline='' cfmgr_keeper_outer_deadline=''
	if [ "$cfmgr_dependencies_code" -eq 0 ]; then cfmgr_dependencies_result=repaired; else cfmgr_dependencies_result=failed; fi
	return "$cfmgr_dependencies_code"
}

_cfmgr_dependencies_early_cleanup() {
	cfmgr_dependencies_code=$1
	[ "$cfmgr_dependencies_code" -ne 3 ] && [ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ] || return 3
	cfmgr_dependencies_cleanup || return 3
	exec 5<&-
	cfmgr_dependencies_claimed=0 cfmgr_dependencies_state=complete cfmgr_dependencies_result=failed
	return "$cfmgr_dependencies_code"
}

cfmgr_execution_view_quiescent() {
	case ${1:-active} in
	active) cfmgr_execution_tasks_quiescent ;;
	retired) [ "$cfmgr_tasks_state:$cfmgr_view_pin_state" = quiescent:retired ] ;;
	*) return 2 ;;
	esac
}
cfmgr_execution_view_keeper() {
	case $1 in
	start)
		cfmgr_dependencies_native mkdir "$2/keeper" 700 || return $?
		cfmgr_mount_keeper_start "$2/keeper" "$cfmgr_dependencies_shell" "$2/worker.sh" "$2/execution.sh" \
			"$cfmgr_dependencies_env" "$cfmgr_dependencies_mknod" "$cfmgr_dependencies_awk" "$cfmgr_dependencies_usleep"
		;;
	retain) cfmgr_mount_keeper_retain "$2" ;;
	check) cfmgr_mount_keeper_check "$2" "$3" ;;
	release) cfmgr_mount_keeper_release ;;
	*) return 2 ;;
	esac
}
cfmgr_mount_keeper_native() {
	[ "$1" = fifo ] || return 2
	cfmgr_dependencies_native fifo "$3"
}
cfmgr_execution_view_native() { cfmgr_dependencies_native "$@"; }
cfmgr_execution_tasks_native() { cfmgr_dependencies_native "$@"; }

cfmgr_execution_tasks_event() {
	[ "$#" -eq 1 ] && [ "$1" = storage-lost ] || return 2
	cfmgr_dependencies_reason=storage-lost
	[ "${cfmgr_dependencies_loss:-0}" = 0 ] || return 0
	cfmgr_dependencies_loss=1
	if cfmgr_dependencies_report storage-lost; then return 0; else
		cfmgr_dependencies_report_code=$?
		[ "$cfmgr_dependencies_report_code" -ne 3 ] || return 3
		return 0
	fi
}

# ---- execution view ----
# Source-inert guarded execution-view foundation; no package launch/supervisor.
# The controller admits a fresh private RAM context, native tools and storage
# (UUID plus held FD6/7). It supplies the fixed trusted callbacks below:
# cfmgr_execution_view_native MODE OPERANDS: bounded/reaped native operation;
# 0 success, 1 ordinary failure, 2 invalid, 3 unresolved child/operation.
# Modes: inventory, list, identity, readlink, mkdir, file, link, chmod, copy,
# root, guard-root, bind4, bind7, private, unbindable, seal, unmount, awk.
# Required cfmgr_execution_view_keeper: start CONTEXT; check ADDITION LEDGER;
# retain ID (borrowed FD4); release. It uses admitted mount_keeper tools/code.
# FD3 is reserved FIFO control until keeper release/reap. No keeper FD may reach
# a future package process. cfmgr_view_pin_state=retired forbids using ledger IDs
# for later task signalling; it permits only rechecked normal mount cleanup.
# Observation output files are fixed private-context operands. `awk` invokes
# cfmgr_execution_view_awk with its finite mode, never arbitrary program text.
# cfmgr_execution_view_quiescent: independently qualified task/root quiescence;
# a successful package exit or a boolean attachment mock is not that proof.
# FD4 is construction scratch and must initially be closed. FD0/5/6/7/8/9
# remain caller-owned. Never release storage pins while an unresolved view lives.
# Return 1 retains a reviewable ordinary failure; 2 invalid admission; 3 retains
# uncertain operations. Only successful create sets ready; release is retryable.

_cfmgr_view_call() {
	if cfmgr_execution_view_native "$@"; then return 0; else
		cfmgr_view_code=$?
		case $cfmgr_view_code in
		1 | 2) return "$cfmgr_view_code" ;;
		*)
			cfmgr_view_pending=native-unresolved
			return 3
			;;
		esac
	fi
}

_cfmgr_view_keeper() {
	if cfmgr_execution_view_keeper "$@"; then return 0; else
		cfmgr_view_keeper_code=$?
		if [ "$cfmgr_view_keeper_code" -eq 1 ]; then return 1; fi
		cfmgr_view_pending=keeper-unresolved
		return 3
	fi
}

_cfmgr_view_pin() {
	# Called with the actual newly observed target borrowed on FD4. Parent source
	# FD4 is saved/restored by function-call redirection, never globally replaced.
	_cfmgr_view_call awk top "$1" "$2" "$cfmgr_view_context/pin.id" || return 3
	IFS= read -r cfmgr_view_pin_id <"$cfmgr_view_context/pin.id" || return 3
	_cfmgr_view_keeper retain "$cfmgr_view_pin_id"
}

# Fixed bounded data transformations for the trusted native callback.
# Inputs originate in the validated mount parser/private ledger, never shell code.
# shellcheck disable=SC2016
cfmgr_execution_view_awk() {
	case $1 in
	source)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { context=ARGV[1]; ARGV[1]="" }
			$5==context || index($5,context "/")==1 { next }
			{ if (NF!=10 || ++n>256 || seen[$5]++) { bad=1; exit 1 }; rows[n]=$0 }
			END { if (bad || n>256) exit 1; for (i=1;i<=n;i++) print rows[i] }
		' "$cfmgr_view_context" "$1" >"$2"
		;;
	order)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { root=ARGV[1]; ARGV[1]=""; prefix=root=="/" ? "/" : root "/" }
			{ relative=substr($5,length(prefix)+1)
			  if ($5==root || index(relative,"/")==0) next
			  depth=split(relative,a,"/"); n++; row[n]=$0; d[n]=depth }
			END { for (i=2;i<=n;i++) { r=row[i]; depth=d[i]; j=i-1
			  while (j>0 && d[j]>depth) { row[j+1]=row[j]; d[j+1]=d[j]; j-- }
			  row[j+1]=r; d[j+1]=depth }
			  for (i=1;i<=n;i++) print row[i] }
		' "$cfmgr_view_native_root" "$1" >"$2"
		;;
	change)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { mode=ARGV[1]; point=ARGV[2]; remove=ARGV[3]; ARGV[1]=ARGV[2]=ARGV[3]="" }
			FILENAME==ARGV[4] { old[$1]=$0; oldpoint[$1]=$5; count++; next }
			{ current[$1]=$0
			  if (!($1 in old)) { added++; if ($5!=point) bad=1 }
			  else if (old[$1]!=$0) {
			    changed++; split(old[$1],a,"\t")
			    if ($5!=point || (mode!="private" && mode!="unbindable" && mode!="seal")) bad=1
			    for (i=1;i<=7;i++) if ($i!=a[i]) bad=1
			    if (mode=="seal") { if ($10!=a[10] || $8 !~ /(^|,)ro(,|$)/) bad=1 }
			    else { if ($8!=a[8] || $9!=a[9] || $10!=mode) bad=1 }
			  }
			}
			END { for (id in old) if (!(id in current)) {
			  missing++; if (mode!="unmount" || id!=remove || oldpoint[id]!=point) bad=1 }
			  if (mode=="root" || mode=="guard-root" || mode=="bind4" || mode=="bind7") {
			    if (added!=1 || changed || missing) bad=1
			  } else if (mode=="unmount") { if (missing!=1 || added || changed) bad=1
			  } else if (added || missing || changed>1) bad=1
			  exit bad ? 1 : 0 }
		' "$1" "$2" "$3" "$4" "$5"
		;;
	same)
		shift
		"$cfmgr_view_awk" -F '\t' '
			FILENAME==ARGV[1] { expected[$1]=$0; n++; next }
			{ if (!($1 in expected) || expected[$1]!=$0) bad=1; m++ }
			END { exit bad || n!=m ? 1 : 0 }
		' "$1" "$2"
		;;
	recover)
		shift
		"$cfmgr_view_awk" -F '\t' '
			FILENAME==ARGV[1] { expected[$1]=$0; next }
			FILENAME==ARGV[2] { live[$1]=1; next }
			{ if (!($1 in expected) || expected[$1]!=$0) bad=1; current[$1]=$0; rows[++n]=$0 }
			END { for (id in expected) if (!(id in current) && (id in live)) bad=1
			  if (bad) exit 1; for (i=1;i<=n;i++) print rows[i] }
		' "$1" "$2" "$3" >"$4"
		;;
	dynamic)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { root=ARGV[1]; guard=root; sub(/\/view$/,"/guard",guard); ARGV[1]="" }
			function protected_cover(p, id,best,depth,n,top,a) {
			  for (id in visible) if (path[id]=="/" || path[id]==p || index(p,path[id] "/")==1) {
			    if (length(path[id])>depth) { depth=length(path[id]); best=path[id] } }
			  n=0; top=""
			  for (id in visible) if (path[id]==best && !(id in covered)) { n++; top=id }
			  if (n!=1 || !(top in old) || old[top]!=full[top]) return 0
			  split(full[top],a,"\t"); return (a[3] in immutable) && a[8] ~ /(^|,)ro(,|$)/
			}
			FILENAME==ARGV[2] { old[$1]=$0; olddev[$1]=$3; oldpath[$1]=$5; point[$5]=1; known[$1]=1
			  if ($5==root || $5==guard) { immutable[$3]=1; essential[$1]=1 }; next }
			FILENAME==ARGV[3] { visible[$1]=1; full[$1]=$0; path[$1]=$5; fullparent[$1]=$2; next }
			{ current[$1]=$0; rows[++n]=$0; parent[$1]=$2
			  if ($1 in old) { if (old[$1]!=$0) bad=1 }
			  else { if (index($5,root "/")!=1 || ($5 in point) || ++added>256) bad=1; fresh[$1]=$0; known[$1]=1; point[$5]=1 } }
			END { for (id in visible) if (path[id]==path[fullparent[id]]) covered[fullparent[id]]=1
			  for (id in old) if (!(id in current)) {
			    if ((id in visible) || (id in essential)) bad=1
			    else if ((olddev[id] in immutable) && !protected_cover(oldpath[id])) bad=1
			  }
			  for (id in fresh) { cursor=id; depth=0
			    while (!(cursor in old)) {
			      if (!(cursor in fresh) || ++depth>256) { bad=1; break }; cursor=parent[cursor] }
			  }
			  if (bad) exit 1
			  # Input mountinfo order is normally parent-first; explicitly sort new
			  # children by ancestry depth so reverse cleanup cannot unmount a parent.
			  for (i=1;i<=n;i++) { split(rows[i],a,"\t"); if (!(a[1] in fresh)) continue
			    depth=0; cursor=a[1]; while (!(cursor in old)) { depth++; cursor=parent[cursor] }
			    k=++count; out[k]=rows[i]; d[k]=depth }
			  for (i=2;i<=count;i++) { row=out[i]; depth=d[i]; j=i-1
			    while (j>0 && d[j]>depth) { out[j+1]=out[j]; d[j+1]=d[j]; j-- }; out[j+1]=row; d[j+1]=depth }
			  for (i=1;i<=count;i++) print out[i] }
		' "$1" "$2" "$3" "$4" >"$5"
		;;
	merge)
		shift
		"$cfmgr_view_awk" -F '\t' '{ if (seen[$1]++) exit 1; print }' "$1" "$2" >"$3"
		;;
	cover-private)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { target=ARGV[1]; ARGV[1]="" }
			$5=="/" || $5==target || index(target,$5 "/")==1 {
			  if (length($5)>depth) { depth=length($5); n=0; propagation=$10 }
			  if (length($5)==depth) n++ }
			END { exit n!=1 || propagation!="private" ? 1 : 0 }
		' "$1" "$2"
		;;
	fd-record)
		shift
		"$cfmgr_view_awk" -F '\t' '
			FILENAME==ARGV[1] && /^mnt_id:/ { split($0,a,/ +|\t+/); id=a[2]; n++; next }
			FILENAME==ARGV[2] && $1==id { row=$0; matches++ }
			END { if (n!=1 || id !~ /^[1-9][0-9]*$/ || matches!=1) exit 1; print row }
		' "/proc/self/fdinfo/$1" "$2" >"$3"
		;;
	bind-proof)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { source=ARGV[1]; target=ARGV[2]; ARGV[1]=ARGV[2]="" }
			FILENAME==ARGV[3] { split($0,original,"\t"); n++; next }
			$5==target { row[$1]=$0; parent[$2]=1 }
			END { for (id in row) if (!(id in parent)) { top++; split(row[id],bound,"\t") }
			  if (n!=1 || top!=1) exit 1
			  if (original[5]==source) expected=original[4]
			  else { prefix=original[5]=="/" ? "/" : original[5] "/"
			    if (index(source,prefix)!=1) exit 1
			    expected=(original[4]=="/" ? "" : original[4]) "/" substr(source,length(prefix)+1) }
			  exit bound[3]!=original[3] || bound[4]!=expected || bound[6]!=original[6] ||
			    bound[7]!=original[7] || bound[8]!=original[8] || bound[9]!=original[9] ? 1 : 0 }
		' "$1" "$2" "$3" "$4"
		;;
	properties)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { mode=ARGV[1]; target=ARGV[2]; ARGV[1]=ARGV[2]="" }
			$5==target { row[$1]=$0; parent[$2]=1 }
			END { for (id in row) if (!(id in parent)) { n++; split(row[id],a,"\t") }
			  if (n!=1) exit 1
			  if (mode=="private" || mode=="unbindable") exit a[10]!=mode ? 1 : 0
			  if (a[6]!="tmpfs" || a[4]!="/") exit 1
			  if (mode=="seal") exit a[8] !~ /(^|,)ro(,|$)/ ? 1 : 0
			  exit a[8] !~ /(^|,)rw(,|$)/ || a[10]!="private" ? 1 : 0 }
		' "$1" "$2" "$3"
		;;
	top)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { point=ARGV[1]; ARGV[1]="" }
			$5==point { ids[$1]=1; parents[$2]=1 }
			END { for (id in ids) if (!(id in parents)) { n++; top=id }
			  if (n!=1) exit 1; print top }
		' "$1" "$2" >"$3"
		;;
	*) return 2 ;;
	esac
}

_cfmgr_view_inventory() {
	_cfmgr_view_call inventory "$1" "$2"
}

_cfmgr_view_source_check() {
	cfmgr_storage_attached || return 1
	_cfmgr_view_call identity "$cfmgr_view_native_root" "$cfmgr_view_context/root.current" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/root.identity" "$cfmgr_view_context/root.current" || return $?
	_cfmgr_view_inventory "$cfmgr_view_native_root" "$cfmgr_view_context/source.raw" || return $?
	_cfmgr_view_call awk source "$cfmgr_view_context/source.raw" "$cfmgr_view_context/source.current" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/source.mounts" "$cfmgr_view_context/source.current" || return $?
	_cfmgr_view_call list "$cfmgr_view_native_root" "$cfmgr_view_context/top.current" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/top.names" "$cfmgr_view_context/top.current" || return $?
	cfmgr_view_source_index=0
	while IFS= read -r cfmgr_view_name; do
		cfmgr_view_source_index=$((cfmgr_view_source_index + 1))
		_cfmgr_view_call identity "${cfmgr_view_native_root%/}/$cfmgr_view_name" "$cfmgr_view_context/identity.current" || return $?
		IFS= read -r cfmgr_view_current_identity <"$cfmgr_view_context/identity.current" || return 1
		IFS= read -r cfmgr_view_saved_identity <"$cfmgr_view_context/source.$cfmgr_view_source_index" || return 1
		[ "$cfmgr_view_current_identity" = "$cfmgr_view_saved_identity" ] || return 1
	done <"$cfmgr_view_context/top.names"
}

_cfmgr_view_exact() {
	[ -z "$cfmgr_view_pending" ] || return 3
	case ${cfmgr_view_pin_state:-none} in
	active) _cfmgr_view_keeper check 0 "$cfmgr_view_context/expected.mounts" || return $? ;;
	retired) ;;
	*) return 3 ;;
	esac
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/current.mounts" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/current.mounts"
}

_cfmgr_view_target() {
	# Never follow a mirrored absolute symlink out of the owned scaffold.
	_cfmgr_storage_path "$1" || return 1
	case $1 in "$cfmgr_view_root" | "$cfmgr_view_root"/*) ;; *) return 1 ;; esac
	cfmgr_view_walk=$1
	while [ "$cfmgr_view_walk" != "$cfmgr_view_root" ]; do
		[ ! -L "$cfmgr_view_walk" ] || return 1
		cfmgr_view_walk=${cfmgr_view_walk%/*}
		[ -d "$cfmgr_view_walk" ] && [ ! -L "$cfmgr_view_walk" ] || return 1
	done
}

_cfmgr_view_mutate() {
	# MODE TARGET; source bind descriptor is inherited, never reopened by name.
	_cfmgr_view_exact || return $?
	case $1 in root | guard-root | bind4 | bind7)
		[ "$cfmgr_view_pin_state" = active ] || return 3
		_cfmgr_view_keeper check 1 "$cfmgr_view_context/expected.mounts" || return $?
		;;
	esac
	[ "$cfmgr_view_sequence" -lt 4096 ] || return 3
	cfmgr_view_sequence=$((cfmgr_view_sequence + 1))
	cfmgr_view_pending=$cfmgr_view_sequence
	printf '%s\t%s\n' "$1" "$2" >"$cfmgr_view_context/intent.$cfmgr_view_sequence" || return 3
	if _cfmgr_view_call "$1" "$2"; then cfmgr_view_operation_code=0; else cfmgr_view_operation_code=$?; fi
	[ "$cfmgr_view_operation_code" -ne 3 ] || return 3
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/observed.mounts" || return 3
	if [ "$cfmgr_view_operation_code" -ne 0 ]; then
		if _cfmgr_view_call awk same "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/observed.mounts"; then
			cfmgr_view_pending=''
			return "$cfmgr_view_operation_code"
		fi
		return 3
	fi
	_cfmgr_view_call awk change "$1" "$2" "${cfmgr_view_remove_id:-0}" "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/observed.mounts" || return 3
	case $1 in root | guard-root | private | unbindable | seal)
		_cfmgr_view_call awk properties "$1" "$2" "$cfmgr_view_context/observed.mounts" || return 3
		;;
	esac
	case $1 in root | guard-root | bind4 | bind7)
		# Keep each mount before any overlay can hide it or a writer can enter.
		# shellcheck disable=SC2094 # Borrow only new mount FD; ledger files are distinct.
		_cfmgr_view_pin "$2" "$cfmgr_view_context/observed.mounts" 4<"$2" || return 3
		_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/pinned.mounts" || return 3
		_cfmgr_view_call awk same "$cfmgr_view_context/observed.mounts" "$cfmgr_view_context/pinned.mounts" || return 3
		;;
	esac
	_cfmgr_view_call copy "$cfmgr_view_context/observed.mounts" "$cfmgr_view_context/expected.mounts" || return 3
	printf '%s\t%s\n' "$1" "$2" >"$cfmgr_view_context/done.$cfmgr_view_sequence" || return 3
	cfmgr_view_pending=''
}

# shellcheck disable=SC3013,SC2154 # Descriptor-backed Linux mount identity is required CI proof.
_cfmgr_view_bind() {
	# SOURCE TARGET; '-' means inherited Entware descriptor 7.
	_cfmgr_view_source_check || return $?
	_cfmgr_view_target "$2" || return 1
	[ -e "$2" ] && [ ! -L "$2" ] || return 1
	if [ "$1" = - ]; then cfmgr_view_bind_mode=bind7; else
		exec 4<"$1" || return 1
		cfmgr_view_bind_mode=bind4
	fi
	cfmgr_view_bind_fd=4 cfmgr_view_bind_source=$1
	if [ "$1" = - ]; then
		cfmgr_view_bind_fd=7
		cfmgr_view_bind_source=$cfmgr_storage_opt
	fi
	if ! _cfmgr_view_inventory / "$cfmgr_view_context/bind.mounts"; then
		exec 4<&-
		return 3
	fi
	if ! _cfmgr_view_call awk fd-record "$cfmgr_view_bind_fd" "$cfmgr_view_context/bind.mounts" "$cfmgr_view_context/bind.source"; then
		exec 4<&-
		return 3
	fi
	if _cfmgr_view_mutate "$cfmgr_view_bind_mode" "$2"; then cfmgr_view_bind_code=0; else cfmgr_view_bind_code=$?; fi
	if [ "$cfmgr_view_bind_code" -eq 0 ]; then
		if ! _cfmgr_view_call awk bind-proof "$cfmgr_view_bind_source" "$2" "$cfmgr_view_context/bind.source" "$cfmgr_view_context/expected.mounts"; then cfmgr_view_bind_code=3; fi
		if [ "$1" = - ]; then
			[ "$2" -ef /proc/self/fd/7 ] || cfmgr_view_bind_code=3
		else
			[ "$2" -ef /proc/self/fd/4 ] || cfmgr_view_bind_code=3
		fi
	fi
	exec 4<&-
	if [ "$cfmgr_view_bind_code" -eq 3 ]; then cfmgr_view_pending=bind-unverified; fi
	[ "$cfmgr_view_bind_code" -eq 0 ] || return "$cfmgr_view_bind_code"
	_cfmgr_view_mutate private "$2"
}

_cfmgr_view_guarded_bind() {
	# Empty immutable underlay survives removal of any device-backed upper leaf.
	if [ -d "$2" ]; then cfmgr_view_underlay=$cfmgr_view_guard; else cfmgr_view_underlay=$cfmgr_view_guard/empty; fi
	_cfmgr_view_bind "$cfmgr_view_underlay" "$2" || return $?
	_cfmgr_view_bind "$1" "$2"
}

# Input is trusted controller data, not environment configuration.
# NATIVE_ROOT FRESH_PRIVATE_RAM_CONTEXT AWK READLINK PARSER
# The context and its ancestry must already be admitted/pinned by the controller.
# shellcheck disable=SC2034,SC2154
cfmgr_execution_view_create() {
	# Failed admission must not discard the still-live keeper/view's recovery data.
	case ${cfmgr_keeper_state:-invalid} in active | retained)
		[ -z "${cfmgr_keeper_pid:-}" ] || return 3
		;;
	esac
	cfmgr_view_state=invalid
	[ "$#" -eq 5 ] || return 2
	for cfmgr_view_argument; do _cfmgr_storage_path "$cfmgr_view_argument" || return 2; done
	cfmgr_view_native_root=$1 cfmgr_view_context=$2 cfmgr_view_awk=$3 cfmgr_view_readlink=$4 cfmgr_view_parser=$5
	[ -d "$1" ] && [ ! -L "$1" ] && [ -d "$2" ] && [ ! -L "$2" ] || return 2
	if (: <&4) 2>/dev/null; then return 2; fi
	if (: <&3) 2>/dev/null; then return 2; fi
	# Pinned ash includes type, but its optional command builtin is disabled.
	type cfmgr_execution_view_keeper >/dev/null 2>&1 || return 2
	cfmgr_storage_attached && [ -n "${cfmgr_storage_uuid_value:-}" ] || return 2
	case $1 in "$2" | "$2"/*) return 2 ;; esac
	cfmgr_view_root=$2/view cfmgr_view_guard=$2/guard
	cfmgr_view_sequence=0 cfmgr_view_pending='' cfmgr_view_remove_id=0 cfmgr_view_pin_state=starting
	# Exclusive fresh claim. Existing evidence is never overwritten or removed.
	(
		umask 077
		set -C
		: >"$2/expected.mounts"
	) || return 2
	cfmgr_view_state=building
	# Private propagation must exist before the first mount. Do not change an
	# unrelated host ancestor to repair missing admission.
	_cfmgr_view_inventory / "$2/host.mounts" || return $?
	_cfmgr_view_call awk cover-private "$2" "$2/host.mounts" || return 2
	_cfmgr_view_inventory "$2" "$2/current.mounts" || return $?
	[ ! -s "$2/current.mounts" ] || return 2
	_cfmgr_view_inventory "$1" "$2/source.raw" || return $?
	_cfmgr_view_call awk source "$2/source.raw" "$2/source.mounts" || return $?
	_cfmgr_view_call awk order "$2/source.mounts" "$2/children.mounts" || return $?
	_cfmgr_view_call identity "$1" "$2/root.identity" || return $?
	IFS='	' read -r cfmgr_view_root_inode cfmgr_view_root_mode cfmgr_view_root_uid cfmgr_view_root_gid <"$2/root.identity" || return 2
	case $cfmgr_view_root_mode in '' | *[!0-7]*) return 2 ;; esac
	[ "${#cfmgr_view_root_mode}" -le 4 ] && [ "$cfmgr_view_root_uid:$cfmgr_view_root_gid" = 0:0 ] || return 2
	_cfmgr_view_call list "$1" "$2/top.names" || return $?
	cfmgr_view_source_index=0
	while IFS= read -r cfmgr_view_name; do
		case $cfmgr_view_name in '' | . | .. | */* | *[!\ -~]*) return 2 ;; esac
		cfmgr_view_source_index=$((cfmgr_view_source_index + 1))
		[ "$cfmgr_view_source_index" -le 256 ] || return 2
		_cfmgr_view_call identity "${1%/}/$cfmgr_view_name" "$2/source.$cfmgr_view_source_index" || return $?
	done <"$2/top.names"
	_cfmgr_view_keeper start "$cfmgr_view_context" || return $?
	cfmgr_view_pin_state=active
	_cfmgr_view_call mkdir "$cfmgr_view_guard" 700 || return $?
	_cfmgr_view_mutate guard-root "$cfmgr_view_guard" || return $?
	_cfmgr_view_call file "$cfmgr_view_guard/empty" || return $?
	_cfmgr_view_mutate seal "$cfmgr_view_guard" || return $?
	_cfmgr_view_call mkdir "$cfmgr_view_root" 700 || return $?
	_cfmgr_view_mutate root "$cfmgr_view_root" || return $?
	_cfmgr_view_mutate unbindable "$cfmgr_view_root" || return $?
	cfmgr_view_has_opt=0
	while IFS= read -r cfmgr_view_name; do
		cfmgr_view_from=${cfmgr_view_native_root%/}/$cfmgr_view_name
		cfmgr_view_to=$cfmgr_view_root/$cfmgr_view_name
		if [ "$cfmgr_view_name" = opt ]; then
			cfmgr_view_has_opt=1
			_cfmgr_view_call mkdir "$cfmgr_view_to" 755 || return $?
			_cfmgr_view_guarded_bind - "$cfmgr_view_to" || return $?
		elif [ -L "$cfmgr_view_from" ]; then
			_cfmgr_view_call readlink "$cfmgr_view_from" "$cfmgr_view_context/link.text" || return $?
			{
				IFS= read -r cfmgr_view_link || return 2
				cfmgr_view_link_extra=''
				if IFS= read -r cfmgr_view_link_extra; then return 2; fi
				[ -z "$cfmgr_view_link_extra" ] || return 2
			} <"$cfmgr_view_context/link.text"
			[ "${#cfmgr_view_link}" -le 4096 ] || return 2
			case $cfmgr_view_link in '' | *[!\ -~]*) return 2 ;; esac
			_cfmgr_view_call link "$cfmgr_view_link" "$cfmgr_view_to" || return $?
		else
			if [ -d "$cfmgr_view_from" ]; then
				_cfmgr_view_call mkdir "$cfmgr_view_to" 755 || return $?
			elif [ -f "$cfmgr_view_from" ]; then
				_cfmgr_view_call file "$cfmgr_view_to" || return $?
			else return 2; fi
			_cfmgr_view_guarded_bind "$cfmgr_view_from" "$cfmgr_view_to" || return $?
		fi
	done <"$cfmgr_view_context/top.names"
	if [ "$cfmgr_view_has_opt" -eq 0 ]; then
		_cfmgr_view_call mkdir "$cfmgr_view_root/opt" 755 || return $?
		_cfmgr_view_guarded_bind - "$cfmgr_view_root/opt" || return $?
	fi
	while IFS='	' read -r cfmgr_view_id cfmgr_view_parent cfmgr_view_device cfmgr_view_fsroot cfmgr_view_point cfmgr_view_type cfmgr_view_source cfmgr_view_options cfmgr_view_super cfmgr_view_propagation; do
		cfmgr_view_relative=${cfmgr_view_point#"${cfmgr_view_native_root%/}"/}
		cfmgr_view_to=$cfmgr_view_root/$cfmgr_view_relative
		_cfmgr_view_target "$cfmgr_view_to" || return 1
		_cfmgr_view_guarded_bind "$cfmgr_view_point" "$cfmgr_view_to" || return $?
		case $cfmgr_view_point in "$cfmgr_storage_opt"/*)
			cfmgr_view_opt_child=$cfmgr_view_root/opt/${cfmgr_view_point#"$cfmgr_storage_opt"/}
			if [ "$cfmgr_view_opt_child" != "$cfmgr_view_to" ]; then
				_cfmgr_view_guarded_bind "$cfmgr_view_point" "$cfmgr_view_opt_child" || return $?
			fi
			;;
		esac
	done <"$cfmgr_view_context/children.mounts"
	# Native /tmp mirrors the controller's private directory. Hide only that
	# owned context, never create a directory through a bound native parent.
	case $cfmgr_view_context in
	"${cfmgr_view_native_root%/}"/*)
		cfmgr_view_relative=${cfmgr_view_context#"${cfmgr_view_native_root%/}"/}
		_cfmgr_view_bind "$cfmgr_view_guard" "$cfmgr_view_root/$cfmgr_view_relative" || return $?
		;;
	esac
	_cfmgr_view_call chmod "$cfmgr_view_root" "$cfmgr_view_root_mode" || return $?
	_cfmgr_view_mutate seal "$cfmgr_view_root" || return $?
	cfmgr_execution_view_recheck || return $?
	cfmgr_view_state=ready
}

# Register only complete, ancestry-verified new descendants; original immutable
# layers/replacements cannot be adopted. Foreign root pins never enter this ledger.
# Missing detached owned IDs stay in the lifetime ledger until quiescent release.
# shellcheck disable=SC2034,SC2094 # Full parsed columns; borrowed mount FD, distinct ledger files.
cfmgr_execution_view_reconcile() {
	[ "$cfmgr_view_pin_state" = active ] && [ -z "$cfmgr_view_pending" ] || return 3
	_cfmgr_view_keeper check 0 "$cfmgr_view_context/expected.mounts" || return 3
	_cfmgr_view_inventory / "$cfmgr_view_context/all.mounts" || return 3
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/current.mounts" || return 3
	_cfmgr_view_call awk dynamic "$cfmgr_view_root" "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/all.mounts" "$cfmgr_view_context/current.mounts" "$cfmgr_view_context/new.mounts" || return 3
	while IFS='	' read -r cfmgr_view_dynamic_id cfmgr_view_dynamic_parent cfmgr_view_dynamic_device cfmgr_view_dynamic_fsroot cfmgr_view_dynamic_point cfmgr_view_dynamic_type cfmgr_view_dynamic_source cfmgr_view_dynamic_options cfmgr_view_dynamic_super cfmgr_view_dynamic_propagation; do
		[ "$cfmgr_view_sequence" -lt 4096 ] || return 3
		_cfmgr_view_target "$cfmgr_view_dynamic_point" || return 3
		cfmgr_view_sequence=$((cfmgr_view_sequence + 1))
		cfmgr_view_pending=dynamic-unverified
		printf 'dynamic\t%s\n' "$cfmgr_view_dynamic_point" >"$cfmgr_view_context/intent.$cfmgr_view_sequence" || return 3
		_cfmgr_view_pin "$cfmgr_view_dynamic_point" "$cfmgr_view_context/current.mounts" 4<"$cfmgr_view_dynamic_point" || return 3
		printf 'dynamic\t%s\n' "$cfmgr_view_dynamic_point" >"$cfmgr_view_context/done.$cfmgr_view_sequence" || return 3
		cfmgr_view_pending=dynamic-unverified
	done <"$cfmgr_view_context/new.mounts"
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/pinned.mounts" || return 3
	_cfmgr_view_call awk same "$cfmgr_view_context/current.mounts" "$cfmgr_view_context/pinned.mounts" || return 3
	_cfmgr_view_call awk merge "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/new.mounts" "$cfmgr_view_context/merged.mounts" || return 3
	_cfmgr_view_call copy "$cfmgr_view_context/merged.mounts" "$cfmgr_view_context/expected.mounts" || return 3
	cfmgr_view_pending=''
}

cfmgr_execution_view_recheck() {
	case ${cfmgr_view_state:-invalid} in building | ready) ;; *) return 2 ;; esac
	if _cfmgr_view_source_check && _cfmgr_view_exact; then return 0; else
		cfmgr_view_recheck_code=$?
		cfmgr_view_state=retained
		return "$cfmgr_view_recheck_code"
	fi
}

# Caller must independently prove no owned task/thread/root can still use the
# view. Missing mounts are reconciled only after that proof and full-namespace
# absence; a hidden/replaced mount ID or any foreign layer preserves evidence.
cfmgr_execution_view_release() {
	case ${cfmgr_view_state:-invalid} in building | ready | retained) ;; *) return 2 ;; esac
	cfmgr_view_state=retained
	case $cfmgr_view_pin_state in
	active) cfmgr_execution_view_quiescent || return 3 ;;
	retired) cfmgr_execution_view_quiescent retired || return 3 ;;
	*) return 3 ;;
	esac
	[ -z "$cfmgr_view_pending" ] || return 3
	_cfmgr_view_inventory / "$cfmgr_view_context/all.mounts" || return $?
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/current.mounts" || return $?
	_cfmgr_view_call awk recover "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/all.mounts" "$cfmgr_view_context/current.mounts" "$cfmgr_view_context/recovered.mounts" || return 3
	_cfmgr_view_call copy "$cfmgr_view_context/recovered.mounts" "$cfmgr_view_context/expected.mounts" || return 3
	# Ledger reconciles while all retained IDs remain lifetime-pinned. Only then
	# retire reference authority, release/reap keeper, and recheck every unmount.
	case $cfmgr_view_pin_state in
	active)
		_cfmgr_view_exact || return 3
		_cfmgr_view_keeper release || return 3
		cfmgr_view_pin_state=retired
		;;
	retired) ;;
	*) return 3 ;;
	esac
	cfmgr_view_release_sequence=$cfmgr_view_sequence
	while [ "$cfmgr_view_release_sequence" -gt 0 ]; do
		if [ -f "$cfmgr_view_context/done.$cfmgr_view_release_sequence" ]; then
			IFS='	' read -r cfmgr_view_done_mode cfmgr_view_done_target <"$cfmgr_view_context/done.$cfmgr_view_release_sequence" || return 3
			case $cfmgr_view_done_mode in root | guard-root | bind4 | bind7 | dynamic)
				_cfmgr_view_exact || return 3
				if _cfmgr_view_call awk top "$cfmgr_view_done_target" "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/top.id"; then
					IFS= read -r cfmgr_view_remove_id <"$cfmgr_view_context/top.id" || return 3
					if _cfmgr_view_mutate unmount "$cfmgr_view_done_target"; then :; else return $?; fi
				else
					cfmgr_view_top_status=$?
					[ "$cfmgr_view_top_status" -eq 1 ] || return 3
				fi
				;;
			esac
		fi
		cfmgr_view_release_sequence=$((cfmgr_view_release_sequence - 1))
	done
	_cfmgr_view_exact || return 3
	[ ! -s "$cfmgr_view_context/expected.mounts" ] || return 3
	cfmgr_view_state=released
	# Retain the flat control ledger and now-empty mountpoint directories for
	# explicit controller-owned recovery/cleanup; never recursively delete here.
}

# ---- execution tasks ----
# Source-inert task/root supervision for an admitted, lifetime-pinned view.
# All tools/code/contexts are explicit controller-admitted native operands.
# shellcheck disable=SC2034,SC2154,SC2016 # Fixed imported/result fields and literal AWK programs.
# Never signal from a retired ledger, unknown root, or partially read thread group.

_cfmgr_tasks_now() {
	IFS=' ' read -r cfmgr_tasks_clock cfmgr_tasks_idle </proc/uptime || return 3
	cfmgr_tasks_now=${cfmgr_tasks_clock%%.*}
	case $cfmgr_tasks_now in '' | *[!0-9]*) return 3 ;; esac
}

# Arbitrary tasks need a distinct parser: stat comm is not trusted shell data.
# A malformed/unreadable live identity is unknown, not an exclusion.
# shellcheck disable=SC2016
_cfmgr_tasks_identity() {
	# Capture complete LF-terminated proc records before AWK; getline alone
	# cannot distinguish a truncated final record on the supported AWK variants.
	cfmgr_tasks_stat_lines=0 cfmgr_tasks_stat_bytes=0 cfmgr_tasks_stat_tail=''
	: >"$cfmgr_tasks_context/stat.raw" || return 3
	{
		while IFS= read -r cfmgr_tasks_stat_tail; do
			cfmgr_tasks_stat_lines=$((cfmgr_tasks_stat_lines + 1))
			cfmgr_tasks_stat_bytes=$((cfmgr_tasks_stat_bytes + ${#cfmgr_tasks_stat_tail} + 1))
			[ "$cfmgr_tasks_stat_lines" -le 17 ] && [ "$cfmgr_tasks_stat_bytes" -le 4096 ] || return 3
			printf '%s\n' "$cfmgr_tasks_stat_tail" >>"$cfmgr_tasks_context/stat.raw" || return 3
			cfmgr_tasks_stat_tail=''
		done
		[ -z "$cfmgr_tasks_stat_tail" ] || return 3
	} 2>/dev/null <"$1/stat" || return 3
	"$cfmgr_tasks_awk" '
		{ bytes+=length($0)+1; if (bytes>4096 || NR>17) bad=1
		  record=record (NR==1 ? "" : "\n") $0 }
		END { if (bad || NR<1 || record !~ /^[1-9][0-9]* \(/) exit 1
		  pid=record; sub(/ .*/,"",pid)
		  tail=record; sub(/^.*\) /,"",tail); n=split(tail,a,/ +/)
		  if (tail==record || n<20 || a[1] !~ /^[RSDZTtXxKWPI]$/ ||
		    a[2] !~ /^[0-9]+$/ || a[7] !~ /^[0-9]+$/ || a[20] !~ /^[1-9][0-9]*$/) exit 1
		  for (i=2;i<=n;i++) if (a[i] !~ /^-?[0-9]+$/) exit 1
		  print pid,a[20],a[1],a[2],a[7] }
	' "$cfmgr_tasks_context/stat.raw" >"$cfmgr_tasks_context/identity" 2>/dev/null || return 3
	IFS=' ' read -r cfmgr_tasks_tid cfmgr_tasks_start cfmgr_tasks_identity_state cfmgr_tasks_parent cfmgr_tasks_flags <"$cfmgr_tasks_context/identity" || return 3
}

# Only actual CLOEXEC regular shell bookkeeping is allowed above the known I/O.
# Kernel fdinfo incorporates FD_CLOEXEC; checking original open flags is insufficient.
# shellcheck disable=SC2016
cfmgr_execution_tasks_fd_admit() (
	[ "$#" -eq 2 ] || exit 2
	set +f
	for cfmgr_tasks_fdinfo in /proc/"$1"/fdinfo/*; do
		cfmgr_tasks_fd=${cfmgr_tasks_fdinfo##*/}
		case $cfmgr_tasks_fd in '' | *[!0-9]*) exit 3 ;; esac
		[ "$cfmgr_tasks_fd" -ge 10 ] || continue
		[ -f "/proc/$1/fd/$cfmgr_tasks_fd" ] && [ ! -d "/proc/$1/fd/$cfmgr_tasks_fd" ] || exit 2
		"$2" '/^flags:/ { n++; f=$2; p=length(f)-6; if (f !~ /^[0-7]+$/ || p<1 || substr(f,p,1) !~ /^[2367]$/) bad=1 }
		  END { exit n!=1 || bad ? 1 : 0 }' "$cfmgr_tasks_fdinfo" || exit 2
	done
)

_cfmgr_tasks_pin() {
	# Actual opened root on FD4; dedup is safe only while all old refs remain held.
	cfmgr_mount_keeper_check 0 || return 3
	# shellcheck disable=SC2016
	if "$cfmgr_tasks_awk" -v id="$1" '$1==id { found=1 } END { exit found ? 0 : 1 }' "$cfmgr_keeper_context/pins"; then return 0; fi
	cfmgr_mount_keeper_retain "$1" || return 3
}

# Root classification requires positive ancestry, never pathname spelling.
# The per-task namespace inventory also permits positively foreign host tasks in
# the isolated CI namespace. Same unique scaffold/guard filesystem outside its
# known ancestry is ambiguous and cannot be classified foreign.
# shellcheck disable=SC2016
_cfmgr_tasks_classify() {
	"$cfmgr_tasks_awk" -F '\t' '
		BEGIN { id=ARGV[1]; root=ARGV[5]; guard=ARGV[6]; ARGV[1]=ARGV[4]=ARGV[5]=ARGV[6]="" }
		FILENAME==ARGV[2] { own[$1]=1; if ($5==root || $5==guard) unique[$3]=1; next }
		FILENAME==ARGV[3] { parent[$1]=$2; dev[$1]=$3; point[$1]=$5; next }
		END { if (id in own) { print "owned"; exit }
		  cursor=id; for (n=0;n<4096;n++) {
		    if (cursor in own) { print "dynamic"; exit }
		    if (!(cursor in parent) || seen[cursor]++ || dev[cursor] in unique) exit 1
		    if (!(parent[cursor] in parent)) { if (point[cursor]!="/") exit 1; print "foreign"; exit }
		    cursor=parent[cursor]
		  }; exit 1 }
	' "$1" "$cfmgr_view_context/expected.mounts" "$2" ignored "$cfmgr_view_root" "$cfmgr_view_guard" >"$cfmgr_tasks_context/class" || return 3
	IFS= read -r cfmgr_tasks_class <"$cfmgr_tasks_context/class" || return 3
}

# Borrow/restore FD4 to reopen the current task root before accepting the row.
# shellcheck disable=SC2016
_cfmgr_tasks_root_again() {
	"$cfmgr_tasks_awk" -v expected="$1" '/^mnt_id:/ { n++; if ($2!=expected) bad=1 } END { exit n!=1 || bad ? 1 : 0 }' /proc/self/fdinfo/4
}

_cfmgr_tasks_thread() {
	# TGID TASK_DIRECTORY; caller groups every live thread before signal admission.
	_cfmgr_tasks_identity "$2" || return 3
	cfmgr_tasks_before=$cfmgr_tasks_tid:$cfmgr_tasks_start
	case $cfmgr_tasks_identity_state in Z | X | x) return 0 ;; esac
	# Positive PF_KTHREAD exclusion; zero/unreadable flags are not an exclusion.
	if "$cfmgr_tasks_awk" -v flags="$cfmgr_tasks_flags" 'BEGIN { exit int(flags/2097152)%2 ? 0 : 1 }'; then return 0; fi
	# Keep a missing-root open failure inside the compound command; exec is a
	# POSIX special builtin and its failing redirection can otherwise exit ash.
	if { exec 4<&0; } 2>/dev/null <"$2/root"; then :; else return 3; fi
	"$cfmgr_tasks_awk" '/^mnt_id:/ { n++; if (NF!=2 || $2 !~ /^[1-9][0-9]*$/) bad=1; id=$2 }
	  END { if (n!=1 || bad) exit 1; print id }' /proc/self/fdinfo/4 >"$cfmgr_tasks_context/root.id" || {
		exec 4<&-
		return 3
	}
	IFS= read -r cfmgr_tasks_root_id <"$cfmgr_tasks_context/root.id" || {
		exec 4<&-
		return 3
	}
	# Use the held-ID classification cache only after the sweep's keeper proof.
	# Newly visible descendants were reconciled before this scan.
	if ! "$cfmgr_tasks_awk" -F '\t' -v id="$cfmgr_tasks_root_id" '
	  FILENAME==ARGV[1] && $1==id { owned=1 }
	  FILENAME==ARGV[2] && $1==id { foreign=1 }
	  END { if (owned) print "owned"; else if (foreign) print "foreign"; else exit 1 }
	' "$cfmgr_view_context/expected.mounts" "$cfmgr_tasks_context/foreign.ids" >"$cfmgr_tasks_context/class"; then
		# Use the full controller namespace, never a chroot-filtered task inventory.
		# New root mounts need another complete reconciliation while FD4 holds the
		# actual object. If it detached before registration, ancestry is unknown.
		if ! cfmgr_execution_view_reconcile; then
			exec 4<&-
			return 3
		fi
		if ! _cfmgr_tasks_classify "$cfmgr_tasks_root_id" "$cfmgr_view_context/all.mounts"; then
			exec 4<&-
			return 3
		fi
	else IFS= read -r cfmgr_tasks_class <"$cfmgr_tasks_context/class" || {
		exec 4<&-
		return 3
	}; fi
	if ! _cfmgr_tasks_identity "$2"; then
		exec 4<&-
		return 3
	fi
	[ "$cfmgr_tasks_before" = "$cfmgr_tasks_tid:$cfmgr_tasks_start" ] || {
		exec 4<&-
		return 3
	}
	case $cfmgr_tasks_class in owned | foreign) ;; *)
		exec 4<&-
		return 3
		;;
	esac
	# Only a new ID needs a protocol transfer/full keeper scan. All existing IDs
	# remain referenced by the keeper proved at the start/end of this sweep.
	if ! "$cfmgr_tasks_awk" -v id="$cfmgr_tasks_root_id" '$1==id { found=1 } END { exit found ? 0 : 1 }' "$cfmgr_keeper_context/pins"; then
		if ! _cfmgr_tasks_pin "$cfmgr_tasks_root_id"; then
			exec 4<&-
			return 3
		fi
		if [ "$cfmgr_tasks_class" = foreign ]; then printf '%s\n' "$cfmgr_tasks_root_id" >>"$cfmgr_tasks_context/foreign.ids" || {
			exec 4<&-
			return 3
		}; fi
	fi
	if ! _cfmgr_tasks_root_again "$cfmgr_tasks_root_id" 4<"$2/root"; then
		exec 4<&-
		return 3
	fi
	exec 4<&-
	if ! _cfmgr_tasks_identity "$2"; then return 3; fi
	[ "$cfmgr_tasks_before" = "$cfmgr_tasks_tid:$cfmgr_tasks_start" ] || return 3
	case $cfmgr_tasks_class in
	owned) printf '%s %s %s owned %s\n' "$1" "$cfmgr_tasks_tid" "$cfmgr_tasks_start" "$cfmgr_tasks_group_start" >>"$cfmgr_tasks_context/${cfmgr_tasks_rows:-sweep}" || return 3 ;;
	foreign) printf '%s %s %s foreign %s\n' "$1" "$cfmgr_tasks_tid" "$cfmgr_tasks_start" "$cfmgr_tasks_group_start" >>"$cfmgr_tasks_context/${cfmgr_tasks_rows:-sweep}" || return 3 ;;
	*) return 3 ;;
	esac
}

# Complete fresh all-TGID/TID sweep. Unknown/exiting observations are retried as
# whole snapshots, with a finite deadline, never converted into a partial success.
cfmgr_execution_tasks_sweep() {
	[ "$cfmgr_view_pin_state" = active ] || return 3
	_cfmgr_tasks_now || return 3
	cfmgr_tasks_sweep_deadline=$((cfmgr_tasks_now + 5))
	case ${cfmgr_tasks_cleanup_deadline:-} in
	[0-9]*) if [ "$cfmgr_tasks_cleanup_deadline" -lt "$cfmgr_tasks_sweep_deadline" ]; then cfmgr_tasks_sweep_deadline=$cfmgr_tasks_cleanup_deadline; fi ;;
	esac
	if [ "${cfmgr_tasks_state:-none}" = running ] && [ -z "${cfmgr_tasks_cleanup_deadline:-}" ]; then
		[ "$cfmgr_tasks_deadline" -ge "$cfmgr_tasks_sweep_deadline" ] || cfmgr_tasks_sweep_deadline=$cfmgr_tasks_deadline
	fi
	while :; do
		cfmgr_mount_keeper_check 0 || return 3
		cfmgr_execution_view_reconcile || return 3
		: >"$cfmgr_tasks_context/sweep" || return 3
		# Proc task names are bounded numeric kernel entries, not executable data.
		cfmgr_tasks_glob=on
		case $- in *f*) cfmgr_tasks_glob=off ;; esac
		set +f
		cfmgr_tasks_total=0 cfmgr_tasks_snapshot=0 cfmgr_tasks_rows=sweep
		for cfmgr_tasks_group in /proc/[0-9]*/task; do
			[ -d "$cfmgr_tasks_group" ] || continue
			cfmgr_tasks_tgid=${cfmgr_tasks_group%/task}
			cfmgr_tasks_tgid=${cfmgr_tasks_tgid##*/}
			if ! _cfmgr_tasks_identity "/proc/$cfmgr_tasks_tgid"; then
				cfmgr_tasks_snapshot=3
				break
			fi
			cfmgr_tasks_group_start=$cfmgr_tasks_start
			for cfmgr_tasks_thread_dir in "$cfmgr_tasks_group"/[0-9]*; do
				[ -d "$cfmgr_tasks_thread_dir" ] || continue
				_cfmgr_tasks_now || {
					cfmgr_tasks_snapshot=3
					break
				}
				if [ "$cfmgr_tasks_now" -ge "$cfmgr_tasks_sweep_deadline" ]; then
					cfmgr_tasks_snapshot=3
					break
				fi
				cfmgr_tasks_total=$((cfmgr_tasks_total + 1))
				if [ "$cfmgr_tasks_total" -gt 8192 ]; then
					cfmgr_tasks_snapshot=3
					break
				fi
				if _cfmgr_tasks_thread "$cfmgr_tasks_tgid" "$cfmgr_tasks_thread_dir"; then :; else
					cfmgr_tasks_snapshot=3
					break
				fi
			done
			[ "$cfmgr_tasks_snapshot" -eq 0 ] || break
			if ! _cfmgr_tasks_identity "/proc/$cfmgr_tasks_tgid"; then
				cfmgr_tasks_snapshot=3
				break
			fi
			if [ "$cfmgr_tasks_group_start" != "$cfmgr_tasks_start" ]; then
				cfmgr_tasks_snapshot=3
				break
			fi
		done
		if [ "$cfmgr_tasks_glob" = off ]; then set -f; fi
		[ "$cfmgr_tasks_snapshot" -ne 0 ] || break
		_cfmgr_tasks_now || return 3
		[ "$cfmgr_tasks_now" -lt "$cfmgr_tasks_sweep_deadline" ] || return 3
		"$cfmgr_tasks_usleep" 50000 || return 3
	done
	cfmgr_mount_keeper_check 0 || return 3
	# Mixed groups cannot authorize group signals, even if one thread is owned.
	# shellcheck disable=SC2016
	"$cfmgr_tasks_awk" '{ if ($4=="owned") owned[$1]=1; else foreign[$1]=1 }
	  END { for (p in owned) if (p in foreign) exit 1; for (p in owned) print p }' "$cfmgr_tasks_context/sweep" >"$cfmgr_tasks_context/owned" || return 3
}

# CONTEXT ENV CHROOT NATIVE_ASH COPIED_HELPER AWK READLINK USLEEP
# Followed by four in-view native tool paths: ASH AWK READLINK USLEEP.
cfmgr_execution_tasks_start() {
	[ "$#" -eq 12 ] && [ "$cfmgr_view_state" = ready ] || return 2
	case ${cfmgr_tasks_state:-none} in running | retained) return 3 ;; esac
	cfmgr_tasks_cleanup_deadline='' cfmgr_tasks_loss=0 cfmgr_tasks_action_refused=0
	cfmgr_tasks_context=$1 cfmgr_tasks_env=$2 cfmgr_tasks_chroot=$3 cfmgr_tasks_shell=$4 cfmgr_tasks_helper=$5
	cfmgr_tasks_awk=$6 cfmgr_tasks_readlink=$7 cfmgr_tasks_usleep=$8 cfmgr_tasks_inside_shell=$9
	shift 9
	cfmgr_tasks_inside_awk=$1 cfmgr_tasks_inside_readlink=$2 cfmgr_tasks_inside_usleep=$3
	cfmgr_tasks_parser=$cfmgr_view_parser
	cfmgr_prerequisites_identity "$$" || return 2
	cfmgr_tasks_owner=$$ cfmgr_tasks_owner_start=$cfmgr_identity_start
	IFS= read -r cfmgr_tasks_boot </proc/sys/kernel/random/boot_id || return 2
	cfmgr_execution_tasks_fd_admit "$$" "$cfmgr_tasks_awk" || return 2
	cfmgr_execution_tasks_native fifo "$cfmgr_tasks_context/gate" || return $?
	(
		umask 077
		set -C
		: >"$cfmgr_tasks_context/receipt"
		[ -f "$cfmgr_tasks_context/foreign.ids" ] && [ ! -L "$cfmgr_tasks_context/foreign.ids" ] && [ ! -s "$cfmgr_tasks_context/foreign.ids" ]
	) || return 2
	exec 4<>"$cfmgr_tasks_context/gate" || return 3
	cfmgr_tasks_state=retained
	"$cfmgr_tasks_env" -i PATH="${cfmgr_tasks_inside_shell%/*}:/bin:/usr/bin:/sbin:/usr/sbin" LC_ALL=C OPENSSL_CONF=/dev/null \
		"$cfmgr_tasks_chroot" "$cfmgr_view_root" "$cfmgr_tasks_inside_shell" /proc/self/fd/9 dependency \
		"$cfmgr_tasks_inside_awk" "$cfmgr_tasks_inside_readlink" "$cfmgr_tasks_inside_usleep" \
		0<&4 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<"$cfmgr_tasks_helper" \
		>"$cfmgr_tasks_context/receipt" 2>/dev/null &
	cfmgr_tasks_pid=$!
	cfmgr_prerequisites_identity "$cfmgr_tasks_pid" || return 3
	cfmgr_tasks_direct_start=$cfmgr_identity_start
	cfmgr_tasks_state=running
	_cfmgr_tasks_now || return 3
	cfmgr_tasks_deadline=$((cfmgr_tasks_now + 120))
	case ${cfmgr_dependencies_operation_deadline:-} in
	[0-9]*) [ "$cfmgr_dependencies_operation_deadline" -ge "$cfmgr_tasks_deadline" ] || cfmgr_tasks_deadline=$cfmgr_dependencies_operation_deadline ;;
	esac
	cfmgr_execution_tasks_receipt ready || return 3
	# The launch helper is a direct child, and actual root FD proves the view.
	cfmgr_prerequisites_identity "$cfmgr_tasks_pid" || return 3
	[ "$cfmgr_identity_start:$cfmgr_identity_parent" = "$cfmgr_tasks_direct_start:$cfmgr_tasks_owner" ] || return 3
	# shellcheck disable=SC3013 # Actual mount-root identity is a Linux contract.
	[ "/proc/$cfmgr_tasks_pid/root" -ef "$cfmgr_view_root" ] || return 3
	_cfmgr_tasks_action_admit || return $?
	printf 'query END\n' >&4 || return 3
	cfmgr_execution_tasks_receipt queried || return 3
}

_cfmgr_tasks_direct() {
	if cfmgr_prerequisites_identity "$cfmgr_tasks_pid"; then :; else
		# A still-visible identity failure is unknown, never an exit receipt.
		[ ! -e "/proc/$cfmgr_tasks_pid" ] && [ ! -L "/proc/$cfmgr_tasks_pid" ] || return 3
		return 1
	fi
	[ "$cfmgr_identity_start:$cfmgr_identity_parent" = "$cfmgr_tasks_direct_start:$cfmgr_tasks_owner" ] || return 3
	IFS= read -r cfmgr_tasks_current_boot </proc/sys/kernel/random/boot_id || return 3
	[ "$cfmgr_tasks_current_boot" = "$cfmgr_tasks_boot" ] || return 3
}

# Observe the action budget before accepting a receipt or releasing a gate.
# Cleanup has its own deadline and deliberately remains available after refusal.
_cfmgr_tasks_action_admit() {
	if [ "${cfmgr_install_interrupted:-0}" != 0 ]; then
		cfmgr_tasks_action_refused=1
		return 1
	fi
	_cfmgr_tasks_now || return 3
	if [ "$cfmgr_tasks_now" -ge "$cfmgr_tasks_deadline" ]; then
		cfmgr_tasks_action_refused=1
		return 1
	fi
	if ! cfmgr_storage_attached; then
		cfmgr_tasks_loss=1 cfmgr_tasks_action_refused=1
		cfmgr_execution_tasks_event storage-lost || return 3
		return 1
	fi
}

# Fixed receipt states; writes may be temporarily partial, never accepted partial.
# shellcheck disable=SC2016
cfmgr_execution_tasks_receipt() {
	while :; do
		_cfmgr_tasks_action_admit || return $?
		if "$cfmgr_tasks_awk" -v phase="$1" '
		  length($0)>4096 || NR>512 || $0 ~ /[^ -~\t]/ { bad=1 }
		  $0=="ready END" && phase=="ready" { found=1 }
		  $0 ~ /^queried [0-9]+ END$/ && phase=="queried" { found=1 }
		  END { exit bad || !found ? 1 : 0 }' "$cfmgr_tasks_context/receipt"; then
			_cfmgr_tasks_action_admit
			return $?
		fi
		_cfmgr_tasks_direct || return $?
		case $cfmgr_identity_state in Z | X | x) return 1 ;; esac
		"$cfmgr_tasks_usleep" 50000 || return 3
	done
}

cfmgr_execution_tasks_run() {
	[ "$#" -eq 1 ] && [ "$cfmgr_tasks_state" = running ] || return 2
	if _cfmgr_tasks_action_admit; then :; else
		cfmgr_tasks_admission_code=$?
		[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
		cfmgr_execution_tasks_finish || return 3
		return 1
	fi
	cfmgr_execution_view_recheck || return 3
	# A long recheck may finish after interruption, expiry or attachment loss.
	if _cfmgr_tasks_action_admit; then :; else
		cfmgr_tasks_admission_code=$?
		[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
		cfmgr_execution_tasks_finish || return 3
		return 1
	fi
	printf 'repair %s END\n' "$1" >&4 || return 3
	exec 4<&-
	cfmgr_tasks_exit=1
	while :; do
		if _cfmgr_tasks_action_admit; then :; else
			cfmgr_tasks_admission_code=$?
			[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
			break
		fi
		if _cfmgr_tasks_direct; then
			case $cfmgr_identity_state in Z | X | x)
				if _cfmgr_tasks_action_admit; then :; else
					cfmgr_tasks_admission_code=$?
					[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
				fi
				break
				;;
			esac
		else
			cfmgr_tasks_direct_code=$?
			[ "$cfmgr_tasks_direct_code" -eq 1 ] || return 3
			if _cfmgr_tasks_action_admit; then :; else
				cfmgr_tasks_admission_code=$?
				[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
			fi
			break
		fi
		cfmgr_execution_tasks_sweep || return 3
		"$cfmgr_tasks_usleep" 100000 || return 3
	done
	# Direct completion does not establish descendant quiescence. Do not test the
	# old action deadline after separately bounded cleanup of a timely completion.
	if cfmgr_execution_tasks_finish; then
		if ! cfmgr_storage_attached; then
			cfmgr_tasks_loss=1
			cfmgr_execution_tasks_event storage-lost || return 3
		fi
		[ "${cfmgr_install_interrupted:-0}" = 0 ] && [ "$cfmgr_tasks_action_refused:$cfmgr_tasks_loss" = 0:0 ] || return 1
		return "$cfmgr_tasks_exit"
	else return $?; fi
}

# Immediately re-prove the complete target thread group and start generation.
# No signal is sent for a positively vanished group; every live unknown retains.
_cfmgr_tasks_signal_admit() {
	[ -d "/proc/$1" ] || return 1
	cfmgr_mount_keeper_check 0 || return 3
	cfmgr_execution_view_reconcile || return 3
	_cfmgr_tasks_identity "/proc/$1" || return 3
	cfmgr_tasks_group_start=$cfmgr_tasks_start
	# shellcheck disable=SC2016
	"$cfmgr_tasks_awk" -v pid="$1" -v start="$cfmgr_tasks_group_start" '$1==pid && $5!=start { bad=1 } END { exit bad ? 1 : 0 }' "$cfmgr_tasks_context/sweep" || return 3
	cfmgr_tasks_rows=signal
	: >"$cfmgr_tasks_context/signal" || return 3
	cfmgr_tasks_glob=on
	case $- in *f*) cfmgr_tasks_glob=off ;; esac
	set +f
	cfmgr_tasks_signal_code=0
	for cfmgr_tasks_signal_thread in /proc/"$1"/task/[0-9]*; do
		[ -d "$cfmgr_tasks_signal_thread" ] || continue
		_cfmgr_tasks_now || {
			cfmgr_tasks_signal_code=3
			break
		}
		[ "$cfmgr_tasks_now" -lt "$cfmgr_tasks_cleanup_deadline" ] || {
			cfmgr_tasks_signal_code=3
			break
		}
		if _cfmgr_tasks_thread "$1" "$cfmgr_tasks_signal_thread"; then :; else
			cfmgr_tasks_signal_code=3
			break
		fi
	done
	if [ "$cfmgr_tasks_glob" = off ]; then set -f; fi
	cfmgr_tasks_rows=sweep
	[ "$cfmgr_tasks_signal_code" -eq 0 ] || return 3
	_cfmgr_tasks_identity "/proc/$1" || return 3
	[ "$cfmgr_tasks_start" = "$cfmgr_tasks_group_start" ] || return 3
	# shellcheck disable=SC2016
	"$cfmgr_tasks_awk" '$4!="owned" { bad=1 } END { exit bad || NR<1 ? 1 : 0 }' "$cfmgr_tasks_context/signal" || return 3
}

cfmgr_execution_tasks_finish() {
	exec 4<&-
	cfmgr_tasks_survivors=0
	_cfmgr_tasks_now || return 3
	cfmgr_tasks_cleanup_deadline=$((cfmgr_tasks_now + 10))
	cfmgr_dependencies_operation_deadline=$cfmgr_tasks_cleanup_deadline
	cfmgr_keeper_outer_deadline=$cfmgr_tasks_cleanup_deadline
	while :; do
		cfmgr_execution_tasks_sweep || {
			cfmgr_tasks_state=retained
			return 3
		}
		if [ ! -s "$cfmgr_tasks_context/owned" ]; then break; fi
		cfmgr_tasks_survivors=1
		_cfmgr_tasks_now || return 3
		[ "$cfmgr_tasks_now" -lt "$cfmgr_tasks_cleanup_deadline" ] || {
			cfmgr_tasks_state=retained
			return 3
		}
		# A second complete sweep immediately precedes each observational numeric
		# group signal. No parent/PGID shortcut and no foreign lifetime pin authority.
		cfmgr_execution_tasks_sweep || return 3
		while IFS= read -r cfmgr_tasks_signal_pid; do
			cfmgr_tasks_signal=TERM
			if [ "$cfmgr_tasks_now" -ge "$((cfmgr_tasks_cleanup_deadline - 5))" ]; then cfmgr_tasks_signal=KILL; fi
			if _cfmgr_tasks_signal_admit "$cfmgr_tasks_signal_pid"; then
				cfmgr_execution_tasks_native signal "$cfmgr_tasks_signal_pid" "$cfmgr_tasks_signal" || return 3
			else
				cfmgr_tasks_signal_code=$?
				[ "$cfmgr_tasks_signal_code" -eq 1 ] || return 3
			fi
		done <"$cfmgr_tasks_context/owned"
		"$cfmgr_tasks_usleep" 100000 || return 3
	done
	# An empty owned-root sweep cannot prove a pre-chroot launch child exited.
	# Do not block in wait or adopt/signal a live child with an unproved root.
	if _cfmgr_tasks_direct; then
		case $cfmgr_identity_state in Z | X | x) ;; *)
			cfmgr_tasks_state=retained
			return 3
			;;
		esac
	else
		cfmgr_tasks_direct_code=$?
		[ "$cfmgr_tasks_direct_code" -eq 1 ] || {
			cfmgr_tasks_state=retained
			return 3
		}
	fi
	if wait "$cfmgr_tasks_pid"; then cfmgr_tasks_exit=0; else cfmgr_tasks_exit=$?; fi
	[ "$cfmgr_tasks_survivors" = 0 ] || cfmgr_tasks_exit=1
	cfmgr_tasks_state=quiescent cfmgr_tasks_cleanup_deadline=''
}

cfmgr_execution_tasks_quiescent() {
	[ "${cfmgr_tasks_state:-none}" = quiescent ] || return 3
	cfmgr_execution_tasks_sweep || return 3
	[ ! -s "$cfmgr_tasks_context/owned" ]
}

# ---- mount keeper ----
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
	# Fixed controller's optional whole-phase budget also bounds ACK/FD retries.
	# Empty for standalone keeper consumers; never derived from environment.
	case ${cfmgr_keeper_outer_deadline:-} in
	'') ;;
	*[!0-9]*) return 3 ;;
	*) [ "$cfmgr_keeper_now" -lt "$cfmgr_keeper_outer_deadline" ] || return 3 ;;
	esac
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
		"$cfmgr_keeper_shell" "$cfmgr_keeper_helper" mount-keeper "$1" "$cfmgr_keeper_owner" "$cfmgr_keeper_owner_start" "$cfmgr_keeper_boot" \
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

# ---- Native probe orchestration ----
cfmgr_native_path() {
	[ -n "$1" ] && [ "${#1}" -le 4096 ] || return 1
	case $1 in /*) ;; *) return 1 ;; esac
	case $1 in *[!\ -~]* | *\\* | *:* | *//* | */./* | */../* | */. | */.. | */) return 1 ;; esac
}

cfmgr_native_step() {
	cfmgr_native_reason=$1
	shift
	if cfmgr_native_action "$@"; then return 0; else
		cfmgr_native_step_code=$?
		if [ "$cfmgr_native_step_code" -eq 3 ]; then cfmgr_native_unresolved=1 cfmgr_native_ready=0; fi
		return "$cfmgr_native_step_code"
	fi
}

cfmgr_native_zero() {
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] && [ ! -s "$cfmgr_native_output" ]
}

cfmgr_native_check() {
	[ "${cfmgr_native_unresolved:-0}" = 0 ] || return 3
	cfmgr_native_ready=0 cfmgr_native_reason=arguments cfmgr_native_dir_owned=0
	[ "$#" -eq 4 ] || return 2
	for cfmgr_native_argument; do cfmgr_native_path "$cfmgr_native_argument" || return 2; done
	cfmgr_native_context=$1 cfmgr_native_curl=$2 cfmgr_native_openssl=$3 cfmgr_native_ca=$4
	[ -d "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ -x "$2" ] && [ -f "$3" ] && [ -x "$3" ] || return 2
	if (: <&3) 2>/dev/null; then return 2; fi
	for cfmgr_native_claim in native.source native.destination native.copy native.published native.directory; do
		if [ -e "$1/$cfmgr_native_claim" ] || [ -L "$1/$cfmgr_native_claim" ]; then
			cfmgr_native_reason=context-not-fresh
			return 2
		fi
	done
	if cfmgr_native_offline && cfmgr_native_mutations; then cfmgr_native_result=0; else cfmgr_native_result=$?; fi
	[ "$cfmgr_native_result" -ne 3 ] || return 3
	cfmgr_native_saved_reason=$cfmgr_native_reason
	if cfmgr_native_cleanup; then :; else
		cfmgr_native_cleanup_code=$?
		if [ "$cfmgr_native_cleanup_code" -eq 3 ]; then cfmgr_native_unresolved=1; fi
		return "$cfmgr_native_cleanup_code"
	fi
	cfmgr_native_reason=$cfmgr_native_saved_reason
	[ "$cfmgr_native_result" -eq 0 ] || return "$cfmgr_native_result"
	cfmgr_native_ready=1 cfmgr_native_reason=''
}
