#!/bin/sh
# Source-inert offline native admission and fixed secure HTTPS HEAD primitive.
# Caller admits tools, root-protected CA and fresh private RAM context, and
# supplies cfmgr_native_action MODE OPERANDS with bounded direct-child probes.
# Callback exports cfmgr_native_output/error/exit; return3 retains ownership.
# No arch/feed inference, network readiness claim, or caller-supplied curl flags.

cfmgr_native_path() {
	[ -n "$1" ] && [ "${#1}" -le 4096 ] || return 1
	case $1 in /*) ;; *) return 1 ;; esac
	case $1 in *[!\ -~]* | *\\* | *:* | *//* | */./* | */../* | */. | */.. | */) return 1 ;; esac
}

cfmgr_native_capath() (
	# OpenSSL hash lookup must find no certificate/CRL entries in this owned flat
	# context. Preserve caller flags; check again at each request, including links.
	set +f
	[ -d "$cfmgr_native_context" ] && [ ! -L "$cfmgr_native_context" ] || exit 1
	for cfmgr_native_entry in "$cfmgr_native_context"/*; do
		case ${cfmgr_native_entry##*/} in
		[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F].[0-9]* | [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F].r[0-9]*) exit 1 ;;
		esac
	done
)

cfmgr_native_step() {
	cfmgr_native_reason=$1
	shift
	if cfmgr_native_action "$@"; then return 0; else
		cfmgr_native_step_code=$?
		if [ "$cfmgr_native_step_code" -eq 3 ]; then cfmgr_native_unresolved=1 cfmgr_native_ready=0; fi
		return "$cfmgr_native_step_code"
	fi
}

# shellcheck disable=SC2154 # Fixed action callback exports exit/output/error.
cfmgr_native_zero() {
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] && [ ! -s "$cfmgr_native_output" ]
}

# shellcheck disable=SC2034 # Fixed native ls columns retain positional schema.
cfmgr_native_mode() {
	cfmgr_native_step mutation-metadata install-ls "$1" || return $?
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	IFS=' ' read -r cfmgr_native_mode cfmgr_native_links cfmgr_native_uid cfmgr_native_gid cfmgr_native_rest <"$cfmgr_native_output" || return 1
	[ "$cfmgr_native_mode" = "$2" ]
}

cfmgr_native_mutations() {
	# Finite names, exclusively claimed before use; no native/JFFS host writes.
	(
		umask 077
		set -C
		printf 'original\n' >"$cfmgr_native_context/native.source" &&
			printf 'retained\n' >"$cfmgr_native_context/native.destination"
	) || return 1
	cfmgr_native_step mutation-mkdir install-mkdir-private "$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_dir_owned=1
	cfmgr_native_mode "$cfmgr_native_context/native.directory" drwx------ || return $?
	cfmgr_native_step mutation-rmdir native-rmdir "$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_dir_owned=0
	cfmgr_native_step mutation-mkdir install-mkdir-public "$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_dir_owned=1
	cfmgr_native_mode "$cfmgr_native_context/native.directory" drwxr-xr-x || return $?
	cfmgr_native_step mutation-copy install-copy "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.copy" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_step mutation-rename install-rename "$cfmgr_native_context/native.copy" "$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	IFS= read -r cfmgr_native_text <"$cfmgr_native_context/native.destination" || return 1
	[ "$cfmgr_native_text" = original ] && [ ! -e "$cfmgr_native_context/native.copy" ] || return 1
	cfmgr_native_step mutation-publish install-publish "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	[ -f "$cfmgr_native_context/native.source" ] && [ ! -L "$cfmgr_native_context/native.source" ] || return 1
	printf 'retained\n' >"$cfmgr_native_context/native.destination" || return 1
	cfmgr_native_step mutation-publish install-publish "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	IFS= read -r cfmgr_native_text <"$cfmgr_native_context/native.destination" || return 1
	[ "$cfmgr_native_text" = retained ] && [ -f "$cfmgr_native_context/native.source" ] || return 1
	cfmgr_native_step mutation-publish install-publish "$cfmgr_native_context/native.source" "$cfmgr_native_context/native.published" || return $?
	cfmgr_native_zero || return 1
	IFS= read -r cfmgr_native_text <"$cfmgr_native_context/native.published" || return 1
	[ "$cfmgr_native_text" = original ] && [ ! -e "$cfmgr_native_context/native.source" ] || return 1
	for cfmgr_native_permission in private readonly executable; do
		cfmgr_native_step mutation-chmod "install-chmod-$cfmgr_native_permission" "$cfmgr_native_context/native.destination" || return $?
		cfmgr_native_zero || return 1
		case $cfmgr_native_permission in private) cfmgr_native_expected=-rw------- ;; readonly) cfmgr_native_expected=-rw-r--r-- ;; executable) cfmgr_native_expected=-rwxr-xr-x ;; esac
		cfmgr_native_mode "$cfmgr_native_context/native.destination" "$cfmgr_native_expected" || return $?
	done
	# FD3 is free before prerequisite flock/view work. Borrow it for the same
	# fsync probe used by the installer, including native errno/diagnostics.
	cfmgr_native_step mutation-flush install-flush 3<"$cfmgr_native_context/native.destination" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_step mutation-flush install-flush 3<"$cfmgr_native_context/native.directory" || return $?
	cfmgr_native_zero || return 1
}

cfmgr_native_cleanup() {
	# Only the exclusively claimed empty scratch directory needs removal. Flat
	# regular evidence remains for the controller's existing bounded cleanup.
	if [ -e "$cfmgr_native_context/native.directory" ] || [ -L "$cfmgr_native_context/native.directory" ]; then
		[ "$cfmgr_native_dir_owned" = 1 ] && [ -d "$cfmgr_native_context/native.directory" ] && [ ! -L "$cfmgr_native_context/native.directory" ] || return 3
		cfmgr_native_step cleanup native-rmdir "$cfmgr_native_context/native.directory" || return $?
		cfmgr_native_zero || return 3
	fi
}

cfmgr_native_http_status() {
	cfmgr_native_status_file=$cfmgr_native_output
	IFS= read -r cfmgr_native_status <"$cfmgr_native_status_file" || return 1
	[ "${#cfmgr_native_status}" -eq 3 ] || return 1
	case $cfmgr_native_status in *[!0-9]*) return 1 ;; esac
	cfmgr_native_step "$cfmgr_native_reason" install-wc "$cfmgr_native_status_file" || return $?
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	cfmgr_prerequisites_text "$cfmgr_native_status_file" "$cfmgr_native_status" "$cfmgr_native_output"
}

cfmgr_native_offline() {
	cfmgr_native_step curl-version native-curl-version || return $?
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	cfmgr_native_step curl-https-ssl native-curl-features "$cfmgr_native_output" || return $?
	cfmgr_native_zero || return 1
	[ -f "$cfmgr_native_ca" ] && [ ! -L "$cfmgr_native_ca" ] || return 1
	cfmgr_native_step ca-size install-wc "$cfmgr_native_ca" || return $?
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	IFS=' ' read -r cfmgr_native_size cfmgr_native_extra <"$cfmgr_native_output" || return 1
	case $cfmgr_native_size in '' | *[!0-9]*) return 1 ;; esac
	[ -z "$cfmgr_native_extra" ] && [ "${#cfmgr_native_size}" -le 7 ] && [ "$cfmgr_native_size" -gt 0 ] && [ "$cfmgr_native_size" -le 1048576 ] || return 1
	cfmgr_native_step ca-pem native-ca-pem "$cfmgr_native_ca" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_step ca-decode native-ca-decode "$cfmgr_native_ca" || return $?
	cfmgr_native_zero || return 1
	cfmgr_native_capath || {
		cfmgr_native_reason=capath
		return 1
	}
	cfmgr_native_step curl-policy native-curl-offline "$cfmgr_native_ca" "$cfmgr_native_context" || return $?
	[ "$cfmgr_native_exit" -eq 1 ] || return 1
	# Exit1 is unsupported protocol; the forbidden HTTP URL must never connect.
	cfmgr_native_http_status || return $?
	[ "$cfmgr_native_status" = 000 ] || return 1
}

# CONTEXT CURL OPENSSL CA, all admitted controller inputs (no public overrides).
# shellcheck disable=SC2034 # Curl/OpenSSL paths are exported to the fixed callback.
cfmgr_native_check() {
	[ "${cfmgr_native_unresolved:-0}" = 0 ] || return 3
	cfmgr_native_ready=0 cfmgr_native_reason=arguments cfmgr_native_dir_owned=0
	[ "$#" -eq 4 ] || return 2
	for cfmgr_native_argument; do cfmgr_native_path "$cfmgr_native_argument" || return 2; done
	cfmgr_native_context=$1 cfmgr_native_curl=$2 cfmgr_native_openssl=$3 cfmgr_native_ca=$4
	[ -d "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ -x "$2" ] && [ -f "$3" ] && [ -x "$3" ] || return 2
	if (: <&3) 2>/dev/null; then return 2; fi
	for cfmgr_native_claim in native.source native.destination native.copy native.published native.directory; do
		[ ! -e "$1/$cfmgr_native_claim" ] && [ ! -L "$1/$cfmgr_native_claim" ] || {
			cfmgr_native_reason=context-not-fresh
			return 2
		}
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

cfmgr_native_https() {
	[ "${cfmgr_native_unresolved:-0}" = 0 ] || return 3
	[ "$#" -eq 1 ] && [ "${cfmgr_native_ready:-0}" = 1 ] || return 2
	case $1 in https://*) ;; *) return 2 ;; esac
	[ "${#1}" -le 4096 ] || return 2
	case $1 in *[!\ -~]* | *' '* | *'@'* | *\\*) return 2 ;; esac
	cfmgr_native_capath || {
		cfmgr_native_reason=capath
		return 1
	}
	cfmgr_native_step https native-curl-https "$cfmgr_native_ca" "$cfmgr_native_context" "$1" || return $?
	[ "$cfmgr_native_exit" -eq 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	cfmgr_native_http_status || return $?
	case $cfmgr_native_status in [1-5][0-9][0-9]) return 0 ;; *) return 1 ;; esac
}
