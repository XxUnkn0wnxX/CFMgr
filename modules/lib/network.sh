#!/bin/sh
# Category owner: network. Sourcing defines functions only.

# ---- native ----
# Source-inert offline native admission and fixed secure HTTPS HEAD primitive.
# Caller admits tools, root-protected CA and fresh private RAM context, and
# supplies cfmgr_native_action MODE OPERANDS with bounded direct-child probes.
# Callback exports cfmgr_native_output/error/exit; return3 retains ownership.
# No arch/feed inference, network readiness claim, or caller-supplied curl flags.

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

# shellcheck disable=SC2154 # Fixed native probe callback exports output/error/exit.
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

# Acquisition needs offline native TLS capability without Entware or the
# installation mutation checks. The trusted controller owns RAM/FD admission
# and separately qualifies native OpenSSL SHA-256 before any remote payload.
# shellcheck disable=SC2034 # Paths exported to the trusted acquisition callback.
cfmgr_native_acquire_check() {
	[ "${cfmgr_native_unresolved:-0}" = 0 ] || return 3
	[ "$#" -eq 4 ] || return 2
	for cfmgr_native_argument; do cfmgr_native_path "$cfmgr_native_argument" || return 2; done
	cfmgr_native_context=$1 cfmgr_native_curl=$2 cfmgr_native_openssl=$3 cfmgr_native_ca=$4
	cfmgr_native_ready=0 cfmgr_native_reason=acquire-offline
	cfmgr_native_offline || return $?
	cfmgr_native_ready=1 cfmgr_native_reason=''
}
