/// The schema of the cache-invalidation log.
///
/// Declared **once**, as a [TomFrameworkTable], for the same reason the
/// scheduling and messaging tables are: the DDL the channel issues, the column
/// lists its statements interpolate and the schema model the convergence guard
/// compares are all derived from this one declaration. See
/// `datasources/framework_table.dart` for the mechanism. The shipped migration
/// under `example/cache/migrations/` stays hand-written, and
/// `test/framework_schema_test.dart` fails if the two drift apart.
library;

import '../datasources/framework_table.dart';

/// The default name of the cache-invalidation log.
const String defaultInvalidationTable = 'tom_cache_invalidation';

/// The cache-invalidation log [table], declared once.
///
/// Notes on the shape:
///
///  * `id` is an auto-increment key, and it is what every node reads by: each
///    remembers the highest id it has seen and asks for the rows above it. An
///    instant could not do that job — two nodes' clocks disagree, and two rows
///    written in one microsecond would tie.
///  * `raised_at` carries the retention sweep and the start-up catch-up of
///    revocations still in force, so it is indexed.
///  * `entry_key` is nullable: only a single-entry invalidation names a key.
///  * instants are `DATETIME(6)` and always written in UTC — see `sqlInstant`
///    in `datasources/sql_instant.dart`.
TomFrameworkTable invalidationTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'invalidationTable',
  columns: const [
    TomFrameworkColumn('id', 'BIGINT', autoIncrement: true),
    TomFrameworkColumn('kind', 'VARCHAR(16)'),
    TomFrameworkColumn('target', 'VARCHAR(191)'),
    TomFrameworkColumn('entry_key', 'VARCHAR(512)', nullable: true),
    TomFrameworkColumn('origin', 'VARCHAR(32)'),
    TomFrameworkColumn('raised_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey('raised', ['raised_at']),
  ],
);

/// The DDL for the cache-invalidation log [table].
String invalidationTableDdl(String table) =>
    invalidationTable(table).createTableDdl;
