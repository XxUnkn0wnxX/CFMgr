#!/bin/sh
# Private immutable fixture forwarders; production policy/function bodies are
# unchanged. Firmware native path admission is adapted, real repair/full probes
# and the real installer transaction are consumed by actual native_work.
# shellcheck disable=SC2034,SC2154,SC3013
# shellcheck disable=SC1090,SC1091 # Python-built private immutable fixture assignments.
. "$dependency_install_adapter"
cp -R "$dependency_package" "$fixture/install-package"
installer_package=$fixture/install-package
mkdir -m 755 "$fixture/jffs"
# Only definition names differ in these Python-asserted private source aliases.
# shellcheck disable=SC1090
. "$dependency_repair_alias"
# shellcheck disable=SC1090
. "$dependency_probe_alias"
# shellcheck disable=SC1090
. "$dependency_bootstrap_alias"
# Restore actual public controller and transaction function name; private aliases
# retain byte-identical bodies for finite path forwarding only.
# shellcheck disable=SC1090
. "$installer_package/modules/lib/package.sh"
cfmgr_test_cost() {
	IFS=' ' read -r cfmgr_test_uptime _ < /proc/uptime
	printf 'CFMGR-TEST-COST 1 %s %s\n' "$1" "$cfmgr_test_uptime" >&2
}
cfmgr_test_cost_installer=1
# Private prerequisite alias imports restore the production /bin/usleep default.
# Reapply the explicitly selected vendor applet before any supervised operation.
cfmgr_prerequisites_pause() { "$view_ram/usleep" 10000; }
cfmgr_dependencies_repair() {
	[ "$#" = 12 ] && [ "$2" = /tmp/cfmgr ] && [ "$3" = "$installer_package" ] || return 91
	case ${cfmgr_install_dependency_action:-normal}:$1 in normal:flock | 'reinstall:jq coreutils-timeout coreutils-sha256sum flock') ;; *) return 91 ;; esac
	[ "$4:$5:$6" = /:/bin/sh:/usr/bin/env ] || return 91
	if [ "$cfmgr_test_cost_installer" = 1 ]; then cfmgr_test_cost installer-repair-begin; fi
	if cfmgr_test_real_repair "$1" "$view_ram" "$installer_package" "$view_native_root" "$view_ram/ash" "$view_ram/env" \
		"$view_ram/awk" "$view_ram/readlink" "$view_ram/usleep" "$view_ram/wc" "$view_ram/mknod" "$view_ram/chroot"; then
		cfmgr_test_status=0
	else
		cfmgr_test_status=$?
	fi
	if [ "$cfmgr_test_cost_installer" = 1 ]; then cfmgr_test_cost installer-repair-end; fi
	return "$cfmgr_test_status"
}
cfmgr_dependencies_inside_tools() { dependency_inside_tools; }
cfmgr_dependencies_native_tool() { dependency_native_tool "$@"; }
cfmgr_execution_view_native() { dependency_native "$@"; }
cfmgr_execution_tasks_native() { dependency_native "$@"; }
cfmgr_mount_keeper_native() {
	[ "$1" = fifo ] || return 2
	dependency_native fifo "$3"
}
cfmgr_dependencies_admit() { cfmgr_bootstrap_attached; }
cfmgr_bootstrap_native_admission() { return 0; }
cfmgr_bootstrap_metadata() { return 0; }
cfmgr_bootstrap_attached() {
	cfmgr_storage_attached && [ "$cfmgr_install_source" -ef "/proc/self/fd/$cfmgr_install_source_fd" ] &&
		[ "$cfmgr_install_context" -ef "/proc/self/fd/$cfmgr_install_context_fd" ]
}
cfmgr_prerequisites_admit_tool() {
	case $1 in "$installer_jq" | "$installer_timeout" | "$installer_sha" | "$cfmgr_storage_opt/bin/flock") ;; *) return 2 ;; esac
	[ -f "$1" ] && [ -x "$1" ]
}
cfmgr_prerequisites_check() {
	[ "$#" = 15 ] && { [ "$1" = shared ] || [ "$1" = tunnel ]; } && [ "$2" = "$cfmgr_install_context" ] || return 92
	installer_probe_count=$((installer_probe_count + 1))
	if [ "$cfmgr_test_cost_installer" = 1 ]; then cfmgr_test_cost "installer-check-$installer_probe_count-begin"; fi
	if cfmgr_test_real_shared_check "$1" "$2" "$view_ram/ash" "$installer_package/modules/helpers/worker.sh" \
		"$view_ram/env" "$view_ram/awk" /bin/sleep "$view_ram/wc" - "$installer_jq" "$installer_timeout" "$installer_sha" "$cfmgr_storage_opt/bin/flock" - "${15}"; then
		cfmgr_test_status=0
	else
		cfmgr_test_status=$?
	fi
	if [ "$cfmgr_test_cost_installer" = 1 ]; then cfmgr_test_cost "installer-check-$installer_probe_count-end"; fi
	return "$cfmgr_test_status"
}
cfmgr_bootstrap_transaction() {
	[ "$1:$2" = "$installer_package:/jffs" ] && [ "$installer_probe_count" = 2 ] && [ -z "$cfmgr_prereq_missing" ] || return 93
	[ "$cfmgr_dependencies_result" = repaired ] && [ "$cfmgr_view_state:$cfmgr_keeper_state" = released:released ] || return 93
	# Metadata, fixed probe supervision, publication and filesystem checks below
	# execute unchanged against explicitly owned fixture roots and actual tools.
	# shellcheck disable=SC1090
	. "$installer_package/modules/lib/package.sh"
	# shellcheck disable=SC2329 # Fixed supervisor calls this imported callback.
	cfmgr_prerequisites_pause() { "$view_ram/usleep" 10000; }
	# shellcheck disable=SC2329 # The imported actual transaction invokes this callback.
	cfmgr_bootstrap_attached() {
		cfmgr_storage_attached && [ "$cfmgr_install_source" -ef /proc/self/fd/9 ] && [ "$cfmgr_install_jffs" -ef /proc/self/fd/8 ] &&
			[ "$cfmgr_install_context" -ef /proc/self/fd/5 ]
	}
	if [ "$cfmgr_test_cost_installer" = 1 ]; then cfmgr_test_cost installer-transaction-begin; fi
	if cfmgr_test_real_transaction "$installer_package" "$fixture/jffs" "$cfmgr_storage_opt" "$cfmgr_install_context" 0 \
		"$view_ram/ash" "$installer_env" "$installer_awk" "$installer_readlink" "$installer_sleep" "$installer_wc" "$installer_ls" "$installer_fsync" \
		"$installer_mkdir" "$installer_cp" "$installer_chmod" "$installer_mv" "$installer_sha" "$installer_jq" \
		"$cfmgr_storage_uuid_value" "$cfmgr_storage_filesystem" "$cfmgr_storage_fsroot" "$cfmgr_storage_relative" "$installer_df"; then
		cfmgr_test_status=0
	else
		cfmgr_test_status=$?
	fi
	if [ "$cfmgr_test_cost_installer" = 1 ]; then cfmgr_test_cost installer-transaction-end; fi
	return "$cfmgr_test_status"
}
installer_probe_count=0
CFMGR_VERSION=0.1.0 CFMGR_REPOSITORY=https://github.com/example/fixture CFMGR_BRANCH=fixture
cfmgr_install_context=$view_ram/preflight-installer cfmgr_install_private_context=$view_ram/preflight-installer
mkdir -m 700 "$cfmgr_install_context"
cfmgr_install_source=$installer_package cfmgr_install_source_fd=9 cfmgr_install_context_fd=0
cfmgr_install_jffs=$fixture/jffs cfmgr_install_opt=$cfmgr_storage_opt cfmgr_install_owner=0
cfmgr_install_sha=$installer_sha cfmgr_install_jq=$installer_jq cfmgr_install_df=$installer_df
cfmgr_install_mv=$installer_mv cfmgr_install_fsync=$installer_fsync
cfmgr_install_nvram=$view_ram/nvram
printf '#!/bin/sh\nprintf "1\\n"\n' > "$cfmgr_install_nvram"
chmod 755 "$cfmgr_install_nvram"
exec 0< "$cfmgr_install_context" 8< "$fixture/jffs" 9< "$installer_package"
if [ -n "${dependency_retained_fixture:-}" ]; then
	cfmgr_test_cost_installer=0
	# Fixed Python-admitted fixture extension, no production environment override.
	# shellcheck disable=SC1090
	. "$dependency_retained_fixture"
	return 0
fi
cfmgr_bootstrap_native_work || fail "actual native_work repair/publication failed phase=${cfmgr_dependencies_phase:-unknown}"
[ "$(cat "$fixture/jffs/addons/CFMgr.d/setup-state")" = 'CFMGR-SETUP 1 0.1.0 complete' ] || fail 'unchanged transaction did not publish complete setup'
cmp "$installer_package/cfmgr.sh" "$fixture/jffs/scripts/cfmgr.sh" || fail 'installer published different entry'
if [ ! -e "$view_ram/dependencies" ] && [ -f "$cfmgr_storage_opt/bin/flock" ]; then :; else fail 'installer repair did not clean its worker/install selected tool'; fi
cfmgr_bootstrap_cleanup || fail 'installer post-probe context did not clean'
exec 8<&- 9<&-
printf 'PASS: actual installer repair, fresh full probes and unchanged transaction\n'
