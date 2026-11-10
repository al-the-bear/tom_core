/// The schema of the data-key table of field-level encryption.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework table;
/// the shipped migration under `example/object_persistence/migrations/` stays
/// hand-written and `test/framework_schema_test.dart` fails if the two drift.
library;

import '../datasources/framework_table.dart';

/// The default name of the data-key table.
const String defaultEncryptionKeyTable = 'tom_encryption_key';

/// The data-key table [table], declared once.
///
/// Notes on the shape:
///
///  * one row per data key: `purpose` is `encryption` (the keys values are
///    encrypted under) or `blindIndex` (the key blind indexes are computed
///    with), and `state` is `active` for the key new values use and `previous`
///    for a key kept so older values still decrypt.
///  * `wrapped_key` is the data key encrypted under the key-encryption key
///    `kek_id` names (base64): the table never holds a usable key, and a
///    database dump without the key-encryption key decrypts nothing.
///  * `(purpose, state)` is indexed: a keyring reads the active keys first.
TomFrameworkTable encryptionKeyTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'encryptionKeyTable',
  kind: TomTableKind.tenant,
  columns: const [
    TomFrameworkColumn('tenant', 'VARCHAR(32)', defaultValue: "''"),
    TomFrameworkColumn('key_id', 'VARCHAR(64)'),
    TomFrameworkColumn('purpose', 'VARCHAR(16)'),
    TomFrameworkColumn('state', 'VARCHAR(16)'),
    TomFrameworkColumn('kek_id', 'VARCHAR(128)'),
    TomFrameworkColumn('wrapped_key', 'VARCHAR(255)'),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['tenant', 'key_id'],
  keys: const [
    TomFrameworkKey('purpose_state', ['purpose', 'state']),
  ],
);

/// The DDL for the data-key table [table].
String encryptionKeyTableDdl(String table) =>
    encryptionKeyTable(table).createTableDdl;
