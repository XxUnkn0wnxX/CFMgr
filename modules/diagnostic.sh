#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# First native diagnostic stage, not operational startup or complete health proof.
# Native firmware paths are trusted; /opt and configuration are never consulted.
# Diagnostics remain native even without Entware or usable packages. A hung
# native executable has no proved deadline; probes are finite, not network I/O.

cfmgr_diagnostic_main() {
	[ "$#" -eq 0 ] || return 2
	_cfmgr_diagnostic_run '' /tmp
}

# Entries own the invoking shell and its exit/signal cleanup; source only defines
# functions. The explicit trusted fixture entry is not exposed by the CLI.
cfmgr_diagnostic_test() {
	[ "$#" -eq 2 ] || return 2
	_cfmgr_diagnostic_run "$1" "$2"
}

_cfmgr_diagnostic_find() {
	if [ -n "$_diag_tools" ]; then
		if [ -x "$_diag_tools/$1" ] && [ ! -d "$_diag_tools/$1" ]; then
			printf '%s\n' "$_diag_tools/$1"
			return 0
		fi
		return 1
	fi
	for _diag_search in /sbin /bin /usr/sbin /usr/bin; do
		if [ -x "$_diag_search/$1" ] && [ ! -d "$_diag_search/$1" ]; then
			printf '%s\n' "$_diag_search/$1"
			return 0
		fi
	done
	return 1
}

_cfmgr_diagnostic_row() {
	printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5"
	if [ "$3" = required ]; then
		case $2 in FAIL) _diag_failed=1 ;; SKIP) _diag_incomplete=1 ;; esac
	fi
}

_cfmgr_diagnostic_available() {
	if _diag_found=$(_cfmgr_diagnostic_find "$2"); then
		_cfmgr_diagnostic_row "$1" PASS "$3" availability "native $2 available"
		return 0
	fi
	_cfmgr_diagnostic_row "$1" FAIL "$3" availability "native $2 missing"
	return 1
}

_cfmgr_diagnostic_capture() {
	_diag_sequence=$((_diag_sequence + 1))
	_diag_output=$_diag_stage/output.$_diag_sequence
	_diag_error=$_diag_stage/error.$_diag_sequence
	# Bound each output file even if a native leaf emits unexpected data.
	(
		(ulimit -f 8 && "$@") >"$_diag_output" 2>"$_diag_error"
	) 2>/dev/null
	_diag_status=$?
} 2>/dev/null

_cfmgr_diagnostic_line() {
	_diag_line=
	IFS= read -r _diag_line <"$_diag_output" || [ -n "$_diag_line" ]
} 2>/dev/null

_cfmgr_diagnostic_single_line() {
	_diag_line=
	{
		IFS= read -r _diag_line || [ -n "$_diag_line" ]
		_diag_extra=
		if IFS= read -r _diag_extra || [ -n "$_diag_extra" ]; then _diag_status=1; fi
	} <"$_diag_output"
} 2>/dev/null

_cfmgr_diagnostic_finish() {
	_diag_exit=$1
	case $_diag_signal in 129 | 130 | 143) _diag_exit=$_diag_signal ;; esac
	trap - 0
	trap '' HUP INT TERM
	if [ -n "$_diag_stage" ]; then
		if "$_diag_rm" -rf "$_diag_stage" >/dev/null 2>&1 && [ ! -e "$_diag_stage" ] && [ ! -L "$_diag_stage" ]; then
			_cfmgr_diagnostic_row RAM.CLEANUP PASS required behavior 'owned private stage removed'
		else
			_cfmgr_diagnostic_row RAM.CLEANUP FAIL required behavior 'owned private stage cleanup failed; no other paths touched'
		fi
	fi
	case $_diag_exit in
	129 | 130 | 143)
		_cfmgr_diagnostic_row DIAGNOSTIC.SUMMARY SKIP info summary 'diagnostic interrupted'
		;;
	2) _cfmgr_diagnostic_row DIAGNOSTIC.SUMMARY SKIP info summary 'invalid diagnostic invocation' ;;
	*)
		if [ "$_diag_failed" -eq 1 ]; then
			_diag_exit=1
			_cfmgr_diagnostic_row DIAGNOSTIC.SUMMARY FAIL info summary 'observed required capability or cleanup failure'
		elif [ "$_diag_incomplete" -eq 1 ]; then
			_diag_exit=3
			_cfmgr_diagnostic_row DIAGNOSTIC.SUMMARY SKIP info summary 'required checks incomplete; no observed required failure'
		else
			_diag_exit=0
			_cfmgr_diagnostic_row DIAGNOSTIC.SUMMARY PASS info summary 'all required checks evaluated and passed'
		fi
		;;
	esac
	exit "$_diag_exit"
}

_cfmgr_diagnostic_context() {
	# Only four fixed nonsecret NVRAM fields; no arbitrary key/config/environment dump.
	if ! _diag_nvram=$(_cfmgr_diagnostic_find nvram); then
		_cfmgr_diagnostic_row CONTEXT.ROUTER SKIP info context 'model/firmware unknown; native nvram missing'
	else
		for _diag_key in productid firmver buildno extendno; do
			_cfmgr_diagnostic_capture "$_diag_nvram" get "$_diag_key"
			_cfmgr_diagnostic_single_line
			_diag_valid=0
			if [ "$_diag_status" -eq 0 ] && [ "${#_diag_line}" -le 48 ]; then
				case $_diag_key:$_diag_line in
				productid:*[!ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-]* | productid:) ;;
				productid:*) _diag_valid=1 ;;
				firmver:*[!0123456789.]* | firmver:) ;;
				firmver:*) _diag_valid=1 ;;
				buildno:*[!0123456789.]* | buildno:) ;;
				buildno:*) _diag_valid=1 ;;
				extendno:*[!0123456789._]* | extendno:) ;;
				extendno:*) _diag_valid=1 ;;
				esac
			fi
			if [ "$_diag_valid" -eq 1 ]; then
				_cfmgr_diagnostic_row "CONTEXT.$_diag_key" PASS info context "$_diag_key=$_diag_line"
			else
				_cfmgr_diagnostic_row "CONTEXT.$_diag_key" SKIP info context "$_diag_key unknown; invalid/unavailable output"
			fi
		done
	fi
	if _diag_uname=$(_cfmgr_diagnostic_find uname); then
		for _diag_flag in r m; do
			_cfmgr_diagnostic_capture "$_diag_uname" "-$_diag_flag"
			_cfmgr_diagnostic_single_line
			case $_diag_line in
			'' | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-]*) _diag_status=1 ;;
			esac
			if [ "$_diag_status" -eq 0 ] && [ "${#_diag_line}" -le 64 ]; then
				_cfmgr_diagnostic_row "CONTEXT.uname-$_diag_flag" PASS info context "uname-$_diag_flag=$_diag_line"
			else
				_cfmgr_diagnostic_row "CONTEXT.uname-$_diag_flag" SKIP info context 'kernel/architecture unknown; invalid/unavailable output'
			fi
		done
	else
		_cfmgr_diagnostic_row CONTEXT.KERNEL SKIP info context 'kernel/architecture unknown; native uname missing'
	fi
}

_cfmgr_diagnostic_run() {
	[ "$#" -eq 2 ] || return 2
	_diag_tools=$1
	_diag_ram=$2
	PATH=/sbin:/bin:/usr/sbin:/usr/bin
	LC_ALL=C
	OPENSSL_CONF=/dev/null
	export PATH LC_ALL OPENSSL_CONF
	unset ENV BASH_ENV CDPATH LD_LIBRARY_PATH LD_PRELOAD
	unset OPENSSL_ENGINES OPENSSL_FIPS OPENSSL_MODULES OPENSSL_CONF_INCLUDE RANDFILE
	IFS='
	 '
	set -f
	exec 0</dev/null
	umask 077
	_diag_failed=0
	_diag_incomplete=0
	_diag_signal=0
	_diag_sh=
	_diag_stage=
	_diag_sequence=0
	trap '_cfmgr_diagnostic_finish "$?"' 0
	# Defer interruption during stage creation until ownership has been recorded.
	trap '_diag_signal=129' HUP
	trap '_diag_signal=130' INT
	trap '_diag_signal=143' TERM
	printf '%s\n' 'CFMgr 0.1.0 development native diagnostics (partial health coverage)'
	_cfmgr_diagnostic_row LOCAL.STATUS SKIP info local 'feature/config status not implemented; no configuration read'
	_cfmgr_diagnostic_row OPT.STORAGE SKIP required preflight 'Entware mount identity unverified; preflight not implemented'
	for _diag_package in jq coreutils-timeout coreutils-sha256sum; do
		_cfmgr_diagnostic_row "PACKAGE.$_diag_package" SKIP required inventory "$_diag_package status unknown; prerequisite OPT.STORAGE"
	done
	for _diag_package in bind-dig flock; do
		_cfmgr_diagnostic_row "PACKAGE.$_diag_package" SKIP scoped inventory "$_diag_package status unknown; prerequisite OPT.STORAGE"
	done
	_cfmgr_diagnostic_row BOUND.DEADLINE SKIP info supervision 'dependency-independent native deadline unproved; no Entware execution'
	_cfmgr_diagnostic_row NETWORK.HTTPS SKIP info network 'no network request; HTTPS/provider reachability not tested'

	_diag_mkdir=
	_diag_rm=
	if _cfmgr_diagnostic_available NATIVE.MKDIR mkdir required; then _diag_mkdir=$_diag_found; fi
	if _cfmgr_diagnostic_available NATIVE.RM rm required; then _diag_rm=$_diag_found; fi
	if [ -z "$_diag_mkdir" ] || [ -z "$_diag_rm" ]; then
		_cfmgr_diagnostic_row RAM.STAGE SKIP required behavior 'prerequisite NATIVE.MKDIR/NATIVE.RM failed'
		return 1
	fi
	case $_diag_ram in /*) ;; *) return 2 ;; esac
	_diag_attempt=0
	while [ "$_diag_attempt" -lt 8 ]; do
		_diag_candidate=$_diag_ram/cfmgr-diagnostic.$$.$_diag_attempt
		if { "$_diag_mkdir" "$_diag_candidate" >/dev/null 2>&1; } 2>/dev/null; then
			_diag_stage=$_diag_candidate
			break
		fi
		[ "$_diag_signal" -eq 0 ] || exit "$_diag_signal"
		_diag_attempt=$((_diag_attempt + 1))
	done
	if [ -z "$_diag_stage" ]; then
		_cfmgr_diagnostic_row RAM.STAGE FAIL required behavior 'private stage creation failed after bounded collision attempts'
		return 1
	fi
	[ "$_diag_signal" -eq 0 ] || exit "$_diag_signal"
	trap 'exit 129' HUP
	trap 'exit 130' INT
	trap 'exit 143' TERM
	_cfmgr_diagnostic_row RAM.STAGE PASS required behavior 'new private RAM stage created; owned cleanup on exit/signals'
	if ! { printf 'A\000B\n' >"$_diag_stage/bytes" && printf '%s' cfmgr >"$_diag_stage/hash" && printf '{\n"x":1\n}' >"$_diag_stage/framing"; } 2>/dev/null; then
		_cfmgr_diagnostic_row RAM.IO FAIL required behavior 'private synthetic fixture write failed'
		return 1
	fi
	_cfmgr_diagnostic_row RAM.IO PASS required behavior 'private synthetic fixture writes succeeded'
	_cfmgr_diagnostic_context

	if _cfmgr_diagnostic_available NATIVE.SH sh required; then
		_diag_sh=$_diag_found
		# The expression belongs to the probed shell.
		# shellcheck disable=SC2016
		_cfmgr_diagnostic_capture "$_diag_sh" -c '[ "$((2147483646 + 1))" = 2147483647 ]'
		if [ "$_diag_status" -eq 0 ] && [ ! -s "$_diag_output" ] && [ ! -s "$_diag_error" ]; then
			_cfmgr_diagnostic_row SHELL.INT31 PASS required behavior 'signed-31 positive boundary arithmetic supported'
		else
			_cfmgr_diagnostic_row SHELL.INT31 FAIL required behavior 'signed-31 boundary arithmetic failed'
		fi
		_cfmgr_diagnostic_capture "$_diag_sh" -c 'command -v printf >/dev/null 2>&1'
		if [ "$_diag_status" -eq 0 ] && [ ! -s "$_diag_output" ] && [ ! -s "$_diag_error" ]; then
			_cfmgr_diagnostic_row SHELL.COMMAND-V PASS info behavior 'command -v supported; production uses fixed path lookup'
		else
			_cfmgr_diagnostic_row SHELL.COMMAND-V FAIL info behavior 'command -v unavailable; production uses fixed path lookup'
		fi
	else
		_cfmgr_diagnostic_row SHELL.INT31 SKIP required behavior 'prerequisite NATIVE.SH failed'
		_cfmgr_diagnostic_row SHELL.COMMAND-V SKIP info behavior 'prerequisite NATIVE.SH failed'
	fi
	if _cfmgr_diagnostic_available NATIVE.PRINTF printf required; then
		_cfmgr_diagnostic_capture "$_diag_found" '%s:%x\n' cfmgr 65535
		_cfmgr_diagnostic_single_line
		if [ "$_diag_status" -eq 0 ] && [ "$_diag_line" = cfmgr:ffff ]; then
			_cfmgr_diagnostic_row PRINTF.FORMAT PASS required behavior 'printf string/hex formatting supported'
		else
			_cfmgr_diagnostic_row PRINTF.FORMAT FAIL required behavior 'printf string/hex formatting failed'
		fi
	else
		_cfmgr_diagnostic_row PRINTF.FORMAT SKIP required behavior 'prerequisite NATIVE.PRINTF failed'
	fi
	for _diag_utility in test '['; do
		case $_diag_utility in test) _diag_id=TEST ;; *) _diag_id=BRACKET ;; esac
		if _cfmgr_diagnostic_available "NATIVE.$_diag_id" "$_diag_utility" required; then
			_diag_test=$_diag_found
			if [ "$_diag_utility" = '[' ]; then set -- ']'; else set --; fi
			_cfmgr_diagnostic_capture "$_diag_test" 2147483647 -eq 2147483647 "$@"
			_diag_test_status=$_diag_status
			_cfmgr_diagnostic_capture "$_diag_test" 2147483647 -lt 2147483647 "$@"
			if [ "$_diag_test_status" -eq 0 ] && [ "$_diag_status" -eq 1 ]; then
				_cfmgr_diagnostic_row "$_diag_id.INTEGER" PASS required behavior 'integer equality and false ordering supported'
			else
				_cfmgr_diagnostic_row "$_diag_id.INTEGER" FAIL required behavior 'integer equality/ordering contract failed'
			fi
		else
			_cfmgr_diagnostic_row "$_diag_id.INTEGER" SKIP required behavior "prerequisite NATIVE.$_diag_id failed"
		fi
	done
	if _cfmgr_diagnostic_available NATIVE.WC wc required; then
		_diag_wc=$_diag_found
		_cfmgr_diagnostic_capture "$_diag_wc" -c <"$_diag_stage/bytes"
		_cfmgr_diagnostic_single_line
		# Deliberate splitting with globbing disabled.
		# shellcheck disable=SC2086
		set -- $_diag_line
		if [ "$_diag_status" -eq 0 ] && [ "$#" -eq 1 ] && [ "$1" = 4 ]; then
			_cfmgr_diagnostic_row WC.BYTES PASS required behavior 'synthetic NUL fixture byte count is 4'
		else
			_cfmgr_diagnostic_row WC.BYTES FAIL required behavior 'wc -c returned an invalid synthetic byte count'
		fi
	else
		_cfmgr_diagnostic_row WC.BYTES SKIP required behavior 'prerequisite NATIVE.WC failed'
	fi
	if _cfmgr_diagnostic_available NATIVE.AWK awk required; then
		# Known byte profiles: retained NUL, C-string truncation, or BusyBox split.
		# The parser combines original-byte counting with explicit control checks.
		_diag_awk=$_diag_found
		_cfmgr_diagnostic_capture "$_diag_awk" 'BEGIN { RS=sprintf("%c",28); a=getline x; first=length(x); b=getline y; second=length(y); c=getline z; if (a!=1 || c!=0 || !((b==0 && (first==4 || first==1)) || (first==1 && second==2 && b==1))) exit 1 }' <"$_diag_stage/bytes"
		_diag_awk_status=1
		if [ "$_diag_status" -eq 0 ] && [ ! -s "$_diag_output" ] && [ ! -s "$_diag_error" ]; then _diag_awk_status=0; fi
		_cfmgr_diagnostic_capture "$_diag_awk" 'BEGIN { RS=sprintf("%c",28); a=getline x; b=getline y; if(a!=1 || length(x)!=9 || b!=0) exit 1 }' <"$_diag_stage/framing"
		if [ "$_diag_awk_status" -eq 0 ] && [ "$_diag_status" -eq 0 ] && [ ! -s "$_diag_output" ] && [ ! -s "$_diag_error" ]; then
			_cfmgr_diagnostic_row AWK.FRAMING PASS required behavior 'synthetic NUL and multiline RS28 byte framing primitives supported'
		else
			_cfmgr_diagnostic_row AWK.FRAMING FAIL required behavior 'awk byte/framing primitive failed; parser not certified'
		fi
	else
		_cfmgr_diagnostic_row AWK.FRAMING SKIP required behavior 'prerequisite NATIVE.AWK failed'
	fi
	if _cfmgr_diagnostic_available NATIVE.OPENSSL openssl required; then
		_cfmgr_diagnostic_capture "$_diag_found" dgst -sha256 "$_diag_stage/hash"
		_cfmgr_diagnostic_single_line
		case $_diag_status:$_diag_line in
		0:*'= 837235063554f1ef1090d60302be6822d1da1b0d48ae82f5b0d18f6e60d0a97d')
			_cfmgr_diagnostic_row OPENSSL.SHA256 PASS required behavior 'synthetic cfmgr SHA256 matches fixed digest'
			;;
		*) _cfmgr_diagnostic_row OPENSSL.SHA256 FAIL required behavior 'OpenSSL SHA256 failed or returned an invalid digest' ;;
		esac
	else
		_cfmgr_diagnostic_row OPENSSL.SHA256 SKIP required behavior 'prerequisite NATIVE.OPENSSL failed'
	fi
	if _cfmgr_diagnostic_available NATIVE.CURL curl required; then
		_cfmgr_diagnostic_capture "$_diag_found" -q --fail --silent --show-error --connect-timeout 2 --max-time 5 --proto '=https' --proto-redir '=https' --max-redirs 0 --tlsv1.2 --version
		_cfmgr_diagnostic_line
		# Deliberate splitting with globbing disabled.
		# shellcheck disable=SC2086
		set -- $_diag_line
		_diag_version=${2-}
		case $_diag_version in '' | *[!0123456789.]*) _diag_status=1 ;; esac
		if [ "$_diag_status" -eq 0 ] && [ "${1-}" = curl ] && [ "${#_diag_version}" -le 24 ]; then
			_cfmgr_diagnostic_row CURL.OPTIONS PASS required options "curl $_diag_version required flags parse; no HTTPS request"
		else
			_cfmgr_diagnostic_row CURL.OPTIONS FAIL required options 'curl required flags/version parse failed; output redacted'
		fi
	else
		_cfmgr_diagnostic_row CURL.OPTIONS SKIP required options 'prerequisite NATIVE.CURL failed'
	fi
	if _cfmgr_diagnostic_available NATIVE.READLINK readlink required; then
		_diag_readlink=$_diag_found
		if _cfmgr_diagnostic_available NATIVE.LN ln required; then
			_diag_ln=$_diag_found
			if "$_diag_ln" -s bytes "$_diag_stage/link" >/dev/null 2>&1 && [ -L "$_diag_stage/link" ]; then
				_cfmgr_diagnostic_row LN.FIXTURE PASS required behavior 'owned synthetic symlink created'
				_cfmgr_diagnostic_capture "$_diag_readlink" -f "$_diag_stage/link"
				_cfmgr_diagnostic_single_line
				if [ "$_diag_status" -eq 0 ] && [ "$_diag_line" = "$_diag_stage/bytes" ]; then
					_cfmgr_diagnostic_row READLINK.CANONICAL PASS required behavior 'readlink -f resolves owned synthetic symlink'
				else
					_cfmgr_diagnostic_row READLINK.CANONICAL FAIL required behavior 'readlink -f unsupported or invalid result'
				fi
			else
				_cfmgr_diagnostic_row LN.FIXTURE FAIL required behavior 'native ln failed to create owned synthetic symlink'
				_cfmgr_diagnostic_row READLINK.CANONICAL SKIP required behavior 'prerequisite LN.FIXTURE failed'
			fi
		else
			_cfmgr_diagnostic_row READLINK.CANONICAL SKIP required behavior 'prerequisite NATIVE.LN failed'
		fi
	else
		_cfmgr_diagnostic_row READLINK.CANONICAL SKIP required behavior 'prerequisite NATIVE.READLINK failed'
	fi
	if _cfmgr_diagnostic_available NATIVE.FLOCK flock scoped; then
		_diag_flock=$_diag_found
		if [ -n "${_diag_sh-}" ]; then
			_cfmgr_diagnostic_capture "$_diag_flock" -n "$_diag_stage/lock" "$_diag_sh" -c 'exit 0'
			if [ "$_diag_status" -eq 0 ]; then
				_cfmgr_diagnostic_row FLOCK.OPTIONS PASS scoped options 'flock -n accepts an uncontended owned lock; contention untested'
			else
				_cfmgr_diagnostic_row FLOCK.OPTIONS FAIL scoped options 'flock -n uncontended owned lock probe failed'
			fi
		else
			_cfmgr_diagnostic_row FLOCK.OPTIONS SKIP scoped options 'prerequisite NATIVE.SH failed'
		fi
	else
		_cfmgr_diagnostic_row FLOCK.OPTIONS SKIP scoped options 'prerequisite NATIVE.FLOCK failed'
	fi
	_cfmgr_diagnostic_row FLOCK.CONTENTION SKIP scoped behavior 'prerequisite BOUND.DEADLINE unverified; no potentially blocking contention probe'
	# Version context is token-whitelisted; never echo an entire tool banner.
	for _diag_utility in busybox openssl; do
		if _diag_tool=$(_cfmgr_diagnostic_find "$_diag_utility"); then
			if [ "$_diag_utility" = openssl ]; then
				_cfmgr_diagnostic_capture "$_diag_tool" version
			else
				_cfmgr_diagnostic_capture "$_diag_tool"
			fi
			_cfmgr_diagnostic_line
			if [ "$_diag_utility" = busybox ] && [ -z "$_diag_line" ]; then
				IFS= read -r _diag_line <"$_diag_error" || :
			fi
			# Deliberate splitting with globbing disabled.
			# shellcheck disable=SC2086
			set -- $_diag_line
			_diag_version=${2-}
			_diag_valid=0
			case $_diag_utility:${1-}:$_diag_version in
			busybox:BusyBox:v[0-9]* | openssl:OpenSSL:[0-9]*) _diag_valid=1 ;;
			esac
			if [ "$_diag_utility" = openssl ] && [ "$_diag_status" -ne 0 ]; then _diag_valid=0; fi
			case $_diag_version in *[!0123456789.abcdefghijklmnopqrstuvwxyz]*) _diag_valid=0 ;; esac
			if [ "$_diag_valid" -eq 1 ] && [ "${#_diag_version}" -le 24 ]; then
				_cfmgr_diagnostic_row "VERSION.$_diag_utility" PASS info context "$_diag_utility $_diag_version"
			else
				_cfmgr_diagnostic_row "VERSION.$_diag_utility" SKIP info context 'version unknown; invalid/unavailable banner'
			fi
		else
			_cfmgr_diagnostic_row "VERSION.$_diag_utility" SKIP info context 'version unknown; native command missing'
		fi
	done
	for _diag_utility in logger cru tar gzip; do
		_cfmgr_diagnostic_available "INVENTORY.$_diag_utility" "$_diag_utility" info || :
	done
	_cfmgr_diagnostic_row DIAGNOSTIC.SCOPE SKIP info scope 'native first stage only; no repairs, feature startup or Entware execution'
	return "$_diag_failed"
}
