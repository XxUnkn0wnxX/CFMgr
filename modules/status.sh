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
	cfmgr_health_reason='' cfmgr_health_incomplete=0
	cfmgr_health_deadline=$((cfmgr_probe_now + 45))
	# Five seconds plus eight operations/16 files/1MiB remain for final
	# rendering/cleanup. Counters are monotonic, including failed operations.
	cfmgr_health_collect_deadline=$((cfmgr_health_deadline - 5))
}

cfmgr_health_mode() {
	cfmgr_health_mode_files=2 cfmgr_health_mode_limit=8 cfmgr_health_mode_get=0
	case $1 in
	health-snapshot) cfmgr_health_mode_limit=128 ;;
	health-get) cfmgr_health_mode_limit=64 cfmgr_health_mode_files=4 cfmgr_health_mode_get=1 ;;
	health-render) cfmgr_health_mode_limit=384 ;;
	health-render-count) cfmgr_health_mode_limit=8 ;;
	health-inventory | health-protected | health-current | health-storage | health-uuid | health-uname | health-blkid | \
		health-jq-good | health-jq-bad | health-sha-bytes | health-sha-good | health-sha-bad | health-wc-jq | health-wc-sha | \
		health-timeout-exit | health-timeout-expiry | health-flock-first | health-flock-compete | health-flock-after | health-flock-release | health-flock-finish | \
		health-flock-entware-first | health-flock-entware-compete | health-flock-entware-after | health-flock-entware-release | health-flock-entware-finish | health-dig-version | \
		health-scope | health-request | health-request-check | health-response | health-trace | health-frame | \
		health-config | health-native | health-fields | health-mount | health-metadata | health-count | health-count-pair | \
		health-date | health-nvram | health-space | health-realpath | health-curl-version | \
		health-curl-features | health-ca-pem | health-ca-decode | health-curl-offline) ;;
	*) return 2 ;;
	esac
	# Native ash units are 512 bytes; supported host bash units can be 1024.
	# Reserve the larger physical payload for EACH writable file, including err.
	cfmgr_health_mode_bytes=$((cfmgr_health_mode_files * cfmgr_health_mode_limit * 1024))
}

cfmgr_health_reserve() {
	[ "${cfmgr_health_active:-0}" = 1 ] || return 2
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_health_mode "$1" || return 2
	case $1 in health-render | health-render-count)
		cfmgr_health_final_reserve "$1"
		return $?
		;;
	esac
	[ -z "${cfmgr_health_final_deadline:-}" ] || return 1
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	if [ "$cfmgr_probe_now" -ge "$cfmgr_health_collect_deadline" ] ||
		[ "$cfmgr_health_operations" -ge 248 ] ||
		[ "$((cfmgr_health_requests + cfmgr_health_mode_get))" -gt 12 ] ||
		[ "$((cfmgr_health_files + cfmgr_health_mode_files))" -gt 560 ] ||
		[ "$((cfmgr_health_bytes + cfmgr_health_mode_bytes))" -gt 11534336 ]; then
		cfmgr_health_incomplete=1 cfmgr_health_reason=budget
		return 1
	fi
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
	[ "$cfmgr_health_operations" -le 248 ] && [ "$cfmgr_health_files" -le 560 ] &&
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
	case $1:$2 in dashboard:32768 | rows:262144 | json.good:8192 | json.bad:8192 | bytes:8192 | checksum.good:8192 | checksum.bad:8192 | lock:8192 | timeout.child:8192) ;; *) return 2 ;; esac
	cfmgr_status_attachment_ok && cfmgr_prerequisites_now || return 1
	if [ "$cfmgr_probe_now" -ge "$cfmgr_health_collect_deadline" ] ||
		[ "$cfmgr_health_files" -ge 560 ] || [ "$((cfmgr_health_bytes + $2))" -gt 11534336 ]; then
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
	/bin/cat "$cfmgr_health_render_output"
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
		[ "$cfmgr_health_seen" -le 576 ] || return 1
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
	cfmgr_health_run health-count-pair /usr/bin/wc "$cfmgr_health_body" "$cfmgr_health_headers" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	{
		IFS=' ' read -r cfmgr_health_body_bytes cfmgr_health_body_path &&
			IFS=' ' read -r cfmgr_health_header_bytes cfmgr_health_header_path &&
			IFS=' ' read -r cfmgr_health_total_bytes cfmgr_health_total_label || return 1
		cfmgr_health_extra=''
		if IFS= read -r cfmgr_health_extra || [ -n "$cfmgr_health_extra" ]; then return 1; fi
	} <"$cfmgr_probe_stdout"
	for cfmgr_health_number in "$cfmgr_health_body_bytes" "$cfmgr_health_header_bytes" "$cfmgr_health_total_bytes"; do
		case $cfmgr_health_number in '' | *[!0-9]* | 0?*) return 1 ;; esac
		[ "${#cfmgr_health_number}" -le 6 ] || return 1
	done
	[ "$cfmgr_health_body_path" = "$cfmgr_health_body" ] && [ "$cfmgr_health_header_path" = "$cfmgr_health_headers" ] &&
		[ "$cfmgr_health_total_label" = total ] && [ "$cfmgr_health_body_bytes" -le 32768 ] &&
		[ "$cfmgr_health_header_bytes" -le 8192 ] &&
		[ "$cfmgr_health_total_bytes" -eq "$((cfmgr_health_body_bytes + cfmgr_health_header_bytes))" ]
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
	cfmgr_health_frame "$cfmgr_health_http_file" http || return $?
	IFS= read -r cfmgr_health_http_code <"$cfmgr_health_http_file" || return 1
	cfmgr_health_http "$cfmgr_health_http_code" || :
	cfmgr_health_transport_exit "$cfmgr_health_curl_exit" || return 1
	# HTTP rejection/throttle is retained even if curl also reports a body limit.
	[ "$cfmgr_health_http_code" = 200 ] && [ "$cfmgr_health_curl_exit" = 0 ] && [ ! -s "$cfmgr_health_curl_error" ] || {
		exec 6<&-
		return 1
	}
	cfmgr_health_sizes || return $?
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
	cfmgr_health_run health-realpath /usr/bin/readlink "$1" || return $?
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
	cfmgr_health_canonical "$1" || return $?
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
	cfmgr_health_run health-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_health_opt" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS= read -r cfmgr_health_mount_current <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_mount_current" = "$cfmgr_health_mount_snapshot" ]
}

cfmgr_health_admit_entware() {
	case $1 in /opt/bin/jq | /opt/bin/timeout | /opt/bin/sha256sum | /opt/bin/flock | /opt/bin/dig) ;; *) return 2 ;; esac
	[ "${cfmgr_health_entware_ready:-0}" = 1 ] || return 1
	cfmgr_health_entware_attachment || return $?
	cfmgr_health_canonical "$1" || return $?
	case $cfmgr_health_resolved in "$cfmgr_health_opt"/*) ;; *) return 1 ;; esac
	[ -f "$cfmgr_health_resolved" ] && [ -x "$cfmgr_health_resolved" ] || return 1
	cfmgr_health_protected "$cfmgr_health_resolved" "$cfmgr_health_opt_mount" file
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
	cfmgr_health_canonical "$cfmgr_health_opt_mount" || return $?
	[ "$cfmgr_health_resolved" = "$cfmgr_health_opt_mount" ] || return 1
	cfmgr_health_protected "$cfmgr_health_opt" "$cfmgr_health_opt_mount" directory || return $?
	exec 6<"$cfmgr_health_opt_mount" 7<"$cfmgr_health_opt" || return 1
	cfmgr_health_run health-blkid /sbin/blkid "$cfmgr_health_opt_device" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_health_run health-uuid /usr/bin/awk "$cfmgr_source/modules/status.sh" "$cfmgr_probe_stdout" "$cfmgr_health_opt_device" "$cfmgr_health_opt_fs" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS= read -r cfmgr_health_current_uuid <"$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_health_current_uuid" = "$cfmgr_health_opt_uuid" ] || return 1
	cfmgr_health_entware_attachment || return $?
	cfmgr_health_entware_ready=1
}

cfmgr_health_observe() {
	# Public IDs contain only feature/kind/ordinal, never configured identities.
	cfmgr_health_observation_id=$1
	shift
	if cfmgr_health_get "$@"; then
		IFS=' ' read -r cfmgr_health_marker cfmgr_health_version cfmgr_health_observed cfmgr_health_matches cfmgr_health_evidence cfmgr_health_end <"$cfmgr_health_result_file" || return 1
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
	cfmgr_health_row "$cfmgr_health_observation_id" "$cfmgr_health_observation_state" "$cfmgr_health_observation_detail" current 'Review configured resource and read permissions.' transport
}

cfmgr_health_provider_collect() {
	cfmgr_health_public_feature='' cfmgr_health_dns_index=0 cfmgr_health_candidates=''
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
			cfmgr_health_row "ip_sync.$cfmgr_health_a.$cfmgr_health_b" UNKNOWN 'The configured family membership comparison is not yet projected from the retained private item response.' current 'Inspect the configured family target; a resource read alone does not prove membership.' ip_sync || return $?
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
		cfmgr_health_row network.public6 SKIP 'No locally validated configured API scope remains eligible and unheld for public discovery.' current 'Review configured scopes and retained authentication evidence.' config
		return $?
	fi
	cfmgr_health_public_eligible=1
	cfmgr_health_observe network.public4 "$cfmgr_health_public_feature" trace - 4 || return $?
	if [ "$cfmgr_health_ipv6_ready" = 1 ]; then
		cfmgr_health_observe network.public6 "$cfmgr_health_public_feature" trace - 6 || return $?
	else
		cfmgr_health_row network.public6 SKIP 'No current usable global IPv6 address was proved on the selected WAN interface.' current 'Check selected WAN IPv6 configuration.' network
	fi
}

cfmgr_health_collect() {
	cfmgr_health_row package.extension PASS 'Diagnostic dependency closure matches the trusted entry generation.' current 'None.' package || return $?
	cfmgr_health_row system.context PASS 'The report uses an attached private RAM context and the admitted native supervisor.' current 'None.' system || return $?
	if [ "${cfmgr_status_setup_ready:-0}" = 1 ]; then
		cfmgr_health_row system.setup PASS 'Retained setup completion framing was verified from the local snapshot.' current 'None.' system
	else
		cfmgr_health_row system.setup FAIL 'Retained setup completion was not verified.' current 'Use explicit package recovery.' system
	fi || return $?
	if [ "${cfmgr_status_storage_observation:-0}:${cfmgr_status_save_pending:-0}" = 0:0 ]; then
		cfmgr_health_row recovery.guards PASS 'No retained storage-observation or configuration-save guard was observed.' current 'None.' recovery
	else
		cfmgr_health_row recovery.guards WARN 'A retained observation or configuration-save guard requires explicit recovery.' current 'Use explicit recovery before operational changes.' recovery
	fi || return $?
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
	cfmgr_health_row package.complete UNKNOWN 'The diagnostic closure and fixed components do not prove complete catalog grammar or package inventory.' current 'Complete package verification remains required.' package || return $?
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
	for cfmgr_health_native_member in curl openssl ca; do
		case $cfmgr_health_native_member in curl) cfmgr_health_native_path=$cfmgr_health_curl cfmgr_health_native_kind=executable ;; openssl) cfmgr_health_native_path=$cfmgr_health_openssl cfmgr_health_native_kind=executable ;; ca) cfmgr_health_native_path=$cfmgr_health_ca cfmgr_health_native_kind=data ;; esac
		if cfmgr_health_admit_native "$cfmgr_health_native_path" "$cfmgr_health_native_kind"; then
			cfmgr_health_row "native.$cfmgr_health_native_member" PASS 'Fixed native path and ancestry are root-protected.' current 'None.' native
		else
			[ "$?" != 3 ] || return 3
			cfmgr_health_native_admitted=0
			cfmgr_health_row "native.$cfmgr_health_native_member" FAIL 'Fixed native path or protected ancestry could not be admitted.' current 'Recover native firmware prerequisites.' native
		fi || return $?
	done
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
		if cfmgr_health_admit_native /usr/bin/flock executable; then cfmgr_health_native_flock=/usr/bin/flock; else [ "$?" != 3 ] || return 3; fi
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
	for cfmgr_health_pending in cloudflared.local logging hooks recovery backup; do
		cfmgr_health_row "$cfmgr_health_pending.integration" UNKNOWN 'This required diagnostic group is not connected to the full collector yet.' current 'Pending the subsequent integration package.' report || return $?
	done
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
	cfmgr_health_begin || exit $?
	if cfmgr_health_session; then cfmgr_health_code=0; else cfmgr_health_code=$?; fi
	[ "$cfmgr_health_code" != 3 ] || exit 3
	exec 3>&- 4>&- 5>&- 6<&- 7<&-
	cfmgr_status_interrupted=0
	cfmgr_health_cleanup || exit $?
	exit "$cfmgr_health_code"
)

cfmgr_status_attachment_ok() {
	[ "${cfmgr_status_interrupted:-0}" = 0 ] && [ ! -L "$cfmgr_status_context" ] &&
		[ "$cfmgr_status_context" -ef /proc/self/fd/9 ]
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
	ulimit -c 0 || exit 1
	cfmgr_health_active=0 cfmgr_status_page=basic
	for cfmgr_status_path in "$cfmgr_source/modules/helpers/worker.sh" "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_source/modules/lib/storage.sh"; do
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
	cfmgr_status_dashboard=$cfmgr_status_context/dashboard
	(
		umask 077
		set -C
		: >"$cfmgr_status_dashboard"
	) || {
		printf '[CFMGR] status: warning: local dashboard staging unavailable\n'
		exit 1
	}
	cfmgr_status_saved_limit=$(ulimit -S -f) || exit 1
	cfmgr_status_limit_hit=0
	trap 'cfmgr_status_limit_hit=1' XFSZ
	ulimit -S -f 32 || exit 1
	if cfmgr_status_work >"$cfmgr_status_dashboard"; then cfmgr_status_code=0; else cfmgr_status_code=$?; fi
	ulimit -S -f "$cfmgr_status_saved_limit" || exit 1
	if [ "$cfmgr_status_code" = 3 ]; then
		printf '[CFMGR] status: error: owned probe unresolved; report cleanup required\n'
		exit 3
	fi
	cfmgr_status_render_ready=0
	if cfmgr_status_final_begin && [ "$cfmgr_status_limit_hit" = 0 ] && cfmgr_status_count_dashboard "$cfmgr_status_dashboard"; then
		cfmgr_status_render_ready=1
	else
		cfmgr_status_code=$?
		[ "$cfmgr_status_code" != 3 ] || exit 3
		cfmgr_status_code=1
	fi
	if [ "$cfmgr_status_render_ready" = 1 ]; then
		if cfmgr_status_render "$cfmgr_status_dashboard" -; then :; else
			cfmgr_status_code=$?
			[ "$cfmgr_status_code" != 3 ] || exit 3
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
		exit 1
	}
	exit "$cfmgr_status_code"
)

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
	cfmgr_status_run status-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_status_mount_target" || return $?
	cfmgr_status_fields mount "$cfmgr_probe_stdout" "$1"
}

cfmgr_status_space() {
	cfmgr_status_run status-space /bin/df "$1" || return $?
	cfmgr_status_fields space "$cfmgr_probe_stdout" -
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
    if(hw_mode=="health-response") { }
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
            if(hw_kind=="items" && !hw_list_ip(hr_text(hr_field(hr_item,"ip"),64))) reject()
            hr_count++
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
    printf "CFMGR-HEALTH-RESPONSE 1 %s %d api-read END\n",hr_state,hr_count
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
