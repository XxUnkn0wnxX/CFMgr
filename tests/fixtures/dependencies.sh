#!/bin/sh
# Included only by the real ext4/private PID+mount namespace fixture. Synthetic
# opkg reproduces one-name status and normal update/install dispatch. All mount,
# keeper, root ownership, cancellation and installed flock behavior are real.
# shellcheck disable=SC2034,SC2154,SC3013
[ "${dependency_pid_namespace:-}" != "$("$readlink" /proc/self/ns/pid)" ] || fail 'dependency fixture needs its own PID namespace'
[ "$("$readlink" /proc/1/ns/pid)" = "$("$readlink" /proc/self/ns/pid)" ] || fail 'dependency fixture needs matching private procfs'
view_prepare
# Fixed synthetic phase evidence survives loss of the private tmpfs/namespace.
# This file contains no arguments, package/config data, or trusted ownership input.
(
	umask 077
	set -C
	: >"$fixture/dependency.trace"
) || fail 'could not exclusively create fixture trace'
dependency_trace_count=0
IFS=' ' read -r dependency_trace_clock dependency_trace_idle </proc/uptime || fail 'could not read diagnostic clock'
dependency_trace_started=${dependency_trace_clock%%.*}
dependency_trace() {
	[ -f "$fixture/dependency.trace" ] && [ ! -L "$fixture/dependency.trace" ] || return 1
	[ "$dependency_trace_count" -lt 999999 ] || return 1
	dependency_trace_count=$((dependency_trace_count + 1))
	IFS=' ' read -r dependency_trace_clock dependency_trace_idle </proc/uptime || return 1
	dependency_trace_elapsed=$((${dependency_trace_clock%%.*} - dependency_trace_started))
	printf 'elapsed=%s probes=%s counter=%s stage=%s mode=%s code=%s phase=%s view=%s sequence=%s pending=%s keeper=%s pins=%s probe=%s status=%s reason=%s exit=%s\n' \
		"$dependency_trace_elapsed" "${cfmgr_probe_serial:-0}" "$dependency_trace_count" "$1" "$2" "${3:-unset}" "${cfmgr_dependencies_phase:-unset}" \
		"${cfmgr_view_state:-unset}" "${cfmgr_view_sequence:-0}" "${cfmgr_view_pending:-none}" \
		"${cfmgr_keeper_state:-unset}" "${cfmgr_keeper_count:-0}" "${cfmgr_probe_mode:-unset}" \
		"${cfmgr_probe_status:-unset}" "${cfmgr_probe_reason:-none}" "${cfmgr_probe_exit:-unset}" >"$fixture/dependency.trace"
}
# Preserve one bounded failure record before owned cleanup removes the receipt.
# This sidecar contains controller/task labels and a capped synthetic receipt,
# never package arguments or configuration. It is read only on fixture failure.
dependency_outcome_capture() {
	[ "${cfmgr_dependencies_phase:-none}" = cleanup ] || return 0
	case ${dependency_attempt_count:-0} in 1 | 2) ;; *) return 0 ;; esac
	dependency_outcome_path=$fixture/dependency.outcome.$dependency_attempt_count
	[ ! -e "$dependency_outcome_path" ] && [ ! -L "$dependency_outcome_path" ] || return 0
	(
		umask 077
		set -C
		: >"$dependency_outcome_path"
	) || return 1
	{
		printf 'attempt=%s label=%s code=%s tasks-exit=%s action-refused=%s loss=%s tasks-state=%s dependencies-state=%s\n' \
			"$dependency_attempt_count" "${dependency_attempt_label:-unset}" "${cfmgr_dependencies_code:-unset}" "${cfmgr_tasks_exit:-unset}" \
			"${cfmgr_tasks_action_refused:-unset}" "${cfmgr_dependencies_loss:-0}" \
			"${cfmgr_tasks_state:-unset}" "${cfmgr_dependencies_state:-unset}"
		dependency_outcome_receipt=$cfmgr_dependencies_context/receipt
		if [ -f "$dependency_outcome_receipt" ] && [ ! -L "$dependency_outcome_receipt" ]; then
			printf 'receipt (first at most 1024 bytes):\n'
			/usr/bin/head -c 1024 "$dependency_outcome_receipt" || return 1
			printf '\n'
		else
			printf 'receipt unavailable\n'
		fi
	} >"$dependency_outcome_path" || return 1
}
# Only fixture callbacks add phase evidence; native dispatch and supervision body
# remain unchanged. Tool selection also covers the first direct snapshot copies.
dependency_native() {
	if cfmgr_dependencies_native "$@"; then dependency_native_code=0; else dependency_native_code=$?; fi
	dependency_trace END "$1" "$dependency_native_code" || return 3
	return "$dependency_native_code"
}
for dependency_applet in sh awk readlink usleep cp chmod kill; do
	ln -s busybox "$view_native_root/bin/$dependency_applet"
done
for dependency_applet in readlink wc ls mkdir cp chmod mount umount ln rm rmdir kill; do
	ln -s "$view_busybox" "$view_ram/$dependency_applet"
done
mkdir -m 755 "$cfmgr_storage_opt/bin" "$cfmgr_storage_opt/lib"
cp "$dependency_process" "$view_native_root/bin/dependency-process"
cat >"$cfmgr_storage_opt/bin/opkg" <<'EOF_OPKG'
#!/bin/sh
case $1 in
--version) exit 0 ;;
status)
    # Actual opkg ignores every status operand after the first.
    case $2 in
    jq-full | coreutils-timeout | coreutils-sha256sum) [ -e /opt/force-fixture ] || exit 0 ;;
    flock) [ -f /opt/bin/flock ] || exit 0 ;;
    *) exit 0 ;;
    esac
    printf 'Package: %s\nVersion: fixture-1\nStatus: install user installed\n\n' "$2"
    ;;
update)
    [ -r /tmp/feed/Packages ] || exit 1
    printf 'update\n' >>/opt/operations
    [ ! -e /opt/fail-update ] || exit 1
    ;;
--force-reinstall)
    [ -e /opt/force-fixture ] && [ "$#" = 6 ] || exit 2
    [ "$2:$3:$4:$5:$6" = install:jq-full:coreutils-timeout:coreutils-sha256sum:flock ] || exit 2
    printf 'force jq-full coreutils-timeout coreutils-sha256sum flock\n' >>/opt/operations
    ;;
install)
    shift
    [ "$#" = 1 ] && [ "$1" = flock ] || exit 2
    printf 'install flock\n' >>/opt/operations
    cp /bin/busybox /opt/bin/flock && chmod 755 /opt/bin/flock || exit 1
    if [ -e /opt/launch-daemon ]; then /bin/dependency-process daemon /opt/daemon.receipt || exit 1; fi
    if [ -e /opt/launch-thread ]; then
        /bin/dependency-process leader-exit /opt/thread.receipt &
        tries=0
        while [ ! -f /opt/thread.receipt ]; do
            [ "$tries" -lt 100 ] || exit 1
            /bin/usleep 50000
            tries=$((tries+1))
        done
    fi
    if [ -e /opt/launch-mixed ]; then
        printf 'requested\n' >/opt/mixed.request || exit 1
        tries=0
        while [ ! -f /opt/mixed.receipt ]; do
            [ "$tries" -lt 100 ] || exit 1
            /bin/usleep 50000
            tries=$((tries+1))
        done
    fi
    if [ -e /opt/launch-loss ]; then
        /bin/dependency-process hold /opt/loss.receipt &
        while :; do /bin/usleep 50000; done
    fi
    ;;
*) exit 2 ;;
esac
EOF_OPKG
chmod 755 "$cfmgr_storage_opt/bin/opkg"
# shellcheck disable=SC1091
. "$root/modules/lib/execution_tasks.sh"
# shellcheck disable=SC1091
. "$root/modules/lib/dependencies.sh"
# shellcheck disable=SC1091
. "$root/modules/helpers/bootstrap.sh"
cfmgr_install_source=$root cfmgr_install_source_fd=0 cfmgr_install_context_fd=9
cfmgr_install_sh=$view_ram/ash cfmgr_install_env=$view_ram/env cfmgr_install_awk=$view_ram/awk
cfmgr_install_readlink=$view_ram/readlink cfmgr_install_sleep=/bin/sleep cfmgr_install_wc=$view_ram/wc
cfmgr_install_ls=$view_ram/ls cfmgr_install_mkdir=$view_ram/mkdir cfmgr_install_cp=$view_ram/cp cfmgr_install_chmod=$view_ram/chmod
cfmgr_install_interrupted=0
cfmgr_install_tmp_snapshot=$("$view_ram/awk" -f "$root/modules/lib/mountinfo.awk" "$view_ram" /proc/self/mountinfo)
cfmgr_bootstrap_attached() {
	cfmgr_storage_attached && [ "$cfmgr_install_context" -ef /proc/self/fd/9 ] && [ "$root" -ef /proc/self/fd/0 ]
}
cfmgr_dependencies_admit() { cfmgr_bootstrap_attached; }
dependency_inside_tools() {
	cfmgr_dependencies_inside_shell=/bin/sh cfmgr_dependencies_inside_awk=/bin/awk
	cfmgr_dependencies_inside_readlink=/bin/readlink cfmgr_dependencies_inside_usleep=/bin/usleep
}
dependency_native_tool() {
	dependency_outcome_capture || :
	dependency_trace START "$1" || return 3
	case $1 in
	inventory | awk | identity-parse) cfmgr_dependencies_native_tool=$view_ram/awk ;;
	identity | list) cfmgr_dependencies_native_tool=$view_ram/ls ;;
	root | guard-root | bind4 | bind7 | private | unbindable | seal) cfmgr_dependencies_native_tool=$view_ram/mount ;;
	file) cfmgr_dependencies_native_tool=$view_ram/ash ;;
	fifo) cfmgr_dependencies_native_tool=$view_ram/mknod ;;
	unmount) cfmgr_dependencies_native_tool=$view_ram/umount ;;
	copy) cfmgr_dependencies_native_tool=$view_ram/cp ;;
	link) cfmgr_dependencies_native_tool=$view_ram/ln ;;
	remove) cfmgr_dependencies_native_tool=$view_ram/rm ;;
	signal) cfmgr_dependencies_native_tool=$view_ram/kill ;;
	readlink | mkdir | chmod | rmdir) cfmgr_dependencies_native_tool=$view_ram/$1 ;;
	retire) cfmgr_dependencies_native_tool=$view_ram/rmdir ;;
	*) return 2 ;;
	esac
}
cfmgr_dependencies_inside_tools() { dependency_inside_tools; }
cfmgr_dependencies_native_tool() { dependency_native_tool "$@"; }
cfmgr_execution_view_native() {
	case $case_name in
	dependency_update_failure | dependency_daemon | dependency_loss)
		# Layer view setup/cleanup only; task, keeper, ownership, signals and repair stay production-native.
		view_native "$@"
		;;
	*) dependency_native "$@" ;;
	esac
}
cfmgr_mount_keeper_native() {
	[ "$1" = fifo ] || return 2
	dependency_native fifo "$3"
}
cfmgr_prerequisites_pause() { "$view_ram/usleep" 10000; }
dependency_attempt() {
	dependency_attempt_count=$((${dependency_attempt_count:-0} + 1))
	[ "$dependency_attempt_count" -le 2 ] || return 3
	dependency_attempt_label=$1
	cfmgr_install_context=$view_ram/preflight-$1
	mkdir -m 700 "$cfmgr_install_context"
	exec 0<"$root" 9<"$cfmgr_install_context"
	cfmgr_dependencies_state=complete cfmgr_keeper_outer_deadline=''
	cfmgr_dependencies_repair flock "$view_ram" "$root" "$view_native_root" "$view_ram/ash" "$view_ram/env" \
		"$view_ram/awk" "$view_ram/readlink" "$view_ram/usleep" "$view_ram/wc" "$view_ram/mknod" "$view_ram/chroot"
}
dependency_attempt_count=0
ln -s "$view_busybox" "$view_ram/chroot"
if [ "$case_name" = dependency_installer ]; then
	# shellcheck disable=SC1091 # Same trusted repository fixture, finite test entry.
	. "$root/tests/fixtures/dependency_installer.sh"
	return 0
fi

dependency_observer=''
dependency_observer_detail() {
	if [ -f "$view_ram/dependency-observer.status" ] && [ ! -L "$view_ram/dependency-observer.status" ]; then
		:
	else
		printf 'not-started'
		return
	fi
	IFS= read -r dependency_observer_state <"$view_ram/dependency-observer.status" || dependency_observer_state=unreadable
	printf '%s' "$dependency_observer_state"
}
dependency_observer_status() {
	printf '%s\n' "$1" >"$view_ram/dependency-observer.status"
}
# The observer starts at the task gate, just before the product action window;
# the outer test watchdog still bounds teardown if the action is interrupted.
dependency_wait_receipt() {
	dependency_wait_path=$1
	IFS=' ' read -r dependency_wait_uptime dependency_wait_idle </proc/uptime || return 1
	dependency_wait_started=${dependency_wait_uptime%%.*}
	case $dependency_wait_started in '' | *[!0-9]*) return 1 ;; esac
	while [ ! -f "$dependency_wait_path" ]; do
		IFS=' ' read -r dependency_wait_uptime dependency_wait_idle </proc/uptime || return 1
		dependency_wait_now=${dependency_wait_uptime%%.*}
		case $dependency_wait_now in '' | *[!0-9]*) return 1 ;; esac
		[ "$((dependency_wait_now - dependency_wait_started))" -lt 120 ] || return 1
		"$view_ram/usleep" 50000 || return 1
	done
}
dependency_start_observer() {
	[ -z "$dependency_observer" ] || return 1
	# Separate fixture-owned actor, positively outside the view. Product must
	# neither signal it nor claim ownership of services requested over IPC.
	(
		exec 3<&- 4<&- 5<&- 6<&- 7<&- 8<&- 9<&-
		if [ "$case_name" = dependency_mixed ]; then
			dependency_observer_status waiting-mixed-request
			if dependency_wait_receipt "$cfmgr_storage_opt/mixed.request"; then :; else
				dependency_observer_status failed-mixed-request-timeout
				exit 1
			fi
			dependency_observer_status launching-mixed-process
			exec "$dependency_process" mixed "$cfmgr_storage_opt/mixed.receipt" "$view_ram/dependencies/view"
		fi
		dependency_observer_status waiting-opkg-receipt
		if dependency_wait_receipt "$cfmgr_storage_opt/loss.receipt"; then :; else
			dependency_observer_status failed-opkg-receipt-timeout
			exit 1
		fi
		dependency_observer_status detaching-guards
		# Simulate device-matched USB detach of the two guarded execution aliases
		# plus the admitted original canonical attachment. These are owned mounts.
		umount -l "$view_ram/dependencies/view/opt" || {
			dependency_observer_status failed-detach-opt
			exit 1
		}
		umount -l "$view_ram/dependencies/view/tmp/mnt/usb" || {
			dependency_observer_status failed-detach-usb
			exit 1
		}
		for target in "$view_ram/dependencies/view/opt/fallback" "$view_ram/dependencies/view/tmp/mnt/usb/fallback"; do
			if (printf 'must fail\n' >"$target") 2>/dev/null; then
				dependency_observer_status failed-writable-fallback
				exit 1
			fi
		done
		printf 'guarded\n' >"$view_ram/loss.guards" || {
			dependency_observer_status failed-guard-proof
			exit 1
		}
		dependency_observer_status detaching-storage
		umount -l "$cfmgr_storage_mount" || {
			dependency_observer_status failed-detach-storage
			exit 1
		}
		dependency_observer_status complete
	) &
	dependency_observer=$!
}
# Record signal evidence without changing the actual native signal dispatch.
cfmgr_execution_tasks_native() {
	if [ "$1" = signal ]; then
		printf '%s %s\n' "$2" "$3" >>"$view_ram/signals"
		if [ "$case_name" = dependency_threads ]; then
			IFS=' ' read -r thread_pid thread_tid <"$cfmgr_storage_opt/thread.receipt"
			if [ "$thread_pid" = "$2" ]; then
				# shellcheck disable=SC2016 # Literal AWK stat fields.
				"$view_ram/awk" '{ sub(/^.*\) /,""); if ($1!="Z") exit 1 }' "/proc/$thread_pid/stat" || return 3
				[ -d "/proc/$thread_pid/task/$thread_tid" ] || return 3
				printf 'dead leader and live thread\n' >"$view_ram/thread.proof"
			fi
		fi
	fi
	if dependency_native "$@"; then dependency_native_status=0; else dependency_native_status=$?; fi
	if [ "$dependency_native_status" -eq 0 ] && [ "$1" = fifo ] && [ "$2" = "$cfmgr_tasks_context/gate" ]; then
		case $case_name in dependency_mixed | dependency_loss) dependency_start_observer || return 3 ;; esac
	fi
	return "$dependency_native_status"
}
case $case_name in
dependency_update_failure)
	: >"$cfmgr_storage_opt/fail-update"
	if dependency_attempt update-failure; then fail 'failed opkg update reported repair success'; else dependency_status=$?; fi
	[ "$dependency_status" = 1 ] || fail "failed opkg update returned unexpected status=$dependency_status"
	[ "$cfmgr_dependencies_code:$cfmgr_dependencies_result:$cfmgr_dependencies_state:$cfmgr_dependencies_claimed:$cfmgr_dependencies_native_unresolved" = 1:failed:complete:0:0 ] ||
		fail 'failed update did not finish with a resolved failed result'
	[ "$cfmgr_tasks_state:$cfmgr_view_state:$cfmgr_view_pin_state:$cfmgr_keeper_state" = quiescent:released:retired:released ] ||
		fail 'failed update did not quiesce and release task/view/keeper ownership'
	[ ! -e "$view_ram/dependencies" ] || fail 'failed update left its repair claim'
	[ -z "$cfmgr_dependencies_operation_deadline" ] && [ -z "$cfmgr_keeper_outer_deadline" ] || fail 'failed update retained an operation deadline'
	[ ! -e /proc/self/fd/5 ] || fail 'failed update left the repair claim descriptor open'
	[ "$(cat "$cfmgr_storage_opt/operations")" = update ] && [ ! -e "$cfmgr_storage_opt/bin/flock" ] ||
		fail 'failed update proceeded to installation'
	exec 0<&- 9<&-
	printf 'PASS: production dependency update failure retires ownership without installation\n'
	return 0
	;;
dependency_retry)
	: >"$cfmgr_storage_opt/fail-update"
	if dependency_attempt failed; then fail 'failed update reported repair success'; else dependency_status=$?; fi
	if [ "$dependency_status" = 1 ] && [ ! -e "$view_ram/dependencies" ]; then :; else fail 'resolved update failure did not release claim'; fi
	rm "$cfmgr_storage_opt/fail-update"
	;;
dependency_daemon) : >"$cfmgr_storage_opt/launch-daemon" ;;
dependency_threads) : >"$cfmgr_storage_opt/launch-thread" ;;
dependency_mixed)
	: >"$cfmgr_storage_opt/launch-mixed"
	;;
dependency_loss)
	: >"$cfmgr_storage_opt/launch-loss"
	;;
esac
if dependency_attempt final; then dependency_status=0; else dependency_status=$?; fi
case $case_name in
dependency_mixed)
	if [ "$dependency_status" = 3 ] && [ -d "$view_ram/dependencies" ] && [ "$cfmgr_view_pin_state" = active ]; then :; else fail "mixed roots were not retained; observer=$(dependency_observer_detail)"; fi
	if IFS=' ' read -r mixed_pid mixed_tid <"$cfmgr_storage_opt/mixed.receipt"; then :; else fail "mixed observer did not publish readiness; observer=$(dependency_observer_detail)"; fi
	if [ "$(dependency_observer_detail)" = launching-mixed-process ] && [ "$mixed_pid" = "$dependency_observer" ] &&
		[ "$mixed_pid" != "$mixed_tid" ] && [ -d "/proc/$mixed_pid/task/$mixed_tid" ] &&
		[ "/proc/$mixed_pid/root" -ef / ] && [ "/proc/$mixed_pid/task/$mixed_tid/root" -ef "$cfmgr_view_root" ] &&
		kill -0 "$mixed_pid" 2>/dev/null; then :; else fail "foreign/mixed process root/liveness proof failed; observer=$(dependency_observer_detail)"; fi
	[ ! -e "$view_ram/signals" ] || fail 'mixed-root uncertainty admitted a signal'
	# Isolated test recovery owns this exact unreaped direct fixture child. This
	# is not product authority to kill a mixed-root/service task.
	kill -KILL "$dependency_observer"
	if wait "$dependency_observer"; then fail 'mixed fixture unexpectedly completed'; fi
	cfmgr_execution_tasks_finish || fail 'known fixture recovery did not reach quiescence'
	cfmgr_dependencies_operation_deadline='' cfmgr_keeper_outer_deadline=''
	cfmgr_execution_view_release || fail 'mixed fixture protection could not be normally released'
	cfmgr_dependencies_phase=cleanup
	cfmgr_dependencies_cleanup || fail 'mixed fixture claim cleanup failed'
	;;
dependency_daemon | dependency_threads)
	[ "$dependency_status" = 1 ] || fail 'surviving process/thread was accepted or unresolved'
	if [ "$case_name" = dependency_daemon ]; then
		IFS=' ' read -r dependency_pid dependency_tid <"$cfmgr_storage_opt/daemon.receipt"
		[ "$dependency_pid" = "$dependency_tid" ] || fail 'daemon receipt changed'
	else
		IFS=' ' read -r dependency_pid dependency_tid <"$cfmgr_storage_opt/thread.receipt"
		if [ "$dependency_pid" != "$dependency_tid" ] && [ -f "$view_ram/thread.proof" ]; then :; else fail 'dead leader/live thread was not observed'; fi
	fi
	if [ -d "/proc/$dependency_pid" ]; then
		cfmgr_tasks_context=$cfmgr_install_context
		_cfmgr_tasks_identity "/proc/$dependency_pid" || fail 'cancelled process identity remains unknown'
		case $cfmgr_tasks_identity_state in Z | X | x) ;; *) fail 'owned process remains live after cancellation' ;; esac
	fi
	if [ "$case_name" = dependency_daemon ]; then
		# shellcheck disable=SC2016 # Literal observed signal fields.
		"$view_ram/awk" -v id="$dependency_pid" '$1==id && $2=="KILL" { found=1 } END { exit !found }' "$view_ram/signals" || fail 'TERM-ignoring daemon did not receive bounded KILL'
	fi
	;;
dependency_loss)
	[ "$dependency_status" = 1 ] || fail "lost attachment did not stop repair with resolved failure; observer=$(dependency_observer_detail)"
	if wait "$dependency_observer"; then :; else
		dependency_observer_exit=$?
		fail "detach actor failed exit=$dependency_observer_exit; observer=$(dependency_observer_detail)"
	fi
	[ "$(dependency_observer_detail)" = complete ] || fail "detach actor did not complete; observer=$(dependency_observer_detail)"
	if [ -f "$view_ram/loss.guards" ] && [ "$cfmgr_dependencies_reason" = storage-lost ]; then :; else
		fail "loss reason/guard proof absent: reason=$cfmgr_dependencies_reason loss=$cfmgr_dependencies_loss task-loss=${cfmgr_tasks_loss:-unset} task-code=${cfmgr_tasks_exit:-unset}"
	fi
	if [ ! -e "$view_ram/dependencies" ] && [ "$cfmgr_keeper_state" = released ]; then :; else fail 'loss cleanup retained live protection unexpectedly'; fi
	exec 0<&- 9<&-
	printf 'PASS: production loss cancellation with readonly fallback\n'
	return 0
	;;
*) [ "$dependency_status" = 0 ] || fail "normal installed opkg repair failed status=$dependency_status phase=${cfmgr_dependencies_phase:-unknown}" ;;
esac
if [ ! -e "$view_ram/dependencies" ] && [ "$cfmgr_view_pin_state:$cfmgr_keeper_state" = retired:released ]; then :; else fail 'repair retained protection after normal cleanup'; fi
[ -f "$cfmgr_storage_opt/bin/flock" ] || fail 'selected package was not installed'
if [ "$(tail -n 2 "$cfmgr_storage_opt/operations")" = "$(printf 'update\ninstall flock')" ]; then :; else fail 'opkg dispatched unexpected package/phase'; fi
# Fresh real post-probe of the selected installed CLI; original receipt survives.
mkdir -m 700 "$view_ram/post"
cfmgr_prerequisites_attachment_ok() { cfmgr_storage_attached; }
cfmgr_prereq_context=$view_ram/post cfmgr_prereq_shell=$view_ram/ash cfmgr_prereq_helper=$root/modules/helpers/probe.sh
cfmgr_prereq_env=$view_ram/env cfmgr_prereq_awk=$view_ram/awk cfmgr_prereq_sleep=/bin/sleep cfmgr_prereq_wc=$view_ram/wc
# Real flock's inherited-FD contention behavior, outside the released view.
: >"$view_ram/post/lock"
exec 4<>"$view_ram/post/lock" 5<>"$view_ram/post/lock"
for dependency_mode in flock-first flock-compete flock-release flock-after flock-finish; do
	cfmgr_prerequisites_run "$dependency_mode" "$view_ram/post" "$view_ram/ash" "$root/modules/helpers/probe.sh" \
		"$view_ram/env" "$view_ram/awk" /bin/sleep "$view_ram/wc" "$cfmgr_storage_opt/bin/flock" || fail 'fresh installed flock probe failed'
	case $dependency_mode:$cfmgr_probe_exit in flock-compete:1 | flock-first:0 | flock-release:0 | flock-after:0 | flock-finish:0) ;; *) fail 'installed flock behavior incorrect' ;; esac
	if [ ! -s "$cfmgr_probe_stdout" ] && [ ! -s "$cfmgr_probe_stderr" ]; then :; else fail 'installed flock output incorrect'; fi
done
exec 4<&- 5<&- 0<&- 9<&-
printf 'PASS: production dependency repair and normal ownership cleanup\n'
