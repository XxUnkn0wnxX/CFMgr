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

**Finish and pause:** the user now explicitly requests completion of **S02.05 and
S02.08**, their focused local/exact CI gates, commit/push and a refreshed handoff,
then pause. Do not start another target afterward. Full suites remain reserved for
complete main-goal markers; this pause does not itself trigger a full suite.

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
(22.2%); Goal 3: 1/10. Focused-complete equals accepted; no additional completed
subgoal awaits CI. Partial storage/inventory proof earns no complete subgoal.

Standing publication/pause, progress and concise-documentation rules are consolidated
in AGENTS.md. Finish only the agreed two-subgoal pause boundary. Completed evidence
belongs in the checklist. The user reiterated the current-/opt mount/read-test and
saved-reference behavior in answer to the repeated storage question; apply that
decision below and do not ask for the same approval again.
Never leave a started library/subgoal half-finished to switch targets. Smallest
standalone subgoals come first on resume; avoid discretionary framework expansion.

## Working tree, refs and last gate

- Current candidate: `060583128c750c3cf1f2baf13c0ca961396ee085`, pushed and
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

## Ownership and next package

S02.09 files are released and accepted; no CI job is active. `prerequisite_inventory`
now owns one coherent **S02.05/S02.08 integrated repair** assignment; do not start
an unrelated helper package. Actual consumer: `cfmgr.sh --install` → bootstrap
prerequisite inventory → healthy no-op or bounded installed-opkg repair → fresh
post-inventory → existing installation transaction. The wider linked batch adds
S02.04 tunnel DNS, S02.06 selected reinstall and S02.08 saved identity/return cases.

Reuse guarded execution view and lifetime keeper. Parent/analyst design review:
- Parent approved PID/start-specific private preflight contexts so concurrent
  installers can reach shared repair coalescence; keep the exclusive JFFS claim,
  strict FD/path ownership and legacy retained `/tmp/cfmgr/install` blocker.
- Parent/analyst approved a repair-phase low-FD swap: source pin on FD0, preflight
  RAM pin on FD9, shared claim on FD5. After snapshots, native callbacks use stable
  RAM/claim pins and never require source FD0 inside read loops. Restore the same
  refs only after scratch FD4 is safely free; unresolved work preserves its phase.
  Once keeper release/reap frees FD3, hold the original context there across fresh
  post-inventory flock probes on FD4/5. Do not add a colliding high descriptor.
- No eval for descriptor closure. Use literal closure of known FDs, a regular
  copied-helper FD9 handoff closed after ash opens it, gate stdin then `/dev/null`,
  and admitted output only. Unexpected high non-CLOEXEC descriptors reject launch;
  positively identified CLOEXEC bookkeeping must disappear across exec. Recheck
  helper descriptors before ready/opkg. Source-proof any native ash uncertainty.
- Launch via fixed chroot/ready/gate helper; record direct PID/start/boot and verify
  rooted view plus closure of outside directory FDs/cwd before release to opkg.
- Scan every task/thread root through an opened FD and rechecked identity. Retained
  owned IDs and verified visible dynamic descendants are ownership evidence;
  unknown/detached/unreadable roots retain protection. Foreign-root lifetime pins
  require positive outside ancestry, are deduplicated, and never authorize cleanup.
- Reconcile **all** visible dynamic view mounts, including script mounts without a
  chroot. Pin verified ancestry/root before registration, preserve immutable guard
  layers, record ordered cleanup, and retain unknown substitutions/foreign layers.
- Keep long-action PID/deadline state separate from `cfmgr_probe_*` native probes.
  Verify all live threads before group signalling. Numeric kill is observational,
  not an atomic identity guarantee. Empty sweeps still need normal unmount proof.
- Direct opkg success with surviving script daemons is not quiescence. Bound cleanup;
  unresolved work retains claim/keeper/storage and prevents overlap. Completed
  ordinary failures release the claim and allow a bounded later-launch retry.
- Preserve normal configured feeds/resolution/scripts and active provider choice.
  Plain install may not repair an already-installed unusable tool; use scoped
  reinstall only for failed mapped requirements, preserving healthy tools.
  Pinned opkg `opkg_info_status_cmd` consumes only `argv[0]`; fixed per-package
  status queries are required (the test double must not invent multi-name support).
- No package-wide tiny file-size limit: normal transitive/package writes may be
  large. Discard opkg output to `/dev/null` and retain concise phase/exit receipts;
  do not create unbounded RAM diagnostics. Native probe bounds remain separate.
- Ensure required helper/parser code remains available from admitted private RAM
  if the original source or Entware volume disappears; never infer this from using
  native tool binaries alone.

Parent owns architecture, three plans, entry/metadata/CI integration and acceptance.
`opkg_supervision_review` is assigned a final read-only check of its five prior
findings plus loss-before-success ordering in the provisional runtime freeze;
no writes, tests or scope expansion. Parent integrates any material findings before
the combined focused local/CI gate. The runtime writer retains exclusive ownership.
That review is complete: the prior five fixes are present; writer corrected
fresh interrupt/deadline/storage admission before query/repair gates, cancellation
preservation when direct exit is zero, and unresolved optional-logger ownership.
Re-record action expiry before accepting terminal status, not after separate cleanup
consumes its own budget. Targeted regressions pass; parent reviewed these corrections.
`opkg_supervision_review` returned five material task-lifecycle findings; the writer
is fixing them. A short read-only follow-up checks the stable descriptor allocation
for read-loop callbacks and fresh post-inventory. Parent owns the final contract.
Worker exclusive files: new `modules/lib/dependencies.sh`, shared root/task
supervision in `modules/lib/execution_tasks.sh` when needed, and narrow
`modules/helpers/dependencies.sh`; existing bootstrap/probe/prerequisites/view/keeper
libraries; their dependency/install/storage/keeper tests and fixture files, plus
necessary native fixture config. Preserve accepted native admission behavior/tests.
Parent exclusive: `cfmgr.sh`, package metadata, workflow, `tests/test_package.py`,
all Markdown and acceptance. No overlapping writers. Worker must deliver the real
installer repair integration and focused tests, then stop/release files; no commits,
pushes, ticks, unrelated refactor or router execution. Notify parent before any
interface change outside this ownership. Focused integration gate will include new
dependency tests, prerequisites, install, native admission, storage/view/keeper and
platform metadata. Linux mount/process tests require exact focused CI; no full
suite is due. Native helper operations retain finite argv and separate long-action
state. Parent reviews source/call/failure paths before publication or next scope.
No router execution or release/version/default-branch change is authorized here.
`dependency_fixture` exclusively owns new `tests/test_dependency_consumer.py` for
portable native-work routing and descriptor/post-inventory regressions, using
explicit adapters for unavailable Linux admission. The runtime writer retains
`test_install.py`, real PID/mount-isolated repair/process tests and fixture changes.
The consumer worker also adds real Linux process/claim-wait coalescence proof in
that file; it owns no runtime or mount-fixture files. Existing consumer tests pass
8 cases locally; three actual cleanup/FD cases require Linux and remain pending.

`next_subgoal_review` returned a future closure map. The user's later boundary
supersedes its execution order: finish S02.05/S02.08, then pause; S02.04/S02.06
and other independent targets wait for resume. Bounded prerequisites are allowed
where needed to complete these two, without awarding unrelated subgoal credit.
Its current read-only follow-up assesses the smallest actual retained-operation
consumer needed for S02.08, using existing entry/config/storage/bootstrap contracts;
no edits, tests or new implementation target. Parent decides the integration design
after the repair gate. Writer ownership remains unchanged.

The user answered the repeated storage question by reiterating the required
mount/read test and saved reference. This settles the implementation direction;
no approval question remains pending. S02.08/S12.05 and section 2 now specify:
resolve current `/opt` every new operation; saved identity/location is a last-known
observation, not a permanent UUID/label lock. Re-admit rebuilt/replaced Entware,
report changes, preserve settings and validate required existing data. Pin one
identity during active work; recheck attachment/readability and cancel/report loss
through native system messages, with truthful cleanup-pending/delivery limits.
Completed bounded opkg status/config initialization supplies repair read evidence.
CFMgr writes use admitted guarded paths; normal installed-opkg scripts remain
enabled. Read checks and cancellation do not promise atomic prevention of fallback
writes through new aliases those scripts create. Do not restart an enforcement
redesign or repeat this question; finish implementation and the required proof.

`dependency_fixture` exclusively owns new `tests/fixtures/dependency_process.c`;
`prerequisite_inventory` released this file and retains all fixture build/integration
tests. Host-only static pthread helper modes: hold, TERM-ignoring daemon,
leader-exit with live thread, and mixed roots via a thread's `unshare(CLONE_FS)`.
CLI `MODE PID_RECEIPT [VIEW_ROOT]`; one canonical `TGID TID\n` receipt after state
is ready, no retained receipt/unrelated descriptors. Parent reviews C source;
Linux PID/mount-isolated integration is the required behavioral gate. Never run
this helper or mount tests on a router. No worker publication or acceptance.
Initial source review passed; parent requested bounded direct-child cleanup on
daemon setup failure before file release. Static Linux build/execution remain CI-only.
That fix is reviewed and the C file is now released to integration.
`dependency_fixture` released both portable test modules. Selection now passes
35 tests, including real opkg Conffiles/Description continuations and strict query
framing; Ruff passes. Task parsing initially passed 12/13; the final-LF correction
passes the two affected cases, with combined validation pending. Runtime
fixes and `test_dependencies.py`/Linux integration remain exclusively
with `prerequisite_inventory`; do not duplicate selector cases or overlap writers.
`opkg_supervision_review` performs read-only review of the implemented task/view
lifecycle and signalling paths while fixtures are written. Parent reviews controller,
bootstrap and selection; runtime edits stay with the implementation owner.

The prior guarded-view construction package used admitted storage FDs 6/7 and
the real ext4 fixture; its Linux proof is recorded in the checklist. The current
package adds the actual writer launch/supervision consumer. Preserve existing parser
interfaces. Filesystem architecture review is integrated.
Parent added matching-native BusyBox CHROOT/LN fixture applets for the actual view tests;
cache identity already includes this config. No new APT requirement or full run is needed.

The completed keeper package retains every owned mount before it is overlaid, using one ash child
with active function-redirection frames. Fixed FIFO requests use native `mknod ... p`
(pinned source verified); Linux O_RDWR FIFO opens do not block. Parent FD3 owns the
channel; scoped function redirection borrows/restores FD4 while transferring its
already-open mount reference. Verify incremental ACK plus complete held mount IDs,
PID/start/boot and resource headroom. Parent loss/EOF must not silently unwind pins.
Release only after independently proved quiescence, then normal view unmount.
Focused tests add `test_mount_keeper.py` to storage/view coverage; Linux proof needs CI.
Keeper implementation is reviewed and focused-local/CI-passed, with no complete
subgoal credit. Current integrated repair ownership is above.
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
  probes and bounded later-launch retry. S02.06 reinstall and S02.07 native recovery/safe Off remain unfinished.
  S02.09 capability/TLS/ABI admission is accepted; exact receipt is above.
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
only after quiescence, then never signal from that retired ledger. This ash/Linux contract now has keeper implementation and focused CI proof;
actual opkg ownership/supervision remains pending.
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

1. Finish the active real installer/repair integration fixture and parent review.
   Runtime metadata was regenerated after the provisional runtime freeze; rerun
   generation if later reviewed runtime changes invalidate it.
2. Complete S02.08 saved-observation revalidation and eligible returning-work
   behavior through actual consumers. Preserve the settled storage policy above.
3. Run focused local/statics, parent-review, commit/push. Required Linux/BusyBox proof
   uses the focused CI route in AGENTS, then wait for exact green before advancing.
   No full run or main-goal tick is due now. Update checklist/README gate status.
4. Once both agreed subgoals pass, update acceptance/README and the handoff, ensure
   no required worker or job remains active, and pause. Start no further target.

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
