#!/bin/sh
# Source-inert trusted-bootstrap acquisition. Never import candidate code as a
# verifier. The public subshell owns source9/JFFS8/context0 and candidate6; the
# installer gets a canonical path and independently repins its own descriptors.
# Source defaults belong only to the trusted entry, never config/environment.
# shellcheck disable=SC2016,SC2030,SC2031,SC2034,SC2154,SC3013
# AWK dollar fields below are deliberately literal; fixed imports export state.

cfmgr_acquire_attached() {
	cfmgr_bootstrap_native_attached || return 1
	if [ "${cfmgr_acquire_stage_owned:-0}" = 1 ]; then
		[ ! -L "$cfmgr_acquire_stage" ] && [ "$cfmgr_acquire_stage" -ef /proc/self/fd/6 ] || return 1
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_acquire_stage")" = "$cfmgr_acquire_stage" ] &&
			[ "$("$cfmgr_install_awk" -f "$cfmgr_install_source/modules/lib/mountinfo.awk" "$cfmgr_acquire_stage" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ] || return 1
	fi
}

cfmgr_acquire_run() {
	# No new supervisor call may erase a previous unresolved child's identity.
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_acquire_attached || return 1
	cfmgr_prerequisites_now || return 1
	[ "$cfmgr_probe_now" -lt "$cfmgr_acquire_deadline" ] || return 1
	cfmgr_acquire_mode=$1
	shift
	case $cfmgr_acquire_mode in
	api | raw | curl-version | curl-offline) cfmgr_acquire_tool=$cfmgr_native_curl ;;
	ca-decode | digest) cfmgr_acquire_tool=$cfmgr_native_openssl ;;
	curl-features | ca-pem | manifest | catalog | entry | awk | text) cfmgr_acquire_tool=$cfmgr_install_awk ;;
	wc | lines) cfmgr_acquire_tool=$cfmgr_install_wc ;;
	ls) cfmgr_acquire_tool=$cfmgr_install_ls ;;
	shell) cfmgr_acquire_tool=$cfmgr_install_sh ;;
	chmod) cfmgr_acquire_tool=$cfmgr_install_chmod ;;
	mkdir) cfmgr_acquire_tool=$cfmgr_install_mkdir ;;
	remove) cfmgr_acquire_tool=/bin/rm ;;
	rmdir) cfmgr_acquire_tool=/bin/rmdir ;;
	*) return 2 ;;
	esac
	cfmgr_prerequisites_run "acquire-$cfmgr_acquire_mode" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/probe.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
		"$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_acquire_tool" "$@" || return $?
	cfmgr_native_output=$cfmgr_probe_stdout cfmgr_native_error=$cfmgr_probe_stderr cfmgr_native_exit=$cfmgr_probe_exit
}

cfmgr_acquire_zero() {
	cfmgr_acquire_run "$@" || return $?
	[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] && [ ! -s "$cfmgr_native_output" ]
}

cfmgr_acquire_native_action() {
	case $1 in
	install-wc)
		shift
		cfmgr_acquire_run wc "$@"
		;;
	native-curl-version)
		shift
		cfmgr_acquire_run curl-version "$@"
		;;
	native-curl-offline)
		shift
		cfmgr_acquire_run curl-offline "$@"
		;;
	native-curl-features)
		shift
		cfmgr_acquire_run curl-features "$@"
		;;
	native-ca-pem)
		shift
		cfmgr_acquire_run ca-pem "$@"
		;;
	native-ca-decode)
		shift
		cfmgr_acquire_run ca-decode "$@"
		;;
	*) return 2 ;;
	esac
}

cfmgr_acquire_size() {
	[ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_acquire_run wc "$1" || return $?
	[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	IFS=' ' read -r cfmgr_acquire_size cfmgr_acquire_extra <"$cfmgr_native_output" || return 1
	case $cfmgr_acquire_size in '' | *[!0-9]*) return 1 ;; esac
	[ -z "$cfmgr_acquire_extra" ] && [ "${#cfmgr_acquire_size}" -le 8 ]
}

cfmgr_acquire_digest() {
	cfmgr_acquire_run digest "$1" || return $?
	[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	cfmgr_acquire_digest=$("$cfmgr_install_awk" 'NR!=1 || NF!=2 || length($1)!=64 || $1~/[^0-9a-f]/ || $2!="*stdin" {bad=1} END{if(bad || NR!=1)exit 1;print $1}' "$cfmgr_native_output") || return 1
}

cfmgr_acquire_text() {
	cfmgr_acquire_run lines "$1" || return $?
	[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	IFS=' ' read -r cfmgr_acquire_lines cfmgr_acquire_extra <"$cfmgr_native_output" || return 1
	case $cfmgr_acquire_lines in '' | *[!0-9]*) return 1 ;; esac
	[ -z "$cfmgr_acquire_extra" ] && [ "${#cfmgr_acquire_lines}" -le 8 ] || return 1
	cfmgr_acquire_zero text "$1" "$2" "$cfmgr_acquire_lines" "$3"
}

cfmgr_acquire_protected() {
	cfmgr_acquire_protected_path=$("$cfmgr_install_readlink" -f "$1") || return 1
	case $cfmgr_acquire_protected_path in "$1" | /bin/busybox) ;; *) return 1 ;; esac
	[ -f "$cfmgr_acquire_protected_path" ] && [ ! -L "$cfmgr_acquire_protected_path" ] || return 1
	if [ "$2" = executable ]; then [ -x "$cfmgr_acquire_protected_path" ] || return 1; fi
	while :; do
		cfmgr_acquire_run ls "$cfmgr_acquire_protected_path" || return $?
		[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
		IFS=' ' read -r cfmgr_acquire_permissions cfmgr_acquire_links cfmgr_acquire_uid cfmgr_acquire_rest <"$cfmgr_native_output" || return 1
		[ "$cfmgr_acquire_uid" = 0 ] || return 1
		case $cfmgr_acquire_permissions in -????????? | d?????????) ;; *) return 1 ;; esac
		case $cfmgr_acquire_permissions in ?????w???? | ????????w?) return 1 ;; esac
		[ ! -L "$cfmgr_acquire_protected_path" ] && [ "$("$cfmgr_install_readlink" -f "$cfmgr_acquire_protected_path")" = "$cfmgr_acquire_protected_path" ] || return 1
		[ "$cfmgr_acquire_protected_path" != / ] || break
		cfmgr_acquire_protected_path=${cfmgr_acquire_protected_path%/*}
		[ -n "$cfmgr_acquire_protected_path" ] || cfmgr_acquire_protected_path=/
	done
}

cfmgr_acquire_admit() {
	cfmgr_native_curl=/usr/sbin/curl cfmgr_native_openssl=/usr/sbin/openssl cfmgr_native_ca=/rom/etc/ssl/certs/ca-certificates.crt
	cfmgr_acquire_protected "$cfmgr_native_curl" executable && cfmgr_acquire_protected "$cfmgr_native_openssl" executable &&
		cfmgr_acquire_protected "$cfmgr_native_ca" certificate || return $?
	cfmgr_native_acquire_check "$cfmgr_install_context" "$cfmgr_native_curl" "$cfmgr_native_openssl" "$cfmgr_native_ca" || return $?
	(
		umask 077
		set -C
		printf abc >"$cfmgr_install_context/acquire.vector"
	) || return 1
	cfmgr_acquire_digest "$cfmgr_install_context/acquire.vector" || return $?
	[ "$cfmgr_acquire_digest" = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]
}

cfmgr_acquire_source() {
	case $CFMGR_REPOSITORY in https://github.com/*) cfmgr_acquire_repository=${CFMGR_REPOSITORY#https://github.com/} ;; *) return 1 ;; esac
	case $cfmgr_acquire_repository in */*) ;; *) return 1 ;; esac
	cfmgr_acquire_owner=${cfmgr_acquire_repository%%/*} cfmgr_acquire_repo=${cfmgr_acquire_repository#*/}
	case $cfmgr_acquire_owner in '' | *[!A-Za-z0-9-]* | -*) return 1 ;; esac
	case $cfmgr_acquire_repo in '' | . | .. | *[!A-Za-z0-9_.-]*) return 1 ;; esac
	[ "${#cfmgr_acquire_owner}" -le 39 ] && [ "${#cfmgr_acquire_repo}" -le 100 ] || return 1
	case $CFMGR_BRANCH in '' | *[!A-Za-z0-9_./-]* | /* | */ | *//* | *..* | . | ./* | */./* | */. | -* | *.lock) return 1 ;; esac
	[ "${#CFMGR_BRANCH}" -le 128 ] || return 1
	cfmgr_acquire_ref=$CFMGR_BRANCH
}

cfmgr_acquire_fetch() {
	[ "$#" = 4 ] && [ "${cfmgr_native_ready:-0}" = 1 ] || return 2
	cfmgr_native_capath || return 1
	cfmgr_acquire_run "$1" "$cfmgr_native_ca" "$cfmgr_native_context" "$2" "$3" "$4" || return $?
	[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	# The fixed curl write-out is separate from the private body, including on
	# redirect/rate-limit/error responses. Only a complete HTTP200 can proceed.
	[ "$("$cfmgr_install_awk" 'NR!=1 || $0!="200" {bad=1} END{if(bad || NR!=1)exit 1;print "ok"}' "$cfmgr_native_output")" = ok ] || return 1
	cfmgr_acquire_size "$3" || return $?
	[ "$cfmgr_acquire_size" -le "$4" ]
}

cfmgr_acquire_manifest() {
	cfmgr_acquire_size "$1" || return $?
	[ "$cfmgr_acquire_size" -gt 0 ] && [ "$cfmgr_acquire_size" -le 131072 ] || return 1
	cfmgr_acquire_text "$1" "$cfmgr_acquire_size" 1 || return $?
	IFS=' ' read -r cfmgr_acquire_tag cfmgr_acquire_schema cfmgr_acquire_version cfmgr_acquire_abi cfmgr_acquire_config cfmgr_acquire_extra <"$1" || return 1
	case $cfmgr_acquire_version in '' | [!0-9]* | *[!A-Za-z0-9._+-]*)
		printf '[CFMGR] acquire: error: incompatible package version declaration\n' >&2
		return 1
		;;
	esac
	if [ "${#cfmgr_acquire_version}" -gt 64 ] ||
		[ "$cfmgr_acquire_tag:$cfmgr_acquire_schema:$cfmgr_acquire_abi:$cfmgr_acquire_config:$cfmgr_acquire_extra" != CFMGR-MANIFEST:2:1:2: ]; then
		printf '[CFMGR] acquire: error: incompatible manifest format, bootstrap ABI or configuration schema\n' >&2
		return 1
	fi
	cfmgr_acquire_run manifest "$1" "$cfmgr_acquire_version" || return $?
	[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
	cfmgr_acquire_records=$cfmgr_native_output
}

cfmgr_acquire_directory() {
	[ "$1" != . ] || return 0
	if [ -d "$cfmgr_acquire_stage/$1" ] && [ ! -L "$cfmgr_acquire_stage/$1" ]; then return 0; fi
	case $1 in */*) cfmgr_acquire_directory "${1%/*}" || return $? ;; esac
	printf '%s\n' "$1" >>"$cfmgr_install_context/acquire.directories" || return 1
	cfmgr_acquire_zero mkdir "/proc/self/fd/6/$1"
}

cfmgr_acquire_verify() {
	cfmgr_acquire_attached || return 1
	cfmgr_bootstrap_inventory "$cfmgr_acquire_stage" || return 1
	for cfmgr_acquire_root_item in "$cfmgr_acquire_stage"/* "$cfmgr_acquire_stage"/.[!.]* "$cfmgr_acquire_stage"/..?*; do
		[ -e "$cfmgr_acquire_root_item" ] || [ -L "$cfmgr_acquire_root_item" ] || continue
		case ${cfmgr_acquire_root_item##*/} in cfmgr.sh | catalog.txt | manifest.txt | modules) ;; *) return 1 ;; esac
	done
	"$cfmgr_install_awk" 'BEGIN{FS="\t"} NR==FNR{expected[$4]=1;path=$4;while(sub(/\/[^\/]+$/,"",path))expected[path "/"]=1;next}
		{if(!expected[$0] || seen[$0]++)bad=1} END{for(path in expected)if(!seen[path])bad=1;if(bad)exit 1}' \
		"$cfmgr_acquire_records" "$cfmgr_install_context/inventory" || return 1
	while IFS='	' read -r cfmgr_acquire_file_mode cfmgr_acquire_file_size cfmgr_acquire_file_digest cfmgr_acquire_file <&4; do
		cfmgr_acquire_size "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $?
		[ "$cfmgr_acquire_size" = "$cfmgr_acquire_file_size" ] || return 1
		cfmgr_acquire_digest "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $?
		[ "$cfmgr_acquire_digest" = "$cfmgr_acquire_file_digest" ] || return 1
		cfmgr_acquire_zero chmod "$cfmgr_acquire_file_mode" "/proc/self/fd/6/$cfmgr_acquire_file" || return $?
		cfmgr_acquire_run ls "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $?
		[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
		IFS=' ' read -r cfmgr_acquire_permissions cfmgr_acquire_links cfmgr_acquire_uid cfmgr_acquire_rest <"$cfmgr_native_output" || return 1
		[ "$cfmgr_acquire_uid" = "$cfmgr_install_owner" ] || return 1
		case $cfmgr_acquire_file_mode:$cfmgr_acquire_permissions:$cfmgr_acquire_links in 0644:-rw-r--r--:1 | 0755:-rwxr-xr-x:1) ;; *) return 1 ;; esac
	done 4<"$cfmgr_acquire_records"
	cfmgr_acquire_size "$cfmgr_acquire_stage/catalog.txt" || return $?
	cfmgr_acquire_text "$cfmgr_acquire_stage/catalog.txt" "$cfmgr_acquire_size" 1 || return $?
	cfmgr_acquire_zero entry "$cfmgr_acquire_stage/cfmgr.sh" "$cfmgr_acquire_version" &&
		cfmgr_acquire_zero catalog "$cfmgr_acquire_records" "$cfmgr_acquire_stage/catalog.txt" "$cfmgr_acquire_version" || return $?
	# Syntax follows COMPLETE byte/mode validation; the prefix is trusted RAM
	# code, never a candidate parser. No candidate BEGIN, END or shell executes.
	(
		umask 077
		set -C
		printf '%s\n' 'BEGIN { print "CFMGR-AWK-PARSED 1"; fflush(); print 1/(NR-NR) }' >"$cfmgr_install_context/acquire.syntax.awk"
	) || return 1
	while IFS='	' read -r cfmgr_acquire_file_mode cfmgr_acquire_file_size cfmgr_acquire_file_digest cfmgr_acquire_file <&4; do
		case $cfmgr_acquire_file:$cfmgr_acquire_file_mode in *.sh:* | *.awk:* | *:0755)
			cfmgr_acquire_text "$cfmgr_acquire_stage/$cfmgr_acquire_file" "$cfmgr_acquire_file_size" 0 || return $?
			;;
		esac
		case $cfmgr_acquire_file in
		*.sh) cfmgr_acquire_zero shell "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $? ;;
		*.awk)
			cfmgr_acquire_run awk "$cfmgr_install_context/acquire.syntax.awk" "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $?
			[ "$cfmgr_native_exit" -ne 0 ] || return 1
			[ "$("$cfmgr_install_awk" 'NR!=1 || $0!="CFMGR-AWK-PARSED 1" {bad=1} END{if(bad || NR!=1)exit 1;print "ok"}' "$cfmgr_native_output")" = ok ] || return 1
			# BusyBox fatal errors bypass END. Host wording is allowed only when
			# equally exact/bounded; the actual vendor case is required in CI.
			"$cfmgr_install_awk" 'BEGIN{prefix=tolower(ARGV[1]);tool=tolower(ARGV[2]);ARGV[1]=ARGV[2]=""}
				NR==1 {line=tolower($0);if(line=="awk: " prefix ":1: division by zero")form=1;
					else if(line==tool ": division by zero")form=2;
					else if(line=="awk: " prefix ":1: fatal: division by zero attempted" || line=="awk: " prefix ":1: error: division by zero attempted" || line=="awk: " prefix ": line 1: division by zero")form=1;
					else bad=1}
				NR==2 {if(form!=2 || $0!=" source line number 1")bad=1}
				NR>2 || length($0)>1024 {bad=1}
				END{exit (bad || !form || (form==1 && NR!=1) || (form==2 && NR!=2))}' \
				"$cfmgr_install_context/acquire.syntax.awk" "$cfmgr_install_awk" "$cfmgr_native_error" || return 1
			;;
		*) [ "$cfmgr_acquire_file_mode" != 0755 ] || cfmgr_acquire_zero shell "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $? ;;
		esac
	done 4<"$cfmgr_acquire_records"
	cfmgr_acquire_digest "$cfmgr_acquire_stage/manifest.txt" || return $?
	cfmgr_acquire_manifest_digest=$cfmgr_acquire_digest
	cfmgr_acquire_attached
}

cfmgr_acquire_work() {
	cfmgr_bootstrap_retained && cfmgr_acquire_source && cfmgr_acquire_admit || return $?
	cfmgr_acquire_fetch api "https://api.github.com/repos/$cfmgr_acquire_repository/commits/$cfmgr_acquire_ref" "$cfmgr_install_context/acquire.sha" 41 || return $?
	cfmgr_acquire_text "$cfmgr_install_context/acquire.sha" "$cfmgr_acquire_size" 0 || return $?
	cfmgr_acquire_sha=$("$cfmgr_install_awk" 'NR!=1 || length($0)!=40 || $0~/[^0-9a-fA-F]/ {bad=1} END{if(bad || NR!=1)exit 1;print tolower($0)}' "$cfmgr_install_context/acquire.sha") || return 1
	cfmgr_acquire_stage=$cfmgr_install_context/package
	cfmgr_acquire_zero mkdir "$cfmgr_acquire_stage" || return $?
	{ exec 6<&3; } 3<"$cfmgr_acquire_stage" || return 1
	cfmgr_acquire_stage_owned=1
	cfmgr_acquire_attached || return 1
	: >"$cfmgr_install_context/acquire.files"
	: >"$cfmgr_install_context/acquire.directories"
	printf 'manifest.txt\n' >>"$cfmgr_install_context/acquire.files"
	cfmgr_acquire_fetch raw "https://raw.githubusercontent.com/$cfmgr_acquire_repository/$cfmgr_acquire_sha/manifest.txt" /proc/self/fd/6/manifest.txt 131072 || return $?
	cfmgr_acquire_manifest "$cfmgr_acquire_stage/manifest.txt" || return $?
	while IFS='	' read -r cfmgr_acquire_file_mode cfmgr_acquire_file_size cfmgr_acquire_file_digest cfmgr_acquire_file <&4; do
		case $cfmgr_acquire_file in */*) cfmgr_acquire_directory "${cfmgr_acquire_file%/*}" || return $? ;; esac
		printf '%s\n' "$cfmgr_acquire_file" >>"$cfmgr_install_context/acquire.files" || return 1
		cfmgr_acquire_fetch_limit=$cfmgr_acquire_file_size
		[ "$cfmgr_acquire_fetch_limit" != 0 ] || cfmgr_acquire_fetch_limit=1
		cfmgr_acquire_fetch raw "https://raw.githubusercontent.com/$cfmgr_acquire_repository/$cfmgr_acquire_sha/$cfmgr_acquire_file" "/proc/self/fd/6/$cfmgr_acquire_file" "$cfmgr_acquire_fetch_limit" || return $?
	done 4<"$cfmgr_acquire_records"
	cfmgr_acquire_zero chmod 0644 /proc/self/fd/6/manifest.txt || return $?
	cfmgr_acquire_verify || return $?
	# Recheck retained data and native attachment after all network/validation.
	cfmgr_bootstrap_retained && cfmgr_acquire_attached || return 1
	printf 'CFMGR-ACQUIRE 1 %s %s %s %s %s END\n' "$CFMGR_REPOSITORY" "$cfmgr_acquire_ref" "$cfmgr_acquire_sha" "$cfmgr_acquire_version" "$cfmgr_acquire_manifest_digest" >"$cfmgr_install_context/acquire.provenance" || return 1
	(
		cfmgr_acquire_active=0
		unset cfmgr_acquire_deadline
		CFMGR_VERSION=$cfmgr_acquire_version
		cfmgr_bootstrap_native "$cfmgr_acquire_stage"
	)
}

cfmgr_acquire_cleanup() {
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 3
	cfmgr_acquire_attached || return 1
	if [ "${cfmgr_acquire_stage_owned:-0}" = 1 ]; then
		# Ledger entries are generated only from bounded trusted-parser paths.
		# Refuse unknown objects; never recurse through arbitrary candidate data.
		if [ -f "$cfmgr_install_context/acquire.files" ]; then
			while IFS= read -r cfmgr_acquire_cleanup_file <&4; do
				if [ -e "$cfmgr_acquire_stage/$cfmgr_acquire_cleanup_file" ] || [ -L "$cfmgr_acquire_stage/$cfmgr_acquire_cleanup_file" ]; then
					cfmgr_acquire_cleanup_path "$cfmgr_acquire_cleanup_file" && [ -f "$cfmgr_acquire_stage/$cfmgr_acquire_cleanup_file" ] || return 1
					/bin/rm -f "/proc/self/fd/6/$cfmgr_acquire_cleanup_file" || return 1
				fi
			done 4<"$cfmgr_install_context/acquire.files"
		fi
		if [ -f "$cfmgr_install_context/acquire.directories" ]; then
			"$cfmgr_install_awk" '{line[NR]=$0} END{for(i=NR;i>0;i--)print line[i]}' "$cfmgr_install_context/acquire.directories" >"$cfmgr_install_context/acquire.reverse" || return 1
			while IFS= read -r cfmgr_acquire_cleanup_directory <&4; do
				if [ -e "$cfmgr_acquire_stage/$cfmgr_acquire_cleanup_directory" ] || [ -L "$cfmgr_acquire_stage/$cfmgr_acquire_cleanup_directory" ]; then
					cfmgr_acquire_cleanup_path "$cfmgr_acquire_cleanup_directory" && [ -d "$cfmgr_acquire_stage/$cfmgr_acquire_cleanup_directory" ] || return 1
					/bin/rmdir "/proc/self/fd/6/$cfmgr_acquire_cleanup_directory" || return 1
				fi
			done 4<"$cfmgr_install_context/acquire.reverse"
		fi
		# The pin is retained until only its empty owned directory remains.
		cfmgr_acquire_attached && /bin/rmdir "$cfmgr_acquire_stage" || return 1
		exec 6<&-
		cfmgr_acquire_stage_owned=0
	fi
	cfmgr_bootstrap_cleanup
}

cfmgr_acquire_cleanup_path() {
	cfmgr_acquire_attached || return 1
	cfmgr_bootstrap_path "$cfmgr_acquire_stage/$1" && [ ! -L "$cfmgr_acquire_stage/$1" ] || return 1
	[ "$("$cfmgr_install_readlink" -f "$cfmgr_acquire_stage/$1")" = "$cfmgr_acquire_stage/$1" ] &&
		[ "$("$cfmgr_install_awk" -f "$cfmgr_install_source/modules/lib/mountinfo.awk" "$cfmgr_acquire_stage/$1" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ]
}

cfmgr_acquire_native() (
	[ "$#" = 1 ] || return 2
	cfmgr_acquire_active=1 cfmgr_acquire_stage_owned=0
	cfmgr_bootstrap_native_prepare "$1" acquire || return $?
	cfmgr_prerequisites_now || return 1
	cfmgr_acquire_deadline=$((cfmgr_probe_now + 120))
	if cfmgr_acquire_work; then cfmgr_acquire_status=0; else cfmgr_acquire_status=$?; fi
	if [ "$cfmgr_acquire_status" = 3 ] || { [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; }; then
		printf '[CFMGR] acquire: error: acquisition context retained for recovery\n' >&2
		return 3
	fi
	if [ "${cfmgr_install_interrupted:-0}" != 0 ]; then
		printf '[CFMGR] acquire: error: interrupted acquisition retained for recovery\n' >&2
		return 1
	fi
	if cfmgr_acquire_cleanup; then :; else
		cfmgr_acquire_cleanup_status=$?
		printf '[CFMGR] acquire: error: acquisition cleanup incomplete\n' >&2
		[ "$cfmgr_acquire_cleanup_status" != 3 ] || return 3
		return 1
	fi
	[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
	trap - HUP INT TERM
	return "$cfmgr_acquire_status"
)
