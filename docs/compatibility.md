# 🧭 Firmware compatibility

[← README](../README.md) · [Development](development.md) · [Implementation plan](../PLAN.md)

![Runtime](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Evidence](https://img.shields.io/badge/evidence-source_%2B_read--only_probes-blue)
![Acceptance](https://img.shields.io/badge/runtime_acceptance-not_claimed-lightgrey)

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
path. Host and Linux fixtures describe the source-level behavior; they do not
establish router runtime acceptance.

The ignored local cache at `.tmp/firmware-audit/INDEX.md` records the audit
method, provenance, selected paths and evidence limits. Read that index before
repeating work and reuse its verified local artifacts where applicable; its
archive, image, extracted data, certificates and raw reports stay ignored and
must not be committed. `audit.py` can rewrite provenance, so consult the cache
instructions before rerunning it. The exact official archive URLs and hashes
are listed above and in the local provenance record.

The coverage map records 33 explicit native tool names per sample and 58 pinned
source files, including `ln`/`chmod` and the current closure/supervision
consumers. Static
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
This supports the two recognized capability profiles without assuming every
firmware build is compatible. Help-disabled builds and changed descriptions require
review. Kernel, ABI, storage and full router acceptance remain separate gates.

## Native worker and execution-root evidence

The matched native cron source creates a process group before launching a job.
CFMgr independently verifies the actual original shell's PID/group identity and
uses a native guarded watchdog with cooperative completion. Cancellation signals
its current group, avoiding stored numeric PID reuse. Linux/BusyBox fixtures exercise
those internal paths; they do not prove operational cron dispatch or router
acceptance. A blocked kernel task or externally stopped watchdog cannot be given an
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
and failure retention. The native-tmp variant adds one checked writable
tmpfs child with canonical size limits of 64–65,536 KiB in multiples of 64 and
8–8,192 inodes. Its mount uses `rw,nosuid,nodev,exec`, `mode=700`, and the exact
requested size/inode ceilings; it creates an empty mode-`0700`
`/tmp/cfmgr-home` while leaving the observer's `HOME` unchanged. These ceilings
limit tmpfs use but do not reserve RAM or establish available memory headroom.

The retained-Opt composition uses a checked writable source mounted through
FD9 and removes Opt before exposing an exact empty readonly fallback. Its kernel
fixture verifies a bounded anchored write; the fixture's FD8 storage metadata is
synthetic, so it does not prove physical block-device or UUID approval.

The fixed native-device layer provides only private-image `/dev/null` (1:3) and
`/dev/urandom` (1:9), mounted as read-only, `nosuid`, `noexec`, device-enabled
children. The base-root `nodev` fallback refuses new opens after child unmount;
it does not revoke already-open descriptors. Before/after inode checks are not
a continuous FD lease, so the private source image must remain frozen.

The native-config-root entry stages six fixed files before binding: hosts,
resolver, NSS, wget, OpenSSL configuration and CA certificates. It copies bytes
without validating resolver, TLS, NSS or loader semantics. The fixed native
shell probe runs one trusted synchronous BusyBox command with a clean
environment and a checked root lease; the separate opkg version probe runs
only `/opt/bin/opkg --version` and treats the expected version as comparison
data. Neither grants general executable, network or package-install authority.

`cfmgr_worker_native_probe` composes the fixed shell check with process-group
deadline supervision, retained-storage descriptors and checked root/IO cleanup.
Its ordinary result is published only after exact completion evidence; uncertain
cleanup remains guarded. Storage acquisition in the developer kernel fixture is
synthetic, so outer storage IO, block-device/UUID admission, ARM32 execution and
router acceptance remain unproved.

The source-only dependency handoff accepts finite repair/reinstall, scope and
lock selectors. It runs the existing Entware backend with configured feeds,
package resolution, locking and package configuration. Normal repair installs
only missing or unusable mapped tools; selected force reinstall remains
separate. CFMgr serializes only its own workers. A configured opkg `tmp_dir` can
still direct package scratch writes outside a private tmpfs quota. Its lock does
not exclude external writers or guarantee that unrelated half-installed packages
remain untouched. The serialized dependency worker requires native process-group
admission, lock/deadline support and the fixed `rmdir` capability. Developer
fixtures use inert opkg/capability programs and synthetic storage metadata; they
do not establish installed-code provenance, real package execution, firmware
ABI or router acceptance. See [PLAN.md](../PLAN.md) for validation records.

## 🧩 Qualify each feature separately

| Feature | Required capability | Current boundary |
| --- | --- | --- |
| Native diagnostic | POSIX shell and native command checks | Read-only host report; it does not load Entware, read configuration, install packages or contact providers. |
| Storage observation | Descriptor mount IDs, native numeric device listing, bounded hexdump and dynamic-revision ext2/ext3/ext4 primary-superblock layout | Read-only observation only; not persistent identity, writability or storage-loss containment. |
| Integrity verification | `coreutils-sha256sum`; native OpenSSL fallback | Both can compare synthetic digests; fallback does not waive a failed required-package installation. |
| Config header and lifecycle reports | BusyBox-compatible POSIX `sh`, native `cat`/AWK, JSON/header parsers and the IO owner | Caller-prepared immutable data only; reports may read raw configuration input but never return or approve credential values, validate full settings or inspect installed availability. |
| Source catalog plan | Existing IO owner, native `cat`/AWK and trusted path/manifest parsers | Joins a parsed catalog to a separately supplied manifest and pins URLs to a supplied commit. It does not prove URL provenance, branch mapping, source authenticity, completeness or installation. |
| Package manifest and verification reports | BusyBox-compatible POSIX `sh`, AWK, native `find`, `wc`, OpenSSL and `hexdump` | Parse declared records, verify declared bytes, compare the observed tree, check entry-version equality and apply a supplied policy. No source acquisition, authentication, complete-profile approval, installed permissions or activation authority. |
| Developer package inventory | Developer-host Python 3.11+ and local Git objects | Reads one explicit local commit; not a router dependency or a source-authentication claim. |

Matched `3004.388.12_2` and `3006.102.9` source
configurations enable BusyBox `find`, and the retained representative image
inventories contain `/usr/bin/find` as a link to BusyBox. The pinned
[3004 `find` implementation](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/findutils/find.c)
supports the plain `find . -print` form used here without following links by
default. Its
[recursive traversal implementation](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/libbb/recursive_action.c)
does not distinguish `readdir` error from EOF or report `closedir` failure.
This is matched source/image capability evidence only; it does not establish
complete runtime acceptance on a router.

Matched Merlin BusyBox 1.25.1 AWK source supports the parser's
record-separator and byte-length framing under the C locale. This source review
is distinct from host-AWK and actual-BusyBox developer tests, and neither is
router runtime acceptance. The supplied package-policy report reuses this parser plus the existing version
comparator and native size helper; its structural-policy checks add no new
firmware applet requirement.

The inspected Cloudflared `2026.10.0` release metadata lists ARM/ARMHF/ARM64
and x86 assets but no MIPS asset. Go 1.26 requires Linux 3.2 or newer; the
sampled legacy MIPS kernel is 2.6.22.19 and RT-AC68U's is 2.6.36.4. These are
external asset and kernel facts, not a claim that CFMgr installs or manages
Cloudflared.
[Cloudflared packaging][cf-packages] · [Go version][cf-go] · [Go platform minimums][go-min]

The current storage observer needs `mnt_id` in proc descriptor information.
Mainline Linux added this in 3.15; older vendor kernels need a verified backport
or a separate observation profile. An Entware feed name such as `k3.10` does not
establish this capability. The measured router exposes it, and lightweight
native hexdump/device-listing probes confirm the required applets; CFMgr runtime
acceptance remains unverified. [Linux 3.15 descriptor information](https://github.com/torvalds/linux/blob/v3.15/fs/proc/fd.c#L47).

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
| `bind-dig` | Selected by the backend's `tunnel` scope. Its `dig -v` check establishes invocation only, not DNS/SRV readiness. |
| `flock` | Only if the native locking command cannot satisfy the tested contract. Present in all five inspected feeds. |

The installed Entware opkg manages versions, package selection and transitive
libraries using its configured repositories. CFMgr's normal backend requests only its
missing/unusable direct dependencies and checks their capabilities afterward;
it does not manually acquire IPKs, choose library versions or change feeds.
A separate internal backend explicitly force-reinstalls all selected direct
packages and repeats the post-checks; the CLI does not expose this API.
The backend is an internal interface; router acceptance is unverified.
CFMgr does not install Entware or request a whole-system upgrade. Native
`--doctor`/`--diagnostic` remain available without Entware and never install
packages.

<details>
<summary>📦 Verified package contents</summary>

The current `jq`, `coreutils-timeout`, `coreutils-sha256sum` and `coreutils`
archives were checked across the three maintained feeds, plus aarch64 `flock`
and `bind-dig`: **14 packages**, each matched to its index size and SHA-256 before
inspection. They use a gzip/tar outer archive and contain no maintainer scripts
or conffiles. This finding covers those exact direct packages, not all libraries
or later versions. [AArch64 index][feed-aarch64] ·
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
invented maximum supported kernel. [AX kernel][kernel-ax] · [BE kernel][kernel-be]

</details>

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

These observations do not qualify volume acquisition, UUID binding,
writability, mount-loss handling or package installation. No blanket firmware
support declaration is made.

Native `blkid` has a separate limitation: its output does not escape disk labels.
A label containing quotes can imitate a UUID field. CFMgr must therefore reject
label-bearing output as identity evidence, even if its text looks well formed.
[Native display routine][blkid-display]

For ext2/3/4, source review and harmless installed probes support an independent
route: read the UUID bytes from the primary superblock through an already open
block descriptor, using bounded native `hexdump`. Labels never enter that
interpretation. Native numeric `ls` can report the held block device's number
for comparison with the mount record. The reader and retained-descriptor callback have host/CI coverage; operational
composition, router acceptance and other filesystem profiles are unverified.
Labelled ext drives are not excluded by the blkid limitation. [Superblock format][ext-superblock]

Merlin callback source and host fixtures do not establish router-level
feature acceptance.

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
