/// The schema of the two tables the database blob backend keeps its content in.
///
/// Each is declared **once**, as a [TomFrameworkTable]: the DDL the store issues
/// on first use, the column lists its statements interpolate, and the schema
/// model the convergence guard compares are all derived from that one
/// declaration. Same arrangement, and same reason, as
/// `scheduling/sql_scheduling_sql.dart` and `audit/sql_audit_sql.dart`.
///
/// The DDL previously lived inline in `TomDatabaseBlobStore.ensureSchema`, which
/// meant the chunk table's column names existed in five statements and were
/// related to each other by nothing at all — and `TomBlobChunkRow` maps only one
/// of its three columns, so even the reflected side gave no complete second
/// opinion. A rename that missed one statement would have failed on a chunk read
/// of a large file, which is a path a small-file deployment may never exercise
/// before production.
library;

import '../datasources/framework_table.dart';
import 'blob_store.dart';

/// The default name of the blob manifest table.
const String defaultBlobManifestTable = 'tom_blob';

/// The default name of the blob chunk table.
const String defaultBlobChunkTable = 'tom_blob_chunk';

/// The one-row-per-blob manifest table [table], declared once.
///
/// Notes on the shape:
///
///  * `storage_key` is the primary key and is what a caller names a blob by. It
///    is `VARCHAR(`[TomBlobStore.maxKeyLength]`)` so the column cannot silently
///    truncate a key the validator accepted — the width is derived from the
///    validator rather than restated next to it.
///  * `upload_id` is the *committed* upload, and is the whole commit protocol:
///    chunks are written under a fresh id and this one row is then replaced in a
///    single statement, so a reader sees the previous blob or the complete new
///    one and never a manifest pointing at chunks still arriving.
///  * `chunk_count` is what [TomBlobStore] `get` iterates, so a manifest and its
///    chunks disagree loudly (a missing-chunk error) rather than quietly
///    truncating the download.
///  * `file_name` is nullable and that is the ordinary case: most blobs are
///    written by key, not by name.
///  * `stored_at` is `DATETIME(6)`, and the width is not a precision
///    preference — it is the column agreeing with its writer. Every `DateTime`
///    bound by this data source is rendered by `sqlInstant`, which always emits
///    six fractional digits, and MariaDB does not reject the extra precision on
///    a narrower column: it silently *rounds* it. A plain `DATETIME` therefore
///    did not hold a coarser version of the right moment but a different one, up
///    to half a second away, making the value `put` returned unequal to the one
///    `describe` read back. `sql_instant.dart` states the general rule.
TomFrameworkTable blobManifestTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'blobManifestTable',
  columns: [
    TomFrameworkColumn('storage_key', 'VARCHAR(${TomBlobStore.maxKeyLength})'),
    const TomFrameworkColumn('upload_id', 'VARCHAR(64)'),
    const TomFrameworkColumn('media_type', 'VARCHAR(255)'),
    const TomFrameworkColumn('file_name', 'VARCHAR(255)', nullable: true),
    const TomFrameworkColumn('byte_count', 'BIGINT'),
    const TomFrameworkColumn('chunk_count', 'INT'),
    // The size every chunk but the last was written at. Recorded rather
    // than assumed because a ranged read maps a byte offset onto a chunk
    // index by dividing by it, and the store's `chunkSize` is a
    // constructor argument: a store reconfigured between the write and the
    // read would otherwise seek to the wrong row and serve the wrong bytes.
    // It is not derivable from `byte_count` and `chunk_count` either --
    // 10 bytes in 2 chunks is 6+4 or 9+1 or 5+5.
    const TomFrameworkColumn('chunk_size', 'INT'),
    // The SHA-256 of the content, as 64 lowercase hex characters. Fixed width
    // because every value is exactly that: a CHAR says so to the reader and
    // to the index. Empty for a manifest row written without one.
    const TomFrameworkColumn('digest', 'CHAR(64)'),
    const TomFrameworkColumn('stored_at', 'DATETIME(6)'),
  ],
  primaryKey: const ['storage_key'],
);

/// The many-rows-per-blob content table [table], declared once.
///
/// Keyed on `(upload_id, chunk_index)` rather than on the storage key, because
/// the chunks of an in-flight write must be addressable before anything commits
/// to them — that separation is what makes the manifest replace atomic.
///
/// `chunk_data` is `LONGTEXT` and holds **base64**, not raw bytes. The MariaDB
/// driver decodes every column value into a Dart `String` before the mapper sees
/// it, so a `BLOB` would come back mangled by UTF-8 decoding; text is the only
/// correct representation available here, at a cost of 33 % in storage.
TomFrameworkTable blobChunkTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'blobChunkTable',
  columns: const [
    TomFrameworkColumn('upload_id', 'VARCHAR(64)'),
    TomFrameworkColumn('chunk_index', 'INT'),
    TomFrameworkColumn('chunk_data', 'LONGTEXT'),
  ],
  primaryKey: const ['upload_id', 'chunk_index'],
);

/// The DDL for the blob manifest table [table].
String blobManifestTableDdl(String table) =>
    blobManifestTable(table).createTableDdl;

/// The DDL for the blob chunk table [table].
String blobChunkTableDdl(String table) => blobChunkTable(table).createTableDdl;
