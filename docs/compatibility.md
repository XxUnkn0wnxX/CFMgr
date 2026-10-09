# 🧭 Firmware compatibility

[← README](../README.md) · [Development](development.md) · [Implementation plan](../PLAN.md)

![Runtime](https://img.shields.io/badge/runtime-POSIX_sh-4EAA25)
![Evidence](https://img.shields.io/badge/evidence-source_%2B_read--only_probes-blue)
![Acceptance](https://img.shields.io/badge/runtime_acceptance-pending-orange)

CFMgr aims to support Merlin by the capabilities each feature needs. **No
firmware is declared fully supported yet.** This evidence snapshot was collected
on **8 October 2026**; source inspection, harmless installed-tool probes, host
tests, and complete router acceptance are different levels of proof.

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
· [Build selection](https://github.com/RMerl/asuswrt-merlin.ng/blob/b053ba701af02e46a86d465d82cc2a7d57102260f/release/src-rt/Makefile#L145)
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

## 🧩 Qualify each feature separately

| Feature | Required capability | Current boundary |
| --- | --- | --- |
| Core manager, DDNS, IP-Sync | POSIX shell, verified HTTPS/CA trust, bounded IO/locking, JFFS/RAM state and usable shared Entware prerequisites | Native recovery diagnostics remain available when prerequisites fail. Complete runtime acceptance remains pending. |
| Current storage-observation profile | Inherited descriptor mount IDs, native numeric device listing and bounded hexdump; dynamic-revision ext2/ext3/ext4 primary superblock | Read-only foundation only. Other filesystem profiles, writability and storage-loss containment remain pending. |
| Integrity verification | Required `coreutils-sha256sum`; native OpenSSL retained for bootstrap and edge fallback | Both produced the same synthetic digest on the current router. Fallback does not waive failed required-package installation. |
| Cloudflared | Verified mounted Entware storage, supported official binary ABI/kernel, integrity and version checks | Modern official assets do not cover MIPS; older ARM kernels may also fail the selected binary's minimum. |
| Optional file logging | Mounted Entware plus configured Scribe/logrotate | Current Scribe/includes were inspected; no service or rotation was exercised. |
| Backup/restore | Native archive/integrity tools plus an explicitly selected mounted drive | A source capability check does not prove extraction, ownership, mount-loss or restore safety. |

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
libraries using its configured repositories. CFMgr's backend requests only its
missing/unusable direct dependencies and checks their capabilities afterward;
it does not manually acquire IPKs, choose library versions or change feeds.
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
for comparison with the mount record. Integration, failure handling and other
filesystem profiles remain pending; labelled ext drives are not excluded by
the blkid limitation. [Superblock format][ext-superblock]

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
