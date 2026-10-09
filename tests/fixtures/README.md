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
The ten scenarios retain individual 15-second bounds:

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
| 9 (native-root) | Native views, six staged files, quota tmpfs, retained Opt, fixed devices, the native shell probe and a synthetic static opkg-version stand-in use the checked lifecycle | FD8 remains synthetic; the stand-in is not Entware opkg or firmware ABI evidence; see below |
| 10 (native-probe) | Real aggregate deadline and native-config-root/chroot cleanup around the fixed probe; the fixture inspects the watchdog's descriptors while FD6/8/9 are held and verifies a known FD0 witness | Storage acquisition is a synthetic seam; does not prove outer storage IO acquisition, physical block-device/UUID admission or router execution |

The ninth scenario composes the quota-limited native-tmp root, retained
Opt root, fixed native devices and native-config-root entry. It stages all six
fixed files before the first bind, including a binary CA bundle larger than
128 KiB, and uses actual BusyBox `dd`/`cmp` to verify exact bytes and readonly
`/etc`. It also checks executable tmpfs, byte/inode ceilings, empty private
`tmp/cfmgr-home`, unchanged observer `HOME`, all 106 query slots, 12 device
metadata observations, and an FD9-backed controlled writable source with an
anchored write reaching it. Opt is unmounted first and must expose the exact
empty readonly fallback before tmpfs removal. FD8 is a regular fixture file
with synthetic metadata, so this does not prove physical block identity or UUID
approval. This ninth scenario passed the earlier
[41% kernel checkpoint](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37957863595)
and remains part of the current ten-scenario gate.

The fixed shell-probe extension uses genuine trusted host BusyBox and its
loader/dependencies. The runner changes only the private BusyBox copy's existing
PT_INTERP region to fit a short `/lib` loader path, verifies the exact rewrite
with `readelf`, and restricts dependency staging to the observed `/lib` and
`/usr/lib` layout. Small static fixture wrappers inspect FD3..63 outside and
inside chroot, then forward to real chroot/BusyBox applets; `/bin/sh` itself is
the genuine dynamic BusyBox. This instruments the descriptor boundary while
executing the fixed script. Original caller descriptors and checked ordinary
teardown remain asserted. Each namespace scenario retains its 15-second bound;
see [PLAN.md](../../PLAN.md) for the checkpoint results.
These host-native bytes and the interpreter adaptation do not establish ARM32,
Merlin loader/NSS/TLS behavior or package execution. Firmware cache files are
never inputs to this executable fixture.

The O9c extension to scenario 9 also invokes a trusted synthetic static opkg
stand-in through the fixed `/opt/bin/opkg --version` path. It witnesses exact
child argv, clean environment and working directory, closure of inherited
descriptors, and reading the retained Opt marker. It does not run Entware opkg
or establish the installed executable's provenance. The O9c 43% Linux gate is
green: all ten scenarios passed at candidate
`d0a04b3a6d2e57464803039255bccafc97d0e79c` in
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37977771431).
Scenario 9 took 6.17s. This synthetic fixture does not prove real opkg,
executable provenance or router execution.

Scenario 10 composes the source-only native-probe worker with the real deadline
owner, fixed chrooted probe, native-config-root teardown and completion handoff.
The worker checks exact-zero root cleanup and the synthetic outer-storage
callback before the deadline completion handoff. The root callback inspects the
watchdog's FD3..63 set while FD6/8/9 are held; a known FD0 metadata read is the positive
witness before confirming no root/storage aliases appeared. The test storage
seam keeps FD8 regular with synthetic metadata and
uses a controlled FD9 source, but compares the supplied Entware authority. It
does not exercise outer storage IO acquisition or physical block-device/UUID
admission. At 43%, all ten scenarios passed; the unchanged tenth scenario took
8.79s. CI also ran the actual BusyBox opkg grammar representative. Full suite
counts and timings are in the [development guide](../../docs/development.md#-run-checks).
These host/Linux results do not establish router acceptance.

The device layer adds only privately generated `/dev/null` (1:3) and
`/dev/urandom` (1:9), with the expected root ownership and mode. Its wrapper
holds a real BusyBox FD5 to witness that unmount is busy, closes it to permit
cleanup, then checks that the `nodev` fallback refuses new opens. This does not
claim that an existing descriptor is revoked or that inode checks provide a
continuous lease; the source image must remain frozen. All nine scenarios pass
the [40% Linux/BusyBox Actions run](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37950451858).
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
`tests/test_native_shell.py` uses an inert chroot wrapper for cheap admission,
descriptor, environment, capture and completion failures, plus real root-lease
uncertainty propagation. It checks real open descriptors with `fstat` on macOS;
the explicit BusyBox case proves ash behavior, and the namespace scenario
separately proves actual dynamic launch and mount cleanup. No host mock is
reported as a privileged chroot or router test.
`tests/test_native_opkg.py` checks the separate fixed version probe with
independent response bytes, boundary and metacharacter versions, separate
evidence, and no-launch/error outcomes. Its opkg fixture never executes real
Entware opkg or installs a package; its BusyBox case is a batched representative.
`tests/test_native_probe.py` checks the fixed worker's argument/authority
routing, watchdog and cleanup ordering, 0/1 outcomes, caller state, stale markers
and uncertain completion with fresh lower-level seams. Its early-exit case
exercises the composition's completion guard; it does not duplicate the real
kernel root lifecycle.
`tests/test_native_devices.py` contains the native-config-root policy and host
lifecycle consumer; the actual BusyBox composition is in
`tests/test_native_root.py`. These consumers exercise all six files with the
retained-Opt/device lifecycle. The local BusyBox root case was explicitly
skipped because no local binary was available; the Linux CI consumer passes.
The fixed-device/native-config composition passed the prior full local and
exact-head kernel/BusyBox gates. Host mirrors do not prove mount-enforced
readonly behavior.
`tests/test_native_tmp_root.py` checks quota validation and lifecycle metadata
with host fixtures; these mock mount tools and do not prove actual quota, write
or exec behavior. `tests/test_entware_root.py` covers retained-Opt success,
busy-Opt cleanup refusal and malformed API rejection;
`tests/test_entware_root_admission.py` covers the storage-admission boundary.
`tests/test_native_devices.py` covers fixed node metadata, inode rechecks and
host busy-unmount guard retention. The actual BusyBox representative and ninth
namespace scenario now provide integration evidence for the 43% O9c gate above;
the tenth native-probe scenario passed unchanged in that gate.
Host fixtures do not prove mount-enforced readonly behavior.
Native-root host tests use the focused query fixture in
`tests/isolation_helpers.py`, while its Linux/BusyBox consumer retains complete
capture evidence. Other host fault tests may share the focused query fixture in
`tests/isolation_helpers.py`, preserving real IO ownership, mount parsing,
framing and descriptor checks. The bare-root host success and actual
BusyBox/kernel consumers retain the full bounded-capture path. Document this evidence boundary
when adding cases, and review fixture guidance at implementation milestones.

The native host dispatcher performs real path and descriptor observations before
loading unrelated simulated mount state. Its standard-library-only processes
skip Python site initialization and load file-copy helpers only when needed;
observations are never cached. On macOS, the fixed descriptor tests use the
system `stat` tool on inherited stdin, preserving the actual open descriptor
without reopening its path. Other hosts retain the Python observations.
`tests/test_native_observation.py` checks real inode relationships, directory
versus file metadata, symlinks, closed descriptors and continued descriptor use
in one small batch. Stateful mount/device simulation remains unchanged.
`tests/test_io_hex.py` separately compares both
hex validators with a decoded-byte grammar, including valid inputs containing
misleading matches between byte boundaries. Full lifecycle assertions and
deadlines remain unchanged.

The opkg fixture also starts its standard-library-only dispatcher with Python
site initialization disabled. It loads hashing, shell quoting and subprocess
helpers only for the actions that use them, while preserving fresh settings,
call logs, real timeout-child execution and the original per-action deadline.
