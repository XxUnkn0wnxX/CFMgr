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
case "$mode" in
launch-config-check | launch-config-observe | launch-config-patch)
	case "$mode:$#" in launch-config-check:4 | launch-config-observe:8 | launch-config-patch:8) ;; *) exit 2 ;; esac
	case $1 in '' | *[!0-9]*) exit 2 ;; esac
	[ "${#1}" -le 5 ] && [ "$1" -le 65536 ] || exit 2
	for path in "$2" "$3" "$4"; do
		case $path in /*) ;; *) exit 2 ;; esac
		[ -f "$path" ] && [ ! -L "$path" ] || exit 2
	done
	config_mode=${mode#launch-config-}
	if [ "$config_mode" != check ]; then
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
		[ -d "$1" ] && [ ! -L "$1" ] && [ "$1" -ef /proc/self/fd/4 ] || exit 2
		exec "$tool" "$1"
		;;
	esac
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
install-sha | install-wc | install-ls | install-config-check | install-mkdir-private | install-mkdir-public | install-chmod-private | install-chmod-readonly | install-chmod-executable | install-df)
	[ "$#" -eq 1 ] || exit 2
	case "$1" in /*) ;; *) exit 2 ;; esac
	case "$mode" in
	install-sha) exec "$tool" <"$1" ;;
	install-wc) exec "$tool" -c <"$1" ;;
	install-ls) exec "$tool" -ldn "$1" ;;
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
