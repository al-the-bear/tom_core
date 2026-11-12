# tom_core_storage

Published on pub.dev as [`tom_core_storage` 0.1.0](https://pub.dev/packages/tom_core_storage).

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and published on pub.dev.

Storage for Tom applications — a compare-and-swap storage port, keyed file
media, a device-local cache and a durable offline commit journal — with the
local filesystem, a GitHub repository, any git server over smart HTTP, the
browser and the cache cipher behind entry points of their own; and, in
`settings.dart`, the settings and secrets an application keeps beside its
documents: device settings, the key port, the secret-store port, identity and
storage locations.

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

Add it from pub.dev:

```yaml
dependencies:
  tom_core_storage: ^0.1.0
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
| `TomLocalFileSystemStorage` | The local filesystem (`io.dart`): atomic multi-file commits through staged temps and a recorded intent; every commit moves the head, however fast two same-size commits follow each other. |
| `TomGitHubStorage` | A GitHub repository (`github.dart`): one save is one commit, compare-and-swap on the branch head, conditional reads, rate-limit waits, LFS refusal, progress per object. |
| `TomGitHubLocator` | `github:<owner>/<repo>[@<branch>]/<path>` — parsed and printed. |
| `TomGitStorage` | Any git server over smart HTTP (`git.dart`), and with an `openLocal` opener a repository in a folder on this device, with no git binary. For a server a local clone is the medium, a head is the document's object id in the branch tip, a commit is a compare-and-swap on it and then a push; a push that lost the race to a change of another document is rebuilt on the new tip and pushed again, one that lost it to this document is a `TomCasConflictException`. A folder's repository is written in place under git's ref lock; a branch some working tree has checked out is read and never written. |
| `TomGitLocator` | `git:<repository-url>[#<branch>]::<path>`, the URL `http(s):` or `file:` — parsed and printed; without a branch, the server's default or the folder's `HEAD`; an empty path is the repository root, a folder. |
| `tomGitMemoryClones`, `tomGitDirectoryClones`, `tomGitLocalRepositories` | Where the git backend keeps its clones — in memory (`git.dart`), or one bare repository per remote under a directory, in git's own layout (`io.dart`) — and how it opens a repository in a folder: a working repository, a linked worktree or a bare one (`io.dart`, `TomGitLocalRepository`). |
| `TomMediumFileStorage` | Single-file containers on a `TomBundleMedium`, one per locator under a prefix (`browser:settings.webwork.kdbx`); a head is the SHA-256 of the bytes and a commit is a compare-and-swap on it. What a root has whose device storage is a keyed medium rather than a file system — a browser's IndexedDB. |
| `tomOpenBrowserMedium` | A medium over IndexedDB (`web.dart`). |
| `TomAesGcmCacheCipher` | AES-256-GCM sealing of cache files (`cipher.dart`). |
| `TomMemoryRemote`, `TomMemoryStorage`, `TomStaleHead` | Test support (`testing.dart`): an in-memory compare-and-swap remote shared by per-device storages whose reads, writes, quota, key and replica lag each fail on their own switch. |

## Entry points

| Import | Holds | Platforms |
| --- | --- | --- |
| `package:tom_core_storage/tom_core_storage.dart` | the port, media, cache, journal, asset store and policies, and both repository locators (`TomGitHubLocator`, `TomGitLocator`) | all, the web included (no `dart:io`, no browser API, no cipher) |
| `package:tom_core_storage/io.dart` | `TomLocalFileSystemStorage`, `TomDirectoryBundleMedium`, `tomGitDirectoryClones`, `tomGitLocalRepositories` | desktop, server, mobile |
| `package:tom_core_storage/github.dart` | `TomGitHubStorage`, `tomGitHubWaitOf` | all, the web included (over `tom_github_api`) |
| `package:tom_core_storage/git.dart` | `TomGitStorage`, `TomGitLocalRepository`, `tomGitMemoryClones` | all, the web included (over `tom_git` and `http`) |
| `package:tom_core_storage/web.dart` | `tomOpenBrowserMedium`, `TomBrowserStorageException` | browser (a VM test gets an in-memory stand-in) |
| `package:tom_core_storage/cipher.dart` | `TomAesGcmCacheCipher` | all |
| `package:tom_core_storage/settings.dart` | device settings, the settings-key bootstrap, the key port, the secret-store port, identity, storage locations and forgetting one | all, the web included (no `dart:io`, no container format, no platform plugin) |
| `package:tom_core_storage/testing.dart` | `TomMemoryRemote`, `TomMemoryStorage`, `TomStaleHead` — a test double; only a test imports it | all |

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

## Settings and secrets

`package:tom_core_storage/settings.dart`.

An application with encrypted documents holds two kinds of settings:

- **What follows the person** — tokens, document keys, identity, registered
  locations — kept in an encrypted settings container whose format the
  application chooses.
- **What describes the machine** — the window layout, the log's location, the
  cache quota — kept in a plain YAML **device settings** file
  (`TomDeviceSettings`) that is readable when nothing else works, never synced
  and never a secret.

The settings container needs a key, and its key cannot live inside it. So a
device holds **one** secret outside both, in the platform secret store
(`TomSecretStore`), with only its *handle* in device settings.
`TomSettingsKeyBootstrap` mints that secret on first launch and finds it again
afterwards; a wiped keychain re-mints the secret under the same handle, and a
keychain that cannot be asked at all is raised as `TomSecretStoreException`
naming the call that failed.

The **key port** states a container key as material (`TomKeyMaterial`: a
passphrase, a key file's bytes, or a pointer to a key file), registers keys per
container with a default behind them (`TomKeyRegistry`), and persists them
between sessions (`TomKeyStore`). A container library's binding turns material
into its own credentials; nothing above it names that library.

**Locations** (`TomStorageLocation`, `TomLocationRegistry`) are a convenience
list of places to offer, never an access-control list. `TomLocationForgetting`
removes one together with every trace this device keeps for it — per-file key
overrides, cache blobs and records, unpushed journal entries — after `survey`
has said what that would remove.

| Type | What it does |
| ---- | ------------ |
| `TomDeviceSettings` | The device settings file: an open registry of keys written back whole, typed accessors for the settings-key handle, the log's path and level and the cache's quota and sealing, and one serialized write queue. |
| `TomSettingsKeyBootstrap` | Mints the device's settings key into the secret store and records its handle; answers a `TomSettingsKey`. |
| `TomSecretStore` | The platform secret-store port (implements the cache's `TomCacheKeyStore`); `TomInMemorySecretStore` for tests. |
| `TomSecretStoreException` | A secret store that could not answer, naming the step (`TomSecretStoreStep`) and keeping the cause. |
| `TomKeyMaterial` | A container key: passphrase, key-file bytes, key-file locator; `isResolvable` and `isEmpty` kept apart. |
| `TomKeyRegistry` | The keys a session tries, by container, with a default; `TomMemoryKeyRegistry` opens nothing. |
| `TomKeyStore` | Keys persisted between sessions: two defaults and per-file overrides; `TomInMemoryKeyStore`. |
| `TomIdentity` | The display name and stable author id content is attributed to, with the `unknown` sentinel. |
| `TomStorageLocation`, `TomLocationRegistry` | Registered locations, keyed by locator; `TomInMemoryLocationRegistry` remembers for the session. |
| `TomLocationForgetting` | `survey` and `forget` a location and its traces (`TomLocationTraces`, `TomForgottenLocation`). |

```dart
import 'package:tom_core_storage/settings.dart';
import 'package:tom_core_storage/io.dart';

Future<void> main() async {
  final device = TomDeviceSettings(
    locator: 'device.yaml',
    storage: const TomLocalFileSystemStorage(),
  );
  // A platform keychain in an application; in memory here.
  final secrets = TomInMemorySecretStore();

  final key = await TomSettingsKeyBootstrap(
    device: device,
    secrets: secrets,
  ).ensure();
  // key.secret opens the settings container; key.handle is in device.yaml.

  device.cacheQuotaBytes = 256 << 20;
  await device.save();
}
```

- **No container format.** The encrypted settings container, and turning key
  material into its credentials, belong to a container binding the application
  supplies.
- **No platform secret store.** The keychain implementation is the host's —
  a Flutter host binds the platform keychain behind `TomSecretStore`.

## Limits

- **Two remote backends.** GitHub, reached through its REST and git-data API,
  and any git server over smart HTTP(S), reached through `tom_git`. Git-LFS
  pointers are refused rather than resolved by both, and a single object over
  `TomGitHubStorage.maxBlobBytes` is refused before the commit spends anything.
- **The git backend fetches and pushes whole objects.** It fetches only the
  branch a document is on, asks for no thin pack and writes no deltas; SSH
  remotes, shallow clones and Git-LFS are not supported (`tom_git`'s README
  states the subset).
- **The cache cipher keeps its key through a port.** `TomCacheKeyStore` is two
  members; an application's own secret store implements it.

## Dependencies

| Dependency | Kind | For |
| ---------- | ---- | --- |
| `tom_basics` | runtime | the structured diagnostics port, the YAML emitter and the content hash |
| `archive` | runtime | a medium's ZIP form |
| `yaml` | runtime | reading the journal back |
| `meta` | runtime | `@visibleForTesting` |
| `uuid` | runtime | the handle a minted settings key is stored under (`settings.dart`) |
| `path` | runtime | paths on the local filesystem (`io.dart`) |
| `tom_github_api` | runtime | the GitHub REST and git-data API (`github.dart`) |
| `tom_git` | runtime | git objects, packs and smart HTTP in pure Dart (`git.dart`) |
| `http` | runtime | the client the git backend's transport is given (`git.dart`) |
| `web` | runtime | IndexedDB (`web.dart`) |
| `pointycastle` | runtime | AES-256-GCM (`cipher.dart`) |
| `test`, `lints` | dev | the suite (with `tom_github_api`'s in-memory GitHub from `package:tom_github_api/testing.dart` and `tom_git`'s in-memory git server from `package:tom_git/testing.dart`) |
| `tom_test_support` | dev | the live contract and the Gitea fixture, for the live git-backend suites |

## Status

Version **0.1.0**. `dart test` runs the unit suite, the settings suite in
`test/settings/` (the device file and its write queue, the bootstrap against a
failing and a wiped keychain, the key port, forgetting a location), the
local-filesystem atomicity suite, the GitHub backend against an in-memory GitHub, the storage
contract (`test/support/storage_contract.dart`) against the local filesystem
and the git backend over an in-memory git server, a dart2js compile of the
default, settings, GitHub, git and web entry points, and —
through `test/browser_suite_test.dart` — the IndexedDB suite on Chrome
(`TOM_SKIP_BROWSER_TESTS=1` skips it, saying so).

With `TOM_LIVE` set, `test/git_storage_test.dart` also runs the contract
against GitHub (on `GITHUB_TEST_TOKEN`, a branch of its own in the scratch
repository, deleted afterwards) and against a Gitea started in Docker.
