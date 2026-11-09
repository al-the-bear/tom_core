/// The schema of the suppression-list table.
///
/// Declared **once**, as a [TomFrameworkTable], like the delivery-correlation
/// table beside it: the DDL the store issues, the column lists its statements
/// interpolate and the schema model the convergence guard compares are derived
/// from this one declaration. The shipped migration under
/// `example/messaging/migrations/` stays hand-written, and
/// `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the suppression-list table.
const String defaultSuppressionTable = 'tom_message_suppression';

/// The suppression-list table [table], declared once.
///
/// Notes on the shape:
///
///  * `(channel, address)` is the primary key: one entry per normalised address
///    on a channel, so suppressing an address twice replaces the entry.
///  * the table is the deployment's, not a tenant's — an address a carrier
///    refuses is refused for every tenant — and `tenant` records whose message
///    failed.
///  * `suppressed_at` is indexed for listing the most recent first.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant` in
///    `datasources/sql_instant.dart`.
TomFrameworkTable suppressionTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'suppressionTable',
  columns: const [
    TomFrameworkColumn('channel', 'VARCHAR(64)'),
    TomFrameworkColumn('address', 'VARCHAR(191)'),
    TomFrameworkColumn('suppressed_at', 'DATETIME(6)'),
    TomFrameworkColumn('message_id', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('remote_id', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('provider_code', 'VARCHAR(64)', nullable: true),
    TomFrameworkColumn('detail', 'TEXT', nullable: true),
    TomFrameworkColumn('tenant', 'VARCHAR(32)', nullable: true),
  ],
  primaryKey: const ['channel', 'address'],
  keys: const [
    TomFrameworkKey('suppressed', ['suppressed_at']),
  ],
);

/// The DDL for the suppression-list table [table].
String suppressionTableDdl(String table) =>
    suppressionTable(table).createTableDdl;
