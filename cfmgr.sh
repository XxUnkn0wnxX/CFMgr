#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Development entry only: no installation, startup, repair or feature dispatch.
CFMGR_VERSION=0.1.0
PATH=/sbin:/bin:/usr/sbin:/usr/bin
export PATH
unset ENV BASH_ENV CDPATH LD_LIBRARY_PATH LD_PRELOAD

case ${1-} in
--help)
	[ "$#" -eq 1 ] || exit 2
	printf '%s\n' 'CFMgr development entry (diagnostics only; not a release)' \
		'Usage: cfmgr --help | --version | --diagnostic | --doctor' \
		'Diagnostics are read-only except their private RAM scratch directory.'
	exit 0
	;;
--version)
	[ "$#" -eq 1 ] || exit 2
	printf '%s\n' "CFMgr $CFMGR_VERSION (development; diagnostics only)"
	exit 0
	;;
--diagnostic | --doctor)
	[ "$#" -eq 1 ] || exit 2
	;;
*)
	printf '%s\n' 'CFMgr: command not implemented; use --help.' >&2
	exit 2
	;;
esac

# Follow only this invocation's path, with a bounded number of symlink hops.
# No environment-selected module or configuration is sourced.
_cfmgr_entry=$0
case $_cfmgr_entry in
/*) ;;
*)
	_cfmgr_cwd=$(pwd -P) || exit 1
	_cfmgr_entry=$_cfmgr_cwd/$_cfmgr_entry
	;;
esac
_cfmgr_readlink=
for _cfmgr_candidate in /usr/bin/readlink /bin/readlink; do
	if [ -x "$_cfmgr_candidate" ]; then
		_cfmgr_readlink=$_cfmgr_candidate
		break
	fi
done
_cfmgr_hops=0
while [ -L "$_cfmgr_entry" ]; do
	[ -n "$_cfmgr_readlink" ] && [ "$_cfmgr_hops" -lt 16 ] || exit 1
	_cfmgr_target=$("$_cfmgr_readlink" "$_cfmgr_entry" 2>/dev/null) || exit 1
	case $_cfmgr_target in
	'' | *'
'*) exit 1 ;;
	/*) _cfmgr_entry=$_cfmgr_target ;;
	*) _cfmgr_entry=${_cfmgr_entry%/*}/$_cfmgr_target ;;
	esac
	_cfmgr_hops=$((_cfmgr_hops + 1))
done
_cfmgr_directory=$(CDPATH='' cd -P "${_cfmgr_entry%/*}" 2>/dev/null && pwd -P) || exit 1
if [ -f "$_cfmgr_directory/modules/diagnostic.sh" ] && [ ! -L "$_cfmgr_directory/modules/diagnostic.sh" ]; then
	_cfmgr_module=$_cfmgr_directory/modules/diagnostic.sh
elif [ -f /jffs/addons/CFMgr.d/diagnostic.sh ] && [ ! -L /jffs/addons/CFMgr.d/diagnostic.sh ]; then
	_cfmgr_module=/jffs/addons/CFMgr.d/diagnostic.sh
else
	printf '%s\n' 'CFMgr: diagnostic module unavailable.' >&2
	exit 1
fi
# shellcheck source=modules/diagnostic.sh
. "$_cfmgr_module"
# The command has already been dispatched; the library takes no CLI args.
# shellcheck disable=SC2119
cfmgr_diagnostic_main
