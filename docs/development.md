# 🛠️ Development

[← README](../README.md) · [User setup](setup.md) · [Architecture](architecture.md) · [Compatibility](compatibility.md) · [Implementation plan](../PLAN.md) · [Test fixtures](../tests/fixtures/README.md)

![Python requirement](https://img.shields.io/badge/development-Python_3.11%2B-3776ab?logo=python&logoColor=white)
![Runtime target](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Project stage](https://img.shields.io/badge/stage-foundation-orange)

CFMgr is being implemented in checked stages. This guide describes the working
developer tools; [PLAN.md](../PLAN.md) remains the design, acceptance checklist,
and progress record. There is no installable manager yet.

Completed implementation, tests and documentation are published to `develop`
after stage validation and review. Unvalidated work stays local. The branch is
an active development checkout, not a router release; router runtime acceptance
and stable promotion remain separate gates.

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

## 🧪 Run checks

From the repository root with `.venv` active:

```sh
python tools/check.py
```

This checks installed dependencies, Python lint/formatting/compilation, discovered
shell syntax, ShellCheck, `shfmt`, and pytest. It recognizes `.sh`, `.sh.in`, and
extensionless shell entry points. Scratch, virtualenv, cache, and symlinked
source paths are excluded. The first native source, `src/common.sh`, provides
pure parsing helpers; it does not install or start CFMgr.

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
one, the dedicated BusyBox test is visibly skipped and compatibility remains
unverified. The initial Mac has no usable BusyBox executable or running Docker
daemon; this is recorded as missing evidence, not a successful compatibility run.

Currently this option exercises BusyBox shell syntax and the dedicated
shell/applet fixture. Ordinary `router` fixtures still use the host `/bin/sh`;
it does **not** silently rerun the whole suite under BusyBox. A modern full
BusyBox build also does not reproduce a router's stripped older build.

### Linux CI

The [Checks workflow](../.github/workflows/checks.yml) runs on code, test and
tooling changes pushed to `develop` or proposed in pull requests targeting
`develop`. Documentation-only changes skip CI. It uses Ubuntu
24.04, Python 3.14.0 in a virtualenv, the pinned Python requirements and the
runner's packaged BusyBox/ShellCheck. It invokes the same check command with
`--busybox /usr/bin/busybox`, so missing BusyBox is a failure rather than a skip.
Tool versions are printed in the job log.

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

## 🧱 Test structure

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
| `tests/fixtures/` | Synthetic or reviewed sanitized data only |
| `tools/check.py` | One host validation entry point |
| `pytest.ini`, `ruff.toml` | Discovery, markers, and Python style |

Each fixture has its own `jffs`, `opt`, `ram`, `home`, `bin`, and working
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

`src/json.awk` currently provides strict validation and a bounded token ledger;
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

`src/ip.sh` provides separate IPv4/IPv6 normalization functions. IPv6 uses lower
case, shortest hextets and longest-leftmost zero compression, including hex
output for dotted IPv4 tails. Valid syntax is not public-address eligibility;
WAN selection, freshness and publish decisions remain separate. Python 3.14
renders mapped addresses differently, so tests use explicit mapped vectors and
address-equality checks alongside the independent standard-library oracle.

The measured firmware resolves `printf`, `test` and `[` to BusyBox applet paths,
not shell builtins. Native callers need a vetted firmware PATH even though host
shell tests can run these helpers with no external tools exposed.

### Mount snapshot parser

`src/mountinfo.awk` selects the deepest mount covering a canonical target path
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

`src/io.sh` is an internal library, separate from CLI feature dispatch. Its caller
supplies an already trusted RAM parent, controlled callback and verified parser
path. Sourcing it has no side effects; production resolves a small fixed set of
native tools and ignores inherited tool-path overrides.

| Function | Contract |
| --- | --- |
| `cfmgr_io_with_workspace ROOT CALLBACK [ARGS...]` | Create an owned mode-700 directory with at most eight collision attempts, call the internal callback with that directory as its first argument, then clean it up. Callback output is suppressed. |
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
The user authorizes completed code, tests, documentation and requirements to be
published to `develop` after stage checks and review pass. Keep the README's
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
common.sh https://raw.githubusercontent.com/XxUnkn0wnxX/CFMgr/{commit}/src/common.sh
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
