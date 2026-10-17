# CFMgr v2 — deferred review notes

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Audit record](PLAN_V2_audit.md)

Only relaxed acceptance points and significant risks needing possible later review.
Use the existing goal/subgoal IDs; these notes do not award acceptance or change scope.

## 2. Installation, storage and dependencies

| Review note | ID | Subgoal and required result |
| --- | --- | --- |
| **Optional lint cost:** during category consolidation, ShellCheck 0.11.0 extended dataflow analysis grew to roughly 8 GB RSS after about three minutes and was stopped. Whole-module checks with `--extended-analysis=false` provide explicitly limited supplemental lint; extended dataflow remains unproved. The [ShellCheck manual](https://github.com/koalaman/shellcheck/blob/master/shellcheck.1.md) documents the resource/coverage tradeoff. Required shell syntax, formatting and behavior/CI gates remain unchanged; core Checks/Quick already exclude optional ShellCheck. Do not split runtime categories merely to accommodate the linter or silently claim equivalent analysis. Runner/workflow defaults have not been changed. | S02.01 | **Modular distribution:** One verified package with extensible feature modules, shared libraries grouped by reused responsibility and thin entry/hooks. |
| **Layered tests:** failed-update, daemon, loss, retained-launch and optional retry/thread/mixed-root cases use real view/mount/keeper/task algorithms with a foreground view-operation adapter. Per-view-command native supervision and unresolved-child accounting are covered by separate supervisor tests, the full fresh-installer repair consumer and the optional standalone repair reference; their combination with every scenario is not repeated. Retained config migration, publication, reporting and return keep their native callbacks and assertions. **Optional diagnostics:** dead-leader/live-thread, mixed-root stress, standalone success and consecutive real failure/success retry. Required failure cleanup, later-retry consumer and fresh/retained success cover retry in separate layers. Extra file/nested-mount topology stays in compatibility/detach cases. Revisit only if real failures justify the cost. | S02.05 | **Normal dependency repair:** Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| **Storage-safety limitation:** new aliases created by normal opkg scripts can briefly write into RAM or the underlying filesystem after detachment, before cancellation. CFMgr's admitted paths stay guarded; new script aliases have no atomic fallback-write guarantee. Revisit if real scripts use them or testing reveals a material corruption risk. | S02.08 | **Storage identity and loss:** Resolve current `/opt`, verify its backing mount and required-data reads, revalidate saved observations, guard CFMgr write paths, pin each action and stop/report owned work on loss. |

## 3. Configuration, menus and status

| Review note | ID | Subgoal and required result |
| --- | --- | --- |
| **Host fixture timing:** the complete installed status-menu journey uses a ten-second process timeout instead of the shared three-second navigation timeout. It completed in 4.87s during isolated macOS diagnosis; the earlier limit interrupted a report still in progress. Production deadlines, return/no-preparation assertions and shorter navigation-test limits remain unchanged. This is host test tolerance, not router latency qualification. | S03.07 | **Basic status dashboard:** Router/resource/address header and compact feature state, last verified family updates, age and current issue summary from local evidence. |

## 4. Save, cancellation and recovery

| Review note | ID | Subgoal and required result |
| --- | --- | --- |
| **Existing firmware limit:** the approved contract checks all exposed write, rename, flush and verification results, but qualified JFFS2 firmware can hide internal flash-flush errors. Cached readback cannot certify restart persistence. The [durable-commit audit](PLAN_V2_audit.md#s0403-durable-staged-commit-review) records the rechecked source evidence and staging protections; actual flash/Merlin qualification remains deferred to beta. No raw-flash workaround or additional waiver is introduced. | S04.03 | **Durable staged commit:** Pre-change intent/recovery, verified coherent publication and honest flush/write/rollback failure handling within documented firmware limits. |

## 14. Backup and restore

| Review point | ID | Subgoal and required result |
| --- | --- | --- |
| **Native enumeration limit:** the source-matched ash terminal glob avoids `ls` metadata failures caused by disappearing unrelated processes. Like the previous native `ls` loop, its source does not expose every possible error after a partial kernel `readdir`. No-match, invalid names, count/memory/output limits and reported execution failures grant no writer authority; actual relevant process, executable, append-FD and before/after identity checks remain required. Representative Linux tests do not qualify exceptional kernel I/O failures or real-router behavior. | S14.08 | **Backup transaction:** Consistent bounded source/rotation locks, private same-filesystem archive, hashes/mount recheck/atomic commit. |
| **Harness timing:** complete creation, populated capture and functional verification use the production 600s internal archive deadline. Measured native completion supports outer guards of 300s for creation, 150s for populated capture and 120s for verification/semantic integration. Host creation/capture guards remain 180s on macOS; the semantic guard remains 90s. Distinct short deadline, cancellation and ownership/reaping tests retain their assertions, and negative integration tests reject supervision failures as false semantic passes. All required payloads and callbacks remain. These representative CI timings do not establish router performance qualification. | S14.08 | **Backup transaction:** Consistent bounded source/rotation locks, private same-filesystem archive, hashes/mount recheck/atomic commit. |
