# 🛠️ Development

[← README](../README.md) · [User setup](setup.md) · [Architecture](architecture.md) · [Compatibility](compatibility.md) · [Implementation plan](../PLAN.md) · [Test fixtures](../tests/fixtures/README.md)

![Python requirement](https://img.shields.io/badge/development-Python_3.11%2B-3776ab?logo=python&logoColor=white)
![Runtime target](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Project stage](https://img.shields.io/badge/stage-foundation-orange)

CFMgr is being implemented in checked stages. This guide describes the working
developer tools; [PLAN.md](../PLAN.md) remains the design, acceptance checklist,
and progress record. There is no installable manager yet.

Use focused tests and relevant lint/static checks for each small implementation
batch, then review and commit. At a major checkpoint, run the full local suite
and fix failures until it passes before pushing the tested commits to `develop`.
Wait for CI and resolve failures before beginning the next set of batches.
Unvalidated work stays local.

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

## 🧪 Run checks

From the repository root with `.venv` active:

```sh
python tools/check.py
```

This checks installed dependencies, Python lint/formatting/compilation, discovered
shell syntax, ShellCheck, `shfmt`, and pytest. It recognizes `.sh`, `.sh.in`, and
extensionless shell entry points. Scratch, virtualenv, cache, and symlinked
source paths are excluded. The first native source, `modules/common.sh`, provides
pure parsing helpers; it does not install or start CFMgr.

`tools/check.py` locates the checkout from its own file, so a fork can use a
different owner, repository name or directory, including spaces. It has no
hardcoded GitHub repository, remote or branch and does not commit, push or wait
for CI. Its selected executable paths are configurable; the same runner is used
by the checked-in workflow.

| Task | Command |
| --- | --- |
| Full host test suite | `python -m pytest` |
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

### Isolated Linux kernel checks

The explicit kernel lane requires a disposable Linux development runner, root,
util-linux `unshare`, BusyBox, GCC/binutils and glibc development files. Its
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

Three representative cases exercise the real lifecycle's successful cleanup,
busy-mount retention and interruption handling. They enter at the preverified
storage callback boundary using actual mount observations and a retained
directory descriptor; block-device and UUID acquisition are outside this proof.
A separate controlled executable fixture checks chroot and exact-mount busy
behavior. Fixture compiler/library results do not establish Entware ABI or
Merlin acceptance, and namespace disposal after a failed case does not count
as successful runtime cleanup. Results and timings belong in the plan.

### Linux CI

The [Checks workflow](../.github/workflows/checks.yml) runs on code, test and
tooling changes pushed to `develop` or proposed in pull requests targeting
`develop`. Documentation-only changes skip CI. It uses Ubuntu
24.04, Python 3.14.0 in a virtualenv, the pinned Python requirements and the
runner's packaged BusyBox/ShellCheck. It invokes the same check command with
`--busybox /usr/bin/busybox`, so missing BusyBox is a failure rather than a skip.
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

The runtime entry point is `cfmgr.sh`, with directly used shell/awk helpers in
`modules/`. These files are not compiled into a main executable. The Python
compilation check validates developer tooling only. The planned installed
command remains `cfmgr`.

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
| `tests/fixtures/kernel/` | Controlled shell/C fixtures for the explicit Linux namespace proof |
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

`modules/json.awk` currently provides strict validation and a bounded token ledger;
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

`modules/ip.sh` provides separate IPv4/IPv6 normalization functions. IPv6 uses lower
case, shortest hextets and longest-leftmost zero compression, including hex
output for dotted IPv4 tails. Valid syntax is not public-address eligibility;
WAN selection, freshness and publish decisions remain separate. Python 3.14
renders mapped addresses differently, so tests use explicit mapped vectors and
address-equality checks alongside the independent standard-library oracle.

The measured firmware resolves `printf`, `test` and `[` to BusyBox applet paths,
not shell builtins. Native callers need a vetted firmware PATH even though host
shell tests can run these helpers with no external tools exposed.

### Mount snapshot parser

`modules/mountinfo.awk` selects the deepest mount covering a canonical target path
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

`modules/io.sh` is an internal library, separate from CLI feature dispatch. Its caller
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

`modules/storageinfo.awk` parses bounded `fdinfo`, native `blkid`, numeric
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

There is no verified supervisor for a hung native executable yet. The report
therefore tests finite local operations and leaves flock contention untested.
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

**Selected design; config/catalog downloads are not implemented yet.** CFMgr
will ship catalog defaults with its readable source modules. Setup stores the
active catalog in **`/jffs/addons/CFMgr.d/config`**. The directory name is
case-sensitive. Users edit the catalog settings manually for testing or forks;
there is no menu setter and no separate remote-catalog URL setting.

The catalog consists of a source selector and named module URLs. Its logical
contents look like this; the exact enclosing config schema is a P1 gate:

```text
# main is the default; develop or a full 40-character commit hash is also valid.
branch: main
common.sh https://raw.githubusercontent.com/XxUnkn0wnxX/CFMgr/{commit}/modules/common.sh
```

This is a format illustration with the existing helper, not a complete install
inventory. `{commit}` is a literal placeholder replaced only with the validated
selected commit. Catalog values are parsed as data, never sourced as shell code.

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
> The manual `developer` flag defaults to `false`. With it off, updates and
> reinstalls may refresh the **catalog portion** from the selected package's
> defaults. With `developer=true`, an existing catalog is preserved; a missing
> catalog may still be initialized. A malformed existing catalog is reported
> for repair, not overwritten. Credentials, feature state and other settings
> are outside catalog replacement. The action keeps its original pinned source.

The `developer` flag also suppresses normal manager update checks. An explicitly
confirmed force reinstall preserves an existing catalog while the flag is true.
Future developer capabilities can extend this flag.

<details>
<summary>🍴 Maintaining a fork and adding modules</summary>

1. Change the module URLs in the local config to your fork for testing. All
   entries must belong to the same selected repository and use `{commit}`.
2. Select `main`, `develop`, or a full commit hash. Invalid sources fail the
   affected action without silently switching back to the default repository.
3. For a distributable fork, update its shipped catalog defaults. Keep helpers
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
These package flows remain unimplemented. Hook dispatch must stay prompt, with
bounded serialized package work and a native recovery entry for broken tools.
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
