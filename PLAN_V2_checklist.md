# CFMgr v2 — project checklist

[Product specification](PLAN_V2.md) · [Audit record](PLAN_V2_audit.md) · [Review notes](PLAN_V2_review_notes.md) · [Current handoff](PLAN_V2_handoff.md) · [Working rules](AGENTS.md)

This checklist owns product acceptance and delivery status. The specification owns
required behavior; the handoff owns current work and pending evidence; AGENTS.md
owns execution and publication rules. Administrative preparation/cleanup does not
earn product ticks.

## Completion assessment

**0 of 16 main goals complete — 0% product completion.**

**25 of 157 product subgoals accepted — 15.9% overall subgoal completion.**

**Subgoal gate:** complete implementation, written focused local tests, relevant
static checks, parent review and required core CI passing at the exact published
candidate revision. Dev Checks supplies focused diagnosis and interim evidence.
Core execution starts with one group per actual main module, with supporting
library tests underneath, complete assigned host/native coverage and a required
aggregate at the same SHA. Groups expand with main modules. Every required group
must pass within approximately ten minutes, preferably sooner; split a main-module
group only after it exceeds that limit, to diagnose and reduce the slow part.
After focused repairs, rerun the diagnostic batches within approximately two to
three minutes each, then rerun the complete main-module group within its budget.
This changes test organization and cost control, not product requirements.
**Main-goal gate:** every required subgoal, accumulated codebase/scope audit, full
local suite and exact full core CI at the complete main-goal checkpoint. Full
local suites remain reserved for that boundary; core CI runs for code, tests,
tooling and Actions changes on develop pushes and PRs targeting develop; documentation-only changes
do not trigger CI. Tools Checks, Lint Checks and Diagnostics Checks are optional
and manual-only; changed optional code/tests still require their affected checks
under the [practical test policy](AGENTS.md#practical-test-policy). Full core CI runs
last at the checkpoint after all applicable focused local/Dev groups pass;
local platform skips still require CI proof. Automatically pause after each
agreed major checkpoint (the approved task/subgoal block) under the standing
[validation rules](AGENTS.md#validation-and-publication-gates).
Publication rules: [AGENTS.md](AGENTS.md); the current user-approved CI decision
is recorded in [the handoff](PLAN_V2_handoff.md).

**Development platform gate:** representative Ubuntu integration and native-host
vendor BusyBox execution. Exact firmware/ARM/kernel-VM execution is not a required
development gate. Merlin/flash/hooks/TLS/provider qualification remains deferred
to separately authorized real-router beta; support stays provisional.

## Main-goal completion gates

Each product subgoal below has separate **focused local** evidence and **final
status**. Focused evidence means the relevant written tests passed, not merely
syntax or smoke checks. Final subgoal status also requires any specific platform
proof; unavailable BusyBox evidence remains pending until required core CI passes
at the exact published candidate revision, including shared foundations across
goals. Small diagnostic selections alone earn no tick.

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

| Accepted subgoal | Verified consumer and behavior |
| --- | --- |
| S02.03 | `cfmgr.sh --install` → bootstrap → config generator: private extensionless fresh-only defaults, modes/bytes, retained/repeated/corrupt/incomplete refusal and interrupted publication. Trusted-local package only. |
| S03.01 | Same installed-config consumer: complete passive feature/tunnel/logging/backup/manager defaults checked by `test_config.py`; private publication, empty Entware destination and refusal cases checked by `test_install.py`. No feature/provider/hook/logging/backup setup during installation. |

Tested code: `7ce3cad771a7cedb0e2f17e69082f9659655c5c5`,
[Checks 38200865754](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38200865754).
Single Ubuntu job: planning/static gates passed; host **163 passed, 4 platform
skips**; vendor BusyBox **166 passed, 1 workstation-without-proc skip**. Required
native fsync, process/FD supervision and cleanup cases ran. Parent review passed.

Focused defaults/install proof on `bc49cf54831e8b7099aad3aee9ba8e75fbcae137`
with handoff-only edits and unchanged tested runtime:
`.venv/bin/python tools/test.py --focused tests -k 'test_config or test_install'`
— **24 passed, 1 Linux-only skip**, 26.62s; all static/planning gates passed.
The skipped owned-copy signal/FD case is covered by the exact Ubuntu CI above.

Evidence boundary: representative component/transaction execution with labelled
attachment/supervision adapters plus real Linux process/FD cases. Exact root/JFFS2
installation and Merlin/ARM/flash qualification remain optional guest/live proof.
These ticks establish passive fresh installation, not remote acquisition,
dependency repair, feature workflows or update scheduling. No main-goal audit or
full local gate is accepted.

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
| [x] | [x] | S02.01 | **Modular distribution:** One verified package with extensible feature modules, shared libraries grouped by reused responsibility and thin entry/hooks. |
| [ ] | [ ] | S02.02 | **Private storage layout:** JFFS authority/recovery, RAM frequent state, verified Entware tunnel/log data, independent backup mount. |
| [x] | [x] | S02.03 | **Generated defaults:** Private extensionless config generated only for genuinely fresh setup; no shipped config/template. |
| [x] | [x] | S02.04 | **Shared operational prerequisites:** Verified jq, timeout and SHA-256; native-first flock and tunnel-only DNS additions. |
| [x] | [x] | S02.05 | **Normal dependency repair:** Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| [x] | [x] | S02.06 | **Selected dependency reinstall:** Explicit force action for mapped requirements, separate from tunnel maintenance and configuration. |
| [ ] | [ ] | S02.07 | **Native recovery access:** Status/doctor/recovery/safe Off remain usable without operational Entware tools. |
| [x] | [x] | S02.08 | **Storage identity and loss:** Resolve current `/opt`, verify its backing mount and required-data reads, revalidate saved observations, guard CFMgr write paths, pin each action and stop/report owned work on loss. |
| [x] | [x] | S02.09 | **Capability-based support:** Target the GT-AX11000 baseline and modern Merlin models with supported Entware and usable required dependencies; record source/ABI profiles and enforce native capability/TLS checks, with model qualification deferred to real-router beta. |

S02.01/S02.03 mapping acceptance: root entry goes only to `/jffs/scripts/cfmgr.sh`;
`modules/` paths remain nested beneath `/jffs/addons/CFMgr.d/`, alongside the
snapshot's root catalog and manifest. No package config/setup-guard payload is
accepted. Trusted-local fresh installation and its generated private defaults
are distinct from the accepted S07.08 remote acquisition proof and unfinished
update-source consumers.

S02.01 consolidation requirement: backup capture, format, parsers, history,
transaction and menu functions share one backup module; shared configuration
functions/parsers share one config library. DDNS, networking and other major
responsibilities follow the same owner-first rule. A function or implementation
stage does not justify another file. The user-requested correction preserves
existing scope, interfaces and safety gates; its current refactor proof is
recorded in the [consolidation audit](PLAN_V2_audit.md#s0201-s1401-s1404s1408-module-fragmentation-correction).

| Scope | Focused local/static evidence | Required CI gate | Subgoal acceptance |
| --- | --- | --- | --- |
| S02.01 verified modular distribution | Final complete entry/reinstall, settings/backup and status/retained groups: **151 passed, 5 Linux skips**, each group under 90s. Package/install: **33 passed, 1 Linux skip**; acquisition: **2 passed, 5 Linux skips**; platform fixture: **40 passed**. Relevant statics, parent review and independent design/runtime review passed; [closure audit](PLAN_V2_audit.md#s0201-modular-distribution-closure-review). | Exact `1ed124bb5ad19c13b507af61e56f796b1c995118`: [core Checks 38865532262](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38865532262), host **612 passed, 28 skips**, 153.75s wall; vendor BusyBox **639 passed, 1 workstation-only skip**, 654.72s wall; four optional diagnostics excluded per phase. Every required job/step passed. [Complete entry/package Quick](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38865544386): **28 passed, no skips**, 3.12s pytest / 3.29s wall. | Accepted: protected manifest data verifies the entry and fixed inert verifier, then complete package admission precedes both installed import paths. Explicit feature/library interfaces, nested passive extensions, both supported manifest headers, installed mapping and native consumer behavior pass. Config/setup/recovery data remains outside payload inventory. Representative Ubuntu/vendor BusyBox; live Merlin/ARM qualification remains beta-only. |
| S02.04 normal scoped prerequisite admission | Complete 15-module gate on the reviewed tree based on `807aa1b`: **299 passed, 55 platform/tool skips**, four optional diagnostics excluded, 137.02s. Planning/package, Ruff/format/compile, shell syntax, ShellCheck, shfmt and whitespace passed; parent, Astra scope review and independent safety review completed. | Exact `e4adda50d141234da6c1f650df6cb7f57fcbeef5`: [Quick A](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38468697992) **225 passed, 1 workstation-only skip**, 48.82s; [B](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38469080381) **92 passed**, 53.96s; [C](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38468896698) **21 passed**, 145.14s; [D](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38468709628) **15 passed**, 108.11s. Every required job passed; four optional diagnostics excluded. | Accepted: real normal retained launch verifies shared tools and configured-tunnel native SRV/A or selected dig capability, repairs only missing/unusable mapped tools, rechecks current scope and post-probes, and reports ordinary DNS deferral without blocking shared admission. Unsafe/storage/unresolved failures remain fatal; resolved migration failures clean up. Settings/history/Off and strict selected reinstall are preserved. Representative Linux/vendor BusyBox with controlled DNS; live qualification remains beta-only. |
| S02.09 native capability/TLS admission | `test_native.py`, `test_install.py`, `test_prerequisites.py`, `test_package.py`, `test_platforms.py`: 112 passed/5 Linux skips, 56.47s on the reviewed dirty tree based on `ac6cb89`; final native/install host-fixture correction: 41 passed/2 Linux skips, 50.17s. All static/planning/package gates passed. Installer success/failure, isolated real TLS trust/hostname cases, CA decode and native mutations proved. | Passed at exact `2c6dfe16ab02d3e8c005851fbab2c7e67d4afeb8`, [Checks 38222000119](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38222000119): host and vendor BusyBox each 117 passed/1 workstation-only skip; all required steps passed. | Accepted: mandatory installer admission and representative TLS/native behavior passed parent review and focused local/CI gates. Static ARM/firmware profiles are recorded in the compatibility guide; model qualification remains beta-only. |
| S02.05/S02.08 fresh and retained consumers | `test_config_observation.py`, `test_retained_launch.py`, `test_dependency_consumer.py`, `test_install.py`, `test_prerequisites.py`, `test_dev_runners.py`: **107 passed, 17 Linux skips**. Final storage-mount/retained fixture checks: **21 passed, 9 Linux skips**. Relevant statics and parent review passed. | Exact `81d2b29fa42374283f3b18d9de37e32f2880628e`, [full Checks 38274552711](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274552711): host **355 passed, 26 skips**; vendor BusyBox **380 passed, 1 workstation-only skip**; four optional diagnostics excluded in each stage. All recorded required test gates passed. | S02.05 accepted: fresh install and retained launch consume normal installed-opkg repair and post-probes without changing retained settings. S02.08's existing guarding, saved observations, retained-launch/repair reporting and cleanup evidence is supplemented by the corrected fresh consumer and final gate below. Synthetic opkg and representative Linux mounts/processes; live Entware/Merlin remains beta evidence. |
| S02.08 corrected fresh-install loss and native ownership | Complete 20-module local gate on the tree committed as `bf3f8ca`: **400 passed, 65 platform/tool skips**, four optional diagnostics excluded; all required statics passed. Final task-root correction: **14 execution-task tests passed**, relevant Python/shell statics passed, deterministic regression failed before the fix. Parent and independent reviews passed. | Exact `1d892a4efc7356508ed306f469f7d3dcc9b11fd2`: [Quick A](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832304399) **81 passed**; [B](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832307235) **178 passed, 1 workstation-only skip**; [C](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832309986) **61 passed**; [D](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832314021) **21 passed**, four optional diagnostics excluded; [E](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832318417) **15 passed**; [F](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832321802) **109 passed**. Every required job/step passed. | Accepted: actual fresh wrapper/publication loss reports through bounded native logging, preserves failure/recovery guards and unresolved identities, rejects unavailable/replaced sources and reports uncertain delivery honestly. Vanishing task roots return to bounded snapshot retry without exiting the controller. Prior retained repair, storage, Save and status consumers pass their complete affected groups. Representative Ubuntu/vendor BusyBox; live Merlin/ARM/syslog qualification remains beta-only. |
| S02.06 installed selected reinstall | Initial complete 15-module local gate: **258 passed, 55 platform skips**, four optional diagnostics excluded, 185.60s on the reviewed tree based on `a9e7e25`. Final repair/action consumer regression: **57 passed, 9 Linux skips**, 17.45s. Planning/package, Ruff/format/compile, shell syntax, ShellCheck, shfmt and whitespace passed; parent and independent review passed. | Exact `03a4f01bc3860be11b5cff2d1faf61f595b589f2`: [Quick A](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443406448) **189 passed, 1 workstation-only skip**, 39.60s; [B](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443410771) **92 passed**, 55.75s; [C](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443415356) **21 passed**, 229.42s; [D](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443419914) **15 passed**, 84.27s. All required jobs/steps passed; four optional diagnostics excluded. | Accepted: installed Advanced options and `--reinstall-dependencies` share explicit default-no confirmation, selected direct packages/alternate provider, configured tunnel DNS scope, native-first optional tools, current-state refusal, fresh post-probes and unchanged settings/history/Off. Real retained force and storage-loss cleanup/reporting pass representative Linux/vendor BusyBox gates; live qualification remains beta-only. |

Focused commands use `.venv/bin/python tools/test.py --focused` followed by the
listed modules under `tests/`. No partial row earns a focused-complete or accepted
subgoal tick. Manual Dev Checks supports focused diagnosis and fixes for core
groups or selected optional tests. Required core Checks must pass at the exact
published candidate before CI-dependent acceptance or a requested pause. Local
packages retain focused tests/commits; full local suites remain reserved for a
main goal reaching 100%. Lint Checks and Diagnostics Checks run manually and are optional.

Test-cost maintenance at `9f62a4a5d9a532f661f835205a420f0fffa8fdc4`: complete
local dependency/retained modules **27 passed, 9 Linux skips**; all affected core
vendor Quick groups **36 passed**. [Final core Checks, attempt 2](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871191644)
passed every required job/step: host **612 passed, 28 skips**, vendor BusyBox
**639 passed, 1 skip**, four optional diagnostics excluded per phase, **16m07s**
job duration. Parent review and statics passed. The
[cost audit](PLAN_V2_audit.md#installer-and-retained-test-cost-review) records
retained-launch consolidation, preserved safety proof and the unproved overall
speedup. Product requirements and accepted counts are unchanged.

Deferred review: [Goal 2 notes](PLAN_V2_review_notes.md#2-installation-storage-and-dependencies).

### 3. Configuration, menus and status

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [x] | [x] | S03.01 | **Passive fresh state:** All three unconfigured/Off; no tunnel/logging/backup setup; manager check On and auto-install Off. |
| [x] | [x] | S03.02 | **Distinct state and settings:** Separate configured/enabled/installed/maintenance, credentials, options, guards and observations. |
| [ ] | [ ] | S03.03 | **Main menu and navigation:** 0/1/2/3/4/fx/ao/u/uf/e with exact dispatch, dedicated nesting and no navigation side effects. |
| [ ] | [ ] | S03.04 | **Feature submenus:** Own setup, On/Off, explicit operation, status and scoped logging/repair; only relevant options. |
| [ ] | [ ] | S03.05 | **Quick service commands:** Shared case-insensitive start/stop handlers, ipsync alias, configure-first validation and truthful results. |
| [ ] | [ ] | S03.06 | **Manager/diagnostic commands:** Update/force aliases, help/version and identical standalone health/doctor/diagnostic reports without implicit repair consent. |
| [x] | [x] | S03.07 | **Basic status dashboard:** Router/resource/address header and compact feature state, last verified family updates, age and current issue summary from local evidence. |
| [ ] | [ ] | S03.08 | **Bounded history and privacy:** Small recorded observations, accurate Unknown/Never/stale labels, no basic-status network calls or secret/raw-data dumps. |
| [x] | [ ] | S03.09 | **Full health diagnostics:** Basic dashboard plus failure-tolerant dependency/config/storage/network/auth/integration/recovery checks; eligible read-only probes, local fallback and no repair. |
| [x] | [ ] | S03.10 | **Terminal presentation:** Clear grouped tables, useful header and issue summary; bounded one-shot output with narrow-terminal/plain-text fallbacks and no UI dependency. |

S03.02 native-setting boundary: represent saved DDNS choices and their mapping to
Merlin's switch/provider/hostname/refresh fields separately from observed NVRAM
values and native lifecycle outcomes. Actual native application and dashboard
parity remain required under S09.05–S09.08; config serialization earns no runtime
integration credit.

S03.02 acceptance: implement fresh schema 2 and explicit schema-1 compatibility
through the real constructor, shared retained/Store admission, scoped manager/
backup Save, storage observation and tolerant status. Prove populated native,
token, advanced, shared/split IP-Sync and maintenance-only configurations;
reference/type/identity rejection; legacy and unrelated-byte preservation;
independent configured/enabled/installed/maintenance state; typed advisory
ownership/history and separate external guards. Certificate associations include
format/account/paths/digest/generation/provenance without claiming authentication.
Unknown required schemas fail closed, ordinary extensions remain inert, and
schema-2 obsolete secret aliases/log-compression controls are rejected. Package
config compatibility changes coherently; independent wire protocols stay intact.

All selected related policy objects contain their full operands; null policies
remain unselected, and null siblings never waive inequalities. Required bounds
mirror the specification:

| Selected setting | Admitted values and relationships |
| --- | --- |
| Request / connection timeout | Request 1–30 seconds; connection 1–10 seconds and no greater than request. |
| DDNS completion timeout | 5–90 seconds and at least request + 5 seconds; later execution must remain inside the matched firmware ceiling. |
| Routine native discovery | 60–3600 seconds in whole minutes; unselected retains the five-minute policy. Independent of outage recovery. |
| Native forced refresh | 1–999 canonical positive days for the pinned three-character native setting interface; default 14. Revalidate the matched firmware before application. |
| IP-Sync retry policy | 1–4 attempts; batch timeout 1–300 seconds and no shorter than request. Expiry may stop before the attempt ceiling. |
| Tunnel reachability | Response 1–2 seconds; command 1–3 seconds and no shorter than response; one packet stays fixed. |
| Tunnel reconnect / stability | Reconnect grace 1–300 seconds; stability 60–3600 seconds. Neither bypasses shared backoff. |
| DDNS TTL | Unselected, Auto or integer seconds 30–86400; effective proxied records require Auto. Provider/account capability remains a separate use-time gate. |
| Tunnel log size / count | Positive canonical size in B/KiB/MiB/GiB; scaled bytes fit signed 64-bit. Positive total count includes live; total minus one fits signed 32-bit. These are representation/tool limits, not product quotas or disk guarantees. |
| Tunnel log mode / age | Size/daily/weekly/monthly; optional age 1–30 days. No compression/delay-compression controls. Native policies are fixed version references. |
| Backup retention / date | Unselected or 3/4/5 archives; unselected or DMY/MDY/YMD. No automatic choice of unresolved defaults. |

Prove exact size/count comparisons without rounding or count-proportional work:
scaled bytes at most 9223372036854775807; total files at most 2147483648. These
source-derived representation limits do not establish installed-tool/filesystem
or extreme-operation qualification. Stale/restored/future historical context does
not invalidate structurally valid settings or become current authority. Empty
defaults or placeholders alone do not complete S03.02; later provider, native
application, lifecycle, history-writing and backup execution earn no credit here.

S03.02 focused local proof on the prepared tree based on `d0da7ec`:
**506 passed, 43 platform skips**, four optional diagnostics excluded, across
the complete affected schema, status, Store/Save, retained launch, installation,
acquisition, dependency and package/fixture groups. The populated schema-2
module passed 68 cases in 76.21 seconds; other groups ranged from 2.84 to 210.50
seconds. Planning/package, Ruff/format/compile, shell syntax, focused ShellCheck,
shfmt and whitespace passed. Parent and independent source review passed;
[audit dispositions](PLAN_V2_audit.md#s0302-schema-implementation-readiness-review)
include preserved backup extensions and measured host-harness timing.

Complete Linux/vendor BusyBox Quick groups passed at
`2dec8a623dba36a4e4718e69b6881918120e2a13`: **548 passed, one
workstation-without-proc skip**, four optional diagnostics excluded, 25.14–231.16
seconds per group. All required jobs/steps passed:
[schema/package](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899821975),
[Store/settings](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899827147),
[menus](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899831811),
[retained launch](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899837709),
[installation](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899842459),
[integration](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899846841),
[dependencies](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38899851735).
S03.02 accepted at that exact candidate after
[final core Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38900418249)
passed every required job/step, dispatched after all focused groups: host
**697 passed, 28 platform skips** in 169.60 seconds wall; mandatory vendor
BusyBox **724 passed, one workstation-only skip** in 687.40 seconds wall.
Four optional diagnostics were excluded per phase. Total job time **14m44s**;
the measured previous checkpoint was 15m09s. Required coverage and the 20-minute
runner limit stayed intact. No full local suite was due. Parent review and test
cost review passed; native DDNS application, provider/lifecycle operations,
logging execution and later feature workflows receive no additional credit.

S03.07 accepted at `d173d691254023a757361996c5b86ff8f8c609bd`: actual installed
choice `0`, menu return before operational preparation, native resource/WAN/NTP/
mount readings, separate settings and typed historical outcomes, age/privacy and
configuration-failure isolation. Local gate: **230 passed, 15 platform skips**,
122.62s pytest; 250.86s including statics/planning/package checks. A fixture-mode
correction retained identical runtime; the complete local status module then
passed **28 with two Linux skips** in 6.26s. Parent review passed.

All complete Quick groups passed at that same final revision:
[A — status](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38479557168)
**30 passed, 18.59s**;
[B — entry/package](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38479679230)
**126 passed, 140.76s**;
[C — shared foundations](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38479691428)
**88 passed, one workstation-only skip, 32.06s**. Linux normal reporting,
owned stalled-probe cancellation, aggregate deadline and cleanup passed. Costs
reviewed; no full suite was due. Representative Ubuntu/vendor BusyBox evidence
does not establish live Merlin/ARM qualification. Only S03.07 earns this tick;
history writers, full diagnostics and final terminal presentation remain separate.

S03.09/S03.10 accepted at `5a96d6730e8683a50cdb0861c33e2e8cfc5e32a1` after parent review,
[independent design/source audits and integration repairs](PLAN_V2_audit.md#s0309-and-s0310-health-entry-and-provider-evidence).
The actual early health/doctor/diagnostic entries retain native fallback, independent
bounded local observations and eligible read-only provider checks. Private typed
receipts, credential/resource holds, retained-source protection, owned child cleanup,
package/recovery/backup/logging/hook observations and grouped plain/narrow output
are implemented and tested. Missing operational producers remain explicitly unknown;
no provider-write, connector, repair, setup or lifecycle acceptance is implied.

Complete affected Dev gates at the same revision:
[original eight modules](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39585209229)
**445 passed, 177.68s**;
[acquisition and supervision](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39585210610)
**47 passed, one workstation-only skip, 71.10s**. The focused history extraction
and real acquisition-to-installer regression also passed both cases in 37.56s.

[Final aggregate Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39585638313)
and every required host/vendor BusyBox module job passed at that exact SHA:

| Complete core module | Host pytest result | Vendor BusyBox pytest result | Whole-job elapsed, host / native |
| --- | --- | --- | --- |
| [Backup](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39585682321) | 410 passed, one native-only skip; 129.45s | 411 passed; 372.68s | 2m28s / 6m28s |
| [Manager](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39585684642) | 609 passed, 29 platform skips, four optional diagnostics deselected; 91.18s | 637 passed, one workstation-only skip, four optional diagnostics deselected; 345.90s | 1m54s / 6m04s |
| [Status](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39585687240) | 250 passed; 30.01s | 250 passed; 74.46s | 44s / 1m31s |

The full native health journey completed twelve GETs and 59 rows in 30 reported
seconds/33.96s wall, with 537 operations/1,160 files/11,338,428 reserved bytes;
finalization used two operations/four files/790,528 bytes. All retained canaries,
privacy, resource bounds and owned cleanup assertions passed. Required preflight,
planning/package, Python lint/format/compile and shell syntax/format gates passed.
All modules are below the ten-minute cost target including setup. Optional stress
and extended ShellCheck were not part of this required gate and are not claimed.

The user-authorized light-Mac/CI route is documented in
[Goal 3 review notes](PLAN_V2_review_notes.md#3-configuration-menus-and-status).
Local behavior boxes remain unticked: after the AWK incident only source checks
ran on macOS; subsequent complete behavior proof is CI. No main-goal full-local
suite was due or waived. Representative Ubuntu/vendor BusyBox with explicit
firmware/provider fixtures is not Merlin/ARM/live-provider qualification.
Goal 3 is now 5/10 accepted; this checkpoint awards only S03.09 and S03.10.

### 4. Save, cancellation and recovery

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [x] | [x] | S04.01 | **Safe data parsing:** Bounded schema/JSON/certificate/YAML/catalog inputs treated as data, never sourced/evaluated. |
| [x] | [x] | S04.02 | **Scoped concurrent Save:** Accepted fields overwrite same-field edits, preserve unrelated guards/settings, detect content changes and respect later Off. |
| [x] | [x] | S04.03 | **Durable staged commit:** Pre-change intent/recovery, verified coherent publication and honest flush/write/rollback failure handling within documented firmware limits. |
| [ ] | [ ] | S04.04 | **Native resumable drafts:** Completed private DDNS/IP-Sync inputs survive exit/signals without touching active config or enabling work. |
| [ ] | [ ] | S04.05 | **Cloudflared Save boundary:** Pre-Save cancellation; mutation-time e disabled; signals honored with bounded cleanup and guarded recovery. |
| [ ] | [ ] | S04.06 | **Input/terminal handling:** No EOF/default-yes or noninteractive prompting; restore echo, reject unsafe controls and preserve literal data. |
| [ ] | [ ] | S04.07 | **Restart recovery:** Inspect guards before activation, preserve damaged/recoverable data and never repeat uncertain provider creation. |
| [ ] | [ ] | S04.08 | **Ownership and locks:** Stable lock identities, verified process start/boot identity, correct provider-child versus connector descriptor lifetime. |
| [ ] | [ ] | S04.09 | **Generation and resource bounds:** Compatible package per invocation, current-state checks, late-result rejection and bounded whole-action cleanup. |

S04.01 accepted at **`c8c76f0d5cc44792387dc43388f7dc418a7fb3fb`**. The
[parser audit](PLAN_V2_audit.md#s0401-safe-data-parsing-review) records the complete
current-consumer contract, repairs, independent agreement and cost review. Future
setup/provider/restore consumers retain their own integration gates. Complete Mac
Backup passed **360 / 23 platform skips** in **549.47s wall / 264.71s user /
184.94s system**, with all 383 cases and safety assertions retained. Unchanged
Manager local proof remains **522 / 72 platform skips**, **343.89s wall**, from
the original parser candidate `efdd465882babd54984c7aa8f0aed94549900ea3`; four
optional diagnostics were excluded. Required statics passed.

Final native [I/O/verifier Dev](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39193491808)
passed **56 tests**, **108.68s wall / 56.74s user / 52.41s system**, **130s including
setup**. Exact [Checks 39193784039](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39193784039)
and all six required module jobs passed: [Backup](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39193829112)
**6m05s**, [Manager](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39193830861)
**8m30s**, [Status](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39193832435)
**33s**, including setup. Core host total **983 passed / 30 platform skips**;
native **1,012 passed / one workstation-only skip**; four optional diagnostics
excluded per platform. These are representative Ubuntu/BusyBox results, not
Merlin/ARM qualification. Complete Mac Backup fell from **697.10s to 549.47s wall**
after repeated padding-wrapper launches were removed from broad fixtures;
dedicated inode-padding proof remains. The paired five-case comparison also
reduced CPU cost. No timing exception, permanent group split or safety waiver
was needed. No full local suite or main-goal completion gate is claimed.

S04.02 accepted at **`dad30c8ab9c6ac3f2f93d12e8efd9e0187f502ea`**.
Focused local proof passed on the prepared tree based on `95ecbdd`:
**123 passed, five platform skips** across complete Store/parser, manager
settings/installed entry, backup storage/menu and retained-launch modules.
Planning/package, Ruff/format/compile, shell syntax, shfmt and whitespace passed;
parent and independent Astra review passed. The
[scoped-Save audit](PLAN_V2_audit.md#s0402-scoped-concurrent-save-review)
records meaningful same-generation merge/refusal, confirmed-field precedence,
unrelated-byte preservation and later-Off rejection through current consumers.
Complete focused Linux/vendor BusyBox proof passed at that candidate:
[Quick A](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38885975614)
**106 passed, 85.69s** and [Quick B](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38885979958)
**22 passed, 152.81s**. Final
[core Checks 38886407905](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38886407905)
passed at the same exact candidate after both focused gates: host **628 passed,
28 platform skips**, 172.93s wall; vendor BusyBox **655 passed, one workstation-only
skip**, 716.70s wall. Four optional diagnostics were excluded in each phase;
every required job/step passed. The job took **15m09s**. This accepts the shared
foundation across current Save/observation consumers; future feature consumers
retain their own integration gates. Live Merlin/ARM qualification remains beta-only.
No other subgoal or main-goal gate receives credit from this checkpoint.

S04.03 accepted at **`457296c79bd786083eb944e0c1cea2ecc9ddce10`**. Focused local
proof: **190 passed, 34 platform skips**, with four optional
diagnostics excluded, across the complete affected Store/settings/backup,
installer/retained and shared dispatch/consumer modules. Relevant statics and
parent review passed. [The durable-commit audit](PLAN_V2_audit.md#s0403-durable-staged-commit-review)
records scope, failure evidence, all four passing Quick groups (**227 passed,
one workstation-only skip**) and measured costs. Final
[core Checks 38880966640](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38880966640)
passed at that exact candidate after the focused gates: host **624 passed,
28 platform skips**, 164.71s wall; vendor BusyBox **651 passed, one workstation-only
skip**, 690.62s wall. Four optional diagnostics were excluded in each phase;
every required job/step passed. The job took 14m40s. Store/backup recovery,
retained-observation space and failure boundaries, and guarded fresh completion
are accepted within documented firmware limits. Live Merlin/ARM/flash proof
remains beta-only. No other Goal 4 subgoal or main-goal gate receives credit.

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
| [ ] | [ ] | S06.10 | **Idle versus On recovery:** Artifact-only maintenance needs no tunnel launch; managed On recovers an interrupted corrupt binary update after readiness with a syslog warning; fresh owned evidence, later Off and truthful rollback apply. |

### 7. CFMgr updates, source selection and developer mode

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [x] | [x] | S07.01 | **Check and auto settings:** Default-On checks/default-Off opt-in install, coupled effective settings independent of tunnel/Entware. |
| [ ] | [ ] | S07.02 | **Launch/daily checks:** Bounded coalesced source checks, once-per-launch y/n update offer, RAM metadata and truthful unknown/error without redraw or boot blocking. |
| [ ] | [ ] | S07.03 | **Manual update/force:** Explicit revalidation/confirmation, current skip or complete reinstall; compatible older manager snapshot only through confirmed developer force. |
| [ ] | [ ] | S07.04 | **Unattended installation:** Saved opt-in and source/ownership rechecked at switch; active transactions defer safely. |
| [ ] | [ ] | S07.05 | **Developer suppression:** Manual-only flag suppresses checks/auto/external callbacks; confirmed force retains normal verification. |
| [ ] | [ ] | S07.06 | **Source selection and catalog:** One code-defined repository/branch default serves install and self-update; only developer mode permits config source overrides; catalog maps one immutable package. |
| [ ] | [ ] | S07.07 | **Developer source retention:** Developer retains configured source; normal operations use the shared code defaults (temporarily develop, later main); successful replacement resets source fields and replaces its catalog. |
| [x] | [x] | S07.08 | **Trusted complete package:** Manifest/hash/version/schema/path/syntax checks before execution, one pinned compatible generation. |
| [ ] | [ ] | S07.09 | **State-preserving update:** No healthy feature reinstall/restart/provider call or config loss; guarded actual owned drift only. |
| [ ] | [ ] | S07.10 | **Self-update failure recovery:** Distinct transfer/storage/switch/hook-reinjection/overlap/opt-out/rollback boundaries preserve last trusted complete package and report incomplete integration honestly. |
| [ ] | [ ] | S07.11 | **Optional amtm:** User-chosen personal launcher; official updater conditional with separate opt-in, no private registry hacks. |

S07.08 accepted at `ffea9ebd59236045579b9250d383aa1c7acf1e09`.
`--install-remote` uses an explicitly trusted complete local
bootstrap, resolves one full commit and validates the complete downloaded package
before the real fresh installer runs. Available local focused gates passed;
Linux-only cases were explicitly skipped locally, then proved by complete vendor
BusyBox Quick groups at that SHA:
[transport/syntax](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858125065)
**3 passed, 2.22s**, and
[acquired installer](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858127676)
**4 passed, 144.26s**, both without skips. Parent and independent
[design/runtime reviews](PLAN_V2_audit.md#s0708-acquisition-and-pre-execution-design-review)
passed. Required [core Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858115527)
passed at that exact SHA: host **597 passed, 28 platform skips**, vendor BusyBox
**624 passed, one workstation-only skip**; four optional diagnostics were excluded
from each selection. Every required job/step passed. The whole job took 15m32s;
focused cost and complete local/CI receipts are in the
[checkpoint handoff](PLAN_V2_handoff.md#paused-after-accepted-s0708--ready-to-select-the-next-task).
Supporting S07.06/S02.01 remain partial, with no standalone bootstrap or self-update
claim. This is representative development proof; live Merlin/ARM qualification
remains beta work. No main goal or full local milestone gate is completed.

S07.01 accepted at `576584885befb84f10bf8c10365a872a0b9fa406`: actual installed
`ao → CFMgr updates` supports reviewed native Save, coupled intent, cancellation,
reopening and saved/effective status independently of Cloudflared and Entware.
Complete focused host modules and required statics passed; parent, independent
runtime and Astra design/fix reviews completed. Linux/vendor BusyBox proved the
actual supervised Save, child-held exclusion, restored observation descriptors,
shared-writer coordination and guarded recovery at the accepted revision.

All six complete Quick groups passed at that same revision:
[A — settings/store](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38488764958)
**49 passed, 46.97s**;
[B — menu/status](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38488912894)
**140 passed, 48.78s**;
[C — shared consumers](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38489196075)
**121 passed, one workstation-only skip, 37.36s**;
[D — package/storage](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38489342960)
**92 passed, 57.44s**;
[E — dependency repair](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38488768533)
**21 passed, four optional diagnostics excluded, 218.17s**;
[F — retained launch](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38489164759)
**15 passed, 115.70s**. Every required job/step passed and cost was reviewed.
Full local/full CI was not due. Host commands, module mapping and bounded firmware
evidence are retained in the [checkpoint receipt](PLAN_V2_handoff.md#paused-checkpoint--s0701-accepted).
Only S07.01 earns acceptance; shared Save support does not complete Goal 4.
Live Merlin/ARM and flash persistence remain separately authorized beta proof.

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

S09.06 native forced-refresh acceptance: keep the 14-day CFMgr default and derive
the positive-day maximum from the verified matched Merlin setting, without an
independently chosen CFMgr cap. Frontend input width alone does not prove a
backend numeric limit.

S09.05–S09.08 native ownership acceptance: while CFMgr owns DDNS, its Save/On/Off
controls Merlin's native configuration, handler and lifecycle. Verify equivalent
native DDNS backend effects to GUI Apply, including owned `ddns_enable_x=1/0`,
Custom provider, selected primary hostname and refresh days. Verify the requested
native service transition and the fields consumed by Merlin's page; config/NVRAM
writes or service-request acknowledgement alone do not pass. Saving settings
while Off preserves Off. Test partial/interrupted apply, outstanding owned work
and stale callbacks, truthful completion and unchanged independent IP-Sync.
Preserve unrelated settings and respect later external ownership. Native-page
values must reflect applied state; real-router GUI/lifecycle qualification
remains beta proof under the existing platform boundary.
The [native DDNS source review](PLAN_V2_audit.md#s0905s0908-native-ddns-ownership-source-review)
records why firmware fields, native service dispatch and CFMgr worker containment
require separate proof. It supplies source evidence only; these IDs remain pending.

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
| [ ] | [ ] | S12.05 | **Mount and shutdown:** Re-resolve and admit current `/opt`, scoped resume and suppression-before-stop within firmware budget. |
| [ ] | [ ] | S12.06 | **Eligible schedules:** One global watchdog dispatches eligible tunnel/native/retry work; native DDNS days, binary updates and manager checks retain distinct schedules. |
| [ ] | [ ] | S12.07 | **No duplicate/foreign jobs:** Exact names plus commands/ownership; Scribe owns rotation, backups manual, Off removes only its scope. |
| [ ] | [ ] | S12.08 | **Bounded resource admission:** Coalesce before spawn/sleep, cap active/pending children/RAM/notices and aggregate work/cleanup. |
| [ ] | [ ] | S12.09 | **Real detachment:** Close inherited pipes/terminal/irrelevant descriptors; prove hook return while worker lives. |
| [ ] | [ ] | S12.10 | **Safe failure recovery:** No boot wait, infinite install/create/crash loop, reboot/global restart or teardown respawn. |
| [ ] | [ ] | S12.11 | **Shared watchdog and recovery:** All three features share NTP/reachability recovery with 1/2/4/5-minute capped due checks, isolated auth/throttle gates and transition logging. |

Outage retry acceptance (S06.06/S12.11): after 1/2/4/5-minute backoff, continue
5/5/5-minute rechecks until connectivity recovers or no eligible recovery remains,
with no overall retry-count or elapsed-time cutoff. Routine native discovery and
bounded provider-batch attempt limits cannot lengthen or exhaust this recovery
cadence. Every individual check is bounded and returns to the dispatcher; current
auth guards and provider cooldowns still gate provider operations.

### 13. Logging and rotation

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [ ] | [ ] | S13.01 | **Three private logs/native notices:** Normal setup detail stays terminal-only; native notices reach system messages, eligible feature logs add a copy and daemon stream stays file-only; no global routes or routine manager logfile, with explicit developer diagnostics under S13.14. |
| [ ] | [ ] | S13.02 | **First setup versus saved preference:** Only completed fresh ready setup initializes own logs; pending/maintenance-only/opt-out remain inactive. |
| [ ] | [ ] | S13.03 | **Readiness and independence:** Verified mounted Entware /opt/var/log paths and actual Scribe/base/schedule/include readiness, graceful no-file operation and service-Off rotation retention. |
| [ ] | [ ] | S13.04 | **Cloudflared tuning:** Per-file size/total-count including live file, shown Enter defaults and supported time/age options; uncompressed log history and no aggregate-byte quota. |
| [ ] | [ ] | S13.05 | **Fixed native policies:** Separate versioned DDNS/IP-Sync defaults with no tuning UI or config override. |
| [ ] | [ ] | S13.06 | **Rotation correctness:** Numbered history/actual cadence, daemon reopen or stated copytruncate limit, safe native append and snapshot coordination. |
| [ ] | [ ] | S13.07 | **Fast scoped repair:** Cheap requested-feature checks, bounded owned fragment/include repair and full explicit validation without base/global changes. |
| [ ] | [ ] | S13.08 | **Install/policy transaction:** Owned /opt/etc/logrotate.d fragments, direct no-rotation validation and coherent config/rule rollback; automatic next-run discovery without Scribe reload/restart or forced rotation. |
| [ ] | [ ] | S13.09 | **Logging uninstall:** Durable opt-out before writer quiescence/deletion; missing Scribe allowed, storage failure deferred and no false removal. |
| [ ] | [ ] | S13.10 | **Resume without file output:** Release runtime guard after safe quiescence/opt-out, retain residual cleanup, resume only still-On/no-file work. |
| [ ] | [ ] | S13.11 | **Optional external viewing:** Supported bounded owned-path registry only if selected; no fake routing/private patches or CFMgr WebUI requirement. |
| [ ] | [ ] | S13.12 | **Explicit all-service re-detect:** Ready Scribe enables logging for every configured On service, overriding prior logging Off only for this explicit action; reuse policies or initialize defaults. |
| [ ] | [ ] | S13.13 | **Prominent concise event format:** Single-line [CFMGR] component: Info/Warning/Error messages with matching syslog severity, verified outcomes/IPs, actionable failures/repair notices, eligible feature-file plus syslog delivery and duplicate suppression; normal/developer credential references identify type/purpose and mask any displayed value. |
| [ ] | [ ] | S13.14 | **Developer diagnostic capture:** Developer-mode-only main-process/all-module trace capture and dedicated Scribe-log copies in a global-config directory, independent of feature On/Off, with redaction and safe storage handling; no destination rotation, pruning or automatic cleanup. |

Cloudflared tuning acceptance (S13.04): use conservative fresh defaults and allow
positive user-selected file sizes and total-file counts without a fixed CFMgr
product maximum or aggregate-byte quota. Validate supported units, finite positive
values, numeric/tool/filesystem limits and bounded operation; reject invalid or
overflowing input without changing the working policy. Optional maximum age is
Off or an integer 1–30 days. Keep logging on admitted mounted `/opt` storage, with
no JFFS/RAM fallback. Native DDNS/IP-Sync policies remain fixed. The proposed safe
defaults remain `10M` and five total files, including the live file. All owned
live logs and rotated history remain uncompressed, with explicit owned-rule
`nocompress`/`nodelaycompress` overriding inherited compression settings. No
logging compression/delay-compression option or saved policy field is provided;
gzip remains reserved for the backup archive contract in S14.01.

Developer diagnostics acceptance (S13.14): fresh destination is `null`; only
`manager.developer` enables capture, with feature On/Off ignored as a logging gate.
Verify main-process/all-module and child/error/Off paths reach `developer.log`,
dedicated CFMgr Scribe content is copied without changing source policies, source
rotation preserves captured history, and developer Off stops new capture while
retaining files. Exercise configurable paths, missing Scribe/source logs, mount
loss/replacement, unsafe paths and full/I/O-failed storage; no stale-mount writes
or false captured/success claim. Credential references follow the shared masking
rule below. The destination has no CFMgr rotation/pruning/truncation/automatic cleanup; retention is user-managed,
while individual records, buffering and copy work remain bounded. Automated
fixtures supply development acceptance; prolonged actual-router capture is beta
evidence and is not claimed before it runs.

Credential logging acceptance (S13.13/S13.14): normal and developer terminal,
syslog, feature-file, trace/child-output and Scribe-copy paths identify the real
credential type and purpose when relevant. An eligible opaque value is at most
`****` plus its final three characters; short/structured/unsafe material has no
suffix. Tests cover distinct token/API-key roles, short values, control characters,
child output and copied logs, and reject any full credential, authorization header,
password, private key, credential JSON/certificate or sensitive payload leakage.
Developer mode cannot bypass masking; irrelevant events contain no credential value.

### 14. Backup and restore

| Status | Focused local | ID | Subgoal and required result |
| --- | --- | --- | --- |
| [x] | [x] | S14.01 | **Manual CFMgr-only archives:** Native unencrypted data-only tar.gz, privacy notice/best-effort modes, no router/add-on/code backup or schedule. |
| [x] | [x] | S14.02 | **Mounted-drive picker:** Explicit numbered exact mount identity including one drive, root CFBackup, no stale/fallback destination. |
| [x] | [x] | S14.03 | **Archive selection/actions:** Numbered newest list, inspect/verify/review restore and confirmed deletion; alternate source does not reset destination. |
| [x] | [x] | S14.04 | **Local date naming:** Regional date choice, same-day time suffix/collision refusal and manifest chronology across format/DST changes. |
| [x] | [x] | S14.05 | **Verified-new-first retention:** Keep 3–5 same-set completed archives; prune only after verified commit and report purge failure separately. |
| [x] | [x] | S14.06 | **Coherent data allowlist:** Config/catalog/typed authority/drafts/full YAML/JSON/both cert copies/.bak/preferences/eligible history; no live controls/executables. |
| [x] | [x] | S14.07 | **Required versus optional payload:** Required authority/YAML cannot be omitted; external dependencies inventoried, optional cert/binary absence handled honestly. |
| [x] | [x] | S14.08 | **Backup transaction:** Consistent bounded source/rotation locks, private same-filesystem archive, hashes/mount recheck/atomic commit. |
| [ ] | [ ] | S14.09 | **Safe current-code restore:** Exact input/schema/hash/path/type/size validation, supported migration and current components, no archive code/downgrade. |
| [ ] | [ ] | S14.10 | **State-aware reconstruction:** Never-configured/draft/maintenance/On/Off rules, independent logging preference and explicitly deferred optional history. |
| [ ] | [ ] | S14.11 | **Guarded restore/recovery:** Fresh local ownership/generation, current auth/source admission, local rollback distinct from new auth-Off and no stale replay. |

S14.02 accepted at `f762dd731a7284a7a6377ffebb738209b9fd49a8` after parent
review, written focused local checks, common statics and exact-candidate
[core Checks 38852845631](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38852845631):
588 host passes / 28 platform-specific skips and 615 vendor BusyBox passes /
one workstation-only skip; four optional diagnostics excluded from each phase.
All required Linux mount/ownership cases and the complete menu consumer ran.
Core job: 11m14s. The final [focused menu group](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38852858797)
passed all 11 backup/settings journeys under vendor BusyBox in 21.15s wall,
with no skips; the same selected-shell group passed locally in 51.43s.
Typed destination persistence, exact mounted-drive admission, guarded root
CFBackup creation/reuse and menu-4 selection/Save/reopen are integrated.
The [audit record](PLAN_V2_audit.md#s1402-destination-foundation-design-review)
records design, implementation, test-fixture corrections and final review.
Supporting portions of S02.02, S03.03 and Goal 4 receive no additional ticks;
manual archive creation still requires its own acceptance gate; browse/restore
and live firmware/filesystem qualification remain unfinished.

S14.01 and S14.04–S14.08 accepted at **`4942b3416fbc68aeeace15284dccf6077f3cf138`** after
complete implementation, written focused local gates, parent and independent
reviews, the [controller/consolidation audit](PLAN_V2_audit.md#s1401-s1404s1408-create-controller-review),
and exact-candidate [Checks 39034472135](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034472135). That checkpoint accepted seven Goal 14 subgoals;
S14.03's subsequent acceptance is recorded below. No main-goal tick is awarded.

The actual menu/controller creates native unencrypted data-only archives with
required/optional capture rules, local date naming, full integrity/semantic
verification, guarded atomic publication and verified-new-first retention.
Written local proof includes the complete creation journey, menu/controller,
transaction, rich capture, verifier, history, writer, I/O and Store/config scopes.
The final runtime cost repair passed 45 local cases / 15 explicit Linux skips;
eighteen native diagnostic groups subsequently covered all 951 Backup/Manager
cases, with every diagnostic job at most 152s. The final whole-module CI below
closes required native process/FD/lock/mount and supervisor proof. Diagnostic
selections supplement, never replace, these complete groups.

| Complete required module | Host result | Vendor BusyBox result | Module wall incl. setup |
| --- | --- | --- | --- |
| [Backup Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034514621) | 374 passed / 1 platform skip; 120.20s | 375 passed; 428.14s | 7m31s |
| [Manager Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034515614) | 547 passed / 29 platform skips; 80.33s | 575 passed / 1 workstation-only skip; 480.76s | 8m21s |
| [Status Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034516700) | 36 passed | 36 passed | 38s |

All six platform jobs, common planning/statics/both syntax, dispatch and strict
parent collection passed at the same full SHA. Four optional diagnostics were
excluded per platform. Each module has a separate workflow run/history; the
aggregate verifies exact identities and current attempts. Optional [Tools Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034479114)
also passed 214 cases on each platform (1.60s host / 1.38s native; 19s whole job).
Developer tooling, consolidation and CI changes add no product credit.
The final CI-only change leaves runtime files identical to `b0a39dc`, whose
complete core and all eighteen diagnostic groups also passed. Representative
Ubuntu/vendor BusyBox evidence does not qualify Merlin/ARM or live deployment;
[retained evidence limits](PLAN_V2_review_notes.md#14-backup-and-restore) remain.

S14.03 accepted at **`00b71feb70eac9d59138eb37310bfd42f95360d4`** after parent and
independent review, written focused Mac/native tests, statics and exact complete
[Checks 39235896209](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235896209).
The installed Backup consumer supports an independent selected source without
saved destination/set, bounded newest-first metadata listing, selected complete
verification and secret-safe actual restore-effects review, and default-no
receipt-bound single deletion. Destination/preferences and unrelated archives
remain preserved; no restore Save or activation is implemented by this ID.

| Complete required module | Host result | Vendor BusyBox result | Module wall incl. setup/post-job work |
| --- | --- | --- | --- |
| [Backup 39235953005](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235953005) | 404 passed / one platform skip | 405 passed | **7m37s** |
| [Manager 39235955405](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235955405) | 565 passed / 29 platform skips | 593 passed / one workstation-only skip | **8m47s** |
| [Status 39235958181](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235958181) | 36 passed | 36 passed | **46s** |

Four optional diagnostics were excluded per Manager platform. Required preflight,
host/native syntax and strict exact-SHA collection passed. The complete changed
history module also passed **46 tests in 13.82s**, 30s including setup, in
[Dev 39235693968](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235693968)
after its stale lock-fixture replacement was repaired. The
[S14.03 audit](PLAN_V2_audit.md#s1403-archive-selection-and-actions-review) records
the implementation, two measured process-work optimizations and final cost review.

Focused local evidence includes the real selected verification/deletion journey,
safe projection, owned cleanup, menu handling, RAM receipt batching and fixed
header reads. The full installed browser journey and native file-limit/FD proof
passed in CI. **The user explicitly approved a one-time local-gate exception**
after all required CI passed: the final Mac Backup run remains failed at its
eight-second Save acknowledgement wait, complete final Mac Manager was not rerun,
and the earlier passing complete Backup run took 607.79s. No local complete pass
is invented. The [review note](PLAN_V2_review_notes.md#14-backup-and-restore)
records the precise exception and host limits. Goal 14 now has **8/11 accepted**;
S14.09–S14.11 remain unfinished. No main-goal audit/full-local gate or live-router
qualification is claimed.

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
| [ ] | [ ] | S16.01 | **Usable integrated product:** Required workflows are implemented through actual user entry paths, with representative automated acceptance and declared beta target limits. |
| [ ] | [ ] | S16.02 | **Evidence and limitations:** At final documentation readiness, separate source/Linux/BusyBox evidence from deferred live beta qualification across the completed product; no unearned hardware or stable-support claims, IPv6 provisional explicit. |
| [ ] | [ ] | S16.03 | **Complete practical guides:** Keep developer notes to essential tools/setup/check commands throughout implementation; after runtime acceptance, complete architecture/developer and install/setup/credentials/operation/update/recovery/logging/archive/removal guides before declaring 100% implementation/beta readiness. |
| [ ] | [ ] | S16.04 | **Cloudflare prerequisites:** At final documentation readiness, complete account/domain/DNS and policy wiring guidance verified against implemented setup, with no extra runtime prompts or private-network restriction. |
| [ ] | [ ] | S16.05 | **Safe reproducible delivery:** At final documentation readiness, sanitized examples/screenshots and validated real installer command/failure behavior match the completed product. |
| [ ] | [ ] | S16.06 | **Release readiness:** Coherent first version, automated development acceptance and extended router beta before stable qualification; required functionality/documentation before optional final polish. |

Development acceptance requires representative normal-operation and serious-failure
tests under [specification section 16](PLAN_V2.md#16-product-readiness-and-documentation).
Relaxed acceptance points and deferred risks belong in [review notes](PLAN_V2_review_notes.md).

**Documentation phase gate:** complete and accept S16.02–S16.05 only after the
required runtime work in goals 1–15 passes its applicable acceptance gates, then
finish documentation before declaring 100% implementation/beta readiness. Earlier
installer implementation/failure-path tests remain evidence for their owning
requirements but do not complete S16.05's final delivery obligation. Accurately
deferred live beta proof does not block documentation acceptance.

Necessary current README/status, proven compatibility/evidence limits, contributor
setup/check commands and guidance directly required by earlier runtime work may
be maintained, but earn no final-documentation ticks. Acceptance requires the
entire required result with no known finishing work deferred to the final audit.
Later behavior/evidence changes require maintenance and revalidation.

### Planned documentation coverage for S16.03

Developer notes stay minimal until runtime acceptance; complete the full guides
before declaring 100% implementation/beta readiness.
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
| [ ] | `docs/compatibility.md` | Target firmware/native-tool/ABI profiles, runtime capability checks, automated/source evidence, deferred router-beta qualification and provisional support limits. | 2, 8, 16 |
| [ ] | `docs/architecture.md` | Actual entry/module/shared-library interfaces, storage/state authority, ownership/locks, transactions, worker/lifecycle/resolver/provider flows and integration boundaries. | 1–15 |
| [ ] | `docs/development.md` | Reproducible environment, source references, focused/full tests on one Ubuntu CI runner with vendor BusyBox, optional platform diagnostics, efficient verified caches/fresh mutable state, package generation and extended router-beta workflow. | All goals, especially 2, 7, 16 |
| [ ] | `CONTRIBUTING.md` | Concise change/review workflow, scope/checklist discipline, validation/privacy rules and links to development/architecture guidance. | 16 |

## Developer tooling acceptance

Tooling is supporting delivery, separate from the 16 product goals and the active
main-goal percentage. A tick requires its complete approved behavior, focused local
tests and any required exact-commit CI. Record concise accepted evidence here;
keep active work in handoff. New entries/scope require user approval.

| Accepted | Tool | Required proof |
| --- | --- | --- |
| [x] | Planning checker | Valid documents pass; misalignment, broken links and private paths fail. |
| [x] | Focused/full test runner | Correct selection, required static gates and truthful failure/skip handling. |
| [x] | Platform runner | Input/cache/staging/log-oracle tests and actual native-host vendor BusyBox execution in the required Ubuntu gate; retained QEMU/ARM paths have separate optional proof status. |
| [x] | Package builder | Deterministic complete package, correct mapping and manifest, unsafe/stale input rejection. |
| [x] | Router probe tools | Config/auth/quoting/status tests without live SSH; native admission, descriptor ownership and cleanup proof in isolated Linux/BusyBox fixtures. |

Router configuration acceptance includes explicit `KEY`/`USR` modes, blank unused
credentials for key authentication, required username/password for `USR`, and
blank/`null` port inheritance or an explicit integer port override.

All five tools have their listed development proof at tested code
`7ce3cad771a7cedb0e2f17e69082f9659655c5c5` and
[Checks 38200865754](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38200865754).
Focused local tests cover checker/runner behavior, platform inputs/cache/oracles,
package mapping/unsafe rejection and router configuration/auth/quoting/status.
The full Ubuntu/vendor BusyBox suites prove required native descriptor/cleanup
cases. The portable launcher has not been run on the live router; optional
QEMU/ARM execution remains unaccepted. Tool ticks add no product progress.

## Open product decisions

See specification section 17. These remain unresolved until their owning workflow has a supported concrete decision.

| Status | Decision area |
| --- | --- |
| [ ] | **Configuration/transactions:** Exact bounded schema/ref/generation/guard formats; reliable write/flush/rename and failure reporting; supported native JSON/certificate/YAML subset; scoped merge and cross-filesystem recovery. |
| [ ] | **Package distribution:** Section 2 fixes the source-to-installed mapping. Remaining decisions/proof: bootstrap acquisition/manifest trust, complete update generation activation/reader retention, developer-only config source grammar/shared-default reset, catalog compatibility beyond the initial schema, supported historical snapshots and development-commit comparison; beta version grammar before first release. |
| [ ] | **Supported platforms:** GT-AX11000 baseline plus modern Merlin targets; firmware/BusyBox/Entware ABI/dependency source references and fail-closed native-path/options/CA checks; explicit package/ABI exclusions and deferred router-beta model qualification, with no historical-coverage obligation or support inferred solely from feed names. |
| [ ] | **Storage/processes:** Persistent/attached volume identity, mount-race handling, approved path whitelist, lock order/descriptor lifetime, child identity/quiescence and uninterruptible-I/O limitation. |
| [ ] | **Budgets/readiness:** Aggregate hook/DDNS/worker/response/staging/queue bounds; monotonic clocks, NTP/transport/egress evidence, reconnect grace/stability criteria, common outage retry fixed at 1/2/4/5 minutes (300-second cap); verify scoped provider-delay parsing and separate no-hint throttle 5/10/20/30-minute state. |
| [ ] | **Firmware DDNS:** DDNS soft timer inside matched whole-action ceiling, overlap without request IDs and native retry collision; default 14-day field/bounds/apply/persistence/certificate side effects and ownership relinquishment. |
| [ ] | **Native discovery:** Selected WAN/protocol/interface mapping, complete absence evidence, routed IPv4/IPv6 observations/lifetimes and scoped support for less-common firmware modes. |
| [ ] | **Provider operations:** Permissions, pagination/completeness, exact managed fields, same-ID empty-list removal, actual mixed-family-list capability, user-selected shared/split migration and target-vs-feature fault schema; no extra feature inferred from uncertain API behavior. |
| [ ] | **Cloudflared:** Token-file floor/default-config isolation, A2 create/token endpoint permissions and failure handling, B route-discovery completeness/lossless mapping edits, login/certificate provenance/manual fallback, same-UUID fetch and runtime auth/connectivity classifier; no implicit binary auto-update default where not selected. |
| [ ] | **Scheduling:** Exact manager daily cron time/registration/removal; shared minute dispatcher, five-minute native discovery and per-scope due-state reconciliation with native DDNS retries. |
| [ ] | **Logging:** Actual Scribe/include/schedule state, daemon reopen/copytruncate, rotation concurrency; uncompressed history despite inherited compression settings, proposed Cloudflared 10M/five-total-files and native 1M/two-total-files defaults, safe count-one reuse and launch budgets. |
| [ ] | **Backup:** Stock tar/gzip behavior/input bounds, regional date evidence, proposed default keep 5, archive chronology/set identity, consistent eligible log snapshot and required external YAML dependencies. |

## Acceptance cases

IDs identify behavior, **not a required test count**. One meaningful test may cover several cases; use representative integrations and focused realistic failures. Existing tests carrying an ID still need review against this specification. Mark acceptance only with actual evidence and note host/CI/source/live limits; optional unrun live IPv6 remains explicitly provisional.

### Installation, storage, dependencies and shared control

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V01 | absent/read-only/wrong/lost Entware blocks dependent operation without stale writes or resetting intent; native diagnostic/recovery/Off remains available; optional logging failure alone does not block otherwise-ready APIs. |
| [ ] | V02 | target official Merlin models against Entware ABI support and available required packages, retaining GT-AX11000 as baseline and modern routers as targets; record source/firmware/BusyBox/feed/dependency references and concrete exclusions without an obsolete-router obligation; implement fail-closed native capability/TLS admission and test it with representative fixtures on one Ubuntu runner plus native-host vendor BusyBox; exact firmware/ARM/kernel-VM execution is optional during development, with actual model/flash/hooks/TLS/provider qualification explicitly deferred to extended router beta; source/feed presence alone is not verified support; temporary Entware loss retains native recovery rather than excluding the model; no router Python/venv/picker dependency. |
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
| [ ] | V63 | scoped wizard Save supersedes same-field manual edits while preserving unrelated state/guards; no-revision content changes and later Off win; write/guard/package-generation failures are contained honestly; additional safeguards/rechecks require validated conclusions without false positives and must not turn cached readback or a later write into independent durability proof; for qualified firmware hiding JFFS2 flash errors, check every exposed outcome and retain staging/coherent publication/recovery tests, while documenting that hidden-error detection and persistence across restart cannot be certified; no complex raw-flash verifier or disruptive operation is required; the documented exception does not waive ordinary errors or accept unfinished Save. |
| [ ] | V64 | event storms, aggregate budgets, delayed work, unmount/watchdog races, missing TTY/EOF/signals and terminal echo remain bounded and safe. |
| [ ] | V73 | all-feature boot/outage/fault injection proves early hook return, pipe closure, resource admission, no premature work, crash backoff/stability reset, teardown suppression and no reboot/global-restart recovery; hardware proof remains separate. |
| [ ] | V74 | normal installed-opkg missing/unusable dependency repair and selected force reinstall preserve healthy tools/config/intent, coalesce attempts, recheck capabilities and remain bounded on mount/network/interruption failures; no custom IPK bootstrap or blanket upgrade. |
| [ ] | V75 | health/doctor/diagnostic are identical full reports and survive partial installation/missing modules/tools/broken config with native fallback; include basic dashboard plus grouped causes/next actions; eligible locally valid, non-faulted credentials permit bounded read-only checks, otherwise local fallback; no mutations/auth-Off/cache-success writes or false live/write-permission proof; safe narrow/plain terminal output and no secrets. |

### Tunnel setup, credentials, maintenance and updates

| Status | Case | Required evidence |
| --- | --- | --- |
| [ ] | V05 | binary metadata/digest/download/ABI/version/backup/stop failures preserve old usable artifact/runtime and report bounded failure. |
| [ ] | V06 | interruption around binary/manager activation preserves a complete trusted generation, pending identity and protected recovery; shutdown at binary staging/switch/publication/start leaves managed configured-On Cloudflared eligible for immediate automatic verified re-fetch at the first passing storage/tools/NTP/Internet gate, without waiting for its normal update schedule; trusted installed/update evidence detects an invalid owned artifact even without a pending marker; incomplete/corrupt identity is distinguished from outage/auth/config/ordinary startup failure; Off/unconfigured/foreign/unmanaged/removal and maintenance-only Off do not trigger this guard; public Off removes repair eligibility, queued work and exclusively owned hooks/jobs under the existing partial-uninstall boundary, retaining binary/config/recovery data and other features' shared watchdog; no independent repair schedule can re-hook or enable Off; later Off cancels pending repair and wins switch/start rechecks; failed/offline repair remains bounded and guarded; verified replacement preserves settings and needs fresh tunnel readiness before launch. |
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
| [ ] | V60 | Cloudflared binary numeric no-downgrade/force rules and artifact transaction recovery work independently for idle and On cases; Off races win, outage does not falsely condemn candidate, successful rollback still reports failed update; interrupted-update automatic re-fetch is limited to managed configured-On state, permits verified same-version repair despite normal healthy-artifact equal-version skip, preserves no-downgrade/protected-rollback policy, coalesces with updater/watchdog work and retains protected old/staged evidence; S13.13 Warning syslog reports the automatic repair including its verified successful-repair outcome, with truthful failure/deferred reporting without optional file logging, duplicates, secrets or a false connected claim. |
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
| [ ] | V22 | Cloudflared per-file size/total count (including live)/time/age options produce supported effective numbered uncompressed rules, overriding inherited compression settings; no log-compression options or policy fields. Invalid changes preserve policy and display actual Scribe cadence, not hard-cap claims. |
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
| [ ] | V43 | reproducible isolated developer environment, focused/full workflows on one Ubuntu CI runner with required vendor BusyBox evidence, optional nongating kernel diagnostics, explicit deferred real-router beta, runtime package exclusions and accurate sanitized linked usage guides. |
| [ ] | V30 — Conditional only | if external uiScribe support is separately selected, verify owned paths/permissions, bounded viewing/clear/rotate and reinstall durability without requiring a CFMgr WebUI. |
| [ ] | V33 — Optional launcher / conditional updater | supported user-chosen amtm personal slot preserves occupied slots and preferences; any later official callback requires explicit separate opt-in/developer gating and the trusted transaction. |

## Implementation complete and ready for beta

| Status | Required result |
| --- | --- |
| [ ] | All required workflows/subgoals and automated development acceptance are satisfied within the declared beta target scope. |
| [ ] | Cross-feature behavior, storage/boot/update/restore recovery, ownership and credentials have adequate evidence with actual limitations stated. |
| [ ] | Practical installation, operation, repair and removal guides are accurate and usable. |
| [ ] | The completion assessment reflects delivered requirements; optional future WebUI/external integrations and post-completion polish are excluded. |
| [ ] | Deferred real-router/flash/hooks/TLS/provider checks and provisional model support are explicitly documented for extended beta; first-version/beta semantics are coherent and stable qualification awaits appropriate live evidence and a separate release decision. |
