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
  - [TomAwsCredentialsSource](#tomawscredentialssource)
  - [TomAwsV4Signer](#tomawsv4signer)
  - [TomS3BlobStore](#toms3blobstore)
  - [TomBlobStoreBackend](#tomblobstorebackend)
  - [The four built-in backends](#the-four-built-in-backends)
  - [TomBlobStoreBackendFactory](#tomblobstorebackendfactory)
  - [TomBlobStoreInfo](#tomblobstoreinfo)
  - [TomDeduplicatingBlobStore](#tomdeduplicatingblobstore)
  - [TomBlobQuota](#tomblobquota)
  - [TomBlobUsage](#tomblobusage)
  - [TomBlobLedger](#tomblobledger)
  - [TomBlobLedgerEntry](#tomblobledgerentry)
  - [TomBlobContent](#tomblobcontent)
  - [TomMemoryBlobLedger](#tommemoryblobledger)
  - [TomSqlBlobLedger](#tomsqlblobledger)
  - [TomBlobLedgerEntryRow](#tomblobledgerentryrow)
  - [TomBlobContentRow](#tomblobcontentrow)
  - [TomBlobUsageRow](#tomblobusagerow)
  - [TomBlobReferenceCountRow](#tomblobreferencecountrow)
- [Global Functions and Constants](#global-functions-and-constants)

## Overview

Source: `lib/src/tomserver/file_storage/blob_store.dart`,
`lib/src/tomserver/file_storage/directory_blob_store.dart`,
`lib/src/tomserver/file_storage/database_blob_store.dart`,
`lib/src/tomserver/file_storage/database_blob_sql.dart`,
`lib/src/tomserver/file_storage/s3_blob_store.dart`,
`lib/src/tomserver/file_storage/aws_v4_signer.dart`,
`lib/src/tomserver/file_storage/blob_store_backends.dart`,
`lib/src/tomserver/file_storage/blob_store_registry.dart`,
`lib/src/tomserver/file_storage/blob_ledger.dart`,
`lib/src/tomserver/file_storage/blob_ledger_sql.dart`,
`lib/src/tomserver/file_storage/deduplicating_blob_store.dart`.

`TomBlobStore` is the contract: five operations — `put`, `get`, `describe`,
`exists` and `delete` — over a key and a `Stream<List<int>>`. A *backend*
implements four of them; `exists` defaults to `describe(key) != null`, so the
count differs depending on which side of the abstraction is being counted.
There is no `list`, no rename
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
vectors. `TomAwsCredentialsSource`, declared beside them, is the function a
signing client calls for each request's credentials — the shape
`tom_core_secrets`' AWS provider and `tom_core_message_bus_aws` take. Finally, `TomBlobStoreInfo` is the process-wide registry of named,
configured stores — the same shape as `TomDataSourceInfo` — and a
`TomBlobStoreBackend` is what a configured store's `type` names: a class whose
fields are that backend's settings, so a key in a store's block that names no
field is refused at start-up. An application registers its own backend through a
`TomBlobStoreBackendFactory`, and a deployment then spells it in configuration
exactly like a built-in one.

`TomDeduplicatingBlobStore` is a `TomBlobStore` in front of any other one — the
*content store* — and a `TomBlobLedger`, the record a plain store cannot keep of
itself: one `TomBlobLedgerEntry` per logical key (owner, digest, content key,
size) and one `TomBlobContent` per distinct SHA-256. A write streams into a
staging key while the store hashes it, then becomes the content for that digest
or is discarded when the content is already held, so every key naming the same
bytes shares one stored copy and a copy moves no bytes. Each write and copy is
charged to an owner — the principal in the zone, or the owner `runAs` names — and
refused past a `TomBlobQuota`, measured in `TomBlobUsage`. Deleting a key removes
its entry; `reclaim` deletes content no entry names once nothing has claimed it
for `reclaimGrace`. `TomMemoryBlobLedger` keeps the record in memory and
`TomSqlBlobLedger` in the framework-owned tables `tom_blob_ledger` and
`tom_blob_content`, declared by `blobLedgerTable` and `blobContentTable`, with
`TomBlobLedgerEntryRow`, `TomBlobContentRow`, `TomBlobUsageRow` and
`TomBlobReferenceCountRow` as its reflected row types. Which keys no row refers
to is the persistence module's `TomBlobOrphanSweep`, which walks the ledger.

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

```text
TomServerException  (little_things)
    └── TomStorageException

TomBlobStoreOperation  (enum)

TomBlobStore  (abstract)
    ├── TomMemoryBlobStore
    ├── TomDirectoryBlobStore
    ├── TomDatabaseBlobStore
    ├── TomS3BlobStore
    └── TomDeduplicatingBlobStore

TomBlobLedger  (abstract)
    ├── TomMemoryBlobLedger
    └── TomSqlBlobLedger

TomBlobLedgerEntry
TomBlobContent
TomBlobUsage
TomBlobQuota

TomBlobLedgerEntryRow
TomBlobContentRow
TomBlobUsageRow
TomBlobReferenceCountRow

TomStoredBlob

TomBlobManifestRow
TomBlobChunkRow

TomAwsCredentials
TomAwsCredentialsSource  (typedef)
TomAwsV4Signer

TomBlobStoreBackend  (abstract)
    ├── TomMemoryBlobStoreBackend
    ├── TomDirectoryBlobStoreBackend
    ├── TomDatabaseBlobStoreBackend
    └── TomS3BlobStoreBackend

TomBlobStoreBackendFactory  (typedef)
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
  StackTrace? stack,
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
| `copy` | `storage.blob.copy_failed` | Putting what one key holds under a second one as well failed. |
| `move` | `storage.blob.move_failed` | Moving what one key holds to another failed. |
| `deletePrefix` | `storage.blob.prefix_delete_failed` | Removing everything under a key prefix failed. |

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
  String digest = TomStoredBlob.unknownDigest,
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
| `unknownDigest` | `static const String` | The `digest` of a blob whose hash was never recorded — a named empty string, so "not recorded" cannot be confused with the digest of zero bytes, which is a real and well-known value. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The key the blob is stored under (final). |
| `mediaType` | `String` | The IANA media type the bytes should be served as (final). |
| `byteCount` | `int` | The number of bytes stored (final). |
| `storedAt` | `DateTime` | When the write completed, always in UTC — the constructor normalises whatever it is given (final). |
| `fileName` | `String?` | The original file name, when one was supplied — kept because the storage key is chosen by the framework while the name a person expects in their downloads folder is the one they uploaded (final). |
| `location` | `Uri?` | A backend-specific address (a `file:` URI, an object-store URL); useful to a human chasing a blob down, never the thing to read it back with (final). |
| `digest` | `String` | The lowercase hex SHA-256 of the stored bytes (final). Every blob written through `TomBlobStore.put` has one, whichever backend is configured: the hash is computed while the bytes stream past, on a pass the backend is making anyway, and recorded beside the media type and the file name. `unknownDigest` for a blob this framework did not write — a file dropped into a directory store's tree, an object already in a bucket — which has no recorded media type either. |
| `hasDigest` | `bool` | *(getter)* Whether `digest` holds a hash rather than `unknownDigest`. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `TomStoredBlob(<key>, <byteCount> bytes, <mediaType>)`. |

### TomBlobDigest

The running SHA-256 of a blob, fed chunk by chunk as it is stored. A backend
hashes on the pass it is already making — a file write, a chunk insert, a part
upload — so the digest costs no extra read. Public because
`TomStoredBlob.digest` is a promise every backend has to keep, including one an
application writes, and a promise the framework does not make easy to keep is
one that gets broken.

- **Extends:** none

#### Constructors

```dart
TomBlobDigest()
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `of` | `static String of(List<int> bytes)` | The hex SHA-256 of `bytes`, for a caller holding them whole. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `add` | `void add(List<int> chunk)` | Feeds `chunk` to the running hash. The chunk is read, never retained, which is what lets a backend pass the same borrowed buffer it is about to write. Throws `StateError` after `close`. |
| `close` | `String close()` | The lowercase hex digest of everything added. Idempotent — calling it again returns the same string rather than closing a closed hash, so a backend with more than one exit path does not have to track which one ran. |

### TomBlobRange

A half-open byte range of a stored blob — `start` inclusive, `endExclusive`
exclusive — for the partial read `TomBlobStore.get` takes. Half-open because
`File.openRead` and `List.sublist` are, which is where a range ends up. HTTP's
`Range` is inclusive at both ends and its suffix form (`bytes=-500`) names no
start at all; both are resolved against the blob's known size before they reach
here, by whoever read the header, so a backend never reasons about a range it
cannot check. Both ends are validated at construction, so every backend refuses
the same nonsense the same way — the reason key validation sits on
`TomBlobStore` and not in each `do*`.

- **Extends:** none

#### Constructors

```dart
TomBlobRange(int start, [int? endExclusive])
```

Throws `TomStorageException` (`storage.blob.invalid_range`) for a negative start
or an end at or before it. An empty range is refused rather than answered with
an empty stream: a zero-length read is a caller's arithmetic going wrong, and an
empty body is how that mistake reaches a user as a corrupt download.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `start` | `int` | The first byte to read, counted from zero (final). |
| `endExclusive` | `int?` | One past the last byte to read, or `null` to read to the end — the form a `bytes=500-` header takes, and the only one that needs no size to resolve (final). |
| `length` | `int?` | *(getter)* How many bytes the range covers, or `null` when it runs to the end. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `clampedTo` | `TomBlobRange? clampedTo(int byteCount)` | The range clamped to a blob of `byteCount` bytes, or `null` when it lies wholly beyond it. `null` is what HTTP calls *unsatisfiable*: a start at or past the end names no byte, and the correct answer is a refusal rather than an empty body. A range that merely overshoots is clamped instead — asking for more than there is and getting what there is is how a resumed download ends. |
| `toString` | `String toString()` | *(override)* Renders `TomBlobRange(<start>, <endExclusive>)`. |

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
| `supportsPrefixDelete` | `bool` | *(getter)* Whether this backend can delete every blob under a key prefix. Asked at wire-up, because it decides whether a deployment's retention pass is one call per partition or one per blob. `false` by default: a backend that does not answer the question does not get to be assumed capable. |
| `maxKeyLength` | `static const int` | The longest key any backend accepts (512) — comfortably under the shortest limit in play, so the database backend can declare a fixed-width indexed column and a filesystem is never handed a name the OS rejects. |
| `passThroughErrorKeys` | `static const Set<String>` | The seven keys that reach a caller as the backend raised them — `storage.blob.not_found`, `invalid_key`, `invalid_key_prefix`, `missing_chunk` and `same_key`, and `storage.quota.count_exceeded` and `bytes_exceeded`, the refusals of a `TomDeduplicatingBlobStore`'s quota. Everything else, *including a backend's own `TomStorageException`*, is wrapped under the operation's key with the original as `rootException`. The match is on the key rather than the type, which is what stops `storage.s3.request_failed` reaching a caller who is supposed to be backend-agnostic; the list is closed by a rule — every member is raised by shared code or enforces a limit every backend obeys — so a backend cannot add to it. |
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

The public methods are the contract's own and are not overridden: each
validates the key and translates any failure, then defers to the `do*` method a
backend implements. That is what makes both obligations hold for every backend
— including one an application writes — rather than leaving each to honour a
different subset of them, which is what the four shipped backends did.

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `put` | `Future<TomStoredBlob> put({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | Validates `key`, calls `doPut`, reports any other failure as `storage.blob.write_failed`. Writes `bytes` under `key`, replacing anything already there, and returns the descriptor. A failure must leave nothing readable under `key` beyond what was there before: implementations commit atomically or not at all. A chunk from `bytes` is borrowed for the duration of the `await` — consume or copy it before asking for the next, never retain it, since a producer refilling one scratch buffer per chunk is the ordinary shape of an encoder. |
| `get` | `Stream<List<int>> get(String key, {TomBlobRange? range})` | Validates `key`, reads through `doGet` — or through `doGetRange` when a `range` is given — reports any other failure as `storage.blob.read_failed`. Throws `storage.blob.not_found` when the key holds nothing, rather than disguising a missing blob as an empty file. Each chunk belongs to the caller: writable, and aliased with nothing the store keeps. Consumes the backend's stream with `await for` rather than `yield*`, because a `yield*` forwards the inner stream's errors past the enclosing `try` and the translation would never run. A transfer that breaks partway still delivers the chunks that arrived and *then* throws — draining the backend's stream first would satisfy the error contract while turning every interrupted download into an empty one, and would reintroduce buffering on the read side. |
| `describe` | `Future<TomStoredBlob?> describe(String key)` | Validates `key`, calls `doDescribe`, reports any other failure as `storage.blob.probe_failed`. The descriptor for `key`, or `null` when it holds nothing — the one read allowed to answer "nothing" without throwing. |
| `delete` | `Future<bool> delete(String key)` | Validates `key`, calls `doDelete`, reports any other failure as `storage.blob.delete_failed`. Returns whether anything was there to delete — **exact on a backend that can delete conditionally, best-effort on an object store**. A filesystem, a map and a manifest row answer that in the operation that removes the blob; S3's `DELETE` answers `204` either way, so `TomS3BlobStore` probes separately and another caller can create or remove the key between the two. The window only misleads a caller already racing itself, and the exact answer is kept rather than dropped for a `void` no backend could get wrong. |
| `deletePrefix` | `Future<int> deletePrefix(String prefix)` | Deletes every blob whose key lies under `prefix`, returning how many went. The reclaim primitive, and the only part of retention this module owns: *what* to keep and *how long* are a deployment's decisions, taken against its own record of what it stored, and this is the one operation that record cannot assemble from outside — deleting a partition key by key is a call per blob where a prefix delete is a call per partition. Matched by key **segment**, so `2026/07` never reaches `2026/070`. An empty prefix is refused (`storage.blob.invalid_key`), and a backend whose `supportsPrefixDelete` is `false` throws `storage.blob.prefix_delete_unsupported` naming itself rather than answering `0`. |
| `copy` | `Future<TomStoredBlob> copy(String fromKey, String toKey)` | Validates both keys, refuses them when equal (`storage.blob.same_key`), calls `doCopy`, reports any other failure as `storage.blob.copy_failed`. Anything at `toKey` is replaced, as it is by `put` — the same rule, because a second one about overwriting would be a rule to remember. The media type and file name travel with the bytes: a copy that lost its `Content-Type` is served as `application/octet-stream` and downloads as a file nothing opens. An absent source is `storage.blob.not_found` rather than an empty destination. |
| `move` | `Future<TomStoredBlob> move(String fromKey, String toKey)` | The same, under `storage.blob.move_failed`, with the source gone on return. The **order** is the contract: the destination is committed before the source is removed, so an interrupted move leaves the blob readable under both keys rather than under neither — the residue of a failure is a duplicate, which a retry converges on, where the other order's residue is a deletion. |
| `exists` | `Future<bool> exists(String key)` | Validates `key`, calls `doExists`, reports any other failure as `storage.blob.probe_failed`. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(abstract)* Implemented by a backend; called by `put` with an already-validated key. A backend that fails part-way through cleans up and lets the failure out — `put` names the operation — rather than building a `write_failed` of its own. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(abstract)* Implemented by a backend; called by `get` with an already-validated key. Throws `notFound` when the key holds nothing. |
| `doGetRange` | `Stream<List<int>> doGetRange(String key, TomBlobRange range)` | Called by `get` when a range is given. Defined in terms of `doGet` so a backend implements one read path, not two — the arrangement `doExists` has over `doDescribe` — and overridden by every shipped backend, each of which can seek. The default reads from zero, discards everything before the range and stops once it is served: correct, and costing the prefix, which for a seek near the end of a large blob is the whole thing. Putting that fallback here rather than in the caller is what lets a download endpoint honour HTTP `Range` against any backend while still reaching S3's native capability. A range running past the end yields what there is rather than failing; the caller that knows the size has already refused an unsatisfiable one with `TomBlobRange.clampedTo`. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(abstract)* Implemented by a backend; called by `describe` with an already-validated key. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(abstract)* Implemented by a backend; called by `delete` with an already-validated key. |
| `doExists` | `Future<bool> doExists(String key)` | Called by `exists` with an already-validated key. Defined in terms of `doDescribe` so a backend implements one lookup, not two; overridden where a cheaper existence probe exists. |
| `doDeletePrefix` | `Future<int> doDeletePrefix(String prefix)` | Called by `deletePrefix` with a validated, non-empty prefix. Implemented by backends that declare `supportsPrefixDelete`; the default throws, so a backend claiming the capability and forgetting the method fails loudly rather than reporting an empty purge. |
| `doCopy` | `Future<TomStoredBlob> doCopy(String fromKey, String toKey)` | Called by `copy` with two validated, distinct keys. Concrete, and a stream round trip: read the source, write it to the destination. Overridden by every shipped backend, each of which can relocate without the bytes leaving — a filesystem copy, a map entry, an `INSERT` sharing the chunks, an `x-amz-copy-source` header. A concrete default is right here in a way it would not be for a listing: a stream round trip costs exactly what it looks like it costs, whereas a default `list` would hide a paginated scan behind a method that reads like a map lookup. |
| `doMove` | `Future<TomStoredBlob> doMove(String fromKey, String toKey)` | Called by `move`. Concrete, and defined as `doCopy` followed by `doDelete` — in that order, so an interruption leaves a duplicate rather than a hole. Overridden where the backend can rename. |
| `getBytes` | `Future<Uint8List> getBytes(String key, {TomBlobRange? range})` | Reads `key` fully into memory — the convenience for call sites that genuinely know their blobs are small. A helper on the streaming API, not a second contract method, so a backend author cannot implement it instead of streaming. Collects with a non-copying builder, which returns a lone chunk untouched: it is exactly as aliased as what the backend yielded, which is why `get` promises the caller owns its chunks. |
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
| `supportsPrefixDelete` | `bool` | *(override)* `true` — it holds its own key space, so a prefix delete is a scan of the keys it has. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `textOf` | `String textOf(String key)` | The stored bytes for `key` decoded as UTF-8 text (malformed input allowed), for tests that assert on content. Validates the key like the contract's own methods do — so a test that mistypes one is told it mistyped one — and throws `storage.blob.not_found` when the key holds nothing. |
| `clear` | `void clear()` | Forgets everything, for a test that reuses one store across cases. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Drains the stream fully before either map is touched, so a stream that throws half way leaves no half-written blob. Copies each chunk as it arrives rather than retaining it, so a producer reusing one scratch buffer stores what it streamed. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Yields the buffered bytes as one chunk, copied so the reader owns it; throws `storage.blob.not_found` when absent. |
| `doGetRange` | `Stream<List<int>> doGetRange(String key, TomBlobRange range)` | *(override)* A `sublist`, copied like a whole read. The inherited default would read the whole blob and discard the prefix; here the whole blob is already a list. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* The descriptor recorded by `doPut`, or `null`. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Answers straight from the content map rather than through `doDescribe`. |
| `doCopy` | `Future<TomStoredBlob> doCopy(String fromKey, String toKey)` | *(override)* A second map entry, with the bytes copied rather than aliased. The copy is defensive: nothing mutates a stored list in place, so a shared one has no observable consequence — what it buys is that the first code to mutate one finds two blobs rather than one, on the backend whose stated trade is fidelity over speed. |
| `doMove` | `Future<TomStoredBlob> doMove(String fromKey, String toKey)` | *(override)* The copy, then the source's two map entries removed. |
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
| `supportsPrefixDelete` | `bool` | *(override)* `true` — keys are paths, so a partition is a directory and one recursive delete reclaims it. The count is of *blobs*, not of the metadata sidecars beside them. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Streams to a sibling `<key>~part` and renames it into place, so a reader sees the previous blob or the complete new one. The close, the rename and the sidecar write are all inside the failure path, because each has filesystem faults of its own — a full disk surfaces at `close`, a rename fails on a cross-device root or an occupied target — and each of them fails *after* the partial exists. The rollback deletes whichever residue the failure left: the partial before the rename, the newly committed blob after it, then rethrows so that `put` reports it as `storage.blob.write_failed` with the original as `rootException`. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Streams the file with `openRead`; throws `storage.blob.not_found` when it does not exist. A mid-read filesystem fault becomes `storage.blob.read_failed` at `get`. |
| `doGetRange` | `Stream<List<int>> doGetRange(String key, TomBlobRange range)` | *(override)* `openRead(start, end)` — a real seek, so a request for the last megabyte of a gigabyte reads a megabyte. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* Size and mtime from `stat()`, media type and file name from the sidecar when it is present and parseable — so a directory populated by `scp` is still readable. A sidecar that cannot be *read* (as opposed to parsed) surfaces as `storage.blob.probe_failed`. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* A direct file-existence probe. `exists` translates whatever this throws, but here there is nothing to translate: `File.exists` answers from a `stat` and maps every failure of it — an unreadable parent directory included — to `false`. It therefore means "visible to this process" rather than "present in storage"; ask `describe` to tell an unreadable blob from an absent one. |
| `doCopy` | `Future<TomStoredBlob> doCopy(String fromKey, String toKey)` | *(override)* `File.copy` into a `~part` sibling and a rename, the staging protocol `doPut` uses and for the same reason: a copy interrupted half way must not leave a truncated blob under a key that already held a complete one. The metadata sidecar is copied before the rename, so the blob is never visible without the media type that says how to serve it, and the destination's own sidecar is removed when the source has none. |
| `doMove` | `Future<TomStoredBlob> doMove(String fromKey, String toKey)` | *(override)* A `rename`, sidecar first. Within one filesystem it moves no bytes and is atomic, which is what makes re-partitioning a terabyte of blobs a metadata operation. |
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
  DateTime Function()? clock,
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
  DateTime Function()? clock,
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
| `clock` | `DateTime Function()` | The source of a blob's `storedAt`, defaulting to `DateTime.now` (final). A seam rather than a call in place, for the reason `TomSqlLeaseLock` has one: what the store does with the reading — hand it to the data source as a `DateTime` so the bind boundary renders it through `sqlInstant` — is only observable against a known instant, and the defect it replaced was a local reading written as though it were UTC. |
| `supportsPrefixDelete` | `bool` | *(override)* `true` — the manifest is indexed by key, so a prefix is one `DELETE` there plus the chunks of each upload no row still names. The `LIKE` pattern escapes `_`, which is both a wildcard and an ordinary key character. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the two tables if they do not exist. Idempotent and called automatically by every operation; exposed so a start-up sequence can provision the schema before serving traffic. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Slices the incoming stream into `chunkSize` chunk rows under a fresh upload id, then replaces the manifest row — the commit point. A failure deletes the chunks it wrote and rethrows, so `put` reports `storage.blob.write_failed`; superseded chunks are removed afterwards and a failure to do so is logged, not raised. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Reads the manifest, then fetches and base64-decodes one chunk row per consumer demand; throws `storage.blob.not_found` for an unknown key and `storage.blob.missing_chunk` when the manifest and its chunks disagree. |
| `doGetRange` | `Stream<List<int>> doGetRange(String key, TomBlobRange range)` | *(override)* Divides the range's start by the manifest's recorded `chunk_size` to name the first chunk row, then fetches only the rows the range touches and trims the two edges. A manifest carrying no size falls back to the inherited read: the size is a constructor argument, so a store reconfigured between the write and the read would otherwise seek to the wrong row, and `byte_count` with `chunk_count` does not determine it. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* Builds the descriptor from the manifest row, or `null`. An empty `file_name` is treated as absent, so a `NOT NULL` variant of the table behaves the same. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Deletes the manifest row first — that is the point at which the blob is gone — then its chunks, but only when no manifest row still names the upload; returns whether a manifest was there. The guard is what makes `doCopy`'s sharing safe. |
| `doCopy` | `Future<TomStoredBlob> doCopy(String fromKey, String toKey)` | *(override)* A second manifest row against the **same** upload id: no chunk is read, written or counted, so a gigabyte copies in one statement. Safe because the chunk delete is guarded by whether any manifest row still names the upload, so the two keys have independent lifetimes despite sharing bytes. Whatever the destination held is released the same way. |
| `doMove` | `Future<TomStoredBlob> doMove(String fromKey, String toKey)` | *(override)* One `UPDATE` of `storage_key`, keeping the upload and its chunks. The destination is deleted first: the key is the primary key, so an `UPDATE` onto an occupied one is a constraint violation rather than the replacement every other write performs, and deleting it through `doDelete` is what stops its chunks becoming orphans. |
| `purgeOrphanedChunks` | `Future<int> purgeOrphanedChunks()` | Deletes chunk rows no manifest refers to, returning how many were removed. Housekeeping for the residue of a replace or delete whose chunk cleanup failed; belongs on a schedule rather than in the request path. |
| `keysOfTenant` | `Future<List<String>> keysOfTenant(String tenant)` | The keys of the blobs written for `tenant`, in key order. The manifest is a system table, kept in the system data source for every tenant; each row records the tenant in context when it was written (`''` outside a tenant), so a tenant's blobs can be listed, exported and erased. |
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
| `chunkSize` | `int` | The size every chunk but the last was written at (column `chunk_size`). Recorded rather than assumed because a ranged read divides a byte offset by it and the store's `chunkSize` is a constructor argument; it is not derivable from `byte_count` and `chunk_count` either — ten bytes in two chunks is 6+4 or 9+1 or 5+5. |
| `digest` | `String` | The SHA-256 of the content as 64 lowercase hex characters (column `digest`). |
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

### TomAwsCredentialsSource

Supplies the credentials an AWS request is signed with. Called for every
request, so a source can hand out refreshed temporary credentials — an instance
or task role's, cached by the source until shortly before they expire. Used by
`tom_core_secrets`' `TomAwsSecretsProvider` and `tom_core_message_bus_aws`'
`TomAwsMessageBus`; `TomS3BlobStore` takes a fixed `TomAwsCredentials` instead.

```dart
typedef TomAwsCredentialsSource = Future<TomAwsCredentials> Function();
```

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
| `canonicalQuery` | `static String canonicalQuery(Uri uri)` | The canonical query string: every parameter encoded and sorted, values included even when empty (`?uploads` signs as `uploads=`). A repeated name contributes all of its values, sorted among themselves (`?x=2&x=1` → `x=1&x=2`) — read from `queryParametersAll`, because `queryParameters` keeps only the last value of a repeated name and signing a subset of what is sent yields `SignatureDoesNotMatch`. Encoded before sorting, so the order is over the bytes the server re-derives. |
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
creates and owns one — a `TomResilientClient` (the kernel's) over a new
`http.Client`, so every request runs under the object store's timeout, retry,
circuit-breaker and bulkhead policies — and `close` disposes of it.

Every request the store rejects becomes one `storage.s3.request_failed` —
which a caller meets as the `rootException` of one of the four operation keys,
never as its own key, because it is not in `TomBlobStore.passThroughErrorKeys` —
whose
parameters are `key` — always the *caller's* key, never the request path, so a
handler that logs or renders it prints something the caller supplied and can
look up — `objectPath` for the full path with bucket and prefix, `operation` for
the store operation (`put`, `get`, `describe`, `delete`, `uploadPart`,
`createMultipartUpload`, `completeMultipartUpload`, `abortMultipartUpload`, and
not the HTTP verb, which cannot tell a multipart upload's four requests apart),
`status`, and the store's own `code` and `message` when it sent them. The path
is reported under its own name rather than as the key because these errors are
logged: an operator needs to know which bucket and prefix refused the request,
while a `keyPrefix` is typically the tenant and belongs nowhere a caller might
render it unawares.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `minimumPartSize` | `static const int` | S3's minimum size for any part but the last: 5 MiB. |
| `defaultPartSize` | `static const int` | The default bytes per multipart part: 8 MiB — above `minimumPartSize` with room to spare, and small enough that the upload buffer it bounds stays a reasonable per-upload allocation. Declared once here rather than repeated at each defaulting site, so a change lands everywhere. |
| `digestHeader` | `static const String` | The header the content digest is carried in, `x-amz-meta-digest`. User metadata rather than a protocol header, because S3 has none that means this: `x-amz-content-sha256` is the *signature's* payload hash — on a multipart upload it is a part's hash, never the object's — and `ETag` is an MD5 only for single-part objects and an opaque string otherwise. |
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
| `supportsPrefixDelete` | `bool` | *(override)* `true`, at a cost worth knowing: S3 has no prefix delete, so this is a paginated `ListObjectsV2` plus batched `DeleteObjects`. It is also **eventually consistent** — a `LIST` may not yet show an object written a moment ago — which is why retention runs against partitions nothing is still writing to. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Buffers up to `partSize`: a stream that ends inside the first buffer is one signed `PUT`, otherwise each full buffer becomes a part and the upload is completed at the end. Any failure issues an `AbortMultipartUpload` and rethrows, so `put` reports `storage.blob.write_failed` — or passes through the storage exception already thrown. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Streams the response body of a signed `GET`; `404` drains the body and throws `storage.blob.not_found`, which passes through to the caller, and any other error status throws `storage.s3.request_failed`, which `get` translates to `storage.blob.read_failed`. |
| `doGetRange` | `Stream<List<int>> doGetRange(String key, TomBlobRange range)` | *(override)* The same signed `GET` carrying `Range: bytes=a-b`, so the bytes before the range never cross the wire. The header is inclusive at both ends where `TomBlobRange` is exclusive at the top, and an open-ended range goes out as `bytes=500-` — the store does not know the object's size, and inventing one would be a second place that size is decided. S3 answers `206`, which the success check already accepts. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* A signed `HEAD`, mapping `content-type`, `content-length`, `last-modified` and `x-amz-meta-filename` into the descriptor; `null` on `404`. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Probes with `doExists` first, because S3 answers `204` to a delete whether or not the object was there, then sends the signed `DELETE`. The two calls make the answer a recent observation rather than a fact — see `TomBlobStore.delete`. There is nothing to close the window with: `DeleteObject` takes no `If-Match`, and a versioned bucket's delete marker answers which version went rather than whether anything was there. |
| `doCopy` | `Future<TomStoredBlob> doCopy(String fromKey, String toKey)` | *(override)* `CopyObject` — a signed `PUT` at the destination naming the source in `x-amz-copy-source`, with no body, so the object never leaves the store. The header value is `/<bucket>/<prefixed key>` with each segment URI-encoded, since it carries a path and a character legal in a key but reserved in a path would otherwise name a different object; the bucket is always in it whatever `pathStyle` puts in the URL, because the header is addressed against the service rather than the request's host. The returned descriptor is the source's under the new key: S3's copy response carries no size, so re-describing would be a second round trip for what is already known. `doMove` is not overridden — S3 has no rename, so the inherited copy-then-delete is the right one. |
| `close` | `Future<void> close()` | *(override)* Closes the HTTP client, but only the one this store created. |
| `toString` | `String toString()` | *(override)* Renders `TomS3BlobStore(<bucket> at <endpoint>)`. |

### TomBlobStoreBackend

One blob-store backend: the settings a configured store of its `type` accepts,
declared as fields, and the store they build. The registry creates a fresh
instance per configured store, rejects any settings key the instance declares no
field for, binds the rest onto its fields through reflection, and calls `build`.
A subclass therefore carries `@tomReflector` and declares each setting as a
plain, non-`final`, public field whose initialiser is its default; anything that
is not a setting — an HTTP client, a credential provider — is a constructor
argument, captured by the factory it is registered with.

#### Constructors

```dart
TomBlobStoreBackend()
```

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `missingSetting` | `static TomStorageException missingSetting(String store, String setting)` | The `storage.registry.missing_setting` error a `build` raises for a required setting the configuration of `store` left unset. |
| `parseInts` | `static Map<String, dynamic> parseInts(Map<String, dynamic> settings, Iterable<String> keys)` | `settings` with the value under each of `keys` parsed to an `int` when it arrived as a string holding one; a string that does not parse is left for binding to refuse. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `build` | `FutureOr<TomBlobStore> build(String name)` | *(abstract)* Builds the store configured as `name` from the bound fields, raising `missingSetting` for a required one left unset. |
| `normalize` | `Map<String, dynamic> normalize(Map<String, dynamic> settings)` | Returns `settings` with each value in the shape its field takes, before binding. The default changes nothing; a backend with an `int` setting overrides it to accept the string an environment substitution produces. |

### The four built-in backends

Registered under the types a configuration names. Each field is a setting; an
empty `String` default marks a required one, which `build` refuses as
`storage.registry.missing_setting`.

| Class | `type` | Settings (fields) |
| ----- | ------ | ----------------- |
| `TomMemoryBlobStoreBackend` | `memory` | none |
| `TomDirectoryBlobStoreBackend` | `directory` | `root` (required) |
| `TomDatabaseBlobStoreBackend` | `database` | `datasource` (required), `manifestTable`, `chunkTable`, `chunkSize`, `createSchema` |
| `TomS3BlobStoreBackend` | `s3` | `endpoint`, `bucket`, `region`, `accessKeyId`, `secretAccessKey` (all required), `sessionToken`, `pathStyle`, `partSize`, `keyPrefix` |

`chunkSize` and `partSize` also accept a string holding a number, through
`normalize`.

### TomBlobStoreBackendFactory

Creates a fresh, unconfigured backend of one type. Called once per configured
store, because the store's settings are bound onto the instance it returns; a
constructor tear-off for a backend with no arguments, a closure for one that
captures something.

```dart
typedef TomBlobStoreBackendFactory = TomBlobStoreBackend Function();
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

`open` builds the store with the backend `settings['type']` names. A store
already in hand gets its entry through `register` instead.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `providedType` | `static const String` | The `type` recorded for a store handed over as an instance (`'provided'`). Deliberately not a registered backend: it names how the store arrived rather than a way to build one, so a configuration naming it fails like any other unknown type and `backendTypes` does not list it. |
| `registryKeys` | `static const Set<String>` | The settings keys the registry reads itself — `type` and `default` — and so removes before the rest reach the backend. |
| `stores` | `static final Map<String, TomBlobStoreInfo>` | All registered stores, keyed by name. |
| `defaultStoreName` | `static String?` | The name `defaultStore` resolves to, or `null` when none is nominated. |
| `backendTypes` | `static Iterable<String>` | *(getter)* The backend type names currently registered. |
| `defaultStore` | `static TomBlobStore` | *(getter)* The store to use when nothing names one; throws `storage.registry.no_default_store` when no default was nominated. |
| `hasDefaultStore` | `static bool` | *(getter)* Whether a default store is available — a name is nominated and a store is registered under it. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `registerBackend` | `static void registerBackend(String type, TomBlobStoreBackendFactory factory)` | Registers `factory` as the creator of backend `type`, replacing any previous registration of the same name. It must return a fresh backend each call, of a class in the application's generated reflection. Call before `initializeBlobStores`: an unknown type is a start-up failure, not a lazy one. |
| `unregisterBackend` | `static bool unregisterBackend(String type)` | Removes backend `type`, answering whether one was registered. A configuration naming it then fails as `storage.registry.unknown_backend`. |
| `getBlobStoreInfo` | `static TomBlobStoreInfo? getBlobStoreInfo(String name)` | The registered info for `name`, or `null` if none. |
| `storeNamed` | `static TomBlobStore storeNamed(String name)` | The store registered as `name`; throws `storage.registry.unknown_store` when there is none, so a typo or an unconfigured deployment is reported rather than silently written somewhere else. |
| `initializeBlobStores` | `static Future<int> initializeBlobStores(Map<String, dynamic> configuration)` | Builds and registers a store for every map-valued entry of `configuration`, returning the number registered. Keys are read defensively because YAML arrives as a `Map<dynamic, dynamic>`. One entry may carry `default: true`; when the configuration names exactly one store it becomes the default without saying so — counted over the entries this call registered, not over every store the process holds, so an application that registered one in code first still gets it. Only ever fills a default that is still unset, so an `asDefault` nominated in code survives; a `default: true` in the configuration displaces it. |
| `register` | `static TomBlobStoreInfo register(String name, TomBlobStore store, {bool asDefault = false})` | Registers a ready-made `store` under `name` — the seam a test, or an application that builds its store in code, uses instead of configuration. The entry records `providedType` and keeps `store`, so `open` on it, after a `closeAll` say, hands back the store it was given. |
| `closeAll` | `static Future<void> closeAll()` | Closes every registered store, empties the registry and clears the default name. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `name` | `String` | The registry key / logical name of this store (final). |
| `settings` | `Map<String, dynamic>` | The raw configuration for this store (final). |
| `isOpen` | `bool` | *(getter)* Whether `open` has built this entry's store — the question `store` answers by throwing, asked without throwing. |
| `store` | `TomBlobStore` | *(getter)* The live store. Throws `storage.registry.store_not_opened`, naming the store and its configured type, when `open` has not run or did not complete — an entry is constructed unopened, and an `open` that throws leaves one behind. |
| `type` | `String` | *(getter)* The backend type, from `settings['type']` — a registered backend for a configured store, `providedType` for one handed over as an instance. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `open` | `Future<void> open()` | Builds this entry's store and registers it. An entry made by `register` hands back its store. A configured entry creates the backend its `type` names (`storage.registry.unknown_backend` when none is registered, `storage.registry.backend_not_reflected` when its class is not in the application's reflection), removes `registryKeys`, refuses every remaining key the backend declares no field for (`storage.registry.unknown_setting`, naming the store and every offending key), binds the rest (`storage.registry.invalid_setting` for a value its field cannot take), and builds the store (`storage.registry.missing_setting` for a required setting left unset). |
| `toString` | `String toString()` | *(override)* Renders `TomBlobStoreInfo <name> <type> <store>`, with `<unopened>` in the store's place while the entry has none. Three segments either way: an unopened entry is most often seen in a debugger or inside the error report about the `open` that failed, so it renders rather than throws. |

### TomDeduplicatingBlobStore

A blob store that keeps one copy of each distinct content, records whose every
key is, and holds each owner to a quota. It sits in front of another store —
the *content store*, any of the four backends — and a `TomBlobLedger`. A write
streams into a staging key while its SHA-256 is computed, then becomes the
content for that digest or is discarded when the content is already held; every
logical key naming the same bytes shares one stored copy, and a copy is a
ledger write that moves no bytes. Deleting a key removes its ledger entry;
content no entry names is deleted by `reclaim`, never at the moment its last key
goes, because that delete would race a concurrent write of the same bytes in
another process.

- **Extends:** `TomBlobStore`

#### Constructors

```dart
TomDeduplicatingBlobStore({
  required TomBlobStore content,
  required TomBlobLedger ledger,
  TomBlobQuota? quota,
  String Function()? ownerOf,
  String contentPrefix = defaultContentPrefix,
  String stagingPrefix = defaultStagingPrefix,
  Duration reclaimGrace = const Duration(hours: 1),
  DateTime Function()? clock,
})
```

`contentPrefix` and `stagingPrefix` are validated as keys and must not contain
each other — staging inside the content area would make an in-flight write look
like content — and `reclaimGrace` must not be negative; either fault is an
`ArgumentError`. `ownerOf` defaults to `principalOwner`, `clock` to
`DateTime.now`.

#### Static Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `defaultContentPrefix` | `static const String` | The prefix content is stored under in the content store by default, `tom-content`. |
| `defaultStagingPrefix` | `static const String` | The prefix in-flight writes are staged under by default, `tom-staging`. |

#### Static Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `principalOwner` | `static String principalOwner()` | The owner the current zone's principal is: its qualified id, or `''` when no principal is set — the default `ownerOf`. |
| `runAs` | `static Future<T> runAs<T>(String owner, Future<T> Function() body)` | Runs `body` with every write and copy it makes charged to `owner` — for work done on someone's behalf outside a request, and for a job that owns its own files. |

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `content` | `TomBlobStore` | Where the bytes are stored (final). |
| `ledger` | `TomBlobLedger` | The record of keys, owners and contents (final). |
| `quota` | `TomBlobQuota?` | How much one owner may hold, or `null` for no limit (final). |
| `ownerOf` | `String Function()` | Who a write counts against when no `runAs` is in effect (final). |
| `contentPrefix` | `String` | The key prefix content takes in `content` (final). Content keys are `<contentPrefix>/<first two hex digits>/<digest>-<12 random hex>`, so content reclaimed and stored again never reuses a key a late delete of the old bytes could still reach. |
| `stagingPrefix` | `String` | The key prefix in-flight writes take in `content` (final). A staged write is moved or deleted before it returns; a process that dies mid-write leaves its staged bytes, which nothing records and so nothing reclaims — `deletePrefix` of this prefix on the content store, while no write is in flight, removes them. |
| `reclaimGrace` | `Duration` | How long content no key names is kept before `reclaim` deletes it, counted from its last claim by a write or a copy (final). Longer than the longest write, since a write claims its content before it records its key. |
| `supportsPrefixDelete` | `bool` | *(override)* `true` over any content store — a prefix delete removes ledger entries, matched by segment. |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `currentOwner` | `String currentOwner()` | Who the write being made now counts against: the owner `runAs` named for the current zone, otherwise `ownerOf()`. |
| `doPut` | `Future<TomStoredBlob> doPut({required String key, required Stream<List<int>> bytes, String mediaType = TomStoredBlob.defaultMediaType, String? fileName})` | *(override)* Checks the owner's count and bytes held against the quota, streams the bytes into a fresh staging key while hashing them, checks the bytes again with the written size, claims the content for the digest, moves the staged bytes to the content key — or deletes them when the content is already stored — and records the entry. When the ledger names content whose bytes are missing, the staged bytes are moved in, so the next write repairs the gap. A failure deletes the staged bytes and rethrows. |
| `doGet` | `Stream<List<int>> doGet(String key)` | *(override)* Looks the key up in the ledger and reads its content key from the content store; `storage.blob.not_found` for an unknown key. |
| `doGetRange` | `Stream<List<int>> doGetRange(String key, TomBlobRange range)` | *(override)* The same, passing the range to the content store, so its seek serves it. |
| `doDescribe` | `Future<TomStoredBlob?> doDescribe(String key)` | *(override)* The ledger entry as a descriptor, digest included, or `null`. |
| `doExists` | `Future<bool> doExists(String key)` | *(override)* Whether the ledger holds an entry for the key. |
| `doDelete` | `Future<bool> doDelete(String key)` | *(override)* Removes the ledger entry and answers whether there was one; the content stays until `reclaim`. |
| `doDeletePrefix` | `Future<int> doDeletePrefix(String prefix)` | *(override)* Removes the ledger entries under `prefix`, by segment, and answers how many went. |
| `doCopy` | `Future<TomStoredBlob> doCopy(String fromKey, String toKey)` | *(override)* A ledger entry at `toKey` naming the source's content, charged to the current owner and checked against the quota with the source's size; the content is claimed first, so a reclaim cannot take it in between. No bytes move. |
| `doMove` | `Future<TomStoredBlob> doMove(String fromKey, String toKey)` | *(override)* Records the entry at `toKey` with the source's owner, then removes `fromKey`. No bytes move. |
| `reclaim` | `Future<int> reclaim({DateTime? now, int batchSize = 500})` | Deletes content no key has named, and nothing has claimed, for `reclaimGrace` before `now` (default: the clock), in batches of `batchSize`; answers how many contents went. A content's record goes before its bytes, and only while still unnamed and unclaimed, so a concurrent write either keeps it or gets new content under a new key. A failure deleting the bytes after the record went leaves them unreachable rather than referenced, and is reported, not retried. A `batchSize` below one is an `ArgumentError`. |
| `reclaimJobDefinition` | `TomJobDefinition reclaimJobDefinition({String name = 'tom.storage.reclaim', TomSchedule? schedule})` | A job running `reclaim` on `schedule` (default: hourly), missed windows run once, for a `TomScheduler` to run in its own isolate (`TomInlineJobDispatcher`), since its body holds this store. |
| `close` | `Future<void> close()` | *(override)* Closes the content store. |

### TomBlobQuota

How much one owner may hold in a `TomDeduplicatingBlobStore`: at most `maxCount`
blobs and at most `maxBytes` in total; `null` leaves that dimension unbounded.
Checked on every write and copy made for an owner. The count and the bytes
already held are checked before anything is written, so a full owner costs no
upload; a write that takes the owner past `maxBytes` is undone before it is
recorded. The check reads the ledger and then writes it, so two writes racing
for the last of an owner's space can both pass: the quota bounds an owner, it
is not a reservation.

#### Constructors

```dart
const TomBlobQuota({int? maxCount, int? maxBytes})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `maxCount` | `int?` | The most blobs one owner may hold (final). |
| `maxBytes` | `int?` | The most bytes one owner's blobs may total (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `check` | `void check(String owner, TomBlobUsage usage, {int addedBytes = 0, bool countingNew = true})` | Throws unless `owner`, holding `usage`, may hold one more blob: `storage.quota.count_exceeded` when the count is at `maxCount` and `countingNew` is set, `storage.quota.bytes_exceeded` when the bytes held plus `addedBytes` exceed `maxBytes` — or, before the write (`addedBytes` `0`), already reach it. Both carry the owner, the count or bytes and the limit. A caller replacing a blob the owner holds passes `countingNew: false` and takes the replaced blob's bytes out of `usage` first. |

### TomBlobUsage

How much an owner holds: `count` blobs of `bytes` in total. Logical bytes — an
owner is charged for every blob it holds, whether or not another key shares the
content, so what one owner may store never depends on what somebody else
uploaded.

#### Constructors

```dart
const TomBlobUsage({required int count, required int bytes})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `count` | `int` | How many blobs (final). |
| `bytes` | `int` | Their total size (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `TomBlobUsage(<count> blobs, <bytes> bytes)`. |

### TomBlobLedger

The record a `TomDeduplicatingBlobStore` keeps of its keys and contents: one
`TomBlobLedgerEntry` per logical key and one `TomBlobContent` per distinct
content. Many entries may name one content; that is the deduplication.

- **Extends:** none (abstract)

#### Constructors

```dart
const TomBlobLedger()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `find` | `Future<TomBlobLedgerEntry?> find(String key)` | *(abstract)* The entry under `key`, or `null`. |
| `record` | `Future<void> record(TomBlobLedgerEntry entry)` | *(abstract)* Records `entry`, replacing any entry under its key. |
| `remove` | `Future<TomBlobLedgerEntry?> remove(String key)` | *(abstract)* Removes the entry under `key` and answers it, or `null` when there was none. The content it named stays until a reclaim. |
| `removePrefix` | `Future<int> removePrefix(String prefix)` | *(abstract)* Removes the entry `prefix` names and every entry below it, matched by segment as `TomBlobStore.deletePrefix` matches; answers how many went. |
| `usageOf` | `Future<TomBlobUsage> usageOf(String owner)` | *(abstract)* What `owner` holds. |
| `storedBefore` | `Future<List<TomBlobLedgerEntry>> storedBefore(DateTime before, {String after = '', int limit = 500})` | *(abstract)* Up to `limit` entries written before `before` whose key sorts after `after`, in key order — the page an orphan sweep walks. |
| `referencesTo` | `Future<int> referencesTo(String digest)` | *(abstract)* How many entries name the content with `digest`. |
| `claimContent` | `Future<TomBlobContent?> claimContent(String digest, {required int byteCount, required String contentKey, required DateTime now, bool create = true})` | *(abstract)* The content with `digest`, claimed at `now`; created under `contentKey` when there is none and `create` is set, otherwise `null` when there is none. A claim keeps content from being reclaimed while a write that will name it is in flight; content reclaimed and claimed again is created anew under the new `contentKey`, so old and new bytes never share a key. |
| `reclaimable` | `Future<List<TomBlobContent>> reclaimable(DateTime claimedBefore, {int limit = 500})` | *(abstract)* Up to `limit` contents no entry names and nothing claimed since `claimedBefore`, oldest claim first. |
| `dropContent` | `Future<bool> dropContent(TomBlobContent content, DateTime claimedBefore)` | *(abstract)* Removes `content`'s record if it is still unnamed and unclaimed since `claimedBefore`; answers whether it did, and so whether its bytes may go. |

### TomBlobLedgerEntry

One logical key of a `TomDeduplicatingBlobStore`.

#### Constructors

```dart
TomBlobLedgerEntry({
  required String key,
  required String owner,
  required String digest,
  required String contentKey,
  required int byteCount,
  required String mediaType,
  required DateTime storedAt,
  String? fileName,
})
```

`storedAt` is normalised to UTC.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The logical key (final). |
| `owner` | `String` | Who the blob counts against — a principal's qualified id, a tenant, a job; `''` for a blob of no one, which no quota counts (final). |
| `digest` | `String` | The SHA-256 of the content, as lowercase hex (final). |
| `contentKey` | `String` | The key the content's bytes are stored under in the content store, kept here so a read is one lookup (final). |
| `byteCount` | `int` | The content's size (final). |
| `mediaType` | `String` | The media type the blob was stored with (final). |
| `fileName` | `String?` | The file name the blob was stored with, if any (final). |
| `storedAt` | `DateTime` | When the key was written, in UTC (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toStoredBlob` | `TomStoredBlob toStoredBlob()` | This entry as the descriptor `describe` answers, digest included. |
| `toString` | `String toString()` | *(override)* Renders `TomBlobLedgerEntry(<key>, <owner>, <byteCount> bytes)`. |

### TomBlobContent

One distinct content held by a `TomDeduplicatingBlobStore`.

#### Constructors

```dart
TomBlobContent({
  required String digest,
  required String contentKey,
  required int byteCount,
  required DateTime claimedAt,
})
```

`claimedAt` is normalised to UTC.

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `digest` | `String` | The SHA-256 of the content, as lowercase hex (final). |
| `contentKey` | `String` | The key the bytes are stored under in the content store (final). |
| `byteCount` | `int` | The content's size (final). |
| `claimedAt` | `DateTime` | When a write or copy last claimed it, in UTC (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `toString` | `String toString()` | *(override)* Renders `TomBlobContent(<digest> at <contentKey>)`. |

### TomMemoryBlobLedger

A `TomBlobLedger` in memory: right for tests and a single process whose content
store is in memory too, wrong for anything that outlives the process.

- **Extends:** `TomBlobLedger`

#### Constructors

```dart
TomMemoryBlobLedger()
```

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `find` | `Future<TomBlobLedgerEntry?> find(String key)` | *(override)* A map lookup. |
| `record` | `Future<void> record(TomBlobLedgerEntry entry)` | *(override)* Stores the entry under its key. |
| `remove` | `Future<TomBlobLedgerEntry?> remove(String key)` | *(override)* Removes and answers the entry. |
| `removePrefix` | `Future<int> removePrefix(String prefix)` | *(override)* Removes every entry `tomBlobKeyUnder` puts under `prefix`. |
| `usageOf` | `Future<TomBlobUsage> usageOf(String owner)` | *(override)* Counts and sums the owner's entries. |
| `storedBefore` | `Future<List<TomBlobLedgerEntry>> storedBefore(DateTime before, {String after = '', int limit = 500})` | *(override)* Filters, sorts by key and takes `limit`. |
| `referencesTo` | `Future<int> referencesTo(String digest)` | *(override)* Counts the entries naming `digest`. |
| `claimContent` | `Future<TomBlobContent?> claimContent(String digest, {required int byteCount, required String contentKey, required DateTime now, bool create = true})` | *(override)* Re-stamps a held content with `now`, keeping its content key and size, or creates it when `create` is set. |
| `reclaimable` | `Future<List<TomBlobContent>> reclaimable(DateTime claimedBefore, {int limit = 500})` | *(override)* The unnamed contents claimed before the cutoff, oldest claim first. |
| `dropContent` | `Future<bool> dropContent(TomBlobContent content, DateTime claimedBefore)` | *(override)* Removes the content when it still has the same content key, is still unclaimed since the cutoff and no entry names it. |

### TomSqlBlobLedger

A `TomBlobLedger` whose entries and contents are rows of two framework-owned
tables in a `TomDataSource`, `tom_blob_ledger` and `tom_blob_content` by
default. Every check that guards content against a concurrent writer is one
statement, so it holds across processes: `claimContent` stamps the claim before
it reads, and `dropContent` deletes only while the content is still unnamed and
unclaimed.

- **Extends:** `TomBlobLedger`

#### Constructors

```dart
TomSqlBlobLedger(
  TomDataSource datasource, {
  String ledgerTable = defaultBlobLedgerTable,
  String contentTable = defaultBlobContentTable,
  bool createSchema = true,
})
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `datasource` | `TomDataSource` | The data source the tables live in (final). |
| `ledgerTable` | `String` | The key table (final). |
| `contentTable` | `String` | The content table (final). |
| `createSchema` | `bool` | Whether to create the tables on first use; `false` when the migration module owns them (final). |

#### Methods

| Method | Signature | Description |
| ------ | --------- | ----------- |
| `ensureSchema` | `Future<void> ensureSchema()` | Creates the tables if they do not exist; idempotent, and called by every operation. |
| `find` | `Future<TomBlobLedgerEntry?> find(String key)` | *(override)* One `SELECT` by `blob_key`. |
| `record` | `Future<void> record(TomBlobLedgerEntry entry)` | *(override)* A replacing write of the entry's row. |
| `remove` | `Future<TomBlobLedgerEntry?> remove(String key)` | *(override)* Reads the entry, deletes its row, and answers it when the delete removed a row. |
| `removePrefix` | `Future<int> removePrefix(String prefix)` | *(override)* One `DELETE` of the key and every key `LIKE` the escaped prefix plus `/%` (`ESCAPE '!'`, because `_` is both a wildcard and a key character). |
| `usageOf` | `Future<TomBlobUsage> usageOf(String owner)` | *(override)* `COUNT(*)` and `SUM(byte_count)` over the owner's rows. |
| `storedBefore` | `Future<List<TomBlobLedgerEntry>> storedBefore(DateTime before, {String after = '', int limit = 500})` | *(override)* Rows with `stored_at` before the cutoff and `blob_key` after `after`, ordered by key, limited. |
| `referencesTo` | `Future<int> referencesTo(String digest)` | *(override)* `COUNT(*)` of rows with that `content_digest`. |
| `claimContent` | `Future<TomBlobContent?> claimContent(String digest, {required int byteCount, required String contentKey, required DateTime now, bool create = true})` | *(override)* Stamps `claimed_at` first, then reads the row; when there is none and `create` is set, inserts it ignoring a conflict and reads the row a concurrent claim may have written instead. |
| `reclaimable` | `Future<List<TomBlobContent>> reclaimable(DateTime claimedBefore, {int limit = 500})` | *(override)* Content rows claimed before the cutoff with no ledger row naming them, oldest claim first. |
| `dropContent` | `Future<bool> dropContent(TomBlobContent content, DateTime claimedBefore)` | *(override)* One `DELETE` of the content row, guarded by its content key, its claim time and the absence of a ledger row naming it. |
| `deleteAll` | `Future<void> deleteAll()` | Empties both tables — for provisioning and tests. |

### TomBlobLedgerEntryRow

One row of the ledger's key table, as the data source's row mapper materialises
it. Reflected and `@TomDbTable`-annotated for the same reason as
`TomBlobManifestRow`; the table values are placeholders.

#### Constructors

```dart
TomBlobLedgerEntryRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `key` | `String` | The logical key (column `blob_key`). |
| `owner` | `String` | Who the blob counts against (column `owner`). |
| `digest` | `String` | The content's SHA-256 (column `content_digest`). |
| `contentKey` | `String` | Where the content's bytes are stored (column `content_key`). |
| `byteCount` | `int` | The content's size (column `byte_count`). |
| `mediaType` | `String` | The blob's media type (column `media_type`). |
| `fileName` | `String?` | The blob's file name (column `file_name`). |
| `storedAt` | `String` | When the key was written, as the stored text (column `stored_at`). |

### TomBlobContentRow

One row of the ledger's content table, as the row mapper materialises it.

#### Constructors

```dart
TomBlobContentRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `digest` | `String` | The content's SHA-256 (column `content_digest`). |
| `contentKey` | `String` | Where the content's bytes are stored (column `content_key`). |
| `byteCount` | `int` | The content's size (column `byte_count`). |
| `claimedAt` | `String` | When it was last claimed, as the stored text (column `claimed_at`). |

### TomBlobUsageRow

The aggregate row `TomSqlBlobLedger.usageOf` reads.

#### Constructors

```dart
TomBlobUsageRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `blobCount` | `int` | How many blobs (column `blob_count`). |
| `blobBytes` | `int` | Their total size (column `blob_bytes`). |

### TomBlobReferenceCountRow

The aggregate row `TomSqlBlobLedger.referencesTo` reads.

#### Constructors

```dart
TomBlobReferenceCountRow()
```

#### Properties

| Property | Type | Description |
| -------- | ---- | ----------- |
| `referenceCount` | `int` | How many entries name the content (column `reference_count`). |

## Global Functions and Constants

### Constants

| Constant | Type | Description |
| -------- | ---- | ----------- |
| `defaultBlobManifestTable` | `String` | The default name of the blob manifest table, `tom_blob`. |
| `defaultBlobChunkTable` | `String` | The default name of the blob chunk table, `tom_blob_chunk`. |
| `defaultBlobLedgerTable` | `String` | The default name of the deduplicating store's key table, `tom_blob_ledger`. |
| `defaultBlobContentTable` | `String` | The default name of the deduplicating store's content table, `tom_blob_content`. |

### Functions

| Function | Signature | Description |
| -------- | --------- | ----------- |
| `blobManifestTable` | `TomFrameworkTable blobManifestTable(String table)` | The one declaration of the one-row-per-blob manifest table: `storage_key` as the primary key, sized from `TomBlobStore.maxKeyLength` so it cannot silently truncate a key the validator accepted; `upload_id` naming the committed upload; `media_type`, the nullable `file_name`, `byte_count`, `chunk_count`, and `stored_at` as `DATETIME(6)` — the width the framework's instant rendering writes, since a narrower column would silently round the microseconds and move the stored moment. |
| `blobChunkTable` | `TomFrameworkTable blobChunkTable(String table)` | The one declaration of the many-rows-per-blob content table, keyed on `(upload_id, chunk_index)` so the chunks of an in-flight write are addressable before anything commits to them. `chunk_data` is `LONGTEXT` holding base64, because the driver decodes every column value into a Dart `String`. |
| `blobManifestTableDdl` | `String blobManifestTableDdl(String table)` | The `CREATE TABLE` statement for the manifest table, derived from `blobManifestTable`. What a deployment applies by hand when its credential may not run DDL: for the default name that text is the shipped `[1]-create_tom_blob.sql`, and for a store constructed with `manifestTable:` there is no shipped file, so this is the only source. |
| `blobChunkTableDdl` | `String blobChunkTableDdl(String table)` | The `CREATE TABLE` statement for the chunk table, derived from `blobChunkTable` — the `[2]-create_tom_blob_chunk.sql` counterpart of `blobManifestTableDdl`, and the same answer for a renamed `chunkTable:`. |
| `blobLedgerTable` | `TomFrameworkTable blobLedgerTable(String table)` | The one declaration of the SQL ledger's key table: `blob_key` as the primary key, sized from `TomBlobStore.maxKeyLength`; `owner` (`VARCHAR(191) NOT NULL DEFAULT ''`), `content_digest` (`CHAR(64)`), `content_key`, `byte_count`, `media_type`, the nullable `file_name`, and `stored_at` as `DATETIME(6)`; indexed on `(owner, stored_at)` for a quota's sum, on `content_digest` for the reclaim's "does anything still name this content", and on `stored_at`. Listed by `frameworkOwnedTables` under `blobLedger`. |
| `blobContentTable` | `TomFrameworkTable blobContentTable(String table)` | The one declaration of the SQL ledger's content table: `content_digest` as the primary key, `content_key`, `byte_count` and `claimed_at` (`DATETIME(6)`), indexed on `claimed_at`, which the reclaim reads oldest first. Listed by `frameworkOwnedTables` under `blobContent`. |
| `blobLedgerTableDdl` | `String blobLedgerTableDdl(String table)` | The `CREATE TABLE` statement for the key table, derived from `blobLedgerTable`; for the default name that text is the shipped `[3]-create_tom_blob_ledger.sql`. |
| `blobContentTableDdl` | `String blobContentTableDdl(String table)` | The `CREATE TABLE` statement for the content table, derived from `blobContentTable`; for the default name that text is the shipped `[4]-create_tom_blob_content.sql`. |
| `tomBlobKeyUnder` | `bool tomBlobKeyUnder(String key, String prefix)` | Whether `key` is `prefix` or lies below it, segment by segment — so `2026/07` covers `2026/07/a` and never `2026/070`. The match every ledger's `removePrefix` and the orphan sweep's prefix filter use. |
