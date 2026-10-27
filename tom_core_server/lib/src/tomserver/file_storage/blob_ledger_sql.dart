/// The relational [TomBlobLedger]: one row per logical key and one per
/// distinct content, in the database the deployment already has.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../object_persistence/persistence_annotations.dart';
import 'blob_key_like.dart';
import 'blob_ledger.dart';
import 'blob_store.dart';

/// The default name of the ledger's key table.
const String defaultBlobLedgerTable = 'tom_blob_ledger';

/// The default name of the ledger's content table.
const String defaultBlobContentTable = 'tom_blob_content';

/// The ledger's key table [table], declared once.
///
/// Keyed by the logical key, at the blob store's key width. Indexed on
/// `(owner, stored_at)` for a quota's sum, on `content_digest` for the
/// reclaim's "does anything still name this content", and on `stored_at`.
TomFrameworkTable blobLedgerTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'blobLedgerTable',
  columns: [
    TomFrameworkColumn('blob_key', 'VARCHAR(${TomBlobStore.maxKeyLength})'),
    const TomFrameworkColumn('owner', 'VARCHAR(191)', defaultValue: "''"),
    const TomFrameworkColumn('content_digest', 'CHAR(64)'),
    TomFrameworkColumn('content_key', 'VARCHAR(${TomBlobStore.maxKeyLength})'),
    const TomFrameworkColumn('byte_count', 'BIGINT'),
    const TomFrameworkColumn('media_type', 'VARCHAR(255)'),
    const TomFrameworkColumn('file_name', 'VARCHAR(255)', nullable: true),
    const TomFrameworkColumn('stored_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['blob_key'],
  keys: const [
    TomFrameworkKey('owner', ['owner', 'stored_at']),
    TomFrameworkKey('content', ['content_digest']),
    TomFrameworkKey('stored', ['stored_at']),
  ],
);

/// The ledger's content table [table], declared once.
///
/// Keyed by the content's SHA-256; indexed on `claimed_at`, which the reclaim
/// reads oldest first.
TomFrameworkTable blobContentTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'blobContentTable',
  columns: [
    const TomFrameworkColumn('content_digest', 'CHAR(64)'),
    TomFrameworkColumn('content_key', 'VARCHAR(${TomBlobStore.maxKeyLength})'),
    const TomFrameworkColumn('byte_count', 'BIGINT'),
    const TomFrameworkColumn('claimed_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['content_digest'],
  keys: const [
    TomFrameworkKey('claimed', ['claimed_at']),
  ],
);

/// The DDL for the ledger's key table [table].
String blobLedgerTableDdl(String table) =>
    blobLedgerTable(table).createTableDdl;

/// The DDL for the ledger's content table [table].
String blobContentTableDdl(String table) =>
    blobContentTable(table).createTableDdl;

/// A [TomBlobLedger] whose entries and contents are rows of [ledgerTable] and
/// [contentTable] in [datasource].
///
/// Every check that guards content against a concurrent writer is one
/// statement, so it holds across processes: [claimContent] stamps the claim
/// before it reads, and [dropContent] deletes only while the content is still
/// unnamed and unclaimed.
class TomSqlBlobLedger extends TomBlobLedger {
  /// Creates a ledger over [datasource]; with [createSchema] the tables are
  /// created on first use, otherwise the migration module owns them.
  TomSqlBlobLedger(
    this.datasource, {
    this.ledgerTable = defaultBlobLedgerTable,
    this.contentTable = defaultBlobContentTable,
    this.createSchema = true,
  });

  /// The data source the tables live in.
  final TomDataSource datasource;

  /// The key table.
  final String ledgerTable;

  /// The content table.
  final String contentTable;

  /// Whether to create the tables on first use.
  final bool createSchema;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  late final TomFrameworkTable _entries = blobLedgerTable(ledgerTable);
  late final TomFrameworkTable _contents = blobContentTable(contentTable);

  static const Map<String, String> _entryColumns = {
    'blob_key': ':key',
    'owner': ':owner',
    'content_digest': ':digest',
    'content_key': ':contentKey',
    'byte_count': ':byteCount',
    'media_type': ':mediaType',
    'file_name': ':fileName',
    'stored_at': ':storedAt',
  };

  static const Map<String, String> _contentColumns = {
    'content_digest': ':digest',
    'content_key': ':contentKey',
    'byte_count': ':byteCount',
    'claimed_at': ':now',
  };

  /// Creates the tables if they do not exist; idempotent, and called by every
  /// operation.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (!createSchema) return;
    await _entries.create(datasource);
    await _contents.create(datasource);
  });

  @override
  Future<TomBlobLedgerEntry?> find(String key) async {
    final rows = await _selectEntries('WHERE blob_key = :key', {'key': key});
    return rows.isEmpty ? null : rows.single;
  }

  @override
  Future<void> record(TomBlobLedgerEntry entry) async {
    await ensureSchema();
    await _entries.replaceRow(datasource, _entryColumns, {
      'key': entry.key,
      'owner': entry.owner,
      'digest': entry.digest,
      'contentKey': entry.contentKey,
      'byteCount': entry.byteCount,
      'mediaType': entry.mediaType,
      'fileName': entry.fileName,
      'storedAt': sqlInstant(entry.storedAt),
    });
  }

  @override
  Future<TomBlobLedgerEntry?> remove(String key) async {
    final entry = await find(key);
    if (entry == null) return null;
    final removed = await datasource.executeCommand(
      'DELETE FROM $ledgerTable WHERE blob_key = :key',
      {'key': key},
    );
    return removed > BigInt.zero ? entry : null;
  }

  @override
  Future<int> removePrefix(String prefix) async {
    await ensureSchema();
    final removed = await datasource.executeCommand(
      'DELETE FROM $ledgerTable '
      'WHERE blob_key = :key OR blob_key LIKE :under ESCAPE \'!\'',
      {'key': prefix, 'under': '${escapeBlobKeyLike(prefix)}/%'},
    );
    return removed.toInt();
  }

  @override
  Future<TomBlobUsage> usageOf(String owner) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomBlobUsageRow>(
      'SELECT COUNT(*) AS blob_count, '
      'COALESCE(SUM(byte_count), 0) AS blob_bytes '
      'FROM $ledgerTable WHERE owner = :owner',
      {'owner': owner},
    );
    final row = rows.single;
    return TomBlobUsage(count: row.blobCount, bytes: row.blobBytes);
  }

  @override
  Future<List<TomBlobLedgerEntry>> storedBefore(
    DateTime before, {
    String after = '',
    int limit = 500,
  }) => _selectEntries(
    'WHERE stored_at < :before AND blob_key > :after '
    'ORDER BY blob_key LIMIT $limit',
    {'before': sqlInstant(before), 'after': after},
  );

  @override
  Future<int> referencesTo(String digest) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomBlobReferenceCountRow>(
      'SELECT COUNT(*) AS reference_count FROM $ledgerTable '
      'WHERE content_digest = :digest',
      {'digest': digest},
    );
    return rows.single.referenceCount;
  }

  @override
  Future<TomBlobContent?> claimContent(
    String digest, {
    required int byteCount,
    required String contentKey,
    required DateTime now,
    bool create = true,
  }) async {
    await ensureSchema();
    final params = {
      'digest': digest,
      'contentKey': contentKey,
      'byteCount': byteCount,
      'now': sqlInstant(now),
    };
    // Stamped before it is read: from this statement on, a reclaim that read
    // the content earlier can no longer drop it.
    await datasource.executeCommand(
      'UPDATE $contentTable SET claimed_at = :now '
      'WHERE content_digest = :digest',
      params,
    );
    final held = await _content(digest);
    if (held != null || !create) return held;
    // A concurrent claim may insert the same digest first; the conflict is
    // ignored and the row it wrote — claimed just now — is the answer.
    await datasource.executeCommand(
      _contents.insertRow(
        datasource.sqlDialect,
        _contentColumns,
        ignoreConflict: true,
      ),
      params,
    );
    return _content(digest);
  }

  @override
  Future<List<TomBlobContent>> reclaimable(
    DateTime claimedBefore, {
    int limit = 500,
  }) => _selectContents(
    'WHERE claimed_at < :cutoff AND NOT EXISTS ('
    'SELECT 1 FROM $ledgerTable '
    'WHERE $ledgerTable.content_digest = $contentTable.content_digest) '
    'ORDER BY claimed_at LIMIT $limit',
    {'cutoff': sqlInstant(claimedBefore)},
  );

  @override
  Future<bool> dropContent(
    TomBlobContent content,
    DateTime claimedBefore,
  ) async {
    await ensureSchema();
    final dropped = await datasource.executeCommand(
      'DELETE FROM $contentTable '
      'WHERE content_digest = :digest AND content_key = :contentKey '
      'AND claimed_at < :cutoff AND NOT EXISTS ('
      'SELECT 1 FROM $ledgerTable WHERE content_digest = :digest)',
      {
        'digest': content.digest,
        'contentKey': content.contentKey,
        'cutoff': sqlInstant(claimedBefore),
      },
    );
    return dropped > BigInt.zero;
  }

  /// Empties both tables — for provisioning and tests.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $ledgerTable');
    await datasource.executeCommand('DELETE FROM $contentTable');
  }

  Future<TomBlobContent?> _content(String digest) async {
    final rows = await _selectContents('WHERE content_digest = :digest', {
      'digest': digest,
    });
    return rows.isEmpty ? null : rows.single;
  }

  Future<List<TomBlobLedgerEntry>> _selectEntries(
    String suffix,
    Map<String, Object?> params,
  ) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomBlobLedgerEntryRow>(
      'SELECT ${_entries.columnList} FROM $ledgerTable $suffix',
      params,
    );
    return [
      for (final row in rows)
        TomBlobLedgerEntry(
          key: row.key,
          owner: row.owner,
          digest: row.digest,
          contentKey: row.contentKey,
          byteCount: row.byteCount,
          mediaType: row.mediaType,
          fileName: row.fileName,
          storedAt: parseSqlInstant(row.storedAt),
        ),
    ];
  }

  Future<List<TomBlobContent>> _selectContents(
    String suffix,
    Map<String, Object?> params,
  ) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomBlobContentRow>(
      'SELECT ${_contents.columnList} FROM $contentTable $suffix',
      params,
    );
    return [
      for (final row in rows)
        TomBlobContent(
          digest: row.digest,
          contentKey: row.contentKey,
          byteCount: row.byteCount,
          claimedAt: parseSqlInstant(row.claimedAt),
        ),
    ];
  }
}

/// One row of the ledger's key table, as the driver hands it back.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomBlobLedgerEntryRow {
  /// The logical key.
  @TomDbColumn(columnName: "blob_key")
  String key = "";

  /// Who the blob counts against.
  @TomDbColumn(columnName: "owner")
  String owner = "";

  /// The content's SHA-256.
  @TomDbColumn(columnName: "content_digest")
  String digest = "";

  /// Where the content's bytes are stored.
  @TomDbColumn(columnName: "content_key")
  String contentKey = "";

  /// The content's size.
  @TomDbColumn(columnName: "byte_count")
  int byteCount = 0;

  /// The blob's media type.
  @TomDbColumn(columnName: "media_type")
  String mediaType = "";

  /// The blob's file name.
  @TomDbColumn(columnName: "file_name")
  String? fileName;

  /// When the key was written, as the stored text.
  @TomDbColumn(columnName: "stored_at")
  String storedAt = "";
}

/// One row of the ledger's content table, as the driver hands it back.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomBlobContentRow {
  /// The content's SHA-256.
  @TomDbColumn(columnName: "content_digest")
  String digest = "";

  /// Where the content's bytes are stored.
  @TomDbColumn(columnName: "content_key")
  String contentKey = "";

  /// The content's size.
  @TomDbColumn(columnName: "byte_count")
  int byteCount = 0;

  /// When it was last claimed, as the stored text.
  @TomDbColumn(columnName: "claimed_at")
  String claimedAt = "";
}

/// The aggregate row [TomSqlBlobLedger.usageOf] reads.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomBlobUsageRow {
  /// How many blobs.
  @TomDbColumn(columnName: "blob_count")
  int blobCount = 0;

  /// Their total size.
  @TomDbColumn(columnName: "blob_bytes")
  int blobBytes = 0;
}

/// The aggregate row [TomSqlBlobLedger.referencesTo] reads.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomBlobReferenceCountRow {
  /// How many entries name the content.
  @TomDbColumn(columnName: "reference_count")
  int referenceCount = 0;
}
