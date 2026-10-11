#!/bin/sh
# Native flush prerequisite, not a transaction or storage-admission layer.
# The caller must admit the executable and storage, own/exclude mutation of the
# target, and open that regular file or directory read-only on inherited fd 3.
# The caller owns fd 3's lifetime and must supervise/reap the action under its
# storage/ownership guards. Kernel I/O can remain uninterruptible: this function
# provides neither a deadline nor proof of a complete durable publication.
# The admitted native utility must have the reviewed bounded text diagnostics.
# Merlin fsync can return zero after fsync(2) fails; any diagnostic is a failure.
# No filesystem operation occurs when this library is sourced.

cfmgr_storage_flush_fd() (
	[ "$#" -eq 1 ] || return 2
	case $1 in
	/*) ;;
	*) return 2 ;;
	esac
	[ -f "$1" ] && [ -x "$1" ] || return 2
	# Validate inheritance without opening a pathname or changing the descriptor.
	(: <&3) 2>/dev/null || return 2
	# The fixed operand bounds native errno diagnostics. Appending the marker
	# inside substitution preserves even newline-only output, which command
	# substitution would otherwise trim. It is appended only after exit zero.
	cfmgr_flush_result=$(
		{
			LC_ALL=C LANGUAGE='' "$1" /proc/self/fd/3 &&
				printf '%s' 'CFMGR_FLUSH_OK_v1'
		} 2>&1
	) || return 1
	[ "$cfmgr_flush_result" = 'CFMGR_FLUSH_OK_v1' ] || return 1
)
