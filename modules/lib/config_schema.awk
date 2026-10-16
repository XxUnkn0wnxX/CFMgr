# Schema-2 typed authority validation. Definition-only companion to the bounded
# json.awk tree and config_observation.awk transaction consumer. No execution,
# provider admission, guard authority, or lifecycle effects follow from validity.
function cs_id(parent, key) { return co_child[parent, "k" co_hex(key)] }
function cs_text(id) { co_type(id,"string"); return co_decode(substr(cfmgr_json_tree_payload[id],2)) }
function cs_string(parent,key,nullable,    id,value) {
    id=co_field(parent,key,(nullable ? "string|null" : "string"))
    if(cfmgr_json_tree_kind[id]=="null") return ""
    value=cs_text(id); if(value=="") reject(); return value
}
function cs_enum(parent,key,values,nullable,    id,value) {
    id=co_field(parent,key,(nullable ? "string|null" : "string"))
    if(cfmgr_json_tree_kind[id]=="null") return ""
    value=cs_text(id); if(value=="" || index(value,"|") || !index("|" values "|","|" value "|")) reject(); return value
}
# Decimal lexemes remain strings throughout comparisons; even signed-64-bit
# boundaries must not round through awk's binary floating-point representation.
function cs_le(value,maximum) {
    return length(value)<length(maximum) || (length(value)==length(maximum) && "d" value<="d" maximum)
}
function cs_integer(id,minimum,maximum,    value) {
    co_type(id,"number"); value=substr(cfmgr_json_tree_payload[id],2)
    if(value!~/^(0|[1-9][0-9]*)$/ || !cs_le(minimum,value) || !cs_le(value,maximum)) reject()
    return value
}
function cs_int(parent,key,minimum,maximum) { return cs_integer(co_field(parent,key,"number"),minimum,maximum) }
function cs_generation(parent,key) { return cs_int(parent,key,"1","99999999999999999999") }
function cs_bool(parent,key,    id) { id=co_field(parent,key,"boolean"); return cfmgr_json_tree_kind[id]=="true" }
function cs_version(parent) { if(cs_int(parent,"schema","1","1")!="1") reject() }
function cs_local(value) { if(value!~/^[A-Za-z][A-Za-z0-9._-]*$/) reject(); return value }
function cs_path(parent,key,nullable,    value) { value=cs_string(parent,key,nullable); if(value!="") co_path(value,1); return value }
function cs_uuid(value,    groups,n,i) {
    n=split(value,groups,"-")
    if(n!=5 || length(groups[1])!=8 || length(groups[2])!=4 || length(groups[3])!=4 || length(groups[4])!=4 || length(groups[5])!=12) reject()
    for(i=1;i<=5;i++) if(groups[i]!~/^[0-9a-fA-F]+$/) reject()
    return tolower(value)
}
function cs_hash(parent,key,nullable,    value) {
    value=cs_string(parent,key,nullable)
    if(value!="" && (length(value)!=64 || value~/[^0-9a-f]/)) reject()
    return value
}
function cs_absent(parent,keys,    a,n,i) {
    n=split(keys,a," "); for(i=1;i<=n;i++) if(cs_id(parent,a[i])) reject()
}
function cs_policy(parent,key,    id) {
    id=co_field(parent,key,"object|null"); if(cfmgr_json_tree_kind[id]=="null") return 0
    cs_version(id); return id
}
function cs_request(id,    request,connection) {
    request=cs_int(id,"request_timeout_seconds","1","30")+0
    connection=cs_int(id,"connect_timeout_seconds","1","10")+0
    if(connection>request) reject(); return request
}
function cs_ref(parent,key,kind,    value) {
    value=cs_string(parent,key,1); if(value=="") return 0
    cs_local(value)
    if(!(value in cs_credentials) || (kind!="" && cs_kinds[value]!=kind)) reject()
    return cs_credentials[value]
}
function cs_credentials_validate(registry,    i,key,record,kind) {
    for(i=2;i<=cfmgr_json_tree_count;i++) {
        if(cfmgr_json_tree_parent[i]!=registry) continue
        key=cs_local(co_decode(substr(cfmgr_json_tree_location[i],2)))
        record=co_type(i,"object"); cs_version(record)
        kind=cs_enum(record,"kind","cloudflare_api_token|cloudflared_token|cloudflared_json|cloudflared_certificate",0)
        cs_credentials[key]=record; cs_kinds[key]=kind
        if(kind=="cloudflare_api_token" || kind=="cloudflared_token") cs_string(record,"value",0)
        else if(kind=="cloudflared_json") {
            cs_string(record,"account_tag",0); cs_uuid(cs_string(record,"tunnel_id",0)); cs_string(record,"tunnel_secret",0)
        } else {
            cs_string(record,"account_id",0); cs_string(record,"format",0)
            cs_path(record,"path",0); cs_path(record,"recovery_path",0)
            cs_hash(record,"sha256",0); cs_generation(record,"generation")
            cs_enum(record,"provenance","login|import|migration|repair",0)
        }
    }
}
function cs_ttl(id,    mode) {
    co_type(id,"object|null"); if(cfmgr_json_tree_kind[id]=="null") return ""
    mode=cs_enum(id,"mode","auto|seconds",0)
    if(mode=="seconds") cs_int(id,"value","30","86400")
    else if(cs_id(id,"value")) reject()
    return mode
}
function cs_ddns(id,    configured,zone,primary,ref,records,i,item,key,name,type,ttl,proxied,effective_ttl,effective_proxy,found,policy,request) {
    cs_absent(id,"credentials")
    configured=cs_bool(id,"configured"); if(cs_bool(id,"enabled") && !configured) reject()
    cs_enum(id,"address_family","auto|ipv4|ipv6|dual",0)
    zone=cs_string(id,"zone_id",1); primary=cs_string(id,"primary_hostname",1)
    if(length(primary)>63) reject()
    ref=cs_ref(id,"credential_ref","cloudflare_api_token")
    ttl=cs_ttl(co_field(id,"ttl","object|null"))
    proxied=co_field(id,"proxied","boolean|null")
    cs_int(id,"forced_refresh_days","1","999")
    records=co_field(id,"records","array")
    for(i=0; (item=co_child[records,"i" i]);i++) {
        co_type(item,"object"); key=cs_local(cs_string(item,"id",0))
        if(cs_ddns_local[key]++) reject()
        name=cs_string(item,"name",0); type=cs_enum(item,"type","A|AAAA",0)
        key=zone SUBSEP tolower(name) SUBSEP type; if(cs_ddns_logical[key]++) reject()
        if("s" tolower(name)=="s" tolower(primary)) found=1
        effective_ttl=(cs_id(item,"ttl") ? cs_ttl(cs_id(item,"ttl")) : ttl)
        effective_proxy=(cs_id(item,"proxied") ? co_type(cs_id(item,"proxied"),"boolean|null") : proxied)
        if(cfmgr_json_tree_kind[effective_proxy]=="true" && effective_ttl!="auto") reject()
        if(configured && (effective_ttl=="" || cfmgr_json_tree_kind[effective_proxy]=="null")) reject()
    }
    if(configured && (zone=="" || primary=="" || !ref || !i || !found)) reject()
    if(!i && cfmgr_json_tree_kind[proxied]=="true" && ttl!="auto") reject()
    policy=cs_policy(id,"timeouts")
    if(policy) { request=cs_request(policy); if((cs_int(policy,"completion_timeout_seconds","5","90")+0)<request+5) reject() }
}
function cs_sync(id,    configured,account,ref,targets,i,item,role,target,families,j,family,primary,policy,request) {
    cs_absent(id,"credentials")
    configured=cs_bool(id,"configured"); if(cs_bool(id,"enabled") && !configured) reject()
    cs_enum(id,"address_family","auto|ipv4|ipv6|dual",0)
    account=cs_string(id,"account_id",1); ref=cs_ref(id,"credential_ref","cloudflare_api_token")
    targets=co_field(id,"targets","array")
    for(i=0;(item=co_child[targets,"i" i]);i++) {
        if(i>=2) reject(); co_type(item,"object")
        role=cs_enum(item,"role","primary|secondary",0); if(cs_sync_roles[role]++) reject()
        if(role=="primary") primary++
        target=cs_string(item,"id",0); if(cs_sync_ids[target]++) reject(); cs_string(item,"name",0)
        families=co_field(item,"families","array")
        for(j=0;co_child[families,"i" j];j++) {
            family=cs_text(co_child[families,"i" j]); if(family!~/^(ipv4|ipv6)$/ || cs_sync_families[family]++) reject()
        }
        if(!j) reject()
    }
    if(configured && (account=="" || !ref || !i || primary!=1)) reject()
    policy=cs_policy(id,"retry")
    if(policy) { request=cs_request(policy); cs_int(policy,"attempts","1","4"); if((cs_int(policy,"batch_timeout_seconds","1","300")+0)<request) reject() }
}
function cs_cloud(id,    configured,method,refs,runtime,management,certificate,dns,identity,account,tunnel,paths,yaml,json,cert_path,policy,response) {
    cs_absent(id,"token account_tag tunnel_id tunnel_secret credentials")
    configured=cs_bool(id,"configured"); if(cs_bool(id,"enabled") && !configured) reject()
    cs_bool(id,"installed"); cs_bool(id,"maintenance_enabled"); co_field(id,"binary_auto_update","boolean|null")
    method=cs_enum(id,"method","token|advanced",1)
    refs=co_field(id,"credential_refs","object")
    runtime=cs_ref(refs,"runtime",(method=="token" ? "cloudflared_token" : (method=="advanced" ? "cloudflared_json" : "")))
    if(runtime && cs_kinds[cs_string(refs,"runtime",0)]!~/^cloudflared_(token|json)$/) reject()
    management=cs_ref(refs,"management","cloudflare_api_token"); dns=cs_ref(refs,"dns","cloudflare_api_token")
    certificate=cs_ref(refs,"certificate","cloudflared_certificate")
    identity=co_field(id,"expected_identity","object")
    account=cs_string(identity,"account_id",1); tunnel=cs_string(identity,"tunnel_id",1)
    if(tunnel!="") tunnel=cs_uuid(tunnel)
    paths=co_field(id,"paths","object"); yaml=cs_path(paths,"yaml",1); json=cs_path(paths,"json",1); cert_path=cs_path(paths,"certificate",1)
    if(certificate && ((account!="" && "s" account!="s" cs_string(certificate,"account_id",0)) || "s" cert_path!="s" cs_path(certificate,"path",0))) reject()
    if(!certificate && cert_path!="") reject()
    if(runtime && method=="advanced") {
        if("s" account!="s" cs_string(runtime,"account_tag",0) || "s" tunnel!="s" cs_uuid(cs_string(runtime,"tunnel_id",0))) reject()
    }
    if(configured && (method=="" || !runtime || (method=="advanced" && (account=="" || tunnel=="" || yaml=="" || json=="")))) reject()
    policy=cs_policy(id,"readiness")
    if(policy) { response=cs_int(policy,"response_timeout_seconds","1","2")+0; if((cs_int(policy,"command_timeout_seconds","1","3")+0)<response) reject() }
    policy=cs_policy(id,"watchdog")
    if(policy) { cs_int(policy,"reconnect_grace_seconds","1","300"); cs_int(policy,"stability_seconds","60","3600") }
    co_cloud_configured=cs_id(id,"configured"); co_cloud_enabled=cs_id(id,"enabled")
}
function cs_logging(root,    i,name,id,configured,enabled,optout,policy,size,unit,maximum,value) {
    for(i=1;i<=3;i++) {
        name=(i==1 ? "ddns" : (i==2 ? "ip_sync" : "cloudflared"))
        id=co_field(root,name,"object"); configured=cs_bool(id,"configured"); enabled=cs_bool(id,"enabled"); optout=cs_bool(id,"opt_out")
        if((enabled && !configured) || (optout && enabled)) reject()
        cs_absent(id,"compress compression delaycompress delay_compression")
        policy=cs_policy(id,"policy")
        if(policy) {
            cs_absent(policy,"compress compression delaycompress delay_compression")
            if(name!="cloudflared") { cs_int(policy,"version","1","1"); cs_absent(policy,"size total_files max_age_days mode") }
            else {
                cs_enum(policy,"mode","size|daily|weekly|monthly",0)
                size=co_field(policy,"size","object"); unit=cs_enum(size,"unit","B|KiB|MiB|GiB",0)
                maximum=(unit=="B" ? "9223372036854775807" : (unit=="KiB" ? "9007199254740991" : (unit=="MiB" ? "8796093022207" : "8589934591")))
                cs_int(size,"value","1",maximum)
                cs_int(policy,"total_files","1","2147483648")
                value=co_field(policy,"max_age_days","number|null"); if(cfmgr_json_tree_kind[value]!="null") cs_integer(value,"1","30")
            }
        }
        if(configured && !policy) reject()
    }
}
function cs_ownership(root,    components,i,item,component,path,migration) {
    cs_version(root); components=co_field(root,"components","array")
    for(i=0;(item=co_child[components,"i" i]);i++) {
        co_type(item,"object"); cs_version(item)
        component=cs_local(cs_string(item,"component",0)); path=cs_path(item,"path",0)
        if(cs_owner_components[component]++ || cs_owner_paths[path]++) reject()
        cs_generation(item,"generation"); cs_hash(item,"sha256",1)
    }
    migration=cs_policy(root,"migration")
    if(migration) { cs_int(migration,"source_schema","1","1"); cs_string(migration,"source",0); cs_enum(migration,"state","pending|complete",0); cs_generation(migration,"generation") }
}
function cs_epoch(parent,key) { return cs_int(parent,key,"0","9999999999") }
function cs_ipv4(s,    a,n,i) { n=split(s,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function cs_public4(s,    a) { if(!cs_ipv4(s)) return 0; split(s,a,"."); return !(a[1]==0 || a[1]==10 || a[1]==127 || a[1]>=224 || (a[1]==100 && a[2]>=64 && a[2]<=127) || (a[1]==169 && a[2]==254) || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && (a[2]==168 || (a[2]==0 && (a[3]==0 || a[3]==2)))) || (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) || (a[1]==203 && a[2]==0 && a[3]==113)) }
function cs_ipv6(s,    lower,n,a,i,double,groups) {
    lower=tolower(s)
    if(length(s)>39 || s~/[^0-9a-fA-F:]/ || lower!~/^[23][0-9a-f][0-9a-f][0-9a-f]:/ || lower~/^2001:0?db8:/ || s~/:::/) return 0
    double=index(s,"::"); if(double && index(substr(s,double+2),"::")) return 0
    n=split(s,a,":"); groups=0
    for(i=1;i<=n;i++) if(a[i]!="") { if(length(a[i])>4 || a[i]!~/^[0-9a-fA-F]+$/) return 0; groups++ }
    if((substr(s,1,1)==":" && substr(s,1,2)!="::") || (substr(s,length(s),1)==":" && substr(s,length(s)-1)!="::")) return 0
    return double ? groups<8 : groups==8
}
function cs_outcome(item,family,    result,value,id) {
    co_type(item,"object"); result=cs_enum(item,"result","published|verified|removed",0); cs_epoch(item,"at")
    id=co_field(item,"value","string|null")
    if(result=="removed") { if(cfmgr_json_tree_kind[id]!="null") reject() }
    else { value=cs_text(id); if(family=="ipv4" ? !cs_public4(value) : !cs_ipv6(value)) reject() }
}
function cs_event(item) { co_type(item,"object"); cs_enum(item,"result","success|partial|pending|failed",0); cs_enum(item,"reason","auth|storage|recovery|throttle|partial|unavailable|none|network|waiting",0); cs_epoch(item,"at") }
function cs_observation(item,    running,state) {
    co_type(item,"object"); cs_enum(item,"origin","runtime|restored",0); cs_uuid(cs_string(item,"boot_id",0)); cs_epoch(item,"at")
    running=cs_bool(item,"running"); state=cs_enum(item,"connection","connected|waiting|unknown",0)
    if(state=="connected" && !running) reject()
    cs_string(item,"installed_version",0); cs_enum(item,"logging","ready|unavailable|unknown",0); cs_bool(item,"cleanup")
}
function cs_status(record,network,    i,id,item,key,value,source) {
    co_type(record,"object"); cs_version(record); cs_generation(record,"generation")
    if(network) { cs_uuid(cs_string(record,"boot_id",0)); cs_enum(record,"selected_wan","0|1|auto",0) }
    for(i=1;i<=2;i++) {
        key=(i==1 ? "ipv4" : "ipv6"); id=cs_id(record,key)
        if(!id || cfmgr_json_tree_kind[id]=="null") continue
        if(!network) cs_outcome(id,key)
        else {
            co_type(id,"object"); value=cs_string(id,"value",0)
            if(key=="ipv4" ? !cs_public4(value) : !cs_ipv6(value)) reject()
            cs_epoch(id,"at"); cs_enum(id,"source","recorded|interface|discovery",0)
            if(key=="ipv6") cs_bool(id,"eligible")
        }
    }
    id=cs_id(record,"latest"); if(id && cfmgr_json_tree_kind[id]!="null") cs_event(id)
    id=cs_id(record,"observation"); if(id && cfmgr_json_tree_kind[id]!="null") cs_observation(id)
    id=cs_id(record,"events"); if(id) { co_type(id,"array"); for(i=0;(item=co_child[id,"i" i]);i++) cs_event(item) }
}
function cs_history(root,    i,key,wrapper,record) {
    for(i=1;i<=4;i++) {
        key=(i==1 ? "ddns" : (i==2 ? "ip_sync" : (i==3 ? "cloudflared" : "network")))
        wrapper=cs_id(root,key)
        if(!wrapper) { if(i<4) reject(); continue }
        co_type(wrapper,"object|null"); if(cfmgr_json_tree_kind[wrapper]=="null") continue
        record=cs_id(wrapper,"status"); if(record && cfmgr_json_tree_kind[record]!="null") cs_status(record,i==4)
    }
}
function cs_validate(    id,value,policy,request,record,source,branch,commit) {
    # Manager source controls are manual data, admitted even while ignored when
    # developer mode is Off; editing them never performs acquisition.
    source=co_source; value=cs_string(source,"repository",0)
    if(value!~/^https:\/\/github\.com\/[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/ || length(value)>256) reject()
    branch=cs_string(source,"branch",0)
    if(length(branch)>128 || branch!~/^[A-Za-z0-9_.\/-]+$/ || branch~/(^|\/)\.\.?(\/|$)/) reject()
    commit=cs_text(cs_id(source,"commit")); if(commit!="" && (length(commit)!=40 || commit~/[^0-9a-f]/)) reject()
    cs_path(co_manager,"developer_log_directory",1)
    cs_credentials_validate(co_field(1,"credentials","object"))
    cs_ddns(co_field(1,"ddns","object")); cs_sync(co_field(1,"ip_sync","object")); cs_cloud(co_field(1,"cloudflared","object"))
    id=co_field(1,"network","object"); cs_enum(id,"address_family","auto|ipv4|ipv6|dual",0)
    value=co_field(id,"selected_wan","number|null"); if(cfmgr_json_tree_kind[value]!="null") cs_integer(value,"0","1")
    policy=cs_policy(id,"discovery")
    if(policy) { cs_request(policy); value=cs_int(policy,"interval_seconds","60","3600")+0; if(value%60) reject() }
    cs_logging(co_field(1,"logging","object"))
    id=co_field(1,"backup","object"); cs_enum(id,"date_format","DMY|MDY|YMD",1)
    value=co_field(id,"retention","number|null"); if(cfmgr_json_tree_kind[value]!="null") cs_integer(value,"3","5")
    record=cs_policy(id,"last_backup")
    if(record) {
        cs_generation(record,"generation"); cs_epoch(record,"at"); cs_enum(record,"date_format","DMY|MDY|YMD",0)
        cs_string(record,"local_date",0); cs_string(record,"local_time",0); cs_string(record,"timezone",0); cs_string(record,"set_id",0); cs_string(record,"archive_id",0)
    }
    cs_ownership(co_field(1,"ownership","object")); cs_history(co_field(1,"history","object"))
}
function cs_null(parent,key) { if(cfmgr_json_tree_kind[cs_id(parent,key)]!="null") reject() }
function cs_empty(id,    i) { for(i=2;i<=cfmgr_json_tree_count;i++) if(cfmgr_json_tree_parent[i]==id) reject() }
function cs_fresh(    i,key,id,cloud,refs,paths,identity,backup,ownership) {
    if(co_old!="1" || !cs_bool(co_manager,"check_updates") || cs_bool(co_manager,"auto_update") || cs_bool(co_manager,"developer")) reject()
    cs_null(co_manager,"developer_log_directory"); if(cs_text(cs_id(co_source,"commit"))!="") reject()
    for(i=1;i<=3;i++) {
        key=(i==1 ? "ddns" : (i==2 ? "ip_sync" : "cloudflared")); id=cs_id(1,key)
        if(cs_bool(id,"configured") || cs_bool(id,"enabled")) reject()
        if(i<3) {
            cs_null(id,"credential_ref"); cs_empty(cs_id(id,(i==1 ? "records" : "targets")))
            if(cs_string(id,"address_family",0)!="auto") reject()
        }
        id=cs_id(cs_id(1,"logging"),key)
        if(cs_bool(id,"configured") || cs_bool(id,"enabled") || cs_bool(id,"opt_out")) reject()
        cs_null(id,"policy"); cs_null(cs_id(1,"history"),key)
    }
    id=cs_id(1,"ddns"); cs_null(id,"zone_id"); cs_null(id,"primary_hostname"); cs_null(id,"ttl"); cs_null(id,"proxied"); cs_null(id,"timeouts")
    if(cs_int(id,"forced_refresh_days","14","14")!="14") reject()
    id=cs_id(1,"ip_sync"); cs_null(id,"account_id"); cs_null(id,"retry")
    cloud=cs_id(1,"cloudflared"); if(cs_bool(cloud,"installed") || cs_bool(cloud,"maintenance_enabled")) reject()
    cs_null(cloud,"method"); cs_null(cloud,"binary_auto_update"); cs_null(cloud,"readiness"); cs_null(cloud,"watchdog")
    refs=cs_id(cloud,"credential_refs"); cs_null(refs,"runtime"); cs_null(refs,"management"); cs_null(refs,"certificate"); cs_null(refs,"dns")
    paths=cs_id(cloud,"paths"); cs_null(paths,"yaml"); cs_null(paths,"json"); cs_null(paths,"certificate")
    identity=cs_id(cloud,"expected_identity"); cs_null(identity,"account_id"); cs_null(identity,"tunnel_id")
    id=cs_id(1,"network"); cs_null(id,"selected_wan"); cs_null(id,"discovery"); if(cs_string(id,"address_family",0)!="auto") reject()
    backup=cs_id(1,"backup"); cs_null(backup,"destination"); cs_null(backup,"date_format"); cs_null(backup,"retention"); cs_null(backup,"last_backup")
    ownership=cs_id(1,"ownership"); cs_empty(cs_id(ownership,"components")); cs_null(ownership,"migration")
    cs_empty(cs_id(1,"credentials"))
    id=cs_id(cs_id(1,"history"),"network"); if(id && cfmgr_json_tree_kind[id]!="null") reject()
}
