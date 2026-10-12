# CFMgr v2 — current handoff

<!--
Codex Session: 01a12b73-456b-7de0-b3c2-db151518949f
Codex Session: 01a12ca8-2b44-7791-90ab-a1e5b17b3d18
Second ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd; no child IDs are included.
Codex Session: 01a12d2e-4093-74b3-a13a-5be95ceaa965
Third ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a12e40-f76a-7710-9c55-a4b89970cbd2
Fourth ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Review notes](PLAN_V2_review_notes.md) · [Working rules](AGENTS.md)

## Current task and route

**Priority override:** 3D passed in 2m39s and 3C in 47s. User accepts 3C; prioritize
baseline trimming and check for another cheap 20–60s saving in 3D, aiming for about
two minutes per batch. User accepts 3A/3B and provisionally 3E. Rerun changed
groups, then the exact combined full gate before accepting S02.05/S02.08 and
pausing. No runtime writer is active.
Standing amendment recorded in AGENTS: every new Linux-dependent subgoal or
substantial library package needs its own focused Quick batch with runtime review
before the combined full gate; split/optimize slow groups first.
Cancellation of 3D is terminal. Its tests finished during cancellation: **21 passed,
4 deselected in 434.51s**, but cancelled workflow supplies no acceptance. Case
times: failed-update 98.96s, daemon 98.66s, loss 95.73s, installer 139.73s; remaining
tests negligible. CPU 407.11s confirms work rather than a fixed wait/hang. Receipt
`.tmp/quick-3d-cancelled.log`. Current batch target is roughly 3–4 minutes.
Parent reviewed and integrated the released test-only layering refinement in
`tests/fixtures/{dependencies,storage_mounts}.sh`: the three failure cases reuse
the real foreground view-operation adapter, preserving exact nonzero status and
quiet-success validation. Real mounts/keeper/task/loss/cancellation and production
task/FIFO/signal/claim callbacks remain. Fresh/retained complete consumers retain
production per-operation supervision. Worker proof: **20 passed, 20 Linux skips**;
affected ShellCheck, shfmt, shell syntax and whitespace passed. Exact `e128968`
Quick runs passed: 3D `38272259819` **21 passed, 4 deselected, 158.46s** (installer
126.60s; daemon 14.59s; loss 9.04s; failed update 7.44s); 3C `38272292860`
**92 passed, 46.41s**. Logs: `.tmp/quick-3d-layered.log`, `.tmp/quick-3c-adapter.log`.
User accepts 3C and now prefers around two minutes per batch, with a cheap further
20–60s cut to 3D if feasible. Baseline remains first optimization priority.
Both bounded reviews are complete with no code changes. No safe further installer
saving of 20–60s was identified without weakening its full production proof.
Baseline ShellCheck follows the entry's shared imports: full-list local check
passed in 90.77s; four smaller batches took 6.71s but lost source context and
reported SC2034/SC1091, so that split is rejected. Existing CI baseline 101.77s
already meets the roughly two-minute target. Parent will rerun baseline at
`e128968`, then the combined full gate. All workers have released their scopes.
Latest cost direction: after the new baseline, report combined estimate; if near
ten minutes, trim repeated subgoal work while preserving every plan core edge.
Parent is checking whether retained-launch view-operation supervision duplicates
the unchanged full fresh-installer proof. `next_subgoal_review` owns read-only
composition review; no fixture edit yet. Retained config migration, actual repair,
native claim/task/keeper paths, absence message and healthy return must stay intact.
Composition review passed: retained uses the same repair FD mapping; its snapshot
migration and publication follow released repair/post-probes through unchanged
native callbacks. `dependency_fixture` now owns only `tests/fixtures/retained_launch.sh`
to use the foreground view adapter before launch, preserving every existing
assertion. Fresh installer remains complete native integration. Parent will rerun
3E before full acceptance. User requests cheap savings across all groups; reuse
the completed 18-module cost audit and already acceptable cheap group timings.
Parent exclusively owns `tests/fixtures/storage_mounts.sh`: omit the unused
native-file/nested-mount topology from `view_cleanup` only, keeping its complete
rollback/quiescence/busy/foreign/retry assertions and full compatibility/detach
topology in their dedicated cases. This is disjoint from the retained writer;
rerun 3C alongside 3E after focused/static review. No other cost reduction survived
the bounded review without losing distinct proof.
The user now requests all practical trimming followed by the full suite. Both
fixture edits are complete and parent-reviewed; focused tests passed **21 tests,
9 Linux skips** across storage-mount and retained-launch modules. Shell syntax,
shfmt, planning/package and whitespace passed. Source-aware ShellCheck passed for
all shell inputs except the unchanged root entry; full CI retains the complete check.
Baseline confirmation `38273391701` passed at `e128968`: host/statics **105.39s**,
355 passed/26 skipped/4 deselected, full job 2m04. Pre-final-trim combined estimate
was about nine minutes including setup. Quick 3C/3E and then exact full Checks are
the remaining validation route; no full local suite or new product target is due.
User accepts a combined full run around ten minutes or less, then requests a final
concise docs consistency check before pause. Include the existing 3.2 KB
`docs/compatibility.md` (added with S02.09 at `a0fdb2a`) in that review. Keep README
and development guidance short, with no investigation/progress diary in guides.
Reduced coupling coverage is in review notes; no product runtime edits authorized
by this optimization package.

**Latest user direction:** cancel full Checks `38267375410` for excessive duration
(sent at about 12m30s). Diagnose each remaining stage separately through Quick
Checks before another full attempt. No cancellation supplies acceptance. Keep
S02.05/S02.08 unchecked and finish optimization, quick proof and exact full CI
before the agreed final pause. Parent owns stage coverage and publication; the
existing quick workflow currently accepts individual test nodes, not modules.
Cancellation is terminal (15:17:08 UTC); force-cancel raced with completion and
returned already-completed. Host **353 passed, 26 skipped, 3 deselected in 27.41s**;
host/statics total 108.71s. BusyBox reached 18% after 10m40s, then 75% about a minute
later: the early dependency integration block dominates. No final BusyBox pass.
Receipt `.tmp/optimized-full-cancelled.log`.
Next bounded owners: `focused_ci` owns only quick module-group selection/timing
in `tools/test.py`, `tests/test_dev_runners.py`, `.github/workflows/quick-checks.yml`;
`dependency_fixture` owns only the retry consolidation in
`tests/fixtures/{dependencies,storage_mounts}.sh` and `tests/test_dependencies.py`.
No runtime edits. Parent integrates focused/static proof, documents reduced
same-process retry coverage, then runs separate Quick batches for parsers/tools,
native/prerequisites, storage/ownership, and each costly repair consumer. No overlap
or full gate until stage costs are understood and bounded. User now authorizes
separate concurrent manual Quick runs for stage 3, after a separate setup/full-host
baseline check. Five disjoint groups cover all 18 modules: parsers/tools (8),
native/prerequisites/consumer (3), install/package/storage/keeper (5), dependencies
(1), retained launch (1). Manual run concurrency must not cancel sibling groups;
push cancellation stays unchanged. Every job uses one serial pytest invocation.
Both workers have released the package. Quick now supports the separate manual
host baseline and whole-module groups with verbose names, durations and CPU/wall
accounting. Required `dependency_update_failure` proves real failed-update terminal
state/ownership/descriptor/deadline cleanup; old consecutive two-repair retry is
optional. The fast later-retry consumer plus required real fresh/retained successes
provide the remaining retry evidence; the composition limit is in review notes.
No runtime change. Worker focused/static gates passed; parent integration review
passed. Combined focused gate: **60 passed, 15 Linux skips, 4 optional diagnostics
excluded in 4.43s** across runners/dependency/consumer modules; affected statics,
planning/package and whitespace pass. Standing subgroup diagnosis rule
and optional-light-Mac suite interaction rule are now in AGENTS below 26 KB.

**Finish and pause:** the user now explicitly requests completion of **S02.05 and
S02.08**, their focused local and exact full CI gates, commit/push and a refreshed
handoff, then pause. Do not start another target afterward. The latest user rule
adds rapid selected BusyBox diagnostics followed by full CI before CI-dependent
subgoal acceptance or pause. Full local suites still wait for main-goal markers.

Latest steering: optimize the whole existing suite before any new push/pause;
the prior full Checks was cancelled on explicit user instruction for excessive
duration. Parent owns runtime/coverage decisions. The read-only suite audit is
complete; both optimization workers released their files and parent review passed.
Preserve meaningful repair/loss/cancellation/corruption proof, exact full CI and
fresh mutable fixture state. No new product target or additional edge-case suite.
The user explicitly permits dropping or optionalizing costly rare edge variants;
prioritize representative core failures over exhaustive combinations. Cheap tests
need no churn. Record only actual relaxed coverage in the review-notes document.
Full CI including setup must target 10–15 minutes and never exceed 20 minutes,
including at product 100%. This is now a standing AGENTS rule; optimize before
the final pause, measure the required run, and do not increase timeouts to fit bloat.
Plan-specified edge cases remain required. Outside the plan, only cheap useful
additions should be implemented automatically. Document critical residuals covered
by small mitigations in review notes; if no small fix can cover a critical gap,
ping the user and pause affected work under the hard-blocker rule. Goal delivery
and planned tests remain the priority.

User explicitly ordered cancellation of Checks `38262065257` at about 20 minutes;
parent sent cancellation. It supplies no acceptance. Completed optimization package:
`focused_ci` released `tools/test.py`, `tests/test_dev_runners.py`, and
`.github/workflows/checks.yml` (common static checks once, retain BusyBox syntax,
visible timings and 20-minute job limit). `dependency_fixture` released
`tests/fixtures/storage_mounts.sh` and `tests/test_dependencies.py` (omit unused
native-file/nested-mount variants for dependency cases, retain dedicated
compatibility proof; standalone normal-repair wrapper becomes optional because
retry success plus actual installer/retained consumers cover it). Parent owns all
docs, integration/coverage review and the exact quick/full CI gates. No runtime
changes, shared mutable test state, supervisor bypass or deadline reductions.
Cancellation is terminal: host/static passed; BusyBox was cancelled at 14:39:50 UTC.
The whole-suite audit covered all 18 test modules and relevant fixtures. Cheap
parser/config/identity/runner/offline-tool tests remain; real publication,
native/TLS admission, coalescence, corruption/interruption, keeper and storage
failure cases establish distinct required behavior. No other large safely
removable case cluster was found. Parent also replaced duplicate retained-package
construction with the existing immutable package fixture; each test still creates
fresh mutable installed state. No polling/cancellation grace was shortened.
Integrated focused proof: runner/dependency/storage tests **50 passed, 16 Linux
skips, 3 optional diagnostics excluded**; retained tests **14 passed, 1 Linux skip**.
Affected lint/format/compile, shell syntax/ShellCheck/shfmt, YAML, planning/package
and whitespace checks passed. Linux timing and behavior still require quick/full
CI at the new candidate. Runtime code is unchanged from `9e2563d`.
Conditional exception: the user permits a full local diagnostic run if optimization
cannot isolate the remaining cost. Not triggered yet: the cancelled CI host suite
passed 351 tests in 27.81s; Linux-only integration dominates and concrete reductions
are implemented. A macOS run skips those mount cases, so it cannot replace Linux
timing or acceptance proof.

Latest optional diagnostic permission: a known-light full Mac suite taking about
one minute may help optimization or focused-pass/full-suite-fail diagnosis, with
Linux-only skips explicit. CI-dependent Quick Checks followed by full Checks still
apply. It is optional, not a new per-subgoal gate; AGENTS records the rule. Ubuntu's 28s behavioral timing
does not establish total Mac cost, and earlier Mac static gates took longer.

Latest user direction: practical acceptance, no hours-long pursuit of rare edges.
Use judgement to relax incidental test details or defer rare low-risk diagnostics
with a concise review-note entry, without pinging the user. Pursue common
failures; raise a concrete blocker after two unsuccessful focused attempts.
Escalate high-risk unresolved issues; if unanswered, record the question and pause
after 3–5 minutes. AGENTS owns the
two-focused-fixes/~20-minute reassessment rule. Full CI means required acceptance,
with rare mixed-root and dead-leader/thread stress optional. Possible later VPS
testing is not current provisioning/execution authorization.

`focused_ci` released the runner/diagnostic files: 41 focused tests passed and
11 Linux cases skipped locally; parent reviewed the selection/output changes.
AGENTS consolidation is reviewed and below 24 KB, with a 28 KB proactive threshold.
The docs/CI worker owns no remaining files.
Parent owns planning files, package manifest, workflow path filters and integration.
Both runtime and parser workers have completed and released their files. Parent
review passed installed default routing, retained config/package admission, shared
normal repair, post-repair snapshot migration, native storage-loss reporting and
guarded raw-preserving observation publication. Native AWK check/observe/patch
modes use exact generation/change/byte-count receipts and immutable snapshots.
The integrated focused local gate passed: **107 passed, 17 Linux-only skips**;
all planning/package, Ruff/format/compile, shell syntax, ShellCheck and shfmt gates
passed. Command: `.venv/bin/python tools/test.py --focused
tests/test_config_observation.py tests/test_retained_launch.py
tests/test_dependency_consumer.py tests/test_install.py tests/test_prerequisites.py
tests/test_dev_runners.py`; receipt `.tmp/retained-local-focused.log`.
This was focused behavior plus common static checks, not a full local suite.
Parent owns quick BusyBox proof, then full required Checks at the same candidate.
Runtime/parser are committed and pushed; no writer or local test remains active.

Aim for **Goal 2 — Installation and dependencies**, the prerequisite to original
Goal 1. S02.09 is accepted after exact focused CI. Follow the user's order:
smallest independently completable subgoals, then linked module/framework batches,
then remaining main-goal work. The active targets are **S02.05/S02.08**:
real installed-opkg repair and saved storage identity/loss/return behavior.
Finish the integrated normal-repair
consumer below; supporting ownership/resource work belongs to S04.08/S04.09 and
native state parsing may need S04.01. The user was notified before this prerequisite
work. Return to Goal 2; supporting main goals do not all have to finish first.

**3/157 accepted subgoals (1.9%); 0/16 main goals (0%).** Goal 2: 2/9 accepted
(22.2%); Goal 3: 1/10. S02.05/S02.08 are implemented and locally reviewed/tested;
their required Linux/BusyBox acceptance remains pending. Neither earns another
accepted tick until full required Checks passes.

Standing publication/pause, progress and concise-documentation rules are consolidated
in AGENTS.md. Finish only the agreed two-subgoal pause boundary. Completed evidence
belongs in the checklist. The user reiterated the current-/opt mount/read-test and
saved-reference behavior in answer to the repeated storage question; apply that
decision below and do not ask for the same approval again.
Never leave a started library/subgoal half-finished to switch targets. Smallest
standalone subgoals come first on resume; avoid discretionary framework expansion.

## Working tree, refs and last gate

- Current candidate **`f9a0c0b42528de640d30e0897cac8a6ff37877d4`** is committed,
  pushed and remote-verified. Quick `38269823553` checks the runner module;
  manual Quick `38269840050` runs stages 1–2 host baseline. `inventory_ci_wait`
  monitors both. After host success, launch the five disjoint BusyBox groups
  together as explicitly requested; record IDs/timings and do not retry full yet.
  Both passed: host baseline step **1m42s**, runner module subsecond. Parent
  verified SHA and terminal success; receipt `.tmp/quick-host-baseline.log`.
  Five BusyBox groups are now running concurrently at this unchanged candidate:
  **3A** parsers/tools `38270185634`; **3B** native/prerequisites `38270189956`;
  **3C** installation/storage `38270194791`; **3D** dependency repair `38270199354`;
  **3E** retained launch `38270203604`. Exact module map `.tmp/quick-groups.json`
  covers all 18 modules once. `inventory_ci_wait` monitors these only. No writers.
- Candidate **`885dc5c1c15881c634c7420a42301394a7306f5c`** is committed, pushed
  and remote-verified on `develop`. Runtime is unchanged from `9e2563d`; subsequent
  code changes optimize tests/runner/workflows and isolate unit-test environment.
- [Full Checks 38267375410](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38267375410)
  was cancelled on explicit user instruction. Host/static passed in 1m49s;
  BusyBox ran 15:05:15–15:17:08 UTC without a final pass. Full acceptance remains pending.
- [Quick Checks 38267255894](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38267255894)
  passed **3 runner tests in 0.06s**, job 17s; parent verified exact SHA/job.
  Receipt `.tmp/optimized-runner-quick-pass.log`. All 30 runner tests also pass
  locally under each inherited shell environment (`/bin/sh` and `busybox ash`).
- Optimized integration [Quick Checks 38265673929](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38265673929)
  passed at `2085e324f54885305f9849c5ad26e0d926fef492`: **4 tests in 248.95s**.
  Retained repair/return 140.16s (previously 165.50s), real drive loss 99.95s,
  full view compatibility 5.42s, plus runner reuse. Receipt
  `.tmp/optimized-quick-pass.log`. No Linux fixture/runtime changes since that pass.
- The first optimized full run `38266754900` failed only a runner unit assertion:
  inherited outer `CFMGR_TEST_SHELL` bypassed the fake default. Parent reproduced
  it locally and fixed the harness in `885dc5c`; production behavior unchanged.
  All statics passed; BusyBox was skipped. Receipt `.tmp/optimized-full-failed.log`.
- Previous full `38262065257` was cancelled on user instruction after about
  20 minutes. Host behavior passed 351 tests in 27.81s; BusyBox supplied no pass.
  Receipt `.tmp/retained-full-cancelled-cost.log`. No acceptance from cancellation.
- Only parent-owned documentation changes are uncommitted: optional-light-Mac
  diagnosis rule in AGENTS and this handoff. No runtime/test writer or local
  command remains active. No unchecked product target may start before pause.

Earlier candidate/failure chronology is historical and preserved in
`885dc5c:PLAN_V2_handoff.md` and its ignored local log receipts. The section was
consolidated because superseded entries still described old work as active.
Current acceptance is only the checklist; old counts/runs do not award new credit.

## Ownership and implemented boundary

All runtime/test/parser workers have released their files. Parent owns the four
planning files, integration, CI decisions and acceptance. `inventory_ci_wait` only
monitors the current job. No new implementation target is authorized before the
requested pause; S02.04/S02.06 and other independent work wait for resume.

Implemented consumers:

- Fresh `cfmgr.sh --install` shares native admission and prerequisite inventory/
  normal repair, then uses its existing fresh-only publication transaction.
- Installed default `cfmgr.sh` (absolute or relative invocation) dispatches the
  isolated retained-launch controller. Explicit help/source-copy defaults remain
  harmless. A bounded immutable private config snapshot and complete setup/layout
  are checked before repair; full package digests follow healthy SHA admission.
- Shared missing/unusable-only repair uses installed opkg, selected direct packages,
  normal feeds/scripts/resolution, bounded coalescence and fresh post-probes. Healthy
  tools are preserved; resolved failure permits later retry. Unresolved children
  retain contexts/guards and prevent overlap.
- Each operation resolves actual `/opt`. Saved UUID/filesystem/root/relative fields
  are advisory observations, not a drive allowlist. Changed observations use a
  guarded raw-preserving config patch and decimal generation increment; unchanged
  observations do not write JFFS. Settings, history and feature Off states survive.
- Missing/lost storage stops dependent work and emits the bounded native message.
  A later invocation re-admits current storage and performs eligible dependency
  work. No feature setup/activation or interrupted fresh tunnel is resumed.

Parent review integrated post-repair record/snapshot migration, live-old/candidate
hash checks, native logger symlink admission and storage-loss reporting outside
opkg. Failed publication retains recovery evidence. Final guard-removal durability
failure retains RAM evidence; do not invent an automatic recovery/adoption subsystem.

Keep these settled contracts:

- The user reiterated mount/read checks and saved references; no storage question
  remains pending. CFMgr paths are guarded. Normal scripts remain enabled; the
  dynamic-alias limitation is tracked solely in the review-notes document.
- Native source/JFFS/storage pins use FDs 9/8/6/7; context starts at 0. Repair swaps
  source to 0 and preflight context to 9; its claim uses 5. Unresolved return 3
  retains that phase. Resolved return restores source9/context0. Post-probes retain
  original context3/new context0; migration copies config, records and passive
  manifest/catalog snapshots before retiring the old context. Final read loops
  move context0 to5. Keep scratch4 and native flush3 lifetimes separate.
- Native probes have fixed argv, isolated environments, bounded output and one
  tracked direct child. Long opkg work has separate task/deadline state. Never
  overwrite unresolved supervision to run another probe or optional logger.
- The view/keeper own admitted mount references; validate rooted tasks and threads
  before signalling/releasing guards. Ordinary exit with a surviving daemon is not
  quiescence. Unknown ownership retains evidence; normal cleanup is never lazy.
- Host fixtures label firmware/mount adapters. Retained Linux proof uses actual
  repair, migration and later no-op; its absent-volume phase is a pin-adapter
  refusal. Separate real detach/cancellation coverage supplies mount-loss proof.

No normal feature menus, remote package acquisition/update, selected reinstall,
complete native recovery/safe Off, provider activation or general Save workflow is
accepted. Goal 4 foundations earn no separate credit. Detailed prior design and
worker history remain recoverable from `b90eb6e:PLAN_V2_handoff.md`.

## Retained execution/storage design evidence

The private descriptor-bound view and fallback guards are integrated with normal
opkg repair; final acceptance follows the current CI receipt above. Do not assume router cgroups/namespaces
or a new resident daemon; Linux test namespaces only isolate fixtures. Polling
`/opt` alone cannot prevent stale-path writes.

Preserve ordinary installed opkg feeds/dependency resolution/scripts, including
configured local-feed/temp/cache paths and existing unpacked packages. A minimal
view omitting host paths or making all `/tmp` read-only changes that behavior.
Opkg invokes `wget` through PATH; curl admission alone does not qualify transport.
Account for native `/etc`→`/tmp` symlinks, devices/procfs and service IPC. Normal
`dest root /` is valid; Entware patches free-space checks to `/opt`.

The implemented writer supervisor tracks direct PID/start/boot before release and rooted tasks across threads/daemonization;
close outside directory descriptors/cwd. The view hides its controller context, so
handshake needs narrowly admitted FIFO descriptors closed before opkg exec.

**Mount IDs can be reused after final reference release.** Pin every ownership
mount; the unique root alone does not retain detached child binds. Source-reviewed
candidate: one native ash child holds directory references in active recursive
function-redirection frames. ACK only after each open; verify its PID/start/boot
and complete held fdinfo mount-ID set before overmounting. Reserve FD/stack headroom;
EOF, unwind, keeper loss or missing pins closes ownership admission. Release pins
only after quiescence, then never signal from that retired ledger. This ash/Linux contract is implemented and exercised by the keeper and repair fixtures.
Pinned `shell/ash.c` SHA256 `28fcb7d7f9428e44bad4299bffdc7c30c8c83468c479305b60f0c690e57b7b09`
matches cached provenance: `openredirect`, `REDIR_PUSH`, `evalfun`, `popredir`.

Script-created mounts/chroots can escape a static inventory; resolve dynamic or
unknown ownership before launch. Positively identify kernel threads by PF_KTHREAD;
retry transient exits within deadline, never infer live unreadable roots are foreign.
Kernel evidence: Linux v4.1 `fs/namespace.c`, `fs/proc/{base,fd}.c`,
`include/linux/{fs_struct,sched}.h`, `kernel/exit.c`.

Parent-verified ownership refinements: classify pinned non-view mount roots too
(existing Entware chroots need not remain unknown). Transfer an already-open root
FD to the keeper while verifying/pinning visible owned ancestry; never reopen the
pathname. Numeric `kill` affects the threadgroup: require all live threads owned
or separately verified group provenance; mixed/unknown groups remain uncertain.
Boot/start/root rechecks are observational, not atomic signal identity: Linux
4.1.51 `kernel/{pid,signal}.c` allows PID reuse despite proc/root FDs; pinned ash
`dowait` also reaps before builtins/functions. Do not claim delayed shell `wait`
reserves a PID. Empty sweeps still require successful normal unmount for cleanup.

Persistent package-script daemons count as continuing owned work, not direct-exit
success. Bounded cancellation can make repair fail even after opkg exit zero; do not
claim normal service-success compatibility without review. Unknown ownership or
busy normal unmount retains evidence and prevents overlap; never lazy cleanup.
Later recovery requires proved quiescence; a completed ordinary failure must not
permanently latch. External host services requested through IPC are not inherited
owned children. Required representative repair/cancellation proof is part of the current full CI gate.

Concrete Merlin hotplug finding: at pinned firmware source below,
`rc/usb.c` unmounts the device from **all** matching mounts, including private bind
clones. `shared/usb.c:300–328` matches `/proc/mounts` by source or device identity.
Changing source spelling/propagation does not hide the clones. Physical removal
can use `MNT_DETACH`, exposing writable fallback directories before any poll.

A read-only root protects bare `/opt`; canonical volume aliases under mirrored
writable `/tmp` additionally need verified read-only underlays. Guard stacks require
an explicit ledger/inventory mode; do not weaken legacy parser rejection blindly.
Mark the unique root unbindable before recursive ancestor binds to avoid copying
itself; preserve a separate bindable guard source. Do not later clear unbindable
with recursive-private. Ordinary device detach can leave the RO underlay in place,
but `rc/usb.c:1797–1849` calls the user hook then retries path-based unmounts without
revalidating top-device identity: another actor removing the leaf can expose the
guard to a later attempt. Parent verified the pinned hotplug source and accepts the revised construction for
ordinary hotplug. Scope remains the action’s verified owned children: host services
asked to act through IPC are not owned children, and independent root dismantling
of guards is not prevented. CFMgr itself must never remove a busy leaf while writers
survive. These are evidence limits, not restrictions on normal feeds/scripts. Actual
construction/failure/cleanup has representative Linux proof; the integrated writer
consumer is included in the current required CI gate.

Source pins and evidence for that decision:

- Merlin `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` (3004.388.12_2),
  `release/src/router/{rc,shared}/usb.c`. Cached GT-AX11000 embedded kernel config
  SHA256 `b9795f074b019c327b1ea6fe7d29d46f6e716a9d017a8235c648e10c30cf323a`:
  cgroups/namespaces disabled. Native BusyBox 1.25.1, kernel 4.1.51,
  Entware aarch64-k3.10; native id/stat/timeout/setsid absent.
- Reverified native `mount.c` SHA256
  `b6a23a99f6564b332ad5f7ae418b5ffaa1c6afe424eac9a5cf2620ada8144803` under
  `.tmp/firmware-audit/sources/3004.388.12_2/util-linux/`: explicit bind operands
  reach syscall unchanged; pinned `get_devname.c` rewrites only UUID=/LABEL=.
  Descriptor binding still needs execution proof. No firmware/router execution.
- Entware root `36db8558ac7840d993cb11df1e47e0326d681077`; opkg source
  `80503d94e356476250adaf1f669ee955ec26de76`. Root feed references are unpinned;
  supplemental recipes `entware-packages/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd`
  and `rtndev/05d2b0f695b8bc1973a9c88a8f08764c8fcb8271` do not prove installed IPKs.
  Selected recipe simplicity does not constrain all existing unpacked scripts.

## Validation and resume

1. Wait for the current full Checks candidate above; quick proof passed. On a
   concrete failure, inspect its first useful log and repair only the affected
   practical acceptance case, then repeat focused quick/full CI as required.
2. No full local suite is due; the focused local gate already passed.
3. After full required CI and parent acceptance, tick S02.05/S02.08, update concise
   checklist/README counts and this handoff, then commit/push the docs receipt.
4. Verify no required worker/job remains active and pause. Start no further target.

Required development CI is one Ubuntu host/vendor-BusyBox job, not exact firmware
emulation. Real Merlin/ARM/flash/hooks/TLS/provider qualification remains beta work.
Optional guest tooling/caches stay preserved and unaccepted. No new kernel matrix,
installer execution, hardware acceptance or beta deployment is authorized.

Use `.venv` and pinned dependencies. CI ShellCheck is now pinned to local 0.11.0;
older-version annotations remain narrow. Regenerate changed runtime metadata with
`.venv/bin/python tools/package.py --write`, then `--check`.

The suite-wide cost review and optimization are complete at `2085e32`: common
statics now run once; unused dependency topology and duplicate successful-repair
coverage were removed from required CI, with dedicated compatibility and retry/
consumer proof retained. Retained repair/return improved from 165.50s to 140.16s
in the passing quick run (not a controlled CPU benchmark). Current full Checks
reports wall/CPU and slowest-test timings; record that receipt before pause.
Further minute-scale fixture cuts were not justified by the bounded follow-up.

## Permissions, retained evidence and recovery

Standing router boundaries are in AGENTS.md. No live task is pending. Brief read-
only inspection and owned nondestructive scratch tests under `/mnt/MERLIN/tmp` are
allowed; all other router writes/code/packages/services/mounts/deployment need
explicit permission. Prior one-off JFFS permission was consumed; no retry is granted.
The portable router launcher has not been run live. Ignored `tools/router.local.json`
uses KEY/global SSH settings; never publish it or personal router paths/credentials.

Prior USB probe and verified cleanup receipts remain in `.tmp/storage-review/`:
`router-usb-probe-20261012.sh`/`.log` (stream SHA256
`9f7ab9b495a99f4df17809c0c21a7b049dfd93a9bae332d638298a6a93c70f08`).
Consumed JFFS attempt: `router-probe-20261012.sh`/`.log`, SHA256
`2476176c378e11d300be4925b6ccef2c32c533bdc04d0621920a106a71fa939a`;
probe 17489 confirmed absent. USB proof does not establish JFFS durability or Save.
The accepted practical JFFS evidence limit remains in the specification: cached
readback cannot certify kernel-hidden flash failure or persistence across reboot.

Read-only original source: `.tmp/reference-paths.md`; historical patterns:
`.tmp/previous-*-reference.sh`. Firmware/provenance: `.tmp/firmware-audit/INDEX.md`,
`.tmp/platform-review/source-index.json`, `.tmp/storage-review/jffs2-source-provenance.json`.
Verify hashes/scope before reuse; preserve these ignored records. No execute/flash/
delete permission is implied. Prior 14-run failed/cancelled Actions cleanup is done,
receipt `.tmp/actions-cleanup-20261012.json`; do not repeat it or restart old matrices.

Earlier reset salvaged no runtime workflows; old S02.01 credit was withdrawn and
old diagnostic subset did not complete S03.09. Historical test counts earn no
current acceptance. Preserve new partial work instead of repeating that loss.
Verified committed-history bundle: `.tmp/history-before-salvage-e571555.bundle`,
SHA256 `3e5599dcc3c531a1c61edb0c891526c5ebf290e976349c001af3a68918e32365`.
It retains old develop `e571555771abbe128102b2edda69014d37143d24`, old remote
`debba577d43b2b20285d8226615c5e3ef7431ddb`, removed main
`f4b3136762bda6fb2f9c31796338ddc27444a403` and detached-worktree reference.
Local `refs/safety/salvage-before-e571555` also retains develop. **Uncommitted salvage
rewrites were not fully snapshotted and cannot be promised recoverable.**

Recovery, if requested, imports original commits into a separate branch/private
checkout without resetting current work. Keep the bundle, `.old/PLAN.md`, ignored
references and unrelated detached-worktree metadata. Historical reset/main receipts:
`.tmp/salvage-history-receipt.txt`, `.tmp/main-removal-receipt.txt`. Those permissions
are spent; no new reset/deletion is authorized by this record.
