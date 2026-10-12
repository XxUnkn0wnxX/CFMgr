# CFMgr v2 — deferred review notes

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md)

Only relaxed acceptance points and significant risks needing possible later review.
Use the existing goal/subgoal IDs; these notes do not award acceptance or change scope.

## 2. Installation, storage and dependencies

| Review note | ID | Subgoal and required result |
| --- | --- | --- |
| **Relaxed coverage:** dead-leader/live-thread and mixed-root stress cases are optional diagnostics. Normal repair, retry, bounded cancellation and drive loss remain required. Revisit if actual package behavior or reported failures justify it. | S02.05 | **Normal dependency repair:** Installed opkg, healthy no-op, missing/unusable-only repair, post-probes and bounded later retry. |
| **Storage-safety limitation:** new aliases created by normal opkg scripts can briefly write into RAM or the underlying filesystem after detachment, before cancellation. CFMgr's admitted paths stay guarded; new script aliases have no atomic fallback-write guarantee. Revisit if real scripts use them or testing reveals a material corruption risk. | S02.08 | **Storage identity and loss:** Resolve current `/opt`, verify its backing mount and required-data reads, revalidate saved observations, guard CFMgr write paths, pin each action and stop/report owned work on loss. |
