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
.venv/bin/python tools/test.py
```

Every test invocation also runs **Ruff lint/format checks, Python compilation,
shell syntax, ShellCheck, shfmt, package metadata, planning/link and whitespace checks**.
Optional `-k` narrows focused pytest selection; keep `PYTEST_ADDOPTS` empty.
For documentation-only changes:

```zsh
.venv/bin/python tools/check.py
git diff --check
```

After changing runtime files, regenerate their catalog and manifest with
`.venv/bin/python tools/package.py --write`; `--check` verifies them without edits.
Use `--output PATH` to build a package in an absent or empty directory.

## Linux platform checks

The [Checks workflow](../.github/workflows/checks.yml) declares the system
prerequisites and runs the full host, required BusyBox and kernel jobs. Explicit
platform builds require Linux x86_64 and download pinned fixtures:

```sh
python3 tools/test_platforms.py --native-busybox
PATH="$PWD/.tmp/native-busybox/bin:$PATH" .venv/bin/python tools/test.py --require-busybox
python3 tools/test_platforms.py --run --kernel 4.1.51
```

Other kernel profiles are in [platforms.json](../tests/fixtures/platforms.json).
Running `tools/test_platforms.py` without build flags validates that manifest
offline. Generic platform checks are separate from live router acceptance.

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
