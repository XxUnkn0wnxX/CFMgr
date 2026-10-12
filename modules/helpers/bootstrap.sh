#!/bin/sh
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
	install-rename | install-publish) cfmgr_install_tool=$cfmgr_install_mv ;;
	install-mkdir-*) cfmgr_install_tool=$cfmgr_install_mkdir ;;
	install-chmod-*) cfmgr_install_tool=$cfmgr_install_chmod ;;
	install-flush) cfmgr_install_tool=$cfmgr_install_fsync ;;
	install-config | install-config-check) cfmgr_install_tool=$cfmgr_install_jq ;;
	install-df) cfmgr_install_tool=$cfmgr_install_df ;;
	install-nvram) cfmgr_install_tool=$cfmgr_install_nvram ;;
	*) return 2 ;;
	esac
	shift
	cfmgr_prerequisites_run "$cfmgr_install_action" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/probe.sh" "$cfmgr_install_env" \
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
	[ -f "$cfmgr_install_source/manifest.txt" ] && [ ! -L "$cfmgr_install_source/manifest.txt" ] || return 1
	cfmgr_bootstrap_metadata "$cfmgr_install_source/manifest.txt" "$cfmgr_install_owner" 0644 || return $?
	cfmgr_bootstrap_size "$cfmgr_install_source/manifest.txt" || return $?
	[ "$cfmgr_install_size" -le 131072 ] || return 1
	# Parse bounded manifest data, never eval/source it. Output is also bounded by
	# the finite input/count/path limits and lives in the private RAM context.
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" '
		BEGIN { FS="\t"; version=ARGV[1]; ARGV[1]="" }
		NR==1 { if ($0 != "CFMGR-MANIFEST 1 " version) bad=1; next }
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
			required="cfmgr.sh catalog.txt modules/lib/config.sh modules/lib/storage.sh modules/lib/prerequisites.sh modules/lib/mountinfo.awk modules/helpers/bootstrap.sh modules/helpers/probe.sh"
			n=split(required,names," "); for (i=1;i<=n;i++) if (!seen[names[i]]) bad=1
			if (bad || count<2) exit 1
		}
	' "$CFMGR_VERSION" "$cfmgr_install_source/manifest.txt" >"$cfmgr_install_context/records" || return 1
	# Catalog is passive schema/versioned data matching the complete module set.
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { FS="\t"; version=ARGV[1]; ARGV[1]="" }
		NR==FNR { if ($4~/^modules\//) expected[$4]=1; next }
		FNR==1 { if ($0!="CFMGR-CATALOG 1 " version) bad=1; next }
		{
			kind=($1~/^modules\/lib\// ? "library" : ($1~/^modules\/helpers\// ? "helper" : "data"))
			if (NF!=2 || !expected[$1] || seen[$1]++ || $2!=kind) bad=1
		}
		END { for (path in expected) if (!seen[path]) bad=1; if (bad) exit 1 }
	' "$CFMGR_VERSION" "$cfmgr_install_context/records" "$cfmgr_install_source/catalog.txt" || return 1
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
	cfmgr_bootstrap_digest "$cfmgr_install_source/manifest.txt" || return $?
	cfmgr_install_manifest_digest=$cfmgr_install_digest
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative; do
		cfmgr_bootstrap_file "$cfmgr_install_source/$cfmgr_install_relative" || return $?
	done <"$cfmgr_install_context/records"
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
	cfmgr_bootstrap_action install-df "$cfmgr_install_jffs" || return $?
	# The validated inventory bounds the sum. Reserve two copies plus native
	# erase-block/config/metadata allowance, rather than requiring an unused maximum.
	# shellcheck disable=SC2016
	cfmgr_install_needed=$("$cfmgr_install_awk" '{ total+=$2 } END { print int((2*total+262144+1023)/1024) }' "$cfmgr_install_context/records") || return 1
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { need=ARGV[1]; ARGV[1]="" }
		NR==2 { n++; if ($4 !~ /^[0-9]+$/ || $4<need) bad=1 }
		END { if (n!=1 || bad) exit 1 }' "$cfmgr_install_needed" "$cfmgr_install_output" || return 1
	# Prepare defaults only after retained-state and package/tool admission. They
	# remain private RAM data until the claimed installation guard is durable.
	cfmgr_bootstrap_action install-config "$cfmgr_install_source" "$CFMGR_REPOSITORY" "$CFMGR_BRANCH" "$cfmgr_install_uuid" "$cfmgr_install_filesystem" "$cfmgr_install_fsroot" "$cfmgr_install_relative_opt" || return $?
	cfmgr_install_config=$cfmgr_install_output
	cfmgr_bootstrap_action install-config-check "$cfmgr_install_config" || return $?
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
	cfmgr_bootstrap_action install-config-check "$cfmgr_install_support/config" || return $?
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
	# Complete is the last published record. A failed final flush returns failure;
	# existing installation paths always prevent reset, even if recovery recording fails.
	(
		umask 077
		printf 'CFMGR-SETUP 1 %s complete\n' "$CFMGR_VERSION" >"$cfmgr_install_context/setup.complete"
	) || return 1
	cfmgr_bootstrap_copy "$cfmgr_install_context/setup.complete" "$cfmgr_install_support/.setup.complete" 0600 || return $?
	cfmgr_bootstrap_action install-rename "$cfmgr_install_support/.setup.complete" "$cfmgr_install_support/setup-state" || return $?
	if ! cfmgr_bootstrap_record "$cfmgr_install_support/setup-state" complete || ! cfmgr_bootstrap_flush "$cfmgr_install_support/setup-state" || ! cfmgr_bootstrap_flush "$cfmgr_install_support" || ! cfmgr_bootstrap_attached; then
		cfmgr_bootstrap_copy "$cfmgr_install_context/setup.installing" "$cfmgr_install_support/setup-state" 0600 || :
		return 1
	fi
	cfmgr_install_result=complete
}

cfmgr_bootstrap_signals() {
	cfmgr_install_interrupted=0
	trap 'cfmgr_install_interrupted=1' HUP INT TERM
}

cfmgr_bootstrap_attached() {
	[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
	cfmgr_storage_attached || return 1
	if [ -n "${cfmgr_install_context:-}" ]; then
		case $cfmgr_install_context_fd in 0 | 5) ;; *) return 1 ;; esac
		[ ! -L "$cfmgr_install_context" ] && [ "$cfmgr_install_context" -ef "/proc/self/fd/$cfmgr_install_context_fd" ] || return 1
		[ "$("$cfmgr_install_awk" -f "$cfmgr_install_source/modules/lib/mountinfo.awk" "$cfmgr_install_context" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ] || return 1
	fi
	[ ! -L "$cfmgr_install_source" ] && [ ! -L "$cfmgr_install_jffs" ] &&
		[ "$cfmgr_install_source" -ef /proc/self/fd/9 ] &&
		[ "$cfmgr_install_jffs" -ef /proc/self/fd/8 ] || return 1
	[ "$("$cfmgr_install_readlink" -f "$cfmgr_install_source")" = "$cfmgr_install_source" ] &&
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_install_jffs")" = "$cfmgr_install_jffs" ] || return 1
	for cfmgr_install_attachment_path in "$cfmgr_install_jffs" "$cfmgr_install_jffs/scripts" "$cfmgr_install_jffs/addons"; do
		if [ -e "$cfmgr_install_attachment_path" ] || [ -L "$cfmgr_install_attachment_path" ]; then
			[ -d "$cfmgr_install_attachment_path" ] && [ ! -L "$cfmgr_install_attachment_path" ] || return 1
			[ "$("$cfmgr_install_awk" -f "$cfmgr_install_source/modules/lib/mountinfo.awk" "$cfmgr_install_attachment_path" /proc/self/mountinfo)" = "$cfmgr_install_jffs_snapshot" ] || return 1
		fi
	done
}

cfmgr_prerequisites_attachment_ok() {
	cfmgr_bootstrap_attached
}

# Storage identity fields are supplied by the explicit storage library.
# shellcheck disable=SC2154
cfmgr_bootstrap_admit_tool() {
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ -x "$1" ] || return 1
	cfmgr_install_resolved=$("$cfmgr_install_readlink" -f "$1") || return 1
	cfmgr_bootstrap_path "$cfmgr_install_resolved" || return 1
	case $cfmgr_install_resolved in "$cfmgr_storage_opt"/*) ;; *) return 1 ;; esac
	[ "$("$cfmgr_install_awk" -f "$cfmgr_install_source/modules/lib/mountinfo.awk" "$cfmgr_install_resolved" /proc/self/mountinfo)" = "$cfmgr_storage_snapshot" ] || return 1
	cfmgr_bootstrap_metadata "$cfmgr_install_resolved" 0 protected || return $?
	cfmgr_install_resolved=${cfmgr_install_resolved%/*}
	while :; do
		cfmgr_bootstrap_metadata "$cfmgr_install_resolved" 0 protected || return $?
		[ "$cfmgr_install_resolved" != "$cfmgr_storage_opt" ] || break
		cfmgr_install_resolved=${cfmgr_install_resolved%/*}
	done
}

# Remove only the FD-pinned private, flat RAM context after all owned children
# have been reaped. Unknown objects/ownership preserve the one active claim.
cfmgr_bootstrap_cleanup() {
	[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
	case $cfmgr_install_context_fd in 0 | 5) ;; *) return 1 ;; esac
	[ "$cfmgr_install_context" = /tmp/cfmgr/install ] &&
		[ ! -L /tmp/cfmgr/install ] && [ /tmp/cfmgr/install -ef "/proc/self/fd/$cfmgr_install_context_fd" ] || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 1
	cfmgr_install_cleanup_count=0
	for cfmgr_install_cleanup_item in /tmp/cfmgr/install/* /tmp/cfmgr/install/.[!.]* /tmp/cfmgr/install/..?*; do
		[ -e "$cfmgr_install_cleanup_item" ] || [ -L "$cfmgr_install_cleanup_item" ] || continue
		[ -f "$cfmgr_install_cleanup_item" ] && [ ! -L "$cfmgr_install_cleanup_item" ] || return 1
		cfmgr_install_cleanup_count=$((cfmgr_install_cleanup_count + 1))
		[ "$cfmgr_install_cleanup_count" -le 4096 ] || return 1
	done
	for cfmgr_install_cleanup_item in /tmp/cfmgr/install/* /tmp/cfmgr/install/.[!.]* /tmp/cfmgr/install/..?*; do
		[ -f "$cfmgr_install_cleanup_item" ] || continue
		/bin/rm -f "$cfmgr_install_cleanup_item" || return 1
	done
	/bin/rmdir /tmp/cfmgr/install || return 1
	case $cfmgr_install_context_fd in 0) exec 0<&- ;; 5) exec 5<&- ;; esac
}

# Explicit storage/prerequisite imports supply result fields; proc/listing
# receiving fields keep their fixed positions even when policy needs a subset.
# shellcheck disable=SC2034,SC2154
cfmgr_bootstrap_native() {
	[ "$#" -eq 1 ] && cfmgr_bootstrap_path "$1" || return 2
	cfmgr_install_source=$1 cfmgr_install_jffs=/jffs cfmgr_install_opt=/opt cfmgr_install_owner=0
	cfmgr_install_sh=/bin/sh cfmgr_install_env=/usr/bin/env cfmgr_install_awk=/usr/bin/awk
	cfmgr_install_readlink=/usr/bin/readlink cfmgr_install_sleep=/bin/sleep cfmgr_install_wc=/usr/bin/wc
	cfmgr_install_ls=/bin/ls cfmgr_install_fsync=/bin/fsync cfmgr_install_mkdir=/bin/mkdir
	cfmgr_install_cp=/bin/cp cfmgr_install_chmod=/bin/chmod cfmgr_install_mv=/bin/mv
	cfmgr_install_df=/bin/df cfmgr_install_nvram=/bin/nvram
	cfmgr_install_sha=/opt/bin/sha256sum cfmgr_install_jq=/opt/bin/jq
	for cfmgr_install_argument in /bin/sh /usr/bin/env /usr/bin/awk /usr/bin/readlink /bin/sleep /usr/bin/wc /bin/ls /bin/fsync /bin/mkdir /bin/cp /bin/chmod /bin/mv /bin/df /bin/nvram /bin/rm /bin/rmdir /sbin/blkid; do
		[ -f "$cfmgr_install_argument" ] && [ -x "$cfmgr_install_argument" ] || return 2
	done
	# The native proc UID record proves all four credential IDs are root.
	# shellcheck disable=SC2016
	/usr/bin/awk '$1=="Uid:" { n++; if (NF!=5 || $2!=0 || $3!=0 || $4!=0 || $5!=0) bad=1 }
		END { if (n!=1 || bad) exit 1 }' /proc/self/status || return 1
	[ -d /jffs ] && [ ! -L /jffs ] && [ -d "$cfmgr_install_source" ] && [ ! -L "$cfmgr_install_source" ] || return 1
	cfmgr_install_jffs_snapshot=$(/usr/bin/awk -f "$cfmgr_install_source/modules/lib/mountinfo.awk" /jffs /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_install_jffs_id cfmgr_install_jffs_parent cfmgr_install_jffs_device cfmgr_install_jffs_root cfmgr_install_jffs_mount cfmgr_install_jffs_type cfmgr_install_jffs_device_path cfmgr_install_jffs_options cfmgr_install_jffs_superoptions <<EOF
$cfmgr_install_jffs_snapshot
EOF
	[ "$cfmgr_install_jffs_mount" = /jffs ] && [ "$cfmgr_install_jffs_type" = jffs2 ] || return 1
	case ,$cfmgr_install_jffs_options, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_install_jffs_options, in *,noexec,* | *,ro,*) return 1 ;; esac
	exec 8</jffs 9<"$cfmgr_install_source" || return 1
	cfmgr_storage_pin /opt /usr/bin/readlink /usr/bin/awk "$cfmgr_install_source/modules/lib/mountinfo.awk" /proc/self || return $?
	# Prove RAM backing before creating any preflight object.
	[ -d /tmp ] && [ ! -L /tmp ] && [ "$(/usr/bin/readlink -f /tmp)" = /tmp ] || return 1
	cfmgr_install_tmp_snapshot=$(/usr/bin/awk -f "$cfmgr_install_source/modules/lib/mountinfo.awk" /tmp /proc/self/mountinfo) || return 1
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
	cfmgr_install_context=/tmp/cfmgr/install
	/bin/mkdir -m 700 /tmp/cfmgr/install || return 1
	exec 0</tmp/cfmgr/install || return 1
	cfmgr_install_context_fd=0
	cfmgr_bootstrap_signals
	cfmgr_probe_serial=0
	cfmgr_probe_pid='' cfmgr_probe_status=invalid
	if cfmgr_bootstrap_native_work; then cfmgr_install_native_status=0; else cfmgr_install_native_status=$?; fi
	if ! cfmgr_bootstrap_cleanup; then
		printf '%s\n' 'CFMgr retained probe context: /tmp/cfmgr/install (recovery required).' >&2
		return 1
	fi
	[ "$cfmgr_install_interrupted" = 0 ] || return 1
	trap - HUP INT TERM
	return "$cfmgr_install_native_status"
}

# The outer admission function owns the single RAM claim and its cleanup.
# shellcheck disable=SC2034,SC2154
cfmgr_bootstrap_native_work() {
	cfmgr_bootstrap_retained || return 1
	cfmgr_bootstrap_action install-nvram || return $?
	IFS= read -r cfmgr_install_scripts_enabled <"$cfmgr_install_output" || return 1
	[ "$cfmgr_install_scripts_enabled" = 1 ] || return 1
	cfmgr_prerequisites_run blkid "$cfmgr_install_context" /bin/sh "$cfmgr_install_source/modules/helpers/probe.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc /sbin/blkid "$cfmgr_storage_source" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	cfmgr_storage_uuid "$cfmgr_probe_stdout" || return $?
	for cfmgr_install_admit_path in "$cfmgr_storage_opt" "$cfmgr_storage_opt/bin" "$cfmgr_storage_opt/lib"; do
		cfmgr_bootstrap_metadata "$cfmgr_install_admit_path" 0 protected || return $?
	done
	cfmgr_bootstrap_admit_tool /opt/bin/jq && cfmgr_bootstrap_admit_tool /opt/bin/timeout && cfmgr_bootstrap_admit_tool /opt/bin/sha256sum || return $?
	cfmgr_install_native_flock=/usr/bin/flock cfmgr_install_entware_flock=-
	if [ -x /opt/bin/flock ]; then
		cfmgr_bootstrap_admit_tool /opt/bin/flock || return $?
		cfmgr_install_entware_flock=/opt/bin/flock
	fi
	if [ ! -f /usr/bin/flock ] || [ ! -x /usr/bin/flock ]; then cfmgr_install_native_flock=-; fi
	cfmgr_prerequisites_check shared "$cfmgr_install_context" /bin/sh "$cfmgr_install_source/modules/helpers/probe.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_install_native_flock" /opt/bin/jq /opt/bin/timeout /opt/bin/sha256sum "$cfmgr_install_entware_flock" - unknown || return $?
	# Flock probes have released FD4/5. Keep the context off stdin before
	# transaction while-read loops temporarily redirect FD0 to manifest records.
	exec 5<&0 0<&-
	cfmgr_install_context_fd=5
	# Prove native flush diagnostics on an owned RAM directory before JFFS mutation.
	cfmgr_bootstrap_flush "$cfmgr_install_context" || return $?
	cfmgr_bootstrap_transaction "$cfmgr_install_source" /jffs "$cfmgr_storage_opt" "$cfmgr_install_context" 0 \
		/bin/sh /usr/bin/env /usr/bin/awk /usr/bin/readlink /bin/sleep /usr/bin/wc /bin/ls /bin/fsync \
		/bin/mkdir /bin/cp /bin/chmod /bin/mv /opt/bin/sha256sum /opt/bin/jq \
		"$cfmgr_storage_uuid_value" "$cfmgr_storage_filesystem" "$cfmgr_storage_fsroot" "$cfmgr_storage_relative" /bin/df
}
