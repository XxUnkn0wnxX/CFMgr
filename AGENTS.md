# CFMgr project instructions

CFMgr rules override conflicting global/skill workflow guidance; explicit user
instructions override stale text. Product behavior belongs in [PLAN_V2.md](PLAN_V2.md).
Keep this file **below 32,000 bytes**; consolidate at **28,000**, targeting **21–23 KB**.
Use `zr0-agents-governance` for instruction edits, `zr0-git-repository-workflow` for
Git/privacy, and matching skills for general planning, testing, CI and documentation.

## Planning authority

Read these at session start/resume; the parent alone edits them:

| Document | Sole purpose |
| --- | --- |
| [PLAN_V2.md](PLAN_V2.md) | Product requirements, stable IDs, behavior, edges and open decisions. |
| [PLAN_V2_checklist.md](PLAN_V2_checklist.md) | Mirrored requirements/acceptance tables, totals, boxes, focused results and outstanding gates. No risks, diary, ownership, queue, next actions or publication authority. |
| [PLAN_V2_handoff.md](PLAN_V2_handoff.md) | Current task/permissions, restart state, owners/jobs, pending proof, blockers and next steps; replace stale notes. |
| [PLAN_V2_review_notes.md](PLAN_V2_review_notes.md) | Only relaxed acceptance and significant deferred risks; mirror affected goal headings/subgoal descriptions, with notes instead of boxes. |
| [PLAN_V2_audit.md](PLAN_V2_audit.md) | Substantive findings/evidence, reviewer agreement/user decisions and verified repair dispositions linked to IDs. No requirements, totals, queue or session lineage. |

Use `zr0-multi-session-projects` for paired specification/checklist edits, evidence
and continuity. Preserve root-level locations, tracking and Sxx.yy IDs, including
the audit companion; new-project defaults do not relocate them. Checklist mirrors
specification tables and links to audit/review notes instead of copying them.
Update review notes when exceptions change; omit unaffected goals, progress and
session history. Notes neither change requirements nor waive serious failures.

Significant objective, behavior, scope, accepted-edge changes or extensive rework
need prior approval: explain the change, reason, tradeoffs and IDs, then ask once.
Explicit user requests, routine evidence/format/link edits and refinements retaining
approved behavior need no repeat approval. Ordinary implementation/test failures
are autonomous repairs. While a hard-blocker question is pending, do only
independent authorized work; after 3–5 unanswered minutes preserve WIP, record the
question/safe restart in handoff and pause. Silence never grants approval.

Preserve [.old/PLAN.md](.old/PLAN.md). Keep the complete hidden session-ID HTML
comment immediately below the handoff title; verified parent lineage belongs only
there. Consolidate continuity records only at the skill's 500–600 KB or hard-to-follow
threshold, not by routine trimming.

## Implementation and preservation

Follow the active handoff boundary; writing it starts no later work. Past cleanup,
branch deletion, history resets and one-off publication grants do not recur.
Select dependency-ready work by smallest fully completable outcome across goals,
not goal number. Size includes integration/validation, not just a helper. Prefer
small independent subgoals/prerequisites; coordinate larger batches only when no
smaller ready outcome remains, including only necessary dependencies. Finish the
active package and focused gates before switching; authorization/pause gates apply.

Before a package inspect code/tests/ownership; record IDs, real consumer, missing
acceptance, focused checks, dependencies and return route in handoff. Notify before
another goal's prerequisite. Goal 1 needs all three features and source parity;
dependencies earn only proven credit.

**Prioritize consolidation:** use few coherent owners (backup, configuration,
networking). Extend an owner before adding files; a function, parser, menu or phase
alone never justifies a script. Keep process entries thin. Prefer simple normal-
operation/core-risk designs, preserving required edges. Elsewhere add only cheap
safeguards/small mitigations; note significant residual limitations. Critical gaps
beyond a small fix use the approval/blocker rule. Avoid speculative frameworks.

Keep WIP and missing integration/tests truthful. Focused-tested WIP may be committed
unchecked, but cannot redefine subgoals/acceptance or authorize target switches.
Review coherent packages before advancing; retain interruptions/known failures.
Never delete work to manufacture a pass.

Before authorized destructive replacement, bulk code/test deletion or history
rewrite, stop affected writers. Snapshot commits plus affected staged, unstaged,
untracked and necessary ignored files; verify inventory/content and record private
recovery path/method. Retain reference/firmware evidence. A Git bundle/ref saves only
commits; no destruction without a verified complete snapshot. Superseded-file
removal within scope requires preservation and consumer/regression checks.
Abandoning features, deleting unfinished subsystems, changing objectives or another
history reset needs explicit approval.

## Evidence, progress and acceptance

Trace actual entry through shared code to observable success/failure. Acceptance
requires approved behavior and representative safety cases. Requirements, source
review, host tests, BusyBox/kernel execution and live evidence are distinct;
helpers, mocks, counts, statics and commits cannot prove a missing consumer.

Record command, tested SHA/dirty state, pass/fail/skip and platform limits. Required
CI must match the exact published head and every required job; old, failed,
cancelled, skipped, queued or incomplete runs do not pass. Relevant later edits
invalidate proof. Distinguish planned, implemented-unverified, focused-local-passed,
platform-pending and accepted. Never invent behavior/evidence; promptly report loss,
regressions, drift or missing outcomes.

Report these separately:

- **Main goals:** accepted goals / 16 (6.25% each); a main tick requires every
  subgoal and its gates.
- **Overall subgoals:** accepted product IDs / approved IDs (currently 157), equally
  weighted and counted once from specification/checklist rows. Change the denominator
  only by approved scope. Report local-complete/CI-pending IDs separately; helpers,
  partial work, developer tools and optional features earn no credit.
- **Active goal:** fully implemented, written-focused-tested subgoals / required
  subgoals. Include goal, count/percentage, changed IDs/goals, missing proof,
  completion target, dependencies and return route. Local proof may count here
  while CI is pending; skips/helpers/WIP do not. Cap at 99% until all subgoals,
  audit, full local and exact full CI gates pass.

Checkpoint/final reports include both accepted totals/percentages and remaining
work. Checklist summary contains only those two totals; IDs/evidence/gates stay in
its tables. Keep workload estimates separate. Product 100% means an integrated,
beta-ready CLI with coherent libraries, automated safety tests and practical guides.
Ubuntu/BusyBox is representative development proof; Merlin/ARM, flash, hooks, TLS
and live providers remain provisional until real-router beta qualification.
Beta deployment and stable/release publication need separate approval. Optional
polish may follow implementation completion.

### Practical test policy

Use `zr0-test-efficiency` and `zr0-ci-optimization`, also in worker briefs.
End-user journeys use `zr0-interactive-testing` and its scoped permissions; it adds
no product acceptance gate or router authority.

Preserve plan-required behavior/edges, especially boot loops, router hangs,
unbounded work, unsafe writes and serious corruption. Rare synthetic process/thread
stress is optional Diagnostics work. Relax incidental output/timing assertions or
defer rare low-risk cases with a review note, without approval. After two failed
focused fixes or roughly 20 minutes on one CI issue, reassess evidence/criticality.
Report blocked common failures' cause/impact; high-risk unresolved issues or
significant behavior changes use the planning approval/blocker rule. Do not spend
hours on rare possibilities or treat test counts as targets.

Review existing wall/CPU timings before each develop push and after about three
batches; never add full runs solely for timing. Remove redundant work/low-value
variants before adding coverage. At product 100%, target at most roughly 40 minutes
including setup; raise lower runner limits only for measured growth, never above
40 minutes. Passing tests alone do not establish acceptable cost.

Core groups follow actual main modules, with libraries beneath their consuming
module; add groups with new main modules. Developer tools remain optional Tools
Checks. Run each **complete module first**, aiming below **ten minutes including
setup**, preferably shorter. **Only after exceeding that limit**, split temporary,
meaningful disjoint Dev batches to locate the slow part. Optimize with focused
tests, rerun every diagnostic batch aiming for **two to three minutes**, ideally
under two, then rerun the **complete module** within budget. Never pre-split tests
or fragment runtime libraries to evade the limit; chunks cannot replace core.

Run all groups after migration; diagnose the longest over-budget group. Keep
visible test names and wall/CPU timings. Assign every required case exactly once
per platform, rejecting omissions/overlap. Shared changes retain every affected
consumer's proof. Map focused Dev selections for Linux-dependent subgoals and
substantial libraries; complete affected groups and review cost at the candidate
SHA before acceptance. A fast subset earns no checkbox.

Reuse pinned venv/dependencies. Gates include Ruff lint/format, Python compile,
shell syntax, shfmt, planning/link/whitespace and behavior. ShellCheck is manual
optional Lint Checks in CI; local runners include it unless `--skip-shellcheck`.
Diagnostics runs existing marked cases only and is optional. Keep optional failures
visible; assess serious product failures wherever exposed. Python is developer-only;
runners never commit/push/watch CI. Planning checks supplement runtime proof;
never remove valid runtime code to satisfy obsolete empty-tree rules.

When adding or changing optional code/tests, run the affected optional checks
before checkpoint closure, including Diagnostics, Tools, lint and link-check
behavior as applicable. Record their actual results and platform limits; optional
status excuses no validation of changed work. These CI workflows remain
manual-only; unrelated optional checks stay nonroutine. Serious failures still
follow the blocker policy above.

Developer tools must support forks/contributors: derive checkout paths; never
hardcode personal SSH aliases, router addresses/logins/keys or mounted paths.
Connection data belongs in ignored `tools/router.local.json`, with fake-value
template/help. Require explicit execution intent and owned cleanup; keep private
data out of tracked files/tests/output. Show proposed text and ask before adding
tool entries, requirements or plan/checklist scope. Approved-tool status updates
use focused gates and earn no product credit.

## Validation and publication gates

Use this checkout only; additional worktrees need explicit approval. Preserve
existing registrations; no cleanup is implied. `develop` is the sole active/default
branch until reviewed product 100%. Do not recreate local/origin `main`, change
defaults, rewrite history or promote runtime incidentally. Main's return needs a
separate readiness action. First release version is chosen at 100%/beta readiness,
with no milestone bumps; settle beta upgrade order before packaging. Releases,
stable promotion and deployment need separate authority.

Subgoals require full implementation, written focused tests, statics and parent
review. CI-dependent acceptance also needs **complete core Checks at the exact
published candidate SHA**, including shared foundations. Dev is interim/diagnostic
proof; narrow passes cannot award ticks.

**Authorized checkpoints include develop pushes needed to finish CI**, including
repairs and the documentation receipt; do not ask again. This grants no unrelated
pushes, later package, release or deployment. Local commits alone add no authority.

- **Interim:** focused local tests/statics → review → commit → continue the same
  package without push/pause when all needed proof is local.
- **Platform proof or substantial early pause:** runnable local gates/review →
  commit/push → affected Dev groups → exact complete core Checks → justified
  acceptance/README/records → pause at the agreed block checkpoint.
- **Main-goal 100%:** all subgoals → accumulated audit → full local suite → push →
  exact complete core CI → accepted boxes/main tick/README/handoff → pause.

**Full local suites run only at main-goal 100%; full core CI runs last at the
checkpoint.** Use adequate local proof and focused Dev for unavailable Linux/BusyBox
proof; local skips stay pending. Do not fabricate local passes or duplicate remote
diagnosis for adequate local proof. Cancel premature owned automatic core runs
while Dev diagnosis is pending, preserving triggers; run the complete final gate
after implementation/review/focused groups pass. Repair with the smallest selection,
then rerun every affected complete group at the final SHA. Retain core edges/statics;
record scope, results and timings in handoff.

Dev accepts **one to eight validated pytest nodes or whole modules, never mixed**,
by manual dispatch. Prefer modules for complete gates; modules exclude optional
diagnostics, explicit nodes may target them. Larger diagnostic scopes use multiple
same-SHA runs, all required. First map affected IDs/consumers/foundations; small node
sets remain diagnosis unless they cover the entire required scope. Invalid/ambiguous
selections fail. Commit trailers and `CFMgr-Focused-Tests:` are unsupported. Dev
runs have independent concurrency groups; their full-host baseline is diagnostic,
not a routine gate. Checks supports manual dispatch; new same-ref/PR runs cancel
superseded core runs. Skipped/cancelled/incomplete proof never passes.

After a runtime checkpoint push, wait for prescribed exact CI before further
implementation. Failures require repair, focused tests, commit/re-push and another
wait; verify remote state and accepted SHAs. Reuse valid exact-candidate evidence.
Documentation receipts use proportionate checks and name the tested code SHA,
without claiming their receipt SHA was runtime-tested. Blockers remain unchecked
and reported; no unearned README progress.

**End the turn after each agreed major checkpoint**, with its tasks, gates and
records finished and no required worker/job active. Report exact evidence, both
progress totals and remaining work. Wait for user permission before reviewing,
selecting or suggesting the next block. A block may span several subgoals without
completing a main goal; interim commits/diagnostics/repairs need no pause or repeat
push approval. After a main-goal checkpoint, do not start another main goal in that
session.

## Main-goal audit

Before a main-goal full local gate/push, audit accumulated active code, not just
the diff. Map entries, libraries/modules, workers/hooks, tests/fixtures, tools and
CI to requirements/consumers; check ownership, reuse, duplicate setup/work, unused
wrappers and abandoned paths. Preserve intentional differences and distinct safety/
platform proof; similar names alone do not justify merging. Repair unjustified
duplication/drift within scope; substantial rework needs approval.

Verify runtime/assertions/docs/acceptance and test cost against spec/user decisions.
Record findings/fixes in audit, significant deferrals in review notes, actions in
handoff and accepted audit revision in checklist. Use existing required gates,
not another full run. **No audit, no checkbox.** Report drift/impact immediately,
repair/revalidate before advancing; never rewrite requirements to legitimize drift
or imply approval of a new gated decision.

## CI requirements

Apply Dev/core gates, including planning consistency, to changed code, tools,
workflows, commands and dependencies. Checks runs automatically on code/test/tool/
Actions pushes to `develop` and PRs targeting `develop`, plus manually. Docs-only
Markdown, docs/ assets and images never trigger CI; mixed code/docs do. Release-
branch triggers need review.

Checks starts separate **Backup Checks, Manager Checks and Status Checks** runs,
visible in each workflow history. Trusted pushes/manual runs dispatch them; PRs
use matching native triggers to preserve fork isolation. Checks strictly verifies
the exact candidate and every required module result. Each independent run owns
common planning/statics and its host/native syntax and behavior gates. Groups
expand with main modules. Each module has isolated host/BusyBox jobs, both
required, fail-fast off, maximum two
concurrent (six product VMs today). Measure module elapsed time including setup;
scheduling does not replace cost optimization. Isolation prevents real-process
fixture collisions. Reuse verified cached native-host vendor BusyBox: representative
Ubuntu proof, never router qualification or a fake Merlin install.

**Dev Checks**, **Tools Checks**, **Lint Checks** and **Diagnostics Checks** stay
optional/manual only. Dev supplies focused/temporary diagnosis; Tools covers
nonproduct developer behavior. Optional stress remains outside core and is never
claimed passed. Preserve fixtures/caches. QEMU/kernel/ARM/firmware matrices are
optional, not routine gates. Use CI failure capture/redundant-run cancellation even
for requested kernel diagnostics; multiple kernel profiles need a specific reason.
Adapt CI with approved growth and modest resources, without changing goals,
acceptance, agent rules or release/deployment authority.

## Delegation and integration

Concurrent independent work is authorized; use `zr0-parallel-execution`, active
routing and planner policy. Give exclusive ownership and dependency/integration
gates in the existing handoff. Normally allow at most two implementation packages;
a third needs settled interfaces/easy integration. Finish the active set before its
combined checkpoint. Workers cannot award ticks, expand scope, discard work,
publish or advance to another package. Only the parent edits the five V2 records.

## Documentation

Use `zr0-github-documentation`. Workers may edit guides, never V2 records. README
includes a concise warning, all 16 goals/subgoal scope/guide links, and distinguishes
intended/available behavior. Progress shows accepted counts (`2/9 accepted`) or
planned/completed only, updated after acceptance. Omit WIP/diagnostics/pending gates
and implementation notes. CI cannot credit incomplete work; main ticks need audit,
local/CI proof and parent review. WebUI is optional future work outside percentages.

During development keep `docs/development.md` to tools/setup/built-in checks and
existing-command usability: no diary, progress, receipts, investigations, fixture
internals, CI/publication procedures or session decisions. Keep compatibility docs
to router/Merlin targets and proved support limits; audit details belong elsewhere.
Practical guides are due near 100%, before beta readiness. Docs prove no runtime or
safety behavior.

## Runtime and evidence boundaries

Runtime is BusyBox-compatible POSIX sh, CLI only, with no router Python/venv.
Features live in `modules/`, shared libraries/parsers in `modules/lib/`, workers/
updaters/bootstrap in `modules/helpers/`, thin hooks/templates in `modules/hooks/`.
Keep imports explicit, with no arbitrary loading or source-time execution. Update
all callers, manifests, tests and docs when reorganizing.

Keep root `cfmgr.sh`/`catalog.txt`; install entry `/jffs/scripts/cfmgr.sh`, support
under `/jffs/addons/CFMgr.d/`. Generate private extensionless config from defaults
only after retained setup checks; ship no public config/template. Preserve complete
verified generations/settings. Section 7's trusted entry supplies one repo/branch
default; overrides require developer mode. Derive module URLs from that source and
one commit pin; replace catalog with verified package. Installed opkg repairs mapped
missing/unusable tools, preserving healthy ones; upgrades are user-managed. Selected
force reinstall is separate from Cloudflared maintenance.

Primary read-only reference is original `cloudflared/setup/`, located via ignored
`.tmp/reference-paths.md`; router captures are supplemental. Keep private paths,
config/credentials and raw evidence out of Git. Before affected Merlin storage,
hooks, scheduling, install/removal design or milestone review, consult official
[Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts),
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
and feature guidance. Verify exact firmware capabilities; current examples do not
prove older targets. Add-ons are supplemental. Put approved design in plan and
evidence limits in checklist/handoff.

Verify revision, hashes/cache and scope before reusing `.tmp/firmware-audit/INDEX.md`.
Never commit or execute/flash firmware, extracted/raw audit or provenance. Keep
source/image, host/BusyBox and live evidence distinct; completion authorizes no
evidence deletion.

## Router permissions

- Brief, lightweight read-only inspection via `ssh router` is authorized using
  single commands or a background terminal; close inspection sessions. It may
  inspect existing files, capabilities and runtime state.
- Router login is zsh: explicitly use router `/bin/sh` for BusyBox/POSIX work.
  Workstation shells use `/usr/local/bin/zsh`; host shell fixtures use suitable
  resolved Homebrew shell. macOS `/bin/sh` is not router proof.
- Small nondestructive command tests and their own temporary files are allowed
  only under `/mnt/MERLIN/tmp`, with verified cleanup. Create that base if absent,
  never remove it, preserve permissions, write only inside it, and remove only
  verified owned test artifacts. Preserve everything outside it.
- This exception excludes JFFS/other paths, settings/services, installed files,
  packages and stress tests. All other router writes/tests, live code/package
  execution, installs, mounts/chroots, service/settings changes, deployment and
  provider writes require explicit user permission before execution. Preserve
  unrelated integrations/secrets and pass these limits to every router worker.

## Pause and handoff

Earlier explicit pauses override the checkpoint boundary; start no unrelated work.
For a barely started attempt, the user permits reverting only that owned subgoal
to HEAD after diff/ownership inspection and verified preservation, never unrelated
work/data. At substantial progress (about halfway or beyond), finish the subgoal,
focused gates/review, repairs and authorized push/exact CI checkpoint; do not leave
required CI failed/pending except a reported genuine blocker. Full local still
requires main-goal completion. **Immediate stop overrides this:** stop at once and
preserve truthful WIP.

Update justified checklist/README and continuity handoff for same/new-session
restart. Publish documentation receipts with proportionate checks/tested code SHA;
docs-only changes trigger no CI. Leave no required worker/job active. Never tick
partial work; preserve/report genuine blockers unchecked and wait for instructions.
