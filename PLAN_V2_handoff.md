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

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Working rules](AGENTS.md)

## Current task and route

Continue until **one complete main goal**, then audit/full local/exact full CI,
update acceptance/README/handoff and pause. The earlier pause-every-subgoal override
was revoked. Recent workflow/doc corrections were not pause requests.

Aim for **Goal 2 — Installation and dependencies**, the prerequisite to original
Goal 1. S02.05/S02.08 keeper validation passed; apply
the user's order: smallest independently completable subgoals first, linked
module/framework batches second, remaining main-goal work last. Read-only closure
mapping selected **S02.09 capability-based support** as the next smallest independent
Goal 2 target. Enforce native capabilities/TLS/ABI through installer admission;
source/profile metadata alone is not completion. Keeper/storage is a necessary
repair prerequisite, not a completed subgoal. The eventual S02.05 batch must include
the normal-opkg consumer, healthy no-op, missing/unusable selection, post-probes and
bounded later retry, with focused workflow paths and complete acceptance gates.
Goal 3 contributes accepted S03.01; Goal 4 S04.01/S04.07–S04.09 may supply parsing,
guards, ownership and resource bounds. Notify the user before an actual cross-goal
switch and record its consumer/return path. Dependency-first ordering is authorized.

**2/157 accepted subgoals (1.3%); 0/16 main goals (0%).** Goal 2: 1/9 accepted;
Goal 3: 1/10. No additional complete subgoal awaits CI. Partial storage/inventory
proof earns no complete subgoal. The checklist owns accepted IDs, results and gates.

Standing publication/pause, progress and concise-documentation rules are consolidated
in AGENTS.md. The current work is authorized to continue; no pause or unanswered
scope-approval question is pending. Completed evidence belongs in the checklist.

## Working tree, refs and last gate

- Branch: `develop`; local/remote verified at runtime `a7fe16ce2503cf34920efe5034a22d319e54f948`.
  [Checks 38216515648](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38216515648)
  passed all required steps: host 135/21 skips, vendor 155/1 workstation-only skip;
  job 94s, vendor behavior 50.90s. Keeper lifetime and real mount failure cases passed.
  Receipts `.tmp/mount-keeper-ci.{json,log}`. No new subgoal acceptance; S02.09 is next.
- Previous documentation receipt:
  `f0f35a0a5c339ffa669987b43a68ff2b687aafd0`; tested guarded-view runtime is
  `ad28a3abf4ced1f74a8bcf42b89e9ba4994704b0`. Exact
  [Checks 38211199161](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38211199161)
  passed host 111/11 skips and vendor BusyBox 122/0 skips, including all eight real
  mount cases. All required steps passed; job 62s, BusyBox behavior 22.84s.
  Receipts: `.tmp/execution-view-ci.{json,log}`. README/checklist receipt is committed;
  it does not claim its own runtime test SHA.
- Guarded-view package is implemented and parent-reviewed. Combined local command
  below passed **103 tests,
  19 platform skips**, pytest 32.73s; all statics/planning/package checks passed.
  Receipt: `.tmp/execution-view-focused.log`. Fixture corrections passed 7/8 skips
  plus statics; `.tmp/execution-view-applet-fix-local.log`. Native fixture rebuild
  is cached. Cost remains proportionate; no extra full measurement run is required.
  Acceptance counts are unchanged; supervision and the real repair consumer remain.
- Prior storage runtime: `423dd14a5b35c295f07aed0d9e1225a10a8a15df`, exact
  [Checks 38206169856](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38206169856)
  green. Selection: `test_mountinfo.py`, `test_storage.py`, `test_storage_mounts.py`,
  `test_install.py`. Host 65 passed/8 skips; vendor BusyBox 73 passed/0 skips,
  including all five real ext4 cases. Statics/planning passed; job 48 seconds.
  Receipts: `.tmp/storage-mount-ci.json` and `.log`.
- Combined local gate: `.venv/bin/python tools/test.py --focused tests/test_mountinfo.py tests/test_storage.py tests/test_storage_mounts.py tests/test_install.py`
  returned 57 passed/16 platform-mode skips, 48.01s, all statics passed;
  `.tmp/storage-mount-focused.log`. Subsequent fixture-only portable lint correction
  passed 2 guards/5 explicit skips plus statics; `.tmp/storage-mount-ci-fix-local.log`.
- Inventory/routing proof and S02.03/S03.01 full-baseline evidence are in the
  checklist. Receipts remain `.tmp/prerequisite-inventory-ci.{json,log}`,
  `.tmp/s03-01-focused.log`, `.tmp/s03-01-existing-ci.log` and
  `.tmp/platform-review/s02-03-ubuntu-{run.json,ci.log}`. Historical failures were
  corrected before their green runs; retained logs are diagnostic history only.
- Current keeper combined gate passed: `.venv/bin/python tools/test.py --focused tests/test_mount_keeper.py tests/test_mountinfo.py tests/test_storage.py tests/test_storage_mounts.py tests/test_install.py tests/test_platforms.py` — **104 passed, 28 platform skips**, 51.29s, all statics/planning/package checks green on the dirty tree based on `f0f35a0`; `.tmp/mount-keeper-focused.log`. Parent review fixed a fixture literal-quoting warning. Exact focused CI is next; no main-goal/full-suite gate is due. Cost review: prior view CI job 62s; new Linux failure/deadline cases and one fixture applet rebuild are necessary proof, not duplicate full runs.
- Final fixture review corrected swallowed fixture-definition quoting and an unset CPU-budget value before push. Portable fixture construction/shell syntax now runs despite Linux skips. `tools/test.py --focused tests/test_mount_keeper.py` passed 2/9 skips, 0.26s, including all statics; `.tmp/mount-keeper-fixture-fix-local.log`. Runtime bytes remain those from local `92ad1c1`; both commits will use one focused CI push.
- Keeper candidate `8b99d0bb62bf115812f625ae401eee17f6593c03` is pushed/remote-verified. [Focused Checks 38215534245](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38215534245) failed vendor checks (126 passed/7 failed); host/static passed. Receipts `.tmp/mount-keeper-ci-failed.{json,log}`. Parent verified three causes: native `ASH_CMDCMD=n` rejects `command -v` (use unconditional `type`); pinned ash ignores `-n` on `-c` (parse a script file); normal vanished-proc identity reads need quiet failure. Rollback fixture now proves the injected bind7 branch was reached. Correction gate `tools/test.py --focused tests/test_mount_keeper.py tests/test_prerequisites.py tests/test_storage_mounts.py`: **29 passed/20 skips**, 5.16s plus statics; `.tmp/mount-keeper-compat-local.log`. Re-push with prerequisite tests added to focused selection; await exact green before implementation. No router action occurred.

## Ownership and next package

| Owner | Exclusive scope | Gate / stop condition |
| --- | --- | --- |
| Parent | Three plans, architecture, integration, metadata and CI config | Review mount-reference lifetime and descriptor contracts; add only source-qualified MKNOD fixture applet. No acceptance for a helper alone. |
| `opkg_supervision_review` analyst | Completed read-only ownership review | Keeper, dynamic roots, mixed threadgroups and numeric-signal evidence limits recorded below; no implementation. |
| `inventory_ci_wait` awaiter | Completed exact repaired-run monitoring | Checks 38216515648 green; no active job. |
| `prerequisite_inventory` worker_strong | Completed implementation and bounded review | Files released; parent owns corrected runtime/fixtures and final CI integration. |
| `next_subgoal_review` explorer | Completed read-only closure map | S02.09 is next independent target. Later linked batch: S02.04/.05/.06/.08, requiring tunnel DNS, confirmed reinstall, saved identity and return-eligibility consumers as well as repair. |

Consumer route: future installed-opkg repair from the existing installer/prerequisite
controller, using already admitted storage FDs 6/7. This package deliberately stops
before writer launch/supervision, so it remains partial. Preserve existing parser
interfaces; add explicit inventory support for verified owned stacks. Reuse the
real ext4 fixture. Focused gate: mountinfo, storage, storage_mounts, install and platforms modules;
Linux mount cases require focused CI. Parent owns workflow requirements and metadata.
All other workers finished and released files; filesystem architecture review is integrated.
Parent added matching-native BusyBox CHROOT/LN fixture applets for the actual view tests;
cache identity already includes this config. No new APT requirement or full run is needed.

Next package retains every owned mount before it is overlaid, using one ash child
with active function-redirection frames. Fixed FIFO requests use native `mknod ... p`
(pinned source verified); Linux O_RDWR FIFO opens do not block. Parent FD3 owns the
channel; scoped function redirection borrows/restores FD4 while transferring its
already-open mount reference. Verify incremental ACK plus complete held mount IDs,
PID/start/boot and resource headroom. Parent loss/EOF must not silently unwind pins.
Release only after independently proved quiescence, then normal view unmount.
Focused tests add `test_mount_keeper.py` to storage/view coverage; Linux proof needs CI.
Keeper implementation is reviewed and focused-local/CI-passed, with no complete
subgoal credit. No worker remains active.
Pinned ash `shellexec` calls `clearredir(drop=1)`, closing saved redirection copies
before external exec; verify that behavior in the vendor fixture. Current review
fixes cover glob-disabled callers, canonical numeric protocol, uncertain-release
lockout, malformed/EOF retention and fixture-child cleanup.

After keeper integration, production native-operation wiring belongs in
`prerequisites.sh`, `helpers/probe.sh`, bootstrap and explicit entry imports.
Reuse raw `cfmgr_prerequisites_run`, not flock-owning `check`; zero means reaped,
so inspect command exit separately. Add finite mode argc/forwarding, serial output
names and justified bounds. Preserve single-child supervision: no copied `ls|awk`
pipeline or non-exec AWK wrapper. Pass globals explicitly across env-i; do not
recursively run view checks inside the probe attachment callback. Native cleanup
needs its own admitted context policy after Entware loss, and flat bootstrap cleanup
must preserve view/FIFO/keeper state until proved releasable. Source helpers on a
lost Entware source are not automatically available merely because native tools are.

## Implemented foundation and remaining consumer gaps

- `cfmgr.sh --install` → `cfmgr_bootstrap_native_work` → prerequisite checks and
  bootstrap transaction. It accepts a trusted complete local package, verifies
  root/JFFS2/script support, actual mounted ext2/3/4 Entware identity/UUID, tools,
  private paths/free space and manifest/catalog. It creates private passive config
  and publishes entry/completion last. Retained/corrupt/interrupted setup is preserved.
- Shared prerequisite inventory retains its 15-argument API, aggregates ordinary
  missing/unusable mapped tools and admits fallback flock only after native failure.
  Unsafe paths/storage/supervisor ownership remain fatal. Fresh private check/recheck
  contexts preserve evidence. There is still no normal opkg repair consumer.
- `cfmgr_storage_pin`/`cfmgr_storage_attached` hold/recheck FDs 6/7, mount IDs,
  canonical alias, filesystem root and UUID. Real ext4 CI now covers attachment,
  alias substitution, lazy detach/replacement, bind-root identity, RO/noexec and
  descriptor lifetime. **Saved identity comparison, returning-work eligibility and
  owned-writer containment remain missing.** Boolean adapters alone are not proof.
- `mountinfo.awk subtree-v1 TARGET INPUT` validates all bounded input before output;
  returns the legacy nine fields plus propagation for target/subtree, rejecting
  unexpected stacked points and conflicting unbindable tags. Legacy interface stays
  unchanged. New inventory mode has no production execution-view consumer yet.
- S02.04 tunnel DNS is only `dig -v`, with no real readiness consumer. S02.05 still
  needs installed-opkg admission, serialized bounded repair, healthy no-op, post-
  probes and bounded later-launch retry. S02.06 reinstall, S02.07 native recovery/
  safe Off and S02.09 capability/TLS/ABI admission remain unfinished.
- No remote package acquisition, menus/features/provider activation, retained
  recovery/update or Save exists. Defaults and helper proof do not complete goals.

Runtime descriptor contracts: source 9, JFFS 8, mount 6, Entware 7; context uses 0
then moves to 5 after flock probes before manifest loops. Do not collide with this
when designing execution-root descriptors. Short native waits use `/bin/usleep`.
The existing 2-second single-child prerequisite supervisor/output limit is unsuitable
for normal opkg/script trees and package writes. Extend coherently; do not blindly reuse.

## Unresolved execution/storage design

The private descriptor-bound view with read-only fallback guards is **focused local/CI
tested, but not integrated with opkg**. Do not assume router cgroups/namespaces
or a new resident daemon; Linux test namespaces only isolate fixtures. Polling
`/opt` alone cannot prevent stale-path writes.

Preserve ordinary installed opkg feeds/dependency resolution/scripts, including
configured local-feed/temp/cache paths and existing unpacked packages. A minimal
view omitting host paths or making all `/tmp` read-only changes that behavior.
Opkg invokes `wget` through PATH; curl admission alone does not qualify transport.
Account for native `/etc`→`/tmp` symlinks, devices/procfs and service IPC. Normal
`dest root /` is valid; Entware patches free-space checks to `/opt`.

Writer supervision remains unresolved and is outside this construction package.
Track direct PID/start/boot before release and rooted tasks across threads/daemonization;
close outside directory descriptors/cwd. The view hides its controller context, so
handshake needs narrowly admitted FIFO descriptors closed before opkg exec.

**Mount IDs can be reused after final reference release.** Pin every ownership
mount; the unique root alone does not retain detached child binds. Source-reviewed
candidate: one native ash child holds directory references in active recursive
function-redirection frames. ACK only after each open; verify its PID/start/boot
and complete held fdinfo mount-ID set before overmounting. Reserve FD/stack headroom;
EOF, unwind, keeper loss or missing pins closes ownership admission. Release pins
only after quiescence, then never signal from that retired ledger. This is an
ash/Linux contract, still needing implementation and focused execution proof.
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
owned children. No supervisor/repair success or scope restriction is yet approved.

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
construction/failure/cleanup now has representative Linux proof; owned-writer
containment is still unimplemented and unclaimed.

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

1. Verify refs/status and retain the green guarded-view evidence above. Local command:
   `.venv/bin/python tools/test.py --focused tests/test_mountinfo.py tests/test_storage.py tests/test_storage_mounts.py tests/test_install.py tests/test_platforms.py`.
2. Integrate the ownership review into the mount-reference keeper and supervised
   writer launch, then the real repair consumer. Native config has MKNOD, not MKFIFO;
   verify its FIFO mode before using it. No consumer may infer ownership from a
   mount-ID ledger after those mount references are released.
   Any necessary product restriction needs a concrete proposal and approval first.
3. Run focused local/statics, parent-review, commit. Required Linux/BusyBox proof
   uses the focused CI route in AGENTS, then wait for exact green before advancing.
   No full run or main-goal tick is due now. Update checklist/README gate status.
4. Continue Goal 2 or recorded prerequisites until the full main-goal boundary.

Required development CI is one Ubuntu host/vendor-BusyBox job, not exact firmware
emulation. Real Merlin/ARM/flash/hooks/TLS/provider qualification remains beta work.
Optional guest tooling/caches stay preserved and unaccepted. No new kernel matrix,
installer execution, hardware acceptance or beta deployment is authorized.

Use `.venv` and pinned dependencies. Local ShellCheck 0.11.0 differs from Ubuntu:
portable explicit conditions avoid SC2015; intentional Linux `-ef` fixture checks
have narrow SC3013 annotations. Package metadata regeneration after runtime edits:
`.venv/bin/python tools/package.py --write`, then `--check`. Cost review uses existing
48-second warm CI and local timings, not extra full measurement runs.

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
