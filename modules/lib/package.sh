#!/bin/sh
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
			required="cfmgr.sh catalog.txt modules/backup.sh modules/manager_settings.sh modules/lib/package.sh modules/lib/acquire.sh modules/lib/config.sh modules/lib/config_store.sh modules/lib/storage.sh modules/lib/prerequisites.sh modules/lib/native.sh modules/lib/mount_keeper.sh modules/lib/execution_view.sh modules/lib/execution_tasks.sh modules/lib/dependencies.sh modules/lib/mountinfo.awk modules/helpers/mount_keeper.sh modules/helpers/dependencies.sh modules/helpers/bootstrap.sh modules/helpers/probe.sh modules/helpers/launch.sh modules/lib/json.awk modules/lib/config_observation.awk modules/lib/config_schema.awk modules/status.sh modules/lib/status.awk modules/lib/status_native.awk"
			n=split(required,names," ");for(i=1;i<=n;i++)if(!seen[names[i]])bad=1
			if(bad || count<2)exit 1
		}' "$cfmgr_source/manifest.txt") || return 1
	cfmgr_package_paths="
$(printf '%s\n' "$cfmgr_package_records" | /usr/bin/awk 'BEGIN{FS="\t"}{print $4}')
"
	cfmgr_package_objects=0
	cfmgr_package_inventory "$cfmgr_source/modules" 0 || return 1
	while IFS="$(printf '\t')" read -r cfmgr_package_mode cfmgr_package_bytes cfmgr_package_sha cfmgr_package_path; do
		case $cfmgr_package_path in cfmgr.sh) cfmgr_package_target=/jffs/scripts/cfmgr.sh ;; *) cfmgr_package_target=$cfmgr_source/$cfmgr_package_path ;; esac
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
