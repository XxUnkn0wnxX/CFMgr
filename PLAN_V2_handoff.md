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

## Paused checkpoint

**Active goal 2: installation, storage and dependencies — 1/9 accepted = 11.1%.**
S02.03 now has accepted focused local and exact Ubuntu/BusyBox CI proof. Overall
product completion remains **0/16 = 0%**. Goal 2 is the announced prerequisite for
original goal 1; S02.04/S02.08/S02.09 supporting work remains partial and unchecked.

The user requested one completed subgoal plus supporting tools, accepted CI and
receipt, then **pause for the day**. This boundary is reached: do not start another
package until resume. No main-goal audit/full local gate or README update belongs
to this early checkpoint. No unanswered approval remains. All workers returned;
no required CI, local test process or router session remains active.

Tested code is `7ce3cad771a7cedb0e2f17e69082f9659655c5c5`, published to `develop`.
[Checks 38200865754](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38200865754)
passed its sole Ubuntu 24.04 job in **50 seconds**. The current documentation
receipt records the resulting S02.03/tool ticks and pause; it is not another tested
runtime revision. Verify `git log -2`, clean status and remote `develop` when
resuming. No `main`, release, deployment or provider action was performed.

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

Latest focused local integration used:

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

1. Verify this receipt, clean Git/remote state and no active worker/job. Do not
   rerun the finished checkpoint or restart the optional kernel matrix.
2. Resume remaining Goal 2 requirements using the plan/checklist and real consumers;
   inspect S02.04/S02.08 foundations before selecting the next coherent package.
   Record exact missing behavior and focused tests before assigning a writer.
3. Keep S02.03/tool ticks scoped to the accepted development evidence. Goal 2,
   multi-goal Vxx cases, all other subgoals and README remain incomplete. At a full
   main-goal boundary follow audit → full local → exact full CI → ticks/README →
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
