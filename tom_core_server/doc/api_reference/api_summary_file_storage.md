# Tom Core Server API Reference: File Storage Module

Storage by key for files too large to live in a row: a streaming
put/get/describe/delete contract, four shipped backends behind it, and the
named registry that selects one from configuration.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomStorageException](#tomstorageexception)
  - [TomBlobStoreOperation](#tomblobstoreoperation)
  - [TomStoredBlob](#tomstoredblob)
  - [TomBlobStore](#tomblobstore)
  - [TomMemoryBlobStore](#tommemoryblobstore)
  - [TomDirectoryBlobStore](#tomdirectoryblobstore)
  - [TomDatabaseBlobStore](#tomdatabaseblobstore)
  - [TomBlobManifestRow](#tomblobmanifestrow)
  - [TomBlobChunkRow](#tomblobchunkrow)
  - [TomAwsCredentials](#tomawscredentials)
  - [TomAwsV4Signer](#tomawsv4signer)
  - [TomS3BlobStore](#toms3blobstore)
  - [TomBlobStoreFactory](#tomblobstorefactory)
  - [TomBlobStoreInfo](#tomblobstoreinfo)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/file_storage/blob_store.dart`,
`lib/src/tomserver/file_storage/directory_blob_store.dart`,
`lib/src/tomserver/file_storage/database_blob_store.dart`,
`lib/src/tomserver/file_storage/database_blob_sql.dart`,
`lib/src/tomserver/file_storage/s3_blob_store.dart`,
`lib/src/tomserver/file_storage/aws_v4_signer.dart`,
`lib/src/tomserver/file_storage/blob_store_registry.dart`.

`TomBlobStore` is the contract: four operations — `put`, `get`, `describe`,
`delete` — over a key and a `Stream<List<int>>`. There is no `list`, no rename
and no partial read, because nothing in the framework needs them and every one
of them would constrain the backends. `TomStoredBlob` is what a write returns
(key, media type, byte count, timestamp, optional original file name and a
backend-specific `location`), and `TomStorageException` is the module's error,
subtyping `TomServerException` so storage faults reach the ordinary server error
mapping. The key grammar is defined once, on `TomBlobStore`: `isValidKey`,
`maxKeyLength` and `validateKey` are applied by all five of `put`, `get`,
`describe`, `exists` and `delete` — the contract's own methods, each of which
reaches its backend only through a `do*` method — so an invalid key never
reaches a filesystem, a network or SQL, on a read any more than on a write. The
same grammar
covers the *namespacing prefixes* several components join onto keys —
`isValidKeyPrefix` and `validateKeyPrefix` check one at construction, so a
misconfigured prefix fails naming itself rather than surfacing later as an
invalid key nobody wrote. `sanitiseKeySegment` completes the set by going the
other way — turning a human-chosen name *into* a segment — and lives beside the
validator for the same reason the predicate does: a sanitiser that drifts from
its own grammar produces output the check it exists to satisfy refuses.

Four backends implement the contract. `TomMemoryBlobStore` holds everything in a
map — for tests and for a development server that should leave nothing behind.
`TomDirectoryBlobStore` maps keys onto paths beneath a root directory, writing
to a sibling `<key>~part` file and renaming it into place, with a `<key>~meta`
JSON sidecar for the media type and file name a filesystem cannot store. Both
auxiliary suffixes hang off `auxiliaryMarker`, a character the shared key
grammar cannot produce, so no valid key can address another key's bookkeeping.
`TomDatabaseBlobStore` keeps blobs as base64 chunk rows in a `TomDataSource` the
application already has, committing by replacing a one-row manifest once every
chunk has landed. `TomS3BlobStore` speaks the S3 REST API against anything
SigV4-compatible, sending a small object as a single signed `PUT` and a large
one as a multipart upload bounded by `partSize`.

The database backend's two tables are declared once, in `database_blob_sql.dart`:
`blobManifestTable` and `blobChunkTable` return the `TomFrameworkTable`
descriptors from which the DDL, the statements and the schema-convergence guard
are all derived, and `blobManifestTableDdl` / `blobChunkTableDdl` render their
`CREATE TABLE` text. `TomBlobManifestRow` and `TomBlobChunkRow` are the
reflected row types the data source's mapper materialises results into.

Requests to an object store are signed by `TomAwsV4Signer` using a
`TomAwsCredentials` pair; signing is a pure function of a request and a key, so
it lives apart from the store and is verified against AWS's published test
vectors. Finally, `TomBlobStoreInfo` is the process-wide registry of named,
configured stores — the same shape as `TomDataSourceInfo` — and
`TomBlobStoreFactory` is the seam an application registers its own backend
through, so a deployment spells a custom backend in configuration exactly like a
built-in one.

This module is the storage half only, and stops at the key. Nothing here is
reachable over HTTP: the endpoint that serves a stored file —
`TomFileService`/`TomFileServer` on `/files/{entity}/{id}/{column}`, and the
`TomFileSlots` registry that decides which columns are exposed at all — lives in
`lib/src/tomserver/endpoints/file_endpoint.dart` and is documented in the
[Endpoints](api_summary_endpoints.md) summary. The row-side contract that binds
a column to a key in one of these stores (`TomFileRepository`,
`@TomFileReference`) belongs to
[Object Persistence](api_summary_object_persistence.md). The split is by tier
rather than by subject, so a reader looking for "files" has three places to
look; each summary names the other two.

## Class Hierarchy

```
TomServerException  (little_things)
    └── TomStorageException

TomBlobStoreOperation  (enum)

TomBlobStore  (abstract)
    ├── TomMemoryBlobStore
    ├── TomDirectoryBlobStore
    ├── TomDatabaseBlobStore
    └── TomS3BlobStore

TomStoredBlob

TomBlobManifestRow
TomBlobChunkRow

TomAwsCredentials
TomAwsV4Signer

TomBlobStoreFactory  (typedef)
TomBlobStoreInfo
```

## Classes

### TomStorageException

The base error for every file-storage failure. Subtypes `TomServerException`, so
the isolate attribution and request correlation every other server error carries
apply here too, and a `catch … on TomServerException` in a pipeline reaches
storage faults without knowing about them.

- **Extends:** `TomServerException`

#### Constructors

```dart
TomStorageException(
  String key,
  String defaultUserMessage, {
  Map<String, Object?>? parameters,
  Object? stack,
  Object? rootException,
  bool autoLog = false,
  bool clientThrow = true,
})
```

### TomBlobStoreOperation

What a store was doing when its infrastructure refused — the vocabulary every
backend translates a `FileSystemException`, a driver error or an HTTP status
into. Letting those through would make a caller's error handling depend on which
backend it was configured with, and would slip past every `on TomServerException`
between the store and the request boundary.

Mirrors `TomExportStoreOperation` in the export module deliberately: the same
four questions are asked of the same kinds of infrastructure, and two different
answers for one fault would be an accident of which module the caller came
through.

The division is by *what the caller asked for*, not by which call threw — so a
sidecar that cannot be read during a `describe` is a `probe` failure even though
a file read is what failed.

- **Type:** `enum`

#### Values

| Value | Error key | Meaning |
| ----- | --------- | ------- |
| `write` | `storage.blob.write_failed` | Storing bytes under a key did not complete. |
| `read` | `storage.blob.read_failed` | Reading a blob's bytes back failed. |
| `probe` | `storage.blob.probe_failed` | `describe` or `exists` could not ask storage about the key. |
| `delete` | `storage.blob.delete_failed` | Removing what a key holds failed. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `errorKey` | `String` | The stable error key a caller matches on (final). |
| `message` | `String` | The user-facing message carried by the raised exception (final). |

### TomStoredBlob

What a stored blob is: its key, what it contains, how big it turned out.
Returned by `TomBlobStore.put` rather than assembled by the caller, because
`byteCount` is only known once the stream has drained.

#### Constructors

```dart
TomStoredBlob({
  required String key,
  required String mediaType,
  required int byteCount,
  required DateTime storedAt,
  String? fileName,
  Uri? location,
})
```

`storedAt` is normalised to UTC by the constructor, so the zone is a property
of the type rather than of whichever backend built the descriptor.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultMediaType` | `static const String` | The media type used when a caller states none: `application/octet-stream`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The key the blob is stored under (final). |
| `mediaType` | `String` | The IANA media type the bytes should be served as (final). |
| `byteCount` | `int` | The number of bytes stored (final). |
| `storedAt` | `DateTime` | When the write completed, always in UTC — the constructor normalises whatever it is given (final). |
| `fileName` | `String?` | The original file name, when one was supplied — kept because the storage key is chosen by the framework while the name a person expects in their downloads folder is the one they uploaded (final). |
| `location` | `Uri?` | A backend-specific address (a `file:` URI, an object-store URL); useful to a human chasing a blob down, never the thing to read it back with (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `TomStoredBlob(<key>, <byteCount> bytes, <mediaType>)`. |

### TomBlobStore

Stores and retrieves blobs by key. Implemented by the four shipped backends; an
application registers its own with `TomBlobStoreInfo.registerBackend`. Also the
single home of the key grammar every backend enforces.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomBlobStore()
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxKeyLength` | `static const int` | The longest key any backend accepts (512) — comfortably under the shortest limit in play, so the database backend can declare a fixed-width indexed column and a filesystem is never handed a name the OS rejects. |
| `auxiliaryMarker` | `static const String` | A character no valid key can contain (`~`), for backends keeping bookkeeping files alongside the blobs. Suffixing with it makes that bookkeeping *unaddressable*, where the obvious `<key>.meta` is a key a caller may legitimately choose — so two callers picking ordinary keys destroyed each other's data. Lives on the contract because it is a fact about `isValidKey`, which `TomExportStore` shares; the suffixes themselves stay with each backend. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isValidKey` | `static bool isValidKey(String key)` | Whether `key` is a well-formed storage key: non-empty, at most `maxKeyLength`, no leading or trailing `/`, no backslash, no `//`, only `A-Za-z0-9._/-`, and no `.` or `..` segment. |
| `validateKey` | `static String validateKey(String key)` | Returns `key` when `isValidKey` accepts it, otherwise throws `storage.blob.invalid_key`. |
| `sanitiseKeySegment` | `static String sanitiseKeySegment(String name, {String fallback = 'file'})` | `name` rewritten into one key segment, so a human-chosen name can *become* a key rather than only be tested against the grammar. The result is a valid key for every `name` short enough to be one — asserted over the code-unit range, not merely intended. `/` and `\` are replaced like any other disallowed character, so a name contributes no path structure; that is what defuses `../../etc/passwd`, by leaving it nothing to traverse with. Length is the one fault it does not repair: an over-long name comes back over-long and `validateKey` refuses it, because truncating would silently give two different names one key. `fallback` is returned when nothing usable survives — an empty name, whitespace, or one of the two segments the grammar reserves — and must itself be a valid key. |
| `isValidKeyPrefix` | `static bool isValidKeyPrefix(String? keyPrefix)` | Whether `keyPrefix` is usable as a key namespace. A prefix is joined as `"$keyPrefix/$key"`, so it must satisfy `isValidKey` itself; `null` and `''` both mean no namespace, and a trailing slash is not a second spelling (the join supplies the separator). Length is the one clause this cannot settle — two valid parts can join past `maxKeyLength`, which depends on a key that has not arrived yet, so the obligation belongs to whoever performs the join: those that join above a store get it from `validateKey`, and `TomS3BlobStore`, which joins below that boundary, checks it itself. |
| `validateKeyPrefix` | `static String? validateKeyPrefix(String? keyPrefix)` | Returns `keyPrefix` when `isValidKeyPrefix` accepts it, otherwise throws `storage.blob.invalid_key_prefix` naming the prefix. A distinct error from `invalid_key` because the two faults have different fixes: a bad key is a caller's mistake, a bad prefix a deployment's. |
| `notFound` | `static TomStorageException notFound(String key)` | Builds the `storage.blob.not_found` error, spelled once so every backend agrees and a caller can match on the key string. |

#### Methods

The five public methods are the contract's own and are not overridden: each
validates the key and translates any failure, then defers to the `do*` method a
backend implements. That is what makes both obligations hold for every backend
— including one an application writes — rather than leaving each to honour a
different subset of them, which is what the four shipped backends did.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | Validates `key`, calls `doPut`, reports any other failure as `storage.blob.write_failed`. Writes `bytes` under `key`, replacing anything already there, and returns the descriptor. A failure must leave nothing readable under `key` beyond what was there before: implementations commit atomically or not at all. A chunk from `bytes` is borrowed for the duration of the `await` — consume or copy it before asking for the next, never retain it, since a producer refilling one scratch buffer per chunk is the ordinary shape of an encoder. |
| `get` | `Stream<List<int>> get(String key)` | Validates `key`, reads through `doGet`, reports any other failure as `storage.blob.read_failed`. Throws `storage.blob.not_found` when the key holds nothing, rather than disguising a missing blob as an empty file. Each chunk belongs to the caller: writable, and aliased with nothing the store keeps. Consumes the backend's stream with `await for` rather than `yield*`, because a `yield*` forwards the inner stream's errors past the enclosing `try` and the translation would never run. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | Validates `key`, calls `doDescribe`, reports any other failure as `storage.blob.probe_failed`. The descriptor for `key`, or `null` when it holds nothing — the one read allowed to answer "nothing" without throwing. |
| `delete` | `Future<bool> delete(String key)` | Validates `key`, calls `doDelete`, reports any other failure as `storage.blob.delete_failed`. Returns whether anything was there to delete. |
| `exists` | `Future<bool> exists(String key)` | Validates `key`, calls `doExists`, reports any other failure as `storage.blob.probe_failed`. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(abstract)* Implemented by a backend; called by `put` with an already-validated key. A backend that fails part-way through cleans up and lets the failure out — `put` names the operation — rather than building a `write_failed` of its own. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(abstract)* Implemented by a backend; called by `get` with an already-validated key. Throws `notFound` when the key holds nothing. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(abstract)* Implemented by a backend; called by `describe` with an already-validated key. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(abstract)* Implemented by a backend; called by `delete` with an already-validated key. |
| `doExists` | `Future<bool> doExists(String key)` | Called by `exists` with an already-validated key. Defined in terms of `doDescribe` so a backend implements one lookup, not two; overridden where a cheaper existence probe exists. |
| `getBytes` | `Future<Uint8List> getBytes(String key)` | Reads `key` fully into memory — the convenience for call sites that genuinely know their blobs are small. A helper on the streaming API, not a second contract method, so a backend author cannot implement it instead of streaming. Collects with a non-copying builder, which returns a lone chunk untouched: it is exactly as aliased as what the backend yielded, which is why `get` promises the caller owns its chunks. |
| `putBytes` | `Future<TomStoredBlob> putBytes({required String key, required List<int> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | The buffered counterpart to `getBytes`; delegates to `put` with a single-value stream. |
| `close` | `Future<void> close()` | Releases whatever the backend holds open. Idempotent; the default does nothing, because most backends hold nothing. |

### TomMemoryBlobStore

A store that keeps its contents in memory, for tests and for a development
server that should not leave files behind. It buffers whole blobs by definition,
which is why it is not a default.

Holding the bytes rather than reading them back off a disk or a bucket makes it
the only backend that can accidentally share a buffer with a caller, in either
direction — so it is the only one that copies on purpose, in both.

- **Extends:** `TomBlobStore`

#### Constructors

```dart
TomMemoryBlobStore()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `keys` | `Iterable<String>` | *(getter)* The keys currently held, in insertion order. |
| `length` | `int` | *(getter)* The number of blobs held. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `textOf` | `String textOf(String key)` | The stored bytes for `key` decoded as UTF-8 text (malformed input allowed), for tests that assert on content. Validates the key like the contract's own methods do — so a test that mistypes one is told it mistyped one — and throws `storage.blob.not_found` when the key holds nothing. |
| `clear` | `void clear()` | Forgets everything, for a test that reuses one store across cases. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Drains the stream fully before either map is touched, so a stream that throws half way leaves no half-written blob. Copies each chunk as it arrives rather than retaining it, so a producer reusing one scratch buffer stores what it streamed. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Yields the buffered bytes as one chunk, copied so the reader owns it; throws `storage.blob.not_found` when absent. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* The descriptor recorded by `doPut`, or `null`. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Answers straight from the content map rather than through `doDescribe`. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Drops the content and its descriptor, returning whether content was present. |
| `toString` | `String toString()` | *(override)* Renders `TomMemoryBlobStore(<n> blobs)`. |

### TomDirectoryBlobStore

A blob store over a directory tree on the local filesystem: keys become paths
beneath `root`, so `2026/07/invoice.pdf` is a file two directories down and the
stored blobs are browsable with `ls`. Media type and original file name go to a
`<key>~meta` JSON sidecar, since a filesystem stores bytes and nothing else. The
sidecar and the `<key>~part` staging file both hang off `auxiliaryMarker`, a
character the shared key grammar cannot produce, so a caller's key can never
name another caller's bookkeeping.

- **Extends:** `TomBlobStore`

#### Constructors

```dart
TomDirectoryBlobStore(Directory root)

TomDirectoryBlobStore.at(String path)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `auxiliaryMarker` | `static const String` | The character separating a blob's path from this backend's bookkeeping, `~` — outside the shared key grammar, so no valid key can name an auxiliary file. |
| `metadataSuffix` | `static const String` | The sidecar suffix, `~meta`, holding one JSON object per blob. |
| `partialSuffix` | `static const String` | The suffix a write stages under before renaming into place, `~part`. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `root` | `Directory` | The directory every key resolves beneath; created on first write (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Streams to a sibling `<key>~part` and renames it into place, so a reader sees the previous blob or the complete new one. The close, the rename and the sidecar write are all inside the failure path, because each has filesystem faults of its own — a full disk surfaces at `close`, a rename fails on a cross-device root or an occupied target — and each of them fails *after* the partial exists. The rollback deletes whichever residue the failure left: the partial before the rename, the newly committed blob after it, then rethrows so that `put` reports it as `storage.blob.write_failed` with the original as `rootException`. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Streams the file with `openRead`; throws `storage.blob.not_found` when it does not exist. A mid-read filesystem fault becomes `storage.blob.read_failed` at `get`. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* Size and mtime from `stat()`, media type and file name from the sidecar when it is present and parseable — so a directory populated by `scp` is still readable. A sidecar that cannot be *read* (as opposed to parsed) surfaces as `storage.blob.probe_failed`. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* A direct file-existence probe. `exists` translates whatever this throws, but here there is nothing to translate: `File.exists` answers from a `stat` and maps every failure of it — an unreadable parent directory included — to `false`. It therefore means "visible to this process" rather than "present in storage"; ask `describe` to tell an unreadable blob from an absent one. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Deletes the file and its sidecar, returning whether the file was there; a filesystem refusal surfaces as `storage.blob.delete_failed`. |
| `toString` | `String toString()` | *(override)* Renders `TomDirectoryBlobStore(<root path>)`. |

### TomDatabaseBlobStore

A blob store that keeps its content in two tables of a `TomDataSource` — the
backend that needs no infrastructure decision, since a backup of the database is
a backup of the files. Content is split across chunk rows so `get` streams, and
each chunk is base64 text because the driver in use decodes every column value
into a Dart `String` before the mapper sees it. Chunks are written under a fresh
upload id and the one-row manifest is then replaced in a single statement, so a
reader sees the previous blob or the complete new one.

- **Extends:** `TomBlobStore`

#### Constructors

```dart
TomDatabaseBlobStore(
  TomDataSource datasource, {
  String manifestTable = defaultBlobManifestTable,
  String chunkTable = defaultBlobChunkTable,
  int chunkSize = defaultChunkSize,
  bool createSchema = true,
})
```

Throws `storage.database.chunk_size_not_positive` when `chunkSize` is zero or
less. `doPut` slices its incoming events with a clamp that is `0` on every
iteration for such a size, so the write loop cannot advance: the store would not
fail an upload but hang on one, with no exception to log. Construction is the
last moment at which the deployment can be told, which is the same reason
`TomS3BlobStore` checks its part size here.

#### Factory Constructors

```dart
factory TomDatabaseBlobStore.named(
  String datasourceName, {
  String manifestTable = defaultBlobManifestTable,
  String chunkTable = defaultBlobChunkTable,
  int chunkSize = defaultChunkSize,
  bool createSchema = true,
})
```

Resolves the registered data source named `datasourceName`, throwing
`storage.database.unknown_datasource` when there is none — a configuration
error far better caught at start-up than on the first upload.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultChunkSize` | `static const int` | The default raw bytes per chunk row: 256 KiB — large enough that a megabyte-scale file is a handful of round trips, small enough that a chunk statement stays inside MariaDB's default `max_allowed_packet` (the stored text is base64, so ~4/3 of this). Declared once here rather than repeated at each defaulting site, so a change lands everywhere. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the two tables live in (final). |
| `manifestTable` | `String` | The one-row-per-blob manifest table (final). |
| `chunkTable` | `String` | The many-rows-per-blob content table (final). |
| `chunkSize` | `int` | Raw bytes per chunk row, defaulting to `defaultChunkSize` and refused by the constructor when zero or less; the stored text is ~4/3 of that, and the upper bound on it is the server's `max_allowed_packet`, which no constructor can know (final). |
| `createSchema` | `bool` | Whether to create the tables on first use; set `false` when the schema is owned by the migration module and the application's database user may not run DDL (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the two tables if they do not exist. Idempotent and called automatically by every operation; exposed so a start-up sequence can provision the schema before serving traffic. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Slices the incoming stream into `chunkSize` chunk rows under a fresh upload id, then replaces the manifest row — the commit point. A failure deletes the chunks it wrote and rethrows, so `put` reports `storage.blob.write_failed`; superseded chunks are removed afterwards and a failure to do so is logged, not raised. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Reads the manifest, then fetches and base64-decodes one chunk row per consumer demand; throws `storage.blob.not_found` for an unknown key and `storage.blob.missing_chunk` when the manifest and its chunks disagree. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* Builds the descriptor from the manifest row, or `null`. An empty `file_name` is treated as absent, so a `NOT NULL` variant of the table behaves the same. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Deletes the manifest row first — that is the point at which the blob is gone — then its chunks; returns whether a manifest was there. |
| `purgeOrphanedChunks` | `Future<int> purgeOrphanedChunks()` | Deletes chunk rows no manifest refers to, returning how many were removed. Housekeeping for the residue of a replace or delete whose chunk cleanup failed; belongs on a schedule rather than in the request path. |
| `toString` | `String toString()` | *(override)* Renders `TomDatabaseBlobStore(<manifestTable>)`. |

### TomBlobManifestRow

One row of the blob manifest table, as the result mapper materialises it.
Reflected and `@TomDbTable`-annotated because the data source's row mapper
requires both; the annotation's table values are placeholders, since the real
table name is a constructor argument of `TomDatabaseBlobStore`.

#### Constructors

```dart
TomBlobManifestRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `storageKey` | `String` | The storage key (column `storage_key`). |
| `uploadId` | `String` | The id of the committed upload whose chunks hold this blob's content (column `upload_id`). |
| `mediaType` | `String` | The IANA media type the bytes should be served as (column `media_type`). |
| `fileName` | `String?` | The original file name, or `null` when none was supplied — the ordinary case, since most blobs are written by key (column `file_name`). |
| `byteCount` | `int` | The blob's size in bytes (column `byte_count`). |
| `chunkCount` | `int` | How many chunk rows the content occupies (column `chunk_count`). |
| `storedAt` | `DateTime` | When the write completed, read back as UTC (column `stored_at`). |

### TomBlobChunkRow

One chunk row's payload, as the result mapper materialises it. Reflected and
`@TomDbTable`-annotated for the same reason as `TomBlobManifestRow`, and mapping
only the one column a read needs.

#### Constructors

```dart
TomBlobChunkRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `chunkData` | `String` | The base64-encoded bytes of this chunk, decoded by `TomDatabaseBlobStore.get` (column `chunk_data`). |

### TomAwsCredentials

The credentials a signer presents — a key pair, optionally with a session token
for temporary (STS / instance-role) credentials.

#### Constructors

```dart
const TomAwsCredentials({
  required String accessKeyId,
  required String secretAccessKey,
  String? sessionToken,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `accessKeyId` | `String` | The public key id (final). |
| `secretAccessKey` | `String` | The secret used to derive the signing key; never transmitted (final). |
| `sessionToken` | `String?` | The session token accompanying temporary credentials, or `null` (final). |

### TomAwsV4Signer

Signs HTTP requests with AWS Signature Version 4 — the request signing every
S3-compatible object store speaks. Kept apart from the store that uses it
because signing is a pure function of a request and a key, so it is verified
against the algorithm's published test vectors rather than against a live
bucket.

#### Constructors

```dart
const TomAwsV4Signer({
  required TomAwsCredentials credentials,
  required String region,
  String service = 's3',
})
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `algorithm` | `static const String` | The algorithm identifier that opens the string to sign: `AWS4-HMAC-SHA256`. |
| `unsignedPayload` | `static const String` | The payload hash to send when the body is not hashed in advance (`UNSIGNED-PAYLOAD`), permitted by S3 over TLS. |
| `emptyPayloadHash` | `static const String` | The SHA-256 of the empty string — the payload hash of every bodyless request, precomputed because it appears in most of them. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `canonicalPath` | `static String canonicalPath(Uri uri)` | The canonical (percent-encoded, slash-preserving) path; an empty path canonicalises to `/` and every segment is encoded with the unreserved-character set. |
| `canonicalQuery` | `static String canonicalQuery(Uri uri)` | The canonical query string: every parameter encoded and sorted, values included even when empty (`?uploads` signs as `uploads=`). |
| `encodeRfc3986` | `static String encodeRfc3986(String value)` | Percent-encodes `value` leaving only the RFC 3986 unreserved characters — stricter than `Uri.encodeComponent`, which leaves `!`, `*`, `'`, `(` and `)` alone. |
| `hashPayload` | `static String hashPayload(List<int> payload)` | The hex SHA-256 of `payload` — the payload hash of a signed body. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `credentials` | `TomAwsCredentials` | The credentials to sign with (final). |
| `region` | `String` | The region the credential scope names, e.g. `eu-central-1` (final). |
| `service` | `String` | The service the credential scope names (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `signedHeaders` | `Map<String, String> signedHeaders({required String method, required Uri uri, required Map<String, String> headers, required String payloadHash, DateTime? now})` | The headers to send with a signed request: the caller's own headers plus `host`, `x-amz-date`, `x-amz-content-sha256`, the optional `x-amz-security-token`, and `authorization`. `now` is injectable so a test can assert against a published vector; it defaults to the current UTC time. |
| `signingKey` | `List<int> signingKey(String dateStamp)` | The date-scoped signing key for `dateStamp` (`YYYYMMDD`), derived by HMAC-ing date, region, service and terminator in turn so a leaked key is scoped to one day, region and service. |

### TomS3BlobStore

A blob store over an S3-compatible object store — Amazon S3, MinIO, Ceph,
Backblaze B2, DigitalOcean Spaces and the rest — with no SDK dependency. An
upload that fits in one `partSize` buffer goes out as a single signed `PUT`;
anything larger becomes a multipart upload, so memory is bounded by the part
size rather than by the object size, and a failure aborts the upload so a
half-sent object never becomes readable.

- **Extends:** `TomBlobStore`

#### Constructors

```dart
TomS3BlobStore({
  required Uri endpoint,
  required String bucket,
  required String region,
  required TomAwsCredentials credentials,
  bool pathStyle = true,
  int partSize = defaultPartSize,
  String? keyPrefix,
  http.Client? client,
})
```

Throws `storage.s3.part_size_too_small` when `partSize` is below
`minimumPartSize`, and `storage.blob.invalid_key_prefix` when `keyPrefix` is not
a usable namespace — the prefix is joined *after* the per-call key check and the
result goes straight into a signed request URI, so it is checked nowhere else.
The same error is raised per request when the prefix and the caller's key are
each valid but join past `TomBlobStore.maxKeyLength`; S3's own limit is twice
ours, so nothing downstream would object. When no `client` is supplied the store
creates and owns one, and `close` disposes of it.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `minimumPartSize` | `static const int` | S3's minimum size for any part but the last: 5 MiB. |
| `defaultPartSize` | `static const int` | The default bytes per multipart part: 8 MiB — above `minimumPartSize` with room to spare, and small enough that the upload buffer it bounds stays a reasonable per-upload allocation. Declared once here rather than repeated at each defaulting site, so a change lands everywhere. |
| `fileNameHeader` | `static const String` | The header the original file name is carried in: `x-amz-meta-filename`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `parseHttpDate` | `static DateTime parseHttpDate(String value)` | Parses an RFC 7231 IMF-fixdate (`Wed, 21 Oct 2015 07:28:00 GMT`); throws a `FormatException` on anything else. Exposed for the test that pins the one header this store reads a value out of. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `endpoint` | `Uri` | The service root, without the bucket (final). |
| `bucket` | `String` | The bucket every key resolves inside (final). |
| `region` | `String` | The region the credential scope names (final). |
| `pathStyle` | `bool` | Whether objects are addressed as `<endpoint>/<bucket>/<key>`; `true` by default because every self-hosted implementation accepts it, `false` for Amazon's virtual-host addressing (final). |
| `partSize` | `int` | Bytes per multipart part, and the upload buffer bound; defaults to `defaultPartSize` (final). |
| `keyPrefix` | `String?` | A prefix prepended to every key, so one bucket can host several stores. Checked twice, because one check cannot cover it: at construction against `TomBlobStore.isValidKeyPrefix`, and at every request against `TomBlobStore.maxKeyLength` on the joined key, which cannot be settled before a key arrives. Either refusal is `storage.blob.invalid_key_prefix` (final). |
| `signer` | `TomAwsV4Signer` | The request signer, built from the constructor's credentials and region (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Buffers up to `partSize`: a stream that ends inside the first buffer is one signed `PUT`, otherwise each full buffer becomes a part and the upload is completed at the end. Any failure issues an `AbortMultipartUpload` and rethrows, so `put` reports `storage.blob.write_failed` — or passes through the storage exception already thrown. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Streams the response body of a signed `GET`; `404` drains the body and throws `storage.blob.not_found`, any other error status throws `storage.s3.request_failed`. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* A signed `HEAD`, mapping `content-type`, `content-length`, `last-modified` and `x-amz-meta-filename` into the descriptor; `null` on `404`. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Probes with `doExists` first, because S3 answers `204` to a delete whether or not the object was there, then sends the signed `DELETE`. |
| `close` | `Future<void> close()` | *(override)* Closes the HTTP client, but only the one this store created. |
| `toString` | `String toString()` | *(override)* Renders `TomS3BlobStore(<bucket> at <endpoint>)`. |

### TomBlobStoreFactory

Builds a store of one backend type from its configured settings. A closure
rather than an annotation-discovered driver, so a backend can capture whatever
it needs — a configured HTTP client, an existing credential provider — and can
be added with a one-line registration instead of a reflection rebuild.

```dart
typedef TomBlobStoreFactory = FutureOr<TomBlobStore> Function(
  String name,
  Map<String, dynamic> settings,
);
```

### TomBlobStoreInfo

The process-wide registry of named, configured blob stores, and one entry in it.
Deliberately the same shape as `TomDataSourceInfo`: a map of named entries, each
a `type` plus that type's settings, built once at start-up from the
configuration and looked up by name thereafter. The four built-in backends
(`memory`, `directory`, `database`, `s3`) are pre-registered, so a configuration
naming one of them needs no code at all.

#### Constructors

```dart
TomBlobStoreInfo(String name, Map<String, dynamic> settings, {TomBlobStoreFactory? factory})
```

`factory` builds the store when `open` is called; when it is null — the
configured case — the backend named by `settings['type']` is looked up among the
registered backends instead. Passing one is how a store that no settings map
could describe still gets an entry that can build itself.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providedType` | `static const String` | The `type` recorded for a store handed over as an instance (`'provided'`). Deliberately not a registered backend: it names how the store arrived rather than a way to build one, so a configuration naming it fails like any other unknown type and `backendTypes` does not list it. |
| `stores` | `static final Map<String, TomBlobStoreInfo>` | All registered stores, keyed by name. |
| `defaultStoreName` | `static String?` | The name `defaultStore` resolves to, or `null` when none is nominated. |
| `backendTypes` | `static Iterable<String>` | *(getter)* The backend type names currently registered. |
| `defaultStore` | `static TomBlobStore` | *(getter)* The store to use when nothing names one; throws `storage.registry.no_default_store` when no default was nominated. |
| `hasDefaultStore` | `static bool` | *(getter)* Whether a default store is available — a name is nominated and a store is registered under it. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerBackend` | `static void registerBackend(String type, TomBlobStoreFactory factory)` | Registers `factory` as the builder for backend `type`, replacing any previous registration of the same name. Call before `initializeBlobStores`: an unknown type is a start-up failure, not a lazy one. |
| `getBlobStoreInfo` | `static TomBlobStoreInfo? getBlobStoreInfo(String name)` | The registered info for `name`, or `null` if none. |
| `storeNamed` | `static TomBlobStore storeNamed(String name)` | The store registered as `name`; throws `storage.registry.unknown_store` when there is none, so a typo or an unconfigured deployment is reported rather than silently written somewhere else. |
| `initializeBlobStores` | `static Future<int> initializeBlobStores(Map<String, dynamic> configuration)` | Builds and registers a store for every map-valued entry of `configuration`, returning the number registered. Keys are read defensively because YAML arrives as a `Map<dynamic, dynamic>`. One entry may carry `default: true`; when the configuration names exactly one store it becomes the default without saying so — counted over the entries this call registered, not over every store the process holds, so an application that registered one in code first still gets it. Only ever fills a default that is still unset, so an `asDefault` nominated in code survives; a `default: true` in the configuration displaces it. |
| `register` | `static TomBlobStoreInfo register(String name, TomBlobStore store, {bool asDefault = false})` | Registers a ready-made `store` under `name` — the seam a test, or an application that builds its store in code, uses instead of configuration. The entry records `providedType` and carries a factory closing over `store`, so it is buildable like any other: `open` on it, after a `closeAll` say, hands back the store it was given. |
| `closeAll` | `static Future<void> closeAll()` | Closes every registered store, empties the registry and clears the default name. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The registry key / logical name of this store (final). |
| `settings` | `Map<String, dynamic>` | The raw configuration for this store (final). |
| `store` | `TomBlobStore` | *(getter)* The live store; available once `open` or `register` has run. |
| `type` | `String` | *(getter)* The backend type, from `settings['type']` — a registered backend for a configured store, `providedType` for one handed over as an instance. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `Future<void> open()` | Builds this entry's store and registers it — from the entry's own factory when it has one, otherwise from the backend its `type` names. An entry always has one or the other, so `storage.registry.unknown_backend` reports a configuration naming a backend nobody registered and never an entry that cannot describe itself; `storage.registry.missing_setting` reports a built-in backend's required setting being absent. |
| `toString` | `String toString()` | *(override)* Renders `TomBlobStoreInfo <name> <type> <store>`. |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultBlobManifestTable` | `String` | The default name of the blob manifest table, `tom_blob`. |
| `defaultBlobChunkTable` | `String` | The default name of the blob chunk table, `tom_blob_chunk`. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `blobManifestTable` | `TomFrameworkTable blobManifestTable(String table)` | The one declaration of the one-row-per-blob manifest table: `storage_key` as the primary key, sized from `TomBlobStore.maxKeyLength` so it cannot silently truncate a key the validator accepted; `upload_id` naming the committed upload; `media_type`, the nullable `file_name`, `byte_count`, `chunk_count`, and `stored_at` as `DATETIME(6)` — the width the framework's instant rendering writes, since a narrower column would silently round the microseconds and move the stored moment. |
| `blobChunkTable` | `TomFrameworkTable blobChunkTable(String table)` | The one declaration of the many-rows-per-blob content table, keyed on `(upload_id, chunk_index)` so the chunks of an in-flight write are addressable before anything commits to them. `chunk_data` is `LONGTEXT` holding base64, because the driver decodes every column value into a Dart `String`. |
| `blobManifestTableDdl` | `String blobManifestTableDdl(String table)` | The `CREATE TABLE` statement for the manifest table, derived from `blobManifestTable`. What a deployment applies by hand when its credential may not run DDL: for the default name that text is the shipped `[1]-create_tom_blob.sql`, and for a store constructed with `manifestTable:` there is no shipped file, so this is the only source. |
| `blobChunkTableDdl` | `String blobChunkTableDdl(String table)` | The `CREATE TABLE` statement for the chunk table, derived from `blobChunkTable` — the `[2]-create_tom_blob_chunk.sql` counterpart of `blobManifestTableDdl`, and the same answer for a renamed `chunkTable:`. |
