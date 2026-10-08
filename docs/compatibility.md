# 🧭 Firmware compatibility

[← README](../README.md) · [Development](development.md) · [Implementation plan](../PLAN.md)

![Runtime](https://img.shields.io/badge/runtime-native_sh-4EAA25)
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

## 🧩 Qualify each feature separately

| Feature | Required capability | Current boundary |
| --- | --- | --- |
| Core manager, DDNS, IP-Sync | Native shell/awk, verified HTTPS and CA trust, bounded parsing/IO, safe locking and JFFS/RAM state | Must work without Entware. Parser, transaction and complete native runtime acceptance remain pending. |
| Integrity verification | Usable `sha256sum`, otherwise native OpenSSL SHA-256 | Both produced the same synthetic digest on the current router; updater implementation remains pending. |
| Cloudflared | Verified mounted Entware storage, supported official binary ABI/kernel, integrity and version checks | Modern official assets do not cover MIPS; older ARM kernels may also fail the selected binary's minimum. |
| Optional file logging | Mounted Entware plus configured Scribe/logrotate | Current Scribe/includes were inspected; no service or rotation was exercised. |
| Backup/restore | Native archive/integrity tools plus an explicitly selected mounted drive | A source capability check does not prove extraction, ownership, mount-loss or restore safety. |

For example, the inspected Cloudflared `2026.10.0` packaging uses Go 1.26,
provides ARM/ARMHF/ARM64 and x86 builds, and has no MIPS asset. Go requires Linux
3.2 or newer. The sampled legacy MIPS kernel is 2.6.22.19 and RT-AC68U's is
2.6.36.4. Those samples cannot qualify for that modern binary merely because
Entware works. Native DDNS/IP-Sync eligibility is evaluated separately.
[Cloudflared packaging][cf-packages] · [Go version][cf-go] · [Go platform minimums][go-min]

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
- Bound streamed responses independently. Before curl 8.4.0,
  `--max-filesize` cannot enforce a limit for responses of unknown size.
  [curl size-limit behavior][curl-size]
- Prefer a usable `sha256sum` on **each** verification, then fall back to native
  OpenSSL. Explicit install/setup may make one bounded attempt to obtain the
  exact Entware provider, currently `coreutils-sha256sum`. Updates and ordinary
  launches do not install packages. Missing integrity capability fails closed.

<details>
<summary>🚧 Remaining firmware-specific proofs</summary>

Native SRV readiness still needs a proved approach: the current `nslookup`
exposes host/server lookup only. The matched custom-DDNS callback takes a result
without a request identity, so delayed background completion cannot yet be
treated as safe. These gates are recorded in `PLAN.md` before dependent code.

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
