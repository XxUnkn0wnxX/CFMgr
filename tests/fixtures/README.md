# 🧩 Test fixtures

[← Development guide](../../docs/development.md) · [Validation plan](../../PLAN.md#validation-matrix)

Use synthetic or reviewed sanitized data. Never copy live router configuration,
credentials, certificates, account identifiers, or private addresses into tests.

The ordinary router harness creates a fresh private JFFS/opt/RAM tree and fake-tool
directory for each test. Regressions generate small synthetic inputs directly;
static fixtures are added only when a tested contract needs them. A capability
profile is an observation, not proof that a runtime feature works on that router.

## Synthetic data and package reports

`tests/test_config_header.py` runs the real JSON producer on synthetic inputs,
then checks the source-only header projection and deliberately corrupted
ledgers. It does not read live settings or expose credential values. The
lifecycle tests likewise use synthetic settings and verify the five-row ledger,
including three feature rows and their mode/configuration implications, without reading or
writing live configuration.

`tests/test_catalog.py` uses complete synthetic catalog text with illustrative
owners, repositories and URLs. `tests/test_manifest.py` checks an independent
literal ledger, file order, parser-helper loading, framing and exact input,
file-count and declared-size bounds. BusyBox exercises helper-plus-parser
loading, hash normalization and malformed spacing/NUL refusal. These parsers do
not download or authenticate a manifest or catalog.

`tests/test_package_manifest.py` creates disposable Git repositories. It checks
raw blob hashes, Git modes and path ordering; explicit commit selection despite
dirty files or ref movement; refusal of replacement objects and inherited Git
redirection; and version extraction as data without executing the selected
entry. The host inventory tool is not part of router runtime.

`tests/test_package.py` exercises the source-only `modules/lib/package.sh`
through explicit fixture APIs, real parsers/helpers and the shared IO owner.
The manifest reader checks canonical ledger publication, framing, producer
status/stderr, cleanup, signal status and caller-state preservation. Declared
byte verification covers binary data above the text-capture cap, file-size
limits, same-size wrong bytes, path and file-shape refusal, digest failures and
malformed hex. A BusyBox case composes the real IO and digest path.

### Complete-tree report

The tree-report fixtures compare an independent `package-tree` ledger oracle
against the synthetic source tree. They check order-independent native listing,
exact expected paths and declared bytes, and refusal of missing, duplicate,
malformed, truncated, oversized or failed listings and unexpected regular,
hidden, empty-directory, link or special-file entries. Native `find` behavior
is exercised separately from host-only command doubles.

The observed namespace is only as complete as the native traversal. Matched
Merlin BusyBox traversal does not distinguish `readdir` error from EOF, so a
silent omission remains possible. The report is meaningful for a healthy,
private, immutable caller-prepared tree; it does not authenticate source,
validate installed permissions, establish semantic compatibility, or install
code.

### Entry-version report

`tests/test_entry_version.py` checks the literal version convention, declared
size, operand rules, optional final LF, global NUL/ASCII 28 refusal, acceptance
of unrelated controls/high bytes, and dense input at the parser limit. The
package consumer tests compose this parser with the tree and digest checks,
compare exact version-ledger bytes, and exercise mismatch, parser status/stderr,
output/footer, cleanup and caller-state failures. No source entry is executed.
The report proves literal entry/manifest version agreement only.

### Supplied package-policy report

The policy fixtures cover accepted equal/newer versions and ledger bytes,
downgrade and manifest-version mismatch, invalid comparator results,
requirements-path shape and aliases, and malformed, duplicate, oversized or
nonmatching requirement rows. Separate real-owner and BusyBox compositions
exercise the complete report. It validates only the caller-supplied structural
and version policy, not policy provenance, semantic compatibility, complete
profile selection, permissions or installation.

### Catalog request plan

The fixture API uses synthetic catalog and manifest files, explicit helper and
parser paths, and no network access. Cases check exact output and footer,
destination-key joins independent of row order and source URL path, commit
pinning, selector mismatch, and quiet refusal on transport or cleanup failures.
The report cannot prove URL provenance, branch mapping, repository authenticity,
profile completeness, source-byte validity or installation.

### Configuration reports

`tests/test_config_header_report.py` composes the real IO owner with the JSON
and header parsers over fresh synthetic configuration. It checks exact
header-only ledger framing, token-output capacity, producer status/stderr and
cleanup refusal. A BusyBox case exercises the actual composition. These tests
do not validate other settings or credentials.

`tests/test_config_lifecycle.py` checks exact passive, enabled and
maintenance-only rows; required feature fields and parent selection; enabled /
configured, Cloudflared maintenance and mode implications; and malformed
projection framing. The previous header projection remains a separate mode.
The fixture does not inspect installed feature availability, credentials or the
full settings schema.

### Setup-state report

`tests/test_setup_state.py` checks all seven accepted guard states, the four
transitional `unknown` generation cases, canonical generation and identity
bounds, exact framing, malformed rows and original-size mismatches. Owner cases
verify that retained/transitional states do not read CONFIG, installed state
requires a generation-matched lifecycle projection, and reset-passive requires
every projected feature/developer flag off with mode `none`. Tests also cover
producer and cleanup refusal; a BusyBox case composes the installed-state path.
The report establishes saved-state consistency only, not installation,
identity authenticity, setup completion or cleanup authority.

## Kernel fixtures

`kernel/` contains controlled developer-only shell/C fixtures for the explicit
Linux namespace check. It uses actual BusyBox mounts and runtime lifecycle code,
but substitutes synthetic storage metadata for block-device/UUID admission.
Each namespace scenario has a 15-second bound.

| Scenario | Evidence established | Limit |
| --- | --- | --- |
| 1 (success) | Retained-storage callback and checked cleanup with real mount observations and a held directory descriptor | Storage-device and UUID approval are substituted |
| 2 (busy) | Busy mount prevents teardown and retains the guard | Does not model physical hotplug |
| 3 (signal) | Interruption preserves the incomplete-operation guard | Does not prove cleanup after an uninterruptible kernel operation |
| 4 (primitive) | Controlled executable reaches chroot and exact-mount busy behavior | Uses a developer fixture, not Entware payloads |
| 5 (image) | Read-only executable image permits execution, rejects root writes with EROFS, and remains writable through its outside alias; mapped-image busy state blocks unmount until the actor exits | Does not qualify firmware executable closure |
| 6 (contained) | Controlled ELF/profile image verifies staging/hash and fixed-probe supervision, closed external descriptors, bootstrap links, null, EROFS and absent proc/shell/writable Opt before guard cleanup | ELF and profile are synthetic |
| 7 (worker-lifetime) | Inherited root descriptor blocks teardown; after chroot/setsid the child drops it but retains root/cwd and proof pipes; removing Opt exposes readonly empty fallbacks until the child exits | Filesystem quiescence does not prove arbitrary descendant reaping |
| 8 (execution-root) | Readonly-root owner checks mount identity, fallback write refusal, restored caller descriptors and completed teardown before RAM removal | Not an operational worker or router acceptance |
| 9 (native-root) | Quota-limited tmpfs, retained Opt, fixed devices, six-file config staging and a controlled writable source use actual BusyBox `dd`/`cmp`; checks readonly `/etc`, binary CA bytes, quotas, private HOME, mount queries, device metadata and Opt fallback | FD8 storage metadata and package executables are synthetic |
| 10 (native-probe) | Real aggregate deadline and native-config-root/chroot cleanup around the fixed probe; checks watchdog descriptors while FD6/8/9 are held and a known FD0 witness | Storage acquisition is synthetic; no physical device/UUID admission |
| 11 (native-dependencies) | Stable lock, deadline, retained Opt/root and source-only worker with synthetic opkg repair and package write; checks watchdog descriptors, acknowledgement/reap and marker release while locked | Storage metadata and package executables are synthetic |

The fixed shell-probe extension uses trusted host BusyBox and its loader. The
runner adapts only the private BusyBox copy's existing PT_INTERP region, checks
the rewrite with `readelf`, and stages dependencies from the observed `/lib`
and `/usr/lib` layout. Static fixture wrappers inspect descriptors outside and
inside chroot, then forward to real chroot/BusyBox applets. This proves host
Linux behavior, not ARM32, Merlin loader/NSS/TLS behavior or package execution.
Firmware cache files are never fixture inputs.

Host lifecycle tests cover descriptor, framing, ownership and cleanup faults
through narrow fixture seams. The Linux namespace tests remain the evidence for
actual mount behavior. Python host mocks are not reported as privileged chroot
or router tests. The native opkg fixtures never execute Entware opkg or install
packages; dependency tests use inert opkg and capability programs. The actual
BusyBox composition is distinct from host mirrors. See [PLAN.md](../../PLAN.md)
for validation records and the [development guide](../../docs/development.md)
for commands and test structure.
