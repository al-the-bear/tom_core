/// The schema of the idempotency-key table.
///
/// Declared **once**, as a [TomFrameworkTable], like every framework table;
/// the shipped migration under `example/endpoints/migrations/` stays
/// hand-written and `test/framework_schema_test.dart` fails if the two drift.
library;

import '../datasources/framework_table.dart';

/// The default name of the idempotency-key table.
const String defaultIdempotencyTable = 'tom_idempotency_key';

/// The idempotency-key table [table], declared once.
///
/// Notes on the shape:
///
///  * the primary key is `(tenant, principal, operation, idem_key)`: a key is
///    the caller's, for one named operation, so two callers — or one caller on
///    two operations — never meet on a key. `tenant` is `''` outside tenancy.
///    The column widths keep the composite key within the index length a
///    `utf8mb4` column allows.
///  * `request_hash` is the SHA-256 of the method, path, query and body of the
///    first request, which is how a key reused for a different request is
///    recognised.
///  * `state` is `in_progress` while the first request runs and `completed`
///    once its response is stored; `status`, `headers` (JSON) and `body`
///    (base64) are that response, `NULL` until then.
///  * `expires_at` carries the retention and the purge, so it is indexed.
TomFrameworkTable idempotencyTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'idempotencyTable',
  columns: const [
    TomFrameworkColumn('tenant', 'VARCHAR(32)'),
    TomFrameworkColumn('principal', 'VARCHAR(150)'),
    TomFrameworkColumn('operation', 'VARCHAR(191)'),
    TomFrameworkColumn('idem_key', 'VARCHAR(191)'),
    TomFrameworkColumn('request_hash', 'VARCHAR(64)'),
    TomFrameworkColumn('state', 'VARCHAR(16)'),
    TomFrameworkColumn('status', 'INT', nullable: true),
    TomFrameworkColumn('headers', 'TEXT', nullable: true),
    TomFrameworkColumn('body', 'LONGTEXT', nullable: true),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
    TomFrameworkColumn('expires_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['tenant', 'principal', 'operation', 'idem_key'],
  keys: const [
    TomFrameworkKey('expiry', ['expires_at']),
  ],
);

/// The DDL for the idempotency-key table [table].
String idempotencyTableDdl(String table) =>
    idempotencyTable(table).createTableDdl;
