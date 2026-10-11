# CFMgr v2 — current handoff

<!--
Codex Session: 01a12b73-456b-7de0-b3c2-db151518949f
Codex Session: 01a12ca8-2b44-7791-90ab-a1e5b17b3d18
Second ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Working rules](AGENTS.md)

## Current boundary

**CI triggers simplified; full implementation remains for the next session.**
The user explicitly requested removing only the workflow path filters, retaining
the planning checks and renaming the workflow to **Checks**. It now targets every
develop push and pull request, including documentation-only changes. Agents must
add CI coverage alongside new test packages. Parent review, local planning checks,
workflow YAML/trigger checks and whitespace checks passed. The authorized push/CI
result is recorded in the receipt below; no salvage restart or goal 1 work is included.
The earlier cleanup, history reset, guarded publication and main deletion are
complete one-time actions, not reusable permission.

Product status is **0/16 main goals = 0%**, zero completed subgoals. The working
tree contains no CFMgr runtime, installer, package catalog or runtime tests.
Only tools/check.py and the CI workflow execute; they validate planning
consistency and deliberately reject runtime until replaced alongside real tests.

## Current work and ownership

| Owner | Scope | State |
| --- | --- | --- |
| Parent | Workflow, AGENTS.md, developer note and this handoff | Edits and local review/checks complete; verify publication and exact CI in the receipt below. |
| readiness_review | Read-only rules review; no owned files | Review and follow-up gate checks returned; parent addressed findings. Stopped. |

The user also authorizes automatic handoff trimming/rebuilding under AGENTS.md.
The specification/checklist remain authoritative; lost context requires a code
and evidence audit before reconstructing notes. Preserve the hidden session-ID
block above and all unresolved work/approval boundaries through every refresh.

Latest user clarification is incorporated in AGENTS.md: main-goal checkpoints
replace the old 1% rule; normally every subgoal's focused local checks precede the
full local suite, push and exact full CI, then the goal/README completion.
Each main-goal candidate also requires the accumulated-codebase audit in AGENTS.md
before that full local gate: check duplication, real reuse, unused paths and
test/tool/CI overlap. The checklist now has an explicit audit box for every main
goal; all remain unchecked because no runtime audit has been performed.
Earlier pushes need approval and are eligible only when most required subgoal
proof needs Linux/BusyBox. The custom parallel-role setup is retained. Extensive feature
rework or material plan/goal changes require user input first; explicit user scope
amendments must not be weakened by an agent interpretation.
Required approval uses a concrete question. If unanswered after a reasonable
response window, record the pending decision here and end the turn waiting;
silence never authorizes the dependent work. No approval question is pending now.

No runtime, tests, tools, README, global profile or agent configuration changes
are included. The earlier documentation-only CI exclusion is superseded by the
user's explicit no-path-filter selection. CI configuration alone may adapt to the
growing approved test suite; it cannot weaken required coverage or change agreed
plan/goal/acceptance/agent/publication rules. All delegated work is complete.
The preceding publication ended at `55e677bc405d43f39dd66e796d916fed2dcf521d`;
its ignored receipt is .tmp/readiness-publication-receipt.txt. The current CI-only
amendment has explicit push authorization. Record its final commit/run in ignored
.tmp/checks-publication-receipt.txt and the final response, then verify them on
resume. This publication does not start further implementation.

## Verified baseline and evidence

Previously reviewed code/workflow revision:
`747137d7f0d594f951dff22d8d242c602cce6211`.
Its exact [Planning-only checks run 38180651867](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38180651867)
completed successfully. The subsequent handoff-only commit 55e677b had local
documentation validation under the former path filters. Neither result validates
the current trigger amendment or provides runtime/platform acceptance.
GitHub default/advertised HEAD is develop; remote main is absent.

Local validation passed: python3 tools/check.py and git diff --check. A separate
read-only comparison against the pre-review baseline 4ce6a9a confirmed all 156 subgoal
requirements, all 76 acceptance cases (including conditional items), the complete
product/checklist detail, existing completion states, custom parallel role table
and hidden session-ID block are unchanged. The new main-goal audit boxes remain
unchecked. Only the four authorized Markdown files changed across preparation.
Parent reviewed document separation, the revised publication/approval sequence
and preservation rules, including the independent review corrections. These are
documentation checks, not proof of runtime behavior or future agent compliance.
The same GitHub documentation skill was applied to AGENTS.md and the planning
documents, including the audit amendment. The final publication also changes
the CI workflow/development note. Workflow YAML and representative trigger checks
passed locally: 14 code/configuration paths selected, 14 documentation/placeholder
paths excluded, plus mixed and documentation-only change sets. A CI run for the
changed workflow still supplies planning-only
evidence until the runtime gate is replaced.

## Recovery record and limits

The preceding operation produced a cleanup/reset with **no successful runtime
salvage**. Useful verification, I/O, dependency and address logic existed, but
whole workflows remained unfinished. The complete-or-drop rule was applied too
broadly instead of finishing viable substantial salvage. The earlier S02.01
completion/focused claim was withdrawn. The removed diagnostic subset did not
complete S03.09. Neither decision reduces those approved requirements.

The former 70-pass/four-skip suite covered discarded partial code. It provides no
current acceptance. Do not repeat its result as a pass for this tree or reinstate
old completion percentages. Future incomplete implementation remains preserved
work in progress under AGENTS.md, with no unearned product tick.

Original committed history remains in verified private
`.tmp/history-before-salvage-e571555.bundle`.
SHA256: `3e5599dcc3c531a1c61edb0c891526c5ebf290e976349c001af3a68918e32365`.
The bundle was reverified during this audit and contains old local develop
`e571555771abbe128102b2edda69014d37143d24`, old remote develop
`debba577d43b2b20285d8226615c5e3ef7431ddb`, deleted main
`f4b3136762bda6fb2f9c31796338ddc27444a403` and the retained detached worktree ref.
Local `refs/safety/salvage-before-e571555` also retains old develop.
**The bundle does not preserve the uncommitted salvage rewrites; no complete
snapshot of those rewrites was verified.** Do not promise full recovery of them.

If original-source recovery is requested, import old develop from the bundle into
a separate recovery branch or private inspection checkout without resetting new
work. Keep the bundle, ignored references/firmware evidence and .old/PLAN.md.
Do not prune the unrelated detached-worktree metadata. Historical reset/main
receipts are in ignored .tmp/salvage-history-receipt.txt and
.tmp/main-removal-receipt.txt. The new history began at parentless
`9a58b52d8382508a7dbbd8f2f68887e70ad53382`; those actions are finished.

## Open implementation blockers

- Durable Save is unimplemented. Previous source review found Merlin fsync may
  report zero on a failed flush and dd count=0 skips its in-loop fsync. Revalidate
  the matched source/capabilities and resolve reliable persistence/failure
  reporting before dependent mutations; do not weaken the contract or silently
  add a mandatory dependency.
- Other product/default/capability decisions remain in specification section 17
  and the matching checklist. No proposed default became approved during cleanup.
- Source selection, hook ownership/repair and logging amendments remain in
  specification sections 7, 12 and 13 with matching acceptance. None is implemented.
  Prior Scribe/Entware evidence is source-only; use the pinned authorities there
  and check actual supported versions when implementing.
- README remains an overview; the small development note describes the current
  checker. Section 16 and S16.03 hold the full future guide inventory.

## Next session

1. Read AGENTS.md and all three v2 documents; inspect current refs, working changes
   and actual worker/job state. Verify the published preparation checkpoint and
   exact CI for subsequent changes; the Checks workflow now runs without path filters.
2. When implementation is authorized, start from goal 1 and map its first coherent
   workflow to existing subgoals and necessary dependencies. Goal 1 covers the
   combined product/source parity; neither a menu skeleton nor supporting helpers
   complete it. Follow dependency order without reducing scope or inventing ticks.
3. Settle that package's concrete consumer/interfaces, relevant open decisions,
   owned files and tests before delegation. Replace the temporary empty-runtime
   gate with focused/full testing and applicable BusyBox/kernel CI alongside the
   first runtime package; preserve useful planning consistency checks.
4. Parent reviews each completed package before assigning the next. Preserve
   partial work in local checkpoints and pending proof here. Apply the existing
   subgoal/main-goal gates in AGENTS.md; an early CI push needs its stated approval.
   Full implementation begins in that next session, not as part of this audit.
