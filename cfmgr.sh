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
	for cfmgr_entry_dir in / /jffs /jffs/scripts /jffs/addons "$cfmgr_source" "$cfmgr_source/modules" "$cfmgr_source/modules/lib"; do
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
		case $cfmgr_entry_path in cfmgr.sh) cfmgr_entry_target=/jffs/scripts/cfmgr.sh ;; modules/lib/package.sh) cfmgr_entry_target=$cfmgr_source/modules/lib/package.sh ;; *) return 1 ;; esac
		cfmgr_entry_file "$cfmgr_entry_target" "$cfmgr_entry_mode" "$cfmgr_entry_bytes" "$cfmgr_entry_sha" || return 1
	done <<EOF_RECORDS
$cfmgr_entry_records
EOF_RECORDS
}

case ${1-} in
--version)
	[ "$#" -eq 1 ] || exit 2
	printf 'CFMgr %s (development placeholder)\n' "$CFMGR_VERSION"
	exit 0
	;;
--help | '')
	[ "$#" -le 1 ] || exit 2
	cfmgr_default_entry=
	if [ "$#" -eq 0 ] && { [ -e /jffs/scripts/cfmgr.sh ] || [ -L /jffs/scripts/cfmgr.sh ]; }; then
		cfmgr_default_entry=$(/usr/bin/readlink -f "$0") || exit 1
	fi
	if [ "$#" -eq 0 ] && [ "$cfmgr_default_entry" = /jffs/scripts/cfmgr.sh ]; then
		[ -f "$0" ] && [ ! -L "$0" ] || exit 1
		exec /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
			CFMGR_INTERNAL_LAUNCH=1 /bin/sh "$cfmgr_default_entry" --internal-launch
	fi
	printf '%s\n' 'CFMgr: --install (trusted complete local package), --install-remote, --version, --help.' \
		'Remote install requires a trusted COMPLETE local bootstrap and uses its one configured repository/branch.' \
		'Installed package: --reinstall-dependencies (interactive confirmation required).' \
		'Fresh base installation checks and repairs required Entware tools. Other feature operations remain unavailable.'
	if [ -e /jffs/addons/CFMgr.d ] || [ -L /jffs/addons/CFMgr.d ]; then
		printf '%s\n' 'An installed or retained package exists; fresh installation will not reset it. Recovery/update is not implemented.'
	fi
	exit 0
	;;
--reinstall-dependencies)
	[ "$#" -eq 1 ] || exit 2
	cfmgr_default_entry=$(/usr/bin/readlink -f "$0") || exit 1
	[ "$cfmgr_default_entry" = /jffs/scripts/cfmgr.sh ] && [ -f "$0" ] && [ ! -L "$0" ] || {
		printf '[CFMGR] dependencies: error: use the installed entry\n' >&2
		exit 1
	}
	exec /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
		CFMGR_INTERNAL_LAUNCH=1 /bin/sh /jffs/scripts/cfmgr.sh --internal-launch reinstall
	;;
--internal-launch)
	[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ "${CFMGR_INTERNAL_LAUNCH-}" = 1 ] && [ "$0" = /jffs/scripts/cfmgr.sh ] || exit 2
	cfmgr_entry_action=${2:-normal}
	case $cfmgr_entry_action in normal | reinstall) ;; *) exit 2 ;; esac
	cfmgr_source=/jffs/addons/CFMgr.d
	if ! cfmgr_entry_admit; then
		printf '[CFMGR] launch: error: installed package verification failed\n' >&2
		exit 1
	fi
	. "$cfmgr_source/modules/lib/package.sh" || exit 1
	if ! cfmgr_package_verify; then
		printf '[CFMGR] launch: error: installed package verification failed\n' >&2
		exit 1
	fi
	if [ "$cfmgr_entry_action" = normal ] && [ -t 0 ]; then
		# shellcheck disable=SC1091
		. "$cfmgr_source/modules/lib/prerequisites.sh" || exit 1
		. "$cfmgr_source/modules/status.sh" || exit 1
		. "$cfmgr_source/modules/lib/storage.sh" || exit 1
		. "$cfmgr_source/modules/lib/config_store.sh" || exit 1
		. "$cfmgr_source/modules/backup.sh" || exit 1
		. "$cfmgr_source/modules/manager_settings.sh" || exit 1
		. "$cfmgr_source/modules/helpers/launch.sh" || exit 1
		if cfmgr_launch_menu; then cfmgr_entry_action=reinstall; else exit 0; fi
	fi
	# shellcheck disable=SC1091
	. "$cfmgr_source/modules/lib/storage.sh" || exit 1
	. "$cfmgr_source/modules/lib/prerequisites.sh" || exit 1
	. "$cfmgr_source/modules/lib/native.sh" || exit 1
	. "$cfmgr_source/modules/lib/config_store.sh" || exit 1
	. "$cfmgr_source/modules/lib/mount_keeper.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution_view.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution_tasks.sh" || exit 1
	. "$cfmgr_source/modules/lib/dependencies.sh" || exit 1
	. "$cfmgr_source/modules/helpers/bootstrap.sh" || exit 1
	. "$cfmgr_source/modules/helpers/launch.sh" || exit 1
	if cfmgr_launch_native "$cfmgr_source" "$cfmgr_entry_action"; then exit 0; else cfmgr_entry_status=$?; fi
	[ "$cfmgr_entry_status" -ne 4 ] || exit 0
	printf '[CFMGR] launch: error: retained launch blocked or incomplete\n' >&2
	exit 1
	;;
--install | --install-remote)
	[ "$#" -eq 1 ] || exit 2
	if [ -e /jffs/addons/CFMgr.d ] || [ -L /jffs/addons/CFMgr.d ] || [ -e /jffs/scripts/cfmgr.sh ] || [ -L /jffs/scripts/cfmgr.sh ]; then
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
	. "$cfmgr_source/modules/lib/prerequisites.sh" || exit 1
	. "$cfmgr_source/modules/lib/native.sh" || exit 1
	. "$cfmgr_source/modules/lib/mount_keeper.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution_view.sh" || exit 1
	. "$cfmgr_source/modules/lib/execution_tasks.sh" || exit 1
	. "$cfmgr_source/modules/lib/dependencies.sh" || exit 1
	. "$cfmgr_source/modules/helpers/bootstrap.sh" || exit 1
	cfmgr_entry_status=1
	if [ "$1" = --internal-install-remote ]; then
		# Acquisition is trusted bootstrap code; downloaded helpers remain inert
		# until its complete package/compatibility/syntax gate has passed.
		. "$cfmgr_source/modules/lib/acquire.sh" || exit 1
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
