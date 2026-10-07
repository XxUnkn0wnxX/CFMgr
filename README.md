# CFMgr

Cloudflare Manager for Asuswrt-Merlin

CFMgr is in the planning and initial development stage. This repository currently contains a project scaffold; there is no installable script yet.

Planned features:

- Manage Cloudflare dynamic DNS (DDNS) using configuration-driven settings.
- Install `cloudflared` and guide tunnel setup with a wizard that prompts only for inputs needed by the selected features.
- Automate `cloudflared` updates, service lifecycle, and startup.
- Optionally publish the router's WAN public IPv4 address to a Cloudflare Zero Trust IP list for use in Access policies.
- Support logging and log rotation only when Scribe is installed and configured. A re-detect action will enable the integration and restart the affected service when appropriate.
- Require mounted Entware storage for persistent configuration, credentials, logs, and larger files.
- Back up and restore the manager and its configuration, with log archives included when Scribe is installed and configured.

Project documentation and images will live in `docs/` and `.images/`.

The implementation plan, build checklist, and handoff notes are maintained in [PLAN.md](PLAN.md).

The `main` branch is intended for stable releases. The `develop` branch is for ongoing work.

CFMgr is distributed under the GNU General Public License, version 3 or later (GPL-3.0-or-later). See [LICENSE.md](LICENSE.md).

Copyright (C) 2026 XxUnkn0wnxX
