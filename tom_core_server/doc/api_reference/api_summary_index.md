# Tom Core Server API Reference: Index

Per-module API summaries for `tom_core_server` — the server layer of Tom Core.
It re-exports all of `tom_core_kernel` (see that package's docs for the kernel
API), `mysql_client`, and `tom_basics_console`, and adds the server-specific
surface documented here.

## Quick Navigation

| Module | Summary | What it provides |
| ------ | ------- | ---------------- |
| Authentication | [api_summary_authentication.md](api_summary_authentication.md) | Login/2FA services, adaptors, and the authentication server. |
| Authorization | [api_summary_authorization.md](api_summary_authorization.md) | Authorization cache, graded access, principal delegation and resource grants. |
| Cache | [api_summary_cache.md](api_summary_cache.md) | Isolate-backed server cache and its command messages. |
| Command Line | [api_summary_cmdline.md](api_summary_cmdline.md) | CLI argument parsing (`TomArgs`) and `.env` file loading (`TomEnvFile`). |
| Configuration | [api_summary_configuration.md](api_summary_configuration.md) | Server config provider, typed config values, YAML resources. |
| Datasources | [api_summary_datasources.md](api_summary_datasources.md) | DB type system, SQL dialects, queries, MariaDB datasource/prepared statements. |
| Database Migration | [api_summary_db_migration.md](api_summary_db_migration.md) | Migration runner, versioning, and the MariaDB migration adaptor. |
| Endpoints | [api_summary_endpoints.md](api_summary_endpoints.md) | Service/endpoint annotations, routing, handler pipeline, error handling. |
| Health Check | [api_summary_healthcheck.md](api_summary_healthcheck.md) | Health analyzer and health-check service/server. |
| Little Things | [api_summary_little_things.md](api_summary_little_things.md) | The server-side base exception `TomServerException`. |
| Object Persistence | [api_summary_object_persistence.md](api_summary_object_persistence.md) | Persistence annotations, repositories, query builder, operators/expressions, data scoping, column authorization. |
| Server | [api_summary_server.md](api_summary_server.md) | The HTTP server, request identity/logging, and middleware. |
| Transactions | [api_summary_transactions.md](api_summary_transactions.md) | Distributed transaction manager and participants. |

## Modules

### Authentication (`lib/src/tomserver/authentication/`)

| Type | Kind | Description |
| ---- | ---- | ----------- |
| `TomAuthenticationServer` | class | Server-side authentication entry point. |
| `TomAuthenticationService` | abstract class | Authentication service contract. |
| `TomDummyAuthenticationService` | class | In-memory service for tests/dev. |
| `Tom2FAService` | abstract class | Two-factor service contract. |
| `TomAuthenticationAdaptor` | class | Reflection marker for auth adaptors. |
| `Tom2FAAdaptor` | class | Reflection marker for 2FA adaptors. |
| `TomAuthenticationData` | class | Reflected authentication payload. |
| `TomAuthenticationInfo` | class | Resolved authentication result. |
| `LoginException` | class | Login failure (extends `TomServerException`). |

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
| `Between` | Object Persistence |
| `BoolCol` | Object Persistence |
| `BoolLiteral` | Object Persistence |
| `contextSetupMiddleware` | Server |
| `DateCol` | Object Persistence |
| `DateLiteral` | Object Persistence |
| `DateTimeCol` | Object Persistence |
| `DateTimeLiteral` | Object Persistence |
| `DbCol` | Object Persistence |
| `DefaultHealthAnalyzer` | Health Check |
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
| `PrincipalDelegationStore` | Authorization |
| `PrincipalResourceGrantStore` | Authorization |
| `Regexp` | Object Persistence |
| `RepositoryPrincipalDelegationStore` | Authorization |
| `RepositoryPrincipalResourceGrantStore` | Authorization |
| `SqlPlaceholderScan` | Datasources |
| `SqlString` | Datasources |
| `StringCol` | Object Persistence |
| `StringLiteral` | Object Persistence |
| `Tom2FAAdaptor` | Authentication |
| `Tom2FAService` | Authentication |
| `TomAnnotationAnalyzer` | Object Persistence |
| `TomAnnotationAnalyzerException` | Object Persistence |
| `TomAnnotationAnalyzerSyntaxException` | Object Persistence |
| `TomApiEndpointImplementation` | Endpoints |
| `TomApiImplementation` | Endpoints |
| `TomArgs` | Command Line |
| `TomAsyncDataScopeResolver` | Object Persistence |
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
| `TomBaseServerConfiguration` | Configuration |
| `TomBinaryOperator` | Object Persistence |
| `TomBoolConfig` | Configuration |
| `TomCache` | Cache |
| `TomCacheEntry` | Cache |
| `TomCacheException` | Cache |
| `TomCacheManager` | Cache |
| `TomCacheRemoveMessage` | Cache |
| `TomCacheRetrieveMessage` | Cache |
| `TomCacheStoreMessage` | Cache |
| `TomClassScanResult` | Endpoints |
| `TomColumnAuthResolver` | Object Persistence |
| `TomColumnAuthorization` | Object Persistence |
| `TomColumnAuthorizationException` | Object Persistence |
| `TomColumnInformation` | Object Persistence |
| `TomColumnWriteDecision` | Object Persistence |
| `TomComponentReference` | Endpoints |
| `TomConfig` | Configuration |
| `TomCount` | Datasources |
| `TomCountResult` | Object Persistence |
| `TomDartType` | Object Persistence |
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
| `TomGeneratedQuery` | Datasources |
| `TomGradedAccessControlInformation` | Authorization |
| `TomHealthServer` | Health Check |
| `TomHealthService` | Health Check |
| `TomIntConfig` | Configuration |
| `TomJoinTable` | Object Persistence |
| `TomLiteralSelect` | Datasources |
| `TomMethodMetadata` | Endpoints |
| `TomMigrationFileName` | Database Migration |
| `TomOperator` | Datasources |
| `TomPersistenceEventHandler` | Object Persistence |
| `TomPreparedStatement` | Datasources |
| `TomPrincipalDelegation` | Authorization |
| `TomPrincipalResourceGrant` | Authorization |
| `TomPrincipalResourceRoleResolver` | Authorization |
| `TomQuery` | Datasources |
| `TomQueryBuilder` | Object Persistence |
| `TomQuerySentenceCompiler` | Object Persistence |
| `TomQuerySyntaxException` | Object Persistence |
| `TomReference` | Object Persistence |
| `TomRepository` | Object Persistence |
| `TomRepositoryType` | Object Persistence |
| `TomRequestId` | Server |
| `TomRequestLogInfo` | Server |
| `TomResourceGrant` | Authorization |
| `TomSelect` | Datasources |
| `TomServer` | Server |
| `TomServerConfigResourceProvider` | Configuration |
| `TomServerException` | Little Things |
| `TomService` | Endpoints |
| `tomService` | Endpoints |
| `TomSqlDatasourceRepository` | Object Persistence |
| `TomSqlDialect` | Datasources |
| `TomStandardSqlDialect` | Datasources |
| `TomStringConfig` | Configuration |
| `TomTransaction` | Transactions |
| `TomTransactionException` | Transactions |
| `TomTransactionManager` | Transactions |
| `TomTransactionParticipant` | Transactions |
| `TomTransactional` | Endpoints |
| `TomTypedPersistenceBase` | Datasources |
| `TomTypePersistenceInfo` | Datasources |
| `TomUnaryOperator` | Object Persistence |
| `TomYaml` | Configuration |
| `tomAppId` | Configuration |
