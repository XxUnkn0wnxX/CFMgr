# 🛠️ Development

[← README](../README.md) · [User setup](setup.md) · [Architecture](architecture.md) · [Compatibility](compatibility.md) · [Implementation plan](../PLAN.md) · [Test fixtures](../tests/fixtures/README.md)

![Python requirement](https://img.shields.io/badge/development-Python_3.11%2B-3776ab?logo=python&logoColor=white)
![Runtime target](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)

[PLAN.md](../PLAN.md) is the source of design and validation records. Follow the
[repository guidance](../AGENTS.md) for publication policy. This guide
describes the current developer tools and source-only interfaces. Commands not
listed here are not available through the current entry point.

Review the latest pytest duration report before each `develop` push and after
about three local batches, whichever comes first. Reuse comparable full-suite
measurements and time affected cases rather than rerunning the suite just to
collect timings. Review new ordinary tests over roughly two seconds, integration
cases over five seconds, or comparable suite growth near 20%. These are review
triggers, not reasons to raise timeouts or remove distinct coverage. Keep a small
set of real-consumer integrations, reduce repeated setup, and retain separate
signal, ownership, descriptor, framing, failure and required BusyBox checks.
The complete-suite review cadence and its evidence belong in [PLAN.md](../PLAN.md).

Before each implementation batch, reconcile test and fixture instructions with
this strategy. Preserve distinct acceptance requirements; record evidence and
results in the plan rather than repeating them here.

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

`modules/helpers/bootstrap.sh` exposes the internal
`cfmgr_bootstrap_dependencies SCOPE LOCK_PROVIDER` backend, which delegates
selected dependency installation to the existing Entware opkg. `SCOPE` is
`shared|tunnel`; `LOCK_PROVIDER` is `native|entware`. Test it with inert executable
doubles under an explicit fixture
root; never invoke host/router opkg, fetch feeds or install packages in tests.
Assert exact update/install arguments, selected-only packages, healthy no-op,
usable alternative providers, failure and post-check handling, and a later
invocation's retry. Keep one actual BusyBox representative. No direct-IPK,
archive-layout, pinned package-version or synthetic library-closure matrix is
needed for this backend.

The separate internal `cfmgr_bootstrap_reinstall` entry always requests an
update followed by `opkg --force-reinstall install` for all selected direct
packages, then checks their capabilities. Its tests cover the explicit reinstall of healthy
tools and refusal after failed update/install steps. Opkg owns dependency resolution and package conflicts.

Routine Entware upgrades remain user-managed through amtm/opkg. The normal
backend never runs a blanket upgrade or force-reinstalls healthy dependencies:
it probes mapped requirements, returns immediately when they are usable, and
refreshes package lists only when installation is needed. The selected install
lets opkg resolve required transitive dependencies. The internal explicit
dependency-reinstall backend is separate and force-reinstalls the selected
direct requirements. The current CLI does not expose this internal backend.

The backend requires an admitted, serialized caller with usable mounted
Entware and suitable scheduling. Its interface does not itself perform storage
admission or aggregate worker supervision. Its fixture root covers
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
failure, descriptor closure and a 32-KiB package write. Run these host checks
with:

```sh
python -m pytest tests/test_native_dependencies.py tests/test_native_shell.py tests/test_bootstrap.py
```

Two focused kernel-runner tests compile
the actual descriptor witness once and check 13 argument/descriptor cases
without chroot or privileged operations. They require a host `cc` executable
and report explicit skips when it is absent; Linux CI supplies the compiler.
This is a developer-test dependency, not a router requirement. Synthetic
stand-ins do not run Entware opkg or prove package provenance, firmware ABI or
router acceptance.

### Source-only serialized dependency worker

`modules/helpers/dependencies.sh` provides a finite fourteen-argument internal
API. It admits only the actual original shell's
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

The Linux fixture composes the lock, deadline, retained-Opt/root and synthetic
normal-opkg path. Its assertions cover the watchdog's own descriptors
(including FD7/high aliases), completion/reap before owned-marker release, and
the stable lock. The focused worker tests distinguish completed backend
outcomes from unproved cleanup and premature exits, and check retained
foreign/partial markers. A real process-group death case proves that a live
child can outlast the owner while the marker blocks a fresh attempt after actual
lock reacquisition.
Storage, root and deadline boundaries are otherwise narrow synthetic seams;
their complete Linux composition is established by the separate kernel gate.

The worker fixture set distinguishes cheap process-record checks from the
Linux/BusyBox lifecycle cases. Keep deadline, signal and real process-group
coverage in the focused worker tests; architecture documents the runtime
contract, and the fixture guide describes kernel evidence.

### Root lifecycle test coverage

The root lifecycles and their boundaries are documented in
[architecture](architecture.md#-runtime-structure). The host fixtures exercise
ownership, exact child ledgers, checked teardown, IO cleanup and retained-guard
failure. The Linux kernel lane supplies mount-enforced evidence; see the
[test-fixture guide](../tests/fixtures/README.md) for scenario coverage and its
limits. Neither proves router acceptance or supplies an operational worker.

The current `cfmgr_isolation_native_config_root_with` entry is the fixed
six-file composition over the retained-Opt/device lifecycle. Its tests check API
selection, pre-bind staging failure, exact bytes, cleanup and preserved device/Opt
behavior. The BusyBox composition is in `tests/test_native_root.py`; see the
[fixture guide](../tests/fixtures/README.md) for the evidence boundary.

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
`python -m pytest tests/test_native_opkg.py` for these host checks. They do not
establish opkg provenance or package execution.

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
Small pending queues balance work between workers. Worker crashes fail the run
without automatic restart. Use `--jobs 1` for a serial full check; direct focused
pytest commands remain serial unless explicitly given parallel options. Both modes
run the full selected inventory with the same per-invocation deadlines.

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
unverified. Linux/BusyBox evidence must come from the dedicated Linux runner or a local
Linux environment with the required privileges.

This option exercises BusyBox shell syntax and the dedicated
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

The kernel lane contains bounded namespace scenarios for BusyBox mounts,
fixed native views, readonly staged `/etc`, quota-limited tmpfs, retained Opt,
device-node cleanup, native probes and the serialized dependency worker. The
native-config-root scenario checks six staged files, including a binary CA bundle
larger than 128 KiB, with native BusyBox `dd` and `cmp`. The probe scenarios use
genuine host BusyBox/loader bytes and inspect descriptor and cleanup behavior;
the dependency-worker composition uses synthetic package executables. Storage
metadata is synthetic, so these fixtures do not prove router storage admission,
physical block-device/UUID approval, real opkg installation, firmware ABI or
router acceptance. They never copy or run firmware executables. See the
[test-fixture guide](../tests/fixtures/README.md) for scenario details and
limits.

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
credentials. Linux/BusyBox checks complement host checks; they do not prove
Merlin firmware, 32-bit arithmetic or hardware acceptance.

CI uses one Linux/BusyBox job. Its hosted kernel does not establish compatibility
with Merlin's patched kernels or older ARM/32-bit environments.

All contributions target `develop`; see [CONTRIBUTING.md](../CONTRIBUTING.md).

Before publication, run the local checks. Eligible code changes pushed to the
fork's `develop` branch start the GitHub Actions workflow; documentation-only
changes do not. Pull requests use the same code filters and target `develop`.
The repository guidance and [PLAN.md](../PLAN.md) define the full publication
and validation cadence.

## 🧱 Test structure

The runtime entry point is `cfmgr.sh`. The native health report is
`modules/diagnostic.sh`; shared shell/awk code is under `modules/lib/`, and
supporting bootstrap and worker code is under `modules/helpers/`.
Files are sourced or invoked explicitly; there is no arbitrary directory
autoloader. Runtime files are not compiled into a main executable. The Python
compilation check validates developer tooling only. The entry point does not install runtime files on a router.

| Path | Responsibility |
| --- | --- |
| `tests/harness.py` | Private fixture tree, explicit fake commands, bounded shell execution |
| `tests/conftest.py` | Fixtures, BusyBox selection, validation-matrix evidence reporting |
| `tests/test_harness.py` | Isolation, input/output, paths, deadlines, and child cleanup |
| `tests/test_reporting.py` | Accurate test-evidence counts |
| `tests/test_primitives.py` | Native decimal/version/digest parsing and caller-state preservation |
| `tests/test_ip.py` | Strict IPv4/IPv6 host syntax and deterministic canonical formatting |
| `tests/test_ip_classify.py` | IPv4/IPv6 scope-range boundaries, quiet invalid-input refusal and caller-state preservation |
| `tests/test_ip_observation.py` | Supplied IPv4 observation decisions, output framing, invalid-input refusal and caller-state preservation |
| `tests/test_wan.py` | Supplied WAN selection and native IPv4 source policy, framing and refusal |
| `tests/test_observation.py` | Supplied identity, monotonic age and lifetime policy, exact refusal and caller-state preservation |
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
Use focused tests to check a changed contract, then run the full check before
publication as required by the repository workflow. Keep native diagnostics separate: their usage and host
fixture command remain below.

### Native health report

The local development entry supports `--help`, `--version`, `--diagnostic` and
its identical alias `--doctor`. This report tests native command capabilities; it is not an installable manager
or a complete system health check.
Exercise it through the isolated host fixtures:

```sh
python -m pytest tests/test_diagnostic.py
```

The report includes feature-status and native command checks. Entware checks
are reported unavailable; the command does not read configuration, execute
Entware programs, contact providers, install packages or start services.

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

The curl check verifies option parsing only; it makes no HTTPS request. Host
fixtures and BusyBox-shell checks do not establish deployed-router acceptance.

</details>

## 🔎 Evidence and validation

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
Publish reviewed code, tests, documentation and requirements to `develop` only
after full local validation passes; wait for green CI before further code work. Keep the README's
explicit active-development warning until router runtime acceptance is complete.
Do not include unreviewed changes in a publication. Stable
promotion and live deployment still require separate authorization.

## 🧭 Address helpers

`cfmgr_ipv4_normalize ADDRESS` validates strict IPv4 text and returns it unchanged.
`cfmgr_ipv6_normalize ADDRESS` returns lowercase hexadecimal with shortest,
leftmost zero compression, including hexadecimal output for dotted IPv4 tails.
Both accept one host address, return 0 with one newline-terminated result, and
refuse invalid syntax or argument counts quietly with status 1.

`modules/lib/ip.sh` also provides `cfmgr_ipv4_classify ADDRESS` and
`cfmgr_ipv6_classify ADDRESS`. Each accepts exactly one address accepted by its
matching normalizer and prints one category followed by a newline with status
0. Invalid syntax or argument count returns status 1 without output. Both are
pure shell classifications: they do not discover interfaces, access the
network or read state, and their subshell bodies preserve caller state. They
use bounded word arithmetic; shells without built-in `printf` or `test` need
those native applets available.

IPv4 categories are `global`, `private`, `shared` and `nonpublic`:

| Result | IPv4 ranges |
| --- | --- |
| `private` | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` |
| `shared` | `100.64.0.0/10` |
| `nonpublic` | `0.0.0.0/8`, `127.0.0.0/8`, `169.254.0.0/16`, `192.0.0.0/24` except `192.0.0.9` and `.10`, `192.0.2.0/24`, `192.88.99.0/24`, `198.18.0.0/15`, `198.51.100.0/24`, `203.0.113.0/24`, and `224.0.0.0/3` |
| `global` | Other syntactically valid addresses, including the two listed `192.0.0.0/24` exceptions |

IPv6 categories are `private`, `transition`, `special`, `nonpublic` and
`global`, with these fixed ranges and exceptions:

| Result | IPv6 ranges |
| --- | --- |
| `private` | `fc00::/7` |
| `transition` | IPv4-mapped `::ffff:0:0/96`; IPv4-compatible `::/96` except `::` and `::1`; well-known NAT64 `64:ff9b::/96`; local-use NAT64 `64:ff9b:1::/48`; Teredo `2001::/32`; 6to4 `2002::/16` |
| `special` | `2001:1::1` through `2001:1::3`; AMT `2001:3::/32`; AS112 `2001:4:112::/48`; ORCHIDv2 `2001:20::/28`; DET `2001:30::/28`; direct AS112 `2620:4f:8000::/48` |
| `nonpublic` | Remaining `2001::/23`, `2001:db8::/32`, `3fff::/20`, retired 6bone `3ffe::/16`, and every valid address outside `2000::/3` not matched above |
| `global` | Remaining addresses in `2000::/3` |

The category is only a range classification. It does not prove assignment,
routing, WAN ownership, freshness, NAT, reachability or eligibility for
publication. The NAT64 categories match the listed prefixes only; they do not
detect network-specific translation or assess an embedded IPv4 address's scope
or reachability. These are CFMgr policy categories. The
final IPv4 octet alone does not identify a subnet's network or broadcast
address. IPv6 normalization remains a syntax and canonical-format operation;
classification is a separate function.

From the repository root, these POSIX-shell examples load the helper and
classify supplied values:

```sh
sh -c '. ./modules/lib/ip.sh; cfmgr_ipv4_classify 8.8.8.8'
sh -c '. ./modules/lib/ip.sh; cfmgr_ipv6_classify 2001:4860::1'
```

### Supplied IPv4 observations

`cfmgr_ipv4_observation_report WAN EXTERNAL` compares two caller-supplied IPv4
values. Use `-` when either observation is unavailable; every other operand
must be accepted by `cfmgr_ipv4_classify`. Invalid arity or input returns
status 1 without output. The helper does not collect addresses, inspect routes,
contact the network or call a provider.

Both operands are validated before the report applies its decision rules; invalid
input returns status 1 even when another condition would otherwise produce an
`unknown` result. For an operational comparison, the caller must provide a
fresh WAN observation for the selected-WAN/config generation and an external
observation whose IPv4 egress is verified for that same WAN and generation.
The helper does not establish those prerequisites.

The data row is `ipv4-observation<TAB>1<TAB>STATE<TAB>ADDRESS<TAB>NAT<TAB>REASON`.
The next row is `end<TAB>COUNT`, where `COUNT` is the byte length of the data
row including its terminating newline. Both rows end with a newline.

| WAN scope / value | External scope / value | State | Address | NAT | Reason |
| --- | --- | --- | --- | --- | --- |
| `-` | Any valid value or `-` | `unknown` | `-` | `unknown` | `wan-unavailable` |
| `nonpublic` | Any valid value or `-` | `unknown` | `-` | `unknown` | `wan-nonpublic` |
| `global`, `private` or `shared` | `-` | `unknown` | `-` | `unknown` | `external-unavailable` |
| `global`, `private` or `shared` | Non-global | `unknown` | `-` | `unknown` | `external-nonpublic` |
| Global and equal to external | `global` | `active` | WAN address | `false` | `address-match` |
| Global and different from external | `global` | `active` | External address | `true` | `address-mismatch` |
| `private` | `global` | `active` | External address | `true` | `private-wan` |
| `shared` | `global` | `active` | External address | `true` | `shared-wan` |

`active` identifies a candidate from these supplied values, not address
assignment, freshness or reachability. `unknown` does not authorize deletion.
`nat=false` means only that the supplied global addresses match; it does not
prove that no upstream translation exists. `nat=true` follows the mismatch or
private/shared-WAN rules, does not identify where translation occurs and does
not prove inbound reachability.

From the repository root, this POSIX-shell example sources the helper and
prints the framed comparison report:

```sh
sh -c '. ./modules/lib/ip.sh; cfmgr_ipv4_observation_report 10.0.0.1 8.8.8.8'
```

### Supplied selected-WAN IPv4 reports

`modules/lib/wan.sh` requires trusted `modules/lib/ip.sh` to be sourced first;
sourcing either library defines functions only. These helpers consume values
from one complete caller-acquired firmware, profile and configuration
observation. The caller must bind the values to the selected-WAN/config
generation and freshness, and verify IPv4 egress for the same WAN before using
them operationally. The reports establish none of those prerequisites.

`cfmgr_wan4_selection_report MODE PRIMARY0 PRIMARY1 DDNS_UNIT CONNECTED0
CONNECTED1 ADDRESS0 ADDRESS1` emits
`wan4-selection<TAB>1<TAB>selected|unknown<TAB>0|1|-<TAB>REASON` and an
`end<TAB>BODY_BYTES` footer. All eight operands are validated before
selection: mode is `off|fo|fb|lb|-`, flags are `0|1|-`, DDNS unit is `0|1|-1|-`
(`-1` means explicitly automatic), and addresses are strict IPv4 or `-`.
For `off`, `fo` and `fb`, exactly one primary flag must be `1` and the other
`0`; unavailable flags report `primary-unavailable`, while every other
combination fails closed as `primary-ambiguous`. In `lb`, explicit unit 0/1
reports `ddns-unit` without checking readiness. Automatic selection requires
known connected flags and addresses for every connected unit. It prefers the
first connected unit with an IANA `global` address (`auto-global`), then the
first connected unit (`auto-connected`); otherwise it reports the applicable
unknown reason: `selector-unavailable`, `connection-unavailable`,
`address-unavailable` or `no-connected-wan`. Missing mode reports
`mode-unavailable`. This strict global preference deliberately replaces the
firmware's broader private-subnet heuristic. A selected unit is a policy result,
not proof of active state, Internet access or egress. `CONNECTED0/1` must be
caller-normalized policy eligibility from complete evidence; they are not raw
firmware `state_t` values or a claim of being online.

`cfmgr_wan4_source_report ENABLE PROTOCOL IFNAME PPP_IFNAME IPADDR` emits
`wan4-source<TAB>1<TAB>candidate|inactive|unknown<TAB>INTERFACE|-<TAB>ADDRESS|-<TAB>REASON`
and the same byte-count footer. It accepts enable `0|1|-`, protocol
`dhcp|static|pppoe|pptp|l2tp|disabled|unsupported|-`, validated interface names
or `-` (1–15 ASCII characters, first alphanumeric, then alphanumeric, `_`, `.`
or `-`), and strict IPv4 or `-`. Only explicit enable `0` reports
`inactive/administratively-disabled`; unavailable enable reports
`enable-unavailable`, and protocol `disabled`, `unsupported` or `-` reports
`protocol-unavailable` without inferring administrative disablement.
DHCP/static use `IFNAME`; PPPoE/PPTP/L2TP use `PPP_IFNAME`. A missing selected
interface reports `interface-unavailable`; missing or `0.0.0.0` address reports
`address-unavailable`; a `nonpublic` address reports `address-nonpublic`. A
valid native address and interface produce `candidate/native-address`. Private
and shared addresses remain candidates for later comparison or NAT handling. A
candidate is not publication authority.

Both reports validate every operand, including unused fields, and return status
1 with no output for invalid input or arity. A valid report returns status 0;
unknown reports use `-` for their unit or interface/address fields. Their ASCII
records end in LF; the footer counts the complete data row including its LF.
They use isolated POSIX-shell
subshells and preserve caller state. This example uses supplied values only:

```sh
sh -c '
. ./modules/lib/ip.sh
. ./modules/lib/wan.sh
cfmgr_wan4_selection_report fo 1 0 - - - - -
cfmgr_wan4_source_report 1 dhcp eth0 ppp0 8.8.8.8
'
```

The API supports the basic two-unit Ethernet DHCP/static/PPPoE/PPTP/L2TP
profile. It does not acquire observations, normalize firmware state, verify
identity or freshness, check routes or egress, or authorize a provider action.
USB, softwire and model-specific overrides remain outside this interface.

### Supplied observation identity and freshness

Source trusted `modules/lib/common.sh` before `modules/lib/observation.sh`;
sourcing these libraries defines functions only. The API is
`cfmgr_observation_freshness_report OBS_BOOT CURRENT_BOOT OBS_GENERATION
CURRENT_GENERATION OBS_ID CURRENT_ID OBSERVED NOW MAX_AGE VALID_FOR`. Boot IDs
are `-` or lowercase UUID-shaped strings with 8-4-4-4-12 hexadecimal groups;
generations are `-` or canonical uint31 decimals (0 through 2,147,483,647,
without leading zeros). Source IDs are `-` or 64 lowercase hexadecimal
characters. `OBSERVED` and `NOW` are `-` or canonical uint31 monotonic seconds. `MAX_AGE` is canonical uint31 from 1 through
86,400; `VALID_FOR` is canonical uint31, `forever` or `-`. All ten operands,
including values ignored by a decision branch, are validated first.

The report is `observation-freshness<TAB>1<TAB>STATE<TAB>AGE<TAB>REASON`, followed
by `end<TAB>BODY_BYTES`; state is `current|stale|unknown`. Both lines end in LF,
and `BODY_BYTES` counts the first complete line including its LF. Invalid arity
or input returns status 1 with no report; a complete report returns 0. The
reason order is deliberate: known unequal boot, generation or source identity
returns stale `boot-changed`, `generation-changed` or `source-changed`, in that
order, before any missing identity is considered. Otherwise missing values
return unknown `boot-unavailable`, `generation-unavailable` or
`source-unavailable`. Then missing time gives `clock-unavailable`, and `NOW`
before `OBSERVED` gives `clock-regressed`. `AGE` stays `-` through these checks.

Once identities match and time is usable, `AGE = NOW - OBSERVED`. Age at or
above `MAX_AGE` is stale `max-age-expired`; this precedes checking lifetime.
With age below that cap, `VALID_FOR=-` gives unknown `lifetime-unavailable`;
finite age at or above `VALID_FOR` gives stale `lifetime-expired`; otherwise
the result is current `fresh`. Both expiry checks use strict age-less-than-cap
validity. `forever` removes only the finite-lifetime cap; `MAX_AGE` still
applies.

The caller supplies a coherent current snapshot, with its source ID recomputed
over the firmware/profile, selected unit, protocol, interface, address/prefix,
family intent, observation kind/result and relevant configuration/source policy.
Generations represent that observation's relevant policy/configuration context.
Known not-applicable fields on an inactive observation differ from unavailable
acquisition. `OBSERVED` is floored monotonic time no later than acquisition;
`NOW` is sampled after collection using the same boot clock. `VALID_FOR` is
measured from `OBSERVED`, conservatively including acquisition delay. The report checks only
supplied relationships: ID shape/equality does not authenticate or prove
complete acquisition. Recheck identity and generation before consuming the
result; inactive/removal observations require the same freshness check. The
helper does not collect or hash data, cache results, verify egress or authorize
a provider action.

From the repository root, this POSIX-shell example reports a fresh five-second
observation using illustrative IDs:

```sh
sh -c '
. ./modules/lib/common.sh
. ./modules/lib/observation.sh
ID=$(printf "%064d" 0)
cfmgr_observation_freshness_report \
  00000000-0000-0000-0000-000000000001 \
  00000000-0000-0000-0000-000000000001 \
  7 7 "$ID" "$ID" 100 105 10 6
'
```

## 📦 Source data and package reports

The source-only `modules/lib/config_header.awk`, `catalog.awk` and
`manifest.awk` validate bounded data formats. Callers explicitly load the
functions-only `modules/lib/package_path.awk` helper before either catalog or
manifest parser; no automatic helper loading is provided. Source-only native
manifest, byte, tree, version and policy reports, catalog request planner,
and config-header and config-lifecycle reports are described below;
none is connected to a full settings reader or installed workflow. These source-only reports do not implement full settings validation, defaults,
configuration writes, authenticated acquisition or installation. No generated
defaults file, catalog or manifest is shipped.

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
Other fields remain structurally checked but opaque; credentials are never
returned or approved. In header mode, output is exactly
`config-header<TAB>1<TAB>GENERATION<TAB>BOOLEAN<LF>` followed by
`end<TAB>BODY_BYTES<LF>`; it contains no other setting values.

Invocation/size errors return 2 and malformed data returns 1; valid projection
returns 0. The caller must still verify the JSON producer's status and exact
consumer output/footer bytes because AWK may not report an output-write failure.
Header mode does not establish complete settings validity, credential
semantics, defaults or config ownership. The public/ordinary IO capture and
measurement limits remain 65,536 bytes. The report uses a fixed private JSON-token
capture profile for this report; it does not widen arbitrary captures or
provide a large-config reader.

### Config-header report

The config-header API is `cfmgr_config_header_report RAM_ROOT CONFIG JSON_PARSER HEADER_PARSER`
and fixture-only `cfmgr_config_header_test RAM_ROOT TOOLS CONFIG JSON_PARSER
HEADER_PARSER`. Explicitly source trusted `io.sh`, `json.sh` and `config.sh`.
The caller supplies a private immutable readable regular nonsymlink CONFIG
file and trusted absolute readable regular nonsymlink parser paths. The report
does not source or evaluate configuration, select an installed path, or fetch
input.

One IO owner captures raw CONFIG in slot 0 at 65,536 stdout and 4,096 stderr
bytes. The fixed internal JSON-token profile in slot 1 runs `json.awk` in token
mode using the measured raw size; its output cap is 131,072 bytes, with 4,096
stderr bytes. The report passes those token bytes as stdin to `config_header.awk`
in slot 2 with 256 stdout and 4,096 stderr bytes. JSON and token contents stay
in files, not shell variables or argv. Each producer must succeed with empty
stderr. The owner then reconstructs the header output and checks exact fields,
canonical generation, boolean value, footer, original byte count, final LF,
EOF and absence of extra data before staging the report and cleaning up.

The public ledger is exactly
`config-header<TAB>1<TAB>GENERATION<TAB>true|false<LF>end<TAB>BODY_BYTES<LF>`.
It exposes only the supported schema marker, generation and developer flag;
it does not approve other settings, credential values or installation state.
Data, producer or cleanup refusal returns 1; invalid API/parser arguments
return 2. A trusted AWK/parser status 2 is preserved after empty-stderr checks.
The IO owner's HUP/INT/TERM results remain 129/130/143.

The report uses three captures and nine scratch artifacts. It allows 209,152
accepted capture bytes including stderr: 65,536 raw JSON, 131,072 token output,
256 header output and 12,288 stderr. Conservative file-limit allocation is
808,960 bytes plus status records: 264,192 raw, 526,336 tokens and 18,432
projection. Caller files and parser memory are additional; input acquisition
has no hard deadline. The ordinary `cfmgr_io_capture`, `_cfmgr_io_limit`,
`_cfmgr_io_size` and `cfmgr_io_stage_report` contracts remain at 65,536 bytes.

With prepared inputs and trusted parser paths, a developer can call the
source-only report as follows:

```sh
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/json.sh"
. "$CFMGR_LIB/config.sh"
JSON_PARSER=$CFMGR_LIB/json.awk
HEADER_PARSER=$CFMGR_LIB/config_header.awk
cfmgr_config_header_report "$RAM_ROOT" "$CONFIG" \
  "$JSON_PARSER" "$HEADER_PARSER"
```

The fixture API is only for developer tests. No CLI, defaults, live-config
admission, persistence or installed lifecycle calls this report.

### Config-lifecycle report

`cfmgr_config_lifecycle_report RAM_ROOT CONFIG JSON_PARSER HEADER_PARSER`
projects saved feature flags from the same caller-prepared private immutable
CONFIG file. Its fixture API is
`cfmgr_config_lifecycle_test RAM_ROOT TOOLS CONFIG JSON_PARSER HEADER_PARSER`.
Explicitly source trusted `io.sh`, `json.sh` and `config.sh`; parser paths must
be trusted absolute readable regular nonsymlink files. The API selects the
fixed lifecycle projection internally, while the existing header API and its
output remain unchanged.

Direct AWK callers select `cfmgr_config_header_mode=lifecycle`; omitted,
empty or literal `header` retains the header projection. Any other mode is an
invocation error. The original token-size and producer checks still apply.

Lifecycle mode requires the root `features` object and its `cloudflared`,
`ddns` and `ip-sync` objects. Each needs explicit boolean `configured` and
`enabled`; Cloudflared also needs boolean `maintenance_enabled` and string
`mode`. Every enabled feature must be configured. Cloudflared `enabled=true`
also requires `maintenance_enabled=true`. A configured Cloudflared feature
uses mode `token` or `advanced`; an unconfigured one uses `none`. A
maintenance-only setup can remain `configured=false` and `enabled=false`.
Installed availability is separate, so missing binaries or storage do not
erase saved intent.

The report emits exactly five LF-terminated rows in this order:

```text
config-lifecycle<TAB>1<TAB>GENERATION<TAB>DEVELOPER
cloudflared<TAB>CONFIGURED<TAB>ENABLED<TAB>MAINTENANCE_ENABLED<TAB>MODE
ddns<TAB>CONFIGURED<TAB>ENABLED
ip-sync<TAB>CONFIGURED<TAB>ENABLED
end<TAB>BODY_BYTES
```

`DEVELOPER` and flag fields are `true` or `false`; generation is canonical
from 0 through 2147483647. The owner checks exact row order and count, parser
and producer status with empty stderr, original bytes, footer, final LF, EOF
and cleanup before publishing. It returns saved header and feature state only;
it returns no credential values or draft state and does not validate the full
settings schema or establish installed availability or generation coherence.
It grants no migration, installation, recovery-guard or write authority. It
creates no defaults and writes no configuration.

The report uses the same three captures and nine scratch artifacts as the
header report: 209,152 accepted capture bytes including stderr and 808,960
bytes of conservative file-limit allocation plus status records. The caller
still owns private input acquisition and provenance. The fixture API is only
for developer tests; no CLI or operational lifecycle consumes this report.
Return codes and signal handling match the header API above. Use
`cfmgr_config_lifecycle_report` in its shell example with a CONFIG containing
the required feature fields.

### Setup-state report

`cfmgr_setup_state_report RAM_ROOT GUARD CONFIG JSON_PARSER HEADER_PARSER`
reads a caller-prepared guard and, for two states, composes the existing config
lifecycle projection. The fixture-only API adds `TOOLS` after `RAM_ROOT`:
`cfmgr_setup_state_test RAM_ROOT TOOLS GUARD CONFIG JSON_PARSER HEADER_PARSER`.
Source trusted `io.sh`, `json.sh`, `config.sh` and `setup_state.sh`; use private,
immutable, unaliased inputs and trusted parser paths. The report does not inspect
an installed path or write configuration.

The guard is at most 256 original bytes and exactly four LF-terminated rows:
`setup-state: 1`, `state: NAME`,
`generation: VALUE`, and `identity: HEX`. The seven state names are `installed`,
`retained`, `installing`, `removing-keep`, `removing-wipe`, `resetting` and
`reset-passive`. Generation is canonical decimal from 0 through 2,147,483,647;
`unknown` is accepted only for the four transitional states (`installing`,
`removing-keep`, `removing-wipe`, `resetting`). Identity is exactly 32 lowercase
hex characters. These fields are recorded claims, not authenticated identity,
installation or generation evidence.

For `retained` and the four transitional states, the API reports
`config-check<TAB>not-read` and does not inspect CONFIG or parser paths. For
`installed`, it requires lifecycle generation equality and reports
`lifecycle-match`. For `reset-passive`, it also requires developer mode off,
all Cloudflared/DDNS/IP-Sync flags off, and Cloudflared mode `none`, then reports
`passive-match`. It compares only these saved-state fields; it does not check an
installed generation, verify setup completion, write defaults or authorize
installation, activation, rollback or cleanup.

The three-row output is `setup-state<TAB>1<TAB>STATE<TAB>GENERATION<TAB>IDENTITY`,
`config-check<TAB>VALUE`, and `end<TAB>BODY_BYTES`, each LF-terminated. The
guard is reconstructed against its original captured byte count. The report
returns 0 only after the report owner's cleanup succeeds. Ordinary input, tool,
producer or cleanup failures return 1; API or required code-path errors return 2,
including a checked projection-parser status of 2. HUP/INT/TERM retain 129/130/143.

A developer caller supplies prepared paths and trusted parsers explicitly:

```sh
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/json.sh"
. "$CFMGR_LIB/config.sh"
. "$CFMGR_LIB/setup_state.sh"
JSON_PARSER=$CFMGR_LIB/json.awk
HEADER_PARSER=$CFMGR_LIB/config_header.awk
cfmgr_setup_state_report "$RAM_ROOT" "$GUARD" "$CONFIG" \
  "$JSON_PARSER" "$HEADER_PARSER"
```

The blocked one-capture path uses three scratch artifacts, at most 4,352
accepted bytes and 18,432 bytes of conservative allocation plus status. The
four-capture checked path uses twelve artifacts, at most 213,504 accepted bytes
and 827,392 bytes of conservative allocation plus statuses. Caller inputs and
process memory are additional. The fixture API is for developer tests only.

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
and their descendants are rejected. These keys name repository files; the parser
does not map them to installed destinations.
A URL's safe source path is validated separately and may differ from its
destination key.

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

### Catalog request plan

The API is `cfmgr_catalog_plan_report RAM_ROOT CATALOG MANIFEST PATH_HELPER
CATALOG_PARSER MANIFEST_PARSER COMMIT` and fixture-only
`cfmgr_catalog_plan_test RAM_ROOT TOOLS CATALOG MANIFEST PATH_HELPER
CATALOG_PARSER MANIFEST_PARSER COMMIT`. Source trusted `io.sh`, `package.sh`,
then `catalog.sh`. The API accepts separately prepared private, immutable
catalog and manifest files and trusted parser/helper paths; it does not fetch
either input or hash package files.

The report captures the catalog in IO slot 0 and the parser result in slot 1,
then parses the manifest through the existing package helper in slots 2 and 3.
It checks producer status and empty stderr, then reconstructs the parser's
catalog header, metadata, rows, footer and exact byte framing. This rejects
NUL normalization and short successful writes against the captured byte count;
`catalog.awk` remains the semantic grammar authority. The report pins the
single literal `{commit}` placeholder in the manifest URL and every file URL
to the caller's full 40-character lowercase hexadecimal `COMMIT`. A
catalog selector of `main` or `develop` is accepted with that commit, but the
caller must establish their correspondence. A full-commit selector is
normalized to lowercase and must equal `COMMIT`. No branch lookup occurs.

The planner joins the catalog file list to the manifest by exact destination
keys, regardless of row order or differences between source URL paths and
destination names. Counts must match, and every key must match exactly once.
The resulting `source-plan<TAB>1` ledger emits repository, selector, commit,
pinned manifest URL, manifest version, config-schema and package-api metadata,
then file rows in manifest order with destination, size, lowercase digest,
mode and pinned URL. Its LF-terminated footer records manifest file count,
package payload total and the complete report body byte count. The URL text is
not part of the package payload total. The consumer must still check function
status and exact ledger framing.

Invalid API/code arguments or malformed `COMMIT` return 2. Catalog or
manifest data, selector mismatch, transport/framing, join and cleanup refusal
return 1; an invoked trusted parser's status 2 and the existing owner signal
statuses are preserved. No report is published unless the complete join and
cleanup succeed.

The catalog raw/result stdout limits are 32,768/65,536 bytes; each manifest
capture allows 65,536 stdout bytes. The four captures use twelve scratch files
and allow 245,760 accepted bytes total: 229,376 stdout plus 16,384 stderr
(4,096 per capture). Conservative file allocation is 925,696 bytes plus
status records; there is no digest scratch. The joined ledger is capped at
65,536 bytes and has a conservative upper estimate of 47,904 bytes. Caller
input files and in-memory projections are additional. The planner adds no
source-acquisition deadline.

With the same trusted inputs prepared by the caller, a developer can invoke
the source-only API like this:

```sh
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/package.sh"
. "$CFMGR_LIB/catalog.sh"
PATH_HELPER=$CFMGR_LIB/package_path.awk
CATALOG_PARSER=$CFMGR_LIB/catalog.awk
MANIFEST_PARSER=$CFMGR_LIB/manifest.awk
cfmgr_catalog_plan_report "$RAM_ROOT" "$CATALOG" "$MANIFEST" \
  "$PATH_HELPER" "$CATALOG_PARSER" "$MANIFEST_PARSER" "$COMMIT"
```

This report does not prove that the local manifest came from its pinned URL,
that a named branch maps to the supplied commit, or that the repository is
authentic. It does not verify acquired source bytes, establish an independently
complete required profile or semantic compatibility, or grant installation
permission. A matching catalog and local manifest remain caller-supplied inputs;
policy validation and installation are outside this report.

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
malformed data returns 1, and valid input returns 0. Consumers must
check status, exact framing/footer and output-write completion; AWK status alone
does not prove a successful write.

The manifest is a declared inventory only. Parsing does not authenticate its
source, verify actual file bytes or installed ownership/modes, prove required
package completeness, compare it with a catalog, or authorize compatibility,
downgrade, activation or installation. A separate source-only verifier below
checks declared file bytes under explicit caller prerequisites; it does not
authenticate the manifest or prove directory completeness. The manifest must
not contain the containing commit hash: that would create a self-reference. An
acquisition caller must bind the manifest to a single already-resolved
immutable revision.
There is no generated root catalog, published manifest, downloader or
installed-package mapper. The developer inventory below writes only to stdout;
it does not publish or install the generated document.

### Native manifest report

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

### Declared-file verifier

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
ceiling is 790,528 bytes plus status files; input and process memory are additional.

### Complete-tree report

The tree report API is `cfmgr_package_tree_report RAM_ROOT SOURCE_ROOT
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

Only after namespace and all declared size/SHA-256 checks succeed does the API emit
the `package-tree<TAB>1` ledger, retaining manifest metadata and file records
and recomputing the footer length. It uses the existing IO owner for all three
captures and cleanup before report publication. The public entries preserve
the declared-file status classes: misuse returns 2, processing/input/tool/cleanup failure
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
acquisition or authority to adopt an arbitrary existing tree. The caller must create exactly the accepted inventory. The API also does not authenticate
source, check installed permissions/ownership, establish semantic module/API
or version compatibility, acquire/download/install/activate code, or prove
Merlin runtime acceptance.

The three captures use nine scratch files; per-file digest and hex captures
add at most 256, for 265 total. Accepted capture streams are bounded to 208,896
bytes plus 12,288 digest/hex bytes; conservative file allocation is at most
1,054,720 bytes plus status files. Caller input, shell/producer memory and
filesystem traversal remain additional.

### Entry-version report

The entry-version API is `cfmgr_package_version_report RAM_ROOT SOURCE_ROOT
MANIFEST PATH_HELPER MANIFEST_PARSER ENTRY_PARSER` and the fixture-only
`cfmgr_package_version_test RAM_ROOT TOOLS SOURCE_ROOT MANIFEST PATH_HELPER
MANIFEST_PARSER ENTRY_PARSER`. Explicitly source trusted `io.sh`,
`native_digest.sh`, then `package.sh`. The APIs are not connected to the CLI,
catalog, acquisition, installer or activation path.

The entry parser, `modules/lib/entry_version.awk`, reads the caller-supplied
regular immutable entry as data on stdin under `LC_ALL=C`; it has no filename
operands and never sources or executes the entry. The caller independently
measures the file and supplies canonical positive `cfmgr_entry_size` from 1 to
1,048,576 bytes. The parser checks whole-document byte length and EOF using
ASCII 28 as its record separator, rejecting that byte anywhere; it also rejects
NUL explicitly for AWKs that preserve it. A final LF is optional. Other
unrelated controls, CR and high bytes remain allowed.

`ENTRY_PARSER` must be a trusted absolute readable regular nonsymlink file;
the entry, helper, parser, native tools and their ancestors retain the existing
immutable/unaliased caller trust requirements. The source-root package limits
remain 1 MiB per file and 8 MiB aggregate.

A candidate declaration begins at the start of the document or after LF, with
zero or more spaces/tabs and optionally `export` or `readonly` followed by
spaces/tabs before `CFMGR_VERSION=`. Exactly one candidate must exist, but the
accepted line itself must be column-zero and exactly
`CFMGR_VERSION=X.Y.Z`. Each component is a canonical nonnegative decimal
string: `0` or a nonzero digit followed by digits, with no leading zeroes.
The complete version is at most 128 bytes. Indentation, an `export` or
`readonly` prefix, quotes, expansion, duplicate or missing candidates, a
leading zero, or any trailing space, CR or other line data is rejected.
Comments and unrelated lines are not interpreted as declarations. The
host-only `tools/package_manifest.py` extractor follows the same convention
and globally rejects NUL and ASCII 28.

On success the parser emits exactly
`entry-version<TAB>VALUE<LF>end<TAB>BODY_BYTES<LF>`, where `BODY_BYTES`
includes the first line's LF. Invalid invocation, missing/noncanonical size,
or an out-of-range declared size returns 2; a byte-count, framing or grammar
mismatch returns 1; success returns 0 with no refusal output. The consumer
still checks producer status, empty stderr, exact output bytes, both lines,
the footer and EOF; AWK status alone does not prove a complete output write.

The source-only consumer performs the manifest read, strict observed-tree
comparison and every declared size/hash check once within the same IO owner.
It then independently
measures `cfmgr.sh`, requires its size to be 1 MiB or less, and captures the
entry parser in IO slot 3 with 256 stdout bytes and 4,096 stderr bytes. It
requires the exact literal version to equal the accepted manifest version
before publishing the existing metadata/file ledger with header
`package-version<TAB>1` and a recomputed footer. Source acquisition remains
bounded and caller-owned; AWK reading through EOF does not add a hard read
deadline. A successful report proves only literal entry/manifest version
agreement. Required-module policy, semantic module/API compatibility,
no-downgrade checks, source authentication/acquisition, installed permissions,
activation and router acceptance remain separate gates.

The consumer preserves the complete-tree report's status classes: API/preflight misuse returns 2,
ordinary parser, mismatch, tool, input or cleanup failure returns 1, and owner
HUP/INT/TERM return 129/130/143. A successfully captured parser status 2 with
empty stderr remains 2; other nonzero parser statuses or any parser stderr map
to 1.

Its four captures have the same resource bounds as the
[package-policy report](#package-policy-report) below.

With the same trusted path variables used above, a developer caller invokes
the production entry like this:

```sh
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/native_digest.sh"
. "$CFMGR_LIB/package.sh"
MANIFEST_PARSER=$CFMGR_LIB/manifest.awk
ENTRY_PARSER=$CFMGR_LIB/entry_version.awk
cfmgr_package_version_report "$RAM_ROOT" "$SOURCE_ROOT" "$MANIFEST" \
  "$PATH_HELPER" "$MANIFEST_PARSER" "$ENTRY_PARSER"
```

Check both the function status and complete `package-version` ledger. The
fixture API is `cfmgr_package_version_test` and is only for developer tests.

### Package-policy report

The package-policy API is `cfmgr_package_policy_report RAM_ROOT SOURCE_ROOT MANIFEST PATH_HELPER
MANIFEST_PARSER ENTRY_PARSER EXPECTED_VERSION INSTALLED_VERSION REQUIREMENTS`
and fixture-only `cfmgr_package_policy_test RAM_ROOT TOOLS SOURCE_ROOT
MANIFEST PATH_HELPER MANIFEST_PARSER ENTRY_PARSER EXPECTED_VERSION
INSTALLED_VERSION REQUIREMENTS`. Source trusted `common.sh`, `io.sh`,
`native_digest.sh` and `package.sh` explicitly. The API is not wired to a
catalog, acquisition, installer or activation path.

The report performs the manifest, observed-tree and declared-byte checks and
the entry/manifest literal-version check once within the same IO owner. It
also compares the caller's expected version with the installed floor using
`cfmgr_version_compare`. Both versions use its canonical three-component,
at-most-128-byte format. Malformed version arguments or unavailable/invalid comparator
output returns 2; a lower expected version or invalid package/policy data
returns 1; equal and newer versions are accepted. The manifest version must
equal the expected version exactly before the tree and digest checks. There is
no downgrade bypass. Normal update callers should provide only newer versions;
a force reinstall may accept equality. The caller must establish the actual
installed floor, or prove that the installation is genuinely fresh before
selecting one. Unknown or damaged installed metadata must not be treated as
`0.0.0`.

`REQUIREMENTS` is a pre-acquired, caller-trusted immutable regular readable
nonsymlink file outside `SOURCE_ROOT`. Its canonical absolute path is limited
to 4,096 bytes and cannot contain controls, repeated slashes, dot components
or a trailing slash. The existing native size helper observes a positive
original size no greater than 32,768 bytes. Contents require exact LF-framed
rows: `requirements: 1`, then 1–128 unique `DEST: MODE` rows, with safe
package destinations, mode `0644` or `0755`, and exactly one `cfmgr.sh: 0755`.
Each row must match a manifest destination and mode exactly; the supplied rows
are minimum requirements, so additional package files are allowed. The final
row must end in LF, and reconstructed bytes must equal the observed file size.
A noncanonical path or invalid file shape is API
misuse (2); invalid size, observation or policy content is refusal (1). The
outside-root check is only a lexical misuse guard; trusted unaliased immutable
ancestors, no hard-link alias and independent selection of a complete
requirements profile remain caller preconditions.

On success the API publishes the normal metadata/file ledger with header
`package-policy<TAB>1` and a recomputed footer. It proves only that the
caller-prepared package matches the supplied structural and version policy.
It does not authenticate source, establish semantic module/API compatibility,
approve full configuration migration or installed permissions, acquire or
install code, or authorize activation. The same four captures use twelve
scratch files; with at most 256 digest/hex files, the maximum is 268.
Accepted capture streams are bounded to 213,248 bytes plus 12,288 digest/hex
bytes; conservative file allocation is at most 1,073,152 bytes plus status
files. Caller input and process memory are additional.

With prepared inputs and the same trusted path variables, a developer caller
can invoke the library API as follows:

```sh
. "$CFMGR_LIB/common.sh"
. "$CFMGR_LIB/io.sh"
. "$CFMGR_LIB/native_digest.sh"
. "$CFMGR_LIB/package.sh"
MANIFEST_PARSER=$CFMGR_LIB/manifest.awk
ENTRY_PARSER=$CFMGR_LIB/entry_version.awk
cfmgr_package_policy_report "$RAM_ROOT" "$SOURCE_ROOT" "$MANIFEST" \
  "$PATH_HELPER" "$MANIFEST_PARSER" "$ENTRY_PARSER" \
  "$EXPECTED_VERSION" "$INSTALLED_VERSION" "$REQUIREMENTS"
```

Check both the function status and complete `package-policy` ledger. The
fixture API is only for developer tests; it does not exercise installation or
live router state.

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
tool applies the same literal version convention described in the
[entry-version report](#entry-version-report), including global
NUL and ASCII 28 refusal. It validates the complete generated document with
the trusted parsers in the tool's current checkout and never sources or runs
the selected snapshot's files.

This Git inventory does not authenticate source, establish an independently
required complete package, verify installed files or authorize installation.

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

## 🧭 Compatibility and documentation

Check [compatibility evidence](compatibility.md) and [PLAN.md](../PLAN.md) before
choosing firmware-specific primitives. The compatibility guide records the
bounded three-image audit, its source/cache instructions and the distinction
between static evidence, host/CI behavior and router acceptance. Reuse the
ignored `.tmp/firmware-audit/INDEX.md` rather than repeating extraction; never
commit its archives, images, extracted data, certificates or raw reports.

Dependency backend tests and policy are described above; actual startup,
install/update/reinstall and worker lifecycle wiring are not provided by the current entry.
Router access stays read-only during development. Host checks and CI do not
authorize installation, service changes, provider writes or router acceptance.
At major documentation reviews, record intentionally unchanged guides in the
plan.
