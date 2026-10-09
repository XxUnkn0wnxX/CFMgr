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
	native-dependencies)
		tools=$work/native-dependencies-tools native_source=$work/dependencies-native-source opt_source=$work/dependencies-opt-source
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

native_fixture_opkg() {
	# Shared static synthetic commands; never execute an installed opkg.
	"$bb" mkdir -m 700 "$opt_source/bin"
	"$bb" cp "$work/opkg-probe" "$opt_source/bin/opkg"
	"$bb" ln -s opkg "$opt_source/bin/timeout"
	"$bb" ln -s opkg "$opt_source/bin/sha256sum"
}

native_fixture_volume() {
	_cfmgr_io_mount_capture "$2" "$repo/modules/lib/mountinfo.awk" /proc/self/mountinfo 0 1 topology || return 1
	[ "$_mount_topology" = "topology$_io_tab-$_io_tab-$_io_tab-$_io_tab"'0'"$_io_tab"'0'"$_io_tab"'0' ] || return 1
	fixture_saved_ifs=$IFS
	IFS=$_io_tab
	# shellcheck disable=SC2086
	set -- $_mount_body
	IFS=$fixture_saved_ifs
	fixture_body="volume$_io_tab$2$_io_tab$4$_io_tab$7$_io_tab$5$_io_tab$6$_io_tab${11}$_io_tab$9$_io_tab${10}$_io_tab"'11111111-1111-1111-1111-111111111111'
	cfmgr_io_stage_report "$fixture_body${_io_lf}end$_io_tab$((${#fixture_body} + 1))$_io_lf"
}

native_fixture_storage_metadata() {
	volume=$(cfmgr_io_test "$ram" "$tools" report native_fixture_volume "$opt_source" && "$bb" printf '.') || return 1
	volume=${volume%.}
	volume_body=${volume%%'
'*}
	saved_ifs=$IFS
	IFS='	'
	# shellcheck disable=SC2086
	set -- $volume_body
	IFS=$saved_ifs
	fixture_device=$3
	# Replace only FD8's regular-file class by exact synthetic block metadata.
	# The real blockdev parser and retained FD9 observation remain active.
	"$bb" cat >"$tools/ls" <<'BLOCK_LS' || return 1
#!/bin/sh
if [ "$#" -eq 2 ] && [ "$1" = -dni ]; then
	case $2 in null | urandom) exec "$CFMGR_KERNEL_BUSYBOX" ls "$@" ;; esac
fi
if [ "$#" -ne 2 ] || [ "$1" != -dnL ] || [ "$2" != /proc/self/fd/8 ]; then exit 2; fi
BLOCK_LS
	"$bb" printf 'exec "%s" "brw------- 1 0 0 %s, %s Jan 1 00:00 /proc/self/fd/8\\n"\n' \
		"$tools/printf" "${fixture_device%%:*}" "${fixture_device#*:}" >>"$tools/ls" || return 1
	"$bb" chmod 700 "$tools/ls"
}
