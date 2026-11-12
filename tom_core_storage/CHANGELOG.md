# Changelog

## 0.1.0

### Added

- **`TomMediumFileStorage`**: single-file containers on a `TomBundleMedium`,
  one per locator under a prefix, with a compare-and-swap on the SHA-256 of
  the stored bytes — the storage a browser root has for a KDBX container in
  IndexedDB.
- **Settings and secrets, in `settings.dart`.** Formerly the package
  `tom_core_settings`, folded in before the first release:

  - **The device settings file.** `TomDeviceSettings`: plain YAML at a locator,
    read and committed through a `TomStorage`; an open registry of keys that is
    written back whole, so a key this build does not know survives; typed
    accessors for the settings-key handle, the log's path and level and the
    cache's quota and sealing; one serialized write queue, so concurrent writers
    never refuse each other; a malformed file reads as empty.
  - **The settings-key bootstrap.** `TomSettingsKeyBootstrap.ensure` mints one
    random secret per device into the platform secret store and records its
    handle in device settings, idempotently; a wiped keychain re-mints the
    secret under the same handle. A store that cannot be asked raises
    `TomSecretStoreException` with its `TomSecretStoreStep` and cause.
  - **The secret-store port.** `TomSecretStore` (a `TomCacheKeyStore`) and
    `TomInMemorySecretStore`.
  - **The key port.** `TomKeyMaterial`, `TomKeyRegistry` with
    `TomMemoryKeyRegistry`, `TomKeyStore` with `TomInMemoryKeyStore`.
  - **Identity and locations.** `TomIdentity`, `TomStorageLocation`,
    `TomLocationRegistry` with `TomInMemoryLocationRegistry`, and
    `TomLocationForgetting` with `TomLocationTraces` and `TomForgottenLocation`.

  These came from the Webwork app, where they carried the `Webwork` prefix; the
  bootstrap there also opened the KDBX settings container, which stays with the
  container binding.
- **A git backend.** `package:tom_core_storage/git.dart`: `TomGitStorage`
  over any git server that speaks smart HTTP, through `tom_git` and with no
  git binary — a local clone as the medium (`tomGitMemoryClones`, or
  `tomGitDirectoryClones` from `io.dart`), a head that is the document's
  object id in the branch tip, a commit that is a compare-and-swap on it and
  then a push, a lost race to another document's change rebuilt and pushed
  again, a lost race to this document's a `TomCasConflictException`, and
  `TomTokenRequiredException` / `TomTokenRejectedException` when the server
  asks for a credential. Locators are `TomGitLocator`:
  `git:<repository-url>[#<branch>]::<path>`, the repository `http(s):` or
  `file:`; an empty path is the repository root, which lists.
  With `openLocal` (`tomGitLocalRepositories` from `io.dart`) a `file:`
  locator is a repository in a folder on this device — a working repository,
  a linked worktree or a bare one — read and written in place, compare-and-
  swap on the branch under git's ref lock; a branch some working tree has
  checked out is read and never written.
- **A storage contract.** `test/support/storage_contract.dart`: what a
  caller may rely on from every backend, run against the local filesystem
  and the git backend.

- **Test support.** `package:tom_core_storage/testing.dart`: `TomMemoryRemote`,
  an in-memory compare-and-swap remote, and `TomMemoryStorage`, a per-device
  view onto it whose reads, writes, quota (`rateLimitedUntil`), key
  (`keyRequiredReason`) and replica lag (`TomStaleHead`) each fail on their
  own switch.
- **The asset store.** `TomAssetStore`: assets filed under the SHA-256 of
  their bytes (`TomAsset`), deduplicated, read on demand and verified then
  (`TomAssetCorruptException`), resolved as `TomAssetLive`,
  `TomAssetHistorical` or `TomAssetMissing`, ingested under a
  `TomObjectCeiling`, revived from history after an undo, copied between
  stores. The accepted types are the application's (`TomAssetTypes`: MIME type
  to extension and kind). `TomAssetBundleLayout` keeps a store in a
  `TomBundleMedium`: `assets/<id>.<ext>`, an append-only history folder, and
  the metadata map a manifest carries.
- **The storage port.** `TomStorage`: list, read a container's bytes or its
  files (`readBundle`, a lazy read-only view), `commit` a `TomChangeset`
  against an expected head (compare-and-swap), delete, and read heads one at a
  time or in a batch. Its failures are typed: `TomUnreachableException`,
  `TomContainerNotFoundException`, `TomCasConflictException`,
  `TomKeyRequiredException`, `TomRateLimitException` (with its
  `TomRateLimitKind`). `TomBackoffPolicy` states the waits a backend chooses
  when the remote names none; `TomCommitProgress` reports a long commit.
- **Keyed file media.** `TomBundleMedium` with `TomMemoryBundleMedium` (and its
  ZIP form), `TomReadOnlyBundleMedium` and `TomRecordingBundleMedium`, which
  turns writes into one changeset; `TomSeededStorage`, a read-only view with
  one container replaced.
- **Policies.** `TomObjectCeiling` (the tighter of a configured and a backend
  limit), Git-LFS pointer refusal (`TomLfsPointer`, `tomRefuseLfsPointer`),
  access tokens (`TomTokenSource`, `TomInMemoryTokenSource`), location
  prefixes (`tomLocationCovers`, `tomLongestLocationPrefix`).
- **A device-local cache** (`TomStorageCache` with `TomCachePolicy`,
  `TomCacheSettings`, `TomCacheScrub`) and **a durable offline commit journal**
  (`TomCommitJournal`, `TomMemoryCommitJournal`, `TomMediumCommitJournal`).
- **A GitHub repository as a backend** (`github.dart`): `TomGitHubStorage` —
  one save is one commit, compare-and-swap on the branch head, conditional
  reads, rate-limit waits (`tomGitHubWaitOf`), Git-LFS refusal, progress per
  object, an optional `commitMessagePrefix` — and its locator
  `TomGitHubLocator` in the default entry point.
- **Entry points of their own**: `io.dart` (`TomLocalFileSystemStorage`,
  `TomDirectoryBundleMedium`), `web.dart` (`tomOpenBrowserMedium` over
  IndexedDB) and `cipher.dart` (`TomAesGcmCacheCipher` over a
  `TomCacheKeyStore`).
- **A local commit always moves the head.** A file's head token is its size
  and its modification time to the millisecond, so a commit writes only once
  the clock is past the previous time of every file it replaces. Two
  same-size commits inside one millisecond otherwise left the head unchanged,
  and a device holding the older head could commit over the newer write.
