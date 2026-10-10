# 🧭 Firmware compatibility

[← README](../README.md) · [Development](development.md) · [Implementation plan](../PLAN.md)

![Runtime](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Evidence](https://img.shields.io/badge/evidence-source_%2B_read--only_probes-blue)
![Acceptance](https://img.shields.io/badge/runtime_acceptance-pending-orange)

CFMgr aims to support Merlin by the capabilities each feature needs. **No
firmware is declared fully supported yet.** This evidence snapshot was collected
on **8–10 October 2026**; individual feed and source snapshots retain their
recorded dates. Source inspection, harmless installed-tool probes, host tests,
and complete router acceptance are different levels of proof.

## 📋 Representative firmware

| Model / firmware sample | Shell arithmetic | Transport evidence | Evidence level |
| --- | --- | --- | --- |
| RT-N16 / `378.50` | Signed 32-bit expected; BusyBox 1.20.2 | curl 7.21.7 source; OpenSSL 1.0.0p/TLS 1.0. Native curl CLI installation unproved. | Pinned release source |
| RT-N66U / RT-AC66U / `380.70` | Signed 32-bit expected; BusyBox 1.25.1 | curl 7.54.1/OpenSSL 1.0.2n; build installs the curl CLI. | Pinned release source |
| RT-AC68U / `386.14` | Signed 32-bit expected; BusyBox 1.25.1 | curl 8.4.0/OpenSSL 1.1.1w source. | Pinned release source |
| GT-AX11000 / `3004.388.12_2` | Signed 32-bit **observed**; BusyBox 1.25.1 | Native curl 8.17.0/OpenSSL 1.1.1w; CA file and relevant options present. | Matched source and installed read-only probes |

The sampled releases disable BusyBox's 64-bit shell arithmetic. Its implementation
then uses signed `long`, which is 32 bits on the sampled userspace ABIs. No
sample showed a smaller integer range. This does not establish every model,
fork, build override, or installed tool's behavior. The current target has an
aarch64 kernel with an ARM32 native BusyBox, illustrating why `uname -m` alone
is insufficient. [BusyBox arithmetic types][math] · [ARM32 ABI][abi]

## Representative official image snapshots

These three ZIPs were checked as static image data. They represent selected
releases, not supported model families. GT-AX11000 is the standard non-ROG
firmware member; the paired ROG member was inventoried but neither extracted nor
compared.

| Official release ZIP | Image and native userland facts | Verified ZIP SHA-256 |
| --- | --- | --- |
| [GT-AX11000 `3004_388.12_2`](https://sourceforge.net/projects/asuswrt-merlin/files/GT-AX11000/Release/GT-AX11000_3004_388.12_2.zip/download), published 2026-08-20 | UBI/UBIFS; AArch64 kernel image, 4.1.51 banner; BusyBox/curl/wget/OpenSSL CLIs are ELF32 ARM little-endian with `/lib/ld-linux.so.3`; libc 2.26 and OpenSSL 1.1.1w banners; ROM CA file 227,375 bytes | `2f7685a95c8072f1734a06bbafdfae349d1c2e826f3ddf3294099a77a33df32f` |
| [RT-AX88U_PRO `3006_102.9_0`](https://sourceforge.net/projects/asuswrt-merlin/files/RT-AX88U_PRO/Release/RT-AX88U_PRO_3006_102.9_0.zip/download), published 2026-09-23 | SquashFS 4.0 XZ; AArch64 kernel image, 4.19.183 banner; BusyBox/curl/wget/OpenSSL CLIs are ELF32 ARM little-endian with `/lib/ld-linux.so.3`; libc 2.30 and OpenSSL 3.5.8 banners; ROM CA file 181,713 bytes | `2b91a0ea4745c1277d12c6dd3109dda0c11527929d6895a4f67d3e877a2abed2` |
| [RT-BE96U `3006_102.9_0`](https://sourceforge.net/projects/asuswrt-merlin/files/RT-BE96U/Release/RT-BE96U_3006_102.9_0.zip/download), published 2026-09-23 | SquashFS 4.0 XZ; AArch64 kernel image, 4.19.294 banner; BusyBox/curl/wget/OpenSSL CLIs are ELF32 ARM little-endian with `/lib/ld-linux.so.3`; libc 2.32 and OpenSSL 3.5.8 banners; ROM CA file 181,713 bytes | `883dad9970619e8341fceb64440f67d4eb1e5ee9f70b98b154c0b13df254a4b8` |

ELF class, machine and interpreter, filesystem format, image paths and embedded
IKCONFIG are decoded facts. Kernel, libc, BusyBox, curl and OpenSSL version
numbers are embedded banner strings, not results from invoking those programs.
All three images contain real `/bin`, `/sbin`, `/lib` and `/usr` directories;
the AArch64 kernel does not change the ARM32 ABI of the shipped native command
line tools. All three embedded kernel configurations disable
`CONFIG_NAMESPACES`, enable procfs/tmpfs/devtmpfs/compat and ext4, and disable
the separate ext2/ext3 drivers. This is build configuration, not a live mount,
device-policy or boot test. It does not by itself establish how CFMgr's bind and
chroot paths behave on a router.

The static image map also contains `/etc/nsswitch.conf` (196 bytes),
`/etc/wgetrc` (50 bytes), `/etc/openssl.cnf` (2,050 bytes on GT and 2,234 on
the other two), and the CA bundle sizes listed above. The source-only
`cfmgr_isolation_native_config_root_with` composition stages these four files
plus `/etc/hosts` and `/etc/resolv.conf` before any bind. Each of the five
non-CA files is capped at 65,536 bytes; the CA cap is 1 MiB. The extended files
are copied and compared as opaque data, including binary/NUL bytes. The image
`/etc` links and init-time rewrites do not establish live router contents, and
copying does not establish NSS behavior, OpenSSL policy, certificate trust or
successful network/TLS use. Older root APIs keep the two-file hosts/resolver
stager. This internal composition adds no payload, opkg or operational worker
path. Full local and Linux/BusyBox validation pass for this composition;
router runtime acceptance remains separate.

The ignored local cache at `.tmp/firmware-audit/INDEX.md` records the audit
method, provenance, selected paths and evidence limits. Read that index before
repeating work and reuse its verified local artifacts where applicable; its
archive, image, extracted data, certificates and raw reports stay ignored and
must not be committed. `audit.py` can rewrite provenance, so consult the cache
instructions before rerunning it. The exact official archive URLs and hashes
are listed above and in the local provenance record.

The coverage map records 33 explicit native tool names per sample and 58 pinned
source files, including `ln`/`chmod` and the current closure/supervision
consumers. The cached integrity/static review passed in 3.755 seconds. Static
file/link graphs and source/config inspection do not establish loader behavior,
TLS or trust, NSS/socket readiness, hook execution, installed router state or
compatibility across every model/build.

<details>
<summary>🔗 Pinned source evidence</summary>

- **378.50** — [BusyBox configuration][378-math], [TLS maximum][378-tls],
  [curl installation rule][378-curl].
- **380.70** — [BusyBox configuration][380-math], [model definitions][380-models],
  [curl installation rule][380-curl].
- **386.14** — [BusyBox configuration][386-math], [ARM toolchain][386-toolchain],
  [curl version][386-curl].
- **3004.388.12_2** — [BusyBox configuration][388-math]. Source is pinned to
  `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f`, matching the installed release tag.

Older MIPS and ARM toolchains also select 32-bit uClibc versions whose `time_t`
is signed `long`. That supports a source-derived 2038 boundary; installed date
behavior has not been tested. [MIPS toolchain][380-toolchain] ·
[ARM toolchain][386-toolchain] · [Official uClibc releases][uclibc]

</details>

## BusyBox unmount capabilities

The checked official `3006.102.9` release still selects BusyBox **1.25.1**.
The current `3004.388`, `3006.102-wifi6` and `main` sources also select that
shared version; the reviewed Wi-Fi 6 and Wi-Fi 7 router trees use the shared
router directory. This is source/build evidence, not an installed measurement
for every model. A firmware-family number alone does not identify its BusyBox
capabilities. [3006 release version](https://github.com/RMerl/asuswrt-merlin.ng/blob/69838e4a60564e5550e97f11d8a8cf2c6260c4f0/release/src/router/busybox/Makefile#L1)
· [Build selection](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src-rt/Makefile#L133)
· [Wi-Fi 6 branch version](https://github.com/RMerl/asuswrt-merlin.ng/blob/2df5b849fdf7af5e9f887703390cc5924c67def9/release/src/router/busybox/Makefile#L1).

BusyBox changed its loop-device behavior between upstream 1.26.2 and 1.27.0.
Older builds release loop devices by default and use `-D` to suppress that;
newer builds require `-d` to request release and no longer accept `-D`.
[Exact upstream change](https://github.com/mirror/busybox/commit/a98db793cffb77a8794c854443b8fe12bad98c0a).

The isolated-root owner checks the actual native `umount --help` before creating
mounts. It requires bounded, complete BusyBox help with one unambiguous supported
loop-option description. Older capability selects `umount -D -n PATH`; newer
capability selects `umount -n PATH`. Both use ordinary unmount, suppress mtab
writes and avoid loop-device release. Unknown, conflicting or incomplete help
fails before any bind; an unmount failure never triggers an alternate command.
This supports the two recognized capability profiles without assuming all future
firmware is compatible. Help-disabled builds and changed descriptions require
review. Kernel, ABI, storage and full router acceptance remain separate gates.

## Native worker and execution-root evidence

The matched native cron source creates a process group before launching a job.
CFMgr independently verifies the actual original shell's PID/group identity and
uses a native guarded watchdog with cooperative completion. Cancellation signals
its current group, avoiding stored numeric PID reuse. Linux/BusyBox tests prove
those internal paths; operational cron dispatch and router acceptance are still
pending. A blocked kernel task or externally stopped watchdog cannot be given an
unconditional userspace termination guarantee.

A brief read-only probe on 9 October found canonical `/bin`, `/sbin`, `/lib` and
`/usr` directories on the target's readonly UBIFS root. Native BusyBox is ELF32
ARM with interpreter `/lib/ld-linux.so.3`; an AArch64 loader also exists. `/etc`
resolves to `/tmp/etc`, and `/usr/local/share` to `/tmp/share`. Those facts do not
prove a complete loader, resolver, TLS or NSS environment inside a new root.

The separate execution-root entry owns a readonly RAM bind, verifies its actual
descriptor mount identity, preserves its guard and requires checked ordinary
teardown plus successful IO cleanup before returning an ordinary callback
status. The native-root entry now adds four fixed readonly views for `/bin`,
`/sbin`, `/lib` and `/usr`, with independently checked source and child mount
identities. The native-data variant stages `/etc/hosts` and
`/etc/resolv.conf` as opaque, exact bytes of at most 65,536 bytes each before
any bind; the base readonly root then protects the staged files against writes.
It does not parse or test resolver readiness. Host fixtures cover byte handling
and failure retention. The 36% native-tmp variant adds one checked writable
tmpfs child with canonical size limits of 64–65,536 KiB in multiples of 64 and
8–8,192 inodes. Its mount uses `rw,nosuid,nodev,exec`, `mode=700`, and the exact
requested size/inode ceilings; it creates an empty mode-`0700`
`/tmp/cfmgr-home` while leaving the observer's `HOME` unchanged. These ceilings
limit tmpfs use but do not reserve RAM or establish available memory headroom.

The earlier accepted 37% snapshot passed the full local suite (1,567 tests, 29
explicit platform skips), Linux/BusyBox CI (1,596 tests, zero skips), six
supplemental stripped-ash checks and its nine kernel scenarios. Exact results
and the fixture setup repair are recorded in [PLAN.md](../PLAN.md). Those
results predate the fixed native-device extension below.

The retained-Opt composition uses the ninth scenario. Its host tests cover
success, busy-Opt cleanup refusal and malformed API rejection, plus cheap
storage-admission boundary cases; the upgraded full-capture BusyBox consumer is
distinct from host mirrors. The kernel proof checks a real writable source
mounted through FD9, a bounded anchored write reaching that source, and
Opt-first teardown followed by an exact empty readonly fallback before tmpfs
removal. FD8 is a regular fixture file with synthetic metadata observation, so
the scenario does not prove physical block-device or UUID approval.

The fixed native-device layer adds only private-image `/dev/null` (1:3) and
`/dev/urandom` (1:9), mounted as separate read-only, `nosuid`, `noexec`
device-enabled children. The base-root `nodev` fallback refuses new opens after
unmount, but does not revoke already-open descriptors; before/after inode
checks are not a continuous FD lease, so the private source image must remain
frozen. The same ninth kernel scenario now witnesses a real BusyBox FD5 making
unmount busy, closes it to allow cleanup, and checks new-open refusal. Host busy
faults separately cover runtime guard retention. The full Mac suite and
[40% Linux/BusyBox checkpoint](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37950451858)
pass, including six stripped-ash checks and all nine kernel scenarios with the
extended configuration composition. Exact commits, counts and timings are
recorded in [PLAN.md](../PLAN.md).

Neither host nor Linux namespace evidence establishes router acceptance. The
internal native-config-root entry stages six fixed files, but does not establish
their runtime semantics or provide complete loader/helper/ELF, TLS or NSS
closure and ordinary opkg execution. The separate `cfmgr_native_shell_probe`
permits one fixed synchronous native shell/BusyBox invocation from the checked
native-config callback. It supplies a clean child environment, omits loader
cache/preload files, and keeps the root descriptor through chroot before closing
it inside. Host tests cover its admission, capture and failure rules; the Linux
fixture adds genuine host-native dynamic BusyBox execution and descriptor
witnesses. See [PLAN.md](../PLAN.md) for the current checkpoint result. This
does not establish ARM32/native firmware execution or NSS/TLS/config semantics.
The observer's own `HOME` remains unchanged, and this is not an operational
worker. No mount or chroot was
executed on the router for these checks.

The O9b source snapshot adds `cfmgr_worker_native_probe`, which composes the
fixed shell check with the existing native process-group deadline, retained
storage descriptors and checked native-config-root cleanup. It returns an
ordinary probe result only after root and outer storage/IO cleanup both report
exact success; uncertain or inconsistent completion remains guarded. This
source-only helper does not install cron, launch opkg or establish an operational
dependency worker. Its tenth Linux scenario uses a synthetic storage-acquisition
boundary while exercising real deadline, root/chroot and cleanup behavior; it
does not prove physical storage or UUID admission, actual outer storage IO
acquisition, ARM32 firmware execution or router acceptance. The O9b 42%
[Linux/BusyBox gate](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37973995819)
is retained as the historical worker-composition baseline. Synthetic storage
acquisition still leaves physical block-device/UUID admission and outer storage
IO acquisition unproved. See the
[fixture guide](../tests/fixtures/README.md) and [PLAN.md](../PLAN.md).

The O9c extension adds `cfmgr_native_opkg_probe ROOT EXPECTED_VERSION` beside
the unchanged fixed shell probe. It checks an independently approved 1–128 byte
printable-ASCII version against the exact `opkg --version` response; the version
is comparison data only and is never passed to the child. The new
`execution/opkg-version` captures and ledger are separate from the shell-probe
evidence. A successful string check does not establish opkg provenance: the
caller must already trust the stable installed static code/profile and exclude
conflicting writers. The source-only worker composition still invokes only its
fixed shell probe; no operational dependency worker or package installation was
added.

The ninth Linux kernel scenario now also invokes a trusted synthetic static
opkg stand-in to witness the fixed command, clean environment and working
directory, closed inherited descriptors, and retained Opt marker read. It does
not run Entware opkg or prove ARM, router, NSS or TLS behavior. All ten scenarios
passed the O9c 43% gate at candidate `d0a04b3a6d2e57464803039255bccafc97d0e79c`
in [Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37977771431).
CI exercised the actual BusyBox grammar representative. Full local, CI and
focused test counts are recorded in [development checks](development.md#-run-checks)
and [PLAN.md](../PLAN.md). These are synthetic host/Linux proofs, not real opkg
installation, executable provenance, Entware/ARM ABI or Merlin acceptance.
The fixed version check in this O9c snapshot did not add repair behavior; the
42% gate cited above remains historical O9b evidence.

The O10a `cfmgr_native_dependencies ROOT BOOTSTRAP_SOURCE ACTION SCOPE
LOCK_PROVIDER` helper now provides a fixed source-only handoff to the bundled
normal repair or explicit selected-reinstall backend. Its trusted source,
admitted retained-Opt/native-config root, storage authority, group/deadline and
checked teardown remain caller prerequisites; source-path bounds do not prove
code provenance. It preserves opkg's configured feeds, package/dependency
resolution, locking, scratch-directory selection and normal configure-unpacked
behavior. The existing backend clears `TMPDIR`, but opkg configuration can
still select another `tmp_dir`; the private tmp quota is not a bound on all
package scratch writes. Normal repair skips healthy requirements and installs
only missing or unusable mapped tools. Selected force reinstall remains
separate. CFMgr serializes only its own workers and does not promise a global
external-writer exclusion or preservation of unrelated half-installed
packages.

The host consumer tests execute the actual bundled backend with inert opkg and
capability stand-ins, including a 32-KiB package-file write without a tiny
launcher file limit. The ninth Linux scenario now also runs a trusted synthetic
static backend stand-in through the native root. The accepted 44% checkpoint
passes the full local check (1,734 tests, 33 explicit platform skips) and
Linux/BusyBox (1,767 tests, no skips); all ten kernel scenarios pass, including
native-root in 7.55s. The ninth scenario's opkg and capability programs and its
storage metadata are synthetic. These checks do not establish real opkg
provenance, router execution or firmware ABI. This 44% snapshot added no menu,
installer or router-side package operation. Exact results are in [PLAN.md](../PLAN.md).

The accepted 45% checkpoint adds a source-only bounded dependency worker. It requires
native process-group and lock/deadline behavior, a trusted fixed runtime bundle,
and caller-supplied retained-storage authority. The new lifecycle also resolves
native `rmdir` through the finite IO tool map; this host-only implementation has not
verified that applet on Merlin. It preserves normal configured opkg scratch and
package-configuration behavior. The eleventh Linux fixture combines the worker
with host locking, deadline, retained-Opt/root cleanup and synthetic opkg repair.
It passes in 8.86s; the full Linux/BusyBox suite passes all 1,792 tests with no
skips. This establishes the controlled host composition, while Merlin router,
ARM32 ABI, installed opkg provenance and firmware acceptance remain unproved.

The preceding 46% checkpoint added standalone AWK parsers for a config-header
projection and source-catalog grammar. The full local gate passes 1,812 tests
with 36 explicit platform skips in 688.43s. Exact Linux/BusyBox CI passes all
1,848 tests in 96.81s, including the two new actual-BusyBox parser cases, and
all eleven unchanged kernel scenarios. This preserves the earlier worker
composition evidence. Matching Merlin awk behavior, full config validity and
an integrated config/catalog runtime path remain unproved.

The accepted 47% checkpoint adds a shared source-relative package-path helper
and a bounded manifest grammar parser. Full local checks pass 1,819 tests
with 37 explicit platform skips. Exact
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38002057996)
passes 1,856 tests with zero skips and all eleven kernel scenarios. The accepted
47% parser checkpoint is followed by the accepted 48% host inventory tool,
with full local and [exact Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38046534095) passing. The manifest declares a version,
config-schema and package-api value, plus file paths, sizes, SHA-256 text and modes; successful parsing validates
those fields as data only. It does not prove that declared bytes match, that
the inventory is complete or trusted, that the declared APIs are compatible,
or that installation is safe. Matching Merlin AWK behavior for these parser
grammars remains unproved.

## 🧩 Qualify each feature separately

| Feature | Required capability | Current boundary |
| --- | --- | --- |
| Core manager, DDNS, IP-Sync | POSIX shell, verified HTTPS/CA trust, bounded IO/locking, JFFS/RAM state and usable shared Entware prerequisites | Native recovery diagnostics remain available when prerequisites fail. Complete runtime acceptance remains pending. |
| Current storage-observation profile | Inherited descriptor mount IDs, native numeric device listing and bounded hexdump; dynamic-revision ext2/ext3/ext4 primary superblock | Read-only foundation only. Other filesystem profiles, writability and storage-loss containment remain pending. |
| Integrity verification | Required `coreutils-sha256sum`; native OpenSSL retained for bootstrap and edge fallback | Both produced the same synthetic digest on the current router. Fallback does not waive failed required-package installation. |
| Source-only dependency worker | Native process-group and lock/deadline behavior, retained storage/root and fixed `rmdir` lookup | Accepted 45% host/Linux composition; no operational entry wiring or Merlin compatibility is claimed. |
| Config-header/catalog parsers | AWK, bounded immutable input and exact status/ledger checks | Data-only grammar and framing checks; the native catalog planner is listed below. Full config reading, source trust and Merlin runtime acceptance remain pending. |
| Shared package paths and manifest parser | Functions-only AWK helper explicitly loaded before the manifest parser | Accepted 47% host/BusyBox data-format proof; declared data checks only, with no trusted acquisition, file hashing, completeness or Merlin runtime proof. |
| Developer package inventory | Developer-host Python 3.11+ and local Git objects | Accepted 48%; host tool only, not a router dependency or Merlin compatibility claim. Trust and installation gates remain open. |
| D4 native manifest report | BusyBox-compatible POSIX `sh`, existing IO owner, native `cat`/AWK, trusted immutable files | Accepted 49% host and Linux/BusyBox evidence; no deadline, authentication or Merlin runtime acceptance is established. |
| D5 declared-file verifier | BusyBox-compatible POSIX `sh`, bounded pre-acquired immutable source, native `wc`, OpenSSL and `hexdump` | Focused package checks pass (14 passed /1 local BusyBox skip in 6.87s); path-with-spaces fixture regressions pass 2/2 in 0.84s. Accepted 50%: full local passes 1,843 tests /38 platform skips in 571.13s; exact-head Linux/BusyBox CI passes 1,881 tests /zero skips, six stripped-ash cases and all eleven kernel scenarios. Missing production `hexdump` fails closed. No source authentication, directory completeness, permission check or Merlin acceptance is established. |
| D6 complete prepared-tree report | BusyBox-compatible POSIX `sh`, native `find`, the existing IO owner, native `wc`, OpenSSL and `hexdump` | Accepted 51% source-tree check compares a manifest-derived expected namespace and declared bytes. Full local passes 1,848 tests /38 platform skips in 500.19s; exact-head [Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38052708576) passes 1,886 tests /zero skips, six stripped-ash checks in 7.13s and all eleven kernel scenarios in 31.24s. Matched Merlin traversal can silently omit paths on `readdir` error, so caller-owned healthy acquisition remains required. No authentication, semantic compatibility, installed-permission or router acceptance claim. |
| D7 entry-version report | D6 tree/digest capabilities plus BusyBox-compatible POSIX `sh`/AWK and bounded immutable entry source | Accepted in the 52% host/Linux checkpoint. Its parser reads `cfmgr.sh` as data and checks literal equality with the manifest. It does not establish required-module/API semantics, no-downgrade policy, source trust/acquisition, installed permissions, activation or router acceptance. |
| D8 supplied package policy | D6/D7 package checks, existing native size observation and `cfmgr_version_compare` | The report checks a caller-selected installed-version floor and exact manifest destination/mode requirements. Requirements-file trust and complete-profile selection stay with the caller; source authenticity, semantic compatibility, acquisition, installed permissions, activation and router acceptance remain unproved. See [PLAN.md](../PLAN.md) for the validation record. |
| D9 catalog request plan | BusyBox-compatible POSIX `sh`, existing IO owner, native `cat`/AWK and trusted path/manifest parsers | Source-only join maps a parsed catalog to a separately supplied manifest by destination and pins URLs to a caller-provided commit. It does not prove the manifest came from that URL, branch-to-commit correspondence, repository authenticity, complete profile, source-byte validity or installation. See [PLAN.md](../PLAN.md) for validation. |
| D10 config-header report | BusyBox-compatible POSIX `sh`, native `cat`/AWK, JSON and header parsers, existing IO owner | Reads private JSON up to 65,536 bytes and uses a fixed 131,072-byte token-output profile to return only schema marker, generation and developer flag. It does not validate all settings or credentials, inspect installed configuration, provide defaults/persistence or establish router acceptance. |
| Cloudflared | Verified mounted Entware storage, supported official binary ABI/kernel, integrity and version checks | Modern official assets do not cover MIPS; older ARM kernels may also fail the selected binary's minimum. |
| Optional file logging | Mounted Entware plus configured Scribe/logrotate | Current Scribe/includes were inspected; no service or rotation was exercised. |
| Backup/restore | Native archive/integrity tools plus an explicitly selected mounted drive | Planned for CFMgr-owned setup/data, including Cloudflared configuration, certificates and eligible logs; excludes whole-router/NVRAM, unrelated add-on/provider setup and displaced pre-CFMgr hooks. Runtime restore safety remains unproved. |

For D6, matched `3004.388.12_2` and `3006.102.9` source
configurations enable BusyBox `find`, and the retained representative image
inventories contain `/usr/bin/find` as a link to BusyBox. The pinned
[3004 `find` implementation](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/findutils/find.c)
supports the plain `find . -print` form used here without following links by
default. Its
[recursive traversal implementation](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/libbb/recursive_action.c)
does not distinguish `readdir` error from EOF or report `closedir` failure.
This is matched source/image capability evidence only; it does not establish
the API's full checkpoint result or runtime acceptance on a router.

For D7, matched Merlin BusyBox 1.25.1 AWK source supports the parser's
record-separator and byte-length framing under the C locale. This source review
is distinct from host-AWK and actual-BusyBox developer tests, and neither is
router runtime acceptance. D8 reuses this parser plus the existing version
comparator and native size helper; its structural-policy checks add no new
firmware applet requirement.

For example, the inspected Cloudflared `2026.10.0` packaging uses Go 1.26,
provides ARM/ARMHF/ARM64 and x86 builds, and has no MIPS asset. Go requires Linux
3.2 or newer. The sampled legacy MIPS kernel is 2.6.22.19 and RT-AC68U's is
2.6.36.4. Those samples cannot qualify for that modern binary merely because
Entware works. Native DDNS/IP-Sync eligibility is evaluated separately.
[Cloudflared packaging][cf-packages] · [Go version][cf-go] · [Go platform minimums][go-min]

The current storage observer needs `mnt_id` in proc descriptor information.
Mainline Linux added this in 3.15; older vendor kernels need a verified backport
or a separate observation profile. An Entware feed name such as `k3.10` does not
establish this capability. The measured router exposes it, and lightweight
native hexdump/device-listing probes passed; assembled CFMgr runtime acceptance
is still pending. [Linux 3.15 descriptor information](https://github.com/torvalds/linux/blob/v3.15/fs/proc/fd.c#L47).

## 🔧 Rules for native implementation

- Validate numeric text before arithmetic. Keep values **and intermediate
  results** within signed 32-bit bounds; use capped seconds/counters instead of
  epoch milliseconds. Preserve large IDs, JSON numbers and version fields as text.
- Parse IPv4 octets and IPv6 groups separately. Avoid whole-address integer
  arithmetic. Memory, input-depth and action limits need their own measured caps.
- Detect usable native commands. The current isolated firmware PATH has no
  `command -v`, `timeout`, `mktemp`, `stat`, `sha256sum`, `base64`, `od`, `setsid`
  or `dig`; installed Entware copies do not prove native availability. Older
  base configurations can omit `hexdump` too.
- The matched 3004.388.12_2 ash configuration disables `command`, job control and
  builtin printf/test/echo. Its builtin `kill` is also conditional on job control.
  Use fixed native executable selection for group signalling and a verified
  native PATH before external predicates or output producers. A full host
  BusyBox shell does not establish compatibility with these stripped settings.
  [Matched configuration](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/config_base)
  and [ash builtin registration](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/shell/ash.c).
- Bound streamed responses independently. Before curl 8.4.0,
  `--max-filesize` cannot enforce a limit for responses of unknown size.
  [curl size-limit behavior][curl-size]
- Prefer a usable `sha256sum` on **each** verification, with native OpenSSL for
  bootstrap and exceptional fallback. The selected Entware installation set
  includes `coreutils-sha256sum`; failed required installation blocks operational
  startup and can be retried on the next launch.

## 📦 Entware coverage and selected packages

These official feed snapshots were checked on **8 October 2026**. They establish
availability, not CFMgr runtime acceptance. Version numbers are evidence from
that date, not installer pins.

| Feed | Entware status | `jq` | `coreutils-sha256sum` / `coreutils-timeout` | `bind-dig` |
| --- | --- | --- | --- | --- |
| [aarch64-k3.10][feed-aarch64] | Maintained | 1.8.1-2 | 9.9-2 | 9.20.18-2 |
| [armv7sf-k3.2][feed-arm32] | Maintained | 1.8.1-2 | 9.9-2 | 9.20.18-2 |
| [mipselsf-k3.4][feed-mips] | Maintained | 1.8.1-2 | 9.9-2 | 9.20.18-2 |
| [armv7sf-k2.6][feed-arm26] | Support withdrawn | 1.6-2 | 9.3-1 | 9.18.16-1 |
| [Archived MIPSEL][feed-mips-old] | Archived Entware-ng | 1.5-2a | 8.23-3 | 9.11.2-3 |

The normal development target is maintained Entware feeds. ARM Linux 2.6.36.4
and MIPS Linux 2.6.22.19 need separate legacy acceptance; archive availability
does not establish support. In particular, `mipselsf-k3.4` is **not** the feed for
an old 2.6.22 router. [Entware support matrix][entware-support] ·
[withdrawn-feed announcement][entware-eos]

| Selected package | Scope and purpose |
| --- | --- |
| `jq` | Shared JSON selection/serialization. Use the ordinary package's non-regex functionality; no `jq-full` requirement. |
| `coreutils-timeout` | Shared bounded command/process-group supervision. Bootstrap must work safely before this command exists. |
| `coreutils-sha256sum` | Required checksum command, present across every feed above. OpenSSL remains available for bootstrap/fallback. |
| `bind-dig` | Tunnel DNS/SRV readiness when native DNS tools cannot satisfy the required queries. |
| `flock` | Only if the native locking command cannot satisfy the tested contract. Present in all five inspected feeds. |

The installed Entware opkg manages versions, package selection and transitive
libraries using its configured repositories. CFMgr's normal backend requests only its
missing/unusable direct dependencies and checks their capabilities afterward;
it does not manually acquire IPKs, choose library versions or change feeds.
A separate implemented internal backend explicitly force-reinstalls all selected
direct packages and repeats the post-checks. Its menu remains unimplemented.
Operational worker/startup integration and router acceptance remain unfinished.
CFMgr does not install Entware or request a whole-system upgrade. Native
`--doctor`/`--diagnostic` remain available without Entware and never install
packages. Cloudflared release binaries are managed separately for supported
kernel and userspace architecture/ABI combinations.

<details>
<summary>📦 Verified package contents</summary>

The current `jq`, `coreutils-timeout`, `coreutils-sha256sum` and `coreutils`
archives were checked across the three maintained feeds, plus aarch64 `flock`
and `bind-dig`: **14 packages**, each matched to its index size and SHA-256 before
inspection. They use a gzip/tar outer archive and contain no maintainer scripts
or conffiles. This finding covers those exact direct packages, not all libraries
or future versions. [AArch64 index][feed-aarch64] ·
[ARM index][feed-arm32] · [MIPS index][feed-mips]

The checksum and timeout executables live under `/opt/libexec`; their public
command links come from opkg alternatives metadata. `coreutils` itself is a
small metadata dependency. ELF interpreters and library search paths still
refer to `/opt`, so copying a verified executable to RAM does not make its
loader and libraries independent of Entware.

The loader audit also found that explicit `ld.so --library-path` execution
still reads `/opt/etc/ld.so.preload` before the program starts. Disabling its
cache does not suppress this lookup. A verified dynamic `unshare` binary has
the same bootstrap problem, so neither approach currently establishes safe
execution during `/opt` changes. Independent internal proofs use native bind
mounts and chroot for admitted fixed probes. They do not replace normal opkg
dependency resolution. The native command paths/help are confirmed on the
sampled router; that lifecycle has not been executed there. [Entware loader patch](https://github.com/Entware/Entware/blob/969c703e6fd8b2ad84d82affaeb14b48d1fcb105/toolchain/glibc/patches/2.27/9999-ldconfig.patch#L34-L44)

No inspected package was installed or executed. Dependency-closure checks,
package-manager side effects and mount-loss containment remain separate gates.

</details>

<details>
<summary>🔗 Libraries, ABI and kernel limits</summary>

The three shared packages on maintained/ARM-2.6 feeds depend on `libc`, `libssp`,
`librt` and `libpthread`; the coreutils commands also use the small `coreutils`
metadata package. This is not an installation of every coreutils command.
The base library chain includes `libgcc`. Archived MIPSEL has a smaller declared
dependency set; use its own metadata, never another feed's packages.

`bind-dig` adds `bind-libs`. On the sampled current feed that adds OpenSSL, zlib,
libatomic, libuv, liburcu and libnghttp2 alongside base libraries. This larger
dependency chain stays tunnel-specific. Plain Entware `jq` omits regex functions
such as `match`, `test` and `sub`; CFMgr filters must not depend on them.
[jq recipe][jq-recipe] · [coreutils recipe][coreutils-recipe]

Maintained feeds use glibc 2.27; its source minimum is Linux 3.2, or 3.7 for
AArch64. The ARM 2.6 feed uses glibc 2.23 and specifically targets Linux 2.6.36.
Those libc limits and feed names do not prove every package's syscall/CPU/ABI
compatibility. [glibc minimum][glibc-min] · [AArch64 minimum][glibc-arm64-min] ·
[Entware toolchain explanation][entware-readme]

The live target is Linux 4.1.51. Current official Merlin source also contains
4.19.183 and 4.19.294 kernel families. These are source observations, not an
invented maximum supported kernel. The final README will state the lowest
accepted profile and the highest tested/source-known families with their
evidence level. [AX kernel][kernel-ax] · [BE kernel][kernel-be]

</details>

The planned operational integration checks required packages on launch and
during CFMgr install, update and reinstall. Missing or unusable requirements block operational work; failed
installation can be retried on the next launch. A separate **Reinstall Entware
dependencies** action will force-reinstall CFMgr's selected package set and
verify it afterward. It preserves configuration/activation and does not perform
the Cloudflared submenu's daemon, hook or worker reinstall.

## 💾 Retained-volume identity

The storage design retains an open directory descriptor so later work can stay
attached to the verified Entware directory. A pathname or filesystem label alone
is insufficient when a drive is removed or `/opt` is retargeted.

On the measured GT-AX11000, read-only probes confirmed an inherited directory
descriptor exposes `mnt_id` in `/proc/self/fdinfo`, and native `test -ef` can
compare that descriptor with `/opt`. The matching kernel source links `mnt_id`
to the open descriptor's mount instance. It must also match a current mount
record; a descriptor can survive after its mount leaves the namespace.
[Descriptor metadata][fdinfo] · [Mount detachment][mount-detach]

This field entered mainline Linux in **3.15**. Older vendor kernels need a
demonstrated backport or a separately validated alternative. Entware feed names
such as `k3.2`, `k3.4` and `k3.10` describe package baselines; they do not prove
this storage capability. Native `test -ef` exists in the sampled older BusyBox,
but compares device/inode and cannot distinguish bind mounts of the same inode.
[Linux 3.14][fdinfo-before] · [Linux 3.15][fdinfo-added] ·
[Legacy comparison][legacy-ef]

These observations do not yet qualify volume acquisition, UUID binding,
writability, mount-loss handling or package installation. There is no new
blanket firmware support declaration.

Native `blkid` has a separate limitation: its output does not escape disk labels.
A label containing quotes can imitate a UUID field. CFMgr must therefore reject
label-bearing output as identity evidence, even if its text looks well formed.
[Native display routine][blkid-display]

For ext2/3/4, source review and harmless installed probes support an independent
route: read the UUID bytes from the primary superblock through an already open
block descriptor, using bounded native `hexdump`. Labels never enter that
interpretation. Native numeric `ls` can report the held block device's number
for comparison with the mount record. The reader and retained-descriptor callback have host/CI coverage; operational
composition, router acceptance and other filesystem profiles remain pending.
Labelled ext drives are not excluded by the blkid limitation. [Superblock format][ext-superblock]

<details>
<summary>🚧 Remaining firmware-specific proofs</summary>

SRV readiness will use a verified capable DNS tool; the current native `nslookup`
exposes host/server lookup only, and `bind-dig` remains untested on the router.
The matched custom-DDNS callback takes a result
without a request identity, so delayed background completion cannot yet be
treated as safe. A short capped wait has been selected for eligible DDNS calls,
but boot callers must return promptly. NTP/network readiness alone does not
prove boot completion: the matched firmware can call DDNS during startup.
Only a failed/timed-out firmware DDNS attempt schedules the additional CFMgr
fallback, which stays pending until full readiness. Exact boot gating, overlap
and retry behavior remain implementation gates in `PLAN.md`.

All router work so far has been read-only. No CFMgr deployment, package install,
service change, callback execution, provider mutation, or router pytest run was
performed. Full boot/outage and feature acceptance require later testing.

</details>

[math]: https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/shell/math.h#L66
[abi]: https://github.com/ARM-software/abi-aa/blob/509aee3027a52ec0e87d19b87116ca1958e0f72b/aapcs32/aapcs32.rst#L1766
[378-math]: https://github.com/RMerl/asuswrt-merlin/blob/4a09301907eca9e55db992c5c0002a8688388255/release/src/router/busybox/config_base#L1009
[378-tls]: https://github.com/RMerl/asuswrt-merlin/blob/4a09301907eca9e55db992c5c0002a8688388255/release/src/router/openssl/ssl/tls1.h#L165
[378-curl]: https://github.com/RMerl/asuswrt-merlin/blob/4a09301907eca9e55db992c5c0002a8688388255/release/src/router/Makefile#L3337
[380-math]: https://github.com/RMerl/asuswrt-merlin/blob/520760eb7268582b002d7c12294b868ee8d66e13/release/src/router/busybox/config_base#L1059
[380-models]: https://github.com/RMerl/asuswrt-merlin/blob/520760eb7268582b002d7c12294b868ee8d66e13/release/src-rt/target.mak#L2
[380-curl]: https://github.com/RMerl/asuswrt-merlin/blob/520760eb7268582b002d7c12294b868ee8d66e13/release/src/router/Makefile#L3981
[380-toolchain]: https://github.com/RMerl/asuswrt-merlin/blob/520760eb7268582b002d7c12294b868ee8d66e13/release/src-rt/platform.mak#L34
[386-math]: https://github.com/RMerl/asuswrt-merlin.ng/blob/440b59b66400bf352ca2a8e8b052e9c45e0650ac/release/src/router/busybox/config_base#L1062
[386-toolchain]: https://github.com/RMerl/asuswrt-merlin.ng/blob/440b59b66400bf352ca2a8e8b052e9c45e0650ac/release/src-rt/platform.mak#L86
[386-curl]: https://github.com/RMerl/asuswrt-merlin.ng/blob/440b59b66400bf352ca2a8e8b052e9c45e0650ac/release/src/router/curl/include/curl/curlver.h#L35
[388-math]: https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/config_base#L1062
[uclibc]: https://uclibc.org/downloads/
[cf-packages]: https://github.com/cloudflare/cloudflared/blob/18cdfe0a6fc7b72a0702d255a1f984e776ce0498/.ci/scripts/linux/build-packages.sh#L18
[cf-go]: https://github.com/cloudflare/cloudflared/blob/18cdfe0a6fc7b72a0702d255a1f984e776ce0498/go.mod#L3
[go-min]: https://go.dev/wiki/MinimumRequirements
[curl-size]: https://curl.se/docs/manpage.html#--max-filesize
[feed-aarch64]: https://bin.entware.net/aarch64-k3.10/Packages.gz
[feed-arm32]: https://bin.entware.net/armv7sf-k3.2/Packages.gz
[feed-mips]: https://bin.entware.net/mipselsf-k3.4/Packages.gz
[feed-arm26]: https://bin.entware.net/armv7sf-k2.6/Packages.gz
[feed-mips-old]: https://pkg.entware.net/binaries/mipsel/Packages.gz
[entware-support]: https://github.com/Entware/Entware/wiki#the-entware-wiki
[entware-eos]: https://github.com/Entware/Entware/discussions/1018
[entware-readme]: https://bin.entware.net/Readme.txt
[jq-recipe]: https://github.com/Entware/entware-packages/blob/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd/utils/jq/Makefile#L36
[coreutils-recipe]: https://github.com/Entware/entware-packages/blob/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd/utils/coreutils/Makefile#L60
[glibc-min]: https://github.com/bminor/glibc/blob/23158b08a0908f381459f273a984c6fd328363cb/sysdeps/unix/sysv/linux/configure.ac#L33
[glibc-arm64-min]: https://github.com/bminor/glibc/blob/23158b08a0908f381459f273a984c6fd328363cb/sysdeps/unix/sysv/linux/aarch64/configure.ac#L4
[kernel-ax]: https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src-rt-5.04axhnd.675x/kernel/linux-4.19/Makefile#L2
[kernel-be]: https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7891a288a7/release/src-rt-5.04behnd.4916/kernel/linux-4.19/Makefile#L2
[fdinfo]: https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src-rt-5.02axhnd/kernel/linux-4.1/fs/proc/fd.c#L19
[mount-detach]: https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src-rt-5.02axhnd/kernel/linux-4.1/fs/namespace.c#L1443
[fdinfo-before]: https://github.com/torvalds/linux/blob/v3.14/fs/proc/fd.c#L46
[fdinfo-added]: https://github.com/torvalds/linux/blob/v3.15/fs/proc/fd.c#L47
[legacy-ef]: https://github.com/RMerl/asuswrt-merlin/blob/4a09301907eca9e55db992c5c0002a8688388255/release/src/router/busybox/coreutils/test.c#L540
[blkid-display]: https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/util-linux/volume_id/get_devname.c
[ext-superblock]: https://docs.kernel.org/filesystems/ext4/super.html
