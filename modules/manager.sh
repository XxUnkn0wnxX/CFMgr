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
				printf '%s\n' 'Advanced options: other actions unavailable' '1 Reinstall Entware dependencies' '2 CFMgr updates' '3 Diagnostic destination' 'e Back'
				IFS= read -r cfmgr_launch_choice || return 1
				case $cfmgr_launch_choice in
				1) return 0 ;;
				2) cfmgr_manager_settings || : ;;
				3) cfmgr_manager_diagnostic_destination || : ;;
				e) break ;;
				esac
			done
			;;
		esac
	done
}
