# 🧩 Test fixtures

[← Development guide](../../docs/development.md) · [Validation plan](../../PLAN.md#validation-matrix)

Use synthetic or reviewed sanitized data. Never copy live router configuration,
credentials, certificates, account identifiers, or private addresses into tests.

The ordinary router harness creates a fresh private JFFS/opt/RAM tree and fake-tool
directory for each test. Regressions generate their small synthetic inputs directly;
static fixtures are added only when a tested contract needs them.

Keep the expected outcome and its evidence level clear. A captured capability
profile is an observation, not proof that a runtime feature passes on that router.

`kernel/` contains controlled developer-only shell/C fixtures for the explicit
Linux namespace check. It uses actual BusyBox mounts and the runtime lifecycle,
but substitutes synthetic storage metadata for block-device/UUID admission.
The nine scenarios retain individual 15-second bounds:

| Scenario | Evidence established | Limit |
| --- | --- | --- |
| 1 (success) | Successful retained-storage callback and checked cleanup with real mount observations and a held directory descriptor | Storage-device and UUID approval are substituted |
| 2 (busy) | Busy mount prevents teardown and retains the guard | Does not model physical hotplug |
| 3 (signal) | Interruption preserves the incomplete-operation guard | Does not prove unconditional cleanup after an uninterruptible kernel operation |
| 4 (primitive) | Controlled executable reaches chroot and exact-mount busy behavior | Uses a developer fixture, not Entware payloads |
| 5 (image) | Read-only executable image permits execution, rejects root writes with EROFS, and remains writable through its outside alias; mapped-image busy state blocks unmount until the actor exits | Does not qualify firmware executable closure |
| 6 (contained) | Controlled ELF/profile image verifies staging/hash and fixed-probe supervision; the host loader sits behind the profile alias. The actor checks closed external descriptors, bootstrap links, null, EROFS and absent proc/shell/writable Opt before guard cleanup | The ELF and profile are synthetic, not a router runtime |
| 7 (worker-lifetime) | An inherited root descriptor blocks teardown; after chroot/setsid the child drops it but retains root/cwd and proof pipes. Removing Opt exposes readonly empty fallbacks until the detached child exits | Filesystem quiescence is not proof of arbitrary descendant reaping |
| 8 (execution-root) | Actual readonly-root owner checks mount identity, fallback write refusal, restored caller descriptors and completed teardown before RAM removal | Not an operational worker or router acceptance |
| 9 (native-root) | Native views, six staged files, quota tmpfs, retained Opt and fixed devices use the complete checked lifecycle | FD8 remains synthetic; see the details below |

The current ninth scenario composes the quota-limited native-tmp root, retained
Opt root, fixed native devices and native-config-root entry. It stages all six
fixed files before the first bind, including a binary CA bundle larger than
128 KiB, and uses actual BusyBox `dd`/`cmp` to verify exact bytes and readonly
`/etc`. It also checks executable tmpfs, byte/inode ceilings, empty private
`tmp/cfmgr-home`, unchanged observer `HOME`, all 106 query slots, 12 device
metadata observations, and an FD9-backed controlled writable source with an
anchored write reaching it. Opt is unmounted first and must expose the exact
empty readonly fallback before tmpfs removal. FD8 is a regular fixture file
with synthetic metadata, so this does not prove physical block identity or UUID
approval. The upgraded kernel result remains pending the 40% CI gate.

The device layer adds only privately generated `/dev/null` (1:3) and
`/dev/urandom` (1:9), with the expected root ownership and mode. Its wrapper
holds a real BusyBox FD5 to witness that unmount is busy, closes it to permit
cleanup, then checks that the `nodev` fallback refuses new opens. This does not
claim that an existing descriptor is revoked or that inode checks provide a
continuous lease; the source image must remain frozen. The Opt-only version
passed the earlier 37% CI gate. The fixed-device upgrade passed all nine kernel
scenarios in the [38% Linux/BusyBox Actions run](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37939185984).
Host mirrors alone do not prove mount-enforced permissions, quota enforcement
or descriptor semantics.
The worker-lifetime fixture separately proves descriptor/root references and
writable-child revocation with controlled descendants. Native BusyBox
unmount capability selection is exercised through the runtime implementation;
there is no command-syntax adapter or simulated cleanup. Its executable
fixtures establish host-kernel behavior only. They are never router dependencies
or an authorization to run arbitrary programs through the runtime callback.

`tests/test_native_config.py` retains the legacy two-file staging contract and
direct helper coverage. `tests/test_native_config_extended.py` covers binary/NUL
preservation, the 65,536-byte and 1-MiB caps, same-descriptor EOF,
producer/comparison failures, partial staging and enclosing IO cleanup.
`tests/test_native_devices.py` contains the native-config-root policy and host
lifecycle consumer; the actual BusyBox composition is in
`tests/test_native_root.py`. These consumers exercise all six files with the
retained-Opt/device lifecycle. The local BusyBox root case was explicitly
skipped because no local binary was available. Full 40% local validation passes;
exact-head kernel/BusyBox CI remains pending; the accepted 39% baseline does not
include this composition. Host mirrors do not prove mount-enforced readonly
behavior.
`tests/test_native_tmp_root.py` checks quota validation and lifecycle metadata
with host fixtures; these mock mount tools and do not prove actual quota, write
or exec behavior. `tests/test_entware_root.py` covers retained-Opt success,
busy-Opt cleanup refusal and malformed API rejection;
`tests/test_entware_root_admission.py` covers the storage-admission boundary.
`tests/test_native_devices.py` covers fixed node metadata, inode rechecks and
host busy-unmount guard retention. Its upgraded actual BusyBox representative
and the ninth namespace scenario provide separate integration evidence in the
38% CI run; the upgraded nine-scenario native-config proof is pending 40% CI.
Host fixtures do not prove mount-enforced readonly behavior.
Native-root host tests use the focused query fixture in
`tests/isolation_helpers.py`, while its Linux/BusyBox consumer retains complete
capture evidence. Other host fault tests may share the focused query fixture in
`tests/isolation_helpers.py`, preserving real IO ownership, mount parsing,
framing and descriptor checks. The bare-root host success and actual
BusyBox/kernel consumers retain the full bounded-capture path. Document this evidence boundary
when adding cases, and review fixture guidance at implementation milestones.
