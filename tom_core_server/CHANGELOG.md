## 1.3.0

### Features

- **repository paging and caller-controlled sorting.** The four finders
  (`findAll`, `findAllById`, `findByQuery`, `findByQuerySentence`) now take an
  optional `TomPageRequest`, so a caller asks for page N of size M instead of
  loading the whole table. Three holes closed at once: OFFSET was previously
  *unrepresentable* (`TomGeneratedQuery` rendered `LIMIT n` and nothing else),
  none of it was on the repository API, and ordering carried a single
  `bool ascending` for every column — `ORDER BY priority DESC, due_date ASC` could
  not be expressed at all.

  Ordering is now a list of `TomSortField`s, each with its own
  `TomSortDirection`. `TomSelect` / `TomCount` / `TomDelete` still accept the old
  `orderBy:` + `ascending:` pair as a *shorthand* that maps onto the list, so the
  generated `*.reflection.dart` files across the samples keep compiling
  unchanged; the stored field is the list.

  **Two requests are rejected rather than silently reinterpreted.** MariaDB's
  grammar is `LIMIT n [OFFSET m]` with no bare `OFFSET`, so a skip without a cap
  would be dropped on the floor — `TomPageRequest.assertWindow` and
  `TomGeneratedQuery.limitClause` both throw `TomQuerySyntaxException` for it, and
  for a negative bound. `TomCount` and `TomDelete` take no offset: a total does
  not depend on the page, and `DELETE … LIMIT n OFFSET m` is not MariaDB syntax.

  **An unsorted window is still made deterministic.** Rather than rejecting a
  page request with no `ORDER BY`, the repository appends the entity's primary key
  ascending as a tiebreaker, so consecutive pages partition the result instead of
  repeating and dropping rows at the database's discretion.

  **Paging composes with the security layers** because the window is applied
  *before* the scope: the row scope's bound `IN` predicate is still ANDed in and
  column-authorization masking still runs on the returned rows. The total beside
  a page comes from `count()`, which routes through the same scoping — so page
  metadata cannot leak a row count the principal may not read. Asserted live in
  `test/paging_db_test.dart` (three of five rows visible, count says three).

  The query sentence grew the matching vocabulary: `skip M` / `offset M` beside
  `top N` / `first N`, and a direction per field in the trailing `order by`. Each
  direction keyword applies back to the previous one, so `order by a b desc`
  sorts both descending (the historical whole-list reading) while
  `order by a desc b asc` mixes them, and an undirected field sorts ascending.

  *Design decisions.* (1) The result shape is `List<T>` plus the existing
  `count()`, not a `TomPage<T>`: it keeps every existing signature intact and
  avoids a mandatory second round-trip per page for callers that do not need the
  total. (2) The offset guard rejects the *unrepresentable* window but not the
  merely under-specified one — a missing `ORDER BY` is repaired with the primary
  key rather than refused, because refusing it would make the common
  "just give me a page" call an error.

## 1.2.0

### Features

- **grant-driven row scope (`resource`).** An entity carrying a `resource_key`
  column is now filtered — on reads *and* on writes — by the resource keys the
  current principal holds a grant on, with **no application-side resolver**. The
  C-5 grants and C-6 delegations already answered "which resources may this
  principal touch, and how strongly"; the new `TomResourceDataScope` (in the
  `authorization` module) simply asks them per query and binds the answer, and
  the new `TomResourceScopeSource` hook in `object_persistence` is the inversion
  that keeps `authorization → object_persistence` the only dependency direction.
  Wire it once at start-up with `TomResourceDataScope.install(delegationResolver)`.
  Delegations are folded in *through* `TomDelegationResolver` rather than around
  it, so the validity window, revocation, mode semantics and non-transitivity
  govern the row scope for free.

  The grades are the design: a row is admitted to a **query** at
  `TomAuthState.read` or wider and to a **write** only at `TomAuthState.full`, so
  a viewer's shared row is listed and opened while every attempt to modify it
  raises `TomDataScopeAuthorizationException` — the difference between "shared
  with me" and "mine". An unregistered role grades as nothing and grants nothing,
  so a typo in a grant row closes a door rather than opening one. Resolution is
  **live** (read per request, never from the token), so a revoked share stops
  granting at revocation rather than at token expiry;
  `TomResourceDataScope.runCached` amortises the several resolutions of one
  request into a single grant read without weakening that.

- **row scopes can distinguish read from write.** `TomDataScopeRegistry.register`
  and `registerAsync` now accept an optional `write:` resolver answering the
  narrower question "which values may this principal *modify*", threaded through
  `TomDataScope.build` / `buildAsync` / `allowedValues` / the new
  `allowedValuesAsync` by a `forWrite` flag and applied by the repository's three
  write guards. A kind that registers no write resolver writes exactly what it
  reads, so every pre-existing scope is unaffected. This is the general mechanism
  behind the `resource` kind's read/write grades; "may read every tenant, may
  write only my own" has the same shape.

### Behaviour Changes

- **grant scoping is now the default, not an opt-in.** `TomAnnotationAnalyzer`
  synthesises a `@TomDbScope(field: 'resource_key', scope: 'resource')` for any
  reflected entity exposing a `resource_key` column (or a `resourceKey` field),
  so forgetting the annotation can no longer silently publish every row. An
  entity that must stay global despite carrying such a column declares
  `@TomDbScope.unscoped()`.

  **Deployments that already have `resource_key` columns and no grant rows will
  see those entities return nothing** until the scope is installed and granted,
  which is the deny-by-default this change is for. The framework's own
  authorization tables are excluded twice over: they declare
  `@TomDbScope.unscoped()`, and they are additionally named in the constant
  `TomAnnotationAnalyzer.resourceScopeInputTables`. The constant is the
  load-bearing guard — it survives a stale generated `*.reflection.dart` whose
  class metadata predates the annotation, and a safety invariant must not depend
  on a deployment having re-run code generation before it upgrades. Scoping those
  tables would close the authorization layer against itself: a principal could
  reach its own grant rows only by already holding a grant on them, which no row
  can satisfy.

### Documentation

- `doc/object_persistence.md` gains a **Row Scopes** section covering the whole
  engine: the three built-in kinds, sync value lists versus async OR-unions and
  why the union is parenthesised, automatic scoping and its opt-out, the
  `runUnscoped` recursion guard, and the read-filters/write-rejects asymmetry.
- `doc/authorization.md` is brought up to date with the module it describes. It
  previously documented only the principal cache and opened by stating that
  nothing in the module grants or refuses anything, which the grant, delegation,
  grade and row-scope code has not been true of for some time.

## 1.1.4

### Bug Fixes

- **bare-flag bool coercion (RCJ2).** `TomArgs.fillFromArgs` recorded a bare
  flag (an argument with no `=`, e.g. `verbose`) as the String `"true"`, while
  its docstring claimed the reflection layer coerced it to the field's declared
  type. The reflection layer does **not** coerce a String into a `bool` field —
  it throws `reflection.set.unexpected_string_type` — so a bare bool flag could
  never fill a `bool` config field. Aligned `fillFromArgs` with
  `parseArgsToMap` by recording a bare flag as the boolean `true`, which
  matches how `key=true` already converts (`_convertString`) and keeps the
  reflection layer's strict String/typed contract intact. A bare flag now fills
  a reflected `bool` field directly; the pinned characterization test in
  `endpoints_pipeline_test.dart` was flipped from "throws" to assert success.
  Docstrings and `doc/cmdline.md` / `doc/api_reference/api_summary_cmdline.md`
  updated to describe the unified boolean encoding.

## 1.1.3

### Tests / Examples

- **cache direct-surface scaling (RCI4, one unblocked module).** Deepened
  `cache_test.dart` to the full connection-free public surface of the `cache`
  module (no public API change; 460 → 477 test cases). The prior suite covered
  the static `…NameCache`/`…TypeCache` helpers, LRU eviction, background-timer
  sweeps, worker-isolate forwarding, and the cross-isolate command objects — but
  the **direct `TomCache` instance surface** was only exercised transitively.
  This pass pins it directly:
  - **`getEntry`**: returns the stored entry object (unbounded), `null` for an
    absent key, promotes the read entry to MRU in a bounded cache, and — the
    distinctive contract — **does not check expiry** (an already-expired entry is
    still returned verbatim; expiry is `fromNameCache`'s job);
  - **`putEntry`**: unbounded store/overwrite, LRU eviction past the bound, and
    the single-entry update path (`cacheSize == 1` clear-and-re-insert);
  - **`removeEntry`**: no-op for an absent key, and middle-of-chain unlink that
    leaves a bounded cache's MRU chain coherent for later eviction;
  - **timer lifecycle**: the default one-hour `deletionIntervalSeconds` installs
    an active `deletionTimer` (and no `clearanceTimer`), both timers stay `null`
    when their intervals are `null`, a clear interval installs an active
    `clearanceTimer`, `stopTimers` cancels a running timer, and `createTimers`
    is idempotent (cancels and replaces the running timer);
  - **construction/properties**: `cacheName`/`deleteEntriesAfterSeconds`/
    `maximumEntries`/`clearIntervalSeconds` round-trip, `forType` names the cache
    `type.toString()`, and an unbounded cache reports a `null` `maximumEntries`.

  This is one module of the RCI4 unblocked residual; the remaining unblocked
  modules and the two blocked buckets (reflection-bootstrap and MariaDB fixtures)
  are filed as RCJ4 for later iteration.

## 1.1.2

### Tests / Examples

- **object_persistence full-surface scaling (RCF4, module 1 of 13).** Closed the
  connection-free public-surface gaps in the `object_persistence` query DSL and
  the SQL dialect (no public API change; 422 → 443 test cases). The prior
  `object_persistence_test.dart` covered `eq`/`gte`/`like`/`isNull`/`isIn`/
  `between` plus the save/annotation/injection paths; this pass added the
  remaining `TomQueryBuilder` builders and the dialect's value dispatch:
  - **comparisons**: `neq` (`<>`), `lt` (`<`), `lte` (`<=`), `gt` (`>`);
  - **string / null predicates**: `isNotNull`, `notLike`, `regexp`;
  - **literal builders**: `doubleOp`, `boolOp`, `dateTimeOp` (quoted ISO-8601),
    `dateOp` (unpadded `YYYY-M-D` — pinned so the non-padding is intentional);
  - **typed column references**: `doubleF`, `boolF`, `dateTimeF`, `dateF` (each
    renders the qualified `table.column` and collects itself as a field);
  - **dialect `objectOp` dispatch**: the runtime-type literal table
    (null→`NULL`, String→quoted+escaped, int/double/bool→bare, DateTime→quoted
    ISO-8601, Iterable→comma list) plus `nullOp`/`iterableOp`.

  The example gained matching steps 6–9. This is the first module of the RCF4
  per-module surface-scaling residual; the remaining 12 modules are filed as
  RCG1 for later iteration.

## 1.1.1

### Documentation

- **API reference (OT7).** Added a per-module API summary set under
  `doc/api_reference/` following
  `_copilot_guidelines/dart/api_summary_creation.md` — one
  `api_summary_{module}.md` for each of the 13 real modules (`authentication`,
  `authorization`, `cache`, `cmdline`, `configuration`, `datasources`,
  `db_migration`, `endpoints`, `healthcheck`, `little_things`,
  `object_persistence`, `server`, `transactions`) plus an
  `api_summary_index.md` with quick navigation, per-module type tables, and an
  alphabetical type index (~110 public types). Each summary lists only the
  public surface (constructors, properties, methods, operators, enums, and
  top-level functions/constants) cross-checked against the actual source and
  the package barrel. Placed under `doc/api_reference/` because this repo
  gitignores `**/doc/api/` (reserved for generated `dart doc` HTML). This
  delivers the "optional API summaries" deferred from the 1.1.0 OT3 pass
  (quest todo RCE4). No source or public API change.

## 1.1.0

> **OT3 verification (2026-07-15).** Re-confirmed the whole-package gates —
> `dart analyze` clean and `testkit :test` 422/422 green — and that all 13 real
> modules carry a one-to-one `doc/<module>.md`, `example/<module>/`, and
> `test/<module>_test.dart`. No code change; deeper per-module surface coverage
> and optional API summaries are tracked as quest todo RCE4.

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
