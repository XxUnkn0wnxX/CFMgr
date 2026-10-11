# CFMgr v2 — current handoff

<!--
Codex Session: 01a12b73-456b-7de0-b3c2-db151518949f
Codex Session: 01a12ca8-2b44-7791-90ab-a1e5b17b3d18
Second ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd; no child IDs are included.
Codex Session: 01a12d2e-4093-74b3-a13a-5be95ceaa965
Third ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Working rules](AGENTS.md)

## Current task and authorization

**Current focus: goal 2, as a prerequisite of the requested goal 1.** The user
explicitly authorizes switching to a necessary prerequisite main goal after
notifying them first. Parent notified this switch: install/storage/dependencies
must support independent feature setup. Return to goal 1's combined workflows
after that foundation, announcing any further necessary focus switch first.
The prior next-session implementation boundary is superseded. Goal 1 means all three
independent features and original-source parity; helpers/menu scaffolds do not
complete it. Product status remains **0/16 main goals = 0%**, with no completed
subgoal. Shared dependencies earn only their actual verified scope.

Local implementation, focused tests, appropriate CI wiring and reviewed local
checkpoints are authorized. The user now conditionally authorizes earlier CI
pushes when most meaningful focused subgoal proof requires unavailable
BusyBox/Linux/platform execution: explain the dependency, run full exact-commit
CI and close only actually proved scope. A minority of platform cases does not
qualify. This storage-helper package has not been judged eligible or pushed.
No current permission covers live installation/deployment, provider mutation or
another history/reset operation.
The prior cleanup/publication/main-deletion grants are completed one-time actions.
Significant product/scope changes still require the user's concrete decision.

The user explicitly permits brief read-only `ssh router` inspection, using either
single commands or a background interactive terminal. Router login defaults to
zsh: explicitly invoke **router-side `/bin/sh`** for BusyBox/POSIX commands and
any separately authorized tests. Workstation sessions remain Homebrew zsh; local
shell fixtures use resolved Homebrew bash, not macOS `/bin/sh`. Router writes and
test execution require explicit permission. Close SSH when its work finishes.
These amendments are recorded in AGENTS.md. No router test has been authorized.

## Verified starting state

- Local and remote develop both started at
  `6dc6dbd5571beee037cf97949a449beff9dcd74d`, clean. Read-only remote inspection
  confirmed develop is advertised HEAD and remote main is absent.
- [Checks run 38180965914](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38180965914)
  passed at `13ffcfc94a88c7f2dd70be382ced5a18fe60f3ff`, verified again this session.
  It had one planning job and proves no runtime/platform behavior. The later
  starting commit is a documentation receipt, not a tested runtime revision.
- The starting tree had only planning/tooling and folder placeholders, no runtime,
  installer, package catalog or runtime tests. Replacing the empty-runtime ban
  must land together with real tests, runner, pinned tools, CI and developer notes.
- Reused local `.venv`: Python 3.14.0, pytest 9.1.1, ruff 0.16.10,
  shfmt_py 3.7.0.1. Homebrew bash is 5.3.3; native host ShellCheck is available.
  No dependencies installed in this session. Host proof is separate from Linux.

## Source audit and first dependency

Parent read all v2 documents and reviewed the focused source-parity and native
persistence reports. Original reference location remains private in ignored
.tmp/reference-paths.md. Parent traced original lifecycle dispatch, independent
Access queue/writer behavior and the DDNS-to-Access handoff. The Python paths to
replace are updater release metadata, DNS record parsing and the complete Access
helper. Keep four-attempt newest-request/writer exclusion semantics, lifecycle
readiness/stop/recovery and independent DDNS completion. The original's weaker
API parsing and old schedules do not override the stronger v2 contracts.

The first package now serves goal 2's **S02.07–S02.09**, using the native persistence
prerequisite of **S04.03**, and ultimately **S01.01–S01.03**. Its eventual consumer is reviewed feature
Save/draft/config publication. Its current concrete consumer is an explicitly
invoked storage-capability probe; this is **not** a Save implementation, production
feature or subgoal acceptance. Complete storage admission, transaction/recovery
and actual feature consumers must follow before any corresponding tick.

Pinned Merlin BusyBox source at `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f`
and `69838e4a60564e5550e97f11d8a8cf2c6260c4f0` confirms native fsync prints
syscall errors but can return zero. Plain sync and dd count=0 do not supply the
required failure reporting. The selected candidate uses one admitted read-only
fd, a fixed short `/proc/self/fd/3` operand, C locale and command-substitution
capture with an exact completion sentinel. It requires both zero exit status and
sentinel-only output. No diagnostic-file writes, new dependency or claim that
readback alone proves durability. Native error-transport/resource limits remain
part of the review; no hard deadline or power-loss guarantee is inferred.

Official Merlin Addons API/User scripts/Custom config files were consulted.
Brief read-only router inspection found GT-AX11000 388.12_2, kernel 4.1.51,
BusyBox 1.25.1, `/bin/fsync`, `/proc/self/fd`, native `/usr/bin/flock` and
`/usr/bin/env`; `/jffs` is mounted JFFS2 rw,noatime. Inspection used help and
existing metadata only, never flush/test/write/install. File and directory flush
behavior on this target is still **unverified**.

## Current ownership and contracts

| Owner | Exclusive files/scope | State |
| --- | --- | --- |
| Parent | PLAN_V2.md, checklist, handoff, AGENTS.md, README; architecture and integration | Reviewing safety boundaries and evidence; no ticks. |
| storage_flush | modules/lib/storage.sh; tests/test_storage.py; tests/fixtures/fsync_legacy.c; tools/router-storage-probe.sh | Returned; parent reviewed and reran focused tests. Ownership returned to parent. |
| runtime_checks | tools/check.py; tools/test.py; requirements-dev.txt; .github/workflows/checks.yml; docs/development.md | Returned and parent-reviewed; original workflow preserved, focused/full runner and required BusyBox job wired. Ownership returned to parent. |
| source_parity / persistence_review | Read-only reports; no writable files | Returned and parent-reviewed; no further work assigned. |

Shared interface: `cfmgr_storage_flush_fd ABSOLUTE_FSYNC_EXECUTABLE`; caller owns
admitted target/storage and opens read-only fd 3. Library sourcing performs no
work. The candidate function invokes one explicitly admitted utility and returns
failure without leaking diagnostics. It does not admit arbitrary storage, supply
process supervision, install/configure features or implement a complete commit.

The router probe is inert without explicit `--run`; parent plans to stream the
reviewed library plus probe into an isolated native `/bin/sh` via SSH. Its only
proposed mutation is a private exclusively created scratch directory below
`/jffs/addons`, tiny owned test files, native file/directory flushes and controlled
cleanup. **Prepare/review locally first, then ask permission before execution.**
No automatic router invocation belongs in local or CI runners. Parent has now
prepared/reviewed the probe and asked explicit permission for this one scratch
test. **Approval is pending**; do not execute it from this handoff alone. The
payload is 30 bytes and no services/settings/provider state are in scope.

Workers may not overlap files, edit planning documents, publish, access the router
or spawn agents. Tests use isolated fixtures with shared immutable setup and
serial execution. Host shell is resolved Homebrew bash in POSIX mode; Linux uses
actual BusyBox ash. `CFMGR_REQUIRE_BUSYBOX=1` makes absent required platform proof
a failure, not a green skip. Parent reviews both packages and their combined
checks before the next dependent package.

## Evidence pending and next actions

1. Both packages are reviewed/integrated, including malformed/failing flush
   output, inert imports/probe, cleanup ownership and test/runner/CI wiring.
   Parent reviewed the storage worker and executed
   `.venv/bin/python -m pytest -q -ra tests/test_storage.py`: **19 passed, 2 Linux
   skips in 0.45s** on the dirty tree based on `6dc6dbd`. ShellCheck and shfmt
   passed. `/usr/bin/time -l` recorded 0.85s wall, 0.51s user, 0.28s system and
   about 40.5MB maximum RSS; this is host accounting, not router timing.
   The C fault fixture compiles once and all cases run serially.
   The new runner was exercised during infrastructure verification with the same
   single-file suite (19 passed, 2 skipped in 0.46s); planning, syntax, lint,
   format, compile and whitespace gates passed. This is no main-goal full-suite
   acceptance. User reaffirmed: **focused checks only during packages/subgoals;
   full local suite only at the main-goal checkpoint**. Keep CI wiring current
   with tests; eligible earlier platform pushes still run full CI, without an
   additional full local run. No repeated full-mode runner checks are needed.
   YAML parsed, and runner rejection of ambient parallel flags, filtered required
   BusyBox runs and absent BusyBox was verified. No agents/jobs remain active.
   Parent also verified the original workflow is preserved byte-for-byte before
   the two appended runtime jobs. An initial unaccepted worker draft changed its
   checkout/trigger settings; parent reported and corrected it before integration.
2. Focused tests and applicable static/planning/whitespace gates passed. Re-run
   affected checks only after relevant further edits; do not repeat a full run.
   BusyBox/Linux CI remains pending until an eligible authorized publication.
3. Only after the router probe is concrete and locally reviewed, request explicit
   permission for that limited test if necessary to settle JFFS2 capabilities.
   The one-probe permission question was presented again at the user's request
   after their focused/full/CI clarification; it is still pending. Silence never
   authorizes it.
4. Review resulting file/directory persistence evidence before a dependent Save
   transaction. Keep unsupported results blocked; propose a concrete support or
   dependency decision only if the existing native route cannot satisfy the plan.
5. Continue goal 2's usable installation/storage/dependency workflow, then return
   towards independent feature setup in goal 1. Announce another necessary
   main-goal focus change before switching. Preserve partial
   work, leave every incomplete subgoal unchecked, and use the main-goal publication
   gates. No ordinary helper completion authorizes a push or a full product claim.

Other unresolved schema, storage, supervision, package, provider and default
choices remain in specification section 17 and checklist. No proposed logging,
backup or binary-update default was silently accepted. Required complete guides
remain under S16.03; interim developer notes stay small.

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
