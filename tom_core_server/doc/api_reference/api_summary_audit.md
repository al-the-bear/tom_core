# Tom Core Server API Reference: Audit Module

An attributable, tamper-evident record of who did what to which record, when,
and with what outcome. Records are produced at the framework's own chokepoints,
hash-chained by the sink, and optionally anchored outside the audited server.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomAuditAction](#tomauditaction)
  - [TomAuditOutcome](#tomauditoutcome)
  - [TomAuditActor](#tomauditactor)
  - [TomAuditRecord](#tomauditrecord)
  - [TomAuditException](#tomauditexception)
  - [TomAuditEntry](#tomauditentry)
  - [TomAuditChainVerification](#tomauditchainverification)
  - [TomAuditSink](#tomauditsink)
  - [TomMemoryAuditSink](#tommemoryauditsink)
  - [TomFileAuditSink](#tomfileauditsink)
  - [TomAudited](#tomaudited)
  - [TomAuditPolicy](#tomauditpolicy)
  - [TomAuditBypass](#tomauditbypass)
  - [TomAuditTrail](#tomaudittrail)
  - [TomAuditRecordIdGenerator](#tomauditrecordidgenerator)
  - [TomAuditAnchor](#tomauditanchor)
  - [TomAuditAnchorSigner](#tomauditanchorsigner)
  - [TomAuditAnchorVerifier](#tomauditanchorverifier)
  - [TomRsaAuditAnchorSigner](#tomrsaauditanchorsigner)
  - [TomRsaAuditAnchorVerifier](#tomrsaauditanchorverifier)
  - [TomAuditAnchorStatus](#tomauditanchorstatus)
  - [TomAuditAnchorVerification](#tomauditanchorverification)
  - [TomAuditAnchorStore](#tomauditanchorstore)
  - [TomMemoryAuditAnchorStore](#tommemoryauditanchorstore)
  - [TomFileAuditAnchorStore](#tomfileauditanchorstore)
  - [TomAuditAnchorPublisher](#tomauditanchorpublisher)
  - [TomAuditWriteOnceCheck](#tomauditwriteoncecheck)
  - [TomSqlAuditSink](#tomsqlauditsink)
  - [TomAuditTrailRow](#tomaudittrailrow)
  - [TomAuditHeadRow](#tomauditheadrow)
  - [TomAuditSeqRow](#tomauditseqrow)
  - [TomAuditTriggerRow](#tomaudittriggerrow)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/audit/audit_record.dart`,
`lib/src/tomserver/audit/audit_sink.dart`,
`lib/src/tomserver/audit/audit_trail.dart`,
`lib/src/tomserver/audit/audit_anchor.dart`,
`lib/src/tomserver/audit/audit_anchor_store.dart`,
`lib/src/tomserver/audit/sql_audit_sink.dart`,
`lib/src/tomserver/audit/sql_audit_sql.dart`.

`TomAuditRecord` is one auditable action — a `TomAuditActor`, a
`TomAuditAction`, a target and target key, a `TomAuditOutcome`, a request id and
the changed-fields-only `before`/`after` pair. Its `toJson` emits a fixed
canonical key order, because the sink hashes the encoded form. `TomAuditTrail`
is the process-wide facade the two chokepoints call: the repository write path
through `recordMutation`, which consults the type's `TomAuditPolicy` first, and
the endpoint pipeline through `recordAction`, which records declared invocations
and unconditional denials. `TomAudited` is the declaration that produces a
policy; `TomAuditPolicy.applyRedaction` replaces declared field values with
`tomAuditRedactedPlaceholder`. `TomAuditTrail.runUnaudited` installs a
`TomAuditBypass` in the zone so the trail's own persistence cannot audit itself
into a regress.

A `TomAuditSink` stores records as `TomAuditEntry` values: the record, the
previous entry's hash, its own hash over both, and its `index` counted from
genesis. The chain starts at `tomAuditGenesisHash`, and `verifyAuditChain`
returns a `TomAuditChainVerification` that distinguishes an edited record, a
broken link and a renumbered chain. `TomMemoryAuditSink` is a bounded ring for
tests; `TomFileAuditSink` appends JSON Lines under a directory, rotating by
renaming and applying age- and count-based retention *itself*;
`TomSqlAuditSink` writes one row per entry into a `TomDataSource` and prunes a
contiguous prefix through `purgeBefore` / `purgeToMaxEntries`, which nothing
calls on its behalf — it retains nothing until the deployment schedules one.
All three recover their head on reopen, so
a restart continues the chain rather than beginning a second one. Auditing is
fail-closed: a sink that cannot store a record completes its `write` future with
a `TomAuditException`, and the audited action fails with it.

The relational sink adds the deployment concerns a table has and a file does
not. Its schema is declared once as `auditTrailTable`, from which
`auditTrailTableDdl`, the entry `INSERT` and every read's column list derive;
`TomAuditTrailRow`, `TomAuditHeadRow`, `TomAuditSeqRow` and `TomAuditTriggerRow`
are the reflected row types its queries materialise. `verifyWriteOnce` observes
what the connected credential and the table's triggers actually permit and
reports a `TomAuditWriteOnceCheck`; `open()` warns on a rewritable table, or
refuses to start when `requireWriteOnce` is set. The two guard triggers
(`auditTrailNoUpdateTriggerDdl`, `auditTrailNoDeleteTriggerDdl`) are defence in
depth for a deployment that cannot separate credentials.

A hash chain proves internal consistency only, so a wholesale rewrite or a
truncation survives it. `TomAuditAnchor` closes both: a claim that chain
`writer` held `entryCount` entries whose head was `headHash` at `createdAt`,
optionally signed by a `TomAuditAnchorSigner` and checked by a
`TomAuditAnchorVerifier` (`TomRsaAuditAnchorSigner` /
`TomRsaAuditAnchorVerifier` implement both over RSA).
`TomAuditAnchorPublisher` writes one per node on a schedule into a
`TomAuditAnchorStore` — `TomMemoryAuditAnchorStore` for tests,
`TomFileAuditAnchorStore` for a directory the deployment has placed outside the
server's reach. `verifyAgainstAnchor` then returns a
`TomAuditAnchorVerification` whose `TomAuditAnchorStatus` separates a match, a
finding and an inconclusive result — and, because comparisons go through the
stored `index`, tells a retention sweep apart from a rewrite.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomAuditException

TomAuditAction  (enum)
TomAuditOutcome  (enum)
TomAuditAnchorStatus  (enum)

TomAuditActor
TomAuditRecord
TomAuditEntry
TomAuditChainVerification

TomAudited
TomAuditPolicy
TomAuditBypass
TomAuditTrail  (static-only)
TomAuditRecordIdGenerator

TomAuditAnchor
TomAuditAnchorVerification
TomAuditWriteOnceCheck

TomClosable  (kernel)
    ├── TomAuditSink  (abstract)
    │       ├── TomMemoryAuditSink
    │       ├── TomFileAuditSink
    │       └── TomSqlAuditSink
    ├── TomAuditAnchorStore  (abstract)
    │       ├── TomMemoryAuditAnchorStore
    │       └── TomFileAuditAnchorStore
    └── TomAuditAnchorPublisher

TomAuditAnchorSigner  (abstract)
    └── TomRsaAuditAnchorSigner

TomAuditAnchorVerifier  (abstract)
    └── TomRsaAuditAnchorVerifier

TomAuditTrailRow
TomAuditHeadRow
TomAuditSeqRow
TomAuditTriggerRow
```

## Classes

### TomAuditAction

What kind of action a `TomAuditRecord` describes. Deliberately small — these are
the categories an auditor reasons in, while the specific operation is carried by
the record's free-form `target` and `detail`.

| Value | Description |
| ----- | ----------- |
| `create` | A new record was created (a repository `INSERT`). |
| `update` | An existing record was modified (a repository `UPDATE`). |
| `delete` | A record was destroyed (a repository `DELETE`). |
| `read` | A record was read. Nothing in the framework produces this — no repository read is audited and no annotation makes one; a record carrying it exists because application code called `TomAuditTrail.recordAction`. |
| `execute` | An action that is not a record mutation — an endpoint call, a job run, a report export. |

### TomAuditOutcome

How the audited action ended. `denied` is kept distinct from `failed` because a
failure is an operational event and a denial is a security one — the entry an
auditor scans for first.

| Value | Description |
| ----- | ----------- |
| `succeeded` | The action completed. |
| `failed` | The action was attempted and raised. |
| `denied` | The action was refused before it ran — authentication, authorization, row scope or column grade. |

### TomAuditActor

Who performed an audited action. Never left blank: an action performed with no
principal in the zone is attributed to `systemUsername` rather than to `null`,
so "the framework acted on its own behalf" and "we failed to record who acted"
cannot look alike.

#### Constructors

```dart
const TomAuditActor({
  required String username,
  int? userId,
  bool authenticated = false,
  int? organizationId,
  int? applicationId,
})
```

#### Factory Constructors

```dart
factory TomAuditActor.fromPrincipal(TomPrincipal? principal)

factory TomAuditActor.fromCurrentZone()

factory TomAuditActor.fromJson(Map<String, Object?> json)
```

`fromPrincipal` normalises `TomPrincipal`'s `-1` "unset" sentinel to `null` and
returns `system` for a `null` principal; `fromCurrentZone` resolves the
principal from the ambient zone, which is how both chokepoints attribute without
threading it through their signatures.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `systemUsername` | `static const String` | The username recorded when no principal is present in the zone (`'SYSTEM'`). |
| `system` | `static const TomAuditActor` | The system actor, used for bootstrap, migrations and scheduled jobs. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `username` | `String` | The username the action is attributed to, or `systemUsername` (final). |
| `userId` | `int?` | The principal's user id; `null` for the system actor or an unset id (final). |
| `authenticated` | `bool` | Whether the principal had authenticated — recorded rather than assumed, since an unauthenticated principal can still reach an endpoint (final). |
| `organizationId` | `int?` | The principal's organization id, or `null` (final). |
| `applicationId` | `int?` | The principal's application id, or `null` (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The actor as JSON, omitting the ids the system actor has none of. |
| `toString` | `String toString()` | *(override)* `username` alone, or `username#userId` when an id is known. |

### TomAuditRecord

One entry in the audit trail: an attributable statement that an action happened.
Immutable — `timestamp` is coerced to UTC and `before`/`after` are wrapped
unmodifiable — because nothing downstream may adjust an entry after the fact.

#### Constructors

```dart
TomAuditRecord({
  required String id,
  required DateTime timestamp,
  required TomAuditActor actor,
  required TomAuditAction action,
  required String target,
  required TomAuditOutcome outcome,
  String? targetKey,
  String? requestId,
  Map<String, Object?> before = const {},
  Map<String, Object?> after = const {},
  String? detail,
})
```

#### Factory Constructors

```dart
factory TomAuditRecord.fromJson(Map<String, Object?> json)
```

Unknown enum names fall back to `TomAuditAction.execute` /
`TomAuditOutcome.failed` rather than throwing, so a reader can still process an
archive written by a version that had a value this one does not.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `id` | `String` | Unique id of this entry; sorts in write order. Unique per process — see `TomAuditRecordIdGenerator` (final). |
| `timestamp` | `DateTime` | When the action happened, always in UTC (final). |
| `actor` | `TomAuditActor` | Who performed the action (final). |
| `action` | `TomAuditAction` | What kind of action it was (final). |
| `target` | `String` | What it acted on — an entity type name, or an endpoint route (final). |
| `targetKey` | `String?` | The key of the affected record, when the action names one (final). |
| `outcome` | `TomAuditOutcome` | How the action ended (final). |
| `requestId` | `String?` | The request the action ran under; stitches an endpoint denial to the repository writes of the same request (final). |
| `before` | `Map<String, Object?>` | The changed fields' prior values, unmodifiable; empty for a create (final). |
| `after` | `Map<String, Object?>` | The changed fields' new values, unmodifiable; empty for a delete (final). |
| `detail` | `String?` | A human-readable note — the denial reason, the exception message (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The record as JSON in a fixed key order with empty collections omitted — canonical, because this encoding is what the sink hashes. |
| `toString` | `String toString()` | *(override)* Timestamp, actor, action, target, optional key and outcome on one line. |

### TomAuditException

Raised when the audit trail cannot do its job — a sink that could not store a
record, a malformed storage line, a chain entry with no index, a table that is
not write-once when one was required. Not client-visible (`clientThrow` defaults
to `false`), since the caller of an audited action has no business learning that
the trail is misconfigured.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomAuditException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? rootException,
  Object? stack,
  bool clientThrow = false,
})
```

### TomAuditEntry

A `TomAuditRecord` together with its position in the hash chain. The entry — not
the record — is what a sink stores, because a chain link only means anything
within one sink's sequence; the same record written to two sinks legitimately
has two different hashes.

#### Constructors

```dart
const TomAuditEntry({
  required TomAuditRecord record,
  required String previousHash,
  required String hash,
  required int index,
})
```

#### Factory Constructors

```dart
factory TomAuditEntry.chain(
  TomAuditRecord record,
  String previousHash, {
  required int index,
})

factory TomAuditEntry.fromJson(Map<String, Object?> json)
```

`chain` is the preferred constructor: it computes the hash rather than accepting
one. `fromJson` defaults nothing — every field is required, and an absent,
mistyped or (for the hashes) empty one raises a `TomAuditException`. A default
would not produce a vague entry but a specific accusation about a record nobody
touched:

| Field | Key | What defaulting it claimed |
| ----- | --- | -------------------------- |
| `index` | `audit.entry.missing_index` | A guessed position, which is what anchor verification is built on — a truncated trail would read as a merely short one. |
| `hash` | `audit.entry.missing_hash` | `''`, so the entry reads back as one whose hash does not match its contents: *content changed after writing*. |
| `previousHash` | `audit.entry.missing_previous_hash` | Genesis, so the entry claims to have begun a chain. Mid-chain that is a link mismatch; at the head it is not a finding at all, and damage verifies as health. |
| `record` | `audit.entry.missing_record` | Nothing — it already failed, but as a `TypeError`, so one field of four left the factory by a different door. |

The unnamed constructor is `const` and so cannot enforce any of this; `fromJson`
is the boundary at which damaged, hand-edited or foreign-written storage is
turned away, and it is what lets `parseAuditLines` promise that a line it cannot
read is reported rather than silently reinterpreted.

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `hashOf` | `static String hashOf(TomAuditRecord record, String previousHash)` | `sha256` over `'$previousHash\|<canonical record JSON>'`; canonical because `TomAuditRecord.toJson` fixes key order. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `record` | `TomAuditRecord` | The audited record (final). |
| `previousHash` | `String` | The hash of the preceding entry, or `tomAuditGenesisHash` for the first (final). |
| `hash` | `String` | This entry's hash, covering `previousHash` and the record's canonical JSON (final). |
| `index` | `int` | Zero-based position in the chain counted from genesis — stored, not inferred from a list offset, so retention does not move it. Deliberately outside the hashed payload (final). |
| `isSelfConsistent` | `bool` | *(getter)* Whether `hash` actually matches the record and link this entry claims. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toJson` | `Map<String, Object?> toJson()` | The entry as JSON: the position, the chain link, then the record. |
| `toJsonLine` | `String toJsonLine()` | The entry as one line of JSON with no embedded newline — the JSON Lines storage format. |
| `toString` | `String toString()` | *(override)* The record's one-line form followed by the first eight hash characters. |

### TomAuditChainVerification

The outcome of checking a chain's integrity: whether it held, how many entries
were checked, and where and how it first broke.

#### Constructors

```dart
const TomAuditChainVerification({
  required bool isValid,
  required int entryCount,
  int? brokenAtIndex,
  String? detail,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `isValid` | `bool` | Whether every entry linked and hashed correctly (final). |
| `entryCount` | `int` | How many entries were checked (final). |
| `brokenAtIndex` | `int?` | The zero-based offset of the first entry that failed, or `null` (final). |
| `detail` | `String?` | What went wrong at `brokenAtIndex` — `link mismatch`, `content changed after writing` or `chain renumbered` — or `null` when valid (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* A one-line summary naming the entry count, and the break position and reason when invalid. |

### TomAuditSink

Where a `TomAuditRecord` is persisted. `write` is expected to **fail** when it
cannot store the record: the trail is fail-closed, so a sink that swallows its
own storage errors defeats the guarantee for everything above it.

Failing means **completing the returned future with an error** — in every case,
including the ones an implementation can see before doing any work, such as a
closed sink. The return type is what a caller protects against:
`sink.write(r).catchError(...)`, `Future.wait([...])` and an unawaited write
with a `.then(onError:)` are all complete handling of a future's failure, and
none of them sits inside a `try`. Implementations mark `write` `async` rather
than raising from the synchronous part of the body, which puts the rule in the
declaration where a guard added later inherits it.

**Reading a trail back is deliberately not part of this interface.** A sink is
a *writer*, and the members below — `write`, `headHash`, `entryCount`, `close`,
`flushAndClose` — are the whole of what a caller may do to an arbitrary sink.
Each implementation exposes its own read-back in the shape
its storage has — `TomMemoryAuditSink.verify` and `TomFileAuditSink.readAll` /
`verify` synchronously, `TomSqlAuditSink.readAll` / `verify` asynchronously
because they are a query — and hoisting those onto one signature would impose
the asynchronous shape on all three while advertising `readAll()` on a
ten-million-row trail table as a reasonable call. Nothing is lost, because the
analysis is storage-neutral already: `verifyAuditChain` and
`verifyAgainstAnchor` take a `List<TomAuditEntry>`, not a sink. What *is*
uniform is the pair an anchor needs — `headHash` and `entryCount` are here
precisely because `TomAuditAnchor.of` must work against whatever sink is
installed. A reporting API over stored trails is a deferred feature of the
module, not a gap this interface is waiting to grow into.

- **Implements:** `TomClosable` (abstract)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `headHash` | `String` | *(getter)* The hash of the most recently written entry; publishing it outside the sink's own storage is what anchoring rests on. |
| `entryCount` | `int` | *(getter)* How many entries the chain has held since genesis, counted from the stored `TomAuditEntry.index` so retention does not move it. Read together with `headHash`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `write` | `Future<TomAuditEntry> write(TomAuditRecord record)` | Persists `record` and returns the entry as stored. Every failure, refusals included, arrives as an error on the returned future — never as a throw from the call itself. |
| `close` | `void close()` | *(override)* Closes the sink **without** waiting for records already queued. Inherits `TomClosable`'s synchronous contract, so a queued record cannot be waited for: it is refused with `audit.sink.closed` rather than dropped or written anyway. |
| `flushAndClose` | `Future<void> flushAndClose()` | Waits for every queued record to be stored, then closes. Nothing enqueued before the call is refused. Idempotent, and safe to call after `close`. Use this wherever an `await` is available. |

### TomMemoryAuditSink

An in-memory sink bounded by entry count. For tests and development servers
where an audit trail must exist but need not survive a restart — not for
production, since memory loses its most interesting entries exactly when the
server falls over.

- **Implements:** `TomAuditSink`

#### Constructors

```dart
TomMemoryAuditSink({int maxEntries = 1000})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxEntries` | `int` | How many entries are retained before the oldest are dropped (final). |
| `entries` | `List<TomAuditEntry>` | *(getter)* The retained entries, oldest first, unmodifiable. |
| `records` | `List<TomAuditRecord>` | *(getter)* The retained records, oldest first. |
| `droppedCount` | `int` | *(getter)* How many entries were dropped to stay within `maxEntries`; exposed so a caller knows it is verifying a suffix. |
| `headHash` | `String` | *(getter, override)* The hash of the most recently written entry. |
| `entryCount` | `int` | *(getter, override)* Entries written since genesis, unaffected by dropping. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `write` | `Future<TomAuditEntry> write(TomAuditRecord record)` | *(override)* Chains `record` onto the head, appends it, and drops the oldest entries once `maxEntries` is exceeded. |
| `verify` | `TomAuditChainVerification verify()` | Verifies the retained entries, starting from the oldest retained link rather than genesis so a bounded sink does not report a false break at the front. Synchronous, and not a `TomAuditSink` member — read-back is per implementation by design. |
| `clear` | `void clear()` | Discards every retained entry and resets the chain. Test-support only. |
| `close` | `void close()` | *(override)* No-op. |
| `flushAndClose` | `Future<void> flushAndClose()` | *(override)* Nothing to drain — `write` stores the entry before its future completes and there is no queue behind it. |

### TomFileAuditSink

An append-only JSON Lines file sink with age- and count-based retention. There
is one file per **UTC** day, named `audit-<yyyy-mm-dd>.jsonl` — UTC because
every record timestamp is, so a file named from local time would disagree with
its own contents. A file that exceeds `maxFileBytes` is rotated by **renaming**
it to `audit-<yyyy-mm-dd>-<n>.jsonl`, never rewritten; a day boundary is not a
rotation, since the new day gets its own name. The chain continues across
files, so retention leaves a verifiable suffix rather than unrelated fragments.
Rotation sequence numbers are monotonic and never reused. The head hash and
entry count are recovered from the newest existing file at construction.

Retention here is **automatic** — the sink applies `retention` and `maxFiles`
whenever it opens a file, so a deployment that sets them has nothing to
schedule. `TomSqlAuditSink` is the opposite and retains nothing on its own; the
asymmetry and where the scheduled purge belongs are described there.

- **Implements:** `TomAuditSink`

#### Constructors

```dart
TomFileAuditSink({
  required Directory directory,
  int maxFileBytes = 16 * 1024 * 1024,
  Duration retention = const Duration(days: 3650),
  int maxFiles = 512,
  String filePrefix = 'audit',
  DateTime Function()? clock,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `directory` | `Directory` | The directory the audit files live in; created if absent (final). |
| `maxFileBytes` | `int` | The byte size at which the current file is rotated (final). |
| `retention` | `Duration` | How long a rotated file is kept (final). |
| `maxFiles` | `int` | How many files are kept, regardless of `retention` (final). |
| `filePrefix` | `String` | The file name prefix, so several trails can share a directory (final). |
| `clock` | `DateTime Function()` | The clock the day boundary and the retention age are read from; defaults to `DateTime.now`, injectable so a test can cross midnight or age a file without waiting (final). |
| `headHash` | `String` | *(getter, override)* The hash of the most recently written entry. |
| `entryCount` | `int` | *(getter, override)* Entries written since genesis, recovered across restarts. |
| `files` | `List<File>` | *(getter)* The audit files in `directory` in write order — by day, then by rotation sequence, with each day's live file last. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `readAll` | `List<TomAuditEntry> readAll()` | Reads every retained entry across all files, oldest first. Synchronous, and not a `TomAuditSink` member — read-back is per implementation by design. |
| `verify` | `TomAuditChainVerification verify()` | Verifies the retained entries starting from the oldest retained link, so a retention deletion is not reported as a break. Synchronous, like `readAll`, and not on `TomAuditSink` either. |
| `write` | `Future<TomAuditEntry> write(TomAuditRecord record)` | *(override)* Appends one JSON line to the current UTC day's file, opening the next day's file when the day has turned over — which is not a rotation, so no sequence number is spent — rotating on overflow and applying retention as needed. Writes are serialised through an internal queue, and each is flushed before it returns. The returned future carries `audit.sink.closed` when the sink is closed and `audit.sink.write_failed` when storage refused it — once each, and never as a throw from the call. A failed write drops the file handle, so the sink resumes recording as soon as the path it died on works again. |
| `close` | `void close()` | *(override)* Closes the file handle. Every `write` that has *returned* already flushed, so nothing completed is at risk; a record still in the queue is refused with `audit.sink.closed`, because `TomClosable` requires this method to return synchronously and no synchronous method can wait for a queue. The refusal is also what keeps a queued record from reopening the file the sink has just closed. |
| `flushAndClose` | `Future<void> flushAndClose()` | *(override)* Closes the sink to new records, waits for the queued ones to be written and flushed, then closes the handle. The route that stores what `close` has to refuse. |

### TomAudited

Declares how the annotated entity or endpoint method is audited. On an entity it
tunes the automatic mutation auditing every entity already gets; on an endpoint
method it opts that method's invocation into the trail, which is not automatic.

#### Constructors

```dart
const TomAudited({bool enabled = true, List<String> redact = const []})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `enabled` | `bool` | Whether the annotated target is audited at all; only meaningful as `false`, the opt-out (final). |
| `redact` | `List<String>` | Field names whose values must never appear in a record's `before`/`after`; the record still shows that the field changed (final). |

### TomAuditPolicy

The resolved audit policy for a type — `TomAudited`'s values with the defaults
already applied. Resolution goes through the reflector, which is not free, so
`TomAuditTrail` caches it per type.

#### Constructors

```dart
const TomAuditPolicy({required bool enabled, required Set<String> redact})
```

#### Factory Constructors

```dart
factory TomAuditPolicy.from(TomAudited annotation)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultPolicy` | `static const TomAuditPolicy` | What a type with no `@TomAudited` annotation gets: mutations audited, reads not, nothing redacted. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `enabled` | `bool` | Whether the type is audited at all (final). |
| `redact` | `Set<String>` | The field names whose values are withheld from records (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `audits` | `bool audits(TomAuditAction action)` | Whether `action` is audited under this policy: nothing when disabled, `read` never, everything else otherwise. |
| `applyRedaction` | `Map<String, Object?> applyRedaction(Map<String, Object?> values)` | `values` with every redacted field replaced by `tomAuditRedactedPlaceholder`; returns `values` unchanged when nothing is redacted, so the common case costs no copy. |

### TomAuditBypass

A zone marker that suppresses auditing for the actions performed inside it,
installed by `TomAuditTrail.runUnaudited`. It exists so the trail's own
persistence cannot audit its own writes into an infinite regress — not as a
general opt-out, which is what `@TomAudited(enabled: false)` is for.

#### Constructors

```dart
const TomAuditBypass()
```

### TomAuditTrail

The audit trail: resolves policy, builds records, and hands them to the
configured sink. A process-wide singleton rather than an injected collaborator,
because an audit trail a caller can decline to pass is not one. Auditing is off
until a sink is installed.

#### Constructors

None — the constructor is private; the whole surface is static.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sink` | `static TomAuditSink?` | *(getter)* The sink records are written to, or `null` when auditing is off. |
| `isEnabled` | `static bool` | *(getter)* Whether records are being written — a sink is installed and the current zone is not bypassed. |
| `isBypassed` | `static bool` | *(getter)* Whether the current zone suppresses auditing, i.e. execution is inside a `runUnaudited` body. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `install` | `static void install(TomAuditSink sink)` | Installs `sink` as the destination for audit records. Closes nothing — the previous sink's lifetime belongs to whoever created it. |
| `uninstall` | `static void uninstall()` | Removes the sink, turning auditing off. |
| `runUnaudited` | `static Future<T> runUnaudited<T>(Future<T> Function() body)` | Runs `body` in a zone carrying a `TomAuditBypass`, so nothing it does is recorded. For the trail's own persistence path only. |
| `policyFor` | `static TomAuditPolicy policyFor(Type type)` | The policy for `type`, resolved from its `@TomAudited` annotation through the reflector and cached. A type the reflector does not know gets `TomAuditPolicy.defaultPolicy`. |
| `resetPolicyCache` | `static void resetPolicyCache()` | Clears the resolved-policy cache. Test-support only. |
| `record` | `static Future<void> record(TomAuditRecord record)` | Writes `record` to the sink. A no-op when auditing is off or suppressed; throws `TomAuditException` when the sink cannot store it. |
| `recordMutation` | `static Future<void> recordMutation({required Type entityType, required TomAuditAction action, required String target, String? targetKey, TomAuditOutcome outcome = TomAuditOutcome.succeeded, Map<String, Object?> before = const {}, Map<String, Object?> after = const {}, String? detail})` | Records a mutation of `entityType`, consulting the type's policy, applying its redaction and attributing the action to the current zone's principal and request. Returns without writing when the policy excludes `action`. |
| `recordAction` | `static Future<void> recordAction({required TomAuditAction action, required String target, required TomAuditOutcome outcome, String? targetKey, String? detail, TomAuditActor? actor})` | Records an action that is not an entity mutation — an endpoint invocation or an access denial. No entity policy is consulted: the caller has already decided. |
| `currentRequestId` | `static String? currentRequestId()` | The current request's id from the zone's `TomRequestId`, or `null` outside a request. |
| `newAuditRecordId` | `static String newAuditRecordId()` | A new record id from the process-wide `TomAuditRecordIdGenerator`: microseconds since epoch plus a per-microsecond counter, so ids sort in write order. |

### TomAuditRecordIdGenerator

Issues audit record ids of the form `<microseconds since epoch>-<six hex
digits>`, e.g. `1700000000000000-00002a`. Both fields are fixed-width, because
sorting audit ids is a *string* sort: the suffix is padded, and the microsecond
field is sixteen digits of its own accord until the year 2286.

The counter counts **within a microsecond** and resets whenever the clock
advances, which is what makes six digits enough. A counter that only climbed
would wrap at 16 777 216 ids and reissue values sorting *before* their
predecessors; reset per microsecond, its width is bounded by how many records a
process can write in one microsecond, and is therefore unreachable rather than
merely generous.

`next` also pins the highest microsecond it has seen, so a clock stepping
backwards — an NTP correction, far likelier than exhausting a counter — cannot
make a later id sort before an earlier one. The cost is that during such a
correction the id's leading field runs ahead of the wall clock; the record's own
`timestamp` is unaffected, and that is the field that states when the action
happened.

Ids are unique **per generator**, hence per process. Two processes writing into
one trail table can mint the same id in the same microsecond and nothing rejects
it: `entry_id` carries no unique key, and must not, because such a key would
turn a legitimate collision between two writers into a failed insert — and a
failed insert here fails the audited action closed. Cross-process identity is
the record's actor and timestamp; cross-process chain integrity is the sink's
`writer` and its unique key on `(writer, previous_hash)`.

#### Constructors

```dart
TomAuditRecordIdGenerator({int Function()? clock})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `clock` | `int Function()` | The clock this generator reads, in microseconds since the epoch; injectable so a test can hold a microsecond still or move it backwards without waiting for either (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `next` | `String next()` | The next id. Advances the pinned microsecond and restarts the counter when the clock has moved forwards; otherwise increments the counter against the pinned microsecond. |

### TomAuditAnchor

A signed-or-unsigned claim about where an audit chain stood at a moment — chain
`writer` held `entryCount` entries whose head was `headHash`, at `createdAt`.
Immutable by construction, since an anchor that could be edited would prove
nothing. `createdAt` is coerced to UTC.

#### Constructors

```dart
TomAuditAnchor({
  required String writer,
  required int entryCount,
  required String headHash,
  required DateTime createdAt,
  String? keyId,
  String? signature,
})
```

#### Factory Constructors

```dart
factory TomAuditAnchor.of(
  TomAuditSink sink, {
  required String writer,
  DateTime? at,
})

factory TomAuditAnchor.fromJson(Map<String, Object?> json)
```

`of` reads `headHash` and `entryCount` with no `await` between them, so a
concurrent write cannot pair a head with the wrong count. `fromJson` throws a
`TomAuditException` when `writer`, `entryCount`, `headHash` or `createdAt` is
missing or of the wrong type.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `writer` | `String` | The chain this anchor describes — `TomSqlAuditSink.writer`, or whatever name the deployment gives a node's chain (final). |
| `entryCount` | `int` | How many entries the chain held, counted from genesis; the positional claim, captured together with `headHash` (final). |
| `headHash` | `String` | The hash of the `entryCount`-th entry, or `tomAuditGenesisHash` for an empty chain (final). |
| `createdAt` | `DateTime` | When the anchor was taken, in UTC. Evidence that bounds when a later divergence happened; positions are never compared by time (final). |
| `keyId` | `String?` | Which key signed this anchor, or `null` when unsigned (final). |
| `signature` | `String?` | The base64 signature over `signedPayload`, or `null` when unsigned (final). |
| `isSigned` | `bool` | *(getter)* Whether both `signature` and `keyId` are present. |
| `signedPayload` | `String` | *(getter)* The exact bytes a signature covers, as canonical JSON with fixed key order, an ISO-8601 UTC `createdAt`, and the signature itself excluded. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `signedWith` | `TomAuditAnchor signedWith(TomAuditAnchorSigner signer)` | This anchor with `signer`'s key id and signature attached. The key id is set *before* the payload is signed, so an anchor cannot be re-attributed without invalidating its own signature. |
| `toJson` | `Map<String, Object?> toJson()` | The anchor as a JSON map, including `keyId` and `signature`. |
| `toJsonLine` | `String toJsonLine()` | The anchor as one line of JSON with no embedded newline. |
| `toString` | `String toString()` | *(override)* Writer, position, truncated head hash, timestamp, and whether it is signed. |

### TomAuditAnchorSigner

Attaches a signature to an anchor's payload. An interface rather than a concrete
algorithm because the key material is the deployment's: an HSM, a KMS and a PEM
file are all legitimate answers.

- **Extends:** none (abstract)

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keyId` | `String` | *(getter)* Names the key, so a verifier holding several can pick the right one and a rotation does not orphan the anchors signed before it. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sign` | `String sign(String payload)` | Signs `payload`, returning the signature base64-encoded. |

### TomAuditAnchorVerifier

Checks the signature on an anchor.

- **Extends:** none (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `verify` | `bool verify(TomAuditAnchor anchor)` | Whether `anchor` carries a valid signature from a key this verifier knows. An unsigned anchor, or one signed by an unknown key, is `false`. **Implementations must not throw** — the input is an anchor that may have been tampered with, so malformed key ids and signatures are ordinary traffic. `verifyAgainstAnchor` enforces this at the seam, reporting a throw as `signatureInvalid` with the error in `detail`. |

### TomRsaAuditAnchorSigner

Signs anchors with an RSA private key (SHA-256, PKCS#1 v1.5). The key should
live where the audited server cannot reach it after signing — a locally held key
defends the store, not the chain.

- **Implements:** `TomAuditAnchorSigner`

#### Constructors

```dart
const TomRsaAuditAnchorSigner({
  required RSAPrivateKey privateKey,
  required String keyId,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `privateKey` | `RSAPrivateKey` | The private key that signs (final). |
| `keyId` | `String` | *(override)* The id anchors signed by this key are published under (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `sign` | `String sign(String payload)` | *(override)* Base64 of `rsaSign` over the UTF-8 payload. |

### TomRsaAuditAnchorVerifier

Verifies anchor signatures against a set of published public keys. Several keys
held by id, so verification survives a key rotation and anchors signed by the
retired key stay checkable.

- **Implements:** `TomAuditAnchorVerifier`

#### Constructors

```dart
const TomRsaAuditAnchorVerifier(Map<String, RSAPublicKey> publicKeys)
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `publicKeys` | `Map<String, RSAPublicKey>` | The public keys, by the `TomAuditAnchorSigner.keyId` that names them (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `verify` | `bool verify(TomAuditAnchor anchor)` | *(override)* `false` for an unsigned anchor, an unknown key id, or any signature the cipher cannot make sense of — invalid base64, the wrong length, bytes that decode to nothing PKCS#1 recognises; otherwise the result of `rsaVerify` over `signedPayload`. Total by construction: every failure below is caught and answered `false`. |

### TomAuditAnchorStatus

How a chain stands relative to an anchor. An operator alert should key on the
three groups `TomAuditAnchorVerification` exposes — `isMatch`,
`indicatesTampering`, `isInconclusive` — rather than on the enum directly.

| Value | Description |
| ----- | ----------- |
| `matched` | The chain is intact and ends exactly where the anchor says it did. |
| `extended` | The chain is intact, agrees at the anchored position, and has grown since — the ordinary state of a live trail. |
| `beforeRetention` | The chain is intact but the anchored position was pruned, so there is nothing left to compare. Inconclusive; a deployment that does not prune should treat it as a finding. |
| `truncated` | The chain is intact but stops short of the anchored position: entries the anchor counted are gone from the end. |
| `diverged` | The chain is intact but the anchored position hashes differently — the wholesale-rewrite signal. |
| `chainBroken` | The chain fails its own verification, so the anchor was not consulted. |
| `signatureInvalid` | The anchor's signature is missing, unknown or wrong — or the verifier threw instead of answering — so nothing was concluded from it. |
| `writerMismatch` | The anchor describes a different chain than the entries do. |

### TomAuditAnchorVerification

The outcome of checking a chain against an anchor: the status, the anchor that
was checked against, the chain's own verification (always performed and always
reported) and a one-line explanation.

#### Constructors

```dart
const TomAuditAnchorVerification({
  required TomAuditAnchorStatus status,
  required TomAuditAnchor anchor,
  required TomAuditChainVerification chain,
  required String detail,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `status` | `TomAuditAnchorStatus` | What was concluded (final). |
| `anchor` | `TomAuditAnchor` | The anchor that was checked against (final). |
| `chain` | `TomAuditChainVerification` | The chain's own verification (final). |
| `detail` | `String` | A one-line explanation, suitable for an operator alert (final). |
| `isMatch` | `bool` | *(getter)* Whether the chain is consistent with the anchor — `matched` or `extended`. |
| `indicatesTampering` | `bool` | *(getter)* Whether this is a finding an operator must act on — `diverged`, `truncated`, `chainBroken` or `signatureInvalid`. |
| `isInconclusive` | `bool` | *(getter)* Whether nothing could be concluded: neither a match nor a finding. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The status name followed by `detail`. |

### TomAuditAnchorStore

An append-only archive of published anchors. Reading is offered because
verification needs it, but a store is free to serve reads from a different
credential than the one that appends — the append path is what runs on the
audited server, and it wants the narrowest possible permission.

- **Implements:** `TomClosable` (abstract)

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `append` | `Future<void> append(TomAuditAnchor anchor)` | Appends `anchor`; must throw rather than silently drop, so a publisher can tell a publication from a swallowed error. |
| `read` | `Future<List<TomAuditAnchor>> read(String writer)` | Every stored anchor for `writer`, oldest first — and **only** that writer's. An implementation that groups by some derivation of the name must still filter on the writer recorded in each anchor, since such derivations are rarely injective. A foreign anchor is worse than none: it makes `latest` answer the routine check with a position from another trail. |
| `latest` | `Future<TomAuditAnchor?> latest(String writer)` | The most recently published anchor for `writer`, or `null`. The one a routine check uses: it pins the furthest verifiable position. |
| `close` | `void close()` | *(override)* No-op by default. |

### TomMemoryAuditAnchorStore

An in-memory anchor store, for tests. Explicitly not an anchor: it lives in the
process it is anchoring, so it dies with exactly the attacker who would need to
rewrite it.

- **Extends:** `TomAuditAnchorStore`

#### Constructors

```dart
TomMemoryAuditAnchorStore()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `anchors` | `List<TomAuditAnchor>` | *(getter)* Every anchor appended, in order, across all writers; unmodifiable. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `append` | `Future<void> append(TomAuditAnchor anchor)` | *(override)* Adds `anchor` to the in-memory list. |
| `read` | `Future<List<TomAuditAnchor>> read(String writer)` | *(override)* The appended anchors whose `writer` matches, in order. |
| `clear` | `void clear()` | Discards every stored anchor. Test-support only. |

### TomFileAuditAnchorStore

A JSON Lines anchor store, one file per writer, append-only. Files are never
rotated — anchors are small and their whole value is that the old ones survive.
The directory must be somewhere the audited application cannot rewrite; the
framework cannot enforce that and does not pretend to.

- **Extends:** `TomAuditAnchorStore`

#### Constructors

```dart
TomFileAuditAnchorStore({
  required Directory directory,
  String filePrefix = 'anchor',
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `directory` | `Directory` | The directory the anchor files live in; created if absent (final). |
| `filePrefix` | `String` | The file name prefix, so several deployments can share a directory (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `fileFor` | `File fileFor(String writer)` | The file holding `writer`'s anchors. The writer name is sanitised into the file name rather than trusted, so a writer called `../../etc` produces a strange name and not a write outside `directory`. The mapping is deliberately **not injective** — `node/a` and `node_a` share a file — and `read` filters accordingly. |
| `append` | `Future<void> append(TomAuditAnchor anchor)` | *(override)* Appends one flushed JSON line to the anchor's writer file. |
| `read` | `Future<List<TomAuditAnchor>> read(String writer)` | *(override)* Parses the writer's file, skipping blank lines and returning `const []` when it does not exist. Returns only anchors whose recorded `writer` matches, since a lossy file name can put two chains in one file. The filter runs **after** parsing: a line too damaged to parse is too damaged to attribute, so every line is still checked and a damaged one raises `TomAuditException` whichever writer wrote it. |

### TomAuditAnchorPublisher

Publishes anchors for a sink's chain on a schedule. Deliberately not a
`TomScheduler` job: the scheduler runs a job once *across the cluster*, whereas
the chain is per `writer` so each node must anchor its own head. Every tick
publishes even when nothing was written, because an anchor over an unchanged
head bounds when a later divergence must have happened.

- **Implements:** `TomClosable`

#### Constructors

```dart
TomAuditAnchorPublisher({
  required TomAuditSink sink,
  required TomAuditAnchorStore store,
  required String writer,
  TomAuditAnchorSigner? signer,
  Duration interval = const Duration(hours: 1),
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `sink` | `TomAuditSink` | The sink whose chain is anchored (final). |
| `store` | `TomAuditAnchorStore` | Where anchors are published (final). |
| `writer` | `String` | The chain's name, matching the sink's own writer identity (final). |
| `signer` | `TomAuditAnchorSigner?` | Signs each anchor before publication, when the deployment has a key (final). |
| `interval` | `Duration` | How often an anchor is published once `start` has been called (final). |
| `lastPublished` | `TomAuditAnchor?` | *(getter)* The most recent anchor this publisher wrote, or `null`. |
| `isScheduled` | `bool` | *(getter)* Whether the periodic schedule is currently armed. The one piece of lifecycle state with no other observable consequence until an interval has elapsed — and a live periodic timer holds the isolate open. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `start` | `Future<void> start()` | Publishes one anchor immediately, then every `interval`. The immediate publication matters: a process compromised and killed inside one interval would otherwise never anchor. Throws `TomAuditException` when the publisher is closed — through `publishNow`, which runs before the timer is armed. |
| `stop` | `void stop()` | Stops the schedule; `publishNow` still works. |
| `publishNow` | `Future<TomAuditAnchor> publishNow()` | Captures the sink's position, signs it when a signer is configured, appends it to the store and returns it. Throws when the store refuses, and throws `TomAuditException` (`audit.anchor.publisher_closed`) once the publisher is closed — this is the single choke point every publication passes through. |
| `publishAndClose` | `Future<void> publishAndClose()` | Cancels the schedule, publishes a final anchor, then closes. The anchor that pins the chain's last head, which a synchronous `close` cannot deliver. A store failure is thrown, unlike the scheduled path; the publisher closes either way. Idempotent, and a no-op after `close`. |
| `close` | `void close()` | *(override)* Cancels the schedule and closes. **Publishes nothing** — `TomClosable`'s contract is synchronous, and a publication started without waiting is one a departing process never finishes. Use `publishAndClose` wherever an `await` is available. |

### TomAuditWriteOnceCheck

What a deployment's audit table actually permits, as observed rather than as
configured. Two independent observations, because neither alone is conclusive: a
privilege probe (a zero-row `UPDATE`/`DELETE`, which still fails at
permission-check time) and a trigger probe of `information_schema.TRIGGERS`,
since a zero-row statement fires no `FOR EACH ROW` trigger.

#### Constructors

```dart
const TomAuditWriteOnceCheck({
  required String table,
  required bool grantsUpdate,
  required bool grantsDelete,
  String? updateGuardTrigger,
  String? deleteGuardTrigger,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `table` | `String` | The table that was probed (final). |
| `grantsUpdate` | `bool` | Whether the connected user may `UPDATE` the table (final). |
| `grantsDelete` | `bool` | Whether the connected user may `DELETE` from the table (final). |
| `updateGuardTrigger` | `String?` | The name of a `BEFORE UPDATE` trigger on the table, when one exists (final). |
| `deleteGuardTrigger` | `String?` | The name of a `BEFORE DELETE` trigger on the table, when one exists (final). |
| `updatesBlocked` | `bool` | *(getter)* Whether an existing entry cannot be rewritten in place — the property that matters most, since an in-place rewrite is the attack the chain alone cannot detect. |
| `deletesBlocked` | `bool` | *(getter)* Whether an existing entry cannot be removed. A weaker requirement, because retention needs `DELETE`. |
| `isAppendOnly` | `bool` | *(getter)* Whether the table admits nothing but inserts. |
| `summary` | `String` | *(getter)* A one-line description of what was found, for start-up logging. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* The `summary` line. |

### TomSqlAuditSink

A `TomAuditSink` whose entries are rows in a `TomDataSource`. It talks to the
data source directly rather than through `TomSqlDatasourceRepository`, which is
itself an audit chokepoint, so the regress is impossible rather than merely
avoided. `writer` is required because a chain has exactly one head: a per-node
chain makes a clustered deployment correct, and the unique key on
`(writer, previous_hash)` turns a fork into a duplicate-key error at insert
time.

**This sink retains nothing on its own.** `TomFileAuditSink` takes `retention`
and `maxFiles` and enforces them itself; here `purgeBefore` and
`purgeToMaxEntries` exist but nothing in the framework calls them, so the trail
table grows without bound until the deployment schedules a purge. That follows
from the write-once story rather than contradicting it: pruning needs a
`DELETE` grant the serving credential should not hold, and a `BEFORE DELETE`
guard trigger blocks the purge outright. The intended home for the call is the
**scheduler** — `TomScheduler` / `@TomScheduledJob` in `tom_core_kernel`, where
an idempotent nightly purge is exactly the shape a job body should have;
`advanced_ops_server`'s `OpsPurgeJob` is the worked pattern. Note that both
purges are scoped to `writer`, so one clustered job trims one node's chain.

- **Implements:** `TomAuditSink`

#### Constructors

```dart
TomSqlAuditSink(
  TomDataSource datasource, {
  required String writer,
  String table = defaultAuditTrailTable,
  bool createSchema = true,
  bool requireWriteOnce = false,
})
```

#### Factory Constructors

```dart
factory TomSqlAuditSink.named(
  String datasourceName, {
  required String writer,
  String table = defaultAuditTrailTable,
  bool createSchema = true,
  bool requireWriteOnce = false,
})
```

`named` resolves a registered data source and throws a `TomServerException` when
none is registered under that name — a configuration error far better caught at
start-up than on the first audited action.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the trail table lives in; should be the sink's own, holding the restricted credential, never the application's (final). |
| `writer` | `String` | The name of the chain this sink appends to; stable across restarts, since the head is recovered by it (final). |
| `table` | `String` | The trail table (final). |
| `createSchema` | `bool` | Whether to create the table on first use; set `false` when the migration module owns the schema, which is what a restricted grant requires (final). |
| `requireWriteOnce` | `bool` | Whether an unprotected table is a start-up failure rather than a warning (final). |
| `headHash` | `String` | *(getter, override)* The hash of the most recently written entry. |
| `entryCount` | `int` | *(getter, override)* Entries written since genesis, recovered from the table. |
| `writeOnceCheck` | `TomAuditWriteOnceCheck?` | *(getter)* What the last `verifyWriteOnce` found, or `null` before `open`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `Future<void> open()` | Provisions the table, runs the write-once probe, and recovers the chain head. Idempotent and awaited by every write; a failed open clears the memo so the next write retries. Warns on a rewritable table, or throws `TomAuditException` when `requireWriteOnce` is set. |
| `write` | `Future<TomAuditEntry> write(TomAuditRecord record)` | *(override)* Inserts one row, serialised through an internal queue so the `(writer, previous_hash)` constraint never has to fire. The returned future carries a `TomAuditException` when the sink is closed or the insert fails; the call itself does not throw. |
| `readAll` | `Future<List<TomAuditEntry>> readAll()` | Reads every retained entry of this writer's chain, ordered by `seq`, oldest first. Throws `TomAuditException` on a row whose record text will not parse. Asynchronous because it is a query, and not a `TomAuditSink` member — read-back is per implementation by design. Reads *every* row, so prefer a bounded window on a large trail. |
| `verify` | `Future<TomAuditChainVerification> verify()` | Verifies the retained entries starting from the oldest retained link, so a retention sweep is not reported as a break. Asynchronous, like `readAll` whose whole result it consumes, and not on `TomAuditSink` either. |
| `purgeBefore` | `Future<int> purgeBefore(DateTime before)` | Deletes this writer's entries recorded before `before`, returning the row count. The cutoff is resolved to a *sequence* boundary first, because deleting by timestamp could punch a hole under clock skew. Never called by the framework — schedule it. |
| `purgeToMaxEntries` | `Future<int> purgeToMaxEntries(int maxEntries)` | Keeps the newest `maxEntries` entries of this writer's chain and deletes the prefix in front of them, returning the row count. Throws `TomAuditException` for a negative limit. Never called by the framework — schedule it. |
| `verifyWriteOnce` | `Future<TomAuditWriteOnceCheck> verifyWriteOnce()` | Observes what the connected user and the table's `BEFORE` triggers actually permit. Called by `open`; exposed so a health check or operator tool can ask without opening a second sink. |
| `close` | `void close()` | *(override)* Marks the sink closed. Every `write` that has *returned* already committed its `INSERT`, so nothing completed is at risk; a record still in the queue is refused with `audit.sink.closed`, because `TomClosable` requires this method to return synchronously and no synchronous method can wait for a queue. The `datasource` is deliberately not closed — it is registered process-wide. |
| `flushAndClose` | `Future<void> flushAndClose()` | *(override)* Closes the sink to new records, waits for the queued ones to be inserted, then returns. The route that stores what `close` has to refuse; like `close`, it leaves the `datasource` open. |
| `toString` | `String toString()` | *(override)* `TomSqlAuditSink(<table>, writer: <writer>)`. |

### TomAuditTrailRow

One row of the audit trail table, as the result mapper materialises it.
Reflected and `@TomDbTable`-annotated because the data source's row mapper
requires both; the annotation values are placeholders, since the real table name
is a constructor argument of `TomSqlAuditSink`.

#### Constructors

```dart
TomAuditTrailRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `entryIndex` | `int` | Column `entry_index` — the entry's position in its writer's chain, counted from genesis. |
| `previousHash` | `String` | Column `previous_hash` — the hash of the preceding entry. |
| `hash` | `String` | Column `hash` — this entry's hash. |
| `record` | `String` | Column `record` — the canonical JSON of the audited record, the authoritative content. |

### TomAuditHeadRow

The columns `TomSqlAuditSink` projects when recovering a chain head. Both come
from the same row in one statement, so they cannot straddle a concurrent insert.

#### Constructors

```dart
TomAuditHeadRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `hash` | `String` | Column `hash` — the newest entry's hash. |
| `entryIndex` | `int` | Column `entry_index` — the newest entry's position, from which the chain's length follows. |

### TomAuditSeqRow

A projected sequence number, used to resolve a retention boundary.

#### Constructors

```dart
TomAuditSeqRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `seq` | `int?` | Column `seq` — nullable, because the aggregate that resolves a retention boundary yields `NULL` when no row matches. |

### TomAuditTriggerRow

One `information_schema.TRIGGERS` row, as the write-once probe reads it.

#### Constructors

```dart
TomAuditTriggerRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `triggerName` | `String` | Column `trigger_name` — the trigger's name. |
| `eventManipulation` | `String` | Column `event_manipulation` — the statement it intercepts: `INSERT`, `UPDATE` or `DELETE`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `tomAuditGenesisHash` | `String` | The hash a chain starts from — sixty-four zeros, the shape of a SHA-256 digest, so a reader never has to special-case the first entry's `previousHash`. |
| `tomAuditRedactedPlaceholder` | `String` | What a redacted value is recorded as (`'***'`). A placeholder rather than an omission, so "changed, and you may not see to what" stays distinguishable from "did not change". |
| `defaultAuditTrailTable` | `String` | The default name of the audit trail table (`'tom_audit_trail'`). |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `verifyAuditChain` | `TomAuditChainVerification verifyAuditChain(Iterable<TomAuditEntry> entries, {String startHash = tomAuditGenesisHash})` | Checks that `entries` form an unbroken chain from `startHash`, reporting a broken link, an edited record or a renumbered chain separately. The index check is not redundant: the index sits outside the hashed payload, so it is the one field an attacker can rewrite without breaking a hash. |
| `parseAuditLines` | `List<TomAuditEntry> parseAuditLines(Iterable<String> lines)` | Parses JSON-Lines audit storage, skipping blank lines and throwing `TomAuditException` on a line that is not a valid entry — a malformed line is itself a finding. The guarantee covers the whole entry, not just its JSON syntax, because `TomAuditEntry.fromJson` defaults no field. |
| `auditDiff` | `({Map<String, Object?> before, Map<String, Object?> after}) auditDiff(Map<String, Object?> before, Map<String, Object?> after)` | The changed fields only, as the narrowed pair a `TomAuditRecord` carries; a key present in just one of the two counts as changed. Free-standing because the repository is the only layer holding both images. |
| `verifyAgainstAnchor` | `TomAuditAnchorVerification verifyAgainstAnchor(Iterable<TomAuditEntry> entries, TomAuditAnchor anchor, {String? writer, TomAuditAnchorVerifier? verifier})` | Checks that `entries` — possibly a retention-pruned suffix — are consistent with `anchor`. Pass `writer` to assert the chain identity and `verifier` to require a signature; omitting `verifier` checks the position only. Every comparison goes through `TomAuditEntry.index`, not a list offset. The checks run in a fixed, most-specific-first order — writer, signature, chain validity, position — and the first failure is the status returned; the chain verification is computed regardless and always reported on `.chain`. |
| `auditTrailTable` | `TomFrameworkTable auditTrailTable(String table)` | The audit trail table declared once: the `CREATE TABLE` the sink issues, its entry `INSERT` and the column list of every read all derive from this descriptor. |
| `auditTrailTableDdl` | `String auditTrailTableDdl(String table)` | The `CREATE TABLE` DDL for `table`, derived from `auditTrailTable`. |
| `auditTrailNoUpdateTriggerName` | `String auditTrailNoUpdateTriggerName(String table)` | The name of the trigger that rejects `UPDATE` on `table` (`trg_<table>_no_update`). |
| `auditTrailNoDeleteTriggerName` | `String auditTrailNoDeleteTriggerName(String table)` | The name of the trigger that rejects `DELETE` on `table` (`trg_<table>_no_delete`). |
| `auditTrailNoUpdateTriggerDdl` | `String auditTrailNoUpdateTriggerDdl(String table)` | A `BEFORE UPDATE` trigger that signals SQLSTATE `45000` on every update. The recommended guard, with no operational cost since nothing in the framework updates an audit row. |
| `auditTrailNoDeleteTriggerDdl` | `String auditTrailNoDeleteTriggerDdl(String table)` | A `BEFORE DELETE` trigger that signals SQLSTATE `45000` on every delete. Only for deployments that never prune: it blocks retention as well as tampering. |
