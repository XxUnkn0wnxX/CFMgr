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

## Current task and progress

**Resumed by the user.** Compiler/runtime prerequisites now pass. Full CI exposed
two guest/configuration fixture defects; their reviewed correction is ready to push. No new runtime
package may start before this exact-SHA gate passes. Resume inspection found a
clean tree at `5853701dfbd5b00e5746f83a2b6da13e8349e94f`, matching origin/develop,
and no existing child agents. Parent session identity remains the already-recorded
third ID; this resume does not establish a new ID. No router work is running.

**Active main goal: 2 — installation, prerequisites and supported platforms.**
Goal 2 progress: **0/9 focused-passed subgoals = 0%**. The user replaced the former
about-10% workload estimate with equal subgoal-based credit. Partial fixture work
is retained but earns no whole-subgoal credit. AGENTS.md records the new formula;
focused passes increment it while final CI acceptance remains separate, and 100%
still requires all main-goal gates.
Product completion remains **0/16 = 0%**; no subgoal is accepted. Goal 2 is the
announced prerequisite for the user's requested goal 1: complete independent
DDNS, tunnel and IP-Sync workflows with original-source parity. Return to goal 1
when its foundation is ready; announce any further necessary goal switch first.

Local implementation, focused checks and matching CI are authorized. The user
conditionally authorized earlier develop pushes when most substantive subgoal
proof needs unavailable Linux/BusyBox/kernel execution. The current S02.09
platform package meets that condition, which the parent explained before pushing.
Each runtime push requires its full exact-SHA CI green before further implementation;
fix/re-push within this checkpoint is allowed. No full local suite merely for this
platform push. No deployment, provider mutation, release, history reset or main
recreation is authorized. Prior cleanup/publication/main deletion was one-time.

The latest user amendment permits each reviewed subgoal commit after focused tests
pass and reaffirms commit/push/wait/fix for required BusyBox/kernel CI. Keep CI
paths current. At the main-goal boundary, pass all focused checks, complete the
audit, pass the full local suite and full exact-SHA CI before final ticks; then
update/push README, fully refresh this handoff for a new session and **pause**.
Do not continue to the next main goal after that boundary.

The user reiterated that interim development notes must stay minimal: required
tooling/setup and built-in check commands only. Parent trimmed development.md to
that scope; detailed fixture/source/CI progress stays here, with the standing
documentation boundary recorded in AGENTS.md. The user explicitly authorized its
separate documentation push: `ae594bf4f44c6bfc34b3eee88997bf644ccc1515`, verified
equal to origin/develop. That receipt is not runtime CI evidence.

## Router boundary

Brief read-only `ssh router` is authorized; close sessions after reads. Router login
shell is zsh, but native commands/tests explicitly use **router-side `/bin/sh`**.
Host sessions use Homebrew zsh and local POSIX fixtures use Homebrew bash, never
macOS `/bin/sh` as router proof.

The single approved JFFS probe permission was consumed: it failed before writing
because native `id` is absent. Exact scratch and all probe-prefixed JFFS paths were
confirmed absent. **No JFFS retry is authorized.** Further router writes are allowed
only for bounded nondestructive command tests under `/mnt/MERLIN/tmp`. Keep that
base directory, preserve its existing permissions/content and clean only owned
scratch artifacts. No stress, package installs, mounts, service/settings changes,
cache clearing, raw-flash experiments or deployment is covered.

No router SSH or test is currently running. Latest read-only package inspection
used native metadata only, never executed Entware programs. The successful USB
probe receipt below is separate from JFFS acceptance.

## Latest user decisions

- Support the required **GT-AX11000 baseline plus qualified modern Merlin models**.
  Qualify firmware/kernel/userspace ABI against Entware support and available,
  usable required dependencies. Exclude incompatible/unavailable profiles with
  reasons; no obsolete-hardware obligation. Do not silently drop the baseline.
  Temporary Entware loss still requires native recovery. S02.09/V02 mirror this.
- Public source or extracted firmware may supply CI fixtures; parent chooses
  workflow layout. Current package uses pinned public sources, four kernel jobs,
  at most two concurrent jobs, two compiler jobs and one CPU/256 MB per guest.
  No live firmware execution/deployment is authorized.
- **Save limitation:** after initially asking to keep acceptance pending and
  investigate, the user directed a simple practical workaround if possible,
  otherwise acceptance of the firmware limitation. Bounded source review found
  no simple reliable alternative. Parent explained the result and applied that
  conditional fallback to S04.03/V63: check every exposed outcome and retain
  staging, coherent publication and recovery, but document that firmware-hidden
  flash failures may escape detection and lose new state across restart. No
  complex custom raw-flash verifier or disruptive filesystem step is required.
  Extra rechecks cannot manufacture independent durability proof. Save itself
  remains unimplemented/unaccepted; this decision awards no tick.
- **Cloudflared update guard:** S06.10/V06/V60 now require automatic verified
  re-fetch after an interrupted managed binary update leaves a damaged/incomplete
  artifact, as soon as storage/tools/NTP/Internet readiness permits. Same-version
  repair is allowed; normal no-downgrade/protected rollback still applies. Only
  CFMgr-owned, configured **On** Cloudflared is eligible. Off/unconfigured/unmanaged/
  removal or maintenance-only Off cannot trigger it. Public Off also detaches
  repair eligibility, queued work and owned hooks/jobs; no independent repair
  schedule can re-hook/enable it. Preserve binary/config/recovery data and other
  features' shared consumers. A verified self-repair produces a Warning syslog
  message; report failed/deferred attempts honestly, with no false connected claim.
  This is a plan addition, not implementation or a switch away from goal 2.

No approval question is currently open.

## Current code and ownership

Latest published runtime revision, verified on local/origin develop after push:
`a7e3955f35319b50bb0d9ed3ecfd3f09ec005002`.
The separate developer-docs receipt is `ae594bf`; it is not runtime CI evidence.
Inspect current refs and full CI status on resume.
Earlier partial checkpoints remain in ancestry: native helper `3e164914`, probe
correction `6b411736`, platform fixtures `6b91cd8`, policy amendment `b73b9bb`.
No main branch was recreated. The pushed repair changes the platform runner/tests,
manifest, BusyBox config and workflow, plus the approved progress rule and this
handoff. Parent reviewed all returned changes and reran their focused/static gate;
actual kernel execution is pending the current full CI run.

| Owner | Exclusive scope | Current state |
| --- | --- | --- |
| Parent | Planning files, AGENTS.md, docs, integration and final review | Own all accepted requirements and CI gate; inspect every returned change. |
| kernel_compiler | Returned; no active ownership | Private compiler-runtime package completed and parent-reviewed. |
| guest_diagnostic | Returned; no active ownership | Parent-reviewed guest prefix correction and native regression; reused existing applet fixture, pinned mode only. |
| Parent | tools/test_platforms.py, tests/test_platforms.py; integration/plans | Enable 4.19-only VIRTIO_MENU required by its MMIO transport Kconfig; preserve 4.1 configuration and required-option assertions. |
| ci_resume_wait | Completed, no active work | Run 38187447546 at a7e3955 terminal failure confirmed. |
| Other agents | No active ownership | Source/parity/persistence/runtime/probe packages returned. No router work. |

Current S02.04/S02.07–S02.09/S04.03 consumers are developer probes/tests, not a
usable install or Save workflow. `modules/lib/storage.sh` is an inert native flush
wrapper: caller admits storage and opens read-only fd 3; an absolute admitted
fsync utility must return zero with sentinel-only captured output. It rejects
native fsync's diagnostic/zero-exit bug, but cannot recover an error the kernel
never exposes. No storage admission, process deadline or full transaction claim.

`tools/router-storage-probe.sh` is explicit opt-in. It uses proc UID fields,
numeric ls, native `test -ef` and held directory/file descriptors; no native id/stat
assumption. Its retained USB base is separate from its owned scratch. The current
probe changes since the verified run are lint comments only.

Worker rules: no plan edits, router access, publication or spawning. Preserve all
required proof; no fixture fallback or skip to conceal a missing native applet.
Parent reviews source, real consumer/failure paths, diff and focused evidence
before accepting ownership or publishing.

## CI gate and local evidence

- [Run 38187447546](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38187447546),
  exact `a7e3955f35319b50bb0d9ed3ecfd3f09ec005002`: failed. Planning, host/static
  and full native BusyBox suite passed. Both 4.1 kernels built/booted but failed
  the guest's diagnostic-prefix expectation after successful native storage probe;
  4.19 jobs failed the required VIRTIO config assertion. Both pinned sources gate
  MMIO transport behind VIRTIO_MENU, absent in 4.1; the parent adds that 4.19-only
  prerequisite. Pinned fsync/libbb sources prove the omitted `fsync: `
  prefix; correct the fixture, retaining status/diagnostic/rejection assertions.
  Local HEAD and origin/develop were verified equal after push. No final tick.
- Guest/configuration correction on dirty `a7e3955`: parent platform gate **28
  passed, zero skips, 0.34s**; worker storage gate **22 passed, ten Linux skips**.
  Parent review removed duplicated applet setup and scoped the legacy diagnostic
  assertion to required pinned BusyBox mode, avoiding assumptions about unrelated
  host versions. New-case recheck: **one explicit platform skip, 31 deselected**;
  all static gates passed. Native regression and all guests still need exact CI.
  No full local suite. Existing version-config test covers the added prerequisite;
  kernel configuration assertions and every guest proof marker remain mandatory.
  Successful prior native job independently verified **59 passed, zero skips,
  0.79s**; the next run must also prove the newly added regression.
- [Run 38186542110](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38186542110),
  exact `9ab6f62b2c545b969b168604f0f4d1eb8810dbc9`: attempt 1 cancelled for the
  pause; resumed **attempt 2 failed**. Host/static and planning passed. Native
  vendor BusyBox compiled and ran 52 tests, but two native-fsync setup cases errored
  because the minimal config omitted BUSYBOX's --list applet. All four generic
  kernel jobs were blocked by GCC 4.9.4's missing host libmpfr.so.4 dependency
  (on 4.19 this also produces secondary Kconfig errors). No kernel boot proof yet.
  Parent enabled the source-declared BUSYBOX option; the private pinned compiler
  runtime and actual compilation preflight are implemented and locally reviewed.
  The user reiterated Ruff and ShellCheck: the focused/full runner retains Ruff
  check/format, compileall, ShellCheck, shfmt and shell syntax; developer notes now
  name Ruff explicitly. No required check is bypassed.
- Current repair on dirty `ae594bf`: parent ran
  `.venv/bin/python tools/test.py --focused tests/test_platforms.py` — **28 passed,
  zero skips, 0.27s**; planning/links/privacy, whitespace, Ruff check/format,
  compileall, Homebrew POSIX syntax, ShellCheck and shfmt passed. Review covered
  actual consumer/failure paths, private library hash/ABI/link/cache validation,
  child-scoped compiler environment, compile/header/assembler preflight, native
  mode isolation, unchanged kernel/compiler source pins and all four workflow
  jobs. Added tests reuse immutable fixtures and complete serially in under one
  second; no full local suite or router work. Actual compiler/kernel execution
  remains CI-only proof.
- [Run 38186228388](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38186228388),
  exact `c8e93c42aaef8216c6cabee2a3c175e74b7552d0`: planning and host/static passed;
  required native BusyBox and all four ARM jobs failed building vendor rm because
  standalone builds lack firmware-generated `rtconfig.h`. The selected generic
  fixture must provide explicit board-neutral configuration without modifying
  applet logic or claiming exact firmware equivalence. Local/remote develop were
  verified equal after push. No new runtime package before full CI passes.
- [Run 38185361432](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38185361432),
  exact `6b91cd82aad8feddcbde7e1d81a8f4e0c35174d8`: planning passed; six jobs failed
  before behavioral proof. Corrected source-declared BusyBox option names and
  compatibility with CI's older ShellCheck. Probe annotations cover its proven
  BusyBox `-ef` extension and EXIT callback only; no runtime guard was removed.
- [Run 38185610840](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38185610840),
  exact `56b8b5a1583e35401065626da8c1a08ca31a0dac`: planning and full host/static job
  passed; required BusyBox and four ARM jobs failed. Ubuntu's regular **and static**
  BusyBox omit fsync (confirmed official package source), and allnoconfig's retained
  shell-NONE choice conflicted with ASH. The choice correction explicitly disables
  NONE and preserves post-Kconfig assertions. Native vendor build is implemented
  with separate compiler/cache/ELF identity; actual compilation remains CI pending.
- Parent combined platform repair check at dirty `56b8b5a`:
  `.venv/bin/python tools/test.py --focused tests/test_platforms.py` — **22 passed,
  zero skips, 0.15s**, plus planning, whitespace, Ruff/format/compile, Homebrew bash
  POSIX syntax, ShellCheck and shfmt. Parent reviewed native/ARM cache separation,
  receipt and ELF checks, source-config guards, version-specific kernel symbols,
  workflow and matching developer notes. Native compilation/guest execution still
  require the next exact-SHA CI run; no full local suite was run.
- Generic-header repair at dirty `c8e93c42`: parent reran the same focused command,
  **23 passed, zero skips, 0.18s**, and all static/planning checks passed. Header staging
  leaves vendor sources unchanged and changing it invalidates both BusyBox targets
  without invalidating kernels. Explicit HND make flags keep generic fixtures free
  of board macros/shared firmware includes. Actual compilation remains CI pending.
  Read-only source audit receipts for all three pins are retained in
  `.tmp/platform-review/busybox-build-support-audit/{provenance,assumptions}.json`;
  source inspection is not compiler/runtime proof.
- Parent storage focused check at dirty `3e164914`: **22 passed, nine Linux skips,
  0.77s**. Those skips were not passes. The later Linux full host job is green,
  but the required BusyBox/platform gate remains failed. No full local suite for
  these corrections. Tests share a compiled fixture and run serially.
- Parent staged all 36 actual hash-verified IPKs with the new extractor, checked
  required ELF class/machine for both feeds, and independently read the generated
  initramfs using host libarchive (175 entries). No maintainer scripts/binaries
  executed. Private `.tmp/platform-review/feed-stage-briuimcw/feeds.cpio.gz`.
- Current host .venv: Python 3.14.0, pytest 9.1.1, Ruff 0.16.10, shfmt 3.7.0.1;
  Homebrew bash 5.3.3 and ShellCheck. No host dependencies installed this session.
  CI installs its declared tools. Developer docs contain tooling/check commands.

Both 4.1 kernels built/booted and passed the native storage happy path; the guest
diagnostic assertion stopped further proof. Neither 4.19 kernel has booted yet.
Complete generic-kernel execution and both ARM Entware command sets are required before
this fixture package is green. Generic guests do not prove exact Merlin firmware,
NAND/JFFS2 hidden-failure behavior, all TLS/options or complete model qualification.
S02.09 remains unfinished even after these selected guests pass.

## Source and platform findings

Read-only original reference remains located through `.tmp/reference-paths.md`.
Parent reviewed original lifecycle dispatch, independent Access queue/writer and
DDNS-to-Access handoff. Replace Python updater metadata/DNS record parsing and the
whole Access helper while preserving four-attempt newest-request/writer exclusion,
lifecycle readiness/stop/recovery and independent DDNS completion. Original weaker
parsing/schedules do not supersede v2.

`tests/fixtures/platforms.json` owns public pins: upstream ARM64 kernels 4.1.51,
4.1.52, 4.19.183 and 4.19.294; three distinct vendor BusyBox 1.25.1 source commits;
GCC 4.9.4 kernel compiler; both aarch64-k3.10 and armv7sf-k3.2 Entware closures.
The compiler needs legacy host MPFR4. Official Debian Stretch metadata and actual
package bytes independently verify `libmpfr4` 3.1.5-1 amd64; both package and library
hashes are pinned in the manifest. Only data is extracted into a private cache;
no install/maintainer script is run. Its library path is passed only to compiler
and kernel-make children. CI declares libmpc3/libgmp10; their identities affect
kernel cache keys. This is build-host support, not a router dependency.
All 18 selected IPKs per feed were hash-verified (about 11.3 MB compressed total).
Coreutils payloads use `/opt/libexec/*-coreutils`, flock uses
`/opt/bin/util-linux-flock`; CI must call real payloads without package scripts.
Baseline native opkg metadata confirms aarch64-k3.10, jq 1.8.1-2, coreutils 9.9-2,
bind-dig 9.20.18-2 and libc 2.27-12. A 64-bit kernel can have 32-bit Entware, so ABI
cannot be inferred from uname alone. Official Merlin/Entware docs were consulted.

Exact baseline source `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f`,
`src-rt-5.02axhnd/kernel/linux-4.1/fs/jffs2/file.c`, discards the buffered flush return;
all four selected source versions do so. Filesystem sync also discards it. Baseline
config enables WRITEBUFFER, disables WBUF_VERIFY; native sysfs reports NAND with
2048-byte writes/131072-byte erase blocks. This is source/config evidence, not an
observed live flash fault or exact executable equivalence. Pins/bytes retained at
`.tmp/storage-review/jffs2-source-provenance.json` and
`.tmp/platform-review/source-index.json`.

O_SYNC/O_DSYNC use the same fsync; no direct_IO alternative; page-cache rereads can
still consult the JFFS2 buffer. A later successful padding write can follow loss
of an earlier node during failed buffer recovery. Kernel logs lack a reliable
per-transaction result and some failure paths have no matching diagnostic. Raw
sequential dumps lack a coherent live namespace; existing jffs2reader omits CRC
checks. Immutable positive witnesses are not ruled out theoretically, but need a
custom CRC/compression/inode/ancestor verifier plus a new recovery proof. No simple
supported workaround was established; do not resume unbounded research contrary
to the user's practical-complexity preference.

## Router receipts

Baseline: GT-AX11000 388.12_2, kernel 4.1.51, BusyBox 1.25.1, native `/bin/fsync`,
`/usr/bin/flock`, `/usr/bin/env`; native id/stat absent. JFFS is JFFS2. MERLIN is
`/tmp/mnt/MERLIN`, `/dev/sdb1`, ext4 rw; `/mnt` aliases `tmp/mnt`.

Consumed JFFS attempt at `3e164914` exited 2 before mutation; scratch
`/jffs/addons/.cfmgr-storage-probe-17489` absent. Invocation/output:
`.tmp/storage-review/router-probe-20261012.sh` and `.log`; stream SHA256
`2476176c378e11d300be4925b6ccef2c32c533bdc04d0621920a106a71fa939a`.

Corrected authorized USB probe exited 0: file/directory flush, rename/readback and
verified cleanup. Scratch 22723 removed; independent read-only SSH confirmed
`/mnt/MERLIN/tmp` retained mode 700 and empty including hidden files, with no JFFS
probe-prefixed paths. Invocation/output:
`.tmp/storage-review/router-usb-probe-20261012.sh` and `.log`; stream SHA256
`9f7ab9b495a99f4df17809c0c21a7b049dfd93a9bae332d638298a6a93c70f08`.
One native ext4 happy path proves neither JFFS durability nor full Save. No service,
setting, package or Cloudflare data was changed.

## Next actions

1. Resume inspection and CI repair are authorized. Preserve the hidden
   session block; append only a verified actual new parent session ID.
2. Commit/push the reviewed guest/configuration correction and monitor its full
   Checks run, all seven exact-SHA jobs. Fix actual
   build/boot/command failures within this checkpoint, focused-test, commit/push
   and wait again. No new runtime package before full required CI passes; no full
   local suite solely for this earlier platform checkpoint.
3. After that gate, continue goal 2's real install/storage/dependency consumer and
   Save integration under the documented firmware limit. Preserve incomplete work;
   no helper-based ticks. At the completed main-goal gate follow the full local/CI,
   README push, complete handoff and pause sequence in AGENTS.md. Goal 1 remains
   the original objective, reached through its necessary prerequisites.

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
