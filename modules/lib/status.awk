# Subsequent json.awk tree consumer: typed, allowlisted status projection only.
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
