#!/bin/sh
# Source-inert normal installed-opkg repair controller. Shared selection/claim
# policy is separate from root/task supervision. No dependency environment input.
# shellcheck disable=SC2034,SC2154 # Explicit imported/exported controller fields.
# Trusted caller supplies native operation/admission/context cleanup callbacks.

# Strict finite missing inventory: complete ordinary prerequisite failure only.
cfmgr_dependencies_inventory() {
	[ "$#" -eq 1 ] && [ "${#1}" -le 128 ] || return 2
	# Reject caller control/glob syntax before field splitting. The subshell
	# fixes splitting without changing the controller's flags or IFS.
	case $1 in *[!a-z0-9\ -]*) return 2 ;; esac
	(
		set -f
		IFS=' '
		cfmgr_dependencies_seen=' '
		for cfmgr_dependencies_package in $1; do
			case $cfmgr_dependencies_package in jq | coreutils-timeout | coreutils-sha256sum | flock | bind-dig) ;; *) exit 2 ;; esac
			case $cfmgr_dependencies_seen in *" $cfmgr_dependencies_package "*) exit 2 ;; esac
			cfmgr_dependencies_seen="$cfmgr_dependencies_seen$cfmgr_dependencies_package "
		done
	) || return 2
	cfmgr_dependencies_missing=$1
}

# Parse fixed opkg status records from the bounded in-view query receipt. Never
# change a provider on an ambiguous/incomplete status database observation.
# shellcheck disable=SC2016
cfmgr_dependencies_select() {
	[ "$#" -eq 4 ] || return 2
	cfmgr_dependencies_inventory "$2" || return 2
	cfmgr_dependencies_query_bytes=$("$4" -c <"$3") || return 1
	case $cfmgr_dependencies_query_bytes in '' | *[!0-9\ ]*) return 1 ;; esac
	[ "$cfmgr_dependencies_query_bytes" -le 65536 ] || return 1
	"$1" -v expected="$cfmgr_dependencies_query_bytes" -v missing="$2" '
		function known(p) { return p ~ /^(jq|jq-full|coreutils-timeout|coreutils-sha256sum|flock|bind-dig)$/ }
		function finish() {
		  if (package=="") return
		  if (seen[package]++ || status=="" || version=="") bad=1
		  if (split(status,parts," ")!=3 || parts[1] !~ /^(unknown|install|deinstall|purge)$/ ||
		    parts[3] !~ /^(not-installed|config-files|installed|unpacked|half-configured|half-installed|post-inst-failed|removal-failed)$/) bad=1
		  for (key in flags_seen) delete flags_seen[key]
		  flags_count=split(parts[2],flags,",")
		  for (f=1;f<=flags_count;f++) if (flags_seen[flags[f]]++ || flags[f] !~ /^(ok|reinstreq|hold|replace|noprune|prefer|obsolete|user)$/ || (flags[f]=="ok" && flags_count!=1)) bad=1
		  if (parts[3]!="not-installed" && parts[3]!="config-files") installed[package]=1
		  package=status=version=""
		}
		{ bytes+=length($0)+1 }
		length($0)>4096 || NR>512 || $0 ~ /[^ -~\t]/ { bad=1 }
		$0=="ready END" { if (NR!=1 || ready++ || ended) bad=1; next }
		$1=="status" && $3=="BEGIN" { if (NF!=3 || !ready || ended || inside || !known($2) || queries[$2]++) bad=1; query=$2; records=0; metadata=0; begun++; inside=1; next }
		$1=="status" && $4=="END" { finish(); if (NF!=4 || !inside || $2!=query || $3!="0" || ended) bad=1; inside=0; next }
		$0 ~ /^queried [0-9]+ END$/ { finish(); if (NF!=3 || inside || $2!="0" || ended++) bad=1; next }
		!inside { bad=1; next }
		/^Package: / { finish(); if (records++) bad=1; package=substr($0,10)
		  if (package!=query) bad=1
		  if (package!="jq" && package!="jq-full" && package!="coreutils-timeout" && package!="coreutils-sha256sum" && package!="flock" && package!="bind-dig") bad=1; next }
		/^Status: / { if (status!="" || package=="") bad=1; status=substr($0,9); metadata=0; next }
		/^Version: / { if (version!="" || package=="") bad=1; version=substr($0,10); metadata=0; next }
		$0=="" { finish(); next }
		/^(Package|Status|Version):/ { bad=1; next }
		$0 ~ /^[A-Za-z0-9-]+:( |$)/ { metadata=1; next }
		/^ / { if (!metadata) bad=1; next }
		{ bad=1 }
		END { if (bytes!=expected || inside || begun!=6 || ended!=1 || bad || (installed["jq"] && installed["jq-full"])) exit 1
		  count=split(missing,items," "); output=""
		  for (i=1;i<=count;i++) { p=items[i]; if (p=="jq" && installed["jq-full"]) p="jq-full"
		    output=output (output=="" ? "" : " ") (installed[p] ? "r-" : "i-") p }
		  print output }
	' "$3"
}

# Claim receipt carries only kernel-derived owner identity, never mutable config.
_cfmgr_dependencies_owner_active() {
	cfmgr_dependencies_claim_admit "$cfmgr_dependencies_context" || return 3
	cfmgr_dependencies_owner_pid='' cfmgr_dependencies_owner_start='' cfmgr_dependencies_owner_boot='' cfmgr_dependencies_extra=''
	if [ ! -f "$cfmgr_dependencies_context/owner" ]; then
		# Exclusive mkdir can precede the owner receipt. Wait without adoption.
		return 0
	fi
	[ ! -L "$cfmgr_dependencies_context/owner" ] || return 3
	cfmgr_dependencies_owner_bytes=$("$cfmgr_dependencies_wc" -c <"$cfmgr_dependencies_context/owner") || return 3
	case $cfmgr_dependencies_owner_bytes in '' | *[!0-9\ ]*) return 3 ;; esac
	[ "$cfmgr_dependencies_owner_bytes" -le 96 ] || return 3
	cfmgr_dependencies_owner_line='' cfmgr_dependencies_owner_tail=''
	{
		IFS= read -r cfmgr_dependencies_owner_line || return 3
		if IFS= read -r cfmgr_dependencies_owner_tail; then return 3; fi
		[ -z "$cfmgr_dependencies_owner_tail" ] || return 3
	} <"$cfmgr_dependencies_context/owner" || return 3
	[ "$cfmgr_dependencies_owner_bytes" -eq "$((${#cfmgr_dependencies_owner_line} + 1))" ] || return 3
	IFS=' ' read -r cfmgr_dependencies_owner_pid cfmgr_dependencies_owner_start cfmgr_dependencies_owner_boot cfmgr_dependencies_extra <<EOF_OWNER
$cfmgr_dependencies_owner_line
EOF_OWNER
	[ -z "$cfmgr_dependencies_extra" ] || return 3
	case $cfmgr_dependencies_owner_pid:$cfmgr_dependencies_owner_start in *[!0-9:]* | :* | *: | 0* | *:0*) return 3 ;; esac
	[ "${#cfmgr_dependencies_owner_pid}" -le 10 ] && [ "${#cfmgr_dependencies_owner_start}" -le 20 ] || return 3
	[ "$cfmgr_dependencies_owner_line" = "$cfmgr_dependencies_owner_pid $cfmgr_dependencies_owner_start $cfmgr_dependencies_owner_boot" ] || return 3
	IFS= read -r cfmgr_dependencies_current_boot </proc/sys/kernel/random/boot_id || return 3
	[ "$cfmgr_dependencies_owner_boot" = "$cfmgr_dependencies_current_boot" ] || return 3
	cfmgr_prerequisites_identity "$cfmgr_dependencies_owner_pid" || return 3
	[ "$cfmgr_identity_start" = "$cfmgr_dependencies_owner_start" ] && [ "$cfmgr_identity_state" != Z ] || return 3
}

_cfmgr_dependencies_wait() {
	_cfmgr_tasks_now || return 3
	cfmgr_dependencies_wait_deadline=$((cfmgr_tasks_now + 120))
	while [ -e "$cfmgr_dependencies_context" ] || [ -L "$cfmgr_dependencies_context" ]; do
		if _cfmgr_dependencies_owner_active; then
			:
		else
			# Successful cleanup can remove the claim during any observation.
			# Only complete disappearance permits the caller's fresh post-probes;
			# an unreadable, stale or replaced claim still present stays unresolved.
			[ ! -e "$cfmgr_dependencies_context" ] && [ ! -L "$cfmgr_dependencies_context" ] || return 3
			break
		fi
		_cfmgr_tasks_now || return 3
		[ "$cfmgr_tasks_now" -lt "$cfmgr_dependencies_wait_deadline" ] || return 3
		[ "${cfmgr_install_interrupted:-0}" = 0 ] || return 1
		"$cfmgr_dependencies_usleep" 50000 || return 3
	done
	cfmgr_dependencies_result=coalesced
}

# MISSING SHARED_PARENT SOURCE NATIVE_ROOT SH ENV AWK READLINK USLEEP WC MKNOD CHROOT
# Empty inventory is an inert no-op unless an existing shared worker needs waiting.
# Only the exclusive claimant creates a view/launches installed opkg. Waiters
# return once for fresh caller probes, never re-launch within this invocation.
cfmgr_dependencies_repair() {
	[ "$#" -eq 12 ] || return 2
	case ${cfmgr_dependencies_state:-none} in retained) return 3 ;; esac
	cfmgr_dependencies_inventory "$1" || return 2
	cfmgr_dependencies_parent=$2 cfmgr_dependencies_source=$3 cfmgr_dependencies_native_root=$4
	cfmgr_dependencies_shell=$5 cfmgr_dependencies_env=$6 cfmgr_dependencies_awk=$7 cfmgr_dependencies_readlink=$8 cfmgr_dependencies_usleep=$9
	shift 9
	cfmgr_dependencies_wc=$1 cfmgr_dependencies_mknod=$2 cfmgr_dependencies_chroot=$3
	cfmgr_dependencies_context=$cfmgr_dependencies_parent/dependencies
	cfmgr_dependencies_result=invalid cfmgr_dependencies_loss=0 cfmgr_dependencies_reason=admission
	cfmgr_dependencies_claimed=0 cfmgr_dependencies_snapshot_ready=0 cfmgr_dependencies_cleaning=0 cfmgr_dependencies_native_unresolved=0
	if [ -e "$cfmgr_dependencies_context" ] || [ -L "$cfmgr_dependencies_context" ]; then
		_cfmgr_dependencies_wait
		return $?
	fi
	[ -n "$cfmgr_dependencies_missing" ] || {
		cfmgr_dependencies_result=healthy
		return 0
	}
	_cfmgr_tasks_now || return 3
	cfmgr_dependencies_operation_deadline=$((cfmgr_tasks_now + 120))
	cfmgr_keeper_outer_deadline=$cfmgr_dependencies_operation_deadline
	if cfmgr_dependencies_admit; then :; else
		cfmgr_dependencies_code=$?
		if [ "$cfmgr_dependencies_code" -eq 3 ]; then
			cfmgr_dependencies_native_unresolved=1 cfmgr_dependencies_state=retained
			cfmgr_dependencies_native_pid=$cfmgr_probe_pid cfmgr_dependencies_native_start=$cfmgr_probe_start cfmgr_dependencies_native_boot=$cfmgr_probe_boot
		fi
		return "$cfmgr_dependencies_code"
	fi
	cfmgr_dependencies_snapshot_ready=0
	cfmgr_dependencies_native copy "$cfmgr_dependencies_source/modules/helpers/probe.sh" "$cfmgr_install_context/repair-probe.sh" || return 3
	cfmgr_dependencies_native chmod "$cfmgr_install_context/repair-probe.sh" 700 || return 3
	cfmgr_dependencies_native copy "$cfmgr_dependencies_source/modules/lib/mountinfo.awk" "$cfmgr_install_context/repair-mountinfo.awk" || return 3
	cfmgr_dependencies_snapshot_ready=1
	if cfmgr_dependencies_native mkdir "$cfmgr_dependencies_context" 700; then :; else
		cfmgr_dependencies_code=$?
		[ "$cfmgr_dependencies_code" -ne 3 ] || return 3
		if [ -d "$cfmgr_dependencies_context" ]; then
			_cfmgr_dependencies_wait
			return $?
		fi
		return "$cfmgr_dependencies_code"
	fi
	cfmgr_dependencies_state=retained cfmgr_dependencies_phase=preparing
	cfmgr_dependencies_claim_admit "$cfmgr_dependencies_context" || return 3
	exec 5<"$cfmgr_dependencies_context" || return 3
	cfmgr_dependencies_claimed=1
	cfmgr_prerequisites_identity "$$" || return 3
	cfmgr_dependencies_owner_start=$cfmgr_identity_start
	IFS= read -r cfmgr_dependencies_owner_boot </proc/sys/kernel/random/boot_id || return 3
	(
		umask 077
		set -C
		printf '%s %s %s\n' "$$" "$cfmgr_dependencies_owner_start" "$cfmgr_dependencies_owner_boot" >"$cfmgr_dependencies_context/owner"
	) || return 3
	# Snapshot all cleanup code while source and storage are still attached.

	for cfmgr_dependencies_code_file in modules/helpers/probe.sh modules/helpers/mount_keeper.sh modules/helpers/dependencies.sh modules/lib/prerequisites.sh modules/lib/execution_view.sh modules/lib/mountinfo.awk; do
		cfmgr_dependencies_native copy "$cfmgr_dependencies_source/$cfmgr_dependencies_code_file" "$cfmgr_dependencies_context/${cfmgr_dependencies_code_file##*/}" || {
			_cfmgr_dependencies_early_cleanup "$?"
			return $?
		}
	done
	cfmgr_dependencies_native chmod "$cfmgr_dependencies_context/probe.sh" 700 || {
		_cfmgr_dependencies_early_cleanup "$?"
		return $?
	}
	cfmgr_tasks_context=$cfmgr_dependencies_context cfmgr_tasks_awk=$cfmgr_dependencies_awk cfmgr_tasks_readlink=$cfmgr_dependencies_readlink cfmgr_tasks_usleep=$cfmgr_dependencies_usleep
	cfmgr_tasks_parser=$cfmgr_dependencies_context/mountinfo.awk cfmgr_tasks_state=quiescent
	(
		umask 077
		set -C
		: >"$cfmgr_dependencies_context/foreign.ids"
	) || return 3
	cfmgr_dependencies_phase=construction
	if cfmgr_execution_view_create "$cfmgr_dependencies_native_root" "$cfmgr_dependencies_context" "$cfmgr_dependencies_awk" "$cfmgr_dependencies_readlink" "$cfmgr_dependencies_context/mountinfo.awk"; then
		cfmgr_dependencies_phase=launch
		cfmgr_dependencies_inside_tools || return 3
		if cfmgr_execution_tasks_start "$cfmgr_dependencies_context" "$cfmgr_dependencies_env" "$cfmgr_dependencies_chroot" "$cfmgr_dependencies_shell" "$cfmgr_dependencies_context/dependencies.sh" \
			"$cfmgr_dependencies_awk" "$cfmgr_dependencies_readlink" "$cfmgr_dependencies_usleep" "$cfmgr_dependencies_inside_shell" "$cfmgr_dependencies_inside_awk" "$cfmgr_dependencies_inside_readlink" "$cfmgr_dependencies_inside_usleep"; then
			if cfmgr_dependencies_select "$cfmgr_dependencies_awk" "$cfmgr_dependencies_missing" "$cfmgr_dependencies_context/receipt" "$cfmgr_dependencies_wc" >"$cfmgr_dependencies_context/selection"; then
				IFS= read -r cfmgr_dependencies_selection <"$cfmgr_dependencies_context/selection" || return 3
				cfmgr_dependencies_phase=repair
				cfmgr_dependencies_code=0
				if type cfmgr_dependencies_before_repair >/dev/null 2>&1; then
					if cfmgr_dependencies_before_repair; then :; else cfmgr_dependencies_code=$?; fi
				fi
				if [ "$cfmgr_dependencies_code" -eq 3 ]; then
					# The native recheck's unresolved child must retain every guard;
					# do not issue a worker request or begin further cleanup probes.
					cfmgr_dependencies_native_unresolved=1
					return 3
				fi
				if [ "$cfmgr_dependencies_code" -eq 0 ]; then
					if cfmgr_execution_tasks_run "$cfmgr_dependencies_selection"; then cfmgr_dependencies_code=0; else cfmgr_dependencies_code=$?; fi
				fi
			else cfmgr_dependencies_code=1; fi
		else cfmgr_dependencies_code=$?; fi
	else cfmgr_dependencies_code=$?; fi
	case ${cfmgr_tasks_state:-none} in running | retained)
		if cfmgr_execution_tasks_finish; then :; else
			cfmgr_dependencies_reason=cleanup-pending
			cfmgr_dependencies_report cleanup-pending || :
			return 3
		fi
		;;
	esac
	cfmgr_dependencies_phase=cleanup
	_cfmgr_tasks_now || return 3
	cfmgr_dependencies_operation_deadline=$((cfmgr_tasks_now + 60))
	cfmgr_keeper_outer_deadline=$cfmgr_dependencies_operation_deadline
	if cfmgr_execution_view_release; then :; else return 3; fi
	if [ "$cfmgr_dependencies_loss" = 1 ]; then
		if cfmgr_dependencies_report cleanup-complete; then :; else
			[ "$?" -ne 3 ] || return 3
		fi
		cfmgr_dependencies_code=1
	fi
	cfmgr_dependencies_cleanup || return 3
	# A resolved full cleanup retires transient ownership uncertainty for retry.
	if [ "$cfmgr_dependencies_code" -eq 3 ]; then cfmgr_dependencies_code=1; fi
	exec 5<&-
	cfmgr_dependencies_claimed=0 cfmgr_dependencies_state=complete
	cfmgr_dependencies_operation_deadline='' cfmgr_keeper_outer_deadline=''
	if [ "$cfmgr_dependencies_code" -eq 0 ]; then cfmgr_dependencies_result=repaired; else cfmgr_dependencies_result=failed; fi
	return "$cfmgr_dependencies_code"
}

_cfmgr_dependencies_early_cleanup() {
	cfmgr_dependencies_code=$1
	[ "$cfmgr_dependencies_code" -ne 3 ] && [ "${cfmgr_dependencies_native_unresolved:-0}" = 0 ] || return 3
	cfmgr_dependencies_cleanup || return 3
	exec 5<&-
	cfmgr_dependencies_claimed=0 cfmgr_dependencies_state=complete cfmgr_dependencies_result=failed
	return "$cfmgr_dependencies_code"
}

cfmgr_execution_view_quiescent() {
	case ${1:-active} in
	active) cfmgr_execution_tasks_quiescent ;;
	retired) [ "$cfmgr_tasks_state:$cfmgr_view_pin_state" = quiescent:retired ] ;;
	*) return 2 ;;
	esac
}
cfmgr_execution_view_keeper() {
	case $1 in
	start)
		cfmgr_dependencies_native mkdir "$2/keeper" 700 || return $?
		cfmgr_mount_keeper_start "$2/keeper" "$cfmgr_dependencies_shell" "$2/mount_keeper.sh" "$2/prerequisites.sh" \
			"$cfmgr_dependencies_env" "$cfmgr_dependencies_mknod" "$cfmgr_dependencies_awk" "$cfmgr_dependencies_usleep"
		;;
	retain) cfmgr_mount_keeper_retain "$2" ;;
	check) cfmgr_mount_keeper_check "$2" "$3" ;;
	release) cfmgr_mount_keeper_release ;;
	*) return 2 ;;
	esac
}
cfmgr_mount_keeper_native() {
	[ "$1" = fifo ] || return 2
	cfmgr_dependencies_native fifo "$3"
}
cfmgr_execution_view_native() { cfmgr_dependencies_native "$@"; }
cfmgr_execution_tasks_native() { cfmgr_dependencies_native "$@"; }

cfmgr_execution_tasks_event() {
	[ "$#" -eq 1 ] && [ "$1" = storage-lost ] || return 2
	cfmgr_dependencies_reason=storage-lost
	[ "${cfmgr_dependencies_loss:-0}" = 0 ] || return 0
	cfmgr_dependencies_loss=1
	if cfmgr_dependencies_report storage-lost; then return 0; else
		cfmgr_dependencies_report_code=$?
		[ "$cfmgr_dependencies_report_code" -ne 3 ] || return 3
		return 0
	fi
}
