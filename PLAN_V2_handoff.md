# CFMgr v2 — current handoff

<!--
Codex Session: 01a12b73-456b-7de0-b3c2-db151518949f
Codex Session: 01a12ca8-2b44-7791-90ab-a1e5b17b3d18
Second ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd; no child IDs are included.
Codex Session: 01a12d2e-4093-74b3-a13a-5be95ceaa965
Third ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
Codex Session: 01a12e40-f76a-7710-9c55-a4b89970cbd2
Fourth ID verified 2026-10-12 against parent environment and matching
session_meta id/cwd/thread_source=user; no child IDs are included.
-->

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Working rules](AGENTS.md)

## Active work: complete one main goal, then pause

The user resumed work and revoked this session's subgoal-pause override. Continue
through foundations/subgoals until one whole main goal completes its audit, full
local, exact full CI, acceptance/README and handoff gates; then pause under normal
rules. S03.01 remains accepted. Current focus returns to **Goal 2**, the installation
and dependency foundations needed by original Goal 1. Cross-goal prerequisites
remain authorized; they earn only their own verified progress.

The user explicitly permits subgoals from different main goals in any dependency-
appropriate order: **build foundations and prerequisites first, then the workflows
that depend on them**. Record each selected subgoal, its consumers/dependencies and
return path before implementation. This sequencing permission does not change
product requirements, evidence, publication gates or progress calculations.

The user also clarified the validation cadence: keep focused tests/static checks,
parent review and outstanding gates in the checklist for each subgoal. **Full local
and full CI gates run only when a complete main goal is ready for its checkpoint.**
The early-push exception remains when CI is needed for unavailable focused proof:
run available local checks, push the reviewed package, run only the required
focused CI, wait for its exact-SHA result and then resume/pause as agreed. This is
recorded in AGENTS.md and the checklist; it replaces the older early-push full-CI
requirement. No relevant missing proof may be counted as a pass.

Current integration set:

| Owner | Exclusive files / scope | Contracts, dependencies and gates |
| --- | --- | --- |
| Parent | Three plans; architecture and integration; package metadata | S02.04/S02.05 admission/repair design through installer; review stored-state/ownership dependencies before opkg writer delegation. |
| Parent | Returned CI/runtime files and integrated focused gate | Both workers finished and released their files. Parent reviews admission/failure paths, regenerates metadata, records evidence and publishes only for required focused Linux/BusyBox proof. |
| `focused_ci` worker (complete) | `.github/workflows/checks.yml`, `tools/test.py`, `tests/test_dev_runners.py`, `docs/development.md` | Validated final `CFMgr-Focused-Tests:` commit trailer lists explicit test files; ordinary pushes/PRs remain full. Local files/directories and keyword filters remain supported; full BusyBox storage-suite guard retained. 24 runner tests and static gates passed. |
| `prerequisite_inventory` worker_strong (complete) | `modules/lib/prerequisites.sh`, `modules/helpers/bootstrap.sh`, `tests/test_prerequisites.py`, `tests/test_install.py` | S02.04/S02.05 prerequisite inventory consumed by fresh installer. 21 focused passes, 3 Linux-only skips; source statics passed. Probe helper unchanged. No opkg mutation or subgoal tick. |
| Process design analyst (complete) | Read-only native/old-reference/source review | Confirmed cron process-group launch, baseline absence of namespaces/cgroups, and private execution-root ownership considerations. Parent owns the design below. No edits/tests/router work. |

Prerequisite package entry is the existing `--install` → native-work → check call.
Missing behavior: first-failure probes cannot select all missing/unusable packages;
eager fallback admission violates native-first locking. Preserve the 15-argument
check interface and output fields, add only a fixed-list deficiency result, and
admit optional fallback only when selected. Fatal mount/ownership/native-supervisor
failure aborts; ordinary completed negative capability probes may be aggregated.
Check/recheck calls use separate fresh private contexts. DNS version-only evidence
remains partial, and no tunnel/readiness claim is awarded. Parent regenerated the
manifest and reviewed both returned packages. The integrated command
`.venv/bin/python tools/test.py --focused tests/test_prerequisites.py tests/test_install.py tests/test_dev_runners.py`
passed **62 tests, 4 Linux-only skips**, 31.26s, plus all planning/package/static
gates on the dirty tree based on `4a50dd0`. Receipt:
`.tmp/prerequisite-inventory-focused.log`. Remaining proof is exact focused
Linux/BusyBox CI for ownership/locking/FD cases. The authorized early push uses
those same three files in its final `CFMgr-Focused-Tests:` trailer; wait for that
exact run before further implementation. No full suite/main-goal gate is claimed.
Cost review uses the preceding 50-second warm Ubuntu job and current focused
timings; caches/resources are unchanged, no extra measurement suite was run.

- Active Goal 2: **1/9 accepted = 11.1%** (S02.03).
- Supporting Goal 3: **1/10 accepted = 10%** (S03.01).
- Product: **0/16 main goals = 0%**. No main-goal/README completion earned.

The preceding acceptance package selected S03.01 as the direct companion to the already delivered
S02.03 defaults installer, notified the user before switching and reviewed every
passive-state clause. This was acceptance of existing implementation, not a new
runtime package. Only checklist/handoff receipts and the clarified standing test
cadence changed. That package is committed as
`4a50dd0d6ddbd18a906e0a870c8d4ca592148a33`, one local commit ahead of origin.
No unanswered approval or inherited CI/router job remains. Active ownership
is listed above; do not interpret the preceding pause as current permission state.

## Current refs and evidence

Resume started on clean local/remote `develop` at
`bc49cf54831e8b7099aad3aee9ba8e75fbcae137`. The current acceptance receipt is local
only, titled `docs: accept passive fresh state and clarify checkpoint gates`;
no push occurred this session. Verify `HEAD` and status on resume. Tested
runtime remains `7ce3cad771a7cedb0e2f17e69082f9659655c5c5`, already published.
[Checks 38200865754](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38200865754)
was reverified at that full SHA: its sole Ubuntu job passed in **50 seconds**.
That was the unchanged runtime at session start. The current inventory/runner
changes and regenerated manifest now require their own focused evidence; the old
CI does not prove these edits. Subsequent documentation receipts are not new
runtime-tested commits. Earlier S02.03/tool receipt:
`02063a4e40764d682dcdd917fa550ad0251a4f63`.

Fresh focused command on the starting HEAD plus handoff-only edits:

```sh
.venv/bin/python tools/test.py --focused tests -k 'test_config or test_install'
```

**24 passed, 1 Linux-only skip, 142 deselected**, 26.62s. All planning/links,
package metadata, Ruff lint/format, compilation, shell syntax, ShellCheck, shfmt
and whitespace gates passed. The skipped identified-copy signal/FD test ran in
the accepted Linux CI. Private receipts: `.tmp/s03-01-focused.log` and freshly
retrieved `.tmp/s03-01-existing-ci.log`. No full local/CI rerun was needed for
unchanged code/tests; no main-goal audit or hardware acceptance is claimed.

Actual consumer: `cfmgr.sh --install` → `cfmgr_bootstrap_native_work` →
`cfmgr_bootstrap_transaction` → fixed `install-config` probe →
`cfmgr_config_defaults_exec`, followed by checked passive-config publication.
The complete-default test covers all initial flags, credentials, family policy,
logging/backup and manager preferences. The transaction test covers publication,
private modes, passive states, an empty Entware destination and repeated-install
refusal; retained/corrupt/interrupted cases preserve setup. Parent traced fixed
installer actions: no feature/provider/hook/logging/backup setup runs at install.
No missing S03.01 behavior remained, so no duplicate lifecycle tests were added.

Required Ubuntu/vendor-BusyBox evidence is representative component/transaction
execution with labelled attachment/supervision adapters plus real Linux process/FD
cases. Exact root/JFFS2 `--install` runs in the optional guest fixture; it was not
rerun or newly accepted. Merlin/ARM/flash/provider qualification remains beta work.
Manager defaults do not establish update scheduling or other feature workflows.

`next_subgoal_review` explorer returned a read-only consumer/acceptance review;
parent integrated its findings and reviewed the existing tests/source. No worker
edited files or ran tests for that preceding acceptance package. Parent exclusively
owned its planning receipts and focused gate. Current work is listed above.

## Pending foundation findings

Use approved dependencies to select the next coherent package; numeric subgoal
order is not mandatory. Goal 2 still supports original Goal 1. Preserve partial
work and keep these gaps visible:

- **S02.04:** shared probes have an installer consumer, but tunnel DNS remains
  `dig -v` with no real tunnel consumer. The current package fixes native-first
  locking and inventories every ordinary missing/unusable direct requirement;
  unsafe admission, absent supervision and unresolved ownership remain fatal.
  Focused Linux/BusyBox proof and the scoped DNS consumer remain pending.
- **S02.08:** fresh UUID storage and current invocation pins exist; retained
  expected-identity comparison and returning-work eligibility do not. Production
  pin/lazy-unmount/substitution loss needs written representative proof; boolean
  attachment adapters cannot establish those behaviors.
- **S02.05:** the current inventory supplies missing/unusable-only selection.
  Installed-opkg admission, serialized bounded repair, healthy no-op, post-probes
  and bounded later-launch retry still require production implementation.

Next shared foundation is S02.05/S02.08 execution/storage containment, returning
to Goal 2 repair and reinstall consumers. Merely polling the `/opt` alias does
not prevent stale-path writes. The parent design is a private execution root with
descriptor-bound Entware; ordinary installed opkg retains its configured feeds,
dependency resolution and scripts. No cgroups/namespaces or new resident daemon
may be assumed. Track the direct launch plus tasks rooted in the owned root/mounts,
including daemonization/nested roots and surviving threads; close outside FDs.
On storage loss/deadline, cancel only verified owned tasks with bounded cleanup.
Persistent/uncertain ownership or busy normal unmount retains guard/root evidence;
never use lazy teardown to claim success. Successful opkg exit alone cannot clear
that guard. Later invocation may recover/retry only after verified quiescence and
cleanup; a completed ordinary failure without survivors must not latch permanently.
The execution view must be proved compatible with normal selected package scripts
before repair acceptance. This is planned implementation, not proven behavior.

Source evidence: pinned Merlin crond creates a process group in both branches;
Linux/chroot sources show inherited filesystem roots across fork/exec independently
of process groups. Analyst hash-verified cached GT-AX11000 embedded kernel config
against `kernel-config-status.json`: SHA256
`b9795f074b019c327b1ea6fe7d29d46f6e716a9d017a8235c648e10c30cf323a`,
with cgroups and namespaces disabled. Other cached firmware evidence was not
requalified. No firmware or router execution occurred. Historical committed
dependency/isolation source is retained read-only under `.tmp/previous-*-reference.sh`;
it supplies patterns only, not acceptance or permission for a wholesale restore.

The official Merlin Addons API, User scripts and Custom config files authorities
were consulted during scope review; no new firmware compatibility claim or
storage/hook behavior was implemented. Existing raw firmware evidence was not
requalified or executed. These findings do not close S02.04/S02.08/S02.09 or Vxx.

Prior authorized Actions cleanup is complete: **14 failed/cancelled kernel-CI
runs were deleted**, preserving successful runs and shared caches. Private receipt:
`.tmp/actions-cleanup-20261012.json`; retained diagnostics:
`.tmp/platform-review/`. Do not recreate removed runs or restart the obsolete
matrix to reconstruct history. No new deletion/publication grant is implied.

## Accepted platform and logging decisions

The user replaced mandatory kernel/firmware VM CI with **one approximate Ubuntu
runner**, running host integration and native-host vendor BusyBox tests. Get close
to the target without requiring exact Merlin emulation or every kernel/ARM profile.
These checks are sufficient development acceptance. At implementation 100%, the
integrated CLI and guides are ready for extended real-router beta, starting with
the GT-AX11000; hardware/flash/hooks/TLS/provider qualification and optional other
router testers follow. Keep support provisional; beta deployment and release still
need explicit authorization. Runtime safety contracts remain required.

Python/APT/native BusyBox caches are preserved; Python and BusyBox were cache hits
in the accepted run. No required ARM downloads, compiler/kernel builds or VM boots.
GCC is not compiled. Existing optional QEMU tools/fixtures/caches are preserved,
not falsely passed or a development gate. During optional diagnostics/shared CI
repair, retrieve the first useful failure and stop redundant work promptly.

New **S13.14** requires `developer.log` covering the main CFMgr process, every
module, child results and trace/verbose/error/Off/stop paths, plus copies of CFMgr's
dedicated Scribe logs. Only `manager.developer` gates capture; feature On/Off does
not. The global `manager.developer_log_directory` selects the destination; no
rotation, pruning, truncation or automatic cleanup there. The user manages the
folder. Preserve Scribe's normal policies, captured history, safe mount checks and
truthful I/O failure reporting. Developer Off stops new capture and preserves files.

Normal and developer output must identify a relevant credential's actual type and
purpose. An eligible opaque token/key can show `****` plus at most its last three
characters; short/structured/unsafe material stays fully masked. Never dump full
credentials, raw authorization or private payloads, including child output/log
copies. These rules are mirrored in S13.13/S13.14 and their acceptance.

Only the passive default `manager.developer_log_directory=null` is implemented;
`manager.developer` remains false. No diagnostic writer is implemented or accepted.
The intended personal beta destination is `/mnt/MERLIN/CFmgr`; never hardcode or
create it now. Implement/test the actual capture during Goal 13 before beta readiness.

## Delivered consumer and remaining boundaries

- `cfmgr.sh --install` isolates native environment and consumes an explicitly
  trusted complete local package. Preflight checks JFFS2, mounted ext2/3/4 Entware
  identity/UUID, native/Entware tools, private paths and practical free space.
- Bootstrap verifies inventory/catalog/manifest/modes/hashes, rejects retained
  setup before defaults, claims a private recovery guard, generates mode-600
  passive config, verifies copied bytes, and publishes the entry/completion last.
  Failed/repeated/corrupt/incomplete installation cannot reset existing setup.
- Source/JFFS/Entware/context descriptors are pinned/rechecked. Signals cancel/reap
  the owned writer before cleanup; unresolved work retains recovery evidence.
  Context FD0 moves to FD5 after flock probes and before manifest loops. Short
  native waits use `/bin/usleep`; firmware fractional sleep is not assumed.
- Entry installs to `/jffs/scripts/cfmgr.sh`; nested support/catalog/manifest live
  under `/jffs/addons/CFMgr.d/`. No shipped product config/template. Actual mountinfo
  is authoritative when native blkid omits TYPE; supplied conflicts are rejected.
- No remote acquisition, opkg repair, retained recovery/update, feature menus,
  provider/hook/service activation or manager auto-update is delivered yet. Save
  is not implemented. Generated defaults alone do not close Goal 2 or Goal 3.

## Accepted evidence and review

Exact CI above ran `.venv/bin/python tools/test.py` (**163 passed, 4 skips**, 7.88s)
and, with native vendor BusyBox on PATH, `tools/test.py --require-busybox`
(**166 passed, 1 skip**, 17.78s). All required planning, metadata, Ruff lint/format,
compilation, shell syntax, ShellCheck, shfmt and whitespace gates passed. BusyBox
ran native fsync/supervisor/cleanup cases skipped in host mode. The remaining Linux
skip is specifically the workstation-without-`/proc` boundary, exercised locally.
Private receipts: `.tmp/platform-review/s02-03-ubuntu-run.json` and
`.tmp/platform-review/s02-03-ubuntu-ci.log`.

Earlier S02.03 focused local integration used:

```sh
.venv/bin/python tools/test.py --focused tests -k 'test_config or test_install or test_dev_runners or test_platforms'
```

It returned **73 passed, 1 Linux-only skip, 1 failed, 92 deselected**, 26.77s.
The failure was the synthetic planning fixture's old 156-row count after S13.14
made 157; the corrected `tools/test.py --focused tests/test_dev_runners.py` passed
**10/10**, 0.15s, with all static gates. CI then passed all corrected tests. Logs:
`.tmp/s02-03-ubuntu-focused.log`, `.tmp/s02-03-planning-fixture-focused.log`.
Earlier broad focused proof was **126 passed, 11 Linux-only skips, 21 deselected**
in 31.88s (`.tmp/s02-03-focused.log`); later affected package/installer/platform
repairs each passed their focused gate. No full local suite was run for this early
checkpoint. Main-goal completion still requires its audit/full local/full CI gates.

Parent reviewed the real entry/config consumer, failure paths, generated metadata,
focused regressions, exact full CI and evidence limits. `ci_tools` returned the
single-runner workflow/docs package and final cache/dependency review; parent
restored the original KEY/USR probe instructions and kept `jq shellcheck` APT
inputs. `portable_tools` returned the null default and seven passing config tests;
parent shfmt/static integration closed its missing local tool check. Test cost is
now the observed 50-second warm CI job, with no extra full run for timing.

The five approved developer tools are accepted in checklist for their listed
proof: planning checker, focused/full runner, platform runner, package builder,
and portable router probes. Optional guest boot proof remains separate/unaccepted.
The runner uses pinned pytest/Ruff/shfmt; JSON/SSH configuration uses stdlib, so no
missing parser dependency. `requirements-dev.txt` matches the development venv.

Router tools use ignored mode-600 `tools/router.local.json`; fake tracked template
supports KEY/USR and optional port. Current private config uses KEY with blank
username/password/port and existing global SSH settings. Local config check passed;
the launcher has not run against the router. Tests prove transport/auth/quoting and
isolated native cleanup. Future live execution retains the router boundaries below.
Package generation is `tools/package.py --write`, then `--check`; regenerate after
runtime source changes. Regular Finder metadata is excluded; unsafe objects fail.

## Resume path

1. Verify the local-only acceptance receipt, Git/remote state and no active jobs.
   Do not repeat finished proof or restart the optional kernel matrix.
2. Resume foundation-first work, normally remaining Goal 2 requirements; use the
   findings above and actual consumers to choose a complete dependency package.
   Cross-goal prerequisite work is explicitly permitted. Record scope, ownership
   and focused checks before assigning a writer.
3. Keep S02.03/S03.01/tool ticks scoped to their accepted development evidence.
   All main goals, remaining product subgoals, Vxx cases and README remain incomplete.
   The user revoked subgoal pauses; continue to the normal full
   main-goal boundary follow audit → full local → exact full CI → main tick/README →
   handoff/pause. Actual router/provider beta follows complete implementation.

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
