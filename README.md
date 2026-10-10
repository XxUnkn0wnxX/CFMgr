# ☁️ CFMgr

Cloudflare Manager for Asuswrt-Merlin — a command-line project.

> [!WARNING]
> **Work in progress — not ready for router use.** Do not install or run this
> development version on a live router.

## 🚧 Implementation checklist

| Feature | Status | At a glance |
| --- | --- | --- |
| Core foundations | Implemented | Parsing, storage checks and managed workspaces |
| Worker safety foundations | Implemented | Process deadlines and read-only workspaces |
| Health report | In progress | Native `--doctor` / `--diagnostic`; [current checks](docs/development.md#native-health-report) |
| Dependency setup | In progress | Source-only repair/reinstall worker; operational wiring pending |
| Settings and module catalog | In progress | Source-only [header](docs/development.md#config-header-report), [lifecycle](docs/development.md#config-lifecycle-report) and [catalog](docs/development.md#catalog-request-plan) reports; full settings/acquisition pending |
| Developer package inventory | Implemented | Host-only [manifest command](docs/development.md#developer-package-inventory) |
| Prepared package validation | Implemented | Source-only [manifest, tree, version and policy reports](docs/development.md#package-policy-report) |
| DDNS and IP-Sync | Planned | DNS updates and Cloudflare IP-list synchronization |
| Cloudflared | Planned | Tunnel setup, service controls and updates |
| Logging | Planned | Optional feature logs and rotation |
| Backup and restore | Planned | CFMgr-owned setup and data only |

## 📚 Documentation

- 📋 [Implementation plan and checklist](PLAN.md)
- ☁️ [User setup guide](docs/setup.md)
- 🛠️ [Development setup and testing](docs/development.md)
- 🧩 [Architecture](docs/architecture.md)
- 🔎 [Health-report development](docs/development.md#native-health-report)
- 🧭 [Firmware compatibility](docs/compatibility.md)
- 🤝 [Contributing](CONTRIBUTING.md) — pull requests target `develop`.
- ⚖️ [License: GPL-3.0-or-later](LICENSE.md) — Copyright (C) 2026 XxUnkn0wnxX.
