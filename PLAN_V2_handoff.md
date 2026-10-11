# CFMgr v2 — current handoff

<!--
Codex Session: 01a12b73-456b-7de0-b3c2-db151518949f
Codex Session: 01a12ca8-2b44-7791-90ab-a1e5b17b3d18
Second ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Working rules](AGENTS.md)

## Current boundary

**Salvage only this session.** The final acceptance review found no existing
runtime area that can close an entire approved subgoal without substantial new
feature implementation. The user accepts only complete subgoals. All partial runtime, its tests and
package tooling have been removed. The retained tree contains planning documents,
README, a temporary development note, license, empty folder structure and a
planning-only verification gate.
No runtime subgoal or focused-complete tick is earned. S02.01 is deferred, not
redefined as metadata verification. Goal 1 starts next session.

The authorized private backup, develop history reset and guarded publication are
complete. The parentless baseline passed exact planning CI; final documentation
receipts use the same gate. CI describes this as planning validation, never full
runtime or BusyBox acceptance. The user subsequently authorized removal of main
locally and from origin. Develop is the repository default until reviewed 100%;
no release/tag promotion, router execution/install/service mutation or provider
write is authorized.

## Decisions and ownership

- Diagnostics cannot close S03.09: configuration/storage/network/auth/service,
  integration and recovery interfaces are missing. Its native subset and aliases
  are removed rather than retained as an unfinished feature.
- S02.01 cannot close merely with an immutable exporter and content verifier:
  there is no completed approved feature using explicit module/entry interfaces.
  The previous tentative completion claim and focused tick are withdrawn.
- Dependencies S02.04–06 and address S08.03/.04 were already below the delegated
  60–70% salvage threshold. Their required workflows remain in the specification.
- All runtime, tests/fixtures, package tools and obsolete guides are removed.
  README stays an implementation overview; current checker/developer instructions
  live in docs/development.md rather than expanding README.
  Preserve .old/PLAN.md, ignored private references/evidence and the history
  backup. Empty modules/lib, modules/helpers, modules/hooks and tests preserve
  the agreed folder structure without executable scaffolding.
- Parent reviewed each finished worker package before assigning the next task,
  including the final planning checker/workflow. All workers are stopped; parent
  owns final validation, history reset and publication. No background test jobs.

## Evidence and progress

The earlier 70-pass/four-skip local suite covered now-discarded partial code.
It supplies no current acceptance. No focused runtime, full runtime, BusyBox,
kernel or router gate can be marked passed for this planning-only tree.
Local planning checks pass: 156 aligned subgoals, 16 README goal links, active
document links/privacy, empty runtime inventory and rejection of unearned ticks.
The documented python3 command passed in 0.40s elapsed (0.07s user + 0.02s system).
Python compile/Ruff/format, workflow YAML and whitespace checks pass. Temporary
fault checks reject accidental product ticks/runtime and ignore archive-internal
links. Exact planning CI passed on root 9a58b52d8382508a7dbbd8f2f68887e70ad53382:
[Planning-only checks, run 38178864431](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38178864431).
The job completed successfully, including the documented checker command. The
latest documentation-receipt commit/CI are recorded in the ignored private receipt
below; verify current remote HEAD and its exact CI before resuming.

The salvage audit and cleanup baseline are complete. Final documentation-only
publication receipts must also pass the planning workflow before the session ends. Product completion stays
**0/16 main goals = 0%**, with zero completed subgoals. Each completed main goal
will add 6.25%. No percentage is awarded for auditing, deletion or planning checks.

Subgoals require complete implemented behavior, written focused local tests and
required exact platform CI. Main goals require every required subgoal plus full
local/full CI suites, docs/cost review and parent scope-drift review. The former
1%/10% cadence is superseded. Resume ordered goal 1 work next session, with no
salvage tick carried forward.

## History reset and publication

Pre-reset develop: e571555771abbe128102b2edda69014d37143d24. Freshly observed
remote develop: debba577d43b2b20285d8226615c5e3ef7431ddb. The subsequently deleted
main tip was f4b3136762bda6fb2f9c31796338ddc27444a403; it is preserved in the
private bundle. No tags were returned.

Before the local reset, a complete private bundle was created and verified:
`.tmp/history-before-salvage-e571555.bundle` (mode600, about2.1MiB).
SHA256: `3e5599dcc3c531a1c61edb0c891526c5ebf290e976349c001af3a68918e32365`.
It contains old heads/remotes/HEAD plus a preserved stale detached worktree HEAD.
That unrelated/prunable worktree metadata is untouched. The backup is ignored,
never part of the shipped tree. Recovery, if requested, can import old develop
from this bundle into a separate recovery branch without resetting new work.

Published parentless root: `9a58b52d8382508a7dbbd8f2f68887e70ad53382`.
Tree: `2b1a76f0370735028e749b2471462137d0d87925`.
The explicit lease against the old remote develop succeeded. At the user's
subsequent request, GitHub default was changed to develop, origin/main was deleted
with an exact lease against f4b3136762bda6fb2f9c31796338ddc27444a403, local main
was deleted and origin/HEAD was set to origin/develop. Server refs confirm develop
as the only branch and advertised HEAD. Develop stays default until reviewed
100%; choose any later release-branch policy explicitly then. Do not recreate
main during implementation. S07.07 and source defaults mirror this policy.

Local safety ref `refs/safety/salvage-before-e571555` also retains old develop;
it is not pushed. Exact old/new/tree IDs, backup digest and final publication/CI
receipts are in ignored `.tmp/salvage-history-receipt.txt`. Keep this receipt,
bundle and private source evidence. The main deletion/default change and final
validation are also recorded in ignored .tmp/main-removal-receipt.txt. No tag
rewrite, unrelated worktree pruning or private artifact publication occurred. Follow-up documentation commits
belong to the new history and cannot tick any runtime subgoal.

## Preserved product decisions and next session

README stays focused on implementation overview/status. Temporary developer notes
remain small and use the same GitHub documentation skill. Build the full guide
set, including architecture, near completion of most/all implementation goals;
finish required documentation before usable 100%. S16.03 mirrors this decision.
The full planned guide inventory and topic/goal coverage are now listed in section
16 and mirrored under S16.03 in the checklist; no empty guide pages were created.

Hook ownership/repair and logging amendments remain mirrored in spec/checklist:
paired owned CFMGR markers, preserve ambiguous foreign bytes, block affected work
and expose repair; default native logger routes to existing system messages plus
eligible feature logs directly under /opt/var/log. Owned logrotate fragments are
reread on normal runs through the valid include; no Scribe reload/forced rotation.
Research used Scribe 53dee6e97c2d6aa4f656c68c18fa1f2c499042f7 and Entware
b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd plus official Merlin guidance. This is
source evidence, not implemented logging/hook acceptance.

Durable Save remains absent. Reviewed Merlin fsync may return zero on failed
flush and dd count=0 does not perform the in-loop conv=fsync. Resolve reliable
native persistence/failure reporting before dependent mutations; do not silently
introduce a mandatory dependency or weaker contract.

Next session: read all three v2 files and verify current develop/CI. Resume
ordered delivery at main goal 1, preserving the unchanged scope and the
16-goal denominator. Main goal 1 spans all independent product features/source
parity; a menu skeleton cannot complete it. Use necessary dependencies without
crediting unfinished workflows. Preserve open product/default decision gates.
