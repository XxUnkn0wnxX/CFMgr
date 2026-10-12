#!/bin/sh
# Source-inert retained launch. Only shared dependency admission/repair is enabled.
# Never constructs defaults, starts features or invokes the fresh transaction.
# shellcheck disable=SC2034,SC2154 # Explicit bootstrap/storage/parser result fields.

cfmgr_launch_attachment_ok() {
	cfmgr_bootstrap_native_attached || return 1
	if [ "${cfmgr_launch_storage_required:-0}" = 1 ]; then cfmgr_storage_attached || return 1; fi
	cfmgr_launch_guard_attachment || return 1
	if [ "${cfmgr_launch_migrating:-0}" = 1 ]; then cfmgr_launch_original_attached || return 1; fi
}

# shellcheck disable=SC3013 # Native BusyBox -ef compares the pinned Linux FD inode.
cfmgr_launch_guard_attachment() {
	if [ "${cfmgr_launch_guard_owned:-0}" = 1 ]; then
		if [ ! -L "$cfmgr_launch_guard" ] && [ "$cfmgr_launch_guard" -ef /proc/self/fd/4 ]; then :; else
			# Only the terminal exact rmdir may remove the pinned guard inode.
			[ "${cfmgr_launch_retiring:-0}" = 1 ] && [ "${cfmgr_probe_mode:-}" = launch-rmdir ] && [ -n "${cfmgr_probe_pid:-}" ] || return 1
			cfmgr_launch_deleted=$("$cfmgr_install_ls" -Ldn /proc/self/fd/4) || return 1
			IFS=' ' read -r cfmgr_launch_mode cfmgr_launch_links cfmgr_launch_uid cfmgr_launch_rest <<EOF_DELETED
$cfmgr_launch_deleted
EOF_DELETED
			[ "$cfmgr_launch_mode:$cfmgr_launch_links:$cfmgr_launch_uid" = drwx------:0:0 ] || return 1
		fi
	fi
}

# Native-only fixed launch dispatch supports config preflight and reporting even
# before /opt can be pinned. Every ordinary install/native/repair guard is intact.
cfmgr_launch_action() {
	cfmgr_launch_mode=$1
	case $1 in
	launch-copy) cfmgr_launch_tool=$cfmgr_install_cp ;;
	launch-readonly) cfmgr_launch_tool=$cfmgr_install_chmod ;;
	launch-ls) cfmgr_launch_tool=$cfmgr_install_ls ;;
	launch-wc) cfmgr_launch_tool=$cfmgr_install_wc ;;
	launch-sha) cfmgr_launch_tool=$cfmgr_install_sha ;;
	launch-config-*) cfmgr_launch_tool=$cfmgr_install_awk ;;
	launch-report) cfmgr_launch_tool=$cfmgr_launch_logger ;;
	launch-remove) cfmgr_launch_tool=/bin/rm ;;
	launch-rmdir) cfmgr_launch_tool=/bin/rmdir ;;
	*) return 2 ;;
	esac
	shift
	cfmgr_prerequisites_run "$cfmgr_launch_mode" "$cfmgr_install_context" "$cfmgr_install_sh" \
		"$cfmgr_install_source/modules/helpers/probe.sh" "$cfmgr_install_env" "$cfmgr_install_awk" \
		"$cfmgr_install_sleep" "$cfmgr_install_wc" "$cfmgr_launch_tool" "$@" || return $?
	cfmgr_install_output=$cfmgr_probe_stdout
	[ "$cfmgr_probe_exit" -eq 0 ] && [ ! -s "$cfmgr_probe_stderr" ] || return 1
	case $cfmgr_launch_mode in launch-ls | launch-wc | launch-sha | launch-config-*) ;; *) [ ! -s "$cfmgr_probe_stdout" ] || return 1 ;; esac
}

cfmgr_launch_size() {
	cfmgr_launch_action launch-wc "$1" || return $?
	IFS=' ' read -r cfmgr_launch_bytes cfmgr_launch_extra <"$cfmgr_install_output" || return 1
	[ -z "$cfmgr_launch_extra" ] || return 1
	case $cfmgr_launch_bytes in '' | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_launch_bytes}" -le 6 ] && [ "$cfmgr_launch_bytes" -le "$2" ]
}

cfmgr_launch_metadata() {
	[ ! -L "$1" ] || return 1
	cfmgr_launch_action launch-ls "$1" || return $?
	IFS=' ' read -r cfmgr_launch_permissions cfmgr_launch_links cfmgr_launch_uid cfmgr_launch_gid cfmgr_launch_rest <"$cfmgr_install_output" || return 1
	[ "$cfmgr_launch_uid" = 0 ] || return 1
	case $2:$cfmgr_launch_permissions in
	private:drwx------ | config:-rw------- | readonly:-rw-r--r--) return 0 ;;
	protected:d????????? | protected:-?????????)
		case $cfmgr_launch_permissions in ?????w???? | ????????w?) return 1 ;; esac
		return 0
		;;
	*) return 1 ;;
	esac
}

cfmgr_launch_config() {
	# MODE SNAPSHOT. Data enters ENV only after the supervisor env-i boundary.
	cfmgr_launch_size "$2" 65536 || return $?
	cfmgr_launch_input_bytes=$cfmgr_launch_bytes
	if [ "$1" = check ]; then
		cfmgr_launch_action launch-config-check "$cfmgr_launch_input_bytes" "$cfmgr_install_source/modules/lib/json.awk" \
			"$cfmgr_install_source/modules/lib/config_observation.awk" "$2"
	else
		cfmgr_launch_action "launch-config-$1" "$cfmgr_launch_input_bytes" "$cfmgr_install_source/modules/lib/json.awk" \
			"$cfmgr_install_source/modules/lib/config_observation.awk" "$2" "$cfmgr_storage_uuid_value" \
			"$cfmgr_storage_filesystem" "$cfmgr_storage_fsroot" "$cfmgr_storage_relative"
	fi
}

cfmgr_launch_receipt() {
	cfmgr_launch_receipt_file=$cfmgr_install_output
	cfmgr_launch_size "$cfmgr_launch_receipt_file" 128 || return $?
	cfmgr_launch_receipt_bytes=$cfmgr_launch_bytes
	cfmgr_launch_line='' cfmgr_launch_tail=''
	{
		IFS= read -r cfmgr_launch_line || return 1
		if IFS= read -r cfmgr_launch_tail; then return 1; fi
		[ -z "$cfmgr_launch_tail" ] || return 1
	} <"$cfmgr_launch_receipt_file" || return 1
	[ "$cfmgr_launch_receipt_bytes" -eq "$((${#cfmgr_launch_line} + 1))" ] || return 1
	IFS=' ' read -r cfmgr_launch_tag cfmgr_launch_schema cfmgr_launch_oldgen cfmgr_launch_newgen cfmgr_launch_changed cfmgr_launch_in cfmgr_launch_out cfmgr_launch_end cfmgr_launch_extra <<EOF_RECEIPT
$cfmgr_launch_line
EOF_RECEIPT
	[ "$cfmgr_launch_tag:$cfmgr_launch_schema:$cfmgr_launch_end:$cfmgr_launch_extra" = CFMGR-CONFIG:1:END: ] || return 1
	[ "$cfmgr_launch_line" = "CFMGR-CONFIG 1 $cfmgr_launch_oldgen $cfmgr_launch_newgen $cfmgr_launch_changed $cfmgr_launch_in $cfmgr_launch_out END" ] || return 1
	for cfmgr_launch_number in "$cfmgr_launch_oldgen" "$cfmgr_launch_newgen"; do
		case $cfmgr_launch_number in '' | 0* | *[!0-9]*) return 1 ;; esac
		[ "${#cfmgr_launch_number}" -le 20 ] || return 1
	done
	case $cfmgr_launch_changed in 0 | 1) ;; *) return 1 ;; esac
	for cfmgr_launch_number in "$cfmgr_launch_in" "$cfmgr_launch_out"; do
		case $cfmgr_launch_number in '' | *[!0-9]*) return 1 ;; esac
		[ "${#cfmgr_launch_number}" -le 5 ] && [ "$cfmgr_launch_number" -le 65536 ] || return 1
	done
	[ "$cfmgr_launch_in" = "$cfmgr_launch_input_bytes" ]
}

# Structural admission precedes repair; digest-complete admission follows healthy
# post-probes. Installed cfmgr.sh maps to the external scripts entry, never reset.
cfmgr_launch_package_structure() {
	cfmgr_launch_guard=$cfmgr_install_source/.storage-observation
	for cfmgr_launch_blocker in "$cfmgr_launch_guard" "$cfmgr_install_source/entry.stage" "$cfmgr_install_source/.setup.complete"; do
		[ ! -e "$cfmgr_launch_blocker" ] && [ ! -L "$cfmgr_launch_blocker" ] || return 1
	done
	cfmgr_launch_metadata "$cfmgr_install_source" private || return $?
	for cfmgr_launch_top in "$cfmgr_install_source"/* "$cfmgr_install_source"/.[!.]* "$cfmgr_install_source"/..?*; do
		[ -e "$cfmgr_launch_top" ] || [ -L "$cfmgr_launch_top" ] || continue
		case ${cfmgr_launch_top##*/} in catalog.txt | manifest.txt | setup-state | config | modules) ;; *) return 1 ;; esac
	done
	cfmgr_launch_metadata "$cfmgr_install_source/manifest.txt" readonly || return $?
	cfmgr_launch_size "$cfmgr_install_source/manifest.txt" 131072 || return $?
	cfmgr_launch_metadata "$cfmgr_install_source/catalog.txt" readonly || return $?
	cfmgr_launch_size "$cfmgr_install_source/catalog.txt" 131072 || return $?
	for cfmgr_launch_passive in manifest.txt catalog.txt; do
		cfmgr_launch_action launch-copy "$cfmgr_install_source/$cfmgr_launch_passive" "$cfmgr_install_context/$cfmgr_launch_passive.snapshot" || return $?
	done
	cfmgr_bootstrap_manifest_records || return $?
	cfmgr_launch_metadata "$cfmgr_install_source/setup-state" config || return $?
	cfmgr_launch_size "$cfmgr_install_source/setup-state" 128 || return $?
	cfmgr_launch_setup="CFMGR-SETUP 1 $CFMGR_VERSION complete"
	[ "$cfmgr_launch_bytes" -eq "$((${#cfmgr_launch_setup} + 1))" ] || return 1
	IFS= read -r cfmgr_launch_actual <"$cfmgr_install_source/setup-state" || return 1
	[ "$cfmgr_launch_actual" = "$cfmgr_launch_setup" ] || return 1
	cfmgr_install_walk_count=0
	{
		printf '%s\n' cfmgr.sh catalog.txt modules/
		cfmgr_bootstrap_walk "$cfmgr_install_source" "$cfmgr_install_source/modules" 0
	} >"$cfmgr_install_context/launch.inventory" || return 1
	# shellcheck disable=SC2016
	"$cfmgr_install_awk" 'BEGIN { FS="\t" }
	 NR==FNR { expected[$4]=1; path=$4; while(sub(/\/[^\/]+$/,"",path)) expected[path "/"]=1; next }
	 { if (!expected[$0] || seen[$0]++) bad=1 }
	 END { for(p in expected) if(!seen[p]) bad=1; exit bad ? 1 : 0 }
	' "$cfmgr_install_context/records" "$cfmgr_install_context/launch.inventory" || return 1
	# Keep FD0 as the context. Only finite metadata probes run while FD4 reads.
	exec 4<"$cfmgr_install_context/launch.inventory" || return 1
	cfmgr_launch_structure_code=0
	while IFS= read -r cfmgr_launch_directory <&4; do
		case $cfmgr_launch_directory in */)
			if cfmgr_launch_metadata "$cfmgr_install_source/${cfmgr_launch_directory%/}" protected; then :; else
				cfmgr_launch_structure_code=$?
				break
			fi
			;;
		esac
	done
	exec 4<&-
	[ "$cfmgr_launch_structure_code" -eq 0 ] || return "$cfmgr_launch_structure_code"
	exec 4<"$cfmgr_install_context/records" || return 1
	cfmgr_launch_structure_code=0
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative <&4; do
		case $cfmgr_install_relative in cfmgr.sh) cfmgr_launch_payload=$cfmgr_install_jffs/scripts/cfmgr.sh ;; *) cfmgr_launch_payload=$cfmgr_install_source/$cfmgr_install_relative ;; esac
		if cfmgr_launch_metadata "$cfmgr_launch_payload" protected; then :; else
			cfmgr_launch_structure_code=$?
			break
		fi
	done
	exec 4<&-
	[ "$cfmgr_launch_structure_code" -eq 0 ] || return "$cfmgr_launch_structure_code"
	cfmgr_launch_live=$cfmgr_install_source/config
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_size "$cfmgr_launch_live" 65536 || return $?
	cfmgr_launch_snapshot=$cfmgr_install_context/config.snapshot
	cfmgr_launch_action launch-copy "$cfmgr_launch_live" "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_action launch-readonly "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_config check "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_oldgen:$cfmgr_launch_newgen:$cfmgr_launch_changed:$cfmgr_launch_in" = "$cfmgr_launch_oldgen:$cfmgr_launch_oldgen:0:$cfmgr_launch_out" ] || return 1
	cfmgr_launch_generation=$cfmgr_launch_oldgen cfmgr_launch_snapshot_bytes=$cfmgr_launch_in
}

# shellcheck disable=SC3013 # Native BusyBox -ef verifies the original pinned FD.
cfmgr_launch_original_attached() {
	[ ! -L "$cfmgr_install_original_context" ] && [ "$cfmgr_install_original_context" -ef /proc/self/fd/3 ] || return 1
	[ "$("$cfmgr_install_awk" -f "$cfmgr_install_source/modules/lib/mountinfo.awk" "$cfmgr_install_original_context" /proc/self/mountinfo)" = "$cfmgr_install_tmp_snapshot" ]
}

cfmgr_launch_migrate_snapshot() {
	cfmgr_launch_migrating=1
	if cfmgr_launch_migrate_work; then cfmgr_launch_migration_code=0; else cfmgr_launch_migration_code=$?; fi
	cfmgr_launch_migrating=0
	return "$cfmgr_launch_migration_code"
}

cfmgr_launch_migrate_work() {
	cfmgr_launch_original_attached && cfmgr_launch_attachment_ok || return 1
	cfmgr_launch_migrated=$cfmgr_install_context/config.snapshot
	[ ! -e "$cfmgr_launch_migrated" ] && [ ! -L "$cfmgr_launch_migrated" ] || return 1
	# Raw copy only: bootstrap_copy/flush would clobber original context FD3.
	cfmgr_launch_action launch-copy "$cfmgr_launch_snapshot" "$cfmgr_launch_migrated" || return $?
	cfmgr_bootstrap_digest "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_saved_digest=$cfmgr_install_digest
	cfmgr_launch_size "$cfmgr_launch_snapshot" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_snapshot_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_migrated" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_saved_digest" ] || return 1
	cfmgr_launch_config check "$cfmgr_launch_migrated" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_newgen:$cfmgr_launch_oldgen:$cfmgr_launch_changed:$cfmgr_launch_in" = "$cfmgr_launch_generation:$cfmgr_launch_generation:0:$cfmgr_launch_out" ] || return 1
	[ "$cfmgr_launch_in" = "$cfmgr_launch_snapshot_bytes" ] || return 1
	for cfmgr_launch_passive in records manifest.txt.snapshot catalog.txt.snapshot; do
		cfmgr_launch_action launch-copy "$cfmgr_install_original_context/$cfmgr_launch_passive" "$cfmgr_install_context/$cfmgr_launch_passive" || return $?
		cfmgr_bootstrap_digest "$cfmgr_install_original_context/$cfmgr_launch_passive" || return $?
		cfmgr_launch_saved_digest=$cfmgr_install_digest
		cfmgr_bootstrap_digest "$cfmgr_install_context/$cfmgr_launch_passive" || return $?
		[ "$cfmgr_install_digest" = "$cfmgr_launch_saved_digest" ] || return 1
	done
	cfmgr_launch_snapshot=$cfmgr_launch_migrated
}

cfmgr_launch_package_digests() {
	cfmgr_launch_attachment_ok || return 1
	for cfmgr_launch_passive in manifest.txt catalog.txt; do
		cfmgr_bootstrap_digest "$cfmgr_install_context/$cfmgr_launch_passive.snapshot" || return $?
		cfmgr_launch_saved_digest=$cfmgr_install_digest
		cfmgr_bootstrap_digest "$cfmgr_install_source/$cfmgr_launch_passive" || return $?
		[ "$cfmgr_install_digest" = "$cfmgr_launch_saved_digest" ] || return 1
	done
	exec 4<"$cfmgr_install_context/records" || return 1
	cfmgr_launch_digest_code=0
	while IFS='	' read -r cfmgr_install_expected_mode cfmgr_install_expected_size cfmgr_install_expected_digest cfmgr_install_relative <&4; do
		case $cfmgr_install_relative in cfmgr.sh) cfmgr_launch_payload=$cfmgr_install_jffs/scripts/cfmgr.sh ;; *) cfmgr_launch_payload=$cfmgr_install_source/$cfmgr_install_relative ;; esac
		if cfmgr_bootstrap_file "$cfmgr_launch_payload"; then :; else
			cfmgr_launch_digest_code=$?
			break
		fi
	done
	exec 4<&-
	return "$cfmgr_launch_digest_code"
}

cfmgr_launch_live_unchanged() {
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_size "$cfmgr_launch_live" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_snapshot_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_live" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_snapshot_digest" ]
}

cfmgr_launch_observation() {
	cfmgr_bootstrap_digest "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_snapshot_digest=$cfmgr_install_digest
	cfmgr_launch_live_unchanged || return $?
	cfmgr_launch_config observe "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_oldgen" = "$cfmgr_launch_generation" ] || return 1
	cfmgr_launch_target_generation=$cfmgr_launch_newgen cfmgr_launch_target_bytes=$cfmgr_launch_out
	if [ "$cfmgr_launch_changed" = 0 ]; then return 0; fi
	cfmgr_launch_config patch "$cfmgr_launch_snapshot" || return $?
	cfmgr_launch_candidate=$cfmgr_install_output
	cfmgr_launch_size "$cfmgr_launch_candidate" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_target_bytes" ] || return 1
	cfmgr_launch_config observe "$cfmgr_launch_candidate" || return $?
	cfmgr_launch_receipt || return $?
	[ "$cfmgr_launch_oldgen:$cfmgr_launch_newgen:$cfmgr_launch_changed:$cfmgr_launch_in" = "$cfmgr_launch_target_generation:$cfmgr_launch_target_generation:0:$cfmgr_launch_target_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_candidate" || return $?
	cfmgr_launch_candidate_digest=$cfmgr_install_digest
	cfmgr_launch_publish_observation
}

cfmgr_launch_publish_observation() {
	cfmgr_launch_attachment_ok && cfmgr_launch_live_unchanged || return $?
	[ ! -e "$cfmgr_launch_guard" ] && [ ! -L "$cfmgr_launch_guard" ] || return 1
	cfmgr_bootstrap_action install-mkdir-private "$cfmgr_launch_guard" || return $?
	cfmgr_launch_recovery=1 cfmgr_launch_guard_owned=1
	exec 4<"$cfmgr_launch_guard" || return 3
	cfmgr_bootstrap_flush "$cfmgr_launch_guard" && cfmgr_bootstrap_flush "$cfmgr_install_source" || return $?
	cfmgr_bootstrap_copy "$cfmgr_launch_snapshot" "$cfmgr_launch_guard/old" 0600 || return $?
	cfmgr_bootstrap_copy "$cfmgr_launch_candidate" "$cfmgr_launch_guard/candidate" 0600 || return $?
	cfmgr_bootstrap_digest "$cfmgr_launch_guard/old" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_snapshot_digest" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_guard/candidate" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_candidate_digest" ] || return 1
	(
		umask 077
		set -C
		printf 'CFMGR-OBSERVATION 1 %s %s %s %s END\n' "$cfmgr_launch_generation" "$cfmgr_launch_target_generation" "$cfmgr_launch_snapshot_digest" "$cfmgr_launch_target_bytes" >"$cfmgr_install_context/observation.intent"
	) || return 1
	cfmgr_bootstrap_copy "$cfmgr_install_context/observation.intent" "$cfmgr_launch_guard/intent" 0600 || return $?
	cfmgr_launch_live_unchanged && cfmgr_launch_attachment_ok || return $?
	cfmgr_bootstrap_action install-rename "$cfmgr_launch_guard/candidate" "$cfmgr_launch_live" || return $?
	cfmgr_bootstrap_flush "$cfmgr_launch_live" && cfmgr_bootstrap_flush "$cfmgr_install_source" || return $?
	cfmgr_launch_metadata "$cfmgr_launch_live" config || return $?
	cfmgr_launch_size "$cfmgr_launch_live" 65536 || return $?
	[ "$cfmgr_launch_bytes" = "$cfmgr_launch_target_bytes" ] || return 1
	cfmgr_bootstrap_digest "$cfmgr_launch_live" || return $?
	[ "$cfmgr_install_digest" = "$cfmgr_launch_candidate_digest" ] || return 1
	cfmgr_launch_action launch-remove "$cfmgr_launch_guard/old" || return $?
	cfmgr_launch_action launch-remove "$cfmgr_launch_guard/intent" || return $?
	cfmgr_launch_retiring=1
	if cfmgr_launch_action launch-rmdir "$cfmgr_launch_guard"; then cfmgr_launch_retire_code=0; else cfmgr_launch_retire_code=$?; fi
	cfmgr_launch_retiring=0
	[ "$cfmgr_launch_retire_code" -eq 0 ] || return "$cfmgr_launch_retire_code"
	cfmgr_launch_guard_owned=0
	exec 4<&-
	cfmgr_bootstrap_flush "$cfmgr_install_source" || return $?
	cfmgr_launch_recovery=0
	printf '[CFMGR] launch: notice: verified Entware observation updated\n'
}

cfmgr_launch_logger_admit() {
	cfmgr_launch_logger_resolved=$("$cfmgr_install_readlink" -f "$cfmgr_launch_logger") || return 1
	case $cfmgr_launch_logger_resolved in /usr/bin/logger | /bin/busybox) ;; *) return 1 ;; esac
	cfmgr_launch_logger_parent=/usr/bin
	while :; do
		cfmgr_launch_metadata "$cfmgr_launch_logger_parent" protected || return $?
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_launch_logger_parent")" = "$cfmgr_launch_logger_parent" ] || return 1
		[ "$cfmgr_launch_logger_parent" != / ] || break
		cfmgr_launch_logger_parent=${cfmgr_launch_logger_parent%/*}
		[ -n "$cfmgr_launch_logger_parent" ] || cfmgr_launch_logger_parent=/
	done
	cfmgr_launch_logger_parent=$cfmgr_launch_logger_resolved
	while :; do
		cfmgr_launch_metadata "$cfmgr_launch_logger_parent" protected || return $?
		[ "$("$cfmgr_install_readlink" -f "$cfmgr_launch_logger_parent")" = "$cfmgr_launch_logger_parent" ] || return 1
		[ "$cfmgr_launch_logger_parent" != / ] || break
		cfmgr_launch_logger_parent=${cfmgr_launch_logger_parent%/*}
		[ -n "$cfmgr_launch_logger_parent" ] || cfmgr_launch_logger_parent=/
	done
}

cfmgr_launch_storage_unavailable() {
	cfmgr_launch_reported=1
	printf '[CFMGR] launch: error: Entware attachment unavailable; operation stopped\n' >&2
	cfmgr_launch_logger=/usr/bin/logger
	# Optional logger cannot change operational failure into success; unresolved
	# native ownership retains the RAM context and prevents subsequent probes.
	if [ ! -f "$cfmgr_launch_logger" ] || [ ! -x "$cfmgr_launch_logger" ]; then
		printf '[CFMGR] launch: warning: native system log unavailable\n' >&2
		return 1
	fi
	if cfmgr_launch_logger_admit; then :; else
		cfmgr_launch_log_code=$?
		[ "$cfmgr_launch_log_code" -ne 3 ] || return 3
		printf '[CFMGR] launch: warning: native system log unavailable\n' >&2
		return 1
	fi
	if cfmgr_launch_action launch-report storage-unavailable; then return 1; else
		cfmgr_launch_log_code=$?
		[ "$cfmgr_launch_log_code" -ne 3 ] || return 3
		printf '[CFMGR] launch: warning: native system log delivery unconfirmed\n' >&2
		return 1
	fi
}

cfmgr_launch_work() {
	cfmgr_launch_package_structure || return $?
	if cfmgr_storage_pin /opt /usr/bin/readlink /usr/bin/awk "$cfmgr_install_source/modules/lib/mountinfo.awk" /proc/self; then :; else
		cfmgr_launch_storage_unavailable
		return $?
	fi
	cfmgr_launch_storage_required=1
	cfmgr_bootstrap_shared_requirements retained || return $?
	# Shared post-probes leave4/5 free. Preserve context through all file loops.
	exec 5<&0 0<&-
	cfmgr_install_context_fd=5
	cfmgr_launch_package_digests || return $?
	cfmgr_launch_observation || return $?
	cfmgr_launch_attachment_ok || return 1
	printf '[CFMGR] launch: notice: shared dependencies verified; feature operations unavailable\n'
}

cfmgr_launch_native() {
	[ "$#" -eq 1 ] && [ "$1" = /jffs/addons/CFMgr.d ] || return 2
	cfmgr_launch_storage_required=0 cfmgr_launch_guard_owned=0 cfmgr_launch_retiring=0 cfmgr_launch_migrating=0 cfmgr_launch_recovery=0
	cfmgr_bootstrap_native_prepare "$1" launch || return $?
	if cfmgr_launch_work; then cfmgr_launch_status=0; else cfmgr_launch_status=$?; fi
	if [ "$cfmgr_launch_status" -ne 0 ] && [ "$cfmgr_launch_status" -ne 3 ] &&
		[ "$cfmgr_launch_storage_required" = 1 ] && [ "${cfmgr_dependencies_loss:-0}" = 0 ] && ! cfmgr_storage_attached; then
		# A resolved inventory/publication failure may also be attachment loss.
		# Reporting alone uses native/JFFS/RAM admission; no further storage work.
		cfmgr_launch_storage_required=0
		if cfmgr_launch_storage_unavailable; then :; else
			cfmgr_launch_report_code=$?
			[ "$cfmgr_launch_report_code" -ne 3 ] || cfmgr_launch_status=3
		fi
	fi
	if [ "$cfmgr_launch_status" -eq 3 ]; then
		printf '[CFMGR] launch: error: owned work unresolved; recovery required\n' >&2
		return 3
	fi
	if [ "$cfmgr_launch_recovery" = 1 ]; then
		printf '[CFMGR] launch: error: observation recovery required (%s)\n' "$cfmgr_install_context" >&2
		return "$cfmgr_launch_status"
	fi
	if ! cfmgr_bootstrap_cleanup; then
		printf '[CFMGR] launch: error: preflight cleanup pending\n' >&2
		return 3
	fi
	[ "$cfmgr_install_interrupted" = 0 ] || return 1
	trap - HUP INT TERM
	return "$cfmgr_launch_status"
}
