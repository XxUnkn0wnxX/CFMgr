# 🧩 Test fixtures

[← Development guide](../../docs/development.md) · [Validation plan](../../PLAN.md#validation-matrix)

Use synthetic or reviewed sanitized data. Never copy live router configuration,
credentials, certificates, account identifiers, or private addresses into tests.

The ordinary router harness creates a fresh private JFFS/opt/RAM tree and fake-tool
directory for each test. Regressions generate their small synthetic inputs directly;
static fixtures are added only when a tested contract needs them.

Keep the expected outcome and its evidence level clear. A captured capability
profile is an observation, not proof that a runtime feature passes on that router.

## Synthetic data-parser inputs

`tests/test_config_header.py` runs the real JSON producer on synthetic inputs,
then checks the source-only header projection and deliberately corrupted ledgers; it does not read a live settings file or expose
credential values in parser output. `tests/test_catalog.py` uses complete
synthetic catalog text with illustrative owners, repositories and URLs. Neither
suite downloads a manifest, validates package trust or exercises a config reader
or writer. Their ledger assertions establish parser behavior only.

## Kernel fixtures

`kernel/` contains controlled developer-only shell/C fixtures for the explicit
Linux namespace check. It uses actual BusyBox mounts and the runtime lifecycle,
but substitutes synthetic storage metadata for block-device/UUID admission.
All eleven scenarios pass at the accepted 45% checkpoint and retain their
individual 15-second bounds.

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
| 9 (native-root) | O9c fixed probes use the checked lifecycle; O10a adds the source-only dependency handoff, synthetic backend and package write; passes the accepted 44% Linux gate in 7.55s | FD8 and package executables remain synthetic; does not prove block-device/UUID admission or real opkg |
| 10 (native-probe) | Real aggregate deadline and native-config-root/chroot cleanup around the fixed probe; the fixture inspects the watchdog's descriptors while FD6/8/9 are held and verifies a known FD0 witness | Storage acquisition is a synthetic seam; does not prove outer storage IO acquisition, physical block-device/UUID admission or router execution |
| 11 (native-dependencies) | Actual stable lock, deadline, retained-Opt/root and source-only worker with a synthetic normal-opkg repair and 32-KiB write; watchdog descriptors and marker release after acknowledgement/reap while the lock is held; passes in 8.86s | Storage metadata and package executables are synthetic, so no router, physical block-device/UUID or real-opkg proof |

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
and remains part of the accepted 45% eleven-scenario gate; the eleventh
scenario reuses the existing root and synthetic-opkg setup.

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

The O9c baseline extension to scenario 9 invoked a trusted synthetic static
opkg stand-in through the fixed `/opt/bin/opkg --version` path. It witnesses
exact child argv, clean environment and working directory, closure of inherited
descriptors, and reading the retained Opt marker. It does not run Entware opkg
or establish the installed executable's provenance. At O9c, all ten scenarios
passed at candidate
`d0a04b3a6d2e57464803039255bccafc97d0e79c` in
[Linux/BusyBox CI](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/37977771431).
Scenario 9 took 6.17s. This historical baseline does not prove real opkg,
executable provenance or router execution.

The O10a extension to the ninth scenario calls the source-only dependency
handoff with the actual bundled bootstrap source and trusted synthetic static
opkg and capability stand-ins. It witnesses a missing-tool repair, ordinary
update/install arguments, post-checks, descriptor closure, and a 32-KiB package
write without inheriting the old probe's small file limit. It does not execute
Entware opkg or establish installed-code provenance. The accepted 44% Linux
gate passes all ten kernel scenarios; scenario 9 takes 7.55s and scenario 10
takes 10.19s. The outer compiled descriptor witness accepts the fixed shell
probe and dependency-handoff argument shapes, checks the held root and allowed
descriptor range, and forwards the complete argument list. The package writer,
opkg and capability executables remain synthetic, as does the storage metadata.
The full local and Linux/BusyBox counts are recorded in [PLAN.md](../../PLAN.md).
Configured opkg scratch selection and filesystem admission remain
separate limits; the host/Linux fixture does not prove router operation.

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

The eleventh scenario exercises the source-only
serialized dependency worker. It uses a dedicated process group, the actual
stable CFMgr lock, armed deadline, retained storage/root lifecycle and the
existing backend with synthetic opkg and capability programs. Its assertions
inspect the real watchdog shell's descriptors, including FD7 and high aliases,
and require the done marker, acknowledgement and exact child reap before the
owned active marker is removed; the stable lock must still be held at that
release point. The scenario retains
the same 15-second bound as the other kernel cases. It passes the exact 45%
Linux gate at `4c59937` in 8.86s. It cannot
prove physical storage admission, real opkg provenance, ARM32/Merlin behavior or
router acceptance.

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
`tests/test_native_dependencies.py` composes the fixed handoff with the actual
bundled backend and inert opkg/capability programs. It covers healthy no-op,
missing-only repair, explicit selected reinstall, ordinary negative outcomes,
source/result framing, writer failures, descriptor closure and package writes
above the old probe cap. Its focused combined run passed 72 tests with three
local BusyBox skips. The 44% full local and Linux/BusyBox results and the
repaired ninth-scenario proof are recorded above and in [PLAN.md](../../PLAN.md).
`tests/test_dependencies.py` checks the serialized worker through narrow
deadline/storage/root seams and real host file locking. Its 23 passing host
cases cover completed 0/1 outcomes, premature exits, exact completion records,
cleanup refusal, and foreign or partial active markers; one BusyBox case is
explicitly skipped locally. A real owner-group death leaves a controlled
FD7-closed child alive: fresh nonce replies prove liveness, and a second attempt
uses a fresh guard to reacquire the lock before the retained marker refuses it.
Both owned process groups are cleaned unconditionally and checked absent.
macOS substitutes only the unavailable Linux process-group snapshot; the
eleventh kernel scenario owns the genuine full Linux composition proof.
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
