# Temporary development notes

[Project overview](../README.md) · [Current handoff](../PLAN_V2_handoff.md)

This tree is a planning baseline. There is no shipped runtime, installer, runtime
test suite or BusyBox acceptance. Read the [current handoff](../PLAN_V2_handoff.md)
before implementing the next approved workflow.

## Current checks

From the repository root, use Python 3.11 or newer. No dependency installation
is needed:

```sh
python3 tools/check.py
```

The checker verifies specification/checklist agreement, README goal coverage,
active document links/privacy and the absence of unvalidated runtime. Success
prints `Planning consistency passed` and exits zero. Failure lists the affected
files or requirements and exits nonzero; correct those findings before proceeding.

The **Planning-only checks** CI workflow runs the same command for relevant develop
pushes and pull requests targeting develop: runtime/package files, tests,
developer tools and CI/test configuration. Documentation-only changes use the
local check above and skip CI. These checks do not earn product completion ticks
or prove router compatibility.

## When implementation resumes

Replace the planning-only gate alongside the first real workflow. It deliberately
rejects new runtime until meaningful focused/full tests and required platform
coverage are provided. Reuse a suitable existing local venv and recreate pinned
developer dependencies as needed; Python and test tools never ship to the router.

Subgoals require complete behavior, written focused tests and applicable exact CI
proof. Main goals also require the full local and CI suites, documentation and
parent review. Keep fixtures isolated and CPU use modest. Follow the detailed
[working rules](../AGENTS.md) and [checklist](../PLAN_V2_checklist.md).

Keep these notes small until most or all implementation goals are met. Then
prepare the [planned documentation set](../PLAN_V2.md#documentation-set) for the
finished product, including architecture, developer and operating guides.
