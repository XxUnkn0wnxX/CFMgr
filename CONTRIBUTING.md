# 🤝 Contributing

[← README](README.md) · [Development guide](docs/development.md) · [Architecture](docs/architecture.md)

> [!WARNING]
> CFMgr is in active development and is not ready for router runtime use.
> Passing developer checks do not replace firmware and router acceptance.

## 🌱 Target `develop`

**All contributions must target `develop`.** Create your branch from the current
`develop` branch and select `develop` as the pull request's base. Pull requests
targeting `main` are not accepted; `main` is reserved for reviewed stable releases.

Keep changes focused and explain the problem, resulting behaviour and validation.
For larger changes, check the contracts and remaining acceptance work in
[PLAN.md](PLAN.md) before changing behaviour.

## 🧪 Validate the change

1. Follow the [virtualenv setup](docs/development.md#-set-up-the-environment).
2. Run focused tests and relevant lint while making small commits. At a major
   checkpoint, pass `python tools/check.py` before pushing and require green CI
   before starting the next set of changes.
3. Include meaningful failure-path tests when changing runtime behaviour, and
   explain any changed test expectations.
4. Record what was actually tested. Keep host, BusyBox and router evidence
   distinct; leave untested firmware combinations clearly marked.
5. Update affected documentation with the change. Major milestones include a
   review of the README and development, architecture, compatibility, setup and
   fixture guides; record that review in the plan before publication.

GitHub Actions runs the same check command with BusyBox on Linux for code,
tests and tooling changes targeting `develop`. Documentation-only changes do
not trigger CI. Contributors should still check Markdown links, examples and
formatting locally.

Forks can use the same local runner without GitHub authentication. Include the
`develop` branch and workflow, enable Actions in the fork, and configure `gh`
only if using its publishing/PR/CI commands. See [GitHub CLI and fork setup](docs/development.md#github-cli-and-fork-setup).

## 🔒 Protect runtime boundaries

Router code uses BusyBox-compatible POSIX `sh`; Python and the virtualenv belong
only in developer tooling. Preserve unrelated router integrations, saved
configuration and private data. Do not add implicit deployment, service changes
or provider mutations to developer tests.

Never submit live configuration, credentials, private domains or router identity
data. Use synthetic fixtures and redacted examples. Keep modules readable and
document their boundaries; the architecture guide and plan describe the current
implementation and intended behaviour separately.
