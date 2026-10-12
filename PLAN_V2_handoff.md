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

## Final checkpoint — focused policy CI pending

Final user amendment is being integrated before publication: complete exact-SHA
focused CI groups accept subgoals, including all affected shared foundations.
Full local/CI suites occur only at complete main-goal markers. Rules, specification
and checklist are reconciled. Both workflow edits are released and reviewed:
Quick labels grouped focused proof; full Checks is manual-only. Existing runner
tests passed (32), with workflow YAML/Bash/Python syntax checks. One exact focused
runner CI batch remains before the final receipt; no new full run.
Product acceptance below remains based on the already completed full pass.

The requested **S02.05 normal dependency repair** and **S02.08 storage identity/loss**
are complete and accepted after focused tests, parent review and exact full CI.
The user accepted the **8m09s** combined runtime; stop cost tuning here.
**5/157 accepted (3.2%); 0/16 main goals.** Goal 2: **4/9**; Goal 3: **1/10**.
Accepted IDs: S02.03, S02.05, S02.08, S02.09, S03.01. No main-goal audit/full-local
completion is claimed. No new product package has started. **Resume only on request.**

## Verified checkpoint

- Tested code/test/workflow commit: **`81d2b29fa42374283f3b18d9de37e32f2880628e`**,
  pushed and remote-verified on develop. Runtime is unchanged from `9e2563d`;
  subsequent code changes optimized tests/runners/workflows.
- Exact full [Checks 38274552711](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274552711)
  passed all required jobs/steps. Host: **355 passed, 26 platform skips**, statics
  included, **1m45.42s**. Vendor BusyBox: **380 passed, 1 workstation-only skip**,
  **6m05.86s**. Four optional diagnostics were excluded in each stage. Job including
  setup/cleanup: **8m09s**. Parent verified terminal success and full head SHA.
- Final focused Quick batches at that candidate: [3C 38274342379](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274342379)
  **92 passed, 47.45s**; [3E 38274310684](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274310684)
  **15 passed, 66.23s**, down from 173.54s. Unchanged 3D at `e128968`,
  [38272259819](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38272259819), passed
  **21 tests in 158.46s**, down from the cancelled 434.51s diagnostic. The full gate
  above subsequently proved every required group together at the final candidate.
- Focused implementation gate: **107 passed, 17 Linux skips**, relevant static/
  planning/package checks and review passed; `.tmp/retained-local-focused.log`.
  Final affected storage-mount/retained fixture tests: **21 passed, 9 Linux skips**;
  relevant lint/syntax/format checks passed. No extra full local suite was run:
  this is a subgoal/pause checkpoint, not a complete main-goal marker.
- Full receipt: `.tmp/final-full-checks.log`. Supporting timings:
  `.tmp/quick-{3c,3e}-final.log`, `.tmp/quick-3d-layered.log`,
  `.tmp/quick-host-baseline-confirmed.log`; module map `.tmp/quick-groups.json`.
  Earlier run history is retained at `81d2b29:PLAN_V2_handoff.md`. Cancelled runs
  supply no acceptance.

## Final documentation and work state

README and checklist reflect only accepted progress. Development and compatibility
remain approximately 3 KB each; commands, links and evidence limits were checked.
Compatibility covers router/Merlin targets, not verified hardware support. AGENTS
is approximately 26 KB, below 32 KB. Handoff session IDs, retained design evidence,
permissions and recovery references are preserved. The completed 18-module cost
review and required core edge coverage are retained; actual test composition/
optional diagnostic limits are in [review notes](PLAN_V2_review_notes.md).

All workers released their files; no product work or blocked question remains.
The user-requested workflow policy update needs its focused runner CI, then the
final documentation receipt. Runtime acceptance remains at the full-tested
candidate above; no new full run is due. Publication is authorized: focused checks,
commit/push, focused CI, then documentation receipt and verified clean refs. Before new work,
verify `git status --short` and `git rev-parse HEAD origin/develop`; if receipt
publication was interrupted, finish that boundary first. No destructive cleanup,
new target or router action is authorized by this record.

AGENTS owns standing routes: focused local work commits/continues; required Linux
proof uses small repair selections followed by all applicable grouped focused CI;
full local and full CI suites occur only at complete main-goal markers. Aim for
two minutes or less per focused batch, with three to four minutes as the practical
upper range where feasible; preserve every plan core edge. The user accepted
current full-suite cost; do not reopen optimization
without new evidence. Keep guides concise and leave session/issue notes out of the
checklist and README.
At complete project 100%, the latest user target is roughly **40 minutes maximum**
for the full suite including setup, replacing the earlier 10–15/20-minute ceiling.
Current full workflow timeout remains 20 minutes; increase only as measured,
necessary coverage grows, never beyond 40 minutes. Current eight-minute cost is accepted.

## Ownership and implemented boundary

All runtime/test/parser workers have released their files. Parent owns the four
planning files, integration, CI decisions and acceptance. All delegated work and
CI monitoring are complete. No new implementation target is authorized during the
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
opkg repair; acceptance is established by the exact full CI receipt above. Do not assume router cgroups/namespaces
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
  Descriptor binding has representative vendor-BusyBox/Linux proof, not firmware/router execution.
- Entware root `36db8558ac7840d993cb11df1e47e0326d681077`; opkg source
  `80503d94e356476250adaf1f669ee955ec26de76`. Root feed references are unpinned;
  supplemental recipes `entware-packages/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd`
  and `rtndev/05d2b0f695b8bc1973a9c88a8f08764c8fcb8271` do not prove installed IPKs.
  Selected recipe simplicity does not constrain all existing unpacked scripts.

## Next-session boundaries

Resume only when the user requests it. Follow smallest independently completable
subgoals first, then shared-module batches, then remaining main-goal work. Finish
started libraries/subgoals before switching; inspect existing consumers, tests and
checklist before choosing the next smallest item. Return toward Goal 2, originally
a prerequisite for Goal 1; S04.01/S04.08/S04.09 foundations earn no extra ticks.
No next package has been selected or started. Full local suites remain main-goal
gates. Required development CI is Ubuntu/vendor BusyBox; exact firmware/ARM/flash/
hooks/provider qualification remains separately authorized beta work.

Use the existing `.venv` and pinned dependencies. ShellCheck is pinned to 0.11.0.
Regenerate changed runtime metadata with `.venv/bin/python tools/package.py --write`,
then `--check`. Preserve optional guest tooling/caches as unaccepted diagnostics.

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
