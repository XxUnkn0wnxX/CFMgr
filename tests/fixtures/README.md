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
cleanup. The ninth kernel scenario now uses the quota-limited native-tmp API: it
stages opaque hosts/resolver bytes before the first bind, then checks readonly
`/etc`, writable tmpfs scratch, executable permission, the configured byte and
inode ceilings, and an empty private `tmp/cfmgr-home`. It also checks that the
observer's `HOME` is unchanged, all 64 query slots, tmpfs-first teardown and
reverse native-view cleanup. The upgraded kernel scenario is pending CI; host
fixture mirrors alone do not prove mount-enforced behavior or quota enforcement.
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
or exec behavior. The native-root BusyBox representative and the upgraded kernel
scenario are pending CI. Host fixtures do not prove mount-enforced readonly
behavior.
Native-root host tests use the focused query fixture in
`tests/isolation_helpers.py`, while its Linux/BusyBox consumer retains complete
capture evidence. Other host fault tests may share the focused query fixture in
`tests/isolation_helpers.py`, preserving real IO ownership, mount parsing,
framing and descriptor checks. The bare-root host success and actual
BusyBox/kernel consumers retain the full bounded-capture path. Document this evidence boundary
when adding cases, and review fixture guidance at implementation milestones.
