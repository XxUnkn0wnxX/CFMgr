#!/bin/sh
# Category owner: status. Sourcing defines functions only.

# ---- status ----
# Source-inert, local-only status consumer. No operational preparation/repair.
# Imports are fixed installed paths admitted by the trusted entry; no data sourcing.
# A private report context holds bounded native snapshots and a config projection.
# Status runs in a subshell so menu descriptors, traps and launch state survive.
# shellcheck disable=SC2034,SC2154,SC3013
cfmgr_status_attachment_ok() {
	[ "${cfmgr_status_interrupted:-0}" = 0 ] && [ ! -L "$cfmgr_status_context" ] &&
		[ "$cfmgr_status_context" -ef /proc/self/fd/9 ]
}

cfmgr_status_run() {
	cfmgr_status_mode=$1 cfmgr_status_tool=$2
	shift 2
	cfmgr_prerequisites_now || return 2
	if [ "$cfmgr_probe_now" -ge "$cfmgr_status_deadline" ]; then
		cfmgr_status_budget_exhausted=1
		return 1
	fi
	cfmgr_prerequisites_run "$cfmgr_status_mode" "$cfmgr_status_context" /bin/sh \
		"$cfmgr_source/modules/helpers/worker.sh" /usr/bin/env /usr/bin/awk /bin/sleep /usr/bin/wc "$cfmgr_status_tool" "$@" || return $?
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_status_cleanup() {
	cfmgr_status_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "$cfmgr_probe_status" = reaped ] || return 1
	cfmgr_status_count=0
	for cfmgr_status_file in "$cfmgr_status_context"/*; do
		[ -e "$cfmgr_status_file" ] || continue
		[ -f "$cfmgr_status_file" ] && [ ! -L "$cfmgr_status_file" ] || return 1
		cfmgr_status_count=$((cfmgr_status_count + 1))
		[ "$cfmgr_status_count" -le 96 ] || return 1
	done
	for cfmgr_status_file in "$cfmgr_status_context"/*; do
		[ -f "$cfmgr_status_file" ] || continue
		/bin/rm -f "$cfmgr_status_file" || return 1
	done
	/bin/rmdir "$cfmgr_status_context" || return 1
	exec 9<&-
}

cfmgr_status_prepare() {
	# Root-owned RAM and fixed native tools only; Entware is never executed.
	[ -d /tmp ] && [ ! -L /tmp ] && [ "$(/usr/bin/readlink -f /tmp)" = /tmp ] || return 1
	cfmgr_status_mount=$(cfmgr_storage_mountinfo /usr/bin/awk /tmp /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_status_id cfmgr_status_parent cfmgr_status_device cfmgr_status_root cfmgr_status_point cfmgr_status_type cfmgr_status_rest << EOF_MOUNT
$cfmgr_status_mount
EOF_MOUNT
	case $cfmgr_status_type in tmpfs | ramfs | rootfs) ;; *) return 1 ;; esac
	cfmgr_prerequisites_identity "$$" || return 1
	cfmgr_status_context=/tmp/cfmgr-status.$$.$cfmgr_identity_start
	umask 077
	/bin/mkdir -m 700 "$cfmgr_status_context" || return 1
	exec 9< "$cfmgr_status_context" || return 1
	cfmgr_status_interrupted=0 cfmgr_probe_pid='' cfmgr_status_budget_exhausted=0
	cfmgr_prerequisites_now || return 1
	cfmgr_status_deadline=$((cfmgr_probe_now + 10))
	trap 'cfmgr_status_interrupted=1' HUP INT TERM
}

cfmgr_status_native() (
	for cfmgr_status_path in "$cfmgr_source/modules/helpers/worker.sh" "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_source/modules/lib/storage.sh"; do
		if [ ! -f "$cfmgr_status_path" ] || [ -L "$cfmgr_status_path" ] ||
			! /usr/bin/awk 'NR!=1 || $3!=0 || $1!~/^-/ || substr($1,6,1)=="w" || substr($1,9,1)=="w" { bad=1 } END { exit NR!=1 || bad }' << EOF_STATUS_METADATA; then
$(/bin/ls -ldn "$cfmgr_status_path")
EOF_STATUS_METADATA
			printf '[CFMGR] status: warning: required native reporting module unavailable\n'
			exit 1
		fi
	done
	cfmgr_status_prepare || {
		printf '[CFMGR] status: warning: native report context unavailable\n'
		exit 1
	}
	if cfmgr_status_work; then cfmgr_status_code=0; else cfmgr_status_code=$?; fi
	if [ "$cfmgr_status_code" = 3 ]; then
		printf '[CFMGR] status: error: owned probe unresolved; report cleanup required\n'
		exit 3
	fi
	# A signal prevents further collection but reaped children permit cleanup.
	cfmgr_status_interrupted=0
	cfmgr_status_cleanup || {
		printf '[CFMGR] status: warning: report cleanup required\n'
		exit 1
	}
	exit "$cfmgr_status_code"
)

cfmgr_status_work() {
	printf '\nCFMgr %s - local status\n' "$CFMGR_VERSION"
	# Each independent failure retains the remaining native/local report.
	cfmgr_status_now=0 cfmgr_status_boot=unknown cfmgr_status_wan=auto cfmgr_status_clock=0
	if cfmgr_status_run status-date /bin/date; then
		IFS= read -r cfmgr_status_now < "$cfmgr_probe_stdout"
		case $cfmgr_status_now in '' | *[!0-9]* | 0*) cfmgr_status_now=0 ;; esac
	elif [ "$?" = 3 ]; then return 3; fi
	if cfmgr_status_run status-native /usr/bin/awk "$cfmgr_source/modules/status.sh" /proc; then
		cfmgr_status_native_output=$cfmgr_probe_stdout
		# Typed receipts contain only allowlisted native resource fields.
		while IFS='	' read -r cfmgr_status_key cfmgr_status_value; do
			case $cfmgr_status_key in
				boot) cfmgr_status_boot=$cfmgr_status_value ;;
				uptime | load | memory) printf '%s: %s\n' "$cfmgr_status_key" "$cfmgr_status_value" ;;
			esac
		done < "$cfmgr_status_native_output"
	else
		[ "$?" != 3 ] || return 3
		printf 'Resources: Unavailable\n'
	fi
	cfmgr_status_config=unavailable
	if cfmgr_status_snapshot "$cfmgr_source/config"; then
		cfmgr_status_config=$cfmgr_status_snapshot_file
		cfmgr_status_config_bytes=$cfmgr_status_snapshot_bytes
		if cfmgr_status_project select; then
			IFS= read -r cfmgr_status_wan < "$cfmgr_probe_stdout"
		else
			[ "$?" != 3 ] || return 3
			cfmgr_status_config=unavailable
		fi
	else
		[ "$?" != 3 ] || return 3
	fi
	# Narrow, fixed nvram get operands; no raw dump and no fallback WAN guess.
	for cfmgr_status_key in productid firmver buildno extendno ntp_ready; do
		cfmgr_status_nvram "$cfmgr_status_key" || return $?
	done
	if [ "$cfmgr_status_wan" = auto ]; then
		cfmgr_status_nvram wan0_primary || return $?
		cfmgr_status_primary0=$cfmgr_status_value
		cfmgr_status_nvram wan1_primary || return $?
		case $cfmgr_status_primary0:$cfmgr_status_value in 1:0) cfmgr_status_wan=0 ;; 0:1) cfmgr_status_wan=1 ;; *) cfmgr_status_wan=unknown ;; esac
	fi
	printf 'Selected WAN: %s\n' "$cfmgr_status_wan"
	case $cfmgr_status_wan in 0 | 1)
		cfmgr_status_nvram "wan${cfmgr_status_wan}_proto" || return $?
		case $cfmgr_status_value in
			dhcp | static) cfmgr_status_nvram "wan${cfmgr_status_wan}_ifname" || return $? ;;
			pppoe | pptp | l2tp) cfmgr_status_nvram "wan${cfmgr_status_wan}_pppoe_ifname" || return $? ;;
			*) printf 'WAN interface: Unknown (unsupported protocol)\n' ;;
		esac
		cfmgr_status_nvram "wan${cfmgr_status_wan}_ipaddr" || return $?
		;;
	*) printf 'WAN interface/address: Unknown\n' ;;
	esac
	for cfmgr_status_target in /jffs /opt; do
		if cfmgr_status_mount "$cfmgr_status_target"; then
			printf '%s mount: ' "$cfmgr_status_target"
			IFS= read -r cfmgr_status_value < "$cfmgr_probe_stdout"
			printf '%s\n' "$cfmgr_status_value"
			if cfmgr_status_space "$cfmgr_status_target"; then
				printf '%s space: ' "$cfmgr_status_target"
				IFS= read -r cfmgr_status_value < "$cfmgr_probe_stdout"
				printf '%s\n' "$cfmgr_status_value"
			else
				[ "$?" != 3 ] || return 3
				printf '%s space: Unavailable\n' "$cfmgr_status_target"
			fi
		else
			[ "$?" != 3 ] || return 3
			printf '%s mount/space: Unavailable or unmounted\n' "$cfmgr_status_target"
		fi
	done
	if cfmgr_status_snapshot "$cfmgr_source/setup-state" &&
		cfmgr_status_fields setup "$cfmgr_status_snapshot_file" "$CFMGR_VERSION"; then
		printf 'Installation: retained setup complete\n'
	else
		[ "$?" != 3 ] || return 3
		printf 'Issue: retained setup incomplete/unavailable; use recovery\n'
	fi
	if cfmgr_status_run status-metadata /bin/ls "$cfmgr_source/.storage-observation"; then
		printf 'Issue: retained storage observation requires cleanup/recovery\n'
	else
		[ "$?" != 3 ] || return 3
	fi
	cfmgr_status_save_pending=0
	for cfmgr_status_save_guard in .config-save.preparing .config-save .config-save.retired; do
		if [ -e "$cfmgr_source/$cfmgr_status_save_guard" ] || [ -L "$cfmgr_source/$cfmgr_status_save_guard" ]; then
			cfmgr_status_save_pending=1
			break
		fi
	done
	[ "$cfmgr_status_save_pending" = 0 ] || printf 'Issue: pending configuration Save/recovery guard; use explicit recovery\n'
	if [ "$cfmgr_status_config" != unavailable ] && cfmgr_status_project render; then
		# The parser emits only a safe typed projection, never input bytes/errors.
		while IFS= read -r cfmgr_status_line; do printf '%s\n' "$cfmgr_status_line"; done < "$cfmgr_probe_stdout"
	else
		[ "$?" != 3 ] || return 3
		printf 'Configuration: Unavailable or invalid; recover retained settings\nDDNS/IP-Sync/Cloudflared: Unknown\nProvider history: Unavailable\n'
	fi
	[ "$cfmgr_status_budget_exhausted" = 0 ] || printf 'Issue: native probe budget exhausted; remaining evidence unavailable\n'
	printf 'Status uses local evidence; no network or feature action was performed.\n\n'
}

cfmgr_status_project() {
	cfmgr_status_run status-config /usr/bin/awk "$cfmgr_source/modules/lib/config.sh" \
		"$cfmgr_source/modules/status.sh" "$cfmgr_status_config" "$1" "$cfmgr_status_now" "$cfmgr_status_boot" \
		"$CFMGR_REPOSITORY" "$CFMGR_BRANCH" "$cfmgr_status_wan" "$cfmgr_status_clock" "$cfmgr_status_config_bytes"
}

cfmgr_status_nvram() {
	cfmgr_status_value=unknown
	if cfmgr_status_run status-nvram /bin/nvram "$1" && cfmgr_status_fields nvram "$cfmgr_probe_stdout" "$1"; then
		IFS= read -r cfmgr_status_value < "$cfmgr_probe_stdout"
		case $1 in wan0_primary | wan1_primary) return 0 ;; ntp_ready) [ "$cfmgr_status_value" != Ready ] || cfmgr_status_clock=1 ;; esac
		printf '%s: %s\n' "$1" "$cfmgr_status_value"
	else
		[ "$?" != 3 ] || return 3
		case $1 in wan0_primary | wan1_primary) return 0 ;; esac
		printf '%s: Unavailable\n' "$1"
	fi
}

# Collection stages exec exactly one owned native command. Projection is a
# separate bounded awk stage, so a hung nvram/df/dd never leaves a wrapper child.
cfmgr_status_fields() {
	cfmgr_status_run status-fields /usr/bin/awk "$cfmgr_source/modules/status.sh" "$1" "$2" "$3"
}

cfmgr_status_snapshot() {
	cfmgr_status_run status-metadata /bin/ls "$1" || return $?
	cfmgr_status_fields metadata "$cfmgr_probe_stdout" - || return $?
	IFS=' ' read -r cfmgr_status_snapshot_inode cfmgr_status_snapshot_bytes < "$cfmgr_probe_stdout" || return 1
	cfmgr_status_snapshot_metadata="$cfmgr_status_snapshot_inode $cfmgr_status_snapshot_bytes"
	cfmgr_status_run status-snapshot /bin/dd "$1" || return $?
	cfmgr_status_snapshot_file=$cfmgr_probe_stdout
	cfmgr_status_run status-count /usr/bin/wc "$cfmgr_status_snapshot_file" || return $?
	IFS=' ' read -r cfmgr_status_snapshot_actual cfmgr_status_snapshot_extra < "$cfmgr_probe_stdout" || return 1
	[ -z "$cfmgr_status_snapshot_extra" ] && [ "$cfmgr_status_snapshot_actual" = "$cfmgr_status_snapshot_bytes" ] || return 1
	cfmgr_status_run status-metadata /bin/ls "$1" || return $?
	cfmgr_status_fields metadata "$cfmgr_probe_stdout" - || return $?
	IFS= read -r cfmgr_status_snapshot_after < "$cfmgr_probe_stdout" || return 1
	[ "$cfmgr_status_snapshot_after" = "$cfmgr_status_snapshot_metadata" ]
}

cfmgr_status_mount() {
	cfmgr_status_run status-realpath /usr/bin/readlink "$1" || return $?
	IFS= read -r cfmgr_status_mount_target < "$cfmgr_probe_stdout" || return 1
	case $cfmgr_status_mount_target in /*) ;; *) return 1 ;; esac
	case $cfmgr_status_mount_target in *[!\ -~]* | *\\* | */../* | */./* | *//*) return 1 ;; esac
	cfmgr_status_run status-mount /usr/bin/awk "$cfmgr_source/modules/lib/storage.sh" "$cfmgr_status_mount_target" || return $?
	cfmgr_status_fields mount "$cfmgr_probe_stdout" "$1"
}

cfmgr_status_space() {
	cfmgr_status_run status-space /bin/df "$1" || return $?
	cfmgr_status_fields space "$cfmgr_probe_stdout" -
}

cfmgr_status_awk_status_native() {
	# CFMGR-AWK-BEGIN status_native
	cfmgr_awk_program='
# One bounded read of fixed kernel resource paths; no process/command-line scan.
# ARGV[1] is the caller-admitted proc root (production /proc). Typed tab receipts
# exclude identifiers except the boot UUID, which stays private in the consumer.
BEGIN {
    if (ARGV[1] != "resources") { projection(ARGV[1],ARGV[2],ARGV[3]); exit }
    root = ARGV[2]; ARGV[1] = ARGV[2] = ""; ARGC = 1
    uptime = load = memory = "Unavailable"
    if ((getline line < (root "/uptime")) == 1 && length(line) < 128) {
        split(line, fields, " ")
        if (fields[1] ~ /^[0-9]+\.[0-9]+$/) uptime = int(fields[1]) "s"
    }
    close(root "/uptime")
    if ((getline line < (root "/loadavg")) == 1 && length(line) < 128) {
        split(line, fields, " ")
        if (fields[1] ~ /^[0-9]+\.[0-9]+$/ && fields[2] ~ /^[0-9]+\.[0-9]+$/ && fields[3] ~ /^[0-9]+\.[0-9]+$/)
            load = fields[1] " " fields[2] " " fields[3]
    }
    close(root "/loadavg")
    count = 0
    while ((getline line < (root "/meminfo")) == 1) {
        if (++count > 128 || length(line) > 256) { bad = 1; break }
        split(line, fields, " ")
        if (fields[2] ~ /^[0-9]+$/ && fields[3] == "kB") mem[fields[1]] = fields[2] + 0
    }
    close(root "/meminfo")
    if (!bad && mem["MemTotal:"] > 0) {
        available = mem["MemAvailable:"]
        if (!("MemAvailable:" in mem)) available = mem["MemFree:"] + mem["Buffers:"] + mem["Cached:"]
        if (available >= 0 && available <= mem["MemTotal:"])
            memory = sprintf("%d/%d KiB used; %d KiB available%s", mem["MemTotal:"] - available,
                mem["MemTotal:"], available, (("MemAvailable:" in mem) ? "" : " (estimate)"))
    }
    boot = "unknown"
    if ((getline line < (root "/sys/kernel/random/boot_id")) == 1 &&
        length(line) == 36 && line ~ /^[0-9a-f-]+$/ && substr(line,9,1)=="-" &&
        substr(line,14,1)=="-" && substr(line,19,1)=="-" && substr(line,24,1)=="-") boot = line
    close(root "/sys/kernel/random/boot_id")
    print "uptime\t" uptime
    print "load\t" load
    print "memory\t" memory
    print "boot\t" boot
    exit
}
# Projection inputs are immutable bounded native outputs in the owned context.
function projection(mode,path,key,    line,n,a,i,value,bad,count,out) {
    count=0
    while((getline line < path)==1) {
        if(++count>4 || length(line)>8192 || line~/[^ -~\t]/) { bad=1; break }
        if(mode=="space") {
            if(count==1) continue
            n=split(line,a," ")
            if(count!=2 || n!=6 || a[2]!~/^[0-9]+$/ || a[3]!~/^[0-9]+$/ || a[4]!~/^[0-9]+$/ || a[5]!~/^[0-9]+%$/ || a[2]<=0 || a[3]>a[2] || a[4]>a[2]) { bad=1; break }
            out=a[3] "/" a[2] " KiB used; " a[4] " KiB available (" a[5] ")"
        } else if(mode=="metadata") {
            n=split(line,a," ")
            if(count!=1 || n<10 || a[1]!~/^[1-9][0-9]*$/ || a[2]!="-rw-------" || a[4]!="0" || a[6]!~/^[1-9][0-9]*$/ || a[6]>65536) { bad=1; break }
            out=a[1] " " a[6]
        } else if(mode=="mount") {
            n=split(line,a,"\t")
            if(count!=1 || n!=9) { bad=1; break }
            if(key=="/jffs" && a[6]=="jffs2" && a[5]=="/jffs") out="jffs2 mounted"
            else if(key=="/opt" && a[5]!="/" && a[6]~/^(ext[234]|vfat|exfat|ntfs|ntfs3|fuseblk)$/) out=a[6] " mounted"
            else { bad=1; break }
            out=out (index("," a[8] ",",",rw,") ? " (rw)" : " (ro)")
        } else if(mode=="setup") {
            if(count!=1 || line!="CFMGR-SETUP 1 " key " complete") { bad=1; break }
            out="complete"
        } else if(mode=="nvram") {
            if(count!=1 || length(line)>128 || line=="" || line~/[^ -~]/) { bad=1; break }
            if(key~/_ipaddr$/) { if(!native_ipv4(line)) { bad=1; break }; out=line " (" native_class(line) ")" }
            else if(key=="ntp_ready") { if(line=="1") out="Ready"; else if(line=="0") out="Not ready"; else bad=1 }
            else if(key~/_primary$/) { if(line!~/^[01]$/) bad=1; else out=line }
            else { if(line!~/^[A-Za-z0-9_.:-]+$/) bad=1; else out=line }
        } else { bad=1; break }
    }
    close(path)
    if(bad || !count || out=="" || (mode=="space" && count!=2)) exit 1
    print out
}
function native_ipv4(s,    n,a,i) { n=split(s,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function native_class(s,    a) {
    split(s,a,".")
    if(a[1]==100 && a[2]>=64 && a[2]<=127) return "Shared-CGNAT"
    if(a[1]==10 || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && a[2]==168)) return "Private"
    if(a[1]==0 || a[1]==127 || a[1]>=224 || (a[1]==169 && a[2]==254) ||
        (a[1]==192 && a[2]==0 && (a[3]==0 || a[3]==2)) ||
        (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) ||
        (a[1]==203 && a[2]==0 && a[3]==113)) return "Non-public"
    return "Public"
}
'
	# CFMGR-AWK-END status_native
}

cfmgr_status_awk_status() {
	# CFMGR-AWK-BEGIN status
	cfmgr_awk_program='
# Subsequent config JSON getter tree consumer: typed, allowlisted status projection only.
# Optional history.<feature>.status contract (schema1, generation): ipv4/ipv6
# {result:published|verified|removed,value:IP|null,at:epoch}; latest/events
# {result:success|partial|pending|failed,reason:enum,at:epoch}. At most5 events.
# observation {origin:runtime|restored,boot_id,at,running:boolean,
# connection:connected|waiting|unknown,installed_version,logging:enum,cleanup:boolean}.
# Current observations require runtime origin, generation/boot match and trusted
# nonfuture age<=300s. Future restore writers MUST invalidate runtime origin.
# history.network.status uses the same context plus selected_wan and family
# {value,at,source:recorded|interface|discovery,eligible:boolean forIPv6}.
# History remains historical and never establishes current auth/provider success.
# No raw recorded errors/credentials/identifiers or terminal controls are emitted.
BEGIN {
    if (!cfmgr_json_tree_ready || cfmgr_json_tree_kind[1] != "object") exit 1
    for (i=2; i<=cfmgr_json_tree_count; i++) child[cfmgr_json_tree_parent[i],cfmgr_json_tree_location[i]]=i
    config_schema=number(field(1,"schema"))
    if (config_schema != "1" && config_schema != "2") exit 1
    generation=number(field(1,"generation"))
    if (generation !~ /^[1-9][0-9]*$/ || length(generation)>20) exit 1
    network=object(field(1,"network")); selected=field(network,"selected_wan")
    wan="auto"
    if (selected && cfmgr_json_tree_kind[selected]!="null") {
        value=number(selected); if(value=="") value=text(selected,8)
        if(value=="wan0") value="0"; if(value=="wan1") value="1"
        wan=(value=="0" || value=="1" ? value : "unknown")
    }
    if (ENVIRON["CFMGR_STATUS_MODE"]=="select") { print wan; exit }
    if (ENVIRON["CFMGR_STATUS_MODE"]!="render") exit 1
    now=ENVIRON["CFMGR_STATUS_NOW"]; clock=(ENVIRON["CFMGR_STATUS_CLOCK"]=="1")
    if (now !~ /^[1-9][0-9]*$/ || length(now)>10) clock=0
    boot=ENVIRON["CFMGR_STATUS_BOOT"]; live_wan=ENVIRON["CFMGR_STATUS_WAN"]
    print "Configuration: local schema" config_schema "; settings and observations are separate"
    manager=object(field(1,"manager")); developer=boolean(field(manager,"developer"))
    repository=ENVIRON["CFMGR_STATUS_REPOSITORY"]; branch=ENVIRON["CFMGR_STATUS_BRANCH"]
    if(developer=="On") {
        source=object(field(manager,"source")); repository=text(field(source,"repository"),192)
        branch=text(field(source,"branch"),128); commit=text(field(source,"commit"),40)
        if(repository !~ /^https:\/\/github\.com\/[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/ ||
            branch !~ /^[A-Za-z0-9_.\/-]+$/ || branch ~ /(^|\/)(\.|\.\.)(\/|$)/ ||
            (commit!="" && (length(commit)!=40 || commit~/[^0-9a-f]/))) {
            print "Manager source: Unavailable (invalid developer selection)"
        } else print "Manager source: developer " repository " / " branch (commit!="" ? " @ " commit : "")
    } else if(developer=="Off") print "Manager source: default " repository " / " branch
    else print "Manager source: Unknown (invalid developer setting)"
    check_updates=boolean(field(manager,"check_updates")); auto_update=boolean(field(manager,"auto_update"))
    if(developer=="On") {
        effective_check=(check_updates=="Unknown" ? "Unknown" : "Off")
        effective_auto=(check_updates=="Unknown" || auto_update=="Unknown" ? "Unknown" : "Off")
    } else if(developer=="Off") {
        effective_check=check_updates
        effective_auto=(check_updates=="Unknown" || auto_update=="Unknown" ? "Unknown" : (check_updates=="On" && auto_update=="On" ? "On" : "Off"))
    } else {
        effective_check="Unknown"; effective_auto="Unknown"
    }
    print "Manager updates: saved Check=" check_updates "; saved Auto=" auto_update "; effective Check=" effective_check "; effective Auto=" effective_auto
    if(developer=="On") print "Note: developer mode suppresses manager updates; saved preferences are retained"
    history=object(field(1,"history")); logging=object(field(1,"logging"))
    if(wan=="unknown") print "Issue: invalid selected WAN; recover network settings"
    addresses(object(field(object(field(history,"network")),"status")))
    names[1]="ddns"; names[2]="ip_sync"; names[3]="cloudflared"
    labels[1]="DDNS"; labels[2]="IP-Sync"; labels[3]="Cloudflared"
    for(f=1;f<=3;f++) {
        name=names[f]; label=labels[f]; settings=object(field(1,name))
        configured=boolean(field(settings,"configured")); enabled=boolean(field(settings,"enabled"))
        print label ": configured=" configured "; enabled=" enabled
        if(name=="cloudflared") print "  installed=" boolean(field(settings,"installed")) "; maintenance=" boolean(field(settings,"maintenance_enabled"))
        if(configured=="Unknown" || enabled=="Unknown") print "  Issue: settings unavailable/invalid; recover retained settings"
        else if(configured=="Off" && enabled=="On") print "  Issue: invalid enabled-without-configured; recover retained settings"
        else if(configured=="Off") print "  Next: configure " label " first"
        else if(enabled=="Off") print "  Next: enable " label " when ready"
        record=object(field(object(field(history,name)),"status"))
        if(record && number(field(record,"schema"))!="1") { print "  History: Unavailable (invalid record schema)"; record=0 }
        if(name!="cloudflared") {
            outcome(record,"ipv4","IPv4"); outcome(record,"ipv6","IPv6")
        }
        latest=object(field(record,"latest"))
        if(!latest) print "  Last outcome: Never"
        else {
            result=result_value(latest); reason=reason_value(latest)
            if(result=="" || reason=="") print "  Last outcome: Unavailable (invalid typed record)"
            else print "  Last outcome (historical): " result "; " reason "; " age(field(latest,"at")) context(record)
        }
        observe(record,configured,enabled)
        log_settings=object(field(logging,name))
        if(boolean(field(log_settings,"configured"))=="On" && boolean(field(log_settings,"enabled"))=="On" && observed_logging!="ready")
            print "  Issue: requested logging readiness " (observed_logging=="" ? "Unknown" : observed_logging)
        events(record)
    }
    for(e=1;e<=recent_count;e++) print recent[e]
    exit
}
function hex(s,    i,out) { out=""; for(i=1;i<=length(s);i++) out=out byte_hex[byte_value["b" substr(s,i,1)]]; return out }
function field(parent,key) { return parent ? child[parent,"k" hex(key)] : 0 }
function object(id) { return cfmgr_json_tree_kind[id]=="object" ? id : 0 }
function number(id) { return cfmgr_json_tree_kind[id]=="number" ? substr(cfmgr_json_tree_payload[id],2) : "" }
function boolean(id) { return cfmgr_json_tree_kind[id]=="true" ? "On" : (cfmgr_json_tree_kind[id]=="false" ? "Off" : "Unknown") }
function text(id,limit,    encoded,i,n,out) {
    if(cfmgr_json_tree_kind[id]!="string") return ""
    encoded=substr(cfmgr_json_tree_payload[id],2); if(length(encoded)>limit*2) return ""
    out=""; for(i=1;i<=length(encoded);i+=2) {
        n=16*hex_value["h" substr(encoded,i,1)]+hex_value["h" substr(encoded,i+1,1)]
        if(n<32 || n>126) return ""
        out=out sprintf("%c",n)
    }; return out
}
function ipv4(s,    a,n,i) { n=split(s,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function public4(s,    a) { if(!ipv4(s)) return 0; split(s,a,"."); return !(a[1]==0 || a[1]==10 || a[1]==127 || a[1]>=224 || (a[1]==100 && a[2]>=64 && a[2]<=127) || (a[1]==169 && a[2]==254) || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && (a[2]==168 || (a[2]==0 && (a[3]==0 || a[3]==2)))) || (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) || (a[1]==203 && a[2]==0 && a[3]==113)) }
function ipv6(s,    lower,n,a,i,double,groups) {
    lower=tolower(s)
    if(length(s)>39 || s~/[^0-9a-fA-F:]/ || lower!~/^[23][0-9a-f][0-9a-f][0-9a-f]:/ || lower~/^2001:0?db8:/ || s~/:::/) return 0
    double=index(s,"::"); if(double && index(substr(s,double+2),"::")) return 0
    n=split(s,a,":"); groups=0
    for(i=1;i<=n;i++) if(a[i]!="") { if(length(a[i])>4 || a[i]!~/^[0-9a-fA-F]+$/) return 0; groups++ }
    if((substr(s,1,1)==":" && substr(s,1,2)!="::") || (substr(s,length(s),1)==":" && substr(s,length(s)-1)!="::")) return 0
    return double ? groups<8 : groups==8
}
function age(id,    stamp) {
    stamp=number(id)
    if(!clock || stamp!~/^[1-9][0-9]*$/ || length(stamp)>10 || stamp>now) return "time/age Unknown"
    return "at " stamp "; age " sprintf("%.0f",now-stamp) "s"
}
function context(record,    gen) {
    gen=number(field(record,"generation"))
    return ("g" gen=="g" generation ? "" : " (stale generation)")
}
function result_value(item,    s) { s=text(field(item,"result"),16); return s~/^(success|partial|pending|failed)$/ ? s : "" }
function reason_value(item,    s) { s=text(field(item,"reason"),16); return s~/^(auth|storage|recovery|throttle|partial|unavailable|none|network|waiting)$/ ? s : "" }
function outcome(record,family,label,    item,result,value,eligible) {
    item=object(field(record,family))
    if(!item) { print "  Last verified " label ": Never"; return }
    result=text(field(item,"result"),16); value=text(field(item,"value"),39)
    if(result!~/^(published|verified|removed)$/ ||
        (result=="removed" ? cfmgr_json_tree_kind[field(item,"value")]!="null" : \
        (family=="ipv4" ? !public4(value) : !ipv6(value)))) { print "  Last verified " label ": Unavailable (invalid typed record)"; return }
    print "  Last verified " label " (historical): " result (result=="removed" ? "" : " " value) "; " age(field(item,"at")) context(record)
}
function fresh(record,item,    stamp,gen) {
    stamp=number(field(item,"at")); gen=number(field(record,"generation"))
    return number(field(record,"schema"))=="1" && "g" gen=="g" generation &&
        text(field(item,"origin"),16)=="runtime" && boot!="unknown" && text(field(item,"boot_id"),36)==boot &&
        clock && stamp~/^[1-9][0-9]*$/ && length(stamp)<=10 && stamp<=now && now-stamp<=300
}
function observe(record,configured,enabled,    item,state,running,version,cleanup) {
    observed_logging=""; item=object(field(record,"observation"))
    if(!item) { print "  Runtime: Unknown (no current local observation)"; if(name=="cloudflared") print "  Installed version: Unknown"; return }
    if(boolean(field(item,"cleanup"))=="On") print "  Issue: recorded cleanup required; use scoped recovery; " age(field(item,"at")) context(record)
    if(!fresh(record,item)) { print "  Runtime: Unknown (stale/restored/untrusted observation)"; version=text(field(item,"installed_version"),64)
        if(name=="cloudflared") print "  Installed version: " (version~/^[A-Za-z0-9_.+-]+$/ ? version " (recorded/stale)" : "Unknown")
        return
    }
    running=boolean(field(item,"running")); state=text(field(item,"connection"),16)
    if(state!~/^(connected|waiting|unknown)$/ || running=="Unknown" || (state=="connected" && running!="On")) {
        print "  Runtime: Unavailable (invalid typed observation)"; return
    }
    print "  Observed running=" running "; connection=" state "; " age(field(item,"at"))
    version=text(field(item,"installed_version"),64)
    if(name=="cloudflared") print "  Installed version: " (version~/^[A-Za-z0-9_.+-]+$/ ? version " (recorded runtime)" : "Unknown")
    observed_logging=text(field(item,"logging"),16)
    if(observed_logging!~/^(ready|unavailable|unknown)$/) observed_logging=""
}
function addresses(record,    family,item,value,valid,label,source,stale) {
    for(family=1;family<=2;family++) {
        label=(family==1 ? "public IPv4" : "eligible IPv6"); item=object(field(record,(family==1 ? "ipv4" : "ipv6")))
        if(!item) { print "Recorded " label ": Never"; continue }
        value=text(field(item,"value"),39); source=text(field(item,"source"),16)
        valid=(family==1 ? public4(value) : ipv6(value) && boolean(field(item,"eligible"))=="On")
        if(number(field(record,"schema"))!="1" || !valid || source!~/^(recorded|interface|discovery)$/) { print "Recorded " label ": Unavailable (invalid typed record)"; continue }
        stale=(!clock || number(field(item,"at"))!~/^[1-9][0-9]*$/ || number(field(item,"at"))>now) || !("g" number(field(record,"generation"))=="g" generation && text(field(record,"boot_id"),36)==boot &&
            boot!="unknown" && text(field(record,"selected_wan"),8)==live_wan)
        print "Recorded " label " (historical" (stale ? "/stale" : "") "): " value "; source=" source "; " age(field(item,"at"))
    }
}
function events(record,    array,i,count,item,result,reason,first) {
    array=field(record,"events"); if(cfmgr_json_tree_kind[array]!="array") return
    count=0; while(child[array,"i" count]) count++
    first=(count>5 ? count-5 : 0)
    for(i=first;i<count;i++) {
        item=object(child[array,"i" i]); result=result_value(item); reason=reason_value(item)
        if(result!="" && reason!="" && recent_count<5) recent[++recent_count]="Recent " label " (historical): " result "; " reason "; " age(field(item,"at")) context(record)
    }
}
'
	# CFMGR-AWK-END status
}
