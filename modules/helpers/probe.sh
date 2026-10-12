#!/bin/sh
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
	[ -r /proc/self/stat ] || exec "$1" 0.3
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
	exec "$native_sleep" 0.3
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
