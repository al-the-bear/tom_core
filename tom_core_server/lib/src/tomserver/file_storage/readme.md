# file_storage

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

One streaming contract for storing bytes by key, over four backends that need
nothing in common.

The thing to watch for is what is **absent**: at no point is a whole file held.
`put` takes a stream and `get` returns one, so a payload larger than any buffer
in the process moves through in chunks — which is what lets the same four
methods serve a 2 KB avatar and a 2 GB export without the caller choosing.

A key is the whole of a blob's identity, so the **key grammar** is a security
boundary rather than a convention: `../` and absolute paths are refused by every
backend on every method, because one key must not be able to reach another.

## Key types

### The contract

| Type | What it is |
| ---- | ---------- |
| `TomBlobStore` | `put` / `get` / `describe` / `exists` / `delete` / `deletePrefix` / `copy` / `move`, by key. The whole surface. `get` takes an optional byte range; the default reads from zero and discards the prefix, so no backend is obliged to implement two read paths — and all four override it, because all four can seek. `copy` and `move` have the same shape: a stream round trip by default, and a native relocation on every backend — a rename, a map entry, a manifest row against the same chunks, `x-amz-copy-source`. `deletePrefix` is the reclaim a deployment's retention pass is built on — the one operation its own record of what it stored cannot assemble from outside. |
| `TomBlobRange` | A half-open `[start, endExclusive)` of a blob. There is no listing and no offset arithmetic to get wrong: both ends are checked once, on the contract. |
| `TomStoredBlob` | What was stored: key, media type, `byteCount`, `storedAt` (always UTC), the SHA-256 `digest` of the content, and an optional file name. |
| `TomBlobDigest` | The running SHA-256 a backend feeds while it writes, so the hash costs the pass it is already making rather than a second read. |
| `TomBlobStoreOperation` | What the caller asked for when a store failed — `write` / `read` / `probe` / `delete` / `deletePrefix` / `copy` / `move` — each carrying a stable error key. |
| `TomStorageException` | The module's base error. An infrastructure failure is named as a storage error rather than escaping as a raw `FileSystemException` or driver error. |

### The backends

| Type | What it is |
| ---- | ---------- |
| `TomMemoryBlobStore` | A map. Tests and single-process development. |
| `TomDirectoryBlobStore` | A directory tree. Writes to a `.partial` sibling and renames, so a reader never meets a half-written blob. |
| `TomDatabaseBlobStore` | The bytes in the database itself, as a manifest row plus chunk rows — `blobManifestTable` and `blobChunkTable` declare the two tables, `blobManifestTableDdl` and `blobChunkTableDdl` render them. No new infrastructure: no bucket, no shared mount, no extra credential. Both are system tables; the manifest records each blob's tenant, and `keysOfTenant` lists one tenant's blobs. |
| `TomS3BlobStore` | S3 and anything speaking its API. `TomAwsV4Signer` and `TomAwsCredentials` sign the requests, so the store needs no AWS SDK; `TomAwsCredentialsSource`, declared beside them, supplies each request's credentials to the other signing clients — `tom_core_secrets`' AWS provider and `tom_core_message_bus_aws`. Its default client is the kernel's `TomResilientClient`, so every request runs under the object store's timeout, retry, circuit-breaker and bulkhead policies (the server's `httpClient` key). |

### Deduplication, quota and reclaim

| Type | What it is |
| ---- | ---------- |
| `TomDeduplicatingBlobStore` | A `TomBlobStore` in front of any other one (the *content store*). A write streams into a staging key while its SHA-256 is computed and then becomes the content for that digest, or is discarded when the content is already held, so every key naming the same bytes shares one stored copy and a `copy` moves no bytes. With a `TomBlobQuota` each write and copy is charged to its owner — the principal in the zone, or the owner `runAs` names. Deleting a key removes its ledger entry; `reclaim` (also the job `tom.storage.reclaim`) deletes content no key names once nothing has claimed it — by a write or a copy — for `reclaimGrace`. |
| `TomBlobLedger` · `TomMemoryBlobLedger` · `TomSqlBlobLedger` | The record such a store keeps beside the bytes, since a blob store cannot list itself: one `TomBlobLedgerEntry` per logical key (owner, digest, content key, size) and one `TomBlobContent` per distinct content (where it is stored, when it was last claimed). The SQL ledger keeps them in `tom_blob_ledger` and `tom_blob_content`, declared by `blobLedgerTable` and `blobContentTable` and rendered by `blobLedgerTableDdl` and `blobContentTableDdl`; `TomBlobLedgerEntryRow`, `TomBlobContentRow`, `TomBlobUsageRow` and `TomBlobReferenceCountRow` are its reflected row types. `tomBlobKeyUnder` is the segment-wise prefix match every ledger uses. |
| `TomBlobQuota` · `TomBlobUsage` | At most `maxCount` blobs and `maxBytes` bytes per owner, charged in logical bytes — a shared content counts for every owner holding it. A full owner is refused before any upload (`storage.quota.count_exceeded`, `storage.quota.bytes_exceeded`). |

Which keys no row refers to — the orphan sweep — is the object-persistence
module's `TomBlobOrphanSweep`, which walks this ledger.

### The registry

| Type | What it is |
| ---- | ---------- |
| `TomBlobStoreInfo` | The process-wide registry of named, configured stores — the same shape `TomDataSourceInfo` has, so an application that can configure a data source can configure a file store. |
| `TomBlobStoreBackend` | A backend: its settings declared as fields, and the store they build. A settings key that names no field of the backend is refused at start-up (`storage.registry.unknown_setting`), naming the store and the key. The four built-ins are `TomMemoryBlobStoreBackend`, `TomDirectoryBlobStoreBackend`, `TomDatabaseBlobStoreBackend` and `TomS3BlobStoreBackend`; a deployment's own registers a `TomBlobStoreBackendFactory`, which can capture what is not a setting — a configured HTTP client — and pass it to the constructor. |

## Quick start

```dart
import 'dart:convert';
import 'package:tom_core_server/tom_core_server.dart';

Future<void> main() async {
  final store = TomMemoryBlobStore();

  final stored = await store.put(
    key: 'invoices/2026/42.txt',
    bytes: Stream.value(utf8.encode('total: 19.99')),
    mediaType: 'text/plain',
  );
  print(stored.byteCount); // 12

  final bytes = <int>[];
  await for (final chunk in store.get(stored.key)) {
    bytes.addAll(chunk);
  }
  print(utf8.decode(bytes)); // total: 19.99
}
```

See [`doc/file_storage.md`](../../../../doc/file_storage.md) for the full
treatment: the key grammar, what happens to the bytes when the row changes,
serving a file over HTTP, and how exports ride the same API.
`example/file_storage/file_storage_example.dart` runs the whole capability with
no database, bucket or credential; `test/file_storage_test.dart` and
`test/file_storage_schema_test.dart` cover it without a server, and
`test/file_storage_db_test.dart` covers the database backend against a live
MariaDB or PostgreSQL. `example/file_storage/deduplicating_store_example.dart`
walks deduplication, quota, reclaim and the orphan sweep;
`test/deduplicating_blob_store_test.dart` covers the deduplicating store over
the memory, directory and S3 backends without a server (S3 through the
in-process `test/fixtures/fake_s3_server.dart`), and
`test/deduplicating_blob_store_db_test.dart` covers the SQL ledger and the
orphan sweep over a real repository against a live MariaDB or PostgreSQL.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
