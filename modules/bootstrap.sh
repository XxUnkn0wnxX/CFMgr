#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Installed Entware opkg manages dependency packages and their libraries.
# Sourcing only defines functions. This synchronous internal backend requires
# a future serialized, non-hook dependency worker to approve writable mounted
# Entware and ownership first. Path/executable presence is not a mount proof.
# No operational installer CLI, cleanup or producer-completion claim exists.
# CFMgr manages Cloudflared releases separately; opkg never installs it here.
# Per-entry subshell state is inherited by its fixed nested capability helpers.
# shellcheck disable=SC2030,SC2031

cfmgr_bootstrap_dependencies() {
	[ "$#" -eq 2 ] || return 2
	_cfmgr_bootstrap_dependencies_run /opt "$1" "$2"
}

# Explicit trusted host fixture only; production never reads an ambient root.
cfmgr_bootstrap_dependencies_test() {
	[ "$#" -eq 3 ] || return 2
	_cfmgr_bootstrap_dependencies_run "$@"
}

# Explicit synchronous reinstall of every selected direct capability package.
cfmgr_bootstrap_reinstall() {
	[ "$#" -eq 2 ] || return 2
	_cfmgr_bootstrap_reinstall_run /opt "$1" "$2"
}

# Explicit trusted host fixture only; production never reads an ambient root.
cfmgr_bootstrap_reinstall_test() {
	[ "$#" -eq 3 ] || return 2
	_cfmgr_bootstrap_reinstall_run "$@"
}

_cfmgr_bootstrap_dependencies_run() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	umask 077
	[ "$#" -eq 3 ] || return 2
	_cfmgr_bootstrap_prepare "$@" || return "$?"
	if _cfmgr_bootstrap_dependencies_check; then return 0; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -eq 1 ] || return 129
	fi
	if "$_bootstrap_opkg" update; then :; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -le 128 ] && return 1
		return 129
	fi
	# Missing packages come only from the compiled capability map below. Fixed
	# IFS/noglob make this deliberate splitting independent of caller state.
	# shellcheck disable=SC2086
	set -- $_bootstrap_missing
	if "$_bootstrap_opkg" install "$@"; then :; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -le 128 ] && return 1
		return 129
	fi
	if _cfmgr_bootstrap_dependencies_check; then return 0; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -eq 1 ] && return 1
		return 129
	fi
) >/dev/null 2>&1

_cfmgr_bootstrap_reinstall_run() (
	trap - 0 HUP INT TERM
	set +x
	set +e
	set +u
	set -f
	umask 077
	[ "$#" -eq 3 ] || return 2
	_cfmgr_bootstrap_prepare "$@" || return "$?"
	if "$_bootstrap_opkg" update; then :; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -le 128 ] && return 1
		return 129
	fi
	# The selected direct packages come from the same fixed capability map used
	# by normal repair. This is an explicit reinstall, so no pre-probe can skip it.
	# shellcheck disable=SC2086
	set -- $_bootstrap_packages
	if "$_bootstrap_opkg" --force-reinstall install "$@"; then :; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -le 128 ] && return 1
		return 129
	fi
	if _cfmgr_bootstrap_dependencies_check; then return 0; else
		_bootstrap_status=$?
		[ "$_bootstrap_status" -eq 1 ] && return 1
		return 129
	fi
) >/dev/null 2>&1

_cfmgr_bootstrap_prepare() {
	[ "$#" -eq 3 ] || return 2
	LC_ALL=C
	export LC_ALL
	_bootstrap_root=$1
	_bootstrap_scope=$2
	_bootstrap_lock=$3
	case $_bootstrap_scope in shared | tunnel) ;; *) return 2 ;; esac
	case $_bootstrap_lock in native | entware) ;; *) return 2 ;; esac
	[ "${#_bootstrap_root}" -le 4096 ] || return 2
	case $_bootstrap_root in /*) ;; *) return 2 ;; esac
	case $_bootstrap_root in / | */ | *//* | */./* | */../* | */. | */.. | *[[:cntrl:]]*) return 2 ;; esac
	IFS=' 	'
	IFS="${IFS}
"
	PATH=/sbin:/bin:/usr/sbin:/usr/bin:$_bootstrap_root/bin:$_bootstrap_root/sbin
	export PATH
	unset ENV BASH_ENV CDPATH TZ
	unset LD_PRELOAD LD_LIBRARY_PATH LD_AUDIT LD_DEBUG LD_DEBUG_OUTPUT LD_PROFILE
	unset LD_PROFILE_OUTPUT LD_TRACE_LOADED_OBJECTS LD_BIND_NOW LD_BIND_NOT
	unset LD_ASSUME_KERNEL LD_ORIGIN_PATH LD_HWCAP_MASK LD_SHOW_AUXV LD_VERBOSE LD_WARN
	unset LD_DYNAMIC_WEAK LD_USE_LOAD_BIAS GLIBC_TUNABLES
	unset OPENSSL_CONF OPENSSL_CONF_INCLUDE OPENSSL_ENGINES OPENSSL_MODULES
	unset OPKG_CONF_DIR OPKG_OFFLINE_ROOT OPKG_ROOT OPKG_INSTROOT OPKG_TMP_DIR
	unset IPKG_CONF_DIR IPKG_OFFLINE_ROOT IPKG_INSTROOT IPKG_TMP_DIR DESTDIR
	unset http_proxy https_proxy ftp_proxy all_proxy no_proxy
	unset HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
	unset CURL_HOME CURL_CA_BUNDLE SSL_CERT_FILE SSL_CERT_DIR WGETRC
	_bootstrap_opkg=$_bootstrap_root/bin/opkg
	[ -d "$_bootstrap_root" ] && [ -x "$_bootstrap_opkg" ] && [ ! -d "$_bootstrap_opkg" ] || return 1
	_bootstrap_capabilities='jq timeout sha256sum'
	[ "$_bootstrap_scope" != tunnel ] || _bootstrap_capabilities="$_bootstrap_capabilities dig"
	[ "$_bootstrap_lock" != entware ] || _bootstrap_capabilities="$_bootstrap_capabilities flock"
	_cfmgr_bootstrap_selected_packages
}

_cfmgr_bootstrap_selected_packages() {
	_bootstrap_packages=
	for _bootstrap_capability in $_bootstrap_capabilities; do
		_cfmgr_bootstrap_package "$_bootstrap_capability" || return "$?"
		_bootstrap_packages="$_bootstrap_packages $_bootstrap_package"
	done
}

_cfmgr_bootstrap_package() {
	case $1 in
	jq) _bootstrap_package=jq ;;
	timeout) _bootstrap_package=coreutils-timeout ;;
	sha256sum) _bootstrap_package=coreutils-sha256sum ;;
	dig) _bootstrap_package=bind-dig ;;
	flock) _bootstrap_package=flock ;;
	*) return 2 ;;
	esac
}

_cfmgr_bootstrap_dependencies_check() {
	_bootstrap_missing=
	for _bootstrap_capability in $_bootstrap_capabilities; do
		if _cfmgr_bootstrap_dependencies_probe "$_bootstrap_capability"; then continue; else
			_bootstrap_status=$?
			[ "$_bootstrap_status" -eq 1 ] || return 129
		fi
		_cfmgr_bootstrap_package "$_bootstrap_capability" || return "$?"
		_bootstrap_missing="$_bootstrap_missing $_bootstrap_package"
	done
	[ -z "$_bootstrap_missing" ]
}

_cfmgr_bootstrap_dependencies_probe() {
	_bootstrap_executable=$_bootstrap_root/bin/$1
	[ -x "$_bootstrap_executable" ] && [ ! -d "$_bootstrap_executable" ] || return 1
	case $1 in
	jq)
		if _bootstrap_output=$(
			"$_bootstrap_executable" -M -r '.cfmgr' <<'EOF_JSON'
{"cfmgr":"ready"}
EOF_JSON
		); then
			[ "$_bootstrap_output" = ready ] && return 0
			return 1
		else _bootstrap_status=$?; fi
		;;
	sha256sum)
		if _bootstrap_output=$(command printf abc | "$_bootstrap_executable"); then
			[ "$_bootstrap_output" = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad  -' ] && return 0
			return 1
		else _bootstrap_status=$?; fi
		;;
	timeout)
		if "$_bootstrap_executable" 1 /bin/sh -c 'exit 0'; then return 0; else _bootstrap_status=$?; fi
		;;
	dig)
		# Availability/invocation only; no DNS behavior or network observation.
		if "$_bootstrap_executable" -v; then return 0; else _bootstrap_status=$?; fi
		;;
	flock)
		# Availability/invocation only; the future caller owns actual lock proof.
		if "$_bootstrap_executable" --version; then return 0; else _bootstrap_status=$?; fi
		;;
	*) return 1 ;;
	esac
	[ "$_bootstrap_status" -le 128 ] && return 1
	return 129
}
