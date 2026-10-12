# Development checks

[Project overview](../README.md) · [Work and acceptance rules](../AGENTS.md)

These tools run on the developer host or CI. Router runtime remains POSIX shell.

## Setup

Use Python 3.11+, ShellCheck, a C99 compiler (`cc`), jq, GNU timeout and sha256sum.
On macOS, host shell tests require Homebrew Bash at `/usr/local/bin/bash` and
the GNU utilities supplied by Homebrew coreutils. Reuse the project `.venv`;
create it if absent, then install pinned pytest, Ruff and shfmt:

```zsh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

## Local checks

Run the relevant focused tests during implementation. Reserve the full suite for
the main-goal gate:

```zsh
.venv/bin/python tools/test.py --focused tests/test_storage.py
.venv/bin/python tools/test.py --focused tests/test_platforms.py
.venv/bin/python tools/test.py --focused tests/test_install.py tests/test_prerequisites.py
.venv/bin/python tools/test.py
```

Every test invocation also runs **Ruff lint/format checks, Python compilation,
shell syntax, ShellCheck, shfmt, package metadata, planning/link and whitespace checks**.
Bare `--focused` selects `tests/`; otherwise it accepts existing test files or
directories under `tests/`, including `--focused tests -k expression` for a
keyword-filtered run. Add `--require-busybox` to run that same selection with
required BusyBox ash evidence. Keep `PYTEST_ADDOPTS` empty.
On Linux, that explicit BusyBox mode also runs the selected real ext4 mount tests
using passwordless `sudo`, private mount namespaces, loop devices and temporary
images. They require Ubuntu's `coreutils`, `e2fsprogs`, `mount`, `sudo` and
`util-linux` packages. Normal host runs skip those privileged cases; required
BusyBox runs fail if their setup is unavailable. These are developer-host
requirements, not router dependencies.
For documentation-only changes:

```zsh
.venv/bin/python tools/check.py
git diff --check
```

After changing runtime files, regenerate their catalog and manifest with
`.venv/bin/python tools/package.py --write`; `--check` verifies them without edits.
Use `--output PATH` to build a package in an absent or empty directory.

## CI and optional platform diagnostics

The required [Checks workflow](../.github/workflows/checks.yml) uses one Ubuntu
24.04 runner for planning consistency, a cached native vendor BusyBox build, and
the selected suite under both the host shell and BusyBox ash. Develop pushes run
the full suite unless the final nonempty commit-message line is a valid
`CFMgr-Focused-Tests:` trailer with one to 16 distinct existing test paths, for
example:

```text
CFMgr-Focused-Tests: tests/test_prerequisites.py tests/test_install.py
```

Pull requests always run the full suite. Missing trailers select the full suite;
malformed or misplaced trailers fail the workflow. Focused routing still runs the
planning, package, static and required BusyBox checks. These are approximate
integration and shell-compatibility checks; they do not establish Merlin firmware,
kernel, flash, hook, or true-beta router behavior. Router acceptance is deferred
until implementation is complete. CI reuses validated Python tools, APT download
archives and the verified BusyBox binary; each runner still installs packages
normally.

An optional Linux x86_64 guest diagnostic can build and run a pinned kernel
profile. It is not required CI or accepted router proof:

```sh
python3 tools/test_platforms.py --run --kernel 4.1.51
```

Other profiles are listed in [platforms.json](../tests/fixtures/platforms.json).
Running `tools/test_platforms.py` without build flags validates that manifest
offline.

## Optional router probe

Copy `tools/router.local.json.template` to ignored `tools/router.local.json`, edit
its target and scratch path, and set file mode `600`. Prefer `"mode": "KEY"` for
passwordless key authentication through your normal SSH config; username and
password can be blank. `"mode": "USR"` requires `ssh_user` and `ssh_password` in
this private file. In either mode, a blank or `null` port inherits SSH config;
an integer overrides it. Verify the router's host key through your normal SSH
client first. The scratch directory must sit directly
below a mounted ext2/3/4 volume; the probe retains that directory.

```zsh
.venv/bin/python tools/router_probe.py --check-config
.venv/bin/python tools/router_probe.py --run
```

`--check-config` stays local. `--run` explicitly authorizes the small remote write
probe and scoped cleanup; inspect its output for success or retained artifacts.
