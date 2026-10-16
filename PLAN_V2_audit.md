# CFMgr v2 — audit record

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Current handoff](PLAN_V2_handoff.md) · [Review notes](PLAN_V2_review_notes.md) · [Working rules](AGENTS.md)

This record owns substantive audit findings, their evidence, recorded review
agreement or user decisions, and repair dispositions linked to existing subgoals.
The checklist remains authoritative for acceptance; the handoff owns current work,
permissions, jobs, next actions and session lineage. Deferred risks remain in the
review notes. This record creates no requirements, product credit or permissions.

## Migration provenance

At the user's request on 2026-10-16, historical audit and source-review passages
were moved from `PLAN_V2_handoff.md` at
`8e6b79ffa8d2697c4232d3b978e13eea1517e23b` into this tracked root-level companion.
The report bodies below preserve the recorded evidence and conclusions. This
relocation is not a new acceptance audit, a fresh firmware verification or
retroactive joint sign-off. Review agreement is claimed only where recorded;
unrecorded details remain unverified. Historical pending work and ownership in
quoted records describe their original stage and grant no current authority.

The complete original is preserved privately at
`.tmp/diagnostics-audit-20261016/PLAN_V2_handoff.before.md` and in the source commit.
Current scope and results are linked from the handoff; historical source evidence
retains its own revision and platform limits.

Parent and independent read-only migration reviewer verified all 20 relocated
passages and links on the prepared tree based on `8e6b79f`. The session ledger,
next-session and permissions/recovery tail are unchanged; all 36 historical CI
run links remain in the handoff. This is preservation review, not runtime
acceptance. Planning/link/privacy and whitespace checks passed.

## Diagnostics fixture optimization review

2026-10-16, baseline `8e6b79f`: parent and dedicated read-only Astra reviewer
agreed **PASS WITH NOTES** on reusing the existing foreground view-operation
adapter for optional retry, thread and mixed-root cases. The unchanged repair
reference and fresh-installer consumer retain per-command native supervision.
The three layered cases continue to execute real mounts, worker/keeper/task
supervision, ownership/refusal/recovery and every existing assertion. They no
longer independently prove per-view-command deadline/unresolved-child accounting.
Production code, deadlines and the full installed-flock post-probe stay unchanged.

The reviewed implementation at `565e8dfa9af66fad2679052dd88cf40939a0abc0`
changes only the three fixture case selectors and their explanatory comment.
Separate Quick runs passed for threads (13.33s), mixed roots (10.67s), retry
(25.65s), and the unchanged full-supervision reference (82.17s). Earlier times
were about 87s, 88.15s, 165s and 87s respectively; the unchanged reference's
variation is not credited to the optimization. Mixed-root user+system CPU fell
from 78.47s to 8.37s. All assertions, including the distinct ownership/refusal
and fresh installed-flock checks, remain intact.

**Finding:** repeated per-view-operation supervision was the demonstrated main
cost in the three changed scenarios; no hang or new runtime failure was observed.
The fully supervised reference fits the two-minute group target and remains
unchanged. No further probe removal or broad redesign is justified by these
results. This changes the layering of optional S02.05/S02.08 evidence, not product
requirements or completion credit. Parent verified the final two-line fixture
diff, all four exact-candidate Quick passes and successful required core CI
`38843069635`. No new product acceptance was awarded. Exact receipts are recorded in the
[handoff](PLAN_V2_handoff.md#named-quick-results).

## CI core integration cost review

2026-10-16; required core at `36199d6`, compared with `41e1765`; parent and read-only cost explorer.

The read-only cost review found no demonstrated cheap duplicate in the two largest
core cases. Installer integration performs actual repair/full probes/guard cleanup
and per-file supervised publication; retained integration already shares setup
across distinct repair, absent/returned storage, DNS outage and explicit force
paths. Cheaper adapted/component tests do not replace their actual integration
proof. A future bounded investigation can add fixture-only phase timings and use
those two named Quick nodes before changing anything. No runtime/test coverage
was cut for an unmeasured saving.

## S02.08 repair task-root review

2026-10-16; repaired runtime `1d892a4`; parent and independent ownership/source review; full grouped receipts remain in the handoff.

CI also exposed an existing process-disappearance race in the copy-signal test
observer and a concrete fatal-open path in native task-root inspection. The
observer now tolerates only expected gone-process errors while retaining its
identity/deadline/signal assertions. Task-root opening now returns to the existing
bounded complete-snapshot retry if a process disappears; FD4 and caller stdin
remain correctly handled. One deterministic regression failed before that fix.
The earlier loss-run log did not identify the exact vanished task, so attributing
that run to this fatal-open path remains an inference.

## Accepted subgoals audit

2026-10-16; nine accepted IDs at the audit boundary, with S02.08 reopened then repaired at `1d892a4`. Scope reviewers covered defaults/status/settings, repair/storage and foundations-first bookkeeping; parent verified the recorded remote gates. This is the historical audit receipt, not a fresh audit of the migration revision.

The audit inspected all nine previously accepted IDs and verified all 20 recorded
acceptance runs against their exact SHAs and required jobs. Eight existing ticks
were supported; the missing fresh-install report caused S02.08 to be reopened
and repaired here. The prior premature S16.02/S16.04 documentation work had
already been reversed; those IDs remain unchecked. No helper-only credit or
unearned main-goal/Goal 4 tick was added. The records support dependency-ready,
foundations-first cross-goal delivery, without claiming every past size estimate
was optimal.

## S07.01 native storage source review

2026-10-14; S07.01 design from baseline `fd1ea8a`; native-source exploration and parent verification. Runtime acceptance later used `5765848`.

Native storage design evidence was refreshed against retained source/provenance
and the official Merlin Addons API, User scripts and Custom config files guidance.
This package keeps the existing private add-on configuration; no firmware service
config, shared custom settings or hooks are added. All three retained image
inventories contain native flock/fsync and OpenSSL. Pinned 3004/3006 flock source
supports inherited numeric descriptors, nonblocking exclusion and contention
exit 1. Existing prerequisite tests exercise that interface. The retained fsync
source can print syscall failure on stderr while returning zero, so both status
and stderr remain mandatory checks. Retained mv can copy/remove after EXDEV;
the Save candidate and destination must remain on the same pinned filesystem.
JFFS2 can discard internal flash-flush errors as already documented in the plan;
cached readback does not prove reboot persistence. OpenSSL digest support is
not established by its existing CA parser admission: the new native digest mode
needs a known-vector check and strict bounded output framing before use. No
firmware image or router code was executed for this evidence refresh.

## S07.01 smallest-task scope review

2026-10-14; task-selection review before S07.01 implementation; existing product IDs and requirements unchanged.

The prior Astra scope audit confirmed this is the next smallest demonstrated full
subgoal. S03.08 still needs production history writers; S03.10 covers both status
and the absent full-health consumer. No independent shortcut is selected.

## S07.01 native store review findings

2026-10-14; draft findings and corrections at the exact blob IDs below. The recorded analyst result is preserved; final Linux receipts belong to the handoff.

Early read-only analyst review of the first native-store draft found premature
retired-journal cleanup and three branches that collapsed unresolved ownership
into ordinary failure. Parent verified and returned both for correction and
regression proof. The final runtime review confirms both corrected, and reviewed
Store/probe/supervisor blobs `8b95450`/`250401b`/`ae70b46` and launch `37aaed8`
without another runtime blocker. It required actual borrowed-observation lock
proof because earlier fixtures bypassed that helper. Added test blob `9064cf2`
closes that review finding: Linux executes the real helper/wrapper, FD5/8/9 and
mountinfo checks, native/admitted Entware flock branches, release and recovery
crossguard; the host contention test also uses the real helper. Analyst result
is PASS WITH NOTES: firmware roots/tool admission and the publication body are
adapted, so this is shared-lock integration proof, not router qualification.

## S07.01 BusyBox ash lock review

2026-10-14; diagnosis following `4b00501`, reviewed repair subsequently published at `5765848`. Worker assignments and pending-gate wording below describe that historical stage only.

Fresh retrieval of the exact CI baseline ash source at commit
`433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` matches retained source SHA-256
`28fcb7d7f9428e44bad4299bffdc7c30c8c83468c479305b60f0c690e57b7b09`.
It resets background FD0 to `/dev/null` before applying redirections and skips
the existing same-descriptor `0<&0` operation. Source evidence is retained at
`.tmp/s0701-ash-baseline.c`; it was not executed.

Parent and Astra audited the narrow fix (PASS WITH NOTES): call a tiny ordinary
launch function with scoped `9<&0`, then give its direct async child `0<&9 9<&-`.
The shell restores the parent's support FD9 when the function returns, before
identity/attachment checks. FD6/7 storage pins and FD8 snapshot behavior stay
intact; no helper consumes FD9. Handle bridge-call/redirection failure before
supervision. Strong now owns this fix in `prerequisites.sh` plus the Linux child
fixture's FD0/closed-FD9 assertions. The three real Linux cases remain the first
diagnostic gate, followed by complete A–F at the final candidate. No acceptance
or scope change follows merely from the source explanation.

## S03.07 smallest-task scope review

2026-10-14; all-157-row task-selection review from baseline `2e68bda`; completed status consumer evidence remains in the handoff/checklist.

The Astra smallest-task audit scanned all 157 rows and returned PASS WITH NOTES:
S03.07 is the smallest demonstrated ready full product outcome. Missing provider
writers do not block its read-only consumer; the plan permits absent evidence.

## S03.07 reader and native source review

2026-10-14; approved reader design, source explorer and parent verification; exact source pins below are retained.

Parent-approved reader design: project a bounded snapshot of existing private
config only; no new history file/writer. Optional `history.<feature>.status`
and `history.network.status` envelopes carry typed schema/generation/timestamps,
family outcomes, allowlisted reasons and at most five events. Family publication
records stay historical. A current runtime observation additionally needs explicit
runtime origin, matching boot/config generation and bounded nonfuture age;
restored/absent-origin evidence cannot establish current connectivity. Network
freshness also binds the selected WAN. Unknown/raw fields are never printed.

Native evidence: retained cache source/image facts were checked by
`status_native_evidence` (completed); parent additionally fetched pinned Merlin
revision `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` source into ignored
`.tmp/s0307-source/` and matched each Git blob SHA against GitHub's contents API:
`rtstate.c` (`5b7f52fa39e32e62bbe3cb1f6b4d0db123c8c213`),
`misc.c` (`6206ab19f1a958f26c25aea51d7377c8251f2ed5`) and
`df.c` (`d79c11a6c0efb9008d2bfd8f76b386c2d594ffae`).
`shared/rtstate.c:564` selects native primary via `wanN_primary`, not the
last-configured `wan_unit`; `:359` distinguishes PPP from ordinary interfaces.
`shared/misc.c:2346` reads that unit's `ipaddr`. BusyBox `coreutils/df.c`
supports `-Pk` independently of DF_FANCY; clear POSIXLY_CORRECT for KiB output.
Cached image inventory confirms `/bin/nvram`; pinned init uses
`firmver.buildno_extendno`, and original common code treats `ntp_ready=1` as ready.
These are source/static facts only, not live router or complete firmware proof.

## S02.04 DNS scope review

2026-10-14; independent scope review from `807aa1b`, final accepted runtime `e4adda5`; S06.03 remained outside this acceptance.

Scope refinement from the independent Astra review: configured tunnel (including
Off) makes DNS tools applicable, not tunnel launch eligible. Normal shared/safety
admission must distinguish DNS not-required/verified/deferred. Ordinary DNS
outages never reinstall healthy tools or block manager/DDNS/IP-Sync; strict
reinstall verification remains unchanged. Storage/ownership/supervisor failures
and stale-scope refusal remain fatal. A resolved DNS-only package failure may
defer only DNS after fresh shared-tool post-probes prove manager admission safe.
S06.03 still owns full tunnel launch/readiness, NTP and reachability integration.

## S02.04 DNS safety review

2026-10-14; scope and safety reviewers, with final required grouped evidence at `e4adda5` retained in the handoff.

`s0204_scope_audit` completed its read-only review.
`s0204_safety_review` independently reviewed the DNS-only repair-failure exception
and post-repair cleanup. Its resolved-migration cleanup finding and real-worker
failure-origin assertion are fixed; the focused follow-up passed. No edits or
acceptance authority were delegated to reviewers.

## S02.04 failure-handling review

2026-10-14; three design corrections accepted before final `e4adda5` verification; no requirement change.

The Astra audit required revising the initial failure handling; its three
findings are incorporated into the worker contract: separate shared/DNS outcomes,
separate configured scope from effective inventory scope when native DNS is
unknown, and preserve fatal supervision/storage/stale-scope failures. It confirmed
that the real normal retained consumer can close S02.04 without Goal 6 lifecycle.
No requirement or acceptance gate changed.

## Instruction maintenance review

2026-10-14; instruction-only tree based on `edcb8cd`, published as `807aa1b`; the authorization and checks remain in the handoff.

Astra Max's read-only audit passed with one procedural
note: retain CFMgr's disjoint Quick Checks groups. That wording is retained;
parent review confirms the removed procedure is covered by available skill text.

## S02.06 smallest-task scope review

2026-10-14; corrected documentation-readiness boundary; user selected S02.06 if no smaller independent complete outcome was ready.

Parent
and Astra Max reviewed the remaining IDs and found no qualifying smaller complete
runtime task.

## S02.06 native DNS source review

2026-10-14; selected reinstall design and parser evidence; final runtime `03a4f01`.

DNS refinement supersedes the earlier no-host proposal in the private snapshot:
usage with no hostname is ambiguous. Complete fixed SRV invocations using the
supported `-q`, `--type=` and `-type=` grammars distinguish known option/type
rejection from accepted-query failure. All three pinned ordinary implementations
reject leading options before resolver work; pinned LEDE explicitly rejects SRV.
The positive parser follows [BusyBox 1.36.1's SRV/A formatting](https://github.com/mirror/busybox/blob/1_36_1/networking/nslookup.c#L370),
excluding server-address preambles and not requiring a non-authoritative marker.
This defines a supported parser interface, not another firmware-support claim.

## S02.06 runtime interface review

2026-10-14; parent/static review of callback discovery and fresh selected-tool probes, final candidate `03a4f01`.

Parent/static review
resolved the BusyBox callback-discovery issue (`type`, because the pinned ash
omits `command -v`) and verifies fresh post-probes for every selected optional
Entware tool even if a native provider changes during the action.

## S02.06 storage-loss report review

2026-10-14; finding on candidate `fd91e89` after failed run `38441702494`; parent and independent analyst reviewed correction, final required gates passed at `03a4f01`.

Source review
found that an exceptional task return can reach resolved controller cleanup
without the final attachment observation performed on the normal task path.
The correction adds a final observation/report after resolved task cleanup;
unresolved native children, task cleanup or event reporting retain guards without
proceeding to release. The new controller regression reuses the existing adapter
and actual repair/event bodies: old source reproduces missing loss reporting;
five scenarios cover lost/attached completion and unresolved task/native/event
states. Parent and independent analyst reviewed the eight-line runtime change
and test assertions. The shared adapter now explicitly supplies its attached
storage assumption; the real detach assertion remains intact and gains bounded
failure labels.

## Documentation readiness review

2026-10-14; S16.02–S16.05 timing correction following the explicit user decision. Original reset authorization, verified recovery inventory and consumed rewrite permission remain in the handoff.

Astra Max's focused audit passed with notes; the replacement resolves its
conflicting-timing, S16.02–S16.05 consistency and essential-current-guidance notes.

## S02.06 earlier design findings

2026-10-14; preimplementation findings preserved after the documentation reset. Later S02.06 acceptance supersedes the historical unimplemented status below.

S02.06 was unimplemented at that pause. Its read-only design findings remain in the
private snapshot's handoff and safety history: configured-tunnel-only DNS scope,
truthful coalesced-repair deferral and capability-versus-outage classification
need implementation before a genuine reinstall action can pass its focused gates.
Pinned native nslookup source inspection found no SRV support in either variant;
source evidence is not live capability proof. No runtime attempt was discarded.

## Retained execution and storage source review

Historical shared-repair foundation review for S02.05/S02.08. Exact source pins and platform limits are below; earlier acceptance and recovery receipts remain in the handoff. References to a receipt above mean those historical handoff receipts, not this migration.

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
