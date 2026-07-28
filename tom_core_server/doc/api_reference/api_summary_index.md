# Tom Core Server API Reference: Index

Per-module API summaries for `tom_core_server` — the server layer of Tom Core.
It re-exports all of `tom_core_kernel` (see that package's docs for the kernel
API), `mysql_client`, and `tom_basics_console`, and adds the server-specific
surface documented here.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Audit | [api_summary_audit.md](api_summary_audit.md) | Attributable, tamper-evident records: the hash-chained trail, its sinks, and signed anchors. |
| Authentication | [api_summary_authentication.md](api_summary_authentication.md) | Login and two-factor services, adaptors, the authentication server, and the server's own self-login. |
| Authorization | [api_summary_authorization.md](api_summary_authorization.md) | Authorization cache, graded access, principal delegation and resource grants. |
| Cache | [api_summary_cache.md](api_summary_cache.md) | Isolate-backed server cache and its command messages. |
| Command Line | [api_summary_cmdline.md](api_summary_cmdline.md) | CLI argument parsing (`TomArgs`) and `.env` file loading (`TomEnvFile`). |
| Configuration | [api_summary_configuration.md](api_summary_configuration.md) | Server config provider, typed config values, YAML resources. |
| Datasources | [api_summary_datasources.md](api_summary_datasources.md) | DB type system, SQL dialects, queries, MariaDB datasource/prepared statements. |
| Database Migration | [api_summary_db_migration.md](api_summary_db_migration.md) | Migration runner, versioning, and the MariaDB migration adaptor. |
| Endpoints | [api_summary_endpoints.md](api_summary_endpoints.md) | Service/endpoint annotations, routing, handler pipeline, error handling. |
| Export | [api_summary_export.md](api_summary_export.md) | Tabular results rendered to CSV, XLSX or PDF, and stored for later retrieval. |
| File Storage | [api_summary_file_storage.md](api_summary_file_storage.md) | Streaming blob storage: one put/get contract over memory, directory, database and S3 backends. |
| Health Check | [api_summary_healthcheck.md](api_summary_healthcheck.md) | Health analyzer and health-check service/server. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | The server-side base exception `TomServerException`. |
| Messaging | [api_summary_messaging.md](api_summary_messaging.md) | Channel-neutral messages, delivery transports (SMTP and stand-ins), MIME encoding, and the durable outbox. |
| Object Persistence | [api_summary_object_persistence.md](api_summary_object_persistence.md) | Persistence annotations, repositories, query builder, operators/expressions, data scoping, column authorization. |
| Scheduling | [api_summary_scheduling.md](api_summary_scheduling.md) | The relational half of the job scheduler: the shared job queue, fencing leases, and the node roll call. |
| Server | [api_summary_server.md](api_summary_server.md) | The HTTP server, request identity/logging, and middleware. |
| Transactions | [api_summary_transactions.md](api_summary_transactions.md) | Distributed transaction manager and participants. |

## Modules

### Audit (`lib/src/tomserver/audit/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuditRecord` | class | One entry in the trail: an attributable statement that an action happened. |
| `TomAuditActor` | class | Who performed the action; never left blank. |
| `TomAuditAction` | enum | What kind of action a record describes. |
| `TomAuditOutcome` | enum | How the action ended — `denied` stays distinct from `failed`. |
| `TomAuditEntry` | class | A record plus its position in the hash chain. |
| `TomAuditChainVerification` | class | The outcome of checking a chain's integrity. |
| `TomAuditException` | class | Audit failure (extends `TomServerException`). |
| `TomAuditSink` | abstract class | Where a record is persisted. |
| `TomMemoryAuditSink` | class | In-memory sink bounded by entry count; tests and dev servers. |
| `TomFileAuditSink` | class | Append-only JSON Lines file sink with retention. |
| `TomSqlAuditSink` | class | Sink whose entries are rows in a `TomDataSource`. |
| `TomAudited` | class | Declares how an entity or endpoint method is audited. |
| `TomAuditPolicy` | class | The resolved policy for a type. |
| `TomAuditBypass` | class | A zone marker suppressing auditing inside it. |
| `TomAuditTrail` | class | Resolves policy, builds records, hands them to the sink. |
| `TomAuditAnchor` | class | A claim about where a chain stood at a moment. |
| `TomAuditAnchorSigner` | abstract class | Attaches a signature to an anchor's payload. |
| `TomAuditAnchorVerifier` | abstract class | Checks the signature on an anchor. |
| `TomRsaAuditAnchorSigner` | class | Signs anchors with an RSA private key. |
| `TomRsaAuditAnchorVerifier` | class | Verifies anchors against published public keys. |
| `TomAuditAnchorStatus` | enum | How a chain stands relative to an anchor. |
| `TomAuditAnchorVerification` | class | The outcome of checking a chain against an anchor. |
| `TomAuditAnchorStore` | abstract class | An append-only archive of published anchors. |
| `TomMemoryAuditAnchorStore` | class | In-memory anchor store, for tests. |
| `TomFileAuditAnchorStore` | class | JSON Lines anchor store, one file per writer. |
| `TomAuditAnchorPublisher` | class | Publishes anchors for a sink's chain on a schedule. |
| `TomAuditWriteOnceCheck` | class | What a deployment's audit table actually permits, as observed. |
| `TomAuditTrailRow` | class | One row of the audit trail table. |
| `TomAuditHeadRow` | class | The columns projected when recovering a chain head. |
| `TomAuditSeqRow` | class | A projected sequence number, for retention boundaries. |
| `TomAuditTriggerRow` | class | One `information_schema.TRIGGERS` row. |
| `verifyAuditChain` / `verifyAgainstAnchor` | top-level | Chain and anchor verification. |
| `parseAuditLines` / `auditDiff` | top-level | JSON-Lines parsing; the changed-fields pair. |
| `tomAuditGenesisHash` / `tomAuditRedactedPlaceholder` | top-level | The chain start hash; the redaction placeholder. |
| `defaultAuditTrailTable` / `auditTrailTable` / `auditTrailTableDdl` | top-level | The trail table's name, descriptor and DDL. |
| `auditTrailNoUpdateTriggerName` / `auditTrailNoDeleteTriggerName` | top-level | Names of the write-once guard triggers. |
| `auditTrailNoUpdateTriggerDdl` / `auditTrailNoDeleteTriggerDdl` | top-level | DDL for the write-once guard triggers. |

### Authentication (`lib/src/tomserver/authentication/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuthenticationServer` | class | Server-side authentication entry point. |
| `TomAuthenticationService` | abstract class | Authentication service contract. |
| `TomDummyAuthenticationService` | class | In-memory service for tests/dev. |
| `Tom2FAService` | abstract class | Two-factor mechanism contract: issue a challenge, verify a submission. |
| `Tom2FARegistry` | class | Maps a mechanism key to its adaptor; scans `@Tom2FAAdaptor` classes. |
| `Tom2FAContext` | class | What an adaptor is told about the login it is challenging. |
| `Tom2FAChallengeSpec` | class | What an adaptor returns when issuing a challenge. |
| `Tom2FASubmission` | class | One answer to a challenge, as presented to the adaptor. |
| `TomTotp2FAService` | class | The shipped RFC 6238 authenticator-app mechanism. |
| `TomTotpSecretResolver` | typedef | Resolves a user's base32 TOTP secret. |
| `Tom2FAException` | class | 2FA configuration fault (extends `TomServerException`). |
| `TomAuthenticationAdaptor` | class | Reflection marker for auth adaptors. |
| `Tom2FAAdaptor` | class | Reflection marker for 2FA adaptors. |
| `TomAuthenticationData` | class | Reflected authentication payload. |
| `TomAuthenticationInfo` | class | Resolved authentication result. |
| `LoginException` | class | Login failure (extends `TomServerException`). |
| `TomServerSelfLogin` | class | Logs the deployment in as itself and installs the server principal. |
| `TomServiceCredential` | class | The deployment's own login credential and where to present it. |
| `TomServiceLoginTransport` | abstract class | The one-JSON-POST seam the self-login runs over. |
| `TomHttpServiceLoginTransport` | class | The live transport, over `TomServerChannel`. |
| `TomServiceLoginResponse` | class | The raw status + body of a self-login POST. |
| `TomServerSelfLoginException` | class | A configured deployment failed to log itself in. |

### Authorization (`lib/src/tomserver/authorization/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuthorizationCache` | class | Cache of resolved authorization state. |
| `TomAuthorizationCacheEntry` | class | A single cache entry. |
| `TomAuthorizationCacheExecutor` | class | Isolate executor backing the cache. |
| `TomAuthorizationCacheStoreMessage` | class | Store command message. |
| `TomAuthorizationCacheRetrieveMessage` | class | Retrieve command message. |
| `TomAuthorizationCacheException` | class | Cache error (extends `TomException`). |
| `TomAuthStateCodec` | class | Encodes/decodes auth state (static). |
| `TomResourceGrant` | class | A grant of a role on a resource. |
| `TomGradedAccessControlInformation` | class | Graded (field-level) access info. |
| `TomPrincipalDelegation` | class | Delegation of authority between principals. |
| `TomDelegationMode` | enum | `share`, `absence`, `intentional`. |
| `TomDelegationResolver` | class | Resolves effective delegations. |
| `PrincipalDelegationStore` | abstract class | Delegation store contract. |
| `RepositoryPrincipalDelegationStore` | class | Repository-backed delegation store. |
| `InMemoryPrincipalDelegationStore` | class | In-memory delegation store. |
| `TomPrincipalResourceGrant` | class | Persisted principal→resource role grant. |
| `TomPrincipalResourceRoleResolver` | class | Resolves a principal's resource roles. |
| `PrincipalResourceGrantStore` | abstract class | Resource-grant store contract. |
| `RepositoryPrincipalResourceGrantStore` | class | Repository-backed grant store. |
| `InMemoryPrincipalResourceGrantStore` | class | In-memory grant store. |

### Cache (`lib/src/tomserver/cache/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomCache` | class | The server cache facade. |
| `TomCacheManager` | class | Manages cache lifecycle/isolate. |
| `TomCacheEntry` | class | A cache entry with metadata. |
| `TomCacheStoreMessage` | class | Store command (extends `TomCommand`). |
| `TomCacheRemoveMessage` | class | Remove command (extends `TomCommand`). |
| `TomCacheRetrieveMessage` | class | Retrieve command (extends `TomCommand`). |
| `TomCacheException` | class | Cache error (extends `TomServerException`). |

### Command Line (`lib/src/tomserver/cmdline/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomArgs` | class | CLI argument parsing/conversion (static). |
| `TomEnvFile` | class | `.env` file loading (static). |

### Configuration (`lib/src/tomserver/configuration/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomServerConfigResourceProvider` | class | Server-side config resource provider. |
| `TomBaseServerConfiguration` | abstract class | Base reflected server configuration. |
| `TomConfig<T>` | class | Typed configuration value. |
| `TomStringConfig` | class | `String` config value. |
| `TomIntConfig` | class | `int` config value. |
| `TomDoubleConfig` | class | `double` config value. |
| `TomBoolConfig` | class | `bool` config value. |
| `TomYaml` | class | YAML resource helpers (static). |
| `tomAppId` | top-level | The current application id. |

### Datasources (`lib/src/tomserver/datasources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbType<T>` | abstract class | Base DB column type (extends kernel `TomObject`). |
| `TomDbInt` / `TomDbDouble` / `TomDbString` / `TomDbDateTime` / `TomDbDate` / `TomDbTime` / `TomDbBool` | class | Concrete DB types. |
| `TomOperator<R>` | abstract class | Base of the SQL expression tree. |
| `TomSqlDialect` | class | Annotation tagging a dialect. |
| `TomStandardSqlDialect` | class | Standard-SQL dialect. |
| `MariadbSqlDialect` | class | MariaDB dialect. |
| `TomQuery` / `TomGeneratedQuery` | abstract class | Query base types. |
| `TomSelect` / `TomLiteralSelect` / `TomCount` / `TomDelete` | class | Concrete queries. |
| `TomTypePersistenceInfo` | class | Type persistence metadata. |
| `TomTypedPersistenceBase` | abstract class | Base for typed persistence. |
| `TomDataSource` | abstract class | Datasource contract (a transaction participant). |
| `TomPreparedStatement<T>` | abstract class | Prepared-statement contract. |
| `TomDataSourceInfo` | class | Datasource descriptor. |
| `TomDatasourceDriver` | class | Annotation tagging a driver. |
| `MariaDbDatasource` | class | MariaDB datasource. |
| `MariaDbXADatasource` | class | XA-capable MariaDB datasource. |
| `MariadbPreparedStatement<T>` | class | MariaDB prepared statement. |
| `SqlPlaceholderScan` | class | SQL placeholder scanner. |
| `TomDatasourceInitException` | class | Init error (extends `TomException`). |
| `MariadbDatasourceException` | class | MariaDB error (extends `TomServerException`). |
| `MariadbPreparedStatementException` | class | Prepared-statement error. |
| `SqlString` | typedef | Alias for `String`. |

### Database Migration (`lib/src/tomserver/db_migration/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbMigrations` | class | Migration runner/registry. |
| `TomDbMigrator` | abstract class | Migrator contract. |
| `TomDbMigrationAdaptor` | class | Annotation tagging a migration adaptor. |
| `MariadbMigrationAdaptor` | class | MariaDB migration adaptor. |
| `TomMigrationFileName` | class | Parses/validates migration file names. |
| `TomDbVersion` | class | A schema version. |
| `TomDbMigrationException` | class | Migration error (extends `TomServerException`). |
| `MariadbMigrationException` | class | MariaDB migration error. |

### Endpoints (`lib/src/tomserver/endpoints/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomService` | class | Service annotation (`@tomService`). |
| `tomService` | top-level | The `@tomService` const instance. |
| `TomApiImplementation` | class | API-implementation annotation. |
| `TomComponentReference` | class | Component-reference annotation. |
| `TomTransactional` | class | Transactional-method annotation. |
| `TomEndpointBase<Req, Res>` | abstract class | Endpoint base contract. |
| `TomEndpoint<Req, Res>` | class | Concrete endpoint. |
| `TomApiEndpointImplementation<Req, Res>` | class | API endpoint implementation. |
| `TomEndpointHandler` | class | Dispatches requests to endpoints. |
| `TomEndpointRouting` | class | Route table. |
| `TomEndpointRoutingInfo` | class | Route entry. |
| `TomMethodMetadata` | class | Reflected method metadata. |
| `TomClassScanResult` | class | Result of scanning a service class. |
| `TomErrorHandler` | abstract class | Error-handler contract. |
| `TomDefaultErrorHandler` | class | Default error handler. |
| `TomEndpointHandlerException` | class | Handler error. |
| `TomEndpointPipelineException` | class | Pipeline error. |

### Export (`lib/src/tomserver/export/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTabularResult` | class | A complete result: title, metadata, and one or more sections. |
| `TomTabularSection` | class | One titled table: typed columns over a stream of rows. |
| `TomTabularColumn` | class | One typed column: machine key, human label, type. |
| `TomTabularRow` | class | One row: cell values positional to the columns. |
| `TomColumnType` | enum | The value types a column may hold. |
| `TomTabularRenderer` | abstract class | Renders a result to a byte stream in one format. |
| `TomCsvRenderer` | class | RFC 4180 CSV, one row at a time. |
| `TomXlsxRenderer` | class | Office Open XML workbook, one worksheet per section. |
| `TomPdfRenderer` | class | Paginated PDF with title, metadata block and tables. |
| `TomExportFormats` | class | The set of formats an application offers. |
| `TomExportStore` | abstract class | Stores and retrieves rendered exports by key. |
| `TomDirectoryExportStore` | class | Export store over a local directory tree. |
| `TomMemoryExportStore` | class | In-memory export store, for tests. |
| `TomBlobExportStore` | class | Export store backed by a `TomBlobStore`. |
| `TomStoredExport` | class | What was written, where, and how big it turned out. |
| `TomExportService` | class | The seam an endpoint calls: render, optionally store. |
| `TomExportException` | class | Export failure (extends `TomServerException`). |
| `tomFormatCellAsText` | top-level | The shared text rule for the text-oriented renderers. |

### File Storage (`lib/src/tomserver/file_storage/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomBlobStore` | abstract class | Stores and retrieves blobs by key, streaming. |
| `TomStoredBlob` | class | A stored blob: key, content type, size. |
| `TomMemoryBlobStore` | class | In-memory blob store, for tests and development. |
| `TomDirectoryBlobStore` | class | Blob store over a local directory tree. |
| `TomDatabaseBlobStore` | class | Blob store over a manifest and chunk table pair. |
| `TomS3BlobStore` | class | Blob store over an S3-compatible object store. |
| `TomBlobStoreInfo` | class | The process-wide registry of named, configured stores. |
| `TomBlobStoreFactory` | typedef | Builds a store of one backend type from its settings. |
| `TomAwsV4Signer` | class | Signs HTTP requests with AWS Signature Version 4. |
| `TomAwsCredentials` | class | The key pair, optionally with a session token. |
| `TomBlobManifestRow` | class | One row of the blob manifest table. |
| `TomBlobChunkRow` | class | One chunk row's payload. |
| `TomStorageException` | class | Storage failure (extends `TomServerException`). |
| `defaultBlobManifestTable` / `defaultBlobChunkTable` | top-level | Default table names. |
| `blobManifestTable` / `blobChunkTable` | top-level | The table descriptors. |
| `blobManifestTableDdl` / `blobChunkTableDdl` | top-level | The `CREATE TABLE` statements. |

### Health Check (`lib/src/tomserver/healthcheck/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `HealthAnalyzer` | abstract class | Health-analysis contract. |
| `DefaultHealthAnalyzer` | class | Default analyzer. |
| `TomHealthService` | abstract class | Health-check service (`@tomService`). |
| `TomHealthServer` | class | Health-check server component. |

### Little Things (`lib/src/tomserver/little_things/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomServerException` | class | Server-side base exception (extends `TomException`). |

### Messaging (`lib/src/tomserver/messaging/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomMessage` | class | One composed message: sender, recipients, subject, bodies, attachments. |
| `TomRecipient` | class | One addressee, by channel-specific address. |
| `TomRecipientKind` | enum | `to`, `cc`, `bcc`. |
| `TomMessageBody` | class | One typed content representation. |
| `TomAttachment` | class | A named binary part, optionally inline. |
| `TomMessageChannel` | class | An open named channel — `email`, `sms`, `push`, `webhook`, or yours. |
| `TomMessageTransport` | abstract class | One delivery channel: one attempt at one message. |
| `TomDeliveryReceipt` | class | What became of an attempt, including partial delivery. |
| `TomDeliveryOutcome` | enum | `delivered`, `rejected`, `deferred`, `discarded`. |
| `TomMessageRouter` | class | Maps a channel to its transport. |
| `TomMemoryMessageTransport` | class | Captures messages in memory; the test stand-in. |
| `TomNoOpMessageTransport` | class | Accepts and discards; the silenced-deployment stand-in. |
| `TomFileMessageTransport` | class | Writes each message to an `.eml` file. |
| `TomSmtpTransport` | class | Real delivery over SMTP. |
| `TomSmtpSettings` | class | Everything needed to reach one mail server. |
| `TomSmtpSecurity` | enum | `none`, `startTls`, `implicitTls`. |
| `TomSmtpConnection` | abstract class | The wire, behind an interface so the protocol is testable. |
| `TomSocketSmtpConnection` | class | The `dart:io` socket implementation. |
| `TomSmtpReply` | class | One SMTP reply and its classification. |
| `TomMimeEncoder` | class | Renders a message as an RFC 5322 / MIME document. |
| `TomMessageOutbox` | class | The durable send queue in front of a router. |
| `TomMessagingException` | class | The module's base error (extends `TomServerException`). |
| `TomDeliveryException` | class | A delivery failure, classified transient or permanent. |
| `TomPermanentDeliveryException` | class | A delivery failure the scheduler will not retry. |
| `tomMimeLineEnding` / `tomMimeMaxLineLength` | top-level | MIME line ending and maximum line length. |
| `tomOutboxJobName` | top-level | The default job name the outbox registers under. |

### Object Persistence (`lib/src/tomserver/object_persistence/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbTable` / `TomDbColumn` / `TomEntityId` / `TomDbScope` / `TomJoinTable` / `TomReference` / `TomPersistenceEventHandler` | class | Persistence annotations. |
| `TomDartType` | class | Dart-type descriptor for persistence. |
| `TomColumnInformation` | class | Column metadata. |
| `TomRepository<T, K>` | abstract class | Repository contract. |
| `TomSqlDatasourceRepository<T, K>` | abstract class | SQL-datasource repository base. |
| `MariadbRepository<T, K>` | class | MariaDB repository. |
| `TomRepositoryType` | class | Repository annotation. |
| `TomCountResult` | class | Count query result. |
| `TomQueryBuilder` | mixin | Fluent query building. |
| `TomQuerySentenceCompiler` | class | Compiles query sentences to SQL. |
| `TomOperator` expression tree | class | `TomUnaryOperator`, `TomBinaryOperator`, `Parameter`, `DbCol`/`IntCol`/`StringCol`/`DoubleCol`/`BoolCol`/`DateTimeCol`/`DateCol`, the `*Literal` set, and `And`/`Or`/`Not`/`Eq`/`Neq`/`Lt`/`Gt`/`Lte`/`Gte`/`Like`/`NotLike`/`In`/`Group`/`Between`/`Regexp`/`IsNull`/`IsNotNull`. |
| `TomQuerySyntaxException` | class | Query syntax error. |
| `TomDataScope` | class | Row-level data scoping (static). |
| `TomDataScopeRegistry` / `TomDataScopePredicate` / `TomDataScopeBypass` | class | Data-scope machinery. |
| `TomDataScopeResolver` / `TomAsyncDataScopeResolver` | typedef | Scope resolver signatures. |
| `TomDataScopeException` / `TomDataScopeAuthorizationException` | class | Data-scope errors. |
| `TomColumnAuthorization` | class | Column-level write authorization (static). |
| `TomColumnWriteDecision<C>` | class | A column write decision. |
| `TomColumnAuthResolver` | typedef | Column-auth resolver signature. |
| `TomColumnAuthorizationException` | class | Column-auth error. |
| `TomAnnotationAnalyzer` | mixin | Persistence-annotation analysis (static). |
| `TomAnnotationAnalyzerException` / `TomAnnotationAnalyzerSyntaxException` | class | Analyzer errors. |

### Scheduling (`lib/src/tomserver/scheduling/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomSqlJobStore` | class | A `TomJobStore` whose queue is a table in a `TomDataSource`. |
| `TomJobRunRow` | class | One row of the job queue table. |
| `TomJobRunWindowRow` | class | The aggregate column `lastWindow` projects. |
| `TomSqlLeaseLock` | class | A `TomLeaseLock` whose leases are rows in a `TomDataSource`. |
| `TomLeaseRow` | class | One row of the lease table. |
| `TomSqlSchedulerNodes` | class | The cluster roll call, backed by a table. |
| `TomSchedulerNode` | class | One node of the cluster, as the roll call knows it. |
| `TomSchedulerNodeRow` | class | One row of the roll-call table. |
| `schedulerNodeFailedAfter` / `isSchedulerNodeFailed` | top-level | When a peer counts as failed, and whether it does. |
| `defaultNodeFailureSlack` | top-level | The grace period added to a peer's expected check-in. |
| `defaultJobRunTable` / `defaultLeaseTable` / `defaultSchedulerNodeTable` | top-level | Default table names. |
| `jobRunTable` / `leaseTable` / `schedulerNodeTable` | top-level | The table descriptors. |
| `jobRunTableDdl` / `leaseTableDdl` / `schedulerNodeTableDdl` | top-level | The `CREATE TABLE` statements. |

### Server (`lib/src/tomserver/server/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomServer` | class | The HTTP server. |
| `TomRequestId` | class | Per-request identity. |
| `TomRequestLogInfo` | class | Per-request log record. |
| `contextSetupMiddleware` | function | Establishes the execution context per request. |
| `extractAuthentication` | function | Extracts principal + JWT from a request. |
| `tomDefaultAuthenticationMiddleware` | function | Default auth middleware. |
| `tomLoggingMiddleware` | function | Request-logging middleware. |
| `noopHandler` | function | A handler returning a fixed status. |

### Transactions (`lib/src/tomserver/transactions/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTransactionManager` | abstract class | Transaction coordination (static). |
| `TomTransaction` | class | An in-flight transaction. |
| `TomTransactionParticipant` | abstract class | Participant contract (2-phase commit). |
| `TomTransactionException` | class | Transaction error. |

## Alphabetical Type Index

| Type | Module |
| ---- | ------ |
| `And` | Object Persistence |
| `auditDiff` | Audit |
| `auditTrailNoDeleteTriggerDdl` | Audit |
| `auditTrailNoDeleteTriggerName` | Audit |
| `auditTrailNoUpdateTriggerDdl` | Audit |
| `auditTrailNoUpdateTriggerName` | Audit |
| `auditTrailTable` | Audit |
| `auditTrailTableDdl` | Audit |
| `Between` | Object Persistence |
| `blobChunkTable` | File Storage |
| `blobChunkTableDdl` | File Storage |
| `blobManifestTable` | File Storage |
| `blobManifestTableDdl` | File Storage |
| `BoolCol` | Object Persistence |
| `BoolLiteral` | Object Persistence |
| `contextSetupMiddleware` | Server |
| `DateCol` | Object Persistence |
| `DateLiteral` | Object Persistence |
| `DateTimeCol` | Object Persistence |
| `DateTimeLiteral` | Object Persistence |
| `DbCol` | Object Persistence |
| `defaultAuditTrailTable` | Audit |
| `defaultBlobChunkTable` | File Storage |
| `defaultBlobManifestTable` | File Storage |
| `DefaultHealthAnalyzer` | Health Check |
| `defaultJobRunTable` | Scheduling |
| `defaultLeaseTable` | Scheduling |
| `defaultNodeFailureSlack` | Scheduling |
| `defaultSchedulerNodeTable` | Scheduling |
| `DoubleCol` | Object Persistence |
| `DoubleLiteral` | Object Persistence |
| `Eq` | Object Persistence |
| `extractAuthentication` | Server |
| `Group` | Object Persistence |
| `Gt` | Object Persistence |
| `Gte` | Object Persistence |
| `HealthAnalyzer` | Health Check |
| `In` | Object Persistence |
| `InMemoryPrincipalDelegationStore` | Authorization |
| `InMemoryPrincipalResourceGrantStore` | Authorization |
| `IntCol` | Object Persistence |
| `IntegerLiteral` | Object Persistence |
| `IsNotNull` | Object Persistence |
| `IsNull` | Object Persistence |
| `isSchedulerNodeFailed` | Scheduling |
| `jobRunTable` | Scheduling |
| `jobRunTableDdl` | Scheduling |
| `leaseTable` | Scheduling |
| `leaseTableDdl` | Scheduling |
| `Like` | Object Persistence |
| `LoginException` | Authentication |
| `Lt` | Object Persistence |
| `Lte` | Object Persistence |
| `MariaDbDatasource` | Datasources |
| `MariadbDatasourceException` | Datasources |
| `MariadbMigrationAdaptor` | Database Migration |
| `MariadbMigrationException` | Database Migration |
| `MariadbPreparedStatement` | Datasources |
| `MariadbPreparedStatementException` | Datasources |
| `MariadbRepository` | Object Persistence |
| `MariadbSqlDialect` | Datasources |
| `MariaDbXADatasource` | Datasources |
| `Neq` | Object Persistence |
| `noopHandler` | Server |
| `Not` | Object Persistence |
| `NotLike` | Object Persistence |
| `Or` | Object Persistence |
| `Parameter` | Object Persistence |
| `parseAuditLines` | Audit |
| `PrincipalDelegationStore` | Authorization |
| `PrincipalResourceGrantStore` | Authorization |
| `Regexp` | Object Persistence |
| `RepositoryPrincipalDelegationStore` | Authorization |
| `RepositoryPrincipalResourceGrantStore` | Authorization |
| `schedulerNodeFailedAfter` | Scheduling |
| `schedulerNodeTable` | Scheduling |
| `schedulerNodeTableDdl` | Scheduling |
| `SqlPlaceholderScan` | Datasources |
| `SqlString` | Datasources |
| `StringCol` | Object Persistence |
| `StringLiteral` | Object Persistence |
| `Tom2FAAdaptor` | Authentication |
| `Tom2FAChallengeSpec` | Authentication |
| `Tom2FAContext` | Authentication |
| `Tom2FAException` | Authentication |
| `Tom2FARegistry` | Authentication |
| `Tom2FAService` | Authentication |
| `Tom2FASubmission` | Authentication |
| `TomAnnotationAnalyzer` | Object Persistence |
| `TomAnnotationAnalyzerException` | Object Persistence |
| `TomAnnotationAnalyzerSyntaxException` | Object Persistence |
| `TomApiEndpointImplementation` | Endpoints |
| `TomApiImplementation` | Endpoints |
| `tomAppId` | Configuration |
| `TomArgs` | Command Line |
| `TomAsyncDataScopeResolver` | Object Persistence |
| `TomAttachment` | Messaging |
| `TomAuditAction` | Audit |
| `TomAuditActor` | Audit |
| `TomAuditAnchor` | Audit |
| `TomAuditAnchorPublisher` | Audit |
| `TomAuditAnchorSigner` | Audit |
| `TomAuditAnchorStatus` | Audit |
| `TomAuditAnchorStore` | Audit |
| `TomAuditAnchorVerification` | Audit |
| `TomAuditAnchorVerifier` | Audit |
| `TomAuditBypass` | Audit |
| `TomAuditChainVerification` | Audit |
| `TomAudited` | Audit |
| `TomAuditEntry` | Audit |
| `TomAuditException` | Audit |
| `tomAuditGenesisHash` | Audit |
| `TomAuditHeadRow` | Audit |
| `TomAuditPolicy` | Audit |
| `TomAuditRecord` | Audit |
| `tomAuditRedactedPlaceholder` | Audit |
| `TomAuditSeqRow` | Audit |
| `TomAuditSink` | Audit |
| `TomAuditTrail` | Audit |
| `TomAuditTrailRow` | Audit |
| `TomAuditTriggerRow` | Audit |
| `TomAuditWriteOnceCheck` | Audit |
| `TomAuthenticationAdaptor` | Authentication |
| `TomAuthenticationData` | Authentication |
| `TomAuthenticationInfo` | Authentication |
| `TomAuthenticationServer` | Authentication |
| `TomAuthenticationService` | Authentication |
| `TomAuthorizationCache` | Authorization |
| `TomAuthorizationCacheEntry` | Authorization |
| `TomAuthorizationCacheException` | Authorization |
| `TomAuthorizationCacheExecutor` | Authorization |
| `TomAuthorizationCacheRetrieveMessage` | Authorization |
| `TomAuthorizationCacheStoreMessage` | Authorization |
| `TomAuthStateCodec` | Authorization |
| `TomAwsCredentials` | File Storage |
| `TomAwsV4Signer` | File Storage |
| `TomBaseServerConfiguration` | Configuration |
| `TomBinaryOperator` | Object Persistence |
| `TomBlobChunkRow` | File Storage |
| `TomBlobExportStore` | Export |
| `TomBlobManifestRow` | File Storage |
| `TomBlobStore` | File Storage |
| `TomBlobStoreFactory` | File Storage |
| `TomBlobStoreInfo` | File Storage |
| `TomBoolConfig` | Configuration |
| `TomCache` | Cache |
| `TomCacheEntry` | Cache |
| `TomCacheException` | Cache |
| `TomCacheManager` | Cache |
| `TomCacheRemoveMessage` | Cache |
| `TomCacheRetrieveMessage` | Cache |
| `TomCacheStoreMessage` | Cache |
| `TomClassScanResult` | Endpoints |
| `TomColumnAuthorization` | Object Persistence |
| `TomColumnAuthorizationException` | Object Persistence |
| `TomColumnAuthResolver` | Object Persistence |
| `TomColumnInformation` | Object Persistence |
| `TomColumnType` | Export |
| `TomColumnWriteDecision` | Object Persistence |
| `TomComponentReference` | Endpoints |
| `TomConfig` | Configuration |
| `TomCount` | Datasources |
| `TomCountResult` | Object Persistence |
| `TomCsvRenderer` | Export |
| `TomDartType` | Object Persistence |
| `TomDatabaseBlobStore` | File Storage |
| `TomDataScope` | Object Persistence |
| `TomDataScopeAuthorizationException` | Object Persistence |
| `TomDataScopeBypass` | Object Persistence |
| `TomDataScopeException` | Object Persistence |
| `TomDataScopePredicate` | Object Persistence |
| `TomDataScopeRegistry` | Object Persistence |
| `TomDataScopeResolver` | Object Persistence |
| `TomDataSource` | Datasources |
| `TomDatasourceDriver` | Datasources |
| `TomDataSourceInfo` | Datasources |
| `TomDatasourceInitException` | Datasources |
| `TomDbBool` | Datasources |
| `TomDbColumn` | Object Persistence |
| `TomDbDate` | Datasources |
| `TomDbDateTime` | Datasources |
| `TomDbDouble` | Datasources |
| `TomDbInt` | Datasources |
| `TomDbMigrationAdaptor` | Database Migration |
| `TomDbMigrationException` | Database Migration |
| `TomDbMigrations` | Database Migration |
| `TomDbMigrator` | Database Migration |
| `TomDbScope` | Object Persistence |
| `TomDbString` | Datasources |
| `TomDbTable` | Object Persistence |
| `TomDbTime` | Datasources |
| `TomDbType` | Datasources |
| `TomDbVersion` | Database Migration |
| `TomDefaultErrorHandler` | Endpoints |
| `TomDelegationMode` | Authorization |
| `TomDelegationResolver` | Authorization |
| `TomDelete` | Datasources |
| `TomDeliveryException` | Messaging |
| `TomDeliveryOutcome` | Messaging |
| `TomDeliveryReceipt` | Messaging |
| `TomDirectoryBlobStore` | File Storage |
| `TomDirectoryExportStore` | Export |
| `TomDoubleConfig` | Configuration |
| `TomDummyAuthenticationService` | Authentication |
| `TomEndpoint` | Endpoints |
| `TomEndpointBase` | Endpoints |
| `TomEndpointHandler` | Endpoints |
| `TomEndpointHandlerException` | Endpoints |
| `TomEndpointPipelineException` | Endpoints |
| `TomEndpointRouting` | Endpoints |
| `TomEndpointRoutingInfo` | Endpoints |
| `TomEntityId` | Object Persistence |
| `TomEnvFile` | Command Line |
| `TomErrorHandler` | Endpoints |
| `TomExportException` | Export |
| `TomExportFormats` | Export |
| `TomExportService` | Export |
| `TomExportStore` | Export |
| `TomFileAuditAnchorStore` | Audit |
| `TomFileAuditSink` | Audit |
| `TomFileMessageTransport` | Messaging |
| `tomFormatCellAsText` | Export |
| `TomGeneratedQuery` | Datasources |
| `TomGradedAccessControlInformation` | Authorization |
| `TomHealthServer` | Health Check |
| `TomHealthService` | Health Check |
| `TomHttpServiceLoginTransport` | Authentication |
| `TomIntConfig` | Configuration |
| `TomJobRunRow` | Scheduling |
| `TomJobRunWindowRow` | Scheduling |
| `TomJoinTable` | Object Persistence |
| `TomLeaseRow` | Scheduling |
| `TomLiteralSelect` | Datasources |
| `TomMemoryAuditAnchorStore` | Audit |
| `TomMemoryAuditSink` | Audit |
| `TomMemoryBlobStore` | File Storage |
| `TomMemoryExportStore` | Export |
| `TomMemoryMessageTransport` | Messaging |
| `TomMessage` | Messaging |
| `TomMessageBody` | Messaging |
| `TomMessageChannel` | Messaging |
| `TomMessageOutbox` | Messaging |
| `TomMessageRouter` | Messaging |
| `TomMessageTransport` | Messaging |
| `TomMessagingException` | Messaging |
| `TomMethodMetadata` | Endpoints |
| `TomMigrationFileName` | Database Migration |
| `TomMimeEncoder` | Messaging |
| `tomMimeLineEnding` | Messaging |
| `tomMimeMaxLineLength` | Messaging |
| `TomNoOpMessageTransport` | Messaging |
| `TomOperator` | Datasources |
| `tomOutboxJobName` | Messaging |
| `TomPdfRenderer` | Export |
| `TomPermanentDeliveryException` | Messaging |
| `TomPersistenceEventHandler` | Object Persistence |
| `TomPreparedStatement` | Datasources |
| `TomPrincipalDelegation` | Authorization |
| `TomPrincipalResourceGrant` | Authorization |
| `TomPrincipalResourceRoleResolver` | Authorization |
| `TomQuery` | Datasources |
| `TomQueryBuilder` | Object Persistence |
| `TomQuerySentenceCompiler` | Object Persistence |
| `TomQuerySyntaxException` | Object Persistence |
| `TomRecipient` | Messaging |
| `TomRecipientKind` | Messaging |
| `TomReference` | Object Persistence |
| `TomRepository` | Object Persistence |
| `TomRepositoryType` | Object Persistence |
| `TomRequestId` | Server |
| `TomRequestLogInfo` | Server |
| `TomResourceGrant` | Authorization |
| `TomRsaAuditAnchorSigner` | Audit |
| `TomRsaAuditAnchorVerifier` | Audit |
| `TomS3BlobStore` | File Storage |
| `TomSchedulerNode` | Scheduling |
| `TomSchedulerNodeRow` | Scheduling |
| `TomSelect` | Datasources |
| `TomServer` | Server |
| `TomServerConfigResourceProvider` | Configuration |
| `TomServerException` | Little Things |
| `TomServerSelfLogin` | Authentication |
| `TomServerSelfLoginException` | Authentication |
| `TomService` | Endpoints |
| `tomService` | Endpoints |
| `TomServiceCredential` | Authentication |
| `TomServiceLoginResponse` | Authentication |
| `TomServiceLoginTransport` | Authentication |
| `TomSmtpConnection` | Messaging |
| `TomSmtpReply` | Messaging |
| `TomSmtpSecurity` | Messaging |
| `TomSmtpSettings` | Messaging |
| `TomSmtpTransport` | Messaging |
| `TomSocketSmtpConnection` | Messaging |
| `TomSqlAuditSink` | Audit |
| `TomSqlDatasourceRepository` | Object Persistence |
| `TomSqlDialect` | Datasources |
| `TomSqlJobStore` | Scheduling |
| `TomSqlLeaseLock` | Scheduling |
| `TomSqlSchedulerNodes` | Scheduling |
| `TomStandardSqlDialect` | Datasources |
| `TomStorageException` | File Storage |
| `TomStoredBlob` | File Storage |
| `TomStoredExport` | Export |
| `TomStringConfig` | Configuration |
| `TomTabularColumn` | Export |
| `TomTabularRenderer` | Export |
| `TomTabularResult` | Export |
| `TomTabularRow` | Export |
| `TomTabularSection` | Export |
| `TomTotp2FAService` | Authentication |
| `TomTotpSecretResolver` | Authentication |
| `TomTransaction` | Transactions |
| `TomTransactional` | Endpoints |
| `TomTransactionException` | Transactions |
| `TomTransactionManager` | Transactions |
| `TomTransactionParticipant` | Transactions |
| `TomTypedPersistenceBase` | Datasources |
| `TomTypePersistenceInfo` | Datasources |
| `TomUnaryOperator` | Object Persistence |
| `TomXlsxRenderer` | Export |
| `TomYaml` | Configuration |
| `verifyAgainstAnchor` | Audit |
| `verifyAuditChain` | Audit |
