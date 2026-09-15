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
| `TomBlobStore` | `put` / `get` / `describe` / `exists` / `delete` / `copy` / `move`, by key. The whole surface. `get` takes an optional byte range; the default reads from zero and discards the prefix, so no backend is obliged to implement two read paths — and all four override it, because all four can seek. `copy` and `move` have the same shape: a stream round trip by default, and a native relocation on every backend — a rename, a map entry, a manifest row against the same chunks, `x-amz-copy-source`. |
| `TomBlobRange` | A half-open `[start, endExclusive)` of a blob. There is no listing and no offset arithmetic to get wrong: both ends are checked once, on the contract. |
| `TomStoredBlob` | What was stored: key, media type, `byteCount`, `storedAt` (always UTC) and an optional file name. |
| `TomBlobStoreOperation` | What the caller asked for when a store failed — `write` / `read` / `probe` / `delete` / `copy` / `move` — each carrying a stable error key. |
| `TomStorageException` | The module's base error. An infrastructure failure is named as a storage error rather than escaping as a raw `FileSystemException` or driver error. |

### The backends

| Type | What it is |
| ---- | ---------- |
| `TomMemoryBlobStore` | A map. Tests and single-process development. |
| `TomDirectoryBlobStore` | A directory tree. Writes to a `.partial` sibling and renames, so a reader never meets a half-written blob. |
| `TomDatabaseBlobStore` | The bytes in the database itself, as a manifest row plus chunk rows — `blobManifestTable` and `blobChunkTable` declare the two tables, `blobManifestTableDdl` and `blobChunkTableDdl` render them. No new infrastructure: no bucket, no shared mount, no extra credential. |
| `TomS3BlobStore` | S3 and anything speaking its API. `TomAwsV4Signer` and `TomAwsCredentials` sign the requests, so the store needs no AWS SDK. |

### The registry

| Type | What it is |
| ---- | ---------- |
| `TomBlobStoreInfo` | The process-wide registry of named, configured stores — the same shape `TomDataSourceInfo` has, so an application that can configure a data source can configure a file store. |
| `TomBlobStoreFactory` | How a backend is built from its settings. A closure rather than an annotation, so a deployment's own backend can capture a configured HTTP client or an existing credential provider, and needs no reflection regeneration to be visible. |

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
MariaDB.

---

Part of [`tom_core_server`](../../../../README.md) — see the package README for
installation, the full module map, and ecosystem context.
