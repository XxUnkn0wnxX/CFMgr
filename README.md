# CFMgr

Cloudflare Manager for Asuswrt-Merlin

CFMgr is in the planning and initial development stage. This repository currently contains a project scaffold; there is no installable script yet.

Planned features:

- Manage Cloudflare dynamic DNS (DDNS) using configuration-driven settings.
- Install `cloudflared` and guide tunnel setup with a wizard that prompts only for inputs needed by the selected features.
- Automate `cloudflared` updates, service lifecycle, and startup.
- Optionally reconcile available public IPv4/IPv6 addresses with Cloudflare Zero Trust IP lists for Access policies; IPv6 support remains provisional pending validation.
- Offer separate Cloudflared, DDNS, and IP-Sync file logs through configured Scribe/logrotate, with explicit logging setup and removal controls.
- Keep core configuration and small credentials in JFFS; use mounted Entware for Cloudflared and optional custom file logging. Native DDNS/IP-Sync work independently of Entware.
- Back up and restore configuration and owned data, including available configured log history. Backups do not contain executable code.

Project documentation and images will live in `docs/` and `.images/`.

The implementation plan, build checklist, and handoff notes are maintained in [PLAN.md](PLAN.md).

🛠️ Contributors: [Development setup and testing](docs/development.md) covers the local virtualenv, pinned requirements, lint tools, and isolated test harness.

🧭 [Firmware compatibility](docs/compatibility.md) records the measured target, older-release research, and remaining support gates. During initial testing, code remains local while documentation and requirements may be published to `develop`.

The `main` branch is intended for stable releases. The `develop` branch is for ongoing work.

CFMgr is distributed under the GNU General Public License, version 3 or later (GPL-3.0-or-later). See [LICENSE.md](LICENSE.md).

Copyright (C) 2026 XxUnkn0wnxX
