/// The schema of the sync change log and its sequence counters.
///
/// Declared **once**, as [TomFrameworkTable]s, like every framework table; the
/// shipped migration under `example/sync/migrations/` stays hand-written and
/// `test/framework_schema_test.dart` fails if the two drift.
library;

import '../datasources/framework_table.dart';

/// The default name of the change-log table.
const String defaultSyncChangeTable = 'tom_sync_change';

/// The default name of the sequence-counter table.
const String defaultSyncSequenceTable = 'tom_sync_sequence';

/// The change-log table [table], declared once.
///
/// Notes on the shape:
///
///  * one row per change of a synced entity, in the order recorded (`id`).
///    `seq` is its number within its `(tenant, collection)` — the number a
///    device's pull cursor counts — given when a pull numbers the committed
///    changes, `NULL` until then. `tenant` is `''` outside tenancy.
///  * the row records the entity's id, its version after the change and
///    whether the change deleted it — never its values. A pull reads those
///    through the entity's repository, so the reader's row scope, column
///    grades and decryption apply to what it receives.
TomFrameworkTable syncChangeTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'syncChangeTable',
  kind: TomTableKind.tenant,
  columns: const [
    TomFrameworkColumn('id', 'BIGINT', autoIncrement: true),
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
    TomFrameworkColumn('collection', 'VARCHAR(64)'),
    TomFrameworkColumn('seq', 'BIGINT', nullable: true),
    TomFrameworkColumn('entity_id', 'VARCHAR(191)'),
    TomFrameworkColumn('version', 'BIGINT'),
    TomFrameworkColumn('deleted', 'TINYINT(1)', defaultValue: '0'),
    TomFrameworkColumn('changed_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey.unique('seq', ['tenant', 'collection', 'seq']),
  ],
);

/// The sequence-counter table [table], declared once.
///
/// One row per `(tenant, collection)` holding the last number given out. A
/// numbering locks it, so two numberings of a collection run one after the
/// other.
TomFrameworkTable syncSequenceTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'syncSequenceTable',
  kind: TomTableKind.tenant,
  columns: const [
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
    TomFrameworkColumn('collection', 'VARCHAR(64)'),
    TomFrameworkColumn('last_sequence', 'BIGINT'),
  ],
  primaryKey: const ['tenant', 'collection'],
);
