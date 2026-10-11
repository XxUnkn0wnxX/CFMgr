# CFMgr project instructions

Global instructions and matching skills apply. This file contains standing work
rules; detailed product behavior belongs in the v2 specification. Explicit user
instructions take precedence.

## Planning documents and parent ownership

Read these on session start and resume:

1. [PLAN_V2.md](PLAN_V2.md): product scope, main goals, subgoal tables and edge cases.
2. [PLAN_V2_checklist.md](PLAN_V2_checklist.md): matching goals/subgoal IDs, acceptance and delivery status.
3. [PLAN_V2_handoff.md](PLAN_V2_handoff.md): concise current notes, exact resumable state, active ownership and next actions.

The **parent exclusively maintains all three files**. Workers return findings and
evidence for parent integration; they do not edit these documents. Keep workflow,
coordination and publication rules here, not duplicated throughout the plan.

Every approved plan addition, removal or change must update the matching checklist
sections/subgoal IDs and acceptance in the **same edit**. Update handoff when it
changes current work, decisions or next actions. Check both directions for missing,
stale or contradictory items. Mark proposed scope changes as proposed until the
user approves them; never silently rewrite scope to match a deviation in code.

**A significant change to an objective, feature behavior, scope or accepted edge
case requires user approval before the parent or any worker applies it.** Explain
what would change, why it is needed, its impact/tradeoffs and the proposed plan/
checklist adjustment. Do not treat a material behavior change as a minor internal
detail or rewrite acceptance to avoid that approval.

Agents may automatically make implementation refinements and corresponding plan
clarifications within the approved feature scope when its main objective and
behavior are not significantly altered. Parent ownership and checklist mirroring
still apply. Changes the user explicitly requests are already approved: implement
those requested X/Y/Z changes without asking again. Routine status/evidence notes,
formatting and link corrections also need no repeat approval. Keep proposals that
do need approval separate from accepted scope until the user decides.

Keep the specification free of progression diaries/checkpoint receipts. Checklist
mirrors its main-goal/subgoal table structure; handoff is current working notes,
not another specification or accumulating transcript. Git retains old snapshots.
Preserve [.old/PLAN.md](.old/PLAN.md) as reference, never an active roadmap or reason
to resume archived milestones. Only `PLAN_V2_handoff.md` stores the hidden session-ID
record, beginning with the verified v2 starting session. The parent appends each
actual verified new session there and preserves the accumulated IDs when refreshing
handoff notes. Do not import the old session list or invent IDs. Keep these IDs in
Markdown comments in handoff, never in the specification or checklist.

Follow the authorization and current stage in handoff. For authorized recovery,
use this sequence: **salvage useful behavior into the new shared runtime in the
existing folder structure; remove superseded code and finish selected checklist
requirements; then rebuild tests, CI and developer tools; reconcile documentation;
validate and record the baseline before ordered feature implementation**.
Rewrite the entry as needed. Temporary staging of legacy modules under `.old/`
is permitted, but remove those modules before the recovery completion pass;
preserve `.old/PLAN.md` and retained private evidence. Do not leave compatibility
wrappers or unused old libraries simply to preserve old tests. Full test/tool/CI
reconstruction follows runtime salvage; keep focused safety/static checks with
runtime changes without maintaining obsolete test interfaces.
Do not ask again for permission already recorded in the handoff. Open product
defaults/capability proofs and significant feature changes retain their normal
decision gates. During salvage, retain code only when it completes an entire existing subgoal
through a real consumer; shared support needs a completed retained consumer.
Drop partial features, even if their isolated tests pass. Existing components/tests
receive acceptance or completion credit only from verified complete behavior. A handoff request does not start work reserved for
the next session during the current pause.

## Real completion and publication

- Develop on `develop`; reserve `main` for separately authorized stable releases.
- Each subgoal requires written focused tests passing locally. If its proof needs
  BusyBox/Linux/kernel CI, keep it pending until the relevant exact-commit CI
  passes. An early push may be proposed for that concrete evidence need; it still
  needs explicit user approval outside an already eligible main-goal checkpoint.
- The recovery publication requires the complete-subgoal audit, removal of
  rejected runtime/tests/tools, documentation reconciliation and reviewed local
  checks. No runtime area met the final retention rule: this baseline is planning
  only, so its local/CI checks confer no product acceptance. The user authorized
  publishing this cleanup after history reset. Normal implementation publication
  follows main-goal checkpoints or an explicitly approved earlier subgoal CI gate.
  Local reviewed commits are permitted. Exact full green CI gates product ticks.
- The user authorizes recovery to reset **local develop history** after the
  reviewed salvage baseline: preserve a verified private recovery bundle and
  make the recovered tree a new root. This session remains salvage-only; ordered
  goal 1 work is reserved for the next session. The user also authorizes publishing
  the recovered develop history after code/tests/docs pass, using an exact
  force-with-lease guard. Main and tags are outside this operation. Record exact
  old/new refs and recovery instructions in the handoff/private receipt.
- Before that push, audit the complete publishable tree for superseded runtime,
  old test suites, obsolete tools/CI references and temporary `.old/` code/test
  copies; all must be gone. Retain only recovered/reworked current implementation
  and its new tests/tools/CI. The explicitly preserved archived plan and private
  ignored evidence are references, not shipped legacy code. History rewriting
  remains a separate decision and cannot substitute for this tree cleanup.
- 100% means the approved CLI product is implemented, integrated, validated and
  ready to use within declared support. Library merging/consolidation belongs to
  the authorized recovery stage. Optional final documentation polish and broad
  optimization may follow 100%. The user permits either a recovery guide rewrite
  or removal of stale guides while retaining an accurate README/main-goal table
  and planning files; full practical guides remain required for usable 100%.
  Efficient tests and required safety validation precede ordered feature work.
- Product completion is **completed main goals / 16 × 100**: each fully completed
  approved main goal contributes 6.25%. Required subgoals and their evidence must
  all be complete before its main tick. Optional/out-of-scope items do not add
  goals. Partial subgoal work is visible but does not add product percentage.
  Salvage workload percentage is a separate temporary estimate.
- Main-goal checkpoints replace the former 1%/10% cadence. At a subgoal use focused
  tests, relevant lint/static/whitespace checks and parent integration/review;
  local commits may follow. Do not run full suites for each helper, worker or
  subgoal merely because it finished.
- A main-goal completion candidate requires **full local and full CI suites**,
  review of accumulated cases/parameters/fixtures/runners and test cost, relevant
  documentation updates and the scope-drift review below. Run full CI on every
  eligible checkpoint push and require green for that exact commit before its
  main tick or further implementation; fix/re-push failures within the checkpoint.
- For an explicitly approved earlier subgoal CI push, relevant BusyBox/kernel
  evidence must pass before the subgoal tick. The workflow may still run the full
  CI suite. This does not require a full local suite for an otherwise focused
  subgoal, and does not earn an incomplete main-goal tick.
- Use the `zr0-test-efficiency` skill for low CPU/load, meaningful coverage, fixture
  reuse and cost decisions during recovery and normal work. Pass it to each
  test-writing agent. Recovery retains its one reviewed final full local baseline.
- After each completed main-goal checkpoint, record a clean handoff with exact
  evidence, completed/16 percentage, remaining requirements and rough next scope.
  Continue authorized work subject to explicit pause/session/publication gates;
  do not invent numeric 1% or 10% checkpoints or stop after an internal package.
- Assign the first release version at usable 100%, then beta. No milestone version
  bumps; settle beta ordering/upgrade rules before packaging. Stable promotion,
  release publication and live deployment require separate authorization.

## Mandatory scope-drift check

At **every main-goal completion checkpoint**, the parent must fact-check actual user entry paths,
runtime behavior/integration, test assertions, documentation, checklist acceptance
and the completion claim against `PLAN_V2.md` and explicit accepted user amendments.
Helper existence, test totals and commits do not establish a delivered workflow.

If drift is found, **immediately notify the user where it happened, what differs,
its impact on completion, and the correction**. Fix the affected implementation,
tests, docs, checklist or estimate and revalidate before further development.
Never silently change the specification to legitimize drift. If correction needs
a new user scope decision, state the concrete choice and keep affected work gated
until it is decided. Record the review/correction in checklist and handoff. Report
drift discovered earlier immediately rather than waiting for the next milestone.

## Delegation and integration

Concurrent independent work is authorized here; apply the parallel-execution
skill. Before delegation the parent records exclusive files, shared contracts,
dependencies and validation/integration gates in handoff. Never overlap writers.
Use global routing with these CFMgr-specific overrides:

| Role | Project use |
| --- | --- |
| Parent | Architecture, uncertain root cause/security judgment, all three planning files, integration and final review. |
| `worker_strong` | Substantial runtime/cross-file changes, process ownership, interruption, storage safety and uncertain compatibility; keep tightly coupled essential regressions together. |
| `worker` | Bounded tests/fixtures, routine refactors/support and clear simpler runtime functions. Independent code/tests may run concurrently only with stable contracts and separate ownership. |
| `worker_alt` | Optional tiny fully specified mechanical fixes when faster than the handoff; never investigation or a capacity workaround. |
| `explorer` | Quick bounded read-only mapping/review; no implementation, tests or extended investigation. |
| `analyst` / `deep` | Deliberate difficult review or exceptional critical reasoning where the active profile supports it; not mandatory second passes. |
| `awaiter` | Monitor an already-running long job to terminal state only; no launching, diagnosing, editing or rerunning. Use shared log/exit paths. |

Normally at most two active implementation packages; a third only with settled
interfaces/dependencies and easy integration. Finish the active set before its
combined checkpoint. Custom workers must not spawn agents. Inspect/reuse existing
threads on resume. Respect active model/profile/tier and report unavailable roles.
The parent must review each finished package and its validation before assigning
the next task/worker. Review and integrate the combined active set before starting
the dependent next stage; do not let a worker self-advance through pending work.

The parent reconciles code/test discrepancies against approved behavior and source
evidence, never by assuming one is right or weakening assertions to fit code. Tiny
understood fixes may be parent-owned after explicit ownership transfer; broader
runtime work stays with the appropriate worker. Finalize/review code before guides;
any later fix requires documentation reconciliation. A worker may exclusively own
guides, but the parent owns plan/checklist/handoff.

## Validation and documentation

Use `zr0-test-efficiency` for general test procedure/tradeoffs and pass its path and
applicable requirements explicitly to workers. Prefer real consumers, reusable
immutable setup with fresh mutable state and representative integrations. Preserve
meaningful interruption, ownership, recovery, byte-framing and BusyBox/platform
coverage. Historical test counts are not targets. Review cost before each develop
push and after roughly three batches using existing timings; no extra full run
solely to measure cost. Do not claim skips/timeouts as passes or mask faulty code.

The current recovery baseline contains no runtime or runtime test suite.
`python3 tools/check.py` and CI validate planning documents only; they deliberately
reject newly added runtime until the gate is replaced. Do not report them as full
local/runtime/BusyBox passes or use them to tick a product subgoal.

When implementation resumes, reuse `.venv` if suitable and recreate the required
pinned developer dependencies and focused/full runner alongside the first real
workflow. Python/pytest/lint/format tools remain developer-only. Restore meaningful
shell syntax, ShellCheck, shfmt, focused tests and required BusyBox/kernel proof
for the code actually delivered. Use `zr0-test-efficiency`, modest worker counts
and owned isolated fixtures. The full runner must not commit/push/watch CI.
Eligible develop pushes/PRs require the applicable full CI; documentation-only
work uses proportionate checks. Do not widen CI to main or promote runtime for
convenience.

README summarizes **all main product implementation goals** covering the detailed
subgoals in v2. Keep a concise warning, main-goal table, quick scope points and guide
links with tasteful visual polish. Distinguish intended from available behavior;
no helper-based progress, unsupported installer or unearned completion labels.
CFMgr WebUI is optional future work, outside current scope/checklist/percentage.

Follow the recovery documentation option recorded in handoff. Maintain accurate
README scope and status throughout; link only to retained guides. If stale guides
are removed, keep interim developer/tool notes small until most or all goals are
met. README remains the implementation overview. Build full architecture,
developer and operating guides near product readiness, before claiming 100%;
do not preserve outdated guidance simply to satisfy a file list. Apply the same
GitHub documentation skill to temporary notes and full guides. Review
retained README/guides at each main-goal checkpoint, recording deferred or justified unchanged
files in handoff. No checkpoint/test/commit history in operating guides. Apply the
documentation skill and sanitized examples/screenshots.

During recovery, keep focused validation with each coherent code/test change;
complete the test-cost review and test rework before running the full local suite.
Apply the agreed documentation rewrite/cleanup after code/tests/CI/tools stabilize,
then finish the applicable local baseline and documentation checks. With all
runtime discarded, the current gate is planning-only; previous tests for removed
code supply no acceptance. Required BusyBox/kernel/full runtime proof must return
with new runtime work. Never invent a completed main goal merely to publish
recovery work. Follow the current publication authorization in handoff.

## Runtime and safety boundaries

- Follow the detailed v2 contracts. Router runtime is BusyBox-compatible POSIX sh,
  CLI-only, with no Python/venv. Keep features directly in `modules/`, libraries/
  parsers in `modules/lib/`, workers/updaters/bootstrap in `modules/helpers/`, thin
  hooks/templates in `modules/hooks/`. Use explicit small interfaces/imports, no
  arbitrary auto-loading or source-time execution. Reorganize coherently with
  callers, manifests, tests and docs when responsibilities justify it.
- Distribution keeps root `cfmgr.sh`/`catalog.txt`; installed entry is
  `/jffs/scripts/cfmgr.sh`, modules/support/catalog under `/jffs/addons/CFMgr.d/`.
  Generate private extensionless config from code-defined defaults only after
  retained setup checks; no public config/template. Preserve complete verified
  package generations and settings under v2 contracts. Source selection belongs in
  main config; developer mode preserves that selection, while catalog is replaced
  with the selected verified package. Group shared code by reused responsibility;
  do not turn each helper into a separate library or expand a monolithic entry.
- Use normal installed opkg for missing/unusable mapped requirements, preserving
  healthy tools; routine upgrades are user-managed. Selected force reinstall is
  separate from Cloudflared maintenance. Do not build placeholder callers or more
  unrelated helpers instead of delivering the current usable workflow.
- Primary read-only reference is original `cloudflared/setup/`, located through
  ignored `.tmp/reference-paths.md`; captured router files are supplemental. Keep
  workstation paths, live config/credentials and raw private evidence out of Git.
- Before affected Merlin storage/hooks/scheduling/install/removal design and at
  milestone reviews consult official [Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
  [User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts),
  [Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
  and relevant feature guidance. Match firmware source/capability; current wiki
  examples do not prove older targets. Record accepted design in plan and evidence
  limits in checklist/handoff. Other add-ons are supplemental examples.
- Reuse ignored `.tmp/firmware-audit/INDEX.md` only after checking exact revision,
  hash/cache/scope. Never commit firmware/extracted/raw audit/provenance or execute/
  flash it. Static images/source, host/BusyBox CI and live acceptance stay distinct.
  Completion does not authorize deletion of retained evidence.
- Standing router access is brief, lightweight and read-only via native `/bin/sh`;
  close sessions after reads. No live install/package execution, mount/chroot,
  stress/pytest, service/settings change, deployment or provider write without
  explicit separate authorization. Preserve unrelated integrations and secrets.

## Pause and handoff

On pause/stop, start no new package. Finish only the agreed safe current boundary,
stop required work and record exact commits, checks/skips, uncommitted files,
agent/command state, unresolved findings and next actions in checklist/handoff.
Leave no required worker/job active at completed handoff. Resume only within the
user's instruction and current gate.
