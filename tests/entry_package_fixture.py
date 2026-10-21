"""Complete installed fixture metadata and literal native-platform adapters."""

from __future__ import annotations

import os
import shlex
import shutil
import tempfile
from pathlib import Path

from tools import package as package_builder

ROOT = Path(__file__).resolve().parents[1]


def complete_modules(support: Path) -> None:
    """Fill missing payloads without replacing a consumer's explicit adapters."""
    for source in (ROOT / "modules").rglob("*"):
        if source.name == ".DS_Store":
            continue
        target = support / source.relative_to(ROOT)
        if source.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        elif not target.exists():
            shutil.copy2(source, target)


def adapt_native(text: str, jffs: Path, tools: dict[str, str], shell: list[str]) -> str:
    """Run actual firmware applets in vendor CI and actual host tools elsewhere."""
    names = {
        "/usr/bin/readlink": "readlink",
        "/usr/bin/awk": "awk",
        "/bin/ls": "ls",
        "/bin/dd": "dd",
        "/usr/bin/wc": "wc",
        "/usr/bin/env": "env",
        "/usr/bin/printf": "printf",
        "/usr/sbin/openssl": "openssl",
    }
    paths = {name: tools.get(name) or shutil.which(name) for name in names.values()}
    assert all(paths.values()), "Actual native package verification tools are required"
    if shell[1:] == ["ash"]:
        applets = jffs.parent / "native-entry-applets"
        applets.mkdir(exist_ok=True)
        vendor = Path(tools["sh"]).resolve(strict=True)
        for name in names.values():
            if name == "openssl":
                continue
            target = applets / name
            if not target.exists():
                target.symlink_to(vendor)
            paths[name] = str(target)
    text = text.replace("/jffs", str(jffs))
    # / is firmware-root-owned while isolated fixture descendants are user-owned.
    text = text.replace("$3!=0", f"($3!=0 && $3!={os.geteuid()})")
    for literal, name in names.items():
        text = text.replace(literal, str(paths[name]))
    shell_args = [] if shell[1:] == ["ash"] else shell[1:]
    return text.replace(" /bin/sh ", " " + shlex.join([tools["sh"], *shell_args]) + " ")


def finish_package(
    entry: Path,
    support: Path,
    tools: dict[str, str],
    shell: list[str],
    *,
    adapt: bool = False,
) -> None:
    """Regenerate real catalog/hash records after every consumer fixture edit."""
    complete_modules(support)
    if adapt:
        entry.write_text(
            adapt_native(entry.read_text(), entry.parent.parent, tools, shell)
        )
        verifier = support / "modules/lib/package.sh"
        verifier.write_text(
            adapt_native(verifier.read_text(), entry.parent.parent, tools, shell)
        )
    entry.chmod(0o755)
    for item in (support / "modules").rglob("*"):
        if item.is_file() and item.stat().st_mode & 0o777 == 0o600:
            item.chmod(0o644)
    with tempfile.TemporaryDirectory(prefix="cfmgr-entry-metadata-") as directory:
        stage = Path(directory)
        shutil.copy2(entry, stage / "cfmgr.sh")
        shutil.copytree(support / "modules", stage / "modules")
        catalog = stage / "catalog.txt"
        catalog.write_bytes(package_builder.catalog(stage))
        catalog.chmod(0o644)
        manifest = package_builder.manifest(stage)
        (support / "catalog.txt").write_bytes(catalog.read_bytes())
        (support / "manifest.txt").write_bytes(manifest)
    for name in ("catalog.txt", "manifest.txt"):
        (support / name).chmod(0o644)


def health_path_adapter(text: str, paths: dict[str, str]) -> str:
    """Translate firmware namespaces once, including AWK escaped path literals.

    This is a firmware-shaped Linux fixture, not a mount/firmware qualification.
    Apply before native tool selection: a Homebrew /usr/local/opt path must never
    become a fixture Entware path. Keep real /proc supervision and FD paths.
    """
    import re

    replacements = dict(paths)
    replacements.update(
        {
            key.replace("/", r"\/"): value.replace("/", r"\/")
            for key, value in paths.items()
        }
    )
    pattern = "|".join(
        re.escape(key) for key in sorted(replacements, key=len, reverse=True)
    )
    return re.sub(pattern, lambda match: replacements[match.group()], text)


def full_health_package(
    entry: Path,
    support: Path,
    base: Path,
    tools: dict[str, str],
    shell: list[str],
    schema2: bytes,
) -> dict[str, Path | tuple[str, ...]]:
    """Build one full entry journey with real Linux supervision and descriptors.

    Only fixture copies are translated. Firmware mountinfo/blkid, NVRAM,
    account ownership and daemon process observations are explicitly synthetic;
    inode/type/size, private parsers, FD attachment, reservation, clock, signals,
    reap and cleanup remain actual. Network is a strict executable boundary with
    private request/body/header FDs, never a live request or a health_get mock.
    The resulting package is rehashed only after every translation.
    """
    import base64
    import hashlib
    import sys

    from test_archive_payload import TUNNEL, advanced_config, serialize
    from test_prerequisites import pause_definition
    from test_status import HEALTH_SECRET, LIST, ZONE

    jffs = base / "jffs"
    selected_entry = jffs / "scripts/cfmgr.sh"
    selected_support = jffs / "addons/CFMgr.d"
    shutil.copytree(support, selected_support)
    selected_entry.parent.mkdir(parents=True)
    shutil.copy2(entry, selected_entry)
    mount = base / "mnt/usb"
    opt = mount / "entware"
    alias = base / "opt"
    opt.mkdir(parents=True)
    alias.symlink_to(opt, target_is_directory=True)
    ram = base / "ram"
    ram.mkdir()
    firmware = base / "firmware"
    firmware.mkdir()
    account = "b" * 32
    secret = "cloud-private-CANARY"
    canaries = (
        HEALTH_SECRET,
        secret,
        account,
        TUNNEL,
        "certificate-private-CANARY",
        "hook-private-CANARY",
    )
    value = advanced_config(schema2)
    value["storage"]["entware"].update(root="/", relative="entware")
    value["credentials"]["advanced"].update(account_tag=account, tunnel_secret=secret)
    value["credentials"]["cert"]["account_id"] = account
    value["credentials"]["api"] = {
        "schema": 1,
        "kind": "cloudflare_api_token",
        "value": HEALTH_SECRET,
    }
    value["ddns"].update(
        configured=True,
        enabled=True,
        credential_ref="api",
        zone_id=ZONE,
        primary_hostname="example.test",
        ttl={"mode": "auto"},
        proxied=True,
        records=[
            {"id": "record-a", "name": "example.test", "type": "A"},
            {"id": "record-b", "name": "*.example.test", "type": "AAAA"},
            {"id": "record-c", "name": "third.example.test", "type": "A"},
        ],
    )
    value["ip_sync"].update(
        configured=True,
        enabled=True,
        credential_ref="api",
        account_id=account,
        targets=[
            {"role": "primary", "id": LIST, "name": "owned-list", "families": ["ipv4"]},
            {
                "role": "secondary",
                "id": "d" * 32,
                "name": "second-list",
                "families": ["ipv6"],
            },
        ],
    )
    value["cloudflared"].update(
        enabled=True, expected_identity={"account_id": account, "tunnel_id": TUNNEL}
    )
    value["cloudflared"]["credential_refs"]["management"] = "api"
    value["network"]["selected_wan"] = 0
    paths = {
        "/jffs": str(jffs),
        "/opt": str(alias),
        "/rom": str(base / "rom"),
        "/tmp/mnt": str(base / "mnt"),
        "/var/spool/cron/crontabs": str(base / "var/spool/cron/crontabs"),
        "/usr/sbin/curl": str(base / "usr/sbin/curl"),
        "/usr/sbin/openssl": str(base / "usr/sbin/openssl"),
        "/usr/bin/flock": str(base / "usr/bin/flock"),
        "/usr/bin/hexdump": str(base / "usr/bin/hexdump"),
        "/bin/busybox": str(base / "bin/busybox"),
        "/bin/nvram": str(firmware / "nvram"),
        "/sbin/blkid": str(firmware / "blkid"),
    }

    def translate(text: str) -> str:
        return health_path_adapter(text, paths)

    def native(text: str) -> str:
        # Protect completed translations from adapt_native literal matching.
        saved = {
            f"__CFMGRFIXTUREPATH{i}__": path for i, path in enumerate(paths.values())
        }
        for token, path in sorted(
            saved.items(), key=lambda item: len(item[1]), reverse=True
        ):
            text = text.replace(path, token)
        text = adapt_native(text, jffs, tools, shell)
        for token, path in saved.items():
            text = text.replace(token, path)
        return text

    def write(logical: str, data: str | bytes, mode: int = 0o600) -> Path:
        target = Path(translate(logical))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data.encode() if isinstance(data, str) else data)
        target.chmod(mode)
        return target

    def forward(logical: str, executable: str) -> None:
        write(logical, f'#!{tools["sh"]}\nexec {shlex.quote(executable)} "$@"\n', 0o755)

    # Entware tools are regular files beneath the pinned attachment, not
    # symlinks escaping it. Their subprocess behavior is the actual host tool.
    for name in ("jq", "timeout", "sha256sum", "flock", "dig"):
        executable = tools.get(name) or shutil.which(name)
        assert executable, f"Actual {name} is required for the full health journey"
        forward("/opt/bin/" + name, executable)
    forward("/usr/sbin/openssl", str(Path(shutil.which("openssl")).resolve()))
    forward("/usr/bin/flock", str(Path(shutil.which("flock")).resolve()))
    hexdump = shutil.which("hexdump")
    busybox = shutil.which(shell[0] if shell[1:] == ["ash"] else "busybox")
    assert hexdump and busybox, (
        "Native hex and BusyBox observation fixtures are required"
    )
    forward("/usr/bin/hexdump", str(Path(hexdump).resolve()))
    write("/bin/busybox", Path(busybox).resolve().read_bytes(), 0o755)
    ca = Path("/etc/ssl/certs/ca-certificates.crt")
    assert ca.is_file(), "Linux CI native CA bundle is required"
    write("/rom/etc/ssl/certs/ca-certificates.crt", ca.read_bytes(), 0o644)
    write(
        "/bin/nvram",
        '#!/bin/sh\n[ "$1" = get ] || exit 2\ncase $2 in\n'
        "http_username) echo root ;; ntp_ready|wan0_primary) echo 1 ;; wan1_primary) echo 0 ;; "
        "wan0_proto) echo dhcp ;; wan0_ifname) echo eth0 ;; wan0_ipaddr) echo 8.8.8.8 ;; "
        "productid) echo GT-AX11000 ;; firmver) echo 3004 ;; buildno) echo 388 ;; "
        "extendno) echo fixture ;; *) exit 1 ;; esac\n",
        0o755,
    )
    uuid = value["storage"]["entware"]["uuid"]
    write(
        "/sbin/blkid",
        f'#!/bin/sh\n[ "$#" = 1 ] && [ "$1" = /dev/cfmgr-fixture ] || exit 2\nprintf \'%s\\n\' \'/dev/cfmgr-fixture: UUID="{uuid}" TYPE="ext4"\'\n',
        0o755,
    )
    (firmware / "mountinfo").write_text(
        f"1 99 0:1 / / rw - rootfs rootfs rw\n"
        f"2 1 0:2 / {ram} rw - tmpfs tmpfs rw\n"
        f"3 1 0:3 / {jffs} rw - jffs2 jffs rw\n"
        f"4 1 8:1 / {mount} rw - ext4 /dev/cfmgr-fixture rw\n"
    )
    (firmware / "if_inet6").write_text(
        "26064700470000000000000000001111 02 40 00 00 eth0\n"
    )
    credential = write(
        "/opt/etc/cloudflared/credentials.json",
        serialize({"AccountTag": account, "TunnelID": TUNNEL, "TunnelSecret": secret}),
    )
    certificate_data = base64.b64encode(
        serialize(
            {"zoneID": "fixture-zone", "accountID": account, "apiToken": canaries[4]}
        )
    )
    pem = (
        b"-----BEGIN ARGO TUNNEL TOKEN-----\n"
        + b"\n".join(
            certificate_data[i : i + 64] for i in range(0, len(certificate_data), 64)
        )
        + b"\n-----END ARGO TUNNEL TOKEN-----\n"
    )
    certificate = write("/opt/etc/cloudflared/cert.pem", pem)
    recovery = write("/jffs/addons/CFMgr.d/cert.pem", pem)
    dependency = write("/opt/etc/cloudflared/ca.pem", b"fixture immutable CA input\n")
    yaml = write(
        "/opt/etc/cloudflared/config.yml",
        translate(
            f"tunnel: {TUNNEL}\ncredentials-file: '/opt/etc/cloudflared/credentials.json'\n"
            "cacert: '/opt/etc/cloudflared/ca.pem'\n"
        ),
    )
    binary = write(
        "/opt/bin/cloudflared", "#!/bin/sh\necho MUST_NOT_EXECUTE\nexit 98\n", 0o755
    )
    value["cloudflared"]["paths"] = {
        "yaml": str(yaml),
        "json": str(credential),
        "certificate": str(certificate),
    }
    value["credentials"]["cert"].update(
        path=str(certificate),
        recovery_path=str(recovery),
        sha256=hashlib.sha256(pem).hexdigest(),
    )
    value["ownership"]["components"] = [
        {
            "schema": 1,
            "component": "cloudflared"
            if role == "binary"
            else "data.cloudflared." + role,
            "path": str(path),
            "generation": 1,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        for role, path in {
            "yaml": yaml,
            "json": credential,
            "certificate": certificate,
            "certificate-recovery": recovery,
            "binary": binary,
            "input.ca_bundle": dependency,
        }.items()
    ]
    from test_archive_history import GLOBAL, RULE

    write(
        "/jffs/scripts/scribe",
        '#!/bin/sh\nreadonly scribe_ver="v3.2.12"\nreadonly scriptVer_TAG="26041123"\n',
        0o755,
    )
    write(
        "/jffs/addons/scribe.d/config",
        "SYSLOG_LOC=/tmp/syslog.log\nLR_CRONJOB_HOUR=3\n",
    )
    (opt / "bin/scribe").symlink_to(jffs / "scripts/scribe")
    write(
        "/opt/etc/syslog-ng.conf",
        translate('@version: 4.7\n@include "/opt/etc/syslog-ng.d/"\n'),
    )
    (opt / "etc/syslog-ng.d").mkdir()
    write("/opt/etc/logrotate.conf", translate("include /opt/etc/logrotate.d\n"))
    write("/opt/etc/logrotate.d/A01global", GLOBAL)
    write(
        "/opt/etc/logrotate.d/messages",
        translate("/opt/var/log/messages {\n size 4M\n}\n"),
    )
    debug = (
        "warning: logrotate in debug mode does nothing except printing debug messages!  "
        "Consider using verbose mode (-v) instead if this is not what you want.\n\n"
        "reading config file "
        + str(alias / "etc/logrotate.conf")
        + "\nincluding "
        + str(alias / "etc/logrotate.d")
        + "\nreading config file A01global\n"
    )
    for feature in ("ddns", "ip_sync", "cloudflared"):
        name = "ip-sync" if feature == "ip_sync" else feature
        rule = RULE.replace("ddns", name)
        if feature == "cloudflared":
            rule = (
                rule.replace("size 7M", "daily")
                .replace("maxsize 0", "maxsize 10M")
                .replace("rotate 2", "rotate 4")
                .replace("maxage 0", "maxage 30")
            )
        rule_path = write("/opt/etc/logrotate.d/cfmgr-" + name, translate(rule))
        log_path = write(
            "/opt/var/log/" + name + ".log", "[CFMGR] fixture: info: retained history\n"
        )
        write("/opt/var/log/" + name + ".log.1", "older retained history\n")
        value["logging"][feature].update(configured=True, enabled=True, opt_out=False)
        if feature == "cloudflared":
            value["logging"][feature]["policy"] = {
                "schema": 1,
                "mode": "daily",
                "size": {"value": 10, "unit": "MiB"},
                "total_files": 5,
                "max_age_days": 30,
            }
        else:
            value["logging"][feature]["policy"] = {"schema": 1, "version": 1}
        for component, path in (
            ("history." + feature, log_path),
            ("history-rule." + feature, rule_path),
        ):
            value["ownership"]["components"].append(
                {
                    "schema": 1,
                    "component": component,
                    "path": str(path),
                    "generation": 1,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            )
        debug += "reading config file cfmgr-" + name + "\n"
    debug += "reading config file messages\n"
    (firmware / "rotate-debug").write_text(debug)
    write(
        "/opt/sbin/syslog-ng",
        '#!/bin/sh\ncase "$#:$1" in 1:--version) echo "syslog-ng 4.7.1" ;; 3:--syntax-only) [ "$2" = -f ] && [ "$3" = '
        + shlex.quote(str(alias / "etc/syslog-ng.conf"))
        + " ] ;; *) exit 42 ;; esac\n",
        0o755,
    )
    write(
        "/opt/sbin/logrotate",
        '#!/bin/sh\ncase "$#:$1" in 1:--version) echo "logrotate 3.22.0" ;; 2:-d) [ "$2" = '
        + shlex.quote(str(alias / "etc/logrotate.conf"))
        + " ] || exit 42; /bin/cat "
        + shlex.quote(str(firmware / "rotate-debug"))
        + " >&2 ;; *) exit 42 ;; esac\n",
        0o755,
    )
    write(
        "/var/spool/cron/crontabs/root",
        translate(
            "SHELL=/bin/sh\n"
            "5 */3 * * * /jffs/scripts/scribe LogRotate #scribeLogRotate#\n"
            "* * * * * /jffs/scripts/cfmgr.sh hook-private-CANARY #CFMgrWatchdog#\n"
            "37 3 * * * /jffs/scripts/cfmgr.sh hook-private-CANARY #CFMgrCloudflaredUpdate#\n"
        ),
    )
    # Generic ownership records are fixture facts only. The health report must
    # not infer managed-block or dispatch authority from these matching bytes.
    for hook in (
        "services-start",
        "wan-event",
        "dhcpc-event",
        "ddns-start",
        "post-mount",
        "unmount",
        "services-stop",
    ):
        hook_path = write(
            "/jffs/scripts/" + hook,
            "#!/bin/sh\n# hook-private-CANARY\nexit 98\n",
            0o755,
        )
        value["ownership"]["components"].append(
            {
                "schema": 1,
                "component": "hook." + hook,
                "path": str(hook_path),
                "generation": 1,
                "sha256": hashlib.sha256(hook_path.read_bytes()).hexdigest(),
            }
        )
    process = firmware / "daemon-facts"
    for pid, comm, start, exe, argv in (
        (
            123,
            "syslog-ng",
            4000,
            opt / "sbin/syslog-ng",
            [str(alias / "sbin/syslog-ng")],
        ),
        (
            124,
            "crond",
            4001,
            base / "bin/busybox",
            ["crond", "-c", str(base / "var/spool/cron/crontabs")],
        ),
    ):
        facts = process / str(pid)
        facts.mkdir(parents=True)
        (facts / "stat").write_text(f"{pid} ({comm}) S " + "0 " * 18 + f"{start} 0\n")
        (facts / "exe").symlink_to(exe)
        (facts / "cmdline").write_bytes(
            b"\0".join(item.encode() for item in argv) + b"\0"
        )
    backup = mount / "CFBackup"
    backup.mkdir()
    value["backup"]["destination"] = {
        "schema": 1,
        "mountpoint": str(mount),
        "uuid": uuid,
        "filesystem": "ext4",
        "root": "/",
    }
    # Capture only numeric/mode sidechannels. No request, identifier or secret
    # enters test diagnostics, launch arguments, or the public health report.
    audit = base / "audit"
    audit.mkdir()
    status_tail = r"""
cfmgr_health_cleanup() {
    cfmgr_prerequisites_now || return 1
    printf '%s %s %s %s %s %s %s %s %s %s\n' "$cfmgr_health_operations" "$cfmgr_health_files" "$cfmgr_health_bytes" "$cfmgr_health_requests" "$cfmgr_health_rows" "$cfmgr_health_final_operations" "$cfmgr_health_final_files" "$cfmgr_health_final_bytes" "$((cfmgr_probe_now - cfmgr_health_deadline + 45))" "${cfmgr_health_reason:-normal}" >@AUDIT@/ledger
    printf '%s\n' "$cfmgr_status_context" >@AUDIT@/context
    /bin/cat "$cfmgr_health_row_file" >@AUDIT@/rows
    cfmgr_health_actual_cleanup "$@"
}
""".replace("@AUDIT@", shlex.quote(str(audit)))
    execution_tail = r"""
cfmgr_prerequisites_run() {
    cfmgr_fixture_mode=$1
    cfmgr_fixture_before_bytes=${cfmgr_health_bytes:-0}
    cfmgr_fixture_actual_run "$@"
    cfmgr_fixture_result=$?
    printf '%s %s %s %s %s %s\n' "$cfmgr_fixture_mode" "$cfmgr_fixture_result" "${cfmgr_probe_exit:-none}" "${cfmgr_probe_pid:-none}" "$((${cfmgr_health_bytes:-0} - cfmgr_fixture_before_bytes))" "${cfmgr_health_bytes:-0}" >>@AUDIT@/routes
    return "$cfmgr_fixture_result"
}
""".replace("@AUDIT@", shlex.quote(str(audit)))
    inventory = []
    for source in (ROOT / "modules").rglob("*"):
        if not source.is_file() or source.name == ".DS_Store":
            continue
        relative = source.relative_to(ROOT)
        original = source.read_text()
        text = translate(original)
        if relative.as_posix() == "modules/status.sh":
            # /tmp is represented by owned RAM only in context preparation;
            # actual /proc process identity and all attachment functions survive.
            start = text.index("cfmgr_status_prepare() {")
            end = text.index("\ncfmgr_status_native()", start)
            text = text[:start] + text[start:end].replace("/tmp", str(ram)) + text[end:]
            text = text.replace("/proc/net/if_inet6", str(firmware / "if_inet6"))
            text = (
                text.replace(
                    "cfmgr_health_cleanup() {", "cfmgr_health_actual_cleanup() {", 1
                )
                + status_tail
            )
            if "cfmgr_health_log_stat() {" in text:
                observer_start = text.index("cfmgr_health_log_stat() {")
                observer_end = text.index(
                    "cfmgr_health_log_cron_boundary()", observer_start
                )
                text = (
                    text[:observer_start]
                    + text[observer_start:observer_end].replace(
                        "/proc/", str(process) + "/"
                    )
                    + text[observer_end:]
                )
            text = text.replace(
                b"/opt/sbin/syslog-ng".hex(),
                str(alias / "sbin/syslog-ng").encode().hex(),
            )
            text = text.replace(
                b"/var/spool/cron/crontabs".hex(),
                str(base / "var/spool/cron/crontabs").encode().hex(),
            )
            # Only the cron metadata exception has a standalone /var anchor.
            text = text.replace('modes["/var"]', f'modes["{base}/var"]').replace(
                'p!="/var"', f'p!="{base}/var"'
            )
            # Fixed native inventory uses fixture parents with genuine metadata.
            text = text.replace('hm_add("/usr",', f'hm_add("{base}/usr",')
            text = text.replace('hm_add("/usr/sbin",', f'hm_add("{base}/usr/sbin",')
            text = text.replace('hm_add("/usr/bin",', f'hm_add("{base}/usr/bin",')
        if relative.as_posix() == "modules/helpers/worker.sh":
            text = text.replace("set -- /usr/bin ", f"set -- {base}/usr/bin ")
            text = text.replace(" / /usr /usr/sbin ", f" / {base}/usr {base}/usr/sbin ")
            text = text.replace(
                b"/opt/sbin/syslog-ng".hex(),
                str(alias / "sbin/syslog-ng").encode().hex(),
            )
            text = text.replace("dir=/proc maximum=4096", f"dir={process} maximum=4096")
            block = text.index("\nblkid)\n")
            block_end = text.index("\n\t;;", block)
            # Device identity is an explicit unmounted fixture fact. No host
            # device is probed and no block node or mount is created.
            text = (
                text[:block]
                + text[block:block_end].replace(
                    '[ -b "$1" ]', '[ "$1" = /dev/cfmgr-fixture ]'
                )
                + text[block_end:]
            )
        if relative.as_posix() == "modules/lib/config.sh":
            text = text.replace(
                "substr(point, 1, 9)", f"substr(point, 1, {len(str(base / 'mnt')) + 1})"
            )
        if relative.as_posix() == "modules/lib/execution.sh":
            text = text.replace(
                "cfmgr_prerequisites_run() {", "cfmgr_fixture_actual_run() {", 1
            )
            text += "\n" + pause_definition(shell) + "\n" + execution_tail
        if relative.as_posix() == "modules/backup.sh":
            text = text.replace(
                "substr(base,1,5)", f"substr(base,1,{len(str(alias)) + 1})"
            )
        text = text.replace("/proc/self/mountinfo", str(firmware / "mountinfo"))
        # The metadata executable below labels fixture ownership only; parser
        # requirements continue to demand root and protected ancestors.
        text = text.replace("/bin/ls", str(firmware / "ls"))
        text = native(text)
        target = selected_support / relative
        target.write_text(text)
        inventory.append(
            f"{relative} {hashlib.sha256(original.encode()).hexdigest()} {hashlib.sha256(text.encode()).hexdigest()}"
        )
    selected_entry.write_text(
        native(translate((ROOT / "cfmgr.sh").read_text())).replace(
            "/bin/ls", str(firmware / "ls")
        )
    )
    (audit / "transformations").write_text("\n".join(inventory) + "\n")
    (selected_support / "config").write_bytes(serialize(value))
    (selected_support / "config").chmod(0o600)
    curl = (
        "#!"
        + str(Path(sys.executable).resolve())
        + "\n"
        + HEALTH_CURL.replace("@BASE@", repr(str(base)))
        .replace("@TOKEN@", HEALTH_SECRET)
        .replace("@TUNNEL@", repr(TUNNEL))
    )
    write("/usr/sbin/curl", curl, 0o755)
    metadata = (
        "#!"
        + str(Path(sys.executable).resolve())
        + "\n"
        + HEALTH_METADATA.replace("@BASE@", repr(str(base)))
    )
    (firmware / "ls").write_text(metadata)
    (firmware / "ls").chmod(0o755)
    finish_package(selected_entry, selected_support, tools, shell)
    return {
        "entry": selected_entry,
        "support": selected_support,
        "base": base,
        "audit": audit,
        "ram": ram,
        "opt": opt,
        "alias": alias,
        "canaries": canaries,
    }


# This executable is the HTTP boundary only. It never imports networking code or
# opens a socket; unexpected argv, FDs, authority, URL or request framing fails.
HEALTH_CURL = r"""
import json, os, sys
from pathlib import Path
from urllib.parse import parse_qs, urlsplit
base = Path(@BASE@)
audit = base / 'audit'
a = sys.argv[1:]
if a == ['-q', '-V']:
    print('curl 8.0.0 fixture\nProtocols: https\nFeatures: SSL')
    sys.exit(0)
ca = str(base / 'rom/etc/ssl/certs/ca-certificates.crt')
common = ['-q', '--silent', '--show-error', '--proto', '=https', '--proto-redir', '=https',
          '--tlsv1.2', '--cacert', ca, '--capath']
if '--head' in a:
    context = a[a.index('--capath') + 1]
    expected = common + [context, '--proxy', '', '--noproxy', '*', '--connect-timeout', '1',
        '--max-time', '1', '--head', '--output', '/dev/null', '--write-out', '%{http_code}\\n',
        '--url', 'http://127.0.0.1:9/']
    assert a == expected
    print('000')
    sys.exit(1)
assert a[:7] == ['-q', '--silent', '--show-error', '--globoff', '--request', 'GET', a[6]]
assert a[6] in ['--ipv4', '--ipv6']
context = a[a.index('--capath') + 1]
expected = ['-q', '--silent', '--show-error', '--globoff', '--request', 'GET', a[6],
    '--proto', '=https', '--proto-redir', '=https', '--tlsv1.2', '--cacert', ca, '--capath', context,
    '--proxy', '', '--noproxy', '*', '--max-redirs', '0', '--retry', '0', '--connect-timeout', '1',
    '--max-time', '3', '--max-filesize', '32768', '--output', '/proc/self/fd/8',
    '--dump-header', '/proc/self/fd/7', '--write-out', '%{http_code}\\n', '--config', '/proc/self/fd/6']
assert a == expected
assert Path(context).is_dir() and Path(context).parent == base / 'ram'
request = Path('/proc/self/fd/6').read_text()
lines = request.splitlines()
assert len(lines) in [1, 2] and lines[0].startswith('url = "') and lines[0].endswith('"')
url = lines[0][7:-1]
u = urlsplit(url)
assert u.scheme == 'https' and not u.fragment and not u.username
if u.hostname == 'cloudflare.com':
    assert u.path == '/cdn-cgi/trace' and not u.query and len(lines) == 1
    kind = 'trace6' if a[6] == '--ipv6' else 'trace4'
    body = 'ip=' + ('2606:4700:4700::1111' if kind == 'trace6' else '8.8.8.8') + '\n'
else:
    assert u.hostname == 'api.cloudflare.com' and len(lines) == 2
    assert lines[1] == 'header = "Authorization: Bearer @TOKEN@"'
    segments = u.path.split('/')[3:]
    query = parse_qs(u.query)
    result_info = None
    if segments[0] == 'zones':
        assert segments[1] == 'a' * 32
        if len(segments) == 2:
            kind = 'zone'; result = {'id': segments[1]}
        else:
            assert segments[2] == 'dns_records' and len(segments) == 3
            name = query['name'][0]; family = query['type'][0]
            assert (name, family) in [('example.test','A'), ('*.example.test','AAAA'), ('third.example.test','A')]
            kind = 'dns'; result = [{'id': 'e' * 32, 'name': name, 'type': family,
                'content': '2606:4700:4700::1111' if family == 'AAAA' else '8.8.8.8', 'ttl': 1, 'proxied': True}]
            result_info = {'page': 1, 'total_pages': 1, 'count': 1, 'total_count': 1}
    elif segments[:1] == ['accounts']:
        assert segments[1] == 'b' * 32
        if segments[2:4] == ['rules','lists']:
            assert segments[4] in ['c' * 32, 'd' * 32]
            if len(segments) == 5:
                kind = 'list'; result = {'id': segments[4], 'kind': 'ip',
                    'name': 'owned-list' if segments[4] == 'c' * 32 else 'second-list'}
            else:
                assert len(segments) == 6 and segments[5] == 'items'
                kind = 'items'; result = [{'id': 'e' * 32, 'ip': '8.8.8.8' if segments[4] == 'c' * 32 else '2606:4700:4700::1111'}]
                result_info = {'cursors': {'before': '', 'after': ''}}
        else:
            assert segments[2] == 'cfd_tunnel' and segments[3] == @TUNNEL@
            if len(segments) == 4:
                kind = 'tunnel'; result = {'id': segments[3]}
            else:
                assert segments[4:] == ['connections']
                kind = 'connections'; result = [{'id': @TUNNEL@}]
    else:
        raise AssertionError('unexpected provider route')
    response = {'success': True, 'errors': [], 'result': result}
    if result_info is not None: response['result_info'] = result_info
    body = json.dumps(response, separators=(',', ':'))
with (audit / 'requests').open('a') as record: record.write(kind + '\n')
with (audit / 'network-environment').open('a') as record:
    for key, value in sorted(os.environ.items()): record.write(key + '=' + value + '\n')
os.write(8, body.encode())
os.write(7, b'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n')
print('200')
"""


HEALTH_METADATA = r"""
import os, stat, subprocess, sys
from pathlib import Path
base = Path(@BASE@)
args = sys.argv[1:]
options = ''.join(value[1:] for value in args if value.startswith('-'))
if 'l' not in options:
    os.execv('/bin/ls', ['/bin/ls', *args])
failed = False
for value in args:
    if value.startswith('-'): continue
    path = Path(value)
    try:
        info = path.stat() if 'L' in options else path.lstat()
    except OSError:
        print('fixture ls: metadata unavailable', file=sys.stderr)
        failed = True
        continue
    mode = stat.filemode(info.st_mode)
    # /tmp is the fixture's unavoidable writable host ancestor. No filesystem
    # permission is changed; all other mode/type/inode/size facts remain actual.
    if path == Path('/tmp'): mode = 'drwxr-xr-x'
    uid = 0 if info.st_uid in (0, os.geteuid()) else info.st_uid
    name = value
    if stat.S_ISLNK(info.st_mode): name += ' -> ' + os.readlink(path)
    inode = str(info.st_ino) + ' ' if 'i' in options else ''
    print(f'{inode}{mode} {info.st_nlink} {uid} {info.st_gid} {info.st_size} Jan 1 00:00 {name}')
sys.exit(1 if failed else 0)
"""
