#!/bin/sh
# Shared trusted kernel-fixture preparation, never sourced by router code.
# Call only after the driver's mount/PID namespace identity checks.
# Context is shared deliberately with the fixed fixture drivers.
# shellcheck disable=SC2034,SC2154

native_fixture_context() {
	ram=$work/ram tools=$work/tools native_source=$work/native-source opt_source=$work/opt-source
	data_source=$ram/native-data-source guard=$work/ram/$1
	case $1 in
	native-root) ;;
	native-probe)
		tools=$work/native-probe-tools native_source=$work/probe-native-source opt_source=$work/probe-opt-source
		;;
	*) return 2 ;;
	esac
}

native_fixture_prepare() {
	native_fixture_context "$1"
	"$bb" mkdir -m 700 "$native_source" "$opt_source"
	"$bb" ln -s "$bb" "$tools/mknod"
	"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$ram"
	"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$native_source"
	"$bb" mount -t tmpfs -o mode=700,nosuid tmpfs "$opt_source"
	for view in bin sbin lib usr; do
		"$bb" mkdir -m 700 "$native_source/$view"
		printf '%s\n' "$view" >"$native_source/$view/marker"
	done
	# Genuine trusted host shell/loader bytes and static descriptor instrumentation.
	# The runner patches only its BusyBox fixture's PT_INTERP to fit the /lib view.
	"$bb" cp -a "$work/native-staging/." "$native_source/"
	"$bb" rm "$tools/chroot"
	"$bb" cp "$work/native-chroot" "$tools/chroot"
	# Remount the actual source filesystem readonly: a RO bind alone would leave
	# its superblock RW and must be refused by the native-source admission profile.
	"$bb" mount -n -i -o remount,ro "$native_source"
	"$bb" mkdir -m 700 "$data_source" "$data_source/etc"
	data_hosts='127.0.0.1	localhost\fixture

'
	printf '%s' "$data_hosts" >"$data_source/etc/hosts"
	: >"$data_source/etc/resolv.conf"
	"$bb" mkdir -m 700 "$data_source/etc/ssl" "$data_source/etc/ssl/certs"
	"$bb" printf 'hosts: files dns\n\000nss-bytes\n' >"$data_source/etc/nsswitch.conf"
	"$bb" printf 'ca_certificate=/etc/ssl/certs/ca-certificates.crt\n\000wget-bytes\n' >"$data_source/etc/wgetrc"
	"$bb" printf '[default]\nvalue=opaque\\bytes\n\n' >"$data_source/etc/openssl.cnf"
	# Binary data is produced and compared through files, never large argv/env.
	"$bb" dd if=/dev/zero of="$data_source/etc/ssl/certs/ca-certificates.crt" bs=4096 count=33 2>/dev/null
	"$bb" printf '\001ca-tail\n\n' >>"$data_source/etc/ssl/certs/ca-certificates.crt"
	[ "$("$bb" wc -c <"$data_source/etc/ssl/certs/ca-certificates.crt")" -gt 131072 ] || fail 'small CA fixture'
	"$bb" mkdir -m 700 "$guard"
	native_fixture_load
}

native_fixture_load() {
	# shellcheck source=/dev/null
	. "$repo/modules/lib/io.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/storage.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/native_config.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/isolation.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/entware.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/entware_root.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/native_devices.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/native_config_root.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/native_exec.sh"
	# shellcheck source=/dev/null
	. "$repo/modules/lib/native_dependencies.sh"
}
