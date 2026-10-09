# 🛠️ Development

[← README](../README.md) · [User setup](setup.md) · [Architecture](architecture.md) · [Compatibility](compatibility.md) · [Implementation plan](../PLAN.md) · [Test fixtures](../tests/fixtures/README.md)

![Python requirement](https://img.shields.io/badge/development-Python_3.11%2B-3776ab?logo=python&logoColor=white)
![Runtime target](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Project stage](https://img.shields.io/badge/stage-foundation-orange)

CFMgr is being implemented in checked stages. This guide describes the working
developer tools; [PLAN.md](../PLAN.md) remains the design, acceptance checklist,
and progress record. There is no installable manager yet.

Use focused tests and relevant lint/static checks for each small implementation
batch, then review and commit. Accumulate those commits for publication at each
approximately one percentage point of delivered requirements, as tracked in the
plan. At that checkpoint, run the full local suite and fix failures until it
passes before pushing the tested commits to `develop`. Wait for CI and resolve
failures before beginning the next set of batches. Pause after each ten-point
milestone's gates pass, or at the next safe boundary after a user pause request.
Unvalidated work stays local.

Finalize and review milestone code before updating its documentation. Assign
the parent or a dedicated documentation worker to the finalized commit/snapshot;
that work may run alongside CI, validation or other independent tasks. Recheck
the documentation after any later code fix and before publication.

Review and update the README and all relevant guides at every major milestone,
and no later than each ten-percentage-point checkpoint. Check development
commands, architecture, compatibility claims, setup instructions, contribution
rules and fixture evidence against the implemented stage. Record the audit,
including guides that remain accurate without edits, in PLAN.md. Documentation
accuracy is part of the checkpoint. Readers should be able to follow feature
availability and current usage as implementation progresses; planned commands
must remain clearly distinguished from available ones. At 100% completion, run a
separate end-to-end consistency and polish pass across all documentation.

Keep the suite affordable as it grows. Review the latest pytest duration report
before each `develop` push and after about three local implementation batches,
whichever comes first. Normal runs report the slowest calls; record comparable
full-suite times and coverage changes in [PLAN.md](../PLAN.md). Reuse existing
measurements and time affected cases rather than running the full suite again
just to gather timings.

Investigate new ordinary tests taking over roughly two seconds, integration
cases over five seconds, or a roughly 20% increase in comparable suite timings.
These are review triggers, not automatic failures or reasons to increase
timeouts. When costs grow, use a focused timing/duplication review and simplify
before adding further coverage. Aim for a full local suite of a few minutes.

Test data and policy permutations through the actual function or consumer;
keep a small set of complete integration cases to prove the connections between
layers. Run the primary shell's behavior matrix once, with selected secondary
shell cases for compatibility-sensitive behavior and the required BusyBox
checks. Preserve distinct signal, ownership, descriptor, byte-framing and
failure regressions. Reduce repeated acquisition and setup, not the assertions
that establish those contracts. Avoid a complex fixture framework or new
dependencies solely to save a few cases.

Before implementing a plan package, update any outdated test or fixture
instructions in that section to follow this strategy. Keep distinct acceptance
requirements, but do not recreate superseded fixture layouts or historical test
counts. Record the selected coverage and actual results in the plan.

The branch is an active development checkout, not a router release; router
runtime acceptance and stable promotion remain separate gates.

> [!IMPORTANT]
> Python and these dependencies run on developer machines only. The router
> implementation uses POSIX shell with verified native tools and any documented
> Entware prerequisites. Default tests use synthetic
> fixtures and do not connect to a router or Cloudflare.

## 🚀 Set up the environment

Use macOS or Linux with Python **3.11 or newer**, Git, and ShellCheck. The initial
environment is verified on macOS Big Sur with Python **3.14.0**; the Python floor
is a tooling requirement, not a claim that every interpreter/OS pair was tested.

```sh
git clone --branch develop https://github.com/XxUnkn0wnxX/CFMgr.git
cd CFMgr
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m pip check
```

For an existing checkout, start with the virtualenv steps. Reuse a healthy
`.venv`; project packages do not belong in the system Python installation.
For a fork, substitute your fork's clone URL and include its `develop` branch
with the current source and `.github/workflows/checks.yml`.

| Tool | Selected version | Purpose |
| --- | --- | --- |
| pytest | 9.1.1 | Tests and fixture lifecycle |
| pytest-xdist / execnet | 3.8.0 / 2.1.2 | Optional bounded local pytest workers |
| Ruff | 0.16.10 | Python lint and formatting |
| shfmt | 3.7.0, through `shfmt-py==3.7.0.1` | POSIX shell formatting; verified on Big Sur |
| ShellCheck | 0.11.0 on the initial host | Shell static analysis; separate host executable |

`requirements-dev.txt` pins the Python tools and pytest dependencies. `shfmt` is
installed in `.venv/bin`; the check command selects it automatically. The older
formatter version is deliberate for the development host's compatibility.

<details>
<summary>Install ShellCheck if it is missing</summary>

Check first:

```sh
shellcheck --version
```

On a Homebrew host, install it with `brew install shellcheck`. On Debian/Ubuntu,
use `sudo apt-get install shellcheck`. These are developer-machine commands,
not router prerequisites. An alternative binary can be selected with
`python tools/check.py --shellcheck /path/to/shellcheck`.

</details>

### GitHub CLI and fork setup

Install [GitHub CLI](https://cli.github.com/) if you want to publish or manage
pull requests and inspect Actions from the terminal. Authenticate once, then
check the active account and repository routing:

```sh
gh auth login
gh auth status
git remote -v
gh repo set-default --view
```

If `gh` has no default, or points to the upstream repository when you intend to
inspect your fork, use `gh repo set-default OWNER/REPOSITORY` with your actual
fork. This selects the repository for GitHub CLI operations; Git pushes still
follow Git's remote configuration. Check both before publication. Local checks
do not require `gh`, GitHub authentication or a configured remote.

Enable Actions in the fork's **Actions** tab if needed. Workflows in forks are
disabled by default; repository or organization policy can also restrict them.
[GitHub's fork workflow documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflows-in-forked-repositories).

## Entware dependency backend tests

`modules/helpers/bootstrap.sh` delegates selected dependency installation to the existing
Entware opkg. Test it with inert executable doubles under an explicit fixture
root; never invoke host/router opkg, fetch feeds or install packages in tests.
Assert exact update/install arguments, selected-only packages, healthy no-op,
usable alternative providers, failure and post-check handling, and a later
invocation's retry. Keep one actual BusyBox representative. No direct-IPK,
archive-layout, pinned package-version or synthetic library-closure matrix is
needed for this backend.

The separate internal `cfmgr_bootstrap_reinstall` entry always requests an
update followed by `opkg --force-reinstall install` for all selected direct
packages, then checks their capabilities. Its tests also prove that healthy
tools do not bypass an explicit reinstall and that failed update/install steps
stop the sequence. Opkg owns dependency resolution and package conflicts.

Routine Entware upgrades remain user-managed through amtm/opkg. The normal
backend never runs a blanket upgrade or force-reinstalls healthy dependencies:
it probes mapped requirements, returns immediately when they are usable, and
refreshes package lists only when installation is needed. The selected install
lets opkg resolve required transitive dependencies. The internal explicit
dependency-reinstall backend is separate and force-reinstalls the selected
direct requirements; its advanced menu wiring remains planned. Cloudflared
binary updates and its service/watchdog lifecycle are managed independently.

The backend requires an already admitted, serialized caller with usable mounted
Entware and suitable scheduling. Mount/authority/ownership and aggregate worker
behavior remain separate integration acceptance gates. Its fixture root proves
command policy and capability handling, not storage or router acceptance.
`--doctor`/`--diagnostic` remain native without Entware; their existing fixtures
must prove that neither opkg nor unverified package executables are called.

The source-only `cfmgr_native_dependencies ROOT BOOTSTRAP_SOURCE ACTION SCOPE
LOCK_PROVIDER` handoff runs that existing backend only after its caller supplies
the trusted immutable bundle source and the already admitted native-config root,
retained Opt authority, serialization and deadline. It accepts finite repair,
reinstall, scope and lock selectors; it is not an operational CLI or worker.
The caller must supply no application descriptor above FD9. The child closes
FD3–9, including FD6 before bundled code, receives detached stdin, and returns
an exact status record that must agree with its direct exit before evidence is
published. Uncertain post-start
work returns 129 and leaves evidence for its owner; checked root/Opt teardown
remains a separate completion requirement. The backend preserves normal opkg
feeds, locking, temporary selection and package-configuration behavior. It
clears `TMPDIR`, but configured opkg `tmp_dir` may still direct scratch writes
outside the private tmpfs quota.

`tests/test_native_dependencies.py` composes this handoff with the actual
`modules/helpers/bootstrap.sh` backend and inert opkg/capability programs. It
covers healthy no-op, missing-only repair, selected reinstall, ordinary failure
and post-check failure, source/result framing, exit/result agreement, writer
failure, descriptor closure and a 32-KiB package write. Its focused run with
`tests/test_native_shell.py` and `tests/test_bootstrap.py` passed 72 tests with
three local BusyBox skips in 36.67s; the 26 kernel-runner checks passed in
1.04s. Run these host checks with:

```sh
python -m pytest tests/test_native_dependencies.py tests/test_native_shell.py tests/test_bootstrap.py
```

The accepted 44% checkpoint passes the full local check with 1,734 tests and 33
explicit platform skips in 790.73s, including all static checks. Linux/BusyBox
passes 1,767 tests with no skips in 131.28s; all ten kernel scenarios pass,
including native-root in 7.55s and native-probe in 10.19s. The six stripped-ash
checks pass in 7.21s. See the [green Linux/BusyBox run](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37987932713)
and [PLAN.md](../PLAN.md) for the full checkpoint record.

The 28 focused kernel-runner tests pass in 1.79s. Two compile
the actual descriptor witness once and check 13 argument/descriptor cases
without chroot or privileged operations. They require a host `cc` executable
and report explicit skips when it is absent; Linux CI supplies the compiler.
This is a developer-test dependency, not a router requirement. Synthetic
stand-ins do not run Entware opkg or prove package provenance, firmware ABI or
router acceptance.

### Source-only serialized dependency worker

The accepted 45% checkpoint adds `modules/helpers/dependencies.sh` with a finite
fourteen-argument internal API. It admits only the actual original shell's
dedicated process group, detaches standard streams and application descriptors,
then takes the existing stable CFMgr dependency lock before its armed deadline.
An exact persistent active-owner marker prevents another CFMgr attempt after
uncertain owner death even if that lock is free. The worker composes the existing
retained-storage, native-config-root and dependency-backend paths, accepts only
matching exact backend evidence plus checked root/storage cleanup and watchdog
acknowledgement/reap, then releases only its own marker while still holding the
lock. The existing opkg scratch and package-configuration policy is unchanged.
The IO resolver adds a finite `rmdir` tool lookup; its capture allowlist is
unchanged. See the [architecture contract](architecture.md#source-only-serialized-dependency-worker)
for argument, status and recovery details.

The checkpoint also adds an eleventh genuine Linux fixture composition for the
lock, deadline, retained-Opt/root and synthetic normal-opkg path. Its assertions
cover the watchdog's own descriptors (including FD7/high aliases),
completion/reap before owned-marker release, and the stable lock. This new
scenario passes in 8.86s. The 45% checkpoint's full serial local check
passes 1,758 tests with 34 explicit platform skips in 836.10s; all static checks
pass. That is 5.7% above the prior local run, with no new case among the slowest
20. Exact commit `4c59937503f7e984268cdb5c75c8b144f8cc7309` passes
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37994019737):
1,792 tests with no skips in 102.36s, six stripped-ash cases in 6.89s, and all
eleven kernel scenarios. Native-root takes 5.84s, native-probe 8.14s, and total
namespace execution 27.30s. The job takes 3m15s. CI's ShellCheck 0.9.0 and the
local 0.11.0 both accept the explicit fixture assertions.

The focused worker contract suite passes 23 host cases with one explicit local
BusyBox skip in 4.05s. It distinguishes completed backend outcomes from unproved
cleanup and premature exits, and checks retained foreign/partial markers. One
real process-group death case proves that a live child can outlast the owner
while the marker blocks a fresh attempt after actual lock reacquisition.
Storage, root and deadline boundaries are otherwise narrow synthetic seams;
their complete Linux composition is established by the separate kernel gate.

The worker fixture set distinguishes cheap process-record checks from the
Linux/BusyBox lifecycle cases. Keep deadline, signal and real process-group
coverage in the focused worker tests; architecture documents the runtime
contract, and the fixture guide describes kernel evidence.

### Root lifecycle test coverage

The root lifecycles and their current boundaries are documented in
[architecture](architecture.md#-current-implementation). The host fixtures exercise
ownership, exact child ledgers, checked teardown, IO cleanup and retained-guard
failure. The Linux kernel lane supplies mount-enforced evidence; see the
[test-fixture guide](../tests/fixtures/README.md) for scenario coverage and its
limits. Neither proves router acceptance or supplies an operational worker.

The current `cfmgr_isolation_native_config_root_with` entry is the fixed
six-file composition over the retained-Opt/device lifecycle. Host coverage in
`tests/test_native_devices.py` and `tests/test_entware_root.py` checks literal API
selection, pre-bind staging failure, exact bytes, cleanup and preserved device/Opt
behavior. The actual BusyBox composition is in `tests/test_native_root.py`; its
local consumer was explicitly skipped because BusyBox was unavailable. Focused
and full checkpoint evidence is in [PLAN.md](../PLAN.md). The composed root
passes local and Linux/BusyBox validation; focused checks do not replace the
full checkpoint.

`tests/test_native_shell.py` checks the fixed shell probe with an inert chroot
stand-in, real descriptor observations, exact environment/arguments, bounded
output, caller-state preservation and uncertainty propagation through the real
root lease. Its BusyBox case exercises actual ash separately. Use
`python -m pytest tests/test_native_shell.py tests/test_check_kernel.py` for the
focused launch/runner checks; these unprivileged tests do not perform chroot or
prove router execution. The kernel scenario described below supplies that
separate host execution evidence.

`tests/test_native_opkg.py` checks the fixed `opkg --version` comparison with
independent expected response bytes, printable-version boundaries, literal
metacharacters, separate evidence, and pre-effect refusal and completed-negative
outcomes. It proves the child receives only `--version`, not the expected value,
and that the opkg probe does not invoke `/bin/busybox`. Its single actual-BusyBox case
batches invalid values and one successful 128-byte version. Run
`python -m pytest tests/test_native_opkg.py` for these host checks. The focused
O9c consumer run passed 71 tests with two local BusyBox skips; the kernel runner
selection passed 26 cases. These host tests do not establish opkg provenance or
package execution.

`tests/test_native_probe.py` checks the source-only worker composition with
fresh markers and narrow storage/root/deadline seams. It verifies fixed
ten-argument routing, arm/acquire/probe/cleanup/acknowledgement order, clean
probe results, caller-state preservation and uncertainty refusal, including an
early `exit 0` through the completion guard. Run it with
`python -m pytest tests/test_native_probe.py`; these host tests do not repeat the
real root/deadline lifecycle or establish firmware behavior.

## 🧪 Run checks

From the repository root with `.venv` active:

```sh
python tools/check.py
```

This checks installed dependencies, Python lint/formatting/compilation, discovered
shell syntax, ShellCheck, `shfmt`, and pytest. It recognizes `.sh`, `.sh.in`, and
extensionless shell entry points. Scratch, virtualenv, cache, and symlinked
source paths are excluded. The first native library, `modules/lib/common.sh`, provides
pure parsing helpers; it does not install or start CFMgr.

`tools/check.py` locates the checkout from its own file, so a fork can use a
different owner, repository name or directory, including spaces. It has no
hardcoded GitHub repository, remote or branch and does not commit, push or wait
for CI. Its selected executable paths are configurable; the same runner is used
by the checked-in workflow.

The runner defaults to two local pytest workers (`--jobs 2`), using standard
[pytest-xdist distribution](https://pytest-xdist.readthedocs.io/en/stable/distribution.html).
Worker crashes fail the run without automatic restart. Use `--jobs 1` for a
serial full check; direct focused pytest commands remain serial unless explicitly
given parallel options. The paired representative trial and full-suite acceptance
are recorded in the plan; neither mode skips tests or changes their
per-invocation deadlines.

| Task | Command |
| --- | --- |
| Full host test suite | `python -m pytest` |
| Full checks with two pytest workers | `python tools/check.py --jobs 2` |
| Focused subprocess regressions | `python -m pytest tests/test_harness.py` |
| Filter tests by behavior | `python -m pytest -k cleanup` |
| Python lint | `python -m ruff check tests tools` |
| Python format check | `python -m ruff format --check tests tools` |
| Apply Python formatting | `python -m ruff format tests tools` |
| Compile Python helpers | `python -m compileall -q tests tools` |
| Save test evidence locally | `python -m pytest --junitxml=.tmp/tests.xml` |

Create `.tmp/` before writing local reports. `.venv/`, `.tmp/`, `tmp/`, and tool
caches are ignored. A passing host run does not establish router support.

### BusyBox checks

When a working BusyBox executable is available on the **development machine**:

```sh
python tools/check.py --busybox /path/to/busybox
```

Explicitly requesting a missing or invalid executable fails the run. Without
one, dedicated BusyBox tests are visibly skipped and compatibility remains
unverified. An unavailable local Linux/BusyBox environment is missing evidence,
not a successful compatibility run.

Currently this option exercises BusyBox shell syntax and the dedicated
shell/applet fixture. Ordinary `router` fixtures still use the host `/bin/sh`;
it does **not** silently rerun the whole suite under BusyBox. A modern full
BusyBox build also does not reproduce a router's stripped older build.

The dependency-lock case requires a real BusyBox `flock` applet as well as
BusyBox `ash`. Some distribution builds omit `flock`; Ubuntu 24.04's packaged
BusyBox is one such build. Supply a supplemental BusyBox binary containing
that applet when necessary:

```sh
python tools/check.py --busybox /path/to/busybox --busybox-flock /path/to/busybox-with-flock
```

With `--busybox-flock`, the supplemental binary provides only the lock test's
`flock`; the primary binary still provides its shell and existing applet checks. A missing or
invalid explicitly selected binary, or a build without the required applet,
fails rather than silently substituting another implementation or skipping the
lock evidence. Without a supplemental selection, the lock case requires
`flock` in the primary BusyBox.

### Isolated Linux kernel checks

The explicit kernel lane requires a disposable Linux development runner, root,
util-linux `unshare`, dynamically linked BusyBox, OpenSSL, GCC/binutils, `ldd`
and glibc development files. Its
temporary source directory must reside on ext2/3/4. Run it separately from pytest:

```sh
sudo -n .venv/bin/python tools/check_kernel.py --busybox /usr/bin/busybox
```

The command never elevates itself. Missing prerequisites fail the requested
check. It creates disposable mount/PID namespaces before mounting private RAM
or exercising BusyBox bind/unmount/chroot operations. It uses no loop devices
and never connects to a router. Normal host checks remain unprivileged.
Namespaces and the C compiler contain and build the developer fixtures; they
are not added router runtime dependencies.

The lane exercises the runtime's native BusyBox capability selection directly.
Before creating mounts, the owner reads bounded `umount --help` output and
selects `-D -n PATH` for the older loop-release default or `-n PATH` for the
newer opt-in behavior. Unknown or conflicting help fails before any bind.
Both forms retain ordinary unmount without loop detach or mtab writes; a failed
unmount has no alternate-flag retry. There is no test-only syntax adapter.
The [compatibility guide](compatibility.md#busybox-unmount-capabilities) records
the firmware evidence and upstream behavior change.

The kernel lane contains eleven accepted bounded namespace scenarios,
including the dependency-worker composition described above. The original nine
cover actual BusyBox mount lifecycle, fixed native views, readonly staged `/etc`,
the quota tmpfs, retained Opt and device-node cleanup. The native-config-root
scenario checks all six staged files, including a binary CA bundle larger than
128 KiB, with native BusyBox `dd` and `cmp`. The tenth composes the fixed native
probe with the real deadline and root/chroot cleanup. The O9b baseline passed all
ten scenarios at 42% in the
[Linux/BusyBox checkpoint](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37973995819)
at `ffc3782`.
The kernel fixture substitutes a synthetic FD8 storage observation and a
controlled FD9 source, so it does not prove router storage admission or
acceptance. The accepted 41% scenario also invokes the fixed shell probe
through genuine host BusyBox/loader bytes. The O9c extension adds a trusted
synthetic static opkg stand-in to the ninth scenario; it witnesses fixed argv,
clean environment and cwd, closed inherited descriptors, and reading the
retained Opt marker. It does not run Entware opkg. Only a private fixture copy's
interpreter path is adapted to the existing `/lib` view, with structural and
`readelf` verification; static
fixture wrappers inspect descriptors before forwarding to real chroot/applets.
No firmware executable is copied or run. The tenth scenario adds the source-only
worker's real deadline and checked root/probe cleanup, observes the watchdog's
own descriptors, and uses synthetic storage acquisition; it does not prove
outer storage IO acquisition or physical block-device/UUID admission. The 43%
full local run passed 1,707 tests with 32 explicit platform skips in
904.87s; [Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37977771431)
passed 1,739 tests with no skips in 108.91s. Six stripped-ash cases passed in
7.05s. All ten kernel scenarios passed: `native-root` took 6.17s and the
unchanged `native-probe` 8.79s; namespace execution took 19.66s and the kernel
command 20.98s. CI ran the actual BusyBox opkg grammar representative. These
synthetic host/Linux results do not prove real opkg installation, executable
provenance, Entware/ARM ABI or Merlin acceptance. The selected future repair path
is normal installed-opkg operation using configured feeds and dependency
resolution, with CFMgr's own serialization, deadlines, storage checks and
post-checks. Its lock cannot exclude unrelated writers or guarantee preservation
of unrelated half-installed packages; no custom foreign-state veto or additional
package manager is planned. The O9c probe does not perform repair. The kernel
suite remains developer-host evidence only. See
[PLAN.md](../PLAN.md)
for the full checkpoint record and the
[test-fixture guide](../tests/fixtures/README.md) for scenario-level evidence
and limits.

### Linux CI

The [Checks workflow](../.github/workflows/checks.yml) runs on code, test and
tooling changes pushed to `develop` or proposed in pull requests targeting
`develop`. Documentation-only changes skip CI. It uses Ubuntu
24.04, Python 3.14.0 in a virtualenv, the pinned Python requirements and the
runner's packaged BusyBox/ShellCheck. It invokes the same check command with
`--busybox /usr/bin/busybox`, so missing BusyBox is a failure rather than a skip.
It also builds a small BusyBox 1.36.1 from the official archive with a pinned
SHA256, using the existing host compiler and two build jobs. That binary supplies
`flock` through `--busybox-flock`, preserving real descriptor-inheritance coverage
despite Ubuntu's disabled applet. It additionally includes ash, arithmetic and
the few applets needed by the focused fixtures. Its ash deliberately disables
`command`, job control and the printf/test/echo builtins, matching those specific
firmware configuration constraints. A separate focused run exercises the worker,
bootstrap, closure and supervision BusyBox consumers with that shell. This is
configuration evidence on a newer BusyBox, not a full reproduction of Merlin's
patched build. Neither binary replaces router tools.
The separately named kernel step runs the explicit namespace proof afterward.
Tool versions and kernel-case timings are printed in the job log.

The workflow has read-only repository permissions and no router or provider
credentials. Linux/BusyBox results complement the Mac checks; they do not prove
Merlin firmware, 32-bit arithmetic or hardware acceptance. Current milestone
counts and timings belong in the plan rather than this contributor workflow.

The initial CI scope is one Linux/BusyBox job. Matching Merlin's patched kernels
or exercising older ARM/32-bit environments would need additional dedicated
infrastructure and acceptance cases; a hosted runner's kernel is not a router
kernel compatibility matrix.

All contributions target `develop`; see [CONTRIBUTING.md](../CONTRIBUTING.md).

At a major checkpoint, pass the local runner first, then push eligible code
changes to the fork's `develop` branch. That push starts Actions independently;
GitHub does not wait for a local process. An already-pushed change may therefore
have a CI run before the local checks finish. Documentation-only pushes do not
start this workflow, and rerunning local checks without a push does not trigger
Actions. Pull requests use the same code filters and must target `develop`.

## 🧱 Test structure

The runtime entry point is `cfmgr.sh`. The current native health report is
`modules/diagnostic.sh`; shared shell/awk code is under `modules/lib/`, and
supporting bootstrap and worker code is under `modules/helpers/`. Firmware hook
templates are reserved for `modules/hooks/`, which currently contains no hooks.
Files are sourced or invoked explicitly; there is no arbitrary directory
autoloader. Runtime files are not compiled into a main executable. The Python
compilation check validates developer tooling only. The planned installed entry
is `/jffs/scripts/cfmgr.sh`, with modules and `catalog.txt` under
`/jffs/addons/CFMgr.d/`.

| Path | Responsibility |
| --- | --- |
| `tests/harness.py` | Private fixture tree, explicit fake commands, bounded shell execution |
| `tests/conftest.py` | Fixtures, BusyBox selection, validation-matrix evidence reporting |
| `tests/test_harness.py` | Isolation, input/output, paths, deadlines, and child cleanup |
| `tests/test_reporting.py` | Accurate test-evidence counts |
| `tests/test_primitives.py` | Native decimal/version/digest parsing and caller-state preservation |
| `tests/test_ip.py` | Strict IPv4/IPv6 host syntax and deterministic canonical formatting |
| `tests/test_json.py` | JSON grammar, Unicode, duplicate keys, exact limits and framed output |
| `tests/test_diagnostic.py` | Diagnostic dispatch, command probes, redaction, private staging and failure cleanup |
| `tests/test_mountinfo.py` | Mount snapshot framing, escaped paths, overmount ambiguity and bind-root selection |
| `tests/test_io.py` | Private staging, stream bounds, producer status, signal cleanup and complete mount handoff |
| `tests/test_io_hex.py` | Independent byte-grammar oracle for hex/path validation, including misleading matches between byte boundaries |
| `tests/test_bootstrap.py` | Healthy no-op, missing requirements, post-probes and explicit Entware reinstall through inert executables |
| `tests/test_storageinfo.py` | Native mount-ID/UUID observations, exact framing and ambiguous disk-label refusal |
| `tests/test_storage.py` | Held-descriptor observation, before/after identity checks and rejection without publication |
| `tests/test_isolation.py` | Focused ownership/cleanup faults plus representative complete lifecycle fixtures |
| `tests/isolation_helpers.py` | Shared focused mount-query fixture; full-capture consumers remain separate |
| `tests/test_execution_root.py` | Readonly-root ownership, descriptor lease, retained guards and complete versus uncertain cleanup |
| `tests/test_native_config.py` | Legacy fixed-file staging plus direct extended staging and its actual BusyBox consumer |
| `tests/test_native_config_extended.py` | Opaque byte limits, same-descriptor EOF checks, producer/cmp failures, partial retention and IO cleanup admission |
| `tests/test_native_shell.py` | Fixed shell admission, clean environment, descriptors, byte framing and retained uncertainty through the root lease |
| `tests/test_native_probe.py` | Fixed worker ordering, authority routing, cleanup gates, caller-state preservation and uncertainty markers |
| `tests/test_native_opkg.py` | Fixed installed-opkg version comparison, API boundaries, separate evidence and completed-negative outcomes |
| `tests/test_native_root.py` | Native root identity/cleanup and the actual BusyBox six-file retained-Opt/device composition |
| `tests/test_native_observation.py` | Real descriptor metadata, inode relationships, symlink failures and retained descriptor usability in host fixture tools |
| `tests/test_native_data_root.py` | Native-data composition before bind, exact staged bytes, query budget and checked teardown |
| `tests/test_native_tmp_root.py` | Canonical quota validation, tmpfs identity/options, private HOME and cleanup retention |
| `tests/test_entware_root.py` | Retained Opt-root success, busy-Opt cleanup refusal and malformed API rejection |
| `tests/test_entware_root_admission.py` | Cheap framing and storage-admission boundary cases |
| `tests/test_native_devices.py` | Fixed node metadata, inode retention, mount lifecycle, busy cleanup faults and literal extended-policy selection |
| `tests/fixtures/kernel/` | Controlled shell/C fixtures for Linux namespace proof, including six-file staging, retained Opt, fixed devices, quota-limited tmpfs and private HOME |
| `tests/fixtures/` | Synthetic or reviewed sanitized data only |
| `tools/check.py` | One host validation entry point |
| `tools/check_kernel.py` | Explicit Linux/root kernel proof, separate from normal pytest |
| `pytest.ini`, `ruff.toml` | Discovery, markers, and Python style |

Ordinary router-harness fixtures have their own `jffs`, `opt`, `ram`, `home`, `bin`, and working
directories. Subprocesses receive an explicit environment and fake-only `PATH`;
inherited tokens, proxy settings, and shell startup overrides are absent. Tests
must explicitly expose any real executable they need.

<details>
<summary>Harness limits and process safety</summary>

- Fixture files and stdin are limited to 64 KiB; combined captured stdout/stderr
  is limited to 128 KiB.
- A shell action defaults to a three-second deadline, configurable up to sixty
  seconds. Cleanup targets only its created process group.
- Paths passed through fixture helpers reject absolute paths, parent traversal,
  and symlink components. Private directories/files use `700`/`600` modes.
- Cleanup covers timeout, output overflow, normal exit with background children,
  and interruption. Darwin exit-transition handling must not hide a genuine
  permission failure.
- This is **not an OS sandbox**. Trusted test code can still use absolute paths,
  network syscalls, or descendants that deliberately leave the process group.
  Helper limits do not bound arbitrary writes by such code or prove router
  process-identity safety.
- The full suite has no arbitrary 120-second cutoff that could kill pytest
  while it is cleaning up separate child sessions. Individual shell actions
  remain bounded; static tool invocations have a separate deadline.

</details>

### Runtime contract references

Runtime behavior and bounded input contracts belong in the
[architecture guide](architecture.md#bounded-parser-and-io-contracts); firmware
and native-tool evidence belongs in the [compatibility guide](compatibility.md).
The test map above points to the focused parser, storage, IO and lifecycle suites.
Use those tests to check a changed contract, then run the full check at the
required checkpoint. Keep native diagnostics separate: their usage and host
fixture command remain below.

### Native health report

The local development entry supports `--help`, `--version`, `--diagnostic` and
its identical alias `--doctor`. This first report tests native command
capabilities; it is not an installable manager or a complete health check yet.
Exercise it through the isolated host fixtures:

```sh
python -m pytest tests/test_diagnostic.py
```

The planned report extends choice **0) Check status** with platform information,
dependency inventory and command checks. The current stage reports feature
status and Entware checks as unavailable until their safe readers/preflight are
implemented. It does not read config, execute Entware programs, contact providers,
install packages or start services. Do not deploy this development entry to the
live router during host validation.

Each result has a stable check ID, `PASS`/`FAIL`/`SKIP`, requirement scope,
evidence level and concise reason. Availability, accepted options and a working
synthetic probe are different evidence. A skipped dependent check names its
prerequisite; an unavailable Entware mount does not mean a package is missing.
Raw command errors and sensitive identifiers are excluded from the report.

| Exit | Meaning |
| --- | --- |
| `0` | Every required check was evaluated and passed. |
| `1` | A required capability or owned-stage cleanup failed. |
| `2` | Invalid command or arguments. |
| `3` | Required checks are incomplete, with no observed required failure. |
| `129`, `130`, `143` | Interrupted by HUP, INT or TERM respectively. |

A healthy first-stage fixture returns **3** because mount/dependency checks are
deferred. Optional failures, such as unsupported `command -v`, do not fail the
whole report when CFMgr uses a different lookup method.

<details>
<summary>Probe isolation and current limits</summary>

Synthetic probes use a newly created private RAM directory and bounded captured
output. Cleanup only removes that owned directory, including on handled signals;
colliding pre-existing paths are left alone. Native command paths and locale are
fixed, and OpenSSL configuration/module overrides are isolated.

The report is not yet connected to the guarded deadline controller. It tests
finite local operations and leaves flock contention untested.
The curl check verifies option parsing only; it makes no HTTPS request. Host
fixtures and optional BusyBox-shell checks do not establish deployed-router
acceptance. Future runtime changes must extend this inventory and its tests.

</details>

## 🔎 Evidence and stage commits

Mark meaningful tests with the corresponding validation IDs from `PLAN.md`:

```python
@pytest.mark.integration
@pytest.mark.matrix("V43", evidence="harness")
def test_observable_behavior(router):
    ...
```

Allowed evidence levels are `harness`, `host`, and `busybox`. Unknown IDs or
missing evidence labels fail collection. The summary reports counts, **not** a
verdict that an entire validation-matrix row has passed. Router observations and
acceptance results are recorded separately in the plan.

Develop on `develop`. For each coherent stage, review the affected contracts,
implement and test normal/failure paths, run the relevant checks, and update the
plan before committing. Explain changes to existing test expectations; preserve
the behavior being tested. Do not mask safety failures with skips or `xfail`.
Publish completed code, tests, documentation and requirements to `develop` at
major checkpoints after the full local suite passes, then require green CI
before the next set of batches. Keep the README's
explicit active-development warning until router runtime acceptance is complete.
Never include an unfinished worker's changes in a passing-stage commit. Stable
promotion and live deployment still require separate authorization.

## 📦 Module catalog and forks

Catalog and config generation are still planned; there is no installable manager
or user command yet. The catalog selects one repository snapshot, and each
relative destination must preserve its nested path under the installed manager.
For example:

```text
# main is the default; develop or a full 40-character commit hash is also valid.
branch: main
lib/common.sh https://raw.githubusercontent.com/XxUnkn0wnxX/CFMgr/{commit}/modules/lib/common.sh
```

`{commit}` is replaced by the validated snapshot hash. Keep fork entries in one
repository and use that same placeholder so every module comes from one immutable
snapshot. Preserve existing catalog bytes on developer checkouts according to the
[architecture contract](architecture.md#-modules-and-forks). The example is not a
complete package manifest or an available install/update workflow; detailed
implementation gates remain in [PLAN.md](../PLAN.md).

## 🧭 Compatibility and documentation

Check [compatibility evidence](compatibility.md) and [PLAN.md](../PLAN.md) before
choosing firmware-specific primitives. The compatibility guide records the
bounded three-image audit, its source/cache instructions and the distinction
between static evidence, host/CI behavior and router acceptance. Reuse the
ignored `.tmp/firmware-audit/INDEX.md` rather than repeating extraction; never
commit its archives, images, extracted data, certificates or raw reports.

Dependency backend tests and policy are described above; actual startup,
install/update/reinstall and worker lifecycle wiring remain separate stages.
Router access stays read-only during development. Host checks and CI do not
authorize installation, service changes, provider writes or router acceptance.
At milestones, review all guides and record intentionally unchanged files in the
plan.
