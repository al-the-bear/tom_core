# Audit Module

An attributable, tamper-evident record of **who did what to which record, when,
and with what outcome**. Audit entries are written at two chokepoints the
framework already owns — the endpoint pipeline and the repository write path —
so an auditable action produces a record without the handler that performed it
remembering to ask.

## Table of Contents

- [Overview](#overview)
- [Audit Is Not Logging](#audit-is-not-logging)
- [The Audit Record](#the-audit-record)
  - [What "sortable, unique" means](#what-sortable-unique-means)
- [The Chokepoints](#the-chokepoints)
- [Declared Versus Automatic](#declared-versus-automatic)
- [Reads Are Not Audited](#reads-are-not-audited)
- [The `@TomAudited` Annotation](#the-tomaudited-annotation)
- [Attribution](#attribution)
- [Personal Values: Sealed per Data Subject](#personal-values-sealed-per-data-subject)
- [Sinks, Persistence and Retention](#sinks-persistence-and-retention)
  - [Reading a trail back is per sink, deliberately](#reading-a-trail-back-is-per-sink-deliberately)
- [The Relational Sink](#the-relational-sink)
- [The Write-Once Story](#the-write-once-story)
  - [Retention is an operator action](#retention-is-an-operator-action)
  - [What the sink checks, and what it does about it](#what-the-sink-checks-and-what-it-does-about-it)
- [Tamper Evidence](#tamper-evidence)
  - [What the chain alone cannot see](#what-the-chain-alone-cannot-see)
  - [A damaged entry is not a tampered one](#a-damaged-entry-is-not-a-tampered-one)
- [Anchoring the Chain Head](#anchoring-the-chain-head)
  - [What the result distinguishes](#what-the-result-distinguishes)
  - [Retention does not raise a false alarm](#retention-does-not-raise-a-false-alarm)
  - [What anchoring actually guarantees](#what-anchoring-actually-guarantees)
  - [The posture is declared, and never believed](#the-posture-is-declared-and-never-believed)
  - [Why the publisher is not a scheduled job](#why-the-publisher-is-not-a-scheduled-job)
  - [Reading the anchors back](#reading-the-anchors-back)
  - [Shutting the publisher down](#shutting-the-publisher-down)
- [Failure Behaviour](#failure-behaviour)
  - [Every failure arrives on the returned future](#every-failure-arrives-on-the-returned-future)
  - [Shutting a sink down](#shutting-a-sink-down)
- [Suppressing the Trail](#suppressing-the-trail)
- [Verification](#verification)
- [Querying the Trail](#querying-the-trail)
  - [The projection narrows, the record decides](#the-projection-narrows-the-record-decides)
  - [Paging is by window, not by offset](#paging-is-by-window-not-by-offset)
  - [Exporting a result](#exporting-a-result)
  - [Reports above the query](#reports-above-the-query)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

The module has **four layers**, and every type belongs to exactly one. Each
layer answers a different question, and the questions are worth reading in
order, because each one only arises once the previous is settled:

| Layer | The question it answers |
| ----- | ----------------------- |
| **Record** | What is written down? |
| **Trail** | When is it written down, and what triggers it? |
| **Sink** | Where does it go, and how is it made tamper-evident? |
| **Anchor** | How do we know the *whole* store was not rewritten? |

The last one is the layer a reader is least likely to know they need. A hash
chain proves that nobody edited an entry *within* the trail it is stored in,
but a forger who rewrites the chain from the edit onwards — or truncates its
end — leaves something internally consistent; see [what the chain alone cannot
see](#what-the-chain-alone-cannot-see). Only a claim about the head, published
where the audited server cannot reach it, closes that, which is why anchoring
is a peer of the other three layers rather than an option on the sink.

| Layer | Type | Kind | Purpose |
| ----- | ---- | ---- | ------- |
| Record | `TomAuditRecord` | class | One auditable action: actor, action, target, outcome, before/after |
| Record | `TomAuditActor` | class | Who acted — resolved from the `TomPrincipal`, or `SYSTEM` |
| Record | `TomAuditAction` / `TomAuditOutcome` | enums | `create`/`update`/`delete`/`read`/`execute`; `succeeded`/`failed`/`denied` |
| Record | `TomAuditRecordIdGenerator` | class | Issues the record ids; fixed-width, so a string sort is a write-order sort |
| Trail | `TomAuditTrail` | class | The static facade the chokepoints call |
| Trail | `TomAudited` | annotation | The *declaration*: opt an endpoint or entity in, out, or redact fields |
| Trail | `TomAuditPolicy` / `tomAuditRedactedPlaceholder` | class / constant | The resolved effective policy for one entity type, and what a redacted value reads as |
| Trail | `TomAuditBypass` | class | The zone marker behind `runUnaudited`, so the trail's own writes do not audit themselves |
| Trail | `auditDiff` | function | The changed fields only, as the narrowed before/after pair a record carries |
| Sink | `TomAuditSink` | abstract class | Where entries go |
| Sink | `TomAuditEntry` | class | A record plus its position in the hash chain |
| Sink | `TomMemoryAuditSink` / `TomFileAuditSink` | classes | Bounded in-memory sink; append-only rotating file sink |
| Sink | `TomSqlAuditSink` | class | One row per entry in a `TomDataSource`, with row-prefix retention |
| Sink | `verifyAuditChain` / `TomAuditChainVerification` | function / class | Verifying a chain, and the result of doing so |
| Sink | `parseAuditLines` / `tomAuditGenesisHash` | function / constant | Reading JSON-Lines storage back; the sixty-four zeros a chain starts from |
| Sink | `auditTrailTable` / `auditTrailTableDdl` / `defaultAuditTrailTable` | functions / constant | The relational trail's schema, declared once and derived from |
| Sink | `auditTrailGuardStatements` | function | The optional database-side guard that refuses `UPDATE` or `DELETE`, as the statements a given dialect's database runs |
| Sink | `auditTrailNoUpdateTriggerDdl` / `auditTrailNoDeleteTriggerDdl` | functions | The MariaDB text of the two guards |
| Sink | `auditTrailNoUpdateTriggerName` / `auditTrailNoDeleteTriggerName` | functions | The names those two guards are installed under, so a deployment can drop or probe one without re-deriving the string |
| Sink | `TomAuditWriteOnceCheck` | class | What a deployment's audit table actually permits, as observed |
| Sink | `TomAuditTrailRow` / `TomAuditHeadRow` / `TomAuditSeqRow` / `TomAuditTriggerRow` | classes | The reflected row shapes `TomSqlAuditSink` reads through |
| Sink | `TomAuditQuery` / `TomAuditQueryResult` | classes | A question about a stored trail — actor, target, outcome, window — and what it found |
| Sink | `filterAuditEntries` / `auditProjectionPrefix` | functions | Answering that question over entries in hand; cutting a value to what a lossy projection column holds |
| Sink | `TomAuditException` | class | A sink that could not store a record |
| Anchor | `TomAuditAnchor` | class | A claim about where one chain stood: `writer`, `entryCount`, `headHash`, `createdAt` |
| Anchor | `verifyAgainstAnchor` / `TomAuditAnchorVerification` / `TomAuditAnchorStatus` | function / classes | Checking a chain against an anchor, and what the answer means |
| Anchor | `TomAuditAnchorSigner` / `TomAuditAnchorVerifier` | abstract classes | The signing seam — the key material is the deployment's |
| Anchor | `TomRsaAuditAnchorSigner` / `TomRsaAuditAnchorVerifier` | classes | The shipped RSA implementation of that seam |
| Anchor | `TomAuditAnchorStore` | abstract class | An append-only archive of published anchors, kept where the audited server cannot rewrite it |
| Anchor | `TomMemoryAuditAnchorStore` / `TomFileAuditAnchorStore` | classes | The test store; the local-file store |
| Anchor | `TomAuditAnchorPublisher` | class | Publishes anchors for a sink's chain on a timer — per node, not per cluster |
| Anchor | `TomAuditAnchorMonitor` | class | Reads the latest anchor of each declared chain back and checks the chain against it — per cluster, not per node |
| Anchor | `TomAuditWatchedChain` / `TomAuditChainReader` | class / typedef | One chain the deployment declares, and the read it supplies for it |
| Anchor | `TomAuditAnchorCheck` / `TomAuditAnchorReport` | classes | What one declared chain concluded, and what a whole round did |
| Anchor | `TomAuditAnchorCheckFailure` | enum | Why a declared chain produced no verification: never anchored, or unreadable |
| Anchor | `TomAuditAnchorVerificationJob` | class | The `@TomScheduledJob` that runs a round hourly |

## Audit Is Not Logging

The audit trail is deliberately **not** part of the diagnostic logging
subsystem (`tomLog`, `remote_logoutput.dart`). The two look similar and conflict
at every property that matters:

| | Diagnostic log | Audit trail |
| --- | --- | --- |
| Reader | An operator, now, debugging a failure | An auditor, later, reconstructing what happened |
| Retention | Days to weeks; rotated away freely | Years; deletion is a policy decision |
| Integrity | Best-effort; a lost line is a nuisance | Tamper-evident; a lost line is the failure |
| Completeness | Sampled, level-filtered, quieted in production | Every audited action, or the trail is worthless |
| Content | Whatever helps diagnose | A fixed, attributable, machine-readable shape |

Routing audit through the logger would give the trail the log's retention and
the log's integrity guarantees, which is to say none of the ones an audit needs.
So the module has its own record type, its own sinks, and its own retention.

## The Audit Record

```dart
TomAuditRecord(
  id: '...',                       // sortable, unique
  timestamp: DateTime.now().toUtc(),
  actor: TomAuditActor.fromCurrentZone(),
  action: TomAuditAction.update,
  target: 'User',                  // entity type or endpoint name
  targetKey: '42',                 // primary key, when there is one
  outcome: TomAuditOutcome.succeeded,
  requestId: '...',                // stitches the entry to its request
  before: {'email': 'a@x.com'},    // changed fields only
  after: {'email': 'b@x.com'},
  detail: null,                    // free text, e.g. the denial reason
)
```

### What "sortable, unique" means

The id is `<microseconds since epoch>-<six hex digits>`, both fields fixed-width
because sorting audit ids is a *string* sort. `TomAuditTrail.newAuditRecordId()`
mints one from a process-wide `TomAuditRecordIdGenerator`, and it is a counter
rather than a UUID because these ids are read by humans reconciling a trail: an
id that sorts in write order is worth more to them than one that is globally
unique.

The counter counts **within a microsecond** and restarts whenever the clock
advances, which is what keeps six digits sufficient — a counter that only
climbed would wrap at 16 777 216 ids and begin reissuing values that sort
*before* their predecessors, long after start-up and with nothing to connect the
two. The generator also pins the highest microsecond it has seen, so a clock
stepping backwards cannot unsort the trail; during such a correction the id's
leading field runs ahead of the wall clock, while `timestamp` — the field that
states when the action happened — is unaffected.

Uniqueness is **per process**. Two nodes writing into one trail table can mint
the same id in the same microsecond, and nothing rejects it: `entry_id` carries
no unique key, and must not, since such a key would turn a legitimate collision
into a failed insert and a failed insert here fails the audited action closed.
Identity across writers is the actor and timestamp; linearity across writers is
`writer` and its unique keys.

Timestamps are coerced to UTC. `before`/`after` are unmodifiable and carry
**only the fields that changed** — an update that touched one column does not
reproduce the whole row, because a diff an auditor can read beats a snapshot
they must compare by eye. `toJson()` emits a fixed canonical key order and omits
empty maps and nulls; the ordering is load-bearing, since the sink hashes the
encoded form.

One consequence stated outright: **an update that changes no value is still
recorded**, with an empty diff. What is audited is the *action*, not the delta.
Making the entry conditional on the data would mean that rewriting a row with
identical values left no trace, and completeness that depends on content is not
completeness.

## The Chokepoints

An audit trail that depends on each handler remembering to call it is not an
audit trail. Entries are therefore written at the two places every auditable
action already passes through:

- **The repository write path** — `TomSqlDatasourceRepository.save`, `saveAll`,
  `delete`, `deleteById`, `deleteAllById` (`object_persistence/crud_repository.dart`).
  This is where data actually changes, so it is where mutation auditing lives.
  `deleteAllById` writes one entry per row, not one per call: the unit of audit
  is the row that was destroyed.
  On a `@TomSoftDelete` entity a delete is recorded as `delete` like a hard
  one, `restoreById` as `update` and `purgeById` as `delete` (see
  [Soft delete](object_persistence.md#soft-delete)).
- **The endpoint pipeline** — `TomEndpointHandler.handleMethodCall`
  (`endpoints/endpoint_pipeline.dart`). This covers the one auditable event the
  repository cannot see, because it happens before any data is reached: a
  **denied** request. It also records declared endpoint invocations, including
  their failures.

## Declared Versus Automatic

CE-LG is explicitly "not doable purely declaratively", so the split between what
the framework does on its own and what a spec must ask for is the module's
central design decision:

| Event | Default | How to change it |
| ----- | ------- | ---------------- |
| Repository mutation (`create` / `update` / `delete`) | **Audited automatically** | `@TomAudited(enabled: false)` on the entity |
| Endpoint access denial | **Audited automatically, always** | not configurable |
| Endpoint invocation (`execute`) | Not audited | `@TomAudited()` on the endpoint method |
| Repository read | **Never audited** | not configurable — see [Reads Are Not Audited](#reads-are-not-audited) |

The asymmetry is the point:

- **Mutations are on by default** because forgetting to declare one is a silent
  gap in the record, and a gap is exactly what an audit trail exists to prevent.
  Opting out is a deliberate, visible act.
- **Invocations are off by default** because most of them are routine traffic,
  and a trail nobody can read is a trail nobody audits. Which calls matter is a
  domain judgement, so the domain declares it.
- **Denials are unconditional** because they are the entry an auditor looks for
  first, and a system that let a component opt out of recording its own refusals
  would be answering "was this attempted?" with silence.

## Reads Are Not Audited

No repository read produces a record, under any annotation. `findById`,
`findAll` and `count` reach no audit code, and `TomAuditPolicy.audits` returns
`false` for `TomAuditAction.read` whatever the entity declares.

This is a decision, not a gap. A read chokepoint has to choose between one
record per call and one per row, and neither is right: per call loses which
rows were seen, which is the only thing a read trail is for; per row turns a
thousand-row list into a thousand entries that say less than an access log.
Fail-closed then puts that write in front of every read of the entity. Those
are deployment judgements about latency and volume, and no framework default
can make them.

Two honest routes remain for a deployment that must record who looked:

| Route | What it records | When it fits |
| ----- | --------------- | ------------ |
| `@TomAudited()` on the **endpoint** | An `execute` record with the actor, at the boundary where "who asked, for what" is unambiguous | The usual answer. Reach for it first. |
| `TomAuditTrail.recordAction(action: TomAuditAction.read, …)` | Exactly what the caller says, with the target and key it chooses | Application code that knows which rows mattered and has made the volume decision itself |

`recordAction` consults no entity policy, so the second route stays open
regardless of the annotation — the caller who accepted the cost is the one who
writes the entry.

## The `@TomAudited` Annotation

```dart
@tomReflector
@TomAudited(redact: ['passwordHash'])
@TomDbTable(datasource: 'main', table: 'users', primaryKeyFields: ['id'])
class User { ... }

@tomReflector
@TomAudited(enabled: false)          // high-volume machine-written table
class SessionRow { ... }

abstract class AdminApi {
  @TomAudited()                      // this *invocation* is the auditable act
  @TomEndpoint(methods: [TomHttpMethod.post], uri: '/admin/grant')
  Future<void> grant(int userId, String role);
}
```

| Parameter | Meaning |
| --------- | ------- |
| `enabled` | `false` opts the type out entirely (default `true`) |
| `redact` | Field names whose *values* never enter the trail |

`redact` is not a column grade. A C-4 column grade hides a value from the
caller; redaction keeps it from existing in a *second* place at all — password
hashes, access tokens, keys. The record still shows that the field changed; the
values on both sides are replaced by `tomAuditRedactedPlaceholder` (`'***'`), so
"changed, and you may not see to what" stays distinguishable from "did not
change".

**An encrypted field is redacted without being named.** The repository replaces
the value of every `@TomEncrypted` field and every `@TomBlindIndex` column in
both images with `[encrypted]` (`TomFieldEncryption.redacted`) before the record
reaches the trail, so a table that keeps a field encrypted at rest does not get
a plaintext copy of it in the audit trail. The record still shows that such a
field changed; a field also listed in `redact` reads `'***'`. See
[object_persistence.md](object_persistence.md#audit-records).

Policies are resolved through the reflector once per type and cached
(`TomAuditTrail.policyFor`, `resetPolicyCache`). A type with no annotation
resolves to `TomAuditPolicy.defaultPolicy`, so mutation auditing needs no
declaration at all.

## Attribution

The actor is read from the ambient zone, not passed down through call
signatures — the repository is several layers below the request and threading a
principal through every method would be the plumbing this module exists to
avoid:

- `TomPrincipal` from the zone supplies username, user id, authentication flag,
  organization and application ids.
- The kernel's `TomRequestId` from the zone supplies `requestId`, which
  stitches every entry written during one request — or one job run, or one
  socket message read through `TomWebSocketConnection.serve` — together.

A write outside a request — a background job, a migration — is attributed to
`TomAuditActor.system` (username `SYSTEM`), never to a blank or null actor. An
unset id — the empty user id (`TomUser.noId`), the `-1` of an unset
organization or application — is normalised to `null` and then omitted, so the
trail never claims an id that does not exist. The user id is a string, unique
within the principal's tenant.

## Personal Values: Sealed per Data Subject

An append-only, hash-chained trail and a person's right to have their data
erased pull in opposite directions: an entry cannot be changed without the
chain showing it, so a person's values cannot be taken out of it afterwards. The
privacy module resolves this by **crypto-shredding** — their values are never
written in the clear in the first place (see
[privacy.md](privacy.md#crypto-shredding-in-the-audit-trail)).

`recordMutation` takes, beside `before` and `after`, `beforeSubjects` and
`afterSubjects`: a field name mapped to the id of the data subject its value
belongs to. The repository fills them for an entity's `@TomPersonal` fields
from the subject column of the row (`TomPersonalDataModel.sealingSubjects`).
When `TomAuditTrail.personalValueSealer` is installed —
`TomPrivacy.installSubjectKeys` sets it to `TomSubjectKeys.seal` — each such
value is replaced, after redaction and before the record is written, by its
sealed form: `tomsubj:v1:<subject>:<ciphertext>`, AES-256-GCM under a key of
that subject alone. A `null` and a redacted value (`***`, or `[encrypted]` for
an encrypted column) are left as they are. The chain hashes the sealed text.

Erasing the subject deletes their key. Every entry stays exactly as written, so
`verify()` still holds and an anchor published before the erasure still
matches; the sealed values simply cannot be opened any more.
`TomPrivacy.reveal(record)` opens them for an auditor while the key exists and
shows `[erased]` once it does not.

With no sealer installed — the default — personal values are recorded as they
are, and an erasure cannot reach them in the trail. A value the sealer cannot
seal fails `recordMutation`, and with it, the trail being fail-closed, the write
it audits. What sealing does not cover — the actor, the target key, the field
names, `recordAction` records and their `detail` — is listed in
[privacy.md](privacy.md#what-stays-as-it-is).

## Sinks, Persistence and Retention

`TomAuditSink` has three implementations:

- **`TomMemoryAuditSink`** — bounded ring (default 1000 entries) with a
  `droppedCount`. For tests and short-lived processes.
- **`TomFileAuditSink`** — append-only JSON Lines under a directory, one file
  per **UTC** day (`audit-<yyyy-mm-dd>.jsonl`), rotated at `maxFileBytes`
  (default 16 MiB). UTC because the entries themselves are: a file named from
  the host's local calendar disagrees with its own contents on any host that is
  not on UTC, so the day an incident report names is not the file it is in.
  Grep the UTC day. Writes are serialised
  through an internal queue so concurrent callers cannot interleave, and the
  head hash is recovered from disk on reopen, so a restart continues the chain
  rather than starting a new one.
- **`TomSqlAuditSink`** — one row per entry in a `TomDataSource`. Same
  serialised queue and same head recovery; see [The Relational
  Sink](#the-relational-sink).

Retention is expressed in the unit each sink can delete without breaking the
chain. `TomFileAuditSink` deletes **whole files** — entries older than
`retention` (default 3650 days ≈ 10 years) and files beyond `maxFiles` (default
512). `TomSqlAuditSink` deletes **a contiguous prefix of rows**, via
`purgeBefore(instant)` or `purgeToMaxEntries(n)`. Both leave a valid *suffix* of
the chain, which still verifies; removing an interior entry would break it and
be indistinguishable from tampering.

**But only one of the two sinks retains anything by itself.** `TomFileAuditSink`
applies its own retention, on every open and rotation, so a deployment that sets
`retention` and `maxFiles` has nothing further to do. `TomSqlAuditSink` applies
**none**: nothing in the framework calls `purgeBefore` or `purgeToMaxEntries`,
and a trail table grows without bound until the deployment schedules one of
them. The intended home for that call is the **scheduler** — `TomScheduler` /
`@TomScheduledJob` from `tom_core_kernel`, where a purge sits naturally beside
the rest of a deployment's nightly housekeeping and where being idempotent (as
both purges are) is what the at-least-once guarantee asks for.
`tom_core_samples/advanced_ops_server` has the pattern in `OpsPurgeJob`, cutoff
computed from the run's `scheduledFor` rather than `DateTime.now()`.

The asymmetry is not an omission on either side. A file sink owns its directory
and may delete in it; a trail table is pruned with a `DELETE` grant that the
credential serving the sink [should not hold](#the-write-once-story) — and if
the deployment installed the `BEFORE DELETE` guard trigger, the purge is blocked
outright. Retention on the relational sink is therefore an *operator* action,
scheduled and credentialed as such, rather than something the sink can do
quietly on its own behalf.

Two things a scheduled purge must get right. Both purges are scoped to the
sink's `writer`, so in a clustered deployment one job trims one node's chain —
run it on every node, or give a single job a sink per writer, or the table keeps
growing while the job reports success. And this is *not* the anchoring case: an
anchor is published per process and is deliberately [kept off the
scheduler](#why-the-publisher-is-not-a-scheduled-job), whereas a purge is
housekeeping over rows already written and belongs on it.

Retention never moves an entry's `index` or a sink's `entryCount`: both are
counted from genesis, so a pruned trail still knows *where* its survivors sat.
That is what lets [anchor verification](#anchoring-the-chain-head) tell a
retention sweep apart from a rewrite.

Rotation sequence numbers are monotonic and never reused, including after
retention has deleted the file that held one — a reused number would let a new
file take an older file's name, and read-back order would stop matching write
order.

### Reading a trail back is per sink, deliberately

`TomAuditSink` declares a writer's surface — `write`, `headHash`, `entryCount`
and `close` — and reading entries back is not among them. Each
implementation exposes read-back separately instead, in the shape its storage
actually has:

| Sink | Read-back | Verification |
| --- | --- | --- |
| `TomMemoryAuditSink` | `entries`, `records` (getters) | `TomAuditChainVerification verify()` |
| `TomFileAuditSink` | `List<TomAuditEntry> readAll()` | `TomAuditChainVerification verify()` |
| `TomSqlAuditSink` | `Future<List<TomAuditEntry>> readAll()` | `Future<TomAuditChainVerification> verify()` |

So `verify()` is synchronous on two sinks and asynchronous on the third, and
that is not an inconsistency to be tidied away. Uniforming the three would have
to pick the asynchronous signature for all of them, and would put `readAll()`
on the interface — advertising a whole-table read of a ten-million-row trail as
an ordinary call.

Nothing is lost by the omission, because the analysis is storage-neutral
already: `verifyAuditChain`, `verifyAgainstAnchor` and `filterAuditEntries` take
a `List<TomAuditEntry>`, not a sink. An operator reads the trail back the way
their storage is read, and hands the entries to the same checker — or the same
filter — whichever sink produced them. See [Querying the
Trail](#querying-the-trail) for the one place that arrangement does not hold,
and why.

The one cross-sink read the module itself performs *is* on the interface:
`TomAuditAnchor.of(sink, ...)` needs `headHash` and `entryCount` from whatever
sink is installed, without knowing its concrete type, and gets them.

## The Relational Sink

```dart
TomAuditTrail.install(
  TomSqlAuditSink.named(
    'audit',                  // its own data source, not the application's
    writer: 'app-node-1',     // names this chain
    createSchema: false,      // the migration owns the table
    requireWriteOnce: true,   // refuse to start if the grant is wrong
  ),
);
```

One row per entry in `tom_audit_trail` (`auditTrailTableDdl`), holding the
projection columns an operator searches by — actor, action, target, outcome,
`recorded_at` — plus the two chain columns and the canonical record JSON. The
**record text is authoritative**: it is exactly what was hashed, so a row
verifies against its own hash without the reader reproducing the encoding. The
projection columns are a lossy index, truncated to fit rather than allowed to
fail an insert, because the trail is fail-closed and a rejected row would take
the audited action down with it. Reading the rows back runs the other way: a row
whose record text will not parse is a finding, not a gap to paper over, and is
raised as `audit.sql.malformed_record` naming the table, the writer and the
row's hash.

`TomSqlAuditSink.named` looks its data source up when the sink is built and
refuses a name nobody registered with `audit.sink.unknown_datasource`.

Four design points are worth stating outright:

- **It does not go through `TomSqlDatasourceRepository`.** The repository is
  itself an audit chokepoint, so a repository-backed sink would audit its own
  writes and each entry would produce another. The regress could be broken with
  `runUnaudited`, but a bypass holds only as long as every write path remembers
  to wrap itself. Talking to the data source directly makes the regress
  impossible rather than merely avoided.
- **`writer` is required.** Each entry hashes its predecessor, so a chain has
  exactly one head; two processes appending to one table with one chain would
  interleave into a sequence that fails its own verification. A per-node chain
  makes a clustered deployment correct, and `UNIQUE (writer, previous_hash)`
  turns a fork into a duplicate-key error at insert time instead of silent
  corruption found at the next audit.
- **`seq` is the primary key.** Nothing addresses an audit row by anything else,
  while insertion order is load-bearing twice: it is the order the chain is read
  back in, and it is the axis retention trims a prefix from. Retention resolves
  its cutoff to a *sequence* boundary before deleting anything —
  `DELETE ... WHERE recorded_at < :cutoff` looks equivalent and is not, because
  timestamps come from the record and sequence numbers from the insert, so
  clock skew is enough to leave an older-stamped row after a newer-stamped one
  and deleting by timestamp would punch a hole.
- **`entry_id` carries no key at all**, unique or otherwise. A record id is
  unique per process, so a unique key there would turn a legitimate collision
  between two writers into a failed insert — and a failed insert fails the
  audited action closed. The row is addressed by `seq`; identity across writers
  is the actor and timestamp.

Reference migrations live in `example/audit/migrations/main/tomcore/`, and their
PostgreSQL form, generated from them, in
`example/audit/migrations_postgresql/main/tomcore/` (see
[db_migration.md](db_migration.md#reference-migrations-for-postgresql)). The
table itself is declared **once**, as the `auditTrailTable(name)` descriptor in
`sql_audit_sql.dart`: the `CREATE TABLE` the sink issues (`create`, in the
connected database's words), its entry `INSERT` and
the column list of every read are all derived from it, and
`test/framework_schema_test.dart` compares that declaration against the shipped
migration, the reflected row type and every statement the sink issues — see
[Schema Convergence](db_migration.md#schema-convergence). The guard functions
are separate on purpose: they are a *grant* posture, not a column declaration,
and are what the write-once story below rests on.

## The Write-Once Story

`TomFileAuditSink` is append-only *by construction* — the only file operation it
performs is "append a line", and rotation renames rather than rewrites. A table
has no such property: `UPDATE` and `DELETE` are ordinary statements. A trail
stored in one is append-only only because something outside the code says so,
and **that something cannot be the code**: the grant is the guarantee, and a
grant is not a thing a library can hold.

This framework takes the first of the three available postures, and provides
mechanism for the second:

| Posture | What makes it write-once | When it is right |
| ------- | ------------------------ | ---------------- |
| **Separate credential** (adopted) | The serving user holds `INSERT` and `SELECT` on the trail table and nothing else | Any deployment that can issue a second credential — which is nearly all of them |
| **Database-side guard** | `BEFORE UPDATE` / `BEFORE DELETE` triggers that refuse the statement — `SIGNAL SQLSTATE '45000'` on MariaDB, `RAISE EXCEPTION` from a trigger function on PostgreSQL | A deployment that cannot separate credentials: one application user, one schema, `UPDATE` already granted across it |
| **Explicit acceptance** | Nothing. The trail is tamper-*evident* only | Development and test, where operational convenience genuinely outweighs tamper-resistance — and stated as such, never assumed |

None of the three detects a rewrite performed *with* the credential that is
permitted to write. That is what [anchoring](#anchoring-the-chain-head) is for,
and the two are complementary: the grant makes the rewrite hard, the anchor
makes it visible.

**The separate credential is the primary mechanism.** Apply the migration with a
privileged credential, then serve the trail with a restricted one:

```sql
-- MariaDB
CREATE USER 'audit_writer'@'%' IDENTIFIED BY '…';
GRANT INSERT, SELECT ON app_db.tom_audit_trail TO 'audit_writer'@'%';

-- PostgreSQL
CREATE ROLE audit_writer LOGIN PASSWORD '…';
GRANT INSERT, SELECT ON tom_audit_trail TO audit_writer;
```

Configure that credential as the sink's **own** data source — never the
application's, which by definition can modify everything it can read. The sink
takes an explicitly named `TomDataSource` and never defaults to one, so the
restricted credential has somewhere to live.

**The triggers are defence in depth, not the mechanism.** They ship as two
environment-tagged migrations (`[2]-…@hardened.sql`,
`[3]-…@immutable.sql`) and are deliberately not part of the default chain: a
deployment whose serving credential already lacks `UPDATE` gains nothing from
them, and applying them needs `TRIGGER` rights a locked-down schema owner may
not wish to exercise. They are also not a *guarantee* — a connection holding
`SUPER` or `TRIGGER` can drop them. Where they earn their place is the
deployment that cannot separate credentials at all: there the grant cannot
express "append-only" and a trigger can.

`auditTrailGuardStatements(table, dialect, event: 'UPDATE' | 'DELETE')` renders
a guard for the dialect's database (through the dialect's `rejectingTrigger`):
one `CREATE TRIGGER … SIGNAL SQLSTATE '45000'` on MariaDB, and on PostgreSQL a
PL/pgSQL trigger function raising the same message plus the `BEFORE` row
trigger that calls it. The message is `audit trail is append-only: <event> is
not permitted` on both. `auditTrailNoUpdateTriggerDdl` and
`auditTrailNoDeleteTriggerDdl` are the MariaDB text of the two, which the
canonical migrations carry; the PostgreSQL migrations carry the translated form.

The two guards are tagged separately because they cost differently. The `UPDATE`
guard costs nothing. The `DELETE` guard **blocks retention entirely** — both
`purgeBefore` and `purgeToMaxEntries` issue `DELETE` — so installing it is a
decision to keep the trail forever, or to prune out of band with a role that
drops the trigger, prunes, and recreates it.

### Retention is an operator action

The restricted serving credential has no `DELETE`, which is the point — and it
means **retention cannot be run by the server that writes the trail**. Calling
`purgeToMaxEntries` on a correctly restricted sink fails, loudly, which is the
right outcome and a surprising one to meet for the first time in production. A
negative `maxEntries` is refused before any statement is issued, with
`audit.retention.negative_limit`.
Pruning is an operator task performed with a separate, privileged credential.

### What the sink checks, and what it does about it

`verifyWriteOnce()` observes the deployment rather than trusting its
configuration, and returns a `TomAuditWriteOnceCheck`. It makes two independent
observations, because neither alone is conclusive:

- a **privilege** probe — an `UPDATE`/`DELETE` restricted to no rows, which
  still fails at permission-check time when the grant is missing; and
- a **trigger** probe of `information_schema.TRIGGERS` in the connection's
  current schema (the dialect's `currentSchema`), because a zero-row
  statement matches nothing and therefore fires no `FOR EACH ROW` trigger. A
  trigger-protected table looks perfectly mutable to the privilege probe alone.

`open()` runs the check and, when the table can be rewritten in place, either
**warns** or — with `requireWriteOnce: true` — **refuses to start**, with
`audit.sql.not_write_once`. The default
is the warning: a sink that refused to start on a developer machine would push
people towards installing no sink at all, and an unprotected trail is still
better than no trail. A deployment that has made the arrangement should set the
flag, because a silently mis-granted credential is precisely the failure it
exists to catch.

## Tamper Evidence

Each entry stores the previous entry's hash, and its own
`sha256('$previousHash|${jsonEncode(record.toJson())}')`. The chain starts at
`tomAuditGenesisHash` (64 zeros). Each entry also carries its `index`: its
position in the chain counted from genesis, which is *not* the same number as
its offset in whatever a reader happens to hold once retention has pruned a
prefix.

Each sink's own `verify()` is a convenience over one function — it reads that
sink's entries back and calls `verifyAuditChain` on them — which is why its
signature differs per sink; see [Reading a trail back is per
sink](#reading-a-trail-back-is-per-sink-deliberately).

`verifyAuditChain(entries)` returns a `TomAuditChainVerification` naming the
offset at which a chain first breaks, and distinguishes three failures because
they mean different things:

| Detail | What happened |
| --- | --- |
| `content changed` | an entry's record no longer matches its own hash — it was edited in place |
| `link mismatch` | an entry was removed, inserted or reordered here |
| `chain renumbered` | the indexes jump — someone rewrote positions |

The index check is not redundant. The index deliberately sits **outside** the
hashed payload, so that adding it did not invalidate every digest already
written — which makes it the one field an attacker can change without breaking a
hash. Left unchecked, renumbering would slide the window an anchor is compared
against.

### What the chain alone cannot see

Two attacks survive a perfect chain, and it is worth naming them precisely
rather than describing the chain as "tamper-evident" and leaving it there:

- **A wholesale rewrite.** Edit an entry, then recompute every hash from that
  point on. The result verifies. Internal consistency is a property a forger can
  restore.
- **A truncation.** Delete entries from the *end*. What remains is a valid
  chain, shorter. Nothing inside the trail records how long it was supposed to
  be.

Both are closed by anchoring.

### A damaged entry is not a tampered one

The three findings above are accusations, and a reader that fills in a field it
could not find manufactures one. So `TomAuditEntry.fromJson` defaults nothing —
an absent, mistyped or empty `index`, `hash`, `previousHash` or `record` raises
`TomAuditException` and the line is refused, each field with its own key —
`audit.entry.missing_index`, `audit.entry.missing_hash`,
`audit.entry.missing_previous_hash` and `audit.entry.missing_record`:

- a defaulted `hash` reads back as an entry whose hash does not match its
  contents, reported as **content changed** — the trail says a record was
  edited when in fact a field went missing, and the investigation starts in the
  wrong place;
- a defaulted `previousHash` claims the entry began a chain. Mid-chain that is a
  **link mismatch**; at the head it is no finding at all, because the entry is
  self-consistent against the link it was handed. Damage verifies as health,
  which is the direction that costs the guarantee rather than merely
  misdirecting.

`parseAuditLines` wraps the refusal as `audit.parse.malformed_line` with the
line number, so its promise — anything unreadable is reported — now covers the
whole entry rather than only its JSON syntax. Head recovery in
`TomFileAuditSink` benefits from the same rule: a final line that parses as
JSON but has lost a chain field is treated exactly like a half-written one, so
the sink falls back to the previous file instead of adopting an empty hash and
linking every subsequent entry onto it.

The relational sink needs no equivalent guard: `previous_hash` and `hash` are
`CHAR(64) NOT NULL` in the shipped DDL, so the database refuses what the file
format cannot.

## Anchoring the Chain Head

An anchor is a claim — *chain `writer` had `entryCount` entries whose head was
`headHash`, at `createdAt`* — published somewhere the audited server does not
control. `TomAuditAnchorPublisher` writes one on a schedule; `verifyAgainstAnchor`
later checks the trail against it.

```dart
final sink = TomSqlAuditSink(auditDatasource, writer: 'node-a');
TomAuditTrail.install(sink);

final publisher = TomAuditAnchorPublisher(
  sink: sink,
  store: TomFileAuditAnchorStore(directory: Directory('/mnt/worm/anchors')),
  writer: 'node-a',
  signer: TomRsaAuditAnchorSigner(privateKey: anchorKey, keyId: 'audit-2026'),
  interval: const Duration(hours: 1),
);
await publisher.start();
```

Checking, later and ideally from somewhere else:

```dart
final result = verifyAgainstAnchor(
  await sink.readAll(),
  (await store.latest('node-a'))!,
  writer: 'node-a',
  verifier: TomRsaAuditAnchorVerifier({'audit-2026': anchorPublicKey}),
);
if (result.indicatesTampering) alert(result.detail);
```

### What the result distinguishes

`TomAuditAnchorVerification.status` is the substance of the check. The three
groups it falls into — `isMatch`, `indicatesTampering`, `isInconclusive` — are
what an operator alert should key on, not the enum directly.

| Status | Group | Meaning |
| --- | --- | --- |
| `matched` | match | intact and ends exactly where the anchor says |
| `extended` | match | intact, agrees at the anchored position, has grown since — the ordinary live state |
| `diverged` | **tampering** | intact but the anchored position hashes differently: **the wholesale-rewrite signal** |
| `truncated` | **tampering** | intact but stops short of the anchored position: entries removed from the end |
| `chainBroken` | **tampering** | the chain fails its own verification, so the anchor was not consulted |
| `signatureInvalid` | **tampering** | the anchor is unsigned, signed by an unknown or wrong key, or the verifier failed to answer |
| `beforeRetention` | inconclusive | the anchored position was pruned; nothing left to compare |
| `writerMismatch` | inconclusive | the anchor describes a different chain |

Only one status comes back, and these conditions routinely fail together — an
anchor for the wrong chain will not hash-match either, so it fails the chain
check as well. The checks therefore run in a fixed order, **writer, then
signature, then chain validity, then position**, and the first failure is the
one reported. The order is most-specific-first: it names the mistake that was
actually made rather than a consequence of it, so an operator told
`writerMismatch` fixes the query instead of investigating a rewrite that never
happened. The chain's own verification is computed regardless and is always
available on `TomAuditAnchorVerification.chain`, whichever status is returned.

`signatureInvalid` counts as tampering because a forged anchor and a
misconfigured key are indistinguishable from the verifier's side, and treating
the ambiguity as "fine" means the check has silently stopped checking.

The same reasoning covers a verifier that **throws**. `TomAuditAnchorVerifier`
is an interface a deployment implements, and the implementations worth having —
an HSM, a KMS — fail in ways a pure-Dart one does not: expired sessions,
timeouts, key material that will not parse. `verifyAgainstAnchor` catches those
and reports `signatureInvalid` rather than letting them out of a function
documented as returning one of eight statuses, and puts the exception in
`detail` so the fault is legible as infrastructure rather than as forgery.
Implementations should still answer `false` instead of throwing; the guard is
there because the checker cannot verify that they do.

`beforeRetention` is the one that needs a policy decision. **If your deployment
does not prune, treat it as a finding** — it means the entries an anchor
counted are gone.

### Retention does not raise a false alarm

This is what the stored `index` buys. After `purgeToMaxEntries(3)` on an
eight-entry chain the survivors still know they are entries 5–7, so an anchor
taken at entry 8 lands inside the retained window and reads `matched`. If the
anchored entry itself was pruned but the oldest survivor still *links* to it,
that link is checked — the one position retention leaves checkable is not
written off. Only when the anchor sits further back than that does the result
become `beforeRetention`.

### What anchoring actually guarantees

Signing and publication defend against **different** adversaries, and conflating
them is how a scheme ends up being ceremony:

- **Publication** — writing the anchor where the server cannot reach it
  afterwards — is what stops the server from revising its own history. Without
  it, an attacker who owns the server owns the anchors and rewrites both.
- **A signature** is what stops whoever holds the *store* from inventing an
  anchor the server never issued, or laundering a real divergence away.

So a signing key held on the machine it attests to adds nothing against
compromise of that machine — it defends the store, not the chain. The guarantee
is exactly: **given an anchor that reached a store the attacker cannot rewrite,
a wholesale rewrite or a truncation of the trail is detectable.**

Where that store lives is the deployment's decision and the framework does not
pretend to make it. `TomFileAuditAnchorStore` writes JSON Lines to a directory;
whether that directory is a WORM mount, an append-only share, or the
application's own scratch space is what determines whether anything has been
anchored at all. `TomMemoryAuditAnchorStore` is for tests and anchors nothing —
it dies with the process it was attesting to.

The file store names a file after the writer, sanitising the name so a writer
called `../../etc` cannot escape the directory. That sanitisation is lossy —
`node/a` and `node_a` land in the same file — so `read` filters on the writer
recorded inside each anchor rather than trusting the file it found it in. This
matters because `latest` feeds the routine check above: an anchor from another
chain reads as tampering when its position is ahead of the trail, and as
`beforeRetention` when it is behind, which is no finding at all and would let a
genuine rewrite pass unexamined. Any custom store owes the same guarantee —
group anchors however you like, but filter on what the anchor says it is.

There is deliberately **no SQL anchor store**. Anchoring the trail into the same
database that holds it is one credential and one blast radius: ceremony without
a guarantee.

**No external store ships in this package, and none will.** That is a decision,
not a gap waiting to be filled. An S3 anchor store's guarantee is not in its
code: it is in the bucket's object-lock mode, its retention period, and a
credential that cannot delete — none of which the class can see. A type called
`TomS3AuditAnchorStore` would read like a guarantee over configuration that may
supply none, which is the exact failure this section is about, dressed as its
remedy. The seam is the deliverable. A deployment implements
`TomAuditAnchorStore` against what it has actually arranged, in its own package,
where the arrangement and the code can be reviewed together.

### The posture is declared, and never believed

Since the framework cannot check independence, it does the next best thing:
`TomAuditAnchorStore.independentOfServer` makes the posture a stated fact.

```dart
TomFileAuditAnchorStore(
  directory: Directory('/srv/anchors'),
  independentOfServer: true,   // the deployment's assertion, not a check
)
```

It **defaults to `false`**, and that default is the whole point. The question is
not "is this store independent" — nothing here can answer that — but "has anyone
said it is", and a store nobody asked must answer no. Without it, a deployment
anchoring into its own writable tree gets a dashboard reading *anchored* with
nothing anywhere recording that the anchors are as rewritable as the trail.
`TomMemoryAuditAnchorStore` answers `false` as a fact rather than a default:
it lives in the process it attests to, so no arrangement could change it.

Two places surface it, and neither acts on it:

```dart
publisher.describe();
// audit anchors -> file:/srv/anchors (NOT declared independent of this
// server — this is a copy, not an anchor; chain "app-node-1")

(await monitor.verifyAll()).toString();
// audit anchors verified: 1 chain(s), no findings
// (store file:/srv/anchors, NOT independent of this server)
```

`TomAuditAnchorReport` carries `storeDescription` and `storeIsIndependent`, and
`isClean` is computed without consulting either. That separation is deliberate:
a flag becomes the config flag that pretends the moment something turns green
because of it. A round verifies a chain against the anchors it was given; whether
those anchors sat somewhere the same attacker could rewrite is a different
question, which the report states and does not answer.

### Why the publisher is not a scheduled job

`TomScheduler` runs a job once *across the cluster*, which is exactly wrong
here. The chain is per `writer` precisely so several nodes may append to one
table, so each node must anchor its own head. A cluster-single-fire publisher
would anchor one node, leave the rest unanchored, and report that everything was
covered.

Every tick publishes, even when nothing was written: an anchor over an unchanged
head says *the head was still this at time T*, which bounds when a later
divergence must have happened. At a couple of hundred bytes an hourly publisher
costs about two megabytes a year.

**Worked example.** `advanced_ops_server` in the samples suite runs three
scheduled jobs *and* this publisher in one process, so the difference is visible
rather than asserted in prose: `test/ops_anchor_test.dart` checks the publisher's
own timer and that **no `@TomScheduledJob` declares it**, which is the shape of
the mistake this section exists to prevent. See
[`README_advanced_14_operations.md`](../../tom_core_samples/README_advanced_14_operations.md).

### Reading the anchors back

Publishing an anchor detects nothing on its own. `TomAuditAnchorMonitor` is the
other half: it takes the chains a deployment expects to exist, reads the latest
anchor published for each, and checks the chain against it — and
`TomAuditAnchorVerificationJob` is a `@TomScheduledJob` that runs the round
hourly.

```dart
final monitor = TomAuditAnchorMonitor(
  store: anchorStore,
  chains: [
    TomAuditWatchedChain(writer: 'node-a', read: nodeASink.readAll),
    TomAuditWatchedChain(writer: 'node-b', read: nodeBSink.readAll),
  ],
  verifier: anchorVerifier,
  onFinding: (finding) => outbox.alertOperator(finding.detail),
);
TomBean.withName(tomAuditAnchorMonitorBean, monitor);
```

**Verification is a scheduled job where publication is a timer, and the reason
is the same one.** Publication is per writer because each node must anchor its
own head. Verification is a *read* over a chain that already exists: it
concludes the same thing whichever node asks, and it is idempotent, which is
what the scheduler's at-least-once guarantee wants. Running it on every node
would multiply the read cost and the alerts by the cluster size for no extra
coverage.

**The writers are declared, not discovered.** Enumerating them from the anchor
store would find only the writers that have published at least once — so a node
that never anchored would be invisible, and that silence is exactly the finding:
an unanchored chain is the one a rewrite leaves no evidence of. A declared chain
the store has nothing for is reported as `neverAnchored`.

**The chain is read through a callback** the deployment supplies, because
[reading a trail back is per sink](#reading-a-trail-back-is-per-sink-deliberately)
and a generic monitor would have to invent the interface that section
deliberately withholds. `TomSqlAuditSink.readAll` is the usual answer.

**A finding reaches two places, and both ship.** Every one is logged at error
level, and every one is handed to `onFinding` — the log being the channel that
always exists and the callback the one that can act: route to the messaging
outbox, fail a health check, page somebody. Which of those is right is a
property of the deployment, so the framework does not choose.

| Outcome | `isFinding` | `isClean` | Reaches `onFinding` |
| ------- | ----------- | --------- | ------------------- |
| `matched` / `extended` | no | yes | no |
| `diverged` / `truncated` / `chainBroken` / `signatureInvalid` | yes | no | yes |
| `beforeRetention` / `writerMismatch` | no | no | no |
| `neverAnchored` / `readFailed` | yes | no | yes |

The inconclusive row is the one worth arguing. A deployment that prunes reaches
`beforeRetention` on every ordinary run, so alerting there would train the
operator to ignore the channel a real divergence arrives on. It is still not
*clean* — `isClean` requires a verification that matched — so a dashboard can
show the difference between "checked and intact" and "could not conclude"
without either of them being an alert.

**The run reports the round, not the verdict.** A diverged chain does not fail
the job: `TomRetryPolicy` would retry it, the second attempt would reach the same
answer, and the retries would burn the alerting budget without changing
anything. A deployment that wants the run itself to fail throws from
`onFinding`, which propagates out of `verifyAll` — and because the callbacks run
only after every chain has been checked and logged, aborting there abandons the
reporting rather than the checking.

Because the job ships in the framework and carries `@tomReflector`, it is in the
reflection build of every application that reflects `tom_core_server`, including
ones that anchor nothing. Those get a run that reports `no audit anchor monitor
registered` rather than an hourly failure; an application that does not want the
job at all excludes it with `TomScheduledJobs.discover`'s `where` filter.

`test/audit_anchor_monitor_test.dart` covers the three shapes this layer adds
over a single `verifyAgainstAnchor` call — the declared-but-never-anchored
chain, the read that throws, and the routing — including that an inconclusive
check reaches neither the findings nor the callback, and that a throwing
callback propagates only after every chain has been checked.

An anchor is held to the same rule as an entry. `TomAuditAnchor.fromJson`
refuses one that lacks its writer, entry count, head hash or creation time with
`audit.anchor.malformed`, and `TomFileAuditAnchorStore` reports an anchor-file
line that does not read as an anchor as `audit.anchor.malformed_line`, naming
the file and the line — the archive is the thing that is supposed to be
unedited, so a damaged line in it is a finding rather than something to skip.

### Shutting the publisher down

The final anchor of a graceful shutdown is the one that pins the chain's last
head; without it every entry written since the previous tick stays unanchored.
`close()` delivers it: it stops the schedule, publishes one final anchor, and
completes once that anchor is in the store. A store failure is thrown — the
caller asked for a publication and is entitled to learn it did not happen — and
the publisher is closed either way. Every call is handed the same close, so a
shutdown that reaches the publisher twice publishes one final anchor, not two.
After that, `publishNow` throws `audit.anchor.publisher_closed`: an anchor
claims that the process was watching the chain at that moment, which a closed
publisher no longer is.

Because `close()` is `TomClosable`'s method, a publisher registered with the
shutdown cleanup is awaited like any other closable, within the phase's budget.

Order matters when the sink is queued. Anchor **after** draining the sink, not
before — an anchor is a claim about a *position*, so one taken first pins the
head as it stood before the records the drain went on to store, leaving them
outside the anchored range. That is the one place a truncation is invisible.
Closables close in registration order, so register the sink ahead of its
publisher. `advanced_ops_server`'s `OpsRuntime.close` is the worked example:
stop the timers, uninstall the trail, close the sink, *then* close the
publisher.

## Failure Behaviour

The trail is **fail-closed**: if the sink cannot store a record, the audited
action fails. A `TomAuditException` from the sink propagates out of the
repository or endpoint call rather than being swallowed. An action that
completed without leaving a record is precisely the outcome the trail exists to
make impossible, so the framework prefers to refuse the action.

With **no sink installed** the trail is a no-op — `TomAuditTrail.record`
returns immediately and every chokepoint behaves as if the trail were not
there. Auditing is
switched on by installing a sink at startup:

```dart
TomAuditTrail.install(TomFileAuditSink(directory: Directory('/var/audit/app')));
```

### Every failure arrives on the returned future

`write` returns a `Future`, and **every** way it can fail completes that future
with an error — including the failures a sink can see before it has done any
work, such as being closed. None of them is thrown from the call itself.

This is a contract about where to put the handler, and getting it wrong is
silent. A caller who awaits inside a `try` is safe either way, which is why the
distinction goes unnoticed; a caller who does anything else is not:

```dart
// All three are complete handling of a future's failure. None is in a `try`.
unawaited(sink.write(record).catchError(reportAuditFailure));
await Future.wait([for (final r in batch) sink.write(r)]);
final pending = sink.write(record); // handled by whoever awaits it later
```

A `write` that could also throw before returning its future would make each of
these a coin flip on *which* failure occurred. The one that escaped would
escape onto whatever stack was running, and for a fail-closed trail that turns
"your record was not stored, decide what to do" into an uncaught error in the
middle of the audited action — a worse outcome than the storage failure it is
reporting. Implementations therefore mark `write` `async` rather than raising
from the synchronous part of the body, so the rule lives in the declaration and
a guard added later inherits it.

The same reasoning applies to failures arriving **twice**. `File.openWrite` is
lazy, so a path the file sink cannot open reports the failure both on the flush
the sink awaits — which becomes the caller's `audit.sink.write_failed` — and on
the file handle's own completion, which has no listener. The sink closes the
broken handle to consume that second copy; without it, a caller who handled the
failure exactly as documented would still see an unhandled asynchronous error
for it. Closing also drops the handle, which is what lets the sink resume
recording once the directory it died on is repaired, rather than failing
against a dead handle for the life of the process.

### Shutting a sink down

Both persistent sinks serialise their writes through an internal queue, so at
the moment of shutdown there may be a record that a caller has submitted and the
sink has not yet stored. `close()` waits for it: the sink closes to new records,
waits for the queued ones to be stored, and only then releases the file or
returns. A shutdown that awaits the close — this is `TomClosable`'s method, so
a sink registered with the shutdown cleanup is awaited within its phase's
budget — therefore has every record submitted before it in the trail.

A record submitted *after* the call is refused. The queue has to stop growing
for the drain to have a point to reach while a caller keeps writing, and that
leaves three possible answers for the late record, of which only one is honest:

- **Write it anyway.** A sink that is closed is still writing — for the file
  sink, reopening the file it is closing, behind the back of the code that
  closed it.
- **Drop it.** An audited action reports success with no entry behind it —
  precisely the outcome a fail-closed trail exists to prevent.
- **Refuse it.** The record's `write` future completes with
  `audit.sink.closed`, and the caller — which is the code that knows whether the
  action may still be allowed to stand — is told.

Every call is handed the same close, so a shutdown that closes the sink twice —
the registered `TomClosable` and the application's own teardown — waits for the
one drain both times and reopens nothing.

**All three sinks answer the same way.** `TomMemoryAuditSink` has no queue —
`write` has stored the entry by the time its future completes — so it has
nothing to drain, but a write submitted after `close()` is refused
with the same `audit.sink.closed`. That is deliberate rather than incidental:
the refusal is a promise of `TomAuditSink`, and a caller holding the interface
cannot ask which implementation it got. A lenient memory sink would be the worse
direction of that disagreement, because it is the sink a suite substitutes for a
real one — a shutdown path exercised against it would pass in the test and
refuse in production.

Closing ends the writing, not the reading: `entries`, `records`, `verify()`,
`headHash` and `entryCount` keep answering afterwards, which is what makes a
closed memory sink still useful as the subject of an assertion.

```dart
final sink = TomFileAuditSink(directory: Directory('/var/audit/app'));
TomAuditTrail.install(sink);

// Graceful teardown: nothing submitted before this line is refused.
await sink.close();
```

## Suppressing the Trail

`TomAuditTrail.runUnaudited(body)` runs `body` in a zone carrying a
`TomAuditBypass`, so nothing inside it is recorded. It exists for one purpose:
letting the trail's own machinery persist without auditing itself into an
infinite regress. It is not a general opt-out — the declaration-based
`@TomAudited(enabled: false)` is, precisely because it is visible in the source
and therefore auditable in its own right.

## Verification

Eight suites carry the module's name, three of which need a server.

`test/audit_error_keys_test.dart` pins the module's error vocabulary: each case reaches a raise with a real input and asserts the exact key, so a key the module stops raising, or raises for a different condition, fails by name. None needs a database.

`test/audit_test.dart` is the largest and always runs: `TomAuditActor`
attribution, `TomAuditRecord` and the normalisation of before/after values to
what `jsonEncode` accepts, `auditDiff`, the declared-versus-automatic split
`TomAudited` expresses and its resolution through the reflector, `TomAuditEntry`
and the hash chain — including that the chain fields are required rather than
defaulted — and the memory and file sinks, with the rule that every sink reports
a failure through the future it returns rather than throwing past its caller.

`test/audit_anchor_test.dart` covers the anchors: `TomAuditAnchor`, the
self-description for any head hash, `verifyAgainstAnchor` and what it does with a
verifier that throws, the precedence when several checks fail at once, RSA
signing, both anchor stores — including writers whose names collide after
sanitisation — and the publisher with its close path.
`test/audit_anchor_monitor_test.dart` covers the monitor above them: its
ordinary states, its findings, the round, the seam a deployment substitutes, the
verification job and `TomAuditAnchorCheck`.

`test/audit_query_test.dart` covers the storage-neutral half of querying:
`TomAuditQuery.matches` judging a record field by field and as an *and*, the
half-open window, `filterAuditEntries` with its order, its limit counted in
matches rather than rows, and `auditProjectionPrefix` against the widths the
trail table declares.

`test/audit_sql_test.dart` reads the source tree: the migration files match the
shipped DDL, the trail schema encodes the invariants the chain relies on, and the
guard triggers reject rather than silently ignore.

The questions an auditor asks of the trail across its writers, and their
scheduled deliveries, are the [audit_reports](audit_reports.md) module's to
test: `test/audit_reports_test.dart` without a database, and
`test/audit_reports_db_test.dart` against the relational trail of two writers.

The sealing of personal values is the privacy module's to test:
`test/privacy_test.dart` records a mutation through a memory sink with subject
keys installed and without, reveals it, shreds the subject and verifies the
chain afterwards, and `test/privacy_db_test.dart` does the same through real
repositories.

Two suites are tagged `db` and skip when no server is reachable, so the default
run stays green without one. `test/audit_sql_db_test.dart` covers the relational
sink against a live database — MariaDB or PostgreSQL — appending, reopening, concurrency, writer scoping,
retention removing a prefix and nothing else, querying — including the two
claims the projection rests on, that an actor too long for its column is still
found and that two actors sharing a prefix are told apart by the record —
verification noticing what the
chain exists to notice, an anchor catching what the chain cannot, the write-once
probe, and the grant that is the guarantee. `test/audit_db_test.dart` covers the
repository chokepoint, which is what makes the trail automatic rather than
something a caller remembers.

```bash
dart run example/audit/audit_example.dart
```

`example/audit/audit_example.dart` walks the module without a database or a
server: installing a sink, the record's shape, attribution from the ambient
zone, the declared/automatic split, redaction, the hash chain, the file sink
with its whole-file retention, the relational sink's schema and write-once
check, the anchors, and finally a query over the trail those steps produced. The records are produced by hand, which is what keeps
the example connection-free — the two chokepoints that produce them in a running
server are covered by the two `db` suites above and by
`test/endpoints_pipeline_test.dart`. Every step checks its own result, and
`test/examples_test.dart` runs it.

## Querying the Trail

An auditor asks few questions and always the same ones: what did this person do,
what happened to this record, what happened in this window, what was refused.
`TomAuditQuery` is that question — a value, with every field optional and every
field given an **and**:

```dart
final result = await sink.query(
  TomAuditQuery(
    actor: 'ada',
    action: TomAuditAction.delete,
    from: DateTime.utc(2026, 3, 1),
    to: DateTime.utc(2026, 4, 1),
    limit: 100,
  ),
);

for (final entry in result.entries) {
  print('${entry.record.timestamp} ${entry.record.target}');
}
if (result.hasMore) print('…and more before that');
```

Being a value rather than a method is the same arrangement `verifyAuditChain`
already has, and for the same reason: the *question* is storage-neutral, the
answering is not.

| Trail | How it is asked |
| --- | --- |
| `TomMemoryAuditSink` | `filterAuditEntries(sink.entries, query)` |
| `TomFileAuditSink` | `filterAuditEntries(sink.readAll(), query)` |
| `TomSqlAuditSink` | `await sink.query(query)` |

The relational sink is the one that does not go through the shared function, and
that is deliberate rather than an accident of it being asynchronous. The filter
is pushed into the database, where the indexes on `(target, action)`, `(actor)`
and `(writer, recorded_at)` are — the indexes the table has carried since it was
declared, and which nothing used to issue a query against. Reading every row back
in order to discard all but five answers the same question and is what
`readAll()` is for; on a trail of ten million rows it is not a query.

`TomAuditQueryResult` carries counts as well as entries, because a page on its
own cannot be read safely:

| Field | What it says |
| --- | --- |
| `entries` | the matching entries, in the order asked for — newest first by default |
| `hasMore` | the trail held further matches beyond this page |
| `examined` | how many stored entries were read and judged |
| `rejectedByProjection` | how many the index matched and the record did not |

A query is scoped to the sink's own `writer`, like `readAll()` and both purges: a
sink is one chain's handle on a table several may share. A deployment with
several writers asks each of them, which is also what keeps the entry indexes in
the answer meaningful — they are positions within a chain, and there is no order
across two.

### The projection narrows, the record decides

The columns a `WHERE` clause can test are the six **projection** columns, and
they are [a lossy index](#the-relational-sink): truncated to fit, so they can say
*maybe* and never *yes*. Both ways of forgetting that are silent, so neither is
left to documentation:

- **Comparing a full search term to a truncated column finds nothing.** A
  200-character username is stored as its first 160, and `WHERE actor = :actor`
  with the whole name matches no row — reported to the auditor as "this person
  did nothing". A false negative, in the one kind of query where a silent
  omission is the worst available outcome. So every search term is cut to its
  column's declared width before it is bound, by the same call the insert uses
  (`auditProjectionPrefix`, over the width in the `TomFrameworkTable`
  declaration). Both ends cut at the same place because both ask the same
  declaration where it is.
- **Trusting the column's value reports a truncated name as the name.** The cut
  above admits rows that merely share a prefix, so every row that comes back is
  decoded and re-judged by `TomAuditQuery.matches` against the record itself,
  which is never truncated. Rows the index matched and the record did not are
  dropped, and counted in `rejectedByProjection` rather than hidden.

So the answer never contains a row the index merely thought looked right, and
never omits one it stored short.

### Paging is by window, not by offset

Narrow `to` to the oldest instant already seen and ask again. There is no
`offset`, and its absence is the same argument as above: an offset would have to
be counted over the projection's matches rather than the record's, and those are
two different numbers. Counting in the units the caller cannot see is how a page
boundary silently skips an entry.

### Exporting a result

Export stays in the `export` module rather than growing a second home here. An
entry is already a map — `TomAuditEntry.toJson()` — so a result feeds
`TomTabularSection.ofMaps` directly, and the CSV, XLSX and PDF renderers follow
from there:

```dart
final section = TomTabularSection.ofMaps(
  columns, // the TomTabularColumns to export, in order
  Stream.fromIterable([
    for (final entry in result.entries) entry.record.toJson(),
  ]),
);
```

Nothing in `audit` depends on `export` for this, and that is the point: the audit
module owns the trail and the question, the export module owns the rendering, and
a result is the value that crosses between them.

### Reports above the query

The auditor's product above the query — questions asked across every writer of
a trail, saved with a schedule, recipients and a format, and delivered as an
export by email — is the [audit_reports](audit_reports.md) module. It reads the
trail through this module's sink and records each delivery in it, so this
module gains a consumer rather than a dependency.

## Core Components

- **`TomAuditRecord` / `TomAuditActor` / `TomAuditAction` / `TomAuditOutcome`**
  — the record shape and its JSON round-trip.
- **`TomAuditRecordIdGenerator`** — `next`; the record ids, fixed-width so that
  sorting them sorts by write order.
- **`TomAudited` / `TomAuditPolicy` / `tomAuditRedactedPlaceholder`** — the
  declaration and its resolved form.
- **`TomAuditTrail`** — `install` / `uninstall` / `record` / `recordMutation` /
  `recordAction` / `policyFor` / `runUnaudited`; the only thing the chokepoints
  touch. `personalValueSealer` is where the privacy module's subject keys plug
  in.
- **`TomAuditBypass`** — the zone marker `runUnaudited` installs.
- **`auditDiff`** — computes the changed-fields-only before/after pair.
- **`TomAuditSink` / `TomMemoryAuditSink` / `TomFileAuditSink` /
  `TomSqlAuditSink`** — storage.
- **`TomAuditWriteOnceCheck` / `auditTrailTable` / `auditTrailTableDdl` /
  `auditTrailGuardStatements` / `auditTrailNoUpdateTriggerDdl` /
  `auditTrailNoDeleteTriggerDdl` / `defaultAuditTrailTable`** — the relational
  trail's schema, declared once, its guards in each database's words, and its
  write-once probe.
- **`TomAuditTrailRow` / `TomAuditHeadRow` / `TomAuditSeqRow` /
  `TomAuditTriggerRow`** — the reflected row shapes `TomSqlAuditSink` reads
  through.
- **`TomAuditEntry` / `verifyAuditChain` / `parseAuditLines` /
  `TomAuditChainVerification` / `tomAuditGenesisHash`** — the hash chain and its
  verification.
- **`TomAuditAnchor` / `verifyAgainstAnchor` / `TomAuditAnchorStatus` /
  `TomAuditAnchorVerification`** — the external anchor and what it proves.
- **`TomAuditAnchorSigner` / `TomAuditAnchorVerifier` /
  `TomRsaAuditAnchorSigner` / `TomRsaAuditAnchorVerifier`** — anchor signing.
- **`TomAuditAnchorStore` / `TomMemoryAuditAnchorStore` /
  `TomFileAuditAnchorStore` / `TomAuditAnchorPublisher`** — anchor publication.
- **`TomAuditException`** — a sink that could not store a record.

## Not Yet Implemented

- ~~Anchor stores for specific external services.~~ **Decided: none ship here,
  and the question is closed.** An external store's guarantee lives in its
  configuration — an object-lock mode, a retention period, a credential that
  cannot delete — and not in the code that talks to it, so shipping one would
  put this package's name on a guarantee it cannot see. The seam is
  `TomAuditAnchorStore`; a deployment implements it where its arrangement is
  reviewable. What the framework does supply is the posture:
  [declared, and never believed](#the-posture-is-declared-and-never-believed).
  <!-- unpinned: decision — no external anchor store ships, by a closed decision -->
- **Routing a finding somewhere other than a log or a callback.**
  `TomAuditAnchorMonitor` ships both of those and nothing else — see [Reading
  the anchors back](#reading-the-anchors-back). A deployment that wants a
  divergence to reach the messaging outbox, a health check or a pager wires it
  in `onFinding`; the framework does not ship those routes because which of
  them is right is a property of the deployment. This is a seam rather than an
  omission.
  <!-- unpinned: absence — routes beyond a log and a callback are the deployment's to wire -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `audit_anchor_monitor.dart`, `audit_anchor_store.dart`, `audit_sink.dart`, `audit_trail.dart`, `sql_audit_sink.dart` | `Future`, `Timer`, `unawaited` |
| `dart:convert` | dart | `audit_anchor.dart`, `audit_anchor_store.dart`, `audit_sink.dart`, `sql_audit_sink.dart` | `base64Decode`, `base64Encode`, `json`, `jsonDecode`, `jsonEncode`, `utf8` |
| `dart:io` | dart | `audit_anchor_store.dart`, `audit_sink.dart` | `Directory`, `File`, `FileMode` |
| `dart:typed_data` | dart | `audit_anchor.dart` | `Uint8List` |
| `crypto` | package | `audit_sink.dart` | SHA-256 for the hash chain |
| `path` | package | `audit_anchor_store.dart`, `audit_sink.dart` | `p.basename`, `p.basenameWithoutExtension`, `p.join` |
| `tom_core_kernel` | package | 7 of 9 files | `TomPrincipal`, `TomUser`, `getFromCurrentZone`, `TomClosable`, `tomReflector` (policy resolution by mirror), `TomScheduledJob` / `TomJobBase` / `TomRetryPolicy` and `TomBean` / `TomBeanLocatorException` for the verification job, `tomLog` for the finding channel, `TomRequestId`, recovered from the zone to supply `requestId`, and — through its `tom_crypto` re-export — `rsaSign` / `rsaVerify` for anchor signatures |
| [datasources](datasources.md) | module | `sql_audit_sink.dart`, `sql_audit_sql.dart` | `TomSqlAuditSink` writes through a `TomDataSource` directly, and encodes instants with `sqlInstant` |
| [little_things](little_things.md) | module | `audit_sink.dart`, `sql_audit_sink.dart` | `TomServerException`, the base of the module's exceptions |
| [object_persistence](object_persistence.md) | module | `sql_audit_sink.dart` | `TomSqlDatasourceRepository` calls the trail on every mutation |

- `pointycastle` — the `RSAPrivateKey` / `RSAPublicKey` types anchor signing
  takes.
- The endpoints module — `TomEndpointHandler` calls the trail at the denial and
  declared-invocation points.
