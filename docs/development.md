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

`modules/helpers/worker.sh` supplies native process-group admission and a separate
guarded aggregate-deadline controller. The admission check reads the calling
shell's actual proc record and requires its PID,
process group and shell `$$` to agree; session leadership is unnecessary.
This rejects a nested shell whose `$$` still identifies its parent. The check
does not establish exclusive group ownership, authorize signals or launch work.
Its actual Linux and BusyBox cases are separate from cheap metadata fixtures.
Deadline cases additionally exercise arm-before-callback, cooperative completion,
exact watchdog wait and real current-group cancellation. Their short, intentional
polling and termination budgets are integration costs, not parser-test targets.

The separate readonly-root entry in `modules/lib/isolation.sh` shares checked IO and
mount parsing without broadening the earlier callbacks. Its host consumers use
inert mount tools and actual inherited file descriptors. Complete success cases
retain every bounded capture; focused fault cases share the established query
fixture while preserving real IO ownership, mount parsing and descriptor checks.
Keep ordinary callback failure separate from incomplete root teardown or failed
IO cleanup: only the fully completed transaction may return that callback status.
The Linux consumer provides actual mount/readonly/descriptor evidence; neither
layer establishes an operational Entware worker.

The fixed native-view entry is
`cfmgr_isolation_native_root_with RAMROOT GUARD MOUNT_PARSER STORAGE_PARSER CALLBACK [ARGS...]`.
Its explicit fixture counterpart additionally takes tools, mount/fdinfo inputs
and a synthetic source root; production uses only `/bin`, `/sbin`, `/lib` and
`/usr`. Source directories must share a private readonly executable UBIFS or
squashfs filesystem; the fixture also permits a readonly tmpfs source. Exact
child ledgers and topology are checked before, during and after the scoped FD6
lease. The observer receives the root path, populated-root ledger and arguments;
it cannot launch payloads, chroot, leave asynchronous users or retain descriptors.
Children are removed in reverse order before checked base-root teardown.

The complete native-view transaction uses 56 unique query slots within a fixed
64-query limit; older entries retain their 16-query limit. Its host lifecycle
uses the focused query fixture to avoid duplicating every external capture.
The actual BusyBox and kernel consumers retain full captures, as does the
existing bare-root success case. Cheap direct cases cover source/options/child
identity and prove that a count of four descendants cannot substitute for four
matching child ledgers. Interrupted or incomplete teardown returns uncertainty
with its guard retained; a callback status is ordinary only after complete
child/root and IO cleanup.

The internal `modules/lib/native_config.sh` helper runs inside an active IO
callback and copies only the fixed `/etc/hosts` and `/etc/resolv.conf` inputs
into the caller-owned private image outside IO scratch. Each file is captured
through the existing IO owner with a 65,536-byte limit, checked for
complete exact-byte publication, and written without interpreting its content.
NUL bytes, truncation, unsafe paths and a pre-existing `/etc` staging path are
rejected. `cfmgr_isolation_native_data_root_with` takes `RAMROOT`, `GUARD`, the
mount and storage parsers, a synchronous native observer, then optional observer
arguments. It stages these files before its first bind and reuses the four
checked readonly native views. The helper does not check resolver syntax or
readiness, execute the copies, or supply a complete native configuration or
payload environment. A successful helper call still requires successful
enclosing IO cleanup; partial staging remains under the retained execution guard
on failure. Existing isolation APIs are unchanged.

`cfmgr_isolation_native_tmp_root_with` extends the native-data lifecycle with a
private writable tmpfs at `root/tmp`. Its production arguments add `LIMIT_KIB`
and `INODE_LIMIT` before the parser paths. Size must be a canonical decimal
multiple of 64 from 64 through 65,536 KiB; inode count must be a canonical
decimal from 8 through 8,192. The owner verifies the exact tmpfs source, flags,
mode, size and inode options, and a new distinct child identity under the base
root. The fixture entry also requires explicit tools, mount/fdinfo inputs and
native/data source roots. It creates an empty mode-`0700` `tmp/cfmgr-home`; the
native observer's `HOME` variable remains unchanged. A future launcher may set
its logical `HOME` to that path.

The limits cap tmpfs usage; they do not reserve physical memory or establish
available RAM headroom. After the observer returns, CFMgr checks the saved tmpfs
ledger, ordinarily unmounts `/tmp`, then removes the four native views in reverse
order and tears down the base root. The native-tmp layout uses 64 unique query
slots within the fixed 64-query ceiling. The native-data API and older root APIs
retain their existing contracts. This native-tmp entry is still not a payload,
chroot, opkg, readiness or operational worker path; the separate retained-Opt
composition is documented below. Complete native loader/ELF/TLS/NSS support
remains unimplemented.

`cfmgr_isolation_entware_root_with RESOLVED VOLUME RAMROOT GUARD LIMIT_KIB
INODE_LIMIT MOUNT_PARSER STORAGE_PARSER CALLBACK [ARGS...]` composes the checked
native views, private quota tmpfs and an already-admitted Entware Opt directory.
Call it only from the independent Entware admission callback while the original
FD8 block and FD9 directory remain held. A canonical volume report or UUID
format does not grant storage authority. The wrapper rechecks source facts,
topology and descriptor identities, then binds only `/proc/self/fd/9` at
`root/opt` with `rw,nosuid,nodev,exec`.

The observer receives the six-child root path and full root ledger, the original
volume report and unchanged optional arguments. It remains a synchronous trusted
native observer: no payload, chroot, asynchronous users, retained descriptors or
HOME replacement. Opt is ordinarily unmounted first; before tmpfs removal, the
owner verifies the exact empty readonly Opt fallback. It then removes tmpfs,
native views in reverse order and the base root. The composition uses 78 unique
mount queries within its fixed 78-query ceiling. Uncertain teardown retains the
guard and returns 129; an ordinary callback status is returned only after root
and enclosing IO cleanup succeed. It does not install packages or establish
physical filesystem identity, device nodes, complete native loader/helper/TLS/
NSS closure, or router acceptance. The separate native-data and older root APIs
are unchanged.

`cfmgr_isolation_native_devices_root_with` keeps the same production arguments
as the retained-Opt API. It creates exactly two owned character nodes in the
private root image: `/dev/null` (1:3) and `/dev/urandom` (1:9), both mode `0600`
and UID/GID 0. It does not copy host `/dev`. Each source inode is observed and
rechecked through the storage parser, retaining large inode values as text;
there are 12 metadata observations, each read only after its IO cleanup has
succeeded. The private image must remain frozen while the root is active,
because the observations before bind and after unmount are not a continuous FD
lease.

Each node gets an individual read-only, `nosuid`, `noexec`, device-enabled bind.
After that mount is removed, the base root's `nodev` fallback refuses new opens.
An already-open descriptor is not revoked by the fallback or by unmount. The
full layout has eight children and uses 106 unique query slots. Teardown removes
Opt, urandom, null, tmp, then `/usr`, `/lib`, `/sbin`, `/bin`, and the base root.
Uncertain cleanup returns 129 and retains the guard; ordinary callback status
is available only after complete root and IO cleanup. The callback remains a
trusted synchronous native observer with no payload, chroot, async users,
retained descriptors or `HOME` replacement.

`tests/test_native_devices.py` adds 25 focused unit cases, passing in 4.74 seconds,
and one host lifecycle case, passing in 35.04 seconds. The actual BusyBox
representative and existing ninth kernel scenario are upgraded in place. The kernel wrapper
opens FD5 on each node so unmount is witnessed busy, closes it to permit
cleanup, then proves new opens fail through the `nodev` fallback. Host busy-fault
tests separately prove runtime guard retention. The full Mac suite passes
1,593 tests with 29 explicit platform skips in 487.36 seconds. Linux/BusyBox and
kernel validation remain pending; neither synthetic metadata nor host fixtures
prove a continuous inode lease or router acceptance.

Preserve independent supplied-manifest closure, fixed-probe, live-producer
interruption, mount ownership and kernel proofs. The retiring direct-IPK tests
are obsolete with their implementation; their counts are not coverage targets.
Reuse strict terminal framing and interrupted-reader cases for retained probe
code, distinguishing ordinary capture rejection from uncertain completion.

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
util-linux `unshare`, BusyBox, OpenSSL, GCC/binutils and glibc development files. Its
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

Three representative cases exercise the real lifecycle's successful cleanup,
busy-mount retention and interruption handling. They enter at the preverified
storage callback boundary using actual mount observations and a retained
directory descriptor; block-device and UUID acquisition are outside this proof.
A separate controlled executable fixture checks chroot and exact-mount busy
behavior. One additional image scenario binds a private RAM executable/library
image read-only with nosuid/nodev and execution allowed. It verifies unchanged
mount identity, root-run EROFS for create and write, a still-writable outside
alias, mapped-image busy refusal, and ordinary removal after exact actor release.
The retained source is mounted separately for a read-and-close sentinel check.
A sixth contained scenario assembles real image staging/hash verification, the
read-only bind, fixed-probe supervision and ordinary checked cleanup. It uses
controlled host ELF bytes under the six-row profile layout, with the host loader
behind the profile alias. Its actor checks closed external descriptors, fixed
bootstrap links, null, EROFS and absence of proc, shell and mutable offline Opt.
Success requires the product guard and its mounts to be gone before namespace
disposal, with the original source mount identity unchanged.
A seventh scenario checks the proposed worker's filesystem-lifetime mechanisms.
An inherited directory descriptor on the actual read-only root bind prevents
removal while a launcher waits outside the root. After chroot and setsid, the
child closes that descriptor and retains only its filesystem root/cwd and two
proof-only communication pipes. Removing a writable `/opt` child bind exposes
read-only empty fallbacks: delayed `/opt` and `/tmp` writes fail with EROFS,
and the detached child still prevents ordinary root removal. Final removal
succeeds after controlled child exit. Fixture guard markers illustrate the
required uncertainty state; they do not implement an operational worker guard
or prove arbitrary descendant reaping or Entware package compatibility.
An eighth scenario calls the actual readonly-root runtime entry with native
BusyBox tools and proc metadata. It checks the root descriptor's mount identity,
failed writes through both readonly fallbacks, preserved caller descriptors,
ordinary callback failure after successful teardown, and retained completion
metadata. It requires the root mount to be absent before removing fixture RAM;
namespace disposal cannot conceal an incomplete successful path.
The ninth scenario now composes the native-tmp root with a retained Opt root and
the fixed native devices.
Alongside four readonly native views, staged hosts/resolver files and the
quota-limited tmpfs, it mounts a controlled writable source through actual FD9,
performs a bounded anchored write and confirms the source received it. FD8 is a
regular fixture file whose metadata is observed synthetically; its real offset
is preserved, so this does not prove physical block-device or UUID admission.
The case also verifies that Opt is unmounted first and becomes the exact empty
readonly fallback before tmpfs removal. The added device checks require the
eight-child ledger and 106 query slots, verify the owned character nodes and
their read-only child mounts, then hold a real BusyBox FD5 to witness a busy
unmount. Closing it allows checked teardown; the nodev base fallback then
refuses new opens. The earlier native data/FD6 checks, readonly-write refusal,
executable tmpfs, 64-KiB/eight-inode limits, private empty home and unchanged
observer `HOME` remain covered. The quota/Opt-only version passed the 37% CI
gate; the fixed-device upgrade passes the host suite and awaits Linux CI. Host
mirrors do not prove mount-enforced behavior or descriptor semantics.

All nine namespace scenarios retain their individual 15-second outer bounds.
Fixture compiler/library results do not establish Entware ABI or
Merlin acceptance, and namespace disposal after a failed case does not count
as successful runtime cleanup. Results and timings belong in the plan.

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
Merlin firmware, 32-bit arithmetic or hardware acceptance. The first passing
baseline ran **786 tests**, including its six dedicated BusyBox cases,
with BusyBox 1.36.1 and ShellCheck 0.9.0. Its matching Mac baseline passed 780
tests with six missing-BusyBox skips. Later stage results are recorded in the plan.

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
| `tests/test_storageinfo.py` | Native mount-ID/UUID observations, exact framing and ambiguous disk-label refusal |
| `tests/test_storage.py` | Held-descriptor observation, before/after identity checks and rejection without publication |
| `tests/test_isolation.py` | Focused ownership/cleanup faults plus representative complete lifecycle fixtures |
| `tests/isolation_helpers.py` | Shared focused mount-query fixture; full-capture consumers remain separate |
| `tests/test_execution_root.py` | Readonly-root ownership, descriptor lease, retained guards and complete versus uncertain cleanup |
| `tests/test_native_config.py` | Exact fixed-file staging, byte limits, NUL rejection, partial failures and cleanup ownership |
| `tests/test_native_root.py` | Four fixed readonly views, staged data, child identity, cleanup and the actual BusyBox retained-Opt/native-device representative |
| `tests/test_native_data_root.py` | Native-data composition before bind, exact staged bytes, query budget and checked teardown |
| `tests/test_native_tmp_root.py` | Canonical quota validation, tmpfs identity/options, private HOME and cleanup retention |
| `tests/test_entware_root.py` | Retained Opt-root success, busy-Opt cleanup refusal and malformed API rejection |
| `tests/test_entware_root_admission.py` | Cheap framing and storage-admission boundary cases |
| `tests/test_native_devices.py` | Fixed node metadata, inode retention, mount lifecycle and busy cleanup faults |
| `tests/fixtures/kernel/` | Controlled shell/C fixtures for the explicit Linux namespace proof, including retained Opt, fixed native devices, quota-limited native tmpfs and private HOME |
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

### JSON parser proof

`modules/lib/json.awk` currently provides strict validation and a bounded token ledger;
it is not yet connected to a config reader or provider client. Its caller must
supply a private, stable regular file, a separately checked byte count, and
`LC_ALL=C`. Input is limited to 64 KiB, 32 nested containers, 4,096 value nodes
and 16 KiB per decoded string. Numbers retain their original text.

Token output is limited to 128 KiB, including its terminal count footer. Native
awk can report success despite a failed output write, so future consumers must
check exit status, exact footer/newline/EOF, body byte count and sequential record
count before using any token. File ownership, bounded transport and router
performance remain separate integration requirements. See the frozen contract
in [PLAN.md](../PLAN.md#native-json-parser-proof-contract--current-package).

`modules/lib/ip.sh` provides separate IPv4/IPv6 normalization functions. IPv6 uses lower
case, shortest hextets and longest-leftmost zero compression, including hex
output for dotted IPv4 tails. Valid syntax is not public-address eligibility;
WAN selection, freshness and publish decisions remain separate. Python 3.14
renders mapped addresses differently, so tests use explicit mapped vectors and
address-equality checks alongside the independent standard-library oracle.

The measured firmware resolves `printf`, `test` and `[` to BusyBox applet paths,
not shell builtins. Native callers need a vetted firmware PATH even though host
shell tests can run these helpers with no external tools exposed.

### Mount snapshot parser

`modules/lib/mountinfo.awk` selects the deepest mount covering a canonical target path
and calculates the target's path within that filesystem, including bind-mount
roots. It rejects ambiguous overmounts at any covering ancestor. Numeric IDs
remain text, including values beyond the host's exact floating-point range.

Its caller must supply `LC_ALL=C`, a private stable regular-file snapshot, its
independently checked byte count, and `CFMGR_MOUNT_TARGET` through the environment.
Limits are 64 KiB per snapshot, 1,024 records, 8,192 bytes per line including LF,
and 4,096 bytes for the target. Standard mountinfo path escapes are decoded;
other raw control characters are outside the supported input profile.

The output is an internal ASCII record with byte-encoded paths and a terminal
byte-count footer. Verify status, structure, count and exact EOF before using it.
Hex encoding is not redaction: keep this metadata private. The parser reports
mount facts, including read-only and pseudo-filesystem records. The private IO
module below handles acquisition/framing; UUID checks, writability, supervision
and protection against mount changes remain separate implementation work.

### Private IO and snapshot handoff

`modules/lib/io.sh` is an internal library, separate from CLI feature dispatch. Its caller
supplies an already trusted RAM parent, controlled callback and verified parser
path. Sourcing it has no side effects; production resolves a small fixed set of
native tools and ignores inherited tool-path overrides.

| Function | Contract |
| --- | --- |
| `cfmgr_io_with_workspace ROOT CALLBACK [ARGS...]` | Create an owned mode-700 directory with at most eight collision attempts, call the internal callback with that directory as its first argument, then clean it up. Callback output is suppressed. |
| `cfmgr_io_with_report ROOT CALLBACK [ARGS...]` | The same private ownership, with exactly one explicitly staged report required for success. |
| `cfmgr_io_stage_report PAYLOAD` | Within a report callback, stage a nonempty ASCII payload of at most 65,536 bytes. Publish only after callback success and owned cleanup. |
| `cfmgr_io_capture SLOT OUT_LIMIT ERR_LIMIT TOOL [ARGS...]` | Within that callback, exclusively create private mode-600 stream/status files. Slots are 0–15 and consumed even after failure. Each accepted stream is at most 65,536 bytes. |
| `cfmgr_io_mount_snapshot ROOT TARGET PARSER` | Acquire fixed `/proc/self/mountinfo`, run the trusted parser and verify its status, fields, complete framing and byte count. Emit the bounded ASCII result only after workspace cleanup succeeds. |

**Capture status 0 means capture completed, not that the producer succeeded.**
The callback must read the producer status from the complete `.status` record
before using either stream. IO/limit/cleanup failures return 1, invalid usage
returns 2, and mount selection preserves 3 for no covering mount. Workspace
callbacks otherwise retain their own status; interrupted owners preserve
129/130/143. Failures do not produce a valid mount result.

File-size limits allow one overflow byte before exact acceptance checks. Because
supported shells use 512- or 1,024-byte units, the conservative physical ceiling
is 132,096 bytes per stream, or 4,227,072 bytes across 16 captures plus small
status files. Accepted stream payload totals at most 2,097,152 bytes. A failed
capture's partial files stay private until owned cleanup.

Disable tracing before passing arguments. The isolated workspace owner preserves
caller state and handles signals delivered to that owner; an external caller
must forward signals or supervise it. There is no hard deadline for a hung
native executable in this stage. The result is snapshot evidence, not authority
to write through a mount path during hotplug.

### Native storage observations

`modules/lib/storageinfo.awk` parses bounded `fdinfo`, native `blkid`, numeric
block-device listings and primary-superblock hex observations. It
requires a stable private file, its independently checked byte count, `LC_ALL=C`
and a literal mode. Inputs are at most 4 KiB; fdinfo has at most 64 records.
Mount IDs remain exact decimal text, including values beyond numeric precision.

For blkid, pass the expected device through `CFMGR_BLKID_DEVICE`, not an awk
`-v` value that might interpret backslashes. The parser validates the entire
native record, but withholds every LABEL-bearing result: the firmware's raw
label formatting can imitate a UUID field. A label-free result contains
byte-encoded UUID/optional filesystem type, never a storage authorization.

Status 0 supplies a complete framed observation, 1 rejects malformed data,
2 rejects invocation errors, and 3 means usable identity is unavailable.
Consumers must check status and the complete terminal byte-count record.
Expected-volume approval, writability and mount-loss handling remain separate
work.

### Held-descriptor storage observation

After loading trusted IO and storage modules, an internal caller can use
`cfmgr_storage_observe ROOT MOUNT_PARSER STORAGE_PARSER`. The arguments identify
the trusted RAM parent and absolute verified parser paths. Production uses fixed
`/opt` and proc inputs; fixture overrides belong to an explicit test API.

The observer holds a directory descriptor, joins its `mnt_id` to the selected
mount and checks that the current target still refers to that directory. It
then holds the selected block device, compares its numeric device number and
reads the first 1,152 bytes through the original descriptor's stdin. It requires
ext magic, dynamic revision and a nonzero UUID. Filesystem type and `sb=` options
are checked before the block-data read. Disk labels do not enter this UUID path.

Before staging, it repeats the target, mount, descriptor and device checks. The
result contains the mount ID, device number, filesystem type, byte-encoded paths
and options, and UUID, followed by an exact byte-count footer. Treat these facts
as private: hex encoding does not redact paths. Consumers must check exit status
and complete framing before using a report.

<details>
<summary>Scope and evidence limits</summary>

- Descriptors remain held through observation and staging, then are restored
  before workspace cleanup and publication. The report transfers no open handle
  or permission to mutate storage.
- This first profile supports dynamic-revision ext2/ext3/ext4 primary
  superblocks. Unsupported formats or unavailable identity return 3; malformed,
  changed or failed observations return 1; invalid API arguments return 2.
- Matching checks before and after a read do not prove atomic continuity,
  device-generation stability, expected configured identity, writability or
  filesystem health.
- The 16-slot capture limit bounds staging, not native process count or CPU
  cost. Command deadlines and native performance remain separate work.
- Host fault fixtures and unprivileged Linux descriptor tests do not establish
  physical hotplug, hardware or router runtime acceptance.

</details>

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

**Selected design; config generation and catalog downloads are not implemented yet.** CFMgr
will keep **`catalog.txt` at the repository root** alongside its readable source
modules. Setup downloads that file from the selected repository snapshot to
**`/jffs/addons/CFMgr.d/catalog.txt`**. The directory name is case-sensitive. Main `config` holds settings, credentials, feature state
and the `developer` flag; the catalog holds the branch/commit selector and module
URLs. Users edit the catalog file manually for testing or forks; there is no
menu setter and no separate remote-catalog URL setting.

The main settings file is **`/jffs/addons/CFMgr.d/config`**, without an extension.
Fresh installation generates it from defaults in code; the public repository
contains neither a config file nor a config template. Detect retained setup
before generating defaults, and preserve existing values during updates and
reinstalls under the schema migration contract. Parse settings as data.

Planned full uninstall defaults to **KEEP**, retaining settings and recovery
data. Explicit **WIPE** additionally removes the entire owned
`/jffs/addons/CFMgr.d/` directory, including its config and catalog, after all
required cleanup succeeds. Defer completion and retain recovery evidence if
cleanup is incomplete. Reset shares the owned-data cleanup but keeps the
verified manager package and generates fresh passive defaults.

The repository-root `cfmgr.sh` installs as `/jffs/scripts/cfmgr.sh`. It is the
CFMgr entry script in that directory; feature files and the `lib/`, `helpers/`
and `hooks/` subdirectories install beneath `/jffs/addons/CFMgr.d/` alongside the
catalog. Existing Merlin hook files retain their firmware-defined locations;
their thin CFMgr dispatch entries call the manager or its owned handlers.

The catalog consists of a source selector and named module URLs. Its logical
contents look like this; the exact bounded text grammar is a P1 gate:

```text
# main is the default; develop or a full 40-character commit hash is also valid.
branch: main
lib/common.sh https://raw.githubusercontent.com/XxUnkn0wnxX/CFMgr/{commit}/modules/lib/common.sh
```

This is a format illustration with the existing helper, not a complete install
inventory. `{commit}` is a literal placeholder replaced only with the validated
selected commit. The safe relative destination `lib/common.sh` preserves its
nested path beneath the installed manager directory. Catalog values are parsed
as data, never sourced as shell code.

| Selection | Meaning |
| --- | --- |
| `branch: main` | Resolve the stable branch once, then use that exact snapshot. |
| `branch: develop` | Resolve the development branch once for explicit testing. |
| `branch: <full-commit-hash>` | Use that snapshot without following a moving branch. |

A commit that changes one module still contains the complete repository tree.
Other modules retain their latest contents **as of that commit**. Nothing newer
is mixed in; missing historical files are not replaced from current main/develop.
The selected manifest and every module use the same immutable commit.

> [!NOTE]
> The manual `developer` flag in `config` defaults to `false`. With it off,
> updates and reinstalls may refresh **`catalog.txt`** from the selected package's
> defaults. With `developer=true`, the existing router catalog stays unchanged
> during branch/commit switches, updates and force reinstalls. Download the
> selected snapshot's default catalog only if the local file is missing. A malformed
> existing catalog is reported for repair, not overwritten. Catalog replacement does not replace
> main settings, credentials or feature state. The action keeps its original
> pinned source.

The `developer` flag also suppresses normal manager update checks. An explicitly
confirmed force reinstall preserves an existing catalog while the flag is true.
Editing the catalog alone does not replace running code. The planned `uf`
action stages and verifies the selected manager and all required modules, then
activates that complete revision together; compatibility and downgrade checks
still apply. Future developer capabilities can extend this flag.

<details>
<summary>🍴 Maintaining a fork and adding modules</summary>

1. Change the module URLs in local `catalog.txt` to your fork for testing. All
   entries must belong to the same selected repository and use `{commit}`.
2. Select `main`, `develop`, or a full commit hash. Invalid sources fail the
   affected action without silently switching back to the default repository.
3. For a distributable fork, update `catalog.txt` at its repository root. Keep helpers
   in separate named files; add new modules to both those defaults and the
   generated manifest's identity/path/hash inventory.
4. Test the complete package before publishing. A manually added URL is not
   sufficient to bypass manifest, hash, version or schema checks.

</details>

Installation/reinstallation/repair stages the complete required set before
activation. Reject duplicate destinations, unsupported URLs, path traversal,
missing files, wrong hashes and incompatible versions before replacing working
code. Each running invocation uses one compatible installed generation.

Ordinary startup, status and automatic hooks use installed modules. Missing
helpers defer the affected operation; explicit install/reinstall/repair uses the
verified download path. The complete activation/recovery protocol remains a
P1 gate in [PLAN.md](../PLAN.md). Existing downgrade restrictions remain in force;
choosing `develop` does not disable integrity checks.

## 🧭 Compatibility and documentation

Check capabilities rather than assuming all Merlin builds share the same
BusyBox configuration. The first measured target is GT-AX11000 on
`3004.388.12_2`; its native shell has signed 32-bit arithmetic and omits several
common applets. A 64-bit kernel does not establish 64-bit shell arithmetic.
Use the [compatibility evidence](compatibility.md) and unresolved gates in
[PLAN.md](../PLAN.md) before choosing runtime primitives.

The selected shared Entware prerequisites are `jq`, `coreutils-timeout` and
`coreutils-sha256sum`; the [compatibility matrix](compatibility.md) documents
scoped additions and feed/library evidence. Required tools are checked on each
launch and manager install/update/reinstall. An unavailable or unusable
prerequisite keeps operational work stopped; a later launch checks and can retry
installation. Advanced options will also provide **Reinstall Entware
dependencies**, distinct from Cloudflared daemon/hook/worker reinstallation.
The normal and explicit force-reinstall backend entries are implemented.
Approved-volume admission and cooperative exclusion have separate tested
primitives; operational scheduling, complete worker lifetime and UI integration
remain pending.
Hook dispatch must stay prompt, and native doctor must remain available without
Entware or working packages.
The final guides must state the accepted kernel/ABI combinations; package
presence alone does not prove compatibility.

Router access for this stage is read-only. Bounded native syntax/capability probes
are distinct from deploying code, changing services, installing packages,
running pytest on the router, or performing provider writes.

Keep guides concise, link to the canonical contracts, and describe implemented
behavior. The final user guides and architecture document follow the verified
runtime implementation. Use labeled screenshot placeholders until redacted
captures are supplied; do not create broken image links or imply unrun checks
passed through decorative badges.
