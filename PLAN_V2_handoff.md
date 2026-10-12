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

**Active goal 2: installation, storage and dependencies.** S02.03 has the real
trusted-local fresh-install consumer and passing focused local proof. Goal progress
is **1/9 focused-passed = 11.1%**; final acceptance waits for the new exact Ubuntu
CI gate. Overall product completion remains **0/16 = 0%**. Goal 2 is the announced
prerequisite for original goal 1; supporting S02.04/S02.08/S02.09 work has no tick.

The user authorizes this subgoal/tools checkpoint: focused checks, commit/push,
required CI, concrete failure repairs/re-pushes, justified ticks and receipt, then
fully refresh handoff and **pause for the day**. No next subgoal in this session.
No README update: only main-goal completion affects its table. No full local run
is required for this early checkpoint; later main-goal audit/full-local/full-CI
requirements remain. No unanswered approval remains.

## Accepted validation change

Latest explicit addition: developer-only diagnostics belong to new S13.14, with
redacted main-process/all-module trace/verbose capture and dedicated CFMgr Scribe
log copies in a global-config destination, regardless of feature On/Off. The
destination has no CFMgr rotation/pruning/truncation/automatic cleanup; the user
manages its contents. Preserve normal Scribe policies and safe mount-loss handling.
Normal and developer logging must identify a relevant credential's type/purpose
and mask any displayed value as `****` with at most a safe three-character suffix;
short/structured secrets remain fully masked. No unmasked diagnostic exception.
The user's intended
beta destination is `/mnt/MERLIN/CFmgr`; do not hardcode or create it now. Default
`manager.developer_log_directory=null`, gated by `manager.developer=false`.
`portable_tools` returned `modules/lib/config.sh` and `tests/test_config.py` with
that passive default; seven focused config tests passed. Parent owns metadata regeneration, focused
integration and all planning documents. No diagnostic writer is implemented or
accepted at this Goal 2 checkpoint; complete S13.14 before beta readiness.

The user explicitly replaced mandatory kernel/firmware VM CI with **one Ubuntu
runner** for approximate integration and native-host vendor BusyBox checks. Real
router use becomes the true beta after implementation is finished, with an
extended beta and optional external testers. Product safety contracts remain;
100% means implementation complete and ready for beta, not stable hardware
qualification. Router/provider changes, beta deployment and publication still
need their own authorization. PLAN_V2.md, checklist and AGENTS.md now mirror this
change, including S02.09/S16 and the supporting platform-tool requirement.

Current workflow candidate runs planning, full host/static tests and full vendor
BusyBox tests on one Ubuntu 24.04 runner. Python/APT and native BusyBox caches
remain. No required ARM toolchain/feed downloads, kernel builds or VM boots. Retained
QEMU tools/fixtures/caches are optional diagnostics; their cancelled/unverified
runs do not become passes or block development ticks. During optional diagnostics
or shared CI failure repair, collect the first useful failure and cancel redundant
work promptly. Final acceptance always needs the prescribed exact CI green.

Latest published pre-change code is
`bb8d5157bda2df6cd42a3e530e92a0662402e843`; its kernel-matrix
[run 38199408002](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38199408002)
was cancelled at the user's request and is **not accepted**. The single-runner
workflow and mirrored docs are current uncommitted candidate work; verify Git
state before resuming. All worker ownership returned; parent owns integration
and planning files. `ci_tools` completed the final read-only workflow/cache review with no blocker;
parent verified the integrated changes. No active worker or router session remains.

The old guest loop exposed fixture assumptions (BusyBox configuration, native
sleep, whole-guest budget and Entware jq without regex). A guest completed its
first native install/cleanup before the UUID assertion failed. Its replacement
uses an exact synthetic filesystem UUID, but no complete current guest pass is
claimed. Private logs remain `.tmp/platform-review/s02-03-*.log`; optional tool
sources and firmware evidence are retained. Do not restart that matrix without
an explicit diagnostic reason/request.

## Implemented consumer and limits

- `cfmgr.sh --install` isolates the native environment and consumes a complete,
  explicitly trusted local package. Preflight admits actual JFFS2, mounted ext2/3/4
  Entware identity/UUID, native/Entware tools, private paths and practical space.
  No public test-root override, remote acquisition or opkg repair exists yet.
- `bootstrap.sh` checks complete inventory/catalog/manifest/modes/bytes, blocks
  retained setup before defaults, claims a durable private recovery guard,
  verifies copied package bytes and generated passive extensionless config,
  publishes the entry and completion record last, and checks exposed flush errors.
  Failed/repeated/corrupt/retained setup cannot reset configuration. No feature,
  hook, service, provider or manager auto-update is activated.
- Inert config/storage/prerequisite libraries and the finite probe helper support
  that consumer. Source/JFFS/Entware/context descriptors are pinned and rechecked.
  Signal handling cancels/reaps the owned writer before cleanup; unresolved work
  retains recovery evidence. Context FD0 transfers to FD5 after flock probes,
  before manifest loops. Native short waits use admitted `/bin/usleep`; firmware
  floating-point sleep remains disabled in the fixtures.
- Installed entry maps to `/jffs/scripts/cfmgr.sh`; support/catalog/manifest stay
  under `/jffs/addons/CFMgr.d/` with nested module paths. Private defaults are code-
  generated, not a distributed product config/template. Root-relative Entware
  bind mounts are supported. Native blkid may omit TYPE; verified mountinfo is
  authoritative and any supplied conflicting TYPE is rejected.
- Optional guest fixtures run the unmodified entry on disposable RAM-MTD JFFS2 and ext4,
  with real pinned Entware packages. They check passive config, exact volume
  identity, private modes, installed bytes, repeated/corrupt/incomplete rejection
  and cleanup. Only the JFFS script-enable NVRAM query is emulated. These are
  limited generic kernel/BusyBox/Entware tests, not a complete Merlin emulator or
  physical-router/flash acceptance. S02.09 native profile qualification remains.

## Developer tools and validation

Five approved supporting tools remain unchecked until the new required exact Ubuntu CI passes:
planning checker, focused/full runner, platform runner, package builder and router
probe tools. Parent reviewed their real consumers and failure paths.

- Package builder checks deterministic complete mapping, safe inventory, byte
  metadata and absent/empty output. Regular Finder metadata is omitted; unsafe
  objects/metadata-only directories fail. Regenerate catalog/manifest after any
  runtime source change with `tools/package.py --write`, then `--check`.
- Portable router launcher reads ignored `tools/router.local.json`; fake template
  documents KEY/USR and optional port. KEY uses normal SSH config/public keys;
  USR requires private username/password and restricted ASKPASS. No password in
  argv/environment/logs; unknown host keys are not accepted. Actual local config
  uses KEY and blank username/password/port, inheriting existing SSH settings.
  Config validation is local-only; this launcher has not run against the router.
- Probe requires explicit execution, a selected mounted scratch directory, owned
  artifacts/descriptor checks and verified cleanup preserving the base. Transport
  tests use fixtures; Linux/BusyBox tests prove native descriptor behavior.
- `.venv` uses pinned pytest/Ruff/shfmt from `requirements-dev.txt`; JSON/SSH tools
  use Python stdlib. Dependency consistency passed; no JSON package is missing.
  Developer notes remain short. README and full product guides are not completed.

Focused combined gate: **126 passed, 11 explicit Linux-only skips, 21 deselected,
31.88s**; `.tmp/s02-03-focused.log`. Command:

```sh
.venv/bin/python tools/test.py --focused tests -k 'install or prerequisite or mountinfo or config or router_probe or dev_runners or platform or package or probe or canonical_attachment or volume_uuid'
```

Later affected package/storage, installer/prerequisite and platform repairs passed
focused gates. Latest focused integration selected config/install/developer-runner/platform tests:
**73 passed, one Linux-only skip, one planning-fixture failure, 92 deselected** in
26.77s. The new S13.14 increased the required subgoal count to 157; the synthetic
planning fixture still had 156. After correcting that fixture, the affected
`tests/test_dev_runners.py` gate passed **10/10** in 0.15s. Both invocations ran
Ruff lint/format, compilation, shell syntax, ShellCheck, shfmt, package metadata,
planning and whitespace checks. Logs are `.tmp/s02-03-ubuntu-focused.log` and
`.tmp/s02-03-planning-fixture-focused.log`. No full local run.

Previous candidate `0babd62d0e91873a5acaae2a6df83487c9e74d3d` passed full Linux
host/static (**163 passed, 4 expected platform skips**, 5.35s) and required vendor
BusyBox (**166 passed, one host-without-proc case skipped**, 18.06s). All mandatory
native supervisor/fsync/cleanup cases ran. Logs:
`.tmp/platform-review/s02-03-candidate-host.log` and `s02-03-candidate-busybox.log`.
These receipts do not replace the new single-runner candidate CI. Earlier host adapters are
labelled; they cannot establish native guest admission/attachment behavior.

## Next actions

1. Finish parent review of the single-runner workflow, concise developer notes and
   mirrored plan/checklist/AGENTS change. Planning and whitespace must pass.
2. Commit/push this authorized candidate; verify exact remote SHA and require the
   one Checks job, both full test suites and static gates green. No old or cancelled
   run supplies that receipt. Fix only concrete failures before moving forward.
3. Tick S02.03 and fully proved tools under the approved automated gate. Record
   tested full SHA/run, commands/results and deferred beta limits. Do not tick
   Goal 2, unfinished multi-goal Vxx cases or README.
4. Push a proportionately checked documentation receipt referencing tested code,
   fully refresh handoff for a new session and pause with no required active jobs.

## Retained evidence and limits

Native cache baseline `d71c813a73da5e0b07a1f0c1af2292aeb17e1111`,
[Checks 38190294055](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38190294055),
proved earlier cache/fixture behavior. Logs are in `.tmp/platform-review/`.
Historical generic kernel/feed success is separate from the current installer.
Pinned optional profiles remain in `tests/fixtures/platforms.json`; raw provenance
is ignored in `.tmp/platform-review/source-index.json`,
`.tmp/storage-review/jffs2-source-provenance.json` and
`.tmp/firmware-audit/INDEX.md`. Verify hashes/scope before reuse; no deletion grant.

The user accepted the practical JFFS2 limit: check all exposed results and retain
staging/coherent publication/readback/recovery, but do not claim cached reads detect
kernel-hidden flash failures or certify persistence across reboot. Save remains
unimplemented. No raw-flash verification, cache clearing, disruptive mount test or
live JFFS write is authorized. Managed-On-only Cloudflared binary self-repair and
syslog warnings remain future S06.10/V06/V60 work.

The original read-only cloudflared/setup reference is located through ignored
`.tmp/reference-paths.md`; captured router files are supplemental. Preserve source
parity and never revive archived completion percentages or partial-feature ticks.

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
