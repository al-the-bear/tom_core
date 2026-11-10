# tom_core_server

Published on pub.dev as [`tom_core_server` 1.3.0](https://pub.dev/packages/tom_core_server).

> **Attribution.** The Tom Framework is developed by Peter Nicolai Alexis Kyaw.
> These packages are BSD-3-Clause licensed and published on pub.dev.

> **⚠️ Work in progress — unstable API.** The Tom Core packages are under active
> development and not yet stable. Their version numbers carry no promise about
> API maturity: they are publishing counters, not semver. The patch number is
> bumped on every change — **including breaking changes** — so a patch bump may
> break you. Expect the public surface to shift without notice. Not recommended
> for production use yet.

Server-side runtime for the Tom Framework — an HTTP host, an endpoint pipeline,
and a relational persistence layer built on the platform-neutral kernel.

## Overview

`tom_core_server` is the backend layer of the Tom Framework. It builds on
[`tom_core_kernel`](../tom_core_kernel/README.md) (dependency injection,
observable state, security, resources) and adds everything a service needs:

- a **shelf-based HTTP host** (`TomServer`) with a middleware pipeline —
  request context, per-request IDs, authentication, logging, and JSON error
  mapping wrapped around a declarative **endpoint router** — and a **graceful
  shutdown** on SIGTERM that turns readiness off, refuses new requests, lets the
  requests and scheduled runs in flight finish, releases their leases and closes
  the connection pools;
- an **ORM-style persistence layer** — repositories with type-safe queries
  built from expression operators, persistence annotations, and a query
  builder, over pluggable **datasources** (MariaDB/MySQL and PostgreSQL
  drivers included) whose **read replicas** serve the repository reads of
  read-only work, with read-your-writes for the principal who just wrote;
- **versioned schema migrations** — one run per database at a time under a
  migration lock the database releases when the process dies, a repair command
  for a failed migration, a rollback with down scripts, and a convergence check that the entities, the
  migration chain and the live database still agree — **local/XA
  transaction** coordination with the **recovery** of branches a dead process
  left prepared, and **sagas** for work across services, each
  step a local transaction undone by its compensation when a later step fails;
- an **audit trail** that is attributable and tamper-evident, with **audit
  reports** above it — an auditor's questions asked across every writer of the
  trail, saved, and delivered on a schedule as CSV, XLSX or PDF exports by
  email — **outbound
  messaging** with a durable outbox and **per-recipient localized text**,
  **notifications** above it — application-declared types, per-user channel
  choices, quiet hours and hourly or daily digests, one message per recipient
  and chosen channel — an
  **idempotent receiver (inbox)** that lets a broker's consumer process a
  redelivered message once, a **bus relay** that publishes to a
  [`tom_core_message_bus`](../tom_core_message_bus/README.md) bus once the
  transaction the publish was queued in has committed,
  **tabular export** to CSV/XLSX/PDF with charts, by response, storage or
  email, under a per-owner quota and a retention purge,
  **streaming blob storage** behind one contract, with one copy per content,
  a per-owner quota and a sweep of files no row refers to, and relational **job
  scheduling** for a cluster that shares no filesystem;
- **data protection** for the GDPR — entities declare the column naming a
  person and the columns holding their data, and one call erases that person
  across every registered entity (deleting, anonymizing or unlinking each row as
  declared), exports what is held about them, or applies declared retention;
  their values in the audit trail are **crypto-shredded**, unreadable once the
  person is erased while the hash chain still verifies;
- the server side of **offline sync** — an entity exposed for sync has every
  write numbered in a change log, a device's queued changes are applied through
  the entity's repository under optimistic locking, and a device pulls what
  changed as its own principal, row scope and column grades applied;
- server **configuration** (typed config + YAML resources, with **secret
  references** resolved from HashiCorp Vault, AWS Secrets Manager or Azure Key
  Vault and refreshed when the store rotates them, and **feature flags** by
  tenant, role and stable percentage), an isolate-backed
  **cache**, **authentication/authorization** services, and **health** endpoints;
- first-class **multi-tenancy** — each tenant's data in a shared table, a schema
  of its own or a database of its own, chosen per tenant, with repositories,
  caches, revocations, jobs and the outbox kept apart by the tenant in context;
- **service accounts with scoped API keys** — issued once, stored as a hash,
  rotated and revoked on every node — and **request rate limits** per user, per
  API key or per client address, off until a deployment configures them;
- **metrics** recorded by every module — requests by route pattern, SQL
  statements and connection pools, cache lookups, rate-limit refusals and the
  scheduler's jobs — read by a **Prometheus scrape** answered ahead of
  authentication or pushed to an **OpenTelemetry collector over OTLP**;
- **tracing** with OpenTelemetry — a span per request, SQL statement,
  transaction, outgoing call, job run and outbox delivery, carried across
  services in `traceparent` and exported over OTLP to the same collector; off
  until `tracing` is configured, and free while off.

Because the barrel re-exports the kernel, a server app depends only on
`tom_core_server` — one import gives both the kernel API and the server stack.

## Installation

Add it from pub.dev:

```yaml
dependencies:
  tom_core_server: ^1.3.0
```

Then import the single barrel — it re-exports `tom_core_kernel`,
`tom_basics_console`, and the MariaDB client (`mysql_client`), so you rarely
import those directly:

```dart
import 'package:tom_core_server/tom_core_server.dart';
```

**SDK:** Dart `^3.10.0`. Modules that use reflection (persistence entities,
endpoint services) require `dart run build_runner build` to generate
`*.reflection.dart`. The relational layer targets two databases:
**MariaDB/MySQL** via `mysql_client` and **PostgreSQL 15+** via `postgres`. Both
drivers share one driver-neutral base, and the framework's own tables are
declared once and rendered in each database's words; the datasource, dialect,
migration, and repository contracts are abstract, so other backends can be
added.

## Features

### HTTP host & endpoints (`server`, `endpoints`)

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | The shelf-based HTTP host and its middleware pipeline; `logFormat: json` writes one JSON log line per entry, and the `httpClient` block sets the timeout, retry, circuit-breaker and bulkhead policies of every outgoing framework call (`configureHttpClients`) |
| `TomGracefulShutdown` / `TomServer.shutdown` | What the server does between SIGTERM (or SIGINT) and exiting: `/ready` answers `503`, the listener closes, a new request is refused with `503` and `Connection: close`, the requests and scheduled runs in flight get the grace period (`shutdownGracePeriodSeconds`) to finish, then the outboxes and schedulers release their leases and the data sources close their pools |
| `tomRequestContextMiddleware` / `tomRequestIdHeader` / `TomRequestIdPolicy` | Every request's correlation ids: the caller's W3C `traceparent` continued with a span of the server's own, and a request id — the trace id, or a trusted proxy's `X-Request-Id` (`requestIds` key) — echoed as `X-Request-Id`; carried as `request_id`, `trace_id` and `span_id` on every structured log line it writes |
| `TomSecurityHeaders` / `tomSecurityHeadersMiddleware` | The security headers every response carries unless it sets its own — HSTS on HTTPS, a deny-all `Content-Security-Policy`, `nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer` — configured by the `securityHeaders` block |
| `TomMutualTls` / `TomMutualTlsClientFactory` | Mutual TLS between services: a client certificate verified against the client CA and listed by its SHA-256 fingerprint authenticates its caller as a service principal, paths reserved for services refuse a request without one (`401`), and outgoing framework calls present this service's own certificate — configured by the `mutualTls` block |
| `TomEndpoint` / `TomEndpointHandler` / `TomEndpointRouting` | Endpoint declaration and the request-handling pipeline |
| `TomService` / `TomApiImplementation` / `TomTransactional` | Annotations that turn a class into a routed API, and mark a handler transactional; `@TomService(version: 2)` serves an API under a `/v2` path segment beside its other versions, and `problemJson: true` answers its errors as RFC 9457 problem documents |
| `TomFileEndpoint` / `TomFileSlots` / `TomFileSlot` | Upload/download/probe/delete over a `<table>/<id>/<column>` slot derived from the entity's own annotations — registered per repository, exposed only where `@TomFileReference` says so |
| `TomMultipartForm` / `TomFormFile` | HTML form bodies (multipart or url-encoded): text parts fold into the request DTO, file parts bind as typed parameters and upload through the same file slot |
| `TomRedirect` | The directive a handler returns to answer with a `3xx`, so the pipeline builds the response rather than the handler |
| `TomWebSocketEndpoint` / `TomWebSocketConnection` | Sockets as a *kind of endpoint* — same scan, access check and parameter binding, run inside the captured request zone, with their own connection lifecycle |
| `TomOpenApiService` / `TomOpenApiServer` | `GET /openapi.json`, public: serves the OpenAPI 3.1 document `tom_core_openapi` generates at build time, from the file the `openApiDocument` setting names |
| `TomErrorHandler` / `TomDefaultErrorHandler` | Maps a thrown exception onto the response the caller sees |
| `TomCors` | The CORS allow-list of browser origins, empty by default — no cross-origin page may read a response until the `cors` block lists its origin, exactly, with any port (`http://localhost:*`) or as `*` |
| `TomIdempotent` / `TomIdempotency` / `TomSqlIdempotencyStore` | Idempotency keys: an annotated endpoint answers a retry carrying the same `Idempotency-Key` with the first response instead of running again — kept in memory, or for a cluster in `tom_idempotency_key` through the `idempotency` block |

### Persistence (`object_persistence`, `datasources`)

| Type | Responsibility |
| ---- | -------------- |
| `TomRepository` / `TomSqlDatasourceRepository` | CRUD + type-safe query repository |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomReference` / `TomFileReference` / `TomDbScope` | Entity-mapping annotations |
| `TomQueryBuilder` + `Eq` / `And` / `Like` / `In` / `Gte` … | Type-safe query expressions |
| `TomAggregate` + `countAll` / `sum` / `avg` / `min` / `max`, `TomGroupedSelect`, `TomGroupedRow` | Grouping and aggregation — results come back as group keys plus aggregate values, not entities |
| `TomQuerySentenceCompiler` | Compiles a readable query sentence (`find first 25 skip 50 by name = :name order by age desc name asc`) into the same query objects the builder produces |
| `TomSubquery` / `TomExists` / `TomInSubquery` | Predicates about another result set — `EXISTS`, `IN (SELECT …)` — and association filters in a query sentence (`find by tags.name = :n`, `find by tags is empty`), compiled to a correlated `EXISTS` that answers each owning row once |
| `TomPageRequest` / `TomSortField` / `TomSortDirection` | The row window and the per-field sort a caller passes to `findAll`, `findAllById`, `findByQuery` and `findByQuerySentence` — cut out of the *scoped* rows, so `count()` reports the scoped total beside it |
| `TomVersion` / `TomOptimisticLockException` | Optimistic locking — a versioned entity's update and `delete(entity)` match the row only at the version the caller loaded, so a second save of one loaded row is refused rather than silently overwriting the first |
| `TomSoftDelete` / `TomHistory` / `TomEntityListener` / `TomEntityLifecycle` / `TomEntityChange` | The entity lifecycle — soft delete (a delete sets a deletion time and every repository read leaves the row out; `restoreById`, `purgeById`), history tables written before every update, delete and restore (`historyOf`), hooks before and after every save and delete, and change events for every insert, update, delete and restore; an observed entity's write, its history and its listeners' writes commit in one transaction, so a change listener writing an outbox row publishes exactly the committed changes |
| `TomEncrypted` / `TomBlindIndex` / `TomFieldEncryption` / `TomFieldKeyring` / `TomFieldReencryption` | Field-level encryption at rest — an annotated field is stored as AES-256-GCM ciphertext and read as plaintext, found by value through a blind index, under data keys kept in `tom_encryption_key` wrapped by a key-encryption key from the `fieldEncryption` block, rotated without downtime and re-encrypted by a background pass in every tenant |
| `TomBlobOrphanSweep` / `TomRepositoryBlobReferences` | Deletes the files of a deduplicating blob store that no row refers to — asking each entity's `@TomFileReference` columns, soft-deleted rows included — once they are older than a grace, then reclaims their content; also as a scheduler job |
| `TomDataScope` / `TomDataScopeRegistry` / `TomColumnAuthorization` | Row scoping ANDed into every query — `owner`, `group` and the grant-driven `resource` kind, the last applied automatically to any entity with a `resource_key` column — and per-column read/write rights enforced by the repository |
| `TomDataSource` / `TomSqlDatasource` | The data-source contract, and the driver-neutral SQL base both drivers extend: pool, a connection per transaction, statement paths, row mapping, and `withSessionLock`, a database-wide lock released when its holder's session ends |
| `MariaDbDatasource` / `MariaDbXADatasource` | MariaDB/MySQL drivers (`mariadb`, `mariadb_xa`) |
| `PostgresDatasource` / `PostgresXADatasource` | PostgreSQL 15+ drivers (`postgresql`, `postgresql_xa`) |
| `TomReplicaRouting` / `TomPrimaryReads` | Read replicas — a data source's `replicas` serve the repository reads of read-only work (a read-only transaction, a `GET`/`HEAD` request, a `readOnly` block), round-robin, with read-your-writes per principal and a failed replica left out while the primary serves; `@TomPrimaryReads` pins an entity's reads to the primary |
| `TomDbType` family / `TomStandardSqlDialect` / `MariadbSqlDialect` / `PostgresSqlDialect` | Typed columns and SQL rendering, including the framework's canonical DDL in each database's words |
| `TomSelect` / `TomCount` / `TomDelete` / `TomUpdate` / `TomGroupedSelect` / `TomLiteralSelect` | Generated query objects, plus the raw-SQL escape hatch |

### Schema & transactions (`db_migration`, `transactions`)

| Type | Responsibility |
| ---- | -------------- |
| `TomDbMigrator` / `TomDbMigrations` / `TomDbVersion` | Versioned schema migrations, run under a per-database migration lock so replicas starting together apply each script once |
| `TomMigrationRepair` / `TomDbMigrations.repair` / `TomDbMigrations.repairFromArgs` | Resolving a migration recorded as failed — removed to be applied again, or marked resolved — from code or with `--repair-migration` / `--repair-action` |
| `TomDbMigrations.rollback` / `TomDbMigrations.rollbackFromArgs` / `TomMigrationScript` | Undoing the migrations applied above a version with the down scripts beside them (`[3]-add_column.down.sql`), newest first — from code or with `--rollback-migrations` |
| `MariadbMigrationAdaptor` / `PostgresMigrationAdaptor` | The MariaDB and PostgreSQL migrators, each serving the plain and the two-phase (`_xa`) data-source type — on PostgreSQL a script and its version row run as one transaction |
| `TomSchemaConvergenceCheck` / `TomSchemaModel` / `TomEntitySchemaReader` / `TomSchemaDivergence` | Checks that the entities, the migrations and the live database still describe the same schema, and names each divergence |
| `TomTransactionManager` / `TomTransaction` / `TomTransactionParticipant` | Local and two-phase transaction coordination (XA on MariaDB, prepared transactions on PostgreSQL) |
| `TomTransactionRecovery` / `TomSqlDecisionLog` | Recovery of the branches a process that died between the two phases left prepared: the coordinator records its decision before the commit phase, and a recovery — at start with `recoverOnStart`, or on demand — commits the decided branches and rolls back the rest |
| `TomSagaOrchestrator` / `TomSaga` / `TomSagaStep` / `TomSqlSagaStore` | Sagas: work across services run step by step, each step a local transaction with the saga's move guarded by its version, the steps already done compensated last first when a step fails for good — on the kernel's job scheduler, kept in `tom_saga`, resumed after a restart in every tenant |

### Platform services (`configuration`, `cache`, `authentication`, `authorization`, `item_authorization`, `tenancy`, `ratelimit`, `metrics`, `tracing`, `audit`, `audit_reports`, `privacy`, `messaging`, `notifications`, `resources`, `export`, `file_storage`, `scheduling`, `preferences`, `sync`, `healthcheck`, `cmdline`, `little_things`)

| Module | Key types | What it does |
| ------ | --------- | ------------ |
| `configuration` | `TomBaseServerConfiguration`, `TomServerConfigResourceProvider`, `TomConfig<T>`, `TomYaml`, `TomSecrets`, `TomSecretsProvider`, `TomFeatureFlagsServer` | Typed config + YAML resources; any value may be a `secret:<provider>:<path>[#<field>]` reference, loaded from a secret store before the configuration is built, substituted with the precedence of the source it was written in, and refreshed fail-soft with watchers for rotation. The Vault, AWS Secrets Manager and Azure Key Vault providers are the libraries of `tom_core_secrets`, in `tom_core_extensions`. The `featureFlags` key holds feature flags by tenant, role and stable percentage, installed at start and served to clients by `GET /feature-flags` |
| `cache` | `TomCache`, `TomCacheManager` | Isolate-backed server-side cache |
| `authentication` | `TomAuthenticationService`, `TomAuthenticationData`, `TomAuthenticationAdaptor`, `Tom2FAAdaptor`, `Tom2FAService`, `Tom2FARegistry`, `TomTotp2FAService`, `TomServerSelfLogin`, `TomOAuthAuthenticationService`, `TomOAuthFlow`, `TomOAuthProviders`, `TomSamlProviders`, `TomSamlFlow`, `TomExternalRoleMapping`, `TomExternalIdentityStore`, `TomScimService`, `TomScimProvisioning`, `TomScimIdentityDirectory`, `TomJwtSigning`, `TomJwksService`, `TomApiKeys`, `TomServiceAccount`, `TomSqlApiKeyStore`, `TomSessionCookie` | Authentication service and adaptor annotations; tokens signed RS256 (default), ES256 or HS256 from configured key files, verified by key id through a rotation, and published as a JSON Web Key Set at `/.well-known/jwks.json`; second-factor challenges behind one service contract, with a TOTP implementation and a registry that picks the factor per principal; a server's own login when it calls another service as itself; and external identity — an OAuth 2.0 / OIDC authorization-code + PKCE login written as *another implementation of the same service contract*, so it reaches the unchanged token and 2FA path instead of a second one; and enterprise single sign-on over OpenID Connect (endpoints read from the issuer's discovery document, nonce-bound `id_token`) or SAML 2.0 (signed responses verified against the identity provider's metadata), with group claims mapped onto roles on every login and just-in-time provisioning; and user provisioning over SCIM 2.0 — the `/scim/v2` endpoints Entra ID and Okta provision users and groups through, with deactivation and group changes revoking the sessions they affect on every node, and single sign-on resolving to the provisioned account; and service accounts authenticating with API keys in `X-API-Key` — shown once as `tomk.<keyId>.<secret>`, stored as a SHA-256 hash, scoped to a subset of the account's roles, rotated with an optional overlap and revoked on every node that shares the cache invalidation channel; and browser sessions holding the access token in an `HttpOnly` cookie, every unsafe request authenticated by it held to a double-submit CSRF check |
| `authorization` | `TomAuthorizationCache`, `TomResourceGrant`, `TomGradedAccessControlInformation`, `TomPrincipalResourceGrant`, `TomPrincipalDelegation`, `TomDelegationResolver`, `TomResourceDataScope` | Isolate-backed authorization cache; graded per-key grants that add the middle states the kernel's granted/denied list cannot express; per-principal-per-resource roles; delegation of those roles by explicit share, out-of-office window, or revocable hand-over; and the row scope that filters an entity's rows by those grants — `read` to list, `full` to write — with no application-side resolver |
| `item_authorization` | `TomItemAuthority`, `TomItemAuthorizationClient`, `TomItemAuthorityScopeSource` | Item authorizations kept by an external authority such as Tom UAM, for an application that keeps none of its own: checks and accessible-item lists asked through a transport-neutral port and cached until the authority's webhook or change feed names their item or subject; the user's share, change and revoke carried with the user's token; and the `resource` row scope fed from the same answers, so a list shows what the user owns and what was shared with them |
| `tenancy` | `TomTenancy`, `TomTenant`, `TomTenantIsolation`, `TomTenantHostResolver`, `TomTenantHeaderResolver` | Multi-tenancy. A **tenant** is an isolation boundary — not an organization, which is a business unit inside a tenant. Each tenant's data lives in the shared database, a schema of its own or a database of its own, chosen per tenant and reached through one data-source routing seam; a request's tenant is its token's `tenant` claim, or before login its host or a header; `@TomTenantTable` entities are routed, filtered and checked per tenant, every other entity is a system table in the system schema |
| `ratelimit` | `TomRateLimits`, `TomRateLimitRule`, `TomRateLimitScope`, `TomMemoryRateLimiter`, `TomSqlRateLimiter`, `tomRateLimitMiddleware` | Request rate limits per signed-in user, per API key or per client address, as sliding-window counters kept per node or in a table every node shares; a request over a limit is answered `429` with `Retry-After`, an admitted one carries `RateLimit-*` headers. Nothing is limited until a deployment configures `rateLimits`; behind a proxy the client address is read from `X-Forwarded-For` only from a trusted proxy |
| `metrics` | `tomRequestMetricsMiddleware`, `tomMetricsEndpointMiddleware`, `TomOtlpHttpTransport`, `TomOtlpMetricsExporter` | The series every module records into the kernel's `TomMetrics.registry` — requests by method, route pattern and status, SQL statements and pool usage per data source (and per tenant pool), cache hits and misses, rate-limit refusals, and the scheduler's job lag, duration, outcomes and backlog — exposed as a Prometheus scrape at `/metrics`, answered before authentication with a bearer token of its own, and pushed cumulatively to an OTLP/HTTP collector, once more on shutdown. Both are off until `metricsEndpoint` / `otlpEndpoint` are configured |
| `tracing` | `TomOtelTracer`, `TomUntracedClient`, `TomInMemorySpanExporter`, `TomTracingException` | The OpenTelemetry tracer behind the kernel's `TomTracing` seam: the server span of every request (`<METHOD> <route>`), and the spans of SQL statements (the statement as written, never a bound value), transactions, outgoing HTTP calls, job runs and the outbox's send and delivery, carried across services in `traceparent` and through the outbox in the message's headers, sampled parent-first and exported over OTLP/HTTP to the metrics' `otlpEndpoint`. Off until `tracing` is configured, and no span is made while it is off |
| `audit` | `TomAuditTrail`, `TomAudited`, `TomAuditRecord`, `TomAuditSink`, `TomSqlAuditSink`, `TomAuditAnchor`, `TomAuditAnchorStore`, `TomAuditAnchorPublisher` | Attributable, tamper-evident trail written at the endpoint and repository chokepoints, stored in memory, in append-only files, or in a table whose write-once guarantee is the grant it is served with — and anchors, published outside the server, that turn a wholesale rewrite or a truncation from invisible into provable |
| `audit_reports` | `TomAuditReports`, `TomAuditView`, `TomAuditQuestion`, `TomSqlAuditQuestionStore`, `TomAuditReportsServer` | The reporting surface above the trail: a question asked across every writer and merged by time, saved by an auditor with a cron schedule, recipients and a format, and delivered when due as a CSV, XLSX or PDF export by email, each delivery recorded in the trail. Served to the `auditor` role as the kernel's `tomAuditReportsApi` under `/audit-reports` |
| `privacy` | `TomPrivacy`, `TomDataSubject`, `TomPersonal`, `TomRetention`, `TomSubjectKeys`, `TomSqlSubjectKeyStore` | GDPR tooling over the application's own repositories: `@TomDataSubject` marks the column naming a person and what erasing them does to the row (delete, anonymize, unlink), `@TomPersonal` the columns holding their data, `@TomRetention` how long rows are kept; `erase` reaches every registered entity and is audited, `exportSubject` renders everything held about a person as CSV, XLSX or PDF, and a retention job deletes or anonymizes what is past its time. With subject keys installed, personal values in the audit trail are sealed per person, and erasing them shreds the key — the values become unreadable while the hash chain still verifies |
| `messaging` | `TomMessage`, `TomMessageTransport`, `TomSmtpTransport`, `TomMessageOutbox`, `TomInbox`, `TomBusRelay` | Outbound messages: a channel-neutral shape, SMTP, and a durable outbox on the kernel's job scheduler; an idempotent receiver for consuming a broker's messages once; the bus relay, the transactional outbox for a `TomMessageBus` of `tom_core_message_bus` |
| `notifications` | `TomNotificationType`, `TomNotificationCatalog`, `TomNotificationAudience`, `TomNotification`, `TomNotificationPreferences`, `TomQuietHours`, `TomTemplatedNotificationRenderer`, `TomNotificationDispatcher`, `TomNotificationDigests`, `TomNotificationPreferencesServer` | The notification model above messaging: notification types the application declares with the channels each may use, the audience that resolves who receives one, each user's channel choices, cadence and quiet hours stored as ordinary user preferences (role and deployment defaults included), every message rendered from resource keys in the recipient's locale, and one message per recipient and chosen channel queued on the outbox under an id derived from the notification — so a repeated dispatch sends nothing twice. A user who chose an hourly or daily cadence receives one digest message per channel instead, kept until due as a pending job run in the outbox's store. `GET /notification-preferences` lists the types and the caller's channels for a settings screen |
| `resources` | `TomTextLocale`, `TomLocalizedTextResources`, `TomResourceLocaleException` | Per-recipient text for a server that renders many languages at once: the locale is an argument rather than ambient state, bundles resolve along a fallback chain *per key* so a half-translated language serves what it has, and a missing key answers `null` instead of the key — right on a screen, unacceptable in a subject line |
| `export` | `TomTabularResult`, `TomTabularChart`, `TomTabularRenderer`, `TomCsvRenderer`, `TomXlsxRenderer`, `TomPdfRenderer`, `TomExportService`, `TomExportStore`, `TomExportEmailDelivery`, `TomExportRegister`, `TomExportQuota`, `TomExportRetention` | CSV/XLSX/PDF rendering from one streaming tabular shape, with bar, line and pie charts of a section's rows (vector graphics in PDF, native charts in XLSX); streamed back to a caller, into storage, or by email through the messaging outbox as a link or an attachment; a register of stored exports (`tom_export`) that a per-owner quota counts against and a retention purge, by hand or scheduled, works from |
| `file_storage` | `TomBlobStore`, `TomDatabaseBlobStore`, `TomDirectoryBlobStore`, `TomS3BlobStore`, `TomMemoryBlobStore`, `TomBlobStoreInfo`, `TomDeduplicatingBlobStore`, `TomSqlBlobLedger`, `TomBlobQuota`, `TomFileReference` | Streaming blob storage behind one four-method contract, backends chosen in configuration, a store in front of any backend that keeps each distinct content once, holds each owner to a quota and reclaims content no key names, and entity columns that hold a storage key instead of the bytes |
| `scheduling` | `TomSqlJobStore`, `TomSqlLeaseLock` | The kernel's job-store and lease-lock contracts over a shared database, so a cluster whose nodes share no filesystem still runs each window exactly once — with priorities, paused jobs and run checkpoints shared by every node, and finished runs moved to an archive table |
| `preferences` | `TomUserPreference`, `TomUserPreferenceRepository`, `TomUserPreferences`, `TomUserPreferencesServer` | Per-principal preferences that follow the user across devices: one scoped table, a typed service that reads its caller from the request zone, and the `/preferences/*` endpoints behind the kernel's contract |
| `sync` | `TomSync`, `TomSqlSyncLog`, `TomSyncServer`, `TomSyncRejection` | The server side of the kernel's offline sync protocol. An entity exposed under a collection name has every write recorded in a change log inside the write's transaction and numbered per collection by the next pull, in commit order; a device's push is applied through the entity's repository under optimistic locking on the change's base version and answered `applied`, `conflict` or `rejected`; a pull reads the changed entities through the repository as the caller, so the row scope, column grades and decryption apply, while a deletion reaches every device. Served as `POST /sync/push` and `POST /sync/pull`, which the kernel's `TomHttpSyncTransport` calls |
| `healthcheck` | `TomHealthService`, `TomHealthServer`, `TomHealthAnalyzer`, `TomFrameworkReadinessAnalyzer` | Liveness at `/health` and readiness at `/ready`, each with a pluggable analyzer — process-wide, or a service instance's own — whose timed-out analysis is cancelled cooperatively; `/ready` answers by default with the framework's own checks — data sources answering `SELECT 1`, no migration running or failed, started outboxes delivering — one line per check in the body — and `503 shutting down` once a graceful shutdown has begun |
| `cmdline` | `TomArgs`, `TomEnvFile` | Argument parsing and `.env` loading |
| `little_things` | `TomServerException`, `TomLoginException`, `tomErrorEnvelope`, `tomErrorResponse` | Server exception base (extends kernel `TomException`), correlated with the kernel's request id in the zone, and the login failure it raises; the error envelope every error response carries, answered as an RFC 9457 problem document (`application/problem+json`) to a caller that asks for one |

## Quick start

Construct a server from a configuration and start it:

```dart
import 'package:tom_core_server/tom_core_server.dart';

void main(List<String> argv) {
  // `configuration` is your subclass of TomBaseServerConfiguration.
  final server = TomServer(configuration);
  server.start(); // HTTP host listening; endpoints routed
}
```

Parse command-line arguments and a `.env` file into typed values:

```dart
final config = TomArgs.fillFromArgs(argv, MyServerArgs()); // reflected key=value
final env = TomEnvFile.read('.env');                       // typed map
```

## Example projects

Every module ships a runnable sample under [`example/`](example/). All of them
run without a database — including the datasource, persistence and migration
samples, which demonstrate SQL rendering, repository wiring and migration
planning against in-memory stand-ins. The sole exception is
[`example/scheduling/cluster/`](example/scheduling/cluster/), whose three
programs are nodes of one demonstration and expect a live MariaDB and each
other.

<a id="a-green-example-run-is-a-verification"></a>

**A green run is a verification, not a transcript.** Each example states its
expectations through the shared
[`example/_support/check.dart`](example/_support/check.dart), which **throws**
when one does not hold. Deliberately not `assert`: `dart run` leaves assertions
*disabled* — that is what its `--enable-asserts` flag is for — so an `assert`
would compile out under the very command each example's header documents,
leaving a sample that prints a plausible transcript and exits 0 with every
expectation in it violated. That is not a hypothetical and it is not left as
prose: `test/fixtures/` holds two programs identical but for that one line, and
`test/examples_test.dart` runs both — the `check` exits non-zero and stops
before its next step, the `assert` exits **0** and runs to the end, and only
`--enable-asserts` makes it fail.

`test/examples_test.dart` holds the property for the set rather than per
example, which is what makes it cover samples added later: it requires that no
file under `example/` contains `assert(`, that none re-declares a local `check`,
that none makes a check inside a handler that would catch it — the same silence
in a different spelling — that the shared helper throws rather than narrating,
and that every example program is either spawned by its module suite, spawned
there, or excluded with a stated reason.

| Sample | Demonstrates |
| ------ | ------------ |
| [`example/server/`](example/server/) | The pieces `TomServer` composes its pipeline from; `graceful_shutdown_example.dart` runs a graceful shutdown step by step — readiness off, a new request refused, the request and the scheduled run in flight finished, the lease released |
| [`example/endpoints/`](example/endpoints/) | Declaring routed endpoints; `idempotency_example.dart` sends a request, its retry, a reused key and another caller's key through the idempotency-key handling |
| [`example/object_persistence/`](example/object_persistence/) | Repositories, annotations, query builder; `entity_lifecycle_example.dart` shows soft delete, history tables, the listener registry and a change event as JSON; `subquery_example.dart` builds `EXISTS`, `NOT EXISTS` and `IN (SELECT …)` |
| [`example/datasources/`](example/datasources/) | SQL-typed values and dialect rendering; `read_replicas_example.dart` shows which statements a read replica may serve, read-only work, the entities pinned to the primary and the replica settings |
| [`example/db_migration/`](example/db_migration/) | Versioned schema migrations; `db_migration_repair_example.dart` shows the migration lock's name and wait, down-script naming, and refuses malformed repair and rollback requests |
| [`example/transactions/`](example/transactions/) | Local/XA transaction coordination; `transaction_recovery_example.dart` records commit decisions and recovers prepared branches — the decided one committed, the undecided one rolled back; `saga_example.dart` runs sagas — steps in order, compensation last first, a failed compensation and a saga resumed after a restart |
| [`example/configuration/`](example/configuration/) | Typed config + YAML resources; `secrets_example.dart` walks secret references — precedence, an unloaded reference refused, rotation and a third-party provider |
| [`example/cache/`](example/cache/) | Isolate-backed cache |
| [`example/authentication/`](example/authentication/) · [`example/authorization/`](example/authorization/) | Login and second factors, external identity and SCIM provisioning; the authorization cache, graded grants, resource roles and delegation, and the grant-driven row scope those grants filter the database with |
| [`example/audit/`](example/audit/) | Audit records, the declared/automatic split, the hash chain, the relational trail's schema and its write-once check, and signed anchors published outside the server |
| [`example/audit_reports/`](example/audit_reports/) | A question asked across two writers of the trail, its filter read back from JSON, saved with a weekly schedule, delivered as a CSV by email when due, and moved to the next week |
| [`example/privacy/`](example/privacy/) | The personal-data declarations the framework's own entities carry, a value sealed and opened under a subject key and refused under another field, the audit trail sealing a personal value, revealing it, shredding the subject and the chain still verifying, and a malformed `privacy` configuration refused |
| [`example/messaging/`](example/messaging/) | Message composition, the MIME document, stand-in transports, the durable outbox, the idempotent receiver |
| [`example/notifications/`](example/notifications/) | Notification types and their policy, a category choice and an opt-out, a mandatory type that cannot be turned off, one notification fanned out to the outbox, a repeated dispatch sending nothing twice, quiet hours in a time zone, an urgent notification going through them, and a daily digest sent as one message |
| [`example/export/`](example/export/) | The streaming tabular shape, the same shape with its columns derived from a reflected entity — rendered against the hand-written one byte for byte — CSV/XLSX/PDF renderers with a chart, the format registry, one export through all three storage backends, the response and storage channels, the email channel by link and attachment, and the register with its quota and retention purge |
| [`example/resources/`](example/resources/) | Localized text as an argument rather than ambient state: bundle sets from maps, the three-rung per-key fallback chain, the locale a principal carries, and the `isTranslated` completeness check |
| [`example/preferences/`](example/preferences/) | The five-piece bootstrap a user preference needs — reflection, the datasource name, the bean, a principal-carrying zone and the migration — with a scalar and a `@tomReflector` object written and read back through the shipped service |
| [`example/sync/`](example/sync/) | The sync API's two `POST` routes from the kernel's contract, the change log's tables holding a number and the entity's id but no values, a change of a collection nothing is exposed under rejected and a pull of one refused, and a push request read back as the endpoint reads it |
| [`example/file_storage/`](example/file_storage/) | The one streaming blob contract, the key grammar, the infrastructure-free backends, configuration-driven selection, generated file-reference keys and the blob-backed export store; deduplication, the per-owner quota, the reclaim and the orphan sweep |
| [`example/scheduling/`](example/scheduling/) | The relational job queue and lease lock: the schema and why each constraint is load-bearing, the shipped migrations, the UTC instant encoding, and the cluster wiring. [`example/scheduling/cluster/`](example/scheduling/cluster/) adds the part that needs a database — two real nodes arbitrating over one MariaDB, asserted rather than narrated |
| [`example/ratelimit/`](example/ratelimit/) | A service account's scoped API key authenticating requests through the server's own middlewares, limits per key and per anonymous address answering `429` with `Retry-After`, a rotation and a revocation |
| [`example/tenancy/`](example/tenancy/) | Two tenants in one deployment: request resolution by host, header and token, a login binding its token, and caches, revocations, jobs and the outbox kept apart |
| [`example/metrics/`](example/metrics/) | Requests counted by route pattern rather than path, a scrape refused without its token and answered with it, cache lookups in the same scrape, and the registry pushed over OTLP to an in-process receiver and once more on close |
| [`example/tracing/`](example/tracing/) | A request continuing its caller's trace as a server span named after its route, its transaction and outgoing call as children, the callee continuing the call's span, and the tree exported over OTLP to an in-process receiver |
| [`example/healthcheck/`](example/healthcheck/) | The liveness and readiness verdicts and what a probe acts on, two instances with analyzers of their own, and an analysis cancelled at its deadline; `readiness_logging_example.dart` adds the framework readiness checks and the JSON log line a request writes with its trace and request ids |
| [`example/cmdline/`](example/cmdline/) · [`example/little_things/`](example/little_things/) | CLI and exceptions |

Run a single example, or all of them:

```bash
dart run example/datasources/datasources_example.dart
dart run example/tom_core_server_example.dart   # every sample, in reading order
```

[`example/tom_core_server_example.dart`](example/tom_core_server_example.dart)
is the runnable form of the table above: one line per program saying what it
shows, and a runner that spawns each in turn and fails if any of them does not
exit 0. The four programs it declines are named in it with their reasons, and
`test/examples_test.dart` requires the two lists together to be exactly the
example programs in the package — so a sample added later appears there rather
than quietly not being on the tour.

## Usage

### Connecting a datasource (MariaDB/MySQL or PostgreSQL)

A driver is configured by its connection fields, then `connect()` opens the
live connection:

```dart
final ds = MariaDbDatasource()
  ..host = 'localhost'
  ..port = 3306
  ..username = 'tom'
  ..password = 'secret'
  ..databaseName = 'tomdb';
await ds.connect(); // throws MariadbDatasourceException on failure
```

The PostgreSQL driver takes the same fields, plus the schema its connections
work in and how they are encrypted:

```dart
final pg = PostgresDatasource() // port defaults to 5432
  ..host = 'localhost'
  ..username = 'tom'
  ..password = 'secret'
  ..databaseName = 'tomdb'
  ..schema = 'app' // the session's search_path; empty keeps `public`
  ..sslMode = 'verifyFull'; // disable | require (default) | verifyFull
await pg.connect();
```

In configuration a data source names its driver by `type` — `mariadb`,
`mariadb_xa`, `postgresql` or `postgresql_xa` — see
[`doc/datasources.md`](doc/datasources.md#the-sql-drivers). A `replicas` list
adds read replicas, each overriding only what differs from the primary:

```yaml
datasources:
  main:
    type: postgresql
    host: db-primary
    databaseName: app
    username: app
    password: ${DB_PASSWORD}
    replicas:
      - host: db-replica-1
```

The repository reads of read-only work — a read-only transaction, a `GET` or
`HEAD` request, a `TomReplicaRouting.readOnly` block — then go to a replica,
everything else to the primary; see
[Read Replicas](doc/datasources.md#read-replicas).

> **MySQL-in-Docker.** The runnable end-to-end story — a Docker Compose MySQL
> plus bootstrap and migrations — ships with the
> [`tom_core_samples/core_server_sample`](../tom_core_samples/core_server_sample/README.md)
> project (see the [samples map](../tom_core_samples/README.md)). This package
> provides the abstract contracts and the two drivers it builds on.

### Repositories and type-safe queries

Repositories expose CRUD plus queries built from the expression operators
(`Eq`, `And`, `Like`, `In`, `Gte`, …):

```dart
final all  = await repository.findAll();
final one  = await repository.findById(42);
final some = await repository.findByQuery(query, params);
```

A grouped query is the one whose rows are not entities — its shape is decided by
the query, so it comes back as group keys plus aggregate values:

```dart
final rows = await repository.findGroupedByQuery(groupedQuery, params);
for (final row in rows) {
  print('${row.stringValue('status')}: ${row.intValue('n')}');
}
```

### Rendering SQL through the dialect

The dialect renders literals and bound-parameter placeholders, keeping untrusted
input out of the SQL string:

```dart
final dialect = TomStandardSqlDialect();
print(dialect.text('abc'));     // 'abc'
print(dialect.objectOp([1, 2, 3])); // 1,2,3
print(dialect.p('userId'));     // :userId
```

### Authentication, authorization, and health

`TomAuthenticationService` (with `TomAuthenticationAdaptor` / `Tom2FAAdaptor`
annotations) drives login, and `Tom2FARegistry` picks the second factor for a
principal — `TomTotp2FAService` ships as one. `installJwtSigning` reads the
token signing from the configuration into `TomJwtSigning`: RS256 by default,
ES256 or HS256, with each key named by its RFC 7638 thumbprint, so a rotation
keeps old tokens verifying, and `TomJwksService` publishes the public keys at
`GET /.well-known/jwks.json` for any verifier. `TomAuthorizationCache` caches
authorization decisions on an isolate, over grants that are graded per key
(`TomResourceGrant`), held per resource (`TomPrincipalResourceGrant`), and
lendable to another principal (`TomPrincipalDelegation`).
`TomHealthService` / `TomHealthServer` expose health endpoints backed by
`TomHealthAnalyzer`s.

Those same grants filter the database. Install `TomResourceDataScope` once and
every entity carrying a `resource_key` column is scoped to the keys the current
principal holds a grant on, on reads *and* on writes — a `read` grade lists the
row, only `full` may change it, and resolution is live, so a revoked share stops
granting on the next request rather than at token expiry:

```dart
TomResourceDataScope.install(delegationResolver);
```

"Sign in with …" is wired in as one line, because it is not a second login path:

```dart
TomAuthenticationServer.globalSettingUserAuthenticationService =
    TomOAuthAuthenticationService(
      directory: MyDirectory(),  // your account lookup + provisioning policy
      delegate: TomAuthenticationServer.globalSettingUserAuthenticationService,
    );
```

`TomOAuthAuthenticationService` **implements `TomAuthenticationService`**. It
receives a `TomOAuthCredential` where a password login receives a password,
exchanges the authorization code, resolves the local account through
`TomExternalIdentityStore`'s `(issuer, subject)` linking table — and then stops.
It issues no token, consults no 2FA policy and makes no session decision,
because the result is handed to the same continuation a password login reaches.
An externally authenticated principal is therefore challenged for its second
factor and issued exactly the claims a password login would produce, not because
this is reimplemented but because it is never touched. Any credential that is
not a `TomOAuthCredential` passes through to the `delegate`, so an account may
hold a password *and* several external identities at once.

Providers are configuration data (`oauth.providers`), never code, and what a
first external login with no local account does — `autoProvision` (the
default), `linkExisting` or `refuse` — is per-provider configuration too.

Enterprise single sign-on is the same login. An OpenID Connect provider —
Entra ID, Okta, Keycloak — sets `discovery: true` and names its issuer, and
`TomOAuthProviders.load()` reads its endpoints at start-up; a SAML 2.0 identity
provider is configured under `saml.providers` from its metadata, and
`TomSamlProviders.load()` fetches it. Both kinds are listed, begun and completed
through `/oauth/*`, with SAML adding its assertion consumer service
(`POST /saml/acs`) and metadata (`GET /saml/metadata/<providerId>`).
`groupsClaim` / `roleMapping` turn the provider's groups into Tom roles on every
login:

```dart
TomBean.withType<TomOAuthProviders>(await TomOAuthProviders.load());
TomBean.withType<TomSamlProviders>(await TomSamlProviders.load());
```

The same identity provider can keep the accounts themselves over SCIM 2.0:
installing a `TomScimProvisioning` serves `/scim/v2`, admitting the bearer
secrets configured under `scim.bearerTokens`, and a user deactivated or removed
from a group there loses the sessions it holds.

A non-human caller — a nightly import, a partner's integration — is a service
account with an API key rather than a login. The key is shown once, presented
as `X-API-Key`, and resolves to an authenticated principal holding the key's
roles, so every access rule applies to it unchanged:

```dart
final keys = TomApiKeys(store: TomMemoryApiKeyStore());
TomApiKeys.install(keys);
await keys.saveAccount(
  const TomServiceAccount(id: 'importer', name: 'Nightly import',
      roles: ['import', 'read']),
);
final issued = await keys.issue('importer', roles: ['import']);
print(issued.value); // tomk.<keyId>.<secret> — stored nowhere
```

Rate limits are off until configured; a `rateLimits` block counts requests per
user, per API key or per anonymous address and answers `429` with
`Retry-After` (see [`doc/ratelimit.md`](doc/ratelimit.md)).

Every call the framework makes to another service — an identity provider, the
object store, the OTLP receiver, a webhook or gateway, a secret store — runs
under the kernel's resilience policies: a 30-second timeout per API call, retries for calls
that may be repeated, and a circuit breaker and a bulkhead per destination. An
`httpClient` block changes them, overall and per destination (see
[`doc/configuration.md`](doc/configuration.md#outgoing-http-calls)).

An endpoint annotated `@TomIdempotent()` makes a client's retry safe: a request
carrying an `Idempotency-Key` runs once, and a retry with the same key gets the
stored response, marked `Idempotent-Replayed: true`. The records are kept in
memory unless an `idempotency` block names a data source, which every instance
then shares (see [`doc/endpoints.md`](doc/endpoints.md#idempotency-keys)).

See [`doc/authentication.md`](doc/authentication.md).

## Architecture

```text
                       TomServer (shelf host)
                            │
         middleware: shutdown gate · context · metrics · request-id · auth · rate limits · logging · JSON errors
                            │
                    TomEndpointRouting
                            │
         ┌──────────────────┼───────────────────┐
   object_persistence   transactions        services
   (TomRepository)   (TomTransactionMgr)  (auth · cache · health)
         │
     datasources  →  TomSqlDatasource → MariaDbDatasource / PostgresDatasource (+ XA variants)
         │
     db_migration  →  TomDbMigrator (versioned schema)
```

| Type | Responsibility |
| ---- | -------------- |
| `TomServer` | HTTP host + middleware pipeline |
| `TomEndpointRouting` | Maps requests to endpoint handlers |
| `TomRepository` | CRUD + type-safe query repository |
| `TomDataSource` / `MariaDbDatasource` / `PostgresDatasource` | Database connection drivers |
| `TomQueryBuilder` | Builds type-safe queries from expression operators |
| `TomDbMigrator` | Applies versioned schema migrations |
| `TomTransactionManager` | Coordinates local and two-phase transactions |
| `TomSagaOrchestrator` | Runs sagas: local transactions with compensations, across services |
| `TomBaseServerConfiguration` | Server configuration root |

## Ecosystem

```text
tom_basics · tom_crypto · tom_reflection
                 │
          tom_core_kernel
                 │
          tom_core_server        ← you are here
          (re-exports the kernel; HTTP, persistence, migrations)
```

`tom_core_server` sits directly on `tom_core_kernel` and re-exports it, so server
apps get the full kernel API through one dependency. It also depends on
[`tom_core_message_bus`](../tom_core_message_bus/README.md), the broker-neutral
message bus its bus relay publishes to and its bus invalidation channel
(`TomBusInvalidationChannel`) subscribes to; the bus is not re-exported, so an
application that publishes or subscribes imports it itself. See the
[repository map](../README.md) for the full picture.

## Further documentation

- Per-module guides under [`doc/`](doc/) — one markdown file per module
  (`doc/object_persistence.md`, `doc/datasources.md`, `doc/endpoints.md`, …).
- Per-module API reference under [`doc/api/`](doc/api/) —
  start at
  [`doc/api/api_summary_index.md`](doc/api/api_summary_index.md)
  for the type index and one `api_summary_{module}.md` per module.
  (`doc/api/` is reserved for generated `dart doc` HTML and is gitignored.)
- [`doc/reflection_generation.md`](doc/reflection_generation.md) — how the
  committed `*.reflection.dart` files are produced, why regenerating rewrites
  thousands of lines nobody edited, and how to tell a stale one from a current
  one.
- [`tom_core_kernel`](../tom_core_kernel/README.md) — the platform-neutral
  building blocks this layer is composed from.

## Status

- **Version:** 1.3.0
- **Tests:** run with `testkit :test` or `dart test`. Part of the suite is
  tagged `db` and skips unless a live database is reachable. The same suites
  run against both databases: `tool/run_db_tests.sh` brings up a throwaway
  MariaDB (port 3309) and `tool/run_db_tests_postgres.sh` a throwaway
  PostgreSQL 15 (port 5439, `TOM_CORE_SERVER_TEST_DB_ENGINE=postgresql`), and
  each runs the tagged tests against it; the two compose projects can run side
  by side. The single sign-on
  interoperability suite is tagged `sso` and skips unless a Keycloak is
  reachable; `tool/run_sso_tests.sh` starts one and runs it. The metrics
  exports are checked by their consumers in the `otel`-tagged suite, which
  skips unless `tool/run_otel_tests.sh` started an OpenTelemetry Collector and
  named promtool's image; the same suite has the collector read the span
  export.

  No count is given, and that is deliberate. A count here is a claim nothing
  checks, and this package's whole position is that an unchecked claim about
  itself breaks — `test/api_reference_coverage_test.dart` is a hundred-odd
  assertions built on exactly that premise. A count breaks faster than most,
  because every added test is a README edit nobody makes. The `db` tag above is
  what a reader can actually act on, and the version is checked, because a
  wrong version is the claim that actively misleads.
- **Conformance guards:** some of those suites check the package rather than the
  code — `test/formatting_test.dart` fails when any Dart file is not
  `dart format` clean (the fix is always `dart format .`, never a code change),
  `test/api_reference_coverage_test.dart` fails when `doc/api/` and
  `lib/` disagree, `test/reflection_currency_test.dart` fails when a class or
  column was added to a reflection root without regenerating, and
  `test/examples_test.dart` fails when an example stops being verified. They need
  no separate invocation: a normal test run is the gate, which is the point —
  `dart analyze` cannot see any of these. The one check too slow to run that way
  is `tool/check_reflection_current.sh`, which regenerates and compares
  exactly (two to four minutes).
- **Mutation sweep:** `python3 tool/mutation_sweep.py` breaks one recorded
  behaviour at a time in `lib/` and reports whether the suite noticed. A green
  test that *names* a behaviour is not the same as one that pins it, and
  reading the test cannot tell them apart. The catalogue is
  `tool/mutations.yaml` and is the committed half: a module absent from it has
  not been swept. A mutant that does not compile is reported as INVALID rather
  than killed, because it turns every test red without asking anything of
  them; one that makes the suite hang is stopped after ten minutes and counted
  as killed, since the suite did notice. Not part of a normal test run — it edits `lib/`, restores in a
  `finally`, and takes minutes.
- **License:** BSD-3-Clause — see [LICENSE](LICENSE).
