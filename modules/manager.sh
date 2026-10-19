#!/bin/sh
# Category owner: manager. Sourcing defines functions only.

# ---- manager settings ----
# Source-inert interactive consumer for manager preferences. Store owns native
# reads, locking, validation and publication; this module owns no files.

cfmgr_ms_effective() {
	if [ "$cfmgr_ms_developer" = 1 ]; then
		cfmgr_ms_effective_check=0 cfmgr_ms_effective_auto=0
	else
		cfmgr_ms_effective_check=$cfmgr_ms_check
		cfmgr_ms_effective_auto=0
		if [ "$cfmgr_ms_check" = 1 ] && [ "$cfmgr_ms_auto" = 1 ]; then cfmgr_ms_effective_auto=1; fi
	fi
}

cfmgr_ms_on_off() {
	if [ "$1" = 1 ]; then cfmgr_ms_on_off_value=On; else cfmgr_ms_on_off_value=Off; fi
}

cfmgr_ms_show() {
	cfmgr_ms_effective
	cfmgr_ms_on_off "$cfmgr_ms_check"
	cfmgr_ms_show_check=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_auto"
	cfmgr_ms_show_auto=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_developer"
	cfmgr_ms_show_developer=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_draft_check"
	cfmgr_ms_show_draft_check=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_draft_auto"
	cfmgr_ms_show_draft_auto=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_effective_check"
	cfmgr_ms_show_effective_check=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_effective_auto"
	cfmgr_ms_show_effective_auto=$cfmgr_ms_on_off_value
	printf '%s\n' 'CFMgr updates: preferences only; checking/installing updates is unavailable yet.'
	printf 'Saved: Check for updates=%s; Auto-update CFMgr=%s; Developer=%s\n' \
		"$cfmgr_ms_show_check" "$cfmgr_ms_show_auto" "$cfmgr_ms_show_developer"
	printf 'Draft: Check for updates=%s; Auto-update CFMgr=%s\n' "$cfmgr_ms_show_draft_check" "$cfmgr_ms_show_draft_auto"
	printf 'Effective now: Check for updates=%s; Auto-update CFMgr=%s\n' \
		"$cfmgr_ms_show_effective_check" "$cfmgr_ms_show_effective_auto"
	[ "$cfmgr_ms_developer" != 1 ] || printf '%s\n' 'Developer mode suppresses manager updates; saved preferences are retained.'
	[ "$cfmgr_ms_pending" != 1 ] || printf '[CFMGR] settings: warning: pending Save/recovery state; use explicit recovery\n'
	printf '%s\n' '1 Toggle Check for updates' '2 Toggle Auto-update CFMgr' 's Save preferences' 'e Back'
	[ "$cfmgr_ms_pending" != 1 ] || printf '%s\n' 'r Recover previous Save'
}

# Keep the Store status outside the captured frame and preserve exact newlines.
cfmgr_ms_call() {
	cfmgr_ms_capture=$(
		cfmgr_config_store "$@"
		cfmgr_ms_status=$?
		printf 'CFMGR-STATUS:%s' "$cfmgr_ms_status"
	)
	cfmgr_ms_status=${cfmgr_ms_capture##*CFMGR-STATUS:}
	case $cfmgr_ms_status in '' | *[!0-9]*) return 1 ;; esac
	cfmgr_ms_raw=${cfmgr_ms_capture%CFMGR-STATUS:*}
	[ "$cfmgr_ms_capture" = "$cfmgr_ms_raw"CFMGR-STATUS:"$cfmgr_ms_status" ] || return 1
	cfmgr_ms_newline=$(printf '\n.')
	cfmgr_ms_newline=${cfmgr_ms_newline%.}
	case $cfmgr_ms_raw in *"$cfmgr_ms_newline") cfmgr_ms_line=${cfmgr_ms_raw%"$cfmgr_ms_newline"} ;; *) return 1 ;; esac
	case $cfmgr_ms_line in *"$cfmgr_ms_newline"*) return 1 ;; esac
	IFS=' ' read -r cfmgr_ms_tag cfmgr_ms_schema cfmgr_ms_result cfmgr_ms_generation \
		cfmgr_ms_check cfmgr_ms_auto cfmgr_ms_developer cfmgr_ms_pending cfmgr_ms_end cfmgr_ms_extra <<EOF_STORE
$cfmgr_ms_line
EOF_STORE
	[ "$cfmgr_ms_tag:$cfmgr_ms_schema:$cfmgr_ms_end:$cfmgr_ms_extra" = CFMGR-STORE:1:END: ] || return 1
	case $cfmgr_ms_result in read | saved | unchanged | recovered | busy | stale | unavailable | recovery | unresolved) ;; *) return 1 ;; esac
	case $cfmgr_ms_generation in
	0) [ "$cfmgr_ms_status" != 0 ] && [ "$cfmgr_ms_result" != read ] &&
		[ "$cfmgr_ms_result" != saved ] && [ "$cfmgr_ms_result" != unchanged ] &&
		[ "$cfmgr_ms_result" != recovered ] || return 1 ;;
	'' | 0* | *[!0-9]*) return 1 ;;
	*) [ "${#cfmgr_ms_generation}" -le 20 ] || return 1 ;;
	esac
	case $cfmgr_ms_check:$cfmgr_ms_auto:$cfmgr_ms_developer:$cfmgr_ms_pending in [01]:[01]:[01]:[01]) ;; *) return 1 ;; esac
	[ "$cfmgr_ms_line" = "CFMGR-STORE 1 $cfmgr_ms_result $cfmgr_ms_generation $cfmgr_ms_check $cfmgr_ms_auto $cfmgr_ms_developer $cfmgr_ms_pending END" ] || return 1
	case $1:$cfmgr_ms_result:$cfmgr_ms_status:$cfmgr_ms_pending in
	read:read:0:0 | read:read:0:1 | save:saved:0:0 | save:unchanged:0:0 | recover:recovered:0:0 | recover:unchanged:0:0) return 0 ;;
	*) [ "$cfmgr_ms_status" != 0 ] || return 1 ;;
	esac
	case $cfmgr_ms_result in busy | stale | unavailable | recovery | unresolved) return 0 ;; esac
	return 1
}

cfmgr_ms_report_failure() {
	case $cfmgr_ms_result in
	busy) printf '[CFMGR] settings: warning: settings save busy; no changes were saved\n' >&2 ;;
	stale) printf '[CFMGR] settings: warning: preferences changed; review current settings\n' >&2 ;;
	unavailable) printf '[CFMGR] settings: error: native settings unavailable\n' >&2 ;;
	recovery) printf '[CFMGR] settings: error: previous Save needs explicit recovery\n' >&2 ;;
	unresolved) printf '[CFMGR] settings: error: settings operation unresolved; leaving settings\n' >&2 ;;
	*) printf '[CFMGR] settings: error: invalid settings response\n' >&2 ;;
	esac
}

cfmgr_ms_load() {
	if ! cfmgr_ms_call read; then
		printf '[CFMGR] settings: error: invalid settings response\n' >&2
		return 1
	fi
	if [ "$cfmgr_ms_result" != read ]; then
		cfmgr_ms_report_failure
		return 1
	fi
	cfmgr_ms_draft_check=$cfmgr_ms_check cfmgr_ms_draft_auto=$cfmgr_ms_auto
	cfmgr_ms_check_owned=0 cfmgr_ms_auto_owned=0
}

cfmgr_ms_save_confirm() {
	cfmgr_ms_effective_check=$cfmgr_ms_draft_check cfmgr_ms_effective_auto=0
	if [ "$cfmgr_ms_developer" = 1 ]; then
		cfmgr_ms_effective_check=0
	else
		if [ "$cfmgr_ms_draft_check" = 1 ] && [ "$cfmgr_ms_draft_auto" = 1 ]; then cfmgr_ms_effective_auto=1; fi
	fi
	cfmgr_ms_on_off "$cfmgr_ms_draft_check"
	cfmgr_ms_review_check=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_draft_auto"
	cfmgr_ms_review_auto=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_effective_check"
	cfmgr_ms_review_effective_check=$cfmgr_ms_on_off_value
	cfmgr_ms_on_off "$cfmgr_ms_effective_auto"
	cfmgr_ms_review_effective_auto=$cfmgr_ms_on_off_value
	printf 'Review Save: Check for updates=%s; Auto-update CFMgr=%s; effective Check=%s; effective Auto=%s\n' \
		"$cfmgr_ms_review_check" "$cfmgr_ms_review_auto" "$cfmgr_ms_review_effective_check" "$cfmgr_ms_review_effective_auto"
	[ "$cfmgr_ms_developer" != 1 ] || printf '%s\n' 'Developer mode suppresses both effective settings.'
	printf 'Save these preferences? [y/N/e] '
	IFS= read -r cfmgr_ms_answer || return 2
	case $cfmgr_ms_answer in y | Y | yes | YES) return 0 ;; e) return 2 ;; esac
	printf '%s\n' 'Save cancelled; no changes were written.'
	return 1
}

cfmgr_ms_mask() {
	case $cfmgr_ms_check_owned:$cfmgr_ms_auto_owned in
	1:1) cfmgr_ms_save_mask=both ;;
	1:0) cfmgr_ms_save_mask=check ;;
	0:1) cfmgr_ms_save_mask=auto ;;
	*) cfmgr_ms_save_mask='' ;;
	esac
}

cfmgr_ms_after_operation() {
	cfmgr_ms_operation=$1
	if [ "$cfmgr_ms_operation" = save ]; then
		if ! cfmgr_ms_call save "$cfmgr_ms_save_mask" "$cfmgr_ms_draft_check" "$cfmgr_ms_draft_auto"; then
			printf '[CFMGR] settings: error: invalid settings response\n' >&2
			return 1
		fi
	else
		if ! cfmgr_ms_call "$cfmgr_ms_operation"; then
			printf '[CFMGR] settings: error: invalid settings response\n' >&2
			return 1
		fi
	fi
	case $cfmgr_ms_result in
	read | saved | unchanged | recovered)
		case $cfmgr_ms_operation:$cfmgr_ms_result in
		read:read | save:saved | save:unchanged | recover:recovered | recover:unchanged) ;;
		*)
			printf '[CFMGR] settings: error: unexpected settings response\n' >&2
			return 1
			;;
		esac
		case $cfmgr_ms_result in
		saved) printf '%s\n' 'Preferences saved.' ;;
		unchanged)
			if [ "$cfmgr_ms_operation" = recover ]; then
				printf '%s\n' 'No pending Save to recover.'
			else
				printf '%s\n' 'Preferences already match the requested values.'
			fi
			;;
		recovered) printf '%s\n' 'Previous Save recovered; no settings were replayed.' ;;
		esac
		;;
	*)
		cfmgr_ms_report_failure
		[ "$cfmgr_ms_result" != unresolved ] || return 2
		;;
	esac
	cfmgr_ms_load || return 1
}

cfmgr_manager_settings() {
	[ -t 0 ] || {
		printf '[CFMGR] settings: warning: interactive terminal required\n' >&2
		return 1
	}
	cfmgr_ms_load || return 1
	while :; do
		cfmgr_ms_show
		IFS= read -r cfmgr_ms_choice || return 0
		case $cfmgr_ms_choice in
		1)
			if [ "$cfmgr_ms_draft_check" = 1 ]; then
				cfmgr_ms_draft_check=0 cfmgr_ms_draft_auto=0 cfmgr_ms_auto_owned=1
			else cfmgr_ms_draft_check=1; fi
			cfmgr_ms_check_owned=1
			;;
		2)
			if [ "$cfmgr_ms_draft_auto" = 1 ]; then
				cfmgr_ms_draft_auto=0
			else cfmgr_ms_draft_auto=1 cfmgr_ms_draft_check=1 cfmgr_ms_check_owned=1; fi
			cfmgr_ms_auto_owned=1
			;;
		s)
			cfmgr_ms_mask
			if [ -z "$cfmgr_ms_save_mask" ]; then
				printf '%s\n' 'No preference changes staged; nothing was saved.'
				continue
			fi
			if cfmgr_ms_save_confirm; then :; else
				cfmgr_ms_confirm_code=$?
				[ "$cfmgr_ms_confirm_code" != 2 ] || return 0
				continue
			fi
			if cfmgr_ms_after_operation save; then :; else
				cfmgr_ms_operation_code=$?
				[ "$cfmgr_ms_operation_code" != 2 ] || return 1
				return 1
			fi
			;;
		r)
			[ "$cfmgr_ms_pending" = 1 ] || continue
			printf 'Recover previous configuration Save? [y/N/e] '
			IFS= read -r cfmgr_ms_answer || return 0
			case $cfmgr_ms_answer in
			y | Y | yes | YES) ;;
			e) return 0 ;;
			*)
				printf '%s\n' 'Recovery cancelled; no recovery was attempted.'
				continue
				;;
			esac
			if cfmgr_ms_after_operation recover; then :; else
				cfmgr_ms_operation_code=$?
				[ "$cfmgr_ms_operation_code" != 2 ] || return 1
				return 1
			fi
			;;
		e) return 0 ;;
		esac
	done
}

# ---- Main menu ----
cfmgr_launch_menu() {
	[ -t 0 ] || return 1
	while :; do
		printf '%s\n' 'CFMgr main menu' '0 Check status' '4 Backup / Restore' 'ao Advanced options' 'e Exit'
		IFS= read -r cfmgr_launch_choice || return 1
		case $cfmgr_launch_choice in
		e) return 1 ;;
		0) cfmgr_status_native || : ;;
		4) cfmgr_backup_menu || : ;;
		ao)
			while :; do
				printf '%s\n' 'Advanced options: other actions unavailable' '1 Reinstall Entware dependencies' '2 CFMgr updates' 'e Back'
				IFS= read -r cfmgr_launch_choice || return 1
				case $cfmgr_launch_choice in
				1) return 0 ;;
				2) cfmgr_manager_settings || : ;;
				e) break ;;
				esac
			done
			;;
		esac
	done
}
