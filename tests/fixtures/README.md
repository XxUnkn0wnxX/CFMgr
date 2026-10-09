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
cleanup. The ninth kernel scenario now composes the quota-limited native-tmp
root with a retained Opt root. It stages opaque hosts/resolver bytes before the
first bind, checks readonly `/etc`, writable tmpfs scratch, executable
permission, configured byte and inode ceilings, and an empty private
`tmp/cfmgr-home`. It also checks unchanged observer `HOME`, all 78 query slots,
a controlled writable source mounted through actual FD9, a bounded anchored
write reaching that source, and Opt-first teardown followed by an exact empty
readonly fallback before tmpfs removal. FD8 uses a regular fixture file with
synthetic metadata observation, so this scenario does not prove physical block
identity or UUID approval. The retained-Opt upgrade passed the 37% CI gate. Host
fixture mirrors alone do not prove mount-enforced behavior, quota enforcement or
readonly fallback.
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
busy-Opt cleanup refusal and malformed API rejection; `tests/test_entware_root_admission.py`
covers the storage-admission boundary. The upgraded BusyBox and kernel consumers
passed the 37% CI gate and provide separate integration evidence. Host fixtures
do not prove mount-enforced readonly behavior.
Native-root host tests use the focused query fixture in
`tests/isolation_helpers.py`, while its Linux/BusyBox consumer retains complete
capture evidence. Other host fault tests may share the focused query fixture in
`tests/isolation_helpers.py`, preserving real IO ownership, mount parsing,
framing and descriptor checks. The bare-root host success and actual
BusyBox/kernel consumers retain the full bounded-capture path. Document this evidence boundary
when adding cases, and review fixture guidance at implementation milestones.
