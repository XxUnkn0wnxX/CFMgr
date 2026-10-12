# CFMgr v2 — deferred review notes

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md)

Only relaxed acceptance points and significant risks needing possible later review.
Use the existing goal/subgoal IDs; these notes do not award acceptance or change scope.

## 2. Installation, storage and dependencies

| Review note | ID | Subgoal and required result |
| --- | --- | --- |
| **Layered tests:** failed-update, daemon and loss cases use real view/mount/keeper/task algorithms with a foreground view-operation adapter. Per-operation native supervision is covered by separate supervisor tests and full fresh/retained repair consumers; its combination with each failure scenario is not repeated. **Optional diagnostics:** dead-leader/live-thread, mixed-root stress, standalone success and consecutive real failure/success retry. Required real failure cleanup, later-retry consumer and fresh/retained success cover retry in separate layers. Extra file/nested-mount topology stays in the compatibility case. Revisit only if real failures justify the cost. | S02.05 | **Normal dependency repair:** Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| **Storage-safety limitation:** new aliases created by normal opkg scripts can briefly write into RAM or the underlying filesystem after detachment, before cancellation. CFMgr's admitted paths stay guarded; new script aliases have no atomic fallback-write guarantee. Revisit if real scripts use them or testing reveals a material corruption risk. | S02.08 | **Storage identity and loss:** Resolve current `/opt`, verify its backing mount and required-data reads, revalidate saved observations, guard CFMgr write paths, pin each action and stop/report owned work on loss. |
