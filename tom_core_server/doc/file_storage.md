# File Storage Module

Files that are too large to live in a row: a streaming put/get contract, four
backends behind it, configuration that selects one, a store in front of any of
them that keeps each distinct content once and holds each owner to a quota, and
a persistence-layer column kind that lets an entity own a file without carrying
its bytes.

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
  - [Who Owns a Chunk](#who-owns-a-chunk)
  - [A Broken Transfer Delivers What It Got](#a-broken-transfer-delivers-what-it-got)
  - [A Byte Range, and Who Is Obliged to Serve It](#a-byte-range-and-who-is-obliged-to-serve-it)
  - [The Content Digest](#the-content-digest)
  - [Quota and Expiry](#quota-and-expiry)
    - [Sweeping the database backend's residue](#sweeping-the-database-backends-residue)
  - [Migrating Between Backends](#migrating-between-backends)
  - [Relocating a Blob](#relocating-a-blob)
- [Keys Are a Grammar, Not a String](#keys-are-a-grammar-not-a-string)
  - [Prefixes obey the same grammar](#prefixes-obey-the-same-grammar)
- [The Backends](#the-backends)
  - [Memory](#memory)
  - [Directory](#directory)
  - [Database](#database)
  - [S3](#s3)
- [Deduplication, Quota and Reclaim](#deduplication-quota-and-reclaim)
  - [One Copy per Content](#one-copy-per-content)
  - [The Ledger](#the-ledger)
  - [Quota per Owner](#quota-per-owner)
  - [Reclaim](#reclaim)
  - [Sweeping Keys No Row Names](#sweeping-keys-no-row-names)
- [A Failure Is a Storage Error, Not the Backend's](#a-failure-is-a-storage-error-not-the-backends)
  - [`key` Is the Caller's Key, on Every Error](#key-is-the-callers-key-on-every-error)
- [Configuration Selects the Backend](#configuration-selects-the-backend)
  - [Every Setting Has to Bind](#every-setting-has-to-bind)
  - [An Entry Exists Before Its Store Does](#an-entry-exists-before-its-store-does)
- [File-Reference Columns](#file-reference-columns)
- [Where the Key Comes From](#where-the-key-comes-from)
- [Authorization Is the Column's, Not a Second Copy](#authorization-is-the-columns-not-a-second-copy)
- [What Happens to the Bytes When the Row Changes](#what-happens-to-the-bytes-when-the-row-changes)
- [Serving a File Over HTTP](#serving-a-file-over-http)
  - [Slots Are Derived, Not Declared](#slots-are-derived-not-declared)
  - [Exposure Is Default-Closed](#exposure-is-default-closed)
  - [The Wire Contract](#the-wire-contract)
    - [ETag and If-None-Match](#etag-and-if-none-match)
    - [Range](#range)
  - [Serving a File by Hand](#serving-a-file-by-hand)
  - [A File That Arrives as Part of a Form](#a-file-that-arrives-as-part-of-a-form)
- [Exports Ride the Same API](#exports-ride-the-same-api)
- [Verification](#verification)
- [Core Components](#core-components)
- [Not Yet Implemented](#not-yet-implemented)
- [Dependencies](#dependencies)

---

## Overview

| Type | Kind | Purpose |
| ---- | ---- | ------- |
| `TomBlobStore` | abstract class | The contract: `put` / `get` (whole or a byte range) / `describe` / `exists` / `delete` / `deletePrefix` / `copy` / `move`, by key |
| `TomStoredBlob` | class | What was stored — key, media type, size, time, digest, name, location |
| `TomBlobDigest` | class | The running SHA-256 a backend feeds while it writes |
| `TomBlobRange` | class | A half-open byte range of a blob, for the partial read `get` takes |
| `TomStorageException` | class | The module's base error |
| `TomBlobStoreOperation` | enum | What the caller asked for when a store failed — `write` / `read` / `probe` / `delete` / `copy` / `move` / `deletePrefix`, each carrying a stable error key |
| `TomMemoryBlobStore` | class | In-memory; tests and development |
| `TomDirectoryBlobStore` | class | A directory on disk, with a metadata sidecar |
| `TomDatabaseBlobStore` | class | Chunk rows in an existing data source |
| `blobManifestTable` / `blobChunkTable` | function | The database backend's two table declarations, from which its DDL, its statements and the convergence guard's schema model all derive |
| `blobManifestTableDdl` / `blobChunkTableDdl` | function | The `CREATE TABLE` text of those two, for a deployment that applies schema by hand |
| `defaultBlobManifestTable` / `defaultBlobChunkTable` | const String | The default names of those two tables — `tom_blob` and `tom_blob_chunk` |
| `TomBlobManifestRow` / `TomBlobChunkRow` | class | The reflected row types the database backend's result mapper materialises |
| `TomS3BlobStore` | class | Any S3-compatible object store, single-PUT or multipart |
| `TomAwsV4Signer` / `TomAwsCredentials` | class | AWS SigV4 request signing |
| `TomAwsCredentialsSource` | typedef | The credentials of each request, from a function — static keys or a role's temporary credentials; taken by the AWS secrets provider and the AWS message bus |
| `TomBlobStoreInfo` | class | The configured stores, by name, with a default |
| `TomBlobStoreBackend` | abstract class | A backend: its settings as fields, and the store they build |
| `TomMemoryBlobStoreBackend` / `TomDirectoryBlobStoreBackend` / `TomDatabaseBlobStoreBackend` / `TomS3BlobStoreBackend` | class | The four built-in backends — `memory`, `directory`, `database`, `s3` |
| `TomBlobStoreBackendFactory` | typedef | Creates a fresh backend of one type, for `registerBackend` |
| `TomDeduplicatingBlobStore` | class | A store in front of another that keeps one copy of each distinct content, charges each owner against a quota, and reclaims content no key names |
| `TomBlobLedger` | abstract class | The record a deduplicating store keeps beside the bytes: its keys, their owners and the contents they name |
| `TomMemoryBlobLedger` / `TomSqlBlobLedger` | class | That record in memory / in two tables of a data source |
| `TomBlobLedgerEntry` / `TomBlobContent` | class | One logical key of the ledger / one distinct content |
| `TomBlobUsage` | class | How many blobs and bytes an owner holds |
| `TomBlobQuota` | class | The most blobs and bytes one owner may hold |
| `blobLedgerTable` / `blobContentTable` | function | The SQL ledger's two table declarations |
| `blobLedgerTableDdl` / `blobContentTableDdl` | function | The `CREATE TABLE` text of those two |
| `defaultBlobLedgerTable` / `defaultBlobContentTable` | const String | Their default names — `tom_blob_ledger` and `tom_blob_content` |
| `TomBlobLedgerEntryRow` / `TomBlobContentRow` / `TomBlobUsageRow` / `TomBlobReferenceCountRow` | class | The reflected row types the SQL ledger reads |
| `tomBlobKeyUnder` | function | Whether a key is a prefix or lies below it, segment by segment |

This module is the bottom of a stack, and the rest of the file story is not in
it. Everything above the blob contract lives where its *other* concern lives —
an annotation among the persistence annotations, an HTTP handler among the
endpoints — and is named here because a reader arriving at "how do I store a
file" needs the whole route, not one layer of it:

| Name | Module | Purpose |
| ---- | ------ | ------- |
| `TomFileReference` | `object_persistence` | Marks a column as holding a storage key |
| `TomFileReferenceKeys` | `object_persistence` | Key generation and store resolution for that annotation |
| `TomBlobMigration` | `object_persistence` | Moving a deployment's blobs between backends, driven by the rows that name them |
| `TomBlobOrphanSweep` / `TomBlobOrphanSweepReport` | `object_persistence` | Deleting the keys of a deduplicating store that no row refers to, and what one sweep did |
| `TomBlobReferenceSource` / `TomRepositoryBlobReferences` | `object_persistence` | What the sweep asks which keys are referenced — a repository's `@TomFileReference` columns, or anything else |
| `TomSqlDatasourceRepository.saveFile` / `.openFile` / `.describeFile` / `.clearFile` | `object_persistence` | The entity-level file API |
| `TomFileRepository` | `object_persistence` | The five-method file contract — `findById`, `saveFile`, `openFile`, `describeFile`, `clearFile` — independent of SQL |
| `TomFileSlots` / `TomFileSlot` | `endpoints` | Reflection-derived `<table>/<column>` slot registry |
| `TomFileEndpoint` | `endpoints` | The HTTP handler: POST / GET / HEAD / DELETE over a slot |
| `TomFileService` / `TomFileServer` | `endpoints` | Mounts the handler at `/files/{entity}/{id}/{column}` |
| `TomFileSlotException` | `endpoints` | Slot registration and resolution errors |
| `TomBlobExportStore` | `export` | The export module's store, over any blob backend |

## The Shape of the Design

Three things, each replaceable without touching the other two:

1. **A contract** — `TomBlobStore`. Five methods over a key and a byte stream.
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

Stream<List<int>> get(String key, {TomBlobRange? range});
Future<int> deletePrefix(String prefix);
Future<TomStoredBlob> copy(String fromKey, String toKey);
Future<TomStoredBlob> move(String fromKey, String toKey);
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

### Who Owns a Chunk

Streaming makes ownership a question worth answering, in both directions, and
the contract answers it the same way each time: **the chunk belongs to whoever
did not produce it, for exactly as long as it takes to use it.**

- A chunk `get` yields is the **reader's own** — writable, and aliased with
  nothing the store keeps. A consumer decoding in place is doing something
  ordinary, and it must not edit the stored blob by doing it.
- A chunk handed to `put` is **borrowed for the duration of the `await`**. The
  store consumes or copies it before asking for the next one and never retains
  it, because a producer refilling one fixed-size buffer per chunk is the
  ordinary shape of an encoder.

The three backends that read and write elsewhere satisfy both without trying: a
chunk off a file, a row or a socket is fresh, and a chunk written to one is gone.
`TomMemoryBlobStore` is the only backend holding the bytes it serves, so it is
the only one that can accidentally share a buffer — and it copies, on both
sides. The same asymmetry applies to `TomMemoryExportStore` in the export module.

The copy is deliberate rather than an unmodifiable view, which would be cheaper.
An unmodifiable chunk would make the same in-place consumer throw on the backend
the tests run on and succeed on every backend they deploy to — a divergence
discovered in production, which is the one place this backend exists to keep
faults out of. `getBytes` inherits whatever `get` yields: it collects with a
non-copying builder, which returns a lone chunk untouched.

### A Broken Transfer Delivers What It Got

A download that fails partway **yields the chunks that arrived, and then
throws**. Both halves are the contract, and the second is the reason the first
has to be stated: it would be easy to satisfy "a failed read throws a
`storage.blob.read_failed`" by draining the backend's stream first and throwing
before yielding anything, and every test of the error would still pass.

It would also be wrong twice over. It reintroduces the buffering this whole
section exists to prevent — on the read side, where the file is largest. And it
destroys the only information a consumer has to act on: a caller that has
written the first megabytes to disk can truncate them and retry a range; a
caller handed an error and nothing else cannot distinguish a transfer that broke
from an object that was empty.

So the translation wraps the *forwarding* rather than replacing it. `get`
re-yields each chunk as it arrives inside the `try` that names the failure,
which is why every backend can hand its raw stream — an `openRead`, an HTTP
response body, a cursor over chunk rows — straight up without wrapping anything
itself. `TomExportStore.open` states and does the same.

### A Byte Range, and Who Is Obliged to Serve It

`get` takes an optional `TomBlobRange`: a half-open `[start, endExclusive)`, with
a null end meaning *to the end of the blob*. Half-open because `File.openRead`
and `List.sublist` are, which is where a range ends up. Both ends are checked at
construction, so every backend refuses the same nonsense the same way — the same
reason key validation sits on `TomBlobStore` and not in each `do*`.

**No backend is obliged to implement it.** `doGetRange` is concrete on
`TomBlobStore` and reads from zero, discarding everything before the range and
stopping once the range is served. A backend that overrides nothing still serves
a range correctly; it just pays for the prefix, which for a seek near the end of
a large blob is the whole thing. That is the same arrangement `doExists` has over
`doDescribe`: one obligation, with a faster path where one exists.

All four shipped backends take the faster path, and each does it the way its
medium already offers:

| Backend | How | What it costs |
| ------- | --- | ------------- |
| `TomDirectoryBlobStore` | `openRead(start, end)` | a real file seek |
| `TomMemoryBlobStore` | `sublist` — copied, like a whole read | one memcpy of the slice |
| `TomDatabaseBlobStore` | `start ~/ chunkSize` names the first chunk row | the rows the range touches, not the rows before it |
| `TomS3BlobStore` | a signed `Range: bytes=a-b` header | the slice crosses the wire, not the object |

The database backend records `chunk_size` in the manifest rather than assuming
its own, because the size is a constructor argument: a store reconfigured
between the write and the read would otherwise divide by the wrong number and
serve the wrong bytes. It is not derivable from `byte_count` and `chunk_count`
either — ten bytes in two chunks is 6+4 or 9+1 or 5+5. A manifest that carries no
size falls back to the inherited read, which is slow and correct.

The S3 header is **inclusive at both ends** where this module's range is
exclusive at the top, so an open-ended range goes out as `bytes=500-` — the store
does not know the object's size, and inventing one would be a second place that
size is decided.

Putting the fallback on the contract rather than in the caller is the decision
worth naming. A download endpoint honouring HTTP `Range` needs *a* range read
from whatever backend is configured; writing the discard at the endpoint instead
would mean the S3 backend's native capability could not be reached through the
interface at all.

### The Content Digest

Every blob `put` stores carries the **SHA-256 of its content**, as 64 lowercase
hex characters on `TomStoredBlob.digest`, recorded beside the media type and the
file name and read back by `describe`.

It is unconditional rather than optional, and that is the decision. A nullable
digest is one no caller can build on — every use of it would begin by handling
the case where it is missing, which is the case a caller cannot do anything
about. What it buys once it is always there:

- **Integrity.** A transfer that completes is not a transfer that arrived
  intact. A caller that hashes what it received has something to compare it to.
- **Deduplication.** A caller can ask whether the bytes it is about to send are
  already stored, before sending them, and `TomDeduplicatingBlobStore` stores
  each distinct digest once — see
  [Deduplication, Quota and Reclaim](#deduplication-quota-and-reclaim).
- **A validator.** The file endpoint serves it as an `ETag` and answers
  `If-None-Match` with `304`, so a client that already holds the bytes is not
  sent them again.

The cost is one pass over bytes the backend is already touching — the hash rides
the write, never a second read:

| Backend | Where the hash is taken |
| ------- | ----------------------- |
| `TomMemoryBlobStore` | the assembled buffer, which it holds anyway |
| `TomDirectoryBlobStore` | the chunks flowing into the file sink |
| `TomDatabaseBlobStore` | the incoming chunks, before they are re-cut to `chunkSize` |
| `TomS3BlobStore` | the incoming chunks — the only place the *whole* object passes on a multipart upload |

**Where each backend keeps it.** The directory store writes it into the metadata
sidecar, the database store into a `digest CHAR(64)` column, and the S3 store
into `x-amz-meta-digest`. S3 has no protocol header that means this:
`x-amz-content-sha256` is the *signature's* payload hash, which on a multipart
upload is a part's hash rather than the object's, and `ETag` is an MD5 only for
single-part objects. A multipart upload therefore sets its digest *after* the
parts are in, with a copy onto the same key and
`x-amz-metadata-directive: REPLACE` — one request, the object store moving
nothing — because multipart metadata is fixed when the upload is created, before
the last part has been seen. Skip that and the largest objects, the ones a
caller most wants to verify, would be the ones with no digest.

**A copy carries the digest rather than recomputing it.** The bytes are the
same, so the hash is; recomputing would mean reading a blob the whole point of
[Relocating a Blob](#relocating-a-blob) is not to read.

**`TomStoredBlob.unknownDigest` is the empty string, and `hasDigest` is the
question to ask.** A blob this framework did not write — a file dropped into a
directory store's tree by hand, an object already in a bucket the store was
pointed at — has no recorded hash, exactly as it has no recorded media type. The
sentinel is empty rather than `null` so that "not recorded" cannot be confused
with the digest of zero bytes, which is a real and well-known value
(`e3b0c442…`); a nullable field would make every caller write the same `?? ''`
and an accidental `''` would then read as a hash.

### Quota and Expiry

A backend on its own has no limit and forgets nothing: no per-tenant ceiling,
no total ceiling, no retention, and nothing that would notice a caller
uploading until the volume filled. The database backend is the sharpest case, because its blobs
sit on the same disk as the rows they belong to — an unbounded blob store there
is an unbounded outage for everything else in that database.

**For a plain store the deployment owns both, and the module owns one
primitive.** A quota is a
question about *whose* data — a tenant, an account, a plan — and expiry is a
question about *what kind* of file and *how long* it is worth keeping. Storage
knows neither, and a store that tried to answer them would need a schema for
tenancy and a policy language, both of which already exist one layer up. What a
deployment needs to answer them is a **row per stored blob**, which it very
likely has already: `TomStoredBlob` is that row — key, media type, size, time
and the content digest — so the quota is a `SUM(byte_count)` and the expiry is a
`WHERE stored_at <`.

One ceiling needs no schema beyond the store: how much **one owner** — a
principal, a tenant, a job — holds. `TomDeduplicatingBlobStore` keeps that
record itself and refuses a write past a `TomBlobQuota`; see
[Deduplication, Quota and Reclaim](#deduplication-quota-and-reclaim).

**The one thing a deployment's record cannot assemble from outside is the
reclaim**, and that is what the module adds:

```dart
// Everything stored on 8 July, in one call.
final removed = await store.deletePrefix('2026/07/08');
```

Deleting a partition key by key is a call per blob; a prefix delete is a call
per partition. It is the operation the date partitioning in a generated key
exists for — `TomFileReferenceKeys.generate` writes `<prefix>/<yyyy>/<mm>/<uuid>`
precisely so a month is expressible as a prefix.

**The prefix is matched by key segment, never by characters.** `2026/07` removes
`2026/07` and everything beneath it, and never `2026/070`. A string prefix that
can reach a sibling is an ordinary convenience everywhere except in a delete,
where it is how a month's retention takes the next month with it. An empty
prefix is refused (`storage.blob.invalid_key`) for the same reason: it names
every file there is, and a delete whose argument came from a configuration value
that turned out empty should not empty the store.

**Every shipped backend can, and `supportsPrefixDelete` is how to ask:**

| Backend | How, and what it costs |
| ------- | ---------------------- |
| `TomMemoryBlobStore` | a scan of its own key space |
| `TomDirectoryBlobStore` | one recursive directory delete — and it counts *blobs*, not the sidecars beside them |
| `TomDatabaseBlobStore` | one `DELETE` over the manifest, then the chunks of each upload no row still names |
| `TomS3BlobStore` | a paginated `ListObjectsV2` plus batched `DeleteObjects` — the one operation here whose cost is not a single request, and it says so |

A backend that cannot throws `storage.blob.prefix_delete_unsupported` naming
itself, rather than answering `0`: "the purge found nothing" and "this backend
cannot purge" must not be the same answer, or the deployment learns the
difference from a disk filling up.

**S3's is eventually consistent**, and that is a property of the service rather
than of this code: a `LIST` may not yet show an object written a moment ago, so
a prefix delete run against a key space something is still writing to can leave
one behind. Retention runs against partitions nothing is still writing to, which
is what the date in a key is for.

**The schedule is the deployment's.** Nothing here runs on a timer by itself.
A nightly purge belongs in the back-office tier beside the other passes that
tidy up after the day — the scheduling module already provides the machinery,
and a second copy of it here would give this module two reasons to change. The
deduplicating store's reclaim and the orphan sweep each describe their job
(`reclaimJobDefinition`, `TomBlobOrphanSweep.jobDefinition`); registering it
with a scheduler is the deployment's call.

#### Sweeping the database backend's residue

`TomDatabaseBlobStore` stores a blob as one manifest row plus N chunk rows, and
every path that removes one deletes the manifest **first** — that is the point
at which the blob is gone — and the chunks after. A failure between the two
leaves chunk rows nothing refers to. `purgeOrphanedChunks()` is the sweep for
them, and it needs a caller.

**Weekly, and after whatever deletes blobs.** The residue needs a cleanup that
*failed*, not a blob that was deleted, so it accumulates at the rate of that
failure and not at the rate of the deletions — a nightly sweep would spend six
full-table anti-joins a week finding nothing. Run it after the pass that removes
blobs (a retention purge, a cascading row delete), since that is where the
residue is created; run it before anything that writes into the same store, so
the scan reads the fewest rows that can never be orphans.

**What it costs to skip.** The sweep is a predicate over the table rather than a
window, so a missed run collects nothing extra and the next one takes everything
— there is no backlog to catch up. What grows in the meantime is the chunk
table, by the size of each blob whose cleanup failed. Those rows are *invisible*:
no read finds them, no `describe` reports them, and `purgeOrphanedChunks` is the
only thing that counts them. The first symptom is a table larger than the blobs
it holds — and on this backend that disk is the same disk the application's rows
are on.

A number that is routinely non-zero is not a sweep doing its job. It is a
cleanup path failing somewhere, and the sweep being the only thing that notices.

`advanced_ops_server` runs it — 04:00 on Sunday, after its 03:00 retention purge
and before its 05:00 export — as `OpsBlobSweepJob` over `OpsBlobSweepService`.
That service resolves the configured store at **wire-up** and refuses anything
that is not a database backend, because a directory store has no chunk rows and
an object store has no manifest: repointing the store elsewhere does not make
the job harmless, it makes it a scheduled no-op that reports success.

### Migrating Between Backends

A deployment that starts on the directory backend and outgrows it has to move
its files. The hard part is not the copying, it is knowing *what* to copy: a
blob store cannot enumerate itself, deliberately.

**So the key list comes from the rows.** A `@TomFileReference` column holds a
storage key, which makes a sweep of the table an enumeration of the blobs the
deployment can still reach — and it is the enumeration that matters, because a
blob no row points at is one nothing can serve. `TomBlobMigration` is that
sweep, and it uses only `get`, `describe` and `put`, so it works between any two
backends including one an application wrote.

```dart
final report = await TomBlobMigration(
  source: TomBlobStoreInfo.storeNamed('files-on-disk'),
  target: TomBlobStoreInfo.storeNamed('files-on-s3'),
).migrate(documentRepository);
```

Then repoint the configuration and run it again: the second pass copies nothing
and confirms the first. That is also how an interrupted migration is resumed —
"already there" is a **digest** comparison, so it is a fact rather than a guess
about a key that happens to exist, and a target holding *different* bytes under
the same key is overwritten rather than mistaken for a finished copy.

**It does not write to the rows**, and that is worth stating because the obvious
design does. A backend migration changes no key: the column holds the key, and
which *store* that key is read from is configuration — `@TomFileReference(store:)`
and `TomBlobStoreInfo` — not data. Saving each row back would be a no-op that
ran both authorization gates, stamped the audit trail and moved every `updated`
timestamp in the table. So the sweep is read-only on the database and can run
against a live system.

**It refuses to run inside a request.** `findAll` applies the entity's row scope
(C-3) and masks the columns the principal may not read (C-4), so under a request
principal the sweep would migrate that principal's *view* of the table and
report success — and a masked file column reads back `null`, which is
indistinguishable from a row holding no file. A migration that quietly moved a
subset is the worst outcome available here, so `storage.migration.scoped_run` is
raised before a single row is read. `allowScopedRun: true` is the explicit
escape for a deployment whose scope resolver opts out for its system principal.

**A dangling reference is reported, not thrown.** One row pointing at a blob
that is gone must not stop a migration of ten thousand: it is a fault in the
data that predates the migration, and an operator wants the whole list. A copy
that does not *match* what was read is the opposite — it throws and stops,
because that is the one failure a later pass cannot detect, the next run finding
the key present and moving on.

**What it cannot do is find orphans.** No care here changes that. The report's
`claimed` list is what a deployment diffs its old store against, using that
backend's own tooling: `find` over a directory, `ListObjectsV2` over a bucket, a
`SELECT` over the manifest table. That is a fair thing to ask of a one-off
migration against a known backend, and not a fair thing to put on a contract
every backend must implement.

### Relocating a Blob

`copy` and `move` are on the contract for the same reason, and with the same
shape: a concrete default built from the four required methods, and an override
on every backend that can do better.

Relocation is not a hypothetical. The documented pattern for expiry is a
date-prefixed key, so re-partitioning a key space is a thing deployments do —
and without these it means pulling every byte through the server and pushing it
back.

| Backend | Copy | Move |
| ------- | ---- | ---- |
| default | `get` piped into `put` | the copy, then a delete |
| `TomMemoryBlobStore` | a second map entry | remove and re-insert |
| `TomDirectoryBlobStore` | `File.copy`, staged and renamed | a `rename` — no bytes move, and it is atomic |
| `TomDatabaseBlobStore` | a second manifest row against the **same** upload | one `UPDATE` of the key column |
| `TomS3BlobStore` | `x-amz-copy-source` — the object never leaves the store | the copy, then a delete |

A concrete default is right here in a way it would not be for a listing. The
cost of this one is not misleading — a stream round trip is exactly as expensive
as it looks — whereas a default `list` would hide a paginated scan behind a
method that reads like a map lookup.

**Rules both share.** Anything at the destination is **replaced**, as it is by
`put`; refusing an occupied destination would be a second rule to remember for
the operation most likely to be run in bulk. The media type and the file name
travel with the bytes, because a copy that lost its `Content-Type` is served as
`application/octet-stream` and downloads as a file nothing opens. An absent
source is `storage.blob.not_found` rather than an empty destination — a
relocation loop that quietly created empty blobs for the keys that had gone
would be worse than one that stopped. A key onto itself is
`storage.blob.same_key`: there is no reading of it worth guessing at, the
obvious implementation is a truncation on any backend whose write is not atomic,
and S3 refuses it outright.

**The order inside `move` is the contract**, not an implementation detail. The
destination is committed before the source is removed, so an interrupted move
leaves the blob readable under *both* keys rather than under neither. The
residue of a failure is a duplicate, which a retry converges on; the residue of
the other order is a deletion.

**The database backend's copy shares chunks**, which is what makes a gigabyte
copy in one statement — and what makes the guard on the chunk delete
load-bearing rather than tidy. Deleting or overwriting either key releases the
chunks only when no manifest row still names the upload, the same predicate
`purgeOrphanedChunks` applies to the whole table. Without it, deleting one key
would take the bytes the other still points at, with no error anywhere.

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
and a traversal in the next.

`TomBlobStore.validateKey` is called by `put`, `get`, `describe`, `exists` and
`delete` alike — those five are the contract's own methods and a backend is
reached only through the `do*` method beneath each — so an invalid key never
reaches the filesystem, the network or SQL, on a read any more than on a write.
Putting the check in the contract rather than in each backend is also what makes
that sentence true of a backend an application writes. It was not always: the
check sat at the top of each backend's `put`, three of the four validated
nowhere else, and `get('../escape')` therefore answered `invalid_key` on a
directory store and `not_found` on a memory one — the wrong error, and for a
caller branching on the two, the wrong branch.

### Prefixes obey the same grammar

Several components namespace keys by joining a configured prefix onto them —
`TomS3BlobStore.keyPrefix` so one bucket can host several stores,
`TomBlobExportStore.keyPrefix` so exports sit apart from whatever else is in the
store, `@TomFileReference(keyPrefix:)` so one column's blobs are addressable as
a partition. A prefix is not a separate notion from a key: it is joined as
`"$keyPrefix/$key"`, so `isValidKeyPrefix` holds it to `isValidKey`. `null` and
`''` both mean *no namespace*; a trailing slash is **not** a second spelling,
because the join supplies the separator and `exports/` would produce
`exports//sales.csv`.

Each of these checks its prefix as early as it can — at construction for the two
stores, at key generation for the annotation, whose `const` constructor cannot
refuse a value — and fails naming the prefix (`storage.blob.invalid_key_prefix`,
or `export.store.invalid_key` in the export module's own vocabulary). The point
is *whose* mistake the error describes: a misconfigured prefix used to surface
on the first write, as an invalid-key error about a key the caller never wrote.

Length is the one clause that check cannot settle — a prefix and a key may each
be within `maxKeyLength` and still exceed it once joined, which depends on a key
that has not arrived yet. The obligation therefore belongs to whoever performs
the join, and where the join happens decides how it is discharged.
`TomBlobExportStore` and `@TomFileReference` join *above* a blob store, so the
joined key passes through `validateKey` like any other and the length is checked
for free. `TomS3BlobStore` joins *below* that boundary — the prefix goes into a
signed request URI, not through the public methods — and so checks the joined
length itself, at every request.

That last check is not redundant with what the object store would do. S3's own
limit is 1024 bytes, twice ours, so an over-long joined key is accepted there:
without the check, this one backend would hold keys every other backend refuses,
and `maxKeyLength` would mean something different depending on where a blob
happened to be stored. Both refusals name the prefix rather than the key, for the
reason above: the caller's key is fine, and the prefix that leaves no room for it
leaves no room for any other key either.

## The Backends

### Memory

`TomMemoryBlobStore` holds everything in a map. It buffers whole blobs by
definition, which is the one place in this module where that is acceptable, and
the reason it is not a default. It is what tests use, and what a development
server uses when it should not leave files behind.

It is also the only backend that copies deliberately, in both directions — see
[Who Owns a Chunk](#who-owns-a-chunk). The others store their bytes somewhere
else and get the same property for nothing.

### Directory

`TomDirectoryBlobStore` maps the key onto a path under a root directory. Two
details are load-bearing:

- **A write goes to `<key>~part` and is renamed into place.** Rename is atomic
  on every filesystem this runs on, so a reader sees either the previous file or
  the complete new one, never a half-written one. The rename is therefore the
  commit, and it is what decides what a failure has to clean up: **before** it
  the leftover is the partial and the previous file is untouched; **after** it
  there is no partial and the leftover is the new file. The rollback deletes
  whichever exists, so a failure before the rename leaves the previous content
  intact and a failure after it leaves the key empty. The second half is the
  best a rename-based commit can do — the rename is itself the destructive step,
  and there is nothing left to restore once it has happened.

  Only the sidecar write comes after the rename, and it is not tolerated
  quietly. A blob without a sidecar reads back fine, but `put` was about to
  return a descriptor naming a media type and file name that a later `describe`
  would contradict — and it will not return at all, so the caller is entitled to
  assume nothing was stored.
- **A `<key>~meta` JSON sidecar** holds what a filesystem cannot: the media type
  and the original file name. `describe` falls back to `stat()` when the sidecar
  is missing, so a file placed in the directory by hand — a migration, an
  `rsync` — is still readable.
- **Both auxiliary suffixes hang off `~`**, which the
  [key grammar](#keys-are-a-grammar-not-a-string) cannot produce: it admits
  `[A-Za-z0-9._/-]` and nothing else. Suffixes the grammar *can* spell —
  `.part` and `.meta` — would not be a cosmetic difference: two callers picking
  ordinary keys would destroy each other's data. `put('a')` followed by
  `put('a.meta')` would overwrite the first blob's sidecar with the second
  blob's bytes, so `a` silently loses its media type; `delete('a')` would then
  delete `a.meta` unconditionally and report success, taking a blob its caller
  never named. The marker closes both by making the bookkeeping unaddressable
  rather than by policing keys.

  It stays in this backend rather than moving into the shared grammar for the
  reason the grammar is shared: a key the directory backend refused would be a
  key S3 and the database refused too, for a reason belonging to neither, and
  the backends would stop being drop-in replacements for one another. A parallel
  `root/.meta/<key>` tree was the other candidate and fixes nothing — `.meta` is
  a valid key *segment*, so the key `.meta/a` collides in turn.

### Database

`TomDatabaseBlobStore` keeps blobs in two tables of a data source the
application already has. It is the backend that requires no infrastructure
decision: a deployment with a database can attach files without also
provisioning a bucket, a volume or a credential, and a backup of the database is
a backup of the files.

`TomDatabaseBlobStore.named(datasourceName)` — the constructor configuration
uses — looks the data source up when the store is built and refuses a name
nobody registered with `storage.database.unknown_datasource`, so a misspelt
`datasource:` fails at start-up rather than on the first upload.

Three design points, each forced rather than chosen:

- **Chunks, not one `LONGBLOB`.** A single column would have to be read whole to
  be read at all, which is exactly the failure the streaming API exists to
  avoid. Chunk rows make `get` incremental.
- **base64 text, not `BLOB`.** Every SQL driver hands the mapper each column
  value as a Dart `String` (`TomSqlRow`; MariaDB's `ResultSetRow` holds
  `List<String?>`), so raw bytes do not survive a round trip. base64 in
  `LONGTEXT` is therefore the only *correct* representation available. It costs
  33 % in storage — the honest price of this backend, and one more reason a
  deployment storing large files should point at an object store.
- **Chunks carry an upload id; the manifest names the committed one.** A write
  streams its chunks under a fresh id and then replaces the one-row manifest in
  a single statement. A reader sees the previous blob or the complete new one; a
  write that fails deletes its own chunks and leaves the manifest alone.
  `purgeOrphanedChunks()` collects the residue of a cleanup that itself failed —
  housekeeping for a schedule, not repair. See
  [Sweeping the database backend's residue](#sweeping-the-database-backends-residue)
  for how often to run it and what grows if nobody does.

`chunkSize` sizes those rows, in *raw* bytes, and defaults to
`TomDatabaseBlobStore.defaultChunkSize` — 256 KiB, declared once so the number
has somewhere to carry its reasoning. Only one of its two bounds can be
enforced, and the store enforces that one: a size of zero or less is refused at
construction with `storage.database.chunk_size_not_positive`, because `put`
slices its incoming events with a clamp that is `0` on every iteration once
`chunkSize` is, so such a store does not fail an upload — it hangs on one, with
no exception to log and nothing for a caller to catch. Construction is the last
moment at which a deployment can be told.

The other bound is real and belongs to the server. A chunk is stored as base64,
so its wire size is ~4/3 of `chunkSize` and the statement carrying it is larger
again; on MariaDB all of it has to fit inside `max_allowed_packet`. That is a
server variable, not a protocol constant — a deployment may raise it, and a
constructor that guessed its value would refuse a configuration that works. So
this bound is a sizing note rather than a check: the 256 KiB default sits well
inside the usual 16 MiB, and a store configured far above it will fail its first
upload with a driver-level packet error.

Both tables are declared **once**, as `TomFrameworkTable` descriptors in
`database_blob_sql.dart`. The `CREATE TABLE` `ensureSchema()` issues (in the
connected database's words), the chunk `INSERT`, the manifest's replacing write
(`replaceRow`) and the column list of every read are all derived from those two
declarations, so a column exists in the code in exactly
one place.

Both are **system tables**: whichever pool the store was built over, it keeps
them in the system data source, once for the deployment. The manifest records,
in its `tenant` column, the tenant in context when a blob was written — `''`
outside a tenant — so `keysOfTenant(tenant)` lists one tenant's blobs, which is
what exporting or erasing a tenant's files starts from.

A deployment whose database user may not run DDL applies that schema itself and
constructs the store with `createSchema: false`. For the default table names the
statements ship as reference migrations under
`example/file_storage/migrations/system/main/tomcore/`. For a store constructed with
`manifestTable:` or `chunkTable:` set to something else there is no shipped file
— its schema exists only as what `blobManifestTableDdl()` and
`blobChunkTableDdl()` return for those names, which is what those two functions
are for.

`test/framework_schema_test.dart` compares the shipped chain against the
descriptors, along with the reflected row types and every statement the store
issues — see [Schema Convergence](db_migration.md#schema-convergence) for what
each of those comparisons rules out, and `test/framework_schema_db_test.dart`
for the `db`-tagged sibling that makes the same comparison against a provisioned
`information_schema`. That check is
about the schema a chain *arrives at*, so it is deliberately blind to how a
statement is spelled; `test/file_storage_schema_test.dart` compares the spelling,
which is what a deployment actually copies.

### S3

`TomS3BlobStore` speaks the S3 REST API against AWS, MinIO, Ceph, Backblaze B2 —
anything SigV4-compatible — with no SDK dependency. Requests are signed by
`TomAwsV4Signer`, which is verified against AWS's own published test vectors.

The signer implements SigV4, not just the handful of requests this store makes,
because it is public API and separable: signing is a pure function of a request
and a key, so it is testable against those vectors rather than against a live
bucket. That is why it canonicalises cases the store never produces — a repeated
query parameter contributes every one of its values, though no request here
repeats a name.

An upload smaller than `partSize` (8 MiB by default) is a single signed `PUT`.
A larger one becomes a multipart upload: initiate, one part per `partSize`
window, complete. A part failure aborts the upload, so a half-uploaded object is
not left to be billed for. `x-amz-meta-filename` carries the original name.

Without a `client` of its own the store sends through the kernel's
`TomResilientClient`, under the policy of the object store's destination (the
`httpClient` key, see [configuration.md](configuration.md#outgoing-http-calls)):
every request is bounded by the timeout, the circuit breaker and the bulkhead,
and the idempotent ones — `GET`, `HEAD`, `DELETE` and the `PUT`s of an
upload, a part and a copy — are retried after a connection failure, a timeout or a
`429`/`502`/`503`/`504`. The `POST`s — initiating and completing a multipart
upload, `DeleteObjects` — are sent once. Every request carries its body in
memory, so the destination's `timeoutMs` (30 seconds by default) also covers
sending an upload or a part of up to `partSize`; over a slow link, give the
object store's destination a longer one. A request the policy refuses or
abandons fails like any other, as one of the operation keys below.

S3 refuses a multipart part below 5 MiB (`minimumPartSize`), and such a store
could not upload anything larger than one part, so a smaller `partSize` is
refused at construction with `storage.s3.part_size_too_small`. Two answers from
the object store break the protocol rather than failing a request, and each has
its own key: an initiation that returns no upload id
(`storage.s3.no_upload_id`), and a part acknowledged without an `ETag`, which
the completing request must name (`storage.s3.part_without_etag`).

**`delete`'s boolean is best-effort here, and exact everywhere else.** The
contract says `delete` answers whether anything was there. A filesystem, a map
and a manifest row answer that in the same operation that removes the blob, so
their boolean is a fact. S3's `DELETE` answers `204` whether or not the object
existed, so this backend asks separately with a `HEAD` — and another caller can
create or remove the key between the two calls. Two concurrent deletes of one
key can therefore both answer `true`, and a delete racing a `put` can answer
`false` having removed nothing that the `put` then writes.

There is no conditional delete to close it with: `DeleteObject` takes no
`If-Match`, and a versioned bucket's delete marker answers *which version* went
rather than *whether anything was there*. The exact answer is kept rather than
replaced by a `void` no backend could get wrong, because a boolean that is a
fact on three backends and a recent observation on the fourth is more useful
than no answer anywhere — and the window only misleads a caller that is already
racing itself. A caller that must not race holds a lock of its own; nothing in a
storage API can supply one.

`test/file_storage_test.dart` demonstrates both halves rather than describing
them: an object appearing between the probe and the request, and two concurrent
deletes both reporting success.

## Deduplication, Quota and Reclaim

`TomDeduplicatingBlobStore` is a `TomBlobStore` in front of another one — any of
the four backends, called the **content store** — and a `TomBlobLedger`, the
record of every logical key it holds. Callers use it like any store; underneath
it keeps each distinct content once, charges each write to an owner, and deletes
content only once nothing has wanted it for a while.

```dart
final store = TomDeduplicatingBlobStore(
  content: TomDirectoryBlobStore.at('/var/lib/app/files'),
  ledger: TomSqlBlobLedger(datasource),
  quota: const TomBlobQuota(maxCount: 1000, maxBytes: 512 * 1024 * 1024),
);

await TomDeduplicatingBlobStore.runAs('job:import', () async {
  await store.putBytes(key: 'imports/2026/10/a.csv', bytes: csv);
  await store.putBytes(key: 'imports/2026/10/b.csv', bytes: csv); // same bytes
});
```

The two keys above name one stored copy. The ledger is what a plain store does
not have — a store cannot list itself — and every other part of this section is
a question asked of it: who holds how much, which contents are still named,
which keys are older than a week.

### One Copy per Content

A write streams into a fresh **staging key** under `stagingPrefix` (default
`tom-staging`) of the content store while the store computes the SHA-256 itself,
so a content store that records no digest still deduplicates. Once the bytes are
in, the ledger is asked for the content with that digest:

- **Not held yet**: the content is created under a fresh **content key**,
  `<contentPrefix>/<first two hex digits>/<digest>-<12 random hex>` (default
  prefix `tom-content`), and the staged bytes are moved there — a rename on
  every backend that has one.
- **Already held**: the staged bytes are deleted. When the ledger names content
  whose bytes are missing — a write that died between creating the content and
  moving its bytes in — this write's bytes are moved in instead, so the next
  write of the same content repairs the gap.

Then the key's `TomBlobLedgerEntry` is recorded: its owner, digest, content key,
size, media type, file name and write time. A failure at any point deletes the
staged bytes and rethrows, so a refused or broken write leaves neither a key nor
stored bytes behind.

Every other operation is answered by the ledger first:

| Operation | What happens |
| --------- | ------------ |
| `get` | One ledger lookup, then the content store's read of the content key; a byte range is passed through, so the content store's seek serves it |
| `describe` / `exists` | The ledger entry alone; `describe` always carries the digest |
| `copy` | A second ledger entry naming the same content, charged to the current owner — no bytes move |
| `move` | The entry renamed; its owner stays, and no bytes move |
| `delete` / `deletePrefix` | The ledger entries go; the content stays until a reclaim. `supportsPrefixDelete` is `true` over any content store, because the prefix is matched in the ledger (`tomBlobKeyUnder`, segment by segment) |

The two prefixes belong to the store: nothing else may write under them in the
content store, and they must not contain each other, which the constructor
refuses with an `ArgumentError` — staging inside the content area would make an
in-flight write look like content.

### The Ledger

| Part | One per | Holds |
| ---- | ------- | ----- |
| `TomBlobLedgerEntry` | logical key | its owner, content digest and content key, size, media type, file name, write time |
| `TomBlobContent` | distinct content (SHA-256) | the key the bytes are stored under, their size, when it was last claimed |

Many entries may name one content; that is the deduplication.
`TomMemoryBlobLedger` keeps both in memory — right for tests and a single
process whose content store is in memory too. `TomSqlBlobLedger` keeps them as
rows of two framework-owned tables in a `TomDataSource`:

| Table | Declared by | Key | Indexes |
| ----- | ----------- | --- | ------- |
| `tom_blob_ledger` | `blobLedgerTable` | `blob_key` | `(owner, stored_at)` for a quota's sum, `content_digest` for "does anything still name this content", `stored_at` for the orphan sweep |
| `tom_blob_content` | `blobContentTable` | `content_digest` | `claimed_at`, which the reclaim reads oldest first |

With `createSchema: true` (the default) the ledger creates both on first use;
otherwise the migration module owns them, and the reference migrations are
`example/file_storage/migrations/system/main/tomcore/[3]-create_tom_blob_ledger.sql`
and `[4]-create_tom_blob_content.sql` (PostgreSQL forms under
`migrations_postgresql/`). Both tables are listed by `frameworkOwnedTables`
(`blobLedger`, `blobContent`), so the framework schema check covers them.

Every check that protects content from a concurrent writer is **one statement**,
so it holds across processes sharing the database: a claim stamps
`claimed_at` before it reads the content row, and a drop deletes the row only
while no entry names it and nothing claimed it since the cutoff.

### Quota per Owner

Every write and copy is charged to an **owner**: the owner `runAs` names for the
work inside it, otherwise `ownerOf()` — by default `principalOwner`, the
qualified id of the principal in the current zone, or `''` when there is none.
`currentOwner()` answers which applies. A blob of owner `''` is no one's, and no
quota counts it.

A `TomBlobQuota` bounds each owner to `maxCount` blobs and `maxBytes` bytes;
either may be `null` for no bound. Usage is in **logical bytes**: an owner is
charged for every blob it holds, whether or not another key shares the content,
so what one owner may store never depends on what somebody else uploaded.

| When | What is checked |
| ---- | --------------- |
| Before a write | The count, and the bytes already held — so a full owner costs no upload |
| After the bytes have arrived | The bytes held plus the written size; past `maxBytes`, the staged bytes are deleted and nothing is recorded |
| Before a copy | The count, and the bytes held plus the source's size |

A write over a key the owner already holds replaces it, so it adds nothing to the
count and only the difference in size to the bytes. A refusal is
`storage.quota.count_exceeded` or `storage.quota.bytes_exceeded`, carrying the
owner, the count or bytes and the limit; both reach the caller as raised (see
[A Failure Is a Storage Error, Not the Backend's](#a-failure-is-a-storage-error-not-the-backends)).

The quota bounds an owner; it is not a reservation. The check reads the ledger
and then writes it, so two writes racing for the last of an owner's space can
both pass.

### Reclaim

Deleting a key removes its ledger entry and nothing else. Content no entry names
is deleted by `reclaim`, and only once nothing has **claimed** it — a write or a
copy naming it — for `reclaimGrace` (default one hour). The grace counts from the
content's last claim, not from the delete of its last key.

The reason is a race: a write of the same bytes in another process claims the
content before it records its key, so content deleted the moment its last key
went could be deleted under that write. With the grace, `reclaim` drops a
content's record first — only while it is still unnamed and unclaimed since the
cutoff — and deletes its bytes after, so a concurrent write either keeps the
content or, when the record is already gone, creates it anew under a **new**
content key, which a late delete of the old bytes cannot reach. Choose a grace
longer than the longest write.

`reclaim({now, batchSize})` works in batches of `batchSize` (default 500) and
answers how many contents it deleted. `reclaimJobDefinition()` is the same as a
`TomJobDefinition` named `tom.storage.reclaim`, hourly by default, for a
`TomScheduler` to run in its own isolate (`TomInlineJobDispatcher`), since its
body holds the store.

### Sweeping Keys No Row Names

A file is uploaded and then attached: the upload writes the blob, a later save
writes the row naming it. An upload whose row never comes leaves a key nothing
serves and nothing deletes. Over a plain store nothing can find those keys; over
a deduplicating store the ledger records every key, and the object-persistence
module's `TomBlobOrphanSweep` walks it, asks each `TomBlobReferenceSource` —
typically a `TomRepositoryBlobReferences` over an entity's `@TomFileReference`
columns — which keys a row refers to, deletes the rest once they are older than
its grace, and then runs `reclaim`. See
[Sweeping Files No Row Refers To](object_persistence.md#sweeping-files-no-row-refers-to)
in the object-persistence guide.

## A Failure Is a Storage Error, Not the Backend's

The faults that stop a store come from the layer underneath it and speak that
layer's language: a `FileSystemException` from the directory backend, a driver
error from the database one, an HTTP status from S3. A backend that lets those
through makes the caller's error handling depend on which backend it was
configured with — and slips past every `on TomServerException` between the store
and the request boundary, so the pipeline's generic handler is the first thing
that sees it.

So every failure is translated into four keys, one per operation:

| Key | Raised when |
| --- | ----------- |
| `storage.blob.write_failed` | Storing bytes under a key did not complete. |
| `storage.blob.read_failed` | The key holds a blob; reading its bytes failed. |
| `storage.blob.probe_failed` | `describe` or `exists` could not ask storage about the key. |
| `storage.blob.delete_failed` | The key holds a blob; removing it failed. |
| `storage.blob.copy_failed` | The source exists; putting it under the second key failed. |
| `storage.blob.move_failed` | The relocation failed. Because the destination commits first, the residue is a duplicate rather than a hole. |
| `storage.blob.prefix_delete_failed` | The reclaim of a key prefix failed. |

The division is by *what the caller asked for*, not by which call threw: a
sidecar that cannot be read during a `describe` is a probe failure even though a
file read is what failed.

The translating is `TomBlobStore`'s own, not each backend's. `put`, `get`,
`describe`, `exists`, `delete`, `deletePrefix`, `copy` and `move` are the
contract's methods; a backend
implements `doPut`, `doGet`, `doDescribe`, `doDelete` and lets its failures out
raw, and the wrapper around each names the operation. For `get` this covers the
whole transfer and not just its opening: a socket that dies after the first
megabyte is translated exactly as a connection that never opened is, which is
what lets each backend forward its underlying stream unguarded. That is also
where the key is validated, which is what makes the two guarantees hold for a
backend written later — the ones this module ships, and the ones an application writes. A
backend still raises a storage exception by hand where it knows something the
wrapper cannot: `storage.blob.not_found` for a key that holds nothing, and the
database backend's `storage.blob.missing_chunk` for a row whose parts are
incomplete.

The module's own answers pass through untranslated, because callers branch on
them. They are a closed list, `TomBlobStore.passThroughErrorKeys`:

| Key | Why it is an answer rather than a failure |
| --- | ---------------------------------------- |
| `storage.blob.not_found` | The key holds nothing. `TomBlobExportStore` re-reports it as `export.store.not_found`; the file endpoint turns it into a 404. |
| `storage.blob.invalid_key` | The key is not a key — the caller's mistake, and the same one on every backend. |
| `storage.blob.invalid_key_prefix` | The key is fine and the deployment's configured prefix leaves no room for it. A different fault from the one above, calling for a different action. |
| `storage.blob.missing_chunk` | The blob is there and its parts do not add up. |
| `storage.blob.same_key` | A copy or move named one key twice. A caller's mistake, refused before any backend is touched. |
| `storage.blob.prefix_delete_unsupported` | The backend cannot reclaim by prefix, and says so rather than answering `0`. Ask `supportsPrefixDelete` first. |
| `storage.quota.count_exceeded` | A `TomDeduplicatingBlobStore` refused the write or copy: its owner already holds `TomBlobQuota.maxCount` blobs. The caller's answer is to delete one, not to retry. |
| `storage.quota.bytes_exceeded` | The same for `TomBlobQuota.maxBytes`: the owner's blobs would total more than the space allowed. |

`storage.blob.invalid_range` is the same shape one step earlier: a `TomBlobRange`
with a negative start, or an end at or before it, is refused by its own
constructor, so no backend ever sees one. An empty range is refused rather than
answered with an empty stream — a zero-length read is a caller's arithmetic going
wrong, and an empty body is how that reaches a user as a corrupt download.

Everything else is wrapped, and the original fault kept as `rootException`: the
caller needs a key it can branch on, whoever reads the log needs the `errno`
that explains it.

**Everything else includes a backend's own storage exceptions.** The match is on
the key, not on the type, and that distinction is the whole of the guarantee.
`TomStorageException` is also what a backend raises its *own* failures as, so a
translation that let the type through let `storage.s3.request_failed` and its
siblings through with it — and a caller switching on `error.key` then saw one
key when the deployment was configured with S3 and another when it was
configured with the directory backend, for the same fault. The S3 status and
code are not lost: they are on the `rootException`, where an operator reading
the log still has them and a caller is no longer written against them.

The list is closed by a rule rather than by taste. Every key on it is raised by
code every backend shares, or enforces a limit every backend is held to —
`invalid_key_prefix` is raised inside the S3 backend as well as by
`validateKeyPrefix`, and belongs here because the limit it enforces is
`TomBlobStore.maxKeyLength` rather than S3's own, which is twice as large. A
backend cannot add to the list, which is what makes the guarantee hold for a
backend an application writes later.

One of the four keys is unreachable on one backend, and it is worth knowing
which. The directory backend's `exists` never reports
`storage.blob.probe_failed` — not because it is exempt from the wrapper but
because it hands the wrapper nothing to translate. `dart:io`'s `File.exists`
answers from a `stat` and turns every failure of that `stat` — a
permission-denied parent directory, a symlink loop, a dead NFS mount — into a
plain `false`. There is no exception, and no errno exposed that would let one be
reconstructed. So on that backend `exists` answers "visible to this process"
rather than "present in storage", and a caller that must tell an unreadable blob
from an absent one should ask `describe`, which reaches real I/O and does report
the failure.

The same four operations exist in the export module as
`TomExportStoreOperation`. That is deliberate — the same questions are being
asked of the same kinds of infrastructure, and two different answers for one
fault would be an accident of which module the caller came through.

### `key` Is the Caller's Key, on Every Error

Every storage exception this module raises carries a `key` parameter, and it is
always **the key the caller passed** — never a path, a URL, a row id or a file
name derived from it. The parameter is a contract rather than a label. A handler
that logs `parameters['key']`, or renders it into a message, has no way to know
that one backend meant something else by it; a value the caller never supplied
and cannot look up is worse than no value at all.

That matters most where a key is decorated on the way to storage. Under a
`keyPrefix` the S3 backend's request path is `/bucket/prefix/key` — in a
multi-tenant deployment the prefix *is* the tenant and the bucket is
infrastructure detail, both of them travelling inside an error a server may
surface.

Backends do report where a request actually went, under names that say so. The
S3 backend's `storage.s3.request_failed` — which a caller meets as the
`rootException` of one of the four operation keys, never as its own key —
carries:

| Parameter | Meaning |
| --------- | ------- |
| `key` | The caller's key. |
| `objectPath` | The full request path, bucket and prefix included. |
| `operation` | The store operation — `put`, `get`, `describe`, `delete`, `uploadPart`, `createMultipartUpload`, `completeMultipartUpload`, `abortMultipartUpload`. |
| `status` | The HTTP status the store answered. |
| `code`, `message` | The store's own error code and text, when it sent one. |

`objectPath` exists because these errors are logged (`autoLog: true`), and which
bucket and prefix a request was rejected from is exactly what the operator
reading that log needs. The separate name is the point: code that renders
parameters wholesale is then visibly opting into infrastructure detail, rather
than being handed it by a field called `key`.

`operation` names the *store* operation, not the HTTP verb. A multipart upload
issues four different requests and three of them are `POST` or `PUT`, so the
verb cannot say which one stopped.

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
  chunkSize: 65536

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

One entry may carry `default: true`; when the configuration names exactly one
store it becomes the default without saying so, because a server with one place
to put files has no ambiguity to resolve. Asking for a default nothing supplied
raises `storage.registry.no_default_store`, and `storeNamed` with a name no
entry has raises `storage.registry.unknown_store`; both list the stores that are
configured.

That count is over the entries the call registered, not over every store the
process happens to hold. An application that builds a store in code first — a
scratch area, a test double, an application-specific archive — and then reads
its real configuration still gets the implicit default, because the rule is
about what the configuration says. A default nominated in code with
`register(..., asDefault: true)` survives, though: that is a statement, and the
single-store rule is an inference drawn when nothing was stated. A `default:
true` in the configuration does displace it, being a statement of its own and a
later one.

Every setting a backend does not require is optional, and each omitted one falls
back to its field's initialiser, which reads the declaration that owns it — `defaultBlobManifestTable` and
`defaultBlobChunkTable` for the database backend's two tables,
`TomDatabaseBlobStore.defaultChunkSize` and `TomS3BlobStore.defaultPartSize` for
the two sizes. The fields read those constants rather than restating their
values, so a rename or a retune reaches the configured path along with every
other one. That matters more here than it looks: the tables are also the ones
the migration module's convergence check compares against, and a configured
store that had drifted to an old name would be checked against a schema it no
longer used.

### Every Setting Has to Bind

A backend is a `TomBlobStoreBackend` class, and its settings are its fields.
`open()` creates a fresh backend for the store, removes the registry's own keys
(`TomBlobStoreInfo.registryKeys`: `type` and `default`), and then holds every
remaining key to the backend's field set: a key that names no field fails the
start-up with `storage.registry.unknown_setting`, whose `parameters` give the
store under `store` and every offending key under `keys`:

```text
File store 'attachments' (type 'database') is configured with settings
'createSchma', 'chunk_size' that name no field of TomDatabaseBlobStoreBackend.
Check the spelling in the file-store configuration for 'attachments'.
```

Absorbed, a misspelt key is read by nobody, and the default it meant to change
stands with nothing to say so — `createSchma: false` creates the tables anyway,
in a schema a migration was supposed to own. It is the rule
[datasources](datasources.md#every-settings-key-has-to-bind) applies to a driver,
derived the same way: the field set is read off the backend through reflection,
so a backend the framework never saw is checked against its own settings.

The keys that bind are then written onto the fields. A value its field cannot
take — `chunkSize: large` — is `storage.registry.invalid_setting`, naming the
setting. The `int` settings, `chunkSize` and `partSize`, also accept a string
holding a number, which is what an environment substitution produces; a backend
of an application's own gets the same through `normalize`.

An application with a backend of its own declares it as such a class and
registers a factory for it, after which a configuration spells it like any
built-in:

```dart
@tomReflector
class GcsBlobStoreBackend extends TomBlobStoreBackend {
  GcsBlobStoreBackend(this._client);
  final http.Client _client;

  String bucket = '';          // a setting: required
  String location = 'EU';      // a setting: optional

  @override
  TomBlobStore build(String name) {
    if (bucket.isEmpty) throw TomBlobStoreBackend.missingSetting(name, 'bucket');
    return GcsBlobStore(_client, bucket: bucket, location: location);
  }
}

TomBlobStoreInfo.registerBackend('gcs', () => GcsBlobStoreBackend(httpClient));
```

What is not a setting — the HTTP client here — is a constructor argument the
factory captures. The class has to be in the application's generated
reflection, because that is where its fields are read from; a backend that is
not is refused as `storage.registry.backend_not_reflected` rather than built
with every field at its default, which would be the silent drop over again.

`TomBlobStoreInfo.register(name, store, asDefault: true)` is the seam for a test
or for an application that builds its store in code. Such an entry records
`TomBlobStoreInfo.providedType` and keeps the instance it was handed, so
reopening it after a `closeAll` hands back the store it was given: the registry
cannot rebuild an instance it did not build, and `close()` is idempotent by
contract.

The provided type is not itself a registered backend, and `backendTypes` does
not list it. It names how the store arrived rather than a way to build one, and
there is no instance in a YAML file to hand over, so a configuration naming it
fails like any other unknown type.

### An Entry Exists Before Its Store Does

`TomBlobStoreInfo(name, settings)` constructs an entry; `open()` builds its
store. Every configured entry passes through the interval between the two, and
an `open()` that throws — an unregistered backend
(`storage.registry.unknown_backend`), a missing required setting such as a
directory store's `root` or a database store's `datasource`
(`storage.registry.missing_setting`), a key no field of the backend reads
(`storage.registry.unknown_setting`) — leaves an
entry sitting in it. Reading `store` there raises
`storage.registry.store_not_opened`, naming the store and its configured type,
and `isOpen` answers the same question without throwing.

`toString()` renders such an entry as `TomBlobStoreInfo files directory
<unopened>` — the shape is the same three segments either way. That matters more
than it sounds: an unopened entry is most often seen in a debugger's variable
pane or inside the error report about the very `open()` that failed, which is
the worst possible moment for rendering it to be what throws.

## File-Reference Columns

A `@TomFileReference` column holds a storage key. The row stays small enough to
select, diff, audit and mask like any other; the payload never passes through
SQL.

```dart
@tomReflector
@TomDbTable(datasource: 'main', table: 'document', primaryKeyFields: ['id'])
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
| `keyPrefix` | The leading segment of every generated key — the partition a retention rule addresses. Held to the [prefix grammar](#prefixes-obey-the-same-grammar) |
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
collision-free. The prefix is validated first and the assembled key second, so a
bad `keyPrefix` is reported as a bad *prefix* — the thing a developer can go and
fix — rather than as an invalid key that is mostly a UUID.

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

```text
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
| `GET` | — | `200` + bytes + descriptor headers, or `206` for a range | `404` |
| `HEAD` | — | `200` + descriptor headers | `404` |
| `DELETE` | — | `204` | `404` |

The descriptor is
`{"key", "mediaType", "byteCount", "fileName"?, "storedAt"?, "digest"?}`.
`storedAt` is always UTC and therefore always carries the zone marker on the
wire — `TomStoredBlob` normalises it whatever backend produced it, so a client
never has to guess which server's local zone an instant was read in. Note that
the client never names a key: the server mints it from the column's
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

#### ETag and If-None-Match

`GET` and `HEAD` carry the blob's digest as a **strong** `ETag` — quoted, with
no `W/` prefix, because the digest identifies the bytes exactly, which is what
makes a conditional range request legal against it. A blob with no recorded
digest carries no `ETag` and so has no validator; the bytes are served.

`If-None-Match` is answered with `304` and no body. The comparison is the weak
one the header specifies, so `W/"…"` matches too — a cache is entitled to send
back a tag it weakened — and `*` matches anything that exists.

**The condition is answered before `Range`**, which is RFC 9110's ordering and
not a detail: a client resuming a download it turns out already holds in full
must get a `304`, not a `206` carrying bytes it did not need. It is also
answered before anything is read, so a conditional request the caller already
satisfies costs one `describe`.

The `304` drops `Content-Length` rather than setting it to `0`: the header
describes the representation, and a zero there tells a cache the resource is
empty.

#### Range

`GET` and `HEAD` both answer `Accept-Ranges: bytes`. Without it a browser does
not attempt a partial request at all, so the backends' seeking would never be
reached from the wire — and `HEAD` is where a client planning a resumable
transfer reads it, along with the size.

A `GET` carrying `Range` is answered `206` with `Content-Range` and a
`Content-Length` of the slice. All three forms are understood, resolved against
the size the descriptor already gives:

| Header | Means | On a 1,000-byte file |
| ------ | ----- | -------------------- |
| `bytes=100-199` | the hundred bytes at 100 | `206`, `Content-Range: bytes 100-199/1000` |
| `bytes=900-` | from 900 to the end | `206`, `bytes 900-999/1000` |
| `bytes=-100` | the **last** hundred bytes | `206`, `bytes 900-999/1000` |
| `bytes=990-2000` | past the end — **clamped** | `206`, `bytes 990-999/1000` |
| `bytes=1000-` | at or past the end | `416`, `Content-Range: bytes */1000` |

The distinction in the last two rows is the one that matters. A range that
overshoots is how a resumed download ends, and refusing it would make the last
request of every resume a failure; a range that *starts* at or past the end
names no byte at all, and the `416` carries `bytes */1000` so a client resuming
from a stale size learns the current one instead of looping. Its body is the
usual `{"key", "message"}`, keyed `file_endpoint.range_not_satisfiable`.

Anything else — more than one range, a unit other than `bytes`, a backwards or
unparsable header — is **ignored**, and the whole file is served with a `200`.
RFC 9110 permits exactly that, and it is the right trade here: a
`multipart/byteranges` body is a second wire format for a case no browser needs,
and refusing a header merely not understood would break a download that would
otherwise have worked.

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

The adaptor is documented here because this is where its backends are, but it is
**not this module's class** — it is declared in `lib/src/tomserver/export/`, and
this module does not know the export module exists. Its tests are in
`test/export_test.dart` accordingly, beside the two export backends it is
interchangeable with. What stays here is the one claim that is about the two
modules *agreeing*: an export key and a blob key are one grammar in two
vocabularies, and the grammar is defined here, so `test/file_storage_test.dart`
pins `TomExportStore.validateKey` against `TomBlobStore.validateKey`.

## Verification

Five suites cover this module, split by what each needs.

`test/file_storage_test.dart` always runs and covers the contract every backend
shares — the key grammar, the refusal of an invalid key on every method of every
backend, an infrastructure failure named as a storage error rather than escaping
as a raw `FileSystemException`, `storedAt` reported as UTC by all of them, and
the property the whole abstraction exists for, that one key cannot reach
another. On top of that it covers the two backends needing no infrastructure
(`TomMemoryBlobStore`, `TomDirectoryBlobStore`), the parts of
`TomDatabaseBlobStore` that need no database, `TomAwsV4Signer`, `TomS3BlobStore`
and the `TomBlobStoreInfo` registry with its configuration.

`test/file_storage_schema_test.dart` is a reading of the source tree: the
migration files match the shipped DDL, and the blob schema encodes what the
store relies on.

`test/file_storage_db_test.dart` is tagged `db` and skips when no server is
reachable. It covers what only a database can settle: `TomDatabaseBlobStore`
with and without `createSchema`, a store built from configuration,
file-reference columns end to end, and blob access under a C-4 grade and under a
row scope — the two authorization rules that decide whether bytes may move at
all.

`test/deduplicating_blob_store_test.dart` always runs and covers
`TomDeduplicatingBlobStore` over three content stores — memory, directory, and S3
through the in-process `test/fixtures/fake_s3_server.dart` — with
`TomMemoryBlobLedger`: one copy per content, copies that move no bytes, a failed
upload leaving nothing behind, the reclaim and its grace, content stored again
under a new key, the per-owner quota, the orphan sweep and its refusals, a
repository as a reference source, and both jobs on a scheduler.

`test/deduplicating_blob_store_db_test.dart` is tagged `db` and skips when no
server is reachable. It covers `TomSqlBlobLedger` against MariaDB or PostgreSQL
— its tables, a claim protecting content from a reclaim that read it earlier,
the quota's sum, the sweep's paging — and the orphan sweep over a real
repository's file columns, with a directory as the content store.

```bash
dart run example/file_storage/file_storage_example.dart
dart run example/file_storage/deduplicating_store_example.dart
```

`example/file_storage/file_storage_example.dart` demonstrates the whole
capability with no database, bucket or credential. The thing to watch for is
what is *absent*: at no point is a whole file held, and step 3 proves it — a
payload larger than any buffer in the program arrives as a sequence of chunks,
and the count of them is the assertion. Every step checks its own result, and
`test/examples_test.dart` runs it.

`example/file_storage/deduplicating_store_example.dart` puts a
`TomDeduplicatingBlobStore` in front of a directory and walks six steps: the
same bytes under two keys stored once, a copy that moves no bytes, each owner
charged in logical bytes, a write past the quota refused without residue, an
orphan sweep deleting the one key no row names, and a reclaim that deletes the
content only once the grace after its last claim has passed. It checks its own
results the same way.

## Core Components

- **`TomBlobStore` / `TomStoredBlob` / `TomStorageException`** — the contract,
  its descriptor, and the module's error.
- **`TomMemoryBlobStore` / `TomDirectoryBlobStore` / `TomDatabaseBlobStore` /
  `TomS3BlobStore`** — the four shipped backends.
- **`TomAwsV4Signer` / `TomAwsCredentials`** — SigV4 signing for the S3 backend.
- **`TomAwsCredentialsSource`** — the credentials of each signed request, from a
  function; the shape `tom_core_secrets`' AWS provider and
  `tom_core_message_bus_aws` take.
- **`TomBlobStoreInfo` / `TomBlobStoreBackend`** — the configured registry, and
  the backend classes whose fields are a store's settings; the four built-ins
  and an application's own, registered through a `TomBlobStoreBackendFactory`.
- **`blobManifestTable` / `blobChunkTable`** — the database backend's two table
  descriptors, from which its DDL and its statements are derived.
- **`TomDeduplicatingBlobStore`** — one copy per content over any backend, a
  per-owner `TomBlobQuota`, and the `reclaim` of content no key names.
- **`TomBlobLedger` / `TomMemoryBlobLedger` / `TomSqlBlobLedger`** — the record
  of keys, owners and contents that store keeps (`TomBlobLedgerEntry`,
  `TomBlobContent`, `TomBlobUsage`), and `blobLedgerTable` / `blobContentTable`,
  the SQL ledger's two table descriptors.
- **`TomFileReference` / `TomFileReferenceKeys`** — the column annotation, its
  key scheme, and store resolution.
- **`TomSqlDatasourceRepository.saveFile` / `.openFile` / `.describeFile` /
  `.clearFile`** — the entity-level file API and its cascade.
- **`TomFileRepository`** — the five-method contract those four satisfy: the four
  above plus `findById`, because the endpoint has to load the row before it can
  move any bytes. Named separately so the HTTP endpoint depends on the capability
  rather than on the SQL implementation.
- **`TomFileSlots` / `TomFileSlot`** — the reflection-derived slot registry:
  `register(repository)` publishes an entity's `exposed` file columns as
  `<table>/<column>`, and `resolve` finds one.
- **`TomFileEndpoint` / `TomFileService` / `TomFileServer`** — the shipped HTTP
  handler and the reflected service that mounts it at
  `/files/{entity}/{id}/{column}`.
- **`TomBlobExportStore`** — the export module's adaptor.

## Not Yet Implemented

- **Deduplication on a plain backend.** The four backends store every `put` as
  its own blob, whatever its digest; only a `TomDeduplicatingBlobStore` in front
  of one shares content between keys. See
  [Deduplication, Quota and Reclaim](#deduplication-quota-and-reclaim).
  <!-- unpinned: decision — deduplication is the deduplicating store's, not every backend's -->
- **Finding what the rows do not claim, on a plain store.** `TomBlobMigration`
  moves every blob a row points at; a blob no row names is invisible to it, and
  to anything else over a plain backend — finding one means enumerating the
  store, which the contract refuses. The report names what it claimed, and a
  deployment diffs that against its old backend with that backend's own
  tooling. A deduplicating store's ledger records every key, which is what
  `TomBlobOrphanSweep` walks. See
  [Migrating Between Backends](#migrating-between-backends).
  <!-- unpinned: absence — a plain store keeps no record of its keys -->
- **A quota on a plain store, and a schedule.** Only a
  `TomDeduplicatingBlobStore` refuses a write past a `TomBlobQuota`; over a plain
  backend the ceiling is the deployment's, for the reason
  [Quota and Expiry](#quota-and-expiry) gives. Nothing in this module runs a
  purge, a reclaim or a sweep on a timer by itself: the jobs are described, and a
  deployment registers them.
  <!-- unpinned: absence — the plain backends keep no per-owner record, and no job is registered by the module -->
- **A quota is not a reservation.** The check reads an owner's usage and then
  writes, so two writes racing for the last of an owner's space can both pass
  and leave the owner over its limit by the second.
  <!-- unpinned: untestable — a race between two writers -->
- **Staged bytes of a process that died mid-write.** A deduplicating store moves
  or deletes a staged write before it returns; a process that dies in between
  leaves the staged bytes under `stagingPrefix`, which nothing records and so
  nothing reclaims. On a content store that supports it, `deletePrefix` of that
  prefix while no write is in flight removes them.
  <!-- unpinned: untestable — a process dying mid-write -->
- **Bytes left behind by a failed reclaim.** `reclaim` drops a content's record
  before deleting its bytes; when the delete then fails, the bytes are left
  unreachable rather than referenced, and are not retried.
  <!-- unpinned: untestable — a content-store delete failing after the record went -->

## Dependencies

| Dependency | Kind | Imported by | For |
| ---------- | ---- | ----------- | --- |
| `dart:async` | dart | `blob_store.dart`, `blob_store_backends.dart`, `database_blob_store.dart`, `deduplicating_blob_store.dart`, `directory_blob_store.dart`, `s3_blob_store.dart` | `Future`, `FutureOr`, `Stream`, `runZoned` for `runAs` |
| `dart:convert` | dart | `aws_v4_signer.dart`, `blob_store.dart`, `database_blob_store.dart`, `directory_blob_store.dart`, `s3_blob_store.dart` | `base64`, `jsonDecode`, `jsonEncode`, `utf8` |
| `dart:io` | dart | `blob_store_backends.dart`, `directory_blob_store.dart` | `File` / `Directory` for the directory backend |
| `dart:typed_data` | dart | `blob_store.dart` | `Uint8List` |
| `crypto` | package | `aws_v4_signer.dart`, `blob_store.dart`, `s3_blob_store.dart` | HMAC-SHA256 and SHA-256 for SigV4; the chunked SHA-256 behind `TomBlobDigest`; the MD5 S3 requires on a `DeleteObjects` body |
| `http` | package | `s3_blob_store.dart` | the S3 backend's transport (injectable, so it is mockable) |
| `path` | package | `directory_blob_store.dart` | key-to-path joining in the directory backend |
| `tom_core_kernel` | package | `blob_ledger_sql.dart`, `blob_store_backends.dart`, `blob_store_registry.dart`, `database_blob_store.dart`, `deduplicating_blob_store.dart`, `s3_blob_store.dart` | `TomServerException` by way of `TomStorageException`, `tomLog`, and the `TomAuthState` grades the C-4 gate reads; `@tomReflector` and `tomReflectionInfo`, through which a backend's settings are checked against its fields and bound onto them; `TomResilientClient`, the S3 store's default client; `TomPrincipal`, the default owner of a deduplicating store's write; `TomJobDefinition` and `TomCommand` for the reclaim job |
| `uuid` | package | `database_blob_store.dart`, `deduplicating_blob_store.dart` | key generation, the database backend's upload ids, and a deduplicating store's staging and content keys |
| [datasources](datasources.md) | module | `blob_ledger_sql.dart`, `database_blob_sql.dart`, `database_blob_store.dart` | `TomDataSource` for the database backend and the SQL ledger; `TomFrameworkTable` and `sqlInstant` for their tables |
| [little_things](little_things.md) | module | `blob_store.dart` | `TomServerException` |
| [object_persistence](object_persistence.md) | module | `blob_ledger_sql.dart`, `database_blob_store.dart` | `TomColumnInformation` and `TomAnnotationAnalyzer` for resolving file columns; `TomSqlDatasourceRepository` for the entity API; `TomDbTable` and `TomDbColumn` on the SQL ledger's row types |
| [tenancy](tenancy.md) | module | `database_blob_store.dart` | `TomTenantData`, so a purged tenant's blobs are deleted |
