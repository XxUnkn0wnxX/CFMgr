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
Linux namespace check. That lane uses actual BusyBox mounts and the real lifecycle,
with a documented substitution at storage device/UUID acquisition for the
storage scenarios. The execution-root consumer uses actual proc mount and
descriptor identities, readonly fallback checks and ordinary root teardown.
The native-root consumers add four fixed readonly views from an explicitly
readonly synthetic source, check each child identity and exercise reverse
cleanup. The ninth kernel scenario composes the quota-limited native-tmp root,
retained Opt root and fixed native devices. It stages opaque hosts/resolver
bytes before the first bind; checks readonly `/etc`, writable executable tmpfs,
configured byte/inode ceilings and the empty private `tmp/cfmgr-home`; and
verifies unchanged observer `HOME`, all 106 query slots, an FD9-backed
controlled writable source and a bounded anchored write reaching it. Opt is
unmounted first and must expose the exact empty readonly fallback before tmpfs
removal. FD8 remains a regular fixture file with synthetic metadata observation,
so the scenario does not prove physical block identity or UUID approval.

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

`tests/test_native_config.py` exercises exact byte copies, the per-file size
limit, NUL rejection, failure retention and the enclosing IO cleanup result.
`tests/test_native_tmp_root.py` checks quota validation and lifecycle metadata
with host fixtures; these mock mount tools and do not prove actual quota, write
or exec behavior. `tests/test_entware_root.py` covers retained-Opt success,
busy-Opt cleanup refusal and malformed API rejection;
`tests/test_entware_root_admission.py` covers the storage-admission boundary.
`tests/test_native_devices.py` covers fixed node metadata, inode rechecks and
host busy-unmount guard retention. Its upgraded actual BusyBox representative
and the ninth namespace scenario provide separate integration evidence in the
38% CI run. Host fixtures do not prove mount-enforced readonly behavior.
Native-root host tests use the focused query fixture in
`tests/isolation_helpers.py`, while its Linux/BusyBox consumer retains complete
capture evidence. Other host fault tests may share the focused query fixture in
`tests/isolation_helpers.py`, preserving real IO ownership, mount parsing,
framing and descriptor checks. The bare-root host success and actual
BusyBox/kernel consumers retain the full bounded-capture path. Document this evidence boundary
when adding cases, and review fixture guidance at implementation milestones.
