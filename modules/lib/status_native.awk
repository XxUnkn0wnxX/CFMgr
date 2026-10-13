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
