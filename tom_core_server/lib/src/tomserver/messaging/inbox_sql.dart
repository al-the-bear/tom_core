/// The schema of the idempotent-receiver inbox table.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework table:
/// the DDL the inbox issues, the statements it writes and the schema the
/// convergence guard compares are derived from this declaration. The shipped
/// migration file under `example/messaging/migrations/` stays hand-written;
/// `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the inbox table.
const String defaultInboxTable = 'tom_message_inbox';

/// The inbox table [table], declared once.
///
/// Notes on the shape:
///
///  * a tenant table ([TomTableKind.tenant]): it lives where the tenant's data
///    lives, beside the consumer's work, and every row names its `tenant`
///    (`''` for none) — also where a tenant has a schema of its own, since any
///    tenant may move.
///  * the primary key is `(tenant, consumer, message_id)`, and it is the whole
///    mechanism: recording a message is an insert that the key refuses for a
///    message the consumer already processed in that tenant. Two consumers of
///    one message — a projection and a notifier — each process it once, which
///    is why the consumer is part of the key.
///  * `consumer` is `VARCHAR(150)` so the composite key stays within the index
///    length a `utf8mb4` column allows.
///  * `processed_at` carries the purge, so it is indexed: an inbox keeps a row
///    per message for as long as a redelivery is possible, and pruning older
///    rows must not scan the table.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant` in
///    `datasources/sql_instant.dart`.
TomFrameworkTable inboxTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'inboxTable',
  kind: TomTableKind.tenant,
  columns: const [
    TomFrameworkColumn('tenant', 'VARCHAR(32)', defaultValue: "''"),
    TomFrameworkColumn('consumer', 'VARCHAR(150)'),
    TomFrameworkColumn('message_id', 'VARCHAR(191)'),
    TomFrameworkColumn('processed_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['tenant', 'consumer', 'message_id'],
  keys: const [
    TomFrameworkKey('processed', ['processed_at']),
  ],
);

/// The DDL for the inbox table [table].
String inboxTableDdl(String table) => inboxTable(table).createTableDdl;
