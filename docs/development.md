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

After completing milestone implementation at 60%, 70%, 80%, 90% and 100%,
review every test, including parametrized cases and shared fixtures, for further
optimization. Make justified improvements before the final full-suite,
publication, green-CI and handoff gate. Record the reviewed inventory, preserved
coverage, timing changes and reasons for retaining expensive cases in PLAN.md.
This complete review supplements the cost review before every push.

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
The worker uses the IO resolver's finite `rmdir` lookup; `rmdir` is not a
capture command. See the [architecture contract](architecture.md#source-only-serialized-dependency-worker)
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

The source-only `modules/lib/config_header.awk`, `catalog.awk` and
`manifest.awk` validate bounded data formats. Callers explicitly load the
functions-only `modules/lib/package_path.awk` helper before either catalog or
manifest parser; no automatic helper loading is provided. Source-only native
report and declared-file verification APIs are described below; neither is
connected to a config reader, catalog consumer or installed workflow. Full
schema/defaults, config ownership, migration, activation and writes remain
future work. There is no generated defaults file, config writer, shipped
catalog or manifest, authenticated manifest acquisition, downloader or installer.

### Configuration-header projection

`config_header.awk` consumes the existing `json.awk` token format from
independently measured, immutable regular-file stdin. Its caller supplies
`LC_ALL=C`, zero operands and canonical `cfmgr_config_header_size` from 1 to
131,072 bytes. It requires exact input length and final LF, consecutive token
IDs, valid container ancestry/preorder, valid typed locations and payloads,
unique object keys, and exact producer footer counts. The root object must have
exactly one top-level `schema` with the JSON number lexeme `1`, a canonical
`generation` from 0 to
2,147,483,647, and a boolean `developer` field. Nested keys do not substitute.
Other fields remain structurally checked but opaque; their values and
credentials are never returned or approved. Output is exactly
`config-header<TAB>1<TAB>GENERATION<TAB>BOOLEAN<LF>` followed by
`end<TAB>BODY_BYTES<LF>`; it contains no other setting values.

Invocation/size errors return 2 and malformed data returns 1; valid projection
returns 0. The caller must still verify the JSON producer's status and exact
consumer output/footer bytes because AWK may not report an output-write failure.
This projection does not establish complete settings validity, credential
semantics, defaults or config ownership. The existing IO capture limit remains
65,536 bytes: this standalone 131,072-byte parser bound does not widen it or
provide a working large-config reader.

### Source-catalog grammar

`catalog.awk` is called with the helper loaded explicitly first. For example,
after independently measuring the exact byte count as `$size` and opening that
same immutable regular file on stdin:
`LC_ALL=C awk -v cfmgr_catalog_size="$size" -f modules/lib/package_path.awk -f modules/lib/catalog.awk <catalog.txt`.
It accepts zero operands and canonical `cfmgr_catalog_size` from 1 to 32,768
bytes. Input must be printable ASCII with LF line endings and a final LF; blank and `#` comment
lines are allowed, while tabs, CR, NUL, non-ASCII and lines over 1,024 bytes
are rejected. Metadata keys are unique and limited to `catalog`, `repository`,
`branch` and `manifest`, all required exactly once with exact `catalog: 1`.
Other keys are file destinations and must follow the file rules below. The
repository is one `https://github.com/OWNER/REPO` value; owner is 1–39
alphanumeric/hyphen characters with alphanumeric ends, and repository is 1–100
ASCII alphanumeric/dot/underscore/hyphen characters starting alphanumeric.
Branch is `main`, `develop` or a full 40-digit hexadecimal commit, normalized
to lowercase. The manifest and each file URL must use the same case-sensitive
owner/repository and the fixed
`https://raw.githubusercontent.com/OWNER/REPO/{commit}/SAFE_PATH` form.
Arbitrary hosts, ports, credentials, queries, fragments and escaped paths are
rejected.

`package_path.awk` contains no input, `BEGIN` or `END` actions and defines only
the explicitly called `cfmgr_package_path_safe`,
`cfmgr_package_destination_safe` and `cfmgr_package_path_conflicts` functions.
Paths are source-relative: 1–240 bytes total, 1–100 bytes per component,
ASCII alphanumeric/dot/underscore/hyphen characters with an alphanumeric first
character, no empty components and no absolute or trailing slash. Package
destinations are exactly `cfmgr.sh` or below `modules/`, excluding
`modules/config`, `modules/catalog.txt` and their descendants. A conflict means
equal paths or an ancestor/descendant pair; each parser also rejects duplicate
destinations.

Entries use exact `KEY: VALUE` syntax with nonempty, unpadded values. One to 128
unique file entries are required, including exactly `cfmgr.sh`. Other
destination keys must be safe relative source paths below `modules/`; each
component is 1–100 ASCII alphanumeric/dot/underscore/hyphen characters starting
with an alphanumeric, and the full path is at most 240 characters. Empty, dot
and dot-dot components, absolute paths, traversal, ancestor/descendant
collisions, and the reserved `modules/config` and `modules/catalog.txt` paths
and their descendants are rejected. These keys name repository files, not
installed destinations: a future owner maps `cfmgr.sh` to the scripts entry and
strips the `modules/` prefix under the established installed manager directory.
A URL's safe source path is validated separately and may differ from its
destination key. The accepted catalog input rules and projection bytes are
preserved after extracting the shared path functions.

The parser preserves file-entry order and emits `catalog<TAB>1`,
`repository<TAB>OWNER<TAB>REPO`, `branch<TAB>REF`, `manifest<TAB>URL`, then
`file<TAB>DEST<TAB>URL` records and `end<TAB>FILE_COUNT<TAB>BODY_BYTES`; the
output cap is 65,536 bytes. Invalid invocation returns 2,
invalid catalog data returns 1, and a valid projection returns 0. Callers must
verify parser status and exact output framing. This is source selection syntax
only; it does not read or trust the manifest, verify hashes/completeness, resolve
a branch or download/write/package anything.

The following is a complete synthetic format example that satisfies the
parser's grammar. Its example owner/repository and paths are illustrative; it
is not a published catalog or downloadable package:

```text
catalog: 1
repository: https://github.com/ExampleOwner/ExampleRepo
branch: main
manifest: https://raw.githubusercontent.com/ExampleOwner/ExampleRepo/{commit}/manifest.txt
cfmgr.sh: https://raw.githubusercontent.com/ExampleOwner/ExampleRepo/{commit}/cfmgr.sh
modules/lib/common.sh: https://raw.githubusercontent.com/ExampleOwner/ExampleRepo/{commit}/modules/lib/common.sh
```

### Bounded package-manifest grammar

`manifest.awk` is called with the same explicit helper-first order. For
example, after independently measuring the exact byte count as `$size` and
opening that same immutable regular file on stdin:
`LC_ALL=C awk -v cfmgr_manifest_size="$size" -f modules/lib/package_path.awk -f modules/lib/manifest.awk <manifest.txt`.
The caller supplies zero operands and canonical `cfmgr_manifest_size` from 1
to 65,536 bytes. The parser checks the declared byte count and final LF. Input
is printable ASCII plus LF, with lines up to 1,024 bytes; blank lines and
comments beginning with `#` in column zero are allowed. Records use exact
`KEY: VALUE` syntax, with unique required metadata in any order: `manifest: 1`,
`version: MAJOR.MINOR.PATCH`, `config-schema: 1` and `package-api: 1`.

The version is 5–128 bytes and has exactly three canonical unsigned decimal
components. Leading zeroes, signs, prerelease labels and build suffixes are not
accepted. Components remain text; the parser does not convert long values to
machine-sized numbers or compare versions. The schema and package API numbers
select declared data versions only;
they do not establish code compatibility, migration behavior or downgrade
approval.

One to 128 file records are required, including `cfmgr.sh` exactly once with
mode `0755`; other module entries may use `0644` or `0755`. Each record is
`DEST: SIZE SHA256 MODE`, with exactly one ASCII space between the three value
fields and no extra field. Destinations use the shared package path rules and
cannot duplicate or collide as ancestor/descendant paths. Sizes are canonical
decimal values from 1 to 1,048,576 bytes, with total declared file bytes at
most 8,388,608. SHA-256 text is exactly 64 hexadecimal digits and is emitted in
lowercase. Directories and symlink records are not supported.

After validating the complete document, the parser emits `manifest<TAB>1`,
`version<TAB>VERSION`, `config-schema<TAB>1`, `package-api<TAB>1`, the file
records in input order as `file<TAB>DEST<TAB>SIZE<TAB>LOWER_SHA256<TAB>MODE`,
and `end<TAB>FILE_COUNT<TAB>TOTAL_FILE_BYTES<TAB>BODY_BYTES`. The complete
ledger is capped at 65,536 bytes. Invocation or declared-size errors return 2,
malformed data returns 1, and valid input returns 0. Future consumers must
check status, exact framing/footer and output-write completion; AWK status alone
does not prove a successful write.

The manifest is a declared inventory only. Parsing does not authenticate its
source, verify actual file bytes or installed ownership/modes, prove required
package completeness, compare it with a catalog, or authorize compatibility,
downgrade, activation or installation. A separate source-only verifier below
checks declared file bytes under explicit caller prerequisites; it does not
authenticate the manifest or prove directory completeness. The manifest must
not contain the containing commit hash: that would create a self-reference. A
future acquisition step must bind the manifest to a single already-resolved
immutable revision.
There is no generated root catalog, published manifest, downloader or
installed-package mapper. The developer inventory below writes only to stdout;
it does not publish or install the generated document.

### Source-only native manifest report

`modules/lib/package.sh` composes the existing IO owner with the trusted path
helper and manifest parser. Explicitly source trusted `modules/lib/io.sh`
before `package.sh`; the package module defines functions and does not load its
dependencies automatically. The production entry is
`cfmgr_package_manifest_report ROOT INPUT PATH_HELPER PARSER`; the explicit
fixture entry is `cfmgr_package_manifest_test ROOT TOOLS INPUT PATH_HELPER
PARSER`. The fixture entry exists for developer tests and is not a production
tool-selection interface.

`ROOT` must be the caller's trusted private RAM parent. `INPUT` must be a stable,
immutable, readable regular nonsymlink manifest. `PATH_HELPER` and `PARSER` must
be absolute paths to trusted immutable readable regular nonsymlink code, and
their ancestors and native tools must be trusted. Callers must exclude aliases
and concurrent writers. These path checks do not provide atomic admission
against a hostile filesystem, provenance or a hard deadline.

The owner makes two bounded captures: native `cat` reads the original input,
then native AWK consumes that captured input with the path helper explicitly
before `manifest.awk` under the C locale. Each capture allows at most 65,536
stdout bytes and 4,096 stderr bytes. The reader independently checks producer
status and stderr. It passes the measured raw-input byte count to AWK as
`cfmgr_manifest_size`. After parsing, it reconstructs the ordered tab-separated
ledger and checks its byte count against the AWK capture's independently
measured stdout size; this is a separate check because the normalized ledger
and raw manifest have different formats. Any nonempty AWK stderr is failure;
quiet parser status 2 remains 2. The complete canonical ledger is published
only after owner cleanup. It contains the metadata, one to 128 file records and
a checked footer; accepted declared file sizes are at most 1 MiB each and 8 MiB
total. Output may be partial if final
publication itself fails, so downstream consumers must still check status and
complete framing. The two captures use six owner files; accepted stream data is
bounded to 139,264 bytes plus status records, with a portable failure-allocation
ceiling of 528,384 bytes plus statuses. Input and process memory are additional.

The public entries return 0 for a complete report, 1 for invalid manifest or
ordinary processing/cleanup failure, and 2 for API or preflight misuse. The IO
owner's HUP, INT and TERM statuses (129, 130 and 143) remain intact. This
report API validates framing and declared fields only; it does not hash source
files. The separate verifier below checks declared bytes but has no deadline or
authentication and does not prove package completeness, install anything or
authorize a router workflow. No menu, catalog consumer or installer calls
either API.

The D4 focused gate passes 8 tests with one unavailable-BusyBox skip in 3.06s.
The full two-worker local gate passes 1,837 tests with 38 explicit platform skips
in 450.58s at source `d1bd99a`; all static checks pass. [Exact-head Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38047884781)
passes all 1,875 tests with zero skips in 139.42s at `adf5f21`, six stripped-ash
cases in 7.29s and all eleven kernel scenarios. This accepts 49%; Merlin
runtime acceptance remains separate.

### Source-only declared-file verifier

`modules/lib/package.sh` adds `cfmgr_package_verify_report RAM_ROOT SOURCE_ROOT
MANIFEST PATH_HELPER PARSER` for production callers and the explicit
fixture-only `cfmgr_package_verify_test RAM_ROOT TOOLS SOURCE_ROOT MANIFEST
PATH_HELPER PARSER`. These library functions are not connected to a CLI,
catalog, downloader, installer or router workflow. Explicitly source trusted
`io.sh`, `native_digest.sh`, then `package.sh`; the libraries do not load one
another automatically. Source `native_digest.sh` before `closure.sh` as well.
The public closure size and hash adapters retain their 0/1 results. The internal
`_cfmgr_closure_size_owned` helper preserves its existing 0/10/2/129 statuses.

A caller must first acquire the manifest and all declared files into a private,
immutable `SOURCE_ROOT`, capped at 1 MiB per file and 8 MiB total. Native `wc`
and OpenSSL read through EOF, so the verifier does not supply or prove bounded
acquisition and has no hard deadline. The root must be a canonical absolute
non-root path of at most 4,096 bytes, with no trailing/repeated slash, dot or
dot-dot component, or control byte. The root, trusted ancestors, code, native
runtime and inputs must stay immutable and unaliased, with no concurrent
writers. These checks are defensive path-shape checks, not atomic admission
against a hostile filesystem.

For every file in the already-decoded manifest, the verifier walks each source
path component without following symlinks, requires intermediate directories
and a readable regular nonsymlink file, then compares its actual size and
SHA-256 with the declaration. It processes files in manifest order and does
not capture whole files through the 64-KiB text interface; files up to 1 MiB
are streamed to native OpenSSL. Production uses fixed native `env`, `openssl`
and `hexdump` paths plus the IO owner's `wc`; missing production `hexdump`
fails verification. Explicit fixture tool selection may use BusyBox `hexdump`,
while OpenSSL remains native. The helper requires successful producers, exactly
32 binary digest bytes, exactly 64 lowercase hex bytes with no line ending, and
an exact match to the declared hash. It clears inherited loader/OpenSSL controls
and runs OpenSSL with a null configuration.

After every declared file passes, the report replaces the first
`manifest<TAB>1` line with `package-bytes<TAB>1`, keeps the other accepted
records, count and total, and recomputes the footer byte count. Modes remain
declared desired attributes: the verifier does not check actual permissions or
ownership. This establishes that listed bytes match declarations; it does not
prove that the directory contains every required file or no extra files,
authenticate the manifest/source, establish API compatibility, or authorize
download, installation or activation. Publication follows owner cleanup, but
failure during final output can leave partial stdout. Consumers must check
status and complete framing. Existing cleanup does not prove every external
child has terminated or been reaped.

The production entry takes five arguments and uses fixed native utility
directories with the IO owner's `wc`. The fixture entry takes six arguments
and inserts an explicit tools directory after `RAM_ROOT`. Both require trusted
absolute helper/parser paths and the caller-prepared files described above. A
developer caller with these prerequisites can load and invoke the API as follows:

```sh
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/native_digest.sh"
. "$CFMGR_LIB/package.sh"
cfmgr_package_verify_report "$RAM_ROOT" "$SOURCE_ROOT" "$MANIFEST" \
  "$PATH_HELPER" "$PARSER"
```

Set `CFMGR_LIB` to the trusted absolute library directory and provide the
remaining variables as validated paths. Check the function's status and the
complete `package-bytes` ledger; bytes on stdout alone do not prove success.
The fixture API is `cfmgr_package_verify_test`; it is for tests and never
selects production tools.

The verifier returns 0 for a completed report, 1 for invalid manifest/member,
size/hash/tool or processing/cleanup failure, and 2 for API, RAM-root,
`SOURCE_ROOT` or trusted-code preflight misuse. An unsuccessful native size
observation maps to verifier status 1, including size-helper uncertainty; an
IO-owner HUP, INT or TERM keeps its 129, 130 or 143 status. A failed size
observation does not become a signal result unless the IO owner itself was
signalled.

At most 262 scratch files support the maximum 128 declared members and their
digest/hex pairs. Those pairs accept at most 12,288 bytes, in addition to the
manifest-reader capture streams. The conservative portable file-allocation
ceiling is 790,528 bytes plus status files; input and process memory are
additional. The focused package run passes 14 tests with one unavailable-
BusyBox skip in 6.87s; the slowest new grouped refusal takes 1.58s. Related
closure/size runtime regressions pass 15 tests with one local BusyBox skip in
27.46s. After a path-with-spaces fixture correction, its focused regressions
pass 2 tests in 0.84s. The full local rerun passes 1,843 tests with 38
explicit platform skips in 571.13s, including all static checks. Exact-head
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38049707354)
passes 1,881 tests with zero skips in 140.52s at `c9d531a`, six stripped-ash
cases in 7.33s and all eleven kernel scenarios. The two existing Entware cases
reviewed for local timing pass a focused follow-up in 23.09s; the CI suite is
0.8% above the prior checkpoint. Runtime source `018a616` and fixture correction
`1ae5160` are accepted at the 50% handoff. These checks do not establish Merlin
runtime acceptance.

### Source-only complete-tree report

D6 adds `cfmgr_package_tree_report RAM_ROOT SOURCE_ROOT
MANIFEST PATH_HELPER PARSER` and the fixture-only
`cfmgr_package_tree_test RAM_ROOT TOOLS SOURCE_ROOT MANIFEST PATH_HELPER
PARSER`. Explicitly source trusted `io.sh`, `native_digest.sh`, and
`package.sh` in that order. These APIs are not connected to the CLI, catalog,
acquisition, installer, or activation path.

The caller supplies the same private, immutable, unaliased, bounded source tree
required by the declared-file verifier, plus its immutable manifest and
trusted parser/helper. The manifest is parsed and checked inside this call. The report derives its expected namespace only from
that manifest: the root, each declared file path, and the parent directories
needed by those files. It captures one native `find . -print` listing from
inside the source root, with link following disabled by the selected command's
default behavior. The listing is limited to 65,536 stdout bytes and 4,096
stderr bytes. The consumer requires a successful capture, producer status zero,
empty stderr, complete LF framing, matching reconstructed byte count, and each
expected path exactly once. Missing, duplicate, extra, empty-directory,
hidden-file, link, or special-file entries are refused. Expected physical
directories and files are also checked for readable/traversable or readable
regular nonsymlink shape. Entry order does not affect acceptance.
Keep the manifest and catalog outside this payload root: unlisted `.gitkeep`
files, repository metadata and other development files are also refused. The
64-KiB listing cap can reject an otherwise valid manifest with many deep
directories. This API adds no traversal deadline.

Only after namespace and all D5 size/SHA-256 checks succeed does the API emit
the `package-tree<TAB>1` ledger, retaining manifest metadata and file records
and recomputing the footer length. It uses the existing IO owner for all three
captures and cleanup before report publication. The public entries preserve
the D5 status classes: misuse returns 2, processing/input/tool/cleanup failure
returns 1, and owner HUP/INT/TERM return 129/130/143.

With the same trusted path variables used by the verifier above, a developer
caller invokes the production library entry like this:

```sh
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/native_digest.sh"
. "$CFMGR_LIB/package.sh"
cfmgr_package_tree_report "$RAM_ROOT" "$SOURCE_ROOT" "$MANIFEST" \
  "$PATH_HELPER" "$PARSER"
```

Check the function status and complete `package-tree` ledger; stdout by itself
does not prove success. The fixture API is `cfmgr_package_tree_test` and is
only for developer tests.

The namespace comparison is against the successful native listing. In matched
Merlin BusyBox source, recursive traversal does not distinguish a `readdir`
error from EOF or report `closedir` failure, so the report cannot rule out an
undeclared path silently omitted by a traversal error. Consequently it is an
additional check under the healthy private immutable-tree premise, not source
acquisition or authority to adopt an arbitrary existing tree. A future owner
must create exactly the accepted inventory. The API also does not authenticate
source, check installed permissions/ownership, establish semantic module/API
or version compatibility, acquire/download/install/activate code, or prove
Merlin runtime acceptance.

The three captures use nine scratch files; per-file digest and hex captures
add at most 256, for 265 total. Accepted capture streams are bounded to 208,896
bytes plus 12,288 digest/hex bytes; conservative file allocation is at most
1,054,720 bytes plus status files. Caller input, shell/producer memory, and
filesystem traversal remain additional. Runtime source `4082a04` with the
test-cost follow-up `5f83f6f` passes the full local checkpoint: 1,848 tests and
38 explicit platform skips in 500.19s. All static
checks pass. Exact-head
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38051496887)
passes 1,886 tests with zero skips in 123.19s at `5e40c6f`, six stripped-ash
cases in 7.19s and all eleven kernel scenarios. That CI run precedes the
test-only cost follow-up, which removes repeated Python launches for healthy
IO fixture operations. The full local run improved from 678.39s to 500.19s;
host load also affects timings. Exact CI for the follow-up and the complete
duration record are tracked in PLAN.md.

### Developer package inventory

`tools/package_manifest.py` is a host-only Python developer command. It reads
the raw Git tree and blobs at one explicit local commit and prints a canonical
package manifest to stdout. Resolve the commit once, then pass its full
40-character SHA-1 ID:

```sh
commit_id=$(git rev-parse --verify 'HEAD^{commit}')
.venv/bin/python tools/package_manifest.py --repo . --commit "$commit_id"
```

`--repo` may name an existing directory within the intended repository,
including a bare repository; when omitted, the tool uses the checkout containing
the script. It rejects non-commit or abbreviated IDs and does not follow later
branch movement or dirty worktree contents. It performs no fetch, checkout,
index update, build, Git-filter invocation or selected-commit code execution.
Git selection refuses transports, disables replacement objects and lazy
fetching, and ignores inherited repository/config redirection. Local Git objects
must already be available.

The inventory covers `cfmgr.sh` and regular files below `modules/`, preserving
their Git executable modes and hashing their raw bytes with SHA-256. The only
excluded module entries are empty, regular, nonexecutable `.gitkeep` blobs.
Unsafe or reserved destinations, unsupported Git object types or modes,
invalid package limits, and a missing or nonexecutable entry are errors. The
tool extracts exactly one canonical, literal full-line `CFMGR_VERSION`
declaration as data and validates the complete generated document with the
trusted parsers in the tool's current checkout. It never sources or runs the
selected snapshot's files.

This deterministic local inventory is not origin or release authentication,
trusted acquisition, proof of package completeness, verification of installed
file bytes or ownership, compatibility approval, activation or installation.
Consumers must separately bind it to an immutable revision and establish trust,
acquisition, completeness, lifecycle and router acceptance. The source-only
verifier above checks declared bytes only after the caller has prepared its
bounded input; it does not authenticate that input. The combined
generator/manifest/catalog focused gate passes 49 tests with two local
missing-BusyBox skips in 46.80s; the generator
tests pass 10 cases in 7.95s. The resumed full local gate passes 1,829 tests with 37 explicit platform
skips in 527.97s using two workers, including all static checks. Exact-head
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38046534095)
passes all 1,866 tests with zero skips in 138.97s at exact head `763c410`,
six stripped-ash checks in 7.25s and all eleven kernel scenarios.

The accepted 47% D2 manifest/catalog focused gate passes 39 tests with two
explicit missing-BusyBox skips in 5.78s. The slowest new group takes 1.32s.
Source `68fa3ed` passes the full serial Mac check: 1,819 tests with 37 explicit
platform skips in 1,159.49s. Exact head
`76fd14677ec925d6dfba495f828fb09a46867200` passes
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38002057996):
1,856 tests with zero skips in 116.52s, six stripped-ash checks in 7.07s and
all eleven kernel scenarios. Native-root, native-probe and native-dependencies
take 6.33s, 8.88s and 9.52s; namespace execution totals 29.53s. The 47%
results remain historical parser evidence; the accepted 48% developer
inventory checkpoint adds the host command described above.

Cost review is complete. An unchanged integration hit its 60s deadline in a
Mac timing follow-up, then passed its isolated retry in 53.69s under the same
bound; CI passes it in 6.86s. Elevated Mac host load, the retained failure and
the Linux suite's 20.4% timing increase are recorded in PLAN.md. New manifest
cases are absent from both full runs' slowest-20 lists. No assertions,
timeouts or source changed, and no second exhaustive run was made solely
for timing.

The following complete manifest is fictional and uses placeholder hashes; file
sizes and digests do not describe real repository files:

```text
manifest: 1
version: 1.0.0
config-schema: 1
package-api: 1
cfmgr.sh: 123 0000000000000000000000000000000000000000000000000000000000000000 0755
modules/lib/common.sh: 456 1111111111111111111111111111111111111111111111111111111111111111 0644
```

The preceding 46% checkpoint's focused parser checks pass 54 tests with two
explicit missing-BusyBox skips in 6.38s; the slowest case took 1.77s. Source
`4fd962d` passes the full serial local gate: 1,812 tests with 36 explicit platform
skips in 688.43s. Exact commit `4a3ae58708d77a484906becac12de2a99150b879` passes
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37997220279):
all 1,848 tests with zero skips in 96.81s, six stripped-ash checks in 6.86s and
all eleven kernel scenarios. The two new actual-BusyBox parser cases run in CI.
Native-root, native-probe and native-dependencies take 5.59s, 8.02s and 8.57s;
namespace execution totals 26.47s, with unchanged 15-second scenario bounds.
These are host checks, separate from Merlin acceptance.

Future developer-mode branch/commit changes must preserve existing router
catalog bytes; default catalog acquisition remains limited to a genuinely missing file. See the
[architecture contract](architecture.md#-modules-and-forks) and [PLAN.md](../PLAN.md).

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
