/// The schema of the delivery-correlation table.
///
/// Declared **once**, as a [TomFrameworkTable], for the same reason the
/// scheduling and OAuth tables are: the DDL the store issues, the column lists
/// its statements interpolate and the schema model the convergence guard
/// compares are all derived from this one declaration. See
/// `datasources/framework_table.dart` for the mechanism and
/// `db_migration/framework_convergence.dart` for what the guard then proves. The
/// shipped migration file under `example/messaging/migrations/` stays
/// hand-written, because a migration is what a DBA applies and must remain
/// readable; `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the delivery-correlation table.
const String defaultDeliveryReportTable = 'tom_delivery_report';

/// The delivery-correlation table [table], declared once.
///
/// Notes on the shape:
///
///  * `remote_id` is the primary key and *is* the row's identity — the only key
///    a carrier callback carries. There is no surrogate key: a second row for
///    one carrier id would make "which message does this report concern" depend
///    on row order, which is the one question the table exists to answer.
///  * `message_id` is what a deployment actually wants back, and is indexed
///    because the other direction — "what became of this message" — is the
///    question a support engineer asks, and it is not the primary key.
///  * `channel` is stored so a deployment routing several carriers through one
///    endpoint can tell whose report it is reading without joining anything.
///  * `state` is nullable, and that is the difference between "sent, nothing
///    heard" and "reported". Defaulting it to a value would erase the
///    distinction that makes an outstanding delivery findable.
///  * `sent_at` carries the sweep, so it is indexed: pruning is otherwise a full
///    scan of a table that grows with every message ever sent.
///  * `tenant` is nullable: a message of no tenant has none.
///  * `addresses` is the JSON array of the addresses the message was sent to,
///    which a failure report suppresses when it names no recipient itself;
///    `provider_code` is the carrier's code from the last report.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant` in
///    `datasources/sql_instant.dart`.
TomFrameworkTable deliveryReportTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'deliveryReportTable',
  kind: TomTableKind.system,
  columns: const [
    TomFrameworkColumn('remote_id', 'VARCHAR(191)'),
    TomFrameworkColumn('message_id', 'VARCHAR(191)'),
    TomFrameworkColumn('channel', 'VARCHAR(64)'),
    TomFrameworkColumn('sent_at', 'DATETIME(6)'),
    TomFrameworkColumn('state', 'VARCHAR(32)', nullable: true),
    TomFrameworkColumn('reported_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('detail', 'TEXT', nullable: true),
    TomFrameworkColumn('tenant', 'VARCHAR(32)', nullable: true),
    TomFrameworkColumn('addresses', 'TEXT', nullable: true),
    TomFrameworkColumn('provider_code', 'VARCHAR(64)', nullable: true),
  ],
  primaryKey: const ['remote_id'],
  keys: const [
    TomFrameworkKey('message', ['message_id']),
    TomFrameworkKey('sent', ['sent_at']),
  ],
);

/// The DDL for the delivery-correlation table [table].
String deliveryReportTableDdl(String table) =>
    deliveryReportTable(table).createTableDdl;
