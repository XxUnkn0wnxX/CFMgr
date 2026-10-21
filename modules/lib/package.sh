#!/bin/sh
# shellcheck disable=SC2034,SC2154 # Explicit category inputs and output fields.
# Category owner: package. Sourcing defines functions only.

# ---- package ----
# Installed generation admission. Source-inert; uses entry-owned fixed-native
# primitives only, before configuration, operational libraries or feature imports.

cfmgr_package_inventory() {
	[ "$2" -le 16 ] || return 1
	for cfmgr_package_item in "$1"/* "$1"/.[!.]* "$1"/..?*; do
		[ -e "$cfmgr_package_item" ] || [ -L "$cfmgr_package_item" ] || continue
		cfmgr_package_objects=$((cfmgr_package_objects + 1))
		[ "$cfmgr_package_objects" -le 1024 ] || return 1
		cfmgr_package_relative=${cfmgr_package_item#"$cfmgr_source/"}
		case $cfmgr_package_relative in *[!A-Za-z0-9_./-]* | */../* | */./* | */.. | */.) return 1 ;; esac
		[ ! -L "$cfmgr_package_item" ] || return 1
		if [ -d "$cfmgr_package_item" ]; then
			case $cfmgr_package_paths in *"
$cfmgr_package_relative/"*) ;; *) return 1 ;; esac
			cfmgr_entry_metadata "$cfmgr_package_item" directory || return 1
			cfmgr_package_inventory "$cfmgr_package_item" "$(($2 + 1))" || return 1
		elif [ -f "$cfmgr_package_item" ]; then
			case $cfmgr_package_paths in *"
$cfmgr_package_relative
"*) ;; *) return 1 ;; esac
		else
			return 1
		fi
	done
}

cfmgr_package_verify() {
	# Native grammar only: no payload parser or shell is used as a verifier.
	# shellcheck disable=SC2016
	cfmgr_package_records=$(/usr/bin/awk -v version="$CFMGR_VERSION" '
		BEGIN {FS="\t"}
		NR==1 {if($0!="CFMGR-MANIFEST 1 " version && $0!="CFMGR-MANIFEST 2 " version " 1 2")bad=1;next}
		{
			if(NF!=4 || length($0)>512 || $1!~/^0(644|755)$/ || $2!~/^(0|[1-9][0-9]*)$/ || $2>1048576 ||
			length($3)!=64 || $3~/[^0-9a-f]/ || length($4)>256 || $4!~/^[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)*$/ ||
			$4~/(^|\/)(\.|\.\.)(\/|$)/ || seen[$4]++ || (prev!="" && $4<=prev)){bad=1;next}
			if($4!="cfmgr.sh" && $4!="catalog.txt" && $4!~/^modules\//)bad=1
			if(($4=="cfmgr.sh" && $1!="0755") || ($4=="catalog.txt" && $1!="0644"))bad=1
			path=$4;depth=0;while(sub(/\/[^\/]+$/,"",path)){if(seen[path] || ++depth>16)bad=1}
			prev=$4;total+=$2;count++;if(count>512 || total>16777216)bad=1
			print
		}
		END {
			required="cfmgr.sh catalog.txt modules/backup.sh modules/helpers/worker.sh modules/lib/config.sh modules/lib/execution.sh modules/lib/network.sh modules/lib/package.sh modules/lib/storage.sh modules/manager.sh modules/status.sh"
			n=split(required,names," ");for(i=1;i<=n;i++)if(!seen[names[i]])bad=1
			if(bad || count<2)exit 1
		}' "$cfmgr_source/manifest.txt") || return 1
	cfmgr_package_paths="
$(printf '%s\n' "$cfmgr_package_records" | /usr/bin/awk 'BEGIN{FS="\t"}{print $4}')
"
	cfmgr_package_objects=0
	cfmgr_package_inventory "$cfmgr_source/modules" 0 || return 1
	while IFS="$(printf '\t')" read -r cfmgr_package_mode cfmgr_package_bytes cfmgr_package_sha cfmgr_package_path; do
		case $cfmgr_package_path in cfmgr.sh) cfmgr_package_target="/jffs/scripts/cfmgr.sh" ;; *) cfmgr_package_target=$cfmgr_source/$cfmgr_package_path ;; esac
		cfmgr_entry_file "$cfmgr_package_target" "$cfmgr_package_mode" "$cfmgr_package_bytes" "$cfmgr_package_sha" || return 1
	done <<EOF_RECORDS
$cfmgr_package_records
EOF_RECORDS
	cfmgr_entry_framing "$cfmgr_source/catalog.txt" || return 1
	# shellcheck disable=SC2016
	/usr/bin/awk -v version="$CFMGR_VERSION" 'BEGIN {FS="\t"}
		NR==FNR {if($4~/^modules\//)expected[$4]=1;next}
		FNR==1 {if($0!="CFMGR-CATALOG 1 " version)bad=1;next}
		{kind=($1~/^modules\/lib\//?"library":($1~/^modules\/helpers\//?"helper":"data"));if(NF!=2 || !expected[$1] || seen[$1]++ || $2!=kind || (prev!="" && $1<=prev))bad=1;prev=$1}
		END {for(path in expected)if(!seen[path])bad=1;if(bad)exit 1}' "$cfmgr_source/manifest.txt" "$cfmgr_source/catalog.txt"
}

# ---- acquire ----
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
			[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_acquire_stage" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ] || return 1
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
	curl-features | ca-pem | manifest | catalog | entry | extract | awk | awk-file | text) cfmgr_acquire_tool=$cfmgr_install_awk ;;
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
		"$cfmgr_install_source/modules/helpers/worker.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
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
			cfmgr_acquire_run awk-file "$cfmgr_install_context/acquire.syntax.awk" "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $?
			cfmgr_acquire_awk_receipt || return 1
			;;
		*) [ "$cfmgr_acquire_file_mode" != 0755 ] || cfmgr_acquire_zero shell "$cfmgr_acquire_stage/$cfmgr_acquire_file" || return $? ;;
		esac
	done 4<"$cfmgr_acquire_records"
	for cfmgr_acquire_parser in config status status_native mountinfo backup_payload backup_history backup_inventory backup_archive_control backup_cloud_writer backup_manifest backup_payload_index backup_payload_match backup_pem backup_tar backup_yaml; do
		cfmgr_acquire_run extract "$cfmgr_acquire_stage" "$cfmgr_install_source/modules/lib/package.sh" "$cfmgr_acquire_parser" || return $?
		[ "$cfmgr_native_exit" = 0 ] && [ ! -s "$cfmgr_native_error" ] || return 1
		cfmgr_acquire_program=''
		while IFS= read -r cfmgr_acquire_program_line; do
			cfmgr_acquire_program="$cfmgr_acquire_program$cfmgr_acquire_program_line
"
			case $((${#cfmgr_acquire_program} <= 98304)) in 1) ;; *) return 1 ;; esac
		done <"$cfmgr_native_output"
		[ -n "$cfmgr_acquire_program" ] || return 1
		cfmgr_acquire_run awk "$cfmgr_install_context/acquire.syntax.awk" "$cfmgr_acquire_program" || return $?
		cfmgr_acquire_awk_receipt || return 1
	done

	cfmgr_acquire_digest "$cfmgr_acquire_stage/manifest.txt" || return $?
	cfmgr_acquire_manifest_digest=$cfmgr_acquire_digest
	cfmgr_acquire_attached
}

# Validate the sole trusted fatal-prefix receipt for either parser form.
cfmgr_acquire_awk_receipt() {

	[ "$cfmgr_native_exit" -ne 0 ] || return 1
	[ "$("$cfmgr_install_awk" 'NR!=1 || $0!="CFMGR-AWK-PARSED 1" {bad=1} END{if(bad || NR!=1)exit 1;print "ok"}' "$cfmgr_native_output")" = ok ] || return 1
	# BusyBox fatal errors bypass END. Host wording is allowed only when
	# equally exact/bounded; the actual vendor case is required in CI.
	"$cfmgr_install_awk" 'BEGIN{prefix=tolower(ARGV[1]);tool=tolower(ARGV[2]);ARGV[1]=ARGV[2]=""}
				NR==1 {line=tolower($0);if(line=="awk: cmd. line:1: division by zero" || line=="awk: cmd. line:1: fatal: division by zero attempted" || line=="awk: cmd. line:1: error: division by zero attempted" || line=="awk: cmd. line:1: division by zero attempted" || line=="awk: " prefix ":1: division by zero")form=1;
					else if(line==tool ": division by zero")form=2;
					else if(line=="awk: " prefix ":1: fatal: division by zero attempted" || line=="awk: " prefix ":1: error: division by zero attempted" || line=="awk: " prefix ": line 1: division by zero")form=1;
					else bad=1}
				NR==2 {if(form!=2 || $0!=" source line number 1")bad=1}
				NR>2 || length($0)>1024 {bad=1}
				END{exit (bad || !form || (form==1 && NR!=1) || (form==2 && NR!=2))}' \
		"$cfmgr_install_context/acquire.syntax.awk" "$cfmgr_install_awk" "$cfmgr_native_error" || return 1
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
		[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_acquire_stage/$1" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ]
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

# ---- bootstrap ----
# shellcheck disable=SC2034,SC2154 # Imported/exported finite controller fields and listing columns.
# Trusted-local fresh installation only. All functions are inert when sourced.
# The internal transaction accepts already-admitted roots/tools, never public
# environment overrides. Production admission always uses the fixed Merlin paths.

cfmgr_bootstrap_path() {
	[ "$#" -eq 1 ] && [ -n "$1" ] && [ "${#1}" -le 4096 ] || return 1
	case $1 in /*) ;; *) return 1 ;; esac
	case $1 in *[!\ -~]* | *\\* | *//* | */./* | */../* | */. | */.. | */) return 1 ;; esac
}

# Inputs/results from the explicitly imported prerequisites library.
# shellcheck disable=SC2154
cfmgr_bootstrap_action() {
	cfmgr_install_action=$1
	cfmgr_bootstrap_attached || return 1
	case $1 in
	install-sha) cfmgr_install_tool=$cfmgr_install_sha ;;
	install-wc) cfmgr_install_tool=$cfmgr_install_wc ;;
	install-ls) cfmgr_install_tool=$cfmgr_install_ls ;;
	install-copy) cfmgr_install_tool=$cfmgr_install_cp ;;
	install-remove) cfmgr_install_tool=/bin/rm ;;
	install-rename | install-publish) cfmgr_install_tool=$cfmgr_install_mv ;;
	install-mkdir-*) cfmgr_install_tool=$cfmgr_install_mkdir ;;
	install-chmod-*) cfmgr_install_tool=$cfmgr_install_chmod ;;
	install-flush) cfmgr_install_tool=$cfmgr_install_fsync ;;
	install-config) cfmgr_install_tool=$cfmgr_install_jq ;;
	install-config-check) cfmgr_install_tool=$cfmgr_install_awk ;;
	install-df) cfmgr_install_tool=$cfmgr_install_df ;;
	install-nvram) cfmgr_install_tool=$cfmgr_install_nvram ;;
	*) return 2 ;;
	esac
	shift
	cfmgr_prerequisites_run "$cfmgr_install_action" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/worker.sh" "$cfmgr_install_env" \
		"$cfmgr_install_awk" "$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_install_tool" "$@" || return $?
	cfmgr_install_output=$cfmgr_probe_stdout
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	case $cfmgr_install_action in install-sha | install-wc | install-ls | install-config | install-df | install-nvram) ;;
	*) [ ! -s "$cfmgr_probe_stdout" ] || return 1 ;;
	esac
	cfmgr_bootstrap_attached
}

cfmgr_bootstrap_size() {
	cfmgr_bootstrap_action install-wc "$1" || return $?
	IFS=' 	' read -r cfmgr_install_size cfmgr_install_extra <"$cfmgr_install_output" || return 1
	[ -z "$cfmgr_install_extra" ] || return 1
	case $cfmgr_install_size in '' | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_install_size}" -le 9 ]
}

cfmgr_bootstrap_digest() {
	cfmgr_bootstrap_action install-sha "$1" || return $?
	cfmgr_install_digest_output=$cfmgr_install_output
	cfmgr_bootstrap_size "$cfmgr_install_digest_output" || return $?
	[ "$cfmgr_install_size" -eq 68 ] || return 1
	IFS=' ' read -r cfmgr_install_digest cfmgr_install_dash cfmgr_install_extra <"$cfmgr_install_digest_output" || return 1
	[ "$cfmgr_install_dash" = - ] && [ -z "$cfmgr_install_extra" ] && [ "${#cfmgr_install_digest}" -eq 64 ] || return 1
	case $cfmgr_install_digest in *[!0-9a-f]*) return 1 ;; esac
}

# Listing columns not used by policy still have explicit receiving fields.
# shellcheck disable=SC2034
cfmgr_bootstrap_metadata() {
	cfmgr_bootstrap_action install-ls "$1" || return $?
	IFS=' ' read -r cfmgr_install_mode cfmgr_install_links cfmgr_install_uid cfmgr_install_gid cfmgr_install_rest <"$cfmgr_install_output" || return 1
	[ "$cfmgr_install_uid" = "$2" ] || return 1
	case $cfmgr_install_mode in *'@') cfmgr_install_mode=${cfmgr_install_mode%@} ;; esac
	case $3:$cfmgr_install_mode in
	0644:-rw-r--r-- | 0755:-rwxr-xr-x | 0600:-rw------- | private:drwx------ | public:drwxr-xr-x) return 0 ;;
	protected:d????????? | protected:-?????????)
		case $cfmgr_install_mode in ?????w???? | ????????w?) return 1 ;; esac
		return 0
		;;
	*) return 1 ;;
	esac
}

cfmgr_bootstrap_retained() {
	for cfmgr_install_retained in "$cfmgr_install_jffs/addons/CFMgr.d" "$cfmgr_install_jffs/scripts/cfmgr.sh" \
		"$cfmgr_install_opt/var/lib/cfmgr" "$cfmgr_install_opt/var/tmp/cfmgr" \
		"$cfmgr_install_opt/etc/cloudflared" "$cfmgr_install_opt/bin/cloudflared"; do
		[ ! -e "$cfmgr_install_retained" ] && [ ! -L "$cfmgr_install_retained" ] || return 1
	done
}

cfmgr_bootstrap_walk() {
	[ "$3" -le 16 ] || return 1
	for cfmgr_install_walk_item in "$2"/* "$2"/.[!.]* "$2"/..?*; do
		[ -e "$cfmgr_install_walk_item" ] || [ -L "$cfmgr_install_walk_item" ] || continue
		[ ! -L "$cfmgr_install_walk_item" ] || return 1
		cfmgr_install_walk_relative=${cfmgr_install_walk_item#"$1"/}
		[ "${#cfmgr_install_walk_relative}" -le 256 ] || return 1
		case $cfmgr_install_walk_relative in *[!A-Za-z0-9_./-]* | */../* | */./*) return 1 ;; esac
		cfmgr_install_walk_count=$((cfmgr_install_walk_count + 1))
		[ "$cfmgr_install_walk_count" -le 1024 ] || return 1
		if [ -d "$cfmgr_install_walk_item" ]; then
			printf '%s/\n' "$cfmgr_install_walk_relative"
			cfmgr_bootstrap_walk "$1" "$cfmgr_install_walk_item" "$(($3 + 1))" || return 1
		elif [ -f "$cfmgr_install_walk_item" ]; then
			printf '%s\n' "$cfmgr_install_walk_relative"
		else return 1; fi
	done
}

cfmgr_bootstrap_inventory() {
	# Enumerate only the frozen package mapping; repository developer files are not
	# package inputs. Hidden/unlisted files inside modules remain detectable.
	[ -f "$1/cfmgr.sh" ] && [ ! -L "$1/cfmgr.sh" ] &&
		[ -f "$1/catalog.txt" ] && [ ! -L "$1/catalog.txt" ] &&
		[ -d "$1/modules" ] && [ ! -L "$1/modules" ] || return 1
	cfmgr_install_walk_count=3
	{
		printf '%s\n' cfmgr.sh catalog.txt modules/
		cfmgr_bootstrap_walk "$1" "$1/modules" 0
	} >"$cfmgr_install_context/inventory"
}

cfmgr_bootstrap_manifest() {
	# Admit both live metadata files before reading either grammar. Parse private
	# bounded copies so subsequent live/staged hash checks bind the parsed bytes.
	for cfmgr_install_passive in manifest.txt catalog.txt; do
		[ -f "$cfmgr_install_source/$cfmgr_install_passive" ] && [ ! -L "$cfmgr_install_source/$cfmgr_install_passive" ] || return 1
		cfmgr_bootstrap_metadata "$cfmgr_install_source/$cfmgr_install_passive" "$cfmgr_install_owner" 0644 || return $?
		cfmgr_bootstrap_size "$cfmgr_install_source/$cfmgr_install_passive" || return $?
		[ "$cfmgr_install_size" -gt 0 ] && [ "$cfmgr_install_size" -le 131072 ] || return 1
	done
	for cfmgr_install_passive in manifest.txt catalog.txt; do
		[ ! -e "$cfmgr_install_context/$cfmgr_install_passive.snapshot" ] && [ ! -L "$cfmgr_install_context/$cfmgr_install_passive.snapshot" ] || return 1
		cfmgr_bootstrap_action install-copy "$cfmgr_install_source/$cfmgr_install_passive" "$cfmgr_install_context/$cfmgr_install_passive.snapshot" || return $?
	done
	cfmgr_bootstrap_manifest_records "$cfmgr_install_context/manifest.txt.snapshot" "$cfmgr_install_context/catalog.txt.snapshot" || return $?
	cfmgr_bootstrap_inventory "$cfmgr_install_source" || return 1
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { FS="\t" } NR==FNR {
			expected[$4]=1; path=$4
			while (sub(/\/[^\/]+$/,"",path)) expected[path "/"]=1
			next
		}
		{ if (!expected[$0] || actual[$0]++) bad=1 }
		END { for (path in expected) if (!actual[path]) bad=1; if (bad) exit 1 }' "$cfmgr_install_context/records" "$cfmgr_install_context/inventory" || return 1
	while IFS= read -r cfmgr_install_inventory_item; do
		case $cfmgr_install_inventory_item in */)
			cfmgr_bootstrap_metadata "$cfmgr_install_source/${cfmgr_install_inventory_item%/}" "$cfmgr_install_owner" protected || return $?
			;;
		esac
	done <"$cfmgr_install_context/inventory"
	cfmgr_bootstrap_digest "$cfmgr_install_context/manifest.txt.snapshot" || return $?
	cfmgr_install_manifest_digest=$cfmgr_install_digest
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative; do
		if [ "$cfmgr_install_relative" = catalog.txt ]; then
			[ "$cfmgr_install_catalog_bytes" -eq "$cfmgr_install_expected_size" ] || return 1
			cfmgr_bootstrap_digest "$cfmgr_install_context/catalog.txt.snapshot" || return $?
			[ "$cfmgr_install_digest" = "$cfmgr_install_expected_digest" ] || return 1
		fi
		cfmgr_bootstrap_file "$cfmgr_install_source/$cfmgr_install_relative" || return $?
	done <"$cfmgr_install_context/records"
}

cfmgr_bootstrap_manifest_records() {
	# Explicit private snapshots only. Direct admitted native tools are required
	# here: retained structural admission precedes storage/tool repair supervision.
	[ "$#" -eq 2 ] || return 2
	for cfmgr_install_passive in "$1" "$2"; do
		[ -f "$cfmgr_install_passive" ] && [ ! -L "$cfmgr_install_passive" ] || return 1
		cfmgr_install_counts=$(LC_ALL=C "$cfmgr_install_wc" -l -c <"$cfmgr_install_passive") || return 1
		IFS=' 	' read -r cfmgr_install_lines cfmgr_install_bytes cfmgr_install_extra <<EOF_COUNTS
$cfmgr_install_counts
EOF_COUNTS
		[ -z "$cfmgr_install_extra" ] || return 1
		case $cfmgr_install_lines:$cfmgr_install_bytes in *[!0-9:]* | :* | *:) return 1 ;; esac
		[ "${#cfmgr_install_lines}" -le 6 ] && [ "${#cfmgr_install_bytes}" -le 6 ] || return 1
		[ "$cfmgr_install_bytes" -gt 0 ] && [ "$cfmgr_install_bytes" -le 131072 ] || return 1
		if [ "$cfmgr_install_passive" = "$1" ]; then
			cfmgr_install_manifest_bytes=$cfmgr_install_bytes cfmgr_install_manifest_lines=$cfmgr_install_lines
		else
			cfmgr_install_catalog_bytes=$cfmgr_install_bytes cfmgr_install_catalog_lines=$cfmgr_install_lines
		fi
	done
	# Reconstruct bytes and compare LF counts independently of AWK record handling:
	# missing final LF or implementations discarding NUL cannot become valid data.
	# shellcheck disable=SC2016
	LC_ALL=C "$cfmgr_install_awk" '
		BEGIN { FS="\t"; version=ARGV[1]; expected_bytes=ARGV[2]; expected_lines=ARGV[3]; ARGV[1]=ARGV[2]=ARGV[3]="" }
		{ bytes+=length($0)+1; if ($0~/[^\t -~]/) bad=1 }
		NR==1 { modern=($0=="CFMGR-MANIFEST 2 " version " 1 2"); if ($0 != "CFMGR-MANIFEST 1 " version && !modern) bad=1; next }
		{
			if (NF!=4 || length($0)>512 || $1 !~ /^0(644|755)$/ ||
			    $2 !~ /^(0|[1-9][0-9]*)$/ || $2>1048576 ||
			    length($3)!=64 || $3 ~ /[^0-9a-f]/ || length($4)>256 ||
			    $4 !~ /^[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)*$/ ||
			    $4 ~ /(^|\/)(\.|\.\.)(\/|$)/ || seen[$4]++) { bad=1; next }
			if ($4!="cfmgr.sh" && $4!="catalog.txt" && $4!~/^modules\//) bad=1
			if (previous!="" && $4<=previous) bad=1
			previous=$4; total+=$2; count++
			if (count>512 || total>16777216) bad=1
			print
		}
		END {
			required="cfmgr.sh catalog.txt modules/backup.sh modules/helpers/worker.sh modules/lib/config.sh modules/lib/execution.sh modules/lib/network.sh modules/lib/package.sh modules/lib/storage.sh modules/manager.sh modules/status.sh"
			if (modern) required=required " modules/backup.sh modules/lib/package.sh"
			n=split(required,names," "); for (i=1;i<=n;i++) if (!seen[names[i]]) bad=1
			if (bad || count<2 || bytes!=expected_bytes || NR!=expected_lines) exit 1
		}
	' "$CFMGR_VERSION" "$cfmgr_install_manifest_bytes" "$cfmgr_install_manifest_lines" "$1" >"$cfmgr_install_context/records" || return 1
	# Catalog is passive schema/versioned data matching the complete module set.
	# shellcheck disable=SC2016
	LC_ALL=C "$cfmgr_install_awk" 'BEGIN { FS="\t"; version=ARGV[1]; expected_bytes=ARGV[2]; expected_lines=ARGV[3]; ARGV[1]=ARGV[2]=ARGV[3]="" }
		NR==FNR { if ($4~/^modules\//) expected[$4]=1; next }
		{ bytes+=length($0)+1; lines++; if ($0~/[^\t -~]/) bad=1 }
		FNR==1 { if ($0!="CFMGR-CATALOG 1 " version) bad=1; next }
		{
			kind=($1~/^modules\/lib\// ? "library" : ($1~/^modules\/helpers\// ? "helper" : "data"))
			if (NF!=2 || !expected[$1] || seen[$1]++ || $2!=kind) bad=1
		}
		END { for (path in expected) if (!seen[path]) bad=1; if (bad || bytes!=expected_bytes || lines!=expected_lines) exit 1 }
	' "$CFMGR_VERSION" "$cfmgr_install_catalog_bytes" "$cfmgr_install_catalog_lines" "$cfmgr_install_context/records" "$2" || return 1
}

cfmgr_bootstrap_file() {
	[ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_bootstrap_metadata "$1" "$cfmgr_install_owner" "$cfmgr_install_expected_mode" || return $?
	cfmgr_bootstrap_size "$1" || return $?
	[ "$cfmgr_install_size" -eq "$cfmgr_install_expected_size" ] || return 1
	cfmgr_bootstrap_digest "$1" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_install_expected_digest" ]
}

cfmgr_bootstrap_record() {
	cfmgr_bootstrap_metadata "$1" "$cfmgr_install_owner" 0600 || return $?
	cfmgr_bootstrap_size "$1" || return $?
	cfmgr_install_record_expected="CFMGR-SETUP 1 $CFMGR_VERSION $2"
	[ "$cfmgr_install_size" -eq "$((${#cfmgr_install_record_expected} + 1))" ] || return 1
	IFS= read -r cfmgr_install_record_actual <"$1" || return 1
	[ "$cfmgr_install_record_actual" = "$cfmgr_install_record_expected" ]
}

cfmgr_bootstrap_flush() {
	cfmgr_bootstrap_attached || return 1
	[ ! -L "$1" ] && { [ -f "$1" ] || [ -d "$1" ]; } || return 1
	exec 3<"$1" || return 1
	if cfmgr_bootstrap_action install-flush; then
		exec 3<&-
		return 0
	else
		cfmgr_install_failure=$?
	fi
	# An unresolved child keeps its inherited descriptor and the installation guard.
	exec 3<&-
	return "${cfmgr_install_failure:-1}"
}

cfmgr_bootstrap_directories() {
	set -- "${1%/*}"
	[ "$1" != "$cfmgr_install_support" ] || return 0
	if [ -e "$1" ] || [ -L "$1" ]; then
		[ -d "$1" ] && [ ! -L "$1" ] || return 1
		return 0
	fi
	cfmgr_bootstrap_directories "$1" || return $?
	cfmgr_bootstrap_action install-mkdir-public "$1" || return $?
	cfmgr_bootstrap_flush "${1%/*}"
}

cfmgr_bootstrap_copy() {
	cfmgr_bootstrap_action install-copy "$1" "$2" || return $?
	case $3 in 0600) cfmgr_install_chmod_mode=private ;; 0644) cfmgr_install_chmod_mode='readonly' ;; 0755) cfmgr_install_chmod_mode=executable ;; *) return 2 ;; esac
	cfmgr_bootstrap_action "install-chmod-$cfmgr_install_chmod_mode" "$2" || return $?
	cfmgr_bootstrap_flush "$2" || return $?
	cfmgr_bootstrap_flush "${2%/*}"
}

# Callers calculate their reserve from already validated package/config sizes.
cfmgr_bootstrap_space() {
	cfmgr_bootstrap_action install-df "$1" || return $?
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { need=ARGV[1]; ARGV[1]="" }
		NR==2 { n++; if ($4 !~ /^[0-9]+$/ || $4<need) bad=1 }
		END { if (n!=1 || bad) exit 1 }' "$2" "$cfmgr_install_output"
}

# Exports the installation result and recovery phase to the trusted entry.
# shellcheck disable=SC2034
cfmgr_bootstrap_transaction() {
	# SOURCE JFFS OPT RAM OWNER SH ENV AWK READLINK SLEEP WC LS FSYNC
	# MKDIR CP CHMOD MV SHA JQ UUID FILESYSTEM FSROOT ENTWARE_RELATIVE DF
	[ "$#" -eq 24 ] || return 2
	cfmgr_install_source=$1 cfmgr_install_jffs=$2 cfmgr_install_opt=$3 cfmgr_install_context=$4 cfmgr_install_owner=$5
	cfmgr_install_sh=$6 cfmgr_install_env=$7 cfmgr_install_awk=$8 cfmgr_install_readlink=$9
	shift 9
	cfmgr_install_sleep=$1 cfmgr_install_wc=$2 cfmgr_install_ls=$3 cfmgr_install_fsync=$4
	cfmgr_install_mkdir=$5 cfmgr_install_cp=$6 cfmgr_install_chmod=$7 cfmgr_install_mv=$8 cfmgr_install_sha=$9
	shift 9
	cfmgr_install_jq=$1 cfmgr_install_uuid=$2 cfmgr_install_filesystem=$3 cfmgr_install_fsroot=$4 cfmgr_install_relative_opt=$5 cfmgr_install_df=$6
	cfmgr_probe_serial=${cfmgr_probe_serial:-0}
	cfmgr_install_result=preflight
	cfmgr_install_support=$cfmgr_install_jffs/addons/CFMgr.d
	for cfmgr_install_argument in "$cfmgr_install_source" "$cfmgr_install_jffs" "$cfmgr_install_opt" "$cfmgr_install_context"; do
		cfmgr_bootstrap_path "$cfmgr_install_argument" && [ -d "$cfmgr_install_argument" ] && [ ! -L "$cfmgr_install_argument" ] || return 2
	done
	case $cfmgr_install_owner in '' | *[!0-9]*) return 2 ;; esac
	for cfmgr_install_argument in "$cfmgr_install_sh" "$cfmgr_install_env" "$cfmgr_install_awk" "$cfmgr_install_readlink" "$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_install_ls" "$cfmgr_install_fsync" "$cfmgr_install_mkdir" "$cfmgr_install_cp" "$cfmgr_install_chmod" "$cfmgr_install_mv" "$cfmgr_install_df"; do
		cfmgr_bootstrap_path "$cfmgr_install_argument" && [ -f "$cfmgr_install_argument" ] && [ -x "$cfmgr_install_argument" ] || return 2
	done
	for cfmgr_install_argument in "$cfmgr_install_sha" "$cfmgr_install_jq"; do
		cfmgr_bootstrap_path "$cfmgr_install_argument" && [ -f "$cfmgr_install_argument" ] && [ -x "$cfmgr_install_argument" ] || return 1
	done
	cfmgr_bootstrap_retained && cfmgr_bootstrap_attached || return 1
	cfmgr_bootstrap_metadata "$cfmgr_install_source" "$cfmgr_install_owner" protected &&
		cfmgr_bootstrap_metadata "$cfmgr_install_jffs" "$cfmgr_install_owner" protected || return $?
	cfmgr_bootstrap_manifest || return $?
	# The validated inventory bounds the sum. Reserve two copies plus native
	# erase-block/config/metadata allowance, rather than requiring an unused maximum.
	# shellcheck disable=SC2016
	cfmgr_install_needed=$("$cfmgr_install_awk" '{ total+=$2 } END { print int((2*total+262144+1023)/1024) }' "$cfmgr_install_context/records") || return 1
	cfmgr_bootstrap_space "$cfmgr_install_jffs" "$cfmgr_install_needed" || return $?
	# Prepare defaults only after retained-state and package/tool admission. They
	# remain private RAM data until the claimed installation guard is durable.
	cfmgr_bootstrap_action install-config "$cfmgr_install_source" "$CFMGR_REPOSITORY" "$CFMGR_BRANCH" "$cfmgr_install_uuid" "$cfmgr_install_filesystem" "$cfmgr_install_fsroot" "$cfmgr_install_relative_opt" || return $?
	cfmgr_install_config=$cfmgr_install_output
	cfmgr_bootstrap_size "$cfmgr_install_config" || return $?
	[ "$cfmgr_install_size" -gt 0 ] && [ "$cfmgr_install_size" -le 65536 ] || return 1
	cfmgr_install_config_bytes=$cfmgr_install_size
	cfmgr_bootstrap_action install-config-check "$cfmgr_install_config" "$cfmgr_install_source" "$cfmgr_install_config_bytes" || return $?
	cfmgr_bootstrap_digest "$cfmgr_install_config" || return $?
	cfmgr_install_config_digest=$cfmgr_install_digest
	cfmgr_bootstrap_retained && cfmgr_bootstrap_attached || return 1
	for cfmgr_install_parent in "$cfmgr_install_jffs/scripts" "$cfmgr_install_jffs/addons"; do
		if [ -e "$cfmgr_install_parent" ] || [ -L "$cfmgr_install_parent" ]; then
			[ -d "$cfmgr_install_parent" ] && [ ! -L "$cfmgr_install_parent" ] || return 1
			cfmgr_bootstrap_metadata "$cfmgr_install_parent" "$cfmgr_install_owner" protected || return $?
		else
			cfmgr_bootstrap_action install-mkdir-public "$cfmgr_install_parent" || return $?
			cfmgr_bootstrap_flush "$cfmgr_install_jffs" || return $?
		fi
	done
	cfmgr_bootstrap_retained && cfmgr_bootstrap_attached || return 1
	# Atomic private directory claim is itself a no-reset/concurrency/crash guard.
	cfmgr_bootstrap_action install-mkdir-private "$cfmgr_install_support" || return $?
	cfmgr_install_result=recovery-required
	cfmgr_bootstrap_flush "$cfmgr_install_support" && cfmgr_bootstrap_flush "$cfmgr_install_jffs/addons" || return $?
	(
		umask 077
		printf 'CFMGR-SETUP 1 %s installing\n' "$CFMGR_VERSION" >"$cfmgr_install_context/setup.installing"
	) || return 1
	cfmgr_bootstrap_copy "$cfmgr_install_context/setup.installing" "$cfmgr_install_support/setup-state" 0600 || return $?
	cfmgr_bootstrap_record "$cfmgr_install_support/setup-state" installing || return $?
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative; do
		case $cfmgr_install_relative in cfmgr.sh)
			cfmgr_install_entry_mode=$cfmgr_install_expected_mode
			cfmgr_install_entry_size=$cfmgr_install_expected_size
			cfmgr_install_entry_digest=$cfmgr_install_expected_digest
			cfmgr_install_destination=$cfmgr_install_support/entry.stage
			;;
		*) cfmgr_install_destination=$cfmgr_install_support/$cfmgr_install_relative ;; esac
		cfmgr_bootstrap_directories "$cfmgr_install_destination" || return $?
		cfmgr_bootstrap_copy "$cfmgr_install_source/$cfmgr_install_relative" "$cfmgr_install_destination" "$cfmgr_install_expected_mode" || return $?
		cfmgr_bootstrap_file "$cfmgr_install_destination" || return $?
	done <"$cfmgr_install_context/records"
	cfmgr_bootstrap_copy "$cfmgr_install_source/manifest.txt" "$cfmgr_install_support/manifest.txt" 0644 || return $?
	cfmgr_bootstrap_digest "$cfmgr_install_support/manifest.txt" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_install_manifest_digest" ] || return 1
	cfmgr_bootstrap_copy "$cfmgr_install_config" "$cfmgr_install_support/config" 0600 || return $?
	cfmgr_bootstrap_metadata "$cfmgr_install_support/config" "$cfmgr_install_owner" 0600 || return $?
	cfmgr_bootstrap_digest "$cfmgr_install_support/config" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_install_config_digest" ] || return 1
	cfmgr_bootstrap_action install-config-check "$cfmgr_install_support/config" "$cfmgr_install_source" "$cfmgr_install_config_bytes" || return $?
	cfmgr_install_walk_count=0
	cfmgr_bootstrap_walk "$cfmgr_install_support" "$cfmgr_install_support" 0 >"$cfmgr_install_context/staged.inventory" || return 1
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { FS="\t"; expected["config"]=1; expected["setup-state"]=1; expected["manifest.txt"]=1 }
		NR==FNR {
			path=$4; if (path=="cfmgr.sh") path="entry.stage"
			expected[path]=1
			while (sub(/\/[^\/]+$/,"",path)) expected[path "/"]=1
			next
		}
		{ if (!expected[$0] || actual[$0]++) bad=1 }
		END { for (path in expected) if (!actual[path]) bad=1; if (bad) exit 1 }
	' "$cfmgr_install_context/records" "$cfmgr_install_context/staged.inventory" || return 1
	cfmgr_bootstrap_attached || return 1
	cfmgr_bootstrap_action install-publish "$cfmgr_install_support/entry.stage" "$cfmgr_install_jffs/scripts/cfmgr.sh" || return $?
	[ ! -e "$cfmgr_install_support/entry.stage" ] || return 1
	cfmgr_bootstrap_flush "$cfmgr_install_jffs/scripts/cfmgr.sh" && cfmgr_bootstrap_flush "$cfmgr_install_jffs/scripts" || return $?
	cfmgr_install_expected_mode=$cfmgr_install_entry_mode
	cfmgr_install_expected_size=$cfmgr_install_entry_size
	cfmgr_install_expected_digest=$cfmgr_install_entry_digest
	cfmgr_bootstrap_file "$cfmgr_install_jffs/scripts/cfmgr.sh" || return $?
	# Keep the durable completion guard through the last record's copy, flush and
	# readback. Retained launch must reject even a complete-looking partial commit.
	(
		umask 077
		printf 'CFMGR-SETUP 1 %s complete\n' "$CFMGR_VERSION" >"$cfmgr_install_context/setup.complete"
	) || return 1
	cfmgr_bootstrap_copy "$cfmgr_install_context/setup.complete" "$cfmgr_install_support/.setup.complete" 0600 || return $?
	cfmgr_bootstrap_record "$cfmgr_install_support/.setup.complete" complete || return $?
	cfmgr_bootstrap_copy "$cfmgr_install_context/setup.complete" "$cfmgr_install_support/setup-state" 0600 || return $?
	cfmgr_bootstrap_record "$cfmgr_install_support/setup-state" complete || return $?
	cfmgr_bootstrap_action install-remove "$cfmgr_install_support/.setup.complete" || return $?
	[ ! -e "$cfmgr_install_support/.setup.complete" ] && [ ! -L "$cfmgr_install_support/.setup.complete" ] || return 1
	# Data and record are verified before removal. Failure here is uncertainty
	# clearing the guard, never permission for a fallible rollback of valid state.
	if cfmgr_bootstrap_flush "$cfmgr_install_support"; then :; else
		cfmgr_install_failure=$?
		printf '[CFMGR] install: error: completion guard cleanup could not be verified\n' >&2
		return "$cfmgr_install_failure"
	fi
	cfmgr_install_result=complete
}

cfmgr_bootstrap_signals() {
	cfmgr_install_interrupted=0
	trap 'cfmgr_install_interrupted=1' HUP INT TERM
}

cfmgr_bootstrap_attached() {
	cfmgr_storage_attached && cfmgr_bootstrap_native_attached
}

# Native-only admission is reserved for finite launch/report pre-storage probes.
# Native BusyBox test -ef is verified by the descriptor and kernel fixtures.
# shellcheck disable=SC3013
cfmgr_bootstrap_native_attached() {
	[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
	if [ "${cfmgr_launch_guard_owned:-0}" = 1 ]; then cfmgr_launch_guard_attachment || return 1; fi
	if [ "${cfmgr_launch_migrating:-0}" = 1 ]; then cfmgr_launch_original_attached || return 1; fi
	# Reject a replaced source before using even its mount parser.
	[ ! -L "$cfmgr_install_source" ] && [ ! -L "$cfmgr_install_jffs" ] &&
		[ "$cfmgr_install_source" -ef "/proc/self/fd/${cfmgr_install_source_fd:-9}" ] &&
		[ "$cfmgr_install_jffs" -ef /proc/self/fd/8 ] || return 1
	[ "$("$cfmgr_install_readlink" -f "$cfmgr_install_source")" = "$cfmgr_install_source" ] &&
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_install_jffs")" = "$cfmgr_install_jffs" ] || return 1
	if [ -n "${cfmgr_install_context:-}" ]; then
		case $cfmgr_install_context_fd in 0 | 3 | 5 | 9) ;; *) return 1 ;; esac
		[ ! -L "$cfmgr_install_context" ] && [ "$cfmgr_install_context" -ef "/proc/self/fd/$cfmgr_install_context_fd" ] || return 1
		[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_install_context" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ] || return 1
	fi
	for cfmgr_install_attachment_path in "$cfmgr_install_jffs" "$cfmgr_install_jffs/scripts" "$cfmgr_install_jffs/addons"; do
		if [ -e "$cfmgr_install_attachment_path" ] || [ -L "$cfmgr_install_attachment_path" ]; then
			[ -d "$cfmgr_install_attachment_path" ] && [ ! -L "$cfmgr_install_attachment_path" ] || return 1
			[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_install_attachment_path" /proc/self/mountinfo)" = "$cfmgr_install_jffs_snapshot" ] || return 1
		fi
	done
}

cfmgr_prerequisites_attachment_ok() {
	cfmgr_bootstrap_attached
}

# Storage identity fields are supplied by the explicit storage library.
# shellcheck disable=SC2154
cfmgr_bootstrap_admit_tool() {
	[ "$#" -eq 1 ] && [ -f "$1" ] || return 1
	cfmgr_install_resolved=$("$cfmgr_install_readlink" -f "$1") || return 1
	cfmgr_bootstrap_path "$cfmgr_install_resolved" || return 1
	case $cfmgr_install_resolved in "$cfmgr_storage_opt"/*) ;; *) return 1 ;; esac
	[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_install_resolved" /proc/self/mountinfo)" = "$cfmgr_storage_snapshot" ] || return 1
	cfmgr_bootstrap_metadata "$cfmgr_install_resolved" 0 protected || return $?
	cfmgr_install_resolved=${cfmgr_install_resolved%/*}
	while :; do
		cfmgr_bootstrap_metadata "$cfmgr_install_resolved" 0 protected || return $?
		[ "$cfmgr_install_resolved" != "$cfmgr_storage_opt" ] || break
		cfmgr_install_resolved=${cfmgr_install_resolved%/*}
	done
}

# Fixed prerequisite admission defers optional tools until their consumer needs
# them. Missing safe tools are repair candidates; unsafe paths are fatal.
cfmgr_prerequisites_admit_tool() {
	[ "$#" -eq 1 ] || return 2
	case "$1" in /opt/bin/jq | /opt/bin/timeout | /opt/bin/sha256sum | /opt/bin/flock | /opt/bin/dig | /opt/sbin/syslog-ng | /opt/sbin/logrotate) ;; *) return 2 ;; esac
	[ -e "$1" ] || [ -L "$1" ] || return 1
	if cfmgr_bootstrap_admit_tool "$1"; then
		[ -x "$1" ] || return 1
	else
		cfmgr_install_admission_status=$?
		[ "$cfmgr_install_admission_status" -ne 3 ] || return 3
		return 2
	fi
}

# Remove only the FD-pinned private, flat RAM context after all owned children
# have been reaped. Unknown objects/ownership preserve the one active claim.
# Native BusyBox test -ef is verified by the descriptor and kernel fixtures.
# shellcheck disable=SC3013
cfmgr_bootstrap_cleanup() {
	# A reaped short native probe says nothing about retained long-action work.
	# Its RAM machinery and phase-pinned descriptors remain recovery evidence.
	[ "${cfmgr_dependencies_state:-none}" != retained ] && [ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ] || return 3
	[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
	case $cfmgr_install_context_fd in 0 | 3 | 5 | 9) ;; *) return 1 ;; esac
	[ "$cfmgr_install_context" = "${cfmgr_install_private_context:-/tmp/cfmgr/install}" ] &&
		[ ! -L "$cfmgr_install_context" ] && [ "$cfmgr_install_context" -ef "/proc/self/fd/$cfmgr_install_context_fd" ] || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 1
	cfmgr_install_cleanup_count=0
	for cfmgr_install_cleanup_item in "$cfmgr_install_context"/* "$cfmgr_install_context"/.[!.]* "$cfmgr_install_context"/..?*; do
		[ -e "$cfmgr_install_cleanup_item" ] || [ -L "$cfmgr_install_cleanup_item" ] || continue
		[ -f "$cfmgr_install_cleanup_item" ] && [ ! -L "$cfmgr_install_cleanup_item" ] || return 1
		cfmgr_install_cleanup_count=$((cfmgr_install_cleanup_count + 1))
		[ "$cfmgr_install_cleanup_count" -le 4096 ] || return 1
	done
	for cfmgr_install_cleanup_item in "$cfmgr_install_context"/* "$cfmgr_install_context"/.[!.]* "$cfmgr_install_context"/..?*; do
		[ -f "$cfmgr_install_cleanup_item" ] || continue
		/bin/rm -f "$cfmgr_install_cleanup_item" || return 1
	done
	/bin/rmdir "$cfmgr_install_context" || return 1
	case $cfmgr_install_context_fd in 0) exec 0<&- ;; 3) exec 3<&- ;; 5) exec 5<&- ;; 9) exec 9<&- ;; esac
}

# Explicit storage/prerequisite imports supply result fields; proc/listing
# receiving fields keep their fixed positions even when policy needs a subset.
# shellcheck disable=SC2034,SC2154
cfmgr_bootstrap_native_prepare() {
	[ "$#" -eq 2 ] && { [ "$2" = install ] || [ "$2" = launch ] || [ "$2" = acquire ]; } && cfmgr_bootstrap_path "$1" || return 2
	cfmgr_install_source=$1 cfmgr_install_jffs="/jffs" cfmgr_install_opt=/opt cfmgr_install_owner=0
	cfmgr_install_sh=/bin/sh cfmgr_install_env=/usr/bin/env cfmgr_install_awk=/usr/bin/awk
	cfmgr_install_readlink=/usr/bin/readlink cfmgr_install_sleep=/bin/sleep cfmgr_install_wc=/usr/bin/wc
	cfmgr_install_ls=/bin/ls cfmgr_install_fsync=/bin/fsync cfmgr_install_mkdir=/bin/mkdir
	cfmgr_install_cp=/bin/cp cfmgr_install_chmod=/bin/chmod cfmgr_install_mv=/bin/mv
	cfmgr_install_df=/bin/df cfmgr_install_nvram=/bin/nvram
	cfmgr_install_sha=/opt/bin/sha256sum cfmgr_install_jq=/opt/bin/jq
	for cfmgr_install_argument in /bin/sh /usr/bin/env /usr/bin/awk /usr/bin/readlink /bin/sleep /bin/usleep /usr/bin/wc /bin/ls /bin/fsync /bin/mkdir /bin/cp /bin/chmod /bin/mv /bin/df /bin/nvram /bin/rm /bin/rmdir /sbin/blkid; do
		[ -f "$cfmgr_install_argument" ] && [ -x "$cfmgr_install_argument" ] || return 2
	done
	# The native proc UID record proves all four credential IDs are root.
	# shellcheck disable=SC2016
	/usr/bin/awk '$1=="Uid:" { n++; if (NF!=5 || $2!=0 || $3!=0 || $4!=0 || $5!=0) bad=1 }
		END { if (n!=1 || bad) exit 1 }' /proc/self/status || return 1
	[ -d "/jffs" ] && [ ! -L "/jffs" ] && [ -d "$cfmgr_install_source" ] && [ ! -L "$cfmgr_install_source" ] || return 1
	cfmgr_install_source_fd=9
	cfmgr_install_jffs_snapshot=$(cfmgr_storage_mountinfo /usr/bin/awk "/jffs" /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_install_jffs_id cfmgr_install_jffs_parent cfmgr_install_jffs_device cfmgr_install_jffs_root cfmgr_install_jffs_mount cfmgr_install_jffs_type cfmgr_install_jffs_device_path cfmgr_install_jffs_options cfmgr_install_jffs_superoptions <<EOF
$cfmgr_install_jffs_snapshot
EOF
	[ "$cfmgr_install_jffs_mount" = "/jffs" ] && [ "$cfmgr_install_jffs_type" = jffs2 ] || return 1
	case ,$cfmgr_install_jffs_options, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_install_jffs_options, in *,noexec,* | *,ro,*) return 1 ;; esac
	exec 8<"/jffs" 9<"$cfmgr_install_source" || return 1
	# Prove RAM backing before creating any preflight object.
	[ -d /tmp ] && [ ! -L /tmp ] && [ "$(/usr/bin/readlink -f /tmp)" = /tmp ] || return 1
	cfmgr_install_tmp_snapshot=$(cfmgr_storage_mountinfo /usr/bin/awk /tmp /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_install_tmp_id cfmgr_install_tmp_parent cfmgr_install_tmp_device cfmgr_install_tmp_root cfmgr_install_tmp_mount cfmgr_install_tmp_type cfmgr_install_tmp_source cfmgr_install_tmp_options cfmgr_install_tmp_superoptions <<EOF
$cfmgr_install_tmp_snapshot
EOF
	case $cfmgr_install_tmp_type in tmpfs | ramfs | rootfs) ;; *) return 1 ;; esac
	case ,$cfmgr_install_tmp_options, in *,rw,*) ;; *) return 1 ;; esac
	# RAM is the only mutable preflight area. Preserve shared parent permissions.
	if [ ! -e /tmp/cfmgr ] && [ ! -L /tmp/cfmgr ]; then /bin/mkdir -m 700 /tmp/cfmgr || return 1; fi
	[ -d /tmp/cfmgr ] && [ ! -L /tmp/cfmgr ] || return 1
	# This fixed native listing is bounded by the literal pathname.
	cfmgr_install_ram=$(/bin/ls -ldn /tmp/cfmgr) || return 1
	IFS=' ' read -r cfmgr_install_ram_mode cfmgr_install_ram_links cfmgr_install_ram_uid cfmgr_install_ram_rest <<EOF
$cfmgr_install_ram
EOF
	[ "$cfmgr_install_ram_mode" = drwx------ ] && [ "$cfmgr_install_ram_uid" = 0 ] || return 1
	if [ -e /tmp/cfmgr/install ] || [ -L /tmp/cfmgr/install ]; then
		printf '[CFMGR] install: error: legacy preflight context requires recovery\n' >&2
		return 1
	fi
	cfmgr_prerequisites_identity "$$" || return 1
	cfmgr_install_private_context=/tmp/cfmgr/$2.$$.$cfmgr_identity_start
	cfmgr_install_context=$cfmgr_install_private_context
	/bin/mkdir -m 700 "$cfmgr_install_context" || return 1
	exec 0<"$cfmgr_install_context" || return 1
	cfmgr_install_context_fd=0
	cfmgr_bootstrap_signals
	cfmgr_probe_serial=0
	cfmgr_probe_pid='' cfmgr_probe_status=invalid
}

cfmgr_bootstrap_native() {
	[ "$#" -eq 1 ] || return 2
	cfmgr_bootstrap_native_prepare "$1" install || return $?
	cfmgr_install_storage_pinned=0
	if cfmgr_storage_pin /opt /usr/bin/readlink /usr/bin/awk "$cfmgr_install_source/modules/lib/storage.sh" /proc/self; then
		cfmgr_install_storage_pinned=1
		if cfmgr_bootstrap_native_work; then cfmgr_install_native_status=0; else cfmgr_install_native_status=$?; fi
	else cfmgr_install_native_status=$?; fi
	# Never start another probe (which resets identities) or clean evidence while
	# a previous native/dependency child may still own work or inherited FDs.
	if [ "$cfmgr_install_native_status" -eq 3 ] ||
		[ "${cfmgr_dependencies_state:-none}" = retained ] ||
		[ "${cfmgr_dependencies_native_unresolved:-0}" != 0 ] ||
		{ [ -n "${cfmgr_probe_pid:-}" ] && [ "${cfmgr_probe_status:-}" != reaped ]; }; then
		return 3
	fi
	if [ "$cfmgr_install_storage_pinned" = 1 ] && [ "$cfmgr_install_native_status" -ne 0 ] &&
		[ "${cfmgr_dependencies_loss:-0}" != 1 ] && ! cfmgr_storage_attached; then
		if cfmgr_bootstrap_storage_lost; then :; else
			cfmgr_install_report_status=$?
			[ "$cfmgr_install_report_status" -ne 3 ] || return 3
		fi
	fi
	if ! cfmgr_bootstrap_cleanup; then
		printf '[CFMGR] install: error: retained preflight context requires recovery (%s)\n' "$cfmgr_install_context" >&2
		return 1
	fi
	[ "$cfmgr_install_interrupted" = 0 ] || return 1
	trap - HUP INT TERM
	return "$cfmgr_install_native_status"
}

# These two fixed modes retain all native source/JFFS/RAM admission while
# deliberately avoiding Entware. Ordinary install-* actions still require it.
cfmgr_bootstrap_report_action() {
	cfmgr_bootstrap_native_attached || return 1
	case $1 in
	install-report) cfmgr_install_report_tool=/usr/bin/logger ;;
	install-report-ls) cfmgr_install_report_tool=$cfmgr_install_ls ;;
	*) return 2 ;;
	esac
	cfmgr_prerequisites_run "$1" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/worker.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
		"$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_install_report_tool" "$2" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	[ "$1" != install-report ] || [ ! -s "$cfmgr_probe_stdout" ]
}

# Admit both the applet's literal ancestry and its resolved native executable.
# Use bounded native listings, never the Entware-attached install metadata path.
cfmgr_bootstrap_logger_admit() {
	[ -f /usr/bin/logger ] && [ -x /usr/bin/logger ] || return 1
	cfmgr_bootstrap_native_attached || return 1
	cfmgr_install_logger_resolved=$("$cfmgr_install_readlink" -f /usr/bin/logger) || return 1
	case $cfmgr_install_logger_resolved in /usr/bin/logger | /bin/busybox) ;; *) return 1 ;; esac
	for cfmgr_install_logger_root in /usr/bin "$cfmgr_install_logger_resolved"; do
		cfmgr_install_logger_parent=$cfmgr_install_logger_root
		while :; do
			cfmgr_bootstrap_report_action install-report-ls "$cfmgr_install_logger_parent" || return $?
			IFS=' ' read -r cfmgr_install_mode cfmgr_install_links cfmgr_install_uid cfmgr_install_gid cfmgr_install_rest <"$cfmgr_probe_stdout" || return 1
			[ "$cfmgr_install_uid" = 0 ] || return 1
			case $cfmgr_install_mode in
			d????????? | -?????????) case $cfmgr_install_mode in ?????w???? | ????????w?) return 1 ;; esac ;;
			*) return 1 ;;
			esac
			[ "$("$cfmgr_install_readlink" -f "$cfmgr_install_logger_parent")" = "$cfmgr_install_logger_parent" ] || return 1
			[ "$cfmgr_install_logger_parent" != / ] || break
			cfmgr_install_logger_parent=${cfmgr_install_logger_parent%/*}
			[ -n "$cfmgr_install_logger_parent" ] || cfmgr_install_logger_parent=/
		done
	done
}

cfmgr_bootstrap_storage_lost() {
	printf '[CFMGR] Manager: Error: Entware storage lost; installation stopped\n' >&2
	if cfmgr_bootstrap_logger_admit; then :; else
		cfmgr_install_log_status=$?
		printf '[CFMGR] Manager: Warning: native system log unavailable\n' >&2
		[ "$cfmgr_install_log_status" -ne 3 ] || return 3
		return 1
	fi
	if cfmgr_bootstrap_report_action install-report storage-lost; then return 1; else
		cfmgr_install_log_status=$?
		printf '[CFMGR] Manager: Warning: native system log delivery unconfirmed\n' >&2
		[ "$cfmgr_install_log_status" -ne 3 ] || return 3
		return 1
	fi
}

# Fixed native tools/CA are root-protected through their resolved ancestry.
# This admission precedes all JFFS publication; test adapters are private callers.
cfmgr_bootstrap_native_protected() {
	cfmgr_bootstrap_path "$1" && [ -f "$1" ] && [ ! -L "$1" ] || return 1
	cfmgr_install_native_resolved=$("$cfmgr_install_readlink" -f "$1") || return 1
	cfmgr_bootstrap_path "$cfmgr_install_native_resolved" && [ "$cfmgr_install_native_resolved" = "$1" ] || return 1
	[ ! -L "$cfmgr_install_native_resolved" ] || return 1
	cfmgr_bootstrap_metadata "$cfmgr_install_native_resolved" 0 protected || return $?
	cfmgr_install_native_parent=${cfmgr_install_native_resolved%/*}
	while [ -n "$cfmgr_install_native_parent" ]; do
		cfmgr_bootstrap_metadata "$cfmgr_install_native_parent" 0 protected || return $?
		[ "$cfmgr_install_native_parent" != / ] || break
		cfmgr_install_native_parent=${cfmgr_install_native_parent%/*}
		[ -n "$cfmgr_install_native_parent" ] || cfmgr_install_native_parent=/
	done
	if [ "$2" = executable ]; then [ -x "$cfmgr_install_native_resolved" ] || return 1; fi
}

# Finite direct-exec dispatcher shared with the prerequisite supervisor.
# shellcheck disable=SC2034,SC2154 # Exports bounded native callback result fields.
cfmgr_native_action() {
	if [ "${cfmgr_acquire_active:-0}" = 1 ]; then
		cfmgr_acquire_native_action "$@"
		return $?
	fi
	case $1 in
	install-*) cfmgr_bootstrap_action "$@" || return $? ;;
	native-*)
		cfmgr_install_native_mode=$1
		case $1 in
		native-curl-version | native-curl-offline | native-curl-https) cfmgr_install_native_tool=$cfmgr_native_curl ;;
		native-ca-decode) cfmgr_install_native_tool=$cfmgr_native_openssl ;;
		native-curl-features | native-ca-pem) cfmgr_install_native_tool=$cfmgr_install_awk ;;
		native-rmdir) cfmgr_install_native_tool=/bin/rmdir ;;
		*) return 2 ;;
		esac
		shift
		cfmgr_prerequisites_run "$cfmgr_install_native_mode" "$cfmgr_install_context" "$cfmgr_install_sh" \
			"$cfmgr_install_source/modules/helpers/worker.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
			"$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_install_native_tool" "$@" || return $?
		;;
	*) return 2 ;;
	esac
	cfmgr_native_output=$cfmgr_probe_stdout cfmgr_native_error=$cfmgr_probe_stderr cfmgr_native_exit=$cfmgr_probe_exit
}

# shellcheck disable=SC2154 # Explicit native library exports finite reason codes.
cfmgr_bootstrap_native_admission() {
	for cfmgr_install_native_path in /usr/sbin/curl /usr/sbin/openssl /rom/etc/ssl/certs/ca-certificates.crt; do
		case $cfmgr_install_native_path in *.crt) cfmgr_install_native_kind=certificate ;; *) cfmgr_install_native_kind=executable ;; esac
		if cfmgr_bootstrap_native_protected "$cfmgr_install_native_path" "$cfmgr_install_native_kind"; then :; else
			cfmgr_install_native_check_status=$?
			printf '[CFMGR] install: error: native path admission failed\n' >&2
			return "$cfmgr_install_native_check_status"
		fi
	done
	if cfmgr_native_check "$cfmgr_install_context" /usr/sbin/curl /usr/sbin/openssl /rom/etc/ssl/certs/ca-certificates.crt; then return 0; else
		cfmgr_install_native_check_status=$?
		printf '[CFMGR] install: error: native admission failed (%s)\n' "$cfmgr_native_reason" >&2
		return "$cfmgr_install_native_check_status"
	fi
}

# The outer admission function owns the single RAM claim and its cleanup.
# shellcheck disable=SC2034,SC2154
cfmgr_bootstrap_shared_requirements() {
	[ "$#" -ge 1 ] && [ "$#" -le 2 ] && { [ "$1" = fresh ] || [ "$1" = retained ]; } || return 2
	cfmgr_install_consumer=$1
	cfmgr_install_dependency_action=${2:-normal}
	case $cfmgr_install_consumer:$cfmgr_install_dependency_action in fresh:normal | retained:normal | retained:reinstall) ;; *) return 2 ;; esac
	cfmgr_install_force_flock=0 cfmgr_install_force_dig=0
	cfmgr_install_dependency_scope=shared cfmgr_install_dns_result=not-required cfmgr_install_dns_warned=0
	if [ "$cfmgr_install_consumer" = retained ]; then cfmgr_launch_reinstall_scope || return $?; fi
	cfmgr_bootstrap_native_admission || return $?
	cfmgr_bootstrap_action install-nvram || return $?
	IFS= read -r cfmgr_install_scripts_enabled <"$cfmgr_install_output" || return 1
	[ "$cfmgr_install_scripts_enabled" = 1 ] || return 1
	cfmgr_prerequisites_run blkid "$cfmgr_install_context" /bin/sh "$cfmgr_install_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc /sbin/blkid "$cfmgr_storage_source" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_storage_uuid "$cfmgr_probe_stdout" || return $?
	for cfmgr_install_admit_path in "$cfmgr_storage_opt" "$cfmgr_storage_opt/bin" "$cfmgr_storage_opt/lib"; do
		cfmgr_bootstrap_metadata "$cfmgr_install_admit_path" 0 protected || return $?
	done
	# Entware admission belongs to the fixed prerequisite callback. A healthy
	# native flock never inspects an unused optional Entware executable.
	cfmgr_install_native_flock=/usr/bin/flock cfmgr_install_entware_flock=/opt/bin/flock
	if [ ! -f /usr/bin/flock ] || [ ! -x /usr/bin/flock ]; then cfmgr_install_native_flock=-; fi
	cfmgr_install_inventory_scope=shared cfmgr_install_inventory_native_dns=unknown
	if [ "$cfmgr_install_dependency_action" = normal ]; then cfmgr_bootstrap_normal_dns pre || return $?; fi
	if cfmgr_prerequisites_check "$cfmgr_install_inventory_scope" "$cfmgr_install_context" /bin/sh "$cfmgr_install_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_install_native_flock" /opt/bin/jq /opt/bin/timeout /opt/bin/sha256sum "$cfmgr_install_entware_flock" /opt/bin/dig "$cfmgr_install_inventory_native_dns"; then cfmgr_install_inventory_code=0; else cfmgr_install_inventory_code=$?; fi
	case $cfmgr_install_inventory_code in
	0) [ ! -e /tmp/cfmgr/dependencies ] && [ ! -L /tmp/cfmgr/dependencies ] || cfmgr_install_inventory_code=1 ;;
	1) [ "$cfmgr_prereq_result" = capabilities-checked ] || return 2 ;;
	*) return "$cfmgr_install_inventory_code" ;;
	esac
	if [ "$cfmgr_install_dependency_action" = normal ] && [ "$cfmgr_prereq_dns_provider" = entware ]; then cfmgr_bootstrap_normal_dns_query || return $?; fi
	if [ "$cfmgr_install_dependency_action" = reinstall ]; then
		# Explicit action chooses the direct logical set even when healthy. The
		# existing status mapper preserves installed alternatives such as jq-full.
		cfmgr_install_selected='jq coreutils-timeout coreutils-sha256sum'
		if [ "$cfmgr_prereq_flock_provider" != native ]; then
			cfmgr_install_selected="$cfmgr_install_selected flock"
			cfmgr_install_force_flock=1
		fi
		cfmgr_install_dns_native=not-required
		if [ "$cfmgr_install_dependency_scope" = tunnel ]; then
			cfmgr_bootstrap_reinstall_dns pre || return $?
			if [ "$cfmgr_install_dns_native" = unsupported ]; then
				cfmgr_install_selected="$cfmgr_install_selected bind-dig"
				cfmgr_install_force_dig=1
			fi
		fi
		cfmgr_prereq_missing=$cfmgr_install_selected
		cfmgr_install_inventory_code=1
	fi
	if [ "$cfmgr_install_inventory_code" -eq 1 ]; then
		# Flock has released4/5. Phase-swap the two retained directories without
		# allocating a hidden/high ash descriptor: source0, stable preflight9.
		exec 4<&9 9<&0 0<&4 4<&-
		cfmgr_install_source_fd=0 cfmgr_install_context_fd=9
		cfmgr_install_repair_missing=$cfmgr_prereq_missing cfmgr_install_repair_code=0
		if cfmgr_dependencies_repair "$cfmgr_prereq_missing" /tmp/cfmgr "$cfmgr_install_source" / /bin/sh /usr/bin/env /usr/bin/awk /usr/bin/readlink /bin/usleep /usr/bin/wc /bin/mknod /usr/sbin/chroot; then :; else
			cfmgr_install_repair_code=$?
			# Unknown gate/root/native children retain the phase mapping and FD4.
			if [ "$cfmgr_install_repair_code" -ne 3 ]; then
				exec 4<&0 0<&9 9<&4 4<&-
				cfmgr_install_source_fd=9 cfmgr_install_context_fd=0
			fi
			if [ "$cfmgr_install_dependency_action:$cfmgr_install_repair_missing:$cfmgr_install_repair_code" = normal:bind-dig:1 ] &&
				[ "${cfmgr_dependencies_failure:-none}:${cfmgr_dependencies_state:-none}:${cfmgr_dependencies_loss:-0}:${cfmgr_dependencies_native_unresolved:-0}" = opkg:complete:0:0 ]; then
				cfmgr_bootstrap_dns_deferred
			else
				printf '[CFMGR] install: error: dependency repair failed (%s)\n' "${cfmgr_dependencies_phase:-admission}" >&2
				return "$cfmgr_install_repair_code"
			fi
		fi
		if [ "$cfmgr_install_repair_code" -eq 0 ]; then
			exec 4<&0 0<&9 9<&4 4<&-
			cfmgr_install_source_fd=9 cfmgr_install_context_fd=0
		fi
		if [ "$cfmgr_install_dependency_action" = reinstall ] && [ "$cfmgr_dependencies_result" != repaired ]; then
			printf '[CFMGR] dependencies: warning: concurrent repair completed; reinstall deferred; retry explicitly\n' >&2
			return 1
		fi
		# Fresh post-probe context; no original probe file is rewritten or reused.
		cfmgr_install_original_context=$cfmgr_install_context
		cfmgr_bootstrap_action install-mkdir-private "$cfmgr_install_original_context.post" || return $?
		exec 3<&0 0<"$cfmgr_install_original_context.post"
		cfmgr_install_context=$cfmgr_install_original_context.post
		cfmgr_install_context_fd=0
		cfmgr_install_post_native_flock=$cfmgr_install_native_flock
		# A newly healthy native provider cannot hide a broken selected reinstall.
		if [ "$cfmgr_install_force_flock" = 1 ]; then cfmgr_install_post_native_flock=-; fi
		cfmgr_install_inventory_scope=shared cfmgr_install_inventory_native_dns=unknown
		cfmgr_install_post_code=0 cfmgr_install_post_inventory=0
		if [ "$cfmgr_install_dependency_action" = normal ]; then
			if [ "$cfmgr_install_consumer" = retained ]; then
				if cfmgr_launch_reinstall_recheck; then :; else cfmgr_install_post_code=$?; fi
			fi
			if [ "$cfmgr_install_post_code" -eq 0 ]; then
				if cfmgr_bootstrap_normal_dns pre; then :; else cfmgr_install_post_code=$?; fi
			fi
		fi
		[ "$cfmgr_install_post_code" -ne 3 ] || return 3
		if [ "$cfmgr_install_post_code" -eq 0 ]; then
			if cfmgr_prerequisites_check "$cfmgr_install_inventory_scope" "$cfmgr_install_context" /bin/sh "$cfmgr_install_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_install_post_native_flock" /opt/bin/jq /opt/bin/timeout /opt/bin/sha256sum "$cfmgr_install_entware_flock" /opt/bin/dig "$cfmgr_install_inventory_native_dns"; then cfmgr_install_post_code=0; else cfmgr_install_post_code=$?; fi
			cfmgr_install_post_inventory=1
		fi
		# Reaped fresh probes allow bounded cleanup of the original owned context.
		[ "$cfmgr_install_post_code" -ne 3 ] || return 3
		if [ "$cfmgr_install_dependency_action" = normal ]; then
			if [ "$cfmgr_install_post_inventory:$cfmgr_install_post_code:$cfmgr_prereq_missing" = 1:1:bind-dig ]; then
				# One normal repair attempt only; shared capabilities passed.
				cfmgr_bootstrap_dns_deferred
				cfmgr_install_post_code=0
			elif [ "$cfmgr_install_post_code" -eq 0 ] && [ "$cfmgr_prereq_dns_provider" = entware ]; then
				if cfmgr_bootstrap_normal_dns_query; then :; else cfmgr_install_post_code=$?; fi
			fi
		fi
		[ "$cfmgr_install_post_code" -ne 3 ] || return 3
		if [ "$cfmgr_install_post_code" -eq 0 ] && [ "$cfmgr_install_dependency_action:$cfmgr_install_dependency_scope" = reinstall:tunnel ]; then
			if cfmgr_bootstrap_reinstall_dns post; then :; else cfmgr_install_post_code=$?; fi
			[ "$cfmgr_install_post_code" -ne 3 ] || return 3
		fi
		if [ "$cfmgr_install_post_code" -eq 0 ] && [ "$cfmgr_install_consumer" = retained ]; then
			if cfmgr_launch_migrate_snapshot; then :; else cfmgr_install_post_code=$?; fi
			[ "$cfmgr_install_post_code" -ne 3 ] || return 3
		fi
		cfmgr_install_post_context=$cfmgr_install_context
		cfmgr_install_context=$cfmgr_install_original_context cfmgr_install_context_fd=3
		cfmgr_bootstrap_cleanup || return 3
		cfmgr_install_context=$cfmgr_install_post_context cfmgr_install_context_fd=0 cfmgr_install_private_context=$cfmgr_install_post_context
		[ "$cfmgr_install_post_code" -eq 0 ] || return "$cfmgr_install_post_code"
	fi
}

# The repair controller calls this immediately before its one opkg request. A
# retained action revalidates live generation/scope through native JSON parsing.
cfmgr_dependencies_before_repair() {
	if [ "${cfmgr_install_consumer:-fresh}" = retained ] || [ "${cfmgr_install_dependency_action:-normal}" = reinstall ]; then cfmgr_launch_reinstall_recheck || return $?; fi
}

cfmgr_bootstrap_dns_run() {
	cfmgr_bootstrap_dns_mode=$1 cfmgr_bootstrap_dns_tool=$2
	shift 2
	cfmgr_prerequisites_run "$cfmgr_bootstrap_dns_mode" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/worker.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
		"$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_bootstrap_dns_tool" "$@"
	cfmgr_bootstrap_dns_run_code=$?
	cfmgr_prerequisites_probe_code "$cfmgr_bootstrap_dns_run_code"
}

cfmgr_bootstrap_dns_admit_native() {
	cfmgr_install_dns_tool=/usr/bin/nslookup
	[ -e "$cfmgr_install_dns_tool" ] || [ -L "$cfmgr_install_dns_tool" ] || return 1
	cfmgr_install_dns_resolved=$("$cfmgr_install_readlink" -f "$cfmgr_install_dns_tool") || return 2
	case $cfmgr_install_dns_resolved in /usr/bin/nslookup | /bin/busybox) ;; *) return 2 ;; esac
	# Admit both the literal applet parents and its root-protected native target.
	for cfmgr_install_dns_parent in /usr/bin /usr /; do
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_install_dns_parent")" = "$cfmgr_install_dns_parent" ] || return 2
		if cfmgr_bootstrap_metadata "$cfmgr_install_dns_parent" 0 protected; then :; else
			cfmgr_install_dns_admit_code=$?
			[ "$cfmgr_install_dns_admit_code" -ne 3 ] || return 3
			return 2
		fi
	done
	if cfmgr_bootstrap_native_protected "$cfmgr_install_dns_resolved" executable; then return 0; else
		cfmgr_install_dns_admit_code=$?
		[ "$cfmgr_install_dns_admit_code" -ne 3 ] || return 3
		return 2
	fi
}

cfmgr_bootstrap_dns_answers() {
	# PROVIDER TOOL SYNTAX SRV_OUTPUT. Pure bounded parsers exclude server
	# addresses, validate the fixed service/port and emit at most two hostnames.
	cfmgr_install_dns_provider=$1 cfmgr_install_dns_query_tool=$2 cfmgr_install_dns_syntax=$3
	cfmgr_bootstrap_dns_run native-dns-parse-srv "$cfmgr_install_awk" "$1" "$4" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	IFS=' ' read -r cfmgr_install_dns_first cfmgr_install_dns_second cfmgr_install_dns_extra <"$cfmgr_probe_stdout" || return 1
	[ -n "$cfmgr_install_dns_first" ] && [ -z "$cfmgr_install_dns_extra" ] || return 1
	for cfmgr_install_dns_target in "$cfmgr_install_dns_first" "$cfmgr_install_dns_second"; do
		[ -n "$cfmgr_install_dns_target" ] || continue
		cfmgr_bootstrap_dns_run "native-dns-$cfmgr_install_dns_provider-a" "$cfmgr_install_dns_query_tool" "$cfmgr_install_dns_syntax" "$cfmgr_install_dns_target" || return $?
		[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
		cfmgr_install_dns_answer=$cfmgr_probe_stdout
		cfmgr_bootstrap_dns_run native-dns-parse-a "$cfmgr_install_awk" "$cfmgr_install_dns_provider" "$cfmgr_install_dns_target" "$cfmgr_install_dns_answer" || return $?
		[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	done
}

cfmgr_bootstrap_reinstall_dns() {
	[ "$#" -eq 1 ] && { [ "$1" = pre ] || [ "$1" = post ]; } || return 2
	cfmgr_install_dns_phase=$1 cfmgr_install_dns_native=unknown
	if [ "$cfmgr_install_dns_phase:${cfmgr_install_force_dig:-0}" = post:1 ]; then
		cfmgr_install_dns_native=unsupported
		cfmgr_bootstrap_dns_verify_dig
		return $?
	fi
	if cfmgr_bootstrap_dns_admit_native; then
		cfmgr_install_dns_usages=0
		for cfmgr_install_dns_variant in q type long; do
			if cfmgr_bootstrap_dns_run native-dns-native-srv "$cfmgr_install_dns_tool" "$cfmgr_install_dns_variant"; then :; else
				cfmgr_install_dns_code=$?
				[ "$cfmgr_install_dns_code" -eq 1 ] || return "$cfmgr_install_dns_code"
				cfmgr_bootstrap_dns_deferred
				return 1
			fi
			cfmgr_install_dns_srv=$cfmgr_probe_stdout cfmgr_install_dns_error=$cfmgr_probe_stderr cfmgr_install_dns_exit=$cfmgr_probe_exit
			cfmgr_bootstrap_dns_run native-dns-classify "$cfmgr_install_awk" "$cfmgr_install_dns_srv" "$cfmgr_install_dns_error" "$cfmgr_install_dns_exit" || return $?
			[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
			IFS= read -r cfmgr_install_dns_class <"$cfmgr_probe_stdout" || return 1
			case $cfmgr_install_dns_class in
			unsupported)
				cfmgr_install_dns_native=unsupported
				break
				;;
			usage) cfmgr_install_dns_usages=$((cfmgr_install_dns_usages + 1)) ;;
			syntax) ;;
			answer)
				if cfmgr_bootstrap_dns_answers native "$cfmgr_install_dns_tool" "$cfmgr_install_dns_variant" "$cfmgr_install_dns_srv"; then
					cfmgr_install_dns_native=srv-a-verified
					return 0
				else cfmgr_install_dns_code=$?; fi
				[ "$cfmgr_install_dns_code" -eq 1 ] || return "$cfmgr_install_dns_code"
				cfmgr_bootstrap_dns_deferred
				return 1
				;;
			*)
				cfmgr_bootstrap_dns_deferred
				return 1
				;;
			esac
		done
		if [ "$cfmgr_install_dns_usages" -eq 3 ]; then cfmgr_install_dns_native=unsupported; fi
	else
		cfmgr_install_dns_code=$?
		case $cfmgr_install_dns_code in 1) cfmgr_install_dns_native=unsupported ;; *) return "$cfmgr_install_dns_code" ;; esac
	fi
	[ "$cfmgr_install_dns_native" = unsupported ] || {
		cfmgr_bootstrap_dns_deferred
		return 1
	}
	[ "$cfmgr_install_dns_phase" = post ] || return 0
	cfmgr_bootstrap_dns_verify_dig
}

cfmgr_bootstrap_dns_verify_dig() {
	# Known missing native capability selects dig, but version/executability alone
	# cannot establish that the reinstall's required DNS behavior now works.
	cfmgr_prerequisites_admit_tool /opt/bin/dig || return $?
	cfmgr_bootstrap_dns_run native-dns-dig-srv /opt/bin/dig || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || {
		cfmgr_bootstrap_dns_deferred
		return 1
	}
	cfmgr_install_dns_srv=$cfmgr_probe_stdout
	if cfmgr_bootstrap_dns_answers dig /opt/bin/dig short "$cfmgr_install_dns_srv"; then return 0; else cfmgr_install_dns_code=$?; fi
	[ "$cfmgr_install_dns_code" -eq 1 ] || return "$cfmgr_install_dns_code"
	cfmgr_bootstrap_dns_deferred
	return 1
}

# Native ambiguity never selects dig. Configuration scope remains unchanged
# for late generation checks; only positive incapability admits tunnel inventory.
cfmgr_bootstrap_normal_dns() {
	[ "$cfmgr_install_dependency_scope" = tunnel ] || return 0
	if cfmgr_bootstrap_reinstall_dns "$1"; then
		case $cfmgr_install_dns_native in
		srv-a-verified) cfmgr_install_dns_result=verified cfmgr_install_inventory_scope=tunnel cfmgr_install_inventory_native_dns=srv-a-verified ;;
		unsupported) cfmgr_install_inventory_scope=tunnel ;;
		esac
	else
		cfmgr_install_dns_code=$?
		[ "$cfmgr_install_dns_code" -eq 1 ] || return "$cfmgr_install_dns_code"
		cfmgr_bootstrap_dns_deferred
	fi
}

cfmgr_bootstrap_normal_dns_query() {
	if cfmgr_bootstrap_dns_verify_dig; then cfmgr_install_dns_result=verified; else
		cfmgr_install_dns_code=$?
		[ "$cfmgr_install_dns_code" -eq 1 ] || return "$cfmgr_install_dns_code"
		cfmgr_bootstrap_dns_deferred
	fi
}

cfmgr_bootstrap_dns_deferred() {
	if [ "${cfmgr_install_dependency_action:-reinstall}" = normal ]; then
		cfmgr_install_dns_result=deferred
		if [ "${cfmgr_install_dns_warned:-0}" = 0 ]; then
			printf '[CFMGR] dependencies: warning: tunnel DNS verification deferred\n' >&2
			cfmgr_install_dns_warned=1
		fi
	elif [ "$cfmgr_install_dns_phase" = post ]; then
		printf '[CFMGR] dependencies: warning: opkg completed; DNS verification deferred; retry explicitly\n' >&2
	else
		printf '[CFMGR] dependencies: warning: native DNS capability unverified; reinstall deferred\n' >&2
	fi
}

cfmgr_bootstrap_native_work() {
	cfmgr_bootstrap_retained || return 1
	cfmgr_bootstrap_shared_requirements fresh || return $?
	# Flock probes have released FD4/5. Keep the context off stdin before
	# transaction while-read loops temporarily redirect FD0 to manifest records.
	exec 5<&0 0<&-
	cfmgr_install_context_fd=5
	# Prove native flush diagnostics on an owned RAM directory before JFFS mutation.
	cfmgr_bootstrap_flush "$cfmgr_install_context" || return $?
	cfmgr_bootstrap_transaction "$cfmgr_install_source" "/jffs" "$cfmgr_storage_opt" "$cfmgr_install_context" 0 \
		/bin/sh /usr/bin/env /usr/bin/awk /usr/bin/readlink /bin/sleep /usr/bin/wc /bin/ls /bin/fsync \
		/bin/mkdir /bin/cp /bin/chmod /bin/mv /opt/bin/sha256sum /opt/bin/jq \
		"$cfmgr_storage_uuid_value" "$cfmgr_storage_filesystem" "$cfmgr_storage_fsroot" "$cfmgr_storage_relative" /bin/df
}

# shellcheck disable=SC2034,SC2154 # Imported view/task/keeper fields and bounded listing columns.
# Native repair operations use a separate RAM/FD admission, so cleanup remains
# executable after Entware/source loss. They never regain package-write admission.
# shellcheck disable=SC3013,SC2154
cfmgr_dependencies_attachment_ok() {
	if [ "${cfmgr_dependencies_claimed:-0}" != 1 ] || [ "${cfmgr_dependencies_snapshot_ready:-0}" != 1 ]; then
		cfmgr_bootstrap_attached
		return $?
	fi
	[ "$cfmgr_install_context_fd" = 9 ] && [ ! -L "$cfmgr_install_context" ] && [ "$cfmgr_install_context" -ef /proc/self/fd/9 ] || return 1
	[ -r "$cfmgr_install_context/repair-storage.sh" ] || return 1
	if [ -d "$cfmgr_dependencies_context" ] && [ ! -L "$cfmgr_dependencies_context" ] &&
		[ "$cfmgr_dependencies_context" -ef /proc/self/fd/5 ]; then :; else
		# Only the already-launched final rmdir may retire this pinned inode.
		# Before launch probe_pid is empty, so normal pathname admission still
		# applies. A new claim at the old name is never adopted or modified.
		[ "${cfmgr_dependencies_retiring:-0}:${cfmgr_probe_mode:-none}" = 1:repair-retire ] && [ -n "${cfmgr_probe_pid:-}" ] || return 1
		[ -d /proc/self/fd/5 ] || return 1
		cfmgr_dependencies_retired_metadata=$("$cfmgr_install_ls" -Ldn /proc/self/fd/5) || return 1
		IFS=' ' read -r cfmgr_dependencies_retired_mode cfmgr_dependencies_retired_links cfmgr_dependencies_retired_uid cfmgr_dependencies_retired_rest <<EOF_RETIRED
$cfmgr_dependencies_retired_metadata
EOF_RETIRED
		[ "$cfmgr_dependencies_retired_mode:$cfmgr_dependencies_retired_links:$cfmgr_dependencies_retired_uid" = drwx------:0:0 ] || return 1
		# The deleted descriptor still pins the old claim; RAM context FD9 and
		# its original covering mount protect the supervisor's remaining receipts.
		[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_install_context" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ]
		return $?
	fi
	if [ "${cfmgr_dependencies_cleaning:-0}" = 1 ]; then
		cfmgr_storage_mountinfo "$cfmgr_install_awk" inventory-v1 "$cfmgr_dependencies_context" /proc/self/mountinfo >"$cfmgr_install_context/repair-cleanup.mounts" || return 1
		[ ! -s "$cfmgr_install_context/repair-cleanup.mounts" ] || return 1
	fi
	[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_dependencies_context" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ]
}

# The private claim parent is admitted once by bootstrap. Never chmod/reclaim an
# existing claim. Fixed literal listing plus FD proof prevents adopting its data.
cfmgr_dependencies_claim_admit() {
	[ -d "$1" ] && [ ! -L "$1" ] || return 2
	cfmgr_dependencies_claim_metadata=$("$cfmgr_install_ls" -ldn "$1") || return 2
	IFS=' ' read -r cfmgr_dependencies_claim_mode cfmgr_dependencies_claim_links cfmgr_dependencies_claim_uid cfmgr_dependencies_claim_rest <<EOF_CLAIM
$cfmgr_dependencies_claim_metadata
EOF_CLAIM
	[ "$cfmgr_dependencies_claim_mode:$cfmgr_dependencies_claim_uid" = drwx------:0 ] || return 2
	if [ -e "$1/owner" ] || [ -L "$1/owner" ]; then
		[ -f "$1/owner" ] && [ ! -L "$1/owner" ] || return 2
		cfmgr_dependencies_claim_metadata=$("$cfmgr_install_ls" -ldn "$1/owner") || return 2
		IFS=' ' read -r cfmgr_dependencies_claim_mode cfmgr_dependencies_claim_links cfmgr_dependencies_claim_uid cfmgr_dependencies_claim_rest <<EOF_OWNER_MODE
$cfmgr_dependencies_claim_metadata
EOF_OWNER_MODE
		[ "$cfmgr_dependencies_claim_mode:$cfmgr_dependencies_claim_uid" = -rw-------:0 ] || return 2
	fi
}

cfmgr_dependencies_admit() {
	cfmgr_bootstrap_attached || return 2
	if cfmgr_bootstrap_admit_tool /opt/bin/opkg; then :; else
		cfmgr_dependencies_opkg_code=$?
		[ "$cfmgr_dependencies_opkg_code" -ne 3 ] || return 3
		return 2
	fi
	[ -x /opt/bin/opkg ] || return 1
	for cfmgr_dependencies_native_tool in /bin/mount /bin/umount /bin/mknod /usr/sbin/chroot /bin/kill /bin/ln /bin/rm /bin/rmdir; do
		cfmgr_dependencies_native_resolved=$("$cfmgr_install_readlink" -f "$cfmgr_dependencies_native_tool") || return 2
		# Native BusyBox applets can be literal firmware symlinks to busybox.
		case $cfmgr_dependencies_native_resolved in "$cfmgr_dependencies_native_tool" | /bin/busybox) ;; *) return 2 ;; esac
		cfmgr_bootstrap_native_protected "$cfmgr_dependencies_native_resolved" executable || return $?
	done
	cfmgr_dependencies_logger_admitted=0
	# Syslog availability cannot decide whether ordinary dependency repair runs.
	if [ -f /usr/bin/logger ] && [ -x /usr/bin/logger ]; then
		cfmgr_dependencies_logger_resolved=$("$cfmgr_install_readlink" -f /usr/bin/logger) || return 0
		case $cfmgr_dependencies_logger_resolved in
		/usr/bin/logger | /bin/busybox)
			if cfmgr_bootstrap_native_protected "$cfmgr_dependencies_logger_resolved" executable; then
				cfmgr_dependencies_logger_admitted=1
			else
				cfmgr_dependencies_logger_code=$?
				[ "$cfmgr_dependencies_logger_code" -ne 3 ] || return 3
			fi
			;;
		esac
	fi
}

# Finite native dispatcher. The supervisor does not accept arbitrary commands;
# every mode below maps to one previously admitted native applet/grammar.
cfmgr_dependencies_native_tool() {
	case $1 in
	inventory | awk | identity-parse) cfmgr_dependencies_native_tool=$cfmgr_install_awk ;;
	identity | list) cfmgr_dependencies_native_tool=$cfmgr_install_ls ;;
	readlink) cfmgr_dependencies_native_tool=$cfmgr_install_readlink ;;
	mkdir) cfmgr_dependencies_native_tool=$cfmgr_install_mkdir ;;
	copy) cfmgr_dependencies_native_tool=$cfmgr_install_cp ;;
	chmod) cfmgr_dependencies_native_tool=$cfmgr_install_chmod ;;
	link) cfmgr_dependencies_native_tool=/bin/ln ;;
	root | guard-root | bind4 | bind7 | private | unbindable | seal) cfmgr_dependencies_native_tool=/bin/mount ;;
	unmount) cfmgr_dependencies_native_tool=/bin/umount ;;
	file) cfmgr_dependencies_native_tool=$cfmgr_install_sh ;;
	fifo) cfmgr_dependencies_native_tool=/bin/mknod ;;
	report) cfmgr_dependencies_native_tool=/usr/bin/logger ;;
	signal) cfmgr_dependencies_native_tool=/bin/kill ;;
	remove) cfmgr_dependencies_native_tool=/bin/rm ;;
	rmdir | retire) cfmgr_dependencies_native_tool=/bin/rmdir ;;
	*) return 2 ;;
	esac
}

cfmgr_dependencies_native() {
	[ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ] || return 3
	cfmgr_dependencies_native_mode=$1
	shift
	if [ "$cfmgr_dependencies_native_mode" = retire ]; then
		[ "$#" -eq 1 ] && [ "$1" = "$cfmgr_dependencies_context" ] &&
			[ "${cfmgr_dependencies_claimed:-0}:${cfmgr_dependencies_snapshot_ready:-0}:${cfmgr_dependencies_cleaning:-0}" = 1:1:1 ] || return 2
		case ${cfmgr_dependencies_phase:-none} in cleanup | preparing) ;; *) return 2 ;; esac
		[ ! -e "$1/owner" ] && [ ! -L "$1/owner" ] || return 2
		# A previous deletion/replacement cannot authorize another rmdir.
		cfmgr_dependencies_attachment_ok || return 3
	fi
	cfmgr_dependencies_native_tool "$cfmgr_dependencies_native_mode" || return 2
	cfmgr_dependencies_operation_context=$cfmgr_install_context
	cfmgr_dependencies_operation_probe=$cfmgr_install_source/modules/helpers/worker.sh
	if [ "${cfmgr_dependencies_snapshot_ready:-0}" = 1 ]; then
		cfmgr_dependencies_operation_probe=$cfmgr_install_context/repair-worker.sh
		if [ "${cfmgr_dependencies_cleaning:-0}" != 1 ] && [ "${cfmgr_dependencies_claimed:-0}" = 1 ]; then cfmgr_dependencies_operation_context=$cfmgr_dependencies_context; fi
	fi
	case $cfmgr_dependencies_native_mode in
	inventory) set -- "$cfmgr_install_context/repair-storage.sh" "$@" ;;
	awk) set -- "$cfmgr_dependencies_context/execution.sh" "$cfmgr_view_context" "$cfmgr_view_native_root" "$@" ;;
	identity)
		cfmgr_dependencies_identity_target=$2
		set -- "$1"
		;;
	esac
	# Snapshot-copy bootstrap can still use the admitted source parser before its
	# private replacement exists; all later cleanup requires the RAM replacement.
	cfmgr_dependencies_retiring=0
	if [ "$cfmgr_dependencies_native_mode" = retire ]; then cfmgr_dependencies_retiring=1; fi
	if cfmgr_prerequisites_run "repair-$cfmgr_dependencies_native_mode" "$cfmgr_dependencies_operation_context" "$cfmgr_install_sh" "$cfmgr_dependencies_operation_probe" \
		"$cfmgr_install_env" "$cfmgr_install_awk" "$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_dependencies_native_tool" "$@"; then :; else
		cfmgr_dependencies_native_code=$?
		cfmgr_dependencies_retiring=0
		if [ "$cfmgr_dependencies_native_code" -eq 3 ]; then
			cfmgr_dependencies_native_unresolved=1 cfmgr_dependencies_state=retained
			cfmgr_dependencies_native_pid=$cfmgr_probe_pid cfmgr_dependencies_native_start=$cfmgr_probe_start cfmgr_dependencies_native_boot=$cfmgr_probe_boot
		fi
		return "$cfmgr_dependencies_native_code"
	fi
	cfmgr_dependencies_retiring=0
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	if [ "$cfmgr_dependencies_native_mode" = identity ]; then
		cfmgr_dependencies_identity_raw=$cfmgr_probe_stdout
		cfmgr_dependencies_native identity-parse "$cfmgr_dependencies_identity_raw" "$cfmgr_dependencies_identity_target"
		return $?
	fi
	[ ! -s "$cfmgr_probe_stdout" ] || return 1
}

# Normal cleanup removes only a pinned private claim after verified root/thread
# quiescence, keeper reap and an empty current mount inventory. No recursive rm.
cfmgr_dependencies_cleanup() {
	if [ "${cfmgr_dependencies_phase:-none}" != preparing ]; then
		[ "$cfmgr_view_state:$cfmgr_keeper_state:$cfmgr_tasks_state" = released:released:quiescent ] || return 3
	fi
	cfmgr_dependencies_attachment_ok || return 3
	cfmgr_dependencies_cleanup_count=0 cfmgr_dependencies_cleaning=1
	cfmgr_dependencies_native inventory "$cfmgr_dependencies_context" "$cfmgr_install_context/repair-empty.mounts" || return 3
	[ ! -s "$cfmgr_install_context/repair-empty.mounts" ] || return 3
	LC_ALL=C _cfmgr_dependencies_tree_check "$cfmgr_dependencies_context" 0 || return 3
	cfmgr_dependencies_cleanup_count=0
	LC_ALL=C _cfmgr_dependencies_remove_tree "$cfmgr_dependencies_context" 0 || return 3
}

# DIR/depth/byte count stay in each recursive positional frame; remaining args
# are at most 64 owned file/FIFO paths and 8192 bytes including their NULs.
_cfmgr_dependencies_remove_batch() {
	[ "$3" -le 8192 ] || return 3
	shift 3
	[ "$#" -gt 0 ] || return 0
	[ "$#" -le 64 ] || return 3
	cfmgr_dependencies_native remove "$@"
}

_cfmgr_dependencies_remove_tree() {
	[ "$2" -le 3 ] && [ -d "$1" ] && [ ! -L "$1" ] || return 3
	set -- "$1" "$2" 0
	for cfmgr_dependencies_cleanup_item in "$1"/* "$1"/.[!.]* "$1"/..?*; do
		[ -e "$cfmgr_dependencies_cleanup_item" ] || [ -L "$cfmgr_dependencies_cleanup_item" ] || continue
		[ "$cfmgr_dependencies_cleanup_item" != "$cfmgr_dependencies_context/owner" ] || continue
		cfmgr_dependencies_cleanup_count=$((cfmgr_dependencies_cleanup_count + 1))
		[ "$cfmgr_dependencies_cleanup_count" -le 4096 ] && [ ! -L "$cfmgr_dependencies_cleanup_item" ] || return 3
		if [ -d "$cfmgr_dependencies_cleanup_item" ]; then
			_cfmgr_dependencies_remove_tree "$cfmgr_dependencies_cleanup_item" "$(($2 + 1))" || return 3
			continue
		elif [ -f "$cfmgr_dependencies_cleanup_item" ]; then
			:
		elif [ -p "$cfmgr_dependencies_cleanup_item" ]; then
			case $cfmgr_dependencies_cleanup_item in "$cfmgr_dependencies_context/keeper/control" | "$cfmgr_dependencies_context/gate") ;; *) return 3 ;; esac
		else return 3; fi
		# LC_ALL=C on the root call makes shell lengths byte counts. Recompute
		# candidate length after any recursion; only positionals retain batch size.
		cfmgr_dependencies_cleanup_bytes=$((${#cfmgr_dependencies_cleanup_item} + 1))
		[ "$cfmgr_dependencies_cleanup_bytes" -le 8192 ] || return 3
		if [ "$#" -eq 67 ] || [ "$(($3 + cfmgr_dependencies_cleanup_bytes))" -gt 8192 ]; then
			_cfmgr_dependencies_remove_batch "$@" || return 3
			set -- "$1" "$2" 0
		fi
		cfmgr_dependencies_batch_dir=$1 cfmgr_dependencies_batch_depth=$2
		cfmgr_dependencies_batch_bytes=$(($3 + cfmgr_dependencies_cleanup_bytes))
		shift 3
		set -- "$cfmgr_dependencies_batch_dir" "$cfmgr_dependencies_batch_depth" "$cfmgr_dependencies_batch_bytes" "$@" "$cfmgr_dependencies_cleanup_item"
	done
	_cfmgr_dependencies_remove_batch "$@" || return 3
	# Failed file batches/child directories preserve the owner for recovery. The
	# owner is never mixed into a batch whose other removals could partly fail.
	if [ "$1" = "$cfmgr_dependencies_context" ]; then
		cfmgr_dependencies_native remove "$1/owner" || return 3
		cfmgr_dependencies_native retire "$1"
	else cfmgr_dependencies_native rmdir "$1"; fi
}

_cfmgr_dependencies_tree_check() {
	[ "$2" -le 3 ] && [ -d "$1" ] && [ ! -L "$1" ] || return 3
	for cfmgr_dependencies_check_item in "$1"/* "$1"/.[!.]* "$1"/..?*; do
		[ -e "$cfmgr_dependencies_check_item" ] || [ -L "$cfmgr_dependencies_check_item" ] || continue
		cfmgr_dependencies_cleanup_count=$((cfmgr_dependencies_cleanup_count + 1))
		[ "$cfmgr_dependencies_cleanup_count" -le 4096 ] && [ ! -L "$cfmgr_dependencies_check_item" ] || return 3
		[ "$((${#cfmgr_dependencies_check_item} + 1))" -le 8192 ] || return 3
		if [ -d "$cfmgr_dependencies_check_item" ]; then
			_cfmgr_dependencies_tree_check "$cfmgr_dependencies_check_item" "$(($2 + 1))" || return 3
		elif [ -f "$cfmgr_dependencies_check_item" ]; then
			:
		elif [ -p "$cfmgr_dependencies_check_item" ]; then
			case $cfmgr_dependencies_check_item in "$cfmgr_dependencies_context/keeper/control" | "$cfmgr_dependencies_context/gate") ;; *) return 3 ;; esac
		else return 3; fi
	done
}

# Native syslog submission is an attempt, never a claim that a lost destination
# stored it. Console evidence remains available even when logger cannot complete.
cfmgr_dependencies_report() {
	case $1 in
	storage-lost) printf '[CFMGR] dependencies: error: Entware attachment lost; cleanup pending\n' >&2 ;;
	cleanup-pending) printf '[CFMGR] dependencies: error: dependency cleanup pending\n' >&2 ;;
	cleanup-complete) printf '[CFMGR] dependencies: error: Entware operation stopped; owned mounts released\n' >&2 ;;
	*) return 2 ;;
	esac
	# Loss console evidence is immediate. Native submission follows cancellation,
	# so an unresolved logger can never prevent the owned opkg stop attempt.
	[ "$1" != storage-lost ] || return 0
	if [ "${cfmgr_dependencies_logger_admitted:-0}" != 1 ]; then
		printf '[CFMGR] dependencies: warning: native system log unavailable\n' >&2
		return 0
	fi
	[ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ] || return 3
	cfmgr_dependencies_native report "$1"
}

cfmgr_dependencies_inside_tools() {
	cfmgr_dependencies_inside_shell=/bin/sh cfmgr_dependencies_inside_awk=/usr/bin/awk
	cfmgr_dependencies_inside_readlink=/usr/bin/readlink cfmgr_dependencies_inside_usleep=/bin/usleep
}

# ---- launch ----
# Source-inert retained launch. Dependency scope follows validated settings.
# Never constructs defaults, starts features or invokes the fresh transaction.
# shellcheck disable=SC2034,SC2154 # Explicit bootstrap/storage/parser result fields.

# The limited menu exposes status and the complete dependency action. Exact tokens,
# back/EOF and default-no confirmation never reach RAM/native preparation.

cfmgr_launch_confirm_reinstall() {
	[ -t 0 ] || {
		printf '[CFMGR] dependencies: warning: interactive confirmation required\n' >&2
		return 1
	}
	printf 'Reinstall selected Entware dependencies? [y/N] '
	IFS= read -r cfmgr_launch_answer || return 4
	case $cfmgr_launch_answer in y | Y | yes | YES) return 0 ;; esac
	return 4
}

cfmgr_launch_attachment_ok() {
	cfmgr_bootstrap_native_attached || return 1
	if [ "${cfmgr_launch_storage_required:-0}" = 1 ]; then cfmgr_storage_attached || return 1; fi
	cfmgr_launch_guard_attachment || return 1
	if [ "${cfmgr_launch_migrating:-0}" = 1 ]; then cfmgr_launch_original_attached || return 1; fi
}

# shellcheck disable=SC3013 # Native BusyBox -ef compares the pinned Linux FD inode.
cfmgr_launch_guard_attachment() {
	if [ "${cfmgr_launch_guard_owned:-0}" = 1 ]; then
		if [ ! -L "$cfmgr_launch_guard" ] && [ "$cfmgr_launch_guard" -ef /proc/self/fd/4 ]; then :; else
			# Only the terminal exact rmdir may remove the pinned guard inode.
			[ "${cfmgr_launch_retiring:-0}" = 1 ] && [ "${cfmgr_probe_mode:-}" = launch-rmdir ] && [ -n "${cfmgr_probe_pid:-}" ] || return 1
			cfmgr_launch_deleted=$("$cfmgr_install_ls" -Ldn /proc/self/fd/4) || return 1
			IFS=' ' read -r cfmgr_launch_mode cfmgr_launch_links cfmgr_launch_uid cfmgr_launch_rest <<EOF_DELETED
$cfmgr_launch_deleted
EOF_DELETED
			[ "$cfmgr_launch_mode:$cfmgr_launch_links:$cfmgr_launch_uid" = drwx------:0:0 ] || return 1
		fi
	fi
}

# Native-only fixed launch dispatch supports config preflight and reporting even
# before /opt can be pinned. Every ordinary install/native/repair guard is intact.
cfmgr_launch_action() {
	cfmgr_launch_mode=$1
	case $1 in
	launch-copy) cfmgr_launch_tool=$cfmgr_install_cp ;;
	launch-readonly) cfmgr_launch_tool=$cfmgr_install_chmod ;;
	launch-ls) cfmgr_launch_tool=$cfmgr_install_ls ;;
	launch-wc) cfmgr_launch_tool=$cfmgr_install_wc ;;
	launch-sha) cfmgr_launch_tool=$cfmgr_install_sha ;;
	launch-config-*) cfmgr_launch_tool=$cfmgr_install_awk ;;
	launch-report) cfmgr_launch_tool=$cfmgr_launch_logger ;;
	launch-remove) cfmgr_launch_tool=/bin/rm ;;
	launch-rmdir) cfmgr_launch_tool=/bin/rmdir ;;
	*) return 2 ;;
	esac
	shift
	cfmgr_prerequisites_run "$cfmgr_launch_mode" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/worker.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
		"$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_launch_tool" "$@" || return $?
	cfmgr_install_output=$cfmgr_probe_stdout
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	case $cfmgr_launch_mode in launch-ls | launch-wc | launch-sha | launch-config-*) ;; *) [ ! -s "$cfmgr_probe_stdout" ] || return 1 ;; esac
}

cfmgr_launch_size() {
	cfmgr_launch_action launch-wc "$1" || return $?
	IFS=' ' read -r cfmgr_launch_bytes cfmgr_launch_extra <"$cfmgr_install_output" || return 1
	[ -z "$cfmgr_launch_extra" ] || return 1
	case $cfmgr_launch_bytes in '' | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_launch_bytes}" -le 6 ] && [ "$cfmgr_launch_bytes" -le "$2" ]
}

cfmgr_launch_metadata() {
	[ ! -L "$1" ] || return 1
	cfmgr_launch_action launch-ls "$1" || return $?
	IFS=' ' read -r cfmgr_launch_permissions cfmgr_launch_links cfmgr_launch_uid cfmgr_launch_gid cfmgr_launch_rest <"$cfmgr_install_output" || return 1
	[ "$cfmgr_launch_uid" = 0 ] || return 1
	case $2:$cfmgr_launch_permissions in
	private:drwx------ | config:-rw------- | readonly:-rw-r--r--) return 0 ;;
	protected:d????????? | protected:-?????????)
		case $cfmgr_launch_permissions in ?????w???? | ????????w?) return 1 ;; esac
		return 0
		;;
	*) return 1 ;;
	esac
}

cfmgr_launch_config() {
	# MODE SNAPSHOT. Data enters ENV only after the supervisor env-i boundary.
	cfmgr_launch_size "$2" 65536 || return $?
	cfmgr_launch_input_bytes=$cfmgr_launch_bytes
	if [ "$1" = check ] || [ "$1" = scope ]; then
		cfmgr_launch_action "launch-config-$1" "$cfmgr_launch_input_bytes" "$cfmgr_install_source/modules/lib/config.sh" \
			"$cfmgr_install_source/modules/lib/config.sh" "$2"
	else
		cfmgr_launch_action "launch-config-$1" "$cfmgr_launch_input_bytes" "$cfmgr_install_source/modules/lib/config.sh" \
			"$cfmgr_install_source/modules/lib/config.sh" "$2" "$cfmgr_storage_uuid_value" \
			"$cfmgr_storage_filesystem" "$cfmgr_storage_fsroot" "$cfmgr_storage_relative"
	fi
}

# The parser emits only framed generation/scope after complete schema validation.
# Native rechecks before opkg do not depend on a usable jq or SHA implementation.
cfmgr_launch_scope() {
	cfmgr_launch_config scope "$1" || return $?
	cfmgr_launch_scope_receipt=$cfmgr_install_output
	cfmgr_launch_size "$cfmgr_launch_scope_receipt" 96 || return $?
	cfmgr_launch_scope_line='' cfmgr_launch_scope_tail=''
	{
		IFS= read -r cfmgr_launch_scope_line || return 1
		if IFS= read -r cfmgr_launch_scope_tail; then return 1; fi
		[ -z "$cfmgr_launch_scope_tail" ] || return 1
	} <"$cfmgr_launch_scope_receipt" || return 1
	[ "$cfmgr_launch_bytes" -eq "$((${#cfmgr_launch_scope_line} + 1))" ] || return 1
	IFS=' ' read -r cfmgr_launch_scope_tag cfmgr_launch_scope_schema cfmgr_launch_scope_generation cfmgr_launch_scope_value cfmgr_launch_scope_end cfmgr_launch_scope_extra <<EOF_SCOPE
$cfmgr_launch_scope_line
EOF_SCOPE
	[ "$cfmgr_launch_scope_tag:$cfmgr_launch_scope_schema:$cfmgr_launch_scope_end:$cfmgr_launch_scope_extra" = CFMGR-SCOPE:1:END: ] || return 1
	case $cfmgr_launch_scope_generation in '' | 0* | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_launch_scope_generation}" -le 20 ] || return 1
	case $cfmgr_launch_scope_value in shared | tunnel) ;; *) return 1 ;; esac
	[ "$cfmgr_launch_scope_line" = "CFMGR-SCOPE 1 $cfmgr_launch_scope_generation $cfmgr_launch_scope_value END" ]
}

cfmgr_launch_reinstall_scope() {
	cfmgr_launch_scope "$cfmgr_launch_snapshot" || return $?
	[ "$cfmgr_launch_scope_generation" = "$cfmgr_launch_generation" ] || return 1
	cfmgr_install_dependency_scope=$cfmgr_launch_scope_value
}

cfmgr_launch_reinstall_recheck() {
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_scope "$cfmgr_launch_live" || return $?
	[ "$cfmgr_launch_scope_generation:$cfmgr_launch_scope_value" = "$cfmgr_launch_generation:$cfmgr_install_dependency_scope" ] || {
		printf '[CFMGR] dependencies: warning: configuration changed; retry explicitly\n' >&2
		return 1
	}
}

cfmgr_launch_receipt() {
	cfmgr_launch_receipt_file=$cfmgr_install_output
	cfmgr_launch_size "$cfmgr_launch_receipt_file" 128 || return $?
	cfmgr_launch_receipt_bytes=$cfmgr_launch_bytes
	cfmgr_launch_line='' cfmgr_launch_tail=''
	{
		IFS= read -r cfmgr_launch_line || return 1
		if IFS= read -r cfmgr_launch_tail; then return 1; fi
		[ -z "$cfmgr_launch_tail" ] || return 1
	} <"$cfmgr_launch_receipt_file" || return 1
	[ "$cfmgr_launch_receipt_bytes" -eq "$((${#cfmgr_launch_line} + 1))" ] || return 1
	IFS=' ' read -r cfmgr_launch_tag cfmgr_launch_schema cfmgr_launch_oldgen cfmgr_launch_newgen cfmgr_launch_changed cfmgr_launch_in cfmgr_launch_out cfmgr_launch_end cfmgr_launch_extra <<EOF_RECEIPT
$cfmgr_launch_line
EOF_RECEIPT
	[ "$cfmgr_launch_tag:$cfmgr_launch_schema:$cfmgr_launch_end:$cfmgr_launch_extra" = CFMGR-CONFIG:1:END: ] || return 1
	[ "$cfmgr_launch_line" = "CFMGR-CONFIG 1 $cfmgr_launch_oldgen $cfmgr_launch_newgen $cfmgr_launch_changed $cfmgr_launch_in $cfmgr_launch_out END" ] || return 1
	for cfmgr_launch_number in "$cfmgr_launch_oldgen" "$cfmgr_launch_newgen"; do
		case $cfmgr_launch_number in '' | 0* | *[!0-9]*) return 1 ;; esac
		[ "${#cfmgr_launch_number}" -le 20 ] || return 1
	done
	case $cfmgr_launch_changed in 0 | 1) ;; *) return 1 ;; esac
	for cfmgr_launch_number in "$cfmgr_launch_in" "$cfmgr_launch_out"; do
		case $cfmgr_launch_number in '' | *[!0-9]*) return 1 ;; esac
		[ "${#cfmgr_launch_number}" -le 5 ] && [ "$cfmgr_launch_number" -le 65536 ] || return 1
	done
	[ "$cfmgr_launch_in" = "$cfmgr_launch_input_bytes" ]
}

# Structural admission precedes repair; digest-complete admission follows healthy
# post-probes. Installed cfmgr.sh maps to the external scripts entry, never reset.
cfmgr_launch_package_structure() {
	cfmgr_launch_guard=$cfmgr_install_source/.storage-observation
	for cfmgr_launch_blocker in "$cfmgr_launch_guard" "$cfmgr_install_source/entry.stage" "$cfmgr_install_source/.setup.complete" "$cfmgr_install_source/.config-save.preparing" "$cfmgr_install_source/.config-save" "$cfmgr_install_source/.config-save.retired"; do
		[ ! -e "$cfmgr_launch_blocker" ] && [ ! -L "$cfmgr_launch_blocker" ] || return 1
	done
	cfmgr_launch_metadata "$cfmgr_install_source" private || return $?
	for cfmgr_launch_top in "$cfmgr_install_source"/* "$cfmgr_install_source"/.[!.]* "$cfmgr_install_source"/..?*; do
		[ -e "$cfmgr_launch_top" ] || [ -L "$cfmgr_launch_top" ] || continue
		case ${cfmgr_launch_top##*/} in catalog.txt | manifest.txt | setup-state | config | modules) ;; *) return 1 ;; esac
	done
	cfmgr_launch_metadata "$cfmgr_install_source/manifest.txt" readonly || return $?
	cfmgr_launch_size "$cfmgr_install_source/manifest.txt" 131072 || return $?
	cfmgr_launch_metadata "$cfmgr_install_source/catalog.txt" readonly || return $?
	cfmgr_launch_size "$cfmgr_install_source/catalog.txt" 131072 || return $?
	for cfmgr_launch_passive in manifest.txt catalog.txt; do
		cfmgr_launch_action launch-copy "$cfmgr_install_source/$cfmgr_launch_passive" "$cfmgr_install_context/$cfmgr_launch_passive.snapshot" || return $?
	done
	cfmgr_bootstrap_manifest_records "$cfmgr_install_context/manifest.txt.snapshot" "$cfmgr_install_context/catalog.txt.snapshot" || return $?
	cfmgr_launch_metadata "$cfmgr_install_source/setup-state" config || return $?
	cfmgr_launch_size "$cfmgr_install_source/setup-state" 128 || return $?
	cfmgr_launch_setup="CFMGR-SETUP 1 $CFMGR_VERSION complete"
	[ "$cfmgr_launch_bytes" -eq "$((${#cfmgr_launch_setup} + 1))" ] || return 1
	IFS= read -r cfmgr_launch_actual <"$cfmgr_install_source/setup-state" || return 1
	[ "$cfmgr_launch_actual" = "$cfmgr_launch_setup" ] || return 1
	cfmgr_install_walk_count=0
	{
		printf '%s\n' cfmgr.sh catalog.txt modules/
		cfmgr_bootstrap_walk "$cfmgr_install_source" "$cfmgr_install_source/modules" 0
	} >"$cfmgr_install_context/launch.inventory" || return 1
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { FS="\t" }
	 NR==FNR { expected[$4]=1; path=$4; while(sub(/\/[^\/]+$/,"",path)) expected[path "/"]=1; next }
	 { if (!expected[$0] || seen[$0]++) bad=1 }
	 END { for(p in expected) if(!seen[p]) bad=1; exit bad ? 1 : 0 }
	' "$cfmgr_install_context/records" "$cfmgr_install_context/launch.inventory" || return 1
	# Keep FD0 as the context. Only finite metadata probes run while FD4 reads.
	exec 4<"$cfmgr_install_context/launch.inventory" || return 1
	cfmgr_launch_structure_code=0
	while IFS= read -r cfmgr_launch_directory <&4; do
		case $cfmgr_launch_directory in */)
			if cfmgr_launch_metadata "$cfmgr_install_source/${cfmgr_launch_directory%/}" protected; then :; else
				cfmgr_launch_structure_code=$?
				break
			fi
			;;
		esac
	done
	exec 4<&-
	[ "$cfmgr_launch_structure_code" -eq 0 ] || return "$cfmgr_launch_structure_code"
	exec 4<"$cfmgr_install_context/records" || return 1
	cfmgr_launch_structure_code=0
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative <&4; do
		case $cfmgr_install_relative in cfmgr.sh) cfmgr_launch_payload=$cfmgr_install_jffs/scripts/cfmgr.sh ;; *) cfmgr_launch_payload=$cfmgr_install_source/$cfmgr_install_relative ;; esac
		if cfmgr_launch_metadata "$cfmgr_launch_payload" protected; then :; else
			cfmgr_launch_structure_code=$?
			break
		fi
	done
	exec 4<&-
	[ "$cfmgr_launch_structure_code" -eq 0 ] || return "$cfmgr_launch_structure_code"
	cfmgr_launch_live=$cfmgr_install_source/config
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_size "$cfmgr_launch_live" 65536 || return $?
	cfmgr_launch_snapshot=$cfmgr_install_context/config.snapshot
	cfmgr_launch_action launch-copy "$cfmgr_launch_live" "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_action launch-readonly "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_config check "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_oldgen:$cfmgr_launch_newgen:$cfmgr_launch_changed:$cfmgr_launch_in" = "$cfmgr_launch_oldgen:$cfmgr_launch_oldgen:0:$cfmgr_launch_out" ] || return 1
	cfmgr_launch_generation=$cfmgr_launch_oldgen cfmgr_launch_snapshot_bytes=$cfmgr_launch_in
}

# shellcheck disable=SC3013 # Native BusyBox -ef verifies the original pinned FD.
cfmgr_launch_original_attached() {
	[ ! -L "$cfmgr_install_original_context" ] && [ "$cfmgr_install_original_context" -ef /proc/self/fd/3 ] || return 1
	[ "$(cfmgr_storage_mountinfo "$cfmgr_install_awk" "$cfmgr_install_original_context" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ]
}

cfmgr_launch_migrate_snapshot() {
	cfmgr_launch_migrating=1
	if cfmgr_launch_migrate_work; then cfmgr_launch_migration_code=0; else cfmgr_launch_migration_code=$?; fi
	cfmgr_launch_migrating=0
	return "$cfmgr_launch_migration_code"
}

cfmgr_launch_migrate_work() {
	cfmgr_launch_original_attached && cfmgr_launch_attachment_ok || return 1
	cfmgr_launch_migrated=$cfmgr_install_context/config.snapshot
	[ ! -e "$cfmgr_launch_migrated" ] && [ ! -L "$cfmgr_launch_migrated" ] || return 1
	# Raw copy only: bootstrap_copy/flush would clobber original context FD3.
	cfmgr_launch_action launch-copy "$cfmgr_launch_snapshot" "$cfmgr_launch_migrated" || return $?
	cfmgr_bootstrap_digest "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_saved_digest=$cfmgr_install_digest
	cfmgr_launch_size "$cfmgr_launch_snapshot" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_snapshot_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_migrated" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_saved_digest" ] || return 1
	cfmgr_launch_config check "$cfmgr_launch_migrated" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_newgen:$cfmgr_launch_oldgen:$cfmgr_launch_changed:$cfmgr_launch_in" = "$cfmgr_launch_generation:$cfmgr_launch_generation:0:$cfmgr_launch_out" ] || return 1
	[ "$cfmgr_launch_in" = "$cfmgr_launch_snapshot_bytes" ] || return 1
	for cfmgr_launch_passive in records manifest.txt.snapshot catalog.txt.snapshot; do
		cfmgr_launch_action launch-copy "$cfmgr_install_original_context/$cfmgr_launch_passive" "$cfmgr_install_context/$cfmgr_launch_passive" || return $?
		cfmgr_bootstrap_digest "$cfmgr_install_original_context/$cfmgr_launch_passive" || return $?
		cfmgr_launch_saved_digest=$cfmgr_install_digest
		cfmgr_bootstrap_digest "$cfmgr_install_context/$cfmgr_launch_passive" || return $?
		[ "$cfmgr_install_digest" = "$cfmgr_launch_saved_digest" ] || return 1
	done
	cfmgr_launch_snapshot=$cfmgr_launch_migrated
}

cfmgr_launch_package_digests() {
	cfmgr_launch_attachment_ok || return 1
	for cfmgr_launch_passive in manifest.txt catalog.txt; do
		cfmgr_bootstrap_digest "$cfmgr_install_context/$cfmgr_launch_passive.snapshot" || return $?
		cfmgr_launch_saved_digest=$cfmgr_install_digest
		cfmgr_bootstrap_digest "$cfmgr_install_source/$cfmgr_launch_passive" || return $?
		[ "$cfmgr_install_digest" = "$cfmgr_launch_saved_digest" ] || return 1
	done
	exec 4<"$cfmgr_install_context/records" || return 1
	cfmgr_launch_digest_code=0
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative <&4; do
		case $cfmgr_install_relative in cfmgr.sh) cfmgr_launch_payload=$cfmgr_install_jffs/scripts/cfmgr.sh ;; *) cfmgr_launch_payload=$cfmgr_install_source/$cfmgr_install_relative ;; esac
		if cfmgr_bootstrap_file "$cfmgr_launch_payload"; then :; else
			cfmgr_launch_digest_code=$?
			break
		fi
	done
	exec 4<&-
	return "$cfmgr_launch_digest_code"
}

cfmgr_launch_live_unchanged() {
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_size "$cfmgr_launch_live" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_snapshot_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_live" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_snapshot_digest" ]
}

cfmgr_launch_observation() {
	cfmgr_bootstrap_digest "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_snapshot_digest=$cfmgr_install_digest
	cfmgr_launch_live_unchanged || return $?
	cfmgr_launch_config observe "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_oldgen" = "$cfmgr_launch_generation" ] || return 1
	cfmgr_launch_target_generation=$cfmgr_launch_newgen cfmgr_launch_target_bytes=$cfmgr_launch_out
	if [ "$cfmgr_launch_changed" = 0 ]; then return 0; fi
	cfmgr_launch_config patch "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_candidate=$cfmgr_install_output
	cfmgr_launch_size "$cfmgr_launch_candidate" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_target_bytes" ] || return 1
	cfmgr_launch_config observe "$cfmgr_launch_candidate" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_oldgen:$cfmgr_launch_newgen:$cfmgr_launch_changed:$cfmgr_launch_in" = "$cfmgr_launch_target_generation:$cfmgr_launch_target_generation:0:$cfmgr_launch_target_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_candidate" || return $?
	cfmgr_launch_candidate_digest=$cfmgr_install_digest
	cfmgr_launch_publish_observation
}

cfmgr_launch_publish_observation() {
	# Inline wrapper preserves the original transaction's recovery/child state.
	if cfmgr_config_store_observation_lock && cfmgr_launch_publish_observation_locked; then cfmgr_launch_lock_code=0; else cfmgr_launch_lock_code=$?; fi
	if [ "$cfmgr_launch_lock_code" != 3 ]; then
		exec 0<&-
		cfmgr_config_lock_fd0=0
	fi
	return "$cfmgr_launch_lock_code"
}

cfmgr_launch_publish_observation_locked() {
	cfmgr_launch_attachment_ok && cfmgr_launch_live_unchanged || return $?
	[ ! -e "$cfmgr_launch_guard" ] && [ ! -L "$cfmgr_launch_guard" ] || return 1
	cfmgr_launch_space_needed=$(((cfmgr_launch_snapshot_bytes + cfmgr_launch_target_bytes + 262144 + 1023) / 1024))
	cfmgr_bootstrap_space "$cfmgr_install_jffs" "$cfmgr_launch_space_needed" || return $?
	cfmgr_bootstrap_action install-mkdir-private "$cfmgr_launch_guard" || return $?
	cfmgr_launch_recovery=1 cfmgr_launch_guard_owned=1
	exec 4<"$cfmgr_launch_guard" || return 3
	cfmgr_bootstrap_flush "$cfmgr_launch_guard" && cfmgr_bootstrap_flush "$cfmgr_install_source" || return $?
	cfmgr_bootstrap_copy "$cfmgr_launch_snapshot" "$cfmgr_launch_guard/old" 0600 || return $?
	cfmgr_bootstrap_copy "$cfmgr_launch_candidate" "$cfmgr_launch_guard/candidate" 0600 || return $?
	cfmgr_bootstrap_digest "$cfmgr_launch_guard/old" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_snapshot_digest" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_guard/candidate" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_candidate_digest" ] || return 1
	(
		umask 077
		set -C
		printf 'CFMGR-OBSERVATION 1 %s %s %s %s END\n' "$cfmgr_launch_generation" "$cfmgr_launch_target_generation" "$cfmgr_launch_snapshot_digest" "$cfmgr_launch_target_bytes" >"$cfmgr_install_context/observation.intent"
	) || return 1
	cfmgr_bootstrap_copy "$cfmgr_install_context/observation.intent" "$cfmgr_launch_guard/intent" 0600 || return $?
	cfmgr_launch_live_unchanged && cfmgr_launch_attachment_ok || return $?
	cfmgr_bootstrap_action install-rename "$cfmgr_launch_guard/candidate" "$cfmgr_launch_live" || return $?
	cfmgr_bootstrap_flush "$cfmgr_launch_live" && cfmgr_bootstrap_flush "$cfmgr_install_source" || return $?
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_size "$cfmgr_launch_live" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_target_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_live" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_candidate_digest" ] || return 1
	cfmgr_launch_action launch-remove "$cfmgr_launch_guard/old" || return $?
	cfmgr_launch_action launch-remove "$cfmgr_launch_guard/intent" || return $?
	cfmgr_launch_retiring=1
	if cfmgr_launch_action launch-rmdir "$cfmgr_launch_guard"; then cfmgr_launch_retire_code=0; else cfmgr_launch_retire_code=$?; fi
	cfmgr_launch_retiring=0
	[ "$cfmgr_launch_retire_code" -eq 0 ] || return "$cfmgr_launch_retire_code"
	cfmgr_launch_guard_owned=0
	exec 4<&-
	cfmgr_bootstrap_flush "$cfmgr_install_source" || return $?
	cfmgr_launch_recovery=0
	printf '[CFMGR] launch: notice: verified Entware observation updated\n'
}

cfmgr_launch_logger_admit() {
	cfmgr_launch_logger_resolved=$("$cfmgr_install_readlink" -f "$cfmgr_launch_logger") || return 1
	case $cfmgr_launch_logger_resolved in /usr/bin/logger | /bin/busybox) ;; *) return 1 ;; esac
	cfmgr_launch_logger_parent=/usr/bin
	while :; do
		cfmgr_launch_metadata "$cfmgr_launch_logger_parent" protected || return $?
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_launch_logger_parent")" = "$cfmgr_launch_logger_parent" ] || return 1
		[ "$cfmgr_launch_logger_parent" != / ] || break
		cfmgr_launch_logger_parent=${cfmgr_launch_logger_parent%/*}
		[ -n "$cfmgr_launch_logger_parent" ] || cfmgr_launch_logger_parent=/
	done
	cfmgr_launch_logger_parent=$cfmgr_launch_logger_resolved
	while :; do
		cfmgr_launch_metadata "$cfmgr_launch_logger_parent" protected || return $?
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_launch_logger_parent")" = "$cfmgr_launch_logger_parent" ] || return 1
		[ "$cfmgr_launch_logger_parent" != / ] || break
		cfmgr_launch_logger_parent=${cfmgr_launch_logger_parent%/*}
		[ -n "$cfmgr_launch_logger_parent" ] || cfmgr_launch_logger_parent=/
	done
}

cfmgr_launch_storage_unavailable() {
	cfmgr_launch_reported=1
	printf '[CFMGR] launch: error: Entware attachment unavailable; operation stopped\n' >&2
	cfmgr_launch_logger=/usr/bin/logger
	# Optional logger cannot change operational failure into success; unresolved
	# native ownership retains the RAM context and prevents subsequent probes.
	if [ ! -f "$cfmgr_launch_logger" ] || [ ! -x "$cfmgr_launch_logger" ]; then
		printf '[CFMGR] launch: warning: native system log unavailable\n' >&2
		return 1
	fi
	if cfmgr_launch_logger_admit; then :; else
		cfmgr_launch_log_code=$?
		[ "$cfmgr_launch_log_code" -ne 3 ] || return 3
		printf '[CFMGR] launch: warning: native system log unavailable\n' >&2
		return 1
	fi
	if cfmgr_launch_action launch-report storage-unavailable; then return 1; else
		cfmgr_launch_log_code=$?
		[ "$cfmgr_launch_log_code" -ne 3 ] || return 3
		printf '[CFMGR] launch: warning: native system log delivery unconfirmed\n' >&2
		return 1
	fi
}

cfmgr_launch_work() {
	cfmgr_launch_package_structure || return $?
	if cfmgr_storage_pin /opt /usr/bin/readlink /usr/bin/awk "$cfmgr_install_source/modules/lib/storage.sh" /proc/self; then :; else
		cfmgr_launch_storage_unavailable
		return $?
	fi
	cfmgr_launch_storage_required=1
	cfmgr_bootstrap_shared_requirements retained "${cfmgr_launch_requested_action:-normal}" || return $?
	# Shared post-probes leave4/5 free. Preserve context through all file loops.
	exec 5<&0 0<&-
	cfmgr_install_context_fd=5
	cfmgr_launch_package_digests || return $?
	cfmgr_launch_observation || return $?
	cfmgr_launch_attachment_ok || return 1
	if [ "${cfmgr_launch_requested_action:-normal}" = reinstall ]; then
		printf '[CFMGR] dependencies: notice: selected dependencies reinstalled and verified\n'
	else
		printf '[CFMGR] launch: notice: shared dependencies verified; tunnel DNS %s; feature operations unavailable\n' "${cfmgr_install_dns_result:-not-required}"
	fi
}

cfmgr_launch_native() {
	[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ "$1" = "/jffs/addons/CFMgr.d" ] || return 2
	cfmgr_launch_requested_action=${2:-normal}
	case $cfmgr_launch_requested_action in
	normal) ;;
	reinstall)
		if cfmgr_launch_confirm_reinstall; then :; else
			cfmgr_launch_confirm_code=$?
			printf '[CFMGR] dependencies: notice: reinstall cancelled\n' >&2
			return "$cfmgr_launch_confirm_code"
		fi
		;;
	*) return 2 ;;
	esac
	cfmgr_launch_storage_required=0 cfmgr_launch_guard_owned=0 cfmgr_launch_retiring=0 cfmgr_launch_migrating=0 cfmgr_launch_recovery=0
	cfmgr_bootstrap_native_prepare "$1" launch || return $?
	if cfmgr_launch_work; then cfmgr_launch_status=0; else cfmgr_launch_status=$?; fi
	if [ "$cfmgr_launch_status" -ne 0 ] && [ "$cfmgr_launch_status" -ne 3 ] &&
		[ "$cfmgr_launch_storage_required" = 1 ] && [ "${cfmgr_dependencies_loss:-0}" = 0 ] && ! cfmgr_storage_attached; then
		# A resolved inventory/publication failure may also be attachment loss.
		# Reporting alone uses native/JFFS/RAM admission; no further storage work.
		cfmgr_launch_storage_required=0
		if cfmgr_launch_storage_unavailable; then :; else
			cfmgr_launch_report_code=$?
			[ "$cfmgr_launch_report_code" -ne 3 ] || cfmgr_launch_status=3
		fi
	fi
	if [ "$cfmgr_launch_status" -eq 3 ]; then
		printf '[CFMGR] launch: error: owned work unresolved; recovery required\n' >&2
		return 3
	fi
	if [ "$cfmgr_launch_recovery" = 1 ]; then
		printf '[CFMGR] launch: error: observation recovery required (%s)\n' "$cfmgr_install_context" >&2
		return "$cfmgr_launch_status"
	fi
	if ! cfmgr_bootstrap_cleanup; then
		printf '[CFMGR] launch: error: preflight cleanup pending\n' >&2
		return 3
	fi
	[ "$cfmgr_install_interrupted" = 0 ] || return 1
	trap - HUP INT TERM
	return "$cfmgr_launch_status"
}

# ---- Embedded parser admission ----
# Called only in a supervised trusted worker. Candidate sources are file DATA;
# this final native AWK exec has the same deadline/reaping owner as every probe.
cfmgr_package_awk_extract_exec() {
	[ "$#" -eq 3 ] || exit 2
	cfmgr_candidate_tool=$1 cfmgr_candidate_root=$2
	case $3 in
	config) cfmgr_candidate_parts="json config_schema config_observation" ;;
	status) cfmgr_candidate_parts="json status" ;;
	backup_payload) cfmgr_candidate_parts="json config_schema config_observation backup_payload" ;;
	backup_history) cfmgr_candidate_parts="json backup_history" ;;
	backup_inventory) cfmgr_candidate_parts="backup_manifest backup_inventory" ;;
	mountinfo | status_native | backup_archive_control | backup_cloud_writer | backup_manifest | backup_payload_index | backup_payload_match | backup_pem | backup_tar | backup_yaml) cfmgr_candidate_parts=$3 ;;
	*) exit 2 ;;
	esac
	# Four fixed owner files are already byte/mode admitted. No candidate shell
	# executes, even when a malicious file supplies syntactically valid commands.
	exec "$cfmgr_candidate_tool" -v root="$cfmgr_candidate_root" -v parts="$cfmgr_candidate_parts" '
 function owner(f) {
  if(f=="json" || f=="config_schema" || f=="config_observation")return "config"
  if(f=="mountinfo")return "storage"
  if(f=="status" || f=="status_native")return "status"
  return "backup"
 }
 BEGIN {quote=sprintf("%c",39);count=split(parts,order," ");for(i=1;i<=count;i++)wanted[order[i]]=1}
 FNR==1 {if(state)bad=1;previous="";bytes=0}
 {bytes+=length($0)+1;if(bytes>1048576 || length($0)>65536)bad=1}
 /^\t# CFMGR-AWK-BEGIN / {
  f=substr($0,20)
  if(wanted[f]) {expected=root "/modules/" ((owner(f)=="config" || owner(f)=="storage")?"lib/":"") owner(f) ".sh";if(FILENAME!=expected || seen[f]++ || state || previous!="cfmgr_" owner(f) "_awk_" f "() {")bad=1;state=1;fragment=f;next}
 }
 state==1 {if($0!="\tcfmgr_awk_program=" quote)bad=1;state=2;program[fragment]="\n";next}
 state==2 {if($0==quote){state=3;next};if(index($0,quote))bad=1;program[fragment]=program[fragment] $0 "\n";if(length(program[fragment])>98304)bad=1;next}
 state==3 {if($0!="\t# CFMGR-AWK-END " fragment)bad=1;state=4;next}
 state==4 {if($0!="}")bad=1;state=0;done[fragment]++;next}
 {previous=$0}
 END {
  for(i=1;i<=count;i++){f=order[i];if(seen[f]!=1 || done[f]!=1)bad=1;output=output program[f]}
  if(bad || state || length(output)>98304)exit 1
  printf "%s",output
 }
 ' "$cfmgr_candidate_root/modules/lib/config.sh" "$cfmgr_candidate_root/modules/lib/storage.sh" "$cfmgr_candidate_root/modules/status.sh" "$cfmgr_candidate_root/modules/backup.sh"
}
