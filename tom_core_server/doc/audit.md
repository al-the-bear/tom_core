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
- [The Chokepoints](#the-chokepoints)
- [Declared Versus Automatic](#declared-versus-automatic)
- [The `@TomAudited` Annotation](#the-tomaudited-annotation)
- [Attribution](#attribution)
- [Sinks, Persistence and Retention](#sinks-persistence-and-retention)
- [The Relational Sink](#the-relational-sink)
- [The Write-Once Story](#the-write-once-story)
- [Tamper Evidence](#tamper-evidence)
- [Failure Behaviour](#failure-behaviour)
- [Suppressing the Trail](#suppressing-the-trail)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomAuditRecord` | class | One auditable action: actor, action, target, outcome, before/after |
| `TomAuditActor` | class | Who acted — resolved from the `TomPrincipal`, or `SYSTEM` |
| `TomAuditAction` / `TomAuditOutcome` | enums | `create`/`update`/`delete`/`read`/`execute`; `succeeded`/`failed`/`denied` |
| `TomAudited` | annotation | The *declaration*: opt an endpoint or entity in, out, or redact fields |
| `TomAuditPolicy` | class | The resolved effective policy for one entity type |
| `TomAuditTrail` | class | The static facade the chokepoints call |
| `TomAuditSink` | abstract class | Where entries go |
| `TomMemoryAuditSink` / `TomFileAuditSink` | classes | Bounded in-memory sink; append-only rotating file sink |
| `TomSqlAuditSink` | class | One row per entry in a `TomDataSource`, with row-prefix retention |
| `TomAuditWriteOnceCheck` | class | What a deployment's audit table actually permits, as observed |
| `TomAuditEntry` | class | A record plus its position in the hash chain |
| `TomAuditChainVerification` | class | The result of verifying a chain |

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
| Repository read | Not audited | `@TomAudited(includeReads: true)` on the entity |

The asymmetry is the point:

- **Mutations are on by default** because forgetting to declare one is a silent
  gap in the record, and a gap is exactly what an audit trail exists to prevent.
  Opting out is a deliberate, visible act.
- **Reads and invocations are off by default** because most of them are routine
  traffic. A list endpoint over a thousand rows would otherwise write a thousand
  entries saying nothing, and a trail nobody can read is a trail nobody audits.
  Which reads matter is a domain judgement, so the domain declares it.
- **Denials are unconditional** because they are the entry an auditor looks for
  first, and a system that let a component opt out of recording its own refusals
  would be answering "was this attempted?" with silence.

## The `@TomAudited` Annotation

```dart
@tomReflector
@TomAudited(redact: ['passwordHash'])
@TomDbTable(datasource: 'main', table: 'users', primaryKeyField: 'id')
class User { … }

@tomReflector
@TomAudited(enabled: false)          // high-volume machine-written table
class SessionRow { … }

abstract class AdminApi {
  @TomAudited()                      // this *invocation* is the auditable act
  @TomEndpoint(methods: [TomHttpMethod.post], uri: '/admin/grant')
  Future<void> grant(int userId, String role);
}
```

| Parameter | Meaning |
| --------- | ------- |
| `enabled` | `false` opts the type out entirely (default `true`) |
| `includeReads` | `true` audits reads as well as mutations (default `false`) |
| `redact` | Field names whose *values* never enter the trail |

`redact` is not a column grade. A C-4 column grade hides a value from the
caller; redaction keeps it from existing in a *second* place at all — password
hashes, access tokens, keys. The record still shows that the field changed; the
values on both sides are replaced by `tomAuditRedactedPlaceholder` (`'***'`), so
"changed, and you may not see to what" stays distinguishable from "did not
change".

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
- `TomRequestId` from the zone supplies `requestId`, which stitches every entry
  written during one request together.

A write outside a request — a background job, a migration — is attributed to
`TomAuditActor.system` (username `SYSTEM`), never to a blank or null actor. The
`-1` sentinel `TomPrincipal` uses for its unset ids is normalised to `null` and
then omitted, so the trail never claims a user id that does not exist.

## Sinks, Persistence and Retention

`TomAuditSink` has three implementations:

- **`TomMemoryAuditSink`** — bounded ring (default 1000 entries) with a
  `droppedCount`. For tests and short-lived processes.
- **`TomFileAuditSink`** — append-only JSON Lines under a directory, one file
  per day, rotated at `maxFileBytes` (default 16 MiB). Writes are serialised
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

Rotation sequence numbers are monotonic and never reused, including after
retention has deleted the file that held one — a reused number would let a new
file take an older file's name, and read-back order would stop matching write
order.

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
the audited action down with it.

Three design points are worth stating outright:

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

Reference migrations live in `example/audit/migrations/main/tomcore/`.

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
| **Database-side guard** | `BEFORE UPDATE` / `BEFORE DELETE` triggers that `SIGNAL SQLSTATE '45000'` | A deployment that cannot separate credentials: one application user, one schema, `UPDATE` already granted across it |
| **Explicit acceptance** | Nothing. The trail is tamper-*evident* only | Development and test, where operational convenience genuinely outweighs tamper-resistance — and stated as such, never assumed |

**The separate credential is the primary mechanism.** Apply the migration with a
privileged credential, then serve the trail with a restricted one:

```sql
CREATE USER 'audit_writer'@'%' IDENTIFIED BY '…';
GRANT INSERT, SELECT ON app_db.tom_audit_trail TO 'audit_writer'@'%';
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

The two guards are tagged separately because they cost differently. The `UPDATE`
guard costs nothing. The `DELETE` guard **blocks retention entirely** — both
`purgeBefore` and `purgeToMaxEntries` issue `DELETE` — so installing it is a
decision to keep the trail forever, or to prune out of band with a role that
drops the trigger, prunes, and recreates it.

### Retention is an operator action

The restricted serving credential has no `DELETE`, which is the point — and it
means **retention cannot be run by the server that writes the trail**. Calling
`purgeToMaxEntries` on a correctly restricted sink fails, loudly, which is the
right outcome and a surprising one to meet for the first time in production.
Pruning is an operator task performed with a separate, privileged credential.

### What the sink checks, and what it does about it

`verifyWriteOnce()` observes the deployment rather than trusting its
configuration, and returns a `TomAuditWriteOnceCheck`. It makes two independent
observations, because neither alone is conclusive:

- a **privilege** probe — an `UPDATE`/`DELETE` restricted to no rows, which
  still fails at permission-check time when the grant is missing; and
- a **trigger** probe of `information_schema.TRIGGERS`, because a zero-row
  statement matches nothing and therefore fires no `FOR EACH ROW` trigger. A
  trigger-protected table looks perfectly mutable to the privilege probe alone.

`open()` runs the check and, when the table can be rewritten in place, either
**warns** or — with `requireWriteOnce: true` — **refuses to start**. The default
is the warning: a sink that refused to start on a developer machine would push
people towards installing no sink at all, and an unprotected trail is still
better than no trail. A deployment that has made the arrangement should set the
flag, because a silently mis-granted credential is precisely the failure it
exists to catch.

## Tamper Evidence

Each entry stores the previous entry's hash, and its own
`sha256('$previousHash|${jsonEncode(record.toJson())}')`. The chain starts at
`tomAuditGenesisHash` (64 zeros). `verifyAuditChain` / `sink.verify()` return a
`TomAuditChainVerification` naming the index at which a chain first breaks.

This is **evidence, not proof**. An attacker who can rewrite the whole file can
recompute every hash. What the chain makes impossible is the realistic attack —
editing, removing or reordering *one* entry — because doing so invalidates every
hash after it. Cryptographic proof would need the head hash published somewhere
the attacker does not control; the chain is the part the framework can provide.

## Failure Behaviour

The trail is **fail-closed**: if the sink cannot store a record, the audited
action fails. A `TomAuditException` from the sink propagates out of the
repository or endpoint call rather than being swallowed. An action that
completed without leaving a record is precisely the outcome the trail exists to
make impossible, so the framework prefers to refuse the action.

With **no sink installed** the trail is a no-op — `TomAuditTrail.record`
returns immediately and every chokepoint behaves exactly as before. Auditing is
switched on by installing a sink at startup:

```dart
TomAuditTrail.install(TomFileAuditSink(Directory('/var/audit/app')));
```

## Suppressing the Trail

`TomAuditTrail.runUnaudited(body)` runs `body` in a zone carrying a
`TomAuditBypass`, so nothing inside it is recorded. It exists for one purpose:
letting the trail's own machinery persist without auditing itself into an
infinite regress. It is not a general opt-out — the declaration-based
`@TomAudited(enabled: false)` is, precisely because it is visible in the source
and therefore auditable in its own right.

## Core Components

- **`TomAuditRecord` / `TomAuditActor` / `TomAuditAction` / `TomAuditOutcome`**
  — the record shape and its JSON round-trip.
- **`TomAudited` / `TomAuditPolicy` / `tomAuditRedactedPlaceholder`** — the
  declaration and its resolved form.
- **`TomAuditTrail`** — `install` / `uninstall` / `record` / `recordMutation` /
  `recordAction` / `policyFor` / `runUnaudited`; the only thing the chokepoints
  touch.
- **`auditDiff`** — computes the changed-fields-only before/after pair.
- **`TomAuditSink` / `TomMemoryAuditSink` / `TomFileAuditSink` /
  `TomSqlAuditSink`** — storage.
- **`TomAuditWriteOnceCheck` / `auditTrailTableDdl` /
  `auditTrailNoUpdateTriggerDdl` / `auditTrailNoDeleteTriggerDdl`** — the
  relational trail's schema and its write-once probe.
- **`TomAuditEntry` / `verifyAuditChain` / `parseAuditLines` /
  `TomAuditChainVerification`** — the hash chain and its verification.
- **`TomAuditException`** — a sink that could not store a record.

## Not Yet Implemented

- Query/export of the trail (overlaps CE-RP reporting — see `csex11`).
- Signed or externally anchored chain heads, which is what would turn the
  tamper-*evidence* above into tamper-*proof*.

## Dependencies

- `tom_core_kernel` — `TomPrincipal`, `TomUser`, `getFromCurrentZone`,
  `TomClosable`, `tomReflector` (policy resolution by mirror).
- `crypto` — SHA-256 for the hash chain.
- The endpoints module — `TomEndpointHandler` calls the trail at the denial and
  declared-invocation points.
- The object-persistence module — `TomSqlDatasourceRepository` calls the trail
  on every mutation.
- The datasources module — `TomSqlAuditSink` writes through a `TomDataSource`
  directly, and encodes instants with `sqlInstant`.
