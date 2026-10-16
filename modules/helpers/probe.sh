#!/bin/sh
# shellcheck disable=SC2034 # Fixed sourced view parser consumes explicit fields.
# Fixed prerequisite probes. Paths are admitted by the caller, never discovered here.
set -f
[ "$#" -ge 1 ] || exit 2
mode=$1
shift
case "$mode" in
exit-seven)
	[ "$#" -eq 0 ] || exit 2
	exit 7
	;;
sleep-short)
	[ "$#" -eq 2 ] || exit 2
	# Direct workstation tests can exercise GNU timeout, but cannot prove
	# Linux ownership. The production supervisor rejects hosts without proc.
	[ -r /proc/self/stat ] || exec "$1" 1
	# Before exec, record the one child GNU timeout owns. No child commands here.
	IFS= read -r boot </proc/sys/kernel/random/boot_id || exit 2
	IFS= read -r identity </proc/self/stat || exit 2
	pid=${identity%% *}
	tail=${identity##*) }
	old_ifs=$IFS
	IFS=' '
	# Linux stat's numeric tail is deliberately split; pathname expansion is off.
	# shellcheck disable=SC2086
	set -- "$1" "$2" $tail
	IFS=$old_ifs
	native_sleep=$1
	context=$2
	shift 2
	ppid=$2
	shift 19
	start=$1
	set -C
	printf '%s %s %s %s\n' "$pid" "$ppid" "$start" "$boot" >"$context/timeout.child" || exit 2
	exec "$native_sleep" 1
	;;
esac
[ "$#" -ge 2 ] || exit 2
tool=$1
context=$2
shift 2
case "$tool:$context" in /*:/*) ;; *) exit 2 ;; esac
[ -f "$tool" ] && [ -x "$tool" ] && [ -d "$context" ] || exit 2
cd "$context" || exit 2
# Acquisition aliases retain the supervisor's distinct native-only admission;
# their executable/grammar is the same fixed trusted bootstrap implementation.
case $mode in
acquire-curl-version) mode=native-curl-version ;;
acquire-curl-offline) mode=native-curl-offline ;;
acquire-curl-features) mode=native-curl-features ;;
acquire-ca-pem) mode=native-ca-pem ;;
acquire-ca-decode) mode=native-ca-decode ;;
acquire-wc) mode=install-wc ;;
acquire-ls) mode=install-ls ;;
esac
case "$mode" in
acquire-lines)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -l <"$1"
	;;
acquire-text)
	[ "$#" -eq 4 ] || exit 2
	case $2:$3:$4 in *[!0-9:]* | :* | *:) exit 2 ;; esac
	case $4 in 0 | 1) ;; *) exit 2 ;; esac
	# Native WC LF count + byte count detect NUL splitting/truncation in old
	# awk. A strict frame additionally requires its final LF; scripts may omit it.
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN{bytes=ARGV[1];lines=ARGV[2];strict=ARGV[3];ARGV[1]=ARGV[2]=ARGV[3]=""}
		{total+=length($0)+1}
		END{if(NR==lines){if(total!=bytes)exit 1}else if(strict || NR!=lines+1 || total-1!=bytes)exit 1}' "$2" "$3" "$4" "$1"
	;;
acquire-api | acquire-raw)
	[ "$#" -eq 5 ] || exit 2
	case "$1:$2:$4" in /*:/*:/*) ;; *) exit 2 ;; esac
	case $2 in *:*) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 1048576 ] || exit 2
	case $mode:$3 in acquire-api:https://api.github.com/repos/*/commits/* | acquire-raw:https://raw.githubusercontent.com/*) ;; *) exit 2 ;; esac
	[ ! -e "$4" ] && [ ! -L "$4" ] || exit 1
	# Pin a new private body before curl. Neither its path nor a substituted
	# stage can redirect a write after this open; no redirects/fallback are used.
	umask 077
	set -C
	exec 8>"$4" || exit 1
	if [ "$mode" = acquire-api ]; then
		set -- "$1" "$2" "$3" "$5" --header 'Accept: application/vnd.github.sha' --header 'X-GitHub-Api-Version: 2022-11-28'
	else set -- "$1" "$2" "$3" "$5"; fi
	cfmgr_acquire_ca=$1 cfmgr_acquire_capath=$2 cfmgr_acquire_url=$3 cfmgr_acquire_limit=$4
	shift 4
	exec "$tool" -q --silent --show-error --proto '=https' --proto-redir '=https' \
		--tlsv1.2 --cacert "$cfmgr_acquire_ca" --capath "$cfmgr_acquire_capath" --proxy '' --noproxy '*' \
		--connect-timeout 5 --max-time 10 --max-filesize "$cfmgr_acquire_limit" \
		--output /proc/self/fd/8 --write-out '%{http_code}\n' "$@" --url "$cfmgr_acquire_url"
	;;
acquire-digest)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" dgst -sha256 -r <"$1"
	;;
acquire-shell)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -n "$1"
	;;
acquire-awk)
	[ "$#" -eq 2 ] && [ "$1" = "$context/acquire.syntax.awk" ] || exit 2
	[ -f "$1" ] && [ ! -L "$1" ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	# Every file is parsed before the trusted first BEGIN terminates fatally.
	# Plain exit is unsafe: candidate END rules would still run. Config's tree
	# consumer is parsed with its already hash-verified companion definitions.
	case $2 in */modules/lib/config_observation.awk) exec "$tool" -f "$1" -f "${2%/*}/json.awk" -f "$2" /dev/null ;;
	*) exec "$tool" -f "$1" -f "$2" /dev/null ;;
	esac
	;;
acquire-mkdir)
	[ "$#" -eq 1 ] && [ ! -e "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -m 700 "$1"
	;;
acquire-chmod)
	[ "$#" -eq 2 ] && [ -f "$2" ] && [ ! -L "$2" ] || exit 2
	case $1 in 0644 | 0755) ;; *) exit 2 ;; esac
	exec "$tool" "$1" "$2"
	;;
acquire-remove | acquire-rmdir)
	[ "$#" -eq 1 ] && [ ! -L "$1" ] || exit 2
	case $mode in acquire-remove)
		[ -f "$1" ] || exit 2
		exec "$tool" -f "$1"
		;;
	*)
		[ -d "$1" ] || exit 2
		exec "$tool" "$1"
		;;
	esac
	;;
acquire-entry)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN {version=ARGV[1];ARGV[1]=""} /^CFMGR_VERSION=/ {n++;if($0!="CFMGR_VERSION=" version)bad=1} END{exit (n!=1 || bad)}' "$2" "$1"
	;;
acquire-manifest)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" '
		BEGIN {FS="\t";version=ARGV[1];ARGV[1]=""}
		NR==1 {if($0!="CFMGR-MANIFEST 2 " version " 1 1")bad=1;next}
		{
			if(NF!=4 || length($0)>512 || $1!~/^0(644|755)$/ || $2!~/^(0|[1-9][0-9]*)$/ || $2>1048576 ||
			length($3)!=64 || $3~/[^0-9a-f]/ || length($4)>256 || $4!~/^[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)*$/ ||
			$4~/(^|\/)(\.|\.\.)(\/|$)/ || seen[$4]++ || (prev!="" && $4<=prev)){bad=1;next}
			if($4!="cfmgr.sh" && $4!="catalog.txt" && $4!~/^modules\//)bad=1
			if($4=="cfmgr.sh" && $1!="0755")bad=1
			path=$4;depth=0;while(sub(/\/[^\/]+$/,"",path)){if(seen[path] || ++depth>16)bad=1}
			prev=$4;total+=$2;count++;if(count>512 || total>16777216)bad=1
			print
		}
		END {
			required="cfmgr.sh catalog.txt modules/backup.sh modules/manager_settings.sh modules/lib/acquire.sh modules/lib/package.sh modules/lib/config.sh modules/lib/config_store.sh modules/lib/storage.sh modules/lib/prerequisites.sh modules/lib/native.sh modules/lib/mount_keeper.sh modules/lib/execution_view.sh modules/lib/execution_tasks.sh modules/lib/dependencies.sh modules/lib/mountinfo.awk modules/helpers/mount_keeper.sh modules/helpers/dependencies.sh modules/helpers/bootstrap.sh modules/helpers/probe.sh modules/helpers/launch.sh modules/lib/json.awk modules/lib/config_observation.awk modules/status.sh modules/lib/status.awk modules/lib/status_native.awk"
			n=split(required,names," ");for(i=1;i<=n;i++)if(!seen[names[i]])bad=1
			if(bad || count<2)exit 1
		}' "$2" "$1"
	;;
acquire-catalog)
	[ "$#" -eq 3 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'BEGIN{FS="\t";version=ARGV[1];ARGV[1]=""}
		NR==FNR{if($4~/^modules\//)expected[$4]=1;next}
		FNR==1{if($0!="CFMGR-CATALOG 1 " version)bad=1;next}
		{kind=($1~/^modules\/lib\//?"library":($1~/^modules\/helpers\//?"helper":"data"));if(NF!=2 || !expected[$1] || seen[$1]++ || $2!=kind)bad=1}
		END{for(path in expected)if(!seen[path])bad=1;if(bad)exit 1}' "$3" "$1" "$2"
	;;
store-backup-config)
	[ "$#" -eq 9 ] || exit 2
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 1; done
	[ -f "$4" ] && [ ! -L "$4" ] || exit 1
	case $3 in backup-read | backup-observe | backup-patch) ;; *) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 65536 ] || exit 1
	export CFMGR_BACKUP_MOUNT="$6" CFMGR_BACKUP_UUID="$7" CFMGR_BACKUP_FILESYSTEM="$8" CFMGR_BACKUP_ROOT="$9"
	exec "$tool" -v cfmgr_config_mode="$3" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" -f "$1" -f "$2" <"$4"
	;;
store-backup-mounts | store-backup-mount)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in /tmp/mnt | /tmp/mnt/?*) ;; *) exit 2 ;; esac
	case $mode in
	store-backup-mounts) exec "$tool" -f "$1" subtree-v1 "$2" /proc/self/mountinfo ;;
	*) exec "$tool" -f "$1" "$2" /proc/self/mountinfo ;;
	esac
	;;
store-backup-blkid)
	[ "$#" -eq 1 ] && [ -b "$1" ] || exit 2
	exec "$tool" "$1"
	;;
store-backup-mkdir)
	[ "$#" -eq 0 ] && [ -d /proc/self/fd/6 ] || exit 2
	[ ! -e /proc/self/fd/6/CFBackup ] && [ ! -L /proc/self/fd/6/CFBackup ] || exit 1
	exec "$tool" /proc/self/fd/6/CFBackup
	;;
store-backup-chmod)
	[ "$#" -eq 0 ] && [ -d /proc/self/fd/7 ] || exit 2
	exec "$tool" 700 /proc/self/fd/7
	;;
store-settings)
	[ "$#" -eq 8 ] || exit 2
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 1; done
	[ -f "$4" ] && [ ! -L "$4" ] || exit 1
	case $3 in settings-read | settings-observe | settings-patch) ;; *) exit 2 ;; esac
	case $5 in '' | *[!0-9]*) exit 2 ;; esac
	[ "$5" -gt 0 ] && [ "$5" -le 65536 ] || exit 1
	export CFMGR_SETTINGS_MASK="$6" CFMGR_SETTINGS_CHECK="$7" CFMGR_SETTINGS_AUTO="$8"
	exec "$tool" -v cfmgr_config_mode="$3" -v cfmgr_json_mode=tree -v cfmgr_json_size="$5" -f "$1" -f "$2" <"$4"
	;;
store-count | store-meta | store-snapshot | store-digest)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 1
	case $mode in
	store-count) exec "$tool" -c <"$1" ;;
	store-meta) exec "$tool" -ildn "$1" ;;
	store-snapshot)
		exec 8<"$1" || exit 1
		[ -f /proc/self/fd/8 ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/8 ] || exit 1
		# BusyBox dd has no status=none. Errors still return nonzero; caller
		# requires exact metadata/size before and after this capped read.
		exec "$tool" bs=4096 count=17 <&8 2>/dev/null
		;;
	store-digest) exec "$tool" dgst -sha256 -r <"$1" ;;
	esac
	;;
store-meta-frame)
	[ "$#" -eq 1 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'NR!=1 || NF<7 || $1!~/^[0-9]+$/ || $2!="-rw-------" || $4!=0 || $6!~/^[0-9]+$/ || $6<1 || $6>65536 {bad=1; exit 1} {print $1 ":" $6} END {if(bad || NR!=1) exit 1}' "$1"
	;;
store-digest-frame)
	[ "$#" -eq 1 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" 'NR!=1 || length($0)!=71 || substr($0,65)!=" *stdin" || substr($0,1,64)~/[^0-9a-fA-F]/ {bad=1; exit 1} {print tolower(substr($0,1,64))} END {if(bad || NR!=1) exit 1}' "$1"
	;;
store-lock-create)
	[ "$#" -eq 1 ] || exit 2
	if [ -e "$1" ] || [ -L "$1" ]; then exit 0; fi
	umask 077
	set -C
	: >"$1"
	;;
store-lock)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 0
	;;
store-lock-test)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 1
	exec 4<>"$1" || exit 1
	exec "$tool" -n 4
	;;
store-flush)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" /proc/self/fd/3
	;;
store-copy)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ ! -e "$2" ] && [ ! -L "$2" ] || exit 1
	exec "$tool" "$1" "$2"
	;;
store-mkdir)
	[ "$#" -eq 1 ] && [ ! -e "$1" ] && [ ! -L "$1" ] || exit 1
	exec "$tool" -m 700 "$1"
	;;
store-move)
	[ "$#" -eq 2 ] && [ ! -L "$1" ] && [ ! -L "$2" ] || exit 1
	exec "$tool" "$1" "$2"
	;;
store-remove | store-rmdir)
	[ "$#" -eq 1 ] && [ ! -L "$1" ] || exit 1
	case $mode in store-remove) exec "$tool" -f "$1" ;; *) exec "$tool" "$1" ;; esac
	;;
store-space)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -Pk "$1"
	;;
store-space-frame)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" -v needed="$2" 'NR>2 || length($0)>1024 {bad=1; exit 1} NR==2 {if(NF!=6 || $4!~/^[0-9]+$/ || $4<needed) bad=1} END {if(bad || NR!=2) exit 1}' "$1"
	;;
store-intent)
	[ "$#" -eq 2 ] || exit 2
	# Fixed ASCII frame; decimal generation increment is string arithmetic.
	# shellcheck disable=SC2016
	exec "$tool" -v size="$2" '
	function gen(s) {return s~/^[1-9][0-9]*$/ && length(s)<=20}
	function inc(s, i,d,r,c) {c=1;r="";for(i=length(s);i>0;i--){d=substr(s,i,1)+c;c=d>9;r=(d%10) r}return (c?"1":"") r}
	NR!=1 || length($0)+1!=size || NF!=9 || $1!="CFMGR-SETTINGS-INTENT" || $2!="1" || $9!="END" || !gen($3) || !gen($4) || ("g" inc($3))!=("g" $4) || $5!~/^[1-9][0-9]*$/ || $6!~/^[1-9][0-9]*$/ || $5>65536 || $6>65536 || length($7)!=64 || length($8)!=64 || $7~/[^0-9a-f]/ || $8~/[^0-9a-f]/ {bad=1;exit 1}
	{if($0!=$1 " " $2 " " $3 " " $4 " " $5 " " $6 " " $7 " " $8 " " $9){bad=1;exit 1};print $3 " " $4 " " $5 " " $6 " " $7 " " $8}
	END {if(bad || NR!=1) exit 1}' "$1"
	;;
status-date)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" +%s
	;;
status-native)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	exec "$tool" -f "$1" resources "$2"
	;;
status-fields)
	[ "$#" -eq 4 ] && [ -f "$1" ] && [ ! -L "$1" ] && [ -f "$3" ] && [ ! -L "$3" ] || exit 2
	case $2 in nvram | space | mount | metadata | setup) ;; *) exit 2 ;; esac
	exec "$tool" -f "$1" "$2" "$3" "$4"
	;;
status-metadata)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -ildn "$1"
	;;
status-count)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 1
	exec "$tool" -c <"$1"
	;;
status-snapshot)
	[ "$#" -eq 1 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 1
	# Only the owned wrapper opens the source; no child is spawned before exec.
	# Native metadata was separately admitted. Pin and recheck its regular inode;
	# capped dd cannot follow a growing source indefinitely. Caller compares
	# immutable output size and fresh metadata before interpreting any JSON.
	exec 8<"$1" || exit 1
	[ -f /proc/self/fd/8 ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/8 ] || exit 1
	exec "$tool" bs=4096 count=17 <&8 2>/dev/null
	;;
status-config)
	[ "$#" -eq 11 ] || exit 2
	case $4 in select | render) ;; *) exit 2 ;; esac
	for parser in "$1" "$2"; do [ -f "$parser" ] && [ ! -L "$parser" ] || exit 1; done
	[ -f "$3" ] && [ ! -L "$3" ] || exit 1
	case ${11} in '' | *[!0-9]*) exit 1 ;; esac
	[ "${11}" -gt 0 ] && [ "${11}" -le 65536 ] || exit 1
	export CFMGR_STATUS_MODE="$4" CFMGR_STATUS_NOW="$5" CFMGR_STATUS_BOOT="$6" CFMGR_STATUS_REPOSITORY="$7" CFMGR_STATUS_BRANCH="$8" CFMGR_STATUS_WAN="$9" CFMGR_STATUS_CLOCK="${10}"
	exec "$tool" -v cfmgr_json_size="${11}" -v cfmgr_json_mode=tree -f "$1" -f "$2" <"$3"
	;;
status-nvram)
	[ "$#" -eq 1 ] || exit 2
	case $1 in productid | firmver | buildno | extendno | ntp_ready | wan0_primary | wan1_primary | wan0_proto | wan1_proto | wan0_ifname | wan1_ifname | wan0_pppoe_ifname | wan1_pppoe_ifname | wan0_ipaddr | wan1_ipaddr) ;; *) exit 2 ;; esac
	exec "$tool" get "$1"
	;;
status-realpath)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /jffs | /opt) ;; *) exit 2 ;; esac
	exec "$tool" -f "$1"
	;;
status-mount)
	[ "$#" -eq 2 ] && [ -f "$1" ] && [ ! -L "$1" ] || exit 2
	case $2 in /*) ;; *) exit 2 ;; esac
	exec "$tool" -f "$1" "$2" /proc/self/mountinfo
	;;
status-space)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /jffs | /opt) ;; *) exit 2 ;; esac
	exec "$tool" -Pk "$1"
	;;
native-dns-native-srv | native-dns-native-a)
	case $mode:$# in native-dns-native-srv:1) dns_host=_v2-origintunneld._tcp.argotunnel.com ;; native-dns-native-a:2) dns_host=$2 ;; *) exit 2 ;; esac
	case $mode in
	*-srv) dns_type=SRV ;;
	*)
		dns_type=A
		case $dns_host in '' | -* | *[!A-Za-z0-9.-]*) exit 2 ;; *.argotunnel.com) ;; *) exit 2 ;; esac
		[ "${#dns_host}" -le 253 ] || exit 2
		;;
	esac
	# Complete fixed argv always includes a host. No-host Usage is ambiguous.
	case $1 in
	q) exec "$tool" -q "$dns_type" "$dns_host" ;;
	long) exec "$tool" "--type=$dns_type" "$dns_host" ;;
	type) exec "$tool" "-type=$dns_type" -retry=1 -timeout=2 "$dns_host" ;;
	*) exit 2 ;;
	esac
	;;
native-dns-dig-srv)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" +time=2 +tries=1 +short SRV _v2-origintunneld._tcp.argotunnel.com
	;;
native-dns-dig-a)
	[ "$#" -eq 2 ] && [ "$1" = short ] || exit 2
	case $2 in '' | -* | *[!A-Za-z0-9.-]*) exit 2 ;; *.argotunnel.com) ;; *) exit 2 ;; esac
	[ "${#2}" -le 253 ] || exit 2
	exec "$tool" +time=2 +tries=1 +short A "$2"
	;;
native-dns-classify)
	[ "$#" -eq 3 ] || exit 2
	case $3 in '' | *[!0-9]*) exit 2 ;; esac
	# shellcheck disable=SC2016 # Fixed awk code, operands remain file data.
	exec "$tool" -v query_exit="$3" '
	 FILENAME==ARGV[1] { output=output $0 "\n"; next }
	 { error=error $0 "\n" }
	 END {
	   if (query_exit==0 && output!="" && error=="") { print "answer"; exit }
	   if (query_exit==1 && output=="" && error=="Invalid query type \"SRV\"\n") { print "unsupported"; exit }
	   if (query_exit==1 && output=="" && error=="nslookup: invalid query type \"\"\n") { print "syntax"; exit }
	   if (query_exit!=0 && output=="") {
	     count=split(error,lines,"\n"); usage=banner=description=optional=0; bad=0
	     for(i=1;i<=count;i++) {
	       if(lines[i]=="") continue
	       if(lines[i] ~ /^BusyBox v[0-9]+\.[0-9]+\.[0-9]+ .*multi-call binary\.$/) { banner++; continue }
	       if(lines[i]=="Usage: nslookup [HOST] [SERVER]") { usage++; continue }
	       if(lines[i]=="Query the nameserver for the IP address of the given HOST") { description++; continue }
	       if(lines[i]=="optionally using a specified DNS server") { optional++; continue }
	       bad=1
	     }
	     if(usage==1 && banner==1 && description==1 && optional==1 && !bad) { print "usage"; exit }
	   }
	   print "deferred"
	 }' "$1" "$2"
	;;
native-dns-parse-srv)
	[ "$#" -eq 2 ] || exit 2
	case $1 in native | dig) ;; *) exit 2 ;; esac
	# shellcheck disable=SC2016
	exec "$tool" -v provider="$1" '
	 function hostname(s,    n,a,i) {
	   sub(/\.$/,"",s)
	   if(length(s)>253 || s !~ /^[A-Za-z0-9.-]+$/ || s !~ /\.argotunnel\.com$/) return 0
	   n=split(s,a,"."); for(i=1;i<=n;i++) if(length(a[i])<1 || length(a[i])>63 || a[i] !~ /^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$/) return 0
	   return 1
	 }
	 function record(priority,weight,port,target) {
	   target=tolower(target)
	   if(priority !~ /^[0-9]+$/ || weight !~ /^[0-9]+$/ || length(priority)>5 || length(weight)>5 || priority>65535 || weight>65535 || port!="7844" || !hostname(target)) { bad=1; return }
	   sub(/\.$/,"",target)
	   if(!seen[target]++ && count<2) { count++; targets[count]=target }
	 }
	 length($0)>1024 || NR>64 || $0 ~ /[^ -~\t]/ { bad=1 }
	 provider=="dig" { if(NF!=4) bad=1; else record($1,$2,$3,$4); next }
	 provider=="native" && tolower($1)=="_v2-origintunneld._tcp.argotunnel.com" && $2=="service" && $3=="=" {
	   if(NF!=7) bad=1; else record($4,$5,$6,$7); next
	 }
	 provider=="native" && ($0=="" || $0=="Non-authoritative answer:" || $1=="Server:" || $1=="Address:") { next }
	 { bad=1 }
	 END { if(bad || !count) exit 1; for(i=1;i<=count;i++) printf "%s%s",targets[i],(i==count ? "\n" : " ") }
	' "$2"
	;;
native-dns-parse-a)
	[ "$#" -eq 3 ] || exit 2
	case $1 in native | dig) ;; *) exit 2 ;; esac
	# shellcheck disable=SC2016
	exec "$tool" -v provider="$1" -v target="$2" '
	 function ipv4(s,    a,n,i) {
	   n=split(s,a,"."); if(n!=4) return 0
	   for(i=1;i<=4;i++) if(a[i] !~ /^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0
	   return a[1]!=0 && a[1]!=127 && a[1]<224 && !(a[1]==169 && a[2]==254)
	 }
	 length($0)>1024 || NR>64 || $0 ~ /[^ -~\t]/ { bad=1 }
	 provider=="dig" { if(NF!=1 || !ipv4($1)) bad=1; else answers++; next }
	 provider=="native" && $1=="Name:" {
	   name=tolower($2); sub(/\.$/,"",name); if(NF!=2 || name!=target) bad=1; answer_name=1; next
	 }
	 provider=="native" && $1=="Address:" {
	   if(answer_name) { if(NF!=2 || !ipv4($2)) bad=1; else answers++ }
	   next
	 }
	 provider=="native" && ($0=="" || $0=="Non-authoritative answer:" || $1=="Server:") { next }
	 { bad=1 }
	 END { if(bad || !answers) exit 1; print "verified" }
	' "$3"
	;;
launch-config-check | launch-config-scope | launch-config-observe | launch-config-patch)
	case "$mode:$#" in launch-config-check:4 | launch-config-scope:4 | launch-config-observe:8 | launch-config-patch:8) ;; *) exit 2 ;; esac
	case $1 in '' | *[!0-9]*) exit 2 ;; esac
	[ "${#1}" -le 5 ] && [ "$1" -le 65536 ] || exit 2
	for path in "$2" "$3" "$4"; do
		case $path in /*) ;; *) exit 2 ;; esac
		[ -f "$path" ] && [ ! -L "$path" ] || exit 2
	done
	config_mode=${mode#launch-config-}
	if [ "$config_mode" = observe ] || [ "$config_mode" = patch ]; then
		CFMGR_CONFIG_UUID=$5 CFMGR_CONFIG_FILESYSTEM=$6 CFMGR_CONFIG_ROOT=$7 CFMGR_CONFIG_RELATIVE=$8
		export CFMGR_CONFIG_UUID CFMGR_CONFIG_FILESYSTEM CFMGR_CONFIG_ROOT CFMGR_CONFIG_RELATIVE
	fi
	exec "$tool" -v cfmgr_json_size="$1" -v cfmgr_json_mode=tree -v cfmgr_config_mode="$config_mode" -f "$2" -f "$3" <"$4"
	;;
launch-copy)
	[ "$#" -eq 2 ] || exit 2
	[ -f "$1" ] && [ ! -L "$1" ] && [ ! -e "$2" ] && [ ! -L "$2" ] || exit 2
	exec "$tool" "$1" "$2"
	;;
launch-ls | launch-wc | launch-sha | launch-remove | launch-rmdir | launch-readonly)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	case $mode in
	launch-ls) exec "$tool" -ldn "$1" ;;
	launch-wc) exec "$tool" -c <"$1" ;;
	launch-sha) exec "$tool" <"$1" ;;
	launch-readonly)
		[ -f "$1" ] && [ ! -L "$1" ] || exit 2
		exec "$tool" 400 "$1"
		;;
	launch-remove)
		[ -f "$1" ] && [ ! -L "$1" ] || exit 2
		exec "$tool" "$1"
		;;
	launch-rmdir)
		# Native BusyBox -ef verifies the exact held Linux directory inode.
		# shellcheck disable=SC3013
		[ -d "$1" ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/4 ] || exit 2
		exec "$tool" "$1"
		;;
	esac
	;;
install-report-ls)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /usr/bin/logger | /usr/bin | /usr | /bin/busybox | /bin | /) ;; *) exit 2 ;; esac
	exec "$tool" -ldn "$1"
	;;
install-report)
	[ "$#" -eq 1 ] && [ "$1" = storage-lost ] || exit 2
	exec "$tool" -p user.err -t CFMGR '[CFMGR] Manager: Error: Entware storage lost; installation stopped'
	;;
launch-report)
	[ "$#" -eq 1 ] && [ "$1" = storage-unavailable ] || exit 2
	exec "$tool" -t CFMGR '[CFMGR] launch: error: Entware attachment unavailable; operation stopped'
	;;
repair-inventory)
	[ "$#" -eq 3 ] || exit 2
	exec "$tool" -f "$1" inventory-v1 "$2" /proc/self/mountinfo >"$3"
	;;
repair-awk)
	# shellcheck disable=SC2034 # Fixed imported library uses these explicit fields.
	[ "$#" -ge 5 ] && [ "$#" -le 13 ] || exit 2
	cfmgr_view_awk=cfmgr_probe_awk_exec cfmgr_view_context=$2 cfmgr_view_native_root=$3
	# Fixed controller-admitted RAM snapshot, never environment/source payload.
	# shellcheck disable=SC1090 # Caller-admitted private RAM library snapshot.
	. "$1" || exit 2
	cfmgr_probe_awk_exec() { exec "$tool" "$@"; }
	shift 3
	cfmgr_execution_view_awk "$@"
	;;
repair-identity)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -idn "$1"
	;;
repair-identity-parse)
	[ "$#" -eq 2 ] || exit 2
	# shellcheck disable=SC2016
	exec "$tool" '
		function bit(c,yes) { return index(yes,c)>0 }
		{ if (NR!=1 || NF<5 || length($2)!=10) exit 1
		  p=$2; special=0
		  if (bit(substr(p,4,1),"sS")) special+=4
		  if (bit(substr(p,7,1),"sS")) special+=2
		  if (bit(substr(p,10,1),"tT")) special+=1
		  mode=special ? special "" : ""
		  for (i=2;i<=8;i+=3) mode=mode (4*bit(substr(p,i,1),"r")+2*bit(substr(p,i+1,1),"w")+bit(substr(p,i+2,1),"xst"))
		  printf "%s\t%s\t%s\t%s\n",$1,mode,$4,$5 }
		END { if (NR!=1) exit 1 }
	' "$1" >"$2"
	;;
repair-readlink | repair-list)
	[ "$#" -eq 2 ] || exit 2
	if [ "$mode" = repair-list ]; then exec "$tool" -1A "$1" >"$2"; fi
	exec "$tool" "$1" >"$2"
	;;
repair-copy)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" "$1" "$2"
	;;
repair-mkdir)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" -m "$2" "$1"
	;;
repair-chmod)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" "$2" "$1"
	;;
repair-link)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" -s -- "$1" "$2"
	;;
repair-file)
	[ "$#" -eq 1 ] || exit 2
	umask 077
	set -C
	: >"$1"
	;;
repair-root | repair-guard-root)
	[ "$#" -eq 1 ] || exit 2
	if [ "$mode" = repair-root ]; then exec "$tool" -t tmpfs -o size=8m,mode=700 tmpfs "$1"; fi
	exec "$tool" -t tmpfs -o size=64k,mode=700 tmpfs "$1"
	;;
repair-bind4)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o bind /proc/self/fd/4 "$1"
	;;
repair-bind7)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o bind /proc/self/fd/7 "$1"
	;;
repair-private)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o make-private "$1"
	;;
repair-unbindable)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o make-unbindable "$1"
	;;
repair-seal)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" -o remount,ro "$1"
	;;
repair-unmount)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" "$1"
	;;
repair-fifo)
	[ "$#" -eq 1 ] || exit 2
	umask 077
	exec "$tool" "$1" p
	;;
repair-remove)
	[ "$#" -ge 1 ] && [ "$#" -le 64 ] || exit 2
	LC_ALL=C
	export LC_ALL
	remove_bytes=0
	for remove_path; do
		case $remove_path in /*) ;; *) exit 2 ;; esac
		remove_bytes=$((remove_bytes + ${#remove_path} + 1))
		[ "$remove_bytes" -le 8192 ] || exit 2
	done
	exec "$tool" "$@"
	;;
repair-retire)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	# shellcheck disable=SC3013 # Exact inherited Linux claim inode, not a new name.
	[ -d "$1" ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/5 ] || exit 2
	exec "$tool" "$1"
	;;
repair-rmdir)
	[ "$#" -eq 1 ] || exit 2
	exec "$tool" "$1"
	;;
repair-report)
	[ "$#" -eq 1 ] || exit 2
	case $1 in
	storage-lost) message='[CFMGR] dependencies: error: Entware attachment lost; cleanup pending' ;;
	cleanup-pending) message='[CFMGR] dependencies: error: dependency cleanup pending' ;;
	cleanup-complete) message='[CFMGR] dependencies: error: Entware operation stopped; owned mounts released' ;;
	*) exit 2 ;;
	esac
	exec "$tool" -t CFMGR "$message"
	;;
repair-signal)
	[ "$#" -eq 2 ] || exit 2
	case $1 in '' | 0* | *[!0-9]*) exit 2 ;; esac
	case $2 in TERM | KILL) ;; *) exit 2 ;; esac
	exec "$tool" -"$2" "$1"
	;;
native-curl-version)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -q -V
	;;
native-curl-offline | native-curl-https)
	case "$mode:$#" in native-curl-offline:2) set -- "$1" "$2" http://127.0.0.1:9/ ;; native-curl-https:3) ;; *) exit 2 ;; esac
	case "$1:$2" in /*:/*) ;; *) exit 2 ;; esac
	case "$2" in *:*) exit 2 ;; esac
	if [ "$mode" = native-curl-https ]; then case $3 in https://*) ;; *) exit 2 ;; esac fi
	# One policy shared by offline option admission and the real HTTPS primitive.
	# -q MUST be first: ignore every curlrc. No redirects, proxy, implicit trust,
	# or environment-configured OpenSSL/loader state survives env-i launch.
	exec "$tool" -q --silent --show-error --proto '=https' --proto-redir '=https' \
		--tlsv1.2 --cacert "$1" --capath "$2" --proxy '' --noproxy '*' \
		--connect-timeout 1 --max-time 1 --head --output /dev/null --write-out '%{http_code}\n' --url "$3"
	;;
native-ca-decode)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	exec "$tool" crl2pkcs7 -nocrl -certfile "$1" -out /dev/null
	;;
native-rmdir)
	[ "$#" -eq 1 ] || exit 2
	case $1 in "$context/native.directory") ;; *) exit 2 ;; esac
	exec "$tool" "$1"
	;;
native-curl-features)
	[ "$#" -eq 1 ] || exit 2
	case $1 in "$context"/*) ;; *) exit 2 ;; esac
	# shellcheck disable=SC2016
	exec "$tool" '
		NR==1 { if ($1!="curl" || $2 !~ /^[0-9]+[.][0-9]+[.][0-9]+/) bad=1 }
		length($0)>4096 || NR>32 { bad=1 }
		$1=="Protocols:" { protocols++; for (i=2;i<=NF;i++) if ($i=="https") https=1 }
		$1=="Features:" { features++; for (i=2;i<=NF;i++) if ($i=="SSL") ssl=1 }
		END { exit bad || protocols!=1 || features!=1 || !https || !ssl ? 1 : 0 }
	' "$1"
	;;
native-ca-pem)
	[ "$#" -eq 1 ] || exit 2
	case $1 in /*) ;; *) exit 2 ;; esac
	# Framing/count is separate: OpenSSL can decode a zero-certificate bundle.
	# shellcheck disable=SC2016
	exec "$tool" '
		length($0)>4096 || NR>32768 || $0 ~ /[^ -~]/ { bad=1; exit 1 }
		$0=="-----BEGIN CERTIFICATE-----" { if (inside || ++certs>1024) bad=1; inside=1; bytes=0; padded=0; next }
		$0=="-----END CERTIFICATE-----" { if (!inside || !bytes || bytes%4) bad=1; inside=0; next }
		inside { if (padded || length($0)<1 || length($0)>76 || $0 !~ /^[A-Za-z0-9+\/]+(=|==)?$/) bad=1
		  if (index($0,"=")) padded=1; bytes+=length($0); next }
		$0!~/^ *$/ && $0!~/^#/ { bad=1 }
		END { exit bad || inside || certs<1 ? 1 : 0 }
	' "$1"
	;;
install-config)
	[ "$#" -eq 7 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	# The trusted local package has been inventoried and hash-verified before
	# this finite import. The filename is fixed, never supplied as arbitrary code.
	# shellcheck disable=SC1091
	. "$1/modules/lib/config.sh" || exit 2
	shift
	cfmgr_config_defaults_exec "$tool" "$@"
	exit 2
	;;
install-copy | install-rename | install-publish)
	[ "$#" -eq 2 ] || exit 2
	case "$1:$2" in /*:/*) ;; *) exit 2 ;; esac
	case "$mode" in
	install-copy) exec "$tool" "$1" "$2" ;;
	install-rename) exec "$tool" -f "$1" "$2" ;;
	install-publish) exec "$tool" -n "$1" "$2" ;;
	esac
	;;
install-sha | install-wc | install-ls | install-config-check | install-mkdir-private | install-mkdir-public | install-chmod-private | install-chmod-readonly | install-chmod-executable | install-df | install-remove)
	[ "$#" -eq 1 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	case "$mode" in
	install-sha) exec "$tool" <"$1" ;;
	install-wc) exec "$tool" -c <"$1" ;;
	install-ls) exec "$tool" -ldn "$1" ;;
	install-remove)
		case $1 in */.setup.complete) ;; *) exit 2 ;; esac
		[ -f "$1" ] && [ ! -L "$1" ] || exit 1
		exec "$tool" "$1"
		;;
	install-config-check)
		# shellcheck disable=SC2016
		exec "$tool" -e '.schema == 1 and .generation == 1 and
			.manager.check_updates == true and .manager.auto_update == false and .manager.developer == false and
			.ddns.configured == false and .ddns.enabled == false and
			.ip_sync.configured == false and .ip_sync.enabled == false and
			.cloudflared.configured == false and .cloudflared.enabled == false and
			.cloudflared.installed == false and .cloudflared.maintenance_enabled == false and
			.logging.ddns.configured == false and .logging.ip_sync.configured == false and
			.logging.cloudflared.configured == false' "$1" >/dev/null
		;;
	install-mkdir-private) exec "$tool" -m 700 "$1" ;;
	install-mkdir-public) exec "$tool" -m 755 "$1" ;;
	install-chmod-private) exec "$tool" 600 "$1" ;;
	install-chmod-readonly) exec "$tool" 644 "$1" ;;
	install-chmod-executable) exec "$tool" 755 "$1" ;;
	install-df) exec "$tool" -Pk "$1" ;;
	esac
	;;
install-flush)
	[ "$#" -eq 0 ] || exit 2
	(: <&3) 2>/dev/null || exit 2
	exec "$tool" /proc/self/fd/3
	;;
install-nvram)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" get jffs2_scripts
	;;
jq-good)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -er '.answer[1] == 2 and .ok == true' json.good
	;;
jq-bad)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -e . json.bad
	;;
wc-jq)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -c <jq-good.out
	;;
wc-sha)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -c <sha-bytes.out
	;;
sha-bytes)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" bytes
	;;
sha-good)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" --check --status checksum.good
	;;
sha-bad)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" --check --status checksum.bad
	;;
timeout-exit)
	[ "$#" -eq 2 ] || exit 2
	exec "$tool" --foreground --kill-after=0.05s 0.5s "$1" "$2" exit-seven
	;;
timeout-expiry)
	[ "$#" -eq 3 ] || exit 2
	exec "$tool" --foreground --kill-after=0.05s 0.1s "$1" "$2" sleep-short "$3" "$context"
	;;
flock-first | flock-entware-first)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 4
	;;
flock-compete | flock-after | flock-entware-compete | flock-entware-after)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -n 5
	;;
flock-release | flock-entware-release)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -u 4
	;;
flock-finish | flock-entware-finish)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -u 5
	;;
dig-version)
	[ "$#" -eq 0 ] || exit 2
	exec "$tool" -v
	;;
blkid)
	[ "$#" -eq 1 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	[ -b "$1" ] || exit 2
	exec "$tool" "$1"
	;;
*) exit 2 ;;
esac
