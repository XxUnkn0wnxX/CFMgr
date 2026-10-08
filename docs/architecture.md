# 🧩 Architecture

[← README](../README.md) · [Development](development.md) · [Compatibility](compatibility.md) · [Implementation plan](../PLAN.md)

![Runtime](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Status](https://img.shields.io/badge/design-in_development-orange)

This is a working developer guide. It separates implemented foundations from
the intended manager; [PLAN.md](../PLAN.md) owns the detailed contracts,
acceptance checklist and implementation record. The full documentation polish
follows implementation and validation.

## 🧱 Current implementation

The repository entry point is `cfmgr.sh`; its runtime helpers live in `modules/`.
POSIX shell sources the shell helpers and invokes the awk parsers directly.
There is no generated or compiled main script. The planned installed command
remains `cfmgr`.

The development entry supports help, version and the two equivalent health
commands. It does not install CFMgr or start a feature.

```mermaid
flowchart LR
    CLI[cfmgr.sh] --> Help[Help / version]
    CLI --> Doctor[--diagnostic / --doctor]
    Doctor --> Native[Native platform and synthetic command checks]
    Native --> Report[PASS / FAIL / SKIP report]
```

| Module | Implemented responsibility | Boundary |
| --- | --- | --- |
| `cfmgr.sh` | Development command dispatch and bounded module-path resolution | No operational startup or repair |
| `modules/diagnostic.sh` | Native health report, private synthetic probes and cleanup | Entware execution and full runtime inventory remain incomplete |
| `modules/common.sh` | Decimal/range/version/SHA-256 text validation | No filesystem, service or network work |
| `modules/json.awk` | Strict bounded JSON validation and token framing | Caller must acquire stable input and validate complete output |
| `modules/ip.sh` | Strict IPv4/IPv6 host normalization | Address syntax does not establish public eligibility or current WAN state |
| `modules/mountinfo.awk` | Select a covering mount; optionally report propagation and descendant counts | Snapshot facts do not establish persistent volume identity, writability or live mount stability |
| `modules/io.sh` | Private bounded captures, checked mount/topology snapshots and publication after cleanup | Internal library; volume approval and command supervision remain separate |
| `modules/storageinfo.awk` | Parse mount-ID, block-device and primary-superblock observations | Strict observation formats; label-bearing blkid reports cannot establish UUID identity |
| `modules/storage.sh` | Compare mount/device facts and read an ext UUID; optionally retain the original descriptors through a trusted callback | Observation does not grant write permission; no dependency execution or CLI integration |
| `modules/isolation.sh` | Own a private RAM root, verify native or fixed-probe mounts and remove them before deleting staging | Separate synchronous native and admitted fixed-probe APIs; no operational CLI |
| `modules/supervision.sh` | Bound fixed-probe startup polling and validate private terminal/capture records | Used by the fixed-probe lifecycle; admitted executable closure and explicit completion remain mandatory |
| `modules/closure.sh` | Stage a bounded fixed library/tool image and verify private copies against the supplied manifest | Copy/integrity only; caller must first bound manifest acquisition and independently approve provenance and ELF graph before execution |
| `modules/bootstrap.sh` | Check selected capabilities, install missing dependencies through existing Entware opkg and verify the result | Internal synchronous backend; admitted mount, serialized worker and hook scheduling remain caller prerequisites; doctor never calls it |

The parsing modules are tested foundations, not yet a complete operational call
path. See [development checks](development.md#-run-checks) for reproducible host
validation and the separate BusyBox evidence requirement.

## 🗂️ Storage and authority

| Location | Intended responsibility |
| --- | --- |
| `/jffs/scripts/cfmgr` | Installed public entry point |
| `/jffs/addons/CFMgr.d/` | Verified manager modules, private configuration and bounded durable recovery |
| `/jffs/addons/CFMgr.d/config` | Authoritative settings, typed credentials, saved activation and module catalog |
| Private RAM workspace | Transient requests, queues, observations, captures and staging |
| Verified Entware volume | Selected packages, cloudflared binary, tunnel runtime files and optional custom logs |
| User-selected backup drive | Manual data-only archives under `CFBackup/` |

Persistent settings and recovery stay in JFFS; frequent observations and retry
state stay in RAM. Missing storage must preserve saved intent and report waiting
or incomplete work. A mount label, `/dev/sd` name, directory or executable alone
cannot establish the expected volume.

The storage observer joins the held directory's mount ID to the current mount
table, checks the block device number and reads the primary ext superblock through
the original open descriptor. It repeats the path/mount/device checks before
staging its result. The descriptors remain open through observation and staging;
the private workspace is cleaned before the result is published.

The internal `cfmgr_storage_with` API instead runs a trusted callback after all
checks, passing the resolved directory, complete volume ledger and caller
arguments while both descriptors remain held. It returns status without
publishing callback output. The callback owns any external transaction guard
and cleanup; mounted trees and asynchronous users must stay outside IO scratch.
Ordinary return restores the caller's descriptors before cleanup. A signal-driven
exit may retain them until process exit, so interrupted setup must preserve its
external guard.

The internal `cfmgr_isolation_with` API builds on that retained callback. It
reserves a private guard outside IO scratch, checks the RAM/source topology,
then binds `/dev/null` and the held Entware directory into its own root. A
trusted synchronous callback receives the root, complete volume ledger and
unchanged arguments only after both mounts pass verification.

Cleanup checks each recorded mount again, removes Opt before null, and proves
both absent before deleting the guard. Busy, changed or uncertain mounts and
interrupted operations leave the guard for recovery. Existing guards are never
adopted or removed automatically. The native callback API does not launch a process inside the root. A separate
internal fixed-probe entry connects image staging and supervision as described
below; neither entry exposes an operational CLI action.

This first profile covers dynamic-revision ext2/ext3/ext4 primary superblocks.
Other filesystems, alternate `sb=` mounts and missing mount-ID support need
separate profiles. A matching observation does not prove writability, filesystem
health or uninterrupted device identity, and it cannot authorize a later write
through a freshly resolved path.

Backups contain configuration and inventoried data, including credentials; they
do not restore executable code or live process/queue/transaction state. The
current manager validates a restore and rebuilds its own integrations.

## ⚙️ Intended execution boundaries

The runtime language is BusyBox-compatible POSIX `sh`. Python, pytest and the
virtualenv are developer tools only. Shared operational prerequisites are `jq`,
`coreutils-timeout` and `coreutils-sha256sum`; scoped DNS/locking additions follow
the [compatibility policy](compatibility.md). Native recovery and health checks
must remain available when those packages cannot run.

| Boundary | Required behavior |
| --- | --- |
| Entry and hooks | Validate the action, apply guards and admit bounded work; no menu or unbounded wait from a firmware hook |
| Shared controller | Check current configuration, prerequisites, ownership and retry eligibility before starting work |
| DDNS and IP-Sync | Share current IPv4/IPv6 observations, retain independent outcomes and reconcile only configured targets |
| Cloudflared controller | Keep saved activation, binary maintenance, readiness and owned-process recovery distinct |
| Installer and updater | Verify the selected generation and complete staged artifacts before replacement; retain recoverable failures |
| Status and health | Report evidence without starting services, installing dependencies or contacting providers |

The DDNS hook is the explicit bounded-wait exception so it can report Merlin's
success/failure result. It must defer promptly during boot or missing readiness.
Only a failed or timed-out firmware DDNS attempt schedules the additional CFMgr
retry; successful completion does not schedule a forced update. Exact boot
release, overlap handling and the whole-action deadline remain implementation
gates.

<details>
<summary>Why checking a command or mount once is insufficient</summary>

An installed-package record does not prove that its executable loads, supports
the required arguments or still belongs to the expected mounted volume. A
successful parser exit does not prove its output was written completely. A
live process does not prove tunnel connectivity.

The intended controller checks the evidence appropriate to each boundary and
preserves unknown outcomes. Dependency installation, operational mount-loss handling and general command
supervision still need implementation and fault-path validation. The fixed-probe
helpers have a narrower contract and do not establish those guarantees.

</details>

<details>
<summary>🔒 Internal dependency execution proofs</summary>

Operational dependencies are to be installed by the existing Entware `opkg`
using its configured repositories and normal package/library resolution. CFMgr
checks required capabilities and verifies the result. Cloudflared is handled
directly through release binaries matched to supported kernel and userspace
architecture/ABI combinations; the kernel architecture alone is insufficient. The direct-IPK bootstrap and isolated-image work below
are internal proofs, currently unselected for operational installation. They
have no operational CLI wiring. The next design pass must simplify dependency
setup around opkg and decide which helpers remain useful; these proofs do not
establish an installer or require a replacement package-resolution mechanism.

Entware's loader reads absolute `/opt` paths before a program starts. An
explicit loader path alone therefore cannot contain execution when the public
mount path changes. The fixed-probe profile uses native bind mounts and chroot
to separate verified executable bytes from the mutable installation destination.
A small private RAM image provides the admitted programs, loader and libraries
at `/opt`, with a verified read-only bind and no preload file. The earlier restricted
installation proposal would expose the retained Entware directory separately at
`/offline/opt`. Version probes do not mount the mutable Entware directory
inside their root. Artifact provenance and ELF-graph admission remain caller
prerequisites; accepting supplied hashes does not establish trust. Before calling
the internal probe entry, the owner must construct/acquire the approved manifest
within 4096 original bytes in stable private RAM. Staging validates its length
after reading through EOF, so that check is not a bounded acquisition primitive.

The earlier direct-IPK catalogue, native fetch/extraction and acquisition
lifecycle have been retired. Their development history remains in Git and the
plan, but operational dependency setup does not use those APIs or choose package
versions/libraries itself. The supplied-manifest closure and fixed-probe helpers
remain independent internal proofs; they do not constrain opkg's dependency
resolution or constitute the normal package installer.

`cfmgr_bootstrap_dependencies` selects the shared jq, timeout and SHA256
capabilities, optionally adding tunnel DNS or Entware locking. Its production
paths are fixed under `/opt`; the explicit test entry selects a fixture root.
If all selected capabilities are usable, it runs no package command. Otherwise
it performs one ordinary opkg update and installs only missing/unusable direct
packages, then checks every selected capability again. A usable jq supplied by
an alternative package needs no replacement. Failed package work or failed
post-checks return failure; a later invocation rechecks rather than trusting a
success cache. Force-reinstall remains separate unfinished work.

Entware is required for operational features. This synchronous backend must be
called by an admitted, serialized dependency worker after verifying the expected
mounted storage; file existence alone is not that proof. It does not provide an
aggregate deadline or mount-loss containment, and the worker/feature launch
integration remains unfinished. `--doctor` and `--diagnostic` use only native
helpers and never invoke this backend, opkg or unverified Entware executables.

The existing native profile binds the expected Entware directory and `/dev/null`.
The outer native owner checks mount identity and removes its
exact mounts before deleting staging. Uncertain cleanup retains a guard and
workspace for recovery. The initial native ownership and cleanup code is in
`modules/isolation.sh`. Focused host fixtures cover its fault matrix; the separate
[Linux kernel lane](development.md#isolated-linux-kernel-checks) exercises actual
mounts, busy cleanup, interruption and controlled static/dynamic executable
mapping behavior. Its namespaces and compiler are developer tools only. The
[plan](../PLAN.md#mount-snapshot-parser-contract--current-package) records its
proof gates and the distinction from hostile-root security isolation.

Before any bind, the owner checks the native BusyBox unmount capability using
bounded help output. It selects the older `-D -n` or newer `-n` command while
preserving ordinary unmount and avoiding loop-device and mtab side effects.
Unknown capability stops the attempt before mounts; an actual cleanup failure
never triggers a retry with different flags. Firmware version numbers alone
do not select this behavior.

For contained probes, cleanup uses ordinary unmount's busy check:
admitted executable mappings retain the exact execution-image bind. Native
launcher completion and successful verified unmount are both required before
staging can be removed. A bounded polling helper records completion separately
from exit status; a polling deadline leaves the launcher unproved and the guard
retained. It never signals a saved numeric PID. The separate fixed-probe entry
accepts only the timeout or gzip version probe. It clears the active launcher
only when nothing started or the supervisor validated completion; a returned
failure or deadline alone cannot authorize cleanup. Even a pre-bind staging
failure requires a fresh unchanged/private RAM topology check before removal.
This does not promise complete process reaping or a hard deadline for blocked
kernel IO. Controlled host ELF tests do not expand the native callback's scope
or prove Entware ABI or Merlin runtime acceptance.

</details>

## 📦 Modules and forks

Modules remain readable source files. The shipped catalog defaults to `main`;
developers can manually select `develop` or a full commit hash in the main
configuration. Resolve a branch once, then acquire one immutable repository
snapshot with its manifest and hashes. Never combine newer per-file fallbacks
or execute catalog contents as shell code.

The **developer flag** defaults to `false`. When `true`, update/reinstall preserves
an existing catalog and normal manager update checks are suppressed. A missing
catalog may be seeded; malformed settings require repair. The detailed catalog
contract and fork examples are in the [development guide](development.md#-module-catalog-and-forks).

Normal startup and hooks do not fetch missing manager code. Installation and
repair own package acquisition; dependency checks do not authorize arbitrary
module downloads.
