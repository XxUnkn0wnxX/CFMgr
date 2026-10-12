# CFMgr project instructions

Global instructions and matching skills apply. This file contains standing work
rules; detailed product behavior belongs in the v2 specification. Explicit user
instructions take precedence.

## Planning documents and parent ownership

Read these on session start and resume:

1. [PLAN_V2.md](PLAN_V2.md): what the product must do, with stable goal/subgoal
   IDs, behavior, edge cases and explicitly open product decisions. No current
   progress, worker assignments, test receipts or session instructions.
2. [PLAN_V2_checklist.md](PLAN_V2_checklist.md): the matching requirements,
   acceptance cases, completion boxes and concise accepted evidence. No execution
   diary, active worker queue, historical cleanup story or publication permission.
3. [PLAN_V2_handoff.md](PLAN_V2_handoff.md): current task and authorization limits,
   exact resumable state, active ownership, pending proof, blockers and next steps.
   Replace stale working notes instead of accumulating another specification.

The **parent exclusively maintains all three files**. Workers return findings and
evidence for parent integration; they do not edit these documents. AGENTS.md owns
standing workflow, coordination, validation and publication rules. Keep each fact
in its owning document and link to it; do not create a competing plan or handoff.
Current explicit user instructions override stale file text and memory. Reconcile
conflicts before affected work; a worker report or handoff cannot invent approval.
Explicit user decisions about the plan, goals and checklist are binding project
requirements. Preserve their full meaning when recording them; do not dilute an
amendment through an agent interpretation, implementation shortcut or test change.

Every approved plan addition, removal or change must update the matching checklist
sections/subgoal IDs and acceptance in the **same edit**. Update handoff when it
changes current work, decisions or next actions. Check both directions for missing,
stale or contradictory items. Mark proposed scope changes as proposed until the
user approves them; never silently rewrite scope to match a deviation in code.

**A significant change to an objective, feature behavior, scope or accepted edge
case, or extensive feature rework, requires user
input and approval before the parent or any worker applies it.** Explain
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

For required approval, ask one clear question showing the concrete proposed
change, reason, tradeoffs and affected plan/checklist IDs. Use the available
question/input tool when suitable. Prepare the reviewable proposal first, but
do not apply the gated change while waiting. Continue only independent work that
is already authorized. Allow a reasonable response window (about a minute for a
simple choice, longer for a complex proposal); if unanswered, record the pending
question and safe resume point in handoff and end the turn waiting for the user.
Silence, elapsed time, an empty tool response or a preselected option is never
approval. Resume the affected work only after an explicit answer authorizes it;
do not repeat an already answered permission question.

Keep the specification free of progression diaries/checkpoint receipts. Checklist
mirrors its main-goal/subgoal table structure; handoff is current working notes,
not another specification or accumulating transcript. Git retains old snapshots.
The parent may automatically trim, reorganize or rebuild a messy/stale handoff
without separate approval for that housekeeping. PLAN_V2.md and its checklist
remain the sources of truth for requirements and accepted status, subject to the
latest explicit user amendments. A handoff refresh cannot redefine them, invent
approval, award ticks or discard work. Preserve current authorization limits,
unanswered questions, unresolved blockers/proof, active owners/jobs, uncommitted
work and necessary recovery references while removing superseded narrative.

If context is lost or the handoff conflicts with evidence, pause affected changes
and re-audit the relevant codebase before rebuilding it: read the specification
and checklist, inspect actual entry/consumer paths, Git refs/diffs and unfinished
files, and verify the relevant tests/CI receipts and worker/job state. Run focused
checks only where needed to resolve uncertainty; do not launch a full suite just
to reconstruct notes. Rebuild the handoff from verified findings, mark unresolved
facts unknown and report any scope/status discrepancy. Do not silently rewrite
the plan/checklist to fit code or copy stale completion claims into the new notes.

Preserve [.old/PLAN.md](.old/PLAN.md) as reference, never an active roadmap or reason
to resume archived milestones. Only `PLAN_V2_handoff.md` stores the hidden session-ID
record, beginning with the verified v2 starting session. The parent appends each
actual verified new session there and preserves the accumulated IDs when refreshing
handoff notes. Do not import the old session list or invent IDs. Keep these IDs in
one HTML comment block immediately below the handoff title, hidden in rendered
Markdown, never in the specification or checklist. Preserve that entire existing
block through every trim/rewrite, and append only newly verified actual parent
session IDs; child IDs or a new turn/compaction do not establish a new session.

## Implementation sequence and preservation

Follow the active task and session boundary in handoff. Preparing instructions or
writing a handoff does not start implementation reserved for the next session.
Do not repeat completed cleanup, history resets or branch deletion from old notes;
those were one-time actions, not standing permissions. Do not ask again for an
action still covered by the user's current authorization.

Before each implementation package, identify its existing Sxx.yy requirements,
observable entry/consumer, dependencies, missing behavior and focused acceptance
checks in handoff. Inspect existing code/tests and current worker ownership first
so the package reuses relevant work instead of recreating it. Start with the
requested main goal and follow the necessary dependency order. If completing a
goal or point requires another goal first, notify the user of that dependency
and the new focus before switching to the prerequisite main goal. This
dependency-driven switch is authorized without repeat approval; record the
active focus and return path in handoff. Goal numbers do not impose an impossible
execution order. Goal 1 includes all three features and source parity: it cannot
be completed by a menu skeleton, and its dependencies must not be blocked until
goal 1 is ticked. Dependency work earns only its verified credit and does not
broaden product scope or weaken any completion/publication gate.

Build coherent workflows with only the shared support they need. Group libraries
by reused responsibility under the specification's folder layout; do not grow an
unconnected helper catalogue or a monolithic entry. A partial implementation is
**work in progress**, not a completed subgoal and not a deletion instruction.
Preserve useful work and record the concrete remaining integration/tests. Complete
the missing behavior before seeking its tick. Do not invent smaller product
subgoals, weaken acceptance or call a scaffold a feature to manufacture progress.

Review and checkpoint each coherent package locally before advancing. A passing
package may be committed as partial work with an honest message and unchecked
product status. Interrupted work must remain recoverable with its known failures;
never delete it just to leave a clean tree or passing gate.

Before any authorized destructive replacement, bulk code/test deletion or history
rewrite, stop affected writers and preserve the **actual current work**: committed
history plus affected staged, unstaged and untracked source/tests and any needed
ignored artifacts. Verify the saved file inventory and content against the working
tree, and record the private recovery location and restore method in handoff.
A Git bundle/ref protects commits only;
it does not back up uncommitted rewrites or untracked new files. Keep private
snapshots ignored and protect existing reference/firmware evidence. If a complete
snapshot cannot be verified, do not proceed with destruction.

Ordinary reviewed replacement/removal of superseded files within an authorized
package may proceed after preserving the affected work and verifying consumers
and meaningful regression coverage. Abandoning a feature, deleting an unfinished
subsystem wholesale, changing the accepted delivery objective, or another history
reset requires explicit authorization covering that concrete action. Prior
salvage permission cannot supply it. Missing acceptance is a reason to finish,
defer or report a blocker, never sufficient evidence that the source is useless.

## Evidence and truthful reporting

- Treat specifications as requirements, source inspection as source evidence,
  worker reports as claims to review, and executed tests as evidence limited to
  their actual inputs/platform. Never substitute one for another.
- Before calling a workflow implemented, trace its real entry through shared
  code to the observable result and inspect its failure paths. Before a tick,
  confirm every clause of that subgoal, relevant acceptance cases and integrated
  tests. Helper presence, mocks, test totals and static checks cannot prove an
  absent production consumer.
- Record exact commands, tested revision or dirty-tree state, pass/fail/skip
  results and platform limits. Verify a CI run's full head SHA and all required
  jobs; queued, skipped, cancelled, old or failed runs are not a current pass.
  Later relevant edits invalidate affected earlier proof and require rechecking.
- Distinguish planned, implemented-but-unverified, focused-local-passed,
  platform-pending and accepted. Keep uncertain facts explicitly unverified;
  investigate source/tool contracts rather than inventing commands or defaults.
- Report loss, regression, drift and unfulfilled outcomes immediately. A task
  completed administratively is not a successfully delivered feature or salvage.
  Never describe a backup as preserving work outside its verified contents.

## Real completion and publication

- `develop` is the only active branch and the repository default until the
  project reaches reviewed 100%. Do not recreate local/origin `main` or change
  the default during implementation. The planned return to
  main is an explicit readiness-time action; releases still need authorization.
- Each subgoal requires written focused tests passing locally. If its proof needs
  BusyBox/Linux/kernel CI, keep it pending until the relevant exact-commit CI
  passes. Local proof that cannot run on this host stays explicitly pending;
  do not call a platform skip a focused pass.
- Publication follows an eligible main-goal checkpoint or an explicitly approved
  earlier CI gate. Reviewed local commits do not imply push permission. Do not
  carry one-time cleanup/publication grants into unrelated later work. Verify
  exact remote state after an authorized push; never rewrite history or recreate
  main as an incidental implementation or CI repair.
- 100% means the approved CLI product is implemented, integrated, validated and
  ready to use within declared support. Coherent shared libraries, efficient tests,
  required safety validation and practical guides are part of delivery. Optional
  final documentation polish and broad optimization may follow 100%.
- Product completion is **completed main goals / 16 × 100**: each fully completed
  approved main goal contributes 6.25%. Required subgoals and their evidence must
  all be complete before its main tick. Optional/out-of-scope items do not add
  goals. Partial subgoal work is visible but does not add product percentage.
  Task-workload estimates are separate and clearly labelled.
- Progress updates must name the active main goal and give its estimated progress
  toward **that goal's 100%**, with a short account of what is done and what remains.
  Update the estimate at meaningful changes and in checkpoint/final reports;
  explain stalls or revisions instead of manufacturing percentage gains. Keep it
  distinct from the overall completed-goals/16 product percentage and from
  package/task workload. Partial implementation may inform an explicitly labelled
  estimate, but never an acceptance tick. Goal progress reaches 100% only after
  every required subgoal, audit, local gate and exact full CI gate is accepted.
- Main-goal checkpoints replace the former 1%/10% cadence; a completed goal is the
  new publication milestone, not an invented numeric 1% increment. At a subgoal
  use focused tests, relevant lint/static/whitespace checks and parent review;
  each reviewed subgoal may be committed once its focused tests pass. Do not run
  full suites for each helper, worker or subgoal merely because it finished.
- Normal publication order is mandatory: **implement every required subgoal and
  pass its runnable focused local tests → audit the codebase, scope, accumulated
  tests/cost and docs → pass the full applicable local suite → push → pass full CI
  for that exact commit → award final subgoal/main-goal ticks → update and push
  README completion → fully refresh the handoff for a new session and pause**.
  Explicitly list any platform-only proof pending for that CI run. A candidate
  may be ready to push before those CI-dependent boxes can be ticked; this is not
  a circular requirement to obtain CI before the push that runs it. Keep the
  main goal and README incomplete until all required evidence is green.
- An earlier subgoal push is eligible **only when most of that subgoal's required
  behavioral proof needs Linux/BusyBox/kernel execution unavailable locally**.
  The user has authorized commit/push/wait for these BusyBox/kernel CI checkpoints:
  explain the concrete dependency, push the reviewed focused-tested package and
  wait for its required CI. No repeat permission question is needed within this
  authorization.
  Judge the meaningful focused proof, not a padded test count. A minority
  of platform cases, convenience or finishing a helper is insufficient. Otherwise
  wait for the full main-goal candidate and local gate above. An approved earlier
  push runs full CI and can close only the fully proved subgoal; it needs no
  additional full local run just for publication and cannot complete an
  unfinished main goal.
- After any authorized runtime checkpoint push, require its exact prescribed CI
  to pass before further implementation; if it fails, fix, commit, re-push and
  wait again until the required exact-commit checks pass. Keep CI paths, jobs and
  dependencies current as tests grow. This does not prevent dependency work
  before a goal is ready.
  Record accepted test/run SHAs with the ticks. A later checklist/README-only
  receipt references the tested code commit and remains documentation evidence;
  never imply its new SHA was already tested. Such receipts may follow within the
  same approved checkpoint using proportionate documentation checks.
- Use the `zr0-test-efficiency` skill for low CPU/load, meaningful coverage, fixture
  reuse and cost decisions. Pass it to each test-writing agent.
- After each completed main-goal checkpoint, record a clean handoff with exact
  evidence, completed/16 percentage, remaining requirements and rough next scope.
  After the accepted goal and README receipt are pushed, fully refresh handoff for
  a new session and **pause**; do not start the next main goal in that session.
  This user-requested pause is at the completed main-goal boundary, not after
  internal packages or invented numeric 1%/10% checkpoints.
- Assign the first release version at usable 100%, then beta. No milestone version
  bumps; settle beta ordering/upgrade rules before packaging. Stable promotion,
  release publication and live deployment require separate authorization.

## Mandatory codebase and scope audit

At **every main-goal completion checkpoint**, audit the accumulated active
codebase, not only the latest diff. This carries forward the former 10% audit
requirement at each full-goal gate, without adding a separate percentage trigger.
Complete the audit and its required corrections before the full local suite/push;
the main-goal tick and README completion still wait for exact full CI.

The parent must:

- Inventory implemented entry paths, feature modules, shared libraries, workers,
  hooks, tests/fixtures, tools and CI against existing requirements and consumers.
  Look for overlapping implementations, copied shared logic, duplicate worker
  effort, unused wrappers/helpers, abandoned paths and redundant test setup.
- Check that each responsibility has a clear owner and that real callers reuse
  the appropriate implementation. Similar names/text alone do not prove duplicate
  behavior; preserve intentional differences and distinct safety/platform proof.
  Do not force unrelated behavior into an abstraction just to reduce file count.
- Repair unjustified duplication or integration drift within approved scope,
  preserving current work and regression coverage. Extensive rework or a material
  plan/goal change requires the user's decision before applying it; keep the
  affected goal pending rather than deleting its unfinished implementation.
- Record concise audit scope, findings, fixes or justified retained differences
  in handoff. Put the accepted audit result/tested revision with the main-goal
  evidence in checklist. An unperformed audit cannot receive its checkbox.

Fact-check actual user entry paths, runtime behavior/integration, test assertions,
documentation, checklist acceptance and the completion claim against PLAN_V2.md
and explicit accepted user amendments. Reuse the already-required focused/full
gates to validate corrections; do not add a second full suite merely for the audit.
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

Every brief names the Sxx.yy scope, actual consumer, allowed files, agreed
interfaces, exclusions, focused checks and stop condition. Workers return changed
files, implemented versus remaining behavior, exact validation/skips and risks;
they cannot award ticks, expand scope, discard another package or publish work.
The parent reads the diff and relevant call paths, checks the evidence and resolves
discrepancies before accepting a result. Record that review and the next owner in
handoff; a worker's completion message alone does not close the package.

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

At the first runtime package, replace the temporary planning-only inventory ban
with meaningful focused/full runtime checks and required platform coverage; keep
the useful specification/checklist/link checks. Never delete valid implementation
to satisfy the temporary empty-tree rule, or bypass it without replacement tests.
Update the runner, CI and concise developer command notes together. Planning-only
CI cannot be called full runtime CI or used for product acceptance.

Reuse `.venv` if suitable and provide the required pinned developer dependencies
with the focused/full runner. Python/pytest/lint/format tools remain developer-only.
Use shell syntax, ShellCheck, shfmt, meaningful focused tests and required
BusyBox/kernel proof for the code actually delivered. Use `zr0-test-efficiency`,
modest worker counts and owned isolated fixtures. The full runner must not
commit/push/watch CI.
The **Checks** workflow targets develop pushes and pull requests, excluding
documentation, images and folder placeholders when they are the only changes.
Keep the planning consistency job running. The speculative code-path list has
been removed; add relevant trigger paths as actual tests grow. As real tests are
written, add their commands, required dependencies and platform jobs in the same
package; do not defer CI wiring until a later goal. Keep documentation-only
changes excluded, and ensure code/test/tool/workflow changes run the required
checks. Authorized runtime pushes/PRs must run the full required suite. Any later
release-branch scope needs explicit review. Do not promote runtime for convenience.

CI configuration may be adjusted as approved implementation and tests grow:
maintain relevant triggers, jobs, supported platform coverage and modest resource
limits, validating each change. This adaptive permission is limited to CI; it
does not authorize changing agreed agent rules, plan/goals, checklist acceptance,
completion/publication gates or reducing required proof. Ordinary authorized
implementation and evidence/status updates continue under their existing rules.

README summarizes **all main product implementation goals** covering the detailed
subgoals in v2. Keep a concise warning, main-goal table, quick scope points and guide
links with tasteful visual polish. Distinguish intended from available behavior;
no helper-based progress, unsupported installer or unearned completion labels.
CFMgr WebUI is optional future work, outside current scope/checklist/percentage.

Maintain accurate README scope and status throughout; link only to available
guides. Keep interim developer/tool notes small until most or all goals are met.
README remains the implementation overview. Build full architecture,
developer and operating guides near product readiness, before claiming 100%;
do not preserve outdated guidance simply to satisfy a file list. Apply the same
GitHub documentation skill to temporary notes and full guides. Review
retained README/guides at each main-goal checkpoint, recording deferred or justified unchanged
files in handoff. No checkpoint/test/commit history in operating guides. Apply the
documentation skill and sanitized examples/screenshots.

Apply the same GitHub documentation skill to AGENTS.md and all three v2 planning
documents: clear headings, proportional detail, accurate claims, working links
and sanitized paths. Keep standing rules here, product contracts in the plan,
accepted status/evidence in the checklist and current notes in handoff.

Write behavioral tests with each coherent implementation package; the salvage-only
tests-last exception has ended. Finalize code and tests before describing their
behavior in guides. At each main-goal candidate review test cost and documentation
before the full local gate, then require the exact full CI gate. A documentation
consistency check cannot establish semantic correctness or runtime safety.

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
  package generations and settings under v2 contracts. Follow section 7: one
  trusted-entry repository/branch default serves install and self-update; config
  overrides apply only in developer mode. Derive module URLs from that effective
  source and one commit pin; catalog is replaced with the verified package.
  Group shared code by reused responsibility;
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
- Standing router access via `ssh router` is authorized for brief, lightweight
  read-only inspection. Single SSH commands or a background interactive terminal
  are permitted; close the session when its inspection work finishes. The router's
  default login shell is zsh: explicitly invoke `/bin/sh` for all BusyBox/POSIX
  commands and any separately authorized tests; never rely on the login shell.
  Workstation shell sessions remain `/usr/local/bin/zsh`; do not substitute the
  macOS `/bin/sh` for router validation. Host shell fixtures use a suitable
  resolved Homebrew shell, with host evidence distinct from BusyBox/Linux and
  actual router evidence. Read-only commands may
  inspect existing files, capabilities and runtime state.
  The user permits small, non-destructive command tests and their own temporary
  files under `/mnt/MERLIN/tmp`, with verified cleanup. Keep the `tmp` directory
  itself; create it if absent, but never remove it. Test writes must stay inside
  it. Its contents may be removed as needed for these tests; avoid unrelated
  removal when it serves no test purpose. This narrow exception
  does not cover JFFS or writes elsewhere, settings, services, installed files,
  package operations or stress tests. Preserve existing directory permissions
  and unrelated content outside the permitted test directory. Probe cleanup
  should still target its verified artifacts. Pass this boundary to any agent
  assigned router work.
  Other router writes, test execution, live package/code
  execution, install, mount/chroot, service/settings changes, deployment and
  provider writes require explicit user permission before execution. Preserve
  unrelated integrations and secrets.

## Pause and handoff

On pause/stop, start no new package. Finish only the agreed safe current boundary,
stop required work and record exact commits, checks/skips, uncommitted/untracked
work, recovery locations, agent/command state, unresolved findings and next actions
in handoff. Checklist receives only justified acceptance/evidence updates.
Leave no required worker/job active at completed handoff. Resume only within the
user's instruction and current gate.
