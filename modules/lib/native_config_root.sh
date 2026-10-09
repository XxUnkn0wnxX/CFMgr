#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Source-only; trusted io/storage/entware/native_config/isolation/entware_root/
# native_devices definitions are explicitly loaded. This fixed composition adds
# extended configuration data to the retained Opt/device observation lifecycle.
# Copying data does not approve executable/config/NSS/TLS trust or authorize
# payload or network execution. The separate native_probe.sh worker composes
# only the fixed native_shell.sh probe exception. Existing owner rules apply.

cfmgr_isolation_native_config_root_with() {
	_cfmgr_entware_root_owner native-config production "$@" >/dev/null 2>&1
}

cfmgr_isolation_native_config_root_test() {
	_cfmgr_entware_root_owner native-config fixture "$@" >/dev/null 2>&1
}
