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

# ---- developer diagnostic destination preference ----
# This consumer stores only the explicit path preference. The logging module
# owns physical admission/preview; browsing these options never creates files.
cfmgr_md_hex_valid() {
	[ "$#" -eq 1 ] || return 1
	case $1 in '' | *[!0-9a-f]*) return 1 ;; esac
	[ "${#1}" -le 2048 ] && [ "$((${#1} % 2))" = 0 ]
}

cfmgr_md_decode_path() {
	[ "$#" -eq 1 ] && cfmgr_md_hex_valid "$1" || return 1
	cfmgr_backup_unhex "$1" text || return 1
	# cfmgr_backup_unhex sets this decoded result on success.
	# shellcheck disable=SC2154
	cfmgr_md_path=$cfmgr_backup_decoded
	case $cfmgr_md_path in /*) ;; *) return 1 ;; esac
	[ "${#cfmgr_md_path}" -le 1024 ]
}

# Capture exactly one typed Store receipt and its exit status; never evaluate
# receipt fields or expose an undecoded path to shell syntax.
cfmgr_md_call() {
	case ${1:-}:$# in read:1 | recover:1 | save:2) ;; *) return 1 ;; esac
	cfmgr_md_capture=$(
		cfmgr_diagnostic_settings "$@"
		cfmgr_md_status=$?
		printf 'CFMGR-STATUS:%s' "$cfmgr_md_status"
	)
	cfmgr_md_status=${cfmgr_md_capture##*CFMGR-STATUS:}
	case $cfmgr_md_status in '' | *[!0-9]*) return 1 ;; esac
	cfmgr_md_raw=${cfmgr_md_capture%CFMGR-STATUS:*}
	[ "$cfmgr_md_capture" = "$cfmgr_md_raw"CFMGR-STATUS:"$cfmgr_md_status" ] || return 1
	cfmgr_md_newline=$(printf '\n.')
	cfmgr_md_newline=${cfmgr_md_newline%.}
	case $cfmgr_md_raw in *"$cfmgr_md_newline") cfmgr_md_line=${cfmgr_md_raw%"$cfmgr_md_newline"} ;; *) return 1 ;; esac
	case $cfmgr_md_line in *"$cfmgr_md_newline"*) return 1 ;; esac
	IFS=' ' read -r cfmgr_md_tag cfmgr_md_schema cfmgr_md_result cfmgr_md_generation \
		cfmgr_md_developer cfmgr_md_pending cfmgr_md_saved_hex cfmgr_md_end cfmgr_md_extra <<EOF_DIAGNOSTIC
$cfmgr_md_line
EOF_DIAGNOSTIC
	[ "$cfmgr_md_tag:$cfmgr_md_schema:$cfmgr_md_end:$cfmgr_md_extra" = CFMGR-DIAGNOSTIC:1:END: ] || return 1
	case $cfmgr_md_result in read | saved | unchanged | recovered | busy | stale | unavailable | recovery | unresolved) ;; *) return 1 ;; esac
	case $cfmgr_md_generation in
	0) [ "$cfmgr_md_status" != 0 ] || [ "$cfmgr_md_result" = read ] || return 1 ;;
	'' | 0* | *[!0-9]*) return 1 ;;
	*) [ "${#cfmgr_md_generation}" -le 20 ] || return 1 ;;
	esac
	case $cfmgr_md_developer:$cfmgr_md_pending in [01]:[01]) ;; *) return 1 ;; esac
	case $cfmgr_md_saved_hex in
	- | '!') ;;
	*) cfmgr_md_decode_path "$cfmgr_md_saved_hex" || return 1 ;;
	esac
	[ "$cfmgr_md_line" = "CFMGR-DIAGNOSTIC 1 $cfmgr_md_result $cfmgr_md_generation $cfmgr_md_developer $cfmgr_md_pending $cfmgr_md_saved_hex END" ] || return 1
	case $1:$cfmgr_md_result:$cfmgr_md_status:$cfmgr_md_pending in
	read:read:0:0 | read:read:0:1 | save:saved:0:0 | save:unchanged:0:0 | recover:recovered:0:0 | recover:unchanged:0:0) return 0 ;;
	*) [ "$cfmgr_md_status" != 0 ] || return 1 ;;
	esac
	case $cfmgr_md_result in busy | stale | unavailable | recovery | unresolved) return 0 ;; esac
	return 1
}

cfmgr_md_preview() {
	[ "$#" -eq 1 ] || return 1
	case $1 in -) ;; *) cfmgr_md_decode_path "$1" || return 1 ;; esac
	cfmgr_md_preview_capture=$(
		cfmgr_log_destination preview "$1" 2>/dev/null
		cfmgr_md_preview_status=$?
		printf 'CFMGR-PREVIEW-STATUS:%s' "$cfmgr_md_preview_status"
	)
	cfmgr_md_preview_status=${cfmgr_md_preview_capture##*CFMGR-PREVIEW-STATUS:}
	case $cfmgr_md_preview_status in '' | *[!0-9]*) return 1 ;; esac
	cfmgr_md_preview_raw=${cfmgr_md_preview_capture%CFMGR-PREVIEW-STATUS:*}
	[ "$cfmgr_md_preview_capture" = "$cfmgr_md_preview_raw"CFMGR-PREVIEW-STATUS:"$cfmgr_md_preview_status" ] || return 1
	case $cfmgr_md_preview_raw in *"$cfmgr_md_newline") cfmgr_md_preview_line=${cfmgr_md_preview_raw%"$cfmgr_md_newline"} ;; *) return 1 ;; esac
	case $cfmgr_md_preview_line in *"$cfmgr_md_newline"*) return 1 ;; esac
	IFS=' ' read -r cfmgr_md_preview_tag cfmgr_md_preview_schema cfmgr_md_availability \
		cfmgr_md_effective_hex cfmgr_md_preview_end cfmgr_md_preview_extra <<EOF_PREVIEW
$cfmgr_md_preview_line
EOF_PREVIEW
	[ "$cfmgr_md_preview_tag:$cfmgr_md_preview_schema:$cfmgr_md_preview_end:$cfmgr_md_preview_extra" = CFMGR-LOG-DEST:1:END: ] || return 1
	case $cfmgr_md_availability in available | unavailable) ;; *) return 1 ;; esac
	if [ "$cfmgr_md_availability" = available ]; then
		cfmgr_md_decode_path "$cfmgr_md_effective_hex" || return 1
		cfmgr_md_effective_path=$cfmgr_md_path
		if [ "$1" != - ] && [ "$cfmgr_md_effective_hex" != "$1" ]; then return 1; fi
	else
		[ "$cfmgr_md_effective_hex" = - ] || return 1
		cfmgr_md_effective_path=''
	fi
	[ "$cfmgr_md_preview_line" = "CFMGR-LOG-DEST 1 $cfmgr_md_availability $cfmgr_md_effective_hex END" ] || return 1
	case $cfmgr_md_availability:$cfmgr_md_preview_status in available:0 | unavailable:0) return 0 ;; esac
	return 1
}

cfmgr_md_load() {
	if ! cfmgr_md_call read; then
		printf '[CFMGR] settings: error: invalid diagnostic destination response\n' >&2
		return 1
	fi
	if [ "$cfmgr_md_result" != read ]; then
		cfmgr_md_report_failure
		return 1
	fi
	cfmgr_md_saved=$cfmgr_md_saved_hex
	if [ "$cfmgr_md_saved" = '!' ]; then
		cfmgr_md_preview_availability=unavailable cfmgr_md_effective_path=''
	else
		if ! cfmgr_md_preview "$cfmgr_md_saved"; then
			printf '[CFMGR] settings: error: invalid diagnostic destination preview\n' >&2
			return 1
		fi
		cfmgr_md_preview_availability=$cfmgr_md_availability
	fi
}

cfmgr_md_show() {
	case $cfmgr_md_saved in
	-) printf '%s\n' 'Saved diagnostic preference: Auto' ;;
	!) printf '%s\n' 'Saved diagnostic preference: custom path is unsafe or invalid' ;;
	*)
		cfmgr_md_decode_path "$cfmgr_md_saved" || return 1
		printf 'Saved diagnostic preference: Custom %s\n' "$cfmgr_md_path"
		;;
	esac
	if [ "$cfmgr_md_preview_availability" = available ]; then
		printf 'Effective diagnostic destination: %s (available)\n' "$cfmgr_md_effective_path"
	else printf '%s\n' 'Effective diagnostic destination: unavailable; no fallback selected'; fi
	[ "$cfmgr_md_developer" != 1 ] || printf '%s\n' 'Developer mode remains manual-file-only; this preference is separate.'
	[ "$cfmgr_md_pending" != 1 ] || printf '%s\n' 'Diagnostic destination Save/recovery is pending; use explicit recovery.'
	printf '%s\n' '1 Enter custom absolute path' 'a Return preference to Auto' 'e Back'
	[ "$cfmgr_md_pending" != 1 ] || printf '%s\n' 'r Recover previous Save'
}

cfmgr_md_report_failure() {
	case $cfmgr_md_result in
	busy) printf '[CFMGR] settings: warning: diagnostic destination Save busy; no changes were saved\n' >&2 ;;
	stale) printf '[CFMGR] settings: warning: diagnostic destination changed; reopen and review\n' >&2 ;;
	unavailable) printf '[CFMGR] settings: error: native diagnostic settings unavailable\n' >&2 ;;
	recovery) printf '[CFMGR] settings: error: diagnostic destination Save needs explicit recovery\n' >&2 ;;
	unresolved) printf '[CFMGR] settings: error: diagnostic destination operation unresolved\n' >&2 ;;
	*) printf '[CFMGR] settings: error: invalid diagnostic destination response\n' >&2 ;;
	esac
}

cfmgr_md_save() {
	cfmgr_md_want=$1
	if ! cfmgr_md_preview "$cfmgr_md_want"; then
		printf '%s\n' 'Diagnostic destination preview unavailable or invalid; nothing was saved.'
		return 1
	fi
	if [ "$cfmgr_md_want" != - ] && [ "$cfmgr_md_availability" != available ]; then
		printf '%s\n' 'Custom destination is unavailable; choose a different path or keep Auto.'
		return 1
	fi
	if [ "$cfmgr_md_want" = - ]; then
		cfmgr_md_review_preference=Auto
	else
		cfmgr_md_decode_path "$cfmgr_md_want" || return 1
		cfmgr_md_review_preference="Custom $cfmgr_md_path"
	fi
	if [ "$cfmgr_md_availability" = available ]; then
		cfmgr_md_review_effective=$cfmgr_md_effective_path
	else cfmgr_md_review_effective='unavailable'; fi
	printf 'Review diagnostic destination: %s; effective preview=%s.\n' \
		"$cfmgr_md_review_preference" "$cfmgr_md_review_effective"
	printf 'Save this preference? [y/N/e] '
	IFS= read -r cfmgr_md_answer || return 2
	case $cfmgr_md_answer in y | Y | yes | YES) ;; e) return 2 ;; *)
		printf '%s\n' 'Save cancelled; no changes were written.'
		return 1
		;;
	esac
	if ! cfmgr_md_call save "$cfmgr_md_want"; then
		printf '[CFMGR] settings: error: invalid diagnostic destination response\n' >&2
		return 1
	fi
	case $cfmgr_md_result in
	saved) printf '%s\n' 'Diagnostic destination preference saved.' ;;
	unchanged) printf '%s\n' 'Diagnostic destination preference already matches.' ;;
	*)
		cfmgr_md_report_failure
		[ "$cfmgr_md_result" != unresolved ] && [ "$cfmgr_md_result" != recovery ] || return 2
		return 1
		;;
	esac
	cfmgr_md_load
}

cfmgr_md_recover() {
	[ "$cfmgr_md_pending" = 1 ] || return 0
	printf 'Recover previous diagnostic destination Save? [y/N/e] '
	IFS= read -r cfmgr_md_answer || return 2
	case $cfmgr_md_answer in y | Y | yes | YES) ;; e) return 2 ;; *)
		printf '%s\n' 'Recovery cancelled; no recovery was attempted.'
		return 1
		;;
	esac
	if ! cfmgr_md_call recover; then
		printf '[CFMGR] settings: error: invalid diagnostic recovery response\n' >&2
		return 1
	fi
	case $cfmgr_md_result in
	recovered) printf '%s\n' 'Previous diagnostic destination Save recovered; no settings were replayed.' ;;
	unchanged) printf '%s\n' 'No pending diagnostic destination Save to recover.' ;;
	*)
		cfmgr_md_report_failure
		return 1
		;;
	esac
	cfmgr_md_load
}

cfmgr_manager_diagnostic_destination() {
	[ -t 0 ] || {
		printf '[CFMGR] settings: warning: interactive terminal required\n' >&2
		return 1
	}
	cfmgr_md_newline=$(printf '\n.')
	cfmgr_md_newline=${cfmgr_md_newline%.}
	cfmgr_md_load || return 1
	while :; do
		printf '%s\n' 'Advanced options: Diagnostic destination'
		cfmgr_md_show || return 1
		IFS= read -r cfmgr_md_choice || return 0
		case $cfmgr_md_choice in
		1)
			printf 'Custom absolute destination path (e cancels): '
			IFS= read -r cfmgr_md_input || return 0
			[ "$cfmgr_md_input" != e ] || continue
			case $cfmgr_md_input in /*) ;; *)
				printf '%s\n' 'Path must be absolute; nothing was saved.'
				continue
				;;
			esac
			cfmgr_md_want=$(cfmgr_backup_hex "$cfmgr_md_input") || {
				printf '%s\n' 'Path is not bounded printable text; nothing was saved.'
				continue
			}
			cfmgr_md_hex_valid "$cfmgr_md_want" || {
				printf '%s\n' 'Path is not a valid bounded destination; nothing was saved.'
				continue
			}
			if cfmgr_md_save "$cfmgr_md_want"; then :; else
				cfmgr_md_code=$?
				[ "$cfmgr_md_code" != 2 ] || return 0
				case $cfmgr_md_result in unresolved | recovery) return 1 ;; esac
				cfmgr_md_load || return 1
			fi
			;;
		a | A)
			if cfmgr_md_save -; then :; else
				cfmgr_md_code=$?
				[ "$cfmgr_md_code" != 2 ] || return 0
				case $cfmgr_md_result in unresolved | recovery) return 1 ;; esac
				cfmgr_md_load || return 1
			fi
			;;
		r)
			[ "$cfmgr_md_pending" = 1 ] || continue
			if cfmgr_md_recover; then :; else
				cfmgr_md_code=$?
				[ "$cfmgr_md_code" != 2 ] || return 0
				cfmgr_md_load || return 1
			fi
			;;
		e) return 0 ;;
		esac
	done
}

# ---- WAN preference ----
cfmgr_mw_store() {
	cfmgr_mw_operation=$1
	cfmgr_mw_capture=$(
		cfmgr_config_wan_store "$@"
		cfmgr_mw_status=$?
		printf 'CFMGR-STATUS:%s' "$cfmgr_mw_status"
	)
	cfmgr_mw_status=${cfmgr_mw_capture##*CFMGR-STATUS:}
	cfmgr_mw_raw=${cfmgr_mw_capture%CFMGR-STATUS:*}
	[ "$cfmgr_mw_capture" = "$cfmgr_mw_raw"CFMGR-STATUS:"$cfmgr_mw_status" ] || return 1
	case $cfmgr_mw_status in 0 | 1 | 3) ;; *) return 1 ;; esac
	cfmgr_mw_nl=$(printf '\n.')
	cfmgr_mw_nl=${cfmgr_mw_nl%.}
	case $cfmgr_mw_raw in *"$cfmgr_mw_nl") cfmgr_mw_line=${cfmgr_mw_raw%"$cfmgr_mw_nl"} ;; *) return 1 ;; esac
	case $cfmgr_mw_line in *"$cfmgr_mw_nl"*) return 1 ;; esac
	IFS=' ' read -r cfmgr_mw_tag cfmgr_mw_v cfmgr_mw_result cfmgr_mw_gen cfmgr_mw_pending cfmgr_mw_origin cfmgr_mw_state cfmgr_mw_primary cfmgr_mw_selectors cfmgr_mw_end cfmgr_mw_extra <<EOF_WAN
$cfmgr_mw_line
EOF_WAN
	[ "$cfmgr_mw_tag:$cfmgr_mw_v:$cfmgr_mw_end:$cfmgr_mw_extra" = CFMGR-WAN-STORE:1:END: ] || return 1
	case $cfmgr_mw_result in read | saved | unchanged | recovered | busy | stale | unavailable | recovery | unresolved) ;; *) return 1 ;; esac
	case $cfmgr_mw_origin in absent | legacy | inventory | unresolved) ;; *) return 1 ;; esac
	case $cfmgr_mw_state in unconfirmed | retained | confirmed | deferred | unknown) ;; *) return 1 ;; esac
	case $cfmgr_mw_pending in 0 | 1) ;; *) return 1 ;; esac
	case $cfmgr_mw_gen in '' | *[!0-9]*) return 1 ;; esac
	[ "$(printf %s "$cfmgr_mw_gen" | wc -c | tr -d ' ')" -le 20 ] || return 1
	case $cfmgr_mw_primary in
	-) ;;
	wan:*)
		cfmgr_mw_unit=${cfmgr_mw_primary#wan:}
		case $cfmgr_mw_unit in '' | *[!0-9]* | 0[0-9]*) return 1 ;; esac
		[ "$cfmgr_mw_unit" -le 255 ] || return 1
		;;
	manual:*)
		cfmgr_mw_unit=${cfmgr_mw_primary#manual:}
		case $cfmgr_mw_unit in '' | *[!0-9]* | 0[0-9]*) return 1 ;; esac
		[ "$cfmgr_mw_unit" -le 32 ] || return 1
		;;
	*) return 1 ;;
	esac
	case $cfmgr_mw_selectors in -) ;; *[!a-z0-9,:=.-]*) return 1 ;; esac
	[ "$cfmgr_mw_line" = "CFMGR-WAN-STORE 1 $cfmgr_mw_result $cfmgr_mw_gen $cfmgr_mw_pending $cfmgr_mw_origin $cfmgr_mw_state $cfmgr_mw_primary $cfmgr_mw_selectors END" ] || return 1
	case $cfmgr_mw_result:$cfmgr_mw_status:$cfmgr_mw_pending in
	read:0:0 | read:0:1 | saved:0:0 | unchanged:0:0 | recovered:0:0) return 0 ;;
	*)
		[ "$cfmgr_mw_result" = unresolved ] && return 2
		return 1
		;;
	esac
}

cfmgr_mw_observe() {
	cfmgr_mw_capture=$(
		cfmgr_status_wan_inventory "$cfmgr_mw_gen" "$cfmgr_mw_origin" "$cfmgr_mw_state" "$cfmgr_mw_primary" "$cfmgr_mw_selectors"
		cfmgr_mw_status=$?
		printf 'CFMGR-STATUS:%s' "$cfmgr_mw_status"
	)
	cfmgr_mw_status=${cfmgr_mw_capture##*CFMGR-STATUS:}
	cfmgr_mw_report=${cfmgr_mw_capture%CFMGR-STATUS:*}
	case $cfmgr_mw_status in 0 | 1 | 2 | 3) ;; *) return 1 ;; esac
	[ "$cfmgr_mw_status" != 3 ] || return 2
	[ "$cfmgr_mw_capture" = "$cfmgr_mw_report"CFMGR-STATUS:"$cfmgr_mw_status" ] || return 1
	[ "$(printf %s "$cfmgr_mw_report" | wc -c | tr -d ' ')" -le 16384 ] || return 1
	case $cfmgr_mw_report in *'END
') ;; *) return 1 ;; esac
	cfmgr_mw_nl=$(printf '\n.')
	cfmgr_mw_nl=${cfmgr_mw_nl%.}
	cfmgr_mw_candidates='' cfmgr_mw_lines=0 cfmgr_mw_sources=0 cfmgr_mw_interfaces=0 cfmgr_mw_headers=0 cfmgr_mw_primaries=0 cfmgr_mw_ends=0
	cfmgr_mw_rest=$cfmgr_mw_report
	while [ -n "$cfmgr_mw_rest" ]; do
		case $cfmgr_mw_rest in *"$cfmgr_mw_nl"*)
			cfmgr_mw_row=${cfmgr_mw_rest%%"$cfmgr_mw_nl"*}
			cfmgr_mw_rest=${cfmgr_mw_rest#*"$cfmgr_mw_nl"}
			;;
		*) return 1 ;; esac
		cfmgr_mw_lines=$((cfmgr_mw_lines + 1))
		[ "$cfmgr_mw_lines" -le 83 ] || return 1
		[ -n "$cfmgr_mw_row" ] || continue
		IFS=' ' read -r cfmgr_mw_tag cfmgr_mw_a cfmgr_mw_b cfmgr_mw_c cfmgr_mw_d cfmgr_mw_e cfmgr_mw_f cfmgr_mw_g cfmgr_mw_h cfmgr_mw_i cfmgr_mw_j cfmgr_mw_k cfmgr_mw_l cfmgr_mw_extra <<EOF_WAN_ROW
$cfmgr_mw_row
EOF_WAN_ROW
		case $cfmgr_mw_tag in
		CFMGR-WAN)
			[ "$cfmgr_mw_headers" = 0 ] && [ "$cfmgr_mw_a" = 1 ] && [ "$cfmgr_mw_b" = "$cfmgr_mw_gen" ] && [ -n "$cfmgr_mw_c" ] || return 1
			case $cfmgr_mw_c in complete | partial | unknown) ;; *) return 1 ;; esac
			[ -z "$cfmgr_mw_extra" ] || return 1
			cfmgr_mw_headers=1
			;;
		PRIMARY)
			[ "$cfmgr_mw_primaries" = 0 ] || return 1
			case $cfmgr_mw_c in coherent | offline | unresolved | unsupported | conflict) ;; *) return 1 ;; esac
			[ -z "$cfmgr_mw_extra" ] || return 1
			cfmgr_mw_primaries=1
			;;
		SOURCE)
			cfmgr_mw_sources=$((cfmgr_mw_sources + 1))
			[ "$cfmgr_mw_sources" -le 16 ] || return 1
			case $cfmgr_mw_a in wan:[0-9]* | manual:[0-9]*) ;; *) return 1 ;; esac
			case $cfmgr_mw_b in - | *[!0-9]* | '') [ "$cfmgr_mw_b" = - ] || return 1 ;; esac
			case $cfmgr_mw_c in -) ;; *[!0-9a-f]* | '') return 1 ;; *) ;; esac
			case $cfmgr_mw_d in dhcp | static | pppoe | pptp | l2tp | -) ;; *) return 1 ;; esac
			case $cfmgr_mw_e:$cfmgr_mw_f in yes:yes | yes:no | yes:unknown | no:yes | no:no | no:unknown | unknown:yes | unknown:no | unknown:unknown) ;; *) return 1 ;; esac
			case $cfmgr_mw_g in coherent | offline | unresolved | unsupported | conflict) ;; *) return 1 ;; esac
			case $cfmgr_mw_h in yes | no | unknown) ;; *) return 1 ;; esac
			case $cfmgr_mw_k in public | private | shared | linklocal | nonpublic | unknown) ;; *) return 1 ;; esac
			[ -z "$cfmgr_mw_extra" ] || return 1
			case $cfmgr_mw_a:$cfmgr_mw_e:$cfmgr_mw_f:$cfmgr_mw_g in
			wan:*:*:*:coherent | wan:*:yes:*:offline | wan:*:yes:*:unresolved)
				[ "$cfmgr_mw_e" = yes ] || [ "$cfmgr_mw_f" = yes ] || continue
				[ "$cfmgr_mw_c" != - ] || continue
				case $cfmgr_mw_report in *"INTERFACE $cfmgr_mw_c "*) cfmgr_mw_candidates=${cfmgr_mw_candidates}${cfmgr_mw_candidates:+,}$cfmgr_mw_a ;; esac
				;;
			esac
			;;
		INTERFACE)
			cfmgr_mw_interfaces=$((cfmgr_mw_interfaces + 1))
			[ "$cfmgr_mw_interfaces" -le 64 ] || return 1
			case $cfmgr_mw_a in '' | *[!0-9a-f]*) return 1 ;; esac
			case $cfmgr_mw_b in up | down | unknown) ;; *) return 1 ;; esac
			case $cfmgr_mw_e in public | private | shared | linklocal | nonpublic | unknown) ;; *) return 1 ;; esac
			case $cfmgr_mw_f in yes | no | unknown) ;; *) return 1 ;; esac
			[ -z "$cfmgr_mw_g" ] || return 1
			;;
		END)
			[ "$cfmgr_mw_ends" = 0 ] && [ -z "$cfmgr_mw_a" ] || return 1
			cfmgr_mw_ends=1
			;;
		*) return 1 ;;
		esac
	done
	[ "$cfmgr_mw_headers:$cfmgr_mw_primaries:$cfmgr_mw_ends" = 1:1:1 ] && [ "$cfmgr_mw_lines" -ge 3 ]
}

cfmgr_mw_display() {
	cfmgr_mw_display_rest=$cfmgr_mw_report
	while [ -n "$cfmgr_mw_display_rest" ]; do
		case $cfmgr_mw_display_rest in *"$cfmgr_mw_nl"*)
			cfmgr_mw_display_row=${cfmgr_mw_display_rest%%"$cfmgr_mw_nl"*}
			cfmgr_mw_display_rest=${cfmgr_mw_display_rest#*"$cfmgr_mw_nl"}
			;;
		*) return 1 ;; esac
		case $cfmgr_mw_display_row in
		SOURCE\ *)
			IFS=' ' read -r cfmgr_mw_tag cfmgr_mw_id cfmgr_mw_unit cfmgr_mw_ifhex cfmgr_mw_proto cfmgr_mw_configured cfmgr_mw_connected cfmgr_mw_mapping cfmgr_mw_route cfmgr_mw_ipv4 cfmgr_mw_mask cfmgr_mw_class cfmgr_mw_lan <<EOF_WAN_SOURCE
$cfmgr_mw_display_row
EOF_WAN_SOURCE
			if [ "$cfmgr_mw_ifhex" = - ]; then
				cfmgr_mw_ifname=Unknown
			elif cfmgr_backup_unhex "$cfmgr_mw_ifhex" text; then
				cfmgr_mw_ifname=$cfmgr_backup_decoded
			else return 1; fi
			printf '  %s: interface=%s; protocol=%s; local IPv4=%s (%s); configured=%s; connected=%s; mapping=%s\n' "$cfmgr_mw_id" "$cfmgr_mw_ifname" "$cfmgr_mw_proto" "$cfmgr_mw_ipv4" "$cfmgr_mw_class" "$cfmgr_mw_configured" "$cfmgr_mw_connected" "$cfmgr_mw_mapping"
			;;
		INTERFACE\ *)
			IFS=' ' read -r cfmgr_mw_tag cfmgr_mw_ifhex cfmgr_mw_up cfmgr_mw_ipv4 cfmgr_mw_mask cfmgr_mw_class cfmgr_mw_lan <<EOF_WAN_INTERFACE
$cfmgr_mw_display_row
EOF_WAN_INTERFACE
			if cfmgr_backup_unhex "$cfmgr_mw_ifhex" text; then
				cfmgr_mw_ifname=$cfmgr_backup_decoded
			else return 1; fi
			printf '  local interface=%s; state=%s; IPv4=%s (%s)\n' "$cfmgr_mw_ifname" "$cfmgr_mw_up" "$cfmgr_mw_ipv4" "$cfmgr_mw_class"
			;;
		esac
	done
}

cfmgr_mw_load() {
	if cfmgr_mw_store read; then return 0; fi
	case $cfmgr_mw_result in
	recovery)
		cfmgr_mw_pending=1
		return 0
		;;
	unresolved)
		printf '%s\n' 'WAN preference ownership is unresolved; leaving without another operation.'
		return 3
		;;
	*)
		printf '%s\n' 'WAN preference settings could not be read; no operation was attempted.'
		return 1
		;;
	esac
}

cfmgr_mw_merge_candidates() {
	cfmgr_mw_want_selectors=$cfmgr_mw_selectors
	[ "$cfmgr_mw_want_selectors" != - ] || cfmgr_mw_want_selectors=''
	cfmgr_mw_merge_rest=$cfmgr_mw_candidates
	while [ -n "$cfmgr_mw_merge_rest" ]; do
		case $cfmgr_mw_merge_rest in *,*)
			cfmgr_mw_merge_id=${cfmgr_mw_merge_rest%%,*}
			cfmgr_mw_merge_rest=${cfmgr_mw_merge_rest#*,}
			;;
		*)
			cfmgr_mw_merge_id=$cfmgr_mw_merge_rest
			cfmgr_mw_merge_rest=''
			;;
		esac
		case ,$cfmgr_mw_want_selectors, in *,$cfmgr_mw_merge_id,*) ;; *)
			cfmgr_mw_want_selectors=${cfmgr_mw_want_selectors}${cfmgr_mw_want_selectors:+,}$cfmgr_mw_merge_id
			;;
		esac
	done
}

cfmgr_mw_review_sources() {
	cfmgr_mw_review_rest=$cfmgr_mw_want_selectors
	[ "$cfmgr_mw_review_rest" != - ] || {
		printf '%s\n' '  none'
		return 0
	}
	while [ -n "$cfmgr_mw_review_rest" ]; do
		case $cfmgr_mw_review_rest in *,*)
			cfmgr_mw_review_token=${cfmgr_mw_review_rest%%,*}
			cfmgr_mw_review_rest=${cfmgr_mw_review_rest#*,}
			;;
		*)
			cfmgr_mw_review_token=$cfmgr_mw_review_rest
			cfmgr_mw_review_rest=''
			;;
		esac
		cfmgr_mw_review_id=${cfmgr_mw_review_token%%=*}
		case $cfmgr_mw_review_token in *=*) cfmgr_mw_review_hex=${cfmgr_mw_review_token#*=} ;;
		*)
			printf '  %s (firmware WAN source)\n' "$cfmgr_mw_review_id"
			continue
			;;
		esac
		if cfmgr_backup_unhex "$cfmgr_mw_review_hex" text; then
			printf '  %s interface %s\n' "$cfmgr_mw_review_id" "$cfmgr_backup_decoded"
		else return 1; fi
	done
}

cfmgr_mw_save() {
	cfmgr_mw_want_state=$1 cfmgr_mw_want_primary=$2 cfmgr_mw_want_selectors=$3
	printf 'Review WAN Save: state=%s; DDNS primary=%s. Internet access is unverified.\nSelected WAN sources:\n' "$cfmgr_mw_want_state" "$cfmgr_mw_want_primary"
	cfmgr_mw_review_sources || return 1
	[ -z "$cfmgr_mw_report" ] || cfmgr_mw_display || return 1
	printf 'Save this WAN preference? [y/N/e] '
	IFS= read -r cfmgr_mw_answer || return 2
	case $cfmgr_mw_answer in y | Y | yes | YES) ;; e) return 2 ;; *)
		printf '%s\n' 'Save cancelled; no changes were written.'
		return 1
		;;
	esac
	if ! cfmgr_mw_store save "$cfmgr_mw_gen" "$cfmgr_mw_want_state" "$cfmgr_mw_want_primary" "$cfmgr_mw_want_selectors"; then
		if [ "$cfmgr_mw_result" = stale ]; then
			printf '%s\n' 'WAN preference changed during review; reloading current saved intent for a new review.'
			cfmgr_mw_load || return $?
			return 1
		fi
		case $cfmgr_mw_result in
		unresolved)
			printf '%s\n' 'WAN Save ownership is unresolved; leaving without another operation.'
			return 3
			;;
		recovery)
			cfmgr_mw_pending=1
			printf '%s\n' 'WAN Save requires recovery; its publication state is uncertain.'
			;;
		*) printf '%s\n' 'WAN preference Save did not complete; check the saved preference before retrying.' ;;
		esac
		return 1
	fi
	case $cfmgr_mw_result in saved) printf '%s\n' 'WAN preference saved.' ;; unchanged) printf '%s\n' 'WAN preference already matches.' ;; *) return 1 ;; esac
	cfmgr_mw_load
}

cfmgr_mw_defer() {
	if [ "$cfmgr_mw_origin" = unresolved ]; then
		printf '%s\n' 'The unresolved retained WAN choice is preserved; confirm a replacement to change it.'
		return 0
	fi
	cfmgr_mw_want_primary=$cfmgr_mw_primary cfmgr_mw_want_selectors=$cfmgr_mw_selectors
	cfmgr_mw_save deferred "$cfmgr_mw_want_primary" "$cfmgr_mw_want_selectors"
}

cfmgr_manager_wan_settings() {
	[ -t 0 ] || return 1
	cfmgr_mw_load || return $?
	while :; do
		if [ "$cfmgr_mw_pending" = 1 ]; then
			while :; do
				printf '%s\n' 'WAN preference Save/recovery is pending; no new changes are allowed.' 'r Recover previous Save' 'e Back'
				IFS= read -r cfmgr_mw_choice || return 0
				case $cfmgr_mw_choice in
				r)
					printf 'Recover previous WAN Save? [y/N/e] '
					IFS= read -r cfmgr_mw_answer || return 0
					case $cfmgr_mw_answer in y | Y | yes | YES) ;; e) return 0 ;; *) continue ;; esac
					if cfmgr_mw_store recover; then
						printf '%s\n' 'Previous WAN Save recovered; no settings were replayed.'
						cfmgr_mw_load || return $?
					else
						[ "$cfmgr_mw_result" != unresolved ] || return 3
						printf '%s\n' 'WAN Save recovery did not complete; no second operation was attempted.'
						return 1
					fi
					[ "$cfmgr_mw_pending" = 0 ] && return 0
					;;
				e) return 0 ;;
				esac
			done
		fi
		printf 'WAN preference: state=%s; primary=%s\nSaved sources:\n' "$cfmgr_mw_state" "$cfmgr_mw_primary"
		cfmgr_mw_want_selectors=$cfmgr_mw_selectors
		cfmgr_mw_review_sources || return 1
		printf '%s\n' 'Current observation is separate from saved intent; Internet access is unverified.' 'Mappings are rechecked when WAN review, Status or Health is invoked after changes.' '1 Review detected WANs' '2 Add/correct observed interface' '3 Remove a saved source' '4 Defer confirmation' 'e Back'
		IFS= read -r cfmgr_mw_choice || return 0
		case $cfmgr_mw_choice in
		1 | 2)
			if cfmgr_mw_observe; then :; else
				cfmgr_mw_code=$?
				[ "$cfmgr_mw_code" != 2 ] || return 3
				continue
			fi
			cfmgr_mw_display || continue
			if [ "$cfmgr_mw_choice" = 2 ] || { [ -z "$cfmgr_mw_candidates" ] && [ "$cfmgr_mw_selectors" = - ]; }; then
				printf 'Observed interface name: '
				IFS= read -r cfmgr_mw_name || continue
				case $cfmgr_mw_name in '' | *[![:print:]]* | *[[:space:]]* | */* | *:*)
					printf '%s\n' 'Invalid literal interface; no changes saved.'
					continue
					;;
				. | ..)
					printf '%s\n' 'Invalid literal interface; no changes saved.'
					continue
					;;
				esac
				[ "${#cfmgr_mw_name}" -le 15 ] || {
					printf '%s\n' 'Invalid literal interface; no changes saved.'
					continue
				}
				cfmgr_mw_hex=$(cfmgr_backup_hex "$cfmgr_mw_name") || continue
				case $cfmgr_mw_report in *"INTERFACE $cfmgr_mw_hex "*) ;;
				*)
					printf 'Interface was not observed. Save an explicit deferral? [y/N/e] '
					IFS= read -r cfmgr_mw_answer || continue
					case $cfmgr_mw_answer in y | Y | yes | YES) cfmgr_mw_defer || {
						cfmgr_mw_code=$?
						[ "$cfmgr_mw_code" != 3 ] || return 3
					} ;; esac
					continue
					;;
				esac
				cfmgr_mw_merge_candidates
				cfmgr_mw_manual_index=1 cfmgr_mw_manual_id=''
				while [ "$cfmgr_mw_manual_index" -le 32 ]; do
					cfmgr_mw_manual_id=manual:$cfmgr_mw_manual_index
					case ,$cfmgr_mw_want_selectors, in *,"$cfmgr_mw_manual_id=$cfmgr_mw_hex",*) break ;; esac
					cfmgr_mw_manual_index=$((cfmgr_mw_manual_index + 1))
				done
				if [ "$cfmgr_mw_manual_index" -gt 32 ]; then
					cfmgr_mw_manual_index=1
					while [ "$cfmgr_mw_manual_index" -le 32 ]; do
						cfmgr_mw_manual_id=manual:$cfmgr_mw_manual_index
						case ,$cfmgr_mw_want_selectors, in *,"$cfmgr_mw_manual_id="*) cfmgr_mw_manual_index=$((cfmgr_mw_manual_index + 1)) ;; *)
							cfmgr_mw_want_selectors=${cfmgr_mw_want_selectors}${cfmgr_mw_want_selectors:+,}$cfmgr_mw_manual_id=$cfmgr_mw_hex
							break
							;;
						esac
					done
				fi
				[ "$cfmgr_mw_manual_index" -le 32 ] || {
					printf '%s\n' 'No manual WAN source IDs are available.'
					continue
				}
				if [ "$cfmgr_mw_primary" = - ]; then
					cfmgr_mw_want_primary=$cfmgr_mw_manual_id
				else
					printf 'Make %s the DDNS primary instead of %s? [y/N/e] ' "$cfmgr_mw_manual_id" "$cfmgr_mw_primary"
					IFS= read -r cfmgr_mw_answer || continue
					case $cfmgr_mw_answer in y | Y | yes | YES) cfmgr_mw_want_primary=$cfmgr_mw_manual_id ;; n | N | no | NO) cfmgr_mw_want_primary=$cfmgr_mw_primary ;; *) continue ;; esac
				fi
			else
				cfmgr_mw_merge_candidates
				printf '%s\n' 'Saved and detected sources:'
				cfmgr_mw_review_sources || continue
				printf 'DDNS primary: '
				IFS= read -r cfmgr_mw_want_primary || continue
				case ,$cfmgr_mw_want_selectors, in *,$cfmgr_mw_want_primary,* | *,"$cfmgr_mw_want_primary="*) ;; *) continue ;; esac
			fi
			cfmgr_mw_save confirmed "$cfmgr_mw_want_primary" "$cfmgr_mw_want_selectors" || {
				cfmgr_mw_code=$?
				[ "$cfmgr_mw_code" != 3 ] || return 3
			}
			;;
		3)
			[ "$cfmgr_mw_selectors" != - ] || {
				printf '%s\n' 'No saved sources to remove.'
				continue
			}
			cfmgr_mw_want_selectors=$cfmgr_mw_selectors
			printf '%s\n' 'Saved sources to remove:'
			cfmgr_mw_review_sources || continue
			printf 'Source ID to remove: '
			IFS= read -r cfmgr_mw_remove_id || continue
			cfmgr_mw_remove_rest=$cfmgr_mw_selectors cfmgr_mw_want_selectors='' cfmgr_mw_remove_found=0
			while [ -n "$cfmgr_mw_remove_rest" ]; do
				case $cfmgr_mw_remove_rest in *,*)
					cfmgr_mw_remove_token=${cfmgr_mw_remove_rest%%,*}
					cfmgr_mw_remove_rest=${cfmgr_mw_remove_rest#*,}
					;;
				*)
					cfmgr_mw_remove_token=$cfmgr_mw_remove_rest
					cfmgr_mw_remove_rest=''
					;;
				esac
				cfmgr_mw_remove_token_id=${cfmgr_mw_remove_token%%=*}
				if [ "$cfmgr_mw_remove_token_id" = "$cfmgr_mw_remove_id" ]; then
					cfmgr_mw_remove_found=1
				else cfmgr_mw_want_selectors=${cfmgr_mw_want_selectors}${cfmgr_mw_want_selectors:+,}$cfmgr_mw_remove_token; fi
			done
			[ "$cfmgr_mw_remove_found" = 1 ] || {
				printf '%s\n' 'Source ID was not in the saved preference.'
				continue
			}
			if [ -z "$cfmgr_mw_want_selectors" ]; then
				cfmgr_mw_save deferred - - || {
					cfmgr_mw_code=$?
					[ "$cfmgr_mw_code" != 3 ] || return 3
				}
				continue
			fi
			cfmgr_mw_want_primary=$cfmgr_mw_primary
			if [ "$cfmgr_mw_remove_id" = "$cfmgr_mw_primary" ]; then
				printf '%s\n' 'Remaining sources:'
				cfmgr_mw_review_sources || continue
				printf 'Choose a new DDNS primary: '
				IFS= read -r cfmgr_mw_want_primary || continue
				case ,$cfmgr_mw_want_selectors, in *,$cfmgr_mw_want_primary,* | *,"$cfmgr_mw_want_primary="*) ;; *)
					printf '%s\n' 'New primary must remain selected.'
					continue
					;;
				esac
			fi
			printf 'Remove %s and save the reviewed source set? [y/N/e] ' "$cfmgr_mw_remove_id"
			IFS= read -r cfmgr_mw_answer || continue
			case $cfmgr_mw_answer in y | Y | yes | YES) cfmgr_mw_save confirmed "$cfmgr_mw_want_primary" "$cfmgr_mw_want_selectors" || {
				cfmgr_mw_code=$?
				[ "$cfmgr_mw_code" != 3 ] || return 3
			} ;; esac
			;;
		4) cfmgr_mw_defer || {
			cfmgr_mw_code=$?
			[ "$cfmgr_mw_code" != 3 ] || return 3
		} ;;
		e) return 0 ;;
		esac
	done
}

cfmgr_manager_wan_first_use() {
	cfmgr_mw_load || return $?
	[ "$cfmgr_mw_pending" != 1 ] || return 0
	case $cfmgr_mw_state in retained | confirmed | deferred | unknown) return 0 ;; esac
	if cfmgr_mw_observe; then :; else
		cfmgr_mw_code=$?
		[ "$cfmgr_mw_code" != 2 ] || return 3
		return 1
	fi
	printf '%s\n' 'First-use WAN confirmation' 'Local evidence does not verify Internet access.'
	cfmgr_mw_display || return 1
	if [ -n "$cfmgr_mw_candidates" ]; then
		printf 'Are these your WAN connections? [Y/n/cancel] '
		IFS= read -r cfmgr_mw_answer || return 0
		case $cfmgr_mw_answer in
		'' | y | Y | yes | YES)
			printf 'Choose DDNS primary from %s: ' "$cfmgr_mw_candidates"
			IFS= read -r cfmgr_mw_want_primary || return 0
			case ,$cfmgr_mw_candidates, in *,$cfmgr_mw_want_primary,*) cfmgr_mw_save confirmed "$cfmgr_mw_want_primary" "$cfmgr_mw_candidates" || {
				cfmgr_mw_code=$?
				[ "$cfmgr_mw_code" != 3 ] || return 3
			} ;; *) printf '%s\n' 'Invalid primary; no changes saved.' ;; esac
			;;
		n | N | no | NO) cfmgr_manager_wan_settings || {
			cfmgr_mw_code=$?
			[ "$cfmgr_mw_code" != 3 ] || return 3
		} ;;
		*) return 0 ;;
		esac
	else
		printf '%s\n' 'No credible WAN candidate; use Advanced options to correct or defer.'
		cfmgr_manager_wan_settings || {
			cfmgr_mw_code=$?
			[ "$cfmgr_mw_code" != 3 ] || return 3
		}
	fi
}

# ---- Main menu ----
cfmgr_launch_menu() {
	[ -t 0 ] || return 1
	cfmgr_manager_wan_first_use || {
		cfmgr_mw_code=$?
		[ "$cfmgr_mw_code" != 3 ] || return 1
	}
	while :; do
		printf '%s\n' 'CFMgr main menu' '0 Check status' '4 Backup / Restore' 'ao Advanced options' 'e Exit'
		IFS= read -r cfmgr_launch_choice || return 1
		case $cfmgr_launch_choice in
		e) return 1 ;;
		0) cfmgr_status_native || : ;;
		4) cfmgr_backup_menu || : ;;
		ao)
			while :; do
				printf '%s\n' 'Advanced options: other actions unavailable' '1 Reinstall Entware dependencies' '2 CFMgr updates' '3 Diagnostic destination' '4 WAN/address preferences' 'e Back'
				IFS= read -r cfmgr_launch_choice || return 1
				case $cfmgr_launch_choice in
				1) return 0 ;;
				2) cfmgr_manager_settings || : ;;
				3) cfmgr_manager_diagnostic_destination || : ;;
				4) cfmgr_manager_wan_settings || {
					cfmgr_mw_code=$?
					[ "$cfmgr_mw_code" != 3 ] || return 1
				} ;;
				e) break ;;
				esac
			done
			;;
		esac
	done
}
