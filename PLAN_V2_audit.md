# CFMgr v2 — audit record

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Current handoff](PLAN_V2_handoff.md) · [Review notes](PLAN_V2_review_notes.md) · [Working rules](AGENTS.md)

This record owns substantive audit findings, their evidence, recorded review
agreement or user decisions, and repair dispositions linked to existing subgoals.
The checklist remains authoritative for acceptance; the handoff owns current work,
permissions, jobs, next actions and session lineage. Deferred risks remain in the
review notes. This record creates no requirements, product credit or permissions.

## S02.01, S14.01, S14.04–S14.08 module fragmentation correction

On 2026-10-17 the user rejected the archive implementation's many separate shell
and AWK helper files and required category-level consolidation: backup in one
module, config in one module, with networking/DDNS and other responsibilities
similarly grouped. The parent agrees this was implementation drift: the existing
S02.01 package-layout contract already says not to create one library per helper.
The correction preserves functions, parsers, behavior and safety contracts while
moving them into a small set of owning categories. It does not remove required
features, lower acceptance gates or award progress.

All affected writers were stopped and a complete verified recovery snapshot was
made before replacement. Current location/restore details, ownership and migration
state belong in the handoff; the requested private category guide is
`.tmp/module-layout.md`. The local structural correction is complete: 48 runtime/
parser files became nine owners, with all 423 prior named functions and 17 AWK
programs preserved. Parsers are fixed literal data inside their owners; candidate
validation extracts them as data without sourcing candidate code. Independent
review required exact physical-owner enforcement and preservation of passive
extension syntax admission; both are implemented and focused-tested.

Final review also caught and repaired a mechanically altered storage-file
admission predicate and missing storage imports in Linux fixture/early-cleanup
paths. File/symlink refusal is tested before observation; source review confirms
cleanup imports precede traps. Fixed worker/descriptor and copied cleanup-code
contracts were retained. Complete affected host groups and static gates passed,
with explicit platform skips and limited ShellCheck analysis recorded in the
handoff and `.tmp/consolidation-validation.md`. This is local refactor proof, not
native CI acceptance or completion of the unfinished manual archive consumer.

## S14.01, S14.04–S14.08 archive foundation review

Independent Astra source review of the uncommitted archive foundation returned
**REVISE**. Parent accepted the corrections below without changing product scope
or acceptance. These findings concern the actual native execution and payload
contracts; partial foundation proof does not establish the manual-create consumer.

- The native tar reader can allocate GNU long-name input before listing. Parent
  and reviewer agreed that retained raw headers must pass the bounded fixed-format
  parser before native tar sees them. The parser checks raw type, short flat name,
  checksum, exact offsets and two zero blocks. Parent review also corrected a
  final-prefix-byte omission and tests whose small size bounds masked rejection.
  Focused raw-parser proof passed 38 tests in 0.99s wall; native execution is pending.
- YAML dependency deduplication originally treated every reference to the selected
  certificate path as optional management data. Required CA uses now upgrade the
  pending capture row regardless of `origincert` ordering. Tests cover both live
  and recovery paths and reject a missing required member. The complete semantic
  group passed 16 tests in 28.50s wall, including actual host archive verification
  with coherent config/YAML/runtime-JSON/PEM authority.
- Disk inode lookups inside the archive attachment callback escaped the command
  supervisor deadline. Parent and reviewer agreed to fixed supervised identity
  checks at operation admission/completion and guarded cleanup, retaining existing
  mount/source checks and child directory anchoring. Unknown identity grants no
  cleanup or publication authority. Correction and focused proof are in progress;
  this does not promise recovery from an uninterruptible kernel filesystem call.
- Flattened PEM token bodies require OpenSSL base64 decoding with `-A`; the old
  helper could refuse valid bodies longer than 1024 characters. The production
  correction and actual-helper regression are in progress. Original certificate
  digests and decoded account association remain mandatory.
- The initial full-verifier fixture contradicted its own certificate digest and
  required ownership rows. The corrected compact fixture has coherent authority,
  scope-relative optional-certificate notes and an explicit JSON-child FD9 lock
  contract. Separate full owned-draft, backup-YAML, input and history capture proof
  remains due; fixing the compact fixture does not waive those consumers.

Source review found the archived-config authority, typed JSON/certificate joins,
required inventory checks and ordinary before/copy/after snapshot design coherent.
The history adapter's host group passed 18 tests in 57.23s wall; actual production
supervisor/process/cron integration is still required. Native `find` lacks the
needed depth controls; the supported one-level `ls` fallback requires a child
memory limit because it allocates entries before emitting output. Host parser
proof, source/image inspection and future native CI remain distinct evidence.

## Migration provenance

At the user's request on 2026-10-16, historical audit and source-review passages
were moved from `PLAN_V2_handoff.md` at
`8e6b79ffa8d2697c4232d3b978e13eea1517e23b` into this tracked root-level companion.
The report bodies below preserve the recorded evidence and conclusions. This
relocation is not a new acceptance audit, a fresh firmware verification or
retroactive joint sign-off. Review agreement is claimed only where recorded;
unrecorded details remain unverified. Historical pending work and ownership in
quoted records describe their original stage and grant no current authority.

The complete original is preserved privately at
`.tmp/diagnostics-audit-20261016/PLAN_V2_handoff.before.md` and in the source commit.
Current scope and results are linked from the handoff; historical source evidence
retains its own revision and platform limits.

Parent and independent read-only migration reviewer verified all 20 relocated
passages and links on the prepared tree based on `8e6b79f`. The session ledger,
next-session and permissions/recovery tail are unchanged; all 36 historical CI
run links remain in the handoff. This is preservation review, not runtime
acceptance. Planning/link/privacy and whitespace checks passed.

## S03.02 schema implementation readiness review

The user approved implementation on 2026-10-16 after reviewing the corrected
schema/compatibility and option inventory. Independent Astra planner review
returned **PASS WITH NOTES**; parent resolved the representation details before
releasing the runtime package. This is design/source evidence, not acceptance.

- Fresh schema 2 has explicit schema-1 compatibility; unchanged receipt/bootstrap
  protocols remain independent. A new bounded validator must reach fresh,
  retained and scoped Save consumers, with tolerant status kept separate.
- Selected related policy objects contain every operand needed for cross-field
  checks. Null policies do not select defaults, and null siblings cannot waive
  inequalities. Typed credential, ownership, migration and history layouts are
  explicit; certificate format metadata does not claim authentication.
- Pinned Merlin backend `CKN_STR3`/length validation gives canonical positive
  forced-refresh days 1–999 for that native setting interface, default 14.
  Parent had verified the backend trace; planner independently checked cached
  frontend width and accepted the interface-bound derivation. Neither claims
  a universal direct-NVRAM/watchdog ceiling; native use revalidates the profile.
- Log size/count have no product quota. Parent inspected Entware's logrotate
  recipe (3.22.0, release 2), then tagged upstream source: size parsing converts
  to `off_t`, count is `int`, and configure enables 64-bit offsets on 32-bit
  systems. For the supported signed-64-bit offset/signed-32-bit count contract,
  positive scaled bytes fit 9223372036854775807; total files fit 2147483648
  because the emitted historical count is total minus one. Validate decimal
  lexemes exactly using per-unit limits, without AWK float rounding or work
  proportional to selected counts. Installed-build/filesystem and bounded
  rotation qualification remains with logging, including rejection of narrower
  unsupported execution limits.
  [Entware recipe](https://github.com/Entware/entware-packages/blob/master/utils/logrotate/Makefile),
  [3.22.0 parser](https://github.com/logrotate/logrotate/blob/3.22.0/config.c#L1408),
  [types](https://github.com/logrotate/logrotate/blob/3.22.0/logrotate.h#L61),
  [large-file configuration](https://github.com/logrotate/logrotate/blob/3.22.0/configure.ac#L24).

Parent mirrored the approved requirements in plan/checklist and froze concrete
internal shapes in the ignored design record. Required proof remains populated
schema-2 consumer behavior, legacy/unrelated-byte preservation, typed-reference
and invalid-policy rejection, tolerant status, coherent package compatibility
and the existing focused/CI gates. No runtime gate or checkbox follows from this
review. No firmware, router or provider execution was performed.

Implementation review on the prepared tree based on `d0da7ec`:

- The shared definition-only schema validator now reaches fresh install,
  retained launch, Store and scoped Saves. Status deliberately remains tolerant;
  schema-1 fixtures retain their original shape and preservation behavior.
- Parent review corrected composite-enum admission, history address predicate
  drift, incomplete fresh-passivity checks and constructor/source grammar drift.
  Cheap negative cases preserve those fixes. Native decimal limits are compared
  without floating-point multiplication or count-proportional work.
- Schema-2 backup Save now replaces only changed known destination scalars,
  preserving nested extension bytes. New exact-byte tests cover that boundary;
  schema-1 behavior and initial null-to-destination construction stay compatible.
- Independent Sol source review returned **PASS WITH NOTES**, with no further
  material correctness or security findings. It inspected references, policies,
  numeric limits, fresh passivity, legacy admission and package/parser wiring.
  Parent agrees with that source-review disposition. Final complete focused
  groups and exact-candidate Linux/vendor BusyBox/core proof remain pending.

Focused test-cost review identified host-harness overhead, not a failed product
deadline: the populated retained replacement completed 188 supervised probes,
published generation 2 and reached final cleanup before its aggregate 20-second
test timeout expired on a heavily loaded host. No orphan remained; inspected
final probe error files were empty. The new populated fixture alone now allows
30 seconds overall; existing legacy fixtures retain 20 seconds, per-probe bounds
and production deadlines are unchanged. The focused rerun passed five cases in
33.34 seconds (replacement 17.83 seconds, healthy 13.27 seconds). Shared-target,
Cloudflared On/installed and per-record DDNS option positives reuse the existing
cheap parser cases without another expensive integration matrix. Final complete
groups remain the acceptance gate. The final populated schema-2 module passed
all 68 cases in 76.21 seconds. All complete affected local groups subsequently
passed: 506 cases, 43 platform skips and four optional diagnostics excluded.
Group times ranged from 2.84 to 210.50 seconds; installation's actual failure/
recovery proof dominated the longest group. Changed-file ShellCheck and common
statics passed. Parent final review is complete. Seven complete Linux/vendor
BusyBox Quick selections passed at `2dec8a623dba36a4e4718e69b6881918120e2a13`:
548 passed, one workstation-only skip and four optional diagnostics excluded.
Group costs were 25.14–231.16 seconds; all remain within the practical range.
Immutable package setup is already reused, and the remaining acquisition/
dependency cost is actual native supervision/installation/publication proof.
No speculative test matrix or full local suite was added.

Verified closure: [final core Checks 38900418249](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38900418249)
passed every required job/step at that exact candidate, after all Quick groups.
Host: 697 passed/28 platform skips, 169.60 seconds wall. Mandatory vendor BusyBox:
724 passed/one workstation-only skip, 687.40 seconds wall. Four optional
diagnostics remained excluded per phase. Total job time was **14m44s**, compared
with the previous accepted **15m09s**, despite 69 additional cases. This is an
observed required-run comparison, not an isolated benchmark attributing the
difference to one optimization. Existing immutable fixture reuse, cheap combined
parser cases, reused valid statics and focused grouping kept the new proof lean;
required safety assertions, local/CI boundaries and the 20-minute runner limit
remain intact. No additional cheap coverage-preserving reduction was identified.
Parent accepts S03.02 only. Live Merlin/ARM, provider and future lifecycle/logging
qualification remain with their owning goals and beta gates.

## S09.05–S09.08 native DDNS ownership source review

Read-only source review, 2026-10-16, supporting the user's clarification that
CFMgr ownership includes Merlin's native DDNS settings, handler and lifecycle.
This supplies evidence for S09.05–S09.08 and the S03.02 representation boundary;
it awards no implementation or acceptance credit.

Pinned Merlin 3004.388.12_2 source revision:
`433fc608f5fc1689f3d3c3ab5cd2a7d57102260f`. Parent traced the native UI; an independent
read-only reviewer traced backend dispatch. Parent re-read the key backend
sections directly from the pinned official raw source and agreed with these
findings:

- The native DDNS page maps its switch to `ddns_enable_x=1/0` and submits a
  default `restart_ddns` action. Hostname and refresh settings map to
  `ddns_hostname_x` and `ddns_refresh_x`; the selected provider is
  `ddns_server_x`. Conditional UI paths add certificate-related actions.
  [Native UI](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/www/Advanced_ASUSDDNS_Content.asp#L1497).
- The service dispatcher maps `restart_` to stop plus start; the `ddns` branch
  invokes `stop_ddns()` then `start_ddns()`. Start exits early when the saved
  native enable value is zero. Enabled start still depends on WAN/readiness and
  other checks; requesting start does not establish provider success.
  [Dispatcher](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/services.c#L16779),
  [enable admission](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/services.c#L4582).
- `stop_ddns()` signals native DDNS clients, not custom `ddns-start` or CFMgr
  worker descendants. Custom start calls `ddns-start` synchronously with a
  120-second timeout. Native stop therefore cannot substitute for CFMgr's own
  admission suppression and bounded owned-worker quiescence; a queued request
  is not proof it interrupted an active handler.
  [Custom start and stop](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/services.c#L5055).
- The service CLI calls `notify_rc()`, prints `Done` and returns zero; the DDNS
  dispatcher does not propagate `start_ddns()`'s result. The published build
  falls back to prebuilt `notify_rc.o`, so exact notification waiting semantics
  remain unverified. CLI exit zero alone cannot certify completed apply/stop.
  [CLI](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/services.c#L20802),
  [build fallback](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/shared/Makefile#L141).
- The start/restart branch also calls `update_srv_cert_if_ddns_changed()`;
  a changed nonempty hostname can regenerate/reload a certificate, even when
  DDNS start returned early for Off. Stop has conditional tunnelbroker firewall
  and OpenVPN-profile side effects. These are part of the existing required
  matched-firmware side-effect review; no wider settings mutation is approved.
  [Certificate helper](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/shared/misc.c#L654).

The original private `ddns-start` reference reports outcomes through
`/sbin/ddns_custom_updated 1/0`, consistent with the documented custom-DDNS
callback interface. Current official Custom DDNS, User scripts, Addons API and
Custom config files guidance was consulted. The older wiki's suggestion to report
unknown outcomes as success is not adopted: the approved CFMgr contract requires
truthful results and separate retry admission.

Disposition: plan/checklist now explicitly require native backend/display parity,
distinct intent/readback/lifecycle evidence, preserved Off during settings Save,
and guarded outstanding work. These are pending implementation requirements,
not repaired or tested behavior. Persistence, actual GUI rendering, notification
completion and model-specific lifecycle effects remain qualification work under
the existing development/beta split. No router command or runtime code executed.

## S04.02 scoped concurrent Save review

2026-10-16, baseline `95ecbdd`: parent and independent Astra scope audit agree
PASS WITH NOTES that S04.02 is the next smallest independently completable
foundation. The user approved starting this package. Current consumers are
manager preference Save, backup-destination Save and retained storage observation;
future provider/updater/connector workflows keep their own integration gates.

Existing Store code acquires the common writer lock, rereads authority, patches
only reviewed fields, compares exact content and permits two merge attempts.
The manager and backup menus confirm before entering the Store. S04.03 supplies
accepted durable publication; relevant shared-lock proof already exists without
claiming the complete S04.08 provider/connector contract.

Two precedence directions must remain distinct: reviewed Save may replace earlier
same-field manual edits within its explicit intent, while a later committed Off
or config change defeats an older worker snapshot. Check/Auto intent coupling
remains unchanged. Preserve unrelated saved guard data, but refuse a currently
active transaction marker. The contract uses cooperative locks and immediate
content checks, not an atomic compare-and-swap guarantee against arbitrary root
writes after the final check.

Missing evidence at baseline: the Store raw-edit fixture appends whitespace;
parser tests provide an already-current document; borrowed observation lock tests
replace the publication body. These prove freshness/parsing/exclusion respectively,
but not complete semantic interleavings. Closure required actual Store/consumer
proof of same-field precedence, unrelated-data preservation, meaningful
same-generation remerge and bounded conflict refusal, plus the actual observation
publisher's refusal to overwrite later Off/config authority. No runtime defect
was inferred solely from these coverage gaps. The closure evidence below covers
the current consumers; the handoff records the resulting checkpoint state.

The implemented proof strengthens the two existing installed-menu journeys and
adds two Store and two retained-publication cases. No production change was
needed. Parent and independent Astra implementation review agree PASS WITH NOTES:
the Store mutation occurs after old-state staging, same-generation semantic edits
require a second scoped merge, repeated edits refuse within two attempts, and
both real menu confirmations permit another owner to acquire the common lock.
Exact expected bytes retain fresh unrelated settings and opaque ownership data.
The real retained publisher rejects newer Off/config authority both before
preparation and after candidate staging, with the appropriate recovery evidence.

The ownership payloads are preservation fixtures, not implementation or acceptance
of future auth/removal workflows. Retained publication adapts host lock admission
and supervision; actual Linux flock/descriptor proof remains in the complete
Store module. Together these tests cover the current consumers without claiming
an entirely unadapted router execution. Existing failure cases remain intact.
Cost containment reuses the existing installed-menu runs and shared package
fixtures; only the four required interleaving cases add executions.

Final complete local gates passed on the prepared tree based on `95ecbdd`:
Store/parser/settings/backup **102 passed, four Linux skips**, 203.15s wall
(92.55s user / 78.58s system), including common statics; retained launch
**21 passed, one Linux skip**, 150.00s wall (67.11s user / 46.60s system).
The combined local group is within the practical three-to-four-minute range;
its slowest cases remain required recovery and real installed-menu proof.
The four new interleavings and two strengthened menu journeys also passed their
small diagnostic selections before these final groups. No full local suite ran.
Planning/package, Ruff/format/compile, shell syntax, shfmt and whitespace passed.
ShellCheck was not rerun for this tests-only change; production files are unchanged.
At published candidate **`dad30c8ab9c6ac3f2f93d12e8efd9e0187f502ea`**, complete
focused Ubuntu/vendor BusyBox groups passed:

| Group | Result | Process wall / user / system |
| --- | --- | --- |
| [Quick A 38885975614](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38885975614): Store/parser/settings/backup | 106 passed | 85.69s / 46.80s / 34.96s |
| [Quick B 38885979958](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38885979958): retained launch | 22 passed | 152.81s / 74.29s / 77.98s |

Parent verified exact SHA and every required job/step. All five local platform
skips are covered; only the separate optional diagnostic host-baseline step was
skipped. The measured groups remain within the practical budget. The measured
retained group is about nine seconds above the previous 143.66s gate while
covering both required later-Off boundaries; no expensive duplicate journey or new fixture
framework was introduced.

Final [core Checks 38886407905](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38886407905)
passed at the same exact candidate after both focused gates. Host proof:
**628 passed, 28 platform skips**, 172.93s wall (37.98s user / 45.31s system).
Vendor BusyBox proof: **655 passed, one workstation-only skip**, 716.70s wall
(338.37s user / 286.18s system). Four optional diagnostics were excluded per phase.
Parent verified every required job/step; the complete job took **15m09s**, within
the unchanged 20-minute core runner limit. No extra full local suite or timing-only
run was introduced. Parent review agrees that S04.02's current-consumer evidence
is complete. Future feature consumers retain integration gates, and real
Merlin/ARM qualification remains beta-only. No runtime repair or acceptance
relaxation was required.

## S04.03 durable staged commit review

2026-10-16, baseline `358ed0c`: the user approved the smallest independently
completable foundation package, S04.03. Parent and independent Astra scope review
agree that the current authority writers below define the closure inventory.
Unfinished provider, tunnel, updater and restore consumers are outside this
package; their future transactions still need their own integration proof.

| Current writer | Publication and failure contract |
| --- | --- |
| Update-settings Save | The native Store takes the shared lock, checks space, preserves old/candidate bytes and a hash/generation intent, then publishes within JFFS. Exact-old recovery never replays a candidate; exact-candidate recovery verifies it; divergent data remains guarded. |
| Backup destination Save | The same Store first prepares an inert folder on the pinned drive, then publishes its identity in JFFS. Drive loss preserves that folder and JFFS evidence; explicit JFFS recovery works without the drive. These are recoverable stages, not cross-filesystem atomicity. |
| Retained storage observation | The separate `.storage-observation` protocol preserves old/candidate/intent before publication, checks exposed flush/readback results, and blocks subsequent admission while guarded. The repair adds its missing pre-change space check. |
| Fresh installation | The private fresh directory and `installing` record block reset while package/config/entry are staged and verified. Corrected completion-marker retirement prevents a failed final record write/flush from becoming an unguarded `complete` installation. |

The baseline Store tests did not reach a failure after a successful live rename.
New focused tests exercise exit-zero flush errors on stderr, post-rename damaged
readback, failed candidate staging, and conservative recovery. Their host module
passes **16 tests with four Linux skips**, 45.73s wall, 22.00s user and 17.13s system.
Recovery assertions follow the actual faults; redundant standalone variants were
removed while retaining the existing exact-old phase proof.
These local results describe the prepared working tree; the exact-candidate
platform results below supply separate evidence.

The baseline installer renamed `.setup.complete` away before final verification,
then attempted a best-effort rewrite to `installing` on failure. A deterministic
double-fault test demonstrated that a failed rewrite could leave `complete` without
its admission blocker. Parent and independent Astra repair review agree to retain
the existing `.setup.complete` while the complete record is copied, flushed and
verified; remove only that exact regular file through the native supervisor after
verification. Preserve unresolved status and avoid a new rollback write. Retained
launch already rejects this marker. Add the observation space check before guard
creation, using bounded old/candidate sizes and the existing native `df` route.
The space check and guarded completion repair are implemented. Independent Astra
implementation review returned PASS WITH NOTES, with no blocking runtime finding.
Parent confirmed the removal's fixed path/one-operand contract, unresolved-status
propagation and guard ordering. The review's test-comment correction is applied:
retained intent binds the old snapshot digest and target generation/size, not a
persisted candidate digest. No recovery format change was needed.

Complete local installer proof passes **21 tests, one Linux skip**, 125.21s wall
(48.14s user / 33.43s system). Complete retained-launch proof passes **19 tests,
one Linux skip**, 108.66s wall (42.85s user / 30.65s system). The early apparent
successful injected retained failure was a fixture taking the unchanged no-op
path; the corrected marked publication path rejects the exposed fault. Existing
entry-route fixtures needed quoted absolute substitutions for workspace paths
with spaces; their byte-for-byte inverse and all four routing cases now pass.
Remaining local groups also pass: backup/settings **50 passed**, 69.49s wall,
and shared dispatch/installed/dependency consumers **84 passed, 28 platform skips**,
30.08s wall. Across distinct complete selections: **190 passed, 34 platform skips**,
four optional diagnostics excluded. Required statics and parent review pass;
changed runtime ShellCheck was checked separately after stopping an unnecessarily
broad whole-tree scan above three minutes. Relevant ShellCheck cost was 12.90s.
The four complete vendor BusyBox Quick groups pass at
`457296c79bd786083eb944e0c1cea2ecc9ddce10`: **227 passed, one workstation-only
skip**, four optional diagnostics excluded. Parent verified every required job
and step. The skipped non-Linux supervisor case passed locally.

| Focused CI group | Required proof | Result | Process wall / user / system |
| --- | --- | --- | --- |
| [A 38880057746](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38880057746) | Store faults/recovery and settings/backup consumers | 70 passed | 83.91s / 38.99s / 40.33s |
| [B 38880061478](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38880061478) | Completion guard, native dispatch/ownership, installed admission and acquired package | 116 passed, one workstation-only skip | 176.38s / 86.15s / 44.43s |
| [C 38880065872](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38880065872) | Complete retained observation/admission consumer | 20 passed | 143.66s / 70.54s / 72.97s |
| [D 38880070154](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38880070154) | Shared repair and actual supervised fresh installation | 21 passed, four optional diagnostics excluded | 230.38s / 119.97s / 109.48s |

All groups fit the practical three-to-four-minute limit. The roughly 230s
dependency group retains the required production-supervised installer, including
the new removal action; the direct probe test alone would not establish this
wiring. Its cost is effectively unchanged from the prior roughly 230s baseline.
No further small safe reduction or extra benchmark is justified.

Final [core Checks 38880966640](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38880966640)
passed at the same candidate after all four Quick groups. Parent verified the
exact SHA and every required job/step. The single Ubuntu job took **14m40s**,
09:30:54–09:45:34 UTC on 2026-10-16.

| Required core phase | Result | Process wall / user / system |
| --- | --- | --- |
| Host/common | 624 passed, 28 platform skips, four optional diagnostics excluded | 164.71s / 36.01s / 41.30s |
| Vendor BusyBox | 651 passed, one workstation-only skip, four optional diagnostics excluded | 690.62s / 329.51s / 270.99s |

The mandatory BusyBox phase closes the host-only platform skips; the remaining
workstation-without-proc boundary passed locally. Installer call cost is 157.39s,
retained repair/return 87.44s. The job fits the unchanged 20-minute limit, compared
with the preceding 16m07s run; this single run does not establish a general speedup.
Parent review accepts the scoped S04.03 repair and current-writer failure/recovery
proof. No additional full local suite, benchmark, optional diagnostic or live
router execution was needed; this is a subgoal checkpoint, not main-goal acceptance.

Once live data and its complete record have passed exposed flush/readback checks,
a failure flushing the final guard deletion is cleanup uncertainty. Return
non-success without claiming rollback or recreating a guard after verified commit.
Earlier publication failures must preserve their existing recovery evidence.

The documented firmware limit is unchanged. Cached JFFS2 source at Merlin revision
`433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` was rechecked against the five recorded
SHA-256 hashes in the ignored provenance inventory: `jffs2_fsync` ignores the
return from `jffs2_flush_wbuf_gc`. Successful exposed calls and cached readback
therefore do not certify persistence across restart. Official
[Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts) and
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
were consulted for the existing storage/entry boundaries; no hook, service or
live-router operation is part of this repair. Representative host/BusyBox proof
remains distinct from deferred Merlin/ARM/flash beta qualification.

## Installer and retained-test cost review

2026-10-16, baseline `33bc998`: user requested optimization of the existing
installer and retained-repair tests before another product target. Existing
module-scoped package/compiler fixtures are already reused; the reported slow
durations are test calls. Fresh mutable ext4/mount/PID state remains necessary.
The installer supplies the remaining core complete production-supervised view
path; replacing it with foreground fixture operations would lose that wiring.
Parent and independent reviewer retain this proof rather than changing its gate.

Finite monotonic phase records at `de66d22` locate the retained cost:
[complete retained module 38870343255](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38870343255)
passed 15 tests in 122.33s pytest / 122.53s wall (73.17s user + 44.78s system).
Repair was 34.30s, absent attachment 3.07s, healthy return 19.30s, DNS outage
18.88s and force 33.94s. Parent and independent reviewer agree the return and
DNS-outage requirements can share one fresh launch: prove current attachment,
successful manager admission, unchanged opkg/config, no observation guard and
deferred DNS together. Initial repair already proves normal SRV/A verification;
forced reinstall stays separate. The specification does not require separate
successful-DNS and failed-DNS return permutations. This removes a repeated
launch while preserving distinct required assertions. No product requirement,
runtime deadline or accepted count changes.

The [complete dependency module 38870338830](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38870338830)
passed at the same SHA: 21 core tests, four optional diagnostics excluded,
229.52s pytest / 229.74s wall (119.44s user + 109.08s system). Installer repair
accounts for 115.85s and real publication 64.84s; pre/post capability checks are
1.03s/1.59s. These are active production operations, not an unexplained idle
wait. Keep the full supervision/repair/publication connection. Isolate this
consumer from the remaining dependency cases for bounded Quick feedback; any
larger production optimization requires its own evidence and scope review.

Final candidate `9f62a4a5d9a532f661f835205a420f0fffa8fdc4` preserves all runtime
bytes and all 36 affected core test cases. Final local modules passed 27 tests
with nine Linux skips and four optional diagnostics excluded, 25.42s pytest /
25.97s wall. Relevant static checks and parent review passed. Complete focused
vendor BusyBox evidence at that exact revision:

| Selection | Result | Pytest / process wall | User / system CPU |
| --- | --- | --- | --- |
| [Installer 38871209489](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871209489) | 1 passed | 185.35s / 185.54s | 96.52s / 87.86s |
| [Other dependencies 38871213036](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871213036) | 20 passed | 38.81s / 38.96s | 19.73s / 14.79s |
| [Retained module 38871217086](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871217086) | 15 passed | 124.03s / 124.33s | 63.63s / 59.74s |

Pytest collection proves the first two selections are disjoint and together cover
all 21 core dependency nodes. Every required Quick step passed; its optional
host baseline was not requested. Private selectors, JSON/logs and local receipts
are retained under `.tmp/test-cost-20261016/`.

**Measured outcome:** retained full launches fell from five to four. Combined
return/DNS admission took 22.77s versus the previous separate 19.30s + 18.88s.
However, unchanged repair/force rose from 34.30s/33.94s to 41.75s/40.83s, and the
whole group changed from 122.53s wall / 117.95s CPU to 124.33s / 123.37s. Those
runs do not establish a reliable whole-group speedup or CPU reduction. Runner
variation is a plausible explanation, not proven causation. Preserve the
redundancy reduction without advertising a guaranteed saving or adding benchmark
reruns. The group stays close to the two-minute target. Installer repair was
114.19s, checks 1.01s/1.55s and publication 62.85s; its isolated 3m06s group stays
within the practical three-to-four-minute range. The remaining dependency group
is under 40s. No safe additional small shortcut was identified.

Instrumentation history: `3612adf` Quick runs 38869722557/38869726230 passed but
pytest descriptor capture hid their successful phase reports. `de66d22` scopes
`capfd.disabled()` to these two helper invocations while child output remains
captured; full module runs 38870338830/38870343255 then exposed the phase costs
above. The dependency run completed successfully in 3m50s; a stale late monitor
alert led to a cancellation request after completion, which GitHub refused.
Cancelled core preflight runs 38869708922, 38870326329 and attempt 1 of
38871191644 supply no acceptance.

Final [core Checks 38871191644, attempt 2](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38871191644)
passed every required job/step at `9f62a4a5d9a532f661f835205a420f0fffa8fdc4`.
Job duration was **16m07s**. Host/common: **612 passed, 28 platform skips**, 171.02s
process wall, 41.15s user + 47.63s system. Vendor BusyBox: **639 passed, one
workstation-only skip**, 773.52s wall, 355.83s user + 347.17s system. Four optional
diagnostics were excluded per phase. This prescribed final gate does not establish
an overall speedup over the previous 13m52s run: host and BusyBox system CPU both
increased, and the installer call rose from 153.07s to 188.55s while retained
remained essentially flat at 110.52s versus 110.06s. Runtime bytes are unchanged;
these runs alone cannot attribute the timing difference to a specific cause.
Keep the 20-minute configured limit, visible phase measurements and bounded
focused selections; do not launch extra full runs solely to improve the timing
claim. The removed repeated launch and complete coverage are verified, while a
whole-group wall/CPU reduction remains unproved. Representative host/vendor
BusyBox proof does not establish live Merlin/ARM/router qualification.

## S02.01 modular distribution closure review

2026-10-16, baseline `a17a66d`: parent and independent Astra scope audit agreed
that S02.01 is the next smallest architecture/package closure. Existing status,
manager-settings and backup modules are real consumers. The approved requirement
does not add standalone bootstrap distribution or completion of later services
and hooks as prerequisites. S07.08 acquisition is reusable evidence; S04.09
generation and S02.07 native access remain supporting overlaps without new credit.

The installed interactive entry checked paths/ownership then sourced its menu
modules before complete package consistency admission. The new isolated real-entry
regression in `tests/test_entry_package.py` confirms this gap: a complete package
with regenerated fixture metadata reaches the real menu, while appending a
top-level sentinel to same-version `manager_settings.sh` without changing the
manifest still executes that sentinel and displays the menu. The normal control
passed in 0.59s; the corrupted-package rejection test failed at its intended
sentinel oracle. The fixture remaps owned paths/tool locations, preserves actual
entry logic and hashes adapted bytes before introducing the corruption. This is
host execution evidence, not live-router proof. Parent independently reproduced
the intact pass and intended failure in one 1.05s pytest run (1.55s process wall).

Parent and independent Astra design review agree on a two-stage native gate:
entry-owned bounded manifest parsing authenticates the entry and one fixed inert
verifier, then that verifier admits the entire installed package before existing
imports. The protected installed manifest is consistency authority; setup-state
contains only schema/version/completion. Fixed native hashing with a known vector,
capped reads and separate producer/hash status avoids Entware or a second general
supervisor. Compatible manifest 1/2 remains supported when the running entry's
required verifier is present. Package inventory excludes legitimate config/recovery
data; existing operational guards remain with their consumers. This addresses
accidental/incomplete mixed generations, not hostile root replacement or the
future self-update concurrency contract.

The implementation now places this gate before both installed import paths and
removes their superseded structural-only import checks. The installer requires
the newly mandatory verifier under either supported manifest header; acquisition
requires it under current schema 2. Parent and independent read-only runtime
review agree **PASS WITH NOTES**: no must-fix runtime issue was found; final
consumer and exact-candidate vendor BusyBox/core proof remains pending. The
review checked fixed loader ordering, strict bounded metadata/inventory, separate
reader/hash status and restoration of descriptors/terminal input. Existing
config/setup/recovery data remains outside package inventory admission.

Real entry fixtures now carry complete catalog/hash data after test adapters are
added. The unchanged original sentinel oracle passes, alongside verifier
corruption, metadata framing/incompleteness, retained-path refusal, legacy/current
headers and passive nested extension checks. Four first-run backup failures were
test adapters edited after metadata generation; correcting those fixture refresh
points restored all eight backup tests (46.06s), without weakening runtime
admission. The parent status/retained gate passed 48 tests with three Linux-only
skips in 49.44s, including aggregate inert imports and native menu return without
operational preparation. No acceptance is awarded before remaining gates.

Initial vendor Quick at `62ceee4` failed the intact control. A one-node traced
run at `56091bd` identified `CFMGR-READ 1 127` from the fixture's `dd` applet and
the empty-stream digest. Parent and independent reviewer confirmed the minimal
vendor build starts from `allnoconfig` and omitted `CONFIG_DD`, while the new test
adapter correctly selects vendor applets. The runtime refused the failed reader
as designed. Enable only `CONFIG_DD=y` in the existing representative fixture;
its content already participates in the verified cache key. No runtime change
or weakened assertion is needed. Superseded core runs were cancelled after
capturing the failure; final complete focused/core proof remains required.

With `dd` present, Quick at `13e6807` revealed valid digest/status lines in the
opposite order during a real 69 KiB bootstrap read. BusyBox may close the pipe
before its final redirected status print. Parent and independent reviewer agree
the correction is to require the same two uniquely typed records in either
order, retaining successful OpenSSL exit and reader status; other, missing or
duplicate records still fail closed. This is an observed portability repair,
not a relaxed hash/read contract. Final local entry/reinstall, settings/backup and
status/retained groups passed 151 tests with five Linux-only skips, each group
under 90s. At `1ed124bb5ad19c13b507af61e56f796b1c995118`,
[complete focused vendor proof 38865544386](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38865544386)
passed all 28 entry/package tests without skips in 3.12s pytest / 3.29s wall.
At the same exact SHA,
[core Checks 38865532262](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38865532262)
passed every required job/step: host **612 passed, 28 skipped** in 153.75s process
wall; vendor BusyBox **639 passed, 1 workstation-only skip** in 654.72s wall.
Four optional diagnostic cases were excluded per phase and are not claimed
passed. Total job duration was 13m52s; the focused package gate remains well below
the two-minute target. Parent verified the exact SHA, terminal conclusions and
raw logs, closing the earlier review's platform-proof condition. **S02.01 alone
is accepted**; no supporting overlap gains credit. Full local main-goal and live
Merlin/ARM/provider qualification remain separate gates. Final local commands,
timings and private receipt locations are recorded in the handoff.

## S07.08 acquisition and pre-execution design review

2026-10-16, baseline `167ef28`: parent and independent Astra design review agreed
**PASS WITH NOTES** for explicitly trusted complete bootstrap → pinned remote
snapshot → existing fresh installer. This implements the S07.08 consumer without
claiming standalone entry distribution, self-update or complete S07.06/S02.01.
The handoff owns implementation state, exclusive owners and pending gates.

The trusted bootstrap must remain separate from downloaded candidates. Resolve
one source pin; validate bounded manifest 2 metadata, complete inventory, native
SHA-256, embedded version, compatibility and syntax before candidate execution.
The existing installer runs only after validation, in its own subshell; pass the
canonical owned stage pathname because installer storage pinning replaces FD6/7.
Preserve the parent's staging pin and unresolved-child evidence. Provenance is
action-local and does not overwrite developer source-selection intent.

[GitHub's commit endpoint](https://docs.github.com/en/rest/commits/commits#get-a-commit)
supports a SHA-only media type. A read-only host request using that media type and
API version `2022-11-28` returned the exact baseline full SHA. This establishes
the response contract, not router transport qualification.

The [BusyBox 1.25.1 AWK source](https://raw.githubusercontent.com/mirror/busybox/1_25_1/editors/awk.c)
parses all `-f` inputs before BEGIN evaluation; its division-by-zero fatal path
bypasses END. A trusted first program can emit a parse receipt, flush it and
evaluate `1/(NR-NR)` to prevent candidate BEGIN/END execution. Parent and an
independent safety reviewer accepted this limited syntax-check design. Tiny host
probes suppressed both candidate markers, and malformed later code produced no
receipt. [Focused transport/syntax CI 38858125065](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858125065)
at `ffea9ebd59236045579b9250d383aa1c7acf1e09` then proved those same oracles
under actual vendor BusyBox: three tests passed in 2.22s, with no skips.
Ordinary `awk -f candidate` and a prefix using `exit` are unsafe alternatives.

Official [Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts) and
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
were consulted for the installer boundary. This package retains existing native
storage/publication admission and adds no new hook or firmware capability claim.

The integrated runtime received parent review and an independent read-only
**PASS WITH LIMITS** on the dirty baseline. Review corrections preserve a
nonzero interrupted result, keep FD0 pinned while reading records through FD4,
bound streams by declared file sizes, reject ambiguous SHA/text framing, and
permit only attached known-inventory RAM cleanup after owned children finish.
The immutable acquisition deadline is separate from the existing installer
budget. [Focused consumer CI 38858127676](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858127676)
at the same candidate passed all four cases in 144.26s: one pinned complete
acquisition reaches the real installer and retained guard, while incompatible
ABI, self-consistent syntax failure and wrong hash cannot execute candidate code
or begin installation. Exact required
[core Checks 38858115527](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38858115527)
then passed at the same SHA: 597 host tests and 624 vendor BusyBox tests, with
only expected platform skips and four excluded optional diagnostics per selection.
Parent verified every required job/step and reviewed measured cost. The full job
took 15m32s; the new focused installer group took 2m24s, within the practical
three-to-four-minute group range. This closes the pending platform proof for the
reviewed S07.08 consumer; it does not establish standalone distribution, updates,
live-router qualification or a complete main-goal audit.

## S14.02 destination foundation design review

2026-10-16, baseline `506e97f`: parent and dedicated read-only Astra reviewer
agreed **PASS WITH NOTES** for one backup feature module, policy-separated
storage helpers and the existing native configuration transaction. This is
design review; the implementation review below is separate from acceptance.

The backup action owns one bounded native context and private descriptor scope.
It records a typed destination, compares the selected transient attachment before
Save, creates/reuses only root `CFBackup` through the pinned mount, and verifies
the complete destination after config publication. The existing journal, lock,
raw-content freshness checks and JFFS recovery remain shared. Backup attachment
checks must be read-only and nonrecursive. After owned work is quiescent,
cleanup/recovery can proceed without the drive; no recovery operation recreates
a folder or replays a selection. Failed Save may leave an inert prepared folder,
whose contents are preserved. No cross-filesystem atomicity is claimed.

The accepted Entware policy requires executable ext storage and a GUID-shaped
UUID. Backup admission must separately accept `noexec` and valid filesystems
without POSIX modes. [BusyBox 1.25.1 UUID formatting](https://raw.githubusercontent.com/mirror/busybox/1_25_1/util-linux/volume_id/util.c)
uses shorter FAT/NTFS identifiers. The
[reviewed Merlin mount dispatch](https://raw.githubusercontent.com/RMerl/asuswrt-merlin.ng/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/rc/usb.c)
also uses driver aliases: a shared `ufsd` driver does not itself prove NTFS.
Positive identity/type evidence and explicit driver compatibility are required;
missing or ambiguous identity is unavailable, never a guessed substitute.
These are source findings, not live filesystem qualification.

The official [Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API),
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts) and
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
were consulted. The current destination operation introduces no hooks, firmware
config overrides or service changes. Firmware/live qualification stays deferred
to beta under the existing project boundary.

Required review conditions: preserve the S07.01 public Store API/receipts; typed
bounded destination parsing and complete readback; no stale-path writes; strict
bounded encoded receipts; one whole-action deadline; final-directory identity
checks; and truthful partial preparation/failure. Lean proof combines parser and
Store regressions, real Linux/BusyBox mount cases, and the menu selection/Save/
reopen journey at the required exact-candidate core gate. No new acceptance rule
or product scope was introduced.

Implementation review identified one additional ordering condition: the shared
writer lock must be held before folder creation or mode changes, so an unresolved
native folder mutator retains writer exclusion through the existing inherited
descriptor mechanism. Preparing the folder before acquiring the Store lock would
leave that overlap unguarded. Parent and an independent read-only analyst agreed
on the finding and the fixed ordering. The reviewed implementation prepares
the folder after lock/setup/pending admission, before both unchanged and changed
Save outcomes. Focused local tests verify admission and refusal; the additional
Linux case reuses the existing inherited-mutator fixture for folder operations.
The actual Linux inherited-child case subsequently passed in focused Quick
`38850933797`, then the complete final-candidate core gate recorded below.

The independent backend implementation review returned **PASS WITH NOTES** on
the dirty tree based on `506e97f`; parent agreed. It confirmed scoped destination
patching, complete identity checks, pinned folder mutation, inherited writer
exclusion, read-only status and drive-independent recovery. No backend blocker
remained. The review excluded the then-active menu additions. Host foundation
proof passed 69 cases with 14 platform/tool skips in 64.33s wall; two subsequent
list-framing cases passed in 1.58s. Real Linux/vendor BusyBox mount and inherited
child execution, final menu integration and exact-candidate core CI remained
required at this review; their completed outcomes are recorded below.

Final source/consumer and written-test review returned **PASS** after menu
integration. Failed discovery renders unknown/unavailable rather than an empty
list; successful receipts must match the requested action, destination, pending
state and record count. The installed-entry tests prove explicit single-drive
choice and confirmation before mutation, Save/reopen, duplicate labels,
cancellation/EOF/SIGINT, failed Save/recovery and malformed-output refusal.
Backend tests cover scoped persistence and drive loss; the separate Linux mount
and inherited-lock fixtures subsequently passed the exact-candidate gate.
Parent approved the package for publication and required core CI, with no
additional supporting-subgoal, archive/restore or live-filesystem credit.

The first core run at `2e94e2b` exposed a stale handwritten retained-launch
fixture: it used `backup:{}` while production defaults at the baseline already
included `destination`, `retention` and `last_backup` as null. Parent reproduced
the new typed parser's rejection of that fixture and acceptance with the actual
passive defaults. Independent review agreed with correcting only the fixture;
no parser requirement, runtime behavior or preservation assertion was weakened.
Focused real retained-launch Quick `38851883264` passed at replacement candidate
`f51894703cdf3366027d23c87dba12b9c18340c6`: 126.88s process wall, preserving all
repair/return/config assertions.

Subsequent independent review found a test-coverage gap: the installed-menu
fixture retained the production `/bin/sh` re-exec, so its successful menu paths
ran under the host system shell even in the vendor BusyBox group. Parent and
reviewer agreed on a fixture-only correction of the exact default-entry re-exec
to the selected, safely quoted interpreter, preserving isolation and host shell
arguments. The first local fixture guard caught a too-broad replacement needle;
it was narrowed to the default-entry token before publication. The existing
eight backup and three settings journeys are reused; no new matrix or runtime
change is required. Core run `38851879877` was deliberately cancelled after host
success; it supplies no completed core acceptance. Final fixture review passed;
all 11 affected journeys passed locally under selected Homebrew Bash `--posix`
in 51.43s wall, with no skips. Changed-file statics and planning/package/whitespace
checks passed. [Menu Quick 38852858797](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38852858797)
then passed all 11 journeys, no skips, with the selected vendor BusyBox shell
through internal re-exec at `f762dd731a7284a7a6377ffebb738209b9fd49a8`:
21.15s process wall, 38s whole job. Parent verified SHA and all applicable steps.
Final [core Checks 38852845631](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/38852845631)
passed at that same exact SHA: 588 host passes with 28 platform-specific skips;
615 vendor BusyBox passes with only the workstation-without-proc case skipped.
Each phase excluded four optional diagnostics. All required Linux mount and
inherited-lock cases executed. Every required job step passed; whole job 11m14s,
host process 73.44s and BusyBox process 585.68s. Parent verified the logs, SHA,
steps, exclusions and measured cost, and accepted S14.02's complete consumer
scope. The largest existing consumer cases were installer publication (181.81s)
and retained repair/return (126.05s); no new S14.02 focused group needed expansion.
No archive/restore or supporting-subgoal credit is implied. Actual firmware/ARM
and live filesystem qualification remain beta boundaries. The failed and
cancelled earlier runs remain failed/cancelled; this final complete pass closes
the required gate.

## Diagnostics fixture optimization review

2026-10-16, baseline `8e6b79f`: parent and dedicated read-only Astra reviewer
agreed **PASS WITH NOTES** on reusing the existing foreground view-operation
adapter for optional retry, thread and mixed-root cases. The unchanged repair
reference and fresh-installer consumer retain per-command native supervision.
The three layered cases continue to execute real mounts, worker/keeper/task
supervision, ownership/refusal/recovery and every existing assertion. They no
longer independently prove per-view-command deadline/unresolved-child accounting.
Production code, deadlines and the full installed-flock post-probe stay unchanged.

The reviewed implementation at `565e8dfa9af66fad2679052dd88cf40939a0abc0`
changes only the three fixture case selectors and their explanatory comment.
Separate Quick runs passed for threads (13.33s), mixed roots (10.67s), retry
(25.65s), and the unchanged full-supervision reference (82.17s). Earlier times
were about 87s, 88.15s, 165s and 87s respectively; the unchanged reference's
variation is not credited to the optimization. Mixed-root user+system CPU fell
from 78.47s to 8.37s. All assertions, including the distinct ownership/refusal
and fresh installed-flock checks, remain intact.

**Finding:** repeated per-view-operation supervision was the demonstrated main
cost in the three changed scenarios; no hang or new runtime failure was observed.
The fully supervised reference fits the two-minute group target and remains
unchanged. No further probe removal or broad redesign is justified by these
results. This changes the layering of optional S02.05/S02.08 evidence, not product
requirements or completion credit. Parent verified the final two-line fixture
diff, all four exact-candidate Quick passes and successful required core CI
`38843069635`. No new product acceptance was awarded. Exact receipts are recorded in the
[handoff](PLAN_V2_handoff.md#named-quick-results). The subsequent combined
Diagnostics run `38845454335` also passed all four cases at `19af505b13266cda55e8cb3dc9f7e0be5a63809b`:
164.90s process wall, 3m07s whole job. Its fully supervised repair call took
114.68s and each other case remained below 23s. This confirms combined completion
within the practical group budget; it does not imply constant runner timings.

## CI core integration cost review

2026-10-16; required core at `36199d6`, compared with `41e1765`; parent and read-only cost explorer.

The read-only cost review found no demonstrated cheap duplicate in the two largest
core cases. Installer integration performs actual repair/full probes/guard cleanup
and per-file supervised publication; retained integration already shares setup
across distinct repair, absent/returned storage, DNS outage and explicit force
paths. Cheaper adapted/component tests do not replace their actual integration
proof. A future bounded investigation can add fixture-only phase timings and use
those two named Quick nodes before changing anything. No runtime/test coverage
was cut for an unmeasured saving.

## S02.08 repair task-root review

2026-10-16; repaired runtime `1d892a4`; parent and independent ownership/source review; full grouped receipts remain in the handoff.

CI also exposed an existing process-disappearance race in the copy-signal test
observer and a concrete fatal-open path in native task-root inspection. The
observer now tolerates only expected gone-process errors while retaining its
identity/deadline/signal assertions. Task-root opening now returns to the existing
bounded complete-snapshot retry if a process disappears; FD4 and caller stdin
remain correctly handled. One deterministic regression failed before that fix.
The earlier loss-run log did not identify the exact vanished task, so attributing
that run to this fatal-open path remains an inference.

## Accepted subgoals audit

2026-10-16; nine accepted IDs at the audit boundary, with S02.08 reopened then repaired at `1d892a4`. Scope reviewers covered defaults/status/settings, repair/storage and foundations-first bookkeeping; parent verified the recorded remote gates. This is the historical audit receipt, not a fresh audit of the migration revision.

The audit inspected all nine previously accepted IDs and verified all 20 recorded
acceptance runs against their exact SHAs and required jobs. Eight existing ticks
were supported; the missing fresh-install report caused S02.08 to be reopened
and repaired here. The prior premature S16.02/S16.04 documentation work had
already been reversed; those IDs remain unchecked. No helper-only credit or
unearned main-goal/Goal 4 tick was added. The records support dependency-ready,
foundations-first cross-goal delivery, without claiming every past size estimate
was optimal.

## S07.01 native storage source review

2026-10-14; S07.01 design from baseline `fd1ea8a`; native-source exploration and parent verification. Runtime acceptance later used `5765848`.

Native storage design evidence was refreshed against retained source/provenance
and the official Merlin Addons API, User scripts and Custom config files guidance.
This package keeps the existing private add-on configuration; no firmware service
config, shared custom settings or hooks are added. All three retained image
inventories contain native flock/fsync and OpenSSL. Pinned 3004/3006 flock source
supports inherited numeric descriptors, nonblocking exclusion and contention
exit 1. Existing prerequisite tests exercise that interface. The retained fsync
source can print syscall failure on stderr while returning zero, so both status
and stderr remain mandatory checks. Retained mv can copy/remove after EXDEV;
the Save candidate and destination must remain on the same pinned filesystem.
JFFS2 can discard internal flash-flush errors as already documented in the plan;
cached readback does not prove reboot persistence. OpenSSL digest support is
not established by its existing CA parser admission: the new native digest mode
needs a known-vector check and strict bounded output framing before use. No
firmware image or router code was executed for this evidence refresh.

## S07.01 smallest-task scope review

2026-10-14; task-selection review before S07.01 implementation; existing product IDs and requirements unchanged.

The prior Astra scope audit confirmed this is the next smallest demonstrated full
subgoal. S03.08 still needs production history writers; S03.10 covers both status
and the absent full-health consumer. No independent shortcut is selected.

## S07.01 native store review findings

2026-10-14; draft findings and corrections at the exact blob IDs below. The recorded analyst result is preserved; final Linux receipts belong to the handoff.

Early read-only analyst review of the first native-store draft found premature
retired-journal cleanup and three branches that collapsed unresolved ownership
into ordinary failure. Parent verified and returned both for correction and
regression proof. The final runtime review confirms both corrected, and reviewed
Store/probe/supervisor blobs `8b95450`/`250401b`/`ae70b46` and launch `37aaed8`
without another runtime blocker. It required actual borrowed-observation lock
proof because earlier fixtures bypassed that helper. Added test blob `9064cf2`
closes that review finding: Linux executes the real helper/wrapper, FD5/8/9 and
mountinfo checks, native/admitted Entware flock branches, release and recovery
crossguard; the host contention test also uses the real helper. Analyst result
is PASS WITH NOTES: firmware roots/tool admission and the publication body are
adapted, so this is shared-lock integration proof, not router qualification.

## S07.01 BusyBox ash lock review

2026-10-14; diagnosis following `4b00501`, reviewed repair subsequently published at `5765848`. Worker assignments and pending-gate wording below describe that historical stage only.

Fresh retrieval of the exact CI baseline ash source at commit
`433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` matches retained source SHA-256
`28fcb7d7f9428e44bad4299bffdc7c30c8c83468c479305b60f0c690e57b7b09`.
It resets background FD0 to `/dev/null` before applying redirections and skips
the existing same-descriptor `0<&0` operation. Source evidence is retained at
`.tmp/s0701-ash-baseline.c`; it was not executed.

Parent and Astra audited the narrow fix (PASS WITH NOTES): call a tiny ordinary
launch function with scoped `9<&0`, then give its direct async child `0<&9 9<&-`.
The shell restores the parent's support FD9 when the function returns, before
identity/attachment checks. FD6/7 storage pins and FD8 snapshot behavior stay
intact; no helper consumes FD9. Handle bridge-call/redirection failure before
supervision. Strong now owns this fix in `prerequisites.sh` plus the Linux child
fixture's FD0/closed-FD9 assertions. The three real Linux cases remain the first
diagnostic gate, followed by complete A–F at the final candidate. No acceptance
or scope change follows merely from the source explanation.

## S03.07 smallest-task scope review

2026-10-14; all-157-row task-selection review from baseline `2e68bda`; completed status consumer evidence remains in the handoff/checklist.

The Astra smallest-task audit scanned all 157 rows and returned PASS WITH NOTES:
S03.07 is the smallest demonstrated ready full product outcome. Missing provider
writers do not block its read-only consumer; the plan permits absent evidence.

## S03.07 reader and native source review

2026-10-14; approved reader design, source explorer and parent verification; exact source pins below are retained.

Parent-approved reader design: project a bounded snapshot of existing private
config only; no new history file/writer. Optional `history.<feature>.status`
and `history.network.status` envelopes carry typed schema/generation/timestamps,
family outcomes, allowlisted reasons and at most five events. Family publication
records stay historical. A current runtime observation additionally needs explicit
runtime origin, matching boot/config generation and bounded nonfuture age;
restored/absent-origin evidence cannot establish current connectivity. Network
freshness also binds the selected WAN. Unknown/raw fields are never printed.

Native evidence: retained cache source/image facts were checked by
`status_native_evidence` (completed); parent additionally fetched pinned Merlin
revision `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` source into ignored
`.tmp/s0307-source/` and matched each Git blob SHA against GitHub's contents API:
`rtstate.c` (`5b7f52fa39e32e62bbe3cb1f6b4d0db123c8c213`),
`misc.c` (`6206ab19f1a958f26c25aea51d7377c8251f2ed5`) and
`df.c` (`d79c11a6c0efb9008d2bfd8f76b386c2d594ffae`).
`shared/rtstate.c:564` selects native primary via `wanN_primary`, not the
last-configured `wan_unit`; `:359` distinguishes PPP from ordinary interfaces.
`shared/misc.c:2346` reads that unit's `ipaddr`. BusyBox `coreutils/df.c`
supports `-Pk` independently of DF_FANCY; clear POSIXLY_CORRECT for KiB output.
Cached image inventory confirms `/bin/nvram`; pinned init uses
`firmver.buildno_extendno`, and original common code treats `ntp_ready=1` as ready.
These are source/static facts only, not live router or complete firmware proof.

## S02.04 DNS scope review

2026-10-14; independent scope review from `807aa1b`, final accepted runtime `e4adda5`; S06.03 remained outside this acceptance.

Scope refinement from the independent Astra review: configured tunnel (including
Off) makes DNS tools applicable, not tunnel launch eligible. Normal shared/safety
admission must distinguish DNS not-required/verified/deferred. Ordinary DNS
outages never reinstall healthy tools or block manager/DDNS/IP-Sync; strict
reinstall verification remains unchanged. Storage/ownership/supervisor failures
and stale-scope refusal remain fatal. A resolved DNS-only package failure may
defer only DNS after fresh shared-tool post-probes prove manager admission safe.
S06.03 still owns full tunnel launch/readiness, NTP and reachability integration.

## S02.04 DNS safety review

2026-10-14; scope and safety reviewers, with final required grouped evidence at `e4adda5` retained in the handoff.

`s0204_scope_audit` completed its read-only review.
`s0204_safety_review` independently reviewed the DNS-only repair-failure exception
and post-repair cleanup. Its resolved-migration cleanup finding and real-worker
failure-origin assertion are fixed; the focused follow-up passed. No edits or
acceptance authority were delegated to reviewers.

## S02.04 failure-handling review

2026-10-14; three design corrections accepted before final `e4adda5` verification; no requirement change.

The Astra audit required revising the initial failure handling; its three
findings are incorporated into the worker contract: separate shared/DNS outcomes,
separate configured scope from effective inventory scope when native DNS is
unknown, and preserve fatal supervision/storage/stale-scope failures. It confirmed
that the real normal retained consumer can close S02.04 without Goal 6 lifecycle.
No requirement or acceptance gate changed.

## Instruction maintenance review

2026-10-14; instruction-only tree based on `edcb8cd`, published as `807aa1b`; the authorization and checks remain in the handoff.

Astra Max's read-only audit passed with one procedural
note: retain CFMgr's disjoint Quick Checks groups. That wording is retained;
parent review confirms the removed procedure is covered by available skill text.

## S02.06 smallest-task scope review

2026-10-14; corrected documentation-readiness boundary; user selected S02.06 if no smaller independent complete outcome was ready.

Parent
and Astra Max reviewed the remaining IDs and found no qualifying smaller complete
runtime task.

## S02.06 native DNS source review

2026-10-14; selected reinstall design and parser evidence; final runtime `03a4f01`.

DNS refinement supersedes the earlier no-host proposal in the private snapshot:
usage with no hostname is ambiguous. Complete fixed SRV invocations using the
supported `-q`, `--type=` and `-type=` grammars distinguish known option/type
rejection from accepted-query failure. All three pinned ordinary implementations
reject leading options before resolver work; pinned LEDE explicitly rejects SRV.
The positive parser follows [BusyBox 1.36.1's SRV/A formatting](https://github.com/mirror/busybox/blob/1_36_1/networking/nslookup.c#L370),
excluding server-address preambles and not requiring a non-authoritative marker.
This defines a supported parser interface, not another firmware-support claim.

## S02.06 runtime interface review

2026-10-14; parent/static review of callback discovery and fresh selected-tool probes, final candidate `03a4f01`.

Parent/static review
resolved the BusyBox callback-discovery issue (`type`, because the pinned ash
omits `command -v`) and verifies fresh post-probes for every selected optional
Entware tool even if a native provider changes during the action.

## S02.06 storage-loss report review

2026-10-14; finding on candidate `fd91e89` after failed run `38441702494`; parent and independent analyst reviewed correction, final required gates passed at `03a4f01`.

Source review
found that an exceptional task return can reach resolved controller cleanup
without the final attachment observation performed on the normal task path.
The correction adds a final observation/report after resolved task cleanup;
unresolved native children, task cleanup or event reporting retain guards without
proceeding to release. The new controller regression reuses the existing adapter
and actual repair/event bodies: old source reproduces missing loss reporting;
five scenarios cover lost/attached completion and unresolved task/native/event
states. Parent and independent analyst reviewed the eight-line runtime change
and test assertions. The shared adapter now explicitly supplies its attached
storage assumption; the real detach assertion remains intact and gains bounded
failure labels.

## Documentation readiness review

2026-10-14; S16.02–S16.05 timing correction following the explicit user decision. Original reset authorization, verified recovery inventory and consumed rewrite permission remain in the handoff.

Astra Max's focused audit passed with notes; the replacement resolves its
conflicting-timing, S16.02–S16.05 consistency and essential-current-guidance notes.

## S02.06 earlier design findings

2026-10-14; preimplementation findings preserved after the documentation reset. Later S02.06 acceptance supersedes the historical unimplemented status below.

S02.06 was unimplemented at that pause. Its read-only design findings remain in the
private snapshot's handoff and safety history: configured-tunnel-only DNS scope,
truthful coalesced-repair deferral and capability-versus-outage classification
need implementation before a genuine reinstall action can pass its focused gates.
Pinned native nslookup source inspection found no SRV support in either variant;
source evidence is not live capability proof. No runtime attempt was discarded.

## Retained execution and storage source review

Historical shared-repair foundation review for S02.05/S02.08. Exact source pins and platform limits are below; earlier acceptance and recovery receipts remain in the handoff. References to a receipt above mean those historical handoff receipts, not this migration.

The private descriptor-bound view and fallback guards are integrated with normal
opkg repair; acceptance is established by the exact full CI receipt above. Do not assume router cgroups/namespaces
or a new resident daemon; Linux test namespaces only isolate fixtures. Polling
`/opt` alone cannot prevent stale-path writes.

Preserve ordinary installed opkg feeds/dependency resolution/scripts, including
configured local-feed/temp/cache paths and existing unpacked packages. A minimal
view omitting host paths or making all `/tmp` read-only changes that behavior.
Opkg invokes `wget` through PATH; curl admission alone does not qualify transport.
Account for native `/etc`→`/tmp` symlinks, devices/procfs and service IPC. Normal
`dest root /` is valid; Entware patches free-space checks to `/opt`.

The implemented writer supervisor tracks direct PID/start/boot before release and rooted tasks across threads/daemonization;
close outside directory descriptors/cwd. The view hides its controller context, so
handshake needs narrowly admitted FIFO descriptors closed before opkg exec.

**Mount IDs can be reused after final reference release.** Pin every ownership
mount; the unique root alone does not retain detached child binds. Source-reviewed
candidate: one native ash child holds directory references in active recursive
function-redirection frames. ACK only after each open; verify its PID/start/boot
and complete held fdinfo mount-ID set before overmounting. Reserve FD/stack headroom;
EOF, unwind, keeper loss or missing pins closes ownership admission. Release pins
only after quiescence, then never signal from that retired ledger. This ash/Linux contract is implemented and exercised by the keeper and repair fixtures.
Pinned `shell/ash.c` SHA256 `28fcb7d7f9428e44bad4299bffdc7c30c8c83468c479305b60f0c690e57b7b09`
matches cached provenance: `openredirect`, `REDIR_PUSH`, `evalfun`, `popredir`.

Script-created mounts/chroots can escape a static inventory; resolve dynamic or
unknown ownership before launch. Positively identify kernel threads by PF_KTHREAD;
retry transient exits within deadline, never infer live unreadable roots are foreign.
Kernel evidence: Linux v4.1 `fs/namespace.c`, `fs/proc/{base,fd}.c`,
`include/linux/{fs_struct,sched}.h`, `kernel/exit.c`.

Parent-verified ownership refinements: classify pinned non-view mount roots too
(existing Entware chroots need not remain unknown). Transfer an already-open root
FD to the keeper while verifying/pinning visible owned ancestry; never reopen the
pathname. Numeric `kill` affects the threadgroup: require all live threads owned
or separately verified group provenance; mixed/unknown groups remain uncertain.
Boot/start/root rechecks are observational, not atomic signal identity: Linux
4.1.51 `kernel/{pid,signal}.c` allows PID reuse despite proc/root FDs; pinned ash
`dowait` also reaps before builtins/functions. Do not claim delayed shell `wait`
reserves a PID. Empty sweeps still require successful normal unmount for cleanup.

Persistent package-script daemons count as continuing owned work, not direct-exit
success. Bounded cancellation can make repair fail even after opkg exit zero; do not
claim normal service-success compatibility without review. Unknown ownership or
busy normal unmount retains evidence and prevents overlap; never lazy cleanup.
Later recovery requires proved quiescence; a completed ordinary failure must not
permanently latch. External host services requested through IPC are not inherited
owned children. Required representative repair/cancellation proof is part of the current full CI gate.

Concrete Merlin hotplug finding: at pinned firmware source below,
`rc/usb.c` unmounts the device from **all** matching mounts, including private bind
clones. `shared/usb.c:300–328` matches `/proc/mounts` by source or device identity.
Changing source spelling/propagation does not hide the clones. Physical removal
can use `MNT_DETACH`, exposing writable fallback directories before any poll.

A read-only root protects bare `/opt`; canonical volume aliases under mirrored
writable `/tmp` additionally need verified read-only underlays. Guard stacks require
an explicit ledger/inventory mode; do not weaken legacy parser rejection blindly.
Mark the unique root unbindable before recursive ancestor binds to avoid copying
itself; preserve a separate bindable guard source. Do not later clear unbindable
with recursive-private. Ordinary device detach can leave the RO underlay in place,
but `rc/usb.c:1797–1849` calls the user hook then retries path-based unmounts without
revalidating top-device identity: another actor removing the leaf can expose the
guard to a later attempt. Parent verified the pinned hotplug source and accepts the revised construction for
ordinary hotplug. Scope remains the action’s verified owned children: host services
asked to act through IPC are not owned children, and independent root dismantling
of guards is not prevented. CFMgr itself must never remove a busy leaf while writers
survive. These are evidence limits, not restrictions on normal feeds/scripts. Actual
construction/failure/cleanup has representative Linux proof; the integrated writer
consumer is included in the current required CI gate.

Source pins and evidence for that decision:

- Merlin `433fc608f5fc1689f3d3c3ab5cd2a7d57102260f` (3004.388.12_2),
  `release/src/router/{rc,shared}/usb.c`. Cached GT-AX11000 embedded kernel config
  SHA256 `b9795f074b019c327b1ea6fe7d29d46f6e716a9d017a8235c648e10c30cf323a`:
  cgroups/namespaces disabled. Native BusyBox 1.25.1, kernel 4.1.51,
  Entware aarch64-k3.10; native id/stat/timeout/setsid absent.
- Reverified native `mount.c` SHA256
  `b6a23a99f6564b332ad5f7ae418b5ffaa1c6afe424eac9a5cf2620ada8144803` under
  `.tmp/firmware-audit/sources/3004.388.12_2/util-linux/`: explicit bind operands
  reach syscall unchanged; pinned `get_devname.c` rewrites only UUID=/LABEL=.
  Descriptor binding has representative vendor-BusyBox/Linux proof, not firmware/router execution.
- Entware root `36db8558ac7840d993cb11df1e47e0326d681077`; opkg source
  `80503d94e356476250adaf1f669ee955ec26de76`. Root feed references are unpinned;
  supplemental recipes `entware-packages/b6a6f2962f62882b76dfe45f9f9e1238cd9b74fd`
  and `rtndev/05d2b0f695b8bc1973a9c88a8f08764c8fcb8271` do not prove installed IPKs.
  Selected recipe simplicity does not constrain all existing unpacked scripts.
