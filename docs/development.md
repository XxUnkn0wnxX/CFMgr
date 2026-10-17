# Development checks

[Project overview](../README.md) · [Work and acceptance rules](../AGENTS.md)

Tools run on the developer host or CI. Router runtime remains POSIX shell.

## Setup

Use Python 3.11+, ShellCheck 0.11.0, a C99 compiler (`cc`), jq, GNU timeout,
sha256sum, curl and OpenSSL for the local TLS fixtures.
On macOS, host shell tests require Homebrew Bash at `/usr/local/bin/bash` and
the GNU utilities supplied by Homebrew coreutils. Reuse the project `.venv`;
create it if absent, then install pinned pytest, Ruff and shfmt:

```zsh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
```

## Local checks

```zsh
.venv/bin/python tools/test.py --focused tests/test_storage.py
.venv/bin/python tools/test.py --focused tests/test_install.py tests/test_prerequisites.py
.venv/bin/python tools/test.py
```

The runner also applies **Ruff lint/format, Python compilation, shell syntax,
ShellCheck, shfmt, package, planning/link and whitespace checks**. By
default pytest excludes optional diagnostic cases; `--include-diagnostics` opts in.
Use `--shellcheck-only` for shell lint alone, or `--skip-shellcheck` to run the
other checks without it.
`--focused` accepts test paths; add `-k expression` to filter them. Add
`--require-busybox` for required BusyBox ash proof. Its Linux mount cases require
passwordless `sudo` and the `coreutils`, `e2fsprogs`, `mount`, `sudo` and `util-linux`
packages. Keep `PYTEST_ADDOPTS` empty. Gate/publication rules are in [AGENTS.md](../AGENTS.md).

For documentation-only changes:

```zsh
.venv/bin/python tools/check.py
git diff --check
```

After changing runtime files, regenerate their catalog and manifest with
`.venv/bin/python tools/package.py --write`; `--check` verifies them without edits.
Use `--output PATH` to build a package in an absent or empty directory.

## CI and optional platform diagnostics

[Checks](../.github/workflows/checks.yml) runs
[Backup Checks](../.github/workflows/backup-checks.yml),
[Manager Checks](../.github/workflows/manager-checks.yml) and
[Status Checks](../.github/workflows/status-checks.yml) on Ubuntu host and vendor
BusyBox ash for develop pushes and PRs, with common statics once.
Documentation-only changes do not trigger CI.
[Tools Checks](../.github/workflows/tools-checks.yml) manually tests developer tools;
[Lint Checks](../.github/workflows/lint.yml) runs ShellCheck manually;
[Diagnostics Checks](../.github/workflows/diagnostics.yml) runs optional stress cases manually.
[Dev Checks](../.github/workflows/quick-checks.yml) manually selects focused
modules or individual tests for diagnosis. Router qualification remains beta work.

An optional Linux x86_64 guest diagnostic can build and run a pinned kernel
profile. It is not required CI or accepted router proof:

```sh
python3 tools/test_platforms.py --run --kernel 4.1.51
```

Profiles are in [platforms.json](../tests/fixtures/platforms.json). Without build
flags, `tools/test_platforms.py` validates that manifest offline.

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
