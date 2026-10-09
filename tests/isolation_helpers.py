"""Shared focused shell helpers for isolated-mount integration fixtures."""

FOCUSED_ISOLATION_QUERY = r"""
_cfmgr_isolation_query_action() {
    _fixture_cat=$(_cfmgr_io_find cat) || return 1
    "$_fixture_cat" "$_isolation_input" >"$_io_stage/raw" 2>"$_io_stage/raw.err" || return 1
    _fixture_error_size=$(_cfmgr_io_size "$_io_stage/raw.err") || return 1
    [ "$_fixture_error_size" = 0 ] || return 1
    _fixture_size=$(_cfmgr_io_size "$_io_stage/raw") || return 1
    _fixture_awk=$(_cfmgr_io_find awk) || return 1
    CFMGR_MOUNT_TARGET=$2
    export CFMGR_MOUNT_TARGET
    "$_fixture_awk" -v "cfmgr_mountinfo_size=$_fixture_size" \
        -v cfmgr_mountinfo_mode=topology -f "$_isolation_parser" \
        <"$_io_stage/raw" >"$_io_stage/parsed" 2>"$_io_stage/parsed.err" || return 1
    _fixture_error_size=$(_cfmgr_io_size "$_io_stage/parsed.err") || return 1
    [ "$_fixture_error_size" = 0 ] || return 1
    _cfmgr_isolation_read "$_io_stage/parsed" || return 1
    _mount_ledger=$_isolation_text
    case $4 in
        1) _fixture_canonical_target=$_isolation_root ;;
        2) _fixture_canonical_target=$2 ;;
        *) _fixture_canonical_target= ;;
    esac
    if [ -n "$_fixture_canonical_target" ]; then
        _fixture_readlink=$(_cfmgr_io_find readlink) || return 1
        "$_fixture_readlink" -f "$_fixture_canonical_target" \
            >"$_io_stage/2.out" 2>"$_io_stage/2.err" || return 1
        _fixture_error_size=$(_cfmgr_io_size "$_io_stage/2.err") || return 1
        [ "$_fixture_error_size" = 0 ] || return 1
        _cfmgr_storage_line 2 || return 1
        [ "$_storage_line" = "$_fixture_canonical_target" ] || return 1
    fi
    _cfmgr_isolation_write "$3" "$_mount_ledger"
}
"""
