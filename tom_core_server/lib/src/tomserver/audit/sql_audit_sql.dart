/// The schema of the relational audit trail, and the optional database-side
/// guards that make its table write-once.
///
/// The DDL lives here, in one place, rather than inside the sink: the shipped
/// migration file under `example/audit/migrations/` carries the same text and a
/// test asserts the two have not drifted apart. Same arrangement, and same
/// reason, as `scheduling/sql_scheduling_sql.dart` — a schema that exists twice
/// and is checked once eventually exists in two versions.
library;

/// The default name of the audit trail table.
const String defaultAuditTrailTable = 'tom_audit_trail';

/// The DDL for the audit trail table [table].
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
String auditTrailTableDdl(String table) => '''
CREATE TABLE IF NOT EXISTS $table (
  seq           BIGINT       NOT NULL AUTO_INCREMENT,
  writer        VARCHAR(64)  NOT NULL,
  entry_index   BIGINT       NOT NULL,
  entry_id      VARCHAR(191) NOT NULL,
  recorded_at   DATETIME(6)  NOT NULL,
  actor         VARCHAR(160) NOT NULL,
  action        VARCHAR(16)  NOT NULL,
  target        VARCHAR(160) NOT NULL,
  target_key    VARCHAR(191) NULL,
  outcome       VARCHAR(16)  NOT NULL,
  request_id    VARCHAR(191) NULL,
  previous_hash CHAR(64)     NOT NULL,
  hash          CHAR(64)     NOT NULL,
  record        LONGTEXT     NOT NULL,
  PRIMARY KEY (seq),
  UNIQUE KEY uq_${table}_link (writer, previous_hash),
  UNIQUE KEY uq_${table}_hash (writer, hash),
  UNIQUE KEY uq_${table}_index (writer, entry_index),
  KEY ix_${table}_time (writer, recorded_at),
  KEY ix_${table}_target (target, action),
  KEY ix_${table}_actor (actor)
)''';

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
