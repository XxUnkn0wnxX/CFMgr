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

**Resumed by the user.** The compiler/locking/entropy/native-test repair passed
all seven exact-SHA CI jobs. Current work is the user's requested persistent CI
tool/dependency caching improvement, pushed at `d71c813a73da5e0b07a1f0c1af2292aeb17e1111`.
Checks 38190294055 passed all seven jobs at that exact SHA. Warm native and
4.19.294 job reruns also passed. Requested CI caching and AGENTS trimming are
complete. Bounded source review found no simple proven correction for the remaining
4.1 guest entropy delay; retain the passing fixtures. No worker or CI job is active.
Resume inspection found a
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

Latest CI request: persist reusable installed developer tools/dependency downloads
so pushes do not rebuild the environment unnecessarily. Kernel/BusyBox build
caches already exist. Improve dependency/tool
caching, preserve validated setup across later test failures, keep mutable guest
and test state fresh, and verify actual cache hits. GitHub-hosted runners still
start fresh; no GCC source build or whole-machine snapshot is requested.
Parent read the user's latest ChatGPT conversation, “GitHub Environments Explained”,
through the connected conversation tool. It recommends saving verified inputs
before later failures, sharing identical downloads/compiler bundles and evaluating
a prebuilt container afterward. This informs the authorized caching task; it does
not change product requirements or authorize a new deployment/registry publication.
The user also requested ongoing CI optimization in AGENTS.md. Parent added the
standing cache/setup rule: share verified immutable inputs, invalidate only affected
compatibility/pins/parameters, save before later failures and prove warm reuse while
retaining all required tests and fresh mutable state. The final S16.03 developer-guide
coverage now mirrors those workflow/cache basics in the plan and checklist; the
interim developer notes remain minimal. This user-requested documentation
amendment adds no product goal or acceptance tick.

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
`d71c813a73da5e0b07a1f0c1af2292aeb17e1111`.
The separate developer-docs receipt is `ae594bf`; it is not runtime CI evidence.
Inspect current refs and full CI status on resume.
Earlier partial checkpoints remain in ancestry: native helper `3e164914`, probe
correction `6b411736`, platform fixtures `6b91cd8`, policy amendment `b73b9bb`.
No main branch was recreated. The pushed repair changes the platform runner/tests,
manifest, BusyBox config and workflow, plus the approved progress rule and this
handoff. Parent reviewed all returned changes and reran their focused/static gate;
actual kernel execution passed the full CI run below.

| Owner | Exclusive scope | Current state |
| --- | --- | --- |
| Parent | Planning files, AGENTS.md, docs, integration and final review | Own all accepted requirements and CI gate; inspect every returned change. |
| kernel_compiler | Returned; no active ownership | Parent reviewed shared compiler/feed/source caches, preparation failure boundaries, actual runner consumers and workflow integration. Existing build/key helpers are unchanged. |
| guest_diagnostic | Returned; no active ownership | Parent-reviewed guest prefix correction and native regression; reused existing applet fixture, pinned mode only. |
| ci_tools | Returned; no active ownership | Parent reviewed APT archive and exact installed-venv caches, compatibility identities and healthy setup saves. Embedded Bash/Python static checks passed. |
| Parent | Integration/planning, developer command notes and final checks | Review both cache packages, focused checks, exact full CI and representative warm-cache reuse. |
| platform_audit | Returned; no active ownership | AGENTS semantic review integrated. Bounded source review supports legacy entropy-transfer stall; no simple proven fixture correction, no edits/execution. |
| ci_resume_wait | Returned; no active ownership | Exact full run plus warm native and 4.19.294 reruns passed; parent verified job identities, timestamps and actual cache-hit logs. |
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

The current cache checkpoint **passed**: [Checks 38190294055](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38190294055)
at exact published `d71c813a73da5e0b07a1f0c1af2292aeb17e1111`, verified against
origin/develop. All seven required jobs passed; parent verified full head and job
outcomes. Attempt 2 reran only native BusyBox (67 passed, zero skips); attempt 3
reran only kernel 4.19.294 with both feed success markers. GitHub carries forward
other jobs under new IDs; their old timestamps/logs are not additional executions.
The prior repair at `3ab84c5ab10dc4ed43d3eb7621a58af5b2fb46c8`,
[Checks 38188741049](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38188741049),
passed all seven required jobs at that exact full SHA. Parent independently read
all four guest logs: exact kernel/vendor identity, native storage flush/rename/
readback/cleanup, diagnostic rejection and both Entware ABI success markers passed.
Native BusyBox suite: **63 passed, zero skips, 0.90s**, including the owned-FIFO
zero-exit diagnostic regression. Planning and host/static jobs also passed.
Generic guests do not establish full S02.09/model/TLS or live flash acceptance.
No product subgoal is accepted.

Current cache package integration contract: workflow uses local
`.github/actions/setup-tools` with `apt-packages` (space-separated validated package
names) and optional `python-tools: 'true'`. Host/native jobs request ShellCheck and
Python tooling; kernel jobs pass their existing package set plus selected compiler
host requirements. Installed venv cache identity includes interpreter/platform,
requirements and workspace location. Cache only APT archive downloads, never an
installed system snapshot. Platform input preparation must verify pinned bytes
and compiler preflight before saving shared immutable inputs. Mutable guest disks,
work directories, test state and secrets are never cached. Preserve current build
cache identities unless an actual build input changes. Focused offline behavioral
tests/static checks precede the authorized CI push; full exact CI and observed
warm restores are required before claiming caching works.

The combined caching candidate on dirty `3ab84c5` passed the parent focused runner:
**35 passed, zero skips, 0.47s** (final pre-commit repeat), with Ruff check/format, compileall, POSIX syntax,
ShellCheck, shfmt, planning/link/privacy and whitespace gates. Parent also parsed
workflow/action YAML, checked every embedded Bash block (including composite
shfmt with two-space indentation), and checked embedded Python syntax/Ruff.
Every pre-existing platform function except `execute`/`main` is source-identical
to HEAD, preserving existing build/cache identities. Four small offline regressions
cover scoped key invalidation, verified-completeness receipts and rejected CLI
combinations. No full local run, native build, router work or test matrix reduction.
Actual Linux/GitHub proof is now accepted for this bounded cache package:

- Warm native job 114622481706 restored the exact installed Python environment and
  existing BusyBox, skipped pip installation, and passed 67 tests with zero skips.
  Its setup was 8s versus 19s on the initial cache-fill job; total 15s versus 27s.
- Warm 4.19.294 job 114622842510 restored APT archives, GCC 8.5 compiler bundle,
  shared Entware inputs, BusyBox and kernel image; APT reported **0 B/57.5 MB** to
  fetch. Both guest ABIs passed. Total job 34s. Legacy GCC bundle reuse was already
  observed by the second 4.1 job on attempt 1.
- All kernel/BusyBox build identities remained unchanged. Warm image hits skip
  unnecessary kernel source restoration/preparation but still execute fresh guests.
  The source-cache miss branch has focused CLI/download proof; it was not exercised
  remotely because all compiled images restored successfully.
- Job wall times include runner/network variation, and aggregate CPU is unmeasured.
  Do not attribute the earlier cold-kernel build savings solely to the new caches.
  Kernel 4.1 guests still spend about 103s executing after warm restoration, versus
  about 1s for 4.19. Source review found a likely legacy entropy-transfer stall:
  hardware bytes credit input_pool, its producer stops above 896 bits, while
  alternating background output transfers credit 64 bits and nonblocking init
  requires more than 128. 4.19 instead directly credits CRNG initialization.
  Guest logs support that diagnosis but replayed output cannot time the precise
  syscall. No simple proven config/boot-argument correction was established;
  retain the passing fixtures, with no sleeps, relaxed checks or extra CPU.
  A future bounded exact-byte random consumer would need its own source/execution
  proof; do not implement a guessed read count or resume unbounded optimization.
- Receipts/logs: `.tmp/platform-review/cache-first-ci.json`, `cache-warm-ci.json`,
  `cache-warm-kernel-ci.json` and `ci-38190294055-*.log`. Full code proof remains
  `d71c813`; later documentation commits do not acquire that tested SHA's identity.

The user requested AGENTS.md trimming. Parent reduced 33,235 bytes to 21,673 bytes;
read-only semantic review checked against `.tmp/agents-before-trim.md`, and parent
restored explicit checklist/README table structure and combined-package checkpoint
clauses. Approval, publication, progress, preservation and router boundaries remain.
The final developer guide's CI optimization coverage is mirrored in S16.03; the
current 53-line developer notes remain unchanged.

Local evidence for the accepted repair:

- Worker and parent ran `.venv/bin/python tools/test.py --focused tests/test_platforms.py`
  on dirty `e01b8ee`: **31 passed, zero skips** (parent 0.31s). Ruff check/format,
  compileall, host POSIX syntax, ShellCheck, shfmt, planning/links/privacy and
  whitespace checks passed. Parent reviewed both returned packages and independently
  matched the prebuilt GCC 8.5 archive hash.
- The owned-FIFO native regression explicitly skipped locally because pinned Linux
  BusyBox was unavailable; the required CI above supplied its actual proof. It
  asserts the vendor fsync zero-exit diagnostic and silent wrapper rejection.
- Earlier CI failures established missing FILE_LOCKING and 4.19 VIRTIO_MENU, the
  4.19 compiler minimum, the native inode-ownership fixture condition and legacy
  MPFR4 runtime requirement. Current source-selected fixes passed actual guests.
  Raw job logs remain ignored at `.tmp/platform-review/ci-<run>-<job>.log`.
- BIND initializes TLS/RAND before `dig` main. The exact four virtio RNG drivers
  advertise quality 1000; the minimal kernel enables HW_RANDOM/VIRTIO and QEMU
  supplies host random bytes. Actual `dig -v` now passes for both feed ABIs on
  every guest. No extra boot argument, rngd or fallback bypass was needed.
- No full local suite was run for this earlier platform checkpoint. Existing
  focused tests run serially below one second. CI retains at most two kernel
  jobs, make -j2 and one CPU/256 MB per guest. Current host tools: .venv Python
  3.14.0, pytest 9.1.1, Ruff 0.16.10, shfmt 3.7.0.1, Homebrew bash 5.3.3/ShellCheck.
  Required full CI supplies comparable job wall times; aggregate CPU is not measured.

These generic kernels are not exact Merlin firmware or live NAND/JFFS2 proof.
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
Legacy GCC 4.9.4 needs host MPFR4. Official Debian Stretch metadata and actual
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
2. CI caching and its exact full/warm gates are complete. The remaining legacy
   guest timing limit is recorded; do not rerun suites to regenerate receipts or
   broaden optimization without a concrete justified correction.
3. Continue goal 2's real install/storage/dependency consumer and
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
