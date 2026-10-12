# CFMgr project instructions

Global instructions and matching skills apply; explicit user decisions override
stale text. This file owns repository workflow; product behavior belongs in
[PLAN_V2.md](PLAN_V2.md). Keep this file below 32,000 bytes. To prevent recurring
ceiling pressure, consolidate proactively at 28,000 bytes; prefer 21–23 KB.
General testing, CI, Git and Markdown procedures belong in their named skills.

## Planning authority

Read at session start/resume:

| Document | Sole purpose |
| --- | --- |
| [PLAN_V2.md](PLAN_V2.md) | Product requirements, stable goal/subgoal IDs, behavior, edge cases and open decisions. |
| [PLAN_V2_checklist.md](PLAN_V2_checklist.md) | Matching requirements, acceptance, totals/boxes, focused results, outstanding gates and concise accepted evidence. No diary, ownership, queue, next actions or publication authority. |
| [PLAN_V2_handoff.md](PLAN_V2_handoff.md) | Current task/permissions, resumable state, owners/jobs, pending proof, blockers and next steps; replace stale notes. |
| [PLAN_V2_review_notes.md](PLAN_V2_review_notes.md) | Only relaxed acceptance points and significant risks for later review. Mirror goal headings and subgoal descriptions; replace checkboxes with concise review notes. |

Checklist mirrors the specification's main-goal/subgoal tables. The parent alone
edits these four files. Preserve user decisions; make every approved plan change
and matching checklist change together, checking both directions; update handoff
when current work changes. Never rewrite requirements to fit code, weaken tests
to manufacture compliance, or infer approval from a worker/handoff. Keep review
notes current when an exception is accepted, resolved or changes; omit unaffected
goals, routine progress and session history. Link from checklist instead of copying
the notes. Review notes neither change requirements nor waive unresolved serious failures.

Significant objective, behavior, scope, accepted-edge-case changes or extensive
feature rework need prior user approval. Explain the change, reason, tradeoffs
and affected IDs in a reviewable proposal, then ask one clear question. Explicit
user requests, routine evidence/format/link updates, and refinements preserving
approved behavior need no repeat approval. While a hard-blocker question is
pending, do independent authorized work only. After 3–5 minutes without an answer,
preserve unfinished work, record the question/safe resume point in handoff and
pause safely. Ordinary implementation/test failures are not approval blockers;
fix them autonomously. Silence or elapsed time is never approval; do not repeat
answered gates.

Do not routinely trim handoff. Consolidate it if it approaches 500–600 KB or
becomes hard to follow, preserving permissions, open questions, proof/blockers,
owners/jobs, unfinished work and recovery references. Resolve conflicts by
checking source, plans, diffs, receipts and agent state; use focused checks only
where uncertainty requires them. Record unknowns and report drift; housekeeping
cannot award ticks or discard work.

Preserve [.old/PLAN.md](.old/PLAN.md) as reference. Preserve the complete hidden
session-ID HTML comment immediately below the handoff title. Append only verified
new parent session IDs, never child IDs or entries for a turn/compaction. Keep
this record only in handoff.

## Implementation and preservation

Follow the active handoff boundary; writing a handoff does not start later work.
Past cleanup, branch deletion, history resets or publication grants do not recur.
Order dependencies first and work in coherent units: finish implementation,
integration and required focused checks before switching targets. Prefer small
independent subgoals, then shared-module batches, then remaining work to close
the active main goal. Do not start a large target while smaller independent ones
remain. Before a package, inspect code/tests/ownership and record
its Sxx.yy, real consumer, missing acceptance and focused checks in handoff.
Name dependencies and return paths; notify the user before switching to a
prerequisite in another goal. Goal 1 requires all three features and source parity,
not a menu skeleton. Dependency work earns only its proven credit.

Keep shared support grouped by responsibility, not disconnected helpers or one
monolith. Preserve partial work as WIP, record missing integration/tests, and do
not invent smaller product subgoals or lower acceptance. Focused-tested partial
work may be committed honestly with boxes unchecked, but does not authorize a
target switch. Review/checkpoint coherent packages before advancing. Preserve
interruptions and known failures; never delete work to manufacture a clean pass.

Before authorized destructive replacement, bulk code/test deletion or history
rewrite, stop affected writers and preserve current commits plus affected staged,
unstaged, untracked and necessary ignored files. Verify backup inventory/content,
record private recovery location and restore method, and retain reference/firmware
evidence. A bundle/ref preserves commits only. Without a verified complete
snapshot, do not destroy. Reviewed removal of superseded files within authorized
scope is allowed after preservation and consumer/regression checks. Abandoning
features, deleting an unfinished subsystem, changing objectives or another
history reset needs explicit authorization.

## Evidence, progress and acceptance

Trace actual entry through shared code to observable results and failure paths.
Acceptance requires approved behavior and representative safety cases, not every
hypothetical permutation. Requirements, source inspection, host tests,
BusyBox/kernel execution and live evidence are distinct; mocks, helpers, counts,
static checks and commits cannot prove a missing production consumer.

Record exact command, tested SHA/dirty state, pass/fail/skip and platform limits.
For required CI, verify the exact head SHA and every job; skipped, queued,
cancelled, old or failed runs do not pass. Later relevant edits invalidate
evidence. Label planned, implemented-unverified, focused-local-passed,
platform-pending and accepted accurately. Never invent source/tool behavior or
commands; report loss, regressions, drift and missing outcomes promptly.

Track progress separately:

- **Main goals:** completed goals / 16; each is 6.25%. A main tick requires every
  subgoal and its evidence.
- **Overall subgoals:** accepted product IDs / approved IDs (currently 157), each
  equally weighted across goals. Derive counts from specification/checklist rows;
  count an ID once. Report locally focused-tested IDs awaiting required CI
  separately; they are not accepted. Helpers, partial work, developer tools and
  optional features earn no credit. Change the denominator only by approved scope.
- **Active goal:** fully implemented subgoals with passing written focused tests /
  its required subgoals. Report goal, count, percentage, changed Sxx.yy IDs/main
  goals, remaining proof, and current completion target/supporting dependencies/
  return route. Focused local proof counts here while CI is pending; skips,
  helpers and partial work do not. Cap at 99% until subgoals, audit, full local
  and exact full CI gates pass.

Meaningful checkpoint/final reports include main-goal and overall-subgoal counts/
percentages and remaining work. Keep checklist summary to these two totals; put
IDs, focused evidence and gates in its tables. Keep package/workload estimates
separate from acceptance. 100% means the approved CLI is integrated and beta
ready, with coherent libraries, automated safety tests and practical guides.
Representative Ubuntu/BusyBox is the development gate. Merlin/ARM, flash, hooks,
TLS and live-provider qualification follow during real-router beta; support stays
provisional until proved. Beta deployment and stable/release publication require
separate authorization. Optional polish may follow implementation completion.

### Practical test policy

Apply `zr0-test-efficiency`; pass its current requirements to test workers.
Reuse immutable setup and fresh mutable state. Prioritize boot-loop, router-hang,
unbounded-work, unsafe-write and serious-corruption failures. Keep mandatory CI
small and focused; rare synthetic process/thread stress is optional diagnostic
work. Relax incidental output/timing assertions or defer rare low-risk cases with
a brief review-note entry and no approval request. Pursue common failures; after two
unsuccessful focused fixes or roughly 20 minutes on one CI issue, reassess its
evidence and criticality. Raise a blocked common failure's concrete
cause/impact. Ask about unresolved high-risk issues or significant behavior
changes; after 3–5 unanswered minutes, pause as above. Do not spend hours proving
rare possibilities. Test counts are not targets; review cost before each develop
push and after about three batches using existing timings, not extra full runs.

Reuse the pinned developer venv/dependencies. Runner gates include Ruff lint/
format, Python compile, shell syntax, ShellCheck, shfmt, planning/link/whitespace
and behavior. Python tools remain developer-only. Planning checks complement
runtime proof; do not remove valid runtime code to satisfy obsolete empty-tree
rules. Runners never commit, push or watch CI.

Developer tools must support contributors/forks: derive checkout paths; never
hardcode a developer's SSH alias, router address/login/key or mounted path.
Router settings are data in ignored `tools/router.local.json`; provide its
fake-value template and useful help. Require explicit execution intent and
scoped cleanup. Keep private data out of tracked files, expectations and output.
Ask before adding developer-tool entries, requirements or plan/checklist scope,
showing proposed text first. Existing approved-tool status updates use normal
focused gates and earn no product percentage.

## Validation and publication gates

`develop` is the only active/default branch until reviewed product 100%. Do not
recreate local/origin `main`, change default, rewrite history or promote runtime
incidentally. Main's return is a separate readiness action. Set the first release
version at 100% implementation/beta readiness; no milestone bumps. Settle beta
upgrade order before packaging. Stable promotion, release and live deployment
need separate authorization.

Each subgoal needs written focused tests passing locally, relevant static checks
and parent review. CI-dependent acceptance requires full Checks at the exact
candidate SHA. Local commits do not authorize pushes. Checkpoint routes:

| Situation | Required route |
| --- | --- |
| Ordinary locally provable work | Focused local tests/statics → parent review → commit → continue without push or pause. |
| Needed proof unavailable locally | Available focused checks/review → commit and authorized Quick Checks push → repair with Quick Checks → full Checks green before acceptance. |
| User-requested pause after substantial subgoal work | Finish subgoal → focused checks/review → commit/push → full Checks green → checklist/README/handoff and pause. Repair with Quick Checks, then rerun full Checks. |
| Complete main-goal marker | All subgoals → accumulated audit → full local suite → push → exact full CI → acceptance/README/handoff and pause. |

Full local suites are main-goal gates; CI-dependent subgoal or pause pushes do
not trigger an extra full local run.

A Quick Checks pass is diagnostic only: no tick, acceptance, or focused-complete
credit. The Quick workflow accepts one to eight validated pytest node IDs in a
final `CFMgr-Quick-Tests:` push trailer or manual dispatch; it runs only those
BusyBox checks, and the broad Checks job skips that quick-marker push. To accept
a CI-dependent subgoal or pause, run full Checks at the candidate SHA. The retired
`CFMgr-Focused-Tests:` selector never narrows Checks: ordinary pushes, PRs and
manual Checks always run the full required suite. Invalid/ambiguous quick selection
fails; never count skipped Checks as passed.

Main-goal checkpoint:

1. Implement all required subgoals; pass runnable focused local tests and list
   platform-only proof pending CI.
2. Audit accumulated codebase/scope/test cost/docs (below).
3. Pass applicable full local suite, then push candidate.
4. Pass full required CI at that exact commit; close CI-dependent boxes and award
   the main tick. Reuse applicable exact-candidate evidence; do not rerun needlessly.
5. Update/push README completion, refresh handoff for a new session and pause.
   Record exact evidence, both progress counts, remaining work and rough next
   scope; do not begin another main goal in that session.

After any authorized runtime checkpoint push, wait for its exact prescribed CI
before more implementation. On failure, repair, focused-test, commit/re-push and
wait again; verify remote state and record accepted SHAs. Documentation receipts
may follow within the same checkpoint with proportionate checks, naming the tested
code SHA and not implying the receipt SHA was runtime-tested. Never award an
unearned tick or README completion. A genuine checkpoint blocker stays unchecked
and is reported. A pause boundary is a completed main goal unless the user
explicitly requests an earlier pause.

## Main-goal audit

Before each main-goal full local gate/push, audit accumulated active code, not
just the latest diff:

- Map entries, modules/libraries, workers/hooks, tests/fixtures, tools and CI to
  requirements/consumers; check ownership, reuse, duplicate work/setup, unused
  wrappers and abandoned paths.
- Preserve intentional differences and distinct safety/platform proof. Similar
  names alone do not prove duplication. Do not force unrelated work into one
  abstraction. Repair unjustified duplication/drift within approved scope;
  substantial rework needs prior approval.
- Verify runtime, assertions, docs, acceptance and completion against the spec
  and user decisions. Review retained docs and test cost. Record findings/fixes
  or justified deferrals in handoff and accepted audit revision in checklist.

Use already-required gates, not a second full run. No audit, no checkbox.
Immediately report drift, its impact and correction; resolve and revalidate before
advancing. Never rewrite scope to legitimize drift or mark a newly gated decision
accepted without approval.

## CI requirements

Keep **Checks** on ordinary develop pushes and PRs, excluding docs/images/
placeholders-only changes, with planning consistency. Include changed code, tests,
tools, workflow paths, commands and dependencies with their tests. Full Checks
means the complete required acceptance suite; optional diagnostic stress is
excluded and never claimed passed. Quick Checks only accelerates CI diagnosis;
later release-branch scope needs review.

Use one Ubuntu runner for full host integration and cached native-host vendor
BusyBox checks, planning and static gates. This is representative development
proof, not a fake Merlin install. QEMU/kernel/ARM/firmware matrices are optional,
never mandatory per push/subgoal/main goal. Preserve optional diagnostics,
fixtures and caches without counting unfinished/cancelled work as passed. Real
router/provider beta follows implementation; state evidence limits without
weakening safety contracts or gates. Adapt CI as approved tests grow, keeping
coverage and modest resource use; this permission changes no goals, acceptance,
agent rules or publication gates.

During shared CI failure repair, retrieve the first useful failure and cancel
redundant work promptly. This applies to explicitly run optional kernel diagnostics;
multiple profiles are only for profile-specific investigation. Cancelled jobs
are not proof; acceptance requires full Ubuntu Checks green at the exact repaired
SHA. CI/cache/test methodology belongs to the corresponding skills.

## Delegation and integration

Concurrent independent work is authorized; apply `zr0-parallel-execution`.
Record exclusive files, interfaces/dependencies and integration gates in handoff;
never overlap writers. Normally use at most two implementation packages; a third
needs settled interfaces and easy integration. Finish the active set before its
combined checkpoint. Custom workers do not spawn agents. Each brief names scope,
consumer, owned files/interfaces, exclusions, checks and stop condition. Keep
architecture, uncertain root cause/security, planning files, integration and
final review with the parent. Use the configured worker role suited to the work:
worker for bounded tests/routine support, worker_strong for substantial or
uncertain runtime/cross-file work, explorer for bounded read-only mapping,
awaiter only for monitoring an existing job, analyst/deep only for deliberate
difficult review where available. Respect active profile routing; report
unavailable roles. Workers return files, behavior, checks/skips and risks; cannot
award ticks, expand scope, discard work or publish. Parent reviews real call/
failure paths, integrates, updates ownership/handoff and resolves discrepancies.
No worker self-advancement.

## Documentation

Apply `zr0-github-documentation` to repository Markdown, including AGENTS and
plans: accurate claims, working links, sanitized paths and proportional detail.
Workers may edit guides, never the four planning files.

README is the implementation overview: concise warning, all 16 goals and their
subgoals/scope/guide links; separate intended from available behavior. Progress
cells show accepted subgoals/total (for example `2/9 accepted`) or planned/
completed only. Update after acceptance; omit partial focus, diagnostics, pending
gates and implementation notes. Full CI cannot increase counts for incomplete
subgoals. Mark a main goal complete only after its audit/local/CI checkpoint and
parent review. WebUI is optional future work outside scope and percentage.

Keep `docs/development.md` short during implementation: required tools, setup
and built-in checks only. Do not add progress, receipts, investigations, fixture
internals, CI/publication procedures or session decisions. Update existing setup/
commands only for usability. Detailed practical guides are due near final 100%
readiness, before beta readiness. No checkpoint/test/commit diary or stale filler
in operating guides. Docs consistency proves neither behavior nor safety.

## Runtime and evidence boundaries

Follow v2 contracts: BusyBox-compatible POSIX sh; CLI only; no router Python/
venv. Features live in `modules/`, shared libraries/parsers in `modules/lib/`,
workers/updaters/bootstrap in `modules/helpers/`, thin hooks/templates in
`modules/hooks/`. Use explicit small imports/interfaces; no arbitrary loading
or source-time execution. Reorganize with all callers, manifests, tests and docs.

Keep root `cfmgr.sh`/`catalog.txt`; install entry `/jffs/scripts/cfmgr.sh`,
support under `/jffs/addons/CFMgr.d/`. Generate private extensionless config
from code defaults only after retained setup checks; ship no public config/template.
Preserve verified complete generations/settings. Section 7's trusted entry gives
one repository/branch default for install/update; overrides require developer
mode. Derive module URLs from that source and one commit pin; replace catalog
with verified package. Use installed opkg for missing/unusable mapped tools,
preserving healthy ones; upgrades remain user-managed. Selected force reinstall
is separate from Cloudflared maintenance.

Primary read-only reference: original `cloudflared/setup/` located via ignored
`.tmp/reference-paths.md`; router captures are supplemental. Keep personal paths,
live config/credentials and raw private evidence out of Git. Before affected
Merlin storage/hooks/scheduling/install/removal design and milestone reviews,
consult official [Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts),
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
and relevant feature guidance. Match exact firmware capabilities; current wiki
examples do not prove older targets. Add-ons are supplemental. Record accepted
design in plan and evidence limits in checklist/handoff.

Reuse `.tmp/firmware-audit/INDEX.md` only after verifying revision, hashes/cache
and scope. Never commit or execute/flash firmware, extracted/raw audit or provenance.
Keep source/image, host/BusyBox CI and live evidence distinct. Completion does not
authorize deleting retained evidence.

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

An explicit pause request overrides the normal main-goal boundary. Start no
unrelated package; choose the last acceptable checkpoint based on progress:

- **Barely started:** user permits discarding that small owned subgoal attempt to
  HEAD. Inspect ownership/diff and preserve under the rules above; reset only
  that attempt, never unrelated work or unverified data.
- **Substantial progress (about halfway or near completion):** finish the subgoal,
  pass focused tests/static checks and review, fix failures, commit/push through the authorized
  pause checkpoint and wait for exact required CI. Do not pause with failed or
  pending full CI. Full local suites remain for a complete main-goal marker.
- **Immediate stop:** stop at once and preserve truthful partial state.

Then update justified checklist/README and refresh handoff for new session or
same-session resumption: commits, checks/skips/pending gates, staged/unstaged/
untracked work, recovery paths, agents/commands/jobs, unresolved findings,
completion target and exact next actions. Publish any documentation receipt with
proportionate checks and tested code SHA. Leave no required worker/job active.
Never tick partial work. If a real blocker prevents the agreed checkpoint,
preserve it unchecked and report it; resume only as instructed.
