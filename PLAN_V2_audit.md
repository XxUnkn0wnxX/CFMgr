# CFMgr v2 — audit record

[Specification](PLAN_V2.md) · [Checklist](PLAN_V2_checklist.md) · [Current handoff](PLAN_V2_handoff.md) · [Review notes](PLAN_V2_review_notes.md) · [Working rules](AGENTS.md)

This record owns substantive audit findings, their evidence, recorded review
agreement or user decisions, and repair dispositions linked to existing subgoals.
The checklist remains authoritative for acceptance; the handoff owns current work,
permissions, jobs, next actions and session lineage. Deferred risks remain in the
review notes. This record creates no requirements, product credit or permissions.

## S03.09 and S03.10 health entry and provider evidence

Initial source review at `43a81f1` confirms that normal entry admission verifies
the complete package before importing Status. Its required payload inventory
includes Backup and Manager, so the existing path cannot meet degraded health
reporting. The current Status controller also requires its worker/config/storage
dependencies, private RAM, native process identity and working supervision; it
is not a standalone fallback. Its tolerant configuration projection may display
independent valid sections but cannot authorize authenticated reads.

The parent and read-only source explorer agree that the existing Status owner,
network library and fixed worker/execution dispatch are the appropriate surfaces.
`cfmgr_native_check` includes installation mutation probes and is unsuitable for
health admission. The existing TLS-only acquisition admission is reusable only
with independent controller/tool admission. Expanded reporting must account for
the current ten-second Status budget, two receipt files per operation and
96-file cleanup ceiling; these are implementation constraints, not permission to
discard required checks or unresolved ownership evidence.

Primary Cloudflare API documentation was checked on 2026-10-21. Configured-resource
GETs provide a supported narrow diagnostic surface:

- [Zone details](https://developers.cloudflare.com/api/resources/zones/methods/get/)
  and [DNS record listing](https://developers.cloudflare.com/api/resources/dns/subresources/records/methods/list/)
  can establish matching resource/read evidence. Saved DDNS record labels are
  local IDs, not proved provider record IDs; use exact name/type filtering and
  admit pagination before claiming absence.
- [List metadata](https://developers.cloudflare.com/api/resources/rules/subresources/lists/methods/get/)
  and [list items](https://developers.cloudflare.com/api/resources/rules/subresources/lists/subresources/items/methods/list/)
  have different documented accepted permissions. Item search is prefix-based,
  so local exact comparison and complete pagination are necessary for absence.
- [Tunnel details](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/methods/get/)
  establish management evidence only. The dedicated
  [connections endpoint](https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/subresources/connections/methods/get/)
  replaces reliance on deprecated embedded connections, but remote observations
  alone cannot authenticate this router. Secret-returning tunnel-token GETs are
  outside diagnostics.
- [Token formats](https://developers.cloudflare.com/fundamentals/api/get-started/token-formats/)
  include current user/account prefixes and legacy values. The existing registry
  does not store token ownership type, so a generic user-token verification call
  cannot safely classify every configured token. Resource reads avoid that guess.
- [Rate limits](https://developers.cloudflare.com/fundamentals/api/reference/limits/)
  require deferred handling of throttling. HTTP 403 can indicate missing resource
  permission; it does not by itself prove a globally invalid secret. No raw
  provider error, token, account ID or response body belongs in the report.

Independent Astra design audit returned **REVISE** for the complete authenticated
design, while allowing the corrected native fallback and fixed-closure foundation
to proceed. Parent agrees with these findings and dispositions:

- Both pinned release source configurations disable ash builtin test, printf and
  echo. The reviewer verified config/source hashes against retained provenance.
  The fallback uses the existing fixed native `/usr/bin/printf` substrate; it is
  not described as shell-builtins-only. Native fallback/admission has finite
  input/step bounds, while later verified supervision provides action deadlines.
- Standalone-to-installed compatibility requires the invoked trusted entry's
  bytes to match the protected manifest's entry record, even if the installed
  entry is absent. The unchanged development version alone is insufficient.
  Verify the fixed reporting closure and complete ancestry, including helpers,
  from one admitted manifest view. Ordinary launch retains full-package checks.
- Tolerant public diagnostics and strict private request descriptions are
  separate products of the bounded config snapshot. Schema-1 visibility does not
  confer typed credential authority. Historical auth/throttle observations are
  not an implemented persistent fault/cooldown controller; conservative holds
  must be described honestly without inventing or mutating operational state.
- The full report needs explicit operation/body/context/file/row limits and one
  aggregate deadline. Budget exhaustion preserves collected results and names
  omitted checks. Unresolved ownership prevents further work and broad cleanup.
- Since native printf is external, even writing a token with shell printf leaks
  it through argv. An admitted parser must serialize credentials directly from
  private input to owned private output. Disable tracing/core dumps, sanitize
  child environments and never expose raw response/error data. Fixed GET/TLS
  policy, no redirects and real response limits remain required.
- Cloudflared selected-file semantics already have a Backup parser owner. Reuse
  a verified optional dependency where appropriate; reference/schema checks alone
  cannot establish selected file integrity or runtime authentication.

The native entry/closure foundation is released with these corrections.
Independent implementation review returned **PASS WITH NOTES**, finding no
material trust/admission or ordinary-launch regression. The remaining foundation
proof note is an actual standalone health invocation with the installed entry
absent; extracted admission coverage is not equivalent.

The revised private transport design received independent Astra **PASS WITH
NOTES**. Parent accepted its strict parser reuse, direct private AWK request
serialization, fixed request grammar, explicit historical hold fields and
report-local provider/shared-transport stop rules. Pre-spawn monotonic reservations
bound retained file payloads to 8 MiB and 384 files, alongside the operation,
request, response, row and aggregate deadline limits recorded in the handoff.
These were checked initial design limits, not measured implementation results.
The actual ten-stage authenticated request path exposed insufficient operation
headroom for the other required groups. Parent and a further Astra audit agree
on 256 operations, 576 files and 12 MiB retained payloads, reserving eight
operations/sixteen files/1 MiB for finalization. Twelve request paths consume
120 operations, 264 files and 4,915,200 reserved bytes; the source-based example
with remaining ordinary operations, eight snapshot exceptions and final rendering
totals 9.6875 MiB. Actual representative collector completion remains unproved.

Independent transport source review found no additional material private-request,
fixed-GET, reservation-before-spawn or unresolved-child handling defect. Parent
review identified response semantics requiring cursor pagination for list items,
typed IP/CIDR values and DNS content/proxy/TTL validation. The five-event display
limit cannot become an eligibility scan limit: absent latest, all events in the
bounded validated configuration inform conservative historical holds. Parent
accepted that correction to the implementation draft and explicit default-deny
current NTP admission. These findings establish neither live-provider proof nor
product acceptance.

The first full-core integration review returned **REVISE** for three concrete
consumer defects: initial prerequisite attachment still referenced a bootstrap
callback not imported by health; a successful zone read could leave public-trace
eligibility after a later same-scope authentication rejection; and strict native
path equality rejected the normal BusyBox flock link. Parent agrees with these
findings. Repairs dispatch the initial attachment to the health context and pinned
Entware observation, retain and recheck bounded candidate scopes against current
report-local holds, and admit only the known native flock link after protected
parent/target checks. Provider DNS record family is separate from the transport
family, and public rows must display the typed refreshed egress address without
claiming selected-WAN routing proof. A read-only independent repair review returned
**PASS** for all three corrections and the additional single-complete-line
canonical-path gate. The focused core selection passed 27 cases with one
Linux-only skip; its sole old basic-entry fixture failure was repaired by quoting
fixed Package path operands. That entry node then passed all three basic,
installed-health and standalone-health cases in 9.95s (10.70s wall). The new
canonical-path case passed in 0.34s. These are dirty `43a81f1` host results;
Linux integration and exact-candidate complete core validation remain pending.

Cached representative coverage inventories for GT-AX11000, RT-AX88U_PRO and
RT-BE96U all record `/usr/bin/flock` resolving to `/bin/busybox`; curl, OpenSSL
and the fixed ROM CA path are regular files without link chains. Each coverage
report hash was checked against its corresponding provenance receipt. This
establishes cached-report integrity only, not a fresh image rehash or live-router
qualification. Raw provenance remains in ignored local evidence.

The independent budget review found an arithmetic error in the owner's initial
235-operation total: its subtotals (52 dashboard/inventory, 30 native/TLS,
53 Entware/prerequisites and 120 GET stages) sum to **255**, already seven above
the 248-operation collection allowance before remaining groups. The earlier
headroom example is therefore insufficient integration evidence. Parent
has requested a concrete consolidation/batching review before advanced collectors
are implemented. Required checks and the existing caps remain intact pending
that review; no missing group is accepted through a placeholder or narrow pass.

Astra's completed capacity review returned **REVISE** for the earlier capacity
assumption and **PASS WITH NOTES** for a bounded consolidation: batch fixed native
and Entware metadata receipts while retaining canonical paths, per-member results,
attachment and actual capability checks; parse only trusted bounded `ls` snapshot
metadata in the controller. The source-derived saving is forty operations,
reducing the corrected core estimate to 215. Exact path matching, spaces,
reordered listings, partial missing members and before/after snapshot identity
remain mandatory. No config, credential or provider parsing moves into shell.

A second source-count check confirms the forty-operation saving with corrected
disjoint labels: **52 dashboard + 30 combined native admission + 7 TLS +
46 remaining Entware + 120 GET = 255**. Native admission includes the later
flock path: four canonical reads plus 26 metadata/parser operations become the
same four canonical reads and one metadata/validator pair, saving 24. Entware's
fourteen separate metadata/parser operations become one pair, saving twelve;
the two snapshots save four receipt-parser operations. The resulting healthy
twelve-request path is **48 + 6 + 7 + 34 + 120 = 215**. Thirteen native operands
cover the verified BusyBox-flock branch; a regular flock needs its corresponding
endpoint or independent union handling. Missing flock must not invalidate TLS.
Extra ancestry and failed-native-to-Entware flock fallback have separate costs;
215 is a normal maximum-target path estimate, not a universal worst-case bound.

The remaining diagnostic groups are provisionally 80–120 additional operations.
Parent accepts **352 total operations / 768 files / 12 MiB** as a conditional
implementation design candidate, not a changed product requirement or proof.
The final ledger must account for every named snapshot, real process/cron stage,
include fragment, digest and parser before freezing the revised limits. Preserve
eight operations/sixteen files/one MiB for finalization and the 45-second overall
supervision/40-second collection envelope. Slow remote requests may still yield
an explicitly incomplete report. Perform Entware-dependent observations before
releasing descriptor pins 6/7 for provider transport. Inspect package completeness
after admission with fixed current members/directories; do not run the recursive
unsupervised package verifier. None of these changes is implemented or accepted
by this review; the current interim CI checkpoint precedes their implementation.

The shared terminal integration required a separate basic finalization allowance:
otherwise collection-budget exhaustion suppressed the entire staged page. Basic
collection remains ten seconds, with three final probes within an immutable
three-second allowance capped at collection start plus thirteen seconds. Health
rendering retains its reserved envelope and uses an immutable deadline no later
than `min(now + 5, original deadline)`, with two-second individual probe limits.
Direct and supervised collection reservations both reject attempts after the
finalization phase begins. Unresolved ownership retains staging/identity and
does not launch the renderer. Basic staging has a physical soft file limit and
core dumps disabled. Invalid rendering input returns failure; the controller
prints only a fixed safe fallback. The maximum case now uses 96 unique 64-byte
group names at width ten. Parent consumer/entry integration passed six focused
host cases in 11.37s; all exact-candidate Linux/core proof is still pending.

Additional source mapping narrows the advanced estimate to roughly 100–114
operations, **plus** 7–10 for package completeness; these are conditional design
counts, not measurements. Current per-file snapshots/hex packing would cost
roughly 188 operations before additional admission. Achieving the smaller count
requires fixed before/after metadata and byte-count batches, separately bounded
reads, and one private logging bundle packer. Preserve three cron boundary
observations, repeated account/read/hash evidence and actual process identity;
nine logging input names are not nine operations. Twelve generic snapshot pairs
alone reserve 3 MiB, so smaller fixed writer tiers and an explicit combined byte
ledger are required before adopting the conditional capacity revision. The
existing 8-KiB Scribe-prefix policy is retained; public protected files do not
inherit the private configuration's `0600` policy.

The explicit physical ledger identifies another conditional boundary: the
consolidated 215-operation core with twelve GETs reserves **7,315,456 bytes**
for collection, leaving **4,218,880 bytes** below its eleven-MiB allowance.
A 114-operation advanced small-file profile nearly fills that remainder before
the required private PEM handoff and package checks; preserving larger legitimate
selected files exceeds it. Small file examples are not new input-validity limits.
Parent has requested independent review of smaller fixed quotas for genuinely
tiny success receipts, preserving full private-data/parser output funding and
explicit budget-incomplete behavior. Actual combined stage/byte measurement
still precedes any revised resource ceiling or acceptance claim.

Astra's final audit returned **PASS WITH NOTES** for consolidation plus an
explicit two-block allowlist, accepted by the parent. Proven tiny outputs include
fixed scope/response/trace receipts, silent validators, counts, date/native
resources and fixed capability probes. Raw paths, metadata, inventory, tool
versions and data-bearing parsers retain separately funded larger tiers. A
schema-valid credential reference can exceed the health request's 64-character
limit; the ineligible scope producer must clear its unused scope/resource/name/
type fields, retaining eligibility reason/feature/kind, before its quota shrinks.
This is a bounded-output repair, not a schema restriction or eligibility change.

The eight tiny stages per successful GET alone save **1,179,648 bytes** across
twelve reads. Applying this to the consolidated core estimate leaves
**5,398,528 collection bytes** before other proven tiny-mode savings. This still
does not prove advanced fit: a 262,144-byte YAML metadata budget needs its full
1,048,576-byte physical output pair; 64-KiB hex input expands to 196,608 bytes;
PEM extraction/decoding and logging bundles need their own enforced writer
quotas. Parent retains all current caps while the actual collector is built and
counted. Small-file tiers are performance choices, never new validity limits.
Any later bounded capacity revision must follow a complete measured reservation
ledger rather than removal of required diagnostics or a speculative RAM increase.

Implementation review refines the forty-operation estimate: pre-admitting the
Entware flock fallback plus re-canonicalizing selected logical tools immediately
before execution can retain approximately **220** operations instead of 215.
Parent explicitly preserves original argv[0], immediate canonical identity and
attachment checks; the estimated saving is not a reason to weaken admission.
Actual counters after integration supersede these source estimates.

The fixed package-completeness design reuses the eleven entry-admitted records,
then inspects the three empty placeholders, four known directories, manifest/
catalog correspondence and bounded flat inventories. The catalog has thirteen
physical lines: its header plus twelve module records. Bind new manifest data
to the original admitted records; do not retrospectively authorize earlier
verification from a later manifest. A standalone invocation additionally needs
independent installed-entry presence/protection/digest evidence. Valid listed
passive extension directories remain uninspected extension scope, not malformed
or fully verified; unlisted objects fail inventory. Reused entry hashes plus
later metadata are explicitly non-atomic observations. These are design findings,
not completed runtime or acceptance evidence.

The remaining per-family provider comparisons need no additional GETs. Retain
bounded private canonical DNS/list values and compare them after the existing
late-auth-hold check and same-report public-family observations. Exact DNS
equality and CIDR membership require a small POSIX-AWK canonical comparison;
the existing IPv6 validator does not normalize addresses. A partial list may
prove observed presence, never absence; partial DNS enumeration remains
incomplete. Missing current public evidence must not be replaced by historical
addresses. The result describes observed egress during the report, never selected
WAN routing, write permission, prior publication or tunnel runtime authentication.

Astra's selected-Cloudflared design is **PASS WITH NOTES**, accepted by the
parent. Reuse only pure Backup YAML/runtime-JSON/PEM readers beneath the Status
consumer. Three projections come from the same fully validated retained config:
a path/policy-only plan, the unchanged private `CFMGR-AUTH` runtime record and
an independent `CFMGR-CERT-ACCOUNT 1 <account-hex> END` certificate record. The
certificate authority is valid in token mode too; it never becomes a token-runtime
prerequisite. Two narrow Backup adaptations are justified: a private account-file
reader and a fixed health-only raw-base64 PEM output, retaining both archive
defaults. This avoids the existing high-level decoder's secret-bearing shell
variable and an unnecessary extraction stage.

Selected-file collection uses protected before/after metadata, pinned bounded
copies, native byte counts and independent per-member results. JSON/certificate
parser boundaries remain 65,536 bytes; larger YAML inputs need checked physical
reservations or diagnostic-budget UNKNOWN, not a new validity limit. Reuse a
single semantic parse when live/recovery certificates both match the saved hash.
Local evidence depends on its own prerequisites, not NTP/curl/provider gates.
JFFS recovery metadata can remain useful when Entware is unavailable.

Binary integrity uses the approved binary-specific pinned native SHA-256 read,
not a retained binary snapshot: ordinary binaries can exceed the whole report's
RAM payload allowance. The child verifies a regular nonsymlink source matches
its pinned descriptor, then directly executes the fixed native digest tool under
the remaining supervisor deadline. Controller before/after metadata compares
exact inode/extent/protection and canonical attachment; a complete fixed receipt
must match the saved digest. This avoids an unsupervised extra stat subprocess.
Metadata-only referenced inputs need no copy; any recorded content comparison
can use the same bounded pinned read. Files actually parsed retain their finite
snapshot contract. None of these observations guarantees atomicity against a
privileged replacement or same-inode rewrite, and no binary is executed.

The borrowed YAML parser proves supported identity/dependency structure, not full
ingress/private-network runtime semantics. Its smaller supported pathname subset
must not redefine the schema's 4,096-byte paths. Missing ownership is unproved;
a matched owned digest is content evidence, not ABI/version/connectivity proof.
Recorded maintenance/watchdog/readiness preferences do not prove running jobs.
The illustrative Cloud ledger is 34 stages before additional canonicalization,
ancestry and referenced inputs; every real producer and output tier still needs
counting in the combined report. No Cloud collector implementation or acceptance
is claimed by this design review.

The selected-file implementation's adapted real-worker fixture subsequently
passed: **one case in 14.26s**, covering selected advanced YAML/runtime JSON,
owned referenced-input hashing, live/recovery certificate parse-once, nonexecuted
binary integrity, a changed owned input and token mode without certificates.
Parent review required complete plan/join frames before reads, health-only typed
semantic mismatches after all fields validate, independent certificate SKIPs and
UNKNOWN for failed/budget-incomplete workers. The read-only analyst reviewed the
settled repairs and returned **PASS**. Exact authority byte counts and private
AWK/file transport preserve the secret boundary. Final source-only guards reject
selected aliases/symlinks and withhold semantic PASS when an expected digest
cannot be checked; native/complete-module proof remains pending for this delta.

The fixture measured **72 operations / 144 output files / 4,810,752 reserved
physical bytes**, not actual retained bytes. Its host paths omit production
`/opt` attachment calls: the planner identified three extra mount observations
per such member, or fifteen additional operations for the representative five
members. These are bounded implementation observations, not a complete report
fit claim. Before/after ancestry and attachment must be retained when reducing
duplicated work. The earlier 34-stage illustration and 352-operation conditional
candidate cannot substitute for the actual combined ledger.

The follow-up aggregate audit returned **REVISE** for the old fit assumption.
Its current conditional estimate is 403–418 collection operations before useful
consolidation, including production attachment calls. It recommends retaining
45 seconds, twelve GETs, 96 rows and 12 MiB while reconciling count/file limits
against actual consumers; 416 total operations/896 files is an implementation
candidate, not measured acceptance. The parent agrees that final proof requires
all normal groups with production-shaped attachments and real supervision in CI.

Concrete source-bounded reductions preserve admission: selected LS output can
reserve `sum(path bytes + 256)` for its at-most-thirteen fixed operands; serialized
YAML output can use `min(262144, 4 * source bytes + 256)` while retaining the
parser's 262144-byte internal metadata budget; the YAML join can use
`min(262144, 8 * counted receipt bytes + 1024)`. Native byte counts and complete
frames still gate every consumer. Lookahead currently overcharges runtime JSON
for a nonexistent hex stage and retains fixed oversized metadata reservations;
derive it from the same mode quotas as actual work. Combining native counts of
the HTTP receipt/body/headers can remove one fixed-frame process per successful
GET, while preserving auth/throttle classification before payload-size rejection.
Sharing primary-file before/after phases can save additional stages but is a
larger sequencing change; the parent will assess its necessity after the small
repairs and actual remaining collectors, without weakening independent members.

The source-sized Cloud quotas and branch-specific lookahead are now implemented;
the adapted actual-worker journey passed in 6.69s (6.57s call), retaining advanced
identity/input checks, changed-owned-input failure and token mode without a
certificate. This is host proof at the dirty candidate, not a production `/opt`
ledger. The retained-address comparison now has 31 focused passing cases across
two selections (1.89s and 0.71s), including complete/partial DNS, duplicate exact
records, IPv4/IPv6 CIDR residual-bit boundaries, malformed full receipts and
missing current families. Completed reads remain report-local evidence after a
later scope hold; they do not authorize another request or claim current auth.

The logging design review returned **PASS WITH NOTES** for a Status-owned thin
collector and rejected the earlier approximately 74-operation estimate. The
parent agrees with its source-backed boundaries: reuse pure `backup_history`
policy/base/assess and raw bundle modes, but do not call the archive controller
or its process-text environment handoff. Preserve before/after content digests
as well as metadata for logging files, all three cron boundaries and two reads,
and process executable/inode/start-time rechecks. A shared private process index
must carry receipt names and safe identity only; raw argv stays inside private
files. Share those cron/process observations with hooks rather than re-observe.

For four base inputs, five fragments, three requested policies and two relevant
processes, the reviewed conditional design estimates 136 logging stages: 2
authority, 8 native/tool/link admission, 62 selected-file/shared-metadata, 5
grouped digest, 12 version/syntax/debug, 2 include admission, 20 cron, 18 process,
and 7 bundle/assessment. Extra path batches, candidates or fragments consume the
same finite budget. This estimate supersedes the earlier fit assumption and does
not validate the 416-operation candidate. Exact native grouped-count/hash output
framing and a combined normal supervised CI journey remain required before
freezing final implementation limits. The 45-second, 12-GET, 96-row and 12-MiB
boundaries remain unchanged; no acceptance or product requirement is relaxed.

The HTTP consolidation now counts the status/body/header files in one fixed
native worker. Exact owned names, three measurements plus total, complete EOF,
numeric bounds and a four-byte status receipt precede the shell's three-digit
HTTP check. Body/header limits remain separate so valid authentication rejection
and throttling still establish their holds when payload limits fail. The prior
HTTP AWK subprocess is removed; response grammar checks remain. Malformed count
or HTTP evidence is unverified, never a new auth claim. Parent's final focused
selection passed 18 cases in 1.17s, including actual comparison-worker consumption
and an unterminated trailing count refusal. Native full-module proof remains the
next gate; no broader transport/platform claim follows from the host adapters.

The policy reuse adapter now returns a canonical receipt from an explicit JSON
tree root, preserving the existing archive wrapper. Health-only assessment reads
that receipt through an absolute private path with an independent native byte
count, one complete LF-terminated line and EOF, canonical fields and existing
feature-specific numeric limits. Legacy assessment retains its environment
interface. Three focused host cases passed in 0.24s, including legacy parity and
malformed private frames; parent reviewed the delta. This provides a pure
interface only and does not establish the missing logging collector or native
dispatch proof.

The complete affected native run exposed optional AWK exponentiation in the new
CIDR residual-bit comparison (`Math support is not compiled in`). Parent replaced
it with fixed divisors for the three possible residual widths, retaining exact
IPv4/IPv6 prefix semantics. Nine focused host boundary cases passed in 0.88s,
including the newly explicit one-bit case; native confirmation remains pending.

The remaining package/recovery/backup/hooks design received **PASS WITH NOTES**;
parent accepts these evidence-backed qualifications before implementation:

- Entry `cfmgr_health_records` retains optional tuples even after their file
  verification fails. Package inventory PASS therefore needs all four entry
  optional flags as well as exact original tuple binding. The new manifest must
  retain full v1/v2 grammar and measured byte/LF framing; ordered catalog bytes
  must match the admitted catalog digest and complete module set. Check the
  fourteen known files, three empty placeholders and four module directories;
  an unexpected inspected entry fails, while listed uninspected extensions
  remain UNKNOWN and are never imported. Earlier code hashes are explicitly
  non-atomic report evidence. A standalone invocation additionally checks the
  installed entry's presence/protection/digest.
- The six known guard names match launch structural admission. Absence requires
  a successfully reaped complete bounded support-root listing, native byte/LF
  counts, framing and unchanged protected attachment. A present but unstatable
  guard stays present/type-unverified; a dangling symlink is not followed. The
  controller must perform the post-list attachment check after the worker's
  terminal exec. No observation grants recovery or operational authority.
- Backup identity must use the broader Backup UUID/filesystem policy, an actual
  mountpoint exactly matching saved selection, and canonical/full-mount identity
  rechecks. Avoid mutating Backup wrappers and FD6/7 ownership. Read-only or
  noexec does not invalidate identity; neither rw nor directory metadata proves
  writability. An unsuccessful CFBackup metadata probe means unverified, not
  absent. Recorded backup age and set association stay separate from current
  destination/actual archive existence; do not expose UUID, path, set/archive
  identifiers or saved arbitrary date/time text.
- Generic ownership schema provides no hook producer or digest-scope contract.
  A fixed-hook whole-file digest match may be described only as that byte match;
  mismatch must not claim a corrupt managed block. Inspect only the seven fixed
  hooks. Parse exact labelled cron multiplicity/schedule/effective SHELL from
  the shared private observation without publishing commands. Matching the two
  documented schedules proves no dispatch/ownership. Hooks reuse the same
  native scheduler/process observer even if logging is not requested or Scribe
  is absent; malformed evidence remains distinct from a missing producer.

The practical package-only estimate is approximately 18–22 stages, not the old
small allowance: around twenty metadata operands already require two batches
per boundary before snapshots, counts, digest, listings and final validation.
Final actual combined counters remain necessary. Lean gates cover original tuple
drift, failed optional admission, unexpected/uninspected entries, standalone
installed-entry disagreement, incomplete absence evidence and dangling guards,
broad UUID/read-only/replacement cases, private-marker suppression and shared
scheduler reuse. None of this design earns an acceptance tick.

The logging bundle can avoid per-file hex subprocesses with an explicitly
validated raw reader: `LC_ALL=C`, LF record separator, independent native byte/LF
counts, exact EOF, retained CR/tabs, a prefixed byte lookup, and immediate failure
on excess records/bytes or unsupported controls. Reconstruct only the counted
LFs, preserving an unterminated final line; require exactly L or L+1 records.
Parent accepts a private `-` sentinel for an empty DATA/FRAGMENT value, decoded
only at that ingestion boundary, so new health bundles need no silent empty-to-
newline normalization. Existing archive pack defaults remain unchanged. Count
the complete produced bundle independently before any consumer, since producer
success alone does not prove AWK output completion. A narrow `includes-raw`
adapter may reuse this admitted text and the existing include scanner, avoiding
the separate debug-hex stage without changing warning or coverage semantics.
This source-reviewed design still requires host/vendor implementation proof.

The raw-history adapters are now integrated. Three focused host cases passed in
**0.53s**, including exact serialization into the unchanged `base`/`assess`
consumers, byte/count/control admission and unchanged empty archive packing.
The new modes alone require `LC_ALL=C`, accept a fixed owned-basename allowlist,
and preserve the legacy three-field bundle. Ruff/compile, shell syntax, plain
shfmt and whitespace checks passed. Controller-owned file admission, independent
native counts, the full logging consumer and vendor BusyBox proof remain separate
pending evidence; a pure-parser pass does not prove Scribe/logrotate readiness.

The remaining local-observation review distinguishes approved integration names
from absent operational producers. Section 12 names `CFMgrWatchdog` and
`CFMgrCloudflaredUpdate`, but current ownership records do not establish a
canonical installed command/hook-block contract. Reuse admitted cron/process
evidence and compare recorded fixed-hook digests; report named schedule, count
and integrity evidence without claiming firmware invocation or command ownership.
Never execute or modify inspected hooks. Parent reconfirmed the official
[User scripts](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts),
[Addons API](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Addons-API) and
[Custom config files](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Custom-config-files)
guidance on 2026-10-21: hook paths/enabling, addon storage and generated-service
overrides are separate contracts. Current documentation does not qualify older
firmware or prove an observed file is operational.

Known recovery observations cover `entry.stage`, `.setup.complete`,
`.storage-observation` and the three `.config-save` guards; metadata failure is
not absence. Reuse retained setup evidence and bounded fixed metadata without
calling recovery/cleanup controllers. Backup observations may compare the saved
mountpoint/root/filesystem and broad supported UUID with current mounted-volume
evidence, then recheck attachment. No folder creation, archive scan or write/
flush test is needed for that claim. Last-backup data remains a historical record,
not evidence that its archive still exists or verifies. Keep this local work
independent of provider readiness and preserve Entware descriptor ownership.

Consolidation inspection exposed a pre-existing real consumer defect:
`health-realpath` aliased the basic worker's `status-realpath`, which only
accepts `/jffs` or `/opt`. Native curl/OpenSSL/CA/flock and individual Entware
tool candidates therefore failed argument admission before readlink. Existing
degraded-path consumer tests did not expose the healthy-path failure; their
earlier passing receipts remain valid only for the paths they exercised. Parent
approved a separate bounded health readlink dispatcher plus actual dispatch
coverage and an audit of the other aliases. No claim of complete health behavior
or acceptance was made from the earlier interim core pass.

The first native Dev run at `2a50fc5` found a real portability defect: its token
backslash case was admitted by BusyBox's escaped-slash bracket expression, while
host AWK rejected it. No product acceptance was awarded. Parent added explicit
backslash-byte rejection to token projection and the entire private request
grammar, with direct request-damage coverage. Fourteen focused host cases passed
in 1.29s. Exact native Dev at `956d9ed` then passed all nineteen token/request/
real-curl cases in 5.77s, including redirects, body/header limits and stalled
requests. Complete module/core proof remains required. The next complete Dev
selection exposed a stale five-field test call after the six-field renderer
integration; its two calls were corrected without changing the row-cap assertions
or runtime behavior, and the focused case passed in 0.52s.

Optional Lint at `2a50fc5` exceeded its five-minute job limit while running
ShellCheck. GitHub's check annotation confirms the timeout; setup was negligible.
A prior completed lint used 107.50s wall and approximately 5.3 GiB peak resident
memory. Current logs contain warnings but do not isolate the slow source because
the single invocation's output is buffered. Parent and read-only review agree
that separating invocations could expose cost but can also reduce source-following
context; no analysis option, timeout or runner behavior is changed without
resolving that tradeoff. The cancelled run is not a passing lint result and adds
no acceptance evidence. No heavy analyzer is rerun locally.

The complete interim candidate `4a0c6c063c9fbd779ba2b7e90770a409520f9a45`
passed [Checks 39550567595](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39550567595),
including all required host/native jobs in Backup 39550624642, Manager
39550626406 and Status 39550628290. Parent independently verified exact SHAs,
terminal conclusions and test logs. The sole skipped parent job is cancellation
cleanup, which is conditional on cancellation and is not a product check.

| Module/platform | Test result | Test wall / user / system seconds | Job elapsed including setup |
| --- | --- | --- | --- |
| Backup host | 404 passed; 1 native-only skip | 109.18 / 35.56 / 34.68 | 2m07s |
| Backup BusyBox | 405 passed | 351.78 / 190.72 / 149.96 | 6m04s |
| Manager host | 600 passed; 29 platform skips; 4 optional deselections | 99.12 / 40.86 / 41.17 | 1m50s |
| Manager BusyBox | 628 passed; 1 host-only skip; 4 optional deselections | 551.98 / 308.96 / 235.87 | 9m31s |
| Status host | 127 passed | 15.59 / 4.51 / 1.95 | 37s |
| Status BusyBox | 127 passed | 26.24 / 10.76 / 6.60 | 57s |

The native Manager skip is the explicit non-Linux workstation-without-proc
boundary, skipped in both Ubuntu jobs and not newly proved by this CI. Required
mount/process cases skipped on host run in the native job. All complete modules fit the ten-minute
budget; Manager native remains the cost-sensitive group. No extra full run was
added for timing. These receipts validate the current foundation/consumer only:
advanced health groups and the combined resource envelope remain unfinished, so
neither S03.09 nor S03.10 earns acceptance. Ubuntu/native BusyBox remains
representative development evidence, not real-router qualification.

The consolidation/actual-worker repair candidate
`adc59bad3a8d23ecf55812badb4b34192d0072db` passed
[Dev 39554450182](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39554450182)
with 226 cases, including native file-quota/signal rejection and the actual fixed
health-realpath dispatcher. Its exact complete
[Checks 39554674361](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39554674361)
and all six module jobs passed. Parent verified the required job/step results
and logs; the existing non-Linux and optional exclusions remain explicit.
Status rose to 153 passing cases per platform while native test wall time stayed
26.94s (11.08s user/6.61s system). Manager native took 9m27s including setup,
552.38s test wall and 546.77s user+system CPU, comparable to the preceding gate.
Its largest costs remain real installer/retained-launch connections already
reviewed below; no safe new small shortcut or reason for a timing-only run was
found. This closes the interim consolidation proof without accepting the still
unfinished health/terminal package.

## S14.03 archive selection and actions review

The authorized standalone package extends the existing Backup owner with source
selection, metadata listing, selected full verification/effects review and
confirmed single deletion. Actual restore Save/reconstruction/activation retains
its S14.09–S14.11 gates. Parent and independent Astra scope review agree that
accepted parsing, drive identity and archive foundations permit this boundary;
no new runtime owner or permanent test group is justified.

Source review identified three concrete integration hazards:

- `cfmgr_archive_work` may persist an absent backup-set identity and assumes
  creation preferences. Browsing needs a separate operation-local controller and
  existing-folder admission, preserving saved destination, preferences and set.
- `cfmgr_archive_existing` fully copies/decompresses/verifies every candidate
  against the saved set. Browser listing needs bounded metadata discovery and
  the selected archive's admitted own-set identity, while creation/retention keep
  strict same-set checks. Metadata recognition grants no full-verification or
  deletion authority.
- The real payload plan contains both useful STATE/CLOUD/LOG/STORAGE fields and
  secret-bearing AUTH rows. Only an explicit safe projection of fully verified
  data may reach the UI; raw plans/configuration cannot be displayed.

The lightweight archive supervisor tracks a direct exec, not an arbitrary
pipeline. Parent and worker therefore rejected a gunzip/dd pipeline. The reviewed
replacement uses a bounded compressed prefix (at most 65,536 bytes) and one
supervised gunzip writing an exclusively owned stage output under its file-size
limit. Strict admission of the first regular manifest header and complete
manifest bytes yields only metadata recognition. A selected action still requires
the complete immutable snapshot, payload/hash/semantic verification and fresh
identity/content checks before deletion.

Independent Astra review returned **PASS WITH NOTES**, agreed by the parent:
preserve the decompressor's original exit/status/reason/stderr before other probes
overwrite shared results; require positively reaped ownership and no supervisor
failure reason; admit only demonstrated successful/expected file-limit outcomes
with their exact native/host output bounds; disable child core dumps; and keep
unexpected errors/insufficient prefixes visibly incomplete. The native 4,608-byte
and host-adapter 9,216-byte limit behavior and SIGXFSZ outcome remain execution
claims to verify, not assumed platform proof. No generic exit-one or stderr
suppression exception was approved. Prefix inode/size observations do not prove
unchanged content during concurrent same-inode rewrites.

Independent backend implementation review returned **PASS WITH NOTES**. The
review traced the public operation-local source controller, immutable selected
snapshot, own-set semantic verification, receipt-bound one-file deletion and
cleanup/unresolved outcomes, finding no material defect. The safe projection
excludes AUTH values, credential references, raw logging policy and draft inputs;
unrecognized future draft-stage names display as incomplete rather than arbitrary
saved strings. Creation/retention retain explicit saved-set matching.

Focused local execution proves small exit-zero metadata recognition, secret-safe
projection, changed-byte/lost-attachment refusal and real selected full verification
plus deletion with unrelated data preserved. Big Sur's gunzip catches the output
limit and emits stderr/exit 1, so its large-prefix outcome correctly remains
incomplete. This is a host limit, not evidence of a native pass or permission to
broaden accepted error outcomes. Native capped-prefix behavior remains pending.

The installed-entry Mac journey now proves entry/source selection without a
saved destination/set, the real public controller and native archive tools,
truthful incomplete metadata discovery, owned cleanup and unchanged configuration,
archives and unrelated data. The same test's native branch must still prove the
complete numbered-list/selected-verification/effects/default-no deletion journey.
The Mac branch does not substitute for that pending platform evidence.

The first complete local Backup group passed 375 cases with 23 explicit Linux-only
skips but took 789.40s, exceeding the ten-minute target. A matched unchanged
verifier using the old runtime and current runtime on the same Mac took 40.07s
and 37.80s respectively, with nearly identical CPU work and identical supervised
probe, attachment and per-file inode observations. Fifteen new cases contributed
26.03s; most growth was in existing cases. This supports host/tool-cost variation
as the principal observed cause, without waiving the measured cost gate.

Review identified repeated native `ls` launches for private RAM stdout/stderr
receipt ownership. Independent Astra proposal review returned **PASS WITH NOTES**
for batching those genuine observations: preserve every exact path, multiplicity
and inode check, validate the existing 128-file bound before execution, reject
all uncertain/partial results before cleanup, and preserve the original probe
outcome. Profile accounting must distinguish native launches from per-file
observations. This is a bounded existing-owner optimization, not permission to
reduce safety proof or add a runtime module.

Parent and independent implementation review found no material regression in the
batching patch. Explicit safe leaf operands are unique and bounded before native
execution; each remains a regular nonsymlink file under the pinned RAM context.
The parser validates the exact observed set/count and positive inode values
without depending on display order. Retirement compares the complete observed
ledger before its single anchored deletion and preserves the ledger on failure.
Original probe results remain intact. Native command-substitution trailing-LF
normalization is accepted: a complete exact identity record needs no additional
process merely to distinguish its cosmetic terminal newline. This does not relax
archive payload/container framing or any missing/partial identity rejection.

Focused execution confirmed genuine pair/multi-pair observations, original failed
probe preservation, complete refusal after a real inode substitution, and no
enumeration for empty/over-limit ledgers. Cheap missing/duplicate/unexpected-row,
nonzero-exit and inode-mismatch cases preserve every file and the original ledger.
A redundant truncated-name variant was removed because exact unexpected-name
matching already proves that boundary. The unchanged real verifier retained 279
supervised probes, 157 archive inode probes, 979 attachment checks and all 1,116
RAM inode observations while reducing native RAM `ls` launches to 302 (814 fewer).
Its call time fell from 35.84s to 24.07s. The optimized combined selection,
including the then-seven cheap cases, took 27.21s wall / 14.36s user / 7.84s sys;
the preceding verifier-only selection took 37.80s / 18.69s / 12.61s. Those CPU
selections differ, but the larger optimized selection used less CPU as well as
less wall time. Complete-module cost remains a separate gate.

The subsequent complete Backup gate passed 381 cases with 23 platform skips in
607.79s wall / 327.15s user / 188.74s sys, improving both wall and CPU cost but
remaining 7.79s above the target including setup. Parent identified one further
repeated lifecycle: the raw walker and browser create, measure, record and delete
a temporary 512-byte header solely to pass it to hexdump. Independent Astra review
returned **PASS WITH NOTES** on replacing that lifecycle with a fixed supervised
512-byte range read from the admitted immutable raw snapshot, retaining existing
input admission and before/after stage identity checks. Parent authorized this
as the final bounded repair in the current cost review.

The pinned vendor [hexdump offset parser](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/util-linux/hexdump.c#L102-L115)
and [regular-file seeking](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/libbb/dump.c#L305-L324)
support the proposed offset operation; the repository's native configuration
enables large-file support. Local host reads at offsets 0, 13 and 256 matched
nonuniform expected bytes. Short reads can return zero, and the pinned reader
can [report I/O errors on stderr](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/libbb/dump.c#L369-L403)
without a failing exit. Therefore admission requires successful execution, empty
stderr and exactly 1,024 hex bytes before invoking the strict header parser.
Short/failed reads remain incomplete rather than being reclassified as parser
exclusions. Preserve the hex receipt across measurement/identity probes and retire
RAM receipts at the existing per-header boundary. Native tool execution remains
pending; source compatibility and Mac proof do not qualify Merlin/ARM.

Parent and independent implementation review returned **PASS**: both consumers
use the same fixed reader, output survives measurement/identity probes, short
reads stay outside the trusted parser-exclusion path, and per-header RAM retirement
remains intact. The direct helper test passed actual offset bytes, noncanonical
offset rejection before execution, a 511-byte remaining-input refusal and owned
cleanup. The representative verifier/browser selection passed locally (native
capability explicitly pending), using 234 supervised operations and 257 RAM `ls`
launches in the verifier versus 279 and 302 before this change. Removed inode
observations belonged to header scratch files that no longer exist; required
input/stage/remaining-receipt and payload checks are preserved. Variable-host
focused timings do not establish a wall speedup; the complete-module gate must
provide the final cost result.

The final Mac group stopped on an existing installed destination-Save PTY wait:
332 passed, 18 skipped and one failed in 616.03s wall, with 319.43s user / 177.60s
sys. The fixture exceeded its eight-second notification wait; later cases were
not run. A subsequent read of the retained fixture established byte-for-byte
equality with the test's expected final configuration, preserved unrelated edits,
the selected folder present and the other folder absent. These data effects
support a notification-timing problem but do not establish a passing test or
justify changing the assertion without further evidence. Heavy local testing
was stopped at the user's resource request; remaining local gates and exact
remote proof are explicitly pending in the handoff.

Parent and independent closure review found no changed destination-Save path:
the backup action/work/UI Save functions and configuration transaction are
unchanged; the new dispatcher operations are archive-only. The retained fixture
also has no pending Save guard or RAM context, and its last recorded route is
the post-publication configuration readback. This supports completed publication
and cleanup, but does not prove the missing acknowledgement, normal return or
reopen. No new unsafe-write/corruption defect was found. The timing cause remains
unmeasured; any acceptance exception must preserve this failed local result.

The three exact-`ebe861b12c17fab9a15787c0eb526ce60e6dffc1` native Dev selections
subsequently passed: metadata/menus **83 tests, 66.51s wall / 33.14s user /
32.20s sys**; verification/effects **40 tests, 108.27s / 58.21s / 50.12s**;
creation **6 tests, 46.06s / 27.17s / 15.75s**. Including setup, those jobs took
84s, 128s and 75s respectively. The complete installed browser journey, bounded
prefix reader, direct header helper and existing Save/reopen journey all ran
successfully under actual vendor BusyBox. These are representative native-host
results, not Mac completion or Merlin/ARM qualification. Exact complete core
and the local-gate decision remain pending; no acceptance is inferred here.

Complete core on `ebe861b` exposed a shared-test-fixture dependency missed by the
focused map: `test_archive_io.py` added the `drafts-review` JSON mode, while the
history fixture's literal replacement still expected the older mode list. It
therefore failed to add `history-policy` to the branch that checks retained FD9
instead of redirected stdin. Host and vendor BusyBox both failed the existing
borrowed-lock case. Parent and the bounded repair worker agree on this direct
cause; production lock handling did not change. Repair `00b71fe` updates the
exact mode list and asserts a unique match before replacement, preserving both
FD identity assertions. No test was removed or relaxed. Brief static checks
passed; the complete affected history module and fresh exact core remain due.

The complete affected native history module subsequently passed all **46 tests
in 13.82s** at `00b71feb70eac9d59138eb37310bfd42f95360d4`, with **30s including
setup** in [Dev 39235693968](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235693968).
This closes the focused fixture repair, not the pending exact complete core or
Mac gate/cost decision.

Final complete [Checks 39235896209](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235896209)
passed at **`00b71feb70eac9d59138eb37310bfd42f95360d4`**, including preflight,
dispatch, all six module jobs and the strict exact-candidate collector. Parent
verified logs and terminal job results. Successful aggregate-job span was
**9m26s**; cancellation-only cleanup correctly skipped. Module elapsed includes
checkout/setup/post-job work; the separate test-process measurements below
provide wall and aggregate user/system CPU accounting.

| Complete module | Host tests; wall / user / sys | Native tests; wall / user / sys | Module elapsed |
| --- | --- | --- | --- |
| [Backup](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235953005) | 404 passed / one platform skip; 127.25s / 46.38s / 42.71s | 405 passed; 441.61s / 241.57s / 200.43s | **7m37s** |
| [Manager](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235955405) | 565 passed / 29 platform skips; 87.94s / 38.31s / 35.59s | 593 passed / one workstation-only skip; 503.89s / 287.98s / 210.83s | **8m47s** |
| [Status](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39235958181) | 36 passed; 13.35s / 2.03s / 1.66s | 36 passed; 16.00s / 4.40s / 2.70s | **46s** |

Four optional Diagnostics cases remain excluded per Manager platform. No optional
checker/code implementation changed; required planning/link checks passed. No
runtime module or permanent test group was added. The fixture repair is test-only;
runtime bytes are unchanged from `ebe861b`.

Final cost review retained the two bounded optimizations rather than deleting
distinct safety proof. The native Backup group includes 405 cases versus the
prior 383. Its real new installed browsing journey takes 26.92s and proves the
actual no-saved-destination consumer; it is not a duplicate parser matrix. The
largest existing cases remain complete creation/history (57.89s), rich capture
(44.97s) and selected semantic verification/deletion (25.81s). Complete native
test time rose from the prior 342.86s to 441.61s, while host time fell from 139.41s
to 127.25s and host aggregate CPU from 105.47s to 89.09s. These are different CI
jobs with uncontrolled runner variation and changed scope, not a controlled
benchmark or proof that one patch caused every difference. All final complete
modules remain below ten minutes. No further cheap, justified coverage removal
was identified in this bounded review; this is not a claim that future
optimization is impossible. No timing-only rerun or broader redesign was added.

After all CI passed, parent explained the outstanding local gates and requested
one explicit exception. The user replied **"as long CI passed then its fine"**.
Parent accepts **S14.03 only** using complete exact CI and the written focused Mac
proof, with the final Mac Backup timeout/failure, unrun final complete Mac Manager
and earlier 607.79s complete Mac Backup pass preserved in
[review notes](PLAN_V2_review_notes.md#14-backup-and-restore). The same Save test
passes on both required CI platforms; its Mac timing cause remains unconfirmed.
No local failure is relabelled passed, no product assertion/CI gate changes and
no future full-local exemption is inferred. Ubuntu/vendor BusyBox remains
representative development evidence; Merlin/ARM/live qualification is deferred.

## S04.01 safe data parsing review

The current installed consumers provide a concrete foundation audit: fresh and
retained package admission, scoped configuration Save and settings/status readers,
and full manual archive capture/verification. The following map records reviewed
implementation and proof, accepted at `c8c76f0d5cc44792387dc43388f7dc418a7fb3fb`
after all required gates passed. Future setup/provider/restore consumers
retain their own integration gates.

| Contract | Current owner and consumer proof |
| --- | --- |
| JSON is data; malformed syntax, decoded duplicate keys and invalid UTF-8/framing reject | `config.sh` JSON tree getter, used by the fixed `worker.sh` config/payload modes; `test_config_observation.py` exercises escaped duplicates, malformed data, byte counts, NUL/invalid UTF-8 and preserved literal bytes. |
| Required schema and safe paths | `config.sh` schema/observation consumers admit schema 1/2 and typed nested versions; `test_config_schema2.py` covers invalid authority and real Store refusal without changing live bytes. Unknown passive extensions remain preserved. |
| Finite configuration input/output | Private immutable snapshots, independent size checks and supervised parsing in Store/launch/archive; JSON limits are 65,536 input bytes, depth 32, 4,096 nodes, 16,384 decoded string bytes and a 131,072-byte tree/token budget. |
| Catalog/package inputs remain passive | `package.sh`, fixed worker grammar and entry framing enforce version/schema, complete module correspondence, safe relative paths and digest admission before use. `test_entry_package.py`, `test_acquire.py` and `test_install.py` exercise the real entry/acquisition/install boundaries. |
| Full YAML bytes survive | `backup.sh` snapshots and copies the original data, deriving a separate identity/dependency receipt. `test_populated_capture_preserves_full_bytes_and_off_history` checks exact bytes, sizes and hashes. The supported subset does not rewrite full YAML. |
| Credential/certificate identity | Shared JSON parsing plus Backup payload joins require selected account/UUID/secret identity; PEM framing and native decoding precede account checks. `test_archive_payload.py` and `test_real_archive_verifier_runs_payload_callbacks_with_native_tools` exercise these joins. Parsing establishes no current remote-authentication claim. |
| Rejection grants no deletion authority | Conservative YAML rejection stays incomplete during retention; `test_archive_transaction.py` contains the real metadata-budget rejection and no-pruning regression. Operational failure is distinct from positively identified optional certificate damage. |

The reviewed YAML subset is one mapping document with block mappings/sequences,
plain/quoted values, ordinary block scalars and JSON-compatible quoted escapes.
LF/CRLF and a missing final newline are supported for YAML; flow containers,
anchors/aliases, merges, tags, directives and multiline quoted values reject
conservatively. It validates UTF-8, limits depth to 64, physical lines to 65,536
bytes and referenced paths to 1,024 printable ASCII bytes. Whole-source capture
is bounded by admitted available space and the existing operation deadline;
metadata/output consume the admitted 65,536–16,777,216-byte inventory budget.
These are existing parser/caller limits, not a claim of general YAML support.

Credential/certificate JSON uses the shared 65,536-byte input limit. PEM input is
also bounded to 65,536 bytes, physical lines to 160 and base64 lines to 128, with
one token block amid supported labels. Its decoded JSON still must match the
selected account. Package manifest admission uses a 131,072-byte input cap,
512 entries, 1 MiB per member, 16 MiB total, 256-byte relative paths and depth 16.
Manifest/catalog require final LF, unlike the separately supported YAML framing.

Two read-only reviewers and parent inspection identified these bounded gaps:

- YAML plain values starting with closing flow indicators or a separated `-`/`?`
  were accepted. Parent reproduced successful receipts for `foo: ]`, `foo: - child`
  and `foo: ? child`. The existing scalar guard needs the missing leading-indicator
  checks while retaining URLs, ordinary punctuation and quoted data. This follows
  the [YAML plain-scalar grammar](https://yaml.org/spec/1.2.2/#733-plain-style),
  without introducing a broader YAML parser or changing the supported subset.
- The shared bootstrap manifest/catalog grammar omitted strict byte/newline
  framing. Parent reproduced success for otherwise valid metadata with final LF
  removed. Fresh bootstrap additionally reached catalog parsing before its later
  regular-file and actual-size admission. The repair must precede those reads and
  preserve native retained-launch access before Entware admission; installed entry
  and remote acquisition already supply framing checks.

Both demonstrated gaps are repaired in their existing owners. The YAML scalar
guard now rejects the missing leading indicators; positive punctuation and quoted
values remain covered. Fresh bootstrap admits both regular metadata inputs before
supervised copying and passes explicit private copies to the shared parser. Native
WC byte/LF counts and C-locale ASCII/grammar checks agree on those same copies;
the manifest digest and catalog size/hash bind the parsed bytes to publication.
Retained launch reuses its existing copies before storage pin/repair and preserves
their migration and later live-file digest comparisons. A review-stage private
snapshot mode mismatch was corrected: private copies are checked by size/hash,
while live distribution files retain their metadata checks.

Parent and independent planner source review agree on these repairs. Sixteen new
package cases add cheap direct grammar/framing checks, fresh missing-LF/oversize/
FIFO rejection before config/JFFS claim, and retained corrupted-snapshot refusal
before pin/repair. Healthy fresh and retained journeys plus those cases passed
18 tests in 23.13s; their strengthened early-refusal subset passed 15 in 1.85s.
The existing configuration test module now covers depth/node/string/input limits;
existing NUL/UTF-8 and archive-incomplete regressions are reused. Complete local
Manager passed 522 tests with 72 explicit platform skips and four optional
diagnostics excluded, in 343.89s wall / 161.66s user / 110.35s system. Required
statics passed. At candidate `efdd465882babd54984c7aa8f0aed94549900ea3`, complete
focused native package/config modules passed 96 in 115.02s and archive/YAML/I/O
modules passed 106 in 89.62s. Final exact
[Checks 39188440805](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39188440805)
and all six independent Backup/Manager/Status platform jobs passed. Host total:
983 passed / 30 explicit platform skips; native total: 1,012 passed / one
workstation-only skip, with four optional diagnostics excluded per platform.

Complete local Backup passed 360 tests with 23 explicit platform skips in 697.10s
wall (301.72s user, 242.51s system). The cost audit found only 5.88s of pytest setup;
the large costs are distinct real capture, verification, creation and corruption
boundaries with already-small fixtures. Parent, worker and planner found no small
fixture-only reduction recovering the 97.10s local budget overrun without losing
required proof. One separate native benchmark repeated identical assertions 100
times on each backend; this is reduced to one observation per assertion/backend,
removing 594 redundant applet launches while retaining semantic checks. Native
Dev validated this reduction: the check measured 0.006s wall/CPU in total versus
the previous 0.402s wall / 0.411s CPU. It does not resolve the macOS overrun. The
local cost decision remains open; no timing budget, acceptance requirement or
safety test was waived. Complete candidate CI module elapsed times including
setup were Backup 6m00s, Manager 7m16s and Status 37s, all below ten minutes.
The native Backup behavior gate used 326.06s wall / 185.35s user / 128.46s system;
Manager used 411.60s wall / 231.51s user / 155.16s system. These differ from the
previous runner timings, but the small benchmark change cannot explain the full
variation and earns no whole-suite performance claim.

The user's renewed cost review found a further fixture improvement missed by
the earlier bounded reviews: the Mac shared archive fixture wrapped every native
inode listing in an extra shell solely to force leading-space formatting.
The existing verifier profile contains 1,116 RAM inode observations plus 157
supervised inode probes. Broad Mac integrations now use real native ls directly;
the existing combined stage-inode and RAM/published/append tests retain the exact
padded-output adapter. Linux lock-checking wrappers and padding are unchanged.
No assertion or test case was removed. Parent and independent Astra review agree
that this preserves inode/cleanup coverage and removes repeated fixture work.

Paired focused proof on the same host, using the unchanged five-case selection,
passed before and after: **37.66s to 28.75s wall**, **14.83s to 12.69s user** and
**14.56s to 9.56s system** (36.55s to 27.86s pytest). The actual verifier call
fell from 33.01s to 26.45s. This is a focused comparison, not a whole-module
speedup claim. The subsequent complete affected Backup gate passed the unchanged
**360 tests / 23 explicit Linux-only skips** in **549.47s wall / 264.71s user /
184.94s system** (546.93s pytest), below the ten-minute target. Its 279 supervised
probes and 1,116 RAM inode observations are unchanged. Compared with the original
complete run, measured wall fell 147.63s and aggregate CPU fell 94.58s; host/run
variation is not controlled, so the entire difference is not attributed solely to
the fixture change. No timing exception is needed. Final native Dev passed all
56 I/O/verifier tests in 130s including setup at the new candidate.

The renewed negative-case audit retained distinct real proofs: malformed archive
rejection before tar; a bad second payload digest before its callback; unsafe
inventory paths before payload callbacks; separate payload/complete callback
failure propagation; expected-set wiring; required JSON absence and foreign
draft refusal; and certificate damage with a valid alternate versus damaged-only
recovery failure. Cheap header/metadata/JSON/PEM variants already exercise the
other input forms. Wrong-set classification coverage elsewhere bypasses the real
metadata orchestration and cannot alone replace its integration proof. No further
trivial case deletion/consolidation was justified; this is a bounded review
finding, not a claim that no future optimization is possible.

No new owner, permanent core group, requirement or live-router claim is introduced.
The original candidate passed its functional gates. Final acceptance is at
**`c8c76f0d5cc44792387dc43388f7dc418a7fb3fb`**, with
[Checks 39193784039](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39193784039)
and every required host/BusyBox module job verified successful at that exact SHA.
Complete module elapsed including setup is Backup **365s**, Manager **510s** and
Status **33s**, all within budget. Native Backup behavior used **342.86s wall /
207.64s user / 128.30s system**; Manager used **491.97s wall / 285.39s user /
200.23s system**. Their runtime and Linux fixture paths are unchanged by the Mac
optimization; timing variation is not a new code-performance claim. No further
small cost repair is justified by these passing, within-budget results. Parent
review agrees with the independent functional and fixture audits; S04.01 is accepted.

## S14.01, S14.04–S14.08 accepted checkpoint disposition

Parent and independent source/security reviews agree that the manual creation,
consolidation, native integration and measured-cost findings below are resolved
for this package. Acceptance is at **`4942b3416fbc68aeeace15284dccf6077f3cf138`**, after
[Checks 39034472135](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034472135) dispatched and verified separate [Backup Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034514621), [Manager Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034515614)
and [Status Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034516700) runs. Both required platforms passed per module; total module wall
including setup was **7m31s / 8m21s / 38s**. Host total: **957 passed / 30 explicit
platform skips**; native total: **986 passed / one workstation-only skip**. Four
optional diagnostic cases were excluded per platform. No required proof was
narrowed or timing limit raised. Earlier pending native/core statements below
record intermediate stages; these final receipts close those gates for the six
named IDs, without claiming unfinished browse/restore behavior.

The separate workflow-history requirement is now demonstrated on GitHub, rather
than inferred from reusable calls. Required parent preflight, dispatch and strict
collector passed; cancellation-only cleanup was correctly skipped. Optional
[Tools Checks](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39034479114) passed 214 cases on each platform in a 19s job. Local complete Tools
passed 214 in 4.80s, and source/YAML/shell/Python/static gates passed. PR correlation,
reruns and cancellation have source/mock validation; no live PR campaign was run.
Runtime is byte-identical to `b0a39dc`, whose complete core and eighteen diagnostic
selections also passed. Representative development evidence remains distinct from
Merlin/ARM and live beta qualification. Six product IDs gain acceptance; tooling
and structural cleanup gain none. The agreed checkpoint is closed.

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

Follow-up integration review found that the consolidation receipt's explicit
`shfmt -ci -sr` command differs from the repository runner's default `shfmt -d`
format. Its reported pass is valid only for that command, not the required
default formatting gate. The established default format is restored without
changing the runner or acceptance rules; the final common static gate verifies
it separately from runtime results. The user's consolidation priority and concrete
backup/config owner rule are now explicit in the specification and mirrored
checklist, preserving their existing S02.01 contract and totals.

The final repository package check also found that the tracked manifest still
contained the pre-consolidation paths and hashes. Fixture-built packages had
regenerated their own metadata, so those passing consumers did not establish the
checkout's manifest freshness. The existing deterministic generator now lists all
14 actual package files with current hashes; the repository package check passes.
The earlier structural WIP commit is not a publishable package by itself. This
repair is included in the complete local candidate before publication approval.

## S02.01, S14.01, S14.04–S14.08 native integration corrections

Representative native execution exposed concrete integration defects that the
macOS descriptor adapters could not prove. Parent and independent source reviewer
agree with the following bounded repairs; final required core acceptance remains
separate from these focused results.

- RAM and archive directory operations passed bare proc descriptor symlinks to
  helpers that correctly reject symlink final components. Using the retained
  directory's `/.` component preserves the opened directory and all original
  pathname/mount/inode checks. Actual native I/O, publication/retention and the
  complete creation journey now pass.
- Pinned vendor `ls -1A` stats every enumerated PID name, allowing ordinary task
  exit to fail process enumeration. Bounded numeric shell expansion with complete
  operand validation avoids those unnecessary metadata races. Empty, invalid or
  over-cap enumerations remain unknown; actual executable, argv, append-FD and
  before/after identity proof is unchanged. Complete native history/I/O passes;
  the residual cooperative readdir limitation remains in review notes.
- Shared settings/backup JSON readers dropped their child lock reference when
  replacing stdin. Retaining it on child FD9 matches the archive reader and
  leaves parent support FD9 intact. All three actual native readers now prove
  exclusion after parent close and release only after child reap. The integrated
  creation history Save passes with this correction.
- Consolidation invalidated several private fixture assumptions: parser getter
  stubs must preserve their full category owners, and category imports must
  precede callback overrides. Corrected native history, shared execution and
  actual retained launch checks confirm those paths. The native ash background
  stdin bridge follows the production supervisor's existing FD9 contract.
- Functional fixture deadlines were shorter than measured native success.
  Production deadlines and explicit cancellation/reaping safety tests remain
  unchanged; expected-rejection tests now distinguish supervisor failures from
  data rejection. Measured outer guards and remaining cost limits are recorded
  in review notes/handoff, without treating a timeout as valid rejection proof.

Independent final source review of `c5b6b55..cf8ecc9` returned **PASS** with no
concrete unintended regression. Native-only BusyBox libc compatibility remains
isolated from the target build and included in cache hashing; all 14 manifest
hashes match. Focused native creation proves prior recognition, new verification,
publication, retention, history Save and cleanup. This supplies no live-router
qualification and does not itself close the final core CI gate.

Full host execution also exposed a timing assumption in the archive deadline test:
its one-second integer-uptime budget began before preliminary inode work, while
its final assertion assumed the blocking tar child had started. Source review
established both legal prelaunch expiry and possible preliminary-probe expiry;
the original quiet failure does not identify which occurred. The fixture now arms
the short real-clock deadline once the child proves its inherited descriptors.
It requires the child marker, exact tar mode, expected reap reason, absent PID and
one-time arming. This strengthens the intended deadline/cancellation proof without
changing production limits. Independent review passed, and the complete native
history/I/O group passed 104 cases at `7a02dc2`; final core remains separate.

The subsequent serial core exceeded the user's acceptable development cost and
was cancelled after about forty minutes. Its host phase passed in 8m47; native
continued making progress but did not finish. The user approved main-module CI
groups and clarified that supporting libraries belong beneath those modules,
with diagnostic subdivision only after a module exceeds ten minutes. The revised
runner partitions all 47 test modules into Backup (19), Manager (24), Status (1)
and contributor Tooling (3). Collection comparison preserves exactly the same
1,110 required cases; optional diagnostics remain excluded. It rejects unmapped
tests, overlaps and missing groups for newly added main modules. Common statics
and both shell syntax modes precede isolated host/native group jobs; the aggregate
requires every job to succeed at the same SHA. Local runner tests passed 80 cases
in 1.22s, and common source checks passed. Grouped CI execution, measured cost and
any resulting slow-test correction remain unverified; this does not award ticks.

The first grouped run at `31926ae` confirmed the cost failure: Backup host took
364.44s, Manager host 114.17s, and both native phases were cancelled when their
whole jobs reached ten minutes. Status passed both shells in approximately one
minute including setup. The aggregate correctly refused the incomplete result.
The user then required separate named sidebar workflows called by Checks,
manual-only Dev/Lint/Diagnostics workflows, and optional manual Tools Checks for
developer-tool behavior. The revised partition retains all 44 product test modules
(963 selected cases) in required core; only `dev_runners`, `platforms` and
`router_probe` move to optional Tools Checks. Source statics and both shell syntax
gates remain required. Independent workflow review passed; runner tests passed
99 cases in 1.79s. No product requirement or safety case was made optional.

The user's cost acceptance is the complete main module within approximately ten
minutes. Smaller diagnostic batches, targeted for two to three minutes after
repair, cannot substitute for rerunning that complete group. A copied-fixture
profile of the existing positive verifier recorded 367 operations, including
245 archive inode probes and 1,468 RAM inode reads. The macOS profile passed all
existing assertions but does not measure Linux supervision. The independent
performance-plan audit approved bounded scalar-guard equivalence changes only
after native measurement, preserving filesystem admission, numeric/deadline
semantics and ownership/signalling/waiting. Native profiling at `31ada7f` then
confirmed 367 probes and 1,101 ownership observations, with 367 explicit pauses.
An identical external-command benchmark identified unnecessary host executable
startup cost: the fixture had not staged the firmware's external test/printf
applets. Correcting that at `f321d55` reduced the positive verifier from 80.44s
to 45.98s and CPU from 68.17s to 32.25s, retaining all 367 operations and assertions.
The privileged installer fixture's equivalent PATH correction reduced its actual
repair/publication case from 176.49s to 133.95s, with CPU 178.27s to 135.01s.
Shell builtins/no-fork remain disabled and production worker PATHs are unchanged.

The subsequent bounded runtime scalar conversion is focused-tested and independently
reviewed PASS: quoted case patterns preserve literal comparisons, short-circuit/
return ordering and integer admission; filesystem and numeric-bound predicates,
deadlines, signals and waits remain intact. At `171f899`, native positive verification
passed in 42.10s (28.63s CPU) and actual repair/publication in 127.91s (128.85s CPU),
retaining the original supervision counters and complete behavior assertions.
Complete prerequisites/I/O passed 48 cases with one workstation-only skip.
No RAM metadata batching was added.

All 17 disjoint diagnostic selections then passed at that candidate, covering
all 927 Backup/Manager cases (926 passed, one explicit workstation-only skip;
four optional dependency diagnostics excluded). Each batch was under 161 seconds.
Summed pytest cost was 665.80s for Backup and 490.14s for Manager. These are useful
cost measurements, not a passing complete-module gate. A further bounded verifier
fixture correction at `0179864` removes unrelated payload members from two
rejection cases: two members for catalog hash rejection, three for unsafe JSON
path rejection. Stronger callback/parser assertions identify the intended failure;
the full five-member binary/empty positive case is unchanged. The two host cases
passed; native integrity cost fell from 62.39s to approximately 41s, with all three
complete verifier selections passing. The final complete-module gate remains pending.

The next bounded optimization has an independent **PASS WITH NOTES** design audit.
For a flat nonsymlink stage file/directory with no active append guard, one supervised
native `ls -id STAGE TARGET STAGE` can replace three separately supervised metadata
probes. Both matched retained `ls.c` copies have SHA-256
`8d76a7301817e798954b27d822915dc95a15b0869bc3d5668c2db7e7b7525264`; their operand
loop performs a fresh stat for every argument, including repeats, before sorting
output. The parser must match exact names and multiplicity without assuming display
order: two stage observations equal the stored inode, one valid target observation,
no missing/extra/unknown/partial rows. Existing archive supervision, directory
identity, nonsymlink/type checks and other-path/active-append fallbacks remain.

The fusion can perform a bounded read-only target metadata lookup before the parent
rejects a mismatching first stage sample. Parent and planner accept this limited
failure-order change under the existing cooperative-root contract: it grants no
ownership, content access, mutation, publication or deletion. Mutation/cleanup
boundaries are unchanged. Runtime implementation, focused substitution/deadline
proof and measured native saving must still pass; the design audit alone is not
runtime or acceptance evidence.

Implementation review caught parent-side target type tests before stage admission.
The selector now examines path syntax only; the supervised worker retains the
original nonsymlink file-or-directory predicate after stage/path-to-anchor checks.
Flat directories therefore retain metadata-only support through the same operation;
`ls -id` never lists their contents. Independent corrective review returned **PASS**.
The planner independently rechecked this exact file/directory refinement and also
returned **PASS**, confirming original accepted input kinds and the supervisor's
completion attachment check. No additional product scope or permission is involved.
Focused host safety checks passed 15 cases with two explicit Linux-only deadline
skips. The unchanged complete positive verifier passed in 30.14s on macOS versus
47.91s previously. Its profile proves 88 fewer supervisor launches (367→279),
88 fewer inode probes (245→157), and 352 fewer RAM receipt inode reads (1,468→1,116),
while retaining all 122 other operations and full payload assertions. Native
execution and the complete module budget remain separate pending gates.

At published `004d852`, native metadata safety passed all 15 selected cases in
4.12s, including both original and combined deadline/reap/FD variants. The complete
positive verifier passed in 31.59s and confirmed the same 279/157/1,116 operation
counts, with 279 pauses and 837 ownership observations. All affected Backup
diagnostic selections passed at that revision, covering 375 unique cases; only
the two deadline variants intentionally overlap the initial safety selection and
complete history/I/O batch. The required complete module gate still decides cost
acceptance; these focused receipts alone award no product credit.

An independent scheduling audit rejected sharing one host between the complete
host/native suites: both real-writer fixtures discover global cloudflared process
candidates and would observe each other's children. Isolated platform VMs avoid
that concrete collision while preserving both complete module selections. The
approved refinement allows two jobs per module (six product VMs), disables matrix
fail-fast and requires all results. Module cost is the earliest job start through
latest completion including setup, with queue delay separate; scheduling alone
does not establish reduced CPU cost or satisfy the complete ten-minute module gate.

The final core attempt [39030592757](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39030592757)
at `004d852` did not satisfy cost acceptance: native Backup continued passing
through 98% before the ten-minute test-step timeout. Manager completed both
platforms in 7m47s including setup; Status completed in 52s. Backup host passed
374 cases with one explicit platform skip in 329.31s. No assertion failure was
reported in the unfinished native group. The aggregate correctly failed and all
six product acceptance boxes remain pending.

The bounded contingency adds one exact-child ownership observation after the first
successful attachment/clock/deadline guards and before sleeping. A child finishing
during those guards can reach the unchanged final observation/wait without a
50ms delay. The flag resets per invocation and is consumed once; a still-live child
retains the ordinary pause and all subsequent cadence. Unknown ownership retains
return 3. Failure/TERM/KILL, timeout-child, absolute deadline and post-wait attachment
paths are unchanged. Independent design audit **PASS WITH NOTES** and exact-delta
source review **PASS**; native safety and measured cost remain required. The host
positive case passed in 23.19s, but its labelled supervisor adapter does not execute
this Linux loop, so that timing cannot establish the optimization's benefit.
Seven controlled tests invoke the production loop and observation wrapper with
labelled proc/clock adapters and a finite real child. They prove the first flag
resets, exact final wait/postwait attachment, later pause cadence, unknown evidence
retention with no product wait/signal, and prior attachment/clock/deadline failures.
Focused local runner/common statics passed 42 cases with 15 explicit Linux skips
in 6.66s. Fixture compatibility uses `unset -f` and builtin wait, preserving the
vendor shell's disabled command builtin. Native proof remains required.

At `5992a36`, native supervision passed 184 cases / one workstation-only skip in
45.57s; history/I/O passed 105 in 46.46s. Verifier structure passed 16 in 59.79s
(42.20s CPU). Its positive profile was only 30.65s versus 31.59s: 279 probes,
256 pauses and 1,093 observations, compared with 279 pauses / 837 observations.
Creation, payload and populated capture also passed. The immediate re-observation
therefore provides too little budget margin and is superseded without claiming
complete-module acceptance.

The revised design uses one 10ms first pause, then the existing 50ms cadence;
it removes the extra immediate observation. Only zero arguments or one literal
`first` are accepted by the pause helper. The first flag resets for every run,
consumes only after successful guards, and never shortens failure/termination
waits. Unknown ownership and pause failure remain unresolved; final observation,
exact wait, timeout-child verification and completion attachment are unchanged.
Independent planner **PASS WITH NOTES** and exact-delta review **PASS**. The code
promises one short interval, not an unconditional cross-run observation-count
bound. Native/host test adapters must honor that fixed selector so actual vendor
`usleep` measurement reflects the implementation. Safety and cost proof remain
pending; no requirements or acceptance gates are relaxed.
Focused local runner/common statics passed 45 cases with 15 explicit Linux skips
in 7.13s. Ten controlled loop scenarios plus the pause capability check exercise
the fixed selector, first/later cadence, prior failures, failed first pause,
unknown evidence retention, and initially absent/zombie children. Native timing
remains necessary; no test uses elapsed-time assertions to manufacture a speedup.
At published `b0a39dc`, native manager execution passed 187 cases / one explicit
workstation-only skip in 37.24s, history/I/O passed 105 in 45.75s, and verifier
structure passed 16 in 41.18s (41.96s CPU). The positive profile improved from
31.59s at `004d852` to **20.90s**, preserving 279 probes / 157 inode probes /
1,116 RAM inode reads. It used 287 pauses and 845 observations: eight continuing
iterations beyond the first wait, with no continuous faster polling. Structure
CPU stayed approximately unchanged (42.26→41.96s), so this refinement's benefit
is reduced avoidable waiting. Native deadline/cancellation/FD/ownership and the
controlled first-pause cases passed. Complete affected batches and the whole
module cost gate remain required before accepting product IDs.


All eighteen complete diagnostic selections subsequently passed at `b0a39dc`;
the slowest whole diagnostic job was 152s. Final
[core 39032859298](https://github.com/XxUnkn0wnxX/CFMgr/actions/runs/39032859298)
passed all eight jobs. Complete module wall times including setup were Backup
**6m27s**, Manager **8m29s**, Status **36s**. Host: 957 passes / 30 platform skips;
native: 986 passes / one workstation-only skip; four optional diagnostics excluded
per platform. The required module cost gate passed without reducing scope or
raising the ten-minute execution limit.

### Independent module workflow histories

The user identified that reusable workflow calls leave the individual workflow
history pages empty. The prior implementation ran distinct module jobs, but missed
the explicit requirement for separate workflow runs. Runtime proof above remains
valid; checkpoint closure is held for this CI correction. Parent and independent
Astra design agree on trusted push/manual dispatch from an isolated no-checkout
job, native PR events preserving fork/cache isolation, and a read-only strict
aggregate of exact-candidate, complete host/native results. Each module keeps its
own statics/syntax and ten-minute bound. Dispatch IDs, PR merge-SHA correlation,
current run attempts, missing/skipped/failing jobs and bounded polling require
focused validation. No `workflow_run` execution of untrusted PR code, write token
in PR execution, or executable-cache trust change is accepted. New exact-candidate
CI must demonstrate separate visible runs before acceptance.
Implementation and independent final review passed. The parent corrected a stale
per-poll success cache and cancellation behavior; optional API workflow-path ref
suffixes are supported without loosening workflow/candidate identity. Privileged
jobs never check out or execute candidate files; all candidate/PR execution stays
read-only. Focused orchestration tests passed 135 cases in 2.42s; complete local
Tools passed 214 in 4.80s with required common statics/host syntax. No runtime
files changed. Actual GitHub dispatch at `4942b34` returned three separate run IDs under their
individual workflow histories. Optional Tools passed 214 cases on each platform
(host 1.60s, native 1.38s; whole job 19s). Complete core child results and strict parent collection subsequently passed;
the accepted checkpoint disposition above records the final receipts.

## S14.06–S14.08 history runtime admission review

Independent Astra review returned **PASS WITH NOTES** for narrowly admitting
native scheduler data and the fixed Scribe rotation lock. Parent accepted these
refinements within the existing cooperative transaction contract. Production
callbacks are now implemented in the consolidated owners with focused host
evidence and a complete host create consumer; actual Linux process/descriptor
proof remains pending. This is not history acceptance.

- The matched crond loader checks the opened account crontab's root owner and
  does not reject native writable mode bits. Supplemental read-only observation
  found canonical root-owned sticky 1777 `/var`, protected cron descendants and
  a root-owned 0666 crontab. A cron-specific data check can admit that layout
  without relaxing executable/configuration path protection. The actual native
  NVRAM path is `/bin/nvram`.
- Inode and size alone do not detect equal-size edits. The supervised reader must
  use its own opened descriptor, compare two bounded complete snapshot hashes,
  and retain account, canonical path, mount/device, inode, size and digest in the
  history fingerprints rechecked under rotation exclusion. A changed admitted
  schedule fails capture. Cron remains private observation data, never payload or
  executable authority. An unsupported effective `SHELL=` makes readiness
  unavailable rather than executing or guessing the override.
- Scribe opens `/tmp/scribeLogRotate.flock` with truncating output redirection
  before attempting flock, sets no explicit creation mode and unlocks without
  unlinking it. Its narrow lock check therefore uses root-owned regular
  single-link type, mount/device/inode and pathname-to-held-FD identity, rather
  than immutable contents/mtime or unwritable mode bits. It must not create,
  truncate, chmod or remove Scribe's lock. This detects ordinary replacement and
  mount changes while coordinating with Scribe; nonsticky `/tmp` does not provide
  protection against arbitrary hostile namespace substitutions.

The source contracts are the
[pinned crond loader](https://github.com/RMerl/asuswrt-merlin.ng/blob/433fc608f5fc1689f3d3c3ab5cd2a7d57102260f/release/src/router/busybox/miscutils/crond.c)
and [pinned Scribe implementation](https://github.com/AMTM-OSR/scribe/blob/53dee6e97c2d6aa4f656c68c18fa1f2c499042f7/scribe.sh).
Source inspection, supplemental metadata, host tests and pending native execution
remain distinct evidence classes.

Implementation review repaired stale cron receipt restoration, process-argv
unresolved-result propagation, executable identity after argv capture, failed
phase restoration and cumulative private-context accounting. Parent review then
caught a remaining base-observation downgrade: a changed admitted cron snapshot
must remain fatal instead of being relabelled optional unavailability. The actual
caller now propagates fatal 2 and unresolved 3, with a focused regression test.
The complete history/runtime/writer host gate passed 64 with 9 Linux skips;
later runtime/writer corrections passed 49 with those same skips. Parent's final
realistic lock/release adapter check passed after context reseeding. Exact command
and timing receipts are in the handoff/private validation record.

Final read-only integration review identified five feature-row write wrappers
that converted unresolved 3 into fatal 2. They now preserve 3, with focused proof
through the feature caller. A Linux-fixture review found unconditional inode
padding in a plain-filename listing adapter and production inode comparisons
that assumed no leading spaces. The adapter now pads only inode output; production
uses IFS field parsing. A formerly vacuous rotation-mount test now changes the
observed mount after a real baseline; the native JSON fixture acquires actual
flock0 before proving FD9 inheritance. Existing I/O contention evidence remains
separate. The final runtime group passed 35 with 10 explicit Linux skips; neither
source review nor host adapters award native proof.

A final Linux-only create-fixture review found two adapter defects before native
execution: the preopened descriptor was not declared during initial Store reads,
and history `plan` was mistaken for a JSON stdin mode requiring FD9. Fixture
preparation now retains its declared FD0, while real Store acquisition still
reopens, locks and tests fresh-open contention. Distinct history-mode labels keep
history `plan` on FD0 and history `policy` on FD9. The history-runtime adapter uses
the same distinction. These are test corrections; production lock reset/dispatch
is unchanged. Native execution is still pending.

The real-create harness then exposed a shared-shell state leak that isolated
callbacks had missed: history context seeding and proc-stat parsing left globbing
disabled, so later Store cleanup could not expand its owned receipt list. Both
functions now preserve the caller's flag, tested with globbing enabled and disabled.
The complete create consumer then passed, including actual Store cleanup, in
87.61s. Its production callbacks use an unconfigured baseline; rich payload and
native writer/lock behavior have separate focused groups and evidence limits.

## S14.01, S14.04–S14.08 create controller review

The focused independent Astra controller audit returned **REVISE**. Parent
accepted five corrections within the original manual-create package. All five
are implemented, with focused boundary tests and a real create consumer:

- Retained compressed archives need a narrow regular-container metadata profile.
  Strict source-payload checks otherwise reject normal FAT/NTFS mode 0777 or
  emulated ownership, breaking recognition and retention. Stable identity, exact
  bytes/hashes and complete same-set semantic verification remain mandatory.
- Record the publication attempt before native rename. A successful move followed
  by mount loss can precede the confirmed-published flag; an unconfirmable outcome
  must be unresolved, with no pruning, history write or nonpublication claim.
- A resource/I/O/unclassified tool failure while inspecting an old candidate
  cannot silently produce a complete retention ledger. Distinguish definitive
  exclusion from incomplete inspection; incomplete scans skip pruning and report
  retention failure separately from successful creation.
- Failure frames can retain a known positive config generation. The UI currently
  rejects those frames but then consumes partially parsed fields, making existing
  output-only tests insufficient. Admit legitimate frames and invalidate all
  decision-bearing data on malformed frames before stopping the affected action.
- Reaped owned-stage cleanup failure after confirmed publication needs the existing
  pending indication and a concise cleanup warning; preserve the archive and
  substituted or otherwise unverified temporary data.

The final independent audit confirmed all five corrections and caught one remaining
resource-classification hole: a quiet YAML parser exit 1 can mean the current
metadata budget is exhausted, not that a retained archive is invalid. Parent
removed YAML from the definitive-exclusion allowlist. A real parser invocation
on valid YAML under an insufficient budget produces its exact `metadata-limit`
receipt, remains incomplete and cannot start pruning. This focused regression
passed in 0.25s. Conservatively incomplete YAML rejection may skip retention;
it never grants deletion authority. No new error framework or behavior waiver
was introduced. Parent agrees the identified source findings are resolved;
native and complete required CI remain distinct outstanding gates.

The scoped trace found coherent Entware/destination phase ordering, config-lock
borrowing, source/rotation descriptor release before verification and Store Save,
separate verifier/caller ownership ledgers and distinct operation deadlines. No
descriptor framework redesign is needed. The passing host create consumer fully
recognizes an independent valid prior container with mode 0777, captures config/
catalog/notes, runs tar/gzip and full semantic verification, publishes, retains,
saves history with a generation increment and removes owned stage/RAM data.
It requires pending 0 and complete/saved outcomes. Host admission, directory-FD,
memory/UUID/timezone and GNU tar adapters are explicit; they do not establish
native filesystem or router qualification. Current commands and pending proof
belong in the handoff.

Parent cost review found the semantic-callback negative cases repeated all five
binary/empty/history/YAML payload members already covered by the complete positive
verifier. The complete-callback case timed out at the unchanged 65s wrapper limit;
the group took 150.59s wall. Its boundary fixture now contains only mandatory
config/catalog members, with explicit payload/complete reached markers so an
earlier rejection cannot pass vacuously. All four cases then passed in 73.48s
(wall 74.10/user 33.54/system 26.48); the separate full binary/empty journey passed
in 63.88s. No production deadline, test timeout or required assertion was relaxed.
The original failed log was accidentally reused by the private runner; its exact
terminal failure/timing receipt is retained separately and is not described as
raw stdout. The runner now preserves superseded logs before reuse.

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

The final package/recovery observer draft received an independent Astra **PASS
WITH NOTES** on 2026-10-21, followed by parent integration into the existing
Status/worker/execution owners. The review corrected printable unlisted names
(e.g. a space-containing basename) to FAIL after a complete inventory, and kept
listed passive extension ancestors UNKNOWN without recursive loading. Fourteen
fixed files, original eleven entry tuples, all optional-admission flags, complete
shared manifest/catalog grammar, installed-entry/catalog hashes and repeated
protected metadata are required for the narrow package agreement claim. It is
explicitly a sequence of observations, not a fresh atomic rehash of all code.
Recovery now independently observes all six launch guards through a pinned,
bounded flat listing; it cannot infer absence from missing metadata. Positive
guard evidence survives a later ordinary metadata failure; unresolved ownership
still stops the report. Native behavior and the combined resource ledger remain
pending CI. Source-estimated cost is 29 operations / 73 reserved files combined;
this estimate grants no capacity change or acceptance.

Parent hooks review corrected hash/metadata ordering and preserved the private
jobs receipt across its independent byte-count operation. Schedule observations
use the two specification-defined labels and fixed schedules; command ownership
and producer dispatch remain explicitly unverified. The full normal Linux entry
journey now belongs to the Status consumer group, retaining actual supervision,
clock, descriptors, quotas, positive reaping and cleanup with labelled firmware
and provider adapters. No feature execution, live router/provider state or
firmware qualification is implied.
