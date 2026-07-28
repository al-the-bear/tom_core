/// The schema of the relational audit trail, and the optional database-side
/// guards that make its table write-once.
///
/// The table is declared **once**, as a [TomFrameworkTable]: the DDL the sink
/// issues, the column lists its statements interpolate, and the schema model the
/// convergence guard compares are all derived from that one declaration. Same
/// arrangement, and same reason, as `scheduling/sql_scheduling_sql.dart` — a
/// schema that exists twice and is checked once eventually exists in two
/// versions. The shipped migration file under `example/audit/migrations/` stays
/// hand-written, because a migration is what a DBA applies and must remain
/// readable; a test asserts it has not drifted from the descriptor.
library;

import '../datasources/framework_table.dart';

/// The default name of the audit trail table.
const String defaultAuditTrailTable = 'tom_audit_trail';

/// The audit trail table [table], declared once.
///
/// Notes on the shape, because each column and each key earns its place:
///
///  * `seq` is an `AUTO_INCREMENT` surrogate and **is** the primary key here,
///    unlike `tom_job_run` where it is merely an ordering. Nothing addresses an
///    audit row by anything else — the trail is never updated and never joined
///    — while *insertion order* is load-bearing twice over: it is the order the
///    chain is read back in, and it is the order retention trims a prefix from.
///  * `writer` names the chain a row belongs to. Two processes appending to one
///    table each continue their own head, so without this column their entries
///    would interleave into a sequence that verifies as broken. Splitting by
///    writer makes a multi-node deployment correct rather than forbidden.
///  * `entry_index` is the entry's position in its writer's chain, counted from
///    genesis. It is **not** `seq`: `seq` is a table-wide surrogate shared by
///    every writer and consumed by rolled-back inserts, whereas the index is
///    per-chain and gapless, which is what an anchor's `entryCount` is a claim
///    about. Unique per writer, so a replayed insert cannot land twice at one
///    position — the same argument as the link key, applied to position instead
///    of linkage.
///  * the **unique key on `(writer, previous_hash)`** is what makes chain
///    linearity a database invariant. Two entries claiming the same predecessor
///    is a *fork* — the shape a replayed or duplicated write produces — and as a
///    constraint it becomes a duplicate-key error at insert time instead of
///    silent corruption discovered at the next verification. The companion key
///    on `(writer, hash)` catches the same event from the other side.
///  * `record` is the canonical JSON that was hashed, and is authoritative. The
///    projection columns (`actor`, `action`, `target`, `target_key`, `outcome`,
///    `request_id`) are a lossy index for operators: they are truncated to fit,
///    so a query may narrow a search but may never be treated as the record.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant`
///    in `datasources/sql_instant.dart`.
///  * the indexed string widths (`writer` 64, `actor` and `target` 160) keep
///    every key inside the 767-byte limit of older InnoDB row formats:
///    `(writer, previous_hash)` is 64×4 + 64×4 = 512 bytes, `(target, action)`
///    is 160×4 + 16×4 = 704. `target_key` is deliberately *not* indexed —
///    `(target, target_key)` would not fit.
TomFrameworkTable auditTrailTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'auditTrailTable',
  columns: const [
    TomFrameworkColumn('seq', 'BIGINT', autoIncrement: true),
    TomFrameworkColumn('writer', 'VARCHAR(64)'),
    TomFrameworkColumn('entry_index', 'BIGINT'),
    TomFrameworkColumn('entry_id', 'VARCHAR(191)'),
    TomFrameworkColumn('recorded_at', 'DATETIME(6)'),
    TomFrameworkColumn('actor', 'VARCHAR(160)'),
    TomFrameworkColumn('action', 'VARCHAR(16)'),
    TomFrameworkColumn('target', 'VARCHAR(160)'),
    TomFrameworkColumn('target_key', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('outcome', 'VARCHAR(16)'),
    TomFrameworkColumn('request_id', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('previous_hash', 'CHAR(64)'),
    TomFrameworkColumn('hash', 'CHAR(64)'),
    TomFrameworkColumn('record', 'LONGTEXT'),
  ],
  primaryKey: const ['seq'],
  keys: const [
    TomFrameworkKey.unique('link', ['writer', 'previous_hash']),
    TomFrameworkKey.unique('hash', ['writer', 'hash']),
    TomFrameworkKey.unique('index', ['writer', 'entry_index']),
    TomFrameworkKey('time', ['writer', 'recorded_at']),
    TomFrameworkKey('target', ['target', 'action']),
    TomFrameworkKey('actor', ['actor']),
  ],
);

/// The DDL for the audit trail table [table].
String auditTrailTableDdl(String table) => auditTrailTable(table).createTableDdl;

/// The name of the trigger that rejects `UPDATE` on [table].
String auditTrailNoUpdateTriggerName(String table) => 'trg_${table}_no_update';

/// The name of the trigger that rejects `DELETE` on [table].
String auditTrailNoDeleteTriggerName(String table) => 'trg_${table}_no_delete';

/// A `BEFORE UPDATE` trigger that refuses every update of [table].
///
/// The **recommended** guard, and the one with no operational cost: nothing in
/// this framework ever updates an audit row, so a deployment loses nothing by
/// making the operation impossible. It is defence in depth rather than the
/// primary mechanism — a connection with `SUPER`/`TRIGGER` can drop it — but it
/// closes the case the grant cannot, namely a deployment that has to serve the
/// trail through a credential which already holds `UPDATE` on the schema.
String auditTrailNoUpdateTriggerDdl(String table) => '''
CREATE TRIGGER IF NOT EXISTS ${auditTrailNoUpdateTriggerName(table)}
BEFORE UPDATE ON $table
FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'audit trail is append-only: UPDATE is not permitted' ''';

/// A `BEFORE DELETE` trigger that refuses every delete of [table].
///
/// Only for deployments that never prune. It blocks retention as well as
/// tampering — `TomSqlAuditSink.purgeBefore` and `purgeToMaxEntries` both issue
/// `DELETE` — so installing it is a decision to keep the trail forever, which
/// is why it is separate from the update guard rather than bundled with it.
String auditTrailNoDeleteTriggerDdl(String table) => '''
CREATE TRIGGER IF NOT EXISTS ${auditTrailNoDeleteTriggerName(table)}
BEFORE DELETE ON $table
FOR EACH ROW
  SIGNAL SQLSTATE '45000'
  SET MESSAGE_TEXT = 'audit trail is append-only: DELETE is not permitted' ''';
