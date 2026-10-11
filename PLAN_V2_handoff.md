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

## Current task and authorization

**Current focus: goal 2, as a prerequisite of the requested goal 1.** The user
explicitly authorizes switching to a necessary prerequisite main goal after
notifying them first. Parent notified this switch: install/storage/dependencies
must support independent feature setup. Return to goal 1's combined workflows
after that foundation, announcing any further necessary focus switch first.
The prior next-session implementation boundary is superseded. Goal 1 means all three
independent features and original-source parity; helpers/menu scaffolds do not
complete it. Product status remains **0/16 main goals = 0%**, with no completed
subgoal. Shared dependencies earn only their actual verified scope.

Local implementation, focused tests, appropriate CI wiring and reviewed local
checkpoints are authorized. The user now conditionally authorizes earlier CI
pushes when most meaningful focused subgoal proof requires unavailable
BusyBox/Linux/platform execution: explain the dependency, run full exact-commit
CI and close only actually proved scope. A minority of platform cases does not
qualify. The platform package is eligible under that conditional grant: most
substantive S02.09 compatibility proof requires ARM kernel/BusyBox/Entware
execution unavailable on this macOS host. Its first full CI push is being prepared;
no push has occurred yet. This does not complete S02.09 or authorize deployment.
No current permission covers live installation/deployment, provider mutation or
another history/reset operation.
The user permits extracted Merlin firmware material or public source as CI test
fixtures and leaves workflow organization to the parent. This package uses public
source with one Checks workflow and a four-profile matrix capped at two concurrent
jobs. It does not authorize execution/deployment of firmware on the live router.
The prior cleanup/publication/main-deletion grants are completed one-time actions.
Significant product/scope changes still require the user's concrete decision.

The user explicitly permits brief read-only `ssh router` inspection, using either
single commands or a background interactive terminal. Router login defaults to
zsh: explicitly invoke **router-side `/bin/sh`** for BusyBox/POSIX commands and
any separately authorized tests. Workstation sessions remain Homebrew zsh; local
shell fixtures use resolved Homebrew bash, not macOS `/bin/sh`. Router writes and
test execution require explicit permission. Close SSH when its work finishes.
These amendments are recorded in AGENTS.md. The user authorized one JFFS probe,
conditional on leaving no artifacts. That attempt is consumed: it stopped before
any mutation because native `id` is absent, returned 2, and its exact scratch path
was confirmed absent. A separate read-only check found no probe-prefixed paths.
The user subsequently allowed bounded command tests and temporary writes only
beneath `/mnt/MERLIN/tmp`, with cleanup. Their latest amendment explicitly says
keep the `tmp` directory itself, allow removal of its contents as needed, and
confine all test writes there. Create the base if absent; never remove it or alter
pre-existing permissions. Prefer owned scratch cleanup over unnecessary removal.
This does not authorize another JFFS attempt, installs, service changes or stress.

## Verified starting state

- Reviewed local checkpoints: `3e164914ef23d6d021a9f8c03cf629903a44b75c`
  (initial native storage/runtime checks) and
  `6b411736c989d822e9ccad34eae111bd45bb64b8` (native probe correction, retained USB
  scratch base and user compatibility amendment). Develop is two commits ahead
  of last verified origin/develop; no push has occurred. Current handoff notes
  track the next platform-fixture package and are documentation working state.
- Local and remote develop both started at
  `6dc6dbd5571beee037cf97949a449beff9dcd74d`, clean. Read-only remote inspection
  confirmed develop is advertised HEAD and remote main is absent.
- [Checks run 38180965914](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38180965914)
  passed at `13ffcfc94a88c7f2dd70be382ced5a18fe60f3ff`, verified again this session.
  It had one planning job and proves no runtime/platform behavior. The later
  starting commit is a documentation receipt, not a tested runtime revision.
- The starting tree had only planning/tooling and folder placeholders, no runtime,
  installer, package catalog or runtime tests. Replacing the empty-runtime ban
  must land together with real tests, runner, pinned tools, CI and developer notes.
- Reused local `.venv`: Python 3.14.0, pytest 9.1.1, ruff 0.16.10,
  shfmt_py 3.7.0.1. Homebrew bash is 5.3.3; native host ShellCheck is available.
  No dependencies installed in this session. Host proof is separate from Linux.

## Source audit and first dependency

Parent read all v2 documents and reviewed the focused source-parity and native
persistence reports. Original reference location remains private in ignored
.tmp/reference-paths.md. Parent traced original lifecycle dispatch, independent
Access queue/writer behavior and the DDNS-to-Access handoff. The Python paths to
replace are updater release metadata, DNS record parsing and the complete Access
helper. Keep four-attempt newest-request/writer exclusion semantics, lifecycle
readiness/stop/recovery and independent DDNS completion. The original's weaker
API parsing and old schedules do not override the stronger v2 contracts.

The first package now serves goal 2's **S02.07–S02.09**, using the native persistence
prerequisite of **S04.03**, and ultimately **S01.01–S01.03**. Its eventual consumer is reviewed feature
Save/draft/config publication. Its current concrete consumer is an explicitly
invoked storage-capability probe; this is **not** a Save implementation, production
feature or subgoal acceptance. Complete storage admission, transaction/recovery
and actual feature consumers must follow before any corresponding tick.

Pinned Merlin BusyBox source at `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f`
and `69838e4a60564e5550e97f11d8a8cf2c6260c4f0` confirms native fsync prints
syscall errors but can return zero. Plain sync and dd count=0 do not supply the
required failure reporting. The selected candidate uses one admitted read-only
fd, a fixed short `/proc/self/fd/3` operand, C locale and command-substitution
capture with an exact completion sentinel. It requires both zero exit status and
sentinel-only output. No diagnostic-file writes, new dependency or claim that
readback alone proves durability. Native error-transport/resource limits remain
part of the review; no hard deadline or power-loss guarantee is inferred.

Official Merlin Addons API/User scripts/Custom config files were consulted.
Brief read-only router inspection found GT-AX11000 388.12_2, kernel 4.1.51,
BusyBox 1.25.1, `/bin/fsync`, `/proc/self/fd`, native `/usr/bin/flock` and
`/usr/bin/env`; `/jffs` is mounted JFFS2 rw,noatime. Inspection used help and
existing metadata only, never flush/test/write/install. JFFS file and directory flush
behavior remains **unverified**; the subsequent USB result is recorded below. The first approved probe exposed
an admission bug: native `id` and `stat` are absent (confirmed by live native PATH,
BusyBox applet inventory and both cached release configs). Host tooling had masked
these assumptions. Correct the probe using verified native facilities without
weakening cleanup identity; this is no evidence of a JFFS flush failure.

Further pinned kernel-source review found a separate S04.03 limitation. In the
same release's `src-rt-5.02axhnd.675x/kernel/linux-4.1/fs/jffs2/`, `file.c:32-48`
discards `jffs2_flush_wbuf_gc`'s integer failure result and returns zero after a
successful page-cache wait; `super.c:99-111` likewise discards the buffered-flush
result in sync_fs. `wbuf.c:702-761` can return a flush error. Cached actual kernel
config enables WRITEBUFFER and disables WBUF_VERIFY; read-only mtd9 sysfs reports
NAND, 2048-byte writes and 131072-byte erase blocks. This is source/config evidence,
not an induced live fault or exact executable equivalence claim. Native syscall
success/readback cannot establish detection of kernel-hidden flash errors; no
wrapper/extra Entware fsync tool fixes that missing return. Parent notified the
user immediately. Keep durable Save acceptance pending; no specification change
or reduced guarantee is approved. Pinned source bytes/hashes are retained under
`.tmp/storage-review/jffs2-source-provenance.json` for bounded review.

**User decision: keep Save acceptance pending and investigate alternatives.**
After the parent explained the discarded error result, the user explicitly chose
not to adopt the proposed weaker firmware-limit guarantee. S04.03 remains
unchanged. Do not re-ask this same question without new evidence or silently
accept exposed-errors-only coverage. Investigate a supported reliable reporting
or persistence-verification route, preserving the required GT-AX11000 baseline.
The user additionally approves safeguards/rechecks as workarounds only if they do
not cause false positives; this is mirrored in S04.03's detailed contract and V63.
It does not approve cached-readback-only acceptance. Latest steering asks for
a practical workaround with little complexity or extra user effort; otherwise
the user is willing to consider accepting the limitation. Complete the bounded
review and explain the result before changing Save acceptance or its guarantee.

Alternative-path review returned and parent checked the decisive source paths:
O_SYNC/O_DSYNC route through the same fsync; no direct_IO callback exists; ioctl
returns ENOTTY; page-cache reread can still use JFFS2's write buffer. A checked
padding write can force buffer rollover, but `jffs2_wbuf_recover` may drop earlier
data after a recovery read/allocation failure and then allow the new node's retry
to succeed. Thus a successful write barrier does not certify earlier transaction
data. Baseline `wbuf.c:318-348` and `write.c:363-371` establish this counterexample;
latest source has the same path. No reliable alternative is established yet.
Direct raw-flash verification would need a coherent namespace/data reconstruction
under GC; current Entware indexes have nand/ubi tools but no selected JFFS2 reader.
This remains investigation, not an approved runtime design or live experiment.
The user's latest amendment qualifies that range by Entware support and required
package availability/usability on the model's firmware/kernel/userspace ABI. Keep
GT-AX11000 as the required baseline and modern Merlin routers; exclude profiles
whose dependencies are unavailable/incompatible, with concrete reasons. There is
no obligation to support obsolete hardware for its own sake. This is mirrored in
S02.09/V02 and does not approve weakening S04.03. Temporary Entware loss still
requires native recovery. The durability guarantee remains unchanged and pending.
Parent has now verified the same discarded flush return in the exact baseline
4.1.51 tree and all three newer selected source versions, retained in ignored
`.tmp/platform-review/source-index.json`. Official Merlin Addons API/User scripts
and a bounded SNBForums search provided no verified alternate error-reporting
interface. The explicit user decision above supersedes that pending question;
source/CI-layout instructions do not alter it. No approval question is open now.

## Current ownership and contracts

| Owner | Exclusive files/scope | State |
| --- | --- | --- |
| Parent | Planning files, docs, runtime/test integration and CI checkpoint | All implementation files returned. Final platform review and focused checks passed; preparing eligible early CI. |
| persistence_review | Read-only positive raw-flash transaction-witness review; no writable files | Prior flush/raw-dump limitations returned. Final bounded review checks unique immutable records, positive evidence and practical existing-tool options. No router work, builds or acceptance. |
| probe_compat, storage_flush, runtime_checks, source_parity | No active ownership | Packages/research returned and reviewed; no active writers or router sessions. |

Shared interface: `cfmgr_storage_flush_fd ABSOLUTE_FSYNC_EXECUTABLE`; caller owns
admitted target/storage and opens read-only fd 3. Library sourcing performs no
work. The candidate function invokes one explicitly admitted utility and returns
failure without leaking diagnostics. It does not admit arbitrary storage, supply
process supervision, install/configure features or implement a complete commit.

The router probe requires explicit `--run`; `--define` only loads inert developer
test functions. No automatic router invocation belongs in local or CI runners.
Parent prepared/reviewed the first JFFS probe, explained its exact write inventory
and received one-test permission. The attempt at code commit `3e164914ef23d6d021a9f8c03cf629903a44b75c`
returned 2 at the UID check, before mkdir or any flush. Scratch path
`/jffs/addons/.cfmgr-storage-probe-17489` was absent afterward; read-only follow-up
confirmed no `.cfmgr-storage-probe-*` paths. Private invocation and output are
`.tmp/storage-review/router-probe-20261012.sh` and `.log` (stream SHA256
`2476176c378e11d300be4925b6ccef2c32c533bdc04d0621920a106a71fa939a`).
USB-backed tests have separate evidence scope; `/mnt/MERLIN/tmp` was absent during read-only inspection, and the mount's
actual canonical location is `/tmp/mnt/MERLIN`, `/dev/sdb1`, ext4 rw,nodev,relatime,
data=ordered. `/mnt` is a firmware alias to `tmp/mnt`. No native file or
directory flush had been executed before the correction. The payload remains 30 bytes.

Corrected USB probe passed on the dirty tree based on `3e164914`, with probe SHA256
`997604b48de30191702421c350a813bbe40c8074e841de6844d36c35e36313c8`.
Parent streamed the library/probe through isolated native `/bin/sh --run
/mnt/MERLIN/tmp`; exact invocation stream/output are ignored
`.tmp/storage-review/router-usb-probe-20261012.sh` and `.log`. Stream SHA256:
`9f7ab9b495a99f4df17809c0c21a7b049dfd93a9bae332d638298a6a93c70f08`.
Exit 0: file/directory flush, rename, readback and cleanup passed. Scratch
`/tmp/mnt/MERLIN/tmp/.cfmgr-storage-probe-22723` was removed. Independent read-only
SSH confirmed `/mnt/MERLIN/tmp` retained mode 700 and empty including hidden files,
and no JFFS probe-prefixed paths. No services/settings/packages were changed.
This proves one native ext4 happy path, not Linux fault cases, JFFS durability,
complete Save or another supported firmware. No SSH/job remains active.

Correction contract: no id/stat dependency. Native `/proc/self/status` supplies
UID admission; verified numeric ls supplies exact private owner/modes. Hold the
scratch directory/file descriptors through cleanup and compare device/inode using
native `test -ef` against `/proc/self/fd`. Create the file on its held descriptor
under noclobber. Reject missing utilities before writes. Keep JFFS as the default
explicit `--run`; add only the separately selected `/mnt/MERLIN/tmp` target with
canonical mounted-volume admission. Create tmp if absent and always retain it;
preserve any pre-existing tmp and its permissions/content. Test data belongs only
inside it and probe cleanup removes only its verified scratch objects. Tests must
cover actual cleanup behavior and native tool
absence, including Linux descriptor proof separately from host fixtures. Parent
reviews code and focused evidence before any permitted USB run; no JFFS retry.

Workers may not overlap files, edit planning documents, publish, access the router
or spawn agents. Tests use isolated fixtures with shared immutable setup and
serial execution. Host shell is resolved Homebrew bash in POSIX mode; Linux uses
actual BusyBox ash. `CFMGR_REQUIRE_BUSYBOX=1` makes absent required platform proof
a failure, not a green skip. Parent reviews both packages and their combined
checks before the next dependent package.

Platform package contract (S02.04/S02.09, V02; current consumers are the native
storage probe and required dependency command checks): boot rebuilt upstream
ARM64 4.1.51/4.1.52/4.19.183/4.19.294 kernels, using a pinned legacy kernel
compiler; compile vendor BusyBox 1.25.1 separately with a libc-equipped compiler.
Use one vCPU and bounded memory per guest, at most two compiler jobs per runner,
and a kernel matrix capped at two concurrent CI jobs.
Pin current aarch64-k3.10 and armv7sf-k3.2 package versions/hashes, including
transitive dependencies. ARM32 compatibility must really execute, not be inferred
from ARM64 success. Downloads/builds run only in explicit Linux CI tooling, never
the host focused suite or router. Guest tests verify version identity, real
storage-wrapper/probe behavior and required JSON/timeout/SHA tools. Test scripts
must fail missing/mismatched proof and check an exact completion marker, not only
QEMU exit zero. No package maintainer scripts or router firmware are executed.
Generic same-version kernel execution is ABI/behavior evidence, not an exact
Merlin vendor kernel, NAND/JFFS2 failure test or model support tick. Preserve the
existing full CI jobs and documentation-only exclusions; add this required job
and focused offline tool tests in the same package. Parent reviews source, tests,
cost and focused local checks before an eligible platform CI push.

Parent verified both official package indexes and all 18 selected IPK hashes per
feed (about 11.3 MB total compressed), including the transitive closure. Baseline
read-only native SSH metadata selects aarch64-k3.10 with jq 1.8.1-2, timeout/SHA
9.9-2, bind-dig 9.20.18-2 and Entware libc 2.27-12. Static jq ELF inspection confirms
ELF64/AArch64 with `/opt/lib/ld-linux-aarch64.so.1`, and ELF32/ARM for armv7sf-k3.2
with `/opt/lib/ld-linux.so.3`. This is availability/ABI metadata, not execution.
Coreutils payloads install under `/opt/libexec/*-coreutils`; CI calls those files
directly instead of executing package scripts that configure normal alternatives.

## Evidence pending and next actions

1. Parent reviewed/integrated the probe correction and ran
   `.venv/bin/python tools/test.py --focused tests/test_storage.py` on the dirty
   tree based on `3e164914`: **22 passed, 9 Linux skips in 0.77s**. Planning,
   whitespace, Ruff/format/compile, Homebrew bash POSIX syntax, ShellCheck and
   shfmt passed. The nine skips cover native proc reopen, native-tool preflight
   and six real descriptor cleanup/fault scenarios; they are not passes.
   The single compiled C fixture is reused; tests run serially. Earlier 19/2
   host evidence is superseded for changed probe behavior. No full local suite
   was run for this correction. The USB receipt above is separate native happy
   path evidence and does not replace the skipped Linux fault cases.
2. The platform package is implemented and parent-reviewed: runner/manifest,
   three pinned vendor BusyBox sources, four upstream kernel versions, both
   Entware feeds, guest fixtures, focused tests and the four-job workflow matrix.
   Parent ran `.venv/bin/python tools/test.py --focused tests/test_platforms.py`
   on dirty `6b411736`: **15 passed, zero skips in 0.21s**, with planning,
   whitespace, Ruff/format/compile, shell syntax, ShellCheck and shfmt passing.
   No full local suite was run. Offline tests do not execute ARM programs.
3. Parent independently staged all 36 actual hash-verified IPKs using the new
   extractor and checked required ELF class/machine for both feeds. Host
   libarchive read the resulting initramfs (175 entries). These are data-format
   checks, not execution. Private artifact:
   `.tmp/platform-review/feed-stage-briuimcw/feeds.cpio.gz`.
   Corrected actual flock payload path, ext4 lost+found/options, kernel config
   dependencies and cache scope during review. No maintainer scripts executed.
4. Package cost review: serial host tests; up to two CI kernel jobs, two compiler
   jobs per runner, one CPU/256 MB per guest. Caches keep verified immutable
   artifacts; runtime fixes reuse unchanged builds. Existing planning, full host
   and mandatory BusyBox jobs remain; docs-only exclusions remain. Updated
   developer commands describe generic-kernel and hardware evidence limits.
5. Next: commit reviewed package, verify unchanged remote develop, explain the
   eligible platform dependency and push under the user's conditional grant.
   Require all seven required jobs green at that exact code SHA before further
   implementation; fix/re-push failures within this checkpoint. Compilation,
   kernel config, boot and actual Entware execution remain pending until CI.
   No current subgoal or main goal is complete; TLS/firmware admission and actual
   production consumers remain missing even if these selected guests pass.
6. S04.03 remains pending. Simple alternatives checked so far do not expose the
   discarded JFFS2 flush error. Raw-dump tools do not provide a coherent live
   filesystem snapshot; existing jffs2reader omits CRC checks. Final review asks
   whether a narrow positive transaction witness avoids that limitation, while
   respecting the user's preference against complex custom verification.
   No router cache clear, remount, freeze, raw-flash scan or further write is
   authorized/performed. Do not weaken the guarantee by an implementation edit.
7. Continue goal 2's usable installation/storage/dependency workflow when the CI
   gate and Save design permit, then return towards goal 1. Another JFFS probe
   requires fresh permission. Router test writes remain confined to the retained
   `/mnt/MERLIN/tmp`; remove owned test artifacts, never that base.

Other unresolved schema, storage, supervision, package, provider and default
choices remain in specification section 17 and checklist. No proposed logging,
backup or binary-update default was silently accepted. Required complete guides
remain under S16.03; interim developer notes stay small.

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
