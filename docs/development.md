# 🛠️ Development

[← README](../README.md) · [Compatibility](compatibility.md) · [Implementation plan](../PLAN.md) · [Test fixtures](../tests/fixtures/README.md)

![Python requirement](https://img.shields.io/badge/development-Python_3.11%2B-3776ab?logo=python&logoColor=white)
![Runtime target](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Project stage](https://img.shields.io/badge/stage-foundation-orange)

CFMgr is being implemented in checked stages. This guide describes the working
developer tools; [PLAN.md](../PLAN.md) remains the design, acceptance checklist,
and progress record. There is no installable manager yet.

During initial review, `develop` receives documentation and requirements updates;
implementation and test code remain local until user testing and publication
approval. The check commands below describe that local development checkout and
become available in a fresh clone when its code is published.

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

## 🧱 Test structure

| Path | Responsibility |
| --- | --- |
| `tests/harness.py` | Private fixture tree, explicit fake commands, bounded shell execution |
| `tests/conftest.py` | Fixtures, BusyBox selection, validation-matrix evidence reporting |
| `tests/test_harness.py` | Isolation, input/output, paths, deadlines, and child cleanup |
| `tests/test_reporting.py` | Accurate test-evidence counts |
| `tests/test_primitives.py` | Native decimal/version/digest parsing and caller-state preservation |
| `tests/test_json.py` | JSON grammar, Unicode, duplicate keys, exact limits and framed output |
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
Documentation and requirements may be published to `develop` during this work.
Keep those changes separate from code commits: pushing a later documentation
commit must never publish its unapproved code ancestors. Implementation and test
code require completed user testing and publication approval; stable promotion
remains separate.

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

Minimal Entware dependencies are allowed when a native equivalent cannot meet
the required contract reliably. Required tools are checked on each launch; an
unavailable or unusable prerequisite keeps operational work stopped. Failed
installation is retried on a later launch after checking again. Hook dispatch
remains prompt, and package work is bounded and serialized. The final guides
must list the exact selected packages, transitive requirements and supported
kernel/ABI combinations; package presence alone does not prove compatibility.

Router access for this stage is read-only. Bounded native syntax/capability probes
are distinct from deploying code, changing services, installing packages,
running pytest on the router, or performing provider writes.

Keep guides concise, link to the canonical contracts, and describe implemented
behavior. The final user guides and architecture document follow the verified
runtime implementation. Use labeled screenshot placeholders until redacted
captures are supplied; do not create broken image links or imply unrun checks
passed through decorative badges.
