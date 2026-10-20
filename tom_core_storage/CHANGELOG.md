# Changelog

## 0.1.0

### Added

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
