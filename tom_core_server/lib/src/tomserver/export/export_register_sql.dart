/// The relational [TomExportRegister]: one row per stored export, in the
/// database the deployment already has.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../file_storage/blob_store.dart';
import '../object_persistence/persistence_annotations.dart';
import 'export_register.dart';

/// The default name of the export register table.
const String defaultExportRegisterTable = 'tom_export';

/// The export register table [table], declared once.
///
/// Keyed by the storage key, at the blob store's key width. Indexed on
/// `(owner, stored_at)` — a quota sums an owner's rows, a listing reads them
/// newest first — and on `stored_at`, which the retention purge scans oldest
/// first.
TomFrameworkTable exportRegisterTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'exportRegisterTable',
  kind: TomTableKind.system,
  columns: [
    TomFrameworkColumn('export_key', 'VARCHAR(${TomBlobStore.maxKeyLength})'),
    const TomFrameworkColumn('owner', 'VARCHAR(191)', defaultValue: "''"),
    const TomFrameworkColumn('media_type', 'VARCHAR(255)'),
    const TomFrameworkColumn('byte_count', 'BIGINT'),
    const TomFrameworkColumn('stored_at', 'DATETIME(6)'),
    const TomFrameworkColumn('title', 'VARCHAR(255)', nullable: true),
  ],
  primaryKey: const ['export_key'],
  keys: const [
    TomFrameworkKey('owner', ['owner', 'stored_at']),
    TomFrameworkKey('stored', ['stored_at']),
  ],
);

/// The DDL for the export register table [table].
String exportRegisterTableDdl(String table) =>
    exportRegisterTable(table).createTableDdl;

/// A [TomExportRegister] whose records are rows of [table] in [datasource].
class TomSqlExportRegister extends TomExportRegister {
  /// Creates a register over [datasource]; with [createSchema] the table is
  /// created on first use, otherwise the migration module owns it.
  TomSqlExportRegister(
    TomDataSource datasource, {
    this.table = defaultExportRegisterTable,
    this.createSchema = true,
  }) : datasource = TomFrameworkTable.systemOf(datasource);

  /// The data source the table lives in.
  final TomDataSource datasource;

  /// The register table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  late final TomFrameworkTable _rows = exportRegisterTable(table);

  static const Map<String, String> _writeColumns = {
    'export_key': ':key',
    'owner': ':owner',
    'media_type': ':mediaType',
    'byte_count': ':byteCount',
    'stored_at': ':storedAt',
    'title': ':title',
  };

  /// Creates the table if it does not exist; idempotent, and called by every
  /// operation.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) await _rows.create(datasource);
  });

  @override
  Future<void> record(TomExportRecord record) async {
    await ensureSchema();
    await _rows.replaceRow(datasource, _writeColumns, {
      'key': record.key,
      'owner': record.owner,
      'mediaType': record.mediaType,
      'byteCount': record.byteCount,
      'storedAt': sqlInstant(record.storedAt),
      'title': record.title,
    });
  }

  @override
  Future<TomExportRecord?> find(String key) async {
    final rows = await _select('WHERE export_key = :key', {'key': key});
    return rows.isEmpty ? null : rows.single;
  }

  @override
  Future<List<TomExportRecord>> ownedBy(String owner) => _select(
    'WHERE owner = :owner ORDER BY stored_at DESC, export_key',
    {'owner': owner},
  );

  @override
  Future<TomExportUsage> usageOf(String owner) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomExportUsageRow>(
      'SELECT COUNT(*) AS export_count, '
      'COALESCE(SUM(byte_count), 0) AS export_bytes '
      'FROM $table WHERE owner = :owner',
      {'owner': owner},
    );
    final row = rows.single;
    return TomExportUsage(count: row.exportCount, bytes: row.exportBytes);
  }

  @override
  Future<List<TomExportRecord>> storedBefore(
    DateTime before, {
    int limit = 500,
  }) => _select(
    'WHERE stored_at < :before ORDER BY stored_at, export_key LIMIT $limit',
    {'before': sqlInstant(before)},
  );

  @override
  Future<bool> remove(String key) async {
    await ensureSchema();
    final removed = await datasource.executeCommand(
      'DELETE FROM $table WHERE export_key = :key',
      {'key': key},
    );
    return removed > BigInt.zero;
  }

  /// Empties the table — for provisioning and tests.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  Future<List<TomExportRecord>> _select(
    String suffix,
    Map<String, Object?> params,
  ) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomExportRecordRow>(
      'SELECT ${_rows.columnList} FROM $table $suffix',
      params,
    );
    return [
      for (final row in rows)
        TomExportRecord(
          key: row.key,
          owner: row.owner,
          mediaType: row.mediaType,
          byteCount: row.byteCount,
          storedAt: parseSqlInstant(row.storedAt),
          title: row.title,
        ),
    ];
  }
}

/// One row of the export register table, as the driver hands it back.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomExportRecordRow {
  /// The export's storage key.
  @TomDbColumn(columnName: "export_key")
  String key = "";

  /// Who the export counts against.
  @TomDbColumn(columnName: "owner")
  String owner = "";

  /// The export's media type.
  @TomDbColumn(columnName: "media_type")
  String mediaType = "";

  /// Its size.
  @TomDbColumn(columnName: "byte_count")
  int byteCount = 0;

  /// When it was stored, as the stored text.
  @TomDbColumn(columnName: "stored_at")
  String storedAt = "";

  /// The report's title.
  @TomDbColumn(columnName: "title")
  String? title;
}

/// The aggregate row [TomSqlExportRegister.usageOf] reads.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomExportUsageRow {
  /// How many exports.
  @TomDbColumn(columnName: "export_count")
  int exportCount = 0;

  /// Their total size.
  @TomDbColumn(columnName: "export_bytes")
  int exportBytes = 0;
}
