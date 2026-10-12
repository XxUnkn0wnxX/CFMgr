#!/bin/sh
# Fixed native-ash mount-reference child, never a package/task supervisor.
# Recursive redirection frames stay live until explicit identity-checked release.
# Parent loss, malformed messages, EOF and ordinary signals never unwind pins.
set -f
umask 077
[ "$#" -eq 8 ] || exit 2
keeper_context=$1 keeper_owner=$2 keeper_owner_start=$3 keeper_boot=$4
keeper_limit=$5 keeper_awk=$6 keeper_prerequisites=$7 keeper_usleep=$8
# shellcheck disable=SC1090 # Explicit hash-admitted repository identity utility.
. "$keeper_prerequisites" || exit 2
trap '' HUP INT QUIT TERM PIPE USR1 USR2 ALRM
keeper_sequence=0 keeper_count=0 keeper_broken=0

# shellcheck disable=SC2154 # Explicit narrow prerequisite identity import.
keeper_controller() {
	cfmgr_prerequisites_identity "$keeper_owner" || return 1
	if [ "$cfmgr_identity_start" != "$keeper_owner_start" ] || [ "$cfmgr_identity_state" = Z ]; then return 1; fi
	IFS= read -r keeper_current_boot </proc/sys/kernel/random/boot_id || return 1
	[ "$keeper_current_boot" = "$keeper_boot" ]
}

keeper_wait() {
	# FD0 now FIFO; surrounding saved redirection frames retain all mount refs.
	printf '%s %s %s END\n' "$1" "$2" "$3" >"$keeper_context/receipt" || keeper_broken=1
	while :; do
		keeper_command='' keeper_next='' keeper_id='' keeper_extra=''
		if ! IFS=' ' read -r keeper_command keeper_next keeper_id keeper_extra; then
			# O_RDWR prevents normal EOF; retain even if read was interrupted/failed.
			keeper_broken=1
			"$keeper_usleep" 100000 || :
			continue
		fi
		# Canonical decimals before any arithmetic: ash treats 08 as invalid octal.
		case $keeper_next in '' | 0* | *[!0-9]*)
			keeper_broken=1
			continue
			;;
		esac
		case $keeper_id in '' | *[!0-9]* | 0?*)
			keeper_broken=1
			continue
			;;
		esac
		if [ -n "$keeper_extra" ] || [ "${#keeper_next}" -gt 9 ] || [ "${#keeper_id}" -gt 10 ]; then
			keeper_broken=1
			continue
		fi
		if [ "$keeper_next" != "$((keeper_sequence + 1))" ]; then
			keeper_broken=1
			continue
		fi
		keeper_controller || {
			keeper_broken=1
			continue
		}
		keeper_sequence=$keeper_next
		case $keeper_command in
		release)
			[ "$keeper_id" = 0 ] || {
				keeper_broken=1
				continue
			}
			printf 'released %s 0 END\n' "$keeper_sequence" >"$keeper_context/receipt" || {
				keeper_broken=1
				continue
			}
			return 0
			;;
		hold)
			if [ "$keeper_broken" -ne 0 ] || [ "$keeper_id" = 0 ] || [ "$keeper_count" -ge "$keeper_limit" ]; then
				printf 'failed %s %s END\n' "$keeper_sequence" "$keeper_id" >"$keeper_context/receipt" || keeper_broken=1
				continue
			fi
			# Only the verified controller's already-proved FD4 is transferred.
			if keeper_next_frame "$keeper_sequence" "$keeper_id" <"/proc/$keeper_owner/fd/4"; then return 0; fi
			printf 'failed %s %s END\n' "$keeper_sequence" "$keeper_id" >"$keeper_context/receipt" || keeper_broken=1
			;;
		*) keeper_broken=1 ;;
		esac
	done
}

keeper_next_frame() {
	# ACK only inside the frame opened from the controller descriptor.
	# shellcheck disable=SC2016
	if [ -d /proc/self/fd/0 ] || [ -f /proc/self/fd/0 ]; then
		if "$keeper_awk" -v expected="$2" '/^mnt_id:/ { n++; if ($2!=expected) bad=1 } END { exit n!=1 || bad ? 1 : 0 }' "/proc/$$/fdinfo/0"; then
			keeper_count=$((keeper_count + 1))
			keeper_wait held "$1" "$2" <&3
			return $?
		fi
	fi
	# An opened but mismatched object is uncertainty; never unwind its frame.
	keeper_broken=1
	keeper_wait uncertain "$1" "$2" <&3
}

keeper_controller || exit 2
keeper_wait ready 0 0 <&3
