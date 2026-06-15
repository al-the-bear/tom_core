## Unreleased

### Documentation

- Replaced the default package-template `README.md` with a customized one: a
  description of the package, a path-dependency getting-started section, correct
  usage snippets (`TomServer`, `TomArgs.fillFromArgs`, `TomEnvFile.read`,
  repository CRUD), and a Modules table covering all 13 exported modules. No
  code or public API change.
- **Authentication module**: added dartdoc to all public symbols
  (`TomAuthenticationServer`, `TomAuthenticationService`,
  `TomAuthenticationData`, `TomAuthenticationInfo`,
  `TomDummyAuthenticationService`, `LoginException`, `TomAuthenticationAdaptor`,
  `Tom2FAAdaptor`, `Tom2FAService`); a module guide at `doc/authentication.md`;
  an executable example at `example/authentication/`; and a test suite at
  `test/authentication_test.dart`. No public API change — removed only stray
  `// TODO:` comments (the deferred 2FA work is now recorded in the module
  dartdoc and the quest completion steps).
- **Authorization module**: added dartdoc to all public symbols
  (`TomAuthorizationCache`, `TomAuthorizationCacheEntry`,
  `TomAuthorizationCacheException`, `TomAuthorizationCacheStoreMessage`,
  `TomAuthorizationCacheRetrieveMessage`, `TomAuthorizationCacheExecutor`),
  including a corrected/relocated class doc and the main-isolate cache /
  cross-isolate forwarding model; a module guide at `doc/authorization.md`; an
  executable example at `example/authorization/`; and a test suite at
  `test/authorization_test.dart`. No public API change — removed only one stray
  `// TODO:` comment (its intent is now captured in the
  `TomAuthorizationCacheException` dartdoc).
- **Cache module**: added dartdoc to all public symbols (`TomCache`,
  `TomCacheEntry`, `TomCacheManager`, `TomCacheException`,
  `TomCacheStoreMessage`, `TomCacheRemoveMessage`, `TomCacheRetrieveMessage`),
  documenting the main-isolate cache / worker-forwarding model, the LRU bound,
  per-entry expiry, and the retrievable-entry-requires-a-deletion-time
  invariant; a module guide at `doc/cache.md`; an executable example at
  `example/cache/`; and a test suite at `test/cache_test.dart`. Removed a dead
  embedded `main()` test scaffold from `server_cache.dart` (its LRU coverage is
  now expressed through observable behaviour in the test suite).
- **Command-line module**: added dartdoc to `TomArgs` and its members
  (`fillFromArgs`, `parseArgsToMap`, `convertToObjectMap`, `intPattern`,
  `doublePattern`), documenting the shared value-conversion table and the
  flag-encoding difference between `fillFromArgs` (string `"true"`) and
  `parseArgsToMap` (boolean `true`); a module guide at `doc/cmdline.md`; an
  executable example at `example/cmdline/`; and a test suite at
  `test/cmdline_test.dart`. `TomEnvFile` was already documented. No public API
  change.
- **Configuration module**: added dartdoc to all public symbols
  (`TomServerConfigResourceProvider`, `TomConfig` and its `TomStringConfig` /
  `TomIntConfig` / `TomDoubleConfig` / `TomBoolConfig` specialisations,
  `TomBaseServerConfiguration`, `tomAppId`), documenting the resource-provider
  lookup model, `TomConfig`'s construction-time resolution, and the
  resources → environment → `.env` → args source precedence; a module guide at
  `doc/configuration.md`; an executable example at `example/configuration/`; and
  a test suite at `test/configuration_test.dart`. `TomYaml` was already
  documented. No public API change — removed only a stray `// TODO:` comment
  (the deferred JWT-settings work is now recorded in the class dartdoc and the
  quest completion steps).

### Fixed

- **Cache `removeFromNameCache` no longer fails to forward / throw correctly in
  worker isolates.** The isolate-routing guard used `useInThisIsolate` without
  the negation present in its `toNameCache` / `fromNameCache` siblings, so the
  forward-or-throw decision was inverted. Pinned by a regression test asserting
  a missing cache in the main isolate throws `TomCacheException`.
- **Cache LRU promotion no longer corrupts the tail pointer.** When `getEntry`
  promoted the most-recently-used *tail* entry to the front, it failed to
  advance `_last` to the predecessor, leaving a stale tail that could evict the
  wrong (recently read) entry. Pinned by a test that reads an entry to promote
  it and asserts it survives the next eviction.

## 1.0.0

- Initial version.
