#!/bin/sh
# Category owner: network. Sourcing defines functions only.

# ---- invocation-local WAN observations ----
# Fixed callback: nvram KEY | interfaces | routes | project RAW PURPOSE GEN
# ORIGIN STATE PRIMARY SELECTORS. The admitted caller owns every probe and its
# ordinary deadline; return 3 must retain that ownership. No background producer.
cfmgr_wan_step() {
	[ "$cfmgr_wan_calls" -lt "$((cfmgr_wan_limit - 1))" ] || {
		cfmgr_wan_cutoff=1
		return 1
	}
	if [ -n "${cfmgr_wan_deadline:-}" ]; then
		cfmgr_prerequisites_now && [ "$cfmgr_probe_now" -lt "$cfmgr_wan_deadline" ] || {
			cfmgr_wan_cutoff=1
			return 1
		}
	fi
	cfmgr_wan_calls=$((cfmgr_wan_calls + 1))
	cfmgr_wan_probe_output='' cfmgr_wan_probe_error='' cfmgr_wan_probe_exit=1
	if cfmgr_wan_action "$@"; then cfmgr_wan_code=0; else cfmgr_wan_code=$?; fi
	[ "$cfmgr_wan_code" != 3 ] || return 3
	cfmgr_wan_value='' cfmgr_wan_valid=0
	if [ "$cfmgr_wan_code" = 0 ] && [ "$cfmgr_wan_probe_exit" = 0 ] &&
		[ -f "$cfmgr_wan_probe_output" ] && [ ! -L "$cfmgr_wan_probe_output" ] &&
		[ -f "$cfmgr_wan_probe_error" ] && [ ! -s "$cfmgr_wan_probe_error" ]; then cfmgr_wan_valid=1; fi
	printf 'B %s %s %s\n' "$1" "${2:--}" "$cfmgr_wan_valid" >>"$cfmgr_wan_raw" || return 1
	cfmgr_wan_lines=0 cfmgr_wan_bytes=0
	if [ "$cfmgr_wan_valid" = 1 ]; then
		while IFS= read -r cfmgr_wan_line || [ -n "$cfmgr_wan_line" ]; do
			cfmgr_wan_lines=$((cfmgr_wan_lines + 1)) cfmgr_wan_bytes=$((cfmgr_wan_bytes + ${#cfmgr_wan_line} + 1))
			if [ "$cfmgr_wan_lines" -gt 512 ] || [ "$cfmgr_wan_bytes" -gt 65536 ] || [ "${#cfmgr_wan_line}" -gt 1024 ]; then
				cfmgr_wan_valid=0
				break
			fi
			if [ "$1" = nvram ]; then
				if [ "$cfmgr_wan_lines" -gt 1 ] || [ "${#cfmgr_wan_line}" -gt 128 ]; then
					cfmgr_wan_valid=0
					break
				fi
				cfmgr_wan_value=$cfmgr_wan_line
			fi
			printf 'D %s\n' "$cfmgr_wan_line" >>"$cfmgr_wan_raw" || return 1
		done <"$cfmgr_wan_probe_output"
	fi
	printf 'E %s\n' "$cfmgr_wan_valid" >>"$cfmgr_wan_raw" || return 1
	[ "$cfmgr_wan_valid" = 1 ] || cfmgr_wan_value=''
	return 0
}

cfmgr_wan_unit() {
	case " $cfmgr_wan_seen " in *" $1 "*) return 0 ;; esac
	[ "$cfmgr_wan_sources" -lt 16 ] || {
		cfmgr_wan_cutoff=1
		return 0
	}
	cfmgr_wan_seen="$cfmgr_wan_seen $1"
	if [ "$1" -lt 2 ]; then
		case $1 in 0) cfmgr_wan_type=${cfmgr_wan_dual%% *} ;; 1)
			cfmgr_wan_type=${cfmgr_wan_dual#* }
			[ "$cfmgr_wan_type" != "$cfmgr_wan_dual" ] || cfmgr_wan_type=''
			;;
		esac
		case $cfmgr_wan_type in wan | lan | usb | wan2 | sfp+) ;; *) return 0 ;; esac
	fi
	if [ "$1" -ge 50 ]; then
		cfmgr_wan_step nvram "wan${1}_type" || return $?
		case $cfmgr_wan_value in wan | lan | usb | wan2 | sfp+) ;; *) return 0 ;; esac
		cfmgr_wan_type=$cfmgr_wan_value
	fi
	cfmgr_wan_sources=$((cfmgr_wan_sources + 1))
	cfmgr_wan_step nvram "wan${1}_enable" || return $?
	cfmgr_wan_step nvram "wan${1}_proto" || return $?
	cfmgr_wan_protocol=$cfmgr_wan_value
	cfmgr_wan_step nvram "wan${1}_primary" || return $?
	case $cfmgr_wan_protocol in pppoe | pptp | l2tp) cfmgr_wan_field=pppoe_ifname ;; *) cfmgr_wan_field=ifname ;; esac
	if [ "$cfmgr_wan_type" = usb ] && [ "$cfmgr_wan_protocol" != dhcp ]; then cfmgr_wan_field=pppoe_ifname; fi
	cfmgr_wan_step nvram "wan${1}_$cfmgr_wan_field" || return $?
	for cfmgr_wan_field in ipaddr state_t sbstate_t auxstate_t; do
		cfmgr_wan_step nvram "wan${1}_$cfmgr_wan_field" || return $?
	done
}

# API selectors are bounded literal data, rechecked by the projection. Expansion
# below only produces bounded fixed nvram keys; literal manual names stay hex.
# shellcheck disable=SC2034 # Public collector outputs and fixed callback ABI.
# The dashboard bounds its own writes to16KiB. The aggregate needs a separate
# bounded soft quota, restored even when a callback returns unresolved ownership.
# shellcheck disable=SC3045 # Native ash supports soft file limits.
cfmgr_wan_collect() {
	cfmgr_wan_output='' cfmgr_wan_status=unknown
	cfmgr_wan_saved_limit=$(ulimit -S -f) || return 1
	ulimit -S -f 384 || return 1
	if cfmgr_wan_collect_body "$@"; then cfmgr_wan_result=0; else cfmgr_wan_result=$?; fi
	ulimit -S -f "$cfmgr_wan_saved_limit" || {
		[ "$cfmgr_wan_result" = 3 ] && return 3
		return 1
	}
	if [ "$cfmgr_wan_result" != 0 ]; then cfmgr_wan_output='' cfmgr_wan_status=unknown; fi
	return "$cfmgr_wan_result"
}

# The trusted projector validates field semantics. Independently check its whole
# bounded envelope before publishing a report path, including ordinary short or
# accidentally appended output. Reading uses builtins, not a second parser child.
cfmgr_wan_report_check() {
	cfmgr_wan_report_lines=0 cfmgr_wan_report_bytes=0 cfmgr_wan_report_sources=0 cfmgr_wan_report_interfaces=0 cfmgr_wan_report_end=0
	case $cfmgr_wan_reason in ok | incomplete | ambiguous | unsupported | no-source) ;; *) return 1 ;; esac
	while IFS= read -r cfmgr_wan_report_line; do
		[ "$cfmgr_wan_report_end" = 0 ] || return 1
		cfmgr_wan_report_lines=$((cfmgr_wan_report_lines + 1)) cfmgr_wan_report_bytes=$((cfmgr_wan_report_bytes + ${#cfmgr_wan_report_line} + 1))
		[ "$cfmgr_wan_report_bytes" -le 16384 ] && [ "$cfmgr_wan_report_lines" -le 83 ] && [ "${#cfmgr_wan_report_line}" -le 256 ] || return 1
		case $cfmgr_wan_report_line in *[!\ -~]*) return 1 ;; esac
		case $cfmgr_wan_report_lines in
		1) [ "$cfmgr_wan_report_line" = "CFMGR-WAN 1 $cfmgr_wan_generation $cfmgr_wan_status $cfmgr_wan_reason" ] || return 1 ;;
		2) case $cfmgr_wan_report_line in 'PRIMARY '*) ;; *) return 1 ;; esac ;;
		*)
			case $cfmgr_wan_report_line in
			END) cfmgr_wan_report_end=1 ;;
			'SOURCE '*)
				cfmgr_wan_report_sources=$((cfmgr_wan_report_sources + 1))
				[ "$cfmgr_wan_report_sources" -le 16 ] && [ "$cfmgr_wan_report_interfaces" = 0 ] || return 1
				;;
			'INTERFACE '*)
				cfmgr_wan_report_interfaces=$((cfmgr_wan_report_interfaces + 1))
				[ "$cfmgr_wan_report_interfaces" -le 64 ] || return 1
				;;
			*) return 1 ;;
			esac
			;;
		esac
	done <"$cfmgr_wan_probe_output"
	[ -z "$cfmgr_wan_report_line" ] && [ "$cfmgr_wan_report_end" = 1 ]
}

cfmgr_wan_selectors() {
	cfmgr_wan_selector_ids='' cfmgr_wan_selector_names='' cfmgr_wan_selector_count=0
	cfmgr_wan_selector_rest=$2
	[ "$2" != - ] || cfmgr_wan_selector_rest=''
	while [ -n "$cfmgr_wan_selector_rest" ]; do
		cfmgr_wan_selector_token=${cfmgr_wan_selector_rest%%,*}
		case $cfmgr_wan_selector_rest in *,*)
			cfmgr_wan_selector_rest=${cfmgr_wan_selector_rest#*,}
			[ -n "$cfmgr_wan_selector_rest" ] || return 2
			;;
		*) cfmgr_wan_selector_rest='' ;; esac
		cfmgr_wan_selector_id=${cfmgr_wan_selector_token%%=*}
		cfmgr_wan_selector_number=${cfmgr_wan_selector_id#*:}
		case $cfmgr_wan_selector_number in '' | *[!0-9]* | 0[0-9]*) return 2 ;; esac
		[ "${#cfmgr_wan_selector_number}" -le 3 ] || return 2
		case $cfmgr_wan_selector_token in
		wan:*) [ "$cfmgr_wan_selector_token" = "$cfmgr_wan_selector_id" ] && [ "$cfmgr_wan_selector_number" -le 255 ] || return 2 ;;
		manual:*=*)
			[ "$cfmgr_wan_selector_number" -ge 1 ] && [ "$cfmgr_wan_selector_number" -le 32 ] || return 2
			cfmgr_wan_selector_hex=${cfmgr_wan_selector_token#*=}
			case $cfmgr_wan_selector_hex in '' | *[!0-9a-f]* | 2e | 2e2e) return 2 ;; esac
			[ "${#cfmgr_wan_selector_hex}" -le 30 ] && [ "$((${#cfmgr_wan_selector_hex} % 2))" = 0 ] || return 2
			case " $cfmgr_wan_selector_names " in *" $cfmgr_wan_selector_hex "*) return 2 ;; esac
			cfmgr_wan_selector_names="$cfmgr_wan_selector_names $cfmgr_wan_selector_hex"
			while [ -n "$cfmgr_wan_selector_hex" ]; do
				cfmgr_wan_selector_tail=${cfmgr_wan_selector_hex#??}
				case ${cfmgr_wan_selector_hex%"$cfmgr_wan_selector_tail"} in 2[1-9a-e] | 3[0-9b-f] | [4-6][0-9a-f] | 7[0-9a-e]) ;; *) return 2 ;; esac
				cfmgr_wan_selector_hex=$cfmgr_wan_selector_tail
			done
			;;
		*) return 2 ;;
		esac
		case " $cfmgr_wan_selector_ids " in *" $cfmgr_wan_selector_id "*) return 2 ;; esac
		cfmgr_wan_selector_ids="$cfmgr_wan_selector_ids $cfmgr_wan_selector_id"
		cfmgr_wan_selector_count=$((cfmgr_wan_selector_count + 1))
		[ "$cfmgr_wan_selector_count" -le 16 ] || return 2
	done
	[ "$2" = - ] || [ "$cfmgr_wan_selector_count" -gt 0 ] || return 2
	case $1 in -) ;; *) case " $cfmgr_wan_selector_ids " in *" $1 "*) ;; *) return 2 ;; esac ;; esac
}

cfmgr_wan_collect_body() {
	[ "$#" -eq 6 ] || return 2
	case $1 in inventory) cfmgr_wan_limit=48 ;; selected) cfmgr_wan_limit=40 ;; *) return 2 ;; esac
	case $2 in '' | *[!0-9]* | 0[0-9]*) return 2 ;; esac
	[ "${#2}" -le 20 ] && [ "${#5}" -le 16 ] && [ "${#6}" -le 1024 ] || return 2
	case $3 in absent | legacy | inventory | unresolved) ;; *) return 2 ;; esac
	case $4 in unconfirmed | retained | confirmed | deferred | unknown) ;; *) return 2 ;; esac
	cfmgr_wan_selectors "$5" "$6" || return 2
	case $cfmgr_wan_context in /*) ;; *) return 2 ;; esac
	[ -d "$cfmgr_wan_context" ] && [ ! -L "$cfmgr_wan_context" ] || return 2
	cfmgr_wan_current='' cfmgr_wan_dual=''
	cfmgr_wan_output='' cfmgr_wan_status=unknown cfmgr_wan_calls=0 cfmgr_wan_cutoff=0 cfmgr_wan_seen='' cfmgr_wan_sources=0
	cfmgr_wan_raw=$cfmgr_wan_context/wan.raw
	[ ! -e "$cfmgr_wan_raw" ] && [ ! -L "$cfmgr_wan_raw" ] || return 2
	(
		umask 077
		set -C
		: >"$cfmgr_wan_raw"
	) || return 1
	for cfmgr_wan_key in sw_mode wans_dualwan wans_mode wan_primary lan_ifname lan_ipaddr lan_netmask; do
		cfmgr_wan_step nvram "$cfmgr_wan_key" || {
			[ "$cfmgr_wan_code" != 3 ] || return 3
			break
		}
		case $cfmgr_wan_key in wan_primary) cfmgr_wan_current=$cfmgr_wan_value ;; wans_dualwan) cfmgr_wan_dual=$cfmgr_wan_value ;; esac
	done
	cfmgr_wan_step interfaces || { [ "$cfmgr_wan_code" != 3 ] || return 3; }
	cfmgr_wan_step routes || { [ "$cfmgr_wan_code" != 3 ] || return 3; }
	# Primary is first; saved remaining selectors precede discovery.
	cfmgr_wan_rest=$5
	[ "$1" != inventory ] || cfmgr_wan_rest="$5,$6"
	while [ -n "$cfmgr_wan_rest" ]; do
		cfmgr_wan_token=${cfmgr_wan_rest%%,*}
		case $cfmgr_wan_rest in *,*) cfmgr_wan_rest=${cfmgr_wan_rest#*,} ;; *) cfmgr_wan_rest='' ;; esac
		case $cfmgr_wan_token in
		wan:*)
			cfmgr_wan_number=${cfmgr_wan_token#wan:}
			case $cfmgr_wan_number in '' | *[!0-9]* | 0[0-9]*) return 2 ;; esac
			[ "${#cfmgr_wan_number}" -le 3 ] && [ "$cfmgr_wan_number" -le 255 ] || return 2
			if [ "$cfmgr_wan_number" -le 1 ] || [ "$cfmgr_wan_number" -ge 50 ]; then
				cfmgr_wan_unit "$cfmgr_wan_number" || { [ "$cfmgr_wan_code" != 3 ] || return 3; }
			fi
			;;
		esac
	done
	if [ "$1" = inventory ]; then
		for cfmgr_wan_number in 0 1 50 51 52 53 54 55 56 57; do
			cfmgr_wan_unit "$cfmgr_wan_number" || { [ "$cfmgr_wan_code" != 3 ] || return 3; }
		done
	else
		# Ordinary peer is the only bounded alternative in selected mode. Modern
		# failover is considered only when current firmware names its exact unit.
		case $cfmgr_wan_current in 0 | 1) cfmgr_wan_alternative=$cfmgr_wan_current ;; *) cfmgr_wan_alternative='' ;; esac
		case $cfmgr_wan_current in [5-9][0-9] | 1[0-9][0-9] | 2[0-4][0-9] | 25[0-5]) cfmgr_wan_alternative=$cfmgr_wan_current ;; esac
		if [ -n "$cfmgr_wan_alternative" ]; then cfmgr_wan_unit "$cfmgr_wan_alternative" || { [ "$cfmgr_wan_code" != 3 ] || return 3; }; fi
		case $5 in wan:0) cfmgr_wan_alternative=1 ;; wan:1) cfmgr_wan_alternative=0 ;; *) cfmgr_wan_alternative='' ;; esac
		if [ -n "$cfmgr_wan_alternative" ]; then cfmgr_wan_unit "$cfmgr_wan_alternative" || { [ "$cfmgr_wan_code" != 3 ] || return 3; }; fi
	fi
	printf 'LIMIT %s\n' "$cfmgr_wan_cutoff" >>"$cfmgr_wan_raw" || return 1
	# Never restart or extend the caller's collection clock for final projection.
	if [ -n "${cfmgr_wan_deadline:-}" ]; then cfmgr_prerequisites_now && [ "$cfmgr_probe_now" -le "$cfmgr_wan_deadline" ] || return 1; fi
	cfmgr_wan_calls=$((cfmgr_wan_calls + 1))
	cfmgr_wan_action project "$cfmgr_wan_raw" "$@" || return $?
	[ "$cfmgr_wan_probe_exit" = 0 ] && [ -f "$cfmgr_wan_probe_output" ] && [ ! -L "$cfmgr_wan_probe_output" ] && [ ! -s "$cfmgr_wan_probe_error" ] || return 1
	IFS=' ' read -r cfmgr_wan_magic cfmgr_wan_version cfmgr_wan_generation cfmgr_wan_status cfmgr_wan_reason <"$cfmgr_wan_probe_output" || return 1
	[ "$cfmgr_wan_magic:$cfmgr_wan_version:$cfmgr_wan_generation" = "CFMGR-WAN:1:$2" ] || return 1
	case $cfmgr_wan_status in complete | partial | unknown) ;; *) return 1 ;; esac
	cfmgr_wan_report_check || return 1
	cfmgr_wan_output=$cfmgr_wan_probe_output
}

cfmgr_network_awk_wan() {
	# CFMGR-AWK-BEGIN wan
	cfmgr_awk_program='
function dec(s,max) { return s~/^(0|[1-9][0-9]*)$/ && length(s)<=3 && s+0<=max }
function validname(s) { return length(s)>0 && length(s)<=15 && s!~/[^!-~]|[\/:]/ && s!="." && s!=".." }
function hex(s, r,i) { r=""; for(i=1;i<=length(s);i++) r=r sprintf("%02x",ord[substr(s,i,1)]); return r==""?"-":r }
function unhex(s, r,i,n,c) {
 if(length(s)%2 || length(s)>30 || s~/[^0-9a-f]/) return ""
 r="";for(i=1;i<=length(s);i+=2) { n=index(digits,substr(s,i,1))-1; c=16*n+index(digits,substr(s,i+1,1))-1; r=r sprintf("%c",c) } return validname(r)?r:""
}
function ip(s, a,i,n) {
 if(split(s,a,".")!=4)return -1;n=0
 for(i=1;i<=4;i++){if(a[i]!~/^(0|[1-9][0-9]*)$/ || a[i]>255)return -1;n=n*256+a[i]}return n
}
function mask(s, n,p) {n=ip(s);if(n<0)return -1;p=4294967296-n;while(p>1 && p%2==0)p/=2;return p==1?n:-1}
function class(s, n,a) {
 n=ip(s);if(n<0 || n==0)return "unknown";split(s,a,".")
 if(a[1]==10 || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && a[2]==168))return "private"
 if(a[1]==100 && a[2]>=64 && a[2]<=127)return "shared"
 if(a[1]==169 && a[2]==254)return "linklocal"
 if(s=="192.0.0.9" || s=="192.0.0.10")return "public"
 if(a[1]==0 || a[1]==127 || a[1]>=224 || (a[1]==192 && (a[2]==0 && (a[3]==0 || a[3]==2) || a[2]==88 && a[3]==99)) || (a[1]==198 && (a[2]==18 || a[2]==19 || a[2]==51 && a[3]==100)) || (a[1]==203 && a[2]==0 && a[3]==113))return "nonpublic"
 return "public"
}
function lan(s, n,m,l,b) { n=ip(s);m=mask(nv["lan_netmask"]);l=ip(nv["lan_ipaddr"]);if(n<0 || m<0 || l<0)return "unknown";b=4294967296-m;return int(n/b)==int(l/b)?"yes":"no" }
function add(id,unit,name) {
 if(id in seen)return; if(ns>=16){partial=1;return};seen[id]=++ns;ids[ns]=id;units[id]=unit;names[id]=name
}
function unitid(s, u) {if(s!~/^wan:/)return 0;u=substr(s,5);return dec(u,255)}
function parseif(line, a,n,i,t,name) {
 if(line!~/^[ \t]/ && line!="") {
  split(line,a,/[ \t]+/);name=a[1];sub(/:$/,"",name)
  if(line!~/Link encap:|flags=/ || !validname(name) || name in ifseen || ni>=64){ifbad=1;cur="";return}
  cur=name;ifseen[name]=++ni;ifs[ni]=name;up[name]="down";addr[name]="-";netmask[name]="-"
 }
 if(line~/[^ -~\t]/){ifbad=1;return}
 if(cur=="")return
 if(line~/(^|[ <,])UP([ >,]|$)/)up[cur]="up"
 n=split(line,a,/[ \t]+/)
 for(i=1;i<=n;i++) {
  if(a[i]~/^addr:/ && ip(substr(a[i],6))>=0)addr[cur]=substr(a[i],6)
  else if(a[i]=="inet" && i<n && ip(a[i+1])>=0)addr[cur]=a[i+1]
  else if(a[i]~/^Mask:/ && mask(substr(a[i],6))>=0)netmask[cur]=substr(a[i],6)
  else if(a[i]=="netmask" && i<n && mask(a[i+1])>=0)netmask[cur]=a[i+1]
 }
}
function parseroute(line, a,n,name) {
 if(line~/^Destination[ \t]/){routeheader=1;return}
 if(line=="" || line~/^Kernel IP routing table/)return
 if(line~/[^ -~\t]/){routebad=1;return}
 n=split(line,a,/[ \t]+/)
 if(n!=8 || ip(a[1])<0 || ip(a[2])<0 || mask(a[3])<0 || !validname(a[8]) || a[4]!~/^[A-Z!]+$/){routebad=1;return}
 if(++nr>256){routebad=1;return}
 if(a[1]=="0.0.0.0" && a[3]=="0.0.0.0" && a[4]~/U/ && a[4]!~/!/) {routes[a[8]]++;defaults++;if(routes[a[8]]>1)routebad=1}
}
function finish( i,j,k,n,a,id,u,p,name,configured,connected,mapping,route,localip,m,flag,active,conflict,eff,pm,reason,status,typ) {
 if(api_bad)exit 2
 if(bad || block!="" || !limitseen)exit 1
 if(nv["sw_mode"]!="1")unsupported=1
 n=split(nv["wans_dualwan"],dual,/[ \t]+/)
 for(i=1;i<=n;i++)if(dual[i]!~/^(wan|lan|usb|wan2|sfp\+|none)$/)unsupported=1
 if(n>2 || n<1 || dual[1]=="")unsupported=1
 # Retained IDs are always represented, including offline/unsupported choices.
 if(selectors!="-") {
  n=split(selectors,a,",");if(n>16)exit 2
  for(i=1;i<=n;i++) {
   id=a[i];name="";u="-"
   if(unitid(id))u=substr(id,5)
   else {j=index(id,"=");if(!j)exit 2;name=unhex(substr(id,j+1));id=substr(id,1,j-1);if(id!~/^manual:/ || !dec(substr(id,8),32) || substr(id,8)+0<1 || name=="")exit 2}
   if(id in retained || name!="" && name in manualseen)exit 2
   retained[id]=1;if(name!="")manualseen[name]=1;if(purpose=="inventory" || id==primary)add(id,u,name)
  }
 }
 if(primary!="-" && !(primary in retained))exit 2
 if(purpose=="inventory") {
  for(u=0;u<=255;u++) {
   k="wan" u "_";typ=nv[k "type"]
   if(u<2 && dual[u+1]!="" && dual[u+1]!="none" || u>=50 && typ~/^(wan|lan|usb|wan2|sfp\+)$/)add("wan:" u,u,"")
  }
 } else {
  # Only an actually observed candidate may be introduced for failover.
  for(u=0;u<=255;u++)if(nv["wan" u "_primary"]=="1" && (u<2 || u>=50))add("wan:" u,u,"")
 }
 if(!ni)ifbad=1;if(!routeheader)routebad=1
 for(i=1;i<=ni;i++)if(addr[ifs[i]]!="-" && mask(netmask[ifs[i]])<0)ifbad=1
 if(!ifok || !routeok || ifbad || routebad)partial=1
 for(i=1;i<=ns;i++) {
  id=ids[i];u=units[id];name=names[id];p="-";configured="unknown";connected="unknown";mapping="unresolved"
  if(u!="-") {
   k="wan" u "_";p=nv[k "proto"];if(p=="")p="-"
   typ=u<2?dual[u+1]:nv[k "type"]
   if(u>=2 && u<50 || typ!~/^(wan|lan|usb|wan2|sfp\+)$/ || p!~/^(dhcp|static|pppoe|pptp|l2tp)$/)mapping="unsupported"
   else if(nv[k "enable"]=="0") {configured="no";mapping="offline";connected="no"}
   else if(nv[k "enable"]=="1")configured="yes"
   name=nv[k (typ=="usb" && p!="dhcp" || p~/^(pppoe|pptp|l2tp)$/?"pppoe_ifname":"ifname")]
   if(!validname(name))name=""
  } else configured="yes"
  if(p!="-" && p!~/^(dhcp|static|pppoe|pptp|l2tp)$/)p="-"
  route=routeok && !routebad?(routes[name]?"yes":"no"):"unknown"
  localip=ifok && !ifbad && name in ifseen?addr[name]:"-";m=ifok && !ifbad && name in ifseen?netmask[name]:"-"
  if(mapping!="unsupported" && configured!="no") {
   if(ifok && !ifbad && name in ifseen) {
    if(up[name]=="down") {mapping="offline";connected="no"}
    else if(u!="-" && configured=="yes" && route=="yes" && ip(localip)>0 && m!="-" && nv[k "ipaddr"]==localip && nv[k "state_t"]=="2" && nv[k "sbstate_t"]=="0" && nv[k "auxstate_t"]=="0") {mapping="coherent";connected="yes"}
   } else if(ifok && !ifbad && name!="") {mapping="offline";connected="no"}
  }
  if(unsupported) {mapping="unsupported";connected="unknown"}
  names[id]=name;maps[id]=mapping;con[id]=connected
  rows[id]="SOURCE " id " " u " " hex(name) " " p " " configured " " connected " " mapping " " route " " localip " " m " " class(localip) " " lan(localip)
  if(u!="-" && nv["wan" u "_primary"]=="1"){flag++;active=id}
 }
 # Manual sources may precede firmware sources; correlate in a second pass.
 for(i=1;i<=ns;i++)if(units[ids[i]]=="-" && maps[ids[i]]=="unresolved")for(j=1;j<=ns;j++)if(units[ids[j]]!="-" && names[ids[i]]!="" && names[ids[i]]==names[ids[j]] && maps[ids[j]]=="coherent") {
  id=ids[i];maps[id]="coherent";con[id]="yes";sub(/ yes unknown unresolved /," yes yes coherent ",rows[id])
 }
 for(i=1;i<=ns;i++)if(maps[ids[i]]=="unresolved")partial=1
 conflict=flag>1 || flag==1 && nv["wan_primary"]!="" && nv["wan_primary"]!=units[active] || routeok && defaults>1 || nv["wans_mode"]=="lb"
 if(primary!="-" && maps[primary]=="coherent" && flag==1 && names[primary]!=names[active])conflict=1
 if(primary!="-" && maps[primary]=="coherent" && units[primary]!="-" && nv["wan_primary"]!="" && nv["wan_primary"]!=units[primary])conflict=1
 eff="-";pm="unresolved"
 if(primary!="-") {pm=maps[primary];if(pm=="coherent")eff=primary}
 else if(flag==1 && maps[active]=="coherent" && nv["wan_primary"]==units[active]) {eff=active;pm="coherent"}
 # wans_mode proves classic dual-WAN policy only. A manual preference or an
 # unproved modern relationship cannot acquire replacement authority from it.
 if(eff=="-" && units[primary]~/^[01]$/ && units[active]~/^[01]$/ && maps[primary]!="unsupported" && flag==1 && maps[active]=="coherent" && nv["wan_primary"]==units[active] && nv["wans_mode"]~/^(fo|fb)$/) {eff=active;pm="coherent"}
 if(conflict) {eff="-";pm="conflict"}
 if(unsupported){eff="-";pm="unsupported"}
 if(pm=="unsupported")unsupported=1
 reason=unsupported?"unsupported":conflict?"ambiguous":ns==0?"no-source":partial?"incomplete":"ok"
 status=unsupported || conflict || ns==0?"unknown":partial?"partial":"complete"
 if(origin=="unresolved" || state=="unknown") {eff="-";pm="unresolved";status="unknown";reason="incomplete"}
 print "CFMGR-WAN 1 " generation " " status " " reason
 print "PRIMARY " primary " " eff " " pm " " (eff=="-"?"-":hex(names[eff]))
 for(i=1;i<=ns;i++)print rows[ids[i]]
 for(i=1;i<=ni;i++) {name=ifs[i];print "INTERFACE " hex(name) " " (ifok && !ifbad?up[name]:"unknown") " " (ifok && !ifbad?addr[name]:"-") " " (ifok && !ifbad?netmask[name]:"-") " " (ifok && !ifbad?class(addr[name]):"unknown") " " (ifok && !ifbad?lan(addr[name]):"unknown")}
 print "END"
}
BEGIN {
 if(ENVIRON["CFMGR_WAN_PURPOSE"]!="") {purpose=ENVIRON["CFMGR_WAN_PURPOSE"];generation=ENVIRON["CFMGR_WAN_GENERATION"];origin=ENVIRON["CFMGR_WAN_ORIGIN"];state=ENVIRON["CFMGR_WAN_STATE"];primary=ENVIRON["CFMGR_WAN_PRIMARY"];selectors=ENVIRON["CFMGR_WAN_SELECTORS"]}
 digits="0123456789abcdef";for(i=32;i<=126;i++)ord[sprintf("%c",i)]=i
 if(purpose!~/^(inventory|selected)$/ || generation!~/^(0|[1-9][0-9]*)$/ || length(generation)>20 || origin!~/^(absent|legacy|inventory|unresolved)$/ || state!~/^(unconfirmed|retained|confirmed|deferred|unknown)$/ || length(selectors)>1024){api_bad=1;exit 2}
}
{bytes+=length($0)+1;if(bytes>196608 || length($0)>1030){bad=1;exit 1}}
$1=="B" {
 if(limitseen || block!="" || NF!=4 || $2!~/^(nvram|interfaces|routes)$/ || $4!~/^[01]$/){bad=1;exit 1}
 block=$2;key=$3;good=$4;count=0;value=""
 if(block!="nvram" && observed[block]++){bad=1;exit 1}
 if(block=="nvram" && (key!~/^(sw_mode|wans_dualwan|wans_mode|wan_primary|lan_ifname|lan_ipaddr|lan_netmask|wan[0-9]+_(type|enable|proto|primary|ifname|pppoe_ifname|ipaddr|state_t|sbstate_t|auxstate_t))$/ || key in got)){bad=1;exit 1}
 if(block=="nvram")got[key]=1
 next
}
substr($0,1,2)=="D " {
 if(block=="" || ++count>512){bad=1;exit 1};line=substr($0,3)
 if(block=="nvram") {if(count>1 || length(line)>128 || line~/[^ -~]/){good=0}else value=line}
 else if(block=="interfaces")parseif(line)
 else parseroute(line)
 next
}
$1=="E" {
 if(block=="" || NF!=2 || $2!~/^[01]$/){bad=1;exit 1}
 good=good && $2==1
 if(block=="nvram") {if(good)nv[key]=value;else partial=1}
 else if(block=="interfaces")ifok=good
 else routeok=good
 block="";next
}
$1=="LIMIT" && NF==2 && $2~/^[01]$/ && block=="" && !limitseen {limitseen=1;if($2==1)partial=1;next}
{bad=1;exit 1}
END {finish()}
'
	# CFMGR-AWK-END wan
}

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

# Full-health read-only admission. The caller admits the native executables and
# protected native CA before setting this flag; no installation checks are used.
# This controller runs only in the private health subshell and owns its callback.
cfmgr_health_tls_check() {
	cfmgr_health_transport=unavailable
	[ "${cfmgr_health_active:-0}" = 1 ] && [ "${cfmgr_health_native_admitted:-0}" = 1 ] || return 2
	cfmgr_native_action() { cfmgr_health_native_action "$@"; }
	if cfmgr_native_acquire_check "$cfmgr_status_context" "$cfmgr_health_curl" "$cfmgr_health_openssl" "$cfmgr_health_ca"; then
		cfmgr_health_transport=ready
		return 0
	else
		cfmgr_health_tls_code=$?
		[ "$cfmgr_health_tls_code" != 3 ] || return 3
		cfmgr_health_reason=transport-prerequisite
		return "$cfmgr_health_tls_code"
	fi
}

cfmgr_health_native_action() {
	case $1 in
	install-wc) cfmgr_health_run health-count /usr/bin/wc "$2" ;;
	native-curl-version) cfmgr_health_run health-curl-version "$cfmgr_health_curl" ;;
	native-curl-features) cfmgr_health_run health-curl-features /usr/bin/awk "$2" ;;
	native-ca-pem) cfmgr_health_run health-ca-pem /usr/bin/awk "$2" ;;
	native-ca-decode) cfmgr_health_run health-ca-decode "$cfmgr_health_openssl" "$2" ;;
	native-curl-offline) cfmgr_health_run health-curl-offline "$cfmgr_health_curl" "$2" "$3" ;;
	*) return 2 ;;
	esac || return $?
	cfmgr_native_output=$cfmgr_probe_stdout cfmgr_native_error=$cfmgr_probe_stderr cfmgr_native_exit=$cfmgr_probe_exit
}
