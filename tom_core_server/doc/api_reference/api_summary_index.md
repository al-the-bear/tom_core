# Tom Core Server API Reference: Index

Per-module API summaries for `tom_core_server` — the server layer of Tom Core.
It re-exports all of `tom_core_kernel` (see that package's docs for the kernel
API), `mysql_client`, and `tom_basics_console`, and adds the server-specific
surface documented here.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Audit | [api_summary_audit.md](api_summary_audit.md) | Attributable, tamper-evident records: the hash-chained trail, its sinks, and signed anchors. |
| Authentication | [api_summary_authentication.md](api_summary_authentication.md) | Login and two-factor services, adaptors, the policy deciding who owes a factor, enrolment and its stores, the authentication server, the server's own self-login, and external identity: the OAuth handshake, its pending-authorization stores, and the linking table. |
| Authorization | [api_summary_authorization.md](api_summary_authorization.md) | Authorization cache, graded access, principal delegation and resource grants. |
| Cache | [api_summary_cache.md](api_summary_cache.md) | Isolate-backed server cache and its command messages. |
| Command Line | [api_summary_cmdline.md](api_summary_cmdline.md) | CLI argument parsing (`TomArgs`) and `.env` file loading (`TomEnvFile`). |
| Configuration | [api_summary_configuration.md](api_summary_configuration.md) | Server config provider, typed config values, YAML resources. |
| Datasources | [api_summary_datasources.md](api_summary_datasources.md) | DB type system, SQL dialects, queries, MariaDB datasource/prepared statements. |
| Database Migration | [api_summary_db_migration.md](api_summary_db_migration.md) | Migration runner, versioning, and the MariaDB migration adaptor. |
| Endpoints | [api_summary_endpoints.md](api_summary_endpoints.md) | Service/endpoint annotations, routing, handler pipeline, error handling, and the three transports over it: HTML form bodies, redirects and WebSockets — plus the HTTP surface of file columns. |
| Export | [api_summary_export.md](api_summary_export.md) | Tabular results rendered to CSV, XLSX or PDF, and stored for later retrieval. |
| File Storage | [api_summary_file_storage.md](api_summary_file_storage.md) | Streaming blob storage: one put/get contract over memory, directory, database and S3 backends. |
| Health Check | [api_summary_healthcheck.md](api_summary_healthcheck.md) | Health analyzer and health-check service/server. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | The server-side base exception `TomServerException`, the per-request correlation id `TomRequestId` it reads, and `tomErrorEnvelope`, the wire shape every error response uses. |
| Messaging | [api_summary_messaging.md](api_summary_messaging.md) | Channel-neutral messages, delivery transports (SMTP, HTTP SMS gateway and stand-ins), MIME encoding, the durable outbox, and resource-keyed email and SMS. |
| Object Persistence | [api_summary_object_persistence.md](api_summary_object_persistence.md) | Persistence annotations, repositories, query builder, operators/expressions, data scoping, column authorization. |
| Preferences | [api_summary_preferences.md](api_summary_preferences.md) | Server-stored per-principal preferences: the scoped `tom_user_preference` entity, the typed service over it, and the `/preferences/*` endpoints. |
| Resources | [api_summary_resources.md](api_summary_resources.md) | Locale-aware text resolution: one bundle per locale, chosen by the recipient's language. |
| Scheduling | [api_summary_scheduling.md](api_summary_scheduling.md) | The relational half of the job scheduler: the shared job queue, fencing leases, and the node roll call. |
| Server | [api_summary_server.md](api_summary_server.md) | The HTTP server, per-request logging state, and middleware. |
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
| `TomAuditRecordIdGenerator` | class | Issues record ids that sort chronologically as plain strings. |
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
| `TomDeliveredCode2FAService` | abstract class | The shape every *delivered* one-time code shares: generate, seal into `verificationData`, send, recognise, and prove the destination by enrolment. |
| `TomEmailCode2FAService` | class | A one-time code mailed through `TomEmailService`. |
| `TomSmsCode2FAService` | class | A one-time code texted through `TomSmsService`. |
| `Tom2FAPolicy` | abstract class | Decides, per login, whether a second factor is owed and which mechanisms may satisfy it. |
| `Tom2FARequirement` | enum | How strongly a factor is owed: `disabled`, `optional`, `required`. |
| `Tom2FADecision` | class | One policy verdict: requirement, permitted mechanisms, grace logins left. |
| `TomPrincipalFlag2FAPolicy` | class | The default policy: reads `TomPrincipal.requires2FA` / `twoFactorType`. |
| `TomRole2FAPolicy` | class | Policy driven by role rules, folded to the strictest match. |
| `Tom2FAGraceAccounting` | abstract class | Optional bean that records a grace login being spent. |
| `Tom2FAEnrolmentStore` | abstract class | Where a principal's set-up factors live; deployment-supplied, no fallback. |
| `TomMemory2FAEnrolmentStore` | class | In-memory enrolment store, for tests and dev servers. |
| `TomPersistent2FAEnrolmentStore` | class | Enrolment store over a repository, with `secretData` encrypted at rest. |
| `TomUserTwoFactorEnrolment` | class | The persisted row behind `TomPersistent2FAEnrolmentStore`. |
| `TomUserTwoFactorEnrolmentRepository` | class | SQL repository for `TomUserTwoFactorEnrolment`. |
| `Tom2FAEnrolment` | class | One factor a principal has set up. |
| `Tom2FAEnrolmentSupport` | abstract class | The extra contract a mechanism implements to be enrollable through a login. |
| `Tom2FAEnrolmentOffer` | class | What a mechanism returns when starting an enrolment. |
| `Tom2FAEnrolmentState` | class | The enrolment leg carried across passes in the interim token. |
| `Tom2FAException` | class | 2FA configuration fault (extends `TomServerException`). |
| `TomAuthenticationAdaptor` | class | Reflection marker for auth adaptors. |
| `Tom2FAAdaptor` | class | Reflection marker for 2FA adaptors. |
| `TomAuthenticationData` | class | Reflected authentication payload. |
| `TomAuthenticationInfo` | class | Resolved authentication result. |
| `TomLoginException` | class | Login failure (extends `TomServerException`). |
| `TomServerSelfLogin` | class | Logs the deployment in as itself and installs the server principal. |
| `TomServiceCredential` | class | The deployment's own login credential and where to present it. |
| `TomServiceLoginTransport` | abstract class | The one-JSON-POST seam the self-login runs over. |
| `TomHttpServiceLoginTransport` | class | The live transport, over `TomServerChannel`. |
| `TomServiceLoginResponse` | class | The raw status + body of a self-login POST. |
| `TomServerSelfLoginException` | class | A configured deployment failed to log itself in. |
| `TomOAuthAuthenticationService` | class | An authentication service for authorization-code logins; delegates every other credential. |
| `TomOAuthCredential` | class | The code + state pair carried in `TomAuthenticationData.key`. |
| `TomExternalIdentityDirectory` | abstract class | What the deployment supplies: local account lookup and first-login provisioning. |
| `TomOAuthProviderConfig` | class | One provider as data: endpoints, client credentials, claim names, provisioning, clock-skew tolerance. |
| `TomOAuthProviders` | class | The configured provider set, read from `oauth.providers`. |
| `TomOAuthProvisioning` | enum | What a first external login with no local account does: `refuse` or `autoProvision`. |
| `TomOAuthFlow` | class | The authorization-code + PKCE handshake. |
| `TomOAuthPkce` | class | A verifier / `S256` challenge pair. |
| `TomOAuthExchange` | class | What a completed handshake yields: the provider it was against, the asserted identity and its login context. |
| `TomOAuthAuthorizationState` | class | One pending authorization: handle, verifier, and the context it started in. |
| `TomOAuthStateStore` | abstract class | Where pending authorizations live between the two halves of the flow. |
| `TomOAuthMemoryStateStore` | class | The default store: per-process, time-to-live bounded. |
| `TomSqlOAuthStateStore` | class | State store over `tom_oauth_state`, so a flow begun on one node completes on another. |
| `TomOAuthStateRow` | class | One `tom_oauth_state` row, as the SQL store reads it back. |
| `TomOAuthStateStoreType` | enum | Which store is configured: `memory` (default) or `sql`. |
| `TomOAuthStateStoreSettings` | class | The `oauth.stateStore` block as data, and `createStore()` for what it names. |
| `TomOAuthTokenTransport` | abstract class | The provider HTTP calls, so a test can stub the provider. |
| `TomHttpOAuthTokenTransport` | class | The live transport to a provider's token and userinfo endpoints. |
| `TomExternalIdentity` | class | What the provider asserted: issuer, subject, username, display name, claims. |
| `TomExternalIdentityStore` | abstract class | The linking table: (issuer, subject) → local account. |
| `TomPersistentExternalIdentityStore` | class | Linking table over a repository. |
| `TomMemoryExternalIdentityStore` | class | In-memory linking table, for tests and dev servers. |
| `TomExternalIdentityLink` | class | One persisted link row. |
| `TomExternalIdentityLinkRepository` | class | SQL repository for `TomExternalIdentityLink`. |
| `TomOAuthTokenGrant` | class | One provider grant — access token, refresh token, scopes, lifetime. Prints neither token. |
| `TomOAuthTokenStore` | abstract class | Where a grant lives, keyed (issuer, subject). Unregistered means nothing is ever stored. |
| `TomMemoryOAuthTokenStore` | class | In-memory grant store, for tests and dev servers. |
| `TomPersistentOAuthTokenStore` | class | Grant store over `tom_external_identity_token`, encrypted at rest. |
| `TomExternalIdentityToken` | class | One persisted grant row: the encrypted grant plus its operator projection. |
| `TomExternalIdentityTokenRepository` | class | SQL repository for `TomExternalIdentityToken`. |
| `TomOAuthServer` | class | The three `/oauth/*` endpoints. |
| `TomOAuthException` | class | A mis-configured provider set or a refused handshake (extends `TomServerException`). |
| `installJwtSigning` | top-level function | Installs the configured JWT key material at boot; refuses the bundled sample keys outside development. |
| `TomSigningKeyException` | class | The refusal: names the unset key fields and their environment variables (extends `TomServerException`). |

### Authorization (`lib/src/tomserver/authorization/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuthorizationCache` | class | Cache of resolved authorization state. |
| `TomAuthorizationCacheEntry` | class | A single cache entry. |
| `TomAuthorizationCacheExecutor` | class | Isolate executor backing the cache. |
| `TomAuthorizationCacheStoreMessage` | class | Store command message. |
| `TomAuthorizationCacheRetrieveMessage` | class | Retrieve command message. |
| `TomAuthorizationCacheException` | class | Cache error (extends `TomServerException`). |
| `TomAuthStateCodec` | class | Encodes/decodes auth state (static). |
| `TomResourceGrant` | class | A grant of a role on a resource. |
| `TomGradedAccessControlInformation` | class | Graded (field-level) access info. |
| `TomResourceDataScope` | class | The grant-driven row scope: filters an entity by the resources the caller holds a grant on. |
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
| `TomEnvFile` | class | `.env` file loading, and resolving it with the OS environment into the map `${VAR:default}` expansion reads (static). |

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
| `TomConfigurationException` | class | A property failed the cast to `T` (extends `TomServerException`). |
| `tomAppId` | top-level getter | The current application id, read from the active configuration's `appId`. |
| `selectedRuntimeEnvironmentName` | top-level function | Which runtime environment the deployment selected, read before the configuration exists: command line, then `.env`, then the OS environment. |

### Datasources (`lib/src/tomserver/datasources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbType<T>` | abstract class | Base DB column type (extends kernel `TomObject`). |
| `TomDbInt` / `TomDbDouble` / `TomDbString` / `TomDbDateTime` / `TomDbDate` / `TomDbTime` / `TomDbBool` | class | Concrete DB types. |
| `TomOperator<R>` | abstract class | Base of the SQL expression tree. |
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
| `TomFrameworkTable` | class | The single declaration of a table the framework itself owns. |
| `TomFrameworkColumn` | class | One column of a framework-owned table. |
| `TomFrameworkKey` | class | One index or unique constraint of a framework-owned table. |
| `TomDatasourceInitException` | class | Init error (extends `TomServerException`). |
| `MariadbDatasourceException` | class | MariaDB error (extends `TomServerException`). |
| `MariadbPreparedStatementException` | class | Prepared-statement error. |
| `TomAggregateFunction` | enum | The aggregate functions the typed query layer can express. |
| `TomSqlTypeFamily` | enum | The coarse type class a stored column belongs to. |
| `TomSqlFailureMode` | enum | Whether a failed write definitely did not apply, or may have. |
| `SqlString` | typedef | Alias for `String`. |
| `classifySqlFailure` | function | Classifies a write failure as `definite` or `ambiguous`. |
| `sqlFailureCauses` | function | A failure and every `rootException` beneath it, outermost first. |
| `isLostConnectionFailure` | function | Whether the statement was left with no live link, so one retry is worth it. |
| `sqlInstant` | function | Renders an instant as the UTC `DATETIME(6)` literal the columns bind. |
| `sqlDate` | function | Renders the calendar half of an instant as the `YYYY-MM-DD` a `DATE` column takes. |
| `sqlTimeOfDay` | function | Renders the clock half of an instant as the `HH:MM:SS` a `TIME` column takes. |
| `parseSqlInstant` | function | Reads a stored `DATETIME(6)` back as a UTC `DateTime`. |
| `parseOptionalSqlInstant` | function | The same, treating an empty column as absent. |
| `unknownFrameworkColumns` | function | Audits a statement for column references no framework table declares. |

### Database Migration (`lib/src/tomserver/db_migration/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomDbMigrations` | class | Migration runner/registry. |
| `TomDbMigrator` | abstract class | Migrator contract. |
| `TomDbMigrationAdaptor` | class | Annotation tagging a migration adaptor. |
| `MariadbMigrationAdaptor` | class | MariaDB migration adaptor. |
| `TomMigrationFileName` | class | Parses/validates migration file names. |
| `TomDbVersion` | class | A schema version. |
| `TomSqlLexer` | class | The module's one quote/comment scanner and statement splitter. |
| `TomSchemaColumn` | class | One column, in the vocabulary the convergence check compares in. |
| `TomSchemaTable` | class | One table: its columns, primary key and origin. |
| `TomSchemaModel` | class | A whole schema — the tables of one datasource/schema pair. |
| `TomSchemaBuilder` | class | The mutable accumulator both sides build their model through. |
| `TomMigrationArtifact` | class | One migration artifact as the reader consumes it (basename + SQL). |
| `TomDdlReplayError` | class | A statement the reader could not replay — reported, never thrown. |
| `TomDdlReplayResult` | class | The schema a chain produces, plus its replay errors. |
| `TomSchemaDdlReader` | class | Replays a migration chain into a schema model without a database. |
| `TomEntitySchemaReader` | class | Reads the schema the annotated entity classes expect. |
| `TomSchemaDivergence` | class | One disagreement between the two sides of a check. |
| `TomSchemaDivergenceKind` | enum | What kind of disagreement a divergence reports. |
| `TomSchemaConvergenceReport` | class | The outcome of checking one datasource/schema pair. |
| `TomSchemaConvergenceCheck` | class | Entity model vs. migration chain, without a database. |
| `TomFrameworkSchemaCheck` | class | The same check for the tables the framework itself owns. |
| `TomInformationSchemaColumnRow` | class | One `information_schema.COLUMNS` row, as the live check reads it. |
| `TomSqlTypeFamilyCompatibility` | extension | How tolerantly two type families still count as agreeing. |
| `frameworkOwnedTables` | function | Every table the framework owns, at its default name. |
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
| `TomEndpointRouteKey` | typedef | Route-table key: declared uri + HTTP method name. |
| `TomEndpointRoutingInfo` | class | Route entry: handler, endpoint, and the one method it was mounted for. |
| `TomMethodMetadata` | class | Reflected method metadata. |
| `TomClassScanResult` | class | Result of scanning a service class. |
| `TomErrorHandler` | abstract class | Error-handler contract. |
| `TomDefaultErrorHandler` | class | Default error handler. |
| `TomEndpointHandlerException` | class | Handler error. |
| `TomEndpointPipelineException` | class | Pipeline error. |
| `TomMultipartForm` | class | A decoded HTML form body: its text fields and its uploaded files. |
| `TomFormFile` | class | One uploaded file part: the bytes plus what the envelope claimed about them. |
| `TomFormBindingException` | class | Form decode or bind failure; always caused by what the caller sent. |
| `tomConsumesForm` | function | Whether a declared media type is an HTML form body, multipart or url-encoded. |
| `tomConsumesMultipartForm` | function | Whether a declared media type is specifically `multipart/form-data`. |
| `TomRedirect` | class | The directive a handler returns to answer with a `3xx`. |
| `TomWebSocketEndpoint<Req, Res>` | class | Method annotation declaring a WebSocket endpoint. |
| `TomWebSocketConnection` | class | A live WebSocket connection as a handler sees it. |
| `TomWebSocketException` | class | A socket endpoint declared or used in a way the pipeline cannot serve. |
| `TomFileSlot` | abstract class | One addressable file column, with its entity and key types already bound. |
| `TomFileSlots` | class | The registry of HTTP-reachable file columns, keyed by table and column name. |
| `TomFileSlotException` | class | Slot registration or resolution failure, raised while the application wires up. |
| `TomFileEndpoint` | class | Serves the file-transfer wire contract over the registered slots. |
| `TomFileService` | abstract class | The file-transfer service interface, mounted like any other `@tomService`. |
| `TomFileServer` | class | The default `TomFileService`, and the bean an application registers to mount it. |
| `TomFormFileStorage` | extension | Stores a `TomFormFile` through the same file slot the raw-body endpoint uses. |

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
| `TomExportStoreOperation` | enum | The four store operations and the error key each failure carries. |
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
| `TomBlobStoreOperation` | enum | The four operations a storage failure is reported as. |
| `defaultBlobManifestTable` / `defaultBlobChunkTable` | top-level | Default table names. |
| `blobManifestTable` / `blobChunkTable` | top-level | The table descriptors. |
| `blobManifestTableDdl` / `blobChunkTableDdl` | top-level | The `CREATE TABLE` statements, for a deployment that applies its own schema. |

### Health Check (`lib/src/tomserver/healthcheck/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomHealthAnalyzer` | abstract class | Health-analysis contract. |
| `TomDefaultHealthAnalyzer` | class | Default analyzer. |
| `TomHealthService` | abstract class | Health-check service (`@tomService`). |
| `TomHealthServer` | class | Health-check server component. |

### Little Things (`lib/src/tomserver/little_things/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomRequestId` | class | Per-request v4-UUID correlation id, published into the request zone. |
| `TomServerException` | class | Server-side base exception (extends `TomException`). |
| `tomErrorEnvelope` | function | Renders any error into the package's wire error body — the shape every error response uses. |

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
| `TomSmsTransport` | class | Real delivery over an HTTP SMS gateway. |
| `TomSmsGatewaySettings` | class | Everything needed to reach one SMS gateway. |
| `TomSmsAuthScheme` | enum | `none`, `bearer`, `basic`. |
| `TomSmsGatewayProtocol` | abstract class | One vendor's request/response shape, behind an interface. |
| `TomFieldMappedSmsProtocol` | class | The configurable protocol: field names in, status/error paths out. |
| `TomSmsGatewayRequest` | class | One gateway call, ready to send. |
| `TomSmsGatewayAnswer` | class | What the gateway said, with a three-valued permanence. |
| `TomSmsBodyFormat` | enum | `form`, `json`. |
| `TomSmsSubmission` | class | One recipient's share of a message, as handed to a protocol. |
| `TomSmsSegmentation` | class | What a text costs: encoding, units, segments. |
| `TomSmsEncoding` | enum | `gsm7`, `ucs2`. |
| `TomMimeEncoder` | class | Renders a message as an RFC 5322 / MIME document. |
| `TomMessageOutbox` | class | The durable send queue in front of a router. |
| `TomTemplatedMessageService` | abstract class | The rule every channel shares: a message is a template key plus parameters. |
| `TomEmailRequest` | class | What to send, to whom, with which values — a template key, never a subject or body. |
| `TomEmailService` | class | Renders resource-keyed email in the recipient's locale and queues it on the outbox. |
| `TomSmsRequest` | class | What to send, to which number, with which values — a template key, never a text. |
| `TomSmsService` | class | Renders resource-keyed SMS, caps its segments, and queues it on the outbox. |
| `TomMessagingException` | class | The module's base error (extends `TomServerException`). |
| `TomDeliveryException` | class | A delivery failure, classified transient or permanent (abstract). |
| `TomPermanentDeliveryException` | class | A delivery failure the scheduler will not retry. |
| `TomTransientDeliveryException` | class | A delivery failure worth another attempt. |
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
| `TomOperator` expression tree | class | `TomUnaryOperator`, `TomBinaryOperator`, `Parameter`, `DbCol`/`IntCol`/`StringCol`/`DoubleCol`/`BoolCol`/`DateTimeCol`/`DateCol`/`TimeCol`, the `*Literal` set, and `And`/`Or`/`Not`/`Eq`/`Neq`/`Lt`/`Gt`/`Lte`/`Gte`/`Like`/`NotLike`/`In`/`Group`/`Between`/`Regexp`/`IsNull`/`IsNotNull`. |
| `TomQuerySyntaxException` | class | Query syntax error. |
| `TomDataScope` | class | Row-level data scoping (static). |
| `TomDataScopeRegistry` / `TomDataScopePredicate` / `TomDataScopeBypass` | class | Data-scope machinery. |
| `TomDataScopeResolver` / `TomAsyncDataScopeResolver` | typedef | Scope resolver signatures. |
| `TomDataScopeException` / `TomDataScopeAuthorizationException` | class | Data-scope errors. |
| `TomColumnAuthorization` | class | Column-level write authorization (static). |
| `TomColumnWriteDecision<C>` | class | A column write decision. |
| `TomColumnAuthResolver` | typedef | Column-auth resolver signature. |
| `TomRowColumnAuthorization` | class | Per-row column grades for file operations (static). |
| `TomRowColumnAuthResolver` | typedef | Per-row column-grade resolver signature. |
| `TomColumnAuthorizationException` | class | Column-auth error. |
| `TomAnnotationAnalyzer` | mixin | Persistence-annotation analysis (static). |
| `TomAnnotationAnalyzerException` / `TomAnnotationAnalyzerSyntaxException` | class | Analyzer errors. |

### Preferences (`lib/src/tomserver/preferences/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomUserPreference` | class | The `tom_user_preference` row; `@TomDbScope(field: 'principal_id', scope: 'owner')` is the whole ownership rule. |
| `TomUserPreferenceRepository` | class | The CRUD repository for that entity. |
| `TomUserPreferences` | class | Typed `get`/`set`/`getOr`/`read`/`all`/`remove` for the caller in the request zone, plus `getFor` for the login path. Installed as a bean. |
| `TomUserPreferenceException` | class | An operation that cannot identify the caller (extends `TomServerException`). |
| `TomUserPreferencesServer` | class | The `@TomApiImplementation` behind the kernel's `tomUserPreferencesApi`. |
| `TomUserPreferencesErrorHandler` | class | Maps `preferences.not_found` — and only that key — to a `404`, so a client can tell a miss from an outage. |

### Resources (`lib/src/tomserver/resources/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTextLocale` | class | A normalised language, optionally narrowed by a country; derivable from a principal. |
| `TomLocalizedTextResources` | class | One `TomTextResourceProvider` per locale, plus the fallback chain that picks one. |
| `TomResourceLocaleException` | class | A locale that cannot be formed (extends `TomServerException`). |

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
| `TomRequestLogInfo` | class | Per-request log record. |
| `contextSetupMiddleware` | function | Establishes the execution context per request. |
| `extractAuthentication` | function | Extracts principal + JWT from a request. |
| `tomDefaultAuthenticationMiddleware` | function | Default auth middleware. |
| `tomLoggingMiddleware` | function | Request-logging middleware. |
| `noopHandler` | function | A handler returning a fixed status. |

### Transactions (`lib/src/tomserver/transactions/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomTransactionManager` | abstract class | Transaction coordination (static, zone-scoped per flow). |
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
| `classifySqlFailure` | Datasources |
| `contextSetupMiddleware` | Server |
| `DateCol` | Object Persistence |
| `DateLiteral` | Object Persistence |
| `DateTimeCol` | Object Persistence |
| `DateTimeLiteral` | Object Persistence |
| `DbCol` | Object Persistence |
| `defaultAuditTrailTable` | Audit |
| `defaultBlobChunkTable` | File Storage |
| `defaultBlobManifestTable` | File Storage |
| `defaultJobRunTable` | Scheduling |
| `defaultLeaseTable` | Scheduling |
| `defaultNodeFailureSlack` | Scheduling |
| `defaultOAuthStateTable` | Authentication |
| `defaultSchedulerNodeTable` | Scheduling |
| `DoubleCol` | Object Persistence |
| `DoubleLiteral` | Object Persistence |
| `Eq` | Object Persistence |
| `extractAuthentication` | Server |
| `frameworkOwnedTables` | Database Migration |
| `Group` | Object Persistence |
| `Gt` | Object Persistence |
| `Gte` | Object Persistence |
| `In` | Object Persistence |
| `InMemoryPrincipalDelegationStore` | Authorization |
| `installJwtSigning` | Authentication |
| `InMemoryPrincipalResourceGrantStore` | Authorization |
| `IntCol` | Object Persistence |
| `IntegerLiteral` | Object Persistence |
| `isLostConnectionFailure` | Datasources |
| `IsNotNull` | Object Persistence |
| `IsNull` | Object Persistence |
| `isSchedulerNodeFailed` | Scheduling |
| `jobRunTable` | Scheduling |
| `jobRunTableDdl` | Scheduling |
| `leaseTable` | Scheduling |
| `leaseTableDdl` | Scheduling |
| `Like` | Object Persistence |
| `TomLoginException` | Authentication |
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
| `oauthStateTable` | Authentication |
| `oauthStateTableDdl` | Authentication |
| `Or` | Object Persistence |
| `Parameter` | Object Persistence |
| `parseAuditLines` | Audit |
| `parseOptionalSqlInstant` | Datasources |
| `parseSqlInstant` | Datasources |
| `PrincipalDelegationStore` | Authorization |
| `PrincipalResourceGrantStore` | Authorization |
| `Regexp` | Object Persistence |
| `RepositoryPrincipalDelegationStore` | Authorization |
| `RepositoryPrincipalResourceGrantStore` | Authorization |
| `schedulerNodeFailedAfter` | Scheduling |
| `schedulerNodeTable` | Scheduling |
| `schedulerNodeTableDdl` | Scheduling |
| `selectedRuntimeEnvironmentName` | Configuration |
| `sqlDate` | Datasources |
| `sqlFailureCauses` | Datasources |
| `sqlInstant` | Datasources |
| `SqlPlaceholderScan` | Datasources |
| `SqlString` | Datasources |
| `sqlTimeOfDay` | Datasources |
| `StringCol` | Object Persistence |
| `StringLiteral` | Object Persistence |
| `TimeCol` | Object Persistence |
| `TimeLiteral` | Object Persistence |
| `Tom2FAAdaptor` | Authentication |
| `Tom2FAChallengeSpec` | Authentication |
| `Tom2FAContext` | Authentication |
| `Tom2FAException` | Authentication |
| `Tom2FARegistry` | Authentication |
| `Tom2FAService` | Authentication |
| `Tom2FASubmission` | Authentication |
| `TomAggregateFunction` | Datasources |
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
| `TomAuditOutcome` | Audit |
| `TomAuditPolicy` | Audit |
| `TomAuditRecord` | Audit |
| `TomAuditRecordIdGenerator` | Audit |
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
| `TomBlobStoreOperation` | File Storage |
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
| `TomConfigurationException` | Configuration |
| `tomConsumesForm` | Endpoints |
| `tomConsumesMultipartForm` | Endpoints |
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
| `TomDdlReplayError` | Database Migration |
| `TomDdlReplayResult` | Database Migration |
| `tomDefaultAuthenticationMiddleware` | Server |
| `TomDefaultErrorHandler` | Endpoints |
| `TomDefaultHealthAnalyzer` | Health Check |
| `TomDelegationMode` | Authorization |
| `TomDelegationResolver` | Authorization |
| `TomDelete` | Datasources |
| `TomDeliveredCode2FAService` | Authentication |
| `TomDeliveryException` | Messaging |
| `TomDeliveryOutcome` | Messaging |
| `TomDeliveryReceipt` | Messaging |
| `TomDirectoryBlobStore` | File Storage |
| `TomDirectoryExportStore` | Export |
| `TomDoubleConfig` | Configuration |
| `TomDummyAuthenticationService` | Authentication |
| `TomEmailCode2FAService` | Authentication |
| `TomEmailRequest` | Messaging |
| `TomEmailService` | Messaging |
| `TomEndpoint` | Endpoints |
| `TomEndpointBase` | Endpoints |
| `TomEndpointHandler` | Endpoints |
| `TomEndpointHandlerException` | Endpoints |
| `TomEndpointPipelineException` | Endpoints |
| `TomEndpointRouteKey` | Endpoints |
| `TomEndpointRouting` | Endpoints |
| `TomEndpointRoutingInfo` | Endpoints |
| `TomEntityId` | Object Persistence |
| `TomEntitySchemaReader` | Database Migration |
| `TomEnvFile` | Command Line |
| `TomErrorHandler` | Endpoints |
| `tomErrorEnvelope` | Little Things |
| `TomExportException` | Export |
| `TomExportFormats` | Export |
| `TomExportService` | Export |
| `TomExportStore` | Export |
| `TomExportStoreOperation` | Export |
| `TomExternalIdentity` | Authentication |
| `TomExternalIdentityDirectory` | Authentication |
| `TomExternalIdentityLink` | Authentication |
| `TomExternalIdentityLinkRepository` | Authentication |
| `TomExternalIdentityStore` | Authentication |
| `TomExternalIdentityToken` | Authentication |
| `TomExternalIdentityTokenRepository` | Authentication |
| `TomFieldMappedSmsProtocol` | Messaging |
| `TomFileAuditAnchorStore` | Audit |
| `TomFileAuditSink` | Audit |
| `TomFileEndpoint` | Endpoints |
| `TomFileMessageTransport` | Messaging |
| `TomFileServer` | Endpoints |
| `TomFileService` | Endpoints |
| `TomFileSlot` | Endpoints |
| `TomFileSlotException` | Endpoints |
| `TomFileSlots` | Endpoints |
| `tomFormatCellAsText` | Export |
| `TomFormBindingException` | Endpoints |
| `TomFormFile` | Endpoints |
| `TomFormFileStorage` | Endpoints |
| `TomFrameworkColumn` | Datasources |
| `TomFrameworkKey` | Datasources |
| `TomFrameworkSchemaCheck` | Database Migration |
| `TomFrameworkTable` | Datasources |
| `TomGeneratedQuery` | Datasources |
| `TomGradedAccessControlInformation` | Authorization |
| `TomHealthAnalyzer` | Health Check |
| `TomHealthServer` | Health Check |
| `TomHealthService` | Health Check |
| `TomHttpOAuthTokenTransport` | Authentication |
| `TomHttpServiceLoginTransport` | Authentication |
| `TomInformationSchemaColumnRow` | Database Migration |
| `TomIntConfig` | Configuration |
| `TomJobRunRow` | Scheduling |
| `TomJobRunWindowRow` | Scheduling |
| `TomJoinTable` | Object Persistence |
| `TomLeaseRow` | Scheduling |
| `TomLiteralSelect` | Datasources |
| `TomLocalizedTextResources` | Resources |
| `tomLoggingMiddleware` | Server |
| `TomMemoryAuditAnchorStore` | Audit |
| `TomMemoryAuditSink` | Audit |
| `TomMemoryBlobStore` | File Storage |
| `TomMemoryExportStore` | Export |
| `TomMemoryExternalIdentityStore` | Authentication |
| `TomMemoryMessageTransport` | Messaging |
| `TomMemoryOAuthTokenStore` | Authentication |
| `TomMessage` | Messaging |
| `TomMessageBody` | Messaging |
| `TomMessageChannel` | Messaging |
| `TomMessageOutbox` | Messaging |
| `TomMessageRouter` | Messaging |
| `TomMessageTransport` | Messaging |
| `TomMessagingException` | Messaging |
| `TomMethodMetadata` | Endpoints |
| `TomMigrationArtifact` | Database Migration |
| `TomMigrationFileName` | Database Migration |
| `TomMimeEncoder` | Messaging |
| `tomMimeLineEnding` | Messaging |
| `tomMimeMaxLineLength` | Messaging |
| `TomMultipartForm` | Endpoints |
| `TomNoOpMessageTransport` | Messaging |
| `TomOAuthAuthenticationService` | Authentication |
| `TomOAuthAuthorizationState` | Authentication |
| `TomOAuthCredential` | Authentication |
| `TomOAuthException` | Authentication |
| `TomOAuthExchange` | Authentication |
| `TomOAuthFlow` | Authentication |
| `TomOAuthMemoryStateStore` | Authentication |
| `TomOAuthPkce` | Authentication |
| `TomOAuthProviderConfig` | Authentication |
| `TomOAuthProviders` | Authentication |
| `TomOAuthProvisioning` | Authentication |
| `TomOAuthServer` | Authentication |
| `TomOAuthStateRow` | Authentication |
| `TomOAuthStateStore` | Authentication |
| `TomOAuthStateStoreSettings` | Authentication |
| `TomOAuthStateStoreType` | Authentication |
| `TomOAuthTokenGrant` | Authentication |
| `TomOAuthTokenStore` | Authentication |
| `TomOAuthTokenTransport` | Authentication |
| `TomOperator` | Datasources |
| `tomOutboxJobName` | Messaging |
| `TomPdfRenderer` | Export |
| `TomPermanentDeliveryException` | Messaging |
| `TomTransientDeliveryException` | Messaging |
| `TomPersistenceEventHandler` | Object Persistence |
| `TomPersistentExternalIdentityStore` | Authentication |
| `TomPersistentOAuthTokenStore` | Authentication |
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
| `TomRedirect` | Endpoints |
| `TomReference` | Object Persistence |
| `TomRepository` | Object Persistence |
| `TomRepositoryType` | Object Persistence |
| `TomRequestId` | Little Things |
| `TomRequestLogInfo` | Server |
| `TomResourceDataScope` | Authorization |
| `TomResourceGrant` | Authorization |
| `TomResourceLocaleException` | Resources |
| `TomRowColumnAuthorization` | Object Persistence |
| `TomRowColumnAuthResolver` | Object Persistence |
| `TomRsaAuditAnchorSigner` | Audit |
| `TomRsaAuditAnchorVerifier` | Audit |
| `TomS3BlobStore` | File Storage |
| `TomSchedulerNode` | Scheduling |
| `TomSchedulerNodeRow` | Scheduling |
| `TomSchemaBuilder` | Database Migration |
| `TomSchemaColumn` | Database Migration |
| `TomSchemaConvergenceCheck` | Database Migration |
| `TomSchemaConvergenceReport` | Database Migration |
| `TomSchemaDdlReader` | Database Migration |
| `TomSchemaDivergence` | Database Migration |
| `TomSchemaDivergenceKind` | Database Migration |
| `TomSchemaModel` | Database Migration |
| `TomSchemaTable` | Database Migration |
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
| `TomSigningKeyException` | Authentication |
| `TomSmsAuthScheme` | Messaging |
| `TomSmsBodyFormat` | Messaging |
| `TomSmsCode2FAService` | Authentication |
| `TomSmsEncoding` | Messaging |
| `TomSmsGatewayAnswer` | Messaging |
| `TomSmsGatewayProtocol` | Messaging |
| `TomSmsGatewayRequest` | Messaging |
| `TomSmsGatewaySettings` | Messaging |
| `TomSmsRequest` | Messaging |
| `TomSmsSegmentation` | Messaging |
| `TomSmsService` | Messaging |
| `TomSmsSubmission` | Messaging |
| `TomSmsTransport` | Messaging |
| `TomSmtpConnection` | Messaging |
| `TomSmtpReply` | Messaging |
| `TomSmtpSecurity` | Messaging |
| `TomSmtpSettings` | Messaging |
| `TomSmtpTransport` | Messaging |
| `TomSocketSmtpConnection` | Messaging |
| `TomSqlAuditSink` | Audit |
| `TomSqlDatasourceRepository` | Object Persistence |
| `TomSqlFailureMode` | Datasources |
| `TomSqlJobStore` | Scheduling |
| `TomSqlLeaseLock` | Scheduling |
| `TomSqlLexer` | Database Migration |
| `TomSqlOAuthStateStore` | Authentication |
| `TomSqlSchedulerNodes` | Scheduling |
| `TomSqlTypeFamily` | Datasources |
| `TomSqlTypeFamilyCompatibility` | Database Migration |
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
| `TomTemplatedMessageService` | Messaging |
| `TomTextLocale` | Resources |
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
| `TomUserPreference` | Preferences |
| `TomUserPreferenceException` | Preferences |
| `TomUserPreferenceRepository` | Preferences |
| `TomUserPreferences` | Preferences |
| `TomUserPreferencesErrorHandler` | Preferences |
| `TomUserPreferencesServer` | Preferences |
| `TomWebSocketConnection` | Endpoints |
| `TomWebSocketEndpoint` | Endpoints |
| `TomWebSocketException` | Endpoints |
| `TomXlsxRenderer` | Export |
| `TomYaml` | Configuration |
| `unknownFrameworkColumns` | Datasources |
| `verifyAgainstAnchor` | Audit |
| `verifyAuditChain` | Audit |
