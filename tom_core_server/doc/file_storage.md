# File Storage Module

Files that are too large to live in a row: a streaming put/get contract, four
backends behind it, configuration that selects one, and a persistence-layer
column kind that lets an entity own a file without carrying its bytes.

The module has **two halves that are usable independently**. The blob store is
storage by key — an export, a generated document, a cached artefact. The
file-reference column is the persistence integration: a `@TomFileReference`
column holds a storage key, and the repository resolves upload on write,
download on read, and deletion on cascade. An application can use the first
without the second; the second is built entirely on the first.

## Table of Contents

- [Overview](#overview)
- [The Shape of the Design](#the-shape-of-the-design)
- [Streaming Is the Requirement](#streaming-is-the-requirement)
- [Keys Are a Grammar, Not a String](#keys-are-a-grammar-not-a-string)
- [The Backends](#the-backends)
  - [Memory](#memory)
  - [Directory](#directory)
  - [Database](#database)
  - [S3](#s3)
- [Configuration Selects the Backend](#configuration-selects-the-backend)
- [File-Reference Columns](#file-reference-columns)
- [Where the Key Comes From](#where-the-key-comes-from)
- [Authorization Is the Column's, Not a Second Copy](#authorization-is-the-columns-not-a-second-copy)
- [What Happens to the Bytes When the Row Changes](#what-happens-to-the-bytes-when-the-row-changes)
- [Serving a File Over HTTP](#serving-a-file-over-http)
  - [Slots Are Derived, Not Declared](#slots-are-derived-not-declared)
  - [Exposure Is Default-Closed](#exposure-is-default-closed)
  - [The Wire Contract](#the-wire-contract)
  - [Serving a File by Hand](#serving-a-file-by-hand)
  - [A File That Arrives as Part of a Form](#a-file-that-arrives-as-part-of-a-form)
- [Exports Ride the Same API](#exports-ride-the-same-api)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomBlobStore` | abstract class | The contract: `put` / `get` / `describe` / `delete` by key |
| `TomStoredBlob` | class | What was stored — key, media type, size, time, name, location |
| `TomStorageException` | class | The module's base error |
| `TomMemoryBlobStore` | class | In-memory; tests and development |
| `TomDirectoryBlobStore` | class | A directory on disk, with a metadata sidecar |
| `TomDatabaseBlobStore` | class | Chunk rows in an existing data source |
| `TomS3BlobStore` | class | Any S3-compatible object store, single-PUT or multipart |
| `TomAwsV4Signer` / `TomAwsCredentials` | class | AWS SigV4 request signing |
| `TomBlobStoreInfo` | class | The configured stores, by name, with a default |
| `TomBlobStoreFactory` | typedef | A backend: settings in, a store out |
| `TomFileReference` | annotation | Marks a column as holding a storage key |
| `TomFileReferenceKeys` | class | Key generation and store resolution for that annotation |
| `TomSqlDatasourceRepository.saveFile` / `.openFile` / `.describeFile` / `.clearFile` | methods | The entity-level file API |
| `TomFileRepository` | abstract class | The four-method file contract, independent of SQL |
| `TomFileSlots` / `TomFileSlot` | class | Reflection-derived `<table>/<column>` slot registry |
| `TomFileEndpoint` | class | The HTTP handler: POST / GET / HEAD / DELETE over a slot |
| `TomFileService` / `TomFileServer` | service / component | Mounts the handler at `/files/{entity}/{id}/{column}` |
| `TomFileSlotException` | class | Slot registration and resolution errors |
| `TomBlobExportStore` | class | The export module's store, over any blob backend |

## The Shape of the Design

Three things, each replaceable without touching the other two:

1. **A contract** — `TomBlobStore`. Four methods over a key and a byte stream.
2. **A backend** — one of four, or one an application writes. Selected from
   configuration, never named in the code that stores a file.
3. **A reference** — a `@TomFileReference` column. The entity owns the file; the
   framework owns the moving of bytes.

The seam between all three is `Stream<List<int>>`, and that is the entire reason
a 2 GB upload costs a chunk of memory rather than 2 GB of it.

## Streaming Is the Requirement

Every method that moves content moves a stream:

```dart
Future<TomStoredBlob> put({
  required String key,
  required Stream<List<int>> bytes,
  String mediaType = TomStoredBlob.defaultMediaType,
  String? fileName,
});

Stream<List<int>> get(String key);
```

`getBytes` and `putBytes` exist as conveniences for the cases that genuinely are
small — a thumbnail, a signature — and they are *named* for what they do, so a
call site that buffers a file says so.

This is not a preference. A server that buffers uploads has a heap requirement
equal to the largest file times the number of concurrent uploads, which is an
availability bug waiting for a busy afternoon. Every backend here therefore
streams both directions: the directory store reads and writes through file
streams, the database store fetches chunk row *n* only once the consumer has
taken row *n-1*, and the S3 store switches to multipart above a threshold so a
large upload is never assembled in memory either.

## Keys Are a Grammar, Not a String

A key is a name in somebody else's namespace — a path under a directory, an
object name in a bucket, a value in a `VARCHAR`. It is validated **once**, by
one rule, before it reaches any of them:

```dart
static final RegExp _keyPattern = RegExp(r'^[A-Za-z0-9._/-]+$');
static const int maxKeyLength = 512;
```

and separately rejected for `..`, a leading or doubled `/`, and a trailing `/`.
The rule is deliberately narrower than any single backend requires, because the
alternative is a per-backend escaping rule and a key that is safe in one store
and a traversal in the next. `TomBlobStore.validateKey` is called at the top of
every `put`, so an invalid key never reaches the filesystem, the network or SQL.

## The Backends

### Memory

`TomMemoryBlobStore` holds everything in a map. It buffers whole blobs by
definition, which is the one place in this module where that is acceptable, and
the reason it is not a default. It is what tests use, and what a development
server uses when it should not leave files behind.

### Directory

`TomDirectoryBlobStore` maps the key onto a path under a root directory. Two
details are load-bearing:

- **A write goes to `<key>.part` and is renamed into place.** Rename is atomic
  on every filesystem this runs on, so a reader sees either the previous file or
  the complete new one, never a half-written one. A failed write deletes the
  partial and leaves the previous file untouched.
- **A `<key>.meta` JSON sidecar** holds what a filesystem cannot: the media type
  and the original file name. `describe` falls back to `stat()` when the sidecar
  is missing, so a file placed in the directory by hand — a migration, an
  `rsync` — is still readable.

### Database

`TomDatabaseBlobStore` keeps blobs in two tables of a data source the
application already has. It is the backend that requires no infrastructure
decision: a deployment with a database can attach files without also
provisioning a bucket, a volume or a credential, and a backup of the database is
a backup of the files.

Three design points, each forced rather than chosen:

- **Chunks, not one `LONGBLOB`.** A single column would have to be read whole to
  be read at all, which is exactly the failure the streaming API exists to
  avoid. Chunk rows make `get` incremental.
- **base64 text, not `BLOB`.** The MariaDB driver in use decodes every column
  value into a Dart `String` before the mapper sees it (`ResultSetRow` holds
  `List<String?>`), so raw bytes do not survive a round trip. base64 in
  `LONGTEXT` is therefore the only *correct* representation available. It costs
  33 % in storage — the honest price of this backend, and one more reason a
  deployment storing large files should point at an object store.
- **Chunks carry an upload id; the manifest names the committed one.** A write
  streams its chunks under a fresh id and then replaces the one-row manifest in
  a single statement. A reader sees the previous blob or the complete new one; a
  write that fails deletes its own chunks and leaves the manifest alone.
  `purgeOrphanedChunks()` collects the residue of a cleanup that itself failed —
  housekeeping for a schedule, not repair.

Both tables are declared **once**, as `TomFrameworkTable` descriptors in
`database_blob_sql.dart`. The `CREATE TABLE` `ensureSchema()` issues, the chunk
`INSERT`, the manifest `REPLACE` and the column list of every read are all
derived from those two declarations, so a column exists in the code in exactly
one place. Hand-written reference migrations for a deployment whose database
user may not run DDL ship under
`example/file_storage/migrations/main/tomcore/`, and
`test/framework_schema_test.dart` compares them against the descriptors, along
with the reflected row types and every statement the store issues — see
[Schema Convergence](db_migration.md#schema-convergence) for what each of those
comparisons rules out, and for the `db`-tagged variant that makes the same
comparison against a provisioned `information_schema`.

### S3

`TomS3BlobStore` speaks the S3 REST API against AWS, MinIO, Ceph, Backblaze B2 —
anything SigV4-compatible — with no SDK dependency. Requests are signed by
`TomAwsV4Signer`, which is verified against AWS's own published test vectors.

An upload smaller than `partSize` (8 MiB by default) is a single signed `PUT`.
A larger one becomes a multipart upload: initiate, one part per `partSize`
window, complete. A part failure aborts the upload, so a half-uploaded object is
not left to be billed for. `x-amz-meta-filename` carries the original name.

## Configuration Selects the Backend

Stores are configured the way data sources are, and read the same way — the
`YamlMap` a config file decodes into is a `Map<dynamic, dynamic>`, so keys are
read defensively:

```yaml
files:
  type: directory
  default: true
  root: /var/lib/myapp/files

attachments:
  type: database
  datasource: main
  chunkSize: 262144

archive:
  type: s3
  endpoint: https://s3.eu-central-1.amazonaws.com
  bucket: myapp-archive
  region: eu-central-1
  accessKeyId: ...
  secretAccessKey: ...
```

```dart
await TomBlobStoreInfo.initializeBlobStores(config);
final store = TomBlobStoreInfo.defaultStore;          // or .storeNamed('archive')
```

One entry may carry `default: true`; when exactly one store is configured it
becomes the default without saying so, because a server with one place to put
files has no ambiguity to resolve.

An application with a backend of its own registers a factory under a name, and
from then on spells it in configuration like any built-in:

```dart
TomBlobStoreInfo.registerBackend('gcs', (name, settings) => GcsBlobStore(settings));
```

`TomBlobStoreInfo.register(name, store, asDefault: true)` is the seam for a test
or for an application that builds its store in code.

## File-Reference Columns

A `@TomFileReference` column holds a storage key. The row stays small enough to
select, diff, audit and mask like any other; the payload never passes through
SQL.

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'document', primaryKeyField: 'id')
class Document {
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int? id;

  @TomDbColumn(columnName: 'attachment')
  @TomFileReference(keyPrefix: 'documents/attachment')
  String? attachment;
}
```

The repository gains four methods over that column:

```dart
final saved = await repo.saveFile(doc, 'attachment', request.read(),
    mediaType: 'application/pdf', fileName: 'invoice.pdf');

final meta   = await repo.describeFile(saved.id!, 'attachment');
final stream = repo.openFile(saved.id!, 'attachment');

await repo.clearFile(saved, 'attachment');
```

`saveFile` **uploads and then saves**, in that order, because that is the
failure mode that is survivable. Saving first would leave a row pointing at a
key that reads back `not_found` — a dangling reference, visible to users and
repairable only by hand. Uploading first can at worst leave an orphaned blob,
which nothing references and a sweep can collect; and even that is cleaned up
when the save throws.

Besides `exposed` — which is the HTTP endpoint's business and is covered under
[Exposure Is Default-Closed](#exposure-is-default-closed) — the annotation
carries four settings:

| Setting | Meaning |
| ------- | ------- |
| `keyPrefix` | The leading segment of every generated key — the partition a retention rule addresses |
| `store` | The configured store name; the default store when omitted |
| `cascadeDelete` | Whether deleting the row deletes the bytes (default `true`) |
| `mediaType` | The media type to store when the caller supplies none |

## Where the Key Comes From

The key is **generated**, never taken from the client:

```text
<keyPrefix>/<yyyy>/<mm>/<uuid-v4><.ext>
documents/attachment/2026/07/1f0c…-4a2b….pdf
```

The prefix comes from the annotation, the year/month partition makes a retention
or archival rule expressible as a prefix (and keeps a directory backend's
directories a sane size), and the UUID makes the key unguessable and
collision-free.

The extension is the one part derived from caller-supplied text, and it is
filtered rather than escaped: `TomFileReferenceKeys.extensionOf` carries a short
alphanumeric suffix (≤ 12 characters), lower-cased, and *nothing else*. A "file
name" from a browser is text a user typed, not an identifier —
`evil.../etc` and `evil.p df` both yield an empty extension rather than a
cleverly quoted one.

## Authorization Is the Column's, Not a Second Copy

The key is an ordinary column, so the entity's `@TomDbScope` (C-3) and the
column's `authKey` (C-4) already govern who may read or change it. The file
methods therefore reach the bytes *through* the existing read paths rather than
beside them:

- `openFile` takes an **id** and loads the row with `findById`. A principal who
  cannot see the row cannot see its file — by construction, not by a second copy
  of the rule.
- `saveFile` runs the C-3 write assertion (`_assertInsertWritable` /
  `_assertRowWritable`) before any bytes move, and `save` enforces it again
  authoritatively at the end.

What is added on top is only what the masked case needs. A C-4 masked column
reads back as `null`, which is indistinguishable from "no file attached", so the
grade is checked explicitly and the refusal is named:

| Situation | Result |
| --------- | ------ |
| Column grade lacks `showsContent` | `column_authorization.read.field_forbidden` |
| Column grade lacks `isInteractive` on upload | `column_authorization.write.field_forbidden` |
| Row not visible or absent | `storage.file_reference.row_not_found` |
| Row visible, column empty | `storage.file_reference.no_file` |
| Field is not a file column of this entity | `storage.file_reference.unknown_column` |

The write refusal is raised *before* the transfer, so a principal who may not
write the column never uploads at all.

## What Happens to the Bytes When the Row Changes

| Operation | Effect on the blob |
| --------- | ------------------ |
| `saveFile` over a column that held a key | The superseded blob is deleted by `save` |
| `clearFile` | The blob is deleted (expressed as a save of a nulled column, so the audit record and both gates are the ordinary ones) |
| `delete` / `deleteById` / `deleteAllById` / `deleteByQuery` | Every cascading column's blob is deleted, *after* the rows are gone |
| Any of the above on a `cascadeDelete: false` column | The bytes are left alone |
| A save that does not touch the file column | Nothing |
| A save by a principal for whom the column is **masked** | Nothing — see below |

That last row is the subtle one. A masked column reads back as `null`, so a
naive "the key became null, delete the old blob" would destroy a file the caller
was not even allowed to see. The orphan diff is therefore measured against the
values actually **written** — and a preserved column is written from its
baseline — so a masked round trip cannot orphan a live blob.

A blob delete that fails **logs rather than raises**. Every caller has already
completed the operation the user asked for: the row was updated, the row was
deleted, the save was rolled back. A store that will not delete leaves bytes
behind, which is a housekeeping problem; raising would report a completed
operation as failed, which is a correctness problem. The key is logged so a
sweep can find what was left.

## Serving a File Over HTTP

The four repository methods are the server half of file transfer; the kernel's
`TomHttpFileTransferClient` is the client half. The endpoint between them is
shipped, because it is the same endpoint in every application: map a URL to an
entity and a file column, stream the request body into `saveFile`, stream
`openFile` back out, answer `HEAD` from `describeFile`, `DELETE` with
`clearFile`. Written by hand once per application, it is four chances per
application to get a status code or a header name subtly wrong.

Wiring it up is one line per entity:

```dart
TomFileSlots.register(documentRepository);
```

That is the whole application-side surface. `TomFileService` mounts itself with
the rest of the reflected endpoint pipeline — it is a `@tomService` like any
other, and `initializeRouter()` constructs its `@tomComponent` implementation
without a bean registration.

### Slots Are Derived, Not Declared

A slot is `<table>/<id>/<column>`, under the endpoint's `/files` base:

```
POST /files/document/4711/attachment
```

`document` is the `@TomDbTable(table: …)` name and `attachment` the
`@TomDbColumn(columnName: …)` name — both read from the entity by reflection.
There is no mapping table, which matters more than it sounds: a mapping table is
a second place the column name lives, and a rename that updates one and not the
other is a runtime 404 rather than a compile error. Here a renamed column
changes the slot with it. Registration also refuses an entity whose file columns
are ambiguous — two columns where one's Dart field name equals another's mapped
column name — because the repository accepts both spellings, and an ambiguous
slot could otherwise reach a column its URL does not name.

The `id` segment is coerced to the entity's key type; a value that is not one
(`/files/document/not-a-number/attachment`) is `400`, not a lookup with a
mangled key.

### Exposure Is Default-Closed

Reflection can see every file column, and must publish none of them by
accident. Exposure is a field on the annotation, next to the column it exposes:

```dart
@TomDbColumn(columnName: 'attachment')
@TomFileReference(keyPrefix: 'documents/attachment', exposed: true)
String? attachment;

@TomDbColumn(columnName: 'internal_scan')
@TomFileReference(keyPrefix: 'documents/internal')
String? internalScan;          // no slot: not addressable over HTTP at all
```

`exposed` decides **which** column a slot names. It never decides **whether** a
caller may have it — that stays with the row scope (C-3) and the column grade
(C-4) the repository already enforces, and the endpoint translates their
refusals rather than re-deciding them. A column that is exposed *and* graded is
still refused with `403`; the endpoint does not soften that into `404`, because
the caller is addressing a slot that exists and they may not have, and a
repository that says so explicitly should not be second-guessed.

### The Wire Contract

The endpoint answers exactly what `TomHttpFileTransferClient` expects, using the
kernel's own `tomFileDescriptorHeaders` to write the descriptor — the two halves
cannot drift, because they share the code that defines the shape.

| Method | Body | Success | Empty slot |
| ------ | ---- | ------- | ---------- |
| `POST` / `PUT` | the bytes, with `Content-Type` and optional `Content-Disposition: attachment; filename="…"` | `201` + descriptor JSON | — |
| `GET` | — | `200` + bytes + descriptor headers | `404` |
| `HEAD` | — | `200` + descriptor headers | `404` |
| `DELETE` | — | `204` | `404` |

The descriptor is `{"key", "mediaType", "byteCount", "fileName"?, "storedAt"?}`.
Note that the client never names a key: the server mints it from the column's
`keyPrefix`, so a caller cannot address, guess or collide with a storage
location. `404` on `GET`/`HEAD` deliberately means *both* "the slot holds no
file" and "there is no such slot" — telling them apart would tell an
unauthorised caller that the column is there.

Because the upload response carries the descriptor, and the descriptor carries
the storage key, an HTTP-exposed column must be readable by anyone permitted to
upload to it. This is intentional: handing the key to a principal who may not
read the column would be a disclosure. A write-only file column is expressible
in the repository, and simply is not exposable over HTTP.

Errors are reported as `{"key", "message"}` with the same key the repository
threw — `storage.file_reference.row_not_found`,
`column_authorization.read.field_forbidden`, and so on — so a client can
distinguish causes without parsing prose.

### Serving a File by Hand

Nothing about the four methods requires the shipped endpoint; an application
that needs a different URL shape, a signed redirect or an inline
`Content-Disposition` writes its own:

```dart
final meta = await repo.describeFile(id, 'attachment');
if (meta == null) return Response.notFound('No attachment.');
return Response.ok(
  repo.openFile(id, 'attachment'),
  headers: {
    'content-type': meta.mediaType,
    'content-length': '${meta.byteCount}',
    if (meta.fileName != null)
      'content-disposition': 'attachment; filename="${meta.fileName}"',
  },
);
```

`describeFile` is the metadata read that precedes a download — a caller needs
`Content-Type` and `Content-Length` before it starts streaming. Both calls are
gated identically, so the metadata read cannot become a side channel around the
download refusal.

### A File That Arrives as Part of a Form

The endpoint above moves a file over a **raw body**: the whole request is the
file, the slot is the URL. That is the right shape for "replace the attachment
of row 42" and the wrong shape for "create a document *with* its attachment" —
there is no row yet, and the title, the tags and the bytes arrive together.

That case is served by
[multipart form binding](endpoints.md#multipart-forms) in the endpoints module,
and the bytes still take **this** route to storage: a `TomFormFile` uploads
through the same `TomFileSlot` the raw-body endpoint uses.

```dart
final saved = await repo.save(Document()..title = request.title);
final stored = await attachment.storeIn('document', 'attachment', '${saved.id}');
```

`storeIn` resolves the slot exactly as the endpoint does — so an unregistered or
unexposed column refuses the upload there for the same reason it refuses it
here — and there is one route from bytes to storage rather than two.

## Exports Ride the Same API

`TomBlobExportStore` implements the export module's four-method
`TomExportStore` over any blob backend, so an export can be written to a
database, a bucket or an application's own store without the export module
knowing any of them exist:

```dart
final service = TomExportService(
  store: TomBlobExportStore.named('archive', keyPrefix: 'exports'),
);
```

The prefix exists because an export store is often pointed at a bucket that
holds other things; `exports/2026/07/sales.xlsx` keeps them apart and makes a
retention rule expressible. The key *recorded* in the returned `TomStoredExport`
is the caller's, not the prefixed one — an export whose recorded key could not
be passed back to `open` would be a trap.

## Core Components

- **`TomBlobStore` / `TomStoredBlob` / `TomStorageException`** — the contract,
  its descriptor, and the module's error.
- **`TomMemoryBlobStore` / `TomDirectoryBlobStore` / `TomDatabaseBlobStore` /
  `TomS3BlobStore`** — the four shipped backends.
- **`TomAwsV4Signer` / `TomAwsCredentials`** — SigV4 signing for the S3 backend.
- **`TomBlobStoreInfo` / `TomBlobStoreFactory`** — the configured registry and
  the seam for an application's own backend.
- **`blobManifestTable` / `blobChunkTable`** — the database backend's two table
  descriptors, from which its DDL and its statements are derived.
- **`TomFileReference` / `TomFileReferenceKeys`** — the column annotation, its
  key scheme, and store resolution.
- **`TomSqlDatasourceRepository.saveFile` / `.openFile` / `.describeFile` /
  `.clearFile`** — the entity-level file API and its cascade.
- **`TomFileRepository`** — the four-method contract those methods satisfy,
  named separately so the HTTP endpoint depends on the capability rather than on
  the SQL implementation.
- **`TomFileSlots` / `TomFileSlot`** — the reflection-derived slot registry:
  `register(repository)` publishes an entity's `exposed` file columns as
  `<table>/<column>`, and `resolve` finds one.
- **`TomFileEndpoint` / `TomFileService` / `TomFileServer`** — the shipped HTTP
  handler and the reflected service that mounts it at
  `/files/{entity}/{id}/{column}`.
- **`TomBlobExportStore`** — the export module's adaptor.

## Not Yet Implemented

- **Range requests.** `get` streams a whole blob; a video seek or a resumable
  download needs a byte range. Every backend can express one (a `Range` header,
  a file seek, a chunk-index arithmetic), so this is an addition to the
  contract rather than a redesign — but adding it before a caller needs it would
  be guessing at the signature.
- **Server-side copy and move.** Currently a copy is a `get` piped into a `put`,
  which is correct but crosses the network twice for S3, where a single
  `x-amz-copy-source` request would do.
- **Content addressing / deduplication.** Two identical uploads are two blobs.
  Deduplicating means hashing the payload, which means either buffering it or
  a second pass — a real cost to weigh against a benefit no deployment has yet
  asked for.
- **A blob-store migration.** Moving a deployment from the database backend to
  S3 is currently an application script; the key stays valid, so this is a copy
  loop rather than a schema change, but it is not shipped.
- **Quota and expiry.** `delete` exists and nothing calls it on a schedule; how
  long a file is worth keeping is a deployment's decision.
- **`purgeOrphanedChunks` on a schedule.** The method exists; wiring it to a
  periodic task belongs to whatever scheduler the application runs.

## Dependencies

- `tom_core_kernel` — `TomServerException` by way of `TomStorageException`,
  `tomLog`, and the `TomAuthState` grades the C-4 gate reads.
- `object_persistence` — `TomColumnInformation` and `TomAnnotationAnalyzer` for
  resolving file columns; `TomSqlDatasourceRepository` for the entity API.
- `datasources` — `TomDataSource` for the database backend.
- `crypto` — HMAC-SHA256 and SHA-256 for SigV4.
- `http` — the S3 backend's transport (injectable, so it is mockable).
- `uuid` — key generation and the database backend's upload ids.
- `path` — key-to-path joining in the directory backend.
- `dart:io` — `File` / `Directory` for the directory backend.
