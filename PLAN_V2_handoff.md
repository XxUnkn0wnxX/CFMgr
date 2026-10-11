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
qualify. This storage-helper package has not been judged eligible or pushed.
No current permission covers live installation/deployment, provider mutation or
another history/reset operation.
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

- Reviewed local checkpoint: `3e164914ef23d6d021a9f8c03cf629903a44b75c`
  (`Start native storage validation and runtime checks`). It contains the tested
  partial package and current instructions; develop is one commit ahead of the
  last verified origin/develop. No push has occurred. The current correction and user-amendment diff is locally validated and awaiting
  its reviewed local checkpoint.
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

**Proposed, not approved:** clarify S02.09/S04.03 to retain JFFS support with an
explicit firmware error-reporting limit: CFMgr checks every exposed write/flush/
rename error and retains staged generations, intent/guards, readback and recovery;
it cannot promise detection of failures the kernel reports as success. Mirror the
capability limit in the checklist and test reported-failure handling, without
claiming a normal probe proves hidden-error detection. Alternative: leave the
stronger guarantee unchanged and keep affected durable Save support unaccepted
until a verified error-reporting route exists. No runtime support/acceptance or
specification change is authorized by this proposal alone.
The user answered by reaffirming support for Merlin's full supported kernel range,
using their router firmware as the baseline. That compatibility requirement is
accepted and mirrored in S02.09 in specification/checklist. It is not approval to
weaken S04.03. Map official supported generations and their native error paths;
the durability guarantee remains unchanged and its affected acceptance pending.

## Current ownership and contracts

| Owner | Exclusive files/scope | State |
| --- | --- | --- |
| Parent | PLAN_V2.md, checklist, handoff, AGENTS.md, README; architecture and integration | Native descriptor correction approved within probe scope; review and authorized USB execution after focused proof. |
| probe_compat | tools/router-storage-probe.sh; tests/test_storage.py | Returned: native admission/cleanup correction and explicit USB mode, 22 host passes/9 Linux skips. Parent reviewed code/test diff; ownership returned to parent for integration and permitted USB verification. |
| storage_flush | modules/lib/storage.sh; tests/test_storage.py; tests/fixtures/fsync_legacy.c; tools/router-storage-probe.sh | Returned; parent reviewed and reran focused tests. Ownership returned to parent. |
| runtime_checks | tools/check.py; tools/test.py; requirements-dev.txt; .github/workflows/checks.yml; docs/development.md | Returned and parent-reviewed; original workflow preserved, focused/full runner and required BusyBox job wired. Ownership returned to parent. |
| source_parity | Read-only supported-model/kernel mapping; no writable files | Map current official supported devices to pinned release source kernel families; do not infer coverage from the three cached images. |
| persistence_review | Read-only native probe identity and kernel-error review | Both returned and parent-reviewed; kernel reporting blind spot confirmed as source evidence, no observed live loss. No router execution. |

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
2. Existing full host/required BusyBox CI already collects the changed storage
   tests and needs no new dependency for this correction. It has not run for
   current code. Keep documentation-only exclusions, planning checks, original
   trigger/checkout settings and modest resource bounds. Parent corrected an
   initial worker draft's unrelated workflow drift before the first commit.
3. The user's next instruction is to obtain fixtures spanning Merlin's oldest
   through current supported kernel/BusyBox generations and exercise unavailable
   platform checks through CI. Map official supported devices to pinned source
   versions/configs first; three cached images do not establish the endpoints.
   Add focused versioned fixtures and CI in one coherent package. Kernel-sensitive
   proof must actually boot/run the selected kernel or stay explicitly pending;
   changing a userspace container does not change its host kernel. Respect the
   approved earlier platform-CI publication gate; no extra full local run.
4. Preserve the S04.03 kernel error-reporting limitation and pending scope
   decision. The user's response reaffirmed full supported-range compatibility;
   no reduced durability guarantee was approved. Reconcile the native route
   across that range before accepting or changing the Save contract.
5. Continue goal 2's usable installation/storage/dependency workflow, then return
   towards goal 1. Keep incomplete subgoals unchecked and preserve useful work.
   Another JFFS probe requires fresh permission. Router test writes are confined
   to the retained `/mnt/MERLIN/tmp`; cleanup its test contents, never that base.

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
