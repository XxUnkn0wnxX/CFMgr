# CFMgr

Cloudflare Manager for Asuswrt-Merlin — a terminal menu and command-line manager.

> [!WARNING]
> **Work in progress — not ready for router use.** Do not install or run this
> development version on a live router.

| Feature / milestone | Status | At a glance |
| --- | --- | --- |
| Core foundations | Implemented | Parsing, storage checks and managed workspaces |
| Worker safety foundations | Implemented | Process deadlines and read-only workspaces |
| Health report | In progress | Native `--doctor` / `--diagnostic`; [current checks](docs/development.md#native-health-report) |
| Dependency setup | In progress | Source-only repair/reinstall worker; operational wiring pending |
| Settings and module catalog | In progress | Source-only config, path and manifest checks; integration pending |
| Developer package inventory | Implemented | Host-only [manifest command](docs/development.md#developer-package-inventory) |
| Manifest reader and byte verification | Implemented | Source-only [library APIs](docs/development.md#source-only-declared-file-verifier) |
| Prepared source-tree report | Implemented | Source-only [namespace and byte check](docs/development.md#source-only-complete-tree-report) |
| Entry/manifest version check | Implemented | Source-only [literal version comparison](docs/development.md#source-only-entry-version-report) |
| DDNS and IP-Sync | Planned | DNS updates and Cloudflare IP-list synchronization |
| Cloudflared | Planned | Tunnel setup, service controls and updates |
| Logging | Planned | Optional feature logs and rotation |
| Backup and restore | Planned | CFMgr-owned setup and data only |

## Planned README

- Feature overview and supported router requirements.
- Installation, first-time setup and a quick start.
- Common menu and CLI workflows, updates, backup and restore.
- Troubleshooting and links to detailed guides.

## Documentation

- [Implementation plan and checklist](PLAN.md)
- [User setup guide](docs/setup.md)
- [Development setup and testing](docs/development.md)
- [Architecture](docs/architecture.md)
- [Health-report development](docs/development.md#native-health-report)
- [Firmware compatibility](docs/compatibility.md)
- [Contributing](CONTRIBUTING.md) — pull requests target `develop`.
- [License: GPL-3.0-or-later](LICENSE.md) — Copyright (C) 2026 XxUnkn0wnxX.
