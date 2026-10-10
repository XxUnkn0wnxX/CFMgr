# CFMgr

Cloudflare Manager for Asuswrt-Merlin — a terminal menu and command-line manager.

> [!WARNING]
> **Active development — not ready for runtime use.** CFMgr is incomplete and
> has not passed router runtime acceptance. Do not install or run this development
> version on a live router. Passing developer tests do not establish safe router
> operation; installation instructions will follow validated implementation.

Completed milestones below have passed developer checks; router runtime
acceptance is still pending. See [PLAN.md](PLAN.md) for detailed progress.

| Feature / milestone | Status | At a glance |
| --- | --- | --- |
| Core foundations | Complete | Parsing, storage checks and managed workspaces |
| Worker safety foundations | Complete | Process deadlines and read-only workspaces |
| Health report | Partial | Native `--doctor` / `--diagnostic`; [current checks](docs/development.md#native-health-report) |
| Dependency setup | In progress | Source-only repair/reinstall worker; operational wiring pending |
| Settings and module catalog | In progress | Source-only config checks, shared path checks and a manifest parser; integration pending |
| Developer package inventory | Available to developers | Host-only [manifest command](docs/development.md#developer-package-inventory); trust gates remain open |
| Manifest reader and byte verification | In progress | Source-only [library APIs](docs/development.md#source-only-declared-file-verifier); final 50% gates underway |
| DDNS and IP-Sync | Planned | DNS updates and Cloudflare IP-list synchronization |
| Cloudflared | Planned | Tunnel setup, service controls and updates |
| Logging | Planned | Optional feature logs and rotation |
| Backup and restore | Planned | CFMgr-owned setup and data only |

These descriptions and their usage guides are updated after each finalized
milestone. A final consistency and polish pass follows complete implementation
and validation; it does not replace keeping the docs current during the build.

Implemented foundations include parsing, storage checks, guarded process
deadlines, internal workspaces and a partial native health report. Fixed probes
cover one native shell launch and the installed Entware `opkg --version`
response. The source-only serialized dependency worker can run the bundled
repair or selected reinstall backend inside an already admitted native root;
operational CLI, menu and installer wiring remain pending.

Source-only libraries validate configuration headers, catalogs and package
manifests with shared safe-path checks. A host-only Python command generates a
deterministic manifest from an explicit local Git commit. The native manifest
reader emits a checked canonical ledger, and the new verifier compares each
declared file's size and SHA-256 in a caller-prepared source tree. The full 50% local gate passes 1,843 tests with 38 platform skips;
exact-head Linux/BusyBox CI remains pending.
See [PLAN.md](PLAN.md) for checkpoint results and remaining work.

These checks do not establish source authenticity, complete package inventory,
compatibility, installed permissions or router acceptance. There is no
integrated config reader, catalog/acquisition workflow or installer, and no
catalog or manifest is shipped. Synthetic host/Linux evidence does not prove
installed-opkg provenance or Merlin behavior. Routine Entware upgrades remain
user-managed; normal repair installs only missing or unusable requirements.

Planned DDNS setup will replace Merlin's existing DDNS configuration and custom
DDNS handler. See the [setup guide](docs/setup.md#-prepare-the-router-and-selected-features)
for the replacement scope; the previous DDNS handler will not be backed up.

Normal operation will require working Entware. Its installed `opkg` manages
CFMgr's dependencies and their libraries; CFMgr manages Cloudflared release
binaries separately for supported kernel and userspace architectures.
`--doctor` / `--diagnostic` remain native diagnostics and work without Entware
or usable dependencies, without attempting package installation.

Runtime source lives in **`cfmgr.sh`** and **`modules/`**. Shared libraries and
parsers are in `modules/lib/`; supporting workers and dependency setup are in
`modules/helpers/`. These shell and awk files run directly; there is no
compilation step for the manager. Only diagnostics are connected to the current
CLI; operational feature wiring is still in development.

Planned features:

- Manage Cloudflare dynamic DNS (DDNS) using configuration-driven settings.
- Install `cloudflared` and guide tunnel setup with a wizard that prompts only for inputs needed by the selected features.
- Automate `cloudflared` updates, service lifecycle, and startup.
- Optionally reconcile available public IPv4/IPv6 addresses with Cloudflare Zero Trust IP lists for Access policies; IPv6 support remains provisional pending validation.
- Offer separate Cloudflared, DDNS, and IP-Sync file logs through configured Scribe/logrotate, with explicit logging setup and removal controls.
- Keep core configuration and small credentials in JFFS; use mounted Entware for the documented shared packages, Cloudflared and optional custom file logging.
- Provide an extended health report through `--diagnostic` / `--doctor`, with platform information, dependency checks and safe command tests.
- Back up and restore CFMgr's own setup and inventoried data, including Cloudflared configuration/certificates and eligible logs. It does not cover the whole router or unrelated add-on/provider setups, and excludes displaced pre-CFMgr `ddns-start` content and executable code.

Project documentation lives in `docs/`; planned screenshots belong in `.images/`.
Guides are reviewed with implementation milestones so current capabilities and
remaining acceptance limits stay explicit.

☁️ **Before setup:** create a Cloudflare account. For DDNS or public tunnel
hostnames, add a domain whose DNS is managed by Cloudflare; it can be registered
with Cloudflare or another registrar. The [user setup guide](docs/setup.md)
walks through account, domain and DNS preparation.

The implementation plan, build checklist, and handoff notes are maintained in [PLAN.md](PLAN.md).

🛠️ Contributors: [Development setup and testing](docs/development.md) covers the local virtualenv, pinned requirements, lint tools, and isolated test harness.

🧩 [Architecture](docs/architecture.md) explains the implemented foundations, planned execution boundaries and storage responsibilities.

🤝 [Contributing](CONTRIBUTING.md): all pull requests must target `develop`.

🔎 [Health-report development](docs/development.md#native-health-report) explains the current `--diagnostic` / `--doctor` checks, exit codes and remaining coverage.

🧭 [Firmware compatibility](docs/compatibility.md) records the measured target, older-release research, and remaining support gates. Tested commits are published to `develop` at major checkpoints after the full local suite passes, then verified by CI. This does not make development code a router release.

The `main` branch is intended for stable releases. The `develop` branch is for ongoing work.

CFMgr is distributed under the GNU General Public License, version 3 or later (GPL-3.0-or-later). See [LICENSE.md](LICENSE.md).

Copyright (C) 2026 XxUnkn0wnxX
