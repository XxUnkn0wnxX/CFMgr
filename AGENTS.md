# CFMgr project instructions

Global instructions and matching skills apply. Explicit user instructions override
stale files and memory. This file owns standing workflow; product behavior belongs
in the v2 specification. Keep this file below **32,000 bytes**: revise/consolidate
existing rules, avoid duplicate text and reference skills/plans instead of copying
their instructions. Check its byte size after edits.

## Planning authority

Read on session start and resume:

| Document | Sole purpose |
| --- | --- |
| [PLAN_V2.md](PLAN_V2.md) | Product requirements, stable goal/subgoal IDs, behavior, edge cases and open decisions; no progress or session diary. |
| [PLAN_V2_checklist.md](PLAN_V2_checklist.md) | Matching requirements/acceptance, completion totals/boxes, focused-test results, outstanding gates and concise accepted evidence. No handoff notes, session narrative, ownership, work queue, completion route, next actions or publication authority. |
| [PLAN_V2_handoff.md](PLAN_V2_handoff.md) | Current task, permissions, exact resumable state, ownership/jobs, pending proof, blockers and next steps; replace stale notes. |

Checklist mirrors the specification's main-goal/subgoal table structure.
The **parent exclusively edits all three**; workers return evidence. Preserve the
full meaning of explicit user decisions. Update every approved plan change and its
matching checklist IDs/acceptance **in the same edit**, checking both directions;
update handoff when current work changes. Never rewrite requirements to fit code,
weaken tests to manufacture compliance, or infer approval from a worker/handoff.

**Significant objective, behavior, scope or accepted-edge-case changes and extensive
feature rework require prior user approval.** Explain the concrete change, reason,
tradeoffs and affected plan/checklist IDs. Keep proposals separate from accepted
scope. Explicitly requested changes, routine evidence/format/link updates and
implementation refinements preserving approved behavior need no repeat approval.

Prepare a reviewable proposal before asking one clear approval question. While
waiting, do only independent authorized work. Allow a reasonable response window
(about a minute for a simple choice, longer for complex decisions); if unanswered,
record the question/safe resume point and end waiting. Silence, elapsed time, empty
responses and preselected options are never approval. Do not repeat answered gates.

Do not spend routine implementation effort trimming handoff. Trim completed notes
if it approaches **500–600 KB** or becomes difficult to follow; rely on the checklist
for accepted evidence. The parent may rebuild it without approval, preserving current
permissions, unanswered questions, unresolved proof/blockers, active jobs/owners,
unfinished work and recovery references. Audit source/receipts where needed instead
of duplicating history. If context or evidence conflicts, pause affected changes
and inspect actual entry/consumer paths, spec/checklist, refs/diffs, unfinished files,
test/CI receipts and agent state first. Use focused checks only where uncertainty
requires them, not a full suite to reconstruct notes. Record unknowns and report
scope/status discrepancies; housekeeping cannot award ticks or discard work.

Preserve [.old/PLAN.md](.old/PLAN.md) as reference only. Preserve the entire hidden
session-ID HTML comment immediately below the handoff title. Append only verified
new **parent** session IDs; no invented/imported old IDs, child IDs, or new entry
for a turn/compaction. Keep this record solely in handoff.

## Implementation and preservation

Follow the active handoff task/session boundary. Writing instructions or a handoff
does not start work reserved for a later session. Past cleanup, branch deletion,
history resets and publication grants are not recurring permissions.

Before each package, inspect existing code/tests and ownership; record its Sxx.yy
scope, actual entry/consumer, dependencies, missing behavior and focused checks in
handoff. Start with the requested main goal. When another goal is a prerequisite,
**notify the user before switching**, then record the focus and return path; this
switch is authorized without repeat approval. Goal 1 requires all three complete
features and source parity, not a menu skeleton. Dependency work earns only its
verified credit and never weakens scope or gates.

Deliver coherent workflows with shared support grouped by reused responsibility,
not disconnected helpers or a monolithic entry. Partial implementation is preserved
**work in progress**, not a completed subgoal or permission to delete it. Record
missing integration/tests; do not invent smaller product subgoals or lower acceptance.
Review/checkpoint each coherent package before advancing. Focused-tested partial
work may be committed honestly with product boxes unchecked. Preserve interrupted
work and known failures rather than deleting it to obtain a clean/passing tree.

Before authorized destructive replacement, bulk code/test deletion or history
rewrite, stop affected writers and preserve **actual current work**: commits plus
affected staged, unstaged, untracked and necessary ignored files. Verify backup
inventory/content against the tree and record private recovery location/restore
method. A bundle/ref preserves commits only. Keep snapshots ignored and retain
reference/firmware evidence; without a verified complete snapshot, do not destroy.

Reviewed removal/replacement of superseded files within an authorized package is
allowed after preservation and consumer/regression checks. Abandoning features,
deleting an unfinished subsystem wholesale, changing delivery objectives or another
history reset needs explicit authorization for that action. Missing acceptance and
old salvage permission cannot supply it.

## Evidence and progress

Trace the real entry through shared code to its observable result and failure paths
before calling a workflow implemented. Before acceptance, prove **every clause** and
relevant integrated case. Requirements, source inspection, worker claims, host tests,
BusyBox/kernel execution and live evidence are distinct; helpers, mocks, test counts,
static checks and commits cannot prove an absent production consumer.

Record exact commands, tested SHA or dirty-tree state, pass/fail/skip outcomes and
platform limits. Verify full CI head SHA and every required job: queued, skipped,
cancelled, old or failed runs are not a current pass. Relevant later edits invalidate
affected evidence. Distinguish planned, implemented-unverified, focused-local-passed,
platform-pending and accepted. Investigate uncertain source/tool contracts instead
of inventing commands/defaults. Report loss, regression, drift or unfulfilled outcomes
immediately; administrative completion is not delivery and backups protect only
verified contents.

Use three separate progress measures:

- **Product:** completed main goals / 16 × 100; each contributes 6.25%. Every required
  subgoal/evidence must pass before its main tick. Partial/optional work adds no
  product percentage.
- **Overall subgoals:** accepted product subgoals / total approved product subgoals
  × 100, equally weighted across all main goals. Derive both counts from the
  matching Sxx.yy specification/checklist rows (currently 157 total); count each ID
  once regardless of dependency order. Report fully focused-tested subgoals still
  awaiting required CI separately, without adding them to the accepted count.
  Helpers, partial packages, developer tools and optional future features earn no
  subgoal credit. Change the denominator only with an approved scope change.
- **Active goal:** fully implemented subgoals with passing written focused tests /
  required subgoals × 100, equally weighted. Name the goal, count, percentage and
  remaining work in meaningful updates and checkpoint/final reports. A focused local
  pass earns this progress credit while required CI acceptance remains explicitly
  pending. Skips, helpers and partial implementations earn none; if meaningful
  focused execution is unavailable locally, wait for focused CI. Cap at **99%** until
  all subgoals, audit, full local and exact full CI gates pass. Explain regressions;
  keep acceptance ticks and labelled package/workload estimates separate.

Meaningful progress updates and checkpoint/final reports include both main-goal
and overall-subgoal counts/percentages. Name the changed Sxx.yy IDs and their main
goals, what changed (implementation, focused proof, pending CI or acceptance), and
remaining proof. State the main goal currently being aimed for completion, the
supporting main goals/subgoals being worked through and the return path after a
prerequisite switch. Keep that route approximate when dependencies are unsettled;
do not imply every supporting main goal must finish first. Update checklist totals
and current handoff focus/route when acceptance or sequencing changes.
Keep the checklist's completion summary to overall main-goal and subgoal counts/
percentages; individual IDs, focused proof and outstanding gates stay in its tables.

100% means the approved CLI is implemented, integrated and ready for controlled
beta, with coherent libraries, automated safety tests and practical guides. The
development gate is representative Ubuntu/BusyBox evidence. Actual Merlin/ARM,
flash, hooks, TLS and live-provider qualification follows during an extended
real-router beta; keep support provisional until evidenced. Beta deployment and
stable/release publication still need explicit authorization. Optional final
polish/broad optimization may follow implementation completion.

## Validation and publication gates

Use `zr0-test-efficiency` as the general testing authority and pass its path/current
requirements to test-writing workers. Write meaningful behavioral tests with each
package, reuse immutable setup with fresh mutable state, and retain interruption,
ownership, recovery, byte-framing and required platform proof. Test counts are not
targets. Review cost before every develop push and after roughly three batches using
existing timings; no extra full run just for measurement.

Reuse suitable `.venv` and pinned developer dependencies. Focused/full runners must
include Ruff lint/format, Python compilation, shell syntax, ShellCheck, shfmt and
planning/link/whitespace checks alongside behavior. Python tooling stays developer-
only. Planning checks complement runtime proof; never remove valid runtime code to
satisfy an obsolete empty-tree rule. The full runner must not commit, push or watch CI.

Developer tools must work for other contributors and forks. Derive checkout paths;
never hardcode a developer's SSH alias, router address, login/key or mounted-drive
path. Router tooling reads those settings as data from ignored
`tools/router.local.json`; ship `tools/router.local.json.template` with fake values
and useful help. Require explicit execution intent and preserve scoped cleanup.
Keep private settings out of tracked files, test expectations and published output.
Ask the user before adding new developer-tool entries, requirements or scope to
the plan and checklist, showing the proposed text first. Existing approved-tool
evidence/status updates follow the normal focused-test and CI gates. Supporting
tool completion does not add product goals or inflate product percentages.

`develop` remains the only active/default branch until reviewed product 100%. Do not
recreate local/origin `main`, change the default, rewrite history or promote runtime
incidentally. Main's return is an explicit readiness action. Assign the first release
version at 100% implementation/beta readiness; no milestone bumps. Settle beta upgrade ordering
before packaging. Stable promotion, release publication and live deployment need
separate authorization.

Each subgoal requires written focused tests passing locally, relevant static/lint
checks and parent review; required unavailable platform proof remains pending until
exact focused CI. Keep focused-test results and outstanding acceptance gates in the
checklist. Keep checkpoints coherent and partial status honest:

| Checkpoint | Required sequence |
| --- | --- |
| Ordinary work with meaningful local proof | Focused local tests/statics → parent review → local commit → continue without pushing or pausing. |
| Required focused proof unavailable locally | Run available focused checks/review → commit and automatically push → exact focused CI pass → continue. No repeat permission needed. |
| Explicit pause after substantial subgoal work | Finish the subgoal → focused local checks/review → commit/push → exact focused CI pass → refreshed handoff and pause, as detailed below. |
| Complete main-goal marker | All subgoals → audit → full local → push → exact full CI → acceptance/README/handoff → pause. |

Full suites run only at complete main-goal markers, not per helper/worker/subgoal
or the retired 1%/10% cadence. A local commit alone is not a routine push trigger.

Mandatory main-goal checkpoint sequence:

1. Implement every required subgoal and pass runnable focused local tests; list
   platform-only proof pending CI.
2. Complete the accumulated codebase/scope/test-cost/documentation audit below.
3. Pass the full applicable local suite, then push the candidate.
4. Pass full required CI for that **exact commit**, close remaining CI-dependent
   boxes and award the main-goal tick. Pending platform boxes may wait for this
   push; already accepted focused subgoals do not trigger full suites themselves.
5. Update and push README completion, fully refresh handoff for a new session and
   **pause**. Record exact evidence, main-goal and overall-subgoal counts/percentages,
   remaining work and rough next scope; do not start another main goal in that session.

Focused pushes select the package and affected regressions through the validated
CI route: the final nonempty commit-message line is `CFMgr-Focused-Tests:` followed
by one to 16 distinct existing `tests/test_*.py` paths. Omit it for a full main-goal
candidate; PRs always run full CI. Unavailable Linux/BusyBox proof stays pending until that exact CI passes;
partial work earns no complete subgoal tick. If a required focused route is absent,
add and validate it within the approved package instead of substituting a full run.

After **any authorized runtime checkpoint push**, wait for its exact prescribed CI
before further implementation. On failure, fix, focused-test, commit/re-push and wait
again. Verify remote state after pushing and record accepted test/run SHAs with ticks.
Documentation-only receipts may follow within the same approved checkpoint using
proportionate checks; reference the tested code SHA, never imply the receipt SHA was
already runtime-tested. No unearned main-goal or README completion. The boundary pause
is after a completed main goal, not internal packages or numeric increments.

During tracing or repair of a shared CI failure, retrieve the first useful failed
log and cancel remaining redundant work promptly. This also applies if optional
kernel diagnostics are explicitly run; keep multiple profiles only to investigate
profile-specific differences. Optional kernel runs are not the acceptance gate.
Cancelled jobs supply no proof; acceptance requires the prescribed focused or full
Ubuntu checks green at the exact repaired SHA, according to the current gate.

## Mandatory main-goal audit

Before every main-goal full local gate/push, the parent audits the **accumulated active
codebase**, not only the latest diff:

- Map actual entries, modules, libraries, workers, hooks, tests/fixtures, tools and
  CI to requirements/consumers. Check clear ownership, shared-code reuse, duplicate
  work/logic/setup, unused wrappers and abandoned paths.
- Preserve intentional differences and distinct safety/platform proof; similar names
  do not establish duplication. Do not force unrelated responsibilities into an
  abstraction just to reduce files. Repair unjustified duplication/integration drift
  within approved scope, preserving work/regressions; substantial rework requires
  the scope approval above, not deletion of unfinished features.
- Fact-check runtime behavior, assertions, docs, acceptance and completion against
  the specification and user amendments. Review retained README/guides and test cost.
  Record concise scope/findings/fixes or justified retained/deferred items in handoff;
  put accepted audit result/tested revision with checklist main-goal evidence.

Use the already-required focused/full gates, not a second full suite for the audit.
An unperformed audit earns no checkbox. **Immediately report drift** wherever found:
location, difference, completion impact and correction. Fix and revalidate before
advancing; never rewrite scope to legitimize it. Keep newly gated decisions pending
user approval and record the review/correction in checklist and handoff.

## CI requirements

Keep **Checks** on develop pushes/PRs; exclude documentation, images and placeholders
when they are the only changes. Retain planning consistency. Add actual code/test/
tool/workflow paths, commands and dependencies **in the same
package as new tests**. Main-goal runtime checkpoints run the full required suite;
the early platform-proof exception runs its prescribed focused CI only. Preserve
explicit, reviewable selection so a focused pass cannot be mistaken for the full
main-goal gate. Later release-branch scope requires review.

Use one Ubuntu CI runner for full host integration and cached native-host vendor
BusyBox checks, including planning and static gates. These are representative
development tests, not a fake Merlin firmware installation. Do not make QEMU
kernel/ARM/firmware matrices mandatory per push, subgoal or main goal. Preserve
existing optional diagnostic tooling/fixtures/caches without treating unfinished
or cancelled guest work as passed. Real-router/provider beta follows completed
implementation; keep those evidence limits explicit without weakening runtime
safety contracts, focused/full testing or publication gates.

Adjust CI as approved tests grow, preserving coverage and modest resource limits.
This adaptive permission applies only to CI, not agent rules, goals, acceptance or
publication gates. Global CI and testing skills own the general procedures.

## Delegation and integration

Concurrent independent work is authorized; apply `zr0-parallel-execution`. Inspect/
reuse existing threads on resume. Before delegation, record exclusive files, shared
contracts, dependencies and integration/validation gates in handoff; **never overlap
writers**. Follow active global model/tier routing, with these project responsibilities:

| Role | Scope |
| --- | --- |
| Parent | Architecture, uncertain root cause/security decisions, three planning files, integration and final review. |
| `worker_strong` | Substantial runtime/cross-file work, process ownership, interruption, storage safety or uncertain compatibility; retain coupled regressions. |
| `worker` | Bounded tests/fixtures, routine support/refactors and clear simpler runtime functions. |
| `worker_alt` | Tiny fully specified mechanical fixes only; no investigation or capacity workaround. |
| `explorer` | Quick bounded read-only mapping/review; no edits, tests or extended investigation. |
| `analyst` / `deep` | Deliberate difficult review/exceptional reasoning where supported, not mandatory second passes. |
| `awaiter` | Monitor an already-running job to terminal state using shared logs/exits; no launch, diagnosis, edits, reruns or agents. |

Normally allow at most two active implementation packages; a third needs settled
interfaces/dependencies and easy integration. Custom workers must not spawn agents.
Finish the active set before its combined checkpoint.
Report unavailable roles. Every brief names Sxx.yy scope, actual consumer, allowed
files/interfaces, exclusions, focused checks and stop condition. Separate code/test
workers need stable contracts and disjoint ownership.

Workers return files changed, implemented/remaining behavior, exact checks/skips and
risks; they cannot award ticks, expand scope, discard others' work or publish. Parent
reviews diffs, actual call/failure paths and evidence before acceptance/next assignment,
records review/next ownership, and integrates the active set before dependent work.
No worker self-advancement. Resolve discrepancies against approved behavior/source,
never assume code/tests are right or weaken assertions to fit. Tiny understood fixes
may transfer to parent explicitly; broader runtime work stays with the suitable
worker. Finalize code/tests before guides and reconcile guides after later fixes.

## Documentation

Apply `zr0-github-documentation` to repository Markdown, including AGENTS and the
three planning documents: proportional detail, accurate claims, working links and
sanitized paths/examples/screenshots. Workers may own guides, never the three plans.

README remains the implementation overview: concise warning, a table of all 16 main
goals covering their subgoals, scope points and links to existing guides. Separate intended
from available behavior; no helper-based progress, unsupported installer or unearned
completion. WebUI is optional future work outside scope/checklist/percentage.

Update the README table as each subgoal's focused-test, required CI or acceptance
gate is validated; do not wait for a whole main goal to update subgoal progress.
Show in-progress status and accepted subgoals/total, distinguishing fully focused-
tested subgoals awaiting CI when applicable. Partial packages may remain visibly
in progress but never increase completed-subgoal counts. Keep rows concise and
put detailed evidence in the checklist. Mark a main goal complete only after its
full audit/local/CI checkpoint. Parent verifies worker evidence before these updates.

Keep `docs/development.md` short throughout implementation: essential required
tools, setup and built-in check commands only. Do not append progress, test-run
receipts, investigations, fixture internals, CI/publication procedure or session
decisions; rules belong here and working notes in handoff. Amend existing setup/
command text only when needed for usability; do not add interim guide sections.
Substantial developer documentation waits for the final **100% readiness stage**.
Complete the required practical guides at that stage before declaring beta readiness.
No checkpoint/test/commit diary in operating guides or stale text kept to fill a
file list. Documentation consistency proves neither behavior nor runtime safety.

## Runtime and reference boundaries

Follow detailed v2 contracts: BusyBox-compatible POSIX sh, CLI-only, no router Python/
venv. Features belong in `modules/`, shared libraries/parsers in `modules/lib/`,
workers/updaters/bootstrap in `modules/helpers/`, thin hooks/templates in
`modules/hooks/`. Use explicit small imports/interfaces, no arbitrary auto-loading
or source-time execution; reorganize with all callers/manifests/tests/docs together.

Keep root `cfmgr.sh`/`catalog.txt`; install entry at `/jffs/scripts/cfmgr.sh` and support
under `/jffs/addons/CFMgr.d/`. Generate private extensionless config from code defaults
only after retained setup checks; ship no public config/template. Preserve verified
complete generations/settings. Section 7's trusted entry supplies one repository/
branch default for install/update; config overrides require developer mode. Derive
module URLs from that effective source and one commit pin; replace catalog with its
verified package. Use normal installed opkg for missing/unusable mapped tools,
preserving healthy tools; routine upgrades remain user-managed. Selected force
reinstall is separate from Cloudflared maintenance.

Primary read-only reference: original `cloudflared/setup/` located through ignored
`.tmp/reference-paths.md`; captured router files are supplemental. Keep personal
workstation paths, live configuration/credentials and raw private evidence out of Git.
Before affected Merlin storage/hooks/scheduling/install/removal design and milestone
reviews, consult official [Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts),
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
and relevant feature guidance. Match exact firmware capabilities; current wiki
examples do not prove older targets. Other add-ons are supplemental. Record accepted
design in plan and evidence limits in checklist/handoff.

Reuse `.tmp/firmware-audit/INDEX.md` only after verifying revision, hashes/cache and
scope. Never commit firmware/extracted/raw audit/provenance, or execute/flash it.
Keep source/image, host/BusyBox CI and live evidence distinct. Completion does not
authorize deleting retained evidence.

## Router permissions

- Brief lightweight read-only inspection through `ssh router` is authorized, via
  single commands or a background terminal; close sessions when inspection finishes.
  It may inspect existing files, capabilities and runtime state.
- Router login shell is zsh: explicitly use the **router's `/bin/sh`** for BusyBox/
  POSIX commands and authorized tests. Workstation sessions remain `/usr/local/bin/zsh`;
  host shell fixtures use a suitable resolved Homebrew shell. macOS `/bin/sh` is not
  router proof; host, BusyBox/Linux and live evidence remain separate.
- Small nondestructive command tests and their own temporary files are authorized
  **only under `/mnt/MERLIN/tmp`**, with verified cleanup. Create that base if absent,
  but never remove it; preserve existing permissions. Writes stay inside it. Contents
  may be removed for tests, but target verified owned artifacts and avoid pointless
  unrelated removal. Preserve content/permissions outside it.
- This exception excludes JFFS/other paths, settings/services, installed files,
  packages and stress tests. Other router writes/test or live code/package execution,
  installs, mounts/chroots, service/settings changes, deployment and provider writes
  require explicit user permission **before execution**. Preserve unrelated
  integrations/secrets and pass these boundaries to every router-assigned agent.

## Pause and handoff

An explicit pause request overrides the normal main-goal stopping boundary. Start
no unrelated subgoal/package; use the amount of work already done to choose the
last acceptable checkpoint:

- **Barely started:** the user permits dropping that small new subgoal attempt
  and resetting its owned changes to HEAD. Inspect the diff/ownership first and
  follow the preservation rules above. Scope the reset/removal to that attempt;
  preserve unrelated changes, prior validated packages and untracked/private data.
  Do not reset the whole tree unless every affected change is verified discardable.
- **Substantial progress, roughly halfway or near completion:** finish that
  subgoal, pass its written focused tests/static checks and parent review, fixing
  failures until they pass. Commit/push through the authorized pause checkpoint and
  wait for its exact required CI, repairing/re-pushing failures under the rules
  above. Do not pause with failed/pending required CI. Full suites still require
  a complete main-goal marker.

Then update justified checklist/README status and refresh handoff for either a new
session or resumption in this one: commits, tests/skips/pending gates, staged/
unstaged/untracked work, recovery paths, agents/commands/jobs, unresolved findings,
completion target and exact next actions. Publish any checkpoint documentation
receipt with proportionate checks, identifying the tested code SHA. Leave no
required worker/job active, then pause; resume only on the user's instruction.
Never award a tick to partial work. If a genuine blocker prevents the agreed
checkpoint, preserve it unchecked and report the blocker instead of discarding
substantial work or claiming success. An immediate stop request takes precedence.
