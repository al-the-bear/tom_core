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

`TomAuditSink` has two implementations:

- **`TomMemoryAuditSink`** — bounded ring (default 1000 entries) with a
  `droppedCount`. For tests and short-lived processes.
- **`TomFileAuditSink`** — append-only JSON Lines under a directory, one file
  per day, rotated at `maxFileBytes` (default 16 MiB). Writes are serialised
  through an internal queue so concurrent callers cannot interleave, and the
  head hash is recovered from disk on reopen, so a restart continues the chain
  rather than starting a new one.

Retention is `TomFileAuditSink`'s own, expressed in whole files: entries older
than `retention` (default 3650 days ≈ 10 years) and files beyond `maxFiles`
(default 512) are deleted **whole**. Deleting whole files leaves a valid
*suffix* of the chain, which still verifies; deleting individual entries would
break it and be indistinguishable from tampering.

Rotation sequence numbers are monotonic and never reused, including after
retention has deleted the file that held one — a reused number would let a new
file take an older file's name, and read-back order would stop matching write
order.

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
- **`TomAuditSink` / `TomMemoryAuditSink` / `TomFileAuditSink`** — storage.
- **`TomAuditEntry` / `verifyAuditChain` / `parseAuditLines` /
  `TomAuditChainVerification`** — the hash chain and its verification.
- **`TomAuditException`** — a sink that could not store a record.

## Not Yet Implemented

- A database-backed sink. The file sink is append-only by construction, which a
  table is not; a DB sink needs its own write-once story (a separate schema, or
  an insert-only grant) before it is worth having.
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
