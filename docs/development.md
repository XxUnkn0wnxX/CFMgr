# Development checks

[Project overview](../README.md) · [Current handoff](../PLAN_V2_handoff.md)

CFMgr runtime code targets BusyBox-compatible POSIX shell. Python and the tools
below are for developer and CI checks only; they are not copied to or run on a
router by these commands.

## Set up developer tools

Use Python 3.11 or newer and a project-local virtual environment. Install the
pinned developer requirements and make ShellCheck available on `PATH` using the
host's package manager. The shell runner also requires `shfmt` from the pinned
Python requirements. Storage tests compile a small C99 fixture with `cc`; a
working C99 compiler is required for that suite.

```zsh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

## Run checks

During an implementation package or subgoal, use focused checks:

```zsh
.venv/bin/python tools/test.py --focused tests/test_storage.py
```

Reserve the full local suite for the main-goal checkpoint. From the repository
root, the default command runs the full pytest suite,
Python lint/format/compile checks, and ShellCheck/shfmt checks for runtime shell
files. It also runs the planning checker, selected-shell syntax checks, and
`git diff --check`. It runs serially, disables pytest plugin autoload, and rejects
nonempty `PYTEST_ADDOPTS` so ambient settings cannot silently alter selection.
The runner does not install dependencies, access a router, or publish changes.

```zsh
.venv/bin/python tools/check.py
.venv/bin/python tools/test.py
```

The planning checker verifies all 156 specification/checklist subgoals, the 16
README goal links, active Markdown links and personal-path privacy. It makes no
runtime claim. The runtime runner fails if a required tool or test target is
missing; an empty or fully deselected pytest run is not accepted as proof.

Use `--focused` with an optional test path and `-k` for a narrower pytest run.
Static checks still cover runtime Python and shell files.

```zsh
.venv/bin/python tools/test.py --focused
.venv/bin/python tools/test.py --focused tests/test_storage.py -k fsync
```

On macOS, the runner selects `/usr/local/bin/bash --posix` as the host test
shell; it deliberately does not use macOS `/bin/sh`. This is host-shell evidence,
not BusyBox or router evidence. On Linux, it defaults to `/bin/sh`. Set
`CFMGR_TEST_SHELL` to a shell command when a focused local check needs another
compatible shell.

## BusyBox evidence

The required Linux CI job installs BusyBox and runs the full suite in required
mode. The runner preflights `busybox ash`, sets `CFMGR_REQUIRE_BUSYBOX=1`, and
fails if the BusyBox test target is absent or cannot start. The tests fail if
required native Linux `/proc` or BusyBox `fsync` evidence is unavailable. This is
Linux BusyBox evidence; it does not test the router firmware or live router
state.

To reproduce that CI check on a Linux host with BusyBox installed:

```sh
.venv/bin/python tools/test.py --require-busybox
```

The **Checks** workflow runs planning consistency, the full host suite and
static checks, plus the full suite with required Linux BusyBox storage coverage for `develop`
pushes and pull requests. It excludes changes limited to Markdown, images and
`.gitkeep` placeholders. Keep test commands, developer dependencies and any
required platform proof in the same package as the tests they support.
An eligible earlier push for predominantly unavailable platform proof runs full
CI, without adding a full local run solely for publication; follow the current
authorization and gates in [AGENTS.md](../AGENTS.md).
