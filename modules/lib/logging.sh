#!/bin/sh
# Category owner: logging. Source-inert diagnostics and sanitized records.
# shellcheck disable=SC2034,SC2154 # Explicit controller inputs and output fields.
# Callers must bound and privately stage inputs before invoking these parsers.

# shellcheck disable=SC2016 # Literal AWK programs keep their own field syntax.
cfmgr_logging_awk_log_frame() {
	# CFMGR-AWK-BEGIN log_frame
	cfmgr_awk_program='
# Input is one independently bounded snapshot, at most 24576 bytes.
# The caller supplies its independently observed exact byte count and whether
# the first line is an excerpt fragment. No source text is emitted in errors.
BEGIN {
	if (ENVIRON["LC_ALL"] != "C" || expected_bytes !~ /^[0-9]+$/ ||
		expected_bytes > 24576 || excerpt !~ /^[01]$/ || ARGC != 1) { bad = 1; exit 1 }
	# BusyBox splits records at NUL even with a different RS. Admit one exact
	# bounded record, then split its actual LF bytes ourselves, like json.
	RS = sprintf("%c", 28)
	if (excerpt == "1") skip_first = 1
}
{
	if (NR != 1 || length($0) != expected_bytes || substr($0, length($0), 1) != "\n") { bad = 1; exit 1 }
	lines = split($0, source_lines, "\n")
	for (line = 1; line < lines; line++) frame_line(source_lines[line])
}
function frame_line(row, i, character, quoted) {
	if (length(row) > 4096 || row ~ /[^ -~]/) { bad = 1; exit 1 }
	if (skip_first) { skip_first = 0; return }
	if (row == "") { bad = 1; exit 1 }
	if (count) framed = framed ",\n"
	if (substr(row, 1, 1) == "{" && substr(row, length(row), 1) == "}") {
		framed = framed row
	} else {
		quoted = "\""
		for (i = 1; i <= length(row); i++) {
			character = substr(row, i, 1)
			if (character == "\\" || character == "\"") quoted = quoted "\\"
			quoted = quoted character
		}
		framed = framed quoted "\""
	}
	count++
}
END {
	if (bad || (expected_bytes > 0 && NR != 1) || count > 4096) exit 1
	print "["
	if (count) printf "%s\n", framed
	print "]"
}
'
	# CFMGR-AWK-END log_frame
}

cfmgr_logging_awk_log_sanitize() {
	# CFMGR-AWK-BEGIN log_sanitize
	cfmgr_awk_program='
# Runs after the shared bounded JSON parser in tree mode. Input is an array of
# complete JSON objects (Cloudflared zerolog) and/or strings (console records).
# Only reconstructed allowlisted events reach stdout. Unknown records become a
# fixed marker and make the copy incomplete. Arbitrary fields are never printed.
BEGIN {
	if (!cfmgr_json_tree_ready || cfmgr_json_tree_kind[1] != "array" ||
		cfmgr_log_excerpt !~ /^[01]$/ ||
		(cfmgr_log_source != "cloudflared" && cfmgr_log_source != "ddns" && cfmgr_log_source != "ip_sync")) exit 1
	lf_build_children()
	if (cfmgr_log_excerpt == "1") incomplete = 1
	print "CFMGR-SANITIZED-LOG 1"
	for (i = 2; i <= cfmgr_json_tree_count; i++) {
		if (cfmgr_json_tree_parent[i] != 1) continue
		if (cfmgr_json_tree_kind[i] == "object" && cfmgr_log_source == "cloudflared") {
			level_id = lf_child(i, "level")
			time_id = lf_child(i, "time")
			message_id = lf_child(i, "message")
			index_id = lf_child(i, "connIndex")
			protocol_id = lf_child(i, "protocol")
			if (cfmgr_json_tree_kind[level_id] != "string" ||
				cfmgr_json_tree_kind[time_id] != "string" ||
				cfmgr_json_tree_kind[message_id] != "string") {
				lf_unknown(); continue
			}
			level = lf_unhex(cfmgr_json_tree_payload[level_id])
			timestamp = lf_unhex(cfmgr_json_tree_payload[time_id])
			message = lf_unhex(cfmgr_json_tree_payload[message_id])
			conn_index = "-"; protocol = "-"
			if (index_id) {
				if (cfmgr_json_tree_kind[index_id] != "number") { lf_unknown(); continue }
				conn_index = substr(cfmgr_json_tree_payload[index_id], 2)
				if (conn_index !~ /^[0-3]$/) { lf_unknown(); continue }
			}
			if (protocol_id) {
				if (cfmgr_json_tree_kind[protocol_id] != "string") { lf_unknown(); continue }
				protocol = lf_unhex(cfmgr_json_tree_payload[protocol_id])
				if (protocol !~ /^(quic|http2|http3)$/) { lf_unknown(); continue }
			}
			lf_emit(message, level, timestamp, conn_index, protocol)
		} else if (cfmgr_json_tree_kind[i] == "string") {
			if (cfmgr_log_source == "cloudflared") lf_console(lf_unhex(cfmgr_json_tree_payload[i]))
			else lf_native(lf_unhex(cfmgr_json_tree_payload[i]), cfmgr_log_source)
		} else {
			lf_unknown()
		}
	}
	printf "END %d %d %d\n", known, redacted, incomplete
}
function lf_child(parent, key) {
	if (key == "level") return lf_find[parent, "k6c6576656c"]
	if (key == "time") return lf_find[parent, "k74696d65"]
	if (key == "message") return lf_find[parent, "k6d657373616765"]
	if (key == "connIndex") return lf_find[parent, "k636f6e6e496e646578"]
	if (key == "protocol") return lf_find[parent, "k70726f746f636f6c"]
}
function lf_build_children(    n) {
	for (n = 2; n <= cfmgr_json_tree_count; n++)
		lf_find[cfmgr_json_tree_parent[n], cfmgr_json_tree_location[n]] = n
}
function lf_unhex(value,    i, a, b, digits, out) {
	if (substr(value, 1, 1) != "x" || length(value) % 2 != 1) return ""
	digits = "0123456789abcdef"
	for (i = 2; i < length(value); i += 2) {
		a = index(digits, tolower(substr(value, i, 1))) - 1
		b = index(digits, tolower(substr(value, i + 1, 1))) - 1
		if (a < 0 || b < 0) return ""
		out = out sprintf("%c", a * 16 + b)
	}
	return out
}
function lf_timestamp(value,    year, month, day, hour, minute, second, month_days) {
	if (length(value) < 20 || length(value) > 30 ||
		value !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]([.][0-9]{1,9})?Z$/) return 0
	year = substr(value, 1, 4) + 0; month = substr(value, 6, 2) + 0; day = substr(value, 9, 2) + 0
	hour = substr(value, 12, 2) + 0; minute = substr(value, 15, 2) + 0; second = substr(value, 18, 2) + 0
	if (month < 1 || month > 12 || hour > 23 || minute > 59 || second > 59) return 0
	month_days = (month == 2 ? 28 : (month == 4 || month == 6 || month == 9 || month == 11 ? 30 : 31))
	if (month == 2 && (year % 400 == 0 || (year % 4 == 0 && year % 100 != 0))) month_days = 29
	return year >= 1 && day >= 1 && day <= month_days
}
function lf_level(value) {
	if (value == "info" || value == "INF") return "info"
	if (value == "warn" || value == "warning" || value == "WRN") return "warning"
	if (value == "error" || value == "ERR") return "error"
	if (value == "debug" || value == "DBG") return "debug"
	return ""
}
function lf_emit(message, level, timestamp, conn_index, protocol,    clean, words, n, delay, unit) {
	clean = lf_level(level)
	if (clean == "" || !lf_timestamp(timestamp)) { lf_unknown(); return }
	if (message == "Registered tunnel connection") {
		printf "Cloudflared: %s: Registered tunnel connection index=%s protocol=%s at=%s\n", clean, conn_index, protocol, timestamp
		known++; return
	}
	if (message == "Starting tunnel" || message == "Lost connection with the edge" || message == "Connection terminated") {
		printf "Cloudflared: %s: %s at=%s\n", clean, message, timestamp
		known++; return
	}
	n = split(message, words, " ")
	if (n == 6 && words[1] == "Retrying" && words[2] == "connection" && words[3] == "in" && words[4] == "up" && words[5] == "to") {
		delay = words[6]; unit = substr(delay, length(delay) - 1)
		if (unit == "ms") delay = substr(delay, 1, length(delay) - 2)
		else { unit = substr(delay, length(delay)); delay = substr(delay, 1, length(delay) - 1) }
		if (delay ~ /^[0-9][0-9]?[0-9]?$/ && (unit == "ms" || unit == "s" || unit == "m")) {
			printf "Cloudflared: %s: Retrying connection in %s%s at=%s\n", clean, delay, unit, timestamp
			known++; return
		}
	}
	if (n == 2 && words[1] == "Version" &&
		words[2] ~ /^(0|[1-9][0-9]{0,4})([.](0|[1-9][0-9]{0,4})){1,3}$/) {
		printf "Cloudflared: %s: Version %s at=%s\n", clean, words[2], timestamp
		known++; return
	}
	lf_unknown()
}
function lf_console(value,    words, n, timestamp, level, message, conn_index, protocol, base) {
	if (value ~ /[^ -~]/) { lf_unknown(); return }
	n = split(value, words, " ")
	if (n < 3 || n > 16) { lf_unknown(); return }
	timestamp = words[1]; level = words[2]
	message = ""
	if (words[3] == "Registered" && words[4] == "tunnel" && words[5] == "connection") message = "Registered tunnel connection"
	else if (words[3] == "Starting" && words[4] == "tunnel") message = "Starting tunnel"
	else if (words[3] == "Lost" && words[4] == "connection" && words[5] == "with" && words[6] == "the" && words[7] == "edge") message = "Lost connection with the edge"
	else if (words[3] == "Connection" && words[4] == "terminated") message = "Connection terminated"
	else if (words[3] == "Retrying" && words[4] == "connection" && words[5] == "in" && words[6] == "up" && words[7] == "to") message = "Retrying connection in up to " words[8]
	else if (words[3] == "Version") message = "Version " words[4]
	else { lf_unknown(); return }
	conn_index = "-"; protocol = "-"
	if (message == "Registered tunnel connection") {
		if (n != 11 || words[6] !~ /^connIndex=[0-3]$/ || words[7] !~ /^connection=[A-Fa-f0-9-]+$/ ||
			words[8] !~ /^event=[0-9]+$/ || words[9] !~ /^ip=[0-9.]+$/ ||
			words[10] !~ /^location=[A-Za-z0-9]+$/ || words[11] !~ /^protocol=(quic|http2|http3)$/) { lf_unknown(); return }
		conn_index = substr(words[6], 11); protocol = substr(words[11], 10)
		lf_emit(message, level, timestamp, conn_index, protocol); return
	}
	if (message == "Lost connection with the edge" || message == "Connection terminated") {
		# The sole optional field is the bounded connection ordinal. Error text
		# and all other fields are unsupported and never copied.
		base = (message == "Lost connection with the edge" ? 7 : 4)
		if (n > base + 1 || (n == base + 1 && words[n] !~ /^connIndex=[0-3]$/)) { lf_unknown(); return }
		lf_emit(message, level, timestamp, "-", "-"); return
	}
	if (message == "Retrying connection in up to " words[8] && n == 8) { lf_emit(message, level, timestamp, "-", "-"); return }
	if (message == "Version " words[4] && n == 4) { lf_emit(message, level, timestamp, "-", "-"); return }
	if (message == "Starting tunnel" && n == 4) { lf_emit(message, level, timestamp, "-", "-"); return }
	lf_unknown()
}
function lf_unknown(    component) {
	component = "Cloudflared"
	if (cfmgr_log_source == "ddns") component = "DDNS"
	if (cfmgr_log_source == "ip_sync") component = "IP-Sync"
	printf "%s: warning: source record redacted; capture incomplete\n", component
	redacted++; incomplete = 1
}
function lf_ipv4(value,    parts, count, i, octet) {
	count = split(value, parts, ".")
	if (count != 4) return 0
	for (i = 1; i <= 4; i++) {
		if (parts[i] !~ /^[0-9][0-9]?[0-9]?$/) return 0
		octet = parts[i] + 0
		if (octet > 255) return 0
	}
	return 1
}
function lf_native(value, source,    ip, delay) {
	if (source == "ddns" && value ~ /^\[CFMGR\] DDNS: Info: IPv4 updated: /) {
		ip = substr(value, length("[CFMGR] DDNS: Info: IPv4 updated: ") + 1)
		if (lf_ipv4(ip)) {
			printf "[CFMGR] DDNS: Info: IPv4 updated: %s\n", ip
			known++; return
		}
	}
	if (source == "ip_sync" && value ~ /^\[CFMGR\] IP-Sync: Warning: Rate limited; retry in [0-9][0-9]?[0-9]?[sm]$/) {
		delay = substr(value, length("[CFMGR] IP-Sync: Warning: Rate limited; retry in ") + 1)
		printf "[CFMGR] IP-Sync: Warning: Rate limited; retry in %s\n", delay
		known++; return
	}
	lf_unknown()
}
END {
	# The shared parser BEGIN runs first; the object index is ready before
	# this consumer BEGIN examines the tree. Kept in END only for awk portability.
}
'
	# CFMGR-AWK-END log_sanitize
}

cfmgr_logging_mask_credential() {
	(
		# The caller must disable tracing before passing the secret as an argument.
		# This subshell keeps helper tracing/verbosity changes out of the caller.
		set +xv
		[ "$#" -eq 2 ] || return 2
		case $1 in
		cloudflare_dns_update) cfmgr_logging_role='Cloudflare API token (DNS update)' ;;
		management_api) cfmgr_logging_role='Cloudflare management API key' ;;
		runtime_tunnel) cfmgr_logging_role='Cloudflared runtime tunnel token' ;;
		certificate) cfmgr_logging_role='Cloudflare certificate' ;;
		*) return 2 ;;
		esac
		case $2 in *[!A-Za-z0-9_-]*) cfmgr_logging_mask='****' ;;
		*)
			if [ "${#2}" -ge 8 ] && [ "${#2}" -le 512 ]; then
				cfmgr_logging_tail=${2#"${2%???}"}
				cfmgr_logging_mask="****$cfmgr_logging_tail"
			else cfmgr_logging_mask='****'; fi
			;;
		esac
		[ "$1" != certificate ] || cfmgr_logging_mask='****'
		printf '%s: %s\n' "$cfmgr_logging_role" "$cfmgr_logging_mask"
	)
}

# Operation-local typed trace queue. Recording never performs capture I/O or
# changes the process supervisor's result, child identities or output paths.
cfmgr_log_event() {
	case ${cfmgr_log_recording:-0}:$# in 1:4) ;; *) return 0 ;; esac
	case $1 in entry | manager | status | backup | execution | config | package | diagnostic) ;; *) return 0 ;; esac
	case $2 in
	start | finish | menu | normal | reinstall | read | save | recover | status | health | destination | list | check | create | browse | inspect | review | preferences | verify | delete | retention | off | stop | deferred | \
		status-* | health-* | store-* | archive-* | history-* | install-* | launch-* | native-* | repair-* | acquire-* | dependency-* | jq-* | sha-* | wc-* | timeout-* | flock-* | dig-version | blkid) ;;
	*) return 0 ;;
	esac
	case $2 in '' | *[!a-z0-9-]*) return 0 ;; esac
	case $3 in started | success | incomplete | failure | skipped | off | deferred | interrupted | unresolved) ;; *) return 0 ;; esac
	case $4 in '' | *[!0-9]* | ????* | 0?*) return 0 ;; esac
	[ "$4" -le 255 ] && [ "${#2}" -le 64 ] || return 0
	if [ "${cfmgr_log_event_count:-0}" -ge 1024 ] || [ "${#cfmgr_log_buffer}" -ge 130800 ]; then
		[ "${cfmgr_log_omitted:-0}" -ge 999999 ] || cfmgr_log_omitted=$((${cfmgr_log_omitted:-0} + 1))
		return 0
	fi
	cfmgr_log_uptime=unknown
	if { IFS=' ' read -r cfmgr_log_uptime cfmgr_log_idle </proc/uptime; } 2>/dev/null; then
		cfmgr_log_uptime=${cfmgr_log_uptime%%.*}
		case $cfmgr_log_uptime in '' | *[!0-9]*) cfmgr_log_uptime=unknown ;; esac
	else cfmgr_log_uptime=unknown; fi
	[ "${#cfmgr_log_uptime}" -le 16 ] || cfmgr_log_uptime=unknown
	cfmgr_log_buffer="${cfmgr_log_buffer}CFMGR-EVENT 1 $cfmgr_log_uptime $1 $2 $3 $4
"
	cfmgr_log_event_count=$((${cfmgr_log_event_count:-0} + 1))
	return 0
}

cfmgr_log_collect() {
	case ${cfmgr_log_available:-0}:$# in 1:2) ;; *) return 0 ;; esac
	cfmgr_log_recording=1 cfmgr_log_buffer='' cfmgr_log_event_count=0 cfmgr_log_omitted=0 cfmgr_log_warned=0
	cfmgr_log_component=$1 cfmgr_log_operation=$2
	cfmgr_log_event "$1" "$2" started 0
}

cfmgr_log_begin() {
	cfmgr_log_collect "$@"
	cfmgr_log_flush started
}

cfmgr_log_result() {
	# Only the controller's strict public receipt is consumed; never replay an
	# error stream or malformed response from a capture child.
	cfmgr_log_result_kind=unavailable cfmgr_log_result_config=unavailable
	IFS=' ' read -r cfmgr_log_tag cfmgr_log_version cfmgr_log_result_kind cfmgr_log_result_config \
		cfmgr_log_result_path cfmgr_log_end cfmgr_log_extra <<EOF_LOG_RECEIPT
$1
EOF_LOG_RECEIPT
	[ "$1" = "CFMGR-LOG-CAPTURE 1 $cfmgr_log_result_kind $cfmgr_log_result_config $cfmgr_log_result_path END" ] || return 1
	case $cfmgr_log_result_kind in saved | incomplete | unavailable | disabled | unresolved) ;; *) return 1 ;; esac
	case $cfmgr_log_result_config in read | unavailable) ;; *) return 1 ;; esac
	case $cfmgr_log_result_path in -) ;; '' | *[!0-9a-f]*) return 1 ;; *)
		[ "${#cfmgr_log_result_path}" -le 2048 ] && [ "$((${#cfmgr_log_result_path} % 2))" = 0 ] || return 1
		;;
	esac
}

cfmgr_log_flush() {
	case ${cfmgr_log_available:-0}:${cfmgr_log_recording:-0} in 1:1) ;; *) return 0 ;; esac
	# A positive unresolved child takes precedence over all diagnostic I/O.
	if [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; then return 0; fi
	[ -n "$cfmgr_log_buffer" ] || return 0
	if [ "${cfmgr_log_omitted:-0}" -gt 0 ]; then
		cfmgr_log_buffer="${cfmgr_log_buffer}CFMGR-OMITTED 1 $cfmgr_log_omitted
"
	fi
	if cfmgr_log_response=$(cfmgr_log_capture developer "$cfmgr_log_buffer" 2>/dev/null); then cfmgr_log_capture_code=0; else cfmgr_log_capture_code=$?; fi
	if ! cfmgr_log_result "$cfmgr_log_response"; then cfmgr_log_result_kind=unavailable; fi
	if [ "$cfmgr_log_capture_code" != 0 ] && [ "$cfmgr_log_result_kind" = saved ]; then cfmgr_log_result_kind=unavailable; fi
	case $cfmgr_log_result_kind in
	saved) ;;
	disabled) cfmgr_log_recording=0 ;;
	*)
		if [ "${cfmgr_log_warned:-0}" = 0 ]; then
			printf '[CFMGR] diagnostics: warning: developer capture unavailable or incomplete; operation result is unchanged\n' >&2
			cfmgr_log_warned=1
		fi
		;;
	esac
	# Never retry an uncertain append. Retention belongs to the user.
	cfmgr_log_buffer='' cfmgr_log_event_count=0 cfmgr_log_omitted=0
	return 0
}

cfmgr_log_finish() {
	case ${cfmgr_log_available:-0}:${cfmgr_log_recording:-0}:$# in 1:1:2) ;; *) return 0 ;; esac
	cfmgr_log_event "$cfmgr_log_component" "$cfmgr_log_operation" "$1" "$2"
	[ "$2" != 3 ] || return 0
	cfmgr_log_flush finished
}

cfmgr_log_path_valid() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 1024 ] || return 1
	case $1 in
	/*) ;;
	*) return 1 ;;
	esac
	case $1 in
	/ | *[!\ -~]* | *//* | */./* | */../* | */. | */.. | */) return 1 ;;
	esac
}

# A returned mount is an observation, not write authority. Caller must pin the
# mount, compare fdinfo IDs, check paths, and re-observe before each mutation.
# The parser emits nine tab-separated fields, so literal spaces are retained.
cfmgr_log_data_mount_record() {
	[ "$#" -eq 1 ] || return 2
	IFS='	' read -r cfmgr_log_mount_id cfmgr_log_mount_parent cfmgr_log_mount_device \
		cfmgr_log_mount_root cfmgr_log_mount_path cfmgr_log_mount_fs cfmgr_log_mount_source \
		cfmgr_log_mount_options cfmgr_log_mount_super cfmgr_log_mount_extra <<EOF_LOG_MOUNT
$1
EOF_LOG_MOUNT
	[ -z "$cfmgr_log_mount_extra" ] || return 1
	case $cfmgr_log_mount_id:$cfmgr_log_mount_parent in
	*[!0-9:]* | :* | *: | 0:* | *:0) return 1 ;;
	esac
	case $cfmgr_log_mount_device in *[!0-9:]* | :* | *: | *:*:*) return 1 ;; *:*) ;; *) return 1 ;; esac
	[ "$cfmgr_log_mount_root" = / ] || return 1
	case $cfmgr_log_mount_path in /tmp/mnt/?* | /mnt/?*) ;; *) return 1 ;; esac
	cfmgr_log_path_valid "$cfmgr_log_mount_path" || return 1
	[ -d "$cfmgr_log_mount_path" ] && [ ! -L "$cfmgr_log_mount_path" ] || return 1
	[ -b "$cfmgr_log_mount_source" ] || return 1
	case ,$cfmgr_log_mount_options, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_log_mount_options, in *,ro,*) return 1 ;; esac
	case ,$cfmgr_log_mount_super, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_log_mount_super, in *,ro,*) return 1 ;; esac
	[ -n "$cfmgr_log_mount_fs" ] || return 1
	# noexec is valid for data; no executable is selected from this mount.
}

# Only a verified /mnt namespace alias may change the lexical custom path.
# A symlink at any deeper component remains an unsafe selected destination.
cfmgr_log_alias_matches() {
	[ "$#" -eq 3 ] || return 2
	if [ "$1" = "$2" ]; then return 0; fi
	case $1 in /mnt/*) ;; *) return 1 ;; esac
	case $3 in /mnt | /tmp/mnt) ;; *) return 1 ;; esac
	[ "$2" = "$3${1#/mnt}" ]
}

cfmgr_log_path_on_mount() {
	[ "$#" -eq 2 ] || return 2
	cfmgr_log_path_valid "$1" && cfmgr_log_path_valid "$2" || return 1
	case $1 in "$2" | "$2"/*) return 0 ;; *) return 1 ;; esac
}

# Native shell builtins avoid starting an untracked helper when an attachment
# callback needs to verify the held file descriptor mount identity.
cfmgr_log_fd_mount_ok() {
	[ "$#" -eq 2 ] || return 2
	case $1 in 3 | 4 | 5 | 6 | 7 | 8 | 9) ;; *) return 2 ;; esac
	case $2 in '' | *[!0-9]* | 0*) return 2 ;; esac
	cfmgr_log_fd_count=0 cfmgr_log_fd_seen=''
	while IFS=' 	' read -r cfmgr_log_fd_key cfmgr_log_fd_value cfmgr_log_fd_extra; do
		case $cfmgr_log_fd_key in
		mnt_id:)
			cfmgr_log_fd_count=$((cfmgr_log_fd_count + 1))
			[ -z "$cfmgr_log_fd_extra" ] || return 1
			cfmgr_log_fd_seen=$cfmgr_log_fd_value
			;;
		esac
	done <"/proc/self/fdinfo/$1" || return 1
	[ "$cfmgr_log_fd_count:$cfmgr_log_fd_seen" = "1:$2" ]
}

# Exact basenames owned by this capture. Unknown same-prefix objects never
# become cleanup authority. All registrations occur only after exclusive create
# or after the supervisor created its unique receipt in our private context.
cfmgr_log_register() {
	[ "$#" -eq 1 ] || return 2
	case $1 in '' | *[!A-Za-z0-9._-]* | . | ..) return 2 ;; esac
	case "${cfmgr_log_owned:-}
" in *"
$1
"*) return 1 ;; esac
	cfmgr_log_owned=${cfmgr_log_owned:-}
	cfmgr_log_owned="$cfmgr_log_owned
$1"
}

# Fixed helper runner supplied by the logging controller's isolated subshell.
# The capture context remains authoritative; callers must preserve status 3.
cfmgr_log_run() {
	cfmgr_log_run_mode=$1 cfmgr_log_run_tool=$2
	shift 2
	case $cfmgr_log_run_mode in diagnostic-*) ;; *) return 2 ;; esac
	case $cfmgr_log_run_mode in *[!A-Za-z0-9._-]*) return 2 ;; esac
	[ "${cfmgr_log_interrupt:-0}" = 0 ] || return 1
	case ${cfmgr_log_operations:-0}:${cfmgr_probe_serial:-0} in *[!0-9:]* | :* | *:) return 2 ;; esac
	[ "${cfmgr_log_operations:-0}" -lt "${cfmgr_log_operation_limit:-96}" ] || return 1
	cfmgr_log_operations=$((${cfmgr_log_operations:-0} + 1))
	cfmgr_log_next_serial=$((${cfmgr_probe_serial:-0} + 1))
	cfmgr_log_run_out=$cfmgr_log_run_mode.$cfmgr_log_next_serial.out
	cfmgr_log_run_err=$cfmgr_log_run_mode.$cfmgr_log_next_serial.err
	for cfmgr_log_run_name in "$cfmgr_log_run_out" "$cfmgr_log_run_err"; do
		[ ! -e "$cfmgr_log_context/$cfmgr_log_run_name" ] && [ ! -L "$cfmgr_log_context/$cfmgr_log_run_name" ] || return 1
	done
	if cfmgr_prerequisites_run "$cfmgr_log_run_mode" "$cfmgr_log_context" /bin/sh \
		"$cfmgr_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc \
		"$cfmgr_log_run_tool" "$@"; then cfmgr_log_run_code=0; else cfmgr_log_run_code=$?; fi
	# The only process that can create these fixed serial names is our invoked
	# supervisor, after the absence check in the root-only context. Partial
	# creation on supervisor setup failure is accounted for as well.
	for cfmgr_log_run_name in "$cfmgr_log_run_out" "$cfmgr_log_run_err"; do
		if [ -e "$cfmgr_log_context/$cfmgr_log_run_name" ] || [ -L "$cfmgr_log_context/$cfmgr_log_run_name" ]; then
			[ -f "$cfmgr_log_context/$cfmgr_log_run_name" ] && [ ! -L "$cfmgr_log_context/$cfmgr_log_run_name" ] || return 3
			cfmgr_log_register "$cfmgr_log_run_name" || return 3
		fi
	done
	[ "$cfmgr_log_run_code" = 0 ] || return "$cfmgr_log_run_code"
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_log_line() {
	cfmgr_log_line_value='' cfmgr_log_line_tail=''
	{
		IFS= read -r cfmgr_log_line_value || return 1
		if IFS= read -r cfmgr_log_line_tail; then return 1; fi
		[ -z "$cfmgr_log_line_tail" ]
	} <"$1"
}

cfmgr_log_observe_mount() {
	cfmgr_log_run diagnostic-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$1" || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" && cfmgr_log_data_mount_record "$cfmgr_log_line_value" || return 1
	cfmgr_log_mount_snapshot=$cfmgr_log_line_value
}

# -ildn is fixed by the worker; the path is an admitted direct operand and
# remains data, never a shell fragment. The owner and permission checks are
# deliberately stronger than mount existence. No chmod/repair is attempted.
cfmgr_log_metadata() {
	cfmgr_log_run diagnostic-meta /bin/ls "$1" || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_log_meta_inode cfmgr_log_meta_mode cfmgr_log_meta_links cfmgr_log_meta_uid \
		cfmgr_log_meta_gid cfmgr_log_meta_size cfmgr_log_meta_rest <<EOF_LOG_META
$cfmgr_log_line_value
EOF_LOG_META
	case $cfmgr_log_meta_inode:$cfmgr_log_meta_links:$cfmgr_log_meta_uid:$cfmgr_log_meta_size in
	*[!0-9:]*) return 1 ;;
	esac
	[ -n "$cfmgr_log_meta_inode" ] && [ "$cfmgr_log_meta_uid" = 0 ] || return 1
	case $2:$cfmgr_log_meta_mode in
	directory:d?????????) ;;
	file:-?????????) [ "$cfmgr_log_meta_links" = 1 ] || return 1 ;;
	*) return 1 ;;
	esac
	case $cfmgr_log_meta_mode in ?????w???? | ????????w?) return 1 ;; esac
}

# Nonrecursive attachment callback for the existing single-child supervisor.
# Readlink and mountinfo are the same fixed, short observation pattern used by
# Backup. It never starts another cfmgr_prerequisites_run while one is active.
# shellcheck disable=SC3013
cfmgr_log_attached() {
	case $#:${1:-} in 0: | 1:source | 1:context) ;; *) return 2 ;; esac
	cfmgr_log_attachment_scope=${1:-destination}
	[ "${cfmgr_log_interrupt:-0}" = 0 ] || return 1
	[ -d "${cfmgr_log_context:-}" ] && [ ! -L "$cfmgr_log_context" ] &&
		[ "$cfmgr_log_context" -ef /proc/self/fd/5 ] || return 1
	set -- /tmp "$cfmgr_log_context"
	cfmgr_log_attachment_expected="$cfmgr_log_tmp_mount
$cfmgr_log_tmp_mount"
	cfmgr_log_attachment_opt=''
	if [ "${cfmgr_log_lock_held:-0}" = 1 ]; then
		[ -f "$cfmgr_log_lock" ] && [ ! -L "$cfmgr_log_lock" ] &&
			[ "$cfmgr_log_lock" -ef /proc/self/fd/0 ] || return 1
	fi
	# Explicit context-only callbacks supervise read-only metadata and private
	# processing. Direct owner checks and all destination writers stay full.
	if [ "$cfmgr_log_attachment_scope" != context ] && [ "${cfmgr_log_mount_pinned:-0}" = 1 ]; then
		if [ -n "${cfmgr_log_auto_target:-}" ]; then
			cfmgr_log_attachment_opt=$(/usr/bin/readlink -f /opt) || return 1
			[ "$cfmgr_log_attachment_opt" = "$cfmgr_log_auto_target" ] || return 1
		fi
		[ -d "$cfmgr_log_mount_path" ] && [ ! -L "$cfmgr_log_mount_path" ] &&
			[ "$cfmgr_log_mount_path" -ef /proc/self/fd/6 ] || return 1
		[ "$(/usr/bin/readlink -f "$cfmgr_log_mount_path")" = "$cfmgr_log_mount_path" ] || return 1
		cfmgr_log_fd_mount_ok 6 "$cfmgr_log_mount_id" || return 1
		set -- "$@" "$cfmgr_log_mount_path"
		cfmgr_log_attachment_expected="$cfmgr_log_attachment_expected
$cfmgr_log_mount_snapshot"
		if [ "${cfmgr_log_walk_pinned:-0}" = 1 ]; then
			[ -d "$cfmgr_log_walk" ] && [ ! -L "$cfmgr_log_walk" ] &&
				[ "$cfmgr_log_walk" -ef /proc/self/fd/7 ] || return 1
			[ "$(/usr/bin/readlink -f "$cfmgr_log_walk")" = "$cfmgr_log_walk" ] || return 1
			cfmgr_log_fd_mount_ok 7 "$cfmgr_log_mount_id" || return 1
			set -- "$@" "$cfmgr_log_walk"
			cfmgr_log_attachment_expected="$cfmgr_log_attachment_expected
$cfmgr_log_mount_snapshot"
		fi
	fi
	if [ "$cfmgr_log_attachment_scope" = source ]; then
		[ "${cfmgr_scribe_pinned:-0}" = 1 ] && [ -d "$cfmgr_scribe_mount" ] &&
			[ ! -L "$cfmgr_scribe_mount" ] && [ "$cfmgr_scribe_mount" -ef /proc/self/fd/8 ] || return 1
		if [ -z "$cfmgr_log_attachment_opt" ]; then
			cfmgr_log_attachment_opt=$(/usr/bin/readlink -f /opt) || return 1
		fi
		[ "$cfmgr_log_attachment_opt" = "$cfmgr_scribe_opt" ] || return 1
		if [ "${cfmgr_log_mount_pinned:-0}:$cfmgr_scribe_mount" != "1:${cfmgr_log_mount_path:-}" ]; then
			[ "$(/usr/bin/readlink -f "$cfmgr_scribe_mount")" = "$cfmgr_scribe_mount" ] || return 1
		fi
		cfmgr_log_fd_mount_ok 8 "$cfmgr_scribe_mount_id" || return 1
		set -- "$@" "$cfmgr_scribe_mount" "$cfmgr_scribe_opt"
		cfmgr_log_attachment_expected="$cfmgr_log_attachment_expected
$cfmgr_scribe_mount_snapshot
$cfmgr_scribe_mount_snapshot"
	fi
	# One validated snapshot, with every original path observation retained.
	cfmgr_log_attachment_records=$(cfmgr_storage_mountinfo /usr/bin/awk targets-v1 "$@" /proc/self/mountinfo) || return 1
	[ "$cfmgr_log_attachment_records" = "$cfmgr_log_attachment_expected" ]
}

# Start with an observed mounted volume, then keep a directory FD anchored to
# every existing component. Only capture can request the mkdir mode. Once an
# absent component is seen during preview, no filesystem object is created.
# This function assumes its caller has acquired capture serialization first.
cfmgr_log_walk_destination() {
	[ "$#" -eq 2 ] || return 2
	case $2 in preview | create) ;; *) return 2 ;; esac
	cfmgr_log_path_on_mount "$1" "$cfmgr_log_mount_path" || return 1
	cfmgr_log_requested=$1 cfmgr_log_walk=$cfmgr_log_mount_path cfmgr_log_walk_pinned=0
	cfmgr_log_metadata "$cfmgr_log_mount_path" directory || return $?
	exec 7<&6 || return 1
	cfmgr_log_walk_pinned=1
	cfmgr_log_attached || return 1
	[ "$cfmgr_log_requested" != "$cfmgr_log_mount_path" ] || return 0
	cfmgr_log_remaining=${cfmgr_log_requested#"$cfmgr_log_mount_path"/}
	while [ -n "$cfmgr_log_remaining" ]; do
		cfmgr_log_component=${cfmgr_log_remaining%%/*}
		case $cfmgr_log_remaining in */*) cfmgr_log_remaining=${cfmgr_log_remaining#*/} ;; *) cfmgr_log_remaining='' ;; esac
		case $cfmgr_log_component in '' | . | .. | */*) return 1 ;; esac
		cfmgr_log_attached || return 1
		if [ ! -e "/proc/self/fd/7/$cfmgr_log_component" ] && [ ! -L "/proc/self/fd/7/$cfmgr_log_component" ]; then
			[ "$2" = create ] || return 0
			cfmgr_log_run diagnostic-mkdir /bin/mkdir "$cfmgr_log_component" || return $?
		fi
		cfmgr_log_next=$cfmgr_log_walk/$cfmgr_log_component
		[ -d "$cfmgr_log_next" ] && [ ! -L "$cfmgr_log_next" ] || return 1
		cfmgr_log_metadata "$cfmgr_log_next" directory || return $?
		[ "$(/usr/bin/readlink -f "$cfmgr_log_next")" = "$cfmgr_log_next" ] || return 1
		[ "$(cfmgr_storage_mountinfo /usr/bin/awk "$cfmgr_log_next" /proc/self/mountinfo)" = "$cfmgr_log_mount_snapshot" ] || return 1
		{ exec 7<&3; } 3<"/proc/self/fd/7/$cfmgr_log_component" || return 1
		cfmgr_log_walk=$cfmgr_log_next
		cfmgr_log_attached || return 1
	done
}

# Open a diagnostic output without truncating old history. The create mode is a
# single fixed shell builtin with noclobber in the worker, addressed relative to
# pinned FD7; existing objects are never repaired or replaced.
# shellcheck disable=SC3013
cfmgr_log_open_output() {
	[ "$#" -eq 2 ] || return 2
	case $1 in developer.log | health-[0-9]*.log | scribe-[A-Za-z0-9._-]*.log) ;; *) return 2 ;; esac
	case $1 in *[!A-Za-z0-9._-]* | *..*) return 2 ;; esac
	case $2 in append | exclusive) ;; *) return 2 ;; esac
	cfmgr_log_output=$cfmgr_log_walk/$1 cfmgr_log_output_created=0
	cfmgr_log_attached || return 1
	if [ "$2" = exclusive ] || { [ ! -e "/proc/self/fd/7/$1" ] && [ ! -L "/proc/self/fd/7/$1" ]; }; then
		cfmgr_log_run diagnostic-create /usr/bin/printf "$1" || return $?
		cfmgr_log_output_created=1
	fi
	[ -f "/proc/self/fd/7/$1" ] && [ ! -L "/proc/self/fd/7/$1" ] || return 1
	cfmgr_log_metadata "$cfmgr_log_output" file || return $?
	{ exec 4<&3; } 3<"/proc/self/fd/7/$1" || return 1
	[ "$cfmgr_log_output" -ef /proc/self/fd/4 ] && cfmgr_log_fd_mount_ok 4 "$cfmgr_log_mount_id" || return 1
	cfmgr_log_attached || return 1
	# Reopen only the already-held inode; unlike path-based >> this cannot
	# follow an attacker-substituted symlink or create a foreign target.
	exec 4>>/proc/self/fd/4 || return 1
	[ "$cfmgr_log_output" -ef /proc/self/fd/4 ] && cfmgr_log_fd_mount_ok 4 "$cfmgr_log_mount_id" && cfmgr_log_attached
}

# Consume exactly a pinned regular input's admitted byte count without a global
# file-size cap on retained developer.log. The block and tail modes each exec
# one native dd and inherit lock0, RAM5, mount6, destination7 and output4.
# A failed/unknown append is never retried automatically.
cfmgr_log_write_fd() {
	[ "$#" -eq 1 ] || return 2
	case $1 in '' | *[!0-9]* | 0*) return 2 ;; esac
	[ "${#1}" -le 6 ] && [ "$1" -le 196608 ] || return 2
	cfmgr_log_write_size=$1 cfmgr_log_write_blocks=$((($1 + 4095) / 4096))
	[ -f /proc/self/fd/3 ] && [ -f /proc/self/fd/4 ] || return 1
	[ "${cfmgr_log_output:-}" -ef /proc/self/fd/4 ] || return 1
	cfmgr_log_attached || return 1
	# The held regular input is an immutable private stage of the exact checked
	# size; EOF limits the final block. Never copy an unadmitted growing stream.
	cfmgr_log_run diagnostic-copy /bin/dd "$cfmgr_log_write_blocks" || return $?
	# Input identity remains held while checking the exact consumed offset. A
	# short successful read is incomplete, never reported as saved.
	cfmgr_log_pos_count=0 cfmgr_log_pos_value=''
	while IFS=' 	' read -r cfmgr_log_pos_key cfmgr_log_pos_item cfmgr_log_pos_extra; do
		case $cfmgr_log_pos_key in
		pos:)
			cfmgr_log_pos_count=$((cfmgr_log_pos_count + 1))
			cfmgr_log_pos_value=$cfmgr_log_pos_item
			[ -z "$cfmgr_log_pos_extra" ] || return 1
			;;
		esac
	done </proc/self/fdinfo/3 || return 1
	[ "$cfmgr_log_pos_count:$cfmgr_log_pos_value" = "1:$cfmgr_log_write_size" ] &&
		[ "$cfmgr_log_output" -ef /proc/self/fd/4 ] && cfmgr_log_attached
}

# This setup mirrors Status's existing fixed native private-RAM bootstrap. The
# installed entry must already admit this library, worker and their source root.
# It never creates a destination directory or changes configuration.
# shellcheck disable=SC3013
cfmgr_log_prepare() {
	[ -d /tmp ] && [ ! -L /tmp ] && [ "$(/usr/bin/readlink -f /tmp)" = /tmp ] || return 1
	cfmgr_log_tmp_mount=$(cfmgr_storage_mountinfo /usr/bin/awk /tmp /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_log_tmp_id cfmgr_log_tmp_parent cfmgr_log_tmp_device cfmgr_log_tmp_root \
		cfmgr_log_tmp_point cfmgr_log_tmp_type cfmgr_log_tmp_rest <<EOF_LOG_RAM
$cfmgr_log_tmp_mount
EOF_LOG_RAM
	case $cfmgr_log_tmp_type in tmpfs | ramfs | rootfs) ;; *) return 1 ;; esac
	cfmgr_log_root=/tmp/cfmgr-diagnostics
	if [ ! -e "$cfmgr_log_root" ] && [ ! -L "$cfmgr_log_root" ]; then
		(
			umask 077
			/bin/mkdir -m 700 "$cfmgr_log_root"
		) || return 1
	fi
	[ -d "$cfmgr_log_root" ] && [ ! -L "$cfmgr_log_root" ] &&
		[ "$(/usr/bin/readlink -f "$cfmgr_log_root")" = "$cfmgr_log_root" ] || return 1
	cfmgr_log_root_meta=$(/bin/ls -ldn "$cfmgr_log_root") || return 1
	IFS=' ' read -r cfmgr_log_root_mode cfmgr_log_root_links cfmgr_log_root_uid cfmgr_log_root_extra <<EOF_LOG_ROOT
$cfmgr_log_root_meta
EOF_LOG_ROOT
	[ "$cfmgr_log_root_mode:$cfmgr_log_root_uid" = drwx------:0 ] || return 1
	[ "$(cfmgr_storage_mountinfo /usr/bin/awk "$cfmgr_log_root" /proc/self/mountinfo)" = "$cfmgr_log_tmp_mount" ] || return 1
	IFS= read -r cfmgr_log_self </proc/self/stat || return 1
	cfmgr_log_pid=${cfmgr_log_self%% *}
	cfmgr_prerequisites_identity "$cfmgr_log_pid" || return 1
	cfmgr_log_start=$cfmgr_identity_start
	case $cfmgr_log_start in '' | *[!0-9]*) return 1 ;; esac
	cfmgr_log_context=$cfmgr_log_root/capture.$cfmgr_log_pid.$cfmgr_log_start
	(
		umask 077
		/bin/mkdir -m 700 "$cfmgr_log_context"
	) || return 1
	exec 5<"$cfmgr_log_context" || return 1
	cfmgr_log_interrupt=0 cfmgr_log_operations=0 cfmgr_log_operation_limit=96 cfmgr_log_file_limit=200 cfmgr_log_owned='' cfmgr_probe_pid='' cfmgr_probe_status=invalid cfmgr_probe_serial=0
	cfmgr_log_mount_pinned=0 cfmgr_log_walk_pinned=0 cfmgr_log_lock_held=0 cfmgr_log_auto_target=
	cfmgr_config_lock_fd0=0 cfmgr_health_active=0
	trap 'cfmgr_log_interrupt=1' HUP INT TERM
	cfmgr_prerequisites_supervisor || return 1
	cfmgr_log_boot=$cfmgr_probe_boot
	cfmgr_log_boot_valid "$cfmgr_log_boot" || return 1
	cfmgr_log_deadline=$((cfmgr_probe_now + 20))
}

# Decode a typed config receipt or encode an effective path through a fixed
# worker. Text cannot be shell input; invalid/unknown custom never becomes Auto.
cfmgr_log_convert() {
	[ "$#" -eq 2 ] || return 2
	case $1 in decode | encode) ;; *) return 2 ;; esac
	cfmgr_log_run diagnostic-convert /usr/bin/awk "$1" "$2" || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	cfmgr_log_converted=$cfmgr_log_line_value
}

# Admit the actual /opt backing mount for Auto or the nearest existing safe
# ancestor of a custom destination. A verified /mnt alias is canonicalized via
# readlink; no namespace, JFFS, RAM or custom-path fallback is inferred.
cfmgr_log_select_destination() {
	[ "$#" -eq 1 ] || return 2
	cfmgr_log_selection=$1
	case $cfmgr_log_selection in
	'!') return 1 ;;
	-)
		cfmgr_log_run diagnostic-realpath /usr/bin/readlink /opt || return $?
		cfmgr_log_line "$cfmgr_probe_stdout" || return 1
		cfmgr_log_target=$cfmgr_log_line_value
		cfmgr_log_auto_target=$cfmgr_log_target
		cfmgr_log_path_valid "$cfmgr_log_target" || return 1
		[ -d "$cfmgr_log_target" ] && [ ! -L "$cfmgr_log_target" ] || return 1
		cfmgr_log_observe_mount "$cfmgr_log_target" || return $?
		cfmgr_log_effective=$cfmgr_log_mount_path/CFMgr/diagnostics
		;;
	*)
		cfmgr_log_convert decode "$cfmgr_log_selection" || return $?
		cfmgr_log_requested=$cfmgr_log_converted
		cfmgr_log_path_valid "$cfmgr_log_requested" || return 1
		cfmgr_log_ancestor=$cfmgr_log_requested cfmgr_log_suffix=''
		while [ ! -e "$cfmgr_log_ancestor" ] && [ ! -L "$cfmgr_log_ancestor" ]; do
			cfmgr_log_part=${cfmgr_log_ancestor##*/}
			cfmgr_log_suffix=/$cfmgr_log_part$cfmgr_log_suffix
			cfmgr_log_ancestor=${cfmgr_log_ancestor%/*}
			[ -n "$cfmgr_log_ancestor" ] || return 1
		done
		[ -d "$cfmgr_log_ancestor" ] && [ ! -L "$cfmgr_log_ancestor" ] || return 1
		cfmgr_log_original_ancestor=$cfmgr_log_ancestor
		cfmgr_log_run diagnostic-realpath /usr/bin/readlink "$cfmgr_log_ancestor" || return $?
		cfmgr_log_line "$cfmgr_probe_stdout" || return 1
		cfmgr_log_ancestor=$cfmgr_log_line_value
		cfmgr_log_path_valid "$cfmgr_log_ancestor" || return 1
		if [ "$cfmgr_log_original_ancestor" != "$cfmgr_log_ancestor" ]; then
			cfmgr_log_run diagnostic-realpath /usr/bin/readlink /mnt || return $?
			cfmgr_log_line "$cfmgr_probe_stdout" || return 1
			cfmgr_log_alias_matches "$cfmgr_log_original_ancestor" "$cfmgr_log_ancestor" "$cfmgr_log_line_value" || return 1
		fi
		cfmgr_log_observe_mount "$cfmgr_log_ancestor" || return $?
		cfmgr_log_effective=$cfmgr_log_ancestor$cfmgr_log_suffix
		cfmgr_log_path_on_mount "$cfmgr_log_effective" "$cfmgr_log_mount_path" || return 1
		;;
	esac
	[ "$(/usr/bin/readlink -f "$cfmgr_log_mount_path")" = "$cfmgr_log_mount_path" ] || return 1
	exec 6<"$cfmgr_log_mount_path" || return 1
	cfmgr_log_mount_pinned=1
	cfmgr_log_attached || return 1
	cfmgr_log_convert encode "$cfmgr_log_effective" || return $?
	cfmgr_log_effective_hex=$cfmgr_log_converted
}

cfmgr_log_cleanup_inventory() {
	cfmgr_log_cleanup_count=0
	for cfmgr_log_cleanup_item in "$cfmgr_log_context"/* "$cfmgr_log_context"/.[!.]* "$cfmgr_log_context"/..?*; do
		[ -e "$cfmgr_log_cleanup_item" ] || [ -L "$cfmgr_log_cleanup_item" ] || continue
		[ -f "$cfmgr_log_cleanup_item" ] && [ ! -L "$cfmgr_log_cleanup_item" ] || return 1
		case "${cfmgr_log_owned:-}
" in *"
${cfmgr_log_cleanup_item##*/}
"*) ;; *) return 1 ;; esac
		cfmgr_log_cleanup_count=$((cfmgr_log_cleanup_count + 1))
		[ "$cfmgr_log_cleanup_count" -le "${cfmgr_log_file_limit:-200}" ] || return 1
	done
}

cfmgr_log_cleanup() {
	[ "${cfmgr_log_interrupt:-0}" = 0 ] && [ -d "${cfmgr_log_context:-}" ] &&
		[ ! -L "$cfmgr_log_context" ] && [ "$cfmgr_log_context" -ef /proc/self/fd/5 ] || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 1
	cfmgr_log_cleanup_inventory || return 1
	for cfmgr_log_cleanup_item in "$cfmgr_log_context"/* "$cfmgr_log_context"/.[!.]* "$cfmgr_log_context"/..?*; do
		[ -f "$cfmgr_log_cleanup_item" ] || continue
		/bin/rm "$cfmgr_log_cleanup_item" || return 1
	done
	/bin/rmdir "$cfmgr_log_context" || return 1
	exec 3<&- 4>&- 5<&- 6<&- 7<&-
}

# Independent capture lock in private RAM. It does not touch the config Save
# lock. Every capture child explicitly inherits fd0's flock description.
# shellcheck disable=SC3013
cfmgr_log_lock() {
	cfmgr_log_lock=$cfmgr_log_root/capture.lock
	if [ ! -e "$cfmgr_log_lock" ] && [ ! -L "$cfmgr_log_lock" ]; then
		(
			umask 077
			set -C
			: >"$cfmgr_log_lock"
		) 2>/dev/null || :
	fi
	[ -f "$cfmgr_log_lock" ] && [ ! -L "$cfmgr_log_lock" ] || return 1
	cfmgr_log_metadata "$cfmgr_log_lock" file || return $?
	exec 0<"$cfmgr_log_lock" || return 1
	[ "$cfmgr_log_lock" -ef /proc/self/fd/0 ] || return 1
	cfmgr_log_run diagnostic-lock /usr/bin/flock || return $?
	cfmgr_log_lock_held=1
	cfmgr_log_attached
}

# Bounded private snapshot from the installed config; a diagnostic-read worker
# projects only schema/generation/manager fields from the already validated JSON
# tree. Unrelated missing feature fields do not prevent reading this preference.
# No Store startup, write, recovery or evaluation of configuration is performed.
# shellcheck disable=SC3013
cfmgr_log_read_config() {
	cfmgr_log_config_state=unavailable cfmgr_log_config_value='!' cfmgr_log_config_dev=0
	cfmgr_log_config_source=$cfmgr_source/config
	[ -f "$cfmgr_log_config_source" ] && [ ! -L "$cfmgr_log_config_source" ] || return 1
	cfmgr_log_metadata "$cfmgr_log_config_source" file || return $?
	[ "$cfmgr_log_meta_mode" = -rw------- ] || return 1
	cfmgr_log_config_inode=$cfmgr_log_meta_inode cfmgr_log_config_bytes=$cfmgr_log_meta_size
	case $cfmgr_log_config_bytes in '' | *[!0-9]* | 0*) return 1 ;; esac
	[ "$cfmgr_log_config_bytes" -le 65536 ] || return 1
	exec 3<"$cfmgr_log_config_source" || return 1
	[ "$cfmgr_log_config_source" -ef /proc/self/fd/3 ] || return 1
	cfmgr_log_config_stage=$cfmgr_log_context/config.$cfmgr_log_operations
	(
		umask 077
		set -C
		: >"$cfmgr_log_config_stage"
	) || return 1
	cfmgr_log_register "${cfmgr_log_config_stage##*/}" || return 1
	exec 4>"$cfmgr_log_config_stage" || return 1
	cfmgr_log_output=$cfmgr_log_config_stage
	cfmgr_log_write_fd "$cfmgr_log_config_bytes" || return $?
	[ "$cfmgr_log_config_source" -ef /proc/self/fd/3 ] || return 1
	cfmgr_log_metadata "$cfmgr_log_config_source" file || return $?
	[ "$cfmgr_log_config_inode:$cfmgr_log_config_bytes" = "$cfmgr_log_meta_inode:$cfmgr_log_meta_size" ] || return 1
	exec 4>&- 3<&-
	cfmgr_log_metadata "$cfmgr_log_config_stage" file || return $?
	[ "$cfmgr_log_meta_size" = "$cfmgr_log_config_bytes" ] || return 1
	exec 3<"$cfmgr_log_config_stage" || return 1
	cfmgr_log_run diagnostic-config /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" "$cfmgr_log_config_bytes" || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_log_config_tag cfmgr_log_config_version cfmgr_log_config_generation cfmgr_log_config_dev \
		cfmgr_log_config_value cfmgr_log_config_end cfmgr_log_config_extra <<EOF_LOG_CONFIG
$cfmgr_log_line_value
EOF_LOG_CONFIG
	[ "$cfmgr_log_config_tag:$cfmgr_log_config_version:$cfmgr_log_config_end:$cfmgr_log_config_extra" = CFMGR-DIAGNOSTIC-CONFIG:1:END: ] || return 1
	case $cfmgr_log_config_generation in '' | 0* | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_log_config_generation}" -le 20 ] || return 1
	case $cfmgr_log_config_dev in 0 | 1) ;; *) return 1 ;; esac
	case $cfmgr_log_config_value in
	- | '!') ;;
	'' | *[!0-9a-f]*) return 1 ;;
	*) [ "${#cfmgr_log_config_value}" -le 2048 ] && [ "$((${#cfmgr_log_config_value} % 2))" -eq 0 ] || return 1 ;;
	esac
	[ "$cfmgr_log_line_value" = "CFMGR-DIAGNOSTIC-CONFIG 1 $cfmgr_log_config_generation $cfmgr_log_config_dev $cfmgr_log_config_value END" ] || return 1
	cfmgr_log_config_state='read'
	exec 3<&-
}

# Each persisted batch identifies its boot/process and router UTC clock. Event
# rows retain monotonic uptime, so clock adjustments cannot reorder operations.
cfmgr_log_run_header() {
	cfmgr_log_run diagnostic-date /bin/date || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	case $cfmgr_log_line_value in ????-??-??T??:??:??Z) ;; *) return 1 ;; esac
	case $cfmgr_log_line_value in *[!0-9TZ:-]*) return 1 ;; esac
	cfmgr_log_event_text="CFMGR-CAPTURE 1 $cfmgr_log_line_value $cfmgr_log_boot $cfmgr_log_pid $cfmgr_log_start $cfmgr_log_kind
$cfmgr_log_event_text"
}

cfmgr_log_stage_events() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 131072 ] || return 2
	# Only already-typed parent-generated events are accepted. Tabs/newlines and
	# printable ASCII are supported; raw child output is never an input contract.
	cfmgr_log_event_tab='	'
	cfmgr_log_event_newline='
'
	case $1 in *[!\ -~"$cfmgr_log_event_tab$cfmgr_log_event_newline"]*) return 2 ;; esac
	cfmgr_log_event_bytes=${#1}
	cfmgr_log_event_stage=$cfmgr_log_context/events
	(
		umask 077
		set -C
		: >"$cfmgr_log_event_stage"
	) || return 1
	cfmgr_log_register events || return 1
	printf '%s' "$1" >"$cfmgr_log_event_stage" || return 1
	cfmgr_log_metadata "$cfmgr_log_event_stage" file || return $?
	[ "$cfmgr_log_meta_size" = "$cfmgr_log_event_bytes" ]
}

# The caller passes the already-rendered, sanitized Health output in its own
# private status context. Snapshot it into our owned RAM before destination I/O.
# shellcheck disable=SC3013
cfmgr_log_stage_report() {
	[ "$#" -eq 2 ] || return 2
	case $1 in /tmp/cfmgr-status.*/*) ;; *) return 2 ;; esac
	case $2 in '' | *[!0-9]* | 0*) return 2 ;; esac
	[ "${#2}" -le 6 ] && [ "$2" -le 196608 ] || return 2
	cfmgr_log_report_input=$1 cfmgr_log_report_bytes=$2
	cfmgr_log_report_parent=${cfmgr_log_report_input%/*}
	[ -d "$cfmgr_log_report_parent" ] && [ ! -L "$cfmgr_log_report_parent" ] &&
		[ "$(/usr/bin/readlink -f "$cfmgr_log_report_parent")" = "$cfmgr_log_report_parent" ] || return 1
	cfmgr_log_metadata "$cfmgr_log_report_parent" directory || return $?
	[ "$cfmgr_log_meta_mode" = drwx------ ] || return 1
	[ -f "$cfmgr_log_report_input" ] && [ ! -L "$cfmgr_log_report_input" ] || return 1
	cfmgr_log_metadata "$cfmgr_log_report_input" file || return $?
	[ "$cfmgr_log_meta_mode:$cfmgr_log_meta_size" = "-rw-------:$cfmgr_log_report_bytes" ] || return 1
	cfmgr_log_report_inode=$cfmgr_log_meta_inode
	exec 3<"$cfmgr_log_report_input" || return 1
	[ "$cfmgr_log_report_input" -ef /proc/self/fd/3 ] || return 1
	cfmgr_log_report_stage=$cfmgr_log_context/report
	(
		umask 077
		set -C
		: >"$cfmgr_log_report_stage"
	) || return 1
	cfmgr_log_register report || return 1
	exec 4>"$cfmgr_log_report_stage" || return 1
	cfmgr_log_output=$cfmgr_log_report_stage
	cfmgr_log_write_fd "$cfmgr_log_report_bytes" || return $?
	[ "$cfmgr_log_report_input" -ef /proc/self/fd/3 ] || return 1
	cfmgr_log_metadata "$cfmgr_log_report_input" file || return $?
	[ "$cfmgr_log_report_inode:$cfmgr_log_report_bytes" = "$cfmgr_log_meta_inode:$cfmgr_log_meta_size" ] || return 1
	exec 3<&- 4>&-
	cfmgr_log_metadata "$cfmgr_log_report_stage" file || return $?
	[ "$cfmgr_log_meta_size" = "$cfmgr_log_report_bytes" ]
}

# Explicit destination display never creates data folders or capture artifacts.
cfmgr_log_destination() (
	[ "$#" -eq 2 ] && [ "$1" = preview ] || exit 2
	if [ "${cfmgr_probe_status:-}" = unresolved ] || { [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; }; then
		printf 'CFMGR-LOG-DEST 1 unavailable - END\n'
		exit 1
	fi
	cfmgr_log_preview_value=$2 cfmgr_log_result=unavailable cfmgr_log_effective_hex=-
	set +x
	set +v
	exec 0</dev/null 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<&-
	if cfmgr_log_prepare && cfmgr_log_select_destination "$cfmgr_log_preview_value" &&
		cfmgr_log_walk_destination "$cfmgr_log_effective" preview; then
		cfmgr_log_result=available cfmgr_log_code=0
	else cfmgr_log_code=$?; fi
	if [ "${cfmgr_log_code:-1}" != 3 ] && [ -n "${cfmgr_log_context:-}" ]; then
		cfmgr_log_interrupt=0
		cfmgr_log_cleanup || cfmgr_log_code=1
	fi
	if [ "${cfmgr_log_code:-1}" != 0 ]; then cfmgr_log_result=unavailable cfmgr_log_effective_hex=-; fi
	printf 'CFMGR-LOG-DEST 1 %s %s END\n' "$cfmgr_log_result" "$cfmgr_log_effective_hex"
	exit "${cfmgr_log_code:-1}"
)

cfmgr_log_still_enabled() {
	if cfmgr_log_read_config; then :; else return $?; fi
	if [ "$cfmgr_log_config_dev" != 1 ]; then
		cfmgr_log_result=disabled
		return 4
	fi
	[ "$cfmgr_log_config_value" = "$cfmgr_log_destination_value" ]
}

# Boot UUID plus process start time and pid distinguishes captures across
# process reuse/reboot. Sequence handles an existing name without replacing it.
cfmgr_log_boot_valid() {
	[ "$#" -eq 1 ] && [ "${#1}" = 36 ] || return 1
	case $1 in *[!0-9a-fA-F-]*) return 1 ;; esac
	IFS=- read -r cfmgr_log_boot_a cfmgr_log_boot_b cfmgr_log_boot_c cfmgr_log_boot_d cfmgr_log_boot_e cfmgr_log_boot_extra <<EOF_LOG_BOOT
$1
EOF_LOG_BOOT
	[ "${#cfmgr_log_boot_a}:${#cfmgr_log_boot_b}:${#cfmgr_log_boot_c}:${#cfmgr_log_boot_d}:${#cfmgr_log_boot_e}:$cfmgr_log_boot_extra" = 8:4:4:4:12: ]
}

cfmgr_log_health_open() {
	cfmgr_log_boot_valid "$cfmgr_log_boot" || return 1
	case $cfmgr_log_pid:$cfmgr_log_start in *[!0-9:]* | :* | *:) return 1 ;; esac
	cfmgr_log_health_sequence=1
	while [ "$cfmgr_log_health_sequence" -le 16 ]; do
		cfmgr_log_output_name=health-$cfmgr_log_boot-$cfmgr_log_start-$cfmgr_log_pid-$cfmgr_log_health_sequence.log
		cfmgr_log_attached || return 1
		if [ -e "$cfmgr_log_walk/$cfmgr_log_output_name" ] || [ -L "$cfmgr_log_walk/$cfmgr_log_output_name" ]; then
			cfmgr_log_health_sequence=$((cfmgr_log_health_sequence + 1))
			continue
		fi
		if cfmgr_log_open_output "$cfmgr_log_output_name" exclusive; then return 0; else cfmgr_log_open_code=$?; fi
		[ "$cfmgr_log_open_code" != 3 ] || return 3
		[ "${cfmgr_log_output_created:-0}" = 0 ] || return "$cfmgr_log_open_code"
		if [ -e "$cfmgr_log_walk/$cfmgr_log_output_name" ] || [ -L "$cfmgr_log_walk/$cfmgr_log_output_name" ]; then
			cfmgr_log_health_sequence=$((cfmgr_log_health_sequence + 1))
			continue
		fi
		return "$cfmgr_log_open_code"
	done
	return 1
}

cfmgr_log_header_check() {
	[ "$#" -eq 1 ] || return 2
	cfmgr_log_line "$1" && [ "$cfmgr_log_line_value" = 'CFMGR-DEVELOPER 1' ]
}

# Existing files are eligible only when their held inode starts with the exact
# diagnostic owner header. New files receive it once through the bounded writer.
# No old log is truncated, scanned in full, or repaired.
# shellcheck disable=SC3013
cfmgr_log_developer_admit() {
	[ "$cfmgr_log_output" -ef /proc/self/fd/4 ] && cfmgr_log_attached || return 1
	if [ "$cfmgr_log_output_created" = 1 ]; then
		cfmgr_log_header_stage=$cfmgr_log_context/header
		(
			umask 077
			set -C
			: >"$cfmgr_log_header_stage"
		) || return 1
		cfmgr_log_register header || return 1
		printf 'CFMGR-DEVELOPER 1\n' >"$cfmgr_log_header_stage" || return 1
		cfmgr_log_metadata "$cfmgr_log_header_stage" file || return $?
		[ "$cfmgr_log_meta_mode:$cfmgr_log_meta_size" = -rw-------:18 ] || return 1
		exec 3<"$cfmgr_log_header_stage" || return 1
		[ "$cfmgr_log_header_stage" -ef /proc/self/fd/3 ] || return 1
		cfmgr_log_write_fd 18 || return $?
		exec 3<&-
	else
		exec 3</proc/self/fd/4 || return 1
		cfmgr_log_run diagnostic-header /bin/dd || return $?
		[ "$cfmgr_log_output" -ef /proc/self/fd/4 ] && cfmgr_log_attached || return 1
		cfmgr_log_header_check "$cfmgr_probe_stdout" || return 1
		exec 3<&-
	fi
}

cfmgr_log_capture_work() {
	cfmgr_log_config_status=unavailable cfmgr_log_destination_value=-
	if cfmgr_log_read_config; then
		cfmgr_log_config_status=read cfmgr_log_destination_value=$cfmgr_log_config_value
	else
		cfmgr_log_config_code=$?
		[ "$cfmgr_log_config_code" != 3 ] || return 3
		[ "$cfmgr_log_kind" != developer ] || return 1
	fi
	if [ "$cfmgr_log_kind" = developer ] && [ "$cfmgr_log_config_dev" != 1 ]; then
		cfmgr_log_result=disabled
		return 0
	fi
	[ "$cfmgr_log_destination_value" != '!' ] || return 1
	cfmgr_log_run_header || return $?
	cfmgr_log_stage_events "$cfmgr_log_event_text" || return $?
	if [ "$cfmgr_log_kind" = health ] && [ "$cfmgr_log_report_path" != - ]; then
		cfmgr_log_stage_report "$cfmgr_log_report_path" "$cfmgr_log_report_length" || return $?
	fi
	cfmgr_log_lock || return $?
	cfmgr_log_select_destination "$cfmgr_log_destination_value" || return $?
	# Recheck before creating directories, and again before appending. A
	# changed/unsafe destination never redirects a queued developer event.
	if [ "$cfmgr_log_kind" = developer ]; then
		if cfmgr_log_still_enabled; then :; else
			cfmgr_log_check_code=$?
			[ "$cfmgr_log_check_code" != 4 ] || return 0
			return "$cfmgr_log_check_code"
		fi
	fi
	cfmgr_log_walk_destination "$cfmgr_log_effective" create || return $?
	if [ "$cfmgr_log_kind" = developer ]; then
		if cfmgr_log_still_enabled; then :; else
			cfmgr_log_check_code=$?
			[ "$cfmgr_log_check_code" != 4 ] || return 0
			return "$cfmgr_log_check_code"
		fi
	fi
	if [ "$cfmgr_log_kind" = developer ]; then
		cfmgr_log_open_output developer.log append || return $?
		[ "$cfmgr_log_output_created" != 1 ] || cfmgr_log_started_output=1
		cfmgr_log_new_developer=$cfmgr_log_output_created
		cfmgr_log_developer_admit || return $?
		if [ "$cfmgr_log_new_developer" = 1 ]; then
			# Hold the header inode while config rechecks borrow FD3/4, then
			# reopen and compare the exact inode before the next write.
			exec 8>&4 || return 1
			if cfmgr_log_still_enabled; then :; else
				cfmgr_log_check_code=$?
				[ "$cfmgr_log_check_code" != 4 ] || return 0
				return "$cfmgr_log_check_code"
			fi
			cfmgr_log_open_output developer.log append || return $?
			[ "$cfmgr_log_output_created" = 0 ] && [ /proc/self/fd/4 -ef /proc/self/fd/8 ] || return 1
			exec 8>&-
			cfmgr_log_developer_admit || return $?
		fi
	else
		cfmgr_log_health_open || return $?
	fi
	cfmgr_log_started_output=1
	if [ "$cfmgr_log_event_bytes" -gt 0 ]; then
		exec 3<"$cfmgr_log_event_stage" || return 1
		cfmgr_log_write_fd "$cfmgr_log_event_bytes" || return $?
		exec 3<&-
	fi
	if [ "$cfmgr_log_kind" = health ] && [ "$cfmgr_log_report_path" != - ]; then
		exec 3<"$cfmgr_log_report_stage" || return 1
		cfmgr_log_write_fd "$cfmgr_log_report_bytes" || return $?
		exec 3<&-
	fi
	cfmgr_log_result=saved
	case $cfmgr_log_kind:$cfmgr_log_health_result in health:incomplete | health:failed) cfmgr_log_result=incomplete ;; esac
	if [ "$cfmgr_log_kind" = developer ]; then
		cfmgr_log_operation_limit=384 cfmgr_log_file_limit=800
		cfmgr_log_scribe_capture || return $?
		[ "$cfmgr_scribe_incomplete" = 0 ] || cfmgr_log_result=incomplete
		if cfmgr_log_scribe_summary; then :; else
			cfmgr_log_summary_code=$?
			[ "$cfmgr_log_summary_code" != 4 ] || return 0
			return "$cfmgr_log_summary_code"
		fi
	fi
}

# Native status, not any product operation's result, is returned here. Parent
# wrappers capture this typed receipt and preserve their original operation code.
# shellcheck disable=SC2030 # All controller fields intentionally stay in this API subshell.
cfmgr_log_capture() (
	case ${1:-}:$# in developer:2 | health:5) ;; *) exit 2 ;; esac
	cfmgr_log_kind=$1 cfmgr_log_event_text=$2 cfmgr_log_report_path=- cfmgr_log_report_length=0 cfmgr_log_health_result=ok
	if [ "$cfmgr_log_kind" = health ]; then
		cfmgr_log_report_path=$3 cfmgr_log_report_length=$4 cfmgr_log_health_result=$5
		case $cfmgr_log_health_result in ok | incomplete | failed) ;; *) exit 2 ;; esac
		case $cfmgr_log_report_path:$cfmgr_log_report_length:$cfmgr_log_health_result in
		-:0:incomplete | -:0:failed) ;;
		-:* | *:0:*) exit 2 ;;
		esac
	fi
	if [ "${cfmgr_probe_status:-}" = unresolved ] || { [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; }; then
		printf 'CFMGR-LOG-CAPTURE 1 unresolved unavailable - END\n'
		exit 3
	fi
	cfmgr_log_result=unavailable cfmgr_log_config_status=unavailable cfmgr_log_effective_hex=- cfmgr_log_started_output=0
	set +x
	set +v
	exec 0</dev/null 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<&-
	if cfmgr_log_prepare && cfmgr_log_capture_work; then cfmgr_log_code=0; else cfmgr_log_code=$?; fi
	if [ "$cfmgr_log_code" = 3 ]; then
		# No new child, cleanup, unlock or descriptor replacement. The surviving
		# fixed native child retains capture lock/mount/RAM descriptions.
		cfmgr_log_result=unresolved
	else
		if [ "$cfmgr_log_code" != 0 ] && [ "$cfmgr_log_started_output" = 1 ]; then cfmgr_log_result=incomplete; fi
		cfmgr_log_interrupt=0
		if [ -n "${cfmgr_log_context:-}" ] && ! cfmgr_log_cleanup; then
			[ "$cfmgr_log_result" != saved ] || cfmgr_log_result=incomplete
			cfmgr_log_code=1
		fi
	fi
	printf 'CFMGR-LOG-CAPTURE 1 %s %s %s END\n' "$cfmgr_log_result" "$cfmgr_log_config_status" "$cfmgr_log_effective_hex"
	exit "$cfmgr_log_code"
)

# Decode only the bounded printable destination receipt, using shell builtins.
# Health can display its result without importing optional Backup or spawning
# another child after capture has returned.
cfmgr_log_display_path() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 2048 ] && [ "$((${#1} % 2))" = 0 ] || return 1
	case $1 in '' | *[!0-9a-f]*) return 1 ;; esac
	cfmgr_log_display='' cfmgr_log_encoded=$1
	while [ -n "$cfmgr_log_encoded" ]; do
		cfmgr_log_rest=${cfmgr_log_encoded#??}
		cfmgr_log_pair=${cfmgr_log_encoded%"$cfmgr_log_rest"}
		cfmgr_log_number=$((0x$cfmgr_log_pair))
		[ "$cfmgr_log_number" -ge 32 ] && [ "$cfmgr_log_number" -le 126 ] || return 1
		cfmgr_log_octal=$(printf '%03o' "$cfmgr_log_number")
		cfmgr_log_display=$cfmgr_log_display$(printf '%b' "\\$cfmgr_log_octal")
		cfmgr_log_encoded=$cfmgr_log_rest
	done
}

# Explicit one-shot Health runs independently of the developer preference.
# The terminal report is already printed. Only its validated private artifact
# is passed to the independent capture controller; no health budget is reused.
cfmgr_log_health() {
	[ "$#" -eq 3 ] || return 0
	cfmgr_health_capture_done=1
	case $3 in
	ok) cfmgr_log_event status health success "${cfmgr_health_code:-0}" ;;
	incomplete) cfmgr_log_event status health incomplete "${cfmgr_health_code:-0}" ;;
	*) cfmgr_log_event status health failure "${cfmgr_health_code:-1}" ;;
	esac
	if cfmgr_log_response=$(cfmgr_log_capture health "${cfmgr_log_buffer:-}" "$1" "$2" "$3" 2>/dev/null); then cfmgr_log_capture_code=0; else cfmgr_log_capture_code=$?; fi
	if ! cfmgr_log_result "$cfmgr_log_response"; then cfmgr_log_result_kind=unavailable cfmgr_log_result_config=unavailable; fi
	if [ "$cfmgr_log_capture_code" != 0 ] && [ "$cfmgr_log_result_kind" = saved ]; then cfmgr_log_result_kind=incomplete; fi
	case $cfmgr_log_result_kind in
	saved) printf '%s\n' '[CFMGR] capture.saved PASS sanitized report and run information saved' ;;
	incomplete) printf '%s\n' '[CFMGR] capture.saved UNKNOWN diagnostics are incomplete; available captured information was preserved' ;;
	*) printf '%s\n' '[CFMGR] capture.saved SKIP saving was unavailable; the terminal report remains available' ;;
	esac
	if [ "$cfmgr_log_result_config" != read ]; then printf '%s\n' '[CFMGR] capture.config UNKNOWN diagnostic preference could not be read; automatic destination was attempted when safe'; fi
	if [ "${cfmgr_log_result_path:--}" != - ] && cfmgr_log_display_path "$cfmgr_log_result_path"; then printf '[CFMGR] capture.destination %s\n' "$cfmgr_log_display"; fi
	cfmgr_log_buffer='' cfmgr_log_recording=0
	return 0
}

# Positively owned dedicated Scribe snapshots; no source policy mutation.
cfmgr_scribe_uint() {
	[ "$#" -eq 2 ] || return 2
	case $1 in '' | *[!0-9]* | 0[0-9]*) return 1 ;; esac
	[ "${#1}" -le "$2" ]
}

cfmgr_scribe_hash_valid() {
	[ "$#" -eq 1 ] && [ "${#1}" -eq 64 ] || return 1
	case $1 in *[!0-9a-f]*) return 1 ;; esac
}

# The existing full-schema Health authority getter emits this fixed six-row
# envelope. Old positively owned data remains eligible even if the feature or
# its logging setting is currently Off; requested/eligible flags are validated
# but deliberately do not replace the retained ownership fields.
cfmgr_scribe_authority_parse() {
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_scribe_uint "$2" 4 && [ "$2" -le 4096 ] || return 1
	cfmgr_scribe_authority_bytes=$2 cfmgr_scribe_authority_seen=0
	cfmgr_scribe_have_ddns=0 cfmgr_scribe_have_ip_sync=0 cfmgr_scribe_have_cloudflared=0
	cfmgr_scribe_sha_ddns='' cfmgr_scribe_sha_ip_sync='' cfmgr_scribe_sha_cloudflared=''
	{
		IFS= read -r cfmgr_scribe_line && [ "$cfmgr_scribe_line" = 'CFMGR-LOGGING 1' ] || return 1
		cfmgr_scribe_authority_seen=$((${#cfmgr_scribe_line} + 1))
		for cfmgr_scribe_role in ddns ip_sync cloudflared; do
			IFS= read -r cfmgr_scribe_line || return 1
			cfmgr_scribe_authority_seen=$((cfmgr_scribe_authority_seen + ${#cfmgr_scribe_line} + 1))
			IFS=' ' read -r cfmgr_scribe_tag cfmgr_scribe_name cfmgr_scribe_configured cfmgr_scribe_enabled \
				cfmgr_scribe_logconfigured cfmgr_scribe_logenabled cfmgr_scribe_optout cfmgr_scribe_requested \
				cfmgr_scribe_health_eligible cfmgr_scribe_history_generation cfmgr_scribe_history_sha \
				cfmgr_scribe_rule_generation cfmgr_scribe_rule_sha cfmgr_scribe_end cfmgr_scribe_extra <<EOF_SCRIBE_FEATURE
$cfmgr_scribe_line
EOF_SCRIBE_FEATURE
			[ "$cfmgr_scribe_tag:$cfmgr_scribe_name:$cfmgr_scribe_end:$cfmgr_scribe_extra" = "FEATURE:$cfmgr_scribe_role:END:" ] || return 1
			case $cfmgr_scribe_configured:$cfmgr_scribe_enabled:$cfmgr_scribe_logconfigured:$cfmgr_scribe_logenabled:$cfmgr_scribe_optout:$cfmgr_scribe_requested:$cfmgr_scribe_health_eligible in
			[01]:[01]:[01]:[01]:[01]:[01]:[01]) ;;
			*) return 1 ;;
			esac
			case $cfmgr_scribe_history_generation in -) ;; *) cfmgr_scribe_uint "$cfmgr_scribe_history_generation" 20 && [ "$cfmgr_scribe_history_generation" != 0 ] || return 1 ;; esac
			case $cfmgr_scribe_rule_generation in -) ;; *) cfmgr_scribe_uint "$cfmgr_scribe_rule_generation" 20 && [ "$cfmgr_scribe_rule_generation" != 0 ] || return 1 ;; esac
			case $cfmgr_scribe_history_sha in -) ;; *) cfmgr_scribe_hash_valid "$cfmgr_scribe_history_sha" || return 1 ;; esac
			case $cfmgr_scribe_rule_sha in -) ;; *) cfmgr_scribe_hash_valid "$cfmgr_scribe_rule_sha" || return 1 ;; esac
			[ "$cfmgr_scribe_line" = "FEATURE $cfmgr_scribe_role $cfmgr_scribe_configured $cfmgr_scribe_enabled $cfmgr_scribe_logconfigured $cfmgr_scribe_logenabled $cfmgr_scribe_optout $cfmgr_scribe_requested $cfmgr_scribe_health_eligible $cfmgr_scribe_history_generation $cfmgr_scribe_history_sha $cfmgr_scribe_rule_generation $cfmgr_scribe_rule_sha END" ] || return 1
			IFS= read -r cfmgr_scribe_policy_line || return 1
			cfmgr_scribe_authority_seen=$((cfmgr_scribe_authority_seen + ${#cfmgr_scribe_policy_line} + 1))
			IFS=' ' read -r cfmgr_scribe_tag cfmgr_scribe_name cfmgr_scribe_policy cfmgr_scribe_policy_mode \
				cfmgr_scribe_policy_size cfmgr_scribe_policy_rotate cfmgr_scribe_policy_age cfmgr_scribe_policy_end cfmgr_scribe_extra <<EOF_SCRIBE_POLICY
$cfmgr_scribe_policy_line
EOF_SCRIBE_POLICY
			[ "$cfmgr_scribe_tag:$cfmgr_scribe_name" = "SAVED:$cfmgr_scribe_role" ] || return 1
			case $cfmgr_scribe_policy in
			NONE) [ "$cfmgr_scribe_policy_line" = "SAVED $cfmgr_scribe_role NONE" ] || return 1 ;;
			POLICY)
				case $cfmgr_scribe_role:$cfmgr_scribe_policy_mode in
				ddns:native | ip_sync:native | cloudflared:size | cloudflared:daily | cloudflared:weekly | cloudflared:monthly) ;;
				*) return 1 ;;
				esac
				for cfmgr_scribe_number in "$cfmgr_scribe_policy_size" "$cfmgr_scribe_policy_rotate" "$cfmgr_scribe_policy_age"; do
					case $cfmgr_scribe_number in -) ;; *) cfmgr_scribe_uint "$cfmgr_scribe_number" 20 || return 1 ;; esac
				done
				[ "$cfmgr_scribe_policy_line" = "SAVED $cfmgr_scribe_role POLICY $cfmgr_scribe_policy_mode $cfmgr_scribe_policy_size $cfmgr_scribe_policy_rotate $cfmgr_scribe_policy_age END" ] || return 1
				;;
			*) return 1 ;;
			esac
			cfmgr_scribe_owned=0
			if [ "$cfmgr_scribe_history_generation" != - ] && [ "$cfmgr_scribe_rule_generation" != - ] &&
				[ "$cfmgr_scribe_rule_sha" != - ] && [ "$cfmgr_scribe_policy" = POLICY ]; then cfmgr_scribe_owned=1; fi
			case $cfmgr_scribe_role in
			ddns) cfmgr_scribe_have_ddns=$cfmgr_scribe_owned cfmgr_scribe_sha_ddns=$cfmgr_scribe_rule_sha ;;
			ip_sync) cfmgr_scribe_have_ip_sync=$cfmgr_scribe_owned cfmgr_scribe_sha_ip_sync=$cfmgr_scribe_rule_sha ;;
			cloudflared) cfmgr_scribe_have_cloudflared=$cfmgr_scribe_owned cfmgr_scribe_sha_cloudflared=$cfmgr_scribe_rule_sha ;;
			esac
		done
		IFS= read -r cfmgr_scribe_line && [ "$cfmgr_scribe_line" = 'END 6 END' ] || return 1
		cfmgr_scribe_authority_seen=$((cfmgr_scribe_authority_seen + ${#cfmgr_scribe_line} + 1))
		[ "$cfmgr_scribe_authority_seen" = "$cfmgr_scribe_authority_bytes" ] || return 1
		cfmgr_scribe_line=''
		if IFS= read -r cfmgr_scribe_line; then return 1; fi
		[ -z "$cfmgr_scribe_line" ] || return 1
	} <"$1"
}

# A finite 32-bit-safe source extent. This guard is applied only to the copied
# Scribe input; diagnostic destination retention and developer.log are unbounded.
cfmgr_scribe_source_size_valid() {
	[ "$#" -eq 1 ] && cfmgr_scribe_uint "$1" 10 || return 1
	[ "${#1}" -eq 10 ] || return 0
	cfmgr_scribe_size_first=${1%?????????} cfmgr_scribe_size_tail=${1#?}
	case $cfmgr_scribe_size_first in
	1) return 0 ;;
	2) [ "$cfmgr_scribe_size_tail" -le 147483647 ] ;;
	*) return 1 ;;
	esac
}

# Source mount pins use FD8, independent of destination FD6/7. These direct,
# fixed observations match the existing Backup attachment callback and cannot
# recursively invoke the single-child supervisor.
# shellcheck disable=SC3013
cfmgr_scribe_source_attached() {
	cfmgr_log_attached source
}

cfmgr_scribe_run() {
	cfmgr_scribe_source_attached || return 1
	if cfmgr_log_run "$@"; then cfmgr_scribe_run_code=0; else cfmgr_scribe_run_code=$?; fi
	[ "$cfmgr_scribe_run_code" != 3 ] || return 3
	cfmgr_scribe_source_attached || return 1
	return "$cfmgr_scribe_run_code"
}

# Resolve /opt's actual backing mount without modifying destination mount state.
cfmgr_scribe_pin_source() {
	cfmgr_log_run diagnostic-realpath /usr/bin/readlink /opt || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	cfmgr_scribe_opt=$cfmgr_log_line_value
	cfmgr_log_path_valid "$cfmgr_scribe_opt" || return 1
	[ -d "$cfmgr_scribe_opt" ] && [ ! -L "$cfmgr_scribe_opt" ] || return 1
	cfmgr_log_run diagnostic-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_scribe_opt" || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	cfmgr_scribe_mount_snapshot=$cfmgr_log_line_value
	IFS='	' read -r cfmgr_scribe_mount_id cfmgr_scribe_mount_parent cfmgr_scribe_mount_device \
		cfmgr_scribe_mount_root cfmgr_scribe_mount cfmgr_scribe_mount_fs cfmgr_scribe_mount_source \
		cfmgr_scribe_mount_options cfmgr_scribe_mount_super cfmgr_scribe_mount_extra <<EOF_SCRIBE_MOUNT
$cfmgr_scribe_mount_snapshot
EOF_SCRIBE_MOUNT
	[ -z "$cfmgr_scribe_mount_extra" ] && [ "$cfmgr_scribe_mount_root" = / ] || return 1
	case $cfmgr_scribe_mount in /tmp/mnt/?* | /mnt/?*) ;; *) return 1 ;; esac
	cfmgr_log_path_valid "$cfmgr_scribe_mount" && cfmgr_log_path_on_mount "$cfmgr_scribe_opt" "$cfmgr_scribe_mount" || return 1
	[ -d "$cfmgr_scribe_mount" ] && [ ! -L "$cfmgr_scribe_mount" ] && [ -b "$cfmgr_scribe_mount_source" ] || return 1
	exec 8<"$cfmgr_scribe_mount" || return 1
	cfmgr_scribe_pinned=1
	cfmgr_scribe_source_attached
}

# Check each directory component from the admitted mount to the selected fixed
# subtree. Nothing is created or chmodded. Mount IDs/realpaths are rechecked.
cfmgr_scribe_admit_directory() {
	[ "$#" -eq 1 ] && cfmgr_log_path_on_mount "$1" "$cfmgr_scribe_mount" || return 1
	cfmgr_scribe_walk=$cfmgr_scribe_mount
	cfmgr_log_metadata "$cfmgr_scribe_walk" directory || return $?
	[ "$1" != "$cfmgr_scribe_mount" ] || {
		cfmgr_scribe_source_attached
		return $?
	}
	cfmgr_scribe_remaining=${1#"$cfmgr_scribe_mount"/}
	while [ -n "$cfmgr_scribe_remaining" ]; do
		cfmgr_scribe_part=${cfmgr_scribe_remaining%%/*}
		case $cfmgr_scribe_remaining in */*) cfmgr_scribe_remaining=${cfmgr_scribe_remaining#*/} ;; *) cfmgr_scribe_remaining='' ;; esac
		cfmgr_scribe_walk=$cfmgr_scribe_walk/$cfmgr_scribe_part
		cfmgr_scribe_source_attached || return 1
		[ -d "$cfmgr_scribe_walk" ] && [ ! -L "$cfmgr_scribe_walk" ] || return 1
		[ "$(/usr/bin/readlink -f "$cfmgr_scribe_walk")" = "$cfmgr_scribe_walk" ] || return 1
		[ "$(cfmgr_storage_mountinfo /usr/bin/awk "$cfmgr_scribe_walk" /proc/self/mountinfo)" = "$cfmgr_scribe_mount_snapshot" ] || return 1
		cfmgr_log_metadata "$cfmgr_scribe_walk" directory || return $?
	done
	cfmgr_scribe_source_attached
}

cfmgr_scribe_authority() {
	[ -f "${cfmgr_log_config_stage:-}" ] && [ ! -L "$cfmgr_log_config_stage" ] || return 1
	cfmgr_scribe_authority_config=$cfmgr_log_config_stage
	cfmgr_scribe_authority_config_bytes=$cfmgr_log_config_bytes
	cfmgr_log_metadata "$cfmgr_log_config_stage" file || return $?
	case $cfmgr_log_meta_size in '' | *[!0-9]* | 0*) return 1 ;; esac
	[ "$cfmgr_log_meta_size" -le 65536 ] || return 1
	cfmgr_log_run diagnostic-scribe-authority /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_source/modules/backup.sh" \
		"$cfmgr_log_config_stage" "$cfmgr_log_meta_size" || return $?
	cfmgr_scribe_authority_file=$cfmgr_probe_stdout
	cfmgr_log_metadata "$cfmgr_scribe_authority_file" file || return $?
	cfmgr_scribe_authority_parse "$cfmgr_scribe_authority_file" "$cfmgr_log_meta_size"
}

# Open only a path under the held Entware mount. The caller supplies a fixed
# path constructed from a positively owned role and never passes config text.
# shellcheck disable=SC3013
cfmgr_scribe_open_source() {
	[ "$#" -eq 1 ] && cfmgr_log_path_on_mount "$1" "$cfmgr_scribe_mount" || return 1
	cfmgr_scribe_source_attached || return 1
	[ -f "$1" ] && [ ! -L "$1" ] || return 1
	[ "$(/usr/bin/readlink -f "$1")" = "$1" ] || return 1
	[ "$(cfmgr_storage_mountinfo /usr/bin/awk "$1" /proc/self/mountinfo)" = "$cfmgr_scribe_mount_snapshot" ] || return 1
	cfmgr_log_metadata "$1" file || return $?
	cfmgr_scribe_open_inode=$cfmgr_log_meta_inode cfmgr_scribe_open_bytes=$cfmgr_log_meta_size cfmgr_scribe_open_path=$1
	exec 3<"$1" || return 1
	[ "$1" -ef /proc/self/fd/3 ] && cfmgr_log_fd_mount_ok 3 "$cfmgr_scribe_mount_id" && cfmgr_scribe_source_attached
}

# An owned rule must match the exact saved digest, not merely an expected name.
# The 64KiB cap bounds digest work. Rotation policy and all source files remain
# untouched; no external logging component is enabled or repaired.
cfmgr_scribe_rule_owned() {
	[ "$#" -eq 2 ] && cfmgr_scribe_hash_valid "$2" || return 1
	case $1 in ddns | cloudflared) cfmgr_scribe_rule_name=cfmgr-$1 ;; ip_sync) cfmgr_scribe_rule_name=cfmgr-ip-sync ;; *) return 2 ;; esac
	cfmgr_scribe_rule_expected=$2
	cfmgr_scribe_open_source "$cfmgr_scribe_opt/etc/logrotate.d/$cfmgr_scribe_rule_name" || return $?
	cfmgr_scribe_uint "$cfmgr_scribe_open_bytes" 5 && [ "$cfmgr_scribe_open_bytes" -le 65536 ] || return 1
	cfmgr_scribe_rule_inode=$cfmgr_scribe_open_inode cfmgr_scribe_rule_size=$cfmgr_scribe_open_bytes
	cfmgr_scribe_run diagnostic-digest /usr/sbin/openssl || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_scribe_digest cfmgr_scribe_digest_operand cfmgr_scribe_digest_extra <<EOF_SCRIBE_DIGEST
$cfmgr_log_line_value
EOF_SCRIBE_DIGEST
	[ "$cfmgr_log_line_value" = "$cfmgr_scribe_digest *stdin" ] &&
		[ "$cfmgr_scribe_digest_operand:$cfmgr_scribe_digest_extra" = '*stdin:' ] &&
		[ "$cfmgr_scribe_digest" = "$cfmgr_scribe_rule_expected" ] || return 1
	[ "$cfmgr_scribe_open_path" -ef /proc/self/fd/3 ] || return 1
	cfmgr_log_metadata "$cfmgr_scribe_open_path" file || return $?
	[ "$cfmgr_log_meta_inode:$cfmgr_log_meta_size" = "$cfmgr_scribe_rule_inode:$cfmgr_scribe_rule_size" ] && cfmgr_scribe_source_attached
}

cfmgr_scribe_count_file() {
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	case $2 in 24576 | 65536) ;; *) return 2 ;; esac
	exec 3<"$1" || return 1
	# This stage is already in the private RAM context. Its supervisor checks
	# that context and destination; source authority is rechecked at publication.
	cfmgr_log_run diagnostic-count /usr/bin/wc || return $?
	cfmgr_log_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_scribe_count cfmgr_scribe_count_extra <<EOF_SCRIBE_COUNT
$cfmgr_log_line_value
EOF_SCRIBE_COUNT
	[ -z "$cfmgr_scribe_count_extra" ] && cfmgr_scribe_uint "$cfmgr_scribe_count" 5 && [ "$cfmgr_scribe_count" -le "$2" ]
}

# Validate only the typed sanitized frame/footer. This routine never emits raw
# source, filenames, secrets or arbitrary child stdout into diagnostic output.
cfmgr_scribe_sanitized_status() {
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_scribe_uint "$2" 5 && [ "$2" -le 65536 ] || return 1
	cfmgr_scribe_expected_bytes=$2 cfmgr_scribe_seen_bytes=0
	cfmgr_scribe_row_count=0 cfmgr_scribe_last=''
	{
		IFS= read -r cfmgr_scribe_line && [ "$cfmgr_scribe_line" = 'CFMGR-SANITIZED-LOG 1' ] || return 1
		cfmgr_scribe_seen_bytes=$((${#cfmgr_scribe_line} + 1))
		while IFS= read -r cfmgr_scribe_line; do
			cfmgr_scribe_seen_bytes=$((cfmgr_scribe_seen_bytes + ${#cfmgr_scribe_line} + 1))
			cfmgr_scribe_row_count=$((cfmgr_scribe_row_count + 1))
			[ "$cfmgr_scribe_row_count" -le 4097 ] && [ "${#cfmgr_scribe_line}" -le 4096 ] || return 1
			case $cfmgr_scribe_line in *[!\ -~]*) return 1 ;; esac
			cfmgr_scribe_last=$cfmgr_scribe_line
		done
		[ -z "$cfmgr_scribe_line" ] || return 1
	} <"$1"
	IFS=' ' read -r cfmgr_scribe_end cfmgr_scribe_known cfmgr_scribe_redacted cfmgr_scribe_was_incomplete cfmgr_scribe_more <<EOF_SCRIBE_END
$cfmgr_scribe_last
EOF_SCRIBE_END
	[ "$cfmgr_scribe_end:$cfmgr_scribe_more" = END: ] || return 1
	cfmgr_scribe_uint "$cfmgr_scribe_known" 4 && cfmgr_scribe_uint "$cfmgr_scribe_redacted" 4 || return 1
	case $cfmgr_scribe_was_incomplete in 0 | 1) ;; *) return 1 ;; esac
	[ "$cfmgr_scribe_last" = "END $cfmgr_scribe_known $cfmgr_scribe_redacted $cfmgr_scribe_was_incomplete" ] &&
		[ "$cfmgr_scribe_seen_bytes" = "$cfmgr_scribe_expected_bytes" ] &&
		[ "$cfmgr_scribe_row_count" -eq "$((cfmgr_scribe_known + cfmgr_scribe_redacted + 1))" ]
}

cfmgr_scribe_output_open() {
	[ "$#" -eq 2 ] || return 2
	case $1 in ddns | ip_sync | cloudflared) ;; *) return 2 ;; esac
	case $2 in current) ;; *) cfmgr_scribe_uint "$2" 10 && [ "$2" != 0 ] || return 2 ;; esac
	cfmgr_scribe_sequence=1
	while [ "$cfmgr_scribe_sequence" -le 16 ]; do
		cfmgr_scribe_output_name=scribe-$cfmgr_log_boot-$cfmgr_log_start-$cfmgr_log_pid-$1-$2-$cfmgr_scribe_sequence.log
		cfmgr_log_attached || return 1
		if [ -e "$cfmgr_log_walk/$cfmgr_scribe_output_name" ] || [ -L "$cfmgr_log_walk/$cfmgr_scribe_output_name" ]; then
			cfmgr_scribe_sequence=$((cfmgr_scribe_sequence + 1))
			continue
		fi
		if cfmgr_log_open_output "$cfmgr_scribe_output_name" exclusive; then return 0; else cfmgr_scribe_open_code=$?; fi
		[ "$cfmgr_scribe_open_code" != 3 ] || return 3
		[ "${cfmgr_log_output_created:-0}" = 0 ] || return "$cfmgr_scribe_open_code"
		if [ -e "$cfmgr_log_walk/$cfmgr_scribe_output_name" ] || [ -L "$cfmgr_log_walk/$cfmgr_scribe_output_name" ]; then
			cfmgr_scribe_sequence=$((cfmgr_scribe_sequence + 1))
			continue
		fi
		return "$cfmgr_scribe_open_code"
	done
	return 1
}

# The full-schema authority is bound to exact private config bytes, including
# manual edits that do not increment generation. The compare worker inherits
# both held files and keeps lock FD0; no configuration bytes are emitted.
# shellcheck disable=SC3013
cfmgr_scribe_authority_unchanged() {
	cfmgr_scribe_live_config=$cfmgr_source/config
	[ -f "$cfmgr_scribe_authority_config" ] && [ ! -L "$cfmgr_scribe_authority_config" ] &&
		[ -f "$cfmgr_scribe_live_config" ] && [ ! -L "$cfmgr_scribe_live_config" ] || return 1
	cfmgr_log_metadata "$cfmgr_scribe_live_config" file || return $?
	[ "$cfmgr_log_meta_mode" = -rw------- ] &&
		[ "$cfmgr_log_meta_size" = "$cfmgr_scribe_authority_config_bytes" ] || return 1
	cfmgr_scribe_fresh_inode=$cfmgr_log_meta_inode
	exec 3<"$cfmgr_scribe_authority_config" 4<"$cfmgr_scribe_live_config" || return 1
	[ "$cfmgr_scribe_authority_config" -ef /proc/self/fd/3 ] &&
		[ "$cfmgr_scribe_live_config" -ef /proc/self/fd/4 ] || return 1
	if cfmgr_log_run diagnostic-compare /usr/bin/cmp; then cfmgr_scribe_compare_code=0; else cfmgr_scribe_compare_code=$?; fi
	[ "$cfmgr_scribe_compare_code" != 3 ] || return 3
	if [ "$cfmgr_scribe_compare_code" = 0 ]; then
		cfmgr_log_metadata "$cfmgr_scribe_live_config" file || return $?
		[ "$cfmgr_log_meta_mode:$cfmgr_log_meta_inode:$cfmgr_log_meta_size" = "-rw-------:$cfmgr_scribe_fresh_inode:$cfmgr_scribe_authority_config_bytes" ] &&
			[ "$cfmgr_scribe_live_config" -ef /proc/self/fd/4 ] && cfmgr_log_attached || return 1
	fi
	exec 3<&- 4<&-
	return "$cfmgr_scribe_compare_code"
}

# shellcheck disable=SC2031 # This helper runs inside the same isolated capture controller.
cfmgr_scribe_save_stage() {
	# Exact equality to the admitted developer-On authority proves the same
	# destination and ownership. Any change stops publication without guessing
	# whether it was an Off edit; the final summary reads its own fresh state.
	if cfmgr_scribe_authority_unchanged; then :; else
		cfmgr_scribe_compare_code=$?
		[ "$cfmgr_scribe_compare_code" != 3 ] || return 3
		cfmgr_scribe_stop=1
		return 1
	fi
	cfmgr_scribe_source_attached || return 1
	# Config bytes do not establish that the live rule stayed unchanged. Check
	# the original saved role-specific rule digest immediately before writing.
	cfmgr_scribe_role_values "$cfmgr_scribe_snapshot_role" || return 1
	if cfmgr_scribe_rule_owned "$cfmgr_scribe_snapshot_role" "$cfmgr_scribe_role_sha"; then :; else
		cfmgr_scribe_rule_check_code=$?
		[ "$cfmgr_scribe_rule_check_code" != 3 ] || return 3
		case $cfmgr_scribe_snapshot_role in
		ddns) cfmgr_scribe_ready_ddns=0 ;;
		ip_sync) cfmgr_scribe_ready_ip_sync=0 ;;
		cloudflared) cfmgr_scribe_ready_cloudflared=0 ;;
		esac
		return 1
	fi
	cfmgr_scribe_output_open "$cfmgr_scribe_snapshot_role" "$cfmgr_scribe_snapshot_index" || return $?
	exec 3<"$cfmgr_scribe_stage" || return 1
	cfmgr_log_write_fd "$cfmgr_scribe_stage_bytes" || return $?
	exec 3<&- 4>&-
}

cfmgr_scribe_snapshot() {
	[ "$#" -eq 2 ] || return 2
	cfmgr_scribe_snapshot_role=$1 cfmgr_scribe_snapshot_index=$2
	case $1 in ddns | cloudflared) cfmgr_scribe_filename=$1.log ;; ip_sync) cfmgr_scribe_filename=ip-sync.log ;; *) return 2 ;; esac
	case $2 in current) ;; *)
		cfmgr_scribe_uint "$2" 10 && [ "$2" != 0 ] || return 2
		cfmgr_scribe_filename=$cfmgr_scribe_filename.$2
		;;
	esac
	cfmgr_scribe_file=$cfmgr_scribe_opt/var/log/$cfmgr_scribe_filename
	cfmgr_scribe_source_attached || return 1
	if [ ! -e "$cfmgr_scribe_file" ] && [ ! -L "$cfmgr_scribe_file" ]; then
		# A stale mountpoint looks absent as well; do not report missing unless
		# the same pinned source still backs the namespace at classification.
		cfmgr_scribe_source_attached || return 1
		cfmgr_scribe_missing=$((cfmgr_scribe_missing + 1))
		return 0
	fi
	if [ "$cfmgr_scribe_attempted" -ge 32 ]; then
		cfmgr_scribe_truncated=1
		return 0
	fi
	cfmgr_scribe_attempted=$((cfmgr_scribe_attempted + 1))
	cfmgr_scribe_open_source "$cfmgr_scribe_file" || return $?
	cfmgr_scribe_source_size_valid "$cfmgr_scribe_open_bytes" || return 1
	cfmgr_scribe_original_inode=$cfmgr_scribe_open_inode cfmgr_scribe_original_bytes=$cfmgr_scribe_open_bytes
	cfmgr_scribe_skip=0 cfmgr_scribe_excerpt=0
	if [ "$cfmgr_scribe_original_bytes" -gt 24576 ]; then
		cfmgr_scribe_skip=$(((cfmgr_scribe_original_bytes - 24576 + 1023) / 1024))
		cfmgr_scribe_excerpt=1
	fi
	cfmgr_scribe_run diagnostic-source /bin/dd "$cfmgr_scribe_skip" || return $?
	cfmgr_scribe_raw=$cfmgr_probe_stdout
	[ "$cfmgr_scribe_file" -ef /proc/self/fd/3 ] || return 1
	cfmgr_log_metadata "$cfmgr_scribe_file" file || return $?
	[ "$cfmgr_log_meta_inode:$cfmgr_log_meta_size" = "$cfmgr_scribe_original_inode:$cfmgr_scribe_original_bytes" ] || return 1
	cfmgr_scribe_source_attached || return 1
	cfmgr_scribe_count_file "$cfmgr_scribe_raw" 24576 || return $?
	cfmgr_scribe_raw_bytes=$cfmgr_scribe_count
	[ "$cfmgr_scribe_raw_bytes" = "$((cfmgr_scribe_original_bytes - cfmgr_scribe_skip * 1024))" ] || return 1
	exec 3<"$cfmgr_scribe_raw" || return 1
	cfmgr_log_run diagnostic-frame /usr/bin/awk "$cfmgr_source/modules/lib/logging.sh" "$cfmgr_scribe_raw_bytes" "$cfmgr_scribe_excerpt" || return $?
	cfmgr_scribe_frame=$cfmgr_probe_stdout
	cfmgr_scribe_count_file "$cfmgr_scribe_frame" 65536 || return $?
	cfmgr_scribe_frame_bytes=$cfmgr_scribe_count
	[ "$cfmgr_scribe_frame_bytes" -gt 0 ] || return 1
	exec 3<"$cfmgr_scribe_frame" || return 1
	cfmgr_log_run diagnostic-sanitize /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/lib/logging.sh" "$cfmgr_scribe_frame_bytes" "$cfmgr_scribe_excerpt" "$cfmgr_scribe_snapshot_role" || return $?
	cfmgr_scribe_sanitized=$cfmgr_probe_stdout
	cfmgr_scribe_count_file "$cfmgr_scribe_sanitized" 65536 || return $?
	cfmgr_scribe_sanitized_bytes=$cfmgr_scribe_count
	[ "$cfmgr_scribe_sanitized_bytes" -gt 0 ] && cfmgr_scribe_sanitized_status "$cfmgr_scribe_sanitized" "$cfmgr_scribe_sanitized_bytes" || return 1
	# Write only the already sanitized result into an owned staging file, then
	# make one bounded destination append after fresh developer confirmation.
	cfmgr_scribe_stage=$cfmgr_log_context/scribe.$cfmgr_scribe_attempted.stage
	(
		umask 077
		set -C
		: >"$cfmgr_scribe_stage"
	) || return 1
	cfmgr_log_register "${cfmgr_scribe_stage##*/}" || return 1
	printf 'CFMGR-SCRIBE 1 %s %s %s %s END\n' "$cfmgr_scribe_snapshot_role" "$cfmgr_scribe_snapshot_index" "$cfmgr_scribe_excerpt" "$cfmgr_scribe_was_incomplete" >"$cfmgr_scribe_stage" || return 1
	exec 3<"$cfmgr_scribe_sanitized" 4>>"$cfmgr_scribe_stage" || return 1
	cfmgr_log_output=$cfmgr_scribe_stage
	cfmgr_log_write_fd "$cfmgr_scribe_sanitized_bytes" || return $?
	exec 3<&- 4>&-
	cfmgr_log_metadata "$cfmgr_scribe_stage" file || return $?
	cfmgr_scribe_stage_bytes=$cfmgr_log_meta_size
	cfmgr_scribe_uint "$cfmgr_scribe_stage_bytes" 5 && [ "$cfmgr_scribe_stage_bytes" -le 65792 ] || return 1
	cfmgr_scribe_source_attached || return 1
	cfmgr_scribe_save_stage || return $?
	cfmgr_scribe_saved=$((cfmgr_scribe_saved + 1))
	[ "$cfmgr_scribe_was_incomplete" = 0 ] || cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
}

cfmgr_scribe_role_values() {
	[ "$#" -eq 1 ] || return 2
	case $1 in
	ddns) cfmgr_scribe_role_owned=$cfmgr_scribe_have_ddns cfmgr_scribe_role_sha=$cfmgr_scribe_sha_ddns ;;
	ip_sync) cfmgr_scribe_role_owned=$cfmgr_scribe_have_ip_sync cfmgr_scribe_role_sha=$cfmgr_scribe_sha_ip_sync ;;
	cloudflared) cfmgr_scribe_role_owned=$cfmgr_scribe_have_cloudflared cfmgr_scribe_role_sha=$cfmgr_scribe_sha_cloudflared ;;
	*) return 2 ;;
	esac
}

cfmgr_scribe_role_ready() {
	[ "$#" -eq 1 ] || return 2
	case $1 in
	ddns) [ "$cfmgr_scribe_ready_ddns" = 1 ] ;;
	ip_sync) [ "$cfmgr_scribe_ready_ip_sync" = 1 ] ;;
	cloudflared) [ "$cfmgr_scribe_ready_cloudflared" = 1 ] ;;
	*) return 2 ;;
	esac
}

cfmgr_scribe_accept_snapshot() {
	if cfmgr_scribe_snapshot "$1" "$2"; then return 0; else cfmgr_scribe_snapshot_code=$?; fi
	[ "$cfmgr_scribe_snapshot_code" != 3 ] || return 3
	cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
	return 0
}

# Enumerate fixed current files first and only then retained numeric siblings.
# The listing is parsed before any snapshot work so FD0 remains the capture
# lock when a fixed worker runs. Every extra candidate beyond 32 is explicit.
cfmgr_log_scribe_capture() {
	cfmgr_scribe_saved=0 cfmgr_scribe_missing=0 cfmgr_scribe_incomplete=0 cfmgr_scribe_unowned=0
	cfmgr_scribe_attempted=0 cfmgr_scribe_truncated=0 cfmgr_scribe_stop=0 cfmgr_scribe_pinned=0
	cfmgr_scribe_ready_ddns=0 cfmgr_scribe_ready_ip_sync=0 cfmgr_scribe_ready_cloudflared=0
	exec 3<&- 4>&- 8<&-
	if cfmgr_scribe_authority; then :; else
		cfmgr_scribe_main_code=$?
		[ "$cfmgr_scribe_main_code" != 3 ] || return 3
		cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
		return 0
	fi
	# No retained owned logging authorities is a supported unowned condition. It must
	# not require an installed Scribe directory or manufacture source logs.
	if [ "$cfmgr_scribe_have_ddns:$cfmgr_scribe_have_ip_sync:$cfmgr_scribe_have_cloudflared" = 0:0:0 ]; then
		cfmgr_scribe_unowned=3
		return 0
	fi
	if cfmgr_scribe_pin_source; then :; else
		cfmgr_scribe_main_code=$?
		[ "$cfmgr_scribe_main_code" != 3 ] || return 3
		cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
		exec 8<&-
		return 0
	fi
	cfmgr_scribe_logs=$cfmgr_scribe_opt/var/log
	cfmgr_scribe_rules=$cfmgr_scribe_opt/etc/logrotate.d
	if cfmgr_scribe_admit_directory "$cfmgr_scribe_rules"; then :; else
		cfmgr_scribe_main_code=$?
		[ "$cfmgr_scribe_main_code" != 3 ] || return 3
		cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
		exec 8<&-
		return 0
	fi
	for cfmgr_scribe_candidate_role in ddns ip_sync cloudflared; do
		cfmgr_scribe_role_values "$cfmgr_scribe_candidate_role" || return 1
		if [ "$cfmgr_scribe_role_owned" != 1 ]; then
			cfmgr_scribe_unowned=$((cfmgr_scribe_unowned + 1))
			continue
		fi
		if cfmgr_scribe_rule_owned "$cfmgr_scribe_candidate_role" "$cfmgr_scribe_role_sha"; then
			case $cfmgr_scribe_candidate_role in
			ddns) cfmgr_scribe_ready_ddns=1 ;;
			ip_sync) cfmgr_scribe_ready_ip_sync=1 ;;
			cloudflared) cfmgr_scribe_ready_cloudflared=1 ;;
			esac
		else
			cfmgr_scribe_main_code=$?
			[ "$cfmgr_scribe_main_code" != 3 ] || return 3
			cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
		fi
	done
	if cfmgr_scribe_admit_directory "$cfmgr_scribe_logs"; then :; else
		cfmgr_scribe_main_code=$?
		[ "$cfmgr_scribe_main_code" != 3 ] || return 3
		if [ ! -e "$cfmgr_scribe_logs" ] && [ ! -L "$cfmgr_scribe_logs" ] && cfmgr_scribe_source_attached; then
			for cfmgr_scribe_candidate_role in ddns ip_sync cloudflared; do
				cfmgr_scribe_role_ready "$cfmgr_scribe_candidate_role" || continue
				cfmgr_scribe_missing=$((cfmgr_scribe_missing + 1))
			done
		else cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1)); fi
		exec 8<&-
		return 0
	fi
	if ! exec 3<"$cfmgr_scribe_logs"; then
		cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
		exec 8<&-
		return 0
	fi
	if [ ! -L "$cfmgr_scribe_logs" ] && [ "$cfmgr_scribe_logs" -ef /proc/self/fd/3 ] &&
		cfmgr_log_fd_mount_ok 3 "$cfmgr_scribe_mount_id" && cfmgr_scribe_run diagnostic-list /bin/ls; then
		if [ ! -L "$cfmgr_scribe_logs" ] && [ "$cfmgr_scribe_logs" -ef /proc/self/fd/3 ]; then
			cfmgr_scribe_listing=$cfmgr_probe_stdout cfmgr_scribe_listing_ok=1
		else cfmgr_scribe_listing_ok=0 cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1)); fi
	else
		cfmgr_scribe_main_code=$?
		[ "$cfmgr_scribe_main_code" != 3 ] || return 3
		cfmgr_scribe_listing_ok=0 cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
	fi
	cfmgr_scribe_retained='' cfmgr_scribe_retained_count=0
	if [ "$cfmgr_scribe_listing_ok" = 1 ]; then
		while IFS= read -r cfmgr_scribe_name; do
			case $cfmgr_scribe_name in
			ddns.log.*) cfmgr_scribe_list_role=ddns cfmgr_scribe_list_index=${cfmgr_scribe_name#ddns.log.} ;;
			ip-sync.log.*) cfmgr_scribe_list_role=ip_sync cfmgr_scribe_list_index=${cfmgr_scribe_name#ip-sync.log.} ;;
			cloudflared.log.*) cfmgr_scribe_list_role=cloudflared cfmgr_scribe_list_index=${cfmgr_scribe_name#cloudflared.log.} ;;
			*) continue ;;
			esac
			cfmgr_scribe_role_ready "$cfmgr_scribe_list_role" || continue
			if ! cfmgr_scribe_uint "$cfmgr_scribe_list_index" 10 || [ "$cfmgr_scribe_list_index" = 0 ]; then
				cfmgr_scribe_truncated=1
				continue
			fi
			if [ "$cfmgr_scribe_retained_count" -ge 32 ]; then
				cfmgr_scribe_truncated=1
				continue
			fi
			cfmgr_scribe_retained_count=$((cfmgr_scribe_retained_count + 1))
			cfmgr_scribe_retained="$cfmgr_scribe_retained
$cfmgr_scribe_list_role $cfmgr_scribe_list_index"
		done <"$cfmgr_scribe_listing"
	fi
	for cfmgr_scribe_candidate_role in ddns ip_sync cloudflared; do
		cfmgr_scribe_role_ready "$cfmgr_scribe_candidate_role" || continue
		cfmgr_scribe_accept_snapshot "$cfmgr_scribe_candidate_role" current || return $?
		[ "$cfmgr_scribe_stop" != 1 ] || break
	done
	if [ "$cfmgr_scribe_stop" != 1 ]; then
		# Here-document input is read fully before any snapshot call, to retain
		# FD0's capture lock while each external phase executes.
		cfmgr_scribe_pending=$cfmgr_scribe_retained
		while [ -n "$cfmgr_scribe_pending" ]; do
			case $cfmgr_scribe_pending in '
'*)
				cfmgr_scribe_pending=${cfmgr_scribe_pending#?}
				continue
				;;
			esac
			cfmgr_scribe_entry=${cfmgr_scribe_pending%%'
'*}
			case $cfmgr_scribe_pending in *'
'*) cfmgr_scribe_pending=${cfmgr_scribe_pending#*'
'} ;; *) cfmgr_scribe_pending='' ;; esac
			cfmgr_scribe_list_role=${cfmgr_scribe_entry%% *} cfmgr_scribe_list_index=${cfmgr_scribe_entry#* }
			cfmgr_scribe_accept_snapshot "$cfmgr_scribe_list_role" "$cfmgr_scribe_list_index" || return $?
			[ "$cfmgr_scribe_stop" != 1 ] || break
		done
	fi
	[ "$cfmgr_scribe_truncated" = 0 ] || cfmgr_scribe_incomplete=$((cfmgr_scribe_incomplete + 1))
	exec 3<&- 4>&- 8<&-
	return 0
}

# Source absence and unavailable ownership are different diagnostic outcomes.
# This bounded summary is appended only after a fresh On/destination check.
cfmgr_log_scribe_summary() {
	cfmgr_log_still_enabled || return $?
	cfmgr_log_summary="CFMGR-SCRIBE-RESULT 1 $cfmgr_scribe_saved $cfmgr_scribe_missing $cfmgr_scribe_incomplete $cfmgr_scribe_unowned END
"
	cfmgr_log_summary_stage=$cfmgr_log_context/scribe-summary
	(
		umask 077
		set -C
		printf '%s' "$cfmgr_log_summary" >"$cfmgr_log_summary_stage"
	) || return 1
	cfmgr_log_register scribe-summary || return 1
	cfmgr_log_open_output developer.log append || return $?
	cfmgr_log_developer_admit || return $?
	exec 3<"$cfmgr_log_summary_stage" || return 1
	cfmgr_log_write_fd "${#cfmgr_log_summary}" || return $?
	exec 3<&- 4>&-
}
