#!/bin/sh
# Category owner: status. Sourcing defines functions only.

# ---- status ----
# Source-inert, local-only status consumer. No operational preparation/repair.
# Imports are fixed installed paths admitted by the trusted entry; no data sourcing.
# A private report context holds bounded native snapshots and a config projection.
# Status runs in a subshell so menu descriptors, traps and launch state survive.
# shellcheck disable=SC2034,SC2154,SC3013
cfmgr_status_row() {
	# The trusted entry owns one finite, printable-only basic/full row renderer.
	cfmgr_entry_health_row "$@"
}

# Full-health interfaces are deliberately separate from basic Status. Call in
# the health subshell after the entry has admitted the fixed reporting closure.
cfmgr_health_begin() {
	set +x
	set +v
	ulimit -c 0 || return 2
	cfmgr_status_prepare || return 1
	cfmgr_health_active=1 cfmgr_health_operations=0 cfmgr_health_requests=0
	cfmgr_health_files=0 cfmgr_health_bytes=0 cfmgr_health_rows=0 cfmgr_health_owned=''
	cfmgr_health_final_operations=0 cfmgr_health_final_files=0 cfmgr_health_final_bytes=0
	cfmgr_health_final_deadline=''
	cfmgr_health_provider_stop=0 cfmgr_health_scope_holds='' cfmgr_health_transport=unknown
	cfmgr_health_public_eligible=0 cfmgr_health_ipv6_ready=0 cfmgr_health_native_admitted=0
	cfmgr_health_clock_ready=0
	cfmgr_health_realpath_limit=8 cfmgr_health_mount_limit=8 cfmgr_health_entware_limit=128
	cfmgr_health_reason='' cfmgr_health_incomplete=0
	cfmgr_health_deadline=$((cfmgr_probe_now + 45))
	# Five seconds plus eight operations/16 files/1MiB remain for final
	# rendering/cleanup. Counters are monotonic, including failed operations.
	cfmgr_health_collect_deadline=$((cfmgr_health_deadline - 5))
}

cfmgr_health_mode() {
	cfmgr_health_mode_files=2 cfmgr_health_mode_limit=8 cfmgr_health_mode_get=0
	case $1 in
	health-snapshot | health-cloud-pem | health-cloud-decode) cfmgr_health_mode_limit=128 ;;
	health-entware-metadata)
		cfmgr_health_mode_limit=${cfmgr_health_entware_limit:-128}
		case $cfmgr_health_mode_limit in '' | *[!0-9]* | 0*) return 2 ;; esac
		[ "${#cfmgr_health_mode_limit}" -le 3 ] && [ "$cfmgr_health_mode_limit" -le 128 ] || return 2
		;;
	health-realpath | health-mount)
		case $1 in health-realpath) cfmgr_health_mode_limit=${cfmgr_health_realpath_limit:-8} ;; *) cfmgr_health_mode_limit=${cfmgr_health_mount_limit:-8} ;; esac
		case $cfmgr_health_mode_limit in [1-8]) ;; *) return 2 ;; esac
		;;
	health-get) cfmgr_health_mode_limit=64 cfmgr_health_mode_files=4 cfmgr_health_mode_get=1 ;;
	health-render) cfmgr_health_mode_limit=384 ;;
	health-flat-list) cfmgr_health_mode_limit=64 ;;
	health-log-debug | health-log-hex | health-log-pids) cfmgr_health_mode_limit=128 ;;
	health-log-process | health-log-argv) cfmgr_health_mode_limit=64 ;;
	health-log-inspect)
		case ${cfmgr_health_log_inspect_limit:-2} in '' | *[!0-9]* | 0*) return 2 ;; esac
		[ "${cfmgr_health_log_inspect_limit:-2}" -le 22528 ] || return 2
		cfmgr_health_mode_limit=${cfmgr_health_log_inspect_limit:-2}
		;;
	health-cloud-plan) cfmgr_health_mode_limit=64 ;;
	health-cloud-authority | health-selected-copy | health-selected-hex | health-selected-metadata | health-cloud-yaml | health-cloud-join | health-log-metadata | health-log-hash | health-log-count | health-log-script | health-log-cron | health-log-bundle)
		case ${cfmgr_health_selected_limit:-} in '' | *[!0-9]* | 0*) return 2 ;; esac
		[ "${#cfmgr_health_selected_limit}" -le 5 ] && [ "$cfmgr_health_selected_limit" -le 22528 ] || return 2
		cfmgr_health_mode_limit=$cfmgr_health_selected_limit
		;;
	# Only finite typed receipts/empty successful probes use the tiny tier.
	# Native ash:1024 bytes/file; supported host reservation:2048 bytes/file.
	health-protected | health-metadata-check | health-flat-check | health-package-check | health-hooks-cron | health-hooks-frame | health-backup-observe | health-backup-uuid | health-cloud-frame | health-selected-check | health-selected-hash | health-cloud-json | health-scope | health-frame | health-request-check | health-trace | health-count | health-render-count | \
		health-wc-jq | health-wc-sha | health-count-get | health-current | health-uuid | health-date | health-native | \
		health-jq-good | health-jq-bad | health-sha-bytes | health-sha-good | health-sha-bad | \
		health-timeout-exit | health-timeout-expiry | health-flock-first | health-flock-compete | health-flock-after | health-flock-release | health-flock-finish | \
		health-flock-entware-first | health-flock-entware-compete | health-flock-entware-after | health-flock-entware-release | health-flock-entware-finish | \
		health-curl-features | health-ca-pem | health-ca-decode | health-curl-offline | health-log-account | health-log-link | health-log-proc-meta | health-log-base | health-log-assess | health-log-path) cfmgr_health_mode_limit=2 ;;
	health-inventory | health-storage | health-uname | health-blkid | health-native-metadata | \
		health-hooks-authority | health-backup-plan | health-log-authority | health-log-version | health-log-syntax | health-log-includes | health-dig-version | health-request | health-config | health-fields | health-metadata | \
		health-nvram | health-space | health-curl-version | health-response | health-compare) ;;
	*) return 2 ;;
	esac
	# Reserve the larger host physical payload for EACH writable file.
	cfmgr_health_mode_bytes=$((cfmgr_health_mode_files * cfmgr_health_mode_limit * 1024))
}

cfmgr_health_reserve() {
	case ${cfmgr_health_active:-0} in 1) ;; *) return 2 ;; esac
	case ${cfmgr_probe_pid:-} in
	'') ;;
	*) case ${cfmgr_probe_status:-} in reaped) ;; *) return 3 ;; esac ;;
	esac
	cfmgr_health_mode "$1" || return 2
	case $1 in health-render | health-render-count)
		cfmgr_health_final_reserve "$1"
		return $?
		;;
	esac
	case ${cfmgr_health_final_deadline:-} in '') ;; *) return 1 ;; esac
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	# These counters are initialized/incremented here and mode sizes are admitted
	# above. Native ash has no test builtin: evaluate this numeric-only guard in
	# shell arithmetic rather than launching five separate comparison processes.
	case $((cfmgr_probe_now >= cfmgr_health_collect_deadline || \
	cfmgr_health_operations >= 568 || \
	cfmgr_health_requests + cfmgr_health_mode_get > 12 || \
	cfmgr_health_files + cfmgr_health_mode_files > 1264 || \
	cfmgr_health_bytes + cfmgr_health_mode_bytes > 11534336)) in
	1)
		cfmgr_health_incomplete=1 cfmgr_health_reason=budget
		return 1
		;;
	esac
	cfmgr_health_operations=$((cfmgr_health_operations + 1))
	cfmgr_health_requests=$((cfmgr_health_requests + cfmgr_health_mode_get))
	cfmgr_health_files=$((cfmgr_health_files + cfmgr_health_mode_files))
	cfmgr_health_bytes=$((cfmgr_health_bytes + cfmgr_health_mode_bytes))
	cfmgr_health_label=$1.$((${cfmgr_probe_serial:-0} + 1))
	for cfmgr_health_suffix in out err; do
		cfmgr_health_owned="$cfmgr_health_owned
$cfmgr_health_label.$cfmgr_health_suffix"
	done
	case $cfmgr_health_mode_get in 1)
		cfmgr_health_owned="$cfmgr_health_owned
$cfmgr_health_label.body
$cfmgr_health_label.headers"
		;;
	esac
}

# Finalization has its own reserved envelope and does not alter collection totals.
cfmgr_health_final_reserve() {
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	[ -n "${cfmgr_health_final_deadline:-}" ] && [ "$cfmgr_probe_now" -lt "$cfmgr_health_final_deadline" ] || return 1
	[ "$cfmgr_health_final_operations" -lt 8 ] &&
		[ "$((cfmgr_health_final_files + cfmgr_health_mode_files))" -le 16 ] &&
		[ "$((cfmgr_health_final_bytes + cfmgr_health_mode_bytes))" -le 1048576 ] || return 1
	[ "$cfmgr_health_operations" -le 568 ] && [ "$cfmgr_health_files" -le 1264 ] &&
		[ "$cfmgr_health_bytes" -le 11534336 ] || return 1
	cfmgr_health_final_operations=$((cfmgr_health_final_operations + 1))
	cfmgr_health_final_files=$((cfmgr_health_final_files + cfmgr_health_mode_files))
	cfmgr_health_final_bytes=$((cfmgr_health_final_bytes + cfmgr_health_mode_bytes))
	cfmgr_health_label=$1.$((${cfmgr_probe_serial:-0} + 1))
	cfmgr_health_owned="$cfmgr_health_owned
$cfmgr_health_label.out
$cfmgr_health_label.err"
}

cfmgr_health_run() {
	cfmgr_health_mode_name=$1 cfmgr_health_tool=$2
	shift 2
	cfmgr_prerequisites_run "$cfmgr_health_mode_name" "$cfmgr_status_context" /bin/sh \
		"$cfmgr_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_health_tool" "$@"
}

cfmgr_health_count() {
	cfmgr_health_count_file=$1 cfmgr_health_count_limit=$2
	cfmgr_health_run health-count /usr/bin/wc "$1" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_health_size cfmgr_health_extra <"$cfmgr_probe_stdout" || return 1
	case $cfmgr_health_size in '' | *[!0-9]* | 0?*) return 1 ;; esac
	[ "${#cfmgr_health_size}" -le 8 ] && [ -z "$cfmgr_health_extra" ] && [ "$cfmgr_health_size" -le "$cfmgr_health_count_limit" ]
}

cfmgr_health_row() {
	[ "$#" = 6 ] || return 2
	case $1:$2:$6 in *[!A-Za-z0-9._:-]* | :* | *:) return 2 ;; esac
	case $2 in PASS | FAIL | WARN | SKIP | UNKNOWN) ;; *) return 2 ;; esac
	[ "${#1}" -le 64 ] && [ "${#3}" -le 512 ] && [ "${#4}" -le 64 ] && [ "${#5}" -le 512 ] && [ "${#6}" -le 64 ] || return 2
	for cfmgr_health_field; do case $cfmgr_health_field in '' | *[!\ -~]*) return 2 ;; esac done
	[ "$cfmgr_health_rows" -lt 96 ] || {
		cfmgr_health_incomplete=1
		return 1
	}
	cfmgr_health_rows=$((cfmgr_health_rows + 1))
	case ${cfmgr_health_staging:-0} in
	1) /usr/bin/printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$@" >&3 ;;
	*) cfmgr_status_row "$@" ;;
	esac
}

# Direct files are reserved before opening, independently of supervised outputs.
cfmgr_health_stage_reserve() {
	[ "$#" = 2 ] || return 2
	[ "${cfmgr_health_active:-0}" = 1 ] || return 2
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	[ -z "${cfmgr_health_final_deadline:-}" ] || return 1
	case $1 in log.spec.* | log.metadata.* | log.process-index.* | log.bundle-index.*)
		case $1 in *[!A-Za-z0-9.-]* | *..*) return 2 ;; esac
		case ${1##*.}:$2 in *[!0-9:]* | :* | *:) return 2 ;; esac
		case $2 in '' | *[!0-9]* | 0*) return 2 ;; esac
		[ "${#2}" -le 5 ] || return 2
		case $1 in
		log.spec.*) [ "$2" -le 32768 ] || return 2 ;;
		log.metadata.*) [ "$2" -le 65536 ] || return 2 ;;
		*) case $2 in 32768 | 65536) ;; *) return 2 ;; esac ;;
		esac
		;;
	*) case $1:$2 in comparison:2048 | dashboard:32768 | rows:262144 | json.good:8192 | json.bad:8192 | bytes:8192 | checksum.good:8192 | checksum.bad:8192 | lock:8192 | timeout.child:8192) ;; *) return 2 ;; esac ;; esac
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	if [ "$cfmgr_probe_now" -ge "$cfmgr_health_collect_deadline" ] ||
		[ "$cfmgr_health_files" -ge 1264 ] || [ "$((cfmgr_health_bytes + $2))" -gt 11534336 ]; then
		cfmgr_health_incomplete=1 cfmgr_health_reason=budget
		return 1
	fi
	case "$cfmgr_health_owned
" in *"
$1
"*) return 2 ;; esac
	cfmgr_health_files=$((cfmgr_health_files + 1)) cfmgr_health_bytes=$((cfmgr_health_bytes + $2))
	cfmgr_health_owned="$cfmgr_health_owned
$1"
}

cfmgr_health_finalize() {
	[ "$#" = 2 ] || return 2
	cfmgr_health_final_begin || return $?
	cfmgr_health_render_width
	cfmgr_status_run status-render /usr/bin/awk "$cfmgr_source/modules/status.sh" "$1" "$2" "$cfmgr_status_width" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_render_output=$cfmgr_probe_stdout
	cfmgr_health_run health-render-count /usr/bin/wc "$cfmgr_health_render_output" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_health_render_bytes cfmgr_health_render_extra <"$cfmgr_probe_stdout" || return 1
	case $cfmgr_health_render_bytes in '' | *[!0-9]* | 0?*) return 1 ;; esac
	[ -z "$cfmgr_health_render_extra" ] && [ "$cfmgr_health_render_bytes" -le 196608 ] || return 1
	cfmgr_status_attachment_ok && [ -f "$cfmgr_health_render_output" ] && [ ! -L "$cfmgr_health_render_output" ] || return 1
	/bin/cat "$cfmgr_health_render_output" || return $?
	if [ "${cfmgr_log_available:-0}" = 1 ]; then
		cfmgr_health_capture_result=ok
		[ "${cfmgr_health_code:-0}:${cfmgr_health_incomplete:-0}" = 0:0 ] || cfmgr_health_capture_result=incomplete
		cfmgr_log_health "$cfmgr_health_render_output" "$cfmgr_health_render_bytes" "$cfmgr_health_capture_result"
	else
		printf '%s\n' '[CFMGR] capture.saved SKIP saving was unavailable; trusted capture prerequisites are missing'
	fi
	return 0
}

cfmgr_health_final_begin() {
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	if [ -z "${cfmgr_health_final_deadline:-}" ]; then
		cfmgr_health_final_deadline=$((cfmgr_probe_now + 5))
		[ "$cfmgr_health_final_deadline" -le "$cfmgr_health_deadline" ] || cfmgr_health_final_deadline=$cfmgr_health_deadline
	fi
}

cfmgr_health_cleanup() {
	cfmgr_status_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_health_seen=0
	for cfmgr_health_file in "$cfmgr_status_context"/* "$cfmgr_status_context"/.[!.]* "$cfmgr_status_context"/..?*; do
		[ -e "$cfmgr_health_file" ] || [ -L "$cfmgr_health_file" ] || continue
		[ -f "$cfmgr_health_file" ] && [ ! -L "$cfmgr_health_file" ] || return 1
		case "$cfmgr_health_owned
" in *"
${cfmgr_health_file##*/}
"*) ;; *) return 1 ;; esac
		cfmgr_health_seen=$((cfmgr_health_seen + 1))
		[ "$cfmgr_health_seen" -le 1280 ] || return 1
	done
	set --
	for cfmgr_health_file in "$cfmgr_status_context"/*; do
		[ -f "$cfmgr_health_file" ] || continue
		set -- "$@" "$cfmgr_health_file"
		case $# in 64)
			cfmgr_health_remove "$@" || return $?
			set --
			;;
		esac
	done
	case $# in 0) ;; *) cfmgr_health_remove "$@" || return $? ;; esac
	/bin/rmdir "$cfmgr_status_context" || return 1
	exec 9<&-
}

cfmgr_health_remove() {
	cfmgr_status_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	case $# in 0) return 2 ;; esac
	case $(($# > 64)) in 1) return 2 ;; esac
	for cfmgr_health_remove_file; do
		case $cfmgr_health_remove_file in "$cfmgr_status_context"/*) ;; *) return 2 ;; esac
		case "$cfmgr_health_owned
" in *"
${cfmgr_health_remove_file#"$cfmgr_status_context/"}
"*) ;; *) return 2 ;; esac
	done
	/bin/rm -f "$@"
}

cfmgr_health_project() {
	cfmgr_health_run "$1" /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_health_config" "$cfmgr_health_config_bytes" \
		"$2" "$3" "$4" "$5" "${cfmgr_health_public_eligible:-0}" "${cfmgr_health_ipv6_ready:-0}"
}

cfmgr_health_frame() {
	cfmgr_health_frame_file=$1 cfmgr_health_frame_kind=$2
	cfmgr_health_run health-frame /usr/bin/awk "$cfmgr_source/modules/status.sh" \
		"$cfmgr_health_frame_file" 0 "$cfmgr_health_frame_kind" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]
}

cfmgr_health_sizes() {
	cfmgr_health_size_valid=0
	cfmgr_health_run health-count-get /usr/bin/wc "$cfmgr_health_http_file" "$cfmgr_health_body" "$cfmgr_health_headers" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_count_index=0
	cfmgr_health_count_ok=1
	while :; do
		cfmgr_health_count_line=''
		if IFS= read -r cfmgr_health_count_line; then :; else
			[ -z "$cfmgr_health_count_line" ] || cfmgr_health_count_ok=0
			break
		fi
		cfmgr_health_count_index=$((cfmgr_health_count_index + 1))
		[ "$cfmgr_health_count_index" -le 4 ] || {
			cfmgr_health_count_ok=0
			break
		}
		cfmgr_health_count_line=${cfmgr_health_count_line#"${cfmgr_health_count_line%%[! ]*}"}
		cfmgr_health_count_number=${cfmgr_health_count_line%% *}
		cfmgr_health_count_label=${cfmgr_health_count_line#* }
		case $cfmgr_health_count_number in '' | *[!0-9]* | 0?*) cfmgr_health_count_ok=0 ;; esac
		[ "${#cfmgr_health_count_number}" -le 6 ] || cfmgr_health_count_ok=0
		if [ "$cfmgr_health_count_index" -le 3 ]; then
			case $cfmgr_health_count_index in
			1) cfmgr_health_count_expected=$cfmgr_health_http_file ;;
			2) cfmgr_health_count_expected=$cfmgr_health_body ;;
			3) cfmgr_health_count_expected=$cfmgr_health_headers ;;
			esac
			[ "$cfmgr_health_count_label" = "$cfmgr_health_count_expected" ] || cfmgr_health_count_ok=0
			case $cfmgr_health_count_index in
			1) cfmgr_health_http_bytes=$cfmgr_health_count_number ;;
			2) cfmgr_health_body_bytes=$cfmgr_health_count_number ;;
			3) cfmgr_health_header_bytes=$cfmgr_health_count_number ;;
			esac
		else
			[ "$cfmgr_health_count_label" = total ] || cfmgr_health_count_ok=0
			cfmgr_health_count_total=$cfmgr_health_count_number
		fi
	done <"$cfmgr_probe_stdout"
	[ "$cfmgr_health_count_index" = 4 ] || cfmgr_health_count_ok=0
	[ "$cfmgr_health_count_ok" = 1 ] || return 1
	[ "$cfmgr_health_http_bytes" = 4 ] &&
		[ "$cfmgr_health_count_total" -eq "$((cfmgr_health_http_bytes + cfmgr_health_body_bytes + cfmgr_health_header_bytes))" ] || return 1
	cfmgr_health_size_valid=1
	[ "$cfmgr_health_body_bytes" -le 32768 ] && [ "$cfmgr_health_header_bytes" -le 8192 ]
}

cfmgr_health_snapshot() {
	cfmgr_status_snapshot "$cfmgr_source/config" || return $?
	cfmgr_health_config=$cfmgr_status_snapshot_file cfmgr_health_config_bytes=$cfmgr_status_snapshot_bytes
}

cfmgr_health_http() {
	case $1 in
	401 | 403)
		cfmgr_health_scope_holds="$cfmgr_health_scope_holds
$cfmgr_health_scope"
		cfmgr_health_result=auth-rejected-read
		;;
	429) cfmgr_health_provider_stop=1 cfmgr_health_result=provider-throttle ;;
	200) cfmgr_health_result=read-response ;;
	5[0-9][0-9]) cfmgr_health_result=transient-transport ;;
	[1-5][0-9][0-9]) cfmgr_health_result=resource-unverified ;;
	*)
		cfmgr_health_result=transport-unverified
		return 1
		;;
	esac
}

cfmgr_health_transport_exit() {
	case $1 in
	6 | 7)
		cfmgr_health_transport=unavailable cfmgr_health_result=host-transport-unavailable
		return 1
		;;
	60 | 77)
		cfmgr_health_transport=unavailable cfmgr_health_result=transport-prerequisite
		return 1
		;;
	*) return 0 ;;
	esac
}

cfmgr_health_get() {
	if _cfmgr_health_get "$@"; then cfmgr_health_get_code=0; else cfmgr_health_get_code=$?; fi
	[ "$cfmgr_health_get_code" = 3 ] || exec 6<&-
	return "$cfmgr_health_get_code"
}

_cfmgr_health_get() {
	# FEATURE KIND LOCAL-SELECTOR FAMILY. Caller sets only proved nonsecret
	# eligibility flags; they default to deny. Public eligibility must come from
	# a validated configured credential/resource scope, not configured alone.
	# Clock readiness comes only from current typed native ntp_ready evidence.
	# No caller supplies a URL or token.
	cfmgr_health_result=prerequisite-blocked cfmgr_health_result_file='' cfmgr_health_scope_eligible=0
	[ "$#" = 4 ] && [ "${cfmgr_health_transport:-unknown}" = ready ] && [ "${cfmgr_health_clock_ready:-0}" = 1 ] || return 1
	[ "${cfmgr_health_provider_stop:-0}" = 0 ] || {
		cfmgr_health_result=provider-throttle
		return 1
	}
	cfmgr_health_project health-scope "$@" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || {
		cfmgr_health_result=config-invalid
		return 1
	}
	cfmgr_health_scope_file=$cfmgr_probe_stdout
	cfmgr_health_frame "$cfmgr_health_scope_file" scope || return $?
	IFS=' ' read -r cfmgr_health_tag cfmgr_health_version cfmgr_health_eligibility cfmgr_health_feature cfmgr_health_scope cfmgr_health_kind cfmgr_health_resource cfmgr_health_name cfmgr_health_type cfmgr_health_request_bytes cfmgr_health_end <"$cfmgr_health_scope_file" || return 1
	case $cfmgr_health_eligibility in eligible) ;; *)
		cfmgr_health_result=$cfmgr_health_eligibility
		return 1
		;;
	esac
	case "$cfmgr_health_scope_holds
" in *"
$cfmgr_health_scope
"*)
		cfmgr_health_result=scope-auth-hold
		return 1
		;;
	esac
	cfmgr_health_scope_eligible=1
	cfmgr_health_project health-request "$@" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_request=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_request" 4352 || return $?
	[ "$cfmgr_health_size" = "$cfmgr_health_request_bytes" ] || return 1
	exec 6<"$cfmgr_health_request" || return 1
	cfmgr_health_run health-request-check /usr/bin/awk "$cfmgr_source/modules/status.sh" \
		"$cfmgr_health_request" "$cfmgr_health_request_bytes" "$cfmgr_health_kind" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ] || return 1
	cfmgr_health_body=$cfmgr_status_context/health-get.$((${cfmgr_probe_serial:-0} + 1)).body
	cfmgr_health_headers=$cfmgr_status_context/health-get.$((${cfmgr_probe_serial:-0} + 1)).headers
	if cfmgr_health_run health-get "$cfmgr_health_curl" "$cfmgr_health_request" "$cfmgr_health_ca" \
		"$cfmgr_status_context" "$cfmgr_health_body" "$cfmgr_health_headers" "$4"; then :; else
		cfmgr_health_code=$?
		[ "$cfmgr_health_code" != 3 ] || return 3
		exec 6<&-
		cfmgr_health_result=transport-unverified
		return "$cfmgr_health_code"
	fi
	cfmgr_health_http_file=$cfmgr_probe_stdout cfmgr_health_curl_exit=$cfmgr_probe_exit cfmgr_health_curl_error=$cfmgr_probe_stderr
	cfmgr_health_result=transport-unverified
	if cfmgr_health_sizes; then cfmgr_health_size_code=0; else cfmgr_health_size_code=$?; fi
	[ "$cfmgr_health_size_code" != 3 ] || return 3
	[ "$cfmgr_health_size_valid" = 1 ] || return 1
	IFS= read -r cfmgr_health_http_code <"$cfmgr_health_http_file" || return 1
	[ "${#cfmgr_health_http_code}" = 3 ] || return 1
	case $cfmgr_health_http_code in [0-9][0-9][0-9]) ;; *) return 1 ;; esac
	cfmgr_health_http "$cfmgr_health_http_code" || :
	cfmgr_health_transport_exit "$cfmgr_health_curl_exit" || return 1
	# HTTP rejection/throttle is retained even if curl also reports a body limit.
	[ "$cfmgr_health_http_code" = 200 ] && [ "$cfmgr_health_curl_exit" = 0 ] && [ ! -s "$cfmgr_health_curl_error" ] || {
		exec 6<&-
		return 1
	}
	[ "$cfmgr_health_size_code" = 0 ] && [ "$cfmgr_health_size_valid" = 1 ] || return 1
	case $cfmgr_health_kind in
	trace)
		cfmgr_health_run health-trace /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_health_body" "$cfmgr_health_body_bytes" "$4" || return $?
		;;
	*)
		cfmgr_health_run health-response /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
			"$cfmgr_source/modules/status.sh" "$cfmgr_health_body" "$cfmgr_health_body_bytes" \
			"$cfmgr_health_scope_file" "$cfmgr_health_request" "$cfmgr_health_request_bytes" || return $?
		;;
	esac
	exec 6<&-
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || {
		cfmgr_health_result=response-unverified
		return 1
	}
	cfmgr_health_result_file=$cfmgr_probe_stdout
	cfmgr_health_frame "$cfmgr_health_result_file" response || return $?
	cfmgr_health_result=observed-read
}

cfmgr_health_protected() {
	# PATH BOUNDARY KIND. Cache only protected ancestors within this report.
	cfmgr_health_admit_path=$1 cfmgr_health_admit_root=$2 cfmgr_health_admit_kind=$3
	while :; do
		[ ! -L "$cfmgr_health_admit_path" ] || return 1
		case "$cfmgr_health_protected_cache
" in *"
$cfmgr_health_admit_path
"*) ;;
		*)
			cfmgr_health_run health-metadata /bin/ls "$cfmgr_health_admit_path" || return $?
			[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
			cfmgr_health_run health-protected /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_probe_stdout" "$cfmgr_health_admit_kind" - || return $?
			[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
			cfmgr_health_protected_cache="$cfmgr_health_protected_cache
$cfmgr_health_admit_path"
			;;
		esac
		[ "$cfmgr_health_admit_path" != "$cfmgr_health_admit_root" ] || return 0
		[ "$cfmgr_health_admit_path" != / ] || return 1
		cfmgr_health_admit_path=${cfmgr_health_admit_path%/*}
		[ -n "$cfmgr_health_admit_path" ] || cfmgr_health_admit_path=/
		cfmgr_health_admit_kind=directory
	done
}

cfmgr_health_canonical() {
	# Unknown resolution keeps the original 4KiB native allowance. A caller
	# comparing against an already-known exact path can reserve its finite size.
	cfmgr_health_realpath_limit=8
	if [ -n "${2:-}" ] && [ "${#2}" -lt 4096 ]; then
		cfmgr_health_realpath_limit=$(((${#2} + 512) / 512))
	fi
	if cfmgr_health_run health-realpath /usr/bin/readlink "$1"; then cfmgr_health_resolve_status=0; else cfmgr_health_resolve_status=$?; fi
	cfmgr_health_realpath_limit=8
	[ "$cfmgr_health_resolve_status" = 0 ] || return "$cfmgr_health_resolve_status"
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	{
		IFS= read -r cfmgr_health_resolved || return 1
		cfmgr_health_resolved_extra=''
		if IFS= read -r cfmgr_health_resolved_extra || [ -n "$cfmgr_health_resolved_extra" ]; then return 1; fi
	} <"$cfmgr_probe_stdout"
	case $cfmgr_health_resolved in /*) ;; *) return 1 ;; esac
	case $cfmgr_health_resolved in *[!\ -~]* | *\\* | *//*) return 1 ;; esac
}

cfmgr_health_admit_native() {
	case $1 in /usr/bin/flock) cfmgr_health_native_expected='' ;; *) cfmgr_health_native_expected=$1 ;; esac
	cfmgr_health_canonical "$1" "$cfmgr_health_native_expected" || return $?
	case $1:$cfmgr_health_resolved:$2 in /usr/bin/flock:/bin/busybox:executable)
		# Retained firmware images use this fixed native applet symlink. Admit
		# both protected namespaces, then preserve argv[0] applet selection.
		[ -f /bin/busybox ] && [ ! -L /bin/busybox ] && [ -x /bin/busybox ] || return 1
		cfmgr_health_protected /usr/bin / directory || return $?
		cfmgr_health_protected /bin/busybox / file
		return $?
		;;
	esac
	[ "$cfmgr_health_resolved" = "$1" ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	case $2 in executable) [ -x "$1" ] || return 1 ;; data) ;; *) return 2 ;; esac
	cfmgr_health_protected "$1" / file
}

cfmgr_health_entware_attachment() {
	[ "$cfmgr_health_opt" -ef /proc/self/fd/7 ] && [ "$cfmgr_health_opt_mount" -ef /proc/self/fd/6 ] || return 1
	cfmgr_health_mount_limit=$(((${#cfmgr_health_mount_snapshot} + 512) / 512))
	[ "$cfmgr_health_mount_limit" -le 8 ] || cfmgr_health_mount_limit=8
	if cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_opt"; then cfmgr_health_mount_status=0; else cfmgr_health_mount_status=$?; fi
	cfmgr_health_mount_limit=8
	[ "$cfmgr_health_mount_status" = 0 ] || return "$cfmgr_health_mount_status"
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS= read -r cfmgr_health_mount_current <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_mount_current" = "$cfmgr_health_mount_snapshot" ]
}

cfmgr_health_admit_entware() {
	case $1 in
	/opt/bin/jq) cfmgr_health_tool_saved=${cfmgr_health_entware_jq_path:-} cfmgr_health_tool_ok=${cfmgr_health_entware_jq_ok:-0} ;;
	/opt/bin/timeout) cfmgr_health_tool_saved=${cfmgr_health_entware_timeout_path:-} cfmgr_health_tool_ok=${cfmgr_health_entware_timeout_ok:-0} ;;
	/opt/bin/sha256sum) cfmgr_health_tool_saved=${cfmgr_health_entware_sha_path:-} cfmgr_health_tool_ok=${cfmgr_health_entware_sha_ok:-0} ;;
	/opt/bin/flock) cfmgr_health_tool_saved=${cfmgr_health_entware_flock_path:-} cfmgr_health_tool_ok=${cfmgr_health_entware_flock_ok:-0} ;;
	/opt/bin/dig) cfmgr_health_tool_saved=${cfmgr_health_entware_dig_path:-} cfmgr_health_tool_ok=${cfmgr_health_entware_dig_ok:-0} ;;
	*) return 2 ;;
	esac
	[ "${cfmgr_health_entware_ready:-0}" = 1 ] || return 1
	[ "$cfmgr_health_tool_ok" = 1 ] || return 1
	cfmgr_health_entware_attachment || return $?
	# Preserve the original logical argv[0], and recheck its canonical identity
	# immediately before use rather than assuming the earlier alias is unchanged.
	cfmgr_health_canonical "$1" "$cfmgr_health_tool_saved" || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_tool_saved" ] &&
		[ -f "$cfmgr_health_resolved" ] && [ ! -L "$cfmgr_health_resolved" ] && [ -x "$cfmgr_health_resolved" ]
}

# Native membership is fixed in BOTH the native LS stage and its validator.
# Missing/untrusted optional flock never holds independent TLS members.
cfmgr_health_native_metadata() {
	cfmgr_health_flock_kind=missing
	cfmgr_health_native_curl_ok=0 cfmgr_health_native_openssl_ok=0 cfmgr_health_native_ca_ok=0 cfmgr_health_native_flock_ok=0
	for cfmgr_health_native_member in curl openssl ca flock; do
		case $cfmgr_health_native_member in curl) cfmgr_health_native_path=$cfmgr_health_curl ;; openssl) cfmgr_health_native_path=$cfmgr_health_openssl ;; ca) cfmgr_health_native_path=$cfmgr_health_ca ;; flock) cfmgr_health_native_path=/usr/bin/flock ;; esac
		case $cfmgr_health_native_member in flock) cfmgr_health_native_expected='' ;; *) cfmgr_health_native_expected=$cfmgr_health_native_path ;; esac
		if cfmgr_health_canonical "$cfmgr_health_native_path" "$cfmgr_health_native_expected"; then :; else
			[ "$?" != 3 ] || return 3
			continue
		fi
		cfmgr_health_native_ok=0
		case $cfmgr_health_native_member:$cfmgr_health_resolved in
		flock:/bin/busybox)
			cfmgr_health_flock_kind=busybox
			[ ! -L /bin/busybox ] && [ -f /bin/busybox ] && [ -x /bin/busybox ] && cfmgr_health_native_ok=1
			;;
		*)
			[ "$cfmgr_health_resolved" = "$cfmgr_health_native_path" ] && [ -f "$cfmgr_health_native_path" ] && [ ! -L "$cfmgr_health_native_path" ] || continue
			case $cfmgr_health_native_member in ca) cfmgr_health_native_ok=1 ;; *) [ -x "$cfmgr_health_native_path" ] && cfmgr_health_native_ok=1 ;; esac
			[ "$cfmgr_health_native_member" != flock ] || cfmgr_health_flock_kind=regular
			;;
		esac
		case $cfmgr_health_native_member in curl) cfmgr_health_native_curl_ok=$cfmgr_health_native_ok ;; openssl) cfmgr_health_native_openssl_ok=$cfmgr_health_native_ok ;; ca) cfmgr_health_native_ca_ok=$cfmgr_health_native_ok ;; flock) cfmgr_health_native_flock_ok=$cfmgr_health_native_ok ;; esac
	done
	cfmgr_health_native_spec="$cfmgr_health_flock_kind $cfmgr_health_native_curl_ok $cfmgr_health_native_openssl_ok $cfmgr_health_native_ca_ok $cfmgr_health_native_flock_ok"
	cfmgr_health_run health-native-metadata /bin/ls "$cfmgr_health_flock_kind" || return $?
	case $cfmgr_probe_exit in 0 | 1 | 2) ;; *) return 1 ;; esac
	cfmgr_health_run health-metadata-check /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_probe_stdout" native "$cfmgr_health_native_spec" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_metadata_read native
}

cfmgr_health_metadata_read() {
	while IFS=' ' read -r cfmgr_health_meta_tag cfmgr_health_meta_member cfmgr_health_meta_ok; do
		case $1:$cfmgr_health_meta_tag:$cfmgr_health_meta_member in
		native:member:curl) cfmgr_health_native_curl_ok=$cfmgr_health_meta_ok ;;
		native:member:openssl) cfmgr_health_native_openssl_ok=$cfmgr_health_meta_ok ;;
		native:member:ca) cfmgr_health_native_ca_ok=$cfmgr_health_meta_ok ;;
		native:member:flock) cfmgr_health_native_flock_ok=$cfmgr_health_meta_ok ;;
		entware:member:storage) cfmgr_health_entware_storage_ok=$cfmgr_health_meta_ok ;;
		entware:member:jq) cfmgr_health_entware_jq_ok=$cfmgr_health_meta_ok ;;
		entware:member:timeout) cfmgr_health_entware_timeout_ok=$cfmgr_health_meta_ok ;;
		entware:member:sha) cfmgr_health_entware_sha_ok=$cfmgr_health_meta_ok ;;
		entware:member:flock) cfmgr_health_entware_flock_ok=$cfmgr_health_meta_ok ;;
		entware:member:dig) cfmgr_health_entware_dig_ok=$cfmgr_health_meta_ok ;;
		esac
	done <"$cfmgr_probe_stdout"
}

cfmgr_health_metadata_walk() {
	cfmgr_health_walk_member=$1 cfmgr_health_walk_path=$2 cfmgr_health_walk_kind=$3
	while :; do
		[ ! -L "$cfmgr_health_walk_path" ] || return 1
		cfmgr_health_metadata_spec="$cfmgr_health_metadata_spec
$cfmgr_health_walk_member	$cfmgr_health_walk_kind	$cfmgr_health_walk_path"
		if [ "${#cfmgr_health_metadata_spec}" -gt 32768 ]; then
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		fi
		case "$cfmgr_health_metadata_paths
" in *"
$cfmgr_health_walk_path
"*) ;;
		*)
			cfmgr_health_metadata_members=$((cfmgr_health_metadata_members + 1))
			if [ "$cfmgr_health_metadata_members" -gt 13 ]; then
				cfmgr_health_incomplete=1 cfmgr_health_reason=budget
				return 1
			fi
			cfmgr_health_metadata_paths="$cfmgr_health_metadata_paths
$cfmgr_health_walk_path"
			;;
		esac
		[ "$cfmgr_health_walk_path" != "$cfmgr_health_opt_mount" ] || return 0
		[ "$cfmgr_health_walk_path" != / ] || return 1
		cfmgr_health_walk_path=${cfmgr_health_walk_path%/*}
		[ -n "$cfmgr_health_walk_path" ] || cfmgr_health_walk_path=/
		cfmgr_health_walk_kind=directory
	done
}

cfmgr_health_entware_metadata() {
	cfmgr_health_metadata_spec='' cfmgr_health_metadata_paths='' cfmgr_health_metadata_members=0
	cfmgr_health_entware_storage_ok=0 cfmgr_health_entware_jq_ok=0 cfmgr_health_entware_timeout_ok=0 cfmgr_health_entware_sha_ok=0 cfmgr_health_entware_flock_ok=0 cfmgr_health_entware_dig_ok=0
	cfmgr_health_metadata_walk storage "$cfmgr_health_opt" directory || return $?
	for cfmgr_health_tool_member in jq timeout sha flock dig; do
		case $cfmgr_health_tool_member in sha) cfmgr_health_tool_logical=/opt/bin/sha256sum ;; *) cfmgr_health_tool_logical=/opt/bin/$cfmgr_health_tool_member ;; esac
		cfmgr_health_resolved=''
		if cfmgr_health_canonical "$cfmgr_health_tool_logical"; then
			case $cfmgr_health_resolved in "$cfmgr_health_opt"/*)
				if [ -f "$cfmgr_health_resolved" ] && [ -x "$cfmgr_health_resolved" ]; then
					cfmgr_health_metadata_walk "$cfmgr_health_tool_member" "$cfmgr_health_resolved" file || return $?
				else cfmgr_health_resolved=''; fi
				;;
			*) cfmgr_health_resolved='' ;;
			esac
		else
			[ "$?" != 3 ] || return 3
			cfmgr_health_resolved=''
		fi
		case $cfmgr_health_tool_member in jq) cfmgr_health_entware_jq_path=$cfmgr_health_resolved ;; timeout) cfmgr_health_entware_timeout_path=$cfmgr_health_resolved ;; sha) cfmgr_health_entware_sha_path=$cfmgr_health_resolved ;; flock) cfmgr_health_entware_flock_path=$cfmgr_health_resolved ;; dig) cfmgr_health_entware_dig_path=$cfmgr_health_resolved ;; esac
	done
	set --
	while IFS= read -r cfmgr_health_meta_path; do
		[ -z "$cfmgr_health_meta_path" ] || set -- "$@" "$cfmgr_health_meta_path"
	done <<EOF_HEALTH_PATHS
$cfmgr_health_metadata_paths
EOF_HEALTH_PATHS
	cfmgr_health_entware_bytes=0
	for cfmgr_health_meta_path; do cfmgr_health_entware_bytes=$((cfmgr_health_entware_bytes + ${#cfmgr_health_meta_path} + 256)); done
	cfmgr_health_entware_limit=$(((cfmgr_health_entware_bytes + 511) / 512))
	[ "$cfmgr_health_entware_limit" -le 128 ] || cfmgr_health_entware_limit=128
	if cfmgr_health_run health-entware-metadata /bin/ls "$@"; then cfmgr_health_entware_status=0; else cfmgr_health_entware_status=$?; fi
	cfmgr_health_entware_limit=128
	[ "$cfmgr_health_entware_status" = 0 ] || return "$cfmgr_health_entware_status"
	case $cfmgr_probe_exit in 0 | 1 | 2) ;; *) return 1 ;; esac
	cfmgr_health_run health-metadata-check /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_probe_stdout" entware "$cfmgr_health_metadata_spec" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_metadata_read entware || return $?
	[ "$cfmgr_health_entware_storage_ok" = 1 ]
}

cfmgr_health_entware() {
	cfmgr_health_entware_ready=0
	cfmgr_health_canonical /opt || return $?
	cfmgr_health_opt=$cfmgr_health_resolved
	cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_opt" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_mount_file=$cfmgr_probe_stdout
	IFS= read -r cfmgr_health_mount_snapshot <"$cfmgr_health_mount_file" || return 1
	cfmgr_health_run health-storage /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_health_mount_file" "$cfmgr_health_inventory" "$cfmgr_health_opt" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS='	' read -r cfmgr_health_opt_uuid cfmgr_health_opt_fs cfmgr_health_opt_device cfmgr_health_opt_mount <"$cfmgr_probe_stdout" || return 1
	cfmgr_health_canonical "$cfmgr_health_opt_mount" "$cfmgr_health_opt_mount" || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_opt_mount" ] || return 1
	exec 6<"$cfmgr_health_opt_mount" 7<"$cfmgr_health_opt" || return 1
	cfmgr_health_run health-blkid /sbin/blkid "$cfmgr_health_opt_device" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_run health-uuid /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_probe_stdout" "$cfmgr_health_opt_device" "$cfmgr_health_opt_fs" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS= read -r cfmgr_health_current_uuid <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_current_uuid" = "$cfmgr_health_opt_uuid" ] || return 1
	cfmgr_health_entware_attachment || return $?
	cfmgr_health_entware_metadata || return $?
	cfmgr_health_entware_ready=1
}

cfmgr_health_observe() {
	# Public IDs contain only feature/kind/ordinal, never configured identities.
	cfmgr_health_observation_id=$1 cfmgr_health_compare_deferred=0
	shift
	if cfmgr_health_get "$@"; then
		IFS=' ' read -r cfmgr_health_marker cfmgr_health_version cfmgr_health_observed cfmgr_health_matches cfmgr_health_evidence cfmgr_health_end <"$cfmgr_health_result_file" || return 1
		case $2:$cfmgr_health_version in
		dns:2)
			if cfmgr_health_comparison_keep DNS "${cfmgr_health_observation_id##*.}" "$cfmgr_health_compare_dns_family" "$cfmgr_health_result_file"; then cfmgr_health_compare_deferred=1; fi
			;;
		items:2)
			case $3 in primary) cfmgr_health_compare_ordinal=1 ;; secondary) cfmgr_health_compare_ordinal=2 ;; *) return 2 ;; esac
			if cfmgr_health_comparison_keep ITEMS "$cfmgr_health_compare_ordinal" - "$cfmgr_health_result_file"; then cfmgr_health_compare_deferred=1; fi
			;;
		trace:1)
			case $4 in 4) cfmgr_health_compare_ordinal=1 ;; 6) cfmgr_health_compare_ordinal=2 ;; esac
			cfmgr_health_comparison_keep TRACE "$cfmgr_health_compare_ordinal" "$4" "$cfmgr_health_result_file" || :
			;;
		esac
		case $cfmgr_health_observed:$2:$cfmgr_health_matches in
		partial:*) cfmgr_health_observation_state=UNKNOWN cfmgr_health_observation_detail='Only a partial provider page was verified; absence is unproved.' ;;
		*:dns:0) cfmgr_health_observation_state=WARN cfmgr_health_observation_detail='The complete bounded page contained no exact DNS match.' ;;
		*:dns:1) cfmgr_health_observation_state=PASS cfmgr_health_observation_detail='One exact DNS record was read; publication and write permission remain unproved.' ;;
		*:dns:*) cfmgr_health_observation_state=WARN cfmgr_health_observation_detail='Multiple exact DNS records were read; review duplicate targets.' ;;
		*:items:0) cfmgr_health_observation_state=WARN cfmgr_health_observation_detail='The complete bounded list page was empty; configured family membership remains unproved.' ;;
		*:items:*) cfmgr_health_observation_state=PASS cfmgr_health_observation_detail='A complete bounded list page was read; per-family membership and write permission remain unproved.' ;;
		*:connections:0) cfmgr_health_observation_state=WARN cfmgr_health_observation_detail='No connections were returned; runtime authentication and service readiness remain unproved.' ;;
		*:connections:*) cfmgr_health_observation_state=PASS cfmgr_health_observation_detail='Provider connections were read; local runtime authentication and readiness remain unproved.' ;;
		*:trace:*) cfmgr_health_observation_state=PASS cfmgr_health_observation_detail="Current egress observation: ${cfmgr_health_evidence#*:}. This does not prove traffic used the selected WAN." ;;
		*) cfmgr_health_observation_state=PASS cfmgr_health_observation_detail='The exact configured resource was read; write permission remains unproved.' ;;
		esac
	else
		cfmgr_health_observation_code=$?
		[ "$cfmgr_health_observation_code" != 3 ] || return 3
		cfmgr_health_observation_state=UNKNOWN
		case $cfmgr_health_result in
		auth-rejected-read) cfmgr_health_observation_detail='This credential reference and resource rejected the read; other scopes remain independent.' ;;
		provider-throttle) cfmgr_health_observation_state=SKIP cfmgr_health_observation_detail='The provider throttled this report; remaining provider reads are skipped.' ;;
		prerequisite-blocked | scope-auth-hold | unconfigured) cfmgr_health_observation_state=SKIP cfmgr_health_observation_detail='This read depends on an available shared transport, current clock, and an unheld configured scope.' ;;
		historical-*) cfmgr_health_observation_state=SKIP cfmgr_health_observation_detail='Retained historical authentication or throttle evidence holds this feature; no live authentication verdict.' ;;
		*) cfmgr_health_observation_detail='The bounded read was unavailable or unverified; no absence or write-permission claim.' ;;
		esac
	fi
	# An eligible local API scope is sufficient; a transient provider failure
	# does not disqualify public diagnostics. Auth holds are filtered after the
	# complete API schedule, so a later DNS rejection also holds its zone scope.
	if [ "${cfmgr_health_scope_eligible:-0}" = 1 ] && [ "$2" != trace ]; then
		cfmgr_health_candidates="$cfmgr_health_candidates
$1 $cfmgr_health_scope"
	fi
	[ "$cfmgr_health_compare_deferred" = 0 ] || return 0
	cfmgr_health_row "$cfmgr_health_observation_id" "$cfmgr_health_observation_state" "$cfmgr_health_observation_detail" current 'Review configured resource and read permissions.' transport
}

cfmgr_health_provider_collect() {
	cfmgr_health_public_feature='' cfmgr_health_dns_index=0 cfmgr_health_candidates=''
	cfmgr_health_compare_count=0 cfmgr_health_compare_pending=''
	cfmgr_health_compare_primary4=0 cfmgr_health_compare_primary6=0 cfmgr_health_compare_secondary4=0 cfmgr_health_compare_secondary6=0
	cfmgr_health_ddns_schedule=0 cfmgr_health_sync_schedule=0
	while IFS=' ' read -r cfmgr_health_tag cfmgr_health_feature cfmgr_health_a cfmgr_health_b cfmgr_health_c; do
		case $cfmgr_health_tag in
		feature)
			[ "$cfmgr_health_a" = 1 ] || continue
			if [ "$cfmgr_health_c" != eligible ]; then
				cfmgr_health_row "$cfmgr_health_feature.provider" SKIP 'Retained historical evidence holds this feature; no provider request was made.' historical 'Review retained feature history before an explicit retry.' config || return $?
				continue
			fi
			case $cfmgr_health_feature in ddns) cfmgr_health_ddns_schedule=1 cfmgr_health_kind=zone ;; ip_sync)
				cfmgr_health_sync_schedule=1
				continue
				;;
			cloudflared) cfmgr_health_kind=tunnel ;; esac
			cfmgr_health_observe "$cfmgr_health_feature.$cfmgr_health_kind" "$cfmgr_health_feature" "$cfmgr_health_kind" - 4 || return $?
			[ "$cfmgr_health_feature" != cloudflared ] || cfmgr_health_observe cloudflared.connections cloudflared connections - 4 || return $?
			;;
		target)
			case $cfmgr_health_feature in
			ddns)
				[ "$cfmgr_health_ddns_schedule" = 1 ] || continue
				cfmgr_health_dns_index=$((cfmgr_health_dns_index + 1))
				cfmgr_health_compare_dns_family=$cfmgr_health_c
				# API transport uses IPv4 independently of the record address family.
				cfmgr_health_observe "ddns.record.$cfmgr_health_dns_index" ddns dns "$cfmgr_health_b" 4 || return $?
				;;
			ip_sync)
				[ "$cfmgr_health_sync_schedule" = 1 ] || continue
				cfmgr_health_observe "ip_sync.$cfmgr_health_b.list" ip_sync list "$cfmgr_health_b" 4 || return $?
				cfmgr_health_observe "ip_sync.$cfmgr_health_b.items" ip_sync items "$cfmgr_health_b" 4 || return $?
				;;
			esac
			;;
		family)
			[ "$cfmgr_health_sync_schedule" = 1 ] || continue
			case $cfmgr_health_a:$cfmgr_health_b in
			primary:ipv4) cfmgr_health_compare_primary4=1 ;; primary:ipv6) cfmgr_health_compare_primary6=1 ;;
			secondary:ipv4) cfmgr_health_compare_secondary4=1 ;; secondary:ipv6) cfmgr_health_compare_secondary6=1 ;;
			esac
			;;
		additional) [ "$cfmgr_health_a" = 0 ] || cfmgr_health_row ddns.additional UNKNOWN 'Additional configured DNS targets exceed the first-three read schedule.' current 'Inspect remaining configured targets separately.' ddns || return $? ;;
		esac
	done <"$cfmgr_health_inventory"
	while IFS=' ' read -r cfmgr_health_candidate cfmgr_health_candidate_scope; do
		case $cfmgr_health_candidate in ddns | ip_sync | cloudflared) ;; *) continue ;; esac
		case "$cfmgr_health_scope_holds
" in *"
$cfmgr_health_candidate_scope
"*) continue ;; esac
		cfmgr_health_public_feature=$cfmgr_health_candidate
		break
	done <<EOF_HEALTH_CANDIDATES
$cfmgr_health_candidates
EOF_HEALTH_CANDIDATES
	if [ -z "$cfmgr_health_public_feature" ]; then
		cfmgr_health_row network.public4 SKIP 'No locally validated configured API scope remains eligible and unheld for public discovery.' current 'Review configured scopes and retained authentication evidence.' config || return $?
		cfmgr_health_row network.public6 SKIP 'No locally validated configured API scope remains eligible and unheld for public discovery.' current 'Review configured scopes and retained authentication evidence.' config || return $?
		cfmgr_health_comparison_finish
		return $?
	fi
	cfmgr_health_public_eligible=1
	cfmgr_health_observe network.public4 "$cfmgr_health_public_feature" trace - 4 || return $?
	if [ "$cfmgr_health_ipv6_ready" = 1 ]; then
		cfmgr_health_observe network.public6 "$cfmgr_health_public_feature" trace - 6 || return $?
	else
		cfmgr_health_row network.public6 SKIP 'No current usable global IPv6 address was proved on the selected WAN interface.' current 'Check selected WAN IPv6 configuration.' network || return $?
	fi
	cfmgr_health_comparison_finish
}

cfmgr_health_collect() {
	cfmgr_health_row package.extension PASS 'Diagnostic dependency closure matches the trusted entry generation.' current 'None.' package || return $?
	cfmgr_health_row system.context PASS 'The report uses an attached private RAM context and the admitted native supervisor.' current 'None.' system || return $?
	if [ "${cfmgr_status_setup_ready:-0}" = 1 ]; then
		cfmgr_health_row system.setup PASS 'Retained setup completion framing was verified from the local snapshot.' current 'None.' system
	else
		cfmgr_health_row system.setup FAIL 'Retained setup completion was not verified.' current 'Use explicit package recovery.' system
	fi || return $?
	cfmgr_health_recovery_collect || return $?
	for cfmgr_health_member in backup manager package catalog; do
		case $cfmgr_health_member in
		backup) cfmgr_health_member_state=${cfmgr_health_backup:-missing} ;;
		manager) cfmgr_health_member_state=${cfmgr_health_manager:-missing} ;;
		package) cfmgr_health_member_state=${cfmgr_health_package:-missing} ;;
		catalog) cfmgr_health_member_state=${cfmgr_health_catalog:-missing} ;;
		esac
		case $cfmgr_health_member_state in
		verified) cfmgr_health_row "package.$cfmgr_health_member" PASS 'This fixed component matches the admitted manifest; complete-package inventory remains separate.' current 'None.' package ;;
		*) cfmgr_health_row "package.$cfmgr_health_member" FAIL 'This fixed normal-launch component is missing or untrusted.' current 'Recover the complete trusted package.' package ;;
		esac || return $?
	done
	cfmgr_health_clock_ready=$cfmgr_status_clock
	if [ "$cfmgr_status_clock" = 1 ]; then
		cfmgr_health_row system.clock PASS 'Current native NTP readiness is set.' current 'None.' system
	else
		cfmgr_health_row system.clock WARN 'Current native NTP readiness was not proved; all GETs are blocked.' current 'Restore router NTP readiness.' system
	fi || return $?
	if cfmgr_health_run health-uname /bin/uname && [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then
		IFS= read -r cfmgr_health_machine <"$cfmgr_probe_stdout"
		case $cfmgr_health_machine in armv7l | aarch64)
			cfmgr_health_row system.architecture PASS "Native kernel architecture: $cfmgr_health_machine; executable ABI compatibility requires the tool probes below." current 'None.' system
			;;
		*) cfmgr_health_row system.architecture UNKNOWN 'The native architecture was not recognized as an admitted router target.' current 'Review supported firmware and executable ABI.' system ;;
		esac
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row system.architecture UNKNOWN 'Native architecture evidence was unavailable.' current 'Review native command prerequisites.' system
	fi || return $?
	cfmgr_health_config=$cfmgr_status_config cfmgr_health_config_bytes=${cfmgr_status_config_bytes:-0}
	cfmgr_health_inventory=''
	if [ "$cfmgr_health_config" != unavailable ] && cfmgr_health_project health-inventory ddns zone - 4 &&
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then
		cfmgr_health_inventory=$cfmgr_probe_stdout
		cfmgr_health_row config.authority PASS 'The retained snapshot passed complete schema-2 validation; no configuration was reread.' current 'None.' config || return $?
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row config.authority UNKNOWN 'The retained snapshot is missing, legacy, invalid, or could not be projected within the report budget; config-dependent reads remain local-only.' current 'Recover or migrate retained settings; review report limits.' config || return $?
	fi
	cfmgr_health_native_admitted=1
	cfmgr_health_curl=/usr/sbin/curl cfmgr_health_openssl=/usr/sbin/openssl cfmgr_health_ca=/rom/etc/ssl/certs/ca-certificates.crt
	if cfmgr_health_native_metadata; then :; else
		[ "$?" != 3 ] || return 3
		cfmgr_health_native_curl_ok=0 cfmgr_health_native_openssl_ok=0 cfmgr_health_native_ca_ok=0 cfmgr_health_native_flock_ok=0
	fi
	for cfmgr_health_native_member in curl openssl ca; do
		case $cfmgr_health_native_member in curl) cfmgr_health_native_ok=$cfmgr_health_native_curl_ok ;; openssl) cfmgr_health_native_ok=$cfmgr_health_native_openssl_ok ;; ca) cfmgr_health_native_ok=$cfmgr_health_native_ca_ok ;; esac
		if [ "$cfmgr_health_native_ok" = 1 ]; then
			cfmgr_health_row "native.$cfmgr_health_native_member" PASS 'Fixed native path and ancestry are root-protected.' current 'None.' native
		else
			cfmgr_health_native_admitted=0
			cfmgr_health_row "native.$cfmgr_health_native_member" FAIL 'Fixed native path or protected ancestry could not be admitted.' current 'Recover native firmware prerequisites.' native
		fi || return $?
	done
	cfmgr_health_package_collect || return $?
	if [ "$cfmgr_health_native_admitted" = 1 ] && cfmgr_health_tls_check; then
		cfmgr_health_row transport.tls PASS 'Read-only native TLS, CA parsing, and fixed curl policy probes passed offline.' current 'None.' native
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row transport.tls SKIP 'A shared native TLS prerequisite failed; provider reads are unavailable.' current 'Review native curl, OpenSSL and CA evidence.' native
	fi || return $?
	cfmgr_health_entware_ready=0
	if [ -n "$cfmgr_health_inventory" ] && cfmgr_health_entware; then
		cfmgr_health_row storage.entware PASS 'The mounted UUID, filesystem, filesystem root and relative Entware path match retained identity.' current 'None.' storage || return $?
		cfmgr_health_native_flock=-
		[ "$cfmgr_health_native_flock_ok" != 1 ] || cfmgr_health_native_flock=/usr/bin/flock
		if cfmgr_prerequisites_check tunnel "$cfmgr_status_context" /bin/sh "$cfmgr_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_health_native_flock" /opt/bin/jq /opt/bin/timeout /opt/bin/sha256sum /opt/bin/flock /opt/bin/dig unknown; then :; else [ "$?" != 3 ] || return 3; fi
		for cfmgr_health_capability in jq timeout sha flock dns; do
			case $cfmgr_health_capability in jq) cfmgr_health_capability_result=$cfmgr_prereq_jq ;; timeout) cfmgr_health_capability_result=$cfmgr_prereq_timeout ;; sha) cfmgr_health_capability_result=$cfmgr_prereq_sha ;; flock) cfmgr_health_capability_result=$cfmgr_prereq_flock ;; dns) cfmgr_health_capability_result=$cfmgr_prereq_dns ;; esac
			case $cfmgr_health_capability_result in usable | dig-executable) cfmgr_health_capability_state=PASS ;; *) cfmgr_health_capability_state=FAIL ;; esac
			cfmgr_health_row "prerequisite.$cfmgr_health_capability" "$cfmgr_health_capability_state" 'Protected tool admission and the existing finite capability probe determine this result; DNS is executable-only, not live SRV/A proof.' current 'Review prerequisites; health performs no repair.' storage || return $?
		done
		cfmgr_health_entware_attachment || {
			[ "$?" != 3 ] || return 3
			cfmgr_health_row storage.attachment FAIL 'The pinned Entware attachment changed during capability probes.' current 'Recover the retained mounted identity.' storage || return $?
		}
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row storage.entware UNKNOWN 'Protected mounted Entware identity was not proved; Entware executables were not admitted.' current 'Review retained storage identity and mount permissions.' storage || return $?
		cfmgr_health_row prerequisite.entware SKIP 'Entware capability checks depend on protected mounted identity.' current 'Resolve storage evidence first.' storage || return $?
	fi
	cfmgr_health_cloud_collect || return $?
	cfmgr_health_logging_collect || return $?
	cfmgr_health_hooks_collect || return $?
	cfmgr_health_backup_collect || return $?
	# Storage observation descriptors must never alias the private curl request.
	exec 6<&- 7<&-
	cfmgr_health_ipv6_ready=0
	if cfmgr_health_run health-current /usr/bin/awk "$cfmgr_source/modules/status.sh" /proc/net/if_inet6 "${cfmgr_status_interface:-unknown}" - &&
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then cfmgr_health_ipv6_ready=1; else [ "$?" != 3 ] || return 3; fi
	if [ -n "$cfmgr_health_inventory" ] && [ "$cfmgr_health_transport" = ready ] && [ "$cfmgr_health_clock_ready" = 1 ]; then
		cfmgr_health_provider_collect || return $?
	else
		cfmgr_health_row provider.reads SKIP 'Provider reads depend on valid schema-2 scope, current NTP and admitted native TLS.' current 'Resolve shared prerequisites first.' transport || return $?
	fi
	if [ "$cfmgr_health_incomplete" = 1 ]; then
		cfmgr_health_row report.budget UNKNOWN 'The collection resource or time budget was exhausted; remaining observations are incomplete.' current 'Review earlier prerequisite failures and retry.' report || return $?
	fi
}

cfmgr_health_session() {
	cfmgr_health_protected_cache='' cfmgr_health_staging=0
	cfmgr_health_stage_reserve dashboard 32768 && cfmgr_health_stage_reserve rows 262144 || return 1
	cfmgr_health_dashboard=$cfmgr_status_context/dashboard cfmgr_health_row_file=$cfmgr_status_context/rows
	cfmgr_health_saved_limit=$(ulimit -S -f) || return 1
	cfmgr_health_limit_hit=0
	trap 'cfmgr_health_limit_hit=1' XFSZ
	ulimit -S -f 32 || return 1
	cfmgr_status_page=full
	if cfmgr_status_work >"$cfmgr_health_dashboard"; then cfmgr_health_code=0; else cfmgr_health_code=$?; fi
	ulimit -S -f "$cfmgr_health_saved_limit" || return 1
	[ "$cfmgr_health_code" != 3 ] || return 3
	[ "$cfmgr_health_limit_hit" = 0 ] || cfmgr_health_code=1
	cfmgr_health_count "$cfmgr_health_dashboard" 16384 || cfmgr_health_code=$?
	[ "$cfmgr_health_code" != 3 ] || return 3
	if [ "$cfmgr_health_code" != 0 ]; then
		cfmgr_status_row report.local UNKNOWN 'The local dashboard exceeded its budget or could not be collected.' current 'Retry after checking local prerequisites.' report
		return 1
	fi
	# FD3 remains bounded while later children restore their own per-mode quotas.
	ulimit -S -f 256 || return 1
	(
		set -C
		: >"$cfmgr_health_row_file"
	) || return 1
	exec 3>"$cfmgr_health_row_file" || return 1
	cfmgr_health_staging=1
	if cfmgr_health_collect; then cfmgr_health_code=0; else cfmgr_health_code=$?; fi
	[ "$cfmgr_health_code" != 3 ] || return 3
	exec 3>&-
	ulimit -S -f "$cfmgr_health_saved_limit" || return 1
	exec 6<&- 7<&-
	if cfmgr_health_finalize "$cfmgr_health_dashboard" "$cfmgr_health_row_file"; then :; else
		cfmgr_health_code=$?
		[ "$cfmgr_health_code" != 3 ] || return 3
		cfmgr_status_render_unavailable
		cfmgr_health_code=1
	fi
	return "$cfmgr_health_code"
}

cfmgr_status_health_native() (
	set +f
	cfmgr_health_capture_done=0
	if [ "${cfmgr_log_available:-0}" = 1 ]; then cfmgr_log_collect status health; fi
	if cfmgr_health_begin; then :; else
		cfmgr_health_code=$?
		if [ "${cfmgr_log_available:-0}" = 1 ]; then cfmgr_log_health - 0 failed; fi
		exit "$cfmgr_health_code"
	fi
	if cfmgr_health_session; then cfmgr_health_code=0; else cfmgr_health_code=$?; fi
	if [ "${cfmgr_log_available:-0}:$cfmgr_health_capture_done" = 1:0 ]; then cfmgr_log_health - 0 failed; fi
	[ "$cfmgr_health_code" != 3 ] || exit 3
	exec 3>&- 4>&- 5>&- 6<&- 7<&-
	cfmgr_status_interrupted=0
	cfmgr_health_cleanup || exit $?
	exit "$cfmgr_health_code"
)

cfmgr_status_attachment_ok() {
	case ${cfmgr_status_interrupted:-0} in 0) ;; *) return 1 ;; esac
	[ ! -L "$cfmgr_status_context" ] && [ "$cfmgr_status_context" -ef /proc/self/fd/9 ]
}

cfmgr_status_run() {
	cfmgr_status_mode=$1 cfmgr_status_tool=$2
	shift 2
	case ${cfmgr_health_active:-0} in 1)
		cfmgr_health_run "health-${cfmgr_status_mode#status-}" "$cfmgr_status_tool" "$@" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
		return $?
		;;
	esac
	case $cfmgr_status_mode in status-render | status-render-count) ;;
	*)
		[ -z "${cfmgr_status_final_deadline:-}" ] || return 1
		cfmgr_prerequisites_now || return 2
		if [ "$cfmgr_probe_now" -ge "$cfmgr_status_deadline" ]; then
			cfmgr_status_budget_exhausted=1
			return 1
		fi
		;;
	esac
	cfmgr_prerequisites_run "$cfmgr_status_mode" "$cfmgr_status_context" /bin/sh \
		"$cfmgr_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_status_tool" "$@" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_status_final_begin() {
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	if [ -z "${cfmgr_status_final_deadline:-}" ]; then
		cfmgr_status_final_deadline=$((cfmgr_probe_now + 3))
		[ "$cfmgr_status_final_deadline" -le "$((cfmgr_status_deadline + 3))" ] || cfmgr_status_final_deadline=$((cfmgr_status_deadline + 3))
	fi
}

cfmgr_status_final_reserve() {
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	[ -n "${cfmgr_status_final_deadline:-}" ] && [ "$cfmgr_probe_now" -lt "$cfmgr_status_final_deadline" ] &&
		[ "${cfmgr_status_final_operations:-0}" -lt 3 ] || return 1
	cfmgr_status_final_operations=$((${cfmgr_status_final_operations:-0} + 1))
}

cfmgr_status_render_unavailable() {
	# No staging bytes are replayed when validation or rendering fails.
	/usr/bin/printf '%s\n' Report not available Check local status
}

cfmgr_status_cleanup() {
	cfmgr_status_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "$cfmgr_probe_status" = reaped ] || return 1
	cfmgr_status_count=0
	for cfmgr_status_file in "$cfmgr_status_context"/*; do
		[ -e "$cfmgr_status_file" ] || continue
		[ -f "$cfmgr_status_file" ] && [ ! -L "$cfmgr_status_file" ] || return 1
		cfmgr_status_count=$((cfmgr_status_count + 1))
		[ "$cfmgr_status_count" -le 104 ] || return 1
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
	cfmgr_status_mount=$(cfmgr_storage_mountinfo /usr/bin/awk /tmp /proc/self/mountinfo) || return 1
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
	cfmgr_status_final_deadline='' cfmgr_status_final_operations=0
	trap 'cfmgr_status_interrupted=1' HUP INT TERM
}

cfmgr_status_native() (
	if [ "${cfmgr_log_available:-0}" = 1 ]; then cfmgr_log_begin status "status"; fi
	if _cfmgr_status_native_work "$@"; then cfmgr_log_operation_code=0; else cfmgr_log_operation_code=$?; fi
	if [ "${cfmgr_log_available:-0}" = 1 ]; then
		case $cfmgr_log_operation_code in
		0) cfmgr_log_finish success 0 ;;
		3) cfmgr_log_finish unresolved 3 ;;
		*) cfmgr_log_finish failure "$cfmgr_log_operation_code" ;;
		esac
	fi
	exit "$cfmgr_log_operation_code"
)

# shellcheck disable=SC3045 # Native BusyBox report/core limits are required and tested.
_cfmgr_status_native_work() {
	ulimit -c 0 || return 1
	cfmgr_health_active=0 cfmgr_status_page=basic
	for cfmgr_status_path in "$cfmgr_source/modules/helpers/worker.sh" "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_source/modules/lib/storage.sh"; do
		if [ ! -f "$cfmgr_status_path" ] || [ -L "$cfmgr_status_path" ] ||
			! /usr/bin/awk 'NR!=1 || $3!=0 || $1!~/^-/ || substr($1,6,1)=="w" || substr($1,9,1)=="w" { bad=1 } END { exit NR!=1 || bad }' <<EOF_STATUS_METADATA; then
$(/bin/ls -ldn "$cfmgr_status_path")
EOF_STATUS_METADATA
			printf '[CFMGR] status: warning: required native reporting module unavailable\n'
			return 1
		fi
	done
	cfmgr_status_prepare || {
		printf '[CFMGR] status: warning: native report context unavailable\n'
		return 1
	}
	cfmgr_status_dashboard=$cfmgr_status_context/dashboard
	(
		umask 077
		set -C
		: >"$cfmgr_status_dashboard"
	) || {
		printf '[CFMGR] status: warning: local dashboard staging unavailable\n'
		return 1
	}
	cfmgr_status_saved_limit=$(ulimit -S -f) || return 1
	cfmgr_status_limit_hit=0
	trap 'cfmgr_status_limit_hit=1' XFSZ
	ulimit -S -f 32 || return 1
	if cfmgr_status_work >"$cfmgr_status_dashboard"; then cfmgr_status_code=0; else cfmgr_status_code=$?; fi
	ulimit -S -f "$cfmgr_status_saved_limit" || return 1
	if [ "$cfmgr_status_code" = 3 ]; then
		printf '[CFMGR] status: error: owned probe unresolved; report cleanup required\n'
		return 3
	fi
	cfmgr_status_render_ready=0
	if cfmgr_status_final_begin && [ "$cfmgr_status_limit_hit" = 0 ] && cfmgr_status_count_dashboard "$cfmgr_status_dashboard"; then
		cfmgr_status_render_ready=1
	else
		cfmgr_status_code=$?
		[ "$cfmgr_status_code" != 3 ] || return 3
		cfmgr_status_code=1
	fi
	if [ "$cfmgr_status_render_ready" = 1 ]; then
		if cfmgr_status_render "$cfmgr_status_dashboard" -; then :; else
			cfmgr_status_code=$?
			[ "$cfmgr_status_code" != 3 ] || return 3
			cfmgr_status_render_unavailable
			cfmgr_status_code=1
		fi
	else
		cfmgr_status_render_unavailable
	fi
	# A signal prevents further collection but reaped children permit cleanup.
	cfmgr_status_interrupted=0
	cfmgr_status_cleanup || {
		printf '[CFMGR] status: warning: report cleanup required\n'
		return 1
	}
	return "$cfmgr_status_code"
}

cfmgr_status_work() {
	case ${cfmgr_status_page:-basic} in full) ;; *) printf '\nCFMgr %s - local status\n' "$CFMGR_VERSION" ;; esac
	# Each independent failure retains the remaining native/local report.
	cfmgr_status_now=0 cfmgr_status_boot=unknown cfmgr_status_wan=auto cfmgr_status_clock=0 cfmgr_status_interface=unknown
	if cfmgr_status_run status-date /bin/date; then
		IFS= read -r cfmgr_status_now <"$cfmgr_probe_stdout"
		case $cfmgr_status_now in '' | *[!0-9]* | 0*) cfmgr_status_now=0 ;; esac
	elif [ "$?" = 3 ]; then return 3; fi
	if cfmgr_status_run status-native /usr/bin/awk "$cfmgr_source/modules/status.sh" /proc; then
		cfmgr_status_native_output=$cfmgr_probe_stdout
		# Typed receipts contain only allowlisted native resource fields.
		while IFS='	' read -r cfmgr_status_key cfmgr_status_value; do
			case $cfmgr_status_key in
			boot) cfmgr_status_boot=$cfmgr_status_value ;;
			uptime | load | memory) case ${cfmgr_status_page:-basic} in full) ;; *) printf '%s: %s\n' "$cfmgr_status_key" "$cfmgr_status_value" ;; esac ;;
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
	cfmgr_status_setup_ready=0
	if cfmgr_status_snapshot "$cfmgr_source/setup-state" &&
		cfmgr_status_fields setup "$cfmgr_status_snapshot_file" "$CFMGR_VERSION"; then
		cfmgr_status_setup_ready=1
		printf 'Installation: retained setup complete\n'
	else
		[ "$?" != 3 ] || return 3
		printf 'Issue: retained setup incomplete/unavailable; use recovery\n'
	fi
	cfmgr_status_storage_observation=0
	if cfmgr_status_run status-metadata /bin/ls "$cfmgr_source/.storage-observation"; then
		cfmgr_status_storage_observation=1
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
	case ${cfmgr_status_page:-basic} in full) printf 'The local dashboard above uses local evidence; subsequent checks may perform read-only GETs.\n\n' ;; *) printf 'Status uses local evidence; no network or feature action was performed.\n\n' ;; esac
}

cfmgr_health_render_width() {
	cfmgr_status_width=${COLUMNS:-64}
	case $cfmgr_status_width in '' | 0?* | *[!0-9]*) cfmgr_status_width=64 ;; esac
	[ "${#cfmgr_status_width}" -le 3 ] || cfmgr_status_width=64
	[ "$cfmgr_status_width" -ge 10 ] || cfmgr_status_width=10
	[ "$cfmgr_status_width" -le 100 ] || cfmgr_status_width=100
}

cfmgr_status_count_dashboard() {
	cfmgr_status_run status-render-count /usr/bin/wc "$1" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_status_dashboard_bytes cfmgr_status_dashboard_extra <"$cfmgr_probe_stdout" || return 1
	case $cfmgr_status_dashboard_bytes in '' | *[!0-9]* | 0?*) return 1 ;; esac
	[ -z "$cfmgr_status_dashboard_extra" ] && [ "$cfmgr_status_dashboard_bytes" -le 16384 ]
}

cfmgr_status_render() {
	[ "$#" = 2 ] || return 2
	cfmgr_health_render_width
	cfmgr_status_run status-render /usr/bin/awk "$cfmgr_source/modules/status.sh" "$1" "$2" "$cfmgr_status_width" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_status_attachment_ok && [ -f "$cfmgr_probe_stdout" ] && [ ! -L "$cfmgr_probe_stdout" ] || return 1
	cfmgr_status_render_output=$cfmgr_probe_stdout
	cfmgr_status_run status-render-count /usr/bin/wc "$cfmgr_status_render_output" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_status_render_bytes cfmgr_status_render_extra <"$cfmgr_probe_stdout" || return 1
	case $cfmgr_status_render_bytes in '' | *[!0-9]* | 0?*) return 1 ;; esac
	[ -z "$cfmgr_status_render_extra" ] && [ "$cfmgr_status_render_bytes" -le 32768 ] || return 1
	cfmgr_status_attachment_ok && [ -f "$cfmgr_status_render_output" ] && [ ! -L "$cfmgr_status_render_output" ] || return 1
	/bin/cat "$cfmgr_status_render_output"
}

cfmgr_status_project() {
	cfmgr_status_run status-config /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_status_config" "$1" "$cfmgr_status_now" "$cfmgr_status_boot" \
		"$CFMGR_REPOSITORY" "$CFMGR_BRANCH" "$cfmgr_status_wan" "$cfmgr_status_clock" "$cfmgr_status_config_bytes"
}

cfmgr_status_nvram() {
	cfmgr_status_value=unknown
	if cfmgr_status_run status-nvram /bin/nvram "$1" && cfmgr_status_fields nvram "$cfmgr_probe_stdout" "$1"; then
		IFS= read -r cfmgr_status_value <"$cfmgr_probe_stdout"
		case $1 in wan0_ifname | wan1_ifname | wan0_pppoe_ifname | wan1_pppoe_ifname) cfmgr_status_interface=$cfmgr_status_value ;; wan0_primary | wan1_primary) return 0 ;; ntp_ready) [ "$cfmgr_status_value" != Ready ] || cfmgr_status_clock=1 ;; esac
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
	cfmgr_status_run status-fields /usr/bin/awk "$cfmgr_source/modules/status.sh" "$1" "$2" "$3"
}

# Consume ONLY the successful bounded native LS receipt, never config data.
cfmgr_status_snapshot_metadata() {
	{
		IFS= read -r cfmgr_status_meta_line || return 1
		cfmgr_status_meta_extra=''
		if IFS= read -r cfmgr_status_meta_extra || [ -n "$cfmgr_status_meta_extra" ]; then return 1; fi
	} <"$cfmgr_probe_stdout"
	case $cfmgr_status_meta_line in '' | *[!\ -~]*) return 1 ;; esac
	[ "${#cfmgr_status_meta_line}" -le 8192 ] || return 1
	IFS=' ' read -r cfmgr_status_meta_inode cfmgr_status_meta_mode cfmgr_status_meta_links cfmgr_status_meta_uid cfmgr_status_meta_gid \
		cfmgr_status_meta_bytes cfmgr_status_meta_month cfmgr_status_meta_day cfmgr_status_meta_stamp cfmgr_status_meta_path <<EOF_STATUS_META
$cfmgr_status_meta_line
EOF_STATUS_META
	case $cfmgr_status_meta_inode in '' | *[!0-9]* | 0*) return 1 ;; esac
	case $cfmgr_status_meta_bytes in '' | *[!0-9]* | 0*) return 1 ;; esac
	[ "${#cfmgr_status_meta_inode}" -le 20 ] && [ "${#cfmgr_status_meta_bytes}" -le 5 ] &&
		[ "$cfmgr_status_meta_bytes" -le 65536 ] && [ "$cfmgr_status_meta_uid" = 0 ] &&
		[ "$cfmgr_status_meta_mode" = -rw------- ] && [ "$cfmgr_status_meta_path" = "$1" ] || return 1
	case $cfmgr_status_meta_links:$cfmgr_status_meta_gid in *[!0-9:]* | :* | *:) return 1 ;; esac
	[ -n "$cfmgr_status_meta_month" ] && [ -n "$cfmgr_status_meta_day" ] && [ -n "$cfmgr_status_meta_stamp" ] || return 1
	cfmgr_status_meta_receipt="$cfmgr_status_meta_inode $cfmgr_status_meta_bytes"
}

cfmgr_status_snapshot() {
	cfmgr_status_run status-metadata /bin/ls "$1" || return $?
	cfmgr_status_snapshot_metadata "$1" || return 1
	cfmgr_status_snapshot_inode=$cfmgr_status_meta_inode cfmgr_status_snapshot_bytes=$cfmgr_status_meta_bytes
	cfmgr_status_snapshot_before=$cfmgr_status_meta_receipt
	cfmgr_status_run status-snapshot /bin/dd "$1" || return $?
	cfmgr_status_snapshot_file=$cfmgr_probe_stdout
	cfmgr_status_run status-count /usr/bin/wc "$cfmgr_status_snapshot_file" || return $?
	IFS=' ' read -r cfmgr_status_snapshot_actual cfmgr_status_snapshot_extra <"$cfmgr_probe_stdout" || return 1
	[ -z "$cfmgr_status_snapshot_extra" ] && [ "$cfmgr_status_snapshot_actual" = "$cfmgr_status_snapshot_bytes" ] || return 1
	cfmgr_status_run status-metadata /bin/ls "$1" || return $?
	cfmgr_status_snapshot_metadata "$1" || return 1
	[ "$cfmgr_status_meta_receipt" = "$cfmgr_status_snapshot_before" ]
}

cfmgr_status_mount() {
	cfmgr_status_run status-realpath /usr/bin/readlink "$1" || return $?
	IFS= read -r cfmgr_status_mount_target <"$cfmgr_probe_stdout" || return 1
	case $cfmgr_status_mount_target in /*) ;; *) return 1 ;; esac
	case $cfmgr_status_mount_target in *[!\ -~]* | *\\* | */../* | */./* | *//*) return 1 ;; esac
	cfmgr_status_run status-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_status_mount_target" || return $?
	cfmgr_status_fields mount "$cfmgr_probe_stdout" "$1"
}

cfmgr_status_space() {
	cfmgr_status_run status-space /bin/df "$1" || return $?
	cfmgr_status_fields space "$cfmgr_probe_stdout" -
}

cfmgr_status_awk_health_metadata() {
	# CFMGR-AWK-BEGIN health_metadata
	cfmgr_awk_program='
# Exact immutable member inventory plus one successful-or-partial native LS.
# A malformed/duplicate/missing known path invalidates its dependent members.
BEGIN {
    path=ARGV[1]; profile=ARGV[2]; spec=ARGV[3]; ARGC=1
    if(profile=="native") {
        if(split(spec,flags," ")!=5 || flags[1]!~/^(busybox|regular|missing)$/) exit 1
        members[1]="curl"; members[2]="openssl"; members[3]="ca"; members[4]="flock"; count=4
        for(i=1;i<=4;i++) { if(flags[i+1]!~/^[01]$/) exit 1; initial[members[i]]=flags[i+1]+0 }
        hm_add("/","directory","curl openssl ca flock")
        hm_add("/usr","directory","curl openssl flock"); hm_add("/usr/sbin","directory","curl openssl")
        hm_add("/usr/sbin/curl","file","curl"); hm_add("/usr/sbin/openssl","file","openssl")
        hm_add("/rom","directory","ca"); hm_add("/rom/etc","directory","ca")
        hm_add("/rom/etc/ssl","directory","ca"); hm_add("/rom/etc/ssl/certs","directory","ca")
        hm_add("/rom/etc/ssl/certs/ca-certificates.crt","file","ca")
        if(flags[1]=="busybox") { hm_add("/usr/bin","directory","flock"); hm_add("/bin","directory","flock"); hm_add("/bin/busybox","file","flock") }
        else if(flags[1]=="regular") { hm_add("/usr/bin","directory","flock"); hm_add("/usr/bin/flock","file","flock") }
        else initial["flock"]=0
    } else if(profile=="entware") {
        members[1]="storage"; members[2]="jq"; members[3]="timeout"; members[4]="sha"; members[5]="flock"; members[6]="dig"; count=6
        if(length(spec)>32768) exit 1
        n=split(spec,lines,"\n"); if(n>97) exit 1
        for(i=1;i<=n;i++) {
            if(lines[i]=="") continue
            if(split(lines[i],fields,"\t")!=3 || fields[1]!~/^(storage|jq|timeout|sha|flock|dig)$/ || fields[2]!~/^(file|directory)$/ ||
                fields[3]!~/^\// || length(fields[3])>4096 || fields[3]~/[^ -~]/ || fields[3]~/\\/) exit 1
            hm_add(fields[3],fields[2],fields[1]); initial[fields[1]]=1
        }
    } else exit 1
    # Complete framing before interpreting any record; native LS always emits LF.
    RS=sprintf("%c",28); got=getline raw < path; more=getline extra < path; close(path)
    if(got<0 || more>0 || length(raw)>65536 || raw~/[^ -~\n]/ || (raw!="" && substr(raw,length(raw),1)!="\n")) exit 1
    n=split(raw,lines,"\n"); if(n>97) exit 1
    for(i=1;i<n;i++) hm_record(lines[i])
    print "CFMGR-HEALTH-METADATA 1"
    for(i=1;i<=count;i++) {
        member=members[i]; ok=initial[member]
        for(p in expected) if(required[p,member] && (!seen[p] || invalid[p])) ok=0
        printf "member %s %d\n",member,(global_bad ? 0 : ok)
    }
    print "END"; exit
}
function hm_add(p,kind,names,    a,n,j) {
    if((p in expected) && expected[p]!=kind) exit 1
    if(!(p in expected) && ++paths>13) exit 1
    expected[p]=kind; n=split(names,a," ")
    for(j=1;j<=n;j++) { if(required[p,a[j]]++) exit 1 }
}
function hm_record(line,    rest,f,j,p,name,bad) {
    rest=line
    for(j=1;j<=9;j++) {
        sub(/^ +/,"",rest)
        if(!match(rest,/^[^ ]+/)) { global_bad=1; return }
        f[j]=substr(rest,1,RLENGTH); rest=substr(rest,RLENGTH+1)
    }
    sub(/^ +/,"",rest); p=rest
    if(!(p in expected) && substr(f[2],1,1)=="l") {
        for(name in expected) if(substr(p,1,length(name)+4)==name " -> ") { p=name; break }
    }
    if(!(p in expected)) { global_bad=1; return }
    if(seen[p]++) invalid[p]=1
    if(f[1]!~/^[1-9][0-9]*$/ || f[3]!~/^[1-9][0-9]*$/ || f[4]!="0" || f[5]!~/^[0-9]+$/ || f[6]!~/^[0-9]+$/ ||
        length(f[2])!=10 || f[2]!~/^[-d]/ || substr(f[2],6,1)=="w" || substr(f[2],9,1)=="w" ||
        (expected[p]=="directory" ? substr(f[2],1,1)!="d" : substr(f[2],1,1)!="-")) invalid[p]=1
}
'
	# CFMGR-AWK-END health_metadata
}

cfmgr_status_awk_health_local() {
	# CFMGR-AWK-BEGIN health_local
	cfmgr_awk_program='
BEGIN {
    mode=ENVIRON["CFMGR_HEALTH_LOCAL"]; path=ARGV[1]; key=ARGV[2]; expected=ARGV[3]; ARGC=1
    if(mode=="health-storage") {
        if((getline line < path)!=1 || (getline extra < path)>0 || split(line,a,"\t")!=9) exit 1
        while((getline line < key)==1) {
            if(++n>16 || length(line)>17000) exit 1
            if(substr(line,1,8)=="storage ") { if(saved++) exit 1; split(line,s," ") }
        }
        if(saved!=1 || s[3]!=a[6] || hl_decode(s[4])!=a[4] ||
            expected!=(a[5] (hl_decode(s[5])=="." ? "" : "/" hl_decode(s[5]))) ||
            a[5]=="/" || a[7]!~/^\/dev\/[A-Za-z0-9._\/-]+$/ || a[6]!~/^ext[234]$/ ||
            !index("," a[8] ",",",rw,") || index("," a[8] ",",",noexec,") || !index("," a[9] ",",",rw,")) exit 1
        printf "%s\t%s\t%s\t%s\n",s[2],a[6],a[7],a[5]; exit
    }
    if(mode=="health-current") {
        if(key!~/^[A-Za-z0-9_.:-]+$/ || length(key)>32) exit 1
        while((getline line < path)==1) {
            if(++n>256 || length(line)>256) exit 1
            if(split(line,a," ")!=6 || a[2]!~/^[0-9a-f]+$/ || length(a[2])>8 || a[3]!~/^[0-9a-f]+$/ || length(a[3])>2 || hl_number(a[3])>128) continue
            # Linux if_inet6: address,index,prefix,scope,flags,interface.
            # Only current global 2000::/3, non-tentative/non-DADfailed and
            # non-deprecated addresses on the selected WAN qualify.
            flags=hl_number(a[5])
            if(a[6]==key && length(a[1])==32 && a[1]~/^[23][0-9a-f]+$/ && a[4]=="00" && flags>=0 &&
                int(flags/4)%2==0 && int(flags/8)%2==0 && int(flags/32)%2==0 && int(flags/64)%2==0 &&
                substr(a[1],1,8)!="20010db8") ready=1
        }
        close(path); if(!ready) exit 1; print "current-global-ipv6"; exit
    }
    if(mode=="health-protected") {
        if((getline line < path)!=1 || length(line)>8192 || (getline extra < path)>0) exit 1
        split(line,a," "); permissions=a[2]
        if(a[1]!~/^[1-9][0-9]*$/ || a[4]!="0" || length(permissions)!=10 ||
            permissions!~/^[-d]/ || substr(permissions,6,1)=="w" || substr(permissions,9,1)=="w") exit 1
        if(key=="directory" ? substr(permissions,1,1)!="d" : substr(permissions,1,1)!="-") exit 1
        print "protected"; exit
    }
    if(mode=="health-uuid") {
        if((getline line < path)!=1 || length(line)>4096 || (getline extra < path)>0 || substr(line,1,length(key)+2)!=key ": ") exit 1
        rest=substr(line,length(key)+3)
        while(rest!="") {
            if(!match(rest,/^[A-Z_]+="/)) exit 1
            name=substr(rest,1,RLENGTH-2); rest=substr(rest,RLENGTH+1); stop=index(rest,"\"")
            if(!stop || seen[name]++) exit 1
            value[name]=substr(rest,1,stop-1); rest=substr(rest,stop+1)
            if(rest!="") { if(substr(rest,1,1)!=" ") exit 1; rest=substr(rest,2) }
        }
        if(value["TYPE"]!="" && value["TYPE"]!=expected) exit 1
        uuid=tolower(value["UUID"]); if(length(uuid)!=36 || uuid~/[^0-9a-f-]/ || substr(uuid,9,1)!="-" || substr(uuid,14,1)!="-" || substr(uuid,19,1)!="-" || substr(uuid,24,1)!="-") exit 1
        compact=uuid; gsub(/-/,"",compact); if(length(compact)!=32) exit 1
        print uuid; exit
    }
    exit 1
}
function hl_number(hex,    i,value,digit) {
    if(hex=="" || length(hex)>8 || hex~/[^0-9a-f]/) return -1
    value=0; for(i=1;i<=length(hex);i++) { digit=index("0123456789abcdef",substr(hex,i,1))-1; value=value*16+digit }; return value
}
function hl_decode(hex,    i,value,out) {
    if(length(hex)%2 || hex=="" || hex~/[^0-9a-f]/) exit 1
    for(i=1;i<=length(hex);i+=2) { value=hl_number(substr(hex,i,2)); if(value<32 || value>126) exit 1; out=out sprintf("%c",value) }; return out
}
'
	# CFMGR-AWK-END health_local
}

cfmgr_status_awk_status_native() {
	# CFMGR-AWK-BEGIN status_native
	cfmgr_awk_program='
# One bounded read of fixed kernel resource paths; no process/command-line scan.
# ARGV[1] is the caller-admitted proc root (production /proc). Typed tab receipts
# exclude identifiers except the boot UUID, which stays private in the consumer.
BEGIN {
    if (ARGV[1] != "resources") { projection(ARGV[1],ARGV[2],ARGV[3]); exit }
    root = ARGV[2]; ARGV[1] = ARGV[2] = ""; ARGC = 1
    uptime = load = memory = "Unavailable"
    if ((getline line < (root "/uptime")) == 1 && length(line) < 128) {
        split(line, fields, " ")
        if (fields[1] ~ /^[0-9]+\.[0-9]+$/) uptime = int(fields[1]) "s"
    }
    close(root "/uptime")
    if ((getline line < (root "/loadavg")) == 1 && length(line) < 128) {
        split(line, fields, " ")
        if (fields[1] ~ /^[0-9]+\.[0-9]+$/ && fields[2] ~ /^[0-9]+\.[0-9]+$/ && fields[3] ~ /^[0-9]+\.[0-9]+$/)
            load = fields[1] " " fields[2] " " fields[3]
    }
    close(root "/loadavg")
    count = 0
    while ((getline line < (root "/meminfo")) == 1) {
        if (++count > 128 || length(line) > 256) { bad = 1; break }
        split(line, fields, " ")
        if (fields[2] ~ /^[0-9]+$/ && fields[3] == "kB") mem[fields[1]] = fields[2] + 0
    }
    close(root "/meminfo")
    if (!bad && mem["MemTotal:"] > 0) {
        available = mem["MemAvailable:"]
        if (!("MemAvailable:" in mem)) available = mem["MemFree:"] + mem["Buffers:"] + mem["Cached:"]
        if (available >= 0 && available <= mem["MemTotal:"])
            memory = sprintf("%d/%d KiB used; %d KiB available%s", mem["MemTotal:"] - available,
                mem["MemTotal:"], available, (("MemAvailable:" in mem) ? "" : " (estimate)"))
    }
    boot = "unknown"
    if ((getline line < (root "/sys/kernel/random/boot_id")) == 1 &&
        length(line) == 36 && line ~ /^[0-9a-f-]+$/ && substr(line,9,1)=="-" &&
        substr(line,14,1)=="-" && substr(line,19,1)=="-" && substr(line,24,1)=="-") boot = line
    close(root "/sys/kernel/random/boot_id")
    print "uptime\t" uptime
    print "load\t" load
    print "memory\t" memory
    print "boot\t" boot
    exit
}
# Projection inputs are immutable bounded native outputs in the owned context.
function projection(mode,path,key,    line,n,a,i,value,bad,count,out) {
    count=0
    while((getline line < path)==1) {
        if(++count>4 || length(line)>8192 || line~/[^ -~\t]/) { bad=1; break }
        if(mode=="space") {
            if(count==1) continue
            n=split(line,a," ")
            if(count!=2 || n!=6 || a[2]!~/^[0-9]+$/ || a[3]!~/^[0-9]+$/ || a[4]!~/^[0-9]+$/ || a[5]!~/^[0-9]+%$/ || a[2]<=0 || a[3]>a[2] || a[4]>a[2]) { bad=1; break }
            out=a[3] "/" a[2] " KiB used; " a[4] " KiB available (" a[5] ")"
        } else if(mode=="metadata") {
            n=split(line,a," ")
            if(count!=1 || n<10 || a[1]!~/^[1-9][0-9]*$/ || a[2]!="-rw-------" || a[4]!="0" || a[6]!~/^[1-9][0-9]*$/ || a[6]>65536) { bad=1; break }
            out=a[1] " " a[6]
        } else if(mode=="mount") {
            n=split(line,a,"\t")
            if(count!=1 || n!=9) { bad=1; break }
            if(key=="/jffs" && a[6]=="jffs2" && a[5]=="/jffs") out="jffs2 mounted"
            else if(key=="/opt" && a[5]!="/" && a[6]~/^(ext[234]|vfat|exfat|ntfs|ntfs3|fuseblk)$/) out=a[6] " mounted"
            else { bad=1; break }
            out=out (index("," a[8] ",",",rw,") ? " (rw)" : " (ro)")
        } else if(mode=="setup") {
            if(count!=1 || line!="CFMGR-SETUP 1 " key " complete") { bad=1; break }
            out="complete"
        } else if(mode=="nvram") {
            if(count!=1 || length(line)>128 || line=="" || line~/[^ -~]/) { bad=1; break }
            if(key~/_ipaddr$/) { if(!native_ipv4(line)) { bad=1; break }; out=line " (" native_class(line) ")" }
            else if(key=="ntp_ready") { if(line=="1") out="Ready"; else if(line=="0") out="Not ready"; else bad=1 }
            else if(key~/_primary$/) { if(line!~/^[01]$/) bad=1; else out=line }
            else { if(line!~/^[A-Za-z0-9_.:-]+$/) bad=1; else out=line }
        } else { bad=1; break }
    }
    close(path)
    if(bad || !count || out=="" || (mode=="space" && count!=2)) exit 1
    print out
}
function native_ipv4(s,    n,a,i) { n=split(s,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function native_class(s,    a) {
    split(s,a,".")
    if(a[1]==100 && a[2]>=64 && a[2]<=127) return "Shared-CGNAT"
    if(a[1]==10 || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && a[2]==168)) return "Private"
    if(a[1]==0 || a[1]==127 || a[1]>=224 || (a[1]==169 && a[2]==254) ||
        (a[1]==192 && a[2]==0 && (a[3]==0 || a[3]==2)) ||
        (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) ||
        (a[1]==203 && a[2]==0 && a[3]==113)) return "Non-public"
    return "Public"
}
'
	# CFMGR-AWK-END status_native
}

cfmgr_status_awk_status() {
	# CFMGR-AWK-BEGIN status
	cfmgr_awk_program='
# Subsequent config JSON getter tree consumer: typed, allowlisted status projection only.
# Optional history.<feature>.status contract (schema1, generation): ipv4/ipv6
# {result:published|verified|removed,value:IP|null,at:epoch}; latest/events
# {result:success|partial|pending|failed,reason:enum,at:epoch}. At most5 events.
# observation {origin:runtime|restored,boot_id,at,running:boolean,
# connection:connected|waiting|unknown,installed_version,logging:enum,cleanup:boolean}.
# Current observations require runtime origin, generation/boot match and trusted
# nonfuture age<=300s. Future restore writers MUST invalidate runtime origin.
# history.network.status uses the same context plus selected_wan and family
# {value,at,source:recorded|interface|discovery,eligible:boolean forIPv6}.
# History remains historical and never establishes current auth/provider success.
# No raw recorded errors/credentials/identifiers or terminal controls are emitted.
BEGIN {
    if (!cfmgr_json_tree_ready || cfmgr_json_tree_kind[1] != "object") exit 1
    for (i=2; i<=cfmgr_json_tree_count; i++) child[cfmgr_json_tree_parent[i],cfmgr_json_tree_location[i]]=i
    config_schema=number(field(1,"schema"))
    if (config_schema != "1" && config_schema != "2") exit 1
    generation=number(field(1,"generation"))
    if (generation !~ /^[1-9][0-9]*$/ || length(generation)>20) exit 1
    network=object(field(1,"network")); selected=field(network,"selected_wan")
    wan="auto"
    if (selected && cfmgr_json_tree_kind[selected]!="null") {
        value=number(selected); if(value=="") value=text(selected,8)
        if(value=="wan0") value="0"; if(value=="wan1") value="1"
        wan=(value=="0" || value=="1" ? value : "unknown")
    }
    if (ENVIRON["CFMGR_STATUS_MODE"]=="select") { print wan; exit }
    if (ENVIRON["CFMGR_STATUS_MODE"]!="render") exit 1
    now=ENVIRON["CFMGR_STATUS_NOW"]; clock=(ENVIRON["CFMGR_STATUS_CLOCK"]=="1")
    if (now !~ /^[1-9][0-9]*$/ || length(now)>10) clock=0
    boot=ENVIRON["CFMGR_STATUS_BOOT"]; live_wan=ENVIRON["CFMGR_STATUS_WAN"]
    print "Configuration: local schema" config_schema "; settings and observations are separate"
    manager=object(field(1,"manager")); developer=boolean(field(manager,"developer"))
    repository=ENVIRON["CFMGR_STATUS_REPOSITORY"]; branch=ENVIRON["CFMGR_STATUS_BRANCH"]
    if(developer=="On") {
        source=object(field(manager,"source")); repository=text(field(source,"repository"),192)
        branch=text(field(source,"branch"),128); commit=text(field(source,"commit"),40)
        if(repository !~ /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/ ||
            branch !~ /^[A-Za-z0-9_.\/-]+$/ || branch ~ /(^|\/)(\.|\.\.)(\/|$)/ ||
            (commit!="" && (length(commit)!=40 || commit~/[^0-9a-f]/))) {
            print "Manager source: Unavailable (invalid developer selection)"
        } else print "Manager source: developer " repository " / " branch (commit!="" ? " @ " commit : "")
    } else if(developer=="Off") print "Manager source: default " repository " / " branch
    else print "Manager source: Unknown (invalid developer setting)"
    check_updates=boolean(field(manager,"check_updates")); auto_update=boolean(field(manager,"auto_update"))
    if(developer=="On") {
        effective_check=(check_updates=="Unknown" ? "Unknown" : "Off")
        effective_auto=(check_updates=="Unknown" || auto_update=="Unknown" ? "Unknown" : "Off")
    } else if(developer=="Off") {
        effective_check=check_updates
        effective_auto=(check_updates=="Unknown" || auto_update=="Unknown" ? "Unknown" : (check_updates=="On" && auto_update=="On" ? "On" : "Off"))
    } else {
        effective_check="Unknown"; effective_auto="Unknown"
    }
    print "Manager updates: saved Check=" check_updates "; saved Auto=" auto_update "; effective Check=" effective_check "; effective Auto=" effective_auto
    if(developer=="On") print "Note: developer mode suppresses manager updates; saved preferences are retained"
    history=object(field(1,"history")); logging=object(field(1,"logging"))
    if(wan=="unknown") print "Issue: invalid selected WAN; recover network settings"
    addresses(object(field(object(field(history,"network")),"status")))
    names[1]="ddns"; names[2]="ip_sync"; names[3]="cloudflared"
    labels[1]="DDNS"; labels[2]="IP-Sync"; labels[3]="Cloudflared"
    for(f=1;f<=3;f++) {
        name=names[f]; label=labels[f]; settings=object(field(1,name))
        configured=boolean(field(settings,"configured")); enabled=boolean(field(settings,"enabled"))
        print label ": configured=" configured "; enabled=" enabled
        if(name=="cloudflared") print "  installed=" boolean(field(settings,"installed")) "; maintenance=" boolean(field(settings,"maintenance_enabled"))
        if(configured=="Unknown" || enabled=="Unknown") print "  Issue: settings unavailable/invalid; recover retained settings"
        else if(configured=="Off" && enabled=="On") print "  Issue: invalid enabled-without-configured; recover retained settings"
        else if(configured=="Off") print "  Next: configure " label " first"
        else if(enabled=="Off") print "  Next: enable " label " when ready"
        record=object(field(object(field(history,name)),"status"))
        if(record && number(field(record,"schema"))!="1") { print "  History: Unavailable (invalid record schema)"; record=0 }
        if(name!="cloudflared") {
            outcome(record,"ipv4","IPv4"); outcome(record,"ipv6","IPv6")
        }
        latest=object(field(record,"latest"))
        if(!latest) print "  Last outcome: Never"
        else {
            result=result_value(latest); reason=reason_value(latest)
            if(result=="" || reason=="") print "  Last outcome: Unavailable (invalid typed record)"
            else print "  Last outcome (historical): " result "; " reason "; " age(field(latest,"at")) context(record)
        }
        observe(record,configured,enabled)
        log_settings=object(field(logging,name))
        if(boolean(field(log_settings,"configured"))=="On" && boolean(field(log_settings,"enabled"))=="On" && observed_logging!="ready")
            print "  Issue: requested logging readiness " (observed_logging=="" ? "Unknown" : observed_logging)
        events(record)
    }
    for(e=1;e<=recent_count;e++) print recent[e]
    exit
}
function hex(s,    i,out) { out=""; for(i=1;i<=length(s);i++) out=out byte_hex[byte_value["b" substr(s,i,1)]]; return out }
function field(parent,key) { return parent ? child[parent,"k" hex(key)] : 0 }
function object(id) { return cfmgr_json_tree_kind[id]=="object" ? id : 0 }
function number(id) { return cfmgr_json_tree_kind[id]=="number" ? substr(cfmgr_json_tree_payload[id],2) : "" }
function boolean(id) { return cfmgr_json_tree_kind[id]=="true" ? "On" : (cfmgr_json_tree_kind[id]=="false" ? "Off" : "Unknown") }
function text(id,limit,    encoded,i,n,out) {
    if(cfmgr_json_tree_kind[id]!="string") return ""
    encoded=substr(cfmgr_json_tree_payload[id],2); if(length(encoded)>limit*2) return ""
    out=""; for(i=1;i<=length(encoded);i+=2) {
        n=16*hex_value["h" substr(encoded,i,1)]+hex_value["h" substr(encoded,i+1,1)]
        if(n<32 || n>126) return ""
        out=out sprintf("%c",n)
    }; return out
}
function ipv4(s,    a,n,i) { n=split(s,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function public4(s,    a) { if(!ipv4(s)) return 0; split(s,a,"."); return !(a[1]==0 || a[1]==10 || a[1]==127 || a[1]>=224 || (a[1]==100 && a[2]>=64 && a[2]<=127) || (a[1]==169 && a[2]==254) || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && (a[2]==168 || (a[2]==0 && (a[3]==0 || a[3]==2)))) || (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) || (a[1]==203 && a[2]==0 && a[3]==113)) }
function ipv6(s,    lower,n,a,i,double,groups) {
    lower=tolower(s)
    if(length(s)>39 || s~/[^0-9a-fA-F:]/ || lower!~/^[23][0-9a-f][0-9a-f][0-9a-f]:/ || lower~/^2001:0?db8:/ || s~/:::/) return 0
    double=index(s,"::"); if(double && index(substr(s,double+2),"::")) return 0
    n=split(s,a,":"); groups=0
    for(i=1;i<=n;i++) if(a[i]!="") { if(length(a[i])>4 || a[i]!~/^[0-9a-fA-F]+$/) return 0; groups++ }
    if((substr(s,1,1)==":" && substr(s,1,2)!="::") || (substr(s,length(s),1)==":" && substr(s,length(s)-1)!="::")) return 0
    return double ? groups<8 : groups==8
}
function age(id,    stamp) {
    stamp=number(id)
    if(!clock || stamp!~/^[1-9][0-9]*$/ || length(stamp)>10 || stamp>now) return "time/age Unknown"
    return "at " stamp "; age " sprintf("%.0f",now-stamp) "s"
}
function context(record,    gen) {
    gen=number(field(record,"generation"))
    return ("g" gen=="g" generation ? "" : " (stale generation)")
}
function result_value(item,    s) { s=text(field(item,"result"),16); return s~/^(success|partial|pending|failed)$/ ? s : "" }
function reason_value(item,    s) { s=text(field(item,"reason"),16); return s~/^(auth|storage|recovery|throttle|partial|unavailable|none|network|waiting)$/ ? s : "" }
function outcome(record,family,label,    item,result,value,eligible) {
    item=object(field(record,family))
    if(!item) { print "  Last verified " label ": Never"; return }
    result=text(field(item,"result"),16); value=text(field(item,"value"),39)
    if(result!~/^(published|verified|removed)$/ ||
        (result=="removed" ? cfmgr_json_tree_kind[field(item,"value")]!="null" : \
        (family=="ipv4" ? !public4(value) : !ipv6(value)))) { print "  Last verified " label ": Unavailable (invalid typed record)"; return }
    print "  Last verified " label " (historical): " result (result=="removed" ? "" : " " value) "; " age(field(item,"at")) context(record)
}
function fresh(record,item,    stamp,gen) {
    stamp=number(field(item,"at")); gen=number(field(record,"generation"))
    return number(field(record,"schema"))=="1" && "g" gen=="g" generation &&
        text(field(item,"origin"),16)=="runtime" && boot!="unknown" && text(field(item,"boot_id"),36)==boot &&
        clock && stamp~/^[1-9][0-9]*$/ && length(stamp)<=10 && stamp<=now && now-stamp<=300
}
function observe(record,configured,enabled,    item,state,running,version,cleanup) {
    observed_logging=""; item=object(field(record,"observation"))
    if(!item) { print "  Runtime: Unknown (no current local observation)"; if(name=="cloudflared") print "  Installed version: Unknown"; return }
    if(boolean(field(item,"cleanup"))=="On") print "  Issue: recorded cleanup required; use scoped recovery; " age(field(item,"at")) context(record)
    if(!fresh(record,item)) { print "  Runtime: Unknown (stale/restored/untrusted observation)"; version=text(field(item,"installed_version"),64)
        if(name=="cloudflared") print "  Installed version: " (version~/^[A-Za-z0-9_.+-]+$/ ? version " (recorded/stale)" : "Unknown")
        return
    }
    running=boolean(field(item,"running")); state=text(field(item,"connection"),16)
    if(state!~/^(connected|waiting|unknown)$/ || running=="Unknown" || (state=="connected" && running!="On")) {
        print "  Runtime: Unavailable (invalid typed observation)"; return
    }
    print "  Observed running=" running "; connection=" state "; " age(field(item,"at"))
    version=text(field(item,"installed_version"),64)
    if(name=="cloudflared") print "  Installed version: " (version~/^[A-Za-z0-9_.+-]+$/ ? version " (recorded runtime)" : "Unknown")
    observed_logging=text(field(item,"logging"),16)
    if(observed_logging!~/^(ready|unavailable|unknown)$/) observed_logging=""
}
function addresses(record,    family,item,value,valid,label,source,stale) {
    for(family=1;family<=2;family++) {
        label=(family==1 ? "public IPv4" : "eligible IPv6"); item=object(field(record,(family==1 ? "ipv4" : "ipv6")))
        if(!item) { print "Recorded " label ": Never"; continue }
        value=text(field(item,"value"),39); source=text(field(item,"source"),16)
        valid=(family==1 ? public4(value) : ipv6(value) && boolean(field(item,"eligible"))=="On")
        if(number(field(record,"schema"))!="1" || !valid || source!~/^(recorded|interface|discovery)$/) { print "Recorded " label ": Unavailable (invalid typed record)"; continue }
        stale=(!clock || number(field(item,"at"))!~/^[1-9][0-9]*$/ || number(field(item,"at"))>now) || !("g" number(field(record,"generation"))=="g" generation && text(field(record,"boot_id"),36)==boot &&
            boot!="unknown" && text(field(record,"selected_wan"),8)==live_wan)
        print "Recorded " label " (historical" (stale ? "/stale" : "") "): " value "; source=" source "; " age(field(item,"at"))
    }
}
function events(record,    array,i,count,item,result,reason,first) {
    array=field(record,"events"); if(cfmgr_json_tree_kind[array]!="array") return
    count=0; while(child[array,"i" count]) count++
    first=(count>5 ? count-5 : 0)
    for(i=first;i<count;i++) {
        item=object(child[array,"i" i]); result=result_value(item); reason=reason_value(item)
        if(result!="" && reason!="" && recent_count<5) recent[++recent_count]="Recent " label " (historical): " result "; " reason "; " age(field(item,"at")) context(record)
    }
}
'
	# CFMGR-AWK-END status
}

cfmgr_status_awk_health() {
	# CFMGR-AWK-BEGIN health
	cfmgr_awk_program='
# Borrow only the completely validated immutable schema-2 authority tree.
BEGIN {
    if(!co_observation_ready || co_version!="n2") reject()
    if(ENVIRON["CFMGR_HEALTH_MODE"]=="health-inventory") { hp_inventory(); exit }
    hp_feature=ENVIRON["CFMGR_HEALTH_FEATURE"]; hp_kind=ENVIRON["CFMGR_HEALTH_KIND"]
    hp_selector=ENVIRON["CFMGR_HEALTH_SELECTOR"]; hp_family=ENVIRON["CFMGR_HEALTH_FAMILY"]
    if(hp_feature!~/^(ddns|ip_sync|cloudflared)$/ || hp_kind!~/^(zone|dns|list|items|tunnel|connections|trace)$/ || hp_family!~/^[46]$/) reject()
    hp_id=cs_id(1,hp_feature); hp_scope=hp_resource=hp_name=hp_type="-"; hp_state="eligible"; hp_url=""; hp_token=""
    if(!cs_bool(hp_id,"configured")) hp_state="unconfigured"
    else hp_state=hp_hold(hp_feature)
    if(hp_state=="eligible" && hp_kind=="trace") {
        if(ENVIRON["CFMGR_HEALTH_PUBLIC"]!="1" || (hp_family=="6" && ENVIRON["CFMGR_HEALTH_IPV6"]!="1")) hp_state="eligibility-unproved"
        else { hp_scope="public." hp_feature; hp_type=hp_family; hp_url="https://cloudflare.com/cdn-cgi/trace" }
    } else if(hp_state=="eligible") hp_resource_request()
    if(hp_state!="eligible") hp_scope=hp_resource=hp_name=hp_type="-"
    hp_request=""
    if(hp_state=="eligible") {
        if(length(hp_url)>2048) reject()
        hp_request="url = \"" hp_url "\"\n"
        if(hp_kind!="trace") hp_request=hp_request "header = \"Authorization: Bearer " hp_token "\"\n"
        if(length(hp_request)>4352) reject()
    }
    if(ENVIRON["CFMGR_HEALTH_MODE"]=="health-request") {
        if(hp_state!="eligible") exit 1
        printf "%s",hp_request
    } else if(ENVIRON["CFMGR_HEALTH_MODE"]=="health-scope")
        printf "CFMGR-HEALTH-SCOPE 1 %s %s %s %s %s %s %s %d END\n",hp_state,hp_feature,hp_scope,hp_kind,hp_resource,hp_name,hp_type,length(hp_request)
    else reject()
    exit 0
}
function hp_hold(feature,    root,wrapper,status,latest,events,i,item,reason,held) {
    root=cs_id(1,"history"); wrapper=cs_id(root,feature)
    if(!wrapper || cfmgr_json_tree_kind[wrapper]=="null") return "eligible"
    status=cs_id(wrapper,"status"); if(!status || cfmgr_json_tree_kind[status]=="null") return "eligible"
    if(cfmgr_json_tree_kind[status]!="object" || cfmgr_json_tree_payload[cs_id(status,"schema")]!="n1") return "historical-unknown"
    latest=cs_id(status,"latest")
    if(latest && cfmgr_json_tree_kind[latest]!="null") {
        if(cfmgr_json_tree_kind[latest]!="object") return "historical-unknown"
        reason=cs_string(latest,"reason",0)
        return reason=="auth" ? "historical-auth" : (reason=="throttle" ? "historical-throttle" : "eligible")
    }
    events=cs_id(status,"events"); if(!events) return "eligible"
    if(cfmgr_json_tree_kind[events]!="array") return "historical-unknown"
    held="eligible"
    for(i=0;(item=co_child[events,"i" i]);i++) {
        reason=cs_string(item,"reason",0)
        if(reason=="auth") return "historical-auth"
        if(reason=="throttle") held="historical-throttle"
    }
    return held
}
function hp_inventory(    f,id,names,i,j,k,array,item,count,s,families,family) {
    print "CFMGR-HEALTH-INVENTORY 1"
    split("ddns ip_sync cloudflared",names," ")
    for(i=1;i<=3;i++) {
        f=names[i]; id=cs_id(1,f)
        printf "feature %s %d %d %s\n",f,cs_bool(id,"configured"),cs_bool(id,"enabled"),hp_hold(f)
        if(f=="ddns") {
            array=cs_id(id,"records"); count=0
            for(j=0;(item=co_child[array,"i" j]);j++) {
                count++; if(length(cs_string(item,"id",0))>64) reject(); if(j<3) printf "target ddns dns %s %s\n",cs_local(cs_string(item,"id",0)),(cs_string(item,"type",0)=="AAAA" ? "6" : "4")
            }
            printf "additional ddns %d\n",(count>3 ? count-3 : 0)
        } else if(f=="ip_sync") {
            array=cs_id(id,"targets")
            for(j=0;(item=co_child[array,"i" j]);j++) {
                printf "target ip_sync list %s 4\n",cs_string(item,"role",0)
                families=cs_id(item,"families")
                for(k=0;(family=co_child[families,"i" k]);k++) printf "family ip_sync %s %s\n",cs_string(item,"role",0),cs_text(family)
            }
        }
    }
    # The complete config stays private for subsequent selected-file/logging
    # consumers. Only the validated retained storage tuple crosses this boundary.
    printf "storage %s %s %s %s\n",tolower(co_saved[1]),co_saved[2],co_hex(co_saved[3]),co_hex(co_saved[4])
    print "END"
}
function hp_provider_id(value) { return length(value)==32 && value~/^[0-9a-fA-F]+$/ }
function hp_dns(value,    a,n,i) {
    if(length(value)>253 || value=="") return 0
    n=split(value,a,"."); for(i=1;i<=n;i++) if(a[i]!~/^[A-Za-z0-9_-]+$/ || length(a[i])>63) { if(i!=1 || a[i]!="*" || n<2) return 0 }
    return 1
}
function hp_encode(value,    i,c,out) {
    out=""; for(i=1;i<=length(value);i++) { c=substr(value,i,1); out=out (c~/^[A-Za-z0-9._~-]$/ ? c : "%" toupper(byte_hex[byte_value["b" c]])) }; return out
}
function hp_resource_request(    ref,credential,account,resource,records,item,i,name,type,found,refs,identity) {
    if(hp_feature=="ddns" && hp_kind~/^(zone|dns)$/) {
        resource=cs_string(hp_id,"zone_id",0); ref=cs_string(hp_id,"credential_ref",0)
        if(!hp_provider_id(resource)) { hp_state="resource-local-only"; return }
        resource=tolower(resource); hp_scope=ref ".zone." resource; hp_resource=resource
        hp_url="https://api.cloudflare.com/client/v4/zones/" resource
        if(hp_kind=="dns") {
            records=cs_id(hp_id,"records")
            for(i=0;(item=co_child[records,"i" i]);i++) if(cs_string(item,"id",0)==hp_selector) { found=item; break }
            if(!found) { hp_state="resource-local-only"; return }
            name=tolower(cs_string(found,"name",0)); type=cs_string(found,"type",0)
            if(!hp_dns(name)) { hp_state="resource-local-only"; return }
            hp_name=co_hex(name); hp_type=type
            hp_url=hp_url "/dns_records?name=" hp_encode(name) "&type=" type "&per_page=50"
        }
    } else if(hp_feature=="ip_sync" && hp_kind~/^(list|items)$/) {
        account=cs_string(hp_id,"account_id",0); ref=cs_string(hp_id,"credential_ref",0)
        records=cs_id(hp_id,"targets")
        for(i=0;(item=co_child[records,"i" i]);i++) if(cs_string(item,"role",0)==hp_selector) { found=item; break }
        if(!found) { hp_state="resource-local-only"; return }
        resource=cs_string(found,"id",0); name=cs_string(found,"name",0)
        if(!hp_provider_id(account) || !hp_provider_id(resource) || length(name)>128 || name~/[^ -~]/) { hp_state="resource-local-only"; return }
        account=tolower(account); resource=tolower(resource); hp_resource=resource; hp_name=co_hex(name)
        hp_scope=ref ".list." account "." resource
        hp_url="https://api.cloudflare.com/client/v4/accounts/" account "/rules/lists/" resource (hp_kind=="items" ? "/items?per_page=50" : "")
    } else if(hp_feature=="cloudflared" && hp_kind~/^(tunnel|connections)$/) {
        refs=cs_id(hp_id,"credential_refs"); identity=cs_id(hp_id,"expected_identity")
        ref=cs_string(refs,"management",1); account=cs_string(identity,"account_id",1); resource=cs_string(identity,"tunnel_id",1)
        if(ref=="" || !hp_provider_id(account) || resource=="") { hp_state="unsupported-runtime-auth"; return }
        account=tolower(account); resource=cs_uuid(resource); hp_resource=resource; hp_scope=ref ".tunnel." account "." resource
        hp_url="https://api.cloudflare.com/client/v4/accounts/" account "/cfd_tunnel/" resource (hp_kind=="connections" ? "/connections" : "")
    } else { hp_state="unsupported-scope"; return }
    credential=cs_credentials[ref]
    if(!credential || cs_kinds[ref]!="cloudflare_api_token" || length(ref)>64) { hp_state="credential-local-only"; return }
    hp_token=cs_string(credential,"value",0)
    # BusyBox may retain the slash escape inside a regex bracket expression.
    # Reject backslash explicitly before the common Bearer alphabet check.
    if(length(hp_token)>2048 || index(hp_token,sprintf("%c",92)) || hp_token!~/^[A-Za-z0-9._~+\/-]+=*$/) { hp_token=""; hp_state="credential-local-only" }
}
'
	# CFMGR-AWK-END health
}

cfmgr_status_awk_health_wire() {
	# CFMGR-AWK-BEGIN health_wire
	cfmgr_awk_program='
BEGIN {
    hw_mode=ENVIRON["CFMGR_HEALTH_MODE"]
    if(hw_mode=="health-response" || hw_mode=="health-compare") { }
    else if(hw_mode=="health-request-check") { hw_request(ENVIRON["CFMGR_HEALTH_INPUT"],ENVIRON["CFMGR_HEALTH_BYTES"]); if(hw_kind!=ENVIRON["CFMGR_HEALTH_KIND"]) exit 1; exit 0 }
    else if(hw_mode=="health-frame") { hw_frame(ENVIRON["CFMGR_HEALTH_INPUT"],ENVIRON["CFMGR_HEALTH_KIND"]); exit 0 }
    else if(hw_mode=="health-trace") { hw_trace(); exit 0 }
    else exit 1
}
function hw_read(path,limit,expected,    s,extra,old) {
    old=RS; RS=sprintf("%c",28)
    if((getline s <path)!=1 || length(s)>limit || (expected && length(s)!=expected) || (getline extra <path)!=0) exit 1
    close(path); RS=old
    if(substr(s,length(s),1)!="\n") exit 1
    return s
}
function hw_id(value) { return length(value)==32 && value~/^[0-9a-f]+$/ }
function hw_uuid(value,    a,n,i) {
    n=split(value,a,"-"); if(n!=5 || length(a[1])!=8 || length(a[2])!=4 || length(a[3])!=4 || length(a[4])!=4 || length(a[5])!=12) return 0
    for(i=1;i<=5;i++) if(a[i]!~/^[0-9a-f]+$/) return 0; return 1
}
function hw_request(path,bytes,    raw,a,n,url,header,p,count,q) {
    if(bytes!~/^[1-9][0-9]*$/ || bytes>4352) exit 1
    raw=hw_read(path,4352,bytes)
    if(index(raw,sprintf("%c",92))) exit 1
    n=split(raw,a,"\n"); if(n<2 || n>3 || a[n]!="" || a[1]!~/^url = "https:\/\/[A-Za-z0-9._?&=%*\/-]+"$/) exit 1
    url=substr(a[1],8,length(a[1])-8); if(length(url)>2048) exit 1
    if(url=="https://cloudflare.com/cdn-cgi/trace") { if(n!=2) exit 1; hw_kind="trace"; hw_url=url; return }
    if(n!=3 || a[2]!~/^header = "Authorization: Bearer [A-Za-z0-9._~+\/-]+=*"$/) exit 1
    header=substr(a[2],33,length(a[2])-33); if(length(header)<1 || length(header)>2048) exit 1
    if(index(url,"https://api.cloudflare.com/client/v4/")!=1) exit 1
    count=split(substr(url,length("https://api.cloudflare.com/client/v4/")+1),p,"/")
    if(p[1]=="zones" && hw_id(p[2])) {
        hw_resource=p[2]
        if(count==2) hw_kind="zone"
        else if(count==3 && p[3]~/^dns_records\?name=[A-Za-z0-9.%_-]+&type=(A|AAAA)&per_page=50$/) {
            hw_kind="dns"; split(p[3],q,"&"); hw_name=substr(q[1],18); hw_type=substr(q[2],6)
            if(hw_name~/%/ && hw_name!~/^%2A\.[A-Za-z0-9._-]+$/) exit 1
        } else exit 1
    } else if(p[1]=="accounts" && hw_id(p[2]) && p[3]=="rules" && p[4]=="lists" && hw_id(p[5])) {
        hw_resource=p[5]
        if(count==5) hw_kind="list"; else if(count==6 && p[6]=="items?per_page=50") hw_kind="items"; else exit 1
    } else if(p[1]=="accounts" && hw_id(p[2]) && p[3]=="cfd_tunnel" && hw_uuid(p[4])) {
        hw_resource=p[4]
        if(count==4) hw_kind="tunnel"; else if(count==5 && p[5]=="connections") hw_kind="connections"; else exit 1
    } else exit 1
    hw_url=url
}
function hw_frame(path,kind,    raw,line,a,n) {
    raw=hw_read(path,8192,0)
    if(kind=="response" && index(raw,"CFMGR-HEALTH-RESPONSE 2 ")==1) {hw_values(path,"","");return}
    if(raw~/[^ -~\n]/ || index(substr(raw,1,length(raw)-1),"\n")) exit 1
    line=substr(raw,1,length(raw)-1); n=split(line,a," ")
    if(kind=="http") { if(length(raw)!=4 || line!~/^[0-5][0-9][0-9]$/) exit 1; return }
    if(kind=="scope") {
        if(n!=11 || a[1]!="CFMGR-HEALTH-SCOPE" || a[2]!="1" || a[11]!="END" || a[3]!~/^(eligible|unconfigured|historical-auth|historical-throttle|historical-unknown|eligibility-unproved|resource-local-only|credential-local-only|unsupported-runtime-auth|unsupported-scope)$/ || a[4]!~/^(ddns|ip_sync|cloudflared)$/ || a[5]!~/^[A-Za-z0-9._-]+$/ || a[6]!~/^(zone|dns|list|items|tunnel|connections|trace)$/ || a[7]!~/^[0-9a-f-]+$/ || a[8]!~/^(-|[0-9a-f]+)$/ || a[9]!~/^(-|A|AAAA|4|6)$/ || a[10]!~/^(0|[1-9][0-9]*)$/ || a[10]>4352) exit 1
    } else if(kind=="response") {
        if(n!=6 || a[1]!="CFMGR-HEALTH-RESPONSE" || a[2]!="1" || a[3]!~/^(verified|partial|observed)$/ || a[4]!~/^(0|[1-9][0-9]*)$/ || a[4]>4096 || a[5]!~/^(api-read|ipv[46]:[0-9a-f:.]+)$/ || a[6]!="END") exit 1
    } else exit 1
    if(line!=a[1]) { hw_rebuilt=a[1]; for(hw_i=2;hw_i<=n;hw_i++) hw_rebuilt=hw_rebuilt " " a[hw_i]; if(hw_rebuilt!=line) exit 1 }
}
# Canonicalize only after the existing ingestion validators succeed. Provider
# receipts retain no raw addresses, names, identifiers or credentials.
function hw_hex_value(value,    i,n) {
    n=0;for(i=1;i<=length(value);i++)n=n*16+index("0123456789abcdef",substr(value,i,1))-1
    return n
}
function hw_canonical(value,family,    a,tail,prefix,pos,left,right,na,nb,la,ra,i,out,zeros) {
    if(family=="4") {split(value,a,".");for(i=1;i<=4;i++)out=out sprintf("%02x",a[i]+0);return out}
    value=tolower(value)
    if(index(value,".")) {
        tail=value;sub(/^.*:/,"",tail);prefix=substr(value,1,length(value)-length(tail));split(tail,a,".")
        value=prefix sprintf("%04x:%04x",a[1]*256+a[2],a[3]*256+a[4])
    }
    pos=index(value,"::")
    if(pos) {
        left=substr(value,1,pos-1);right=substr(value,pos+2)
        na=(left=="" ? 0 : split(left,la,":"));nb=(right=="" ? 0 : split(right,ra,":"));zeros=8-na-nb
        for(i=1;i<=na;i++)out=out sprintf("%04x",hw_hex_value(la[i]))
        for(i=1;i<=zeros;i++)out=out "0000"
        for(i=1;i<=nb;i++)out=out sprintf("%04x",hw_hex_value(ra[i]))
    } else {split(value,a,":");for(i=1;i<=8;i++)out=out sprintf("%04x",hw_hex_value(a[i]))}
    return out
}
function hw_values(path,expected_kind,expected_family,    raw,lines,a,n,i,c,key,family,width,prefix) {
    raw=hw_read(path,4096,0);n=split(raw,lines,"\n")
    if(n<3 || split(lines[1],a," ")!=6 || a[1]!="CFMGR-HEALTH-RESPONSE" || a[2]!="2" || a[3]!~/^(verified|partial)$/ || a[4]!~/^(0|[1-9][0-9]*)$/ || a[4]>50 || a[5]!~/^(dns|items)$/ || a[6]!~/^(4|6|mixed)$/ || lines[1]!=a[1] " " a[2] " " a[3] " " a[4] " " a[5] " " a[6])exit 1
    hw_value_state=a[3];hw_value_count=a[4]+0;hw_value_kind=a[5];hw_value_family=a[6]
    if((expected_kind!="" && hw_value_kind!=expected_kind) || (expected_family!="" && hw_value_family!=expected_family) || n!=hw_value_count+3 || lines[n-1]!="END " hw_value_count)exit 1
    if(hw_value_kind=="dns" ? hw_value_family!~/^[46]$/ : hw_value_family!="mixed")exit 1
    for(key in hw_value_address)delete hw_value_address[key]
    for(i=2;i<n-1;i++) {
        c=split(lines[i],a," ");family=a[2];width=(family=="4" ? 32 : 128);prefix=a[4]
        if(c!=4 || a[1]!="VALUE" || family!~/^[46]$/ || a[3]~/[^0-9a-f]/ || length(a[3])!=(family=="4" ? 8 : 32) || prefix!~/^(0|[1-9][0-9]*)$/ || length(prefix)>3 || prefix>width || prefix<(family=="4" ? 8 : 12) || lines[i]!="VALUE " family " " a[3] " " prefix)exit 1
        if(hw_value_kind=="dns" && (family!=hw_value_family || prefix!=width))exit 1
        hw_value_address[i-1]=a[3];hw_value_prefix[i-1]=prefix+0;hw_value_address_family[i-1]=family
    }
}
function hw_bits_match(address,network,bits,    full,remaining,i,mask) {
    full=int(bits/4);remaining=bits-full*4
    for(i=1;i<=full;i++)if(substr(address,i,1)!=substr(network,i,1))return 0
    if(!remaining)return 1
    # Vendor BusyBox AWK omits optional libm/exponentiation support.
    mask=(remaining==1 ? 8 : (remaining==2 ? 4 : 2))
    return int(hw_hex_value(substr(address,full+1,1))/mask)==int(hw_hex_value(substr(network,full+1,1))/mask)
}
function hw_ipv4(value,    a,n,i) { n=split(value,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function hw_public4(value,    a) {
    if(!hw_ipv4(value)) return 0; split(value,a,".")
    return !(a[1]==0 || a[1]==10 || a[1]==127 || a[1]>=224 || (a[1]==100 && a[2]>=64 && a[2]<=127) || (a[1]==169 && a[2]==254) || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && (a[2]==168 || (a[2]==0 && (a[3]==0 || a[3]==2)))) || (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) || (a[1]==203 && a[2]==0 && a[3]==113))
}
function hw_ipv6(value,    a,n,i,groups,double) {
    if(length(value)>39 || value~/[^0-9a-f:]/ || value!~/^[23][0-9a-f][0-9a-f][0-9a-f]:/ || value~/^2001:0?db8:/ || value~/:::/) return 0
    double=index(value,"::"); if(double && index(substr(value,double+2),"::")) return 0
    n=split(value,a,":"); groups=0; for(i=1;i<=n;i++) if(a[i]!="") { if(length(a[i])>4 || a[i]!~/^[0-9a-f]+$/) return 0; groups++ }
    if((substr(value,1,1)==":" && substr(value,1,2)!="::") || (substr(value,length(value),1)==":" && substr(value,length(value)-1)!="::")) return 0
    return double ? groups<8 : groups==8
}
function hw_address6(value,    a,n,i,groups,double,tail) {
    value=tolower(value)
    if(length(value)>45 || value~/[^0-9a-f:.]/) return 0
    if(index(value,".")) {
        tail=value; sub(/^.*:/,"",tail)
        if(!hw_ipv4(tail) || tail==value) return 0
        value=substr(value,1,length(value)-length(tail)) "0:0"
    }
    if(value~/:::/) return 0
    double=index(value,"::"); if(double && index(substr(value,double+2),"::")) return 0
    n=split(value,a,":"); groups=0
    for(i=1;i<=n;i++) if(a[i]!="") { if(length(a[i])>4 || a[i]!~/^[0-9a-f]+$/) return 0; groups++ }
    if((substr(value,1,1)==":" && substr(value,1,2)!="::") || (substr(value,length(value),1)==":" && substr(value,length(value)-1)!="::")) return 0
    return double ? groups<8 : groups==8
}
function hw_list_ip(value,    a,n,v6) {
    n=split(value,a,"/"); if(n<1 || n>2) return 0
    v6=index(a[1],":")>0
    if(v6 ? !hw_address6(a[1]) : !hw_ipv4(a[1])) return 0
    if(n==1) return 1
    return a[2]~/^(0|[1-9][0-9]*)$/ && length(a[2])<=3 && (v6 ? a[2]>=12 && a[2]<=128 : a[2]>=8 && a[2]<=32)
}
function hw_trace(    raw,a,n,i,ip,count,family) {
    raw=hw_read(ENVIRON["CFMGR_HEALTH_INPUT"],32768,ENVIRON["CFMGR_HEALTH_BYTES"])
    if(raw~/[^ -~\n]/) exit 1
    n=split(raw,a,"\n"); for(i=1;i<=n;i++) if(substr(a[i],1,3)=="ip=") { ip=tolower(substr(a[i],4)); count++ }
    family=ENVIRON["CFMGR_HEALTH_KIND"]
    if(count!=1 || (family=="4" ? !hw_public4(ip) : (family!="6" || !hw_ipv6(ip)))) exit 1
    printf "CFMGR-HEALTH-RESPONSE 1 observed 1 ipv%s:%s END\n",family,ip
}
'
	# CFMGR-AWK-END health_wire
}

cfmgr_status_awk_health_response() {
	# CFMGR-AWK-BEGIN health_response
	cfmgr_awk_program='
BEGIN {
    if(!cfmgr_json_tree_ready) reject()
    for(hr_i=2;hr_i<=cfmgr_json_tree_count;hr_i++) hr_child[cfmgr_json_tree_parent[hr_i],cfmgr_json_tree_location[hr_i]]=hr_i
    hw_frame(ENVIRON["CFMGR_HEALTH_SCOPE"],"scope")
    hr_scope=hw_read(ENVIRON["CFMGR_HEALTH_SCOPE"],8192,0); split(hr_scope,hr_saved," ")
    hw_request(ENVIRON["CFMGR_HEALTH_INPUT"],ENVIRON["CFMGR_HEALTH_BYTES"])
    if(hr_saved[3]!="eligible" || hr_saved[6]!=hw_kind || hr_saved[7]!=hw_resource) reject()
    if(cfmgr_json_tree_kind[1]!="object" || cfmgr_json_tree_kind[hr_field(1,"success")]!="true") reject()
    hr_errors=hr_field(1,"errors"); if(cfmgr_json_tree_kind[hr_errors]!="array" || hr_child[hr_errors,"i0"]) reject()
    hr_result=hr_field(1,"result"); hr_count=0; hr_state="verified"
    if(hw_kind~/^(zone|list|tunnel)$/) {
        if(cfmgr_json_tree_kind[hr_result]!="object" || hr_text(hr_field(hr_result,"id"),64)!=hw_resource) reject()
        if(hw_kind=="list" && (hr_hex(hr_text(hr_field(hr_result,"name"),128))!=hr_saved[8] || hr_text(hr_field(hr_result,"kind"),16)!="ip")) reject()
        hr_count=1
    } else {
        if(cfmgr_json_tree_kind[hr_result]!="array") reject()
        for(hr_j=0;(hr_item=hr_child[hr_result,"i" hr_j]);hr_j++) {
            if(cfmgr_json_tree_kind[hr_item]!="object") reject()
            hr_value=hr_text(hr_field(hr_item,"id"),64)
            if(hw_kind=="connections" ? !hw_uuid(hr_value) : !hw_id(hr_value)) reject()
            if(hw_kind=="dns" && (hr_hex(tolower(hr_text(hr_field(hr_item,"name"),253)))!=hr_saved[8] || hr_text(hr_field(hr_item,"type"),8)!=hr_saved[9])) reject()
            if(hw_kind=="dns") {
                hr_content=hr_text(hr_field(hr_item,"content"),45)
                if(hr_saved[9]=="A" ? !hw_ipv4(hr_content) : !hw_address6(hr_content)) reject()
                hr_proxy=cfmgr_json_tree_kind[hr_field(hr_item,"proxied")]
                hr_ttl=hr_uint(hr_field(hr_item,"ttl"))
                if(hr_proxy!~/^(true|false)$/ || (hr_ttl!=1 && (hr_ttl<30 || hr_ttl>86400))) reject()
            }
            if(hw_kind=="items") {
                hr_content=hr_text(hr_field(hr_item,"ip"),64);if(!hw_list_ip(hr_content))reject()
            }
            if(hw_kind=="dns" || hw_kind=="items") {
                hr_family=(index(hr_content,":") ? "6" : "4");hr_width=(hr_family=="4" ? 32 : 128)
                hr_parts=split(hr_content,hr_network,"/");hr_prefix=(hr_parts==1 ? hr_width : hr_network[2]+0)
                hr_values=hr_values "VALUE " hr_family " " hw_canonical(hr_network[1],hr_family) " " hr_prefix "\n"
            }
            hr_count++
            if((hw_kind=="dns" || hw_kind=="items") && hr_count>50)reject()
        }
        if(hw_kind=="items") {
            hr_info=hr_field(1,"result_info"); hr_cursors=hr_field(hr_info,"cursors")
            if(cfmgr_json_tree_kind[hr_info]!="object" || cfmgr_json_tree_kind[hr_cursors]!="object") hr_state="partial"
            else {
                hr_after=hr_field(hr_cursors,"after"); hr_before=hr_field(hr_cursors,"before")
                if((hr_after && cfmgr_json_tree_kind[hr_after]!="string") || (hr_before && cfmgr_json_tree_kind[hr_before]!="string")) hr_state="partial"
                else if((hr_after && hr_text(hr_after,2048)!="") || (hr_before && length(hr_text(hr_before,2048))>2048)) hr_state="partial"
            }
        } else if(hw_kind=="dns") {
            hr_info=hr_field(1,"result_info")
            hr_page=hr_uint(hr_field(hr_info,"page")); hr_pages=hr_uint(hr_field(hr_info,"total_pages"))
            hr_total=hr_uint(hr_field(hr_info,"total_count")); hr_seen=hr_uint(hr_field(hr_info,"count"))
            if(hr_page!=1 || hr_pages!=1 || hr_total!=hr_count || hr_seen!=hr_count) hr_state="partial"
        }
    }
    if(hw_kind=="dns" || hw_kind=="items") {
        hr_output="CFMGR-HEALTH-RESPONSE 2 " hr_state " " hr_count " " hw_kind " " (hw_kind=="dns" ? (hr_saved[9]=="A" ? "4" : "6") : "mixed") "\n" hr_values "END " hr_count "\n"
        if(length(hr_output)>4096)reject()
        printf "%s",hr_output
    } else printf "CFMGR-HEALTH-RESPONSE 1 %s %d api-read END\n",hr_state,hr_count
    exit 0
}
function hr_hex(value,    i,out) { out=""; for(i=1;i<=length(value);i++) out=out byte_hex[byte_value["b" substr(value,i,1)]]; return out }
function hr_field(parent,key) { return hr_child[parent,"k" hr_hex(key)] }
function hr_text(id,limit,    value,i,code,out) {
    if(cfmgr_json_tree_kind[id]!="string") reject()
    value=substr(cfmgr_json_tree_payload[id],2); if(length(value)>limit*2) reject()
    out=""; for(i=1;i<=length(value);i+=2) { code=hex_value["h" substr(value,i,1)]*16+hex_value["h" substr(value,i+1,1)]; if(code<32 || code>126) reject(); out=out sprintf("%c",code) }; return out
}
function hr_uint(id,    value) { if(cfmgr_json_tree_kind[id]!="number") return -1; value=substr(cfmgr_json_tree_payload[id],2); return value~/^(0|[1-9][0-9]*)$/ && length(value)<=7 ? value+0 : -1 }
'
	# CFMGR-AWK-END health_response
}

cfmgr_status_awk_health_render() {
	# CFMGR-AWK-BEGIN health_render
	cfmgr_awk_program='
# Arguments: width, bounded raw status-work text path, and rows path or -.
# Input is entirely validated and the bounded output built before stdout begins.
BEGIN {
    width = ARGV[1]; dashboard_path = ARGV[2]; rows_path = ARGV[3]
    ARGV[1] = ARGV[2] = ARGV[3] = ""; ARGC = 1
    if (width !~ /^(10|[1-9][0-9]|100)$/ || width > 100 || dashboard_path == "" || rows_path == "") fail()
    group_order[1]="Router/resources"; group_order[2]="Manager"; group_order[3]="Network"
    group_order[4]="DDNS"; group_order[5]="IP-Sync"; group_order[6]="Cloudflared"; group_order[7]="Integrations"
    dashboard_bytes = 0; dashboard_count = 0; header_count=0; footer_count=0
    current_group="Router/resources"; current_feature=""
    while ((got = getline line < dashboard_path) == 1) {
        dashboard_bytes += length(line) + 1
        if (dashboard_bytes > 16384 || line ~ /[^ -~]/ || length(line) > 16384) fail()
        clean=line; sub(/^[ ]+/,"",clean)
        if (clean == "") continue
        if (index(clean,"CFMgr ")==1) { header[++header_count]=clean; continue }
        if (index(clean,"Status uses local evidence")==1) { footer[++footer_count]=clean; continue }
        if (index(clean,"DDNS: configured=")==1) { current_group="DDNS"; current_feature="DDNS" }
        else if (index(clean,"IP-Sync: configured=")==1) { current_group="IP-Sync"; current_feature="IP-Sync" }
        else if (index(clean,"Cloudflared: configured=")==1) { current_group="Cloudflared"; current_feature="Cloudflared" }
        else if (index(clean,"Recent DDNS ")==1) { current_group="DDNS"; current_feature="DDNS" }
        else if (index(clean,"Recent IP-Sync ")==1) { current_group="IP-Sync"; current_feature="IP-Sync" }
        else if (index(clean,"Recent Cloudflared ")==1) { current_group="Cloudflared"; current_feature="Cloudflared" }
        else if (line ~ /^ +/ && current_feature!="") { }
        else if (index(clean,"uptime:")==1 || index(clean,"load:")==1 || index(clean,"memory:")==1 ||
            index(clean,"Resources:")==1 || index(clean,"productid:")==1 || index(clean,"firmver:")==1 ||
            index(clean,"buildno:")==1 || index(clean,"extendno:")==1 || index(clean,"/jffs ")==1 || index(clean,"/opt ")==1) {
            current_group="Router/resources"; current_feature=""
        }
        else if (index(clean,"Selected WAN:")==1 || index(clean,"WAN interface")==1 || index(clean,"ntp_ready:")==1 ||
            index(clean,"Recorded public IPv4")==1 || index(clean,"Recorded eligible IPv6")==1 ||
            index(clean,"Issue: invalid selected WAN")==1) { current_group="Network"; current_feature="" }
        else if (index(clean,"Configuration:")==1 || index(clean,"Manager ")==1 || index(clean,"Installation:")==1 ||
            index(clean,"Issue: retained setup")==1 || index(clean,"Issue: pending configuration Save")==1 ||
            index(clean,"DDNS/IP-Sync/Cloudflared:")==1 || index(clean,"Provider history:")==1 ||
            index(clean,"Note: developer mode")==1) { current_group="Manager"; current_feature="" }
        else if (index(clean,"Issue: retained storage observation")==1 || index(clean,"Issue: native probe budget")==1) {
            current_group="Integrations"; current_feature=""
        }
        # Unknown safe lines retain their current group; default is Router/resources.
        dashboard_group[++dashboard_count]=current_group
        dashboard_text[dashboard_count]=clean
        dashboard_indent[dashboard_count]=(line ~ /^ +/ ? "    " : "  ")
    }
    close(dashboard_path)
    if (got < 0 || (!dashboard_count && !header_count && !footer_count)) fail()

    row_count = 0; group_count = 0
    if (rows_path != "-") {
        while ((got = getline line < rows_path) == 1) {
            if (++row_count > 96 || line ~ /[^ -~\t]/ || length(line) > 1228) fail()
            n = split(line, f, "\t")
            if (n != 6 || !safe_field(f[1],64) || !safe_field(f[3],512) ||
                !safe_field(f[4],64) || !safe_field(f[5],512) || !safe_field(f[6],64)) fail()
            if (f[1] !~ /^[A-Za-z0-9][A-Za-z0-9._-]*$/ || f[2] !~ /^(PASS|FAIL|WARN|SKIP|UNKNOWN)$/) fail()
            if (f[3] == "" || f[4] == "" || f[5] == "" || f[6] == "") fail()
            if (f[1] in seen) fail()
            seen[f[1]] = 1
            rid[row_count] = f[1]; state[row_count] = f[2]; detail[row_count] = f[3]
            age[row_count] = f[4]; next_action[row_count] = f[5]; dependency[row_count] = f[6]
            dot = index(f[1], "."); prefix = dot ? substr(f[1],1,dot-1) : f[1]
            row_group[row_count] = prefix
            if (!(prefix in group_seen)) { group_seen[prefix] = 1; groups[++group_count] = prefix }
        }
        close(rows_path)
        if (got < 0 || row_count == 0) fail()
    }

    if (rows_path != "-") {
        emit_wrapped("", "Issue summary")
        issues = 0
        for (severity=1; severity<=3; severity++) {
            wanted=(severity==1 ? "FAIL" : severity==2 ? "WARN" : "UNKNOWN")
            for (i=1; i<=row_count; i++) if (state[i] == wanted) {
                emit_wrapped("- ", rid[i] " [" state[i] "]")
                issues++
            }
        }
        if (!issues) emit_wrapped("- ", "None")
        append_line("")
    }
    for (i=1; i<=header_count; i++) emit_wrapped("",header[i])
    for (g=1; g<=7; g++) {
        present=0
        for (i=1; i<=dashboard_count; i++) if (dashboard_group[i] == group_order[g]) present=1
        if (!present) continue
        emit_wrapped("", group_order[g])
        for (i=1; i<=dashboard_count; i++) if (dashboard_group[i] == group_order[g])
            emit_wrapped(dashboard_indent[i], dashboard_text[i])
        append_line("")
    }
    if (rows_path != "-") {
        for (g=1; g<=group_count; g++) {
            if (g>1) append_line("")
            emit_wrapped("", "== " groups[g] " ==")
            for (i=1; i<=row_count; i++) if (row_group[i] == groups[g]) {
                emit_wrapped("  ", "Check: " rid[i] " [" state[i] "]")
                emit_field("Detail",detail[i]); emit_field("Age",age[i])
                emit_field("Next",next_action[i]); emit_field("Dependency",dependency[i])
            }
        }
    }
    for (i=1; i<=footer_count; i++) emit_wrapped("",footer[i])
    for (i=1; i<=out_count; i++) print output[i]
    exit 0
}
function safe_field(s,limit) { return length(s) <= limit && s !~ /[^ -~]/ }
function fail() {
    # Never disguise validation failure as a successfully produced report.
    # The controller owns the fixed safe fallback and preserves native evidence.
    exit 1
}
function append_line(s) {
    if (length(s) > width || output_bytes + length(s) + 1 > 196608) fail()
    output[++out_count] = s; output_bytes += length(s) + 1
}
# Preserve word boundaries; only split a token when it cannot fit on one line.
function emit_wrapped(prefix,s,    n,words,i,word,line,continuation,room,part) {
    line=prefix; continuation=" "
    n=split(s,words,/ +/)
    for (i=1; i<=n; i++) {
        word=words[i]
        if (word=="") continue
        if (length(line) && length(line)+1+length(word)<=width) line=line " " word
        else if (line==prefix || line==continuation) line=continuation word
        else if (length(line) && length(line)<width) { append_line(line); line=continuation word }
        else if (length(line)==0 || line==continuation) line=line word
        else { append_line(line); line=continuation word }
        while (length(line)>width) {
            room=width
            part=substr(line,1,room); append_line(part)
            line=continuation substr(line,room+1)
        }
    }
    append_line(line)
}
function emit_field(label,value) {
    emit_wrapped("  ", label ":")
    emit_wrapped("    ", value)
}
'
	# CFMGR-AWK-END health_render
}

cfmgr_status_awk_health_cloud() {
	# CFMGR-AWK-BEGIN health_cloud
	cfmgr_awk_program='
# Three separate private projections. Only the path/policy plan is shell-readable.
BEGIN {
    if(!co_observation_ready || co_version!="n2")reject()
    hc=cs_id(1,"cloudflared"); refs=cs_id(hc,"credential_refs"); paths=cs_id(hc,"paths")
    registry=cs_id(1,"credentials"); mode=ENVIRON["CFMGR_HEALTH_CLOUD"]
    runtime_ref=cs_string(refs,"runtime",1); cert_ref=cs_string(refs,"certificate",1)
    runtime=(runtime_ref=="" ? 0 : cs_credentials[runtime_ref]); cert=(cert_ref=="" ? 0 : cs_credentials[cert_ref])
    method=cs_string(hc,"method",1); generation=cs_generation(1,"generation")
    if(mode=="runtime-authority") {
        if(method!="advanced" || !runtime)exit 1
        out="CFMGR-AUTH 1 " co_hex(runtime_ref) " " co_hex(cs_string(runtime,"account_tag",0)) " " cs_uuid(cs_string(runtime,"tunnel_id",0)) " " co_hex(cs_string(runtime,"tunnel_secret",0)) " END\n"
    } else if(mode=="certificate-account") {
        if(!cert)exit 1
        out="CFMGR-CERT-ACCOUNT 1 " co_hex(cs_string(cert,"account_id",0)) " END\n"
    } else if(mode=="plan") {
        hc_line("CFMGR-CLOUD-PLAN\t1")
        hc_line("STATE\t" cs_bool(hc,"configured") "\t" cs_bool(hc,"enabled") "\t" cs_bool(hc,"installed") "\t" cs_bool(hc,"maintenance_enabled") "\t" (method=="" ? "-" : method))
        auto=cs_id(hc,"binary_auto_update"); watchdog=cs_policy(hc,"watchdog"); ready=cs_policy(hc,"readiness")
        hc_line("POLICY\t" (cfmgr_json_tree_kind[auto]=="null" ? "-" : (cfmgr_json_tree_kind[auto]=="true" ? "1" : "0")) "\t" (watchdog ? "1" : "0") "\t" (watchdog ? cs_int(watchdog,"reconnect_grace_seconds","1","300") : "-") "\t" (watchdog ? cs_int(watchdog,"stability_seconds","60","3600") : "-"))
        hc_line("READINESS\t" (ready ? cs_int(ready,"response_timeout_seconds","1","2") : "-") "\t" (ready ? cs_int(ready,"command_timeout_seconds","1","3") : "-"))
        owners=cs_id(cs_id(1,"ownership"),"components")
        hc_file("yaml",cs_string(paths,"yaml",1),"data.cloudflared.yaml",0)
        hc_file("json",cs_string(paths,"json",1),"data.cloudflared.json",0)
        hc_file("certificate",(cert ? cs_string(cert,"path",0) : ""),"data.cloudflared.certificate",cert)
        hc_file("certificate-recovery",(cert ? cs_string(cert,"recovery_path",0) : ""),"data.cloudflared.certificate-recovery",cert)
        hc_file("binary","/opt/bin/cloudflared","cloudflared",0)
        hc_line("AUTH\t" (runtime ? length(co_hex(runtime_ref))/2 : 0) "\t" (method=="advanced" && runtime ? length(co_hex(cs_string(runtime,"account_tag",0)))/2 : 0) "\t" (method=="advanced" && runtime ? length(co_hex(cs_string(runtime,"tunnel_secret",0)))/2 : 0) "\t" (cert ? length(co_hex(cs_string(cert,"account_id",0)))/2 : 0))
        hc_line("CERT\t" (cert ? cs_string(cert,"provenance",0) : "-") "\t" (cert ? "1" : "0"))
        for(i=0;(item=co_child[owners,"i" i]);i++)if(cs_string(item,"component",0)~/^data\.cloudflared\.input\.[A-Za-z][A-Za-z0-9._-]*$/) {
            p=cs_string(item,"path",0);gen=cs_generation(item,"generation");sha=cs_string(item,"sha256",1)
            hc_line("INPUT-OWNER\t" (hc_path(p) ? "supported" : "unsupported") "\t" (hc_path(p) ? p : "-") "\t" (cs_le(gen,generation) ? "matched" : "conflict") "\t" gen "\t" (sha=="" ? "-" : sha))
        }
        out=out "END\t" rows "\n"
        if(length(out)>32768)reject()
    } else reject()
    if(length(out)>131072)reject()
    printf "%s",out;exit
}
function hc_line(s) { out=out s "\n";rows++ }
function hc_path(p,    a,n,i) {
    if(p=="" || length(p)>1024 || p!~/^\// || p~/[^ -~]/ || index(p,"\\") || p~/\/$/)return 0
    n=split(p,a,"/");for(i=2;i<=n;i++)if(a[i]=="" || a[i]=="." || a[i]=="..")return 0
    return 1
}
function hc_file(role,path,component,cert,    i,item,state,gen,hash,found,supported) {
    state="none";gen=hash="-";found=0
    for(i=0;(item=co_child[owners,"i" i]);i++)if(cs_string(item,"component",0)==component) {
        found++;state="matched";gen=cs_generation(item,"generation");hash=cs_string(item,"sha256",1)
        if(hash=="")hash="-"
        if(cs_string(item,"path",0)!=path || !cs_le(gen,generation))state="conflict"
        if(cert && (gen!=cs_generation(cert,"generation") || hash!=cs_string(cert,"sha256",0)))state="conflict"
    }
    if(found>1)state="conflict"
    if(cert && !found) {gen=cs_generation(cert,"generation");hash=cs_string(cert,"sha256",0);if(!cs_le(gen,generation))state="conflict"}
    supported=(path=="" ? "absent" : (hc_path(path) ? "supported" : "unsupported"))
    hc_line("FILE\t" role "\t" supported "\t" (supported=="supported" ? path : "-") "\t" state "\t" gen "\t" hash)
}
'
	# CFMGR-AWK-END health_cloud
}

cfmgr_status_awk_health_selected() {
	# CFMGR-AWK-BEGIN health_selected
	cfmgr_awk_program='
# Fixed private metadata and YAML/authority join. No authority becomes output.
function hs_fail() { bad=1;exit 1 }
function hs_unhex(s,    i,n,out) {
    if(s=="" || length(s)%2 || s~/[^0-9a-f]/)hs_fail()
    for(i=1;i<=length(s);i+=2) {
        n=(index("0123456789abcdef",substr(s,i,1))-1)*16+index("0123456789abcdef",substr(s,i+1,1))-1
        if(n<32 || n>126)hs_fail();out=out sprintf("%c",n)
    };return out
}
function hs_path(p,    a,n,i) {
    if(p=="/")return p
    if(length(p)>1024 || p!~/^\// || p~/[^ -~]/ || index(p,"\\"))hs_fail()
    n=split(p,a,"/");for(i=2;i<=n;i++)if(a[i]=="" || a[i]=="." || a[i]=="..")hs_fail()
    return p
}
function hs_read(p,max,    saved,raw,extra,n) {
    saved=RS;RS=sprintf("%c",28);n=getline raw <p
    if(n<0 || (getline extra <p)>0 || length(raw)>max || raw~/[^ -~\n\t]/ || substr(raw,length(raw),1)!="\n")hs_fail()
    close(p);RS=saved;return raw
}
function hs_uint(s,max) { return s~/^(0|[1-9][0-9]*)$/ && length(s)<=length(max) && (length(s)<length(max) || "n" s<="n" max) }
function hs_hash(s) { return s=="-" || (length(s)==64 && s!~/[^0-9a-f]/) }
function hs_generation(s) { return s=="-" || (s~/^[1-9][0-9]*$/ && length(s)<=20) }
function hs_plan(path,    raw,lines,n,i,a,c,roles) {
    raw=hs_read(path,32768);n=split(raw,lines,"\n");split("yaml json certificate certificate-recovery binary",roles," ")
    if(n<13 || lines[1]!="CFMGR-CLOUD-PLAN\t1")hs_fail()
    for(i=2;i<n;i++) {
        c=split(lines[i],a,"\t")
        if(i==2) {if(c!=6 || a[1]!="STATE" || a[2]!~/^[01]$/ || a[3]!~/^[01]$/ || a[4]!~/^[01]$/ || a[5]!~/^[01]$/ || a[6]!~/^(-|token|advanced)$/)hs_fail()}
        else if(i==3) {if(c!=5 || a[1]!="POLICY" || a[2]!~/^(-|0|1)$/ || a[3]!~/^[01]$/ || (a[3]==0 ? (a[4]!="-" || a[5]!="-") : (!hs_uint(a[4],"300") || a[4]+0<1 || !hs_uint(a[5],"3600") || a[5]+0<60)))hs_fail()}
        else if(i==4) {if(c!=3 || a[1]!="READINESS" || (a[2]=="-" ? a[3]!="-" : (!hs_uint(a[2],"2") || a[2]+0<1 || !hs_uint(a[3],"3") || a[3]+0<a[2]+0)))hs_fail()}
        else if(i>=5 && i<=9) {
            if(c!=7 || a[1]!="FILE" || a[2]!=roles[i-4] || a[3]!~/^(supported|unsupported|absent)$/ || a[5]!~/^(none|matched|conflict)$/ || !hs_generation(a[6]) || !hs_hash(a[7]))hs_fail()
            if(a[3]=="supported")hs_path(a[4]);else if(a[4]!="-")hs_fail()
        } else if(i==10) {if(c!=5 || a[1]!="AUTH" || !hs_uint(a[2],"65536") || !hs_uint(a[3],"65536") || !hs_uint(a[4],"65536") || !hs_uint(a[5],"65536"))hs_fail()}
        else if(i==11) {if(c!=3 || a[1]!="CERT" || a[2]!~/^(-|login|import|migration|repair)$/ || a[3]!~/^[01]$/ || ((a[2]=="-")!=(a[3]==0)))hs_fail()}
        else if(i==n-1) {if(c!=2 || a[1]!="END" || a[2]!=(n-2) "")hs_fail()}
        else {
            if(c!=6 || a[1]!="INPUT-OWNER" || a[2]!~/^(supported|unsupported)$/ || a[4]!~/^(matched|conflict)$/ || !hs_generation(a[5]) || a[5]=="-" || !hs_hash(a[6]))hs_fail()
            if(a[2]=="supported")hs_path(a[3]);else if(a[3]!="-")hs_fail()
        }
    }
}
function hs_join_frame(path,    raw,n,lines,a,i,c,total) {
    raw=hs_read(path,262144)
    if(raw=="CFMGR-CLOUD-YAML-MISMATCH 1 END\n")return
    n=split(raw,lines,"\n");if(n<3 || split(lines[1],a,"\t")!=4 || a[1]!="CFMGR-CLOUD-YAML" || a[2]!="1" || !hs_uint(a[3],"65536") || !hs_uint(a[4],"65536"))hs_fail()
    total=a[3]+0;if(n!=total+3)hs_fail()
    for(i=2;i<n-1;i++) {
        c=split(lines[i],a,"\t")
        if(c!=7 || a[1]!="INPUT" || a[2]!=(i-1) "" || a[3]!~/^(origincert|cacert|origin-ca-pool|caPool)$/ || a[5]!~/^(external|matched|conflict)$/ || !hs_generation(a[6]) || !hs_hash(a[7]))hs_fail()
        hs_path(a[4])
    }
    if(lines[n-1]!="END\t" total)hs_fail()
}
BEGIN {
    mode=ARGV[1];input=ARGV[2];profile=ARGV[3];spec=ARGV[4];plan=ARGV[5];ARGC=1
    if(mode=="frame-plan") {hs_plan(input);exit}
    if(mode=="frame-join") {hs_join_frame(input);exit}
    if(mode=="metadata") {
        if(profile!~/^(private|public|executable)$/)hs_fail()
        n=split(spec,wanted,"\n");if(n<1 || n>13)hs_fail()
        for(i=1;i<=n;i++) {hs_path(wanted[i]);if(expected[wanted[i]]++)hs_fail()}
        raw=hs_read(input,32768);count=split(raw,lines,"\n");if(count!=n+1)hs_fail()
        for(i=1;i<count;i++) {
            rest=lines[i]
            for(j=1;j<=9;j++) {
                sub(/^ +/,"",rest);if(!match(rest,/^[^ ]+/))hs_fail()
                f[j]=substr(rest,1,RLENGTH);rest=substr(rest,RLENGTH+1)
            }
            sub(/^ +/,"",rest);if(!(rest in expected) || seen[rest]++)hs_fail()
            if(f[1]!~/^[1-9][0-9]*$/ || length(f[1])>20 || f[3]!~/^[1-9][0-9]*$/ || f[4]!="0" || f[5]!~/^[0-9]+$/ || f[6]!~/^(0|[1-9][0-9]*)$/ || length(f[6])>10 || length(f[2])!=10 || substr(f[2],6,1)=="w" || substr(f[2],9,1)=="w")hs_fail()
            if(rest==ENVIRON["CFMGR_HEALTH_SELECTED_PATH"]) {
                if(substr(f[2],1,1)!="-" || (profile=="private" && f[2]!="-rw-------") || (profile=="executable" && substr(f[2],4,1)!="x"))hs_fail()
                inode=f[1];bytes=f[6]
            } else if(substr(f[2],1,1)!="d")hs_fail()
        }
        print "CFMGR-SELECTED 1 " (inode=="" ? "-" : inode) " " (bytes=="" ? "-" : bytes) " END";exit
    }
    if(mode!="yaml-join")hs_fail()
    raw=hs_read(profile,131072);sub(/\n$/,"",raw)
    if(index(raw,"\n") || split(raw,a," ")!=7 || raw!="CFMGR-AUTH 1 " a[3] " " a[4] " " a[5] " " a[6] " END" || a[1]!="CFMGR-AUTH" || a[2]!="1" || a[7]!="END")hs_fail()
    uuid=a[5]
    if(plan!="-") {
        hs_plan(plan)
        raw=hs_read(plan,32768);n=split(raw,lines,"\n")
        for(i=1;i<n;i++)if(split(lines[i],a,"\t")==6 && a[1]=="INPUT-OWNER" && a[2]=="supported") {
            p=hs_path(a[3]);if(p in owner)owner[p]="conflict";else owner[p]=a[4]
            ownergen[p]=a[5];ownerhash[p]=a[6]
        }
    }
    raw=hs_read(input,262144);n=split(raw,lines,"\n")
    if(n<4 || lines[1]!="CFMGR-YAML 1" || split(lines[2],a," ")!=3 || a[1]!="IDENTITY")hs_fail()
    mismatch=(a[2]!=uuid || hs_unhex(a[3])!=spec)
    for(i=3;i<n;i++) {
        count=split(lines[i],a," ")
        if(a[1]=="INPUT") {
            if(ended || count!=4 || a[2]!=++inputs || a[3]!~/^(origincert|cacert|origin-ca-pool|caPool)$/)hs_fail()
            path=hs_path(hs_unhex(a[4]));output=output "INPUT\t" inputs "\t" a[3] "\t" path "\t" ((path in owner) ? owner[path] : "external") "\t" ((path in owner) ? ownergen[path] : "-") "\t" ((path in owner) ? ownerhash[path] : "-") "\n"
        } else if(a[1]=="CONTROL") {
            if(ended || count!=3 || a[2]!~/^(logfile|log-directory|pidfile|trace-output)$/)hs_fail()
            hs_path(hs_unhex(a[3]));controls++
        } else if(a[1]=="END") {
            if(ended++ || i!=n-1 || count!=3 || a[2]!=inputs+0 || a[3]!=controls+0)hs_fail()
        } else hs_fail()
    }
    if(!ended)hs_fail()
    if(mismatch) {print "CFMGR-CLOUD-YAML-MISMATCH 1 END";exit}
    if(length(output)+128>262144)hs_fail()
    # A report does not launch Cloudflared. Explicit output-control paths are
    # still surfaced as an unproved launch-control association, never executed.
    printf "CFMGR-CLOUD-YAML\t1\t%d\t%d\n%sEND\t%d\n",inputs,controls,output,inputs;exit
}
'
	# CFMGR-AWK-END health_selected
}

# These operations consume the retained config only. Authority stdout remains
# private, is measured natively, and is never read into a shell variable.
cfmgr_health_cloud_project() {
	case $1 in plan) cfmgr_health_cloud_mode=health-cloud-plan cfmgr_health_cloud_max=32768 ;;
	runtime-authority | certificate-account)
		cfmgr_health_cloud_mode=health-cloud-authority cfmgr_health_cloud_max=131072
		case $1 in runtime-authority) cfmgr_health_cloud_expected=$cfmgr_health_cloud_runtime_bytes ;; *) cfmgr_health_cloud_expected=$cfmgr_health_cloud_account_bytes ;; esac
		if [ "$cfmgr_health_cloud_expected" -gt 131072 ]; then
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		fi
		cfmgr_health_selected_limit=$(((cfmgr_health_cloud_expected + 511) / 512))
		;;
	*) return 2 ;;
	esac
	cfmgr_health_run "$cfmgr_health_cloud_mode" /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_health_config" "$cfmgr_health_config_bytes" "$1" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_cloud_projection=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_cloud_projection" "$cfmgr_health_cloud_max" || return $?
	[ "$cfmgr_health_size" -gt 0 ] || return 1
	case $1 in
	plan) cfmgr_health_cloud_frame "$cfmgr_health_cloud_projection" plan || return $? ;;
	*) [ "$cfmgr_health_size" = "$cfmgr_health_cloud_expected" ] || return 1 ;;
	esac
}

cfmgr_health_selected_attached() {
	cfmgr_status_attachment_ok || return 1
	case $cfmgr_health_selected_logical in /opt/* | "${cfmgr_health_opt:-/opt}"/*) cfmgr_health_entware_attachment || return $? ;; esac
}

cfmgr_health_selected_resolve() {
	cfmgr_health_selected_attached || return $?
	[ -f "$cfmgr_health_selected_logical" ] && [ ! -L "$cfmgr_health_selected_logical" ] || return 1
	case $cfmgr_health_selected_logical in /opt/*) cfmgr_health_selected_expected=$cfmgr_health_opt/${cfmgr_health_selected_logical#/opt/} ;; *) cfmgr_health_selected_expected=$cfmgr_health_selected_logical ;; esac
	cfmgr_health_canonical "$cfmgr_health_selected_logical" "$cfmgr_health_selected_expected" || return $?
	case $cfmgr_health_selected_logical in
	/opt/*) [ "$cfmgr_health_resolved" = "$cfmgr_health_opt/${cfmgr_health_selected_logical#/opt/}" ] || return 1 ;;
	*) [ "$cfmgr_health_resolved" = "$cfmgr_health_selected_logical" ] || return 1 ;;
	esac
	[ "${#cfmgr_health_resolved}" -le 1024 ] || return 1
}

cfmgr_health_selected_batch() {
	# Root-owned regular files/directories have nine bounded native LS fields.
	# Charge the exact path bytes plus a conservative 256-byte field allowance.
	cfmgr_health_selected_batch_bytes=0
	for cfmgr_health_selected_operand; do
		cfmgr_health_selected_batch_bytes=$((cfmgr_health_selected_batch_bytes + ${#cfmgr_health_selected_operand} + 256))
	done
	cfmgr_health_selected_limit=$(((cfmgr_health_selected_batch_bytes + 511) / 512))
	cfmgr_health_selected_metadata_reserved=$((cfmgr_health_selected_metadata_reserved + cfmgr_health_selected_limit * 2048 + 4096))
	cfmgr_health_run health-selected-metadata /bin/ls "$@" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_run health-selected-check /usr/bin/awk "$cfmgr_source/modules/status.sh" \
		"$cfmgr_probe_stdout" "$cfmgr_health_selected_profile" "$cfmgr_health_selected_spec" "$cfmgr_health_selected_path" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_health_selected_tag cfmgr_health_selected_version cfmgr_health_selected_i cfmgr_health_selected_n cfmgr_health_selected_end cfmgr_health_selected_extra <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_selected_tag:$cfmgr_health_selected_version:$cfmgr_health_selected_end:$cfmgr_health_selected_extra" = CFMGR-SELECTED:1:END: ] || return 1
	if [ "$cfmgr_health_selected_i" != - ]; then
		cfmgr_health_selected_inode=$cfmgr_health_selected_i cfmgr_health_selected_bytes=$cfmgr_health_selected_n
	fi
}

cfmgr_health_selected_metadata() {
	cfmgr_health_selected_walk=$cfmgr_health_selected_path cfmgr_health_selected_spec=''
	cfmgr_health_selected_inode='' cfmgr_health_selected_bytes='' cfmgr_health_selected_path_count=0
	cfmgr_health_selected_metadata_reserved=0
	set --
	while :; do
		[ ! -L "$cfmgr_health_selected_walk" ] || return 1
		cfmgr_health_selected_path_count=$((cfmgr_health_selected_path_count + 1))
		set -- "$@" "$cfmgr_health_selected_walk"
		cfmgr_health_selected_spec="${cfmgr_health_selected_spec}${cfmgr_health_selected_spec:+
}$cfmgr_health_selected_walk"
		if [ "$#" = 13 ] || [ "$cfmgr_health_selected_walk" = / ]; then
			cfmgr_health_selected_batch "$@" || return $?
			set --
			cfmgr_health_selected_spec=''
		fi
		[ "$cfmgr_health_selected_walk" != / ] || break
		cfmgr_health_selected_walk=${cfmgr_health_selected_walk%/*}
		[ -n "$cfmgr_health_selected_walk" ] || cfmgr_health_selected_walk=/
	done
	[ -n "$cfmgr_health_selected_inode" ] && [ -n "$cfmgr_health_selected_bytes" ]
}

# ROLE LOGICAL_PATH PROFILE snapshot|hash|metadata. Parsed YAML has no validity
# size cap: finite snapshot and three-byte hex funding are checked before copy.
cfmgr_health_selected_snapshot() {
	cfmgr_health_selected_role=$1 cfmgr_health_selected_logical=$2 cfmgr_health_selected_profile=$3 cfmgr_health_selected_operation=$4
	cfmgr_health_selected_file='' cfmgr_health_selected_digest=''
	cfmgr_health_selected_resolve || return $?
	cfmgr_health_selected_path=$cfmgr_health_resolved
	cfmgr_health_selected_metadata || return $?
	cfmgr_health_selected_before="$cfmgr_health_selected_inode $cfmgr_health_selected_bytes"
	cfmgr_health_selected_extent=$cfmgr_health_selected_bytes
	case $cfmgr_health_selected_operation in
	snapshot)
		case $cfmgr_health_selected_role in json | certificate | certificate-recovery)
			[ "$cfmgr_health_selected_extent" -le 65536 ] || return 1
			;;
		esac
		# A copy larger than the entire collection payload allowance cannot be
		# funded. Reject it before multiplying a potentially large file extent.
		if [ "$cfmgr_health_selected_extent" -gt 11534336 ]; then
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		fi
		cfmgr_health_selected_limit=$(((cfmgr_health_selected_extent + 4095) / 4096 * 4096 + 4096 + 511))
		cfmgr_health_selected_limit=$((cfmgr_health_selected_limit / 512))
		# Fund copy/count, canonical and after-metadata observations using the
		# same physical writer tiers as actual dispatch. Only semantic branches
		# that can run reserve future hex/count work. No counter is reset.
		cfmgr_health_selected_batches=$(((cfmgr_health_selected_path_count + 12) / 13))
		cfmgr_health_selected_future=$((cfmgr_health_selected_limit * 2048 + cfmgr_health_selected_metadata_reserved + 4096 + 16384))
		cfmgr_health_selected_future_ops=$((cfmgr_health_selected_batches * 2 + 3))
		case $cfmgr_health_selected_logical in /opt/*)
			cfmgr_health_selected_future=$((cfmgr_health_selected_future + 32768))
			cfmgr_health_selected_future_ops=$((cfmgr_health_selected_future_ops + 2))
			;;
		esac
		cfmgr_health_selected_future_hex=0
		if [ "${cfmgr_health_backup:-missing}" = verified ]; then
			case $cfmgr_health_selected_role in
			yaml) [ -z "${cfmgr_health_cloud_authority:-}" ] || cfmgr_health_selected_future_hex=1 ;;
			certificate | certificate-recovery)
				if [ -n "${cfmgr_health_cloud_account:-}" ] && [ "${cfmgr_health_native_openssl_ok:-0}" = 1 ]; then
					cfmgr_health_selected_future_hex=1
					if [ "${cfmgr_health_cloud_certificate_parsed:-0}" = 1 ] && [ "${cfmgr_health_cloud_sha:--}" != - ] &&
						[ "${cfmgr_health_cloud_sha:-}" = "${cfmgr_health_cloud_certificate_digest:-}" ]; then cfmgr_health_selected_future_hex=0; fi
				fi
				;;
			esac
		fi
		if [ "$cfmgr_health_selected_future_hex" = 1 ]; then
			cfmgr_health_selected_hex_limit=$(((cfmgr_health_selected_extent * 3 + 511) / 512))
			[ "$cfmgr_health_selected_hex_limit" -gt 0 ] || cfmgr_health_selected_hex_limit=1
			cfmgr_health_selected_future=$((cfmgr_health_selected_future + cfmgr_health_selected_hex_limit * 2048 + 4096))
			cfmgr_health_selected_future_ops=$((cfmgr_health_selected_future_ops + 2))
		fi
		if [ "$((cfmgr_health_bytes + cfmgr_health_selected_future))" -gt 11534336 ] ||
			[ "$((cfmgr_health_operations + cfmgr_health_selected_future_ops))" -gt 568 ] || [ "$((cfmgr_health_files + cfmgr_health_selected_future_ops * 2))" -gt 1264 ]; then
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		fi
		cfmgr_health_run health-selected-copy /bin/dd "$cfmgr_health_selected_path" "$cfmgr_health_selected_extent" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_health_selected_file=$cfmgr_probe_stdout
		cfmgr_health_count "$cfmgr_health_selected_file" "$cfmgr_health_selected_extent" || return $?
		[ "$cfmgr_health_size" = "$cfmgr_health_selected_extent" ] || return 1
		;;
	hash)
		[ "${cfmgr_health_native_openssl_ok:-0}" = 1 ] || return 1
		cfmgr_health_run health-selected-hash "$cfmgr_health_openssl" "$cfmgr_health_selected_path" "$cfmgr_health_selected_extent" || return $?
		cfmgr_health_selected_hash_receipt || return $?
		;;
	metadata) ;;
	*) return 2 ;;
	esac
	cfmgr_health_selected_resolve || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_selected_path" ] || return 1
	cfmgr_health_selected_metadata || return $?
	[ "$cfmgr_health_selected_before" = "$cfmgr_health_selected_inode $cfmgr_health_selected_bytes" ] && cfmgr_health_selected_attached
}

cfmgr_health_selected_hash_receipt() {
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	{
		IFS= read -r cfmgr_health_selected_hash_line || return 1
		cfmgr_health_selected_extra=''
		if IFS= read -r cfmgr_health_selected_extra || [ -n "$cfmgr_health_selected_extra" ]; then return 1; fi
	} <"$cfmgr_probe_stdout"
	cfmgr_health_selected_digest=${cfmgr_health_selected_hash_line%% *}
	[ "${#cfmgr_health_selected_digest}" = 64 ] || return 1
	case $cfmgr_health_selected_digest in *[!0-9a-f]*) return 1 ;; esac
	# OpenSSL -r stdin spelling, never accept a partial or named-file receipt.
	[ "$cfmgr_health_selected_hash_line" = "$cfmgr_health_selected_digest *stdin" ] ||
		[ "$cfmgr_health_selected_hash_line" = "$cfmgr_health_selected_digest stdin" ]
}

cfmgr_health_cloud_hex() {
	cfmgr_health_selected_limit=$((($2 * 3 + 511) / 512))
	[ "$cfmgr_health_selected_limit" -gt 0 ] || cfmgr_health_selected_limit=1
	cfmgr_health_run health-selected-hex /usr/bin/hexdump "$1" "$2" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_cloud_hex_file=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_cloud_hex_file" "$(($2 * 3))" || return $?
	[ "$cfmgr_health_size" = "$(($2 * 3))" ]
}

cfmgr_health_cloud_frame() {
	cfmgr_health_run health-cloud-frame /usr/bin/awk "$cfmgr_source/modules/status.sh" "$1" "$2" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]
}

cfmgr_health_cloud_json() {
	cfmgr_health_cloud_match_state=unknown
	cfmgr_health_run health-cloud-json /usr/bin/awk "$cfmgr_source/modules/lib" "$1" "$2" "$3" "$4" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	{
		IFS= read -r cfmgr_health_cloud_match || return 1
		cfmgr_health_cloud_extra=''
		if IFS= read -r cfmgr_health_cloud_extra || [ -n "$cfmgr_health_cloud_extra" ]; then return 1; fi
	} <"$cfmgr_probe_stdout"
	case $cfmgr_health_cloud_match in
	"CFMGR-PAYLOAD 1 $1 matched END") cfmgr_health_cloud_match_state=matched ;;
	"CFMGR-PAYLOAD 1 $1 mismatch END") cfmgr_health_cloud_match_state=mismatch ;;
	*) return 1 ;;
	esac
}

cfmgr_health_cloud_file_row() {
	case $1 in yaml) cfmgr_health_cloud_row_id=yaml.identity ;; json) cfmgr_health_cloud_row_id=runtime.local ;; certificate) cfmgr_health_cloud_row_id=certificate.live ;; *) cfmgr_health_cloud_row_id=$1 ;; esac
	cfmgr_health_row "cloudflared.$cfmgr_health_cloud_row_id" "$2" "$3" current 'Review the selected local Cloudflared files and retained ownership; health performs no repair.' cloudflared
}

cfmgr_health_cloud_collect() {
	cfmgr_health_cloud_plan='' cfmgr_health_cloud_authority='' cfmgr_health_cloud_account=''
	if [ -n "$cfmgr_health_inventory" ] && cfmgr_health_cloud_project plan; then :; else
		[ "$?" != 3 ] || return 3
		cfmgr_health_cloud_file_row local UNKNOWN 'Strict retained schema-2 Cloudflared authority was unavailable; local selected-file checks are incomplete.'
		return $?
	fi
	cfmgr_health_cloud_plan=$cfmgr_health_cloud_projection
	cfmgr_health_cloud_method=- cfmgr_health_cloud_cert_selected=0
	# Fixed trusted projection contains paths/policies only, never credential refs,
	# accounts, tunnel identity or secrets. Its AWK writer validates before output.
	while IFS='	' read -r cfmgr_health_cloud_tag cfmgr_health_cloud_a cfmgr_health_cloud_b cfmgr_health_cloud_c cfmgr_health_cloud_d cfmgr_health_cloud_e cfmgr_health_cloud_f; do
		case $cfmgr_health_cloud_tag in
		STATE) cfmgr_health_cloud_configured=$cfmgr_health_cloud_a cfmgr_health_cloud_enabled=$cfmgr_health_cloud_b cfmgr_health_cloud_installed=$cfmgr_health_cloud_c cfmgr_health_cloud_maintenance=$cfmgr_health_cloud_d cfmgr_health_cloud_method=$cfmgr_health_cloud_e ;;
		FILE)
			case $cfmgr_health_cloud_a in
			yaml) cfmgr_health_cloud_yaml=$cfmgr_health_cloud_c cfmgr_health_cloud_yaml_support=$cfmgr_health_cloud_b ;;
			json) cfmgr_health_cloud_json=$cfmgr_health_cloud_c cfmgr_health_cloud_json_support=$cfmgr_health_cloud_b ;;
			esac
			;;
		POLICY) cfmgr_health_cloud_policy="auto-update=$cfmgr_health_cloud_a watchdog=$cfmgr_health_cloud_b grace=$cfmgr_health_cloud_c stability=$cfmgr_health_cloud_d" ;;
		READINESS) cfmgr_health_cloud_readiness="response=$cfmgr_health_cloud_a command=$cfmgr_health_cloud_b" ;;
		AUTH) cfmgr_health_cloud_runtime_bytes=$((57 + 2 * (cfmgr_health_cloud_a + cfmgr_health_cloud_b + cfmgr_health_cloud_c))) cfmgr_health_cloud_account_bytes=$((26 + 2 * cfmgr_health_cloud_d)) ;;
		CERT) cfmgr_health_cloud_cert_selected=$cfmgr_health_cloud_b ;;
		esac
	done <"$cfmgr_health_cloud_plan"
	case $cfmgr_health_cloud_method in
	token) cfmgr_health_cloud_file_row method PASS 'Token method is recorded; YAML/runtime JSON are not prerequisites and no runtime token is displayed or executed.' ;;
	advanced) cfmgr_health_cloud_file_row method PASS 'Advanced method is recorded; selected YAML and runtime JSON require independent local identity checks.' ;;
	*) cfmgr_health_cloud_file_row method SKIP 'No Cloudflared method is configured.' ;;
	esac || return $?
	if [ "$cfmgr_health_cloud_method" = advanced ] && [ "${cfmgr_health_backup:-missing}" = verified ]; then
		if cfmgr_health_cloud_project runtime-authority; then cfmgr_health_cloud_authority=$cfmgr_health_cloud_projection; else [ "$?" != 3 ] || return 3; fi
	fi
	if [ "$cfmgr_health_cloud_cert_selected" = 1 ] && [ "${cfmgr_health_backup:-missing}" = verified ]; then
		if cfmgr_health_cloud_project certificate-account; then cfmgr_health_cloud_account=$cfmgr_health_cloud_projection; else [ "$?" != 3 ] || return 3; fi
	fi
	cfmgr_health_cloud_certificate_parsed=0
	while IFS='	' read -r cfmgr_health_cloud_tag cfmgr_health_cloud_role cfmgr_health_cloud_support cfmgr_health_cloud_path cfmgr_health_cloud_owner cfmgr_health_cloud_gen cfmgr_health_cloud_sha; do
		[ "$cfmgr_health_cloud_tag" = FILE ] || continue
		if cfmgr_health_cloud_one; then :; else
			[ "$?" != 3 ] || return 3
			cfmgr_health_cloud_file_row "$cfmgr_health_cloud_role" UNKNOWN 'The local check could not finish within its supported parser, native prerequisite or report budget.' || return $?
		fi
	done <"$cfmgr_health_cloud_plan"
	cfmgr_health_cloud_file_row maintenance UNKNOWN "Saved configured=$cfmgr_health_cloud_configured enabled=$cfmgr_health_cloud_enabled installed=$cfmgr_health_cloud_installed maintenance=$cfmgr_health_cloud_maintenance; $cfmgr_health_cloud_policy; readiness $cfmgr_health_cloud_readiness. These are recorded policy only; running jobs and readiness are unproved." || return $?
}

cfmgr_health_cloud_one() {
	case $cfmgr_health_cloud_role in yaml | json)
		[ "$cfmgr_health_cloud_method" = advanced ] || return 0
		;;
	esac
	cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='Selected file observation was unavailable, unsupported, or could not be funded within the report budget.'
	if [ "$cfmgr_health_cloud_support:$cfmgr_health_cloud_role" = absent:certificate ] || [ "$cfmgr_health_cloud_support:$cfmgr_health_cloud_role" = absent:certificate-recovery ]; then
		cfmgr_health_cloud_file_row "$cfmgr_health_cloud_role" SKIP 'No management certificate is selected; this optional role is not a runtime prerequisite.'
		return $?
	fi
	if [ "$cfmgr_health_cloud_owner" = conflict ]; then
		cfmgr_health_cloud_file_row "$cfmgr_health_cloud_role" FAIL 'The selected path, ownership record or generation has a proven retained conflict.'
		return $?
	fi
	if [ "$cfmgr_health_cloud_support" != supported ]; then
		[ "$cfmgr_health_cloud_support" != absent ] || cfmgr_health_cloud_detail='No selected file is recorded for this role.'
		cfmgr_health_cloud_file_row "$cfmgr_health_cloud_role" UNKNOWN "$cfmgr_health_cloud_detail"
		return $?
	fi
	case $cfmgr_health_cloud_role in
	json | certificate | certificate-recovery) cfmgr_health_cloud_profile=private cfmgr_health_cloud_operation=snapshot ;;
	yaml) cfmgr_health_cloud_profile=public cfmgr_health_cloud_operation=snapshot ;;
	binary) cfmgr_health_cloud_profile=executable cfmgr_health_cloud_operation=hash ;;
	*) return 2 ;;
	esac
	if cfmgr_health_selected_snapshot "$cfmgr_health_cloud_role" "$cfmgr_health_cloud_path" "$cfmgr_health_cloud_profile" "$cfmgr_health_cloud_operation"; then
		cfmgr_health_cloud_snapshot=$cfmgr_health_selected_file cfmgr_health_cloud_extent=$cfmgr_health_selected_extent
		cfmgr_health_cloud_integrity=unproved
		if [ "$cfmgr_health_cloud_role" != binary ] && [ "$cfmgr_health_cloud_sha" != - ] && [ "${cfmgr_health_native_openssl_ok:-0}" = 1 ]; then
			cfmgr_health_run health-selected-hash "$cfmgr_health_openssl" "$cfmgr_health_cloud_snapshot" "$cfmgr_health_cloud_extent" || return $?
			cfmgr_health_selected_hash_receipt || return 1
		fi
		if [ -n "$cfmgr_health_selected_digest" ] && [ "$cfmgr_health_cloud_sha" != - ] && [ "$cfmgr_health_selected_digest" != "$cfmgr_health_cloud_sha" ]; then
			cfmgr_health_cloud_state=FAIL cfmgr_health_cloud_detail='Protected selected bytes differ from the exact retained ownership digest.'
		else
			[ -z "$cfmgr_health_selected_digest" ] || cfmgr_health_cloud_integrity=matched
			cfmgr_health_cloud_semantics || return $?
			if [ "$cfmgr_health_cloud_state" = PASS ] && [ "$cfmgr_health_cloud_sha" != - ] && [ "$cfmgr_health_cloud_integrity" != matched ]; then
				cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='Local identity matched, but the retained ownership digest could not be checked with admitted native OpenSSL.'
			fi
		fi
	else
		[ "$?" != 3 ] || return 3
	fi
	cfmgr_health_cloud_file_row "$cfmgr_health_cloud_role" "$cfmgr_health_cloud_state" "$cfmgr_health_cloud_detail"
}

cfmgr_health_cloud_semantics() {
	if [ "$cfmgr_health_cloud_role" = binary ]; then
		if [ "$cfmgr_health_cloud_owner" = matched ] && [ "$cfmgr_health_cloud_sha" != - ]; then
			cfmgr_health_cloud_state=PASS cfmgr_health_cloud_detail='Protected pinned executable bytes match the exact nonfuture ownership record; Cloudflared was not executed.'
		else cfmgr_health_cloud_detail='Protected pinned executable was hashed, but exact retained ownership is missing; association remains unproved.'; fi
		return 0
	fi
	if [ "${cfmgr_health_backup:-missing}" != verified ]; then
		cfmgr_health_cloud_detail='Selected metadata and snapshot were observed; borrowed semantic parsers require the independently verified Backup member.'
		return 0
	fi
	case $cfmgr_health_cloud_role in
	json)
		[ -n "$cfmgr_health_cloud_authority" ] || return 0
		if cfmgr_health_cloud_json runtime-json "$cfmgr_health_cloud_snapshot" "$cfmgr_health_cloud_extent" "$cfmgr_health_cloud_authority"; then
			if [ "$cfmgr_health_cloud_match_state" = matched ]; then
				cfmgr_health_cloud_state=PASS cfmgr_health_cloud_detail='Private runtime JSON exactly matches selected account, tunnel and secret authority; no runtime or provider authentication claim is made.'
			else cfmgr_health_cloud_state=FAIL cfmgr_health_cloud_detail='Complete private runtime JSON conflicts with the exact selected authority.'; fi
		else
			[ "$?" != 3 ] || return 3
			cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='Runtime JSON identity could not be proved by a complete bounded parser receipt.'
		fi
		;;
	yaml)
		[ -n "$cfmgr_health_cloud_authority" ] || return 0
		cfmgr_health_cloud_yaml_check || return $?
		;;
	certificate | certificate-recovery)
		[ -n "$cfmgr_health_cloud_account" ] && [ "${cfmgr_health_native_openssl_ok:-0}" = 1 ] || return 0
		if [ "$cfmgr_health_cloud_certificate_parsed" = 1 ] && [ "$cfmgr_health_selected_digest" = "$cfmgr_health_cloud_certificate_digest" ] && [ "$cfmgr_health_cloud_sha" != - ]; then
			cfmgr_health_cloud_state=PASS cfmgr_health_cloud_detail='This independently hashed protected certificate matches the same expected bytes and the already verified selected account.'
		else
			cfmgr_health_cloud_certificate_check || return $?
		fi
		;;
	esac
	if [ "$cfmgr_health_cloud_state" = PASS ] && [ "$cfmgr_health_cloud_owner" != matched ]; then
		cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='Local content identity matched, but exact retained file ownership is missing; association remains unproved.'
	fi
}

cfmgr_health_cloud_yaml_check() {
	[ "$cfmgr_health_cloud_json_support" = supported ] || return 0
	cfmgr_health_cloud_hex "$cfmgr_health_cloud_snapshot" "$cfmgr_health_cloud_extent" || return $?
	# Source-sized writer limits preserve the parser's independent 262144-byte
	# internal metadata budget. Paths serialize as hex plus bounded row framing.
	cfmgr_health_cloud_yaml_bound=$((cfmgr_health_cloud_extent * 4 + 256))
	[ "$cfmgr_health_cloud_yaml_bound" -le 262144 ] || cfmgr_health_cloud_yaml_bound=262144
	cfmgr_health_selected_limit=$(((cfmgr_health_cloud_yaml_bound + 511) / 512))
	cfmgr_health_run health-cloud-yaml /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_cloud_hex_file" || return $?
	if [ "$cfmgr_probe_exit" != 0 ] || [ -s "$cfmgr_probe_stderr" ]; then
		cfmgr_health_cloud_detail='The selected YAML is outside the supported identity/dependency subset or could not be parsed within budget; configuration validity is unchanged.'
		return 0
	fi
	cfmgr_health_cloud_yaml_receipt=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_cloud_yaml_receipt" "$cfmgr_health_cloud_yaml_bound" || return $?
	cfmgr_health_cloud_join_bound=$((cfmgr_health_size * 8 + 1024))
	[ "$cfmgr_health_cloud_join_bound" -le 262144 ] || cfmgr_health_cloud_join_bound=262144
	cfmgr_health_selected_limit=$(((cfmgr_health_cloud_join_bound + 511) / 512))
	cfmgr_health_run health-cloud-join /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_health_cloud_yaml_receipt" "$cfmgr_health_cloud_authority" "$cfmgr_health_cloud_json" "$cfmgr_health_cloud_plan" || return $?
	if [ "$cfmgr_probe_exit" != 0 ] || [ -s "$cfmgr_probe_stderr" ]; then
		cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='A complete supported YAML identity join was unavailable.'
		return 0
	fi
	cfmgr_health_cloud_inputs=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_cloud_inputs" "$cfmgr_health_cloud_join_bound" || return $?
	cfmgr_health_cloud_frame "$cfmgr_health_cloud_inputs" join || return $?
	IFS= read -r cfmgr_health_cloud_join_header <"$cfmgr_health_cloud_inputs" || return 1
	if [ "$cfmgr_health_cloud_join_header" = 'CFMGR-CLOUD-YAML-MISMATCH 1 END' ]; then
		cfmgr_health_cloud_state=FAIL cfmgr_health_cloud_detail='Complete supported YAML identity or credentials path conflicts with selected authority.'
		return 0
	fi
	cfmgr_health_cloud_state=PASS cfmgr_health_cloud_detail='Supported YAML tunnel identity and credentials path match; ingress and private-network runtime semantics are not proved.'
	while IFS='	' read -r cfmgr_health_cloud_input_tag cfmgr_health_cloud_input_n cfmgr_health_cloud_input_kind cfmgr_health_cloud_input_path cfmgr_health_cloud_input_owner cfmgr_health_cloud_input_gen cfmgr_health_cloud_input_sha; do
		if [ "$cfmgr_health_cloud_input_tag" = CFMGR-CLOUD-YAML ] && [ "$cfmgr_health_cloud_input_path" != 0 ]; then
			cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='YAML identity matched, but explicit output-control paths require separate launch-control ownership proof.'
		fi
		[ "$cfmgr_health_cloud_input_tag" = INPUT ] || continue
		cfmgr_health_cloud_input_profile=public
		[ "$cfmgr_health_cloud_input_kind" != origincert ] || cfmgr_health_cloud_input_profile=private
		cfmgr_health_cloud_input_detail='Referenced runtime input availability/protection was not proved.'
		[ "$cfmgr_health_cloud_input_kind" != origincert ] || cfmgr_health_cloud_input_detail='Referenced management-only origin certificate availability/protection was not proved; this is independent of runtime readiness.'
		cfmgr_health_cloud_input_state=UNKNOWN
		if [ "$cfmgr_health_cloud_input_owner" = conflict ]; then
			cfmgr_health_cloud_input_state=FAIL cfmgr_health_cloud_input_detail='A referenced input has conflicting or future retained ownership.'
		else
			cfmgr_health_cloud_input_operation=metadata
			[ "$cfmgr_health_cloud_input_owner:$cfmgr_health_cloud_input_sha" = external:- ] || cfmgr_health_cloud_input_operation=hash
			if cfmgr_health_selected_snapshot input "$cfmgr_health_cloud_input_path" "$cfmgr_health_cloud_input_profile" "$cfmgr_health_cloud_input_operation"; then
				if [ "$cfmgr_health_cloud_input_owner" = external ]; then
					cfmgr_health_cloud_input_state=PASS cfmgr_health_cloud_input_detail='External referenced input is available with protected ancestry; no managed integrity association is claimed.'
				elif [ "$cfmgr_health_cloud_input_sha" != - ] && [ "$cfmgr_health_selected_digest" = "$cfmgr_health_cloud_input_sha" ]; then
					cfmgr_health_cloud_input_state=PASS cfmgr_health_cloud_input_detail='Protected pinned referenced input matches its exact nonfuture retained ownership digest.'
				elif [ "$cfmgr_health_cloud_input_sha" != - ]; then
					cfmgr_health_cloud_input_state=FAIL cfmgr_health_cloud_input_detail='Protected referenced input bytes conflict with their exact retained ownership digest.'
				fi
			else [ "$?" != 3 ] || return 3; fi
		fi
		[ "$cfmgr_health_cloud_input_kind" != origincert ] || cfmgr_health_cloud_input_detail="Management-only origin certificate: $cfmgr_health_cloud_input_detail"
		cfmgr_health_cloud_file_row "yaml.input.$cfmgr_health_cloud_input_n" "$cfmgr_health_cloud_input_state" "$cfmgr_health_cloud_input_detail" || return $?
	done <"$cfmgr_health_cloud_inputs"
}

cfmgr_health_cloud_certificate_check() {
	cfmgr_health_cloud_saved_digest=$cfmgr_health_selected_digest
	cfmgr_health_cloud_hex "$cfmgr_health_cloud_snapshot" "$cfmgr_health_cloud_extent" || return $?
	cfmgr_health_run health-cloud-pem /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_cloud_hex_file" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 0
	cfmgr_health_cloud_base64=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_cloud_base64" 65536 || return $?
	cfmgr_health_run health-cloud-decode "$cfmgr_health_openssl" "$cfmgr_health_cloud_base64" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 0
	cfmgr_health_cloud_decoded=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_cloud_decoded" 65536 || return $?
	if cfmgr_health_cloud_json certificate-json "$cfmgr_health_cloud_decoded" "$cfmgr_health_size" "$cfmgr_health_cloud_account"; then
		if [ "$cfmgr_health_cloud_match_state" != matched ]; then
			cfmgr_health_cloud_state=FAIL cfmgr_health_cloud_detail='Complete decoded certificate JSON conflicts with the selected certificate account.'
			return 0
		fi
		cfmgr_health_cloud_certificate_parsed=1 cfmgr_health_cloud_certificate_digest=$cfmgr_health_cloud_saved_digest
		cfmgr_health_cloud_state=PASS cfmgr_health_cloud_detail='Protected PEM framing and decoded certificate JSON match the selected certificate account; management authority remains distinct from runtime token readiness.'
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_cloud_state=UNKNOWN cfmgr_health_cloud_detail='A complete bounded certificate identity receipt was unavailable.'
	fi
}

cfmgr_status_awk_health_compare() {
	# CFMGR-AWK-BEGIN health_compare
	cfmgr_awk_program='
# One pass over at most 7 owned receipts, 250 canonical values and 2 current samples.
# No provider identifier, configured name, secret, address or path becomes output.
BEGIN {
    manifest=ARGV[1];context=ARGV[2];ARGC=1
    raw=hw_read(manifest,1024,0);n=split(raw,lines,"\n")
    if(n<3 || n>10 || lines[1]!="CFMGR-HEALTH-COMPARISON 1" || lines[n-1]!="END " (n-3))exit 1
    for(i=2;i<n-1;i++) {
        if(split(lines[i],a," ")!=4 || lines[i]!=a[1] " " a[2] " " a[3] " " a[4] || a[1]!~/^(DNS|ITEMS|TRACE)$/ || a[2]!~/^[1-3]$/ || a[4]!~/^health-(response|trace)\.[1-9][0-9]*\.out$/ || length(a[4])>32 || seen[a[1],a[2]]++ || names[a[4]]++)exit 1
        role[i]=a[1];ordinal[i]=a[2];family[i]=a[3];file[i]=context "/" a[4]
        if(a[1]=="DNS") {if(a[3]!~/^[46]$/ || ++dns>3 || a[4]!~/^health-response\./)exit 1}
        else if(a[1]=="ITEMS") {if(a[2]>2 || a[3]!~/^(4|6|46)$/ || ++items>2 || a[4]!~/^health-response\./)exit 1}
        else {if(a[2]>2 || a[3]!~/^[46]$/ || ++samples>2 || tracefamily[a[3]]++ || a[4]!~/^health-trace\./)exit 1}
    }
    for(i=2;i<n-1;i++) {
        if(role[i]=="TRACE") {
            raw=hw_read(file[i],256,0);sub(/\n$/,"",raw)
            if(split(raw,a," ")!=6 || a[1]!="CFMGR-HEALTH-RESPONSE" || a[2]!="1" || a[3]!="observed" || a[4]!="1" || a[6]!="END" || substr(a[5],1,5)!="ipv" family[i] ":" || raw!="CFMGR-HEALTH-RESPONSE 1 observed 1 " a[5] " END")exit 1
            address=substr(a[5],6)
            if(family[i]=="4" ? !hw_public4(address) : !hw_ipv6(address))exit 1
            current[family[i]]=hw_canonical(address,family[i]);continue
        }
        hw_values(file[i],(role[i]=="DNS" ? "dns" : "items"),(role[i]=="DNS" ? family[i] : "mixed"))
        state[i]=hw_value_state;count[i]=hw_value_count;total+=hw_value_count
        if(total>250)exit 1
        for(j=1;j<=hw_value_count;j++) {value[i,j]=hw_value_address[j];prefix[i,j]=hw_value_prefix[j];valuefamily[i,j]=hw_value_address_family[j]}
    }
    for(i=2;i<n-1;i++) {
        if(role[i]=="TRACE")continue
        if(role[i]=="DNS") {
            f=family[i];id="ddns.record." ordinal[i]
            if(current[f]=="") hc_row(id,"UNKNOWN","current-family-unavailable")
            else if(state[i]!="verified")hc_row(id,"UNKNOWN","dns-partial")
            else if(count[i]==0)hc_row(id,"WARN","dns-absent")
            else if(count[i]>1)hc_row(id,"WARN","dns-multiple")
            else if(value[i,1]==current[f])hc_row(id,"PASS","dns-equal")
            else hc_row(id,"WARN","dns-different")
        } else {
            for(k=1;k<=length(family[i]);k++) {
                f=substr(family[i],k,1);id="ip_sync." (ordinal[i]==1 ? "primary" : "secondary") ".ipv" f
                if(listfamily[f]++)exit 1
                if(current[f]=="") {hc_row(id,"UNKNOWN","current-family-unavailable");continue}
                hit=0
                for(j=1;j<=count[i];j++)if(valuefamily[i,j]==f && hw_bits_match(current[f],value[i,j],prefix[i,j]))hit=1
                if(hit)hc_row(id,"PASS",(state[i]=="verified" ? "list-member" : "list-member-partial"))
                else if(state[i]!="verified")hc_row(id,"UNKNOWN","list-partial-no-match")
                else hc_row(id,"WARN","list-no-match")
            }
        }
    }
    output="CFMGR-HEALTH-COMPARE 1\n" rows "END " rowcount "\n"
    if(length(output)>4096)exit 1
    printf "%s",output;exit
}
function hc_row(id,state,reason) {
    if(++rowcount>5)exit 1
    rows=rows "ROW " id " " state " " reason "\n"
}
'
	# CFMGR-AWK-END health_compare
}

cfmgr_health_comparison_keep() {
	# KIND ORDINAL CONFIGURED_FAMILY OWNED_RECEIPT. No provider values are read.
	[ "$cfmgr_health_compare_count" -lt 7 ] || return 1
	case $4 in "$cfmgr_status_context"/health-response.*.out | "$cfmgr_status_context"/health-trace.*.out) ;; *) return 1 ;; esac
	cfmgr_health_compare_base=${4##*/}
	case $cfmgr_health_compare_base in *[!A-Za-z0-9.-]* | *..*) return 1 ;; esac
	[ "${#cfmgr_health_compare_base}" -le 32 ] && [ -f "$4" ] && [ ! -L "$4" ] || return 1
	case "$cfmgr_health_owned
" in *"
$cfmgr_health_compare_base
"*) ;; *) return 1 ;; esac
	cfmgr_health_compare_pending="$cfmgr_health_compare_pending
$1 $2 $3 $cfmgr_health_compare_base"
	cfmgr_health_compare_count=$((cfmgr_health_compare_count + 1))
}

cfmgr_health_comparison_manifest() {
	cfmgr_health_compare_text='CFMGR-HEALTH-COMPARISON 1
'
	cfmgr_health_compare_entries=0
	while IFS=' ' read -r cfmgr_health_compare_role cfmgr_health_compare_ordinal cfmgr_health_compare_family cfmgr_health_compare_base; do
		case $cfmgr_health_compare_role in DNS | ITEMS | TRACE) ;; *) continue ;; esac
		cfmgr_status_attachment_ok || return 1
		[ -f "$cfmgr_status_context/$cfmgr_health_compare_base" ] && [ ! -L "$cfmgr_status_context/$cfmgr_health_compare_base" ] || return 1
		case "$cfmgr_health_owned
" in *"
$cfmgr_health_compare_base
"*) ;; *) return 1 ;; esac
		if [ "$cfmgr_health_compare_role" = ITEMS ]; then
			cfmgr_health_compare_family=''
			case $cfmgr_health_compare_ordinal in
			1)
				[ "$cfmgr_health_compare_primary4" = 0 ] || cfmgr_health_compare_family=4
				[ "$cfmgr_health_compare_primary6" = 0 ] || cfmgr_health_compare_family=${cfmgr_health_compare_family}6
				;;
			2)
				[ "$cfmgr_health_compare_secondary4" = 0 ] || cfmgr_health_compare_family=4
				[ "$cfmgr_health_compare_secondary6" = 0 ] || cfmgr_health_compare_family=${cfmgr_health_compare_family}6
				;;
			esac
			[ -n "$cfmgr_health_compare_family" ] || continue
		fi
		cfmgr_health_compare_text="$cfmgr_health_compare_text$cfmgr_health_compare_role $cfmgr_health_compare_ordinal $cfmgr_health_compare_family $cfmgr_health_compare_base
"
		cfmgr_health_compare_entries=$((cfmgr_health_compare_entries + 1))
	done <<EOF_HEALTH_COMPARISON
$cfmgr_health_compare_pending
EOF_HEALTH_COMPARISON
	cfmgr_health_compare_text="${cfmgr_health_compare_text}END $cfmgr_health_compare_entries
"
	[ "$cfmgr_health_compare_entries" -gt 0 ] && [ "${#cfmgr_health_compare_text}" -le 1024 ] || return 1
	cfmgr_health_stage_reserve comparison 2048 || return $?
	# Two blocks are 1024B on native ash, 2048B on the host. The complete finite
	# text is checked before this fixed native write and never contains authority.
	(
		umask 077
		set -C
		ulimit -f 2 && /usr/bin/printf '%s' "$cfmgr_health_compare_text" >"$cfmgr_status_context/comparison"
	)
}

cfmgr_health_comparison_read() {
	# Validate complete safe output before presenting any row. At most 8 lines;
	# no raw address or externally selected string is admitted to public output.
	cfmgr_health_compare_safe='' cfmgr_health_compare_seen='' cfmgr_health_compare_rows=0 cfmgr_health_compare_line_number=0 cfmgr_health_compare_ended=0
	while :; do
		cfmgr_health_compare_line=''
		if IFS= read -r cfmgr_health_compare_line; then :; else
			[ -z "$cfmgr_health_compare_line" ] && [ "$cfmgr_health_compare_ended" = 1 ]
			return $?
		fi
		cfmgr_health_compare_line_number=$((cfmgr_health_compare_line_number + 1))
		[ "$cfmgr_health_compare_line_number" -le 8 ] && [ "${#cfmgr_health_compare_line}" -le 256 ] && [ "$cfmgr_health_compare_ended" = 0 ] || return 1
		if [ "$cfmgr_health_compare_line_number" = 1 ]; then
			[ "$cfmgr_health_compare_line" = 'CFMGR-HEALTH-COMPARE 1' ] || return 1
			continue
		fi
		IFS=' ' read -r cfmgr_health_compare_tag cfmgr_health_compare_id cfmgr_health_compare_state cfmgr_health_compare_reason cfmgr_health_compare_extra <<EOF_HEALTH_COMPARE_ROW
$cfmgr_health_compare_line
EOF_HEALTH_COMPARE_ROW
		if [ "$cfmgr_health_compare_tag" = END ]; then
			[ "$cfmgr_health_compare_line" = "END $cfmgr_health_compare_rows" ] || return 1
			cfmgr_health_compare_ended=1
			continue
		fi
		[ "$cfmgr_health_compare_tag" = ROW ] && [ -z "$cfmgr_health_compare_extra" ] &&
			[ "$cfmgr_health_compare_line" = "ROW $cfmgr_health_compare_id $cfmgr_health_compare_state $cfmgr_health_compare_reason" ] || return 1
		case $cfmgr_health_compare_id in ddns.record.[1-3] | ip_sync.primary.ipv[46] | ip_sync.secondary.ipv[46]) ;; *) return 1 ;; esac
		case $cfmgr_health_compare_state:$cfmgr_health_compare_reason in
		PASS:dns-equal | PASS:list-member | PASS:list-member-partial | WARN:dns-absent | WARN:dns-multiple | WARN:dns-different | WARN:list-no-match | UNKNOWN:current-family-unavailable | UNKNOWN:dns-partial | UNKNOWN:list-partial-no-match) ;;
		*) return 1 ;;
		esac
		case "$cfmgr_health_compare_seen
" in *"
$cfmgr_health_compare_id
"*) return 1 ;; esac
		cfmgr_health_compare_seen="$cfmgr_health_compare_seen
$cfmgr_health_compare_id"
		cfmgr_health_compare_rows=$((cfmgr_health_compare_rows + 1))
		[ "$cfmgr_health_compare_rows" -le 5 ] || return 1
		cfmgr_health_compare_safe="$cfmgr_health_compare_safe
$cfmgr_health_compare_id $cfmgr_health_compare_state $cfmgr_health_compare_reason"
	done
}

cfmgr_health_comparison_row() {
	case $3 in
	dns-equal) cfmgr_health_compare_detail='One exact DNS record in a complete page matches the public family sample observed during this report; publication and write permission remain unproved.' ;;
	dns-absent) cfmgr_health_compare_detail='The complete bounded DNS page contained no exact configured record.' ;;
	dns-multiple) cfmgr_health_compare_detail='The complete bounded DNS page contained multiple exact configured records; duplicates require review.' ;;
	dns-different) cfmgr_health_compare_detail='The single exact DNS value differs from the public family sample observed during this report.' ;;
	dns-partial) cfmgr_health_compare_detail='DNS pagination is incomplete; current-address equality and absence remain unproved.' ;;
	list-member) cfmgr_health_compare_detail='The complete observed list contains the public family sample observed during this report; write permission remains unproved.' ;;
	list-member-partial) cfmgr_health_compare_detail='The partial observed list contains the public family sample observed during this report; remaining pages are unverified.' ;;
	list-no-match) cfmgr_health_compare_detail='The complete observed list does not contain the public family sample observed during this report.' ;;
	list-partial-no-match) cfmgr_health_compare_detail='The partial observed list has no matching current value; absence remains unproved.' ;;
	current-family-unavailable) cfmgr_health_compare_detail='A current public sample for this configured family was unavailable; retained provider values were not compared with history.' ;;
	*) cfmgr_health_compare_detail='The current-address comparison was unavailable or could not finish within its report budget.' ;;
	esac
	cfmgr_health_row "$1" "$2" "$cfmgr_health_compare_detail" current 'Review current family discovery and configured target observations; no write was attempted.' network
}

cfmgr_health_comparison_finish() {
	cfmgr_health_compare_done=''
	if [ "$cfmgr_health_compare_count" -gt 0 ]; then
		if cfmgr_health_comparison_manifest && cfmgr_health_run health-compare /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_status_context/comparison" &&
			[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] && cfmgr_health_comparison_read <"$cfmgr_probe_stdout"; then
			cfmgr_health_compare_done=$cfmgr_health_compare_seen
			while IFS=' ' read -r cfmgr_health_compare_id cfmgr_health_compare_state cfmgr_health_compare_reason; do
				[ -n "$cfmgr_health_compare_id" ] || continue
				cfmgr_health_comparison_row "$cfmgr_health_compare_id" "$cfmgr_health_compare_state" "$cfmgr_health_compare_reason" || return $?
			done <<EOF_HEALTH_COMPARE_SAFE
$cfmgr_health_compare_safe
EOF_HEALTH_COMPARE_SAFE
		else [ "$?" != 3 ] || return 3; fi
	fi
	# Missing receipts/current samples/worker capacity remain explicit. Earlier
	# admitted observations survive a later auth hold but are never history data.
	while IFS=' ' read -r cfmgr_health_compare_role cfmgr_health_compare_ordinal cfmgr_health_compare_family cfmgr_health_compare_base; do
		[ "$cfmgr_health_compare_role" = DNS ] || continue
		cfmgr_health_compare_id=ddns.record.$cfmgr_health_compare_ordinal
		case "$cfmgr_health_compare_done
" in *"
$cfmgr_health_compare_id
"*) continue ;; esac
		cfmgr_health_comparison_row "$cfmgr_health_compare_id" UNKNOWN unavailable || return $?
	done <<EOF_HEALTH_COMPARE_PENDING
$cfmgr_health_compare_pending
EOF_HEALTH_COMPARE_PENDING
	for cfmgr_health_compare_role in primary secondary; do
		for cfmgr_health_compare_family in 4 6; do
			case $cfmgr_health_compare_role:$cfmgr_health_compare_family in
			primary:4) cfmgr_health_compare_present=$cfmgr_health_compare_primary4 ;; primary:6) cfmgr_health_compare_present=$cfmgr_health_compare_primary6 ;;
			secondary:4) cfmgr_health_compare_present=$cfmgr_health_compare_secondary4 ;; secondary:6) cfmgr_health_compare_present=$cfmgr_health_compare_secondary6 ;;
			esac
			[ "$cfmgr_health_compare_present" = 1 ] || continue
			cfmgr_health_compare_id=ip_sync.$cfmgr_health_compare_role.ipv$cfmgr_health_compare_family
			case "$cfmgr_health_compare_done
" in *"
$cfmgr_health_compare_id
"*) continue ;; esac
			cfmgr_health_comparison_row "$cfmgr_health_compare_id" UNKNOWN unavailable || return $?
		done
	done
}

# Private logging projections reuse schema admission and Backup policy math.
cfmgr_status_awk_health_logging_authority() {
	# CFMGR-AWK-BEGIN health_logging_authority
	cfmgr_awk_program='
BEGIN {
    if(!co_observation_ready || co_version!="n2")reject()
    for(i=1;i<256;i++)hh_ord[sprintf("%c",i)]=i
    owners=cs_id(cs_id(1,"ownership"),"components");generation=cs_generation(1,"generation")
    for(i=1;i<=3;i++) {
        f=(i==1?"ddns":(i==2?"ip_sync":"cloudflared"));base=(f=="ip_sync"?"ip-sync":f)
        feature=cs_id(1,f);lognode=cs_id(cs_id(1,"logging"),f);policy=cs_policy(lognode,"policy")
        lg=rg=lh=rh="-";own=0
        for(j=0;(item=co_child[owners,"i" j]);j++) {
            c=cs_string(item,"component",0);p=cs_string(item,"path",0);g=cs_generation(item,"generation");h=cs_string(item,"sha256",1)
            if(c=="history." f && p=="/opt/var/log/" base ".log" && cs_le(g,generation)) {lg=g;lh=(h==""?"-":h)}
            if(c=="history-rule." f && p=="/opt/etc/logrotate.d/cfmgr-" base && cs_le(g,generation)) {rg=g;rh=(h==""?"-":h)}
        }
        requested=(cs_bool(feature,"configured") && cs_bool(lognode,"configured") && !cs_bool(lognode,"opt_out"))
        eligible=(requested && lg!="-" && rg!="-" && rh!="-" && policy)
        out=out "FEATURE " f " " cs_bool(feature,"configured") " " cs_bool(feature,"enabled") " " cs_bool(lognode,"configured") " " cs_bool(lognode,"enabled") " " cs_bool(lognode,"opt_out") " " requested " " (eligible?1:0) " " lg " " lh " " rg " " rh " END\n"
        out=out "SAVED " f " " (policy?hh_policy_value(policy,f):"NONE") "\n"
    }
    if(length(out)>4096)reject()
    printf "CFMGR-LOGGING 1\n%sEND 6 END\n",out;exit
}
'
	# CFMGR-AWK-END health_logging_authority
}

cfmgr_status_awk_health_logging() {
	# CFMGR-AWK-BEGIN health_logging
	cfmgr_awk_program='
function hl_fail() { exit 1 }
function hl_read(p,max,    save,s,x,n) {
    save=RS;RS=sprintf("%c",28);n=(getline s <p)
    if(n<0 || (getline x <p)>0 || length(s)>max || s~/[^ -~\n\t]/ || (s!="" && substr(s,length(s),1)!="\n"))hl_fail()
    close(p);RS=save;return s
}
function hl_uint(s,max) {return s~/^(0|[1-9][0-9]*)$/ && (length(s)<length(max) || length(s)==length(max) && "n" s<="n" max)}
function hl_path(p,    a,n,i) {
    if(p=="/")return 1
    if(p!~/^\// || length(p)>1024 || p~/[^ -~]/ || index(p,"\\") || p~/\/$/)return 0
    n=split(p,a,"/");for(i=2;i<=n;i++)if(a[i]==""||a[i]=="."||a[i]=="..")return 0;return 1
}
function hl_specs(p,    raw,lines,n,i,a,c,q) {
    raw=hl_read(p,32768);n=split(raw,lines,"\n")
    for(i=1;i<n;i++) {
        c=split(lines[i],a,"\t");if(c<2 || c>4 || a[1]!~/^[A-Za-z0-9_-]+$/ || !hl_path(a[2]) || a[1] in path || spec_paths[a[2]]++)hl_fail()
        if(mode=="metadata" || mode=="spec") {if(c!=4 || a[3]!~/^(public|executable|directory)$/ || a[4]!~/^(whole|prefix|metadata)$/)hl_fail()}
        order[++members]=a[1];if(members>256)hl_fail();path[a[1]]=a[2];profile[a[1]]=a[3];operation[a[1]]=a[4]
        q=a[2];while(1){expected[q]=1;if(q=="/")break;sub(/\/[^\/]*$/,"",q);if(q=="")q="/"}
    }
    if(!members)hl_fail()
}
function hl_meta(s,    rest,f,j,p) {
    rest=s
    for(j=1;j<=9;j++) {sub(/^ +/,"",rest);if(!match(rest,/^[^ ]+/))hl_fail();f[j]=substr(rest,1,RLENGTH);rest=substr(rest,RLENGTH+1)}
    sub(/^ +/,"",rest);p=rest;if(!hl_path(p)||!(p in expected)||meta_seen[p]++)hl_fail()
    if(f[1]!~/^[1-9][0-9]*$/ || length(f[1])>20 || length(f[2])!=10 || f[3]!~/^[1-9][0-9]*$/ || f[4]!="0" || f[5]!~/^[0-9]+$/ || !hl_uint(f[6],"11534336"))return
    modes[p]=f[2];links[p]=f[3];inode[p]=f[1];bytes[p]=f[6];meta[p]=s
}
BEGIN {
    mode=ARGV[1];input=ARGV[2];spec=ARGV[3];arg=ARGV[4];ARGC=1
    if(mode=="authority-frame" || mode=="policy") {
        raw=hl_read(input,4096);n=split(raw,lines,"\n");if(n!=9 || lines[1]!="CFMGR-LOGGING 1" || lines[8]!="END 6 END")hl_fail()
        for(i=1;i<=3;i++) {
            f=(i==1?"ddns":(i==2?"ip_sync":"cloudflared"));c=split(lines[i*2],a," ")
            if(c!=14 || a[1]!="FEATURE" || a[2]!=f || a[14]!="END")hl_fail()
            for(j=3;j<=9;j++)if(a[j]!~/^[01]$/)hl_fail()
            for(j=10;j<=12;j+=2)if(a[j]!="-" && (a[j]!~/^[1-9][0-9]*$/ || length(a[j])>20))hl_fail()
            for(j=11;j<=13;j+=2)if(a[j]!="-" && (length(a[j])!=64 || a[j]~/[^0-9a-f]/))hl_fail()
            saved=lines[i*2+1];if(index(saved,"SAVED " f " ")!=1)hl_fail()
            p=substr(saved,length(f)+8);if(p!="NONE" && p!~/^POLICY (native|size|daily|weekly|monthly) [-0-9]+ [-0-9]+ [-0-9]+ END$/)hl_fail()
            if(mode=="policy" && f==spec) {if(p=="NONE")hl_fail();chosen=p}
        }
        if(mode=="policy") {if(chosen=="")hl_fail();print chosen};exit
    }
    if(mode=="debug-check") {
        raw=hl_read(input,65536);n=split(raw,lines,"\n")
        # logrotate 3.22.0 logrotate.c and log.c: one expected -d advisory.
        notice="warning: logrotate in debug mode does nothing except printing debug messages!  Consider using verbose mode (-v) instead if this is not what you want."
        for(i=1;i<n;i++) {
            if(lines[i]==notice) {if(notices++)hl_fail();continue}
            if(tolower(lines[i])~/(^|[ \t])(warning|error):/)hl_fail()
        };exit
    }
    if(mode=="process") {
        raw=hl_read(input,32768);n=split(raw,lines,"\n")
        for(i=1;i<n;i++) {
            c=split(lines[i],a,"\t");if(c!=7 || a[1]!="CANDIDATE" || a[2]!~/^(syslog|cron)$/ || !hl_uint(a[3],"2147483647") || a[3]=="0" || !hl_uint(a[4],"18446744073709551615") || a[5]!~/^health-log-argv\.[1-9][0-9]*[.]out$/ || !hl_path(a[6]) || !hl_uint(a[7],"18446744073709551615") || seen[a[3]]++ || names[a[5]]++)hl_fail()
            receipt=hl_read(spec "/" a[5],32768);sub(/\n$/,"",receipt);k=split(receipt,b," ")
            if(index(receipt,"\n") || b[2]!=a[3] || b[3]!=a[4] || b[k]!="END")hl_fail()
            if(a[2]=="syslog") {if(b[1]!="PROC" || b[4]!="2f6f70742f7362696e2f7379736c6f672d6e67" || !hl_uint(b[5],"64") || b[5]=="0" || k!=b[5]+6)hl_fail();for(j=6;j<k;j++)if(b[j]!~/^([0-9a-f][0-9a-f])+$/)hl_fail()}
            else if(k!=5 || b[1]!="CROND" || b[4]!="2f7661722f73706f6f6c2f63726f6e2f63726f6e74616273")hl_fail()
            out=out receipt "\n"
        }
        printf "%s",out;exit
    }
    hl_specs(spec);if(mode=="spec")exit;raw=hl_read(input,262144);n=split(raw,lines,"\n")
    if(mode=="metadata") {
        parts=split(arg,bounds,"\t");if(parts!=1 && parts!=3)hl_fail();arg=bounds[1];anchor=optroot="-"
        if(arg!~/^(normal|cron)$/)hl_fail()
        if(parts==3) {optroot=bounds[2];anchor=bounds[3];if(optroot!="-" && (!hl_path(optroot) || !hl_path(anchor) || !(optroot==anchor || index(optroot,anchor "/")==1)))hl_fail()}
        for(i=1;i<n;i++)hl_meta(lines[i])
        for(i=1;i<=members;i++) {
            role=order[i];p=path[role];okay=1;chain="";boundary="/"
            if(anchor!="-" && (p==optroot || index(p,optroot "/")==1))boundary=anchor
            while(1) {
                m=modes[p];if(!(p in meta) || substr(m,6,1)=="w" || substr(m,9,1)=="w")okay=0
                if(p==path[role]) {
                    if(profile[role]=="directory") {if(substr(m,1,1)!="d")okay=0}
                    else if(substr(m,1,1)!="-" || (profile[role]=="executable" && substr(m,4,1)!="x"))okay=0
                } else if(substr(m,1,1)!="d")okay=0
                chain=chain "|" meta[p]
                if(p==boundary)break;sub(/\/[^\/]*$/,"",p);if(p=="")p="/"
            }
            # Cron accepts only root protected /var or the native sticky directory.
            if(arg=="cron" && modes["/var"]=="drwxrwxrwt") {
                okay=1;p=path[role];while(1) {m=modes[p];if(!(p in meta) || p!="/var" && (substr(m,6,1)=="w" || substr(m,9,1)=="w") || (p==path[role]?substr(m,1,1)!="-":substr(m,1,1)!="d"))okay=0;if(p=="/")break;sub(/\/[^\/]*$/,"",p);if(p=="")p="/"}
            }
            if(arg=="cron" && (links[path[role]]!=1 || bytes[path[role]]+0<1))okay=0
            print "MEMBER\t" role "\t" okay "\t" (okay?inode[path[role]]:"-") "\t" (okay?bytes[path[role]]:"-") "\t" (okay?modes[path[role]]:"-") "\t" chain
        };exit
    }
    for(i=1;i<=members;i++)reverse[path[order[i]]]=order[i]
    if(mode=="hashes") {
        for(i=1;i<n;i++) {h=substr(lines[i],1,64);p=substr(lines[i],67);if(length(h)!=64 || h~/[^0-9a-f]/ || substr(lines[i],65,2)!=" *" || !(p in reverse) || seen[p]++)hl_fail();digest[p]=h}
        if(n!=members+1)hl_fail();for(i=1;i<=members;i++)print "HASH\t" order[i] "\t" digest[path[order[i]]];exit
    }
    if(mode=="counts") {
        total_b=total_l=0
        for(i=1;i<n;i++) {
            rest=lines[i];sub(/^ +/,"",rest);if(!match(rest,/^[0-9]+/))hl_fail();l=substr(rest,1,RLENGTH);rest=substr(rest,RLENGTH+1);sub(/^ +/,"",rest);if(!match(rest,/^[0-9]+/))hl_fail();bytecount=substr(rest,1,RLENGTH);rest=substr(rest,RLENGTH+1);sub(/^ +/,"",rest);p=rest
            if(!hl_uint(l,"11534336") || !hl_uint(bytecount,"11534336") || l+0>bytecount+0)hl_fail()
            if(i==members+1 && members>1) {if(p!="total" || bytecount+0!=total_b || l+0!=total_l)hl_fail();continue}
            if(!(p in reverse) || seen[p]++)hl_fail();count_b[p]=bytecount;count_l[p]=l;total_b+=bytecount;total_l+=l
        }
        if(n!=members+1+(members>1))hl_fail();for(i=1;i<=members;i++)print "COUNT\t" order[i] "\t" count_b[path[order[i]]] "\t" count_l[path[order[i]]];exit
    }
    hl_fail()
}
'
	# CFMGR-AWK-END health_logging
}

cfmgr_health_log_stage() {
	cfmgr_health_log_direct=$((${cfmgr_health_log_direct:-0} + 1))
	cfmgr_health_log_stage_name=log.$1.$cfmgr_health_log_direct
	cfmgr_health_stage_reserve "$cfmgr_health_log_stage_name" "$2" || return $?
	cfmgr_health_log_stage_file=$cfmgr_status_context/$cfmgr_health_log_stage_name
	(
		set -C
		: >"$cfmgr_health_log_stage_file"
	)
}

cfmgr_health_log_spec_write() {
	[ "${#1}" -le 32768 ] || {
		cfmgr_health_incomplete=1 cfmgr_health_reason=budget
		return 1
	}
	cfmgr_health_log_spec_bytes=${#1}
	[ "$cfmgr_health_log_spec_bytes" -gt 0 ] || cfmgr_health_log_spec_bytes=1
	cfmgr_health_log_stage spec "$cfmgr_health_log_spec_bytes" || return $?
	printf '%s' "$1" >"$cfmgr_health_log_stage_file" || return 1
	cfmgr_health_log_spec_file=$cfmgr_health_log_stage_file
}

cfmgr_health_log_parse() {
	case $1 in
	process) cfmgr_health_log_parse_mode=health-log-process ;;
	*)
		cfmgr_health_log_parse_mode=health-log-inspect
		case $1 in metadata) cfmgr_health_log_inspect_limit=$(((cfmgr_health_log_meta_result_bytes + 511) / 512)) ;;
		hashes | counts) cfmgr_health_log_inspect_limit=4 ;;
		*) cfmgr_health_log_inspect_limit=2 ;;
		esac
		;;
	esac
	cfmgr_health_run "$cfmgr_health_log_parse_mode" /usr/bin/awk "$cfmgr_source/modules/status.sh" "$1" "$2" "$3" "${4:--}" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

# SPEC is a bounded private role/path/profile/operation table. Metadata is
# observed for every unique ancestor; missing members retain independent rows.
cfmgr_health_log_metadata() {
	cfmgr_health_log_meta_spec=$1 cfmgr_health_log_meta_kind=$2
	cfmgr_health_log_parse spec - "$cfmgr_health_log_meta_spec" || return $?
	cfmgr_health_log_meta_arg="$cfmgr_health_log_meta_kind	${cfmgr_health_opt:--}	${cfmgr_health_opt_mount:--}"
	cfmgr_health_log_meta_paths='' cfmgr_health_log_meta_result_bytes=0 cfmgr_health_log_meta_raw_bound=0
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path cfmgr_health_log_profile cfmgr_health_log_op; do
		cfmgr_health_log_meta_boundary=/
		cfmgr_health_log_meta_result_bytes=$((cfmgr_health_log_meta_result_bytes + ${#cfmgr_health_log_role} + 256))
		case $cfmgr_health_log_path in "${cfmgr_health_opt:-/opt}" | "${cfmgr_health_opt:-/opt}"/*) cfmgr_health_log_meta_boundary=${cfmgr_health_opt_mount:-/} ;; esac
		while :; do
			cfmgr_health_log_meta_result_bytes=$((cfmgr_health_log_meta_result_bytes + ${#cfmgr_health_log_path} + 256))
			case "$cfmgr_health_log_meta_paths
" in *"
$cfmgr_health_log_path
"*) ;;
			*)
				cfmgr_health_log_meta_paths="$cfmgr_health_log_meta_paths
$cfmgr_health_log_path"
				cfmgr_health_log_meta_raw_bound=$((cfmgr_health_log_meta_raw_bound + ${#cfmgr_health_log_path} + 256))
				[ "$cfmgr_health_log_meta_raw_bound" -le 65536 ] || {
					cfmgr_health_incomplete=1 cfmgr_health_reason=budget
					return 1
				}
				;;
			esac
			[ "$cfmgr_health_log_path" != "$cfmgr_health_log_meta_boundary" ] || break
			cfmgr_health_log_path=${cfmgr_health_log_path%/*}
			[ -n "$cfmgr_health_log_path" ] || cfmgr_health_log_path=/
		done
	done <"$cfmgr_health_log_meta_spec"
	# Reserve unique native rows before any write. The parser's MEMBER output
	# retains its separate repeated-ancestry bound above.
	cfmgr_health_log_stage metadata "$cfmgr_health_log_meta_raw_bound" || return $?
	cfmgr_health_log_meta_raw=$cfmgr_health_log_stage_file cfmgr_health_log_append_bytes=0
	cfmgr_health_log_append_limit=$cfmgr_health_log_meta_raw_bound
	set --
	while IFS= read -r cfmgr_health_log_path; do
		[ -n "$cfmgr_health_log_path" ] || continue
		set -- "$@" "$cfmgr_health_log_path"
		if [ "$#" = 13 ]; then
			cfmgr_health_log_meta_batch "$@" || return $?
			set --
		fi
	done <<EOF_LOG_METADATA_PATHS
$cfmgr_health_log_meta_paths
EOF_LOG_METADATA_PATHS
	case $# in 0) ;; *) cfmgr_health_log_meta_batch "$@" || return $? ;; esac
	cfmgr_health_log_parse metadata "$cfmgr_health_log_meta_raw" "$cfmgr_health_log_meta_spec" "$cfmgr_health_log_meta_arg" || return $?
	cfmgr_health_log_metadata_file=$cfmgr_probe_stdout
}

cfmgr_health_log_meta_batch() {
	cfmgr_health_log_batch_bytes=0
	for cfmgr_health_log_operand; do cfmgr_health_log_batch_bytes=$((cfmgr_health_log_batch_bytes + ${#cfmgr_health_log_operand} + 256)); done
	cfmgr_health_selected_limit=$(((cfmgr_health_log_batch_bytes + 511) / 512))
	cfmgr_health_run health-log-metadata /bin/ls "$@" || return $?
	case $cfmgr_probe_exit in 0 | 1 | 2) ;; *) return 1 ;; esac
	cfmgr_health_log_append "$cfmgr_probe_stdout" "$cfmgr_health_log_meta_raw" || return $?
}

# Preserve native LF/EOF exactly; never discard or complete a truncated tail.
cfmgr_health_log_append() {
	while :; do
		cfmgr_health_log_append_line=''
		if IFS= read -r cfmgr_health_log_append_line; then
			cfmgr_health_log_append_bytes=$((cfmgr_health_log_append_bytes + ${#cfmgr_health_log_append_line} + 1))
			[ "$cfmgr_health_log_append_bytes" -le "$cfmgr_health_log_append_limit" ] && [ "$cfmgr_health_log_append_bytes" -le 65536 ] || {
				cfmgr_health_incomplete=1 cfmgr_health_reason=budget
				return 1
			}
			printf '%s\n' "$cfmgr_health_log_append_line" >>"$2" || return 1
		else
			[ -z "$cfmgr_health_log_append_line" ]
			return $?
		fi
	done <"$1"
}

cfmgr_health_log_member() {
	cfmgr_health_log_member_ok=0
	while IFS='	' read -r cfmgr_health_log_mtag cfmgr_health_log_mrole cfmgr_health_log_mok cfmgr_health_log_minode cfmgr_health_log_mbytes cfmgr_health_log_mmode cfmgr_health_log_mchain; do
		[ "$cfmgr_health_log_mtag:$cfmgr_health_log_mrole" = "MEMBER:$2" ] || continue
		cfmgr_health_log_member_ok=$cfmgr_health_log_mok
		cfmgr_health_log_member_identity="$cfmgr_health_log_minode $cfmgr_health_log_mbytes $cfmgr_health_log_mmode $cfmgr_health_log_mchain"
		cfmgr_health_log_member_inode=$cfmgr_health_log_minode cfmgr_health_log_member_bytes=$cfmgr_health_log_mbytes
		return 0
	done <"$1"
	return 1
}

cfmgr_health_log_group() {
	# Native output is parsed against exact private operands and total/EOF.
	cfmgr_health_log_group_kind=$1 cfmgr_health_log_group_spec=$2
	cfmgr_health_log_group_bound=0
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path cfmgr_health_log_rest; do
		case $cfmgr_health_log_group_kind in
		hashes) cfmgr_health_log_group_bound=$((cfmgr_health_log_group_bound + ${#cfmgr_health_log_path} + 128)) ;;
		counts) cfmgr_health_log_group_bound=$((cfmgr_health_log_group_bound + ${#cfmgr_health_log_role} + 128)) ;;
		*) return 2 ;;
		esac
		[ "$cfmgr_health_log_group_bound" -le 65536 ] || {
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		}
	done <"$cfmgr_health_log_group_spec"
	cfmgr_health_log_stage metadata "$cfmgr_health_log_group_bound" || return $?
	cfmgr_health_log_group_raw=$cfmgr_health_log_stage_file cfmgr_health_log_group_batch_spec='' cfmgr_health_log_append_bytes=0
	cfmgr_health_log_append_limit=$cfmgr_health_log_group_bound
	set --
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path cfmgr_health_log_rest; do
		set -- "$@" "$cfmgr_health_log_path"
		cfmgr_health_log_group_batch_spec="$cfmgr_health_log_group_batch_spec$cfmgr_health_log_role	$cfmgr_health_log_path
"
		if [ "$#" = 13 ]; then
			cfmgr_health_log_group_batch "$@" || return $?
			set --
			cfmgr_health_log_group_batch_spec=''
		fi
	done <"$cfmgr_health_log_group_spec"
	# Each count batch validates its own exact native total and membership.
	case $# in 0) ;; *) cfmgr_health_log_group_batch "$@" || return $? ;; esac
	if [ "$cfmgr_health_log_group_kind" = counts ]; then
		cfmgr_health_log_group_file=$cfmgr_health_log_group_raw
		return 0
	fi
	cfmgr_health_log_parse "$cfmgr_health_log_group_kind" "$cfmgr_health_log_group_raw" "$cfmgr_health_log_group_spec" || return $?
	cfmgr_health_log_group_file=$cfmgr_probe_stdout
}

cfmgr_health_log_group_batch() {
	case $cfmgr_health_log_group_kind in hashes) cfmgr_health_log_group_mode=health-log-hash cfmgr_health_log_group_tool=$cfmgr_health_openssl ;; counts) cfmgr_health_log_group_mode=health-log-count cfmgr_health_log_group_tool=/usr/bin/wc ;; *) return 2 ;; esac
	cfmgr_health_log_batch_bytes=128
	for cfmgr_health_log_operand; do cfmgr_health_log_batch_bytes=$((cfmgr_health_log_batch_bytes + ${#cfmgr_health_log_operand} + 128)); done
	cfmgr_health_selected_limit=$(((cfmgr_health_log_batch_bytes + 511) / 512))
	cfmgr_health_run "$cfmgr_health_log_group_mode" "$cfmgr_health_log_group_tool" "$@" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	if [ "$cfmgr_health_log_group_kind" = counts ]; then
		cfmgr_health_log_count_raw=$cfmgr_probe_stdout
		cfmgr_health_log_spec_write "$cfmgr_health_log_group_batch_spec" || return $?
		cfmgr_health_log_parse counts "$cfmgr_health_log_count_raw" "$cfmgr_health_log_spec_file" || return $?
	fi
	cfmgr_health_log_append "$cfmgr_probe_stdout" "$cfmgr_health_log_group_raw"
}

cfmgr_health_log_hash_value() {
	cfmgr_health_log_hash=''
	while IFS='	' read -r cfmgr_health_log_htag cfmgr_health_log_hrole cfmgr_health_log_hvalue; do
		[ "$cfmgr_health_log_htag:$cfmgr_health_log_hrole" != "HASH:$2" ] || {
			cfmgr_health_log_hash=$cfmgr_health_log_hvalue
			return 0
		}
	done <"$1"
	return 1
}

# Before/copy/after observations preserve independent members and content hashes.
# Valid snapshots append safe names/digests only, never source content, to the map.
cfmgr_health_log_snapshots() {
	cfmgr_health_log_sources=$1
	cfmgr_health_log_metadata "$cfmgr_health_log_sources" normal || return $?
	cfmgr_health_log_before_meta=$cfmgr_health_log_metadata_file
	cfmgr_health_log_good=''
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path cfmgr_health_log_profile cfmgr_health_log_op; do
		cfmgr_health_log_member "$cfmgr_health_log_before_meta" "$cfmgr_health_log_role" || continue
		[ "$cfmgr_health_log_member_ok" = 1 ] || continue
		cfmgr_health_log_good="$cfmgr_health_log_good$cfmgr_health_log_role	$cfmgr_health_log_path	$cfmgr_health_log_profile	$cfmgr_health_log_op
"
	done <"$cfmgr_health_log_sources"
	[ -n "$cfmgr_health_log_good" ] || return 1
	cfmgr_health_log_spec_write "$cfmgr_health_log_good" || return $?
	cfmgr_health_log_good_spec=$cfmgr_health_log_spec_file
	cfmgr_health_log_group hashes "$cfmgr_health_log_good_spec" || return $?
	cfmgr_health_log_before_hash=$cfmgr_health_log_group_file cfmgr_health_log_copied=''
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path cfmgr_health_log_profile cfmgr_health_log_op; do
		cfmgr_health_log_member "$cfmgr_health_log_before_meta" "$cfmgr_health_log_role" || continue
		cfmgr_health_selected_logical=$cfmgr_health_log_path
		cfmgr_health_selected_attached && cfmgr_health_canonical "$cfmgr_health_log_path" "$cfmgr_health_log_path" || {
			[ "$?" != 3 ] || return 3
			continue
		}
		[ "$cfmgr_health_resolved" = "$cfmgr_health_log_path" ] || continue
		cfmgr_health_log_extent=$cfmgr_health_log_member_bytes
		if [ "$cfmgr_health_log_extent" -gt 11534336 ]; then
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			continue
		fi
		cfmgr_health_selected_limit=$(((cfmgr_health_log_extent + 4095) / 4096 * 8 + 8))
		case $cfmgr_health_log_op in prefix) cfmgr_health_log_copy_mode=health-log-script cfmgr_health_selected_limit=16 ;; *) cfmgr_health_log_copy_mode=health-selected-copy ;; esac
		cfmgr_health_run "$cfmgr_health_log_copy_mode" /bin/dd "$cfmgr_health_log_path" "$cfmgr_health_log_extent" || {
			[ "$?" != 3 ] || return 3
			continue
		}
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || continue
		cfmgr_health_log_copied="$cfmgr_health_log_copied$cfmgr_health_log_role	$cfmgr_probe_stdout	$cfmgr_health_log_extent	$cfmgr_health_log_path
"
	done <"$cfmgr_health_log_good_spec"
	cfmgr_health_log_metadata "$cfmgr_health_log_sources" normal || return $?
	cfmgr_health_log_after_meta=$cfmgr_health_log_metadata_file
	cfmgr_health_log_group hashes "$cfmgr_health_log_good_spec" || return $?
	cfmgr_health_log_after_hash=$cfmgr_health_log_group_file
	cfmgr_health_log_complete=1
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path cfmgr_health_log_profile cfmgr_health_log_op; do
		cfmgr_health_log_member "$cfmgr_health_log_before_meta" "$cfmgr_health_log_role" || {
			cfmgr_health_log_complete=0
			continue
		}
		cfmgr_health_log_saved_identity=$cfmgr_health_log_member_identity
		[ "$cfmgr_health_log_member_ok" = 1 ] || {
			cfmgr_health_log_complete=0
			continue
		}
		cfmgr_health_log_member "$cfmgr_health_log_after_meta" "$cfmgr_health_log_role" || return 1
		if [ "$cfmgr_health_log_member_ok" != 1 ] || [ "$cfmgr_health_log_saved_identity" != "$cfmgr_health_log_member_identity" ]; then
			cfmgr_health_log_complete=0
			continue
		fi
		cfmgr_health_log_hash_value "$cfmgr_health_log_before_hash" "$cfmgr_health_log_role" || return 1
		cfmgr_health_log_saved_hash=$cfmgr_health_log_hash
		cfmgr_health_log_hash_value "$cfmgr_health_log_after_hash" "$cfmgr_health_log_role" || return 1
		[ "$cfmgr_health_log_saved_hash" = "$cfmgr_health_log_hash" ] || {
			cfmgr_health_log_complete=0
			continue
		}
		cfmgr_health_selected_logical=$cfmgr_health_log_path
		cfmgr_health_selected_attached && cfmgr_health_canonical "$cfmgr_health_log_path" "$cfmgr_health_log_path" || {
			[ "$?" != 3 ] || return 3
			cfmgr_health_log_complete=0
			continue
		}
		[ "$cfmgr_health_resolved" = "$cfmgr_health_log_path" ] || {
			cfmgr_health_log_complete=0
			continue
		}
		cfmgr_health_log_found=0
		while IFS='	' read -r cfmgr_health_log_crole cfmgr_health_log_cfile cfmgr_health_log_cbytes cfmgr_health_log_csource; do
			[ "$cfmgr_health_log_crole" = "$cfmgr_health_log_role" ] || continue
			case $cfmgr_health_log_op in prefix) [ "$cfmgr_health_log_cbytes" -le 8192 ] || cfmgr_health_log_cbytes=8192 ;; esac
			cfmgr_health_log_raw="$cfmgr_health_log_raw$cfmgr_health_log_role	$cfmgr_health_log_cfile	$cfmgr_health_log_cbytes	$cfmgr_health_log_saved_hash
"
			cfmgr_health_log_found=1
		done <<EOF_LOG_COPIES
$cfmgr_health_log_copied
EOF_LOG_COPIES
		[ "$cfmgr_health_log_found" = 1 ] || cfmgr_health_log_complete=0
	done <"$cfmgr_health_log_sources"
	[ "$cfmgr_health_log_complete" = 1 ]
}

cfmgr_health_log_stat() {
	IFS= read -r cfmgr_health_log_stat_line 2>/dev/null <"/proc/$1/stat" || return 1
	cfmgr_health_log_stat_pid=${cfmgr_health_log_stat_line%% *}
	case $cfmgr_health_log_stat_pid in "$1") ;; *) return 1 ;; esac
	cfmgr_health_log_stat_comm=${cfmgr_health_log_stat_line#*(}
	cfmgr_health_log_stat_comm=${cfmgr_health_log_stat_comm%)*}
	cfmgr_health_log_stat_tail=${cfmgr_health_log_stat_line##*) }
	case $- in *f*) cfmgr_health_log_stat_noglob=1 ;; *) cfmgr_health_log_stat_noglob=0 ;; esac
	set -f
	# shellcheck disable=SC2086 # Fixed numeric stat fields, never shell code.
	set -- $cfmgr_health_log_stat_tail
	case $cfmgr_health_log_stat_noglob in 0) set +f ;; esac
	case $(($# >= 20)) in 1) ;; *) return 1 ;; esac
	shift 19
	cfmgr_health_log_stat_start=$1
	case $cfmgr_health_log_stat_pid:$cfmgr_health_log_stat_start in *[!0-9:]* | :* | *:) return 1 ;; esac
}

cfmgr_health_log_processes() {
	cfmgr_health_process_ready=0 cfmgr_health_process_scan_complete=0 cfmgr_health_process_file='' cfmgr_health_process_identity_file=''
	cfmgr_health_admit_native /bin/busybox executable && cfmgr_health_admit_native /usr/bin/hexdump executable || return $?
	cfmgr_health_run health-log-pids /usr/bin/awk 65536 || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_pids=$cfmgr_probe_stdout
	# The completed enumerator necessarily sees itself. Its recorded owned PID
	# is already reaped and cannot be an unclassified daemon observation.
	cfmgr_health_log_enumerator_pid=''
	case ${cfmgr_probe_status:-} in reaped) cfmgr_health_log_enumerator_pid=${cfmgr_probe_pid:-} ;; esac
	cfmgr_health_log_stage process-index 32768 || return $?
	cfmgr_health_process_identity_file=$cfmgr_health_log_stage_file cfmgr_health_log_pid_count=0 cfmgr_health_log_process_index_bytes=0 cfmgr_health_log_scan_uncertain=0 cfmgr_health_log_pid_header=0 cfmgr_health_log_pid_end=0
	while :; do
		cfmgr_health_log_pid=''
		if IFS= read -r cfmgr_health_log_pid; then :; else
			[ -z "$cfmgr_health_log_pid" ] && [ "$cfmgr_health_log_pid_end" = 1 ] || return 1
			break
		fi
		[ "$cfmgr_health_log_pid_end" = 0 ] || return 1
		if [ "$cfmgr_health_log_pid_header" = 0 ]; then
			IFS=' ' read -r cfmgr_health_log_pid_tag cfmgr_health_log_pid_version cfmgr_health_log_pid_expected cfmgr_health_log_pid_extra <<EOF_LOG_PID_HEADER
$cfmgr_health_log_pid
EOF_LOG_PID_HEADER
			[ "$cfmgr_health_log_pid" = "CFMGR-HEALTH-PIDS 1 $cfmgr_health_log_pid_expected" ] || return 1
			case $cfmgr_health_log_pid_expected in '' | *[!0-9]* | 0*) return 1 ;; esac
			[ "${#cfmgr_health_log_pid_expected}" -le 4 ] && [ "$cfmgr_health_log_pid_expected" -le 4096 ] || return 1
			cfmgr_health_log_pid_header=1
			continue
		fi
		if [ "$cfmgr_health_log_pid" = "END $cfmgr_health_log_pid_expected" ]; then
			[ "$cfmgr_health_log_pid_count" = "$cfmgr_health_log_pid_expected" ] || return 1
			cfmgr_health_log_pid_end=1
			continue
		fi
		cfmgr_health_log_pid_count=$((cfmgr_health_log_pid_count + 1))
		case $((cfmgr_health_log_pid_count <= 4096)):$cfmgr_health_log_pid in 1:*[!0-9]* | 1: | 0:*) return 1 ;; esac
		case $cfmgr_health_log_pid in "$cfmgr_health_log_enumerator_pid") continue ;; esac
		cfmgr_prerequisites_now || return 1
		case $((cfmgr_probe_now < cfmgr_health_collect_deadline)) in 1) ;; *)
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
			;;
		esac
		cfmgr_health_log_stat "$cfmgr_health_log_pid" || {
			cfmgr_health_log_scan_uncertain=1
			continue
		}
		case $cfmgr_health_log_stat_comm in syslog-ng) cfmgr_health_log_kind=syslog ;; crond | busybox) cfmgr_health_log_kind=cron ;; *) continue ;; esac
		cfmgr_health_log_start=$cfmgr_health_log_stat_start
		cfmgr_health_canonical "/proc/$cfmgr_health_log_pid/exe" || {
			[ "$?" != 3 ] || return 3
			return 1
		}
		cfmgr_health_log_exe=$cfmgr_health_resolved
		case $cfmgr_health_log_kind:$cfmgr_health_log_exe in "syslog:${cfmgr_health_opt:-}/sbin/syslog-ng" | cron:/bin/busybox) ;; *) continue ;; esac
		cfmgr_health_run health-log-proc-meta /bin/ls "/proc/$cfmgr_health_log_pid/exe" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		IFS=' ' read -r cfmgr_health_log_inode cfmgr_health_log_unused <"$cfmgr_probe_stdout" || return 1
		case $cfmgr_health_log_inode in '' | *[!0-9]*) return 1 ;; esac
		[ "/proc/$cfmgr_health_log_pid/exe" -ef "$cfmgr_health_log_exe" ] || return 1
		cfmgr_health_run health-log-hex /usr/bin/hexdump "/proc/$cfmgr_health_log_pid/cmdline" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_health_run health-log-argv /usr/bin/awk "$cfmgr_probe_stdout" "$cfmgr_health_log_kind" "$cfmgr_health_log_pid" "$cfmgr_health_log_start" || return $?
		cfmgr_health_log_skip=0
		if [ "$cfmgr_health_log_kind" = cron ] && [ "$cfmgr_probe_exit" = 4 ] && [ "${cfmgr_probe_status:-reaped}" = reaped ] && [ ! -s "$cfmgr_probe_stdout" ] && [ ! -s "$cfmgr_probe_stderr" ]; then
			cfmgr_health_log_skip=1
		else [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1; fi
		cfmgr_health_log_argv_file=$cfmgr_probe_stdout
		cfmgr_health_canonical "/proc/$cfmgr_health_log_pid/exe" "$cfmgr_health_log_exe" || return $?
		[ "$cfmgr_health_resolved" = "$cfmgr_health_log_exe" ] || return 1
		cfmgr_health_run health-log-proc-meta /bin/ls "/proc/$cfmgr_health_log_pid/exe" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		IFS=' ' read -r cfmgr_health_log_after_inode cfmgr_health_log_unused <"$cfmgr_probe_stdout" || return 1
		[ "$cfmgr_health_log_inode" = "$cfmgr_health_log_after_inode" ] || return 1
		cfmgr_health_log_stat "$cfmgr_health_log_pid" && [ "$cfmgr_health_log_stat_start" = "$cfmgr_health_log_start" ] || return 1
		[ "$cfmgr_health_log_skip" = 0 ] || continue
		cfmgr_health_log_process_index_bytes=$((cfmgr_health_log_process_index_bytes + ${#cfmgr_health_log_kind} + ${#cfmgr_health_log_pid} + ${#cfmgr_health_log_start} + ${#cfmgr_health_log_argv_file} + ${#cfmgr_health_log_exe} + ${#cfmgr_health_log_inode} + 32))
		[ "$cfmgr_health_log_process_index_bytes" -le 32768 ] || {
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		}
		printf 'CANDIDATE\t%s\t%s\t%s\t%s\t%s\t%s\n' "$cfmgr_health_log_kind" "$cfmgr_health_log_pid" "$cfmgr_health_log_start" "${cfmgr_health_log_argv_file##*/}" "$cfmgr_health_log_exe" "$cfmgr_health_log_inode" >>"$cfmgr_health_process_identity_file" || return 1
	done <"$cfmgr_health_log_pids"
	cfmgr_health_log_parse process "$cfmgr_health_process_identity_file" "$cfmgr_status_context" || return $?
	cfmgr_health_process_file=$cfmgr_probe_stdout
	# Fixed assembler mode uses the raw-bundle-approved output basename.
	[ "$cfmgr_health_log_scan_uncertain" = 0 ] || return 1
	cfmgr_health_process_ready=1 cfmgr_health_process_scan_complete=1
}

cfmgr_health_log_cron_boundary() {
	cfmgr_health_canonical "$cfmgr_health_cron_path" "$cfmgr_health_cron_path" || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_cron_path" ] || return 1
	cfmgr_health_log_metadata "$cfmgr_health_log_cron_spec" cron || return $?
	cfmgr_health_log_cron_meta=$cfmgr_health_log_metadata_file
	cfmgr_health_log_member "$cfmgr_health_log_cron_meta" cron || return $?
	[ "$cfmgr_health_log_member_ok" = 1 ] || return 1
	cfmgr_health_log_cron_identity=$cfmgr_health_log_member_identity cfmgr_health_log_cron_bytes=$cfmgr_health_log_member_bytes
	cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_cron_path" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_one_line "$cfmgr_probe_stdout" || return 1
	cfmgr_health_log_cron_mount=$cfmgr_health_log_line
	cfmgr_health_log_cron_identity="$cfmgr_health_log_cron_identity $cfmgr_health_log_cron_mount"
}

cfmgr_health_log_cron() {
	cfmgr_health_cron_ready=0 cfmgr_health_cron_file='' cfmgr_health_cron_identity=''
	cfmgr_health_admit_native /bin/nvram executable || return $?
	cfmgr_health_run health-log-account /bin/nvram || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_one_line "$cfmgr_probe_stdout" || return 1
	cfmgr_health_cron_account=$cfmgr_health_log_line
	case $cfmgr_health_cron_account in '' | . | .. | *[!A-Za-z0-9_-]*) return 1 ;; esac
	[ "${#cfmgr_health_cron_account}" -le 64 ] || return 1
	cfmgr_health_cron_path=/var/spool/cron/crontabs/$cfmgr_health_cron_account
	cfmgr_health_log_spec_write "cron	$cfmgr_health_cron_path	public	whole
" || return $?
	cfmgr_health_log_cron_spec=$cfmgr_health_log_spec_file
	cfmgr_health_log_cron_boundary || return $?
	cfmgr_health_cron_identity=$cfmgr_health_log_cron_identity cfmgr_health_cron_bytes=$cfmgr_health_log_cron_bytes
	[ "$cfmgr_health_cron_bytes" -gt 0 ] || return 1
	cfmgr_health_log_cron_copies=''
	for cfmgr_health_log_cron_pass in first second; do
		cfmgr_health_selected_limit=$(((cfmgr_health_cron_bytes + 511) / 512))
		cfmgr_health_run health-log-cron /bin/dd "$cfmgr_health_cron_path" "$cfmgr_health_cron_bytes" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_health_log_cron_copies="$cfmgr_health_log_cron_copies$cfmgr_health_log_cron_pass	$cfmgr_probe_stdout
"
		cfmgr_health_log_cron_boundary || return $?
		[ "$cfmgr_health_cron_identity" = "$cfmgr_health_log_cron_identity" ] || return 1
	done
	cfmgr_health_log_spec_write "$cfmgr_health_log_cron_copies" || return $?
	cfmgr_health_log_cron_copy_spec=$cfmgr_health_log_spec_file
	cfmgr_health_log_group counts "$cfmgr_health_log_cron_copy_spec" || return $?
	while IFS='	' read -r cfmgr_health_log_tag cfmgr_health_log_role cfmgr_health_log_bytes cfmgr_health_log_lf; do [ "$cfmgr_health_log_bytes" = "$cfmgr_health_cron_bytes" ] || return 1; done <"$cfmgr_health_log_group_file"
	[ "${cfmgr_health_native_openssl_ok:-0}" = 1 ] || return 1
	cfmgr_health_log_group hashes "$cfmgr_health_log_cron_copy_spec" || return $?
	cfmgr_health_log_hash_value "$cfmgr_health_log_group_file" first || return 1
	cfmgr_health_log_cron_sha=$cfmgr_health_log_hash
	cfmgr_health_log_hash_value "$cfmgr_health_log_group_file" second || return 1
	[ "$cfmgr_health_log_cron_sha" = "$cfmgr_health_log_hash" ] || return 1
	cfmgr_health_run health-log-account /bin/nvram || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_one_line "$cfmgr_probe_stdout" && [ "$cfmgr_health_log_line" = "$cfmgr_health_cron_account" ] || return 1
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_path; do [ "$cfmgr_health_log_role" != first ] || cfmgr_health_cron_file=$cfmgr_health_log_path; done <"$cfmgr_health_log_cron_copy_spec"
	cfmgr_health_cron_ready=1
}

cfmgr_health_log_one_line() {
	{
		IFS= read -r cfmgr_health_log_line || return 1
		cfmgr_health_log_extra=''
		if IFS= read -r cfmgr_health_log_extra || [ -n "$cfmgr_health_log_extra" ]; then return 1; fi
	} <"$1"
}

cfmgr_health_logging_collect() {
	if _cfmgr_health_logging_collect; then return 0; else cfmgr_health_logging_code=$?; fi
	[ "$cfmgr_health_logging_code" != 3 ] || return 3
	cfmgr_health_row logging.observation UNKNOWN 'A logging observation could not complete; later independent diagnostic groups remain available.' current 'Review logging prerequisites and report capacity.' logging || :
	return 0
}

_cfmgr_health_logging_collect() {
	# Native observers remain useful to hooks when no logger is requested.
	if cfmgr_health_log_cron; then
		cfmgr_health_row system.cron PASS 'The native scheduler account, protected identity and two content snapshots agreed across three boundaries.' current 'None.' system || return $?
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row system.cron UNKNOWN 'The native scheduler snapshot could not be completed consistently.' current 'Review native scheduler prerequisites and report capacity.' system || return $?
	fi
	if cfmgr_health_log_processes; then
		cfmgr_health_row system.processes PASS 'The bounded process scan completed with executable and start-time checks for relevant candidates.' current 'None.' system || return $?
	else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row system.processes UNKNOWN 'The bounded process scan or a relevant process identity was incomplete.' current 'Review process evidence and report capacity.' system || return $?
	fi
	cfmgr_health_log_authority='' cfmgr_health_log_raw='' cfmgr_health_log_fragments='' cfmgr_health_log_owners=''
	if [ -n "${cfmgr_health_inventory:-}" ] && [ "${cfmgr_health_backup:-missing}" = verified ]; then
		cfmgr_health_run health-log-authority /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" "$cfmgr_source/modules/status.sh" "$cfmgr_source/modules/backup.sh" "$cfmgr_health_config" "$cfmgr_health_config_bytes" || return $?
		if [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then
			cfmgr_health_log_authority=$cfmgr_probe_stdout
			cfmgr_health_log_parse authority-frame "$cfmgr_health_log_authority" - || {
				[ "$?" != 3 ] || return 3
				cfmgr_health_log_authority=''
			}
		fi
	fi
	if [ -z "$cfmgr_health_log_authority" ]; then
		cfmgr_health_row logging.authority UNKNOWN 'Strict retained logging ownership and policy authority was unavailable.' current 'Review retained settings or report capacity.' logging
		return $?
	fi
	cfmgr_health_log_requested=0
	while IFS=' ' read -r cfmgr_health_log_tag cfmgr_health_log_feature cfmgr_health_log_fc cfmgr_health_log_fe cfmgr_health_log_lc cfmgr_health_log_le cfmgr_health_log_opt cfmgr_health_log_request cfmgr_health_log_eligible cfmgr_health_log_lgen cfmgr_health_log_lhash cfmgr_health_log_rgen cfmgr_health_log_rhash cfmgr_health_log_end; do
		[ "$cfmgr_health_log_tag" = FEATURE ] || continue
		cfmgr_health_log_owners="$cfmgr_health_log_owners$cfmgr_health_log_feature	$cfmgr_health_log_request	$cfmgr_health_log_eligible	$cfmgr_health_log_rhash
"
		case $cfmgr_health_log_request:$cfmgr_health_log_eligible in
		0:*) cfmgr_health_row "logging.$cfmgr_health_log_feature.state" SKIP "Retained feature configured=$cfmgr_health_log_fc enabled=$cfmgr_health_log_fe; logging configured=$cfmgr_health_log_lc enabled=$cfmgr_health_log_le opt-out=$cfmgr_health_log_opt; history was not requested." retained 'None.' logging ;;
		1:0) cfmgr_health_row "logging.$cfmgr_health_log_feature.state" UNKNOWN 'Logging history was requested, but owned generation/digest or saved policy was not proved.' retained 'Review retained logging ownership and policy.' logging ;;
		1:1)
			cfmgr_health_log_requested=1
			cfmgr_health_row "logging.$cfmgr_health_log_feature.state" PASS "Retained feature configured=$cfmgr_health_log_fc enabled=$cfmgr_health_log_fe; logging configured=$cfmgr_health_log_lc enabled=$cfmgr_health_log_le opt-out=$cfmgr_health_log_opt; history ownership is eligible." retained 'Observed readiness is assessed separately.' logging
			;;
		esac || return $?
	done <"$cfmgr_health_log_authority"
	[ "$cfmgr_health_log_requested" = 1 ] || return 0
	if [ "${cfmgr_health_entware_ready:-0}" != 1 ] || [ "${cfmgr_health_native_openssl_ok:-0}" != 1 ]; then
		cfmgr_health_row logging.base UNKNOWN 'Logging observations depend on protected Entware identity and native hashing.' current 'Review storage and native prerequisites.' logging
		return $?
	fi
	if _cfmgr_health_logging_base; then cfmgr_health_log_base_state=PASS; else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row logging.base UNKNOWN 'Scribe profile, tools, include inventory or consistent snapshots could not establish readiness.' current 'Review Scribe, native observers and report capacity; no repair was attempted.' logging
		return $?
	fi
	cfmgr_health_row logging.base PASS 'Scribe profile, actual read-only tool probes, complete includes, scheduler and process evidence agree.' current 'Delivery and rotation were not exercised.' logging || return $?
	while IFS='	' read -r cfmgr_health_log_feature cfmgr_health_log_request cfmgr_health_log_eligible cfmgr_health_log_expected; do
		[ "$cfmgr_health_log_eligible" = 1 ] || continue
		cfmgr_health_log_match=0
		while IFS='	' read -r cfmgr_health_log_fragrole cfmgr_health_log_fraghex cfmgr_health_log_fragpath; do
			case $cfmgr_health_log_feature:$cfmgr_health_log_fragpath in ddns:/opt/etc/logrotate.d/cfmgr-ddns | ip_sync:/opt/etc/logrotate.d/cfmgr-ip-sync | cloudflared:/opt/etc/logrotate.d/cfmgr-cloudflared)
				while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_file cfmgr_health_log_bytes cfmgr_health_log_digest; do
					[ "$cfmgr_health_log_role:$cfmgr_health_log_digest" != "$cfmgr_health_log_fragrole:$cfmgr_health_log_expected" ] || cfmgr_health_log_match=1
				done <<EOF_LOG_OWNED_RAW
$cfmgr_health_log_raw
EOF_LOG_OWNED_RAW
				;;
			esac
		done <<EOF_LOG_FRAGMENTS
$cfmgr_health_log_fragments
EOF_LOG_FRAGMENTS
		if [ "$cfmgr_health_log_match" != 1 ]; then
			cfmgr_health_row "logging.$cfmgr_health_log_feature.policy" FAIL 'The included rule does not match the retained owned digest.' current 'Review explicit logging recovery.' logging || return $?
			continue
		fi
		cfmgr_health_log_parse policy "$cfmgr_health_log_authority" "$cfmgr_health_log_feature" || return $?
		cfmgr_health_log_policy_file=$cfmgr_probe_stdout
		cfmgr_health_count "$cfmgr_health_log_policy_file" 256 || return $?
		cfmgr_health_run health-log-assess /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_log_bundle" "$cfmgr_health_log_policy_file" "$cfmgr_health_size" "$cfmgr_health_log_feature" || return $?
		if [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then
			cfmgr_health_row "logging.$cfmgr_health_log_feature.policy" PASS 'The complete observed rule and include chain match the saved canonical policy and owned digest.' current 'Delivery and rotation were not exercised.' logging
		else
			cfmgr_health_row "logging.$cfmgr_health_log_feature.policy" WARN 'Observed logging policy did not establish agreement with the saved policy.' current 'Review Scribe policy and supported include configuration.' logging
		fi || return $?
	done <<EOF_LOG_OWNERS
$cfmgr_health_log_owners
EOF_LOG_OWNERS
}

_cfmgr_health_logging_base() {
	[ "$cfmgr_health_cron_ready:$cfmgr_health_process_ready" = 1:1 ] || return 1
	# The optional link and executables are admitted only on the pinned mount.
	cfmgr_health_entware_attachment || return $?
	cfmgr_health_run health-log-link /usr/bin/readlink /opt/bin/scribe || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_one_line "$cfmgr_probe_stdout" && [ "$cfmgr_health_log_line" = /jffs/scripts/scribe ] || return 1
	for cfmgr_health_log_tool in /opt/sbin/syslog-ng /opt/sbin/logrotate; do
		cfmgr_health_selected_logical=$cfmgr_health_log_tool
		cfmgr_health_selected_resolve || return $?
		cfmgr_health_selected_path=$cfmgr_health_resolved cfmgr_health_selected_profile=executable
		cfmgr_health_selected_metadata || return $?
	done
	cfmgr_health_log_sources_text=''
	for cfmgr_health_log_role in script scribe-config syslog-config rotate-config; do
		case $cfmgr_health_log_role in script) cfmgr_health_log_path=/jffs/scripts/scribe cfmgr_health_log_op=prefix ;; scribe-config) cfmgr_health_log_path=/jffs/addons/scribe.d/config cfmgr_health_log_op=whole ;; syslog-config) cfmgr_health_log_path=/opt/etc/syslog-ng.conf cfmgr_health_log_op=whole ;; rotate-config) cfmgr_health_log_path=/opt/etc/logrotate.conf cfmgr_health_log_op=whole ;; esac
		cfmgr_health_selected_logical=$cfmgr_health_log_path
		cfmgr_health_selected_resolve || return $?
		cfmgr_health_log_sources_text="$cfmgr_health_log_sources_text$cfmgr_health_log_role	$cfmgr_health_resolved	public	$cfmgr_health_log_op
"
	done
	cfmgr_health_log_spec_write "$cfmgr_health_log_sources_text" || return $?
	cfmgr_health_log_snapshots "$cfmgr_health_log_spec_file" || return $?
	for cfmgr_health_log_kind in syslog rotate; do
		case $cfmgr_health_log_kind in syslog) cfmgr_health_log_tool=/opt/sbin/syslog-ng cfmgr_health_log_version_role=syslog-version ;; *) cfmgr_health_log_tool=/opt/sbin/logrotate cfmgr_health_log_version_role=logrotate-version ;; esac
		cfmgr_health_entware_attachment || return $?
		cfmgr_health_run health-log-version "$cfmgr_health_log_tool" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_health_log_raw="$cfmgr_health_log_raw$cfmgr_health_log_version_role	$cfmgr_probe_stdout	-	-
"
	done
	cfmgr_health_entware_attachment || return $?
	cfmgr_health_run health-log-syntax /opt/sbin/syslog-ng || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stdout" ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_entware_attachment || return $?
	cfmgr_health_run health-log-debug /opt/sbin/logrotate || return $?
	# Debug normally uses stderr; stdout must be empty, never concealed.
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stdout" ] || return 1
	cfmgr_health_log_debug=$cfmgr_probe_stderr
	cfmgr_health_log_parse debug-check "$cfmgr_health_log_debug" - || return $?
	cfmgr_health_log_raw="$cfmgr_health_log_raw"'cron	'"$cfmgr_health_cron_file	$cfmgr_health_cron_bytes	-
process	$cfmgr_health_process_file	-	-
debug	$cfmgr_health_log_debug	-	-
"
	cfmgr_health_log_spec_write "debug	$cfmgr_health_log_debug
" || return $?
	cfmgr_health_log_group counts "$cfmgr_health_log_spec_file" || return $?
	IFS='	' read -r cfmgr_health_log_tag cfmgr_health_log_role cfmgr_health_log_debug_bytes cfmgr_health_log_debug_lf <"$cfmgr_health_log_group_file" || return 1
	cfmgr_health_run health-log-includes /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_log_debug" "$cfmgr_health_log_debug_bytes" "$cfmgr_health_log_debug_lf" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_include_file=$cfmgr_probe_stdout cfmgr_health_log_fragment_count=0 cfmgr_health_log_sources_text=''
	while IFS=' ' read -r cfmgr_health_log_tag cfmgr_health_log_pathhex cfmgr_health_log_end cfmgr_health_log_extra; do
		[ "$cfmgr_health_log_tag:$cfmgr_health_log_end:$cfmgr_health_log_extra" = INCLUDE:END: ] || return 1
		cfmgr_health_run health-log-path /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_log_pathhex" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_health_log_one_line "$cfmgr_probe_stdout" || return 1
		cfmgr_health_log_path=$cfmgr_health_log_line
		[ "$cfmgr_health_log_path" != /opt/etc/logrotate.conf ] || continue
		cfmgr_health_log_fragment_count=$((cfmgr_health_log_fragment_count + 1))
		cfmgr_health_log_role=f$cfmgr_health_log_fragment_count
		cfmgr_health_log_fragments="$cfmgr_health_log_fragments$cfmgr_health_log_role	$cfmgr_health_log_pathhex	$cfmgr_health_log_path
"
		cfmgr_health_selected_logical=$cfmgr_health_log_path
		cfmgr_health_selected_resolve || return $?
		cfmgr_health_log_sources_text="$cfmgr_health_log_sources_text$cfmgr_health_log_role	$cfmgr_health_resolved	public	whole
"
		[ "${#cfmgr_health_log_sources_text}" -le 32768 ] || {
			cfmgr_health_incomplete=1 cfmgr_health_reason=budget
			return 1
		}
	done <"$cfmgr_health_log_include_file"
	[ -n "$cfmgr_health_log_sources_text" ] || return 1
	cfmgr_health_log_spec_write "$cfmgr_health_log_sources_text" || return $?
	cfmgr_health_log_snapshots "$cfmgr_health_log_spec_file" || return $?
	cfmgr_health_log_sources_text=''
	while IFS='	' read -r cfmgr_health_log_role cfmgr_health_log_file cfmgr_health_log_bytes cfmgr_health_log_sha; do
		[ -n "$cfmgr_health_log_role" ] || continue
		cfmgr_health_log_sources_text="$cfmgr_health_log_sources_text$cfmgr_health_log_role	$cfmgr_health_log_file
"
	done <<EOF_LOG_RAW_SPEC
$cfmgr_health_log_raw
EOF_LOG_RAW_SPEC
	cfmgr_health_log_spec_write "$cfmgr_health_log_sources_text" || return $?
	cfmgr_health_log_group counts "$cfmgr_health_log_spec_file" || return $?
	cfmgr_health_log_counts=$cfmgr_health_log_group_file
	cfmgr_health_log_stage bundle-index 32768 || return $?
	cfmgr_health_log_index=$cfmgr_health_log_stage_file cfmgr_health_log_bundle_bytes=0 cfmgr_health_log_records=0
	printf 'CFMGR-HEALTH-HISTORY 1\n' >"$cfmgr_health_log_index" || return 1
	while IFS='	' read -r cfmgr_health_log_tag cfmgr_health_log_role cfmgr_health_log_bytes cfmgr_health_log_lf; do
		cfmgr_health_log_file='' cfmgr_health_log_expected=-
		while IFS='	' read -r cfmgr_health_log_rrole cfmgr_health_log_rfile cfmgr_health_log_rbytes cfmgr_health_log_rhash; do
			[ "$cfmgr_health_log_rrole" != "$cfmgr_health_log_role" ] || {
				cfmgr_health_log_file=$cfmgr_health_log_rfile
				cfmgr_health_log_expected=$cfmgr_health_log_rbytes
			}
		done <<EOF_LOG_RAW
$cfmgr_health_log_raw
EOF_LOG_RAW
		[ -n "$cfmgr_health_log_file" ] || return 1
		[ "$cfmgr_health_log_expected" = - ] || [ "$cfmgr_health_log_expected" = "$cfmgr_health_log_bytes" ] || return 1
		cfmgr_health_log_label=$cfmgr_health_log_role cfmgr_health_log_record=DATA
		case $cfmgr_health_log_role in f[0-9]*)
			cfmgr_health_log_record=FRAGMENT
			while IFS='	' read -r cfmgr_health_log_frole cfmgr_health_log_fhex cfmgr_health_log_fpath; do [ "$cfmgr_health_log_frole" != "$cfmgr_health_log_role" ] || cfmgr_health_log_label=$cfmgr_health_log_fhex; done <<EOF_LOG_FRAGMENT_LABELS
$cfmgr_health_log_fragments
EOF_LOG_FRAGMENT_LABELS
			;;
		esac
		printf '%s %s %s %s %s\n' "$cfmgr_health_log_record" "$cfmgr_health_log_label" "${cfmgr_health_log_file##*/}" "$cfmgr_health_log_bytes" "$cfmgr_health_log_lf" >>"$cfmgr_health_log_index" || return 1
		cfmgr_health_log_serialized_label=$cfmgr_health_log_label
		[ "$cfmgr_health_log_role" != debug ] || cfmgr_health_log_serialized_label=rotate-debug
		case $cfmgr_health_log_record in DATA) cfmgr_health_log_overhead=7 ;; *) cfmgr_health_log_overhead=11 ;; esac
		cfmgr_health_log_payload=$((cfmgr_health_log_bytes * 2))
		[ "$cfmgr_health_log_payload" != 0 ] || cfmgr_health_log_payload=1
		cfmgr_health_log_bundle_bytes=$((cfmgr_health_log_bundle_bytes + cfmgr_health_log_overhead + ${#cfmgr_health_log_serialized_label} + cfmgr_health_log_payload))
		cfmgr_health_log_records=$((cfmgr_health_log_records + 1))
	done <"$cfmgr_health_log_counts"
	printf 'END %s %s END\n' "$cfmgr_health_log_records" "$cfmgr_health_log_bundle_bytes" >>"$cfmgr_health_log_index" || return 1
	cfmgr_health_selected_limit=$(((cfmgr_health_log_bundle_bytes + 511) / 512))
	[ "$cfmgr_health_selected_limit" -gt 0 ] || return 1
	cfmgr_health_run health-log-bundle /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_log_index" "$cfmgr_health_log_bundle_bytes" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_bundle=$cfmgr_probe_stdout
	cfmgr_health_run health-log-base /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_health_log_bundle" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_log_one_line "$cfmgr_probe_stdout" || return 1
	case $cfmgr_health_log_line in 'BASE ready '*' END') ;; *) return 1 ;; esac
	cfmgr_health_entware_attachment
}

cfmgr_status_awk_health_backup_plan() {
	# CFMGR-AWK-BEGIN health_backup_plan
	cfmgr_awk_program='
BEGIN {
    if(!co_observation_ready || co_version!="n2")reject()
    now=ENVIRON["CFMGR_HEALTH_BACKUP_NOW"]; clock=ENVIRON["CFMGR_HEALTH_BACKUP_CLOCK"]
    if(clock!~/^[01]$/ || now!~/^(0|[1-9][0-9]*)$/ || length(now)>10)reject()
    print "CFMGR-HEALTH-BACKUP\t1"
    print "DESTINATION\t" co_backup_present "\t" (co_backup_present ? co_backup_saved[1] : "-")
    print "IDENTITY\t" (co_backup_present ? co_backup_saved[2] "\t" co_backup_saved[3] "\t" co_backup_saved[4] : "-\t-\t-")
    last=cs_policy(co_backup,"last_backup"); state="never"; age="unknown"; association="unknown"
    if(last) {
        state="recorded"; stamp=cs_epoch(last,"at")
        if(clock==1 && stamp+0>0 && stamp+0<=now+0)age=sprintf("%.0f",now-stamp)
        saved=cs_optional_uuid(co_backup,"set_id"); prior=cs_string(last,"set_id",0); archive=cs_string(last,"archive_id",0)
        if(saved!="" && saved==prior && hb_uuid(archive) && cs_le(cs_generation(last,"generation"),cs_generation(1,"generation")))association="same-set"
    }
    print "HISTORY\t" state "\t" age "\t" association
    print "END\t4";exit
}
function hb_uuid(s,    a,n,i) {
    n=split(s,a,"-");if(n!=5 || length(a[1])!=8 || length(a[2])!=4 || length(a[3])!=4 || length(a[4])!=4 || length(a[5])!=12)return 0
    for(i=1;i<=5;i++)if(a[i]~/[^0-9a-f]/)return 0;return 1
}
'
	# CFMGR-AWK-END health_backup_plan
}

cfmgr_status_awk_health_backup_observation() {
	# CFMGR-AWK-BEGIN health_backup_observation
	cfmgr_awk_program='
function hb_fail() { exit 1 }
function hb_read(path,max,    saved,raw,extra,n) {
    saved=RS;RS=sprintf("%c",28);n=getline raw <path
    if(n!=1 || (getline extra <path)>0 || length(raw)>max || raw~/[^ -~\t\n]/ || substr(raw,length(raw),1)!="\n")hb_fail()
    close(path);RS=saved;return raw
}
function hb_path(s,    a,n,i) {
    if(s=="/")return 1
    if(length(s)>1024 || s!~/^\// || s~/[^ -~]/ || index(s,"\\"))return 0
    n=split(s,a,"/");for(i=2;i<=n;i++)if(a[i]=="" || a[i]=="." || a[i]=="..")return 0;return 1
}
function hb_plan(path,    raw,n,a,i,c) {
    raw=hb_read(path,4096);n=split(raw,lines,"\n")
    if(n!=6 || lines[1]!="CFMGR-HEALTH-BACKUP\t1" || lines[5]!="END\t4")hb_fail()
    if(split(lines[2],a,"\t")!=3 || a[1]!="DESTINATION" || a[2]!~/^[01]$/)hb_fail()
    selected=a[2];point=a[3]
    if(selected ? !hb_path(point) : point!="-")hb_fail()
    if(split(lines[3],a,"\t")!=4 || a[1]!="IDENTITY")hb_fail()
    uuid=a[2];fs=a[3];root=a[4]
    if(selected) {
        if(length(uuid)>128 || uuid!~/^[A-Za-z0-9][A-Za-z0-9._:-]*$/ || length(fs)>32 || fs!~/^[A-Za-z0-9][A-Za-z0-9_+.-]*$/ || !hb_path(root))hb_fail()
    } else if(uuid!="-" || fs!="-" || root!="-")hb_fail()
    if(split(lines[4],a,"\t")!=4 || a[1]!="HISTORY" || a[2]!~/^(never|recorded)$/ || (a[3]!="unknown" && (a[3]!~/^(0|[1-9][0-9]*)$/ || length(a[3])>10)) || a[4]!~/^(unknown|same-set)$/ || (a[2]=="never" && (a[3]!="unknown" || a[4]!="unknown")))hb_fail()
}
BEGIN {
    mode=ARGV[1];plan=ARGV[2];input=ARGV[3];identity=ARGV[4];ARGC=1
    hb_plan(plan)
    if(mode=="frame")exit
    if(!selected || mode!~/^(mount|identity|folder)$/)hb_fail()
    if(mode=="folder") {
        raw=hb_read(input,4096);if(split(raw,lines,"\n")!=2)hb_fail()
        rest=lines[1]
        for(i=1;i<=9;i++) {sub(/^ +/,"",rest);if(!match(rest,/^[^ ]+/))hb_fail();a[i]=substr(rest,1,RLENGTH);rest=substr(rest,RLENGTH+1)}
        sub(/^ +/,"",rest)
        if(rest!=point "/CFMgr/backup" || a[1]!~/^[1-9][0-9]*$/ || length(a[2])!=10 || substr(a[2],1,1)!="d" || a[3]!~/^[1-9][0-9]*$/ || a[4]!~/^[0-9]+$/ || a[5]!~/^[0-9]+$/ || a[6]!~/^(0|[1-9][0-9]*)$/)hb_fail()
        print "CFMGR-BACKUP-FOLDER 1 observed END";exit
    }
    raw=hb_read(input,8192);if(split(raw,lines,"\n")!=2 || split(lines[1],a,"\t")!=9)hb_fail()
    if(a[1]!~/^[1-9][0-9]*$/ || a[2]!~/^[0-9]+$/ || a[3]!~/^[0-9]+:[0-9]+$/ || !hb_path(a[4]) || !hb_path(a[5]) || a[6]!~/^[A-Za-z0-9][A-Za-z0-9_+.-]*$/ || a[7]!~/^\/dev\/[A-Za-z0-9._\/-]+$/ || a[7]~/\/(\.|\.\.)(\/|$)/ || a[8]~/[^A-Za-z0-9,._=:-]/ || a[9]~/[^A-Za-z0-9,._=:-]/)hb_fail()
    if(a[5]!=point || a[4]!=root || a[6]!=fs) {print "CFMGR-BACKUP-MOUNT 1 mismatch END";exit}
    if(mode=="mount") {print "CFMGR-BACKUP-MOUNT\t1\tmatched\t" a[7] "\t" a[6];exit}
    mount_rw=(index("," a[8] ",",",rw,") && index("," a[9] ",",",rw,"));noexec=(index("," a[8] ",",",noexec,")>0)
    raw=hb_read(identity,512);if(split(raw,lines,"\n")!=3 || lines[1]=="" || length(lines[1])>128 || length(lines[2])>256)hb_fail()
    print "CFMGR-BACKUP-IDENTITY 1 " (lines[1]==uuid ? "matched" : "mismatch") " " (mount_rw ? "rw" : "ro") " " (noexec ? "noexec" : "exec") " END";exit
}
'
	# CFMGR-AWK-END health_backup_observation
}

cfmgr_health_backup_frame() {
	cfmgr_health_run health-backup-observe /usr/bin/awk "$cfmgr_source/modules/status.sh" frame "$cfmgr_health_backup_plan" - - || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]
}

cfmgr_health_backup_recheck() {
	cfmgr_health_canonical "$cfmgr_health_backup_point" "$cfmgr_health_backup_point" || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_backup_point" ] || return 1
	cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_backup_point" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	{
		IFS= read -r cfmgr_health_backup_current || return 1
		cfmgr_health_backup_extra=''
		if IFS= read -r cfmgr_health_backup_extra || [ -n "$cfmgr_health_backup_extra" ]; then return 1; fi
	} <"$cfmgr_probe_stdout"
	[ "$cfmgr_health_backup_current" = "$cfmgr_health_backup_mount_record" ]
}

cfmgr_health_backup_folder_observe() {
	# Observe both components without following a substituted shared parent or
	# accepting a nested mount as the selected drive's backup folder.
	for cfmgr_health_backup_component in "$cfmgr_health_backup_point/CFMgr" "$cfmgr_health_backup_point/CFMgr/backup"; do
		[ -d "$cfmgr_health_backup_component" ] && [ ! -L "$cfmgr_health_backup_component" ] || return 1
		cfmgr_health_canonical "$cfmgr_health_backup_component" "$cfmgr_health_backup_component" || return $?
		[ "$cfmgr_health_resolved" = "$cfmgr_health_backup_component" ] || return 1
		cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_backup_component" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		IFS= read -r cfmgr_health_backup_component_mount <"$cfmgr_probe_stdout" || return 1
		[ "$cfmgr_health_backup_component_mount" = "$cfmgr_health_backup_mount_record" ] || return 1
	done
	cfmgr_health_run health-metadata /bin/ls "$cfmgr_health_backup_point/CFMgr/backup" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_backup_folder_meta=$cfmgr_probe_stdout
	cfmgr_health_run health-backup-observe /usr/bin/awk "$cfmgr_source/modules/status.sh" folder "$cfmgr_health_backup_plan" "$cfmgr_health_backup_folder_meta" - || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_health_backup_collect() {
	if [ -z "$cfmgr_health_inventory" ]; then
		cfmgr_health_row backup.destination SKIP 'Backup observation requires a complete retained schema-2 snapshot.' current 'Review configuration evidence first.' config
		return $?
	fi
	if cfmgr_health_run health-backup-plan /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" "$cfmgr_source/modules/status.sh" "$cfmgr_health_config" "$cfmgr_health_config_bytes" "${cfmgr_status_now:-0}" "${cfmgr_status_clock:-0}" && [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then :; else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row backup.destination UNKNOWN 'A complete private Backup projection was unavailable.' current 'Review retained Backup settings and report limits.' backup
		return $?
	fi
	cfmgr_health_backup_plan=$cfmgr_probe_stdout
	if cfmgr_health_backup_frame; then :; else
		[ "$?" != 3 ] || return 3
		cfmgr_health_row backup.destination UNKNOWN 'Backup projection framing could not be verified.' current 'Review retained Backup settings and report limits.' backup
		return $?
	fi
	cfmgr_health_backup_selected=0 cfmgr_health_backup_point='' cfmgr_health_backup_history=never cfmgr_health_backup_age=unknown cfmgr_health_backup_association=unknown
	while IFS='	' read -r cfmgr_health_backup_tag cfmgr_health_backup_a cfmgr_health_backup_b cfmgr_health_backup_c; do
		case $cfmgr_health_backup_tag in
		DESTINATION) cfmgr_health_backup_selected=$cfmgr_health_backup_a cfmgr_health_backup_point=$cfmgr_health_backup_b ;;
		HISTORY) cfmgr_health_backup_history=$cfmgr_health_backup_a cfmgr_health_backup_age=$cfmgr_health_backup_b cfmgr_health_backup_association=$cfmgr_health_backup_c ;;
		esac
	done <"$cfmgr_health_backup_plan"
	if [ "$cfmgr_health_backup_history" = never ]; then
		cfmgr_health_row backup.history SKIP 'No completed Backup history is recorded.' never 'Create a Backup explicitly when needed.' backup || return $?
	else
		cfmgr_health_backup_history_detail='Recorded Backup history does not prove a current archive exists or is usable.'
		[ "$cfmgr_health_backup_association" != same-set ] || cfmgr_health_backup_history_detail='Recorded Backup history matches the retained set and a nonfuture generation; current archive existence and validity are unproved.'
		[ "$cfmgr_health_backup_age" = unknown ] || cfmgr_health_backup_age="$cfmgr_health_backup_age seconds ago"
		cfmgr_health_row backup.history UNKNOWN "$cfmgr_health_backup_history_detail" "$cfmgr_health_backup_age" 'Use the explicit archive browser for current archive verification.' backup || return $?
	fi
	if [ "$cfmgr_health_backup_selected" = 0 ]; then
		cfmgr_health_row backup.destination SKIP 'No Backup destination is selected.' current 'Select a destination in the Backup menu.' backup
		return $?
	fi
	cfmgr_health_backup_state=UNKNOWN cfmgr_health_backup_detail='The selected Backup destination could not be independently identified; no directory or archive was created.'
	if cfmgr_health_backup_observe; then :; else [ "$?" != 3 ] || return 3; fi
	cfmgr_health_row backup.destination "$cfmgr_health_backup_state" "$cfmgr_health_backup_detail" current 'Review the selected mounted drive; no write test or repair was performed.' backup || return $?
	[ "$cfmgr_health_backup_state" = PASS ] || return 0
	if [ "$cfmgr_health_backup_access" = ro ]; then
		cfmgr_health_row backup.access WARN 'The identified destination is mounted read-only; archive creation cannot write there.' current 'Review the drive mount state before creating an archive.' backup
	else
		cfmgr_health_row backup.access UNKNOWN "The identified mount allows writes and CFMgr/backup=$cfmgr_health_backup_folder; actual write access, free space and archive contents were not tested." current 'Use the explicit Backup workflow when needed.' backup
	fi
}

cfmgr_health_backup_observe() {
	cfmgr_health_canonical "$cfmgr_health_backup_point" "$cfmgr_health_backup_point" || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_backup_point" ] && [ -d "$cfmgr_health_backup_point" ] && [ ! -L "$cfmgr_health_backup_point" ] || return 1
	cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_backup_point" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_backup_mount_file=$cfmgr_probe_stdout
	IFS= read -r cfmgr_health_backup_mount_record <"$cfmgr_health_backup_mount_file" || return 1
	cfmgr_health_run health-backup-observe /usr/bin/awk "$cfmgr_source/modules/status.sh" mount "$cfmgr_health_backup_plan" "$cfmgr_health_backup_mount_file" - || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS='	' read -r cfmgr_health_backup_tag cfmgr_health_backup_version cfmgr_health_backup_match cfmgr_health_backup_device cfmgr_health_backup_fs <"$cfmgr_probe_stdout" || return 1
	if [ "$cfmgr_health_backup_tag" = 'CFMGR-BACKUP-MOUNT 1 mismatch END' ]; then
		cfmgr_health_backup_state=WARN cfmgr_health_backup_detail='Current mountpoint, filesystem or filesystem root differs from the retained selection.'
		return 0
	fi
	[ "$cfmgr_health_backup_tag:$cfmgr_health_backup_version:$cfmgr_health_backup_match" = CFMGR-BACKUP-MOUNT:1:matched ] || return 1
	[ "${cfmgr_health_backup:-missing}" = verified ] || return 1
	cfmgr_health_run health-blkid /sbin/blkid "$cfmgr_health_backup_device" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_run health-backup-uuid /usr/bin/awk "$cfmgr_source/modules/backup.sh" "$cfmgr_probe_stdout" "$cfmgr_health_backup_device" "$cfmgr_health_backup_fs" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_backup_uuid_file=$cfmgr_probe_stdout
	cfmgr_health_run health-backup-observe /usr/bin/awk "$cfmgr_source/modules/status.sh" identity "$cfmgr_health_backup_plan" "$cfmgr_health_backup_mount_file" "$cfmgr_health_backup_uuid_file" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_health_backup_tag cfmgr_health_backup_version cfmgr_health_backup_match cfmgr_health_backup_access cfmgr_health_backup_execution cfmgr_health_backup_end <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_backup_tag:$cfmgr_health_backup_version:$cfmgr_health_backup_end" = CFMGR-BACKUP-IDENTITY:1:END ] || return 1
	cfmgr_health_backup_recheck || return $?
	if [ "$cfmgr_health_backup_match" = mismatch ]; then
		cfmgr_health_backup_state=WARN cfmgr_health_backup_detail='Current volume UUID differs from the retained Backup selection.'
		return 0
	fi
	[ "$cfmgr_health_backup_match" = matched ] || return 1
	cfmgr_health_backup_folder=unverified
	if cfmgr_health_backup_folder_observe; then
		cfmgr_health_backup_folder=observed
	else [ "$?" != 3 ] || return 3; fi
	cfmgr_health_backup_recheck || return $?
	cfmgr_health_backup_state=PASS
	cfmgr_health_backup_detail="Selected mountpoint, volume UUID, filesystem and root matched across repeated identity observations; mount flags=$cfmgr_health_backup_access/$cfmgr_health_backup_execution, CFMgr/backup=$cfmgr_health_backup_folder. Writability and archive validity were not tested."
}

cfmgr_status_awk_health_hooks_authority() {
	# CFMGR-AWK-BEGIN health_hooks_authority
	cfmgr_awk_program='
function hk_id(path) {
    if(path=="/jffs/scripts/services-start") return "services-start"
    if(path=="/jffs/scripts/wan-event") return "wan-event"
    if(path=="/jffs/scripts/dhcpc-event") return "dhcpc-event"
    if(path=="/jffs/scripts/ddns-start") return "ddns-start"
    if(path=="/jffs/scripts/post-mount") return "post-mount"
    if(path=="/jffs/scripts/unmount") return "unmount"
    if(path=="/jffs/scripts/services-stop") return "services-stop"
    return ""
}
BEGIN {
    if(!co_observation_ready || co_version!="n2" || cfmgr_config_mode!="archive-data") reject()
    for(i=1;i<=7;i++) {
        if(i==1) path="/jffs/scripts/services-start"
        else if(i==2) path="/jffs/scripts/wan-event"
        else if(i==3) path="/jffs/scripts/dhcpc-event"
        else if(i==4) path="/jffs/scripts/ddns-start"
        else if(i==5) path="/jffs/scripts/post-mount"
        else if(i==6) path="/jffs/scripts/unmount"
        else path="/jffs/scripts/services-stop"
        order[i]=hk_id(path); fixed[path]=order[i]
    }
    owners=cs_id(cs_id(1,"ownership"),"components")
    root_generation=cs_generation(1,"generation")
    for(i=0;(item=co_child[owners,"i" i]);i++) {
        # Full schema admission already validates every record. Re-read the
        # typed fields here; arbitrary owner components/paths never escape.
        component=cs_string(item,"component",0)
        path=cs_path(item,"path",0)
        gen=cs_generation(item,"generation")
        sha=cs_hash(item,"sha256",1)
        id=hk_id(path)
        if(id!="" && cs_le(gen,root_generation)) {
            owner_count[id]++
            owner_gen[id]=gen
            owner_sha[id]=(sha==""?"-":sha)
        }
    }
    output="CFMGR-HOOKS 1 " root_generation "\n"
    for(i=1;i<=7;i++) {
        id=order[i]
        if(owner_count[id]==1) output=output "HOOK " id " " owner_gen[id] " " owner_sha[id] " END\n"
        else output=output "HOOK " id " - - END\n"
    }
    if(length(output)>2048) reject()
    printf "%sEND 7 END\n",output
    exit
}
'
	# CFMGR-AWK-END health_hooks_authority
}

cfmgr_status_awk_health_hooks_cron() {
	# CFMGR-AWK-BEGIN health_hooks_cron
	cfmgr_awk_program='
function hj_fail() { bad=1; exit 1 }
function hj_read(path, limit,    line,total,n,extra,rc) {
    total=n=0
    while((rc=getline line < path)>0) {
        n++; total+=length(line)+1
        if(length(line)>4096 || total>limit || line~/[^ -~\t]/) hj_fail()
        lines[n]=line
    }
    if(rc<0 || close(path)!=0 || n==0) hj_fail()
    # The caller supplies an independent wc byte count; the LF count plus
    # every line length proves exact final-LF framing and complete EOF.
    if(total!=expected_bytes || n!=expected_lf) hj_fail()
    return n
}
function hj_uint(value,max) {
    return value~/^(0|[1-9][0-9]*)$/ && (length(value)<length(max) || (length(value)==length(max) && "n" value<="n" max))
}
function hj_trim(value) { sub(/^[ \t]+/,"",value); sub(/[ \t]+$/,"",value); return value }
function hj_schedule(line, label,    fields,n,last,tag,schedule,shell) {
    line=hj_trim(line)
    if(line=="" || line~/^#/) return
    if(line~/^SHELL[ \t]*=/) {
        sub(/^SHELL[ \t]*=[ \t]*/,"",line)
        current_shell=(line=="/bin/sh"?"admitted":"unknown")
        return
    }
    n=split(line,fields,/[ \t]+/)
    if(n<6) return
    last=fields[n]
    if(last!="#CFMgrWatchdog#" && last!="#CFMgrCloudflaredUpdate#") return
    # The exact suffix is a separate final token. Never search the command for
    # an ID substring or emit/execute any command bytes.
    if(n<7) hj_fail()
    label=(last=="#CFMgrWatchdog#"?"watchdog":"cloud-update")
    schedule=fields[1] " " fields[2] " " fields[3] " " fields[4] " " fields[5]
    if(label=="watchdog") expected=(schedule=="* * * * *"?"exact":"mismatch")
    else expected=(schedule=="37 3 * * *"?"exact":"mismatch")
    if(++job_count[label]==1) {
        job_schedule[label]=expected
        job_shell[label]=(current_shell=="admitted"?"admitted":"unknown")
    }
}
BEGIN {
    cron=ARGV[1]; process=ARGV[2]; expected_bytes=ARGV[3]; expected_lf=ARGV[4]; process_bytes=ARGV[5]
    ARGC=1
    if(cron!~/^\// || process!~/^\// || !hj_uint(expected_bytes,"131072") || !hj_uint(expected_lf,"131072") || expected_bytes=="0" || !hj_uint(process_bytes,"32768") || process_bytes=="0") hj_fail()
    current_shell="default-unverified"
    n=hj_read(cron,131072)
    for(i=1;i<=n;i++) hj_schedule(lines[i])
    proc_count=0; proc_total=0
    while((rc=getline line < process)>0) {
        proc_total+=length(line)+1
        if(length(line)>32768 || proc_total>32768 || line~/[^ -~\t]/) hj_fail()
        if(line~/^CROND /) {
            c=split(line,p,/ +/)
            if(c!=5 || p[1]!="CROND" || !hj_uint(p[2],"2147483647") || p[2]=="0" || !hj_uint(p[3],"18446744073709551615") || p[4]!="2f7661722f73706f6f6c2f63726f6e2f63726f6e74616273" || p[5]!="END") hj_fail()
            proc_count++
        }
    }
    if(rc<0 || close(process)!=0 || proc_count!=1 || proc_total!=process_bytes || proc_total==0) hj_fail()
    print "CFMGR-JOBS 1"
    for(i=1;i<=2;i++) {
        id=(i==1?"watchdog":"cloud-update")
        count=job_count[id]+0
        if(count==1) {sched=job_schedule[id]; shell=job_shell[id]}
        else {sched=(count==0?"absent":"ambiguous");shell="unknown"}
        print "JOB " id " " count " " sched " " shell " END"
    }
    print "END 2 END"
}
'
	# CFMGR-AWK-END health_hooks_cron
}

cfmgr_status_awk_health_hooks_frame() {
	# CFMGR-AWK-BEGIN health_hooks_frame
	cfmgr_awk_program='
function hf_fail() { exit 1 }
function hf_uint(value,max) { return value~/^(0|[1-9][0-9]*)$/ && (length(value)<length(max) || (length(value)==length(max) && "n" value<="n" max)) }
BEGIN {
    mode=ARGV[1]; input=ARGV[2]; expected_bytes=ARGV[3]; ARGC=1
    if((mode!="authority" && mode!="jobs") || !hf_uint(expected_bytes,"32768") || expected_bytes=="0") hf_fail()
    total=n=0
    while((rc=getline line < input)>0) {
        n++; total+=length(line)+1
        if(length(line)>4096 || total>expected_bytes || line~/[^ -~\t]/ || n>16) hf_fail()
        lines[n]=line
    }
    if(rc<0 || close(input)!=0 || total!=expected_bytes) hf_fail()
    # Validate every field before producing any normalized bytes.
    if(mode=="authority") {
        if(n!=9 || split(lines[1],a," ")!=3 || a[1]!="CFMGR-HOOKS" || a[2]!="1" || !hf_uint(a[3],"99999999999999999999")) hf_fail()
        ids[1]="services-start"; ids[2]="wan-event"; ids[3]="dhcpc-event"; ids[4]="ddns-start"; ids[5]="post-mount"; ids[6]="unmount"; ids[7]="services-stop"
        if(lines[1]!="CFMGR-HOOKS 1 " a[3] || lines[9]!="END 7 END") hf_fail()
        for(i=1;i<=7;i++) {
            if(split(lines[i+1],b," ")!=5 || b[1]!="HOOK" || b[2]!=ids[i] || b[5]!="END") hf_fail()
            if(b[3]=="-") { if(b[4]!="-") hf_fail() }
            else if(!hf_uint(b[3],"99999999999999999999") || b[3]=="0" || (b[4]!="-" && (length(b[4])!=64 || b[4]~/[^0-9a-f]/))) hf_fail()
            gen[i]=b[3]; sha[i]=b[4]
        }
        for(i=1;i<=7;i++) print "HOOK " ids[i] " " gen[i] " " sha[i] " END"
        print "ROOT " a[3] " END"; exit
    }
    if(n!=4 || lines[1]!="CFMGR-JOBS 1" || lines[4]!="END 2 END") hf_fail()
    ids[1]="watchdog"; ids[2]="cloud-update"
    for(i=1;i<=2;i++) {
        if(split(lines[i+1],b," ")!=6 || b[1]!="JOB" || b[2]!=ids[i] || b[6]!="END" || !hf_uint(b[3],"131072")) hf_fail()
        if(b[3]=="0") { if(b[4]!="absent" || b[5]!="unknown") hf_fail() }
        else if(b[3]=="1") { if(b[4]!="exact" && b[4]!="mismatch") hf_fail(); if(b[5]!="admitted" && b[5]!="unknown") hf_fail() }
        else if(b[4]!="ambiguous" || b[5]!="unknown") hf_fail()
        count[i]=b[3]; sched[i]=b[4]; shell[i]=b[5]
    }
    for(i=1;i<=2;i++) print "JOB " ids[i] " " count[i] " " sched[i] " " shell[i] " END"
    exit
}
'
	# CFMGR-AWK-END health_hooks_frame
}

cfmgr_health_hooks_authority_validate() {
	# Count private worker output first; AWK requires exact bytes and final LF.
	cfmgr_health_count "$1" 32768 || return $?
	cfmgr_health_hooks_frame_bytes=$cfmgr_health_size
	cfmgr_health_run health-hooks-frame /usr/bin/awk "$cfmgr_source/modules/status.sh" authority "$1" "$cfmgr_health_hooks_frame_bytes" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_hooks_authority_file=$cfmgr_probe_stdout
}

cfmgr_health_hooks_cron_observe() {
	cfmgr_health_hooks_jobs=''
	[ "${cfmgr_health_cron_ready:-0}" = 1 ] &&
		[ "${cfmgr_health_process_ready:-0}" = 1 ] &&
		[ "${cfmgr_health_process_scan_complete:-0}" = 1 ] || return 1
	[ -f "$cfmgr_health_cron_file" ] && [ ! -L "$cfmgr_health_cron_file" ] &&
		[ -f "$cfmgr_health_process_file" ] && [ ! -L "$cfmgr_health_process_file" ] || return 1
	cfmgr_health_hooks_tab=$(printf '\t')
	cfmgr_health_log_spec_write "cron-observer${cfmgr_health_hooks_tab}${cfmgr_health_cron_file}${cfmgr_health_hooks_tab}public${cfmgr_health_hooks_tab}whole
" || return $?
	cfmgr_health_hooks_spec_file=$cfmgr_health_log_spec_file
	cfmgr_health_log_group counts "$cfmgr_health_hooks_spec_file" || return $?
	cfmgr_health_hooks_tab=$(printf '\t')
	IFS="$cfmgr_health_hooks_tab" read -r cfmgr_health_hooks_tag cfmgr_health_hooks_role cfmgr_health_hooks_bytes cfmgr_health_hooks_lf <"$cfmgr_health_log_group_file" || return 1
	[ "$cfmgr_health_hooks_tag:$cfmgr_health_hooks_role" = COUNT:cron-observer ] &&
		[ "$cfmgr_health_hooks_bytes" = "$cfmgr_health_cron_bytes" ] &&
		[ "$cfmgr_health_hooks_bytes" -le 131072 ] &&
		[ "$cfmgr_health_hooks_lf" -gt 0 ] || return 1
	cfmgr_health_count "$cfmgr_health_process_file" 32768 || return $?
	cfmgr_health_hooks_process_bytes=$cfmgr_health_size
	cfmgr_health_run health-hooks-cron /usr/bin/awk "$cfmgr_source/modules/status.sh" \
		"$cfmgr_health_cron_file" "$cfmgr_health_process_file" \
		"$cfmgr_health_hooks_bytes" "$cfmgr_health_hooks_lf" "$cfmgr_health_hooks_process_bytes" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_hooks_jobs_raw=$cfmgr_probe_stdout
	cfmgr_health_count "$cfmgr_health_hooks_jobs_raw" 32768 || return $?
	cfmgr_health_hooks_frame_bytes=$cfmgr_health_size
	cfmgr_health_run health-hooks-frame /usr/bin/awk "$cfmgr_source/modules/status.sh" jobs "$cfmgr_health_hooks_jobs_raw" "$cfmgr_health_hooks_frame_bytes" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_hooks_jobs=$cfmgr_probe_stdout
}

cfmgr_health_hooks_member_result() {
	cfmgr_health_hooks_member_state=UNKNOWN
	cfmgr_health_log_member "$1" "$2" || return $?
	[ "$cfmgr_health_log_member_ok" = 1 ] || return 0
	case $cfmgr_health_log_member_bytes in '' | *[!0-9]*) return 1 ;; esac
	[ "$cfmgr_health_log_member_bytes" -le 65536 ] || return 0
	cfmgr_health_hooks_total_bytes=$((cfmgr_health_hooks_total_bytes + cfmgr_health_log_member_bytes))
	[ "$cfmgr_health_hooks_total_bytes" -le 262144 ] || return 0
	cfmgr_health_hooks_member_state=PASS
}

cfmgr_health_hooks_files_observe() {
	cfmgr_health_hooks_tab=$(printf '\t') cfmgr_health_hooks_spec=''
	for cfmgr_health_hooks_id in services-start wan-event dhcpc-event ddns-start post-mount unmount services-stop; do
		case $cfmgr_health_hooks_id in
		services-start) cfmgr_health_hooks_path=/jffs/scripts/services-start ;;
		wan-event) cfmgr_health_hooks_path=/jffs/scripts/wan-event ;;
		dhcpc-event) cfmgr_health_hooks_path=/jffs/scripts/dhcpc-event ;;
		ddns-start) cfmgr_health_hooks_path=/jffs/scripts/ddns-start ;;
		post-mount) cfmgr_health_hooks_path=/jffs/scripts/post-mount ;;
		unmount) cfmgr_health_hooks_path=/jffs/scripts/unmount ;;
		services-stop) cfmgr_health_hooks_path=/jffs/scripts/services-stop ;;
		esac
		cfmgr_health_hooks_spec="$cfmgr_health_hooks_spec$cfmgr_health_hooks_id$cfmgr_health_hooks_tab$cfmgr_health_hooks_path$cfmgr_health_hooks_tab""public""$cfmgr_health_hooks_tab""whole
"
	done
	cfmgr_health_log_spec_write "$cfmgr_health_hooks_spec" || return $?
	cfmgr_health_hooks_spec_file=$cfmgr_health_log_spec_file
	cfmgr_health_hooks_metadata_before=''
	if cfmgr_health_log_metadata "$cfmgr_health_hooks_spec_file" normal; then
		cfmgr_health_hooks_metadata_before=$cfmgr_health_log_metadata_file
	else
		cfmgr_health_hooks_rc=$?
		return "$cfmgr_health_hooks_rc"
	fi
	cfmgr_health_hooks_all_metadata=1 cfmgr_health_hooks_total_bytes=0 cfmgr_health_hooks_hash_spec=''
	for cfmgr_health_hooks_id in services-start wan-event dhcpc-event ddns-start post-mount unmount services-stop; do
		if cfmgr_health_hooks_member_result "$cfmgr_health_hooks_metadata_before" "$cfmgr_health_hooks_id"; then
			[ "$cfmgr_health_hooks_member_state" = PASS ] || cfmgr_health_hooks_all_metadata=0
		else
			cfmgr_health_hooks_rc=$?
			[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
			cfmgr_health_hooks_all_metadata=0
		fi
		[ "$cfmgr_health_hooks_member_state" = PASS ] || continue
		case $cfmgr_health_hooks_id in
		services-start) cfmgr_health_hooks_path=/jffs/scripts/services-start ;;
		wan-event) cfmgr_health_hooks_path=/jffs/scripts/wan-event ;;
		dhcpc-event) cfmgr_health_hooks_path=/jffs/scripts/dhcpc-event ;;
		ddns-start) cfmgr_health_hooks_path=/jffs/scripts/ddns-start ;;
		post-mount) cfmgr_health_hooks_path=/jffs/scripts/post-mount ;;
		unmount) cfmgr_health_hooks_path=/jffs/scripts/unmount ;;
		services-stop) cfmgr_health_hooks_path=/jffs/scripts/services-stop ;;
		esac
		cfmgr_health_hooks_hash_spec="$cfmgr_health_hooks_hash_spec$cfmgr_health_hooks_id$cfmgr_health_hooks_tab$cfmgr_health_hooks_path
"
	done
	cfmgr_health_hooks_hashes=''
	if [ -n "$cfmgr_health_hooks_hash_spec" ] && [ "${cfmgr_health_native_openssl_ok:-0}" = 1 ]; then
		cfmgr_health_log_spec_write "$cfmgr_health_hooks_hash_spec" || return $?
		cfmgr_health_hooks_hash_input=$cfmgr_health_log_spec_file
		if cfmgr_health_log_group hashes "$cfmgr_health_hooks_hash_input"; then
			cfmgr_health_hooks_hashes=$cfmgr_health_log_group_file
		else
			cfmgr_health_hooks_rc=$?
			[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
		fi
	fi
	cfmgr_health_hooks_metadata_after=''
	if cfmgr_health_log_metadata "$cfmgr_health_hooks_spec_file" normal; then
		cfmgr_health_hooks_metadata_after=$cfmgr_health_log_metadata_file
	else
		cfmgr_health_hooks_rc=$?
		[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
	fi
	cfmgr_health_hooks_after_complete=1
	if [ -n "$cfmgr_health_hooks_metadata_after" ]; then
		for cfmgr_health_hooks_id in services-start wan-event dhcpc-event ddns-start post-mount unmount services-stop; do
			cfmgr_health_log_member "$cfmgr_health_hooks_metadata_before" "$cfmgr_health_hooks_id"
			cfmgr_health_hooks_rc=$?
			[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
			cfmgr_health_hooks_before_rc=$cfmgr_health_hooks_rc
			cfmgr_health_hooks_before_ok=$cfmgr_health_log_member_ok cfmgr_health_hooks_before_identity=$cfmgr_health_log_member_identity
			cfmgr_health_log_member "$cfmgr_health_hooks_metadata_after" "$cfmgr_health_hooks_id"
			cfmgr_health_hooks_rc=$?
			[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
			[ "$cfmgr_health_hooks_before_rc:$cfmgr_health_hooks_before_ok:$cfmgr_health_log_member_ok:$cfmgr_health_hooks_before_identity" = "0:1:1:$cfmgr_health_log_member_identity" ] || cfmgr_health_hooks_after_complete=0
		done
	else cfmgr_health_hooks_after_complete=0; fi
	cfmgr_health_hooks_all_match=1 cfmgr_health_hooks_match_count=0
	if [ -n "$cfmgr_health_hooks_metadata_after" ] && [ -n "$cfmgr_health_hooks_hashes" ] &&
		[ -n "$cfmgr_health_hooks_authority_file" ] && [ "$cfmgr_health_hooks_all_metadata" = 1 ] && [ "$cfmgr_health_hooks_after_complete" = 1 ]; then
		for cfmgr_health_hooks_id in services-start wan-event dhcpc-event ddns-start post-mount unmount services-stop; do
			cfmgr_health_hooks_owner_sha=''
			while IFS=' ' read -r cfmgr_health_hooks_tag cfmgr_health_hooks_owner_id cfmgr_health_hooks_owner_gen cfmgr_health_hooks_owner_value cfmgr_health_hooks_end; do
				[ "$cfmgr_health_hooks_tag:$cfmgr_health_hooks_owner_id:$cfmgr_health_hooks_end" != "HOOK:$cfmgr_health_hooks_id:END" ] || cfmgr_health_hooks_owner_sha=$cfmgr_health_hooks_owner_value
			done <"$cfmgr_health_hooks_authority_file"
			cfmgr_health_log_hash_value "$cfmgr_health_hooks_hashes" "$cfmgr_health_hooks_id"
			cfmgr_health_hooks_observed_sha=$cfmgr_health_log_hash
			if [ -z "$cfmgr_health_hooks_owner_sha" ] || [ "$cfmgr_health_hooks_owner_sha" = - ] ||
				[ -z "$cfmgr_health_hooks_observed_sha" ] || [ "$cfmgr_health_hooks_owner_sha" != "$cfmgr_health_hooks_observed_sha" ]; then
				cfmgr_health_hooks_all_match=0
			else cfmgr_health_hooks_match_count=$((cfmgr_health_hooks_match_count + 1)); fi
		done
	fi
	if [ "$cfmgr_health_hooks_all_metadata" = 1 ] && [ "$cfmgr_health_hooks_after_complete" = 1 ]; then
		cfmgr_health_hooks_files_state=PASS
		cfmgr_health_hooks_files_detail='All seven fixed hook files had protected metadata before and after observation.'
	fi
	if [ "$cfmgr_health_hooks_all_match" = 1 ] && [ "$cfmgr_health_hooks_match_count" = 7 ]; then
		cfmgr_health_hooks_integrity_state=PASS
		cfmgr_health_hooks_integrity_detail='All seven fixed hook files matched eligible retained whole-file digests across stable protected metadata.'
	fi
}

cfmgr_health_hooks_jobs_observe() {
	if cfmgr_health_hooks_cron_observe; then
		while IFS=' ' read -r cfmgr_health_hooks_tag cfmgr_health_hooks_job cfmgr_health_hooks_count cfmgr_health_hooks_sched cfmgr_health_hooks_shell cfmgr_health_hooks_end; do
			[ "$cfmgr_health_hooks_tag:$cfmgr_health_hooks_end" = JOB:END ] || continue
			case $cfmgr_health_hooks_count:$cfmgr_health_hooks_sched:$cfmgr_health_hooks_shell in
			1:exact:admitted) cfmgr_health_hooks_job_state=PASS ;;
			1:mismatch:*) cfmgr_health_hooks_job_state=WARN ;;
			*:ambiguous:*) cfmgr_health_hooks_job_state=WARN ;;
			*) cfmgr_health_hooks_job_state=UNKNOWN ;;
			esac
			case $cfmgr_health_hooks_job in watchdog) cfmgr_health_hooks_cron_state=$cfmgr_health_hooks_job_state ;; cloud-update) cfmgr_health_hooks_update_state=$cfmgr_health_hooks_job_state ;; esac
		done <"$cfmgr_health_hooks_jobs"
	else
		cfmgr_health_hooks_rc=$?
		[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
	fi
	case $cfmgr_health_hooks_cron_state in
	PASS) cfmgr_health_hooks_watchdog_detail='One watchdog label had the expected fixed schedule and explicit /bin/sh setting.' ;;
	WARN) cfmgr_health_hooks_watchdog_detail='The observed watchdog label was duplicated or had a mismatched schedule.' ;;
	*) cfmgr_health_hooks_watchdog_detail='The watchdog label, schedule, shell, or CROND receipt could not be established.' ;;
	esac
	case $cfmgr_health_hooks_update_state in
	PASS) cfmgr_health_hooks_update_detail='One update label had the expected fixed schedule and explicit /bin/sh setting.' ;;
	WARN) cfmgr_health_hooks_update_detail='The observed update label was duplicated or had a mismatched schedule.' ;;
	*) cfmgr_health_hooks_update_detail='The update label, schedule, shell, or CROND receipt could not be established.' ;;
	esac
}

cfmgr_health_hooks_collect() {
	# Ordinary observation failure is contained to its group; status 3 means the
	# shared supervisor became unresolved and must abort the enclosing report.
	cfmgr_health_hooks_cron_state=UNKNOWN cfmgr_health_hooks_update_state=UNKNOWN
	cfmgr_health_hooks_files_state=UNKNOWN cfmgr_health_hooks_integrity_state=UNKNOWN
	cfmgr_health_hooks_dispatch_state=UNKNOWN
	cfmgr_health_hooks_files_detail='The seven fixed hook files were not all observed under protected metadata.'
	cfmgr_health_hooks_integrity_detail='Whole-file hash comparisons were unavailable or inconclusive.'
	cfmgr_health_hooks_watchdog_detail='The watchdog label, schedule, shell, or CROND receipt could not be established.'
	cfmgr_health_hooks_update_detail='The update label, schedule, shell, or CROND receipt could not be established.'
	cfmgr_health_hooks_authority_file=''
	if [ "${cfmgr_health_config:-unavailable}" != unavailable ]; then
		if cfmgr_health_run health-hooks-authority /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
			"$cfmgr_source/modules/status.sh" "$cfmgr_health_config" "$cfmgr_health_config_bytes"; then
			if [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then
				cfmgr_health_hooks_authority_raw=$cfmgr_probe_stdout
				if cfmgr_health_hooks_authority_validate "$cfmgr_health_hooks_authority_raw"; then
					:
				else
					cfmgr_health_hooks_rc=$?
					[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
				fi
			fi
		else
			cfmgr_health_hooks_rc=$?
			[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
		fi
	fi
	if cfmgr_health_hooks_files_observe; then
		:
	else
		cfmgr_health_hooks_rc=$?
		[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
	fi
	if cfmgr_health_hooks_jobs_observe; then
		:
	else
		cfmgr_health_hooks_rc=$?
		[ "$cfmgr_health_hooks_rc" != 3 ] || return 3
	fi
	cfmgr_health_row hooks.files "$cfmgr_health_hooks_files_state" "$cfmgr_health_hooks_files_detail" current 'No hook was executed.' hooks || return $?
	cfmgr_health_row hooks.integrity "$cfmgr_health_hooks_integrity_state" "$cfmgr_health_hooks_integrity_detail" retained 'Whole-file digest comparison does not prove managed-block integrity.' hooks || return $?
	cfmgr_health_row hooks.watchdog "$cfmgr_health_hooks_cron_state" "$cfmgr_health_hooks_watchdog_detail" current 'Schedule evidence does not prove dispatch or lifecycle authority.' hooks || return $?
	cfmgr_health_row hooks.cloud-update "$cfmgr_health_hooks_update_state" "$cfmgr_health_hooks_update_detail" current 'Schedule evidence does not prove dispatch or lifecycle authority.' hooks || return $?
	cfmgr_health_row hooks.dispatch UNKNOWN 'Fixed hook producers have not been implemented or verified.' current 'Review producer integration separately; no hook was sourced or executed.' hooks
}

cfmgr_status_awk_health_flat() {
	# CFMGR-AWK-BEGIN health_flat
	cfmgr_awk_program='
function hf_bad() {bad=1}
BEGIN {
    input=ARGV[1];bytes=ARGV[2];lf=ARGV[3];complete=ARGV[4];ARGC=1
    if(bytes!~/^(0|[1-9][0-9]*)$/ || bytes>32768 || lf!~/^(0|[1-9][0-9]*)$/ || lf>1024 || complete!~/^[01]$/)exit 1
    guards["entry.stage"]=1;guards[".setup.complete"]=1;guards[".storage-observation"]=1
    guards[".config-save.preparing"]=1;guards[".config-save"]=1;guards[".config-save.retired"]=1
    total=rows=0
    while((rc=getline line < input)>0) {
        total+=length(line)+1;rows++
        if(total>32768 || rows>1024) {hf_bad();break}
        if(line in guards)present=1
        if(line=="" || line~/[^ -~]/ || index(line,"/") || line=="." || line==".." || seen[line]++)hf_bad()
    }
    if(rc<0 || close(input)!=0 || total!=bytes || rows!=lf || !complete)hf_bad()
    print "CFMGR-GUARDS 1 " (present?"WARN":(bad?"UNKNOWN":"PASS")) " END"
    exit
}
'
	# CFMGR-AWK-END health_flat
}

cfmgr_status_awk_health_package() {
	# CFMGR-AWK-BEGIN health_package
	cfmgr_awk_program='
function pi_fail() {exit 1}
function pi_read(path,limit,    saved,raw,extra,rc) {
    saved=RS;RS="\034";rc=getline raw < path
    if(rc<0 || length(raw)>limit || raw~/[^ -~\t\n]/ || (raw!="" && substr(raw,length(raw),1)!="\n") || (getline extra < path)!=0)pi_fail()
    if(close(path)!=0)pi_fail();RS=saved;return raw
}
function pi_private(name) {
    if(name=="" || length(name)>128 || name~/[^A-Za-z0-9._-]/ || index(name,".."))pi_fail()
    return context "/" name
}
function pi_fixed(    ids,paths,n,i) {
    n=split("entry catalog backup manager status helpers-empty worker hooks-empty lib-empty config execution logging network package storage",ids," ")
    split("cfmgr.sh catalog.txt modules/backup.sh modules/manager.sh modules/status.sh modules/helpers/.gitkeep modules/helpers/worker.sh modules/hooks/.gitkeep modules/lib/.gitkeep modules/lib/config.sh modules/lib/execution.sh modules/lib/logging.sh modules/lib/network.sh modules/lib/package.sh modules/lib/storage.sh",paths," ")
    for(i=1;i<=n;i++) {fixed[paths[i]]=ids[i];byrole[ids[i]]=paths[i];order[i]=ids[i]}
    dirs["modules"]="d0";dirs["modules/lib"]="d1";dirs["modules/helpers"]="d2";dirs["modules/hooks"]="d3"
}
function pi_metadata(path,side,    raw,lines,n,i,f,c,r) {
    raw=pi_read(path,65536);n=split(raw,lines,"\n")
    if(n!=21)pi_fail()
    for(i=1;i<n;i++) {
        c=split(lines[i],f,"\t");r=f[2]
        if(c!=7 || f[1]!="MEMBER" || (!(r in byrole) && r!="manifest" && r!~/^d[0-3]$/) || metaseen[side,r]++ || f[3]!~/^[01]$/)pi_fail()
        meta[side,r]=lines[i];okay[side,r]=f[3];size[side,r]=f[5];mode[side,r]=f[6]
    }
}
function pi_descendant(path,    j) {
    for(j=1;j<=pk_count;j++)if(index(pk_paths[j],path "/")==1)return 1
    return 0
}
function pi_checked(role,limit,    raw,n) {
    if(!(role in sources) || !(role in countbytes))pi_fail()
    raw=pi_read(sources[role],limit);n=split(raw,pi_lines,"\n")-1
    if(length(raw)!=countbytes[role] || n!=countlf[role])pi_fail()
    return raw
}
BEGIN {
    context=ARGV[1];input=ARGV[2];ARGC=1
    pi_fixed();raw=pi_read(input,8192);n=split(raw,lines,"\n")
    if(n>40 || n<20 || lines[n-1]!="END")pi_fail()
    if(split(lines[1],a,"\t")!=4 || a[1]!="CFMGR-PACKAGE" || a[2]!="1" || a[3]!~/^[0-9A-Za-z._-]+$/ || a[4]!="verified:verified:verified:verified:verified")pi_fail()
    version=a[3]
    for(i=2;i<n-1;i++) {
        c=split(lines[i],a,"\t")
        if(a[1]=="ORIGINAL") {
            if(c!=5 || !(a[5] in fixed) || a[5]~/[.]gitkeep$/ || original[a[5]]++)pi_fail()
            omode[a[5]]=a[2];obytes[a[5]]=a[3];osha[a[5]]=a[4];original_count++
        } else if(a[1]=="SOURCE") {
            if(c!=3 || a[2]!~/^(manifest|catalog|d0|d1|d2|d3)$/ || a[2] in sources)pi_fail()
            sources[a[2]]=pi_private(a[3]);source_count++
        } else {
            if(c!=2 || a[1]!~/^(COUNTS|BEFORE|AFTER|HASHES)$/ || a[1] in receipt)pi_fail()
            receipt[a[1]]=pi_private(a[2]);receipt_count++
        }
    }
    if(original_count!=12 || source_count!=6 || receipt_count!=4)pi_fail()
    raw=pi_read(receipt["COUNTS"],8192);n=split(raw,lines,"\n")
    if(n!=7)pi_fail()
    for(i=1;i<n;i++) {
        if(split(lines[i],a,"\t")!=4 || a[1]!="COUNT" || !(a[2] in sources) || a[2] in countbytes || a[3]!~/^(0|[1-9][0-9]*)$/ || a[4]!~/^(0|[1-9][0-9]*)$/ || a[3]>131072 || a[4]>1024)pi_fail()
        countbytes[a[2]]=a[3];countlf[a[2]]=a[4]
    }
    raw=pi_checked("manifest",131072)
    if(!pk_manifest(sources["manifest"],version))pi_fail()
    raw=pi_checked("catalog",131072)
    if(!pk_catalog(sources["catalog"],version))pi_fail()
    for(p in original)if(pk_mode[p]!=omode[p] || pk_bytes[p]!=obytes[p] || pk_sha[p]!=osha[p])pi_fail()
    # New manifest records remain passive: do not import, recurse or claim their
    # content validated. Fixed empty placeholders are required and separately checked.
    extension=0
    for(i=1;i<=pk_count;i++) {
        p=pk_paths[i]
        if(!(p in fixed))extension=1
    }
    pi_metadata(receipt["BEFORE"],"before");pi_metadata(receipt["AFTER"],"after")
    for(r in byrole) {
        p=byrole[r]
        if(!pk_seen[p] || okay["before",r]!=1 || okay["after",r]!=1 || meta["before",r]!=meta["after",r])pi_fail()
        expected=(r=="entry" || r=="worker"?"-rwxr-xr-x":"-rw-r--r--")
        if(mode["after",r]!=expected || size["after",r]!=pk_bytes[p] || pk_mode[p]!=(expected=="-rwxr-xr-x"?"0755":"0644"))pi_fail()
        if(r~/empty$/ && (pk_bytes[p]!="0" || pk_sha[p]!="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))pi_fail()
    }
    if(okay["before","manifest"]!=1 || meta["before","manifest"]!=meta["after","manifest"] || size["after","manifest"]!=countbytes["manifest"] || size["after","catalog"]!=countbytes["catalog"])pi_fail()
    for(d in dirs) {
        r=dirs[d]
        if(okay["before",r]!=1 || meta["before",r]!=meta["after",r])pi_fail()
        raw=pi_checked(r,32768);n=split(raw,lines,"\n")
        for(i=1;i<n;i++) {
            name=lines[i];p=d "/" name
            if(name=="" || index(name,"/") || name=="." || name==".." || observed[p]++)pi_fail()
            if(name~/[^A-Za-z0-9_.-]/)unexpected=1
            if(!(p in pk_seen) && !(p in dirs) && !pi_descendant(p))unexpected=1
        }
    }
    for(p in fixed)if(p~/^modules\// && !(p in observed))pi_fail()
    for(d in dirs)if(d!="modules" && !(d in observed))pi_fail()
    raw=pi_read(receipt["HASHES"],1024);n=split(raw,lines,"\n")
    if(n!=3)pi_fail()
    for(i=1;i<n;i++) {
        if(split(lines[i],a,"\t")!=3 || a[1]!="HASH" || a[2]!~/^(entry|catalog)$/ || hashes[a[2]]++ || a[3]!=pk_sha[byrole[a[2]]])pi_fail()
    }
    print "CFMGR-PACKAGE 1 " (unexpected?"FAIL":(extension?"UNKNOWN":"PASS")) " END"
    exit
}
'
	# CFMGR-AWK-END health_package
}

# A fixed flat native listing is supervised and output/memory bounded. The child
# pins its directory before exec; callers compare protected attachment afterwards.
cfmgr_health_flat_list() {
	cfmgr_health_flat_path=$1 cfmgr_health_flat_complete=0
	cfmgr_health_run health-flat-list /bin/ls "$1" || return $?
	cfmgr_health_flat_file=$cfmgr_probe_stdout
	if [ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]; then cfmgr_health_flat_complete=1; fi
}

cfmgr_health_recovery_collect() {
	cfmgr_health_recovery_state=UNKNOWN
	# Preserve positive basic observations even when a later directory read fails.
	case ${cfmgr_status_storage_observation:-0}:${cfmgr_status_save_pending:-0} in 0:0) ;; *) cfmgr_health_recovery_state=WARN ;; esac
	if _cfmgr_health_recovery_collect; then :; else [ "$?" != 3 ] || return 3; fi
	case $cfmgr_health_recovery_state in
	PASS) cfmgr_health_recovery_detail='A complete bounded listing of the unchanged protected support root contained none of the six known launch guards.' ;;
	WARN) cfmgr_health_recovery_detail='A known retained launch guard was observed; its contents and recovery action were not evaluated.' ;;
	*) cfmgr_health_recovery_detail='The bounded support-root observation could not establish absence of retained launch guards.' ;;
	esac
	cfmgr_health_row recovery.guards "$cfmgr_health_recovery_state" "$cfmgr_health_recovery_detail" current 'Use explicit recovery when required; health makes no recovery changes.' recovery
}

_cfmgr_health_recovery_collect() {
	cfmgr_health_log_spec_write "root	$cfmgr_source	directory	metadata
" || return $?
	cfmgr_health_recovery_spec=$cfmgr_health_log_spec_file
	cfmgr_health_log_metadata "$cfmgr_health_recovery_spec" normal || return $?
	cfmgr_health_log_member "$cfmgr_health_log_metadata_file" root || return $?
	[ "$cfmgr_health_log_member_ok" = 1 ] || return 1
	cfmgr_health_recovery_before=$cfmgr_health_log_member_identity
	cfmgr_health_flat_list "$cfmgr_source" || return $?
	cfmgr_health_recovery_file=$cfmgr_health_flat_file cfmgr_health_recovery_complete=$cfmgr_health_flat_complete
	cfmgr_health_log_spec_write "root	$cfmgr_health_recovery_file
" || return $?
	cfmgr_health_log_group counts "$cfmgr_health_log_spec_file" || return $?
	IFS='	' read -r cfmgr_health_flat_tag cfmgr_health_flat_role cfmgr_health_flat_bytes cfmgr_health_flat_lf <"$cfmgr_health_log_group_file" || return 1
	[ "$cfmgr_health_flat_tag:$cfmgr_health_flat_role" = COUNT:root ] || return 1
	cfmgr_health_run health-flat-check /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_health_recovery_file" "$cfmgr_health_flat_bytes" "$cfmgr_health_flat_lf" "$cfmgr_health_recovery_complete" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_health_flat_tag cfmgr_health_flat_version cfmgr_health_flat_state cfmgr_health_flat_end cfmgr_health_flat_extra <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_flat_tag:$cfmgr_health_flat_version:$cfmgr_health_flat_end:$cfmgr_health_flat_extra" = CFMGR-GUARDS:1:END: ] || return 1
	case $cfmgr_health_flat_state in WARN) cfmgr_health_recovery_state=WARN ;; PASS | UNKNOWN) ;; *) return 1 ;; esac
	cfmgr_health_log_metadata "$cfmgr_health_recovery_spec" normal || return $?
	cfmgr_health_log_member "$cfmgr_health_log_metadata_file" root || return $?
	[ "$cfmgr_health_log_member_ok:$cfmgr_health_log_member_identity" = "1:$cfmgr_health_recovery_before" ] || return 1
	[ "$cfmgr_health_recovery_state" = WARN ] || cfmgr_health_recovery_state=$cfmgr_health_flat_state
}

cfmgr_health_package_collect() {
	cfmgr_health_package_state=UNKNOWN
	if _cfmgr_health_package_collect; then :; else [ "$?" != 3 ] || return 3; fi
	case $cfmgr_health_package_state in
	PASS) cfmgr_health_package_detail='Complete grammar and fixed flat inventory match the earlier entry-verified generation, with current installed-entry/catalog hashes and stable protected metadata. This is a sequence of observations, not an atomic rehash of all code.' ;;
	FAIL) cfmgr_health_package_detail='The completed inspected module-directory inventory contained an object absent from the manifest.' ;;
	*) cfmgr_health_package_detail='Complete package agreement was not established; missing prerequisites, changed metadata or uninspected passive extensions remain possible.' ;;
	esac
	cfmgr_health_row package.inventory "$cfmgr_health_package_state" "$cfmgr_health_package_detail" current 'Use explicit complete-package verification or recovery; health imports no extra files.' package
}

_cfmgr_health_package_collect() {
	[ "${cfmgr_health_package:-missing}:${cfmgr_health_catalog:-missing}:${cfmgr_health_backup:-missing}:${cfmgr_health_manager:-missing}:${cfmgr_health_logging:-missing}" = verified:verified:verified:verified:verified ] && [ "${cfmgr_health_native_openssl_ok:-0}" = 1 ] || return 1
	cfmgr_health_package_spec='' cfmgr_health_package_index="CFMGR-PACKAGE	1	$CFMGR_VERSION	verified:verified:verified:verified:verified
"
	while IFS='	' read -r cfmgr_health_package_mode cfmgr_health_package_bytes cfmgr_health_package_sha cfmgr_health_package_path; do
		cfmgr_health_package_index="$cfmgr_health_package_index""ORIGINAL	$cfmgr_health_package_mode	$cfmgr_health_package_bytes	$cfmgr_health_package_sha	$cfmgr_health_package_path
"
	done <<EOF_PACKAGE_ORIGINAL
$cfmgr_health_records
EOF_PACKAGE_ORIGINAL
	while IFS=' ' read -r cfmgr_health_package_role cfmgr_health_package_relative; do
		cfmgr_health_package_profile=public
		case $cfmgr_health_package_role in
		entry) cfmgr_health_package_path=/jffs/scripts/cfmgr.sh ;;
		d0 | d1 | d2 | d3) cfmgr_health_package_path=$cfmgr_source/$cfmgr_health_package_relative cfmgr_health_package_profile=directory ;;
		*) cfmgr_health_package_path=$cfmgr_source/$cfmgr_health_package_relative ;;
		esac
		cfmgr_health_package_spec="$cfmgr_health_package_spec$cfmgr_health_package_role	$cfmgr_health_package_path	$cfmgr_health_package_profile	metadata
"
	done <<'EOF_PACKAGE_FIXED'
entry cfmgr.sh
catalog catalog.txt
backup modules/backup.sh
manager modules/manager.sh
status modules/status.sh
helpers-empty modules/helpers/.gitkeep
worker modules/helpers/worker.sh
hooks-empty modules/hooks/.gitkeep
lib-empty modules/lib/.gitkeep
config modules/lib/config.sh
execution modules/lib/execution.sh
logging modules/lib/logging.sh
network modules/lib/network.sh
package modules/lib/package.sh
storage modules/lib/storage.sh
manifest manifest.txt
d0 modules
d1 modules/lib
d2 modules/helpers
d3 modules/hooks
EOF_PACKAGE_FIXED
	cfmgr_health_log_spec_write "$cfmgr_health_package_spec" || return $?
	cfmgr_health_package_spec_file=$cfmgr_health_log_spec_file
	cfmgr_health_log_metadata "$cfmgr_health_package_spec_file" normal || return $?
	cfmgr_health_package_before=$cfmgr_health_log_metadata_file
	# Never open an unprotected or nonregular input. Metadata also bounds copying.
	cfmgr_health_package_counts=''
	for cfmgr_health_package_role in manifest catalog; do
		cfmgr_health_log_member "$cfmgr_health_package_before" "$cfmgr_health_package_role" || return $?
		[ "$cfmgr_health_log_member_ok" = 1 ] && [ "$cfmgr_health_log_member_bytes" -gt 0 ] && [ "$cfmgr_health_log_member_bytes" -le 131072 ] || return 1
		cfmgr_health_selected_limit=$(((cfmgr_health_log_member_bytes + 4095) / 4096 * 8 + 8))
		cfmgr_health_run health-selected-copy /bin/dd "$cfmgr_source/$cfmgr_health_package_role.txt" "$cfmgr_health_log_member_bytes" || return $?
		[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_health_package_index="$cfmgr_health_package_index""SOURCE	$cfmgr_health_package_role	${cfmgr_probe_stdout##*/}
"
		cfmgr_health_package_counts="$cfmgr_health_package_counts$cfmgr_health_package_role	$cfmgr_probe_stdout
"
	done
	for cfmgr_health_package_role in d0 d1 d2 d3; do
		cfmgr_health_log_member "$cfmgr_health_package_before" "$cfmgr_health_package_role" || return $?
		[ "$cfmgr_health_log_member_ok" = 1 ] || return 1
		case $cfmgr_health_package_role in d0) cfmgr_health_package_dir=modules ;; d1) cfmgr_health_package_dir=modules/lib ;; d2) cfmgr_health_package_dir=modules/helpers ;; d3) cfmgr_health_package_dir=modules/hooks ;; esac
		cfmgr_health_flat_list "$cfmgr_source/$cfmgr_health_package_dir" || return $?
		[ "$cfmgr_health_flat_complete" = 1 ] || return 1
		cfmgr_health_package_index="$cfmgr_health_package_index""SOURCE	$cfmgr_health_package_role	${cfmgr_health_flat_file##*/}
"
		cfmgr_health_package_counts="$cfmgr_health_package_counts$cfmgr_health_package_role	$cfmgr_health_flat_file
"
	done
	cfmgr_health_log_spec_write "$cfmgr_health_package_counts" || return $?
	cfmgr_health_log_group counts "$cfmgr_health_log_spec_file" || return $?
	cfmgr_health_package_index="$cfmgr_health_package_index""COUNTS	${cfmgr_health_log_group_file##*/}
BEFORE	${cfmgr_health_package_before##*/}
"
	# Installed entry is independent of a trusted standalone entry copy.
	cfmgr_health_log_member "$cfmgr_health_package_before" entry || return $?
	[ "$cfmgr_health_log_member_ok" = 1 ] && [ "$cfmgr_health_log_member_bytes" -le 1048576 ] || return 1
	cfmgr_health_log_spec_write "entry	/jffs/scripts/cfmgr.sh
catalog	$cfmgr_source/catalog.txt
" || return $?
	cfmgr_health_log_group hashes "$cfmgr_health_log_spec_file" || return $?
	cfmgr_health_package_index="$cfmgr_health_package_index""HASHES	${cfmgr_health_log_group_file##*/}
"
	cfmgr_health_log_metadata "$cfmgr_health_package_spec_file" normal || return $?
	cfmgr_health_package_index="$cfmgr_health_package_index""AFTER	${cfmgr_health_log_metadata_file##*/}
END
"
	[ "${#cfmgr_health_package_index}" -le 8192 ] || return 1
	cfmgr_health_log_spec_write "$cfmgr_health_package_index" || return $?
	cfmgr_health_run health-package-check /usr/bin/awk "$cfmgr_source/modules/lib/package.sh" "$cfmgr_source/modules/status.sh" "$cfmgr_health_log_spec_file" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_health_package_tag cfmgr_health_package_version cfmgr_health_package_result cfmgr_health_package_end cfmgr_health_package_extra <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_package_tag:$cfmgr_health_package_version:$cfmgr_health_package_end:$cfmgr_health_package_extra" = CFMGR-PACKAGE:1:END: ] || return 1
	case $cfmgr_health_package_result in PASS | FAIL | UNKNOWN) cfmgr_health_package_state=$cfmgr_health_package_result ;; *) return 1 ;; esac
}
