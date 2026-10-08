# CFMgr

Cloudflare Manager for Asuswrt-Merlin

> [!WARNING]
> **Active development — not ready for runtime use.** CFMgr is incomplete and
> has not passed router runtime acceptance. Do not install or run this development
> version on a live router. Passing developer tests do not establish safe router
> operation; installation instructions will follow validated implementation.

CFMgr is in initial development. The implementation has tested parsing and read-only storage foundations, plus a partial native health report; there is no installable manager yet.

Normal operation will require working Entware. Its installed `opkg` manages
CFMgr's dependencies and their libraries; CFMgr manages Cloudflared release
binaries separately for supported kernel and userspace architectures.
`--doctor` / `--diagnostic` remain native diagnostics and work without Entware
or usable dependencies, without attempting package installation.

Runtime source lives in **`cfmgr.sh`** and **`modules/`**. These shell and awk
files run directly; there is no compilation step for the manager.

Planned features:

- Manage Cloudflare dynamic DNS (DDNS) using configuration-driven settings.
- Install `cloudflared` and guide tunnel setup with a wizard that prompts only for inputs needed by the selected features.
- Automate `cloudflared` updates, service lifecycle, and startup.
- Optionally reconcile available public IPv4/IPv6 addresses with Cloudflare Zero Trust IP lists for Access policies; IPv6 support remains provisional pending validation.
- Offer separate Cloudflared, DDNS, and IP-Sync file logs through configured Scribe/logrotate, with explicit logging setup and removal controls.
- Keep core configuration and small credentials in JFFS; use mounted Entware for the documented shared packages, Cloudflared and optional custom file logging.
- Provide an extended health report through `--diagnostic` / `--doctor`, with platform information, dependency checks and safe command tests.
- Back up and restore configuration and owned data, including available configured log history. Backups do not contain executable code.

Project documentation and images will live in `docs/` and `.images/`.

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
