# tom_core_storage

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and internal (`publish_to: none`).

Storage for Tom applications — a compare-and-swap storage port, keyed file
media, a device-local cache and a durable offline commit journal — with the
local filesystem, a GitHub repository, the browser and the cache cipher behind
entry points of their own.

## Overview

An application keeps its documents in **containers**: a single file, or a
directory of files. Every backend answers the same port, `TomStorage`:
list a container, read its bytes or its files, and **commit** a changeset
against the head the caller last saw. A commit whose expected head is no
longer the container's head is refused with `TomCasConflictException`, so two
writers can never overwrite each other silently; the caller re-reads, merges
and commits again.

Around the port sit the parts every application with remote documents needs:

- **Media.** A `TomBundleMedium` is a keyed file store — read, write, list,
  delete, move — whose writes are atomic by contract. A store that writes to a
  medium never learns where the files go: `TomRecordingBundleMedium` turns its
  writes into one `TomChangeset` for a commit.
- **A cache.** `TomStorageCache` keeps what a backend has read, keyed by
  content, so an unchanged container is served from the device and an
  unreachable backend can still be read offline.
- **Assets.** `TomAssetStore` files bytes under their SHA-256, deduplicates
  them, verifies them on first read, and resolves a reference as live, from
  the container's history area, or missing; `TomAssetBundleLayout` keeps it in
  a medium as `assets/<id>.<ext>` with an append-only history folder.
- **An offline journal.** `TomCommitJournal` queues commits that could not be
  delivered; `TomMediumCommitJournal` keeps them in a medium, so they survive
  the process.
- **Policies.** Object ceilings, Git-LFS pointer refusal, access tokens,
  rate-limit kinds and backoff waits.

## Installation

The package is consumed by path inside this workspace:

```yaml
dependencies:
  tom_core_storage:
    path: ../../tom_ai/core/tom_core_storage
```

Dart SDK `^3.10.0`. No Flutter dependency.

## Features

| Type | What it does |
| ---- | ------------ |
| `TomStorage` | The port: `list`, `readBytes`, `readBundle`, `commit` against an expected head, `delete`, `headOf`, `headsOf`. |
| `TomChangeset` | One commit's writes and deletes; `singleFile` for a container that is one file. |
| `TomBundleMedium` | A keyed file store with atomic writes; `TomMemoryBundleMedium`, `TomReadOnlyBundleMedium`, `TomRecordingBundleMedium`. |
| `TomStorageCache` | A device-local cache over any storage, with a quota and optional sealing. |
| `TomAssetStore` | A content-addressed asset store over the asset types an application accepts (`TomAssetTypes`): ingest under a size ceiling, live / historical / missing resolution, revive after an undo, copy between stores. |
| `TomAssetBundleLayout` | Assets in a medium: `assets/<id>.<ext>`, an append-only history folder, and the metadata map a manifest carries. |
| `TomCommitJournal` | A durable queue of undelivered commits; `TomMemoryCommitJournal`, `TomMediumCommitJournal`. |
| `TomObjectCeiling` | The largest object a commit may carry: the tighter of a configured and a backend limit. |
| `TomLfsPointer` | Recognises a Git-LFS pointer, so a backend refuses it by name instead of delivering 130 bytes as content. |
| `TomTokenSource` | Where a remote backend's access token comes from. |
| `TomLocalFileSystemStorage` | The local filesystem (`io.dart`): atomic multi-file commits through staged temps and a recorded intent. |
| `TomGitHubStorage` | A GitHub repository (`github.dart`): one save is one commit, compare-and-swap on the branch head, conditional reads, rate-limit waits, LFS refusal, progress per object. |
| `TomGitHubLocator` | `github:<owner>/<repo>[@<branch>]/<path>` — parsed and printed. |
| `tomOpenBrowserMedium` | A medium over IndexedDB (`web.dart`). |
| `TomAesGcmCacheCipher` | AES-256-GCM sealing of cache files (`cipher.dart`). |

## Entry points

| Import | Holds | Platforms |
| --- | --- | --- |
| `package:tom_core_storage/tom_core_storage.dart` | the port, media, cache, journal, asset store and policies | all, the web included (no `dart:io`, no browser API, no cipher) |
| `package:tom_core_storage/io.dart` | `TomLocalFileSystemStorage`, `TomDirectoryBundleMedium` | desktop, server, mobile |
| `package:tom_core_storage/github.dart` | `TomGitHubStorage`, `tomGitHubWaitOf` | all, the web included (over `tom_github_api`) |
| `package:tom_core_storage/web.dart` | `tomOpenBrowserMedium`, `TomBrowserStorageException` | browser (a VM test gets an in-memory stand-in) |
| `package:tom_core_storage/cipher.dart` | `TomAesGcmCacheCipher` | all |

## Quick start

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:tom_core_storage/io.dart';
import 'package:tom_core_storage/tom_core_storage.dart';

Future<void> main() async {
  const storage = TomLocalFileSystemStorage();
  const locator = 'notes.yaml';

  // Write against the head we saw; a concurrent writer makes this throw
  // TomCasConflictException instead of being overwritten.
  final head = await storage.headOf(locator);
  await storage.commit(
    locator,
    TomChangeset.singleFile(Uint8List.fromList(utf8.encode('a: 1\n'))),
    expectedHead: head,
  );

  // Keep a commit that could not be delivered, across restarts.
  final journal = TomMediumCommitJournal(medium: TomMemoryBundleMedium());
  await journal.append(
    locator: locator,
    changeset: TomChangeset.singleFile(Uint8List.fromList([1])),
    baseHead: head,
    version: 1,
  );
}
```

## Limits

- **One remote backend.** GitHub, reached through its REST and git-data API;
  Git-LFS pointers are refused rather than resolved, and a single object over
  `TomGitHubStorage.maxBlobBytes` is refused before the commit spends anything.
- **The cache cipher keeps its key through a port.** `TomCacheKeyStore` is two
  members; an application's own secret store implements it.

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_basics` | runtime | the structured diagnostics port, the YAML emitter and the content hash |
| `archive` | runtime | a medium's ZIP form |
| `yaml` | runtime | reading the journal back |
| `meta` | runtime | `@visibleForTesting` |
| `path` | runtime | paths on the local filesystem (`io.dart`) |
| `tom_github_api` | runtime | the GitHub REST and git-data API (`github.dart`) |
| `web` | runtime | IndexedDB (`web.dart`) |
| `pointycastle` | runtime | AES-256-GCM (`cipher.dart`) |
| `test`, `lints` | dev | the suite (with `tom_github_api`'s in-memory GitHub from `package:tom_github_api/testing.dart`) |

## Status

Version **0.1.0**. `dart test` runs the unit suite, the local-filesystem
atomicity suite, the GitHub backend against an in-memory GitHub, a dart2js
compile of the default, GitHub and web entry points, and —
through `test/browser_suite_test.dart` — the IndexedDB suite on Chrome
(`TOM_SKIP_BROWSER_TESTS=1` skips it, saying so).
