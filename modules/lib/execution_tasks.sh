#!/bin/sh
# Source-inert task/root supervision for an admitted, lifetime-pinned view.
# All tools/code/contexts are explicit controller-admitted native operands.
# shellcheck disable=SC2034,SC2154,SC2016 # Fixed imported/result fields and literal AWK programs.
# Never signal from a retired ledger, unknown root, or partially read thread group.

_cfmgr_tasks_now() {
	IFS=' ' read -r cfmgr_tasks_clock cfmgr_tasks_idle </proc/uptime || return 3
	cfmgr_tasks_now=${cfmgr_tasks_clock%%.*}
	case $cfmgr_tasks_now in '' | *[!0-9]*) return 3 ;; esac
}

# Arbitrary tasks need a distinct parser: stat comm is not trusted shell data.
# A malformed/unreadable live identity is unknown, not an exclusion.
# shellcheck disable=SC2016
_cfmgr_tasks_identity() {
	# Capture complete LF-terminated proc records before AWK; getline alone
	# cannot distinguish a truncated final record on the supported AWK variants.
	cfmgr_tasks_stat_lines=0 cfmgr_tasks_stat_bytes=0 cfmgr_tasks_stat_tail=''
	: >"$cfmgr_tasks_context/stat.raw" || return 3
	{
		while IFS= read -r cfmgr_tasks_stat_tail; do
			cfmgr_tasks_stat_lines=$((cfmgr_tasks_stat_lines + 1))
			cfmgr_tasks_stat_bytes=$((cfmgr_tasks_stat_bytes + ${#cfmgr_tasks_stat_tail} + 1))
			[ "$cfmgr_tasks_stat_lines" -le 17 ] && [ "$cfmgr_tasks_stat_bytes" -le 4096 ] || return 3
			printf '%s\n' "$cfmgr_tasks_stat_tail" >>"$cfmgr_tasks_context/stat.raw" || return 3
			cfmgr_tasks_stat_tail=''
		done
		[ -z "$cfmgr_tasks_stat_tail" ] || return 3
	} 2>/dev/null <"$1/stat" || return 3
	"$cfmgr_tasks_awk" '
		{ bytes+=length($0)+1; if (bytes>4096 || NR>17) bad=1
		  record=record (NR==1 ? "" : "\n") $0 }
		END { if (bad || NR<1 || record !~ /^[1-9][0-9]* \(/) exit 1
		  pid=record; sub(/ .*/,"",pid)
		  tail=record; sub(/^.*\) /,"",tail); n=split(tail,a,/ +/)
		  if (tail==record || n<20 || a[1] !~ /^[RSDZTtXxKWPI]$/ ||
		    a[2] !~ /^[0-9]+$/ || a[7] !~ /^[0-9]+$/ || a[20] !~ /^[1-9][0-9]*$/) exit 1
		  for (i=2;i<=n;i++) if (a[i] !~ /^-?[0-9]+$/) exit 1
		  print pid,a[20],a[1],a[2],a[7] }
	' "$cfmgr_tasks_context/stat.raw" >"$cfmgr_tasks_context/identity" 2>/dev/null || return 3
	IFS=' ' read -r cfmgr_tasks_tid cfmgr_tasks_start cfmgr_tasks_identity_state cfmgr_tasks_parent cfmgr_tasks_flags <"$cfmgr_tasks_context/identity" || return 3
}

# Only actual CLOEXEC regular shell bookkeeping is allowed above the known I/O.
# Kernel fdinfo incorporates FD_CLOEXEC; checking original open flags is insufficient.
# shellcheck disable=SC2016
cfmgr_execution_tasks_fd_admit() (
	[ "$#" -eq 2 ] || exit 2
	set +f
	for cfmgr_tasks_fdinfo in /proc/"$1"/fdinfo/*; do
		cfmgr_tasks_fd=${cfmgr_tasks_fdinfo##*/}
		case $cfmgr_tasks_fd in '' | *[!0-9]*) exit 3 ;; esac
		[ "$cfmgr_tasks_fd" -ge 10 ] || continue
		[ -f "/proc/$1/fd/$cfmgr_tasks_fd" ] && [ ! -d "/proc/$1/fd/$cfmgr_tasks_fd" ] || exit 2
		"$2" '/^flags:/ { n++; f=$2; p=length(f)-6; if (f !~ /^[0-7]+$/ || p<1 || substr(f,p,1) !~ /^[2367]$/) bad=1 }
		  END { exit n!=1 || bad ? 1 : 0 }' "$cfmgr_tasks_fdinfo" || exit 2
	done
)

_cfmgr_tasks_pin() {
	# Actual opened root on FD4; dedup is safe only while all old refs remain held.
	cfmgr_mount_keeper_check 0 || return 3
	# shellcheck disable=SC2016
	if "$cfmgr_tasks_awk" -v id="$1" '$1==id { found=1 } END { exit found ? 0 : 1 }' "$cfmgr_keeper_context/pins"; then return 0; fi
	cfmgr_mount_keeper_retain "$1" || return 3
}

# Root classification requires positive ancestry, never pathname spelling.
# The per-task namespace inventory also permits positively foreign host tasks in
# the isolated CI namespace. Same unique scaffold/guard filesystem outside its
# known ancestry is ambiguous and cannot be classified foreign.
# shellcheck disable=SC2016
_cfmgr_tasks_classify() {
	"$cfmgr_tasks_awk" -F '\t' '
		BEGIN { id=ARGV[1]; root=ARGV[5]; guard=ARGV[6]; ARGV[1]=ARGV[4]=ARGV[5]=ARGV[6]="" }
		FILENAME==ARGV[2] { own[$1]=1; if ($5==root || $5==guard) unique[$3]=1; next }
		FILENAME==ARGV[3] { parent[$1]=$2; dev[$1]=$3; point[$1]=$5; next }
		END { if (id in own) { print "owned"; exit }
		  cursor=id; for (n=0;n<4096;n++) {
		    if (cursor in own) { print "dynamic"; exit }
		    if (!(cursor in parent) || seen[cursor]++ || dev[cursor] in unique) exit 1
		    if (!(parent[cursor] in parent)) { if (point[cursor]!="/") exit 1; print "foreign"; exit }
		    cursor=parent[cursor]
		  }; exit 1 }
	' "$1" "$cfmgr_view_context/expected.mounts" "$2" ignored "$cfmgr_view_root" "$cfmgr_view_guard" >"$cfmgr_tasks_context/class" || return 3
	IFS= read -r cfmgr_tasks_class <"$cfmgr_tasks_context/class" || return 3
}

# Borrow/restore FD4 to reopen the current task root before accepting the row.
# shellcheck disable=SC2016
_cfmgr_tasks_root_again() {
	"$cfmgr_tasks_awk" -v expected="$1" '/^mnt_id:/ { n++; if ($2!=expected) bad=1 } END { exit n!=1 || bad ? 1 : 0 }' /proc/self/fdinfo/4
}

_cfmgr_tasks_thread() {
	# TGID TASK_DIRECTORY; caller groups every live thread before signal admission.
	_cfmgr_tasks_identity "$2" || return 3
	cfmgr_tasks_before=$cfmgr_tasks_tid:$cfmgr_tasks_start
	case $cfmgr_tasks_identity_state in Z | X | x) return 0 ;; esac
	# Positive PF_KTHREAD exclusion; zero/unreadable flags are not an exclusion.
	if "$cfmgr_tasks_awk" -v flags="$cfmgr_tasks_flags" 'BEGIN { exit int(flags/2097152)%2 ? 0 : 1 }'; then return 0; fi
	# Keep a missing-root open failure inside the compound command; exec is a
	# POSIX special builtin and its failing redirection can otherwise exit ash.
	if { exec 4<&0; } 2>/dev/null <"$2/root"; then :; else return 3; fi
	"$cfmgr_tasks_awk" '/^mnt_id:/ { n++; if (NF!=2 || $2 !~ /^[1-9][0-9]*$/) bad=1; id=$2 }
	  END { if (n!=1 || bad) exit 1; print id }' /proc/self/fdinfo/4 >"$cfmgr_tasks_context/root.id" || {
		exec 4<&-
		return 3
	}
	IFS= read -r cfmgr_tasks_root_id <"$cfmgr_tasks_context/root.id" || {
		exec 4<&-
		return 3
	}
	# Use the held-ID classification cache only after the sweep's keeper proof.
	# Newly visible descendants were reconciled before this scan.
	if ! "$cfmgr_tasks_awk" -F '\t' -v id="$cfmgr_tasks_root_id" '
	  FILENAME==ARGV[1] && $1==id { owned=1 }
	  FILENAME==ARGV[2] && $1==id { foreign=1 }
	  END { if (owned) print "owned"; else if (foreign) print "foreign"; else exit 1 }
	' "$cfmgr_view_context/expected.mounts" "$cfmgr_tasks_context/foreign.ids" >"$cfmgr_tasks_context/class"; then
		# Use the full controller namespace, never a chroot-filtered task inventory.
		# New root mounts need another complete reconciliation while FD4 holds the
		# actual object. If it detached before registration, ancestry is unknown.
		if ! cfmgr_execution_view_reconcile; then
			exec 4<&-
			return 3
		fi
		if ! _cfmgr_tasks_classify "$cfmgr_tasks_root_id" "$cfmgr_view_context/all.mounts"; then
			exec 4<&-
			return 3
		fi
	else IFS= read -r cfmgr_tasks_class <"$cfmgr_tasks_context/class" || {
		exec 4<&-
		return 3
	}; fi
	if ! _cfmgr_tasks_identity "$2"; then
		exec 4<&-
		return 3
	fi
	[ "$cfmgr_tasks_before" = "$cfmgr_tasks_tid:$cfmgr_tasks_start" ] || {
		exec 4<&-
		return 3
	}
	case $cfmgr_tasks_class in owned | foreign) ;; *)
		exec 4<&-
		return 3
		;;
	esac
	# Only a new ID needs a protocol transfer/full keeper scan. All existing IDs
	# remain referenced by the keeper proved at the start/end of this sweep.
	if ! "$cfmgr_tasks_awk" -v id="$cfmgr_tasks_root_id" '$1==id { found=1 } END { exit found ? 0 : 1 }' "$cfmgr_keeper_context/pins"; then
		if ! _cfmgr_tasks_pin "$cfmgr_tasks_root_id"; then
			exec 4<&-
			return 3
		fi
		if [ "$cfmgr_tasks_class" = foreign ]; then printf '%s\n' "$cfmgr_tasks_root_id" >>"$cfmgr_tasks_context/foreign.ids" || {
			exec 4<&-
			return 3
		}; fi
	fi
	if ! _cfmgr_tasks_root_again "$cfmgr_tasks_root_id" 4<"$2/root"; then
		exec 4<&-
		return 3
	fi
	exec 4<&-
	if ! _cfmgr_tasks_identity "$2"; then return 3; fi
	[ "$cfmgr_tasks_before" = "$cfmgr_tasks_tid:$cfmgr_tasks_start" ] || return 3
	case $cfmgr_tasks_class in
	owned) printf '%s %s %s owned %s\n' "$1" "$cfmgr_tasks_tid" "$cfmgr_tasks_start" "$cfmgr_tasks_group_start" >>"$cfmgr_tasks_context/${cfmgr_tasks_rows:-sweep}" || return 3 ;;
	foreign) printf '%s %s %s foreign %s\n' "$1" "$cfmgr_tasks_tid" "$cfmgr_tasks_start" "$cfmgr_tasks_group_start" >>"$cfmgr_tasks_context/${cfmgr_tasks_rows:-sweep}" || return 3 ;;
	*) return 3 ;;
	esac
}

# Complete fresh all-TGID/TID sweep. Unknown/exiting observations are retried as
# whole snapshots, with a finite deadline, never converted into a partial success.
cfmgr_execution_tasks_sweep() {
	[ "$cfmgr_view_pin_state" = active ] || return 3
	_cfmgr_tasks_now || return 3
	cfmgr_tasks_sweep_deadline=$((cfmgr_tasks_now + 5))
	case ${cfmgr_tasks_cleanup_deadline:-} in
	[0-9]*) if [ "$cfmgr_tasks_cleanup_deadline" -lt "$cfmgr_tasks_sweep_deadline" ]; then cfmgr_tasks_sweep_deadline=$cfmgr_tasks_cleanup_deadline; fi ;;
	esac
	if [ "${cfmgr_tasks_state:-none}" = running ] && [ -z "${cfmgr_tasks_cleanup_deadline:-}" ]; then
		[ "$cfmgr_tasks_deadline" -ge "$cfmgr_tasks_sweep_deadline" ] || cfmgr_tasks_sweep_deadline=$cfmgr_tasks_deadline
	fi
	while :; do
		cfmgr_mount_keeper_check 0 || return 3
		cfmgr_execution_view_reconcile || return 3
		: >"$cfmgr_tasks_context/sweep" || return 3
		# Proc task names are bounded numeric kernel entries, not executable data.
		cfmgr_tasks_glob=on
		case $- in *f*) cfmgr_tasks_glob=off ;; esac
		set +f
		cfmgr_tasks_total=0 cfmgr_tasks_snapshot=0 cfmgr_tasks_rows=sweep
		for cfmgr_tasks_group in /proc/[0-9]*/task; do
			[ -d "$cfmgr_tasks_group" ] || continue
			cfmgr_tasks_tgid=${cfmgr_tasks_group%/task}
			cfmgr_tasks_tgid=${cfmgr_tasks_tgid##*/}
			if ! _cfmgr_tasks_identity "/proc/$cfmgr_tasks_tgid"; then
				cfmgr_tasks_snapshot=3
				break
			fi
			cfmgr_tasks_group_start=$cfmgr_tasks_start
			for cfmgr_tasks_thread_dir in "$cfmgr_tasks_group"/[0-9]*; do
				[ -d "$cfmgr_tasks_thread_dir" ] || continue
				_cfmgr_tasks_now || {
					cfmgr_tasks_snapshot=3
					break
				}
				if [ "$cfmgr_tasks_now" -ge "$cfmgr_tasks_sweep_deadline" ]; then
					cfmgr_tasks_snapshot=3
					break
				fi
				cfmgr_tasks_total=$((cfmgr_tasks_total + 1))
				if [ "$cfmgr_tasks_total" -gt 8192 ]; then
					cfmgr_tasks_snapshot=3
					break
				fi
				if _cfmgr_tasks_thread "$cfmgr_tasks_tgid" "$cfmgr_tasks_thread_dir"; then :; else
					cfmgr_tasks_snapshot=3
					break
				fi
			done
			[ "$cfmgr_tasks_snapshot" -eq 0 ] || break
			if ! _cfmgr_tasks_identity "/proc/$cfmgr_tasks_tgid"; then
				cfmgr_tasks_snapshot=3
				break
			fi
			if [ "$cfmgr_tasks_group_start" != "$cfmgr_tasks_start" ]; then
				cfmgr_tasks_snapshot=3
				break
			fi
		done
		if [ "$cfmgr_tasks_glob" = off ]; then set -f; fi
		[ "$cfmgr_tasks_snapshot" -ne 0 ] || break
		_cfmgr_tasks_now || return 3
		[ "$cfmgr_tasks_now" -lt "$cfmgr_tasks_sweep_deadline" ] || return 3
		"$cfmgr_tasks_usleep" 50000 || return 3
	done
	cfmgr_mount_keeper_check 0 || return 3
	# Mixed groups cannot authorize group signals, even if one thread is owned.
	# shellcheck disable=SC2016
	"$cfmgr_tasks_awk" '{ if ($4=="owned") owned[$1]=1; else foreign[$1]=1 }
	  END { for (p in owned) if (p in foreign) exit 1; for (p in owned) print p }' "$cfmgr_tasks_context/sweep" >"$cfmgr_tasks_context/owned" || return 3
}

# CONTEXT ENV CHROOT NATIVE_ASH COPIED_HELPER AWK READLINK USLEEP
# Followed by four in-view native tool paths: ASH AWK READLINK USLEEP.
cfmgr_execution_tasks_start() {
	[ "$#" -eq 12 ] && [ "$cfmgr_view_state" = ready ] || return 2
	case ${cfmgr_tasks_state:-none} in running | retained) return 3 ;; esac
	cfmgr_tasks_cleanup_deadline='' cfmgr_tasks_loss=0 cfmgr_tasks_action_refused=0
	cfmgr_tasks_context=$1 cfmgr_tasks_env=$2 cfmgr_tasks_chroot=$3 cfmgr_tasks_shell=$4 cfmgr_tasks_helper=$5
	cfmgr_tasks_awk=$6 cfmgr_tasks_readlink=$7 cfmgr_tasks_usleep=$8 cfmgr_tasks_inside_shell=$9
	shift 9
	cfmgr_tasks_inside_awk=$1 cfmgr_tasks_inside_readlink=$2 cfmgr_tasks_inside_usleep=$3
	cfmgr_tasks_parser=$cfmgr_view_parser
	cfmgr_prerequisites_identity "$$" || return 2
	cfmgr_tasks_owner=$$ cfmgr_tasks_owner_start=$cfmgr_identity_start
	IFS= read -r cfmgr_tasks_boot </proc/sys/kernel/random/boot_id || return 2
	cfmgr_execution_tasks_fd_admit "$$" "$cfmgr_tasks_awk" || return 2
	cfmgr_execution_tasks_native fifo "$cfmgr_tasks_context/gate" || return $?
	(
		umask 077
		set -C
		: >"$cfmgr_tasks_context/receipt"
		[ -f "$cfmgr_tasks_context/foreign.ids" ] && [ ! -L "$cfmgr_tasks_context/foreign.ids" ] && [ ! -s "$cfmgr_tasks_context/foreign.ids" ]
	) || return 2
	exec 4<>"$cfmgr_tasks_context/gate" || return 3
	cfmgr_tasks_state=retained
	"$cfmgr_tasks_env" -i PATH="${cfmgr_tasks_inside_shell%/*}:/bin:/usr/bin:/sbin:/usr/sbin" LC_ALL=C OPENSSL_CONF=/dev/null \
		"$cfmgr_tasks_chroot" "$cfmgr_view_root" "$cfmgr_tasks_inside_shell" /proc/self/fd/9 \
		"$cfmgr_tasks_inside_awk" "$cfmgr_tasks_inside_readlink" "$cfmgr_tasks_inside_usleep" \
		0<&4 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<"$cfmgr_tasks_helper" \
		>"$cfmgr_tasks_context/receipt" 2>/dev/null &
	cfmgr_tasks_pid=$!
	cfmgr_prerequisites_identity "$cfmgr_tasks_pid" || return 3
	cfmgr_tasks_direct_start=$cfmgr_identity_start
	cfmgr_tasks_state=running
	_cfmgr_tasks_now || return 3
	cfmgr_tasks_deadline=$((cfmgr_tasks_now + 120))
	case ${cfmgr_dependencies_operation_deadline:-} in
	[0-9]*) [ "$cfmgr_dependencies_operation_deadline" -ge "$cfmgr_tasks_deadline" ] || cfmgr_tasks_deadline=$cfmgr_dependencies_operation_deadline ;;
	esac
	cfmgr_execution_tasks_receipt ready || return 3
	# The launch helper is a direct child, and actual root FD proves the view.
	cfmgr_prerequisites_identity "$cfmgr_tasks_pid" || return 3
	[ "$cfmgr_identity_start:$cfmgr_identity_parent" = "$cfmgr_tasks_direct_start:$cfmgr_tasks_owner" ] || return 3
	# shellcheck disable=SC3013 # Actual mount-root identity is a Linux contract.
	[ "/proc/$cfmgr_tasks_pid/root" -ef "$cfmgr_view_root" ] || return 3
	_cfmgr_tasks_action_admit || return $?
	printf 'query END\n' >&4 || return 3
	cfmgr_execution_tasks_receipt queried || return 3
}

_cfmgr_tasks_direct() {
	if cfmgr_prerequisites_identity "$cfmgr_tasks_pid"; then :; else
		# A still-visible identity failure is unknown, never an exit receipt.
		[ ! -e "/proc/$cfmgr_tasks_pid" ] && [ ! -L "/proc/$cfmgr_tasks_pid" ] || return 3
		return 1
	fi
	[ "$cfmgr_identity_start:$cfmgr_identity_parent" = "$cfmgr_tasks_direct_start:$cfmgr_tasks_owner" ] || return 3
	IFS= read -r cfmgr_tasks_current_boot </proc/sys/kernel/random/boot_id || return 3
	[ "$cfmgr_tasks_current_boot" = "$cfmgr_tasks_boot" ] || return 3
}

# Observe the action budget before accepting a receipt or releasing a gate.
# Cleanup has its own deadline and deliberately remains available after refusal.
_cfmgr_tasks_action_admit() {
	if [ "${cfmgr_install_interrupted:-0}" != 0 ]; then
		cfmgr_tasks_action_refused=1
		return 1
	fi
	_cfmgr_tasks_now || return 3
	if [ "$cfmgr_tasks_now" -ge "$cfmgr_tasks_deadline" ]; then
		cfmgr_tasks_action_refused=1
		return 1
	fi
	if ! cfmgr_storage_attached; then
		cfmgr_tasks_loss=1 cfmgr_tasks_action_refused=1
		cfmgr_execution_tasks_event storage-lost || return 3
		return 1
	fi
}

# Fixed receipt states; writes may be temporarily partial, never accepted partial.
# shellcheck disable=SC2016
cfmgr_execution_tasks_receipt() {
	while :; do
		_cfmgr_tasks_action_admit || return $?
		if "$cfmgr_tasks_awk" -v phase="$1" '
		  length($0)>4096 || NR>512 || $0 ~ /[^ -~\t]/ { bad=1 }
		  $0=="ready END" && phase=="ready" { found=1 }
		  $0 ~ /^queried [0-9]+ END$/ && phase=="queried" { found=1 }
		  END { exit bad || !found ? 1 : 0 }' "$cfmgr_tasks_context/receipt"; then
			_cfmgr_tasks_action_admit
			return $?
		fi
		_cfmgr_tasks_direct || return $?
		case $cfmgr_identity_state in Z | X | x) return 1 ;; esac
		"$cfmgr_tasks_usleep" 50000 || return 3
	done
}

cfmgr_execution_tasks_run() {
	[ "$#" -eq 1 ] && [ "$cfmgr_tasks_state" = running ] || return 2
	if _cfmgr_tasks_action_admit; then :; else
		cfmgr_tasks_admission_code=$?
		[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
		cfmgr_execution_tasks_finish || return 3
		return 1
	fi
	cfmgr_execution_view_recheck || return 3
	# A long recheck may finish after interruption, expiry or attachment loss.
	if _cfmgr_tasks_action_admit; then :; else
		cfmgr_tasks_admission_code=$?
		[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
		cfmgr_execution_tasks_finish || return 3
		return 1
	fi
	printf 'repair %s END\n' "$1" >&4 || return 3
	exec 4<&-
	cfmgr_tasks_exit=1
	while :; do
		if _cfmgr_tasks_action_admit; then :; else
			cfmgr_tasks_admission_code=$?
			[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
			break
		fi
		if _cfmgr_tasks_direct; then
			case $cfmgr_identity_state in Z | X | x)
				if _cfmgr_tasks_action_admit; then :; else
					cfmgr_tasks_admission_code=$?
					[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
				fi
				break
				;;
			esac
		else
			cfmgr_tasks_direct_code=$?
			[ "$cfmgr_tasks_direct_code" -eq 1 ] || return 3
			if _cfmgr_tasks_action_admit; then :; else
				cfmgr_tasks_admission_code=$?
				[ "$cfmgr_tasks_admission_code" -ne 3 ] || return 3
			fi
			break
		fi
		cfmgr_execution_tasks_sweep || return 3
		"$cfmgr_tasks_usleep" 100000 || return 3
	done
	# Direct completion does not establish descendant quiescence. Do not test the
	# old action deadline after separately bounded cleanup of a timely completion.
	if cfmgr_execution_tasks_finish; then
		if ! cfmgr_storage_attached; then
			cfmgr_tasks_loss=1
			cfmgr_execution_tasks_event storage-lost || return 3
		fi
		[ "${cfmgr_install_interrupted:-0}" = 0 ] && [ "$cfmgr_tasks_action_refused:$cfmgr_tasks_loss" = 0:0 ] || return 1
		return "$cfmgr_tasks_exit"
	else return $?; fi
}

# Immediately re-prove the complete target thread group and start generation.
# No signal is sent for a positively vanished group; every live unknown retains.
_cfmgr_tasks_signal_admit() {
	[ -d "/proc/$1" ] || return 1
	cfmgr_mount_keeper_check 0 || return 3
	cfmgr_execution_view_reconcile || return 3
	_cfmgr_tasks_identity "/proc/$1" || return 3
	cfmgr_tasks_group_start=$cfmgr_tasks_start
	# shellcheck disable=SC2016
	"$cfmgr_tasks_awk" -v pid="$1" -v start="$cfmgr_tasks_group_start" '$1==pid && $5!=start { bad=1 } END { exit bad ? 1 : 0 }' "$cfmgr_tasks_context/sweep" || return 3
	cfmgr_tasks_rows=signal
	: >"$cfmgr_tasks_context/signal" || return 3
	cfmgr_tasks_glob=on
	case $- in *f*) cfmgr_tasks_glob=off ;; esac
	set +f
	cfmgr_tasks_signal_code=0
	for cfmgr_tasks_signal_thread in /proc/"$1"/task/[0-9]*; do
		[ -d "$cfmgr_tasks_signal_thread" ] || continue
		_cfmgr_tasks_now || {
			cfmgr_tasks_signal_code=3
			break
		}
		[ "$cfmgr_tasks_now" -lt "$cfmgr_tasks_cleanup_deadline" ] || {
			cfmgr_tasks_signal_code=3
			break
		}
		if _cfmgr_tasks_thread "$1" "$cfmgr_tasks_signal_thread"; then :; else
			cfmgr_tasks_signal_code=3
			break
		fi
	done
	if [ "$cfmgr_tasks_glob" = off ]; then set -f; fi
	cfmgr_tasks_rows=sweep
	[ "$cfmgr_tasks_signal_code" -eq 0 ] || return 3
	_cfmgr_tasks_identity "/proc/$1" || return 3
	[ "$cfmgr_tasks_start" = "$cfmgr_tasks_group_start" ] || return 3
	# shellcheck disable=SC2016
	"$cfmgr_tasks_awk" '$4!="owned" { bad=1 } END { exit bad || NR<1 ? 1 : 0 }' "$cfmgr_tasks_context/signal" || return 3
}

cfmgr_execution_tasks_finish() {
	exec 4<&-
	cfmgr_tasks_survivors=0
	_cfmgr_tasks_now || return 3
	cfmgr_tasks_cleanup_deadline=$((cfmgr_tasks_now + 10))
	cfmgr_dependencies_operation_deadline=$cfmgr_tasks_cleanup_deadline
	cfmgr_keeper_outer_deadline=$cfmgr_tasks_cleanup_deadline
	while :; do
		cfmgr_execution_tasks_sweep || {
			cfmgr_tasks_state=retained
			return 3
		}
		if [ ! -s "$cfmgr_tasks_context/owned" ]; then break; fi
		cfmgr_tasks_survivors=1
		_cfmgr_tasks_now || return 3
		[ "$cfmgr_tasks_now" -lt "$cfmgr_tasks_cleanup_deadline" ] || {
			cfmgr_tasks_state=retained
			return 3
		}
		# A second complete sweep immediately precedes each observational numeric
		# group signal. No parent/PGID shortcut and no foreign lifetime pin authority.
		cfmgr_execution_tasks_sweep || return 3
		while IFS= read -r cfmgr_tasks_signal_pid; do
			cfmgr_tasks_signal=TERM
			if [ "$cfmgr_tasks_now" -ge "$((cfmgr_tasks_cleanup_deadline - 5))" ]; then cfmgr_tasks_signal=KILL; fi
			if _cfmgr_tasks_signal_admit "$cfmgr_tasks_signal_pid"; then
				cfmgr_execution_tasks_native signal "$cfmgr_tasks_signal_pid" "$cfmgr_tasks_signal" || return 3
			else
				cfmgr_tasks_signal_code=$?
				[ "$cfmgr_tasks_signal_code" -eq 1 ] || return 3
			fi
		done <"$cfmgr_tasks_context/owned"
		"$cfmgr_tasks_usleep" 100000 || return 3
	done
	# An empty owned-root sweep cannot prove a pre-chroot launch child exited.
	# Do not block in wait or adopt/signal a live child with an unproved root.
	if _cfmgr_tasks_direct; then
		case $cfmgr_identity_state in Z | X | x) ;; *)
			cfmgr_tasks_state=retained
			return 3
			;;
		esac
	else
		cfmgr_tasks_direct_code=$?
		[ "$cfmgr_tasks_direct_code" -eq 1 ] || {
			cfmgr_tasks_state=retained
			return 3
		}
	fi
	if wait "$cfmgr_tasks_pid"; then cfmgr_tasks_exit=0; else cfmgr_tasks_exit=$?; fi
	[ "$cfmgr_tasks_survivors" = 0 ] || cfmgr_tasks_exit=1
	cfmgr_tasks_state=quiescent cfmgr_tasks_cleanup_deadline=''
}

cfmgr_execution_tasks_quiescent() {
	[ "${cfmgr_tasks_state:-none}" = quiescent ] || return 3
	cfmgr_execution_tasks_sweep || return 3
	[ ! -s "$cfmgr_tasks_context/owned" ]
}
