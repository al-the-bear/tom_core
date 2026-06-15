## 1.1.0

This release is a documentation, test, and example pass over every module of
`tom_core_server` — adding dartdoc to all public symbols, a `doc/<module>.md`
guide, an executable example, and a test suite per module — plus a handful of
genuine bug fixes pinned by regression tests. No public API was added or
removed (the deletions below were unexported placeholders).

### Documentation

- Replaced the default package-template `README.md` with a customized one: a
  description of the package, a path-dependency getting-started section, correct
  usage snippets (`TomServer`, `TomArgs.fillFromArgs`, `TomEnvFile.read`,
  repository CRUD), and a Modules table covering all 13 exported modules. No
  code or public API change.
- **Final-review accuracy pass**: the README Server-module summary and the
  intro no longer advertise the unimplemented WebSocket / diagnostics /
  monitoring / form-handling capabilities (those were empty placeholders,
  removed below). The Server description now reflects the actual surface — the
  shelf middleware pipeline around the endpoint router — matching
  `doc/server.md`'s "Not Yet Implemented" section. Verified that all 13 modules
  have a one-to-one `doc/<module>.md`, an `example/<module>/`, and a
  `test/<module>_test.dart`; reflection/DB/socket-dependent surfaces are
  documented and integration-tested, the connection-free surfaces are
  unit-tested (196 tests, all green).
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

- **Datasources module**: added dartdoc to all public symbols across the six
  files — the SQL-typed values (`TomDbType` and `TomDbInt` / `TomDbDouble` /
  `TomDbString` / `TomDbDateTime` / `TomDbDate` / `TomDbTime` / `TomDbBool`), the
  operator tree (`TomOperator`, `SqlString`), the dialect (`TomStandardSqlDialect`
  and every fragment method, `TomSqlDialect`, `MariadbSqlDialect`), the query
  objects (`TomTypePersistenceInfo`, `TomTypedPersistenceBase`, `TomQuery`,
  `TomGeneratedQuery`, `TomSelect`, `TomLiteralSelect`, `TomCount`, `TomDelete`),
  and the data-source/driver layer (`TomDatasourceInitException`,
  `TomDatasourceDriver`, `TomPreparedStatement`, `TomDataSource`,
  `TomDataSourceInfo`, `MariadbDatasourceException`,
  `MariadbPreparedStatementException`, `MariadbPreparedStatement`,
  `MariaDbDatasource`, `MariaDbXADatasource`); a module guide at
  `doc/datasources.md`; an executable example at `example/datasources/`; and a
  test suite at `test/datasources_test.dart` covering the connection-independent
  surface (dialect SQL-fragment generation and `TomDbType` `.of()` conversions).
  No public API change — removed several stray `// TODO:` comments (the
  SQL-injection-escaping of directly-interpolated literals and the
  result-set access-control work are now recorded in the quest completion
  steps; the architectural "should be in SqlDialect" notes are captured in the
  module dartdoc).
- **Database-migration module**: added dartdoc to all public symbols across the
  two files — the orchestrator and its contract (`TomDbMigrations`,
  `TomDbMigrator`, `TomDbMigrationAdaptor`, `TomDbMigrationException`) and the
  MariaDB implementation (`MariadbMigrationAdaptor`, `MariadbMigrationException`,
  `TomDbVersion`), documenting the keyed directory layout
  (`<datasourceName>/<schemaName>/[<version>]-<description>.<ext>`), reflection
  adaptor discovery, and the versioning-table idempotency/checksum-stability
  model; a module guide at `doc/db_migration.md`; an executable example at
  `example/db_migration/`; and a test suite at `test/db_migration_test.dart`
  covering the connection-free surface (`TomDbVersion`, the
  `TomDbMigrationAdaptor` type binding, and the exception types). No public API
  change — the literal-escaping of directly-interpolated migration scripts is
  noted in the module doc and tracked with the datasources follow-up.
- **Endpoints module**: added dartdoc to all public symbols across the two files
  — the annotations (`TomEndpoint`, `TomApiEndpointImplementation`,
  `TomService` / `tomService`, `TomApiImplementation`, `TomComponentReference`,
  `TomTransactional`, `TomErrorHandler` / `TomDefaultErrorHandler`, the
  `TomEndpointBase` contract) and the pipeline (`TomEndpointRouting`,
  `TomEndpointHandler`, `TomMethodMetadata`, `TomClassScanResult`,
  `TomEndpointRoutingInfo`, `TomEndpointHandlerException`,
  `TomEndpointPipelineException`), documenting the annotation-driven routing
  model, the per-request pipeline (access → parameter binding → transaction →
  invoke → result/error conversion), and the default opaque-`500` error handler;
  a module guide at `doc/endpoints.md`; an executable example at
  `example/endpoints/`; and a test suite at `test/endpoints_test.dart` covering
  the reflection-free surface (the annotations and the default error handler).
  No public API change — removed several stray `// TODO:` comments (the
  unimplemented form-field/file-upload/redirect, streaming/file response,
  WebSocket, and richer-authorization work is now recorded in the quest
  completion steps and folded into the relevant dartdoc).

- **Health-check module**: the module was already dartdoc-documented; added a
  doc comment to the `TomHealthService.health` endpoint method, a module guide at
  `doc/healthcheck.md`, an executable example at `example/healthcheck/`, and a
  test suite at `test/healthcheck_test.dart` covering the server-free surface
  (the `HealthAnalyzer` contract and `TomHealthServer.health`'s delegation to the
  global analyzer). The `/health` route itself is mounted by the reflection
  pipeline and is documented, not unit-tested. No public API change.

- **Little-things module**: added dartdoc to the sole public symbol
  `TomServerException` and its members (`isolateName`, `clientThrow`, the
  constructor, and the `toString` override), documenting its role as the base
  class for every server-raised exception and its two server-specific concerns —
  isolate attribution (`Isolate.current.debugName`) and zone-based request
  correlation (copying the current `TomRequestId`'s UUID into the inherited
  `requestUuid`); a module guide at `doc/little_things.md`; an executable example
  at `example/little_things/`; and a test suite at `test/little_things_test.dart`
  covering construction, defaults, the `TomException` inheritance, isolate
  attribution, the `toString` format, and request correlation via a `runZoned`
  carrying a `TomRequestId`. No public API change.
- **Object-persistence module**: added dartdoc to all public symbols across the
  seven module files — the persistence annotations (`TomDartType`, `TomDbTable`,
  `TomDbColumn`, `TomEntityId`, `TomJoinTable`, `TomReference`,
  `TomPersistenceEventHandler`) and `TomColumnInformation`; the operator tree
  (`TomUnaryOperator` / `TomBinaryOperator` and every concrete operator —
  literals, `Parameter`, the `*Col` references, `And`/`Or`, the comparisons,
  `Like`/`In`/`Between`/`Group`/`Regexp`, …) and `TomQuerySyntaxException`; the
  `TomQueryBuilder` DSL mixin and every factory; the `TomAnnotationAnalyzer`
  mixin and its exceptions; the repository contract (`TomRepository`,
  `TomSqlDatasourceRepository`, `MariadbRepository`, `TomCountResult`,
  `TomRepositoryType`); and the `TomQuerySentenceCompiler`. Added a module guide
  at `doc/object_persistence.md`, an executable example at
  `example/object_persistence/`, and a test suite at
  `test/object_persistence_test.dart` covering the connection-free surface (the
  `TomQueryBuilder` DSL / operator-tree SQL rendering through `MariadbSqlDialect`,
  BETWEEN arity validation, and the plain-data annotations /
  `TomColumnInformation`). No public API change — removed only stray `// TODO:`
  comments (the deferred work — `@TomJoinTable` / `@TomPersistenceEventHandler`
  detection, pageable / limit / slicing / sort result options, additional
  query-method keywords, and a `deleteById` prepared-statement bug — is now
  recorded in the quest completion steps).
- **Server module**: added dartdoc to every public symbol in `server.dart`
  (`TomServer` and its members, `TomRequestId`, `TomRequestLogInfo`,
  `contextSetupMiddleware`, `extractAuthentication`,
  `tomDefaultAuthenticationMiddleware`, `tomLoggingMiddleware`, `noopHandler`),
  documenting the shelf pipeline composition, the request-context / request-zone
  channels, and the JSON error mapping. Added a module guide at `doc/server.md`,
  an executable example at `example/server/`, and a test suite at
  `test/server_test.dart` (17 tests) covering the socket-free surface — the
  per-request value objects, `extractAuthentication`, and the
  `contextSetupMiddleware` / `tomLoggingMiddleware` /
  `tomDefaultAuthenticationMiddleware` / `noopHandler` middlewares; `TomServer`
  binds a real socket and needs a reflected configuration, so it is documented,
  not unit-tested. No public API change — removed only a stray `// TODO:`
  comment (the GZIP/autoCompress note).
- **Transactions module**: added dartdoc to all public symbols
  (`TomTransactionParticipant` and its hooks, `TomTransaction` +
  `isReadOnly`/`isRunning`/`registerParticipant`/`commitTransaction`/
  `rollbackTransaction`, `TomTransactionManager` +
  `startTransaction`/`getCurrentTransaction`/`transactional`, and
  `TomTransactionException`), documenting the participant contract, the
  commit-veto → rollback drive, the new-vs-existing return of `startTransaction`,
  and the single-static (per-isolate) current-transaction model. Added a module
  guide at `doc/transactions.md`, an executable example at
  `example/transactions/`, and a test suite at `test/transactions_test.dart`
  (11 tests) exercising the full self-contained surface with a recording fake
  participant. No public API change.

### Removed

- **Removed the empty `externalapis/` placeholder module.** It contained no
  Dart code — only a `readme.md` holding a single bookmark URL
  (`https://dart.dev/guides/google-apis`) — and was not exported, referenced, or
  depended on anywhere. Implementing it would have been speculative (no contract
  or consumer existed), so the placeholder was deleted. The workspace metadata
  still lists an `externalapis` module entry (no sources) until the next
  metadata regeneration.
- **Removed four empty placeholder files from the `server/` module**
  (`diagnostics.dart`, `forms.dart`, `monitoring.dart`, `websocket.dart`). They
  held only `// TODO:` markers (or were empty), were not exported, referenced, or
  depended on anywhere, and carried no contract — so they were deleted. The
  intended capabilities (diagnostics, monitoring, WebSocket support, server-side
  forms) are recorded in the quest completion steps and the `doc/server.md`
  "Not Yet Implemented" section.

### Fixed

- **`HealthAnalyzer` dartdoc example now overrides the right method.** The
  class-doc example overrode a non-existent `analyze()` method; corrected to the
  actual abstract method `analyzeHealth()` so the snippet matches the contract.
- **`TomStandardSqlDialect.iterableOp` now comma-joins correctly.** The
  separator was emitted only on the first element (`result.isEmpty ? "," : ""`),
  so `[1, 2, 3]` rendered as `"1,23"` instead of `"1,2,3"` — corrupting any
  `IN (...)` / list literal built through `objectOp`. Pinned by regression tests
  for multi-, single-, and empty-element iterables.
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
