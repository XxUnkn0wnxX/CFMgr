#!/bin/sh
# shellcheck disable=SC1091 # Fixed literal installed imports are admitted below.
# Trusted entry defaults. Fork maintainers change this one source-selection block.
CFMGR_REPOSITORY=https://github.com/XxUnkn0wnxX/CFMgr
CFMGR_BRANCH=develop
CFMGR_VERSION=0.1.0

# Clear loader/config overrides with shell builtins before invoking native tools.
# The interpreter's own startup precedes this boundary; children use env -i too.
unset LD_LIBRARY_PATH LD_PRELOAD LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE \
	LD_ORIGIN_PATH LD_ASSUME_KERNEL LD_BIND_NOW LD_BIND_NOT LD_DYNAMIC_WEAK \
	LD_HWCAP_MASK LD_SHOW_AUXV LD_TRACE_LOADED_OBJECTS GLIBC_TUNABLES \
	GCONV_PATH LOCPATH NLSPATH ENV BASH_ENV CDPATH CURL_HOME CURL_CA_BUNDLE \
	SSL_CERT_FILE SSL_CERT_DIR OPENSSL_CONF OPENSSL_MODULES OPENSSL_ENGINES \
	http_proxy https_proxy all_proxy no_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
PATH=/bin:/usr/bin:/sbin:/usr/sbin
LC_ALL=C LANGUAGE=
export PATH LC_ALL LANGUAGE

# Entry-owned native primitives. Package bytes are never shell input; only
# bounded metadata and fixed digest receipts cross command substitutions.
cfmgr_entry_metadata() {
	[ ! -L "$1" ] && [ "$(/usr/bin/readlink -f "$1")" = "$1" ] || return 1
	# shellcheck disable=SC2016
	cfmgr_entry_size=$(/bin/ls -ldn "$1" | /usr/bin/awk -v kind="$2" '
		NR!=1 || $3!=0 || substr($1,6,1)=="w" || substr($1,9,1)=="w" {bad=1}
		kind=="directory" && (length($1)!=10 || $1!~/^d[rwxstST-]+$/) {bad=1}
		kind!="directory" && ($2!=1 || (kind=="0644" && $1!="-rw-r--r--") || (kind=="0755" && $1!="-rwxr-xr-x") || (kind=="manifest" && $1!="-rw-r--r--") || $5!~/^[0-9]+$/) {bad=1}
		END {if(NR!=1 || bad)exit 1; print $5}') || return 1
}

cfmgr_entry_hash() {
	# One block beyond the declared extent also covers an appended payload.
	cfmgr_entry_blocks=$(($2 / 4096 + 1))
	cfmgr_entry_hash_frame=$(
		{
			{
				/bin/dd bs=4096 count="$cfmgr_entry_blocks" <"$1" 2>/dev/null
				cfmgr_entry_read_status=$?
				printf 'CFMGR-READ 1 %s\n' "$cfmgr_entry_read_status" >&3
			} | /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C OPENSSL_CONF=/dev/null /usr/sbin/openssl dgst -sha256 -r
		} 3>&1
	) || return 1
	# Shells may close the producer pipe before its final redirected receipt.
	# Require both typed records, in either order, including reader success.
	# shellcheck disable=SC2016
	cfmgr_entry_digest=$(printf '%s\n' "$cfmgr_entry_hash_frame" | /usr/bin/awk '
		$0=="CFMGR-READ 1 0" {reader++;next}
		NF==2 && length($1)==64 && $1!~/[^0-9a-f]/ && $2=="*stdin" {digests++;hash=$1;next}
		{bad=1} END {if(NR!=2 || reader!=1 || digests!=1 || bad)exit 1;print hash}') || return 1
}

cfmgr_entry_file() {
	cfmgr_entry_metadata "$1" "$2" && [ "$cfmgr_entry_size" = "$3" ] || return 1
	cfmgr_entry_hash "$1" "$3" && [ "$cfmgr_entry_digest" = "$4" ]
}

cfmgr_entry_framing() {
	# Independent byte and newline counts reject NUL-to-record ambiguity as well
	# as missing final LF. Native awk runs in the byte locale, never a payload AWK.
	cfmgr_entry_counts=$(/usr/bin/wc -lc <"$1") || return 1
	# shellcheck disable=SC2016
	/usr/bin/awk -v counts="$cfmgr_entry_counts" 'BEGIN {split(counts,c); if(c[2]>131072)exit 1}
		{bytes+=length($0)+1} END {exit bytes!=c[2] || NR!=c[1]}' "$1"
}

cfmgr_entry_admit() {
	for cfmgr_entry_dir in / "/jffs" "/jffs/scripts" "/jffs/addons" "$cfmgr_source" "$cfmgr_source/modules" "$cfmgr_source/modules/lib"; do
		cfmgr_entry_metadata "$cfmgr_entry_dir" directory || return 1
	done
	cfmgr_entry_metadata "$cfmgr_source/manifest.txt" manifest && [ "$cfmgr_entry_size" -le 131072 ] || return 1
	cfmgr_entry_framing "$cfmgr_source/manifest.txt" || return 1
	cfmgr_entry_known=$(printf abc | /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C OPENSSL_CONF=/dev/null /usr/sbin/openssl dgst -sha256 -r) || return 1
	[ "$cfmgr_entry_known" = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad *stdin' ] || return 1
	# Only these two fixed records can select bootstrap verification input.
	# shellcheck disable=SC2016
	cfmgr_entry_records=$(/usr/bin/awk -v version="$CFMGR_VERSION" 'BEGIN {FS="\t"}
		NR==1 {if($0!="CFMGR-MANIFEST 1 " version && $0!="CFMGR-MANIFEST 2 " version " 1 2")bad=1;next}
		$4=="cfmgr.sh" || $4=="modules/lib/package.sh" {
			if(NF!=4 || seen[$4]++ || $2!~/^(0|[1-9][0-9]*)$/ || $2>1048576 || length($3)!=64 || $3~/[^0-9a-f]/ || ($4=="cfmgr.sh" && $1!="0755") || ($4=="modules/lib/package.sh" && $1!="0644"))bad=1
			print
		} END {if(bad || !seen["cfmgr.sh"] || !seen["modules/lib/package.sh"])exit 1}' "$cfmgr_source/manifest.txt") || return 1
	while IFS="$(printf '\t')" read -r cfmgr_entry_mode cfmgr_entry_bytes cfmgr_entry_sha cfmgr_entry_path; do
		case $cfmgr_entry_path in cfmgr.sh) cfmgr_entry_target="/jffs/scripts/cfmgr.sh" ;; modules/lib/package.sh) cfmgr_entry_target=$cfmgr_source/modules/lib/package.sh ;; *) return 1 ;; esac
		cfmgr_entry_file "$cfmgr_entry_target" "$cfmgr_entry_mode" "$cfmgr_entry_bytes" "$cfmgr_entry_sha" || return 1
	done <<EOF_RECORDS
$cfmgr_entry_records
EOF_RECORDS
}

# Native fallback deliberately needs no package, configuration or Entware code.
# Pinned ash has no builtin test/printf/echo: only the fixed native output applet
# is executed here. Fixed kernel files and finite reads bound work, not wall time.
cfmgr_entry_health_row() {
	# Shared basic/full row contract: ID STATE DETAIL AGE NEXT [DEPENDENCY].
	# Only short printable projections, never raw source/error bytes, are shown.
	case $# in 5 | 6) ;; *) return 2 ;; esac
	case $1 in '' | *[!A-Za-z0-9._-]*) return 2 ;; esac
	case ${6:-none} in *[!A-Za-z0-9._-]*) return 2 ;; esac
	case $2 in PASS | FAIL | WARN | SKIP | UNKNOWN) ;; *) return 2 ;; esac
	case $3$4$5 in *[!\ -~]*) return 2 ;; esac
	case $((${#1} > 64 || ${#3} > 512 || ${#4} > 64 || ${#5} > 512 || ${#6} > 64)) in 1) return 2 ;; esac
	cfmgr_entry_health_width
	cfmgr_entry_health_wrap "$1 [$2]" || return 1
	cfmgr_entry_health_wrap "  Detail: $3" || return 1
	cfmgr_entry_health_wrap "  Age: $4" || return 1
	cfmgr_entry_health_wrap "  Next: $5" || return 1
	case ${6:-none} in none) ;; *) cfmgr_entry_health_wrap "  Requires: $6" || return 1 ;; esac
}

cfmgr_entry_health_width() {
	cfmgr_health_width=${COLUMNS:-64}
	case $cfmgr_health_width in '' | *[!0-9]* | 0* | ????*) cfmgr_health_width=64 ;; esac
	case $((cfmgr_health_width < 10 || cfmgr_health_width > 100)) in 1) cfmgr_health_width=64 ;; esac
}

cfmgr_entry_health_wrap() {
	cfmgr_health_text=$1 cfmgr_health_chunk= cfmgr_health_column=0
	while :; do
		case $cfmgr_health_text in '') break ;; esac
		cfmgr_health_tail=${cfmgr_health_text#?}
		cfmgr_health_chunk=$cfmgr_health_chunk${cfmgr_health_text%"$cfmgr_health_tail"}
		cfmgr_health_text=$cfmgr_health_tail cfmgr_health_column=$((cfmgr_health_column + 1))
		case $cfmgr_health_column in "$cfmgr_health_width")
			case $cfmgr_health_chunk in
			*' '*)
				cfmgr_health_break=${cfmgr_health_chunk% *}
				cfmgr_health_chunk=${cfmgr_health_chunk##* }
				;;
			*) cfmgr_health_break=$cfmgr_health_chunk cfmgr_health_chunk= ;;
			esac
			/usr/bin/printf '%s\n' "$cfmgr_health_break" || return 1
			cfmgr_health_column=${#cfmgr_health_chunk}
			;;
		esac
	done
	case $cfmgr_health_column in 0) ;; *) /usr/bin/printf '%s\n' "$cfmgr_health_chunk" ;; esac
}

cfmgr_entry_health_decimal() {
	# Only short unsigned kernel decimal projections may reach the terminal.
	case $1 in '' | *[!0-9.]* | *.*.* | .* | *.) return 1 ;; esac
	case $((${#1} > 24)) in 1) return 1 ;; esac
}

cfmgr_entry_health_native() {
	cfmgr_entry_health_width
	/usr/bin/printf '\n' || return 1
	cfmgr_entry_health_wrap "CFMgr $CFMGR_VERSION - health diagnostics" || return 1
	cfmgr_entry_health_wrap 'Native snapshot; extended checks follow only after diagnostic verification.' || return 1
	cfmgr_entry_health_wrap 'This snapshot makes no install, repair, service action or provider request.' || return 1
	cfmgr_entry_health_row system.native PASS 'Trusted native shell and fixed native output are available.' current 'None.' || return 1
	cfmgr_health_uptime= cfmgr_health_idle=
	if { IFS=' ' read -r cfmgr_health_uptime cfmgr_health_idle </proc/uptime; } 2>/dev/null &&
		cfmgr_entry_health_decimal "$cfmgr_health_uptime"; then
		cfmgr_entry_health_row system.uptime PASS "Uptime: $cfmgr_health_uptime seconds." current 'None.' || return 1
	else
		cfmgr_entry_health_row system.uptime UNKNOWN 'Native uptime is unavailable or invalid.' unknown 'Inspect native /proc availability.' || return 1
	fi
	cfmgr_health_load1= cfmgr_health_load5= cfmgr_health_load15= cfmgr_health_rest=
	if { IFS=' ' read -r cfmgr_health_load1 cfmgr_health_load5 cfmgr_health_load15 cfmgr_health_rest </proc/loadavg; } 2>/dev/null &&
		cfmgr_entry_health_decimal "$cfmgr_health_load1" && cfmgr_entry_health_decimal "$cfmgr_health_load5" &&
		cfmgr_entry_health_decimal "$cfmgr_health_load15"; then
		cfmgr_entry_health_row system.load PASS "Load (1/5/15 minutes): $cfmgr_health_load1 / $cfmgr_health_load5 / $cfmgr_health_load15." current 'None.' || return 1
	else
		cfmgr_entry_health_row system.load UNKNOWN 'Native load is unavailable or invalid.' unknown 'Inspect native /proc availability.' || return 1
	fi
	cfmgr_health_total= cfmgr_health_available= cfmgr_health_free= cfmgr_health_lines=0 cfmgr_health_memory_bad=0
	# Old kernels may lack MemAvailable. Report MemFree explicitly in that case;
	# do not relabel free memory as an available-memory estimate.
	{
		while IFS=' ' read -r cfmgr_health_key cfmgr_health_value cfmgr_health_unit cfmgr_health_extra; do
			cfmgr_health_lines=$((cfmgr_health_lines + 1))
			case $cfmgr_health_lines in 49) break ;; esac
			case $cfmgr_health_key in
			MemTotal: | MemAvailable: | MemFree:)
				case $cfmgr_health_value in '' | *[!0-9]* | 0?*)
					cfmgr_health_memory_bad=1
					continue
					;;
				esac
				case $((${#cfmgr_health_value} > 12)) in 1)
					cfmgr_health_memory_bad=1
					continue
					;;
				esac
				case $cfmgr_health_unit:$cfmgr_health_extra in kB:) ;; *)
					cfmgr_health_memory_bad=1
					continue
					;;
				esac
				case $cfmgr_health_key in
				MemTotal:) case $cfmgr_health_total in '') cfmgr_health_total=$cfmgr_health_value ;; *) cfmgr_health_memory_bad=1 ;; esac ;;
				MemAvailable:) case $cfmgr_health_available in '') cfmgr_health_available=$cfmgr_health_value ;; *) cfmgr_health_memory_bad=1 ;; esac ;;
				MemFree:) case $cfmgr_health_free in '') cfmgr_health_free=$cfmgr_health_value ;; *) cfmgr_health_memory_bad=1 ;; esac ;;
				esac
				;;
			esac
		done </proc/meminfo
	} 2>/dev/null
	case $cfmgr_health_total in
	'' | 0) cfmgr_health_memory_bad=1 ;;
	*) case $((${cfmgr_health_available:-0} > cfmgr_health_total || ${cfmgr_health_free:-0} > cfmgr_health_total)) in 1) cfmgr_health_memory_bad=1 ;; esac ;;
	esac
	case $cfmgr_health_memory_bad in 1) cfmgr_health_total= ;; esac
	case $cfmgr_health_total in
	'')
		cfmgr_entry_health_row system.memory UNKNOWN 'Native memory data is unavailable or invalid.' unknown 'Inspect native /proc availability.' || return 1
		;;
	*)
		case $cfmgr_health_available:$cfmgr_health_free in
		:)
			cfmgr_entry_health_row system.memory UNKNOWN 'Native memory data is unavailable or invalid.' unknown 'Inspect native /proc availability.' || return 1
			;;
		:*)
			cfmgr_entry_health_row system.memory WARN "Memory: total $cfmgr_health_total kB; free $cfmgr_health_free kB; available estimate unsupported." current 'Use the free value only as a partial memory observation.' || return 1
			;;
		*)
			cfmgr_entry_health_row system.memory PASS "Memory: total $cfmgr_health_total kB; available $cfmgr_health_available kB." current 'None.' || return 1
			;;
		esac
		;;
	esac
	cfmgr_health_kernel=
	{ IFS= read -r cfmgr_health_kernel </proc/sys/kernel/osrelease; } 2>/dev/null || cfmgr_health_kernel=
	case $cfmgr_health_kernel in '' | *[!A-Za-z0-9._+-]*) cfmgr_health_kernel= ;; esac
	case $((${#cfmgr_health_kernel} > 128)) in 1) cfmgr_health_kernel= ;; esac
	case $cfmgr_health_kernel in
	'') cfmgr_entry_health_row system.kernel UNKNOWN 'Kernel release is unavailable or invalid.' unknown 'Inspect native /proc availability.' || return 1 ;;
	*) cfmgr_entry_health_row system.kernel PASS "Kernel release: $cfmgr_health_kernel." current 'None.' || return 1 ;;
	esac
}

cfmgr_entry_health_admit() {
	# Optional owners are trusted only after this call verifies their exact fixed
	# records. Never accept inherited shell values as admission evidence.
	cfmgr_health_backup=missing cfmgr_health_manager=missing
	cfmgr_health_package=missing cfmgr_health_catalog=missing
	cfmgr_health_problem='Protected installed diagnostic ancestry is unavailable.'
	for cfmgr_entry_dir in / "/jffs" "/jffs/addons" "$cfmgr_source" "$cfmgr_source/modules" "$cfmgr_source/modules/lib" "$cfmgr_source/modules/helpers"; do
		cfmgr_entry_metadata "$cfmgr_entry_dir" directory || return 1
	done
	cfmgr_health_problem='Protected compatible manifest is unavailable or invalid.'
	cfmgr_entry_metadata "$cfmgr_source/manifest.txt" manifest && [ "$cfmgr_entry_size" -le 131072 ] || return 1
	cfmgr_health_manifest_size=$cfmgr_entry_size
	# One finite raw manifest view supplies ALL admission records. Byte accounting
	# rejects NUL/control bytes, extra payload, and missing final LF before any
	# projection enters shell variables. The producer also must finish successfully.
	# shellcheck disable=SC2016
	cfmgr_health_frame=$(
		{
			{
				/bin/dd bs=4096 count=33 <"$cfmgr_source/manifest.txt" 2>/dev/null
				cfmgr_health_read_status=$?
				/usr/bin/printf 'CFMGR-READ 1 %s\n' "$cfmgr_health_read_status" >&3
			} | /usr/bin/awk -v version="$CFMGR_VERSION" -v expected="$cfmgr_health_manifest_size" '
			BEGIN {FS="\t"; required="cfmgr.sh modules/status.sh modules/lib/storage.sh modules/lib/execution.sh modules/lib/config.sh modules/lib/network.sh modules/helpers/worker.sh"; n=split(required,names," ");for(i=1;i<=n;i++)wanted[names[i]]=1}
			{bytes+=length($0)+1;if(bytes>131072 || $0~/[^ -~\t]/)bad=1}
			NR==1 {if($0!="CFMGR-MANIFEST 1 " version && $0!="CFMGR-MANIFEST 2 " version " 1 2")bad=1;next}
			{
				if(NF!=4 || length($0)>512 || $1!~/^0(644|755)$/ || $2!~/^(0|[1-9][0-9]*)$/ || $2>1048576 ||
				length($3)!=64 || $3~/[^0-9a-f]/ || length($4)>256 || $4!~/^[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)*$/ ||
				$4~/(^|\/)(\.|\.\.)(\/|$)/ || seen[$4]++ || (prev!="" && $4<=prev)){bad=1;next}
				if($4!="cfmgr.sh" && $4!="catalog.txt" && $4!~/^modules\//)bad=1
				path=$4;depth=0;while(sub(/\/[^\/]+$/,"",path)){if(seen[path] || ++depth>16)bad=1}
				prev=$4;total+=$2;count++;if(count>512 || total>16777216)bad=1
				if(wanted[$4]){mode=($4=="cfmgr.sh" || $4=="modules/helpers/worker.sh" ? "0755" : "0644");if($1!=mode)bad=1;records[$4]=$0}
				if($4=="modules/backup.sh")backup=$0
				if($4=="modules/manager.sh")manager=$0
				if($4=="modules/lib/package.sh")package=$0
				if($4=="catalog.txt")catalog=$0
			}
			END {for(i=1;i<=n;i++)if(!seen[names[i]])bad=1;if(bad || bytes!=expected)exit 1;for(i=1;i<=n;i++)print records[names[i]];if(backup!="")print backup;if(manager!="")print manager;if(package!="")print package;if(catalog!="")print catalog}'
		} 3>&1
	) || return 1
	# shellcheck disable=SC2016
	cfmgr_health_records=$(/usr/bin/printf '%s\n' "$cfmgr_health_frame" | /usr/bin/awk '
		$0=="CFMGR-READ 1 0" {reader++;next}
		{if(index($0,"\t")==0)bad=1;records[++count]=$0}
		END {
			required="cfmgr.sh modules/status.sh modules/lib/storage.sh modules/lib/execution.sh modules/lib/config.sh modules/lib/network.sh modules/helpers/worker.sh"
			n=split(required,names," ");optional["modules/backup.sh"]=1;optional["modules/manager.sh"]=2;optional["modules/lib/package.sh"]=3;optional["catalog.txt"]=4
			if(bad || reader!=1 || count<n || count>n+4)exit 1
			for(i=1;i<=n;i++){fields_count=split(records[i],fields,"\t");if(fields_count!=4 || fields[4]!=names[i])exit 1}
			last=0;for(i=n+1;i<=count;i++){fields_count=split(records[i],fields,"\t");rank=optional[fields[4]];if(fields_count!=4 || !rank || rank<=last)exit 1;last=rank}
			for(i=1;i<=count;i++)print records[i]
		}') || return 1
	cfmgr_health_problem='Trusted entry does not match the installed diagnostic generation.'
	cfmgr_health_self=$(/usr/bin/readlink -f "$0") || return 1
	[ -f "$0" ] && [ ! -L "$0" ] || return 1
	case $cfmgr_health_self in "/jffs/scripts/cfmgr.sh") cfmgr_entry_metadata "/jffs/scripts" directory || return 1 ;; esac
	cfmgr_entry_known=$(/usr/bin/printf abc | /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C OPENSSL_CONF=/dev/null /usr/sbin/openssl dgst -sha256 -r) || return 1
	[ "$cfmgr_entry_known" = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad *stdin' ] || return 1
	cfmgr_health_required_verified=0
	while IFS='	' read -r cfmgr_entry_mode cfmgr_entry_bytes cfmgr_entry_sha cfmgr_entry_path; do
		case $cfmgr_entry_path in
		cfmgr.sh) cfmgr_entry_target=$cfmgr_health_self ;;
		modules/status.sh | modules/lib/storage.sh | modules/lib/execution.sh | modules/lib/config.sh | modules/lib/network.sh | modules/helpers/worker.sh)
			cfmgr_entry_target=$cfmgr_source/$cfmgr_entry_path
			cfmgr_health_problem="Diagnostic member missing or untrusted: $cfmgr_entry_path."
			;;
		modules/backup.sh)
			cfmgr_entry_target=$cfmgr_source/modules/backup.sh
			cfmgr_health_backup=untrusted
			[ "$cfmgr_entry_mode" = 0644 ] || continue
			;;
		modules/manager.sh)
			cfmgr_entry_target=$cfmgr_source/modules/manager.sh
			cfmgr_health_manager=untrusted
			[ "$cfmgr_entry_mode" = 0644 ] || continue
			;;
		modules/lib/package.sh)
			cfmgr_entry_target=$cfmgr_source/modules/lib/package.sh
			cfmgr_health_package=untrusted
			[ "$cfmgr_entry_mode" = 0644 ] || continue
			;;
		catalog.txt)
			cfmgr_entry_target=$cfmgr_source/catalog.txt
			cfmgr_health_catalog=untrusted
			[ "$cfmgr_entry_mode" = 0644 ] || continue
			;;
		*) return 1 ;;
		esac
		if ! cfmgr_entry_file "$cfmgr_entry_target" "$cfmgr_entry_mode" "$cfmgr_entry_bytes" "$cfmgr_entry_sha" 2>/dev/null; then
			case $cfmgr_entry_path in modules/backup.sh | modules/manager.sh | modules/lib/package.sh | catalog.txt) continue ;; *) return 1 ;; esac
		fi
		case $cfmgr_entry_path in
		cfmgr.sh | modules/status.sh | modules/lib/storage.sh | modules/lib/execution.sh | modules/lib/config.sh | modules/lib/network.sh | modules/helpers/worker.sh) cfmgr_health_required_verified=$(($cfmgr_health_required_verified + 1)) ;;
		modules/backup.sh) cfmgr_health_backup=verified ;;
		modules/manager.sh) cfmgr_health_manager=verified ;;
		modules/lib/package.sh) cfmgr_health_package=verified ;;
		catalog.txt) cfmgr_health_catalog=verified ;;
		esac
	done <<EOF_HEALTH_RECORDS
$cfmgr_health_records
EOF_HEALTH_RECORDS
	[ "$cfmgr_health_required_verified" -eq 7 ] || return 1
}

cfmgr_entry_health() (
	# Emit useful independent observations before optional, finite native admission.
	cfmgr_entry_health_native || exit 1
	cfmgr_source="/jffs/addons/CFMgr.d"
	if ! cfmgr_entry_health_admit 2>/dev/null; then
		cfmgr_entry_health_row package.extension FAIL "$cfmgr_health_problem" current 'Use a complete trusted compatible package for extended checks.' || exit 1
		cfmgr_entry_health_row config.validation SKIP 'Diagnostic extension unavailable; configuration was not read.' unknown 'Resolve package verification first.' package.extension || exit 1
		cfmgr_entry_health_row network.readiness SKIP 'Trusted local prerequisites unavailable; no network request was made.' unknown 'Resolve package verification first.' package.extension || exit 1
		cfmgr_entry_health_row features.validation SKIP 'Feature credentials and runtime state were not inspected.' unknown 'Resolve package verification first.' package.extension
		exit $?
	fi
	. "$cfmgr_source/modules/lib/storage.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution.sh" || exit 1
	. "$cfmgr_source/modules/lib/network.sh" || exit 1
	. "$cfmgr_source/modules/lib/config.sh" || exit 1
	. "$cfmgr_source/modules/status.sh" || exit 1
	cfmgr_status_health_native
)

case ${1-} in
--health | --doctor | --diagnostic)
	case $# in 1) ;; *) exit 2 ;; esac
	cfmgr_entry_health
	exit $?
	;;
--version)
	[ "$#" -eq 1 ] || exit 2
	printf 'CFMgr %s (development placeholder)\n' "$CFMGR_VERSION"
	exit 0
	;;
--help | '')
	[ "$#" -le 1 ] || exit 2
	cfmgr_default_entry=
	if [ "$#" -eq 0 ] && { [ -e "/jffs/scripts/cfmgr.sh" ] || [ -L "/jffs/scripts/cfmgr.sh" ]; }; then
		cfmgr_default_entry=$(/usr/bin/readlink -f "$0") || exit 1
	fi
	if [ "$#" -eq 0 ] && [ "$cfmgr_default_entry" = "/jffs/scripts/cfmgr.sh" ]; then
		[ -f "$0" ] && [ ! -L "$0" ] || exit 1
		exec /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
			CFMGR_INTERNAL_LAUNCH=1 /bin/sh "$cfmgr_default_entry" --internal-launch
	fi
	printf '%s\n' 'CFMgr: --install (trusted complete local package), --install-remote, --version, --help.' \
		'Diagnostics: --health (--doctor or --diagnostic); read-only native fallback works without installation.' \
		'Remote install requires a trusted COMPLETE local bootstrap and uses its one configured repository/branch.' \
		'Installed package: --reinstall-dependencies (interactive confirmation required).' \
		'Fresh base installation checks and repairs required Entware tools. Other feature operations remain unavailable.'
	if [ -e "/jffs/addons/CFMgr.d" ] || [ -L "/jffs/addons/CFMgr.d" ]; then
		printf '%s\n' 'An installed or retained package exists; fresh installation will not reset it. Recovery/update is not implemented.'
	fi
	exit 0
	;;
--reinstall-dependencies)
	[ "$#" -eq 1 ] || exit 2
	cfmgr_default_entry=$(/usr/bin/readlink -f "$0") || exit 1
	[ "$cfmgr_default_entry" = "/jffs/scripts/cfmgr.sh" ] && [ -f "$0" ] && [ ! -L "$0" ] || {
		printf '[CFMGR] dependencies: error: use the installed entry\n' >&2
		exit 1
	}
	exec /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
		CFMGR_INTERNAL_LAUNCH=1 /bin/sh "/jffs/scripts/cfmgr.sh" --internal-launch reinstall
	;;
--internal-launch)
	[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ "${CFMGR_INTERNAL_LAUNCH-}" = 1 ] && [ "$0" = "/jffs/scripts/cfmgr.sh" ] || exit 2
	cfmgr_entry_action=${2:-normal}
	case $cfmgr_entry_action in normal | reinstall) ;; *) exit 2 ;; esac
	cfmgr_source="/jffs/addons/CFMgr.d"
	if ! cfmgr_entry_admit; then
		printf '[CFMGR] launch: error: installed package verification failed\n' >&2
		exit 1
	fi
	. "$cfmgr_source/modules/lib/package.sh" || exit 1
	if ! cfmgr_package_verify; then
		printf '[CFMGR] launch: error: installed package verification failed\n' >&2
		exit 1
	fi
	# Explicit category imports define functions only.
	# shellcheck disable=SC1091
	. "$cfmgr_source/modules/lib/storage.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution.sh" || exit 1
	. "$cfmgr_source/modules/lib/network.sh" || exit 1
	. "$cfmgr_source/modules/lib/config.sh" || exit 1
	if [ "$cfmgr_entry_action" = normal ] && [ -t 0 ]; then
		. "$cfmgr_source/modules/status.sh" || exit 1
		. "$cfmgr_source/modules/backup.sh" || exit 1
		. "$cfmgr_source/modules/manager.sh" || exit 1
		if cfmgr_launch_menu; then cfmgr_entry_action=reinstall; else exit 0; fi
	fi
	if cfmgr_launch_native "$cfmgr_source" "$cfmgr_entry_action"; then exit 0; else cfmgr_entry_status=$?; fi
	[ "$cfmgr_entry_status" -ne 4 ] || exit 0
	printf '[CFMGR] launch: error: retained launch blocked or incomplete\n' >&2
	exit 1
	;;
--install | --install-remote)
	[ "$#" -eq 1 ] || exit 2
	if [ -e "/jffs/addons/CFMgr.d" ] || [ -L "/jffs/addons/CFMgr.d" ] || [ -e "/jffs/scripts/cfmgr.sh" ] || [ -L "/jffs/scripts/cfmgr.sh" ]; then
		printf '%s\n' 'Existing or retained CFMgr installation: recovery/update required; fresh defaults were not generated.' >&2
		exit 1
	fi
	cfmgr_entry=$(/usr/bin/readlink -f "$0") || exit 1
	case $cfmgr_entry in /*/cfmgr.sh) ;; *) exit 1 ;; esac
	cfmgr_internal_install=--internal-install
	[ "$1" != --install-remote ] || cfmgr_internal_install=--internal-install-remote
	exec /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
		CFMGR_INTERNAL_INSTALL=1 /bin/sh "$cfmgr_entry" "$cfmgr_internal_install"
	;;
--internal-install | --internal-install-remote)
	[ "$#" -eq 1 ] && [ "${CFMGR_INTERNAL_INSTALL-}" = 1 ] || exit 2
	cfmgr_entry=$(/usr/bin/readlink -f "$0") || exit 1
	case $cfmgr_entry in /*/cfmgr.sh) ;; *) exit 1 ;; esac
	cfmgr_source=${cfmgr_entry%/*}
	# Only explicit trusted-package imports. Configuration is never sourced.
	# shellcheck disable=SC1091
	. "$cfmgr_source/modules/lib/storage.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution.sh" || exit 1
	. "$cfmgr_source/modules/lib/network.sh" || exit 1
	. "$cfmgr_source/modules/lib/package.sh" || exit 1
	cfmgr_entry_status=1
	if [ "$1" = --internal-install-remote ]; then
		# Acquisition is trusted bootstrap code; downloaded helpers remain inert
		# until its complete package/compatibility/syntax gate has passed.
		if cfmgr_acquire_native "$cfmgr_source"; then cfmgr_entry_status=0; else cfmgr_entry_status=$?; fi
	else
		if cfmgr_bootstrap_native "$cfmgr_source"; then cfmgr_entry_status=0; fi
	fi
	if [ "$cfmgr_entry_status" = 0 ]; then
		printf '%s\n' 'CFMgr fresh installation complete.'
		exit 0
	fi
	printf '%s\n' 'CFMgr installation blocked or incomplete; existing data was not reset. Recovery may be required.' >&2
	exit "$cfmgr_entry_status"
	;;
*)
	printf '%s\n' 'Unsupported command; use --help.' >&2
	exit 2
	;;
esac
