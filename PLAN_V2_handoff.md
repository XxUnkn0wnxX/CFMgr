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

**Resumed by the user.** Full CI exposed further fixture prerequisites; the combined
compiler/locking/entropy/native-test repair is reviewed and ready to push. No new runtime
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
`e01b8ee0514fc5bc5df908efebafb56cddb1e752`.
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
| kernel_compiler | Returned; no active ownership | Parent reviewed compiler selection/cache/preflight/workflow and QEMU RNG integration; actual CI pending. |
| guest_diagnostic | Returned; no active ownership | Parent-reviewed guest prefix correction and native regression; reused existing applet fixture, pinned mode only. |
| Parent | tests/test_storage.py, tests/fixtures/platform/kernel.config; integration/plans | Owned FIFO native error fixture; FILE_LOCKING and virtio RNG guest prerequisites. Worker owns matching QEMU arguments. Preserve all proof. |
| ci_resume_wait | Completed | Run 38187960627 at e01b8ee terminal failure confirmed. |
| platform_audit | Returned; no active ownership | Source review found guest entropy prerequisite; parent reviewed BIND constructor/RAND check and exact virtio driver quality. No other concrete blocker found. |
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

The runtime checkpoint remains **failed**, so only its repairs may advance.
Latest published runtime: `e01b8ee0514fc5bc5df908efebafb56cddb1e752`, verified
against origin/develop. No product subgoal is accepted.

- [Checks 38187960627](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38187960627)
  at that exact SHA finished with host/static and planning success; native BusyBox
  and four kernel jobs failed. Parent read all five failed-job logs.
- Native suite: **59 passed, one new-case failure**, 0.85s. The new error fixture
  used root-owned /dev/null under the non-root runner; vendor fsync's O_NOATIME
  requires inode ownership/capability. Parent now uses a private owned FIFO with
  a held writer, separately asserting the real zero-status diagnostic and silent
  wrapper rejection. The root guest keeps its valid /dev/null test.
- Both 4.1 kernels built and booted; native storage probe/cleanup and zero-status
  diagnostic rejection passed, followed by actual Entware jq, timeout and SHA.
  flock returned ENOSYS because the minimal fixture omitted FILE_LOCKING. Parent
  enabled that exact source-declared prerequisite; real locking proof stays required.
- Both 4.19 kernels passed configuration, then their ARM64 compiler header rejected
  GCC 4.9.4 (minimum 5.1). Worker is qualifying a separately pinned official GCC
  8.5 compiler; retain the working 4.1 compiler, every kernel pin and source checks.
- Earlier [Checks 38187447546](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38187447546)
  at `a7e3955f35319b50bb0d9ed3ecfd3f09ec005002` passed planning, host/static and native
  BusyBox (**59 passed, zero skips, 0.79s**). It exposed the now-fixed guest fsync
  prefix and 4.19 VIRTIO_MENU prerequisite. This older success does not cover the
  new native regression. Prior compiler MPFR4 and BUSYBOX applet repairs are proven
  by the later actual builds; old failed/cancelled runs award no acceptance.

Local evidence, limited to the named dirty tree and inputs:

- Combined compiler-runtime repair on dirty `ae594bf`: parent
  `.venv/bin/python tools/test.py --focused tests/test_platforms.py` — **28 passed,
  zero skips, 0.27s**; all planning/static checks passed. Worker also validated
  actual Debian package data extraction/cache hashes without executing its code.
- Guest/config correction on dirty `a7e3955`: parent platform command **28 passed,
  zero skips, 0.34s**; worker storage command **22 passed, ten Linux skips**. Parent
  removed duplicated applet setup and restricted the legacy-error assertion to
  required pinned BusyBox mode. No test assumes an unrelated host version has it.
- Current owned-FIFO correction on dirty `e01b8ee`:
  `.venv/bin/python tools/test.py --focused tests/test_storage.py -k linux_busybox_zero_exit`
  — **one explicit platform skip, 31 deselected**; no native execution claimed.
  Current FILE_LOCKING selection check:
  `.venv/bin/python tools/test.py --focused tests/test_platforms.py -k kernel_configuration`
  — **one passed, 27 deselected**, 0.12s. Both invocations passed Ruff check/format,
  compileall, host POSIX syntax, ShellCheck, shfmt, planning/links/privacy and
  whitespace checks. Actual changed behavior must pass the next full CI gate.
- No full local suite for this earlier platform checkpoint. Tests reuse immutable
  setup and run serially; platform tests complete under one second. CI keeps two
  kernel jobs at most, make -j2, one CPU/256 MB per guest and verified build caches.
  No extra full suite was run to measure cost. Current host tools: .venv Python
  3.14.0, pytest 9.1.1, Ruff 0.16.10, shfmt 3.7.0.1, Homebrew bash 5.3.3/ShellCheck.
- Combined final repair on dirty `e01b8ee`: worker and parent ran the platform
  focused command, **31 passed, zero skips**, with all static gates passing.
  Parent reviewed every changed consumer, tests, manifest, workflow and both
  returned packages; independently matched the downloaded GCC 8.5 archive hash.
  New coverage reuses existing fixtures; each family gets its own prebuilt
  compiler/preflight/environment checks, no GCC source build or new framework.
  Kernel and BusyBox actual execution, FIFO regression and guest RNG remain
  pending the next exact full CI run.

Raw job logs remain ignored at `.tmp/platform-review/ci-<run>-<job>.log`.
Bounded independent fixture review found an additional unexecuted risk: BIND's
[libisc constructor](https://github.com/isc-projects/bind9/blob/v9.20.18/lib/isc/lib.c)
initializes TLS/RAND before dig main. Add the guest HW_RANDOM/VIRTIO driver and an
explicit QEMU virtio-rng device backed by host /dev/urandom. Exact drivers for all
four kernels set quality 1000, so their RNG cores credit entropy without rngd or
extra boot arguments. Parent reviewed the relevant sources. This prevents a
plausible startup entropy wait; actual dig proof remains required, never replaced
by source inspection. Exact Entware OpenSSL build configuration was inferred
from its recipe, not independently reproduced.
Complete guests must prove both ARM Entware command sets and every exact success
marker. Generic kernels are not exact Merlin firmware or live NAND/JFFS2 proof;
TLS/native option checks and full model qualification remain unfinished. S02.09
cannot be ticked merely because these selected guests pass.

## Source and platform findings

Read-only original reference remains located through `.tmp/reference-paths.md`.
Parent reviewed original lifecycle dispatch, independent Access queue/writer and
DDNS-to-Access handoff. Replace Python updater metadata/DNS record parsing and the
whole Access helper while preserving four-attempt newest-request/writer exclusion,
lifecycle readiness/stop/recovery and independent DDNS completion. Original weaker
parsing/schedules do not supersede v2.

`tests/fixtures/platforms.json` owns public pins: upstream ARM64 kernels 4.1.51,
4.1.52, 4.19.183 and 4.19.294; three distinct vendor BusyBox 1.25.1 source commits;
GCC 4.9.4 for 4.1 and GCC 8.5.0 for 4.19; both aarch64-k3.10 and armv7sf-k3.2
Entware closures. Both compilers are prebuilt downloads. Official kernel.org GCC
8.5 archive SHA256 `a676b32874ee649f5d39bed5a31c9d88b29d70833b99d6d00879b086420909c6`
matches its published digest (signature not checked). Data-only ELF inspection
found only glibc host dependencies, no MPFR4/MPC/GMP dependency. It uses exact
-dumpfullversion and clears child LD_LIBRARY_PATH. Evidence is retained at
`.tmp/platform-review/gcc-8.5.0-elf-dependencies.txt`; no compiler executed locally.
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
2. Commit/push the reviewed combined fixture correction and monitor its full
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
