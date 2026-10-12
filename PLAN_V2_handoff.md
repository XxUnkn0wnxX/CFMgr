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

## Current checkpoint and stop boundary

**Active goal 2: installation, storage and dependencies.** S02.03 now has the
complete trusted-local fresh-install consumer and passing focused host tests.
Goal progress is **1/9 focused-passed subgoals = 11.1%**, with final S02.03
acceptance pending exact Linux/BusyBox/kernel CI. Product completion stays
**0/16 = 0%**. Supporting prerequisite/storage work does not complete S02.04,
S02.08 or S02.09. Goal 2 remains the announced prerequisite for original goal 1.

The user explicitly authorizes this subgoal/tool checkpoint commit and push,
required full CI, fixes/re-pushes until green, then acceptance evidence and a
**pause for the day**. Do not start another subgoal after acceptance. Do not update
README: no main goal is complete, and optional developer tools do not belong in
its completion table. No full local suite is required for this authorized early
platform checkpoint. Main-goal audit/full-local/full-CI gates remain unchanged.

No unanswered approval remains. The user approved the separate developer-tools
sections in plan/checklist and explicitly requested KEY/USR configuration modes.
New tool scope/entries still need approval; evidence updates do not.

## Implemented package and reviewed ownership

All workers returned ownership; parent owns integration and final review. No
router session or worker job is active. The first candidate was published as
`5492a7d1cd1f9eb381c7595fa57d0d915c9e54eb`; exact CI found the failures below.
The parent and a bounded package-tools worker own only those corrections.

- `cfmgr.sh --install` enters an isolated native shell and consumes a complete
  explicitly trusted local package. Native preflight admits JFFS2, actual mounted
  ext2/3/4 Entware identity/UUID, tools, private paths and practical free space.
  There is no public path override, remote acquisition or dependency repair yet.
- `modules/helpers/bootstrap.sh` checks manifest/catalog/inventory/modes/bytes,
  blocks any retained setup before defaults, claims a private recovery guard,
  copies and verifies one package, generates private extensionless passive
  configuration, publishes entry and completion last, and checks exposed flush
  failures. Fresh failure preserves guards; repeated/corrupt/retained setup never
  resets data. No feature, hook, service or provider activation is implemented.
- `config.sh`, `storage.sh`, `mountinfo.awk`, `prerequisites.sh` and fixed `probe.sh`
  supply inert defaults, storage admission and bounded actual-tool operations.
  Parent reviewed consumers/failure paths and fixed root-relative Entware support.
  Review caught controller-only signals leaving a writer; the correction routes
  signals through owned-child cancellation/reaping. A Linux active-writer test
  covers it. RAM FD0 transfers to FD5 after flock probes, before manifest reads.
- `tools/package.py` builds/checks deterministic metadata and trusted-local package
  mapping. The test runner now rejects stale metadata. Regenerate catalog/manifest
  with `--write` after any runtime source change, then verify with `--check`.
- Portable SSH launcher uses ignored `tools/router.local.json` and a fake template.
  KEY uses SSH config/public-key authentication; USR requires username/password
  with private config and restricted ASKPASS. Blank/null port inherits SSH config.
  Actual ignored config is KEY with blank user/password/port, the existing SSH
  alias and authorized scratch. No password is sent through argv/env/logs.
  `--check-config` is local-only; no live execution of the new launcher occurred.
- Portable shell probe requires explicit execution, admits a selected mounted
  scratch directory, preserves its base and cleans only verified owned artifacts.
  Linux descriptor/cleanup tests cover alternate paths including spaces.
- CI keeps seven jobs, at most two kernel jobs, make -j2 and one CPU/256 MiB guest.
  Each kernel boots once, testing both pinned Entware ABIs against an actual
  RAM-MTD JFFS2 and external ext4 volume. Only the NVRAM script-enable query is
  emulated. Guest checks run the unmodified entry, passive defaults, installed
  bytes/modes, repeat/corrupt/incomplete rejection and cleanup. This is isolated
  kernel evidence, not exact Merlin firmware or physical-flash acceptance.

Workers: kernel_compiler returned installer/prerequisites; ci_tools returned
platform fixtures and package tests; portable_tools returned launcher/runner
checks; platform_audit independently confirmed the signal/FD correction. Parent
reviewed diffs and acceptance boundaries. No worker may publish or award ticks.

## Latest repair and ownership

Current exact run `38197550576` at `5b1d1aef45146dd8fb8fdfe62810e06fbe11336e`
finished with host/BusyBox/planning green and all four kernel guests timing out
at 180 seconds during the first install. Even 4.19 times out; legacy entropy alone
does not explain it. Independent source review found no proved loop/collision;
the native attachment checks have substantial synchronous process overhead.
Parent owns diagnosis. `ci_tools` returned narrow disposable-guest progress
diagnostics in `tests/fixtures/platform/init.sh`, preserving the unmodified
packaged entry and all acceptance assertions. Parent reviewed the diff and real
child exit handling. Focused platform gate: **36 passed**, plus all static gates.
The diagnostic candidate is ready for the authorized exact CI run.
Do not increase the guest budget without forward-progress evidence. No router
execution, product behavior change or new tool scope is authorized by this work.
User amendment: for trace-only diagnosis, collect the first kernel failure/log
and cancel the remaining run promptly; do not wait for every kernel to fail.
The repaired acceptance candidate still needs all required exact-commit CI jobs.

Trace candidate `03b0db30d4f241d4dc12834e62306dea7d9f6bc4`, run `38198511174`,
showed steady progress from operation 13 at 10s to operation 76 at 60s after
legacy startup. First failed kernel log is
`.tmp/platform-review/s02-03-trace-first.log`. Parent cancelled immediately after
retrieval; both legacy jobs had finished failing by then, modern jobs cancelled.
No tick. `ci_tools` returned the aggregate guest budget correction in
`tools/test_platforms.py` plus focused runner failure tests in
`tests/test_platforms.py`: allow 600s for startup and two complete guarded
installs, retain per-operation bounds and failure rejection. Focused platform gate
passed **40 tests** and all static checks. Parent reviewed the runner and tests:
nonzero exits/timeouts cannot pass despite success markers; missing markers fail.
Parent owns the AGENTS user amendment, integration and publication; all worker
ownership returned. Candidate is ready for required exact CI. If the next failure
is the same shared cause, retrieve its log and cancel remaining jobs promptly.

Run `38198892155` at `0babd62d0e91873a5acaae2a6df83487c9e74d3d` completed the
first real install/cleanup on 4.1.52, then its test assertion failed because
Entware jq omits ONIGURUMA regex support. Parent retrieved
`.tmp/platform-review/s02-03-budget-first.log` and cancelled remaining jobs.
Host/full BusyBox passed (163/166 tests respectively; expected platform skips).
`ci_tools` returned the fixture correction: fixed synthetic ext4 UUID via mke2fs
and an independent exact saved-UUID comparison without jq regex. Parent reviewed
it; focused/static gate passed **40 tests**. Parent queues 4.19.294 first in the
unchanged four-profile/max-two matrix for faster shared-failure feedback. Runtime
and cached build inputs remain unchanged. Another exact acceptance run is required.

All worker ownership is returned. Parent reviewed the native timer correction:
fixed `/bin/usleep 50000` supplies three short supervision waits, bootstrap admits
it, and the timeout child uses whole-second sleep. Guest fixture stages native
usleep while explicitly disabling FLOAT_SLEEP. Required BusyBox tests call the
actual vendor applet and assert fractional-sleep rejection; host adapter is
labelled. Source-only imports and argument counts remain unchanged.
Worker focused installer/prerequisite/platform gate: **63 passed, 4 Linux-only
skips in 28.50s**, plus lint/format/compile/shell/whitespace checks. Parent regenerated
metadata and ran the prerequisite runner/static gate. Corrected exact CI is still
required. Fourth run `38196992713` at `0c44d04` completed with host/BusyBox/planning
success and all kernel guests failing at this same native fractional-sleep gap.
Read-only router metadata confirmed native `/bin/usleep`; no router write occurred.

Cost review: Linux host suites were roughly 7s and mandatory BusyBox roughly 14s;
local combined focused work was roughly 32s. Current changed kernel builds took
about two minutes each before guest execution. Required caches survived failures.
The timer repair changes BusyBox configuration only, so compiled kernels/compiler/
feed/source inputs should restore. No full local suite, extra boot per ABI or
unrelated benchmark run was added.

## Current validation and next actions

Combined focused command on the current dirty tree:

```sh
.venv/bin/python tools/test.py --focused tests -k 'install or prerequisite or mountinfo or config or router_probe or dev_runners or platform or package or probe or canonical_attachment or volume_uuid'
```

**126 passed, 11 explicit Linux-only skips, 21 deselected in 31.88s**. Ruff lint/
format, compile, host POSIX syntax, ShellCheck, shfmt, package metadata, planning,
links/privacy and whitespace passed. Log: `.tmp/s02-03-focused.log`. The 11 skips
are owned supervisor/active writer and descriptor-based probe cleanup cases;
required CI must supply their platform proof. Host installer tests replace only
unavailable proc supervision with a documented adapter; guest entry tests do not.

Focused tools include planning checker/runner, package construction and unsafe
inputs, SSH KEY/USR/port/quoting/credential handling, platform input/cache/staging/
log oracle and probe admission/cleanup. No live SSH is needed to test transport.
`requirements-dev.txt` remains correct: pinned pytest/Ruff/shfmt; JSON and SSH
launcher use stdlib. `.venv` pip check passed. Local ignored config validates.

1. Finish the focused CI corrections below, regenerate package metadata, commit
   and push. Verify the remote full SHA.
2. Wait for all seven exact-commit Checks jobs. No further product implementation
   after push until green; fix only failures, focused-check and re-push as needed.
   Preserve cache inputs; changed kernel/BusyBox configurations intentionally
   invalidate affected compiled fixtures, not compiler/feed/download caches.
3. Verify all four kernel/feed/install markers and required native ownership/
   cleanup tests. Do not accept skips, old runs or build success as runtime proof.
4. Tick only S02.03 and fully proved tools, recording tested code SHA/run. A
   documentation-only receipt is not separately runtime-tested. Push receipt,
   fully refresh this handoff and pause with no active required jobs.

## Current CI corrections

First candidate `5492a7d`, [Checks 38196136386](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38196136386),
failed before runtime acceptance. Corrected at `9038a99410894153955e42f5082cbb94b959d35e`:
regular Finder metadata no longer enters inventory/catalog/output; unsafe objects
and metadata-only directories still fail before copying. Parent verified metadata
in a clean Git export. Vendor BusyBox uses `CONFIG_VOLUMEID`; the invalid symbol
was corrected. `FEATURE_BLKID_TYPE=n` matches baseline source and a brief read-only
native query. UUID parser accepts absent TYPE based on verified mountinfo, while
rejecting any supplied empty/conflicting TYPE. No router writes occurred.
Repair focused gate: **28 passed, 134 deselected in 6.77s**, all static gates passed;
`.tmp/s02-03-repair-focused.log`.

Second candidate [Checks 38196367041](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38196367041)
reached ShellCheck and kernel configuration. CI ShellCheck 0.9 reports SC2015 and
SC3013 that local 0.11 accepts: parent made failure branches explicit and scoped
the existing proven native BusyBox `test -ef` exception to descriptor functions.
Focused gate: **46 passed, 3 Linux-only skips, 113 deselected in 6.80s**, with static
checks (`.tmp/s02-03-lint-repair-focused.log`). Kernel admission correctly rejected
missing JFFS2: both [4.1](https://raw.githubusercontent.com/torvalds/linux/v4.1/fs/Kconfig)
and [4.19](https://raw.githubusercontent.com/torvalds/linux/v4.19/fs/Kconfig) require
`MISC_FILESYSTEMS` before the JFFS2 option can remain enabled. Parent added that
fixture dependency; its configuration regression passes. No guard was relaxed.
Preserve restored/saved source/compiler/feed/BusyBox caches for the next attempt.
Third candidate `8a6caf1dd1adb5297cb32dbde9a4ba50d383c6b1`,
[Checks 38196576936](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38196576936),
passed Linux host/static (158 passed, 4 platform-specific skips) and required
BusyBox (161 passed, one host-without-proc case intentionally skipped; all native
ownership/fsync/cleanup cases ran). Kernel guests reached storage probe success
then rejected absent `/dev/mtdblock0`: `MTD_RAM` is not the RAM-backed test driver.
Parent corrected to `MTD_MTDRAM` with Kconfig 8192 KiB/128 KiB geometry. Source
shows module-only sizing arguments cannot configure the built-in 4.1 driver;
no-op boot arguments were removed. Independent read-only review found legacy
ABS_POS exists only in 4.1; it is now version-scoped. No other concrete guest
plumbing blocker found. Platform focused/static gate: **36 passed, 0.62s**,
`.tmp/s02-03-mtd-focused.log`; actual corrected guest execution remains pending.

Full exact CI remains pending; raw logs are `.tmp/platform-review/s02-03-*.log`.

## Retained evidence and known limits

Previous runtime/cache proof: `d71c813a73da5e0b07a1f0c1af2292aeb17e1111`,
[Checks 38190294055](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38190294055),
all seven jobs passed. Warm native and 4.19.294 reruns proved installed Python,
APT archives, compiler/feed inputs and compiled fixture reuse. Logs/receipts:
`.tmp/platform-review/cache-*-ci.json` and `ci-38190294055-*.log`. Later docs-only
commits do not replace that runtime SHA. Prebuilt GCC bundles are downloaded;
GCC is not compiled in CI. Legacy 4.1 guests spend roughly 103s in entropy startup;
bounded source review found no simple proven correction. Do not reopen speculative
optimization or weaken proof to hide it. Current guest deadline is 180s; if actual
new workload exceeds it, diagnose from retained logs before changing the bound.

Pinned public source/ABI details live in `tests/fixtures/platforms.json`: kernels
4.1.51, 4.1.52, 4.19.183, 4.19.294; vendor BusyBox 1.25.1; prebuilt GCC 4.9.4/8.5;
aarch64-k3.10 and armv7sf-k3.2 Entware closures. Generic CI does not complete
S02.09 model/native option/TLS qualification. Raw provenance remains ignored in
`.tmp/platform-review/source-index.json`, `.tmp/storage-review/jffs2-source-provenance.json`
and `.tmp/firmware-audit/INDEX.md`; inspect hashes/scope before reuse.

The user accepted the practical JFFS2 limitation after requesting bounded
alternatives: check every exposed outcome, stage/read back/recover coherently,
but do not claim cached rereads detect kernel-hidden flash failures or guarantee
persistence across restart. Source confirmed ignored flush errors in all selected
kernels; no simple independent verifier was proved. Save remains unimplemented.
No raw-flash verifier, cache clearing, mount experiment or disruptive workaround
is authorized. The managed-On-only Cloudflared self-repair/syslog requirement is
recorded in S06.10/V06/V60; it remains future work, not the current goal.

Original read-only cloudflared/setup reference is located through ignored
`.tmp/reference-paths.md`; captured router files are supplemental. Preserve source
parity and do not restore obsolete archived percentages or partial-feature ticks.

## Router permissions and receipts

Brief read-only `ssh router` is authorized. Router default login is zsh; explicitly
use its `/bin/sh` for native/POSIX work. Host uses Homebrew zsh/Bash, not macOS sh
as router proof. Baseline: GT-AX11000 388.12_2, kernel 4.1.51, BusyBox 1.25.1;
native id/stat/timeout/setsid absent. Existing Entware is aarch64-k3.10.

The one-off JFFS probe permission was consumed before mutation; no JFFS retry is
authorized. Small nondestructive tests may write only within `/mnt/MERLIN/tmp`,
keeping that base and cleaning verified owned artifacts. Other router writes,
JFFS tests, installs, services/settings, packages, mounts, stress or deployment
need explicit permission. No live router mutation occurred for this checkpoint.

Prior authorized USB probe passed native file/directory flush, rename/readback
and verified cleanup, base mode700 retained. Private receipts:
`.tmp/storage-review/router-usb-probe-20261012.sh` and `.log`, stream SHA256
`9f7ab9b495a99f4df17809c0c21a7b049dfd93a9bae332d638298a6a93c70f08`.
Consumed JFFS attempt files: `router-probe-20261012.sh`/`.log` in the same directory,
SHA256 `2476176c378e11d300be4925b6ccef2c32c533bdc04d0621920a106a71fa939a`;
probe path 17489 confirmed absent. This earlier USB pass does not prove the new
launcher, JFFS durability or Save. No active router connection remains.

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
