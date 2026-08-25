# Tom Core Server API Reference: File Storage Module

Storage by key for files too large to live in a row: a streaming
put/get/describe/delete contract, four shipped backends behind it, and the
named registry that selects one from configuration.

## Table of Contents

- [Overview](#overview)
- [Class Hierarchy](#class-hierarchy)
- [Classes](#classes)
  - [TomStorageException](#tomstorageexception)
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
`maxKeyLength` and `validateKey` are called at the top of every `put`, so an
invalid key never reaches a filesystem, a network or SQL.

Four backends implement the contract. `TomMemoryBlobStore` holds everything in a
map — for tests and for a development server that should leave nothing behind.
`TomDirectoryBlobStore` maps keys onto paths beneath a root directory, writing
to a sibling `.part` file and renaming it into place, with a `<key>.meta` JSON
sidecar for the media type and file name a filesystem cannot store.
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

### TomStoredBlob

What a stored blob is: its key, what it contains, how big it turned out.
Returned by `TomBlobStore.put` rather than assembled by the caller, because
`byteCount` is only known once the stream has drained.

#### Constructors

```dart
const TomStoredBlob({
  required String key,
  required String mediaType,
  required int byteCount,
  required DateTime storedAt,
  String? fileName,
  Uri? location,
})
```

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
| `storedAt` | `DateTime` | When the write completed (final). |
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

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `isValidKey` | `static bool isValidKey(String key)` | Whether `key` is a well-formed storage key: non-empty, at most `maxKeyLength`, no leading or trailing `/`, no backslash, no `//`, only `A-Za-z0-9._/-`, and no `.` or `..` segment. |
| `validateKey` | `static String validateKey(String key)` | Returns `key` when `isValidKey` accepts it, otherwise throws `storage.blob.invalid_key`. |
| `notFound` | `static TomStorageException notFound(String key)` | Builds the `storage.blob.not_found` error, spelled once so every backend agrees and a caller can match on the key string. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | Writes `bytes` under `key`, replacing anything already there, and returns the descriptor. A failure must leave nothing readable under `key` beyond what was there before: implementations commit atomically or not at all. |
| `get` | `Stream<List<int>> get(String key)` | Reads the blob stored under `key`; throws `storage.blob.not_found` when the key holds nothing, rather than disguising a missing blob as an empty file. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | The descriptor for `key`, or `null` when it holds nothing — the one read allowed to answer "nothing" without throwing. |
| `delete` | `Future<bool> delete(String key)` | Deletes `key`, returning whether anything was there to delete. |
| `exists` | `Future<bool> exists(String key)` | Whether `key` currently holds a blob; defined in terms of `describe` so a backend implements one lookup, overridden where a cheaper probe exists. |
| `getBytes` | `Future<Uint8List> getBytes(String key)` | Reads `key` fully into memory — the convenience for call sites that genuinely know their blobs are small. A helper on the streaming API, not a second contract method, so a backend author cannot implement it instead of streaming. |
| `putBytes` | `Future<TomStoredBlob> putBytes({required String key, required List<int> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | The buffered counterpart to `getBytes`; delegates to `put` with a single-value stream. |
| `close` | `Future<void> close()` | Releases whatever the backend holds open. Idempotent; the default does nothing, because most backends hold nothing. |

### TomMemoryBlobStore

A store that keeps its contents in memory, for tests and for a development
server that should not leave files behind. It buffers whole blobs by definition,
which is why it is not a default.

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
| `textOf` | `String textOf(String key)` | The stored bytes for `key` decoded as UTF-8 text (malformed input allowed), for tests that assert on content; throws `storage.blob.not_found` when the key holds nothing. |
| `clear` | `void clear()` | Forgets everything, for a test that reuses one store across cases. |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Validates the key and drains the stream fully before either map is touched, so a stream that throws half way leaves no half-written blob. |
| `get` | `Stream<List<int>> get(String key)` | *(override)* Yields the buffered bytes as one chunk; throws `storage.blob.not_found` when absent. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | *(override)* The descriptor recorded by `put`, or `null`. |
| `exists` | `Future<bool> exists(String key)` | *(override)* Answers straight from the content map rather than through `describe`. |
| `delete` | `Future<bool> delete(String key)` | *(override)* Drops the content and its descriptor, returning whether content was present. |
| `toString` | `String toString()` | *(override)* Renders `TomMemoryBlobStore(<n> blobs)`. |

### TomDirectoryBlobStore

A blob store over a directory tree on the local filesystem: keys become paths
beneath `root`, so `2026/07/invoice.pdf` is a file two directories down and the
stored blobs are browsable with `ls`. Media type and original file name go to a
`<key>.meta` JSON sidecar, since a filesystem stores bytes and nothing else.

- **Extends:** `TomBlobStore`

#### Constructors

```dart
TomDirectoryBlobStore(Directory root)

TomDirectoryBlobStore.at(String path)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `metadataSuffix` | `static const String` | The sidecar suffix, `.meta` — chosen so a metadata file can never be mistaken for a blob. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `root` | `Directory` | The directory every key resolves beneath; created on first write (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Streams to a sibling `<file>.part` and renames it into place, so a reader sees the previous blob or the complete new one; a failure deletes the partial and throws `storage.blob.write_failed`. The sidecar is written after the rename. |
| `get` | `Stream<List<int>> get(String key)` | *(override)* Streams the file with `openRead`; throws `storage.blob.not_found` when it does not exist. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | *(override)* Size and mtime from `stat()`, media type and file name from the sidecar when it is present and parseable — so a directory populated by `scp` is still readable. |
| `exists` | `Future<bool> exists(String key)` | *(override)* A direct file-existence probe. |
| `delete` | `Future<bool> delete(String key)` | *(override)* Deletes the file and its sidecar, returning whether the file was there. |
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
  int chunkSize = 256 * 1024,
  bool createSchema = true,
})
```

#### Factory Constructors

```dart
factory TomDatabaseBlobStore.named(
  String datasourceName, {
  String manifestTable = defaultBlobManifestTable,
  String chunkTable = defaultBlobChunkTable,
  int chunkSize = 256 * 1024,
  bool createSchema = true,
})
```

Resolves the registered data source named `datasourceName`, throwing
`storage.database.unknown_datasource` when there is none — a configuration
error far better caught at start-up than on the first upload.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the two tables live in (final). |
| `manifestTable` | `String` | The one-row-per-blob manifest table (final). |
| `chunkTable` | `String` | The many-rows-per-blob content table (final). |
| `chunkSize` | `int` | Raw bytes per chunk row; the stored text is ~4/3 of that. The 256 KiB default keeps a chunk statement inside MariaDB's default `max_allowed_packet` while making a megabyte-scale file a handful of round trips (final). |
| `createSchema` | `bool` | Whether to create the tables on first use; set `false` when the schema is owned by the migration module and the application's database user may not run DDL (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the two tables if they do not exist. Idempotent and called automatically by every operation; exposed so a start-up sequence can provision the schema before serving traffic. |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Slices the incoming stream into `chunkSize` chunk rows under a fresh upload id, then replaces the manifest row — the commit point. A failure deletes the chunks it wrote and throws `storage.blob.write_failed`; superseded chunks are removed afterwards and a failure to do so is logged, not raised. |
| `get` | `Stream<List<int>> get(String key)` | *(override)* Reads the manifest, then fetches and base64-decodes one chunk row per consumer demand; throws `storage.blob.not_found` for an unknown key and `storage.blob.missing_chunk` when the manifest and its chunks disagree. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | *(override)* Builds the descriptor from the manifest row, or `null`. An empty `file_name` is treated as absent, so a `NOT NULL` variant of the table behaves the same. |
| `delete` | `Future<bool> delete(String key)` | *(override)* Deletes the manifest row first — that is the point at which the blob is gone — then its chunks; returns whether a manifest was there. |
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
| `storedAt` | `DateTime` | When the write completed (column `stored_at`). |

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
  int partSize = 8 * 1024 * 1024,
  String? keyPrefix,
  http.Client? client,
})
```

Throws `storage.s3.part_size_too_small` when `partSize` is below
`minimumPartSize`. When no `client` is supplied the store creates and owns one,
and `close` disposes of it.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `minimumPartSize` | `static const int` | S3's minimum size for any part but the last: 5 MiB. |
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
| `partSize` | `int` | Bytes per multipart part, and the upload buffer bound (final). |
| `keyPrefix` | `String?` | A prefix prepended to every key, so one bucket can host several stores (final). |
| `signer` | `TomAwsV4Signer` | The request signer, built from the constructor's credentials and region (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Buffers up to `partSize`: a stream that ends inside the first buffer is one signed `PUT`, otherwise each full buffer becomes a part and the upload is completed at the end. Any failure issues an `AbortMultipartUpload` and raises `storage.blob.write_failed` (or the storage exception already thrown). |
| `get` | `Stream<List<int>> get(String key)` | *(override)* Streams the response body of a signed `GET`; `404` drains the body and throws `storage.blob.not_found`, any other error status throws `storage.s3.request_failed`. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | *(override)* A signed `HEAD`, mapping `content-type`, `content-length`, `last-modified` and `x-amz-meta-filename` into the descriptor; `null` on `404`. |
| `delete` | `Future<bool> delete(String key)` | *(override)* Probes with `exists` first, because S3 answers `204` to a delete whether or not the object was there, then sends the signed `DELETE`. |
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
TomBlobStoreInfo(String name, Map<String, dynamic> settings)
```

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
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
| `initializeBlobStores` | `static Future<int> initializeBlobStores(Map<String, dynamic> configuration)` | Builds and registers a store for every map-valued entry of `configuration`, returning the number registered. Keys are read defensively because YAML arrives as a `Map<dynamic, dynamic>`. One entry may carry `default: true`; when exactly one store is configured it becomes the default without saying so. |
| `register` | `static TomBlobStoreInfo register(String name, TomBlobStore store, {bool asDefault = false})` | Registers a ready-made `store` under `name` — the seam a test, or an application that builds its store in code, uses instead of configuration. |
| `closeAll` | `static Future<void> closeAll()` | Closes every registered store, empties the registry and clears the default name. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The registry key / logical name of this store (final). |
| `settings` | `Map<String, dynamic>` | The raw configuration for this store (final). |
| `store` | `TomBlobStore` | *(getter)* The live store; available once `open` or `register` has run. |
| `type` | `String` | *(getter)* The backend type, from `settings['type']`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `Future<void> open()` | Builds this entry's store from its `settings` through the factory for its `type` and registers it; throws `storage.registry.unknown_backend` when the type has no factory, and `storage.registry.missing_setting` when a built-in backend's required setting is absent. |
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
| `blobManifestTable` | `TomFrameworkTable blobManifestTable(String table)` | The one declaration of the one-row-per-blob manifest table: `storage_key` as the primary key, sized from `TomBlobStore.maxKeyLength` so it cannot silently truncate a key the validator accepted; `upload_id` naming the committed upload; `media_type`, the nullable `file_name`, `byte_count`, `chunk_count`, and a plain `DATETIME` `stored_at`. |
| `blobChunkTable` | `TomFrameworkTable blobChunkTable(String table)` | The one declaration of the many-rows-per-blob content table, keyed on `(upload_id, chunk_index)` so the chunks of an in-flight write are addressable before anything commits to them. `chunk_data` is `LONGTEXT` holding base64, because the driver decodes every column value into a Dart `String`. |
| `blobManifestTableDdl` | `String blobManifestTableDdl(String table)` | The `CREATE TABLE` statement for the manifest table, derived from `blobManifestTable`. |
| `blobChunkTableDdl` | `String blobChunkTableDdl(String table)` | The `CREATE TABLE` statement for the chunk table, derived from `blobChunkTable`. |
