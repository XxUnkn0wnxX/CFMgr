#!/bin/sh
# shellcheck disable=SC2034,SC2154 # Explicit category inputs and output fields.
# Category owner: config. Sourcing defines functions only.

# ---- config ----
# Source-inert constructor for passive fresh settings. The trusted entry owns
# defaults and publication; this function only validates bounded inputs and
# emits JSON. It creates no config files, feature paths, hooks, logs, or services.

cfmgr_config_path_valid() (
	[ "$#" -eq 2 ] || return 1
	cfmgr_config_path_kind=$1
	cfmgr_config_path_value=$2
	[ -n "$cfmgr_config_path_value" ] || return 1
	[ "${#cfmgr_config_path_value}" -le 4096 ] || return 1
	case $cfmgr_config_path_value in
	*[[:cntrl:]]* | *//* | ./?* | ../?* | */./* | */../* | */. | */..) return 1 ;;
	esac
	case $cfmgr_config_path_kind in
	absolute)
		case $cfmgr_config_path_value in /*) ;; *) return 1 ;; esac
		[ "$cfmgr_config_path_value" = / ] ||
			[ "${cfmgr_config_path_value%/}" = "$cfmgr_config_path_value" ]
		;;
	relative)
		case $cfmgr_config_path_value in /* | */) return 1 ;; esac
		# A verified Entware mount may itself be the filesystem root.
		[ "$cfmgr_config_path_value" != .. ]
		;;
	*) return 1 ;;
	esac
)

# Fixed child entry for the owning supervisor. On valid arguments the process is
# replaced by jq, so the controller continues to own the actual writer PID.
cfmgr_config_defaults_exec() {
	[ "$#" -eq 7 ] || return 2
	cfmgr_config_jq=$1
	cfmgr_config_repository=$2
	cfmgr_config_branch=$3
	cfmgr_config_uuid=$4
	cfmgr_config_filesystem=$5
	cfmgr_config_fsroot=$6
	cfmgr_config_entware_relative=$7

	case $cfmgr_config_jq in /*) ;; *) return 2 ;; esac
	[ "${#cfmgr_config_jq}" -le 4096 ] &&
		[ -f "$cfmgr_config_jq" ] && [ -x "$cfmgr_config_jq" ] || return 2

	[ -n "$cfmgr_config_repository" ] && [ "${#cfmgr_config_repository}" -le 256 ] || return 2
	case $cfmgr_config_repository in https://github.com/*/*) ;; *) return 2 ;; esac
	cfmgr_config_repo_path=${cfmgr_config_repository#https://github.com/}
	cfmgr_config_repo_owner=${cfmgr_config_repo_path%%/*}
	cfmgr_config_repo_name=${cfmgr_config_repo_path#*/}
	case $cfmgr_config_repo_owner in '' | [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*) return 2 ;; esac
	case $cfmgr_config_repo_name in '' | */* | [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*) return 2 ;; esac

	[ -n "$cfmgr_config_branch" ] && [ "${#cfmgr_config_branch}" -le 128 ] || return 2
	case $cfmgr_config_branch in
	*[!A-Za-z0-9_./-]* | . | .. | ./* | ../* | */./* | */../* | */. | */..) return 2 ;;
	esac

	[ "${#cfmgr_config_uuid}" -eq 36 ] || return 2
	cfmgr_config_uuid_a=${cfmgr_config_uuid%%-*}
	cfmgr_config_uuid_rest=${cfmgr_config_uuid#*-}
	cfmgr_config_uuid_b=${cfmgr_config_uuid_rest%%-*}
	cfmgr_config_uuid_rest=${cfmgr_config_uuid_rest#*-}
	cfmgr_config_uuid_c=${cfmgr_config_uuid_rest%%-*}
	cfmgr_config_uuid_rest=${cfmgr_config_uuid_rest#*-}
	cfmgr_config_uuid_d=${cfmgr_config_uuid_rest%%-*}
	cfmgr_config_uuid_e=${cfmgr_config_uuid_rest#*-}
	[ "${#cfmgr_config_uuid_a}" -eq 8 ] && [ "${#cfmgr_config_uuid_b}" -eq 4 ] &&
		[ "${#cfmgr_config_uuid_c}" -eq 4 ] && [ "${#cfmgr_config_uuid_d}" -eq 4 ] &&
		[ "${#cfmgr_config_uuid_e}" -eq 12 ] || return 2
	case $cfmgr_config_uuid_a$cfmgr_config_uuid_b$cfmgr_config_uuid_c$cfmgr_config_uuid_d$cfmgr_config_uuid_e in
	*[!0123456789abcdefABCDEF]*) return 2 ;;
	esac

	case $cfmgr_config_filesystem in ext2 | ext3 | ext4) ;; *) return 2 ;; esac
	cfmgr_config_path_valid absolute "$cfmgr_config_fsroot" || return 2
	cfmgr_config_path_valid relative "$cfmgr_config_entware_relative" || return 2

	# The jq program is intentionally literal; user data enters only via --arg.
	# shellcheck disable=SC2016
	exec "$cfmgr_config_jq" -n -c \
		--arg repository "$cfmgr_config_repository" \
		--arg branch "$cfmgr_config_branch" \
		--arg uuid "$cfmgr_config_uuid" \
		--arg filesystem "$cfmgr_config_filesystem" \
		--arg fsroot "$cfmgr_config_fsroot" \
		--arg entware_relative "$cfmgr_config_entware_relative" \
		'{
			"schema": 2,
			"generation": 1,
			"manager": {
				"check_updates": true,
				"auto_update": false,
				"developer": false,
				"developer_log_directory": null,
				"source": {
					"repository": $repository,
					"branch": $branch,
					"commit": ""
				}
			},
			"storage": {
				"entware": {
					"uuid": $uuid,
					"filesystem": $filesystem,
					"root": $fsroot,
					"relative": $entware_relative
				}
			},
			"ddns": {
				"configured": false,
				"enabled": false,
				"credential_ref": null,
				"zone_id": null,
				"records": [],
				"primary_hostname": null,
				"ttl": null,
				"proxied": null,
				"forced_refresh_days": 14,
				"address_family": "auto",
				"timeouts": null
			},
			"ip_sync": {
				"configured": false,
				"enabled": false,
				"credential_ref": null,
				"account_id": null,
				"targets": [],
				"address_family": "auto",
				"retry": null
			},
			"cloudflared": {
				"configured": false,
				"enabled": false,
				"installed": false,
				"maintenance_enabled": false,
				"method": null,
				"expected_identity": {"account_id": null, "tunnel_id": null},
				"paths": {"yaml": null, "json": null, "certificate": null},
				"credential_refs": {
					"runtime": null,
					"management": null,
					"certificate": null,
					"dns": null
				},
				"binary_auto_update": null,
				"readiness": null,
				"watchdog": null
			},
			"network": {
				"address_family": "auto",
				"selected_wan": null,
				"discovery": null
			},
			"logging": {
				"ddns": {
					"configured": false,
					"enabled": false,
					"opt_out": false,
					"policy": null
				},
				"ip_sync": {
					"configured": false,
					"enabled": false,
					"opt_out": false,
					"policy": null
				},
				"cloudflared": {
					"configured": false,
					"enabled": false,
					"opt_out": false,
					"policy": null
				}
			},
			"backup": {
				"destination": null,
				"set_id": null,
				"retention": null,
				"date_format": null,
				"last_backup": null
			},
			"credentials": {},
			"ownership": {"schema": 1, "components": [], "migration": null},
			"history": {
				"ddns": null,
				"ip_sync": null,
				"cloudflared": null
			}
		}'
}

cfmgr_config_defaults() (
	if cfmgr_config_json=$(cfmgr_config_defaults_exec "$@"); then
		[ -n "$cfmgr_config_json" ] || return 1
		printf '%s\n' "$cfmgr_config_json"
	else
		return $?
	fi
)

# ---- config store ----
# Source-inert native settings store plus cooperative operational writer lock.
# Settings never admit Entware or providers; observation keeps its admitted flock.
# Public API: read | save check|auto|both CHECK(0|1) AUTO(0|1) | recover.
# Exactly one CFMGR-STORE v1 receipt describes the result, never status0 alone.
# The transaction subshell owns FD0 lock, FD3 flush, FD4 guard, FD5 RAM,
# FD8 JFFS and FD9 support. UI stdin and caller state remain untouched.
# Cooperative lock + immediate raw freshness checks are not CAS against root
# editors. Same-mount publication/fsync is representative proof, not JFFS2 beta.
# shellcheck disable=SC2030,SC2031,SC2034,SC2154,SC3013
# Helpers run inside the API subshell; observation initializes its own borrowed state.
cfmgr_config_store() (
	cfmgr_store_scope=settings cfmgr_store_backup_gate=0 cfmgr_store_archive_lock_held=0
	cfmgr_store_result=unavailable cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0
	cfmgr_store_pending=0 cfmgr_config_lock_fd0=0 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0 cfmgr_store_flock_entware=0
	case ${1:-}:$# in read:1 | recover:1) ;; save:4)
		case $2:$3:$4 in check:[01]:[01] | auto:[01]:[01] | both:[01]:[01]) ;; *) exit 2 ;; esac
		[ "$2:$3:$4" != both:0:1 ] || exit 2
		;;
	*) exit 2 ;;
	esac
	cfmgr_store_operation=$1 cfmgr_store_mask=${2:-both} cfmgr_store_want_check=${3:-0} cfmgr_store_want_auto=${4:-0}
	if cfmgr_store_prepare && cfmgr_store_work; then cfmgr_store_code=0; else cfmgr_store_code=$?; fi
	if [ "$cfmgr_store_code" = 3 ]; then
		cfmgr_store_result=unresolved cfmgr_store_pending=1
	else
		# Release by close after reap, never unlock a child's shared description.
		exec 0<&-
		cfmgr_config_lock_fd0=0 cfmgr_store_interrupt=0
		if [ -n "${cfmgr_store_context:-}" ] && ! cfmgr_store_cleanup; then
			cfmgr_store_result=recovery cfmgr_store_code=1 cfmgr_store_pending=1
		fi
	fi
	[ "$cfmgr_store_code" != 4 ] || cfmgr_store_code=1
	if [ "$cfmgr_store_code" != 0 ]; then cfmgr_store_generation=0 cfmgr_store_check=0 cfmgr_store_auto=0 cfmgr_store_developer=0; fi
	printf 'CFMGR-STORE 1 %s %s %s %s %s %s END\n' "$cfmgr_store_result" "$cfmgr_store_generation" "$cfmgr_store_check" "$cfmgr_store_auto" "$cfmgr_store_developer" "$cfmgr_store_pending"
	exit "$cfmgr_store_code"
)

cfmgr_store_prepare() {
	cfmgr_store_source=/jffs/addons/CFMgr.d cfmgr_store_jffs=/jffs cfmgr_store_ram=/tmp/cfmgr
	cfmgr_store_live=$cfmgr_store_source/config cfmgr_store_lock=$cfmgr_store_ram/config.lock
	cfmgr_store_sh=/bin/sh cfmgr_store_env=/usr/bin/env cfmgr_store_awk=/usr/bin/awk cfmgr_store_readlink=/usr/bin/readlink
	cfmgr_store_wc=/usr/bin/wc cfmgr_store_ls=/bin/ls cfmgr_store_sleep=/bin/sleep cfmgr_store_flock=/usr/bin/flock
	cfmgr_store_openssl=/usr/sbin/openssl cfmgr_store_dd=/bin/dd cfmgr_store_cp=/bin/cp cfmgr_store_mv=/bin/mv cfmgr_store_fsync=/bin/fsync
	for cfmgr_store_path in /jffs /jffs/addons "$cfmgr_store_source" /tmp; do
		[ -d "$cfmgr_store_path" ] && [ ! -L "$cfmgr_store_path" ] && [ "$(/usr/bin/readlink -f "$cfmgr_store_path")" = "$cfmgr_store_path" ] || return 1
	done
	# Trusted entry admits this library and prerequisites before source. Store
	# independently protects every fixed file it will execute/read as code.
	for cfmgr_store_code_path in "$cfmgr_store_source/modules/helpers/worker.sh" "$cfmgr_store_source/modules/lib/config.sh" "$cfmgr_store_source/modules/lib/storage.sh"; do
		cfmgr_store_protected "$cfmgr_store_code_path" || return 1
	done
	for cfmgr_store_tool_path in "$cfmgr_store_sh" "$cfmgr_store_env" "$cfmgr_store_awk" "$cfmgr_store_readlink" "$cfmgr_store_wc" "$cfmgr_store_ls" "$cfmgr_store_sleep" "$cfmgr_store_dd" "$cfmgr_store_cp" "$cfmgr_store_mv" "$cfmgr_store_fsync" /bin/mkdir /bin/rm /bin/rmdir /bin/df /bin/usleep; do
		cfmgr_store_native_tool "$cfmgr_store_tool_path" || return 1
	done
	cfmgr_store_jffs_mount=$(cfmgr_storage_mountinfo /usr/bin/awk /jffs /proc/self/mountinfo) || return 1
	cfmgr_store_tmp_mount=$(cfmgr_storage_mountinfo /usr/bin/awk /tmp /proc/self/mountinfo) || return 1
	IFS='	' read -r cfmgr_store_id cfmgr_store_parent cfmgr_store_device cfmgr_store_root cfmgr_store_point cfmgr_store_type cfmgr_store_mount_source cfmgr_store_mount_flags cfmgr_store_mount_super <<EOF_JFFS
$cfmgr_store_jffs_mount
EOF_JFFS
	[ "$cfmgr_store_point:$cfmgr_store_type" = /jffs:jffs2 ] && cfmgr_store_mount_writable || return 1
	IFS='	' read -r cfmgr_store_id cfmgr_store_parent cfmgr_store_device cfmgr_store_root cfmgr_store_point cfmgr_store_type cfmgr_store_mount_source cfmgr_store_mount_flags cfmgr_store_mount_super <<EOF_RAM
$cfmgr_store_tmp_mount
EOF_RAM
	case $cfmgr_store_type in tmpfs | ramfs | rootfs) ;; *) return 1 ;; esac
	cfmgr_store_mount_writable || return 1
	[ "$(cfmgr_storage_mountinfo /usr/bin/awk "$cfmgr_store_source" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] || return 1
	if [ ! -e "$cfmgr_store_ram" ] && [ ! -L "$cfmgr_store_ram" ]; then /bin/mkdir -m 700 "$cfmgr_store_ram" || return 1; fi
	cfmgr_store_admit_private "$cfmgr_store_ram" directory && cfmgr_store_admit_private "$cfmgr_store_source" directory || return 1
	IFS= read -r cfmgr_store_self </proc/self/stat || return 1
	cfmgr_store_pid=${cfmgr_store_self%% *}
	cfmgr_prerequisites_identity "$cfmgr_store_pid" || return 1
	cfmgr_store_context=$cfmgr_store_ram/settings.$cfmgr_store_pid.$cfmgr_identity_start
	umask 077
	/bin/mkdir -m 700 "$cfmgr_store_context" || return 1
	exec 5<"$cfmgr_store_context" 8<"$cfmgr_store_jffs" 9<"$cfmgr_store_source" || return 3
	cfmgr_store_context_fd=5 cfmgr_store_borrowed=0 cfmgr_probe_pid='' cfmgr_probe_serial=0
	trap 'cfmgr_store_interrupt=1' HUP INT TERM
	cfmgr_prerequisites_now || return 1
	cfmgr_store_deadline=$((cfmgr_probe_now + 20))
}

# Fixed root/native metadata admission before acquiring the RAM lock. It never
# changes modes or follows a caller/config-selected executable or symlink.
cfmgr_store_admit_private() {
	[ ! -L "$1" ] || return 1
	cfmgr_store_metadata=$(/bin/ls -ldn "$1") || return 1
	IFS=' ' read -r cfmgr_store_mode cfmgr_store_links cfmgr_store_uid cfmgr_store_rest <<EOF_MODE
$cfmgr_store_metadata
EOF_MODE
	case $2:$cfmgr_store_mode:$cfmgr_store_uid in directory:drwx------:0 | file:-rw-------:0) return 0 ;; *) return 1 ;; esac
}

cfmgr_store_mount_writable() {
	case ,$cfmgr_store_mount_flags, in *,rw,*) ;; *) return 1 ;; esac
	case ,$cfmgr_store_mount_super, in *,rw,*) ;; *) return 1 ;; esac
}

cfmgr_store_protected() {
	cfmgr_store_protected_path=$1
	while :; do
		[ ! -L "$cfmgr_store_protected_path" ] || return 1
		cfmgr_store_protected_meta=$("$cfmgr_store_ls" -ldn "$cfmgr_store_protected_path") || return 1
		IFS=' ' read -r cfmgr_store_protected_mode cfmgr_store_protected_links cfmgr_store_protected_uid cfmgr_store_rest <<EOF_PROTECTED
$cfmgr_store_protected_meta
EOF_PROTECTED
		[ "$cfmgr_store_protected_uid" = 0 ] || return 1
		case $cfmgr_store_protected_mode in -????????? | d?????????) ;; *) return 1 ;; esac
		case $cfmgr_store_protected_mode in ?????w???? | ????????w?) return 1 ;; esac
		[ "$cfmgr_store_protected_path" != / ] || break
		cfmgr_store_protected_path=${cfmgr_store_protected_path%/*}
		[ -n "$cfmgr_store_protected_path" ] || cfmgr_store_protected_path=/
	done
}

cfmgr_store_fd_is() { [ ! -L "$1" ] && [ "$1" -ef "/proc/self/fd/$2" ]; }

cfmgr_store_attachment_ok() {
	if [ "${cfmgr_store_borrowed:-0}" = 1 ]; then cfmgr_launch_attachment_ok || return 1; fi
	[ "$cfmgr_store_interrupt" = 0 ] && cfmgr_store_fd_is "$cfmgr_store_context" "$cfmgr_store_context_fd" &&
		cfmgr_store_fd_is "$cfmgr_store_source" 9 && cfmgr_store_fd_is "$cfmgr_store_jffs" 8 || return 1
	[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_store_source" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] &&
		[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_store_jffs" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] &&
		[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" /tmp /proc/self/mountinfo)" = "$cfmgr_store_tmp_mount" ] || return 1
	if [ "$cfmgr_config_lock_fd0" = 1 ]; then cfmgr_store_fd_is "$cfmgr_store_lock" 0 || return 1; fi
	if [ "${cfmgr_store_backup_gate:-0}" = 1 ]; then cfmgr_backup_attached || return 1; fi
	if [ "$cfmgr_store_guard_owned" = 1 ]; then
		[ "$(cfmgr_storage_mountinfo "$cfmgr_store_awk" "$cfmgr_store_guard" /proc/self/mountinfo)" = "$cfmgr_store_jffs_mount" ] || return 1
		if cfmgr_store_fd_is "$cfmgr_store_guard" 4; then
			:
		elif [ -n "${cfmgr_store_guard_next:-}" ] && [ "${cfmgr_probe_mode:-}" = store-move ] && cfmgr_store_fd_is "$cfmgr_store_guard_next" 4; then
			:
		elif [ "${cfmgr_store_retiring:-0}:${cfmgr_probe_mode:-}" = 1:store-rmdir ] && [ -n "${cfmgr_probe_pid:-}" ]; then
			cfmgr_store_deleted=$("$cfmgr_store_ls" -Ldn /proc/self/fd/4) || return 1
			IFS=' ' read -r cfmgr_store_deleted_mode cfmgr_store_deleted_links cfmgr_store_deleted_uid cfmgr_store_rest <<EOF_DELETED
$cfmgr_store_deleted
EOF_DELETED
			[ "$cfmgr_store_deleted_mode:$cfmgr_store_deleted_links:$cfmgr_store_deleted_uid" = drwx------:0:0 ] || return 1
		else return 1; fi
	fi
}

cfmgr_store_run() {
	cfmgr_store_run_mode=$1 cfmgr_store_run_tool=$2
	shift 2
	cfmgr_store_attachment_ok || return 1
	cfmgr_prerequisites_now || return 1
	[ "$cfmgr_probe_now" -lt "$cfmgr_store_deadline" ] || return 1
	cfmgr_prerequisites_run "$cfmgr_store_run_mode" "$cfmgr_store_context" "$cfmgr_store_sh" "$cfmgr_store_source/modules/helpers/worker.sh" \
		"$cfmgr_store_env" "$cfmgr_store_awk" "$cfmgr_store_sleep" "$cfmgr_store_wc" "$cfmgr_store_run_tool" "$@" || return $?
	[ "$cfmgr_probe_exit" = 0 ] && [ ! -s "$cfmgr_probe_stderr" ]
}

cfmgr_store_read_line() {
	cfmgr_store_line='' cfmgr_store_tail=''
	{
		IFS= read -r cfmgr_store_line || return 1
		if IFS= read -r cfmgr_store_tail; then return 1; fi
		[ -z "$cfmgr_store_tail" ]
	} <"$1"
}

cfmgr_store_count() {
	cfmgr_store_run store-count "$cfmgr_store_wc" "$1" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_store_bytes cfmgr_store_extra <<EOF_COUNT
$cfmgr_store_line
EOF_COUNT
	case $cfmgr_store_bytes:$cfmgr_store_extra in *[!0-9:]*) return 1 ;; esac
	[ -n "$cfmgr_store_bytes" ] && [ -z "$cfmgr_store_extra" ] && [ "${#cfmgr_store_bytes}" -le 6 ] && [ "$cfmgr_store_bytes" -le 65536 ]
}

cfmgr_store_metadata() {
	cfmgr_store_run store-meta "$cfmgr_store_ls" "$1" || return $?
	cfmgr_store_meta_raw=$cfmgr_probe_stdout
	cfmgr_store_run store-meta-frame "$cfmgr_store_awk" "$cfmgr_store_meta_raw" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_store_meta=$cfmgr_store_line
}

cfmgr_store_snapshot() {
	cfmgr_store_snapshot_source=$1
	cfmgr_store_metadata "$cfmgr_store_snapshot_source" || return $?
	cfmgr_store_snapshot_meta=$cfmgr_store_meta
	cfmgr_store_run store-snapshot "$cfmgr_store_dd" "$1" || return $?
	cfmgr_store_snapshot=$cfmgr_probe_stdout
	cfmgr_store_count "$cfmgr_store_snapshot" || return $?
	[ "$cfmgr_store_bytes" -gt 0 ] || return 1
	cfmgr_store_snapshot_bytes=$cfmgr_store_bytes
	[ "$cfmgr_store_snapshot_bytes" = "${cfmgr_store_snapshot_meta#*:}" ] || return 1
	cfmgr_store_metadata "$cfmgr_store_snapshot_source" || return $?
	[ "$cfmgr_store_snapshot_meta" = "$cfmgr_store_meta" ]
}

cfmgr_store_parse() {
	if [ "${cfmgr_store_scope:-settings}" = backup ] && [ "$1" != settings-read ]; then
		case $1 in settings-observe) cfmgr_store_backup_mode=backup-observe ;; settings-patch) cfmgr_store_backup_mode=backup-patch ;; *) return 2 ;; esac
		cfmgr_store_backup_parse "$cfmgr_store_backup_mode" "$2" "$3"
		return $?
	fi
	case ${cfmgr_store_scope:-settings} in
	archive-preferences | archive-history)
		case $1 in
		settings-read) ;;
		settings-observe | settings-patch)
			cfmgr_store_archive_parse "$cfmgr_store_scope-${1#settings-}" "$2" "$3"
			return $?
			;;
		*) return 2 ;;
		esac
		;;
	esac
	cfmgr_store_run store-settings "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/config.sh" "$cfmgr_store_source/modules/lib/config.sh" \
		"$1" "$2" "$3" "$cfmgr_store_mask" "$cfmgr_store_want_check" "$cfmgr_store_want_auto"
}

# Internal same-context API. Only the backup action owns initialization/cleanup;
# never call the public store recursively or reset its whole-action deadline.
cfmgr_store_backup_parse() {
	cfmgr_store_run store-backup-config "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/config.sh" "$cfmgr_store_source/modules/lib/config.sh" \
		"$1" "$2" "$3" "${cfmgr_backup_want_mount:-}" "${cfmgr_backup_want_uuid:-}" "${cfmgr_backup_want_filesystem:-}" "${cfmgr_backup_want_root:-}"
}

cfmgr_store_backup_read() {
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	cfmgr_store_backup_parse backup-read "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_backup_tag cfmgr_backup_schema cfmgr_store_generation cfmgr_backup_saved_present \
		cfmgr_backup_saved_mount_hex cfmgr_backup_saved_uuid_hex cfmgr_backup_saved_filesystem_hex cfmgr_backup_saved_root_hex cfmgr_backup_end cfmgr_backup_extra <<EOF_BACKUP_CONFIG
$cfmgr_store_line
EOF_BACKUP_CONFIG
	[ "$cfmgr_backup_tag:$cfmgr_backup_schema:$cfmgr_backup_end:$cfmgr_backup_extra" = CFMGR-BACKUP-CONFIG:1:END: ] || return 1
	case $cfmgr_backup_saved_present in
	0) [ "$cfmgr_store_line" = "CFMGR-BACKUP-CONFIG 1 $cfmgr_store_generation 0 - - - - END" ] ;;
	1)
		cfmgr_backup_decode "$cfmgr_backup_saved_mount_hex" >/dev/null && cfmgr_backup_decode "$cfmgr_backup_saved_uuid_hex" >/dev/null &&
			cfmgr_backup_decode "$cfmgr_backup_saved_filesystem_hex" >/dev/null && cfmgr_backup_decode "$cfmgr_backup_saved_root_hex" >/dev/null
		;;
	*) return 1 ;;
	esac
}

cfmgr_store_backup_save() {
	cfmgr_store_scope=backup cfmgr_store_operation=save
	cfmgr_store_mask=both cfmgr_store_want_check=0 cfmgr_store_want_auto=0
	cfmgr_store_work
}

# Archive settings/history are scopes of this same transaction. The controller
# owns context/cleanup, explicit selected values and any stable-ID generation.
cfmgr_store_archive_parse() {
	cfmgr_store_run store-archive-config "$cfmgr_store_awk" "$cfmgr_store_source/modules/lib/config.sh" "$cfmgr_store_source/modules/lib/config.sh" \
		"$1" "$2" "$3" "${cfmgr_archive_want_format:-}" "${cfmgr_archive_want_keep:-}" "${cfmgr_archive_want_set_id:-}" \
		"${cfmgr_archive_want_id:-}" "${cfmgr_archive_want_at:-}" "${cfmgr_archive_want_date:-}" "${cfmgr_archive_want_time:-}" \
		"${cfmgr_archive_want_zone:-}" "${cfmgr_archive_want_generation:-}"
}

cfmgr_store_archive_read() {
	[ "$#" = 0 ] || return 2
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	cfmgr_store_archive_parse archive-read "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_store_archive_tag cfmgr_store_archive_version cfmgr_store_archive_schema cfmgr_store_archive_generation cfmgr_store_archive_format cfmgr_store_archive_keep cfmgr_store_archive_set cfmgr_store_archive_end cfmgr_store_archive_extra <<EOF_ARCHIVE_CONFIG
$cfmgr_store_line
EOF_ARCHIVE_CONFIG
	[ "$cfmgr_store_archive_tag:$cfmgr_store_archive_version:$cfmgr_store_archive_end:$cfmgr_store_archive_extra" = CFMGR-ARCHIVE-CONFIG:1:END: ] || return 1
	case $cfmgr_store_archive_schema in 1 | 2) ;; *) return 1 ;; esac
	case $cfmgr_store_archive_generation in '' | 0* | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_store_archive_generation}" -le 20 ] || return 1
	case $cfmgr_store_archive_format in - | DMY | MDY | YMD) ;; *) return 1 ;; esac
	case $cfmgr_store_archive_keep in 0 | 3 | 4 | 5) ;; *) return 1 ;; esac
	if [ "$cfmgr_store_archive_set" != - ]; then
		case $cfmgr_store_archive_set in *[!0-9a-f-]*) return 1 ;; esac
		IFS=- read -r cfmgr_store_archive_u1 cfmgr_store_archive_u2 cfmgr_store_archive_u3 cfmgr_store_archive_u4 cfmgr_store_archive_u5 cfmgr_store_archive_u6 <<EOF_ARCHIVE_UUID
$cfmgr_store_archive_set
EOF_ARCHIVE_UUID
		[ "${#cfmgr_store_archive_u1}:${#cfmgr_store_archive_u2}:${#cfmgr_store_archive_u3}:${#cfmgr_store_archive_u4}:${#cfmgr_store_archive_u5}:${#cfmgr_store_archive_u6}" = 8:4:4:4:12:0 ] && [ "${#cfmgr_store_archive_set}" = 36 ] || return 1
	fi
	[ "$cfmgr_store_line" = "CFMGR-ARCHIVE-CONFIG 1 $cfmgr_store_archive_schema $cfmgr_store_archive_generation $cfmgr_store_archive_format $cfmgr_store_archive_keep $cfmgr_store_archive_set END" ] || return 1
	cfmgr_archive_saved_schema=$cfmgr_store_archive_schema cfmgr_archive_saved_generation=$cfmgr_store_archive_generation
	cfmgr_archive_saved_format=$cfmgr_store_archive_format cfmgr_archive_saved_keep=$cfmgr_store_archive_keep cfmgr_archive_saved_set_id=$cfmgr_store_archive_set
}

cfmgr_store_archive_save() {
	[ "$#" = 1 ] || return 2
	case $1 in preferences | history) ;; *) return 2 ;; esac
	# Flush3 and guard4 must not replace source/rotation ownership. Neither this
	# same-context API nor its caller's already-held lock is implicitly reset.
	if (: <&3) 2>/dev/null || (: <&4) 2>/dev/null; then return 2; fi
	[ "${cfmgr_store_guard_owned:-0}" = 0 ] || return 2
	case ${cfmgr_store_archive_lock_held:-0}:${cfmgr_config_lock_fd0:-0} in 0:0 | 1:1) ;; *) return 2 ;; esac
	cfmgr_store_scope=archive-$1 cfmgr_store_operation=save
	cfmgr_store_mask=both cfmgr_store_want_check=0 cfmgr_store_want_auto=0
	cfmgr_store_work
}

cfmgr_store_archive_borrow_lock() {
	# The trusted archive controller acquired this exact context's FD0 once.
	# Do not reopen or acquire it here. A fresh independent open must contend.
	[ "${cfmgr_store_archive_lock_held:-0}:${cfmgr_config_lock_fd0:-0}:${cfmgr_store_guard_owned:-0}" = 1:1:0 ] &&
		cfmgr_store_attachment_ok && cfmgr_store_fd_is "$cfmgr_store_lock" 0 || return 1
	cfmgr_store_admit_private "$cfmgr_store_lock" file || return 1
	if [ "${cfmgr_store_flock_entware:-0}" = 1 ]; then
		cfmgr_prerequisites_admit_tool "$cfmgr_store_flock" || return $?
	else cfmgr_store_native_tool "$cfmgr_store_flock" || return 1; fi
	cfmgr_store_lock_excludes_fresh_open
}

cfmgr_store_archive_digest_admit() {
	# One archive action can Save preferences, then history in this context.
	# Revalidate the retained private known vector; ordinary Store admission
	# keeps its original exclusive-create behavior and never trusts this cache.
	if [ -e "$cfmgr_store_context/sha-vector" ] || [ -L "$cfmgr_store_context/sha-vector" ]; then
		cfmgr_store_native_tool "$cfmgr_store_openssl" && cfmgr_store_admit_private "$cfmgr_store_context/sha-vector" file || return 1
		cfmgr_store_count "$cfmgr_store_context/sha-vector" || return $?
		[ "$cfmgr_store_bytes" = 3 ] || return 1
		cfmgr_store_digest "$cfmgr_store_context/sha-vector" || return $?
		[ "$cfmgr_store_digest_value" = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]
	else cfmgr_store_digest_admit; fi
}

cfmgr_store_target_matches() {
	cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
	[ "$cfmgr_store_generation:$cfmgr_store_check:$cfmgr_store_auto:$cfmgr_store_developer" = "$cfmgr_store_new:$cfmgr_store_target_check:$cfmgr_store_target_auto:$cfmgr_store_target_dev" ] || return 1
	if [ "${cfmgr_store_scope:-settings}" = backup ]; then
		cfmgr_store_backup_parse backup-observe "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		[ "$cfmgr_store_line" = "CFMGR-BACKUP-PATCH 1 $cfmgr_store_new $cfmgr_store_new 0 $cfmgr_store_target_check $cfmgr_store_target_auto $cfmgr_store_target_dev $cfmgr_store_target_bytes $cfmgr_store_target_bytes END" ] || return 1
	fi
	case ${cfmgr_store_scope:-settings} in
	archive-preferences | archive-history)
		cfmgr_store_archive_parse "$cfmgr_store_scope-observe" "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		[ "$cfmgr_store_line" = "CFMGR-ARCHIVE-PATCH 1 $cfmgr_store_new $cfmgr_store_new 0 $cfmgr_store_target_check $cfmgr_store_target_auto $cfmgr_store_target_dev $cfmgr_store_target_bytes $cfmgr_store_target_bytes END" ] || return 1
		;;
	esac
}

cfmgr_store_flags() {
	cfmgr_store_parse settings-read "$1" "$2" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	IFS=' ' read -r cfmgr_store_tag cfmgr_store_schema cfmgr_store_generation cfmgr_store_check cfmgr_store_auto cfmgr_store_developer cfmgr_store_end cfmgr_store_extra <<EOF_FLAGS
$cfmgr_store_line
EOF_FLAGS
	[ "$cfmgr_store_tag:$cfmgr_store_schema:$cfmgr_store_end:$cfmgr_store_extra" = CFMGR-SETTINGS:1:END: ] || return 1
	case $cfmgr_store_generation in '' | 0* | *[!0-9]*) return 1 ;; esac
	[ "${#cfmgr_store_generation}" -le 20 ] || return 1
	case $cfmgr_store_check:$cfmgr_store_auto:$cfmgr_store_developer in [01]:[01]:[01]) ;; *) return 1 ;; esac
	[ "$cfmgr_store_line" = "CFMGR-SETTINGS 1 $cfmgr_store_generation $cfmgr_store_check $cfmgr_store_auto $cfmgr_store_developer END" ]
}

cfmgr_store_native_tool() {
	[ -f "$1" ] && [ -x "$1" ] || return 1
	cfmgr_store_tool_target=$("$cfmgr_store_readlink" -f "$1") || return 1
	case $cfmgr_store_tool_target in "$1" | /bin/busybox) ;; *) return 1 ;; esac
	cfmgr_store_tool_metadata=$("$cfmgr_store_ls" -ldn "$cfmgr_store_tool_target") || return 1
	IFS=' ' read -r cfmgr_store_tool_mode cfmgr_store_tool_links cfmgr_store_tool_uid cfmgr_store_rest <<EOF_TOOL
$cfmgr_store_tool_metadata
EOF_TOOL
	[ "$cfmgr_store_tool_uid" = 0 ] || return 1
	case $cfmgr_store_tool_mode in -?????????) ;; *) return 1 ;; esac
	case $cfmgr_store_tool_mode in ?????w???? | ????????w?) return 1 ;; esac
	cfmgr_store_protected "$cfmgr_store_tool_target"
}

cfmgr_store_digest_admit() {
	cfmgr_store_native_tool "$cfmgr_store_openssl" || return 1
	(
		umask 077
		set -C
		printf abc >"$cfmgr_store_context/sha-vector"
	) || return 1
	cfmgr_store_digest "$cfmgr_store_context/sha-vector" || return $?
	[ "$cfmgr_store_digest_value" = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad ]
}

cfmgr_store_digest() {
	cfmgr_store_run store-digest "$cfmgr_store_openssl" "$1" || return $?
	cfmgr_store_digest_raw=$cfmgr_probe_stdout
	cfmgr_store_count "$cfmgr_store_digest_raw" || return $?
	[ "$cfmgr_store_bytes" = 72 ] || return 1
	cfmgr_store_run store-digest-frame "$cfmgr_store_awk" "$cfmgr_store_digest_raw" || return $?
	cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
	cfmgr_store_digest_value=$cfmgr_store_line
	[ "${#cfmgr_store_digest_value}" = 64 ] || return 1
	case $cfmgr_store_digest_value in *[!0-9a-f]*) return 1 ;; esac
}

cfmgr_store_pending() {
	cfmgr_store_pending=0
	for cfmgr_store_phase in .storage-observation .config-save.preparing .config-save .config-save.retired; do
		if [ -e "$cfmgr_store_source/$cfmgr_store_phase" ] || [ -L "$cfmgr_store_source/$cfmgr_store_phase" ]; then cfmgr_store_pending=1; fi
	done
}

cfmgr_store_lock_acquire() {
	if [ "${cfmgr_store_flock_entware:-0}" = 1 ]; then
		cfmgr_prerequisites_admit_tool "$cfmgr_store_flock" || return $?
	else cfmgr_store_native_tool "$cfmgr_store_flock" || return 1; fi
	cfmgr_store_run store-lock-create "$cfmgr_store_sh" "$cfmgr_store_lock" || return $?
	cfmgr_store_admit_private "$cfmgr_store_lock" file || return 1
	exec 0<>"$cfmgr_store_lock" || return 1
	cfmgr_config_lock_fd0=1
	cfmgr_store_fd_is "$cfmgr_store_lock" 0 || return 1
	if cfmgr_store_run store-lock "$cfmgr_store_flock"; then :; else
		cfmgr_store_lock_code=$?
		[ "$cfmgr_store_lock_code" != 3 ] || return 3
		if [ "$cfmgr_probe_mode:${cfmgr_probe_status:-}:$cfmgr_probe_exit:${cfmgr_probe_reason:-}" = store-lock:reaped:1: ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]; then cfmgr_store_result=busy; fi
		return 1
	fi
	# A fresh independent open must contend AFTER the helper that acquired the
	# inherited description exits. This admits semantics, not executability alone.
	cfmgr_store_lock_excludes_fresh_open
}

cfmgr_store_lock_excludes_fresh_open() {
	if cfmgr_store_run store-lock-test "$cfmgr_store_flock" "$cfmgr_store_lock"; then return 1; else
		cfmgr_store_lock_code=$?
		[ "$cfmgr_store_lock_code" != 3 ] || return 3
	fi
	[ "$cfmgr_probe_mode:${cfmgr_probe_status:-}:$cfmgr_probe_exit:${cfmgr_probe_reason:-}" = store-lock-test:reaped:1: ] && [ ! -s "$cfmgr_probe_stderr" ] && [ ! -s "$cfmgr_probe_stdout" ]
}

cfmgr_store_flush() {
	cfmgr_store_attachment_ok || return 1
	[ ! -L "$1" ] && { [ -f "$1" ] || [ -d "$1" ]; } || return 1
	exec 3<"$1" || return 1
	if cfmgr_store_run store-flush "$cfmgr_store_fsync"; then cfmgr_store_flush_code=0; else cfmgr_store_flush_code=$?; fi
	exec 3<&-
	return "$cfmgr_store_flush_code"
}

cfmgr_store_cleanup() {
	cfmgr_store_attachment_ok || return 1
	[ -z "${cfmgr_probe_pid:-}" ] || [ "${cfmgr_probe_status:-}" = reaped ] || return 1
	cfmgr_store_items=0
	for cfmgr_store_item in "$cfmgr_store_context"/*; do
		[ -e "$cfmgr_store_item" ] || continue
		[ -f "$cfmgr_store_item" ] && [ ! -L "$cfmgr_store_item" ] || return 1
		cfmgr_store_items=$((cfmgr_store_items + 1))
		[ "$cfmgr_store_items" -le 512 ] || return 1
	done
	for cfmgr_store_item in "$cfmgr_store_context"/*; do
		[ -f "$cfmgr_store_item" ] || continue
		/bin/rm -f "$cfmgr_store_item" || return 1
	done
	/bin/rmdir "$cfmgr_store_context" || return 1
	exec 4<&- 5<&- 8<&- 9<&-
}

cfmgr_store_setup_ok() {
	for cfmgr_store_blocker in entry.stage .setup.complete .storage-observation; do
		[ ! -e "$cfmgr_store_source/$cfmgr_store_blocker" ] && [ ! -L "$cfmgr_store_source/$cfmgr_store_blocker" ] || return 1
	done
	cfmgr_store_snapshot "$cfmgr_store_source/setup-state" || return $?
	[ "$cfmgr_store_snapshot_bytes" -le 128 ] || return 1
	cfmgr_store_read_line "$cfmgr_store_snapshot" || return 1
	[ "$cfmgr_store_line" = "CFMGR-SETUP 1 $CFMGR_VERSION complete" ]
}

cfmgr_store_work() {
	cfmgr_store_pending
	if [ "$cfmgr_store_operation" = read ]; then
		if cfmgr_store_setup_ok; then :; else
			[ "$?" != 3 ] || return 3
			cfmgr_store_pending=1
		fi
		cfmgr_store_snapshot "$cfmgr_store_live" || return $?
		cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_result='read'
		return 0
	fi
	if cfmgr_store_setup_ok; then :; else
		cfmgr_store_setup_code=$?
		[ "$cfmgr_store_setup_code" != 3 ] || return 3
		cfmgr_store_result=recovery cfmgr_store_pending=1
		return 1
	fi
	case ${cfmgr_store_scope:-settings}:${cfmgr_store_archive_lock_held:-0} in
	archive-preferences:1 | archive-history:1) cfmgr_store_archive_borrow_lock || return $? ;;
	*) cfmgr_store_lock_acquire || return $? ;;
	esac
	cfmgr_store_setup_ok || return $?
	case ${cfmgr_store_scope:-settings} in
	archive-preferences | archive-history) cfmgr_store_archive_digest_admit || return $? ;;
	*) cfmgr_store_digest_admit || return $? ;;
	esac
	if [ "$cfmgr_store_operation" = recover ]; then
		cfmgr_store_recover
		return $?
	fi
	cfmgr_store_pending
	if [ "$cfmgr_store_pending" = 1 ]; then
		cfmgr_store_result=recovery
		return 1
	fi
	# Folder mutators inherit the same already-admitted writer description as
	# publication. An unresolved mkdir/chmod child must exclude another Save.
	if [ "${cfmgr_store_scope:-settings}" = backup ]; then cfmgr_backup_prepare_folder || return $?; fi
	cfmgr_store_attempt=0
	while [ "$cfmgr_store_attempt" -lt 2 ]; do
		cfmgr_store_attempt=$((cfmgr_store_attempt + 1))
		cfmgr_store_snapshot "$cfmgr_store_live" || return $?
		cfmgr_store_base=$cfmgr_store_snapshot cfmgr_store_base_bytes=$cfmgr_store_snapshot_bytes
		cfmgr_store_flags "$cfmgr_store_base" "$cfmgr_store_base_bytes" || return $?
		cfmgr_store_base_generation=$cfmgr_store_generation
		cfmgr_store_digest "$cfmgr_store_base" || return $?
		cfmgr_store_base_sha=$cfmgr_store_digest_value
		cfmgr_store_parse settings-observe "$cfmgr_store_base" "$cfmgr_store_base_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_store_tag cfmgr_store_schema cfmgr_store_old cfmgr_store_new cfmgr_store_changed cfmgr_store_target_check cfmgr_store_target_auto cfmgr_store_target_dev cfmgr_store_input_bytes cfmgr_store_target_bytes cfmgr_store_end cfmgr_store_extra <<EOF_PATCH
$cfmgr_store_line
EOF_PATCH
		cfmgr_store_patch_tag=CFMGR-SETTINGS-PATCH
		[ "${cfmgr_store_scope:-settings}" != backup ] || cfmgr_store_patch_tag=CFMGR-BACKUP-PATCH
		case ${cfmgr_store_scope:-settings} in archive-preferences | archive-history) cfmgr_store_patch_tag=CFMGR-ARCHIVE-PATCH ;; esac
		[ "$cfmgr_store_tag:$cfmgr_store_schema:$cfmgr_store_end:$cfmgr_store_extra" = "$cfmgr_store_patch_tag:1:END:" ] &&
			[ "$cfmgr_store_old:$cfmgr_store_input_bytes" = "$cfmgr_store_base_generation:$cfmgr_store_base_bytes" ] || return 1
		case $cfmgr_store_changed:$cfmgr_store_target_check:$cfmgr_store_target_auto:$cfmgr_store_target_dev in [01]:[01]:[01]:[01]) ;; *) return 1 ;; esac
		case $cfmgr_store_new:$cfmgr_store_target_bytes in *[!0-9:]* | :* | *:) return 1 ;; esac
		[ "${#cfmgr_store_new}" -le 20 ] && [ "$cfmgr_store_target_bytes" -gt 0 ] && [ "$cfmgr_store_target_bytes" -le 65536 ] || return 1
		if [ "$cfmgr_store_changed" = 0 ]; then
			if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then :; else
				cfmgr_store_match_code=$?
				[ "$cfmgr_store_match_code" = 4 ] || return "$cfmgr_store_match_code"
				cfmgr_store_result=stale
				return 1
			fi
			cfmgr_store_result=unchanged
			return 0
		fi
		cfmgr_store_parse settings-patch "$cfmgr_store_base" "$cfmgr_store_base_bytes" || return $?
		cfmgr_store_candidate=$cfmgr_probe_stdout
		cfmgr_store_count "$cfmgr_store_candidate" || return $?
		[ "$cfmgr_store_bytes" = "$cfmgr_store_target_bytes" ] || return 1
		cfmgr_store_snapshot=$cfmgr_store_candidate
		cfmgr_store_target_matches || return $?
		cfmgr_store_digest "$cfmgr_store_candidate" || return $?
		cfmgr_store_candidate_sha=$cfmgr_store_digest_value
		cfmgr_store_prepare_guard || return $?
		if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then
			cfmgr_store_publish
			return $?
		else
			cfmgr_store_stale_code=$?
			[ "$cfmgr_store_stale_code" = 4 ] || return "$cfmgr_store_stale_code"
			# Only this invocation's complete finite preparing directory is ours.
			cfmgr_store_remove_guard || return $?
			cfmgr_store_result=stale
		fi
	done
	return 1
}

cfmgr_store_live_matches() {
	cfmgr_store_expected_sha=$1 cfmgr_store_expected_bytes=$2
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_expected_bytes" ] || return 4
	cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
	[ "$cfmgr_store_digest_value" = "$cfmgr_store_expected_sha" ] || return 4
}

cfmgr_store_copy() {
	cfmgr_store_run store-copy "$cfmgr_store_cp" "$1" "$2" || return $?
	cfmgr_store_admit_private "$2" file || return 1
	cfmgr_store_flush "$2"
}

cfmgr_store_prepare_guard() {
	cfmgr_store_pending
	[ "$cfmgr_store_pending" = 0 ] || {
		cfmgr_store_result=recovery
		return 1
	}
	# Same-JFFS old/candidate plus erase-block and metadata allowance, before
	# creating persistent intent or any live change.
	cfmgr_store_space_needed=$(((cfmgr_store_base_bytes + cfmgr_store_target_bytes + 262144 + 1023) / 1024))
	cfmgr_store_run store-space /bin/df "$cfmgr_store_jffs" || return $?
	cfmgr_store_space_raw=$cfmgr_probe_stdout
	cfmgr_store_run store-space-frame "$cfmgr_store_awk" "$cfmgr_store_space_raw" "$cfmgr_store_space_needed" || return $?
	cfmgr_store_guard=$cfmgr_store_source/.config-save.preparing
	cfmgr_store_run store-mkdir /bin/mkdir "$cfmgr_store_guard" || return $?
	cfmgr_store_guard_owned=1 cfmgr_store_pending=1 cfmgr_store_result=recovery
	exec 4<"$cfmgr_store_guard" || return 3
	cfmgr_store_copy "$cfmgr_store_base" "$cfmgr_store_guard/old" || return $?
	cfmgr_store_copy "$cfmgr_store_candidate" "$cfmgr_store_guard/candidate" || return $?
	cfmgr_store_digest "$cfmgr_store_guard/old" || return $?
	[ "$cfmgr_store_digest_value" = "$cfmgr_store_base_sha" ] || return 1
	cfmgr_store_digest "$cfmgr_store_guard/candidate" || return $?
	[ "$cfmgr_store_digest_value" = "$cfmgr_store_candidate_sha" ] || return 1
	case ${cfmgr_store_scope:-settings} in
	archive-preferences | archive-history) cfmgr_store_intent=$cfmgr_store_context/intent.archive.$cfmgr_probe_serial.$cfmgr_store_attempt ;;
	*) cfmgr_store_intent=$cfmgr_store_context/intent.$cfmgr_store_attempt ;;
	esac
	(
		umask 077
		set -C
		printf 'CFMGR-SETTINGS-INTENT 1 %s %s %s %s %s %s END\n' "$cfmgr_store_base_generation" "$cfmgr_store_new" "$cfmgr_store_base_bytes" "$cfmgr_store_target_bytes" "$cfmgr_store_base_sha" "$cfmgr_store_candidate_sha" >"$cfmgr_store_intent"
	) || return 1
	cfmgr_store_copy "$cfmgr_store_intent" "$cfmgr_store_guard/intent" || return $?
	cfmgr_store_flush "$cfmgr_store_guard" && cfmgr_store_flush "$cfmgr_store_source"
}

cfmgr_store_move_guard() {
	[ ! -e "$2" ] && [ ! -L "$2" ] || return 1
	cfmgr_store_guard_next=$2
	if cfmgr_store_run store-move "$cfmgr_store_mv" "$1" "$2"; then cfmgr_store_move_code=0; else cfmgr_store_move_code=$?; fi
	[ "$cfmgr_store_move_code" = 0 ] || return "$cfmgr_store_move_code"
	cfmgr_store_guard=$2 cfmgr_store_guard_next=''
	cfmgr_store_flush "$cfmgr_store_source"
}

cfmgr_store_publish() {
	cfmgr_store_move_guard "$cfmgr_store_guard" "$cfmgr_store_source/.config-save" || return $?
	if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then :; else
		cfmgr_store_match_code=$?
		[ "$cfmgr_store_match_code" = 4 ] || return "$cfmgr_store_match_code"
		cfmgr_store_result=stale
		return 1
	fi
	cfmgr_store_admit_private "$cfmgr_store_live" file || return 1
	cfmgr_store_run store-move "$cfmgr_store_mv" "$cfmgr_store_guard/candidate" "$cfmgr_store_live" || return $?
	cfmgr_store_flush "$cfmgr_store_live" && cfmgr_store_flush "$cfmgr_store_source" || return $?
	cfmgr_store_live_matches "$cfmgr_store_candidate_sha" "$cfmgr_store_target_bytes" || return $?
	cfmgr_store_target_matches || return $?
	cfmgr_store_move_guard "$cfmgr_store_guard" "$cfmgr_store_source/.config-save.retired" || return $?
	cfmgr_store_remove_guard || return $?
	cfmgr_store_result=saved cfmgr_store_pending=0
}

cfmgr_store_remove_guard() {
	cfmgr_store_attachment_ok && cfmgr_store_admit_private "$cfmgr_store_guard" directory || return 1
	cfmgr_store_guard_inventory || return $?
	for cfmgr_store_guard_item in "$cfmgr_store_guard/old" "$cfmgr_store_guard/candidate" "$cfmgr_store_guard/intent"; do
		[ -e "$cfmgr_store_guard_item" ] || continue
		cfmgr_store_admit_private "$cfmgr_store_guard_item" file || return 1
		cfmgr_store_run store-remove /bin/rm "$cfmgr_store_guard_item" || return $?
	done
	cfmgr_store_retiring=1
	if cfmgr_store_run store-rmdir /bin/rmdir "$cfmgr_store_guard"; then cfmgr_store_retire_code=0; else cfmgr_store_retire_code=$?; fi
	cfmgr_store_retiring=0
	[ "$cfmgr_store_retire_code" = 0 ] || return "$cfmgr_store_retire_code"
	exec 4<&-
	cfmgr_store_guard_owned=0 cfmgr_store_pending=0
	cfmgr_store_flush "$cfmgr_store_source"
}

cfmgr_store_recover() {
	cfmgr_store_result=recovery
	[ ! -e "$cfmgr_store_source/.storage-observation" ] && [ ! -L "$cfmgr_store_source/.storage-observation" ] || return 1
	cfmgr_store_phase_count=0
	for cfmgr_store_phase in .config-save.preparing .config-save .config-save.retired; do
		if [ -e "$cfmgr_store_source/$cfmgr_store_phase" ] || [ -L "$cfmgr_store_source/$cfmgr_store_phase" ]; then
			cfmgr_store_phase_count=$((cfmgr_store_phase_count + 1))
			cfmgr_store_guard=$cfmgr_store_source/$cfmgr_store_phase
		fi
	done
	if [ "$cfmgr_store_phase_count" = 0 ]; then
		cfmgr_store_snapshot "$cfmgr_store_live" || return $?
		cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_result=unchanged cfmgr_store_pending=0
		return 0
	fi
	[ "$cfmgr_store_phase_count" = 1 ] && cfmgr_store_admit_private "$cfmgr_store_guard" directory || return 1
	exec 4<"$cfmgr_store_guard" || return 3
	cfmgr_store_guard_owned=1 cfmgr_store_pending=1
	cfmgr_store_guard_inventory || return $?
	if [ "$cfmgr_store_guard" = "$cfmgr_store_source/.config-save.retired" ]; then
		cfmgr_store_validate_retired || return $?
		cfmgr_store_remove_guard || return $?
	else
		cfmgr_store_snapshot "$cfmgr_store_guard/intent" || return $?
		cfmgr_store_run store-intent "$cfmgr_store_awk" "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_store_old cfmgr_store_new cfmgr_store_base_bytes cfmgr_store_target_bytes cfmgr_store_base_sha cfmgr_store_candidate_sha <<EOF_INTENT
$cfmgr_store_line
EOF_INTENT
		cfmgr_store_snapshot "$cfmgr_store_guard/old" || return $?
		[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_base_bytes" ] || return 1
		cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_base_bytes" || return $?
		[ "$cfmgr_store_generation" = "$cfmgr_store_old" ] || return 1
		cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
		[ "$cfmgr_store_digest_value" = "$cfmgr_store_base_sha" ] || return 1
		if cfmgr_store_live_matches "$cfmgr_store_base_sha" "$cfmgr_store_base_bytes"; then
			# Never replay a candidate when live remains the exact old generation.
			cfmgr_store_snapshot "$cfmgr_store_guard/candidate" || return $?
			[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_target_bytes" ] || return 1
			cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
			[ "$cfmgr_store_generation" = "$cfmgr_store_new" ] || return 1
			cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
			[ "$cfmgr_store_digest_value" = "$cfmgr_store_candidate_sha" ] || return 1
		elif [ "$?" = 3 ]; then
			return 3
		elif cfmgr_store_live_matches "$cfmgr_store_candidate_sha" "$cfmgr_store_target_bytes"; then
			cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_target_bytes" || return $?
			[ "$cfmgr_store_generation" = "$cfmgr_store_new" ] || return 1
			cfmgr_store_flush "$cfmgr_store_live" && cfmgr_store_flush "$cfmgr_store_source" || return $?
		else
			[ "$?" != 3 ] || return 3
			return 1
		fi
		cfmgr_store_move_guard "$cfmgr_store_guard" "$cfmgr_store_source/.config-save.retired" || return $?
		cfmgr_store_remove_guard || return $?
	fi
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
	cfmgr_store_result=recovered cfmgr_store_pending=0
}

cfmgr_store_guard_inventory() {
	cfmgr_store_guard_count=0
	for cfmgr_store_guard_item in "$cfmgr_store_guard"/* "$cfmgr_store_guard"/.[!.]* "$cfmgr_store_guard"/..?*; do
		[ -e "$cfmgr_store_guard_item" ] || [ -L "$cfmgr_store_guard_item" ] || continue
		case ${cfmgr_store_guard_item##*/} in old | candidate | intent) ;; *) return 1 ;; esac
		cfmgr_store_admit_private "$cfmgr_store_guard_item" file || return 1
		cfmgr_store_count "$cfmgr_store_guard_item" || return $?
		cfmgr_store_guard_count=$((cfmgr_store_guard_count + 1))
		[ "$cfmgr_store_guard_count" -le 3 ] || return 1
	done
}

cfmgr_store_validate_retired() {
	# Validate current state before discarding any recovery payload. A complete
	# intent must bind live exactly; only an empty retired directory can lack an
	# intent (our fixed cleanup order removes intent last). Nonempty partial or
	# alien evidence is preserved rather than guessed.
	cfmgr_store_snapshot "$cfmgr_store_live" || return $?
	cfmgr_store_retired_live=$cfmgr_store_snapshot cfmgr_store_retired_bytes=$cfmgr_store_snapshot_bytes
	cfmgr_store_flags "$cfmgr_store_retired_live" "$cfmgr_store_retired_bytes" || return $?
	cfmgr_store_retired_generation=$cfmgr_store_generation
	cfmgr_store_digest "$cfmgr_store_retired_live" || return $?
	cfmgr_store_retired_sha=$cfmgr_store_digest_value
	if [ -e "$cfmgr_store_guard/intent" ]; then
		cfmgr_store_snapshot "$cfmgr_store_guard/intent" || return $?
		cfmgr_store_run store-intent "$cfmgr_store_awk" "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
		cfmgr_store_read_line "$cfmgr_probe_stdout" || return 1
		IFS=' ' read -r cfmgr_store_old cfmgr_store_new cfmgr_store_base_bytes cfmgr_store_target_bytes cfmgr_store_base_sha cfmgr_store_candidate_sha <<EOF_RETIRED
$cfmgr_store_line
EOF_RETIRED
		case $cfmgr_store_retired_sha:$cfmgr_store_retired_bytes:$cfmgr_store_retired_generation in
		"$cfmgr_store_base_sha:$cfmgr_store_base_bytes:$cfmgr_store_old" | "$cfmgr_store_candidate_sha:$cfmgr_store_target_bytes:$cfmgr_store_new") ;;
		*) return 1 ;;
		esac
		for cfmgr_store_retired_item in old candidate; do
			[ -e "$cfmgr_store_guard/$cfmgr_store_retired_item" ] || continue
			case $cfmgr_store_retired_item in
			old) cfmgr_store_retired_item_sha=$cfmgr_store_base_sha cfmgr_store_retired_item_bytes=$cfmgr_store_base_bytes cfmgr_store_retired_item_gen=$cfmgr_store_old ;;
			candidate) cfmgr_store_retired_item_sha=$cfmgr_store_candidate_sha cfmgr_store_retired_item_bytes=$cfmgr_store_target_bytes cfmgr_store_retired_item_gen=$cfmgr_store_new ;;
			esac
			cfmgr_store_snapshot "$cfmgr_store_guard/$cfmgr_store_retired_item" || return $?
			[ "$cfmgr_store_snapshot_bytes" = "$cfmgr_store_retired_item_bytes" ] || return 1
			cfmgr_store_flags "$cfmgr_store_snapshot" "$cfmgr_store_snapshot_bytes" || return $?
			[ "$cfmgr_store_generation" = "$cfmgr_store_retired_item_gen" ] || return 1
			cfmgr_store_digest "$cfmgr_store_snapshot" || return $?
			[ "$cfmgr_store_digest_value" = "$cfmgr_store_retired_item_sha" ] || return 1
		done
	else [ "$cfmgr_store_guard_count" = 0 ] || return 1; fi
	cfmgr_store_flush "$cfmgr_store_live" && cfmgr_store_flush "$cfmgr_store_source" || return $?
	cfmgr_store_live_matches "$cfmgr_store_retired_sha" "$cfmgr_store_retired_bytes"
}

# Operational observation borrows its already-admitted native context/FD pins;
# it retains the original publication transaction and existing Entware fallback.
cfmgr_config_store_observation_lock() {
	cfmgr_store_source=$cfmgr_install_source cfmgr_store_jffs=$cfmgr_install_jffs cfmgr_store_ram=/tmp/cfmgr
	cfmgr_store_context=$cfmgr_install_context cfmgr_store_context_fd=$cfmgr_install_context_fd
	cfmgr_store_lock=$cfmgr_store_ram/config.lock cfmgr_store_borrowed=1 cfmgr_store_guard_owned=0 cfmgr_store_interrupt=0
	cfmgr_store_jffs_mount=$cfmgr_install_jffs_snapshot cfmgr_store_tmp_mount=$cfmgr_install_tmp_snapshot
	cfmgr_store_sh=$cfmgr_install_sh cfmgr_store_env=$cfmgr_install_env cfmgr_store_awk=$cfmgr_install_awk
	cfmgr_store_sleep=$cfmgr_install_sleep cfmgr_store_wc=$cfmgr_install_wc cfmgr_store_ls=$cfmgr_install_ls cfmgr_store_readlink=$cfmgr_install_readlink
	cfmgr_store_result=unavailable cfmgr_config_lock_fd0=0 cfmgr_store_flock_entware=0 cfmgr_store_flock=/usr/bin/flock cfmgr_store_archive_lock_held=0
	case ${cfmgr_prereq_flock_provider:-none} in
	native) ;;
	entware) cfmgr_store_flock_entware=1 cfmgr_store_flock=/opt/bin/flock ;;
	*) return 1 ;;
	esac
	cfmgr_store_admit_private "$cfmgr_store_ram" directory || return 1
	cfmgr_prerequisites_now || return 1
	cfmgr_store_deadline=$((cfmgr_probe_now + 20))
	cfmgr_store_lock_acquire || return $?
	cfmgr_store_pending
	[ "$cfmgr_store_pending" = 0 ]
}

cfmgr_config_awk_json() {
	# CFMGR-AWK-BEGIN json
	cfmgr_awk_program='
# SPDX-License-Identifier: GPL-3.0-or-later
# Native JSON parsing proof, not an input-ownership or API transport wrapper.
# Caller MUST supply LC_ALL=C and a private, immutable, bounded REGULAR file on
# stdin, with an independently checked original wc -c byte count. No operands.
# Pipes/growing files cannot be made finite or ownership-safe by this parser.
# Required -v variables: cfmgr_json_size (canonical 1..65536), cfmgr_json_mode
# (validate, tokens or tree). No input contents appear in diagnostics; failures are quiet.
# Awk -v decodes escapes: pass verified decimal size and a literal known mode,
# never unvalidated configuration/provider text as a -v assignment.
# Native awk may exit 0 despite a failed output write. Before using ANY token,
# consumers must verify parser status, exact node/body-byte counts and the terminal
# footer (no subsequent data). The footer does not prove file I/O ownership.
# Tree mode alone falls through to a subsequent trusted consumer BEGIN. Its
# namespaced arrays retain tagged fields and original preorder IDs without a
# second token ledger; readiness follows every complete token-budget check.

BEGIN {
    cfmgr_json_tree_ready = 0
    cfmgr_json_tree_count = 0
    if (ARGC != 1 || ENVIRON["LC_ALL"] != "C") reject()
    if (cfmgr_json_size !~ /^[1-9][0-9]*$/ || length(cfmgr_json_size) > 5) reject()
    expected_size = cfmgr_json_size + 0
    if (expected_size > 65536) reject()
    if (cfmgr_json_mode != "validate" && cfmgr_json_mode != "tokens" &&
        cfmgr_json_mode != "tree") reject()

    # BusyBox awk splits records at raw NUL even with a different RS. Do not
    # reconstruct records/newlines: length plus exact EOF detects lost bytes.
    RS = sprintf("%c", 28)
    if ((getline document) != 1 || length(document) != expected_size) reject()
    if ((getline extra_record) != 0) reject()

    for (n = 1; n <= 255; n++) {
        byte_value["b" sprintf("%c", n)] = n
        byte_hex[n] = sprintf("%02x", n)
    }
    for (n = 0; n < 16; n++) {
        hex_value["h" substr("0123456789abcdef", n + 1, 1)] = n
        hex_value["h" substr("0123456789ABCDEF", n + 1, 1)] = n
    }
    escape_hex["e\""] = "22"
    escape_hex["e\\"] = "5c"
    escape_hex["e/"] = "2f"
    escape_hex["eb"] = "08"
    escape_hex["ef"] = "0c"
    escape_hex["en"] = "0a"
    escape_hex["er"] = "0d"
    escape_hex["et"] = "09"

    position = 1
    nodes = 0
    output_size = 0
    parse_value(0, "r", 0)
    whitespace()
    if (position != length(document) + 1) reject()
    # All syntax, Unicode, duplicate keys and resource limits pass before output.
    if (cfmgr_json_mode == "tokens" || cfmgr_json_mode == "tree") {
        footer = sprintf("end\t%d\t%d\n", nodes, output_size)
        if (output_size + length(footer) > 131072) reject()
        if (cfmgr_json_mode == "tokens") {
            for (n = 1; n <= nodes; n++) printf "%s", ledger[n]
            printf "%s", footer
        }
    }
    if (cfmgr_json_mode == "tree") {
        cfmgr_json_tree_count = nodes
        cfmgr_json_tree_ready = 1
    } else {
        exit 0
    }
}

function reject() {
    exit 1
}

function peek() {
    return substr(document, position, 1)
}

function whitespace(    character) {
    while (position <= length(document)) {
        character = peek()
        if (character != " " && character != "\t" && character != "\r" && character != "\n") break
        position++
    }
}

function token(id, parent, location, kind, payload,    line) {
    if (cfmgr_json_mode != "tokens" && cfmgr_json_mode != "tree") return
    line = id "\t" parent "\t" location "\t" kind "\t" payload "\n"
    output_size += length(line)
    if (output_size > 131072) reject()
    if (cfmgr_json_mode == "tokens") ledger[id] = line
    else {
        cfmgr_json_tree_parent[id] = parent
        cfmgr_json_tree_location[id] = location
        cfmgr_json_tree_kind[id] = kind
        cfmgr_json_tree_payload[id] = payload
    }
}

function parse_value(parent, location, depth,    id, start) {
    whitespace()
    id = nodes + 1
    start = position
    parse_value_node(parent, location, depth)
    if (cfmgr_json_mode == "tree") {
        cfmgr_json_tree_start[id] = start
        cfmgr_json_tree_end[id] = position - 1
    }
}

function parse_value_node(parent, location, depth,    id, character, key, index_number, kind) {
    whitespace()
    character = peek()
    id = ++nodes
    if (nodes > 4096) reject()
    if (character == "{" || character == "[") {
        if (depth >= 32) reject()
        kind = (character == "{" ? "object" : "array")
        token(id, parent, location, kind, "-")
        position++
        whitespace()
        if (kind == "object") {
            if (peek() == "}") { position++; return }
            while (1) {
                if (peek() != "\"") reject()
                parse_string()
                key = "k" string_hex
                # Prefixes prevent awk numeric-string coercion of decoded keys.
                if ((id SUBSEP key) in seen_key) reject()
                seen_key[id SUBSEP key] = 1
                whitespace()
                if (peek() != ":") reject()
                position++
                parse_value(id, key, depth + 1)
                whitespace()
                if (peek() == "}") { position++; return }
                if (peek() != ",") reject()
                position++
                whitespace()
            }
        } else {
            if (peek() == "]") { position++; return }
            index_number = 0
            while (1) {
                parse_value(id, "i" index_number, depth + 1)
                index_number++
                whitespace()
                if (peek() == "]") { position++; return }
                if (peek() != ",") reject()
                position++
            }
        }
    } else if (character == "\"") {
        parse_string()
        token(id, parent, location, "string", "x" string_hex)
    } else if (character == "t" || character == "f" || character == "n") {
        kind = (character == "t" ? "true" : (character == "f" ? "false" : "null"))
        if (substr(document, position, length(kind)) != kind) reject()
        position += length(kind)
        token(id, parent, location, kind, "-")
    } else {
        parse_number()
        token(id, parent, location, "number", "n" number_text)
    }
}

function digit(character) {
    return character != "" && character ~ /^[0123456789]$/
}

function parse_number(    start, character) {
    start = position
    if (peek() == "-") position++
    character = peek()
    if (character == "0") position++
    else {
        if (character !~ /^[123456789]$/) reject()
        while (digit(peek())) position++
    }
    if (peek() == ".") {
        position++
        if (!digit(peek())) reject()
        while (digit(peek())) position++
    }
    if (peek() == "e" || peek() == "E") {
        position++
        if (peek() == "+" || peek() == "-") position++
        if (!digit(peek())) reject()
        while (digit(peek())) position++
    }
    # Never convert JSON numbers: bigint, signed zero and huge exponents survive.
    number_text = substr(document, start, position - start)
}

function read_hex4(    value, count, character) {
    value = 0
    for (count = 0; count < 4; count++) {
        character = peek()
        if (!("h" character in hex_value)) reject()
        value = value * 16 + hex_value["h" character]
        position++
    }
    return value
}

function unicode_hex(codepoint) {
    if (codepoint < 128) return sprintf("%02x", codepoint)
    if (codepoint < 2048)
        return sprintf("%02x%02x", 192 + int(codepoint / 64), 128 + codepoint % 64)
    if (codepoint < 65536)
        return sprintf("%02x%02x%02x", 224 + int(codepoint / 4096),
                       128 + int(codepoint / 64) % 64, 128 + codepoint % 64)
    return sprintf("%02x%02x%02x%02x", 240 + int(codepoint / 262144),
                   128 + int(codepoint / 4096) % 64, 128 + int(codepoint / 64) % 64,
                   128 + codepoint % 64)
}

function raw_utf8_hex(character,    first, count, index_number, next_byte, encoded) {
    if (!("b" character in byte_value)) reject()
    first = byte_value["b" character]
    if (first < 32) reject()
    if (first < 128) { position++; return byte_hex[first] }
    if (first >= 194 && first <= 223) count = 2
    else if (first >= 224 && first <= 239) count = 3
    else if (first >= 240 && first <= 244) count = 4
    else reject()
    encoded = byte_hex[first]
    position++
    for (index_number = 1; index_number < count; index_number++) {
        character = peek()
        if (!("b" character in byte_value)) reject()
        next_byte = byte_value["b" character]
        if (next_byte < 128 || next_byte > 191) reject()
        if (index_number == 1) {
            if (first == 224 && next_byte < 160) reject()
            if (first == 237 && next_byte > 159) reject()
            if (first == 240 && next_byte < 144) reject()
            if (first == 244 && next_byte > 143) reject()
        }
        encoded = encoded byte_hex[next_byte]
        position++
    }
    return encoded
}

function parse_string(    character, fragment, codepoint, low, decoded_size) {
    if (peek() != "\"") reject()
    position++
    string_hex = ""
    decoded_size = 0
    while (position <= length(document)) {
        character = peek()
        if (character == "\"") { position++; return }
        if (character == "\\") {
            position++
            character = peek()
            if (character == "u") {
                position++
                codepoint = read_hex4()
                if (codepoint >= 55296 && codepoint <= 56319) {
                    if (substr(document, position, 2) != "\\u") reject()
                    position += 2
                    low = read_hex4()
                    if (low < 56320 || low > 57343) reject()
                    codepoint = 65536 + (codepoint - 55296) * 1024 + low - 56320
                } else if (codepoint >= 56320 && codepoint <= 57343) reject()
                # Escaped NUL becomes hex "00", never a NUL in an awk C string.
                fragment = unicode_hex(codepoint)
            } else {
                if (!("e" character in escape_hex)) reject()
                fragment = escape_hex["e" character]
                position++
            }
        } else fragment = raw_utf8_hex(character)
        decoded_size += length(fragment) / 2
        if (decoded_size > 16384) reject()
        string_hex = string_hex fragment
    }
    reject()
}
'
	# CFMGR-AWK-END json
}

cfmgr_config_awk_config_schema() {
	# CFMGR-AWK-BEGIN config_schema
	cfmgr_awk_program='
# Schema-2 typed authority validation. Definition-only companion to the bounded
# config JSON getter tree and config observation getter transaction consumer. No execution,
# provider admission, guard authority, or lifecycle effects follow from validity.
function cs_id(parent, key) { return co_child[parent, "k" co_hex(key)] }
function cs_text(id) { co_type(id,"string"); return co_decode(substr(cfmgr_json_tree_payload[id],2)) }
function cs_string(parent,key,nullable,    id,value) {
    id=co_field(parent,key,(nullable ? "string|null" : "string"))
    if(cfmgr_json_tree_kind[id]=="null") return ""
    value=cs_text(id); if(value=="") reject(); return value
}
function cs_enum(parent,key,values,nullable,    id,value) {
    id=co_field(parent,key,(nullable ? "string|null" : "string"))
    if(cfmgr_json_tree_kind[id]=="null") return ""
    value=cs_text(id); if(value=="" || index(value,"|") || !index("|" values "|","|" value "|")) reject(); return value
}
# Decimal lexemes remain strings throughout comparisons; even signed-64-bit
# boundaries must not round through awks binary floating-point representation.
function cs_le(value,maximum) {
    return length(value)<length(maximum) || (length(value)==length(maximum) && "d" value<="d" maximum)
}
function cs_integer(id,minimum,maximum,    value) {
    co_type(id,"number"); value=substr(cfmgr_json_tree_payload[id],2)
    if(value!~/^(0|[1-9][0-9]*)$/ || !cs_le(minimum,value) || !cs_le(value,maximum)) reject()
    return value
}
function cs_int(parent,key,minimum,maximum) { return cs_integer(co_field(parent,key,"number"),minimum,maximum) }
function cs_generation(parent,key) { return cs_int(parent,key,"1","99999999999999999999") }
function cs_bool(parent,key,    id) { id=co_field(parent,key,"boolean"); return cfmgr_json_tree_kind[id]=="true" }
function cs_version(parent) { if(cs_int(parent,"schema","1","1")!="1") reject() }
function cs_local(value) { if(value!~/^[A-Za-z][A-Za-z0-9._-]*$/) reject(); return value }
function cs_path(parent,key,nullable,    value) { value=cs_string(parent,key,nullable); if(value!="") co_path(value,1); return value }
function cs_uuid(value,    groups,n,i) {
    n=split(value,groups,"-")
    if(n!=5 || length(groups[1])!=8 || length(groups[2])!=4 || length(groups[3])!=4 || length(groups[4])!=4 || length(groups[5])!=12) reject()
    for(i=1;i<=5;i++) if(groups[i]!~/^[0-9a-fA-F]+$/) reject()
    return tolower(value)
}
function cs_optional_uuid(parent,key,    id,value) {
    id=cs_id(parent,key); if(!id || cfmgr_json_tree_kind[id]=="null") return ""
    value=cs_text(id); if(cs_uuid(value)!=value) reject(); return value
}
function cs_hash(parent,key,nullable,    value) {
    value=cs_string(parent,key,nullable)
    if(value!="" && (length(value)!=64 || value~/[^0-9a-f]/)) reject()
    return value
}
function cs_absent(parent,keys,    a,n,i) {
    n=split(keys,a," "); for(i=1;i<=n;i++) if(cs_id(parent,a[i])) reject()
}
function cs_policy(parent,key,    id) {
    id=co_field(parent,key,"object|null"); if(cfmgr_json_tree_kind[id]=="null") return 0
    cs_version(id); return id
}
function cs_request(id,    request,connection) {
    request=cs_int(id,"request_timeout_seconds","1","30")+0
    connection=cs_int(id,"connect_timeout_seconds","1","10")+0
    if(connection>request) reject(); return request
}
function cs_ref(parent,key,kind,    value) {
    value=cs_string(parent,key,1); if(value=="") return 0
    cs_local(value)
    if(!(value in cs_credentials) || (kind!="" && cs_kinds[value]!=kind)) reject()
    return cs_credentials[value]
}
function cs_credentials_validate(registry,    i,key,record,kind) {
    for(i=2;i<=cfmgr_json_tree_count;i++) {
        if(cfmgr_json_tree_parent[i]!=registry) continue
        key=cs_local(co_decode(substr(cfmgr_json_tree_location[i],2)))
        record=co_type(i,"object"); cs_version(record)
        kind=cs_enum(record,"kind","cloudflare_api_token|cloudflared_token|cloudflared_json|cloudflared_certificate",0)
        cs_credentials[key]=record; cs_kinds[key]=kind
        if(kind=="cloudflare_api_token" || kind=="cloudflared_token") cs_string(record,"value",0)
        else if(kind=="cloudflared_json") {
            cs_string(record,"account_tag",0); cs_uuid(cs_string(record,"tunnel_id",0)); cs_string(record,"tunnel_secret",0)
        } else {
            cs_string(record,"account_id",0); cs_string(record,"format",0)
            cs_path(record,"path",0); cs_path(record,"recovery_path",0)
            cs_hash(record,"sha256",0); cs_generation(record,"generation")
            cs_enum(record,"provenance","login|import|migration|repair",0)
        }
    }
}
function cs_ttl(id,    mode) {
    co_type(id,"object|null"); if(cfmgr_json_tree_kind[id]=="null") return ""
    mode=cs_enum(id,"mode","auto|seconds",0)
    if(mode=="seconds") cs_int(id,"value","30","86400")
    else if(cs_id(id,"value")) reject()
    return mode
}
function cs_ddns(id,    configured,zone,primary,ref,records,i,item,key,name,type,ttl,proxied,effective_ttl,effective_proxy,found,policy,request) {
    cs_absent(id,"credentials")
    configured=cs_bool(id,"configured"); if(cs_bool(id,"enabled") && !configured) reject()
    cs_enum(id,"address_family","auto|ipv4|ipv6|dual",0)
    zone=cs_string(id,"zone_id",1); primary=cs_string(id,"primary_hostname",1)
    if(length(primary)>63) reject()
    ref=cs_ref(id,"credential_ref","cloudflare_api_token")
    ttl=cs_ttl(co_field(id,"ttl","object|null"))
    proxied=co_field(id,"proxied","boolean|null")
    cs_int(id,"forced_refresh_days","1","999")
    records=co_field(id,"records","array")
    for(i=0; (item=co_child[records,"i" i]);i++) {
        co_type(item,"object"); key=cs_local(cs_string(item,"id",0))
        if(cs_ddns_local[key]++) reject()
        name=cs_string(item,"name",0); type=cs_enum(item,"type","A|AAAA",0)
        key=zone SUBSEP tolower(name) SUBSEP type; if(cs_ddns_logical[key]++) reject()
        if("s" tolower(name)=="s" tolower(primary)) found=1
        effective_ttl=(cs_id(item,"ttl") ? cs_ttl(cs_id(item,"ttl")) : ttl)
        effective_proxy=(cs_id(item,"proxied") ? co_type(cs_id(item,"proxied"),"boolean|null") : proxied)
        if(cfmgr_json_tree_kind[effective_proxy]=="true" && effective_ttl!="auto") reject()
        if(configured && (effective_ttl=="" || cfmgr_json_tree_kind[effective_proxy]=="null")) reject()
    }
    if(configured && (zone=="" || primary=="" || !ref || !i || !found)) reject()
    if(!i && cfmgr_json_tree_kind[proxied]=="true" && ttl!="auto") reject()
    policy=cs_policy(id,"timeouts")
    if(policy) { request=cs_request(policy); if((cs_int(policy,"completion_timeout_seconds","5","90")+0)<request+5) reject() }
}
function cs_sync(id,    configured,account,ref,targets,i,item,role,target,families,j,family,primary,policy,request) {
    cs_absent(id,"credentials")
    configured=cs_bool(id,"configured"); if(cs_bool(id,"enabled") && !configured) reject()
    cs_enum(id,"address_family","auto|ipv4|ipv6|dual",0)
    account=cs_string(id,"account_id",1); ref=cs_ref(id,"credential_ref","cloudflare_api_token")
    targets=co_field(id,"targets","array")
    for(i=0;(item=co_child[targets,"i" i]);i++) {
        if(i>=2) reject(); co_type(item,"object")
        role=cs_enum(item,"role","primary|secondary",0); if(cs_sync_roles[role]++) reject()
        if(role=="primary") primary++
        target=cs_string(item,"id",0); if(cs_sync_ids[target]++) reject(); cs_string(item,"name",0)
        families=co_field(item,"families","array")
        for(j=0;co_child[families,"i" j];j++) {
            family=cs_text(co_child[families,"i" j]); if(family!~/^(ipv4|ipv6)$/ || cs_sync_families[family]++) reject()
        }
        if(!j) reject()
    }
    if(configured && (account=="" || !ref || !i || primary!=1)) reject()
    policy=cs_policy(id,"retry")
    if(policy) { request=cs_request(policy); cs_int(policy,"attempts","1","4"); if((cs_int(policy,"batch_timeout_seconds","1","300")+0)<request) reject() }
}
function cs_cloud(id,    configured,method,refs,runtime,management,certificate,dns,identity,account,tunnel,paths,yaml,json,cert_path,policy,response) {
    cs_absent(id,"token account_tag tunnel_id tunnel_secret credentials")
    configured=cs_bool(id,"configured"); if(cs_bool(id,"enabled") && !configured) reject()
    cs_bool(id,"installed"); cs_bool(id,"maintenance_enabled"); co_field(id,"binary_auto_update","boolean|null")
    method=cs_enum(id,"method","token|advanced",1)
    refs=co_field(id,"credential_refs","object")
    runtime=cs_ref(refs,"runtime",(method=="token" ? "cloudflared_token" : (method=="advanced" ? "cloudflared_json" : "")))
    if(runtime && cs_kinds[cs_string(refs,"runtime",0)]!~/^cloudflared_(token|json)$/) reject()
    management=cs_ref(refs,"management","cloudflare_api_token"); dns=cs_ref(refs,"dns","cloudflare_api_token")
    certificate=cs_ref(refs,"certificate","cloudflared_certificate")
    identity=co_field(id,"expected_identity","object")
    account=cs_string(identity,"account_id",1); tunnel=cs_string(identity,"tunnel_id",1)
    if(tunnel!="") tunnel=cs_uuid(tunnel)
    paths=co_field(id,"paths","object"); yaml=cs_path(paths,"yaml",1); json=cs_path(paths,"json",1); cert_path=cs_path(paths,"certificate",1)
    if(certificate && ((account!="" && "s" account!="s" cs_string(certificate,"account_id",0)) || "s" cert_path!="s" cs_path(certificate,"path",0))) reject()
    if(!certificate && cert_path!="") reject()
    if(runtime && method=="advanced") {
        if("s" account!="s" cs_string(runtime,"account_tag",0) || "s" tunnel!="s" cs_uuid(cs_string(runtime,"tunnel_id",0))) reject()
    }
    if(configured && (method=="" || !runtime || (method=="advanced" && (account=="" || tunnel=="" || yaml=="" || json=="")))) reject()
    policy=cs_policy(id,"readiness")
    if(policy) { response=cs_int(policy,"response_timeout_seconds","1","2")+0; if((cs_int(policy,"command_timeout_seconds","1","3")+0)<response) reject() }
    policy=cs_policy(id,"watchdog")
    if(policy) { cs_int(policy,"reconnect_grace_seconds","1","300"); cs_int(policy,"stability_seconds","60","3600") }
    co_cloud_configured=cs_id(id,"configured"); co_cloud_enabled=cs_id(id,"enabled")
}
function cs_logging(root,    i,name,id,configured,enabled,optout,policy,size,unit,maximum,value) {
    for(i=1;i<=3;i++) {
        name=(i==1 ? "ddns" : (i==2 ? "ip_sync" : "cloudflared"))
        id=co_field(root,name,"object"); configured=cs_bool(id,"configured"); enabled=cs_bool(id,"enabled"); optout=cs_bool(id,"opt_out")
        if((enabled && !configured) || (optout && enabled)) reject()
        cs_absent(id,"compress compression delaycompress delay_compression")
        policy=cs_policy(id,"policy")
        if(policy) {
            cs_absent(policy,"compress compression delaycompress delay_compression")
            if(name!="cloudflared") { cs_int(policy,"version","1","1"); cs_absent(policy,"size total_files max_age_days mode") }
            else {
                cs_enum(policy,"mode","size|daily|weekly|monthly",0)
                size=co_field(policy,"size","object"); unit=cs_enum(size,"unit","B|KiB|MiB|GiB",0)
                maximum=(unit=="B" ? "9223372036854775807" : (unit=="KiB" ? "9007199254740991" : (unit=="MiB" ? "8796093022207" : "8589934591")))
                cs_int(size,"value","1",maximum)
                cs_int(policy,"total_files","1","2147483648")
                value=co_field(policy,"max_age_days","number|null"); if(cfmgr_json_tree_kind[value]!="null") cs_integer(value,"1","30")
            }
        }
        if(configured && !policy) reject()
    }
}
function cs_ownership(root,    components,i,item,component,path,migration) {
    cs_version(root); components=co_field(root,"components","array")
    for(i=0;(item=co_child[components,"i" i]);i++) {
        co_type(item,"object"); cs_version(item)
        component=cs_local(cs_string(item,"component",0)); path=cs_path(item,"path",0)
        if(cs_owner_components[component]++ || cs_owner_paths[path]++) reject()
        cs_generation(item,"generation"); cs_hash(item,"sha256",1)
    }
    migration=cs_policy(root,"migration")
    if(migration) { cs_int(migration,"source_schema","1","1"); cs_string(migration,"source",0); cs_enum(migration,"state","pending|complete",0); cs_generation(migration,"generation") }
}
function cs_epoch(parent,key) { return cs_int(parent,key,"0","9999999999") }
function cs_ipv4(s,    a,n,i) { n=split(s,a,"."); if(n!=4) return 0; for(i=1;i<=4;i++) if(a[i]!~/^(0|[1-9][0-9]*)$/ || length(a[i])>3 || a[i]>255) return 0; return 1 }
function cs_public4(s,    a) { if(!cs_ipv4(s)) return 0; split(s,a,"."); return !(a[1]==0 || a[1]==10 || a[1]==127 || a[1]>=224 || (a[1]==100 && a[2]>=64 && a[2]<=127) || (a[1]==169 && a[2]==254) || (a[1]==172 && a[2]>=16 && a[2]<=31) || (a[1]==192 && (a[2]==168 || (a[2]==0 && (a[3]==0 || a[3]==2)))) || (a[1]==198 && (a[2]==18 || a[2]==19 || (a[2]==51 && a[3]==100))) || (a[1]==203 && a[2]==0 && a[3]==113)) }
function cs_ipv6(s,    lower,n,a,i,double,groups) {
    lower=tolower(s)
    if(length(s)>39 || s~/[^0-9a-fA-F:]/ || lower!~/^[23][0-9a-f][0-9a-f][0-9a-f]:/ || lower~/^2001:0?db8:/ || s~/:::/) return 0
    double=index(s,"::"); if(double && index(substr(s,double+2),"::")) return 0
    n=split(s,a,":"); groups=0
    for(i=1;i<=n;i++) if(a[i]!="") { if(length(a[i])>4 || a[i]!~/^[0-9a-fA-F]+$/) return 0; groups++ }
    if((substr(s,1,1)==":" && substr(s,1,2)!="::") || (substr(s,length(s),1)==":" && substr(s,length(s)-1)!="::")) return 0
    return double ? groups<8 : groups==8
}
function cs_outcome(item,family,    result,value,id) {
    co_type(item,"object"); result=cs_enum(item,"result","published|verified|removed",0); cs_epoch(item,"at")
    id=co_field(item,"value","string|null")
    if(result=="removed") { if(cfmgr_json_tree_kind[id]!="null") reject() }
    else { value=cs_text(id); if(family=="ipv4" ? !cs_public4(value) : !cs_ipv6(value)) reject() }
}
function cs_event(item) { co_type(item,"object"); cs_enum(item,"result","success|partial|pending|failed",0); cs_enum(item,"reason","auth|storage|recovery|throttle|partial|unavailable|none|network|waiting",0); cs_epoch(item,"at") }
function cs_observation(item,    running,state) {
    co_type(item,"object"); cs_enum(item,"origin","runtime|restored",0); cs_uuid(cs_string(item,"boot_id",0)); cs_epoch(item,"at")
    running=cs_bool(item,"running"); state=cs_enum(item,"connection","connected|waiting|unknown",0)
    if(state=="connected" && !running) reject()
    cs_string(item,"installed_version",0); cs_enum(item,"logging","ready|unavailable|unknown",0); cs_bool(item,"cleanup")
}
function cs_status(record,network,    i,id,item,key,value,source) {
    co_type(record,"object"); cs_version(record); cs_generation(record,"generation")
    if(network) { cs_uuid(cs_string(record,"boot_id",0)); cs_enum(record,"selected_wan","0|1|auto",0) }
    for(i=1;i<=2;i++) {
        key=(i==1 ? "ipv4" : "ipv6"); id=cs_id(record,key)
        if(!id || cfmgr_json_tree_kind[id]=="null") continue
        if(!network) cs_outcome(id,key)
        else {
            co_type(id,"object"); value=cs_string(id,"value",0)
            if(key=="ipv4" ? !cs_public4(value) : !cs_ipv6(value)) reject()
            cs_epoch(id,"at"); cs_enum(id,"source","recorded|interface|discovery",0)
            if(key=="ipv6") cs_bool(id,"eligible")
        }
    }
    id=cs_id(record,"latest"); if(id && cfmgr_json_tree_kind[id]!="null") cs_event(id)
    id=cs_id(record,"observation"); if(id && cfmgr_json_tree_kind[id]!="null") cs_observation(id)
    id=cs_id(record,"events"); if(id) { co_type(id,"array"); for(i=0;(item=co_child[id,"i" i]);i++) cs_event(item) }
}
function cs_history(root,    i,key,wrapper,record) {
    for(i=1;i<=4;i++) {
        key=(i==1 ? "ddns" : (i==2 ? "ip_sync" : (i==3 ? "cloudflared" : "network")))
        wrapper=cs_id(root,key)
        if(!wrapper) { if(i<4) reject(); continue }
        co_type(wrapper,"object|null"); if(cfmgr_json_tree_kind[wrapper]=="null") continue
        record=cs_id(wrapper,"status"); if(record && cfmgr_json_tree_kind[record]!="null") cs_status(record,i==4)
    }
}
function cs_validate(    id,value,policy,request,record,source,branch,commit) {
    # Manager source controls are manual data, admitted even while ignored when
    # developer mode is Off; editing them never performs acquisition.
    source=co_source; value=cs_string(source,"repository",0)
    if(value!~/^https:\/\/github\.com\/[A-Za-z0-9][A-Za-z0-9_.-]*\/[A-Za-z0-9][A-Za-z0-9_.-]*$/ || length(value)>256) reject()
    branch=cs_string(source,"branch",0)
    if(length(branch)>128 || branch!~/^[A-Za-z0-9_.\/-]+$/ || branch~/(^|\/)\.\.?(\/|$)/) reject()
    commit=cs_text(cs_id(source,"commit")); if(commit!="" && (length(commit)!=40 || commit~/[^0-9a-f]/)) reject()
    cs_path(co_manager,"developer_log_directory",1)
    cs_credentials_validate(co_field(1,"credentials","object"))
    cs_ddns(co_field(1,"ddns","object")); cs_sync(co_field(1,"ip_sync","object")); cs_cloud(co_field(1,"cloudflared","object"))
    id=co_field(1,"network","object"); cs_enum(id,"address_family","auto|ipv4|ipv6|dual",0)
    value=co_field(id,"selected_wan","number|null"); if(cfmgr_json_tree_kind[value]!="null") cs_integer(value,"0","1")
    policy=cs_policy(id,"discovery")
    if(policy) { cs_request(policy); value=cs_int(policy,"interval_seconds","60","3600")+0; if(value%60) reject() }
    cs_logging(co_field(1,"logging","object"))
    id=co_field(1,"backup","object")
    cs_enum(id,"date_format","DMY|MDY|YMD",1)
    value=co_field(id,"retention","number|null"); if(cfmgr_json_tree_kind[value]!="null") cs_integer(value,"3","5")
    cs_optional_uuid(id,"set_id")
    record=cs_policy(id,"last_backup")
    if(record) {
        cs_generation(record,"generation"); cs_epoch(record,"at"); cs_enum(record,"date_format","DMY|MDY|YMD",0)
        cs_string(record,"local_date",0); cs_string(record,"local_time",0); cs_string(record,"timezone",0); cs_string(record,"set_id",0); cs_string(record,"archive_id",0)
    }
    cs_ownership(co_field(1,"ownership","object")); cs_history(co_field(1,"history","object"))
}
function cs_null(parent,key) { if(cfmgr_json_tree_kind[cs_id(parent,key)]!="null") reject() }
function cs_empty(id,    i) { for(i=2;i<=cfmgr_json_tree_count;i++) if(cfmgr_json_tree_parent[i]==id) reject() }
function cs_fresh(    i,key,id,cloud,refs,paths,identity,backup,ownership) {
    if(co_old!="1" || !cs_bool(co_manager,"check_updates") || cs_bool(co_manager,"auto_update") || cs_bool(co_manager,"developer")) reject()
    cs_null(co_manager,"developer_log_directory"); if(cs_text(cs_id(co_source,"commit"))!="") reject()
    for(i=1;i<=3;i++) {
        key=(i==1 ? "ddns" : (i==2 ? "ip_sync" : "cloudflared")); id=cs_id(1,key)
        if(cs_bool(id,"configured") || cs_bool(id,"enabled")) reject()
        if(i<3) {
            cs_null(id,"credential_ref"); cs_empty(cs_id(id,(i==1 ? "records" : "targets")))
            if(cs_string(id,"address_family",0)!="auto") reject()
        }
        id=cs_id(cs_id(1,"logging"),key)
        if(cs_bool(id,"configured") || cs_bool(id,"enabled") || cs_bool(id,"opt_out")) reject()
        cs_null(id,"policy"); cs_null(cs_id(1,"history"),key)
    }
    id=cs_id(1,"ddns"); cs_null(id,"zone_id"); cs_null(id,"primary_hostname"); cs_null(id,"ttl"); cs_null(id,"proxied"); cs_null(id,"timeouts")
    if(cs_int(id,"forced_refresh_days","14","14")!="14") reject()
    id=cs_id(1,"ip_sync"); cs_null(id,"account_id"); cs_null(id,"retry")
    cloud=cs_id(1,"cloudflared"); if(cs_bool(cloud,"installed") || cs_bool(cloud,"maintenance_enabled")) reject()
    cs_null(cloud,"method"); cs_null(cloud,"binary_auto_update"); cs_null(cloud,"readiness"); cs_null(cloud,"watchdog")
    refs=cs_id(cloud,"credential_refs"); cs_null(refs,"runtime"); cs_null(refs,"management"); cs_null(refs,"certificate"); cs_null(refs,"dns")
    paths=cs_id(cloud,"paths"); cs_null(paths,"yaml"); cs_null(paths,"json"); cs_null(paths,"certificate")
    identity=cs_id(cloud,"expected_identity"); cs_null(identity,"account_id"); cs_null(identity,"tunnel_id")
    id=cs_id(1,"network"); cs_null(id,"selected_wan"); cs_null(id,"discovery"); if(cs_string(id,"address_family",0)!="auto") reject()
    backup=cs_id(1,"backup"); cs_null(backup,"destination"); cs_null(backup,"date_format"); cs_null(backup,"retention"); cs_null(backup,"last_backup")
    id=cs_id(backup,"set_id"); if(id && cfmgr_json_tree_kind[id]!="null") reject()
    ownership=cs_id(1,"ownership"); cs_empty(cs_id(ownership,"components")); cs_null(ownership,"migration")
    cs_empty(cs_id(1,"credentials"))
    id=cs_id(cs_id(1,"history"),"network"); if(id && cfmgr_json_tree_kind[id]!="null") reject()
}
'
	# CFMGR-AWK-END config_schema
}

cfmgr_config_awk_config_observation() {
	# CFMGR-AWK-BEGIN config_observation
	cfmgr_awk_program='
# SPDX-License-Identifier: GPL-3.0-or-later
# Subsequent trusted consumer of config JSON getter tree mode. No file operands; immutable
# private stdin and LC_ALL=C are caller obligations. Only fixed modes use -v;
# observation strings enter through ENVIRON to avoid awk assignment decoding.
# check/observe emit one receipt; patch emits only original/patched JSON bytes.
# Caller must check status, receipt framing and independently measured output.
BEGIN { co_observation_read() }

# The archive payload consumer may borrow this fully validated immutable tree.
# Ordinary modes retain their exact receipts and process exit behavior.
function co_observation_read() {
    if (!cfmgr_json_tree_ready || cfmgr_json_mode != "tree") reject()
    if (cfmgr_config_mode != "fresh" && cfmgr_config_mode != "check" && cfmgr_config_mode != "observe" &&
        cfmgr_config_mode != "patch" && cfmgr_config_mode != "scope" &&
        cfmgr_config_mode != "settings-read" && cfmgr_config_mode != "settings-observe" &&
        cfmgr_config_mode != "settings-patch" && cfmgr_config_mode != "backup-read" &&
        cfmgr_config_mode != "backup-observe" && cfmgr_config_mode != "backup-patch" &&
        cfmgr_config_mode !~ /^archive-(data|read|preferences-(observe|patch)|history-(observe|patch))$/) reject()
    co_archive_mode = (cfmgr_config_mode ~ /^archive-/ && cfmgr_config_mode != "archive-data")

    for (co_i = 2; co_i <= cfmgr_json_tree_count; co_i++)
        co_child[cfmgr_json_tree_parent[co_i], cfmgr_json_tree_location[co_i]] = co_i

    co_type(1, "object")
    co_schema = co_field(1, "schema", "number")
    co_version = cfmgr_json_tree_payload[co_schema]
    if (co_version != "n1" && co_version != "n2") reject()
    co_generation = co_field(1, "generation", "number")
    co_old = substr(cfmgr_json_tree_payload[co_generation], 2)
    if (co_old !~ /^[1-9][0-9]*$/ || length(co_old) > 20) reject()
    co_new = co_old

    co_manager = co_field(1, "manager", "object")
    co_check = co_field(co_manager, "check_updates", "boolean")
    co_auto = co_field(co_manager, "auto_update", "boolean")
    co_developer = co_field(co_manager, "developer", "boolean")
    co_field(co_manager, "developer_log_directory", "string|null")
    co_source = co_field(co_manager, "source", "object")
    co_field(co_source, "repository", "string")
    co_field(co_source, "branch", "string")
    co_field(co_source, "commit", "string")
    co_storage = co_field(1, "storage", "object")
    co_entware = co_field(co_storage, "entware", "object")
    co_ids[1] = co_field(co_entware, "uuid", "string")
    co_ids[2] = co_field(co_entware, "filesystem", "string")
    co_ids[3] = co_field(co_entware, "root", "string")
    co_ids[4] = co_field(co_entware, "relative", "string")
    for (co_i = 1; co_i <= 4; co_i++)
        co_saved[co_i] = co_decode(substr(cfmgr_json_tree_payload[co_ids[co_i]], 2))
    co_observation_valid(co_saved[1], co_saved[2], co_saved[3], co_saved[4])

    if (co_version == "n2") cs_validate()
    else {
    co_features[1] = "ddns"
    co_features[2] = "ip_sync"
    co_features[3] = "cloudflared"
    co_logging = co_field(1, "logging", "object")
    co_history = co_field(1, "history", "object")
    for (co_i = 1; co_i <= 3; co_i++) {
        co_feature = co_field(1, co_features[co_i], "object")
        co_field(co_feature, "configured", "boolean")
        co_field(co_feature, "enabled", "boolean")
        co_log = co_field(co_logging, co_features[co_i], "object")
        co_field(co_log, "configured", "boolean")
        co_field(co_log, "enabled", "boolean")
        co_field(co_log, "opt_out", "boolean")
        co_field(co_log, "policy", "object|string|null")
        co_field(co_history, co_features[co_i], "object|array|string|null")
    }
    co_ddns = co_field(1, "ddns", "object")
    co_field(co_ddns, "credentials", "object|string|null")
    co_field(co_ddns, "records", "array")
    co_field(co_ddns, "proxied", "boolean|null")
    co_sync = co_field(1, "ip_sync", "object")
    co_field(co_sync, "credentials", "object|string|null")
    co_field(co_sync, "targets", "array")
    co_cloud = co_field(1, "cloudflared", "object")
    co_cloud_configured = co_field(co_cloud, "configured", "boolean")
    co_cloud_enabled = co_field(co_cloud, "enabled", "boolean")
    if (cfmgr_json_tree_kind[co_cloud_enabled] == "true" &&
        cfmgr_json_tree_kind[co_cloud_configured] != "true") reject()
    co_field(co_cloud, "installed", "boolean")
    co_field(co_cloud, "maintenance_enabled", "boolean")
    co_field(co_cloud, "binary_auto_update", "boolean|null")
    co_refs = co_field(co_cloud, "credential_refs", "object")
    co_field(co_refs, "runtime", "string|null")
    co_field(co_refs, "management", "string|null")
    co_field(co_refs, "certificate", "string|null")
    co_network = co_field(1, "network", "object")
    co_field(co_network, "address_family", "string")
    co_field(co_network, "selected_wan", "string|number|null")
    }
    co_backup = co_field(1, "backup", "object")
    if (co_archive_mode) co_archive_saved()
    co_destination = co_field(co_backup, "destination", "object|null")
    co_backup_present = (cfmgr_json_tree_kind[co_destination] == "object")
    if (co_backup_present) {
        co_backup_schema = co_field(co_destination, "schema", "number")
        if (cfmgr_json_tree_payload[co_backup_schema] != "n1") reject()
        co_backup_keys[1] = "mountpoint"; co_backup_keys[2] = "uuid"
        co_backup_keys[3] = "filesystem"; co_backup_keys[4] = "root"
        co_backup_fields = 0
        for (co_i = 1; co_i <= cfmgr_json_tree_count; co_i++)
            if (cfmgr_json_tree_parent[co_i] == co_destination) co_backup_fields++
        if (co_version == "n1" && co_backup_fields != 5) reject()
        for (co_i = 1; co_i <= 4; co_i++) {
            co_bi = co_field(co_destination, co_backup_keys[co_i], "string")
            co_backup_saved[co_i] = co_decode(substr(cfmgr_json_tree_payload[co_bi], 2))
        }
        co_backup_valid(co_backup_saved[1], co_backup_saved[2], co_backup_saved[3], co_backup_saved[4])
        if (co_backup_saved[2] ~ /^[0-9A-Fa-f-]+$/) co_backup_saved[2] = tolower(co_backup_saved[2])
    }
    co_field(1, "credentials", "object")
    co_field(1, "ownership", "object")

    if (cfmgr_config_mode == "archive-data") {
        co_observation_ready = 1
        return
    }

    if (cfmgr_config_mode == "fresh") {
        if (co_version != "n2") reject()
        cs_fresh()
        exit 0
    }

    if (co_archive_mode) {
        co_archive_dispatch()
        exit 0
    }

    if (cfmgr_config_mode ~ /^backup-/) {
        if (cfmgr_config_mode == "backup-read") {
            printf "CFMGR-BACKUP-CONFIG 1 %s %d %s %s %s %s END\n", co_old, co_backup_present,
                (co_backup_present ? co_hex(co_backup_saved[1]) : "-"),
                (co_backup_present ? co_hex(co_backup_saved[2]) : "-"),
                (co_backup_present ? co_hex(co_backup_saved[3]) : "-"),
                (co_backup_present ? co_hex(co_backup_saved[4]) : "-")
            exit 0
        }
        co_backup_want[1] = ENVIRON["CFMGR_BACKUP_MOUNT"]
        co_backup_want[2] = ENVIRON["CFMGR_BACKUP_UUID"]
        co_backup_want[3] = ENVIRON["CFMGR_BACKUP_FILESYSTEM"]
        co_backup_want[4] = ENVIRON["CFMGR_BACKUP_ROOT"]
        co_backup_valid(co_backup_want[1], co_backup_want[2], co_backup_want[3], co_backup_want[4])
        if (co_backup_want[2] ~ /^[0-9A-Fa-f-]+$/) co_backup_want[2] = tolower(co_backup_want[2])
        co_changed = !co_backup_present
        co_backup_json = "{\"schema\":1"
        co_backup_keys[1] = "mountpoint"; co_backup_keys[2] = "uuid"
        co_backup_keys[3] = "filesystem"; co_backup_keys[4] = "root"
        for (co_i = 1; co_i <= 4; co_i++) {
            if ("v" co_backup_want[co_i] != "v" co_backup_saved[co_i]) co_changed = 1
            co_backup_json = co_backup_json ",\"" co_backup_keys[co_i] "\":" co_quote(co_backup_want[co_i])
        }
        co_backup_json = co_backup_json "}"
        co_result = document
        if (co_changed) {
            co_new = co_increment(co_old)
            co_replacement[co_generation] = co_new
            if (co_version == "n2" && co_backup_present) {
                # Schema2 extensions are inert and remain byte-for-byte even
                # inside the selected destination; only known saved fields move.
                for (co_i = 1; co_i <= 4; co_i++)
                    if ("v" co_backup_want[co_i] != "v" co_backup_saved[co_i])
                        co_replacement[cs_id(co_destination, co_backup_keys[co_i])] = co_quote(co_backup_want[co_i])
            } else co_replacement[co_destination] = co_backup_json
            co_result = ""; co_cursor = 1
            for (co_i = 1; co_i <= cfmgr_json_tree_count; co_i++) {
                if (!(co_i in co_replacement)) continue
                co_result = co_result substr(document, co_cursor, cfmgr_json_tree_start[co_i] - co_cursor) co_replacement[co_i]
                co_cursor = cfmgr_json_tree_end[co_i] + 1
            }
            co_result = co_result substr(document, co_cursor)
        }
        if (length(co_result) > 65536) reject()
        if (cfmgr_config_mode == "backup-patch") printf "%s", co_result
        else printf "CFMGR-BACKUP-PATCH 1 %s %s %d %d %d %d %d %d END\n", co_old, co_new,
            co_changed, (cfmgr_json_tree_kind[co_check] == "true"), (cfmgr_json_tree_kind[co_auto] == "true"),
            (cfmgr_json_tree_kind[co_developer] == "true"), expected_size, length(co_result)
        exit 0
    }

    if (cfmgr_config_mode ~ /^settings-/) {
        co_settings_check = (cfmgr_json_tree_kind[co_check] == "true" ? 1 : 0)
        co_settings_auto = (cfmgr_json_tree_kind[co_auto] == "true" ? 1 : 0)
        co_settings_developer = (cfmgr_json_tree_kind[co_developer] == "true" ? 1 : 0)
        if (cfmgr_config_mode == "settings-read") {
            printf "CFMGR-SETTINGS 1 %s %d %d %d END\n", co_old,
                co_settings_check, co_settings_auto, co_settings_developer
            exit 0
        }
        co_settings_mask = ENVIRON["CFMGR_SETTINGS_MASK"]
        co_settings_want_check = ENVIRON["CFMGR_SETTINGS_CHECK"]
        co_settings_want_auto = ENVIRON["CFMGR_SETTINGS_AUTO"]
        if (co_settings_mask !~ /^(check|auto|both)$/ || co_settings_want_check !~ /^[01]$/ ||
            co_settings_want_auto !~ /^[01]$/) reject()
        co_target_check = co_settings_check
        co_target_auto = co_settings_auto
        if (co_settings_mask == "check" || co_settings_mask == "both") co_target_check = co_settings_want_check + 0
        if (co_settings_mask == "auto" || co_settings_mask == "both") co_target_auto = co_settings_want_auto + 0
        # The reviewed intent closure is applied to a fresh locked base: Check
        # Off also disables Auto; Auto On also enables Check. Own-field changes
        # preserve the other fresh value. Contradictory explicit pairs refuse.
        if (co_settings_mask == "check" && !co_target_check) co_target_auto = 0
        if (co_settings_mask == "auto" && co_target_auto) co_target_check = 1
        if (co_target_auto && !co_target_check) reject()
        co_changed = (co_target_check != co_settings_check || co_target_auto != co_settings_auto)
        co_result = document
        if (co_changed) {
            co_new = co_increment(co_old)
            co_replacement[co_generation] = co_new
            if (co_target_check != co_settings_check) co_replacement[co_check] = (co_target_check ? "true" : "false")
            if (co_target_auto != co_settings_auto) co_replacement[co_auto] = (co_target_auto ? "true" : "false")
            co_result = ""; co_cursor = 1
            for (co_i = 1; co_i <= cfmgr_json_tree_count; co_i++) {
                if (!(co_i in co_replacement)) continue
                co_result = co_result substr(document, co_cursor, cfmgr_json_tree_start[co_i] - co_cursor) co_replacement[co_i]
                co_cursor = cfmgr_json_tree_end[co_i] + 1
            }
            co_result = co_result substr(document, co_cursor)
        }
        if (length(co_result) > 65536) reject()
        if (cfmgr_config_mode == "settings-patch") printf "%s", co_result
        else printf "CFMGR-SETTINGS-PATCH 1 %s %s %d %d %d %d %d %d END\n", co_old, co_new,
            co_changed, co_target_check, co_target_auto, co_settings_developer, expected_size, length(co_result)
        exit 0
    }

    if (cfmgr_config_mode == "scope") {
        printf "CFMGR-SCOPE 1 %s %s END\n", co_old,
            (cfmgr_json_tree_kind[co_cloud_configured] == "true" ? "tunnel" : "shared")
        exit 0
    }

    co_changed = 0
    co_result = document
    if (cfmgr_config_mode != "check") {
        co_current[1] = ENVIRON["CFMGR_CONFIG_UUID"]
        co_current[2] = ENVIRON["CFMGR_CONFIG_FILESYSTEM"]
        co_current[3] = ENVIRON["CFMGR_CONFIG_ROOT"]
        co_current[4] = ENVIRON["CFMGR_CONFIG_RELATIVE"]
        co_observation_valid(co_current[1], co_current[2], co_current[3], co_current[4])
        for (co_i = 1; co_i <= 4; co_i++) {
            # Encoding also verifies literal environment UTF-8 before any output.
            co_encoded[co_i] = co_quote(co_current[co_i])
            if ("v" co_current[co_i] != "v" co_saved[co_i]) co_changed = 1
        }
        if (co_changed) {
            co_new = co_increment(co_old)
            co_replacement[co_generation] = co_new
            for (co_i = 1; co_i <= 4; co_i++)
                if ("v" co_current[co_i] != "v" co_saved[co_i])
                    co_replacement[co_ids[co_i]] = co_encoded[co_i]
            co_result = ""
            co_cursor = 1
            # Preorder IDs also order these non-overlapping scalar spans.
            for (co_i = 1; co_i <= cfmgr_json_tree_count; co_i++) {
                if (!(co_i in co_replacement)) continue
                co_result = co_result substr(document, co_cursor,
                    cfmgr_json_tree_start[co_i] - co_cursor) co_replacement[co_i]
                co_cursor = cfmgr_json_tree_end[co_i] + 1
            }
            co_result = co_result substr(document, co_cursor)
        }
    }
    if (length(co_result) > 65536) reject()
    if (cfmgr_config_mode == "patch") printf "%s", co_result
    else printf "CFMGR-CONFIG 1 %s %s %d %d %d END\n", co_old, co_new,
        co_changed, expected_size, length(co_result)
    exit 0
}

function co_archive_saved(    id,value) {
    co_archive_format_id=cs_id(co_backup,"date_format")
    co_archive_format="-"
    if(co_archive_format_id) {
        co_type(co_archive_format_id,"string|null")
        if(cfmgr_json_tree_kind[co_archive_format_id]!="null") {
            value=co_decode(substr(cfmgr_json_tree_payload[co_archive_format_id],2))
            if(value!~/^(DMY|MDY|YMD)$/) reject()
            co_archive_format=value
        }
    }
    co_archive_keep_id=cs_id(co_backup,"retention")
    co_archive_keep="0"
    if(co_archive_keep_id) {
        co_type(co_archive_keep_id,"number|null")
        if(cfmgr_json_tree_kind[co_archive_keep_id]!="null") {
            co_archive_keep=cs_integer(co_archive_keep_id,"3","5")
        }
    }
    co_archive_saved_set=cs_optional_uuid(co_backup,"set_id")
    co_archive_last_id=cs_id(co_backup,"last_backup")
    if(co_archive_last_id && cfmgr_json_tree_kind[co_archive_last_id]!="object" &&
        cfmgr_json_tree_kind[co_archive_last_id]!="null") reject()
    if(co_archive_last_id && cfmgr_json_tree_kind[co_archive_last_id]=="object") {
        co_archive_record=cs_policy(co_backup,"last_backup")
        cs_generation(co_archive_record,"generation")
        cs_epoch(co_archive_record,"at")
        cs_enum(co_archive_record,"date_format","DMY|MDY|YMD",0)
        cs_string(co_archive_record,"local_date",0)
        cs_string(co_archive_record,"local_time",0)
        cs_string(co_archive_record,"timezone",0)
        cs_string(co_archive_record,"set_id",0)
        cs_string(co_archive_record,"archive_id",0)
    }
}

function co_archive_dispatch(    mode) {
    mode=cfmgr_config_mode
    if(mode=="archive-read") {
        printf "CFMGR-ARCHIVE-CONFIG 1 %s %s %s %s %s END\n",
            substr(cfmgr_json_tree_payload[co_schema],2), co_old,
            (co_archive_format=="-" ? "-" : co_archive_format), co_archive_keep,
            (co_archive_saved_set=="" ? "-" : co_archive_saved_set)
        return
    }
    if(mode=="archive-preferences-observe" || mode=="archive-preferences-patch") {
        co_archive_preferences(mode)
        return
    }
    co_archive_history(mode)
}

function co_archive_preferences(mode,    format,keep,set_id) {
    format=ENVIRON["CFMGR_ARCHIVE_FORMAT"]
    keep=ENVIRON["CFMGR_ARCHIVE_KEEP"]
    set_id=ENVIRON["CFMGR_ARCHIVE_SET_ID"]
    if(format!~/^(DMY|MDY|YMD)$/ || keep!~/^[345]$/ || cs_uuid(set_id)!=set_id) reject()
    if(co_archive_saved_set!="" && co_archive_saved_set!=set_id) reject()
    co_changed=(co_archive_format!=format || co_archive_keep!=keep || co_archive_saved_set!=set_id)
    co_result=document
    if(co_changed) {
        co_new=co_increment(co_old)
        co_replacement[co_generation]=co_new
        co_archive_missing=0
        co_archive_queue(co_backup,"date_format",co_quote(format),format)
        co_archive_queue(co_backup,"retention",keep)
        co_archive_queue(co_backup,"set_id",co_quote(set_id),set_id)
        co_archive_insert_missing(co_backup)
        co_result=co_archive_rebuild()
    }
    co_archive_output(mode)
}

function co_archive_history(mode,    set_id,archive_id,at,date,time,zone,format,generation,year,month,day,days,leap,i,id,value) {
    set_id=ENVIRON["CFMGR_ARCHIVE_SET_ID"]
    archive_id=ENVIRON["CFMGR_ARCHIVE_ID"]
    at=ENVIRON["CFMGR_ARCHIVE_AT"]
    date=ENVIRON["CFMGR_ARCHIVE_DATE"]
    time=ENVIRON["CFMGR_ARCHIVE_TIME"]
    zone=ENVIRON["CFMGR_ARCHIVE_ZONE"]
    format=ENVIRON["CFMGR_ARCHIVE_FORMAT"]
    generation=ENVIRON["CFMGR_ARCHIVE_GENERATION"]
    if(cs_uuid(set_id)!=set_id || cs_uuid(archive_id)!=archive_id) reject()
    if(at!~/^(0|[1-9][0-9]*)$/ || length(at)>10 || !cs_le(at,"9999999999")) reject()
    if(date!~/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) reject()
    year=substr(date,1,4)+0; month=substr(date,6,2)+0; day=substr(date,9,2)+0
    if(year<1 || month<1 || month>12 || day<1) reject()
    leap=(year%4==0 && (year%100!=0 || year%400==0))
    days=(month==2 ? (leap ? 29 : 28) : (month==4 || month==6 || month==9 || month==11 ? 30 : 31))
    if(day>days) reject()
    if(time!~/^[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/ ||
        substr(time,1,2)+0>23 || substr(time,4,2)+0>59 || substr(time,7,2)+0>59) reject()
    if(length(zone)==0 || length(zone)>1024) reject()
    for(i=1;i<=length(zone);i++) {
        value=byte_value["b" substr(zone,i,1)]
        if(value<32 || value>126) reject()
    }
    if(format!~/^(DMY|MDY|YMD)$/ || generation!~/^[1-9][0-9]*$/ || length(generation)>20 || !cs_le(generation,co_old)) reject()
    if(co_archive_saved_set=="" || co_archive_saved_set!=set_id || co_archive_format!=format) reject()

    co_history_values[1]="1"
    co_history_values[2]=generation
    co_history_values[3]=at
    co_history_values[4]=co_quote(format)
    co_history_values[5]=co_quote(date)
    co_history_values[6]=co_quote(time)
    co_history_values[7]=co_quote(zone)
    co_history_values[8]=co_quote(set_id)
    co_history_values[9]=co_quote(archive_id)
    co_history_plain[4]=format; co_history_plain[5]=date; co_history_plain[6]=time
    co_history_plain[7]=zone; co_history_plain[8]=set_id; co_history_plain[9]=archive_id
    co_history_keys[1]="schema"; co_history_keys[2]="generation"; co_history_keys[3]="at"
    co_history_keys[4]="date_format"; co_history_keys[5]="local_date"
    co_history_keys[6]="local_time"; co_history_keys[7]="timezone"
    co_history_keys[8]="set_id"; co_history_keys[9]="archive_id"
    co_changed=0
    co_result=document
    co_archive_missing=0
    if(!co_archive_last_id) {
        co_archive_queue(co_backup,"last_backup",co_archive_object(9))
        co_archive_insert_missing(co_backup)
        co_changed=1
    } else if(cfmgr_json_tree_kind[co_archive_last_id]=="null") {
        co_replacement[co_archive_last_id]=co_archive_object(9)
        co_changed=1
    } else {
        for(i=1;i<=9;i++) {
            id=cs_id(co_archive_last_id,co_history_keys[i])
            if(!id) {
                co_archive_queue(co_archive_last_id,co_history_keys[i],co_history_values[i])
                co_changed=1
            } else {
                co_type(id,(i<=3 ? "number" : "string"))
                value=(i<=3 ? substr(cfmgr_json_tree_payload[id],2) : co_decode(substr(cfmgr_json_tree_payload[id],2)))
                if(value!=(i<=3 ? co_history_values[i] : co_history_plain[i])) {
                    co_replacement[id]=co_history_values[i]
                    co_changed=1
                }
            }
        }
        if(co_archive_missing) co_archive_insert_missing(co_archive_last_id)
    }
    if(co_changed) {
        co_new=co_increment(co_old)
        co_replacement[co_generation]=co_new
        co_result=co_archive_rebuild()
    }
    co_archive_output(mode)
}

function co_archive_queue(parent,key,value,plain,    id) {
    id=cs_id(parent,key)
    if(!id) {
        co_archive_missing++
        co_archive_missing_key[co_archive_missing]=key
        co_archive_missing_value[co_archive_missing]=value
        return
    }
    if(cfmgr_json_tree_kind[id]=="null") {
        co_replacement[id]=value
        return
    }
    if(key=="date_format" || key=="set_id") {
        if(co_decode(substr(cfmgr_json_tree_payload[id],2))!=plain) co_replacement[id]=value
    } else if(cfmgr_json_tree_payload[id]!=("n" value)) co_replacement[id]=value
}

function co_archive_insert_missing(object,    i,properties,last,children,original,inside,start,finish) {
    if(!co_archive_missing) return
    properties=""
    for(i=1;i<=co_archive_missing;i++)
        properties=properties (i==1 ? "" : ",") co_quote(co_archive_missing_key[i]) ":" co_archive_missing_value[i]
    last=0; children=0
    for(i=2;i<=cfmgr_json_tree_count;i++) {
        if(cfmgr_json_tree_parent[i]!=object) continue
        children++
        if(!last || cfmgr_json_tree_end[i]>cfmgr_json_tree_end[last]) last=i
    }
    if(children) {
        original=(last in co_replacement ? co_replacement[last] : substr(document,cfmgr_json_tree_start[last],cfmgr_json_tree_end[last]-cfmgr_json_tree_start[last]+1))
        co_replacement[last]=original "," properties
    } else {
        start=cfmgr_json_tree_start[object]; finish=cfmgr_json_tree_end[object]
        inside=substr(document,start+1,finish-start-1)
        co_replacement[object]="{" properties inside "}"
    }
    co_archive_missing=0
}

function co_archive_object(count,    i,result) {
    result="{"
    for(i=1;i<=count;i++) result=result (i==1 ? "" : ",") co_quote(co_history_keys[i]) ":" co_history_values[i]
    return result "}"
}

function co_archive_rebuild(    i,cursor,result) {
    result=""; cursor=1
    for(i=1;i<=cfmgr_json_tree_count;i++) {
        if(!(i in co_replacement)) continue
        result=result substr(document,cursor,cfmgr_json_tree_start[i]-cursor) co_replacement[i]
        cursor=cfmgr_json_tree_end[i]+1
    }
    result=result substr(document,cursor)
    if(length(result)>65536) reject()
    return result
}

function co_archive_output(mode) {
    if(length(co_result)>65536) reject()
    if(mode=="archive-preferences-patch" || mode=="archive-history-patch") printf "%s",co_result
    else printf "CFMGR-ARCHIVE-PATCH 1 %s %s %d %d %d %d %d %d END\n",co_old,co_new,co_changed,
        (cfmgr_json_tree_kind[co_check]=="true"),(cfmgr_json_tree_kind[co_auto]=="true"),
        (cfmgr_json_tree_kind[co_developer]=="true"),expected_size,length(co_result)
}

function co_hex(value,    i, result, character) {
    result = ""
    for (i = 1; i <= length(value); i++) {
        character = substr(value, i, 1)
        if (!("b" character in byte_value)) reject()
        result = result byte_hex[byte_value["b" character]]
    }
    return result
}

function co_type(id, allowed,    kind) {
    if (!id) reject()
    kind = cfmgr_json_tree_kind[id]
    if (kind == "true" || kind == "false") kind = "boolean"
    if (index("|" allowed "|", "|" kind "|") == 0) reject()
    return id
}

function co_field(parent, key, allowed) {
    return co_type(co_child[parent, "k" co_hex(key)], allowed)
}

function co_decode(value,    i, code, result) {
    result = ""
    for (i = 1; i <= length(value); i += 2) {
        code = hex_value["h" substr(value, i, 1)] * 16 + hex_value["h" substr(value, i + 1, 1)]
        # This decoder is only for observation fields, where controls are forbidden.
        if (code < 32 || code == 127) reject()
        result = result sprintf("%c", code)
    }
    return result
}

function co_path(value, absolute,    i, code) {
    if (length(value) == 0 || length(value) > 4096) reject()
    for (i = 1; i <= length(value); i++) {
        code = byte_value["b" substr(value, i, 1)]
        if (code < 32 || code == 127) reject()
    }
    if (index(value, "//") || value ~ /(^|\/)\.\.?\// || value ~ /\/\.\.?$/) reject()
    if (absolute) {
        if (substr(value, 1, 1) != "/" || (value != "/" && value ~ /\/$/)) reject()
    } else {
        if (substr(value, 1, 1) == "/" || value ~ /\/$/ || value == "..") reject()
    }
}

function co_observation_valid(uuid, filesystem, root, relative,    groups, count, i) {
    count = split(uuid, groups, "-")
    if (count != 5 || length(groups[1]) != 8 || length(groups[2]) != 4 ||
        length(groups[3]) != 4 || length(groups[4]) != 4 || length(groups[5]) != 12) reject()
    for (i = 1; i <= 5; i++) if (groups[i] !~ /^[0-9a-fA-F]+$/) reject()
    if (filesystem != "ext2" && filesystem != "ext3" && filesystem != "ext4") reject()
    co_path(root, 1)
    co_path(relative, 0)
}

function co_backup_valid(point, uuid, filesystem, root,    i, value) {
    co_path(point, 1); co_path(root, 1)
    if (substr(point, 1, 9) != "/tmp/mnt/" || length(point) > 1024 || length(root) > 1024 ||
        length(uuid) > 128 || uuid !~ /^[A-Za-z0-9][A-Za-z0-9._:-]*$/ ||
        length(filesystem) > 32 || filesystem !~ /^[A-Za-z0-9][A-Za-z0-9_+.-]*$/) reject()
    value = point root
    for (i = 1; i <= length(value); i++)
        if (byte_value["b" substr(value, i, 1)] > 126) reject()
}

function co_increment(value,    i, digit_value, carry, result) {
    carry = 1
    result = ""
    for (i = length(value); i >= 1; i--) {
        digit_value = substr(value, i, 1) + carry
        carry = (digit_value == 10)
        if (carry) digit_value = 0
        result = sprintf("%d", digit_value) result
    }
    if (carry) result = "1" result
    if (length(result) > 20) reject()
    return result
}

function co_quote(value,    saved_document, saved_position, result, character, start) {
    saved_document = document
    saved_position = position
    document = value
    position = 1
    result = "\""
    while (position <= length(document)) {
        start = position
        character = peek()
        raw_utf8_hex(character)
        if (character == "\"" || character == "\\") result = result "\\"
        result = result substr(document, start, position - start)
    }
    document = saved_document
    position = saved_position
    return result "\""
}
'
	# CFMGR-AWK-END config_observation
}
