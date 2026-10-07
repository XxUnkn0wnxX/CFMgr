# CFMgr implementation plan and handoff

Cloudflare Manager for Asuswrt-Merlin. This document is the working specification, build checklist, and handoff record.

| Project state | Current position |
| --- | --- |
| Stage | Planning; no manager implementation or router deployment yet. |
| Last source review | 2026-10-08. |
| Development branch | `develop`; promote reviewed releases to `main`. |
| Repository baseline | `594055d` — initial project scaffold. |
| Authoritative reference | The supplied `cloudflared/setup/` snapshot, including both `jffs/scripts/` and `opt/etc/cloudflared/`. In the original workspace it is at `../../cloudflared/setup/` relative to this checkout. |
| Additional logging evidence | Separate captured router `jffs/` files, especially Scribe and `post-mount`. These supplement the reference; they are not a fresh live-router inspection. |
| Evidence boundary | Existing behavior below is verified from source. Current router mounts, running services, cron state, remote tunnel configuration, and active rotation policies still need verification before migration. |
| Next stage | Settle the configuration/dependency choices and capture the missing logging/storage evidence. Implementation starts only when requested. |

**Status convention:** `Done` means the stated planning work is complete. `Pending` means implementation or validation remains. `Proposed` means a design/default to settle during the relevant phase. A completed source audit does not mark a runtime test complete.

## Contents

- [Requirements](#requirements)
- [Current setup inventory](#current-setup-inventory)
- [Hooks and schedules](#hooks-and-schedules)
- [Installation layout and Entware checks](#installation-layout-and-entware-checks)
- [Configuration and setup wizard](#configuration-and-setup-wizard)
- [Service lifecycle, updates, DDNS, and Access](#service-lifecycle-updates-ddns-and-access)
- [Scribe logging and rotation](#scribe-logging-and-rotation)
- [Backup and restore](#backup-and-restore)
- [Install, migration, repair, and uninstall](#install-migration-repair-and-uninstall)
- [Build checklist](#build-checklist)
- [Validation matrix](#validation-matrix)
- [Decisions and missing evidence](#decisions-and-missing-evidence)
- [Handoff record](#handoff-record)
- [References](#references)

## Requirements

| ID | Required outcome | Completion evidence |
| --- | --- | --- |
| R01 | One installable CFMgr entry point and menu for setup, services, updates, status, backup, restore, repair, and uninstall. | A clean supported Merlin installation can use the published package without assembling the old scripts manually. |
| R02 | Support the capabilities of the supplied setup, while allowing cleaner internal organization. | Each inventory row below has an implemented equivalent and a parity check. |
| R03 | Configuration-driven DDNS, tunnel, Access IP publishing, logging, and backup settings. | No account-specific values in code; versioned configuration can be exported and restored. |
| R04 | Prompt only for credentials/settings needed by the selected features. | DDNS-only, tunnel-only, Access-only, and combined setup paths have separate tested requirements. |
| R05 | Install/configure `cloudflared`, import existing tunnels, and create a tunnel through supported Cloudflare APIs. | Validated import plus a tested create/connect workflow with the correct credential type. |
| R06 | Preserve automatic updates, watchdog recovery, readiness checks, bounded stop, and interrupted-update rollback. | Lifecycle/concurrency tests and authorized router validation. |
| R07 | Preserve Cloudflare A-record updates and optional AAAA updates, including Merlin DDNS completion reporting. | Multiple-record, IP-source, IPv6, timeout, and failure cases pass. |
| R08 | Optional WAN public IPv4 publishing to a dedicated Cloudflare Zero Trust IP list. | Newest-request queue, retry, validation, unchanged-list, and readback behavior pass. |
| R09 | Integrate with boot, WAN, DDNS, and mount hooks without damaging other add-ons. | Idempotent hook edits, preserved unrelated content, and exactly one owned cron entry per task. |
| R10 | Require installed, mounted, writable Entware storage. | Missing/unmounted/read-only storage prevents installation and filesystem writes; interactive users receive Entware setup guidance. |
| R11 | Keep large/persistent files on the Entware drive. | Config, certificates, credentials, logs, backups, and staging resolve to the verified Entware filesystem. |
| R12 | Support logging and log rotation only when Scribe is installed and configured. | Without usable Scribe: no CFMgr file logging, syslog emission, or rotation rules; interactive status/errors remain available. |
| R13 | Provide a Scribe re-detect action that configures logging/rotation and restarts affected services when enabling it. | Transition tests cover absent, incomplete, ready, and later-unavailable Scribe. |
| R14 | Back up existing configuration before migration or replacement; include owned logs when Scribe is ready. | Verified pre-change archive and manifest exist before activation. |
| R15 | Support full manager backup/restore and a smaller configuration backup/restore. | Restore to the same router and a compatible replacement installation reconstructs owned services, settings, credentials, hooks, and eligible logs. |
| R16 | Protect credentials in configuration, command invocation, logs, diagnostics, and backups. | Private permissions, safe parsing, redacted diagnostics, and repository secret checks pass. |
| R17 | Support repair and clean removal of CFMgr-owned integrations. | Uninstall/repair leaves unrelated hooks, schedules, Entware, Scribe, and remote Cloudflare resources intact. |
| R18 | Keep this plan usable as a handoff during development. | Phase/checklist status, decisions, commits, validation evidence, and next actions are updated after each material package. |

## Current setup inventory

All paths in this table are relative to the supplied `cloudflared/setup/` reference. Real domains, IPs, IDs, tokens, credential contents, and certificate contents are intentionally omitted.

| Source | Current responsibility and evidence | CFMgr equivalent |
| --- | --- | --- |
| `jffs/scripts/services-start` | Lines 5–8 register watchdog, updater, daily DDNS, and Access retry jobs. Other lines start existing add-ons. | Managed schedule registration through a small owned hook block. |
| `jffs/scripts/wan-event` | Lines 3–9 start the tunnel in a detached worker after a 20-second settle delay for WAN unit `0` becoming `connected`; scMerlin still receives the event. | WAN handler using the shared lifecycle controller; preserve event forwarding. |
| `jffs/scripts/ddns-start` | Lines 63–138 resolve IPv4, launch the independent Access helper, update matching A/optional AAAA records, and report DNS success/failure. Initial settings are account-specific. | Configuration-driven DDNS handler and optional Access notification. |
| `jffs/scripts/cloudflared.sh` | Shared-helper entry point; default/start and restart commands take the lifecycle lock. Lines 40–52 check readiness before a restart stops the service. | `cfmgr start`, `restart`, and watchdog entry points. |
| `jffs/scripts/cloudflared-common.sh` | Paths at lines 9–16; readiness at 71–200; launch at 203–229; pending recovery at 233–397; bounded stop at 399–453; version handling follows. | One lifecycle implementation reused by all triggers. |
| `jffs/scripts/cloudflared-update.sh` | Official GitHub release lookup, fixed Linux ARM64 asset, version validation, staging, separate update lock, `.old` backup, pending marker, activation, and rollback. | Architecture-aware updater retaining these protections. |
| `jffs/scripts/cloudflare-access-ip.py` | Private JSON settings, public-IPv4 validation, list identity/type checks, newest-request queue, independent retries, and verified list writes. | Optional Access module retaining the behavior even if its language changes. |
| `jffs/scripts/cloudflare-access-ip.json` | Enabled flag and account/list identity plus token settings. This supplied file is enabled; values are private. | Import into private external configuration; new installs keep unconfigured features disabled. |
| `opt/etc/cloudflared/config.yml` | Tunnel reference, credential-file path, origin-certificate path, and one `http_status` ingress entry. | Import the complete configuration without inventing application routes. |
| `opt/etc/cloudflared/<tunnel-id>.json` | Tunnel credentials with `AccountTag`, `TunnelSecret`, and `TunnelID` fields. | Private tunnel credentials on Entware storage. |
| `opt/etc/cloudflared/cert.pem` | Existing account certificate referenced by the YAML configuration. | Preserve on import; require it only for workflows that actually use certificate-based administration. |
| The two script READMEs | Existing behavior, deployment grouping, permissions, schedules, and operator checks. | Use as parity evidence; move public operating documentation into `docs/` as implemented. |

The file layout alone does not establish the remote tunnel's `config_src` or its actual published applications. Import must determine the management mode and preserve existing remote/local routing rather than replacing it with guessed wizard output.

### Source fingerprints

These SHA-256 values identify the reviewed non-credential helper/hook files. Re-audit changed source before importing it. Fingerprints and contents of private configuration/certificates are not published here; the secret-bearing DDNS script is also excluded from this table.

| Source under `jffs/scripts/` | SHA-256 |
| --- | --- |
| `cloudflared-common.sh` | `7818f2bd3e579c7dbda1da9790f5bf5718a086f027dcce7ed138670c4ff12c5f` |
| `cloudflared-update.sh` | `a99f20993611b4698a4fc39bd53b07cc650d8ff8433bcfcae36ffa97eb59ff24` |
| `cloudflared.sh` | `d5ab3b144e78054a030f91faf046c72e8001b4d5136d533b04d391399acf1f02` |
| `cloudflare-access-ip.py` | `9f15128a52767e29628bb71d6f432d4903d35c5f8b0362b83d0e8b7f51435598` |
| `services-start` | `b28c087f7ba7f645ea5e9c3f52e8ff2a810a2c230a6971eefe4f57c52999226c` |
| `wan-event` | `8fd37fdb059fc5bdfe02a917a343fbadbdac465705112aa556863df7eb6f861d` |

## Hooks and schedules

The existing integration has several entry points, but they must share one controller. Merlin documents the boot, WAN, DDNS, mount, and unmount hooks in its [user-script reference](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts).

| Hook/trigger | Current setup | Planned integration and preservation rule |
| --- | --- | --- |
| `services-start` | Registers the four Cloudflare jobs; also invokes YazDHCP, scMerlin/tailtaintdns, amtm history, BackupMon, and MerlinAU. | Add one marked CFMgr block for idempotent registration and a detached ready-start request. Preserve all unrelated entries. Do not perform slow API/download work in the hook. |
| `wan-event` | Unit `0`/`connected`, detached 20-second delay, then shared start; scMerlin receives the original arguments. | Preserve this baseline/default with configurable WAN selection/settle policy. Pass the event arguments intact to other add-ons. Readiness still decides whether startup can proceed. |
| `ddns-start` | Owns the custom Cloudflare DNS update and firmware completion; asynchronously notifies Access with the same IPv4. | Exactly one DDNS completion owner. Migrate recognized legacy CF provider code instead of appending a second updater. Unknown/custom hook content requires a reviewed integration path. |
| Access-only DDNS observation | Not separately configured in the reference. | When CFMgr DNS is disabled, preserve the existing provider and observe the IP event for Access; do not report another provider's DDNS result. Use the configured IP-source policy. |
| `post-mount` | Outside the primary reference: captured amtm/Entware mounting and other add-ons, including Scribe rotation registration. | Proposed small detached CFMgr readiness/start request after Entware is available; preserve the existing mount helpers and Scribe scheduler. |
| `unmount` / `services-stop` | No CFMgr entries in the supplied reference. | Proposed bounded stop for the owned tunnel before its Entware volume disappears or services shut down. Match the actual Entware mount; keep hook duration bounded. |
| Watchdog/manual/update/restore | Existing watchdog, manual restart, and updater converge on shared lifecycle helpers. | All future service transitions use the same locks/readiness/stop/start implementation. |

Use marked `CFMgr BEGIN` / `CFMgr END` blocks and an ownership manifest. Re-running install/repair must not duplicate blocks. Uninstall removes only owned blocks. Compare the hook again before atomic replacement so concurrent edits are not discarded. Preserve executable mode and valid POSIX shell syntax.

| Current job | Current schedule (router local time) | Proposed CFMgr job | Activation rule |
| --- | --- | --- | --- |
| `Cloudflared` | `* * * * *` | `CFMgrWatchdog` | Tunnel enabled. |
| `CloudflaredUpdate` | `37 3 * * *` | `CFMgrCloudflaredUpdate` | Tunnel enabled and automatic binary updates enabled. |
| `UpdateDDNS` | `0 0 * * *` | `CFMgrDDNS` | CFMgr DDNS enabled; manual execution uses the configured IP source. |
| `CloudflareAccessIP` | `*/5 * * * *` | `CFMgrAccessRetry` | Access IP publishing enabled; no pending work means no API call. |
| `scribeLogRotate` (supplemental snapshot) | `5 0 * * *` | Keep Scribe's existing job | Scribe owns its own rotation schedule. CFMgr adds a policy, not another rotation cron. |
| No manager-specific backup job | None in primary reference | `CFMgrBackup` — proposed `15 4 * * *` | Only if automatic backups are selected; full/config choice and retention are configurable. |

Remove old Cloudflare jobs only after their commands/ownership are recognized and the new configuration is committed. In particular, the generic name `UpdateDDNS` alone is insufficient proof of ownership. Never remove BackupMon or unrelated jobs. Existing Cloudflare schedule defaults are retained unless explicitly changed in configuration.

## Installation layout and Entware checks

The preferred layout keeps the public command and small hook support in JFFS, with persistent data and larger files on the verified Entware drive. The current setup already uses `/opt/bin/cloudflared` and `/opt/etc/cloudflared`.

| Location | Proposed contents | Storage/permissions |
| --- | --- | --- |
| `/jffs/scripts/cfmgr` | Main menu/CLI entry point. | Small executable, mode `755`; POSIX `sh`. |
| `/jffs/addons/cfmgr/` | Optional private helper modules and non-secret integration/ownership metadata. | Small files only; no tunnel credentials or accumulated logs/backups. |
| `/opt/bin/cloudflared` | Installed binary, with protected `.old` and pending-update companion files. | Entware drive; executable validated for this router. |
| `/opt/etc/cloudflared/cfmgr.conf` | Versioned CFMgr settings. | Private file, mode `600`; private containing directory. |
| `/opt/etc/cloudflared/config.yml` | Local tunnel configuration when applicable. | Entware drive; import preserves existing settings. |
| `/opt/etc/cloudflared/credentials/` | Tunnel JSON, token files, API credentials, and imported account certificate as applicable. | Directory `700`, secret files `600`; normalize imported paths deliberately. |
| `/opt/var/lib/cfmgr/` | Persistent manager/install metadata and configuration transaction state. | Entware drive; no stale process locks stored here. |
| `/opt/var/log/cfmgr/` | Manager and tunnel logs plus their rotations. | Created/used only after Scribe detection/configuration succeeds. |
| `/opt/var/backups/cfmgr/` | Complete backup archives and verified pre-change/migration snapshots. | Private directory `700`; archives `600`. |
| `/opt/var/tmp/cfmgr/` | Download, restore, and archive staging. | Verified Entware drive; bounded cleanup of owned staging only. |
| `/tmp/cfmgr/` | Runtime locks, PIDs, readiness state, and transient Access queue. | Private RAM directory; recreate after reboot, never restore process locks. |
| `/opt/etc/syslog-ng.d/` and `/opt/etc/logrotate.d/` | Individually owned CFMgr fragments when Scribe is usable. | Preserve unrelated files/global configuration; validate before activation. |

`/opt` is the application-facing Entware namespace. Its physical target may be a mounted partition's `entware` directory; discover it rather than hardcoding a drive label. Bare `/etc` is not an approved fallback. A different data location must still resolve inside validated Entware storage. [Merlin's Entware guide](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Entware) documents installation through amtm.

### Required preflight

1. Confirm supported Merlin environment, root privileges, enabled JFFS user scripts, and required commands/capabilities.
2. Resolve the `/opt` symlink chain and identify its actual mount from the router's mount table. A directory named `/opt`, or a leftover symlink, is not enough.
3. Require executable `/opt/bin/opkg`, a usable Entware installation, and an actually mounted persistent filesystem. Confirm the target is the expected Entware volume, not rootfs/JFFS/tmpfs.
4. Check writable storage and sufficient space before creating directories, installing dependencies, downloading binaries, or extracting backups. Use a private write probe only after mount identity is established.
5. Recheck mount identity/writability before committing each filesystem transaction. Prevent fallback writes into a bare mountpoint if the disk disappears.
6. On an interactive missing-Entware failure, stop and explain how to install/mount Entware with amtm, then rerun setup. CFMgr will not install Entware, repartition, or format storage itself.
7. On a boot/cron hook, do not prompt or create substitute storage. Return/defer promptly; the next mount/WAN/watchdog trigger can retry. If CFMgr owns an enabled DDNS update that cannot run, report DDNS failure once rather than false success.
8. Keep stopped-by-user separate from waiting-for-storage/network; the watchdog must respect the user's disabled/stopped setting.

## Configuration and setup wizard

### Configuration contract

Use one authoritative external settings file and private referenced credential files. A versioned, safely parsed format is required; do not `eval` settings or source arbitrary user configuration as shell code. The exact serializer/parser is a Phase 1 decision.

| Group | Settings to support |
| --- | --- |
| General | Schema version, enabled modules, supported channel/version, WAN unit, Entware-derived paths, readiness/dependency settings. |
| DDNS | Zone identity, DNS credential reference, record names/IDs, IPv4 source policy, optional IPv6 source, TTL/proxy policy, timeout bounds, schedule. |
| Tunnel | Tunnel identity/name, management mode, config/credential/token paths, optional imported certificate, ingress/routing settings, startup/watchdog/settle controls. |
| Updates | Binary architecture/asset selection, update channel/schedule, download limits, rollback policy; manager updates kept distinct from binary updates. |
| Access | Enabled flag, account/list ID/name, credential reference, single-public-IPv4 policy, pending-request age, retry schedule. |
| Logging | Requested logging mode, detected Scribe readiness, output paths, levels, rotation frequency/size/retention; keep detected runtime status separate from user preference. |
| Backup | Destination, full/config selection, automatic schedule, retention/free-space reserve, log inclusion when Scribe is ready, protected snapshots. |
| Integration | Owned hook blocks/jobs, prior DDNS settings when changed, install/schema versions, migration provenance. |

Imported values stay private. Public examples use empty/placeholding values. Validate settings and write atomically before activation. Preserve unknown imported tunnel options where possible; do not rebuild an existing YAML file from a narrow template that silently drops them.

### Feature-specific inputs

| Selected action | Minimum user-supplied information | Credentials and lookup rules |
| --- | --- | --- |
| Cloudflare DDNS | Scoped DNS token, zone ID or selectable zone, record name(s), IP-source preference. | DNS edit/read as needed; zone enumeration may require additional read scope. Accept a supplied zone ID when enumeration is unavailable. |
| Import existing tunnel | Existing YAML and tunnel credentials, or an existing remote tunnel token. | Preserve existing local/remote settings. Import certificate only if present/needed; importing must not create a replacement tunnel. |
| Create new tunnel | Account identity/selection, tunnel name, scoped tunnel-management API token; hostname/origin inputs only if publishing applications. | Verify create/read permissions and management mode. DNS routing additionally needs the selected zone's DNS permission. |
| Connect existing remote tunnel | Tunnel token and any local connector runtime choices. | A connector token can run its tunnel; it is not a substitute for an API token that creates or administers tunnels. |
| Access IP publishing | Account and dedicated IP-list selection/identity plus suitable Zero Trust token. | Separate from DNS/tunnel credentials; permit shared token only when its verified scope covers the selected operations. |
| Logging and backup | Requested logging, backup location/schedule/retention choices. | No Cloudflare credential is needed merely to detect Scribe or back up local files. |

The [Tunnel creation API](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/methods/create/) supports `config_src` choices. Preserve the current file-based installation; decide the default for newly created tunnels explicitly. A scoped API token does not generate a browser-login account certificate. Cloudflare distinguishes account certificates from tunnel-specific credentials in its [tunnel permission documentation](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/tunnel-permissions/).

For remote-token mode, use a private token file where supported rather than exposing the token in process arguments; Cloudflare documents `--token-file` for versions `2025.4.0` and later. Keep `--no-autoupdate` under the shared updater's control. See [run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/).

### Wizard sequence

1. Run Entware/environment preflight and detect an existing CFMgr or legacy setup.
2. Offer import or new setup and select DDNS, tunnel, and/or Access independently.
3. Detect usable Scribe; keep logging unavailable until its requirements are met. Offer backup defaults.
4. Ask only for selected-feature inputs. Mask secret entry and omit secrets from the review screen.
5. Validate input and use bounded read-only API checks where possible. Resolve ambiguity by asking for the intended account/zone/list instead of guessing.
6. Show the intended resources, hook changes, storage paths, dependencies, and selected features before activation. Separate Cloudflare resource creation from local validation.
7. Save a verified pre-change backup, stage configuration/install files, and create only the selected remote resources. Record IDs of resources created by this setup attempt; preserve pre-existing resources on failure.
8. Activate owned hooks/jobs and start selected services after local validation. Report process state separately from tunnel connectivity and DNS/Access success.

The planned menu/CLI includes `setup`, `status`, `start`, `stop`, `restart`, `update`, `ddns`, Access retry/test, logging re-detect, `backup`, `restore`, `repair`, and `uninstall`. These are a specification, not available commands yet.

## Service lifecycle, updates, DDNS, and Access

### Lifecycle and update invariants

| Contract | Existing behavior to preserve / planned improvement |
| --- | --- |
| One lifecycle controller | Boot/WAN/watchdog/manual/update/restore must not each implement their own start/stop sequence. |
| Lock separation | Preserve independent nonblocking updater and lifecycle locks. Download/metadata work must not block watchdog recovery; only activation owns the lifecycle lock. Define one lock order for maintenance, updater, lifecycle, queue, and backup/rotation paths to prevent deadlock. |
| Owned process | Validate PID/executable ownership; avoid stopping unrelated `cloudflared` connectors. Scope the first release to one managed connector rather than advertising untested multi-tunnel support. |
| Readiness | Preserve bounded checks for binary/config/tools, synchronized time, IPv4 reachability, and usable tunnel discovery SRV/A answers. Expected wait remains distinct from failed launch; the current implementation uses status `75`. |
| Fast path | Leave a running service alone. Retain readiness checks before stopping for restart/update. Do not add unconditional boot delays or repeat expensive recovery work when nothing is wrong. |
| Startup evidence | Current two-second process survival proves process startup only. Status must distinguish process running, readiness deferred, and separately verified Cloudflare tunnel connectivity. |
| Bounded stop | Current TERM/wait is bounded to 35 seconds. Refuse replacement when the process does not stop; do not force-kill as a routine fallback. |
| Single binary update owner | Launch with `--no-autoupdate`; use the scheduled worker for automatic updates. A separate continuously polling updater daemon is unnecessary for current feature parity. |
| Architecture and integrity | Current updater targets Linux ARM64 and validates URL/tag/reported version, without checksum/signature verification. Add a tested architecture/ABI map; verify published digests/checksums when available and document the actual validation level. Unsupported routers/assets fail before activation. |
| Activation | Bound metadata/download size and time; stage on the target filesystem; validate before stopping. Recheck version/readiness/mount after locks are acquired, then atomically activate. |
| Recovery | Protect the known-good `.old` and pending-update marker across interruption. A pending recovery must resolve before another update overwrites its backup. Clear recovery state only after the restored/replaced binary passes startup checks. |
| Manager updates | Version the manager package separately; validate and back up before replacing it. Update related lifecycle/helper files as one compatible package. Do not automatically install development-branch code on stable installations. |

### DDNS and Access parity

| Behavior | Required implementation rule |
| --- | --- |
| IPv4 discovery | Preserve router `$1` when supplied and the configured external fallback otherwise. Make router/external/automatic policy explicit, including double NAT. |
| IPv6 | Preserve optional AAAA updating and its existing external discovery path; default off unless imported settings enable it. Merlin also supplies an optional second IPv6 argument, so support it only through an explicit, tested source policy. |
| DNS records | Preserve updating every matching A/AAAA record. The reference writes its configured TTL and `proxied: false`; preserve those settings on import and make later changes explicit. Read current record attributes so unrelated fields are retained. Record creation is a wizard action, not an implicit response to an ambiguous lookup failure. |
| Transport | Preserve bounded DNS/IP HTTP calls (current connect timeout 5 seconds, total 20 seconds). Validate HTTP/API results and handle record pagination explicitly. |
| Completion | One `/sbin/ddns_custom_updated` result for a CFMgr-owned custom DDNS invocation; failure in any required DNS update yields failure. |
| Access independence | Forward the already-resolved public IPv4 asynchronously. Access failure must not turn a successful DNS update into failure, and must not delay the DDNS hook waiting for retries. |
| List safety | Validate list ID, name, type, and dedicated-list policy. Accept zero or one public IPv4 `/32`; refuse to overwrite unrelated/multiple/IPv6/wider-CIDR entries. |
| API work | Preserve metadata/item checks, unchanged-value no-op, replacement, and readback verification. Keep API tokens out of curl arguments and diagnostic bodies. |
| Queue | Keep the newest request, serialize workers, prevent an old worker from clearing a newer notification, and bound work per run (currently four queued updates). |
| Retry | Reuse the saved IP; do not repeat address discovery or DNS updates. Retain configured target matching and 24-hour expiry defaults. Queues/locks remain transient; rebuild from a fresh DDNS event after reboot/restore. |
| Disabled module | Missing/disabled Access configuration is a no-op. Avoid API calls and dependency installation for unselected features. |
| Policy meaning | Publishing the list does not itself create a bypass policy. Preserve existing Access policy behavior; the wizard must not silently change authorization policies. |

The list update uses Cloudflare's [Zero Trust list API](https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/subresources/lists/methods/update/). DNS edits follow the [DNS record API](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/edit/). Validate required permissions against the selected operations during implementation.

## Scribe logging and rotation

### What is established

The primary reference writes tunnel output to `/opt/var/log/cloudflared.log` and emits lifecycle/DDNS/Access messages to syslog. It does not include its active Scribe rotation policy.

| Current producer | Current logging path | CFMgr treatment |
| --- | --- | --- |
| `cloudflared` connector | Direct application logfile `/opt/var/log/cloudflared.log`; background console output is suppressed. | Import existing log/history when eligible, then use the selected owned tunnel-log path only with usable Scribe. |
| Watchdog/shared lifecycle | `logger` with `cloudflared-watchdog` or shared `cloudflared-control` tag. | Recognizable lifecycle category through the conditional CFMgr logging adapter. |
| Binary updater | `logger` with `cloudflared-update` tag. | Separate update category through the same conditional adapter. |
| DDNS | `logger` with `DDNS-CF`; also prints when invoked in a terminal. | Preserve interactive feedback; conditional DDNS logging category. |
| Access helper | Syslog with `CF-Access-IP`, plus console messages; hooks redirect its output. | Conditional Access logging; keep queue/retry status available through the manager. |

The captured Scribe setting names `/tmp/syslog.log` as the system-log path. Actual destinations/retention still depend on its active syslog-ng and logrotate rules; do not infer those rules from the tags or filename alone.

The separate captured `jffs/scripts/scribe` identifies AMTM-OSR Scribe and defines `/opt/etc/syslog-ng.conf`, `/opt/etc/syslog-ng.d`, `/opt/etc/logrotate.conf`, and `/opt/etc/logrotate.d` (lines 149–211). It checks `syslog-ng` process/config state; its `LogRotate` path locks `/tmp/scribeLogRotate.flock` and runs `/opt/sbin/logrotate /opt/etc/logrotate.conf` (lines 1539–1551 and 1712–1746). Captured `jffs/addons/scribe.d/config` selects `/tmp/syslog.log`; captured `post-mount` registers Scribe rotation at 00:05 when Entware is available.

Treat Scribe script/package presence as a detection signal, not proof of a configured logging system. Its fallback discovery concerns syslog-ng destinations; `cloudflared` writes a direct application log and therefore needs an explicit owned policy. The maintained [Scribe project](https://github.com/AMTM-OSR/scribe) provides the upstream integration reference.

### Logging state model

| Detected state | CFMgr behavior |
| --- | --- |
| Scribe absent | Logging unavailable: omit daemon logfile flags, suppress background console output, and do not call `logger`/syslog or create rotation fragments. Interactive status/errors still print. |
| Scribe present but incomplete/unusable | Same logging behavior as absent. Explain the failed detection checks in interactive status and offer re-detection after setup. |
| Scribe ready and logging selected | Enable private manager/tunnel log destinations and an owned rotation fragment after both configurations validate. Preserve unrelated logging configuration. |
| Scribe becomes unavailable | Do not accumulate unrotated CFMgr logs. Disable the owned logging path and arrange a bounded tunnel restart if needed; leave existing log archives in place. Re-detection can enable it later. |

Readiness requires verified Entware storage, installed Scribe integration, usable syslog-ng/logrotate executables and configurations, active syslog-ng when logging is requested, a functioning Scribe rotation schedule, and confirmed inclusion of the fragment directories. Detection is read-only; it must not install or reconfigure Scribe globally.

### Proposed owned logging integration

| Item | Planned behavior |
| --- | --- |
| Manager messages | Route CFMgr-owned tags to `manager.log` through one syslog-ng fragment. Keep separate recognizable DDNS, Access, updater, and lifecycle categories. Redact credentials and sensitive API bodies. |
| Tunnel log | `cloudflared.log` under the approved CFMgr log directory; retain/migrate the existing logfile and its rotations after backup. Do not depend on Scribe auto-discovery for this file. |
| Rotation owner | One non-`A01global` CFMgr fragment under the active included `logrotate.d`. Reuse Scribe's scheduler and lock contract; no second rotation cron. |
| Policy | Configurable frequency, size limit, count/age retention, and compression. Validate against installed logrotate and available space; inherited global defaults must not accidentally define CFMgr retention. |
| Open logfile handling | Confirm `cloudflared` log-reopen behavior before choosing rename/reopen or `copytruncate`. If `copytruncate` is necessary, document its small loss window; do not assume a syslog-ng HUP reopens cloudflared's own file. |
| Validation | Check syslog-ng syntax and run logrotate debug mode against the active include chain. Verify nested log paths and duplicate/matching rules. Activate only the owned changes. |
| Backup coordination | Agree a non-deadlocking lock/snapshot strategy with Scribe's rotation path. Full backup must not race file rotation or recursively include its own archive. |

**Re-detect flow:** inspect prerequisites and prior owned state; back up existing CFMgr configuration/rules; stage and validate its fragments; reload affected logging configuration using the supported mechanism; commit the logging state; restart the tunnel through the shared controller if its logfile options changed. Repeating the action must be a no-op when already configured. Failure restores prior owned fragments/settings and must not damage Scribe's global configuration.

## Backup and restore

Backups cover the complete CFMgr installation and the existing Cloudflare setup being migrated. They are separate from the updater's `.old` binary recovery file. Default storage is the Entware drive; export to another destination provides protection against failure of that drive.

### Backup contents

| Item | Config backup | Full backup | Restore rule |
| --- | --- | --- | --- |
| CFMgr settings, schema, feature selections | Include | Include | Validate/migrate schema before activation. |
| Tunnel YAML, credential JSON, token files, imported certificate | Include | Include | Restore privately to verified Entware paths; preserve tunnel identity and settings. |
| DNS and Access credentials/settings | Include | Include | Restore selected settings; validate credentials without displaying them. |
| Hook/job ownership manifest and prior DDNS settings | Include | Include | Merge/rebuild owned integrations rather than overwriting current whole hooks. |
| Owned syslog-ng/logrotate fragments and logging preference | Include when present | Include when present | Activate logging only if Scribe is currently ready; retained preferences can remain disabled. |
| Existing pre-migration config/hook/rule originals | Include in migration snapshot | Include in migration snapshot | Retain for rollback; whole-hook restoration is an explicitly reviewed emergency action. |
| Manager executable/helper package | Version manifest | Include | Restore a compatible package as one unit. |
| Active cloudflared and known-good `.old` | Version/asset manifest | Include if safe/validated | Check architecture/version; a config-only restore can obtain the required supported binary separately. |
| Manager/tunnel logs and owned rotated history | Exclude | Include when Scribe is detected and configured | Restore owned files only; state in the manifest whether logs were included, absent, or skipped because Scribe was unavailable. |
| Locks, PIDs, temporary queues/downloads, stale readiness state | Exclude | Exclude | Recreate fresh; obtain a new public IP instead of replaying stale Access work. |
| Unrelated Entware/add-on files and whole router syslog | Exclude | Exclude | This is a full CFMgr backup, not a whole-router or Scribe-system backup. |
| Remote Cloudflare resource inventory | Available identity/settings snapshot | Available identity/settings snapshot | Reconcile existing IDs read-only first; local restore does not resurrect a deleted/revoked remote resource automatically. |

Archives contain operational credentials. Use private files/directories, no secret-bearing filenames or shell arguments, and a clearly labeled export action. Decide encrypted export support without adding a mandatory encryption dependency to the basic manager.

### Backup transaction

1. Run Entware/storage/free-space checks and acquire the documented maintenance/backup locks. Do not take a successful backup of an unresolved binary activation; resolve/defer pending update state first.
2. Save a pre-change configuration snapshot before migration, setup replacement, manager update, restore, or logging-rule changes. Coordinate ordinary snapshots with lifecycle/update activity.
3. Capture a consistent owned file set and permissions. Snapshot eligible logs with the chosen rotation/writer coordination; do not stop the tunnel unnecessarily for a configuration-only backup.
4. Create a versioned manifest containing archive type, timestamp, manager/schema versions, architecture, file list/modes, hashes, feature states, and log-inclusion result. Do not include arbitrary command output or secrets in the manifest.
5. Build and verify the archive in private Entware staging, then atomically move it into the backup directory. A partial or unverified archive never counts as successful.
6. Prune only recognized, unpinned CFMgr archives after a new successful archive exists. Keep the migration and active restore rollback snapshots protected. Never purge arbitrary logs/backups to make an operation appear successful.
7. Support listing, inspecting the manifest, verifying, and exporting archives. Record a useful interactive failure if space is insufficient; do not silently omit required files from a successful full backup.

Proposed defaults to settle in Phase 1: retain seven successful scheduled archives and ten lightweight pre-change snapshots; pin migration/restore recovery archives. Automatic backup is selected during setup, with a proposed 04:15 schedule. Log inclusion is conditional on usable Scribe, independent of whether its currently selected CFMgr logging path has produced files yet.

### Restore transaction

1. Verify Entware mount, destination writability/space, archive integrity, schema compatibility, and architecture before changing active files. Allow inspection/validation without activation.
2. Extract into private staging with a strict owned-path allowlist. Reject absolute paths, `..` traversal, unsafe links/devices, duplicate conflicting entries, and writes outside approved roots.
3. Show the archive's selected features and intended local changes, then create a verified rollback snapshot of the current installation.
4. Acquire maintenance/update/lifecycle locks in the documented order; pause owned schedules while committing. Stop the owned tunnel through the bounded controller; abort if it cannot be stopped safely.
5. Restore configuration/credentials/package as a coherent transaction. Resolve Entware paths for this router; do not restore another router's physical mount label. Restore metadata and permissions.
6. Regenerate owned hook blocks and cron jobs while preserving current unrelated content. Do not blindly replace whole `services-start`, DDNS, mount, or Scribe global files from the archive.
7. Re-detect Scribe and validate logging/rotation before enabling it. Restore eligible owned log archives only to Entware storage; if Scribe is unavailable, retain them privately without enabling writes/rotation.
8. Reconcile Cloudflare resources before any provider writes. Preserve existing tunnels/DNS/Access policies; report revoked tokens/deleted resources and route needed repair through setup. A local archive is not a rollback of Cloudflare's control plane.
9. Resume selected schedules/services after validation and readiness. Preserve a saved stopped/disabled state. Run fresh DDNS/Access work only for enabled features; distinguish process survival from connectivity.
10. On activation failure, restore the saved local transaction and owned integrations. Keep the rollback archive; report the exact failed stage and remaining service state.

## Install, migration, repair, and uninstall

| Operation | Required behavior |
| --- | --- |
| Fresh install | Verify Entware first; install only selected-feature dependencies; stage a versioned manager package and verified binary; write private config; install owned hooks/jobs; start selected services. No formatting/Entware installation. |
| Legacy detection | Identify the supplied scripts, tunnel files, old cron commands, logfile, and any matching rotation policy. Never execute/source a legacy secret-bearing script just to extract its settings. |
| Migration backup | Archive existing Cloudflare settings, credentials, original hook files, old cron definitions, and relevant rotation policies before modifying them. Include existing owned logs when Scribe is ready. |
| Migration activation | Validate imported settings, determine tunnel management mode, stage new paths, preserve routing/certificates, switch hooks/jobs once, and use one deliberate lifecycle transition. Retain rollback material. |
| Legacy takeover | Remove only recognized legacy CF behavior and owned jobs. If unrelated DDNS logic cannot be separated safely, stop automatic takeover and prepare a reviewed integration instead of running duplicate providers. |
| Repair | Revalidate mounted storage/config/schema/permissions, reconcile owned blocks/jobs/rules, and recover interrupted manager/binary transactions. Do not change remote policies or install global Scribe defaults. |
| Uninstall | Remove owned jobs/blocks/fragments and stop the owned connector. Preserve user configuration/credentials/backups by default; any purge is a distinct action. Leave Entware/Scribe/other add-ons installed and remote Cloudflare resources intact. |
| Releases | Publish reviewed stable manager packages through `main`/versioned releases. Development builds are an explicit choice. Installation documentation is added only after a real install path has passed validation. |

A single public command may use packaged private helpers internally. The goal is one setup/management workflow, with no separately managed user scripts. Keep the layout small; modularize only when it improves correctness or maintainability.

## Build checklist

### Phase overview

| Phase | Status | Deliverable / exit condition |
| --- | --- | --- |
| P0 — Reference and plan | Done | Current source/config shape, hooks, schedules, logging gaps, storage layout, backup/restore requirements, and handoff captured here. |
| P1 — Contracts and evidence | Pending | Configuration schema, dependency choice, supported architecture matrix, live Scribe include/rules, Entware checks, and transaction/lock order settled. |
| P2 — Manager foundation | Pending | Menu/CLI, safe config IO, feature selection, status, Entware preflight, package ownership, and sanitized fixtures. |
| P3 — Tunnel lifecycle and updater | Pending | Shared controller, readiness/watchdog, bounded stop, supported binary installer/updater, interruption recovery, and manager package transactions. |
| P4 — DDNS and Access | Pending | Feature-selectable DNS updates, firmware reporting, public-IP policy, Access queue/retry/readback, and parity validation. |
| P5 — Hooks and wizard | Pending | Idempotent integrations, legacy import, minimum-input API setup, resource-ownership handling, and migration backup before activation. |
| P6 — Scribe integration | Pending | Detection/state transitions, owned log destinations/rules, re-detect/restart, rotation verification, and absent-Scribe behavior. |
| P7 — Backup and restore | Pending | Config/full archives, automatic/retention/export options, transactional restore, and failure/rollback validation. Build the pre-change snapshot primitive earlier, before any migration activation. |
| P8 — Router validation and release | Pending | Authorized fresh-install/migration/reboot/unmount/restore evidence, operating docs, supported-model declaration, and reviewed stable release. |

### Action checklist

- [x] P0.1 Inspect the supplied setup directory, including tunnel file shape without publishing values.
- [x] P0.2 Map existing boot/WAN/DDNS hooks, four Cloudflare schedules, and unrelated add-on entries.
- [x] P0.3 Record current readiness, locks, update recovery, DDNS, and Access queue contracts.
- [x] P0.4 Inspect captured Scribe integration; distinguish it from missing active rotation/mount evidence.
- [x] P0.5 Define proposed storage layout, backup/restore scope, phases, and handoff format.
- [ ] P1.1 Capture current mount resolution, package capabilities, permissions, cron commands, and relevant hook contents privately.
- [ ] P1.2 Capture active Scribe/syslog-ng/logrotate includes and cloudflared-specific rules; verify read-only configuration checks.
- [ ] P1.3 Freeze safely parsed configuration schema, module/dependency selection, architecture support, and version compatibility.
- [ ] P1.4 Settle remote/local tunnel creation default and permissions for each wizard path; preserve import compatibility.
- [ ] P1.5 Document lock order, ownership model, interrupted manager-update state, and log/backup coordination.
- [ ] P2.1 Implement Entware preflight and storage-loss behavior before persistent writes.
- [ ] P2.2 Implement menu/CLI, private atomic config IO, feature switches, status, and redacted diagnostics.
- [ ] P2.3 Create de-identified fixtures; retain the meaningful reference concurrency/failure scenarios.
- [ ] P3.1 Port shared lifecycle/readiness and respectful start/stop/restart/watchdog behavior.
- [ ] P3.2 Implement architecture-aware installation/update validation and protected `.old`/pending recovery.
- [ ] P3.3 Add compatible manager-package staging, verification, pre-change backup, and recovery.
- [ ] P4.1 Implement A/optional AAAA updates, IP-source policies, pagination, and exact firmware result semantics.
- [ ] P4.2 Implement Access validation, newest-request queue, independent retries, and readback.
- [ ] P5.1 Build idempotent hook/job installation/repair/removal and Access-only observation.
- [ ] P5.2 Implement backup-before-migration and safe legacy settings extraction/import.
- [ ] P5.3 Build selected-feature wizard, scoped-token checks, tunnel creation/import, and provider-resource provenance.
- [ ] P6.1 Implement Scribe detection and complete suppression of background logging when unavailable.
- [ ] P6.2 Add owned logging/rotation rules and validate logfile handling, retention, and existing-rule coexistence.
- [ ] P6.3 Implement transactional re-detect/enable/disable with bounded affected-service restart.
- [ ] P7.1 Implement manifests, config/full backups, logs when Scribe is ready, verification, and protected retention.
- [ ] P7.2 Implement inspection/export and same-router/replacement-router restore with safe extraction.
- [ ] P7.3 Validate failed/partial restore rollback and service/hook/cron reconciliation.
- [ ] P8.1 Perform authorized runtime checks, reboot and mount-loss recovery, fresh install, and actual full restore.
- [ ] P8.2 Populate `docs/`, add useful `.images/` assets, review secret exposure, and publish the first supported release.

## Validation matrix

All runtime results start as pending. Use sanitized fixtures/mocks first; source checks, local simulations, and live router/Cloudflare proof are recorded separately. Do not claim connectivity from PID/process-survival checks. Existing test changes should be explained before changing their expectations.

| Test ID | Scenario | Required result | Evidence status |
| --- | --- | --- | --- |
| V01 | Entware absent, unmounted, read-only, wrong volume, or lost mid-operation | No fallback writes; interactive guidance or prompt hook deferral; owned DDNS fails accurately when necessary. | Pending |
| V02 | Supported/unsupported architecture and missing dependencies | Supported selected-feature paths work; unsupported binaries/dependencies fail before activation. | Pending |
| V03 | Boot/WAN/watchdog/manual starts overlap | One owned connector; preserved other hooks; no blocking boot/network loop. | Pending |
| V04 | Time/DNS/IPv4 readiness failure and recovery | Deferred state, bounded checks, restart does not stop a healthy process before readiness, and recovery on a later trigger. | Pending |
| V05 | Update metadata/download/version/backup/stop failure | Old binary/service protected; failure is bounded and recoverable. | Pending |
| V06 | Interruption before/after binary or manager activation | Compatible package/known-good binary restored; pending markers and backups protected. | Pending |
| V07 | DDNS router/external IPv4, multiple A records, optional AAAA, partial API failure | Correct IP/records and exactly one truthful Merlin completion result. | Pending |
| V08 | Access disabled, unchanged, wrong/multi-entry list, API failure, concurrent/newer requests | No unintended writes; newest valid request survives; retry uses saved IP and verified readback. | Pending |
| V09 | Install/repair twice; legacy migration; unknown DDNS owner | No duplicates; other add-ons preserved; ambiguous takeover does not run a second provider. | Pending |
| V10 | DDNS-only/tunnel-only/Access-only/combined wizard, bad/scoped tokens | Only needed prompts/dependencies; credentials are correctly distinguished; failures preserve existing resources. | Pending |
| V11 | Import supplied YAML/JSON/PEM and remote-token configuration | Settings/routing retained; actual management mode honored; no unnecessary certificate requirement. | Pending |
| V12 | Scribe absent/incomplete/ready/later installed/later unavailable | Logging disabled unless ready; re-detect safely installs rules and restarts only affected services. | Pending |
| V13 | Logrotate validation/real rotation with active tunnel logging | Correct includes/retention/compression; no duplicate stanzas or abandoned open logfile; no separate rotation cron. | Pending |
| V14 | Config/full backups, eligible/ineligible Scribe, full disk, concurrent rotation | Honest manifest, correct file/log set, private valid archive, no partial-success report or recursive archive inclusion. | Pending |
| V15 | Backup retention/export and pinned snapshots | Only recognized old CFMgr archives pruned after success; protected rollback copies retained. | Pending |
| V16 | Restore on same and compatible replacement router, corrupt/traversal/unsafe-link archive | Validation before active changes; path-safe extraction; correct Entware remapping/permissions. | Pending |
| V17 | Restore activation failure, revoked credentials, or deleted remote resources | Local rollback succeeds; no guessed resource recreation or authorization-policy changes. | Pending |
| V18 | Stop, reboot, unmount/remount, and uninstall | Stopped state respected; disk removal bounded; owned integrations reconciled; unrelated add-ons/resources preserved. | Pending |

## Decisions and missing evidence

| ID | Decision/evidence | Proposed direction / next check | Status |
| --- | --- | --- | --- |
| D01 | Dedicated folder layout | Small `/jffs/scripts/cfmgr` plus optional `/jffs/addons/cfmgr/`; persistent data under verified `/opt`. | Proposed |
| D02 | Configuration format and parser | Versioned non-executable settings with private credential references; choose one parser before implementing IO. | Pending P1 |
| D03 | Access implementation/dependencies | Prefer a small POSIX manager with shared JSON tooling; retain a packaged Python helper if a rewrite cannot cheaply preserve its tested queue semantics. Install Python only when selected behavior needs it. | Pending P1 |
| D04 | New tunnel management mode | Import both existing forms; choose new local/API-managed versus remotely configured default after confirming exact create/route/token flows. | Pending P1 |
| D05 | Actual router support | Current updater is ARM64-specific; test real firmware/architecture/ABI combinations before declaring wider support. | Pending P1/P8 |
| D06 | Backup schedule/retention | Proposed optional 04:15 automatic job, seven scheduled and ten pre-change snapshots, protected migration/restore snapshots. | Proposed |
| D07 | Encryption/export | Private local archives are required; decide optional encrypted export and dependency cost before release. | Pending P7 |
| D08 | Active Scribe include/rules | Need active `/opt/etc/logrotate.conf`, included fragments, syslog-ng include chain, Scribe readiness/schedule, and debug validation. Historical captured policy values are not adopted as defaults. | Needs router evidence |
| D09 | Logfile rotation strategy | Verify cloudflared reopen support and installed logrotate behavior, including nested paths, before choosing rename/reopen or copytruncate. | Needs targeted validation |
| D10 | Actual mounted Entware target | Need resolved `/opt`, mount identity, free-space/read-only checks, and post-mount/unmount ordering. | Needs router evidence |
| D11 | Existing tunnel routing/mode | Supplied YAML has a catch-all-style ingress entry; inspect management mode/configuration before import rather than inventing applications. | Needs selected-account evidence |
| D12 | Maintenance lock order | Include manager/binary update, lifecycle, backup, Access workers, and Scribe rotation without long watchdog blocking. | Pending P1 |

Evidence collection stays private and read-only until a deployment or provider mutation is authorized. Do not commit captured tokens, tunnel IDs, hostnames, certificates, raw config dumps, or real log archives. Sanitized operating examples belong in `docs/`.

## Handoff record

Update this section and the checklist after each material implementation package. Record actual test evidence, not just planned commands. Keep secrets and personal paths out of this document.

| Handoff field | Current value |
| --- | --- |
| Last completed stage | P0 source audit and planning. |
| Current branch / base | `develop`, based on scaffold commit `594055d`; this change adds the plan. |
| Implemented runtime components | None. |
| Current documentation changes | Root `PLAN.md`; README link and planned backup/storage scope. |
| Validation completed | Source inspection, redacted config-shape inspection, source fingerprints, and documentation/secret checks recorded with this change. No manager runtime tests. |
| Router/provider changes | None during planning. |
| Outstanding evidence | Active Entware mount/capabilities; Scribe config/include/rotation rules; tunnel mode/routing; selected architecture matrix. |
| Next coherent work package | P1 contract decisions and a de-identified reference fixture set; implement only after requested. |
| Worktree / publication | Verify with `git status` and branch refs at handoff. Planning document can be committed on `develop`; publication is a separate action. |

| Date | Stage / note | Files or evidence | Commit / next action |
| --- | --- | --- | --- |
| 2026-10-08 | Initial CFMgr scaffold published on `main` and `develop`. | README, GPL license, ignore rules, empty docs/images folders; local ignored agent instructions. | `594055d` |
| 2026-10-08 | P0 completed using the supplied current setup, with supplemental captured Scribe integration. Defined parity, Entware storage, hook ownership, Scribe-only logs, and full backup/restore design. | Source references and fingerprints above; plan and README. Active rotation rules still unverified. | This planning change; next P1. |

For subsequent rows use: date, completed package, changed files, exact checks/results, commit/ref, unresolved issues, and next action. If scope or a default changes, update the requirement/decision row as well as the session note. Keep P0 history; do not overwrite prior implementation evidence.

## References

| Reference | Purpose |
| --- | --- |
| Supplied `cloudflared/setup/jffs/scripts/` and `opt/etc/cloudflared/` | Primary behavior/configuration baseline; keep private outside the repository. |
| Separate captured `jffs/scripts/scribe`, `post-mount`, and `jffs/addons/scribe.d/config` | Supplemental Scribe/storage hook evidence, with no claim of active runtime verification. |
| [Merlin user scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts) | Hook lifecycle and argument contracts. |
| [Merlin Entware guide](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Entware) | Entware setup prerequisite. |
| [AMTM-OSR Scribe](https://github.com/AMTM-OSR/scribe) | Maintained Scribe integration source. |
| [Cloudflare Tunnel creation API](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/methods/create/) | Scoped API creation and configuration-source selection. |
| [Cloudflare tunnel permissions](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/tunnel-permissions/) | Account certificate versus tunnel credentials. |
| [Cloudflare run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/) | Explicit updater ownership and token-file runtime support. |
| [Cloudflare Zero Trust list update](https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/subresources/lists/methods/update/) | Optional Access IP-list updates. |
| [Cloudflare DNS record API](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/edit/) | Configuration-driven DNS updates. |
