# audit

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Attributable, tamper-evident records of what a deployment did: who changed what,
when, and whether the record has since been altered.

The module has **four layers**, and every type belongs to exactly one. Each
question only arises once the previous one is settled, which is why they are
worth reading in order: what is written down (**record**), when it is written
and what triggers it (**trail**), where it goes (**sink**), and what makes the
result hard to edit undetected (**anchor**).

The two *chokepoints* are what make an audit automatic rather than something a
caller remembers: the endpoint pipeline and the repository write path. A record
produced by hand is possible and is what the example does, but a trail that
depends on being remembered is a trail with holes in exactly the places that
matter.

## Key types

### The record — what is written down

| Type | What it is |
| ---- | ---------- |
| `TomAuditRecord` | One thing that happened: the actor, the action, the entity and key, the before/after values, and the outcome. |
| `TomAuditActor` | Who did it, resolved from the ambient request zone rather than passed in — `TomAuditActor.system` is the deployment acting as itself. |
| `TomAuditAction` · `TomAuditOutcome` | What kind of thing it was, and whether it succeeded. |
| `auditDiff` | The before/after pair reduced to what actually changed, normalised to what `jsonEncode` accepts. |

### The trail — when a record is made

| Type | What it is |
| ---- | ---------- |
| `TomAuditTrail` | The entry point the chokepoints call. `TomAuditRecordIdGenerator` decides what a record is identified by. |
| `TomAudited` | The annotation that makes an entity audited, and names the columns to `redact:` — a redacted value never reaches a sink, so `tomAuditRedactedPlaceholder` is what a reader sees. |
| `TomAuditPolicy` | Which entities are audited and how much of them, when the annotation is not the whole answer. |
| `TomAuditBypass` | The deliberate, scoped opt-out — a bulk import that would otherwise write a million records. |

### The sink — where it goes

| Type | What it is |
| ---- | ---------- |
| `TomAuditSink` | The contract. Every sink reports a failure through the future it returns rather than throwing past its caller, because an audit failure must not become the application's exception. |
| `TomAuditEntry` | One record as a sink stores it: the record plus its position in the hash chain. |
| `TomMemoryAuditSink` · `TomFileAuditSink` | The two sinks needing no database — the second appends, and its retention operates on whole files. |
| `TomSqlAuditSink` | The relational sink, over the table `auditTrailTable` declares and `auditTrailTableDdl` renders. `TomAuditWriteOnceCheck` reports whether the deployment's triggers actually forbid `UPDATE` and `DELETE`. |
| `TomAuditChainVerification` | Whether the chain still verifies, and where it first does not. |

### The anchor — what the chain alone cannot catch

A hash chain catches an edit *within* the trail. It cannot catch a trail
truncated and rebuilt from scratch, because a consistent chain is exactly what
the rebuilder produces. An anchor is a signed statement about the head at a
point in time, kept somewhere the trail's writer cannot reach.

| Type | What it is |
| ---- | ---------- |
| `TomAuditAnchor` | One signed statement: the head hash, the sequence it was at, and when. |
| `TomAuditAnchorSigner` · `TomAuditAnchorVerifier` | How one is signed and checked; `TomRsaAuditAnchorSigner` is the shipped pair. |
| `TomAuditAnchorStore` | Where anchors live — `TomMemoryAuditAnchorStore` and `TomFileAuditAnchorStore` ship. `TomAuditAnchorPublisher` writes them on a cadence. |
| `TomAuditAnchorMonitor` | Reads the anchors back and reports what they say about the chain today, through `TomAuditAnchorCheck` / `TomAuditAnchorReport`. |
| `verifyAuditChain` · `verifyAgainstAnchor` | The two verifications, kept separate because they answer different questions. |

## Quick start

```dart
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final sink = TomMemoryAuditSink();
  await sink.write(
    TomAuditRecord(
      id: 'audit-1',
      timestamp: DateTime.now(),
      actor: TomAuditActor.system,
      action: TomAuditAction.update,
      target: 'Invoice',
      targetKey: '42',
      outcome: TomAuditOutcome.succeeded,
      before: {'total': 19.99},
      after: {'total': 24.99},
    ),
  );

  print(sink.entries.single.record.target); // Invoice
  print(sink.verify().isValid);             // true — the chain is intact
}
```

See [`doc/audit.md`](../../../../doc/audit.md) for the full treatment: the four
layers in order, the chokepoints, redaction, the hash chain, the write-once
guarantee and what an anchor adds. The connection-free surface runs in
`example/audit/audit_example.dart`; `test/audit_test.dart`,
`test/audit_anchor_test.dart` and `test/audit_anchor_monitor_test.dart` cover it
without a server, and `test/audit_sql_db_test.dart` and `test/audit_db_test.dart`
cover the relational sink and the repository chokepoint against a live MariaDB.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
