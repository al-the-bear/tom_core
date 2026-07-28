/// The database backend: blobs as chunk rows in the data source that already
/// holds the entity referring to them.
///
/// The built-in that needs no infrastructure decision. A deployment that has a
/// database — every deployment that has entities to attach files to — can store
/// those files without also provisioning a bucket, a volume or a credential,
/// and a backup of the database is a backup of the files.
///
/// ## Why chunks, and why base64
///
/// **Chunks** are what make it stream. A single `LONGBLOB` column would have to
/// be read whole to be read at all, which is precisely the failure the
/// streaming API exists to avoid; splitting the payload across rows lets [get]
/// fetch row *n* only when the consumer has taken row *n-1*, so a 2 GB download
/// costs one chunk of memory.
///
/// **base64** is not a preference. The MariaDB driver in use decodes every
/// column value of every result row into a Dart `String` before the mapper ever
/// sees it (`ResultSetRow` holds `List<String?>`), so raw bytes do not survive
/// a round trip through it — a `BLOB` column would come back mangled by UTF-8
/// decoding. Encoding the chunk as base64 text is therefore the only *correct*
/// representation available, not a shortcut around a harder one. It costs 33 %
/// in storage, which is the honest price of this backend and one more reason
/// that a deployment storing large files should point at an object store.
///
/// ## How a half-written blob is prevented
///
/// Chunks carry an **upload id**, not the storage key; the manifest row holds
/// the id that is *committed*. A write streams its chunks under a fresh id and
/// then replaces the one-row manifest — a single atomic statement — so a reader
/// sees either the previous blob or the complete new one. A write that fails
/// deletes the chunks it wrote and leaves the manifest untouched.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/uuid.dart';

import '../datasources/datasource_initialization.dart';
import '../object_persistence/persistence_annotations.dart';
import 'blob_store.dart';

/// A blob store that keeps its content in two tables of a [TomDataSource].
class TomDatabaseBlobStore extends TomBlobStore {
  /// Creates a store over [datasource].
  ///
  /// [manifestTable] and [chunkTable] name the two tables; [chunkSize] is the
  /// number of *raw* bytes per chunk row (the stored text is ~4/3 of that).
  /// The 256 KiB default keeps a chunk statement comfortably inside MariaDB's
  /// default `max_allowed_packet` while being large enough that a megabyte-scale
  /// file is a handful of round trips rather than hundreds.
  ///
  /// With [createSchema] left `true` the two tables are created on first use;
  /// set it `false` when the schema is owned by the migration module and the
  /// application's database user is not allowed to run DDL.
  TomDatabaseBlobStore(
    this.datasource, {
    this.manifestTable = 'tom_blob',
    this.chunkTable = 'tom_blob_chunk',
    this.chunkSize = 256 * 1024,
    this.createSchema = true,
  });

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomStorageException] when no such data source is registered —
  /// a configuration error that is far better caught at start-up than on the
  /// first upload.
  factory TomDatabaseBlobStore.named(
    String datasourceName, {
    String manifestTable = 'tom_blob',
    String chunkTable = 'tom_blob_chunk',
    int chunkSize = 256 * 1024,
    bool createSchema = true,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomStorageException(
        'storage.database.unknown_datasource',
        'The file store refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomDatabaseBlobStore(
      info.datasource,
      manifestTable: manifestTable,
      chunkTable: chunkTable,
      chunkSize: chunkSize,
      createSchema: createSchema,
    );
  }

  /// The data source the two tables live in.
  final TomDataSource datasource;

  /// The one-row-per-blob manifest table.
  final String manifestTable;

  /// The many-rows-per-blob content table.
  final String chunkTable;

  /// Raw bytes per chunk row.
  final int chunkSize;

  /// Whether to create the tables on first use.
  final bool createSchema;

  static const Uuid _uuid = Uuid();
  bool _schemaReady = false;

  /// Creates the two tables if they do not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic rather
  /// than on the first request.
  Future<void> ensureSchema() async {
    if (_schemaReady) return;
    if (createSchema) {
      await datasource.executeCommand('''
CREATE TABLE IF NOT EXISTS $manifestTable (
  storage_key VARCHAR(${TomBlobStore.maxKeyLength}) NOT NULL,
  upload_id   VARCHAR(64)  NOT NULL,
  media_type  VARCHAR(255) NOT NULL,
  file_name   VARCHAR(255) NULL,
  byte_count  BIGINT       NOT NULL,
  chunk_count INT          NOT NULL,
  stored_at   DATETIME     NOT NULL,
  PRIMARY KEY (storage_key)
)''');
      await datasource.executeCommand('''
CREATE TABLE IF NOT EXISTS $chunkTable (
  upload_id   VARCHAR(64) NOT NULL,
  chunk_index INT         NOT NULL,
  chunk_data  LONGTEXT    NOT NULL,
  PRIMARY KEY (upload_id, chunk_index)
)''');
    }
    _schemaReady = true;
  }

  @override
  Future<TomStoredBlob> put({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    TomBlobStore.validateKey(key);
    await ensureSchema();

    final uploadId = _uuid.v4();
    final previous = await _manifestOf(key);
    var byteCount = 0;
    var chunkIndex = 0;
    final buffer = <int>[];

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await datasource.executeCommand(
        'INSERT INTO $chunkTable (upload_id, chunk_index, chunk_data) '
        'VALUES (:uploadId, :chunkIndex, :chunkData)',
        {
          'uploadId': uploadId,
          'chunkIndex': chunkIndex,
          'chunkData': base64.encode(buffer),
        },
      );
      chunkIndex++;
      buffer.clear();
    }

    try {
      await for (final incoming in bytes) {
        byteCount += incoming.length;
        var offset = 0;
        // A single incoming chunk may be larger than `chunkSize` (a file read
        // hands out whatever the OS gave it), so the loop slices rather than
        // assuming one buffer fill per event.
        while (offset < incoming.length) {
          final take = (chunkSize - buffer.length).clamp(0, incoming.length - offset);
          buffer.addAll(incoming.getRange(offset, offset + take));
          offset += take;
          if (buffer.length >= chunkSize) await flush();
        }
      }
      await flush();
    } on Object catch (error, stack) {
      await _deleteChunks(uploadId).catchError((Object _) {});
      throw TomStorageException(
        'storage.blob.write_failed',
        'The file could not be written to storage.',
        parameters: {'key': key},
        rootException: error,
        stack: stack,
      );
    }

    final storedAt = DateTime.now();
    // The commit point: one statement, so a concurrent reader sees the old
    // upload id or the new one and never a manifest that names chunks which
    // are still arriving.
    await datasource.executeCommand(
      'REPLACE INTO $manifestTable '
      '(storage_key, upload_id, media_type, file_name, byte_count, chunk_count, stored_at) '
      'VALUES (:key, :uploadId, :mediaType, :fileName, :byteCount, :chunkCount, :storedAt)',
      {
        'key': key,
        'uploadId': uploadId,
        'mediaType': mediaType,
        'fileName': fileName,
        'byteCount': byteCount,
        'chunkCount': chunkIndex,
        'storedAt': _sqlDateTime(storedAt),
      },
    );

    // The superseded content, once nothing points at it. A failure here leaves
    // collectable orphans, not a broken blob, so it must not fail the write —
    // [purgeOrphanedChunks] exists for exactly this residue.
    if (previous != null) {
      await _deleteChunks(previous.uploadId).catchError((Object error) {
        tomLog.warn(
          'Blob store could not remove superseded chunks for '
          '${previous.uploadId}: $error',
        );
      });
    }

    return TomStoredBlob(
      key: key,
      mediaType: mediaType,
      byteCount: byteCount,
      storedAt: storedAt,
      fileName: fileName,
    );
  }

  @override
  Stream<List<int>> get(String key) async* {
    await ensureSchema();
    final manifest = await _manifestOf(key);
    if (manifest == null) throw TomBlobStore.notFound(key);
    for (var index = 0; index < manifest.chunkCount; index++) {
      // One round trip per chunk, taken only when the consumer has asked for
      // the previous one — this is where the streaming actually happens.
      final rows = await datasource.executeQuery<TomBlobChunkRow>(
        'SELECT chunk_data FROM $chunkTable '
        'WHERE upload_id = :uploadId AND chunk_index = :chunkIndex',
        {'uploadId': manifest.uploadId, 'chunkIndex': index},
      );
      if (rows.isEmpty) {
        throw TomStorageException(
          'storage.blob.missing_chunk',
          'The stored file is incomplete and cannot be read.',
          parameters: {
            'key': key,
            'uploadId': manifest.uploadId,
            'chunkIndex': index,
          },
          autoLog: true,
        );
      }
      yield base64.decode(rows.first.chunkData);
    }
  }

  @override
  Future<TomStoredBlob?> describe(String key) async {
    await ensureSchema();
    final manifest = await _manifestOf(key);
    if (manifest == null) return null;
    return TomStoredBlob(
      key: manifest.storageKey,
      mediaType: manifest.mediaType,
      byteCount: manifest.byteCount,
      storedAt: manifest.storedAt,
      // An empty string is treated as absent too: a `NOT NULL` variant of this
      // table (a migration may well declare one) stores "no name" that way.
      fileName: (manifest.fileName?.isEmpty ?? true) ? null : manifest.fileName,
    );
  }

  @override
  Future<bool> delete(String key) async {
    await ensureSchema();
    final manifest = await _manifestOf(key);
    if (manifest == null) return false;
    // Manifest first: it is what makes the blob visible, so removing it is the
    // point at which the blob is gone. The chunks are then unreferenced bytes.
    await datasource.executeCommand(
      'DELETE FROM $manifestTable WHERE storage_key = :key',
      {'key': key},
    );
    await _deleteChunks(manifest.uploadId);
    return true;
  }

  /// Deletes chunk rows no manifest refers to, returning how many were removed.
  ///
  /// The residue of the two operations that deliberately do not fail on a
  /// chunk-delete error: replacing a blob and deleting one. Neither can leave a
  /// *readable* orphan — nothing points at those rows — so collecting them is
  /// housekeeping rather than repair, and belongs on a schedule rather than in
  /// the request path.
  Future<int> purgeOrphanedChunks() async {
    await ensureSchema();
    final removed = await datasource.executeCommand(
      'DELETE FROM $chunkTable WHERE upload_id NOT IN '
      '(SELECT upload_id FROM $manifestTable)',
    );
    return removed.toInt();
  }

  Future<_BlobManifest?> _manifestOf(String key) async {
    final rows = await datasource.executeQuery<TomBlobManifestRow>(
      'SELECT storage_key, upload_id, media_type, file_name, byte_count, '
      'chunk_count, stored_at FROM $manifestTable WHERE storage_key = :key',
      {'key': key},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return _BlobManifest(
      storageKey: row.storageKey,
      uploadId: row.uploadId,
      mediaType: row.mediaType,
      fileName: row.fileName,
      byteCount: row.byteCount,
      chunkCount: row.chunkCount,
      storedAt: row.storedAt,
    );
  }

  Future<void> _deleteChunks(String uploadId) => datasource.executeCommand(
        'DELETE FROM $chunkTable WHERE upload_id = :uploadId',
        {'uploadId': uploadId},
      );

  /// Renders [value] in the `YYYY-MM-DD HH:MM:SS` form a SQL `DATETIME` binds.
  static String _sqlDateTime(DateTime value) =>
      value.toIso8601String().substring(0, 19).replaceFirst('T', ' ');

  @override
  String toString() => 'TomDatabaseBlobStore($manifestTable)';
}

/// The manifest fields, decoupled from the reflected row holder so nothing
/// outside this file depends on the mapping type.
class _BlobManifest {
  const _BlobManifest({
    required this.storageKey,
    required this.uploadId,
    required this.mediaType,
    required this.fileName,
    required this.byteCount,
    required this.chunkCount,
    required this.storedAt,
  });

  final String storageKey;
  final String uploadId;
  final String mediaType;
  final String? fileName;
  final int byteCount;
  final int chunkCount;
  final DateTime storedAt;
}

/// One row of the blob manifest table, as the result mapper materialises it.
///
/// Reflected and `@TomDbTable`-annotated because the data source's row mapper
/// requires both; the table values are placeholders because the real table name
/// is a constructor argument of [TomDatabaseBlobStore]. Same arrangement, and
/// same reason, as `TomDbVersion` in the migration module.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomBlobManifestRow {
  /// The storage key.
  @TomDbColumn(columnName: "storage_key")
  String storageKey = "";

  /// The id of the committed upload whose chunks hold this blob's content.
  @TomDbColumn(columnName: "upload_id")
  String uploadId = "";

  /// The IANA media type the bytes should be served as.
  @TomDbColumn(columnName: "media_type")
  String mediaType = TomStoredBlob.defaultMediaType;

  /// The original file name, or `null` when none was supplied.
  ///
  /// Nullable because the column is: most blobs are written by a key, not by a
  /// name, so `NULL` is the ordinary value here and a non-nullable field would
  /// make the ordinary blob unreadable.
  @TomDbColumn(columnName: "file_name")
  String? fileName;

  /// The blob's size in bytes.
  @TomDbColumn(columnName: "byte_count")
  int byteCount = 0;

  /// How many chunk rows the content occupies.
  @TomDbColumn(columnName: "chunk_count")
  int chunkCount = 0;

  /// When the write completed.
  @TomDbColumn(columnName: "stored_at")
  DateTime storedAt = DateTime.fromMillisecondsSinceEpoch(0);
}

/// One chunk row's payload — base64 text, decoded by [TomDatabaseBlobStore.get].
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyField: "irrelevant",
)
class TomBlobChunkRow {
  /// The base64-encoded bytes of this chunk.
  @TomDbColumn(columnName: "chunk_data")
  String chunkData = "";
}
