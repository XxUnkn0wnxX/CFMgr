#!/bin/sh
# Fixed in-view installed-opkg launch handshake. No arbitrary command/data eval.
# FD9 is the copied regular script handoff, FD0 gate, FD1 bounded phase receipt.
set -f
umask 077
[ "$#" -eq 3 ] || exit 2
# shellcheck disable=SC2034 # All three explicit native paths are admitted as launch ABI.
awk=$1 readlink=$2 usleep=$3
for tool; do
	case $tool in /*) ;; *) exit 2 ;; esac
	[ -f "$tool" ] && [ -x "$tool" ] || exit 2
done
cd / || exit 2
script_fd=''
# ash opened its script with CLOEXEC before running the first command.
set +f
for fdinfo in /proc/self/fdinfo/*; do
	fd=${fdinfo##*/}
	case $fd in '' | *[!0-9]*) exit 2 ;; esac
	[ "$fd" -ge 10 ] || continue
	# shellcheck disable=SC3013 # Real held regular-file identity, not a pathname claim.
	if [ "/proc/$$/fd/$fd" -ef /proc/self/fd/9 ] && [ -f "/proc/$$/fd/$fd" ]; then
		[ -z "$script_fd" ] || exit 2
		script_fd=$fd
	else exit 2; fi
done
set -f
[ -n "$script_fd" ] || exit 2
exec 9<&-
audit() {
	# Parent descriptor namespace: external native AWK must inspect the ash PID,
	# not /proc/self (which would identify AWK rather than the launch helper).
	(
		set +f
		for audit_info in /proc/"$$"/fdinfo/*; do
			audit_fd=${audit_info##*/}
			case $audit_fd in 0 | 1 | 2) continue ;; esac
			[ "$audit_fd" = "$script_fd" ] && [ -f "/proc/$$/fd/$audit_fd" ] || exit 2
			# shellcheck disable=SC2016
			"$awk" '/^flags:/ { n++; f=$2; p=length(f)-6; if (f !~ /^[0-7]+$/ || p<1 || substr(f,p,1) !~ /^[2367]$/) bad=1 }
			  END { exit n!=1 || bad ? 1 : 0 }' "$audit_info" || exit 2
		done
	)
}
audit || exit 2
printf 'ready END\n'
IFS=' ' read -r request end extra || exit 2
[ "$request:$end:$extra" = query:END: ] || exit 2
# No package data is constrained by this status-query-only file-size limit.
opkg() (
	PATH=/opt/bin:/opt/sbin:/bin:/usr/bin:/sbin:/usr/sbin
	export PATH
	exec /opt/bin/opkg "$@"
)
if opkg --version </dev/null >/dev/null 2>/dev/null; then :; else
	code=$?
	printf 'failed version %s END\n' "$code"
	exit 1
fi
for package in jq jq-full coreutils-timeout coreutils-sha256sum flock bind-dig; do
	printf 'status %s BEGIN\n' "$package"
	# Pinned opkg status accepts only its first operand. Query each fixed name.
	if (ulimit -f 128 && opkg status "$package" </dev/null) 2>/dev/null; then query_exit=0; else query_exit=$?; fi
	printf '\nstatus %s %s END\n' "$package" "$query_exit"
	[ "$query_exit" -eq 0 ] || exit 1
done
printf 'queried 0 END\n'
# Fixed capped selection comes only from the controller after status validation.
IFS= read -r request || exit 2
[ "${#request}" -le 256 ] || exit 2
old_ifs=$IFS
IFS=' '
# Finite tokens become argv, never shell code or arbitrary paths.
# shellcheck disable=SC2086
set -- $request
IFS=$old_ifs
[ "$#" -ge 3 ] && [ "$#" -le 7 ] && [ "$1" = repair ] || exit 2
shift
install='' reinstall=''
while [ "$#" -gt 1 ]; do
	case $1 in
	i-jq | i-jq-full | i-coreutils-timeout | i-coreutils-sha256sum | i-flock | i-bind-dig) install="$install ${1#i-}" ;;
	r-jq | r-jq-full | r-coreutils-timeout | r-coreutils-sha256sum | r-flock | r-bind-dig) reinstall="$reinstall ${1#r-}" ;;
	*) exit 2 ;;
	esac
	shift
done
[ "$1" = END ] || exit 2
exec 0</dev/null
audit || exit 2
printf 'update BEGIN\n'
if opkg update >/dev/null 2>/dev/null; then :; else
	code=$?
	printf 'failed update %s END\n' "$code"
	exit 1
fi
if [ -n "$install" ]; then
	old_ifs=$IFS
	IFS=' '
	# shellcheck disable=SC2086
	set -- $install
	IFS=$old_ifs
	printf 'install BEGIN\n'
	if opkg install "$@" >/dev/null 2>/dev/null; then :; else
		code=$?
		printf 'failed install %s END\n' "$code"
		exit 1
	fi
fi
if [ -n "$reinstall" ]; then
	old_ifs=$IFS
	IFS=' '
	# shellcheck disable=SC2086
	set -- $reinstall
	IFS=$old_ifs
	printf 'reinstall BEGIN\n'
	if opkg --force-reinstall install "$@" >/dev/null 2>/dev/null; then :; else
		code=$?
		printf 'failed reinstall %s END\n' "$code"
		exit 1
	fi
fi
printf 'complete 0 END\n'
