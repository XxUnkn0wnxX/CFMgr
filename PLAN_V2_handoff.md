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
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Review notes](PLAN_V2_review_notes.md) · [Working rules](AGENTS.md)

## Active — S03.07 basic status dashboard

The user resumed on 2026-10-14: work on the next smallest task, allow automatic
checkpoint publication after its test/review gate, and pause before a large
multi-goal crossover. Reuse the existing `develop` checkout; no worktrees.
Starting HEAD is `2e68bda5a977a33a093e8ee207708f84f8a5f193`, clean, with the two
local instruction commits following the published S02.04 receipt. Those commits
remain preserved. This permission covers the selected runtime candidate's normal
focused Quick Checks checkpoint and acceptance/documentation receipt; award a
tick only after all required exact-candidate groups pass. No full-suite checkpoint,
history rewrite, deployment, router execution or release is authorized.

The Astra smallest-task audit scanned all 157 rows and returned PASS WITH NOTES:
S03.07 is the smallest demonstrated ready full product outcome. Missing provider
writers do not block its read-only consumer; the plan permits absent evidence.
The selected independent package is **S03.07 only**, using the real installed
choice `0` before operational prerequisite repair. Provide bounded native router,
resource, mount, selected-WAN/address and NTP observations, manager/source and
separate feature settings, safe bounded typed local outcome/history reading,
ages, concise issues and truthful next actions. Invalid/unavailable config or
records must not suppress independent resource checks. No network/provider call,
repair, feature activation, operational history writer or live-router execution.
Supporting read/privacy/native-entry contracts overlap S03.08/S02.07; neither ID
earns acceptance from this package. Do not expand into full diagnostics, Save,
hooks, lifecycle, logging or provider implementation. Pause if a large coordinated
cross-goal prerequisite proves necessary.

Runtime/test owner: `s0204_runtime` strong worker completed entry/launch integration,
the source-inert status module/parsers and required native supervision adapters/tests;
all write ownership is released. Parent owns the planning files, generated package
metadata, gate selection, integration and publication. Freeze the bounded typed local-evidence contract in runtime
comments/tests; never infer provider success or connected state from PID/file
presence or invented placeholders. Preserve existing JSON/parser and launch
contracts; status must show invalid configured/enabled combinations rather than
using operational config rejection as an all-or-nothing report gate.

Parent-approved reader design: project a bounded snapshot of existing private
config only; no new history file/writer. Optional `history.<feature>.status`
and `history.network.status` envelopes carry typed schema/generation/timestamps,
family outcomes, allowlisted reasons and at most five events. Family publication
records stay historical. A current runtime observation additionally needs explicit
runtime origin, matching boot/config generation and bounded nonfuture age;
restored/absent-origin evidence cannot establish current connectivity. Network
freshness also binds the selected WAN. Unknown/raw fields are never printed.

Native evidence: retained cache source/image facts were checked by
`status_native_evidence` (completed); parent additionally fetched pinned Merlin
revision `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` source into ignored
`.tmp/s0307-source/` and matched each Git blob SHA against GitHub's contents API:
`rtstate.c` (`5b7f52fa39e32e62bbe3cb1f6b4d0db123c8c213`),
`misc.c` (`6206ab19f1a958f26c25aea51d7377c8251f2ed5`) and
`df.c` (`d79c11a6c0efb9008d2bfd8f76b386c2d594ffae`).
`shared/rtstate.c:564` selects native primary via `wanN_primary`, not the
last-configured `wan_unit`; `:359` distinguishes PPP from ordinary interfaces.
`shared/misc.c:2346` reads that unit's `ipaddr`. BusyBox `coreutils/df.c`
supports `-Pk` independently of DF_FANCY; clear POSIXLY_CORRECT for KiB output.
Cached image inventory confirms `/bin/nvram`; pinned init uses
`firmver.buildno_extendno`, and original common code treats `ntp_ready=1` as ready.
These are source/static facts only, not live router or complete firmware proof.

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

Run the complete affected local gate with static/planning/package checks and parent
review, then all three Quick groups at the exact candidate. Record results and
measured group costs before acceptance; no full suite is due. Lightweight isolated
PTY status/back/exit checks use fixture data only, without router access.

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
preparation and cleaned the private context. The new Linux status group must pass
and have its cost reviewed before acceptance. Candidate push/Quick gates are next;
do not start another implementation package while required CI is pending.

Accepted progress remains
**7/157 (4.5%), 0/16 main goals (0%)**; Goal 2 remains **6/9 (66.7%)**.

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
Scope refinement from the independent Astra review: configured tunnel (including
Off) makes DNS tools applicable, not tunnel launch eligible. Normal shared/safety
admission must distinguish DNS not-required/verified/deferred. Ordinary DNS
outages never reinstall healthy tools or block manager/DDNS/IP-Sync; strict
reinstall verification remains unchanged. Storage/ownership/supervisor failures
and stale-scope refusal remain fatal. A resolved DNS-only package failure may
defer only DNS after fresh shared-tool post-probes prove manager admission safe.
S06.03 still owns full tunnel launch/readiness, NTP and reachability integration.

Completed runtime/test owner: `s0204_runtime` strong worker for
`modules/helpers/{bootstrap,launch,probe}.sh`, `modules/lib/{prerequisites,dependencies}.sh`,
and directly affected dependency/retained-launch/config-scope tests and fixtures.
The worker has released all files; no overlapping writers. Parent owns plans,
generated metadata, integration, review, gate selection, acceptance and publication.
`s0204_scope_audit` completed its read-only review.
`s0204_safety_review` independently reviewed the DNS-only repair-failure exception
and post-repair cleanup. Its resolved-migration cleanup finding and real-worker
failure-origin assertion are fixed; the focused follow-up passed. No edits or
acceptance authority were delegated to reviewers.

Required gates: written focused consumer/capability tests, applicable existing
shared-foundation groups, static/package/planning checks and parent review;
complete applicable Quick Checks groups at the exact candidate SHA, with runtime
cost review. Full suites are not due. The selected route includes the normal
subgoal pause checkpoint push/CI/acceptance receipt; no force-push, deployment,
router execution, release or next-package authority is added. Local gates and all
four exact-candidate Quick groups passed. Workers, local tests and CI monitoring
are complete; no required job remains active. Pause here with no next package.

The Astra audit required revising the initial failure handling; its three
findings are incorporated into the worker contract: separate shared/DNS outcomes,
separate configured scope from effective inventory scope when native DNS is
unknown, and preserve fatal supervision/storage/stale-scope failures. It confirmed
that the real normal retained consumer can close S02.04 without Goal 6 lifecycle.
No requirement or acceptance gate changed. Final worker host checks passed
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
is selected or started. Astra Max's read-only audit passed with one procedural
note: retain CFMgr's disjoint Quick Checks groups. That wording is retained;
parent review confirms the removed procedure is covered by available skill text.
On the instruction-only tree based on `edcb8cd`, `.venv/bin/python tools/check.py`
and `git diff --check` pass. Product plan, checklist, review notes, README and
runtime are unchanged; the pre-existing handoff/session ledger is preserved.
No runtime tests or CI were due. The user subsequently authorized its normal push;
`807aa1b` was pushed and remote-verified. That instruction-only checkpoint did not
resume runtime work; the route A authorization above now sets the active boundary.

## Previous checkpoint — S02.06 selected dependency reinstall accepted

The user resumed on 2026-10-14: identify any genuinely small independent task
under the corrected acceptance rules; otherwise start and finish S02.06. Parent
and Astra Max reviewed the remaining IDs and found no qualifying smaller complete
runtime task. S02.06 is complete after implementation, focused local/static checks,
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

DNS refinement supersedes the earlier no-host proposal in the private snapshot:
usage with no hostname is ambiguous. Complete fixed SRV invocations using the
supported `-q`, `--type=` and `-type=` grammars distinguish known option/type
rejection from accepted-query failure. All three pinned ordinary implementations
reject leading options before resolver work; pinned LEDE explicitly rejects SRV.
The positive parser follows [BusyBox 1.36.1's SRV/A formatting](https://github.com/mirror/busybox/blob/1_36_1/networking/nslookup.c#L370),
excluding server-address preambles and not requiring a non-authoritative marker.
This defines a supported parser interface, not another firmware-support claim.

Implementation is committed and normally pushed through `03a4f01`;
the strong worker has released all source/test ownership. Parent/static review
resolved the BusyBox callback-discovery issue (`type`, because the pinned ash
omits `command -v`) and verifies fresh post-probes for every selected optional
Entware tool even if a native provider changes during the action. The completed
test package covers actual entry/confirmation, stale generation/scope refusal,
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
storage-loss reason/report was absent. That candidate was not accepted. Source review
found that an exceptional task return can reach resolved controller cleanup
without the final attachment observation performed on the normal task path.
The correction adds a final observation/report after resolved task cleanup;
unresolved native children, task cleanup or event reporting retain guards without
proceeding to release. The new controller regression reuses the existing adapter
and actual repair/event bodies: old source reproduces missing loss reporting;
five scenarios cover lost/attached completion and unresolved task/native/event
states. Parent and independent analyst reviewed the eight-line runtime change
and test assertions. The shared adapter now explicitly supplies its attached
storage assumption; the real detach assertion remains intact and gains bounded
failure labels. Old-source regression: four failures/one pass, 4.74s; fixed:
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
Astra Max's focused audit passed with notes; the replacement resolves its
conflicting-timing, S16.02–S16.05 consistency and essential-current-guidance notes.
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

S02.06 was unimplemented at that pause. Its read-only design findings remain in the
private snapshot's handoff and safety history: configured-tunnel-only DNS scope,
truthful coalesced-repair deferral and capability-versus-outage classification
need implementation before a genuine reinstall action can pass its focused gates.
Pinned native nslookup source inspection found no SRV support in either variant;
source evidence is not live capability proof. No runtime attempt was discarded.

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
checks. Current S02.04 ownership and required proof are recorded at the top of this
handoff. Before any later resumption, verify `git status --short` and exact
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

The completed ownership and pause boundary are recorded at the top of this handoff.
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

No normal feature menus, remote package acquisition/update,
complete native recovery/safe Off, provider activation or general Save workflow is
accepted. Goal 4 foundations earn no separate credit. Detailed prior design and
worker history remain recoverable from `b90eb6e:PLAN_V2_handoff.md`.

## Retained execution/storage design evidence

The private descriptor-bound view and fallback guards are integrated with normal
opkg repair; acceptance is established by the exact full CI receipt above. Do not assume router cgroups/namespaces
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
  Descriptor binding has representative vendor-BusyBox/Linux proof, not firmware/router execution.
- Entware root `36db8558ac7840d993cb11df1e47e0326d681077`; opkg source
  `80503d94e356476250adaf1f669ee955ec26de76`. Root feed references are unpinned;
  supplemental recipes `entware-packages/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd`
  and `rtndev/05d2b0f695b8bc1973a9c88a8f08764c8fcb8271` do not prove installed IPKs.
  Selected recipe simplicity does not constrain all existing unpacked scripts.

## Next-session boundaries

S02.06 and S02.04 are complete through their required checkpoints. Their selected
route A is finished; the user has now resumed the next-smallest-task selection
under the active scope above. The user has set project-wide
selection order: follow the [work ordering rule](AGENTS.md#implementation-and-preservation),
finishing independent subgoals and prerequisites before larger features. Use a
coordinated multi-goal batch only when no smaller ready, independently completable
outcome remains. This records the ordering policy; no new implementation package
is selected by this instruction update.
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
