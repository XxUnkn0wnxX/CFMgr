#!/bin/sh
# Source-inert capability checks. The caller owns admission, context and attachment.
# cfmgr_prerequisites_attachment_ok and cfmgr_prerequisites_admit_tool are
# mandatory, fixed trusted caller functions. Admission: 0 safe, 1 missing/unusable,
# 2 unsafe, 3 unresolved ownership. Rechecks require a new private context.
# Return: 0 capability present, 1 unusable, 2 invalid/native supervision unavailable,
# 3 unresolved ownership. Result variables are capability evidence, never readiness.

cfmgr_prerequisites_identity() {
	case "$1" in '' | *[!0-9]*) return 1 ;; esac
	# A task can disappear before open; callers classify absence themselves.
	IFS= read -r cfmgr_identity_line 2>/dev/null <"/proc/$1/stat" || return 1
	[ "${cfmgr_identity_line%% *}" = "$1" ] || return 1
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
	cfmgr_prerequisites_identity "$cfmgr_probe_pid" || return 1
	[ "$cfmgr_identity_start" = "$cfmgr_probe_start" ] &&
		[ "$cfmgr_identity_parent" = "$cfmgr_probe_owner" ] &&
		IFS= read -r cfmgr_probe_current_boot </proc/sys/kernel/random/boot_id &&
		[ "$cfmgr_probe_current_boot" = "$cfmgr_probe_boot" ]
}

cfmgr_prerequisites_child() {
	[ "$cfmgr_probe_mode" = timeout-expiry ] || return 0
	[ -f "$cfmgr_probe_context/timeout.child" ] || return 1
	IFS=' ' read -r cfmgr_probe_child_pid cfmgr_probe_child_parent cfmgr_probe_child_start cfmgr_probe_child_boot cfmgr_probe_child_extra <"$cfmgr_probe_context/timeout.child" || return 1
	[ -z "$cfmgr_probe_child_extra" ] &&
		[ "$cfmgr_probe_child_parent" = "$cfmgr_probe_pid" ] &&
		[ "$cfmgr_probe_child_boot" = "$cfmgr_probe_boot" ] || return 1
	case "$cfmgr_probe_child_pid:$cfmgr_probe_child_start" in *[!0-9:]* | :*) return 1 ;; esac
	if [ ! -d "/proc/$cfmgr_probe_child_pid" ]; then
		return 0
	fi
	cfmgr_prerequisites_identity "$cfmgr_probe_child_pid" &&
		[ "$cfmgr_identity_start" = "$cfmgr_probe_child_start" ] &&
		[ "$cfmgr_identity_parent" = "$cfmgr_probe_pid" ]
}

# shellcheck disable=SC2034
cfmgr_prerequisites_now() {
	IFS=' ' read -r cfmgr_probe_uptime cfmgr_probe_idle </proc/uptime || return 1
	cfmgr_probe_now=${cfmgr_probe_uptime%%.*}
	case "$cfmgr_probe_now" in '' | *[!0-9]*) return 1 ;; esac
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
	/bin/usleep 50000
}

_cfmgr_prerequisites_attachment() {
	case ${cfmgr_probe_mode:-none} in
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
	cfmgr_probe_status=invalid
	cfmgr_probe_exit=
	cfmgr_probe_pid=
	cfmgr_probe_start='' cfmgr_probe_owner='' cfmgr_probe_boot=''
	cfmgr_probe_child_pid=
	cfmgr_probe_child_start='' cfmgr_probe_child_parent='' cfmgr_probe_child_boot=''
	cfmgr_probe_stdout='' cfmgr_probe_stderr=''
	cfmgr_probe_reason=arguments
	[ "$#" -ge 9 ] && [ "$#" -le 22 ] || return 2
	cfmgr_probe_mode=$1 cfmgr_probe_context=$2 cfmgr_probe_shell=$3
	cfmgr_probe_helper=$4 cfmgr_probe_env=$5 cfmgr_probe_awk=$6
	cfmgr_probe_sleep=$7 cfmgr_probe_wc=$8 cfmgr_probe_tool=$9
	case "$cfmgr_probe_mode" in
	repair-awk) [ "$#" -ge 14 ] && [ "$#" -le 22 ] || return 2 ;;
	repair-inventory) [ "$#" -eq 12 ] || return 2 ;;
	repair-identity-parse | repair-readlink | repair-list | repair-copy | repair-mkdir | repair-chmod | repair-link | repair-signal) [ "$#" -eq 11 ] || return 2 ;;
	repair-report | repair-identity | repair-file | repair-root | repair-guard-root | repair-bind4 | repair-bind7 | repair-private | repair-unbindable | repair-seal | repair-unmount | repair-fifo | repair-remove | repair-rmdir) [ "$#" -eq 10 ] || return 2 ;;
	native-curl-offline) [ "$#" -eq 11 ] || return 2 ;;
	native-curl-https) [ "$#" -eq 12 ] || return 2 ;;
	native-curl-version) [ "$#" -eq 9 ] || return 2 ;;
	native-curl-features | native-ca-pem | native-ca-decode | native-rmdir) [ "$#" -eq 10 ] || return 2 ;;
	install-copy | install-rename | install-publish) [ "$#" -eq 11 ] || return 2 ;;
	install-sha | install-wc | install-ls | install-config-check | install-mkdir-private | install-mkdir-public | install-chmod-private | install-chmod-readonly | install-chmod-executable | install-df) [ "$#" -eq 10 ] || return 2 ;;
	install-flush | install-nvram) [ "$#" -eq 9 ] || return 2 ;;
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
	install-* | native-* | repair-*)
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
	(
		# Clear loader/config input before even execing the env utility. env-i
		# sanitizes its child, but cannot protect env own dynamic-loader startup.
		unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE \
			LD_ORIGIN_PATH LD_ASSUME_KERNEL LD_BIND_NOW LD_TRACE_LOADED_OBJECTS \
			DYLD_INSERT_LIBRARIES DYLD_LIBRARY_PATH DYLD_FRAMEWORK_PATH \
			DYLD_FALLBACK_LIBRARY_PATH DYLD_FALLBACK_FRAMEWORK_PATH \
			OPENSSL_CONF OPENSSL_MODULES OPENSSL_ENGINES CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR
		case "$cfmgr_probe_mode" in repair-*) ulimit -f 8192 || exit 2 ;; install-copy) ulimit -f 2048 || exit 2 ;; *) ulimit -f 8 || exit 2 ;; esac
		case "$cfmgr_probe_mode" in
		install-* | native-* | repair-*)
			shift 9
			exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" "$@"
			;;
		timeout-exit) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" "$cfmgr_probe_shell" "$cfmgr_probe_helper" ;;
		timeout-expiry) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_sleep" ;;
		blkid) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" blkid "$cfmgr_probe_tool" "$cfmgr_probe_context" "${10}" ;;
		*) exec "$cfmgr_probe_env" -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= OPENSSL_CONF=/dev/null "$cfmgr_probe_shell" "$cfmgr_probe_helper" "$cfmgr_probe_mode" "$cfmgr_probe_tool" "$cfmgr_probe_context" ;;
		esac
	) >"$cfmgr_probe_stdout" 2>"$cfmgr_probe_stderr" &
	cfmgr_probe_pid=$!
	# Save identity before supervising. A vanished immediate child is already reapable.
	if cfmgr_prerequisites_identity "$cfmgr_probe_pid"; then
		cfmgr_probe_start=$cfmgr_identity_start
		[ "$cfmgr_identity_parent" = "$cfmgr_probe_owner" ] || {
			cfmgr_probe_status=unresolved
			return 3
		}
	elif [ -d "/proc/$cfmgr_probe_pid" ]; then
		cfmgr_probe_status=unresolved
		return 3
	else
		cfmgr_probe_start=
	fi
	cfmgr_probe_reason=
	while [ -d "/proc/$cfmgr_probe_pid" ]; do
		cfmgr_prerequisites_owned || {
			cfmgr_probe_status=unresolved
			return 3
		}
		[ "$cfmgr_identity_state" = Z ] && break
		if ! _cfmgr_prerequisites_attachment; then cfmgr_probe_reason=attachment; fi
		cfmgr_prerequisites_now || cfmgr_probe_reason=clock
		[ "$cfmgr_probe_now" -lt "$cfmgr_probe_deadline" ] || cfmgr_probe_reason=deadline
		if [ -n "$cfmgr_probe_reason" ]; then
			# The timeout mode has exactly one fixed child. Missing ownership evidence
			# cannot be replaced by assuming that killing timeout ends its child.
			cfmgr_prerequisites_child || {
				cfmgr_probe_status=unresolved
				return 3
			}
			if [ -n "$cfmgr_probe_child_pid" ] && [ -d "/proc/$cfmgr_probe_child_pid" ]; then
				cfmgr_prerequisites_child || {
					cfmgr_probe_status=unresolved
					return 3
				}
				kill -TERM "$cfmgr_probe_child_pid" || :
			fi
			cfmgr_prerequisites_owned || {
				cfmgr_probe_status=unresolved
				return 3
			}
			kill -TERM "$cfmgr_probe_pid" || :
			break
		fi
		cfmgr_prerequisites_pause || {
			cfmgr_probe_status=unresolved
			return 3
		}
	done
	if [ -n "$cfmgr_probe_reason" ]; then
		cfmgr_probe_attempt=0
		while [ "$cfmgr_probe_attempt" -lt 10 ] && [ -d "/proc/$cfmgr_probe_pid" ]; do
			cfmgr_prerequisites_owned || {
				cfmgr_probe_status=unresolved
				return 3
			}
			[ "$cfmgr_identity_state" = Z ] && break
			cfmgr_prerequisites_pause || {
				cfmgr_probe_status=unresolved
				return 3
			}
			cfmgr_probe_attempt=$((cfmgr_probe_attempt + 1))
		done
		if [ -d "/proc/$cfmgr_probe_pid" ] && [ "$cfmgr_identity_state" != Z ]; then
			# Never force the parent out before it has reaped the tracked child.
			cfmgr_prerequisites_child || {
				cfmgr_probe_status=unresolved
				return 3
			}
			if [ -n "$cfmgr_probe_child_pid" ] && [ -d "/proc/$cfmgr_probe_child_pid" ]; then
				kill -KILL "$cfmgr_probe_child_pid" || :
				cfmgr_probe_status=unresolved
				return 3
			fi
			cfmgr_prerequisites_owned || {
				cfmgr_probe_status=unresolved
				return 3
			}
			kill -KILL "$cfmgr_probe_pid" || :
			cfmgr_prerequisites_pause || :
		fi
	fi
	if [ -d "/proc/$cfmgr_probe_pid" ]; then
		if ! cfmgr_prerequisites_owned || [ "$cfmgr_identity_state" != Z ]; then
			cfmgr_probe_status=unresolved
			return 3
		fi
	fi
	if wait "$cfmgr_probe_pid"; then cfmgr_probe_exit=0; else cfmgr_probe_exit=$?; fi
	if [ "$cfmgr_probe_mode" = timeout-expiry ]; then
		if ! cfmgr_prerequisites_child || [ -d "/proc/$cfmgr_probe_child_pid" ]; then
			cfmgr_probe_status=unresolved
			return 3
		fi
	fi
	_cfmgr_prerequisites_attachment || cfmgr_probe_reason=attachment
	cfmgr_probe_status=reaped
	[ -z "$cfmgr_probe_reason" ] || return 1
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
	cfmgr_prerequisites_attachment_ok || return 2
	cfmgr_prerequisites_supervisor || return 2
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
		elif cfmgr_prerequisites_admit_tool "$cfmgr_prereq_tool"; then
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
			if cfmgr_prerequisites_admit_tool "$cfmgr_prereq_tool"; then cfmgr_prereq_code=0; else cfmgr_prereq_code=$?; fi
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
			elif cfmgr_prerequisites_admit_tool "$cfmgr_prereq_dig"; then
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
