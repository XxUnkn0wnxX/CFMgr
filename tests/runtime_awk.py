"""Fixed embedded parser literals shared by category and consumer tests."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OWNERS = {
    "backup_yaml": "modules/backup.sh",
    "json": "modules/lib/config.sh",
    "backup_manifest": "modules/backup.sh",
    "config_schema": "modules/lib/config.sh",
    "backup_payload_index": "modules/backup.sh",
    "status_native": "modules/status.sh",
    "backup_cloud_writer": "modules/backup.sh",
    "backup_payload": "modules/backup.sh",
    "backup_pem": "modules/backup.sh",
    "status": "modules/status.sh",
    "health": "modules/status.sh",
    "health_cloud": "modules/status.sh",
    "health_selected": "modules/status.sh",
    "health_local": "modules/status.sh",
    "health_metadata": "modules/status.sh",
    "health_wire": "modules/status.sh",
    "health_response": "modules/status.sh",
    "health_compare": "modules/status.sh",
    "health_render": "modules/status.sh",
    "config_observation": "modules/lib/config.sh",
    "backup_archive_control": "modules/backup.sh",
    "backup_tar": "modules/backup.sh",
    "mountinfo": "modules/lib/storage.sh",
    "backup_payload_match": "modules/backup.sh",
    "backup_history_policy": "modules/backup.sh",
    "health_backup_plan": "modules/status.sh",
    "health_backup_observation": "modules/status.sh",
    "health_flat": "modules/status.sh",
    "health_package": "modules/status.sh",
    "package_records": "modules/lib/package.sh",
    "health_logging": "modules/status.sh",
    "health_logging_authority": "modules/status.sh",
    "health_hooks_authority": "modules/status.sh",
    "health_hooks_cron": "modules/status.sh",
    "health_hooks_frame": "modules/status.sh",
    "backup_history": "modules/backup.sh",
    "backup_uuid": "modules/backup.sh",
    "backup_inventory": "modules/backup.sh",
}


def awk_program(*fragments: str) -> str:
    programs = []
    for fragment in fragments:
        if fragment == "backup_history":
            programs.append(awk_program("backup_history_policy"))
        source = (ROOT / OWNERS[fragment]).read_text()
        begin = "\t# CFMGR-AWK-BEGIN " + fragment + "\n\tcfmgr_awk_program='\n"
        end = "'\n\t# CFMGR-AWK-END " + fragment + "\n"
        assert source.count(begin) == 1 and source.count(end) == 1
        program = source.split(begin, 1)[1].split(end, 1)[0]
        assert "'" not in program
        programs.append("\n" + program)
    result = "".join(programs)
    assert len(result.encode()) <= 98304
    return result


def awk_arguments(arguments):
    """Resolve explicit parser IDs in existing AWK command constructions."""
    result = []
    fragments = []
    position = None
    i = 0
    while i < len(arguments):
        value = str(arguments[i])
        if (
            value == "-f"
            and i + 1 < len(arguments)
            and str(arguments[i + 1]).startswith("cfmgr-parser:")
        ):
            # The former -f options may surround later -v assignments. The
            # complete program operand follows every such AWK option.
            position = len(result)
            fragments.append(str(arguments[i + 1]).split(":", 1)[1])
            i += 2
        else:
            result.append(arguments[i])
            i += 1
    if fragments:
        result.insert(position, awk_program(*fragments))
    return result
