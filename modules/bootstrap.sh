#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Reviewed byte identities from docs/evidence/bootstrap-catalog.json only.
# Source defines functions only; trusted closure.sh must already be sourced.
# The caller supplies stable private RAM, trusted nonsymlink ancestors, disabled
# tracing and no other writers. This helper does not approve mounts or runtime
# compatibility. The caller owns signals/cleanup; failures retain partial output.

# Reviewed archive acquisition only; trusted fetch.sh must also be sourced.
# Neither archive extraction nor package execution is authorized by success.
cfmgr_bootstrap_fetch() (
	trap - 0
	set +x
	set +e
	set +u
	set -f
	umask 077
	LC_ALL=C
	export LC_ALL
	IFS=' 	'
	IFS="${IFS}
"
	[ "$#" -eq 3 ] || return 2
	_cfmgr_bootstrap_archive "$1" "$2" || return 2
	_cfmgr_fetch_run '' "$3" "$_bootstrap_url" "$_bootstrap_size" "$_bootstrap_sha256"
) >/dev/null 2>&1

# Archive identities are a reviewed snapshot, never a runtime feed preference
# or an environment-selected URL/digest. Unknown replacements require review.
_cfmgr_bootstrap_archive() {
	_bootstrap_url=
	_bootstrap_size=
	_bootstrap_sha256=
	[ "$#" -eq 2 ] || return 2
	case $1:$2 in
	aarch64-k3.10:coreutils-timeout)
		_bootstrap_url=https://bin.entware.net/aarch64-k3.10/coreutils-timeout_9.9-2_aarch64-3.10.ipk
		_bootstrap_size=21046
		_bootstrap_sha256=8fd7f1f3c291b8556ca5cc77a55f16f656630ebc0af42ba879f0b62b35584516
		;;
	aarch64-k3.10:gzip)
		_bootstrap_url=https://bin.entware.net/aarch64-k3.10/gzip_1.14-1_aarch64-3.10.ipk
		_bootstrap_size=55607
		_bootstrap_sha256=2dc64aa9448b27d2d0b20cd78634e15d810525bd6a866094deba82878408c802
		;;
	armv7sf-k3.2:coreutils-timeout)
		_bootstrap_url=https://bin.entware.net/armv7sf-k3.2/coreutils-timeout_9.9-2_armv7-3.2.ipk
		_bootstrap_size=18404
		_bootstrap_sha256=26e52e7bba8dc7c8eee82be87ae1abd92fd924b5c86b1ac5f6ddaeb4e0d56157
		;;
	armv7sf-k3.2:gzip)
		_bootstrap_url=https://bin.entware.net/armv7sf-k3.2/gzip_1.14-1_armv7-3.2.ipk
		_bootstrap_size=49546
		_bootstrap_sha256=a7325626497fc20ff860c9240442e31dcd41ff28890785d3971a030144953826
		;;
	mipselsf-k3.4:coreutils-timeout)
		_bootstrap_url=https://bin.entware.net/mipselsf-k3.4/coreutils-timeout_9.9-2_mipsel-3.4.ipk
		_bootstrap_size=20295
		_bootstrap_sha256=add408df5340292347dfbc423b51c6cec7ad88b57f0f195318bf1ae276dc8e44
		;;
	mipselsf-k3.4:gzip)
		_bootstrap_url=https://bin.entware.net/mipselsf-k3.4/gzip_1.14-1_mipsel-3.4.ipk
		_bootstrap_size=53693
		_bootstrap_sha256=5cca33e44e0bd5f8c85ee996892a87dc8b963eb249fcdf6a165024728d1e8b42
		;;
	*) return 2 ;;
	esac
}

# Return 0 for complete fresh output, 1 for IO/existing-output failure, or 2 for
# invalid arguments/profile/path. No output escapes to the caller's streams.
cfmgr_bootstrap_manifest() (
	trap - 0
	set +e
	set +u
	set -f
	umask 077
	LC_ALL=C
	export LC_ALL
	[ "$#" -eq 2 ] || return 2
	case $1 in
	aarch64-k3.10) _bootstrap_bytes=546 ;;
	armv7sf-k3.2) _bootstrap_bytes=634 ;;
	mipselsf-k3.4) _bootstrap_bytes=635 ;;
	*) return 2 ;;
	esac
	_cfmgr_closure_path "$2" || return 2
	# A non-LF sentinel preserves the final LF through command substitution.
	_bootstrap_expected=$(_cfmgr_bootstrap_rows "$1" && command printf '.') || return 1
	_bootstrap_expected=${_bootstrap_expected%.}
	[ "${#_bootstrap_expected}" -eq "$_bootstrap_bytes" ] &&
		[ "${#_bootstrap_expected}" -le 4096 ] || return 1
	[ ! -e "$2" ] && [ ! -L "$2" ] || return 1
	# Ignore any closure fixture-tool state inherited from the caller.
	_closure_tools=''
	_bootstrap_wc=$(_cfmgr_closure_find wc) || return 1
	# Fatal redirection errors in some POSIX shells must remain inside this
	# nested subshell, so every write/readback failure normalizes to status 1.
	(
		set -C
		command printf '%s' "$_bootstrap_expected" >"$2" || exit 1
		_closure_manifest_bytes=''
		_closure_manifest_text=''
		_cfmgr_closure_manifest "$1" "$2" "$_bootstrap_wc" || exit 1
		[ "$_closure_manifest_bytes" -eq "$_bootstrap_bytes" ] &&
			[ "$_closure_manifest_text" = "$_bootstrap_expected" ] || exit 1
	) || return 1
) >/dev/null 2>&1

# Each fixed format consumes literal path/decimal size/lowercase digest triples.
# There is no runtime catalogue parser or caller-supplied member data.
_cfmgr_bootstrap_rows() {
	case $1 in
	aarch64-k3.10)
		command printf '%s\t%s\t%s\n' \
			'lib/ld-2.27.so' '136952' '9cf11983a8983de8f05aa0134ac0aafc6c34eb45138e8591cc397a6c09a3ab1c' \
			'lib/libc-2.27.so' '1427720' '9a2ba6fdce4bb9053f1b1078fc524cb9cc0cb3c4386d07470085a59ad9af42c4' \
			'lib/libpthread-2.27.so' '105168' 'b86bb800b8440ea5f128fd9e574a8af1598eb8e16ee2c1e0cdb158689df72005' \
			'lib/librt-2.27.so' '31032' '65572d6fe758f0dbde3741d220c57741ed411989c100e23bc17e32eaedf64e5a' \
			'libexec/timeout-coreutils' '44112' 'ba7a4ae4237c790b4c989bd87a125b911c808edbeab25c67e1777a748bd659d7' \
			'libexec/gzip-gnu' '93600' '500eb9ff2a7067159a581c8ccd7d4b85c2a011a3a919081981b00626846e97a7'
		;;
	armv7sf-k3.2)
		command printf '%s\t%s\t%s\n' \
			'lib/ld-2.27.so' '134428' 'fe412c44b24b7900eb390701d5a4cba3b348e3d67c1ac0116c8f6451f7d1cfb0' \
			'lib/libc-2.27.so' '1247408' 'be552c80cf13cddc5fdca4c1ced2e681d3b5ca2b4f35f841dccd32b014634ad9' \
			'lib/libpthread-2.27.so' '92656' '1fcb89ce39c319210043a17adba1d0de43760c283643b503e16222033652d1ac' \
			'lib/librt-2.27.so' '26516' '6a770ea97ad8b31448b109ed882dedd5a121e13fa69cb99f70b32eac695d1c6f' \
			'lib/libgcc_s.so.1' '46752' '13834c4ccc78f14ace0fb2fd121a7d2dc51732075463afca791d2fd4df1d7c78' \
			'libexec/timeout-coreutils' '39152' '1479674edc7fbf7ecb33ed668cb7114b33a2d7f805cd62ca94868495f915bd7f' \
			'libexec/gzip-gnu' '80316' '43537cf1252858e3492d1825e0b60bd440d4badbe20103eeecaea2834285ea96'
		;;
	mipselsf-k3.4)
		command printf '%s\t%s\t%s\n' \
			'lib/ld-2.27.so' '159016' '32fef6bdd8febc7f066910b63fccf5648280d17fb49dda97d4770fd1172eef0f' \
			'lib/libc-2.27.so' '1672960' 'ab12e4d3d3b72a08c195bf6e91f96c3c5aaea3c311dc9e77dfa9a3cb2984c8d2' \
			'lib/libpthread-2.27.so' '123056' 'f37ca66a709864de66755dfdc6306355de7bfb244b7e8901d696db90a3ee7eba' \
			'lib/librt-2.27.so' '33200' 'da9d1b989f9023e046120aa8c994515dce05459880cb3283241a0e02462474a5' \
			'lib/libgcc_s.so.1' '85924' '9672bd8dfb491b8d2bc895262e8d0f8b158efbfb3c1a754639fa2cdef9bfb76e' \
			'libexec/timeout-coreutils' '45508' '4d7ff5e75dda873b23b6899acf647265dc831fe3780c6037809f77331c97ee6c' \
			'libexec/gzip-gnu' '93240' 'd9ddde441fb1a06272384866cbaf63cf50b92ff4c29a63d99032057dfa63b5f0'
		;;
	*) return 2 ;;
	esac
}
