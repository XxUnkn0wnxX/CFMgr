#!/bin/sh
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
