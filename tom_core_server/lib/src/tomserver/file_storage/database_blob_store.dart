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
import '../datasources/framework_table.dart';
import '../object_persistence/persistence_annotations.dart';
import 'blob_key_like.dart';
import 'blob_store.dart';
import 'database_blob_sql.dart';
import '../tenancy/tenant_data.dart';

/// A blob store that keeps its content in two tables of a [TomDataSource].
class TomDatabaseBlobStore extends TomBlobStore implements TomTenantData {
  /// The default number of *raw* bytes per chunk row, 256 KiB.
  ///
  /// Large enough that a megabyte-scale file is a handful of round trips rather
  /// than hundreds, and small enough that a chunk statement stays comfortably
  /// inside MariaDB's default `max_allowed_packet` — the stored text is base64,
  /// so ~4/3 of this, and the statement is larger again.
  ///
  /// Declared here rather than repeated at each defaulting site, for the same
  /// reason the table names are declared in `database_blob_sql.dart`: a default
  /// restated is a default that can diverge.
  static const int defaultChunkSize = 256 * 1024;

  /// Creates a store over [datasource].
  ///
  /// [manifestTable] and [chunkTable] name the two tables; [chunkSize] is the
  /// number of *raw* bytes per chunk row, defaulting to [defaultChunkSize] and
  /// rejected with `storage.database.chunk_size_not_positive` when it is zero
  /// or less.
  ///
  /// That rejection is not a preference about efficiency. [doPut] slices each
  /// incoming event with `(chunkSize - buffer.length).clamp(0, ...)`, which is
  /// `0` on every iteration once `chunkSize` is, so the write loop never
  /// advances and the upload hangs rather than failing. A hung request has
  /// nothing to throw, which makes construction the last moment at which the
  /// deployment can still be told — the same reason [TomS3BlobStore] refuses a
  /// part size below the protocol minimum here rather than on first use.
  ///
  /// With [createSchema] left `true` the two tables are created on first use;
  /// set it `false` when the schema is owned by the migration module and the
  /// application's database user is not allowed to run DDL.
  ///
  /// [clock] is the source of a blob's `storedAt`, defaulting to
  /// [DateTime.now]. A seam rather than a call in place, for the reason
  /// [TomSqlLeaseLock] and [TomSqlOAuthStateStore] have one: what this store
  /// does with the reading — hand it to the data source as a `DateTime` so the
  /// bind boundary renders it as UTC, rather than formatting it here — is only
  /// observable against a *known* instant, and the defect it replaced was
  /// exactly a local reading written as though it were UTC.
  TomDatabaseBlobStore(
    TomDataSource datasource, {
    this.manifestTable = defaultBlobManifestTable,
    this.chunkTable = defaultBlobChunkTable,
    this.chunkSize = defaultChunkSize,
    this.createSchema = true,
    DateTime Function()? clock,
  }) : datasource = TomFrameworkTable.systemOf(datasource),
       clock = clock ?? DateTime.now {
    if (chunkSize <= 0) {
      throw TomStorageException(
        'storage.database.chunk_size_not_positive',
        'The configured blob chunk size must be a positive number of bytes.',
        parameters: {'chunkSize': chunkSize},
      );
    }
  }

  /// Creates a store over the registered data source named [datasourceName].
  ///
  /// Throws a [TomStorageException] when no such data source is registered —
  /// a configuration error that is far better caught at start-up than on the
  /// first upload.
  factory TomDatabaseBlobStore.named(
    String datasourceName, {
    String manifestTable = defaultBlobManifestTable,
    String chunkTable = defaultBlobChunkTable,
    int chunkSize = defaultChunkSize,
    bool createSchema = true,
    DateTime Function()? clock,
  }) {
    final info = TomDataSourceInfo.getBaseDataSourceInfo(datasourceName);
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
      clock: clock,
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

  /// The clock a blob's `storedAt` is read from.
  ///
  /// Its reading is handed to the data source as a `DateTime`, not as text
  /// this store formats: the bind boundary renders every instant through
  /// `sqlInstant`, which is what puts a UTC value in the column. A local
  /// reading formatted here read back as though it were UTC and was wrong by
  /// the host's offset — and wrong by a different amount per node.
  final DateTime Function() clock;

  static const Uuid _uuid = Uuid();
  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  /// The manifest table's single column declaration — see
  /// `file_storage/database_blob_sql.dart`.
  late final TomFrameworkTable _manifest = blobManifestTable(manifestTable);

  /// The chunk table's single column declaration.
  late final TomFrameworkTable _chunks = blobChunkTable(chunkTable);

  /// Creates the two tables if they do not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic rather
  /// than on the first request.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) {
      await _manifest.create(datasource);
      await _chunks.create(datasource);
    }
  });

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    await ensureSchema();

    final uploadId = _uuid.v4();
    final previous = await _manifestOf(key);
    var byteCount = 0;
    var chunkIndex = 0;
    final buffer = <int>[];
    // Hashed from the incoming chunks rather than from the buffered ones. The
    // buffer is re-cut to `chunkSize`, so hashing it would be the same bytes in
    // different pieces — the same digest, but only because SHA-256 does not
    // care, and a reader should not need to know that to believe this line.
    final digest = TomBlobDigest();

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      await datasource.executeCommand(
        _chunks.insertRow(datasource.sqlDialect, const {
          'upload_id': ':uploadId',
          'chunk_index': ':chunkIndex',
          'chunk_data': ':chunkData',
        }),
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
        digest.add(incoming);
        var offset = 0;
        // A single incoming chunk may be larger than `chunkSize` (a file read
        // hands out whatever the OS gave it), so the loop slices rather than
        // assuming one buffer fill per event.
        while (offset < incoming.length) {
          final take = (chunkSize - buffer.length).clamp(
            0,
            incoming.length - offset,
          );
          buffer.addAll(incoming.getRange(offset, offset + take));
          offset += take;
          if (buffer.length >= chunkSize) await flush();
        }
      }
      await flush();
    } on Object catch (error, stack) {
      // Rethrown rather than wrapped: [TomBlobStore.put] reports it as
      // `storage.blob.write_failed`. This block exists for the chunk cleanup,
      // and having done it must not swallow what caused it.
      await _deleteChunks(uploadId).catchError((Object _) {});
      Error.throwWithStackTrace(error, stack);
    }

    final storedAt = clock();
    // The commit point: one statement, so a concurrent reader sees the old
    // upload id or the new one and never a manifest that names chunks which
    // are still arriving.
    await _manifest.replaceRow(
      datasource,
      const {
        'storage_key': ':key',
        'upload_id': ':uploadId',
        'media_type': ':mediaType',
        'file_name': ':fileName',
        'byte_count': ':byteCount',
        'chunk_count': ':chunkCount',
        'chunk_size': ':chunkSize',
        'digest': ':digest',
        'stored_at': ':storedAt',
        'tenant': ':tenant',
      },
      {
        'key': key,
        'uploadId': uploadId,
        'mediaType': mediaType,
        'fileName': fileName,
        'byteCount': byteCount,
        'chunkCount': chunkIndex,
        'chunkSize': chunkSize,
        'digest': digest.close(),
        // Bound as a `DateTime`, not as text this store renders itself. The
        // data source binds every instant through `sqlInstant`, which is what
        // puts a UTC reading in the column; a local one formatted here read
        // back as though it were UTC and was wrong by the host's offset.
        'storedAt': storedAt,
        'tenant': TomTenantContext.currentId ?? '',
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
      digest: digest.close(),
      fileName: fileName,
    );
  }

  @override
  Stream<List<int>> doGet(String key) async* {
    await ensureSchema();
    final manifest = await _manifestOf(key);
    if (manifest == null) throw TomBlobStore.notFound(key);
    for (var index = 0; index < manifest.chunkCount; index++) {
      // One round trip per chunk, taken only when the consumer has asked for
      // the previous one — this is where the streaming actually happens.
      yield base64.decode(await _chunkData(key, manifest, index));
    }
  }

  @override
  Stream<List<int>> doGetRange(String key, TomBlobRange range) async* {
    await ensureSchema();
    final manifest = await _manifestOf(key);
    if (manifest == null) throw TomBlobStore.notFound(key);
    // Chunks are addressed by index and every one but the last was written at
    // the recorded size, so the first chunk a byte offset can be in is a
    // division. The rows before it are never fetched: the inherited default
    // would take one round trip each and decode them only to throw them away,
    // which on a gigabyte blob is thousands of queries for a seek to the end.
    final size = manifest.chunkSize;
    if (size <= 0) {
      // A manifest written before the size was recorded, or by a store that got
      // it wrong. Reading from zero is slow and correct; guessing is neither.
      yield* super.doGetRange(key, range);
      return;
    }
    final first = range.start ~/ size;
    final end = range.endExclusive;
    final last = end == null
        ? manifest.chunkCount - 1
        : ((end - 1) ~/ size).clamp(0, manifest.chunkCount - 1);
    for (var index = first; index <= last; index++) {
      final chunk = base64.decode(await _chunkData(key, manifest, index));
      final position = index * size;
      final from = range.start > position ? range.start - position : 0;
      final to = end == null || end - position >= chunk.length
          ? chunk.length
          : end - position;
      if (from < to) yield chunk.sublist(from, to);
    }
  }

  /// The base64 payload of chunk [index] of [manifest].
  Future<String> _chunkData(
    String key,
    _BlobManifest manifest,
    int index,
  ) async {
    final rows = await datasource.executeQuery<TomBlobChunkRow>(
      'SELECT ${_chunks.columnsOf(const ['chunk_data'])} FROM $chunkTable '
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
    return rows.first.chunkData;
  }

  @override
  Future<TomStoredBlob?> doDescribe(String key) async {
    await ensureSchema();
    final manifest = await _manifestOf(key);
    if (manifest == null) return null;
    return TomStoredBlob(
      key: manifest.storageKey,
      mediaType: manifest.mediaType,
      byteCount: manifest.byteCount,
      storedAt: manifest.storedAt,
      digest: manifest.digest,
      // An empty string is treated as absent too: a `NOT NULL` variant of this
      // table (a migration may well declare one) stores "no name" that way.
      fileName: (manifest.fileName?.isEmpty ?? true) ? null : manifest.fileName,
    );
  }

  @override
  Future<TomStoredBlob> doCopy(String fromKey, String toKey) async {
    await ensureSchema();
    final source = await _manifestOf(fromKey);
    if (source == null) throw TomBlobStore.notFound(fromKey);
    final displaced = await _manifestOf(toKey);

    // A second manifest row against the *same* upload id: the chunks are not
    // read, not written and not counted, so a copy of a gigabyte is one row.
    // What makes it safe is that "delete the chunks" is guarded by whether any
    // manifest row still names the upload — see [_deleteChunks] — so the two
    // keys have independent lifetimes despite sharing bytes.
    final storedAt = clock();
    await _manifest.replaceRow(
      datasource,
      const {
        'storage_key': ':key',
        'upload_id': ':uploadId',
        'media_type': ':mediaType',
        'file_name': ':fileName',
        'byte_count': ':byteCount',
        'chunk_count': ':chunkCount',
        'chunk_size': ':chunkSize',
        'digest': ':digest',
        'stored_at': ':storedAt',
      },
      {
        'key': toKey,
        'uploadId': source.uploadId,
        'mediaType': source.mediaType,
        'fileName': source.fileName,
        'byteCount': source.byteCount,
        'chunkCount': source.chunkCount,
        'chunkSize': source.chunkSize,
        'digest': source.digest,
        'storedAt': storedAt,
      },
    );

    // Whatever the destination held is now unreferenced, exactly as it is after
    // a `doPut` over an occupied key — and released the same way, through the
    // guard, since the displaced upload may be one this copy now shares.
    if (displaced != null) await _deleteChunks(displaced.uploadId);

    return TomStoredBlob(
      key: toKey,
      mediaType: source.mediaType,
      byteCount: source.byteCount,
      storedAt: storedAt,
      fileName: source.fileName,
    );
  }

  @override
  Future<TomStoredBlob> doMove(String fromKey, String toKey) async {
    await ensureSchema();
    final source = await _manifestOf(fromKey);
    if (source == null) throw TomBlobStore.notFound(fromKey);

    // Anything at the destination goes first: the key is the primary key, so an
    // UPDATE onto an occupied one is a constraint violation rather than the
    // replacement every other write performs. Deleting through `doDelete` is
    // what releases the displaced blob's chunks under the same guard.
    if (toKey != fromKey) await doDelete(toKey);
    await datasource.executeCommand(
      'UPDATE $manifestTable SET storage_key = :toKey '
      'WHERE storage_key = :fromKey',
      {'toKey': toKey, 'fromKey': fromKey},
    );
    return TomStoredBlob(
      key: toKey,
      mediaType: source.mediaType,
      byteCount: source.byteCount,
      storedAt: source.storedAt,
      fileName: source.fileName,
    );
  }

  @override
  bool get supportsPrefixDelete => true;

  @override
  Future<int> doDeletePrefix(String prefix) async {
    await ensureSchema();
    // The uploads are read before the manifest rows go, because after that
    // nothing names them and there is no way back to their chunks.
    final doomed = await datasource.executeQuery<TomBlobManifestRow>(
      'SELECT ${_manifest.columnList} FROM $manifestTable '
      'WHERE storage_key = :key OR storage_key LIKE :under ESCAPE \'!\'',
      {'key': prefix, 'under': '${escapeBlobKeyLike(prefix)}/%'},
    );
    if (doomed.isEmpty) return 0;

    await datasource.executeCommand(
      'DELETE FROM $manifestTable '
      'WHERE storage_key = :key OR storage_key LIKE :under ESCAPE \'!\'',
      {'key': prefix, 'under': '${escapeBlobKeyLike(prefix)}/%'},
    );
    // One guarded sweep per upload rather than one statement over all of them:
    // a copy (see [doCopy]) can leave two keys on one upload, and only the
    // rows still naming it decide whether its chunks may go.
    for (final uploadId in {for (final row in doomed) row.uploadId}) {
      await _deleteChunks(uploadId);
    }
    return doomed.length;
  }

  @override
  Future<bool> doDelete(String key) async {
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

  /// The storage keys of the blobs written in [tenant] (`''` for those written
  /// with no tenant), in key order: the manifest is a system table serving
  /// every tenant, and this is how a tenant's blobs are listed for an export or
  /// a purge.
  Future<List<String>> keysOfTenant(String tenant) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomBlobManifestRow>(
      'SELECT ${_manifest.columnList} FROM $manifestTable '
      'WHERE tenant = :tenant ORDER BY storage_key',
      {'tenant': tenant},
    );
    return [for (final row in rows) row.storageKey];
  }

  /// Deletes the blobs written for [tenant] ([keysOfTenant]), their chunks
  /// with them.
  @override
  Future<int> purgeTenant(String tenant) async {
    var deleted = 0;
    for (final key in await keysOfTenant(tenant)) {
      if (await delete(key)) deleted++;
    }
    return deleted;
  }

  Future<_BlobManifest?> _manifestOf(String key) async {
    final rows = await datasource.executeQuery<TomBlobManifestRow>(
      'SELECT ${_manifest.columnList} FROM $manifestTable '
      'WHERE storage_key = :key',
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
      chunkSize: row.chunkSize,
      digest: row.digest,
      storedAt: row.storedAt,
    );
  }

  /// Deletes the chunks of [uploadId], unless a manifest row still names it.
  ///
  /// The guard is what makes [doCopy]'s sharing safe. A copy is a second
  /// manifest row against the *same* upload, so the bytes are reachable by two
  /// keys; deleting either key, or overwriting either, must not take the chunks
  /// the other still points at. The predicate is the same one
  /// [purgeOrphanedChunks] applies to the whole table, narrowed to one upload:
  /// chunks are unreferenced bytes, and unreferenced is a question about the
  /// manifest rather than about who asked.
  Future<void> _deleteChunks(String uploadId) => datasource.executeCommand(
    'DELETE FROM $chunkTable WHERE upload_id = :uploadId '
    'AND upload_id NOT IN (SELECT upload_id FROM $manifestTable)',
    {'uploadId': uploadId},
  );

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
    required this.chunkSize,
    required this.digest,
    required this.storedAt,
  });

  final String storageKey;
  final String uploadId;
  final String mediaType;
  final String? fileName;
  final int byteCount;
  final int chunkCount;
  final int chunkSize;
  final String digest;
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
  primaryKeyFields: ["irrelevant"],
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

  /// The size every chunk but the last was written at.
  @TomDbColumn(columnName: "chunk_size")
  int chunkSize = 0;

  /// The SHA-256 of the content, as 64 lowercase hex characters.
  @TomDbColumn(columnName: "digest")
  String digest = "";

  /// When the write completed.
  @TomDbColumn(columnName: "stored_at")
  DateTime storedAt = DateTime.fromMillisecondsSinceEpoch(0);
}

/// One chunk row's payload — base64 text, decoded by [TomDatabaseBlobStore.get].
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomBlobChunkRow {
  /// The base64-encoded bytes of this chunk.
  @TomDbColumn(columnName: "chunk_data")
  String chunkData = "";
}
