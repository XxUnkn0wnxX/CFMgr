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

- Current optimized candidate `2085e324f54885305f9849c5ad26e0d926fef492` is pushed
  and remote-verified (`c7574df` implementation plus corrected selection receipt).
  Whole-suite review and focused gates passed before publication. [Quick Checks 38265673929](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38265673929)
  passed: **4 tests in 248.95s**, actual retained repair (140.16s, previously
  165.50s), drive loss (99.95s), unchanged full view compatibility (5.42s) and
  runner gate reuse. Parent verified exact SHA and sole job success; receipt
  `.tmp/optimized-quick-pass.log`. No invalid selector was executed. Runtime remains
  unchanged from `9e2563d`. [Full Checks 38266754900](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38266754900)
  failed at the same candidate: runner unit test inherited outer
  `CFMGR_TEST_SHELL=/bin/sh` instead of its fake default. All statics passed;
  BusyBox was skipped. Parent reproduced the assertion locally with that environment
  and owns only `tests/test_dev_runners.py` fixture isolation, focused tests/statics,
  quick diagnostic and subsequent full CI. Receipt `.tmp/optimized-full-failed.log`.
  The one-line fixture isolation fix passes all **30 runner tests** under each
  inherited environment (`/bin/sh` and `busybox ash` with required-BusyBox mode).
  Relevant Ruff/format/compile, planning/package and whitespace checks passed.
  Production runner/runtime behavior is unchanged; only the unit harness clears
  ambient shell selection before individual tests set their explicit inputs.
  No job remains active. Exact full acceptance and overall cost remain pending.
  User requests another safe
  saving if practical, ideally one minute, but accepts stopping if further cuts
  would weaken necessary proof. `next_subgoal_review` completed a bounded read-only
  follow-up: no further justified minute-scale cut. Remaining work is real guarded
  view construction, checks and cleanup, without fixed long sleeps; removing the
  absent/return launch or proc/dev mounts loses distinct required proof. No writer
  or new product scope is authorized.
- Previous candidate `9e2563da53b836a9a51cedc66b94f7287af8f548` is pushed and
  remote-verified. It pins CI ShellCheck 0.11.0 to match the workstation and contains
  the reviewed shell annotation/conditional fixes below. [Quick Checks 38261906544](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38261906544)
  passed **14 tests in 8.97s** and verified the pinned ShellCheck binary. Receipt
  `.tmp/retained-shellcheck-quick-pass.log`. [Full Checks 38262065257](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38262065257)
  was cancelled on user instruction after about 20 minutes; host/static passed,
  BusyBox supplied no final pass. No CI, local tests or writers remain active.
- Previous runtime candidate `cffc1a541a73d177ec216746a3351433ce136d94` is committed,
  pushed and remote-verified, including the practical CI and review-note commits.
  [Quick Checks 38260092807](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38260092807)
  passed **17 tests in 344.93s**, including actual retained repair/return and fresh
  installer repair. Receipt `.tmp/retained-quick-pass.log`. Parent verified exact
  SHA/job success. [Full Checks 38261015597](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38261015597)
  failed in Ubuntu ShellCheck before behavioral tests: SC3013 needs narrowly
  scoped annotations for intentional BusyBox/Linux descriptor `-ef` checks;
  three fixture SC2015 expressions need explicit conditionals. Receipt
  `.tmp/retained-full-failed-1.log`. No CI is active. `focused_ci` owns only these
  annotations/conditionals in `modules/helpers/{bootstrap,launch,probe}.sh` and
  `tests/fixtures/{dependencies,retained_launch}.sh`; no runtime contract changes.
  These shell edits are released and pass targeted lint/syntax/format plus 15
  focused host tests. The user additionally requested CI ShellCheck match the
  workstation: **0.11.0** verified locally. Shared setup now installs the official
  pinned Linux x86_64 archive after SHA-256 verification; both workflows removed
  APT ShellCheck. YAML parsing, extracted Bash syntax, planning and package checks
  passed. Worker released all files; parent review passed. Quick proof will verify
  CI setup and selected short regressions, then full Checks supplies acceptance.
  Parent owns metadata, review and publication. Focused checks then exact full
  Checks remain required before accepting S02.05/S02.08 and pausing; full local
  is not due. The marker-push Checks skip supplies no acceptance.
- Latest pushed/remote-verified candidate: `8dfa47753860667f71aecb7710007559c61d5617`.
  [Quick Checks 38253817799](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38253817799)
  passed at that exact SHA; selected mixed/loss/installer tests ran
  13:10:37–13:19:12 UTC. `inventory_ci_wait` finished and owns no work.
  Only the exact mixed stderr expectation changed. Local dependency tests
  **13 passed/11 Linux skips**; affected Ruff/format/compile/planning/whitespace
  passed. Quick proof permits continued work on the same pair; full required
  acceptance CI still waits for the completed candidate.
- Previous candidate: `bf2da3e40f8b42c61e9e73ad8a0361b497f81fe1`.
  [Quick Checks 38253187477](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38253187477)
  failed the Python stderr expectation after **160.30s**. The mixed-root shell
  fixture exited zero: actual foreign/owned roots, retained state, no signals,
  explicit fixture recovery and final cleanup assertions all passed. It correctly
  emitted cleanup-pending plus unavailable-native-log messages, matching the source
  contract; the outer test incorrectly expected empty stderr. Receipt
  `.tmp/dependency-repair-quick-failed-2.log`. Parent owns the exact expected-message
  correction in `tests/test_dependencies.py`; runtime unchanged. Repeat the same
  three quick cases. No CI/workers active. README contains accepted counts only.
- Previous candidate: `31d3c78d0fc0b0891625aeffb9ee59c88c45b284`.
  [Quick Checks 38249697814](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38249697814)
  **passed 9 tests in 134.93s**: five deterministic short-child observations,
  existing supervision and real normal repair. Receipt
  `.tmp/dependency-repair-quick-pass-2.log`.
  [Full Checks 38250075180](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38250075180)
  failed at that same SHA: host/statics passed; BusyBox **16 passed/1 failed,
  975.40s**. Mixed-root fixture expected retained ownership but cleanup completed;
  `.tmp/dependency-repair-full-failed-2.log`. No CI job remains active. Its foreign
  observer starts before view construction but waits only 10s for the later action
  receipt; loss observer likewise waits only 20s. Parent is tracing that fixture
  timing against the actual phase, preserving all runtime ownership assertions.
  `dependency_fixture` owns only `tests/fixtures/dependencies.sh` and
  `tests/test_dependencies.py`: start observers at the actual task-gate phase,
  bounded by the product action window; prove readiness/liveness and retain
  mixed-root/no-signal/loss assertions. Focused local/statics, then quick mixed,
  loss and installer cases before full CI. No retained-launch implementation yet.
  Fixture correction is implemented and parent-reviewed; writer released files.
  Observers start after actual gate creation, wait at most the 120s action window,
  and record finite phase diagnostics. Mixed actor waits for opkg's explicit test
  request after selected-tool installation; assertions prove distinct live TIDs,
  actual foreign/owned roots and no product signals. Local dependency tests
  **13 passed/11 Linux skips**; affected statics, package/planning checks passed.
  Runtime code and deadlines are unchanged. Quick mixed/loss/installer proof pending.
- Previous candidate `0851c1c5a5012ddaceaabfa2583aaffda48e7dd7` is pushed and
  remote-verified. [Quick Checks 38247678272](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38247678272)
  **passed 5 tests in 122.87s**, including real normal opkg repair/cleanup
  (121.74s) and four retirement cases. Verified BusyBox warm preparation took 1s;
  the full quick job took about 2m22s. Full Checks manually dispatched at this
  candidate: [Checks 38248007991](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38248007991).
  Full Checks failed: host/statics passed; BusyBox **12 passed/1 failed, 134.58s**.
  Actual opkg completed successfully (`complete 0 END`); view/keeper released.
  A short cleanup probe became unresolved with a tracked PID/start and no other
  refusal reason. `.tmp/dependency-repair-full-failed-1.log`. The short supervisor
  has a confirmed source race: proc directory can disappear between its existence
  check and owned-identity read, which currently reports unresolved. No job remains
  active. `prerequisite_inventory` owns prerequisites-only lifecycle correction;
  `dependency_fixture` owns prerequisite tests with deterministic disappearance and
  still-visible unknown/reused identity cases. Preserve ownership proof before any
  signal; only positively absent direct children may proceed to their exact wait.
  Parent reviews; quick lifecycle/normal-repair proof then exact full CI.
  Retained-launch native logging review completed read-only; no implementation yet.
  The direct-child correction is implemented and parent-reviewed. A failed identity
  read plus confirmed absence allows exact wait; any successful-but-invalid read or
  ownership mismatch remains unknown, even after disappearance. Fresh identity
  remains required before signals; timeout-child proof/deadlines are unchanged.
  Five deterministic Linux regressions are added, with private process-group
  teardown; local prerequisite tests **20 passed/8 Linux skips**, affected statics
  passed. Writers released files; metadata regenerated. Quick selection includes
  these races, existing flock/output-limit supervision and real normal repair.
- Quick candidate `e2ae0df5aa3346853ac7f27e69f55e506db8e0db` is pushed and
  remote-verified. [Quick Checks 38246627323](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38246627323)
  passed all four terminal-retirement cases but failed normal repair during bounded
  cleanup: **4 passed/1 failed, 157.62s**. View and keeper were released; removal
  reached the unchanged cleanup deadline. `.tmp/dependency-repair-quick-failed-1.log`.
  No CI remains active; skipped Checks supplies no acceptance. The eight-file
  cleanup batches still multiply supervised probes over thousands of receipt files.
  `prerequisite_inventory` owns bootstrap/prerequisites/probe only: widen finite
  cleanup batches to at most 64 operands and at most 8192 pathname bytes including
  NUL delimiters, preserving all prevalidation, guards, owner-last and deadlines.
  `dependency_fixture` owns matching consumer/probe regressions and the bounded
  dependency outcome sidecar, including oversized argv rejection and partial
  failure. Capture the pre-cleanup result even after opkg success so cleanup-only
  failures retain its receipt. Parent owns metadata/plans/review.
  Re-run these same quick cases before any new retained-launch implementation.
  The 64/8192 refinement is implemented and parent-reviewed; both writers released
  files. Consumer/dependency tests **28 passed/18 Linux skips**, prerequisite
  regressions **20 passed/3 Linux skips**, affected statics passed. No deadline,
  ownership or prevalidation reduction. Metadata regenerated; next quick candidate
  rechecks terminal retirement and actual normal repair.
- Local runtime correction: `c086f66970c93355b7e7316c679c36c2214fd832`, committed
  after focused checks and included in the quick candidate above. Prerequisite
  regressions also passed: **20 passed/3 Linux skips**.
- Last remote candidate: `d809f5b3e7f3326428e98b4daf3a90695a0a7966`, pushed and
  remote-verified. [Checks 38242571950](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38242571950)
  failed vendor repair (**1 passed/1 failed**, 121.34s); host/static passed.
  Receipt `.tmp/dependency-repair-ci-failed-7.log`: batching reached final claim
  rmdir, whose successful removal invalidates the supervisor's own pathname
  attachment check. No job remains active. The terminal `repair-retire` correction
  is implemented and parent-reviewed: ordinary prelaunch admission remains; only
  the launched final removal may accept deleted pinned FD5 with zero links, valid
  preflight FD9 and the original RAM mount. Both runtime/test writers released
  files. Consumer/dependency tests: **27 passed/18 Linux skips**; affected statics
  pass. Platform tests: **40 passed**. Fixture `ls -L` now matches the hash-verified
  baseline source config. Bounded failure receipts survive cleanup. New quick CI
  below will first run retirement cases and the actual normal-repair case.
- The user now authorizes a separate fast CI loop: an explicit quick-test push
  runs only selected BusyBox test nodes using the existing verified cache, without
  duplicating the host/acceptance run. Quick results are diagnostic, not subgoal
  acceptance. The user clarified that normal Checks must run the **full suite**
  before accepting CI-dependent subgoals or pausing; ordinary local-focused work
  still commits and continues. Main Checks gains manual full-suite dispatch at the
  candidate ref; the older focused-trailer route is retired. `focused_ci` completed
  and released both workflows, shared verified BusyBox setup and bounded runner
  selection/tests. Parent reviewed the changes. Direct runner tests: **26 passed**;
  affected Ruff/format/compile, package/whitespace and YAML parsing passed
  (`.tmp/quick-ci-validation.log`). Integrated runner attempts were interrupted in
  all-tree ShellCheck before pytest; they supply no full-run receipt. Actionlint
  is unavailable. No worker or local test remains active. Parent owns planning,
  metadata and publication. Finish this CI prerequisite, then return to the same
  S02.05/S02.08 repair tests and the agreed finish-and-pause boundary.
- Previous candidate: `060583128c750c3cf1f2baf13c0ca961396ee085`, pushed and
  remote-verified. [Checks 38241095159](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38241095159)
  failed first vendor repair after **1 passed/1 failed**, 143.89s; host/static passed.
  Receipt `.tmp/dependency-repair-ci-failed-6.log`: view/keeper released, but individual
  receipt-file deletion exhausted the 60s cleanup deadline (1,635 probes at 142s).
  Parent approved bounded batches of at most eight existing cleanup operands,
  retaining quiescence, full tree/FD/mount checks, owner-last removal and all deadlines.
  `prerequisite_inventory` owns bootstrap/prerequisites/probe runtime changes only;
  `dependency_fixture` owns consumer tests and their finite native adapter. Parent
  owns metadata/plans/integration. No CI is active; require exact green before new work.
  Batched cleanup is now implemented and parent-reviewed. Actual portable probe
  dispatch proves <=8 quoted operands, partial failure/evidence retention and
  owner-last ordering; consumer **14 passed/7 Linux skips**. Prerequisite/dependency
  regressions **33 passed/10 Linux skips** (4.19s); affected lint/format/compile,
  shell syntax, metadata/planning and whitespace pass. Both writers released files.
  Cost fix removes redundant per-file supervision without changing deadlines or
  mount/ownership gates; exact Linux timing and behavior remain pending.
- Previous candidate: `e480822eb42933ae9c0a6dd6c4eec35b89b7199c`, pushed and
  remote-verified. [Checks 38240094327](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38240094327)
  failed first vendor repair case after **1 passed/1 failed**, 48.12s; host/static
  passed. Receipt `.tmp/dependency-repair-ci-failed-5.log`. Diagnostic proves view
  construction reached sequence 24/13 pins and 1,351 finite phase markers before
  the fixture's 45s timeout, inside identity parsing. Runtime action budget is
  120s plus separately bounded cleanup; audit the mismatched outer fixture budget.
  `prerequisite_inventory` owns `test_dependencies.py` and dependency/storage
  fixture budget/cost review only; no runtime edits without parent agreement.
  No CI remains active. Require exact green before retained runtime implementation.
  Parent/worker finite-loop audit found no loop bug: full source checks repeat
  8+2N supervised calls per bind, explaining hundreds of progressing probes.
  The outer fixture guard now covers unchanged 120s action/10s cancellation/60s
  release budgets plus 30s setup/teardown: 220s normal, 410s retry, 290s mixed-root
  recovery. Trace adds elapsed/probe counts; duplicate START writes removed.
  Focused dependency **13 passed/7 Linux skips**, affected static/syntax/format
  checks passed. Files released and parent-reviewed; runtime fit remains CI-pending.
  While CI runs, `next_subgoal_review` may read only the retained-launch bootstrap
  interfaces and return a bounded factoring map. No implementation/file ownership
  is granted; parent reviews the design after the current gate.
- Previous candidate: `64085a10f9efffa06621068125f4e94e7fd23bc4`, pushed and
  remote-verified. [Checks 38237947152](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38237947152)
  failed: host/static passed; vendor BusyBox **266 passed/1 skip/8 failed**.
  Six real repair cases hit their 45s outer watchdog; installer fixture re-imports
  the default `/bin/usleep` callback, unavailable on Ubuntu; coalescence has an
  intermittent waiter failure. Receipt `.tmp/dependency-repair-ci-failed-4.log`.
  No CI remains active. Repair ownership: `prerequisite_inventory` owns the
  dependency/storage shell fixtures and `test_dependencies.py` for bounded timeout
  diagnostics and installer callback correction; runtime changes require parent
  agreement. `dependency_fixture` owns only `test_dependency_consumer.py` for the
  coalescence fixture race; report production findings to parent. Parent owns
  runtime race review, runner fail-fast and planning/metadata. Preserve all
  assertions and deadlines unless execution evidence justifies a change. Focused
  modules stay the prior selection, plus developer-runner checks for CI edits;
  require exact green before implementing retained-manager behavior.
  Parent fixed waiter observation/removal races: only complete claim disappearance
  permits coalescence and fresh caller probes; retained bad claims remain blocked.
  Portable regressions pass (consumer **11 passed/7 Linux skips**). Runner now
  stops after the first failed test, retaining complete selection for successful
  gates; developer-runner **24 passed**, selection/package **47 passed**. Affected
  static/planning/package checks pass. Installer callback correction and bounded
  timeout diagnostics are the next exact focused CI candidate; no acceptance yet.
  Fixtures are released and parent-reviewed: dependency **13 passed/7 Linux skips**,
  affected shell/Python lint/format/compile/syntax and whitespace passed. Runtime
  metadata regenerated. No worker remains active. Cost review: the last vendor
  behavior run took 366.64s, dominated by repeated known watchdog failures; first-
  failure termination avoids that repetition without reducing successful coverage.
- Previous candidate: `91cdfb1e511f2cc8f89b1d8d6cb5c832edaa4d43`, pushed and
  remote-verified. [Checks 38236908142](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38236908142)
  failed BusyBox: **267 passed/1 skip/6 failures/1 fixture error**; host/static
  passed. Receipt `.tmp/dependency-repair-ci-failed-3.log`. All six repair cases
  exit before view construction (`status=3`, phase unset); installer lacks its
  imported `shell` fixture. No job remains active. Parent owns that Python fixture
  registration; `prerequisite_inventory` owns bounded investigation/correction of
  early repair setup in the runtime libraries/bootstrap/probe and dependency/storage
  shell fixtures, with focused regression proof. No edits to the three plans,
  metadata, CI, entry or Python test modules without transferring ownership.
  Preserve all behavior/assertions; re-push the same focused selection and require
  exact green before implementing the retained-manager consumer.
  Source review proved fixture mode names were incorrectly used as executable
  names: `copy/link/remove/signal` now map to `cp/ln/rm/kill`. Parent imported the
  missing shell fixture and exercises adapter construction in portable syntax
  coverage. Bounded failure diagnostics retain unknown ownership. Runtime bytes
  are unchanged. Combined dependency/storage fixture checks: **20 passed/15 Linux
  skips**; affected lint/format/compile/syntax, planning and whitespace passed.
  Parent review passed and files are released. Cost review reuses required CI:
  vendor behavior 81.74s; retain distinct mount/process cases, no full rerun due.
- Previous candidate: `f99853c8fe39a34870875664b844711bfd69d290`, pushed and
  remote-verified. [Checks 38236283307](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38236283307)
  failed after statics and 246 host passes/28 skips: concurrency fixture controller
  exited 83 before its marker. BusyBox was skipped. Receipt
  `.tmp/dependency-repair-ci-failed-2.log`. Parent reproduced CPython rejecting
  directory stdin. The fixture now uses the parent UID, supplies the finite query
  receipt consumed by the real selector and reports bounded child diagnostics.
  Parent review passed; module pytest: **8 passed/7 Linux skips**, Ruff lint/format,
  Python compilation and embedded-shell syntax passed. File ownership is released.
  No CI job is active. Re-push the same focused selection and require exact green
  before advancing runtime implementation.
- Active repair candidate: `b85df486221a519cd291ebe31a1d92d50d7dfa7c`, committed,
  pushed and remote-verified on `develop`. Exact focused
  [Checks 38235446674](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38235446674)
  failed Ubuntu ShellCheck before behavior; BusyBox checks were skipped. Receipt:
  `.tmp/dependency-repair-ci-failed.log`. The two dependency shell fixtures now use
  explicit conditionals and direct `tail`, preserving every assertion. Parent diff
  review passed; `.venv/bin/pytest -q tests/test_dependencies.py`: **13 passed/7
  Linux skips**. Relevant shell syntax, ShellCheck/shfmt, planning and whitespace
  checks passed. Worker files are released; runtime bytes remain unchanged.
  Re-push the same focused selection and require exact green before new runtime work.
  No job is active or subgoal acceptance awarded.
- Previous branch/local/remote receipt: `develop` at
  `008ad84d5e64592b9462af501b33d0b2aa714284`. The integrated repair package below
  is now in progress; prior failed runs and candidate instructions in this section
  are historical. No CI is active or owed for the accepted S02.09 runtime.
- Current repair dirty-tree proof: parent ran `.venv/bin/pytest -q
  tests/test_dependency_selection.py tests/test_execution_tasks.py`: **48 passed**
  in 1.18s. This proves portable selection/stat parsing only; integrated repair,
  loss/cancellation, descriptor phases and Linux mount/process proof remain pending.
  Latest AGENTS finish-before-switch amendment passes planning/whitespace checks;
  AGENTS is 29,062 bytes, including the user's 3–5 minute unanswered hard-blocker
  pause rule. No additional acceptance, commit or push yet.
- Repair runtime/tests are now frozen after parent/analyst review. Worker targeted
  regressions pass **70 tests/14 explicit Linux skips**, 5.80s. Parent regenerated
  metadata and launched the combined focused runner on dependency, consumer,
  selection, task, install, prerequisite, native, storage/mount/keeper, package and
  platform modules. Command `7445` finished: **228 passed/46 platform skips/1 failed**,
  behavior 100.32s; all statics passed. Receipt `.tmp/dependency-repair-focused.log`.
  Failure is the existing native-admission/full-transaction fixture's 15s outer
  deadline during normal file publication (253 bounded probes completed), not a
  runtime hang. A narrow reproduction completed 213 probes before the same deadline;
  receipt intervals stayed below 0.20s, with normal copies/real fsync progressing.
  Immutable setup is already shared and these publication checks are required.
  Parent made only the outer fixture budget scale with payload count; per-operation
  2s supervision and all publication/failure assertions remain. Narrow proof passed:
  native/install consumer **1 passed**, 20.02s call; installer regression module
  **18 passed/1 Linux skip**, 75.88s. Receipts
  `.tmp/dependency-repair-native-budget.log` and `.tmp/dependency-repair-install-budget.log`.
  Relevant Python lint/format/compile and whitespace passed after that fixture-only
  change; prior shell/static evidence remains applicable. No local command remains.
  Required Linux proof still awaits the next exact focused CI; no full suite is due.
- Pre-push cost review: immutable package/tool/C builds are module-scoped; mutation,
  interruption and ownership cases retain fresh state. Real fsync/publication now
  costs 15–20s in the largest workstation cases; distinct failure proof is retained.
  ShellCheck was the largest local static step (over two minutes); avoid duplicate
  invocations and inspect the required CI timing before further cost changes.

- Latest accepted runtime: `2c6dfe16ab02d3e8c005851fbab2c7e67d4afeb8`, exact
  [Checks 38222000119](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38222000119).
  Parent verified all required job steps and focused selection: host **117 passed/1
  workstation-only skip**, vendor BusyBox **117 passed/1 same skip**; native loader,
  real TLS and mutation cases ran. Job 101s, host behavior 20.21s/vendor 45.21s.
  Receipts `.tmp/native-admission-ci.{json,log}`. S02.09 accepted; README/checklist
  receipt follows without claiming a separate runtime test for the docs commit.

- S02.09 `f9eb6b5acdeb2abbc8a70cc2c8d8c99d5c916ee7`, [Checks 38221588897](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38221588897): host/static green; vendor failed before probe execution because fixture symlinks resolved bare `busybox` against the checkout instead of the selected executable. Parent now derives every applet from the already-resolved shell fixture and asserts each is executable. Native focused local gate: 23 passed/1 Linux skip, 19.76s plus statics; `.tmp/native-admission-vendor-path-fix.log`. Failed receipt `.tmp/native-admission-ci-failed-3.log`; re-push same focused selection. Runtime admission is unchanged.

- S02.09 candidate `a0fdb2a6c33a68738e528c67769fc5d0ce39387b` was pushed/remote-verified; [Checks 38220282450](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38220282450) failed Ubuntu ShellCheck SC2015 before behavior, with BusyBox skipped. Parent changed the owned-context guard to an explicit conditional; semantics are unchanged. Corrective `tools/test.py --focused tests/test_native.py`: **22 passed/1 Linux skip**, 14.38s plus all statics; `.tmp/native-admission-lint-fix.log`. Failed receipt `.tmp/native-admission-ci-failed.log`. Re-push the same complete focused selection and wait for exact green.

- S02.09 final integrated local gate: `.venv/bin/python tools/test.py --focused tests/test_native.py tests/test_install.py tests/test_prerequisites.py tests/test_package.py tests/test_platforms.py` passed **112 tests/5 explicit Linux skips**, 56.47s, plus all static/planning/package checks on the reviewed dirty tree based on `ac6cb89`. Receipt `.tmp/native-admission-focused.log`. Runtime/tests are frozen and parent-reviewed; worker files released. Package metadata is regenerated. Commit with the matching focused-test trailer and push for required Linux supervision/loader and vendor applet proof; wait for exact green before more implementation. No full gate is due. Cost review: previous required job 94s; TLS setup is module-scoped with fresh mutable contexts and bounded requests, no duplicate full run.

- Branch: `develop`; current work is based on local/remote documentation receipt
  `ac6cb89643f2d689763c3eff57bd7bc42091e4bc`; tested keeper runtime is
  `a7fe16ce2503cf34920efe5034a22d319e54f948`.
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
