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
Codex Session: 01a14803-6b23-7b22-b261-581bee5dfce5
Eighth ID verified 2026-10-17 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a151ca-9b8c-7d21-a424-11c9013c54fd
Ninth ID verified 2026-10-19 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a15c84-5da2-7eb2-b960-72ad3e59dd86
Tenth ID verified 2026-10-21 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a16765-b366-7071-8c80-8f4770f6036c
Eleventh ID verified 2026-10-23 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1848b-c9de-7121-b7c2-6611f14d8aea
Twelfth ID verified 2026-10-29 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1aa23-d93d-7883-a4ea-5c956b11b24c
Thirteenth ID verified 2026-11-05 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a1ab24-f6a2-7762-a94f-84e2d211d566
Fourteenth ID verified 2026-11-05 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Audit](PLAN_V2_audit.md) · [Review notes](PLAN_V2_review_notes.md) · [Rules](AGENTS.md)

## Paused — repair checkpoint complete

All five original reopened subgoals **S02.04, S02.05, S04.02, S07.08 and S14.04**
are repaired and accepted. The subsequent old **S03.09 Gateway Health** contract
failure is also repaired and accepted. No reopened repair remains.
Accepted product subgoals: **26/157 (16.6%)**. Main goals: **0/16 (0%)**.
The thirteen previously unticked partial feature areas remain explicitly inventoried
below; they are not silently treated as unstarted or awarded completion credit.

The user authorized finishing these repairs, saving the next whole-subgoal scope,
trimming this handoff and then pausing. **The next scope is saved only. Do not start
its implementation until the user resumes it.** The completed temporary Daybreak
handoff was retired at the user's request, including its obsolete AGENTS paragraph
under separate explicit approval. Its report remains in immutable Git history and
the private retirement snapshot; the audit links to the archived report.

Branch: `develop`, existing checkout only. Tested/published code:
**`8d4cc4fff9d47d63452b4246cfce9b03e9cd9a0c`**. The documentation receipt is the
commit containing this condensed handoff; it changes no runtime/test/workflow bytes
and must not be described as a separate runtime-tested candidate. Resolve its exact
published SHA from Git and the final checkpoint response on resume.
No required worker, test process or CI job remains active. There is no pending
permission question, deployment, release or router action.
Final planning/link/privacy, staged 157-row parity and whitespace checks passed;
independent receipt/trim review passed. No runtime tests were run for the
documentation or Daybreak-handoff deletion.

## Final proof and limits

[Final complete Checks 42043449375](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/42043449375)
passed at the exact code SHA above. Parent independently verified source/remote
parity, every required parent job and all six module jobs. Parent cancellation
cleanup correctly skipped. The passing full gate must not be repeated for this
unchanged code or for the documentation/deletion receipt.

| Module/platform | Final result | Job including setup |
| --- | --- | --- |
| Backup host | 429 passed, 1 native-only skip | 2m40s |
| Backup BusyBox | 430 passed | 8m27s |
| Manager host | 879 passed, 30 platform skips; 4 optional diagnostics excluded | 3m00s |
| Manager BusyBox | 908 passed, 1 workstation-only skip; 4 optional diagnostics excluded | 8m40s |
| Status host | 291 passed | 1m02s |
| Status BusyBox | 291 passed | 2m21s |

Children: [Backup 42043514135](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/42043514135),
[Manager 42043518421](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/42043518421),
[Status 42043522866](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/42043522866).
Native prerequisite Dev gates at the same SHA: failing-node repair `42042344295`
(1 passed/1.10s), remaining focused nodes `42042561350` (29 passed/1.60s), complete
Status `42042832209` (291 passed/116.73s; 2m13s job), complete parser admission
`42042838620` (10 passed/4.65s; 20s job). The final full gate ran only after these
passed. Metadata and compact proof are private under `.tmp/s03-09-gateway/ci/`;
detailed findings and wall/CPU data are in the audit.

The original five repairs also have their independent complete core receipt at
`9c3c58732f803f649d7c021568bbedb69d14b49d`, Checks `42032878335`. They were retained
during the immediate Gateway review and all current complete gates passed again
after that necessary additional runtime repair. Do not infer unrelated feature
completion from either passing suite.

Local source/package/planning/syntax/format/compile gates passed; optional
ShellCheck was explicitly skipped for the Gateway change. S03.09/S03.10 retain
their user-approved CI placement for behavior/AWK after the earlier Apple-AWK
failure; their local boxes remain blank. This exception is specific to those
outcomes, not a blanket exemption for later packages. No main goal completed, so
no full local suite was due. Representative Ubuntu/vendor BusyBox is not live
Merlin/ARM/flash/provider qualification; beta qualification remains separate.

The installed Health journey intentionally covers a lean real DDNS entry path.
Configured Gateway behavior is proved by focused actual collector/worker/HTTP
boundary tests. Do not restore a full-project/router simulation. Prior unexplained
Health deadline and package.inventory UNKNOWN failures remain historical evidence,
not claimed diagnosed production fixes; see the audit/review notes. Gateway Health
reads one bounded items page and makes whole-list claims only with coherent complete
pagination evidence; missing or additional-page evidence remains partial/UNKNOWN.

## Next checkpoint — saved scope only

**Selected route A: finish S08.03 — Selected-WAN IPv4.** This is the smallest
independently completable existing partial outcome found by the dependency review.
It uses the existing saved WAN selection and eligible explicit Health consumer;
it does not start another unfinished setup wizard. The prior manager-source-check,
S10.10-only and incomplete IP-Sync draft/picker proposals are not active scopes.

**User-visible outcome:** after confirming/correcting WAN selection through existing
Settings, an eligible `--health` run reports each selected WAN's current local IPv4
class, verified external public address and source association. Distinguish public
match (no translation observed), private upstream NAT evidence, shared-address/CGNAT
evidence and public-address mismatch. Preserve both observations; neither private
space nor a mismatch proves carrier ownership, and no result promises inbound
reachability. Unknown mapping, wrong egress, changed source, invalid/nonpublic
response or insufficient budget produces explicit Unknown, never private-address
fallback, confirmed inactivity or deletion authority.

**Ready foundations:** reviewed scoped WAN Save, native WAN/interface/protocol
collection, classification, supervised private workers, trusted HTTPS and the real
Health/report/cleanup path already exist at the tested code SHA. Settings and basic
Status remain network-free. Preserve Health's existing configured-scope and
prerequisite gates; this checkpoint does not add unconfigured probing. Valid retained
configuration is input to an existing diagnostic consumer, not a pretend setup
implementation. No DDNS/IP-Sync publisher must be built first for this observation.

**Required work inside this one completion outcome:**

1. Establish the supported native method for proving selected IPv4 egress, using
   current interface/protocol/source and routing evidence. Verify actual curl/native
   capabilities; do not assume modern host-only interface syntax. A default route
   or an interface argument alone does not prove the selected path. If ordinary
   supported WAN paths require new dependencies or router routing changes, preserve
   that concrete blocker for decision instead of weakening the acceptance.
2. Extend the shared network owner with bounded source-bound external observation
   and revalidation before accepting a response. Use fresh invocation-local facts;
   boot/reconnect/remapping/selection changes must not reuse stale source identity.
   Account for every selected source, including bounded-budget Unknown outcomes.
3. Integrate the actual Health collection/report path with per-source results and
   truthful NAT/mismatch meaning. Preserve its read-only behavior, trusted hosts,
   TLS, existing holds, credential isolation, aggregate limits and cleanup. No new
   persistent cache, parallel resolver or top-level module is justified.
4. Prove the normal supported path and required failure boundaries, review affected
   accepted consumers, finish all prescribed gates and only then award S08.03.

This first capability check is part of completing S08.03, **not** a prerequisite-only
checkpoint or acceptance credit. An implementation that always returns Unknown
for ordinary supported WANs does not complete the row.

**Ownership and dependency order:** one foundation owner takes
`modules/lib/network.sh`, necessary fixed operations in `modules/helpers/worker.sh`
and focused network tests. Settle its result contract and focused proof before a
consumer owner changes `modules/status.sh` and Health/WAN tests. Parent integrates,
regenerates package metadata, reviews shared consumers and owns the records. Keep
the existing schema and WAN settings unless a demonstrated integration need
justifies a scoped adjustment. Independent read-only review may run alongside
settled implementation; overlapping foundation/consumer edits remain sequential.

**Lean gates:** available local focused behavior and relevant statics; cheap
classification/source-change/ambiguity/invalid-response cases; one bounded
Linux/BusyBox routing integration showing that distinct selected paths cannot
silently return another WAN/VPN path's observation. Reuse controlled HTTPS and
supervision fixtures, without a full-router simulation. Fix any exposed error with
the smallest native selection first, then run all complete affected Dev modules at
the final candidate, including shared network/worker consumers. Review measured
cost and perform independent affected-row acceptance review with parent
reconciliation. Run one passing exact-candidate full core last; no full local suite
is due. The old S03.09/S03.10 local exception does not extend to this checkpoint.
The broader accepted/partial audit is due at this next runtime checkpoint.

**Credit:** S08.03 only, expected **27/157 (17.2%)**, main goals still **0/16**.
Supporting portions of S08.01/.05/.06 and execution safeguards earn no separate
ticks; reconcile their inventory honestly against the resulting implementation.
Operational family states, background rediscovery, persistent cache/queues, IPv6
authority, setup, publication, S10.10, hooks, updater and logging remain outside
this scope. No credential/authorization-policy change is inherently required;
any actual security-control expansion still needs the proper routing/access.
No live router or provider action is authorized by this saved plan.

**Stop/return route:** on a future user start, finish this whole row and its gates,
update evidence and pause at that checkpoint. Return to the remaining partial-work
inventory with proved IPv4 observation available; do not start or preselect the
following implementation batch. At the present checkpoint, save this scope and
**pause before implementation**.

## Unfinished-work inventory and audit cadence

The full current 157-ID classification and evidence live in
[the acceptance audit](PLAN_V2_audit.md#accepted-subgoals-and-partial-work-audit--2026-11-05).
These thirteen rows have partial runtime behavior and remain unchecked:

| ID | Existing behavior / missing completion |
| --- | --- |
| S02.02 | JFFS/RAM/backup paths exist; tunnel-data and feature-log lifecycle missing. |
| S02.07 | Native diagnostics and Store recovery exist; feature Safe-Off/general recovery missing. |
| S03.03 | Main/Settings/WAN menus work; operational feature/update/repair dispatch missing. |
| S03.06 | Help/version/Health aliases work; update/force transactions missing. |
| S03.08 | Readers/privacy/history display exist; verified runtime outcome/event producers missing (roughly 40–60% contract coverage). |
| S04.06 | Existing literal/EOF/non-TTY/default-no input works; secret masking/echo recovery and real wizard consumers missing. |
| S04.07 | Fresh/retained/Store guards exist; feature/update/restore/auth/create restart consumers missing. |
| S04.08 | Existing locks/supervision work; provider/connector descriptor-lifetime consumers missing. |
| S04.09 | Package/current worker bounds exist; updater/provider/connector overlap, late-result and cleanup consumers missing. |
| S07.06 | Default source/pin/catalog work; developer-effective-source and retained self-update consumers missing. |
| S08.01 | WAN preferences/local observations exist; operational family states and background rediscovery missing (roughly 25–40%). |
| S08.03 | Local classification exists; routed external discovery and authoritative mismatch/NAT reporting missing (roughly 15–30%). |
| S13.13 | Limited native notices/diagnostic formatting exist; full feature events, file delivery and deduplication missing (roughly 10–25%). |

Estimates describe broad contract coverage, not accepted progress or remaining
effort. Foundations are distinguished from partial runtime in the audit. In
particular, S14.09/.10/.11 have supporting restore foundations but **no executable
restore controller**. No fake partial percentage is assigned merely because a
future feature can reuse existing helpers.

Last broad audit: **2026-11-06**, at `9c3c587`, triggered immediately by the false
S03.09 tick; all accepted rows and partial work were reconciled. **One runtime
checkpoint since that audit** (the Gateway correction). Broader review is next due
after the next runtime checkpoint, or immediately upon false credit/material drift.
Every runtime checkpoint, including zero-credit repairs, also requires independent
affected-outcome review with parent reconciliation. Documentation receipts do not
advance the cadence. No extra full suite is created for an audit.

## Working-tree drafts and durable decisions

Original unrelated working edits remain deliberately unstaged in `PLAN_V2.md`,
`PLAN_V2_checklist.md` and `PLAN_V2_audit.md`. They include Merlin 3006/VPNMgr PR #62
reference work, fresh-router hook creation requirements/evidence, and the historical
manager-source-check readiness proposal. Preserve and review their actual diffs;
do not publish them wholesale, erase them, or revive the retired source-check
proposal as current scope. The PLAN/checklist mirror in the index must be checked
separately from the dirty working copy. The parent alone writes the five V2 records.

Final receipt bases at `.tmp/s03-09-gateway/pre-final-receipt/` retain working
files and their exact HEAD copies from `8d4cc4f`. For checklist/audit, the parent
staged only subsequent owned acceptance/evidence changes using a reviewed three-way
merge. `PLAN_V2.md` was not staged. Handoff consolidation is separately authorized
and preserves all unpublished intent through the complete snapshot below.

The user approved the global AGENTS clarification: ordinary compatibility changes
retain the normal lane when trusted destinations, account/resource/credential
binding, allowed methods, privacy and access controls are preserved. Gateway's
existing Health correction met that classification after independent/parent review;
the original routing hold was a classification disagreement, not a platform safety
refusal. The verification-only Daybreak child returned ACCESS_UNVERIFIED and did no
implementation. Actual security work still requires its mandated verified access.
No profile/role files changed. Global before/after receipt:
`.tmp/global-agent-routing-2026-11-06/`. Retired admission-task report/recovery:
`.tmp/s03-09-gateway/daybreak-retirement/` and the immutable audit link.

Test policy: realistic normal behavior and core risks; ask whether each costly
case is necessary. Preserve boot-loop/hang/unbounded-work/unsafe-write/corruption
coverage. Fix an error with the smallest valid selection first, then complete every
affected group at the final candidate, then one passing final full core. Dev input
is **space-separated**, one to eight nodes or whole modules, never mixed; validate
it before dispatch. No raw-log dumps, redundant full runs or test-count targets.
Keep visible wall/CPU costs; the reviewed Manager cap remains 12 minutes with a
roughly ten-minute target. All current jobs met that target. Full local remains
reserved for main-goal completion. Apply relevant testing/CI skills on resume.

## Permissions and recovery

Completed checkpoint develop publication includes its repairs and documentation
receipt only. Next-scope implementation requires a new user start. Concurrent
independent work follows the standing project grant, normally at most two coherent
implementation packages; overlapping writers remain serial. No worker can award
ticks, publish, change requirements or advance the checkpoint. Reuse existing
completed investigations rather than repeating them. At pause all owners released.

Use this checkout only; no additional worktree, reset, branch deletion, release,
stable promotion, deployment or evidence cleanup is authorized. Existing detached
worktree metadata remains untouched. Router limits remain in AGENTS.md: brief
read-only inspection and bounded owned scratch under `/mnt/MERLIN/tmp` only; other
writes, execution, packages, settings/services, mounts and provider writes need
explicit permission. No live task is pending. The earlier one-off JFFS attempt and
Actions/history cleanup permissions are consumed. Never publish private router
configuration or `.tmp` evidence. Practical cached JFFS readback cannot certify
kernel-hidden flash failure or persistence over reboot.

This handoff was condensed at the user's explicit request after acceptance and
scope selection. The immediately preceding **complete working handoff**, all record
files, dirty/index patches, branch/source identity and verified SHA-256 inventory
are preserved at **`.tmp/s03-09-gateway/pre-trim-2026-11-06/`**. The complete
14-parent HTML ledger above was preserved byte for byte, including provenance and
order. Structural preservation does not guarantee historical session resumability.
Review the snapshot and merge needed passages; do not overwrite current records
with stale status. Earlier snapshot `.tmp/five-row-resume/pre-trim-2026-11-06/`
is retained too, but predates the final Gateway receipt.

Other recovery/evidence pointers remain private and must not be purged:

- `.tmp/five-row-resume/`, `.tmp/acceptance-audit-2026-11-05/`,
  `.tmp/s04-02-repair/`, `.tmp/daybreak-pause-2026-11-05/`,
  `.tmp/s03-09-gateway/`: repair ownership, snapshots, focused/cost evidence and CI.
- `.tmp/reference-paths.md`, `.tmp/previous-*-reference.sh`: original read-only
  reference location and historical patterns.
- `.tmp/firmware-audit/INDEX.md`, `.tmp/platform-review/source-index.json`,
  `.tmp/storage-review/jffs2-source-provenance.json`: verify hashes/revision/scope
  before reuse. No execute/flash/delete authority follows from possession.
- `.tmp/storage-review/`: owned USB scratch/cleanup and consumed JFFS attempt
  receipts. USB proof does not establish JFFS durability.
- `.tmp/history-before-salvage-e571555.bundle`, SHA-256
  `3e5599dcc3c531a1c61edb0c891526c5ebf290e976349c001af3a68918e32365`, plus
  `refs/safety/salvage-before-e571555`: committed history. **Uncommitted salvage
  rewrites were not fully snapshotted and cannot be promised recoverable.**
- `.tmp/doc-reset-preservation-20261014-72abde8/RECOVERY.md` and
  `refs/safety/docs-before-reset-20261014`: separately preserved documentation
  replacement, verified dirty files/patches and committed history.
- `.tmp/salvage-history-receipt.txt`, `.tmp/main-removal-receipt.txt`,
  `.tmp/actions-cleanup-20261012.json`, `.old/PLAN.md` and detached-worktree metadata:
  preserve historical evidence; their destructive permissions do not recur.

On resume, verify actual branch/HEAD/diffs, remote SHA, saved scope, worker/job state
and available preservation files before acting. Read this compact state plus the
relevant current contracts and audit dispositions; historical snapshots are
recovery evidence, not new authorization or a queue of unfinished old CI runs.
