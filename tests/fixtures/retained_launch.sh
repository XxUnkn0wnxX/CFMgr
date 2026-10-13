#!/bin/sh
# Extension of the existing private PID/mount/ext4 installer fixture. Installed
# layout is seeded from the real package; actual launch/repair/post-probes run.
# Fixed firmware roots/native admission are caller adapters, never product env.
# shellcheck disable=SC2034,SC2154,SC3013,SC1090,SC1091
. "$installer_package/modules/helpers/launch.sh"
retained_support=$fixture/jffs/addons/CFMgr.d
mkdir -p "$fixture/jffs/addons" "$fixture/jffs/scripts"
mkdir -m 700 "$retained_support"
cp -R "$installer_package/modules" "$retained_support/modules"
cp "$installer_package/catalog.txt" "$installer_package/manifest.txt" "$retained_support/"
cp "$installer_package/cfmgr.sh" "$fixture/jffs/scripts/cfmgr.sh"
printf 'CFMGR-SETUP 1 0.1.0 complete\n' >"$retained_support/setup-state"
# Synthetic retained settings preserve unrelated history/credentials; no feature creation.
# shellcheck disable=SC2016 # Literal jq program, fixed data via --arg.
"$installer_jq" -n -c --arg uuid "$cfmgr_storage_uuid_value" --arg filesystem "$cfmgr_storage_filesystem" \
	--arg root "$cfmgr_storage_fsroot" --arg relative "$cfmgr_storage_relative" '
 {schema:1,generation:19,manager:{check_updates:false,auto_update:false,developer:false,developer_log_directory:null,
 source:{repository:"https://github.com/example/fixture",branch:"fixture",commit:""}},
 storage:{entware:{uuid:$uuid,filesystem:$filesystem,root:$root,relative:$relative}},
 ddns:{configured:true,enabled:false,credentials:"synthetic-kept",records:[],proxied:null},
 ip_sync:{configured:false,enabled:false,credentials:null,targets:[]},
 cloudflared:{configured:true,enabled:false,installed:false,maintenance_enabled:false,binary_auto_update:null,
 credential_refs:{runtime:null,management:null,certificate:null}},
 logging:{ddns:{configured:false,enabled:false,opt_out:false,policy:null},
 ip_sync:{configured:false,enabled:false,opt_out:false,policy:null},cloudflared:{configured:false,enabled:false,opt_out:false,policy:null}},
 history:{ddns:{kept:"history"},ip_sync:null,cloudflared:null},network:{address_family:"auto",selected_wan:null},backup:{},credentials:{},ownership:{}}
' >"$retained_support/config"
chmod 600 "$retained_support/setup-state" "$retained_support/config"
cp "$retained_support/config" "$fixture/retained.original"
installer_package=$retained_support
cfmgr_bootstrap_native_prepare() {
	[ "$#" = 2 ] && [ "$1:$2" = /jffs/addons/CFMgr.d:launch ] || return 94
	retained_attempt=$((${retained_attempt:-0} + 1))
	cfmgr_install_source=$retained_support cfmgr_install_source_fd=9 cfmgr_install_context_fd=0
	cfmgr_install_jffs=$fixture/jffs cfmgr_install_owner=0
	cfmgr_install_context=$view_ram/retained.$retained_attempt cfmgr_install_private_context=$view_ram/retained.$retained_attempt
	mkdir -m 700 "$cfmgr_install_context" || return 1
	exec 0<"$cfmgr_install_context" 8<"$fixture/jffs" 9<"$retained_support"
	cfmgr_bootstrap_signals
	cfmgr_probe_pid='' cfmgr_probe_status=invalid
}
cfmgr_bootstrap_native_attached() {
	[ "$cfmgr_install_source" -ef "/proc/self/fd/$cfmgr_install_source_fd" ] &&
		[ "$cfmgr_install_context" -ef "/proc/self/fd/$cfmgr_install_context_fd" ] &&
		[ "$cfmgr_install_jffs" -ef /proc/self/fd/8 ] || return 1
	if [ "${cfmgr_launch_migrating:-0}" = 1 ]; then cfmgr_launch_original_attached || return 1; fi
	if [ "${cfmgr_launch_guard_owned:-0}" = 1 ]; then cfmgr_launch_guard_attachment || return 1; fi
}
cfmgr_bootstrap_attached() { cfmgr_storage_attached && cfmgr_bootstrap_native_attached; }
cfmgr_storage_pin() {
	[ "$#" = 5 ] && [ "$1:$2:$3" = /opt:/usr/bin/readlink:/usr/bin/awk ] || return 95
	[ "$4:$5" = "$retained_support/modules/lib/mountinfo.awk:/proc/self" ] || return 95
	[ "${retained_absent:-0}" != 1 ] || return 1
	cfmgr_test_real_storage_pin "$cfmgr_storage_alias" "$view_ram/readlink" "$view_ram/awk" "$4" "$5"
}
cfmgr_launch_storage_unavailable() {
	printf '[CFMGR] launch: error: Entware attachment unavailable; operation stopped\n' >&2
	cfmgr_launch_logger=$retained_fixture_logger
	cfmgr_launch_action launch-report storage-unavailable || return $?
	return 1
}
retained_fixture_logger=$view_ram/retained-logger
# shellcheck disable=SC2016 # Positional argument belongs to the generated logger fixture.
printf '#!/bin/sh\nprintf "%%s\\n" "$3" >>"%s"\n' "$view_ram/retained-system-messages" >"$retained_fixture_logger"
chmod 755 "$retained_fixture_logger"
# Source wrapper is definition-only renamed and byte-verified by Python; actual
# pin implementation still validates the held ext4 device and mount identities.
. "$retained_storage_alias"
# Alias source defines only the renamed public pin; restore selected callback.
# Keep real view operations bounded in the foreground for this retained case.
cfmgr_execution_view_native() { view_native "$@"; }
cfmgr_prerequisites_pause() { "$view_ram/usleep" 10000; }
cfmgr_launch_native /jffs/addons/CFMgr.d || fail 'actual retained launch repair failed'
if [ "$installer_probe_count" = 2 ] && [ "$cfmgr_dependencies_result" = repaired ]; then :; else
	fail 'retained launch did not repair and fully re-probe'
fi
cmp "$fixture/retained.original" "$retained_support/config" || fail 'retained repair changed passive settings'
if [ ! -e "$view_ram/dependencies" ] && [ "$cfmgr_view_state:$cfmgr_keeper_state" = released:released ]; then :; else
	fail 'retained repair did not normally release protection'
fi
retained_operations=$(cat "$cfmgr_storage_opt/operations")
retained_absent=1
if cfmgr_launch_native /jffs/addons/CFMgr.d; then fail 'absent later attachment was accepted'; fi
[ -s "$view_ram/retained-system-messages" ] || fail 'absent retained launch did not submit native message'
retained_absent=0
cfmgr_launch_native /jffs/addons/CFMgr.d || fail 'returned volume was not freshly admitted'
[ "$(cat "$cfmgr_storage_opt/operations")" = "$retained_operations" ] || fail 'healthy return retried opkg unnecessarily'
cmp "$fixture/retained.original" "$retained_support/config" || fail 'return changed unrelated settings'
[ ! -e "$retained_support/.storage-observation" ] || fail 'unchanged return created observation guard'
# One explicit healthy force consumer uses the real worker/view/storage guards.
# DNS query responses are controlled adapters, not public-network evidence.
cfmgr_launch_confirm_reinstall() { return 0; }
cfmgr_bootstrap_reinstall_dns() { cfmgr_install_dns_native=srv-a-verified; }
: >"$cfmgr_storage_opt/force-fixture"
installer_probe_count=0
cfmgr_launch_native /jffs/addons/CFMgr.d reinstall || fail 'healthy explicit force consumer failed'
[ "$installer_probe_count" = 2 ] && [ "$cfmgr_dependencies_result" = repaired ] || fail 'force did not run fresh full capability probes'
[ "$(tail -n 2 "$cfmgr_storage_opt/operations")" = "$(printf 'update\nforce jq-full coreutils-timeout coreutils-sha256sum flock')" ] || fail 'force selected unrelated or incorrect direct packages'
cmp "$fixture/retained.original" "$retained_support/config" || fail 'force changed settings/history/Off'
[ ! -e "$view_ram/dependencies" ] && [ "$cfmgr_view_state:$cfmgr_keeper_state" = released:released ] || fail 'force retained resolved protection'
exec 6<&- 7<&- 8<&- 9<&-
printf 'PASS: actual retained repair, immutable migration, missing-message and returned-volume no-op\n'
printf 'PASS: actual healthy force, alternate jq-full, settings/history/Off and released guards\n'
