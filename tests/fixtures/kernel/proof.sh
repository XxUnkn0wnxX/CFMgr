#!/bin/sh
# Linux namespace-only fixture: actual native tools, no router execution.
# shellcheck disable=SC2154,SC2034
set -eu
[ "$#" -eq 6 ] || exit 2
repo=$1 work=$2 bb=$3 parent_mount=$4 parent_pid=$5 scenario=$6
fail() {
	printf 'kernel fixture failed: %s\n' "$*" >&2
	printf 'scenario=%s status=%s\n' "${scenario-unset}" "${status-unset}" >&2
	# Failure-only evidence from fixed owned metadata, never root/Opt contents.
	if [ -n "${ram-}" ] && [ -n "${bb-}" ]; then
		diagnostic_guard=$ram/cfmgr-isolation
		if [ -d "$diagnostic_guard" ] && [ ! -L "$diagnostic_guard" ]; then
			printf 'guard=reserved\n' >&2
			diagnostic_queries=0
			for diagnostic_name in active intent-null intent-opt mounted-null mounted-opt \
				query-0 query-1 query-2 query-3 query-4 query-5 query-6 query-7 \
				query-8 query-9 query-10 query-11 query-12 query-13 query-14 query-15; do
				diagnostic_file=$diagnostic_guard/$diagnostic_name
				if [ -f "$diagnostic_file" ] && [ ! -L "$diagnostic_file" ]; then
					printf '%s (at most 4096 bytes):\n' "$diagnostic_name" >&2
					# shellcheck disable=SC2016
					"$bb" awk 'BEGIN { left = 4096 }
						{ line = $0 "\n"; if (length(line) > left) {
							printf "%s\n[truncated]\n", substr(line, 1, left); exit
						} printf "%s", line; left -= length(line); if (!left) exit }' \
						"$diagnostic_file" >&2 || printf 'metadata read failed\n' >&2
					case $diagnostic_name in query-*) diagnostic_queries=$((diagnostic_queries + 1)) ;; esac
				else
					printf '%s=absent-or-not-regular\n' "$diagnostic_name" >&2
				fi
			done
			printf 'query files present=%s\n' "$diagnostic_queries" >&2
		else
			printf 'guard=absent-or-not-owned-directory\n' >&2
		fi
	fi
	if [ -n "${work-}" ] && [ -n "${bb-}" ]; then
		printf 'mountinfo scoped to fixture work path (at most 32 rows):\n' >&2
		# shellcheck disable=SC2016
		CFMGR_KERNEL_WORK=$work "$bb" awk '
			BEGIN {
				path = ENVIRON["CFMGR_KERNEL_WORK"]; escaped = ""
				for (i = 1; i <= length(path); i++) {
					char = substr(path, i, 1)
					if (char == " ") char = "\\040"
					else if (char == "\t") char = "\\011"
					else if (char == "\n") char = "\\012"
					else if (char == "\\") char = "\\134"
					escaped = escaped char
				}
			}
			$5 == escaped || index($5, escaped "/") == 1 {
				print substr($0, 1, 8192); if (++rows == 32) exit
			}' /proc/self/mountinfo >&2 || printf 'mountinfo read failed\n' >&2
	fi
	exit 1
}
[ "$$" -eq 1 ] || fail 'fixture is not namespace init'
[ "$("$bb" readlink /proc/self/ns/mnt)" != "$parent_mount" ] || fail 'host mount namespace'
[ "$("$bb" readlink /proc/self/ns/pid)" != "$parent_pid" ] || fail 'host PID namespace'
# util-linux made propagation private before mounting this namespace's proc.
# No fixture mount happens until both namespace checks above have passed.
ram=$work/ram source=$work/source tools=$work/tools
"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$ram"
# shellcheck source=/dev/null
. "$repo/modules/io.sh"
# shellcheck source=/dev/null
. "$repo/modules/storage.sh"
# shellcheck source=/dev/null
. "$repo/modules/isolation.sh"

wait_ready() {
	attempt=0
	while [ ! -s "$1" ]; do
		[ "$attempt" -lt 80 ] || fail 'readiness deadline'
		"$bb" sleep 0.05
		attempt=$((attempt + 1))
	done
	[ "$("$bb" cat "$1")" = ready ] || fail 'invalid readiness'
}
hex() { printf '%s' "$1" | "$bb" hexdump -v -e '1/1 "%02x"'; }
verify_mounts() {
	# Actual checked mount parser, followed by exact bindpoint/private assertions.
	verify_root=$2
	point=$verify_root/opt
	_cfmgr_io_mount_capture "$point" "$repo/modules/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ] || return 1
	point_hex=$(hex "$point") || return 1
	saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$saved_ifs
	[ "$6" = "$point_hex" ] && "$bb" test "$source" -ef "$point"
}
verify_null() {
	verify_root=$2
	_cfmgr_io_mount_capture "$2/dev/null" "$repo/modules/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ] || return 1
	point_hex=$(hex "$2/dev/null") || return 1
	saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$saved_ifs
	[ "$6" = "$point_hex" ] && "$bb" test /dev/null -ef "$verify_root/dev/null"
}
check_binds() {
	cfmgr_io_test "$ram" "$tools" workspace verify_mounts "$1" || fail 'Opt binding/topology'
	cfmgr_io_test "$ram" "$tools" workspace verify_null "$1" || fail 'null binding/topology'
}

if [ "$scenario" != primitive ]; then
	_isolation_root=$ram
	_isolation_tools=$tools
	_isolation_parser=$repo/modules/mountinfo.awk
	_isolation_input=/proc/self/mountinfo
	guard=$ram/cfmgr-isolation
	# Callbacks below are invoked indirectly by the isolation owner.
	# shellcheck disable=SC2317,SC2329
	fixture_enter() {
		_cfmgr_io_mount_capture "$source" "$_isolation_parser" /proc/self/mountinfo 0 1 || return 1
		saved_ifs=$IFS
		IFS=$_io_tab
		# shellcheck disable=SC2086
		set -- $_mount_body
		IFS=$saved_ifs
		# Only UUID is synthetic: this lane does not establish block identity.
		volume=$(printf 'volume\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t00000000-0000-0000-0000-000000000001' "$2" "$4" "$7" "$5" "$6" "${11}" "$9" "${10}")$_io_lf
		volume="${volume}end$_io_tab${#volume}$_io_lf"
		# Read-only retained inputs; neither redirection is an output target.
		# shellcheck disable=SC2094
		_cfmgr_isolation_begin "$source" "$volume" fixture_callback 9<"$source" 8<"$source/sentinel"
	}
	# shellcheck disable=SC2317,SC2329
	fixture_callback() {
		"$bb" test "$source" -ef /proc/self/fd/9 || return 1
		"$bb" test "$source/sentinel" -ef /proc/self/fd/8 || return 1
		check_binds "$1"
		case $scenario in
		busy)
			printf '%s\n' "$1/opt/sentinel" >&7
			wait_ready "$ram/holder-ready"
			;;
		signal)
			"$source/probe" signal-parent
			# Prevent a shell tail-exec from replacing the actual callback owner.
			:
			;;
		success) ;;
		*) return 2 ;;
		esac
	}
	if [ "$scenario" = busy ]; then
		"$bb" mkfifo "$ram/control"
		"$source/probe" holder "$ram/control" "$ram/holder-ready" &
		holder=$!
		exec 7>"$ram/control"
	fi
	status=0
	cfmgr_io_test "$ram" "$tools" workspace fixture_enter || status=$?
	case $scenario in
	success)
		if [ "$status" -ne 0 ] || [ -e "$guard" ]; then
			fail 'product success/guard cleanup'
		fi
		# Namespace discard must not conceal a mount left by product cleanup.
		! "$bb" grep -F "$guard/" /proc/self/mountinfo || fail 'success left a bind'
		;;
	busy | signal)
		if [ "$scenario" = busy ]; then
			if [ "$status" -ne 1 ] || [ -e "$guard/active" ]; then
				fail 'busy result'
			fi
		else
			if [ "$status" -ne 143 ] || [ "$("$bb" cat "$guard/active")" != callback ]; then
				fail 'interrupted active result'
			fi
		fi
		[ -d "$guard" ] || fail 'failure guard missing'
		check_binds "$guard/root"
		if [ "$scenario" = busy ]; then
			printf x >&7
			exec 7>&-
			wait "$holder" || fail 'exact holder wait'
		fi
		# Intentionally retained mounts die with this namespace, not product cleanup.
		;;
	esac
	printf 'lifecycle %s passed\n' "$scenario"
	exit 0
fi

# Direct primitive proof only: no runtime callback admits chroot or ELF here.
root=$ram/primitive
"$bb" mkdir -m 700 "$root" "$root/opt" "$root/dev" "$root/bootstrap"
: >"$root/dev/null"
exec 9<"$source" 8<"$source/sentinel"
"$bb" mount -n -i -o bind /dev/null "$root/dev/null"
"$bb" mount -n -i -o make-private "$root/dev/null"
"$bb" mount -n -i -o bind /proc/self/fd/9 "$root/opt"
"$bb" mount -n -i -o make-private "$root/opt"
check_binds "$root"
"$bb" cp "$work/dynamic" "$root/bootstrap/probe"
for mode in static dynamic; do
	if [ "$mode" = static ]; then executable=/opt/probe; else executable=/bootstrap/probe; fi
	"$bb" chroot "$root" "$executable" check 8<&- 9<&-
	"$bb" mkfifo "$ram/control-$mode"
	"$bb" chroot "$root" "$executable" wait <"$ram/control-$mode" >"$ram/ready-$mode" 8<&- 9<&- &
	actor=$!
	exec 7>"$ram/control-$mode"
	wait_ready "$ram/ready-$mode"
	[ "$("$bb" readlink "/proc/$actor/cwd")" = "$root" ] || fail 'Opt cwd holder'
	for fd in /proc/"$actor"/fd/*; do
		link=$("$bb" readlink "$fd") || fail 'actor descriptor inspection'
		case $link in "$root/opt" | "$root/opt/"*) fail 'extra Opt file holder' ;; esac
	done
	if [ "$mode" = static ]; then
		"$bb" grep -F "$root/opt/probe" "/proc/$actor/maps" >/dev/null || fail 'static Opt executable mapping'
	else
		"$bb" grep -F "$root/opt/loader" "/proc/$actor/maps" >/dev/null || fail 'Opt interpreter mapping'
		"$bb" grep -F "$root/opt/libc.so.6" "/proc/$actor/maps" >/dev/null || fail 'Opt libc mapping'
	fi
	if "$bb" umount -D -n "$root/opt"; then fail 'mapped Opt unmount unexpectedly succeeded'; fi
	check_binds "$root"
	printf x >&7
	exec 7>&-
	wait "$actor" || fail 'exact mapped actor wait'
	"$bb" umount -D -n "$root/opt"
	"$bb" umount -D -n "$root/dev/null"
	! "$bb" grep -F "$root/opt" /proc/self/mountinfo || fail 'Opt removal unproved'
	! "$bb" grep -F "$root/dev/null" /proc/self/mountinfo || fail 'null removal unproved'
	printf 'primitive %s passed\n' "$mode"
	if [ "$mode" = static ]; then
		"$bb" mount -n -i -o bind /dev/null "$root/dev/null"
		"$bb" mount -n -i -o make-private "$root/dev/null"
		"$bb" mount -n -i -o bind /proc/self/fd/9 "$root/opt"
		"$bb" mount -n -i -o make-private "$root/opt"
	fi
done
exec 8<&- 9<&-
