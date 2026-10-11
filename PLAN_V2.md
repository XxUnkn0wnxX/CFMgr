# CFMgr — product and implementation plan v2

> **Reviewed scope and recovery baseline.** This plan describes the complete intended CFMgr product. Delivery and acceptance items live in [PLAN_V2_checklist.md](PLAN_V2_checklist.md); product acceptance remains unassessed. Recovery authorization, sequencing and current coordination belong in [PLAN_V2_handoff.md](PLAN_V2_handoff.md) and [AGENTS.md](AGENTS.md). Existing code must be audited and validated against these requirements before receiving completion credit. Open decisions remain explicitly identified.

CFMgr is a terminal menu and command-line manager for Cloudflare DDNS, one Cloudflared tunnel, and Cloudflare IP-Sync on Asuswrt-Merlin. Each feature has its own setup and saved activation state, with shared infrastructure where their requirements overlap.

**100% means implemented, integrated, validated and ready to use within the declared support scope.** Necessary library consolidation, operating documentation, efficient tests and required safety validation are part of delivery. Optional final documentation polish and broad optimization may follow functional completion.

The retained source specification is [`.old/PLAN.md`](.old/PLAN.md). It is an archive for checking scope, not an execution roadmap. This v2 contains no imported progress, commit history, validation results or completion credit. Each main section lists its subgoals; the detailed contracts below the table define their behavior and edge cases. Proposed defaults and unresolved implementation decisions are labelled explicitly; they are not silently treated as approved guarantees.

## Contents

- [1. Product scope and boundaries](#1-product-scope-and-boundaries)
- [2. Installation, storage and dependencies](#2-installation-storage-and-dependencies)
- [3. Configuration, menus and status](#3-configuration-menus-and-status)
- [4. Save, cancellation and recovery](#4-save-cancellation-and-recovery)
- [5. Cloudflared setup and credentials](#5-cloudflared-setup-and-credentials)
- [6. Tunnel lifecycle and binary maintenance](#6-tunnel-lifecycle-and-binary-maintenance)
- [7. CFMgr updates, source selection and developer mode](#7-cfmgr-updates-source-selection-and-developer-mode)
- [8. Shared address discovery and reconciliation](#8-shared-address-discovery-and-reconciliation)
- [9. DDNS](#9-ddns)
- [10. IP-Sync](#10-ip-sync)
- [11. Provider failures and credential repair](#11-provider-failures-and-credential-repair)
- [12. Hooks, schedules and boot safety](#12-hooks-schedules-and-boot-safety)
- [13. Logging and rotation](#13-logging-and-rotation)
- [14. Backup and restore](#14-backup-and-restore)
- [15. Uninstall, retained installation and reset](#15-uninstall-retained-installation-and-reset)
- [16. Product readiness and documentation](#16-product-readiness-and-documentation)
- [17. Open product decisions](#17-open-product-decisions)
- [18. Reference authorities](#18-reference-authorities)

## 1. Product scope and boundaries

| ID | Subgoal | Required result |
| --- | --- | --- |
| S01.01 | CLI product | One terminal manager with independently configured DDNS, one tunnel and IP-Sync. |
| S01.02 | Source parity | Replace all router Python paths while preserving the specified lifecycle, updater, DDNS and Access behaviors. |
| S01.03 | Feature isolation | No forced setup, credentials or activation of unselected features. |
| S01.04 | Scope boundaries | No multi-tunnel manager, policy administration, automatic whole-list/old-tunnel deletion or whole-router backup. |
| S01.05 | Optional future work | CFMgr WebUI is outside current scope; external viewer/catalog integrations remain conditional. |

### Required product

- One installable POSIX `sh` entry, native numbered/text menus, dedicated feature submenus and equivalent commands for supported operations.
- Passive fresh installation; independent DDNS, Cloudflared and IP-Sync setup; truthful local status and standalone diagnostics.
- Shared safe configuration, selected dependency management, mounted-storage checks, process ownership, admission, deadlines, recovery and provider transport.
- Cloudflared token setup, advanced import and fresh advanced creation; explicit mode switching; lifecycle control, watchdog, checked binary updates and rollback.
- DDNS A/AAAA and IP-Sync current-address reconciliation, including confirmed family removal, return, remote drift and independent failure handling.
- Bounded firmware integration and schedules, scoped self-repair, optional Scribe file logging, manual data backup/restore, KEEP/WIPE uninstall and passive reset.
- Verified manager updates with default-On checks, default-Off automatic installation, explicit force reinstall and manual developer source controls.
- Documentation that lets users install, configure, operate, recover and remove the finished supported product.

### Scope limits

CFMgr is CLI-only. A CFMgr browser GUI is outside this roadmap and its completion percentage. Optional viewing through uiScribe is an external integration, not a CFMgr GUI commitment.

Manage one tunnel per router. Advanced B includes reviewed discovery/creation of
public-hostname routes and basic hostname-to-origin ingress mappings for that
tunnel. Extra application/YAML options, private-network routes and Access policies
remain user-managed. A supports an existing connector token or guided creation of
a dashboard-managed tunnel; its application configuration stays in Cloudflare.
IP-Sync publishes host addresses into selected lists; it does not create a bypass
policy or authorize a delegated IPv6 subnet.

Do not automatically create/delete Cloudflare IP lists, delete old tunnels, restore a previous DDNS provider, back up the whole router, install Entware/Scribe, upgrade all Entware packages, reboot the router or restart global firmware services. The explicit DDNS handoff has its own narrowly scoped firmware apply operation.

No router Python, virtualenv, Python reference-script wrapper/fallback, mandatory external picker, new polling daemon or self-unpacking monolithic distribution. Optional amtm official catalog/update support and a uiScribe external-log registry require a separately supported route; they do not block the initial product.

### Source parity

Use the original private `cloudflared/setup/` tree as the primary behavioral reference. Resolve its local location through ignored `.tmp/reference-paths.md`; supplemental captured router files are not substitutes for the original source or runtime acceptance.

| Reference responsibility | Required CFMgr equivalent |
| --- | --- |
| Cloudflared entry/common helper | One lifecycle controller, readiness before ordinary restart, bounded stop, pending recovery and safe detached connector ownership. |
| Binary updater | Official release/version checks, protected old binary, pending transaction, activation/rollback and truthful failed-update reporting. |
| DDNS hook | Native structured record enumeration, all matching configured A/AAAA records, saved TTL/proxy attributes and exactly one firmware completion owner. |
| Python Access helper | Full shell IP-Sync port: private API transport, complete validation/readback, unchanged-no-write behavior, newest-request queue, writer exclusion, bounded retries and explicit read-only target check. |
| Boot/WAN hooks and cron | Preserve the operational schedule defaults and detached WAN settle behavior without blocking foreign hooks or duplicating controllers. |
| Advanced YAML/JSON/certificate | Preserve full valid application configuration and credential identity; import does not infer remote management mode or invent applications. |

Remove every router Python call path, including DDNS record parsing, Access dispatch and updater metadata parsing. Deliberate improvements include NAT-aware shared address discovery, provisional IPv6, strict artifact verification, ownership checks, capped outage retries and authoritative active/inactive remote reconciliation.

## 2. Installation, storage and dependencies

| ID | Subgoal | Required result |
| --- | --- | --- |
| S02.01 | Modular distribution | One verified package with extensible feature modules, shared libraries grouped by reused responsibility and thin entry/hooks. |
| S02.02 | Private storage layout | JFFS authority/recovery, RAM frequent state, verified Entware tunnel/log data, independent backup mount. |
| S02.03 | Generated defaults | Private extensionless config generated only for genuinely fresh setup; no shipped config/template. |
| S02.04 | Shared operational prerequisites | Verified jq, timeout and SHA-256; native-first flock and tunnel-only DNS additions. |
| S02.05 | Normal dependency repair | Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| S02.06 | Selected dependency reinstall | Explicit force action for mapped requirements, separate from tunnel maintenance and configuration. |
| S02.07 | Native recovery access | Status/doctor/recovery/safe Off remain usable without operational Entware tools. |
| S02.08 | Storage identity and loss | Verify actual expected volume/attachment and paths, stop dependent owned work on loss, never stale mountpoint writes. |
| S02.09 | Capability-based support | Actual native options, TLS trust, userspace ABI and bounded platform profiles; no inferred universal compatibility. |

### Package and directory layout

Repository `cfmgr.sh` and `catalog.txt` stay at the root. Feature modules live directly in `modules/`; shared libraries/parsers in `modules/lib/`; workers, updaters and bootstrap in `modules/helpers/`; thin hook/cron entries and templates in `modules/hooks/`. Use small explicit interfaces and imports. Loading a library must not start work, wait, contact the network or mutate state. No arbitrary directory auto-loading.

Group genuinely reused code into a small practical set of coherent responsibilities,
such as networking/provider transport, hook integration, worker/update management
and logging where shared. Do not create one library for each internal helper or
component; keep small feature-specific logic in its owning module. Forks and new
features should extend explicit module interfaces with thin menu/dispatch changes,
without repeatedly rewriting a monolithic entry. Consolidation must preserve
explicit consumers, feature isolation and the safety contracts of reused code;
fewer files alone do not establish a coherent architecture or delivered feature.

Recovery retains code only where it can finish at least one entire existing
subgoal through a real consumer. Most of that substantive requirement should be
salvageable, with the remaining behavior completed before retention is accepted.
Partial feature implementations and disconnected scaffolding are removed and
rebuilt in their checklist turn. Shared support stays only when consumed by a
fully completed retained subgoal. Written focused tests and required exact CI
must pass before the final tick. Recovery selection and proof status are tracked
in the checklist/handoff and do not reduce the product scope below.

The package manifest must enumerate safe nested relative paths. Install the entry at `/jffs/scripts/cfmgr.sh`; keep its verified modules, support files and separate catalog under `/jffs/addons/CFMgr.d/`, preserving responsibility categories. Freeze the exact source-to-installed mapping before installer implementation and use it consistently in imports, manifests, hooks and recovery.

| Location | Intended contents and rules |
| --- | --- |
| `/jffs/scripts/cfmgr.sh` | Small executable entry, mode `755`; installed package generation must match its modules. |
| `/jffs/addons/CFMgr.d/config` | Extensionless, versioned, private main settings and typed credential authority; root-owned `600`, never executable/sourced. Defaults are generated from code on a genuinely fresh installation. Ship no public config/template containing these settings. |
| `/jffs/addons/CFMgr.d/catalog.txt` | Separate snapshot-supplied module catalog; replaced with the selected verified package. Source repository/branch/full-commit selection and developer flag belong in main config, never catalog authority. |
| `/jffs/addons/CFMgr.d/setup-drafts` | Inert private DDNS/IP-Sync completed-input drafts, validation metadata and resume stage. |
| `/jffs/addons/CFMgr.d/setup-state` | Independently readable non-secret installation/generation and incomplete-operation/removal/reset guards; not an archive-restored execution authority. |
| `/jffs/addons/CFMgr.d/recovery/` | Small bounded private transaction metadata and recovery copies; available without Entware; retained while recovery is unresolved. |
| `/jffs/addons/CFMgr.d/cert.pem` | Original-byte validated account-certificate recovery copy with account/format/provenance/hash/generation association. No full user-YAML duplicate in JFFS. |
| `/opt/bin/cloudflared` | Verified official executable, with protected `.old` and pending-update companions where needed. |
| `/opt/etc/cloudflared/config.yml` | Full private advanced runtime YAML. Routine integrity owns the identity key trio; explicit B mapping Save may edit reviewed basic ingress entries while preserving other application options/comments. |
| `/opt/etc/cloudflared/credentials/` | Private selected runtime JSON, live administrative certificate and inventoried tunnel data. |
| `/opt/etc/cloudflared/import/` | Private advanced incoming files; preparation never changes a working generation or implies setup completion. |
| `/opt/etc/cloudflared/config.yml.bak` | Optional inventoried CFMgr-owned previous full YAML for manual recovery. Never adopt or overwrite a foreign `.bak`. |
| `/opt/var/lib/cfmgr/` | Compact tunnel binary/provenance/install/update observations; no native feature credential authority. |
| `/opt/var/log/` | Separate owned `cloudflared.log`, `ddns.log`, `ip-sync.log` and numbered rotations directly in this shared directory, only under eligible logging integration. Preserve unrelated logs and directory permissions. |
| `/opt/var/tmp/cfmgr/` | Larger tunnel download/restore staging and recovery on verified Entware. |
| `/opt/etc/logrotate.d/` | Separate owned feature fragments; never replace Scribe/global rules. |
| `/tmp/cfmgr/` | Private bounded boot-local locks, queues, status, discovery cache, retry state, temporary credential handoff and failure evidence. No frequent JFFS cache writes. |
| `<selected-mount>/CFBackup/` | Manual data-only archives at the chosen mounted drive's root, outside its Entware folder. |

Preserve shared parent permissions. Resolve aliases such as `/etc/cloudflared` only through verified canonical storage; a bare `/etc`, stale `/opt` directory, wrong replacement volume, JFFS or RAM filesystem is not a fallback for Entware data.

### Dependency policy

Normal manager operation, DDNS and IP-Sync require usable mounted Entware for the selected shared tools. Their settings and queues still reside in JFFS/RAM and they do not require a tunnel or custom logging. Native entry, diagnostics, recovery and safe Off/unhook/removal must remain available without working Entware.

| Capability | Selected policy |
| --- | --- |
| Runtime language and native utilities | BusyBox-compatible POSIX `sh`, verified firmware curl/CA and native utilities; explicit approved command paths and isolated environment. |
| Shared tools | `jq`, `coreutils-timeout`, `coreutils-sha256sum`. Ordinary non-regex jq operations; strict bounded JSON/schema/duplicate-key handling remains required. |
| Locking | Prefer usable native `flock`; add the Entware `flock` package only if necessary. |
| Tunnel DNS checks | Add `bind-dig` only where firmware DNS cannot provide the required SRV/A readiness checks. |
| Tunnel binary | Checked direct official Cloudflared download, independent of the opkg cloudflared feed package. |
| SHA-256 | Prefer verified sha256sum. Native OpenSSL may serve bootstrap/exceptional fallback, but does not excuse failure to install the required SHA package. |
| Archive tools | Prefer verified firmware tar/gzip. Add an essential missing capability only after documenting and approving its minimum support requirement. |
| Scribe/logrotate | Optional scoped custom logging; no automatic Scribe installation or global reconfiguration. |

At launch/install/update/reinstall, preserve healthy tools and install only missing/unusable mapped requirements. Use installed Entware opkg and its configured repositories with normal dependency resolution; refresh lists when installation is needed. Do not manually bootstrap dependency IPKs, switch feeds, use a restricted `--nodeps` route or upgrade every package. Normal opkg may process transitive requirements and existing unpacked package state; an explicit direct-package list is not a promise that opkg has no other normal side effects.

Coalesce concurrent repair behind one bounded worker. Recheck mount, ABI, executable behavior and required capabilities after installation: opkg exit zero or package database presence alone is insufficient. Failure blocks dependent work, preserves settings/intent and allows a bounded retry on a later launch, without an endless reinstall loop or permanent failure latch.

Advanced options has a separate confirmed **Reinstall Entware dependencies** action. It force-reinstalls only CFMgr's selected direct set and active scoped additions, lets opkg resolve libraries normally, handles a usable alternate provider such as `jq-full`, and performs post-probes. It does not reset configuration/activation, reinstall the Cloudflared daemon/hooks/workers or deliberately refresh unrelated healthy packages.

### Storage, platform and preflight

Before affected work verify root/JFFS/script support, safely parsed state, actual command capabilities, practical free space, private paths and required storage permissions. Verify `/opt`'s resolved mounted backing volume, persistent identity, filesystem/root and relative Entware location; directory/executable presence, mount label, `/dev/sdX`, kernel architecture or package-feed name alone is insufficient. Recheck attachment and identity through dependent stages and owned-child supervision, including lazy unmount and substituted paths.

Mount loss cancels/reaps only the action's verified owned children within a bounded cleanup policy, retains guards/recovery and reports unavailable storage. Never write into a leftover mountpoint, silently select another drive or wait in boot for the drive. A confirmed returning mount resumes only already configured eligible work, never an interrupted fresh tunnel creation. Software deadlines must not claim guaranteed termination of uninterruptible kernel I/O; retain unresolved ownership and prevent overlapping replacement work.

Native tool paths, curl TLS trust, loader/CA/proxy environment, kernel/userspace ABI and actual options must be proved for each supported capability profile. Target broad practical Merlin coverage, including older machines where requirements can be met, without inventing universal model/kernel support or an upper bound. Static firmware/feed evidence, host fixtures, BusyBox execution and live router acceptance are separate evidence classes. Downloaded firmware and raw private evidence remain ignored and must never be executed/flashed as part of an audit.

## 3. Configuration, menus and status

| ID | Subgoal | Required result |
| --- | --- | --- |
| S03.01 | Passive fresh state | All three unconfigured/Off; no tunnel/logging/backup setup; manager check On and auto-install Off. |
| S03.02 | Distinct state and settings | Separate configured/enabled/installed/maintenance, credentials, options, guards and observations. |
| S03.03 | Main menu and navigation | 0/1/2/3/4/fx/ao/u/uf/e with exact dispatch, dedicated nesting and no navigation side effects. |
| S03.04 | Feature submenus | Own setup, On/Off, explicit operation, status and scoped logging/repair; only relevant options. |
| S03.05 | Quick service commands | Shared case-insensitive start/stop handlers, ipsync alias, configure-first validation and truthful results. |
| S03.06 | Manager/diagnostic commands | Update/force aliases, help/version and identical standalone health/doctor/diagnostic reports without implicit repair consent. |
| S03.07 | Basic status dashboard | Router/resource/address header and compact feature state, last verified family updates, age and current issue summary from local evidence. |
| S03.08 | Bounded history and privacy | Small recorded observations, accurate Unknown/Never/stale labels, no basic-status network calls or secret/raw-data dumps. |
| S03.09 | Full health diagnostics | Basic dashboard plus failure-tolerant dependency/config/storage/network/auth/integration/recovery checks; eligible read-only probes, local fallback and no repair. |
| S03.10 | Terminal presentation | Clear grouped tables, useful header and issue summary; bounded one-shot output with narrow-terminal/plain-text fallbacks and no UI dependency. |

### Fresh defaults and saved state

Detect retained setup and incomplete guards **before** generating defaults. Missing/corrupt required retained state requires recovery, not an automatic fresh reset. Fresh base installation checks prerequisites and writes the passive manager/config only: no provider prompts, tunnel install, feature hooks or feature logging. Its independent manager update-check schedule is permitted under section 7.

| Setting/state | Fresh value or policy |
| --- | --- |
| DDNS and IP-Sync | `configured=false`, `enabled=false`; blank provider settings. |
| Cloudflared | `configured=false`, `enabled=false`, `installed=false`, `maintenance_enabled=false`. |
| Address-family policy | Auto for fresh setup; preserve explicit imported/restored per-feature family choices. |
| Feature custom logging | Inactive and no detection/files/rules before dedicated setup. This initial placeholder is not an explicit opt-out. |
| Backup | Destination unset; no folder/archive; retention selectable as 3, 4 or 5, proposed default 5. |
| Check for CFMgr updates | On. |
| Auto-update CFMgr | Off; requires saved explicit opt-in. |
| Developer mode | `developer=false`, manual config editing only. |
| Manager source selection | Main config defaults to `main`; developer mode retains an explicitly selected branch/full immutable commit for testing. |
| External amtm update permission | Off if that optional supported integration is later selected. |

`configured` means a complete validated setup, `enabled` is the user's saved On/Off intent, `installed` describes an owned binary/component installation, and `maintenance_enabled` separately authorizes Cloudflared maintenance. Running, connected, waiting, faulted and cleanup-required are observations/guards, not interchangeable flags. File presence, a draft or an updater preference never implies configured or enabled.

Store schema/data generation, explicit typed credential references and expected identities; DDNS zones/logical records/TTL/proxy; IP-Sync target names/IDs/mappings; shared WAN/family/discovery settings; tunnel mode/readiness/watchdog/binary-update preferences; per-feature logging preferences and policy; backup destination/date/retention; manager check/auto settings; and ownership/migration data. Keep activation, installed components, logging readiness, auth faults and installation/removal guards distinct. Credential serialization is data, never shell code.

Expose actual user choices in their owning submenu. Internal schema/generation/guard controls are not product settings. Bound timeout/retry/schedule/retention values, reject invalid input without changing working settings and preserve unrelated fields. No developer toggle, arbitrary source-URL menu or arbitrary manager-check cron-expression UI.

### Menu structure

| Main key | Actions and boundaries |
| --- | --- |
| `0` Check status | Compact local dashboard with router/resources, WAN/public addresses, configured/enabled services and last outcomes; return without setup or maintenance. |
| `1` DDNS | Dedicated setup/import and credentials/zone/record editing; On/Off; update now; status; address-family link; TTL/proxy/timeout/schedule; owned integration repair; scoped logging controls. |
| `2` Cloudflared | A1 existing token / A2 guided remote creation / B advanced setup; B hostname discovery and mapping editor; token/method editing; re-detect advanced config; On/Off, Restart, status; readiness/watchdog; setup-preserving binary maintenance/reinstall and separate full Cloudflared-only uninstall/reset; scoped logging/rotation. |
| `3` IP-Sync | Account/token and guided shared/separate family-list setup/import; On/Off; publish now; status; explicit read-only target check; address-family link; queue/retry controls; owned integration repair and scoped logging. |
| `4` Backup / Restore | Mounted destination/date/count setup; manual create; numbered list/inspect/verify/restore; confirmed selected-archive deletion. |
| `fx` Fix invalid credentials | Conditional on repairable saved auth faults; same serialized credential-only repair as the launch prompt. |
| `ao` Advanced options | Shared address settings; manager version/channel/config/install inspection; grouped **CFMgr updates** check/auto switches; selected Entware dependency reinstall; configured integration repair; full uninstall and Initialise/reset. |
| `u` Check for updates / Update CFMgr | Same check/revalidate/confirm path; label reflects known availability. Manual action works when automatic checking is Off, subject to developer suppression. |
| `uf` Force update / reinstall | Explicit complete selected-manager reinstall, including current version; never settings reset or a verification bypass. |
| `e` Exit / Back | Exit at root, Back in ordinary submenus; setup and commit behavior follows section 4. |

Parse exact complete tokens: `uf` cannot dispatch as `u`. Unknown input has no effect. Selecting a submenu, viewing settings, backing out or opening status never enables a feature. Keep current On/Off values visible beside settings. One feature's wizard never demands setup or credentials for another.

Configured feature logging menus offer **Install/enable logging** and **Uninstall logging** for that feature. The visibly shared **Re-detect logging / enable for all enabled services** action also checks Scribe and applies section 13 across enabled CFMgr features. Only Cloudflared offers rotation tuning. No global Scribe daemon control, native-feature rotation tuning or separate temporary Stop logging/Stop rotation UI.

### Commands

Plan `cfmgr start <service>` and `cfmgr stop <service>` using the same On/Off handlers as menus. Accept case-insensitive verbs/service names, canonical `cloudflared`, `ddns`, `ip-sync`, and `ipsync` alias. Reject missing/extra/unknown identifiers; no implicit global action. Unconfigured, draft-only or maintenance-only service calls return configure-first without install, toggle, provider or integration mutation. Corruption returns repair-required.

Cloudflared Start sets On and can recover a missing owned binary through the checked installer; Stop sets Off and clears maintenance activation too. Restart requires a valid already-On tunnel and never enables Off. Native Stop quiesces only its owned work and preserves the other native feature/shared integration when needed. Repeated valid actions converge idempotently. Report named steps and actual stopped/deferred/failed results without secrets.

Provide descriptive manager aliases `update` and `forceupdate` through the same confirmation/transaction policy as `u`/`uf`. Missing stdin never implies consent. Provide help/version and canonical `--health`, with `--diagnostic` / `--doctor` aliases producing the same full report. Freeze other operation command spellings when their complete menu workflows are implemented; do not advertise speculative commands in operating guides.

### Status and diagnostics

Both pages use a compact terminal header and readable grouped tables. Basic status
is the quick operational view; `--health` includes that view plus the diagnostic
causes and recovery guidance behind unavailable, waiting, partial or failed states.
Neither page claims that an unknown or untested condition passed.

| Display area | Basic status, choice 0 | Additional full-health detail |
| --- | --- | --- |
| Router and resources | Router model, firmware, uptime, current load, memory used/available and JFFS/Entware space/mount summary where natively available. | Kernel/userspace/ABI, supported native options, path permissions, mounted-volume identity and prerequisite failures. |
| Manager | Version, selected source/channel, configured/enabled service summary and compact current warning. | Entry/module/catalog completeness, compatibility, config/schema problems, incomplete installation/update/removal and recovery guards. |
| Network | Selected WAN/interface; observed WAN IPv4 with Public/Private/shared-CGNAT classification; separately recorded public IPv4 and eligible IPv6, source age and NTP state. | Discovery/egress/family evidence, missing/stale observations, outage/readiness reasons and eligible bounded read-only refresh. Never label every private address CGNAT or use a private address as the public result. |
| DDNS and IP-Sync | On/Off/configured, last verified IPv4/IPv6 values and update time per feature, latest result and short pending/error reason. | Per-family/target failures, saved credential faults, relevant read permissions, recent bounded errors, retry/cooldown and why work is blocked. |
| Cloudflared | On/Off/configured, installed version, observed running/connected/waiting state and last relevant outcome. | Selected-method config/credential integrity, ownership, connectivity evidence, binary/update/watchdog and management-versus-runtime credential problems. |
| Integrations | Concise recorded logging/readiness or recovery warning where relevant. | Owned hooks/jobs, independent maintenance state, requested Scribe/logrotate readiness, backup destination/history observations and pending safe cleanup. |

Show feature configured/enabled values separately from runtime observations. Off
features do not trigger operational probes from basic status; a saved auth fault or
cleanup reason remains visible so Off does not hide the problem. No configured
feature gives configure-first guidance; configured-but-Off gives enable guidance.
Invalid enabled-without-configured state is reported without rewriting it.

Record the last verified DDNS and IP-Sync outcome separately, including family,
published/verified/removed result, value where applicable, timestamp/age and partial
failure. A discovery result is not a successful provider update. A live PID,
two-second survival, metrics, file timestamp or restored history does not prove
current authentication, connectivity or publication. Mark absent evidence Never,
Unknown, Unavailable or stale as appropriate; show observed errors separately from
historical ones and provide a short relevant next action.

Basic status does no provider/network lookup, update check, download, sync, restart,
repair, forced rotation or full logrotate validation. Use bounded native resource
snapshots rather than a sampling loop. Keep status in private bounded RAM, with a
proposed recent-event display limit of five. Eligible owned logs or bounded verified
tagged system messages may supply history; deduplicate and bound scans. Missing
logging never blocks either page, and metadata failure cannot undo provider success.

`--health` is admitted before normal startup, dependency repair and update checks.
It must remain useful after failed/incomplete installation, missing modules/tools,
unmounted Entware or corrupt config. Keep a minimal native diagnostic/reporting
path available from the trusted entry; optional verified diagnostic modules extend
it. Missing modules must produce a named failure and retain independent native
checks, not crash into the normal manager or auto-download code. Broken config
skips only checks that need that config. If the entry itself is absent, a trusted
standalone copy must provide the same native fallback without installing first.

Full health groups checks by system/dependencies, package/config/storage, network,
each feature, hooks/jobs, logging and recovery/backup. Use stable check IDs and
explicit PASS/FAIL/WARN/SKIP/UNKNOWN with a concise cause, evidence age and next
action. Distinguish missing, installed-unusable, unsupported, prerequisite-blocked,
untested permissions, observed auth rejection and transient transport/throttle.
One root failure should explain dependent skips rather than manufacture many
independent failures. Summarize blocking issues before optional detail; bounded
read-only checks never promise to discover every possible remote/runtime fault.

Use read-only network/provider checks only for explicitly configured credentials
that pass local validation and are not already known rejected, with usable trusted
tools, NTP/storage/transport prerequisites and proved action bounds. Credentials
missing, malformed, recorded invalid or unusable prerequisites keep that scope
local-only. For eligible scope, a supported read-only validation/read can establish
current credential evidence and refresh relevant public-IP/target observations in
report-local memory. Rejection stops further authenticated probes for that scope
and falls back to local evidence; lack of an appropriate non-mutating validation
method is UNKNOWN, not a successful auth claim. Read access does not prove write
permission, and tunnel runtime authentication is not proved by management API
access. Never start a connector or perform a test write to obtain evidence.

Diagnostic probes respect existing cooldowns and shared resource/transport bounds;
throttling/outage reports deferred/unknown without aggressive retries. They do not
invoke the mutating auth-Off/credential-repair path, clear saved faults, change
activation/settings, enqueue publication or replace operational success/history
with a diagnostic result. No package install, update, service action, API write or
automatic repair. Private synthetic probe files/children are bounded and cleaned
only by proved ownership; no hard deadline claim without a working supervisor.

Presentation is a one-shot text page with a small htop-inspired resource/address
header and diagnostic-table layout, not a continuously refreshing monitor. Use
clear columns such as Check, State, Detail and Next action, with optional restrained
TTY color. Labels must remain useful without color; narrow terminals wrap or use
stacked rows, and redirected output uses plain text without cursor-control codes.
No dependency on htop, Codex, curses or an external table renderer. Escape unsafe
terminal controls in labels/errors. Show the requested local/public IP evidence,
but never raw config/environment/NVRAM, tokens, tunnel secrets, certificate contents,
authorization headers, account identifiers or unrelated device identifiers.

## 4. Save, cancellation and recovery

| ID | Subgoal | Required result |
| --- | --- | --- |
| S04.01 | Safe data parsing | Bounded schema/JSON/certificate/YAML/catalog inputs treated as data, never sourced/evaluated. |
| S04.02 | Scoped concurrent Save | Accepted fields overwrite same-field edits, preserve unrelated guards/settings, detect content changes and respect later Off. |
| S04.03 | Durable staged commit | Pre-change intent/recovery, verified coherent publication and honest flush/write/rollback failure handling. |
| S04.04 | Native resumable drafts | Completed private DDNS/IP-Sync inputs survive exit/signals without touching active config or enabling work. |
| S04.05 | Cloudflared Save boundary | Pre-Save cancellation; mutation-time e disabled; signals honored with bounded cleanup and guarded recovery. |
| S04.06 | Input/terminal handling | No EOF/default-yes or noninteractive prompting; restore echo, reject unsafe controls and preserve literal data. |
| S04.07 | Restart recovery | Inspect guards before activation, preserve damaged/recoverable data and never repeat uncertain provider creation. |
| S04.08 | Ownership and locks | Stable lock identities, verified process start/boot identity, correct provider-child versus connector descriptor lifetime. |
| S04.09 | Generation and resource bounds | Compatible package per invocation, current-state checks, late-result rejection and bounded whole-action cleanup. |

### Safe configuration transactions

Parse configuration, catalog, JSON, certificate and supported YAML forms as bounded data. Reject malformed/ambiguous/duplicate fields, invalid encoding/framing, unsafe paths and unknown required schemas. Do not source/eval data or rebuild full user YAML through a lossy parser. Freeze supported syntax and resource bounds before its dependent workflow.

At reviewed Save, briefly lock and reread current valid authority. The wizard's explicitly accepted fields overwrite same-field manual edits; preserve unrelated settings, ownership, current auth/removal guards and other features. Detect raw content changes without revision bumps and retry a bounded scoped merge. A later valid Off or configuration change wins over an older worker. Never hold config/queue/lifecycle locks across user input, browser login or network waits.

Check space, path ownership and ability to record intent before changing live state. Persist a small durable guard/journal and recovery copies before active mutation, stage validated data, commit one coherent generation and clear the guard only after verified completion. Prove write/rename/flush failure behavior; exit zero alone is not durability evidence. Cross-filesystem operations need explicit recoverable stages, not a false atomicity promise.

If a pre-change guard cannot be saved, abort mutation with the old valid state intact. An observed auth failure whose durable fault cannot be written uses a boot-local containment guard and reports the persistence limitation; never claim durable Off or reboot safety. Preserve unresolved recovery material and damaged user data instead of overwriting evidence or repeatedly retrying a destructive action.

### Input and interruption

| Point | Required behavior |
| --- | --- |
| Ordinary navigation / pre-Save Cloudflared | `e` cancels/returns without activation or remote creation. |
| Native DDNS/IP-Sync setup | Privately checkpoint completed valid token/account/zone/selection fields, not keystrokes. `e` exits Setup; Ctrl+C exits safely; completed draft survives. Next Setup resumes missing/invalid stages. |
| Native draft isolation | Draft never overwrites working config/shared credential authority, creates operational integration or enables an incomplete feature. Draft write failure is reported; do not claim it was saved. |
| Reviewed Cloudflared mutation | Disable `e` Back through installer/login/create/config commit; explain work is committing. Ctrl+C/HUP/TERM remain honored with bounded owned-child cleanup and guarded recovery when outcome is uncertain. |
| Other destructive/transactional Save | Show effects before confirmation; after commit begins use the same bounded interruption/recovery discipline. Empty input/cancel cannot authorize wipe, force replacement or remote recreation. |
| EOF / missing TTY | Never interpret as default yes, loop forever or prompt from hooks. Restore terminal echo after masked input on every exit/signal path. |
| Restart after interruption | Inspect independently readable guards first. Resolve or quarantine affected work before normal activation; no blind repeat of provider creation or silent fresh defaults. |

Read names literally, reject unsupported control characters and encode them for their real transport. Native setup resume may revalidate completed credentials/targets without forcing valid fields to be reentered. A draft remains inert data in backup/KEEP and is removed only by owned WIPE/reset.

### Ownership and concurrency

Use stable lock-file identities, a documented lock order and nonblocking admission where required. Never unlink a live lock to unlock it. Verify process identity using boot/process-start and action ownership, not a name or stale PID. Long-lived connectors close controller/update/config/queue descriptors; an in-flight provider child retains writer exclusion until it exits or is safely quiesced. A killed worker must not leave an untracked concurrent curl writer.

Pin a compatible installed package generation per invocation. Recheck relevant configuration/source/credential content and generation before writes or activation. Discard late results without losing newer requests. Bound worker/child counts, aggregate runtime, staging/response sizes, queue batches and cleanup. An unresolved owned child prevents overlapping replacement work; unrelated processes are never killed or adopted by inference.

## 5. Cloudflared setup and credentials

| ID | Subgoal | Required result |
| --- | --- | --- |
| S05.01 | A1 existing-token setup | Existing dashboard connector token, optional guide, private authority/handoff and no inactive YAML or extra management credential requirement. |
| S05.02 | B choice and import | y import versus n/Enter fresh; private placement/re-scan, explicit candidate and full referenced-data validation. |
| S05.03 | Fresh named creation | Reviewed Save, checked installer, same-account certificate/login, named CLI create and hostless http_status:404 starter. |
| S05.04 | Mode switching | One selected method/connector, validate candidate first, preserve Off and inactive/foreign material. |
| S05.05 | Advanced configuration validation | Published-app and private-network shapes, valid UUID/JSON, safe required paths and no guessed routing. |
| S05.06 | Master and owned YAML fields | Same account/UUID/secret JSON; routine identity-trio repair separated from explicit reviewed B ingress edits, preserving all other YAML. |
| S05.07 | Runtime integrity no-op | Matching files untouched; only real selected runtime drift repairs/restarts; missing whole YAML needs full recovery. |
| S05.08 | Certificate recovery/provenance | Original bytes with account/format/hash/generation, no redundant JFFS copy or missing-cert login loop. |
| S05.09 | Browser login authority | Current attempt/path/account validation, private terminal URL, no foreign-cert overwrite or login-only runtime-secret claim. |
| S05.10 | Unknown NEW creation | Guard incomplete outcome, preserve old generation and require manual dashboard cleanup/explicit retry; no auto lookup/create. |
| S05.11 | Existing-ID credential repair | Same-tunnel token or supported same-UUID JSON fetch; local regeneration never clears proven auth fault. |
| S05.12 | Explicit replacement | Default-no only after conclusive recovery failure; preserve full application YAML/owned .bak and manual old-tunnel deletion. |
| S05.13 | B hostname mappings | Discover exact selected-tunnel DNS routes and add multiple reviewed hostname/origin mappings with guarded DNS creation, lossless ingress edits and truthful partial recovery. |
| S05.14 | A2 guided remote creation | Separate account management credentials create a dashboard-managed tunnel after Save; verify/store connector token privately, with guide fallback and no blind create retry. |

### Setup choices

Support exactly one selected connector/runtime method. Multiple ingress services in that tunnel are allowed. Inactive method data may be preserved, but cannot cause an implicit switch or second connector.

**A — Dashboard-managed token runtime (default):** offer **A1 existing token** or
**A2 guided creation**. A1 accepts the user's existing/dashboard-created connector
token with optional dashboard instructions. Mask/store it privately; do not require
a shell installation command, browser cookie, account/zone ID, account certificate
or management API credential for A1.

A2 collects a tunnel name, account ID and separately typed management API token
with the required tunnel-create permission. After reviewed Save and durable intent,
use the supported Cloudflare API to create a remotely managed tunnel, verify the
returned account/UUID/management mode, and obtain/store its connector token through
the supported response or token endpoint. A connector token alone is not management
authority. The tunnel remains dashboard-managed; A2 does not create local B YAML or
start managing its applications/Access policies. Offer dashboard guidance/A1 when
creation is unavailable or the user declines management credentials; never silently
switch to B, broaden permissions, or infer that a timed-out create did nothing.

Both A paths use the same checked binary/maintenance setup, local Save/activation
review and runtime handler. Local token shape does not prove remote acceptance.
Derive a private transient `--token-file` handoff from master config where supported;
never expose the token in process arguments or load stale default YAML. Both A and
B use `--no-autoupdate` so CFMgr owns binary updates. Failed/unknown A2 creation uses
the same durable incomplete-result guard/manual dashboard cleanup policy as NEW B
creation, with no blind retry or automatic remote deletion.

**B — Advanced:** ask `Auto-detect/import existing advanced config? [y/N]`. `y` enters import; `n` or Enter enters fresh named-tunnel creation. Re-detect/import is an explicit B-only action, not a token-file import path.

The fresh starter contains the confirmed UUID and credential path with a final
`http_status:404` ingress rule. Hostname/origin examples remain comments until the
user adds mappings through the reviewed B editor. A hostless valid starter may
complete setup; applications are never invented or created without those choices.

| Advanced path | Required workflow |
| --- | --- |
| Import | Prepare/show private incoming directory, let the user place files, Continue/re-scan, then select and validate one YAML/JSON identity and any actually required referenced files. Review/Save before replacing working files or selecting B. No login, remote creation or guessed routing. |
| Fresh creation | Collect minimum name/intended account context. Warn about existing selected local files in the normal review. After Save/guard/checked binary staging, reuse a validated same-account management certificate or perform supported browser login, then named CLI creation and private credential capture. Generate only a hostless starter/commented examples, never invented applications. |
| Mode/token change | Validate candidate before disturbing old runtime. Preserve inactive credentials, full valid user YAML, foreign files and old recoverable generation. Preserve Off unless explicitly changed. One controlled replacement only after validation/readiness. |
| B hostname/origin mappings | Discover existing routes for the selected UUID and add multiple explicit hostname-to-origin mappings; review DNS and ingress effects together before Save, independently of remote tunnel creation. |
| Missing/ambiguous candidates | Explain missing/invalid paths or multiple identities and require explicit selection/repair. File appearance alone never configures/enables or selects a method. |

Both A/B setup and explicit maintenance Install/reinstall force-fetch a verified official binary at reviewed Save, even if an owned one is present. Normal On reuses a healthy binary and fetches only when missing. Normal updater skips current. Stage/verify before stopping a working connector. Base installation never invokes a tunnel wizard.

Advanced validation must distinguish published-application YAML (including native ingress validation and required final catch-all) from supported private-network-only configuration. Lack of application ingress alone cannot reject the latter. Check paths/permissions, real UUID, matching JSON account/identity/secret and actually used certificates; reject placeholders, duplicate/ambiguous owned keys and conflicting unmanaged token/config/logging controls. Use a tested native supported subset and Cloudflared validation rather than adding a YAML dependency or assuming arbitrary YAML can be rewritten losslessly.

### Master authority and exact owned fields

The main config retains full typed B `AccountTag`, `TunnelID`, `TunnelSecret`, credential references and expected identity. Runtime JSON derives the **same** values, mode `600`. A retains its opaque runtime token separately. Native API credentials, optional genuinely selected management API credentials and login certificates are different types; equal strings do not establish sharing or authority.

Routine integrity/recovery owns advanced YAML `tunnel`, `credentials-file`, and
`origincert` only when a certificate path was selected. Preserve all other bytes,
options, ingress and comments during that routine repair. The explicit B mapping
editor is a separate reviewed permission to change selected basic ingress entries;
it does not make the entire ingress section automatically managed. Direct edits to
owned identity fields are reconciled from validated authority, not adopted as new
authority. Missing JSON/owned keys can be reconstructed under a guarded transaction;
missing whole YAML requires complete known-good recovery/archive/import, never a
replacement starter that loses applications. Invalid user YAML stays available.

### Advanced B hostname discovery and mapping editor

Offer discovery and creation in dedicated B setup/settings. Select a domain/zone
and discover existing Cloudflare DNS records whose verified route target matches
the configured tunnel UUID. Prefer supported cloudflared commands where they prove
the necessary result; otherwise use authenticated, complete bounded DNS enumeration
with separately typed scoped DNS credentials. Do not invent a CLI listing command,
require DDNS feature setup, list unrelated tunnels, or mistake an ordinary A/AAAA
record/public DNS proxy address for proof that a hostname belongs to this tunnel.

Let the user select an existing matching hostname or add several new hostnames,
supplying each origin service URL/protocol/port explicitly. DNS discovery alone
does not supply the local origin mapping. Validate names, zone scope, supported
origin syntax and local ordering before reviewing all proposed changes. Reuse
verified identical routes; conflicting foreign DNS records or another tunnel's
route require explicit resolution, never silent takeover/deletion.

Save may create the required DNS route using supported `cloudflared tunnel route
dns` behavior or the verified Cloudflare API and add the reviewed basic ingress
entries. Preserve manual `originRequest`, path-specific rules, ordering, comments
and other settings. Retain a valid final catch-all and do not duplicate it; a fresh
starter supplies 404, while existing manual catch-all choices remain user-owned.
Stage lossless YAML edits and validate the whole result before active mutation.
Unsupported or ambiguous YAML is retained with a clear manual-edit requirement.

Track local publication and each remote record independently in one guarded Save.
DNS plus YAML are not remotely atomic: interruption/partial success preserves the
previous recoverable file, per-mapping outcomes and needed next action. Re-read
exact DNS scope after uncertain responses before retrying; no duplicate create,
blanket rollback deleting foreign changes or false all-mappings success. Recheck
concurrent YAML/config changes and newer Off before commit/activation. One real
reviewed mapping change may request one readiness-gated restart of a still-On owned
connector; ordinary launch/health/integrity never rewrites routes or reconciles
manual ingress edits into a forced restart. Off remains Off.

Run the same selected-method local integrity gate before starts/watchdog activation and manager update/reinstall. A does not require inactive B files; an unconfigured/native-only installation has no tunnel-file requirement. Healthy matching runtime means no rewrite, JFFS certificate resnapshot, binary download, provider request or restart. User ingress edits, file mtimes, inactive-method changes and management-only changes are not restart triggers. A real validated selected runtime change may coalesce one internal readiness-gated restart of a still-On verified owned connector. Off stays Off.

Local file reconstruction never proves remote authentication or clears an auth fault. Invalid/missing authority requires reviewed repair; never guess UUID, adopt a foreign secret or repeatedly regenerate a known-rejected secret as an auth fix.

### Certificate provenance and browser login

Validate supported Cloudflared credential PEM/account/endpoint formats; do not assume it is an ordinary X.509 certificate. Preserve complete original bytes in both its selected Entware location and the private JFFS recovery copy, with account/format/provenance/hash/generation metadata. Capture a copy on successful reviewed login/import/repair replacement; seed a missing JFFS copy only from a trusted validated existing certificate during explicit migration/reinstall/update. Matching content produces no redundant JFFS writes. Bound practical certificate size/space without guessing from one sample.

A trusted matching copy can recover a missing runtime certificate. Missing optional cert alone does not invalidate UUID+JSON runtime or initiate login from ordinary launch/boot/watchdog/import. Copying does not renew rejected management authority.

Fresh/replacement creation or explicit existing-ID credential retrieval may request browser authorization if no usable same-account certificate exists. Display the login URL only in the terminal; keep callback/material private. Verify current attempt/child, actual supported write path, account and certificate contents—exit zero or file appearance is insufficient. Do not assume `--origincert` redirects login output, repurpose HOME, overwrite foreign/default certs or require a headless browser. Login yields management authority; it does not itself yield a runtime secret for an existing tunnel.

### Failed fresh creation and existing-tunnel repair

Before NEW create persist small intent and use fresh private output. Track remote creation, local data commit and runtime authentication separately. A complete confirmed UUID plus trusted complete credentials can recover the same local result without another create. An ID alone, partial JSON, lost response, nonzero CLI result or apparent CLI rollback cannot prove success or remote absence.

For failed/incomplete/unknown NEW creation, keep setup inactive/guarded, preserve old generation and tell the user to inspect Zero Trust and manually remove any failed tunnel before an explicit reviewed retry. No automatic tunnel listing, unknown-result lookup/adoption, remote deletion, due-job create or returning-mount create. Mount loss during installer/login/create/repair boundedly interrupts owned work and warns of a possible orphan. Do not claim a locally failed Save undid remote creation.

For an existing rejected tunnel, attempt identity-preserving repair first:

- A requests a current token for the same dashboard tunnel, without rerunning unrelated setup.
- B uses a trusted same-account certificate, or accepted login if required, then a supported same-UUID credential retrieval such as verified `token --cred-file` behavior. Stage fresh JSON; verify account/UUID/new credential; update master/derived data coherently and retry through normal gates. Version/provider/local-management limitations must be proved.
- Outage, throttling, mount failure or repairable permissions never force recreation. Unsupported/inconclusive evidence remains repair-required, not a guessed deleted tunnel.
- Only conclusively unrecoverable/deleted/unsupported identity offers a **separate default-no reviewed replacement**. Preserve full valid application YAML and a private owned `config.yml.bak`; change only the owned trio where possible. Malformed user YAML remains available for manual re-patching. Explain manual old-tunnel deletion; CFMgr never deletes it automatically. Decline/`e` leaves affected runtime Off.

## 6. Tunnel lifecycle and binary maintenance

| ID | Subgoal | Required result |
| --- | --- | --- |
| S06.01 | Activation state model | Correct configured/On-Off/installed/maintenance/update preference effects for every action. |
| S06.02 | One lifecycle controller | Shared control with independent download/activation locks and cheap healthy path. |
| S06.03 | Readiness gates | Expected storage/tools plus shared NTP/family-aware reachability and tunnel DNS, rechecked before launch and ordinary restart. |
| S06.04 | Outage and connectivity | Saved On retained, PID distinguished from connected, bounded grace/recovery and no restart storm. |
| S06.05 | Owned stop/containment | Bounded normal TERM, no routine unsafe replacement, narrowly rechecked corruption/auth escalation only. |
| S06.06 | Retry and stability | Shared monotonic outage retry at 1/2/4/5 minutes, five-minute cap, coalesced events, sustained-stability reset and no tick JFFS churn. |
| S06.07 | Official binary acquisition | Bounded exact origin/tag/asset SHA-256/ELF/version validation before stop or replacement. |
| S06.08 | Foreign binary ownership | Fixed bounded lookup and explicit adoption, no wrapper/symlink/foreign controller overwrite. |
| S06.09 | Version policy | Equal skip for updater, explicit equal/newer reinstall, no downgrade except protected rollback. |
| S06.10 | Idle versus On recovery | Artifact-only maintenance needs no tunnel launch; On uses fresh owned evidence, Off races win and rollback reports failed update. |

### Activation state table

| Action/state | Tunnel | Installation/maintenance | Integrations |
| --- | --- | --- | --- |
| Fresh | Unconfigured/Off | Uninstalled; maintenance Off | None. |
| Explicit maintenance install/reinstall | Unchanged, including unconfigured/Off | Verified installed; maintenance On | Updater only if saved binary auto-update preference is On; no runtime watchdog without configured+On. |
| Configured Start/On | Valid configured/On | Reuse healthy binary or checked missing-binary recovery; maintenance On | Runtime/event/watchdog; updater only if its saved preference permits. |
| Stop/Off | Configuration preserved; Off | Installed files preserved; maintenance Off | Remove **all** Cloudflared runtime/watchdog/updater/maintenance eligibility and exclusively owned integration; retain the shared watchdog if another scope needs it. |
| Later maintenance install while tunnel Off | Remains Off | Maintenance On | Updater may run; no connector/watchdog. Another Off clears maintenance again. |
| Binary/updater/watchdog uninstall | Configured data retained; Off | Installed=false only after verified removal; maintenance Off | Detach all owned runtime/maintenance integration; remove only owned/adopted binary/helper/old/staging files. |
| Restart | Requires valid already-On | Verified installed/current generation | One bounded replacement; cannot enable Off. |
| External process kill | Saved On remains On | Unchanged | Watchdog may recover through readiness; no extra persistent manual-stop flag. |

All actions obey installation/auth/removal/recovery guards. Service Off and maintenance uninstall preserve tunnel data, settings, logging preference/history/rules and Scribe rotation. Failure to stop/remove remains guarded cleanup-required, not a false uninstalled/stopped result.

### Controller and readiness

Boot, WAN, watchdog, manual control, update, logging transitions and restore share one lifecycle controller. Separate updater download and lifecycle locks so metadata/transfer does not block normal watchdog recovery. Healthy unchanged service takes a cheap path; no routine restart or expensive recovery.

For tunnel start and ordinary restart require a trusted complete generation, valid configuration/activation, actual expected writable Entware, shared tools and the common NTP/reachability gate in section 12, then required bounded tunnel SRV/address resolution over usable transport. Recheck after acquiring locks and after WAN settle. Ordinary readiness failure must not stop a healthy connector just to attempt restart. Native publishing and idle binary maintenance use the common gate without requiring tunnel credentials or tunnel-specific DNS; IPv4 failure alone cannot block a supported usable IPv6 path.

Preserve a two-second startup observation as process-start evidence only. Verify connectivity separately. During Internet loss a still-owned connector may perform normal reconnects; do not repeatedly kill it because probes fail. A missing connector waits until required gates return. Persistent evidenced disconnection uses a bounded reconnect grace/recovery policy; unknown connectivity is reported unknown, not auth failure.

Normal stop uses verified owned TERM/wait, bounded by a 35-second ceiling, shortened for firmware shutdown/unmount budgets. Failure to quiesce forbids routine replacement or deletion of an open logfile. Only corruption or definitive auth containment may escalate to targeted KILL after rechecking still-owned identity under a closed gate; never for generic throttle/transient failure or by process name. Uncertain ownership retains guard and honest cleanup-required state.

Use the shared boot-local retry policy in section 12 rather than a separate tunnel timer. Retain connector-specific crash/connectivity history: one successful probe or two-second process survival does not erase repeated startup failures. Confirmed sustained stability resets the applicable delay/failure state. Bound the selected reachability probes; initial per-probe budget is one packet, two-second response and three-second command ceiling, subject to supported-tool validation.

### Official acquisition, activation and rollback

Acquire only for reviewed setup/maintenance install, valid configured On with missing binary, restore/retained reconstruction or eligible scheduled update. Match official repository/origin, release tag and exact supported userspace architecture/ABI asset. Bound HTTPS metadata/body/time, require an independently trusted exact-asset SHA-256, then validate ELF and bounded product/version output before replacement. Self-computed digest, filename, HTML body, command exit zero or kernel architecture alone is insufficient.

Use bounded canonical/approved legacy path lookup, never recursive scans. Reject wrappers, unsafe links, read-only firmware targets and foreign/unclaimed binaries/controllers. A product version does not prove CFMgr ownership; adopt foreign installation only through reviewed migration. Preserve unrelated init scripts, connectors and configs.

Normal updater skips equal versions and refuses downgrade before transfer and after locked recheck. Force reinstall may install equal/newer, not downgrade. Protected rollback to the old verified binary is the recovery exception. Do not add release blacklists, pins, skip-version controls or version cooldowns.

Stage on verified target storage and validate before stopping. Protect known-good `.old` and transaction identity until recovery is resolved; a new update cannot overwrite unresolved evidence. Recheck mount, version, configuration/activation and readiness under the appropriate locks before switch.

Idle Off/unconfigured maintenance completes verified artifact publication/recovery without tunnel credentials, tunnel DNS or launching a connector. On activation requires fresh owned-child/start evidence and readiness; an unrelated/existing PID cannot clear the pending marker. If startup fails, distinguish outage from a bad candidate before rollback. Successful rollback still reports that the attempted update failed and the prior service was recovered. Concurrent Off wins; unavailable/ambiguous recovery stays bounded and guarded, never enables a service to clear a marker.

## 7. CFMgr updates, source selection and developer mode

| ID | Subgoal | Required result |
| --- | --- | --- |
| S07.01 | Check and auto settings | Default-On checks/default-Off opt-in install, coupled effective settings independent of tunnel/Entware. |
| S07.02 | Launch/daily checks | Bounded coalesced source checks, once-per-launch y/n update offer, RAM metadata and truthful unknown/error without redraw or boot blocking. |
| S07.03 | Manual update/force | Explicit revalidation/confirmation, current skip or complete reinstall; compatible older manager snapshot only through confirmed developer force. |
| S07.04 | Unattended installation | Saved opt-in and source/ownership rechecked at switch; active transactions defer safely. |
| S07.05 | Developer suppression | Manual-only flag suppresses checks/auto/external callbacks; confirmed force retains normal verification. |
| S07.06 | Source selection and catalog | Main config selects repository/branch/full commit; snapshot catalog maps modules in one immutable complete package. |
| S07.07 | Developer source retention | Developer keeps selected source; normal updates return the selector to main; every package replacement also replaces its catalog. |
| S07.08 | Trusted complete package | Manifest/hash/version/schema/path/syntax checks before execution, one pinned compatible generation. |
| S07.09 | State-preserving update | No healthy feature reinstall/restart/provider call or config loss; guarded actual owned drift only. |
| S07.10 | Self-update failure recovery | Distinct transfer/storage/switch/hook-reinjection/overlap/opt-out/rollback boundaries preserve last trusted complete package and report incomplete integration honestly. |
| S07.11 | Optional amtm | User-chosen personal launcher; official updater conditional with separate opt-in, no private registry hacks. |

### User controls

Group **Check for updates** (On by default) and **Auto-update CFMgr** (Off by default) in `ao` → **CFMgr updates**. Enabling automatic installation enables checking; disabling checking disables automatic installation. Show both effective values. These settings are independent of Cloudflared binary updates, Entware maintenance and any future amtm permission.

| Trigger | Behavior |
| --- | --- |
| Interactive launch, checks On | After integrity/recovery admission, perform/coalesce a bounded selected-source check. If a valid newer compatible update is already known or found, show current/available identity and ask `Update CFMgr now? [y/n]` before the normal menu. Revalidate before a confirmed install; no repeated offer on redraw in that launch. |
| Owned daily check | One fixed code-defined daily schedule, shared helper/lock/due/backoff. Skip/defer on unavailable prerequisites, active ownership, recovery/removal or developer mode; no blocking boot work. |
| `u` / `update` | Check even when automatic checking is Off; show current/available identity, revalidate and ask `Update CFMgr? [y/n]`. Only explicit yes installs. Current skips package replacement after required local integrity comparison. |
| Decline/error | `n`, empty or `e` declines the foreground install and opens/returns to the menu; EOF never authorizes it. Do not repeat the same automatic offer in that launch; explicit `u` may recheck and ask again. Offline/timeout/invalid metadata means unknown/check-failed, never already-current; installation unchanged. |
| Saved Auto-update On | A proved newer compatible selected-source revision may use the same verified transaction without per-update prompt. Recheck opt-in/source/config/ownership immediately before activation, including queued work. |
| `uf` / `forceupdate` | Explicitly confirm target/reinstall even when current. Developer mode may deliberately select an older compatible manager snapshot for testing; trust/schema/storage and state-preservation checks still apply. This does not authorize a Cloudflared binary downgrade. |
| Status, redraw, doctor, feature hooks | No repeated check or update. Hooks may register/dispatch the independent bounded timer, not perform foreground transfer. |

A launch offer needs current matching source/version evidence; stale metadata, a changed source or developer mode cannot authorize it. Saved unattended auto-update remains a separate opt-in path; coalesce ownership with foreground offers and never replace code beneath an active menu/confirmation. Declining the foreground offer does not silently change saved check/auto preferences.

Cache availability/due state in bounded RAM, not JFFS per tick. Coalesce launch/timer/manual overlap; use main-config source selection under the developer policy below and retain the action's resolved commit pin. For development branches compare verified commit identity coherently even when a development version string is unchanged. Defer a switch while interactive/mutation owners or recovery would make it unsafe; do not replace modules beneath an invocation using another generation.

### Catalog and developer behavior

`developer` and manager source repository/branch/full-commit selection are manual-file-only main-config settings. True suppresses automatic/manual manager checks, offers, unattended installation and external check/update callbacks while preserving saved preferences. It does not alter Cloudflared update preferences. Explicit confirmed `uf` uses and retains the configured developer source, with a clear target warning and normal verification. Editing a selector alone fetches or activates nothing.

With developer=false, effective manager update/reinstall selection is `main` in the configured repository; a successful transaction also resets the saved branch/commit selection to `main`, preserving unrelated settings. With developer=true, retain the selected branch or full immutable commit across reinstalls. Failed/cancelled transactions do not reset source settings or partially publish another source. Show the effective source before confirmation. There is no menu source setter or remote `catalog_url` indirection.

`catalog.txt` remains in the repository root and installed manager directory. It is package data mapping named modules to validated paths/URLs, not the authority for branch/commit selection. Every successful package replacement, including developer `uf`, installs the catalog from that same verified snapshot with its matching entry/modules. Developer mode no longer preserves old catalog bytes. Validate bounded catalog grammar, approved HTTPS repository, commit binding and safe destinations before use; malformed installed catalog requires explicit verified repair, never a silent switch to another source.

Resolve a selected branch once to an immutable full commit; acquire its manifest, catalog and complete required tree from that snapshot. The tree already includes unchanged files last edited before the selected commit. Do not resurrect files deleted by that commit, invent modules absent from its tree, scan history to fill gaps or mix in current modules. Retain the action's pin and recheck main-config source/intent before activation. Unsupported old package/schema formats fail with a concrete compatibility explanation.

An explicitly selected older manager snapshot is allowed only through reviewed developer `uf` when it can safely read/preserve the current data schema and meet package trust/capability requirements. Ordinary updates never silently downgrade, data restore never selects executable versions, and Cloudflared binary downgrade restrictions remain independent. KEEP and data backup/restore preserve main-config selectors and catalog as validated data, not executable or unverified update authority.

### One verified manager transaction

Bind trusted release/commit, exact manifest/file inventory/hashes, version and schema compatibility. Read embedded entry version as data and compare it with manifest authority before sourcing/executing downloaded code. Reject missing/malformed manifest, wrong SHA-256/version, HTML, incomplete tree, unsafe paths and incompatible helpers. Verify every required file, syntax and bounded staging before activation.

Retain the last trusted complete package and recovery entry; publish one coherent generation with deterministic interrupted-switch recovery. Preserve typed credentials, tunnel data, feature/maintenance/logging/update choices, history, backup settings/archives and foreign integration; source selection/catalog follow the explicit policy above. Never reset configuration, silently downgrade, rerun a feature wizard or recreate a tunnel. Normal launch/status/hooks use installed code and report missing modules; they do not fetch arbitrary replacement modules.

Before retained-config update/reinstall, reconcile selected-method master/runtime integrity as in section 5. Matching tunnel state is a true runtime no-op even during `uf`: no overwrite/resnapshot/restart/binary download/provider call/activation change. Only validated owned drift gets guarded repair and at most one eligible restart for a real runtime change. Corrupt authority/user YAML is preserved for recovery. A manager package transfer authorized by `u`, `uf` or saved auto opt-in is distinct from feature reinstall.

Automatic self-update must stay unavailable until distinct failure boundaries are validated: transport/partial download; invalid metadata/hash/schema; storage/write/rename failure; interruption before/at/after switch; failed required hook reinjection; queued opt-out/source changes; simultaneous owners; failed rollback; and next-launch/boot recovery. Failed or unverifiable rollback retains evidence and suppresses unsafe activation, never destroys the last trusted generation or claims success. Track package replacement and required integration outcomes separately: a replaced package with failed hook reinjection is an incomplete update requiring repair, not a successful update. Apply section 12's affected-service containment and dedicated repair flow while preserving trusted package recovery and unrelated healthy work. No healthy-service restart, reboot, boot delay, retry storm or tick writes. Small representative scheduler-to-transaction integrations plus focused fault injection provide this coverage.

### Optional amtm integration

Document a user-selected amtm Personal scripts slot pointing to the installed `sh` entry, preserving occupied slots and update preferences. No automatic registry/module patches or catalog impersonation. A launcher does not confer official installation/update support.

If clean supported official catalog integration is later selected, a separate default-Off external-update permission gates `amtmupdate check` and the no-prompt callback. Check is local/read-only with truthful status; actual update uses the same trusted transaction, developer suppression and activation preservation. Do not maintain an amtm fork solely for registration.

## 8. Shared address discovery and reconciliation

| ID | Subgoal | Required result |
| --- | --- | --- |
| S08.01 | Independent family states | Active host, proven inactive or unknown per family; no deletion from missing/failed evidence. |
| S08.02 | Current desired state | Dual/one/no-family add/remove behavior; manual Off clears managed remote values, auth-Off only contains; IPv6-only remains provisional. |
| S08.03 | Selected-WAN IPv4 | Public/private/shared/mismatch classification with correctly routed external evidence and honest NAT meaning. |
| S08.04 | Global IPv6 host | Current selected-WAN public host/lifetime/canonical form, verified translation when present; no ULA, delegated-prefix or arbitrary LAN/VPN publishing. |
| S08.05 | Independent transport | Per-family selected-egress discovery and either-family provider transport, with verified TLS and bounded fallback. |
| S08.06 | Shared cache/freshness | One coalesced resolver with independent current family identity/generation/time/lifetime records. |
| S08.07 | DDNS and standalone reuse | Resolve once, forward valid source independently of DNS result; standalone lists require no DNS setup. |
| S08.08 | Events and periodic discovery | Current enable/boot/WAN/IPv6/manual/periodic requests coalesce; no menu/status network work. |
| S08.09 | Fresh remote authority | Read complete configured remote targets every eligible run, correct managed drift and preserve unrelated metadata. |
| S08.10 | Newest queue/retries | Explicit add/remove intent per target/family, four-attempt and aggregate bounds, no stale replay or late success. |
| S08.11 | Explicit Off cleanup | Persist scoped cleanup before unhooking, clear list contents/managed A-AAAA while remaining Off, retain offline/auth-blocked intent and never infer cleanup from auth-Off. |

### One source of current family state

DDNS and IP-Sync share one native resolver, cache, lock and coalesced dispatcher; neither copies discovery logic. Required shared Entware tools, JFFS/RAM validity, NTP and usable network/HTTPS gates apply. Cloudflared-specific readiness and optional logging do not control native publication.

Represent each family independently as **active with validated current public host**, **confirmed inactive**, or **unknown/unsupported**. Explicit allowed-family disable or successful complete selected-source inspection can prove inactivity. Missing hook input, stale cache, malformed/incomplete output, unavailable tools, failed external observation or unknown egress cannot. Unknown never authorizes deletion.

| Current state | DNS desired state | IP-list desired state |
| --- | --- | --- |
| IPv4 + IPv6 active | Current managed A and AAAA. | Exact current IPv4 `/32` and IPv6 `/128`, shared or mapped. |
| IPv4 active; IPv6 confirmed inactive | Current A; remove managed AAAA. | IPv4 only; clear mapped IPv6-only target. |
| IPv6 active; IPv4 confirmed inactive | Current AAAA; remove managed A. | IPv6 only; clear mapped IPv4-only target. Provisional support. |
| Both confirmed inactive | Remove managed A/AAAA where provider transport exists. | Empty selected targets without deleting list identity. Offline cleanup remains pending. |
| One family unknown | Known independent DNS scope may proceed; overall outcome partial/deferred. | Shared target replacement defers because desired set is incomplete; independent known-family target may proceed. |

Feature Off stops normal publication and discovery. **Explicit user Off/Stop for DDNS or IP-Sync also clears its managed remote values** under the scoped cleanup contract below. Automatic authentication containment does not authorize remote cleanup. Disabling one family while the feature remains On reconciles that family's removal. IPv4-only and dual-stack transitions are primary; symmetric IPv6-only support remains provisional with honest automated/live labels and no required forced firmware IPv4-disable option. Optional missing live IPv6 coverage cannot excuse automated safety failures.

### Explicit Off versus authentication containment

Review the effect of a user-selected DDNS/IP-Sync Off/Stop: preserve saved setup, credentials, names/IDs, feature options and logging history, but clear the configured remote addresses. IP-Sync empties each configured dedicated list without deleting its identity or Access-policy references. DDNS deletes only the configured managed A/AAAA definitions, preserving CNAME/NS and unrelated names/types; do not invent placeholder addresses. Re-enabling reconciles current addresses and recreates its missing configured DNS definitions through ordinary verified publication.

Persist local Off and exact cleanup intent before unhooking/quiescing normal work. Capture the configured account/zone/targets/credential references and a new generation; no valid durable intent means no remote deletion. Remove normal feature hooks/jobs and disable still-owned native DDNS integration without waiting for the network. Then, where common readiness and valid scoped credentials/cooldown permit, perform bounded read/clear/readback. Already-empty/absent is verified success. An in-flight older publication must be quiesced or excluded before cleanup can be declared complete; a lost response requires current-state reload, not blind replay.

Offline, throttled or failed cleanup remains **Off — remote cleanup pending**, never falsely complete. Retain compact durable cleanup intent across reboot, distinct from disposable retry queues. The shared watchdog may retain only the necessary cleanup dispatch after normal updates are Off; remove that eligibility when finished. No address discovery, normal publication, target creation or feature reactivation is permitted through this exception. Missing/rejected credentials block cleanup until repaired in CFMgr. A later On or configuration change supersedes old cleanup under the same serialization/generation checks so it cannot clear newly published addresses or a replacement target.

An automatic auth failure only faults, disables/unhooks and quiesces the affected feature under section 11. It preserves remote values and local setup, and never creates a clear request. If a previously explicit manual Off cleanup is already pending, retain that request but make no unauthorized calls until credential repair. Repair resumes only the user's current intent: pending cleanup stays Off; only an otherwise still-requested auth-disabled service may re-enable. Historical Off state or restored backups cannot mint new remote-clear permission. Uninstall/reset do not implicitly perform this user-Off action; disclose unresolved cleanup before credentials/intent are removed and retain it behind KEEP guards without background execution.

### IPv4 and IPv6 source policy

Use the configured/selected WAN's verified native address/interface/protocol mapping, not an assumed WAN0 or a hook argument alone. Classify IPv4 using universal IANA special-use rules and exceptions; never hardcode ISP customer ranges.

- Shared `100.64.0.0/10` indicates likely shared/CGNAT addressing; private RFC1918 indicates upstream/private NAT, not proof a carrier owns it. Both require bounded external public IPv4 discovery.
- A public WAN needs fresh correctly routed external evidence before declaring no translation observed. Matching evidence permits reuse of current direct-WAN state; mismatch uses the validated external value and reports observed translation/mismatch.
- Boot, WAN/source/policy change or expiry revalidates. Failed/invalid/nonpublic/oversized/incorrect-egress observation is unknown, never a private fallback or guessed absence. CGNAT does not prevent public-IP publication, but publication does not provide inbound reachability.

A publishable IPv6 value must be a usable global unicast **host** associated with the selected router/WAN egress. Never derive one from a delegated prefix or arbitrary LAN/VPN interface. Prefer stable non-temporary local source addresses; reject tentative/deprecated/expired candidates and track lifetimes/temporary churn. Never publish unspecified, loopback, link-local, ULA, multicast, documentation/nonpublic, mapped or scoped `%interface` values; explicitly validate supported transition/special cases. Canonical comparison prevents compressed/expanded/case duplicates. A router `/128` does not cover LAN clients or their privacy addresses; never silently widen it to `/64`.

IPv4 shared-CGNAT classification does not apply to IPv6. IPv6 prefix/address translation can change the externally visible address: compare bounded external IPv6 evidence with the actual selected local source/route, use the verified public external host when translation is observed and report both values without guessing the translation mechanism. A local ULA may be source evidence for a proved translated path, never the published address. Merely seeing ULA, an enabled IPv6 setting, a delegated prefix or IPv4 service through NAT64 does not establish a usable public IPv6 host. Failed/ambiguous egress observations remain unknown, never authorize cleanup or fabricated publication. Do not reconfigure router/ISP translation or claim inbound reachability from outbound observation.

Bound ordered per-family external endpoints and total fallback cost. Discovery uses its own family and verified selected-WAN egress; VPN/proxy/another WAN cannot silently supply results. Provider transport may use either usable family independently of the family published; no unconditional IPv4-only API gate, TLS bypass or duplicated resolver.

### Freshness, generations and dispatch

One bounded private RAM cache stores separate family records keyed by boot, selected WAN, native address/interface/prefix/source identity, relevant config/policy and monotonic freshness. IPv6 evidence cannot outlive its source lifetime. Active and inactive observations need equivalent current identity/time proof. Collection must be complete/coherent; changed or unavailable source evidence is not repaired by a matching fingerprint. Recheck local generation/content/egress before writes; preserve compatible sibling observations and invalidate affected ones on changes.

Enabled DDNS resolves once and forwards immutable valid per-family observations/removals asynchronously to IP-Sync before independent DNS work. DNS failure cannot discard valid source state; list failure cannot hold DNS completion. Standalone IP-Sync calls only the resolver/list path, requiring no DDNS credentials, DNS requests or firmware callback.

Explicit first enable, eligible boot/recovery/restore, selected-WAN reconnect, IPv6 renewal and manual publish request coalesced discovery. The shared watchdog dispatches native discovery/reconciliation when due, by default every five minutes, covering missed events and remote drift even when local IP is unchanged. Both native features Off removes normal native discovery/publication work; explicitly pending Off cleanup remains separately eligible; disabling one retains the other's work, and Cloudflared can independently retain the watchdog. Ordinary status/menus and local hook repair do no source/provider calls.

### Remote authority and queue rules

Every eligible publishing run reads complete current configured remote state before declaring unchanged. Local success/IP cache is historical evidence only. Exact current canonical state skips writes; differences in managed addresses, selected-list name/managed attributes or DNS TTL/proxy automatically converge from saved config, without a dashboard-edit conflict prompt. Preserve unmanaged metadata and unrelated targets/accounts.

Read/write/readback is not atomic with dashboard edits. Conditional conflicts, if supported, or observed drift trigger bounded reload/reconcile; persistent external churn remains pending within attempts/time/cooldown bounds, not an endless loop or ownership-conflict mode. Old replies never satisfy newer work.

Keep newest active-address **and explicit inactive/removal intent** per family/target with source/config/credential identity. Serialize same-target writes, merge sibling outcomes, use short queue locks and child-held writer exclusion. Preserve the reference's four-attempt bound while freezing aggregate batch/time limits and safe queue expiry. Retry reloads current source/config and fresh remote state, never blindly replays an old IP or clear. Reboot/restore rebuilds work from current state; historical success/fault metadata is not live cache/queue authority. Verified equality, successful publication and completed removal are distinct outcomes/history.

## 9. DDNS

| ID | Subgoal | Required result |
| --- | --- | --- |
| S09.01 | Dedicated setup | Scoped DNS token, zone ID/selection, names/attributes/primary hostname and native draft resume. |
| S09.02 | Logical DNS scope | Persist zone/name/type/creation attributes separately from IDs; handle all matching managed records. |
| S09.03 | Active/inactive reconciliation | Update, remove or recreate configured definitions from complete current evidence; unrelated types survive. |
| S09.04 | Lost/partial outcomes | Re-enumerate uncertain creates/deletes, no duplicate POST or full success while unresolved. |
| S09.05 | Firmware handoff | Reviewed Save/Enable replaces prior provider/handler without extra takeover prompt or displaced-setup backup. |
| S09.06 | Scoped firmware settings | Custom client, chosen primary hostname and native forced-refresh days (default 14), preserving other settings/IP-Sync with verified nonredundant apply. |
| S09.07 | Ownership relinquishment | Off/uninstall/repair respects still-owned integration and later external ownership, never restores old provider. |
| S09.08 | Bounded completion | DDNS-specific soft completion timer inside the proved firmware cap, one truthful invocation result and prompt early-unready return. |
| S09.09 | Failure-only fallback | Failed/timed-out DDNS attempt becomes shared-watchdog pending work; reconcile native retries, honor recovery/auth/throttle gates and keep IP-Sync independent. |

### Setup and provider reconciliation

Collect a scoped Cloudflare DNS token, selectable zone or explicitly supplied zone ID, record names and required attributes. Zone enumeration may need extra read permission; a supplied valid zone ID avoids an unnecessary enumeration requirement. Review primary firmware hostname, Auto/per-feature family policy, TTL/proxy, timeouts/schedule and intended activation. Native drafts resume completed inputs. No tunnel/IP-Sync setup or ISP-specific NAT question.

Retain logical zone/name/type definitions and creation attributes separately from cached record IDs. After complete authenticated typed enumeration, update **all** matching managed A/AAAA records to current hosts, delete managed records for confirmed inactive families, and recreate missing configured definitions when active. Preserve unrelated records, CNAME/NS conflicts and unmanaged fields; conflicts require diagnosis, not deletion. An incomplete/failed lookup authorizes neither creation nor deletion.

After lost create/delete responses, re-enumerate exact managed scope before retrying. Never blindly repeat POST or treat a stale-ID 404 as proof the whole definition is absent. Full success requires verified desired writes/removals and no unresolved source/target work. Successful A plus failed AAAA deletion is partial/failure. Both-inactive cleanup is reported as cleanup/no active address, not address publication; freeze the correct single firmware callback result before implementation.

### Merlin handoff

Normal reviewed DDNS Save/Enable replaces Merlin's existing DDNS provider/settings and the `ddns-start` provider handler. Explain replacement in the normal review; no extra takeover prompt and **no backup or restore of the displaced provider/settings/handler**. Do not run two provider handlers.

Set DDNS client enabled, server Custom, the explicitly selected primary configured hostname and native forced-update interval in days (default **14**) using the supported firmware contract. The mapped fields are `ddns_enable_x=1`, `ddns_server_x=CUSTOM`, `ddns_hostname_x=<primary>` and `ddns_refresh_x=14` by default, with the scoped `service restart_ddns` apply route subject to matched-firmware persistence/side-effect verification. Multiple managed names still have one firmware primary field. In the pinned Merlin 3004.388.12_2 source, `ddns_refresh_x` is days and zero disables forced refresh; 14 is CFMgr's chosen default, not the firmware default. Validate CFMgr's supported positive-day setting against the matched firmware rather than treating frontend input width as a backend range guarantee. Enforce actual supported hostname bounds, including the matched frontend's 63-character limit where applicable.

Preserve stored unrelated username/password/provider fields, DDNS options outside these reviewed fields, WAN settings, certificate/HTTPS choices, all other hooks and independently enabled CFMgr IP-Sync observation. Do not silently enable global custom-script support or alter `ddns_ipv6_update` without its separately verified requirement. Skip redundant writes/commit/restart when already correct; guard partial/interrupted application and verify before claiming enabled.

This replacement is the explicit exception to generic foreign-hook preservation. Ordinary repair does not silently retake externally changed DDNS ownership. Off/uninstall removes/disables only still-owned CFMgr local integration; explicit user Off additionally clears managed DNS through section 8, and never resurrects the displaced provider or overwrites a later external owner. Recognized legacy migration avoids duplicate updaters and removes legacy jobs only after command ownership and committed replacement are established.

### Completion and fallback

Exactly one owner reports verified success/failure for the current firmware DDNS invocation. DDNS retains its own short **soft completion timer**, strictly inside the matched firmware's whole-action ceiling with time reserved for cleanup/callback. This timer bounds the current attempt; it is separate from native forced-refresh days and the shared outage-retry delay. Prove callback identity, overlap, timeout, lock contention, cooldown, reentry and firmware retry behavior. No stale detached completion or fabricated success. The matched 3004.388.12_2 custom-handler path has a 120-second native timeout; this is a ceiling to stay well below, not CFMgr's soft timer or proof that descendant workers are killed. Explicit `ddns_custom_updated` success/failure arguments must reflect verified outcomes; callback exit zero alone does not prove successful publication. Recheck other supported firmware profiles before fixing the soft budget.

Early calls return promptly when boot/router/mount/tools/NTP/Internet are not ready; the soft timer never becomes a wait-for-boot-readiness loop. A failed or timed-out attempt leaves one coalesced pending DDNS retry with an honest failure result for its current invocation. The global watchdog retries only once common readiness and applicable authentication/rate-limit gates permit it, using current source/config/remote readback. Choose the supported scoped firmware retrigger or shared DDNS handler without recursive restart or a late callback for the old invocation.

Merlin retains ordinary DDNS event handling and the configured native forced-refresh schedule. CFMgr adds **no separate daily forced-DDNS job**. Its shared periodic discovery/drift checks remain due-state work, not unconditional firmware restarts or duplicate updates after success. Native firmware retries and CFMgr retries must enter the same exclusion/admission gate: native reentry cannot bypass outage/cooldown, multiply attempts, or produce a second completion owner. Do not disable native retry through undocumented NVRAM changes or falsely report success to suppress it. Off/config invalidation/auth guards cancel or contain normal pending publication; an explicit user-Off clear has its separate scoped authorization under section 8. Independent IP-Sync observation/queue handling cannot delay or change DNS completion.

## 10. IP-Sync

| ID | Subgoal | Required result |
| --- | --- | --- |
| S10.01 | Independent account/list setup | Suitable Zero Trust token/account, correct list API, provider-returned name/ID without normal manual ID entry. |
| S10.02 | Ten-item display policy | First ten stay selectable by number at any list count; exact-name search covers every eligible list. |
| S10.03 | Literal exact-name input | Case/space/numeric/quotes/e/Unicode ambiguity and correct one-time URL/JSON encoding without guessing. |
| S10.04 | Complete lookup and draft retry | Not-found only after complete lookup, immediate name retry, distinct auth/network/incomplete errors and preserved fields. |
| S10.05 | Shared or separate lists | Offer IPv4-only or detected usable IPv6 participation; shared list when supported or user-selected distinct family lists, same picker and no list/policy creation. |
| S10.06 | Mapping migration | Quiesce old requests, atomic local mapping and automatic primary/secondary cleanup with independent remote outcomes. |
| S10.07 | Nonempty publication | Exact current hosts and managed metadata, fresh read/readback, remove extra/wrong-family entries. |
| S10.08 | Empty target clearing | Same-ID supported item removal with exact returned spellings, complete verification and metadata reconciliation. |
| S10.09 | Unknown/missing targets | Shared unknown defers; known independent target proceeds; missing whole list requires reviewed repair. |
| S10.10 | Explicit read-only check | Configured-Off candidate GET/check allowed, no mutation/discovery/queue/success history/enable; cooldown/auth containment retained. |

### Guided setup and exact-name input

Collect account ID and a suitable Zero Trust API token independently of DNS/tunnel credentials. Discover eligible **Zero Trust Gateway IP lists**, not account Rules Lists, and store provider-returned name/ID automatically. Users should not need to locate/type IDs in normal setup. Guide dashboard list creation and Refresh when needed; CFMgr does not create lists.

Show at most **10** eligible lists as a numbered picker. Even when more than ten exist, every displayed entry remains selectable by its shown number; exact case-sensitive name search covers the complete eligible set, including lists beyond the preview. State when additional results exist. Ten is a display cap, never a lookup cap.

- Re-fetch/revalidate selected identity before Save. Exact-name filtering is local case-sensitive equality; provider substring/case-insensitive search is only candidate discovery. Multiple exact matches require disambiguation, never first-match guessing.
- Numeric input is an index at the displayed picker, including a first-ten preview of a larger set. If it also identifies a literal list name, clarify; quoted numeric input explicitly requests name lookup. In the exact-name retry prompt numbers are literal names; distinguish this prompt from the numbered picker. Never reinterpret an out-of-range index as a different list without clarification.
- Preserve case, internal spaces, backslashes and supported Unicode. One balanced surrounding quote pair may be syntax; consider raw and unwrapped candidates and disambiguate if they identify different real names. Bare `e` exits Setup; quoted `e` is a name. Reject unsupported controls without shell expansion/eval.
- Encode once for actual URL/JSON transport. Preserve apostrophes, ampersands, percent signs and literal quotes correctly; never shell-expand or double-wrap/escape names. API operations use returned IDs.
- Complete successful lookup with zero exact matches prints `List not found` and immediately repeats `Enter the exact list name (e to exit):`, retaining token/account. No extra retry confirmation or full wizard restart.
- Auth denial, throttling, transport failure, incomplete/truncated/oversized enumeration, repeated pages or count mismatch are not not-found. Bound complete enumeration using actual supported pagination; do not assume list-items pagination applies to list discovery. A clearly advanced manual-ID validation route may remain for known targets without listing permission.

Checkpoint completed native draft fields; `e`/Ctrl+C retains them and preserves working config. Show chosen provider name/ID/family mapping in final review, never token. Validate account/ID/type and available permission evidence; read success alone does not prove write permission or Access authorization.

### Shared or separate family lists

For a fresh setup with usable IPv4, offer IPv4-only first; offer adding IPv6 only after detecting a currently usable public IPv6 host through the shared resolver. When IPv6 is usable and the user chooses it, offer one shared list containing at most the current IPv4 `/32` and IPv6 `/128` if the actual target/API supports mixed families, or separate dedicated IPv4 and IPv6 lists by user choice. Separate lists no longer require a provider limitation. Use the same numbered/name picker for each selected target, mapping IPv4 first and then IPv6 when both are selected. A supported IPv6-only setup can select its sole usable family without inventing IPv4.

Do not infer mixed-family support from a different Cloudflare list product, expose an unsupported option as working, or treat a network/auth/throttle error as proof a second list is required. Missing/unknown IPv6 is shown with its reason and a recheck path; it does not block otherwise valid IPv4 setup. An existing saved IPv6 mapping survives temporary loss and follows the active/inactive/unknown reconciliation rules; no automatic configuration erasure or silent addition of a new family. When IPv6 later becomes usable, the user can extend the saved setup through the same reviewed flow.

Store primary/optional secondary names, IDs and family mapping; reject the same ID twice. Preserve an existing IPv6-primary mapping rather than blindly assigning primary to IPv4. Background workers never prompt, add a new family mapping or create targets: record bounded setup/capability guidance while preserving the already usable family. Save atomically changes mapping after old owned requests are quiesced; cancel leaves committed primary and completed draft intact.

Reviewed shared-to-split or split-to-shared migration reconciles each retained destination and clears displaced values only from the previously configured owned target scope. Preserve list identities and keep per-target cleanup intent until verified; never leave the old second list populated merely because the new mapping omits it. Family-specific targets converge to their assigned family, including empty inactive targets. No manual-cleanup/stale-entry exception. Two remote writes are not atomic; keep independent outcomes and retry from current authority. Explain that the user must reference the second list in the intended Access policy; never edit Include/Require/Exclude rules.

### Publication, clear and read-only target check

Read/validate complete current account/list/type/items and managed metadata before no-op. A nonempty desired set replaces differing, extra and wrong-family entries inside that configured list, preserving unmanaged metadata and enforcing saved managed name/attributes. No remote-content conflict prompt. A missing whole list requires reviewed target repair, not guessed ID or recreation.

For an empty desired set, preserve the list's ID/name/policy references. Do not assume PUT with `items: []` clears it: use supported bounded same-ID item removal, preserving provider-returned value spellings for removal, then verify complete emptiness/count. Already-empty needs no removal but may still need managed metadata repair. Unsupported or partial clear is explicit pending/limitation, never successful stale retention. Unknown family state blocks shared-target complete replacement; known separate targets can proceed.

Provide an explicit provider-read-only target-check equivalent of legacy dry-run, including configured-but-Off state and explicit IPv4 and/or IPv6 candidates. Validate candidates/config and GET configured targets; report unchanged/would-replace only with verified evidence. No PUT/PATCH/DELETE, discovery, queue/success-cache/history writes, enabling or publication. An omitted family is not absence evidence. Shared cooldown recording and definitive saved-credential auth containment still apply; this narrow diagnostic is distinct from ordinary local status.

## 11. Provider failures and credential repair

| ID | Subgoal | Required result |
| --- | --- | --- |
| S11.01 | Private bounded transport | Isolated curl/TLS/auth/redirect/header/body/aggregate limits and strict complete endpoint validation. |
| S11.02 | Partial and transient outcomes | Newest pending reconciliation, preserve On, no false success or credential loop from network errors. |
| S11.03 | Provider throttle | Evidenced shared scope, provider delay first, no-hint 5/10/20/30-minute backoff, bounded due dispatch and no worker bypass. |
| S11.04 | Definitive auth-Off | Only confirmed typed/scoped auth rejection permits fault-before-containment; repeated generic failures with healthy Internet are insufficient. |
| S11.05 | Owned containment | Close generations, bounded verified stop, stale requests/replies cannot reenable or erase newer faults. |
| S11.06 | Credential and target scope | Explicit compatible sharing; global versus operation/target fault isolation and management-only limits. |
| S11.07 | Immediate and launch repair | Setup/On first failure enters credential-only flow; Y/n launch/fx repair with no EOF/background consent. |
| S11.08 | Preserved intent | Cancel leaves fault/Off, later intentional Off wins, only still-requested repaired scope retries and archive intent stays advisory. |

Use native curl with `-q` first, private authentication, isolated proxy/CA/config environment, no tracing/token output, verified TLS and bounded whole-action transport. Authenticated API requests cannot follow unapproved redirects. Release transfer uses a separate bounded HTTPS redirect policy without provider credentials. Enforce streamed body/header limits even without Content-Length; older curl `--max-filesize` alone may not bound such a stream. Strictly validate full JSON success/error/schema/type/pagination and endpoint-specific semantics.

The containment/repair transitions below apply to operational work. The explicit
`--health` report is the read-only exception: a probe may report a rejection and
stop further probes, but does not persist auth-Off, unhook services or run repair.

| Outcome | Required behavior |
| --- | --- |
| Current complete remote match | Skip writes; record verified equality separately from new publication. |
| Partial/ambiguous/lost response | Retain only newest applicable pending work; reload current source/remote state before retry. No fabricated full success. |
| Proven throttle | Keep On, maintenance intent and eligible hooks/jobs. Honor a valid provider Retry-After/reset delay, even beyond 30 minutes. Without a usable hint, wait 5 minutes initially; consecutive proven no-hint throttling increases to 10, 20, then 30 minutes, capped there. One shared evidenced account/credential/endpoint cooldown prevents linked workers bypassing it. |
| Network/time/DNS/TLS/5xx or unexplained repeated operation failure | Bounded waiting/retry and useful failure evidence; preserve On. Healthy general Internet does not turn repeated failures into proof of bad credentials. No auth-Off or credential replacement loop without confirmed scoped rejection. |
| Definitive credential revocation/operation permission rejection | Persist non-secret fault, typed reference, proven affected scope and prior requested On with new generation **before** public Off/quiescence/unhooking. Preserve valid setup/data/options/log history. |
| Resource/identity mismatch | Reviewed target/setup repair; generic 403/404, raw text, failed startup, PID or zero connections alone is not global credential rejection. |

The no-hint throttle sequence is CFMgr policy, separate from the common 1/2/4/5-minute outage checks. Parse supported endpoint headers/error evidence; never treat a generic failure as rate limiting or shorten a valid provider delay to either local cap. Advance the affected throttle state once per actual admitted rate-limited attempt, not per queued event or sibling worker. Verified successful provider work in that scope resets its consecutive fallback state; ping/NTP recovery alone does not. Keep due/counter state bounded and boot-local, preserve newest work, and resume through current readiness/auth/config admission. Record concise reason/next-due changes without repeated credential prompts.

Native feature auth-Off removes only affected operational integration and quiesces owned work. It never clears remote addresses or creates a cleanup request; manual-Off cleanup is separately authorized as described in section 8. Cloudflared auth-Off clears both runtime and maintenance activation and removes all its runtime/watchdog/updater integration. Scribe rotation remains independent. Bound TERM/cleanup and permit targeted rechecked KILL only under the narrow containment rule; uncertain surviving ownership remains Off/guarded, never claimed stopped.

An already-sent API write cannot be undone by local Off. New generation blocks superseded further/queued requests and stale-response state changes; only separately authorized current-generation manual-Off cleanup can write while Off; it cannot erase newer fault or reenable work. Use version-specific supported Cloudflared rejection evidence even if PID survives reconnects. Bounded private RAM classification must work without Scribe, not rely on a persistent raw debug/syslog stream or new daemon. GitHub release errors do not imply a Cloudflare credential fault.

Explicit sharing uses compatible typed credential references. Global revocation may fault verified dependents; operation-only denial affects only proved failing scope. For split IP-Sync a target-specific fault blocks that target, keeps durable target fault/intent and leaves feature On if another target can operate; global rejection invokes feature auth-Off. Equal token strings alone establish neither sharing nor rate scope.

The first definitive authentication failure during reviewed interactive setup or explicit On enters the failed credential's minimal repair flow after durable fault/public-Off containment. Ask again only for that credential; background handlers never prompt. On interactive launch with repairable faults ask `Fix invalid credentials now? [Y/n]`; Enter is yes only with actual valid interactive input, never EOF. Also show conditional `fx`. Serialize compatible credential groups and update/revalidate them atomically without rerunning the full wizard, changing UUID/mode, losing selections or displaying saved secrets.

Cancel leaves affected fault/Off state intact. Accepted repair retries only still-requested faulted work; a later intentional/manual Off wins and unrelated shared users never auto-enable. Restored historical repair intent is advisory, not activation authority. Repeated definitive rejection remains in the minimal repair path; throttle/transport does not repeatedly ask for tokens. Management-certificate faults gate the dependent management operation, not healthy UUID+JSON runtime. Existing-ID tunnel repair follows section 5.

## 12. Hooks, schedules and boot safety

| ID | Subgoal | Required result |
| --- | --- | --- |
| S12.01 | Thin shared handlers | Explicit module loading, same admission/controller/resolver, no menu/network/settle loop in foreign hook body. |
| S12.02 | Exact hook ownership and repair | Dedicated verified CFMgr blocks preserve foreign content; unsafe edits leave hooks unchanged, stop affected work with visible repair state, and use guarded repair/reinjection before eligible resume. |
| S12.03 | Boot/WAN/IPv6 dispatch | Saved eligible registration without mount wait, selected events and detached rechecked tunnel settle. |
| S12.04 | DDNS/IP-Sync coexistence | One completion owner; Access-only observation preserves foreign provider and needs no provider itself. |
| S12.05 | Mount and shutdown | Match expected volume, scoped resume and suppression-before-stop within firmware budget. |
| S12.06 | Eligible schedules | One global watchdog dispatches eligible tunnel/native/retry work; native DDNS days, binary updates and manager checks retain distinct schedules. |
| S12.07 | No duplicate/foreign jobs | Exact names plus commands/ownership; Scribe owns rotation, backups manual, Off removes only its scope. |
| S12.08 | Bounded resource admission | Coalesce before spawn/sleep, cap active/pending children/RAM/notices and aggregate work/cleanup. |
| S12.09 | Real detachment | Close inherited pipes/terminal/irrelevant descriptors; prove hook return while worker lives. |
| S12.10 | Safe failure recovery | No boot wait, infinite install/create/crash loop, reboot/global restart or teardown respawn. |
| S12.11 | Shared watchdog and recovery | All three features share NTP/reachability recovery with 1/2/4/5-minute capped due checks, isolated auth/throttle gates and transition logging. |

### Shared watchdog and recovery gate

One shared watchdog monitors eligible **Cloudflared, DDNS and IP-Sync** work; it does not invent DDNS/IP-Sync daemons. It dispatches tunnel health/recovery, failed native updates and due shared native discovery through their owning modules. Saved activation, per-operation prerequisites and current teardown/auth/transaction guards still decide eligibility. Cloudflared maintenance requires its independent saved activation/update preference; the common gate never enables a feature. Explicit pending manual-Off cleanup is the narrowly scoped exception to On eligibility, not permission to resume normal feature work.

Check NTP readiness first, then independent bounded reachability over an available supported IP family. NTP already synchronized does **not** prove Internet access. After any operational failure, require a fresh common readiness check before retrying; coalesced fresh evidence may serve all eligible features. Use alternative bounded targets so one unavailable probe target alone is not an outage verdict. Do not impose IPv4-only ping on otherwise usable IPv6 transport. Tunnel-specific DNS/credentials and provider-specific response checks remain scoped requirements.

A network outage defers affected work while retaining On. Valid provider responses are classified immediately: definitive scoped auth rejection follows section 11 containment; throttling preserves intent and honors the provider's delay; other failures remain bounded pending work without guessing bad credentials. Shared network success cannot clear an auth fault, bypass cooldown or certify a provider operation. One feature's endpoint fault must not block unrelated healthy features.

Use one cheap minute-driven dispatcher with private boot-local monotonic reason/attempt/due state. Ordinary failed outage checks back off **1, 2, 4, then 5 minutes**, with **300 seconds as the hard maximum scheduled outage-check interval** while eligible recovery remains pending. Coalesce tick/event/manual admission before spawning; do not accumulate delayed sleeping workers. A relevant event may request one earlier readiness check without erasing crash history or multiplying counters. Due checks run on eligible dispatcher ticks; host scheduling delays are reported rather than called successful timely execution. Longer valid provider cooldowns still suppress API calls even while common readiness is rechecked. No five-minute deadline forces a request into a known rate limit.

Keep one shared network reason/due state plus necessary per-feature operation/crash/cooldown state; advance a failed due check once. Confirmed sustained recovery resets the applicable backoff, while successful NTP/ping alone does not reset connector crash history. Retain only newest pending work, bound worker/probe cost, and avoid per-tick JFFS writes. Log reason changes, increased retry delay and recovered state concisely; suppress identical repeated notices at the cap. Status/health show waiting reason and next due. There is no blocking boot wait loop, permanent polling daemon or repeated restart of a healthy connector during an outage.

### Thin owned integration

Hooks/cron dispatch explicitly through the entry or fixed owned shell handler into the same shared guards, admission, resolver/lifecycle and deadline logic. No copied provider calls, credentials, readiness loops or settle sleeps inside foreign hook bodies. Do not source libraries into a foreign shell or open the interactive menu from a hook. Missing/incompatible modules defer affected CFMgr work and allow firmware/foreign content to continue.

Every CFMgr hook segment has its own dedicated managed block with a stable,
code-defined block ID for its responsibility, such as DDNS, IP-Sync, Cloudflared,
Maintenance or shared NativeIP. Use paired, exact marker lines:

```text
# CFMGR BEGIN <block-id> - MANAGED: DO NOT EDIT
<thin CFMgr hook dispatch>
# CFMGR END <block-id>
```

The ID and private ownership metadata identify the specific segment to replace
or remove; a file merely mentioning CFMgr is not owned. Before an install repair,
hook-code update, Off/unhook, feature removal or full uninstall edits a hook,
locate one complete unambiguous matching block and verify its body against the
recorded installed form or a recognized versioned CFMgr template/signature.
Markers alone do not authorize deleting an arbitrary modified body. Unmarked
legacy code may be migrated only when an exact recognized signature and trusted
context establish its complete range; never use a substring or broad regex as
ownership proof. Duplicate, nested, mismatched, missing/truncated markers,
unrecognized bodies or uncertain boundaries leave the hook unchanged and report
repair required. A recognized older owned block can be replaced as one unit;
repeating an already correct update is a no-op.

Preserve unrelated content byte-for-byte, original arguments, reachable control
flow, shebang and executable mode. Remove only the identified owned segment;
delete the whole hook file only when its complete remaining content and metadata
prove it is exclusively CFMgr-generated. Stage, syntax-check the **whole** hook,
compare current content under lock and remerge concurrent changes before atomic
replacement. Never append after an unreachable exit. Missing hooks may be
created minimally with the same markers. Explicit DDNS Save/Enable replacement
remains the separately authorized scoped exception in section 9; the resulting
CFMgr handler uses these markers for subsequent maintenance/removal.

### Hook faults and dedicated repair

When a required hook cannot be installed, updated or safely identified, notify
the user and mark the affected service or integration **Repair required**. Stop
owned affected runtime work and suppress its queued/scheduled admission before
further activation; central controller guards must also block stale hooks and
watchdog respawn. Use verified process ownership and bounded cleanup, never
claim a process stopped when its outcome remains uncertain. DDNS/IP-Sync have
workers rather than service daemons; contain only the affected work and preserve
shared dispatch needed by healthy scopes. Keep saved setup, credentials and
requested activation. This automatic containment is not a user-requested Off and
must not clear remote DNS/list values or create a remote cleanup request.

Expose the fault in launch/status/health and offer a dedicated integration repair
flow, also reachable through advanced configured-integration repair. Keep `fx`
credential-only. Explain the affected hook/block and the safe next action without
printing credentials or silently deleting an ambiguous segment. Back, cancel or
EOF leaves the affected scope blocked. If the user manually removes the damaged
CFMgr segment, the next launch may inject a clean owned block after current
configuration, ownership, foreign-content and whole-hook checks; it must not
append another copy beside unresolved damage. An absent block and a malformed
block are different states.

Retain the repair guard across launches/recovery until the integration is
verified. Successful repair clears only that fault and resumes only still-saved,
configured and otherwise eligible intent; later intentional Off wins. A partial
update with failed reinjection follows the same flow and remains visibly
incomplete until required integration has been verified. Unrelated healthy
features and their settings are preserved.

Emit a concise actionable event to syslog and, when Scribe and the affected
feature's requested logging are configured and ready, also to its own feature
log. Otherwise use syslog only; do not create an unmanaged file or override a
logging opt-out. Show the warning/error immediately during interactive work and
the retained repair notice on a later launch for background faults. Include the
affected service, actual stopped/blocked/uncertain state and repair action;
suppress unchanged repetitions and log verified recovery once. Shared manager
faults retain section 13's syslog-only policy, without a new manager logfile.

| Entry | Required action |
| --- | --- |
| `services-start` | Register saved eligible jobs from JFFS independently of Entware presence and request detached admitted work; no foreground network/wait/install. |
| `wan-event` | Preserve original argument forwarding. Selected WAN connected/reconnected requests coalesced work; retain the reference default unit 0/connected and detached 20-second tunnel settle unless configured otherwise. Delayed workers recheck intent/generation. |
| `dhcpc-event` where supported | Validate firmware family/interface event mapping; coalesce IPv6 address/prefix/RA changes, preserve foreign behavior. Shared periodic discovery covers missed/unsupported events. |
| `ddns-start` | One bounded completion owner under section 9; independent valid native observation forwarding. |
| Access-only observation | With IP-Sync On and CFMgr DDNS Off, preserve an existing foreign provider and add only identifiable IP-Sync observation; never report its DDNS result. Standalone boot/WAN/periodic resolution works with no DDNS provider. |
| `post-mount` | Match actual expected Entware; request only eligible deferred scope/logging repair, not all services or unrelated mounts. Shared dependency gates still govern native work. |
| `unmount` / `services-stop` | Establish suppression before owned stop; cancel pending admission, bound cleanup inside firmware budget and preserve saved On for later valid recovery. No watchdog respawn during teardown. |

### Schedules

| Job | Router-local schedule | Eligibility |
| --- | --- | --- |
| `CFMgrWatchdog` | `* * * * *` | At least one valid configured On feature, independently eligible maintenance recovery or authorized pending manual-Off cleanup; cheap common dispatcher, due-time/guards gate actual work. |
| `CFMgrCloudflaredUpdate` | `37 3 * * *` | Installed + maintenance_enabled + saved binary auto-update preference; idle path never starts tunnel. |
| Native DDNS forced refresh | Merlin setting, default 14 days | Valid configured On DDNS; firmware events/retries enter common admission. No extra daily CFMgr forced-refresh cron. |
| Native discovery/reconciliation | Shared watchdog due work, default every five minutes | Either native feature valid/On; covers missed events and unchanged-local-IP remote drift without a second polling job. |
| DDNS/IP-Sync failure retry | Shared watchdog due work | Newest failed/timed-out pending work only, common recovery and scoped cooldown/guards; no separate retry cron or duplicate after success. |
| Explicit Off remote cleanup | Shared watchdog due work until complete | Exact durable user-authorized list/DNS clear only; feature remains Off, auth faults block it, no normal updates or recreated targets. |
| CFMgr manager update check | One fixed daily schedule, exact time to settle | Saved manager checks On, developer=false, valid installation and no conflicting guard/owner. |
| Scribe rotation | Scribe's own existing schedule | CFMgr owns feature policies only, never a second rotation job or global schedule changes. |

Review supported imported schedule preferences during migration; consolidate proven-owned legacy watchdog/retry/daily-DDNS jobs into the accepted shared dispatch/native-refresh model without duplicate execution. Exact names plus commands/ownership identify legacy jobs; a generic name such as `UpdateDDNS` alone is insufficient for removal. One feature Off removes its normal operational work; retain only separately authorized pending remote cleanup, and shared work needed by another eligible feature. Cloudflared Off removes all its runtime and maintenance integration. Manager check preferences remain independent. Backups have no schedule.

### Bounded automatic work

All required scope gates must pass before start/publication/update; false/unknown means record waiting and exit for a later due trigger. Registering jobs or finding a mount is not proof of readiness. Native publishing requires shared tools, NTP, current source and usable network/HTTPS; optional file logging may defer independently. No loop waiting for mount/NTP/Internet in boot or menu.

Admit/coalesce **before** spawning a worker or WAN sleeper: at most one active and one bounded newest pending request per scope. Cap total children, timers, RAM/staging and notices across scopes. Busy lock/fork failure/full RAM/JFFS/read-only storage must not spin, recurse, grow contenders or flood logs. Bound the complete action plus owned cleanup, not merely each curl/ping; event/callback bursts cannot bypass backoff or server delay.

Detach stdin/stdout/stderr and inherited hook pipes/terminal before long work, closing all unrelated descriptors. `&` alone does not prove hook independence. Safe output sinks must not require Entware. Measure actual hook return/output closure with a live worker, including shutdown budgets and the narrow capped DDNS exception.

Permanent invalid config, incompatible artifact or missing essential capability requires relevant repair/change; do not endlessly download/rewrite/restart. Repeated early crashes retain backoff until sustained stability. Boot/mount recovery may resolve bounded known local transactions, never enter login/create/reinstall loops or reactivate uncertain generations. No automatic reboot/poweroff/global WAN/DNS/service restart, firmware-watchdog manipulation or recursive firmware hook recovery. The explicit reviewed DDNS settings apply remains narrowly scoped.

## 13. Logging and rotation

| ID | Subgoal | Required result |
| --- | --- | --- |
| S13.01 | Three private logs/native notices | Extended setup detail stays terminal-only; native notices reach the existing system messages log, eligible feature logs add a copy, daemon stream stays file-only, no global routes/manager logfile. |
| S13.02 | First setup versus saved preference | Only completed fresh ready setup initializes own logs; pending/maintenance-only/opt-out remain inactive. |
| S13.03 | Readiness and independence | Verified mounted Entware /opt/var/log paths and actual Scribe/base/schedule/include readiness, graceful no-file operation and service-Off rotation retention. |
| S13.04 | Cloudflared tuning | Per-file size/total-count including live file, shown Enter defaults and supported time/compression/age options; no aggregate-byte quota. |
| S13.05 | Fixed native policies | Separate versioned DDNS/IP-Sync defaults with no tuning UI or config override. |
| S13.06 | Rotation correctness | Numbered history/actual cadence, daemon reopen or stated copytruncate limit, safe native append and snapshot coordination. |
| S13.07 | Fast scoped repair | Cheap requested-feature checks, bounded owned fragment/include repair and full explicit validation without base/global changes. |
| S13.08 | Install/policy transaction | Owned /opt/etc/logrotate.d fragments, direct no-rotation validation and coherent config/rule rollback; automatic next-run discovery without Scribe reload/restart or forced rotation. |
| S13.09 | Logging uninstall | Durable opt-out before writer quiescence/deletion; missing Scribe allowed, storage failure deferred and no false removal. |
| S13.10 | Resume without file output | Release runtime guard after safe quiescence/opt-out, retain residual cleanup, resume only still-On/no-file work. |
| S13.11 | Optional external viewing | Supported bounded owned-path registry only if selected; no fake routing/private patches or CFMgr WebUI requirement. |
| S13.12 | Explicit all-service re-detect | Ready Scribe enables logging for every configured On service, overriding prior logging Off only for this explicit action; reuse policies or initialize defaults. |
| S13.13 | Prominent concise event format | Single-line [CFMGR] component: Info/Warning/Error messages with matching syslog severity, verified outcomes/IPs, actionable failures/repair notices, eligible feature-file plus syslog delivery and duplicate suppression. |

### Independent output and preference

Throughout this plan, **syslog/native notices means delivery to the router's
existing system messages log**, using the router's native `logger` command and
its normal local syslog route, as in the original DDNS/lifecycle scripts. Add the
CFMgr tag and appropriate priority; do not select a separate logging transport. Under
Scribe/syslog-ng this is normally `/opt/var/log/messages`; firmware system-log
access uses `/tmp/syslog.log` or its configured location/alias. Without Scribe,
keep using the native firmware system log. Resolve the actual active destination
and routing rather than assuming either filename is a separate independent log.
Use a facility/severity admitted by that route and verify that CFMgr notices
reach the messages destination during logging acceptance; `logger` exit zero
alone does not establish file delivery. Preserve the user's system logging
configuration and rotation. Do not append directly to both aliases, duplicate
system entries, create an unmanaged messages file, or rewrite global routes.
If the system logger/destination is unavailable, retain the operational/repair
outcome, show the delivery limitation when interactive and do not claim the
notice was stored. Eligible feature-file logging remains an additional output.

Manage three separate private direct files: `/opt/var/log/cloudflared.log`,
`/opt/var/log/ddns.log` and `/opt/var/log/ip-sync.log`, each with its own ownership,
preference and rotation rule. Their numbered history stays alongside them. `/opt`
is the common Entware prefix across supported Merlin targets; the underlying
drive/mount can differ. This does not imply every router has Entware/Scribe or
usable mounted storage. Verify the expected backing volume and writable canonical
paths before creating or appending files; never fall back to a bare/stale `/opt`,
JFFS or RAM. Preserve shared-directory permissions and unrelated files. An existing
same-named foreign log or rule is a collision, not permission to adopt, truncate
or delete it. Syslog and eligible Scribe feature files use **minimal operational
logging by default**. Extended interactive setup explanation stays in the
terminal; do not copy wizard transcripts, raw API replies, token values or verbose
discovery/probe details into persistent logs.

| Event/output | Destination and detail |
| --- | --- |
| Interactive DDNS/IP-Sync setup | Terminal may explain selected WAN/local and verified public IPv4/IPv6, detected translation/CGNAT, chosen family/list mapping and actual success/failure or waiting cause. Label unknown/stale evidence and never print credentials. |
| DDNS/IP-Sync operational update | Concise syslog plus that feature's requested/ready file: action, changed public address/family, verified outcome or short failure/defer reason. Show a compact local-to-public/CGNAT distinction when relevant, not full repeated discovery traces. |
| Watchdog/readiness/Cloudflared maintenance | Brief reason/delay/recovery/start/stop/update result in syslog and the applicable requested/ready feature log. Coalesce shared outage notices and suppress unchanged repeated waits; do not spam three copies of every shared probe. |
| Feature hook/integration repair | Notify interactively and retain visible repair state; send the concise fault, affected stopped/blocked/uncertain state and safe repair action to syslog plus the affected feature's configured/ready Scribe log. Without eligible file logging, syslog only; verified repair produces one recovery event. |
| Cloudflared daemon stream | File-only when eligible logging is ready, at normal daemon verbosity; never mirror the stream to syslog or force debug logging for setup. Separate controller notices remain minimal. |
| CFMgr manager checks/install/reinstall | Minimal syslog result for launch/manual/daily checks and update success/failure/rollback; suppress duplicate unchanged notices. No dedicated manager logfile or custom logging prerequisite. |

Missing Scribe or logging Off leaves native operational notices available without creating unmanaged files. No global syslog-ng route change, verbose-by-default logger or new persistent setup transcript. Terminal setup detail does not expand routine logging verbosity.

### Event prefixes and severity

Every CFMgr-generated operational event uses the stable, prominent ASCII format
`[CFMGR] <component>: <level>: <short message>` in syslog and any eligible feature
file. The same concise event shown in the terminal keeps this format. Use
`Cloudflared`, `DDNS` or `IP-Sync` for the affected feature, including its watchdog
and updater events; `Watchdog` identifies a shared readiness/outage event, and
`Manager` identifies CFMgr's own updates/core operations. Render the marker once;
normal syslog timestamps/host metadata may precede it. Do not add banners, repeated
separator lines, ANSI escapes or decorative multi-line output to persistent logs.

| Level | Use |
| --- | --- |
| `Info` | Verified IP publication (family and actual published IP), successful binary/manager update (version), service transition and recovery. A check/no-op is not an update success. |
| `Warning` | Proven rate limit, confirmed auth/permission rejection, expected network/NTP/mount readiness wait or recoverable failure. Give the concise cause plus applicable retry delay or action, such as disabled pending credential repair. |
| `Error` | A failed operation needing attention: invalid/corrupt configuration, failed required-dependency repair or storage I/O, rejected update integrity, failed activation/rollback or incomplete cleanup that cannot safely proceed. State the actual failure and preserved/recovery state; do not relabel routine readiness/throttle waits as hard errors. |

Use the matching native syslog priority as well as the visible level. Severity
labels do not change the auth, retry or activation rules. If a recoverable warning
develops into a distinct hard failure, emit an Error with the new cause. Logging
failure must not overwrite the real provider/lifecycle result.

Keep each event to one bounded physical line: component, level, result/reason,
then only the IP, version, target or next action needed to understand it. Report
new/changed warnings and real errors promptly; suppress unchanged polling results
and identical repeated notices. Log material reason/delay/severity changes and one
recovery Info, preserving distinct affected-target failures without repeating a
shared outage under every feature. Sanitize untrusted text/newlines/control bytes;
never dump credentials, API bodies, wizard detail or raw stack/debug traces.
Cloudflared's own daemon stream retains its native format and remains file-only;
these prefixes apply to CFMgr's controller/maintenance notices.

Illustrative messages (documentation-only IP/version values):

```text
[CFMGR] DDNS: Info: IPv4 updated: 203.0.113.10
[CFMGR] IP-Sync: Warning: Rate limited; retry in 5m
[CFMGR] Cloudflared: Warning: Token rejected; disabled; fix credentials
[CFMGR] Cloudflared: Info: Binary updated to <version>
[CFMGR] Cloudflared: Error: Update verification failed; kept current binary
[CFMGR] Watchdog: Warning: Network unavailable; retry in 5m
[CFMGR] Manager: Info: Updated to <version>
```

### Logging initialization and readiness

First **completed fresh feature setup** with ready Scribe initializes only that feature's logging policy. Before setup, during incomplete B preparation and for maintenance-only installation, no automatic Scribe detection/files/rules. Missing Scribe does not block feature setup or otherwise-ready operation. Preserve imported/restored/saved preferences and explicit opt-out on repeat setup, ordinary launch and automatic repair. The explicit all-enabled-service Re-detect logging action below is a new user request that can override a previous logging Off choice.

File readiness requires actual mounted writable Entware, installed/configured Scribe, required usable syslog-ng/logrotate/base configuration, active syslog-ng as required, functioning Scribe rotation schedule and validated inclusion of owned rules. Package/script presence alone is insufficient. Probe base readiness separately from missing generated fragments so scoped repair remains possible.

| State | Behavior |
| --- | --- |
| Requested and ready | Own file output and validated rule only; no other feature/global changes. |
| Requested but unavailable | Preserve preference/history; no new unmanaged file output. Omit daemon logfile flags and suppress background console stream. Native notices remain. |
| Scribe base ready, owned rule/include absent/stale | Regenerate only requested configured feature's owned integration from saved/versioned policy, validate and commit boundedly. |
| Explicit logging opt-out | No automatic checks/writes/heal. Explicit Re-detect logging enables it for currently enabled services when Scribe is ready; otherwise a separate explicit enable is required. |
| Service Stop/Off | Preserve preference/files/rules; Scribe continues rotating history independently. No Scribe daemon/job/schedule changes. |
| Scribe lost while writer active | Coordinate only needed owned no-file transition; native append writers stop file output. No forced provider sync or invented native daemon. |

### Policies and controls

Cloudflared tuning is available only through its configured logging submenu with usable Scribe. Initial setup asks no advanced rotation questions. These numeric values remain **proposed defaults to settle**, not previously approved fixed guarantees:

| Cloudflared setting | Proposed default | Options/rules |
| --- | --- | --- |
| Custom logging | On for completed first setup with ready Scribe; otherwise inactive | Separate from service activation/readiness; uninstall saves false. |
| Rotation mode | Size | Size only, or daily/weekly/monthly plus size threshold. |
| Size | `10M` | Validated positive bounded units/value. |
| Total log files | `5` | Positive bounded count including the live file; 1 keeps no history, 3 means live plus two rotations. |
| Interval | Unset in size mode | Does not increase Scribe's actual checking cadence. |
| Compression | On | Available gzip, explicit option. |
| Delay compression | On | Leave newest rotation uncompressed until next cycle when enabled. |
| Maximum age | Off | Optional positive age limit, independent of count. |

DDNS and IP-Sync use separate **fixed** versioned policies: proposed `1M` per file, two files total (live plus one uncompressed numbered rotation), size-only, no time/age/compression tuning or editable user overrides. Save only their preference/policy version. Invalid Cloudflared policy changes preserve working config/rule.

Use per-file size and total file count as the storage controls; no separate aggregate-byte budget. A count of **1** clears/reuses the live file at rotation without retaining history. A count of **3** with `3M` means one live file and at most two historical files, rotating around the per-file threshold and discarding the oldest history. Present the total count in prompts/config/status and translate it to logrotate's historical count internally; never silently add one more file.

Show the effective current/default size and count in each prompt; Enter keeps the shown value (initial default for fresh configuration), while invalid input preserves the working policy. Use numbered `.1` through `.N-1` history for total count `N` and `.gz` where applicable, explicit `nodateext`/`start 1`, `missingok`/`notifempty`, size-only `size` or time-plus-size `maxsize` after verifying installed directive support. With count 1 omit inapplicable history compression/age behavior without deleting saved preferences. Scribe alone schedules rotation. Thresholds are checked at its cadence, **not immediate hard size caps**; display that cadence. No second cron, polling rotation daemon or launch truncation.

Count 1 must safely reset the owned live file without orphaning an active writer or leaving extra history; do not unlink/recreate an open logfile and claim the writer followed it. Prove Cloudflared open-file behavior before choosing rename/reopen versus copytruncate; a syslog-ng HUP is not daemon reopen evidence. Document copytruncate loss window if selected. Separately validate short-lived serialized DDNS/IP-Sync append/rotation and log-backup coordination. Preserve existing eligible owned log/history through recoverable migration; never adopt unrelated history by filename alone.

### Fast check, install and repair

Healthy launch checks only small configured/requested state, owned fingerprints/include signals and shared base prerequisites. Skip all custom-log probes when no configured feature requests them. No full logrotate dry-run, rotation, network, install, sleep or restart on the healthy path. Proposed target: under one second healthy, at most two seconds total foreground check/repair; measure against supported hardware and bound/defer contention.

Label the explicit action **Re-detect logging / enable for all enabled services** so its effects are visible. It checks Scribe readiness and enables or repairs logging for every fully configured currently On service, including a previously explicit logging opt-out. Reuse valid saved Cloudflared tuning and fixed native policy versions; initialize defaults only where no valid policy exists. Unconfigured, incomplete, maintenance-only, auth-disabled and service-Off scopes remain inactive. Missing/unready Scribe reports unavailable without fabricating successful logging or creating unmanaged files.

This explicit action is distinct from passive detection on launch and automatic rule repair, which never override logging opt-out. Respect newer service-Off/configuration changes during the transaction. A necessary logfile-argument transition uses one guarded restart of a still-On Cloudflared connector; DDNS/IP-Sync need no forced publication. Report each enabled/repaired/skipped/deferred outcome. Install/enable resolves pending cleanup, stages private recovery/config/rules and validates the full include chain, including duplicate/nested matches. Preserve other text and `A01global`. Never recreate a missing/invalid Scribe base or reinstall Scribe.

Publish one independently owned regular fragment per eligible feature in
`/opt/etc/logrotate.d/`, with stable CFMgr names such as `cfmgr-cloudflared`,
`cfmgr-ddns` and `cfmgr-ip-sync`. Identify ownership before replace/remove; use
explicit single-feature paths, private file permissions and validated effective
directives. Stage incomplete rules and recovery copies outside the included
directory, then publish atomically under the existing transaction/storage guards.
Check actual filename exclusions, permissions, duplicate coverage and include
order; file presence alone does not prove logrotate will read the rule. Preserve
the top-level config, global rules and foreign fragments. A missing/invalid global
directory include is a Scribe/base-readiness fault to report, not permission to
rewrite `/opt/etc/logrotate.conf`; scoped repair may change only verified owned
registrations within an already valid base.

Scribe's scheduled rotation invokes logrotate with `/opt/etc/logrotate.conf`;
logrotate reads included fragments afresh on each invocation. A newly committed
valid fragment is therefore discovered on the **next existing scheduled run**.
No Scribe re-detect/reload/restart, syslog-ng HUP, immediate forced rotation or new
cron is needed merely to add/change a rule. Discovery does not mean the size/time
rotation condition has already been met. The CFMgr Re-detect menu action above
rechecks/enables CFMgr logging; it is not a Scribe reload command.

For explicit install/repair validation, use the admitted logrotate executable's
bounded direct debug invocation (`/opt/sbin/logrotate -d /opt/etc/logrotate.conf`)
with private bounded diagnostic capture. It must leave logs/state unchanged and
execute no rotation scripts. Do not substitute Scribe's status/debug wrappers:
reviewed versions perform integration/configuration writes around their checks.
Validate the candidate effective include chain and final committed rule with
concurrent rotation handled by the logging transaction; failure retains or
restores the previous valid owned policy. No full debug invocation on healthy
ordinary launch.

The directory include follows the [Entware logrotate package's config patch](https://github.com/Entware/entware-packages/blob/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd/utils/logrotate/patches/500-config.patch).
The invocation/refresh behavior follows [Scribe's rotation implementation](https://github.com/AMTM-OSR/scribe/blob/53dee6e97c2d6aa4f656c68c18fa1f2c499042f7/scribe.sh)
and the [logrotate include/debug contract](https://github.com/logrotate/logrotate/blob/main/logrotate.8.in).
The shared `/opt` prefix is documented by [Entware](https://github.com/Entware/Entware/wiki#installation);
the [Merlin Entware guide](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Entware)
describes the separate storage/install prerequisite. Validate installed versions
and capabilities; these sources do not prove every historical router or a live
rotation outcome.

Commit config/rule coherently with rollback. Rule-only/native policy repair needs no tunnel restart/provider sync. Only a real logfile-argument change for a valid still-On connector can need an internal controller restart. Name actual repaired rule/feature and distinguish success, failure, unavailable and deferred. Status only reports observations.

### Uninstall logging

After explicit review, durably save inactive preference and scoped cleanup/generation guard **before** quiescing writers or deleting data. Preserve service configured/enabled/maintenance intent and operational hooks/jobs. This is internal temporary quiescence, not public Stop/Off.

1. Stop/quiesce only the verified owned writer before deleting its open logfile, even when readiness fails or Scribe has been removed. Failed stop retains the log and temporary guard; no false stopped/deleted result.
2. On verified writable storage remove found owned selected-feature log/rotations with bounded inventory and symlink/foreign-root protection. Preserve other features, native messages, shared directory and manual archives. This does not require usable Scribe.
3. If Scribe is detected, remove surviving independently verified owned fragment/include only where safe whole-file ownership/syntax/concurrency checks pass. If fully absent, skip Scribe configuration work. Never heal/recreate base just to uninstall, change global policy or control its daemon/job.
4. Once writer quiescence and durable opt-out are verified, release the temporary runtime guard even if safe residual file/rule deletion is still pending. Retain cleanup metadata and inactive self-heal. Pending cleanup alone must not block eligible native APIs/messages or a ready no-file connector.
5. Resume only still-On valid current-generation Cloudflared through readiness **without logfile arguments**; failure leaves truthful waiting/deferred with saved On for watchdog. Native jobs resume eligible work without forced publication. Off remains Off.
6. Clear cleanup metadata only when required safe deletion resolves. Missing/read-only/lost mount defers without stale writes or false completion. Later explicit Install/enable or the shared Re-detect logging action must resolve pending cleanup first. Re-detect may then enable logging for configured On services as specified above; ordinary restore/reinstall/automatic repair preserves opt-out.

### Optional external log viewing

uiScribe is optional and outside required delivery unless a supported integration is explicitly selected. Direct logfiles plus logrotate do not automatically establish viewer discovery. Do not fake unused syslog-ng destinations, patch private generated viewer lists, relax parent-directory permissions or mirror the daemon stream merely to expose files. A future supported external-log registry must constrain owned/redacted paths, labels, bounded file sizes and safe clear/rotate/reinstall behavior. It is not a CFMgr WebUI.

## 14. Backup and restore

| ID | Subgoal | Required result |
| --- | --- | --- |
| S14.01 | Manual CFMgr-only archives | Native unencrypted data-only tar.gz, privacy notice/best-effort modes, no router/add-on/code backup or schedule. |
| S14.02 | Mounted-drive picker | Explicit numbered exact mount identity including one drive, root CFBackup, no stale/fallback destination. |
| S14.03 | Archive selection/actions | Numbered newest list, inspect/verify/review restore and confirmed deletion; alternate source does not reset destination. |
| S14.04 | Local date naming | Regional date choice, same-day time suffix/collision refusal and manifest chronology across format/DST changes. |
| S14.05 | Verified-new-first retention | Keep 3–5 same-set completed archives; prune only after verified commit and report purge failure separately. |
| S14.06 | Coherent data allowlist | Config/catalog/typed authority/drafts/full YAML/JSON/both cert copies/.bak/preferences/eligible history; no live controls/executables. |
| S14.07 | Required versus optional payload | Required authority/YAML cannot be omitted; external dependencies inventoried, optional cert/binary absence handled honestly. |
| S14.08 | Backup transaction | Consistent bounded source/rotation locks, private same-filesystem archive, hashes/mount recheck/atomic commit. |
| S14.09 | Safe current-code restore | Exact input/schema/hash/path/type/size validation, supported migration and current components, no archive code/downgrade. |
| S14.10 | State-aware reconstruction | Never-configured/draft/maintenance/On/Off rules, independent logging preference and explicitly deferred optional history. |
| S14.11 | Guarded restore/recovery | Fresh local ownership/generation, current auth/source admission, local rollback distinct from new auth-Off and no stale replay. |

### Scope and destination

Backups cover **CFMgr's own data/setup only**, using native unencrypted `.tar.gz`. No whole-router/NVRAM/Entware/add-on backup and no displaced DDNS provider/handler. Explain in normal review/docs that archives contain operational credentials and the user is responsible for privacy; use best-effort `700` folder/`600` archive modes. Do not add an encryption dependency, extra privacy approval gate or reject a valid drive solely because its filesystem lacks POSIX modes.

Manual create/list/inspect/verify/restore/delete only; no automatic user archive, backup cron or calendar tiers. Internal transaction recovery copies are separate, require no configured backup drive and are not pruned as archives.

Enumerate actual usable mounted drives under `/tmp/mnt` (`/mnt` only if verified same namespace), not leftover directories. Show vertical numbered label/full-mountpoint choices and `e`; require explicit choice even for one drive. Safely handle spaces/duplicate labels. Save exact mount identity/path, recheck each use and require reselection when missing/changed; never fallback silently. Create/reuse root-level `CFBackup` only after selection/checks, preserving unrelated content.

Restore may choose another source drive without silently changing saved backup destination. List recognized archives newest first with short numbered local-date labels; show detailed manifest/feature/effect review after selection. Empty lists, invalid input, `e`/Ctrl+C and no usable drive return cleanly. Native menus need no `fzf` installation/detection.

### Names and retention

Use router local time/timezone and a reliable firmware date-format preference if available; otherwise offer DMY/MDY/YMD explicitly, never infer date order from country/timezone. First same-local-day archive is `CFbackup-<regional-date>.tar.gz`; subsequent ones add `_hh-mm-ss`. Examples: `CFbackup-08-10-26.tar.gz`, then `CFbackup-08-10-26_21-45-12.tar.gz` for DMY. Never overwrite exact timestamp collisions; report and retry with a distinct time.

Manifest records creation timestamp/UTC reference, local calendar date, timezone/display format and backup-set identity. Detect same-day/order/age from metadata, not localized lexical filenames, including format changes and DST repeats. `backup_keep` accepts 3–5, proposed default 5. Count only recognized completed same-set archives. Verify/commit a new backup before oldest-first pruning; failed/cancelled/full-disk creation never deletes usable old archives to make room. Report successful creation separately from failed retention cleanup. Selected single-archive deletion is explicit and confirmed.

### Data allowlist

| Include as coherent validated data | Restore meaning |
| --- | --- |
| Main config, separate catalog, typed credentials/expected identities, feature configured/On-Off/maintenance/preferences and inert setup drafts | Current schema/migration; no source/eval, no activation inferred from file presence/draft/history. |
| Full owned user YAML, matching runtime JSON, selected live cert and original-byte JFFS cert recovery copy with provenance | One coherent generation, safe remapping, same identity/secret authority. Either trusted certificate copy may recover the other. Preserve full application content. |
| Optional inventoried owned `config.yml.bak` | Inactive user recovery data; hash/type/path/ownership checked; never auto-apply it as runtime authority. No certificate-only or single-file restore UI. |
| Saved logging opt-in/opt-out, Cloudflared tuning and fixed native policy version | Rebuild owned rules from current templates when ready; opt-out stays inactive. |
| Eligible configured-feature owned logs/rotations, including Off history when Entware/Scribe are ready | Record included/absent/unavailable per feature; independent Scribe rotation can continue without service activation. |
| Compact historical observations and advisory source fault/repair intent | History only, never current auth/health, queued work, process ownership or permission to reenable. |
| Existing remote resource references and required owned allowlisted external YAML data | Preserve references; backup cannot resurrect deleted remote objects. Inventory other YAML dependencies and report foreign/missing files/remapping. |

Exclude manager/modules/helpers/code, Cloudflared binaries/`.old`, executable hooks/jobs/generated rotation fragments, whole syslog, foreign data, live setup-state/transaction journals/recovery copies, active auth/runtime guards, PIDs/locks/queues/cooldowns/retry_due/current-success cache, downloads/staging and CFBackup itself. Explicit owned `.bak` and certificate recovery copies are durable user data, distinct from excluded live journals. Do not archive all of `/opt/etc/cloudflared/` indiscriminately.

No provider call is required merely to archive local data. Missing optional management certificate or intentionally uninstalled binary is not a configured UUID+JSON data-backup failure. Missing required trustworthy authority/full YAML/runtime payload without valid recovery is a real failure; no silent omission. Whole YAML inclusion alone does not prove every referenced external file is portable or backed up.

### Backup transaction

Validate selected source scopes, backup mount, tools/space and coherent committed configuration. Refuse/defer a damaged, quarantined or active incomplete setup/update/restore transaction. Use documented non-deadlocking locks for config, writers and rotation; capture consistent data without unnecessary tunnel restart.

Build a private temporary archive on the selected backup filesystem with relative allowlisted paths and a versioned manifest containing state, chronology, modes and hashes. Verify readability and all required payload hashes, recheck mount, then atomically name it in CFBackup. Only then report success and prune. Compression failure, mount loss or cancellation removes only this operation's safe owned temporary data and retains old archives/recovery.

Native-only data needs no tunnel folder; backup destination need not be Entware. Actual tool prerequisites still apply. Required tunnel data/history separately needs its verified storage. No automatic manual archive during setup/update/migration/restore.

### Current-code restore and activation

Install trusted current CFMgr first if entry is absent. Validate data/archive/schema and manifest agreement before active writes; migrate supported older schemas with recovery, reject newer/unsupported schemas with compatible-manager guidance. Informational source version never chooses or downgrades executable code. Never execute/source archive content.

Validate the exact bytes later extracted/restored, not a swappable path. Bound compressed/expanded size, entry count/depth/metadata and extraction work; reject traversal/absolute paths, unsafe links/devices, conflicting duplicates and unsupported extended headers. Extract privately within approved scope roots, validate hashes/modes and required external dependencies before commit. Current code supplies integrations/installers/templates and verified ABI binary.

| Archived state | Reconstruction/activation |
| --- | --- |
| Never configured, no prepared maintenance | Shared settings/inert drafts only; no feature installation, logging setup, hooks/jobs/provider call or fabricated setup. |
| Configured On | Restore required data and current components; new local ownership/guard/generation, eligible hooks/jobs, fresh readiness/auth/source admission before actual work. |
| Configured Off | Restore full data/current components, including verified Cloudflared binary/helpers for its complete setup; remain operationally unhooked/Off. Only independently saved maintenance activation plus update preference permits idle updater. |
| Prepared maintenance without completed tunnel | Rebuild current verified binary/helpers; updater only if maintenance_enabled + preference, never connector/watchdog/tunnel logging. Inert draft remains incomplete. |
| Configured Off with requested logging history | Current owned rotation may be rebuilt when Scribe/storage ready; service remains Off while Scribe rotates. Explicit opt-out never heals/enables from restored log presence. |

An explicit Cloudflared Off archive has both activation flags false; a later separate maintenance action is the only Off-tunnel updater exception. Required tunnel data/storage cannot be silently skipped. For native-only restore with optional archived logs but unavailable history storage, explicitly offer core restore with history deferred and retain the archive/report that history is not restored; shared operational tools still gate actual publication.

Review state/migrations/paths/integration/remapping/deferred history, then Save. Persist a fresh local restore guard and recovery copies, pause affected owned work and boundedly stop a superseded owned connector before commit. Stage coherent JFFS/Entware data, regenerate derived JSON/token from authority, preserve full YAML and reconstruct only saved configured/prepared scope through current code. Remove stale owned integration for absent features without purging their old data or touching foreign files.

Bootstrap eligible On through current remote/auth/source gates; no API call merely because Off files were restored. Definitive current rejection creates a new local fault/Off; transient/throttle stays On waiting. Missing whole tunnel/list identities require reviewed repair, never automatic recreation; missing configured active DNS definitions follow the ordinary admitted reconciliation in section 9. Commit coherent local state then release guard/resume fresh work, never replay historical caches/queues/auth intent. Local commit failure rolls back or quarantines; a legitimate new auth-Off/waiting result must not roll back blindly into faulty On or erase its fault. Preserve archive/recovery and report actual outcome.

## 15. Uninstall, retained installation and reset

| ID | Subgoal | Required result |
| --- | --- | --- |
| S15.01 | Reviewed legacy migration | Recognized data/ownership only, private staged settings and one-controller recovery without foreign adoption. |
| S15.02 | Explicit removal choices | Full uninstall KEEP default versus confirmed WIPE, separate confirmed reset and guard-before-stop/delete. |
| S15.03 | Common owned cleanup | Detach own integration/jobs, stop owned work, remove runtime/log components and preserve foreign/manual/remote data. |
| S15.04 | KEEP | Retain full primary YAML/JSON/cert/JFFS authority/cert/.bak/catalog/preferences/drafts/intent behind retained-install guard. |
| S15.05 | WIPE | After safe cleanup remove all owned data plus exact canonical manager directory/entry, refusing substituted/foreign roots. |
| S15.06 | Passive reset | Keep verified package, finish owned cleanup then regenerate passive defaults with update-check On/auto Off. |
| S15.07 | Retained reconstruction | Detect before defaults, validate/reuse same files, current-code rebuild without wizard/login/create and preserve Off. |
| S15.08 | Incomplete cleanup/recovery | Missing/lost/read-only storage or uncertain ownership retains recovery entry/guard and honest pending state. |
| S15.09 | Cloudflared-only full reset | Confirmed full removal of owned local tunnel setup/runtime/logging, preserving manager, DDNS/IP-Sync, shared credentials still in use, backups and remote resources. |

### Migration and removal ownership

Read recognized legacy scripts/config/settings/hooks/jobs as data; privately stage typed settings and reviewed owned migration with rollback. Preserve foreign controllers, concurrent edits and one connector. Do not execute a legacy script to import secrets, recursively adopt directories or treat a generic job name as ownership. DDNS explicit handoff still follows its no-previous-provider-backup rule.

Full uninstall first reviews scope, then asks `Wipe everything? [y/N]`. Blank/`n` selects KEEP; `y` selects WIPE. Reset is a separate explicit destructive confirmation; empty/cancel never approves it. Before stop/delete, durably record intent and close activation/reconstruction gates independently of the old config's On flags.

Common full-removal cleanup detaches exact owned feature/maintenance/manager-check hooks/jobs, boundedly stops verified owned work, removes owned/adopted binary/updater/watchdog/old/staging components and own logging integration/files. Preserve Entware itself, Scribe globals/schedule, other add-ons, foreign files, native system messages, manual archives and remote resources. Never follow substituted links or delete shared roots. Required missing/read-only/changed storage or stop failure retains recovery/guard and reports incomplete cleanup; do not remove the usable recovery entry prematurely or claim success.

### Outcomes

| Action | Retain | Remove / next behavior |
| --- | --- | --- |
| Full uninstall KEEP | Private main config/catalog, typed credentials, saved activation/maintenance/preferences/drafts, primary Entware YAML/JSON/cert, JFFS cert copy, owned `.bak`, retained identity and necessary recovery | Remove installed manager/runtime components and operational/log integration through common cleanup. Preserve saved On intent behind the non-runnable installation guard, not by pretending it is public Off. |
| Full uninstall WIPE | Foreign files/add-ons, manual backups and remote resources | After successful common cleanup, remove all positively owned settings/data/cert copies/`.bak`/drafts/state/recovery and exact canonical `/jffs/addons/CFMgr.d/` plus installed entry. Success requires directory absence, not deletion of a few known files. Refuse substituted/foreign directory content rather than blanket-delete it. |
| Initialise / reset everything | Verified current manager package and its necessary distribution files | Reuse owned WIPE cleanup, then generate passive defaults: all feature activation/configuration false, maintenance Off, manager auto-update Off/checks On/developer false. No wizard or provider creation. Keep guard until cleanup/default generation succeeds. |

### Cloudflared-only full uninstall/reset

The Cloudflared submenu also offers a separate confirmed **Uninstall/reset
Cloudflared completely** action. Durably record scoped reset intent and close
admission before stopping/removing its owned
binary/maintenance components, hooks/jobs, local A/B credentials and configuration,
certificate copies, owned YAML backup, logfiles/rotations/history and log/rotation
integration. Clear only its
main-config setup/activation/maintenance/preferences and applicable drafts/faults.
Preserve manager/source/update/backup settings, DDNS/IP-Sync, shared dependencies,
credentials still referenced elsewhere, foreign files, manual archives and remote
tunnels/DNS/routes/lists. Do not delete a shared account credential just because the
tunnel used it. No fresh wizard or provider call is implied. Incomplete stop/storage
cleanup keeps the appropriate guard/recovery data and truthful pending result.
This full local reset is distinct from setup-preserving reinstall, which stages and
verifies the replacement before stopping/replacing the old binary and reconstructs
only the saved eligible runtime/maintenance jobs.

### First install after KEEP

Detect completed retained removal before fresh defaults; distinguish it from interrupted removal. Validate retained master/identity/mount/user YAML and reconstruct current configured or explicitly prepared maintenance components without wizard/login/create. Reuse matching primary files unchanged; repair only missing/actual owned drift from trusted authority. Missing whole YAML requires a full trusted recovery/import, never a generated starter that loses ingress.

Preserve Off as operationally unhooked even when reconstructing its binary/data; restore eligible On/maintenance only after current guards/readiness. Missing Entware defers dependent reconstruction honestly while native recovery/status remain available. Corrupt retained state enters repair instead of resetting defaults. This reconstruction is distinct from live manager `u`/`uf`, which must not reinstall healthy feature components.

## 16. Product readiness and documentation

| ID | Subgoal | Required result |
| --- | --- | --- |
| S16.01 | Usable integrated product | Required workflows and acceptance work through actual user entry paths within declared support. |
| S16.02 | Evidence and limitations | Source/host/BusyBox/kernel/live classes separate; no ready claim for missing required proof, IPv6 provisional explicit. |
| S16.03 | Complete practical guides | Keep interim developer notes small until most goals are met; complete architecture/developer and install/setup/credentials/operation/update/recovery/logging/archive/removal guides before product readiness. |
| S16.04 | Cloudflare prerequisites | Account/domain/DNS and policy wiring guidance in docs, no extra runtime prompts or private-network restriction. |
| S16.05 | Safe reproducible delivery | Sanitized examples/screenshots and validated real installer command/failure behavior. |
| S16.06 | Release readiness | Coherent first version/beta semantics and required functionality/documentation before optional final polish. |

The finished product is the complete CLI described here, integrated and validated
within a declared supported platform scope. Source-only helpers, a passing fixture
suite or a live PID cannot establish ready-to-use operation. Required live behavior
remains unaccepted without its appropriate evidence; optional live IPv6-only gaps
remain explicitly provisional rather than being reported as passed.

During implementation, keep README focused on the implementation overview and
main-goal status. Keep temporary developer/tool notes small and accurate. Build
the full documentation set, including architecture and developer guides, when
most or all implementation goals are met; complete required guides before
claiming ready-to-use 100%. Do not expand interim notes into a premature manual.

User documentation must cover installation, dependencies, dedicated feature setup,
credentials and permissions, current operation/status, updates, outages/repair,
logging, manual data backup/restore, migration/removal and supported limitations.
Explain Cloudflare account creation and Cloudflare-managed domain/DNS prerequisites
for DDNS and public tunnel hostnames, including domains registered elsewhere, in
documentation rather than extra script prompts. Preserve private-network-only
tunnel support. Explain second-list Access policy wiring and IPv6 host-only scope.

Examples/screenshots must be sanitized. A copy-and-paste installer command is only
an accepted deliverable when the real installer and its download/permission/invoke
failure path are validated. Document practical current commands, exact minimum
tools and kernel/userspace/ABI boundaries without claiming universal router support.

### Documentation set

The following set defines S16.03 coverage now; the full guides are written near
product readiness. Paths name planned deliverables, not currently available
pages. Keep README as the overview and the current development note compact.
Describe actual delivered behavior and limits when writing each guide; shared
facts have one authoritative home with links from related tasks.

| Planned document | Required coverage | Product goals |
| --- | --- | --- |
| `README.md` | Product overview, intended versus implemented main goals, readiness and guide navigation. | All goals |
| `docs/setup.md` | Verified installation/prerequisites, first launch, private defaults and independent DDNS, Cloudflared and IP-Sync setup. | 1–3, 5, 9–10 |
| `docs/credentials.md` | Cloudflare account/domain/DNS prerequisites, minimum scoped permissions, token/JSON/certificate choices, policy wiring and safe credential handling. | 5, 9–11, 16 |
| `docs/operation.md` | Menus and commands, Save/On/Off, dashboard/health, address evidence and normal DDNS/tunnel/IP-Sync operation. | 3–6, 8–10 |
| `docs/maintenance.md` | Manager updates/reinstall and source/developer selection, Cloudflared binary maintenance and separate selected Entware repair/reinstall. | 2, 6–7 |
| `docs/recovery.md` | Failed setup/save/update, missing storage/dependencies, outages, credential faults, damaged hook blocks, rollback and interrupted-operation recovery. | 2–4, 7–8, 11–12, 15 |
| `docs/logging.md` | Native system messages, per-feature Scribe logging, /opt/var/log storage, owned logrotate policy, re-detection and truthful failure handling. | 12–13 |
| `docs/backup-and-removal.md` | Manual archives, validated restore/migration, backup storage/retention, KEEP/WIPE uninstall, retained installation and scoped resets. | 14–15 |
| `docs/compatibility.md` | Declared firmware/native-tool/ABI support, required capabilities, source/host/BusyBox/kernel/live evidence and provisional limitations. | 2, 8, 16 |
| `docs/architecture.md` | Actual entry/module/shared-library interfaces, storage/state authority, ownership/locks, transactions, worker/lifecycle/resolver/provider flows and integration boundaries. | 1–15 |
| `docs/development.md` | Reproducible environment, source references, focused/full/platform testing, fixtures and cost controls, CI/tools, package generation and release/beta workflow. | All goals, especially 2, 7, 16 |
| `CONTRIBUTING.md` | Concise change/review workflow, scope/checklist discipline, validation/privacy rules and links to development/architecture guidance. | 16 |

Full-guide readiness requires verified commands and failure guidance, accurate
scope/compatibility claims, sanitized examples, working links and agreement with
the accepted runtime/tests. A small interim page does not complete its final-guide
obligation. These documents are coverage within S16.03, not extra product goals or
percentage points. Reassess grouping near completion if the implementation makes
another arrangement clearer, preserving every required topic.

The first release version is assigned when the product is ready to use, followed
by beta. Version identity, manifest comparison and beta ordering must agree.
Necessary library organization and practical documentation belong to functional
readiness. Optional final polish and broad optimization may follow it. A future
CFMgr WebUI remains outside this product scope.

## 17. Open product decisions

These details need concrete supported decisions before their dependent product behavior can be accepted. Proposed values remain proposals until settled.

| Area | Decision/proof required |
| --- | --- |
| Configuration/transactions | Exact bounded schema/ref/generation/guard formats; reliable write/flush/rename and failure reporting; supported native JSON/certificate/YAML subset; scoped merge and cross-filesystem recovery. |
| Package distribution | Source-to-installed path mapping, bootstrap manifest trust, complete generation activation/reader retention, main-config source grammar/normal-main reset, snapshot catalog grammar, supported historical snapshots and development-commit comparison; beta version grammar before first release. |
| Supported platforms | Actual native paths/options/CA, minimal kernel/userspace ABI/capability profiles and official binary compatibility; no unsupported legacy promise based solely on feed names. |
| Storage/processes | Persistent/attached volume identity, mount-race handling, approved path whitelist, lock order/descriptor lifetime, child identity/quiescence and uninterruptible-I/O limitation. |
| Budgets/readiness | Aggregate hook/DDNS/worker/response/staging/queue bounds; monotonic clocks, NTP/transport/egress evidence, reconnect grace/stability criteria, common outage retry fixed at 1/2/4/5 minutes (300-second cap); verify scoped provider-delay parsing and separate no-hint throttle 5/10/20/30-minute state. |
| Firmware DDNS | DDNS soft timer inside matched whole-action ceiling, overlap without request IDs and native retry collision; default 14-day field/bounds/apply/persistence/certificate side effects and ownership relinquishment. |
| Native discovery | Selected WAN/protocol/interface mapping, complete absence evidence, routed IPv4/IPv6 observations/lifetimes and scoped support for less-common firmware modes. |
| Provider operations | Permissions, pagination/completeness, exact managed fields, same-ID empty-list removal, actual mixed-family-list capability, user-selected shared/split migration and target-vs-feature fault schema; no extra feature inferred from uncertain API behavior. |
| Cloudflared | Token-file floor/default-config isolation, A2 create/token endpoint permissions and failure handling, B route-discovery completeness/lossless mapping edits, login/certificate provenance/manual fallback, same-UUID fetch and runtime auth/connectivity classifier; no implicit binary auto-update default where not selected. |
| Scheduling | Exact manager daily cron time/registration/removal; shared minute dispatcher, five-minute native discovery and per-scope due-state reconciliation with native DDNS retries. |
| Logging | Actual Scribe/include/schedule state, daemon reopen/copytruncate, rotation concurrency; proposed Cloudflared 10M/five-total-files/compression and native 1M/two-total-files defaults, safe count-one reuse and launch budgets. |
| Backup | Stock tar/gzip behavior/input bounds, regional date evidence, proposed default keep 5, archive chronology/set identity, consistent eligible log snapshot and required external YAML dependencies. |

Settle a decision from official source/capability evidence and user scope before shipping dependent behavior. If a supported minimum cannot meet a required contract, present the concrete limitation and choice rather than silently weakening it, inventing a dependency or drifting into an unbounded redesign.

## 18. Reference authorities

Use these as research authorities when implementing/rechecking their contracts, not as claims that a current installed version was tested. Keep private baseline/evidence locations in ignored local storage; do not embed workstation paths or secrets in public files.

| Authority | Purpose |
| --- | --- |
| Original private `cloudflared/setup/` and its guides | Source parity for hooks, lifecycle, readiness, updater, DDNS, Access queue/dry-run and full advanced data. |
| [Merlin Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API), [User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts), [Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files) | Add-on storage/settings, hook contracts and firmware configuration boundaries; cross-check matched firmware source. |
| [Merlin Custom DDNS](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-DDNS), [Entware guide](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Entware), [official firmware source](https://github.com/RMerl/asuswrt-merlin.ng) | Completion/apply behavior, shared operational tools, model/version-specific capabilities. |
| [Merlin 3004.388.12_2 DDNS service](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/services.c#L5055), [native watchdog](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/watchdog.c#L7142) | Pinned custom-hook timeout, completion callback, native failure retries and `ddns_refresh_x` forced-day scheduling; source evidence, not universal runtime proof. |
| [Official Cloudflared releases](https://github.com/cloudflare/cloudflared/releases), [release-assets API](https://docs.github.com/en/rest/releases/assets), [Cloudflared source](https://github.com/cloudflare/cloudflared) | Exact asset trust, ABI/version, login/create/credential behavior, supported runtime evidence. |
| [Cloudflare Tunnel API setup](https://developers.cloudflare.com/tunnel/get-started/), [create-tunnel API](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/methods/create/) | A2 account-scoped remote tunnel creation, separate management authority, connector-token acquisition and dashboard-managed mode. |
| [Dashboard tunnel setup](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/), [local tunnel setup](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/create-local-tunnel/), [configuration](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/configuration-file/), [run parameters](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/run-parameters/) | A/B workflows, credentials, applications/private networks and token-file/updater controls. |
| [DNS list](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/list/), [edit](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/edit/), [create](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/create/), [delete](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/delete/) | Managed DNS current-state reconciliation and endpoint-specific permissions/results. |
| [Gateway lists](https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/subresources/lists/methods/list/), [update](https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/subresources/lists/methods/update/), [item removal](https://developers.cloudflare.com/api/resources/zero_trust/subresources/gateway/subresources/lists/methods/edit/), [Access policy selectors](https://developers.cloudflare.com/cloudflare-one/access-controls/policies/) | Discovery, exact target identity, nonempty replacement/empty clear and user-managed policy wiring. |
| [Cloudflare Zero Trust lists](https://developers.cloudflare.com/cloudflare-one/reusable-components/lists/), [IPv6 prefix translation RFC 6296](https://www.rfc-editor.org/rfc/rfc6296.html) | Actual selected-list capability and IPv6 translation/observed-public-address boundaries; do not infer support from WAF lists or IPv4 CGNAT ranges. |
| [Cloudflare API limits](https://developers.cloudflare.com/fundamentals/api/reference/limits/), [curl manual](https://curl.se/docs/manpage.html) | Endpoint rate/error evidence, transport isolation and actual-version limit behavior. |
| [RFC 6598](https://www.rfc-editor.org/rfc/rfc6598), [IANA IPv4 registry](https://www.iana.org/assignments/iana-ipv4-special-registry/), [RFC 5952](https://www.rfc-editor.org/rfc/rfc5952), [IANA IPv6 registry](https://www.iana.org/assignments/iana-ipv6-special-registry/) | Public-host classification, exceptions and canonical representation. |
| [Scribe](https://github.com/AMTM-OSR/scribe), [logrotate manual](https://github.com/logrotate/logrotate/blob/main/logrotate.8.in) | Optional logging base/readiness, owned include policy and actual installed rotation behavior. |
| [amtm](https://github.com/decoderman/amtm), [uiScribe](https://github.com/AMTM-OSR/uiScribe) | Optional personal launcher/viewer boundaries; no required catalog/WebUI feature. |
| [Skynet](https://github.com/Adamm00/IPSet_ASUS), [VPNMgr](https://github.com/h0me5k1n/vpnmgr), [BackupMon](https://github.com/ViktorJp/BACKUPMON) | Supplemental menu/native archive examples, never authority overriding CFMgr scope, trust or ownership contracts. |
