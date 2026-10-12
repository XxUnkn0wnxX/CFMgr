# Compatibility targets

[Overview](../README.md) · [Requirements](../PLAN_V2.md#2-installation-storage-and-dependencies)

**Development targets, not verified router support.** GT-AX11000 is the baseline
and first router-beta target. Modern targets follow the official
[Merlin device list](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Supported-Devices).
Actual router, flash, hooks, TLS and provider qualification remains pending beta;
IPv6 operation remains provisional.

## Representative profiles

Retained official firmware was inspected as data, without execution or flashing.
These are selected image snapshots, not promises about every release or model.

| Target | Firmware snapshot | Kernel | Native BusyBox/curl/OpenSSL ABI |
| --- | --- | --- | --- |
| [GT-AX11000](https://sourceforge.net/projects/asuswrt-merlin/files/GT-AX11000/Release/) | Standard, non-ROG `3004_388.12_2` | AArch64, 4.1.51 | ARM ELF32, `/lib/ld-linux.so.3` |
| [RT-AX88U_PRO](https://sourceforge.net/projects/asuswrt-merlin/files/RT-AX88U_PRO/Release/) | `3006_102.9_0` | AArch64, 4.19.183 | ARM ELF32, `/lib/ld-linux.so.3` |
| [RT-BE96U](https://sourceforge.net/projects/asuswrt-merlin/files/RT-BE96U/Release/) | `3006_102.9_0` | AArch64, 4.19.294 | ARM ELF32, `/lib/ld-linux.so.3` |

All three contain BusyBox 1.25.1, curl 8.17.0 and a ROM CA bundle. Embedded
OpenSSL banners identify 1.1.1w on the baseline and 3.5.8 on the modern snapshots;
banner/ELF inspection does not prove successful execution.

[Pinned test profiles](../tests/fixtures/platforms.json) record Merlin source
revisions, BusyBox and dependency inputs. Entware's
[supported feeds](https://github.com/Entware/Entware/wiki) include
`armv7sf-k3.2` and `aarch64-k3.10`, using their own
[`/opt/lib` loaders](https://github.com/Entware/Entware/wiki/Using-GCC-for-native-compilation#environment-variables).
The pinned inventories include jq, coreutils-timeout, coreutils-sha256sum and
conditional flock/bind-dig. Feed names and package listings do not establish
runtime usability, and the kernel, native utilities and Entware need not share
one ELF class.

## Admission and evidence limits

Required admission covers protected native paths, actual command options,
readable valid ROM CA certificates, isolated curl/loader/proxy configuration and
usable selected executables. Local installation must not require an external
HTTPS request. TLS policy must retain peer and hostname verification; representative
local HTTPS fixtures exercise trust failures separately from router qualification.

Profiles lacking required native options, valid trust, compatible loaders or usable
mapped dependencies cannot perform dependent work. Withdrawn ARMv5 and ARMv7 kernel
2.6 Entware feeds are outside the target profiles. Temporary Entware/storage loss
is an operational failure, not grounds to exclude a model or discard its settings.

Required development evidence is Ubuntu integration plus native-host vendor
BusyBox. Optional kernel/ARM diagnostics are separate evidence. The
[checklist](../PLAN_V2_checklist.md#2-installation-storage-and-dependencies) records
which admission checks have actually passed; this profile guide awards no acceptance.
