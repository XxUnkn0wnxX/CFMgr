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
Goal 1. Current S02.05/S02.08 work covers safe normal-opkg repair and storage.
Goal 3 contributes accepted S03.01; Goal 4 S04.01/S04.07–S04.09 may supply parsing,
guards, ownership and resource bounds. Notify the user before an actual cross-goal
switch and record its consumer/return path. Dependency-first ordering is authorized.

**2/157 accepted subgoals (1.3%); 0/16 main goals (0%).** Goal 2: 1/9 accepted;
Goal 3: 1/10. No additional complete subgoal awaits CI. Partial storage/inventory
proof earns no complete subgoal. The checklist owns accepted IDs, results and gates.

AGENTS.md owns publication/pause and documentation rules. Ordinary local proof ends
in a reviewed local commit, then work continues. Required unavailable focused proof
authorizes an automatic focused push and exact green CI before further implementation.
Full suites belong only to complete main-goal markers. An explicit pause after
substantial work requires completing that subgoal, focused tests/commit/push/green
CI and a session-ready handoff; a barely-started owned attempt may be scoped back to
HEAD without losing unrelated work. No pause is currently requested.

Keep development notes to essential tools/setup/check commands until the final
100% readiness stage. Keep accepted evidence in the checklist and update README
subgoal status at validated gates. Trim completed narrative here; audit source and
receipts if uncertain. No pending scope-approval question exists.

## Working tree, refs and last gate

- Branch: `develop`. Last inspected local HEAD:
  `d5c1597a68272db0198420a10291836d4381392e` (local documentation-policy commit).
  Last verified published documentation receipt:
  `67f0283e13024046d7746bafc36cb6d744204e9b`. Verify refs/status on resume; later
  documentation commits do not change the tested runtime below.
- Current parent-owned edits: developer-note reduction, matching S16.03 wording,
  consolidated AGENTS rules and this handoff reduction. Validate planning/links/
  whitespace and commit locally; no docs-only push is due.
- Latest runtime: `423dd14a5b35c295f07aed0d9e1225a10a8a15df`, exact
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
- No CI, shell test or router job is active. No router action occurred in this
  package. Architecture review is complete; no agent is active.

## Ownership and next package

| Owner | Exclusive scope | Gate / stop condition |
| --- | --- | --- |
| Parent | Three plans, architecture, integration, metadata | Resolve execution-view compatibility/storage risks before assigning construction or opkg launch. Preserve approved normal opkg semantics. |
| `execution_view_review` deep, completed | Read-only S02.05/S02.08 architecture review | Revised guarded view is viable for ordinary hotplug; concurrent root unmount and external-service ownership boundaries need the parent decision below. No edits/tests/router actions. |

All workers released their files. Inspect live threads on resume before assigning
another writer. No execution-root or opkg-writer
implementation is underway. Before delegation record exclusive files, entry/consumer,
interfaces, missing behavior and focused checks. Reuse existing privileged fixture
rather than creating a duplicate harness. Parent owns acceptance and publications.

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

The candidate is a private chroot view with descriptor-bound Entware and native
path compatibility. It is **not implemented or qualified**. Do not assume cgroups,
mount namespaces or a new resident daemon on the router. Native Linux test namespaces
isolate fixtures only. Polling `/opt` cannot prevent stale-path writes by itself.

Preserve ordinary installed opkg feeds/dependency resolution/scripts, including
configured local-feed/temp/cache paths and existing unpacked packages. A minimal
view omitting host paths or making all `/tmp` read-only changes that behavior.
Opkg invokes `wget` through PATH; curl admission alone does not qualify transport.
Account for native `/etc`→`/tmp` symlinks, devices/procfs and service IPC. Normal
`dest root /` is valid; Entware patches free-space checks to `/opt`.

Proposed ownership: direct PID/start/boot handshake, then tasks rooted in owned
root/mounts across fork/exec/daemonization/nested roots and surviving threads;
close inherited outside descriptors/cwd. Storage loss/deadline cancels only verified
owned tasks with bounded TERM/KILL/reaping. Persistent/uncertain ownership or busy
normal unmount retains guard/root evidence; no lazy cleanup or replacement overlap.
Opkg exit alone does not prove quiescence. A later invocation recovers only verified
quiescent state; ordinary completed failure must not create a permanent failure latch.
Host services spawned through IPC do not inherit the chroot; establish that boundary
without pretending it owns arbitrary host daemon work.

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
guard to a later attempt. The completed review finds the revised construction viable for ordinary hotplug;
parent must resolve or state this concrete concurrency boundary before implementation. No containment success is claimed.

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

1. Verify refs/status and collect the architecture review. Finish documentation-only
   correction with planning/link/whitespace checks and a local commit.
2. Settle the bounded execution/storage design, then record and delegate its actual
   implementation/consumer/fixture package. Any necessary product restriction needs
   a concrete proposal and approval first; implementation refinements do not.
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
