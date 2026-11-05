# Daybreak handoff — one package-admission repair

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
Codex Session: 01a13107-3627-7803-aa3d-4fb1c1974dea
Fifth ID verified 2026-10-14 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1420b-3ef8-7c80-a5f1-aa989e2fae32
Sixth ID verified 2026-10-16 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a143d6-a984-7c11-923a-4c30a037c5f5
Seventh ID verified 2026-10-16 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a14803-6b23-7b22-b261-581bee5dfce5
Eighth ID verified 2026-10-17 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a151ca-9b8c-7d21-a424-11c9013c54fd
Ninth ID verified 2026-10-19 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a15c84-5da2-7eb2-b960-72ad3e59dd86
Tenth ID verified 2026-10-21 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a16765-b366-7071-8c80-8f4770f6036c
Eleventh ID verified 2026-10-23 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1848b-c9de-7121-b7c2-6611f14d8aea
Twelfth ID verified 2026-10-29 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1aa23-d93d-7883-a4ea-5c956b11b24c
Thirteenth ID verified 2026-11-05 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1ab24-f6a2-7762-a94f-84e2d211d566
Fourteenth ID verified 2026-11-05 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
-->

## Scope and authority

The user requested this temporary root-level handoff, approved keeping it tracked,
and explicitly limited Daybreak to **one task**. The user will open a separate
Daybreak session; verify that session actually has Blue access before doing the
security-sensitive work. A model/role name alone is not access proof.

**Task:** repair and prove the package-verification failure handling in the new
interactive startup admission path. This blocks the S02.04/S02.05 repair, but
Daybreak does not own the wider five-subgoal checkpoint. Preserve all other WIP.

## Finding and required result

The uncommitted `cfmgr.sh` change runs a fresh internal `admission` process before
the normal interactive menu. It treats child status 3 as unresolved and other
nonzero statuses as resolved operational unavailability, then offers native menus.
However, failure of the child's installed-package verification currently also
returns 1. It can therefore be treated as ordinary operational unavailability.

Review the actual trust and failure-classification boundary, fix the issue, and
add focused regression proof. Required observable outcomes:

- Installed-package verification failure must not lead the parent into loading or
  using menu modules whose current package cannot be trusted; report failure.
- A resolved operational prerequisite failure must still preserve the intended
  native reporting/recovery access when the package is valid.
- Unresolved owned work must retain its stop/recovery behavior. Preserve terminal
  input, traps, the single-admission-per-launch rule and existing public commands.

Start with `cfmgr.sh` around 419–480 and its current diff. Consult only the directly
relevant entry/native return paths in `modules/lib/package.sh` and focused tests
in `tests/test_dependency_reinstall.py` / `tests/test_entry_package.py` as needed.
The new internal action extends an existing verified-entry protocol. Determine the
smallest sound repair; do not assume an exit-code-only change is sufficient.

## Boundaries

- Own this failure-handling repair and its focused tests only. Change `cfmgr.sh`
  and directly necessary helper/test lines; do not refactor adjacent subsystems.
- Do not implement/review the unrelated parser-inventory, WAN Save, archive-naming
  or Linux fixture-bridge work. Do not take over the other reopened subgoals.
- Do not rewrite requirements, award checkboxes, update README percentages, scope
  the next checkpoint, trim the main handoff, alter AGENTS/global rules or memory.
- No router/provider actions, dependency installation, new worktree, commits,
  pushes, CI dispatch or full-suite runs. Parent integration and exact-candidate
  platform/core CI follow after this narrow task returns.
- Other agents/tests were stopped at the user's pause. Preserve every unrelated
  staged/unstaged/untracked/ignored file. The existing index was empty.

## Workspace and focused verification

Use the existing `develop` checkout. HEAD and last verified origin/develop are
`7444c82b95249c14a54fa8e1d154551fc76dfcd3`; prior tested runtime was
`7ea47342b6c92883ca92f66c60802a4f43f3f4ec`. All current repairs and records are
uncommitted. The full current pause snapshot/inventory is private at
`.tmp/daybreak-pause-2026-11-05/`; earlier ownership snapshots remain intact.

Use the existing `.venv`, established focused pytest fixtures and changed-file
statics. Linux/vendor BusyBox proof is not available on this macOS host; record
skips honestly for later parent CI. Do not replace the required behavior with
stubs that make the failure path pass. Record command, result, scope and platform
limits. If runtime bytes change, coordinate or regenerate catalog/manifest with
`.venv/bin/python tools/package.py --write` and report those generated changes.

The previous whole-repository `tools/test.py --checks-only` was interrupted at
ShellCheck during the explicit pause (exit 130); it is not a passed final gate.
Do not inherit acceptance from it or from the old runtime CI.

## Return and stop

Write the result **in the Daybreak report section below**, including files,
focused tests, remaining limits and whether this one task is complete. Do not
create a separate report. Then pause. The main session will integrate the repair,
finish the other gates/subgoals and only afterwards scope the next checkpoint and
trim `PLAN_V2_handoff.md`, as the user requested.

The broader state remains in [PLAN_V2_handoff.md](PLAN_V2_handoff.md); it is not an
instruction to resume its other work in this Daybreak session.

## Daybreak report

- **Status:** COMPLETE for this scoped repair on the uncommitted `develop` tree at
  `7444c82b95249c14a54fa8e1d154551fc76dfcd3`. No acceptance row is awarded.
- **Access and necessity:** The user reported that Codex says “Daybreak is on for
  new turns”; this turn has the Daybreak runtime profile. The shell/session
  metadata did not expose an independent account-level Blue entitlement readout.
  No security refusal or technical need for relaxed behavior was observed. The
  prior hold was the project's security-routing/verification rule for this
  sensitive boundary, not a failed attempt to implement the repair.
- **Finding/disposition:** The admission child returned status 1 for installed-
  package verification failure, which the interactive parent interpreted as
  resolved operational unavailability. The child now returns dedicated fatal
  status 5 for its initial installed-package admission/source/verification
  failures. The parent stops on that status and re-verifies current package
  bytes after any otherwise menu-eligible child result, before importing menu
  modules. Status 3 still stops unresolved owned work; other operational
  results still allow native reporting/recovery when the package verifies.
- **Changed files:** `cfmgr.sh`; two focused regression cases in
  `tests/test_dependency_reinstall.py`; regenerated `manifest.txt` after the
  runtime-byte change. `catalog.txt` was regenerated but its bytes did not
  change. All other pre-existing WIP was preserved.
- **Focused tests:** On the dirty macOS host tree, the selected installed-entry
  and admission tests in `test_dependency_reinstall.py` and
  `test_entry_package.py` passed **14/14 in 50.67s**. They cover real child
  verification failure, a package change during an operational child failure,
  valid-package operational recovery, unresolved work, normal menu access and
  earlier corruption/metadata rejection. `tools/package.py --check`, Ruff
  check/format, Python compile, `/bin/sh -n`, ShellCheck error severity and
  `git diff --check` passed. Full ShellCheck still reports the same pre-existing
  warning-code counts as HEAD (8 SC1007, 1 SC2004, 9 SC2034); `shfmt` is not
  installed on the resolved PATH.
- **Outcome and remaining limits:** No router/provider action, dependency
  install, full suite, CI, commit or push. The test fixtures use real package
  verification on host-adapted temporary copies; Linux/vendor BusyBox and
  exact-candidate core CI remain for the main checkpoint. No direct account-
  entitlement proof beyond the user's Daybreak setting report was available.
- **Action needed from the main session:** Review/integrate this scoped diff and
  generated manifest, then finish the remaining work across the five reopened
  rows and all required affected-module, platform and exact-candidate gates.
  Keep S02.04/S02.05 unchecked until the full coordinated checkpoint proves them.
