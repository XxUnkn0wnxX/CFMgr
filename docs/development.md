# Development checks

[Project overview](../README.md) · [Work and acceptance rules](../AGENTS.md)

These tools run on the developer host or CI. Router runtime remains POSIX shell.

## Setup

Use Python 3.11+, ShellCheck and a C99 compiler (`cc`). On macOS, host shell tests
also require Homebrew Bash at `/usr/local/bin/bash`. Reuse the project `.venv`;
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
shell syntax, ShellCheck, shfmt, planning/link checks and whitespace checks**.
Optional `-k` narrows focused pytest selection; keep `PYTEST_ADDOPTS` empty.
For documentation-only changes:

```zsh
.venv/bin/python tools/check.py
git diff --check
```

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
