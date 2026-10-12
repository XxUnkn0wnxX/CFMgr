# CFMgr v2 — deferred review notes

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md)

Only relaxed acceptance points and significant risks needing possible later review.
Use the existing goal/subgoal IDs; these notes do not award acceptance or change scope.

## 2. Installation, storage and dependencies

| Review note | ID | Subgoal and required result |
| --- | --- | --- |
| **Optional diagnostics:** dead-leader/live-thread, mixed-root stress, standalone success and the consecutive real failure/success retry. Required real update-failure cleanup, later-retry consumer tests and fresh/retained real success cover the retry contract in separate layers; they do not execute both real repairs consecutively in one process. Bounded cancellation and drive loss remain required. Extra file/nested-mount topology stays in the dedicated compatibility case. Revisit only if real failures justify the additional cost. | S02.05 | **Normal dependency repair:** Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| **Storage-safety limitation:** new aliases created by normal opkg scripts can briefly write into RAM or the underlying filesystem after detachment, before cancellation. CFMgr's admitted paths stay guarded; new script aliases have no atomic fallback-write guarantee. Revisit if real scripts use them or testing reveals a material corruption risk. | S02.08 | **Storage identity and loss:** Resolve current `/opt`, verify its backing mount and required-data reads, revalidate saved observations, guard CFMgr write paths, pin each action and stop/report owned work on loss. |
