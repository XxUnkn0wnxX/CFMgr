# ☁️ CFMgr

Cloudflare Manager for Asuswrt-Merlin — a terminal menu and command-line
manager for DDNS, one Cloudflared tunnel, and IP-Sync.

> [!WARNING]
> **Development recovery; not ready for router use.** Do not install or run
> this development version on a live router. The table below summarizes the
> intended product; it is not a report of completed or accepted features.

## Implementation status

**0 of 16 main goals complete (0%); 2 of 157 subgoals accepted (1.3%).**
The development code provides trusted-local fresh installation with private,
passive defaults and initial storage safeguards. Complete installation/dependency
repair and usable feature workflows remain unfinished. The [v2 plan](PLAN_V2.md)
defines the requirements, the [checklist](PLAN_V2_checklist.md) records acceptance,
and the [handoff](PLAN_V2_handoff.md) records current work and pending proof.

## 🧭 Planned product goals

| Area | Intended implementation | Status |
| --- | --- | --- |
| [Product scope](PLAN_V2.md#1-product-scope-and-boundaries) | Independent DDNS, one Cloudflared tunnel and IP-Sync in a native shell CLI. | Planned |
| [Installation and dependencies](PLAN_V2.md#2-installation-storage-and-dependencies) | Verified modular packages, private defaults, selected Entware tools and native recovery. | In progress — 1/9 accepted; storage guards passed focused CI, mount-keeper CI corrections passed local checks |
| [Menus, settings and status](PLAN_V2.md#3-configuration-menus-and-status) | Separate setup and On/Off controls, a compact dashboard and full health diagnostics. | In progress — 1/10 accepted |
| [Settings and recovery](PLAN_V2.md#4-save-cancellation-and-recovery) | Reviewed saves, resumable drafts, cancellation and safe interruption recovery. | Planned |
| [Cloudflared setup](PLAN_V2.md#5-cloudflared-setup-and-credentials) | Token, guided and advanced credential/configuration paths with reviewed hostname routing. | Planned |
| [Tunnel lifecycle](PLAN_V2.md#6-tunnel-lifecycle-and-binary-maintenance) | Guarded Start/Stop/Restart, readiness, watchdog recovery and verified binary maintenance. | Planned |
| [CFMgr updates](PLAN_V2.md#7-cfmgr-updates-source-selection-and-developer-mode) | Verified updates/reinstall, configurable sources and preserved settings across replacement. | Planned |
| [Shared address discovery](PLAN_V2.md#8-shared-address-discovery-and-reconciliation) | Current IPv4/IPv6 evidence, selected-WAN verification and shared discovery/reconciliation. | Planned |
| [DDNS](PLAN_V2.md#9-ddns) | A/AAAA reconciliation, remote drift repair and Merlin hostname/refresh integration. | Planned |
| [IP-Sync](PLAN_V2.md#10-ip-sync) | IPv4/IPv6 list reconciliation while preserving list identity and handling inactive families. | Planned |
| [Credential recovery](PLAN_V2.md#11-provider-failures-and-credential-repair) | Scoped authorization failure handling and credential repair without unintended reactivation. | Planned |
| [Hooks and schedules](PLAN_V2.md#12-hooks-schedules-and-boot-safety) | Identifiable owned hook blocks, safe repair, shared scheduling and bounded outage recovery. | Planned |
| [Logging](PLAN_V2.md#13-logging-and-rotation) | System messages plus optional per-feature Scribe logs and owned logrotate rules. | Planned |
| [Backup and restore](PLAN_V2.md#14-backup-and-restore) | Manual data-only archives, guarded restoration and independently selected backup storage. | Planned |
| [Uninstall and reset](PLAN_V2.md#15-uninstall-retained-installation-and-reset) | Retained-config uninstall, full wipe and scoped resets that preserve unrelated data. | Planned |
| [Compatibility and guidance](PLAN_V2.md#16-product-readiness-and-documentation) | Evidence-based support, usable operating guides and validated release readiness. | Planned |

## Scope

Features have independent setup and activation; checking status never enables or
repairs them. Cloudflare accounts and the relevant DNS/list resources are required.
The current scope is CLI-only; a WebUI is optional future work.

## Project links

- [Product specification](PLAN_V2.md) · [Implementation checklist](PLAN_V2_checklist.md)
- [Current handoff](PLAN_V2_handoff.md) · [Working rules](AGENTS.md)
- [Temporary development notes](docs/development.md)
- [GPL-3.0-or-later license](LICENSE.md) — Copyright (C) 2026 XxUnkn0wnxX.
