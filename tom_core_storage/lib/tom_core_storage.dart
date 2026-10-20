/// Storage for Tom applications — the platform-neutral part.
///
/// A compare-and-swap storage port ([TomStorage]: list, read, commit against
/// an expected head, delete), keyed file media ([TomBundleMedium] and its
/// in-memory, read-only and recording forms), a device-local cache over any
/// storage ([TomStorageCache]), a durable offline queue of commits
/// ([TomCommitJournal]), and the policies around them: object ceilings,
/// Git-LFS pointer refusal, backoff, access tokens.
///
/// Imports no `dart:io`, no browser API and no cipher, so it compiles for
/// every platform, the web included. The implementations that need one of
/// those have entry points of their own:
///
/// - `package:tom_core_storage/io.dart` — the local filesystem;
/// - `package:tom_core_storage/web.dart` — IndexedDB in a browser;
/// - `package:tom_core_storage/cipher.dart` — AES-256-GCM for the cache.
library;

export 'src/assets/asset.dart';
export 'src/assets/asset_bundle_layout.dart';
export 'src/backoff_policy.dart';
export 'src/bundle_medium.dart';
export 'src/commit_journal.dart';
export 'src/commit_progress.dart';
export 'src/github_locator.dart';
export 'src/lfs_pointer.dart';
export 'src/location_prefix.dart';
export 'src/object_ceiling.dart';
export 'src/recording_medium.dart';
export 'src/seeded_storage.dart';
export 'src/storage.dart';
export 'src/storage_cache.dart';
export 'src/token_source.dart';
