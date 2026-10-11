# CFMgr v2 — project checklist

[Product specification](PLAN_V2.md) · [Current handoff](PLAN_V2_handoff.md) · [Working rules](AGENTS.md)

This checklist owns product acceptance and delivery status. The specification owns
required behavior; the handoff owns current work and pending evidence; AGENTS.md
owns execution and publication rules. Administrative preparation/cleanup does not
earn product ticks.

## Completion assessment

**0 of 16 main goals complete — 0% product completion.** The user-selected
calculation is `completed main goals / 16 × 100`; every completed main goal adds
6.25%. Partial subgoals remain visible without increasing this percentage.
Task-workload estimates are separate. No archived completion is imported.

**Subgoal gate:** write and pass focused local tests. Where BusyBox/Linux/kernel
CI evidence is required, retain pending status until that exact-commit proof
passes. Source review and preliminary smokes are not the focused-test gate.
**Main-goal gate:** all required subgoals complete, parent codebase/scope audit,
and full local/full CI suites. The full procedures are in [AGENTS.md](AGENTS.md).
Incomplete work remains unchecked; that status does not authorize deletion or
reduction of its requirements.
The main-goal box and README completion change only after that full evidence is
accepted. A locally validated candidate awaiting required CI is still incomplete.

## Main-goal completion gates

Each product subgoal below has separate **focused local** evidence and **final
status**. Focused evidence means the relevant written tests passed, not merely
syntax or smoke checks. Final subgoal status also requires any specific platform
proof; BusyBox-dependent subgoals remain pending until exact-commit CI.

A main goal needs every required subgoal complete, the codebase audit, and full
local/full CI suites before its final tick. Product completion is the number of
completed main goals out of 16. Optional/out-of-scope items cannot inflate this
denominator.

| Main goal | Required subgoals complete | Codebase audit | Full local suite | Full CI | Final goal |
| --- | --- | --- | --- | --- | --- |
| 1 — Product scope | [ ] | [ ] | [ ] | [ ] | [ ] |
| 2 — Installation and dependencies | [ ] | [ ] | [ ] | [ ] | [ ] |
| 3 — Configuration, menus and status | [ ] | [ ] | [ ] | [ ] | [ ] |
| 4 — Save and recovery | [ ] | [ ] | [ ] | [ ] | [ ] |
| 5 — Cloudflared setup | [ ] | [ ] | [ ] | [ ] | [ ] |
| 6 — Tunnel lifecycle | [ ] | [ ] | [ ] | [ ] | [ ] |
| 7 — CFMgr updates | [ ] | [ ] | [ ] | [ ] | [ ] |
| 8 — Shared addresses | [ ] | [ ] | [ ] | [ ] | [ ] |
| 9 — DDNS | [ ] | [ ] | [ ] | [ ] | [ ] |
| 10 — IP-Sync | [ ] | [ ] | [ ] | [ ] | [ ] |
| 11 — Provider failures | [ ] | [ ] | [ ] | [ ] | [ ] |
| 12 — Hooks and schedules | [ ] | [ ] | [ ] | [ ] | [ ] |
| 13 — Logging | [ ] | [ ] | [ ] | [ ] | [ ] |
| 14 — Backup and restore | [ ] | [ ] | [ ] | [ ] | [ ] |
| 15 — Uninstall and reset | [ ] | [ ] | [ ] | [ ] | [ ] |
| 16 — Product readiness | [ ] | [ ] | [ ] | [ ] | [ ] |

## Accepted product evidence

None yet: native storage prerequisites are being implemented, with current work
and pending proof in the handoff. All 156 subgoals and the acceptance cases below
remain unchecked. Partial helpers and planning checks do not establish complete
Save, feature, BusyBox/kernel or live router acceptance.

For each future accepted subgoal, record its actual consumer, focused test
references/command and result, tested revision, and required exact platform CI
run. Main-goal evidence also records the codebase audit, full local/full CI results
and parent review, with the accepted revision.
Current partial work, missing proof and next actions belong in the handoff.

## Product goals and subgoal evidence

Focused-local is a separate evidence step; final status requires the complete
subgoal and applicable CI/platform proof. Partial helper/report coverage does not
justify a focused-complete checkbox for an otherwise unfinished subgoal.

### 1. Product scope and boundaries

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S01.01 | **CLI product:** One terminal manager with independently configured DDNS, one tunnel and IP-Sync. |
| [ ] | [ ] | S01.02 | **Source parity:** Replace all router Python paths while preserving the specified lifecycle, updater, DDNS and Access behaviors. |
| [ ] | [ ] | S01.03 | **Feature isolation:** No forced setup, credentials or activation of unselected features. |
| [ ] | [ ] | S01.04 | **Scope boundaries:** No multi-tunnel manager, policy administration, automatic whole-list/old-tunnel deletion or whole-router backup. |
| [ ] | [ ] | S01.05 | **Optional future work:** CFMgr WebUI is outside current scope; external viewer/catalog integrations remain conditional. |

### 2. Installation, storage and dependencies

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S02.01 | **Modular distribution:** One verified package with extensible feature modules, shared libraries grouped by reused responsibility and thin entry/hooks. |
| [ ] | [ ] | S02.02 | **Private storage layout:** JFFS authority/recovery, RAM frequent state, verified Entware tunnel/log data, independent backup mount. |
| [ ] | [ ] | S02.03 | **Generated defaults:** Private extensionless config generated only for genuinely fresh setup; no shipped config/template. |
| [ ] | [ ] | S02.04 | **Shared operational prerequisites:** Verified jq, timeout and SHA-256; native-first flock and tunnel-only DNS additions. |
| [ ] | [ ] | S02.05 | **Normal dependency repair:** Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| [ ] | [ ] | S02.06 | **Selected dependency reinstall:** Explicit force action for mapped requirements, separate from tunnel maintenance and configuration. |
| [ ] | [ ] | S02.07 | **Native recovery access:** Status/doctor/recovery/safe Off remain usable without operational Entware tools. |
| [ ] | [ ] | S02.08 | **Storage identity and loss:** Verify actual expected volume/attachment and paths, stop dependent owned work on loss, never stale mountpoint writes. |
| [ ] | [ ] | S02.09 | **Capability-based support:** Actual native options, TLS trust, userspace ABI and bounded platform profiles; no inferred universal compatibility. |

### 3. Configuration, menus and status

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S03.01 | **Passive fresh state:** All three unconfigured/Off; no tunnel/logging/backup setup; manager check On and auto-install Off. |
| [ ] | [ ] | S03.02 | **Distinct state and settings:** Separate configured/enabled/installed/maintenance, credentials, options, guards and observations. |
| [ ] | [ ] | S03.03 | **Main menu and navigation:** 0/1/2/3/4/fx/ao/u/uf/e with exact dispatch, dedicated nesting and no navigation side effects. |
| [ ] | [ ] | S03.04 | **Feature submenus:** Own setup, On/Off, explicit operation, status and scoped logging/repair; only relevant options. |
| [ ] | [ ] | S03.05 | **Quick service commands:** Shared case-insensitive start/stop handlers, ipsync alias, configure-first validation and truthful results. |
| [ ] | [ ] | S03.06 | **Manager/diagnostic commands:** Update/force aliases, help/version and identical standalone health/doctor/diagnostic reports without implicit repair consent. |
| [ ] | [ ] | S03.07 | **Basic status dashboard:** Router/resource/address header and compact feature state, last verified family updates, age and current issue summary from local evidence. |
| [ ] | [ ] | S03.08 | **Bounded history and privacy:** Small recorded observations, accurate Unknown/Never/stale labels, no basic-status network calls or secret/raw-data dumps. |
| [ ] | [ ] | S03.09 | **Full health diagnostics:** Basic dashboard plus failure-tolerant dependency/config/storage/network/auth/integration/recovery checks; eligible read-only probes, local fallback and no repair. |
| [ ] | [ ] | S03.10 | **Terminal presentation:** Clear grouped tables, useful header and issue summary; bounded one-shot output with narrow-terminal/plain-text fallbacks and no UI dependency. |

### 4. Save, cancellation and recovery

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S04.01 | **Safe data parsing:** Bounded schema/JSON/certificate/YAML/catalog inputs treated as data, never sourced/evaluated. |
| [ ] | [ ] | S04.02 | **Scoped concurrent Save:** Accepted fields overwrite same-field edits, preserve unrelated guards/settings, detect content changes and respect later Off. |
| [ ] | [ ] | S04.03 | **Durable staged commit:** Pre-change intent/recovery, verified coherent publication and honest flush/write/rollback failure handling. |
| [ ] | [ ] | S04.04 | **Native resumable drafts:** Completed private DDNS/IP-Sync inputs survive exit/signals without touching active config or enabling work. |
| [ ] | [ ] | S04.05 | **Cloudflared Save boundary:** Pre-Save cancellation; mutation-time e disabled; signals honored with bounded cleanup and guarded recovery. |
| [ ] | [ ] | S04.06 | **Input/terminal handling:** No EOF/default-yes or noninteractive prompting; restore echo, reject unsafe controls and preserve literal data. |
| [ ] | [ ] | S04.07 | **Restart recovery:** Inspect guards before activation, preserve damaged/recoverable data and never repeat uncertain provider creation. |
| [ ] | [ ] | S04.08 | **Ownership and locks:** Stable lock identities, verified process start/boot identity, correct provider-child versus connector descriptor lifetime. |
| [ ] | [ ] | S04.09 | **Generation and resource bounds:** Compatible package per invocation, current-state checks, late-result rejection and bounded whole-action cleanup. |

### 5. Cloudflared setup and credentials

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S05.01 | **A1 existing-token setup:** Existing dashboard connector token, optional guide, private authority/handoff and no inactive YAML or extra management credential requirement. |
| [ ] | [ ] | S05.02 | **B choice and import:** y import versus n/Enter fresh; private placement/re-scan, explicit candidate and full referenced-data validation. |
| [ ] | [ ] | S05.03 | **Fresh named creation:** Reviewed Save, checked installer, same-account certificate/login, named CLI create and hostless http_status:404 starter. |
| [ ] | [ ] | S05.04 | **Mode switching:** One selected method/connector, validate candidate first, preserve Off and inactive/foreign material. |
| [ ] | [ ] | S05.05 | **Advanced configuration validation:** Published-app and private-network shapes, valid UUID/JSON, safe required paths and no guessed routing. |
| [ ] | [ ] | S05.06 | **Master and owned YAML fields:** Same account/UUID/secret JSON; routine identity-trio repair separated from explicit reviewed B ingress edits, preserving all other YAML. |
| [ ] | [ ] | S05.07 | **Runtime integrity no-op:** Matching files untouched; only real selected runtime drift repairs/restarts; missing whole YAML needs full recovery. |
| [ ] | [ ] | S05.08 | **Certificate recovery/provenance:** Original bytes with account/format/hash/generation, no redundant JFFS copy or missing-cert login loop. |
| [ ] | [ ] | S05.09 | **Browser login authority:** Current attempt/path/account validation, private terminal URL, no foreign-cert overwrite or login-only runtime-secret claim. |
| [ ] | [ ] | S05.10 | **Unknown NEW creation:** Guard incomplete outcome, preserve old generation and require manual dashboard cleanup/explicit retry; no auto lookup/create. |
| [ ] | [ ] | S05.11 | **Existing-ID credential repair:** Same-tunnel token or supported same-UUID JSON fetch; local regeneration never clears proven auth fault. |
| [ ] | [ ] | S05.12 | **Explicit replacement:** Default-no only after conclusive recovery failure; preserve full application YAML/owned .bak and manual old-tunnel deletion. |
| [ ] | [ ] | S05.13 | **B hostname mappings:** Discover exact selected-tunnel DNS routes and add multiple reviewed hostname/origin mappings with guarded DNS creation, lossless ingress edits and truthful partial recovery. |
| [ ] | [ ] | S05.14 | **A2 guided remote creation:** Separate account management credentials create a dashboard-managed tunnel after Save; verify/store connector token privately, with guide fallback and no blind create retry. |

### 6. Tunnel lifecycle and binary maintenance

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S06.01 | **Activation state model:** Correct configured/On-Off/installed/maintenance/update preference effects for every action. |
| [ ] | [ ] | S06.02 | **One lifecycle controller:** Shared control with independent download/activation locks and cheap healthy path. |
| [ ] | [ ] | S06.03 | **Readiness gates:** Expected storage/tools plus shared NTP/family-aware reachability and tunnel DNS, rechecked before launch and ordinary restart. |
| [ ] | [ ] | S06.04 | **Outage and connectivity:** Saved On retained, PID distinguished from connected, bounded grace/recovery and no restart storm. |
| [ ] | [ ] | S06.05 | **Owned stop/containment:** Bounded normal TERM, no routine unsafe replacement, narrowly rechecked corruption/auth escalation only. |
| [ ] | [ ] | S06.06 | **Retry and stability:** Shared monotonic outage retry at 1/2/4/5 minutes, five-minute cap, coalesced events, sustained-stability reset and no tick JFFS churn. |
| [ ] | [ ] | S06.07 | **Official binary acquisition:** Bounded exact origin/tag/asset SHA-256/ELF/version validation before stop or replacement. |
| [ ] | [ ] | S06.08 | **Foreign binary ownership:** Fixed bounded lookup and explicit adoption, no wrapper/symlink/foreign controller overwrite. |
| [ ] | [ ] | S06.09 | **Version policy:** Equal skip for updater, explicit equal/newer reinstall, no downgrade except protected rollback. |
| [ ] | [ ] | S06.10 | **Idle versus On recovery:** Artifact-only maintenance needs no tunnel launch; On uses fresh owned evidence, Off races win and rollback reports failed update. |

### 7. CFMgr updates, source selection and developer mode

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S07.01 | **Check and auto settings:** Default-On checks/default-Off opt-in install, coupled effective settings independent of tunnel/Entware. |
| [ ] | [ ] | S07.02 | **Launch/daily checks:** Bounded coalesced source checks, once-per-launch y/n update offer, RAM metadata and truthful unknown/error without redraw or boot blocking. |
| [ ] | [ ] | S07.03 | **Manual update/force:** Explicit revalidation/confirmation, current skip or complete reinstall; compatible older manager snapshot only through confirmed developer force. |
| [ ] | [ ] | S07.04 | **Unattended installation:** Saved opt-in and source/ownership rechecked at switch; active transactions defer safely. |
| [ ] | [ ] | S07.05 | **Developer suppression:** Manual-only flag suppresses checks/auto/external callbacks; confirmed force retains normal verification. |
| [ ] | [ ] | S07.06 | **Source selection and catalog:** One code-defined repository/branch default serves install and self-update; only developer mode permits config source overrides; catalog maps one immutable package. |
| [ ] | [ ] | S07.07 | **Developer source retention:** Developer retains configured source; normal operations use the shared code defaults (temporarily develop, later main); successful replacement resets source fields and replaces its catalog. |
| [ ] | [ ] | S07.08 | **Trusted complete package:** Manifest/hash/version/schema/path/syntax checks before execution, one pinned compatible generation. |
| [ ] | [ ] | S07.09 | **State-preserving update:** No healthy feature reinstall/restart/provider call or config loss; guarded actual owned drift only. |
| [ ] | [ ] | S07.10 | **Self-update failure recovery:** Distinct transfer/storage/switch/hook-reinjection/overlap/opt-out/rollback boundaries preserve last trusted complete package and report incomplete integration honestly. |
| [ ] | [ ] | S07.11 | **Optional amtm:** User-chosen personal launcher; official updater conditional with separate opt-in, no private registry hacks. |

### 8. Shared address discovery and reconciliation

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S08.01 | **Independent family states:** Active host, proven inactive or unknown per family; no deletion from missing/failed evidence. |
| [ ] | [ ] | S08.02 | **Current desired state:** Dual/one/no-family add/remove behavior; manual Off clears managed remote values, auth-Off only contains; IPv6-only remains provisional. |
| [ ] | [ ] | S08.03 | **Selected-WAN IPv4:** Public/private/shared/mismatch classification with correctly routed external evidence and honest NAT meaning. |
| [ ] | [ ] | S08.04 | **Global IPv6 host:** Current selected-WAN public host/lifetime/canonical form, verified translation when present; no ULA, delegated-prefix or arbitrary LAN/VPN publishing. |
| [ ] | [ ] | S08.05 | **Independent transport:** Per-family selected-egress discovery and either-family provider transport, with verified TLS and bounded fallback. |
| [ ] | [ ] | S08.06 | **Shared cache/freshness:** One coalesced resolver with independent current family identity/generation/time/lifetime records. |
| [ ] | [ ] | S08.07 | **DDNS and standalone reuse:** Resolve once, forward valid source independently of DNS result; standalone lists require no DNS setup. |
| [ ] | [ ] | S08.08 | **Events and periodic discovery:** Current enable/boot/WAN/IPv6/manual/periodic requests coalesce; no menu/status network work. |
| [ ] | [ ] | S08.09 | **Fresh remote authority:** Read complete configured remote targets every eligible run, correct managed drift and preserve unrelated metadata. |
| [ ] | [ ] | S08.10 | **Newest queue/retries:** Explicit add/remove intent per target/family, four-attempt and aggregate bounds, no stale replay or late success. |
| [ ] | [ ] | S08.11 | **Explicit Off cleanup:** Persist scoped cleanup before unhooking, clear list contents/managed A-AAAA while remaining Off, retain offline/auth-blocked intent and never infer cleanup from auth-Off. |

### 9. DDNS

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S09.01 | **Dedicated setup:** Scoped DNS token, zone ID/selection, names/attributes/primary hostname and native draft resume. |
| [ ] | [ ] | S09.02 | **Logical DNS scope:** Persist zone/name/type/creation attributes separately from IDs; handle all matching managed records. |
| [ ] | [ ] | S09.03 | **Active/inactive reconciliation:** Update, remove or recreate configured definitions from complete current evidence; unrelated types survive. |
| [ ] | [ ] | S09.04 | **Lost/partial outcomes:** Re-enumerate uncertain creates/deletes, no duplicate POST or full success while unresolved. |
| [ ] | [ ] | S09.05 | **Firmware handoff:** Reviewed Save/Enable replaces prior provider/handler without extra takeover prompt or displaced-setup backup. |
| [ ] | [ ] | S09.06 | **Scoped firmware settings:** Custom client, chosen primary hostname and native forced-refresh days (default 14), preserving other settings/IP-Sync with verified nonredundant apply. |
| [ ] | [ ] | S09.07 | **Ownership relinquishment:** Off/uninstall/repair respects still-owned integration and later external ownership, never restores old provider. |
| [ ] | [ ] | S09.08 | **Bounded completion:** DDNS-specific soft completion timer inside the proved firmware cap, one truthful invocation result and prompt early-unready return. |
| [ ] | [ ] | S09.09 | **Failure-only fallback:** Failed/timed-out DDNS attempt becomes shared-watchdog pending work; reconcile native retries, honor recovery/auth/throttle gates and keep IP-Sync independent. |

### 10. IP-Sync

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S10.01 | **Independent account/list setup:** Suitable Zero Trust token/account, correct list API, provider-returned name/ID without normal manual ID entry. |
| [ ] | [ ] | S10.02 | **Ten-item display policy:** First ten stay selectable by number at any list count; exact-name search covers every eligible list. |
| [ ] | [ ] | S10.03 | **Literal exact-name input:** Case/space/numeric/quotes/e/Unicode ambiguity and correct one-time URL/JSON encoding without guessing. |
| [ ] | [ ] | S10.04 | **Complete lookup and draft retry:** Not-found only after complete lookup, immediate name retry, distinct auth/network/incomplete errors and preserved fields. |
| [ ] | [ ] | S10.05 | **Shared or separate lists:** Offer IPv4-only or detected usable IPv6 participation; shared list when supported or user-selected distinct family lists, same picker and no list/policy creation. |
| [ ] | [ ] | S10.06 | **Mapping migration:** Quiesce old requests, atomic local mapping and automatic primary/secondary cleanup with independent remote outcomes. |
| [ ] | [ ] | S10.07 | **Nonempty publication:** Exact current hosts and managed metadata, fresh read/readback, remove extra/wrong-family entries. |
| [ ] | [ ] | S10.08 | **Empty target clearing:** Same-ID supported item removal with exact returned spellings, complete verification and metadata reconciliation. |
| [ ] | [ ] | S10.09 | **Unknown/missing targets:** Shared unknown defers; known independent target proceeds; missing whole list requires reviewed repair. |
| [ ] | [ ] | S10.10 | **Explicit read-only check:** Configured-Off candidate GET/check allowed, no mutation/discovery/queue/success history/enable; cooldown/auth containment retained. |

### 11. Provider failures and credential repair

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S11.01 | **Private bounded transport:** Isolated curl/TLS/auth/redirect/header/body/aggregate limits and strict complete endpoint validation. |
| [ ] | [ ] | S11.02 | **Partial and transient outcomes:** Newest pending reconciliation, preserve On, no false success or credential loop from network errors. |
| [ ] | [ ] | S11.03 | **Provider throttle:** Evidenced shared scope, provider delay first, no-hint 5/10/20/30-minute backoff, bounded due dispatch and no worker bypass. |
| [ ] | [ ] | S11.04 | **Definitive auth-Off:** Only confirmed typed/scoped auth rejection permits fault-before-containment; repeated generic failures with healthy Internet are insufficient. |
| [ ] | [ ] | S11.05 | **Owned containment:** Close generations, bounded verified stop, stale requests/replies cannot reenable or erase newer faults. |
| [ ] | [ ] | S11.06 | **Credential and target scope:** Explicit compatible sharing; global versus operation/target fault isolation and management-only limits. |
| [ ] | [ ] | S11.07 | **Immediate and launch repair:** Setup/On first failure enters credential-only flow; Y/n launch/fx repair with no EOF/background consent. |
| [ ] | [ ] | S11.08 | **Preserved intent:** Cancel leaves fault/Off, later intentional Off wins, only still-requested repaired scope retries and archive intent stays advisory. |

### 12. Hooks, schedules and boot safety

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S12.01 | **Thin shared handlers:** Explicit module loading, same admission/controller/resolver, no menu/network/settle loop in foreign hook body. |
| [ ] | [ ] | S12.02 | **Exact hook ownership and repair:** Dedicated verified CFMgr blocks preserve foreign content; unsafe edits leave hooks unchanged, stop affected work with visible repair state, and use guarded repair/reinjection before eligible resume. |
| [ ] | [ ] | S12.03 | **Boot/WAN/IPv6 dispatch:** Saved eligible registration without mount wait, selected events and detached rechecked tunnel settle. |
| [ ] | [ ] | S12.04 | **DDNS/IP-Sync coexistence:** One completion owner; Access-only observation preserves foreign provider and needs no provider itself. |
| [ ] | [ ] | S12.05 | **Mount and shutdown:** Match expected volume, scoped resume and suppression-before-stop within firmware budget. |
| [ ] | [ ] | S12.06 | **Eligible schedules:** One global watchdog dispatches eligible tunnel/native/retry work; native DDNS days, binary updates and manager checks retain distinct schedules. |
| [ ] | [ ] | S12.07 | **No duplicate/foreign jobs:** Exact names plus commands/ownership; Scribe owns rotation, backups manual, Off removes only its scope. |
| [ ] | [ ] | S12.08 | **Bounded resource admission:** Coalesce before spawn/sleep, cap active/pending children/RAM/notices and aggregate work/cleanup. |
| [ ] | [ ] | S12.09 | **Real detachment:** Close inherited pipes/terminal/irrelevant descriptors; prove hook return while worker lives. |
| [ ] | [ ] | S12.10 | **Safe failure recovery:** No boot wait, infinite install/create/crash loop, reboot/global restart or teardown respawn. |
| [ ] | [ ] | S12.11 | **Shared watchdog and recovery:** All three features share NTP/reachability recovery with 1/2/4/5-minute capped due checks, isolated auth/throttle gates and transition logging. |

### 13. Logging and rotation

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S13.01 | **Three private logs/native notices:** Extended setup detail stays terminal-only; native notices reach the existing system messages log, eligible feature logs add a copy, daemon stream stays file-only, no global routes/manager logfile. |
| [ ] | [ ] | S13.02 | **First setup versus saved preference:** Only completed fresh ready setup initializes own logs; pending/maintenance-only/opt-out remain inactive. |
| [ ] | [ ] | S13.03 | **Readiness and independence:** Verified mounted Entware /opt/var/log paths and actual Scribe/base/schedule/include readiness, graceful no-file operation and service-Off rotation retention. |
| [ ] | [ ] | S13.04 | **Cloudflared tuning:** Per-file size/total-count including live file, shown Enter defaults and supported time/compression/age options; no aggregate-byte quota. |
| [ ] | [ ] | S13.05 | **Fixed native policies:** Separate versioned DDNS/IP-Sync defaults with no tuning UI or config override. |
| [ ] | [ ] | S13.06 | **Rotation correctness:** Numbered history/actual cadence, daemon reopen or stated copytruncate limit, safe native append and snapshot coordination. |
| [ ] | [ ] | S13.07 | **Fast scoped repair:** Cheap requested-feature checks, bounded owned fragment/include repair and full explicit validation without base/global changes. |
| [ ] | [ ] | S13.08 | **Install/policy transaction:** Owned /opt/etc/logrotate.d fragments, direct no-rotation validation and coherent config/rule rollback; automatic next-run discovery without Scribe reload/restart or forced rotation. |
| [ ] | [ ] | S13.09 | **Logging uninstall:** Durable opt-out before writer quiescence/deletion; missing Scribe allowed, storage failure deferred and no false removal. |
| [ ] | [ ] | S13.10 | **Resume without file output:** Release runtime guard after safe quiescence/opt-out, retain residual cleanup, resume only still-On/no-file work. |
| [ ] | [ ] | S13.11 | **Optional external viewing:** Supported bounded owned-path registry only if selected; no fake routing/private patches or CFMgr WebUI requirement. |
| [ ] | [ ] | S13.12 | **Explicit all-service re-detect:** Ready Scribe enables logging for every configured On service, overriding prior logging Off only for this explicit action; reuse policies or initialize defaults. |
| [ ] | [ ] | S13.13 | **Prominent concise event format:** Single-line [CFMGR] component: Info/Warning/Error messages with matching syslog severity, verified outcomes/IPs, actionable failures/repair notices, eligible feature-file plus syslog delivery and duplicate suppression. |

### 14. Backup and restore

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S14.01 | **Manual CFMgr-only archives:** Native unencrypted data-only tar.gz, privacy notice/best-effort modes, no router/add-on/code backup or schedule. |
| [ ] | [ ] | S14.02 | **Mounted-drive picker:** Explicit numbered exact mount identity including one drive, root CFBackup, no stale/fallback destination. |
| [ ] | [ ] | S14.03 | **Archive selection/actions:** Numbered newest list, inspect/verify/review restore and confirmed deletion; alternate source does not reset destination. |
| [ ] | [ ] | S14.04 | **Local date naming:** Regional date choice, same-day time suffix/collision refusal and manifest chronology across format/DST changes. |
| [ ] | [ ] | S14.05 | **Verified-new-first retention:** Keep 3–5 same-set completed archives; prune only after verified commit and report purge failure separately. |
| [ ] | [ ] | S14.06 | **Coherent data allowlist:** Config/catalog/typed authority/drafts/full YAML/JSON/both cert copies/.bak/preferences/eligible history; no live controls/executables. |
| [ ] | [ ] | S14.07 | **Required versus optional payload:** Required authority/YAML cannot be omitted; external dependencies inventoried, optional cert/binary absence handled honestly. |
| [ ] | [ ] | S14.08 | **Backup transaction:** Consistent bounded source/rotation locks, private same-filesystem archive, hashes/mount recheck/atomic commit. |
| [ ] | [ ] | S14.09 | **Safe current-code restore:** Exact input/schema/hash/path/type/size validation, supported migration and current components, no archive code/downgrade. |
| [ ] | [ ] | S14.10 | **State-aware reconstruction:** Never-configured/draft/maintenance/On/Off rules, independent logging preference and explicitly deferred optional history. |
| [ ] | [ ] | S14.11 | **Guarded restore/recovery:** Fresh local ownership/generation, current auth/source admission, local rollback distinct from new auth-Off and no stale replay. |

### 15. Uninstall, retained installation and reset

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S15.01 | **Reviewed legacy migration:** Recognized data/ownership only, private staged settings and one-controller recovery without foreign adoption. |
| [ ] | [ ] | S15.02 | **Explicit removal choices:** Full uninstall KEEP default versus confirmed WIPE, separate confirmed reset and guard-before-stop/delete. |
| [ ] | [ ] | S15.03 | **Common owned cleanup:** Detach own integration/jobs, stop owned work, remove runtime/log components and preserve foreign/manual/remote data. |
| [ ] | [ ] | S15.04 | **KEEP:** Retain full primary YAML/JSON/cert/JFFS authority/cert/.bak/catalog/preferences/drafts/intent behind retained-install guard. |
| [ ] | [ ] | S15.05 | **WIPE:** After safe cleanup remove all owned data plus exact canonical manager directory/entry, refusing substituted/foreign roots. |
| [ ] | [ ] | S15.06 | **Passive reset:** Keep verified package, finish owned cleanup then regenerate passive defaults with update-check On/auto Off. |
| [ ] | [ ] | S15.07 | **Retained reconstruction:** Detect before defaults, validate/reuse same files, current-code rebuild without wizard/login/create and preserve Off. |
| [ ] | [ ] | S15.08 | **Incomplete cleanup/recovery:** Missing/lost/read-only storage or uncertain ownership retains recovery entry/guard and honest pending state. |
| [ ] | [ ] | S15.09 | **Cloudflared-only full reset:** Confirmed full removal of owned local tunnel setup/runtime/logging, preserving manager, DDNS/IP-Sync, shared credentials still in use, backups and remote resources. |

### 16. Product readiness and documentation

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S16.01 | **Usable integrated product:** Required workflows and acceptance work through actual user entry paths within declared support. |
| [ ] | [ ] | S16.02 | **Evidence and limitations:** Source/host/BusyBox/kernel/live classes separate; no ready claim for missing required proof, IPv6 provisional explicit. |
| [ ] | [ ] | S16.03 | **Complete practical guides:** Keep interim developer notes small until most goals are met; complete architecture/developer and install/setup/credentials/operation/update/recovery/logging/archive/removal guides before product readiness. |
| [ ] | [ ] | S16.04 | **Cloudflare prerequisites:** Account/domain/DNS and policy wiring guidance in docs, no extra runtime prompts or private-network restriction. |
| [ ] | [ ] | S16.05 | **Safe reproducible delivery:** Sanitized examples/screenshots and validated real installer command/failure behavior. |
| [ ] | [ ] | S16.06 | **Release readiness:** Coherent first version/beta semantics and required functionality/documentation before optional final polish. |


### Planned documentation coverage for S16.03

Keep interim developer notes small until most/all implementation goals are met.
The following final-guide obligations mirror specification section 16; existing
README and temporary developer notes do not complete them. These checks belong
to S16.03 and do not change the 16-goal denominator. Final review checks actual
commands/failure guidance, scope/compatibility, sanitized examples and links
against accepted runtime/tests. Reassess grouping only while preserving coverage.

| Ready | Planned document | Required coverage | Product goals |
| --- | --- | --- | --- |
| [ ] | `README.md` | Product overview, intended versus implemented main goals, readiness and guide navigation. | All goals |
| [ ] | `docs/setup.md` | Verified installation/prerequisites, first launch, private defaults and independent DDNS, Cloudflared and IP-Sync setup. | 1–3, 5, 9–10 |
| [ ] | `docs/credentials.md` | Cloudflare account/domain/DNS prerequisites, minimum scoped permissions, token/JSON/certificate choices, policy wiring and safe credential handling. | 5, 9–11, 16 |
| [ ] | `docs/operation.md` | Menus and commands, Save/On/Off, dashboard/health, address evidence and normal DDNS/tunnel/IP-Sync operation. | 3–6, 8–10 |
| [ ] | `docs/maintenance.md` | Manager updates/reinstall and source/developer selection, Cloudflared binary maintenance and separate selected Entware repair/reinstall. | 2, 6–7 |
| [ ] | `docs/recovery.md` | Failed setup/save/update, missing storage/dependencies, outages, credential faults, damaged hook blocks, rollback and interrupted-operation recovery. | 2–4, 7–8, 11–12, 15 |
| [ ] | `docs/logging.md` | Native system messages, per-feature Scribe logging, /opt/var/log storage, owned logrotate policy, re-detection and truthful failure handling. | 12–13 |
| [ ] | `docs/backup-and-removal.md` | Manual archives, validated restore/migration, backup storage/retention, KEEP/WIPE uninstall, retained installation and scoped resets. | 14–15 |
| [ ] | `docs/compatibility.md` | Declared firmware/native-tool/ABI support, required capabilities, source/host/BusyBox/kernel/live evidence and provisional limitations. | 2, 8, 16 |
| [ ] | `docs/architecture.md` | Actual entry/module/shared-library interfaces, storage/state authority, ownership/locks, transactions, worker/lifecycle/resolver/provider flows and integration boundaries. | 1–15 |
| [ ] | `docs/development.md` | Reproducible environment, source references, focused/full/platform testing, fixtures and cost controls, CI/tools, package generation and release/beta workflow. | All goals, especially 2, 7, 16 |
| [ ] | `CONTRIBUTING.md` | Concise change/review workflow, scope/checklist discipline, validation/privacy rules and links to development/architecture guidance. | 16 |

## Open product decisions

See specification section 17. These remain unresolved until their owning workflow has a supported concrete decision.

| Status | Decision area |
| --- | --- |
| [ ] | **Configuration/transactions:** Exact bounded schema/ref/generation/guard formats; reliable write/flush/rename and failure reporting; supported native JSON/certificate/YAML subset; scoped merge and cross-filesystem recovery. |
| [ ] | **Package distribution:** Source-to-installed path mapping, bootstrap manifest trust, complete generation activation/reader retention, developer-only config source grammar/shared-default reset, snapshot catalog grammar, supported historical snapshots and development-commit comparison; beta version grammar before first release. |
| [ ] | **Supported platforms:** Actual native paths/options/CA, minimal kernel/userspace ABI/capability profiles and official binary compatibility; no unsupported legacy promise based solely on feed names. |
| [ ] | **Storage/processes:** Persistent/attached volume identity, mount-race handling, approved path whitelist, lock order/descriptor lifetime, child identity/quiescence and uninterruptible-I/O limitation. |
| [ ] | **Budgets/readiness:** Aggregate hook/DDNS/worker/response/staging/queue bounds; monotonic clocks, NTP/transport/egress evidence, reconnect grace/stability criteria, common outage retry fixed at 1/2/4/5 minutes (300-second cap); verify scoped provider-delay parsing and separate no-hint throttle 5/10/20/30-minute state. |
| [ ] | **Firmware DDNS:** DDNS soft timer inside matched whole-action ceiling, overlap without request IDs and native retry collision; default 14-day field/bounds/apply/persistence/certificate side effects and ownership relinquishment. |
| [ ] | **Native discovery:** Selected WAN/protocol/interface mapping, complete absence evidence, routed IPv4/IPv6 observations/lifetimes and scoped support for less-common firmware modes. |
| [ ] | **Provider operations:** Permissions, pagination/completeness, exact managed fields, same-ID empty-list removal, actual mixed-family-list capability, user-selected shared/split migration and target-vs-feature fault schema; no extra feature inferred from uncertain API behavior. |
| [ ] | **Cloudflared:** Token-file floor/default-config isolation, A2 create/token endpoint permissions and failure handling, B route-discovery completeness/lossless mapping edits, login/certificate provenance/manual fallback, same-UUID fetch and runtime auth/connectivity classifier; no implicit binary auto-update default where not selected. |
| [ ] | **Scheduling:** Exact manager daily cron time/registration/removal; shared minute dispatcher, five-minute native discovery and per-scope due-state reconciliation with native DDNS retries. |
| [ ] | **Logging:** Actual Scribe/include/schedule state, daemon reopen/copytruncate, rotation concurrency; proposed Cloudflared 10M/five-total-files/compression and native 1M/two-total-files defaults, safe count-one reuse and launch budgets. |
| [ ] | **Backup:** Stock tar/gzip behavior/input bounds, regional date evidence, proposed default keep 5, archive chronology/set identity, consistent eligible log snapshot and required external YAML dependencies. |

## Acceptance cases

IDs identify behavior, **not a required test count**. One meaningful test may cover several cases; expensive scenario matrices need representative integrations plus focused distinct failures. Existing tests carrying an ID still need review against this specification. Mark acceptance only with actual evidence and note host/CI/source/live limits; optional unrun live IPv6 remains explicitly provisional.

### Installation, storage, dependencies and shared control

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V01 | absent/read-only/wrong/lost Entware blocks dependent operation without stale writes or resetting intent; native diagnostic/recovery/Off remains available; optional logging failure alone does not block otherwise-ready APIs. |
| [ ] | V02 | supported native/Entware command, parser and ABI capabilities succeed; unsupported/missing requirements fail before activation; no router Python/venv/picker dependency. |
| [ ] | V03 | overlapping boot/WAN/watchdog/manual starts admit one owned connector and leave firmware/foreign hooks responsive. |
| [ ] | V04 | all three features use shared NTP plus independent family-aware reachability after failure; IPv6 transport is not blocked by IPv4-only probes; readiness precedes ordinary tunnel stop/restart, outage checks follow 1/2/4/5-minute capped due state, and longer provider cooldown still wins. |
| [ ] | V09 | repeated install/repair/hook-code update converges exact owned hooks/jobs; dedicated paired CFMGR BEGIN/END blocks with stable IDs and DO NOT EDIT labels replace only recognized current/older owned bodies, preserve unrelated bytes/control flow/arguments/mode and concurrent edits, and pass whole-hook syntax. Only explicit DDNS Save/Enable may replace a foreign provider without displaced-provider backup; its generated handler is marked for later maintenance. |
| [ ] | V10 | dedicated setup/migration affects only chosen feature/shared accepted fields and required dependencies; bad/scoped credentials do not damage siblings. |
| [ ] | V25 | fresh installation is passive; live manager update/reinstall preserves healthy feature state; legacy services stay unchanged until reviewed migration. |
| [ ] | V26 | exact numeric/text menu keys, B y/n/Enter, Back/Exit, unsupported input and scoped settings dispatch correctly without accidental actions. |
| [ ] | V38 | e/Ctrl+C/EOF/signals/power loss preserve completed native drafts and prior active state; Cloudflared commit-time e is refused, interruption is guarded and no uncertain create repeats. |
| [ ] | V39 | corrupt authority/user YAML/journal is preserved/quarantined; valid derived drift repairs the same identity; missing optional certificate or mount does not fabricate corruption/login/activation. |
| [ ] | V40 | On/Off/repair, feature removal and full uninstall identify exact owned segments before editing; preserve foreign content and shared native work; duplicate/nested/mismatched/truncated markers, unknown modified bodies or uncertain signature boundaries leave the hook unchanged with visible repair required. Stop/block only affected owned work, retain guards against stale hooks/watchdog admission, preserve saved intent and never manufacture manual-Off remote cleanup. Dedicated launch/advanced repair handles cancellation/EOF safely; after manual removal, next launch may reinsert a verified block and resume only current eligible intent. Legacy adoption needs an exact known signature and trusted complete range; whole-file deletion needs exclusive generated-file ownership. Repeated update/removal is safe and idempotent. |
| [ ] | V41 | boot with delayed/absent Entware registers saved eligible dispatchers; handlers defer their required scope, ignore unrelated mounts and use capped/resettable due state without blocking boot. |
| [ ] | V42 | isolated shell/native tool/CA/loader paths, strict bounded data/transport and volatile queue/status work under shared prerequisites; poisoned/unavailable tools fail safely. |
| [ ] | V48 | quick case-insensitive service start/stop and ipsync alias share menu handlers, reject incomplete/unconfigured/corrupt or extra arguments, preserve unrelated activation and report real outcomes. |
| [ ] | V59 | worker/child death, inherited descriptors, stale lock paths, PID reuse and foreign processes cannot defeat writer exclusion or cause unsafe kills; detached connector holds no controller lock. |
| [ ] | V63 | scoped wizard Save supersedes same-field manual edits while preserving unrelated state/guards; no-revision content changes and later Off win; write/guard/package-generation failures are contained honestly. |
| [ ] | V64 | event storms, aggregate budgets, delayed work, unmount/watchdog races, missing TTY/EOF/signals and terminal echo remain bounded and safe. |
| [ ] | V73 | all-feature boot/outage/fault injection proves early hook return, pipe closure, resource admission, no premature work, crash backoff/stability reset, teardown suppression and no reboot/global-restart recovery; hardware proof remains separate. |
| [ ] | V74 | normal installed-opkg missing/unusable dependency repair and selected force reinstall preserve healthy tools/config/intent, coalesce attempts, recheck capabilities and remain bounded on mount/network/interruption failures; no custom IPK bootstrap or blanket upgrade. |
| [ ] | V75 | health/doctor/diagnostic are identical full reports and survive partial installation/missing modules/tools/broken config with native fallback; include basic dashboard plus grouped causes/next actions; eligible locally valid, non-faulted credentials permit bounded read-only checks, otherwise local fallback; no mutations/auth-Off/cache-success writes or false live/write-permission proof; safe narrow/plain terminal output and no secrets. |

### Tunnel setup, credentials, maintenance and updates

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V05 | binary metadata/digest/download/ABI/version/backup/stop failures preserve old usable artifact/runtime and report bounded failure. |
| [ ] | V06 | interruption around binary/manager activation preserves a complete trusted generation, pending identity and protected recovery. |
| [ ] | V11 | B import validates one full YAML/JSON/certificate identity, captures typed master/provenance and preserves user content; A never requires inactive B files. |
| [ ] | V18 | public Stop clears tunnel+maintenance activation and its operational eligibility/integration while preserving other shared-watchdog consumers; external kill retains On for gated watchdog; Restart cannot enable Off; missing-binary Start uses checked recovery. |
| [ ] | V31 | check/auto defaults and coupling, launch/daily coalescing, valid-known/new update y/n offer once on opening, decline-to-menu/no redraw nag, explicit u recheck/offer, developer suppression, manual check while checks Off, stale/offline/unknown evidence, exact source pins and queued opt-out/owner contention behave as specified. |
| [ ] | V32 | manual/force/automatic manager updates verify every trusted package file/version/schema before execution, preserve complete recovery on all distinct switch faults and leave healthy features/config intact. Failed required hook reinjection keeps package and integration outcomes distinct, reports incomplete update, contains affected work and enters dedicated repair without claiming success or restarting unrelated healthy services. |
| [ ] | V34 | A1 existing-token-only with optional guide; A2 separately typed management authority, reviewed dashboard-managed creation and private connector-token handoff/fallback; B placement/re-scan/import; n/Enter fresh setup; published-app/private-network-only validation; no incomplete setup/logging activation. |
| [ ] | V35 | A/B switches validate before one controlled replacement, preserve inactive material/Off/full user routing and recover failures without overlapping connectors or implicit mode fallback. |
| [ ] | V36 | explicit A/B/maintenance force-install, independent idle update and maintenance uninstall follow installed/configured/activation state table; no foreign/shared binary deletion or false stop/removal success. |
| [ ] | V37 | fresh B login/create and A2 API creation handle applicable account/credential/name/write/permission failures, lost/partial results and cancellation without pre-Save creation, blind retry, mode confusion or remote cleanup claims. |
| [ ] | V45 | official origin/tag/exact asset SHA-256, numeric version and ELF ABI validation precede mutation; fixed lookup/legacy path limits reject wrappers/symlink/read-only/foreign ownership. |
| [ ] | V46 | developer suppresses checks/offers/auto/external callbacks; one code-defined repository/branch pair supplies fresh install and normal checks/update/reinstall/module fetches, with no copied defaults or independent catalog source URLs. Changing only the central branch value from develop to main changes every normal consumer coherently. Developer=false ignores configured repository/branch/pin; successful authorized replacement resets all source fields to the shared defaults and clears the pin, while checks/status and failure/cancel preserve config. Developer=true uses and retains validated configured repository/branch/full commit through confirmed force. All fetched files and the replaced catalog use one selected repository/pinned snapshot; compatible older developer snapshots use the exact complete tree without history gap-filling; data restore never executes archive code. |
| [ ] | V54 | exact master-derived JSON and lossless YAML trio repair, original certificate provenance/copies and full-YAML/.bak preservation produce only one eligible real-change restart; no file copy treated as auth renewal. |
| [ ] | V55 | NEW create outcome/JSON/JFFS/mount loss distinguishes confirmed same-ID local recovery from unknown result requiring manual dashboard cleanup; returning mount never recreates. |
| [ ] | V56 | same-UUID existing-credential fetch/login/import is attempted appropriately; no unchanged-secret loop; only conclusive failure offers default-no replacement preserving full YAML/.bak, with manual old-tunnel deletion. |
| [ ] | V57 | matching retained runtime is a true no-op across u/uf/start/reinstall; owned drift only is repaired; corrupt master/user YAML preserved; KEEP/restore certificate provenance and WIPE boundaries remain correct. |
| [ ] | V60 | Cloudflared binary numeric no-downgrade/force rules and artifact transaction recovery work independently for idle and On cases; Off races win, outage does not falsely condemn candidate, successful rollback still reports failed update. |
| [ ] | V76 | B discovery identifies only selected-tunnel hostnames; reviewed multi-mapping Save validates DNS/origin/YAML, preserves manual options/catch-all, rejects foreign conflicts and tracks local/remote partial outcomes without duplicate creation or unrequested route writes/restarts. |

### Native families, provider reconciliation and repair

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V07 | IPv4/dual-stack/provisional IPv6-only DDNS uses reviewed default 14-day native refresh and its own short completion timer; failure/timeout coalesces into the shared watchdog, native retries cannot bypass gates or duplicate callbacks, no extra daily forced job; updates/deletion/recreation/partial/unknown outcomes stay truthful and IP-Sync independent. |
| [ ] | V08 | manual Off persists scoped cleanup, clears configured list contents/managed A-AAAA while keeping list identities/setup, and reports offline/throttled/auth-blocked cleanup pending; reboot/re-enable/config changes and stale writes cannot replay unauthorized cleanup. Fresh equality/drift/shared/split/empty targets reconcile correctly. |
| [ ] | V44 | IPv4 public/private/shared/mismatch/WAN/VPN/expired evidence uses correctly routed current public observations; failure is unknown and standalone IP-Sync does not require DDNS. |
| [ ] | V50 | unchanged local IP cannot bypass fresh complete remote comparison; managed drift/removal and partial results invalidate affected state; equality differs from new publication. |
| [ ] | V51 | provider throttle uses evidenced shared scope/newest work; valid server delay wins even beyond local caps, no-hint retries follow 5/10/20/30 minutes and reset only on scoped provider success, overlap cannot multiply/bypass state; preserve On/maintenance/jobs, no token prompt or fresh-create retry. |
| [ ] | V52 | only definitive typed/scoped auth/permission evidence triggers durable fault-before-Off; generic errors/PID/metrics/throttle/GitHub faults and repeated failures despite healthy Internet do not; auth-Off never creates remote cleanup; existing explicit-Off intent stays blocked pending repair, and shared/target scope is safe. |
| [ ] | V53 | first definitive auth failure during interactive setup/On and later launch/fx enter credential-only repair; compatible shared references are handled serially, intentional Off/unrelated settings preserved, repaired manual-Off cleanup resumes only cleanup, EOF consent refused and archived repair intent never promoted. |
| [ ] | V58 | native port removes all Python call paths, retains complete source parity and private queue/metadata behavior; explicit configured-Off target check remains provider-read-only with no publication/cache/history/enable/discovery side effects. |
| [ ] | V61 | hostile curlrc/environment/redirects, response overflow/truncation, endpoint pagination/type errors, callback overlap and cooldown cannot leak auth or authorize incomplete DNS create/delete/success. |
| [ ] | V62 | next eligible run corrects remote address/extra-item/name/managed-field drift and recreates only missing configured DNS definitions; missing whole list/tunnel identity requires reviewed repair. |
| [ ] | V66 | family disable/return/both-inactive/unknown/lifetime/source change invalidates old add/remove replies; independent known scope proceeds and shared unknown replacement defers. |
| [ ] | V67 | external edit races, shared/split nonempty replacement, empty clear and partial readback converge boundedly without manual-content conflict mode or claims of permanent remote atomicity. |
| [ ] | V68 | IPv6 host selection/canonicalization/lifetimes/source/provider transport remain independent of IPv4; verified selected-WAN translation uses the public external host and reports local mismatch, never publishes ULA or infers usable IPv6 from NAT64/prefix alone; unknown stays unknown and live coverage is not invented. |
| [ ] | V69 | usable public IPv6 gates fresh IPv6 setup offers; IPv4-only remains valid; verified mixed-family shared or user-selected separate lists, cancel, both mapping migrations, stale workers/reboot and inactive-target cleanup preserve IDs with independent outcomes and no policy edits. |
| [ ] | V70 | zero/one/ten/eleven-plus list discovery, numbered first-ten selection at any count, beyond-preview name lookup, numeric/exact/duplicate/case/quote/space/Unicode names and incomplete enumeration are handled without identity guessing or incorrect encoding. |
| [ ] | V71 | native draft resume and repeated exact-name not-found loop retain completed fields, distinguish auth/network errors, handle literal quoted e/numbers and never modify active/shared credentials before final Save. |
| [ ] | V72 | empty-list same-ID value removal, metadata-only drift, inactive DNS removal, returning-family recreation and lost responses verify current state without duplicate POST or false offline cleanup success. |

### Logging, backups, restore and removal

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V12 | first fresh ready-Scribe setup initializes only selected feature policy; absent base/pending tunnel/maintenance-only/restore/opt-out follow distinct activation rules. |
| [ ] | V13 | real rotation/reopen or documented copytruncate and concurrent native appends preserve owned policy/history without duplicate stanzas, abandoned open log or new rotation cron; total count includes live file, count 1 safely clears/reuses it, count 3 retains at most two histories, size/count prompts show defaults, and Scribe-check overshoot is reported honestly. |
| [ ] | V14 | coherent data-only CFMgr backups include required full tunnel/credential/certificate/.bak/draft/preference/history data and exclude code/runtime control/foreign/router/displaced-DDNS data; damaged commit and missing required data fail honestly. |
| [ ] | V15 | native mounted-drive/archive picker handles one/no/multiple drives, exact identity, spaces, duplicate labels, invalid/e/Ctrl+C without unintended destination/archive change. |
| [ ] | V16 | same/compatible replacement-router restore validates exact archive bytes, schema/hash/modes/path/size/link safety before writes and remaps storage transactionally. |
| [ ] | V17 | local restore failure rolls back/quarantines; fresh auth rejection/throttle is retained correctly without faulty-On rollback, source-fault replay or remote identity recreation. |
| [ ] | V19 | never-configured/draft/maintenance/On/Off restore rebuilds only eligible current-code components, preserves operational Off and separately requested history rotation. |
| [ ] | V20 | backup drive independent of Entware, removed/substituted destination, optional destination setup and internal recovery cannot cause stale writes, automatic archives or unrelated pruning. |
| [ ] | V21 | fast passive check/automatic repair preserves logging opt-out; explicit all-service Re-detect overrides it only for configured On services with ready Scribe, repairs saved policy or initializes defaults, respects concurrent Off and handles unavailable base/partial repair without enabling services or forcing provider updates. |
| [ ] | V22 | Cloudflared per-file size/total count (including live)/time/compression/age options produce supported effective numbered rules; invalid changes preserve policy and display actual Scribe cadence, not hard-cap claims. |
| [ ] | V23 | 3–5 retention verifies new before pruning, reports purge failures, preserves old backups on failure and handles regional format/timezone/DST/same-second collisions using manifest chronology. |
| [ ] | V24 | independent feature logging opt-in/opt-out/service Off/ready-unready transitions preserve native notices/provider completion and independent Scribe rotation. |
| [ ] | V27 | basic status is a bounded local-only dashboard with router/resources, distinct WAN/CGNAT/public-family observations and ages, per-feature activation/current issues and last verified IPv4/IPv6 outcomes; no provider probes, hidden Off faults, setup-reset of quarantined state or live health inferred from restored history; missing optional fields/logging do not break rendering. |
| [ ] | V28 | fixed DDNS/IP-Sync policies have no Cloudflared dependency or tuning UI; writer/policy-version/rotation failures preserve provider outcome and other rules/preferences. All three owned feature files/history use verified mounted /opt/var/log directly; absent/lost/substituted storage and foreign same-name files never receive fallback writes or adoption. Owned regular /opt/etc/logrotate.d fragments are admitted by the actual top-level include, filename/permission rules and duplicate checks, then discovered on the next existing Scribe rotation run without reload/restart/HUP/forced rotation or extra cron. Direct bounded logrotate debug validation changes no logs/state and runs no rotation scripts; Scribe status/debug wrappers are not read-only substitutes. Missing global include remains a reported base fault; staged/recovery rules stay outside the include and failed/concurrent policy changes preserve the previous valid owned policy. |
| [ ] | V29 | extended setup terminal output explains local/public/CGNAT/translation and true outcomes; CFMgr events use one prominent [CFMGR] component: Info/Warning/Error line with matching syslog priority, verified IP/version successes, rate-limit/auth warnings and actionable hard errors; polling/duplicate noise and unsafe text are suppressed without hiding new failures. Hook repair faults identify affected work, actual stopped/blocked/uncertain state and safe repair action, remain visible on launch and emit one verified recovery event. Recovery/maintenance/feature repair use eligible configured Scribe feature files plus syslog, otherwise syslog only; verify the native logger command uses the normal local system route and delivers to the active system messages destination (normally /opt/var/log/messages with Scribe, firmware /tmp/syslog.log/configured alias otherwise), including severity/filter admission and no double append to aliases; logger success alone is insufficient and unavailable routing is reported honestly; native daemon stream stays file-only and manager updates syslog-only; absent Scribe/opt-out never produces unmanaged files, verbose transcripts or secrets. |
| [ ] | V47 | KEEP/WIPE/reset/retained install and Cloudflared-only full local reset handle confirmation, intent, interruption and storage failure; tunnel-only reset removes its owned setup/runtime/logging while preserving other features/shared references/remote resources; full WIPE alone removes the exact manager directory; preserve foreign/manual data. |
| [ ] | V49 | logging uninstall guards opt-out before writer stop/deletion, works without Scribe, defers unsafe storage/stop cleanup and releases runtime guard after safe quiescence so eligible no-file operation can continue. |
| [ ] | V65 | archive bombs/swaps/duplicates/extended paths/unsafe types and extra YAML dependencies stay bounded/allowlisted; missing foreign dependencies are reported rather than falsely claiming portable complete backup. |

### Documentation and optional integrations

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V43 | reproducible isolated developer environment, efficient focused/full workflows, required BusyBox evidence, runtime package exclusions and accurate sanitized linked usage guides. |
| [ ] | V30 — Conditional only | if external uiScribe support is separately selected, verify owned paths/permissions, bounded viewing/clear/rotate and reinstall durability without requiring a CFMgr WebUI. |
| [ ] | V33 — Optional launcher / conditional updater | supported user-chosen amtm personal slot preserves occupied slots and preferences; any later official callback requires explicit separate opt-in/developer gating and the trusted transaction. |

## Ready-to-use product

| Status | Required result |
| --- | --- |
| [ ] | All required workflows/subgoals and release-blocking acceptance are satisfied within the declared support scope. |
| [ ] | Cross-feature behavior, storage/boot/update/restore recovery, ownership and credentials have adequate evidence with actual limitations stated. |
| [ ] | Practical installation, operation, repair and removal guides are accurate and usable. |
| [ ] | The completion assessment reflects delivered requirements; optional future WebUI/external integrations and post-completion polish are excluded. |
| [ ] | Required hardware/provider acceptance is explicitly evidenced; first-version and beta semantics are coherent. |
