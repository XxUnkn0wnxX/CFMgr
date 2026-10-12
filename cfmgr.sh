#!/bin/sh
# Trusted entry defaults. Fork maintainers change this one source-selection block.
CFMGR_REPOSITORY=https://github.com/XxUnkn0wnxX/CFMgr
CFMGR_BRANCH=develop
CFMGR_VERSION=0.1.0

case ${1-} in
--version)
	[ "$#" -eq 1 ] || exit 2
	printf 'CFMgr %s (development placeholder)\n' "$CFMGR_VERSION"
	exit 0
	;;
--help | '')
	[ "$#" -le 1 ] || exit 2
	printf '%s\n' 'CFMgr: --install (trusted complete local package), --version, --help.' \
		'Fresh base installation only. Dependency repair, acquisition and feature menus remain unavailable.'
	if [ -e /jffs/addons/CFMgr.d ] || [ -L /jffs/addons/CFMgr.d ]; then
		printf '%s\n' 'An installed or retained package exists; fresh installation will not reset it. Recovery/update is not implemented.'
	fi
	exit 0
	;;
--install)
	[ "$#" -eq 1 ] || exit 2
	if [ -e /jffs/addons/CFMgr.d ] || [ -L /jffs/addons/CFMgr.d ] || [ -e /jffs/scripts/cfmgr.sh ] || [ -L /jffs/scripts/cfmgr.sh ]; then
		printf '%s\n' 'Existing or retained CFMgr installation: recovery/update required; fresh defaults were not generated.' >&2
		exit 1
	fi
	cfmgr_entry=$(/usr/bin/readlink -f "$0") || exit 1
	case $cfmgr_entry in /*/cfmgr.sh) ;; *) exit 1 ;; esac
	exec /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin LC_ALL=C LANGUAGE= \
		CFMGR_INTERNAL_INSTALL=1 /bin/sh "$cfmgr_entry" --internal-install
	;;
--internal-install)
	[ "$#" -eq 1 ] && [ "${CFMGR_INTERNAL_INSTALL-}" = 1 ] || exit 2
	cfmgr_entry=$(/usr/bin/readlink -f "$0") || exit 1
	case $cfmgr_entry in /*/cfmgr.sh) ;; *) exit 1 ;; esac
	cfmgr_source=${cfmgr_entry%/*}
	# Only explicit trusted-package imports. Configuration is never sourced.
	# shellcheck disable=SC1091
	. "$cfmgr_source/modules/lib/storage.sh" || exit 1
	. "$cfmgr_source/modules/lib/prerequisites.sh" || exit 1
	. "$cfmgr_source/modules/helpers/bootstrap.sh" || exit 1
	if cfmgr_bootstrap_native "$cfmgr_source"; then
		printf '%s\n' 'CFMgr fresh installation complete.'
		exit 0
	fi
	printf '%s\n' 'CFMgr installation blocked or incomplete; existing data was not reset. Recovery may be required.' >&2
	exit 1
	;;
*)
	printf '%s\n' 'Unsupported command; use --help.' >&2
	exit 2
	;;
esac
