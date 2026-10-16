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
Codex Session: 01a13107-3627-7803-aa3d-4fb1c1974dea
Fifth ID verified 2026-10-14 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1420b-3ef8-7c80-a5f1-aa989e2fae32
Sixth ID verified 2026-10-16 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a143d6-a984-7c11-923a-4c30a037c5f5
Seventh ID verified 2026-10-16 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Audit record](PLAN_V2_audit.md) · [Review notes](PLAN_V2_review_notes.md) · [Working rules](AGENTS.md)

## Active S04.03 durable-commit closure

The user approved starting the recommended **S04.03** foundation package, then
explicitly requested preserving strict local-versus-CI gates, running full core
CI last, and automatically pausing after each cleared checkpoint until instructed
otherwise. The user authorized recording these workflow rules in AGENTS. Product
requirements and acceptance gates are unchanged. This package ends with its
required checkpoint and pause; no next target is authorized.

Baseline: clean `develop` at `358ed0c98e62a614b3bb19a1c0d1d22703cae230`, matching
the local `origin/develop` ref. Accepted runtime remains `1ed124b`; the latest
tested fixture candidate is `9f62a4a`. Current progress: **12/157 accepted (7.6%)**,
**0/16 main goals (0%)**; Goal 4 has **0/9 accepted**. No S04.03 credit yet.

Route A targets S04.03 alone, using accepted settings/backup/package/storage
foundations. Parent and the independent Astra scope audit agree PASS WITH NOTES:
close the durable-commit contract across current real authority writers, without
requiring unfinished updater/provider/tunnel/restore consumers. Existing parsing,
locking and scoped-merge support overlaps S04.01/.02/.08/.09 without extra credit.

| Current writer/consumer | Required closure review |
| --- | --- |
| `ao` update-settings Save/recovery | Native Store pre-change intent/copies, coherent publication, exposed failures, verified recovery and truthful receipts. |
| Backup destination Save/recovery | Same Store plus pinned inert folder preparation; preserve staged folder and recover JFFS independently, without claiming cross-filesystem atomicity. |
| Retained-launch storage observation | Separate `.storage-observation` writer: compare its complete intent/publication/failure protocol against S04.03. |
| Fresh installation | Compare private fresh config/setup publication and incomplete-install guards; reuse valid existing proof where sufficient. |

The [S04.03 audit](PLAN_V2_audit.md#s0403-durable-staged-commit-review) records the
writer inventory and independent scope/repair review. New Store proof passes
post-live-rename flush/verification failure, failed candidate staging and
old/candidate/divergent recovery. Retained observation lacked a space check;
fresh completion could lose its guard before final verification and then fail
its corrective rewrite. Parent repaired these boundaries using the existing
guard and native supervisor. Publication tests and complete affected gates remain
pending; no S04.03 credit is earned by this implementation alone.

Parent owns runtime decisions, integration, generated metadata and all V2 records.
Delegated ownership: `store_failure_proof` completed only
`tests/test_config_store.py`; `publication_failure_proof` completed only
`tests/test_install.py` and `tests/test_retained_launch.py`. Parent owns
`tests/test_backup_storage.py`; `candidate_readiness` completed read-only writer
inventory and `foundation_scope_audit` completed the independent design reviews.
No delegated writer remains active; parent owns integration. Focused pytest jobs
use one local execution slot.

Current local evidence on the dirty working tree: complete Store module
**16 passed, four Linux skips**, 45.73s wall / 22.00s user / 17.13s system after
removing redundant standalone recovery cases. These assertions now follow the
actual publication faults. Changed runtime shell syntax, ShellCheck and shfmt
passed. Planning/link/privacy and whitespace passed after the rule changes.
The retained fault trace confirms that exposed flush errors propagate. The test
oracle was corrected: successful rename consumes the staged candidate, leaving
the live candidate plus old/intent recovery evidence. Final complete installer
module: **21 passed, one Linux skip**, 125.21s wall / 48.14s user / 33.43s system.
The extra guard/failure proof stays within the practical three-to-four-minute
budget; no additional full suite is justified for timing.
Final retained module: **19 passed, one Linux skip**, 108.66s wall / 42.85s user /
30.65s system. Existing entry-path fixtures now quote canonical absolute paths;
their four cases pass with the original absolute-routing contract preserved.
New backup post-publication drive-loss/failed-recovery/successful-recovery sequence
passes locally (one diagnostic case, 19.81s wall). Complete backup/settings and
shared dispatch/consumer groups are next. Independent implementation review is
PASS WITH NOTES; the only requested test-comment correction is applied.
The optional whole-tree ShellCheck step in the first focused runner invocation
was stopped after exceeding three minutes; it supplied no pass. The four changed
shell files then passed explicit ShellCheck in **12.90s** (11.13s user / 0.49s
system). Subsequent focused runner invocations use `--skip-shellcheck` and reuse
that relevant proof while retaining planning/package, Ruff/format, compile,
shell syntax, shfmt and behavioral gates. The stopped log is preserved separately.

Validation: reuse the pinned venv; focused diagnostics then complete affected
Store/settings/backup groups, plus retained/install groups if changed or needed
to close evidence. Local Linux skips remain pending for vendor BusyBox Quick.
Keep groups near two minutes, split meaningful slow groups, preserve every core
assertion and review measured wall/CPU costs. Full local suite is not due.
Finish focused/Quick gates before the final exact-candidate core Checks gate;
cancel premature automatic core runs during diagnosis. Follow the authorized
pause-checkpoint publication route, update accepted evidence only after its gate,
then pause with no required job/worker active. No router work, deployment, release,
dependency installation, worktree creation or scope changes are authorized.

Final local focused groups pass on the prepared tree based on `358ed0c`:

| Selection | Result | Wall / user / system |
| --- | --- | --- |
| `test_config_store.py` | 16 passed, four Linux skips | 45.73s / 22.00s / 17.13s |
| `test_install.py` | 21 passed, one Linux skip | 125.21s / 48.14s / 33.43s |
| `test_retained_launch.py` | 19 passed, one Linux skip | 108.66s / 42.85s / 30.65s |
| Backup storage, manager settings, installed settings entry, backup menu | 50 passed | 69.49s / 31.30s / 29.90s, including common statics |
| Prerequisites, install reporting, installed package entry, dependency consumer, dependencies | 84 passed, 28 platform skips, four optional diagnostics excluded | 30.08s / 15.07s / 10.96s |

Total: **190 passed, 34 platform skips**. No full local suite ran. The complete
focused runner passed planning/package, whitespace, Ruff/format, Python compile,
shell syntax and shfmt; changed runtime ShellCheck passed separately as above.
Only formatting and unused fixture-branch removal followed applicable behavior
proof; required Quick will test the exact published candidate. Parent review and
cost review are complete. S04.03 is focused-local-passed, still not accepted;
Goal 4 active focused completion is **1/9 (11.1%)**, accepted remains **0/9**.

Commands: `.venv/bin/python tools/test.py --skip-shellcheck --focused` with the
four backup/settings modules; other selections use
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' PYTEST_DISABLE_PLUGIN_AUTOLOAD=1`
and `.venv/bin/python -m pytest -m 'not diagnostic'` with the named modules.
`/usr/bin/time -l` supplies the recorded costs. Exact commands/results and prior
diagnostic failures remain private under `.tmp/s0403/`.

Next: commit/push this checkpoint candidate, cancel its premature automatic core
run, complete Quick groups A–D below at that SHA, then run final core Checks.
Accept only after all required evidence passes, update the receipt and pause.

Required focused CI selections (whole modules, optional diagnostics excluded):

| Group | Modules under `tests/` | Purpose |
| --- | --- | --- |
| A | `test_config_store.py`, `test_backup_storage.py`, `test_manager_settings.py`, `test_manager_settings_entry.py`, `test_backup_menu.py` | Store failures/recovery and actual settings/backup consumers. |
| B | `test_install.py`, `test_install_reporting.py`, `test_prerequisites.py`, `test_entry_package.py`, `test_dependency_consumer.py`, `test_acquire_install.py` | Completion guard, native dispatch/ownership, installed admission and acquired-package install. |
| C | `test_retained_launch.py` | Observation publication, guard admission and complete retained consumer. |
| D | `test_dependencies.py` | Real supervised fresh installer and shared repair integration; reuse its measured cost diagnosis. |

Run applicable local groups first; Linux-only acquisition/namespace/process proof
goes directly to Quick instead of simulated local passes. All four Quick groups
must pass the same candidate before the final required core run. None is accepted
yet. Manual Lint/Diagnostics remain optional; no workflow triggers were changed.

## Paused after verified test-cost checkpoint

The user approved optimizing the two slow existing tests before another product
target, then requested a global AGENTS rule to review measured cost and apply
small verified optimizations before advancing to another target/checklist item.
That scoped global rule is applied. Product requirements, safety assertions,
runtime deadlines and repository CI policy are unchanged. This maintenance earns
no new product credit: **12/157 accepted (7.6%)**, **0/16 main goals (0%)**;
Goal 2 remains **7/9 (77.8%)**. No next product target has started.

Baseline is `33bc998`, with accepted runtime `1ed124b`. Final test candidate
**`9f62a4a5d9a532f661f835205a420f0fffa8fdc4`** is pushed on `develop`. Runtime
files are unchanged. Finite phase reports now expose repair, prerequisite and
publication costs. The retained fixture combines returned-volume admission and
DNS outage in one fresh launch, preserving every distinct required assertion;
initial normal DNS, missing attachment and explicit force remain separate.
The real installer retains its full production-supervised repair/publication
path. Parent and independent review agree with this bounded consolidation;
[the cost audit](PLAN_V2_audit.md#installer-and-retained-test-cost-review) owns
findings and measured limits.

Final local dependency/retained modules: **27 passed, 9 Linux skips**, four
optional diagnostics excluded, 25.42s pytest / 25.97s wall (11.91s user + 8.82s
system). Relevant Ruff/format/compile, shell syntax/shfmt/ShellCheck, package,
planning and whitespace checks passed. Final vendor BusyBox Quick evidence is
complete at the candidate above:

| Group | Complete affected selection | Passed | Process wall | User / system CPU |
| --- | --- | --- | --- | --- |
| [Installer 38871209489](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871209489) | Actual installer repair/publication node | 1 | 185.54s | 96.52s / 87.86s |
| [Dependency core 38871213036](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871213036) | All other core nodes in `test_dependencies.py` | 20 | 38.96s | 19.73s / 14.79s |
| [Retained 38871217086](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871217086) | Complete `test_retained_launch.py` | 15 | 124.33s | 63.63s / 59.74s |

Parent verified the exact SHA and every required job/step. Pytest collection
confirms the first two disjoint groups cover all 21 core dependency tests;
`final-gates.json` records the eight-selector limit and complete mapping. Four
optional diagnostics remain excluded. Quick's unrequested diagnostic host phase
is intentionally skipped, not accepted evidence. The retained whole-group result
is effectively flat against its preceding 122.53s / 117.95s CPU run: no reliable
end-to-end speedup is claimed. The repeated launch is removed; measured combined
return/DNS work is 22.77s versus 38.18s previously; the unchanged phases also
ran slower. Do not run extra benchmarks solely to improve a claim.

[Core Checks 38871191644](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871191644)
**attempt 2 passed** at the same final candidate. Every required job/step passed;
the Ubuntu job ran **16m07s**, 08:08:47–08:24:54 UTC on 2026-10-16.

| Required core phase | Result | Process wall | User / system CPU |
| --- | --- | --- | --- |
| Host/common | 612 passed, 28 platform skips, 4 optional diagnostics excluded | 171.02s | 41.15s / 47.63s |
| Vendor BusyBox | 639 passed, 1 workstation-only skip, 4 optional diagnostics excluded | 773.52s | 355.83s / 347.17s |

The full job is slower than the preceding 13m52s core run, with higher system CPU
in both host and BusyBox phases. Installer call cost is 188.55s versus 153.07s;
retained is 110.06s versus 110.52s. No overall CI speedup is established. The
20-minute configured limit is unchanged. Focused groups remain within the
practical range, and no safe further small fixture reduction was identified.
No extra benchmark or full local suite was run. Optional diagnostics are not
claimed passed; live Merlin/ARM/provider qualification remains beta-only.

This documentation receipt records the tested code/test SHA above; it does not
claim a runtime rerun at its own revision. Planning/link/privacy and whitespace
checks pass. All workers and the awaiter finished; no local test, required CI,
implementation writer, unresolved failure or user question remains. Parent review
is complete. Pause at this checkpoint and wait for the user's next-task
authorization. On resume, verify clean `develop` against `origin/develop` and
this receipt. No additional product target is selected or started.

Private evidence is in `.tmp/test-cost-20261016/`: `local-final.log`,
`{installer,dependency-core,retained}-final.{json,log}`, `final-gates.json` and
`dependency-core-nodes.txt`, plus `core-final.{json,log}`. Earlier profile receipts
and cancelled/superseded runs are described in the audit. Preserve them separately
from final passing proof. No router actions, new dependency, release or product
scope change is authorized by this checkpoint.

## Accepted S02.01 checkpoint

The user approved the smallest independent S02.01 closure, with push and pause
after its required gate. Use this checkout and `develop`; do not start another
package, deploy to a router, release or implement the updater/standalone bootstrap.
Original baseline: `a17a66d859d047bb47cb67575ac086e11d65a23f`. Final tested and
published code: **`1ed124bb5ad19c13b507af61e56f796b1c995118`**, including the
receipt-order repair and narrow PTY fixture correction. Complete focused local
gates, parent review, focused vendor Quick and exact-candidate core CI passed.
This documentation receipt updates README/checklist/audit/handoff only; it does
not imply a runtime rerun at its own revision.

Route A targets **S02.01** only. Accepted S07.08 acquisition and existing
status/settings/backup consumers provide its foundations. S04.09 generation
admission and S02.07 native status overlap without extra credit. Requirements
remain unchanged. Accepted totals are **12/157 (7.6%)**, **0/16 main goals (0%)**,
Goal 2 **7/9 (77.8%)**. Only S02.01 gained credit; 145 product subgoals and all
16 main-goal completion gates remain.

Parent owns architecture/security decisions, integration and all V2 records.
Fixture/regression implementation, independent Astra design and independent
runtime review are complete; all workers released their files. Parent agrees
with the final independent **PASS** on strict reader/hash receipts in either
order. All workers and the CI awaiter finished and released their files. No local
test, required CI job, unresolved implementation failure or user question remains.

Implemented: trusted entry verifies its own installed record and fixed inert
`modules/lib/package.sh` using the protected bounded manifest before sourcing
that verifier. Full manifest/catalog/inventory/mapping, protection, sizes and
hashes then precede both installed import paths. Native bounded reads and an
SHA-256 known vector require no Entware, network or operational preparation.
Both manifest schemas require the verifier in installed/trusted-local admission.
Config/setup/Save-recovery data stays outside payload inventory. This proves
entry-time consistency, not hostile-root resistance or concurrent updater
pinning. Existing consumer behavior and passive extensibility are preserved.

The two CI findings and disposition are in
[the audit](PLAN_V2_audit.md#s0201-modular-distribution-closure-review):

- At `62ceee4`, Quick 38863530377 failed because the vendor fixture omitted `dd`.
  Traced one-node Quick 38863974045 at `56091bd` confirmed reader status 127.
  Enable `CONFIG_DD=y`; the existing verified config cache key rebuilds correctly.
- At `13e6807`, Quick 38864297451 found valid digest/status lines in reverse order
  on BusyBox. The corrected parser requires exactly one success receipt and one
  valid digest in either order, rejecting missing/duplicate/other records and
  retaining OpenSSL exit checking. No hash/read requirement was relaxed.
- Superseded core runs 38863512606, 38863966533 and 38864287101 were cancelled;
  they supply no acceptance. Raw `quick-first.log`, `quick-trace.log`,
  `quick-dd.{json,log}`, `core-first.{json,log}` and `core-dd.{json,log}` are retained
  under `.tmp/s0201-ci/`.

Complete affected local consumer groups passed after the final runtime repair:

| Group | Complete selection under `tests/` | Result / pytest / process wall / user + system |
| --- | --- | --- |
| A | `test_entry_package.py test_dependency_reinstall.py` | 92 passed, 2 Linux skips / 86.65s / 87.52s / 36.06s + 31.43s |
| B | `test_manager_settings_entry.py test_backup_menu.py` | 11 passed / 65.57s / 66.46s / 26.99s + 29.18s |
| C | `test_status.py test_retained_launch.py` | 48 passed, 3 Linux skips / 52.57s / 53.14s / 22.43s + 18.15s |

These use `CFMGR_TEST_SHELL='/usr/local/bin/bash --posix'
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 /usr/bin/time -l .venv/bin/python -m pytest -q
-ra --strict-config --strict-markers --maxfail=1 --durations=8 -m 'not diagnostic'`
with the listed modules. Logs: `local-final-{a,b,c}.log`. The first A attempt's
3-second test watchdog was too tight for normal 2.3–3.3s complete-entry work.
Only that fixture now allows 8s and kills/reaps a timed-out child. The exact Ctrl-D
retry passed in 3.17s; original failure and honest retry receipt are preserved as
`local-first-failure-a.log` and `local-ctrl-d-retry.txt`. Runtime deadlines and
assertions are unchanged.

Additional unchanged-boundary local evidence: package/install 33 passed, 1 Linux
skip (66.29s pytest / 67.16s wall); acquisition 2 passed, 5 Linux skips (0.59s /
1.17s); platform fixture 40 passed (1.54s / 2.46s). Their raw receipts are
`local-package-install.log`, `local-acquisition.log`, `local-platform-fixture.log`.
Local Linux-only skips are covered by the required CI below. Final four-file
ShellCheck passed in 20.28s
(11.76s user + 0.59s system), with syntax/shfmt, relevant Ruff/format/compile,
package/planning and whitespace passed. Earlier whole-tree common statics passed
in the status/retained runner. No full local milestone suite is due.

Passed at the final tested code revision:
[core Checks 38865532262](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38865532262)
and [complete focused package gate 38865544386](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38865544386).
The focused run selects `test_entry_package.py` and `test_package.py` under actual
vendor BusyBox. **Quick passed all 28 tests, no skips**, 3.12s pytest / 3.29s wall,
2.24s user + 1.52s system, maximum RSS 37,480 KiB. Every required step passed at
the final SHA; its unrequested diagnostic-host step was intentionally skipped.
Raw `quick-final.{json,log}` is retained.

Core Checks passed every required job/step at that same SHA. The job ran
**13m52s**, 07:10:31–07:24:23 UTC on 2026-10-16.

| Required core phase | Result | Process wall | User / system CPU | Peak RSS |
| --- | --- | --- | --- | --- |
| Host/common | 612 passed, 28 platform skips; 4 optional diagnostics excluded | 153.75s | 39.01s / 30.49s | 49,332 KiB |
| Native-host vendor BusyBox | 639 passed, 1 workstation-only skip; 4 optional diagnostics excluded | 654.72s | 351.15s / 219.95s | 46,488 KiB |

Parent verified exact `headSha`, terminal conclusions, every required step and
test counts/timings from `core-final.{json,log}` under `.tmp/s0201-ci/`. Optional
diagnostics are not claimed passed. Representative Ubuntu/vendor BusyBox proves
development acceptance; live Merlin/ARM/router/provider qualification remains
beta-only. No router actions occurred. The new focused package group is 3.12s;
no broad optimization or extra full local run was needed for this closure.

Resume by checking clean `develop` against `origin/develop` and reading this
section with the current specification/checklist/audit. The authorized package
is complete and the requested pause boundary has been reached. Wait for the
user's next-task authorization; then compare remaining cross-goal prerequisites
and the smallest independently completable outcomes before selecting scope.
No next target has been started. Preserve failed/cancelled receipts separately
from the successful final gate. The specification and task contracts are unchanged.

## Paused after accepted S07.08 — ready to select the next task

The user approved starting the recommended S07.08 package after the accepted
S14.02 checkpoint, and explicitly requested handoff-ready records at every
major checkpoint. S07.08 is now accepted and the requested pause boundary is
reached. Implementation began from clean `develop` at
`167ef2837eb6510c535bb50499a1c76399fbe081`. Use the existing checkout only;
do not begin another package until the user authorizes it.

Completion target: **S07.08**, with only necessary effective-source/pin work
from S07.06 and package/installer support from S02.01. No supporting tick follows
from partial work. The real consumer is acquisition and pre-execution validation
of one immutable complete snapshot, then the existing fresh installation path.
Manual/automatic self-update transactions, feature work, router deployment and
release remain outside this package. No product requirement or gate changes are
currently proposed. Accepted totals: **11/157 subgoals (7.0%)**, **0/16 main goals
(0%)**. Goal 7 has **2/11 accepted (18.2%)**; only S07.08 gained credit here.
The remaining product scope is 146 subgoals across all 16 incomplete main goals.

Current checkpoint: candidate `ffea9ebd59236045579b9250d383aa1c7acf1e09` is
committed and verified on `origin/develop`; available local gates, parent review,
both focused CI groups and exact-candidate core CI passed.
Astra's design condition for BusyBox syntax safety is now proved. Parent owns
trust/integration decisions and all five V2 records. Existing local-package
admission remains the explicitly trusted bootstrap prerequisite; it is not
evidence of remote package validation.

This documentation receipt updates only README, checklist, audit and handoff;
it records the tested code SHA above and does not claim a runtime rerun at the
receipt revision. Resume by verifying clean `develop` against `origin/develop`.
The specification and all subgoal contracts remain unchanged. No pending user
question, unresolved implementation failure, worker or CI job remains.

Frozen implementation contract (a refinement of existing S07.08 requirements):

- Add explicit `--install-remote` from an explicitly trusted **complete** local
  bootstrap, with no public source URL operands or environment overrides. Keep
  the existing `--install` trusted-local path. Standalone entry distribution and
  full developer-source/update consumers remain unclaimed supporting work.
- Resolve the central entry repository/branch once through GitHub's SHA response;
  fetch every manifest/member from that immutable full SHA. Require isolated
  native HTTPS, no redirect/fallback, native SHA-256, a shared action deadline,
  bounded individual transfers and complete private staging before execution.
- Manifest header: `CFMGR-MANIFEST 2 VERSION 1 1` (package/helper ABI 1 and config
  schema 1). Keep catalog schema 1 and the existing inventory bounds. Remote
  schema 1 is unsupported; the explicitly trusted local route may retain it.
  Compare the unique literal embedded entry version as data; check the complete
  required inventory, hashes, sizes, paths, catalog and syntax before candidate
  code executes. Safe AWK syntax checking passed actual vendor BusyBox proof; a
  normal `awk -f` or `BEGIN { exit }` is not an acceptable pre-execution check.
- Hand the validated canonical stage pathname to the existing trusted installer
  in an isolated subshell. Its own source pin replaces child FD6/7; the parent
  retains its independent stage pin. Preserve unresolved children and staging;
  cleanup is bounded to known owned files/empty directories. Keep provenance in
  the action receipt, not the developer override field `manager.source.commit`.

All workers and the CI awaiter finished and released their files; no local or
required remote job remains active.
Parent owns the integrated tree and publication. The real consumer fixture uses
production acquisition, verification, supervision and installer transaction with
isolated root/tool admission adapters; its four cases need Linux `/proc`.
Parent and independent runtime review passed; focused platform proof is complete.
No router actions occurred. Acceptance is based on the exact completed gates below.

Required [core Checks 38858115527](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858115527)
passed at that exact SHA. Parent verified the sole required job and every step.
The job ran **15m32s**, 05:53:07–06:08:39 UTC on 2026-10-16.

| Required core phase | Result | Process wall | User / system CPU | Peak RSS |
| --- | --- | --- | --- | --- |
| Host plus common statics | 597 passed, 28 platform-specific skips, 4 optional diagnostics deselected | 156.11s | 34.08s / 38.92s | 49,660 KiB |
| Vendor BusyBox ash | 624 passed, 1 workstation-only skip, 4 optional diagnostics deselected | 759.84s | 350.29s / 337.19s | 45,172 KiB |

Commands: `.venv/bin/python tools/test.py --skip-shellcheck`, then
`.venv/bin/python tools/test.py --require-busybox --reuse-static`, each measured
by `/usr/bin/time -v`. The new acquisition/installer tests all ran on both Linux
selections; expected existing host skips delegate platform proof to BusyBox.
Metadata/logs: `.tmp/s0708-ci/core-first.*`.

Core cost increased **4m18s** from the previous S14.02 job's 11m14s. The new
complete focused acquisition/installer group stayed within the agreed practical
range below. No timeout was raised or safety proof removed; optional Lint and
Diagnostics were not rerun. Retain these measurements for the next scheduled
test-cost review rather than treating the earlier baseline as current.

The separate
[transport/syntax Quick 38858125065](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858125065)
passed: **3 tests, no skips**, actual vendor BusyBox, 2.22s pytest / 2.41s process
wall, 0.82s user + 0.43s system and 39,036 KiB peak RSS. Whole job: 18s. Parent
verified the SHA and all applicable steps; only the unrequested full-host
diagnostic baseline skipped. Metadata/logs: `.tmp/s0708-ci/transport-first.*`.

[Acquired-installer Quick 38858127676](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858127676)
also passed at that SHA: **4 tests, no skips**, 144.26s pytest / 144.45s process
wall, 57.88s user + 44.93s system and 40,520 KiB peak RSS. Test durations:
full immutable acquisition/install/retained guard **86.71s**; pre-execution syntax
rejection **37.69s**; hash rejection **16.42s**; ABI rejection **3.08s**.
The group is above the two-minute ideal but within the agreed three-to-four-minute
range; no test hung. Parent verified exact SHA and every applicable step.
Metadata/logs: `.tmp/s0708-ci/install-first.*`.

Completed focused evidence on the dirty baseline: manifest generator and unique
literal entry-version validation, `tests/test_package.py`: **14 passed, 1.01s**.
Changed Python lint/format/compile and whitespace checks passed. Parent reviewed
the two-file diff. Initial acquisition module: **2 passed, 1 Linux-specific
skip, 0.77s**; the focused CI receipts above now supply actual vendor AWK and
TLS/supervisor execution.
The TLS fixture covers fixed headers, redirects, incomplete/oversized bodies and
a short whole-action deadline; it does not itself prove orchestration pinning.
Runtime shell syntax/shfmt and preliminary review passed; package metadata was
regenerated after the final SHA-response framing correction. Planning consistency
still reports 157 aligned subgoals and 16 README goal links.

Completed parent test job: local shell session `35631`, complete install/native/
prerequisite/package modules, output `.tmp/s0708-ci/foundation-local.log`.
Command: `CFMGR_TEST_SHELL='/usr/local/bin/bash --posix'
PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 /usr/bin/time -l .venv/bin/python -m pytest -q
tests/test_install.py tests/test_native.py tests/test_prerequisites.py
tests/test_package.py --maxfail=1 --durations=8`. **75 passed, 10 platform skips**,
128.91s pytest / 129.98s wall, 56.24s user + 36.57s system, 47,603,712-byte peak
RSS. No failed case. The longest normal install was 25.56s and the existing
native-to-installer consumer 19.46s; no group reached the three-to-four-minute
diagnosis threshold. No full local suite is running or due.

Final new-module command: `/usr/bin/time -l .venv/bin/python tools/test.py
--focused tests/test_acquire.py tests/test_acquire_install.py --skip-shellcheck`:
**2 passed, 5 Linux-specific skips**, 1.42s pytest / 3.66s total wall; planning,
package, Ruff/format/compile, shell syntax, shfmt and whitespace passed.
Log: `.tmp/s0708-ci/acquire-local-no-shellcheck.log`.
Focused ShellCheck passed for all six changed runtime files after the worker's
final edits. Parent's later one-line SHA text-framing change received a final
`shellcheck modules/lib/acquire.sh` pass, 0.59s wall. Its log is
`.tmp/s0708-ci/acquire-shellcheck.log`. The earlier all-files runner was manually
stopped in ShellCheck at 209.55s, before pytest; it is **cancelled**, not a passing
full lint/test receipt (`.tmp/s0708-ci/acquire-local.log`). Valid focused evidence
was reused; no test or lint requirement was waived.

Next safe actions after the user's next instruction:

1. Read current plan/checklist/handoff/audit and AGENTS, verify branch/remote and
   any new dirty files, and reuse the exact receipts above for unchanged code.
2. Inspect cross-goal hard prerequisites and shared consumers before recommending
   the smallest independently completable next subgoal. S07.08 supplies trusted
   package acquisition; S07.06 source-selection/update consumers and S02.01 full
   installer distribution remain partial and unchecked. Do not infer completion
   or automatically begin either task from this supporting work.
3. Record the selected target, actual consumer, missing acceptance, dependencies,
   owner and focused gate before implementation. No next task is currently active.

Use small meaningful tests and whole affected groups; aim for two minutes per
focused group, splitting slow three-to-four-minute groups through Quick Checks.
No full local suite is due. Required core CI remains automatic for code/Actions
pushes; optional Lint/Diagnostics need no routine rerun. At each major checkpoint,
refresh revision/dirty files, owners/jobs, completed/pending gates, blockers and
next action so another session can resume without reconstructing the chat.
The completed S14.02 record below retains its exact historical evidence; the
current pause and restart boundary is this accepted S07.08 checkpoint.

## Paused after accepted S14.02 — implementation and gates complete

The user authorized S14.02 implementation, required passing gates and a final
push, then an explicit pause. **S14.02 is accepted; do not start another package.**
Implementation began at `506e97fded9ac29d865c38e67c8f5aaaef7ac40f`. The tested
candidate is `f762dd731a7284a7a6377ffebb738209b9fd49a8`, verified on
origin/develop. This final documentation receipt changes no executable files and
records that tested code SHA; it does not claim a new runtime test run.

Required [core Checks 38852845631](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38852845631)
**passed** at that exact candidate. Parent verified the SHA, sole required job,
every job step, complete host/BusyBox results and expected exclusions. The job
ran **11m14s**, 04:52:31–05:03:45 UTC on 2026-10-16.

| Required core phase | Result | Process wall | User / system CPU | Peak RSS |
| --- | --- | --- | --- | --- |
| Host plus common statics | 588 passed, 28 platform-specific skips, 4 optional diagnostics deselected | 73.44s | 17.24s / 19.80s | 48,444 KiB |
| Vendor BusyBox ash | 615 passed, 1 non-Linux boundary skipped, 4 optional diagnostics deselected | 585.68s | 279.43s / 275.64s | 44,240 KiB |

Commands: `.venv/bin/python tools/test.py --skip-shellcheck`, then
`.venv/bin/python tools/test.py --require-busybox --reuse-static`, each measured
by `/usr/bin/time -v`. Host-only skips delegate mount/keeper/fsync proof to the
required BusyBox phase. Its sole skip is `tests/test_prerequisites.py:254`, the
workstation-without-proc boundary exercised by the focused macOS group below.
No required Linux storage or ownership case skipped. Optional Lint/Diagnostics
were not rerun or claimed passed. Logs/metadata: `.tmp/s1402-ci/core-final.log`
and `core-final.json`.

Focused [menu Quick 38852858797](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38852858797)
passed both complete backup-menu and manager-settings-entry modules under vendor
BusyBox, including internal re-exec: 11 passed, no skips, 20.91s pytest / 21.15s
process wall, 10.40s user + 11.00s system, 32,584 KiB peak RSS. Whole job: 38s,
04:52:41–04:53:19 UTC. Parent verified exact SHA and all applicable steps;
only the unrequested host baseline skipped. Logs/metadata:
`.tmp/s1402-ci/menu-quick.log` and `menu-quick.json`.

The final core's largest cases remain the existing installer publication
(181.81s) and retained repair/return (126.05s). Their combined cost is 307.86s;
these are required integrated consumer checks, not optional stress. The new
menu's full focused group remains far below two minutes. No runtime or package
byte changes followed `2e94e2b`; subsequent fixes corrected two test fixtures.

Parent review, final acceptance and publication are complete for S14.02 only.
All workers, local commands and required CI jobs are finished. Progress is
**10/157 accepted subgoals (6.4%)**, **0/16 main goals (0%)**; Goal 14 is
**1/11 accepted (9.1%)**. The other 147 subgoals remain unfinished. Supporting
portions of S02.02, S03.03 and Goal 4 earn no additional credit. Resume only after
a new user instruction, selecting the next smallest ready complete subgoal by
cross-goal prerequisites. No next target has been started. Router execution,
deployment, releases and additional worktrees remain outside this checkpoint.

### S14.02 focused evidence and repaired gate history

Previous published candidate: `f51894703cdf3366027d23c87dba12b9c18340c6`.
Its [core Checks 38851879877](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38851879877)
was deliberately cancelled after review found that the installed-menu fixture
re-executed system `/bin/sh` instead of retaining the selected test interpreter.
Host checks passed in 1m14s; BusyBox ran 6m15s before cancellation. This is not
a passed core gate. Logs and metadata are retained in `.tmp/s1402-ci/core-second.*`.
A fixture-only correction now selects the safely quoted host shell/arguments or
the existing vendor BusyBox `sh` symlink for the exact default-entry re-exec.
Production isolation and runtime bytes are unchanged. All eight backup and
three settings journeys were repeated locally and in the complete focused
Quick group, followed by the passing final core gate recorded above.
Final fixture review passed. The complete local affected group passed: 11 tests,
no skips, 50.48s pytest / 51.43s process wall, 20.18s user + 20.51s system,
43,098,112-byte peak RSS, using Homebrew Bash with `--posix` throughout.
Command: `CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 /usr/bin/time -l .venv/bin/python -m pytest -q tests/test_backup_menu.py tests/test_manager_settings_entry.py --durations=5`.
Tested dirty tree based on `f518947`; log: `.tmp/s1402-ci/menu-selected-local.log`.
Changed-file Ruff lint/format and compile, planning/package and whitespace
checks passed. No runtime or package byte changes followed earlier statics.
Focused [retained-launch Quick 38851883264](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38851883264)
passed: one case, no skips, 126.67s pytest / 126.88s process wall, 67.28s user +
58.34s system, 37,028 KiB peak RSS. The full job ran 2m21s,
04:41:38–04:43:59 UTC; parent verified the exact SHA, job and every applicable
step. Only the unrequested full-host baseline skipped. The actual retained
consumer call took 125.61s, close to the earlier 124.40s reference and within
the practical three-to-four-minute group budget. All preservation/repair/return
assertions remain. Logs/metadata: `.tmp/s1402-ci/retained-quick.log` and
`retained-quick.json`. Candidate `f518947` changed only the retained-launch
fixture's passive backup object; runtime code and package bytes are unchanged.

Initial candidate: `2e94e2b0957e928bdee101a8fa07ce250eab132b`. Its required
[core Checks 38850890760](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38850890760)
failed in the BusyBox retained-launch fixture after host success. The failure
occurred before dependency work: its handwritten `backup:{}` omitted the
`destination:null` that production defaults already emitted at `506e97f`.
Parent reproduced parser refusal for that exact fixture and success with the
actual passive backup defaults; independent review confirmed a fixture-only
correction. Strict production validation and all retained-launch assertions are
unchanged. The initial run had 495 BusyBox passes/one skip before stopping, so
it is not complete core proof. The repaired fixture's focused retained-launch
pass is recorded above; the final candidate subsequently passed complete core CI.

[Quick Checks 38850933797](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38850933797)
passed the two new real-mount cases and inherited backup-mkdir lock case:
3 passed, no skips, 2.87s pytest / 3.07s process wall, 1.20s user + 0.73s system,
32,740 KiB peak RSS. Whole job: 19s, 04:30:11–04:30:30 UTC. Parent verified the
exact SHA and all applicable steps; only the unrequested host baseline skipped.
The three calls took 0.98s, 0.96s and 0.45s respectively. This is interim
platform evidence, not the core acceptance gate. Logs/metadata are private in
`.tmp/s1402-ci/quick.log` and `quick.json`. Final core repeated the required
platform scope at the accepted SHA. The awaiter has finished monitoring.

Chosen route: the minimum coordinated foundation/consumer batch previously
described to the user. Completed mounted-drive discovery/admission (the backup
portion of S02.02, reusing S02.08), typed guarded destination persistence
(applicable S04.01–.03 and S04.06–.09), then menu-4 navigation (S03.03 portion)
and the full S14.02 selection/Save/reopen outcome. Supporting IDs receive no
credit unless their complete original contracts are independently satisfied.
Archive creation, retention and restore are outside this package.

Parent owns architecture, integration, all five V2 records and publication.
Read-only storage/persistence mapping is complete. The Astra design reviewer
approved one backup feature owner borrowing the native Store context and its
existing transaction; a fixed read-only attachment gate protects backup writes.
Both implementation workers completed and released their files. Parent reviewed
the integrated menu, backend and package metadata. Independent backend review
returned PASS WITH NOTES; the stable UI/entry review passed after correcting
unknown-versus-empty display and action-specific receipt validation. Final
independent written-test review and the selected-shell fixture correction passed.
Exact-candidate core CI subsequently passed above. No writer or local test is
active. Parent owns publication and all acceptance records.
Integrated backend interface: `cfmgr_backup_action list|check|recover`
or `save MOUNT_HEX UUID_HEX FILESYSTEM_HEX ROOT_HEX SNAPSHOT_HEX`. Strict bounded
ASCII receipts carry encoded literal paths, saved identity and numbered drive
rows. `check` distinguishes unset, available and unavailable saved destinations.
The Save input includes the exact listing's transient attachment snapshot;
persistent settings store the canonical mountpoint, UUID, filesystem and root.
The backup action owns private FD6/7 and backup-prefixed state in a subshell;
it does not replace the accepted Entware controller's globals or claim future
simultaneous source/destination archive handling. Generic recovery remains
independent of backup storage; the explicit backup-menu recovery route reuses
that same JFFS-only transaction without folder creation or selection replay.
Once owned work is reaped, cleanup may proceed
without the backup drive. A prepared inert folder is never deleted to simulate
cross-filesystem rollback.
Storage and Save foundations passed focused checks before menu integration.
Required proof covers explicit single/multiple-drive selection, spaces/duplicate
labels, exact identity revalidation, unavailable/replaced drives, safe CFBackup
creation/reuse, unrelated-setting preservation, cancelled input and failed Save.
Focused local groups, applicable statics, Linux mount/BusyBox proof and the
exact published candidate's automatic core Checks all passed. Aim for
two-minute groups; split diagnostic Quick selections if a group reaches roughly
three to four minutes. No full local suite or optional diagnostic rerun is due.

Foundation implementation is locally focused-tested on the dirty tree based on
`506e97f`. Command:
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l .venv/bin/python -m pytest -q tests/test_backup_storage.py tests/test_config_observation.py tests/test_config_store.py tests/test_storage_mounts.py --durations=5`.
Result: **69 passed, 14 platform/tool skips**, 63.34s pytest / 64.33s wall,
30.53s user + 22.36s system, approximately 45.7 MB maximum RSS. Two subsequent
cheap list-framing tests passed in 1.58s with no intervening runtime edit.
Linux mount/ownership proof subsequently passed in the initial focused Quick
recorded above; these local skips remain skips.
Changed-file Ruff lint/format, Python compile, shfmt, POSIX syntax, runtime
ShellCheck and whitespace passed. The existing mount fixture retains two
pre-existing unused-variable ShellCheck warnings; optional full Lint is not due.
The menu package exercised short isolated PTY journeys through the installed
entry; no router or user-data interaction was included.

Shared-supervisor/storage regressions on the same dirty foundation passed with
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 /usr/bin/time -l .venv/bin/python -m pytest -q tests/test_prerequisites.py tests/test_mountinfo.py tests/test_storage.py --durations=5`:
58 passed, 18 platform/tool skips, 7.82s pytest / 8.93s wall, 4.17s user +
2.58s system. The slowest case was the bounded mount-inventory parser at 0.91s.
The generated catalog/manifest include the backup module. Package/retained-launch
regressions (`tests/test_package.py tests/test_retained_launch.py`, same direct
pytest command/environment) passed 26 cases with one Linux/tool skip in 34.62s
pytest / 35.19s wall, 15.51s user + 11.29s system. Passive config defaults
(`tests/test_config.py`) passed seven cases in 0.58s pytest / 1.16s wall.

Menu/entry proof used `.venv/bin/python -m pytest -q` with the named modules:

| Focused scope | Final applicable result | Pytest time |
| --- | --- | --- |
| `tests/test_backup_menu.py` | Initial 8 passed; repeated with settings under the selected internal shell in the final 11-case local group above | 27.96s initial |
| `tests/test_manager_settings_entry.py` | Initial 3 passed; repeated in the final 11-case selected-shell local group above | Included above |
| `tests/test_dependency_reinstall.py` | 78 passed, 2 platform skips after its fixture helper change | 68.35s |
| `tests/test_status.py` | 34 passed, 2 platform skips after the scoped timeout correction | 30.63s |

The initial four-module run had 122 passes, four skips and one status-fixture
timeout in 126.15s. Its three-second process bound expired mid-report; the
isolated status journey completed in 4.87s with a ten-second bound. Only that
call now uses ten seconds; shared navigation defaults, production deadlines and
behavior assertions are unchanged. The complete affected status and dependency
modules then passed separately above. This is reused evidence across runs,
equivalent to 123 passed/four skipped for the four-module scope, not a claimed
single passing combined run. The [review note](PLAN_V2_review_notes.md#3-configuration-menus-and-status)
records the host-only timing tolerance.

Parent final common statics passed: shell syntax, pinned Ruff lint/format, Python
compile and pinned `.venv/bin/shfmt`, plus planning/package/whitespace checks.
Changed-runtime ShellCheck also passed; optional full Lint/Diagnostics were not
run. Every final local focused group remains under two minutes; the first combined
entry group was split after its existing short fixture deadline failed.
The three actual-mount/lock cases and retained-launch repair passed focused
Quick runs recorded above. The final selected-shell menu group and complete
automatic core Checks also passed at the accepted SHA. Narrow diagnostic passes alone earned no acceptance.

The final acceptance counts and pause boundary are recorded at the top.
Representative Ubuntu/vendor BusyBox acceptance does not qualify Merlin/ARM
or live FAT/NTFS behavior; real-router/provider qualification remains beta work.
The earlier checkpoint records below preserve prior evidence and decisions;
their old status and next-target statements are historical.

## Completed timing check — combined Diagnostics passed

The user requested the actual combined workflow duration after the separate
Quick runs. Manual [Diagnostics 38845454335](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38845454335)
**passed all four cases** at `19af505b13266cda55e8cb3dc9f7e0be5a63809b`.
Parent verified the exact SHA, job and every step. Only documentation differs
from fixture/core candidate `565e8df`; no code change or new core run was needed.

- Complete job: **3m07s**, 03:25:41–03:28:48 UTC on 2026-10-16.
- Dispatch to final status: **3m12s**, including queue time.
- Pytest: **4 passed, 580 deselected**, 164.64s; process wall **164.90s**.
- CPU: **90.20s user + 72.32s system**; maximum RSS **46,784 KiB**.
- Case calls: fully supervised repair **114.68s**, retry **22.16s**, threads
  **12.29s**, mixed-root **11.67s**. Shared pytest setup: 2.96s.
- Logs/metadata: `.tmp/diagnostics-audit-20261016/combined-diagnostics.log` and
  `combined-diagnostics.json`.

No failure, hang or manual cancellation occurred. Every individual case remains
below two minutes; the complete batch fits the practical three-to-four-minute
range including setup. The unchanged fully supervised reference accounts for
most of the cost and varied from its 82.17s standalone process run. Preserve it;
no further changes are justified by this measurement. All jobs/owners are done.
This later combined pass supersedes earlier statements that it had not been
rerun; the original cancelled run remains a cancellation, not a retrospective pass.

The user then asked for the next planned target. The existing next candidate
remains S14.02: mount identity/admission and typed guarded persistence foundations,
then menu-4 selection/Save/reopen. This is a scope/status answer, not authorization
to start a new product package. Product progress remains 9/157 (5.7%), 0/16 goals.

## Paused maintenance — diagnostics optimized and audit records separated

The user authorized optimizing optional diagnostics, separate named Quick Checks,
small automatic timing-led fixture tweaks, manual cancellation/retry of
three-to-four-minute groups, and a report of the remaining expensive parts.
Sweeping changes need a user decision. If a question is unanswered within the
applicable window, preserve the safe state and end the turn to wait. No question
is pending. This maintenance does not start S14.02 or change product acceptance.

Published test candidate: **`565e8dfa9af66fad2679052dd88cf40939a0abc0`**, verified
on origin/develop. Only `tests/fixtures/dependencies.sh` changes executable test
behavior: retry, threads and mixed-root reuse the existing foreground view
adapter. Fully supervised repair and installer references, production code,
timeouts, assertions and installed-flock probes remain unchanged. The coverage
boundary and parent/Astra design review are in the
[audit record](PLAN_V2_audit.md#diagnostics-fixture-optimization-review).

### Named Quick results

Each run selects exactly
`tests/test_dependencies.py::test_normal_repair_and_owned_cleanup[CASE]` at that
candidate, with pinned vendor BusyBox on Ubuntu. All four selected tests and every
applicable workflow step passed; the unrequested full-host baseline step is
intentionally skipped. These four passes cover the full current optional
selection. The subsequent combined Diagnostics pass is recorded above.

| Group / CASE | Exact-candidate run | Pytest / process wall | User + system CPU | Earlier observed time |
| --- | --- | --- | --- | --- |
| A / `dependency_threads` | [38843097190](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38843097190) | 13.12s / 13.33s | 7.23s + 5.55s | about 87s |
| B / `dependency_mixed` | [38843169647](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38843169647) | 10.50s / 10.67s | 5.20s + 3.17s | 88.15s |
| C / `dependency_retry` | [38843172113](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38843172113) | 25.43s / 25.65s | 13.21s + 10.96s | about 165s |
| D / `dependency_repair` | [38843242908](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38843242908) | 82.03s / 82.17s | 46.81s + 29.45s | about 87s; unchanged reference |

Threads passed first; mixed/retry then ran independently, followed by the
unchanged reference, with at most two optional jobs active. Every group finished
under two minutes; no new cancellation or second tweak was needed. The three
changed cases total 49.65s process wall versus about 340s previously. The four
new process walls sum to 131.82s; this is separate-run test work, not a measured
combined-workflow duration. Prior non-mixed timings are verbose completion
intervals including fixture transitions; runner variation is not an algorithmic
saving. Mixed-root CPU fell from 78.47s to 8.37s. Raw logs remain private under
`.tmp/diagnostics-audit-20261016/quick-*.log`.

Available local gate on the prepared tree based on `8e6b79f`:
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l .venv/bin/python tools/test.py --skip-shellcheck --focused tests/test_dependencies.py`.
**13 passed, eight Linux/tool skips, four diagnostics excluded**, 2.56s pytest;
4.37s wall, 1.43s user + 2.15s system. Core statics/planning and changed-file
ShellCheck/shfmt/POSIX syntax/whitespace passed. The Linux Quick results above
supply the optional platform evidence unavailable on macOS. No full local suite.

Required automatic [core Checks 38843069635](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38843069635)
**passed at the same candidate**; parent verified the exact SHA, job and every
required step. Host **554 passed, 26 platform/tool skips, four optional excluded**;
BusyBox **579 passed, one workstation-without-proc skip, four optional excluded**.
Host pytest/process wall: 66.24s/67.98s, CPU 14.70s user + 17.06s system.
BusyBox pytest/process wall: 548.79s/549.13s, CPU 262.91s user + 255.93s system.
The complete job ran **10m38s**, 02:57:29–03:08:07 UTC. Its longer elapsed time
than the prior 8m54s run does not measure this optional-fixture change: all changed
cases are excluded from core, and production/core paths are unchanged. Installer
178.71s and retained integration 124.40s remain the largest core cases; no new
core optimization or second benchmark run was attempted. Core log/metadata are
private at `.tmp/diagnostics-audit-20261016/core.log` and `core.json`.
All workers, Quick jobs and the core awaiter are complete; no required work remains
active. The later user-requested combined Diagnostics result is recorded above.

### Audit record and stop boundary

At the user's request, `PLAN_V2_audit.md` is a tracked root-level companion to
the existing V2 documents. Parent moved 20 cohesive audit/source-review passages,
left links in the handoff, and synchronized navigation and the narrow AGENTS
file-role/location rules. Independent read-only migration review and parent
preservation checks passed: all bodies, 36 historical CI links, session ledger,
permissions/recovery and next-session boundaries remain intact. This relocation
does not grant retrospective review agreement or new acceptance.
Private originals and the relocation inventory are verified under
`.tmp/diagnostics-audit-20261016/`.

The last acceptance audit covered the nine accepted product IDs; none has been
newly accepted since. Follow the continuity skill's small-batch review trigger
(three newly accepted IDs across goals/sessions, or earlier affected-foundation
risk), while preserving the required main-goal audit. Audit findings belong in
[the audit record](PLAN_V2_audit.md#accepted-subgoals-audit), not this queue.

Product counts remain **9/157 (5.7%), 0/16 main goals (0%)**; Goal 2 **6/9
(66.7%)**. Parent reviewed the final fixture diff, measured results and relocated
documents. The documentation-only receipt receives planning/link/whitespace and
privacy checks; it names the tested candidate without claiming its own later SHA
reran runtime tests. Identify the receipt with
`git log -1 --format='%H %s' -- PLAN_V2_handoff.md`.

**Stop here.** All four optional cases fit the two-minute group target. Retain the
full-supervision reference and every current assertion; further tuning is not
justified by these measurements. No S14.02, next product package, router execution,
deployment, release, new worktree or history rewrite is authorized. Earlier
checkpoint notices below are historical and were superseded only for this
completed maintenance scope.

## Paused CI checkpoint — automatic core and manual optional workflows verified

**Stop here.** The requested CI split, both optional launches, focused follow-up
and cost review are complete. No worker or required CI job remains active. Do not
begin S14.02. Product acceptance remains **9/157 subgoals (5.7%), 0/16 main goals
(0%)**; Goal 2 remains **6/9 (66.7%)**.

The user's final decision supersedes the initial required-Lint-job proposal:
**Checks** runs the full core host/vendor BusyBox suite automatically on pushes
to develop and PRs targeting develop; **Lint** and **Diagnostics** are separate,
optional manual workflows. **Quick Checks** is manual focused core/optional-test
diagnosis and repair. Required normal behavior and core safety proof remain in
Checks; only ShellCheck and the four already-optional diagnostic cases are outside
its gate. All other core statics and the normal local runner's lint default stay.
The user separately approved the scoped AGENTS update; its CI cadence, optional
ShellCheck/diagnostics, Quick purpose and documentation exemption are synchronized.
No product scope, product IDs or acceptance credit changes.

The user additionally approved excluding documentation-only pushes/PRs from CI:
Markdown and documentation image changes do not trigger Checks; code, tests,
tooling and Actions changes still do. No documentation-only CI workflow is added.

Prior baseline: full Checks `38833527680` at `41e1765` passed in 12m51s runner
time; its receipt `74d0bca4053790d42755990a68f07ba01064539d` is pushed. ShellCheck
alone occupied 117.58s. Parent owns integration/planning records. The runner/tool
worker completed the shared pinned ShellCheck action and explicit runner modes;
the workflow worker completed the four workflow files. Both released ownership.
Parent reviewed the complete diff and passed
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l .venv/bin/python tools/test.py --skip-shellcheck --focused tests/test_dev_runners.py`:
**34 passed in 0.22s**, all remaining statics passed; 1.54s wall, 0.93s user +
0.43s system. YAML parsing and planning/whitespace checks passed; actionlint is
unavailable. Diagnostic collection selects exactly the existing four optional
cases (584 collected total, 580 deselected). The actual GitHub workflows below
also validated their runtime wiring; no PR was created merely for this check.
The user explicitly requested running **both optional workflows after the split**
and looking for further core cost savings. No S14.02 work is authorized.

### Published CI results and measured cost

Implementation split: `d46217b95dc42ac7b84aea3d357d22d0684b2644`.
Final code/workflow candidate, including the approved documentation filter:
**`36199d63296cfc1d0c38d58b174287f78aa75184`**, pushed to develop.
Parent verified exact SHAs, required job/steps, selectors and logs.

| Run | Scope and result | Measured process wall / CPU |
| --- | --- | --- |
| [Core Checks 38836060014](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38836060014) at `36199d6` | Automatic push; host **554 passed, 26 platform/tool skips**, BusyBox **579 passed, one workstation-without-proc skip**; four optional cases excluded in each. Every required step passed. | Host 61.89s / 14.78s user + 11.13s system; BusyBox 454.80s / 252.99s user + 162.27s system |
| [Lint 38835845325](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38835845325) at `d46217b` | Manual; pinned ShellCheck over the unchanged complete shell-file selection **passed**. | 107.50s / 102.12s user + 5.58s system |
| [Quick 38835900202](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38835900202) at `d46217b` | Manual whole `tests/test_dev_runners.py`; **34 passed** in 0.11s pytest. | 0.30s / 0.20s user + 0.04s system |
| [Diagnostics 38835851877](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38835851877) at `d46217b` | Manual four-case batch; **cancelled for cost**, not a passing workflow. Repair, retry and threads completed PASS before cancellation; mixed-root was unfinished. | Verbose completion timestamps show approximately 87s, 165s and 87s respectively, including fixture transitions; no complete process timing |
| [Quick mixed-root 38836566052](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38836566052) at `36199d6` | Only `tests/test_dependencies.py::test_normal_repair_and_owned_cleanup[dependency_mixed]`; **1 passed** in 87.98s pytest. | 88.15s / 47.86s user + 30.61s system |

The core job ran **8m54s** (01:37:11–01:46:05 UTC on 2026-10-16), versus the
prior 12m51s: an observed **3m57s reduction**. Dispatch-to-final-status was 9m18s,
including queue/supersession delay. The host stage fell from 185.82s to 61.89s;
BusyBox also fell from 569.77s to 454.80s without runtime/test changes. Attribute
the removed lint work to this split; the further BusyBox variation is not a proved
algorithmic saving. Current largest core cases are actual installer 147.19s and
retained repair/return 104.24s. Host/core maximum RSS is now 48,336 KiB; the separate
optional Lint measured 5,548,840 KiB. Required setup remained about 13 seconds.

The initial core run `38835837070` was superseded/cancelled when the user approved
the documentation filter; it supplies no full pass. `36199d6` changes only the
Checks trigger filters and documentation relative to `d46217b`, so optional and
Quick evidence is reused only for their unchanged workflow/tool/test inputs.

The optional diagnostic batch exceeded four minutes; cancellation was requested
and GitHub finished stopping it at 6m10s of test-stage time. Its verbose log shows
three successful cases, not a demonstrated hang. Only the unfinished mixed-root
case was rerun through Quick. All four optional cases now have individual passing
results across those runs; the cancelled combined workflow is never called green.
For short future diagnosis, keep retry alone and select other named cases/groups
through Quick; do not repeat healthy groups or reclassify core safety tests.

Private evidence is retained in `.tmp/ci-split-*.log`, including the cancelled runs.
The documentation-only receipt receives planning/whitespace checks and is expected
to trigger no CI under the approved filter. It names the tested candidate above
without claiming its later receipt SHA reran runtime tests.

Further expensive optional diagnostics may be separated when justified; required
normal-behavior/core-safety proof cannot be downgraded merely to reduce runtime.
No additional test reclassification is part of this split.

Historical review: [CI core integration cost review](PLAN_V2_audit.md#ci-core-integration-cost-review).

## Paused checkpoint — S02.08 repaired and accepted

**Stop here.** The user-authorized audit and reopened S02.08 repair are complete.
Do not begin S14.02 or another package. Runtime and its required focused gates
are published. The user subsequently requested the full CI suite and its measured
cost; that successful run is recorded below. Later documentation-only receipts
do not claim another runtime test run.

- Tested runtime: `1d892a4efc7356508ed306f469f7d3dcc9b11fd2` on
  `origin/develop`; initial reporting fix `bf3f8ca70633a9c2ba8ea99ba47a42b766543991`.
- Accepted progress: **9/157 subgoals (5.7%); 0/16 main goals (0%)**.
  Goal 2 is **6/9 (66.7%)**, Goal 3 **2/10**, Goal 7 **1/11**.
  S02.08 is restored; no other product ID or main-goal gate gains credit.
- Parent integrated and reviewed the implementation, regenerated package metadata
  and accepted independent reporting/ownership and test reviews. All workers
  released their files; all required CI jobs are terminal and successful.
- Existing checkout/develop, requirements, review notes and all five verified
  parent-session IDs are preserved. The current parent ID is unavailable and
  has not been inferred. No router execution, new worktree, release or deployment.
- The pushed receipt can be identified with
  `git log -1 --format='%H %s' -- PLAN_V2_handoff.md`.

Delivered behavior: the actual fresh-install wrapper detects confirmed Entware
loss after admission, emits the fixed Manager error and attempts bounded native
syslog delivery. It keeps installation failed, preserves recovery guards and
reports unavailable/unconfirmed logging honestly. Unresolved owned work retains
its PID/start/mode and context before any new probe or cleanup; existing repair
notifications are not duplicated. Missing/replaced package sources are refused.

Historical review: [S02.08 repair task-root review](PLAN_V2_audit.md#s0208-repair-task-root-review).

### Focused verification and cost

Complete 20-module local gate on the reviewed tree committed as `bf3f8ca`:
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l .venv/bin/python tools/test.py --focused`
followed by every `tests/` module in A-F below. Result: **400 passed, 65 explicit
platform/tool skips, four optional diagnostics excluded**, 354.02s pytest.
Planning/package, Ruff/format/compile, shell syntax, ShellCheck, shfmt and whitespace
passed. Whole command: 659.76s wall, 350.72s user + 111.98s system; maximum RSS
5,663,363,072 bytes. Broad static analysis accounted for most remaining time.
Keep future local behavior selections visibly grouped; reuse unchanged statics.

The new reporting module alone passed **21 tests, five Linux skips** in 14.21s
(15.11s wall, 9.28s combined CPU). Final corrections reused unaffected local
evidence: complete `tests/test_execution_tasks.py` **14 passed**, changed Python
and shell lint/format/compile/syntax/whitespace checks passed, and the Linux-only
copy-signal test remained explicitly pending CI on macOS.

[Final three-node diagnostic](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832195355)
passed at `1d892a4`: **3 passed in 9.80s**, covering copy-signal observation,
missing-root caller survival and actual dependency-loss cleanup. It was diagnosis;
the complete final acceptance gate is the six disjoint whole-module groups below.

| Group | Complete modules under `tests/` | Exact-candidate Quick run | Result | Pytest / process wall (s) | User + system CPU (s) |
| --- | --- | --- | --- | --- | --- |
| A | `test_install_reporting.py`, `test_install.py`, `test_native.py`, `test_package.py` | [38832304399](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832304399) | 81 passed | 58.25 / 58.46 | 22.79 + 24.66 |
| B | `test_prerequisites.py`, `test_dependency_consumer.py`, `test_dependency_selection.py`, `test_dependency_reinstall.py`, `test_execution_tasks.py` | [38832307235](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832307235) | 178 passed, 1 workstation-only skip | 24.52 / 24.69 | 11.87 + 8.35 |
| C | `test_storage.py`, `test_storage_mounts.py`, `test_mount_keeper.py` | [38832309986](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832309986) | 61 passed | 23.14 / 23.31 | 12.65 + 7.81 |
| D | `test_dependencies.py` | [38832314021](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832314021) | 21 passed, 4 optional diagnostics excluded | 219.12 / 219.30 | 115.64 + 102.65 |
| E | `test_retained_launch.py` | [38832318417](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832318417) | 15 passed | 138.89 / 139.11 | 70.79 + 64.43 |
| F | `test_config_store.py`, `test_manager_settings.py`, `test_manager_settings_entry.py`, `test_status.py`, `test_config_observation.py`, `test_config.py` | [38832321802](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38832321802) | 109 passed | 52.02 / 52.15 | 23.18 + 13.37 |

All six heads equal the full tested SHA above. Parent verified each required
job/step, actual selector and log result: **465 passed, one workstation-without-proc
skip, four optional diagnostics excluded**. Only the diagnostic full-host workflow
step was skipped. No required platform case was skipped. This is representative
Ubuntu/vendor BusyBox proof, not live Merlin/ARM/syslog/flash qualification.
No complete main-goal marker was reached. Full local/Checks were not run for the
original subgoal checkpoint; the subsequent explicitly requested full CI follows.

The user reaffirmed the existing cost rule: aim for two minutes per focused group;
investigate/split groups exceeding roughly three to four minutes, preserve core
safety proof and avoid speculative edge-case expansion. AGENTS and the testing
skill already cover this. Four final groups finished below one minute; E took
2:19 and D 3:39. D's measured cost is the existing actual installer integration
test, **178.10s**, versus 176.64s at the previous accepted checkpoint. The other
repair cases took 10.90–16.61s. No hang or material cost increase was observed.
If D needs further diagnosis or grows, isolate that existing node through Quick
before broader reruns; do not rerun a full suite merely to measure it.

Preserved failure receipts: first-candidate A `38831307892` hit the test observer
race; D `38831350219` stopped during loss cleanup. B/C/F passed; E `38831353447`
was cancelled after failure capture. The unchanged-SHA isolated loss diagnostic
`38831632976` passed in 9.63s. Those runs supply no final acceptance credit.
Private local logs remain under `.tmp/s0208-*`; no failure evidence was discarded.

### User-requested full CI timing baseline

The user explicitly requested full CI after the focused checkpoint, overriding
the ordinary main-goal-only cadence for this measurement. Parent dispatched
`gh workflow run checks.yml --ref develop` and verified the exact head, sole job,
every required step and logs of [Checks 38833527680](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38833527680):
**success at `41e176568d679ebd8c69fa8dc0ff195d966ad9f3`**. No code, tests, workflow,
timeout or acceptance requirements changed; no additional local full suite ran.

| Stage | Result | Process wall | User + system CPU |
| --- | --- | --- | --- |
| Full host tests and statics: `.venv/bin/python tools/test.py` | 552 passed, 26 platform/tool skips, 4 optional diagnostics excluded | 185.82s | 126.79s + 23.97s |
| Full vendor BusyBox: `.venv/bin/python tools/test.py --require-busybox --reuse-static` | 577 passed, 1 workstation-only skip, 4 optional diagnostics excluded | 569.77s | 265.91s + 270.78s |

Both commands used `/usr/bin/time -v`. Host pytest itself took 67.45s; BusyBox
pytest took 569.40s. The BusyBox stage covered the host's platform/tool skips;
its sole remaining skip specifically checks a workstation without `/proc`.
Every workflow step succeeded. Developer-tool and verified BusyBox caches hit;
preparation took about 12s. Job time was **12m51s** (01:08:57–01:21:48 UTC on
2026-10-16), or **12m56s** from dispatch to final workflow status.

Largest measured costs: actual installer repair/publication **186.89s**, actual
retained repair/later return **128.03s**, and host ShellCheck **117.58s** from
adjacent command timestamps. The first two account for 55.3% of BusyBox pytest
time. No hang appeared; all remaining reported BusyBox cases were 16.99s or less.
Host/static maximum RSS was 6,077,464 KiB; BusyBox maximum RSS was 44,524 KiB.

The prior [full run 38274552711](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274552711)
at `81d2b29fa42374283f3b18d9de37e32f2880628e` took **8m14s** from dispatch to
status: 105.42s host/statics and 365.86s BusyBox, with 355/380 passing tests.
The current full total is **4m42s longer** and includes the intervening status,
settings/Save, dependency-reinstall and reporting work. This comparison does not
attribute all growth to one change. Reuse these timings; any further diagnosis
starts with the named slow cases through Quick Checks, preserving required proof.
Raw current and prior logs are retained privately as `.tmp/full-ci-38833527680.log`
and `.tmp/full-ci-previous-baseline.log`.

This adds full representative Ubuntu/vendor BusyBox evidence, not a main-goal
completion or live-router qualification. Progress remains **9/157 subgoals (5.7%)
and 0/16 main goals (0%)**. Stop at this completed checkpoint; S14.02 is not started.

### Acceptance audit link and next boundary

Historical review: [Accepted subgoals audit](PLAN_V2_audit.md#accepted-subgoals-audit).

After a new user instruction to continue, the proposed next complete outcome
remains **S14.02**: backup-specific mount admission, typed destination persistence
and guarded Save/recovery, then menu-4 select/Save/reopen/revalidate. Supporting
parts cross S02.02, S03.03 and Goal 4; broader support IDs and archive creation/
restore remain separately gated. Do not impose Entware-only filesystem/noexec
rules on backup storage. This checkpoint does not start that package.

## Paused checkpoint — S07.01 accepted

Historical S07.01 receipt. The completed S02.08 checkpoint above owns the current
execution boundary and acceptance evidence; S07.01 itself remains accepted.

**Stop here.** The authorized S07.01/native Save package is complete through
parent review, focused local/statics and all six exact-candidate Quick CI groups.
The user requested a pushed handoff ready for a new session and a pause before
the next substantial crossover. No next package is selected or started.

- Runtime tested and published: `576584885befb84f10bf8c10365a872a0b9fa406`
  on `origin/develop`. The documentation commit containing this receipt changes
  only README/checklist/handoff; its identity is available with
  `git log -1 --format='%H %s' -- PLAN_V2_handoff.md`. Runtime CI applies to the
  named runtime SHA, not to a claim that this later receipt reran runtime tests.
- Accepted progress: **9/157 subgoals (5.7%); 0/16 main goals (0%)**.
  Goal 7 is **1/11 (9.1%)**, S07.01 only. Goal 2 remains **6/9** and Goal 3
  **2/10**. Goal 4 support remains unchecked; no main-goal full suite/audit is due.
- Delivered consumer: `ao → CFMgr updates` with Check/Auto intent and coupling,
  default-no confirmed native Save, cancel/reopen, explicit guarded recovery and
  saved/effective status. Updater/checker/scheduling/provider/lifecycle expansion
  remains outside this accepted settings package.
- All implementation/review owners released their files; the final CI awaiter
  completed. No required worker or job remains active. No unresolved S07.01 gate,
  blocker or unanswered approval is carried forward.
- Existing checkout, all five verified parent IDs/provenance, approved plan and
  requirements, private evidence and detached-worktree metadata are preserved.
  No new session ID, worktree, history rewrite, router execution or release.
- This checkpoint's publication permission does not authorize another package.
  On a user-requested resume, read this boundary and the applicable instructions,
  verify Git/receipt state, then inspect remaining dependencies toward Goal 2.
  Keep the smallest-independent-first rule; present the next material crossover
  for selection before starting it. Do not automatically begin S07.02.

### Exact-candidate acceptance and cost

Every run below completed successfully at
`576584885befb84f10bf8c10365a872a0b9fa406`. Parent independently verified each
job and required step. The diagnostic full-host-baseline step is intentionally
excluded from this focused route; it is not missing required proof.

| Group | Run / successful job | Pytest result | Pytest / command wall seconds |
| --- | --- | --- | --- |
| A | [38488764958](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38488764958) / `115608712512` | 49 passed | 46.97 / 47.14 |
| B | [38488912894](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38488912894) / `115609193071` | 140 passed | 48.78 / 48.96 |
| C | [38489196075](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38489196075) / `115610110082` | 121 passed, 1 workstation-only skip | 37.36 / 37.55 |
| D | [38489342960](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38489342960) / `115610584814` | 92 passed | 57.44 / 57.68 |
| E | [38488768533](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38488768533) / `115608724097` | 21 passed, 4 optional diagnostics excluded | 218.17 / 218.34 |
| F | [38489164759](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38489164759) / `115610012216` | 15 passed | 115.70 / 115.96 |

The six whole-module groups are disjoint: **438 passed**, one workstation-only
no-`/proc` boundary skipped on Linux, four optional diagnostics excluded. Their
module map and host commands/results remain below. Native Store group A is under
one minute; retained launch F is under two. Existing dependency group E is within
the practical three-to-four-minute range and below its prior 229.42s accepted
checkpoint: actual installer repair/publication accounts for 176.64s. No coverage
or runner limit was changed. These separate focused timings are not a new full
suite benchmark. Whole-repository local ShellCheck cost remains recorded below
for the next required main-goal cost audit; no duplicate full run was performed.

CI logs: `.tmp/s0701-ci-{a,b,c,d,e,f}-5765848.log`; independently verified remote
run/job/step metadata: `.tmp/s0701-final-ci-receipt.json`. Earlier failed runs,
bounded diagnostics and ash source provenance remain below, now resolved by the
final accepted candidate. Do not rerun them or discard their recovery evidence.
Representative Ubuntu/vendor BusyBox is the development proof; live Merlin/ARM,
flash/reboot persistence and provider qualification remain beta-only. The accepted
JFFS2 hidden-flush-error limitation is unchanged.

The receipt uses proportionate planning/link/privacy, package and whitespace
checks. Final publication/ref and clean-tree verification is recorded locally in
`.tmp/s0701-publication-receipt.json` after push. A new clone can identify the
receipt from Git history and the six linked runs without that private file.

## Completed implementation and diagnostic record — S07.01

The following chronological record preserves implementation, review, failed-run
and recovery evidence. Its earlier pending gates, ownership and next actions are
historical and superseded by the accepted pause receipt above; they grant no new
work or publication permission.

The user authorized this recommended Goal 7 + Goal 4 package on 2026-10-14:
"ok start & pause on the next large cross-over". Baseline is clean, published
`fd1ea8aef7b51d180348fea499eb4f08000289d2` on the existing `develop` checkout.
No worktree changes. Finish the complete S07.01 consumer and required focused
local/static/review/exact-candidate Quick gates, publish the accepted receipt, and
pause before the next substantial crossover. The agreed checkpoint publication
permission continues for this package; no history rewrite, live deployment,
router execution or release is authorized.

Continuity skill refreshed from its installed `SKILL.md` and all four current
references on 2026-10-14, including `resumption-and-audits.md`. Lightweight
reconciliation found 157 matching unique plan/checklist IDs, 8 accepted, and all
five parent-session ledger entries/provenance unchanged from HEAD. No new session
was created or inferred. The roughly 64 KB handoff is navigable; no consolidation
or extra accumulated-code/full-suite audit is due. Historical ownership wording
was clarified without changing contracts or receipts. The approved root-level
tracked plans, existing checkout, recovery evidence and S07.01 scope stay intact.

Historical review: [S07.01 native storage source review](PLAN_V2_audit.md#s0701-native-storage-source-review).

Completion target: **S07.01 only** — real `ao → CFMgr updates` Check/Auto controls,
coupled effective values, private persistent Save, and correct reopened menu/status
values independent of Cloudflared and working Entware. Necessary support comes
from S04.02 scoped concurrent Save and S04.03 staged durable commit, with applicable
S04.01/S04.08/S04.09 parsing, ownership and generation safeguards. Preserve unrelated
settings/guards, detect raw edits, bound retries, handle cancellation and exposed
write/rename/flush/interruption failures, and preserve unresolved recovery material.
No generic-framework expansion, updater/downloader, schedules, provider actions or
whole Goal 4 completion. Supporting IDs remain unchecked unless their complete
original contracts are proved; do not rewrite acceptance to fit this package.

Historical review: [S07.01 smallest-task scope review](PLAN_V2_audit.md#s0701-smallest-task-scope-review).

The Astra `s0204_scope_audit` DESIGN is integrated. Parent owns decisions, all
four planning records, package metadata and final review/publication. Native
evidence exploration is complete. Implementation proceeds in two dependent
stages of this one package, without parallel writers on shared files:

1. Strong worker `s0204_runtime` owns `modules/lib/config_store.sh`, narrowly
   required probe/supervisor adapters, common-lock/recovery admission in the
   observation writer and focused store/coordination tests. Its initial fixed
   settings parser modes are implemented and released: Luna `s0701_settings_ui`
   completed that parser test package: 26 tests passed in 2.41s with Ruff and
   whitespace checks. Luna also completed the independent saved/effective/
   recovery status display (`modules/status.sh`, `modules/lib/status.awk`,
   `tests/test_status.py`) using its existing snapshot interface: 34 passed,
   2 Linux-only skips in 8.20s; Ruff, shell syntax/format/ShellCheck and whitespace
   passed. Parent reviewed both diffs; all five files are released. Commands used
   `CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' .venv/bin/pytest -q` with the
   respective complete module on dirty `fd1ea8a`; this is partial local evidence,
   not S07.01 acceptance. The first complete host Store batch passed 8 tests in
   20.56s; added concurrency/interruption cases and actual Linux supervisor proof
   are still being finished. Strong has released `launch.sh` after completing
   the common-lock wrapper; its remaining ownership is the Store/probe/supervisor
   and their tests. Analyst `s0204_safety_review` is reviewing those native paths.
2. Luna `s0701_settings_ui` completed the source-inert settings screen and isolated
   interface tests (`modules/manager_settings.sh`, `tests/test_manager_settings.py`):
   21 passed in 1.28s with Ruff, POSIX syntax, shfmt, ShellCheck and whitespace
   checks. These use a finite Store adapter and are provisional consumer evidence.
   It now owns installed-entry imports in `cfmgr.sh`, the released launch menu,
   bootstrap's mandatory-module inventory, the old inert entry fixture and new
   `tests/test_manager_settings_entry.py`. Real Store PTY Save/cancel/reopen/
   recovery and prompt-time lock tests are the next integration gate. It must
   not edit Strong's files or package metadata. Acceptance still requires the
   complete combined focused gates; no product tick is earned yet.

Public frame: `CFMGR-STORE 1 RESULT GENERATION CHECK AUTO DEVELOPER PENDING END`
plus one newline. Success results are read/saved/unchanged/recovered; failure
results are busy/stale/unavailable/recovery/unresolved. Typed flags are 0/1;
generation 0 is only a failed/unavailable placeholder. Invalid arguments return
2 without requiring a frame. UI must validate framing, result/status agreement
and operation; only successful receipts establish saved values. Explicit recovery
may return `unchanged` when no pending operation remains; this is idempotent
recovery, not a claim that a Save occurred.

The store exposes only native `read`, `save(mask, check, auto)` and explicit
`recover`; no arbitrary JSON mutation API. Check On and Auto Off own their single
field; Auto On and Check Off own both coupled fields. Save reapplies accumulated
reviewed intent to fresh authority under a stable private RAM config lock and
preserves all other raw bytes. Viewing contradictory saved values does not change
them: effective Auto requires Check; developer mode suppresses effective activity
while preserving preferences. Prompts remain outside the transaction subprocess.

Use a finite preparing → active → retired journal on the same pinned JFFS mount,
with verified private old/candidate/intent data, strict raw-content identities,
checked writes/flushes and bounded freshness retries. No live mutation precedes
an armed guard. Recovery is separately confirmed: an exact old match retains old
settings without replaying opt-in; an exact candidate match verifies/flushes it;
divergent, missing or corrupt live data is preserved and stays blocked. Unknown
journal contents are never deleted. Both current configuration writers acquire
the same stable lock and honor pending recovery; the old observation writer
rechecks raw freshness after acquisition. FD0 is borrowed only in transactions,
explicitly inherited by mutating asynchronous children, and released by close
after ownership resolves, never by unlink or early flock unlock. These inherited
descriptor and native digest contracts require real Linux proof. Preserve the
accepted JFFS2 limit; no new flash/reboot durability claim is implied.

Initial focused gate scope: actual settings menu/Save/reopen/status consumer,
coupling and unchanged preferences on cancel; preserved unrelated raw settings,
content-change concurrency and idempotent/no-op Save; guarded write/rename/flush/
signal/restart recovery failures; real Linux ownership/locking/bounds; all affected
entry/config/parser/storage/retained-launch/package groups. Final groups and costs
will follow the actual change map. Full local/full CI suites are not due. Accepted
progress remains **8/157 (5.1%), 0/16 main goals (0%)**; Goal 7 starts **0/11**,
Goal 2 remains **6/9**, Goal 3 **2/10**.

Historical review: [S07.01 native store review findings](PLAN_V2_audit.md#s0701-native-store-review-findings).
Runtime and test ownership is now released to the parent. The final Store +
prerequisites host batch passed **33 tests, 11 Linux skips in 64.46s** (wall65.14,
user22.92, sys20.15). The completed Store + retained batch passed **27 tests,
3 skips in 106.21s** before the final added Store-only observation proofs;
retained behavior is unchanged afterward. The final UI + actual entry + reinstall
batch passed **102 tests, 2 Linux skips in 64.71s**, including separate reopen,
cancel, explicit recovery and no lock during confirmation. Changed-file static
checks passed. These batches used the selected Homebrew POSIX shell on dirty
`fd1ea8a`; firmware paths/admission are labelled host adapters. No live router
execution occurred.

Parent regenerated catalog/manifest and started the complete repository static
gate plus the remaining focused local regressions in
`.tmp/s0701-local-final.log`. Do not rerun completed unchanged groups merely for
bookkeeping. Final exact-candidate Quick groups are disjoint whole modules:

| Group | Modules under `tests/` | Required proof |
| --- | --- | --- |
| A | `test_config_store.py`, `test_config_observation.py`, `test_config.py` | Native Save/recovery, shared lock, raw-preserving intent and schema/default regression; review the new Store batch cost independently. |
| B | `test_manager_settings.py`, `test_manager_settings_entry.py`, `test_status.py`, `test_dependency_reinstall.py` | Actual settings/menu/reopen/status and existing entry/reinstall routing. |
| C | `test_prerequisites.py`, `test_native.py`, `test_dependency_consumer.py`, `test_dependency_selection.py`, `test_execution_tasks.py` | Shared async supervisor/FD changes and existing native/dependency consumers. |
| D | `test_install.py`, `test_package.py`, `test_storage.py`, `test_storage_mounts.py`, `test_mount_keeper.py` | Fresh/retained package inventory and shared storage/worker regressions. |
| E | `test_dependencies.py` | Actual repair controller, cancellation, loss and cleanup under the shared supervisor. |
| F | `test_retained_launch.py` | Existing retained observation and operational admission after common locking. |

The parent local gate passed: **170 passed, 44 platform skips, 4 optional
diagnostics deselected in 124.45s**; complete runner wall392.53/user242.94/sys50.50
seconds, maximum RSS5,491,232,768 bytes. Command was
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l .venv/bin/python tools/test.py --focused`
with `test_config.py`, `test_dependency_selection.py`, `test_native.py`,
`test_dependency_consumer.py`, `test_execution_tasks.py`, `test_install.py`,
`test_package.py`, `test_storage.py`, `test_storage_mounts.py`,
`test_mount_keeper.py` and `test_dependencies.py` under `tests/`.
Planning/package/whitespace, all shell syntax, Ruff lint/format, Python compile,
ShellCheck and shfmt passed. Whole-repository ShellCheck dominated local static
cost and memory; no gate was weakened or duplicated. This is not a new full-suite
benchmark or justification for increasing CI limits. Final parent source/package
review passed; exact-SHA CI must execute the skipped Linux/BusyBox proof.

No full suite or main-goal audit is due. The complete local focused scope is
passed; exact-SHA CI remains pending. All acceptance boxes and README counts
remain unchanged until every prescribed group passes.

Candidate `b513f4503cd7599d602bc963e402904bdb97fa56` was committed, pushed to
`origin/develop` and verified against the remote ref. Group A push run
`38487295216` / job `115603908097` failed after 13 passes at
`test_linux_actual_supervisor_save_and_cleanup`: unavailable receipt before any
recovery guard, 1.07s case time; no detailed failed-probe information yet. Failure
log is `.tmp/s0701-ci-A-b513f45-failed.log`. Group B run `38487306839` / job
`115603951722` passed at this SHA (focused step about 50s); it does not waive A.
No C–F jobs were launched, and neither run remains active. Strong owns only
`tests/test_config_store.py` for bounded failure diagnostics and a concrete fix;
runtime changes require parent review of the finding. Parent owns commits/pushes
and the final complete A–F gate at the corrected candidate. No unrelated package
may start. All product boxes remain unchecked for this package.

Diagnostic-only candidate `4b00501819fb0d37dbebff376c95cecf67e4d115` was pushed
and remote-verified. Run `38487829438` / job `115605643278` identifies the cause:
`store-lock-test` unexpectedly exits 0 after successful acquisition. The parent
therefore does not retain the helper's lock; the mandatory admission refuses Save
before any persistent write. Log: `.tmp/s0701-ci-diagnostic-4b00501.log`.
Historical review: [S07.01 BusyBox ash lock review](PLAN_V2_audit.md#s0701-busybox-ash-lock-review).

The user explicitly confirmed that the final checkpoint must leave a pushed,
new-session-ready handoff with exact refs/gates, preserved session lineage,
permissions, recovery evidence and a clear pause/resume boundary. Preserve that
requirement while finishing this package; do not start the next crossover.

Corrected candidate `576584885befb84f10bf8c10365a872a0b9fa406` is committed,
pushed and remote-verified. The narrow fix passed changed-file statics and the
whole host prerequisite module (20 passed, 8 Linux skips in 3.12s). Parent reviewed
the fix and regenerated/checked the manifest. Diagnostic run `38488628486` /
job `115608265796` now passes all three actual Linux/vendor-ash cases in 12.00s:
supervised Save 9.71s, borrowed observation 1.54s, orphaned child lock 0.44s.
Log: `.tmp/s0701-ci-lock-5765848.log`. The child assertion verifies that FD0
identifies the lock and temporary FD9 is closed. This resolves the concrete
failure; it is not a substitute for the complete focused gate.

Complete A–F subsequently passed at this corrected SHA, with at most two groups
running concurrently. `s0204_ci_wait` finished recording the per-group logs;
parent independently verified every job/required step and reviewed counts/cost.
The final accepted receipt above supersedes the earlier pending state.

## Completed checkpoint — S03.07 accepted

The user resumed on 2026-10-14: work on the next smallest task, allow automatic
checkpoint publication after its test/review gate, and pause before a large
multi-goal crossover. Reuse the existing `develop` checkout; no worktrees.
Starting HEAD was `2e68bda5a977a33a093e8ee207708f84f8a5f193`, clean, with two local
instruction commits following the published S02.04 receipt. Those commits are
preserved and now published with this checkpoint. S03.07 passed its complete local
and exact-candidate Quick gates; this receipt closes acceptance. No full-suite
checkpoint, history rewrite, deployment, router execution or release was performed.
Do not interpret this completed task's auto-push permission as authority to start
the next coordinated feature package.

Historical review: [S03.07 smallest-task scope review](PLAN_V2_audit.md#s0307-smallest-task-scope-review).
The completed independent package is **S03.07 only**, using the real installed
choice `0` before operational prerequisite repair. It provides bounded native router,
resource, mount, selected-WAN/address and NTP observations, manager/source and
separate feature settings, safe bounded typed local outcome/history reading,
ages, concise issues and truthful next actions. Invalid/unavailable config or
records do not suppress independent resource checks. No network/provider call,
repair, feature activation, operational history writer or live-router execution.
Supporting read/privacy/native-entry contracts overlap S03.08/S02.07; neither ID
earns acceptance from this package. Full diagnostics, Save, hooks, lifecycle,
logging and provider implementation remain outside this completed task.

Runtime/test owner: `s0204_runtime` strong worker completed entry/launch integration,
the source-inert status module/parsers and required native supervision adapters/tests;
all write ownership is released. Parent owns the planning files, generated package
metadata, gate selection, integration and publication. The bounded typed local
evidence contract is recorded in runtime comments/tests. It never infers provider
success or connected state from PID/file presence. Existing JSON/parser and launch
contracts are preserved; invalid configured/enabled combinations are reported
without rejecting the entire native resource page.

Historical review: [S03.07 reader and native source review](PLAN_V2_audit.md#s0307-reader-and-native-source-review).

Focused gate map (whole modules; optional diagnostics excluded):

- **A — status:** `tests/test_status.py`; real choice-0/PTY consumer, typed native
  and historical evidence, privacy, malformed/unavailable configuration, bounded
  snapshots, normal Linux supervision and stalled-probe aggregate deadline.
- **B — entry/package:** `tests/test_dependency_reinstall.py`,
  `tests/test_retained_launch.py`, `tests/test_install.py`, `tests/test_package.py`;
  changed entry/import ordering, menu return, mandatory package inventory and
  existing installation/reinstall consumers.
- **C — shared foundations:** `tests/test_config.py`,
  `tests/test_config_observation.py`, `tests/test_prerequisites.py`,
  `tests/test_native.py`, `tests/test_execution_tasks.py`; reused JSON/default
  contracts and changed shared supervisor/probe dispatch with native ownership.

The complete affected local/static/planning/package gate and parent review passed,
followed by all three Quick groups at the same candidate. Lightweight isolated
PTY status/back/exit checks used fixture data only, without router access.

Parent review passed after fixing direct-child ownership for native collectors,
reserved-address classification, malformed IPv6 rejection, stale cleanup-warning
visibility and mandatory status-package inventory. The independent analyst found
no remaining material safety issue after its cleanup warning was corrected and
covered by the typed-history tests. No gates or requirements were relaxed.

Complete local command on `2e68bda` plus the candidate runtime/tests/generated
metadata (planning evidence edits follow the run):

```sh
CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l \
  .venv/bin/python tools/test.py --focused tests/test_status.py \
  tests/test_dependency_reinstall.py tests/test_retained_launch.py \
  tests/test_install.py tests/test_package.py tests/test_config.py \
  tests/test_config_observation.py tests/test_prerequisites.py \
  tests/test_native.py tests/test_execution_tasks.py
```

Passed **230 tests; 15 required Linux/platform cases skipped locally** in 122.62s.
Ruff lint/format, Python compile, shell syntax, ShellCheck, shfmt, planning, package
and whitespace checks passed. Whole local command: 250.86s wall, 169.95s user,
46.08s system; no full suite ran. Log: `.tmp/s0307-local-final.log`.
Status alone previously passed 28 with its two Linux cases skipped, 10.89s.
Its installed-menu PTY journey left settings unchanged, performed no operational
preparation and cleaned the private context. Linux status proof and all remaining
groups subsequently passed at the final candidate below.

First candidate `19bc32c847ecceff97ca57621805a76703963e01` was pushed and
remote-verified. Quick A run `38479329681` failed after 28 passes: the new Linux
fixture wrote its probe helper without preserving executable mode, so the real
supervisor correctly refused it before spawning. The fixture now preserves source
modes and explicitly verifies executable admission. Runtime bytes are unchanged;
the complete local status module then passed 28 with two Linux skips in 6.26s
(6.63s wall, 2.92s user, 2.82s system), plus Python/planning/package checks, before
the corrected candidate push. Log: `.tmp/s0307-local-fixture-fix.log`.
The failed candidate is not accepted evidence.

Final tested code: **`d173d691254023a757361996c5b86ff8f8c609bd`**.
All complete groups and their only required jobs passed at that exact SHA;
parent verified run logs, selectors and the commit's check-run records:

| Group | Quick run / job | Result and pytest cost |
| --- | --- | --- |
| A | [38479557168](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38479557168) / `115578519467` | 30 passed; 18.59s. Actual Linux normal report 4.62s; stalled-probe budget case 9.52s. |
| B | [38479679230](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38479679230) / `115578927859` | 126 passed; 140.76s. |
| C | [38479691428](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38479691428) / `115578968777` | 88 passed, one workstation-without-proc skip; 32.06s. |

Total: **244 passed, one expected workstation-only skip**. Every Linux case
skipped locally ran successfully. A ran first; B/C then ran concurrently with no
overlap in their selected modules. Cost review passed: new status well under two
minutes; larger entry/package regression within the practical range. No timeout
limit increase, omitted core proof, full suite or router run. Logs are retained as
`.tmp/s0307-ci-{a,b,c}.log`, the first failed run as
`.tmp/s0307-ci-a-first.log`, and exact-SHA jobs as
`.tmp/s0307-ci-check-runs.json`. Workers and required CI jobs are complete.

Accepted progress is **8/157 (5.1%), 0/16 main goals (0%)**.
Goal 3 is **2/10 (20%)**; Goal 2 remains **6/9 (66.7%)**.
README/checklist updates in this documentation receipt refer to the tested code
SHA above; the receipt itself is checked proportionately, not runtime-tested anew.

**Pause boundary:** the next small-looking candidates need larger shared behavior:
S07.01 needs real coupled settings and safe native Save; S14.02 needs exact mounted
selection and persisted backup destination; S13.13 needs real syslog/eligible-file
delivery and deduplication. Their missing consumers cannot earn helper-only ticks.
Do not start those Save/storage/logging batches under the completed status task.
On resumption, propose the smallest coherent prerequisite/consumer batch and its
return path toward Goal 2; complete Goal 4 is not automatically required. Remaining
Goal 2 IDs are S02.01, S02.02 and S02.07; basic status alone does not finish them.

## Completed checkpoint — route A; S02.04 accepted

The user selected route A on 2026-10-14: complete S02.04 only, including its
normal-operation tunnel DNS dependency path, focused tests and required CI, then
pause. S02.04 is now accepted at tested code
`e4adda50d141234da6c1f650df6cb7f57fcbeef5`, committed, pushed and remote-verified.
Baseline was clean pushed `807aa1b3845ab7a355c758ccf91f6a1a2e9a98ab`.
Accepted progress is **7/157 (4.5%), 0/16 main goals (0%)**; Goal 2 is **6/9
(66.7%)**. Accepted IDs: S02.03, S02.04, S02.05, S02.06, S02.08, S02.09 and
S03.01. No main goal completed and no other ID receives new credit.
S02.01/S02.02/S02.07 and wider feature work remain outside this package.
No known required S02.04 finishing work is deferred to project 100%.

Consumer: installed normal retained launch through shared prerequisite admission
and installed-opkg repair; fresh setup remains shared-only until tunnel setup.
Completed acceptance: normal scoped native-versus-dig selection, real bounded SRV/A
verification, missing/unusable-only repair, fresh post-probes and safe failure
without configuration/activation changes. Reuse S02.05/S02.06/S02.08 foundations;
S06.03 shares the readiness interface but receives no completion credit.
Historical review: [S02.04 DNS scope review](PLAN_V2_audit.md#s0204-dns-scope-review).

Completed runtime/test owner: `s0204_runtime` strong worker for
`modules/helpers/{bootstrap,launch,probe}.sh`, `modules/lib/{prerequisites,dependencies}.sh`,
and directly affected dependency/retained-launch/config-scope tests and fixtures.
The worker has released all files; no overlapping writers. Parent owns plans,
generated metadata, integration, review, gate selection, acceptance and publication.
Historical review: [S02.04 DNS safety review](PLAN_V2_audit.md#s0204-dns-safety-review).

Required gates: written focused consumer/capability tests, applicable existing
shared-foundation groups, static/package/planning checks and parent review;
complete applicable Quick Checks groups at the exact candidate SHA, with runtime
cost review. Full suites are not due. The selected route includes the normal
subgoal pause checkpoint push/CI/acceptance receipt; no force-push, deployment,
router execution, release or next-package authority is added. Local gates and all
four exact-candidate Quick groups passed. Workers, local tests and CI monitoring
are complete; no required job remains active. Pause here with no next package.

Historical review: [S02.04 failure-handling review](PLAN_V2_audit.md#s0204-failure-handling-review).

Final worker host checks passed
107 tests with 10 platform/tool skips in 63.09s after the cleanup fix. Parent
regenerated package metadata and reviewed the production calls/failure paths.
The complete local gate passed on the reviewed dirty tree based on `807aa1b`:
**299 passed, 55 platform/tool skips, four optional diagnostics deselected**,
137.02s pytest; 137.48s wall / 59.03s user / 43.83s system. Python 3.14.0,
pytest 9.1.1, Homebrew Bash POSIX on macOS; no Linux or router proof is implied.
Exact grouped Linux/BusyBox proof subsequently passed as recorded below; S02.04
is accepted. Main-goal full suites remain due only when every Goal 2 subgoal is done.

Exact local selection is every module in groups A–D below. Initial command:
`CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' /usr/bin/time -l .venv/bin/python tools/test.py --focused <A–D modules>`.
All planning/package, Ruff lint/format, compile, shell syntax, ShellCheck and shfmt
gates passed; the behavior stage found one obsolete shared-inventory test argument
expectation (225 passed, 19 skips before stop). Parent updated that adapter to the
now-explicit dig path while retaining its shared-only scope assertion; targeted
case, changed-file lint/format/compile and planning/package/whitespace checks pass.
Final complete selection reused unchanged successful statics:

```sh
CFMGR_TEST_SHELL='/usr/local/bin/bash --posix' PYTEST_DISABLE_PLUGIN_AUTOLOAD=1 \
  /usr/bin/time -l .venv/bin/python -m pytest -q -ra --strict-config \
  --strict-markers --maxfail=1 --durations=10 -m 'not diagnostic' \
  tests/test_dependency_reinstall.py tests/test_config.py \
  tests/test_config_observation.py tests/test_dependency_selection.py \
  tests/test_prerequisites.py tests/test_native.py \
  tests/test_dependency_consumer.py tests/test_execution_tasks.py \
  tests/test_install.py tests/test_package.py tests/test_storage.py \
  tests/test_storage_mounts.py tests/test_mount_keeper.py \
  tests/test_dependencies.py tests/test_retained_launch.py
```

Logs: `.tmp/s0204-local-focused.log`, `.tmp/s0204-local-final.log`.

Complete focused gate mapped to final changed consumers and foundations:

| Group | Whole test modules under `tests/` | Purpose / prior BusyBox cost |
| --- | --- | --- |
| A | `test_dependency_reinstall.py`, `test_config.py`, `test_config_observation.py`, `test_dependency_selection.py`, `test_prerequisites.py`, `test_native.py`, `test_dependency_consumer.py`, `test_execution_tasks.py` | Scoped native/dig policy, shared tools, normal/force dispatch, schema/current scope and fatal supervision; prior 39.60s. |
| B | `test_install.py`, `test_package.py`, `test_storage.py`, `test_storage_mounts.py`, `test_mount_keeper.py` | Fresh shared-only consumer, package identity, storage/worker protection; prior 55.75s. |
| C | `test_dependencies.py` | Real installed-opkg controller/receipts, cancellation, storage loss, cleanup and concurrency; prior 229.42s, including distinct full-supervision installer proof. |
| D | `test_retained_launch.py` | Actual normal scoped DNS, retained repair/post-probes, force/alternate-provider regression and settings/Off preservation; prior 84.27s. |

Groups are disjoint and exclude optional diagnostics. Prior costs guided scheduling;
the actual acceptance costs are below. The new normal-consumer group ran and was
reviewed separately. Every group passed at the same final SHA using pinned setup
and isolated mutable fixtures. No full host/CI suite ran. Applicable Quick CI
resolved the local platform skips.

Candidate `e4adda50d141234da6c1f650df6cb7f57fcbeef5` is committed, pushed and
remote-verified. Every run below targets that same SHA; at most two groups ran
together. `s0204_ci_wait` completed wait-only monitoring. Parent verified logs,
measured cost, run conclusions and all four required jobs through the exact-SHA
check-run records. A transient Actions jobs-list HTTP 502 was resolved through
that independent endpoint; no test or job failure was waived.

| Group | Exact Quick Checks run | Result / pytest cost |
| --- | --- | --- |
| A | [38468697992](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38468697992) | Passed: 225 passed, one workstation-only skip; 48.82s. |
| B | [38469080381](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38469080381) | Passed: 92 passed; 53.96s. |
| C | [38468896698](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38468896698) | Passed: 21 passed, four optional diagnostics deselected; 145.14s, within the practical three-to-four-minute range. |
| D | [38468709628](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38468709628) | Passed: 15 passed; 108.11s. New normal DNS integration remains within the two-minute target. |

Combined focused CI: **353 passed, one workstation-only skip**, four optional
diagnostics excluded. Captured logs: `.tmp/s0204-ci-{a,b,c,d}.log`; exact job/SHA
receipt: `.tmp/s0204-ci-check-runs.json`. Normal required proof uses Ubuntu 24.04
and pinned native-host vendor BusyBox, controlled DNS responses and isolated
storage fixtures; it does not establish Merlin/ARM/live-provider qualification.
This later checklist/README/handoff receipt changes no tested runtime or tests.
Its own gate is planning/count/link/privacy, package identity, whitespace and
parent review; it names the tested code SHA without claiming runtime tests at the
documentation commit. Final docs subgoals remain deferred under their readiness gate.

## Previous checkpoint — instruction maintenance

The user authorized using refreshed skills and removing superseded duplication
from this repository's AGENTS.md, after confirming that CFMgr rules override
conflicting global guidance. Parent owns this instruction-only cleanup and this
handoff receipt. Preserve all product contracts, acceptance, root-level records,
the 3–5-minute blocker rule and existing runtime/publishing permissions.
The scope is skill references and redundant procedure removal; no Sxx.yy target
is selected or started.

Historical review: [Instruction maintenance review](PLAN_V2_audit.md#instruction-maintenance-review).
On the instruction-only tree based on `edcb8cd`, `.venv/bin/python tools/check.py`
and `git diff --check` pass. Product plan, checklist, review notes, README and
runtime are unchanged; the pre-existing handoff/session ledger is preserved.
No runtime tests or CI were due. The user subsequently authorized its normal push;
`807aa1b` was pushed and remote-verified. That instruction-only checkpoint did not
resume runtime work; the route A authorization above now sets the active boundary.

## Previous checkpoint — S02.06 selected dependency reinstall accepted

The user resumed on 2026-10-14: identify any genuinely small independent task
under the corrected acceptance rules; otherwise start and finish S02.06.

Historical review: [S02.06 smallest-task scope review](PLAN_V2_audit.md#s0206-smallest-task-scope-review).

S02.06 is complete after implementation, focused local/static checks,
parent/independent review and every complete applicable Quick CI group at exact
`03a4f01bc3860be11b5cff2d1faf61f595b589f2`. This documentation receipt records that
tested code SHA; it does not claim a new runtime test on its own later commit.
Pause at the requested subgoal boundary; no next package is selected or started.
No router execution, deployment, main promotion or release is authorized.

Accepted progress: **6/157 (3.8%); 0/16 main goals (0%)**. Goal 2 is **5/9
(55.6%)**; Goal 3 remains **1/10**. The sole new accepted ID is **S02.06**.
Accepted IDs are S02.03, S02.05, S02.06, S02.08, S02.09 and S03.01. No main goal
completed. At that checkpoint Goal 2 still needed S02.01, S02.02, S02.04 and S02.07. No known required
S02.06 finishing work is deferred to project 100%; final guide subgoals remain
deferred under the approved readiness phase gate. Baseline was `a9e7e25`.

All source/test ownership below is released; workers, local commands and required
CI jobs are complete. Parent owns this acceptance receipt and final verification.

| Package / consumer | Completed ownership | Verified result / gate |
| --- | --- | --- |
| S02.06 installed Advanced options and `--reinstall-dependencies` action | `runtime_reinstall` strong worker: `cfmgr.sh`, `modules/helpers/{launch,bootstrap,probe}.sh`, `modules/lib/{config_observation.awk,prerequisites.sh,dependencies.sh}`, narrowly needed source-inert dependency/DNS helper, and affected `tests/test_*`/existing fixtures. No overlapping writers. | One confirmed action; selected mandatory/active scoped direct set; native-first optional tools; installed alternate provider; guarded current-state/storage checks; actual force completion and fresh post-probes; unchanged feature settings. Written consumer and core failure proof, then parent review and complete affected focused gates. |
| Integration / acceptance / CI | Parent only: all planning files, README if accepted, generated catalog/manifest, gate mapping and publication. | Preserve source/host/BusyBox/live evidence boundaries, package integrity and existing safety guards. Complete grouped Quick runs at the exact candidate SHA; no full suite for this subgoal. |
| Read-only support | `native_dns_contract`: pinned/upstream query syntax/output evidence; `reinstall_entry_review`: entry, scope and before-repair guard review. Neither writes or runs tests. | Parent resolves findings with the sole runtime writer before final integration; no independent acceptance or publication. |

Settled design: reuse retained launch and installed-opkg repair/supervision; do
not build another controller. Confirmation occurs once before native preparation
replaces stdin or creates action state; cancellation/EOF/non-TTY cannot authorize
reinstall. The narrow menu supplies this actual action only and does not complete
general navigation. Native schema-checked extraction supplies only current
generation/scope, rechecked before mutation. Configured tunnel scope includes Off
but excludes installed-only/idle maintenance. Native DNS inability must be
positively identified, never inferred from a network outage; unknown/unsafe
capability defers. Fixed bounded SRV/A checks qualify selected DNS tools separately
from feature readiness. A coalesced repair is deferred reinstall, never success.
Preserve existing unresolved-child/guard, FD phase and snapshot-migration rules.

Historical review: [S02.06 native DNS source review](PLAN_V2_audit.md#s0206-native-dns-source-review).

Implementation is committed and normally pushed through `03a4f01`;
the strong worker has released all source/test ownership.

Historical review: [S02.06 runtime interface review](PLAN_V2_audit.md#s0206-runtime-interface-review).

The completed test package covers actual entry/confirmation, stale generation/scope refusal,
native-versus-dig DNS policy, coalesced/failed/unresolved repair and one real
retained force lifecycle with `jq-full` and byte-preserved settings/Off. DNS
responses are controlled adapters, not live provider evidence. Parent owns all
acceptance and publication; no worker is authorized to start another package.

Initial complete local gate on the reviewed dirty tree based on `a9e7e25`: **258 passed,
55 platform skips, four optional diagnostics excluded**, 185.60s pytest; wall
187.16s, user 71.39s, sys 55.02s. Command: `.venv/bin/python tools/test.py --focused`
with all modules in groups A–D below. Its planning/package, shell syntax, Ruff,
format, compile and ShellCheck stages passed; it stopped at shfmt differences in
bootstrap. Parent applied shfmt, verified byte-identical normalized `shfmt -mn`
commands before/after, rechecked syntax/format/package/whitespace, and resumed
the complete same pytest selection using `/usr/local/bin/bash --posix`, strict
config/markers, `--maxfail=1 --durations=10 -m 'not diagnostic'`, with plugin
autoload disabled. Receipts: `.tmp/s0206-local-focused.log` and
`.tmp/s0206-local-pytest.log`. No full suite ran. Required Linux/BusyBox proof
is now complete in groups A–D at the final candidate below.

Parent regenerated `manifest.txt`; catalog inventory is unchanged. An earlier
worker ShellCheck against superseded source was cancelled (exit 130), supplying
no proof; final runner ShellCheck passed. All workers and local commands are
complete. Candidate `b56026f948d25706f754c8e051f7a25a72fc36f2` is committed,
normally pushed and remote-verified. Required Quick runs at that exact head:
A `38439720618` failed in the new Linux callback fixture: its release adapter
omitted keeper state `released`, correctly causing production cleanup to retain
the claim. The assertion alone did not establish whether the callback had run.
Parent restored the complete adapter state and moved the callback-marker check
before the result assertion. Runtime is unchanged. B `38439743516`, C
`38439748042`, D `38439753616` were cancelled promptly; none supplies acceptance.
Repaired candidate `6eeccb07d6e0b2220976c29cb3b1ba84c37faa41` is committed/pushed.
A `38440334338` passed: **184 passed, one workstation-only skip**, 33.01s pytest
(33.17s wall, 12.19s user, 8.79s sys). B `38440589853` passed **92 tests**, 53.12s
pytest (53.30s wall, 27.42s user, 24.45s sys). D `38440600062` then found a second
fixture issue: synthetic opkg expected the force flag after `install`, although
the unchanged real worker passes `opkg --force-reinstall install ...`. Parent
reproduced the original argv rejection (exit 2, no shell error), corrected the
fixture and verified acceptance (exit 0) plus refusal of misplaced flags/unrelated
packages. Focused fixture syntax, ShellCheck, shfmt and whitespace passed. C
`38440595213` was cancelled as superseded; no acceptance from partial runs.
Runtime remained unchanged through candidate `fd91e893f65ca90da770a2942b54e8196e4a9bfb`.
D `38441351653` passed **15 tests**, 100.09s pytest (100.27s wall, 52.10s user,
47.75s sys); A `38441692910` and B `38441697923` also passed. C `38441702494`
failed the real storage-loss case: owned cleanup resolved, but the required
storage-loss reason/report was absent. That candidate was not accepted.

Historical review: [S02.06 storage-loss report review](PLAN_V2_audit.md#s0206-storage-loss-report-review).

Old-source regression: four failures/one pass, 4.74s; fixed:
five passed, 1.69s. Final local action/consumer modules: **57 passed, 9 Linux
skips**, 17.45s, using `CFMGR_TEST_SHELL="/usr/local/bin/bash --posix"`, strict
config/markers and the pinned pytest. Relevant statics passed. Receipt:
`.tmp/s0206-loss-local-regression.log`. Diagnostic [38443197208](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443197208)
passed the real detach case and all five new controller cases at `03a4f01`: six
passed, 14.34s. This diagnostic did not award acceptance.

Complete acceptance gate at **`03a4f01bc3860be11b5cff2d1faf61f595b589f2`**:

| Group / run | Result | Pytest / wall / user / sys seconds |
| --- | --- | --- |
| [A — 38443406448](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443406448) | 189 passed, one workstation-without-proc skip | 39.60 / 39.79 / 14.29 / 14.15 |
| [B — 38443410771](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443410771) | 92 passed | 55.75 / 56.01 / 27.95 / 26.47 |
| [C — 38443415356](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443415356) | 21 passed, four optional diagnostics excluded | 229.42 / 229.67 / 111.85 / 109.37 |
| [D — 38443419914](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38443419914) | 15 passed | 84.27 / 84.43 / 45.61 / 36.29 |

Parent verified exact SHA, terminal success and every required job/step in all
four runs. The unrequested full-host diagnostic step was intentionally skipped;
no required Linux case was skipped. Total **317 passed, one workstation-only
skip** across the complete 15-module gate. Logs: `.tmp/s0206-{A,B,C,D}-final.log`;
verified job receipts: `.tmp/s0206-acceptance-runs.json`. Gate commands were
`gh workflow run quick-checks.yml --ref develop -f host_baseline=false` with each
complete module selection below and the S02.06 group labels.

Cost review: A/B/D remain below two minutes. C's test stage is within the practical
three-to-four-minute range; its required fully supervised fresh-installer integration
accounts for 181.28s of 229.42s. Job totals including setup/cleanup were A 57s,
B 72s, C 249s and D 108s. Retain that distinct safety/consumer proof; no
extra full run or coverage cut was warranted. These grouped timings do not
measure a new full-suite baseline. No other package may start.

Required focused groups, each at the final candidate SHA (whole modules; optional
diagnostics excluded):

| Group | Test modules under `tests/` | Purpose |
| --- | --- | --- |
| A | `test_dependency_reinstall.py`, `test_config.py`, `test_config_observation.py`, `test_dependency_selection.py`, `test_prerequisites.py`, `test_native.py`, `test_dependency_consumer.py`, `test_execution_tasks.py` | Entry/confirmation, current schema/scope, package selection, finite DNS, native supervision and shared repair dispatch. |
| B | `test_install.py`, `test_package.py`, `test_storage.py`, `test_storage_mounts.py`, `test_mount_keeper.py` | Fresh-consumer regression, regenerated package identity and retained storage/worker protection. |
| C | `test_dependencies.py` | Actual installed-opkg controller, selected force worker, cancellation/loss/cleanup and concurrency. |
| D | `test_retained_launch.py` | Retained launch integration, real healthy force/alternate provider, immutable snapshots, current scope and settings/Off preservation. |

Local statics and all complete focused modules passed before acceptance. The
retained lifecycle reuses immutable setup with fresh mutable state and adds one
real force scenario. No full-suite run was due for this subgoal. Publication
stays on develop; the earlier force-push grant is consumed.

## Prior accepted runtime checkpoint

The requested **S02.05 normal dependency repair** and **S02.08 storage identity/loss**
are complete and accepted after focused tests, parent review and exact full CI.
The user accepted the **8m09s** combined runtime; stop cost tuning here.
**5/157 accepted (3.2%); 0/16 main goals.** Goal 2: **4/9**; Goal 3: **1/10**.
Accepted IDs: S02.03, S02.05, S02.08, S02.09, S03.01. No main-goal audit/full-local
completion is claimed. The accepted S02.06 checkpoint above supersedes these historical counts.

## Documentation reset and final-readiness decision

On 2026-10-14 the user clarified that accepted subgoals must be fully finished,
with no known required work deferred to project 100%. The early S16.02/S16.04
documentation package did not meet that intent. The user explicitly authorized
resetting it, dropping/amending its commits and force-pushing, and clarifying
the specification/checklist so documentation needing the completed codebase is
deferred until final readiness.

The three documentation-only commits `a54ecf8`, `aa3269c` and `72abde8` are removed
from develop's replacement history, based on `29d661f0a1fc550994eafcf1cf2c28d0607a852a`.
README and compatibility text return to that baseline; the premature credentials
page is removed. All runtime/tests/tools/workflows and prior five accepted IDs
remain unchanged. S16.02/S16.04 and all of Goal 16 remain unchecked. The only
replacement changes are the paired plan/checklist timing clarification and this
handoff. Final docs follow implemented/validated runtime, then precede overall
100% implementation readiness; necessary interim corrections earn no docs ticks.
Historical review: [Documentation readiness review](PLAN_V2_audit.md#documentation-readiness-review).
Planning consistency (all 157 mirrored rows and 16 README links), privacy/local
links and whitespace checks pass. README/compatibility and all runtime files
match the pre-attempt baseline; no runtime test or new CI claim is made.

Before reset, all agents were complete and there were no staged or untracked
files. Verified preservation includes all 78 tracked working files with byte/mode
checks (including the uncommitted acceptance correction), patches, index/status
inventories and a complete verified commit bundle. Recovery is private under
`.tmp/doc-reset-preservation-20261014-72abde8/`; local-only safety ref
`refs/safety/docs-before-reset-20261014` retains the former head. See its
`RECOVERY.md`: create a separate recovery branch from that ref/bundle, then apply
the preserved dirty patch or recover selected files from the verified tar.
All unrelated ignored reference, firmware and test/dependency caches remain in
place. The full hidden parent-session record above is preserved.

That replacement documentation checkpoint was force-pushed with an exact lease
against `72abde8c1ed8b12792577c153c77f4ecf9631635` and verified at `a9e7e25`.
The one-time rewrite authority is consumed; later work uses ordinary checkpoint
publication. It grants no other reset, router action, main promotion or release.

Historical review: [S02.06 earlier design findings](PLAN_V2_audit.md#s0206-earlier-design-findings).

## Prior verified checkpoint — shared repair and CI policy

- Latest policy/workflow checkpoint: **`3d47219d6f3c93f0152d7b812830067f8290a000`**,
  committed, pushed and remote-verified. [Focused CI 38276757146](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38276757146)
  passed all **32 runner tests** at that exact SHA in 0.13s, job **20 seconds**;
  workflow syntax and local runner tests also passed. Full Checks is now manual
  for main-goal completion; complete focused groups accept subgoals. No additional
  full suite ran. Receipt: `.tmp/focused-policy-ci.log`.
- Tested code/test/workflow commit: **`81d2b29fa42374283f3b18d9de37e32f2880628e`**,
  pushed and remote-verified on develop. Runtime is unchanged from `9e2563d`;
  subsequent code changes optimized tests/runners/workflows.
- Exact full [Checks 38274552711](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274552711)
  passed all required jobs/steps. Host: **355 passed, 26 platform skips**, statics
  included, **1m45.42s**. Vendor BusyBox: **380 passed, 1 workstation-only skip**,
  **6m05.86s**. Four optional diagnostics were excluded in each stage. Job including
  setup/cleanup: **8m09s**. Parent verified terminal success and full head SHA.
- Final focused Quick batches at that candidate: [3C 38274342379](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274342379)
  **92 passed, 47.45s**; [3E 38274310684](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38274310684)
  **15 passed, 66.23s**, down from 173.54s. Unchanged 3D at `e128968`,
  [38272259819](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38272259819), passed
  **21 tests in 158.46s**, down from the cancelled 434.51s diagnostic. The full gate
  above subsequently proved every required group together at the final candidate.
- Focused implementation gate: **107 passed, 17 Linux skips**, relevant static/
  planning/package checks and review passed; `.tmp/retained-local-focused.log`.
  Final affected storage-mount/retained fixture tests: **21 passed, 9 Linux skips**;
  relevant lint/syntax/format checks passed. No extra full local suite was run:
  this is a subgoal/pause checkpoint, not a complete main-goal marker.
- Full receipt: `.tmp/final-full-checks.log`. Supporting timings:
  `.tmp/quick-{3c,3e}-final.log`, `.tmp/quick-3d-layered.log`,
  `.tmp/quick-host-baseline-confirmed.log`; module map `.tmp/quick-groups.json`.
  Earlier run history is retained at `81d2b29:PLAN_V2_handoff.md`. Cancelled runs
  supply no acceptance.

## Preserved documentation and checkpoint policy

README and checklist reflect only accepted progress. Development and compatibility
remain approximately 3 KB each; commands, links and evidence limits were checked.
Compatibility covers router/Merlin targets, not verified hardware support. AGENTS
is approximately 25 KB, below 32 KB. Handoff session IDs, retained design evidence,
permissions and recovery references are preserved. The completed 18-module cost
review and required core edge coverage are retained; actual test composition/
optional diagnostic limits are in [review notes](PLAN_V2_review_notes.md).

S02.06's workers and required CI completed at `03a4f01`; its documentation receipt
used proportionate planning/link/privacy, counts/session-record and whitespace
checks. Current package ownership and required proof are recorded at the top of
this handoff; S02.04's receipt remains in its completed section. Before any later
resumption, verify `git status --short` and exact
local/remote develop state. The earlier reset grant has been consumed.

AGENTS owns standing routes: focused local work commits/continues; required Linux
proof uses small repair selections followed by all applicable grouped focused CI;
full local and full CI suites occur only at complete main-goal markers. Aim for
two minutes or less per focused batch, with three to four minutes as the practical
upper range where feasible; preserve every plan core edge. The user accepted
current full-suite cost; do not reopen optimization
without new evidence. Keep guides concise and leave session/issue notes out of the
checklist and README.
At complete project 100%, the latest user target is roughly **40 minutes maximum**
for the full suite including setup, replacing the earlier 10–15/20-minute ceiling.
Current full workflow timeout remains 20 minutes; increase only as measured,
necessary coverage grows, never beyond 40 minutes. Current eight-minute cost is accepted.

## Ownership and implemented boundary

Current ownership and the next stop boundary are recorded at the top of this handoff.
Parent owns the four planning files, integration, CI decisions and acceptance.
S02.06 and S02.04 are accepted. S02.01, S02.02 and S02.07
require a later user resumption after the selected checkpoint.

Implemented consumers:

- Fresh `cfmgr.sh --install` shares native admission and prerequisite inventory/
  normal repair, then uses its existing fresh-only publication transaction.
- Installed default `cfmgr.sh` (absolute or relative invocation) dispatches the
  isolated retained-launch controller. Explicit help/source-copy defaults remain
  harmless. A bounded immutable private config snapshot and complete setup/layout
  are checked before repair; full package digests follow healthy SHA admission.
- Confirmed Advanced options / `--reinstall-dependencies` force only the selected
  mapped direct set, including a usable alternate provider and configured-tunnel
  DNS additions where native capability is positively absent. Fresh probes and
  stale-state/storage guards preserve settings/history/Off.
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
failure retains RAM evidence. That accepted storage-observation checkpoint did
not implement automatic recovery/adoption; the currently authorized native
settings recovery is described separately at the top of this handoff.

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

No normal feature menus, remote package acquisition/update,
complete native recovery/safe Off, provider activation or general Save workflow is
accepted. Goal 4 foundations earn no separate credit. Detailed prior design and
worker history remain recoverable from `b90eb6e:PLAN_V2_handoff.md`.

## Retained execution/storage design evidence

Historical review: [Retained execution and storage source review](PLAN_V2_audit.md#retained-execution-and-storage-source-review).

## Next-session boundaries

The completed test-cost checkpoint and exact passing gates are recorded at the
top of this handoff; S02.01 is the latest accepted product subgoal. At the next
user-authorized resume, first reconcile branch/HEAD/status and the documentation
receipt with the exact tested candidate and CI runs above. Reuse valid proof
instead of automatically repeating tests. No next product target is selected.
The user has set project-wide selection order: follow the
[work ordering rule](AGENTS.md#implementation-and-preservation), finishing
independent subgoals and prerequisites before larger features. Use a coordinated
multi-goal batch only when no smaller ready, independently completable outcome
remains. This ordering policy does not authorize another package.
Final documentation subgoals follow the explicit phase gate in the specification
and checklist; do not select interim documentation as an early completion. Finish
started libraries/subgoals before switching; inspect existing consumers, tests and
checklist before choosing the next smallest item. Return toward Goal 2, originally
a prerequisite for Goal 1; S04.01/S04.08/S04.09 foundations earn no extra ticks.
Select only the next smallest independently completable package; pause before a
large multi-goal crossover. Full local suites remain main-goal
gates. Required development CI is Ubuntu/vendor BusyBox; exact firmware/ARM/flash/
hooks/provider qualification remains separately authorized beta work.

The user has chosen to keep CFMgr in the existing checkout without additional
worktrees; follow the [checkout policy](AGENTS.md#validation-and-publication-gates).
Existing detached-worktree metadata remains preserved; no cleanup is authorized.

Use the existing `.venv` and pinned dependencies. ShellCheck is pinned to 0.11.0.
Regenerate changed runtime metadata with `.venv/bin/python tools/package.py --write`,
then `--check`. Preserve optional guest tooling/caches as unaccepted diagnostics.

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
