#!/bin/sh
# Source-inert guarded execution-view foundation; no package launch/supervisor.
# The controller admits a fresh private RAM context, native tools and storage
# (UUID plus held FD6/7). It supplies the fixed trusted callbacks below:
# cfmgr_execution_view_native MODE OPERANDS: bounded/reaped native operation;
# 0 success, 1 ordinary failure, 2 invalid, 3 unresolved child/operation.
# Modes: inventory, list, identity, readlink, mkdir, file, link, chmod, copy,
# root, guard-root, bind4, bind7, private, unbindable, seal, unmount, awk.
# Observation output files are fixed private-context operands. `awk` invokes
# cfmgr_execution_view_awk with its finite mode, never arbitrary program text.
# cfmgr_execution_view_quiescent: independently qualified task/root quiescence;
# a successful package exit or a boolean attachment mock is not that proof.
# FD4 is construction scratch and must initially be closed. FD0/5/6/7/8/9
# remain caller-owned. Never release storage pins while an unresolved view lives.
# Return 1 retains a reviewable ordinary failure; 2 invalid admission; 3 retains
# uncertain operations. Only successful create sets ready; release is retryable.

_cfmgr_view_call() {
	if cfmgr_execution_view_native "$@"; then return 0; else
		cfmgr_view_code=$?
		case $cfmgr_view_code in
		1 | 2) return "$cfmgr_view_code" ;;
		*)
			cfmgr_view_pending=native-unresolved
			return 3
			;;
		esac
	fi
}

# Fixed bounded data transformations for the trusted native callback.
# Inputs originate in the validated mount parser/private ledger, never shell code.
# shellcheck disable=SC2016
cfmgr_execution_view_awk() {
	case $1 in
	source)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { context=ARGV[1]; ARGV[1]="" }
			$5==context || index($5,context "/")==1 { next }
			{ if (NF!=10 || ++n>256 || seen[$5]++) { bad=1; exit 1 }; rows[n]=$0 }
			END { if (bad || n>256) exit 1; for (i=1;i<=n;i++) print rows[i] }
		' "$cfmgr_view_context" "$1" >"$2"
		;;
	order)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { root=ARGV[1]; ARGV[1]=""; prefix=root=="/" ? "/" : root "/" }
			{ relative=substr($5,length(prefix)+1)
			  if ($5==root || index(relative,"/")==0) next
			  depth=split(relative,a,"/"); n++; row[n]=$0; d[n]=depth }
			END { for (i=2;i<=n;i++) { r=row[i]; depth=d[i]; j=i-1
			  while (j>0 && d[j]>depth) { row[j+1]=row[j]; d[j+1]=d[j]; j-- }
			  row[j+1]=r; d[j+1]=depth }
			  for (i=1;i<=n;i++) print row[i] }
		' "$cfmgr_view_native_root" "$1" >"$2"
		;;
	change)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { mode=ARGV[1]; point=ARGV[2]; remove=ARGV[3]; ARGV[1]=ARGV[2]=ARGV[3]="" }
			FILENAME==ARGV[4] { old[$1]=$0; oldpoint[$1]=$5; count++; next }
			{ current[$1]=$0
			  if (!($1 in old)) { added++; if ($5!=point) bad=1 }
			  else if (old[$1]!=$0) {
			    changed++; split(old[$1],a,"\t")
			    if ($5!=point || (mode!="private" && mode!="unbindable" && mode!="seal")) bad=1
			    for (i=1;i<=7;i++) if ($i!=a[i]) bad=1
			    if (mode=="seal") { if ($10!=a[10] || $8 !~ /(^|,)ro(,|$)/) bad=1 }
			    else { if ($8!=a[8] || $9!=a[9] || $10!=mode) bad=1 }
			  }
			}
			END { for (id in old) if (!(id in current)) {
			  missing++; if (mode!="unmount" || id!=remove || oldpoint[id]!=point) bad=1 }
			  if (mode=="root" || mode=="guard-root" || mode=="bind4" || mode=="bind7") {
			    if (added!=1 || changed || missing) bad=1
			  } else if (mode=="unmount") { if (missing!=1 || added || changed) bad=1
			  } else if (added || missing || changed>1) bad=1
			  exit bad ? 1 : 0 }
		' "$1" "$2" "$3" "$4" "$5"
		;;
	same)
		shift
		"$cfmgr_view_awk" -F '\t' '
			FILENAME==ARGV[1] { expected[$1]=$0; n++; next }
			{ if (!($1 in expected) || expected[$1]!=$0) bad=1; m++ }
			END { exit bad || n!=m ? 1 : 0 }
		' "$1" "$2"
		;;
	recover)
		shift
		"$cfmgr_view_awk" -F '\t' '
			FILENAME==ARGV[1] { expected[$1]=$0; next }
			FILENAME==ARGV[2] { live[$1]=1; next }
			{ if (!($1 in expected) || expected[$1]!=$0) bad=1; current[$1]=$0; rows[++n]=$0 }
			END { for (id in expected) if (!(id in current) && (id in live)) bad=1
			  if (bad) exit 1; for (i=1;i<=n;i++) print rows[i] }
		' "$1" "$2" "$3" >"$4"
		;;
	cover-private)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { target=ARGV[1]; ARGV[1]="" }
			$5=="/" || $5==target || index(target,$5 "/")==1 {
			  if (length($5)>depth) { depth=length($5); n=0; propagation=$10 }
			  if (length($5)==depth) n++ }
			END { exit n!=1 || propagation!="private" ? 1 : 0 }
		' "$1" "$2"
		;;
	fd-record)
		shift
		"$cfmgr_view_awk" -F '\t' '
			FILENAME==ARGV[1] && /^mnt_id:/ { split($0,a,/ +|\t+/); id=a[2]; n++; next }
			FILENAME==ARGV[2] && $1==id { row=$0; matches++ }
			END { if (n!=1 || id !~ /^[1-9][0-9]*$/ || matches!=1) exit 1; print row }
		' "/proc/self/fdinfo/$1" "$2" >"$3"
		;;
	bind-proof)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { source=ARGV[1]; target=ARGV[2]; ARGV[1]=ARGV[2]="" }
			FILENAME==ARGV[3] { split($0,original,"\t"); n++; next }
			$5==target { row[$1]=$0; parent[$2]=1 }
			END { for (id in row) if (!(id in parent)) { top++; split(row[id],bound,"\t") }
			  if (n!=1 || top!=1) exit 1
			  if (original[5]==source) expected=original[4]
			  else { prefix=original[5]=="/" ? "/" : original[5] "/"
			    if (index(source,prefix)!=1) exit 1
			    expected=(original[4]=="/" ? "" : original[4]) "/" substr(source,length(prefix)+1) }
			  exit bound[3]!=original[3] || bound[4]!=expected || bound[6]!=original[6] ||
			    bound[7]!=original[7] || bound[8]!=original[8] || bound[9]!=original[9] ? 1 : 0 }
		' "$1" "$2" "$3" "$4"
		;;
	properties)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { mode=ARGV[1]; target=ARGV[2]; ARGV[1]=ARGV[2]="" }
			$5==target { row[$1]=$0; parent[$2]=1 }
			END { for (id in row) if (!(id in parent)) { n++; split(row[id],a,"\t") }
			  if (n!=1) exit 1
			  if (mode=="private" || mode=="unbindable") exit a[10]!=mode ? 1 : 0
			  if (a[6]!="tmpfs" || a[4]!="/") exit 1
			  if (mode=="seal") exit a[8] !~ /(^|,)ro(,|$)/ ? 1 : 0
			  exit a[8] !~ /(^|,)rw(,|$)/ || a[10]!="private" ? 1 : 0 }
		' "$1" "$2" "$3"
		;;
	top)
		shift
		"$cfmgr_view_awk" -F '\t' '
			BEGIN { point=ARGV[1]; ARGV[1]="" }
			$5==point { ids[$1]=1; parents[$2]=1 }
			END { for (id in ids) if (!(id in parents)) { n++; top=id }
			  if (n!=1) exit 1; print top }
		' "$1" "$2" >"$3"
		;;
	*) return 2 ;;
	esac
}

_cfmgr_view_inventory() {
	_cfmgr_view_call inventory "$1" "$2"
}

_cfmgr_view_source_check() {
	cfmgr_storage_attached || return 1
	_cfmgr_view_call identity "$cfmgr_view_native_root" "$cfmgr_view_context/root.current" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/root.identity" "$cfmgr_view_context/root.current" || return $?
	_cfmgr_view_inventory "$cfmgr_view_native_root" "$cfmgr_view_context/source.raw" || return $?
	_cfmgr_view_call awk source "$cfmgr_view_context/source.raw" "$cfmgr_view_context/source.current" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/source.mounts" "$cfmgr_view_context/source.current" || return $?
	_cfmgr_view_call list "$cfmgr_view_native_root" "$cfmgr_view_context/top.current" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/top.names" "$cfmgr_view_context/top.current" || return $?
	cfmgr_view_source_index=0
	while IFS= read -r cfmgr_view_name; do
		cfmgr_view_source_index=$((cfmgr_view_source_index + 1))
		_cfmgr_view_call identity "${cfmgr_view_native_root%/}/$cfmgr_view_name" "$cfmgr_view_context/identity.current" || return $?
		IFS= read -r cfmgr_view_current_identity <"$cfmgr_view_context/identity.current" || return 1
		IFS= read -r cfmgr_view_saved_identity <"$cfmgr_view_context/source.$cfmgr_view_source_index" || return 1
		[ "$cfmgr_view_current_identity" = "$cfmgr_view_saved_identity" ] || return 1
	done <"$cfmgr_view_context/top.names"
}

_cfmgr_view_exact() {
	[ -z "$cfmgr_view_pending" ] || return 3
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/current.mounts" || return $?
	_cfmgr_view_call awk same "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/current.mounts"
}

_cfmgr_view_target() {
	# Never follow a mirrored absolute symlink out of the owned scaffold.
	_cfmgr_storage_path "$1" || return 1
	case $1 in "$cfmgr_view_root" | "$cfmgr_view_root"/*) ;; *) return 1 ;; esac
	cfmgr_view_walk=$1
	while [ "$cfmgr_view_walk" != "$cfmgr_view_root" ]; do
		[ ! -L "$cfmgr_view_walk" ] || return 1
		cfmgr_view_walk=${cfmgr_view_walk%/*}
		[ -d "$cfmgr_view_walk" ] && [ ! -L "$cfmgr_view_walk" ] || return 1
	done
}

_cfmgr_view_mutate() {
	# MODE TARGET; source bind descriptor is inherited, never reopened by name.
	_cfmgr_view_exact || return $?
	[ "$cfmgr_view_sequence" -lt 4096 ] || return 3
	cfmgr_view_sequence=$((cfmgr_view_sequence + 1))
	cfmgr_view_pending=$cfmgr_view_sequence
	printf '%s\t%s\n' "$1" "$2" >"$cfmgr_view_context/intent.$cfmgr_view_sequence" || return 3
	if _cfmgr_view_call "$1" "$2"; then cfmgr_view_operation_code=0; else cfmgr_view_operation_code=$?; fi
	[ "$cfmgr_view_operation_code" -ne 3 ] || return 3
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/observed.mounts" || return 3
	if [ "$cfmgr_view_operation_code" -ne 0 ]; then
		if _cfmgr_view_call awk same "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/observed.mounts"; then
			cfmgr_view_pending=''
			return "$cfmgr_view_operation_code"
		fi
		return 3
	fi
	_cfmgr_view_call awk change "$1" "$2" "${cfmgr_view_remove_id:-0}" "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/observed.mounts" || return 3
	case $1 in root | guard-root | private | unbindable | seal)
		_cfmgr_view_call awk properties "$1" "$2" "$cfmgr_view_context/observed.mounts" || return 3
		;;
	esac
	_cfmgr_view_call copy "$cfmgr_view_context/observed.mounts" "$cfmgr_view_context/expected.mounts" || return 3
	printf '%s\t%s\n' "$1" "$2" >"$cfmgr_view_context/done.$cfmgr_view_sequence" || return 3
	cfmgr_view_pending=''
}

# shellcheck disable=SC3013,SC2154 # Descriptor-backed Linux mount identity is required CI proof.
_cfmgr_view_bind() {
	# SOURCE TARGET; '-' means inherited Entware descriptor 7.
	_cfmgr_view_source_check || return $?
	_cfmgr_view_target "$2" || return 1
	[ -e "$2" ] && [ ! -L "$2" ] || return 1
	if [ "$1" = - ]; then cfmgr_view_bind_mode=bind7; else
		exec 4<"$1" || return 1
		cfmgr_view_bind_mode=bind4
	fi
	cfmgr_view_bind_fd=4 cfmgr_view_bind_source=$1
	if [ "$1" = - ]; then
		cfmgr_view_bind_fd=7
		cfmgr_view_bind_source=$cfmgr_storage_opt
	fi
	if ! _cfmgr_view_inventory / "$cfmgr_view_context/bind.mounts"; then
		exec 4<&-
		return 3
	fi
	if ! _cfmgr_view_call awk fd-record "$cfmgr_view_bind_fd" "$cfmgr_view_context/bind.mounts" "$cfmgr_view_context/bind.source"; then
		exec 4<&-
		return 3
	fi
	if _cfmgr_view_mutate "$cfmgr_view_bind_mode" "$2"; then cfmgr_view_bind_code=0; else cfmgr_view_bind_code=$?; fi
	if [ "$cfmgr_view_bind_code" -eq 0 ]; then
		if ! _cfmgr_view_call awk bind-proof "$cfmgr_view_bind_source" "$2" "$cfmgr_view_context/bind.source" "$cfmgr_view_context/expected.mounts"; then cfmgr_view_bind_code=3; fi
		if [ "$1" = - ]; then
			[ "$2" -ef /proc/self/fd/7 ] || cfmgr_view_bind_code=3
		else
			[ "$2" -ef /proc/self/fd/4 ] || cfmgr_view_bind_code=3
		fi
	fi
	exec 4<&-
	if [ "$cfmgr_view_bind_code" -eq 3 ]; then cfmgr_view_pending=bind-unverified; fi
	[ "$cfmgr_view_bind_code" -eq 0 ] || return "$cfmgr_view_bind_code"
	_cfmgr_view_mutate private "$2"
}

_cfmgr_view_guarded_bind() {
	# Empty immutable underlay survives removal of any device-backed upper leaf.
	if [ -d "$2" ]; then cfmgr_view_underlay=$cfmgr_view_guard; else cfmgr_view_underlay=$cfmgr_view_guard/empty; fi
	_cfmgr_view_bind "$cfmgr_view_underlay" "$2" || return $?
	_cfmgr_view_bind "$1" "$2"
}

# Input is trusted controller data, not environment configuration.
# NATIVE_ROOT FRESH_PRIVATE_RAM_CONTEXT AWK READLINK PARSER
# The context and its ancestry must already be admitted/pinned by the controller.
# shellcheck disable=SC2034,SC2154
cfmgr_execution_view_create() {
	cfmgr_view_state=invalid
	[ "$#" -eq 5 ] || return 2
	for cfmgr_view_argument; do _cfmgr_storage_path "$cfmgr_view_argument" || return 2; done
	cfmgr_view_native_root=$1 cfmgr_view_context=$2 cfmgr_view_awk=$3 cfmgr_view_readlink=$4 cfmgr_view_parser=$5
	[ -d "$1" ] && [ ! -L "$1" ] && [ -d "$2" ] && [ ! -L "$2" ] || return 2
	if (: <&4) 2>/dev/null; then return 2; fi
	cfmgr_storage_attached && [ -n "${cfmgr_storage_uuid_value:-}" ] || return 2
	case $1 in "$2" | "$2"/*) return 2 ;; esac
	cfmgr_view_root=$2/view cfmgr_view_guard=$2/guard
	cfmgr_view_sequence=0 cfmgr_view_pending='' cfmgr_view_remove_id=0
	# Exclusive fresh claim. Existing evidence is never overwritten or removed.
	(
		umask 077
		set -C
		: >"$2/expected.mounts"
	) || return 2
	cfmgr_view_state=building
	# Private propagation must exist before the first mount. Do not change an
	# unrelated host ancestor to repair missing admission.
	_cfmgr_view_inventory / "$2/host.mounts" || return $?
	_cfmgr_view_call awk cover-private "$2" "$2/host.mounts" || return 2
	_cfmgr_view_inventory "$2" "$2/current.mounts" || return $?
	[ ! -s "$2/current.mounts" ] || return 2
	_cfmgr_view_inventory "$1" "$2/source.raw" || return $?
	_cfmgr_view_call awk source "$2/source.raw" "$2/source.mounts" || return $?
	_cfmgr_view_call awk order "$2/source.mounts" "$2/children.mounts" || return $?
	_cfmgr_view_call identity "$1" "$2/root.identity" || return $?
	IFS='	' read -r cfmgr_view_root_inode cfmgr_view_root_mode cfmgr_view_root_uid cfmgr_view_root_gid <"$2/root.identity" || return 2
	case $cfmgr_view_root_mode in '' | *[!0-7]*) return 2 ;; esac
	[ "${#cfmgr_view_root_mode}" -le 4 ] && [ "$cfmgr_view_root_uid:$cfmgr_view_root_gid" = 0:0 ] || return 2
	_cfmgr_view_call list "$1" "$2/top.names" || return $?
	cfmgr_view_source_index=0
	while IFS= read -r cfmgr_view_name; do
		case $cfmgr_view_name in '' | . | .. | */* | *[!\ -~]*) return 2 ;; esac
		cfmgr_view_source_index=$((cfmgr_view_source_index + 1))
		[ "$cfmgr_view_source_index" -le 256 ] || return 2
		_cfmgr_view_call identity "${1%/}/$cfmgr_view_name" "$2/source.$cfmgr_view_source_index" || return $?
	done <"$2/top.names"
	_cfmgr_view_call mkdir "$cfmgr_view_guard" 700 || return $?
	_cfmgr_view_mutate guard-root "$cfmgr_view_guard" || return $?
	_cfmgr_view_call file "$cfmgr_view_guard/empty" || return $?
	_cfmgr_view_mutate seal "$cfmgr_view_guard" || return $?
	_cfmgr_view_call mkdir "$cfmgr_view_root" 700 || return $?
	_cfmgr_view_mutate root "$cfmgr_view_root" || return $?
	_cfmgr_view_mutate unbindable "$cfmgr_view_root" || return $?
	cfmgr_view_has_opt=0
	while IFS= read -r cfmgr_view_name; do
		cfmgr_view_from=${cfmgr_view_native_root%/}/$cfmgr_view_name
		cfmgr_view_to=$cfmgr_view_root/$cfmgr_view_name
		if [ "$cfmgr_view_name" = opt ]; then
			cfmgr_view_has_opt=1
			_cfmgr_view_call mkdir "$cfmgr_view_to" 755 || return $?
			_cfmgr_view_guarded_bind - "$cfmgr_view_to" || return $?
		elif [ -L "$cfmgr_view_from" ]; then
			_cfmgr_view_call readlink "$cfmgr_view_from" "$cfmgr_view_context/link.text" || return $?
			{
				IFS= read -r cfmgr_view_link || return 2
				cfmgr_view_link_extra=''
				if IFS= read -r cfmgr_view_link_extra; then return 2; fi
				[ -z "$cfmgr_view_link_extra" ] || return 2
			} <"$cfmgr_view_context/link.text"
			[ "${#cfmgr_view_link}" -le 4096 ] || return 2
			case $cfmgr_view_link in '' | *[!\ -~]*) return 2 ;; esac
			_cfmgr_view_call link "$cfmgr_view_link" "$cfmgr_view_to" || return $?
		else
			if [ -d "$cfmgr_view_from" ]; then
				_cfmgr_view_call mkdir "$cfmgr_view_to" 755 || return $?
			elif [ -f "$cfmgr_view_from" ]; then
				_cfmgr_view_call file "$cfmgr_view_to" || return $?
			else return 2; fi
			_cfmgr_view_guarded_bind "$cfmgr_view_from" "$cfmgr_view_to" || return $?
		fi
	done <"$cfmgr_view_context/top.names"
	if [ "$cfmgr_view_has_opt" -eq 0 ]; then
		_cfmgr_view_call mkdir "$cfmgr_view_root/opt" 755 || return $?
		_cfmgr_view_guarded_bind - "$cfmgr_view_root/opt" || return $?
	fi
	while IFS='	' read -r cfmgr_view_id cfmgr_view_parent cfmgr_view_device cfmgr_view_fsroot cfmgr_view_point cfmgr_view_type cfmgr_view_source cfmgr_view_options cfmgr_view_super cfmgr_view_propagation; do
		cfmgr_view_relative=${cfmgr_view_point#"${cfmgr_view_native_root%/}"/}
		cfmgr_view_to=$cfmgr_view_root/$cfmgr_view_relative
		_cfmgr_view_target "$cfmgr_view_to" || return 1
		_cfmgr_view_guarded_bind "$cfmgr_view_point" "$cfmgr_view_to" || return $?
		case $cfmgr_view_point in "$cfmgr_storage_opt"/*)
			cfmgr_view_opt_child=$cfmgr_view_root/opt/${cfmgr_view_point#"$cfmgr_storage_opt"/}
			if [ "$cfmgr_view_opt_child" != "$cfmgr_view_to" ]; then
				_cfmgr_view_guarded_bind "$cfmgr_view_point" "$cfmgr_view_opt_child" || return $?
			fi
			;;
		esac
	done <"$cfmgr_view_context/children.mounts"
	# Native /tmp mirrors the controller's private directory. Hide only that
	# owned context, never create a directory through a bound native parent.
	case $cfmgr_view_context in
	"${cfmgr_view_native_root%/}"/*)
		cfmgr_view_relative=${cfmgr_view_context#"${cfmgr_view_native_root%/}"/}
		_cfmgr_view_bind "$cfmgr_view_guard" "$cfmgr_view_root/$cfmgr_view_relative" || return $?
		;;
	esac
	_cfmgr_view_call chmod "$cfmgr_view_root" "$cfmgr_view_root_mode" || return $?
	_cfmgr_view_mutate seal "$cfmgr_view_root" || return $?
	cfmgr_execution_view_recheck || return $?
	cfmgr_view_state=ready
}

cfmgr_execution_view_recheck() {
	case ${cfmgr_view_state:-invalid} in building | ready) ;; *) return 2 ;; esac
	if _cfmgr_view_source_check && _cfmgr_view_exact; then return 0; else
		cfmgr_view_recheck_code=$?
		cfmgr_view_state=retained
		return "$cfmgr_view_recheck_code"
	fi
}

# Caller must independently prove no owned task/thread/root can still use the
# view. Missing mounts are reconciled only after that proof and full-namespace
# absence; a hidden/replaced mount ID or any foreign layer preserves evidence.
cfmgr_execution_view_release() {
	case ${cfmgr_view_state:-invalid} in building | ready | retained) ;; *) return 2 ;; esac
	cfmgr_view_state=retained
	cfmgr_execution_view_quiescent || return 3
	[ -z "$cfmgr_view_pending" ] || return 3
	_cfmgr_view_inventory / "$cfmgr_view_context/all.mounts" || return $?
	_cfmgr_view_inventory "$cfmgr_view_context" "$cfmgr_view_context/current.mounts" || return $?
	_cfmgr_view_call awk recover "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/all.mounts" "$cfmgr_view_context/current.mounts" "$cfmgr_view_context/recovered.mounts" || return 3
	_cfmgr_view_call copy "$cfmgr_view_context/recovered.mounts" "$cfmgr_view_context/expected.mounts" || return 3
	cfmgr_view_release_sequence=$cfmgr_view_sequence
	while [ "$cfmgr_view_release_sequence" -gt 0 ]; do
		if [ -f "$cfmgr_view_context/done.$cfmgr_view_release_sequence" ]; then
			IFS='	' read -r cfmgr_view_done_mode cfmgr_view_done_target <"$cfmgr_view_context/done.$cfmgr_view_release_sequence" || return 3
			case $cfmgr_view_done_mode in root | guard-root | bind4 | bind7)
				_cfmgr_view_exact || return 3
				if _cfmgr_view_call awk top "$cfmgr_view_done_target" "$cfmgr_view_context/expected.mounts" "$cfmgr_view_context/top.id"; then
					IFS= read -r cfmgr_view_remove_id <"$cfmgr_view_context/top.id" || return 3
					if _cfmgr_view_mutate unmount "$cfmgr_view_done_target"; then :; else return $?; fi
				else
					cfmgr_view_top_status=$?
					[ "$cfmgr_view_top_status" -eq 1 ] || return 3
				fi
				;;
			esac
		fi
		cfmgr_view_release_sequence=$((cfmgr_view_release_sequence - 1))
	done
	_cfmgr_view_exact || return 3
	[ ! -s "$cfmgr_view_context/expected.mounts" ] || return 3
	cfmgr_view_state=released
	# Retain the flat control ledger and now-empty mountpoint directories for
	# explicit controller-owned recovery/cleanup; never recursively delete here.
}
